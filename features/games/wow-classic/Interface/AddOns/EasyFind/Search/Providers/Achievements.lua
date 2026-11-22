local _, ns = ...

local Search = ns.Search
local Providers = ns.SearchProviders
local Utils = ns.Utils

local slower = Utils.slower
local sfind = Utils.sfind
local smatch = Utils.smatch
local tconcat = Utils.tconcat
local mfloor = Utils.mfloor
local CreateFrame = CreateFrame
local wipe = wipe
local band = bit.band

local ACHIEVEMENT_PROTO = {
    keywords      = {},
    keywordsLower = {},
    category      = "Achievement",
    buttonFrame   = "AchievementMicroButton",
    path          = { _G["ACHIEVEMENTS"] or "Achievements" },
}
local ACHIEVEMENT_MT = { __index = ACHIEVEMENT_PROTO }
local achievementEntryByID = {}
local achSearchCache = {}
local achSearchStatsVersion
local achSearchPending = nil
local achSearchCurrentQuery = nil
local achSearchListener
local ACH_MAX_RESULTS = 8
local ACHIEVEMENT_CATEGORY_FLAG_GUILD = 0x00000001

local function GetAchievementFilterMode()
    local mode = EasyFind and EasyFind.db and EasyFind.db.achievementFilterMode or "all"
    if mode == "earned" or mode == "incomplete" then return mode end
    return "all"
end

local function AchievementSearchCacheKey(query, mode)
    return (mode or "all") .. "\31" .. (query or "")
end

local function AchievementPassesFilter(completed, mode)
    if mode == "earned" then return completed == true end
    if mode == "incomplete" then return completed ~= true end
    return true
end

local function SyncAchievementSearchStatsVersion()
    local version = ns.Database and ns.Database.statisticsVersion or 0
    if achSearchStatsVersion == version then return end
    wipe(achSearchCache)
    wipe(achievementEntryByID)
    achSearchPending = nil
    achSearchCurrentQuery = nil
    achSearchStatsVersion = version
end





