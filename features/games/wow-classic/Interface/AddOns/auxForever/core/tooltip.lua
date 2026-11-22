select(2, ...) 'aux.core.tooltip'

local aux = require 'aux'
local info = require 'aux.util.info'
local money =  require 'aux.util.money'
local disenchant = require 'aux.core.disenchant'
local history = require 'aux.core.history'
local gui = require 'aux.gui'
local search_tab = require 'aux.tabs.search'

local UNKNOWN = GRAY_FONT_COLOR_CODE .. '?' .. FONT_COLOR_CODE_CLOSE


local function is_secret(value)
    return issecretvalue and issecretvalue(value)
end

-- Forever: item tooltips are built through TooltipDataProcessor, so one post-call replaces the
-- per-method GameTooltip hooks of Classic aux. The quantity is read from the call that filled the
-- tooltip, where the item's stack size is known.
local quantity_getters = {
    GetBagItem = function(bag, slot)
        local item = C_Container.GetContainerItemInfo(bag, slot)
        return item and item.stackCount
    end,
    GetInventoryItem = function(unit, slot)
        return GetInventoryItemCount(unit, slot)
    end,
    GetLootItem = function(slot)
        return select(3, GetLootSlotInfo(slot))
    end,
    GetMerchantItem = function(slot)
        return select(4, GetMerchantItemInfo(slot))
    end,
    GetBuybackItem = function(slot)
        return select(4, GetBuybackItemInfo(slot))
    end,
    GetInboxItem = function(message_index, attachment_index)
        return select(4, GetInboxItem(message_index, attachment_index))
    end,
    GetSendMailItem = function(attachment_index)
        return select(4, GetSendMailItem(attachment_index))
    end,
    GetGuildBankItem = function(tab, slot)
        return select(2, GetGuildBankItemInfo(tab, slot))
    end,
    GetTradePlayerItem = function(slot)
        return select(3, GetTradePlayerItemInfo(slot))
    end,
    GetTradeTargetItem = function(slot)
        return select(3, GetTradeTargetItemInfo(slot))
    end,
    GetQuestItem = function(quest_type, item_index)
        return select(3, GetQuestItemInfo(quest_type, item_index))
    end,
    GetQuestLogItem = function(quest_type, item_index)
        if quest_type == 'choice' then
            return select(3, GetQuestLogChoiceInfo(item_index))
        end
        return select(3, GetQuestLogRewardInfo(item_index))
    end,
}

