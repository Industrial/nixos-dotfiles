local _, ns = ...

local Database = {}
ns.Database = Database

local Utils   = ns.Utils
local L       = ns.L
local SearchText = ns.SearchText
local ipairs, pairs = Utils.ipairs, Utils.pairs
local sfind, ssub = Utils.sfind, Utils.ssub




local slower = SearchText.Normalize
local select, type, tostring = select, type, tostring
local wipe = wipe
local CreateFrame = CreateFrame
local GetTime = GetTime
local C_CurrencyInfo = C_CurrencyInfo
local C_Reputation = C_Reputation
local C_MountJournal = C_MountJournal
local C_ToyBox = C_ToyBox
local C_PetJournal = C_PetJournal
local C_EncounterJournal = C_EncounterJournal
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local band, lshift = bit.band, bit.lshift

local uiSearchData = {}
Database.uiSearchData = uiSearchData
local knownCurrencyIDs = {}






local EMPTY_KEYWORDS = {}





local Corpora = { packedLive = {} }

local function RemoveEntriesByCategory(category)
    Corpora.packedLive[category] = nil
    local before = #uiSearchData
    local writeIdx = 0
    for i = 1, before do
        local entry = uiSearchData[i]
        if entry.category ~= category then
            writeIdx = writeIdx + 1
            uiSearchData[writeIdx] = entry
        elseif ns.SearchIndex and ns.SearchIndex.NoteRemoved then
            ns.SearchIndex:NoteRemoved(entry)
        end
    end
    for i = before, writeIdx + 1, -1 do
        uiSearchData[i] = nil
    end
    if ns.SearchIndex and ns.SearchIndex.NoteCompacted then
        ns.SearchIndex:NoteCompacted(writeIdx)
    end


    if Database.NotePopulateStart then Database:NotePopulateStart(category, writeIdx < before) end


end

Database.RemoveEntriesByCategory = RemoveEntriesByCategory

local function RemoveEntriesWithField(field)
    local before = #uiSearchData
    local writeIdx = 0
    for i = 1, before do
        local entry = uiSearchData[i]
        if not entry[field] then
            writeIdx = writeIdx + 1
            uiSearchData[writeIdx] = entry
        elseif ns.SearchIndex and ns.SearchIndex.NoteRemoved then
            ns.SearchIndex:NoteRemoved(entry)
        end
    end
    for i = before, writeIdx + 1, -1 do
        uiSearchData[i] = nil
    end
    if ns.SearchIndex and ns.SearchIndex.NoteCompacted then
        ns.SearchIndex:NoteCompacted(writeIdx)
    end
end

function Database:_RemoveEntriesByCategory(category)
    RemoveEntriesByCategory(category)
end

local partialSearchRefreshPending = false
local lastPartialSearchRefreshMs = 0

function Database:SchedulePartialSearchRefresh(minIntervalMs)
    if partialSearchRefreshPending then return end

    local now = debugprofilestop and debugprofilestop() or 0
    minIntervalMs = minIntervalMs or 150
    local delay = 0
    if now > 0 and lastPartialSearchRefreshMs > 0 then
        local elapsed = now - lastPartialSearchRefreshMs
        if elapsed < minIntervalMs then
            delay = (minIntervalMs - elapsed) / 1000
        end
    end

    partialSearchRefreshPending = true
    local function run()
        partialSearchRefreshPending = false
        lastPartialSearchRefreshMs = debugprofilestop and debugprofilestop() or 0
        if Database.ResetSearchCache then Database:ResetSearchCache() end
        if ns.Search and ns.Search.RefreshActiveSearch then
            ns.Search:RefreshActiveSearch(true)
        end
    end

    if Utils.SafeAfter then
        Utils.SafeAfter(delay, run)
    else
        run()
    end
end

function Database:Initialize()
    self:BuildUIDatabase()

    local staticRows = {}
    for i = 1, #uiSearchData do staticRows[i] = uiSearchData[i] end
    self.staticRows = staticRows
end



function Database:IsCurrencyAccountTransferable(currencyID)
    if not currencyID or not C_CurrencyInfo then return false end
    local fns = {
        C_CurrencyInfo.IsAccountTransferableCurrency,
        C_CurrencyInfo.IsAccountWideCurrency,
    }
    for i = 1, #fns do
        local fn = fns[i]
        if fn then
            local ok, val = pcall(fn, currencyID)
            if ok and val then return true end
        end
    end
    if C_CurrencyInfo.GetCurrencyInfo then
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
        if ok and type(info) == "table" then
            if info.isAccountTransferable then return true end
            if info.isAccountWide then return true end
            if info.transferPercentage and info.transferPercentage > 0 then return true end
        end
    end
    return false
end

