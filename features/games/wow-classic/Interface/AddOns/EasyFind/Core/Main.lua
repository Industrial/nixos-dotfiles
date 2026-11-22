local ADDON_NAME, ns = ...

local Utils   = ns.Utils
local L       = ns.L
local sformat = Utils.sformat
local pairs   = Utils.pairs
local xpcall  = Utils.xpcall
local mmin, mmax = Utils.mmin, Utils.mmax
local mrad, mdeg, matan2, mcos, msin, msqrt = math.rad, math.deg, math.atan2, math.cos, math.sin, math.sqrt
local ErrorHandler = Utils.ErrorHandler

EasyFind = {}
ns.EasyFind = EasyFind
EasyFind._ns = ns


ns.BUILD = "5.5.0"

local eventFrame = CreateFrame("Frame")
ns.eventFrame = eventFrame

EasyFind.db = {}


local DB_VERSION = 28
local REVAMPED_TUTORIAL_VERSION = "2.0.0"
ns.REVAMPED_TUTORIAL_VERSION = REVAMPED_TUTORIAL_VERSION

local DB_DEFAULTS = {
    dbVersion = DB_VERSION,
    learnedStepLocks = {},
    visible = true,
    enableMapSearch = true,
    iconScale = 0.8,
    nativePinScale = 1.5,
    uiSearchScale = 1.0,
    uiSearchWidth = 1.54,
    uiResultsScale = 1.0,
    uiResultsWidth = 350,
    uiSearchBarHeight = ns.SEARCHBAR_HEIGHT,
    fontSize = ns.DEFAULT_FONT_SIZE,
    searchWindowOpacity = ns.SEARCH_WINDOW_ALPHA,
    uiSearchPosition = nil,
    localMapDirectOpen = true,
    globalMapDirectOpen = true,
    autoHide = true,
    smartShow = false,


    combatHide = true,

    combatDim = false,
    moveDim = false,

    windowBorder = true,
    themeFrameArt = true,
    lockPosition = false,
    tutorialDone = false,
    updateNotify = true,
    hideExtensionTips = false,
    snippets = {},
    snippetChatExpansion = true,

    quicklists = {},

    clipboardCopied = true,
    clipboardPasted = true,


    clipboardChat = false,
    clipboardWhispers = false,
    clipboardSent = false,

    clipboardLastCopiedRow = false,

    notesSurfaceHere = false,
    resultClicks = {},

    rowActionKeys = {},
    clickSelectsRow = false,


    clipboardKindLink = true, clipboardKindEflink = true, clipboardKindMappin = true,
    clipboardKindUrl = true, clipboardKindCommand = true, clipboardKindNumber = true,
    clipboardKindText = true,
    clipboardOldestFirst = false,
    snippetTriggerChar = "\\",
    accountKeybinds = {},
    resultsTheme = "Modern",
    font = "Default",

    uiTheme = (ns.Caps and ns.Caps.forever) and "Forever" or "Midnight",
    iconVisibility = "all",
    indicatorStyle = "EasyFind Arrow",
    indicatorColor = "Yellow",
    uiResultsRows = 6,
    pinnedUIItems = {},
    pinnedUIItemsPerChar = {},
    pinnedMapItems = {},
    lootStatCache = {},
    lootStatCacheVer = 0,
    lootItemCache = {},
    lootItemCacheVer = 0,
    bossCache = {},
    bossCacheVer = 0,
    statisticCache = {},
    statisticCacheVer = 0,



    optionsSearchCache = {},
    mapPinsCollapsed = false,
    blinkingPins = false,
    mapPinStyle = "glow",
    autoPinClear = true,
    autoTrackPins = true,
    mapWaypointOnly = false,
    uiResultsAbove = false,
    showResultShortcutHints = true,
    showMinimapButton = true,
    minimapButtonAngle = 200,
    globalSearchFilters = {
        zones = true,
        dungeons = true,
        raids = true,
        delves = true,
    },
    localSearchFilters = {
        instances = true,
        travel = true,
        services = true,
        rares = true,
    },
    mapTabFilters = {
        zones = true,
        instances = true,
        raid = true,
        dungeon = true,
        delve = true,
        travel = true,
        flights = false,
        boats = true,
        portals = true,
        services = true,
        banks = true,
        auction = true,
        inns = true,
        mail = true,
        trainers = true,
        vendors = true,
        appearance = true,
        otherservices = true,
        rares = true,
        npcs = true,
    },


    addonOptionsFilters = {},
    uiMapFilters = {
        zones = true,
        instances = true,
        raid = true,
        dungeon = true,
        delve = true,
        travel = true,
        flights = false,
        boats = true,
        portals = true,
        services = true,
        banks = true,
        auction = true,
        inns = true,
        mail = true,
        trainers = true,
        vendors = true,
        appearance = true,
        otherservices = true,
        rares = true,
        npcs = true,
    },
    mapTabRecentSearches = {},
    mapTabShowRecent = true,
    mapTabRecentCount = 3,
    mapTabFontSize = 1,
    mapTabAutoExpand = true,
    mapTabShowParents = true,
    mapSidePanelOpen = false,
    alwaysShowRares = false,
    housingCollection = "collected",
    housingDyeableOnly = false,
    housingCollectionBonusOnly = false,
    housingIndoors = true,
    housingOutdoors = true,
    housingShowRooms = false,
    housingSortType = 0,
    housingTags = {},
    housingTagGroupsCache = {},
    housingFiltersPendingPush = false,
    professionFilters = {},
    skillFilters = {},
    professionRecipeFilters = {},
    professionFiltersPendingPush = false,
    uiSearchFilters = {
        achievements   = true,
        characterInfo  = true,
        statistics     = true,
        charPlayed     = true,
        charSeen       = true,
        charGold       = true,
        charLevel      = true,
        currencies     = true,
        reputations    = true,
        collections    = true,
        gameOptions    = true,
        addonOptions   = true,
        addons         = true,
        mounts         = true,
        toys           = true,
        pets           = true,
        outfits        = true,
        heirlooms      = true,
        loot           = true,
        housing        = true,
        appearances    = true,
        appearanceItems = true,
        appearanceSets = true,
        items          = true,
        catalog        = true,
        bags           = true,
        bank           = true,
        mail           = true,
        guildBank      = true,
        macros         = true,
        options        = true,
        professions    = true,
        abilities      = true,
        bosses         = true,
        gearSets       = true,
        holidays       = true,
        social         = true,
        friends        = true,
        guildMembers   = true,
        skills         = true,
        talents        = true,
        titles         = true,
        map            = true,
    },



    bankScope = "current",


    bagScope = "current",
    lootSpecs = nil,
    lootSearchSlots = true,
    lootSearchStats = true,
    lootUpgradesOnly = false,
    lootDifficulty = "normal",
    mountFilterCollected = true,
    mountFilterNotCollected = false,
    mountFilterUnusable = false,
    mountTypeGround = true,
    mountTypeFlying = true,
    mountTypeAquatic = true,
    mountTypeRideAlong = true,
    mountSourceFilters = {},
    heirloomFilterCollected = true,
    heirloomFilterNotCollected = false,
    heirloomSourceFilters = {},
    toyFilterCollected = true,
    toyFilterNotCollected = false,
    toyFilterUnusable = true,
    toySourceFilters = {},
    toyExpansionFilters = {},
    petFilterCollected = true,
    petFilterNotCollected = false,
    petSourceFilters = {},
    petTypeFilters = {},
    hideTooltips = {
        collections = false,
        loot        = false,
        abilities   = false,
        talents     = false,
        macros      = false,
        bags        = false,
        bank        = false,
        items       = false,
        currencies  = false,
    },
    currencyFilterMode = "all",
    gearSetSpecFilter = "all",
    reputationFilterMode = "all",
    achievementFilterMode = "all",


    statisticFilterMode = "all",
    talentShowSpecs = true,
    talentShowLoadouts = true,
    titleFilterMode = "earned",
    catalogQualityTier = 0,
    catalogTypeFilters = {},
    hideAchievementHeaders = true,
    hideGuildAchievements = true,
    showLegacyReputations = false,
    abilityHidePassives = false,
    macroFilterGeneral = true,
    macroFilterChar = true,
    bossFilterDungeon = true,
    bossFilterRaid = true,
    bagHideJunk = false,
    wowheadLocale = "auto",
    shortkeyConflictPrompt = true,
    commandShowNative = true,
    commandShowCustom = true,
    appearanceSetClass = nil,
    appearanceSetCollected = true,
    appearanceSetNotCollected = true,
    appearanceSetPvE = true,
    appearanceSetPvP = true,
    uiMapSearchLocal = true,
    aliases = {},
    shortkeys = {},
    shortkeysPerChar = {},
    uiSearchHistory = {},
    uiSearchHistoryLimit = 500,
    searchAutocomplete = true,
    mapTabAutocomplete = true,
    showAppsButton = true,
    showFilterButton = true,


    mapZoneOnly = {},
    learnFromPicks = true,
    macroPickerSearch = true,
    spotlightsDone = {},
    queryLearn = {},
}


