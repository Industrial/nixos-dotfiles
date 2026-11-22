-- Settings panel (right-click the minimap button, or /dj options).
-- Also owns the two "auto-hide" rules for the dungeon list on the home page.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

-- Panel text follows the journal's language choice (Auto = client language).
local function L(key, ...)
    if FDJ.L then return FDJ.L(key, ...) end
    return key
end

local function Store()
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    return ForeverDungeonJournalDB
end

local function Plain(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
    return v
end

-- ---------------------------------------------------------------------------
-- Auto-hide rules
-- ---------------------------------------------------------------------------
local function PlayerLevel()
    if type(UnitLevel) ~= "function" then return nil end
    local ok, level = pcall(UnitLevel, "player")
    level = ok and Plain(level) or nil
    return type(level) == "number" and level or nil
end

local function PlayerFaction()
    if type(UnitFactionGroup) ~= "function" then return nil end
    local ok, faction = pcall(UnitFactionGroup, "player")
    return ok and Plain(faction) or nil
end

local function PlayerClass()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    token = ok and Plain(token) or nil
    return type(token) == "string" and token:upper() or nil
end

-- "29-38" -> 38
local function MaxDungeonLevel(dungeon)
    local text = dungeon and dungeon.level
    if type(text) ~= "string" then return nil end
    local top
    for number in text:gmatch("%d+") do top = tonumber(number) end
    return top
end

-- True when the character has handed in every quest of this dungeon that it
-- can actually take (own faction, own class). False when there are none.
-- (questdone: a quest ready to turn in is not done yet.)
local function AllQuestsDone(dungeon)
    if not FDJ.QuestTurnedIn then return false end
    local faction, class = PlayerFaction(), PlayerClass()
    if not faction then return false end
    local count = 0
    for _, quest in ipairs(dungeon.quests or {}) do
        local forFaction = quest.faction == nil or quest.faction == "Both"
            or quest.faction == "Neutral" or quest.faction == faction
        -- otherclass (2.0.8): another class's quest (or a profession the
        -- character doesn't have) never counts, "Show all ..." on or not
        local forClass = not quest.classOnly
            or (class and FDJ.QuestClassMatches(quest.classOnly, class)) -- (twoclasses)
        local forProfession = not quest.profession
            or not FDJ.PlayerHasProfession or FDJ.PlayerHasProfession(quest.profession)
        if forFaction and forClass and forProfession and not quest.hideFromMainList and not quest.repeatable and quest.id
            and not (FDJ.IsQuestLost and FDJ.IsQuestLost(quest)) then -- a lost quest doesn't count
            count = count + 1
            if not FDJ.QuestTurnedIn(quest.id) then return false end
        end
    end
    return count > 0
end

-- "29-38" -> 29, 38; "55+" -> 55, nil
local function DungeonLevelRange(dungeon)
    local text = dungeon and dungeon.level
    if type(text) ~= "string" then return nil end
    local low, top
    for number in text:gmatch("%d+") do
        if not low then low = tonumber(number) else top = tonumber(number) end
    end
    return low, top
end

-- devlevel (dev, not in the release; M 16 Nov 2026): /dj level 1-60 shows
-- the dungeon list as a character of that level sees it.
local function ListLevel()
    return FDJ.devLevel or PlayerLevel()
end

FDJ.DungeonLevelRange = DungeonLevelRange
FDJ.ListLevel = ListLevel

-- keepshown (2.0.10, M 17 Nov 2026; Discord report by HonestAuntyElle: an
-- auto-hidden dungeon could not be shown again in Hide Dungeons, whatever
-- was clicked): dungeons the player chose to show in Hide Dungeons although
-- an auto-hide option would hide them. Per character, like the dungeons
-- hidden by hand.
function FDJ.ShownDungeons()
    ForeverDungeonJournalCharacterDB = ForeverDungeonJournalCharacterDB or {}
    local char = ForeverDungeonJournalCharacterDB
    if type(char.shownDungeons) ~= "table" then char.shownDungeons = {} end
    return char.shownDungeons
end

-- Which auto-hide option hides a dungeon (its option's label key), or nil.
-- ignoreLevelRange (levelempty, 2.0.9): as if "Show only my level range" were off
-- only (rehide): check just that one option (its saved setting's name)
local function AutoHideReason(dungeonName, ignoreLevelRange, only)
    local db = Store()
    if not db.autoHideOutleveled and not db.autoHideQuestsDone and not db.onlyMyLevelRange then return nil end
    if only then
        db = { [only] = db[only] }
    end
    local dungeon = FDJ.DB and FDJ.DB[dungeonName]
    if not dungeon then return nil end

    -- Never hide the dungeon the player is standing in.
    if FDJ.CurrentDungeon then
        local ok, current = pcall(FDJ.CurrentDungeon)
        if ok and current == dungeonName then return nil end
    end

    if db.autoHideOutleveled then
        local level, top = ListLevel(), MaxDungeonLevel(dungeon)
        if level and top and level > top then return "OPT_HIDE_OUTLEVELED" end
    end
    -- levelrange (2.0.9, M 16 Nov 2026: "players can choose to show only
    -- dungeons in their range level"): only those whose level range (the
    -- Looking For Group panel's) has the character's level in it. Off by
    -- default. A dungeon with no range given always shows.
    if db.onlyMyLevelRange and not ignoreLevelRange then
        local level = ListLevel()
        local low, top = DungeonLevelRange(dungeon)
        if level and low and (level < low or (top and level > top)) then return "OPT_MY_LEVEL_RANGE" end
    end
    if db.autoHideQuestsDone then
        local ok, done = pcall(AllQuestsDone, dungeon)
        if ok and done then return "OPT_HIDE_QUESTS_DONE" end
    end
    return nil
end

-- ignoreShown (keepshown): as if the player had not chosen to show it
function FDJ.IsDungeonAutoHidden(dungeonName, ignoreLevelRange, ignoreShown)
    if not ignoreShown and FDJ.ShownDungeons()[dungeonName] then return false end
    return AutoHideReason(dungeonName, ignoreLevelRange) ~= nil
end
function FDJ.DungeonAutoHideReason(dungeonName)
    return AutoHideReason(dungeonName)
end

-- rehide (2.0.10, M 17 Nov 2026: "if the auto hide option is untoggled and
-- retoggled, the dungeons get hidden again, like a reset"): turning an
-- auto-hide option on drops the "show it anyway" picks for the dungeons
-- that option hides, so they are hidden again.
local function RehideFor(option)
    local shown = FDJ.ShownDungeons()
    for dungeonName in pairs(shown) do
        if AutoHideReason(dungeonName, nil, option) then shown[dungeonName] = nil end
    end
end

-- ---------------------------------------------------------------------------
-- Panel
-- ---------------------------------------------------------------------------
local panel

local OPTIONS = {
    { header = "OPT_UI" },
    -- exporttab (2.1.1, M 20 Nov 2026: "I don't like the export button like
    -- this. Just make an export tab before Discord"): the character code is
    -- now on its own Export tab (BuildExportPage), not a button here.
    -- bindtop (2.0.11): the key bind first on General, so players see it at once.
    { keybind = true, label = "OPT_BIND" },
    -- resizemode (2.0.10, M 17 Nov 2026): opens the journal with a handle on
    -- each corner to drag it bigger (Systems/Resize.lua)
    {
        buttons = {
            { label = "OPT_RESIZE", tip = "OPT_RESIZE_TIP",
                click = function() if FDJ.StartResizeMode then FDJ.StartResizeMode() end end },
            -- resetsize (M 17 Nov 2026): the normal size and scale again
            { label = "OPT_RESET_SIZE", tip = "OPT_RESET_SIZE_TIP",
                click = function() if FDJ.ResetJournalSize then FDJ.ResetJournalSize() end end },
        },
    },
    {
        label = "OPT_HIDE_ITEM_LINE",
        tip = "OPT_HIDE_ITEM_LINE_TIP",
        get = function() return Store().itemSourceStrip == false end,
        set = function(on) Store().itemSourceStrip = not on end,
    },
    {
        -- autocompare (2.0.6): the journal's item tooltips compare with the
        -- equipped item without Shift (off by default: Shift as before).
        label = "OPT_AUTO_COMPARE",
        tip = "OPT_AUTO_COMPARE_TIP",
        get = function() return Store().autoCompare == true end,
        set = function(on) Store().autoCompare = on and true or nil end,
    },
    {
        label = "OPT_HIDE_MINIMAP",
        tip = "OPT_HIDE_MINIMAP_TIP",
        get = function() return Store().minimapHidden == true end,
        set = function(on)
            if on then
                if FDJ.HideMinimapButton then FDJ.HideMinimapButton() end
            elseif FDJ.ShowMinimapButton then
                FDJ.ShowMinimapButton()
            end
        end,
    },
    {
        label = "OPT_HIDE_LFG",
        tip = "OPT_HIDE_LFG_TIP",
        get = function() return FDJ.IsLFGButtonHidden and FDJ.IsLFGButtonHidden() or false end,
        set = function(on) if FDJ.SetLFGButtonHidden then FDJ.SetLFGButtonHidden(on) end end,
    },
    {
        label = "OPT_HIDE_SLEEPING_BAG",
        tip = "OPT_HIDE_SLEEPING_BAG_TIP",
        get = function() return FDJ.IsSleepingBagHidden and FDJ.IsSleepingBagHidden() or false end,
        set = function(on) if FDJ.SetSleepingBagHidden then FDJ.SetSleepingBagHidden(on) end end,
    },
    {
        -- The Onyxia Attunement icon (Systems/OnyxiaAttunement.lua).
        -- hideonyxia (2.0.15): a Hide option like the others (it was "Show").
        -- Ticked (hidden) by default until the character can start the chain,
        -- then it unticks by itself; any level may untick it to see it sooner.
        -- Ticking it again below the level goes back to that default.
        label = "OPT_HIDE_ONYXIA",
        tip = "OPT_HIDE_ONYXIA_TIP",
        get = function() return not (FDJ.IsOnyxiaIconShown and FDJ.IsOnyxiaIconShown()) end,
        set = function(on) if FDJ.SetOnyxiaIconShown then FDJ.SetOnyxiaIconShown(not on) end end,
        refreshHome = true,
    },
    {
        -- tierhide (2.0.10): the Tier Sets icon (Systems/TierSets.lua)
        label = "OPT_HIDE_TIER",
        tip = "OPT_HIDE_TIER_TIP",
        get = function() return FDJ.IsTierIconHidden and FDJ.IsTierIconHidden() or false end,
        set = function(on) if FDJ.SetTierIconHidden then FDJ.SetTierIconHidden(on) end end,
        refreshHome = true,
    },
    {
        label = "OPT_HIDE_RUNLOG",
        tip = "OPT_HIDE_RUNLOG_TIP",
        get = function() return FDJ.IsRunLogButtonHidden and FDJ.IsRunLogButtonHidden() or false end,
        set = function(on) if FDJ.SetRunLogButtonHidden then FDJ.SetRunLogButtonHidden(on) end end,
    },
    {
        -- exporttitle (2.1.1): the Export button in the title bar (Systems/BugReport.lua)
        label = "OPT_HIDE_EXPORT",
        tip = "OPT_HIDE_EXPORT_TIP",
        get = function() return FDJ.IsExportButtonHidden and FDJ.IsExportButtonHidden() or false end,
        set = function(on) if FDJ.SetExportButtonHidden then FDJ.SetExportButtonHidden(on) end end,
    },
    {
        label = "OPT_HIDE_DUNGEON_MAP",
        tip = "OPT_HIDE_DUNGEON_MAP_TIP",
        get = function() return Store().worldMapOverlay == false end,
        set = function(on)
            if on then Store().worldMapOverlay = false else Store().worldMapOverlay = nil end
            if FDJ.RefreshWorldMapOverlay and WorldMapFrame and WorldMapFrame:IsShown() then pcall(FDJ.RefreshWorldMapOverlay) end
        end,
    },
    -- (useprompt: its Hide option taken out, M 20 Nov 2026: "I don't want it")
    { header = "OPT_DUNGEON_LIST" },
    {
        label = "OPT_RPG_MODE",
        tip = "OPT_RPG_MODE_TIP",
        get = function() return FDJ.IsRPGMode and FDJ.IsRPGMode() or false end,
        set = function(on) if FDJ.SetJournalMode then FDJ.SetJournalMode(on and "rpg" or "gamer") end end,
        refreshHome = true,
    },
    {
        -- Same switch as the WoW Forever emblem at the top left of the
        -- dungeon list (Systems/ForeverFilter.lua), for players who clicked
        -- the emblem by mistake and can't find the other dungeons. Off by
        -- default.
        label = "OPT_FOREVER_ONLY",
        tip = "OPT_FOREVER_ONLY_TIP",
        get = function() return FDJ.IsForeverOnly and FDJ.IsForeverOnly() or false end,
        set = function(on) if FDJ.SetForeverOnly then FDJ.SetForeverOnly(on) end end,
        refreshHome = true,
    },
    {
        -- levelrange (2.0.9): the game's "Show All Level Ranges" turned round
        label = "OPT_MY_LEVEL_RANGE",
        tip = "OPT_MY_LEVEL_RANGE_TIP",
        get = function() return Store().onlyMyLevelRange == true end,
        set = function(on)
            Store().onlyMyLevelRange = on or nil
            if on then RehideFor("onlyMyLevelRange") end
        end,
        refreshHome = true,
    },
    {
        label = "OPT_HIDE_OUTLEVELED",
        tip = "OPT_HIDE_OUTLEVELED_TIP",
        get = function() return Store().autoHideOutleveled == true end,
        set = function(on)
            Store().autoHideOutleveled = on or nil
            if on then RehideFor("autoHideOutleveled") end
        end,
        refreshHome = true,
    },
    {
        label = "OPT_HIDE_QUESTS_DONE",
        tip = "OPT_HIDE_QUESTS_DONE_TIP",
        get = function() return Store().autoHideQuestsDone == true end,
        set = function(on)
            Store().autoHideQuestsDone = on or nil
            if on then RehideFor("autoHideQuestsDone") end
        end,
        refreshHome = true,
    },
    {
        label = "OPT_HIDE_DONE_TICK",
        tip = "OPT_HIDE_DONE_TICK_TIP",
        get = function() return Store().hideDoneTick == true end,
        set = function(on) Store().hideDoneTick = on or nil end,
        refreshHome = true,
    },
    -- questspage (2.0.8, M 15 Nov 2026): the quest options on a page of
    -- their own, after the Dungeon list (moved from it, unchanged).
    { header = "QUESTS" },
    {
        label = "OPT_SHOW_ALL_CLASS",
        tip = "OPT_SHOW_ALL_CLASS_TIP",
        get = function() return Store().showAllClassQuests == true end,
        set = function(on)
            Store().showAllClassQuests = on or nil
            if FDJ.ScheduleQuestRefresh then pcall(FDJ.ScheduleQuestRefresh) end
        end,
        refreshHome = true,
    },
    {
        label = "OPT_SHOW_ALL_PROF",
        tip = "OPT_SHOW_ALL_PROF_TIP",
        get = function() return Store().showAllProfessionQuests == true end,
        set = function(on)
            Store().showAllProfessionQuests = on or nil
            if FDJ.ScheduleQuestRefresh then pcall(FDJ.ScheduleQuestRefresh) end
        end,
        refreshHome = true,
    },
    {
        -- questrowtrial (2.0.8): off: a dungeon's quest list shows the
        -- character's faction only, its crest locked at the top (every
        -- dungeon: FDJ.QUESTROW_ALL).
        label = "OPT_BOTH_FACTIONS",
        tip = "OPT_BOTH_FACTIONS_TIP",
        get = function() return Store().showBothFactions == true end,
        set = function(on)
            Store().showBothFactions = on or nil
            if FDJ.RefreshQuestFactionLock then pcall(FDJ.RefreshQuestFactionLock) end
        end,
    },
    {
        -- chainglowoff (2.0.8, M 15 Nov 2026): no golden glow on a quest
        -- whose chain is done ("Pick it up" stays). Off by default.
        label = "OPT_HIDE_CHAIN_GLOW",
        tip = "OPT_HIDE_CHAIN_GLOW_TIP",
        get = function() return Store().hideChainGlow == true end,
        set = function(on)
            Store().hideChainGlow = on or nil
            if FDJ.ScheduleQuestRefresh then pcall(FDJ.ScheduleQuestRefresh) end
        end,
    },
    {
        -- hideunavailable (2.0.11, M 18 Nov 2026): the quests marked
        -- Unavailable are left out of the quest lists. Off by default; turns
        -- itself off when an update makes one of them available again.
        label = "OPT_HIDE_UNAVAILABLE",
        tip = "OPT_HIDE_UNAVAILABLE_TIP",
        get = function() return Store().hideUnavailableQuests == true end,
        set = function(on)
            Store().hideUnavailableQuests = on or nil
            Store().hideUnavailableSeen = on and FDJ.UnavailableQuestIDs and FDJ.UnavailableQuestIDs() or nil
            if FDJ.ScheduleQuestRefresh then pcall(FDJ.ScheduleQuestRefresh) end
        end,
        refreshHome = true,
    },
    {
        -- hidedone (2.1.3, M 21 Nov 2026: "the hide completed quest ... needed
        -- to be in the option panel under quests"): the quests handed in are
        -- left out of a dungeon's quest list (Core/Journal.lua); the dungeon
        -- list on the main page still counts them. Off by default.
        label = "OPT_HIDE_DONE_QUESTS",
        tip = "OPT_HIDE_DONE_QUESTS_TIP",
        get = function() return Store().hideDoneQuests == true end,
        set = function(on)
            Store().hideDoneQuests = on or nil
            if FDJ.ScheduleQuestRefresh then pcall(FDJ.ScheduleQuestRefresh) end
        end,
    },
    -- lootoptions (2.0.11, M 18 Nov 2026: "add a new Loot section in the
    -- option panel, the options: Hide drop rates, Hide quest item drops").
    { header = "OPT_LOOT" },
    {
        label = "OPT_HIDE_QUEST_DROPS",
        tip = "OPT_HIDE_QUEST_DROPS_TIP",
        get = function() return Store().hideQuestDrops == true end,
        set = function(on)
            Store().hideQuestDrops = on or nil
            if FDJ.RefreshLootNow then pcall(FDJ.RefreshLootNow) end
        end,
    },
    -- The on-screen dungeon tracker (Systems/RunLogUI.lua).
    { header = "OPT_TRACKER" },
    {
        -- locktracker (2.0.11, M 18 Nov 2026): the tracker can't be moved, no
        -- resize corner, no X; right-click still opens Options.
        label = "OPT_TRACK_LOCK",
        tip = "OPT_TRACK_LOCK_TIP",
        get = function() return FDJ.TrackerOption and FDJ.TrackerOption("lock") or false end,
        set = function(on) if FDJ.SetTrackerOption then FDJ.SetTrackerOption("lock", on) end end,
    },
    {
        -- hidetracker (2.0.4): ticked by the tracker's X, unticked by
        -- "/dj tracker"; unticking it here shows the tracker again.
        label = "OPT_TRACK_HIDE",
        tip = "OPT_TRACK_HIDE_TIP",
        get = function() return FDJ.TrackerOption and FDJ.TrackerOption("hide") or false end,
        set = function(on) if FDJ.SetTrackerHidden then FDJ.SetTrackerHidden(on) end end,
    },
    {
        label = "OPT_TRACK_NEVER",
        tip = "OPT_TRACK_NEVER_TIP",
        get = function() return FDJ.TrackerOption and FDJ.TrackerOption("never") or false end,
        set = function(on) if FDJ.SetTrackerOption then FDJ.SetTrackerOption("never", on) end end,
    },
    {
        label = "OPT_TRACK_SOLO",
        tip = "OPT_TRACK_SOLO_TIP",
        get = function() return FDJ.TrackerOption and FDJ.TrackerOption("solo") or false end,
        set = function(on) if FDJ.SetTrackerOption then FDJ.SetTrackerOption("solo", on) end end,
    },
    {
        label = "OPT_TRACK_HIDE_TIME",
        tip = "OPT_TRACK_HIDE_TIME_TIP",
        get = function() return FDJ.TrackerOption and FDJ.TrackerOption("hideTime") or false end,
        set = function(on) if FDJ.SetTrackerOption then FDJ.SetTrackerOption("hideTime", on) end end,
    },
    {
        label = "OPT_TRACK_HIDE_XP",
        tip = "OPT_TRACK_HIDE_XP_TIP",
        get = function() return FDJ.TrackerOption and FDJ.TrackerOption("hideXP") or false end,
        set = function(on) if FDJ.SetTrackerOption then FDJ.SetTrackerOption("hideXP", on) end end,
    },
    {
        label = "OPT_TRACK_HIDE_GOLD",
        tip = "OPT_TRACK_HIDE_GOLD_TIP",
        get = function() return FDJ.TrackerOption and FDJ.TrackerOption("hideGold") or false end,
        set = function(on) if FDJ.SetTrackerOption then FDJ.SetTrackerOption("hideGold", on) end end,
    },
    {
        label = "OPT_TRACK_HIDE_BOSSES",
        tip = "OPT_TRACK_HIDE_BOSSES_TIP",
        get = function() return FDJ.TrackerOption and FDJ.TrackerOption("hideBosses") or false end,
        set = function(on) if FDJ.SetTrackerOption then FDJ.SetTrackerOption("hideBosses", on) end end,
    },
    -- RPG Mode's achievement popups (Systems/RPGMode.lua).
    { header = "OPT_RPG_PAGE" },
    {
        -- the same switch as RPG Mode on the Dungeon list page
        label = "OPT_RPG_ENABLE",
        tip = "OPT_RPG_MODE_TIP",
        get = function() return FDJ.IsRPGMode and FDJ.IsRPGMode() or false end,
        set = function(on) if FDJ.SetJournalMode then FDJ.SetJournalMode(on and "rpg" or "gamer") end end,
        refreshHome = true,
    },
    {
        -- Off: each character keeps its own unlocks. On: every character's
        -- unlocks are shared by the whole account (Systems/RPGMode.lua).
        label = "OPT_RPG_ACCOUNT",
        tip = "OPT_RPG_ACCOUNT_TIP",
        get = function() return FDJ.RPGOption and FDJ.RPGOption("accountWide") or false end,
        set = function(on) if FDJ.SetRPGOption then FDJ.SetRPGOption("accountWide", on) end end,
        refreshHome = true,
    },
    {
        -- showquests (2.0.16): every dungeon's quests shown in RPG Mode, the
        -- cards with their quest count, no quest popups (Systems/RPGMode.lua).
        label = "OPT_RPG_SHOW_QUESTS",
        tip = "OPT_RPG_SHOW_QUESTS_TIP",
        get = function() return FDJ.RPGOption and FDJ.RPGOption("showQuests") or false end,
        set = function(on) if FDJ.SetRPGOption then FDJ.SetRPGOption("showQuests", on) end end,
        refreshHome = true,
    },
    {
        label = "OPT_RPG_HIDE_QUEST",
        tip = "OPT_RPG_HIDE_QUEST_TIP",
        get = function() return FDJ.RPGOption and FDJ.RPGOption("hideQuestPopups") or false end,
        set = function(on) if FDJ.SetRPGOption then FDJ.SetRPGOption("hideQuestPopups", on) end end,
    },
    {
        label = "OPT_RPG_HIDE_BOSS",
        tip = "OPT_RPG_HIDE_BOSS_TIP",
        get = function() return FDJ.RPGOption and FDJ.RPGOption("hideBossPopups") or false end,
        set = function(on) if FDJ.SetRPGOption then FDJ.SetRPGOption("hideBossPopups", on) end end,
    },
    {
        label = "OPT_RPG_MUTE",
        tip = "OPT_RPG_MUTE_TIP",
        get = function() return FDJ.RPGOption and FDJ.RPGOption("mute") or false end,
        set = function(on) if FDJ.SetRPGOption then FDJ.SetRPGOption("mute", on) end end,
    },
    {
        slider = true,
        label = "OPT_RPG_VOLUME",
        tip = "OPT_RPG_VOLUME_TIP",
        min = 0, max = 100, step = 5,
        get = function() return FDJ.RPGOption and FDJ.RPGOption("volume") or 85 end,
        set = function(v) if FDJ.SetRPGOption then FDJ.SetRPGOption("volume", v) end end,
    },
    {
        -- Moving RPG Mode progress to another computer (Systems/ProgressTransfer.lua).
        buttons = {
            { label = "OPT_RPG_EXPORT", tip = "OPT_RPG_EXPORT_TIP",
                click = function() if FDJ.ShowProgressExport then FDJ.ShowProgressExport() end end },
            { label = "OPT_RPG_IMPORT", tip = "OPT_RPG_IMPORT_TIP",
                click = function() if FDJ.ShowProgressImport then FDJ.ShowProgressImport() end end },
        },
    },
}

-- ---------------------------------------------------------------------------
-- Key binding button (same binding as Key Bindings > AddOns > Dungeon Journal)
-- ---------------------------------------------------------------------------
local BINDING = "FOREVERDUNGEONJOURNAL_TOGGLE"
local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true }

local function Say(text) print("|cffd8a83cDungeonJournal:|r " .. text) end

-- "CTRL-SHIFT-L" -> "Ctrl-Shift-L" (the client's own abbreviation shows "c-L").
local MODIFIER_NAMES = { CTRL = "Ctrl", SHIFT = "Shift", ALT = "Alt", META = "Cmd" }
local function PrettyKey(key)
    if not key or key == "" then return nil end
    local parts = {}
    for part in key:gmatch("[^%-]+") do parts[#parts + 1] = part end
    if key:sub(-1) == "-" then parts[#parts + 1] = "-" end
    local last = table.remove(parts) or key
    local out = {}
    for _, mod in ipairs(parts) do out[#out + 1] = MODIFIER_NAMES[mod] or mod end
    local name = last
    if #last > 1 and _G["KEY_" .. last] then name = _G["KEY_" .. last] end
    out[#out + 1] = name
    return table.concat(out, "-")
end

local function BindingText()
    if not GetBindingKey then return nil end
    local key1, key2 = GetBindingKey(BINDING)
    if key1 and key2 then return PrettyKey(key1) .. ", " .. PrettyKey(key2) end
    return PrettyKey(key1)
end

local function SaveBindingSet()
    if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
end

local function ClearJournalKeys()
    if not GetBindingKey or not SetBinding then return end
    local key1, key2 = GetBindingKey(BINDING)
    if key1 then SetBinding(key1) end
    if key2 then SetBinding(key2) end
end

local function CreateKeybindRow(parent, option, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    label:SetPoint("TOPLEFT", 34, y - 4)
    label:SetText(L(option.label))
    panel.texts[#panel.texts + 1] = { label, option.label }

    -- Same look as the game's own key binding buttons (Options > Keybindings):
    -- near-black fill, thin grey rounded edge, white key text, grey "Not Bound".
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(156, 21)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 252, y)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 9,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button:SetBackdropColor(0.085, 0.066, 0.074, 1)
    button:SetBackdropBorderColor(0.46, 0.45, 0.43, 1)
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetPoint("TOPLEFT", 2, -2)
    hover:SetPoint("BOTTOMRIGHT", -2, 2)
    hover:SetTexture("Interface\\Buttons\\WHITE8X8")
    hover:SetVertexColor(1, 1, 1, 0.07)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button.text = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    button.text:SetPoint("LEFT", 6, 0)
    button.text:SetPoint("RIGHT", -6, 0)
    button.text:SetJustifyH("CENTER")
    button.text:SetWordWrap(false)

    local capturing = false
    local pending -- key combination waiting for its key to be released
    local function Refresh()
        local bound = BindingText()
        local text = capturing and L("OPT_PRESS_KEY") or bound or L("OPT_NOT_BOUND")
        button.text:SetText(text)
        if capturing then
            button.text:SetTextColor(1.00, 0.82, 0.00)
            button:SetBackdropBorderColor(0.95, 0.95, 0.92, 1)
        elseif bound then
            button.text:SetTextColor(1, 1, 1)
            button:SetBackdropBorderColor(0.46, 0.45, 0.43, 1)
        else
            button.text:SetTextColor(0.50, 0.49, 0.47)
            button:SetBackdropBorderColor(0.46, 0.45, 0.43, 1)
        end
    end
    local function Stop()
        capturing = false
        pending = nil
        button:EnableKeyboard(false)
        if button.SetPropagateKeyboardInput then button:SetPropagateKeyboardInput(true) end
        Refresh()
    end

    button:SetScript("OnClick", function(_, mouse)
        if InCombatLockdown and InCombatLockdown() then
            Say(L("OPT_NO_COMBAT"))
            return
        end
        if mouse == "RightButton" then
            ClearJournalKeys()
            SaveBindingSet()
            Stop()
            return
        end
        if capturing then Stop() return end
        capturing = true
        button:EnableKeyboard(true)
        if button.SetPropagateKeyboardInput then button:SetPropagateKeyboardInput(false) end
        Refresh()
    end)
    button:SetScript("OnKeyDown", function(_, key)
        if not capturing then return end
        if key == "ESCAPE" then Stop() return end
        if MODIFIER_KEYS[key] then return end
        local combo = ""
        if IsControlKeyDown and IsControlKeyDown() then combo = combo .. "CTRL-" end
        if IsShiftKeyDown and IsShiftKeyDown() then combo = combo .. "SHIFT-" end
        if IsAltKeyDown and IsAltKeyDown() then combo = combo .. "ALT-" end
        combo = combo .. key
        -- Never take over a key another action already uses (movement,
        -- action bars, ...): SetBinding would silently replace it.
        local current = GetBindingAction and GetBindingAction(combo)
        if current and current ~= "" and current ~= BINDING then
            Say(L("OPT_KEY_TAKEN", PrettyKey(combo)))
            Stop()
            return
        end
        -- Bind only once the key is let go. Binding it while it is still
        -- held makes that same key press open the journal straight away.
        pending = { combo = combo, key = key }
    end)
    button:SetScript("OnKeyUp", function(_, key)
        if not capturing or not pending or key ~= pending.key then return end
        local combo = pending.combo
        ClearJournalKeys()
        if SetBinding then SetBinding(combo, BINDING) SaveBindingSet() end
        Stop()
    end)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L(option.label), 1, 0.82, 0.27)
        GameTooltip:AddLine(L("OPT_BIND_TIP"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    -- Never leave a hidden panel holding the keyboard.
    button:SetScript("OnHide", Stop)

    -- Giving a frame an OnKeyDown script switches its keyboard on, and it
    -- then swallows every key (no movement) until the panel closes. Keep it
    -- off until the button is clicked to record a key.
    button:EnableKeyboard(false)
    if button.SetPropagateKeyboardInput then button:SetPropagateKeyboardInput(true) end
    button.Refresh = Refresh
    return button
end

local function Version()
    local getter = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if getter then
        local ok, version = pcall(getter, "ForeverDungeonJournal", "Version")
        if ok and version then return tostring(version) end
    end
    return ""
end

-- Built after the game's own Options window (WoW Forever):
--   * translucent dark frame with a thin bronze edge and a slim title bar
--     (small gold title, red X);
--   * "Game" / "AddOns"-style tabs over a bronze-edged content box;
--   * on the Options tab, a category list on the left (dark header bar with
--     white text, gold entries, the open one underlined in gold) and the
--     page on the right: big white title, gold rule, gold labels with their
--     boxes in a column; a page with more rows than fit scrolls, with the
--     game's thin scroll bar on its right (2.0.10);
--   * no Close button at the bottom (2.0.9): the red X closes it.
local PANEL_W, PANEL_H = 660, 430
local SIDEBAR_W = 178
local LABEL_X, BOX_X = 34, 300 -- inside a page: label left edge, box column

local BRONZE = { 0.50, 0.39, 0.22 }
local function Edge(frame, size, alpha)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = size or 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropBorderColor(BRONZE[1], BRONZE[2], BRONZE[3], alpha or 1)
end

local function Line(parent, r, g, b, a)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetVertexColor(r, g, b, a or 1)
    return t
end

-- Gold fade used under the open category ("Controls" in the game).
local function GoldFade(tex, fromAlpha, toAlpha)
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    local ok = pcall(function()
        tex:SetGradient("HORIZONTAL", CreateColor(1.00, 0.78, 0.10, fromAlpha), CreateColor(1.00, 0.78, 0.10, toAlpha))
    end)
    if not ok then tex:SetVertexColor(1.00, 0.78, 0.10, (fromAlpha + toAlpha) / 2) end
end

-- Pixel-exact frames built from 1px lines (colours sampled from the game's
-- own Options window). layers: outermost first, each { r, g, b } in 0-255.
local function LinedFrame(frame, layers, drawLayer, openBottom)
    for i, c in ipairs(layers) do
        local d = i - 1
        local r, g, b, a = c[1] / 255, c[2] / 255, c[3] / 255, c[4] or 1
        local function L1()
            local t = frame:CreateTexture(nil, drawLayer or "BORDER")
            t:SetTexture("Interface\\Buttons\\WHITE8X8")
            t:SetVertexColor(r, g, b, a)
            return t
        end
        local top = L1()
        top:SetPoint("TOPLEFT", d, -d); top:SetPoint("TOPRIGHT", -d, -d); top:SetHeight(1)
        local left = L1()
        left:SetPoint("TOPLEFT", d, -d); left:SetPoint("BOTTOMLEFT", d, openBottom and 0 or d); left:SetWidth(1)
        local right = L1()
        right:SetPoint("TOPRIGHT", -d, -d); right:SetPoint("BOTTOMRIGHT", -d, openBottom and 0 or d); right:SetWidth(1)
        if not openBottom then
            local bottom = L1()
            bottom:SetPoint("BOTTOMLEFT", d, d); bottom:SetPoint("BOTTOMRIGHT", -d, d); bottom:SetHeight(1)
        end
    end
end

-- Window edge: dark rim, two gold lines, dark, bronze, brown, black.
local WINDOW_EDGE = {
    { 51, 31, 14 }, { 182, 150, 104 }, { 177, 150, 109 }, { 49, 31, 16 },
    { 112, 76, 38 }, { 59, 41, 25 }, { 10, 7, 6 },
}
local BOX_EDGE = { { 100, 76, 60 }, { 64, 47, 38 } }
local TAB_EDGE = { { 122, 92, 72 }, { 96, 72, 58, 0.8 } }

-- Borrow the real frame art from the game's own Options window
-- (SettingsPanel.NineSlice): same corners, edges and title bar.
local NINE = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }

local function CopyTexture(src, dst)
    local atlas = src.GetAtlas and src:GetAtlas()
    if atlas then
        dst:SetAtlas(atlas, false)
    else
        local tex = src:GetTexture()
        if not tex then return false end
        dst:SetTexture(tex)
        if src.GetTexCoord then dst:SetTexCoord(src:GetTexCoord()) end
    end
    if src.GetHorizTile and dst.SetHorizTile then dst:SetHorizTile(src:GetHorizTile()) end
    if src.GetVertTile and dst.SetVertTile then dst:SetVertTile(src:GetVertTile()) end
    if src.GetVertexColor then dst:SetVertexColor(src:GetVertexColor()) end
    return true
end

local function CopyGameFrameArt(dst)
    local sp = _G.SettingsPanel
    local nine = sp and sp.NineSlice
    if not nine or not nine.TopLeftCorner then return false end
    local holder = CreateFrame("Frame", nil, dst)
    holder:SetAllPoints(dst)
    holder:SetFrameLevel(dst:GetFrameLevel() + 1)
    local made, keyOf = {}, {}
    for _, key in ipairs(NINE) do
        local src = nine[key]
        if src then keyOf[src] = key end
        local hasArt = src and ((src.GetAtlas and src:GetAtlas()) or src:GetTexture())
        if hasArt then
            local layer, sub = src:GetDrawLayer()
            local t = holder:CreateTexture(nil, layer or "BORDER", nil, sub or 0)
            if CopyTexture(src, t) then
                t:SetSize(src:GetWidth(), src:GetHeight())
                made[key] = t
            end
        end
    end
    if not (made.TopLeftCorner and made.TopEdge and made.LeftEdge) then holder:Hide() return false end
    -- Same anchors as the game uses (offsets included), mapped onto our frame.
    for key, t in pairs(made) do
        local src = nine[key]
        for i = 1, src:GetNumPoints() do
            local point, rel, relPoint, x, y = src:GetPoint(i)
            local target = holder
            if rel and keyOf[rel] and made[keyOf[rel]] then target = made[keyOf[rel]] end
            t:SetPoint(point, target, relPoint, x, y)
        end
    end
    dst.fdjNine = holder
    return true
end

-- One-time record of how the game's Options window is built (pieces, atlases,
-- sizes), saved with the addon's settings so the look can be matched exactly.
local function DumpGameOptions()
    local sp = _G.SettingsPanel
    if not sp or not ForeverDungeonJournalDB then return end
    local out, n = {}, 0
    local function Walk(obj, path, depth)
        if n > 400 or depth > 4 then return end
        local function Add(region, p)
            n = n + 1
            if n > 400 then return end
            local line = p .. " [" .. (region.GetObjectType and region:GetObjectType() or "?") .. "]"
            if region.GetAtlas and region:GetAtlas() then line = line .. " atlas=" .. tostring(region:GetAtlas()) end
            if region.GetTexture and region:GetObjectType() == "Texture" and not region:GetAtlas() then line = line .. " tex=" .. tostring(region:GetTexture()) end
            if region.GetSize then local w, h = region:GetSize(); line = line .. string.format(" %.0fx%.0f", w or 0, h or 0) end
            if region.GetText and region:GetObjectType() == "FontString" then line = line .. " text=" .. tostring(region:GetText()) end
            out[#out + 1] = line
        end
        for key, value in pairs(obj) do
            if type(key) == "string" and type(value) == "table" and value.GetObjectType then
                local ok, kind = pcall(value.GetObjectType, value)
                if ok and (kind == "Texture" or kind == "FontString") then
                    Add(value, path .. "." .. key)
                elseif ok and depth < 4 and key ~= "parent" and value ~= obj then
                    Add(value, path .. "." .. key)
                    Walk(value, path .. "." .. key, depth + 1)
                end
            end
        end
    end
    pcall(Walk, sp, "SettingsPanel", 0)
    local function Kids(frame, path)
        if not (frame and frame.GetChildren) then return end
        for i, child in ipairs({ frame:GetChildren() }) do
            if i > 12 then break end
            pcall(Walk, child, path .. "#" .. i, 2)
            for _, r in ipairs({ child:GetRegions() }) do
                if r.GetObjectType and r:GetObjectType() == "Texture" then
                    n = n + 1
                    out[#out + 1] = path .. "#" .. i .. ".region [" .. tostring(r:GetDrawLayer()) .. "] atlas=" .. tostring(r:GetAtlas()) .. " tex=" .. tostring(r:GetTexture()) .. string.format(" %.0fx%.0f", r:GetWidth() or 0, r:GetHeight() or 0)
                end
            end
        end
    end
    pcall(Kids, sp.CategoryList and sp.CategoryList.ScrollBox and sp.CategoryList.ScrollBox.ScrollTarget, "CategoryRow")
    pcall(Kids, sp.Container and sp.Container.SettingsList and sp.Container.SettingsList.ScrollBox and sp.Container.SettingsList.ScrollBox.ScrollTarget, "SettingRow")
    table.sort(out)
    ForeverDungeonJournalDB.fdjOptionsDump = out
end

-- Gold band that fades out on both sides (peak at `split` of the width),
-- like the highlight and rules in the game's Options window.
local function GoldBand(parent, layer, peak, split)
    local f = CreateFrame("Frame", nil, parent)
    local left = f:CreateTexture(nil, layer or "ARTWORK")
    local right = f:CreateTexture(nil, layer or "ARTWORK")
    GoldFade(left, 0, peak)
    GoldFade(right, peak, 0)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT")
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT")
    right:SetPoint("LEFT", left, "RIGHT")
    f:SetScript("OnSizeChanged", function(self, w) left:SetWidth(math.max(1, (w or 0) * (split or 0.5))) end)
    left:SetWidth(40)
    return f
end

local function PageTitle(page, key)
    local title = page:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 22, -18)
    title:SetTextColor(1, 1, 1)
    panel.texts[#panel.texts + 1] = { title, key }
    local rule = GoldBand(page, "ARTWORK", 0.75, 0.3)
    rule:SetPoint("TOPLEFT", 18, -52)
    rule:SetPoint("TOPRIGHT", -18, -52)
    rule:SetHeight(1)
    return -66
end

-- Grey band behind a row while hovered, as in the game's Options window.
local function RowHover(page, y, height)
    local band = page:CreateTexture(nil, "BACKGROUND", nil, 1)
    band:SetPoint("TOPLEFT", 10, y + 2)
    band:SetPoint("TOPRIGHT", -10, y + 2)
    band:SetHeight(height or 32)
    band:SetTexture("Interface\\Buttons\\WHITE8X8")
    band:SetVertexColor(0.62, 0.60, 0.66, 0.16)
    band:Hide()
    return band
end

local function CreateOptionRow(page, option, y)
    local label = page:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    label:SetPoint("TOPLEFT", LABEL_X, y - 7)
    label:SetWidth(BOX_X - LABEL_X - 12)
    label:SetJustifyH("LEFT")
    label:SetText(L(option.label))
    panel.texts[#panel.texts + 1] = { label, option.label }

    local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    FDJ.OwnFonts(check) -- ownfonts (2.0.8)
    check:SetSize(30, 30)
    check:SetPoint("TOPLEFT", BOX_X, y)
    check.option = option
    -- The label counts as part of the box: clicking or hovering it works too.
    check:SetHitRectInsets(-(BOX_X - LABEL_X), 0, 0, 0)
    check:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        pcall(self.option.set, on)
        if self.option.refreshHome and FDJ.RefreshHomeCards then pcall(FDJ.RefreshHomeCards) end
        -- a switch shown on two pages (RPG Mode) ticks on both
        if FDJ.RefreshSettingsChecks then pcall(FDJ.RefreshSettingsChecks) end
    end)
    local band = RowHover(page, y)
    check:SetScript("OnEnter", function(self)
        band:Show()
        label:SetTextColor(1, 1, 1)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L(self.option.label), 1, 0.82, 0.27)
        GameTooltip:AddLine(L(self.option.tip), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function()
        band:Hide()
        label:SetTextColor(1.00, 0.82, 0.00)
        if GameTooltip then GameTooltip:Hide() end
    end)
    panel.checks[#panel.checks + 1] = check
end

-- A row with a slider (0-100%), e.g. Options > RPG Mode > Achievement
-- Popup sound. Letting go of it plays a sample (the RPG fanfare).
local function CreateSliderRow(page, option, y)
    local label = page:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    label:SetPoint("TOPLEFT", LABEL_X, y - 7)
    label:SetJustifyH("LEFT")
    label:SetText(L(option.label))
    panel.texts[#panel.texts + 1] = { label, option.label }

    local slider = CreateFrame("Slider", nil, page, "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(190, 16)
    slider:SetPoint("TOPLEFT", LABEL_X + 4, y - 30)
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetMinMaxValues(option.min or 0, option.max or 100)
    slider:SetValueStep(option.step or 5)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider.option = option
    local value = page:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    value:SetPoint("LEFT", slider, "RIGHT", 12, 0)
    slider.valueText = value
    slider:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v + 0.5)
        self.valueText:SetText(v .. "%")
        if self.fdjSetting then return end
        pcall(self.option.set, v)
    end)
    slider:SetScript("OnMouseUp", function()
        if FDJ.PlayRPGFanfare then pcall(FDJ.PlayRPGFanfare) end
    end)
    slider:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L(self.option.label), 1, 0.82, 0.27)
        GameTooltip:AddLine(L(self.option.tip), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    slider:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    slider.Refresh = function(self)
        local ok, v = pcall(self.option.get)
        self.fdjSetting = true
        self:SetValue(ok and tonumber(v) or 85)
        self.valueText:SetText(math.floor(self:GetValue() + 0.5) .. "%")
        self.fdjSetting = nil
    end
    panel.sliders = panel.sliders or {}
    panel.sliders[#panel.sliders + 1] = slider
end

-- A row of buttons, e.g. Options > RPG Mode > Export Progress / Import Progress.
local function CreateButtonsRow(page, option, y)
    local x = LABEL_X
    for _, spec in ipairs(option.buttons) do
        local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        FDJ.OwnFonts(button) -- ownfonts (2.0.8)
        button:SetSize(spec.width or 150, 24)
        button:SetPoint("TOPLEFT", page, "TOPLEFT", x, y - 6)
        button:SetText(L(spec.label))
        panel.texts[#panel.texts + 1] = { button, spec.label }
        button:SetScript("OnClick", function()
            if spec.click then pcall(spec.click) end
        end)
        button:SetScript("OnEnter", function(self)
            if not GameTooltip or not spec.tip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L(spec.label), 1, 0.82, 0.27)
            GameTooltip:AddLine(L(spec.tip), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        x = x + (spec.width or 150) + 12
    end
end

local function BuildDiscordPage(page)
    local y = PageTitle(page, "OPT_DISCORD")
    local text = page:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    text:SetPoint("TOPLEFT", LABEL_X, y - 10)
    text:SetPoint("RIGHT", page, "RIGHT", -34, 0)
    text:SetJustifyH("LEFT")
    panel.texts[#panel.texts + 1] = { text, "OPT_DISCORD_TEXT" }

    local link = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    link:SetSize(300, 26)
    link:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 6, -22)
    link:SetAutoFocus(false)
    link:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    link:SetScript("OnTextChanged", function(self, user)
        if user then self:SetText(FDJ.DISCORD_LINK or ""); self:HighlightText() end
    end)
    link:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    link:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local hint = page:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", link, "BOTTOMLEFT", -4, -8)
    hint:SetTextColor(0.75, 0.72, 0.66)
    panel.texts[#panel.texts + 1] = { hint, "OPT_DISCORD_COPY" }

    link:SetScript("OnKeyDown", function(self, key)
        if key == "C" and IsControlKeyDown and IsControlKeyDown() then
            C_Timer.After(0.05, function()
                self:ClearFocus()
                hint:SetText(L("OPT_COPIED"))
                hint:SetTextColor(0.25, 1.00, 0.25)
            end)
        end
    end)
    link:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)

    -- Never take the keyboard by itself (it would block key bindings);
    -- clicking the box selects the link for Ctrl+C.
    page:SetScript("OnShow", function()
        link:SetText(FDJ.DISCORD_LINK or "")
        link:ClearFocus()
        hint:SetText(L("OPT_DISCORD_COPY"))
        hint:SetTextColor(0.75, 0.72, 0.66)
    end)
end

-- exporttab (2.1.1, M 20 Nov 2026: "make an export tab before Discord at
-- the top ... everything is going to be in that tab"): what the /dj export
-- window shows, on the Options' own tab: the character's name and quests
-- done, the code (one line; a click selects all of it for Ctrl+C), the
-- website's address to paste it at, and how to copy it. The code is made
-- again each time the tab opens. Like the Discord tab, it never takes the
-- keyboard by itself (it would block key bindings).
local function BuildExportPage(page)
    local y = PageTitle(page, "OPT_EXPORT")
    local info = page:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    info:SetPoint("TOPLEFT", LABEL_X, y - 10)
    info:SetPoint("RIGHT", page, "RIGHT", -34, 0)
    info:SetJustifyH("LEFT")

    local code = CreateFrame("EditBox", nil, page)
    code:SetMultiLine(false)
    code:SetMaxLetters(0)
    code:SetFontObject("ForeverDJ_GameFontHighlightSmall")
    code:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 6, -22)
    code:SetPoint("RIGHT", page, "RIGHT", -40, 0)
    code:SetHeight(22)
    code:SetAutoFocus(false)
    code:SetTextInsets(4, 4, 0, 0)
    if code.SetClipsChildren then code:SetClipsChildren(true) end
    code:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    code:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    code:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
    code:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    code:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    -- Typing into it would only corrupt the code, so put it straight back.
    code:SetScript("OnTextChanged", function(self, byUser)
        if byUser then
            self:SetText(page.code or "")
            self:HighlightText()
        end
    end)
    local codeBg = CreateFrame("Frame", nil, page, "BackdropTemplate")
    codeBg:SetPoint("TOPLEFT", code, -6, 6)
    codeBg:SetPoint("BOTTOMRIGHT", code, 6, -6)
    codeBg:SetFrameLevel(math.max(0, code:GetFrameLevel() - 1))
    if codeBg.SetBackdrop then
        codeBg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        codeBg:SetBackdropColor(0, 0, 0, 0.6)
        codeBg:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
    end

    -- exportgo (2.1.1, M 20 Nov 2026: "the export link ... send the user to
    -- the export option page, with the usual highlight on the code"): the
    -- gold band that pulses on an option row opened from elsewhere
    -- (PulseRow), here on the code's row; FDJ.OpenExportTab asks for it.
    local glow = page:CreateTexture(nil, "BACKGROUND", nil, 2)
    glow:SetPoint("LEFT", page, "LEFT", 10, 0)
    glow:SetPoint("RIGHT", page, "RIGHT", -10, 0)
    glow:SetPoint("TOP", codeBg, "TOP", 0, 5)
    glow:SetPoint("BOTTOM", codeBg, "BOTTOM", 0, -5)
    glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    glow:SetVertexColor(1.00, 0.78, 0.25, 0.35)
    glow:SetAlpha(0)
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.4)
    pulse:SetScript("OnLoop", function(self)
        self.loops = (self.loops or 0) + 1
        if self.loops >= 6 then self:Stop() end
    end)
    function page.PulseCode()
        pulse.loops = 0
        pulse:Stop()
        pulse:Play()
    end

    -- "Paste the code here:" and the website's address (a click selects it).
    local siteLabel = page:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    siteLabel:SetPoint("TOPLEFT", code, "BOTTOMLEFT", -6, -26)
    panel.texts[#panel.texts + 1] = { siteLabel, "EXPORT_SITE" }
    local site = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    if FDJ.OwnFonts then FDJ.OwnFonts(site) end
    site:SetSize(250, 22)
    site:SetPoint("LEFT", siteLabel, "RIGHT", 12, 0)
    site:SetAutoFocus(false)
    site:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    site:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    site:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
    site:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    site:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    site:SetScript("OnTextChanged", function(self, byUser)
        if byUser then
            self:SetText(FDJ.SITE_CHARACTER_URL or "")
            self:HighlightText()
        end
    end)

    local copy = page:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    copy:SetPoint("TOPLEFT", siteLabel, "BOTTOMLEFT", 0, -22)
    copy:SetPoint("RIGHT", page, "RIGHT", -34, 0)
    copy:SetJustifyH("LEFT")
    copy:SetTextColor(0.75, 0.72, 0.66)
    panel.texts[#panel.texts + 1] = { copy, "EXPORT_COPY" }

    -- exporthidetab (2.1.1, M 20 Nov 2026: "at the bottom an option to toggle
    -- on and off called hide export button on main page ... I'm always going
    -- to give them options to use their UI as they wish"): the same switch as
    -- General's, at the bottom of this tab, under a gold rule.
    local bottom = CreateFrame("Frame", nil, page)
    bottom:SetPoint("BOTTOMLEFT", 0, 8)
    bottom:SetPoint("BOTTOMRIGHT", 0, 8)
    bottom:SetHeight(40)
    local rule = GoldBand(page, "ARTWORK", 0.75, 0.3)
    rule:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT", 18, 4)
    rule:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", -18, 4)
    rule:SetHeight(1)
    CreateOptionRow(bottom, {
        label = "OPT_HIDE_EXPORT",
        tip = "OPT_HIDE_EXPORT_TIP",
        get = function() return FDJ.IsExportButtonHidden and FDJ.IsExportButtonHidden() or false end,
        set = function(on) if FDJ.SetExportButtonHidden then FDJ.SetExportButtonHidden(on) end end,
    }, -4)

    -- exportlag (2.1.1, M 20 Nov 2026: "when I click on the export tab ...
    -- there is some lag"): the tab opens at once and the code is made the
    -- next moment (a quicker compression too, Systems/CharacterExport.lua).
    -- Leaving the tab before then makes nothing.
    local function Fill()
        local ok, text, questCount, name = false, nil, nil, nil
        if FDJ.BuildExportCode then ok, text, questCount, name = pcall(FDJ.BuildExportCode) end
        if ok and type(text) == "string" then
            page.code = text
            info:SetText(string.format(L("EXPORT_HINT"), name or "?", questCount or 0))
        else
            page.code = ""
            info:SetText(L("EXPORT_ERROR"))
        end
        code:SetText(page.code)
        if code.SetCursorPosition then code:SetCursorPosition(0) end -- show the start
        if page.pulseWanted then -- exportgo: opened from the Export button
            page.pulseWanted = nil
            -- pulseonce (2.1.1, M 20 Nov 2026: "only once, not every time we
            -- open it or we click on it"): the first time only, for good
            -- (once per account, exportPulseSeen).
            local db = ForeverDungeonJournalDB
            if type(db) == "table" and not db.exportPulseSeen then
                db.exportPulseSeen = true
                page.PulseCode()
            end
        end
    end
    page:SetScript("OnShow", function()
        page.code = ""
        info:SetText("")
        code:SetText("")
        code:ClearFocus()
        site:SetText(FDJ.SITE_CHARACTER_URL or "")
        if site.SetCursorPosition then site:SetCursorPosition(0) end
        site:ClearFocus()
        page.fillToken = (page.fillToken or 0) + 1
        local token = page.fillToken
        local function Later()
            if page.fillToken == token and page:IsVisible() then Fill() end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.05, Later) else Fill() end
    end)
    page:SetScript("OnHide", function() page.fillToken = (page.fillToken or 0) + 1 end)
end

-- BEGIN scrollpages (2.0.10)
-- An options page whose rows don't fit (General with the key bind, RPG Mode
-- with the slider and the Export / Import buttons) scrolls: mouse wheel, or
-- the scroll bar on the page's right. The bar is the game's own (Options >
-- Game: thin track, arrows at both ends, bronze thumb, its sounds) and only
-- shows when the page has more rows than fit. The page title and its gold
-- rule stay put; only the rows move.
local SCROLL_TOP = 58       -- just under the page title's gold rule (-52)
local SCROLL_BOTTOM = 6     -- just above the box's bottom edge
local SCROLL_BAR_SPACE = 24 -- right of the rows, for the bar
local SCROLL_STEP = 35      -- one wheel notch: one row

-- The game's scroll bar (MinimalScrollBar), wired to the scroll frame the
-- way the game does it (ScrollUtil.InitScrollFrameWithScrollBar).
local function GameScrollBar(page, scroll)
    if not (ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar) then return nil end
    local ok, bar = pcall(CreateFrame, "EventFrame", nil, page, "MinimalScrollBar")
    if not (ok and bar) then return nil end
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, -2)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, 2)
    if not pcall(ScrollUtil.InitScrollFrameWithScrollBar, scroll, bar) then
        bar:Hide()
        return nil
    end
    if scroll.SetPanExtent then scroll:SetPanExtent(SCROLL_STEP) end
    return bar
end

-- Clients without it: a plain bar in the same colours (dark track, bronze
-- thumb), same mouse wheel.
local function PlainScrollBar(page, scroll)
    local bar = CreateFrame("Slider", nil, page)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(8)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, -2)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, 2)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(bar)
    track:SetTexture("Interface\\Buttons\\WHITE8X8")
    track:SetVertexColor(0, 0, 0, 0.55)
    bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = bar:GetThumbTexture()
    if thumb then
        thumb:SetSize(8, 34)
        thumb:SetVertexColor(0.72, 0.45, 0.16, 1)
    end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetScript("OnValueChanged", function(_, value)
        if math.abs((scroll:GetVerticalScroll() or 0) - value) > 0.5 then scroll:SetVerticalScroll(value) end
    end)
    scroll:SetScript("OnScrollRangeChanged", function(self, _, range)
        range = math.max(0, range or 0)
        bar:SetMinMaxValues(0, range)
        bar:SetValue(math.min(self:GetVerticalScroll() or 0, range))
    end)
    scroll:SetScript("OnVerticalScroll", function(_, offset)
        if math.abs(bar:GetValue() - offset) > 0.5 then bar:SetValue(offset) end
    end)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local _, max = bar:GetMinMaxValues()
        bar:SetValue(math.max(0, math.min(max or 0, bar:GetValue() - delta * SCROLL_STEP)))
    end)
    return bar
end

-- The page's rows go on the frame this returns (page.content). y for the
-- first row: the same spot on screen as before the pages scrolled.
local function ScrollPage(page, titleY)
    local scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetPoint("TOPLEFT", 0, -SCROLL_TOP)
    scroll:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_SPACE, SCROLL_BOTTOM)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(PANEL_W - 28 - SIDEBAR_W - 1 - SCROLL_BAR_SPACE, 1)
    scroll:SetScrollChild(content)
    content.fdjScroll = scroll
    page.scroll, page.content = scroll, content

    local bar = GameScrollBar(page, scroll) or PlainScrollBar(page, scroll)
    page.scrollBar = bar

    -- The bar only when the rows don't all fit.
    local function Refresh()
        if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        local view = scroll:GetHeight() or 0
        local fits = view <= 0 or (content:GetHeight() or 0) <= view + 0.5
        if fits and (scroll:GetVerticalScroll() or 0) > 0 then scroll:SetVerticalScroll(0) end
        bar:SetShown(not fits)
    end
    page.fdjRefreshScroll = Refresh
    scroll:HookScript("OnScrollRangeChanged", Refresh)
    scroll:HookScript("OnSizeChanged", function(self, w)
        if w and w > 0 then content:SetWidth(w) end
        Refresh()
    end)
    page:HookScript("OnShow", Refresh)
    bar:Hide()
    return content, titleY + SCROLL_TOP
end

-- Bring an option's row into view on its page (Options opened at a line).
local function ScrollRowIntoView(row)
    local content = row and row:GetParent()
    local scroll = content and content.fdjScroll
    if not scroll then return end
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    local _, _, _, _, y = row:GetPoint(1)
    local top = math.max(0, -(y or 0) - 8)
    local bottom = top + 36
    local view = scroll:GetHeight() or 0
    local current = scroll:GetVerticalScroll() or 0
    local target = current
    if top < current then
        target = top
    elseif bottom > current + view then
        target = bottom - view
    end
    local range = scroll:GetVerticalScrollRange() or 0
    target = math.max(0, math.min(range, target))
    if math.abs(target - current) > 0.5 then scroll:SetVerticalScroll(target) end
end
-- END scrollpages

local function CreatePanel()
    panel = CreateFrame("Frame", "ForeverDungeonJournalSettings", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    -- Drag the bottom-right corner to make the whole panel bigger or smaller
    -- (text included: it scales, it does not just add empty space). Kept.
    local function Scale() return (ForeverDungeonJournalDB and ForeverDungeonJournalDB.optionsScale) or 1 end
    panel:SetScale(Scale())
    local function PinTopLeft(newScale)
        local eff = panel:GetEffectiveScale()
        local left, top = panel:GetLeft(), panel:GetTop()
        if not (left and top) then panel:SetScale(newScale) return end
        local sx, sy = left * eff, top * eff
        panel:SetScale(newScale)
        local e2 = panel:GetEffectiveScale()
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", sx / e2, sy / e2)
    end
    local grip = CreateFrame("Button", nil, panel)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel(panel:GetFrameLevel() + 20)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function(self)
        local cx = GetCursorPosition()
        self.startX = cx
        self.startScale = panel:GetScale()
        self.startW = panel:GetWidth() * panel:GetEffectiveScale()
        self:SetScript("OnUpdate", function(g)
            local x = GetCursorPosition()
            local s = g.startScale * (g.startW + (x - g.startX)) / g.startW
            s = math.max(0.75, math.min(2.0, s))
            if math.abs(s - panel:GetScale()) > 0.005 then PinTopLeft(s) end
        end)
    end)
    grip:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
        ForeverDungeonJournalDB.optionsScale = panel:GetScale()
    end)
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    panel:SetBackdropColor(0.176, 0.13, 0.15, 0.90)
    pcall(DumpGameOptions)
    local copied = false
    do local ok, res = pcall(CopyGameFrameArt, panel); copied = ok and res end
    panel.fdjGameArt = copied
    if not copied then LinedFrame(panel, WINDOW_EDGE, "BORDER") end
    for _, p in ipairs(copied and {} or { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local glint = panel:CreateTexture(nil, "ARTWORK")
        glint:SetTexture("Interface\\Buttons\\WHITE8X8")
        glint:SetVertexColor(0.85, 0.77, 0.62, 1)
        glint:SetSize(3, 3)
        glint:SetPoint(p, (p:find("LEFT") and 1 or -1), (p:find("TOP") and -1 or 1))
    end
    if UISpecialFrames then tinsert(UISpecialFrames, "ForeverDungeonJournalSettings") end

    panel.checks, panel.keybinds, panel.texts = {}, {}, {}

    -- Slim title bar.
    local bar = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
    bar:SetPoint("TOPLEFT", 7, -7)
    bar:SetPoint("TOPRIGHT", -7, -7)
    bar:SetHeight(20)
    bar:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetVertexColor(0.15, 0.095, 0.06, 1)
    local rule = { { 26, 17, 12 }, { 58, 39, 18 }, { 107, 74, 34 }, { 93, 67, 37 }, { 40, 16, 4 } }
    if copied then bar:Hide(); rule = {} end
    for i, c in ipairs(rule) do
        local t = panel:CreateTexture(nil, "BORDER")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        t:SetVertexColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
        t:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -(i - 1))
        t:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -(i - 1))
        t:SetHeight(1)
    end
    local over = CreateFrame("Frame", nil, panel)
    over:SetAllPoints(panel)
    over:SetFrameLevel(panel:GetFrameLevel() + 3)
    local title = over:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    title:SetPoint("CENTER", panel, "TOP", 9, -12)
    local titleIcon = over:CreateTexture(nil, "OVERLAY")
    titleIcon:SetSize(15, 15)
    titleIcon:SetPoint("RIGHT", title, "LEFT", -4, 0)
    titleIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    titleIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    title:SetText("Dungeon Journal")
    local version = over:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontDisableSmall")
    version:SetPoint("LEFT", panel, "TOPLEFT", 12, -12)
    version:SetText(Version())
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("CENTER", panel, "TOPRIGHT", -13, -13) -- on the frame corner, like the game's
    close:SetScript("OnClick", function() panel:Hide() end)

    -- Content box (the tabs sit on its top edge).
    local box = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 14, -66)
    box:SetPoint("BOTTOMRIGHT", -14, 44)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropColor(0.11, 0.078, 0.067, 0.92)
    box:SetBackdropBorderColor(0.50, 0.39, 0.31, 1)
    box:SetFrameLevel(panel:GetFrameLevel() + 4)

    -- ---------------------------------------------------- tab 1: options
    local optionsView = CreateFrame("Frame", nil, box)
    optionsView:SetAllPoints(box)
    local divider = Line(optionsView, BRONZE[1], BRONZE[2], BRONZE[3], 0.8)
    divider:SetPoint("TOPLEFT", SIDEBAR_W, -4)
    divider:SetPoint("BOTTOMLEFT", SIDEBAR_W, 4)
    divider:SetWidth(1)

    local header = CreateFrame("Frame", nil, optionsView, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 6, -10)
    header:SetSize(SIDEBAR_W - 12, 28)
    Edge(header, 10)
    header:SetBackdropColor(0.20, 0.14, 0.09, 0.96)
    header:SetBackdropBorderColor(0.36, 0.27, 0.15, 1)
    local headerText = header:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightLarge")
    headerText:SetPoint("LEFT", 12, 0)
    headerText:SetText("Dungeon Journal")

    local pages, entries = {}, {}
    local page, y
    local rows, bottom -- scrollpages (2.0.10): the page's scrolling part, where its rows go; its last row's bottom
    for _, option in ipairs(OPTIONS) do
        if option.header then
            page = CreateFrame("Frame", nil, optionsView)
            page:SetPoint("TOPLEFT", SIDEBAR_W + 1, 0)
            page:SetPoint("BOTTOMRIGHT", 0, 0)
            page:Hide()
            pages[#pages + 1] = page
            page.key = option.header
            y = PageTitle(page, option.header)
            rows, y = ScrollPage(page, y)
            bottom = nil
        elseif option.keybind then
            local row = CreateKeybindRow(rows, option, y - 4)
            panel.keybinds[#panel.keybinds + 1] = row
            bottom = y - 26
            y = y - 36
        elseif option.slider then
            CreateSliderRow(rows, option, y)
            bottom = y - 48
            y = y - 54
        elseif option.buttons then
            CreateButtonsRow(rows, option, y)
            bottom = y - 32
            y = y - 40
        elseif not option.action then
            CreateOptionRow(rows, option, y)
            bottom = y - 32
            y = y - 35
        end
        -- the scrolling part is as tall as the page's rows reach (+ a little air)
        if rows and bottom then rows:SetHeight(math.max(1, -bottom + 4)) end
    end

    local function SelectPage(index)
        panel.selectedPage = index
        for i, p in ipairs(pages) do
            p:SetShown(i == index)
            local e = entries[i]
            e.fade:SetShown(i == index)
            e.text:SetTextColor(i == index and 1 or 1, i == index and 1 or 0.82, i == index and 1 or 0)
        end
    end
    for i, p in ipairs(pages) do
        local e = CreateFrame("Button", nil, optionsView)
        e:SetSize(SIDEBAR_W - 14, 22)
        e:SetPoint("TOPLEFT", 8, -44 - (i - 1) * 22)
        e.fade = GoldBand(e, "BACKGROUND", 0.32, 0.35)
        e.fade:SetPoint("BOTTOMLEFT", 0, 0)
        e.fade:SetPoint("BOTTOMRIGHT", 0, 0)
        e.fade:SetHeight(22)
        e.fade:SetFrameLevel(e:GetFrameLevel())
        e.underline = GoldBand(e, "ARTWORK", 0.95, 0.35)
        e.underline:SetPoint("BOTTOMLEFT", 0, 0)
        e.underline:SetPoint("BOTTOMRIGHT", 0, 0)
        e.underline:SetHeight(1)
        e.fade:Hide()
        e.text = e:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
        e.text:SetPoint("LEFT", 22, 0)
        panel.texts[#panel.texts + 1] = { e.text, p.key }
        e:SetScript("OnClick", function() SelectPage(i) end)
        e:SetScript("OnEnter", function(self) if panel.selectedPage ~= i then self.text:SetTextColor(1, 1, 1) end end)
        e:SetScript("OnLeave", function(self) if panel.selectedPage ~= i then self.text:SetTextColor(1, 0.82, 0) end end)
        entries[i] = e
    end
    -- Underline only on the open entry.
    local baseSelect = SelectPage
    SelectPage = function(index)
        baseSelect(index)
        for i, e in ipairs(entries) do e.underline:SetShown(i == index) end
    end

    -- ---------------------------------------------------- tab 2: Export
    -- exporttab (2.1.1): the character code, before Discord (BuildExportPage)
    local exportView = CreateFrame("Frame", nil, box)
    exportView:SetAllPoints(box)
    exportView:Hide()
    BuildExportPage(exportView)
    panel.exportView, panel.exportTab = exportView, 2 -- exportgo (FDJ.OpenExportTab)

    -- ---------------------------------------------------- tab 3: Discord
    local discordView = CreateFrame("Frame", nil, box)
    discordView:SetAllPoints(box)
    BuildDiscordPage(discordView)

    -- ------------------------------------------------------------- tabs
    local views = { optionsView, exportView, discordView }
    local tabKeys = { "OPT_TAB_OPTIONS", "RUNLOG_EXPORT", "OPT_DISCORD" }
    panel.tabs = {}
    local function SelectTab(index)
        panel.selectedTab = index
        for i, tab in ipairs(panel.tabs) do
            local on = (i == index)
            views[i]:SetShown(on)
            tab.text:SetTextColor(on and 1 or 1, on and 1 or 0.82, on and 1 or 0)
            tab.fill:SetVertexColor(1, 1, 1, on and 0.05 or 0)
            if tab.SetActive then tab:SetActive(on) end
        end
    end
    for i, key in ipairs(tabKeys) do
        local tab = CreateFrame("Button", nil, panel)
        tab:SetHeight(26)
        tab.fill = tab:CreateTexture(nil, "BACKGROUND")
        tab.fill:SetPoint("TOPLEFT", 2, -2)
        tab.fill:SetPoint("BOTTOMRIGHT", -2, 0)
        tab.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
        -- Options_Tab_* / Options_Tab_Active_* are the art of the game's
        -- "Game" / "AddOns" tabs; fall back to drawn lines without them.
        local hasAtlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Options_Tab_Middle")
        if hasAtlas then
            tab.fill:SetAlpha(0)
            tab.L = tab:CreateTexture(nil, "BORDER")
            tab.M = tab:CreateTexture(nil, "BORDER")
            tab.R = tab:CreateTexture(nil, "BORDER")
            tab.L:SetPoint("BOTTOMLEFT")
            tab.R:SetPoint("BOTTOMRIGHT")
            tab.M:SetPoint("BOTTOMLEFT", tab.L, "BOTTOMRIGHT")
            tab.M:SetPoint("BOTTOMRIGHT", tab.R, "BOTTOMLEFT")
            function tab.SetActive(self, on)
                local p = on and "Options_Tab_Active_" or "Options_Tab_"
                local h = on and 26 or 23
                self.L:SetAtlas(p .. "Left"); self.L:SetSize(7, h)
                self.M:SetAtlas(p .. "Middle"); self.M:SetHeight(h)
                self.R:SetAtlas(p .. "Right"); self.R:SetSize(7, h)
                self.text:ClearAllPoints()
                self.text:SetPoint("CENTER", self, "BOTTOM", 0, on and 13 or 11)
            end
        else
            LinedFrame(tab, TAB_EDGE, "BORDER", true)
        end
        tab.text = tab:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
        tab.text:SetPoint("CENTER", 0, 1)
        tab.key = key
        tab:SetScript("OnClick", function()
            if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
            SelectTab(i)
        end)
        tab:SetScript("OnEnter", function(self) if panel.selectedTab ~= i then self.text:SetTextColor(1, 1, 1) end end)
        tab:SetScript("OnLeave", function(self) if panel.selectedTab ~= i then self.text:SetTextColor(1, 0.82, 0) end end)
        panel.tabs[i] = tab
    end
    local function LayoutTabs()
        local left = 14
        for _, tab in ipairs(panel.tabs) do
            tab:SetWidth(math.max(86, (tab.text:GetStringWidth() or 50) + 40))
            tab:ClearAllPoints()
            tab:SetPoint("BOTTOMLEFT", box, "TOPLEFT", left, -2)
            left = left + tab:GetWidth() + 6
        end
    end

    -- BEGIN optsearch
    do
        -- optsearch (2.1.1, M 20 Nov 2026: "top right of the options, add a little
        -- search that people can type in their option and just find it"): a search
        -- box at the top right. Typing lists every option whose name or tip has
        -- each word typed (any case), under its section's name, each with its own
        -- box to tick (the same option as on its page). Emptied (the X, or a
        -- section clicked on the left), the pages are back as they were.
        local results = CreateFrame("Frame", nil, optionsView)
        results:SetPoint("TOPLEFT", SIDEBAR_W + 1, 0)
        results:SetPoint("BOTTOMRIGHT", 0, 0)
        results:Hide()
        local resultsRows, resultsY = ScrollPage(results, PageTitle(results, "OPT_SEARCH_RESULTS"))
        local noneFound = resultsRows:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontDisable")
        noneFound:SetPoint("TOPLEFT", LABEL_X, resultsY - 7)
        panel.texts[#panel.texts + 1] = { noneFound, "OPT_SEARCH_NONE" }
        noneFound:Hide()

        -- Lower case, letters with accents and Cyrillic too (string.lower is
        -- A-Z only); colour codes out.
        local function Fold(text)
            local s = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
            s = s:gsub("\195([\128-\158])", function(c)
                local b = c:byte()
                if b ~= 151 then return "\195" .. string.char(b + 32) end
            end)
            s = s:gsub("\208\129", "\209\145")
            s = s:gsub("\208([\144-\159])", function(c) return "\208" .. string.char(c:byte() + 32) end)
            s = s:gsub("\208([\160-\175])", function(c) return "\209" .. string.char(c:byte() - 32) end)
            return s
        end
        local function OptionText(option, section)
            local parts = { L(section) }
            if option.label then parts[#parts + 1] = L(option.label) end
            if option.tip then parts[#parts + 1] = L(option.tip) end
            if option.keybind then parts[#parts + 1] = L("OPT_BIND_TIP") end
            for _, spec in ipairs(option.buttons or {}) do
                parts[#parts + 1] = L(spec.label)
                if spec.tip then parts[#parts + 1] = L(spec.tip) end
            end
            return Fold(table.concat(parts, " "))
        end

        -- One row per option found, made the first time it is found.
        local mirrors, sectionNames = {}, {}
        local function Mirror(option)
            local holder = mirrors[option]
            if holder then return holder end
            holder = CreateFrame("Frame", nil, resultsRows)
            if option.keybind then
                panel.keybinds[#panel.keybinds + 1] = CreateKeybindRow(holder, option, -4)
                holder.h = 36
            elseif option.slider then
                CreateSliderRow(holder, option, 0)
                holder.h = 54
            elseif option.buttons then
                CreateButtonsRow(holder, option, 0)
                holder.h = 40
            else
                CreateOptionRow(holder, option, 0)
                holder.h = 35
            end
            mirrors[option] = holder
            return holder
        end
        local function SectionName(key)
            local s = sectionNames[key]
            if not s then
                s = resultsRows:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
                s:SetTextColor(0.80, 0.68, 0.45)
                sectionNames[key] = s
            end
            return s
        end
        local function RefreshValues()
            for _, button in ipairs(panel.keybinds) do button.Refresh() end
            for _, slider in ipairs(panel.sliders or {}) do slider:Refresh() end
            for _, check in ipairs(panel.checks) do
                local ok, value = pcall(check.option.get)
                check:SetChecked(ok and value or false)
            end
        end

        local searching = false
        local function RunSearch(text)
            local words = {}
            for w in Fold(text):gmatch("%S+") do words[#words + 1] = w end
            if #words == 0 then
                if searching then
                    searching = false
                    results:Hide()
                    SelectPage(panel.selectedPage or 1)
                    RefreshValues()
                end
                return
            end
            searching = true
            if panel.selectedTab ~= 1 then SelectTab(1) end
            for _, p in ipairs(pages) do p:Hide() end
            for _, e in ipairs(entries) do
                e.fade:Hide()
                e.underline:Hide()
                e.text:SetTextColor(1, 0.82, 0)
            end
            for _, holder in pairs(mirrors) do holder:Hide() end
            for _, s in pairs(sectionNames) do s:Hide() end
            local y, found, section, shownSection = resultsY, 0, nil, nil
            for _, option in ipairs(OPTIONS) do
                if option.header then
                    section = option.header
                elseif not option.action then
                    local text = OptionText(option, section)
                    local all = true
                    for _, w in ipairs(words) do
                        if not text:find(w, 1, true) then all = false break end
                    end
                    if all then
                        if shownSection ~= section then
                            shownSection = section
                            local s = SectionName(section)
                            s:SetText(L(section))
                            s:ClearAllPoints()
                            s:SetPoint("TOPLEFT", 22, y - 6)
                            s:Show()
                            y = y - 24
                        end
                        local holder = Mirror(option)
                        holder:ClearAllPoints()
                        holder:SetPoint("TOPLEFT", resultsRows, "TOPLEFT", 0, y)
                        holder:SetPoint("TOPRIGHT", resultsRows, "TOPRIGHT", 0, y)
                        holder:SetHeight(holder.h)
                        holder:Show()
                        y = y - holder.h
                        found = found + 1
                    end
                end
            end
            noneFound:SetShown(found == 0)
            resultsRows:SetHeight(math.max(1, -y + 4))
            results:Show()
            if results.scroll then results.scroll:SetVerticalScroll(0) end
            if results.fdjRefreshScroll then results.fdjRefreshScroll() end
            RefreshValues()
        end

        -- The box, in the journal's own search box style (smaller).
        local search = CreateFrame("EditBox", "ForeverDungeonJournalSettingsSearch", panel, "BackdropTemplate")
        search:SetSize(176, 22)
        search:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -4, 4)
        search:SetFrameLevel(box:GetFrameLevel() + 2)
        search:SetAutoFocus(false)
        search:SetMaxLetters(40)
        search:SetFontObject("ForeverDJ_GameFontHighlightSmall")
        search:SetTextInsets(22, 20, 0, 0)
        search:SetJustifyH("LEFT")
        search:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        search:SetBackdropColor(0.045, 0.043, 0.040, 0.98)
        search:SetBackdropBorderColor(0.34, 0.31, 0.27, 1)
        local icon = search:CreateTexture(nil, "ARTWORK")
        icon:SetSize(12, 12)
        icon:SetPoint("LEFT", 6, 0)
        icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
        icon:SetVertexColor(0.72, 0.70, 0.66)
        local placeholder = search:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
        placeholder:SetPoint("LEFT", 22, 0)
        placeholder:SetPoint("RIGHT", -20, 0)
        placeholder:SetJustifyH("LEFT")
        placeholder:SetWordWrap(false)
        placeholder:SetTextColor(0.48, 0.47, 0.44)
        panel.texts[#panel.texts + 1] = { placeholder, "OPT_SEARCH" }
        local clear = CreateFrame("Button", nil, search)
        clear:SetSize(14, 14)
        clear:SetPoint("RIGHT", -4, 0)
        clear:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
        clear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        clear:Hide()
        clear:SetScript("OnClick", function()
            search:SetText("")
            search:ClearFocus()
        end)
        search:SetScript("OnTextChanged", function(self)
            local text = self:GetText() or ""
            placeholder:SetShown(text == "")
            clear:SetShown(text ~= "")
            RunSearch(text)
        end)
        search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        panel.searchBox = search

        -- A section clicked on the left: its page, the search emptied.
        for _, e in ipairs(entries) do
            e:HookScript("OnClick", function()
                if searching then
                    search:SetText("")
                    search:ClearFocus()
                end
            end)
        end
        -- Closed: the search is emptied (Options opens on its pages again).
        panel:HookScript("OnHide", function()
            search:ClearFocus()
            if (search:GetText() or "") ~= "" then search:SetText("") end
        end)
    end
    -- END optsearch

    -- noclose (2.0.9): no Close button at the bottom; the X in the title bar
    -- (and Esc) close the panel.

    panel:SetScript("OnShow", function(self)
        for _, entry in ipairs(self.texts) do entry[1]:SetText(L(entry[2])) end
        for _, tab in ipairs(self.tabs) do tab.text:SetText(L(tab.key)) end
        LayoutTabs()
        SelectTab(self.selectedTab or 1)
        SelectPage(self.selectedPage or 1)
        for _, button in ipairs(self.keybinds) do button.Refresh() end
        for _, slider in ipairs(self.sliders or {}) do slider:Refresh() end
        for _, check in ipairs(self.checks) do
            local ok, value = pcall(check.option.get)
            check:SetChecked(ok and value or false)
        end
    end)
    panel:Hide()
end

-- Ticks follow changes made elsewhere while the panel is open (the WoW
-- Forever emblem).
function FDJ.RefreshSettingsChecks()
    if not (panel and panel.checks) then return end
    for _, check in ipairs(panel.checks) do
        local ok, value = pcall(check.option.get)
        check:SetChecked(ok and value or false)
    end
end

function FDJ.ToggleSettingsPanel()
    if not panel then CreatePanel() end
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

-- ---------------------------------------------------------------------------
-- AddOn drawer (the addon list button next to the minimap on newer clients,
-- where Leatrix and others appear). Wired up in the .toc; clients without the
-- drawer simply ignore those lines.
--   left-click: open / close the journal     right-click: options
-- ---------------------------------------------------------------------------
function ForeverDungeonJournal_OnAddonCompartmentClick(_, mouseButton)
    if mouseButton == "RightButton" then
        if FDJ.ToggleSettingsPanel then FDJ.ToggleSettingsPanel() end
    elseif FDJ.ToggleJournal then
        FDJ.ToggleJournal()
    end
end

function ForeverDungeonJournal_OnAddonCompartmentEnter(_, owner)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner or UIParent, "ANCHOR_LEFT")
    GameTooltip:AddLine("Dungeon Journal", 1, 0.82, 0.25)
    GameTooltip:AddLine(L("MINIMAP_LEFT"), 1, 1, 1)
    GameTooltip:AddLine(L("MINIMAP_OPTIONS"), 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function ForeverDungeonJournal_OnAddonCompartmentLeave()
    if GameTooltip then GameTooltip:Hide() end
end

-- BEGIN rpgintro
-- Open the options on the page that holds one option and make its row pulse
-- gold a few times (the RPG Mode note's "Disable in Options" button).
local function PulseRow(check)
    if not check.fdjPulse then
        local page = check:GetParent()
        local _, _, _, _, y = check:GetPoint(1)
        local glow = page:CreateTexture(nil, "BACKGROUND", nil, 2)
        glow:SetPoint("TOPLEFT", 10, (y or 0) + 2)
        glow:SetPoint("TOPRIGHT", -10, (y or 0) + 2)
        glow:SetHeight(32)
        glow:SetTexture("Interface\\Buttons\\WHITE8X8")
        glow:SetVertexColor(1.00, 0.78, 0.25, 0.35)
        glow:SetAlpha(0)
        local pulse = glow:CreateAnimationGroup()
        pulse:SetLooping("BOUNCE")
        local fade = pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(0)
        fade:SetToAlpha(1)
        fade:SetDuration(0.4)
        pulse:SetScript("OnLoop", function(self)
            self.loops = (self.loops or 0) + 1
            if self.loops >= 6 then self:Stop() end
        end)
        check.fdjPulse = pulse
    end
    check.fdjPulse.loops = 0
    check.fdjPulse:Stop()
    check.fdjPulse:Play()
end

-- exportgo (2.1.1, M 20 Nov 2026: "the export link to just send the user to
-- the export option page, with the usual highlight on the code"): the
-- Options open on the Export tab, and once the code is made its row pulses.
function FDJ.OpenExportTab()
    if not panel then CreatePanel() end
    panel.selectedTab = panel.exportTab or 2
    if panel.exportView then panel.exportView.pulseWanted = true end
    if panel:IsShown() then panel:Hide() end
    panel:Show()
    if panel.Raise then panel:Raise() end
end

-- quiet: just open that page, no flashing row.
function FDJ.OpenSettingsAt(label, quiet)
    if not panel then CreatePanel() end
    local pageIndex, pages = 1, 0
    for _, option in ipairs(OPTIONS) do
        if option.header then pages = pages + 1 end
        if option.label == label then
            pageIndex = math.max(1, pages)
            break
        end
    end
    panel.selectedTab = 1
    panel.selectedPage = pageIndex
    if panel:IsShown() then panel:Hide() end
    panel:Show()
    if panel.Raise then panel:Raise() end
    -- scrollpages (2.0.10): a row lower down the page scrolls into view
    -- (once the panel has its size, the next moment).
    local function Reveal()
        for _, check in ipairs(panel.checks or {}) do
            if check.option and check.option.label == label then ScrollRowIntoView(check) end
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.05, Reveal) else Reveal() end
    if quiet then return end
    for _, check in ipairs(panel.checks or {}) do
        if check.option and check.option.label == label then PulseRow(check) end
    end
end
-- END rpgintro

-- BEGIN hideunavailable
-- 2.0.11 (M 18 Nov 2026: "give players an option to Hide unavailable quests,
-- this option will then be auto unticked if we change a quest from
-- unavailable back to viable"). The quests the data marks unavailable
-- (unavailable = true, or unavailableRaces) are saved with the option; at
-- login, if one of them is no longer marked, the option turns itself off.
do
    local strings = {
        enUS = { OPT_HIDE_UNAVAILABLE = "Hide unavailable quests",
            OPT_HIDE_UNAVAILABLE_TIP = "Hides the quests marked Unavailable (not in WoW Forever for now, or not for your race). If an update makes one of them available again, this option turns itself off so you see it." },
        deDE = { OPT_HIDE_UNAVAILABLE = "Nicht verfügbare Quests ausblenden",
            OPT_HIDE_UNAVAILABLE_TIP = "Blendet Quests aus, die als nicht verfügbar markiert sind (derzeit nicht in WoW Forever oder nicht für dein Volk). Wird eine davon durch ein Update wieder verfügbar, schaltet sich diese Option von selbst aus, damit du sie siehst." },
        frFR = { OPT_HIDE_UNAVAILABLE = "Masquer les quêtes indisponibles",
            OPT_HIDE_UNAVAILABLE_TIP = "Masque les quêtes marquées indisponibles (absentes de WoW Forever pour l'instant, ou pas pour votre race). Si une mise à jour en rend une de nouveau disponible, cette option se désactive d'elle-même pour que vous la voyiez." },
        esES = { OPT_HIDE_UNAVAILABLE = "Ocultar misiones no disponibles",
            OPT_HIDE_UNAVAILABLE_TIP = "Oculta las misiones marcadas como no disponibles (aún no están en WoW Forever o no son para tu raza). Si una actualización vuelve a hacer disponible alguna, esta opción se desactiva sola para que la veas." },
        itIT = { OPT_HIDE_UNAVAILABLE = "Nascondi missioni non disponibili",
            OPT_HIDE_UNAVAILABLE_TIP = "Nasconde le missioni segnate come non disponibili (per ora non in WoW Forever, o non per la tua razza). Se un aggiornamento ne rende di nuovo disponibile una, questa opzione si disattiva da sola così la vedi." },
        ptBR = { OPT_HIDE_UNAVAILABLE = "Ocultar missões indisponíveis",
            OPT_HIDE_UNAVAILABLE_TIP = "Oculta as missões marcadas como indisponíveis (ainda não estão no WoW Forever ou não são para a sua raça). Se uma atualização deixar alguma disponível de novo, esta opção se desliga sozinha para você vê-la." },
        ruRU = { OPT_HIDE_UNAVAILABLE = "Скрывать недоступные задания",
            OPT_HIDE_UNAVAILABLE_TIP = "Скрывает задания, помеченные как недоступные (пока нет в WoW Forever или не для вашей расы). Если обновление снова сделает какое-то из них доступным, этот параметр отключится сам, чтобы вы его увидели." },
        koKR = { OPT_HIDE_UNAVAILABLE = "이용 불가 퀘스트 숨기기",
            OPT_HIDE_UNAVAILABLE_TIP = "이용 불가로 표시된 퀘스트를 숨깁니다(현재 WoW Forever에 없거나 내 종족은 받을 수 없음). 업데이트로 그중 하나가 다시 가능해지면 이 옵션이 자동으로 꺼져 그 퀘스트가 보입니다." },
        zhCN = { OPT_HIDE_UNAVAILABLE = "隐藏不可用的任务",
            OPT_HIDE_UNAVAILABLE_TIP = "隐藏标为不可用的任务（目前不在WoW Forever中，或你的种族无法接取）。如果更新让其中某个任务重新可用，此选项会自动关闭，让你看到它。" },
        zhTW = { OPT_HIDE_UNAVAILABLE = "隱藏無法使用的任務",
            OPT_HIDE_UNAVAILABLE_TIP = "隱藏標為無法使用的任務（目前不在WoW Forever中，或你的種族無法接取）。如果更新讓其中某個任務重新可用，此選項會自動關閉，讓你看到它。" },
    }
    strings.esMX = strings.esES
    for locale, entries in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for key, value in pairs(entries) do
                if t[key] == nil then t[key] = value end
            end
        end
    end

    -- Every quest the data marks unavailable now (quest ID -> true).
    FDJ.UnavailableQuestIDs = function()
        local ids = {}
        for _, dungeon in pairs(FDJ.DB or {}) do
            local quests = type(dungeon) == "table" and dungeon.quests
            for _, q in ipairs(type(quests) == "table" and quests or {}) do
                if type(q) == "table" and type(q.id) == "number"
                    and (q.unavailable or type(q.unavailableRaces) == "table") then
                    ids[q.id] = true
                end
            end
        end
        return ids
    end
    FDJ.CheckHideUnavailable = function()
        local db = Store()
        if not db.hideUnavailableQuests then db.hideUnavailableSeen = nil return end
        local now = FDJ.UnavailableQuestIDs()
        for id in pairs(type(db.hideUnavailableSeen) == "table" and db.hideUnavailableSeen or {}) do
            if not now[id] then
                db.hideUnavailableQuests = nil
                db.hideUnavailableSeen = nil
                return
            end
        end
        db.hideUnavailableSeen = now
    end
    if type(CreateFrame) == "function" then
        local watcher = CreateFrame("Frame")
        watcher:RegisterEvent("PLAYER_LOGIN")
        watcher:SetScript("OnEvent", function() pcall(FDJ.CheckHideUnavailable) end)
    end
end
-- END hideunavailable

-- BEGIN hidedone
do
    local strings = {
        enUS = { OPT_HIDE_DONE_QUESTS = "Hide completed quests",
            OPT_HIDE_DONE_QUESTS_TIP = "Leaves the quests you've handed in out of a dungeon's quest list, so you only see what's left to do. The dungeon list still counts them." },
        deDE = { OPT_HIDE_DONE_QUESTS = "Abgeschlossene Quests ausblenden",
            OPT_HIDE_DONE_QUESTS_TIP = "Lässt die Quests, die du abgegeben hast, aus der Questliste eines Dungeons weg, damit du nur siehst, was noch zu tun ist. Die Dungeonliste zählt sie weiterhin." },
        frFR = { OPT_HIDE_DONE_QUESTS = "Masquer les quêtes terminées",
            OPT_HIDE_DONE_QUESTS_TIP = "Retire de la liste des quêtes d'un donjon celles que vous avez rendues, pour ne voir que ce qu'il reste à faire. La liste des donjons les compte toujours." },
        esES = { OPT_HIDE_DONE_QUESTS = "Ocultar misiones completadas",
            OPT_HIDE_DONE_QUESTS_TIP = "Quita de la lista de misiones de una mazmorra las que ya entregaste, para que solo veas lo que te queda por hacer. La lista de mazmorras las sigue contando." },
        itIT = { OPT_HIDE_DONE_QUESTS = "Nascondi missioni completate",
            OPT_HIDE_DONE_QUESTS_TIP = "Toglie dall'elenco delle missioni di una spedizione quelle che hai già consegnato, così vedi solo cosa ti resta da fare. L'elenco delle spedizioni le conta comunque." },
        ptBR = { OPT_HIDE_DONE_QUESTS = "Ocultar missões concluídas",
            OPT_HIDE_DONE_QUESTS_TIP = "Tira da lista de missões de uma masmorra as que você já entregou, para você ver só o que falta fazer. A lista de masmorras continua contando-as." },
        ruRU = { OPT_HIDE_DONE_QUESTS = "Скрывать выполненные задания",
            OPT_HIDE_DONE_QUESTS_TIP = "Убирает из списка заданий подземелья те, что вы уже сдали, чтобы видеть только то, что осталось. Список подземелий по-прежнему их учитывает." },
        koKR = { OPT_HIDE_DONE_QUESTS = "완료한 퀘스트 숨기기",
            OPT_HIDE_DONE_QUESTS_TIP = "이미 완료한 퀘스트를 던전 퀘스트 목록에서 빼서 남은 것만 보이게 합니다. 던전 목록에서는 계속 집계됩니다." },
        zhCN = { OPT_HIDE_DONE_QUESTS = "隐藏已完成的任务",
            OPT_HIDE_DONE_QUESTS_TIP = "在副本的任务列表中不显示你已交付的任务，只显示还要做的。副本列表仍会计入它们。" },
        zhTW = { OPT_HIDE_DONE_QUESTS = "隱藏已完成的任務",
            OPT_HIDE_DONE_QUESTS_TIP = "在副本的任務列表中不顯示你已交付的任務，只顯示還要做的。副本列表仍會計入它們。" },
    }
    strings.esMX = strings.esES
    for locale, entries in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for key, value in pairs(entries) do
                if t[key] == nil then t[key] = value end
            end
        end
    end
end
-- END hidedone

-- lootoptions (2.0.11): Options > Loot.
do
    local strings = {
        enUS = { OPT_LOOT = "Loot",
            OPT_HIDE_QUEST_DROPS = "Hide quest item drops", OPT_HIDE_QUEST_DROPS_TIP = "Boss loot pages don't list the quest items a boss drops." },
        deDE = { OPT_LOOT = "Beute",
            OPT_HIDE_QUEST_DROPS = "Questgegenstände in der Beute ausblenden", OPT_HIDE_QUEST_DROPS_TIP = "Die Beuteseiten der Bosse führen die Questgegenstände nicht auf, die ein Boss fallen lässt." },
        frFR = { OPT_LOOT = "Butin",
            OPT_HIDE_QUEST_DROPS = "Masquer les objets de quête du butin", OPT_HIDE_QUEST_DROPS_TIP = "Les pages de butin des boss ne listent pas les objets de quête qu'un boss laisse tomber." },
        esES = { OPT_LOOT = "Botín",
            OPT_HIDE_QUEST_DROPS = "Ocultar objetos de misión del botín", OPT_HIDE_QUEST_DROPS_TIP = "Las páginas de botín de los jefes no muestran los objetos de misión que suelta un jefe." },
        itIT = { OPT_LOOT = "Bottino",
            OPT_HIDE_QUEST_DROPS = "Nascondi oggetti di missione dal bottino", OPT_HIDE_QUEST_DROPS_TIP = "Le pagine del bottino dei boss non elencano gli oggetti di missione che un boss lascia cadere." },
        ptBR = { OPT_LOOT = "Saque",
            OPT_HIDE_QUEST_DROPS = "Ocultar itens de missão do saque", OPT_HIDE_QUEST_DROPS_TIP = "As páginas de saque dos chefes não listam os itens de missão que um chefe deixa cair." },
        ruRU = { OPT_LOOT = "Добыча",
            OPT_HIDE_QUEST_DROPS = "Скрыть предметы для заданий", OPT_HIDE_QUEST_DROPS_TIP = "На страницах добычи боссов не показываются предметы для заданий, которые падают с босса." },
        koKR = { OPT_LOOT = "전리품",
            OPT_HIDE_QUEST_DROPS = "퀘스트 아이템 숨기기", OPT_HIDE_QUEST_DROPS_TIP = "우두머리 전리품 페이지에 우두머리가 떨구는 퀘스트 아이템을 표시하지 않습니다." },
        zhCN = { OPT_LOOT = "掉落",
            OPT_HIDE_QUEST_DROPS = "隐藏任务物品掉落", OPT_HIDE_QUEST_DROPS_TIP = "首领掉落页面不列出首领掉落的任务物品。" },
        zhTW = { OPT_LOOT = "掉落",
            OPT_HIDE_QUEST_DROPS = "隱藏任務物品掉落", OPT_HIDE_QUEST_DROPS_TIP = "首領掉落頁面不列出首領掉落的任務物品。" },
    }
    strings.esMX = strings.esES
    for locale, entries in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for key, value in pairs(entries) do
                if t[key] == nil then t[key] = value end
            end
        end
    end
end

-- optsearch (2.1.1): the Options search box's texts.
do
    local strings = {
        enUS = { OPT_SEARCH = "Search options", OPT_SEARCH_RESULTS = "Search results", OPT_SEARCH_NONE = "No options found." },
        deDE = { OPT_SEARCH = "Optionen durchsuchen", OPT_SEARCH_RESULTS = "Suchergebnisse", OPT_SEARCH_NONE = "Keine Optionen gefunden." },
        frFR = { OPT_SEARCH = "Rechercher une option", OPT_SEARCH_RESULTS = "Résultats de la recherche", OPT_SEARCH_NONE = "Aucune option trouvée." },
        esES = { OPT_SEARCH = "Buscar opciones", OPT_SEARCH_RESULTS = "Resultados de la búsqueda", OPT_SEARCH_NONE = "No se encontraron opciones." },
        itIT = { OPT_SEARCH = "Cerca opzioni", OPT_SEARCH_RESULTS = "Risultati della ricerca", OPT_SEARCH_NONE = "Nessuna opzione trovata." },
        ptBR = { OPT_SEARCH = "Buscar opções", OPT_SEARCH_RESULTS = "Resultados da busca", OPT_SEARCH_NONE = "Nenhuma opção encontrada." },
        ruRU = { OPT_SEARCH = "Поиск настроек", OPT_SEARCH_RESULTS = "Результаты поиска", OPT_SEARCH_NONE = "Настройки не найдены." },
        koKR = { OPT_SEARCH = "옵션 검색", OPT_SEARCH_RESULTS = "검색 결과", OPT_SEARCH_NONE = "옵션을 찾을 수 없습니다." },
        zhCN = { OPT_SEARCH = "搜索选项", OPT_SEARCH_RESULTS = "搜索结果", OPT_SEARCH_NONE = "未找到选项。" },
        zhTW = { OPT_SEARCH = "搜尋選項", OPT_SEARCH_RESULTS = "搜尋結果", OPT_SEARCH_NONE = "找不到選項。" },
    }
    strings.esMX = strings.esES
    for locale, entries in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for key, value in pairs(entries) do
                if t[key] == nil then t[key] = value end
            end
        end
    end
end