function Database:PopulateDynamicCurrencies()

    local Caps = ns.Caps
    if not ((C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize) or _G["GetCurrencyListSize"]) then return false end
    if Caps.NumCurrencies() == 0 then



        return false
    end

    RemoveEntriesByCategory("Currency")
    wipe(knownCurrencyIDs)

    local headersWeExpanded = {}
    for pass = 1, 50 do
        local size = Caps.NumCurrencies()
        local didExpand = false
        for i = 1, size do
            Utils.SliceCheckpoint()
            local info = Caps.CurrencyAt(i)
            if info and info.isHeader and not info.isHeaderExpanded then
                Caps.SetCurrencyHeaderExpanded(i, true)
                headersWeExpanded[info.name] = true
                didExpand = true
                break
            end
        end
        if not didExpand then break end
    end

    local size = Caps.NumCurrencies()
    local injected = 0

    local baseSteps = {
        { buttonFrame = "CharacterMicroButton" },
        { waitForFrame = "CharacterFrame", tabIndex = 3 },
    }

    local headerStack = {}

    local function pushHeader(name, depth)
        while #headerStack > 0 and headerStack[#headerStack].depth >= depth do
            headerStack[#headerStack] = nil
        end
        headerStack[#headerStack + 1] = { name = name, depth = depth }
    end



    local headerStep, sharedPath = {}, {}
    local function buildHeaderSteps()
        local steps = {}
        for _, s in ipairs(baseSteps) do steps[#steps + 1] = s end
        for _, h in ipairs(headerStack) do
            local step = headerStep[h.name]
            if not step then
                step = { waitForFrame = "CharacterFrame", currencyHeader = h.name }
                headerStep[h.name] = step
            end
            steps[#steps + 1] = step
        end
        return steps
    end

    local function buildPath()
        local path = {_G["CHARACTER_BUTTON"] or "Character Info", _G["CURRENCY"] or "Currency"}
        for _, h in ipairs(headerStack) do
            path[#path + 1] = h.name .. L["UITREE_SUFFIX_CURRENCIES"]
        end
        return path
    end
    local function groupPath()
        local names = {}
        for i, h in ipairs(headerStack) do names[i] = h.name end
        local key = table.concat(names, "\1")
        local path = sharedPath[key]
        if not path then
            path = buildPath()
            sharedPath[key] = path
        end
        return path
    end

    local currencyIconMap = {}

    for i = 1, size do
        if i % 16 == 0 then Utils.SliceCheckpoint() end
        local info = Caps.CurrencyAt(i)
        if info then
            local depth = info.currencyListDepth or 0

            if info.currencyID and info.iconFileID then
                currencyIconMap[info.currencyID] = info.iconFileID
            end

            if info.isHeader then
                pushHeader(info.name, depth)

                local headerKey = "header_" .. slower(info.name)
                if not knownCurrencyIDs[headerKey] then
                    knownCurrencyIDs[headerKey] = true

                    local headerNameLower = slower(info.name)
                    local entry = {
                        name = info.name .. L["UITREE_SUFFIX_CURRENCIES"],
                        keywords = {headerNameLower, headerNameLower .. " currencies", headerNameLower .. " currency"},
                        category = "Currency",
                        buttonFrame = "CharacterMicroButton",
                        path = buildPath(),
                        steps = buildHeaderSteps(),
                    }
                    entry.path[#entry.path] = nil
                    entry.nameLower = slower(entry.name)

                    entry.keywordsLower = entry.keywords
                    uiSearchData[#uiSearchData + 1] = entry
                    injected = injected + 1
                end
            elseif info.currencyID and not knownCurrencyIDs[info.currencyID] then
                local currName = info.name
                local immediateHeader = headerStack[#headerStack]
                local immediateHeaderName = immediateHeader and immediateHeader.name or "Unknown"

                local currSteps = buildHeaderSteps()
                currSteps[#currSteps + 1] = { waitForFrame = "CharacterFrame", currencyID = info.currencyID }

                local words = {}
                local currNameLower = slower(currName)
                for word in currNameLower:gmatch("%S+") do
                    if #word > 2 then
                        words[#words + 1] = word
                    end
                end
                words[#words + 1] = slower(immediateHeaderName) .. " " .. currNameLower





                words[#words + 1] = "currency"
                words[#words + 1] = "currencies"
                local currencyGlobal = _G["CURRENCY"]
                if currencyGlobal and slower(currencyGlobal) ~= "currency" then
                    words[#words + 1] = slower(currencyGlobal)
                end

                local isAccountTransferable = Database:IsCurrencyAccountTransferable(info.currencyID)
                local entry = {
                    name = currName,
                    keywords = words,
                    category = "Currency",
                    buttonFrame = "CharacterMicroButton",
                    path = groupPath(),
                    steps = currSteps,
                    icon = info.iconFileID or nil,
                    currencyID = info.currencyID,
                    isAccountTransferable = isAccountTransferable,
                }
                entry.nameLower = slower(entry.name)

                entry.keywordsLower = entry.keywords
                uiSearchData[#uiSearchData + 1] = entry
                knownCurrencyIDs[info.currencyID] = true
                injected = injected + 1
            end
        end
    end

    if injected > 0 then
        Utils.DebugPrint("Injected", injected, "dynamic currency entries")
    end




    for idx, item in ipairs(uiSearchData) do
        if idx % 256 == 0 then Utils.SliceCheckpoint() end
        local steps = rawget(item, "steps")
        if not item.icon and steps then
            for _, step in ipairs(steps) do
                if step.currencyID and currencyIconMap[step.currencyID] then
                    item.icon = currencyIconMap[step.currencyID]
                    break
                end
            end
        end
    end


    for pass = 1, 50 do
        local sz = Caps.NumCurrencies()
        local didCollapse = false
        for i = sz, 1, -1 do
            local info = Caps.CurrencyAt(i)
            if info and info.isHeader and info.isHeaderExpanded and headersWeExpanded[info.name] then
                Caps.SetCurrencyHeaderExpanded(i, false)
                headersWeExpanded[info.name] = nil
                didCollapse = true
                break
            end
        end
        if not didCollapse then break end
    end




    do
        local extraIDs
        if C_CurrencyInfo and C_CurrencyInfo.GetAccountCurrencyTypes then
            local ok, list = pcall(C_CurrencyInfo.GetAccountCurrencyTypes)
            if ok and type(list) == "table" then extraIDs = list end
        end
        if extraIDs then
            for _, cid in ipairs(extraIDs) do
                if not knownCurrencyIDs[cid]
                   and self:IsCurrencyAccountTransferable(cid) then
                    local fok, finfo = pcall(C_CurrencyInfo.GetCurrencyInfo, cid)
                    local cname = (fok and type(finfo) == "table" and finfo.name) or nil
                    if cname and cname ~= "" then
                        local cnameLower = slower(cname)
                        local kw = { cnameLower, "currency", "warband" }
                        local entry = {
                            name = cname,
                            keywords = kw,
                            category = "Currency",
                            buttonFrame = "CharacterMicroButton",
                            path = { _G["CHARACTER_BUTTON"] or "Character Info", _G["CURRENCY"] or "Currency" },
                            steps = {
                                { buttonFrame = "CharacterMicroButton" },
                                { waitForFrame = "CharacterFrame", tabIndex = 3 },
                                { waitForFrame = "CharacterFrame", currencyID = cid },
                            },
                            icon = (fok and finfo.iconFileID) or nil,
                            currencyID = cid,
                            isAccountTransferable = true,
                        }
                        entry.nameLower = cnameLower
                        entry.keywordsLower = { cnameLower, "currency", "warband" }
                        uiSearchData[#uiSearchData + 1] = entry
                        knownCurrencyIDs[cid] = true
                    end
                end
            end
        end
    end

    return true
end


function Database.SkillHeadings()
    local out = {}
    for i = 1, GetNumSkillLines and GetNumSkillLines() or 0 do
        local name, isHeader = GetSkillLineInfo(i)
        if isHeader and name and name ~= "" then out[#out + 1] = { key = name, label = name } end
    end
    return out
end


function Database:PopulateDynamicSkills()
    if not (GetNumSkillLines and GetSkillLineInfo) then return false end
    if GetNumSkillLines() == 0 then return false end

    RemoveEntriesByCategory("Skill")


    local folded
    for i = GetNumSkillLines(), 1, -1 do
        local headerName, isHeader, isExpanded = GetSkillLineInfo(i)
        if isHeader and not isExpanded then
            folded = folded or {}
            folded[headerName] = true
            ns.skillHeadersToggledAt = GetTime()
            ExpandSkillHeader(i)
        end
    end

    local characterLabel = _G["CHARACTER_BUTTON"] or "Character Info"
    local skillsLabel = _G["SKILLS"] or "Skills"
    local header, headerLower
    for i = 1, GetNumSkillLines() do
        local skillName, isHeader, _, rank, tempPoints, modifier, maxRank = GetSkillLineInfo(i)
        if isHeader then
            header, headerLower = skillName, slower(skillName or "")
        elseif skillName and skillName ~= "" then
            local nameLower = slower(skillName)
            local keywords = { nameLower, "skill", headerLower }
            uiSearchData[#uiSearchData + 1] = {
                name = skillName,
                nameLower = nameLower,
                keywords = keywords,
                keywordsLower = keywords,
                category = "Skill",
                buttonFrame = "CharacterMicroButton",
                path = { characterLabel, skillsLabel, header },
                skillLine = skillName,
                skillHeader = header,

                skillRank = rank and (rank + (tempPoints or 0)),
                skillMaxRank = maxRank,
                skillModifier = modifier,
                steps = {
                    { buttonFrame = "CharacterMicroButton" },
                    { waitForFrame = "CharacterFrame", tabFrame = "SkillsFrame" },
                    { waitForFrame = "CharacterFrame", skillLine = skillName, skillHeader = header },
                },
            }
        end
    end

    if folded then
        for i = GetNumSkillLines(), 1, -1 do
            local headerName, isHeader, isExpanded = GetSkillLineInfo(i)
            if isHeader and isExpanded and folded[headerName] then CollapseSkillHeader(i) end
        end
    end
    return true
end

function Database:PopulateDynamicReputations()

    local Caps = ns.Caps
    if not ((C_Reputation and C_Reputation.GetNumFactions) or _G["GetNumFactions"]) then return false end
    local liveFactions = Caps.NumFactions()
    if not liveFactions or liveFactions == 0 then



        return false
    end

    RemoveEntriesByCategory("Reputation")

    local headersWeExpanded = {}
    for pass = 1, 50 do
        local numFactions = Caps.NumFactions()
        local didExpand = false
        for i = 1, numFactions do
            Utils.SliceCheckpoint()
            local factionData = Caps.FactionAt(i)
            if factionData and factionData.isHeader then
                local isCollapsed = false
                if factionData.isHeaderExpanded ~= nil then
                    isCollapsed = not factionData.isHeaderExpanded
                elseif factionData.isCollapsed ~= nil then
                    isCollapsed = factionData.isCollapsed
                end

                if isCollapsed then
                    Caps.SetFactionHeaderExpanded(i, true)
                    headersWeExpanded[factionData.name] = true
                    didExpand = true
                    break
                end
            end
        end
        if not didExpand then break end
    end

    local numFactions = Caps.NumFactions()
    local injected = 0

    local baseSteps = {
        { buttonFrame = "CharacterMicroButton" },
        { waitForFrame = "CharacterFrame", tabIndex = 2 },
    }

    local currentExpansion
    local currentFactionGroup







    local repMTByKey = {}
    local function getRepMT()
        local key = (currentExpansion or "") .. "\31" .. (currentFactionGroup or "")
        local cached = repMTByKey[key]
        if cached then return cached end

        local steps = {}
        for _, s in ipairs(baseSteps) do steps[#steps + 1] = s end
        if currentExpansion then
            steps[#steps + 1] = { waitForFrame = "CharacterFrame", factionHeader = currentExpansion }
        end
        if currentFactionGroup then
            steps[#steps + 1] = { waitForFrame = "CharacterFrame", factionHeader = currentFactionGroup }
        end

        local path = { _G["CHARACTER_BUTTON"] or "Character Info", _G["REPUTATION"] or "Reputation" }
        if currentExpansion then path[#path + 1] = currentExpansion end
        if currentFactionGroup then path[#path + 1] = currentFactionGroup end

        local prefixLen = #steps
        local proto = {
            category    = "Reputation",
            buttonFrame = "CharacterMicroButton",
            path        = path,
        }
        local mt = {
            __index = function(t, k)
                if k == "steps" then
                    local v = {}
                    for i = 1, prefixLen do v[i] = steps[i] end
                    v[prefixLen + 1] = {
                        waitForFrame = "CharacterFrame",
                        factionID = t.factionID,
                    }
                    rawset(t, "steps", v)
                    return v
                end
                return proto[k]
            end,
            __index_proto = proto,
        }
        repMTByKey[key] = mt
        return mt
    end

    local ALLIANCE_HEADER = (FACTION_ALLIANCE or "Alliance"):lower()
    local HORDE_HEADER    = (FACTION_HORDE    or "Horde"):lower()

    local function injectFaction(factionData)
        local isDiscovered = factionData.listed or (factionData.currentStanding and factionData.currentStanding > 0) or
                             (factionData.isWatched == true)
        if not isDiscovered then return end

        local keywords = {}
        local factionNameLower = slower(factionData.name)
        for word in factionNameLower:gmatch("%S+") do
            if #word > 2 then
                keywords[#keywords + 1] = word
            end
        end
        keywords[#keywords + 1] = factionNameLower

        local factionSide
        if currentFactionGroup then
            local groupLower = slower(currentFactionGroup)
            if groupLower == ALLIANCE_HEADER then
                factionSide = "alliance"
            elseif groupLower == HORDE_HEADER then
                factionSide = "horde"
            end
        end

        uiSearchData[#uiSearchData + 1] = setmetatable({
            name           = factionData.name,
            nameLower      = factionNameLower,
            keywords       = keywords,
            factionID      = factionData.factionID,
            factionSide    = factionSide,
            hasRepBar      = not factionData.isHeader or factionData.isHeaderWithRep,
        }, getRepMT())
        injected = injected + 1
    end

    for i = 1, numFactions do
        Utils.SliceCheckpoint()
        local factionData = Caps.FactionAt(i)
        if factionData and factionData.name then
            if factionData.isHeader then
                if not factionData.isChild then
                    currentExpansion = factionData.name
                    currentFactionGroup = nil
                else
                    currentFactionGroup = nil
                    if factionData.factionID and factionData.factionID > 0 then
                        injectFaction(factionData)
                    end
                    currentFactionGroup = factionData.name
                end
            elseif factionData.factionID then
                injectFaction(factionData)
            end
        end
    end

    if injected > 0 then
        Utils.DebugPrint("Injected", injected, "dynamic reputation entries")
    end

    for pass = 1, 50 do
        local numFactionsPost = Caps.NumFactions()
        local didCollapse = false
        for i = numFactionsPost, 1, -1 do
            local factionData = Caps.FactionAt(i)
            if factionData and factionData.isHeader and headersWeExpanded[factionData.name] then
                local isExpanded = false
                if factionData.isHeaderExpanded ~= nil then
                    isExpanded = factionData.isHeaderExpanded
                elseif factionData.isCollapsed ~= nil then
                    isExpanded = not factionData.isCollapsed
                end

                if isExpanded then
                    Caps.SetFactionHeaderExpanded(i, false)
                    headersWeExpanded[factionData.name] = nil
                    didCollapse = true
                    break
                end
            end
        end
        if not didCollapse then break end
    end
    return true
end

local MOUNT_PROTO = {
    keywords     = {"mount", "ride"},
    keywordsLower = {"mount", "ride"},
    category     = "Mount",
    path         = {},
    steps        = {},
}




local mountTypeCache = {}
local mountCacheHydrated = false




local function ResolveMountTypeID(mountID, typeFilterActive)
    if not typeFilterActive then return nil end
    local GetExtra = C_MountJournal and C_MountJournal.GetMountInfoExtraByID
    if not GetExtra then return nil end
    local cached = mountTypeCache[mountID]
    if cached == nil then
        cached = select(5, GetExtra(mountID)) or false
        mountTypeCache[mountID] = cached
    end
    return cached or nil
end

local HOUSING_PROTO = {
    keywords      = {"housing", "decor", "decoration", "furniture"},
    keywordsLower = {"housing", "decor", "decoration", "furniture"},
    category      = "Housing",
    path          = {},
    steps         = {},
}



local HOUSING_ROOM_TYPE = (Enum and Enum.HousingCatalogEntryType and Enum.HousingCatalogEntryType.Room) or 2

local MOUNT_TYPE_GROUND_ONLY = 230
local MOUNT_TYPE_AMPHIBIOUS = 231
local MOUNT_TYPE_AQUATIC = 254
local MOUNT_TYPE_RIDE_ALONG = 412

local function MountTypePassesFilters(mountTypeID, db)
    if not mountTypeID then return true end
    local ground = not db or db.mountTypeGround ~= false
    local flying = not db or db.mountTypeFlying ~= false
    local aquatic = not db or db.mountTypeAquatic ~= false
    local rideAlong = not db or db.mountTypeRideAlong ~= false

    if mountTypeID == MOUNT_TYPE_GROUND_ONLY then return ground end
    if mountTypeID == MOUNT_TYPE_AMPHIBIOUS then return ground or aquatic end
    if mountTypeID == MOUNT_TYPE_AQUATIC then return aquatic end
    if mountTypeID == MOUNT_TYPE_RIDE_ALONG then return rideAlong end
    return flying
end

function Database:MountPassesSearchFilters(data)
    if not data or not data.mountID then return false end
    local db = EasyFind and EasyFind.db
    if not db then return true end

    if data.isCollected then
        if db.mountFilterCollected == false then return false end
    elseif db.mountFilterNotCollected == false then
        return false
    end

    local unusableOnThisChar = data.shouldHideOnChar or (data.isCollected and data.isUsable == false)
    if unusableOnThisChar and not db.mountFilterUnusable then return false end
    if not MountTypePassesFilters(data.mountTypeID, db) then return false end

    local sourceFilters = db.mountSourceFilters
    local sourceType = data.mountSourceType
    if sourceType and type(sourceFilters) == "table" and sourceFilters[sourceType] == false then
        return false
    end

    return true
end

local TOY_PROTO = {
    keywords     = {"toy", "fun"},
    keywordsLower = {"toy", "fun"},
    category     = "Toy",
    path         = {},
    steps        = {},
}
local TOY_MT = { __index = TOY_PROTO }

local PET_PROTO = {
    keywords     = {"pet", "companion", "battle pet"},
    keywordsLower = {"pet", "companion", "battle pet"},
    category     = "Pet",
    path         = {},
    steps        = {},
}
local PET_MT = { __index = PET_PROTO }

local OUTFIT_PROTO = {
    keywords     = {"outfit", "appearance"},
    keywordsLower = {"outfit", "appearance"},
    category     = "Outfit",
    path         = {},
    steps        = {},
}
local OUTFIT_MT = { __index = OUTFIT_PROTO }

local HEIRLOOM_PROTO = {
    keywords     = {"heirloom"},
    keywordsLower = {"heirloom"},
    category     = "Heirloom",
    path         = {},
    steps        = {},
}
local HEIRLOOM_MT = { __index = HEIRLOOM_PROTO }

local LOOT_PROTO = {
    category    = "Loot",
    path        = {},
    steps       = {},
    lootEntry   = true,


    lookupRow   = true,
}






local lootEncounterMTCache = {}
local function GetLootEncounterMT(encID, instID, encName, instName, isRaid)
    local cached = lootEncounterMTCache[encID]
    if cached then return cached end
    local proto = {
        category         = "Loot",
        path             = LOOT_PROTO.path,
        steps            = LOOT_PROTO.steps,
        lootEntry        = true,



        lookupRow        = true,
        encounterID      = encID,
        instanceID       = instID,
        lootSourceName   = encName,
        lootInstanceName = instName,
        lootSourceType   = isRaid and "Raid" or "Dungeon",
    }
    local mt = { __index = proto }
    lootEncounterMTCache[encID] = mt
    return mt
end

local TRANSMOG_SET_PROTO = {
    category = "Appearance Set",
    path     = {},
    steps    = {},
}

local APPEARANCE_ITEM_PROTO = {
    category = "Appearance",
    path     = {},
    steps    = {},
}
local APPEARANCE_ITEM_MT = { __index = APPEARANCE_ITEM_PROTO }

local TITLE_PROTO = {
    keywords     = {"title"},
    keywordsLower = {"title"},
    category     = "Title",
    path         = {},
    steps        = {},
}
local TITLE_MT = { __index = TITLE_PROTO }

local GEAR_SET_PROTO = {
    keywords     = {"gear", "set", "equipment", "equip", "loadout"},
    keywordsLower = {"gear", "set", "equipment", "equip", "loadout"},
    category     = "Gear Set",
    path         = {},
    steps        = {},
}
local GEAR_SET_MT = { __index = GEAR_SET_PROTO }


local SLOT_KEYWORDS = {
    INVTYPE_HEAD            = {"helm", "helmet", "head"},
    INVTYPE_NECK            = {"neck", "necklace", "amulet"},
    INVTYPE_SHOULDER        = {"shoulder", "shoulders", "pauldrons"},
    INVTYPE_CHEST           = {"chest", "chestpiece"},
    INVTYPE_ROBE            = {"chest", "robe", "chestpiece"},
    INVTYPE_WAIST           = {"waist", "belt"},
    INVTYPE_LEGS            = {"legs", "leggings", "pants"},
    INVTYPE_FEET            = {"feet", "boots"},
    INVTYPE_WRIST           = {"wrist", "bracers"},
    INVTYPE_HAND            = {"hands", "gloves", "gauntlets"},
    INVTYPE_FINGER          = {"ring", "finger"},
    INVTYPE_TRINKET         = {"trinket"},
    INVTYPE_CLOAK           = {"cloak", "back", "cape"},
    INVTYPE_WEAPON          = {"weapon", "one hand"},
    INVTYPE_WEAPONMAINHAND  = {"weapon", "main hand"},
    INVTYPE_WEAPONOFFHAND   = {"weapon", "off hand", "offhand"},
    INVTYPE_2HWEAPON        = {"weapon", "two hand", "2h"},
    INVTYPE_SHIELD          = {"shield", "off hand"},
    INVTYPE_RANGED          = {"ranged", "weapon"},
    INVTYPE_RANGEDRIGHT     = {"ranged", "weapon", "wand"},
    INVTYPE_HOLDABLE        = {"off hand", "held"},
}



Database.WEAPON_KEYWORDS = {
    [0] = {"axe", "axes"}, [1] = {"axe", "axes"},
    [2] = {"bow", "bows"}, [3] = {"gun", "guns"},
    [4] = {"mace", "maces"}, [5] = {"mace", "maces"},
    [6] = {"polearm", "polearms"},
    [7] = {"sword", "swords"}, [8] = {"sword", "swords"},
    [9] = {"warglaive", "warglaives", "glaive", "glaives"},
    [10] = {"staff", "staves"},
    [13] = {"fist", "fists"},
    [15] = {"dagger", "daggers"},
    [16] = {"thrown"},
    [17] = {"spear", "spears"},
    [18] = {"crossbow", "crossbows"},
    [19] = {"wand", "wands"},
}

local STAT_KEYWORD_MAP = {
    ITEM_MOD_CRIT_RATING_SHORT    = {"crit", "critical strike"},
    ITEM_MOD_HASTE_RATING_SHORT   = {"haste"},
    ITEM_MOD_MASTERY_RATING_SHORT = {"mastery"},
    ITEM_MOD_VERSATILITY          = {"vers", "versatility"},
    ITEM_MOD_INTELLECT_SHORT      = {"int", "intellect"},
    ITEM_MOD_AGILITY_SHORT        = {"agi", "agility"},
    ITEM_MOD_STRENGTH_SHORT       = {"str", "strength"},
}



ns.LOOT_STAT_CACHE_VER = 2



local function AddLookupWords(lookup, phrase, list)
    for part in phrase:gmatch("%S+") do
        if not lookup[part] then
            lookup[part] = true
            if list then list[#list + 1] = part end
        end
    end
end

local slotSearchWordLookup, slotSearchWordList
local function IsLootSlotSearchWord(word)
    if not slotSearchWordLookup then
        slotSearchWordLookup = {}
        slotSearchWordList = {}
        for _, words in pairs(SLOT_KEYWORDS) do
            for i = 1, #words do
                AddLookupWords(slotSearchWordLookup, words[i], slotSearchWordList)
            end
        end
        for _, words in pairs(Database.WEAPON_KEYWORDS) do
            for i = 1, #words do
                AddLookupWords(slotSearchWordLookup, words[i], slotSearchWordList)
            end
        end
    end
    if slotSearchWordLookup[word] then return true end




    if #word < 2 then return false end
    for i = 1, #slotSearchWordList do
        if sfind(slotSearchWordList[i], word, 1, true) == 1 then return true end
    end
    return false
end

function Database:IsLootSlotSearchWord(word)
    return IsLootSlotSearchWord(word)
end

local lockGen = 0
local function BumpLockGen()
    lockGen = lockGen + 1
end

local GetAvailableLFGCategories = C_LFGList and C_LFGList.GetAvailableCategories
local lfgAvailableCategories

function Database:InvalidateLFGAvailability()
    lfgAvailableCategories = nil
    BumpLockGen()
end





local function IsLFGCategoryLocked(categoryID)
    if not GetAvailableLFGCategories then return false end
    if not lfgAvailableCategories then
        local categories = GetAvailableLFGCategories()
        if not categories or #categories == 0 then return false end
        lfgAvailableCategories = {}
        for i = 1, #categories do lfgAvailableCategories[categories[i]] = true end
    end
    return not lfgAvailableCategories[categoryID]
end

function Database:IsLFGCategoryLocked(categoryID)
    return IsLFGCategoryLocked(categoryID)
end







local STEP_TARGET_KEYS = {
    "lfgCategoryID", "pvpSideTabIndex", "sideTabIndex", "tabIndex",
    "searchButtonText", "sidebarButtonFrame", "currencyID", "factionID",
    "achievementID", "statisticID",
}







local function StepSignature(step)
    local sig = step._efSig
    if sig == nil then
        sig = false
        for i = 1, #STEP_TARGET_KEYS do
            local key = STEP_TARGET_KEYS[i]
            local value = step[key]
            if value ~= nil then
                sig = key .. ":" .. tostring(value)
                break
            end
        end
        step._efSig = sig
    end
    if sig then return sig end
    return nil
end

local function CharKey()
    return ns.CurrentCharacterKey()
end

local function LearnedLocks()
    local db = EasyFind and EasyFind.db
    if not db then return nil end
    db.learnedStepLocks = db.learnedStepLocks or {}
    local key = CharKey()
    db.learnedStepLocks[key] = db.learnedStepLocks[key] or {}
    return db.learnedStepLocks[key]
end

function Database:LearnStepLock(step)
    local sig = StepSignature(step)
    if not sig then return end
    local locks = LearnedLocks()
    if locks then locks[sig] = true end
    BumpLockGen()
end

function Database:OnPlayerLevelUp()
    lfgAvailableCategories = nil
    local db = EasyFind and EasyFind.db
    if db and db.learnedStepLocks then
        db.learnedStepLocks[CharKey()] = nil
    end
    BumpLockGen()
end

function Database:IsStepLocked(step)
    if step._efLockGen == lockGen then
        return step._efLockState
    end
    step._efLockGen = lockGen
    local locked = false
    local highlight = ns.Highlight
    if highlight and highlight.GetStepLockState
       and highlight:GetStepLockState(step) == "locked" then
        locked = true
    else
        local sig = StepSignature(step)
        if sig then
            local locks = LearnedLocks()
            locked = (locks and locks[sig]) == true
        end
    end
    step._efLockState = locked
    return locked
end



function Database:GetEntryLockedReason(entry)
    local steps = entry.steps
    if not steps then return nil end
    for i = 1, #steps do
        if self:IsStepLocked(steps[i]) then
            return L["TOOLTIP_RESULT_LOCKED"]
        end
    end
    return nil
end








ns.LOOT_ITEM_CACHE_VER = 7
ns.BOSS_CACHE_VER = 4
ns.STATISTIC_CACHE_VER = 3
ns.MOUNT_CACHE_VER = 2
ns.HOUSING_CACHE_VER = 3
ns.TMOG_SET_CACHE_VER = 1









ns.TITLE_SOURCE_CACHE_VER = 4







ns.BANK_CACHE_VER = 1



ns.BAG_CACHE_VER = 1

local heavySearchWordLookup
local function AddHeavySearchWord(word)
    if not word or word == "" then return end
    word = slower(word)
    heavySearchWordLookup[word] = true
    if #word > 2 and ssub(word, #word, #word) ~= "s" then
        heavySearchWordLookup[word .. "s"] = true
    end
end

local function AddHeavySearchWords(words)
    for i = 1, #words do
        for word in words[i]:gmatch("%S+") do
            AddHeavySearchWord(word)
        end
    end
end

local function GetHeavySearchWordLookup()
    if heavySearchWordLookup then return heavySearchWordLookup end
    heavySearchWordLookup = {}
    AddHeavySearchWords({
        "loot", "item", "gear", "armor", "boss", "bosses",
        "dungeon", "raid", "weapon",
    })
    for equipLoc, words in pairs(SLOT_KEYWORDS) do
        AddHeavySearchWord(_G[equipLoc])
        AddHeavySearchWords(words)
    end
    for statKey, words in pairs(STAT_KEYWORD_MAP) do
        AddHeavySearchWord(_G[statKey])
        AddHeavySearchWords(words)
    end
    Database.AddGearAndInstanceSearchWords(AddHeavySearchWord)
    return heavySearchWordLookup
end

local statSearchWordLookup
local function IsLootStatSearchWord(word)
    if not statSearchWordLookup then
        statSearchWordLookup = {}
        for statKey, words in pairs(STAT_KEYWORD_MAP) do
            local label = _G[statKey]
            if label then
                AddLookupWords(statSearchWordLookup, slower(label))
            end
            for i = 1, #words do
                AddLookupWords(statSearchWordLookup, words[i])
            end
        end
    end
    return statSearchWordLookup[word] or false
end

function Database:IsLootStatSearchWord(word)
    return IsLootStatSearchWord(word)
end

function Database:QueryNeedsHeavySearchData(text)
    if not text then return false end
    local lookup = GetHeavySearchWordLookup()
    local query = slower(text)
    if self.NormalizeSearchQuery then
        query = self:NormalizeSearchQuery(query)
    end
    for word in query:gmatch("%S+") do
        word = word:gsub("^%p+", ""):gsub("%p+$", "")
        if lookup[word] then return true end
    end
    return false
end

local SLOT_DISPLAY = {
    INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulder",
    INVTYPE_CHEST = "Chest", INVTYPE_ROBE = "Chest", INVTYPE_WAIST = "Waist",
    INVTYPE_LEGS = "Legs", INVTYPE_FEET = "Feet", INVTYPE_WRIST = "Wrist",
    INVTYPE_HAND = "Hands", INVTYPE_FINGER = "Ring", INVTYPE_TRINKET = "Trinket",
    INVTYPE_CLOAK = "Cloak", INVTYPE_WEAPON = "Weapon", INVTYPE_WEAPONMAINHAND = "Main Hand",
    INVTYPE_WEAPONOFFHAND = "Off Hand", INVTYPE_2HWEAPON = "Two-Hand",
    INVTYPE_SHIELD = "Shield", INVTYPE_RANGED = "Ranged", INVTYPE_RANGEDRIGHT = "Ranged",
    INVTYPE_HOLDABLE = "Off Hand",
}





local FILTER_TO_INVTYPE = {}
do
    local slotFilter = Enum and Enum.ItemSlotFilterType
    if slotFilter then
        local byName = {
            Head = "INVTYPE_HEAD", Neck = "INVTYPE_NECK", Shoulder = "INVTYPE_SHOULDER",
            Cloak = "INVTYPE_CLOAK", Chest = "INVTYPE_CHEST", Wrist = "INVTYPE_WRIST",
            Hand = "INVTYPE_HAND", Waist = "INVTYPE_WAIST", Legs = "INVTYPE_LEGS",
            Feet = "INVTYPE_FEET", MainHand = "INVTYPE_WEAPONMAINHAND",
            OffHand = "INVTYPE_WEAPONOFFHAND", Finger = "INVTYPE_FINGER",
            Trinket = "INVTYPE_TRINKET",
        }
        for enumName, invType in pairs(byName) do
            local enumValue = slotFilter[enumName]
            if enumValue then FILTER_TO_INVTYPE[enumValue] = invType end
        end
    end
end



local function EJ(name)
    return (C_EncounterJournal and C_EncounterJournal[name]) or _G["EJ_" .. name]
end

local lootEntries = {}
local lootScanGeneration = 0
local bossScanGeneration = 0
local lootItemCache = {}
Database._lootItemCache = lootItemCache
local lootSpecsScanned = {}



local lootEventFrame
local activeLootScan
local lootItemCacheHydrated = false
local lootSearchDataHydrated = false
local bossCacheHydrated = false
local statisticCacheHydrated = false

local function CopyArray(src)
    local out = {}
    if type(src) ~= "table" then return out end
    for i = 1, #src do out[i] = src[i] end
    return out
end


local LOOT_ROW_SPEC = {
    { "itemID" }, { "name" }, { "icon" },
    { "lootSlotKw", "list" }, { "lootSourceKw", "list" }, { "lootStatKw", "list" },
    { "lootItemLinks", "map" }, { "lootSlotName" },
    { "_cachedSpecs", "list" }, { "_cachedDiffs", "list" }, { "_statsEnriched" },
    { "encounterID" }, { "instanceID" },
    { "lootSourceName" }, { "lootInstanceName" }, { "lootSourceType" },
}






Corpora.LOOT_COMPUTED = {


    lootItemLinks = function() return {} end,
}


function Corpora.HasLootCache()
    if next(lootItemCache) ~= nil then return true end
    return Corpora.lootCorpus ~= nil and Corpora.lootCorpus.count > 0
end

local function HydratePersistedLootCache()
    if lootItemCacheHydrated then return end
    lootItemCacheHydrated = true
    local db = EasyFind and EasyFind.db
    local saved = db and db.lootItemCache
    if type(saved) ~= "table" or db.lootItemCacheVer ~= ns.LOOT_ITEM_CACHE_VER then return end
    if type(saved.packed) ~= "string" or saved.packed == "" then return end

    if not Corpora.LOOT_CORPUS_PROTO then
        Corpora.LOOT_CORPUS_PROTO = {
            category  = "Loot",
            path      = LOOT_PROTO.path,
            steps     = LOOT_PROTO.steps,
            lootEntry = true,
            lookupRow = true,
            keywords  = EMPTY_KEYWORDS,
        }
    end






    Corpora.lootCorpus = Utils.NewPackedCorpus(saved.packed, LOOT_ROW_SPEC, Corpora.LOOT_CORPUS_PROTO,
        { ungated = true, noShed = true, computed = Corpora.LOOT_COMPUTED, sliced = true })
    Utils.RegisterCorpus("loot", Corpora.lootCorpus)


    Corpora.lootItemRi = nil
    setmetatable(lootItemCache, {
        __index = function(t, itemID)
            local ri = Corpora.lootItemRi and Corpora.lootItemRi[itemID]
            if not ri or not Corpora.lootCorpus then return nil end
            local stub = Corpora.lootCorpus:StubAt(ri)
            rawset(t, itemID, stub)
            return stub
        end,
    })

    if type(saved.specsScanned) == "table" then
        for key, value in pairs(saved.specsScanned) do
            if value then lootSpecsScanned[key] = true end
        end
    end
end

local function PersistLootCache()
    local db = EasyFind and EasyFind.db
    if not db then return end

    local specsScanned = {}
    for key in pairs(lootSpecsScanned) do
        specsScanned[key] = true
    end



    if Corpora.lootCorpus and Corpora.lootItemRi then
        for itemID, ri in pairs(Corpora.lootItemRi) do
            if rawget(lootItemCache, itemID) == nil then
                lootItemCache[itemID] = Corpora.lootCorpus:StubAt(ri)
            end
        end
    end


    local rows, n = {}, 0
    for itemID, entry in pairs(lootItemCache) do
        n = n + 1
        rows[n] = {
            itemID = itemID,
            name = entry.name,
            icon = entry.icon,
            lootSlotKw = entry.lootSlotKw,
            lootSourceKw = entry.lootSourceKw,
            lootStatKw = entry.lootStatKw,
            lootItemLinks = entry.lootItemLinks,
            lootSlotName = entry.lootSlotName,
            _cachedSpecs = entry._cachedSpecs,
            _cachedDiffs = entry._cachedDiffs,
            _statsEnriched = entry._statsEnriched == true,
            encounterID = entry.encounterID,
            instanceID = entry.instanceID,
            lootSourceName = entry.lootSourceName,
            lootInstanceName = entry.lootInstanceName,
            lootSourceType = entry.lootSourceType,
        }
    end
    db.lootItemCache = {
        version = ns.LOOT_ITEM_CACHE_VER,
        specsScanned = specsScanned,
        packed = Utils.PackRows(rows, LOOT_ROW_SPEC),
    }
    db.lootItemCacheVer = ns.LOOT_ITEM_CACHE_VER
end

local LOOT_DIFF_IDS = {
    lfr     = { raid = 17 },
    normal  = { dungeon = 1,  raid = 14 },
    heroic  = { dungeon = 2,  raid = 15 },
    mythic  = { dungeon = 23, raid = 16 },
}


function Database.LootDifficulty()
    local key = EasyFind.db.lootDifficulty or "normal"
    local offered = ns.Caps and ns.Caps.lootDifficulties or {}
    for i = 1, #offered do
        if offered[i] == key then return key end
    end
    return "normal"
end

function Database:GetEJDifficultyID(sourceType)
    local diffKey = Database.LootDifficulty()
    local diffIDs = LOOT_DIFF_IDS[diffKey]
    if not diffIDs then return nil end
    local srcKey = sourceType == "Raid" and "raid" or "dungeon"
    return diffIDs[srcKey]
end

function Database:SetEJDifficulty(diffID)
    if not diffID then return end
    local setDiff = EJ("SetDifficulty")
    if setDiff then setDiff(diffID) end
end

function Database:SyncEJLootFilter()
    local setFilter = EJ("SetLootFilter")
    if not setFilter then return end

    EasyFind._lootFilterHookSuppress = true
    local lf = EasyFind.db.lootFilter
    if not lf then
        local _, _, cid = UnitClass("player")
        local si = GetSpecialization and GetSpecialization()
        local sid = si and GetSpecializationInfo and GetSpecializationInfo(si)
        if cid and sid then
            setFilter(cid, sid)
        end
    elseif lf == "all" then
        setFilter(0, 0)
    elseif lf.specID then
        setFilter(lf.classID, lf.specID)
    elseif lf.classID then
        setFilter(lf.classID, 0)
    end
    EasyFind._lootFilterHookSuppress = false
end




function Database:SyncHeirloomJournalFilter()
    if not C_Heirloom or not C_Heirloom.SetClassAndSpecFilters then return end
    local f = EasyFind.db and EasyFind.db.heirloomFilter
    local classID, specID
    if not f then
        local _, _, cid = UnitClass("player")
        local si = GetSpecialization and GetSpecialization()
        local sid = si and GetSpecializationInfo and GetSpecializationInfo(si)
        classID, specID = cid or 0, sid or 0
    elseif f == "all" then
        classID, specID = 0, 0
    elseif f.specID then
        classID, specID = f.classID, f.specID
    else
        classID, specID = f.classID, 0
    end
    EasyFind._heirloomHookSuppress = true
    pcall(C_Heirloom.SetClassAndSpecFilters, classID, specID)
    EasyFind._heirloomHookSuppress = false
end




local function ClassSpecIDs(classID)
    local specs = {}
    if not (ns.Caps and ns.Caps.specs) then return specs end
    for specIdx = 1, GetNumSpecializationsForClassID(classID) do
        local specID = GetSpecializationInfoForClassID(classID, specIdx)
        if specID then specs[#specs + 1] = specID end
    end
    return specs
end

local function RebuildLootSearchData()




    local writeIdx = 0
    for i = 1, #uiSearchData do
        local entry = uiSearchData[i]
        if entry.category ~= "Loot" then
            writeIdx = writeIdx + 1
            uiSearchData[writeIdx] = entry
        elseif ns.SearchIndex and ns.SearchIndex.NoteRemoved then
            ns.SearchIndex:NoteRemoved(entry)
        end
    end
    for i = #uiSearchData, writeIdx + 1, -1 do
        uiSearchData[i] = nil
    end
    if ns.SearchIndex and ns.SearchIndex.NoteCompacted then
        ns.SearchIndex:NoteCompacted(writeIdx)
    end
    wipe(lootEntries)



    local lootFilter = EasyFind.db.lootFilter
    local wantSpec = {}
    local wantAll = false
    if not lootFilter then
        local _, _, cid = UnitClass("player")
        local si = GetSpecialization and GetSpecialization()
        local sid = si and GetSpecializationInfo and GetSpecializationInfo(si)
        if cid and sid then
            wantSpec[cid .. "-" .. sid] = true
        elseif cid then

            for _, specID in ipairs(ClassSpecIDs(cid)) do
                wantSpec[cid .. "-" .. specID] = true
            end
        end
    elseif lootFilter == "all" then
        wantAll = true
    elseif lootFilter.specID then
        wantSpec[lootFilter.classID .. "-" .. lootFilter.specID] = true
    elseif lootFilter.classID then
        for _, specID in ipairs(ClassSpecIDs(lootFilter.classID)) do
            wantSpec[lootFilter.classID .. "-" .. specID] = true
        end
    end

    local wantDiff = Database.LootDifficulty()

    local wantClass
    if not wantAll then
        if type(lootFilter) == "table" then wantClass = lootFilter.classID
        else wantClass = select(3, UnitClass("player")) end
    end



    local function wanted(specs, diffs, itemID)
        local specMatch = wantAll
        if not specMatch and specs then
            for i = 1, #specs do
                if specs[i] == "*" then
                    specMatch = not wantClass or Database.LootForClass(itemID, wantClass)
                    break
                elseif wantSpec[specs[i]] then
                    specMatch = true
                    break
                end
            end
        end
        if not specMatch then return false end
        if diffs then
            for i = 1, #diffs do
                if diffs[i] == "*" or diffs[i] == wantDiff then return true end
            end
        end
        return false
    end






    if Corpora.lootCorpus then
        local corpus = Corpora.lootCorpus
        local ri2item = Corpora.lootItemRi
        local building = ri2item == nil
        if building then
            ri2item = {}
            Corpora.lootItemRi = ri2item
        end


        local wantedFields = building
            and { itemID = true, name = true, encounterID = true, instanceID = true,
                  _cachedSpecs = true, _cachedDiffs = true }
            or { itemID = true, _cachedSpecs = true, _cachedDiffs = true }
        corpus:EachRow(function(ri, row)
            local itemID = row.itemID
            if building then
                if itemID and row.name and row.name ~= "" and row.encounterID and row.instanceID then
                    ri2item[itemID] = ri
                else
                    itemID = nil
                end
            end
            if itemID and ri2item[itemID] == ri then
                local live = rawget(lootItemCache, itemID)
                local specs = live and live._cachedSpecs or row._cachedSpecs
                local diffs = live and live._cachedDiffs or row._cachedDiffs
                if wanted(specs, diffs, itemID) then
                    local entry = live or corpus:StubAt(ri)
                    uiSearchData[#uiSearchData + 1] = entry
                    lootEntries[#lootEntries + 1] = entry
                end
            end
        end, wantedFields, true)
    end
    for itemID, entry in pairs(lootItemCache) do
        if not (Corpora.lootItemRi and Corpora.lootItemRi[itemID])
           and wanted(entry._cachedSpecs, entry._cachedDiffs, itemID) then
            uiSearchData[#uiSearchData + 1] = entry
            lootEntries[#lootEntries + 1] = entry
        end
    end
    lootSearchDataHydrated = true
    EasyFind.API.Fire("loot", "changed")
end

local DIFF_PRIORITY = { "mythic", "heroic", "normal", "lfr" }





function Database.NoWardrobe()
    return ns.Caps ~= nil and ns.Caps.transmog == false
end


Database.CATEGORY_SLOT = {
    [1] = 1, [2] = 3, [3] = 15, [4] = 5, [5] = 4, [6] = 19,
    [7] = 9, [8] = 10, [9] = 6, [10] = 7, [11] = 8,
}



function Database.TransmogLocation(category)
    local C = C_TransmogCollection
    local slotID = Database.CATEGORY_SLOT[category]
    if not slotID and C and C.GetCategoryInfo then
        local name, isWeapon, _, canMainHand, canOffHand, canRanged = C.GetCategoryInfo(category)
        if name and isWeapon then
            slotID = (canMainHand and (INVSLOT_MAINHAND or 16))
                or (canOffHand and (INVSLOT_OFFHAND or 17))
                or (canRanged and (INVSLOT_RANGED or 18))
        end
    end
    if not slotID then return nil end
    return {
        slotID = slotID,
        type = (Enum.TransmogType and Enum.TransmogType.Appearance) or 0,
        modification = (Enum.TransmogModification and Enum.TransmogModification.Main) or 0,
    }
end

function Database.CategoryAppearances(category)
    local C = C_TransmogCollection
    if Database.NoWardrobe() or not (C and C.GetCategoryAppearances) then return nil end
    local location = Database.TransmogLocation(category)
    if not location then return nil end
    local ok, list = pcall(C.GetCategoryAppearances, category, location)
    if ok then return list end
    return nil
end

function Database.AppearanceSources(visualID, category)
    local C = C_TransmogCollection
    if Database.NoWardrobe() or not (C and C.GetAppearanceSources) then return nil end
    local location = Database.TransmogLocation(category)
    if not location then return nil end
    local ok, list = pcall(C.GetAppearanceSources, visualID, category, location)
    if ok then return list end
    return nil
end

function Database.AllTransmogSets()
    if Database.NoWardrobe() or not (C_TransmogSets and C_TransmogSets.GetAllSets) then return nil end
    local ok, sets = pcall(C_TransmogSets.GetAllSets)
    if ok then return sets end
    return nil
end


function Database:GetTransmogSetIDByName(name)
    if not name or not C_TransmogSets or not C_TransmogSets.GetAllSets then return nil end
    local allSets = Database.AllTransmogSets()
    if not allSets then return nil end
    for i = 1, #allSets do
        local s = allSets[i]
        if s and s.name == name then return s.setID end
    end
    return nil
end

function Database:GetLootItemLink(entry)
    local links = entry.lootItemLinks

    if not links and entry.itemID then
        local live = lootItemCache[entry.itemID]
        if live then links = live.lootItemLinks end
    end
    local selected = Database.LootDifficulty()
    if links and links[selected] then return links[selected] end
    for _, dk in ipairs(links and DIFF_PRIORITY or {}) do
        if links[dk] then return links[dk] end
    end

    if entry.itemID and C_Item and C_Item.GetItemInfo then
        return (select(2, C_Item.GetItemInfo(entry.itemID)))
    end
    return nil
end





EasyFind.API.RegisterAction("loot", "ensure", function(fn)
    return Database:EnsureDynamicProviderLoaded("loot", type(fn) == "function" and fn or nil)
end)
EasyFind.API.RegisterAction("loot", "entries", function()
    if not Corpora.HasLootCache() then return nil end
    if Corpora.lootCorpus and Corpora.lootItemRi then
        for itemID, ri in pairs(Corpora.lootItemRi) do
            if rawget(lootItemCache, itemID) == nil then lootItemCache[itemID] = Corpora.lootCorpus:StubAt(ri) end
        end
    end
    local out = {}
    for itemID, e in pairs(lootItemCache) do
        local links = {}
        for k, v in pairs(e.lootItemLinks or {}) do links[k] = v end
        out[#out + 1] = { itemID = itemID, name = e.name, icon = e.icon, slotName = e.lootSlotName, links = links,
            bossName = e.lootSourceName, encounterID = e.encounterID, instanceName = e.lootInstanceName,
            instanceID = e.instanceID, isRaid = e.lootSourceType == "Raid" }
    end
    return out
end)
EasyFind.API.RegisterAction("loot", "link", function(itemID)
    local e = itemID and lootItemCache[itemID]
    return e and Database:GetLootItemLink(e) or nil
end)
EasyFind.API.RegisterAction("loot", "open", function(itemID)
    local e = itemID and lootItemCache[itemID]
    if not (e and ns.ResultHandlers and ns.ResultHandlers.OpenLootSource) then return false end
    ns.ResultHandlers:OpenLootSource(e, true)
    return true
end)





local pendingStatEnrichment = {}
Database._pendingStatEnrichment = pendingStatEnrichment

function Database:EnrichLootStats(entry)
    if entry._statsEnriched then return end
    local itemID = entry.itemID



    local cache = EasyFind.db and EasyFind.db.lootStatCache
    if itemID and cache and cache[itemID] then
        entry.lootStatKw = cache[itemID]
        entry._statsEnriched = true
        return
    end
    local link = Database:GetLootItemLink(entry)
    local GetItemStatsFn = (C_Item and C_Item.GetItemStats) or GetItemStats
    if not GetItemStatsFn then return end
    local stats = link and GetItemStatsFn(link)
    if not stats and itemID then
        stats = GetItemStatsFn("item:" .. itemID)
    end
    if not stats or not next(stats) then



        if itemID then
            pendingStatEnrichment[itemID] = entry
            if ns.OnStatEnrichmentQueued then ns.OnStatEnrichmentQueued() end
            if C_Item and C_Item.RequestLoadItemDataByID then
                pcall(C_Item.RequestLoadItemDataByID, itemID)
            end
        end
        return
    end
    local statKw = entry.lootStatKw or {}
    for statKey, searchWords in pairs(STAT_KEYWORD_MAP) do
        if stats[statKey] then
            for _, word in ipairs(searchWords) do
                statKw[#statKw + 1] = word
            end
        end
    end
    entry.lootStatKw = statKw
    entry._statsEnriched = true
    if itemID and cache then
        cache[itemID] = statKw
    end
end




function Database:ResolvePendingStatEnrichment(itemID, success)
    if not success then

        pendingStatEnrichment[itemID] = nil
        return false
    end
    local entry = pendingStatEnrichment[itemID]
    if not entry then return false end
    pendingStatEnrichment[itemID] = nil
    Database:EnrichLootStats(entry)
    return entry._statsEnriched == true
end

local function MountTypeFilterActive(db)
    return db ~= nil and (db.mountTypeGround == false or db.mountTypeFlying == false
        or db.mountTypeAquatic == false or db.mountTypeRideAlong == false)
end




Corpora.MOUNT_COMPUTED = {
    mountTypeID = function(stub)
        local db = EasyFind and EasyFind.db
        return ResolveMountTypeID(stub.mountID, MountTypeFilterActive(db))
    end,
}









local MOUNT_ROW_SPEC = {
    { "name" }, { "icon" }, { "mountID" }, { "spellID" },
    { "isCollected" }, { "isUsable" }, { "shouldHideOnChar" }, { "mountSourceType" },
}

local function PersistMountCache(packed, guid)
    local db = EasyFind and EasyFind.db
    if not db or not packed then return end
    db.mountCache = {
        version = ns.MOUNT_CACHE_VER,
        guid = guid,
        packed = packed,
    }
    db.mountCacheVer = ns.MOUNT_CACHE_VER
end

function Database:InvalidateMountCache()
    local db = EasyFind and EasyFind.db
    if not db then return end
    db.mountCache = nil
    db.mountCacheVer = nil
    if self._BumpMountWalkGen then self._BumpMountWalkGen() end
end



function Corpora.MountCorpusFor(packed)
    local corpus = Utils.GetCorpus("mounts")
    if not (corpus and corpus.packed == packed) then
        corpus = Utils.NewPackedCorpus(packed, MOUNT_ROW_SPEC, MOUNT_PROTO,
            { computed = Corpora.MOUNT_COMPUTED, sliced = true })
        Utils.RegisterCorpus("mounts", corpus)
    end
    return corpus
end

function Corpora.MountIncludeRow(corpus, ri, row, typeFilterActive)
    if not (row.name and row.mountID) then return 0 end
    row.mountTypeID = ResolveMountTypeID(row.mountID, typeFilterActive)
    if not Database:MountPassesSearchFilters(row) then return 0 end
    uiSearchData[#uiSearchData + 1] = corpus:StubAt(ri)
    return 1
end



function Corpora.InsertMountStubs(corpus)
    local db = EasyFind and EasyFind.db
    local typeFilterActive = MountTypeFilterActive(db)
    local inserted = 0
    corpus:EachRow(function(ri, row)
        inserted = inserted + Corpora.MountIncludeRow(corpus, ri, row, typeFilterActive)
    end, { name = true, mountID = true, isCollected = true, isUsable = true,
           shouldHideOnChar = true, mountSourceType = true }, true)
    return inserted
end

local function HydratePersistedMountCache()
    if mountCacheHydrated then return false end
    mountCacheHydrated = true

    local db = EasyFind and EasyFind.db
    local saved = db and db.mountCache
    if type(saved) ~= "table" or db.mountCacheVer ~= ns.MOUNT_CACHE_VER then
        return false
    end
    if saved.guid ~= (UnitGUID and UnitGUID("player")) then return false end
    if type(saved.packed) ~= "string" or saved.packed == "" then return false end
    local corpus = Corpora.MountCorpusFor(saved.packed)
    if corpus.count == 0 then return false end

    RemoveEntriesByCategory("Mount")

    local inserted = Corpora.InsertMountStubs(corpus)
    if inserted == 0 then return false end
    if Database.ResetSearchCache then Database:ResetSearchCache() end
    return true
end

function Database:PopulateDynamicMounts()
    if not C_MountJournal or not C_MountJournal.GetMountIDs then return false end

    if HydratePersistedMountCache() then return true end



    local mountIDs = C_MountJournal.GetMountIDs()
    if not mountIDs then return false end

    RemoveEntriesByCategory("Mount")





    local GetMountInfoByID = C_MountJournal.GetMountInfoByID

    local rows = {}
    for _, mountID in ipairs(mountIDs) do
        local name, spellID, icon, _, isUsable, sourceType, _,
              _, _, shouldHideOnChar, isCollected = GetMountInfoByID(mountID)
        if name then
            rows[#rows + 1] = {
                name             = name,
                icon             = icon,
                mountID          = mountID,
                spellID          = spellID,
                isCollected      = isCollected and true or false,
                isUsable         = isUsable and true or false,
                shouldHideOnChar = shouldHideOnChar and true or false,
                mountSourceType  = sourceType,
            }
        end
    end
    local packed = Utils.PackRows(rows, MOUNT_ROW_SPEC)
    PersistMountCache(packed, UnitGUID and UnitGUID("player"))
    Corpora.InsertMountStubs(Corpora.MountCorpusFor(packed))
    return true
end






local mountWalkGen = 0
Database._BumpMountWalkGen = function() mountWalkGen = mountWalkGen + 1 end

function Database:PopulateDynamicMountsAsync(done)
    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        done(false)
        return
    end
    if HydratePersistedMountCache() then
        done(true)
        return
    end

    local mountIDs = C_MountJournal.GetMountIDs()
    if not mountIDs then
        done(false)
        return
    end

    RemoveEntriesByCategory("Mount")

    local GetMountInfoByID = C_MountJournal.GetMountInfoByID
    mountWalkGen = mountWalkGen + 1
    local myGen = mountWalkGen
    local rows = {}
    local i = 1
    local total = #mountIDs
    local budgetMs = 4
    local dps = debugprofilestop
    local function slice()
        if myGen ~= mountWalkGen then
            done(false, "cancelled")
            return
        end
        local start = dps and dps() or 0
        local processed = 0
        while i <= total do
            local mountID = mountIDs[i]
            i = i + 1
            local name, spellID, icon, _, isUsable, sourceType, _,
                  _, _, shouldHideOnChar, isCollected = GetMountInfoByID(mountID)
            if name then
                rows[#rows + 1] = {
                    name             = name,
                    icon             = icon,
                    mountID          = mountID,
                    spellID          = spellID,
                    isCollected      = isCollected and true or false,
                    isUsable         = isUsable and true or false,
                    shouldHideOnChar = shouldHideOnChar and true or false,
                    mountSourceType  = sourceType,
                }
            end
            processed = processed + 1
            if (dps and (dps() - start) >= budgetMs) or (not dps and processed >= 80) then
                Utils.SafeAfter(0, slice)
                return
            end
        end
        local packed = Utils.PackRows(rows, MOUNT_ROW_SPEC)
        PersistMountCache(packed, UnitGUID and UnitGUID("player"))
        Corpora.InsertMountStubs(Corpora.MountCorpusFor(packed))
        done(true)
    end
    slice()
end





function Database:_MeasureMountCache()
    local dps = debugprofilestop
    if not (dps and C_MountJournal and C_MountJournal.GetMountIDs) then return end
    local function countMounts()
        local n = 0
        for i = 1, #uiSearchData do
            if uiSearchData[i].category == "Mount" then n = n + 1 end
        end
        return n
    end

    self:InvalidateMountCache()
    mountCacheHydrated = false
    local t0 = dps()
    self:PopulateDynamicMounts()
    local walkMs = dps() - t0
    local walkN = countMounts()

    mountCacheHydrated = false
    t0 = dps()
    local hydrated = self:PopulateDynamicMounts()
    local hydrateMs = dps() - t0
    local hydrateN = countMounts()

    self:TakePopulatedRows("Mount")
    self:UnholdPopulated("Mount")
    mountCacheHydrated = true
    if self.ResetSearchCache then self:ResetSearchCache() end
    return { walkMs = walkMs, hydrateMs = hydrateMs,
             walkN = walkN, hydrateN = hydrateN, hydrated = hydrated }
end





local housingSearcher
local housingSearchDone
local housingCacheHydrated = false








local HOUSING_ROW_SPEC = {
    { "name" }, { "icon" }, { "housingEntryID" },
    { "housingRecordID" }, { "housingNumStored" }, { "housingNumPlaced" },
    { "housingQuality" }, { "housingSourceText" }, { "isRoom" },
}

local function PersistHousingCache(packed, guid)
    local db = EasyFind and EasyFind.db
    if not db then return end
    db.housingCache = {
        version = ns.HOUSING_CACHE_VER,
        guid = guid,
        packed = packed,
    }
    db.housingCacheVer = ns.HOUSING_CACHE_VER
end

local function HydratePersistedHousingCache()
    if housingCacheHydrated then return false end
    housingCacheHydrated = true
    local db = EasyFind and EasyFind.db
    local saved = db and db.housingCache
    if type(saved) ~= "table" or db.housingCacheVer ~= ns.HOUSING_CACHE_VER then
        return false
    end
    if saved.guid ~= (UnitGUID and UnitGUID("player")) then return false end
    if type(saved.packed) ~= "string" or saved.packed == "" then return false end




    local corpus = Utils.NewPackedCorpus(saved.packed, HOUSING_ROW_SPEC, HOUSING_PROTO, { sliced = true })
    if corpus.count == 0 then return false end
    Utils.RegisterCorpus("housing", corpus)

    RemoveEntriesByCategory("Housing")
    local inserted = 0
    corpus:EachRow(function(ri, row)
        if row.name and row.housingEntryID then
            uiSearchData[#uiSearchData + 1] = corpus:StubAt(ri)
            inserted = inserted + 1
        end
    end, { name = true, housingEntryID = true }, true)
    if inserted == 0 then return false end
    Corpora.packedLive.Housing = saved.packed
    if Database.ResetSearchCache then Database:ResetSearchCache() end
    return true
end

function Database:FinishHousingResults(done)
    local searcher = housingSearcher
    if not (C_HousingCatalog and searcher) then
        done(false)
        return
    end
    local okIDs, entryIDs = pcall(searcher.GetCatalogSearchResults, searcher)
    if not okIDs or type(entryIDs) ~= "table" then
        done(false, "cancelled")
        return
    end



    Corpora.housingFinishGen = (Corpora.housingFinishGen or 0) + 1
    local gen = Corpora.housingFinishGen
    Utils.RunSliced(function()




        local GetCatalogEntryInfo = C_HousingCatalog.GetCatalogEntryInfo



        local keyOrder, keyParts = nil, {}
        local function EntryKey(id)
            if type(id) ~= "table" then return id end
            if not keyOrder then
                keyOrder = {}
                for k, v in pairs(id) do
                    if type(v) ~= "table" then keyOrder[#keyOrder + 1] = k end
                end
                table.sort(keyOrder, function(a, b) return tostring(a) < tostring(b) end)
            end
            for k = 1, #keyOrder do keyParts[k] = tostring(id[keyOrder[k]]) end
            return table.concat(keyParts, ":", 1, #keyOrder)
        end
        local fresh = {}
        for i = 1, #entryIDs do
            if i % 64 == 0 then Utils.SliceCheckpoint() end
            local okInfo, info = pcall(GetCatalogEntryInfo, entryIDs[i])
            if okInfo and info and info.name and info.name ~= "" then
                fresh[#fresh + 1] = {
                    name = info.name,
                    icon = info.iconTexture,
                    housingEntryID = EntryKey(entryIDs[i]),
                    housingRecordID = info.recordID,
                    housingNumStored = info.totalNumStored,
                    housingNumPlaced = info.totalNumPlaced,
                    housingQuality = info.quality,
                    housingSourceText = info.sourceText,
                    isRoom = info.entryType == HOUSING_ROOM_TYPE or nil,
                }
            end
        end




        if #fresh == 0 or gen ~= Corpora.housingFinishGen then return "cancelled" end
        local packed = Utils.PackRows(fresh, HOUSING_ROW_SPEC, true)
        if gen ~= Corpora.housingFinishGen then return "cancelled" end

        if packed == Corpora.packedLive.Housing then return "unchanged" end
        PersistHousingCache(packed, UnitGUID and UnitGUID("player"))
        local corpus = Utils.NewPackedCorpus(packed, HOUSING_ROW_SPEC, HOUSING_PROTO, { sliced = true })
        local stubs = {}
        for ri = 1, corpus.count do
            if ri % 256 == 0 then Utils.SliceCheckpoint() end
            stubs[ri] = corpus:StubAt(ri)
        end
        if gen ~= Corpora.housingFinishGen then return "cancelled" end


        Utils.RegisterCorpus("housing", corpus)
        RemoveEntriesByCategory("Housing")
        for i = 1, #stubs do
            uiSearchData[#uiSearchData + 1] = stubs[i]
        end
        Corpora.packedLive.Housing = packed
    end, function(ok, result)
        if not ok then
            done(false, result)
        elseif result == "cancelled" then
            done(false, "cancelled")
        else
            done(result ~= "unchanged")
        end
    end, Corpora.packedLive.Housing and 1.5 or nil, "housingRows")
end




local function BlizzardCatalogSearcher()
    local dash = _G["HousingDashboardFrame"]
    local content = dash and dash.CatalogContent
    local s = content and content.catalogSearcher
    if type(s) ~= "userdata" then return nil end
    local ok, hasGetter = pcall(function() return s.GetSortType ~= nil end)
    if ok and hasGetter then return s end
    return nil
end



local function ForEachHousingFilterTag(fn)
    if not (C_HousingCatalog and C_HousingCatalog.GetAllFilterTagGroups) then return end
    local ok, groups = pcall(C_HousingCatalog.GetAllFilterTagGroups)
    if not ok or type(groups) ~= "table" then return end
    for gi = 1, #groups do
        local grp = groups[gi]
        local gid = grp and grp.groupID
        local tags = grp and grp.tags
        if gid and tags then
            for ti = 1, #tags do
                local tid = tags[ti] and tags[ti].tagID
                if tid then fn(gid, tid) end
            end
        end
    end
end






function Database:SyncHousingFiltersFromBlizzard()
    return ns.ControlSync.Sync("housing")
end



local function ApplyHousingFilters(searcher, db)
    if not (searcher and db) then return end
    local mode = db.housingCollection or "collected"
    if searcher.SetCollected then searcher:SetCollected(mode ~= "uncollected") end
    if searcher.SetUncollected then searcher:SetUncollected(mode ~= "collected") end
    if searcher.SetCustomizableOnly then searcher:SetCustomizableOnly(db.housingDyeableOnly == true) end
    if searcher.SetFirstAcquisitionBonusOnly then
        searcher:SetFirstAcquisitionBonusOnly(db.housingCollectionBonusOnly == true)
    end
    if searcher.SetAllowedIndoors then searcher:SetAllowedIndoors(db.housingIndoors ~= false) end
    if searcher.SetAllowedOutdoors then searcher:SetAllowedOutdoors(db.housingOutdoors ~= false) end
    if searcher.SetSortType then searcher:SetSortType(db.housingSortType or 0) end
    if searcher.SetFilterTagStatus then
        local tags = db.housingTags
        ForEachHousingFilterTag(function(gid, tid)


            local grpState = tags and tags[gid]
            if grpState then
                pcall(searcher.SetFilterTagStatus, searcher, gid, tid, grpState[tid] == true)
            end
        end)
    end
end

ns.ControlSync.Register{
    key = "housing",
    pendingKey = "housingFiltersPendingPush",
    state = function() return EasyFind.db end,
    available = function() return BlizzardCatalogSearcher() ~= nil end,
    push = function(db)
        local s = BlizzardCatalogSearcher()
        if not s then return end
        pcall(function()
            ApplyHousingFilters(s, db)
            if s.RunSearch then s:RunSearch() end
        end)
    end,
    pull = function(db)
        local s = BlizzardCatalogSearcher()
        if not (s and db) then return end
        local function readState(method)
            local ok, v = pcall(s[method], s)
            if ok then return v end
        end
        local collected = readState("IsCollectedActive")
        local uncollected = readState("IsUncollectedActive")
        db.housingCollection = (collected and uncollected and "all")
            or (uncollected and "uncollected") or "collected"
        db.housingDyeableOnly = readState("IsCustomizableOnlyActive") and true or false
        db.housingCollectionBonusOnly = readState("IsFirstAcquisitionBonusOnlyActive") and true or false
        db.housingIndoors = readState("IsAllowedIndoorsActive") ~= false
        db.housingOutdoors = readState("IsAllowedOutdoorsActive") ~= false
        db.housingSortType = readState("GetSortType") or 0
        local tags = {}
        db.housingTags = tags



        ForEachHousingFilterTag(function(gid, tid)
            local grpState = tags[gid]
            if not grpState then grpState = {}; tags[gid] = grpState end
            local okS, active = pcall(s.GetFilterTagStatus, s, gid, tid)
            if okS and active then
                grpState[tid] = true
            end
        end)
        return true
    end,
}

function Database:ArmHousingPendingPushIfNeeded()
    ns.ControlSync.ArmAtLoginIfNeeded("housing")
end



function Database:WriteHousingFiltersToBlizzard()
    return ns.ControlSync.Push("housing")
end

function Database:PopulateDynamicHousingAsync(done)
    if not (C_HousingCatalog and C_HousingCatalog.CreateCatalogSearcher) then
        done(false)
        return
    end







    local hydrated = HydratePersistedHousingCache()
    if hydrated then
        done(true)
    end

    local completion = function(changed, err)
        if not hydrated then
            done(changed, err)
            return
        end


        local _, rows = Database:TakePopulatedRows("Housing")
        local function Settled() Database:UnholdPopulated("Housing") end
        if rows and ns.SearchSegments then ns.SearchSegments.Attach("housing", rows, Settled) else Settled() end
        if changed and ns.Search and ns.Search.RefreshActiveSearch then
            ns.Search:RefreshActiveSearch(true)
        end
    end

    if housingSearchDone then
        local cancelled = housingSearchDone
        housingSearchDone = nil
        cancelled(false, "cancelled")
    end
    if not housingSearcher then
        local okCreate, searcher = pcall(C_HousingCatalog.CreateCatalogSearcher)
        if not okCreate or not searcher then




            completion(false, "cancelled")
            return
        end
        housingSearcher = searcher
        pcall(function()
            if searcher.SetAutoUpdateOnParamChanges then
                searcher:SetAutoUpdateOnParamChanges(false)
            end
            searcher:SetResultsUpdatedCallback(function()
                local finish = housingSearchDone
                housingSearchDone = nil
                if finish then
                    Database:FinishHousingResults(finish)
                end
            end)
        end)
    end
    housingSearchDone = completion


    self:SyncHousingFiltersFromBlizzard()
    local okRun = pcall(function()
        local searcher = housingSearcher
        searcher:SetSearchText("")
        ApplyHousingFilters(searcher, EasyFind.db)
        if searcher.SetBaseVariantOnly then searcher:SetBaseVariantOnly(true) end
        searcher:RunSearch()
    end)
    if not okRun then
        housingSearchDone = nil
        completion(false, "cancelled")
        return
    end






    if Utils.SafeAfter then
        Utils.SafeAfter(4, function()
            if housingSearchDone == completion then
                housingSearchDone = nil
                completion(false, "cancelled")
            end
        end)
    end
end

function Database:PopulateDynamicToys()
    if not C_ToyBox then return false end

    local GetToyInfo = C_ToyBox.GetToyInfo
    local GetNumFilteredToys = C_ToyBox.GetNumFilteredToys
    local GetToyFromIndex = C_ToyBox.GetToyFromIndex
    if not GetToyInfo or not GetNumFilteredToys or not GetToyFromIndex then return false end








    local db = EasyFind and EasyFind.db or {}
    local maxExp = (GetNumExpansions and GetNumExpansions()) or 11
    local savedString = C_ToyBox.GetFilterString and C_ToyBox.GetFilterString() or ""
    local savedCollected = C_ToyBox.GetCollectedShown and C_ToyBox.GetCollectedShown()
    local savedUncollected = C_ToyBox.GetUncollectedShown and C_ToyBox.GetUncollectedShown()
    local savedUnusable = C_ToyBox.GetUnusableShown and C_ToyBox.GetUnusableShown()
    local savedSources, savedExps
    if C_ToyBox.IsSourceTypeFilterChecked then
        savedSources = {}
        for i = 1, 12 do savedSources[i] = C_ToyBox.IsSourceTypeFilterChecked(i) end
    end
    if C_ToyBox.IsExpansionTypeFilterChecked then
        savedExps = {}
        for i = 0, maxExp do savedExps[i] = C_ToyBox.IsExpansionTypeFilterChecked(i) end
    end

    local dbSources, dbExps = db.toySourceFilters, db.toyExpansionFilters
    if C_ToyBox.SetCollectedShown then C_ToyBox.SetCollectedShown(db.toyFilterCollected ~= false) end
    if C_ToyBox.SetUncollectedShown then C_ToyBox.SetUncollectedShown(db.toyFilterNotCollected == true) end
    if C_ToyBox.SetUnusableShown then C_ToyBox.SetUnusableShown(db.toyFilterUnusable ~= false) end
    if C_ToyBox.SetSourceTypeFilter then
        for i = 1, 12 do C_ToyBox.SetSourceTypeFilter(i, not (dbSources and dbSources[i] == false)) end
    end
    if C_ToyBox.SetExpansionTypeFilter then
        for i = 0, maxExp do C_ToyBox.SetExpansionTypeFilter(i, not (dbExps and dbExps[i] == false)) end
    end
    if C_ToyBox.SetFilterString then C_ToyBox.SetFilterString("") end
    if C_ToyBox.ForceToyRefilter then C_ToyBox.ForceToyRefilter() end

    local function restoreFilters()
        if savedCollected ~= nil and C_ToyBox.SetCollectedShown then C_ToyBox.SetCollectedShown(savedCollected) end
        if savedUncollected ~= nil and C_ToyBox.SetUncollectedShown then C_ToyBox.SetUncollectedShown(savedUncollected) end
        if savedUnusable ~= nil and C_ToyBox.SetUnusableShown then C_ToyBox.SetUnusableShown(savedUnusable) end
        if savedSources and C_ToyBox.SetSourceTypeFilter then
            for i = 1, 12 do C_ToyBox.SetSourceTypeFilter(i, savedSources[i]) end
        end
        if savedExps and C_ToyBox.SetExpansionTypeFilter then
            for i = 0, maxExp do C_ToyBox.SetExpansionTypeFilter(i, savedExps[i]) end
        end
        if C_ToyBox.SetFilterString then C_ToyBox.SetFilterString(savedString) end
        if C_ToyBox.ForceToyRefilter then C_ToyBox.ForceToyRefilter() end
    end

    local numToys = GetNumFilteredToys()
    if not numToys or numToys == 0 then





        local total = C_ToyBox.GetNumToys and C_ToyBox.GetNumToys() or 0
        if total == 0 then
            restoreFilters()
            return false
        end
    end

    RemoveEntriesByCategory("Toy")

    for i = 1, numToys or 0 do
        Utils.SliceCheckpoint()
        local itemID = GetToyFromIndex(i)
        if itemID and itemID > 0 then
            local _, toyName, toyIcon = GetToyInfo(itemID)
            if toyName and toyName ~= "" then




                local isUsable = true
                if C_ToyBox and C_ToyBox.IsToyUsable then
                    local ok, usable = pcall(C_ToyBox.IsToyUsable, itemID)
                    if ok and usable == false then isUsable = false end
                end
                local entry = setmetatable({
                    name = toyName,
                    icon = toyIcon,
                    toyItemID = itemID,
                    nameLower = slower(toyName),
                }, TOY_MT)
                if not isUsable then entry.isToyboxOnly = true end
                uiSearchData[#uiSearchData + 1] = entry
            end
        end
    end

    restoreFilters()
    return true
end

function Database:PopulateDynamicPets()
    if not C_PetJournal or not C_PetJournal.GetNumPets then return false end





    local db = EasyFind and EasyFind.db or {}
    local savedString = C_PetJournal.GetSearchFilter and C_PetJournal.GetSearchFilter() or ""
    local savedCollected = C_PetJournal.IsFilterChecked and C_PetJournal.IsFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED)
    local savedNotCollected = C_PetJournal.IsFilterChecked and C_PetJournal.IsFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED)
    local numSources = C_PetJournal.GetNumPetSources and C_PetJournal.GetNumPetSources() or 12
    local numTypes = C_PetJournal.GetNumPetTypes and C_PetJournal.GetNumPetTypes() or 10
    local savedSources, savedTypes
    if C_PetJournal.IsPetSourceChecked then
        savedSources = {}
        for i = 1, numSources do savedSources[i] = C_PetJournal.IsPetSourceChecked(i) end
    end
    if C_PetJournal.IsPetTypeChecked then
        savedTypes = {}
        for i = 1, numTypes do savedTypes[i] = C_PetJournal.IsPetTypeChecked(i) end
    end
    local dbSources, dbTypes = db.petSourceFilters, db.petTypeFilters

    local changedColl, changedNot, changedSearch
    local changedSources, changedTypes






    if C_PetJournal.SetFilterChecked then
        local wantColl = db.petFilterCollected ~= false
        local wantNot = db.petFilterNotCollected == true
        if savedCollected == nil or savedCollected ~= wantColl then
            C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED, wantColl); changedColl = true
        end
        if savedNotCollected == nil or savedNotCollected ~= wantNot then
            C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED, wantNot); changedNot = true
        end
    end
    if C_PetJournal.SetPetSourceChecked then
        for i = 1, numSources do
            local want = not (dbSources and dbSources[i] == false)
            if not savedSources or savedSources[i] ~= want then
                C_PetJournal.SetPetSourceChecked(i, want)
                if savedSources then changedSources = changedSources or {}; changedSources[i] = true end
                Utils.SliceCheckpoint()
            end
        end
    end
    if C_PetJournal.SetPetTypeFilter then
        for i = 1, numTypes do
            local want = not (dbTypes and dbTypes[i] == false)
            if not savedTypes or savedTypes[i] ~= want then
                C_PetJournal.SetPetTypeFilter(i, want)
                if savedTypes then changedTypes = changedTypes or {}; changedTypes[i] = true end
                Utils.SliceCheckpoint()
            end
        end
    end
    if C_PetJournal.SetSearchFilter and savedString ~= "" then
        C_PetJournal.SetSearchFilter(""); changedSearch = true
    end

    local function restoreFilters()
        if C_PetJournal.SetFilterChecked then
            if changedColl and savedCollected ~= nil then C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED, savedCollected) end
            if changedNot and savedNotCollected ~= nil then C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED, savedNotCollected) end
        end
        if savedSources and C_PetJournal.SetPetSourceChecked then
            if changedSources then
                for i in pairs(changedSources) do C_PetJournal.SetPetSourceChecked(i, savedSources[i]); Utils.SliceCheckpoint() end
            end
        elseif C_PetJournal.SetPetSourceChecked then
            for i = 1, numSources do C_PetJournal.SetPetSourceChecked(i, not (dbSources and dbSources[i] == false)) end
        end
        if savedTypes and C_PetJournal.SetPetTypeFilter then
            if changedTypes then
                for i in pairs(changedTypes) do C_PetJournal.SetPetTypeFilter(i, savedTypes[i]); Utils.SliceCheckpoint() end
            end
        elseif C_PetJournal.SetPetTypeFilter then
            for i = 1, numTypes do C_PetJournal.SetPetTypeFilter(i, not (dbTypes and dbTypes[i] == false)) end
        end
        if changedSearch and C_PetJournal.SetSearchFilter then C_PetJournal.SetSearchFilter(savedString) end
    end

    local numPets, numOwned = C_PetJournal.GetNumPets()
    if not numPets or numPets == 0 then





        if not numOwned or numOwned == 0 then
            restoreFilters()
            return false
        end
    end

    RemoveEntriesByCategory("Pet")

    local seen = {}
    for i = 1, numPets or 0 do
        Utils.SliceCheckpoint()




        local petID, speciesID, owned, _, _, _, _,
              speciesName, icon = C_PetJournal.GetPetInfoByIndex(i)
        if speciesName and speciesName ~= "" and speciesID and not seen[speciesID] then
            seen[speciesID] = true
            uiSearchData[#uiSearchData + 1] = setmetatable({
                name = speciesName,
                icon = icon,
                petID = petID,
                speciesID = speciesID,
                isCollected = owned and true or false,
                nameLower = slower(speciesName),
            }, PET_MT)
        end
    end

    restoreFilters()
    return true
end


function Database:PopulateDynamicHeirlooms()
    if not C_Heirloom then return false end

    local byIndex = C_Heirloom.GetNumDisplayedHeirlooms and C_Heirloom.GetHeirloomItemIDFromDisplayedIndex
    if not (C_Heirloom.GetHeirloomItemIDs or byIndex) then return false end



    self:SyncHeirloomJournalFilter()

    local ids
    if C_Heirloom.GetHeirloomItemIDs then
        ids = C_Heirloom.GetHeirloomItemIDs()
    else
        ids = {}
        for i = 1, C_Heirloom.GetNumDisplayedHeirlooms() or 0 do
            ids[#ids + 1] = C_Heirloom.GetHeirloomItemIDFromDisplayedIndex(i)
        end
    end
    if type(ids) ~= "table" then return false end

    local hasHeirloom = C_Heirloom.PlayerHasHeirloom
    local getInfo = C_Heirloom.GetHeirloomInfo
    if not getInfo then return false end





    local streamed = 0
    for _, itemID in ipairs(ids) do
        if getInfo(itemID) then streamed = streamed + 1 end
    end
    if streamed == 0 then return false end

    RemoveEntriesByCategory("Heirloom")

    local getItemIcon = C_Item and C_Item.GetItemIconByID
    for _, itemID in ipairs(ids) do




        local name, _, _, icon, _, source, searchFiltered = getInfo(itemID)
        if not searchFiltered then
            if (not icon or icon == 0) and getItemIcon then
                icon = getItemIcon(itemID)
            end
            if name and name ~= "" then
                local entry = setmetatable({
                    name = name,
                    nameLower = slower(name),
                    icon = icon,
                    heirloomItemID = itemID,
                    isCollected = ((not hasHeirloom) or hasHeirloom(itemID)) and true or false,
                    heirloomSourceType = source,
                }, HEIRLOOM_MT)
                if self:HeirloomPassesSearchFilters(entry) then
                    uiSearchData[#uiSearchData + 1] = entry
                end
            end
        end
    end
    return true
end

function Database:HeirloomPassesSearchFilters(data)
    if not data or not data.heirloomItemID then return false end
    local db = EasyFind and EasyFind.db
    if not db then return true end

    if data.isCollected then
        if db.heirloomFilterCollected == false then return false end
    elseif db.heirloomFilterNotCollected == false then
        return false
    end

    local sourceFilters = db.heirloomSourceFilters
    local sourceType = data.heirloomSourceType
    if sourceType and type(sourceFilters) == "table" and sourceFilters[sourceType] == false then
        return false
    end

    return true
end



function Database:PopulateDynamicTitles()
    local getNum = GetNumTitles
    local getName = GetTitleName
    local isKnown = IsTitleKnown
    if not getNum or not getName or not isKnown then return false end

    local total = getNum()
    if not total or total <= 0 then return false end






    local known = 0
    for titleID = 1, total do
        Utils.SliceCheckpoint()
        if isKnown(titleID) then known = known + 1 end
    end
    if known == 0 then return false end

    RemoveEntriesByCategory("Title")




    local mode = (EasyFind and EasyFind.db and EasyFind.db.titleFilterMode) or "earned"

    if ns.Caps and ns.Caps.achievements == false then mode = "earned" end
    local wantEarned = mode ~= "incomplete"
    local wantUnearned = mode == "incomplete" or mode == "all"
    local needSources = false


    if wantUnearned then self:EnsureTitleSourceCache() end

    for titleID = 1, total do
        Utils.SliceCheckpoint()
        local titleKnown = isKnown(titleID)
        if (titleKnown and wantEarned) or (not titleKnown and wantUnearned) then
            local raw = getName(titleID)






            local sourceAch = (not titleKnown)
                and self:GetTitleSourceAchievement(titleID) or nil
            if raw and raw ~= "" and (titleKnown or sourceAch) then
                local display = raw:gsub("%%s", ""):gsub("^%s+", ""):gsub("%s+$", "")
                if display == "" then display = raw end
                local entry = setmetatable({
                    name = display,
                    titleID = titleID,
                    nameLower = slower(display),
                }, TITLE_MT)


                if not titleKnown then entry.titleUnearned = true end
                uiSearchData[#uiSearchData + 1] = entry
                needSources = needSources or not titleKnown
            end
        end
    end


    if needSources then self:EnsureTitleSourceCache() end
    return true
end


function Database:PopulateDynamicGearSets()
    if not C_EquipmentSet or not C_EquipmentSet.GetEquipmentSetIDs then return false end

    local ids = C_EquipmentSet.GetEquipmentSetIDs()
    if type(ids) ~= "table" then return false end

    RemoveEntriesByCategory("Gear Set")

    local getInfo = C_EquipmentSet.GetEquipmentSetInfo
    if not getInfo then return false end





    local getAssignedSpec = C_EquipmentSet.GetEquipmentSetAssignedSpec



    local specFilter = EasyFind and EasyFind.db and EasyFind.db.gearSetSpecFilter
    if specFilter == "all" then specFilter = nil end
    for _, setID in ipairs(ids) do
        Utils.SliceCheckpoint()
        local name, iconFileID = getInfo(setID)
        if name and name ~= "" then
            local assignedSpec
            if getAssignedSpec then
                local ok, spec = pcall(getAssignedSpec, setID)
                if ok then assignedSpec = spec end
            end
            if not specFilter or assignedSpec == specFilter then


                local specIcon
                if assignedSpec and GetSpecializationInfo then
                    specIcon = select(4, GetSpecializationInfo(assignedSpec))
                end
                uiSearchData[#uiSearchData + 1] = setmetatable({
                    name = name,
                    icon = iconFileID,
                    gearSetID = setID,
                    gearSetSpec = assignedSpec,
                    gearSetSpecIcon = specIcon,
                    nameLower = slower(name),
                }, GEAR_SET_MT)
            end
        end
    end
    if self.ResetSearchCache then self:ResetSearchCache() end
    return true
end

function Database:PopulateDynamicOutfits()
    if not C_TransmogOutfitInfo or not C_TransmogOutfitInfo.GetOutfitsInfo then return false end

    RemoveEntriesByCategory("Outfit")
    local outfits = C_TransmogOutfitInfo.GetOutfitsInfo()
    if not outfits then return false end





    local nameCounts = {}
    for i = 1, #outfits do
        local info = outfits[i]
        if info and not info.isDisabled and info.name then
            nameCounts[info.name] = (nameCounts[info.name] or 0) + 1
        end
    end
    local nameSeen = {}

    for index, info in ipairs(outfits) do
        if not info.isDisabled then
            local displayName = info.name
            if displayName and (nameCounts[displayName] or 0) > 1 then
                nameSeen[displayName] = (nameSeen[displayName] or 0) + 1
                displayName = displayName .. " (" .. nameSeen[displayName] .. ")"
            end
            local entry = setmetatable({
                name = displayName,
                icon = info.icon,
                outfitID = info.outfitID,
                outfitIndex = index,
                nameLower = slower(displayName),
            }, OUTFIT_MT)
            uiSearchData[#uiSearchData + 1] = entry
        end
    end
    return true
end




function Database:ReplaceCategoryEntries(category, entries, scopedName)
    self.nameScopedCategories[category] = scopedName or nil
    RemoveEntriesByCategory(category)
    if not entries then return false end
    for i = 1, #entries do
        uiSearchData[#uiSearchData + 1] = entries[i]
    end
    return true
end

function Database:PopulateDynamicCommands()
    RemoveEntriesByCategory("Command")
    local entries = ns.SearchCommands and ns.SearchCommands.BuildCommandSearchData
        and ns.SearchCommands:BuildCommandSearchData()
    if not entries then return false end
    for i = 1, #entries do
        uiSearchData[#uiSearchData + 1] = entries[i]
    end
    return true
end

function Database:SyncTransmogSetFiltersFromUI()
    local db = EasyFind and EasyFind.db
    if not db then return end
    local getFilter = C_TransmogSets and (C_TransmogSets.GetBaseSetsFilter or C_TransmogSets.GetSetsFilter)
    if getFilter then

        local ok1, v1 = pcall(getFilter, 1)
        local ok2, v2 = pcall(getFilter, 2)
        local ok3, v3 = pcall(getFilter, 3)
        local ok4, v4 = pcall(getFilter, 4)
        if ok1 then db.appearanceSetCollected = v1 end
        if ok2 then db.appearanceSetNotCollected = v2 end
        if ok3 then db.appearanceSetPvE = v3 end
        if ok4 then db.appearanceSetPvP = v4 end
    end





end









Corpora.TMOG_SET_ROW_SPEC = {
    { "transmogSetID" }, { "name" }, { "labelLower" }, { "descKw" },
    { "classMask" }, { "collected" },
}




Corpora.tmogKwBuf = {}
function Corpora.TmogSetRowKeywords(row)
    Corpora.tmogKwBuf[1] = "set"
    Corpora.tmogKwBuf[2] = "transmog"
    Corpora.tmogKwBuf[3] = "tmog"
    Corpora.tmogKwBuf[4] = "xmog"
    Corpora.tmogKwBuf[5] = "appearance"
    local n = 3
    local label = row.labelLower
    if label and label ~= "" then
        n = n + 1
        Corpora.tmogKwBuf[n] = label
    end
    if row.descKw then
        n = n + 1
        Corpora.tmogKwBuf[n] = row.descKw
    end
    if n < 5 then n = 5 end
    for i = #Corpora.tmogKwBuf, n + 1, -1 do Corpora.tmogKwBuf[i] = nil end
    return Corpora.tmogKwBuf
end

Corpora.TMOG_SET_COMPUTED = {
    keywords = function(stub)
        local kws = Corpora.TmogSetRowKeywords(stub)
        local copy = {}
        for i = 1, #kws do copy[i] = kws[i] end
        return copy
    end,
    icon = function(stub)
        local C = C_TransmogSets
        local GetSetPrimaryAppearances = C and C.GetSetPrimaryAppearances
        local GetSourceIcon = C_TransmogCollection and C_TransmogCollection.GetSourceIcon
        if not (GetSetPrimaryAppearances and GetSourceIcon) then return nil end
        local ok, appearances = pcall(GetSetPrimaryAppearances, stub.transmogSetID)
        local sourceID = ok and appearances and appearances[1] and appearances[1].appearanceID
        return sourceID and GetSourceIcon(sourceID) or nil
    end,
}

Corpora.tmogSetCacheHydrated = false

function Corpora.IsTransmogLabelPvP(labelLower)
    return sfind(labelLower, "pvp") or sfind(labelLower, "season")
        or sfind(labelLower, "gladiator") or sfind(labelLower, "aspirant")
        or sfind(labelLower, "combatant")
end




function Corpora.SyncTransmogWardrobeFilters(classFilter, showCollected, showNotCollected, showPvE, showPvP)
    if C_TransmogSets.SetTransmogSetsClassFilter then
        EasyFind._tmogClassHookSuppress = true
        if not classFilter then
            local _, _, cid = UnitClass("player")
            if cid then C_TransmogSets.SetTransmogSetsClassFilter(cid) end
        elseif classFilter ~= "all" and type(classFilter) == "table" and classFilter.classID then
            C_TransmogSets.SetTransmogSetsClassFilter(classFilter.classID)
        end
        EasyFind._tmogClassHookSuppress = false
    end


    local syncFilter = C_TransmogSets.SetBaseSetsFilter or C_TransmogSets.SetSetsFilter
    if syncFilter then
        pcall(syncFilter, 1, showCollected)
        pcall(syncFilter, 2, showNotCollected)
        pcall(syncFilter, 3, showPvE)
        pcall(syncFilter, 4, showPvP)
    end

    local wcf = _G["WardrobeCollectionFrame"]
    local scf = wcf and wcf.SetsCollectionFrame
    if scf and scf:IsShown() then
        if scf.SetDataSource then pcall(scf.SetDataSource, scf) end
        if scf.UpdateUI then pcall(scf.UpdateUI, scf) end
        if scf.Refresh then pcall(scf.Refresh, scf) end
    end
    if wcf and wcf.ClassDropdown and wcf.ClassDropdown.Update then
        pcall(wcf.ClassDropdown.Update, wcf.ClassDropdown)
    end
end

function Corpora.TransmogWantMask(classFilter)
    if not classFilter then
        local _, _, cid = UnitClass("player")
        return cid and lshift(1, cid - 1) or 0
    elseif classFilter == "all" then
        return nil
    elseif type(classFilter) == "table" and classFilter.classID then
        return lshift(1, classFilter.classID - 1)
    end
    return 0
end



function Corpora.TmogRowWanted(row, wantMask, showCollected, showNotCollected, showPvE, showPvP)
    local cm = row.classMask or 0
    if wantMask and cm ~= 0 and cm >= 0 and band(cm, wantMask) == 0 then return false end
    local isPvP = Corpora.IsTransmogLabelPvP(row.labelLower or "")
    if not ((isPvP and showPvP) or (not isPvP and showPvE)) then return false end
    if not (showCollected and showNotCollected) then
        if row.collected and not showCollected then return false end
        if not row.collected and not showNotCollected then return false end
    end
    return true
end

function Corpora.InsertTransmogSetStubs(packed, wantMask, showCollected, showNotCollected, showPvE, showPvP)
    local corpus = Utils.GetCorpus("transmogSets")
    if not (corpus and corpus.packed == packed) then
        corpus = Utils.NewPackedCorpus(packed, Corpora.TMOG_SET_ROW_SPEC, TRANSMOG_SET_PROTO,
            { computed = Corpora.TMOG_SET_COMPUTED, keywordsFor = Corpora.TmogSetRowKeywords,
              keywordFields = { labelLower = true, descKw = true }, sliced = true })
        Utils.RegisterCorpus("transmogSets", corpus)
    end
    local inserted = 0
    corpus:EachRow(function(ri, row)
        if row.transmogSetID and row.name
           and Corpora.TmogRowWanted(row, wantMask, showCollected, showNotCollected, showPvE, showPvP) then
            uiSearchData[#uiSearchData + 1] = corpus:StubAt(ri)
            inserted = inserted + 1
        end
    end, nil, true)
    return inserted
end

function Database:PopulateDynamicTransmogSets()
    if not C_TransmogSets or not C_TransmogSets.GetAllSets then return false end

    RemoveEntriesWithField("transmogSetID")


    if self.ResetSearchCache then self:ResetSearchCache() end

    local db = EasyFind and EasyFind.db
    if not db then return false end
    local classFilter = db.appearanceSetClass
    local showCollected = not db or db.appearanceSetCollected ~= false
    local showNotCollected = not db or db.appearanceSetNotCollected ~= false
    local showPvE = not db or db.appearanceSetPvE ~= false
    local showPvP = not db or db.appearanceSetPvP ~= false

    Corpora.SyncTransmogWardrobeFilters(classFilter, showCollected, showNotCollected, showPvE, showPvP)

    local wantMask = Corpora.TransmogWantMask(classFilter)



    if not Corpora.tmogSetCacheHydrated then
        Corpora.tmogSetCacheHydrated = true
        local saved = db.transmogSetCache
        if type(saved) == "table" and db.transmogSetCacheVer == ns.TMOG_SET_CACHE_VER
           and type(saved.packed) == "string" and saved.packed ~= "" then
            if Corpora.InsertTransmogSetStubs(saved.packed, wantMask,
                showCollected, showNotCollected, showPvE, showPvP) > 0 then
                return true
            end
        end
    end

    local allSets = Database.AllTransmogSets()
    if not allSets then return false end

    local rows = {}
    for i = 1, #allSets do
        local setInfo = allSets[i]


        local isBaseSet = true
        if C_TransmogSets.GetBaseSetID then
            local bid = C_TransmogSets.GetBaseSetID(setInfo.setID)
            isBaseSet = not bid or bid == setInfo.setID
        end
        if isBaseSet and setInfo.name and setInfo.name ~= "" and not setInfo.hiddenUntilCollected then
            local labelLower = slower(setInfo.label or "")
            local descKw
            if setInfo.description and setInfo.description ~= "" then
                local descLower = slower(setInfo.description)
                if descLower ~= slower(setInfo.name) then descKw = descLower end
            end
            rows[#rows + 1] = {
                transmogSetID = setInfo.setID,
                name          = setInfo.name,
                labelLower    = labelLower,
                descKw        = descKw,
                classMask     = setInfo.classMask or 0,
                collected     = setInfo.collected and true or false,
            }
        end
    end

    local packed = Utils.PackRows(rows, Corpora.TMOG_SET_ROW_SPEC)
    db.transmogSetCache = { version = ns.TMOG_SET_CACHE_VER, packed = packed }
    db.transmogSetCacheVer = ns.TMOG_SET_CACHE_VER
    Corpora.InsertTransmogSetStubs(packed, wantMask, showCollected, showNotCollected, showPvE, showPvP)
    return true
end




local tmogWalkGen = 0

function Database:PopulateDynamicTransmogSetsAsync(done)
    if not C_TransmogSets or not C_TransmogSets.GetAllSets then
        done(false)
        return
    end

    RemoveEntriesWithField("transmogSetID")
    if self.ResetSearchCache then self:ResetSearchCache() end

    local db = EasyFind and EasyFind.db
    if not db then
        done(false)
        return
    end
    local classFilter = db.appearanceSetClass
    local showCollected = not db or db.appearanceSetCollected ~= false
    local showNotCollected = not db or db.appearanceSetNotCollected ~= false
    local showPvE = not db or db.appearanceSetPvE ~= false
    local showPvP = not db or db.appearanceSetPvP ~= false

    Corpora.SyncTransmogWardrobeFilters(classFilter, showCollected, showNotCollected, showPvE, showPvP)

    local wantMask = Corpora.TransmogWantMask(classFilter)

    if not Corpora.tmogSetCacheHydrated then
        Corpora.tmogSetCacheHydrated = true
        local saved = db.transmogSetCache
        if type(saved) == "table" and db.transmogSetCacheVer == ns.TMOG_SET_CACHE_VER
           and type(saved.packed) == "string" and saved.packed ~= "" then
            if Corpora.InsertTransmogSetStubs(saved.packed, wantMask,
                showCollected, showNotCollected, showPvE, showPvP) > 0 then
                done(true)
                return
            end
        end
    end

    local allSets = Database.AllTransmogSets()
    if not allSets then
        done(false)
        return
    end

    tmogWalkGen = tmogWalkGen + 1
    local myGen = tmogWalkGen
    local rows = {}
    local i = 1
    local total = #allSets
    local budgetMs = 4
    local dps = debugprofilestop
    local function slice()
        if myGen ~= tmogWalkGen then
            done(false, "cancelled")
            return
        end
        local start = dps and dps() or 0
        local processed = 0
        while i <= total do
            local setInfo = allSets[i]
            i = i + 1
            local isBaseSet = true
            if C_TransmogSets.GetBaseSetID then
                local bid = C_TransmogSets.GetBaseSetID(setInfo.setID)
                isBaseSet = not bid or bid == setInfo.setID
            end
            if isBaseSet and setInfo.name and setInfo.name ~= "" and not setInfo.hiddenUntilCollected then
                local labelLower = slower(setInfo.label or "")
                local descKw
                if setInfo.description and setInfo.description ~= "" then
                    local descLower = slower(setInfo.description)
                    if descLower ~= slower(setInfo.name) then descKw = descLower end
                end
                rows[#rows + 1] = {
                    transmogSetID = setInfo.setID,
                    name          = setInfo.name,
                    labelLower    = labelLower,
                    descKw        = descKw,
                    classMask     = setInfo.classMask or 0,
                    collected     = setInfo.collected and true or false,
                }
            end
            processed = processed + 1
            if (dps and (dps() - start) >= budgetMs) or (not dps and processed >= 80) then
                Utils.SafeAfter(0, slice)
                return
            end
        end
        local packed = Utils.PackRows(rows, Corpora.TMOG_SET_ROW_SPEC)
        db.transmogSetCache = { version = ns.TMOG_SET_CACHE_VER, packed = packed }
        db.transmogSetCacheVer = ns.TMOG_SET_CACHE_VER
        Corpora.InsertTransmogSetStubs(packed, wantMask, showCollected, showNotCollected, showPvE, showPvP)
        done(true)
    end
    slice()
end





function Database:PopulateDynamicAppearanceItems()
    local C = C_TransmogCollection
    if not C or not C.GetCategoryAppearances then return false end

    RemoveEntriesWithField("appearanceItemID")
    if self.ResetSearchCache then self:ResetSearchCache() end

    local db = EasyFind and EasyFind.db
    if not db then return false end

    local showCollected = db.appearanceItemCollected ~= false
    local showNotCollected = db.appearanceItemNotCollected == true
    if not showCollected and not showNotCollected then return true end

    local classFilter = db.appearanceItemClass
    local sourceFilters = db.appearanceItemSourceFilters




    if type(sourceFilters) == "table" then
        local anyEnabled = false
        for st = 1, 12 do
            if _G["TRANSMOG_SOURCE_" .. st] and sourceFilters[st] ~= false then
                anyEnabled = true
                break
            end
        end
        if not anyEnabled then
            db.appearanceItemSourceFilters = nil
            sourceFilters = nil
        end
    end







    if C.SetClassFilter and C.GetClassFilter then
        local _, _, playerClassID = UnitClass("player")
        local targetClass = playerClassID
        if classFilter == "all" then
            targetClass = 0
        elseif type(classFilter) == "table" and classFilter.classID then
            targetClass = classFilter.classID
        end
        local okCur, currentClass = pcall(C.GetClassFilter)
        if targetClass and okCur and currentClass ~= targetClass then
            EasyFind._appItemClassHookSuppress = true
            pcall(C.SetClassFilter, targetClass)
            EasyFind._appItemClassHookSuppress = false




            local wcf = _G["WardrobeCollectionFrame"]
            if wcf then
                if wcf.ClassDropdown and wcf.ClassDropdown.Update then
                    pcall(wcf.ClassDropdown.Update, wcf.ClassDropdown)
                end
                local icf = wcf.ItemsCollectionFrame
                if icf and icf.RefreshVisualsList and icf.IsShown and icf:IsShown() then
                    pcall(icf.RefreshVisualsList, icf)
                end
            end


            EasyFind._appItemClassDeferred = true
            local database = self
            if Utils and Utils.SafeAfter then
                Utils.SafeAfter(0.7, function()
                    if EasyFind._appItemClassDeferred and database.RefreshDynamicCategory then
                        database:RefreshDynamicCategory("appearanceItems")
                    end
                end)
            end
            return true
        end
    end
    EasyFind._appItemClassDeferred = nil



    local slot = db.appearanceItemSlot
    if type(slot) ~= "number" then
        slot = (Enum.TransmogCollectionType and Enum.TransmogCollectionType.Head) or 1
    end
    local slotCats = { slot }





    local probe = Database.CategoryAppearances(slotCats[1])
    if (not probe or #probe == 0) and C_AddOns and C_AddOns.LoadAddOn
       and not C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_Collections")
        probe = Database.CategoryAppearances(slotCats[1])
    end
    if not probe or #probe == 0 then return false end


    if ns.Filters and ns.Filters.EnsureWardrobeItemSlotHooks then
        ns.Filters:EnsureWardrobeItemSlotHooks()
    end

    local GetSourceInfo = C.GetSourceInfo
    local GetSourceIcon = C.GetSourceIcon
    local getCatInfo = C.GetCategoryInfo

    for ci = 1, #slotCats do
        local catID = slotCats[ci]
        local appearances = Database.CategoryAppearances(catID)
        if appearances and #appearances > 0 then
            local slotName
            if getCatInfo then
                local okN, n = pcall(getCatInfo, catID)
                if okN and type(n) == "string" and n ~= "" then slotName = n end
            end
            local kw = { "appearance", "transmog", "tmog", "xmog" }
            if slotName then kw[#kw + 1] = slower(slotName) end

            for i = 1, #appearances do
                local app = appearances[i]


                local appOk = (app.isCollected and showCollected)
                    or (not app.isCollected and showNotCollected)
                if appOk and app.visualID then
                    local sources = Database.AppearanceSources(app.visualID, catID)
                    if sources then




                        for s = 1, #sources do
                            local src = sources[s]
                            local collectedOk = (src.isCollected and showCollected)
                                or (not src.isCollected and showNotCollected)
                            local st = src.sourceType
                            local srcOk = not sourceFilters or not st or sourceFilters[st] ~= false
                            if collectedOk and srcOk then
                                local name
                                if GetSourceInfo and src.sourceID then
                                    local info = GetSourceInfo(src.sourceID)
                                    if info and info.name and info.name ~= "" then name = info.name end
                                end
                                if not name and src.itemID and GetItemInfo then
                                    name = GetItemInfo(src.itemID)
                                end
                                if name and name ~= "" then
                                    local icon = GetSourceIcon and src.sourceID and GetSourceIcon(src.sourceID)
                                    uiSearchData[#uiSearchData + 1] = setmetatable({
                                        name = name,
                                        nameLower = slower(name),
                                        appearanceItemID = src.sourceID,
                                        appearanceVisualID = app.visualID,
                                        appearanceSlot = catID,
                                        appearanceSlotName = slotName,
                                        icon = icon,
                                        keywords = kw,
                                    }, APPEARANCE_ITEM_MT)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return true
end

function Database:PopulateDynamicAppearanceItemsAsync(done)
    done = done or function() end
    if not Utils.SafeAfter then
        local ready = self:PopulateDynamicAppearanceItems()
        done(ready ~= false, ready == false and "cancelled" or nil)
        return
    end

    local C = C_TransmogCollection
    if not C or not C.GetCategoryAppearances then done(false, "cancelled"); return end

    RemoveEntriesWithField("appearanceItemID")
    if self.ResetSearchCache then self:ResetSearchCache() end

    local db = EasyFind and EasyFind.db
    if not db then done(false, "cancelled"); return end

    local showCollected = db.appearanceItemCollected ~= false
    local showNotCollected = db.appearanceItemNotCollected == true
    if not showCollected and not showNotCollected then done(true); return end

    local classFilter = db.appearanceItemClass
    local sourceFilters = db.appearanceItemSourceFilters

    if type(sourceFilters) == "table" then
        local anyEnabled = false
        for st = 1, 12 do
            if _G["TRANSMOG_SOURCE_" .. st] and sourceFilters[st] ~= false then
                anyEnabled = true
                break
            end
        end
        if not anyEnabled then
            db.appearanceItemSourceFilters = nil
            sourceFilters = nil
        end
    end

    if C.SetClassFilter and C.GetClassFilter then
        local _, _, playerClassID = UnitClass("player")
        local targetClass = playerClassID
        if classFilter == "all" then
            targetClass = 0
        elseif type(classFilter) == "table" and classFilter.classID then
            targetClass = classFilter.classID
        end
        local okCur, currentClass = pcall(C.GetClassFilter)
        if targetClass and okCur and currentClass ~= targetClass then
            EasyFind._appItemClassHookSuppress = true
            pcall(C.SetClassFilter, targetClass)
            EasyFind._appItemClassHookSuppress = false
            local wcf = _G["WardrobeCollectionFrame"]
            if wcf then
                if wcf.ClassDropdown and wcf.ClassDropdown.Update then
                    pcall(wcf.ClassDropdown.Update, wcf.ClassDropdown)
                end
                local icf = wcf.ItemsCollectionFrame
                if icf and icf.RefreshVisualsList and icf.IsShown and icf:IsShown() then
                    pcall(icf.RefreshVisualsList, icf)
                end
            end
            EasyFind._appItemClassDeferred = true
            local database = self
            Utils.SafeAfter(0.7, function()
                if EasyFind._appItemClassDeferred and database.RefreshDynamicCategory then
                    database:RefreshDynamicCategory("appearanceItems")
                end
            end)
            done(true)
            return
        end
    end
    EasyFind._appItemClassDeferred = nil

    local slot = db.appearanceItemSlot
    if type(slot) ~= "number" then
        slot = (Enum.TransmogCollectionType and Enum.TransmogCollectionType.Head) or 1
    end

    local probe = Database.CategoryAppearances(slot)
    if (not probe or #probe == 0) and C_AddOns and C_AddOns.LoadAddOn
       and not C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_Collections")
        probe = Database.CategoryAppearances(slot)
    end
    if not probe or #probe == 0 then done(false, "cancelled"); return end

    if ns.Filters and ns.Filters.EnsureWardrobeItemSlotHooks then
        ns.Filters:EnsureWardrobeItemSlotHooks()
    end

    local GetSourceInfo = C.GetSourceInfo
    local GetSourceIcon = C.GetSourceIcon
    local getCatInfo = C.GetCategoryInfo
    if not C.GetAppearanceSources then done(false, "cancelled"); return end

    local appearances = Database.CategoryAppearances(slot)
    if not appearances or #appearances == 0 then done(false, "cancelled"); return end

    local slotName
    if getCatInfo then
        local okN, n = pcall(getCatInfo, slot)
        if okN and type(n) == "string" and n ~= "" then slotName = n end
    end
    local kw = { "appearance", "transmog", "tmog", "xmog" }
    if slotName then kw[#kw + 1] = slower(slotName) end

    local appIndex = 1
    local sources
    local sourceIndex = 1
    local app
    local budgetMs = 3

    local function scheduleStep(step)
        Utils.SafeAfter(0, function()
            local ok, err = xpcall(step, Utils.ErrorHandler)
            if not ok then done(false, err) end
        end)
    end

    local function step()
        local start = debugprofilestop and debugprofilestop() or 0
        while appIndex <= #appearances do
            if not sources then
                app = appearances[appIndex]
                local appOk = app and ((app.isCollected and showCollected)
                    or (not app.isCollected and showNotCollected))
                sources = appOk and app.visualID and Database.AppearanceSources(app.visualID, slot) or false
                sourceIndex = 1
            end

            if sources and sources ~= false then
                while sourceIndex <= #sources do
                    local src = sources[sourceIndex]
                    sourceIndex = sourceIndex + 1
                    local collectedOk = src and ((src.isCollected and showCollected)
                        or (not src.isCollected and showNotCollected))
                    local st = src and src.sourceType
                    local srcOk = not sourceFilters or not st or sourceFilters[st] ~= false
                    if collectedOk and srcOk then
                        local name
                        if GetSourceInfo and src.sourceID then
                            local info = GetSourceInfo(src.sourceID)
                            if info and info.name and info.name ~= "" then name = info.name end
                        end
                        if not name and src.itemID and GetItemInfo then
                            name = GetItemInfo(src.itemID)
                        end
                        if name and name ~= "" then
                            local icon = GetSourceIcon and src.sourceID and GetSourceIcon(src.sourceID)
                            uiSearchData[#uiSearchData + 1] = setmetatable({
                                name = name,
                                nameLower = slower(name),
                                appearanceItemID = src.sourceID,
                                appearanceVisualID = app.visualID,
                                appearanceSlot = slot,
                                appearanceSlotName = slotName,
                                icon = icon,
                                keywords = kw,
                            }, APPEARANCE_ITEM_MT)
                        end
                    end
                    if debugprofilestop and (debugprofilestop() - start) >= budgetMs then
                        scheduleStep(step)
                        return
                    end
                end
            end

            appIndex = appIndex + 1
            sources = nil
            app = nil
            if debugprofilestop and (debugprofilestop() - start) >= budgetMs then
                scheduleStep(step)
                return
            end
        end
        done(true)
    end

    scheduleStep(step)
end

local function AppendClassSpecPairs(specPairs, classID)
    for _, specID in ipairs(ClassSpecIDs(classID)) do
        specPairs[#specPairs + 1] = { classID = classID, specID = specID }
    end
end

local function AppendAllClassSpecPairs(specPairs)
    for classIdx = 1, GetNumClasses() do
        local _, _, classID = GetClassInfo(classIdx)
        if classID then
            AppendClassSpecPairs(specPairs, classID)
        end
    end
end

local function BuildLootSpecPairs(scanAllSpecs)
    local specPairs = {}
    if scanAllSpecs then
        AppendAllClassSpecPairs(specPairs)
    else
        local lootFilter = EasyFind.db.lootFilter
        if not lootFilter then
            local _, _, cid = UnitClass("player")
            local si = GetSpecialization and GetSpecialization()
            local sid = si and GetSpecializationInfo and GetSpecializationInfo(si)
            if cid and sid then
                specPairs[1] = { classID = cid, specID = sid }
            elseif cid then


                AppendClassSpecPairs(specPairs, cid)
            end
        elseif lootFilter == "all" then
            AppendAllClassSpecPairs(specPairs)
        elseif lootFilter.specID then
            specPairs[1] = { classID = lootFilter.classID, specID = lootFilter.specID }
        elseif lootFilter.classID then
            AppendClassSpecPairs(specPairs, lootFilter.classID)
        end
    end
    return specPairs
end

local function GetLootSpecsToScan(specPairs)
    local needScan = {}
    for _, sp in ipairs(specPairs) do
        local key = sp.classID .. "-" .. sp.specID
        if not lootSpecsScanned[key] then
            needScan[#needScan + 1] = sp
        end
    end
    return needScan
end

local function GetLootDiffPairs(isRaid)
    local diffPairs = {}
    local st = isRaid and "raid" or "dungeon"
    for diffKey, ids in pairs(LOOT_DIFF_IDS) do
        if ids[st] then
            diffPairs[#diffPairs + 1] = { key = diffKey, id = ids[st] }
        end
    end
    return diffPairs
end

function Database:HydrateCachedLoot()
    if lootSearchDataHydrated then return false end
    HydratePersistedLootCache()
    if not Corpora.HasLootCache() then return false end

    local specPairs = BuildLootSpecPairs(false)
    if #specPairs == 0 then return false end

    local needScan = GetLootSpecsToScan(specPairs)
    RebuildLootSearchData()
    if #needScan == 0 and self.MarkDynamicProviderLoaded then
        self:MarkDynamicProviderLoaded("loot")
    end
    return true
end

local function CacheLootInfo(database, lootInfo, inst, encName, encID, diff, sp, spKey, GetItemInfoInstantFn)
    local itemID = lootInfo.itemID
    if not itemID then return end
    local cached = lootItemCache[itemID]
    if cached then
        local changed = false
        local foundSp = false
        for _, sk in ipairs(cached._cachedSpecs) do
            if sk == spKey then foundSp = true; break end
        end
        if not foundSp then
            cached._cachedSpecs[#cached._cachedSpecs + 1] = spKey
            changed = true
        end

        local foundDf = false
        for _, dk in ipairs(cached._cachedDiffs) do
            if dk == diff.key then foundDf = true; break end
        end
        if not foundDf then
            cached._cachedDiffs[#cached._cachedDiffs + 1] = diff.key
            if lootInfo.link and cached.lootItemLinks then
                cached.lootItemLinks[diff.key] = lootInfo.link
            end
            changed = true
        end
        return changed
    end

    local itemName = lootInfo.name
    if not itemName or itemName == "" then return end
    local _, _, subTypeName, equipLoc, instIcon, classID, subclassID = GetItemInfoInstantFn(itemID)
    if not (equipLoc and SLOT_KEYWORDS[equipLoc]) and lootInfo.filterType then
        equipLoc = FILTER_TO_INVTYPE[lootInfo.filterType] or equipLoc
    end
    local slotKws = {}
    local slotKwVals = equipLoc and SLOT_KEYWORDS[equipLoc]
    if slotKwVals then
        for _, w in ipairs(slotKwVals) do slotKws[#slotKws + 1] = w end
    end
    if classID == 2 then
        local weaponWords = Database.WEAPON_KEYWORDS[subclassID]
        if weaponWords then
            for _, w in ipairs(weaponWords) do slotKws[#slotKws + 1] = w end
        end
        if type(subTypeName) == "string" and GetLocale() ~= "enUS" then
            for w in slower(subTypeName):gmatch("[^%s%-]+") do slotKws[#slotKws + 1] = w end
        end
    end

    local sourceKws = {}
    if encName then
        for w in encName:lower():gmatch("%a+") do sourceKws[#sourceKws + 1] = w end
    end
    if inst.name then
        for w in inst.name:lower():gmatch("%a+") do sourceKws[#sourceKws + 1] = w end
        local abbrs = Database.InstanceAbbrs(slower(inst.name))
        if abbrs then
            for i = 1, #abbrs do sourceKws[#sourceKws + 1] = abbrs[i] end
        end
    end
    local wings = encName and Database.BOSS_WING_WORDS[slower(encName)]
    if wings then
        for i = 1, #wings do sourceKws[#sourceKws + 1] = wings[i] end
    end

    local itemLinks = {}
    if lootInfo.link then itemLinks[diff.key] = lootInfo.link end
    local entry = setmetatable({
        name = itemName,
        nameLower = slower(itemName),
        icon = lootInfo.icon or instIcon,
        itemID = itemID,
        keywords = EMPTY_KEYWORDS,
        lootSlotKw = slotKws,
        lootSourceKw = sourceKws,
        lootStatKw = {},
        lootItemLinks = itemLinks,
        lootSlotName = equipLoc and SLOT_DISPLAY[equipLoc],
        _cachedSpecs = { spKey },
        _cachedDiffs = { diff.key },
    }, GetLootEncounterMT(encID, inst.id, encName, inst.name, inst.isRaid))

    if lootInfo.link then
        database:EnrichLootStats(entry)
    end
    lootItemCache[itemID] = entry
    return true
end

function Database:CancelDynamicScans(includeBosses)
    lootScanGeneration = lootScanGeneration + 1
    if includeBosses then
        bossScanGeneration = bossScanGeneration + 1
    end
end



function Corpora.StaticInstances()
    local insts = {}
    for _, e in ipairs(ns.FOREVER_INSTANCES or {}) do insts[e.id] = insts[e.id] or e end
    return insts
end

function Corpora.StaticInstanceName(inst, e)
    local zone = GetRealZoneText and GetRealZoneText(inst)
    return (zone and zone ~= "") and zone or (e and e.n)
end

function Corpora.StaticBossName(boss)
    local names = ns.STATIC_LOOT_BOSS_NAMES
    return names and names[boss.enc] or boss.boss
end


Corpora.STATIC_DIFF = { any = { key = "*" }, normal = { key = "normal" }, heroic = { key = "heroic" } }
local function PopulateStaticLoot(database)
    local names = ns.STATIC_LOOT_NAMES or {}
    local insts = Corpora.StaticInstances()
    local GetName = C_Item and C_Item.GetItemNameByID
    for _, boss in ipairs(ns.STATIC_LOOT) do
        Utils.SliceCheckpoint()
        local e = insts[boss.inst]
        local inst = { id = boss.inst, name = Corpora.StaticInstanceName(boss.inst, e), isRaid = e and e.raid or false }
        local bossName = Corpora.StaticBossName(boss)
        local diffs = Corpora.STATIC_DIFF
        for _, list in ipairs({ { boss.items, boss.heroic and diffs.normal or diffs.any }, { boss.heroic or {}, diffs.heroic } }) do
            for _, itemID in ipairs(list[1]) do
                local name = (GetName and GetName(itemID)) or names[itemID]
                CacheLootInfo(database, { itemID = itemID, name = name }, inst, bossName, boss.enc, list[2], nil, "*",
                    GetItemInfoInstant)
            end
        end
    end
    RebuildLootSearchData()
end

function Database:PopulateDynamicLoot(scanAllSpecs)
    if InCombatLockdown() then return false end
    if ns.STATIC_LOOT and not (ns.Caps and ns.Caps.journal) then
        PopulateStaticLoot(self)
        return
    end
    HydratePersistedLootCache()

    local specPairs = BuildLootSpecPairs(scanAllSpecs)
    if #specPairs == 0 then return false end

    local needScan = GetLootSpecsToScan(specPairs)

    if #needScan == 0 then
        RebuildLootSearchData()
        return
    end


    if not EncounterJournal then
        if not (ns.Caps and ns.Caps.journal) then return end
        EncounterJournal_LoadUI()
    end

    local EJ_GetCurrentTier     = EJ("GetCurrentTier")
    local EJ_SelectTier         = EJ("SelectTier")
    local EJ_GetInstanceByIndex = EJ("GetInstanceByIndex")
    local EJ_SelectInstance     = EJ("SelectInstance")
    local EJ_GetEncounterInfoByIndex = EJ("GetEncounterInfoByIndex")
    local EJ_SelectEncounter    = EJ("SelectEncounter")
    local EJ_SetDifficulty      = EJ("SetDifficulty")
    local EJ_SetLootFilter      = EJ("SetLootFilter")
    local EJ_SetSlotFilter      = EJ("SetSlotFilter")
    local EJ_GetLootInfoByIndex = EJ("GetLootInfoByIndex")
    local EJ_GetNumLoot         = EJ("GetNumLoot")

    if not EJ_GetCurrentTier or not EJ_GetInstanceByIndex or not EJ_GetLootInfoByIndex then
        Utils.DebugPrint("Loot scan aborted: EJ APIs not available")
        return false
    end


    lootScanGeneration = lootScanGeneration + 1
    local myGen = lootScanGeneration


    local ejFrame = _G["EncounterJournal"]
    local savedOnEvent
    if ejFrame then
        savedOnEvent = ejFrame:GetScript("OnEvent")
        ejFrame:SetScript("OnEvent", nil)
    end

    local savedTier = EJ_GetCurrentTier and EJ_GetCurrentTier()

    local instances = {}
    local function collectInstances(isRaid)
        local idx = 1
        while true do
            local instID, instName = EJ_GetInstanceByIndex(idx, isRaid)
            if not instID then break end
            instances[#instances + 1] = { id = instID, name = instName, isRaid = isRaid }
            idx = idx + 1
        end
    end
    collectInstances(false)
    collectInstances(true)

    for _, inst in ipairs(instances) do
        if myGen ~= lootScanGeneration then break end
        EJ_SelectInstance(inst.id)
        local diffPairs = GetLootDiffPairs(inst.isRaid)

        local encIdx = 1
        while true do
            local encName, _, encID = EJ_GetEncounterInfoByIndex(encIdx)
            if not encName then break end

            for _, diff in ipairs(diffPairs) do
                for _, sp in ipairs(needScan) do
                    local spKey = sp.classID .. "-" .. sp.specID
                    EJ_SelectInstance(inst.id)
                    EJ_SelectEncounter(encID)
                    if EJ_SetDifficulty then
                        EJ_SetDifficulty(diff.id)
                    end
                    if EJ_SetSlotFilter then
                        EJ_SetSlotFilter(Enum.ItemSlotFilterType.NoFilter)
                    end
                    if EJ_SetLootFilter then
                        EasyFind._lootFilterHookSuppress = true
                        EJ_SetLootFilter(sp.classID, sp.specID)
                        EasyFind._lootFilterHookSuppress = false
                    end




                    local numLoot = EJ_GetNumLoot and EJ_GetNumLoot() or 0
                    for li = 1, numLoot do
                        local lootInfo = EJ_GetLootInfoByIndex(li)
                        if lootInfo and lootInfo.name then
                            CacheLootInfo(Database, lootInfo, inst, encName, encID, diff, sp, spKey, GetItemInfoInstant)
                        end
                    end
                end
            end
            encIdx = encIdx + 1
        end
    end

    if savedTier and EJ_SelectTier then EJ_SelectTier(savedTier) end
    if ejFrame and savedOnEvent then ejFrame:SetScript("OnEvent", savedOnEvent) end




    PersistLootCache()
    RebuildLootSearchData()


    Database:SyncEJLootFilter()
    Utils.SafeAfter(0, function()
        Utils.GCStep(1)
    end)
end

function Database:PopulateDynamicLootAsync(done, scanAllSpecs)
    if InCombatLockdown() then done(false, "cancelled"); return end
    if ns.STATIC_LOOT and not (ns.Caps and ns.Caps.journal) then
        PopulateStaticLoot(self)
        done(true)
        return
    end
    HydratePersistedLootCache()
    if not Utils.SafeAfter then
        local ready = self:PopulateDynamicLoot(scanAllSpecs)
        done(ready ~= false, ready == false and "cancelled" or nil)
        return
    end

    local specPairs = BuildLootSpecPairs(scanAllSpecs)
    if #specPairs == 0 then
        done(false, "cancelled")
        return
    end

    local needScan = GetLootSpecsToScan(specPairs)
    if #needScan == 0 then
        RebuildLootSearchData()
        done(true)
        return
    end

    if not EncounterJournal then
        if not (ns.Caps and ns.Caps.journal) then return end
        EncounterJournal_LoadUI()
    end

    local EJ_GetCurrentTier     = EJ("GetCurrentTier")
    local EJ_SelectTier         = EJ("SelectTier")
    local EJ_GetInstanceByIndex = EJ("GetInstanceByIndex")
    local EJ_SelectInstance     = EJ("SelectInstance")
    local EJ_GetEncounterInfoByIndex = EJ("GetEncounterInfoByIndex")
    local EJ_SelectEncounter    = EJ("SelectEncounter")
    local EJ_SetDifficulty      = EJ("SetDifficulty")
    local EJ_SetLootFilter      = EJ("SetLootFilter")
    local EJ_SetSlotFilter      = EJ("SetSlotFilter")
    local EJ_GetLootInfoByIndex = EJ("GetLootInfoByIndex")




    local EJ_GetNumLoot         = EJ("GetNumLoot")
    local EJ_IsLootListOutOfDate = EJ("IsLootListOutOfDate")

    if not EJ_GetCurrentTier or not EJ_GetInstanceByIndex or not EJ_GetLootInfoByIndex
       or not EJ_GetNumLoot then
        done(false, "cancelled")
        return
    end

    lootScanGeneration = lootScanGeneration + 1
    local myGen = lootScanGeneration
    local ejFrame = _G["EncounterJournal"]
    local savedOnEvent
    if ejFrame then
        savedOnEvent = ejFrame:GetScript("OnEvent")
        ejFrame:SetScript("OnEvent", nil)
    end
    local savedTier = EJ_GetCurrentTier and EJ_GetCurrentTier()

    local instances = {}
    local function collectInstances(isRaid)
        local idx = 1
        while true do
            local instID, instName = EJ_GetInstanceByIndex(idx, isRaid)
            if not instID then break end
            instances[#instances + 1] = { id = instID, name = instName, isRaid = isRaid }
            idx = idx + 1
        end
    end
    collectInstances(false)
    collectInstances(true)

    local state = {
        instIdx = 1,
        encIdx = 1,
        diffIdx = 1,
        specIdx = 1,
        lootIdx = 1,
        diffPairs = nil,
        encName = nil,
        encID = nil,
        prepared = false,
        waiting = false,
        waitDeadline = nil,
        lootDataDirty = false,
    }
    local GetItemInfoInstantFn = GetItemInfoInstant
    local budgetMs = 4
    local partialLootChanged = false


    local sweepCachedAny = false




    local scanIncomplete = false

    if not lootEventFrame then
        lootEventFrame = CreateFrame("Frame")
        lootEventFrame:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
        lootEventFrame:SetScript("OnEvent", function()
            if activeLootScan then activeLootScan.lootDataDirty = true end
        end)
    end
    activeLootScan = state

    local function finish(changed, err)
        if activeLootScan == state then activeLootScan = nil end
        if savedTier and EJ_SelectTier then EJ_SelectTier(savedTier) end
        if ejFrame and savedOnEvent then ejFrame:SetScript("OnEvent", savedOnEvent) end
        if changed and scanIncomplete and not sweepCachedAny
           and not Corpora.HasLootCache() then






            Database:SyncEJLootFilter()
            done(false, "cancelled")
            return
        end
        if changed then
            if not scanIncomplete then
                for _, sp in ipairs(needScan) do
                    lootSpecsScanned[sp.classID .. "-" .. sp.specID] = true
                end
            end
            PersistLootCache()
            RebuildLootSearchData()
            Database:SyncEJLootFilter()
            Utils.GCStep(1)
        end
        done(changed, err)
    end

    local function step()
        if myGen ~= lootScanGeneration then
            finish(false, "cancelled")
            return
        end

        local start = debugprofilestop and debugprofilestop() or 0
        while true do
            local inst = instances[state.instIdx]
            if not inst then
                finish(true)
                return
            end

            if not state.diffPairs then
                EJ_SelectInstance(inst.id)
                state.diffPairs = GetLootDiffPairs(inst.isRaid)
                state.encIdx = 1
                state.diffIdx = 1
                state.specIdx = 1
                state.lootIdx = 1
                state.prepared = false
            end

            if not state.encName then
                local encName, _, encID = EJ_GetEncounterInfoByIndex(state.encIdx)
                if not encName then
                    state.instIdx = state.instIdx + 1
                    state.diffPairs = nil
                    state.encName = nil
                    state.encID = nil
                    state.prepared = false
                else
                    state.encName = encName
                    state.encID = encID
                end
            elseif not state.diffPairs[state.diffIdx] then
                state.encIdx = state.encIdx + 1
                state.diffIdx = 1
                state.specIdx = 1
                state.lootIdx = 1
                state.encName = nil
                state.encID = nil
                state.prepared = false
            elseif not needScan[state.specIdx] then
                state.diffIdx = state.diffIdx + 1
                state.specIdx = 1
                state.lootIdx = 1
                state.prepared = false
            elseif state.waiting then



                if state.lootDataDirty then


                    state.lootDataDirty = false
                    state.waiting = false
                    state.prepared = false
                elseif GetTime() > state.waitDeadline then



                    scanIncomplete = true
                    state.waiting = false
                    state.waitDeadline = nil
                    state.specIdx = state.specIdx + 1
                    state.lootIdx = 1
                    state.prepared = false
                else
                    Utils.SafeAfter(0.1, function()
                        local ok, err = xpcall(step, Utils.ErrorHandler)
                        if not ok then finish(false, err) end
                    end)
                    return
                end
            else
                local diff = state.diffPairs[state.diffIdx]
                local sp = needScan[state.specIdx]
                local spKey = sp.classID .. "-" .. sp.specID
                if not state.prepared then
                    EJ_SelectInstance(inst.id)
                    EJ_SelectEncounter(state.encID)
                    if EJ_SetDifficulty then EJ_SetDifficulty(diff.id) end
                    if EJ_SetSlotFilter then EJ_SetSlotFilter(Enum.ItemSlotFilterType.NoFilter) end
                    if EJ_SetLootFilter then
                        EasyFind._lootFilterHookSuppress = true
                        EJ_SetLootFilter(sp.classID, sp.specID)
                        EasyFind._lootFilterHookSuppress = false
                    end
                    state.lootIdx = 1



                    state.cellNum = EJ_GetNumLoot()
                    state.cellStale = EJ_IsLootListOutOfDate and EJ_IsLootListOutOfDate() or false
                    state.cellPending = false
                    state.prepared = true
                end

                if state.cellStale then


                    state.waiting = true
                    if not state.waitDeadline then
                        state.waitDeadline = GetTime() + 1.5
                    end
                else
                    local processed = 0
                    while processed < 8 do
                        if state.lootIdx > (state.cellNum or 0) then




                            if state.cellPending then scanIncomplete = true end
                            state.waitDeadline = nil
                            state.specIdx = state.specIdx + 1
                            state.lootIdx = 1
                            state.prepared = false
                            break
                        end
                        local lootInfo = EJ_GetLootInfoByIndex(state.lootIdx)
                        if lootInfo and lootInfo.name and lootInfo.itemID then
                            if CacheLootInfo(self, lootInfo, inst, state.encName, state.encID, diff, sp, spKey, GetItemInfoInstantFn) then
                                partialLootChanged = true
                                sweepCachedAny = true
                            end
                        else



                            state.cellPending = true
                        end
                        state.lootIdx = state.lootIdx + 1
                        processed = processed + 1
                    end
                end
            end

            if debugprofilestop and (debugprofilestop() - start) >= budgetMs then
                if partialLootChanged then
                    partialLootChanged = false
                    RebuildLootSearchData()
                    if self.SchedulePartialSearchRefresh then





                        self:SchedulePartialSearchRefresh(750)
                    end
                end
                Utils.SafeAfter(0, function()
                    local ok, err = xpcall(step, Utils.ErrorHandler)
                    if not ok then finish(false, err) end
                end)
                return
            end
        end
    end

    Utils.SafeAfter(0, function()
        local ok, err = xpcall(step, Utils.ErrorHandler)
        if not ok then finish(false, err) end
    end)
end








local C_SpellBook = C_SpellBook
local IsPlayerSpell = IsPlayerSpell
local getRecipeInfo = C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo






local function IsRecipeLearned(recipeID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, recipeID)
        if ok then return known end
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, recipeID)
        if ok then return known end
    end
    return true
end
Database.IsRecipeLearned = IsRecipeLearned




local function PageRecipeIDs(profData, pageID)
    local byPage = profData.recipesByPage
    if not byPage then return nil end
    profData._pageCache = profData._pageCache or {}
    local cached = profData._pageCache[pageID]
    if cached then return cached end
    local packed = byPage[pageID]
    if not packed then return nil end
    local ids = {}
    for id in packed:gmatch("%d+") do
        ids[#ids + 1] = tonumber(id)
    end
    profData._pageCache[pageID] = ids

    local made = profData.makesByPage and profData.makesByPage[pageID]
    if made then
        local items = {}
        for id in made:gmatch("%d+") do items[#items + 1] = tonumber(id) end
        profData._makesCache = profData._makesCache or {}
        profData._makesCache[pageID] = items
    end
    return ids
end
Database.PageRecipeIDs = PageRecipeIDs





local professionPageRetries = 0



local function ProfessionPagesResolved()
    local resolved = 0
    if not (GetProfessions and GetProfessionInfo and ns.KnownExpansionPages) then return resolved end
    local p1, p2, arch, fish, cook = GetProfessions()
    local idxs = { p1, p2, arch, fish, cook }
    for i = 1, 5 do
        local idx = idxs[i]
        if idx then
            local _, _, _, _, _, _, skillLine = GetProfessionInfo(idx)
            if skillLine and ns.PROFESSION_RECIPES and ns.PROFESSION_RECIPES[skillLine] then
                local pages = ns.KnownExpansionPages(skillLine)
                if pages and #pages > 0 then resolved = resolved + 1 end
            end
        end
    end
    return resolved
end





local function ScheduleProfessionRetry(self)
    if professionPageRetries >= 6 then professionPageRetries = 0; return end
    professionPageRetries = professionPageRetries + 1
    local before = ProfessionPagesResolved()
    Utils.SafeAfter(3, function()
        if ProfessionPagesResolved() > before then
            if self.RefreshDynamicCategory then self:RefreshDynamicCategory("professions") end
        else
            ScheduleProfessionRetry(self)
        end
    end)
end






Database.CLASSIC_OPEN_WINDOW_S = 1.5
Database.CLASSIC_SKILL_LEVEL = { optimal = 0, medium = 1, easy = 2, trivial = 3 }

function Database.ClassicRecipeBook()
    local db = EasyFind and EasyFind.db
    if not db then return nil end
    db.classicRecipes = db.classicRecipes or {}
    local key = ns.CurrentCharacterKey()
    db.classicRecipes[key] = db.classicRecipes[key] or {}
    return db.classicRecipes[key]
end

function Database:NoteClassicOpener(profName, spellID)
    local book = Database.ClassicRecipeBook()
    local prof = book and book[profName]
    local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    if not prof or not spellName or prof.recipes[spellName] then return false end
    if prof.spellID == spellID then return false end
    prof.spellID = spellID
    return true
end

function Database:NoteClassicCast(spellID)
    local now = GetTime()
    self.classicLastCast = self.classicLastCast or {}
    self.classicLastCast.spellID, self.classicLastCast.at = spellID, now
    local shownAt = self.classicWindowShown
    if shownAt and now - shownAt.at < Database.CLASSIC_OPEN_WINDOW_S then
        return self:NoteClassicOpener(shownAt.profession, spellID)
    end
    return false
end

function Database:CaptureClassicRecipes(isCraft, isShow)
    local lineFn = _G[isCraft and "GetCraftDisplaySkillLine" or "GetTradeSkillLine"]
    local countFn = _G[isCraft and "GetNumCrafts" or "GetNumTradeSkills"]
    local infoFn = _G[isCraft and "GetCraftInfo" or "GetTradeSkillInfo"]
    local iconFn = _G[isCraft and "GetCraftIcon" or "GetTradeSkillIcon"]
    if not (lineFn and countFn and infoFn) then return false end
    local linked = _G["IsTradeSkillLinked"]
    if not isCraft and linked and linked() then return false end
    local profName = lineFn()
    if isCraft and (not profName or profName == "" or profName == "UNKNOWN") and _G["GetCraftName"] then
        profName = _G["GetCraftName"]()
    end
    if not profName or profName == "" or profName == "UNKNOWN" then return false end
    local book = Database.ClassicRecipeBook()
    if not book then return false end
    local prof = book[profName]
    local changed = false
    if not prof then
        prof = { recipes = {} }
        book[profName] = prof
        changed = true
    end

    prof.levels = prof.levels or {}
    for i = 1, countFn() or 0 do
        local name, second, third = infoFn(i)
        local kind = isCraft and third or second
        if name and name ~= "" and kind ~= "header" then
            if not prof.recipes[name] then
                prof.recipes[name] = (iconFn and iconFn(i)) or true
                changed = true
            end
            prof.levels[name] = Database.CLASSIC_SKILL_LEVEL[kind] or prof.levels[name]
        end
    end
    if isShow then
        local now = GetTime()
        self.classicWindowShown = self.classicWindowShown or {}
        self.classicWindowShown.profession, self.classicWindowShown.at = profName, now
        local cast = self.classicLastCast
        if cast and now - cast.at < Database.CLASSIC_OPEN_WINDOW_S and self:NoteClassicOpener(profName, cast.spellID) then
            changed = true
        end
    end
    if not prof.spellID and C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(profName)
        if info and info.spellID then
            prof.spellID = info.spellID
            changed = true
        end
    end
    return changed
end




function Database:PopulateClassicProfessions()
    RemoveEntriesByCategory("Profession")
    if self.ResetSearchCache then self:ResetSearchCache() end
    local book = Database.ClassicRecipeBook()
    if not book then return false end
    local getTexture = C_Spell and C_Spell.GetSpellTexture

    local off = EasyFind.db.professionFilters or {}
    for profName, prof in pairs(book) do
        if off[profName] ~= false then
            local profLower = slower(profName)
            local profIcon = prof.spellID and getTexture and getTexture(prof.spellID) or nil
            ns.ProfessionGlyphs = ns.ProfessionGlyphs or {}
            ns.ProfessionGlyphs[profName] = profIcon and { tex = profIcon } or nil
            uiSearchData[#uiSearchData + 1] = {
                name = profName, nameLower = profLower, icon = profIcon, category = "Profession",
                keywords = { profLower, "profession" }, keywordsLower = { profLower, "profession" },
                classicProfession = profName, spellID = prof.spellID,
            }
            for recipe, icon in pairs(prof.recipes) do
                Utils.SliceCheckpoint()
                local lower = slower(recipe)
                uiSearchData[#uiSearchData + 1] = {
                    name = recipe, nameLower = lower, icon = icon ~= true and icon or profIcon,
                    category = "Profession", keywords = { lower, profLower }, keywordsLower = { lower, profLower },
                    classicProfession = profName, classicRecipe = true, professionName = profName,
                    spellID = prof.spellID,
                }
            end
        end
    end
    return true
end

function Database:HasClassicProfessions()
    local book = Database.ClassicRecipeBook()
    return book ~= nil and next(book) ~= nil
end

function Database:PopulateDynamicProfessions()
    if ns.Caps and ns.Caps.classic then return self:PopulateClassicProfessions() end
    if not (GetProfessions and GetProfessionInfo) then return false end
    local pagesUnresolved = false

    RemoveEntriesByCategory("Profession")
    if self.ResetSearchCache then self:ResetSearchCache() end

    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
    local profIndexes = { prof1, prof2, archaeology, fishing, cooking }
    local profFilters = EasyFind.db.professionFilters
    local added = false
    for i = 1, 5 do
        local profIndex = profIndexes[i]
        if profIndex then
            local profName, profIcon, _, _, numAbilities, spellOffset, skillLine = GetProfessionInfo(profIndex)
            if profName and profName ~= "" and skillLine
               and not (profFilters and profFilters[skillLine] == false) then
                local nameLower = slower(profName)

                ns.ProfessionGlyphs = ns.ProfessionGlyphs or {}
                ns.ProfessionGlyphs[profName] = profIcon and { tex = profIcon } or nil













                local profSpellID
                if spellOffset and numAbilities and numAbilities > 0
                   and C_SpellBook and C_SpellBook.GetSpellBookItemType
                   and Enum and Enum.SpellBookSpellBank and Enum.SpellBookItemType then
                    for slot = spellOffset + 1, spellOffset + numAbilities do
                        local okType, itemType, actionID, slotSpellID =
                            pcall(C_SpellBook.GetSpellBookItemType,
                                slot, Enum.SpellBookSpellBank.Player)
                        if okType and itemType == Enum.SpellBookItemType.Spell then
                            local okPassive, passive = pcall(C_SpellBook.IsSpellBookItemPassive,
                                slot, Enum.SpellBookSpellBank.Player)
                            if okPassive and not passive then
                                profSpellID = slotSpellID or actionID
                                if profSpellID then break end
                            end
                        end
                    end
                end
                uiSearchData[#uiSearchData + 1] = {
                    name = profName,
                    nameLower = nameLower,
                    icon = profIcon,
                    category = "Profession",
                    keywords = { nameLower, "profession" },
                    professionSkillLine = skillLine,
                    spellID = profSpellID,
                    professionOpenID = ns.PROFESSION_RECIPES
                        and ns.PROFESSION_RECIPES[skillLine]
                        and ns.PROFESSION_RECIPES[skillLine].childSkillLine,
                }
                added = true







                local profData = ns.PROFESSION_RECIPES and ns.PROFESSION_RECIPES[skillLine]
                if profData and profData.recipesByPage then
                    local getSpell = C_Spell and C_Spell.GetSpellInfo
                    local getItemIcon = C_Item and C_Item.GetItemIconByID
                    local pfState = EasyFind.db.professionRecipeFilters
                    local showLearned = not (pfState and pfState.learned == false)
                    local showUnlearned = not (pfState and pfState.unlearned == false)



                    local ownedPages = ns.KnownExpansionPages and ns.KnownExpansionPages(skillLine)

                    if not (ownedPages and #ownedPages > 0) and ns.Caps and ns.Caps.forever then
                        local only = next(profData.recipesByPage)
                        if only and next(profData.recipesByPage, only) == nil then
                            ownedPages = { { professionID = only } }
                        end
                    end
                    local fallbackLearnedOnly = not (ownedPages and #ownedPages > 0)
                    if fallbackLearnedOnly then pagesUnresolved = true end
                    local pageIDsToScan = {}
                    if fallbackLearnedOnly then
                        for pageID in pairs(profData.recipesByPage) do
                            pageIDsToScan[#pageIDsToScan + 1] = pageID
                        end
                    else
                        for pi = 1, #ownedPages do
                            pageIDsToScan[#pageIDsToScan + 1] = ownedPages[pi].professionID
                        end
                    end
                    for pi = 1, #pageIDsToScan do
                        local pageID = pageIDsToScan[pi]
                        local pageIDs = PageRecipeIDs(profData, pageID)
                        local made = profData._makesCache and profData._makesCache[pageID]
                        if pageIDs then
                            for ri = 1, #pageIDs do
                                if ri % 32 == 0 then Utils.SliceCheckpoint() end
                                local recipeID = pageIDs[ri]
                                local show
                                if fallbackLearnedOnly then
                                    show = IsRecipeLearned(recipeID)
                                elseif showLearned and showUnlearned then
                                    show = true
                                elseif showLearned or showUnlearned then
                                    local learned = IsRecipeLearned(recipeID)
                                    show = (learned and showLearned) or (not learned and showUnlearned)
                                end
                                if show then











                                    local rName, rIcon
                                    if getSpell then
                                        local ok, spellInfo = pcall(getSpell, recipeID)
                                        if ok and type(spellInfo) == "table" then
                                            rName = spellInfo.name
                                            rIcon = spellInfo.iconID
                                        end
                                    end
                                    if (not rName) and getRecipeInfo then
                                        local ok, info = pcall(getRecipeInfo, recipeID)
                                        if ok and type(info) == "table" then
                                            rName = info.name
                                            rIcon = rIcon or info.icon
                                        end
                                    end


                                    local item = made and made[ri]
                                    if item and item > 0 and getItemIcon then
                                        rIcon = getItemIcon(item) or rIcon
                                    end
                                    if rName and rName ~= "" then
                                        local rNameLower = slower(rName)
                                        uiSearchData[#uiSearchData + 1] = {
                                            name = rName,
                                            nameLower = rNameLower,
                                            icon = rIcon or profIcon,
                                            category = "Profession",
                                            keywords = { rNameLower, nameLower },
                                            professionSkillLine = skillLine,
                                            professionName = profName,
                                            professionOpenID = pageID,
                                            professionRecipeID = recipeID,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end






    if pagesUnresolved then
        ScheduleProfessionRetry(self)
    else
        professionPageRetries = 0
    end
    return added
end


Corpora.MACRO_PATHS = {}
Corpora.MACRO_MT = Utils.LeanRowMT({ category = "Macro", buttonFrame = "MainMenuMicroButton" }, { steps = function(row)
    local macros = _G["MACROS"] or "Macros"
    return {
        { buttonFrame = "MainMenuMicroButton" },
        { gameMenuText = macros },
        { waitForFrame = "MacroFrame", tabIndex = row.macroIsChar and 2 or 1 },
        { waitForFrame = "MacroFrame", macroIndex = row.macroIndex },
    }
end })

function Database:PopulateDynamicMacros()
    if not GetNumMacros or not GetMacroInfo then return false end

    RemoveEntriesByCategory("Macro")
    if self.ResetSearchCache then self:ResetSearchCache() end

    local numGlobal, numPerChar = GetNumMacros()
    local MAX_ACCOUNT = MAX_ACCOUNT_MACROS or 120



    local function MacroBodyTitle(body)
        for line in (body or ""):gmatch("[^\n]+") do
            local text = line:match("^%s*(.-)%s*$")
            if text ~= "" and text:sub(1, 1) ~= "#" then return text end
        end
    end

    local function injectMacro(macroIdx, isCharSpecific)
        local name, iconTexture, body = GetMacroInfo(macroIdx)
        if name and not name:find("%S") then name = MacroBodyTitle(body) end
        if not name then return end
        local nameLower = slower(name)
        local kw = { "macro", nameLower }

        if body and body ~= "" then
            local cleanBody = body:gsub("#show[^\n]*", ""):gsub("/", " ")
            for word in cleanBody:gmatch("[%w']+") do
                local wl = slower(word)
                if #wl >= 3 then kw[#kw + 1] = wl end
            end
        end
        local paths = Corpora.MACRO_PATHS
        local path = paths[isCharSpecific]
        if not path then
            path = { _G["MACROS"] or "Macros", isCharSpecific and (_G["CHARACTER"] or "Character") or (_G["GENERAL"] or "General") }
            paths[isCharSpecific] = path
        end
        uiSearchData[#uiSearchData + 1] = setmetatable({
            name = name,
            nameLower = nameLower,
            keywords = kw,
            plainKeywords = true,
            icon = iconTexture,
            macroIndex = macroIdx,
            macroBody = body,
            macroIsChar = isCharSpecific,
            path = path,
        }, Corpora.MACRO_MT)
    end

    for i = 1, numGlobal do
        injectMacro(i, false)
    end
    for i = 1, numPerChar do
        injectMacro(MAX_ACCOUNT + i, true)
    end
    return true
end

Corpora.ABILITY_MT = Utils.LeanRowMT({ category = "Ability" }, {
    steps = function(row) return { { spellID = row.spellID } } end,
})

function Database:PopulateDynamicAbilities()
    RemoveEntriesByCategory("Ability")
    if self.ResetSearchCache then self:ResetSearchCache() end

    local SBOOK = C_SpellBook
    local modern = SBOOK and SBOOK.GetSpellBookItemInfo and SBOOK.GetNumSpellBookSkillLines
        and SBOOK.GetSpellBookSkillLineInfo

    local classic = not modern and GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName
        and GetSpellBookItemInfo
    if not (modern or classic) then return false end
    local BANK = classic and "spell" or (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    local SPELL_TYPE = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    local FLYOUT_TYPE = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout
    local GetFlyoutInfoFn = GetFlyoutInfo
    local GetFlyoutSlotInfoFn = GetFlyoutSlotInfo

    local seen = {}

    local function injectAbility(name, subName, spellID, iconID, lineName, lineSpecID, isOffSpec, isPassive, slotIndex)
        if not name or name == "" or not spellID then return end
        local displayName = (subName and subName ~= "") and (name .. " (" .. subName .. ")") or name
        local nameLower = slower(displayName)
        local kw = { slower(name), "ability", "abilities" }
        if lineName and lineName ~= "" then
            kw[#kw + 1] = slower(lineName)
        end







        local isTeleport, teleportName, teleportNameEn
        if ns.AppendDungeonTeleportKeywords then
            isTeleport, teleportName, teleportNameEn = ns.AppendDungeonTeleportKeywords(kw, spellID)
        end

        local row = setmetatable({
            name = displayName,
            nameLower = nameLower,
            keywords = kw,
            treeName = lineName,
            isOffSpec = isOffSpec or false,
            isPassive = isPassive,
            isSpellbookOnly = isOffSpec or isPassive,
            icon = iconID,
            spellID = spellID,
            spellBookSpellID = spellID,
            spellBookIndex = slotIndex,
            spellBookBank = BANK,
            spellBookCategoryName = lineName,
            spellBookSpecID = lineSpecID,
            spellName = name,
        }, Corpora.ABILITY_MT)
        if isTeleport then
            row.scoreBonus = 500
            row.scoreBonusWords = ns.DUNGEON_TELEPORT_ASK_WORDS
            row.teleportNameLower = teleportName
            row.teleportNameEnLower = teleportNameEn
        end
        uiSearchData[#uiSearchData + 1] = row
        return row
    end

    if classic then

        local order, best = {}, {}
        for tab = 1, GetNumSpellTabs() or 0 do
            local lineName, _, offset, numSlots = GetSpellTabInfo(tab)
            offset = offset or 0
            for slot = offset + 1, offset + (numSlots or 0) do
                Utils.SliceCheckpoint()
                local slotType, spellID = GetSpellBookItemInfo(slot, BANK)
                local name, rank = GetSpellBookItemName(slot, BANK)
                if slotType == "SPELL" and spellID and name and name ~= "" then
                    if not best[name] then order[#order + 1] = name end
                    best[name] = { rank = rank, spellID = spellID, slot = slot, line = lineName }
                end
            end
        end
        for i = 1, #order do
            local name = order[i]
            local b = best[name]
            local icon = GetSpellBookItemTexture and GetSpellBookItemTexture(b.slot, BANK)
            local isPassive = _G["IsPassiveSpell"]
            local passive = isPassive and isPassive(b.slot, BANK) and true or false
            injectAbility(name, b.rank, b.spellID, icon, b.line, nil, false, passive, b.slot)
        end
        return true
    end

    local numLines = SBOOK.GetNumSpellBookSkillLines() or 0
    for tab = 1, numLines do
        local lineInfo = SBOOK.GetSpellBookSkillLineInfo(tab)
        local offset = lineInfo and lineInfo.itemIndexOffset or 0
        local numSpells = lineInfo and lineInfo.numSpellBookItems or 0
        local lineName = lineInfo and lineInfo.name
        local lineSpecID = lineInfo and lineInfo.specID
        local offSpecID = lineInfo and lineInfo.offSpecID
        if (lineSpecID == nil or lineSpecID == 0)
            and offSpecID and offSpecID ~= 0 then
            lineSpecID = offSpecID
        end
        local isOffSpec = lineInfo and lineInfo.offSpecID
            and lineInfo.offSpecID ~= 0 or false
        for s = offset + 1, offset + numSpells do
            Utils.SliceCheckpoint()
            local itemInfo = SBOOK.GetSpellBookItemInfo(s, BANK)
            if itemInfo and itemInfo.name and itemInfo.name ~= "" and itemInfo.actionID then
                if (not SPELL_TYPE or itemInfo.itemType == SPELL_TYPE) then
                    local seenKey = itemInfo.actionID .. ":" .. tab .. ":" .. (lineSpecID or "")
                    if not seen[seenKey] then
                        seen[seenKey] = true
                        injectAbility(itemInfo.name, itemInfo.subName, itemInfo.actionID,
                            itemInfo.iconID, lineName, lineSpecID, isOffSpec, itemInfo.isPassive, s)
                    end
                elseif FLYOUT_TYPE and itemInfo.itemType == FLYOUT_TYPE
                       and GetFlyoutInfoFn and GetFlyoutSlotInfoFn then


                    local flyoutID = itemInfo.actionID
                    local flyoutName, _, numSlots, isKnown = GetFlyoutInfoFn(flyoutID)
                    if isKnown and numSlots and numSlots > 0 then
                        local flyoutKw = flyoutName and flyoutName ~= ""
                            and slower(flyoutName) or nil
                        for slot = 1, numSlots do
                            local slotSpellID, _, slotIsKnown, slotSpellName = GetFlyoutSlotInfoFn(flyoutID, slot)
                            if slotIsKnown and slotSpellID and slotSpellName then
                                local slotIcon = C_Spell and C_Spell.GetSpellTexture
                                    and C_Spell.GetSpellTexture(slotSpellID)
                                local seenKey = tostring(slotSpellID) .. ":" .. tostring(tab)
                                    .. ":" .. tostring(lineSpecID or "")
                                if not seen[seenKey] then
                                    seen[seenKey] = true
                                    injectAbility(slotSpellName, nil, slotSpellID,
                                        slotIcon, lineName, lineSpecID, isOffSpec, false, s)
                                    if flyoutKw then
                                        local injected = uiSearchData[#uiSearchData]
                                        injected.keywords[#injected.keywords + 1] = flyoutKw
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end




    if GetProfessions and GetProfessionInfo then
        for _, profIndex in pairs({ GetProfessions() }) do
            local profName, _, _, _, numAbilities, spellOffset = GetProfessionInfo(profIndex)
            if profName and spellOffset and numAbilities and numAbilities > 0 then
                local opener = true
                for s = spellOffset + 1, spellOffset + numAbilities do
                    local itemInfo = SBOOK.GetSpellBookItemInfo(s, BANK)
                    if itemInfo and itemInfo.itemType == SPELL_TYPE and not itemInfo.isPassive then
                        if opener then
                            opener = false
                        else

                            local row = injectAbility(itemInfo.name, nil, itemInfo.spellID or itemInfo.actionID,
                                itemInfo.iconID, profName, nil, false, false, s)
                            if row then
                                row.spellName = nil
                                row.professionAbility = true
                            end
                        end
                    end
                end
            end
        end
    end
    return true
end
















local bossInstanceMTCache = {}

local function ClearBossInstanceCache()
    wipe(bossInstanceMTCache)
end



function Corpora.BuildBossSteps(tier, isRaid, instID, instName, bossName, encounterID)
    return {
        { buttonFrame = "EJMicroButton" },
        { waitForFrame = "EncounterJournal", ejTier = tier, ejTabIsRaid = isRaid },
        { waitForFrame = "EncounterJournal", ejInstance = instName, ejInstanceID = instID },
        { waitForFrame = "EncounterJournal", ejBoss = bossName, ejEncounterID = encounterID },
    }
end



local function GetBossInstanceMT(tier, isRaid, instID, instName, entrance)
    local cached = bossInstanceMTCache[instID]
    if cached then return cached end

    local instLower = slower(instName or "")


    local kw = { "boss", "bosses" }
    local abbrs = Database.InstanceAbbrs(instLower)
    if abbrs then
        for ai = 1, #abbrs do kw[#kw + 1] = abbrs[ai] end
    end

    local pathArr = { isRaid and "Raid" or "Dungeon", instName }

    local proto = {
        category          = "Boss",
        isRaidBoss        = isRaid,
        ejTier            = tier,
        instanceID        = instID,
        instanceName      = instName,
        instanceNameLower = instLower,
        keywords          = kw,
        path              = pathArr,
    }
    if entrance then
        proto.gpsDest = { name = instName, mapID = entrance.m, x = entrance.x, y = entrance.y,
                          isDungeonEntrance = true, category = isRaid and "raid" or "dungeon" }
    end
    local mt = {
        __index = function(t, k)
            if k == "steps" then
                if entrance then return nil end
                local v = Corpora.BuildBossSteps(tier, isRaid, instID, instName, t.name, t.encounterID)
                rawset(t, "steps", v)
                return v
            end
            return proto[k]
        end,
        __index_proto = proto,
    }
    bossInstanceMTCache[instID] = mt
    return mt
end

local function BuildBossEntry(tier, isRaid, instID, instName, encName, encID, icon, entrance, displayID)
    local mt = GetBossInstanceMT(tier, isRaid, instID, instName, entrance)
    local entry = setmetatable({
        name = encName,
        nameLower = slower(encName),
        encounterID = encID,
        icon = icon,
        displayID = displayID,
    }, mt)

    local wings = Database.BOSS_WING_WORDS[entry.nameLower]
    if wings then
        local kw = {}
        for _, w in ipairs(mt.__index_proto.keywords) do kw[#kw + 1] = w end
        for _, w in ipairs(wings) do kw[#kw + 1] = w end
        entry.keywords = kw
    end
    Database.AddInstanceSearchWords(instName, encName)
    return entry
end




local function BossFace(getCreatureInfo, encID)
    if not (getCreatureInfo and encID) then return nil, nil end
    local ok, _, _, _, displayInfo, iconImage = pcall(getCreatureInfo, 1, encID)
    if not ok then return nil, nil end
    return (iconImage and iconImage ~= 0) and iconImage or nil, (displayInfo and displayInfo ~= 0) and displayInfo or nil
end


function Corpora.PopulateStaticBosses(database)
    RemoveEntriesByCategory("Boss")
    ClearBossInstanceCache()
    local insts = Corpora.StaticInstances()
    local getCreatureInfo = EJ("GetCreatureInfo")
    local seen = {}
    for _, boss in ipairs(ns.STATIC_LOOT) do
        local e = insts[boss.inst]
        local instName = Corpora.StaticInstanceName(boss.inst, e)
        if instName and not seen[boss.enc] then
            seen[boss.enc] = true

            local isRaid = e == nil or e.raid or false


            local icon, displayID = BossFace(getCreatureInfo, boss.enc)
            local entry = BuildBossEntry(1, isRaid, boss.inst, instName,
                Corpora.StaticBossName(boss), boss.enc, icon, e, displayID or boss.d)
            entry.lootCount = boss.items and #boss.items or nil
            uiSearchData[#uiSearchData + 1] = entry
        end
    end
    if database.ResetSearchCache then database:ResetSearchCache() end
    return true
end

local function AddBossEntry(tier, isRaid, instID, instName, encName, encID, getCreatureInfo)
    local icon, displayID = BossFace(getCreatureInfo, encID)
    local entry = BuildBossEntry(tier, isRaid, instID, instName, encName, encID, icon, nil, displayID)
    uiSearchData[#uiSearchData + 1] = entry
    return entry
end

local BOSS_ROW_SPEC = {
    { "tier" }, { "isRaid" }, { "instanceID" },
    { "instanceName" }, { "name" }, { "encounterID" }, { "icon" }, { "displayID" },
}

local function AddBossCacheRow(cacheRows, tier, isRaid, instID, instName, encName, encID, entry)
    if not cacheRows then return end
    cacheRows[#cacheRows + 1] = {
        tier = tier,
        isRaid = isRaid and true or false,
        instanceID = instID,
        instanceName = instName,
        name = encName,
        encounterID = encID,
        icon = entry and entry.icon,
        displayID = entry and entry.displayID,
    }
end

local function PersistBossCache(cacheRows)
    local db = EasyFind and EasyFind.db
    if not db or not cacheRows then return end
    db.bossCache = {
        version = ns.BOSS_CACHE_VER,
        packed = Utils.PackRows(cacheRows, BOSS_ROW_SPEC),
    }
    db.bossCacheVer = ns.BOSS_CACHE_VER
end





Corpora.bossKwBuf = {}
function Corpora.BossRowKeywords(row)
    local instName = row.instanceName
    local instLower = type(instName) == "string" and slower(instName) or nil
    local n = 0
    if instLower then
        n = n + 1
        Corpora.bossKwBuf[n] = instLower
    end
    n = n + 1
    Corpora.bossKwBuf[n] = "boss"
    n = n + 1
    Corpora.bossKwBuf[n] = "bosses"
    local abbrs = instLower and Database.InstanceAbbrs(instLower)
    if abbrs then
        for i = 1, #abbrs do
            n = n + 1
            Corpora.bossKwBuf[n] = abbrs[i]
        end
    end
    local wings = row.name and Database.BOSS_WING_WORDS[slower(row.name)]
    if wings then
        for i = 1, #wings do
            n = n + 1
            Corpora.bossKwBuf[n] = wings[i]
        end
    end
    for i = #Corpora.bossKwBuf, n + 1, -1 do Corpora.bossKwBuf[i] = nil end
    return Corpora.bossKwBuf
end

Corpora.BOSS_CORPUS_PROTO = { category = "Boss" }

Corpora.BOSS_COMPUTED = {
    isRaidBoss = function(stub) return stub.isRaid == true end,
    ejTier = function(stub) return stub.tier or 1 end,
    instanceNameLower = function(stub)
        local instName = stub.instanceName
        return type(instName) == "string" and slower(instName) or nil
    end,
    keywords = function(stub)



        local kws = Corpora.BossRowKeywords(stub)
        local copy = {}
        for i = type(stub.instanceName) == "string" and 2 or 1, #kws do copy[#copy + 1] = kws[i] end
        return copy
    end,
    keywordsLower = function(stub) return stub.keywords end,
    path = function(stub)
        return { stub.isRaid and "Raid" or "Dungeon", stub.instanceName }
    end,
    steps = function(stub)
        return Corpora.BuildBossSteps(stub.ejTier, stub.isRaid == true, stub.instanceID,
            stub.instanceName, stub.name, stub.encounterID)
    end,
}

local function HydratePersistedBossCache()
    if bossCacheHydrated then return false end
    bossCacheHydrated = true

    local db = EasyFind and EasyFind.db
    local saved = db and db.bossCache
    if type(saved) ~= "table" or db.bossCacheVer ~= ns.BOSS_CACHE_VER then
        return false
    end
    if type(saved.packed) ~= "string" or saved.packed == "" then return false end



    local corpus = Utils.NewPackedCorpus(saved.packed, BOSS_ROW_SPEC, Corpora.BOSS_CORPUS_PROTO,
        { computed = Corpora.BOSS_COMPUTED, keywordsFor = Corpora.BossRowKeywords,
          keywordFields = { instanceName = true }, sliced = true })
    if corpus.count == 0 then return false end
    Utils.RegisterCorpus("bosses", corpus)

    RemoveEntriesByCategory("Boss")
    ClearBossInstanceCache()

    local inserted = 0
    corpus:EachRow(function(ri, row)
        if row.name and row.name ~= ""
           and row.encounterID and row.instanceID and row.instanceName then
            uiSearchData[#uiSearchData + 1] = corpus:StubAt(ri)
            Database.AddInstanceSearchWords(row.instanceName, row.name)
            inserted = inserted + 1
        end
    end, { name = true, encounterID = true, instanceID = true, instanceName = true }, true)
    if inserted == 0 then return false end

    if Database.ResetSearchCache then Database:ResetSearchCache() end
    return true
end

function Database:HydrateCachedBosses()
    local changed = HydratePersistedBossCache()
    if changed and self.MarkDynamicProviderLoaded then
        self:MarkDynamicProviderLoaded("bosses")
    end
    return changed
end

function Database:PopulateDynamicBosses()
    if ns.STATIC_LOOT and not (ns.Caps and ns.Caps.journal) then return Corpora.PopulateStaticBosses(self) end
    if HydratePersistedBossCache() then return true end

    RemoveEntriesByCategory("Boss")
    ClearBossInstanceCache()
    if self.ResetSearchCache then self:ResetSearchCache() end

    if not EncounterJournal then
        if not (ns.Caps and ns.Caps.journal) then return end
        EncounterJournal_LoadUI()
    end

    local getNumTiers       = EJ("GetNumTiers") or _G.EJ_GetNumTiers
    local getCurrentTier    = EJ("GetCurrentTier") or _G.EJ_GetCurrentTier
    local selectTier        = EJ("SelectTier") or _G.EJ_SelectTier
    local getInstanceByIdx  = EJ("GetInstanceByIndex")
    local selectInstance    = EJ("SelectInstance")
    local getEncounterByIdx = EJ("GetEncounterInfoByIndex")
    local getCreatureInfo   = EJ("GetCreatureInfo") or _G.EJ_GetCreatureInfo
    if not getInstanceByIdx or not getEncounterByIdx or not selectTier then
        return
    end


    local ejFrame = _G["EncounterJournal"]
    local savedOnEvent
    if ejFrame then
        savedOnEvent = ejFrame:GetScript("OnEvent")
        ejFrame:SetScript("OnEvent", nil)
    end

    local savedTier = getCurrentTier and getCurrentTier()
    local numTiers = (getNumTiers and getNumTiers()) or 10
    local cacheRows = {}

    for tier = 1, numTiers do
        selectTier(tier)
        for _, isRaid in ipairs({ false, true }) do
            local idx = 1
            while true do
                local instID, instName = getInstanceByIdx(idx, isRaid)
                if not instID then break end
                if selectInstance then selectInstance(instID) end

                local encIdx = 1
                while true do
                    local encName, _, encID = getEncounterByIdx(encIdx)
                    if not encName then break end

                    local entry = AddBossEntry(tier, isRaid, instID, instName, encName, encID, getCreatureInfo)
                    AddBossCacheRow(cacheRows, tier, isRaid, instID, instName, encName, encID, entry)
                    encIdx = encIdx + 1
                end

                idx = idx + 1
            end
        end
    end

    if savedTier and selectTier then selectTier(savedTier) end
    if ejFrame and savedOnEvent then ejFrame:SetScript("OnEvent", savedOnEvent) end
    PersistBossCache(cacheRows)
    return true
end

function Database:PopulateDynamicBossesAsync(done)
    if not Utils.SafeAfter or (ns.STATIC_LOOT and not (ns.Caps and ns.Caps.journal)) then
        self:PopulateDynamicBosses()
        done(true)
        return
    end
    if HydratePersistedBossCache() then
        done(true)
        return
    end

    RemoveEntriesByCategory("Boss")
    ClearBossInstanceCache()
    if self.ResetSearchCache then self:ResetSearchCache() end

    if not EncounterJournal then
        if not (ns.Caps and ns.Caps.journal) then return end
        EncounterJournal_LoadUI()
    end

    local getNumTiers       = EJ("GetNumTiers") or _G.EJ_GetNumTiers
    local getCurrentTier    = EJ("GetCurrentTier") or _G.EJ_GetCurrentTier
    local selectTier        = EJ("SelectTier") or _G.EJ_SelectTier
    local getInstanceByIdx  = EJ("GetInstanceByIndex")
    local selectInstance    = EJ("SelectInstance")
    local getEncounterByIdx = EJ("GetEncounterInfoByIndex")
    local getCreatureInfo   = EJ("GetCreatureInfo") or _G.EJ_GetCreatureInfo
    if not getInstanceByIdx or not getEncounterByIdx or not selectTier then
        done(false)
        return
    end

    bossScanGeneration = bossScanGeneration + 1
    local myGen = bossScanGeneration
    local ejFrame = _G["EncounterJournal"]
    local savedOnEvent
    if ejFrame then
        savedOnEvent = ejFrame:GetScript("OnEvent")
        ejFrame:SetScript("OnEvent", nil)
    end

    local savedTier = getCurrentTier and getCurrentTier()
    local numTiers = (getNumTiers and getNumTiers()) or 10
    local state = { tier = 1, raidIdx = 1, instIdx = 1, encIdx = 1, instID = nil, instName = nil }
    local raidModes = { false, true }
    local budgetMs = 4
    local cacheRows = {}




    local seenEncounters = {}
    local emittedSinceRefresh = false

    local function finish(changed, err)
        if savedTier and selectTier then selectTier(savedTier) end
        if ejFrame and savedOnEvent then ejFrame:SetScript("OnEvent", savedOnEvent) end
        if changed then PersistBossCache(cacheRows) end
        done(changed, err)
    end

    local function step()
        if myGen ~= bossScanGeneration then
            finish(false, "cancelled")
            return
        end

        local start = debugprofilestop and debugprofilestop() or 0
        while state.tier <= numTiers do
            selectTier(state.tier)
            local isRaid = raidModes[state.raidIdx]
            if isRaid == nil then
                state.tier = state.tier + 1
                state.raidIdx = 1
                state.instIdx = 1
                state.encIdx = 1
                state.instID = nil
                state.instName = nil
            elseif not state.instID then
                local instID, instName = getInstanceByIdx(state.instIdx, isRaid)
                if not instID then
                    state.raidIdx = state.raidIdx + 1
                    state.instIdx = 1
                    state.encIdx = 1
                else
                    state.instID = instID
                    state.instName = instName
                    state.encIdx = 1
                    if selectInstance then selectInstance(instID) end
                end
            else
                local processed = 0
                while processed < 10 do
                    local encName, _, encID = getEncounterByIdx(state.encIdx)
                    if not encName then
                        state.instIdx = state.instIdx + 1
                        state.instID = nil
                        state.instName = nil
                        state.encIdx = 1
                        break
                    end
                    if not (encID and seenEncounters[encID]) then
                        if encID then seenEncounters[encID] = true end
                        local entry = AddBossEntry(state.tier, isRaid, state.instID, state.instName, encName, encID, getCreatureInfo)
                        AddBossCacheRow(cacheRows, state.tier, isRaid, state.instID, state.instName, encName, encID, entry)
                        emittedSinceRefresh = true
                    end
                    state.encIdx = state.encIdx + 1
                    processed = processed + 1
                end
            end

            if debugprofilestop and (debugprofilestop() - start) >= budgetMs then
                if emittedSinceRefresh and self.SchedulePartialSearchRefresh then
                    emittedSinceRefresh = false
                    self:SchedulePartialSearchRefresh(150)
                end
                Utils.SafeAfter(0, function()
                    local ok, err = xpcall(step, Utils.ErrorHandler)
                    if not ok then finish(false, err) end
                end)
                return
            end
        end

        finish(true)
    end

    Utils.SafeAfter(0, function()
        local ok, err = xpcall(step, Utils.ErrorHandler)
        if not ok then finish(false, err) end
    end)
end

function Database:PopulateDynamicTalents()
    RemoveEntriesByCategory("Talent")
    if self.ResetSearchCache then self:ResetSearchCache() end

    local SI = C_SpecializationInfo
    local Caps = ns.Caps


    if Caps and Caps.talentTiers then
        local group = SI.GetActiveSpecGroup and SI.GetActiveSpecGroup() or 1
        local talents = _G["TALENTS"] or "Talents"
        local tierInfo = _G["GetTalentTierInfo"]
        local consts = _G["Constants"] and _G["Constants"].TalentConsts
        local columns = consts and consts.NumTalentColumns or 3
        for tier = 1, _G["MAX_NUM_TALENT_TIERS"] or 6 do
            local level = tierInfo and select(3, tierInfo(tier, group))
            local tierName = level and ((_G["LEVEL"] or "Level") .. " " .. level) or nil
            local kw = { "talent", "talents", "tier" }
            for column = 1, columns do
                Utils.SliceCheckpoint()
                local ok, info = pcall(SI.GetTalentInfo, { tier = tier, column = column, groupIndex = group })
                if ok and type(info) == "table" and info.name and info.name ~= "" then
                    uiSearchData[#uiSearchData + 1] = {
                        name = info.name,
                        nameLower = slower(info.name),
                        keywords = kw,
                        keywordsLower = kw,
                        category = "Talent",
                        icon = info.icon,
                        spellID = (info.spellID or 0) > 0 and info.spellID or nil,
                        spellName = info.name,
                        talentTab = 2,
                        talentTier = tier,
                        talentColumn = column,
                        talentID = info.talentID,
                        talentGroup = group,
                        talentIsAllocated = info.selected or info.known or false,
                        buttonFrame = "TalentMicroButton",
                        path = { talents, tierName },
                        steps = { { buttonFrame = "TalentMicroButton" }, { waitForFrame = "PlayerTalentFrame", tabIndex = 2 } },
                    }
                end
            end
        end
        return true
    end


    local numTabs, numTalents = _G["GetNumTalentTabs"], _G["GetNumTalents"]
    if Caps and Caps.talentTrees and numTabs and numTalents then
        local group = SI.GetActiveSpecGroup and SI.GetActiveSpecGroup() or 1
        local talents = _G["TALENTS"] or "Talents"
        local treeKw = { "talent", "talents", "tree", "spec" }
        for tab = 1, numTabs() or 0 do
            local spec = SI.GetSpecializationInfo and { SI.GetSpecializationInfo(tab) } or {}
            local tabName, tabIcon = spec[2], spec[4]
            local kw = { "talent", "talents" }
            if tabName and tabName ~= "" then
                kw[3] = slower(tabName)

                uiSearchData[#uiSearchData + 1] = {
                    name = tabName,
                    nameLower = slower(tabName),
                    keywords = treeKw,
                    keywordsLower = treeKw,
                    category = "Talent",
                    icon = tabIcon,
                    talentTab = tab,
                    talentGroup = group,
                    buttonFrame = "TalentMicroButton",
                    path = { talents },
                    steps = { { buttonFrame = "TalentMicroButton" }, { waitForFrame = "PlayerTalentFrame", tabIndex = tab } },
                }
            end
            for index = 1, numTalents(tab) or 0 do
                Utils.SliceCheckpoint()
                local ok, info = pcall(SI.GetTalentInfo, { specializationIndex = tab, talentIndex = index, groupIndex = group })
                if ok and type(info) == "table" and info.name and info.name ~= "" then
                    uiSearchData[#uiSearchData + 1] = {
                        name = info.name,
                        nameLower = slower(info.name),
                        keywords = kw,
                        keywordsLower = kw,
                        category = "Talent",
                        icon = info.icon,
                        spellID = info.spellID,
                        spellName = info.name,
                        talentTab = tab,
                        talentIndex = index,
                        talentID = info.talentID,
                        talentGroup = group,
                        talentRank = info.rank,
                        talentMaxRank = info.maxRank,
                        talentIsAllocated = (info.rank or 0) > 0,
                        buttonFrame = "TalentMicroButton",
                        path = { talents, tabName },
                        steps = { { buttonFrame = "TalentMicroButton" }, { waitForFrame = "PlayerTalentFrame", tabIndex = tab } },
                    }
                end
            end
        end
        return true
    end

    if not C_ClassTalents or not C_ClassTalents.GetActiveConfigID
       or not C_Traits or not C_Traits.GetConfigInfo
       or not C_Traits.GetTreeNodes or not C_Traits.GetNodeInfo
       or not C_Traits.GetEntryInfo or not C_Traits.GetDefinitionInfo then
        return false
    end
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return false end

    local cfgOk, configInfo = pcall(C_Traits.GetConfigInfo, configID)
    if not cfgOk or type(configInfo) ~= "table" or type(configInfo.treeIDs) ~= "table" then
        return false
    end





    local treeMTByID = {}
    local SHARED_TALENT_KW = { "talent", "talents", "spec" }
    local function getTreeMT(treeID)
        local cached = treeMTByID[treeID]
        if cached then return cached end
        local baseStep1 = { buttonFrame = "PlayerSpellsMicroButton" }
        local baseStep2 = { waitForFrame = "PlayerSpellsFrame", tabIndex = 2 }
        local proto = {
            category       = "Talent",
            buttonFrame    = "PlayerSpellsMicroButton",
            keywords       = SHARED_TALENT_KW,
            keywordsLower  = SHARED_TALENT_KW,
            path           = { _G["TALENTS"] or "Talents" },
            talentConfigID = configID,
            talentTreeID   = treeID,
        }
        local mt = {
            __index = function(t, k)
                if k == "steps" then
                    local v = {
                        baseStep1, baseStep2,
                        { talentNodeID = t.talentNodeID, talentTreeID = treeID },
                    }
                    rawset(t, "steps", v)
                    return v
                end
                return proto[k]
            end,
            __index_proto = proto,
        }
        treeMTByID[treeID] = mt
        return mt
    end

    local seen = {}

    local function injectEntry(treeID, nodeID, entryID, isChoice, nodeInfo)
        local eok, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
        if not eok or type(entryInfo) ~= "table" then return end
        local defID = entryInfo.definitionID
        if not defID then return end
        local dok, defInfo = pcall(C_Traits.GetDefinitionInfo, defID)
        if not dok or type(defInfo) ~= "table" then return end

        local spellID = defInfo.spellID or defInfo.overriddenSpellID
        local name = defInfo.overrideName
        local icon
        if spellID and C_Spell and C_Spell.GetSpellInfo then
            local sok, spellInfo = pcall(C_Spell.GetSpellInfo, spellID)
            if sok and spellInfo then
                if not name or name == "" then name = spellInfo.name end
                icon = spellInfo.iconID
            end
        end
        if not name or name == "" then return end
        if seen[name .. "|" .. (spellID or 0)] then return end
        seen[name .. "|" .. (spellID or 0)] = true


        local isAllocated
        if isChoice then
            isAllocated = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID == entryID
        else
            isAllocated = (nodeInfo.activeRank or 0) > 0
        end

        uiSearchData[#uiSearchData + 1] = setmetatable({
            name = name,
            nameLower = slower(name),
            icon = icon,
            spellID = spellID,
            spellName = name,
            talentNodeID = nodeID,
            talentEntryID = entryID,
            talentIsChoice = isChoice or false,
            talentIsAllocated = isAllocated and true or false,
        }, getTreeMT(treeID))
    end

    for _, treeID in ipairs(configInfo.treeIDs) do
        local nok, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
        if nok and type(nodeIDs) == "table" then
            for _, nodeID in ipairs(nodeIDs) do
                Utils.SliceCheckpoint()
                local niok, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                if niok and type(nodeInfo) == "table" and type(nodeInfo.entryIDs) == "table" then
                    local isChoice = #nodeInfo.entryIDs > 1
                    for _, entryID in ipairs(nodeInfo.entryIDs) do
                        injectEntry(treeID, nodeID, entryID, isChoice, nodeInfo)
                    end
                end
            end
        end
    end
    self:InjectTalentSwapRows()
    return true
end







local Stored = {}
ns.Stored = Stored

function Stored.ItemIcon(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    end
    return nil
end




Stored.STORED_ITEM_ROW_SPEC = {
    { "itemID" }, { "count" }, { "tab" }, { "slot" },
    { "name" }, { "icon" }, { "quality" },
}


function Stored.ContainerName(bagID)
    if BANK_CONTAINER and bagID == BANK_CONTAINER then return _G["BANK"] or "Bank" end
    local getName = (C_Container and C_Container.GetBagName) or GetBagName
    return getName and getName(bagID) or nil
end





function Stored.Layout(slots, sizes, names)
    local boxes = {}
    for i = 1, #slots do
        local s = slots[i]
        local box = boxes[s.tab] or {}
        boxes[s.tab] = box
        box[s.slot] = (s.count or 1) > 1 and (s.row .. "*" .. s.count) or tostring(s.row)
    end
    local packed = {}
    for tab, box in pairs(boxes) do
        local last = 0
        for slot in pairs(box) do
            if slot > last then last = slot end
        end
        for slot = 1, last do box[slot] = box[slot] or "" end
        packed[tab] = Utils.tconcat(box, ",", 1, last)
    end
    return { slots = packed, sizes = sizes, names = names }
end

Stored.BAG_STORED_KEYWORDS = { "bag", "item", "inventory" }
Stored.BANK_STORED_KEYWORDS = { "bank", "storage", "vault" }



Stored.WARBAND_STORED_KEYWORDS = { "warband", "storage", "vault" }
local warbandKeywordsBuilt = false
local function WarbandKeywords()
    if not warbandKeywordsBuilt then
        warbandKeywordsBuilt = true
        local label = ns.WarbandBankLabel()
        local words = label and SearchText.Tokenize(slower(label))
        if words then
            local kw = Stored.WARBAND_STORED_KEYWORDS
            for i = 1, #words do
                local w = words[i]
                local dup = false
                for k = 1, #kw do
                    if kw[k] == w then dup = true break end
                end
                if not dup then kw[#kw + 1] = w end
            end
        end
    end
    return Stored.WARBAND_STORED_KEYWORDS
end




function Stored.AbsorbStoredRows(record, holderName, charKey, itemMap, order)
    if type(record) ~= "table" or type(record.packed) ~= "string" then return end
    local tabs = type(record.tabs) == "table" and record.tabs
    local rows = Utils.UnpackRows(record.packed, Stored.STORED_ITEM_ROW_SPEC)
    for i = 1, #rows do
        local row = rows[i]
        local itemID = row.itemID
        if itemID then
            local entry = itemMap[itemID]
            if not entry then
                entry = { row = row, total = 0, holders = {} }
                itemMap[itemID] = entry
                order[#order + 1] = entry
            end
            entry.total = entry.total + (row.count or 1)
            entry.holders[#entry.holders + 1] = {
                charKey = charKey,
                name = holderName,
                class = record.class,
                count = row.count or 1,
                tab = row.tab,
                tabName = tabs and tabs[row.tab],
                slot = row.slot,
            }
        end
    end
end

function Stored.StoredCacheStore(cacheField, verField, ver)
    local db = EasyFind and EasyFind.db
    if not db then return nil end
    if type(db[cacheField]) ~= "table" or db[verField] ~= ver then
        db[cacheField] = { chars = {} }
        db[verField] = ver
    end
    db[cacheField].chars = db[cacheField].chars or {}
    return db[cacheField]
end

function Stored.StoredCharRecord(packed, tabs)
    return {
        name = ns.PlayerName() or "?",
        realm = GetRealmName() or "?",
        class = select(2, UnitClass("player")),
        scannedAt = time and time() or 0,
        tabs = tabs,
        packed = packed,
    }
end







Stored.ROW_MTS = {}
local function StoredRowMT(category, remote)
    local key = category .. (remote and "+" or "")
    local mt = Stored.ROW_MTS[key]
    if not mt then
        mt = Utils.LeanRowMT({ category = category, lookupRow = true, storedRemote = remote or nil }, {
            storedSubtext = function(row) return ns.StoredHoldersText(row.storedHolders, category) end,
        })
        Stored.ROW_MTS[key] = mt
    end
    return mt
end



function Stored.IsMountItem(itemID)
    if ns.ERA_MOUNT_ITEMS then return ns.ERA_MOUNT_ITEMS[itemID] == true end
    local getInfo = C_Item and C_Item.GetItemInfoInstant
    if not (getInfo and itemID) then return false end
    local _, _, _, _, _, classID, subclassID = getInfo(itemID)
    local misc = Enum and Enum.ItemClass and Enum.ItemClass.Miscellaneous or 15
    local mount = Enum and Enum.ItemMiscellaneousSubclass and Enum.ItemMiscellaneousSubclass.Mount or 5
    return classID == misc and subclassID == mount
end


function Stored.AddItemKindWords(kw, itemID)
    if not Stored.IsMountItem(itemID) then return end
    kw[#kw + 1] = slower(_G["MOUNT"] or "Mount")
    kw[#kw + 1] = slower(_G["MOUNTS"] or "Mounts")
end

function Stored.EmitStoredRow(entry, category, keywords, remote)
    local row = entry.row
    local itemID = row.itemID
    local name = row.name or (GetItemInfo and GetItemInfo(itemID))
        or ((_G["ITEM"] or "Item") .. " " .. itemID)
    local equipLoc = Utils.GetItemEquipLoc(itemID)
    local nameLower = slower(name)
    local kw = { nameLower }
    for i = 1, #keywords do kw[#kw + 1] = keywords[i] end
    Stored.AddItemKindWords(kw, itemID)
    return setmetatable({
        name = name,
        nameLower = nameLower,
        keywords = kw,
        icon = row.icon or Stored.ItemIcon(itemID),
        itemID = itemID,
        quality = row.quality,
        equipLoc = equipLoc,
        isEquippable = Utils.IsRealEquipLoc(equipLoc),
        storedCount = entry.total,
        storedHolders = entry.holders,
    }, StoredRowMT(category, remote))
end



function Stored.ScopeAdmits(scope, charKey, currentKey)
    if scope == "current" then return charKey == currentKey end
    if type(scope) == "string" and scope ~= "" and scope ~= "all" then
        return charKey == scope
    end
    return true
end








function ns.MaxCarriedBagIndex()
    local maxBag = NUM_BAG_SLOTS or 4
    if NUM_TOTAL_EQUIPPED_BAG_SLOTS and NUM_TOTAL_EQUIPPED_BAG_SLOTS > maxBag then
        maxBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS
    end
    local reagentBag = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    if reagentBag and reagentBag > maxBag then maxBag = reagentBag end
    return maxBag
end




function Stored.WalkPlayerBags()
    local CONT = C_Container
    local getNumSlots = (CONT and CONT.GetContainerNumSlots) or GetContainerNumSlots
    local getItemInfo = (CONT and CONT.GetContainerItemInfo)  or GetContainerItemInfo
    if not getNumSlots or not getItemInfo then return nil, nil end

    local itemMap = {}
    local order = {}
    local sizes = {}
    local slotsSeen = 0
    for bag = 0, ns.MaxCarriedBagIndex() do
        local slots = getNumSlots(bag) or 0
        slotsSeen = slotsSeen + slots
        if slots > 0 then sizes[bag] = slots end
        for slot = 1, slots do
            local raw = getItemInfo(bag, slot)
            if raw then
                local itemID, texture, link, count
                if type(raw) == "table" then
                    itemID, texture, link, count = raw.itemID, raw.iconFileID, raw.hyperlink, raw.stackCount
                else

                    texture = raw
                    local _
                    _, count, _, _, _, _, link, _, _, itemID = getItemInfo(bag, slot)
                end
                if itemID then
                    local entry = itemMap[itemID]
                    if not entry then
                        entry = { texture = texture, link = link, totalCount = 0, locations = {} }
                        itemMap[itemID] = entry
                        order[#order + 1] = itemID
                    end
                    entry.totalCount = entry.totalCount + (count or 1)
                    entry.locations[#entry.locations + 1] = { bag = bag, slot = slot, count = count or 1 }
                end
            end
        end
    end
    return itemMap, order, slotsSeen, sizes
end






local TALENT_SPEC_KW = { "spec", "specialization", "swap", "switch", "talents" }
local TALENT_LOADOUT_KW = { "loadout", "loadouts", "build", "talents", "swap", "switch" }

function Database:InjectTalentSwapRows()

    if ns.Caps and ns.Caps.specs == false then return end
    local specPath = { _G["TALENTS"] or "Talents" }
    local getNumSpecs = (C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializations)
        or GetNumSpecializations
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization)
        or GetSpecialization
    local getSpecInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo)
        or GetSpecializationInfo
    if not (getNumSpecs and getSpecInfo) then return end

    local activeSpec = getSpec and getSpec()

    local activeLabel = "|cff4dff4d" .. L["TALENT_CURRENTLY_ACTIVE"] .. "|r"
    for i = 1, getNumSpecs() or 0 do
        local ok, specID, specName, _, specIcon = pcall(getSpecInfo, i)
        if ok and specID and specName and specName ~= "" then
            local isActive = (i == activeSpec) or nil
            uiSearchData[#uiSearchData + 1] = {
                name = specName,
                nameLower = slower(specName),
                icon = specIcon,
                category = "Talent",
                path = specPath,
                keywords = TALENT_SPEC_KW,
                keywordsLower = TALENT_SPEC_KW,
                specSetIndex = i,
                specIsActive = isActive,
                searchCommandDesc = isActive and activeLabel
                    or L["TALENT_SPEC_SUBTEXT"],
            }
        end
    end

    if not (C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID
            and C_Traits and C_Traits.GetConfigInfo) then
        return
    end






    if not activeSpec then return end
    local okID, specID, specName, _, specIcon = pcall(getSpecInfo, activeSpec)
    if not (okID and specID) then return end
    local okCfg, configIDs = pcall(C_ClassTalents.GetConfigIDsBySpecID, specID)
    if not (okCfg and type(configIDs) == "table") then return end


    local lastSelected
    if C_ClassTalents.GetLastSelectedSavedConfigID then
        local okSel, sel = pcall(C_ClassTalents.GetLastSelectedSavedConfigID, specID)
        if okSel then lastSelected = sel end
    end
    for i = 1, #configIDs do
        local loadoutID = configIDs[i]
        local infoOk, info = pcall(C_Traits.GetConfigInfo, loadoutID)
        if infoOk and type(info) == "table" and info.name and info.name ~= "" then


            local kw = { slower(specName or "") }
            for k = 1, #TALENT_LOADOUT_KW do kw[#kw + 1] = TALENT_LOADOUT_KW[k] end
            local isActive = (loadoutID == lastSelected) or nil
            uiSearchData[#uiSearchData + 1] = {
                name = info.name,
                nameLower = slower(info.name),
                icon = specIcon,
                category = "Talent",
                path = specPath,
                keywords = kw,
                keywordsLower = kw,
                loadoutConfigID = loadoutID,
                loadoutIsActive = isActive,
                searchCommandDesc = isActive and activeLabel
                    or L["TALENT_LOADOUT_SUBTEXT"],
            }
        end
    end
end









local function UpdateLastSelectedLoadout(configID)
    local CT = C_ClassTalents
    if not (CT and CT.UpdateLastSelectedSavedConfigID) then return end
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization)
        or GetSpecialization
    local getSpecInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo)
        or GetSpecializationInfo
    local specIndex = getSpec and getSpec()
    local specID = specIndex and getSpecInfo and getSpecInfo(specIndex)
    local function selectedNow()
        if not (CT.GetLastSelectedSavedConfigID and specID) then return nil end
        local ok, id = pcall(CT.GetLastSelectedSavedConfigID, specID)
        if ok then return id end
        return nil
    end
    if specID then
        pcall(CT.UpdateLastSelectedSavedConfigID, specID, configID)
        local sel = selectedNow()
        if sel == configID or sel == nil then return end
    end
    pcall(CT.UpdateLastSelectedSavedConfigID, configID)
end

local function LoadTalentConfig(configID)
    if not (C_ClassTalents and C_ClassTalents.LoadConfig) then return false end
    local ok = (xpcall(C_ClassTalents.LoadConfig, Utils.ErrorHandler, configID, true))
    if ok then UpdateLastSelectedLoadout(configID) end
    return ok
end





function ns.RunTalentSwap(specIndex, loadoutConfigID)
    if InCombatLockdown() then
        if EasyFind and EasyFind.Print then
            EasyFind:Print(_G["ERR_NOT_IN_COMBAT"] or "")
        end
        return false
    end
    if specIndex then
        local setSpec = (C_SpecializationInfo and C_SpecializationInfo.SetSpecialization)
            or SetSpecialization
        if setSpec then
            return (xpcall(setSpec, Utils.ErrorHandler, specIndex))
        end
    elseif loadoutConfigID then
        return LoadTalentConfig(loadoutConfigID)
    end
    return false
end

Corpora.BAG_MT = Utils.LeanRowMT({ category = "Bag" }, { steps = function(row)
    return {
        { buttonFrame = row.buttonFrame },
        { containerBag = row.bagID, containerSlot = row.bagSlot, allLocations = row.bagLocations },
    }
end })

function Database:PopulateDynamicBags()
    local isRealEquipLoc = Utils.IsRealEquipLoc
    local getEquipLoc = Utils.GetItemEquipLoc
    local getQuality = C_Item and C_Item.GetItemQualityByID

    local itemMap, order, _, sizes = Stored.WalkPlayerBags()
    if not itemMap then return false end

    RemoveEntriesByCategory("Bag")
    if self.ResetSearchCache then self:ResetSearchCache() end

    for _, itemID in ipairs(order) do
        Utils.SliceCheckpoint()
        local info = itemMap[itemID]
        local name = info.link and info.link:match("%[(.-)%]") or (GetItemInfo and GetItemInfo(itemID)) or ((_G["ITEM"] or "Item") .. " " .. itemID)
        local quality
        if getQuality then
            quality = getQuality(itemID)
        elseif GetItemInfo then
            quality = select(3, GetItemInfo(itemID))
        end


        info.quality = quality
        local equipLoc = getEquipLoc(itemID)
        local isEquippable = isRealEquipLoc(equipLoc)
        local first = info.locations[1]
        local bagBtn = first.bag == 0 and "MainMenuBarBackpackButton"
            or ("CharacterBag" .. (first.bag - 1) .. "Slot")
        local nameLower = slower(name)
        local kw = { "bag", "item", "inventory", nameLower }
        Stored.AddItemKindWords(kw, itemID)
        local searchEntry = setmetatable({
            name = name,
            nameLower = nameLower,
            keywords = kw,
            icon = info.texture,
            itemID = itemID,
            quality = quality,
            equipLoc = equipLoc,
            isEquippable = isEquippable,
            bagID = first.bag,
            bagSlot = first.slot,
            bagItemLink = info.link,
            bagCount = info.totalCount,
            bagLocations = info.locations,
            buttonFrame = bagBtn,
        }, Corpora.BAG_MT)
        uiSearchData[#uiSearchData + 1] = searchEntry


        info.searchEntry = searchEntry
    end



    self:PersistBagContents(itemMap, order, sizes)
    Stored.AppendOtherCharacterBagRows(itemMap)
    return true
end





function Stored.AppendOtherCharacterBagRows(liveItemMap)
    local db = EasyFind and EasyFind.db
    local store = db and type(db.bagCache) == "table" and db.bagCache
    if not store or db.bagCacheVer ~= ns.BAG_CACHE_VER then return end
    local chars = store.chars
    if type(chars) ~= "table" then return end

    local scope = db.bagScope
    if scope == "current" then return end

    local currentKey = CharKey()
    local itemMap, order = {}, {}
    for charKey, record in pairs(chars) do
        if charKey ~= currentKey and Stored.ScopeAdmits(scope, charKey, currentKey) then
            Stored.AbsorbStoredRows(record, record.name, charKey, itemMap, order)
        end
    end

    for i = 1, #order do
        local entry = order[i]




        local live = liveItemMap and liveItemMap[entry.row.itemID]
        if live and live.searchEntry then
            local holders = { {
                charKey = currentKey,
                name = ns.PlayerName() or "?",
                class = select(2, UnitClass("player")),
                count = live.totalCount or 1,
            } }
            for h = 1, #entry.holders do holders[#holders + 1] = entry.holders[h] end
            live.searchEntry.storedHolders = holders
            live.searchEntry.storedSubtext = ns.StoredHoldersText(holders, "Bag")
        elseif not live then
            uiSearchData[#uiSearchData + 1] =
                Stored.EmitStoredRow(entry, "Bag", Stored.BAG_STORED_KEYWORDS, true)
        end
    end
end

function Stored.BagCacheStore()
    return Stored.StoredCacheStore("bagCache", "bagCacheVer", ns.BAG_CACHE_VER)
end





function Database:PersistBagContents(itemMap, order, sizes)
    if not itemMap or not order then
        local slotsSeen
        itemMap, order, slotsSeen, sizes = Stored.WalkPlayerBags()





        if slotsSeen == 0 then return false end
    end
    local store = Stored.BagCacheStore()
    if not store or type(order) ~= "table" then return false end

    local getQuality = C_Item and C_Item.GetItemQualityByID
    local rows, slots = {}, {}
    for i = 1, #order do
        local itemID = order[i]
        local info = itemMap[itemID]
        local first = info.locations and info.locations[1]
        for _, loc in ipairs(info.locations) do
            slots[#slots + 1] = { tab = loc.bag, slot = loc.slot, row = i, count = loc.count or 1 }
        end


        local quality = info.quality
        if quality == nil and getQuality then quality = getQuality(itemID) end
        rows[i] = {
            itemID = itemID,
            count = info.totalCount,
            tab = first and first.bag,
            slot = first and first.slot,
            name = info.link and info.link:match("%[(.-)%]"),
            icon = info.texture,
            quality = quality,
        }
    end

    local record = Stored.StoredCharRecord(Utils.PackRows(rows, Stored.STORED_ITEM_ROW_SPEC))
    local names = {}
    for bag in pairs(sizes) do names[bag] = Stored.ContainerName(bag) end
    record.layout = Stored.Layout(slots, sizes, names)
    store.chars[CharKey()] = record
    return true
end







function Stored.CollectBankTabs(bankType, out)
    if not (C_Bank and C_Bank.FetchPurchasedBankTabData and bankType) then return out end
    local ok, tabs = pcall(C_Bank.FetchPurchasedBankTabData, bankType)
    if not ok or type(tabs) ~= "table" then return out end
    for i = 1, #tabs do
        local tab = tabs[i]
        if type(tab) == "table" and tab.ID then
            out[#out + 1] = { id = tab.ID, name = tab.name }
        end
    end
    return out
end

function Stored.GetCharacterBankTabs()
    if C_Bank and C_Bank.FetchPurchasedBankTabData then
        return Stored.CollectBankTabs(Enum and Enum.BankType and Enum.BankType.Character, {})
    end
    if not BANK_CONTAINER then return {} end
    local tabs = { { id = BANK_CONTAINER, name = Stored.ContainerName(BANK_CONTAINER) } }
    local first = (NUM_BAG_SLOTS or 4) + 1
    for bag = first, first + (NUM_BANKBAGSLOTS or 0) - 1 do
        tabs[#tabs + 1] = { id = bag, name = Stored.ContainerName(bag) }
    end
    return tabs
end

function Stored.GetAccountBankTabs()
    return Stored.CollectBankTabs(Enum and Enum.BankType and Enum.BankType.Account, {})
end






function Stored.WalkBankTabs(tabs)
    local getNumSlots = C_Container and C_Container.GetContainerNumSlots
    local getItemInfo = C_Container and C_Container.GetContainerItemInfo
    if not (getNumSlots and getItemInfo) then return nil, nil, 0 end

    local itemMap, order, tabNames = {}, {}, {}
    local slotRows, sizes, rowOf = {}, {}, {}
    local slotsSeen = 0
    for t = 1, #tabs do
        local tabID = tabs[t].id
        tabNames[tabID] = tabs[t].name
        local slots = getNumSlots(tabID) or 0
        slotsSeen = slotsSeen + slots
        if slots > 0 then sizes[tabID] = slots end
        for slot = 1, slots do
            local info = getItemInfo(tabID, slot)
            local itemID = type(info) == "table" and info.itemID or nil
            if itemID then
                local row = itemMap[itemID]
                if not row then
                    local quality = info.quality
                    if quality == nil and C_Item and C_Item.GetItemQualityByID then
                        quality = C_Item.GetItemQualityByID(itemID)
                    end
                    row = {
                        itemID = itemID,
                        count = 0,
                        tab = tabID,
                        slot = slot,
                        name = info.hyperlink and info.hyperlink:match("%[(.-)%]"),
                        icon = info.iconFileID,
                        quality = quality,
                    }
                    itemMap[itemID] = row
                    order[#order + 1] = row
                    rowOf[itemID] = #order
                end
                row.count = row.count + (info.stackCount or 1)
                slotRows[#slotRows + 1] = { tab = tabID, slot = slot, row = rowOf[itemID], count = info.stackCount or 1 }
            end
        end
    end
    return order, tabNames, slotsSeen, Stored.Layout(slotRows, sizes, tabNames)
end

function Stored.BankCacheStore()
    return Stored.StoredCacheStore("bankCache", "bankCacheVer", ns.BANK_CACHE_VER)
end






do
    local index, stamp = {}, nil

    local SOURCES = { { "bagCache", "bagCacheVer", "BAG_CACHE_VER", "bags" }, { "bankCache", "bankCacheVer", "BANK_CACHE_VER", "bank" },
                      { "mailCache", "mailCacheVer", "MAIL_CACHE_VER", "mail" },
                      { "guildBankCache", "guildBankCacheVer", "GUILD_BANK_CACHE_VER", "guild" } }

    local function Stores()
        local db = EasyFind and EasyFind.db
        local out = {}
        for i, src in ipairs(SOURCES) do
            local store = db and type(db[src[1]]) == "table" and db[src[2]] == ns[src[3]] and db[src[1]]
            out[i] = store and type(store.chars) == "table" and store.chars or nil
        end
        return out
    end

    local function Stamp(stores)
        local sum = 0
        for _, chars in pairs(stores) do
            for _, record in pairs(chars) do sum = sum + (type(record.scannedAt) == "number" and record.scannedAt or 0) + 1 end
        end
        return sum
    end

    function ns.StoredItemCounts(itemID)
        local stores = Stores()
        local now = Stamp(stores)
        if now ~= stamp then
            stamp = now
            wipe(index)
            for i, src in ipairs(SOURCES) do
                for charKey, record in pairs(stores[i] or {}) do
                    if type(record) == "table" and type(record.packed) == "string" then
                        for _, row in ipairs(Utils.UnpackRows(record.packed, Stored.STORED_ITEM_ROW_SPEC)) do
                            local id = row.itemID
                            if id then
                                local byChar = index[id] or {}
                                index[id] = byChar
                                local c = byChar[charKey] or { name = record.name, class = record.class, bags = 0, bank = 0 }
                                byChar[charKey] = c
                                c[src[4]] = (c[src[4]] or 0) + (row.count or 1)
                            end
                        end
                    end
                end
            end
        end
        return index[itemID], stamp
    end
end





function Database:ScanBankContents()
    local store = Stored.BankCacheStore()
    if not store then return false end

    local scanned = false

    local charRows, charTabs, charSlots, charLayout = Stored.WalkBankTabs(Stored.GetCharacterBankTabs())
    if charSlots > 0 then
        local record = Stored.StoredCharRecord(Utils.PackRows(charRows, Stored.STORED_ITEM_ROW_SPEC), charTabs)
        record.layout = charLayout
        store.chars[CharKey()] = record
        scanned = true
    end

    local acctRows, acctTabs, acctSlots, acctLayout = Stored.WalkBankTabs(Stored.GetAccountBankTabs())
    if acctSlots > 0 then
        store.account = {
            scannedAt = time and time() or 0,
            tabs = acctTabs,
            packed = Utils.PackRows(acctRows, Stored.STORED_ITEM_ROW_SPEC),
            layout = acctLayout,
        }
        scanned = true
    end

    return scanned
end



function Database:PopulateDynamicBank()
    local db = EasyFind and EasyFind.db
    local store = db and type(db.bankCache) == "table" and db.bankCache
    RemoveEntriesByCategory("Bank")
    RemoveEntriesByCategory("Warband")
    if self.ResetSearchCache then self:ResetSearchCache() end
    if not store or db.bankCacheVer ~= ns.BANK_CACHE_VER then return true end

    local chars = store.chars
    if type(chars) ~= "table" then return true end

    local scope = db.bankScope
    local currentKey = CharKey()




    local itemMap, order = {}, {}
    for charKey, record in pairs(chars) do
        if Stored.ScopeAdmits(scope, charKey, currentKey) then
            Stored.AbsorbStoredRows(record, record.name, charKey, itemMap, order)
        end
    end
    for i = 1, #order do
        uiSearchData[#uiSearchData + 1] =
            Stored.EmitStoredRow(order[i], "Bank", Stored.BANK_STORED_KEYWORDS, true)
    end



    local acctMap, acctOrder = {}, {}
    Stored.AbsorbStoredRows(store.account, ns.WarbandBankLabel(), nil, acctMap, acctOrder)
    for i = 1, #acctOrder do
        uiSearchData[#uiSearchData + 1] =
            Stored.EmitStoredRow(acctOrder[i], "Warband", WarbandKeywords(), true)
    end
    return true
end

function Database:_ResetDynamicProviderCaches()
    wipe(knownCurrencyIDs)
    wipe(lootEntries)
    wipe(lootItemCache)
    setmetatable(lootItemCache, nil)
    Corpora.lootCorpus = nil
    Corpora.lootItemRi = nil
    Utils.RegisterCorpus("loot", nil)
    wipe(lootSpecsScanned)
    wipe(lootEncounterMTCache)
    wipe(pendingStatEnrichment)
    lootItemCacheHydrated = false
    lootSearchDataHydrated = false
    bossCacheHydrated = false
    statisticCacheHydrated = false
end

function Database:_ResetHeavyProviderCaches()
    wipe(lootEntries)
    wipe(lootItemCache)
    setmetatable(lootItemCache, nil)
    Corpora.lootCorpus = nil
    Corpora.lootItemRi = nil
    Utils.RegisterCorpus("loot", nil)
    wipe(lootSpecsScanned)
    wipe(lootEncounterMTCache)
    wipe(pendingStatEnrichment)
    lootItemCacheHydrated = false
    lootSearchDataHydrated = false
    bossCacheHydrated = false
    statisticCacheHydrated = false
end



local CATEGORY_KEYWORD_OVERLAY = {
    ["rated battlegrounds"]      = {"rbg", "rated bg"},
    ["alterac valley"]           = {"av"},
    ["arathi basin"]             = {"ab"},
    ["eye of the storm"]         = {"eots"},
    ["warsong gulch"]            = {"wsg"},
    ["wintergrasp"]              = {"wg"},
    ["strand of the ancients"]   = {"sota"},
    ["isle of conquest"]         = {"ioc"},
    ["temple of kotmogu"]        = {"tok"},
    ["silvershard mines"]        = {"ssm"},
    ["the burning crusade"]      = {"tbc", "burning crusade"},
    ["wrath of the lich king"]   = {"wotlk", "wrath", "lich king"},
    ["mists of pandaria"]        = {"mop", "pandaria"},
    ["warlords of draenor"]      = {"wod", "draenor"},
    ["battle for azeroth"]       = {"bfa"},
    ["shadowlands"]              = {"sl"},
    ["dragonflight"]             = {"df"},
    ["the war within"]           = {"tww", "war within"},
    ["feats of strength"]        = {"fos"},
    ["player vs. player"]        = {"pvp"},
    ["dungeons & raids"]         = {"dungeons", "raids"},
}

local CATEGORY_FLAG_GUILD = 0x00000001
local RefreshStatisticsCategoryIDs
local IsInStatisticsCategoryTree
local MarkID
local HasID


Corpora.ACH_CATEGORY_MT = Utils.LeanRowMT(
    { category = "Achievement Category", buttonFrame = "AchievementMicroButton" },
    { steps = function(row)
        local chain, node = {}, row
        while node do
            chain[#chain + 1] = node
            node = rawget(node, "parentRow")
        end
        local steps = {
            { buttonFrame = "AchievementMicroButton" },
            { waitForFrame = "AchievementFrame", tabIndex = row.isGuildAchievement and 2 or 1 },
        }
        for i = #chain, 1, -1 do
            node = chain[i]
            steps[#steps + 1] = {
                waitForFrame = "AchievementFrame",
                achievementCategory = rawget(node, "categoryName") or node.name,
                achievementCategoryID = node.achievementCategoryID,
            }
        end
        return steps
    end })

local function buildCategoryEntry(cat, displayName, path, parentRow, isGuild)
    local nameLower = slower(cat.name)
    local kw = { nameLower }
    local words = SearchText.Tokenize(nameLower)
    for i = 1, #words do
        local w = words[i]
        if #w > 2 and w ~= nameLower then kw[#kw + 1] = w end
    end
    local overlay = CATEGORY_KEYWORD_OVERLAY[nameLower]
    if overlay then
        for i = 1, #overlay do kw[#kw + 1] = overlay[i] end
    end

    local row = setmetatable({
        name = displayName,
        nameLower = slower(displayName),
        keywords = kw,

        keywordsLower = kw,
        path = path,
        achievementCategoryID = cat.id,
        parentRow = parentRow,
    }, Corpora.ACH_CATEGORY_MT)
    if isGuild then
        row.isGuildAchievement = true
        row.categoryName = cat.name
    end
    return row
end












local TITLE_SOURCE_ROW_SPEC = { { "titleID" }, { "achievementID" } }
local titleSourceByID

local function NormalizeTitleText(raw)
    if not raw or raw == "" then return nil end
    local t = raw:gsub("%%s", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if t == "" then return nil end
    return slower(t)
end

local function HydrateTitleSourceCache()
    if titleSourceByID then return true end
    local db = EasyFind and EasyFind.db
    local cache = db and db.titleSourceCache
    if not cache or cache.version ~= ns.TITLE_SOURCE_CACHE_VER or not cache.packed then
        return false
    end
    local rows = Utils.UnpackRows(cache.packed, TITLE_SOURCE_ROW_SPEC)
    titleSourceByID = {}
    for i = 1, #rows do
        local row = rows[i]
        local tid, aid = tonumber(row.titleID), tonumber(row.achievementID)
        if tid and aid then titleSourceByID[tid] = aid end
    end
    return true
end








local function Claim(found, rows, titleID, achID)
    if titleID and not found[titleID] then
        found[titleID] = achID
        rows[#rows + 1] = { titleID = titleID, achievementID = achID }
    end
end





local function MatchRewardTitles(byName, found, rows, achID, rewardText)
    if not achID then return end
    local key = NormalizeTitleText(rewardText)
    if not key then return end
    if byName[key] then
        Claim(found, rows, byName[key], achID)
        return
    end
    local afterLabel = key:match("^[^:]*:%s*(.+)$")
    if not afterLabel then return end
    if byName[afterLabel] then
        Claim(found, rows, byName[afterLabel], achID)
        return
    end







    for segment in (afterLabel .. " and "):gmatch("(.-) and ") do
        for part in segment:gmatch("[^/]+") do
            part = part:gsub("^%s+", ""):gsub("%s+$", "")
            if #part >= 4 then Claim(found, rows, byName[part], achID) end
        end
    end
end

local titleSourceBuilding, titleSourceAttempted = false, false




local TITLE_SOURCE_MS_PER_SLICE = 1.5
local TITLE_SOURCE_START_DELAY = 3

local function StartTitleSourceBuild()
    if titleSourceBuilding or titleSourceAttempted then return end
    if not (GetNumTitles and GetTitleName and GetCategoryList
            and GetCategoryNumAchievements and GetAchievementInfo) then
        titleSourceAttempted = true
        return
    end



    local byName, anyTitle = {}, false
    local totalTitles = GetNumTitles() or 0
    for titleID = 1, totalTitles do
        local key = NormalizeTitleText(GetTitleName(titleID))
        if key then byName[key] = titleID; anyTitle = true end
    end
    local categories = anyTitle and GetCategoryList() or nil
    if not categories then
        titleSourceAttempted = true
        return
    end

    titleSourceBuilding = true
    local found, rows, ci = {}, {}, 1

    local function finish()
        titleSourceBuilding = false
        titleSourceAttempted = true
        titleSourceByID = found
        local db = EasyFind and EasyFind.db
        if db and #rows > 0 then
            db.titleSourceCache = {
                version = ns.TITLE_SOURCE_CACHE_VER,
                packed = Utils.PackRows(rows, TITLE_SOURCE_ROW_SPEC),
            }
        end



        if db and db.titleFilterMode and db.titleFilterMode ~= "earned" then
            Database:RefreshDynamicCategory("titles")
        end
    end



    local ai = 1


    local seenPrev = {}
    local function slice()
        local sliceStart = debugprofilestop()
        while ci <= #categories do
            local catID = categories[ci]



            local total = GetCategoryNumAchievements(catID, true) or 0
            while ai <= total do



                local achID, _, _, _, _, _, _, _, _, _, rewardText =
                    GetAchievementInfo(catID, ai)
                MatchRewardTitles(byName, found, rows, achID, rewardText)







                local prev, guard = achID, 0
                while prev and guard < 12 do
                    guard = guard + 1
                    prev = GetPreviousAchievement and GetPreviousAchievement(prev)
                    if prev and not seenPrev[prev] then
                        seenPrev[prev] = true
                        MatchRewardTitles(byName, found, rows, prev,
                            select(11, GetAchievementInfo(prev)))
                    elseif prev then
                        break
                    end
                end
                ai = ai + 1
                if debugprofilestop() - sliceStart >= TITLE_SOURCE_MS_PER_SLICE then
                    if ai > total then ci = ci + 1; ai = 1 end
                    Utils.SafeAfter(0, slice)
                    return
                end
            end
            if ai > total then
                ci = ci + 1
                ai = 1
            end
        end
        if ci > #categories then
            finish()
        else
            Utils.SafeAfter(0, slice)
        end
    end





    Utils.SafeAfter(TITLE_SOURCE_START_DELAY, slice)
end



function Database:GetTitleSourceAchievement(titleID)
    if not titleID then return nil end
    if not titleSourceByID then
        if not HydrateTitleSourceCache() then
            StartTitleSourceBuild()
            return nil
        end
    end
    return titleSourceByID[titleID]
end



function Database:EnsureTitleSourceCache()
    if titleSourceByID then return end
    if not HydrateTitleSourceCache() then StartTitleSourceBuild() end
end

function Database:PopulateDynamicAchievements()
    if not GetCategoryList or not GetCategoryInfo then return false end




    RemoveEntriesByCategory("Achievement Category")

    local categories = GetCategoryList()
    if not categories then return false end

    local statsCatSet = RefreshStatisticsCategoryIDs()

    local catMap = {}
    for i = 1, #categories do
        Utils.SliceCheckpoint()
        local catID = categories[i]
        if not HasID(statsCatSet, catID) and not HasID(Database.statisticIDs, catID) then
            local name, parentID, flags = GetCategoryInfo(catID)
            if name and name ~= ""
               and not IsInStatisticsCategoryTree(catID, parentID)
               and not Database:IsStatisticAchievement(catID) then
                catMap[catID] = {
                    id = catID, name = name, parentID = parentID,
                    isGuild = band(flags or 0, CATEGORY_FLAG_GUILD) == 1,
                    children = {},
                }
            end
        end
    end

    local roots = {}
    for _, cat in pairs(catMap) do
        Utils.SliceCheckpoint()
        local parent = cat.parentID and cat.parentID ~= -1 and catMap[cat.parentID]
        if parent then
            parent.children[#parent.children + 1] = cat
        else
            roots[#roots + 1] = cat
        end
    end


    local function emit(cat, path, parentRow, isGuildBranch)
        local prefix = isGuildBranch and "Guild: " or ""
        local row = buildCategoryEntry(cat, prefix .. cat.name, path, parentRow, isGuildBranch)
        uiSearchData[#uiSearchData + 1] = row

        if #cat.children > 0 then
            local childPath = {}
            for i = 1, #path do childPath[i] = path[i] end
            childPath[#childPath + 1] = cat.name
            for i = 1, #cat.children do emit(cat.children[i], childPath, row, isGuildBranch) end
        end
    end

    local personalRoot = { _G["ACHIEVEMENTS"] or "Achievements", L["UITREE_PERSONAL_ACHIEVEMENTS"] }
    local guildRoot = { _G["ACHIEVEMENTS"] or "Achievements", _G["GUILD_ACHIEVEMENTS_TITLE"] or "Guild Achievements" }
    for i = 1, #roots do
        local root = roots[i]
        emit(root, root.isGuild and guildRoot or personalRoot, nil, root.isGuild)
    end
    return true
end





Database.statisticIDs = Database.statisticIDs or {}
Database.statisticsCategoryIDs = Database.statisticsCategoryIDs or {}
Database.statisticsCategoryChildIDs = Database.statisticsCategoryChildIDs or {}
Database.statisticsComplete = Database.statisticsComplete or false
Database.statisticsVersion = Database.statisticsVersion or 0

MarkID = function(set, id)
    if id == nil then return end
    set[id] = true
    local numericID = tonumber(id)
    if numericID then set[numericID] = true end
end

HasID = function(set, id)
    if id == nil then return false end
    if set[id] == true then return true end
    local numericID = tonumber(id)
    return numericID and set[numericID] == true or false
end

RefreshStatisticsCategoryIDs = function(statCats)
    wipe(Database.statisticsCategoryIDs)
    wipe(Database.statisticsCategoryChildIDs)
    if not statCats and GetStatisticsCategoryList then
        statCats = GetStatisticsCategoryList()
    end
    if statCats then
        for i = 1, #statCats do
            MarkID(Database.statisticsCategoryIDs, statCats[i])
        end
    end
    return Database.statisticsCategoryIDs
end

IsInStatisticsCategoryTree = function(categoryID, parentID)
    if not categoryID then return false end
    local statCats = Database.statisticsCategoryIDs
    if HasID(statCats, categoryID) then return true end
    if HasID(statCats, parentID) then return true end

    local cached = Database.statisticsCategoryChildIDs[categoryID]
    if cached ~= nil then return cached end

    local current = parentID
    local seen
    while current and current ~= -1 do
        if HasID(statCats, current) then
            Database.statisticsCategoryChildIDs[categoryID] = true
            return true
        end
        if not GetCategoryInfo then break end
        seen = seen or {}
        if seen[current] then break end
        seen[current] = true
        local _, nextParentID = GetCategoryInfo(current)
        current = nextParentID
    end

    Database.statisticsCategoryChildIDs[categoryID] = false
    return false
end

function Database:IsStatisticAchievement(achievementID)
    if not achievementID then return false end
    if HasID(Database.statisticIDs, achievementID) then return true end
    if not GetCategoryInfo then return false end
    if not next(Database.statisticsCategoryIDs) then RefreshStatisticsCategoryIDs() end
    local getAchievementCategory = _G["GetAchievementCategory"]
    if getAchievementCategory then
        local categoryID = getAchievementCategory(achievementID)
        if IsInStatisticsCategoryTree(categoryID, nil) then return true end
        local categoryParentID
        if categoryID then
            local _
            _, categoryParentID = GetCategoryInfo(categoryID)
        end
        if IsInStatisticsCategoryTree(categoryID, categoryParentID) then return true end
    end
    local _, parentID = GetCategoryInfo(achievementID)
    return IsInStatisticsCategoryTree(achievementID, parentID)
end


local statsScanGeneration = 0
local STAT_KEYWORDS_EMPTY = {}
local STAT_CHAIN_EMPTY = {}
local STAT_DEFAULT_PATH = { _G["ACHIEVEMENTS"] or "Achievements", _G["STATISTICS"] or "Statistics" }
local statisticMTCache = {}

local function CopyStatisticChain(src)
    local out = {}
    if type(src) ~= "table" then return out end
    for i = 1, #src do
        local cat = src[i]
        if type(cat) == "table" then
            out[i] = { id = cat.id, name = cat.name }
        end
    end
    return out
end

local function StatisticChainKey(chain)
    local key = ""
    if type(chain) ~= "table" then return key end
    for i = 1, #chain do
        local cat = chain[i]
        key = key .. "\30" .. tostring(cat and cat.id or "") .. "\31" .. tostring(cat and cat.name or "")
    end
    return key
end



function Corpora.BuildStatisticSteps(categoryChain, statisticID, statisticName)
    local steps = {
        { buttonFrame = "AchievementMicroButton" },
        { waitForFrame = "AchievementFrame", tabIndex = 3 },
    }
    for i = 1, #categoryChain do
        local cat = categoryChain[i]
        steps[#steps + 1] = {
            waitForFrame = "AchievementFrame",
            statisticsCategory = cat.name,
            statisticsCategoryID = cat.id,
        }
    end
    steps[#steps + 1] = {
        waitForFrame = "AchievementFrame",
        statisticID = statisticID,
        statisticName = statisticName,
    }
    return steps
end

local function GetStatisticMT(path, categoryChain)
    local key = StatisticChainKey(categoryChain)
    local cached = statisticMTCache[key]
    if cached then return cached end

    local proto = {
        category      = "Statistic",
        buttonFrame   = "AchievementMicroButton",
        keywords      = STAT_KEYWORDS_EMPTY,
        keywordsLower = STAT_KEYWORDS_EMPTY,
        path          = path,
    }
    local mt = {
        __index = function(t, k)
            if k == "steps" then
                local steps = Corpora.BuildStatisticSteps(categoryChain, t.statisticID, t.name)
                rawset(t, "steps", steps)
                return steps
            end
            return proto[k]
        end,
        __index_proto = proto,
    }
    statisticMTCache[key] = mt
    return mt
end




local function BuildStatisticEntry(name, id, path, categoryChain)
    return setmetatable({
        name = name,
        nameLower = slower(name),
        statisticID = id,
    }, GetStatisticMT(path or STAT_DEFAULT_PATH, categoryChain or STAT_CHAIN_EMPTY))
end





local function NewStatisticCache()
    return { rows = {}, chains = {}, byChain = {} }
end

local function AddStatisticCacheRow(cache, id, name, path, categoryChain)
    if not cache then return end
    local chainIndex = cache.byChain[categoryChain]
    if not chainIndex then
        cache.chains[#cache.chains + 1] = {
            path = CopyArray(path),
            chain = CopyStatisticChain(categoryChain),
        }
        chainIndex = #cache.chains
        cache.byChain[categoryChain] = chainIndex
    end
    cache.rows[#cache.rows + 1] = { id = id, name = name, chain = chainIndex }
end



local STAT_ROW_SPEC = { { "id" }, { "name" }, { "chain" } }

local function PersistStatisticsCache(cache, categories)
    local db = EasyFind and EasyFind.db
    if not db or not cache then return end
    db.statisticCache = {
        version = ns.STATISTIC_CACHE_VER,
        categoryIDs = CopyArray(categories),
        chains = cache.chains,
        packed = Utils.PackRows(cache.rows, STAT_ROW_SPEC),
    }
    db.statisticCacheVer = ns.STATISTIC_CACHE_VER
end




Corpora.STAT_CORPUS_PROTO = {
    category      = "Statistic",
    buttonFrame   = "AchievementMicroButton",
    keywords      = STAT_KEYWORDS_EMPTY,
    keywordsLower = STAT_KEYWORDS_EMPTY,
}

Corpora.STAT_COMPUTED = {
    statisticID = function(stub) return stub.id end,
    path = function(stub)
        local def = Corpora.statChainsRef and Corpora.statChainsRef[stub.chain]
        return def and def.path or STAT_DEFAULT_PATH
    end,
    steps = function(stub)
        local def = Corpora.statChainsRef and Corpora.statChainsRef[stub.chain]
        return Corpora.BuildStatisticSteps(def and def.chain or STAT_CHAIN_EMPTY,
            stub.statisticID, stub.name)
    end,
}

local function HydratePersistedStatisticsCache()
    if statisticCacheHydrated then return false end
    statisticCacheHydrated = true

    local db = EasyFind and EasyFind.db
    local saved = db and db.statisticCache
    if type(saved) ~= "table" or db.statisticCacheVer ~= ns.STATISTIC_CACHE_VER then
        return false
    end
    local chains = saved.chains
    if type(saved.packed) ~= "string" or saved.packed == "" then return false end
    if type(chains) ~= "table" or #chains == 0 then return false end



    local corpus = Utils.NewPackedCorpus(saved.packed, STAT_ROW_SPEC, Corpora.STAT_CORPUS_PROTO,
        { computed = Corpora.STAT_COMPUTED, sliced = true })
    if corpus.count == 0 then return false end
    Utils.RegisterCorpus("statistics", corpus)
    Corpora.statChainsRef = chains

    RemoveEntriesByCategory("Statistic")
    wipe(Database.statisticIDs)
    Database.statisticsComplete = true
    RefreshStatisticsCategoryIDs(saved.categoryIDs)

    local inserted = 0
    corpus:EachRow(function(ri, row)
        if row.id and row.name and row.name ~= "" and chains[row.chain] then
            uiSearchData[#uiSearchData + 1] = corpus:StubAt(ri)
            MarkID(Database.statisticIDs, row.id)
            inserted = inserted + 1
        end
    end, nil, true)
    if inserted == 0 then return false end

    Database.statisticsVersion = Database.statisticsVersion + 1
    if Database.ResetSearchCache then Database:ResetSearchCache() end
    return true
end

function Database:HydrateCachedStatistics()
    local changed = HydratePersistedStatisticsCache()
    if changed and self.MarkDynamicProviderLoaded then
        self:MarkDynamicProviderLoaded("statistics")
    end
    return changed
end

function Database:PopulateDynamicStatisticsAsync(done)
    if not GetStatisticsCategoryList or not GetCategoryInfo
       or not Utils.SafeAfter then
        local ok = self:PopulateDynamicStatistics()
        done(ok)
        return
    end
    if HydratePersistedStatisticsCache() then
        done(true)
        return
    end

    RemoveEntriesByCategory("Statistic")
    wipe(Database.statisticIDs)
    Database.statisticsComplete = false
    statsScanGeneration = statsScanGeneration + 1
    local myGen = statsScanGeneration

    local categories = GetStatisticsCategoryList()
    if not categories then done(false); return end
    RefreshStatisticsCategoryIDs(categories)

    local catMap = {}
    for i = 1, #categories do
        local catID = categories[i]
        local name, parentID = GetCategoryInfo(catID)
        if name and name ~= "" then
            catMap[catID] = { id = catID, name = name, parentID = parentID, children = {} }
        end
    end

    local roots = {}
    for _, cat in pairs(catMap) do
        local parent = cat.parentID and cat.parentID ~= -1 and catMap[cat.parentID]
        if parent then
            parent.children[#parent.children + 1] = cat
        else
            roots[#roots + 1] = cat
        end
    end

    local queue = {}

    local function enqueueCategory(cat, parentChain)
        local path = { _G["ACHIEVEMENTS"] or "Achievements", _G["STATISTICS"] or "Statistics" }
        local categoryChain = {}
        for i = 1, #parentChain do
            local parent = parentChain[i]
            categoryChain[#categoryChain + 1] = { id = parent.id, name = parent.name }
            path[#path + 1] = parent.name
        end
        categoryChain[#categoryChain + 1] = { id = cat.id, name = cat.name }
        path[#path + 1] = cat.name

        if GetCategoryNumAchievements then
            local total = GetCategoryNumAchievements(cat.id) or 0
            if total == 0 and #cat.children == 0 then
                total = GetCategoryNumAchievements(cat.id, true) or 0
            end
            for i = 1, total do
                queue[#queue + 1] = {
                    catID = cat.id, rowIndex = i,
                    path = path,
                    categoryChain = categoryChain,
                }
            end
        end

        if #cat.children > 0 then
            local nextChain = {}
            for i = 1, #parentChain do nextChain[i] = parentChain[i] end
            nextChain[#nextChain + 1] = cat
            for i = 1, #cat.children do enqueueCategory(cat.children[i], nextChain) end
        end
    end
    for i = 1, #roots do enqueueCategory(roots[i], {}) end


    local seenStatisticIDs = {}
    local cache = NewStatisticCache()
    local function processRow(item)
        if not GetAchievementInfo then return end
        local id, title = GetAchievementInfo(item.catID, item.rowIndex)
        if not (id and title and title ~= "") then return end
        if HasID(seenStatisticIDs, id) then
            MarkID(Database.statisticIDs, id)
            return
        end
        MarkID(seenStatisticIDs, id)
        MarkID(Database.statisticIDs, id)
        local entry = BuildStatisticEntry(title, id, item.path, item.categoryChain)
        uiSearchData[#uiSearchData + 1] = entry
        AddStatisticCacheRow(cache, id, title, item.path, item.categoryChain)
        return true
    end


    local BUDGET_MS = 6
    local cursor = 1
    local emittedSinceRefresh = 0
    local function step()
        if myGen ~= statsScanGeneration then
            done(false, "cancelled")
            return
        end
        local startMs = debugprofilestop and debugprofilestop() or 0
        while cursor <= #queue do
            if processRow(queue[cursor]) then
                emittedSinceRefresh = emittedSinceRefresh + 1
            end
            cursor = cursor + 1
            if debugprofilestop and (debugprofilestop() - startMs) > BUDGET_MS then
                if emittedSinceRefresh > 0 and Database.SchedulePartialSearchRefresh then
                    emittedSinceRefresh = 0
                    Database:SchedulePartialSearchRefresh(150)
                end
                Utils.SafeAfter(0, step)
                return
            end
        end


        Database.statisticsComplete = true
        Database.statisticsVersion = Database.statisticsVersion + 1
        PersistStatisticsCache(cache, categories)
        if Database.RefreshDynamicCategory then
            Database:RefreshDynamicCategory("achievements")
        end
        done(true)
    end
    step()
end

function Database:PopulateDynamicStatistics()
    if not GetStatisticsCategoryList or not GetCategoryInfo then return false end
    if HydratePersistedStatisticsCache() then return true end

    RemoveEntriesByCategory("Statistic")
    wipe(Database.statisticIDs)
    Database.statisticsComplete = false
    statsScanGeneration = statsScanGeneration + 1

    local categories = GetStatisticsCategoryList()
    if not categories then return false end
    RefreshStatisticsCategoryIDs(categories)

    local catMap = {}
    for i = 1, #categories do
        local catID = categories[i]
        local name, parentID = GetCategoryInfo(catID)
        if name and name ~= "" then
            catMap[catID] = {
                id = catID, name = name, parentID = parentID, children = {},
            }
        end
    end

    local roots = {}
    for _, cat in pairs(catMap) do
        local parent = cat.parentID and cat.parentID ~= -1 and catMap[cat.parentID]
        if parent then
            parent.children[#parent.children + 1] = cat
        else
            roots[#roots + 1] = cat
        end
    end


    local seenStatisticIDs = {}
    local cache = NewStatisticCache()
    local function emit(cat, parentChain)
        local pathBase = { _G["ACHIEVEMENTS"] or "Achievements", _G["STATISTICS"] or "Statistics" }
        local categoryChain = {}
        for i = 1, #parentChain do
            local parent = parentChain[i]
            local pn = parent.name
            categoryChain[#categoryChain + 1] = { id = parent.id, name = pn }
            pathBase[#pathBase + 1] = pn
        end
        categoryChain[#categoryChain + 1] = { id = cat.id, name = cat.name }
        pathBase[#pathBase + 1] = cat.name

        if GetCategoryNumAchievements and GetAchievementInfo then
            local total = GetCategoryNumAchievements(cat.id)
            if (total or 0) == 0 and #cat.children == 0 then
                total = GetCategoryNumAchievements(cat.id, true)
            end
            for i = 1, (total or 0) do
                local id, title = GetAchievementInfo(cat.id, i)
                if id and title and title ~= "" then
                    if HasID(seenStatisticIDs, id) then
                        MarkID(Database.statisticIDs, id)
                    else
                        MarkID(seenStatisticIDs, id)
                        MarkID(Database.statisticIDs, id)
                        local entry = BuildStatisticEntry(title, id, pathBase, categoryChain)
                        uiSearchData[#uiSearchData + 1] = entry
                        AddStatisticCacheRow(cache, id, title, pathBase, categoryChain)
                    end
                end
            end
        end

        if #cat.children > 0 then
            local nextChain = {}
            for i = 1, #parentChain do nextChain[i] = parentChain[i] end
            nextChain[#nextChain + 1] = cat
            for i = 1, #cat.children do emit(cat.children[i], nextChain) end
        end
    end

    for i = 1, #roots do emit(roots[i], {}) end
    Database.statisticsComplete = true
    Database.statisticsVersion = Database.statisticsVersion + 1
    PersistStatisticsCache(cache, categories)
    return true
end








local flattenMTCache = {}
local function GetFlattenMT(category, buttonFrame, path, steps, keywords)
    local key = (category or "") .. "\31"
             .. (buttonFrame or "") .. "\31"
             .. tostring(path) .. "\31"
             .. tostring(steps) .. "\31"
             .. tostring(keywords)
    local cached = flattenMTCache[key]
    if cached then return cached end
    local proto = {
        category    = category,
        buttonFrame = buttonFrame,
        path        = path,
        steps       = steps,
        keywords    = keywords,
    }
    local mt = { __index = proto }
    flattenMTCache[key] = mt
    return mt
end

function Database:FlattenTree(tree, parentPath, parentSteps, parentButtonFrame, parentCategory, parentIsPvP, parentIsPvE)
    parentPath = parentPath or {}
    parentSteps = parentSteps or {}

    for _, node in ipairs(tree) do
        local myButtonFrame = node.buttonFrame or parentButtonFrame
        local myCategory = node.category or parentCategory





        local myIsPvP = node.isPvP or parentIsPvP or nil
        local myIsPvE = node.isPvE or parentIsPvE or nil


        local mySteps
        if node.steps then
            mySteps = {}
            for _, s in ipairs(parentSteps) do mySteps[#mySteps + 1] = s end
            for _, s in ipairs(node.steps) do mySteps[#mySteps + 1] = s end
        else
            mySteps = parentSteps
        end

        local myKeywords = node.keywords or EMPTY_KEYWORDS
        local mt = GetFlattenMT(myCategory, myButtonFrame, parentPath, mySteps, myKeywords)
        local entry = setmetatable({ name = node.name }, mt)
        if node.icon then entry.icon = node.icon end




        if node.iconAtlas then entry.iconAtlas = node.iconAtlas end
        if node.available then entry.available = node.available end
        if node.caps then entry.caps = node.caps end
        if node.canQueue then entry.canQueue = true end
        if node.slashCommand then entry.slashCommand = node.slashCommand end
        if myIsPvP then entry.isPvP = true end
        if myIsPvE then entry.isPvE = true end

        uiSearchData[#uiSearchData + 1] = entry

        if node.children then
            local childPath = {}
            for i = 1, #parentPath do childPath[i] = parentPath[i] end
            childPath[#childPath + 1] = node.name
            self:FlattenTree(node.children, childPath, mySteps, myButtonFrame, myCategory, myIsPvP, myIsPvE)
        end
    end
end

local GROUP_FINDER_SUBCATEGORY_ICONS = {
    dungeonFinder = { icon = 133076, frame = "GroupFinderFrameGroupButton1" },
    raidFinder = { icon = 341547, frame = "GroupFinderFrameGroupButton2" },
    premadeGroups = { icon = 464820, frame = "GroupFinderFrameGroupButton3" },
    pvpQuickMatch = { icon = 236396, frame = "PVPQueueFrame.CategoryButton1" },
    pvpRated = { icon = 236368, frame = "PVPQueueFrame.CategoryButton2" },
    pvpPremade = { icon = 464820, frame = "PVPQueueFrame.CategoryButton3" },
    pvpTraining = { icon = 236179, frame = "PVPQueueFrame.CategoryButton4" },
}


local function EntryIsUnderGroupFinder(item)
    local bf = item and item.buttonFrame
    if bf == "LFDMicroButton" or bf == "LFGMicroButton" then return true end
    local steps = item and item.steps
    if not steps then return false end
    for i = 1, #steps do
        bf = steps[i] and steps[i].buttonFrame
        if bf == "LFDMicroButton" or bf == "LFGMicroButton" then return true end
    end
    return false
end

local function GetGroupFinderSubcategoryIcon(item)
    local steps = item and item.steps
    if not steps then return nil end
    for i = 1, #steps do
        local step = steps[i]
        if step then
            if step.pvpSideTabIndex == 1 then return GROUP_FINDER_SUBCATEGORY_ICONS.pvpQuickMatch end
            if step.pvpSideTabIndex == 2 then return GROUP_FINDER_SUBCATEGORY_ICONS.pvpRated end
            if step.pvpSideTabIndex == 3 then return GROUP_FINDER_SUBCATEGORY_ICONS.pvpPremade end
            if step.pvpSideTabIndex == 4 then return GROUP_FINDER_SUBCATEGORY_ICONS.pvpTraining end
            if step.sideTabIndex == 1 then return GROUP_FINDER_SUBCATEGORY_ICONS.dungeonFinder end
            if step.sideTabIndex == 2 then return GROUP_FINDER_SUBCATEGORY_ICONS.raidFinder end
            if step.sideTabIndex == 3 then return GROUP_FINDER_SUBCATEGORY_ICONS.premadeGroups end
        end
    end
    return nil
end

local function ApplyGroupFinderSubcategoryIcon(item)
    if item.specificIcon or item.specificIconFrame or not EntryIsUnderGroupFinder(item) then return end
    local iconDef = GetGroupFinderSubcategoryIcon(item)
    if iconDef then
        item.specificIcon = iconDef.icon
        item.specificIconFrame = iconDef.frame
    end
end

function Database:BuildUIDatabase()



    local uiTree = {

        {
            name = _G["CHARACTER_BUTTON"] or "Character Info",
            keywords = {"character", "char", "attributes"},
            category = "Menu Bar",
            buttonFrame = "CharacterMicroButton",
            steps = {{ buttonFrame = "CharacterMicroButton" }},
            children = {
                {
                    name = _G["PAPERDOLL_SIDEBAR_STATS"] or "Character Stats",
                    keywords = {"character stats", "character sheet", "paperdoll", "equipment", "gear stats", "item level"},
                    category = "Character Info",
                    steps = {
                        { waitForFrame = "CharacterFrame", tabIndex = 1 },
                        { waitForFrame = "CharacterFrame", sidebarButtonFrame = "CharacterFrameTab1", sidebarIndex = 1 },
                    },
                },
                {
                    name = _G["PAPERDOLL_SIDEBAR_TITLES"] or "Titles",
                    keywords = {"titles", "title", "name title"},
                    category = "Character Info",
                    steps = {
                        { waitForFrame = "CharacterFrame", tabIndex = 1 },
                        { waitForFrame = "CharacterFrame", sidebarButtonFrame = "CharacterFrameTab1", sidebarIndex = 2 },
                    },
                },
                {
                    name = _G["EQUIPMENT_MANAGER"] or "Equipment Manager",
                    keywords = {"equipment manager", "gear sets", "equipment sets", "outfitter", "save gear", "load gear", "gear manager"},
                    category = "Character Info",
                    steps = {
                        { waitForFrame = "CharacterFrame", tabIndex = 1 },
                        { waitForFrame = "CharacterFrame", sidebarButtonFrame = "CharacterFrameTab1", sidebarIndex = 3 },
                    },
                },
                {
                    name = _G["REPUTATION"] or "Reputation",
                    keywords = {"reputation", "rep", "faction", "factions", "standing", "renown"},
                    category = "Character Info",
                    steps = {
                        { waitForFrame = "CharacterFrame", tabIndex = 2 },
                    },
                },
                {
                    name = _G["CURRENCY"] or "Currency",
                    keywords = {"currency", "currencies", "tokens", "money"},
                    category = "Character Info",
                    steps = {
                        { waitForFrame = "CharacterFrame", tabIndex = 3 },
                    },
                },


                {
                    name = _G["SKILLS"] or "Skills",
                    keywords = {"skills", "weapon skills", "armor proficiencies", "languages", "defense", "skill"},
                    category = "Character Info",
                    steps = {
                        { waitForFrame = "CharacterFrame", tabFrame = "SkillsFrame" },
                    },
                },
                {
                    name = _G["PET"] or "Pet",
                    keywords = {"pet", "pet tab", "pet stats", "pet happiness", "pet training"},
                    category = "Character Info",

                    available = function() local hasPet = _G["HasPetUI"]; return hasPet and hasPet() or false end,
                    steps = {
                        { waitForFrame = "CharacterFrame", tabFrame = "PetPaperDollFrame" },
                    },
                },
                {
                    name = ns.Caps.era and _G["HONOR"] or _G["PVP"] or "PvP",
                    keywords = {"pvp", "honor", "rank", "player vs player", "battlegrounds"},
                    category = "Character Info",
                    steps = {
                        { waitForFrame = "CharacterFrame", tabFrame = "PVPRankFrame" },
                    },
                },
                {
                    name = _G["STATISTICS"] or "Statistics",
                    keywords = {"statistics", "stats", "records", "kills", "deaths"},
                    category = "Character Info",
                    steps = {
                        { waitForFrame = "CharacterFrame", tabFrame = "StatisticsFrame" },
                    },
                },
            },
        },

        {
            name = _G["TRADE_SKILLS"] or _G["PROFESSIONS_BUTTON"] or "Professions",
            keywords = {"professions", "profession", "crafting", "trade skills", "skills"},
            category = "Menu Bar",
            buttonFrame = "ProfessionMicroButton",
            steps = {{ buttonFrame = "ProfessionMicroButton" }},
        },



        {
            name = _G["SPELLBOOK"] or "Spellbook",
            keywords = {"spellbook", "spell book", "spells", "abilities"},
            category = "Menu Bar",
            caps = "classic",
            buttonFrame = "SpellbookMicroButton",
            steps = {{ buttonFrame = "SpellbookMicroButton" }},
        },

        {
            name = _G["TALENTS"] or "Talents",
            keywords = {"talents", "talent", "talent tree", "talent points"},
            category = "Menu Bar",
            caps = "classic",
            buttonFrame = "TalentMicroButton",
            steps = {{ buttonFrame = "TalentMicroButton" }},


            children = {
                { name = _G["SPECIALIZATION"] or "Specialization", keywords = {"specialization", "spec", "change spec"}, category = "Talents", caps = "mists", steps = {{ waitForFrame = "PlayerTalentFrame", tabIndex = 1 }} },
                { name = _G["TALENTS"] or "Talents", keywords = {"talents", "talent tiers"}, category = "Talents", caps = "mists", steps = {{ waitForFrame = "PlayerTalentFrame", tabIndex = 2 }} },
                { name = _G["GLYPHS"] or "Glyphs", keywords = {"glyphs", "glyph", "major glyph", "minor glyph"}, category = "Talents", caps = "mists", steps = {{ waitForFrame = "PlayerTalentFrame", tabIndex = 3 }} },
                { name = _G["PET_SPECIALIZATION"] or "Pet Specialization", keywords = {"pet specialization", "pet spec", "hunter pet"}, category = "Talents", caps = "mists", steps = {{ waitForFrame = "PlayerTalentFrame", tabIndex = 4 }} },
            },
        },

        {
            name = _G["WORLDMAP_BUTTON"] or _G["WORLD_MAP"] or "World Map",
            keywords = {"map", "world map", "worldmap"},
            category = "Menu Bar",
            caps = "classic",
            buttonFrame = "WorldMapMicroButton",
            steps = {{ buttonFrame = "WorldMapMicroButton" }},
        },


        {
            name = _G["SOCIAL_BUTTON"] or "Social",
            keywords = {"social", "friends", "friend list", "who", "guild", "raid"},
            category = "Menu Bar",
            caps = "classic",
            buttonFrame = "SocialsMicroButton",
            steps = {{ buttonFrame = "SocialsMicroButton" }},
            children = {
                { name = _G["FRIENDS"] or "Friends", keywords = {"friends", "friend list", "friends list", "add friend"}, category = "Social", steps = {{ waitForFrame = "FriendsFrame", tabIndex = 1 }} },
                { name = _G["WHO"] or "Who", keywords = {"who", "who list", "player search", "find player"}, category = "Social", steps = {{ waitForFrame = "FriendsFrame", tabIndex = 2 }} },
                { name = _G["GUILD"] or "Guild", keywords = {"guild", "guild roster", "guild members"}, category = "Social", steps = {{ waitForFrame = "FriendsFrame", tabIndex = 3 }} },
                { name = _G["RAID"] or "Raid", keywords = {"raid", "raid group", "raid info", "raid roster"}, category = "Social", steps = {{ waitForFrame = "FriendsFrame", tabIndex = 4 }} },
            },
        },



        {
            name = _G["LFG_BUTTON"] or "Looking For Group",
            keywords = {"lfg", "lfm", "looking for group", "group finder", "find group", "group browser"},
            category = "Menu Bar",
            caps = "lfgWindow",
            buttonFrame = "LFGMinimapFrame",
            steps = {{ buttonFrame = "LFGMinimapFrame" }},
            children = {
                {
                    name = _G["LFG_LIST_TAB_1"] or "Create Listing",
                    keywords = {"create listing", "list yourself", "list group", "advertise group", "lfg listing"},
                    category = "Group Finder",
                    steps = {{ waitForFrame = "LFGParentFrame", tabIndex = 1 }},
                },
                {
                    name = _G["LFG_LIST_TAB_2"] or "Browse Groups",
                    keywords = {"browse groups", "group browser", "search groups", "find group", "lfm"},
                    category = "Group Finder",
                    steps = {{ waitForFrame = "LFGParentFrame", tabIndex = 2 }},
                },
            },
        },

        {
            name = _G["PLAYERSPELLS_BUTTON"] or "Talents & Spellbook",
            keywords = {"talents and spellbook", "class abilities"},
            category = "Menu Bar",
            buttonFrame = "PlayerSpellsMicroButton",
            steps = {{ buttonFrame = "PlayerSpellsMicroButton" }},
            children = {
                {
                    name = _G["SPECIALIZATION"] or "Specialization",
                    keywords = {"specialization", "spec", "class spec", "change spec", "switch spec"},
                    category = "Talents",
                    steps = {{ waitForFrame = "PlayerSpellsFrame", tabIndex = 1 }},
                },
                {
                    name = _G["TALENTS"] or "Talents",
                    keywords = {"talent tree", "talent points", "class talents", "hero talents", "talents"},
                    category = "Talents",
                    steps = {{ waitForFrame = "PlayerSpellsFrame", tabIndex = 2 }},
                    children = {
                        {
                            name = _G["PVP_TALENTS"] or "PvP Talents",
                            isPvP = true,
                            keywords = {"pvp talents", "pvp abilities", "battleground talents", "pvp"},
                            steps = {{ waitForFrame = "PlayerSpellsFrame", regionFrames = { "PlayerSpellsFrame.TalentsFrame.PvPTalentSlotTray" } }},
                        },
                        {
                            name = _G["PVP_LABEL_WAR_MODE"] or "War Mode",
                            isPvP = true,
                            keywords = {"war mode", "warmode", "pvp toggle", "world pvp", "pvp on", "pvp off", "pvp"},
                            steps = {{ waitForFrame = "PlayerSpellsFrame", regionFrames = { "PlayerSpellsFrame.TalentsFrame.WarmodeButton" } }},
                        },
                    },
                },
                {
                    name = _G["SPELLBOOK"] or "Spellbook",
                    keywords = {"spellbook", "spells", "abilities", "skills", "spell book"},
                    category = "Menu Bar",
                    steps = {{ waitForFrame = "PlayerSpellsFrame", tabIndex = 3 }},
                },
            },
        },

        {
            name = _G["ACHIEVEMENTS"] or "Achievements",
            keywords = {"achievement", "achievements", "achieve", "points"},
            category = "Menu Bar",
            buttonFrame = "AchievementMicroButton",
            steps = {{ buttonFrame = "AchievementMicroButton" }},
            children = {
                {
                    name = _G["STATISTICS"] or "Statistics",
                    keywords = {"statistics", "stats tab", "player statistics"},
                    category = "Statistics",
                    steps = {{ waitForFrame = "AchievementFrame", tabIndex = 3 }},
                },
            },
        },

        {
            name = _G["QUESTLOG_BUTTON"] or _G["QUEST_LOG"] or "Quest Log",
            keywords = {"quest", "quests", "objectives", "log", "journal"},
            category = "Menu Bar",
            buttonFrame = "QuestLogMicroButton",
            steps = {{ buttonFrame = "QuestLogMicroButton" }},
        },

        {
            name = _G["HOUSING_DASHBOARD_FRAMETITLE"] or _G["HOUSING_MICRO_BUTTON"] or "Housing Dashboard",
            keywords = {"housing", "house", "home", "dashboard", "player housing"},
            category = "Menu Bar",
            buttonFrame = "HousingMicroButton",
            steps = {{ buttonFrame = "HousingMicroButton" }},
        },

        {
            name = _G["GUILD_AND_COMMUNITIES"] or "Guild & Communities",
            keywords = {"guild", "communities", "social", "clan"},
            category = "Menu Bar",
            buttonFrame = "GuildMicroButton",
            steps = {{ buttonFrame = "GuildMicroButton" }},
        },



        {
            name = _G["GROUP_FINDER"] or "Group Finder",
            keywords = {"lfg", "lfd", "lfr", "finder", "queue", "group finder", "dungeon finder"},
            category = "Menu Bar",
            caps = "mists",
            buttonFrame = "LFGMicroButton",
            steps = {{ buttonFrame = "LFGMicroButton" }},
            children = {
                { name = _G["LOOKING_FOR_DUNGEON_PVEFRAME"] or _G["LOOKING_FOR_DUNGEON"] or "Dungeon Finder", isPvE = true, keywords = {"dungeon finder", "lfd", "random dungeon", "heroic dungeon", "dungeon queue"}, category = "Group Finder", steps = {{ waitForFrame = "PVEFrame", tabIndex = 1 }, { waitForFrame = "PVEFrame", sideTabIndex = 1 }} },
                { name = _G["RAID_FINDER_PVEFRAME"] or _G["RAID_FINDER"] or "Raid Finder", isPvE = true, keywords = {"raid finder", "lfr", "looking for raid", "raid queue"}, category = "Group Finder", steps = {{ waitForFrame = "PVEFrame", tabIndex = 1 }, { waitForFrame = "PVEFrame", sideTabIndex = 2 }} },
                { name = _G["LFGLIST_NAME"] or "Premade Groups", isPvE = true, keywords = {"premade", "premade groups", "group browser", "find group", "lfm"}, category = "Group Finder", steps = {{ waitForFrame = "PVEFrame", tabIndex = 1 }, { waitForFrame = "PVEFrame", sideTabIndex = 3 }} },
                { name = _G["SCENARIOS_PVEFRAME"] or _G["SCENARIOS"] or "Scenarios", isPvE = true, keywords = {"scenario", "scenarios", "scenario queue"}, category = "Group Finder", steps = {{ waitForFrame = "PVEFrame", tabIndex = 1 }, { waitForFrame = "PVEFrame", sideTabIndex = 4 }} },
                {
                    name = _G["PLAYER_V_PLAYER"] or _G["PVP"] or "Player vs. Player",
                    isPvP = true,
                    keywords = {"pvp", "player vs player", "battleground", "arena", "bg"},
                    category = "Group Finder",
                    steps = {{ waitForFrame = "PVEFrame", tabIndex = 2 }},
                    children = {
                        { name = _G["PVP_TAB_HONOR"] or "Honor", keywords = {"honor", "random bg", "random battleground", "battleground", "skirmish"}, category = "PvP", steps = {{ waitForFrame = "PVEFrame", pvpSideTabIndex = 1 }} },
                        { name = _G["PVP_TAB_CONQUEST"] or "Conquest", keywords = {"conquest", "rated", "arena", "rated battleground", "2v2", "3v3", "5v5"}, category = "PvP", steps = {{ waitForFrame = "PVEFrame", pvpSideTabIndex = 2 }} },
                        { name = _G["WARGAMES"] or "War Games", keywords = {"war games", "wargame", "wargames"}, category = "PvP", steps = {{ waitForFrame = "PVEFrame", pvpSideTabIndex = 3 }} },
                        { name = (_G["LFGLIST_NAME"] or "Premade Groups") .. L["UITREE_SUFFIX_PVP_GROUP"], keywords = {"pvp premade", "arena group", "bg premade", "premade"}, category = "PvP", steps = {{ waitForFrame = "PVEFrame", pvpSideTabIndex = 4 }} },
                    },
                },
                { name = _G["CHALLENGES"] or "Challenges", keywords = {"challenges", "challenge mode", "challenge modes"}, category = "Group Finder", steps = {{ waitForFrame = "PVEFrame", tabIndex = 3 }} },
            },
        },

        {
            name = _G["LFG_TITLE"] or _G["GROUP_FINDER"] or "Group Finder",
            keywords = {"lfg", "lfd", "lfr", "finder", "queue", "group finder"},
            category = "Menu Bar",
            buttonFrame = "LFDMicroButton",
            steps = {{ buttonFrame = "LFDMicroButton" }},
            children = {
                {
                    name = _G["GROUP_FINDER"] or "Dungeons & Raids",
                    isPvE = true,
                    keywords = {"dungeons", "raids", "dungeons and raids"},
                    category = "Group Finder",
                    steps = {{ waitForFrame = "PVEFrame", tabIndex = 1 }},
                    children = {
                        { name = _G["LOOKING_FOR_DUNGEON"] or "Dungeon Finder", keywords = {"dungeon finder", "lfd", "random dungeon", "heroic dungeon", "normal dungeon", "dungeon queue"}, canQueue = true, steps = {{ waitForFrame = "PVEFrame", sideTabIndex = 1 }} },
                        { name = _G["RAID_FINDER"] or _G["LOOKING_FOR_RAID"] or "Raid Finder", keywords = {"raid finder", "lfr", "looking for raid", "raid queue", "random raid"}, canQueue = true, steps = {{ waitForFrame = "PVEFrame", sideTabIndex = 2 }} },
                        { name = (_G["GUILD_INTEREST_QUEST"] or "Questing") .. L["UITREE_SUFFIX_PREMADE"], keywords = {"questing", "quest", "quest group", "quest lfg", "find quest group", "premade questing", "premade"}, steps = {{ waitForFrame = "PVEFrame", sideTabIndex = 3 }, { waitForFrame = "PVEFrame", lfgCategoryID = 1 }} },
                        { name = (_G["DELVES_LABEL"] or "Delves") .. L["UITREE_SUFFIX_PREMADE"], keywords = {"delves", "delve group", "delve lfg", "find delve group", "premade delves", "delve", "premade"}, steps = {{ waitForFrame = "PVEFrame", sideTabIndex = 3 }, { waitForFrame = "PVEFrame", lfgCategoryID = 121 }} },
                        { name = (_G["DUNGEONS"] or "Dungeons") .. L["UITREE_SUFFIX_PREMADE"], keywords = {"dungeons", "dungeon group", "dungeon lfg", "find dungeon group", "premade dungeons", "m+ group", "mythic group", "premade"}, steps = {{ waitForFrame = "PVEFrame", sideTabIndex = 3 }, { waitForFrame = "PVEFrame", lfgCategoryID = 2 }} },
                        { name = (_G["RAIDS"] or "Raids") .. " - " .. (_G["EXPANSION_NAME10"] or "The War Within") .. L["UITREE_SUFFIX_PREMADE"], keywords = {"raids", "raids the war within", "raid group", "raid lfg", "find raid group", "premade raids", "tww raid", "war within raid", "nerub-ar", "liberation of undermine", "premade"}, steps = {{ waitForFrame = "PVEFrame", sideTabIndex = 3 }, { waitForFrame = "PVEFrame", lfgCategoryID = 3, lfgFilters = (Enum and Enum.LFGListFilter and Enum.LFGListFilter.Recommended) or 0x1 }} },
                        { name = (_G["RAIDS"] or "Raids") .. " - " .. L["UITREE_LEGACY"] .. L["UITREE_SUFFIX_PREMADE"], keywords = {"raids", "raids legacy", "legacy raid", "old raid", "legacy raid group", "legacy lfg", "transmog raid", "tmog raid", "mount run", "premade"}, steps = {{ waitForFrame = "PVEFrame", sideTabIndex = 3 }, { waitForFrame = "PVEFrame", lfgCategoryID = 3, lfgFilters = (Enum and Enum.LFGListFilter and Enum.LFGListFilter.NotRecommended) or 0x2 }} },
                        { name = (_G["CUSTOM"] or "Custom") .. L["UITREE_SUFFIX_PVE_GROUP"], keywords = {"custom", "custom pve", "custom group", "custom lfg", "pve custom", "premade"}, steps = {{ waitForFrame = "PVEFrame", sideTabIndex = 3 }, { waitForFrame = "PVEFrame", lfgCategoryID = 6 }} },
                    },
                },

                {
                    name = _G["PVP"] or _G["PLAYER_V_PLAYER"] or "Player vs. Player",
                    isPvP = true,
                    keywords = {"pvp", "player vs player", "battleground", "arena", "bg"},
                    category = "Group Finder",
                    steps = {{ waitForFrame = "PVEFrame", tabIndex = 2 }},
                    children = {
                        {
                            name = _G["PVP_TAB_HONOR"] or "Quick Match",
                            keywords = {"quick match", "random bg", "random battleground", "casual pvp", "unrated", "pvp"},
                            steps = {{ waitForFrame = "PVEFrame", pvpSideTabIndex = 1 }},
                            children = {
                                { name = _G["SKIRMISH"] or "Arena Skirmish", keywords = {"arena skirmish", "skirmish", "unrated arena", "casual arena", "arena"}, category = "PvP", canQueue = true, steps = {{ waitForFrame = "PVEFrame", regionFrames = {"HonorFrame.BonusFrame.Arena1Button", "HonorFrame.ArenaSkirmish"}, searchButtonText = "Arena Skirmish" }} },
                                { name = _G["RANDOM_BATTLEGROUND"] or "Random Battleground", keywords = {"random bg", "random battleground", "casual bg", "unrated bg", "battleground"}, category = "PvP", canQueue = true, steps = {{ waitForFrame = "PVEFrame", regionFrames = {"HonorFrame.BonusFrame.RandomBGButton", "HonorFrame.RandomBG"}, searchButtonText = "Random Battlegrounds" }} },
                                { name = _G["RANDOM_EPIC_BATTLEGROUND"] or "Random Epic Battleground", keywords = {"random epic bg", "random epic battleground", "epic bg", "epic battleground", "ashran", "alterac", "isle of conquest"}, category = "PvP", canQueue = true, steps = {{ waitForFrame = "PVEFrame", regionFrames = {"HonorFrame.BonusFrame.RandomEpicBGButton", "HonorFrame.RandomEpicBG"}, searchButtonText = "Random Epic Battlegrounds" }} },
                                { name = _G["LFG_CATEGORY_BATTLEFIELD"] or "Brawl", keywords = {"brawl", "pvp brawl", "weekly brawl", "packed house"}, category = "PvP", canQueue = true, steps = {{ waitForFrame = "PVEFrame", regionFrames = {"HonorFrame.BonusFrame.BrawlButton"}, searchButtonText = "Brawl" }} },
                            },
                        },
                        {
                            name = _G["PVP_TAB_CONQUEST"] or "Rated",
                            keywords = {"rated", "rated pvp", "conquest", "pvp"},
                            steps = {{ waitForFrame = "PVEFrame", pvpSideTabIndex = 2 }},
                            children = {
                                { name = _G["PVP_RATED_SOLO_SHUFFLE"] or "Solo Shuffle", keywords = {"solo shuffle", "shuffle", "solo arena", "arena"}, category = "PvP", canQueue = true, steps = {{ waitForFrame = "PVEFrame", regionFrames = {"ConquestFrame.RatedSoloShuffle"}, searchButtonText = "Solo Arena" }} },
                                { name = _G["CONQUEST_BRACKET_NAME_2V2"] or _G["PVP_BRACKET_1"] or "2v2 Arena", keywords = {"2v2", "2s", "twos", "2v2 arena", "two vs two", "arena"}, category = "PvP", canQueue = true, steps = {{ waitForFrame = "PVEFrame", regionFrames = {"ConquestFrame.Arena2v2"}, searchButtonText = "2v2" }} },
                                { name = _G["PVP_BRACKET_2"] or "3v3 Arena", keywords = {"3v3", "3s", "threes", "3v3 arena", "three vs three", "arena"}, category = "PvP", canQueue = true, steps = {{ waitForFrame = "PVEFrame", regionFrames = {"ConquestFrame.Arena3v3"}, searchButtonText = "3v3" }} },
                                { name = _G["PVP_RATED_BATTLEGROUNDS"] or "Rated Battlegrounds", keywords = {"rbg", "rated bg", "rated battleground", "rated battlegrounds", "10v10", "ten vs ten"}, category = "PvP", canQueue = true, steps = {{ waitForFrame = "PVEFrame", regionFrames = {"ConquestFrame.RatedBG"} }} },
                                { name = L["UITREE_SOLO_BATTLEGROUNDS"] .. L["UITREE_SUFFIX_BLITZ"], keywords = {"solo bg", "solo battleground", "solo battlegrounds", "battleground", "blitz", "battleground blitz"}, category = "PvP", canQueue = true, steps = {{ waitForFrame = "PVEFrame", regionFrames = {"ConquestFrame.RatedBGBlitz"}, searchButtonText = "Solo Battlegrounds" }} },
                            },
                        },
                        { name = L["UITREE_ARENAS"] .. L["UITREE_SUFFIX_PREMADE"], keywords = {"arena premade", "arena group", "arena lfg", "find arena", "arena", "premade"}, category = "PvP", steps = {{ waitForFrame = "PVEFrame", pvpSideTabIndex = 3 }, { waitForFrame = "PVEFrame", lfgCategoryID = 4 }} },
                        { name = (_G["SKIRMISH"] or "Arena Skirmish") .. L["UITREE_SUFFIX_PREMADE"], keywords = {"arena skirmish premade", "skirmish group", "skirmish lfg", "skirmish", "premade"}, category = "PvP", steps = {{ waitForFrame = "PVEFrame", pvpSideTabIndex = 3 }, { waitForFrame = "PVEFrame", lfgCategoryID = 7 }} },
                        { name = (_G["BATTLEGROUNDS"] or "Battlegrounds") .. L["UITREE_SUFFIX_PREMADE"], keywords = {"bg premade", "battleground group", "bg lfg", "find bg", "battleground", "premade"}, category = "PvP", steps = {{ waitForFrame = "PVEFrame", pvpSideTabIndex = 3 }, { waitForFrame = "PVEFrame", lfgCategoryID = 8 }} },
                        { name = (_G["PVP_RATED_BATTLEGROUNDS"] or "Rated Battlegrounds") .. L["UITREE_SUFFIX_PREMADE"], keywords = {"rated bg premade", "rbg premade", "rbg group", "rbg lfg", "rated battleground", "premade"}, category = "PvP", steps = {{ waitForFrame = "PVEFrame", pvpSideTabIndex = 3 }, { waitForFrame = "PVEFrame", lfgCategoryID = 9 }} },
                        { name = (_G["CUSTOM"] or "Custom") .. L["UITREE_SUFFIX_PVP_GROUP"], keywords = {"custom pvp", "custom group", "custom lfg", "pvp custom", "custom", "premade"}, category = "PvP", steps = {{ waitForFrame = "PVEFrame", pvpSideTabIndex = 3 }, { waitForFrame = "PVEFrame", lfgCategoryID = 6 }} },
                        {
                            name = _G["PVP_TAB_TRAINING_GROUNDS"] or "Training Grounds",
                            keywords = {"training", "training grounds", "practice", "pvp"},
                            steps = {{ waitForFrame = "PVEFrame", pvpSideTabIndex = 4 }},
                            children = {
                                { name = L["UITREE_RANDOM_BATTLEGROUNDS"] .. L["UITREE_SUFFIX_TRAINING_GROUNDS"], keywords = {"random bg", "random battleground", "random battlegrounds", "training battleground", "bonus battleground"}, category = "PvP", steps = {{ waitForFrame = "PVEFrame", regionFrames = {"TrainingGroundsFrame.BonusTrainingGroundList.RandomTrainingGroundButton"}, searchButtonText = "Random Battlegrounds" }} },
                            },
                        },
                    },
                },

                {
                    name = _G["CHALLENGES"] or "Mythic+ Dungeons",
                    isPvE = true,
                    keywords = {"mythic", "mythic+", "m+", "keystone", "mythic plus", "keys"},
                    category = "Group Finder",
                    steps = {{ waitForFrame = "PVEFrame", tabIndex = 3 }},
                },
            },
        },

        {
            name = _G["COLLECTIONS"] or "Warband Collections",
            keywords = {"collections", "warband"},
            category = "Menu Bar",
            buttonFrame = "CollectionsMicroButton",
            steps = {{ buttonFrame = "CollectionsMicroButton" }},
            children = {
                { name = _G["MOUNTS"] or "Mounts", keywords = {"mounts", "mount", "riding", "mount collection", "flying"}, category = "Warband Collections", caps = "mounts", steps = {{ waitForFrame = "CollectionsJournal", tabIndex = 1 }} },
                { name = _G["PET_JOURNAL"] or _G["PETS"] or "Pet Journal", keywords = {"pets", "pet", "battle pets", "companion", "pet collection", "critter", "pet journal"}, category = "Warband Collections", caps = "pets", steps = {{ waitForFrame = "CollectionsJournal", tabIndex = 2 }} },
                { name = _G["TOY_BOX"] or "Toy Box", keywords = {"toys", "toy", "toybox", "toy box", "fun items"}, category = "Warband Collections", caps = "toys", steps = {{ waitForFrame = "CollectionsJournal", tabIndex = 3 }} },
                { name = _G["HEIRLOOMS"] or "Heirlooms", keywords = {"heirlooms", "heirloom", "leveling gear", "bind on account", "boa"}, category = "Warband Collections", caps = "heirlooms", steps = {{ waitForFrame = "CollectionsJournal", tabIndex = 4 }} },
                { name = _G["WARDROBE"] or "Appearances", keywords = {"transmog", "tmog", "xmog", "transmogrification", "appearance", "appearances", "wardrobe", "cosmetic", "looks", "mog"}, category = "Warband Collections", steps = {{ waitForFrame = "CollectionsJournal", tabIndex = 5 }} },
                { name = _G["WARBAND_SCENES"] or "Campsites", keywords = {"campsites", "campsite", "camp", "camping", "rest area"}, category = "Warband Collections", caps = "campsites", steps = {{ waitForFrame = "CollectionsJournal", tabIndex = 6 }} },
            },
        },

        {
            name = _G["TRANSMOGRIFICATION"] or "Transmogrification",
            keywords = {"transmogrification", "transmog", "tmog", "xmog", "mog", "wardrobe", "appearance"},
            category = "Transmogrification",
            caps = "transmog",
            icon = { file = ns.ART.transmog.tex, coords = ns.ART.transmog.coords },
            steps = {{ loadTransmog = true }},
        },

        {
            name = _G["ADVENTURE_JOURNAL"] or "Adventure Guide",
            keywords = {"adventure", "guide", "dungeon journal", "encounters", "loot", "boss", "journal"},
            category = "Menu Bar",
            buttonFrame = "EJMicroButton",
            steps = {{ buttonFrame = "EJMicroButton" }},
            children = {
                { name = _G["JOURNEYS_LABEL"] or "Journeys", keywords = {"journeys", "journey", "adventure journeys"}, category = "Adventure Guide", caps = "journalTabs", steps = {{ waitForFrame = "EncounterJournal", tabIndex = 1 }}, children = {
                    { name = L["UITREE_GREAT_VAULT"] .. L["UITREE_SUFFIX_REWARDS"], keywords = {"great vault", "vault", "weekly rewards", "weekly chest", "rewards"}, category = "Adventure Guide", icon = { file = ns.ART.great_vault.tex, coords = ns.ART.great_vault.coords }, steps = {{ buttonFrame = "EncounterJournalInstanceSelect.GreatVaultButton" }} },
                }},
                { name = _G["MONTHLY_ACTIVITIES_TAB"] or "Traveler's Log", keywords = {"traveler", "travelers log", "traveler log", "travel log"}, category = "Adventure Guide", caps = "journalTabs", steps = {{ waitForFrame = "EncounterJournal", tabIndex = 2 }} },
                { name = _G["AJ_SUGGESTED_CONTENT_TAB"] or "Suggested Content", keywords = {"suggested", "suggested content", "recommendations"}, category = "Adventure Guide", caps = "journalTabs", steps = {{ waitForFrame = "EncounterJournal", tabIndex = 3 }} },
                { name = (_G["DUNGEONS"] or "Dungeons") .. L["UITREE_SUFFIX_JOURNAL"], keywords = {"dungeon journal", "dungeon guide", "dungeon encounters", "dungeon bosses"}, category = "Adventure Guide", caps = "journal", steps = {{ waitForFrame = "EncounterJournal", tabIndex = 4 }} },
                { name = (_G["RAIDS"] or "Raids") .. L["UITREE_SUFFIX_JOURNAL"], keywords = {"raid journal", "raid guide", "raid encounters", "raid bosses"}, category = "Adventure Guide", caps = "journal", steps = {{ waitForFrame = "EncounterJournal", tabIndex = 5 }} },
                { name = _G["LOOT_JOURNAL_ITEM_SETS"] or "Item Sets", keywords = {"item sets", "tier sets", "set bonuses", "class sets"}, category = "Adventure Guide", caps = "journalTabs", steps = {{ waitForFrame = "EncounterJournal", tabIndex = 6 }} },
                { name = _G["EJ_TUTORIALS"] or "Tutorials", keywords = {"tutorials", "tutorial", "help guide", "how to"}, category = "Adventure Guide", caps = "journalTabs", steps = {{ waitForFrame = "EncounterJournal", tabIndex = 7 }} },
            },
        },




        {
            name = _G["MAINMENU_BUTTON"] or "Game Menu",


            keywords = {"menu", "escape", "esc", "logout", "quit", "exit", "interface"},
            category = "Menu Bar",
            buttonFrame = "MainMenuMicroButton",
            slashCommand = "/click MainMenuMicroButton",
            children = {
                {
                    name = _G["GAMEMENU_OPTIONS"] or _G["OPTIONS"] or "Options",
                    keywords = {"options", "game options", "settings", "game settings", "system"},
                    steps = {
                        { buttonFrame = "MainMenuMicroButton" },
                        { gameMenuText = _G["GAMEMENU_OPTIONS"] or _G["OPTIONS"] or "Options" },
                    },
                },

                {
                    name = _G["MACROS"] or "Macros",
                    keywords = {"macros", "macro", "macro window", "new macro", "create macro", "edit macro"},
                    steps = {
                        { buttonFrame = "MainMenuMicroButton" },
                        { gameMenuText = _G["MACROS"] or "Macros" },
                    },
                },
            },
        },
        {
            name = _G["HELP_BUTTON"] or _G["HELP_LABEL"] or "Help",
            keywords = {"help", "support", "ticket", "bug", "report", "gm"},
            category = "Menu Bar",
            buttonFrame = "HelpMicroButton",
            steps = {{ buttonFrame = "HelpMicroButton" }},
        },
        {
            name = _G["BLIZZARD_STORE"] or _G["STORE"] or "Shop",
            keywords = {"shop", "store", "blizzard shop", "cash shop", "buy", "purchase", "micro transaction"},
            category = "Menu Bar",
            buttonFrame = "StoreMicroButton",




            slashCommand = "/click StoreMicroButton",
        },

        {
            name = L["UITREE_PORTRAIT_MENU"],
            keywords = {"portrait", "portrait menu", "right click portrait", "player frame menu"},
            category = "Portrait Menu",
            buttonFrame = "PlayerFrame",
            steps = {{ portraitMenu = true }},
            children = {
                { name = _G["SET_FOCUS"] or "Set Focus", keywords = {"set focus", "focus target", "focus frame", "focus"}, steps = {{ portraitMenuOption = _G["SET_FOCUS"] or "Set Focus" }} },
                { name = _G["SELF_HIGHLIGHT_OPTION"] or "Self Highlight", caps = "selfHighlight", keywords = {"self highlight", "highlight self", "outline", "self outline"}, steps = {{ portraitMenuOption = _G["SELF_HIGHLIGHT_OPTION"] or "Self Highlight" }} },
                { name = _G["RAID_TARGET_ICON"] or "Target Marker Icon", keywords = {"target marker", "raid marker", "skull", "cross", "star", "moon", "marker icon", "raid icon", "world marker"}, steps = {{ portraitMenuOption = _G["RAID_TARGET_ICON"] or "Target Marker Icon" }} },
                { name = _G["SELECT_LOOT_SPECIALIZATION"] or "Loot Specialization", caps = "specs", keywords = {"loot spec", "loot specialization", "loot preference"}, steps = {{ portraitMenuOption = _G["SELECT_LOOT_SPECIALIZATION"] or "Loot Specialization" }} },
                { name = _G["DUNGEON_DIFFICULTY"] or "Dungeon Difficulty", keywords = {"dungeon difficulty", "normal dungeon", "heroic dungeon", "mythic dungeon", "instance difficulty"}, steps = {{ portraitMenuOption = _G["DUNGEON_DIFFICULTY"] or "Dungeon Difficulty" }} },
                { name = _G["RAID_DIFFICULTY"] or "Raid Difficulty", keywords = {"raid difficulty", "normal raid", "heroic raid", "mythic raid", "raid size"}, steps = {{ portraitMenuOption = _G["RAID_DIFFICULTY"] or "Raid Difficulty" }} },
                {
                    name = _G["RESET_INSTANCES"] or "Reset All Instances",
                    keywords = {"reset instances", "reset all instances", "instance reset", "dungeon reset"},
                    available = function()
                        local inInstance = IsInInstance()
                        if inInstance then return false end
                        if IsInGroup() and not UnitIsGroupLeader("player") then return false end
                        return true
                    end,
                    steps = {{ portraitMenuOption = _G["RESET_INSTANCES"] or "Reset All Instances" }},
                },
                { name = _G["HUD_EDIT_MODE_MENU"] or _G["EDIT_MODE"] or "Edit Mode", caps = "editMode", keywords = {"edit mode", "ui layout", "customize ui", "move frames", "hud edit", "ui editor"}, steps = {{ portraitMenuOption = _G["HUD_EDIT_MODE_MENU"] or _G["EDIT_MODE"] or "Edit Mode" }} },
                { name = _G["VOICE_CHAT"] or "Voice Chat", keywords = {"voice chat", "voice", "voip", "talk", "microphone", "mic"}, steps = {{ portraitMenuOption = _G["VOICE_CHAT"] or "Voice Chat" }} },
                { name = _G["PVP_FLAG"] or "PvP Flag", isPvP = true, keywords = {"pvp flag", "pvp toggle", "player vs player flag", "pvp enable", "war mode"}, steps = {{ portraitMenuOption = _G["PVP_FLAG"] or "PvP Flag" }} },
            },
        },

        {
            name = _G["BAGSLOT"] or _G["INVENTORY_TOOLTIP"] or "Bags / Inventory",
            keywords = {"bags", "bag", "inventory", "backpack", "items", "storage"},
            category = "Inventory",
            iconAtlas = ns.BAG_ICON_ATLAS,
            icon = ns.BAG_ICON_TEX,
            steps = {{ buttonFrame = "MainMenuBarBackpackButton" }},
        },
        {
            name = L["UITREE_CALENDAR"],
            keywords = {"calendar", "events", "holidays", "schedule"},
            category = "Social",
            icon = 134939,

            available = function() return ns.Caps.calendar end,
            slashCommand = "/click GameTimeFrame",
        },



        {
            name = L["UITREE_DISMISS_PET"],
            caps = "pets",
            keywords = {"dismiss", "dismiss pet", "pet", "companion", "summon",
                        "battle pet", "critter", "minion"},
            category = "Action",
            icon = 631719,
            slashCommand = "/dismisspet\n/run local g = C_PetJournal and C_PetJournal.GetSummonedPetGUID and C_PetJournal.GetSummonedPetGUID(); if g then C_PetJournal.SummonPetByGUID(g) end",
        },
    }

    self:FlattenTree(uiTree)

    for _, item in ipairs(uiSearchData) do
        item.nameLower = slower(item.name)
        if item.keywords then
            local kws = item.keywords
            local needsCopy = false
            for i = 1, #kws do
                local k = kws[i]
                if k ~= slower(k) then needsCopy = true; break end
            end
            if needsCopy then
                local lowered = {}
                for i = 1, #kws do lowered[i] = slower(kws[i]) end
                item.keywordsLower = lowered
            end



        end
        if not item.icon and not item.buttonFrame then
            item.icon = 134400
        end
    end





    for _, item in ipairs(uiSearchData) do
        ApplyGroupFinderSubcategoryIcon(item)
        if not item.isPvP and item.category == "PvP" then
            item.isPvP = true
        end
    end




    if ns.Caps and ns.Caps.UIEntryBlocked then
        local blocked = ns.Caps.UIEntryBlocked
        for _, item in ipairs(uiSearchData) do
            if item.buttonFrame or item.steps then
                local own = rawget(item, "available")
                item.available = function()
                    if blocked(item) then return false end
                    if own then return own() end
                    return true
                end
            end
        end
    end
end



local initOk, initErr = xpcall(Database.Initialize, Utils.ErrorHandler, Database)
if not initOk then
    print((ns.CHAT_LOGO or "") .. "|cffff4444" .. L["ERR_DATABASE_INIT_FAILED"] .. tostring(initErr) .. "|r")
end