ns.DB_DEFAULTS = DB_DEFAULTS

local function RequireRevampedTutorial(db)
    if db.revampedTutorialVersion ~= REVAMPED_TUTORIAL_VERSION then
        db.tutorialDone = false
        db.lastSeenVersion = REVAMPED_TUTORIAL_VERSION
    end
end

local CloneDefaultValue = ns.Utils.DeepCopy


local PRESERVED_KEYS = {
    dbVersion = true,
    tutorialDone = true,
    mapTabRecentSearches = true,
    aliases = true,
    shortkeys = true,
    shortkeysPerChar = true,
    uiSearchHistory = true,
    uiSearchHistoryLimit = true,
    accountKeybinds = true,
}

local RETIRED_SETTINGS_KEYS = {
    enableUISearch = true,
    mapSearchScale = true,
    mapSearchWidth = true,
    mapResultsScale = true,
    mapResultsWidth = true,
    mapFontSize = true,
    mapResultsHeight = true,
    mapResultsAbove = true,
    mapSearchPosition = true,
    globalSearchPosition = true,
    mapSearchPositionMax = true,
    globalSearchPositionMax = true,
    mapSearchYOffset = true,
    hideSearchBarsMaximized = true,
    directOpen = true,
    mapSmartShow = true,
    pinsCollapsed = true,
    arrivalDistance = true,
    minimapArrowGlow = true,
    glowOnlyEasyFind = true,
    minimapGuideCircle = true,
    circleOnlyEasyFind = true,
    guideCircleScale = true,
    minimapPinGlow = true,
    panelOpacity = true,
    searchBarOpacity = true,
    staticOpacity = true,
    suggestedKeybindsApplied = true,
    optionsPosition = true,
    lootFilter = true,
    showTruncationMessage = true,
    hardResultsCap = true,
}

local function ApplyFreshSettingsFor2(db)
    for key, defaultValue in pairs(DB_DEFAULTS) do
        if not PRESERVED_KEYS[key] then
            db[key] = CloneDefaultValue(defaultValue)
        end
    end

    for key in pairs(RETIRED_SETTINGS_KEYS) do
        db[key] = nil
    end

    RequireRevampedTutorial(db)
end





local INTERACTIVE_RESET_PRESERVE = {
    pinnedUIItems = true,
    pinnedUIItemsPerChar = true,
    pinnedMapItems = true,
    lootStatCache = true,
    lootStatCacheVer = true,
    lootItemCache = true,
    lootItemCacheVer = true,
    bossCache = true,
    bossCacheVer = true,
    statisticCache = true,
    statisticCacheVer = true,
    optionsSearchCache = true,

    snippets = true,
    quicklists = true,
    queryLearn = true,
}
for key in pairs(PRESERVED_KEYS) do
    INTERACTIVE_RESET_PRESERVE[key] = true
end



local NIL_DEFAULT_KEYS = { "uiSearchPosition", "lootSpecs", "appearanceSetClass", "heirloomFilter", "lootFilter",
                           "appearanceItemClass", "appearanceItemSlot", "appearanceItemSourceFilters" }

function EasyFind:ResetSettingsToDefaults()
    local db = self.db
    if not db then return end
    for key, defaultValue in pairs(DB_DEFAULTS) do
        if not INTERACTIVE_RESET_PRESERVE[key] then
            db[key] = CloneDefaultValue(defaultValue)
        end
    end
    for i = 1, #NIL_DEFAULT_KEYS do
        db[NIL_DEFAULT_KEYS[i]] = nil
    end
end

local DB_MIGRATIONS = {
    [1] = function(db)
        if db.maxResults then
            if not db.uiMaxResults then db.uiMaxResults = db.maxResults end
            if not db.mapMaxResults then db.mapMaxResults = db.maxResults end
            db.maxResults = nil
        end
        if db.uiResultsWidth == 1.0 then db.uiResultsWidth = 300 end
    end,
    [2] = function(db)
        if db.uiResultsWidth == 300 then db.uiResultsWidth = 350 end
    end,
    [3] = function(db)
        if not db.uiResultsHeight then
            db.uiResultsHeight = db.uiMaxResults and (db.uiMaxResults * 28) or 280
        end
        db.uiMaxResults = nil
        db.mapMaxResults = nil
    end,
    [4] = function(db)
        local w = db.uiSearchWidth
        if w == nil or w <= 0.88 then
            db.uiSearchWidth = 1.54
        end
    end,
    [5] = function(db)
        if db.localMapDirectOpen == false then db.localMapDirectOpen = true end
        if db.globalMapDirectOpen == false then db.globalMapDirectOpen = true end
    end,
    [6] = function(db)
        if db.mapTabFilters and db.mapTabFilters.flightpath == nil then
            db.mapTabFilters.flightpath = false
        end
    end,
    [8] = function(db)
        if db.resultsTheme == "Retail" or db.resultsTheme == "Classic" then
            db.resultsTheme = "Modern"
        end
    end,
    [9] = function(db)
        db.panelOpacity = nil
    end,
    [10] = function(db)
        if not db.uiSearchBarHeight then db.uiSearchBarHeight = ns.SEARCHBAR_HEIGHT end
    end,
    [11] = function(db)
        RequireRevampedTutorial(db)
    end,
    [12] = function(db)
        db.searchBarOpacity = nil
    end,
    [13] = function(db)
        RequireRevampedTutorial(db)
    end,
    [14] = function(db)
        db.staticOpacity = nil
        db.searchBarOpacity = nil
        db.suggestedKeybindsApplied = nil
        if db.mapTabFilters then
            db.mapTabFilters.flightpath = false
        end
    end,
    [15] = function(db)
        db.showLoginMessage = false
    end,
    [16] = function(db)
        if db.tutorialDone == true
           and db.lastSeenVersion == REVAMPED_TUTORIAL_VERSION
           and db.revampedTutorialVersion ~= REVAMPED_TUTORIAL_VERSION then
            db.revampedTutorialVersion = REVAMPED_TUTORIAL_VERSION
        end
    end,
    [17] = function(db)
        ApplyFreshSettingsFor2(db)
    end,
    [18] = function(db)



        if type(db.mapTabFilters) == "table" then
            local barFilters = {}
            for k, v in pairs(db.mapTabFilters) do barFilters[k] = v end
            db.uiMapFilters = barFilters
        end
    end,
    [19] = function(db)



        local seeded = {
            "raid", "dungeon", "delve", "boats", "portals",
            "banks", "auction", "inns", "mail", "trainers",
            "vendors", "appearance", "otherservices",
        }
        local function foldFilters(t)
            if type(t) ~= "table" then return end
            if t.flights == nil then t.flights = t.flightpath == true end
            t.flightpath = nil
            for i = 1, #seeded do
                if t[seeded[i]] == nil then t[seeded[i]] = true end
            end
        end
        foldFilters(db.mapTabFilters)
        foldFilters(db.uiMapFilters)
    end,
    [20] = function(db)


        local w = db.uiSearchWidth
        if type(w) == "number" and w < 1.0 then
            db.uiSearchWidth = 1.0
        end
    end,
    [21] = function(db)

        db.uiResultsHeight = nil
    end,
    [22] = function(db)

        if db.mapPinHighlight == false then db.mapPinStyle = "off" end
        db.mapPinHighlight = nil
    end,
    [24] = function(db)

        for _, slot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            if type(slot) == "table" and type(slot.settings) == "table" then
                slot.settings.achievementIndex = nil
            end
        end
    end,
    [25] = function(db)

        db.gpsChatArrive = nil
        for _, slot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            if type(slot) == "table" and type(slot.settings) == "table" then
                slot.settings.gpsChatArrive = nil
            end
        end
    end,
    [26] = function(db)

        db.showAliasMessages = nil
        for _, slot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            if type(slot) == "table" and type(slot.settings) == "table" then
                slot.settings.showAliasMessages = nil
            end
        end
    end,
    [27] = function(db)

        if db.mapCategoryScope == "local" then db.mapZoneOnly = { all = true } end
        db.mapCategoryScope = nil
    end,
    [28] = function(db)


        for _, key in ipairs({ "mapFilters", "uiMapFilters" }) do
            if type(db[key]) == "table" then db[key].npcs = true end
        end
    end,
}

local RUNTIME_FIELDS = {
    "firstInstall",
}

local GITHUB_ISSUES_URL = "https://github.com/fallenguards/EasyFind/issues/new"

ns.GITHUB_CHANGELOG_URL = "https://github.com/fallenguards/EasyFind/blob/main/CHANGELOG.md"

local function UrlEncode(str)
    return str:gsub("([^%w%-%.%_%~ ])", function(c)
        return sformat("%%%02X", c:byte())
    end):gsub(" ", "+")
end



