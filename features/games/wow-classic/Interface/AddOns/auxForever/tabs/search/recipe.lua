select(2, ...) 'aux.tabs.search'

local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local history = require 'aux.core.history'
local gui = require 'aux.gui'

-- auxForever (0.4): recipe search. Forever has retail's profession window, which can tell an addon
-- the materials of any recipe at the moment it is asked (C_TradeSkillUI.GetRecipeSchematic). A
-- "Search in aux" button on that window, or Alt-click on a recipe, searches the item the recipe
-- makes and every material in one search, and the line next to the sub tabs adds up the cost.
-- Nothing is read or kept before the click. (Shift-click is Blizzard's "track recipe", which aux
-- cannot stop, so it is not used.)

local AUCTION_CUT = .05

-- the recipe ID of a recipe link (the profession window's recipe links are not item links)
function M.recipe_id_from_link(link)
    if type(link) ~= 'string' or strfind(link, 'item:', 1, true) then
        return
    end
    return tonumber(strmatch(link, 'enchant:(%d+)') or strmatch(link, 'spell:(%d+)'))
end

-- {recipe_id, name, output = {item_id, count}, reagents = {{item_id, count}, ...}}, or nil
function M.recipe_parts(recipe_id)
    local schematic = C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic and C_TradeSkillUI.GetRecipeSchematic(recipe_id, false)
    if type(schematic) ~= 'table' then
        return
    end
    local parts = {recipe_id = recipe_id, name = schematic.name, reagents = {}}
    if (schematic.outputItemID or 0) > 0 then
        parts.output = {item_id = schematic.outputItemID, count = max(1, schematic.quantityMin or 1)}
    end
    for _, slot in ipairs(schematic.reagentSlotSchematics or empty) do
        local reagent = slot.reagents and slot.reagents[1]
        if reagent and reagent.itemID and slot.required ~= false and (slot.quantityRequired or 0) > 0 then
            tinsert(parts.reagents, {item_id = reagent.itemID, count = slot.quantityRequired})
        end
    end
    return parts
end

local pending_recipe

-- the search being started belongs to this recipe (read by execute)
function M.take_pending_recipe()
    local parts = pending_recipe
    pending_recipe = nil
    return parts
end

function M.search_recipe(recipe_id)
    local parts = recipe_parts(recipe_id)
    if not parts then
        aux.print('This recipe could not be read.')
        return
    end
    local ids, seen = {}, {}
    for _, part in ipairs(parts.output and {parts.output} or empty) do
        seen[part.item_id] = true
        tinsert(ids, part.item_id)
    end
    for _, part in ipairs(parts.reagents) do
        if not seen[part.item_id] then
            seen[part.item_id] = true
            tinsert(ids, part.item_id)
        end
    end
    aux.coro_thread(function()
        -- item names load on demand: wait up to 2 seconds for any the client has not seen yet
        local names, t0 = {}, GetTime()
        while true do
            local missing
            for i, item_id in ipairs(ids) do
                if not names[i] then
                    local item_info = info.item(item_id)
                    if item_info then
                        names[i] = strlower(item_info.name)
                    else
                        missing = true
                        info.request_item(item_id)
                    end
                end
            end
            if not missing or GetTime() - t0 > 2 then break end
            aux.coro_wait()
        end
        local found = {}
        for i = 1, #ids do
            if names[i] then tinsert(found, names[i]) end
        end
        search_parts(parts, found)
    end)
end

-- one search for every item named (lower case), the parts kept with it (a recipe, or since 0.8 a
-- crate) so the bottom bar can add up the cost
function M.search_parts(parts, names)
    local queries = {}
    for _, name in ipairs(names) do
        -- a slash or semicolon would break the search text; no such item names are known
        if name and not strfind(name, '[/;]') then
            tinsert(queries, name .. '/exact')
        end
    end
    if #queries == 0 then
        return
    end
    pending_recipe = parts
    aux.set_tab(1)
    set_filter(table.concat(queries, ';'))
    execute(nil, false)
    -- taken by execute; never left for an unrelated later search
    pending_recipe = nil
end

-- coin letters in their colors, numbers in the color given (or the line's own) (Tyler, 0.6)
local function plain_money(amount, color)
    return money.to_string(amount, true, nil, color)
end

-- Cost of a recipe from a search's records: materials (each the cheapest auction or the vendor
-- price, whichever is lower; cost counts only those with a price, missing lists the item IDs of
-- the others, nil when none is missing) and what the made item sells for after the cut (nil when
-- none is for sale or the recipe makes no item).
function M.recipe_costs(parts, records)
    local cheapest = {}
    for _, record in ipairs(records or empty) do
        if not record.own and (record.buyout_price or 0) > 0 then
            local unit = record.unit_buyout_price
            if not cheapest[record.item_id] or unit < cheapest[record.item_id] then
                cheapest[record.item_id] = unit
            end
        end
    end
    local cost, missing = 0, nil
    for _, part in ipairs(parts.reagents) do
        local price = cheapest[part.item_id]
        local vendor, limited = info.merchant_buy_info(part.item_id)
        if vendor and not limited and (not price or vendor < price) then
            price = vendor
        end
        if price then
            cost = cost + ceil(price) * part.count
        else
            missing = missing or {}
            tinsert(missing, part.item_id)
        end
    end
    local sell = parts.output and cheapest[parts.output.item_id]
    local net = sell and floor(ceil(sell) * parts.output.count * (1 - AUCTION_CUT)) or nil
    return cost, missing, net
end

-- The line in the bottom bar: "Simple Kilt   materials 6s 10c   sells 42s 75c after cut   profit
-- 36s 65c". A material with no auction and no known vendor price is named (aux learns vendor prices
-- when you open a vendor that sells it): "materials 8s 63c + Gray Dye (no price)", and the profit
-- becomes a bound ("profit at most", "loss at least").
local GAP = '   '
function M.recipe_summary(search)
    local parts = search.recipe
    if parts.crate then
        return crate_summary(search)
    end
    local cost, missing, net = recipe_costs(parts, search.records)
    local text = aux.color.accent.background(parts.name or 'Recipe') .. GAP .. 'materials ' .. plain_money(cost)
    if missing then
        local names = {}
        for _, item_id in ipairs(missing) do
            local item_info = info.item(item_id)
            tinsert(names, item_info and item_info.name or 'a material')
        end
        text = text .. ' + ' .. table.concat(names, ', ') .. ' (no price)'
    end
    if parts.output then
        if not net then
            text = text .. GAP .. 'none for sale'
        else
            text = text .. GAP .. 'sells ' .. plain_money(net) .. ' after cut' .. GAP
            if net >= cost then
                text = text .. aux.color.green(missing and 'profit at most ' or 'profit ') .. plain_money(net - cost, aux.color.green)
            else
                text = text .. aux.color.red(missing and 'loss at least ' or 'loss ') .. plain_money(cost - net, aux.color.red)
            end
        end
    end
    return text
