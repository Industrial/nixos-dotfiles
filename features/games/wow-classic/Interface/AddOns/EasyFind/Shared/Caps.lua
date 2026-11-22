

local _, ns = ...

local Caps = {}
ns.Caps = Caps

local function rule(name)


    if not (C_GameRules and C_GameRules.IsGameRuleActive and Enum and Enum.GameRule) then return nil end
    local id = Enum.GameRule[name]
    if not id then return nil end
    local ok, active = pcall(C_GameRules.IsGameRuleActive, id)
    if ok then return active and true or false end
    return nil
end
Caps.Rule = rule

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
end



local panelKnown = {}


local PANEL_SYSTEM = { Blizzard_AchievementUI = "achievements", Blizzard_HousingDashboard = "housing" }


local project = WOW_PROJECT_ID
local interface = tonumber((select(4, GetBuildInfo()))) or 0
local forever = (WOW_PROJECT_CAMELOT ~= nil and project == WOW_PROJECT_CAMELOT)
    or (project == nil and interface >= 16000 and interface < 20000)
local classic = project ~= nil and (project == WOW_PROJECT_CLASSIC or project == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
    or (WOW_PROJECT_MISTS_CLASSIC ~= nil and project == WOW_PROJECT_MISTS_CLASSIC))
function Caps.PanelEnabled(addonName)
    local system = PANEL_SYSTEM[addonName]
    if system and Caps[system] == false then return false end
    if classic then


        local known = panelKnown[addonName]
        if known == nil then
            local ok, _, _, _, _, reason = pcall(C_AddOns.GetAddOnInfo, addonName)
            known = ok and reason ~= "MISSING" and reason ~= "DISABLED" and reason ~= "INCOMPATIBLE"


            if known and not C_AddOns.IsAddOnLoaded(addonName) then
                local okL, loaded = pcall(C_AddOns.LoadAddOn, addonName)
                known = okL and loaded
            end
            known = known and true or false
            panelKnown[addonName] = known
        end
        return known
    end
    if not forever then return true end
    local known = panelKnown[addonName]
    if known ~= nil then return known end
    local ok, _, _, _, _, reason = pcall(C_AddOns.GetAddOnInfo, addonName)
    if ok and reason == "MISSING" then panelKnown[addonName] = true return true end
    if ok and (reason == "DISABLED" or reason == "INCOMPATIBLE") then panelKnown[addonName] = false return false end
    local okL, loaded, why = pcall(C_AddOns.LoadAddOn, addonName)
    local enabled = (okL and loaded) and true or (why ~= "WRONG_GAME_TYPE" and why ~= "DISABLED" and why ~= "INCOMPATIBLE")
    panelKnown[addonName] = enabled and true or false
    return panelKnown[addonName]
end



local bindingSet
function Caps.HasBinding(name)
    if not bindingSet or next(bindingSet) == nil then
        bindingSet = {}
        local n = GetNumBindings and GetNumBindings() or 0
        for i = 1, n do
            local cmd = GetBinding(i)
            if type(cmd) == "string" then bindingSet[cmd] = true end
        end
        if n == 0 then return true end
    end
    return bindingSet[name] == true
end


local version, build, _, toc = GetBuildInfo()
Caps.version = version
Caps.build = tonumber(build)
Caps.interface = tonumber(toc) or 0

Caps.forever = forever


Caps.classic = classic
Caps.era = classic and project == WOW_PROJECT_CLASSIC
Caps.tbc = classic and project == WOW_PROJECT_BURNING_CRUSADE_CLASSIC

Caps.mists = classic and project == WOW_PROJECT_MISTS_CLASSIC


Caps.lfgWindow = Caps.era or Caps.tbc
Caps.retail = not forever and not classic



local classID = UnitClass and select(3, UnitClass("player"))
Caps.specs = type(GetNumSpecializationsForClassID) == "function"
    and type(GetSpecializationInfoForClassID) == "function"
    and (not classID or (call(GetNumSpecializationsForClassID, classID) or 0) > 1)
Caps.journal = rule("EncounterJournalDisabled") ~= true
    and type(EncounterJournal_LoadUI) == "function"
    and Caps.PanelEnabled("Blizzard_EncounterJournal")


Caps.journalTabs = Caps.journal and not classic


Caps.loot = Caps.journal or Caps.forever or Caps.era or Caps.tbc


Caps.upgrades = (Caps.forever or Caps.era or Caps.tbc) and not Caps.journal