local function ShowFeedbackURL(url, about)
    ns.ShowThemedDialog({
        text = about, hasEditBox = true, editBoxDefault = url, maxLetters = 0, readOnly = true,
        single = true, acceptText = _G["CLOSE"] or "Close",
    })
end

local function OpenBugReport()
    local version = ns.version or "unknown"
    local url = GITHUB_ISSUES_URL .. "?template=bug_report.yml&version=" .. UrlEncode(version)
    ShowFeedbackURL(url, L["FEEDBACK_LINK_BUG"])
end

local function OpenFeatureRequest()
    local url = GITHUB_ISSUES_URL .. "?template=feature_request.yml"
    ShowFeedbackURL(url, L["FEEDBACK_LINK_FEATURE"])
end

function EasyFind:OpenBugReport() OpenBugReport() end


function EasyFind:OpenRouteReport(code, step)
    ShowFeedbackURL(GITHUB_ISSUES_URL .. "?template=route_report.yml&version=" .. UrlEncode(ns.version or "unknown")
        .. "&route=" .. UrlEncode(code) .. (step and ("&step=" .. UrlEncode(step)) or ""), L["FEEDBACK_LINK_ROUTE"])
end
function EasyFind:OpenFeatureRequest() OpenFeatureRequest() end


local SUGGESTED_KEYBINDS = {
    EASYFIND_TOGGLE_FOCUS = "CTRL-SPACE",
    EASYFIND_MAP_FOCUS = "CTRL-M",
}





local WHATSNEW_CONTENT_VERSION = "5.5.0"

local WHATSNEW_LINK_PREFIX = "easyfind:whatsnew:"
local TUTORIAL_LINK_PREFIX = "easyfind:tutorial"
local PAGE_LINK_PREFIX = "easyfind:page:"
local EXTENSIONS_LINK = "easyfind:extensions"
local whatsNewHookInstalled = false

