local ADDON_NAME, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS

-- Interface localization plus a separate content-localization layer. Internal
-- database keys remain stable; localized display text is resolved at render time.
FDJ.Locales = FDJ.Locales or {}

FDJ.Locales.enUS = {
    RANDOM_ENCHANT = "<Random enchantment>",
    ALSO_RECEIVE = "You will also receive:",
    MAP_JUMP_LEVEL = "Jump down to Level %d",
    MAP_RFK_VINE = "Jump on this vine to reach Roogug",
    MAP_OBJ_BFD_CHEST = "Loot the Lorgalis Manuscript from the Pitted Iron Chest, underwater in this alcove of the pool.",
    MAP_OBJ_BFD_FATHOM = "Click the Fathom Stone underwater, below the walkway, to get the Fathom Core. Baron Aquanis spawns when you do.",
    MAP_OBJ_LOOT = "Loot here: %s",
    MAP_OBJ_USE = "Use it here",
    MAP_OBJ_EXPLORE = "Explore this place",
    NOTICE_LV30_DATA = "New loot and quests for dungeons up to lv 30 are still being discovered. I will update as new data comes out. gl hf",
    NOTICE_RESIZE = "Commands changed from |cffff3030/fj|r to |cff33ff33/dj|r.",
    MAP_SHARK_EXIT = "Shark exit",
    MAP_SAFE_EXIT = "Safe exit",
    MAP_SWIM_HERE = "Swim underwater here for level %d",
    MAP_ALT_SPAWN = "Can also spawn here",
    MAP_SWIM_LEVEL = "Swim underwater for level %d",
    MAP_ENTRANCE = "Entrance",
    LOOT_COMPACT = "Compact view",
    LOOT_DETAILED = "Detailed view",
    LOOT_COMPACT_TIP = "Show more items at once in smaller rows",
    LOOT_DETAILED_TIP = "Show the full item rows",
    ATTUNE_ONYXIA = "Onyxia Attunement",
    MAP_ENTRANCE_ORANGE = "Orange Entrance",
    MAP_ENTRANCE_PURPLE = "Purple Entrance",
    MAP_FLOOR = "Level %d",
    DUNGEON_JOURNAL = "Dungeon Journal",
    SEARCH = "Search for Dungeons, Items...",
    SEARCH_NO_RESULTS = "No results",
    DUNGEONS = "Dungeons",
    MAP = "Map",
    BROWSE_DUNGEONS = "Browse Dungeons",
    HOME_SUBTITLE = "Select a dungeon cover to view bosses, loot and quests",
    FOREVER_BETA_DATA = "Forever beta data",
    BOSSES = "Bosses",
    QUESTS = "Quests",
    QUEST = "quest",
    QUESTS_LOWER = "quests",
    LOOT = "Loot",
    ITEM = "item",
    ITEMS = "items",
    RARE = "RARE",
    YOU_HAVE_IT = "YOU HAVE IT",
    TURN_IN_LABEL = "Turn in",
    AVAILABLE_FROM_LEVEL = "Available from Level %s",
    REQUIRED_PREREQUISITE = "Required prerequisite",
    OBJECTIVE = "Objective",
    STARTS_AT = "Starts at",
    OBTAIN = "Obtain",
    TURN_IN = "Turn in",
    NOTES = "Notes",
    SHARE = "Share",
    NOT_SHAREABLE = "Not Shareable",
    SHAREABLE_QUEST = "Shareable Quest",
    ACCEPT_TO_SHARE = "Accept this quest to share it with your group.",
    SHAREABLE_SAME_STEP = "Shareable to players on the same step.",
    REWARD = "Reward",
    REWARDS = "Rewards",
    CHOOSE_ONE_REWARD = "Choose one reward",
    SHOW_ON_MAP = "Show on Map",
    SHOW_TURN_IN = "Show Turn In",
    TURN_IN_DUNGEON = "Turn in: Dungeon",
    ROUTE_FP_TARREN_MILL_TEXT = "The route detours here so you can pick up the flight path. Afterwards, head back down the road and continue east toward Arathi.",
    ROUTE_FP_TARREN_MILL = "Tarren Mill Flight Path",
    ROUTE_REMOVE_HINT = "Right click to remove route",
    SHOW_LOCATION = "Show Location",
    DUNGEON_ENTRANCE = "Dungeon entrance",
    HOW_TO_GET_THERE = "How to get there",
    ROUTE = "Route",
    BACK_TO_DUNGEON = "Back to Dungeon",
    ALLIANCE_ROUTE = "Alliance route",
    SHOW_QUEST_CHAIN = "Show Quest Chain",
    REQUIRED_QUESTS = "Required Quests",
    REQUIRED_ITEMS = "Required Items",
    PROVIDED_ITEM = "Provided Item",
    SHOW_WHOLE_CHAIN = "Click to show the whole quest chain",
    OPEN_REQUIRED_CHAIN = "Open the required quest chain.",
    SHOW_GIVER_ON_MAP = "Show quest giver on map",
    MAP_TOOLTIP = "Opens the correct zone and marks the recorded quest-start location.",
    IN_DUNGEON = "In Dungeon",
    NO_QUESTS = "No quests",
    NO_FACTION_QUESTS = "No %s quests recorded for this dungeon.",
    NO_FACTION_QUESTS_TBD = "No %s quests known for this dungeon yet. It is new and its quests are still being found.",
    STEP_ACCEPT_ONLY = "(accept only)",
    CHAIN_PICK_ONE = "You just need 1 of the following quests:",
    LOOT_NOTE_TWO_ITEMS = "Can drop 2 items",
    LOOT_NOTE_HELNURATH = "Summoned by the Warlock epic mount quest",
    LOOT_NOTE_BURNING_FELGUARD = "Scarshield Warlocks can summon it through their portals",
    UNIQUE_TRASH = "Unique dungeon trash drops",
    DROPS_FROM = "Drops from: %s",
    CLICK_DUNGEON = "Click to open dungeon details",
    HIDE_DUNGEONS = "Hide Dungeons",
    LOOT_FILTER = "Loot Filter",
    BUG_REPORT = "Report a Bug",
    BUG_REPORT_SHORT = "Report",
    BUG_REPORT_TEXT = "Found some wrong information or new discoveries that should be added? Please report it on the Discord, Screenshot required.",
    WM_WORLD_MAP = "World Map",
    WM_DUNGEON_MAP = "Dungeon Map",
    MINIMAP_HIDE_CONFIRM = "Hide the Dungeon Journal minimap button?\n\nYou can bring it back by typing /dj minimap.",
    LF_SHOW_RECIPES = "Always show pattern/recipe drops",
    RESIZE_TIP_TITLE = "Rescale",
    RESIZE_TIP = "Drag to rescale the window. Right-click to reset.",
    OPT_RESIZE = "Resize",
    OPT_RESIZE_TIP = "Opens the journal so you can drag its corners to make it bigger.",
    RESIZE_HINT = "Drag the corners to resize",
    RESIZE_CORNER_TIP = "Drag to resize. Right-click to reset the size.",
    OPT_RESET_SIZE = "Reset Size",
    OPT_RESET_SIZE_TIP = "Puts the journal back to its normal size and scale.",
    LF_ENABLE = "Enable",
    LF_DISABLE = "Disable",
    LF_MIN_LEVEL = "Minimum required level",
    LF_LEVEL_RANGE = "Level range", -- levelrange (2.1.2)
    OPT_UI = "General",
    OPT_DISCORD_TEXT = "Join the Dungeon Journal Discord to report bugs, share new discoveries and get the latest news.",
    OPT_DUNGEON_LIST = "Dungeon list",
    OPT_HIDE_ITEM_LINE = "Hide journal line on item tooltips",
    OPT_HIDE_ITEM_LINE_TIP = "Removes the line that shows which boss or quest an item comes from.",
    OPT_AUTO_COMPARE = "Auto Item Comparison",
    OPT_AUTO_COMPARE_TIP = "Item tooltips in the journal compare with your equipped item right away, without holding Shift.",
    MALLET_HOW = "How to get the Mallet",
    OPT_HIDE_MINIMAP = "Hide minimap button",
    OPT_HIDE_MINIMAP_TIP = "Type /dj minimap to bring the button back.",
    OPT_BIND = "Open Journal Bind",
    OPT_BIND_TIP = "Click, then press a key. Right-click to clear.",
    OPT_NOT_BOUND = "Not Bound",
    OPT_PRESS_KEY = "Press a key...",
    OPT_KEY_TAKEN = "%s is already bound. Choose an unused key.",
    OPT_NO_COMBAT = "Keybinds cannot be changed during combat.",
    LEVEL_TOO_LOW_DUNGEONS = "You are too low level for dungeons.\nThe first ones start at level %d.",
    NO_DUNGEONS_MY_LEVEL = "No dungeons for your level.",
    SHOW_ALL_DUNGEONS_ANYWAY = "Show all dungeons anyway",
    SUMMON_QUEST_NOTE = "%s has to be summoned: use the %s at the gong by his pool.",
    REP_REQUIRES = "Requires %s with %s",
    HOW_TO_SUMMON = "How to summon %s",
    MAP_WREX_KEYRING = "Open with Wrex's Keyring for level %d",
    OPT_MY_LEVEL_RANGE = "Show only my level range",
    OPT_MY_LEVEL_RANGE_TIP = "Shows only the dungeons whose level range includes your level (the ranges of the Looking For Group panel).",
    OPT_HIDE_OUTLEVELED = "Auto-hide outleveled dungeons",
    OPT_HIDE_OUTLEVELED_TIP = "Hides a dungeon from the list once your level is above its level range.",
    OPT_HIDE_QUESTS_DONE = "Auto-hide dungeons with all quests done",
    OPT_HIDE_QUESTS_DONE_TIP = "Hides a dungeon from the list once you have completed every quest your character can do there.",
    OPT_HIDE_DONE_TICK = "Hide the green checkmark for finished dungeons",
    OPT_HIDE_DONE_TICK_TIP = "Removes the green checkmark shown on the home page before the quest count of a dungeon whose quests you have all completed.",
    OPT_SHOW_ALL_CLASS = "Show all class quests",
    OPT_SHOW_ALL_CLASS_TIP = "Also lists class quests for other classes (for example Warlock or Paladin quests). Off: you only see your own class's quests.",
    OPT_HIDE_LFG = "Hide LFG Panel",
    OPT_HIDE_LFG_TIP = "Hides the eye button next to Show Location on dungeon pages, which opens Looking For Group on that dungeon. You can also right-click the eye and pick Disable.",
    OPT_HIDE_SLEEPING_BAG = "Hide Sleeping Bag quest",
    OPT_HIDE_SLEEPING_BAG_TIP = "Hides the Sleeping Bag icon on the journal's home page (next to the WoW Forever and Raids icons). You can also right-click the icon and pick Hide. A tracked Sleeping Bag chain keeps its arrow.",
    OPT_HIDE_DUNGEON_MAP = "Hide Dungeon Map inside the dungeon",
    OPT_HIDE_DUNGEON_MAP_TIP = "When ticked, pressing M inside a dungeon shows the game's normal map instead of the journal's dungeon map.",
    DESCRIPTION = "Description",
    MINIMAP_OPTIONS = "Right-click: Options",
    LF_ARMOR_ALL = "All",
    LF_ARMOR = "Armor Filter",
    LF_WEAPON_ALL = "All",
    LF_WEAPON = "Weapon Filter",
    LF_WEAPONS = "Weapons",
    LF_ARMOR_TIP = "Hides armor pieces of other types. Weapons, shields, rings, necks, trinkets and cloaks always stay.",
    CHAIN_REQUIRED = "Requires a quest chain first.",
    CHAIN_STEP = "You are on step %d of %d.",
    GUIDE = "Guide",
    HOW_TO_COMPLETE = "How to complete",
    GUIDE_TIP = "Click to show the steps to complete this quest",
    GUIDE_STEP = "Guide: step %d of %d",
    SHOW_NEXT_STEP_MAP = "Show next step on Map",
    LF_SHOW = "Show results",
    LF_SHOW_TIP = "Opens a page listing every boss, in every dungeon, that drops loot matching the filters above.",
    LF_RESULTS = "Matching loot",
    LF_NO_RESULTS = "No items match these filters.",
    LF_BACK = "Close",
    LF_CLASS_ONLY = "Only show loot my class can use",
    LF_STATS_HEADER = "Only items with these stats",
    LF_STATS_HINT = "Tick the stats you are looking for. Nothing ticked shows everything.",
    LF_MATCH_ALL = "Item must have all ticked stats",
    LF_QUEST_REWARDS = "Show quest rewards too",
    LF_SEARCHING = "Searching the loot... %d%%",
    LF_CLEAR = "Clear",
    OPT_DISCORD_COPY = "Press Ctrl+C to copy the invite link.",
    OPT_CLOSE = "Close",
    RPG_LOCKED = "Locked",
    RPG_LOCKED_CARD = "Kill the last boss of a dungeon to unlock the Journal Page",
    RPG_PROGRESS_BAR = "Journey %d/%d (%d%%)",
    RPG_LOCKED_MSG = "This dungeon is locked. Defeat its final boss to unlock it.",
    RPG_LOCKED_TIP2 = "Kill the final boss of the dungeon to unlock this page.",
    RPG_LOCKED_TIP_TITLE = "Locked Journal Page",
    RPG_LOCKED_TIP = "Defeat %s, the final boss of %s, to unlock this page.",
    RPG_LOCKED_TIP_POINTS = "Unlocking it gives +%d journey points.",
    RPG_UNLOCKED_MSG = "%s is now unlocked in your journal!",
    RPG_TOAST_TITLE = "Journal Page Unlocked",
    RPG_TOAST_HINT = "Click to open it in the journal",
    RPG_QUEST_TOAST_TITLE = "Dungeon Quest Unlocked",
    RPG_QUEST_UNLOCKED_MSG = "%s quest unlocked! %d/%d",
    RPG_QUEST_TOAST_HINT = "Click to open it in the journal",
    RPG_BOSS_HIDDEN = "Defeat this boss to reveal it.",
    RPG_TRASH_HIDDEN = "Clear about 20% of the dungeon's trash to reveal it.",
    RPG_QUEST_HIDDEN = "Pick up this quest to unlock it.",
    RPG_MAP_LOCKED_TITLE = "Map Locked",
    RPG_MAP_LOCKED_TIP = "Clear about 20%% of the dungeon's trash to unlock it: %d/%d.",
    RPG_MAP_LOCKED_MSG = "The dungeon map unlocks after clearing about 20%% of its trash (%d/%d).",
    RPG_MAP_TOAST_TITLE = "Dungeon Map Unlocked",
    RPG_MAP_UNLOCKED_MSG = "%s map unlocked!",
    RPG_MAP_TOAST_HINT = "Click to open the map in the journal",
    RPG_MAP_TOAST_HINT_M = "Press M in the dungeon to see it",
    RPG_BOSS_REVEALED_MSG = "%s revealed in your journal!",
    RPG_LOCKED_TIP_QUEST = "Picking up one of its quests opens part of it.",
    RPG_PROGRESS = "Journey %d%%",
    RPG_PROGRESS_TITLE = "Dungeon Journey",
    RPG_PROGRESS_TIP = "%d of %d dungeon quests completed for your faction and class.",
    RPG_PROGRESS_PAGES = "%d of %d journal pages unlocked (final bosses defeated).",
    RPG_PROGRESS_POINTS = "Each quest is worth %d points, each journal page %d.",
    RPG_SUBTITLE = "Defeat a dungeon's final boss to unlock its pages",
    MODE_TITLE = "Choose your journal",
    MODE_SUB = "You can change this any time in the options (/dj options) or with /dj mode.",
    MODE_GAMER = "Gamer Mode",
    MODE_GAMER_DESC = "The full journal: every dungeon, boss, loot table and quest is open from the start.",
    MODE_RPG = "RPG Mode",
    MODE_RPG_DESC = "Dungeons start locked and unlock when you defeat their final boss. A progress bar tracks every dungeon quest you complete.",
    MODE_CHOOSE = "Choose",
    RPG_CONFIRM_TEXT = "In this mode dungeons will be locked until you kill the final boss. You can always change mode in the options panel.",
    RPG_CONFIRM_OK = "Ok",
    RPG_CONFIRM_BACK = "Choose again",
    RPG_INTRO_TEXT = "Dungeons stay locked until you kill their final boss.\nYou can still choose to show quests in the Options panel.", -- introline (2.0.17, text 2.0.18)
    RPG_INTRO_KEEP = "Keep RPG Mode",
    RPG_INTRO_OPTIONS = "Disable in Options",
    MODE_RPG_ENABLE = "Enable in Options",
    COMING_SOON = "Coming Soon",
    PREVIEW_DATA_SOON = "Boss, loot and quest data coming soon.",
    PREVIEW_MAP_CLICK = "Click to see the map.",
    ITEM_CLICK_MAP = "Click to show it on the map.",
    REPEAT_SHOW = "Show Repeatable Quests (%d)",
    REPEAT_HIDE = "Hide Repeatable Quests (%d)",
    OPT_SHOW_ALL_PROF = "Show All Profession Quests",
    OPT_SHOW_ALL_PROF_TIP = "Also list profession quests (Blacksmithing, Mining...) for professions this character doesn't have.",
    OPT_FOREVER_ONLY = "Forever Dungeons Only",
    OPT_FOREVER_ONLY_TIP = "Show only the dungeons that are new in WoW Forever. Untick it to see every dungeon again.",
    PROF_BLACKSMITHING = "Blacksmithing",
    PROF_MINING = "Mining",
    RAIDS_TITLE = "Raids",
    ITEM_UNSEEN_TITLE = "Not seen yet",
    ITEM_UNSEEN_TIP = "This item is in the game but the server hasn't sent its details yet. They'll show up once someone has seen it (for example after it drops).",
    FOREVER_FILTER_TITLE = "WoW Forever Dungeons",
    FOREVER_FILTER_TIP = "Click to show only the dungeons that are new in WoW Forever.",
    FOREVER_FILTER_ON = "Showing only WoW Forever dungeons. Click to show all dungeons again.",
    OPT_RPG_MODE = "RPG Mode",
    OPT_RPG_MODE_TIP = "Dungeons stay locked until this character defeats their final boss, and a progress bar tracks your dungeon quests.",
    OPT_VERSION = "Version: %s",
    OPT_ACCESS = "Access options with %s",
    OPT_OPEN_OPTIONS = "Open Options",
    OPT_COPY = "Copy",
    OPT_COPIED = "Copied!",
    OPT_TAB_OPTIONS = "Options",
    OPT_DISCORD = "Discord",
    LF_OK = "Ok",
    LF_HIDDEN_NOTE = "%d hidden by Loot Filter",
    RECIPES_SECTION = "Recipes & Patterns (%d)",
    SHARED_SHOW = "Show Shared Loot (%d)",
    SHARED_HIDE = "Hide Shared Loot (%d)",
    PROBABLE_LOOT = "Not confirmed, but probable drop (%d)",
    SHARED_NOTE = "low drop chance, many bosses",
    SHARED_LOOT = "Shared Loot",
    SEVERAL_DUNGEONS = "several dungeons",
    LF_STAT_HEAL = "Healing",
    LF_STAT_SPELL = "Spell Damage",
    LF_STAT_AP = "Attack Power",
    LF_STAT_CRIT = "Critical Strike",
    LF_STAT_SPELLCRIT = "Spell Crit",
    LF_STAT_HIT = "Hit",
    LF_STAT_SPELLHIT = "Spell Hit",
    LF_STAT_MP5 = "MP5",
    LF_STAT_MP5_TIP = "Mana per 5 seconds",
    LF_STAT_HP5 = "HP5",
    LF_STAT_HP5_TIP = "Health per 5 seconds",
    LF_ARMOR_BTN = "Armor",
    LF_RING = "Ring",
    LF_NECK = "Neck",
    LF_TRINKET = "Trinket",
    LF_CLOAK = "Cloak",
    LF_WEAPON_BTN = "Weapon",
    LF_RESIST = "Resistance Filter",
    LF_RESISTANCES = "Resistances",
    LF_RES_FIRE = "Fire",
    LF_RES_HOLY = "Holy",
    LF_SCHOOLS = "Spell schools",
    LF_RES_FROST = "Frost",
    LF_RES_NATURE = "Nature",
    LF_RES_SHADOW = "Shadow",
    LF_RES_ARCANE = "Arcane",
    LF_STAT_DEF = "Defense Rating",
    LF_STAT_STR = "Strength",
    LF_STAT_AGI = "Agility",
    LF_STAT_STA = "Stamina",
    LF_STAT_INT = "Intellect",
    LF_STAT_SPI = "Spirit",
    DONE = "Done",
    HIDDEN = "Hidden",
    CLICK_HIDE_DUNGEON = "Click to hide this dungeon.",
    CLICK_RESTORE_DUNGEON = "Click to restore this dungeon.",
    AUTO_HIDDEN_BY = "Hidden by: %s",
    CLICK_SHOW_ANYWAY = "Click to show it anyway.",
    ALL_DUNGEONS_HIDDEN = "All dungeons are hidden. Click Hide Dungeons to restore them.",
    FACTION_QUESTS = "%s quests",
    QUEST_IN_LOG = "This earlier quest is in your quest log.",
    QUEST_COMPLETED = "This earlier quest has been completed.",
    QUEST_NOT_CACHED = "Quest text is not currently cached by the client.",
    CLASS_ONLY = "%s ONLY",
    MINIMAP_HIDDEN = "minimap button hidden. Use /dj minimap.",
    MINIMAP_LEFT = "Left-click: Open / close",
    MINIMAP_DRAG = "Drag: Move",
    MINIMAP_RIGHT = "Right-click: Hide",
    LANGUAGE_CURRENT = "Language: %s",
    LANGUAGE_SET = "Language set to %s.",
    LANGUAGE_AUTO = "Auto (%s)",
    LANGUAGE_HELP = "Language test: /dj lang de, fr, es, ru, it, pt, ko, zh, zhtw, en, /dj lang auto",
    UPDATE_AVAILABLE = "Version %s is available (you have %s). Update on CurseForge.",
    PREVIOUS_QUEST = "Previous quest",
    REQUIRES_QUEST = "Requires: %s",
    NEXT_QUEST = "Next quest",
    LEADS_TO = "Leads to: %s",
    MAP_MARKER_REMOVED = "map marker removed.",
    MAP_LEFT_TARGET = "Left Click to target and mark quest giver if nearby",
    MAP_RIGHT_REMOVE = "Right Click to remove marker",
    MAP_PATROL = "Walks around: the line shows the path",
    MAP_QUEST_TARGET = "Quest target",
    MAP_MARKED = "marked %s on the map.",
    MAP_OPEN_FAILED = "could not open the recorded map location.",
    MAP_COMBAT = "the map can't open during combat. Press %s to see the marked spot.",
    QUEST_GIVER = "Quest giver",
    QUEST_STARTS_HERE = "Quest starts here",
    TRACK = "Track",
    TRACKING = "Tracking",
    TRACK_TIP = "Shows this dungeon's quests on your screen with your progress. Drag it anywhere.",
    TRACK_STOP = "Stop tracking",
    TRACK_READY = "Ready to turn in",
    TRACK_DONE = "Completed",
    TRACK_IN_LOG = "In your quest log",
    TRACK_CLICK = "Click to open it in the journal",
    TURN_IN_HERE = "Turn in here",
    TRACK_ACCEPT = "Click to accept the quest",
}

