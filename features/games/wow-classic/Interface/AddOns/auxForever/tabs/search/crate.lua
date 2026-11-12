select(2, ...) 'aux.tabs.search'

local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local history = require 'aux.core.history'

-- auxForever (0.8, FB-020, Harro22): Waylaid Crates. A crate's tooltip lists the bundles that fill
-- it, any one of them, after the words "Fill the crate" (seen 2026-10-20 on Journeyman Textiles and
-- Fabrics, 2026-11-08 on Journeyman Herbs and Artisan Curiosities):
--   Use: Fill the crate with any bundle from the following list:
--   - 20 Wool Cloth
--   - 40 Silk Cloth
--   - 20 Medium Leather
-- aux reads that list from the tooltip text, so no crate is written down by hand, and prices each
-- bundle from what aux already knows (the recipe cost rules: vendor when cheaper, else the latest
-- price), less what is already in the bags. The cheapest bundle is the cheapest way to fill it.

-- crate item ID -> its bundles; a crate's list never changes, so each is read once
local bundles_of = {}

local function plain(text)
    return (text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''))
end

-- the bundles in a tooltip's lines (strings; a line may hold several rows), or nil when the item
-- is not a crate: {{name, count}, ...}, in the tooltip's order
function M.crate_bundles_from_text(texts)
    local bundles, crate = {}, false
    for _, text in ipairs(texts) do
        if type(text) == 'string' then
            text = plain(text)
            -- only a crate's own Use line opens the list (review H-006, finding 6): a negative stat
            -- such as "-5 Spirit" reads like a bundle row too
            if strfind(strlower(text), 'fill the crate', 1, true) then
                crate = true
            end
            for row in string.gmatch(text, '[^\n]+') do
                local count, name = strmatch(row, '^%s*%-%s*(%d+)%s+(.-)%s*$')
                if crate and count and name ~= '' then
                    tinsert(bundles, {name = name, count = tonumber(count)})
                end
            end
        end
    end
    return #bundles > 0 and bundles or nil
end

-- whether the game may still be filling in the item's "Use:" text: the item has a use spell and its
-- text is not loaded, or its tooltip has no Use line yet (0.8 build 14: crates hovered in aux's
-- results showed no bundles, Tyler, build 13; the list is the use spell's text, which the game loads
-- after the item). Blizzard's code: C_Item.GetItemSpell, C_Spell.IsSpellDataCached.
local function use_text_pending(item_id, texts)
    local _, spell_id
    if C_Item and C_Item.GetItemSpell then
        _, spell_id = C_Item.GetItemSpell(item_id)
    end
    if not spell_id then
        return false
    end
    if C_Spell and C_Spell.IsSpellDataCached and not C_Spell.IsSpellDataCached(spell_id) then
        if C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(spell_id) end
        return true
    end
    local use = ITEM_SPELL_TRIGGER_ONUSE or 'Use:'
    for _, text in ipairs(texts) do
        if type(text) == 'string' and strfind(text, use, 1, true) then
            return false
        end
    end
    return true
end

-- the bundles of a crate, read from its tooltip lines the first time and kept. texts is the lines,
-- or a function that reads them (only called the first time). An item that is not a crate is kept
-- as one too, but only once the game has loaded it: before that its tooltip can be a bare
-- "Retrieving item information", or lack the Use line that holds a crate's list.
function M.crate_bundles(item_id, texts)
    if bundles_of[item_id] == nil and texts then
        if type(texts) == 'function' then texts = texts() end
        local bundles = crate_bundles_from_text(texts)
        if bundles or (info.item(item_id) and not use_text_pending(item_id, texts)) then
            bundles_of[item_id] = bundles or false
        end
        return bundles
    end
    return bundles_of[item_id] or nil
end

