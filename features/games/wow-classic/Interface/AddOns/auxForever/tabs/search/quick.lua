select(2, ...) 'aux.tabs.search'

local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local gui = require 'aux.gui'

-- auxForever: quick searches. The clock button next to "<" opens a menu of pinned searches (aux's
-- favorites, so they also stay on the Saved Searches tab) and recent searches, each with the
-- item's icon, the cheapest price the last search found and when. One click searches again; the
-- pin on a row pins or unpins it.

local TEXTURES = [[Interface\AddOns\auxForever\textures\]]
local MENU_WIDTH = 380
local ROW_HEIGHT = 36
local MAX_PINNED_ROWS = 5
local MAX_RECENT_ROWS = 7

local menu, rows, recent_offset = nil, {}, 0
M.quick_menu_rows = rows

-- Remember what a finished search found: the cheapest price per item (other players' auctions),
-- the item when the search found only one, and when. Kept on the recent and pinned entries.
function M.remember_search_result(filter_string, records)
    local cheapest, item_id, single = nil, nil, true
    for _, record in ipairs(records or empty) do
        local price = record.unit_buyout_price
        if not record.own and price and price > 0 and (not cheapest or price < cheapest) then
            cheapest = price
        end
        if item_id and record.item_id ~= item_id then
            single = false
        end
        item_id = item_id or record.item_id
    end
    for _, list in ipairs{recent_searches or empty, favorite_searches or empty} do
        for _, entry in ipairs(list) do
            if entry.filter_string == filter_string then
                entry.last_time = time()
                entry.last_price = cheapest
                entry.item_id = single and item_id or nil
                if entry.recipe then
                    local cost, missing, net = recipe_costs(entry.recipe, records)
                    entry.last_profit = net and not missing and net - cost or nil
                end
            end
        end
    end
    if menu and menu:IsShown() then
        update_quick_menu()
    end
end

function M.time_ago(t)
    local seconds = time() - t
    if seconds < 60 then
        return 'just now'
    elseif seconds < 3600 then
        return floor(seconds / 60) .. 'm ago'
    elseif seconds < 86400 then
        return floor(seconds / 3600) .. 'h ago'
    elseif seconds < 2 * 86400 then
        return 'yesterday'
    end
    return floor(seconds / 86400) .. ' days ago'
end

-- the second line of a row
function M.quick_entry_detail(entry)
    if not entry.last_time then
        return 'Search again to see prices'
    elseif entry.recipe and entry.last_profit then
        local amount = money.to_string(abs(entry.last_profit), true)
        return (entry.last_profit >= 0 and 'Profit ' or 'Loss ') .. amount .. ', ' .. time_ago(entry.last_time)
    elseif entry.recipe then
        return (entry.recipe.crate and 'Crate, ' or 'Recipe, ') .. time_ago(entry.last_time)
    elseif entry.last_price then
        return 'Cheapest ' .. money.to_string(entry.last_price, true) .. ', ' .. time_ago(entry.last_time)
    elseif entry.item_id then
        return 'None for sale, ' .. time_ago(entry.last_time)
    end
    return 'Filter search, ' .. time_ago(entry.last_time)
end

local function find(list, filter_string)
    for i, entry in ipairs(list) do
        if entry.filter_string == filter_string then
            return i, entry
        end
    end
end

function M.is_pinned(entry)
    return find(favorite_searches, entry.filter_string) ~= nil
end

function M.pin_search(entry)
    if not is_pinned(entry) then
        tinsert(favorite_searches, 1, entry)
    end
    update_search_listings()
    update_quick_menu()
end

-- an unpinned search goes back to the recent list, so it is never lost by a click
function M.unpin_search(entry)
    local i = find(favorite_searches, entry.filter_string)
    while i do
        tremove(favorite_searches, i)
        i = find(favorite_searches, entry.filter_string)
    end
    if not find(recent_searches, entry.filter_string) then
        tinsert(recent_searches, 1, entry)
        while #recent_searches > 50 do
            tremove(recent_searches)
        end
    end
    update_search_listings()
    update_quick_menu()
end

local function create_row()
    local row = CreateFrame('Button', nil, menu)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForClicks('LeftButtonUp')
    row.highlight = gui.add_highlight(row, 6, 1, 1, 1, .07)

    local icon = row:CreateTexture(nil, 'ARTWORK')
    icon:SetSize(26, 26)
    icon:SetPoint('LEFT', 8, 0)
    row.icon = icon

    local name = gui.label(row, gui.font_size.medium)
    name:SetPoint('TOPLEFT', icon, 'TOPRIGHT', 10, -1)
    name:SetPoint('RIGHT', -40, 0)
    name:SetJustifyH('LEFT')
    row.name = name

    local detail = gui.label(row, gui.font_size.small)
    detail:SetPoint('BOTTOMLEFT', icon, 'BOTTOMRIGHT', 10, 0)
    detail:SetPoint('RIGHT', -40, 0)
    detail:SetJustifyH('LEFT')
    gui.text_color(detail, aux.color.label.enabled)
    row.detail = detail

    local pin = CreateFrame('Button', nil, row)
    pin:SetSize(28, 28)
    pin:SetPoint('RIGHT', -4, 0)
    gui.add_highlight(pin, 5, 1, 1, 1, .1)
    pin.texture = pin:CreateTexture(nil, 'ARTWORK')
    pin.texture:SetSize(16, 16)
    pin.texture:SetPoint('CENTER')
    pin:SetScript('OnClick', function()
        if is_pinned(row.entry) then
            unpin_search(row.entry)
        else
            pin_search(row.entry)
        end
    end)
    pin:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        GameTooltip:AddLine(is_pinned(row.entry) and 'Unpin' or 'Pin to the top')
        GameTooltip:Show()
    end)
    pin:SetScript('OnLeave', function() GameTooltip:Hide() end)
    row.pin = pin

    -- the pin of a recent search shows while the mouse is over its row; alpha, not Hide, so a
    -- click that starts on it is never dropped
    row:SetScript('OnUpdate', function(self)
        local shown = self.pinned or self:IsMouseOver()
        if shown ~= self.pin_shown then
            self.pin_shown = shown
            self.pin:SetAlpha(shown and 1 or 0)
        end
    end)
    row:SetScript('OnClick', function(self)
        menu:Hide()
        set_filter(self.entry.filter_string)
        execute()
    end)
    return row