FDJ.Locales.deDE = {
    RANDOM_ENCHANT = "<Zufällige Verzauberung>",
    ALSO_RECEIVE = "Ihr bekommt außerdem:",
    MAP_JUMP_LEVEL = "Auf Ebene %d hinunterspringen",
    MAP_RFK_VINE = "Spring auf diese Ranke, um Roogug zu erreichen",
    MAP_OBJ_BFD_CHEST = "Plündere das Lorgalis-Manuskript aus der Narbigen Eisentruhe, unter Wasser in dieser Nische des Beckens.",
    MAP_OBJ_BFD_FATHOM = "Klicke unter Wasser unter dem Steg auf den Tiefenstein, um den Tiefenkern zu erhalten. Dabei erscheint Baron Aquanis.",
    MAP_OBJ_LOOT = "Hier plündern: %s",
    MAP_OBJ_USE = "Hier benutzen",
    MAP_OBJ_EXPLORE = "Diesen Ort erkunden",
    NOTICE_LV30_DATA = "Neue Beute und Quests für Dungeons bis Stufe 30 werden noch entdeckt. Ich aktualisiere, sobald neue Daten erscheinen. gl hf",
    NOTICE_RESIZE = "Die Befehle wurden von |cffff3030/fj|r zu |cff33ff33/dj|r geändert.",
    MAP_SHARK_EXIT = "Hai-Ausgang",
    MAP_SAFE_EXIT = "Sicherer Ausgang",
    MAP_SWIM_HERE = "Hier unter Wasser tauchen für Ebene %d",
    MAP_ALT_SPAWN = "Kann auch hier erscheinen",
    MAP_SWIM_LEVEL = "Unter Wasser tauchen für Ebene %d",
    MAP_ENTRANCE = "Eingang",
    LOOT_COMPACT = "Kompaktansicht",
    LOOT_DETAILED = "Detailansicht",
    LOOT_COMPACT_TIP = "Mehr Gegenstände auf einmal in kleineren Zeilen anzeigen",
    LOOT_DETAILED_TIP = "Vollständige Zeilen anzeigen",
    ATTUNE_ONYXIA = "Onyxia-Einstimmung",
    MAP_ENTRANCE_ORANGE = "Orangefarbener Eingang",
    MAP_ENTRANCE_PURPLE = "Violetter Eingang",
    MAP_FLOOR = "Ebene %d",
    DUNGEON_JOURNAL = "Dungeon-Journal",
    SEARCH = "Dungeons, Gegenstände suchen...",
    SEARCH_NO_RESULTS = "Keine Ergebnisse",
    DUNGEONS = "Dungeons",
    MAP = "Karte",
    BROWSE_DUNGEONS = "Dungeons durchsuchen",
    HOME_SUBTITLE = "Wähle einen Dungeon, um Bosse, Beute und Quests anzusehen",
    FOREVER_BETA_DATA = "Forever-Betadaten",
    BOSSES = "Bosse",
    QUESTS = "Quests",
    QUEST = "Quest",
    QUESTS_LOWER = "Quests",
    LOOT = "Beute",
    ITEM = "Gegenstand",
    ITEMS = "Gegenstände",
    RARE = "RARE",
    YOU_HAVE_IT = "ANGENOMMEN",
    TURN_IN_LABEL = "Abgeben",
    AVAILABLE_FROM_LEVEL = "Verfügbar ab Stufe %s",
    REQUIRED_PREREQUISITE = "Benötigte Vorquest",
    OBJECTIVE = "Ziel",
    STARTS_AT = "Startet bei",
    OBTAIN = "Erhalten",
    TURN_IN = "Abgeben bei",
    NOTES = "Hinweise",
    SHARE = "Teilen",
    NOT_SHAREABLE = "Nicht teilbar",
    SHAREABLE_QUEST = "Teilbare Quest",
    ACCEPT_TO_SHARE = "Nimm diese Quest an, um sie mit deiner Gruppe zu teilen.",
    SHAREABLE_SAME_STEP = "Mit Spielern teilbar, die beim selben Schritt sind.",
    REWARD = "Belohnung",
    REWARDS = "Belohnungen",
    CHOOSE_ONE_REWARD = "Wähle eine Belohnung",
    SHOW_ON_MAP = "Auf Karte zeigen",
    SHOW_TURN_IN = "Abgabe anzeigen",
    TURN_IN_DUNGEON = "Abgabe: Dungeon",
    SHOW_LOCATION = "Ort anzeigen",
    DUNGEON_ENTRANCE = "Dungeoneingang",
    HOW_TO_GET_THERE = "Anreise",
    ROUTE = "Route",
    BACK_TO_DUNGEON = "Zurück zum Dungeon",
    ALLIANCE_ROUTE = "Allianz-Route",
    SHOW_QUEST_CHAIN = "Questreihe anzeigen",
    REQUIRED_QUESTS = "Benötigte Quests",
    REQUIRED_ITEMS = "Benötigte Gegenstände",
    PROVIDED_ITEM = "Bereitgestellter Gegenstand",
    SHOW_WHOLE_CHAIN = "Klicken, um die gesamte Questreihe anzuzeigen",
    OPEN_REQUIRED_CHAIN = "Benötigte Questreihe öffnen.",
    SHOW_GIVER_ON_MAP = "Queststart auf Karte anzeigen",
    MAP_TOOLTIP = "Öffnet das passende Gebiet und markiert den Startpunkt dieser Quest. Rechtsklick auf die Markierung entfernt sie.",
    IN_DUNGEON = "Im Dungeon",
    NO_QUESTS = "Keine Quests",
    NO_FACTION_QUESTS = "Keine %s-Quests für diesen Dungeon erfasst.",
    NO_FACTION_QUESTS_TBD = "Noch keine %s-Quests für diesen Dungeon bekannt. Er ist neu und seine Quests werden noch gesammelt.",
    STEP_ACCEPT_ONLY = "(nur annehmen)",
    CHAIN_PICK_ONE = "Du brauchst nur 1 der folgenden Quests:",
    LOOT_NOTE_TWO_ITEMS = "Kann 2 Gegenstände droppen",
    LOOT_NOTE_HELNURATH = "Beschworen durch die epische Reittier-Quest der Hexenmeister",
    LOOT_NOTE_BURNING_FELGUARD = "Scarschild-Hexenmeister können ihn durch ihre Portale beschwören",
    UNIQUE_TRASH = "Einzigartige Beute von Trashmobs",
    DROPS_FROM = "Beute von: %s",
    CLICK_DUNGEON = "Klicken, um Dungeon-Details zu öffnen",
    HIDE_DUNGEONS = "Dungeons ausblenden",
    LOOT_FILTER = "Beutefilter",
    BUG_REPORT = "Fehler melden",
    BUG_REPORT_SHORT = "Melden",
    BUG_REPORT_TEXT = "Falsche Informationen gefunden oder neue Entdeckungen, die hinzugefügt werden sollten? Bitte melde es auf Discord, Screenshot erforderlich.",
    WM_WORLD_MAP = "Weltkarte",
    WM_DUNGEON_MAP = "Dungeonkarte",
    MINIMAP_HIDE_CONFIRM = "Minimap-Schaltfläche des Dungeon-Journals ausblenden?\n\nMit /dj minimap wird sie wieder angezeigt.",
    LF_SHOW_RECIPES = "Muster-/Rezept-Drops immer anzeigen",
    RESIZE_TIP_TITLE = "Skalieren",
    RESIZE_TIP = "Ziehen, um das Fenster zu skalieren. Rechtsklick zum Zurücksetzen.",
    OPT_RESIZE = "Größe ändern",
    OPT_RESIZE_TIP = "Öffnet das Journal, damit du es an den Ecken größer ziehen kannst.",
    RESIZE_HINT = "Ziehe an den Ecken, um die Größe zu ändern",
    RESIZE_CORNER_TIP = "Ziehen, um die Größe zu ändern. Rechtsklick setzt die Größe zurück.",
    OPT_RESET_SIZE = "Größe zurücksetzen",
    OPT_RESET_SIZE_TIP = "Setzt das Journal auf seine normale Größe und Skalierung zurück.",
    LF_ENABLE = "Aktivieren",
    LF_DISABLE = "Deaktivieren",
    LF_MIN_LEVEL = "Mindeststufe (benötigt)",
    LF_LEVEL_RANGE = "Stufenbereich",
    OPT_UI = "Allgemein",
    OPT_DISCORD_TEXT = "Tritt dem Dungeon Journal Discord bei, um Fehler zu melden, neue Entdeckungen zu teilen und die neuesten News zu erhalten.",
    OPT_DUNGEON_LIST = "Dungeonliste",
    OPT_HIDE_ITEM_LINE = "Journalzeile in Gegenstandstooltips ausblenden",
    OPT_HIDE_ITEM_LINE_TIP = "Entfernt die Zeile, die zeigt, von welchem Boss oder aus welcher Quest ein Gegenstand stammt.",
    OPT_AUTO_COMPARE = "Automatischer Gegenstandsvergleich",
    OPT_AUTO_COMPARE_TIP = "Gegenstandstooltips im Journal vergleichen sofort mit deinem angelegten Gegenstand, ohne dass du Shift gedrückt hältst.",
    MALLET_HOW = "So bekommst du den Hammer",
    OPT_HIDE_MINIMAP = "Minikartenknopf ausblenden",
    OPT_HIDE_MINIMAP_TIP = "Mit /dj minimap holst du den Knopf zurück.",
    OPT_BIND = "Taste: Journal öffnen",
    OPT_BIND_TIP = "Klicken, dann eine Taste drücken. Rechtsklick zum Löschen.",
    OPT_NOT_BOUND = "Nicht belegt",
    OPT_PRESS_KEY = "Taste drücken...",
    OPT_KEY_TAKEN = "%s ist bereits belegt. Wähle eine freie Taste.",
    OPT_NO_COMBAT = "Tastenbelegungen können im Kampf nicht geändert werden.",
    LEVEL_TOO_LOW_DUNGEONS = "Deine Stufe ist zu niedrig für Dungeons.\nDie ersten beginnen ab Stufe %d.",
    NO_DUNGEONS_MY_LEVEL = "Keine Dungeons für deine Stufe.",
    SHOW_ALL_DUNGEONS_ANYWAY = "Trotzdem alle Dungeons zeigen",
    SUMMON_QUEST_NOTE = "%s muss beschworen werden: Benutze %s am Gong bei seinem Becken.",
    REP_REQUIRES = "Benötigt %s bei %s",
    HOW_TO_SUMMON = "So beschwörst du %s",
    MAP_WREX_KEYRING = "Mit Wrex' Schlüsselring öffnen für Ebene %d",
    OPT_MY_LEVEL_RANGE = "Nur meinen Stufenbereich zeigen",
    OPT_MY_LEVEL_RANGE_TIP = "Zeigt nur die Dungeons, deren Stufenbereich deine Stufe enthält (die Bereiche der Gruppensuche).",
    OPT_HIDE_OUTLEVELED = "Zu niedrige Dungeons automatisch ausblenden",
    OPT_HIDE_OUTLEVELED_TIP = "Blendet einen Dungeon aus der Liste aus, sobald deine Stufe über seinem Stufenbereich liegt.",
    OPT_HIDE_QUESTS_DONE = "Dungeons mit allen Quests erledigt ausblenden",
    OPT_HIDE_QUESTS_DONE_TIP = "Blendet einen Dungeon aus der Liste aus, sobald du jede Quest erledigt hast, die dein Charakter dort machen kann.",
    OPT_HIDE_DONE_TICK = "Grünes Häkchen für fertige Dungeons ausblenden",
    OPT_HIDE_DONE_TICK_TIP = "Entfernt das grüne Häkchen auf der Startseite vor der Questanzahl eines Dungeons, dessen Quests du alle erledigt hast.",
    OPT_SHOW_ALL_CLASS = "Alle Klassenquests anzeigen",
    OPT_SHOW_ALL_CLASS_TIP = "Zeigt auch Klassenquests anderer Klassen (zum Beispiel Hexenmeister- oder Paladinquests). Aus: Du siehst nur die Quests deiner eigenen Klasse.",
    OPT_HIDE_LFG = "LFG-Button ausblenden",
    OPT_HIDE_LFG_TIP = "Blendet den Augen-Button neben „Ort anzeigen“ auf Dungeonseiten aus, der die Gruppensuche für diesen Dungeon öffnet. Geht auch per Rechtsklick auf das Auge → Deaktivieren.",
    OPT_HIDE_SLEEPING_BAG = "Schlafsack-Quest ausblenden",
    OPT_HIDE_SLEEPING_BAG_TIP = "Blendet das Schlafsack-Symbol auf der Startseite des Journals aus (neben den Symbolen für WoW Forever und Schlachtzüge). Geht auch per Rechtsklick auf das Symbol → Ausblenden. Eine verfolgte Schlafsack-Questreihe behält ihren Pfeil.",
    OPT_HIDE_DUNGEON_MAP = "Dungeonkarte im Dungeon ausblenden",
    OPT_HIDE_DUNGEON_MAP_TIP = "Wenn aktiviert, zeigt M im Dungeon die normale Karte des Spiels statt der Dungeonkarte des Journals.",
    DESCRIPTION = "Beschreibung",
    MINIMAP_OPTIONS = "Rechtsklick: Optionen",
    LF_ARMOR_ALL = "Alle",
    LF_ARMOR = "Rüstungsfilter",
    LF_WEAPON_ALL = "Alle",
    LF_WEAPON = "Waffenfilter",
    LF_WEAPONS = "Waffen",
    LF_ARMOR_TIP = "Blendet Rüstungsteile anderer Typen aus. Waffen, Schilde, Ringe, Halsketten, Schmuckstücke und Umhänge bleiben immer sichtbar.",
    CHAIN_REQUIRED = "Erfordert zuerst eine Questreihe.",
    CHAIN_STEP = "Du bist bei Schritt %d von %d.",
    GUIDE = "Anleitung",
    HOW_TO_COMPLETE = "So schließt du sie ab",
    GUIDE_TIP = "Klicken, um die Schritte zum Abschließen dieser Quest anzuzeigen",
    GUIDE_STEP = "Anleitung: Schritt %d von %d",
    SHOW_NEXT_STEP_MAP = "Nächsten Schritt auf Karte zeigen",
    LF_SHOW = "Ergebnisse",
    LF_SHOW_TIP = "Öffnet eine Seite mit allen Bossen aus allen Dungeons, die zur Auswahl passende Beute fallen lassen.",
    LF_RESULTS = "Passende Beute",
    LF_NO_RESULTS = "Keine Gegenstände passen zu diesen Filtern.",
    LF_BACK = "Schließen",
    LF_STAT_STR = "Stärke",
    LF_STAT_AGI = "Beweglichkeit",
    LF_STAT_STA = "Ausdauer",
    LF_STAT_INT = "Intelligenz",
    LF_STAT_SPI = "Willenskraft",
    LF_CLASS_ONLY = "Nur Beute anzeigen, die meine Klasse nutzen kann",
    LF_STATS_HEADER = "Nur Gegenstände mit diesen Werten",
    LF_STATS_HINT = "Gesuchte Werte auswählen. Ohne Auswahl wird alles angezeigt.",
    LF_MATCH_ALL = "Gegenstand muss alle gewählten Werte haben",
    LF_QUEST_REWARDS = "Auch Questbelohnungen zeigen",
    LF_SEARCHING = "Beute wird durchsucht... %d%%",
    LF_CLEAR = "Leeren",
    OPT_DISCORD_COPY = "Drücke Strg+C, um den Einladungslink zu kopieren.",
    OPT_CLOSE = "Schließen",
    RPG_LOCKED = "Gesperrt",
    RPG_LOCKED_CARD = "Besiege den letzten Boss eines Dungeons, um die Journalseite freizuschalten",
    RPG_PROGRESS_BAR = "Reise %d/%d (%d%%)",
    RPG_LOCKED_MSG = "Dieser Dungeon ist gesperrt. Besiege seinen Endboss, um ihn freizuschalten.",
    RPG_LOCKED_TIP2 = "Besiege den Endboss des Dungeons, um diese Seite freizuschalten.",
    RPG_LOCKED_TIP_TITLE = "Gesperrte Journalseite",
    RPG_LOCKED_TIP = "Besiege %s, den Endboss von %s, um diese Seite freizuschalten.",
    RPG_LOCKED_TIP_POINTS = "Das Freischalten bringt +%d Reisepunkte.",
    RPG_UNLOCKED_MSG = "%s ist jetzt in deinem Journal freigeschaltet!",
    RPG_TOAST_TITLE = "Journalseite freigeschaltet",
    RPG_TOAST_HINT = "Klicken, um sie im Journal zu öffnen",
    RPG_QUEST_TOAST_TITLE = "Dungeonquest freigeschaltet",
    RPG_QUEST_UNLOCKED_MSG = "%s: Quest freigeschaltet! %d/%d",
    RPG_QUEST_TOAST_HINT = "Klicken, um sie im Journal zu öffnen",
    RPG_BOSS_HIDDEN = "Besiege diesen Boss, um ihn aufzudecken.",
    RPG_TRASH_HIDDEN = "Besiege etwa 20 % der Gegner im Dungeon, um es aufzudecken.",
    RPG_QUEST_HIDDEN = "Nimm diese Quest an, um sie freizuschalten.",
    RPG_MAP_LOCKED_TITLE = "Karte gesperrt",
    RPG_MAP_LOCKED_TIP = "Besiege etwa 20 %% der Gegner im Dungeon, um sie freizuschalten: %d/%d.",
    RPG_MAP_LOCKED_MSG = "Die Dungeonkarte wird freigeschaltet, wenn etwa 20 %% der Gegner besiegt sind (%d/%d).",
    RPG_MAP_TOAST_TITLE = "Dungeonkarte freigeschaltet",
    RPG_MAP_UNLOCKED_MSG = "%s: Karte freigeschaltet!",
    RPG_MAP_TOAST_HINT = "Klicken, um die Karte im Journal zu öffnen",
    RPG_MAP_TOAST_HINT_M = "Drücke M im Dungeon, um sie zu sehen",
    RPG_BOSS_REVEALED_MSG = "%s im Journal aufgedeckt!",
    RPG_LOCKED_TIP_QUEST = "Nimmst du eine seiner Quests an, öffnet sich ein Teil davon.",
    RPG_PROGRESS = "Reise %d%%",
    RPG_PROGRESS_TITLE = "Dungeon-Reise",
    RPG_PROGRESS_TIP = "%d von %d Dungeon-Quests für deine Fraktion und Klasse abgeschlossen.",
    RPG_PROGRESS_PAGES = "%d von %d Journalseiten freigeschaltet (Endbosse besiegt).",
    RPG_PROGRESS_POINTS = "Jede Quest bringt %d Punkte, jede Journalseite %d.",
    RPG_SUBTITLE = "Besiege den Endboss eines Dungeons, um seine Seiten freizuschalten",
    MODE_TITLE = "Wähle dein Journal",
    MODE_SUB = "Du kannst das jederzeit in den Optionen (/dj options) oder mit /dj mode ändern.",
    MODE_GAMER = "Gamer-Modus",
    MODE_GAMER_DESC = "Das volle Journal: Jeder Dungeon, Boss, jede Beute und Quest ist von Anfang an offen.",
    MODE_RPG = "RPG-Modus",
    MODE_RPG_DESC = "Dungeons sind zu Beginn gesperrt und werden freigeschaltet, wenn du ihren Endboss besiegst. Ein Fortschrittsbalken zeigt alle abgeschlossenen Dungeon-Quests.",
    MODE_CHOOSE = "Wählen",
    RPG_CONFIRM_TEXT = "In diesem Modus bleiben Dungeons gesperrt, bis du den Endboss besiegst. Du kannst den Modus jederzeit in den Optionen ändern.",
    RPG_CONFIRM_OK = "Ok",
    RPG_CONFIRM_BACK = "Erneut wählen",
    RPG_INTRO_TEXT = "Dungeons bleiben gesperrt, bis du ihren Endboss besiegst.\nDu kannst die Quests trotzdem in den Optionen anzeigen lassen.", -- introline (2.0.17, text 2.0.18)
    RPG_INTRO_KEEP = "RPG-Modus behalten",
    RPG_INTRO_OPTIONS = "In den Optionen deaktivieren",
    MODE_RPG_ENABLE = "In den Optionen aktivieren",
    COMING_SOON = "Demnächst",
    PREVIEW_DATA_SOON = "Boss-, Beute- und Questdaten folgen bald.",
    PREVIEW_MAP_CLICK = "Klicken, um die Karte anzusehen.",
    ITEM_CLICK_MAP = "Klicken, um den Ort auf der Karte zu zeigen.",
    REPEAT_SHOW = "Wiederholbare Quests anzeigen (%d)",
    REPEAT_HIDE = "Wiederholbare Quests ausblenden (%d)",
    OPT_SHOW_ALL_PROF = "Alle Berufsquests anzeigen",
    OPT_SHOW_ALL_PROF_TIP = "Zeigt auch Berufsquests (Schmiedekunst, Bergbau...) für Berufe, die dieser Charakter nicht hat.",
    OPT_FOREVER_ONLY = "Nur Forever-Dungeons",
    OPT_FOREVER_ONLY_TIP = "Zeigt nur die Dungeons, die neu in WoW Forever sind. Haken entfernen, um wieder alle Dungeons zu sehen.",
    PROF_BLACKSMITHING = "Schmiedekunst",
    PROF_MINING = "Bergbau",
    RAIDS_TITLE = "Schlachtzüge",
    ITEM_UNSEEN_TITLE = "Noch nicht gesehen",
    ITEM_UNSEEN_TIP = "Dieser Gegenstand ist im Spiel, aber der Server hat seine Details noch nicht gesendet. Sie erscheinen, sobald jemand ihn gesehen hat (zum Beispiel, nachdem er gedroppt ist).",
    FOREVER_FILTER_TITLE = "WoW-Forever-Dungeons",
    FOREVER_FILTER_TIP = "Klicken, um nur die Dungeons anzuzeigen, die neu in WoW Forever sind.",
    FOREVER_FILTER_ON = "Es werden nur WoW-Forever-Dungeons angezeigt. Klicken, um wieder alle Dungeons anzuzeigen.",
    OPT_RPG_MODE = "RPG-Modus",
    OPT_RPG_MODE_TIP = "Dungeons bleiben gesperrt, bis dieser Charakter ihren Endboss besiegt; ein Fortschrittsbalken zeigt deine Dungeon-Quests.",
    OPT_VERSION = "Version: %s",
    OPT_ACCESS = "Optionen mit %s öffnen",
    OPT_OPEN_OPTIONS = "Optionen öffnen",
    OPT_COPY = "Kopieren",
    OPT_COPIED = "Kopiert!",
    OPT_TAB_OPTIONS = "Optionen",
    OPT_DISCORD = "Discord",
    LF_OK = "Ok",
    LF_HIDDEN_NOTE = "%d vom Beutefilter ausgeblendet",
    RECIPES_SECTION = "Rezepte & Muster (%d)",
    SHARED_SHOW = "Geteilte Beute anzeigen (%d)",
    SHARED_HIDE = "Geteilte Beute ausblenden (%d)",
    PROBABLE_LOOT = "Nicht bestätigt, aber wahrscheinlicher Drop (%d)",
    SHARED_NOTE = "geringe Dropchance, viele Bosse",
    SHARED_LOOT = "Geteilte Beute",
    SEVERAL_DUNGEONS = "mehrere Dungeons",
    LF_STAT_HEAL = "Heilung",
    LF_STAT_SPELL = "Zauberschaden",
    LF_STAT_AP = "Angriffskraft",
    LF_STAT_CRIT = "Kritischer Treffer",
    LF_STAT_SPELLCRIT = "Zauberkrit",
    LF_STAT_HIT = "Trefferchance",
    LF_STAT_SPELLHIT = "Zaubertreffer",
    LF_STAT_MP5 = "MP5",
    LF_STAT_MP5_TIP = "Mana alle 5 Sekunden",
    LF_STAT_HP5 = "HP5",
    LF_STAT_HP5_TIP = "Gesundheit alle 5 Sekunden",
    LF_ARMOR_BTN = "Rüstung",
    LF_RING = "Ring",
    LF_NECK = "Hals",
    LF_TRINKET = "Schmuck",
    LF_CLOAK = "Umhang",
    LF_WEAPON_BTN = "Waffe",
    LF_RESIST = "Widerstandsfilter",
    LF_RESISTANCES = "Widerstände",
    LF_RES_FIRE = "Feuer",
    LF_RES_HOLY = "Heilig",
    LF_SCHOOLS = "Zauberschulen",
    LF_RES_FROST = "Frost",
    LF_RES_NATURE = "Natur",
    LF_RES_SHADOW = "Schatten",
    LF_RES_ARCANE = "Arkan",
    LF_STAT_DEF = "Verteidigungswertung",
    DONE = "Fertig",
    HIDDEN = "Ausgeblendet",
    CLICK_HIDE_DUNGEON = "Klicken, um diesen Dungeon auszublenden.",
    CLICK_RESTORE_DUNGEON = "Klicken, um diesen Dungeon wieder einzublenden.",
    AUTO_HIDDEN_BY = "Ausgeblendet durch: %s",
    CLICK_SHOW_ANYWAY = "Klicken, um ihn trotzdem anzuzeigen.",
    ALL_DUNGEONS_HIDDEN = "Alle Dungeons sind ausgeblendet. Klicke auf Dungeons ausblenden, um sie wieder einzublenden.",
    FACTION_QUESTS = "%s-Quests",
    QUEST_IN_LOG = "Diese frühere Quest befindet sich in deinem Questlog.",
    QUEST_COMPLETED = "Diese frühere Quest wurde abgeschlossen.",
    QUEST_NOT_CACHED = "Der Questtext ist derzeit nicht im Client-Cache.",
    CLASS_ONLY = "NUR %s",
    MINIMAP_HIDDEN = "Minimap-Schaltfläche ausgeblendet. Mit /dj minimap wieder anzeigen.",
    MINIMAP_LEFT = "Linksklick: Öffnen / schließen",
    MINIMAP_DRAG = "Ziehen: Verschieben",
    MINIMAP_RIGHT = "Rechtsklick: Ausblenden",
    LANGUAGE_CURRENT = "Sprache: %s",
    LANGUAGE_SET = "Sprache auf %s gesetzt.",
    LANGUAGE_AUTO = "Automatisch (%s)",
    LANGUAGE_HELP = "Sprachtest: /dj lang de, fr, es, ru, it, pt, en oder auto",
    UPDATE_AVAILABLE = "Version %s ist verfügbar (du hast %s). Aktualisiere über CurseForge.",
    PREVIOUS_QUEST = "Vorherige Quest",
    REQUIRES_QUEST = "Erfordert: %s",
    NEXT_QUEST = "Nächste Quest",
    LEADS_TO = "Führt zu: %s",
    MAP_MARKER_REMOVED = "Kartenmarkierung entfernt.",
    MAP_LEFT_TARGET = "Linksklick, um den Questgeber in der Nähe anzuvisieren und zu markieren",
    MAP_RIGHT_REMOVE = "Rechtsklick zum Entfernen der Markierung",
    MAP_PATROL = "Läuft umher: die Linie zeigt den Weg",
    MAP_QUEST_TARGET = "Questziel",
    MAP_MARKED = "%s auf der Karte markiert.",
    MAP_OPEN_FAILED = "Der gespeicherte Kartenort konnte nicht geöffnet werden.",
    MAP_COMBAT = "Die Karte lässt sich im Kampf nicht öffnen. Drücke %s, um die markierte Stelle zu sehen.",
    QUEST_GIVER = "Questgeber",
    QUEST_STARTS_HERE = "Quest startet hier",
    TRACK = "Verfolgen",
    TRACKING = "Verfolgt",
    TRACK_TIP = "Zeigt die Quests dieses Dungeons mit deinem Fortschritt auf dem Bildschirm. Lässt sich überallhin ziehen.",
    TRACK_STOP = "Nicht mehr verfolgen",
    TRACK_READY = "Bereit zur Abgabe",
    TRACK_DONE = "Abgeschlossen",
    TRACK_IN_LOG = "In deinem Questlog",
    TRACK_CLICK = "Klicken, um sie im Journal zu öffnen",
    TURN_IN_HERE = "Hier abgeben",
    TRACK_ACCEPT = "Klicken, um die Quest anzunehmen",
}