Caps.instanceTable = (Caps.forever or Caps.era or Caps.tbc) and true or false

Caps.housing = not Caps.forever and C_Housing ~= nil
    and rule("HousingDashboardDisabled") ~= true
    and rule("HousingEnabled") ~= false
    and Caps.PanelEnabled("Blizzard_HousingDashboard")


Caps.achievements = not Caps.forever and not (Caps.era or Caps.tbc)
    and rule("AchievementsPanelDisabled") ~= true
    and type(GetCategoryList) == "function"
    and Caps.PanelEnabled("Blizzard_AchievementUI")


Caps.transmog = rule("TransmogEnabled") ~= false
    and C_TransmogCollection ~= nil
    and not classic




Caps.collectionsUI = Caps.PanelEnabled("Blizzard_Collections")
Caps.mounts = Caps.collectionsUI and C_MountJournal ~= nil and C_MountJournal.GetMountIDs ~= nil
Caps.pets = Caps.collectionsUI and rule("PetBattlesDisabled") ~= true and C_PetJournal ~= nil
Caps.toys = Caps.collectionsUI and C_ToyBox ~= nil
Caps.heirlooms = Caps.collectionsUI and C_Heirloom ~= nil
    and (C_HeirloomInfo == nil or call(C_HeirloomInfo.HeirloomsAvailable) ~= false)



local function characterTab(frameName)
    local subs = _G["CHARACTERFRAME_SUBFRAMES"]
    if type(subs) ~= "table" then return false end
    for i = 1, #subs do if subs[i] == frameName then return true end end
    return false
end
Caps.currencies = (not classic and C_CurrencyInfo ~= nil)
    or (classic and characterTab("TokenFrame") and type(_G["GetCurrencyListSize"]) == "function")
Caps.warbandBank = C_Bank ~= nil and C_Bank.FetchPurchasedBankTabData ~= nil and not Caps.forever
Caps.classTalents = C_ClassTalents ~= nil and C_Traits ~= nil
Caps.oldTalents = type(GetTalentInfo) == "function" and type(GetNumTalentTabs) == "function"


local talentQuery = C_SpecializationInfo ~= nil and C_SpecializationInfo.GetTalentInfo ~= nil
Caps.talentTrees = (Caps.era or Caps.tbc) and talentQuery and type(GetNumTalentTabs) == "function"
Caps.talentTiers = Caps.mists and talentQuery
Caps.talents = rule("TalentsPanelDisabled") ~= true
    and ((not classic and (Caps.classTalents or Caps.oldTalents)) or Caps.talentTrees or Caps.talentTiers)
Caps.delves = C_DelvesUI ~= nil and not Caps.forever
Caps.mythicPlus = C_MythicPlus ~= nil and not Caps.forever
Caps.perks = C_PerksProgram ~= nil and not Caps.forever
Caps.editMode = rule("EditModeDisabled") ~= true and C_EditMode ~= nil
Caps.macros = rule("MacrosDisabled") ~= true


Caps.professions = rule("ProfessionsPanelDisabled") ~= true
    and (not classic or type(_G["GetNumTradeSkills"]) == "function")


Caps.gearSets = C_EquipmentSet ~= nil and (not classic or type(_G["PAPERDOLL_SIDEBARS"]) == "table")

Caps.skills = classic and type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function"
Caps.outfits = Caps.transmog
Caps.ammo = rule("EnableAmmoSystem") == true
Caps.campsites = C_WarbandScene ~= nil and not Caps.forever


Caps.warbandRep = C_Reputation ~= nil and C_Reputation.IsAccountWideReputation ~= nil
    and not Caps.forever and not classic

Caps.reputation = (C_Reputation ~= nil and C_Reputation.GetFactionDataByIndex ~= nil)
    or (type(_G["GetNumFactions"]) == "function" and type(_G["GetFactionInfo"]) == "function")

Caps.waypoints = C_Map ~= nil and C_Map.SetUserWaypoint ~= nil and C_SuperTrack ~= nil and UiMapPoint ~= nil
Caps.pvpUI = Caps.PanelEnabled("Blizzard_PVPUI")
Caps.groupFinder = Caps.PanelEnabled("Blizzard_GroupFinder")



