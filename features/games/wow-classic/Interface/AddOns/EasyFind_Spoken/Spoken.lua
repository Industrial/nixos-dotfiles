-- Spoken's lines on EasyFind's rows: Play and Open in Compendium on the
-- right-click menu of quest, zone, subzone, dungeon, boss and bag item rows.
-- Spoken is read through its globals at runtime; nothing of its data or
-- audio is copied, and what it keeps locked stays locked here.
local _, ns = ...
local API = EasyFind and EasyFind.API
if not (API and API.VERSION == 1) then return end

local L = ns.L
-- Loaded beside Spoken (OptionalDeps), nothing without it.
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
if not (IsAddOnLoaded and IsAddOnLoaded("Spoken")) then return end
local KEY = "spoken"
local ICON = "Interface\\AddOns\\EasyFind_Spoken\\speaker"
ns.KEY = KEY

local sformat = string.format
local slower, supper = string.lower, string.upper
local GetLocale = GetLocale

function ns.Print(text)
    print(sformat("|cff66ccff%s:|r %s", L["EXT_NAME"], text))
end

-- Spoken's parts, each read through its global when the row's menu opens.
local function Quests() return _G.VoiceOver end
local function Places() return _G.SpokenPlaces end
local function Readables() return _G.SpokenReadables end
-- Bosses: SpokenBossesAddon from Spoken 3.7.0, SpokenNPCs before it.
local function Bosses() return _G.SpokenBossesAddon or _G.SpokenNPCs end

local function PartOn(key)
    local Spoken = _G.Spoken
    return not (Spoken and Spoken.IsPartOn) or Spoken:IsPartOn(key)
end

-- The line at the head of Spoken's queue, speaking or paused, or nil.
local function NowPlaying()
    local Spoken = _G.Spoken
    return Spoken and Spoken.GetNowPlaying and Spoken:GetNowPlaying() or nil
end

-- ==== what a row stands for ==================================================

-- Dungeon and raid instance maps by their name, in English and the client's
-- language, from Spoken's shared dungeon table. Built on first use.
local dungeonMaps
local function DungeonMap(name)
    if type(name) ~= "string" then return nil end
    if not dungeonMaps then
        dungeonMaps = {}
        local locale = GetLocale()
        local dungeons = _G.SpokenDungeons and SpokenDungeons.dungeons or {}
        for map, entry in pairs(dungeons) do
            if entry[1] then dungeonMaps[slower(entry[1])] = map end
            if entry[locale] then dungeonMaps[slower(entry[locale])] = map end
        end
    end
    return dungeonMaps[slower(name)]
end

-- A boss's key in Spoken's data, by its name on the instance `map`.
local bossKeys = {}
local function BossKey(map, name)
    if not (map and type(name) == "string") then return nil end
    local byMap = bossKeys[map]
    if not byMap then
        byMap = {}
        bossKeys[map] = byMap
        local locale = GetLocale()
        local bosses = _G.SpokenBosses and SpokenBosses.maps and SpokenBosses.maps[map] or {}
        for _, entry in ipairs(bosses) do
            if entry[1] then byMap[slower(entry[1])] = entry.key end
            if entry[locale] then byMap[slower(entry[locale])] = entry.key end
        end
    end
    return byMap[slower(name)]
end

-- A subzone's story key and the map it is kept under, by the zone the row
-- names it in; false where Spoken has no story for it.
local areaKeys = {}
local function AreaStory(mapID, name)
    local P = Places()
    if not (P and P.GetSubzoneLore and mapID and type(name) == "string") then return nil end
    local byMap = areaKeys[mapID]
    if not byMap then
        byMap = {}
        areaKeys[mapID] = byMap
    end
    local found = byMap[name]
    if found == nil then
        local entry, key, storyMap = P:GetSubzoneLore(mapID, name)
        found = entry and key and storyMap and { storyMap, key } or false
        byMap[name] = found
    end
    return found or nil
end

-- A readable by its title: its book and first page, as Spoken's index files them.
local function Readable(name)
    local R = Readables()
    local data = _G.SpokenReadablesData
    local titles = data and data.index
    local pages = titles and type(name) == "string" and titles[name]
    local first = pages and pages[1]
    if not (first and R and R.PlaceOf) then return nil end
    for _, pageId in pairs(first) do
        local book = R:PlaceOf(pageId)
        if book then return book, pageId end
    end
    return nil
end