local function NormalizeLanguage(value)
    value = tostring(value or "auto"):lower()
    if value == "de" or value == "dede" or value == "german" or value == "deutsch" then return "deDE" end
    if value == "fr" or value == "frfr" or value == "french" or value == "français" or value == "francais" then return "frFR" end
    if value == "es" or value == "eses" or value == "esmx" or value == "spanish" or value == "español" or value == "espanol" then return "esES" end
    if value == "ru" or value == "ruru" or value == "russian" or value == "русский" then return "ruRU" end
    if value == "it" or value == "itit" or value == "italian" or value == "italiano" then return "itIT" end
    if value == "zhtw" or value == "tw" or value == "繁體中文" or value == "繁体中文" then return "zhTW" end
    if value == "zh" or value == "zhcn" or value == "chinese" or value == "中文" or value == "简体中文" then return "zhCN" end
    if value == "ko" or value == "kokr" or value == "korean" or value == "한국어" then return "koKR" end
    if value == "pt" or value == "ptbr" or value == "portuguese" or value == "portugues" or value == "português" then return "ptBR" end
    if value == "en" or value == "enus" or value == "engb" or value == "english" then return "enUS" end
    return "auto"
end

function FDJ.GetLanguage()
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    local override = NormalizeLanguage(ForeverDungeonJournalDB.language)
    if override ~= "auto" then return override end
    local client = type(GetLocale) == "function" and GetLocale() or "enUS"
    if client == "deDE" then return "deDE" end
    if client == "frFR" then return "frFR" end
    if client == "esES" or client == "esMX" then return "esES" end
    if client == "ruRU" then return "ruRU" end
    if client == "itIT" then return "itIT" end
    if client == "ptBR" then return "ptBR" end
    if client == "koKR" then return "koKR" end
    if client == "zhCN" then return "zhCN" end
    if client == "zhTW" then return "zhTW" end
    return "enUS"