end

local function fill_row(row, entry, pinned)
    row.entry, row.pinned = entry, pinned
    local item_id = entry.recipe and (entry.recipe.output and entry.recipe.output.item_id or entry.recipe.item_id) or entry.item_id
    local item = item_id and info.item(item_id)
    if entry.recipe then
        -- a recipe search: the made item's icon and "Recipe  Colorful Kilt  (3 materials)" (a crate
        -- search: the crate's icon and "Crate  Journeyman Textiles  (3 bundles)")
        if item then
            row.icon:SetTexture(item.texture)
            row.icon:SetTexCoord(.07, .93, .07, .93)
            row.icon:SetVertexColor(1, 1, 1)
        else
            row.icon:SetTexture(TEXTURES .. 'funnel.tga')
            row.icon:SetTexCoord(0, 1, 0, 1)
            row.icon:SetVertexColor(aux.color.label.enabled())
        end
        row.name:SetText(recipe_entry_name(entry))
        row.name:SetTextColor(aux.color.text.enabled())
    elseif item then
        row.icon:SetTexture(item.texture)
        row.icon:SetTexCoord(.07, .93, .07, .93)
        row.icon:SetVertexColor(1, 1, 1)
        row.name:SetText(item.name)
        local color = ITEM_QUALITY_COLORS[item.quality] or ITEM_QUALITY_COLORS[1]
        row.name:SetTextColor(color.r, color.g, color.b)
    else
        row.icon:SetTexture(TEXTURES .. 'funnel.tga')
        row.icon:SetTexCoord(0, 1, 0, 1)
        row.icon:SetVertexColor(aux.color.label.enabled())
        row.name:SetText(entry.filter_name or entry.prettified or entry.filter_string)
        row.name:SetTextColor(aux.color.text.enabled())
    end
    row.detail:SetText(quick_entry_detail(entry))
    row.pin.texture:SetTexture(TEXTURES .. (pinned and 'pin-filled.tga' or 'pin.tga'))
    if pinned then
        row.pin.texture:SetVertexColor(aux.color.accent.background())
    else
        row.pin.texture:SetVertexColor(aux.color.label.enabled())
    end
end

local function label(text, size, color)
    local l = gui.label(menu, size)
    l:SetText(text)
    gui.text_color(l, color)
    return l
end