local function InstallWhatsNewHyperlinkHook()
    if whatsNewHookInstalled then return end
    whatsNewHookInstalled = true





    hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
        if link and link:sub(1, #WHATSNEW_LINK_PREFIX) == WHATSNEW_LINK_PREFIX then
            local version = link:sub(#WHATSNEW_LINK_PREFIX + 1)
            if ns.RequestOnboarding() and ns.Onboarding.ShowWhatsNew then
                xpcall(ns.Onboarding.ShowWhatsNew, ErrorHandler, ns.Onboarding, version)
            end
        elseif link == TUTORIAL_LINK_PREFIX then
            if ns.RequestOnboarding() and ns.Wizard.Show then
                xpcall(ns.Wizard.Show, ErrorHandler, ns.Wizard)
            end
        elseif link and link:sub(1, #PAGE_LINK_PREFIX) == PAGE_LINK_PREFIX then
            ns.ShowExtensionPage(link:sub(#PAGE_LINK_PREFIX + 1))
        elseif link == EXTENSIONS_LINK then
            ns.ShowExtensionPages()
        end
    end)
end



local function BlueChatLink(target, label)
    local LC = ns.LINK_COLOR or { 0.44, 0.84, 1.0 }
    return sformat("|cff%02x%02x%02x|H%s|h[%s]|h|r",
        LC[1] * 255, LC[2] * 255, LC[3] * 255, target, label)
end
ns.BlueChatLink = BlueChatLink




function ns.OfferTutorialInChat()
    print(ns.CHAT_LOGO .. sformat(L["TUTORIAL_CHAT_OFFER"], BlueChatLink(TUTORIAL_LINK_PREFIX, L["WHATSNEW_CHAT_HERE"])))
end


function ns.TutorialOpensItself()
    return not (ns.Caps and ns.Caps.forever)
end

local function ShowWhatsNewChatMessage(version)
    local v = version or "?"
    local link = BlueChatLink(WHATSNEW_LINK_PREFIX .. v, L["WHATSNEW_CHAT_HERE"])
    local msg = sformat(L["WHATSNEW_CHAT_HELLO"], v, link)


    print(ns.CHAT_LOGO .. msg)
end
ns.ShowWhatsNewChatMessage = ShowWhatsNewChatMessage







local function CompareVersion(a, b)
    a, b = tostring(a or ""), tostring(b or "")
    local abase, apre = a:match("^([^-]*)-?(.*)$")
    local bbase, bpre = b:match("^([^-]*)-?(.*)$")
    local ai, bi = abase:gmatch("%d+"), bbase:gmatch("%d+")
    while true do
        local av, bv = ai(), bi()
        if av == nil and bv == nil then break end
        av, bv = tonumber(av) or 0, tonumber(bv) or 0
        if av ~= bv then return av < bv and -1 or 1 end
    end
    if (apre == "") ~= (bpre == "") then return apre == "" and 1 or -1 end
    local an, bn = tonumber(apre:match("%d+")) or 0, tonumber(bpre:match("%d+")) or 0
    if an ~= bn then return an < bn and -1 or 1 end
    return 0
end


ns.CompareVersion = CompareVersion




local function ApplyDBDefaults(db)
    for k, v in pairs(DB_DEFAULTS) do
        if db[k] == nil then
            db[k] = CloneDefaultValue(v)
        elseif type(v) == "table" and type(db[k]) == "table" then
            for sk, sv in pairs(v) do
                if db[k][sk] == nil then
                    db[k][sk] = CloneDefaultValue(sv)
                end
            end
        end
    end
end
ns.ApplyDBDefaults = ApplyDBDefaults



local SLOT_STEPS_FROM = 22
local function MigrateSlots(db, fromVersion)
    if type(db.profiles) ~= "table" then return end
    for v = mmax(fromVersion + 1, SLOT_STEPS_FROM), db.dbVersion do
        local step = DB_MIGRATIONS[v]
        if step then
            for _, slot in pairs(db.profiles) do
                if type(slot) == "table" and type(slot.settings) == "table" then
                    xpcall(step, ErrorHandler, slot.settings)
                end
            end
        end
    end
end

local function OnInitialize()

    EasyFindDB = EasyFindDB or { firstInstall = true, dbVersion = DB_VERSION }
    EasyFindDB.dbVersion = tonumber(EasyFindDB.dbVersion) or 0
    local savedVersion = EasyFindDB.dbVersion

    Utils.Migrate(EasyFindDB, "dbVersion", DB_MIGRATIONS, DB_VERSION)
    MigrateSlots(EasyFindDB, savedVersion)
    ApplyDBDefaults(EasyFindDB)

    for k, v in pairs(EasyFindDB) do
        local default = DB_DEFAULTS[k]
        if default ~= nil and type(v) ~= type(default) then
            EasyFindDB[k] = CloneDefaultValue(default)
        end
    end

    EasyFind.db = EasyFindDB


    if ns.Profiles then ns.Profiles:OnInitialize() end

    ns.version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")

    SLASH_EASYFIND1 = "/ef"
    SlashCmdList["EASYFIND"] = function(msg)
        msg = msg and msg:lower():trim() or ""
        if msg == "o" or msg == "options" or msg == "config" or msg == "settings" then
            EasyFind:OpenOptions()
        elseif msg == "toggle" or msg == "t" then
            if ns.Search then ns.Search:Toggle() end
        elseif msg == "c" or msg == "clear" then
            EasyFind:ClearAll()
        elseif msg == "r" or msg == "reset" then
            if ns.RequestOptionsPanel() and ns.Options then
                ns.Options:Initialize()
                ns.Options:ConfirmResetAll()
            end
        elseif msg == "reset positions" then
            if ns.RequestOptionsPanel() and ns.Options then
                ns.Options:Initialize()
                ns.Options:ConfirmResetPositions()
            end
        elseif msg == "bug" then
            OpenBugReport()
        elseif msg == "feature" then
            OpenFeatureRequest()
        elseif msg == "setup" or msg == "tutorial" or msg == "wizard" or msg == "welcome" then
            if ns.RequestOnboarding() and ns.Wizard.Show then
                EasyFind.db.tutorialDone = false
                ns.Wizard:Show()
            end
        elseif msg == "whatsnew" then
            if not ns.RequestOnboarding() then
                return
            elseif ns.version == "2.0.0" and ns.Wizard.Show then
                EasyFind.db.tutorialDone = false
                ns.Wizard:Show()
            elseif ns.Onboarding.ShowWhatsNew then
                ns.Onboarding:ShowWhatsNew(ns.version)
            end
        elseif msg == "help" or msg == "h" or msg == "?" then
            EasyFind:Print(L["CMD_HEADER"])
            EasyFind:Print(L["CMD_OPTIONS"])
            EasyFind:Print(L["CMD_CLEAR"])
            EasyFind:Print(L["CMD_RESET"])
            EasyFind:Print(L["CMD_BUG"])
            EasyFind:Print(L["CMD_FEATURE"])
        elseif msg == "" then
            EasyFind:OpenOptions()
        end
    end


    SLASH_EASYFINDNOTES1 = "/notes"
    SlashCmdList["EASYFINDNOTES"] = function(msg)
        if ns.RequestNotes() and ns.Notes.Slash then ns.Notes.Slash(msg) end
    end

    InstallWhatsNewHyperlinkHook()
end

local SafeAfter = Utils.SafeAfter

local function MarkDynamicCategoryDirty(key)
    if ns.Database and ns.Database.MarkDynamicCategoryDirty then
        ns.Database:MarkDynamicCategoryDirty(key)
    end
    if ns.Search and ns.Search.RebuildOpenResults then
        ns.Search:RebuildOpenResults()
    end
end






local function ClassFilterFromGame(hasSpec, classID, specID)
    if not classID or classID <= 0 then return "all" end
    local _, _, playerClassID = UnitClass("player")
    if not hasSpec then
        if classID == playerClassID then return nil end
        return { classID = classID }
    end
    if not specID or specID == 0 then return { classID = classID } end
    local si = GetSpecialization and GetSpecialization()
    local playerSpecID = si and GetSpecializationInfo and GetSpecializationInfo(si)
    if classID == playerClassID and specID == playerSpecID then return nil end
    return { classID = classID, specID = specID }
end

local function SameClassFilter(a, b)
    local aID = type(a) == "table" and a.classID or a
    local bID = type(b) == "table" and b.classID or b
    if aID ~= bID then return false end
    local aSpec = type(a) == "table" and a.specID or nil
    local bSpec = type(b) == "table" and b.specID or nil
    return aSpec == bSpec
end

local CLASS_FILTER_HOOKS = {
    { dbKey = "appearanceSetClass",  provider = "transmogSets",
      tbl = C_TransmogSets,       method = "SetTransmogSetsClassFilter",
      suppress = "_tmogClassHookSuppress",    installed = "_tmogClassHooked" },
    { dbKey = "appearanceItemClass", provider = "appearanceItems",
      tbl = C_TransmogCollection,  method = "SetClassFilter",
      suppress = "_appItemClassHookSuppress", installed = "_tmogItemClassHooked" },
    { dbKey = "heirloomFilter",      provider = "heirlooms", hasSpec = true,
      tbl = C_Heirloom,            method = "SetClassAndSpecFilters",
      suppress = "_heirloomHookSuppress",     installed = "_heirloomClassHooked" },
    { dbKey = "lootFilter",          provider = "loot", hasSpec = true,
      tbl = C_EncounterJournal,    method = "SetLootFilter", globalFn = "EJ_SetLootFilter",
      suppress = "_lootFilterHookSuppress",   installed = "_lootClassHooked" },
}

local function InstallClassFilterHook(desc)
    if EasyFind[desc.installed] then return end
    local function onChange(classID, specID)
        if EasyFind[desc.suppress] then return end
        local db = EasyFind.db
        if not db then return end
        local newVal = ClassFilterFromGame(desc.hasSpec, classID, specID)
        if SameClassFilter(db[desc.dbKey], newVal) then return end
        db[desc.dbKey] = newVal
        MarkDynamicCategoryDirty(desc.provider)
    end
    local tbl = desc.tbl
    if tbl and tbl[desc.method] then
        EasyFind[desc.installed] = true
        hooksecurefunc(tbl, desc.method, onChange)
    elseif desc.globalFn and _G[desc.globalFn] then
        EasyFind[desc.installed] = true
        hooksecurefunc(desc.globalFn, onChange)
    end
end

local function InstallClassFilterHooks()
    for i = 1, #CLASS_FILTER_HOOKS do
        InstallClassFilterHook(CLASS_FILTER_HOOKS[i])
    end
end


function EasyFind:EnsureDynamicLoaded()


end





local EASYFIND_BINDINGS = { "EASYFIND_TOGGLE_FOCUS", "EASYFIND_FOCUS_BAR", "EASYFIND_MAP_FOCUS", "EASYFIND_CLEAR",
                            "EASYFIND_CLIPBOARD", "EASYFIND_HOVER_NOTE" }
local EASYFIND_BINDING_LOOKUP = {}
for i = 1, #EASYFIND_BINDINGS do EASYFIND_BINDING_LOOKUP[EASYFIND_BINDINGS[i]] = true end

local bindingOverrideOwner = CreateFrame("Frame")

local KEYBIND_BUTTON = {
    EASYFIND_TOGGLE_FOCUS = "EasyFindKeybindToggleButton",
    EASYFIND_FOCUS_BAR    = "EasyFindKeybindFocusButton",
    EASYFIND_MAP_FOCUS    = "EasyFindKeybindMapButton",
    EASYFIND_CLEAR        = "EasyFindKeybindClearButton",
    EASYFIND_CLIPBOARD    = "EasyFindKeybindClipboardButton",
    EASYFIND_HOVER_NOTE   = "EasyFindKeybindNoteButton",
}
do
    local toggleBtn = CreateFrame("Button", "EasyFindKeybindToggleButton", UIParent)
    toggleBtn:Hide()
    toggleBtn:SetScript("OnClick", function() EasyFind:ToggleFocusSearchUI() end)


    local focusBtn = CreateFrame("Button", "EasyFindKeybindFocusButton", UIParent)
    focusBtn:Hide()
    focusBtn:SetScript("OnClick", function()
        if ns.Search and ns.Search.Focus then ns.Search:Focus() end
    end)
    local mapBtn = CreateFrame("Button", "EasyFindKeybindMapButton", UIParent)
    mapBtn:Hide()
    mapBtn:SetScript("OnClick", function() EasyFind:FocusMapSearch() end)
    local clearBtn = CreateFrame("Button", "EasyFindKeybindClearButton", UIParent)
    clearBtn:Hide()
    clearBtn:SetScript("OnClick", function() EasyFind:ClearAll() end)

    local clipBtn = CreateFrame("Button", "EasyFindKeybindClipboardButton", UIParent)
    clipBtn:Hide()
    clipBtn:SetScript("OnClick", function()
        EasyFind.API.OpenExtension("clipboard")
    end)

    local noteBtn = CreateFrame("Button", "EasyFindKeybindNoteButton", UIParent)
    noteBtn:Hide()
    noteBtn:SetScript("OnClick", function()
        if ns.OpenHoveredNote then ns.OpenHoveredNote() end
    end)
end

local function ApplyAccountKeybinds()
    local store = EasyFindDB and EasyFindDB.accountKeybinds
    if not store then return end
    if InCombatLockdown() then
        bindingOverrideOwner:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    ClearOverrideBindings(bindingOverrideOwner)
    for i = 1, #EASYFIND_BINDINGS do
        local action = EASYFIND_BINDINGS[i]
        local key = store[action]
        if key and key ~= "" then
            SetOverrideBindingClick(bindingOverrideOwner, true, key, KEYBIND_BUTTON[action])
        end
    end
end

bindingOverrideOwner:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    ApplyAccountKeybinds()
end)




function EasyFind:ApplyAccountKeybinds()
    ApplyAccountKeybinds()
end





function ns.ApplyUISettings(resetPosition)
    if ns.Highlight and ns.Highlight.ClearAll then pcall(ns.Highlight.ClearAll, ns.Highlight) end
    local Search = ns.Search
    if not (_G["EasyFindSearchFrame"] and Search) then return end
    if resetPosition then
        if Search.ResetPosition then Search:ResetPosition() end
    elseif Search.ApplySavedPosition then
        Search:ApplySavedPosition()
    end
    if Search.UpdateScale then Search:UpdateScale() end
    if Search.UpdateWidth then Search:UpdateWidth() end
    if Search.UpdateOpacity then Search:UpdateOpacity() end
    if Search.UpdateSearchBarHeight then Search:UpdateSearchBarHeight() end
    if Search.UpdateSmartShow then Search:UpdateSmartShow(false) end
    if Search.UpdateFontSize then Search:UpdateFontSize() end
    if Search.RefreshResults then Search:RefreshResults() end
end

function ns.ClearMapRuntime()
    local MapSearch = ns.MapSearch
    if not MapSearch then return end
    pcall(MapSearch.ClearAll, MapSearch)
    pcall(MapSearch.ClearZoneHighlight, MapSearch)
    MapSearch.pendingWaypoint = nil
end

function ns.ApplyMapSettings()
    ns.ClearMapRuntime()
    local MapSearch = ns.MapSearch
    if MapSearch then
        if MapSearch.UpdateIconScales then MapSearch:UpdateIconScales() end
        if MapSearch.RefreshIndicators then MapSearch:RefreshIndicators() end
    end
    local uiInd = _G["EasyFindIndicatorFrame"]
    if uiInd then uiInd:SetScale(EasyFind.db.iconScale or 0.8) end
end

function EasyFind:SetAccountKeybind(action, key)
    if not (action and EASYFIND_BINDING_LOOKUP[action] and EasyFindDB) then return end
    EasyFindDB.accountKeybinds = EasyFindDB.accountKeybinds or {}
    if key == "" then key = nil end
    EasyFindDB.accountKeybinds[action] = key
    ApplyAccountKeybinds()
end

EasyFind.GetAccountKeybind = function(_, action)
    return EasyFindDB and EasyFindDB.accountKeybinds and EasyFindDB.accountKeybinds[action]
end



function EasyFind:ResetAccountKeybindsToDefaults()
    if not EasyFindDB then return end
    local store = {}
    for action, key in pairs(SUGGESTED_KEYBINDS) do store[action] = key end
    EasyFindDB.accountKeybinds = store
    EasyFindDB.suggestedKeybindsSeeded = true
    ApplyAccountKeybinds()
end





local function RegisterBlizzardOptionsStub()


    local panel = CreateFrame("Frame")
    panel:Hide()
    panel.name = "EasyFind"


    local function EmbedAt(frame, pageName)
        if ns.RequestOptionsPanel() and ns.Options and ns.Options.EmbedInBlizzardPanel then
            ns.Options:EmbedInBlizzardPanel(frame, pageName)
        end
    end
    local function PanelHidden()
        if ns.Options and ns.Options.OnBlizzardPanelHide then
            ns.Options:OnBlizzardPanelHide()
        end
    end
    panel:SetScript("OnShow", function(self) EmbedAt(self, nil) end)
    panel:SetScript("OnHide", PanelHidden)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)


        if Settings.RegisterCanvasLayoutSubcategory then
            ns.OptionsCategory = category
            ns.OptionsSubcategories = {}
            for _, key in ipairs({ "OPT_TAB_GENERAL_BINDS", "OPT_TAB_SEARCH", "OPT_TAB_MAP", "OPT_TAB_SHORTCUTS",
                                   "OPT_TAB_ALIASES", "OPT_TAB_BLACKLIST", "FILTER_EXTENSIONS",
                                   "OPT_TAB_PROFILES", "OPT_TAB_FEEDBACK" }) do
                local name = L[key]
                local page = CreateFrame("Frame")
                page:Hide()
                page.name = name
                page:SetScript("OnShow", function(self) EmbedAt(self, name) end)
                page:SetScript("OnHide", PanelHidden)
                ns.OptionsSubcategories[name] = Settings.RegisterCanvasLayoutSubcategory(category, page, name)
            end
        end
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end



    local settingsRoot = SettingsPanel or InterfaceOptionsFrame
    if settingsRoot then
        local restoreOnClose = false









        local function AfterPanelChange(fn)
            Utils.SafeAfter(0, function()
                if InCombatLockdown() then return end
                fn()
            end)
        end
        settingsRoot:HookScript("OnShow", function()
            local sf = _G["EasyFindSearchFrame"]
            restoreOnClose = sf and sf:IsShown() or false
            AfterPanelChange(function()
                if not settingsRoot:IsShown() then return end
                local frame = _G["EasyFindSearchFrame"]
                if frame then frame:Hide() end
                if ns.Search and ns.Search.HideResults then ns.Search:HideResults() end
            end)
        end)
        settingsRoot:HookScript("OnHide", function()
            if not restoreOnClose then return end
            restoreOnClose = false
            AfterPanelChange(function()
                if settingsRoot:IsShown() then return end
                local frame = _G["EasyFindSearchFrame"]
                if frame then frame:Show() end
            end)
        end)
    end
end

local function OnPlayerLogin()



    if ns.Scheduler and not ns.Scheduler._pumpFrame then
        ns.Scheduler:SetBudgetMs(2)
        ns.Scheduler:StartPump(CreateFrame("Frame"))
    end



    if ns.Profiles then ns.Profiles:OnLogin() end
    EasyFind:RestoreChatFramesHidden()
    EasyFind:RestoreObjectiveTrackerHidden()







    if ns.ThemeShare then
        xpcall(ns.ThemeShare.RegisterCustomThemes, ErrorHandler, ns.ThemeShare)
    end
    if ns.ApplyUITheme then
        ns.ApplyUITheme(EasyFind.db.uiTheme, true)
    end
    if ns.WarmAddonFonts and ns.Utils and ns.Utils.SafeAfter then
        ns.Utils.SafeAfter(1, ns.WarmAddonFonts)
    end

    local function SafeInit(mod, name)
        if not mod then return end
        local ok, err = xpcall(mod.Initialize, ErrorHandler, mod)
        if not ok then
            EasyFind:Print("|cffff4444" .. (L["ERR_MODULE_INIT_FAILED"]):format(name, tostring(err)) .. "|r")
        end
    end






    local spotlightsDone = EasyFind.db.spotlightsDone
    if not EasyFind.db.tutorialDone
       or not (spotlightsDone and spotlightsDone.snippets31) then
        ns.RequestOnboarding()
    end

    if EasyFind.db.enableMapSearch ~= false then
        SafeInit(ns.MapSearch,  "MapSearch")
    end
    SafeInit(ns.Search,        "UI")
    SafeInit(ns.VersionCheck,  "VersionCheck")
    SafeInit(ns.RowCopy,       "RowCopy")
    local regOk, regErr = xpcall(RegisterBlizzardOptionsStub, ErrorHandler)
    if not regOk then
        EasyFind:Print("|cffff4444" .. (L["ERR_OPTIONS_REGISTER_FAILED"]):format(tostring(regErr)) .. "|r")
    end


    if EasyFind.API and EasyFind.API.RegisterSettingsIndex then
        EasyFind.API.RegisterSettingsIndex("EasyFind", ns.SettingsRows.Rows)
    end
    InstallClassFilterHooks()
    if ns.ControlSync and ns.ControlSync.ArmAllAtLogin then
        pcall(ns.ControlSync.ArmAllAtLogin)
    end









    if ns.Database and ns.Utils and ns.Utils.SafeAfter then
        ns.Utils.SafeAfter(2, function()
            local db = ns.Database
            if db.LoadDeferredSyncProvidersStaggered then
                db:LoadDeferredSyncProvidersStaggered()
            elseif db.WarmSearchHotPath then
                db:WarmSearchHotPath()
            end
            local f = ns.Search and ns.Search.GetSearchFrame and ns.Search:GetSearchFrame()
            if f then f._efProvidersWarmed = true end
        end)
    end





    if EasyFind.db.lootStatCacheVer ~= ns.LOOT_STAT_CACHE_VER then
        EasyFind.db.lootStatCache = {}
        EasyFind.db.lootStatCacheVer = ns.LOOT_STAT_CACHE_VER
    end
    if EasyFind.db.lootItemCacheVer ~= ns.LOOT_ITEM_CACHE_VER then
        EasyFind.db.lootItemCache = {}
        EasyFind.db.lootItemCacheVer = ns.LOOT_ITEM_CACHE_VER
    end
    if EasyFind.db.bossCacheVer ~= ns.BOSS_CACHE_VER then
        EasyFind.db.bossCache = {}
        EasyFind.db.bossCacheVer = ns.BOSS_CACHE_VER
    end
    if EasyFind.db.statisticCacheVer ~= ns.STATISTIC_CACHE_VER then
        EasyFind.db.statisticCache = {}
        EasyFind.db.statisticCacheVer = ns.STATISTIC_CACHE_VER
    end



    local achievementIndex = EasyFind.db.achievementIndex
    if type(achievementIndex) == "table" and type(achievementIndex.packed) ~= "string" then
        EasyFind.db.achievementIndex = nil
    end


    SafeAfter(0.6, function()



        if ns.RegisterDataBroker then ns.RegisterDataBroker() end
        if ns.RegisterMinimapIcon then ns.RegisterMinimapIcon() end
        if EasyFind.db.showMinimapButton then
            EasyFind:UpdateMinimapButton()
        end
    end)

    local currentVersion = ns.version
    local lastSeen = EasyFind.db.lastSeenVersion
    if currentVersion and currentVersion ~= lastSeen then

        if lastSeen ~= nil then

            if ns.NoteUpgrade then ns.NoteUpgrade(lastSeen) end
            if CompareVersion(lastSeen, REVAMPED_TUTORIAL_VERSION) < 0 then


                EasyFind.db.tutorialDone = false
            elseif EasyFind.db.tutorialDone
                and CompareVersion(lastSeen, WHATSNEW_CONTENT_VERSION) < 0 then








                SafeAfter(2.0, function()
                    ShowWhatsNewChatMessage(currentVersion)
                end)
            end
        end
        EasyFind.db.lastSeenVersion = currentVersion
    end

    EasyFindDB.accountKeybinds = EasyFindDB.accountKeybinds or {}





    if not EasyFindDB.nativeKeybindsImported then
        EasyFindDB.nativeKeybindsImported = true
        for i = 1, #EASYFIND_BINDINGS do
            local action = EASYFIND_BINDINGS[i]
            if not EasyFindDB.accountKeybinds[action] then
                local existing = GetBindingKey(action)
                if existing then EasyFindDB.accountKeybinds[action] = existing end
            end
        end
    end




    if not InCombatLockdown() then
        local removedAny = false
        for i = 1, #EASYFIND_BINDINGS do
            local key1, key2 = GetBindingKey(EASYFIND_BINDINGS[i])
            if key1 then SetBinding(key1); removedAny = true end
            if key2 then SetBinding(key2); removedAny = true end
        end
        if removedAny and SaveBindings and GetCurrentBindingSet then
            pcall(SaveBindings, GetCurrentBindingSet())
        end
    end





    if not EasyFindDB.suggestedKeybindsSeeded then
        EasyFindDB.suggestedKeybindsSeeded = true
        if next(EasyFindDB.accountKeybinds) == nil then
            for action, key in pairs(SUGGESTED_KEYBINDS) do
                EasyFindDB.accountKeybinds[action] = key
            end
        end
    end

    ApplyAccountKeybinds()
    if ns.Shortkeys and ns.Shortkeys.ApplyAll then ns.Shortkeys:ApplyAll() end







    SafeAfter(8, function() ns.Utils.SettleGC() end)


    ns.Extensions.LoadAtLogin()







    SafeAfter(12, function()
        local uiFilters = EasyFind.db and EasyFind.db.uiSearchFilters
        local map = ns.CategoryMap
        if ns.RequestItemCatalog and map and map.IsProviderFilterOff
           and not (uiFilters and map.IsProviderFilterOff(uiFilters, "catalog")) then
            ns.RequestItemCatalog(false)
        end
        if ns.RequestSettingsSearch and map and map.IsProviderFilterOff then
            local bothOff = uiFilters
                and map.IsProviderFilterOff(uiFilters, "gameOptions")
                and map.IsProviderFilterOff(uiFilters, "addonOptions")
            if not bothOff then
                ns.RequestSettingsSearch(false)
            end
        end
    end)
end

local outfitRefreshTimer

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_LOGOUT")



if not (ns.Caps and ns.Caps.transmog == false) then
    eventFrame:RegisterEvent("TRANSMOG_OUTFITS_CHANGED")
    eventFrame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
end
eventFrame:RegisterEvent("UPDATE_MACROS")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
eventFrame:RegisterEvent("EQUIPMENT_SETS_CHANGED")



pcall(eventFrame.RegisterEvent, eventFrame, "NEW_MOUNT_ADDED")


pcall(eventFrame.RegisterEvent, eventFrame, "TRAIT_CONFIG_CREATED")
pcall(eventFrame.RegisterEvent, eventFrame, "TRAIT_CONFIG_DELETED")
pcall(eventFrame.RegisterEvent, eventFrame, "TRAIT_CONFIG_UPDATED")
pcall(eventFrame.RegisterEvent, eventFrame, "TRAIT_CONFIG_LIST_UPDATED")
pcall(eventFrame.RegisterEvent, eventFrame, "ACTIVE_PLAYER_SPECIALIZATION_CHANGED")

pcall(eventFrame.RegisterEvent, eventFrame, "CHARACTER_POINTS_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_TALENT_UPDATE")
if C_HousingCatalog then
    eventFrame:RegisterEvent("HOUSING_STORAGE_UPDATED")
end




local DIRTY_EVENT_CATEGORY = {
    TOYS_UPDATED = "toys",
    PET_JOURNAL_LIST_UPDATE = "pets",
    KNOWN_TITLES_UPDATE = "titles",
    HEIRLOOMS_UPDATED = "heirlooms",
    CURRENCY_DISPLAY_UPDATE = "currencies",
    UPDATE_FACTION = "reputations",


    SKILL_LINES_CHANGED = "professions",
    TRADE_SKILL_SHOW = "professions",
}


if ns.Caps and ns.Caps.skills then DIRTY_EVENT_CATEGORY.SKILL_LINES_CHANGED = "skills" end
local CLASSIC_PROFESSION_EVENTS = {}
if ns.Caps and ns.Caps.classic then
    for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE" }) do
        if pcall(eventFrame.RegisterEvent, eventFrame, e) then CLASSIC_PROFESSION_EVENTS[e] = true end
    end
    if pcall(eventFrame.RegisterUnitEvent, eventFrame, "UNIT_SPELLCAST_SUCCEEDED", "player") then
        CLASSIC_PROFESSION_EVENTS.UNIT_SPELLCAST_SUCCEEDED = true
    end
end
for dirtyEvent in pairs(DIRTY_EVENT_CATEGORY) do




    pcall(eventFrame.RegisterEvent, eventFrame, dirtyEvent)
end





local BAG_SNAPSHOT_MIN_INTERVAL = 60
local lastBagSnapshot = 0
local function MaybeSnapshotBags()
    if not (ns.Database and ns.Database.PersistBagContents) then return end
    local now = GetTime and GetTime() or 0
    if now - lastBagSnapshot < BAG_SNAPSHOT_MIN_INTERVAL then return end
    lastBagSnapshot = now
    ns.Database:PersistBagContents()
end

local talentRefreshTimer
local bagRefreshTimer
local spellRefreshTimer
local gearSetRefreshTimer
local appearanceItemRefreshTimer




local bankOpen = false
local bankScanTimer
local function ScheduleBankScan()
    if bankScanTimer then bankScanTimer:Cancel() end
    bankScanTimer = C_Timer.NewTimer(0.4, function()
        bankScanTimer = nil
        if not (ns.Database and ns.Database.ScanBankContents) then return end
        if ns.Database:ScanBankContents() then
            MarkDynamicCategoryDirty("bank")
        end
    end)
end






local dirtyTimers = {}
local dirtyDue = {}
local function MarkDirtyDebounced(category)
    dirtyDue[category] = GetTime() + 1.0
    if dirtyTimers[category] then return end
    local function fire()
        local left = dirtyDue[category] - GetTime()
        if left > 0.05 then
            dirtyTimers[category] = C_Timer.NewTimer(left, fire)
            return
        end
        dirtyTimers[category] = nil


        if ns.Database and ns.Database.WasProviderRecentlyRun
           and ns.Database:WasProviderRecentlyRun(category, 2.5) then
            return
        end
        MarkDynamicCategoryDirty(category)
    end
    dirtyTimers[category] = C_Timer.NewTimer(1.0, fire)
end
eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)


    if CLASSIC_PROFESSION_EVENTS[event] and ns.Database then
        local changed
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            changed = ns.Database:NoteClassicCast(arg3)
        else
            changed = ns.Database:CaptureClassicRecipes(event:find("^CRAFT") ~= nil, event:find("SHOW$") ~= nil)
        end
        if changed then MarkDirtyDebounced("professions") end
        return
    end
    local dirtyCategory = DIRTY_EVENT_CATEGORY[event]

    if dirtyCategory == "skills" and ns.skillHeadersToggledAt and GetTime() - ns.skillHeadersToggledAt < 1 then return end
    if dirtyCategory then
        MarkDirtyDebounced(dirtyCategory)
        return
    end
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        OnInitialize()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        OnPlayerLogin()
        self.loginHandled = true
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        if ns.Database and ns.Database.InvalidateLFGAvailability then
            ns.Database:InvalidateLFGAvailability()
        end

        if arg2 and not self.loginHandled then
            OnPlayerLogin()
        end
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "TRANSMOG_OUTFITS_CHANGED" then
        if outfitRefreshTimer then outfitRefreshTimer:Cancel() end
        outfitRefreshTimer = C_Timer.NewTimer(0.5, function()
            outfitRefreshTimer = nil
            MarkDynamicCategoryDirty("outfits")
            if ns.UIPins and ns.UIPins.SyncOutfits then
                ns.UIPins.SyncOutfits()
            end
        end)
    elseif event == "TRANSMOG_COLLECTION_UPDATED" then
        if ns.Database and ns.Database.SyncTransmogSetFiltersFromUI then
            ns.Database:SyncTransmogSetFiltersFromUI()
            MarkDynamicCategoryDirty("transmogSets")
            InstallClassFilterHooks()
        end



        if appearanceItemRefreshTimer then appearanceItemRefreshTimer:Cancel() end
        appearanceItemRefreshTimer = C_Timer.NewTimer(0.5, function()
            appearanceItemRefreshTimer = nil
            if ns.Database and ns.Database.RefreshDynamicCategory then
                ns.Database:RefreshDynamicCategory("appearanceItems")
            end
            local frame = ns.Search and ns.Search.GetSearchFrame and ns.Search:GetSearchFrame()
            local editBox = frame and frame.editBox
            if editBox and frame:IsShown() and ns.Search.OnSearchTextChanged then
                ns.Search:OnSearchTextChanged(ns.Search:GetTypedQuery(), true)
            end
        end)
    elseif event == "UPDATE_MACROS" then
        MarkDynamicCategoryDirty("macros")
    elseif event == "HOUSING_STORAGE_UPDATED" then
        MarkDynamicCategoryDirty("housing")
    elseif event == "SPELLS_CHANGED" then
        if spellRefreshTimer then spellRefreshTimer:Cancel() end
        spellRefreshTimer = C_Timer.NewTimer(1.0, function()
            spellRefreshTimer = nil
            MarkDynamicCategoryDirty("abilities")
        end)
    elseif event == "TRAIT_CONFIG_CREATED" or event == "TRAIT_CONFIG_DELETED"
        or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED"
        or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" or event == "CHARACTER_POINTS_CHANGED"
        or event == "PLAYER_TALENT_UPDATE" then


        if talentRefreshTimer then talentRefreshTimer:Cancel() end
        talentRefreshTimer = C_Timer.NewTimer(1.0, function()
            talentRefreshTimer = nil
            MarkDynamicCategoryDirty("talents")
        end)
    elseif event == "BAG_UPDATE_DELAYED" then
        if bagRefreshTimer then bagRefreshTimer:Cancel() end
        bagRefreshTimer = C_Timer.NewTimer(0.5, function()
            bagRefreshTimer = nil
            MarkDynamicCategoryDirty("bags")
            MaybeSnapshotBags()
        end)
        if bankOpen then ScheduleBankScan() end
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true


        ScheduleBankScan()
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        if bankOpen then ScheduleBankScan() end
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
        if bankScanTimer then
            bankScanTimer:Cancel()
            bankScanTimer = nil
        end
    elseif event == "EQUIPMENT_SETS_CHANGED" then
        if gearSetRefreshTimer then gearSetRefreshTimer:Cancel() end
        gearSetRefreshTimer = C_Timer.NewTimer(0.3, function()
            gearSetRefreshTimer = nil
            MarkDynamicCategoryDirty("gearSets")
        end)
    elseif event == "NEW_MOUNT_ADDED" then
        if ns.Database and ns.Database.InvalidateMountCache then
            ns.Database:InvalidateMountCache()
        end
        MarkDirtyDebounced("mounts")
    elseif event == "PLAYER_LEVEL_UP" then
        if ns.Database and ns.Database.OnPlayerLevelUp then
            ns.Database:OnPlayerLevelUp()
        end
    elseif event == "PLAYER_LOGOUT" then

        if ns.Database and ns.Database.PersistBagContents then
            pcall(ns.Database.PersistBagContents, ns.Database)
        end
        if EasyFindDB then
            for _, field in ipairs(RUNTIME_FIELDS) do
                EasyFindDB[field] = nil
            end
        end
    end
end)