end

function FDJ.SetLanguage(value)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    ForeverDungeonJournalDB.language = NormalizeLanguage(value)
    return FDJ.GetLanguage(), ForeverDungeonJournalDB.language
end

function FDJ.L(key, ...)
    local lang = FDJ.GetLanguage()
    local active = FDJ.Locales[lang] or FDJ.Locales.enUS
    local value = active[key] or FDJ.Locales.enUS[key] or key
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, value, ...)
        if ok then return formatted end
    end
    return value
end


function FDJ.GetClientLanguage()
    local client = type(GetLocale) == "function" and GetLocale() or "enUS"
    if client == "deDE" then return "deDE" end
    if client == "frFR" then return "frFR" end
    if client == "esES" or client == "esMX" then return "esES" end
    if client == "ruRU" then return "ruRU" end
    if client == "itIT" then return "itIT" end
    if client == "ptBR" then return "ptBR" end
    if client == "koKR" then return "koKR" end
    if client == "zhCN" then return "zhCN" end
    if client == "zhTW" then return "zhTW" end
    return "enUS"
end

-- Client-provided quest/item strings are already localized, but only to the
-- actual WoW client language. When /dj lang forces a different language for
-- testing, use our content table instead of mixing English client text into it.
function FDJ.CanUseClientLocalizedText()
    return FDJ.GetLanguage() == FDJ.GetClientLanguage()