local function create_menu()
    menu = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
    gui.set_panel_style(menu)
    M.quick_menu = menu
    menu:SetFrameStrata('DIALOG')
    menu:SetClampedToScreen(true)
    menu:SetWidth(MENU_WIDTH)
    menu:SetPoint('TOPLEFT', history_button, 'BOTTOMLEFT', 0, -4)
    menu:EnableMouse(true)
    menu:EnableMouseWheel(true)
    menu:SetScript('OnMouseWheel', function(_, delta)
        recent_offset = recent_offset - delta
        update_quick_menu()
    end)
    menu:SetScript('OnShow', function()
        recent_offset = 0
        update_quick_menu()
        gui.set_selected(history_button, true)
    end)
    menu:SetScript('OnHide', function()
        gui.set_default(history_button)
    end)
    -- a click anywhere else closes the menu
    pcall(menu.RegisterEvent, menu, 'GLOBAL_MOUSE_DOWN')
    menu:SetScript('OnEvent', function(self)
        if self:IsShown() and not self:IsMouseOver() and not history_button:IsMouseOver() then
            self:Hide()
        end
    end)
    menu:Hide()
    -- closes with the search tab and the window, so it does not reappear when they open again
    frame:HookScript('OnHide', function() menu:Hide() end)

    menu.pinned_header = label('PINNED', gui.font_size.small, aux.color.accent.background)
    menu.pinned_count = label('', gui.font_size.small, aux.color.label.disabled)
    menu.no_pins = label('Pin a search below to keep it here.', gui.font_size.small, aux.color.label.enabled)
    menu.divider1 = menu:CreateTexture(nil, 'ARTWORK')
    gui.texture_color(menu.divider1, aux.color.window.border)
    menu.divider1:SetHeight(1)
    menu.recent_header = label('RECENT', gui.font_size.small, aux.color.label.enabled)
    menu.recent_count = label('last 50 kept, scroll for more', gui.font_size.small, aux.color.label.disabled)
    menu.no_recent = label('Your searches show up here, the last 50 are kept.', gui.font_size.small, aux.color.label.enabled)
    menu.divider2 = menu:CreateTexture(nil, 'ARTWORK')
    gui.texture_color(menu.divider2, aux.color.window.border)
    menu.divider2:SetHeight(1)
    menu.hint = label('Click to search again. Pin keeps it at the top.', gui.font_size.small, aux.color.label.disabled)
    local saved = gui.button(menu, gui.font_size.small)
    gui.set_size(saved, 100, 22)
    saved:SetText('Saved Searches')
    gui.themed(function()
        saved:SetBackdropColor(0, 0, 0, 0)
        saved:SetBackdropBorderColor(0, 0, 0, 0)
        saved:GetFontString():SetTextColor(aux.color.accent.background())
    end)
    saved:SetScript('OnClick', function()
        menu:Hide()
        set_subtab(SAVED)
    end)
    menu.saved_button = saved
end

local function place(region, y, x, right)
    region:ClearAllPoints()
    region:SetPoint('TOPLEFT', menu, 'TOPLEFT', x or 8, -y)
    if right ~= false then
        region:SetPoint('TOPRIGHT', menu, 'TOPRIGHT', -(right or 8), -y)
    end
end

function M.update_quick_menu()
    if not menu or not menu:IsShown() then return end

    local pinned = {}
    for i = 1, min(#favorite_searches, MAX_PINNED_ROWS) do
        tinsert(pinned, favorite_searches[i])
    end
    local recent = {}
    for _, entry in ipairs(recent_searches) do
        if not is_pinned(entry) then
            tinsert(recent, entry)
        end
    end
    recent_offset = max(0, min(recent_offset, #recent - MAX_RECENT_ROWS))

    local y, used = 10, 0
    local function next_row(entry, is_pin)
        used = used + 1
        rows[used] = rows[used] or create_row()
        local row = rows[used]
        fill_row(row, entry, is_pin)
        place(row, y, 4, 4)
        row:Show()
        y = y + ROW_HEIGHT + 2
    end

    place(menu.pinned_header, y, 12, false)
    menu.pinned_count:ClearAllPoints()
    menu.pinned_count:SetPoint('TOPRIGHT', menu, 'TOPRIGHT', -12, -y)
    menu.pinned_count:SetText(#favorite_searches .. ' pinned')
    y = y + 18
    if #pinned == 0 then
        place(menu.no_pins, y, 12)
        menu.no_pins:Show()
        y = y + 22
    else
        menu.no_pins:Hide()
        for _, entry in ipairs(pinned) do
            next_row(entry, true)
        end
    end

    y = y + 4
    place(menu.divider1, y, 6, 6)
    y = y + 9
    place(menu.recent_header, y, 12, false)
    menu.recent_count:ClearAllPoints()
    menu.recent_count:SetPoint('TOPRIGHT', menu, 'TOPRIGHT', -12, -y)
    menu.recent_count:SetShown(#recent > MAX_RECENT_ROWS)
    y = y + 18
    if #recent == 0 then
        place(menu.no_recent, y, 12)
        menu.no_recent:Show()
        y = y + 22
    else
        menu.no_recent:Hide()
        for i = recent_offset + 1, min(#recent, recent_offset + MAX_RECENT_ROWS) do
            next_row(recent[i], false)
        end
    end

    for i = used + 1, #rows do
        rows[i]:Hide()
    end

    y = y + 4
    place(menu.divider2, y, 6, 6)
    y = y + 7
    place(menu.hint, y + 4, 12, false)
    menu.saved_button:ClearAllPoints()
    menu.saved_button:SetPoint('TOPRIGHT', menu, 'TOPRIGHT', -6, -y)
    y = y + 28
    menu:SetHeight(y)
end

function M.toggle_quick_menu()
    if not menu then
        create_menu()
    end
    if menu:IsShown() then
        menu:Hide()
    else
        menu:Show()
    end
end

function M.hide_quick_menu()
    if menu then
        menu:Hide()
    end
end
