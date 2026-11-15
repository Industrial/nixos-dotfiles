select(2, ...) 'aux.tabs.sniper'

local aux = require 'aux'
local gui = require 'aux.gui'
local money = require 'aux.util.money'
local buy_bar = require 'aux.gui.buy_bar'

-- auxForever 0.8.3: the Standing Buy control, a small panel beside the window while the Sniper tab
-- is open. It keeps the best deal in the queue armed and buys it on one press, so a snipe no longer
-- needs the player to find its row, click it, wait for its auctions to be read, and click Buy.
--
-- What it cannot be, and why. Every auction purchase goes through C_AuctionHouse.PlaceBid (gear) or
-- C_AuctionHouse.StartCommoditiesPurchase (trade goods), and the auction house honours those two
-- only while the game is running code that a physical press started: a key, a mouse button, the
-- mouse wheel, a gamepad button. Called from a timer or an event handler they buy nothing at all.
-- One press is also allowed one such call, so there is no emptying the queue from a single press
-- either. aux therefore cannot buy for the player, and nothing here tries to: this control takes
-- the waiting out of a purchase, not the press.
--
-- What is left is worth having, because the press then costs nothing but the press:
--   * the queue (core.lua) already holds deals with their auction IDs and tiers, so no server
--     request sits between the press and the purchase
--   * a trade good's Confirm needs no press of its own (Settings: Confirm trade goods for me), so
--     one press buys it outright
--   * the mouse wheel over this panel is a press, and a wheel gives far more presses per second
--     than a finger on a mouse button: a flick of the wheel walks the queue
--   * the key binding (Bindings.xml; Key Bindings -> auxForever) works with the hand on the
--     keyboard and the eyes on the list
-- The limit the player actually meets is not the press but the auction house: place_bid takes one
-- purchase at a time and waits for the server to answer (aux-addon.lua), so purchases land about as
-- fast as the realm answers, however quickly the wheel turns.

-- A gear deal holds the Sniper's rounds while it is selected (holding, core.lua), because its
-- auction can only be bought while its own item search is the client's last one. Armed and not
-- bought within this long, it is let go so the rounds carry on looking, and it is passed over for
-- SKIP_SECONDS so it does not arm itself again at once.
local HOLD_SECONDS = 30
local SKIP_SECONDS = 60
-- how often the queue is read: judging every deal again (judge_record) is its cost, and the deals
-- table itself redraws no more than twice a second
local QUEUE_INTERVAL = .2
local WIDTH = 212
local PANEL_HEIGHT = 128
local TOP_OFFSET = -46 -- under the window's top bar

local armed -- the deal the buy bar is armed on
local armed_at
-- whether this control picked the armed deal, rather than the player clicking its row. Only a deal
-- this control picked is ever let go again: a row the player chose stays chosen.
local ours
-- Item key -> GetTime() from which that item may be armed again. By item key and not by record,
-- because a round replaces a deal's record with a fresh one and the hold would mean nothing. An
-- entry is dropped once it has run out and the item turns up again.
local skipped = {}
local next_queue = 0
local queue_length = 0

local function on()
    return aux.account_data.standing_buy and true or false
end

-- The quantity the bar buys for a trade good: every unit judged a deal, not the stack the bar
-- offers by default. Re-applied while a deal stays armed, because selecting it may read its
-- auctions first and the bar sets its own quantity when they arrive.
local function sync_quantity()
    if not armed or not armed.commodity or selected_deal() ~= armed then
        return
    end
    local units = deal_units(armed)
    if units >= 1 and buy_bar.buy_quantity() ~= units then
        buy_bar.set_buy_quantity(units)
    end
end

-- Whether a press right now would buy something. It is the buy bar's own answer (buy_bar.ready), so
-- this control and the Buy button under the table can never disagree about what is buyable.
local function ready()
    -- frame: the Sniper tab. The key binding works anywhere, so without this a press on another tab
    -- would buy whatever that tab's own Buy button is pointing at.
    return on() and frame:IsShown() and armed ~= nil and selected_deal() == armed and buy_bar.ready()
end

-- Runs inside a hardware event: the key binding, a click on this panel's Buy button, or the mouse
-- wheel over the panel. One purchase, never a loop over the queue -- see the note at the top.
local function fire()
    if not ready() then
        return
    end
    buy_bar.primary_click()
end