end

local function ContentTable()
    local all = FDJ.ContentLocales or {}
    return all[FDJ.GetLanguage()]
end

-- Free text is only ever translated as a WHOLE string or as whole
-- comma-separated parts ("Tinkmaster Overspark, Ironforge" -> the place part).
-- Words are never swapped inside a sentence: a sentence without a full
-- translation stays in English instead of becoming a half-translated mix.
local plainMapCache = {}
local function PlainText(pattern)
    return (pattern:gsub("%%(%p)", "%1"))
end
local function FreeTextMap(content, lang)
    local cached = plainMapCache[lang]
    if cached and cached.source == content then return cached.map end
    local map = {}
    for key, value in pairs(content.places or {}) do map[key] = value end
    for _, pair in ipairs(content.replacements or {}) do
        local key = PlainText(pair[1])
        if map[key] == nil then map[key] = (pair[2]:gsub("%%%%", "%%")) end
    end
    plainMapCache[lang] = { source = content, map = map }
    return map
end

function FDJ.LocalizeFreeText(value)
    if type(value) ~= "string" or value == "" then return value end
    local content = ContentTable()
    if not content then return value end
    local map = FreeTextMap(content, FDJ.GetLanguage())
    if map[value] then return map[value] end

    -- Whole parts separated by " — " (label lines) or commas (NPC, place).
    local function TranslateCommaList(text)
        if map[text] then return map[text], true end
        if not text:find(",", 1, true) then return text, false end
        local parts, changed = {}, false
        for part in text:gmatch("([^,]+)") do
            local clean = part:gsub("^%s+", ""):gsub("%s+$", "")
            local translated = map[clean]
            if translated then changed = true end
            parts[#parts + 1] = translated or clean
        end
        return table.concat(parts, ", "), changed
    end

    local dash = " \226\128\148 " -- " — "
    if value:find(dash, 1, true) then
        local out, changed, rest = {}, false, value
        while true do
            local i = rest:find(dash, 1, true)
            local piece = i and rest:sub(1, i - 1) or rest
            local t, c = TranslateCommaList(piece)
            out[#out + 1] = t
            changed = changed or c
            if not i then break end
            rest = rest:sub(i + #dash)
        end
        if changed then return table.concat(out, dash) end
        return value
    end

    local t, changed = TranslateCommaList(value)
    if changed then return t end
    return value
end


-- Reputation reward names need their own localization pass because reward
-- summaries store them together with the amount (for example
-- "Ironforge +100").  Localize the faction name before rebuilding that token
-- instead of requiring a translation entry for every possible amount.
local REPUTATION_NAMES = {
    deDE = {
        ["Alliance"] = "Allianz", -- repfix (2.0.8)
        ["Gadgetzan"] = "Gadgetzan",
        ["Kirin Tor"] = "Kirin Tor",
        ["Gnomeregan Exiles"] = "Gnomeregangnome",
        ["Argent Dawn"] = "Argentumdämmerung",
        ["Darnassus"] = "Darnassus",
        ["Darkspear Trolls"] = "Dunkelspeertrolle",
        ["Earthen Ring"] = "Der Irdene Ring",
        ["Orgrimmar"] = "Orgrimmar",
        ["Stormwind"] = "Sturmwind",
        ["Ironforge"] = "Eisenschmiede",
        ["Thunder Bluff"] = "Donnerfels",
        ["Undercity"] = "Unterstadt",
    },
    frFR = {
        ["Alliance"] = "Alliance", -- repfix (2.0.8)
        ["Gadgetzan"] = "Gadgetzan",
        ["Kirin Tor"] = "Kirin Tor",
        ["Gnomeregan Exiles"] = "Exilés de Gnomeregan",
        ["Argent Dawn"] = "Aube d'argent",
        ["Darnassus"] = "Darnassus",
        ["Darkspear Trolls"] = "Trolls Sombrelance",
        ["Earthen Ring"] = "Cercle terrestre",
        ["Orgrimmar"] = "Orgrimmar",
        ["Stormwind"] = "Hurlevent",
        ["Ironforge"] = "Forgefer",
        ["Thunder Bluff"] = "Pitons-du-Tonnerre",
        ["Undercity"] = "Fossoyeuse",
    },
    esES = {
        ["Alliance"] = "Alianza", -- repfix (2.0.8)
        ["Gadgetzan"] = "Gadgetzan",
        ["Kirin Tor"] = "Kirin Tor",
        ["Gnomeregan Exiles"] = "Exiliados de Gnomeregan",
        ["Argent Dawn"] = "Alba Argenta",
        ["Darnassus"] = "Darnassus",
        ["Darkspear Trolls"] = "Trols Lanza Negra",
        ["Earthen Ring"] = "Anillo de la Tierra",
        ["Orgrimmar"] = "Orgrimmar",
        ["Stormwind"] = "Ventormenta",
        ["Ironforge"] = "Forjaz",
        ["Thunder Bluff"] = "Cima del Trueno",
        ["Undercity"] = "Entrañas",
    },
    itIT = {
        ["Alliance"] = "Alleanza", -- repfix (2.0.8)
        ["Gadgetzan"] = "Gadgetzan",
        ["Kirin Tor"] = "Kirin Tor",
        ["Gnomeregan Exiles"] = "Esuli di Gnomeregan",
        ["Argent Dawn"] = "Alba d'Argento",
        ["Darnassus"] = "Darnassus",
        ["Darkspear Trolls"] = "Troll Lanciascura",
        ["Earthen Ring"] = "Circolo della Terra",
        ["Orgrimmar"] = "Orgrimmar",
        ["Stormwind"] = "Roccavento",
        ["Ironforge"] = "Forgiardente",
        ["Thunder Bluff"] = "Picco del Tuono",
        ["Undercity"] = "Sepulcra",
    },
    ptBR = {
        ["Alliance"] = "Aliança", -- repfix (2.0.8)
        ["Gadgetzan"] = "Geringontzan",
        ["Kirin Tor"] = "Kirin Tor",
        ["Gnomeregan Exiles"] = "Exilados de Gnomeregan",
        ["Argent Dawn"] = "Aurora Argêntea",
        ["Darnassus"] = "Darnassus",
        ["Darkspear Trolls"] = "Trolls Lançanegra",
        ["Earthen Ring"] = "Harmonia Telúrica",
        ["Orgrimmar"] = "Orgrimmar",
        ["Stormwind"] = "Ventobravo",
        ["Ironforge"] = "Altaforja",
        ["Thunder Bluff"] = "Penhasco do Trovão",
        ["Undercity"] = "Cidade Baixa",
    },
    ruRU = {
        ["Alliance"] = "Альянс", -- repfix (2.0.8)
        ["Gadgetzan"] = "Прибамбасск",
        ["Kirin Tor"] = "Kirin Tor",
        ["Gnomeregan Exiles"] = "Изгнанники Гномрегана",
        ["Argent Dawn"] = "Серебряный Рассвет",
        ["Darnassus"] = "Дарнас",
        ["Darkspear Trolls"] = "Тролли Черного Копья",
        ["Earthen Ring"] = "Служители Земли",
        ["Orgrimmar"] = "Оргриммар",
        ["Stormwind"] = "Штормград",
        ["Ironforge"] = "Стальгорн",
        ["Thunder Bluff"] = "Громовой Утёс",
        ["Undercity"] = "Подгород",
    },
    koKR = {
        ["Alliance"] = "얼라이언스", -- repfix (2.0.8)
        ["Gadgetzan"] = "가젯잔",
        ["Kirin Tor"] = "Kirin Tor",
        ["Gnomeregan Exiles"] = "놈리건 추방자",
        ["Argent Dawn"] = "은빛 여명회",
        ["Darnassus"] = "다르나서스",
        ["Darkspear Trolls"] = "검은창 트롤",
        ["Earthen Ring"] = "대지 고리회",
        ["Orgrimmar"] = "오그리마",
        ["Stormwind"] = "스톰윈드",
        ["Ironforge"] = "아이언포지",
        ["Thunder Bluff"] = "썬더 블러프",
        ["Undercity"] = "언더시티",
    },
    zhCN = {
        ["Alliance"] = "联盟", -- repfix (2.0.8)
        ["Gadgetzan"] = "加基森",
        ["Kirin Tor"] = "Kirin Tor",
        ["Gnomeregan Exiles"] = "诺莫瑞根流亡者",
        ["Argent Dawn"] = "银色黎明",
        ["Darnassus"] = "达纳苏斯",
        ["Darkspear Trolls"] = "暗矛巨魔",
        ["Earthen Ring"] = "大地之环",
        ["Orgrimmar"] = "奥格瑞玛",
        ["Stormwind"] = "暴风城",
        ["Ironforge"] = "铁炉堡",
        ["Thunder Bluff"] = "雷霆崖",
        ["Undercity"] = "幽暗城",
    },
    zhTW = {
        ["Alliance"] = "聯盟", -- repfix (2.0.8)
        ["Gadgetzan"] = "加基森",
        ["Kirin Tor"] = "Kirin Tor",
        ["Gnomeregan Exiles"] = "諾姆瑞根流亡者",
        ["Argent Dawn"] = "銀色黎明",
        ["Darnassus"] = "達納蘇斯",
        ["Darkspear Trolls"] = "暗矛食人妖",
        ["Earthen Ring"] = "大地之環",
        ["Orgrimmar"] = "奧格瑪",
        ["Stormwind"] = "暴風城",
        ["Ironforge"] = "鐵爐堡",
        ["Thunder Bluff"] = "雷霆崖",
        ["Undercity"] = "幽暗城",
    },
}

function FDJ.LocalizeReputationName(name)
    if type(name) ~= "string" or name == "" then return name end
    local names = REPUTATION_NAMES[FDJ.GetLanguage()]
    if names and names[name] then return names[name] end
    -- Keep this fallback so any future reputation name already present in the
    -- general content tables still localizes without another code change.
    return FDJ.LocalizeFreeText(name)
end

function FDJ.LocalizeDungeonName(internalName)
    local content = ContentTable()
    local entry = content and content.dungeons and content.dungeons[internalName]
    return (entry and entry.name) or internalName
end

function FDJ.LocalizeDungeonField(internalName, field, fallback)
    local content = ContentTable()
    local entry = content and content.dungeons and content.dungeons[internalName]
    local value = entry and entry[field]
    if value and value ~= "" then return value end
    return FDJ.LocalizeFreeText(fallback)
end

function FDJ.LocalizeQuestField(questID, field, fallback)
    -- Quest lists, trackers and prerequisite pages must use the same title as
    -- the player's client. Only query it for the matching journal language;
    -- another language still uses the verified static translations below.
    if field == "name" and FDJ.GetLanguage() ~= "itIT"
        and FDJ.CanUseClientLocalizedText() and type(questID) == "number"
        and questID > 0 and questID < 1000000 and C_QuestLog then
        local getter = C_QuestLog.GetTitleForQuestID or C_QuestLog.GetQuestInfo
        if type(getter) == "function" then
            local ok, title = pcall(getter, questID)
            if ok and not (type(issecretvalue) == "function" and issecretvalue(title))
                and type(title) == "string" and title ~= "" then
                return title
            end
        end
    end
    local content = ContentTable()
    local entry = content and content.quests and content.quests[questID]
    local value = entry and entry[field]
    if value and value ~= "" then return value end
    return FDJ.LocalizeFreeText(fallback)
end

function FDJ.LocalizeBossName(name)
    if name == "Recipes & Patterns" then
        -- Reuse the translated divider text ("Recipes & Patterns (%d)") without its count.
        local text = FDJ.L("RECIPES_SECTION", 0):gsub("%s*%(0%)%s*", "")
        return text
    end
    local content = ContentTable()
    local value = content and content.bosses and content.bosses[name]
    return value or FDJ.LocalizeFreeText(name)
end

-- sourcetipl10n (2.0.9, M 16 Nov 2026: the trash portrait tooltip "like
-- all trees, all satyrs ... doesn't get translated to other languages"):
-- the family a trash item's portraits stand for (sourceTip, Data/Dungeons.lua).
-- Eldreth spirits and Verek: the game's own names (Wowhead tooltips of npc
-- 11472 and 9042, per language); zhTW written from zhCN.
local SOURCE_TIPS = {
    deDE = { ["All trees"] = "Alle Bäume", ["All satyrs"] = "Alle Satyrn", ["All Eldreth spirits"] = "Alle Geister der Eldreth", ["Verek"] = "Verek" },
    frFR = { ["All trees"] = "Tous les arbres", ["All satyrs"] = "Tous les satyres", ["All Eldreth spirits"] = "Tous les esprits Eldreth", ["Verek"] = "Verek" },
    esES = { ["All trees"] = "Todos los árboles", ["All satyrs"] = "Todos los sátiros", ["All Eldreth spirits"] = "Todos los espíritus Eldreth", ["Verek"] = "Verek" },
    itIT = { ["All trees"] = "Tutti gli alberi", ["All satyrs"] = "Tutti i satiri", ["All Eldreth spirits"] = "Tutti gli spiriti Eldreth", ["Verek"] = "Verek" },
    ptBR = { ["All trees"] = "Todas as árvores", ["All satyrs"] = "Todos os sátiros", ["All Eldreth spirits"] = "Todos os espíritos eldretianos", ["Verek"] = "Verek" },
    ruRU = { ["All trees"] = "Все деревья", ["All satyrs"] = "Все сатиры", ["All Eldreth spirits"] = "Все элдретарские духи", ["Verek"] = "Верек" },
    koKR = { ["All trees"] = "모든 나무정령", ["All satyrs"] = "모든 사티로스", ["All Eldreth spirits"] = "모든 엘드레스 영혼", ["Verek"] = "베레크" },
    zhCN = { ["All trees"] = "所有树人", ["All satyrs"] = "所有萨特", ["All Eldreth spirits"] = "所有艾德雷斯鬼巫", ["Verek"] = "维雷克" },
    zhTW = { ["All trees"] = "所有樹人", ["All satyrs"] = "所有薩特", ["All Eldreth spirits"] = "所有艾德雷斯鬼巫", ["Verek"] = "維雷克" },
}
function FDJ.LocalizeSourceTip(text)
    if type(text) ~= "string" or text == "" then return text end
    local own = SOURCE_TIPS[FDJ.GetLanguage()]
    return (own and own[text]) or FDJ.LocalizeFreeText(text)
end

function FDJ.LocalizeItemSlot(slotText)
    if type(slotText) ~= "string" or slotText == "" then return slotText end
    local content = ContentTable()
    if not content or not content.slotParts then return slotText end

    -- Item categories in the database are comma-separated canonical tokens
    -- (for example "Shoulder, Leather" or "One-Hand, Dagger"). Translate
    -- each complete token instead of doing substring replacements. This avoids
    -- partial/ordering edge cases and guarantees mixed strings are fully
    -- localized.
    local translated = {}
    for token in slotText:gmatch("([^,]+)") do
        local clean = token:gsub("^%s+", ""):gsub("%s+$", "")
        translated[#translated + 1] = content.slotParts[clean] or clean
    end
    if #translated > 1 then
        return table.concat(translated, ", ")
    elseif #translated == 1 then
        return translated[1]
    end

    return content.slotParts[slotText] or slotText
end

function FDJ.LocalizeMapLocation(loc)
    if type(loc) ~= "table" then return loc end
    if FDJ.GetLanguage() == "enUS" then return loc end
    -- Do not mutate the database table; MapMarkers may retain it after a click.
    return {
        mapID = loc.mapID,
        x = loc.x,
        y = loc.y,
        label = FDJ.LocalizeFreeText(loc.label),
        detail = FDJ.LocalizeFreeText(loc.detail),
        noteKey = loc.noteKey, noteArg = loc.noteArg, -- (loreaspects: the arrow's note line, translated by its key)
        pickUp = loc.pickUp, exact = loc.exact, -- (bookexact: a thing to pick up at one place, in every language)
    }
end
