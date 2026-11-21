select(2, ...) 'aux'

local gui = require 'aux.gui'

-- Gamepad support for Forever's gamepad mode. Nothing here runs unless gamepad mode is on.
--
-- aux must not write into Blizzard's gamepad system (GamepadMode, SmartNavigation, the window
-- manager or its binding stack): whatever aux writes there taints Blizzard's own code later. The
-- first try registered aux with Blizzard's window manager; closing aux by gamepad then had Blizzard
-- call SetPreferredGamepadInteractTarget, which was blocked, each "blocked" popup was blocked in turn
-- (259 times) and the game froze (Logs/taint.log, 2026-10-13).
--
-- So aux has a navigator of its own. While aux is open it binds the pad buttons to buttons of its own
-- with override bindings on a frame it owns; they win over Blizzard's navigation, which still drives
-- the invisible Blizzard auction house window (probe, 2026-10-13), and a press through them counts
-- as a hardware event, so A can buy and post.
--   D-pad  moves a gold frame to the nearest control in that direction; in a list, past the last
--          row shown, it scrolls the list
--   A      presses the control (focuses a text box; opens a dropdown, then picks an option). On a
--          Sniper deal it then moves the focus to the buy bar's Buy button once it shows
--   B      closes what is open: a dropdown, a text box, a popup (Settings, quick searches), then aux
--   X      right-clicks the control (search from a bag item, remove a favorite, clear a text box)
--   Y      the tab's main action: Buy (then Confirm, with Confirm before buying on) on Search, Start or Stop on Sniper, Post on Post,
--          Cancel the selected auction on Auctions, Buyout the selected bid on Bids
--   LB/RB  step through the top bar: the five tabs (switched at once), then Settings, Full scan
--          and Blizzard UI (A presses them)
-- Nothing runs every frame: the controls are found when a button is pressed.

local KEYS = {
    {'up', 'GAMEPAD_DPAD_TOP', 'PADDUP'},
    {'down', 'GAMEPAD_DPAD_BOTTOM', 'PADDDOWN'},
    {'left', 'GAMEPAD_DPAD_LEFT', 'PADDLEFT'},
    {'right', 'GAMEPAD_DPAD_RIGHT', 'PADDRIGHT'},
    {'A', 'GAMEPAD_FACE_BOTTOM', 'PAD1'},
    {'B', 'GAMEPAD_FACE_RIGHT', 'PAD2'},
    {'X', 'GAMEPAD_FACE_LEFT', 'PAD3'},
    {'Y', 'GAMEPAD_FACE_TOP', 'PAD4'},
    {'LB', 'GAMEPAD_SHOULDER_LEFT', 'PADLSHOULDER'},
    {'RB', 'GAMEPAD_SHOULDER_RIGHT', 'PADRSHOULDER'},
}
local TOP_BAR_HEIGHT = 40

function M.gamepad_enabled()
    local input = _G.InputUtil
    return input ~= nil and input.IsGamepadUIEnabled ~= nil and input.IsGamepadUIEnabled() and true or false
end

local owner = CreateFrame('Frame')
local focused

-- the gold frame around the control that has the pad's focus, above popups and menus
local marker = CreateFrame('Frame', nil, frame)
marker:SetFrameStrata('FULLSCREEN_DIALOG')
marker:Hide()
do
    local edges = {}
    for i = 1, 4 do
        edges[i] = marker:CreateTexture(nil, 'OVERLAY')
        edges[i]:SetTexture([[Interface\Buttons\WHITE8X8]])
    end
    edges[1]:SetPoint('TOPLEFT'); edges[1]:SetPoint('TOPRIGHT'); edges[1]:SetHeight(2)
    edges[2]:SetPoint('BOTTOMLEFT'); edges[2]:SetPoint('BOTTOMRIGHT'); edges[2]:SetHeight(2)
    edges[3]:SetPoint('TOPLEFT'); edges[3]:SetPoint('BOTTOMLEFT'); edges[3]:SetWidth(2)
    edges[4]:SetPoint('TOPRIGHT'); edges[4]:SetPoint('BOTTOMRIGHT'); edges[4]:SetWidth(2)
    marker:SetScript('OnShow', function()
        for _, edge in ipairs(edges) do edge:SetVertexColor(color.accent.background()) end
    end)
end

-- the top bar: tabs, then the Settings, Full scan and Blizzard UI buttons
local function top_bar()
    local items = {}
    for _, tab in ipairs(tabs._tabs) do tinsert(items, tab) end
    tinsert(items, settings_button)
    tinsert(items, scan_button)
    tinsert(items, blizzard_button)
    return items
end