-- Keeps the best deal armed. Called from the panel's own OnUpdate, and again the moment a purchase
-- settles (aux.on_bid_idle), so the next target is armed without waiting for the next tick.
local function arm()
    -- never while a purchase is under way: the bar is mid-quote or mid-bid, and the selection must
    -- not move under it
    if buy_bar.busy() or aux.bid_in_progress() then
        return
    end
    local waiting = queue()
    queue_length = #waiting
    local selected = selected_deal()
    -- the player clicked a row themselves: that choice wins, and becomes the armed one
    if selected and selected ~= armed and buyable_deal(selected) then
        armed, armed_at, ours = selected, GetTime(), false
        sync_quantity()
        return
    end
    if armed and selected == armed and buyable_deal(armed) then
        if ours and not armed.commodity and GetTime() - armed_at > HOLD_SECONDS then
            if armed.deal_key then
                skipped[armed.deal_key] = GetTime() + SKIP_SECONDS
            end
            armed, armed_at, ours = nil, nil, nil
            deselect_deal()
            return
        end
        sync_quantity()
        return
    end
    -- nothing armed, or what was armed is bought or gone: take the head of the queue
    armed, armed_at = nil, nil
    for _, deal in ipairs(waiting) do
        local held = deal.deal_key and skipped[deal.deal_key]
        if held and GetTime() > held then
            skipped[deal.deal_key] = nil
            held = nil
        end
        if not held then
            armed, armed_at = deal, GetTime()
            break
        end
    end
    if armed then
        ours = true
        select_deal(armed)
        sync_quantity()
    elseif ours then
        -- only what this control selected is cleared; a row the player is reading stays selected
        ours = nil
        deselect_deal()
    end
end

-- the panel ---------------------------------------------------------------------------------------

-- Parented to the Sniper tab's frame through a holder, so closing the tab hides the panel with it
-- and stops the work below. The panel is placed outside the window; child frames are not clipped to
-- their parent.
local holder = CreateFrame('Frame', nil, frame)
holder:SetAllPoints(frame)

local panel = gui.panel(holder)
panel:SetFrameStrata('DIALOG')
gui.set_size(panel, WIDTH, PANEL_HEIGHT)
panel:EnableMouse(true)
panel:EnableMouseWheel(true)
panel:SetScript('OnMouseWheel', function() fire() end)
panel:Hide()
M.standing_buy_panel = panel

-- Beside the window, on whichever side has room. Worked out whenever the panel is shown, because
-- the window can be moved, resized or scaled at any time.
local function place()
    panel:ClearAllPoints()
    local right = aux.frame:GetRight()
    local scale = aux.frame:GetEffectiveScale()
    local screen = scale > 0 and GetScreenWidth() * UIParent:GetEffectiveScale() / scale or nil
    if right and screen and right + WIDTH + 8 > screen then
        panel:SetPoint('TOPRIGHT', aux.frame, 'TOPLEFT', -6, TOP_OFFSET)
    else
        panel:SetPoint('TOPLEFT', aux.frame, 'TOPRIGHT', 6, TOP_OFFSET)
    end
end
place() -- so the panel has an anchor before it is ever shown

local title = gui.label(panel, gui.font_size.small)
title:SetPoint('TOPLEFT', 10, -10)
gui.themed(function() title:SetText(aux.color.accent.background('STANDING BUY')) end)

local count_label = gui.label(panel, gui.font_size.small)
count_label:SetPoint('TOPRIGHT', -28, -10)
count_label:SetJustifyH('RIGHT')

-- hides the panel; it comes back from Settings or /aux standing buy
local close_button = gui.button(panel, gui.font_size.small)
gui.set_size(close_button, 16, 16)
close_button:SetPoint('TOPRIGHT', -8, -7)
close_button:SetText('x')
close_button:SetScript('OnClick', function()
    aux.account_data.standing_buy = false
    aux.refresh_settings()
end)
close_button:SetScript('OnEnter', function(self)
    GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
    GameTooltip:AddLine('Hide Standing Buy')
    GameTooltip:AddLine('Bring it back in Settings, or with /aux standing buy.', 1, 1, 1, true)
    GameTooltip:Show()
end)
close_button:SetScript('OnLeave', function() GameTooltip:Hide() end)

local name_label = gui.label(panel, gui.font_size.medium)
name_label:SetPoint('TOPLEFT', 10, -28)
name_label:SetPoint('TOPRIGHT', -10, -28)
name_label:SetJustifyH('LEFT')

local detail_label = gui.label(panel, gui.font_size.small)
detail_label:SetPoint('TOPLEFT', 10, -46)
detail_label:SetPoint('TOPRIGHT', -10, -46)
detail_label:SetJustifyH('LEFT')

local buy_button = gui.button(panel, gui.font_size.medium)
buy_button:SetPoint('TOPLEFT', 10, -62)
buy_button:SetPoint('TOPRIGHT', -10, -62)
buy_button:SetHeight(32)
buy_button:SetScript('OnClick', function() fire() end)
buy_button:SetScript('OnEnter', function(self)
    GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
    GameTooltip:AddLine('Buy the armed deal')
    GameTooltip:AddLine('One deal per press: the auction house takes a purchase only from a real key, click or wheel turn, and only one per press. Press again for the next deal in the queue.', 1, 1, 1, true)
    GameTooltip:AddLine('The mouse wheel over this panel buys too, and gives the most presses per second.', .6, .6, .6, true)
    GameTooltip:Show()
end)
buy_button:SetScript('OnLeave', function() GameTooltip:Hide() end)
M.standing_buy_button = buy_button