end

-- Saved and Recent searches keep the recipe of a recipe search, so running one again (from either
-- list, the quick menu, the history arrows or typed) shows the cost line again.
function M.saved_recipe(filter_string)
    for _, list in ipairs{recent_searches or empty, favorite_searches or empty} do
        for _, entry in ipairs(list) do
            if entry.recipe and entry.filter_string == filter_string then
                return entry.recipe
            end
        end
    end
end

-- a recipe search in the lists: "Recipe  Colorful Kilt  (3 materials)" instead of its search text
function M.recipe_entry_name(entry)
    if entry.recipe.crate then
        local n = #(entry.recipe.bundles or empty)
        return aux.color.accent.background('Crate') .. '  ' .. (entry.filter_name or entry.recipe.name or '?')
            .. '  ' .. aux.color.label.enabled('(' .. n .. (n == 1 and ' bundle)' or ' bundles)'))
    end
    local n = #(entry.recipe.reagents or empty)
    return aux.color.accent.background('Recipe') .. '  ' .. (entry.filter_name or entry.recipe.name or '?')
        .. '  ' .. aux.color.label.enabled('(' .. n .. (n == 1 and ' material)' or ' materials)'))
end

-- auxForever (0.5, FB-007): what one craft's materials cost, anywhere in the world, from prices aux
-- already keeps. Each material at its vendor price when a vendor sells it without limit for less,
-- else at its latest price (the latest look at it, as in tooltips; build 3, was the usual price).
-- Returns the cost of the priced ones, how many have no price, and a row per material for the
-- tooltip: {item_id, count, cost, source = 'vendor' | 'latest', age}.
function M.recipe_usual_cost(parts)
    local total, missing, rows = 0, 0, {}
    for _, part in ipairs(parts.reagents) do
        local usual, age = history.latest(part.item_id .. ':0')
        local vendor, limited = info.merchant_buy_info(part.item_id)
        local row = {item_id = part.item_id, count = part.count}
        if vendor and not limited and (not usual or vendor <= usual) then
            row.cost, row.source = ceil(vendor) * part.count, 'vendor'
        elseif usual then
            row.cost, row.source, row.age = ceil(usual) * part.count, 'latest', age
            row.latest = usual
        end
        if row.cost then
            total = total + row.cost
        else
            missing = missing + 1
        end
        tinsert(rows, row)
    end
    return total, missing, rows