local function tooltip_quantity(tooltip)
    local processing_info = tooltip.processingInfo
    local getter = processing_info and quantity_getters[processing_info.getterName]
    if getter and processing_info.getterArgs then
        local ok, quantity = pcall(getter, unpack(processing_info.getterArgs, 1, processing_info.getterArgs.n or #processing_info.getterArgs))
        if ok and not is_secret(quantity) and type(quantity) == 'number' and quantity > 0 then
            return quantity
        end
    end
    return 1
end

-- 0.9 (FB-056, user_kc0ds7pqedmptpep): read the link from tooltip data with secret-value guards
-- before falling back to pcall(tooltip.GetItem). Blizzard's TooltipUtil.GetDisplayedItem calls
-- C_Item.GetItemLinkByGUID and GetItemInfo without checking issecretvalue first.
local function tooltip_link(tooltip, data)
    local link
    if type(data) == 'table' then
        if data.hyperlink ~= nil then
            if is_secret(data.hyperlink) then
                return nil
            end
            link = data.hyperlink
        elseif data.guid ~= nil then
            if is_secret(data.guid) then
                return nil
            end
            if C_Item and C_Item.GetItemLinkByGUID then
                local ok, resolved = pcall(C_Item.GetItemLinkByGUID, data.guid)
                if ok and type(resolved) == 'string' and not is_secret(resolved) then
                    link = resolved
                end
            end
        end
    end
    if not link and tooltip.GetItem then
        local ok, _, item_link = pcall(tooltip.GetItem, tooltip)
        if ok then
            link = item_link
        end
    end
    if type(link) ~= 'string' or is_secret(link) or not strfind(link, 'item:', 1, true) then
        return nil
    end
    return link
end

function aux.event.AUX_LOADED()
    settings = aux.character_data.tooltip
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
            return
        end
        if tooltip.IsForbidden and tooltip:IsForbidden() then
            return
        end
        local link = tooltip_link(tooltip, data)
        if not link then
            return
        end
        extend_tooltip(tooltip, link, tooltip_quantity(tooltip), data)
    end)
end

-- auxForever: whether an item can be auctioned is read from a hidden tooltip of the item, which
-- the game has to build. aux did that on every hover of every item, anywhere in the game; the
-- answer never changes for an item, so it is kept (one entry per item hovered).
local auctionable_cache = {}

function M.is_auctionable(item_id, item_info)
    local known = auctionable_cache[item_id]
    if known == nil then
        known = info.auctionable(info.tooltip('link', item_info.link), item_info.quality) and true or false
        auctionable_cache[item_id] = known
    end
    return known
end

-- auxForever (0.5): how fresh the usual price is, after Value: "  today", "  3d", gray, darker when
-- the newest price is a week old or more (0.9 build 3, Tyler Option B: compact age, no "for N")
function M.age_suffix(age)
    local text = history.short_age_text(age)
    if not text then
        return ''
    end
    local color = age >= history.OLD_DAYS and aux.color.label.disabled or aux.color.label.enabled
    return '  ' .. color(text)
end

function extend_tooltip(tooltip, link, quantity, data)
    local item_id, suffix_id = info.parse_link(link)
    -- 0.9 (FB-058, jebbush; Tyler): full stack by default, hold Shift for 1 item.
    -- Turning /aux tooltip stack off restores 1 item by default and Shift for the stack.
    local stack_default = settings.stack ~= false
    local show_stack = stack_default and not IsShiftKeyDown() or not stack_default and IsShiftKeyDown()
    quantity = show_stack and quantity or 1
    -- 0.9 build 3 (Tyler): keep tooltip lines minimal with no "for N" suffix
    local per = ''
    local item_info = info.item(item_id)
    -- auxForever: the disenchant table is only worked out when one of its lines is shown
    if item_info and (settings.disenchant_distribution or settings.disenchant_value) then
        local distribution = disenchant.distribution(item_info.slot, item_info.quality, item_info.level)
        if #distribution > 0 then
            if settings.disenchant_distribution then
                tooltip:AddLine('Disenchants into:', aux.color.tooltip.disenchant.distribution())
                sort(distribution, function(a,b) return a.probability > b.probability end)
                for _, event in ipairs(distribution) do
                    tooltip:AddLine(format('  %s%% %s (%s-%s)', event.probability * 100, info.display_name(event.item_id, true) or 'item:' .. event.item_id, event.min_quantity, event.max_quantity), aux.color.tooltip.disenchant.distribution())
                end
            end
            if settings.disenchant_value then
                local disenchant_value = disenchant.value(item_info.slot, item_info.quality, item_info.level)
                if settings.money_icons then
                    tooltip:AddLine('Disenchant: ' .. (disenchant_value and GetCoinTextureString(disenchant_value) or UNKNOWN), aux.color.tooltip.disenchant.value())
                else
                    tooltip:AddLine('Disenchant: ' .. (disenchant_value and money.to_string2(disenchant_value) or UNKNOWN), aux.color.tooltip.disenchant.value())
                end
            end
        end
    end
    if settings.merchant_buy then
        local price, limited = info.merchant_buy_info(item_id)
        if price then
            if settings.money_icons then
                tooltip:AddLine('Vendor Buy ' .. (limited and '(limited): ' or ': ') .. GetCoinTextureString(price * quantity) .. per, aux.color.tooltip.merchant())
            else
                tooltip:AddLine('Vendor Buy ' .. (limited and '(limited): ' or ': ') .. money.to_string2(price * quantity) .. per, aux.color.tooltip.merchant())
            end
        end
    end
    if settings.merchant_sell then
        local price = item_info and item_info.sell_price
        if price ~= 0 then
            if settings.money_icons then
                tooltip:AddLine('Vendor: ' .. (price and GetCoinTextureString(price * quantity) .. per or UNKNOWN), aux.color.tooltip.merchant())
            else
                tooltip:AddLine('Vendor: ' .. (price and money.to_string2(price * quantity) .. per or UNKNOWN), aux.color.tooltip.merchant())
            end
        end
    end
    local auctionable = not item_info or is_auctionable(item_id, item_info)
    -- 0.8: gear is priced per ending, which on Forever only the name tells (info.price_key)
    local item_key = info.link_price_key(link)
    -- auxForever (0.5, build 3): Value is the latest look at the item (what players just saw at the
    -- auction house); the multi-day usual price shows under it only when the two differ a lot
    local latest, age = history.latest(item_key)
    local value = history.value(item_key)
    if auctionable then
        if settings.value then
            local function coins(amount)
                return settings.money_icons and GetCoinTextureString(amount) or money.to_string2(amount)
            end
            -- 0.8.2 build 4 (FB-035, deep_structure; Tyler, 2026-11-09): the usual price shows as a percent
            -- on the Value line, "Value: 2s (67%)  seen today", as the Search tab's % Hist. Value column
            -- and in its colors, instead of a "usually 3s" line under it. Its switch is "% of usual".
            local share = ''
            if latest and settings.usually ~= false and value and value > 0 then
                share = ' (' .. gui.percentage_historical(aux.round(latest / value * 100)) .. ')'
            end
            -- (0.8.2 build 6, Tyler: "I dont want to put shift instructions in the tooltip": the
            -- "Shift for 20" hint of build 1 is gone; Shift still shows a stack's prices)
            tooltip:AddLine('Value: ' .. (latest and coins(latest * quantity) .. share .. per .. age_suffix(age) or UNKNOWN), aux.color.tooltip.value())
        end
        if settings.daily then
            local market_value = history.market_value(item_key)
            local share = ''
            if market_value and value and value > 0 then
                share = ' (' .. gui.percentage_historical(aux.round(market_value / value * 100)) .. ')'
            end
            if settings.money_icons then
                tooltip:AddLine('Today: ' .. (market_value and GetCoinTextureString(market_value * quantity) .. per .. share or UNKNOWN), aux.color.tooltip.value())
            else
                tooltip:AddLine('Today: ' .. (market_value and money.to_string2(market_value * quantity) .. per .. share or UNKNOWN), aux.color.tooltip.value())
            end
        end
    end

    -- auxForever (0.8, FB-020): a Waylaid Crate lists its bundles and what each costs. Its tooltip
    -- is read once per item (kept by the crate code), so other items cost one table lookup. Its
    -- switch: "Waylaid Crates" in Settings, /aux tooltip crate (0.8.2.1 build 7, FB-041).
    local bundles = settings.crate ~= false and search_tab.crate_bundles(item_id, function() return search_tab.tooltip_texts(tooltip, data) end)
    if bundles then
        search_tab.add_crate_lines(tooltip, bundles, settings.money_icons)
    end
    -- 0.9 (FB-056): Blizzard's TooltipDataHandler calls tooltip:Show() right after post-calls
    -- finish; calling it here risks tainting GameTooltip during combat or dungeons.
end

-- auxForever: /aux memory detail
function M.memory_counts()
    local n = 0
    for _ in pairs(auctionable_cache) do n = n + 1 end
    return n
end
