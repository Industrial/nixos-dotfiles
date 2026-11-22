-- DungeonJournal on EasyFind's own rows: a boss, an item or a dungeon
-- EasyFind already finds opens in the journal, and the journal's dungeon
-- quests are rows of their own when no other extension has them. The
-- journal's data is read at runtime through its own namespace and its
-- pages open through its own functions.
local _, ns = ...
local API = EasyFind and EasyFind.API
if not (API and API.VERSION == 1) then return end

local L = ns.L
-- Row decorators, the way onto EasyFind's rows, came in API MINOR 4.
if (API.MINOR or 0) < 4 then
    print("|cff66ccff" .. L["EXT_NAME"] .. ":|r " .. L["NEEDS_EASYFIND"])
    return
end
-- Loaded beside DungeonJournal (OptionalDeps), nothing without it.
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
if not (IsAddOnLoaded and IsAddOnLoaded("ForeverDungeonJournal")) then return end
local FDJ = _G.ForeverDungeonJournal_NS
if not (FDJ and type(FDJ.DB) == "table" and type(FDJ.ORDER) == "table") then
    print("|cff66ccff" .. L["EXT_NAME"] .. ":|r " .. L["NOT_READY"])
    return
end

ns.API, ns.FDJ = API, FDJ
ns.KEY = "dungeonjournal"
ns.ICON = "Interface\\AddOns\\EasyFind_DungeonJournal\\journal"
local KEY, ICON, DB = ns.KEY, ns.ICON, FDJ.DB
local sformat, slower = string.format, string.lower

function ns.SavedVars()
    EasyFindDungeonJournalDB = EasyFindDungeonJournalDB or {}
    return EasyFindDungeonJournalDB
end

-- ==== the journal's words ===================================================

-- Its localizers, when this version has them; the English data otherwise.
local function Localized(fn, ...)
    if type(fn) ~= "function" then return nil end
    local value = fn(...)
    return type(value) == "string" and value ~= "" and value or nil
end

function ns.DungeonName(name)
    return Localized(FDJ.LocalizeDungeonName, name) or name
end

function ns.DungeonField(name, field)
    local raw = DB[name] and DB[name][field]
    return Localized(FDJ.LocalizeDungeonField, name, field, raw) or raw
end

function ns.BossName(name)
    return Localized(FDJ.LocalizeBossName, name) or name
end

function ns.QuestField(quest, field)
    return Localized(FDJ.LocalizeQuestField, quest.id, field, quest[field]) or quest[field]
end

-- The dungeons in the journal's order; a preview page is not one.
function ns.EachDungeon(fn)
    for i = 1, #FDJ.ORDER do
        local name = FDJ.ORDER[i]
        local dungeon = DB[name]
        if dungeon and not dungeon.previewOnly then fn(name, dungeon) end
    end
end

-- A dungeon's real bosses: the trash and recipe rows are its pages, not bosses.
function ns.IsBoss(boss)
    return type(boss) == "table" and boss.name ~= nil and not boss.trash and not boss.recipeTab
end

-- ==== what the journal has, by the keys EasyFind's rows carry ===============