-- the text of a tooltip's lines: from the tooltip data the game hands aux's post-call, else from
-- the tooltip's own lines. Text the game keeps from addons is skipped.
function M.tooltip_texts(tooltip, data)
    local texts = {}
    local function add(text)
        if type(text) == 'string' and not (issecretvalue and issecretvalue(text)) then
            tinsert(texts, text)
        end
    end
    if type(data) == 'table' and type(data.lines) == 'table' then
        for _, line in ipairs(data.lines) do
            if type(line) == 'table' then add(line.leftText) end
        end
    elseif tooltip and tooltip.GetName and tooltip.NumLines then
        local name = tooltip:GetName()
        for i = 1, name and tooltip:NumLines() or 0 do
            local line = _G[name .. 'TextLeft' .. i]
            add(line and line:GetText())
        end
    end
    return texts
end

-- a material's item ID from its name: aux's item list (filled by scans), else the game's cache
local function material_id(name)
    local id = info.item_id(name)
    if not id and C_Item and C_Item.GetItemInfoInstant then
        local instant = C_Item.GetItemInfoInstant(name)
        id = type(instant) == 'number' and instant or nil
    end
    return id
end

local function bag_count(item_id)
    local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(item_id)
    if type(count) ~= 'number' and GetItemCount then count = GetItemCount(item_id) end
    return type(count) == 'number' and count or 0
end

-- each bundle priced: {name, count, item_id, have, need, cost, source, age}, cost nil when aux
-- has no price (or does not know the item); and the index of the cheapest priced bundle
function M.crate_costs(bundles)
    local rows, cheapest = {}, nil
    for i, bundle in ipairs(bundles) do
        local row = {name = bundle.name, count = bundle.count, item_id = material_id(bundle.name)}
        row.have = row.item_id and bag_count(row.item_id) or 0
        row.need = max(0, bundle.count - row.have)
        if row.item_id then
            if row.need == 0 then
                row.cost, row.source = 0, 'bags'
            else
                local total, missing, priced = recipe_usual_cost({reagents = {{item_id = row.item_id, count = row.need}}})
                if missing == 0 then
                    row.cost, row.source, row.age = total, priced[1].source, priced[1].age
                end
            end
        end
        if row.cost and (not cheapest or row.cost < rows[cheapest].cost) then
            cheapest = i
        end
        tinsert(rows, row)
    end
    return rows, cheapest
end

-- the lines aux adds to a crate's tooltip (Tyler chose option A of the mockup, 2026-10-20): every
-- bundle, the cheapest in gold, what the bags already hold. Prices are the latest aux has seen.
function M.add_crate_lines(tooltip, bundles, money_icons)
    local rows, cheapest = crate_costs(bundles)
    tooltip:AddLine(' ')
    tooltip:AddLine('Cheapest way to fill it', 1, 1, 1)
    tooltip:AddLine('Latest prices, less what is in your bags', aux.color.label.enabled())
    for i, row in ipairs(rows) do
        local left = row.count .. ' ' .. row.name
        local right
        if row.need == 0 and row.item_id then
            right = aux.color.label.enabled('in your bags')
        else
            if row.have > 0 then
                left = left .. aux.color.label.enabled(' (' .. row.have .. ' in bags)')
            end
            if not row.cost then
                right = aux.color.label.disabled('no price yet')
            elseif money_icons then
                right = GetCoinTextureString(row.cost)
            else
                right = money.to_string(row.cost, true)
            end
        end
        -- three color numbers per side: a color object's four values would color the right side
        -- wrongly (AGENTS.md)
        local r, g, b = 1, 1, 1
        if i == cheapest then
            r, g, b = aux.color.accent.background()
        end
        tooltip:AddDoubleLine(left, right, r, g, b, 1, 1, 1)
    end
end

-- the crate part of a search: what aux needs to name it in the lists and price it in the bottom
-- bar. Kept with Recent and Favorite searches in place of a recipe (reagents empty, so the recipe
-- code that reads them finds nothing to add up).
local function crate_parts(item_id, name, bundles)
    local copy = {}
    for _, bundle in ipairs(bundles) do
        tinsert(copy, {name = bundle.name, count = bundle.count})
    end
    return {crate = true, item_id = item_id, name = strmatch(name or '', ':%s*(.+)$') or name, bundles = copy, reagents = {}}