local top_bar_set
local function in_top_bar(f)
    -- the tabs exist once the saved settings load (event.AUX_LOADED in frame.lua)
    if not top_bar_set or not top_bar_set[tabs._tabs[1] or false] then
        top_bar_set = {}
        for _, item in ipairs(top_bar()) do top_bar_set[item] = true end
    end
    return top_bar_set[f] or false
end

local function usable(f)
    if not f or not f:IsVisible() then return false end
    if f.GetEffectiveAlpha and f:GetEffectiveAlpha() < .05 then return false end
    local x = f:GetCenter()
    return x ~= nil
end

-- what A can act on: buttons, text boxes, and frames that react to a mouse press (the Post tab's
-- bag list rows)
local function is_stop(f)
    if f == resize_grip or f == close_button or f == marker or in_top_bar(f) then return false end
    if f:IsObjectType('ScrollFrame') or f:IsObjectType('Slider') then return false end
    if f:IsObjectType('Button') or f:IsObjectType('EditBox') then return true end
    return f:GetScript('OnMouseUp') ~= nil or f:GetScript('OnMouseDown') ~= nil
end

local function collect(f, found)
    if not usable(f) then return end
    if f ~= frame and is_stop(f) then
        tinsert(found, f)
        -- a row's own icon button is part of the row; a text box's buttons are controls of their own
        -- (the Post tab's -, + and Max are children of its quantity boxes)
        if not f:IsObjectType('EditBox') then return end
    end
    -- a list's scroll bar is driven by the D-pad, not visited
    if f:IsObjectType('ScrollFrame') then return end
    for _, child in ipairs{f:GetChildren()} do
        collect(child, found)
    end
end

-- a popup on top of aux keeps the focus inside it: Settings, the quick search menu and the Filter
-- Builder's menu are aux's only frames in the DIALOG layer
local function find_popup(f)
    for _, child in ipairs{f:GetChildren()} do
        if child:IsVisible() and child ~= marker then
            if child:GetFrameStrata() == 'DIALOG' then return child end
            local popup = find_popup(child)
            if popup then return popup end
        end
    end
end

-- aux's own popup dialog in gamepad mode (made by create_dialog, below)
local dialog

local function root()
    -- aux's dialog comes first: it is made last, so a menu left open under it was found before it
    -- and the pad moved behind the dialog (review H-006, finding 4)
    if dialog and dialog:IsShown() then return dialog end
    return find_popup(frame) or frame
end

local function stops()
    local found = {}
    collect(root(), found)
    return found
end

-- An auction row (gui/auction_listing.lua) under the pad shows its item's tooltip beside aux's
-- window, where it covers no rows, and under it the item the player wears in that slot, so the two
-- read top to bottom (PR #41, nokkty). The mouse keeps the row's own tooltips. The comparison is
-- Blizzard's (GameTooltip_ShowCompareItem, as the row icon's hover uses): it shows only for gear
-- with something worn in its slot, and places ShoppingTooltip1 and 2 beside the item; aux moves
-- them under it.
local row_tooltip -- the row whose item tooltip is shown
local row_tooltip_side -- 'right' or 'left' of aux's window
local GAP = 2

local function is_auction_row(f)
    return f.rt ~= nil and f.record ~= nil and f.rt.ItemTooltip ~= nil
end

local function hide_shopping_tooltips()
    for _, name in ipairs{'ShoppingTooltip1', 'ShoppingTooltip2'} do
        if _G[name] then _G[name]:Hide() end
    end
end

local function stack_comparison()
    if not row_tooltip or not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= frame then return end
    local edge = row_tooltip_side == 'left' and 'RIGHT' or 'LEFT'
    local above = GameTooltip
    for _, name in ipairs{'ShoppingTooltip1', 'ShoppingTooltip2'} do
        local tip = _G[name]
        if tip and tip:IsShown() then
            tip:ClearAllPoints()
            tip:SetPoint('TOP' .. edge, above, 'BOTTOM' .. edge, 0, -GAP)
            above = tip
        end
    end
end

-- right of aux's window, or left of it when the screen has no room on the right
local function place_row_tooltip()
    GameTooltip:ClearAllPoints()
    local width = (GameTooltip:GetWidth() or 0) * (GameTooltip:GetEffectiveScale() or 1)
    for _, name in ipairs{'ShoppingTooltip1', 'ShoppingTooltip2'} do
        local tip = _G[name]
        if tip and tip:IsShown() then
            width = max(width, (tip:GetWidth() or 0) * (tip:GetEffectiveScale() or 1))
        end
    end
    local right = (frame:GetRight() or 0) * (frame:GetEffectiveScale() or 1)
    local screen = (UIParent:GetRight() or 0) * (UIParent:GetEffectiveScale() or 1)
    if right + width + GAP <= screen then
        row_tooltip_side = 'right'
        GameTooltip:SetPoint('TOPLEFT', frame, 'TOPRIGHT', GAP, 0)
    else
        row_tooltip_side = 'left'
        GameTooltip:SetPoint('TOPRIGHT', frame, 'TOPLEFT', -GAP, 0)
    end
    stack_comparison()
end

-- Blizzard places the comparison again when its item data arrives late: aux puts it back under.
-- Confirmed in Forever's UI source (Code, Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua).
local comparison_hooked
local function hook_comparison()
    if comparison_hooked then return end
    comparison_hooked = true
    local manager = _G.TooltipComparisonManager
    if manager and manager.AnchorShoppingTooltips then
        hooksecurefunc(manager, 'AnchorShoppingTooltips', function()
            if row_tooltip and GameTooltip:IsShown() and GameTooltip:GetOwner() == frame then
                place_row_tooltip()
            end
        end)
    end
end

local function show_row_tooltip(row)
    hook_comparison()
    row_tooltip = row
    if row.hover then row.hover:Show() end
    -- scrolling from gear to a trade good on the same row leaves prior comparison tooltips up unless cleared
    hide_shopping_tooltips()
    GameTooltip:SetOwner(frame, 'ANCHOR_NONE')
    row.rt:ItemTooltip(row)
    GameTooltip:Show()
    if GameTooltip_ShowCompareItem then GameTooltip_ShowCompareItem(GameTooltip) end
    place_row_tooltip()
end

local function hide_tooltip(f)
    if f and f == row_tooltip then
        row_tooltip = nil
        row_tooltip_side = nil
        hide_shopping_tooltips()
    end
    local leave = f and f:GetScript('OnLeave')
    if leave then leave(f) end
end

local function show_tooltip(f)
    if f and is_auction_row(f) then return show_row_tooltip(f) end
    -- a list scrolled past its last record leaves the row empty
    if f and f == row_tooltip then hide_tooltip(f) end
    local enter = f and f:GetScript('OnEnter')
    if enter then enter(f) end
end

local function set_focus(f)
    if focused == f then return end
    if focused then
        hide_tooltip(focused)
        if focused:IsObjectType('EditBox') and focused:HasFocus() then focused:ClearFocus() end
    end
    focused = f
    if f then
        marker:ClearAllPoints()
        marker:SetPoint('TOPLEFT', f, 'TOPLEFT', -3, 3)
        marker:SetPoint('BOTTOMRIGHT', f, 'BOTTOMRIGHT', 3, -3)
        marker:Show()
        show_tooltip(f)
    else
        marker:Hide()
    end
end
M.gamepad_set_focus = set_focus
function M.gamepad_focused() return focused end

local function first_stop()
    local best, best_top, best_left
    for _, f in ipairs(stops()) do
        if not in_top_bar(f) then
            local left, top = f:GetLeft(), f:GetTop()
            if not best or top > best_top + 4 or (abs(top - best_top) <= 4 and left < best_left) then
                best, best_top, best_left = f, top, left
            end
        end
    end
    return best
end

-- the nearest control in a direction: mostly along it, little to the side
local function nearest(from, direction)
    local x0, y0 = from:GetCenter()
    local best, best_score
    for _, f in ipairs(stops()) do
        if f ~= from then
            local x, y = f:GetCenter()
            local dx, dy = x - x0, y - y0
            local along, side
            if direction == 'up' then along, side = dy, abs(dx)
            elseif direction == 'down' then along, side = -dy, abs(dx)
            elseif direction == 'left' then along, side = -dx, abs(dy)
            else along, side = dx, abs(dy) end
            if along > 1 then
                local score = along + side * 2
                if not best or score < best_score then best, best_score = f, score end
            end
        end
    end
    return best
end

-- a list (search results, the Post tab's bag items) shows only the rows that fit: past the last one
-- shown, the D-pad scrolls it instead
local function scroll_bar_of(row)
    local list = row:GetParent() and row:GetParent():GetParent()
    if not list then return end
    for _, child in ipairs{list:GetChildren()} do
        if child:IsObjectType('ScrollFrame') then
            local name = child:GetName()
            local bar = child.ScrollBar
            if type(bar) ~= 'table' then
                bar = name and _G[name .. 'ScrollBar']
            end
            return type(bar) == 'table' and bar or nil
        end
    end
end

local function scroll(row, direction)
    local bar = scroll_bar_of(row)
    if not bar then return false end
    local before = bar:GetValue()
    local low, high = bar:GetMinMaxValues()
    local step = row:GetHeight()
    bar:SetValue(bounded(low, high, before + (direction == 'down' and step or -step)))
    return bar:GetValue() ~= before
end

local function inside(f, ancestor)
    while f do
        if f == ancestor then return true end
        f = f:GetParent()
    end
    return false
end

local top_bar_step -- defined below, with LB and RB

local function move(direction)
    if not usable(focused) or not inside(focused, root()) then
        set_focus(first_stop())
        return
    end
    if in_top_bar(focused) then
        if direction == 'down' then
            set_focus(first_stop())
        elseif direction == 'left' or direction == 'right' then
            top_bar_step(direction == 'left' and -1 or 1)
        end
        return
    end
    local target = nearest(focused, direction)
    local vertical = direction == 'up' or direction == 'down'
    -- leaving a list sideways is a move; leaving it up or down scrolls it while it can
    if vertical and (not target or target:GetParent() ~= focused:GetParent()) and scroll(focused, direction) then
        show_tooltip(focused)
        return
    end
    if target then set_focus(target) end
end

-- presses the control as a mouse click would; runs inside the pad press, a hardware event
local function press(f)
    if f:IsObjectType('EditBox') then
        f:SetFocus()
        return
    end
    if f:IsObjectType('Button') and f:GetScript('OnClick') then
        if f:IsEnabled() then f:Click('LeftButton') end
        return
    end
    local down, up = f:GetScript('OnMouseDown'), f:GetScript('OnMouseUp')
    if down then down(f, 'LeftButton') end
    if up then up(f, 'LeftButton') end
end

-- X: a right-click on the control, as the mouse would
local function press_right(f)
    if f:IsObjectType('Button') and f:GetScript('OnClick') then
        if f:IsEnabled() then f:Click('RightButton') end
        return
    end
    -- a text box clears on a right-click (gui.editbox)
    local down, up = f:GetScript('OnMouseDown'), f:GetScript('OnMouseUp')
    if down then down(f, 'RightButton') end
    if up then up(f, 'RightButton') end
end

-- Y: the main action of the tab that is open, by tab number (Search 1, Sniper 2, Post 3, Auctions 4,
-- Bids 5). The buy
-- bar's button is Buy; since 0.8.2.1 build 7 one press buys (Buy, then Confirm with Confirm before
-- buying on, 0.8.2.2: the same button, so Y presses it twice).
local QUICK_ACTIONS = {
    function() return require('aux.gui.buy_bar').primary_button end,
    function() return require('aux.tabs.sniper').run_button end,
    function() return require('aux.tabs.post').post_button end,
    function() return require('aux.tabs.auctions').cancel_button end,
    function() return require('aux.tabs.bids').buyout_button end,
}

local function quick_action()
    local find = QUICK_ACTIONS[tabs._selected or 0]
    local button = find and find()
    if button and button:IsVisible() and button:IsEnabled() then
        button:Click('LeftButton')
    end
end

-- an open dropdown menu (Category, Rarity, ...): it opens outside aux's window, so its options are
-- walked here
local menu, menu_items = gui.dropdown_menu, gui.dropdown_items
local menu_index

local function menu_open()
    return menu:IsShown() and menu.owner and menu.owner:HasFocus()
end

local function menu_count()
    local n = 0
    while menu_items[n + 1] and menu_items[n + 1]:IsShown() do n = n + 1 end
    return n
end

local function menu_move(step)
    local n = menu_count()
    if n == 0 then return end
    local current = menu_index or (menu.owner.GetIndex and menu.owner:GetIndex()) or (step > 0 and 0 or 2)
    menu_index = bounded(1, n, current + step)
    marker:ClearAllPoints()
    marker:SetPoint('TOPLEFT', menu_items[menu_index], 'TOPLEFT', -3, 3)
    marker:SetPoint('BOTTOMRIGHT', menu_items[menu_index], 'BOTTOMRIGHT', 3, -3)
end

local function menu_close()
    menu_index = nil
    if menu.owner then menu.owner:ClearFocus() end
    menu:Hide()
    if focused then set_focus(nil); set_focus(focused) end
end

local function menu_pick()
    local option = menu_index and menu_items[menu_index]
    menu_index = nil
    local owner_box = menu.owner
    if option then
        local down = option:GetScript('OnMouseDown')
        if down then down(option, 'LeftButton') end
    else
        menu_close()
    end
    -- back on the dropdown itself
    if owner_box then
        focused = nil
        set_focus(owner_box)
        if owner_box:HasFocus() then owner_box:ClearFocus() end
    end
end

-- A on a Sniper deal: the buy bar shows "Checking the auction..." first and its Buy button only once
-- the deal is confirmed, so the focus moves there when it shows (checked with the hints, four times a
-- second; given up after 5 seconds or at the next press). Y stays Start/Stop on the Sniper, so Y never
-- spends money there; B on the buy bar goes back to the deal.
local buy_jump, buy_return

local function buy_button()
    return require('aux.gui.buy_bar').primary_button
end

local function wait_for_buy(row)
    buy_jump = {row = row, until_time = GetTime() + 5}
end

function M.gamepad_poll()
    if not buy_jump then return end
    if GetTime() > buy_jump.until_time or tabs._selected ~= 2 then
        buy_jump = nil
        return
    end
    local buy = buy_button()
    if buy and buy:IsVisible() then
        buy_return = buy_jump.row
        buy_jump = nil
        set_focus(buy)
    end
end

local function sniper_deal(f)
    local list = require('aux.tabs.sniper').deals_list
    return tabs._selected == 2 and list and inside(f, list)
end

local function back()
    if buy_return and focused == buy_button() and usable(buy_return) then
        set_focus(buy_return)
        buy_return = nil
    elseif menu_open() then
        menu_close()
    elseif focused and focused:IsObjectType('EditBox') and focused:HasFocus() then
        local escape = focused:GetScript('OnEscapePressed')
        if escape then escape(focused) else focused:ClearFocus() end
    elseif root() ~= frame then
        root():Hide()
        set_focus(first_stop())
    else
        frame:Hide()
    end
end

-- LB and RB: the top bar, from the item that has the focus or else the selected tab
function top_bar_step(step)
    local items = top_bar()
    local index = tabs._selected or 1
    for i, item in ipairs(items) do
        if item == focused then index = i end
    end
    index = (index - 1 + step) % #items + 1
    local item = items[index]
    if index <= #tabs._tabs then
        if item.id ~= tabs._selected then
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            tabs:select(item.id)
        end
        set_focus(item)
    else
        set_focus(item)
    end
end

-- aux's popups (StaticPopupDialogs.AUX_*): in gamepad mode aux shows them in a dialog of its own
-- inside its window. A Blizzard popup is out of the pad's reach while aux holds the pad buttons, and
-- shown from aux's code it registers with Blizzard's gamepad navigation, which taints it (a blocked
-- popup was shown 259 times when the game froze). The dialog reads the same definition: text,
-- buttons, OnShow, OnAccept, OnCancel, OnHide, an edit box. The focus starts on the second button
-- (Cancel, No) when there is one: posting at a price the server warns about takes a deliberate move.
local function create_dialog()
    dialog = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
    gui.set_panel_style(dialog)
    dialog:SetFrameStrata('DIALOG')
    dialog:EnableMouse(true)
    gui.set_size(dialog, 380, 140)
    dialog:SetPoint('CENTER', frame, 'CENTER', 0, 40)
    dialog:Hide()
    local text = gui.label(dialog, gui.font_size.medium)
    text:SetPoint('TOPLEFT', 18, -18)
    text:SetPoint('TOPRIGHT', -18, -18)
    text:SetWordWrap(true)
    text:SetJustifyH('CENTER')
    text:SetTextColor(color.text.enabled())
    dialog.text = text
    local edit = gui.editbox(dialog)
    edit:SetPoint('TOPLEFT', text, 'BOTTOMLEFT', 0, -10)
    edit:SetPoint('TOPRIGHT', text, 'BOTTOMRIGHT', 0, -10)
    edit.enter = function() dialog.button1:Click() end
    dialog.editBox = edit
    for i = 1, 2 do
        local b = gui.button(dialog)
        gui.set_size(b, 130, 26)
        dialog['button' .. i] = b
    end
    dialog.button1:SetScript('OnClick', function()
        local def, data = dialog.def, dialog.data
        dialog.answered = true
        if def.OnAccept then def.OnAccept(dialog, data) end
        dialog:Hide()
    end)
    dialog.button2:SetScript('OnClick', function() dialog:Hide() end)
    -- closed any other way than Accept (Cancel, B): cancelled, as Blizzard's popup does on Escape
    dialog:SetScript('OnHide', function(self)
        local def, data = self.def, self.data
        if not def then return end
        if not self.answered and self.cancel_on_hide and def.OnCancel then def.OnCancel(self, data) end
        if def.OnHide then def.OnHide(self, data) end
        self.def, self.data, self.name = nil, nil, nil
    end)
end

function M.show_popup(name, text_arg1, text_arg2, data)
    local def = StaticPopupDialogs[name]
    if not gamepad_enabled() or not frame:IsShown() or not def then
        return StaticPopup_Show(name, text_arg1, text_arg2, data)
    end
    if not dialog then create_dialog() end
    if dialog:IsShown() then
        dialog.cancel_on_hide = false
        dialog:Hide()
    end
    dialog.def, dialog.data, dialog.name, dialog.answered, dialog.cancel_on_hide = def, data, name, false, true
    dialog.text:SetText(format(def.text, text_arg1 or '', text_arg2 or ''))
    local two = def.button2 ~= nil
    dialog.button1:SetText(def.button1 or OKAY)
    dialog.button2:SetText(def.button2 or '')
    if def.button1 == ACCEPT or def.button1 == 'Accept' or def.button1 == 'Yes' then
        gui.set_primary(dialog.button1)
    else
        gui.set_default(dialog.button1)
    end
    dialog.button1:ClearAllPoints()
    dialog.button2:ClearAllPoints()
    if two then
        dialog.button1:SetPoint('BOTTOMRIGHT', dialog, 'BOTTOM', -6, 16)
        dialog.button2:SetPoint('BOTTOMLEFT', dialog, 'BOTTOM', 6, 16)
        dialog.button2:Show()
    else
        dialog.button1:SetPoint('BOTTOM', 0, 16)
        dialog.button2:Hide()
    end
    if def.hasEditBox then dialog.editBox:Show() else dialog.editBox:Hide() end
    dialog.editBox:SetText('')
    local text_height = dialog.text:GetStringHeight() or 14
    gui.set_size(dialog, 380, 18 + text_height + (def.hasEditBox and 40 or 0) + 16 + 26 + 18)
    dialog:Show()
    if def.OnShow then def.OnShow(dialog, data) end
    -- a popup with a box (renaming a favorite) starts in the box its OnShow puts the cursor in, so A
    -- and B type and stop typing there instead of pressing Cancel (review H-006, finding 4)
    set_focus(def.hasEditBox and dialog.editBox or two and dialog.button2 or dialog.button1)
    return dialog
end

function M.hide_popup(name)
    if dialog and dialog:IsShown() and dialog.name == name then
        dialog.cancel_on_hide = false
        dialog:Hide()
    end
    StaticPopup_Hide(name)
end

local actions = {
    up = function() if menu_open() then menu_move(-1) else move('up') end end,
    down = function() if menu_open() then menu_move(1) else move('down') end end,
    left = function() if not menu_open() then move('left') end end,
    right = function() if not menu_open() then move('right') end end,
    A = function()
        if menu_open() then
            menu_pick()
        elseif usable(focused) and not inside(focused, root()) then
            -- a popup opened over the focused control: A never presses what is behind it
            set_focus(first_stop())
        elseif usable(focused) then
            -- a tab selected with LB/RB is already open: A goes into it
            if in_top_bar(focused) and focused.group == tabs then
                set_focus(first_stop())
            else
                local deal = sniper_deal(focused) and focused
                press(focused)
                -- the row's click hint follows the new state (Click: select, Click again: let go);
                -- uses show_tooltip so a row whose record cleared hides cleanly instead of erroring
                if focused and focused == row_tooltip then
                    if focused:IsVisible() then show_tooltip(focused) else hide_tooltip(focused) end
                end
                if deal then
                    wait_for_buy(deal)
                    gamepad_poll()
                end
            end
        else
            set_focus(first_stop())
        end
    end,
    B = back,
    X = function()
        if not menu_open() and usable(focused) and inside(focused, root()) then press_right(focused) end
    end,
    -- not while a popup or a dropdown is open: it would act behind it
    Y = function()
        if not menu_open() and root() == frame then quick_action() end
    end,
    LB = function() if menu_open() then menu_close() end; top_bar_step(-1) end,
    RB = function() if menu_open() then menu_close() end; top_bar_step(1) end,
}

-- Button hints: one strip under the window (chosen 2026-10-13, after icons at the tab bar and beside
-- the Y button were hard to see):
--   A <what A does>   B <what B does>   X <what X does>   Y <the tab's action>   LB RB Tabs
-- A, B and X are named for the control in focus; Y shows only while its button can be pressed.
-- Each button shows the controller's own icon (Xbox letters, PlayStation shapes, Switch), as PADChat
-- does: the icon's name comes from Blizzard's table for the controller in use
-- (InputIconTextureSetUtility, Blizzard_SharedXML/Shared/InputIcons/InputIconTexture.lua, build
-- 70374; a lookup that only reads). Without it, a badge: a dark box with a gold edge and the letter.
local PAD_KEYS = {A = 'PAD1', B = 'PAD2', X = 'PAD3', Y = 'PAD4', LB = 'PADLSHOULDER', RB = 'PADRSHOULDER'}
local BADGE = 22

local function atlas_for(key)
    local util = _G.InputIconTextureSetUtility
    if not util or not util.GetNormalActiveInputIconButtonTexture then return end
    local ok, atlas = pcall(util.GetNormalActiveInputIconButtonTexture, PAD_KEYS[key])
    if ok and type(atlas) == 'string' and atlas ~= '' then return atlas end
end

local function create_badge(parent, wide)
    local badge = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
    gui.set_size(badge, wide and BADGE + 12 or BADGE, BADGE)
    gui.set_frame_style(badge, color.input.background, color.accent.background, nil, nil, nil, nil, wide and 6 or BADGE / 2)
    badge.texture = badge:CreateTexture(nil, 'OVERLAY')
    badge.texture:SetPoint('CENTER')
    gui.set_size(badge.texture, wide and BADGE + 8 or BADGE + 4, BADGE + 4)
    badge.texture:Hide()
    badge.letters = badge:CreateFontString(nil, 'OVERLAY')
    badge.letters:SetFont(gui.font_bold, wide and gui.font_size.small or gui.font_size.medium)
    badge.letters:SetPoint('CENTER', 0, 0)
    badge.letters:SetTextColor(1, 1, 1)
    return badge
end

local function set_badge(badge, key)
    local atlas = atlas_for(key)
    if badge.key == key and badge.atlas == atlas then return end
    badge.key, badge.atlas = key, atlas
    local ok = atlas and pcall(badge.texture.SetAtlas, badge.texture, atlas)
    if ok then
        badge.texture:Show()
        badge.letters:SetText('')
        badge:SetBackdropColor(0, 0, 0, 0)
        badge:SetBackdropBorderColor(0, 0, 0, 0)
    else
        badge.texture:Hide()
        badge.letters:SetText(key)
        badge:SetBackdropColor(color.input.background())
        badge:SetBackdropBorderColor(color.accent.background())
    end
end

-- whether aux holds the pad buttons now (gamepad_bind, below)
local bound, unbind_after_combat

local HINT_KEYS = {'A', 'B', 'X', 'Y', 'LB'}
local hints
local function create_hints()
    hints = {items = {}}
    local strip = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
    gui.set_panel_style(strip)
    strip:SetPoint('TOPLEFT', frame, 'BOTTOMLEFT', 0, -2)
    strip:SetPoint('TOPRIGHT', frame, 'BOTTOMRIGHT', 0, -2)
    strip:SetHeight(BADGE + 12)
    hints.strip = strip
    for _, key in ipairs(HINT_KEYS) do
        local item = {badge = create_badge(strip, key == 'LB')}
        if key == 'LB' then
            item.badge2 = create_badge(strip, true)
            item.badge2:SetPoint('LEFT', item.badge, 'RIGHT', 4, 0)
        end
        item.label = gui.label(strip, gui.font_size.medium)
        item.label:SetPoint('LEFT', item.badge2 or item.badge, 'RIGHT', 6, 0)
        item.label:SetTextColor(color.text.enabled())
        hints.items[key] = item
    end
    -- buttons appear, light up and grey out without a pad press (a search ends, an item is picked):
    -- checked four times a second while the strip is shown, redrawn only on a change
    local next_check = 0
    strip:SetScript('OnUpdate', function()
        if GetTime() < next_check then return end
        next_check = GetTime() + .25
        gamepad_poll()
        update_hints()
    end)
end

-- what A, B and X do on the control in focus; nil leaves that hint out
local function hint_labels()
    if menu_open() then return 'Pick', 'Close', nil end
    local f = usable(focused) and focused or nil
    local typing = f and f:IsObjectType('EditBox') and f:HasFocus()
    local b = typing and 'Done' or (buy_return and f == buy_button()) and 'Back' or 'Close'
    if not f then return nil, b, nil end
    if typing then return nil, b, 'Clear' end
    if in_top_bar(f) then return f.group == tabs and 'Enter' or 'Press', b, nil end
    if f:IsObjectType('EditBox') then
        -- a dropdown is a text box with SetOptions of its own (gui.dropdown)
        return rawget(f, 'SetOptions') and 'Open' or 'Type', b, 'Clear'
    end
    return 'Select', b, 'Right-click'
end

local function quick_button()
    local find = QUICK_ACTIONS[tabs._selected or 0]
    local button = find and find()
    if button and button:IsVisible() and button:IsEnabled() and root() == frame and not menu_open() then
        return button
    end
end

-- Y's name: the tab's action. On Search Buy (one press buys since 0.8.2.1 build 7); on Sniper,
-- Start or Stop.
local Y_NAMES = {'Buy', 'Start', 'Post', 'Cancel', 'Buyout'}
local function y_label()
    local button = quick_button()
    if not button then return end
    local text = button:GetText() or ''
    if tabs._selected == 2 and text:find('^Stop') then return 'Stop' end
    -- Confirm before buying on (0.8.2.2): the second press confirms
    if tabs._selected == 1 and text:find('^Confirm') then return 'Confirm' end
    return Y_NAMES[tabs._selected]
end

function M.update_hints()
    if not hints then return end
    if not bound or not frame:IsShown() then
        hints.strip:Hide()
        return
    end
    hints.strip:Show()
    local a, b, x = hint_labels()
    local texts = {A = a, B = b, X = x, Y = y_label(), LB = 'Tabs'}
    -- left to right, the hints that apply now, each after the one before
    local previous
    for _, key in ipairs(HINT_KEYS) do
        local item, text = hints.items[key], texts[key]
        if text then
            set_badge(item.badge, key)
            if item.badge2 then set_badge(item.badge2, 'RB') end
            if item.label:GetText() ~= text then item.label:SetText(text) end
            if item.after ~= (previous or false) then
                item.after = previous or false
                item.badge:ClearAllPoints()
                if previous then
                    item.badge:SetPoint('LEFT', previous, 'RIGHT', 22, 0)
                else
                    item.badge:SetPoint('LEFT', hints.strip, 'LEFT', 12, 0)
                end
            end
            item.badge:Show(); item.label:Show()
            if item.badge2 then item.badge2:Show() end
            previous = item.label
        else
            item.badge:Hide(); item.label:Hide()
            if item.badge2 then item.badge2:Hide() end
        end
    end
end
M.gamepad_hints = function() return hints end

for _, entry in ipairs(KEYS) do
    local name = entry[1]
    local button = CreateFrame('Button', 'auxForeverPad' .. name, owner)
    button:RegisterForClicks('AnyDown')
    button:SetScript('OnClick', function()
        buy_jump = nil
        actions[name]()
        update_hints()
    end)
end


local function key_of(entry)
    return _G[entry[2]] or entry[3]
end

-- 0.8.2.1 (outside review 2026-11-10, R-19; Tyler, 2026-11-10: yes): when a fight starts while aux
-- holds the pad buttons, they go back to the game for the fight and come back to aux after it, if
-- aux is still open. They stayed with aux for the whole fight, since bindings cannot change in
-- combat. The event PLAYER_REGEN_DISABLED comes as a fight starts; on the modern client bindings
-- can still be changed while it is handled (Outside: known from retail addons, not seen on
-- Forever). aux only tries when the game says it is not locked yet (InCombatLockdown), so if that
-- does not hold on Forever nothing is called and it behaves as before.
local rebind_after_combat

function M.gamepad_bind()
    if bound or not gamepad_enabled() then return end
    if InCombatLockdown() then
        -- opened during a fight: aux takes the buttons once it is over
        rebind_after_combat = true
        owner:RegisterEvent('PLAYER_REGEN_ENABLED')
        return
    end
    for _, entry in ipairs(KEYS) do
        SetOverrideBindingClick(owner, true, key_of(entry), 'auxForeverPad' .. entry[1])
    end
    bound = true
    owner:RegisterEvent('PLAYER_REGEN_DISABLED')
end

function M.gamepad_unbind()
    if not bound then return end
    -- bindings cannot change in combat: they are given back once it ends
    if InCombatLockdown() then
        unbind_after_combat = true
        owner:RegisterEvent('PLAYER_REGEN_ENABLED')
        return
    end
    ClearOverrideBindings(owner)
    bound = false
    owner:UnregisterEvent('PLAYER_REGEN_DISABLED')
end

function M.gamepad_bound() return bound and true or false end

owner:SetScript('OnEvent', function(self, event)
    if event == 'PLAYER_REGEN_DISABLED' then
        -- a fight starts: the game gets its buttons back while that is still allowed
        if bound and not InCombatLockdown() then
            set_focus(nil)
            gamepad_unbind()
            rebind_after_combat = true
            self:RegisterEvent('PLAYER_REGEN_ENABLED')
            update_hints()
        end
    elseif event == 'PLAYER_REGEN_ENABLED' then
        self:UnregisterEvent('PLAYER_REGEN_ENABLED')
        local open = frame:IsShown() and not blizzard_frame_shown()
        if unbind_after_combat and not open then
            unbind_after_combat = false
            gamepad_unbind()
        end
        unbind_after_combat = false
        if rebind_after_combat then
            rebind_after_combat = false
            if open and not bound then
                gamepad_bind()
                if bound then
                    set_focus(first_stop())
                    if not hints then create_hints() end
                end
                update_hints()
            end
        end
    end
end)

-- one frame after aux shows: Blizzard sets up its own bindings for its window as it opens, and the
-- latest override may be the one that counts
frame:HookScript('OnShow', function()
    if not gamepad_enabled() then return end
    focused = nil
    local function start()
        if not frame:IsShown() then return end
        gamepad_bind()
        set_focus(first_stop())
        if not hints then create_hints() end
        update_hints()
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, start) else start() end
end)
frame:HookScript('OnHide', function()
    unbind_after_combat = false
    rebind_after_combat = false
    set_focus(nil)
    gamepad_unbind()
    update_hints()
end)

-- the Blizzard UI button shows Blizzard's window on top of aux: its own gamepad navigation drives it
-- then, so aux gives the pad buttons back until it is hidden again
do
    local set_shown = set_blizzard_frame_shown
    function M.set_blizzard_frame_shown(shown)
        set_shown(shown)
        if not gamepad_enabled() or not frame:IsShown() then return end
        if shown then
            set_focus(nil)
            gamepad_unbind()
        else
            gamepad_bind()
        end
        update_hints()
    end
end