local hint_label = gui.label(panel, gui.font_size.small)
hint_label:SetPoint('TOPLEFT', 10, -99)
hint_label:SetPoint('TOPRIGHT', -10, -99)
hint_label:SetJustifyH('LEFT')

-- A named button for the key binding: Bindings.xml runs auxForeverStandingBuy:Click('LeftButton')
-- and gui.button makes unnamed frames. Parented to UIParent and always there, so the binding works
-- whatever has focus; fire() is what decides whether there is anything to buy. Off screen and with
-- the mouse turned off, so it is never in the way.
local binding_button = CreateFrame('Button', 'auxForeverStandingBuy', UIParent)
gui.set_size(binding_button, 1, 1)
binding_button:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', -20, 20)
binding_button:EnableMouse(false)
binding_button:SetScript('OnClick', function() fire() end)

_G.BINDING_HEADER_AUXFOREVER = 'auxForever'
_G.BINDING_NAME_AUXFOREVER_STANDING_BUY = 'Standing Buy (Sniper)'

local function binding_text()
    local key = GetBindingKey('AUXFOREVER_STANDING_BUY')
    if not key or key == '' then
        return
    end
    local ok, pretty = pcall(GetBindingText, key, 'KEY_')
    return ok and type(pretty) == 'string' and pretty ~= '' and pretty or key
end

-- the rule that found it, in the words of the table's Why column
local REASONS = {vendor = 'below vendor', disenchant = 'disenchant', market = 'under market', usual = 'under usual'}

local function describe(record)
    local parts = {}
    local units = deal_units(record)
    if units > 1 then
        tinsert(parts, units .. ' units')
    end
    tinsert(parts, money.to_string(ceil(record.unit_buyout_price), true) .. ' each')
    tinsert(parts, REASONS[record.deal_reason] or 'deal')
    return aux.color.label.enabled(table.concat(parts, ' · '))
end

local last_label, last_enabled

-- what the button says, and whether a press would do anything
local function button_state()
    if not armed then
        return 'Nothing to buy', false
    elseif aux.bid_in_progress() then
        return 'Buying...', false
    elseif selected_deal() ~= armed then
        return 'Arming...', false
    elseif buy_bar.ready() then
        local total = buy_bar.ready_total() or deal_cost(armed)
        return 'Buy ' .. money.to_string(total, true), true
    elseif buy_bar.busy() then
        return 'Buying...', false
    end
    return 'Reading its auctions...', false
end

local function draw()
    local more = armed and queue_length - 1 or queue_length
    count_label:SetText(more > 0 and aux.color.label.enabled(more .. ' more') or '')

    if armed then
        local quality = ITEM_QUALITY_COLORS[armed.quality or 1] or ITEM_QUALITY_COLORS[1]
        name_label:SetText(armed.name or '')
        name_label:SetTextColor(quality.r, quality.g, quality.b)
        detail_label:SetText(describe(armed))
    else
        name_label:SetText('Nothing to buy')
        name_label:SetTextColor(aux.color.label.enabled())
        detail_label:SetText(aux.color.label.disabled(running and 'Watching for deals' or 'Press Start on the Sniper'))
    end

    local label, enabled = button_state()
    -- redrawn only when it changes: a button re-styled every tick can drop a press that is under way
    if label ~= last_label then
        last_label = label
        buy_button:SetText(label)
    end
    if enabled ~= last_enabled then
        last_enabled = enabled
        if enabled then
            buy_button:Enable()
            gui.set_primary(buy_button)
        else
            buy_button:Disable()
            gui.set_default(buy_button)
            -- set_primary leaves the label bold; put it back (as the Sniper's Start button does)
            local _, size = buy_button:GetFontString():GetFont()
            buy_button:GetFontString():SetFont(gui.font, size and size > 0 and size or gui.font_size.medium)
        end
    end

    local key = binding_text()
    hint_label:SetText(key
        and aux.color.label.enabled(key) .. aux.color.label.disabled(' · or scroll here')
        or aux.color.label.disabled('No key bound · Key Bindings → auxForever'))
end

holder:SetScript('OnUpdate', function()
    if not on() then
        if panel:IsShown() then
            panel:Hide()
        end
        return
    end
    if not panel:IsShown() then
        panel:Show()
    end
    if GetTime() >= next_queue then
        next_queue = GetTime() + QUEUE_INTERVAL
        -- worked out each time rather than once: the window can be moved, resized or scaled at any
        -- moment, and which side of it has room changes with that. Two getters and a SetPoint.
        place()
        arm()
        draw()
    end
end)

-- The moment a purchase settles, the next deal is armed, rather than waiting out the tick: gear
-- goes through place_bid (aux.on_bid_idle), trade goods answer with their own events.
function aux.event.AUX_LOADED()
    local function poke()
        next_queue = 0
    end
    aux.on_bid_idle(poke)
    aux.event_listener('COMMODITY_PURCHASE_SUCCEEDED', poke)
    aux.event_listener('COMMODITY_PURCHASE_FAILED', poke)
end