function EasyFind:ToggleSearchUI()
    if ns.Search then ns.Search:Toggle() end
end

function EasyFind:FocusSearchUI()
    if ns.Search then ns.Search:Focus() end
end

function EasyFind:ToggleFocusSearchUI()
    if EasyFind.db.enableMapSearch ~= false and WorldMapFrame and WorldMapFrame:IsShown() and ns.MapTab then
        ns.MapTab:Focus()
    elseif ns.Search then
        ns.Search:ToggleFocus()
    end
end

function EasyFind:FocusMapSearch()
    if EasyFind.db.enableMapSearch == false then return end
    if ns.MapTab then ns.MapTab:Focus() end
end




local hiddenChatFrames
local function HideChatFrames()
    hiddenChatFrames = hiddenChatFrames or {}
    local function stash(frame)
        if frame and frame:IsShown() then
            frame:Hide()
            hiddenChatFrames[frame] = true
        end
    end
    for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
        stash(_G["ChatFrame" .. i])
        stash(_G["ChatFrame" .. i .. "Tab"])
        stash(_G["ChatFrame" .. i .. "ButtonFrame"])
        stash(_G["ChatFrame" .. i .. "EditBox"])
    end
    stash(_G["GeneralDockManager"])
    stash(_G["ChatFrameMenuButton"])
    stash(_G["ChatFrameChannelButton"])
    stash(_G["TextToSpeechButton"])
    stash(_G["QuickJoinToastButton"])

    for frame in pairs(ns.chatPieces or {}) do stash(frame) end