-- What Spoken can say for a row: its kind and the keys its part uses, or nil.
-- Cheap: table lookups, so the decorator can ask it for every shown row.
local function Resolve(row)
    local questId = row.questId
    if questId then
        local Q = Quests()
        local tab = Q and Q.QuestsTab
        if tab and tab.Lists and tab:Lists(questId) and PartOn("quests") then return "quest", questId end
        return nil
    end
    -- A boss row: EasyFind's own (category Boss, instanceName) or an extension's (bossName, dungeon).
    if row.bossName or (row.category == "Boss" and row.instanceName) then
        local map = DungeonMap(row.dungeon) or DungeonMap(row.instanceName)
        local key = BossKey(map, row.bossName) or BossKey(map, row.name)
        local N = Bosses()
        if key and N and N.StoryClip and PartOn("bosses") and N:StoryClip(map, key) then return "boss", map, key end
        return nil
    end
    local P = Places()
    if P and PartOn("places") then
        if row.isZone and row.mapID and P.GetLore and P:GetLore(row.mapID) then return "place", row.mapID end
        if row.category == "subzone" then
            local story = AreaStory(row.mapID, row.name)
            if story then return "place", story[1], story[2] end
        end
        if row.isDungeonEntrance or row.dungeon then
            local map = DungeonMap(row.dungeon) or DungeonMap(row.name)
            local entry = map and _G.SpokenDungeons and SpokenDungeons.dungeons[map]
            local story = entry and entry.story
            if story and P.Subzones and P.Subzones[story[1]] and P.Subzones[story[1]][story[2]] then
                return "place", story[1], story[2]
            end
        end
    end
    if row.itemID and PartOn("readables") then
        local book, pageId = Readable(row.name)
        if book then return "book", book, pageId end
    end
    return nil
end
ns.Resolve = Resolve

-- ==== each kind: locked, voiced, playing, play, open ==========================

local KINDS = {}

KINDS.quest = {
    locked = function(id)
        local tab = Quests().QuestsTab
        if not (tab.Has and tab:Has(id)) then return L["LOCK_QUEST"] end
    end,
    voiced = function(id)
        local Q = Quests()
        return Q.DataModules:PrepareSound({ event = Q.Enums.SoundEvent.QuestAccept, questID = id }) and true or false
    end,
    playing = function(id)
        local head = NowPlaying()
        return head ~= nil and head.questID == id
    end,
    -- The offer, named and pictured for its giver, as the quest log's Play queues it.
    play = function(id)
        local Q = Quests()
        local tab, Enums, Data = Q.QuestsTab, Q.Enums, Q.DataModules
        local kind, speaker = Data:GetQuestLogQuestGiverTypeAndID(id)
        local name = speaker and Data:GetObjectName(kind, speaker) or tab:Title(id)
        local guid = speaker and Enums.GUID:CanHaveID(kind) and Q.Utils:MakeGUID(kind, speaker) or nil
        local words = _G.SpokenQuestsText and SpokenQuestsText[id]
        local text = words and words.accept
        if text and tab.Fill then text = tab:Fill(text) end
        Q.Player:PlayNow({ event = Enums.SoundEvent.QuestAccept, questID = id, title = tab:Title(id), name = name,
                           unitGUID = guid, unitIsObjectOrItem = speaker ~= nil and not Enums.GUID:IsCreature(kind),
                           text = text, origin = "EasyFind" })
    end,
    stop = function() _G.Spoken:Skip() end,
    open = function(id) Quests().QuestsTab:Open(id) end,
}

KINDS.place = {
    locked = function(map, key)
        local P = Places()
        if P.IsLocked and P:IsLocked(map, key) then return L["LOCK_PLACE"] end
    end,
    voiced = function(map, key) return Places():HasAudio(map, key) end,
    playing = function(map, key)
        local P = Places()
        return P.IsPlayingLore ~= nil and P:IsPlayingLore(map, key)
    end,
    play = function(map, key) Places():PlayLore(map, key) end,
    stop = function() Places():StopLore() end,
    open = function(map, key) Places():ShowLoreFor(map, key) end,
}

KINDS.book = {
    locked = function(book)
        local R = Readables()
        if R.CompendiumHas and not R:CompendiumHas(book) then return L["LOCK_BOOK"] end
    end,
    voiced = function(book)
        local R = Readables()
        local entry = R:BookById(book)
        for _, pageId in ipairs(entry and entry.pages or {}) do
            if R:HasAudio(pageId) then return true end
        end
        return false
    end,
    playing = function(book) return Readables():IsNarrating(book) end,
    -- Read from its first page; browsing, so it starts now and in a battleground too.
    play = function(_, pageId) Readables():PlayFrom(pageId, true, true) end,
    stop = function(book) Readables():StopReading(book) end,
    open = function(book) Readables():ShowReadables(book) end,
}