local function BuildAchievementSteps(achievementID, knownGuildAchievement)
    local isGuildAchievement = knownGuildAchievement and true or false
    local steps = {
        { buttonFrame = "AchievementMicroButton" },
        { waitForFrame = "AchievementFrame", tabIndex = isGuildAchievement and 2 or 1 },
    }
    local getCat   = _G["GetAchievementCategory"]
    local getInfo  = _G["GetCategoryInfo"]
    if not getCat or not getInfo then
        steps[#steps + 1] = {
            waitForFrame = "AchievementFrame",
            achievementID = achievementID,
        }
        return steps, isGuildAchievement
    end
    local catID = getCat(achievementID)
    if not catID or catID < 0 then
        steps[#steps + 1] = {
            waitForFrame = "AchievementFrame",
            achievementID = achievementID,
        }
        return steps, isGuildAchievement
    end
    local chain = {}
    local seen = {}
    local current = catID
    while current and current > 0 and not seen[current] do
        seen[current] = true
        local title, parentID, flags = getInfo(current)
        if not title then break end
        if flags and band(flags, ACHIEVEMENT_CATEGORY_FLAG_GUILD) == ACHIEVEMENT_CATEGORY_FLAG_GUILD then
            isGuildAchievement = true
        end
        chain[#chain + 1] = { id = current, name = title }
        current = parentID
    end
    steps[2].tabIndex = isGuildAchievement and 2 or 1

    for i = #chain, 1, -1 do
        local cat = chain[i]
        steps[#steps + 1] = {
            waitForFrame = "AchievementFrame",
            achievementCategory = cat.name,
            achievementCategoryID = cat.id,
        }
    end

    steps[#steps + 1] = {
        waitForFrame = "AchievementFrame",
        achievementID = achievementID,
    }
    return steps, isGuildAchievement
end

local function GetOrCreateAchievementEntry(id, name, icon, knownGuildAchievement)
    local entry = achievementEntryByID[id]
    local steps, isGuildAchievement = BuildAchievementSteps(id, knownGuildAchievement)
    if entry then
        if name and entry.name ~= name then
            entry.name = name
            entry.nameLower = slower(name)
        end
        if icon and entry.icon ~= icon then entry.icon = icon end
        entry.steps = steps
        entry.isGuildAchievement = isGuildAchievement or nil
        return entry
    end
    entry = setmetatable({
        name = name,
        nameLower = slower(name or ""),
        achievementID = id,
        icon = icon,
        steps = steps,
        isGuildAchievement = isGuildAchievement or nil,
    }, ACHIEVEMENT_MT)
    achievementEntryByID[id] = entry
    return entry
end





function Providers:GetAchievementRowByID(achievementID)
    local id = tonumber(achievementID)
    if not id then return nil end
    local cached = achievementEntryByID[id]
    if cached then return cached end
    local getInfo = _G["GetAchievementInfo"]
    if not getInfo then return nil end
    local ok, _, name, _, _, _, _, _, _, _, icon, _, isGuild = pcall(getInfo, id)
    if not ok or not name then return nil end
    return GetOrCreateAchievementEntry(id, name, icon, isGuild)
end




if ns.Aliases and ns.Aliases.RegisterKeyResolver then
    ns.Aliases:RegisterKeyResolver("achievement", function(key)
        return Providers:GetAchievementRowByID(smatch(key, "^achievement:(%d+)$"))
    end)
end













local fallbackScan
local fallbackBuilding = false
local clientAnswered = false









local ACH_INDEX_VER = 2

local ACH_ROW_SPEC = {
    { "id" }, { "name" }, { "icon" }, { "isGuild" }, { "completed" },
}

local function ClientBuildKey()
    local version, build = GetBuildInfo()
    return tostring(version) .. "-" .. tostring(build)
end

local function PersistFallbackIndex(rows, sliced)
    local db = EasyFind and EasyFind.db
    if not db then return end
    db.achievementIndex = {
        version = ACH_INDEX_VER,
        build = ClientBuildKey(),
        packed = Utils.PackRows(rows, ACH_ROW_SPEC, sliced),
    }
end

local ACH_NAME_ONLY = { name = true }


local function ArmFallbackScan(packed, sliced)


    local corpus = Utils.NewPackedCorpus(packed, ACH_ROW_SPEC, nil,
        { ungated = true, noShed = true, sliced = sliced })
    if corpus.count == 0 then return false end
    local parts, riAt = {}, {}
    local pos = 1
    corpus:EachRow(function(ri, row)
        local nm = type(row.name) == "string" and slower(row.name) or ""
        parts[ri] = nm
        riAt[ri] = pos
        pos = pos + #nm + 1
    end, ACH_NAME_ONLY, sliced)
    fallbackScan = {
        corpus = corpus,
        names = tconcat(parts, "\n"),
        riAt = riAt,
    }
    Utils.RegisterCorpus("achievementsFallback", corpus)
    return true
end

local function SavedFallbackIndex()
    local db = EasyFind and EasyFind.db
    local saved = db and db.achievementIndex
    if type(saved) ~= "table" or saved.version ~= ACH_INDEX_VER
       or saved.build ~= ClientBuildKey() or type(saved.packed) ~= "string"
       or saved.packed == "" then
        return nil
    end
    return saved
end

local function TryHydrateFallbackIndex(sliced)
    if fallbackScan then return true end
    local saved = SavedFallbackIndex()
    if not saved then return false end
    return ArmFallbackScan(saved.packed, sliced)
end

local function ClientHasAchievements()
    local getList = _G["GetCategoryList"]
    local getNum = _G["GetCategoryNumAchievements"]
    if not getList or not getNum then return false end
    local cats = getList()
    if not cats then return false end
    for i = 1, #cats do
        local total = getNum(cats[i])
        if total and total > 0 then return true end
    end
    return false
end

local function RefreshOpenQuery(expectedQuery)
    local eb = Search:GetSearchFrame() and Search:GetSearchFrame().editBox
    if not eb then return end



    local full = eb:GetText() or ""
    local cursor = eb:GetCursorPosition() or #full
    local typedPrefix = strtrim(full:sub(1, cursor))
    if not expectedQuery or typedPrefix == expectedQuery then
        Search:OnSearchTextChanged(typedPrefix, true)
    end
end

local function BuildFallbackIndex()
    if fallbackScan or fallbackBuilding then return end
    local getList = _G["GetCategoryList"]
    local getNum = _G["GetCategoryNumAchievements"]
    local getInfo = _G["GetAchievementInfo"]
    if not getList or not getNum or not getInfo then return end
    local cats = getList()
    if not cats then return end
    fallbackBuilding = true
    local database = ns.Database
    local rows = {}
    local catIdx, achIdx = 1, 1




    local budgetMs = 4
    local function step()
        local start = debugprofilestop and debugprofilestop() or 0
        local processed = 0
        while catIdx <= #cats do
            local catID = cats[catIdx]
            local total = getNum(catID) or 0
            while achIdx <= total do
                local ok, id, name, _, completed, _, _, _, _, _, icon, _, isGuild =
                    pcall(getInfo, catID, achIdx)
                if ok and id and name and name ~= ""
                   and not (database and database.IsStatisticAchievement
                            and database:IsStatisticAchievement(id)) then
                    rows[#rows + 1] = {
                        id = id, name = name, nameLower = slower(name),
                        icon = icon, isGuild = isGuild, completed = completed,
                    }
                end
                achIdx = achIdx + 1
                processed = processed + 1
                if (debugprofilestop and (debugprofilestop() - start) >= budgetMs)
                   or (not debugprofilestop and processed >= 50) then
                    Utils.SafeAfter(0, step)
                    return
                end
            end
            catIdx = catIdx + 1
            achIdx = 1
        end
        Utils.RunSliced(function()
            PersistFallbackIndex(rows, true)
            local db = EasyFind and EasyFind.db
            local saved = db and db.achievementIndex
            if saved and type(saved.packed) == "string" and saved.packed ~= "" then
                ArmFallbackScan(saved.packed, true)
            end
        end, function(ok, err)
            fallbackBuilding = false
            if not ok then Utils.ErrorHandler(err) end
            RefreshOpenQuery(nil)
        end, 2, "achievementHydrate")
    end
    Utils.SafeAfter(0, step)
end




local fallbackArming, fallbackWanted = false, false
local function ArmFallbackInBackground()
    if fallbackScan or fallbackBuilding or fallbackArming then return end
    fallbackArming = true
    Utils.SafeAfter(0, function()
        Utils.RunSliced(function()
            return TryHydrateFallbackIndex(true)
        end, function(ok, armed)
            fallbackArming = false
            if not ok then return Utils.ErrorHandler(armed) end
            if not armed then
                BuildFallbackIndex()
            elseif fallbackWanted then
                fallbackWanted = false
                RefreshOpenQuery(nil)
            end
        end, 2, "achievementArm")
    end)
end

local function CollectFallbackResults(query, mode)
    local results = {}
    local queryLower = slower(query or "")
    if queryLower == "" or not fallbackScan then return results end
    local names = fallbackScan.names
    local riAt = fallbackScan.riAt
    local corpus = fallbackScan.corpus
    local total = corpus.count
    local namesLen = #names
    local init = 1
    while #results < ACH_MAX_RESULTS and init <= namesLen do
        local at = sfind(names, queryLower, init, true)
        if not at then break end
        local lo, hi = 1, total
        while lo < hi do
            local mid = mfloor((lo + hi + 1) / 2)
            if riAt[mid] <= at then lo = mid else hi = mid - 1 end
        end
        local stub = corpus:StubAt(lo)
        if stub.id and stub.name and AchievementPassesFilter(stub.completed, mode) then
            results[#results + 1] = GetOrCreateAchievementEntry(stub.id, stub.name, stub.icon, stub.isGuild)
        end
        init = riAt[lo + 1] or (namesLen + 1)
    end
    return results
end





local function ResolveEmptySearchResults(query, mode)


    if clientAnswered then return {} end

    if fallbackArming then
        fallbackWanted = true
        return nil
    end
    if fallbackScan then return CollectFallbackResults(query, mode) end
    if SavedFallbackIndex() then
        fallbackWanted = true
        ArmFallbackInBackground()
        return nil
    end
    if not fallbackBuilding and ClientHasAchievements() then
        BuildFallbackIndex()
    end
    return nil
end

local function CollectAchievementSearchResults(query, mode)
    SyncAchievementSearchStatsVersion()
    mode = mode or GetAchievementFilterMode()

    local getNum = _G["GetNumFilteredAchievements"]
    local getID  = _G["GetFilteredAchievementID"]
    local getInfo = _G["GetAchievementInfo"]
    if not getNum or not getID or not getInfo then return nil end
    local count = getNum() or 0
    if count == 0 then return {} end
    clientAnswered = true
    local results = {}
    local database = ns.Database
    local canCheckStat = database and database.IsStatisticAchievement
    for i = 1, count do
        if #results >= ACH_MAX_RESULTS then break end
        local id = getID(i)
        if id and not (canCheckStat and database:IsStatisticAchievement(id)) then
            local _, name, _, completed, _, _, _, _, _, icon, _, isGuild = getInfo(id)
            if name and name ~= "" and AchievementPassesFilter(completed, mode) then
                results[#results + 1] = GetOrCreateAchievementEntry(id, name, icon, isGuild)
            end
        end
    end
    return results
end

local function EnsureAchievementSearchListener()
    if achSearchListener then return end
    achSearchListener = CreateFrame("Frame")
    achSearchListener:RegisterEvent("ACHIEVEMENT_SEARCH_UPDATED")
    achSearchListener:RegisterEvent("ACHIEVEMENT_EARNED")
    achSearchListener:SetScript("OnEvent", function(_, event, earnedID)
        if event == "ACHIEVEMENT_EARNED" then
            wipe(achSearchCache)



            if fallbackScan and earnedID then


                local corpus = fallbackScan.corpus
                local packed = corpus.packed
                local rowStart
                local at = sfind(packed, "\31n" .. earnedID .. "\30", 1, true)
                if at then
                    rowStart = at + 1
                elseif sfind(packed, "n" .. earnedID .. "\30", 1, true) == 1 then
                    rowStart = 1
                end
                if rowStart then
                    local offsets = corpus.offsets
                    local lo, hi = 1, corpus.count
                    while lo < hi do
                        local mid = mfloor((lo + hi + 1) / 2)
                        if offsets[mid] <= rowStart then lo = mid else hi = mid - 1 end
                    end
                    if offsets[lo] == rowStart then
                        local stub = corpus:StubAt(lo)
                        if stub.id == earnedID then stub.completed = true end
                    end
                end
            end
            return
        end
        local pending = achSearchPending
        if not pending then return end
        achSearchPending = nil
        achSearchCurrentQuery = pending.query
        local results = CollectAchievementSearchResults(pending.query, pending.mode)
        if results and #results == 0 then
            results = ResolveEmptySearchResults(pending.query, pending.mode)
        end






        if results then
            achSearchCache[pending.key] = results
            RefreshOpenQuery(pending.query)
        end
    end)
end

function Providers:RequestAchievementSearch(query)
    if not query or #query < 2 then return nil end


    if ns.Caps and ns.Caps.achievements == false then return nil end
    SyncAchievementSearchStatsVersion()





    if not SavedFallbackIndex() then ArmFallbackInBackground() end

    local mode = GetAchievementFilterMode()
    local cacheKey = AchievementSearchCacheKey(query, mode)
    local cached = achSearchCache[cacheKey]
    if cached then return cached end
    if achSearchCurrentQuery == query then
        local results = CollectAchievementSearchResults(query, mode)
        if results and #results == 0 then
            results = ResolveEmptySearchResults(query, mode)
        end
        if results then
            achSearchCache[cacheKey] = results
            return results
        end
    end
    local setSearch = _G["SetAchievementSearchString"]
    if not setSearch then return nil end
    EnsureAchievementSearchListener()
    achSearchPending = { query = query, mode = mode, key = cacheKey }
    pcall(setSearch, query)
    return nil
end




function Providers:IsAchievementSearchPending(query)
    if ns.Caps and ns.Caps.achievements == false then return false end
    return achSearchPending ~= nil and achSearchPending.query == query
end



function Providers:_DebugFallbackSearch(query)
    local armed = fallbackScan ~= nil or TryHydrateFallbackIndex()
    local results
    if armed then
        results = CollectFallbackResults(query, GetAchievementFilterMode())
    end
    return armed, fallbackBuilding, results
end
