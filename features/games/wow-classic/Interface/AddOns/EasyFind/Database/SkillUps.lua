local _, ns = ...





local SkillUps = {}
ns.SkillUps = SkillUps

local Utils, L = ns.Utils, ns.L
local ipairs, tsort = Utils.ipairs, Utils.tsort
local TS = C_TradeSkillUI

local TRIVIAL = 3

local HEX = { [0] = "|cffff8040", [1] = "|cffffff00", [2] = "|cff40bf40", [3] = "|cff808080" }
local HEX_LIGHT = { [0] = "|cffb84a00", [1] = "|cff807000", [2] = "|cff1f7a1f", [3] = "|cff707070" }

local function Store()
    local db = EasyFind and EasyFind.db
    if not db then return nil end
    db.recipeLevels = db.recipeLevels or {}
    local key = ns.CurrentCharacterKey()
    db.recipeLevels[key] = db.recipeLevels[key] or {}
    return db.recipeLevels[key]
end


function SkillUps.Capture()
    if not (TS and TS.GetAllRecipeIDs and TS.GetRecipeInfo) then return end
    if (TS.IsTradeSkillLinked and TS.IsTradeSkillLinked()) or (TS.IsTradeSkillGuild and TS.IsTradeSkillGuild())
       or (TS.IsNPCCrafting and TS.IsNPCCrafting()) then
        return
    end
    local store = Store()
    if not store then return end
    for _, recipeID in ipairs(TS.GetAllRecipeIDs() or {}) do
        local info = TS.GetRecipeInfo(recipeID)
        if info and info.learned and info.relativeDifficulty then store[recipeID] = info.relativeDifficulty end
    end
end


function SkillUps.Level(data)
    if data.professionRecipeID then
        local db = EasyFind and EasyFind.db
        local store = db and db.recipeLevels and db.recipeLevels[ns.CurrentCharacterKey()]
        return store and store[data.professionRecipeID] or nil
    end
    if data.classicRecipe and ns.Database.ClassicRecipeBook then
        local book = ns.Database.ClassicRecipeBook()
        local prof = book and book[data.classicProfession]
        return prof and prof.levels and prof.levels[data.name] or nil
    end
    return nil
end

function SkillUps.Hex(data)
    local level = (data.professionRecipeID or data.classicRecipe) and SkillUps.Level(data)
    if not level then return nil end
    local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
    return (theme and theme.lightTheme and HEX_LIGHT or HEX)[level]
end

if TS and TS.GetRecipeInfo and not (ns.Caps and ns.Caps.classic) then
    local pending = false
    local watcher = CreateFrame("Frame")
    Utils.RegisterEventIfValid(watcher, "TRADE_SKILL_LIST_UPDATE")
    Utils.RegisterEventIfValid(watcher, "TRADE_SKILL_SHOW")
    watcher:SetScript("OnEvent", function()
        if pending then return end
        pending = true
        Utils.SafeAfter(0.5, function()
            pending = false
            SkillUps.Capture()
        end)
    end)
end



local entries, words, found = {}, {}, {}

local function RowLess(a, b)
    if a.level ~= b.level then return a.level < b.level end
    local pa, pb = a.data.professionName or "", b.data.professionName or ""
    if pa ~= pb then return pa < pb end
    return a.data.name < b.data.name
end

local function SetEntry(n, data)
    local e = entries[n] or {}
    entries[n] = e
    e.name, e.depth, e.isPathNode, e.isMatch, e.isPinned, e.isFlat, e.data = data.name, 0, false, true, false, true, data
    e.isSectionHeader = false
end

function SkillUps.OnPage()
    local shown = ns.Filters and ns.Filters.GetQuickFilter and ns.Filters:GetQuickFilter()
    return shown ~= nil and shown.skillUpsView == true
end



function SkillUps:ShowView(_, text)
    local Database, Fold = ns.Database, ns.CharacterData.Fold
    if Database.IsDynamicProviderLoaded and not Database:IsDynamicProviderLoaded("professions") and ns.SearchEngine then
        ns.SearchEngine:RequestDynamicProvider("professions", function()
            if ns.Search and ns.Search.RefreshActiveSearch then ns.Search:RefreshActiveSearch(true) end
        end)
    end
    ns.CharacterData.Words(text or "", words)
    wipe(found)
    local read = false
    for _, data in ipairs(Database.uiSearchData) do
        if data.category == "Profession" and (data.professionRecipeID or data.classicRecipe) then
            local level = SkillUps.Level(data)
            read = read or level ~= nil
            if level and level < TRIVIAL
               and ns.CharacterData.MatchesAll(Fold(data.name .. " " .. (data.professionName or "")), words) then
                found[#found + 1] = { level = level, data = data }
            end
        end
    end
    tsort(found, RowLess)
    local n = 0
    for _, hit in ipairs(found) do
        n = n + 1
        SetEntry(n, hit.data)
    end
    if n == 0 then
        n = 1
        SetEntry(1, { name = read and (_G["BROWSE_NO_RESULTS"] or L["CHAR_NO_MATCH"]) or L["SKILLUPS_UNREAD"],
                      category = "Profession", noPin = true, noLearn = true, noMenu = true, lookupRow = true })
    end
    for i = n + 1, #entries do entries[i] = nil end
    ns.Results:ShowHierarchicalResults(entries)
end