Caps.FRAME_PANEL = {
    PVEFrame = "Blizzard_GroupFinder", GroupFinderFrame = "Blizzard_GroupFinder", PVPQueueFrame = "Blizzard_PVPUI",
    EncounterJournal = "Blizzard_EncounterJournal", AchievementFrame = "Blizzard_AchievementUI",
    CollectionsJournal = "Blizzard_Collections", PlayerSpellsFrame = "Blizzard_PlayerSpells",
    MacroFrame = "Blizzard_MacroUI", ProfessionsFrame = "Blizzard_Professions", HousingDashboardFrame = "Blizzard_HousingDashboard",
    CommunitiesFrame = "Blizzard_Communities", CalendarFrame = "Blizzard_Calendar",
}
Caps.BUTTON_BINDING = {
    AchievementMicroButton = "TOGGLEACHIEVEMENT", EJMicroButton = "TOGGLEENCOUNTERJOURNAL",
    CollectionsMicroButton = "TOGGLECOLLECTIONS", LFDMicroButton = "TOGGLEGROUPFINDER",
    GuildMicroButton = "TOGGLEGUILDTAB", TalentMicroButton = "TOGGLETALENTS", QuestLogMicroButton = "TOGGLEQUESTLOG",
}



function Caps.UIEntryBlocked(entry)

    if entry.caps and Caps[entry.caps] == false then return "no " .. entry.caps end

    if entry.isPvP and not Caps.pvpUI then return "Blizzard_PVPUI disabled" end
    local bf = entry.buttonFrame
    if bf then
        local binding = Caps.BUTTON_BINDING[bf]
        if binding and not Caps.HasBinding(binding) then return "no " .. binding end
        local b = _G[bf]
        if not b then return "no " .. bf end


        if (Caps.forever or Caps.classic) and b.IsShown and not b:IsShown() then return bf .. " hidden" end
    end
    local steps = entry.steps
    if steps then
        for i = 1, #steps do
            local s = steps[i]
            local panel = s.waitForFrame and Caps.FRAME_PANEL[s.waitForFrame]
            if panel and not Caps.PanelEnabled(panel) then return panel .. " disabled" end


            if Caps.classic and s.waitForFrame then
                local root = s.waitForFrame:match("^[^.]+")
                if not _G[root] and (not panel or C_AddOns.IsAddOnLoaded(panel)) then return "no " .. root end
            end
            if s.waitForFrame == "CharacterFrame" and CharacterFrame and (s.tabIndex or s.tabFrame)
                and not Caps.CharacterTab(s.tabFrame or s.tabIndex) then
                return "no character tab " .. tostring(s.tabFrame or s.tabIndex)
            end
            if s.sidebarIndex and not Caps.CharacterSidebarSlot(s.sidebarIndex) then
                return "no character sidebar " .. s.sidebarIndex
            end
            if s.buttonFrame then
                local binding = Caps.BUTTON_BINDING[s.buttonFrame]
                if binding and not Caps.HasBinding(binding) then return "no " .. binding end
            end
        end
    end
    return nil
end








local CHARACTER_TAB_FRAME = { [1] = "PaperDollFrame", [2] = "ReputationFrame", [3] = "TokenFrame" }
local SIDEBAR_FRAME = { [1] = "CharacterStatsPane", [2] = "PaperDollTitlesPane", [3] = "PaperDollEquipmentManagerPane" }


local SIDEBAR_NAME = { [1] = "PAPERDOLL_SIDEBAR_STATS", [2] = "PAPERDOLL_SIDEBAR_TITLES", [3] = "PAPERDOLL_EQUIPMENTMANAGER" }


local CLASSIC_SUBFRAME = { SkillsFrame = { "SkillFrame" }, PVPRankFrame = { "HonorFrame", "PVPFrame" } }


function Caps.CharacterSubframe(name)
    local subs = _G["CHARACTERFRAME_SUBFRAMES"]
    if not (Caps.classic and type(subs) == "table") then return name end
    local own = CLASSIC_SUBFRAME[name]
    for i = 1, #subs do
        if subs[i] == name then return name end
        for j = 1, own and #own or 0 do
            if subs[i] == own[j] then return own[j] end
        end
    end
    return nil
end