end



local chatHideWatch, editModeWatch
local function RehideChatFrames()
    if EasyFind.db.chatFramesHidden then ns.Utils.SafeAfter(0, HideChatFrames) end
end
local function KeepChatFramesHidden()
    if not chatHideWatch then
        chatHideWatch = CreateFrame("Frame")
        chatHideWatch:SetScript("OnEvent", RehideChatFrames)
    end
    chatHideWatch:RegisterEvent("UPDATE_CHAT_WINDOWS")



    local manager = _G["EditModeManagerFrame"]
    if manager and not editModeWatch then
        editModeWatch = CreateFrame("Frame", nil, manager.Border or manager)
        editModeWatch:SetScript("OnHide", RehideChatFrames)
    end
    ns.Utils.SafeAfter(0, HideChatFrames)
end

function EasyFind:RestoreChatFramesHidden()
    if EasyFind.db.chatFramesHidden then KeepChatFramesHidden() end
end

function EasyFind:ToggleChatFrames()
    if hiddenChatFrames then
        for frame in pairs(hiddenChatFrames) do frame:Show() end
        hiddenChatFrames = nil
        EasyFind.db.chatFramesHidden = nil
        if chatHideWatch then chatHideWatch:UnregisterAllEvents() end
        return
    end
    HideChatFrames()
    EasyFind.db.chatFramesHidden = true
    KeepChatFramesHidden()