end

-- 0.8.1 (FB-026, suggested by deep_structure; Tyler, 2026-11-08: option A of the mockup, reversing
-- FB-007's "cost only, no profit"): what one craft's made items bring after the auction house cut,
-- from the made item's latest price (Value in its tooltip), with no request. Returns the amount
-- after the cut, the price of the whole output before it and that price's age; nil when the recipe
-- makes no item or the made item has no price yet. The deposit is left out: it comes back on a sale.
function M.recipe_sale(parts)
    local output = parts.output
    if not output then return end
    local price, age = history.latest(output.item_id .. ':0')
    if not price then return end
    local gross = ceil(price) * output.count
    return floor(gross * (1 - AUCTION_CUT)), gross, age
end

-- "Profit" and "7s 6c" in green, or "Loss" and "1s 10c" in red; "at most" / "at least" when a
-- material has no price (the true cost is higher). nil when the recipe makes no item or the made
-- item has no price yet.
local function profit_parts(parts, total, missing)
    local net = recipe_sale(parts)
    if not net then return end
    if net >= total then
        return aux.color.green(missing > 0 and 'Profit at most' or 'Profit'), plain_money(net - total, aux.color.green)
    end
    return aux.color.red(missing > 0 and 'Loss at least' or 'Loss'), plain_money(total - net, aux.color.red)
end

-- the line's profit part: "Profit  7s 6c", or "no sell price yet"; nil for a recipe that makes no item
local function profit_text(parts, total, missing)
    if not parts.output then return end
    local label, amount = profit_parts(parts, total, missing)
    if not label then
        return aux.color.label.disabled('no sell price yet')
    end
    return label .. '  ' .. amount
end

-- the line's text: "Materials  1g 24s   Profit  36s", a gray "+" when some materials have no price,
-- "no price yet" for none
function M.recipe_cost_text(parts)
    local total, missing = recipe_usual_cost(parts)
    local text = aux.color.label.enabled('Materials  ')
    if #parts.reagents > 0 and missing == #parts.reagents then
        return text .. aux.color.label.disabled('no price yet')
    end
    text = text .. money.to_string(total, true) .. (missing > 0 and aux.color.label.disabled('+') or '')
    local profit = profit_text(parts, total, missing)
    return profit and (text .. GAP .. profit) or text
end

-- 0.8.2 build 6 (Tyler: "% of usual" everywhere, "especially in crafting menus"): " (67%)" after a
-- latest price, the share of the usual price in the colors of the Search tab's % of usual column, as
-- on the tooltip's Value line; '' without a usual price or when the "% of usual" switch is off
function M.share_of_usual(latest, item_key)
    local settings = aux.character_data and aux.character_data.tooltip
    if not latest or (settings and settings.usually == false) then
        return ''
    end
    local value = history.value(item_key)
    if not value or value <= 0 then
        return ''
    end
    return ' (' .. gui.percentage_historical(aux.round(latest / value * 100)) .. ')'
end

function M.recipe_cost_tooltip(tooltip, parts)
    local total, missing, rows = recipe_usual_cost(parts)
    tooltip:AddLine('Materials for 1 craft', 1, 1, 1)
    tooltip:AddLine('Prices from your latest scans', aux.color.label.enabled())
    for _, row in ipairs(rows) do
        local item_info = info.item(row.item_id)
        if not item_info then info.request_item(row.item_id) end
        local name = (item_info and item_info.name or ('item ' .. row.item_id)) .. (row.count > 1 and (' ×' .. row.count) or '')
        local right
        if not row.cost then
            right = aux.color.label.disabled('no price yet')
        else
            local source = row.source == 'vendor' and 'vendor' or ('seen ' .. (history.age_text(row.age) or '?'))
            local dim = row.source == 'latest' and row.age and row.age >= history.OLD_DAYS
            local share = row.source == 'latest' and share_of_usual(row.latest, row.item_id .. ':0') or ''
            right = money.to_string(row.cost, true) .. share .. '  ' .. (dim and aux.color.label.disabled or aux.color.label.enabled)(source)
        end
        -- white on both sides, like aux's tables: the game's default right color is gold, which
        -- colored every price (Tyler, build 2)
        tooltip:AddDoubleLine(name, right, 1, 1, 1, 1, 1, 1)
    end
    if missing < #rows then
        -- colors given in full: a color object's four values would make the right side red
        local r, g, b = aux.color.label.enabled()
        tooltip:AddDoubleLine(missing > 0 and ('Total, without ' .. missing .. ' unpriced') or 'Total', money.to_string(total, true) .. (missing > 0 and '+' or ''), r, g, b, 1, 1, 1)
    else
        tooltip:AddLine('Search or scan at the auction house to learn prices.', aux.color.label.enabled())
    end
    -- 0.8.1 (FB-026): what the made item sells for, after the cut, and the profit or loss
    local output = parts.output
    if output and missing < #rows then
        local item_info = info.item(output.item_id)
        if not item_info then info.request_item(output.item_id) end
        local name = (item_info and item_info.name or ('item ' .. output.item_id)) .. (output.count > 1 and (' ×' .. output.count) or '')
        local net, gross, age = recipe_sale(parts)
        local r, g, b = aux.color.label.enabled()
        tooltip:AddLine(' ')
        if not net then
            tooltip:AddDoubleLine(name .. ' sells for', aux.color.label.disabled('no price yet'), 1, 1, 1, 1, 1, 1)
            tooltip:AddLine('Search for it at the auction house to learn its price.', r, g, b)
            return
        end
        local dim = age and age >= history.OLD_DAYS
        local share = share_of_usual(gross / output.count, output.item_id .. ':0')
        tooltip:AddDoubleLine(name .. ' sells for', money.to_string(gross, true) .. share .. '  ' .. (dim and aux.color.label.disabled or aux.color.label.enabled)('seen ' .. (history.age_text(age) or '?')), 1, 1, 1, 1, 1, 1)
        tooltip:AddDoubleLine('After the 5% auction house cut', money.to_string(net, true), r, g, b, 1, 1, 1)
        local label, amount = profit_parts(parts, total, missing)
        tooltip:AddDoubleLine(label, amount, 1, 1, 1, 1, 1, 1)
    end
end

-- the line under Blizzard's reagent list (in the 20 pixel gap above any optional reagents), set
-- when a recipe is shown (the form's Init), never per frame
do
    local line, line_parts

    local function update_line(form)
        local recipe = form.GetRecipeInfo and form:GetRecipeInfo()
        line_parts = recipe and recipe.recipeID and recipe_parts(recipe.recipeID)
        local reagents = type(form.Reagents) == 'table' and form.Reagents
        if not line_parts or #line_parts.reagents == 0 or (reagents and not reagents:IsShown()) then
            line:Hide()
            return
        end
        line.text:SetText(recipe_cost_text(line_parts))
        line:SetWidth(max(60, line.text:GetStringWidth() + 8))
        line:Show()
        if GameTooltip:IsOwned(line) then
            line:GetScript('OnEnter')(line)
        end
    end

    M.update_cost_line = update_line

    function M.create_cost_line()
        local form = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
        if line or type(form) ~= 'table' or not form.Init then
            return
        end
        line = CreateFrame('Frame', nil, form)
        line:SetHeight(14)
        if type(form.Reagents) == 'table' then
            line:SetPoint('TOPLEFT', form.Reagents, 'BOTTOMLEFT', 0, -3)
        else
            line:SetPoint('BOTTOMLEFT', form, 'BOTTOMLEFT', 30, 50)
        end
        line:EnableMouse(true)
        line.text = line:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        line.text:SetPoint('LEFT', 0, 0)
        line.text:SetJustifyH('LEFT')
        line:SetScript('OnEnter', function(self)
            if not line_parts then return end
            GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
            recipe_cost_tooltip(GameTooltip, line_parts)
            GameTooltip:Show()
        end)
        line:SetScript('OnLeave', function() GameTooltip:Hide() end)
        line:Hide()
        M.recipe_cost_line = line
        hooksecurefunc(form, 'Init', function(self) update_line(self) end)
        if form:IsShown() then update_line(form) end
    end
end

-- the button on the profession window, shown while aux is open at the auction house
do
    local button

    -- Blizzard's patch of 2026-10-08 (Forever build 70291) moved the Track Recipe checkbox from the
    -- bottom left of the recipe panel to the bottom right, under this button (Tyler, after 0.6).
    -- When the checkbox sits on the right, the button goes just left of it; otherwise it keeps the
    -- bottom right corner it had since 0.4.
    function M.recipe_button_spot(form)
        local track = form.TrackRecipeCheckbox
        local point = type(track) == 'table' and track.GetPoint and track:GetPoint(1)
        if type(point) == 'string' and strfind(point, 'RIGHT') then
            return 'track', track
        end
        return 'corner'
    end

    function place_button(button, form)
        local spot, track = recipe_button_spot(form)
        button:ClearAllPoints()
        if spot == 'track' then
            button:SetPoint('RIGHT', track, 'LEFT', -8, 0)
        else
            button:SetPoint('BOTTOMRIGHT', form, 'BOTTOMRIGHT', -16, 12)
        end
    end

    local function create_button()
        local form = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
        if button or type(form) ~= 'table' or not form.GetRecipeInfo then
            return
        end
        button = CreateFrame('Button', nil, form, 'UIPanelButtonTemplate')
        button:SetSize(120, 22)
        place_button(button, form)
        hooksecurefunc(form, 'Init', function(self) place_button(button, self) end)
        button:SetText('Search in aux')
        button:SetScript('OnClick', function()
            local recipe = form:GetRecipeInfo()
            if recipe and recipe.recipeID then
                search_recipe(recipe.recipeID)
            end
        end)
        if aux.frame:IsShown() then button:Show() else button:Hide() end
        M.recipe_button = button
    end

    function aux.event.AUX_LOADED()
        aux.event_listener('ADDON_LOADED', function(name)
            if name == 'Blizzard_Professions' then
                create_button()
                create_cost_line()
            end
        end)
        create_button()
        create_cost_line()
        aux.event_listener('AUCTION_HOUSE_SHOW', function()
            create_button()
            if button then button:Show() end
        end)
        aux.event_listener('AUCTION_HOUSE_CLOSED', function()
            if button then button:Hide() end
        end)
    end
end