function Caps.CharacterTab(tabIndex)
    local want = type(tabIndex) == "string" and tabIndex or CHARACTER_TAB_FRAME[tabIndex]
    if type(tabIndex) == "string" then

        for i, f in pairs(CHARACTER_TAB_FRAME) do if f == tabIndex then tabIndex = i end end
    end
    local tabs = _G["CharacterFrameModeTabs"]
    if tabs and want then
        for i = 1, select("#", tabs:GetChildren()) do
            local tab = select(i, tabs:GetChildren())
            if tab and tab.frameName == want then return tab end
        end
        return nil
    end


    local subs = _G["CHARACTERFRAME_SUBFRAMES"]
    if Caps.classic and type(subs) == "table" then
        want = want and Caps.CharacterSubframe(want)
        for i = 1, #subs do
            if subs[i] == want then return _G["CharacterFrameTab" .. i] end
        end
        return nil
    end
    if type(tabIndex) ~= "number" then return nil end
    local tab = _G["CharacterFrameTab" .. tabIndex]
    if not tab and CharacterFrame and CharacterFrame.Tabs then tab = CharacterFrame.Tabs[tabIndex] end
    return tab
end



local COLLECTIONS_TAB_LABEL = {
    [1] = "MOUNTS", [2] = "PET_JOURNAL", [3] = "TOY_BOX",
    [4] = "HEIRLOOMS", [5] = "WARDROBE", [6] = "WARBAND_SCENES",
}




function Caps.CollectionsTab(tabIndex)
    local direct = _G["CollectionsJournalTab" .. tostring(tabIndex)]
    if direct or not Caps.forever then return direct end
    local container = CollectionsJournal and CollectionsJournal.TabContainer
    local tabs = container and container.Tabs
    if not tabs then return nil end
    local key = COLLECTIONS_TAB_LABEL[tabIndex]
    local want = key and _G[key]
    for i = 1, #tabs do
        if want and tabs[i].tooltipText == want then return tabs[i] end
    end
    return tabs[tabIndex]
end



function Caps.CharacterSidebarSlot(sidebarIndex)

    if Caps.classic and type(_G["PAPERDOLL_SIDEBARS"]) ~= "table" then return nil end
    local want = SIDEBAR_FRAME[sidebarIndex]
    local wantName = SIDEBAR_NAME[sidebarIndex] and _G[SIDEBAR_NAME[sidebarIndex]]
    local list = _G["PAPERDOLL_SIDEBARS"]
    if type(list) == "table" and want then
        for i = 1, #list do
            local s = list[i]
            if type(s) == "table" and (s.frame == want or (wantName and s.name == wantName)) then return i end
        end


        if Caps.forever then return nil end
        return sidebarIndex
    end
    return sidebarIndex
end



Caps.selfHighlight = not classic

Caps.guildBank = not Caps.era and type(_G["GetNumGuildBankTabs"]) == "function"
Caps.calendar = not (Caps.era or Caps.tbc)


Caps.titles = not Caps.era



Caps.questLogAtlas = not Caps.era


Caps.mapTabStrip = not Caps.classic



Caps.itemCatalog = true
Caps.iconSearch = not classic

Caps.sourceData = Caps.forever or Caps.era or Caps.tbc or false



Caps.lootDifficulties = (Caps.era or Caps.forever) and {}
    or Caps.tbc and { "normal", "heroic" }
    or Caps.mists and { "lfr", "normal", "heroic" }
    or { "lfr", "normal", "heroic", "mythic" }


Caps.spellRanks = Caps.forever and C_Spell ~= nil and C_Spell.GetSpellSubtext ~= nil



local NEEDS = {
    pets = "pets", toys = "toys", heirlooms = "heirlooms", currencies = "currencies",
    housing = "housing", loot = "loot", bosses = "loot", delves = "delves", delve = "delves",
    warband = "warbandBank", achievements = "achievements", statistics = "achievements",
    talents = "talents", outfits = "outfits", appearances = "transmog",
    transmogSets = "transmog", appearanceItems = "transmog", mounts = "mounts",
    perks = "perks", macros = "macros", professions = "professions", gearSets = "gearSets",
    reputations = "reputation", catalog = "itemCatalog", icons = "iconSearch",
    collections = "collectionsUI", titles = "titles", skills = "skills", upgrades = "upgrades",
    holidays = "calendar", skillUps = "professions", guildBank = "guildBank",
}
Caps.NEEDS = NEEDS



function Caps.Has(key)
    local need = NEEDS[key]
    if not need then return true end
    return Caps[need] and true or false
end