-- Names compared without case, a leading "The" or spaces around.
local function Plain(name)
    return (slower(tostring(name or "")):gsub("^the ", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local index
local function Index()
    if index then return index end
    index = { items = {}, bosses = {}, quests = {}, dungeons = {} }
    local recipes = {}
    ns.EachDungeon(function(name, dungeon)
        index.dungeons[#index.dungeons + 1] = { name = name, plain = Plain(name), shown = Plain(ns.DungeonName(name)),
                                                mapID = dungeon.entrance and dungeon.entrance.mapID }
        for bossIndex, boss in ipairs(dungeon.bosses or {}) do
            if type(boss) == "table" and boss.recipeTab then
                for _, item in ipairs(boss.loot or {}) do
                    if type(item) == "table" and tonumber(item[1]) then recipes[tonumber(item[1])] = true end
                end
            elseif type(boss) == "table" and boss.name then
                local hit = { dungeon = name, bossIndex = bossIndex, bossName = boss.name }
                if ns.IsBoss(boss) then
                    local names = { boss.name, ns.BossName(boss.name) }
                    for _, alias in ipairs(boss.aliases or {}) do names[#names + 1] = alias end
                    for _, n in ipairs(names) do
                        local key = Plain(n)
                        index.bosses[key] = index.bosses[key] or {}
                        index.bosses[key][#index.bosses[key] + 1] = hit
                    end
                end
                local function add(item)
                    local id = tonumber(type(item) == "table" and item[1])
                    if not id then return end
                    local entry = index.items[id]
                    if not entry then
                        entry = { id = id, name = item[2], slot = item[3], dungeon = name, bossIndex = bossIndex, sources = {} }
                        index.items[id] = entry
                    end
                    entry.sources[#entry.sources + 1] = hit
                end
                for _, item in ipairs(boss.loot or {}) do add(item) end
                local shared = FDJ.GetBossSharedLoot and FDJ.GetBossSharedLoot(name, boss)
                for _, item in ipairs(shared or {}) do add(item) end
            end
        end
        for questIndex, quest in ipairs(dungeon.quests or {}) do
            if type(quest) == "table" and quest.id and not index.quests[quest.id] then
                index.quests[quest.id] = { dungeon = name, questIndex = questIndex, quest = quest }
            end
        end
    end)
    for id in pairs(recipes) do
        if index.items[id] then index.items[id].recipe = true end
    end
    return index
end
ns.Index = Index

function ns.ItemFor(itemID)
    return Index().items[tonumber(itemID) or 0]
end

function ns.QuestFor(questID)
    return Index().quests[tonumber(questID) or 0]
end

-- The journal dungeons an EasyFind name stands for: the same name, or one
-- inside the other ("Stockade" in "Stormwind Stockade", a monastery wing
-- under "Scarlet Monastery"); the entrance's map settles a tie.
function ns.DungeonsFor(name, mapID)
    local n = Plain(name)
    if n == "" then return {} end
    local out, onMap = {}, {}
    for _, d in ipairs(Index().dungeons) do
        local p, s = d.plain, d.shown
        if p == n or s == n or p:find(n, 1, true) or n:find(p, 1, true) or s:find(n, 1, true) or n:find(s, 1, true) then
            out[#out + 1] = d.name
            if mapID and d.mapID == mapID then onMap[#onMap + 1] = d.name end
        end
    end
    return #onMap > 0 and onMap or out
end

-- The journal boss behind an EasyFind boss row: by name, the dungeon
-- deciding between namesakes.
function ns.BossFor(name, instanceName)
    local hits = Index().bosses[Plain(name)]
    if not hits then return nil end
    if #hits > 1 and instanceName then
        local dungeons = ns.DungeonsFor(instanceName)
        for _, hit in ipairs(hits) do
            for _, d in ipairs(dungeons) do
                if hit.dungeon == d then return hit end
            end
        end
    end
    return hits[1]
end

-- ==== items =================================================================

local C_Item = C_Item
local requested = {}

-- The client's name once it has it; the journal's name until then.
function ns.ItemName(id, fallback)
    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if name then return name, true end
    if not requested[id] and C_Item.RequestLoadItemDataByID then
        requested[id] = true
        C_Item.RequestLoadItemDataByID(id)
    end
    return fallback, false
end

function ns.InsertChatLink(link)
    if not link then return end
    local active = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if active and active:IsShown() then
        active:Insert(link)
    elseif not (ChatEdit_InsertLink and ChatEdit_InsertLink(link)) and ChatFrame_OpenChat then
        ChatFrame_OpenChat(link)
    end
end

-- ==== places ================================================================

-- The dungeon's entrance as a destination, for the map search and the GPS.
function ns.Entrance(name)
    local dungeon = DB[name]
    local entrance = dungeon and dungeon.entrance
    if not (entrance and entrance.mapID and entrance.x and entrance.y) then return nil end
    return { name = sformat(L["DEST_ENTRANCE_FMT"], ns.DungeonName(name)), mapID = entrance.mapID,
             x = entrance.x, y = entrance.y, step = L["STEP_ENTRANCE"], icon = dungeon.icon, category = KEY }
end

function ns.EntranceMap(name)
    local entrance = DB[name] and DB[name].entrance
    return entrance and entrance.mapID or nil
end

-- ==== the journal window ====================================================

-- Shown through its own toggle; false before its login setup built it.
function ns.ShowJournal()
    local frame = _G.ForeverDungeonJournalFrame
    if not frame then
        print("|cff66ccff" .. L["EXT_NAME"] .. ":|r " .. L["NO_JOURNAL"])
        return false
    end
    if not frame:IsShown() then
        if FDJ.ToggleJournal then FDJ.ToggleJournal() else frame:Show() end
    end
    return true
end

function ns.HideJournal()
    local frame = _G.ForeverDungeonJournalFrame
    if frame and frame:IsShown() then
        if FDJ.ToggleJournal then FDJ.ToggleJournal() else frame:Hide() end
    end
end

function ns.IsJournalShown()
    local frame = _G.ForeverDungeonJournalFrame
    return frame ~= nil and frame:IsShown()
end

function ns.OpenDungeon(name)
    if not (ns.ShowJournal() and FDJ.OpenBossPage) then return false end
    FDJ.OpenBossPage(name)
    return true
end

function ns.OpenBoss(hit)
    if not (hit and ns.ShowJournal() and FDJ.OpenBossPage) then return false end
    FDJ.OpenBossPage(hit.dungeon, hit.bossIndex)
    return true
end

-- The journal's own search-result opener: a boss page with the item
-- focused, a recipe's page of every boss that drops it, or a quest page on
-- the right faction tab.
function ns.OpenResult(result)
    if not (ns.ShowJournal() and FDJ.OpenSearchResult) then return false end
    FDJ.OpenSearchResult(result)
    return true
end

function ns.OpenItem(entry)
    if not entry then return false end
    if entry.recipe then
        return ns.OpenResult({ kind = "item", mode = "recipe", dungeonName = entry.dungeon, itemID = entry.id,
                               displayName = (ns.ItemName(entry.id, entry.name)) })
    end
    return ns.OpenResult({ kind = "item", mode = "bosses", dungeonName = entry.dungeon, bossIndex = entry.bossIndex, itemID = entry.id })
end

function ns.OpenQuest(hit)
    if not hit then return false end
    return ns.OpenResult({ kind = "quest", mode = "quests", dungeonName = hit.dungeon, questIndex = hit.questIndex,
                           questID = hit.quest.id, questFaction = hit.quest.faction })
end

-- ==== refresh ===============================================================

local pending = {}
function ns.Refresh(key)
    if pending[key] then return end
    pending[key] = true
    C_Timer.After(0.5, function()
        pending[key] = nil
        API.RefreshSearchProvider(key)
    end)
end

-- ==== the extension =========================================================

local function Options()
    return {
        { label = L["OPT_HIDE_DONE"], tooltip = L["OPT_HIDE_DONE_TIP"], get = ns.GetHideDone, set = ns.SetHideDone },
        { label = L["OPT_OTHER_FACTION"], tooltip = L["OPT_OTHER_FACTION_TIP"], get = ns.GetOtherFaction, set = ns.SetOtherFaction },
        { label = L["OPT_ALL_CLASSES"], tooltip = L["OPT_ALL_CLASSES_TIP"], get = ns.GetAllClasses, set = ns.SetAllClasses },
    }
end
ns.QuestOptions = Options

API.RegisterExtension({
    id = KEY,
    name = L["EXT_NAME"],
    description = L["EXT_DESC"],
    icon = ICON,
    keywords = { "dj", "dungeon", "dungeons", "journal", "boss", "loot" },
    open = ns.ShowJournal,
    close = ns.HideJournal,
    isOpen = ns.IsJournalShown,
    menu = function()
        if not FDJ.ToggleSettingsPanel then return nil end
        return { { kind = "action", label = L["MENU_OPTIONS"], onClick = FDJ.ToggleSettingsPanel } }
    end,
    settings = function(page, kit)
        if ns.questie then
            kit.Title(page, L["EXT_NAME"], L["SETTINGS_QUESTIE"])
            return
        end
        local below = kit.Title(page, L["EXT_NAME"], L["SETTINGS_HINT"])
        for _, opt in ipairs(Options()) do
            local box = kit.Checkbox(page, opt.label, opt.get, opt.set, opt.tooltip)
            box:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -4)
            below = box
        end
    end,
})

-- The quest rows wait for login: the Questie extension loads after this
-- one, and with it registered the journal's quests ride its rows instead.
local function Settle()
    ns.questie = API.IsExtensionRegistered and API.IsExtensionRegistered("questie") == true
    if not ns.questie and ns.RegisterQuests then ns.RegisterQuests() end
end
ns.Settle = Settle
if IsLoggedIn and IsLoggedIn() then
    C_Timer.After(0, Settle)
else
    local login = CreateFrame("Frame")
    login:RegisterEvent("PLAYER_LOGIN")
    login:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        Settle()
    end)
end