-- A boss's story is heard from the Places and Bosses pack, else read as words in the narrator.
KINDS.boss = {
    locked = function(map, key)
        local N = Bosses()
        local settings = _G.SpokenBossesSettings or _G.SpokenNPCsSettings
        local unlocked = settings and settings.unlockUnfound == true
        if not unlocked and N.IsBossFound and not N:IsBossFound(map, key) then return L["LOCK_BOSS"] end
    end,
    voiced = function(map, key)
        local N, Spoken = Bosses(), _G.Spoken
        if N.GetAudioClip and N:GetAudioClip(map, key) then return true end
        return Spoken.ShowsNarratorFor == nil or Spoken:ShowsNarratorFor("bosses")
    end,
    playing = function(map, key)
        local head = NowPlaying()
        return head ~= nil and head.key == "boss:" .. map .. ":" .. key
    end,
    play = function(map, key)
        local source = _G.Spoken:GetSource("bosses")
        local clip = Bosses():StoryClip(map, key)
        if source and clip then source:PlayNow(clip) end
    end,
    stop = function() _G.Spoken:Skip() end,
    open = function() Bosses():ShowBosses() end,
    unvoicedTip = L["NO_NARRATOR"],
}

-- ==== Spoken's Unlock switches ===============================================

-- Each kind's Compendium tab, whose Unlock switch is the one Spoken's own page shows.
local TABS = { quest = "quests", place = "places", book = "readables", boss = "bosses" }
local KINDS_ORDER = { "quest", "place", "book", "boss" }

local function Unlock(kind)
    local C = _G.SpokenCompendium
    local tab = C and C.tabs and C.tabs[TABS[kind]]
    local unlock = tab and tab.unlock
    return unlock and unlock.get and unlock.set and unlock or nil
end
ns.Unlock = Unlock

local function UnlockRow(kind)
    return { kind = "check", label = L["MENU_UNLOCK_" .. supper(kind)], tooltip = L["TT_UNLOCK"],
             get = function() local u = Unlock(kind) return u ~= nil and u.get() == true end,
             set = function(on) local u = Unlock(kind) if u then u.set(on == true) end end }
end

-- ==== the row's menu =========================================================

local function Applies(row)
    return Resolve(row) ~= nil
end

local function Menu(row)
    local kind, a, b = Resolve(row)
    if not kind then return nil end
    local K = KINDS[kind]
    local rows = {}
    if K.playing(a, b) then
        rows[1] = { kind = "action", label = L["MENU_STOP"], onClick = function() K.stop(a, b) end }
    else
        local lock = K.locked(a, b)
        local reason = lock
        if not reason and not K.voiced(a, b) then reason = K.unvoicedTip or L["NO_VOICE"] end
        rows[1] = { kind = "action", label = L["MENU_PLAY"], tooltip = reason, disabled = reason ~= nil,
                    onClick = function() K.play(a, b) end }
        -- Kept until found: Spoken's own Unlock switch, right under the greyed Play.
        if lock and Unlock(kind) then rows[2] = UnlockRow(kind) end
    end
    -- Another window opens: the bar steps aside, as after a chosen result.
    if _G.SpokenCompendium then
        rows[#rows + 1] = { kind = "action", label = L["MENU_OPEN"], closes = true, onClick = function() K.open(a, b) end }
    end
    return rows
end
ns.Menu = Menu

local stopRows = { { name = L["STOP_ALL"], icon = ICON, keywords = { "stop", "spoken", "narration", "narrator", "voice" } } }
local function StopRows() return stopRows end

-- The Extensions tab's Spoken page: the four Unlock switches, Spoken's own.
local function Settings(page, kit)
    local below = kit.Title(page, L["EXT_NAME"], L["SETTINGS_HINT"])
    for _, kind in ipairs(KINDS_ORDER) do
        if Unlock(kind) then
            local row = UnlockRow(kind)
            local box = kit.Checkbox(page, row.label, row.get, row.set, row.tooltip)
            box:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -8)
            below = box
        end
    end
end
ns.Settings = Settings

API.RegisterExtension({
    id = KEY,
    name = L["EXT_NAME"],
    description = L["EXT_DESC"],
    icon = ICON,
    keywords = { "spoken", "voice", "voiceover", "narrator", "lore" },
    settings = Settings,
})

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    local Spoken = _G.Spoken
    if not (Spoken and Spoken.IsCompatible and Spoken:IsCompatible(1)) then
        ns.Print(L["NOT_READY_SPOKEN"])
        return
    end
    if not API.RegisterRowDecorator then
        ns.Print(L["NOT_READY_EASYFIND"])
        return
    end
    -- One entry per extension on the row menu: ours is the Spoken flyout.
    API.RegisterRowDecorator({ id = KEY, label = L["EXT_NAME"], applies = Applies, menu = Menu, submenu = true })
    -- One row, found only by typing it: everything Spoken has queued, gone.
    if Spoken.StopAll and API.RegisterSearchProvider then
        API.RegisterSearchProvider({
            key = KEY, category = "Spoken", label = L["EXT_NAME"], extension = KEY, eager = true,
            rows = StopRows, select = function() _G.Spoken:StopAll() end,
        })
    end
    ns.ready = true
end)