function Caps.PruneRows(rows)
    if type(rows) ~= "table" then return rows end
    for i = #rows, 1, -1 do
        local row = rows[i]
        if type(row) == "table" and row.key and not Caps.Has(row.key) then
            table.remove(rows, i)
        elseif type(row) == "table" then

            if row.flyoutSubFilters and #row.flyoutSubFilters > 0
               and #Caps.PruneRows(row.flyoutSubFilters) == 0 then
                table.remove(rows, i)
            end

            local radio = row.flyoutRadio
            if radio then
                local pruned = false
                for _, list in ipairs({ radio.options, radio.checkboxes }) do
                    if type(list) == "table" then
                        for j = #list, 1, -1 do
                            local opt = list[j]
                            if type(opt) == "table" and opt.caps and Caps[opt.caps] == false then
                                table.remove(list, j)
                                pruned = true
                            end
                        end
                    end
                end

                if pruned and type(radio.options) == "table" and #radio.options < 2
                   and not (radio.checkboxes and #radio.checkboxes > 0) then
                    row.flyoutRadio = nil
                end
            end
        end
    end
    return rows
end


function Caps.Summary()
    local on, off = {}, {}
    for k, v in pairs(Caps) do
        if type(v) == "boolean" then
            if v then on[#on + 1] = k else off[#off + 1] = k end
        end
    end
    table.sort(on) table.sort(off)
    return string.format("%s (%s) on: %s | off: %s", tostring(version), tostring(toc), table.concat(on, " "), table.concat(off, " "))
end





function Caps.ClassicFaction(name, _, standingID, barMin, barMax, barValue, _, _, isHeader, isCollapsed, hasRep,
                             isWatched, isChild, factionID)
    if not name then return nil end
    return { name = name, factionID = factionID, isHeader = isHeader, isCollapsed = isCollapsed,
             isHeaderExpanded = not isCollapsed, isHeaderWithRep = hasRep, isWatched = isWatched, isChild = isChild,
             reaction = standingID, currentStanding = barValue, currentReactionThreshold = barMin,
             nextReactionThreshold = barMax, listed = true }
end

function Caps.NumFactions()
    local R = C_Reputation
    if R and R.GetNumFactions then return R.GetNumFactions() or 0 end
    local count = _G["GetNumFactions"]
    return count and count() or 0
end

function Caps.FactionAt(index)
    local R = C_Reputation
    if R and R.GetFactionDataByIndex then return R.GetFactionDataByIndex(index) end
    local get = _G["GetFactionInfo"]
    return get and Caps.ClassicFaction(get(index)) or nil
end


function Caps.FactionByID(factionID)
    local R = C_Reputation
    if R and R.GetFactionDataByID then return R.GetFactionDataByID(factionID) end
    local get = _G["GetFactionInfoByID"]
    if get then return Caps.ClassicFaction(get(factionID)) end
    for i = 1, Caps.NumFactions() do
        local data = Caps.FactionAt(i)
        if data and data.factionID == factionID then return data end
    end
    return nil
end

function Caps.SetFactionHeaderExpanded(index, expanded)
    local R = C_Reputation
    local name = expanded and "ExpandFactionHeader" or "CollapseFactionHeader"
    local fn = (R and R[name]) or _G[name]
    if fn then fn(index) end
end




function Caps.NumCurrencies()
    local C = C_CurrencyInfo
    if C and C.GetCurrencyListSize then return C.GetCurrencyListSize() or 0 end
    local size = _G["GetCurrencyListSize"]
    return size and size() or 0
end

function Caps.CurrencyAt(index)
    local C = C_CurrencyInfo
    if C and C.GetCurrencyListInfo then return C.GetCurrencyListInfo(index) end
    local get = _G["GetCurrencyListInfo"]
    if not get then return nil end
    local name, isHeader, isExpanded, isUnused, isWatched, count, icon = get(index)
    if not name or name == "" then return nil end
    local link = C and C.GetCurrencyListLink and C.GetCurrencyListLink(index)
    return { name = name, isHeader = isHeader, isHeaderExpanded = isExpanded, isTypeUnused = isUnused,
             isShowInBackpack = isWatched, quantity = count, iconFileID = icon,
             currencyID = type(link) == "string" and tonumber(link:match("currency:(%d+)")) or nil }
end

function Caps.SetCurrencyHeaderExpanded(index, expanded)
    local C = C_CurrencyInfo
    if C and C.ExpandCurrencyList then
        C.ExpandCurrencyList(index, expanded)
    elseif _G["ExpandCurrencyList"] then
        _G["ExpandCurrencyList"](index, expanded and 1 or 0)
    end
end
