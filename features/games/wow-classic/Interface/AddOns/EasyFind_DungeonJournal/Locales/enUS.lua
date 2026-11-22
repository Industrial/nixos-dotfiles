local _, ns = ...

-- Every string the player sees. Other locales override keys in files of
-- their own; a missing key falls back to this one.
local L = setmetatable({}, { __index = function(_, k) return k end })
ns.L = L

L["EXT_NAME"] = "DungeonJournal"
L["EXT_DESC"] = "Open DungeonJournal from the bosses, loot and dungeons EasyFind finds, and search its dungeon quests."
L["SETTINGS_HINT"] = "Which of DungeonJournal's dungeon quests the search shows."
L["SETTINGS_QUESTIE"] = "Dungeon quests come through the Questie extension's rows here; Open in DungeonJournal is in their right-click menu."
L["PROVIDER_QUESTS"] = QUESTS_LABEL or "Quests"

L["HINT_WORD"] = "DungeonJournal"
L["HINT_LOOT"] = LOOT or "Loot"
L["HINT_OPEN"] = "Open in DungeonJournal"
L["HINT_MAP"] = "Dungeon map"
L["HINT_LINK"] = "Link in chat"
L["OPEN_FMT"] = "Open %s in DungeonJournal"
L["MAP_FMT"] = "%s: dungeon map"
L["BOSS_LINE_FMT"] = "%s, %s"
L["DROPS_FROM"] = "Drops from"

L["LEVEL_FMT"] = "Level %s"
L["LEVEL_REQ_FMT"] = "Level %s, needs level %s"
L["STARTS_AT"] = "Starts at %s"
L["ENDS_AT"] = "Ends at %s"
L["OBJECTIVES"] = QUEST_OBJECTIVES or "Objectives"
L["REWARDS"] = REWARDS or "Rewards"
L["FACTION_ONLY_FMT"] = "%s only"
L["FACTION_ALLIANCE"] = FACTION_ALLIANCE or "Alliance"
L["FACTION_HORDE"] = FACTION_HORDE or "Horde"
L["STATE_AVAILABLE"] = "Available"
L["STATE_IN_LOG"] = "In your log"
L["STATE_TURN_IN"] = "Ready to turn in"
L["STATE_DONE"] = "Turned in"
L["STATE_NEEDS_LEVEL"] = "Needs level %d"
L["STATE_SUBTEXT_FMT"] = "%s: %s"
L["DEST_ENTRANCE_FMT"] = "%s entrance"
L["STEP_ENTRANCE"] = "Travel to the dungeon entrance"
L["DEST_GIVER_FMT"] = "%s: quest giver"
L["STEP_GIVER"] = "Travel to the quest giver"

L["OPT_HIDE_DONE"] = "Hide turned in"
L["OPT_HIDE_DONE_TIP"] = "Leave out quests you have turned in."
L["OPT_OTHER_FACTION"] = "Other faction's quests"
L["OPT_OTHER_FACTION_TIP"] = "Also list quests only the other faction can take."
L["OPT_ALL_CLASSES"] = "Every class's quests"
L["OPT_ALL_CLASSES_TIP"] = "Also list class quests for other classes."
L["MENU_OPTIONS"] = "DungeonJournal options"

L["NOT_READY"] = "DungeonJournal's data is not available in this version, so its search is off."
L["NEEDS_EASYFIND"] = "Needs a newer EasyFind: update EasyFind."
L["NO_JOURNAL"] = "DungeonJournal's window is not ready yet."