end




local function TrackerFrame()


    return _G["ObjectiveTrackerFrame"] or _G["WatchFrame"] or _G["QuestWatchFrame"]
end


local trackerPieces, pieceWatches = {}, {}


local trackerStash = {}
local trackerHideWatch, trackerEditModeWatch, trackerCombatWatch
local ApplyTracker

local function Locked(frame)
    return InCombatLockdown() and frame:IsProtected()
end
local function AfterCombat()
    if not trackerCombatWatch then
        trackerCombatWatch = CreateFrame("Frame")
        trackerCombatWatch:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            ApplyTracker()
        end)
    end
    trackerCombatWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
end
local function Stash(frame)
    if not frame:IsShown() then return end
    if Locked(frame) then return AfterCombat() end
    frame:Hide()
    trackerStash[frame] = true
end
local function HideTracker()
    local manager = _G["EditModeManagerFrame"]
    if manager and manager:IsShown() then return end
    local t = TrackerFrame()
    if t then Stash(t) end
    for frame in pairs(trackerPieces) do Stash(frame) end
    EasyFind.API.Fire("easyfind", "trackerChanged")
end
local function ShowTracker()
    for frame in pairs(trackerStash) do
        if Locked(frame) then
            AfterCombat()
        else
            trackerStash[frame] = nil
            local show = trackerPieces[frame]
            if type(show) == "function" then xpcall(show, ns.Utils.ErrorHandler) else frame:Show() end
        end
    end
    EasyFind.API.Fire("easyfind", "trackerChanged")
end
ApplyTracker = function()
    if EasyFind.db.objectiveTrackerHidden then HideTracker() else ShowTracker() end
end


local function RehideTracker()
    if EasyFind.db.objectiveTrackerHidden then HideTracker() end
end
local function WatchTracker()



    local t = TrackerFrame()
    if t and not trackerHideWatch then
        trackerHideWatch = CreateFrame("Frame", nil, t)
        trackerHideWatch:SetScript("OnShow", RehideTracker)
    end


    for frame in pairs(trackerPieces) do
        if not pieceWatches[frame] then
            pieceWatches[frame] = CreateFrame("Frame", nil, frame)
            pieceWatches[frame]:SetScript("OnShow", function()
                if EasyFind.db.objectiveTrackerHidden then Stash(frame) end
            end)
        end
    end
    local manager = _G["EditModeManagerFrame"]
    if manager and not trackerEditModeWatch then
        trackerEditModeWatch = CreateFrame("Frame", nil, manager.Border or manager)
        trackerEditModeWatch:SetScript("OnHide", RehideTracker)
    end
end

function EasyFind:RestoreObjectiveTrackerHidden()
    if not EasyFind.db.objectiveTrackerHidden then return end
    WatchTracker()
    ns.Utils.SafeAfter(0, HideTracker)
end

function ns.AddTrackerPiece(frame, show)
    trackerPieces[frame] = show or true
    if EasyFind.db and EasyFind.db.objectiveTrackerHidden then
        WatchTracker()
        HideTracker()
    end
end

function EasyFind:ToggleObjectiveTracker()
    if not TrackerFrame() then return end
    if EasyFind.db.objectiveTrackerHidden then
        EasyFind.db.objectiveTrackerHidden = nil
        ShowTracker()
        return
    end
    EasyFind.db.objectiveTrackerHidden = true
    WatchTracker()

    HideTracker()
end

function EasyFind:OpenOptions()
    if ns.RequestOptionsPanel() and ns.Options then ns.Options:Toggle() end
end

function EasyFind:ClearAll()
    if ns.Highlight then
        ns.Highlight:ClearAll()
    end
    if ns.MapSearch then
        ns.MapSearch:ClearAll()
        ns.MapSearch:ClearZoneHighlight()
        ns.MapSearch.pendingWaypoint = nil
    end
end