end

-- Alt-click a crate (C of the mockup): one search for every bundle's item, as recipe search does.
-- Returns true when the item was a crate.
function M.search_crate(link)
    local item_id, _, _, _, name = info.parse_link(link)
    local bundles = crate_bundles(item_id, function()
        local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
        return tooltip_texts(nil, data)
    end)
    if not bundles then
        return false
    end
    local names = {}
    for _, bundle in ipairs(bundles) do
        tinsert(names, strlower(bundle.name))
    end
    search_parts(crate_parts(item_id, name, bundles), names)
    return true
end

-- what one bundle costs from live auctions: the cheapest listings first, as many as are needed,
-- a vendor price taking over where it is lower. Returns the cost and how many could not be found.
local function fill_cost(listings, need, vendor)
    sort(listings, function(a, b) return a.unit < b.unit end)
    local cost, left = 0, need
    for _, listing in ipairs(listings) do
        if left == 0 or (vendor and vendor <= listing.unit) then
            break
        end
        local n = min(left, listing.units)
        cost = cost + ceil(listing.unit) * n
        left = left - n
    end
    if left > 0 and vendor then
        cost, left = cost + ceil(vendor) * left, 0
    end
    return cost, left
end

-- each bundle priced from a crate search's results: {name, count, have, need, cost, short} (short:
-- how many are missing from the auction house), and the index of the cheapest complete bundle
function M.crate_live_costs(parts, records)
    local listings = {}
    for _, record in ipairs(records or empty) do
        if not record.own and (record.buyout_price or 0) > 0 and record.name then
            local key = strlower(record.name)
            listings[key] = listings[key] or {}
            tinsert(listings[key], {unit = record.unit_buyout_price, units = history.record_units(record)})
        end
    end
    local rows, cheapest = {}, nil
    for i, bundle in ipairs(parts.bundles) do
        local item_id = material_id(bundle.name)
        local have = item_id and bag_count(item_id) or 0
        local row = {name = bundle.name, count = bundle.count, have = have, need = max(0, bundle.count - have)}
        local vendor, limited = nil, nil
        if item_id then vendor, limited = info.merchant_buy_info(item_id) end
        local cost, left = fill_cost(listings[strlower(bundle.name)] or {}, row.need, not limited and vendor or nil)
        row.cost, row.short = cost, left > 0 and left or nil
        if not row.short and (not cheapest or cost < rows[cheapest].cost) then
            cheapest = i
        end
        tinsert(rows, row)
    end
    return rows, cheapest
end

-- the bottom bar: "Crate  Journeyman Textiles   cheapest fill  20 Wool Cloth (12 in bags)  2s 56c
-- next  40 Silk Cloth  5s 60c"
local GAP = '   '
function M.crate_summary(search)
    local parts = search.recipe
    local rows, cheapest = crate_live_costs(parts, search.records)
    local text = aux.color.accent.background('Crate') .. '  ' .. (parts.name or '?') .. GAP
    local function bundle_text(row)
        local s = row.count .. ' ' .. row.name
        if row.have > 0 then
            s = s .. aux.color.label.enabled(' (' .. row.have .. ' in bags)')
        end
        return s
    end
    if not cheapest then
        return text .. aux.color.label.enabled('no bundle can be filled from what is listed')
    end
    local best = rows[cheapest]
    text = text .. aux.color.label.enabled('cheapest fill  ') .. bundle_text(best) .. '  ' .. money.to_string(best.cost, true)
    local next_row
    for i, row in ipairs(rows) do
        if i ~= cheapest and not row.short and (not next_row or row.cost < next_row.cost) then
            next_row = row
        end
    end
    if next_row then
        text = text .. GAP .. aux.color.label.enabled('next  ') .. bundle_text(next_row) .. '  ' .. money.to_string(next_row.cost, true)
    end
    return text
end