function EasyFind:StartGuide(guideData)
    if ns.Utils.GuideBlockedInCombat and ns.Utils.GuideBlockedInCombat(guideData) then
        return
    end
    local highlight = ns.RequestGuide()
    if highlight then
        highlight:StartGuide(guideData)
    end
end



local LAUNCHER_ICON = "Interface\\AddOns\\EasyFind\\textures\\SpyglassMinimap"

local ADDON_LABEL = "EasyFind"


ns.CHAT_LOGO = "|T" .. LAUNCHER_ICON .. ":0:0:0:0:64:64:2:63:1:64|t "

function EasyFind:Print(msg)
    print(sformat("%s|cFF00FF00EasyFind:|r %s", ns.CHAT_LOGO, msg))
end





ns.brokerLauncherButtons = setmetatable({}, { __mode = "k" })

local minimapButton

local minimapShapes = {
    ["ROUND"]                 = {true, true, true, true},
    ["SQUARE"]                = {false, false, false, false},
    ["CORNER-TOPLEFT"]        = {false, false, false, true},
    ["CORNER-TOPRIGHT"]       = {false, false, true, false},
    ["CORNER-BOTTOMLEFT"]     = {false, true, false, false},
    ["CORNER-BOTTOMRIGHT"]    = {true, false, false, false},
    ["SIDE-LEFT"]             = {false, true, false, true},
    ["SIDE-RIGHT"]            = {true, false, true, false},
    ["SIDE-TOP"]              = {false, false, true, true},
    ["SIDE-BOTTOM"]           = {true, true, false, false},
    ["TRICORNER-TOPLEFT"]     = {false, true, true, true},
    ["TRICORNER-TOPRIGHT"]    = {true, false, true, true},
    ["TRICORNER-BOTTOMLEFT"]  = {true, true, false, true},
    ["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
}




function ns.MinimapEdgeOffset(angle)
    local rad = mrad(angle)
    local cx, cy = mcos(rad), msin(rad)
    local q = 1
    if cx < 0 then q = q + 1 end
    if cy > 0 then q = q + 2 end
    local w = (Minimap:GetWidth()  / 2) + 5
    local h = (Minimap:GetHeight() / 2) + 5
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local quadTable = minimapShapes[shape] or minimapShapes["ROUND"]
    if quadTable[q] then
        return cx * w, cy * h
    end
    local dw = msqrt(2 * w * w) - 10
    local dh = msqrt(2 * h * h) - 10
    return mmax(-w, mmin(cx * dw, w)), mmax(-h, mmin(cy * dh, h))
end

local function PositionMinimapButton(angle)
    if not minimapButton then return end
    local rad = mrad(angle)
    local cx, cy = mcos(rad), msin(rad)

    local q = 1
    if cx < 0 then q = q + 1 end
    if cy > 0 then q = q + 2 end

    local w = (Minimap:GetWidth()  / 2) + 5
    local h = (Minimap:GetHeight() / 2) + 5

    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local quadTable = minimapShapes[shape] or minimapShapes["ROUND"]

    local x, y
    if quadTable[q] then
        x, y = cx * w, cy * h
    else
        local dw = msqrt(2 * w * w) - 10
        local dh = msqrt(2 * h * h) - 10
        x = mmax(-w, mmin(cx * dw, w))
        y = mmax(-h, mmin(cy * dh, h))
    end

    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end


local function SavedMinimapAngle()
    local icon = EasyFind.db.minimapIcon
    return (type(icon) == "table" and icon.minimapPos) or EasyFind.db.minimapButtonAngle or 200
end

local function CreateMinimapButton()
    if minimapButton then return minimapButton end

    local mmBtn = CreateFrame("Button", "EasyFindMinimapButton", Minimap)
    mmBtn:SetSize(31, 31)
    mmBtn:SetFrameStrata("MEDIUM")
    mmBtn:SetFrameLevel(8)

    local border = mmBtn:CreateTexture(nil, "OVERLAY")
    border:SetSize(50, 50)
    border:SetTexture(136430)
    border:SetPoint("TOPLEFT")

    local background = mmBtn:CreateTexture(nil, "BACKGROUND")
    background:SetSize(24, 24)
    background:SetTexture(136467)
    background:SetPoint("CENTER")

    local icon = mmBtn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetTexture(LAUNCHER_ICON)
    icon:SetPoint("CENTER")

    mmBtn:SetHighlightTexture(136477)

    mmBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")



    mmBtn:HookScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            EasyFind._minimapClickActive = true
        end
    end)
    mmBtn:HookScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            EasyFind._minimapClickActive = nil
        end
    end)
    mmBtn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            EasyFind:ToggleSearchUI()
        elseif button == "RightButton" then
            EasyFind:OpenOptions()
        end
    end)

    mmBtn:RegisterForDrag("LeftButton")
    local DRAG_TICK = 0.03
    local function MinimapDragTick(self, elapsed)
        self._dragAccum = (self._dragAccum or 0) + elapsed
        if self._dragAccum < DRAG_TICK then return end
        self._dragAccum = 0
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = mdeg(matan2(cy - my, cx - mx))
        EasyFind.db.minimapButtonAngle = angle
        if type(EasyFind.db.minimapIcon) == "table" then EasyFind.db.minimapIcon.minimapPos = angle end
        PositionMinimapButton(angle)
    end
    mmBtn:SetScript("OnDragStart", function(self)
        self._dragAccum = 0
        self:SetScript("OnUpdate", MinimapDragTick)
    end)
    mmBtn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    mmBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(ADDON_LABEL)
        GameTooltip:AddLine(L["MINIMAP_TT_LEFT_CLICK"], 1, 1, 1)
        GameTooltip:AddLine(L["MINIMAP_TT_RIGHT_CLICK"], 1, 1, 1)
        GameTooltip:AddLine(L["MINIMAP_TT_DRAG"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    mmBtn:SetScript("OnLeave", GameTooltip_Hide)

    minimapButton = mmBtn
    PositionMinimapButton(SavedMinimapAngle())
    return mmBtn
end

function EasyFind:UpdateMinimapButton()
    local icon = ns.minimapIcon
    if icon then
        if EasyFind.db.showMinimapButton then icon:Show(ADDON_LABEL) else icon:Hide(ADDON_LABEL) end
        if minimapButton then minimapButton:Hide() end
        return
    end
    if EasyFind.db.showMinimapButton then
        if not minimapButton then
            CreateMinimapButton()
        end
        minimapButton:Show()
        PositionMinimapButton(SavedMinimapAngle())
    elseif minimapButton then
        minimapButton:Hide()
    end
end











function ns.RegisterDataBroker()
    if not LibStub then return end
    local ok, broker = pcall(LibStub, "LibDataBroker-1.1", true)
    if not (ok and type(broker) == "table" and broker.NewDataObject) then return end
    if broker.GetDataObjectByName and broker:GetDataObjectByName(ADDON_LABEL) then return end
    pcall(broker.NewDataObject, broker, ADDON_LABEL, {
        type = "launcher",
        label = ADDON_LABEL,
        icon = LAUNCHER_ICON,
        OnClick = function(self, button)



            if self then ns.brokerLauncherButtons[self] = true end
            if button == "RightButton" then
                EasyFind:OpenOptions()
            else
                EasyFind:ToggleSearchUI()
            end
        end,
        OnTooltipShow = function(tooltip)
            if not (tooltip and tooltip.AddLine) then return end
            tooltip:AddLine(ADDON_LABEL)
            tooltip:AddLine(L["MINIMAP_TT_LEFT_CLICK"], 1, 1, 1)
            tooltip:AddLine(L["MINIMAP_TT_RIGHT_CLICK"], 1, 1, 1)
        end,
    })
end





function ns.RegisterMinimapIcon()
    if ns.minimapIcon then return true end
    if not LibStub then return false end
    local okIcon, icon = pcall(LibStub, "LibDBIcon-1.0", true)
    local okBroker, broker = pcall(LibStub, "LibDataBroker-1.1", true)
    if not (okIcon and type(icon) == "table" and icon.Register and okBroker and type(broker) == "table"
            and broker.GetDataObjectByName) then
        return false
    end
    local obj = broker:GetDataObjectByName(ADDON_LABEL)
    if not obj then return false end
    local db = EasyFind.db
    if type(db.minimapIcon) ~= "table" then db.minimapIcon = { minimapPos = db.minimapButtonAngle or 200 } end
    db.minimapIcon.hide = db.showMinimapButton == false
    if not pcall(icon.Register, icon, ADDON_LABEL, obj, db.minimapIcon) then return false end
    ns.minimapIcon = icon

    local btn = icon.GetMinimapButton and icon:GetMinimapButton(ADDON_LABEL)
    if btn then ns.brokerLauncherButtons[btn] = true end
    if minimapButton then minimapButton:Hide() end
    return true
end

function EasyFind_OnAddonCompartmentClick(_, button)
    if button == "LeftButton" then
        EasyFind:ToggleSearchUI()
    else
        EasyFind:OpenOptions()
    end
end
