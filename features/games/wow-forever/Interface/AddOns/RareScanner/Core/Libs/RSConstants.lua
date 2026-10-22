-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

local RSConstants = private.NewLib("RareScannerConstants")

-- Locales
local AL = LibStub("AceLocale-3.0"):GetLocale("RareScanner");

-- RareScanner general libraries
local RSTextTags = private.ImportLib("RareScannerTextTags")

---============================================================================
-- DEBUG MODE
---============================================================================

RSConstants.DEBUG_MODE = false
RSConstants.DEBUG_ATLAS_VIGNETTE = false
RSConstants.DEBUG_SHOW_COMPLETED_GLYPHS = false

-- Use this constant to logger information about an specific entity while
-- displaying on the map. This is handy to find bugs in the POI filters
RSConstants.MAP_ENTITY_ID = nil

-- Use this constant to logger information about an specific item whie
-- displaying on the loot bar under the main button or the map. This is handy to find bugs
-- with the loot filters
RSConstants.LOOT_ITEM_ID = nil

---============================================================================
-- Current versions
---============================================================================

RSConstants.CURRENT_DB_VERSION = 232
RSConstants.CURRENT_LOOT_DB_VERSION = 199

---============================================================================
-- Current maps (newer)
---============================================================================

RSConstants.CURRENT_MAP_ID = 2537 -- Quel'Thalas
RSConstants.CURRENT_SUBMAP_ID = 2512 -- The Coiled Isle

---============================================================================
-- Default filtered entities by version
---============================================================================

RSConstants.DEFAULT_FILTERED_ENTITIES = {
	version = 67,
	containers = {382029, 383733, 383734, 383735, 376386, 376587}
}

---============================================================================
-- Other fixes
---============================================================================

RSConstants.FIX_RINGING_DEEPS_X_OFFSET_VERSION = 172
RSConstants.FIX_RINGING_DEEPS_X_OFFSET = 0.0416

---============================================================================
-- Special events
---============================================================================

RSConstants.SHADOWLANDS_PRE_PATCH_EVENT = 1
RSConstants.GREEDY_EMISSARY_EVENT = 2
RSConstants.WARCRAFT_RUMBLE_CROSSOVER_EVENT = 3
RSConstants.HEARTHSTONE_10TH_EVENT = 4
RSConstants.NOBLEGARDEN_EVENT = 5
RSConstants.WARWITHIN_PRE_PATCH_EVENT = 6
RSConstants.WOW_ANNIVERSARY_EVENT = 7
RSConstants.LEGION_REMIX_EVENT = 8
RSConstants.MIDNIGHT_PRE_PATCH_EVENT = 9
RSConstants.OLD_DELVE_NPCS = 10

RSConstants.EVENTS = {
	-- [RareScanner_EVENTID] = true|false|holidayTextureID;
	[RSConstants.SHADOWLANDS_PRE_PATCH_EVENT] = false;
	[RSConstants.GREEDY_EMISSARY_EVENT] = 5212619;
	[RSConstants.WARCRAFT_RUMBLE_CROSSOVER_EVENT] = true;
	[RSConstants.HEARTHSTONE_10TH_EVENT] = false;
	[RSConstants.NOBLEGARDEN_EVENT] = 235477;
	[RSConstants.WARWITHIN_PRE_PATCH_EVENT] = false;
	[RSConstants.WOW_ANNIVERSARY_EVENT] = 6238552;
	[RSConstants.LEGION_REMIX_EVENT] = 5788368;
	[RSConstants.MIDNIGHT_PRE_PATCH_EVENT] = false;
	[RSConstants.OLD_DELVE_NPCS] = false;
}

---============================================================================
-- Mini events
---============================================================================

RSConstants.DRAGONFLIGHT_DREAMSURGE_MINIEVENT = 1
RSConstants.DRAGONFLIGHT_STORM_INVASTION_FIRE_MINIEVENT = 2
RSConstants.DRAGONFLIGHT_STORM_INVASTION_WATER_MINIEVENT = 3
RSConstants.DRAGONFLIGHT_STORM_INVASTION_EARTH_MINIEVENT = 4
RSConstants.DRAGONFLIGHT_STORM_INVASTION_AIR_MINIEVENT = 5
RSConstants.DRAGONFLIGHT_HUNTING_PARTY_MINIEVENT = 6
RSConstants.DRAGONFLIGHT_FYRAKK_MINIEVENT = 7
RSConstants.DRAGONFLIGHT_WARCRAFT_RUMBLE_MINIEVENT = 8
RSConstants.DRAGONFLIGHT_DREAMSEED_MINIEVENT = 9
RSConstants.WARWITHIN_RARES_WORLDSOUL_MINIEVENT = 10
RSConstants.WARWITHIN_ROCKED_SLEEP_MINIEVENT = 11
RSConstants.WARWITHIN_TREASURES_ISLE_DORN_MINIEVENT = 12
RSConstants.WARWITHIN_TREASURES_RINGING_DEEPS_MINIEVENT = 13
RSConstants.WARWITHIN_NOTABLE_MACHINES_MINIEVENT = 14
RSConstants.WARWITHIN_BIBLO_ARCHIVIST_MINIEVENT = 15
RSConstants.WARWITHIN_KHAZALGAR_LORE_MINIEVENT = 16
RSConstants.WARWITHIN_TREASURES_HALLOWFALL_MINIEVENT = 17
RSConstants.WARWITHIN_TREASURES_AZJKAHET_MINIEVENT = 18
RSConstants.WARWITHIN_BOOKWORM_MINIEVENT = 19
RSConstants.WARWITHIN_NO_SO_QUICK_MINIEVENT = 20
RSConstants.WARWITHIN_SMELLING_HISTORY_MINIEVENT = 21
RSConstants.WARWITHIN_TREASURES_UNDERMINE_MINIEVENT = 22
RSConstants.WARWITHIN_READ_BETWEEN_LINES_MINIEVENT = 23
RSConstants.WARWITHIN_NINE_TENTHS_LAW_MINIEVENT = 24
RSConstants.WARWITHIN_FIGHTER_NIGHTMAN_MINIEVENT = 25
RSConstants.PANDARIA_IS_ANOTHER_MANS_TREASURE_MINIEVENT = 26
RSConstants.PANDARIA_RICHES_OF_PANDARIA_MINIEVENT = 27
RSConstants.PANDARIA_HOZEN_IN_THE_MIST_MINIEVENT = 28
RSConstants.PANDARIA_WHAT_WORTH_FIGHITING_MINIEVENT = 29
RSConstants.PANDARIA_LEGEND_BREWFATHERS_MINIEVENT = 30
RSConstants.PANDARIA_DARK_HEART_MOGU_MINIEVENT = 31
RSConstants.PANDARIA_BETWEEN_SAUROK_HARD_PLACE_MINIEVENT = 32
RSConstants.PANDARIA_SEVEN_BUDENS_SHAOHAO_MINIEVENT = 33
RSConstants.PANDARIA_FISH_TALES_MINIEVENT = 34
RSConstants.PANDARIA_BALLAD_LIU_LANG_MINIEVENT = 35
RSConstants.PANDARIA_SONG_YAUNGOL_MINIEVENT = 36
RSConstants.PANDARIA_HEART_MANTID_SWARM_MINIEVENT = 37
RSConstants.PANDARIA_ZANDALARI_PROFECY_MINIEVENT = 38
RSConstants.PANDARIA_RUMBLES_THUNDER_MINIEVENT = 39
RSConstants.PANDARIA_GODS_MONSTERS_MINIEVENT = 40
RSConstants.WARWITHIN_SECRETS_KARESHI_MINIEVENT = 41
RSConstants.WARWITHIN_TREASURES_KARESH_MINIEVENT = 42
RSConstants.LEGION_HIGHMOUNTAIN_MINIEVENT = 43
RSConstants.LEGION_VALSHARAH_MINIEVENT = 44
RSConstants.LEGION_STORMHEIM_MINIEVENT = 45
RSConstants.LEGION_SURAMAR_MINIEVENT = 46
RSConstants.LEGION_AZSUNA_MINIEVENT = 47
RSConstants.MIDNIGHT_TREASURES_EVERSONG_WOODS_MINIEVENT = 48
RSConstants.MIDNIGHT_LORE_HUNTER_MINIEVENT = 49
RSConstants.MIDNIGHT_TREASURES_ZUL_AMAN_MINIEVENT = 50
RSConstants.MIDNIGHT_TREASURES_VOIDSTORM_MINIEVENT = 51
RSConstants.MIDNIGHT_TREASURES_HARANDAR_MINIEVENT = 52
RSConstants.MIDNIGHT_EVERSONG_WOODS_HIGH_PEAKS_MINIEVENT = 53
RSConstants.LEGION_SHOOT_FIRST_LOOT_LATER_MINIEVENT = 54
RSConstants.MIDNIGHT_DUST_EM_OFF_MINIEVENT = 55
RSConstants.MIDNIGHT_CHRONICLER_HARANIR_MINIEVENT = 56
RSConstants.MIDNIGHT_ZUL_AMAN_HIGH_PEAKS_MINIEVENT = 57
RSConstants.MIDNIGHT_HARANDAR_HIGH_PEAKS_MINIEVENT = 58
RSConstants.MIDNIGHT_VOIDSTORM_HIGH_PEAKS_MINIEVENT = 59
RSConstants.MIDNIGHT_STUDENT_HISSTORY_MINIEVENT = 60
RSConstants.MIDNIGHT_TREASURES_COILED_ISLE_MINIEVENT = 61
RSConstants.MIDNIGHT_HONORED_DEAD_MINIEVENT = 62

-- Minievents that will have an option to filter/unfilter the icons from the worldmap
RSConstants.MINIEVENTS_WORLDMAP_FILTERS = {
	[RSConstants.LEGION_HIGHMOUNTAIN_MINIEVENT] = { active = true, containers = true, mapIDs = { 650, 651, 652, 654, 655, 657, 658, 659, 750 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_TREASURES_HIGHMOUNTAIN_CONTAINERS"] };
	[RSConstants.LEGION_VALSHARAH_MINIEVENT] = { active = true, containers = true, mapIDs = { 641, 642 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_TREASURES_VALSHARAH_CONTAINERS"] };
	[RSConstants.LEGION_STORMHEIM_MINIEVENT] = { active = true, containers = true, mapIDs = { 634, 636, 649 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_TREASURES_STORMHEIM_CONTAINERS"] };
	[RSConstants.LEGION_SURAMAR_MINIEVENT] = { active = true, containers = true, mapIDs = { 680, 682, 683, 684, 685, 686 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_TREASURES_SURAMAR_CONTAINERS"] };
	[RSConstants.LEGION_AZSUNA_MINIEVENT] = { active = true, containers = true, mapIDs = { 630, 631 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_TREASURES_AZSUNA_CONTAINERS"] };
	[RSConstants.LEGION_SHOOT_FIRST_LOOT_LATER_MINIEVENT] = { active = true, containers = true, mapIDs = { 830, 882, 885 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_SHOOT_FIRST_LOOT_LATER_CONTAINERS"] };
	[RSConstants.DRAGONFLIGHT_DREAMSURGE_MINIEVENT] = { active = true, npcs = true, mapIDs = { 2025, 2024, 2023, 2022 }, atlas = "dreamsurge_hub-icon", text = AL["MAP_MENU_SHOW_DREAMSURGE_RARE_NPCS"] };
	[RSConstants.DRAGONFLIGHT_STORM_INVASTION_FIRE_MINIEVENT] = { active = true, npcs = true, mapIDs = { 2025, 2024, 2023, 2022 }, atlas = "ElementalStorm-Lesser-Fire", text = AL["MAP_MENU_SHOW_FIRE_PRIMALSTORM_RARE_NPCS"] };
	[RSConstants.DRAGONFLIGHT_STORM_INVASTION_WATER_MINIEVENT] = { active = true, npcs = true, mapIDs = { 2025, 2024, 2023, 2022 }, atlas = "ElementalStorm-Lesser-Water", text = AL["MAP_MENU_SHOW_WATER_PRIMALSTORM_RARE_NPCS"] };
	[RSConstants.DRAGONFLIGHT_STORM_INVASTION_EARTH_MINIEVENT] = { active = true, npcs = true, mapIDs = { 2025, 2024, 2023, 2022 }, atlas = "ElementalStorm-Lesser-Earth", text = AL["MAP_MENU_SHOW_EARTH_PRIMALSTORM_RARE_NPCS"] };
	[RSConstants.DRAGONFLIGHT_STORM_INVASTION_AIR_MINIEVENT] = { active = true, npcs = true, mapIDs = { 2025, 2024, 2023, 2022 }, atlas = "ElementalStorm-Lesser-Air", text = AL["MAP_MENU_SHOW_AIR_PRIMALSTORM_RARE_NPCS"] };
	[RSConstants.DRAGONFLIGHT_HUNTING_PARTY_MINIEVENT] = { active = true, npcs = true, mapIDs = { 2025, 2024, 2023, 2022 }, atlas = "Vehicle-Trap-Gold", text = AL["MAP_MENU_SHOW_HUNTING_PARTY_RARE_NPCS"] };
	[RSConstants.DRAGONFLIGHT_FYRAKK_MINIEVENT] = { active = true, npcs = true, mapIDs = { 2023, 2024}, atlas = "Fyrakk-Head-Icon-Grey", text = AL["MAP_MENU_SHOW_FYRAKK_RARE_NPCS"] };
	[RSConstants.WARWITHIN_RARES_WORLDSOUL_MINIEVENT] = { active = true, npcs = true, mapIDs = { 2248, 2214, 2215, 2255, 2213, 2346 }, atlas = "echoes-icon", text = AL["MAP_MENU_SHOW_WORLDSOUL_RARE_NPCS"] };
	[RSConstants.WARWITHIN_FIGHTER_NIGHTMAN_MINIEVENT] = { active = true, npcs = true, mapIDs = { 2215, 2255, 2256, 2213, 2256 }, atlas = "renown-flame", text = AL["MAP_MENU_SHOW_FIGHTER_NIGHTMAN_RARE_NPCS"] };

	[RSConstants.DRAGONFLIGHT_WARCRAFT_RUMBLE_MINIEVENT] = { active = true, containers = true, mapIDs = { 2025, 2024, 2023, 2022, 2199, 2112, 1, 84, 85 }, atlas = "Battlenet-ClientIcon-GRY", text = AL["MAP_MENU_SHOW_WARCRAFT_RUMBLE_CONTAINERS"] };
	[RSConstants.DRAGONFLIGHT_DREAMSEED_MINIEVENT] = { active = true, containers = true, mapIDs = { 2200 }, atlas = "SeedPlanting-Full", text = AL["MAP_MENU_SHOW_DREAMSEED_CONTAINERS"] };
	[RSConstants.WARWITHIN_ROCKED_SLEEP_MINIEVENT] = { active = true, containers = true, mapIDs = { 2214 }, atlas = "Class", text = AL["MAP_MENU_SHOW_ROCKED_SLEEP_CONTAINERS"] };
	[RSConstants.WARWITHIN_TREASURES_ISLE_DORN_MINIEVENT] = { active = true, containers = true, mapIDs = { 2248, 2339 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_TREASURES_ISLE_DORN_CONTAINERS"] };
	[RSConstants.WARWITHIN_TREASURES_RINGING_DEEPS_MINIEVENT] = { active = true, containers = true, mapIDs = { 2214 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_TREASURES_RINGING_DEEPS_CONTAINERS"] };
	[RSConstants.WARWITHIN_NOTABLE_MACHINES_MINIEVENT] = { active = true, containers = true, mapIDs = { 2214 }, atlas = "mechagon-projects", text = AL["MAP_MENU_SHOW_NOTABLE_MACHINE_CONTAINERS"] };
	[RSConstants.WARWITHIN_BIBLO_ARCHIVIST_MINIEVENT] = { active = true, containers = true, mapIDs = { 2215 }, atlas = "Class", text = AL["MAP_MENU_SHOW_BIBLO_ARCHIVIST_CONTAINERS"] };
	[RSConstants.WARWITHIN_KHAZALGAR_LORE_MINIEVENT] = { active = true, containers = true, mapIDs = { 2248, 2214, 2215, 2255, 2213 }, atlas = "loreobject-32x32", text = AL["MAP_MENU_SHOW_KHAZALGAR_LORE_CONTAINERS"] };
	[RSConstants.WARWITHIN_TREASURES_HALLOWFALL_MINIEVENT] = { active = true, containers = true, mapIDs = { 2215 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_TREASURES_HALLOWFALL_CONTAINERS"] };
	[RSConstants.WARWITHIN_TREASURES_AZJKAHET_MINIEVENT] = { active = true, containers = true, mapIDs = { 2255, 2213, 2256 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_TREASURES_AZJKAHET_CONTAINERS"] };
	[RSConstants.WARWITHIN_BOOKWORM_MINIEVENT] = { active = true, containers = true, mapIDs = { 2255 }, atlas = "Class", text = AL["MAP_MENU_SHOW_BOOKWORM_CONTAINERS"] };
	[RSConstants.WARWITHIN_NO_SO_QUICK_MINIEVENT] = { active = true, containers = true, mapIDs = { 2214 }, atlas = "poi-scrapper", text = AL["MAP_MENU_SHOW_NO_SO_QUICK_CONTAINERS"] };
	[RSConstants.WARWITHIN_SMELLING_HISTORY_MINIEVENT] = { active = true, containers = true, mapIDs = { 2255, 2256, 2213, 2216 }, atlas = "Profession", text = AL["MAP_MENU_SMELLING_HISTORY_CONTAINERS"] };
	[RSConstants.WARWITHIN_TREASURES_UNDERMINE_MINIEVENT] = { active = true, containers = true, mapIDs = { 2346 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_TREASURES_UNDERMINE_CONTAINERS"] };
	[RSConstants.WARWITHIN_READ_BETWEEN_LINES_MINIEVENT] = { active = true, containers = true, mapIDs = { 2214, 2346 }, atlas = "Profession", text = AL["MAP_MENU_SHOW_READ_BETWEEN_LINES_CONTAINERS"] };
	[RSConstants.WARWITHIN_NINE_TENTHS_LAW_MINIEVENT] = { active = true, containers = true, mapIDs = { 2346 }, atlas = "Soulbind-32x32", text = AL["MAP_MENU_SHOW_NINE_TENTHS_LAW_CONTAINERS"] };
	[RSConstants.PANDARIA_IS_ANOTHER_MANS_TREASURE_MINIEVENT] = { active = true, containers = true, mapIDs = { 371, 379, 422, 418, 376, 388 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_IS_ANOTHER_MANS_TREASURE_CONTAINERS"] };
	[RSConstants.PANDARIA_RICHES_OF_PANDARIA_MINIEVENT] = { active = true, containers = true, mapIDs = { 371, 379, 418, 376, 388 }, atlas = "Banker", text = AL["MAP_MENU_SHOW_RICHES_OF_PANDARIA_CONTAINERS"] };
	[RSConstants.PANDARIA_HOZEN_IN_THE_MIST_MINIEVENT] = { active = true, containers = true, mapIDs = { 371, 379, 418, 376 }, atlas = "Vehicle-TempleofKotmogu-CyanBall", text = AL["MAP_MENU_SHOW_HOZEN_IN_THE_MIST_CONTAINERS"] };
	[RSConstants.PANDARIA_WHAT_WORTH_FIGHITING_MINIEVENT] = { active = true, containers = true, mapIDs = { 371, 379, 390, 418, 376 }, atlas = "Vehicle-TempleofKotmogu-GreenBall", text = AL["MAP_MENU_SHOW_WHAT_WORTH_FIGHITING_CONTAINERS"] };
	[RSConstants.PANDARIA_LEGEND_BREWFATHERS_MINIEVENT] = { active = true, containers = true, mapIDs = { 371, 379, 418 }, atlas = "Class", text = AL["MAP_MENU_SHOW_LEGEND_BREWFATHERS_CONTAINERS"] };
	[RSConstants.PANDARIA_DARK_HEART_MOGU_MINIEVENT] = { active = true, containers = true, mapIDs = { 371, 379, 390, 418 }, atlas = "Vehicle-TempleofKotmogu-PurpleBall", text = AL["MAP_MENU_SHOW_DARK_HEART_MOGU_CONTAINERS"] };
	[RSConstants.PANDARIA_BETWEEN_SAUROK_HARD_PLACE_MINIEVENT] = { active = true, containers = true, mapIDs = { 371, 418, 422, 433 }, atlas = "Profession", text = AL["MAP_MENU_SHOW_BETWEEN_SAUROK_HARD_PLACE_CONTAINERS"] };
	[RSConstants.PANDARIA_SEVEN_BUDENS_SHAOHAO_MINIEVENT] = { active = true, containers = true, mapIDs = { 371, 379, 390, 376, 388, 418 }, atlas = "poi-workorders", text = AL["MAP_MENU_SHOW_SEVEN_BUDENS_SHAOHAO_CONTAINERS"] };
	[RSConstants.PANDARIA_FISH_TALES_MINIEVENT] = { active = true, containers = true, mapIDs = { 371, 379, 376, 418 }, atlas = "Fishing-Hole", text = AL["MAP_MENU_SHOW_FISH_TALES_CONTAINERS"] };
	[RSConstants.PANDARIA_BALLAD_LIU_LANG_MINIEVENT] = { active = true, containers = true, mapIDs = { 376, 418 }, atlas = "PathofAscension-32x32", text = AL["MAP_MENU_SHOW_BALLAD_LIU_LANG_CONTAINERS"] };
	[RSConstants.PANDARIA_SONG_YAUNGOL_MINIEVENT] = { active = true, containers = true, mapIDs = { 379, 388 }, atlas = "dragon-rostrum", text = AL["MAP_MENU_SHOW_SONG_YAUNGOL_CONTAINERS"] };
	[RSConstants.PANDARIA_HEART_MANTID_SWARM_MINIEVENT] = { active = true, containers = true, mapIDs = { 422 }, atlas = "nazjatar-nagaevent", text = AL["MAP_MENU_SHOW_HEART_MANTID_SWARM_CONTAINERS"] };
	[RSConstants.PANDARIA_ZANDALARI_PROFECY_MINIEVENT] = { active = true, containers = true, mapIDs = { 504 }, atlas = "Profession", text = AL["MAP_MENU_SHOW_ZANDALARI_PROFECY_CONTAINERS"] };
	[RSConstants.PANDARIA_RUMBLES_THUNDER_MINIEVENT] = { active = true, containers = true, mapIDs = { 504 }, atlas = "Class", text = AL["MAP_MENU_SHOW_RUMBLES_THUNDER_CONTAINERS"] };
	[RSConstants.PANDARIA_GODS_MONSTERS_MINIEVENT] = { active = true, containers = true, mapIDs = { 504 }, atlas = "Vehicle-Mogu", text = AL["MAP_MENU_SHOW_GODS_MONSTERS_CONTAINERS"] };
	[RSConstants.WARWITHIN_SECRETS_KARESHI_MINIEVENT] = { active = true, containers = true, mapIDs = { 2371, 2472 }, atlas = "Profession", text = AL["MAP_MENU_SHOW_SECRETS_KARESHI_CONTAINERS"] };
	[RSConstants.WARWITHIN_TREASURES_KARESH_MINIEVENT] = { active = true, containers = true, mapIDs = { 2371, 2472 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_TREASURES_KARESH_CONTAINERS"] };
	[RSConstants.MIDNIGHT_TREASURES_EVERSONG_WOODS_MINIEVENT] = { active = true, containers = true, mapIDs = { 2393, 2395 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_EVERSONG_WOODS_CONTAINERS"] };
	[RSConstants.MIDNIGHT_LORE_HUNTER_MINIEVENT] = { active = true, containers = true, mapIDs = { 2393, 2395, 2405, 2437, 2413 }, atlas = "Class", text = AL["MAP_MENU_SHOW_MIDNIGHT_LORE_HUNTER_CONTAINERS"] };
	[RSConstants.MIDNIGHT_TREASURES_ZUL_AMAN_MINIEVENT] = { active = true, containers = true, mapIDs = { 2437 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_TREASURES_ZUL_AMAN_CONTAINERS"] };
	[RSConstants.MIDNIGHT_TREASURES_VOIDSTORM_MINIEVENT] = { active = true, containers = true, mapIDs = { 2405 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_TREASURES_VOIDSTORM_CONTAINERS"] };
	[RSConstants.MIDNIGHT_TREASURES_HARANDAR_MINIEVENT] = { active = true, containers = true, mapIDs = { 2413 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_TREASURES_HARANDAR_CONTAINERS"] };
	[RSConstants.MIDNIGHT_EVERSONG_WOODS_HIGH_PEAKS_MINIEVENT] = { active = true, containers = true, mapIDs = { 2393, 2395 }, atlas = "Warfronts-FieldMapIcons-Empty-Banner-Minimap", text = AL["MAP_MENU_SHOW_HIGH_PEAKS_EVERSONG_WOODS_CONTAINERS"] };
	[RSConstants.MIDNIGHT_DUST_EM_OFF_MINIEVENT] = { active = true, containers = true, mapIDs = { 2413, 2576 }, atlas = "AncientMana", text = AL["MAP_MENU_SHOW_DUST_EM_OFF_CONTAINERS"] };
	[RSConstants.MIDNIGHT_CHRONICLER_HARANIR_MINIEVENT] = { active = true, containers = true, mapIDs = { 2413 }, atlas = "housing-map-deed", text = AL["MAP_MENU_SHOW_CHRONICLER_HARANIR_CONTAINERS"] };
	[RSConstants.MIDNIGHT_ZUL_AMAN_HIGH_PEAKS_MINIEVENT] = { active = true, containers = true, mapIDs = { 2437, 2536, 2395 }, atlas = "Warfronts-FieldMapIcons-Empty-Banner-Minimap", text = AL["MAP_MENU_SHOW_HIGH_PEAKS_ZUL_AMAN_CONTAINERS"] };
	[RSConstants.MIDNIGHT_HARANDAR_HIGH_PEAKS_MINIEVENT] = { active = true, containers = true, mapIDs = { 2413 }, atlas = "Warfronts-FieldMapIcons-Empty-Banner-Minimap", text = AL["MAP_MENU_SHOW_HIGH_PEAKS_HARANDAR_CONTAINERS"] };
	[RSConstants.MIDNIGHT_VOIDSTORM_HIGH_PEAKS_MINIEVENT] = { active = true, containers = true, mapIDs = { 2405 }, atlas = "Warfronts-FieldMapIcons-Empty-Banner-Minimap", text = AL["MAP_MENU_SHOW_HIGH_PEAKS_VOIDSTORM_CONTAINERS"] };
	[RSConstants.MIDNIGHT_STUDENT_HISSTORY_MINIEVENT] = { active = true, containers = true, mapIDs = { 2512, 2509 }, atlas = "Class", text = AL["MAP_MENU_SHOW_STUDENT_HISSTORY_CONTAINERS"] };
	[RSConstants.MIDNIGHT_TREASURES_COILED_ISLE_MINIEVENT] = { active = true, containers = true, mapIDs = { 2512 }, atlas = "Auctioneer", text = AL["MAP_MENU_SHOW_TREASURES_COILED_ISLE_CONTAINERS"] };
	[RSConstants.MIDNIGHT_HONORED_DEAD_MINIEVENT] = { active = true, containers = true, mapIDs = { 2509, 2636 }, atlas = "TeleportationNetwork-Revendreth-32x32", text = AL["MAP_MENU_SHOW_HONORED_DEAD_CONTAINERS"] };
}

if (RSTextTags) then
	for _, minieventData in pairs (RSConstants.MINIEVENTS_WORLDMAP_FILTERS) do
		if (minieventData.text) then
			minieventData.text = RSTextTags.ParseText(minieventData.text)
		end
	end
end

---============================================================================
-- World events
---============================================================================

RSConstants.ULDUM_INVASSION_QUESTS = {57157,55350,56308}
RSConstants.VALLEY_BLOSSOMS_INVASSION_QUESTS = {56064,57728,57008}

---============================================================================
-- Timers
---============================================================================

RSConstants.CHECK_RESET_RECENTLY_SEEN_TIMER = 5 --5 seconds
RSConstants.RECENTLY_SEEN_RESET_TIMER = 120 --2 minutes
RSConstants.RECENTLY_SEEN_INSTANCE_RESET_TIMER = 120 * 15 --30 minutes
RSConstants.RECENTLY_SEEN_PING_ANIMATION_TIMER = 5 --5 seconds
RSConstants.CACHE_ALL_COMPLETED_QUEST_IDS_TIMER = 60 --1 minute
RSConstants.FIND_HIDDEN_QUESTS_TIMER = 5 --5 seconds after killing a NPC or opening a container
RSConstants.CHECK_RESPAWN_THRESHOLD = 150 --2.5 minutes
RSConstants.CHECK_RESPAWN_TIMER = 60 --1 minute
RSConstants.CHECK_RESET_NOTIFICATIONS_TIMER = 10 --10 seconds
RSConstants.CHECK_TARGETS_TIMER = 1 --1 seconds
RSConstants.BUTTON_TIMER = 1 --1 seconds
RSConstants.PREFOUND_TIMER = 5 --5 seconds

---============================================================================
-- Collections enumerators
---============================================================================

RSConstants.ITEM_SOURCE = {
	NPC = 1,
	CONTAINER = 2
}

RSConstants.ITEM_TYPE = {
	UNKNOWN = 0,
	APPEARANCE = 1,
	TOY = 2,
	PET = 3,
	MOUNT = 4,
	DRAKEWATCHER = 5,
	DECOR = 6,
	CUSTOM = "c%s"
}

---============================================================================
-- Types of entity by map (used in MapEntitiesTables)
---============================================================================

RSConstants.MAP_ENTITY_NPC = 1
RSConstants.MAP_ENTITY_CONTAINER = 2
RSConstants.MAP_ENTITY_EVENT = 3

---============================================================================
-- Types of entity filters
---============================================================================

RSConstants.ENTITY_FILTER_ALL = 1
RSConstants.ENTITY_FILTER_WORLDMAP = 2
RSConstants.ENTITY_FILTER_ALERTS = 3

---============================================================================
-- Events when adding animations to the world map
---============================================================================

RSConstants.MAP_ANIMATIONS_ON_FOUND = 1
RSConstants.MAP_ANIMATIONS_ON_CLICK = 2
RSConstants.MAP_ANIMATIONS_ON_BOTH = 3

---============================================================================
-- Tracking systems
---============================================================================

RSConstants.TRACKING_SYSTEM = {
	VIGNETTE = 1,
	NAMEPLATE_MOUSEOVER = 2,
	UNIT_TARGET = 3,
	CHAT_EMOTE = 4,
	AURA = 5,
	TOAST_EVENT = 6,
	SOFT_INTERACT = 7
}

---============================================================================
-- Addons default settings
---============================================================================

RSConstants.PROFILE_DEFAULTS = {
	profile = {
		general = {
			rescanTimer = 5,
			scanRares = true,
			scanContainers = true,
			scanEvents = true,
			scanChatAlerts = true,
			scanGarrison = false,
			scanInstances = false,
			scanOnTaxi = true,
			scanOnPetBattle = true,
			scanOnRacingQuest = true,
			scanWorldmapVignette = true,
			scanWithMacro = false,
			scanWithMacroPerChar = false,
			scanSoftInteract = false,
			pingTarget = false,
			originalSoftInteractCVars = false,
			autoHideButtonInstances = false,
			ignoreCompletedEntities = true,
			showMaker = true,
			marker = 8,
			enableWaypointsSupport = false,
			autoWaypoints = false,
			enableTomtomSupport = false,
			autoTomtomWaypoints = false,
			showTomtomMinimapIcon = false,
			showTomtomWorldmapIcon = false,
			enableWaypointUISupport = false,
			autoWaypointUIWaypoints = false
		},
		sound = {
			soundDisabled = false,
			soundObjectDisabled = false,
			soundChannel = "Master",
			soundVolume = 4,
			soundPlayed = "Horn",
			soundObjectPlayed = "PVP Horde",
			soundCustomFolder = "RareScannerSounds"
		},
		display = {
			displayButton = true,
			displayMiniature = true,
			displayButtonContainers = true,
			autoHideButton = 0,
			scale = 0.8,
			lockPosition = false,
			displayRaidWarning = true,
			flashWindowsTaskBar = true,
			displayChatMessage = true,
			chatWindowName = nil,
			displayTimestampChatMessage = true,
			enableNavigation = true,
			navigationLockEntity = false,
			minimapButton = {
				hide = false
			},
			worldmapButton = true
		},
		rareFilters = {
			defaultNpcFilterType = RSConstants.ENTITY_FILTER_ALL,
			filterWeeklyRep = false
		},
		containerFilters = {
			defaultContainerFilterType = RSConstants.ENTITY_FILTER_ALL,
			filterAchievements = false,
			filterRepeatable = false
		},
		eventFilters = {
			defaultEventFilterType = RSConstants.ENTITY_FILTER_ALL
		},
		zoneFilters = {
			defaultZoneFilterType = RSConstants.ENTITY_FILTER_ALL
		},
		collections = {
			filteredOnlyOnWorldMap = false,
			autoFilteringOnCollect = false,
			createProfileBackup = true,
			searchingPets = true,
			searchingMounts = true,
			searchingToys = true,
			searchingAppearances = true,
			searchingClassAppearances = true,
			searchingDrakewatcher = true,
			searchingDecors = true,
			searchingMissingAchievementCriteria = true,
			showFiltered = true,
			showDead = true,
			showWithoutCollectibles = false,
			lockingMap = false
		},
		map = {
			displayNpcIcons = true,
			displayNotDiscoveredNpcIcons = true,
			displayAlreadyKilledNpcIcons = false,
			displayAlreadyKilledNpcIconsReseteable = false,
			displayWeeklyRepNpcIcons = true,
			displayProfessionRaresNpcIcons = true,
			displayAchievementRaresNpcIcons = true,
			displayMinieventsNpcIcons = { true, true, true, true, true, true, true, true, true, true, false, false, true, true, true, false, false, true, true, true },
			displayCustomGroupNpcIcons = {},
			displayOtherRaresNpcIcons = true,
			displayRenownRaresNpcIcons = false,
			displayContainerIcons = true,
			displayAlreadyOpenedContainersIcons = false,
			displayNotDiscoveredContainerIcons = true,
			displayNotTrackeableContainerIcons = true,
			displayAchievementContainerIcons = true,
			displayProfessionContainerIcons = true,
			displayOtherContainerIcons = true,
			displayRenownContainerIcons = false,
			displayEventIcons = true,
			displayNotDiscoveredEventIcons = true,
			disableLastSeenFilter = false,
			displayFriendlyNpcIcons = false,
			displayOldNotDiscoveredMapIcons = true,
			displayDragonGlyphsIcons = true,
			displayAlreadyCompletedEventIcons = false,
			supportMapIcons = true,
			displayFilteredIngameMapIcons = true,
			playerPinOntop = false,
			maxSeenTime = 0,
			maxSeenTimeContainer = 0,
			maxSeenTimeEvent = 5,
			scale = 0.8,
			minimapscale = 0.7,
			showingWorldMapSearcher = true,
			cleanWorldMapSearcherOnChange = true,
			displayMinimapIcons = true,
			ignoreWmOnMinimap = false,
			waypointIngame = true,
			waypointTomtom = false,
			waypointWaypointUI = false,
			tooltipsScale = 1.0,
			tooltipsOnIngameIcons = true,
			tooltipsAchievements = true,
			tooltipsNotes = true,
			tooltipsState = true,
			tooltipsCounters = true,
			tooltipsSeen = true,
			tooltipsCommands = true,
			tooltipsExtraInfo = true,
			tooltipsFilterState = true,
			lootAchievTooltipsScale = 0.7,
			lootAchievementsPosition = "ANCHOR_LEFT",
			overlayMaxColours = 10,
			overlayColour1 = { 1, 0.2, 1 },
			overlayColour2 = { 0.23, 0.943, 1 },
			overlayColour3 = { 0.98, 0.99, 0.19 },
			overlayColour4 = { 0, 0.12, 1 },
			overlayColour5 = { 0.317, 1, 0.1 },
			overlayColour6 = { 1, 0.35, 0.11 },
			overlayColour7 = { 0.08, 0.55, 1 },
			overlayColour8 = { 0.18, 1, 0.42 },
			overlayColour9 = { 1, 0.04, 0.4 },
			overlayColour10 = { 0.4, 0.007, 1 },
			animationNpcs = true,
			animationNpcsType = RSConstants.MAP_ANIMATIONS_ON_BOTH,
			animationContainers = true,
			animationContainersType = RSConstants.MAP_ANIMATIONS_ON_CLICK,
			animationEvents = true,
			animationEventsType = RSConstants.MAP_ANIMATIONS_ON_CLICK,
			animationVignettes = true,
			highlightReputation = true,
			autoGuidanceIcons = true,
			displayMinimapRoute = true,
			displayRouteArrows = true,
			routeColour = { 0.2, 0.8, 1.0 },
			routeLineThickness = 2
		},
		loot = {
			filteredLootCategories = {},
			filteredItems = {},
			displayLoot = true,
			displayLootOnMap = true,
			lootTooltipPosition = "ANCHOR_LEFT",
			lootMinQuality = 0,
			filterItemsCompletedQuest = true,
			filterNotEquipableItems = false,
			filterNotMatchingClass = false,
			filterNotMatchingFaction = true,
			filterAnimaItems = true,
			filterConduitItems = true,
			filterByExplorerResults = false,
			showingMissingMounts = true,
			showingMissingPets = true,
			showingMissingToys = true,
			showingMissingAppearances = true,
			showingMissingClassAppearances = true,
			showingMissingDrakewatcher = true,
			showingMissingDecors = true,
			numItems = 10,
			numItemsPerRow = 10,
			tooltipsCommands = true,
			tooltipsCanImogit = false,
			tooltipsTSM = true,
			covenantRequirement = true
		},
		chat = {
			waypointIngame = true,
			waypointTomtom = false,
			waypointWaypointUI = false,
			tooltipsScale = 1,
			tooltipsCounters = true,
			tooltipsAchievements = true,
			tooltipsNotes = true,
			tooltipsLoot = true,
			tooltipsSeen = true,
			tooltipsCommands = true,
			tooltipsFilterScale = 0.75,
			colorNpc = "85c1e9",
			colorContainer = "d7dbdd",
			colorEvent = "f7dc6f",
		}
	}
}

---============================================================================
-- Macro settings
---============================================================================

RSConstants.RARESCANNER_MACRO_NAME = "RS_MACRO"
RSConstants.RARESCANNER_MACRO_ICON = "Interface/Icons/Icon_upgradestone_rare"
RSConstants.RARESCANNER_MACRO_TARGET_DISTANCE_YARDS = 200
RSConstants.RARESCANNER_MACRO_UPDATE_NPCS_DISTANCE_YARDS = 40
RSConstants.RARESCANNER_MACRO_REFRESH_TIMER = 2 --seconds

---============================================================================
-- Name of the RareScanner's button
---============================================================================

RSConstants.RS_BUTTON_NAME = "RARESCANNER_BUTTON"

---============================================================================
-- Sounds
---============================================================================

RSConstants.DEFAULT_SOUNDS = {
	["Achievement Sound"] = "Interface\\AddOns\\RareScanner\\Media\\achievmentsound1-4.ogg",
	["Alarm Clock"] = "Interface\\AddOns\\RareScanner\\Media\\alarmclockwarning2-4.ogg",
	["Boat Docking"] = "Interface\\AddOns\\RareScanner\\Media\\boatdockedwarning-4.ogg",
	["Siege Engineer Weapon"] = "Interface\\AddOns\\RareScanner\\Media\\fx_ograid_siege_weaponmachine_warning-4.ogg",
	["PVP Alliance"] = "Interface\\AddOns\\RareScanner\\Media\\pvpwarningalliance-4.ogg",
	["PVP Horde"] = "Interface\\AddOns\\RareScanner\\Media\\pvpwarninghorde-4.ogg",
	["Ready Check"] = "Interface\\AddOns\\RareScanner\\Media\\readycheck-4.ogg",
	["Horn"] = "Interface\\AddOns\\RareScanner\\Media\\gruntling_horn_bb-4.ogg",
	["Event Wardrum Ogre"] = "Interface\\AddOns\\RareScanner\\Media\\Event_wardrum_ogre-4.ogg",
	["Level Up"] = "Interface\\AddOns\\RareScanner\\Media\\levelup2-4.ogg",
}

RSConstants.EXTERNAL_SOUND_FOLDER = "Interface\\AddOns\\%s\\%s"
RSConstants.ERROR_SOUND_CLOSE_ID = 567464 --(close), 567490 (open)
RSConstants.ERROR_SOUND_OPEN_ID = 567490 --(close), 567490 (open)

---============================================================================
-- CMD commands
---============================================================================

RSConstants.CMD_HELP = "help"
RSConstants.CMD_TOGGLE_MAP_ICONS = "tmi"
RSConstants.CMD_TOGGLE_ALERTS = "ta"
RSConstants.CMD_TOGGLE_RARES = "tr"
RSConstants.CMD_TOGGLE_RARES_ALERTS = "tra"
RSConstants.CMD_TOGGLE_EVENTS = "te"
RSConstants.CMD_TOGGLE_EVENTS_ALERTS = "tea"
RSConstants.CMD_TOGGLE_TREASURES = "tt"
RSConstants.CMD_TOGGLE_TREASURES_ALERTS = "tta"
RSConstants.CMD_TOGGLE_FILTER_REPEATABLE_TREASURES = "frt"
RSConstants.CMD_TOGGLE_SCANNING_WORLD_MAP_VIGNETTES = "swmv"
RSConstants.CMD_TOMTOM_WAYPOINT = "waypoint"
RSConstants.CMD_TOGGLE_DRAGON_GLYPHS = "tdg"
RSConstants.CMD_OPEN_EXPLORER = "explorer"
RSConstants.CMD_RECENTLY_SEEN = "rseen"
RSConstants.CMD_IMPORT = "import"
RSConstants.CMD_MIDNIGHT_PRE_PATCH = "midnight"
RSConstants.CMD_ROUTE = "route"
RSConstants.CMD_ROUTE_CANCEL = "croute"

---============================================================================
-- AtlasNames
---============================================================================

RSConstants.NPC_VIGNETTE = "VignetteKill"
RSConstants.NPC_VIGNETTE_ELITE = "VignetteKillElite"
RSConstants.NPC_LEGION_VIGNETTE = "DemonInvasion5"
RSConstants.NPC_NAZJATAR_VIGNETTE = "nazjatar-nagaevent"
RSConstants.NPC_WARFRONT_NEUTRAL_HERO_VIGNETTE = "Warfront-NeutralHero"
RSConstants.NPC_TORMENTORS_VIGNETTE = "Tormentors-Boss"
RSConstants.NPC_DIABLO_GOBLIN = "BuildanAbomination-32x32"
RSConstants.NPC_WARLOCK_PORTAL_GOBLIN = "WarlockPortal-Yellow-32x32"
RSConstants.NPC_VIGNETTE_BOSS = "vignettekillboss"

RSConstants.CONTAINER_VIGNETTE = "VignetteLoot"
RSConstants.CONTAINER_ELITE_VIGNETTE = "VignetteLootElite"
RSConstants.CONTAINER_LOCKED_VIGNETTE = "vignetteloot-locked"
RSConstants.CONTAINER_ELITE_LOCKED_VIGNETTE = "vignettelootelite-locked"
RSConstants.CONTAINER_LORE_OBJECT = "loreobject-32x32"
RSConstants.CONTAINER_HIGH_PEAK_OBJECT = "Warfronts-FieldMapIcons-Empty-Banner-Minimap-small"
RSConstants.CONTAINER_PVP_AIRPLANE_OBJECT = "Vehicle-Air-Occupied"
RSConstants.CONTAINER_PVP_FLAGS_OBJECT = "CrossedFlags"
RSConstants.CONTAINER_GLOWING_MOTHS_OBJECT = "AncientMana"

RSConstants.EVENT_VIGNETTE = "VignetteEvent"
RSConstants.EVENT_ELITE_VIGNETTE = "VignetteEventElite"
RSConstants.EVENT_TORMENTORS_VIGNETTE = "Tormentors-Event"
RSConstants.EVENT_HORN = "minimap-genericevent-hornicon-small"
RSConstants.EVENT_SCRAP_VIGNETTE = "SCRAP-deactivated"

---============================================================================
-- SpellIDs
---============================================================================

RSConstants.RACING_SPELL_ID = 369968

---============================================================================
-- FileIDs
---============================================================================

RSConstants.DUNDUN_EVENT_ICON = 647701

---============================================================================
-- MapIDS
---============================================================================

RSConstants.ALL_ZONES_CUSTOM_NPC = 0
RSConstants.ALL_ZONES = "all"
RSConstants.UNKNOWN_ZONE_ID = 0
RSConstants.TANAAN_JUNGLE_MAPID = 534
RSConstants.MECHAGON_MAPID = 1462
RSConstants.VALLEY_OF_ETERNAL_BLOSSOMS_MAPID = 1530
RSConstants.ULDUM_MAPID = 1527
RSConstants.THE_MAW_MAPID = 1543
RSConstants.ZERETH_MORTIS_MAPID = 1970
RSConstants.IGNORE_MAPS = { 1978, 2537 }
RSConstants.THE_AZURE_SPAN = 2024
RSConstants.VALDRAKKEN = 2025
RSConstants.THE_PRIMALIST_FUTURE = 2085
RSConstants.ZARALEK_CAVERN = 2133
RSConstants.COSMIC = 946
RSConstants.AZEROTH = 947
RSConstants.KHAZ_ALGAR = 2274
RSConstants.RINGING_DEEPS = 2214
RSConstants.AZJ_KAHET1 = 2255
RSConstants.AZJ_KAHET2 = 2256
RSConstants.AZJ_KAHET3 = 2213
RSConstants.AZJ_KAHET4 = 2216
RSConstants.MAPS_WITHOUT_WARBAND_REPUTATION = { 2369, 2375 }
RSConstants.CONTINENTS_WARBAND_REPUTATION = { 2274 }
RSConstants.UNDERMINE = 2346
RSConstants.RINGING_DEEPS = 2214
RSConstants.EASTERN_KINGDOMS_MIDNIGHT_CONTINENT = 2537
RSConstants.HARANDAR = 2413
RSConstants.EVERSONG_WOODS = 2395
RSConstants.MAPS_TRACK_EVENT_HORNS = { 2133 }
RSConstants.IGNORE_HIGH_PEAK_ICON_MAPS = { 2509, 2636 }

---============================================================================
-- Entity IDs
---============================================================================

RSConstants.DUNDUN_DELVES = 266751
RSConstants.CATACOMBS_CACHE = 358040
RSConstants.DOOMROLLER_ID = 95056
RSConstants.DEATHTALON = 95053
RSConstants.TERRORFIST = 95044
RSConstants.VENGEANCE = 95054
RSConstants.WINGFLAYER_CRUEL = 167078
RSConstants.GIEGER = 162741
RSConstants.CHOSEN_RUNECOFFER = 355035
RSConstants.LARGE_LUNARLIGHT_POD = 356820
RSConstants.FORGEMASTER_MADALAV = 159496
RSConstants.HARIKA_HORRID = 165290
RSConstants.VALFIR_UNRELENTING = 168647
RSConstants.GREEDS_DESIRE = 356757
RSConstants.ORATOR_KLOE_NPCS = { 161527, 161528, 161529, 161530 }
RSConstants.CRAFTING_NPCS = { 157294, 157308, 157307, 157312, 157309, 157310, 157311 }
RSConstants.DAFFODIL_NPCS = { 171690, 167724 }
RSConstants.ABUSE_POWER_GI_NPCS = { 159156, 159157 }
RSConstants.ABUSE_POWER_I_NPCS = { 159151, 156919, 156916, 156918 }
RSConstants.ABUSE_POWER_HI_NPCS = { 159153, 159152, 159155, 159154 }
RSConstants.RUNE_CONSTRUCTS_CONTAINERS = { 355036, 355037, 355038, 364531 }
RSConstants.GRAPPLING_GROWTH_CONTAINERS = { 352596, 354852, 354853 }
RSConstants.GREEDSTONE_CONTAINERS = { 354211, 354206 }
RSConstants.LUNARLIGHT_CONTAINERS = { 353771, 353770, 353772, 353773, 353769 }
RSConstants.CITADEL_LOYALTY_NPCS = { 156339, 156340 }
RSConstants.SWELLING_TEAR_NPCS = { 171040, 171013, 171041 }
RSConstants.VESPER_REPAIR_NPCS = { 160882, 160985 }
RSConstants.THEATER_PAIN_NPCS = { 168147, 168148 }
RSConstants.DAPPERDEW_NPCS = { 168135, 164415, 166135, 166138, 166139, 166140, 166142, 166145, 166146 }
RSConstants.ASCENDED_COUNCIL_NPCS = { 170832, 170833, 170834, 170835, 170836 }
RSConstants.FOUR_PEOPLE_NPCS = { 170301, 169827, 170301, 170302 }
RSConstants.BOUNDING_SHRROM_CONTAINERS = { 349793, 349797, 353330 }
RSConstants.RIPE_PURIAN_CONTAINERS = { 353643, 353503, 353205, 353500, 352754, 353516, 353325, 353019, 353252, 353314, 352998 }
RSConstants.RIFT_HIDDEN_ENTITIES = { 179883, 368645, 368646, 368647, 368648, 368649, 368650 }
RSConstants.RIFT_NPCS = { 179608, 179911, 179913, 179914, 369437, 369438, 369439, 369440 }
RSConstants.RIFT_NPCS_MAW = { 179735, 179853, 179851 }
RSConstants.RELIC_CACHE = { 369292, 369294, 369310 }
RSConstants.PILE_BONES = { 369297, 369295 }
RSConstants.SHARDHIDE_STASH = { 369296 }
RSConstants.CACHES_SWAGSNOUT_GROMIT = { 369292, 369294, 369310, 369297, 369295, 369296 }
RSConstants.STOLEN_ANIMA_VESSEL = { 368946, 368947, 368948, 368949, 368950, 368951, 368952, 368953 }
RSConstants.STOLEN_ANIMA_VESSEL_RIFT = { 369227, 369235, 369236 }
RSConstants.DISTURBED_DIRT = { 382029, 376386, 383733, 383734, 383735 }
RSConstants.OMINOUS_CONCHS_NPCS = { 193735, 193634, 193710, 197371, 193708, 193706 } --197411
RSConstants.CONTAINERS_WITHOUT_VIGNETTE = { 376582, 376583, 376585, 376579, 376584, 378010, 376580 }
RSConstants.MAGIC_BOUND_CHEST = { 376426, 385075, 385074 }
RSConstants.CONTAINER_WITH_NPC_VIGNETTE = { 192243, 222381, 222369, 253957 }
RSConstants.CONTAINERS_FORBIDDEN_REACH = { 386214, 386165, 386166, 386167, 386168, 386172, 386174, 386179, 386208, 386212, 386213 }
RSConstants.FORBIDDEN_REACH_ANCESTRAL_SPIRIT = 203388
RSConstants.GOBLIN_PORTAL = 205722
RSConstants.ZARALEK_CAVERN_LOAM_SCOUT = 204657
RSConstants.ELUSIVE_NPCS = { 204821, 204831, 202436, 202441, 194489, 194491, 195465, 195472, 195492, 195509, 195518, 195541 }
RSConstants.CONTAINERS_UNWAKING_ECHO = { 411447, 411463, 411465, 411466 }
RSConstants.RUMBLE_FOIL_BAG = { 386158, 386140, 386157, 387718, 387720, 387721, 405585, 392031, 405586, 392032, 405587, 387722, 405584, 387719 }
RSConstants.RUMBLE_COIN_BAG = { 387696, 387697, 385961, 386138, 386139, 387695, 385958 }
RSConstants.IGNORE_NPCS_REPUTATION = { 216046, 207802, 220285, 205490 }
RSConstants.WORLDBOSSES = { 221585, 224157, 212088, 167749, 227257, 226646, 121912, 121820, 121818, 121911, 121821, 121913 }
RSConstants.STORMS_BREWIN_NPCS = { 228547, 231353, 231356, 231357 }
RSConstants.FLAMES_RADIANCE_INCURSION_NPCS = { 241227, 241229, 241231, 241234, 241236, 241238, 241228, 241230, 241232, 241235, 241237, 241239 }
RSConstants.CONTAINERS_INFESTED_CACHE = { 339247, 339248, 339249, 339250, 339251 }
RSConstants.CONTAINERS_JANIS_STASH = { 281176, 281365, 281381, 281388, 281390, 282664, 282647, 282668 }
RSConstants.CONTAINERS_BLACK_EMPIRE_CACHE = { 335707, 335709, 335711, 335712, 335717, 334189, 334213, 334215, 334216, 334220, 334223 }
RSConstants.CONTAINERS_DARKSHORE_CACHE = { 320514, 320515, 320516, 320517, 320518, 319024, 319211, 319212, 319226 }
RSConstants.CONTAINERS_INVASIVE_MAWSHROOM = { 369327, 369329, 369330, 369331, 369332 }
RSConstants.CONTAINERS_LUNARLIGHT_POD = { 353681, 353683, 353684, 353685, 353686 }
RSConstants.CONTAINERS_AMATHET_CACHE = { 324413, 325973, 325974, 325981, 325984 }
RSConstants.CONTAINERS_VOID_SEEPED_CACHE = { 273443, 277637 }
RSConstants.CONTAINERS_LEGION_WAR_SUPPLIES = { 273519, 273521, 273523, 273524, 273527, 273528, 273533, 273535, 273538 }
RSConstants.CONTAINERS_STOLEN_ANIMA_VESSEL = { 369227, 369235, 369236 }
RSConstants.CONTAINERS_CURIOUS_GRAIN_SACK = { 303039, 303170 }
RSConstants.CONTAINERS_PUGILISTS_PRIZE = { 354115, 354116, 354121, 354122, 354123 }
RSConstants.CONTAINERS_SKYWARD_BELL = { 353690, 353691, 353867 }
RSConstants.CONTAINERS_BROKEN_BELL = { 353687, 353688, 353689 }
RSConstants.CONTAINERS_ENCHANTED_CHEST = { 297881, 353233 }
RSConstants.CONTAINERS_TEST_OF_PENITENCE = { 353875, 356819 }
RSConstants.CONTAINERS_DECAYED_HUSK = { 353306, 353323, 353324, 353326, 353327 }
RSConstants.CONTAINERS_SECRET_TREASURE = { 351487, 351540, 351541, 351542, 351543, 351544, 351545, 353336 }
RSConstants.CONTAINERS_MECHANIZED_CHEST = { 325659, 325660, 325661, 325662, 325663, 325664, 325665, 325666, 325667, 325668 }
RSConstants.CONTAINERS_TREASURE_CHEST = { 278456, 278459, 278460, 278461, 278462, 278694, 278713, 278716, 278793, 278795, 281903, 281904, 281905, 281906, 288604, 279325, 279352, 279366, 279367, 279373, 279378, 279379, 282721, 282722, 282723, 284408, 284409, 284410, 284411, 284412, 284413, 284414, 284415, 284416, 284417, 284418, 284419, 284420, 284421, 290770, 277336, 253957 }
RSConstants.CONTAINERS_ARCANE_CHEST = { 326394, 326401, 326402, 326403, 326404, 326405, 326406, 326407, 326408, 326409, 326410, 326411, 326412, 326413, 326414, 326415, 326416, 326417, 326418, 326419 }
RSConstants.CONTAINERS_EREDAR_WAR_SUPPLIES = { 271849, 272455, 272456, 272770, 272771, 273222, 271850 }
RSConstants.CONTAINERS_SHIMMERING_ANCIENT_MANA_CLUSTER = { 252446, 252447, 252448, 252449, 252450, 252432 }
RSConstants.CONTAINERS_SPROUTING_GROWTH = { 352596, 354852, 354853 }
RSConstants.CONTAINERS_BURIED_TREASURE_CHEST = { 293852, 293880, 293881, 293884 }
RSConstants.CONTAINERS_LOOSE_PARTS = { 311902, 311903 }
RSConstants.CONTAINERS_SMALL_TREASURE_CHEST = { 273900, 273902, 273903, 273905, 273910, 273917, 273918, 273919, 273955, 273956, 275070, 275071, 275074, 275076, 280751, 284469, 291201, 291204, 291211, 291213, 291217, 291222, 291223, 291224, 291225, 291226, 291227, 291228, 291229, 291230, 287531, 291244, 291246, 291254, 291255, 291257, 291258, 291259, 291263, 291264, 291265, 291266, 291267, 294311, 273901 }
RSConstants.CONTAINERS_FULL_GARRISON_CACHE = { 237722, 237724 }
RSConstants.CONTAINERS_MOGU_PLUNDER = { 334227, 334228, 334229, 334232, 334237, 334238 }
RSConstants.CONTAINERS_AMBERED_CACHE = { 339464, 339465, 339466, 339467, 339468 }
RSConstants.CONTAINERS_SILVER_STRONGBOX = { 352754, 352998, 353019, 353205, 353252, 353314, 353325, 353500, 353503, 353516, 353643 }
RSConstants.CONTAINERS_GARRISON_CACHE = { 236916, 237191 }
RSConstants.CONTAINERS_CURSED_TREASURE = { 272622, 287493 }
RSConstants.CONTAINERS_RUNEBOUND_COFFER = { 297893, 355036, 355037, 355038, 364531 }
RSConstants.CONTAINERS_HIDDEN_HOARD = { 353868, 353869, 353870, 353871, 353872, 353873 }
RSConstants.CONTAINERS_FAERIE_STASH = { 353329, 353330, 353331, 353332, 353333 }
RSConstants.CONTAINERS_A_DAMP_SCROLL = { 292673, 292674, 292675, 292676, 292677 }
RSConstants.CONTAINERS_DISTURBED_DIRT = { 376386, 382029, 383733, 383735, 383734 }
RSConstants.CONTAINERS_RIFTBOUND_CACHE = { 369437, 369438, 369439, 369440 }
RSConstants.CONTAINERS_GLOWING_ARCANE_TRUNK = { 326395, 326396, 326397, 326398, 326399, 326400, 329783, 332220 }
RSConstants.CONTAINERS_ELIXIR_OF_SHADOW_SIGHT = { 234703, 234704, 234705, 234734, 234735, 234736 }
RSConstants.CONTAINERS_RIFT_HIDDEN_CACHE = { 368645, 368646, 368647, 368648, 368649, 368650 }
RSConstants.CONTAINERS_DIM_LUNARLIGHT_POD = { 353769, 353770, 353771, 353772, 353773 }
RSConstants.CONTAINERS_MAGIC_BOUND_CHEST = { 376426, 385074, 385075 }
RSConstants.CONTAINERS_ANCIENT_EREDAR_CACHE = { 273301, 273407, 273412, 273414, 273415, 273439 }
RSConstants.CONTAINERS_NEST_OF_UNUSUAL_MATERIALS = { 369333, 369334, 369335, 369336, 369337 }
RSConstants.CONTAINERS_WAR_SUPPLY_CHEST = { 290135, 324043 }
RSConstants.CONTAINERS_MAWSWORN_CACHE = { 368205, 368206, 368207, 368208, 368213, 368214, 369141, 368876, 369339, 369341, 375272 }
RSConstants.CONTAINERS_HARMONIC_CHEST = { 355358, 380556 }
RSConstants.CONTAINERS_STONEBORN_SATCHEL = { 354108, 354109, 354110, 354111, 354112, 354113, 354114, 354186, 354187, 354188, 354189, 354190, 354191, 354192, 354193 }
RSConstants.CONTAINERS_DREAMSEED_CACHE = { 406117, 406138, 406121, 406106, 409220, 406129, 406354, 406119, 405303, 409224, 409227, 405930, 406134, 406116, 409848, 405487, 406142, 406956, 406130, 409225, 409844, 406977, 406124, 406143, 407006, 406123, 406148, 409223, 409221, 405932, 405321, 409226, 405929, 406107, 405931, 406356, 405320, 407001, 406128, 406954, 406120, 406118, 409847, 405488, 406135, 406147, 409228, 406955, 406355, 406139, 406998 }
RSConstants.CONTAINERS_DESPAWN = { 444899, 446473, 446476, 444773, 446299, 446140, 419695, 213749, 64004, 64191, 213962, 213968, 65552, 213969, 213972, 213966, 213964, 213960, 213842 }
RSConstants.CONTAINERS_POTION_POLYMORPHIC_TRANSLATION = { 454335, 454338, 454336, 454328, 454344, 454350, 454320, 454332, 456927, 454343, 454348, 454313, 454316, 454330, 456928 }
RSConstants.CONTAINERS_SPARKBUG = { 435008, 441723, 428472, 457271 }
RSConstants.CONTAINERS_SEAFARER_CACHE = { 500682, 500683, 500685, 500688, 494499, 500689, 500686, 500690, 500684 }
RSConstants.CONTAINERS_SLIMY_COCOON = { 324414, 324415, 324416, 324417 }
RSConstants.CONTAINERS_MUFF_AUTO_LOCKER = { 467468, 474393, 474396, 474397, 474398 }
RSConstants.NINE_TENTHS_LAW_CHAPTER_4 = { 502893, 502908, 502903 }
RSConstants.EVENTS_SCRAP_HEAP = { 234350, 234349, 234348, 234347, 234346, 234345, 234344 }
RSConstants.MISLAID_CURIOSITY = 478443
RSConstants.FIX_MULTIPLE_ALERTS = { 205490 }
RSConstants.PHASE_DIVING = { 231981, 232127, 232128, 232193, 232189, 232111, 232077, 232182, 232006, 232195, 232199, 558108, 558110, 232129, 232108, 527414, 558117, 558375, 558112, 549326 }
RSConstants.RESHII_WRAPS_CONTAINERS = { 516626, 548010, 529525, 529643, 529591, 529537, 529669, 547995, 529664, 548001, 529533, 548597, 529539 }
RSConstants.CONTAINERS_LIGHTS_JUDGMENT = { 276225, 276224, 276491, 276489, 277206, 277205 }
RSConstants.CONTAINERS_GOBLIN_GLIDER_KIT = { 276227, 276230, 276229 }
RSConstants.CONTAINERS_SHROUD_ARCANE_ECHOES = { 277327, 277340, 277342, 277344, 277343, 277346 }
RSConstants.CONTAINERS_LIGHTFORGED_WARFRAME = { 276226, 276223, 276490, 277204 }
RSConstants.ENTITIES_ATAL_AMAN = { 525959, 525908, 525896, 525918, 525940, 525953, 525964 }
RSConstants.STORMARION_ASSAULT_NPCS = { 248700, 248791, 248068, 248459 }
RSConstants.CONTAINERS_ECHOLESS_FLAME = { 579123, 579130, 579131 }
RSConstants.CONTAINERS_RUSSULAS_OUTREACH = { 579242, 579243, 579244 }
RSConstants.CONTAINERS_PVP = { 244215, 290129 }
RSConstants.CONTAINERS_ALN_HARAS_BLOOM = { 579239, 579240, 579241 }
RSConstants.CONTAINERS_CAULDRON_ECHOES = { 579236, 579237, 579238 }
RSConstants.CONTAINERS_ROOT_WORLD = { 579180, 579182, 579183 }
RSConstants.CONTAINERS_WEYNAN_WARD = { 579233, 579234, 579235 }
RSConstants.CONTAINERS_SKY_HOPE = { 579201, 579202, 579203 }
RSConstants.MOTHS_RENOWN_1 = {571099,571121,571122,571123,571124,571125,571126,571127,571128,571129,571130,571131,571132,571133,571134,571135,571136,571137,571138,571139,571140,571141,571142,571143,571144,571145,571146,571147,571148,571149,571150,571151,571152,571153,571154,571155,571156,571157,571158,571159};
RSConstants.MOTHS_RENOWN_4 = {571162,571163,571164,571165,571166,571167,571168,571169,571170,571171,571172,571173,571174,571175,571176,571177,571178,571179,571180,571181,571264,571265,571266,571267,571268,571269,571270,571271,571272,571273,571274,571275,571276,571277,571278,571279,571280,571281,571282,571283};
RSConstants.MOTHS_RENOWN_9 = {571289,571290,571291,571292,571293,571294,571295,571296,571297,571298,571299,571300,571301,571302,571303,571304,571305,571306,571307,571308,571310,571311,571312,571313,571314,571315,571316,571317,571318,571319,571320,571321,571322,571323,571324,571325,571326,571327,571328,571329};
RSConstants.CONTAINERS_STURDY_CHEST = { 617855, 618111, 618112, 618276, 618288, 618289, 618272, 618278, 618292, 618273, 618281, 618295, 618277, 618279, 618291, 618283, 618284, 618296, 618293, 618270, 618290, 617852, 618113, 618275, 618287, 618274, 618285, 618286, 618280, 618294, 655978, 655980, 655981, 655982, 655979, 655983 };
RSConstants.CONTAINERS_FUNERARY_INSCRIPTION = { 668589, 668590, 668591, 668593, 668594, 668596, 668597, 668598, 668599, 668600, 668601, 668602 };
RSConstants.RARES_RITUAL_SITES_4 = {260203,260204,263897,263490}
RSConstants.RARES_RITUAL_SITES_8 = {259971,260209,263463,263361}
RSConstants.CONTAINERS_COILED_ISLE_CHAPTER2 = {644791,642021,642322,644681}
RSConstants.RARES_TEMPLE_INCURSION = {260898,260900,260897,260903}
RSConstants.ANCIENT_TREASURES = {676585,659517,676624,676625,676628,676629,676661,676663,676653,676657,676760,676759,676648,676649,676645,676643,676640,676639}

-- NPCs that spawn after completing an event
RSConstants.NPCS_WITH_PRE_EVENT = {
	-- EVENTID = NPCID
	-- Vol'dun
	[136390] = 136393;
	-- Zuldazar
	[281130] = 134782;
	-- Drustvar
	[277389] = 129904;
	[127652] = 127651;
	[137180] = 137183;
	-- Mechagon
	[154342] = 151934;
	[152932] = 153000;
	-- Korthia
	[179759] = 179760;
	[180145] = 179859;
	[369247] = 179859;
	[180144] = 179802;
	[369130] = 179802;
	[179464] = 179472;
	[369444] = 180162;
	[180064] = 180042;
	[179969] = 179985;
	[180028] = 180032;
	[180009] = 180014;
	[180013] = 180014;
	-- Zereth Mortis
	[183505] = 183516;
	[183781] = 183764;
	[182156] = 182155;
	[185612] = 181249;
	[182120] = 182114;
	[182161] = 182158;
	[185836] = 180924;
	-- Bastion
	[176543] = 171008;
	[171012] = 171040;
	[356756] = 167078;
	[356677] = 156340;
	[6896] = 167078;
	[6894] = 156339;
	[170548] = 170439;
	-- Revendredth
	[165230] = 165206;
	[166483] = 166521;
	[176347] = 160675;
	[165152] = 165175;
	[169253] = 155779;
	[6912] = 165290;
	[6913] = 159496;
	-- Ardenweald
	[164102] = 164093;
	[167874] = 167851;
	[168053] = 167721;
	[6910] = 168647;
	-- Maldraxxus
	[6901] = 162741;
	-- Talador
	[84037] = 88494;
	[77764] = 77750;
	-- Tanaan Jungle
	[90524] = 90519;
	[243386] = 91227;
	-- Shadowlands (Draenor)
	[82426] = 75434;
	-- Spires of Arak
	[82084] = 82050;
	[84918] = 84912;
	[84821] = 84833;
	[85758] = 85037;
	-- Nagrand (Draenor)
	[84275] = 84263;
	-- Frostfire Ridge
	[75235] = 72156;
	[74970] = 74971;
	-- Timeless Isle
	[71944] = 71919;
	[55421] = 72048;
	[220815] = 71864;
	-- The Maw
	[170315] = 170302;
	[169828] = 169827;
	[170305] = 170301;
	-- The Azure Span
	[379234] = 194270;
	-- Ohn'ahran Plains
	[193166] = 187559;
	-- The Azure Span
	[192747] = 192749;
	[190971] = 189822;
	-- The Forbidden Reach
	[386342] = 200619;
	[386343] = 200620;
	[386344] = 200621;
	[386345] = 200622;
	[386360] = 200722;
	[386358] = 200725;
	[386350] = 200730;
	[386348] = 200737;
	[386347] = 200738;
	[386351] = 200739;
	[386346] = 200740;
	[386340] = 200742;
	[386338] = 200743;
	[205722] = 205490;
	--Emerald Dream
	[209264] = 209113;
	[210300] = 209936;
	[210516] = 209893;
	[210132] = 209929;
	[214131] = 209929;
	[209980] = 209913;
	[210155] = 209898;
	[210083] = 209912;
	[210063] = 209915;
	--Noblegarden
	[218619] = 213665;
	[219928] = 213665;
	[219936] = 213665;
	-- Azsuna
	[243009] = 89816;
	[90775] = 89816;
	[91113] = 91115;
	[91114] = 91115;
	[91097] = 91100;
	[90232] = 90244;
	[105913] = 105938;
	[91580] = 91579;
	[90804] = 90803;
	[90507] = 90505;
	--Val'Sharah
	[93677] = 93686;
	[92334] = 93654;
	[92111] = 92117;
	[109713] = 109708;
	[109602] = 95221;
	[94194] = 92423;
	[243099] = 94414;
	[112472] = 93679;
	--Suramar
	[103859] = 103827;
	--Stormheim
	[241528] = 92685;
	[241568] = 92763;
	[92343] = 91780;
	--Highmountain
	[97584] = 97593;
	[97215] = 97220;
	[244667] = 97793;
	[98754] = 98311;
	[97543] = 100495;
	--Hallowfall
	[225404] = 207802;
	--Valley of the Four Winds
	[334785] = 157468;
	--Uldum
	[158754] = 157593;
	-- Undermine
	[234819] = 234480;
	[234911] = 233471;
	[234889] = 233472;
	[234751] = 234499;
	[231336] = 231310;
	--Tazavesh
	[517436] = 238540;
	--K'aresh
	[234967] = 234970;
	[246163] = 245998;
	[235085] = 235087;
	[235102] = 235104;
	[516597] = 238135;
	[231232] = 231229;
	[517336] = 238536;
	[527973] = 241956;
	[241987] = 241956;
	[516961] = 238384;
	[527868] = 241920;
	--Eversong Woods
	[250788] = 250780;
	--Zul'Aman
	[246122] = 245691;
	[246074] = 242034;
	[249712] = 242034;
	--Voidstorm
	[617692] = 256926;
	[248907] = 248823;
	[248825] = 248823;
	--Twilight Highlands
	[253605] = 253378;
	--The Coiled Isle
	[258250] = 258254;
}

-- Contains that spawn after completing an event
RSConstants.CONTAINERS_WITH_PRE_EVENT = {
	-- EVENTID = CONTAINERID
	-- PVP crate
	[135238] = 433369;
	[135181] = 433369;
	[290129] = 433369;
	[244215] = 433369;
	-- Vol'dun
	[132662] = 280951;
	-- Tiragarde Sound
	[131453] = 279750;
	-- Stormsong Valley
	[154944] = 328883;
	[155069] = 328883;
	-- Ardenweald
	[171475] = 354662;
	[356821] = 356820;
	-- Bastion
	[163460] = 344588;
	[6899] = 356819;
	-- Zereth Mortis
	[185265] = 375403;
	[185502] = 375403;
	[185285] = 375413;
	[180507] = 369757;
	[185416] = 375493;
	-- Talador
	[77664] = 227793;
	-- Shadowlands (Draenor)
	[79805] = 230664;
	-- Frostfire Ridge
	[229366] = 229367;
	-- Dragonflight
	[191861] = 385074;
	[203225] = 396339;
	[191905] = 385075;
	[192012] = 377540;
	[192243] = 377587;
	--Emerald Dream
	[212009] = 411065;
	[210732] = 409222;
	[212012] = 411067;
	[210538] = 408719;
	[212011] = 411066;
	[210060] = 407739;
	--Hallowfall
	[453359] = 453374;
	--Isle of Dorn
	[223104] = 223143;
	[222847] = 444215;
	[222956] = 222963;
	[222963] = 222965;
	[222965] = 443638;
	[212928] = 223338;
	[223338] = 212945;
	[212945] = 444354;
	[223227] = 223247;
	[223247] = 444137;
	[222941] = 443318;
	[222894] = 444233;
	[223143] = 444022;
	[446100] = 446151;
	[453283] = 453274;
	[225948] = 453167;
	--Revendreth
	[166680] = 349796;
	[173786] = 358298;
	[173607] = 173603;
	[173634] = 357565;
	[173704] = 357683;
	[6908] = 356820;
	[356758] = 356757;
	[6915] = 356757;
	--Maldraxxus
	[165037] = 348521;
	[6900] = 355035;
	--Korthia
	[164542] = 369200;
	[179772] = 369200;
	--Torghast
	[164674] = 291046;
	--The Waking Shores
	[194874] = 380598;
	--Azsuna
	[101532] = 240638;
	--Highmountain
	[97653] = 244628;
	[251125] = 251124;
	--Val'Sharah
	[241127] = 241128;
	[93758] = 242350;
	--Suramar
	[113368] = 255341;
	-- Undermine
	[233720] = 499090;
	[233775] = 499207;
	[493307] = 493305;
	[234564] = 478443;
	--Tazavesh
	[503837] = 503823;
	--K'aresh
	[499334] = 500046;
	--Voidstorm
	[254756] = 612891;
	[254811] = 612891;
	[257141] = 618016;
	--Zul'Aman
	[613727] = 539046;
	[261867] = 642205;
}

-- NPCs that spawn after killing another NPC
RSConstants.NPCS_WITH_PRE_NPCS = {
	[165175] = 165152;
	[165206] = 165230;
	[166521] = 166483;
	[160675] = 176347;
}

-- 156480 Next door entity inside Torghast
-- 155660 Summons from the Depths
RSConstants.IGNORED_VIGNETTES_NPCS = { 156480, 155660, 163373, 182160, 182668, 182667, 185261, 200002, 190034, 191125, 210081, 210084, 210544, 210550, 226647, 226657, 226528, 221630, 206978, 206980, 206981, 209780, 209781, 127025, 136466, 136472, 136144, 136109, 128660, 128661, 128662, 128665, 98141, 92600, 227481, 147188, 171743, 219827, 90173, 92682, 92703, 247220, 256569, 155796, 157718, 193681, 9046, 158037, 265828, 269526, 269595, 269599, 269600, 258262, 673863, 653064, 261514, 261586, 263576 }
RSConstants.IGNORED_VIGNETTES_CONTAINERS = { 370467, 370466, 376210, 250642, 239887, 253216, 253224, 253228, 267925, 267927, 500687 }
RSConstants.IGNORED_FRIENDLY_NPCS = { 227984 }
RSConstants.NPCS_WITH_EVENT_VIGNETTE = { 72156, 154154, 154330, 164547, 164477, 160629, 175012, 157833, 166398, 164064, 162829, 157964, 162844, 171317, 170774, 162849, 170301, 170302, 170711, 170634, 170731, 172862, 172577, 158025, 158278, 170303, 179684, 179791, 179805, 177444, 180246, 179108, 179853, 179755, 179768, 179779, 179460, 179851, 179735, 169827, 203280, 213665, 129904, 90217, 91579, 91892, 96072, 97653, 95872, 98299, 150191, 153898, 149653, 150468, 154148, 153928, 90244  }
RSConstants.NPCS_WITH_CONTAINER_VIGNETTE = { 179883, 249997, 250534 }
RSConstants.CONTAINERS_WITH_NPC_VIGNETTE = { 369435, 398828, 652482 }
RSConstants.CONTAINERS_WITH_EVENT_VIGNETTE = { 453374, 251124 }
RSConstants.EVENTS_WITH_NPC_VIGNETTE = { 204131, 204211, 204747, 204768, 203278, 203950, 204101, 203065, 203702, 203889, 205006, 204710, 204967, 204732, 204389, 204423, 204460, 204763, 214985, 222165, 234350, 234349, 234348, 234347, 234346, 234345, 234344, 177525, 176103 }
RSConstants.NPCS_WITH_MULTIPLE_SPAWNS = { 69768, 69769, 69841, 69842, 70323, 205490, 248660, 248688, 250534 }
RSConstants.FIRIM_EXILE_OBJECTS = { 375973, 375982, 375983, 375984, 375985, 375986, 375987 }
RSConstants.IGNORED_TRACKING_SYSTEMS_NOT_VIGNETTE = { 205490 }

---============================================================================
-- Custom NPCs
---============================================================================

RSConstants.DEFAULT_GROUP = 0

---============================================================================
-- ItemIDs
---============================================================================

RSConstants.ITEMS_REQUIRE_NECROLORD = { 181815, 182080, 186489 }
RSConstants.ITEMS_REQUIRE_NIGHT_FAE = { 180730, 186492 }
RSConstants.ITEMS_REQUIRE_VENTHYR = { 180581, 180461, 186479 }
RSConstants.ITEMS_REQUIRE_KYRIAN = { 186483 }

---============================================================================
-- Achievements
---============================================================================

RSConstants.TALES_OF_EXILE_ACHIEVEMENT_ID = 15509

---============================================================================
-- Garrison cache
---============================================================================

RSConstants.GARRISON_CACHE_IDS = { 236916, 237191, 237724, 237722, 237723, 237720 }

---============================================================================
-- TSM
---============================================================================

RSConstants.TSM_SOURCES = { "DBMinBuyout", "DBMarket", "DBRegionMarketAvg" }

---============================================================================
-- Eternal states
---============================================================================

RSConstants.ETERNAL_DEATH = -1
RSConstants.ETERNAL_OPENED = -1
RSConstants.ETERNAL_COMPLETED = -1
RSConstants.ETERNAL_COLLECTED = -1

---============================================================================
-- Textures
---============================================================================

RSConstants.TEXTURE_PATH = "Interface\\AddOns\\RareScanner\\Media\\Icons\\%s.blp"
RSConstants.GROUP_TOP_TEXTURE_FILE = "GroupT"
RSConstants.GROUP_RIGHT_TEXTURE_FILE = "GroupR"
RSConstants.GROUP_LEFT_TEXTURE_FILE = "GroupL"
RSConstants.NORMAL_NPC_TEXTURE_FILE = "OriginalSkull"
RSConstants.RED_NPC_TEXTURE_FILE = "RedSkullDark"
RSConstants.PINK_NPC_TEXTURE_FILE = "PinkSkullDark"
RSConstants.BLUE_NPC_TEXTURE_FILE = "BlueSkullDark"
RSConstants.PURPLE_NPC_TEXTURE_FILE = "CustomSkull"
RSConstants.LIGHT_BLUE_NPC_TEXTURE_FILE = "BlueSkullLight"
RSConstants.NORMAL_CONTAINER_TEXTURE_FILE = "OriginalChest"
RSConstants.RED_CONTAINER_TEXTURE_FILE = "RedChest"
RSConstants.PINK_CONTAINER_TEXTURE_FILE = "PinkChest"
RSConstants.BLUE_CONTAINER_TEXTURE_FILE = "BlueChest"
RSConstants.LIGHT_GREEN_CONTAINER_TEXTURE_FILE = "LightGreenChest"
RSConstants.NORMAL_EVENT_TEXTURE_FILE = "OriginalStar"
RSConstants.RED_EVENT_TEXTURE_FILE = "RedStar"
RSConstants.PINK_EVENT_TEXTURE_FILE = "PinkStar"
RSConstants.BLUE_EVENT_TEXTURE_FILE = "BlueStar"
RSConstants.OVERLAY_SPOT_TEXTURE_FILE = "Overlay"
RSConstants.GUIDE_TRANSPORT_FILE = "Transport"
RSConstants.GUIDE_ENTRANCE_FILE = "Entrance"
RSConstants.GUIDE_FLAG_FILE = "Flag"
RSConstants.GUIDE_DOT_FILE = "Dot"
RSConstants.GUIDE_STEP1_FILE = "Number1"
RSConstants.GUIDE_STEP2_FILE = "Number2"
RSConstants.GUIDE_STEP3_FILE = "Number3"
RSConstants.GUIDE_STEP4_FILE = "Number4"
RSConstants.GUIDE_STEP5_FILE = "Number5"
RSConstants.GUIDE_STEP6_FILE = "Number6"
RSConstants.GUIDE_STEP7_FILE = "Number7"
RSConstants.GUIDE_STEP8_FILE = "Number8"
RSConstants.GUIDE_STEP9_FILE = "Number9"
RSConstants.DRAGON_GLYFH_FILE = "DragonGlyphSmall"
RSConstants.PROFFESION_ICON_ATLAS = "Professions-Crafting-Orders-Icon"
RSConstants.ACHIEVEMENT_ICON_ATLAS = "UI-Achievement-Shield-2"
RSConstants.PRIMAL_STORM_ICON_ATLAS = "ElementalStorm-Lesser-Water"
RSConstants.NOT_TRACKABLE_ICON_ATLAS = "Islands-MarkedArea"

RSConstants.NORMAL_NPC_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.NORMAL_NPC_TEXTURE_FILE);
RSConstants.GROUP_NORMAL_NPC_T_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.NORMAL_NPC_TEXTURE_FILE, RSConstants.GROUP_TOP_TEXTURE_FILE));
RSConstants.GROUP_NORMAL_NPC_L_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.NORMAL_NPC_TEXTURE_FILE, RSConstants.GROUP_LEFT_TEXTURE_FILE));
RSConstants.GROUP_NORMAL_NPC_R_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.NORMAL_NPC_TEXTURE_FILE, RSConstants.GROUP_RIGHT_TEXTURE_FILE));
RSConstants.RED_NPC_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.RED_NPC_TEXTURE_FILE);
RSConstants.GROUP_RED_NPC_T_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.RED_NPC_TEXTURE_FILE, RSConstants.GROUP_TOP_TEXTURE_FILE));
RSConstants.GROUP_RED_NPC_L_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.RED_NPC_TEXTURE_FILE, RSConstants.GROUP_LEFT_TEXTURE_FILE));
RSConstants.GROUP_RED_NPC_R_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.RED_NPC_TEXTURE_FILE, RSConstants.GROUP_RIGHT_TEXTURE_FILE));
RSConstants.PINK_NPC_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.PINK_NPC_TEXTURE_FILE);
RSConstants.GROUP_PINK_NPC_T_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.PINK_NPC_TEXTURE_FILE, RSConstants.GROUP_TOP_TEXTURE_FILE));
RSConstants.GROUP_PINK_NPC_L_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.PINK_NPC_TEXTURE_FILE, RSConstants.GROUP_LEFT_TEXTURE_FILE));
RSConstants.GROUP_PINK_NPC_R_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.PINK_NPC_TEXTURE_FILE, RSConstants.GROUP_RIGHT_TEXTURE_FILE));
RSConstants.BLUE_NPC_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.BLUE_NPC_TEXTURE_FILE);
RSConstants.GROUP_BLUE_NPC_T_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.BLUE_NPC_TEXTURE_FILE, RSConstants.GROUP_TOP_TEXTURE_FILE));
RSConstants.GROUP_BLUE_NPC_L_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.BLUE_NPC_TEXTURE_FILE, RSConstants.GROUP_LEFT_TEXTURE_FILE));
RSConstants.GROUP_BLUE_NPC_R_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.BLUE_NPC_TEXTURE_FILE, RSConstants.GROUP_RIGHT_TEXTURE_FILE));
RSConstants.LIGHT_BLUE_NPC_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.LIGHT_BLUE_NPC_TEXTURE_FILE);
RSConstants.GROUP_LIGHT_BLUE_NPC_T_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.LIGHT_BLUE_NPC_TEXTURE_FILE, RSConstants.GROUP_TOP_TEXTURE_FILE));
RSConstants.GROUP_LIGHT_BLUE_NPC_L_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.LIGHT_BLUE_NPC_TEXTURE_FILE, RSConstants.GROUP_LEFT_TEXTURE_FILE));
RSConstants.GROUP_LIGHT_BLUE_NPC_R_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.LIGHT_BLUE_NPC_TEXTURE_FILE, RSConstants.GROUP_RIGHT_TEXTURE_FILE));
RSConstants.PURPLE_NPC_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.PURPLE_NPC_TEXTURE_FILE);
RSConstants.GROUP_PURPLE_NPC_T_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.PURPLE_NPC_TEXTURE_FILE, RSConstants.GROUP_TOP_TEXTURE_FILE));
RSConstants.GROUP_PURPLE_NPC_L_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.PURPLE_NPC_TEXTURE_FILE, RSConstants.GROUP_LEFT_TEXTURE_FILE));
RSConstants.GROUP_PURPLE_NPC_R_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.PURPLE_NPC_TEXTURE_FILE, RSConstants.GROUP_RIGHT_TEXTURE_FILE));
RSConstants.NORMAL_CONTAINER_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.NORMAL_CONTAINER_TEXTURE_FILE);
RSConstants.GROUP_NORMAL_CONTAINER_T_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.NORMAL_CONTAINER_TEXTURE_FILE, RSConstants.GROUP_TOP_TEXTURE_FILE));
RSConstants.GROUP_NORMAL_CONTAINER_L_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.NORMAL_CONTAINER_TEXTURE_FILE, RSConstants.GROUP_LEFT_TEXTURE_FILE));
RSConstants.GROUP_NORMAL_CONTAINER_R_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.NORMAL_CONTAINER_TEXTURE_FILE, RSConstants.GROUP_RIGHT_TEXTURE_FILE));
RSConstants.RED_CONTAINER_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.RED_CONTAINER_TEXTURE_FILE);
RSConstants.GROUP_RED_CONTAINER_T_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.RED_CONTAINER_TEXTURE_FILE, RSConstants.GROUP_TOP_TEXTURE_FILE));
RSConstants.GROUP_RED_CONTAINER_L_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.RED_CONTAINER_TEXTURE_FILE, RSConstants.GROUP_LEFT_TEXTURE_FILE));
RSConstants.GROUP_RED_CONTAINER_R_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.RED_CONTAINER_TEXTURE_FILE, RSConstants.GROUP_RIGHT_TEXTURE_FILE));
RSConstants.PINK_CONTAINER_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.PINK_CONTAINER_TEXTURE_FILE);
RSConstants.GROUP_PINK_CONTAINER_T_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.PINK_CONTAINER_TEXTURE_FILE, RSConstants.GROUP_TOP_TEXTURE_FILE));
RSConstants.GROUP_PINK_CONTAINER_L_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.PINK_CONTAINER_TEXTURE_FILE, RSConstants.GROUP_LEFT_TEXTURE_FILE));
RSConstants.GROUP_PINK_CONTAINER_R_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.PINK_CONTAINER_TEXTURE_FILE, RSConstants.GROUP_RIGHT_TEXTURE_FILE));
RSConstants.BLUE_CONTAINER_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.BLUE_CONTAINER_TEXTURE_FILE);
RSConstants.GROUP_BLUE_CONTAINER_T_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.BLUE_CONTAINER_TEXTURE_FILE, RSConstants.GROUP_TOP_TEXTURE_FILE));
RSConstants.GROUP_BLUE_CONTAINER_L_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.BLUE_CONTAINER_TEXTURE_FILE, RSConstants.GROUP_LEFT_TEXTURE_FILE));
RSConstants.GROUP_BLUE_CONTAINER_R_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.BLUE_CONTAINER_TEXTURE_FILE, RSConstants.GROUP_RIGHT_TEXTURE_FILE));
RSConstants.LIGHT_GREEN_CONTAINER_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.LIGHT_GREEN_CONTAINER_TEXTURE_FILE);
RSConstants.GROUP_LIGHT_GREEN_CONTAINER_T_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.LIGHT_GREEN_CONTAINER_TEXTURE_FILE, RSConstants.GROUP_TOP_TEXTURE_FILE));
RSConstants.GROUP_LIGHT_GREEN_CONTAINER_L_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.LIGHT_GREEN_CONTAINER_TEXTURE_FILE, RSConstants.GROUP_LEFT_TEXTURE_FILE));
RSConstants.GROUP_LIGHT_GREEN_CONTAINER_R_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.LIGHT_GREEN_CONTAINER_TEXTURE_FILE, RSConstants.GROUP_RIGHT_TEXTURE_FILE));
RSConstants.NORMAL_EVENT_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.NORMAL_EVENT_TEXTURE_FILE);
RSConstants.GROUP_NORMAL_EVENT_T_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.NORMAL_EVENT_TEXTURE_FILE, RSConstants.GROUP_TOP_TEXTURE_FILE));
RSConstants.GROUP_NORMAL_EVENT_L_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.NORMAL_EVENT_TEXTURE_FILE, RSConstants.GROUP_LEFT_TEXTURE_FILE));
RSConstants.GROUP_NORMAL_EVENT_R_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.NORMAL_EVENT_TEXTURE_FILE, RSConstants.GROUP_RIGHT_TEXTURE_FILE));
RSConstants.RED_EVENT_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.RED_EVENT_TEXTURE_FILE);
RSConstants.GROUP_RED_EVENT_T_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.RED_EVENT_TEXTURE_FILE, RSConstants.GROUP_TOP_TEXTURE_FILE));
RSConstants.GROUP_RED_EVENT_L_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.RED_EVENT_TEXTURE_FILE, RSConstants.GROUP_LEFT_TEXTURE_FILE));
RSConstants.GROUP_RED_EVENT_R_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.RED_EVENT_TEXTURE_FILE, RSConstants.GROUP_RIGHT_TEXTURE_FILE));
RSConstants.PINK_EVENT_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.PINK_EVENT_TEXTURE_FILE);
RSConstants.GROUP_PINK_EVENT_T_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.PINK_EVENT_TEXTURE_FILE, RSConstants.GROUP_TOP_TEXTURE_FILE));
RSConstants.GROUP_PINK_EVENT_L_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.PINK_EVENT_TEXTURE_FILE, RSConstants.GROUP_LEFT_TEXTURE_FILE));
RSConstants.GROUP_PINK_EVENT_R_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.PINK_EVENT_TEXTURE_FILE, RSConstants.GROUP_RIGHT_TEXTURE_FILE));
RSConstants.BLUE_EVENT_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.BLUE_EVENT_TEXTURE_FILE);
RSConstants.GROUP_BLUE_EVENT_T_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.BLUE_EVENT_TEXTURE_FILE, RSConstants.GROUP_TOP_TEXTURE_FILE));
RSConstants.GROUP_BLUE_EVENT_L_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.BLUE_EVENT_TEXTURE_FILE, RSConstants.GROUP_LEFT_TEXTURE_FILE));
RSConstants.GROUP_BLUE_EVENT_R_TEXTURE = string.format(RSConstants.TEXTURE_PATH, string.format("%s%s", RSConstants.BLUE_EVENT_TEXTURE_FILE, RSConstants.GROUP_RIGHT_TEXTURE_FILE));
RSConstants.OVERLAY_SPOT_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.OVERLAY_SPOT_TEXTURE_FILE);
RSConstants.GUIDE_TRANSPORT_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.GUIDE_TRANSPORT_FILE);
RSConstants.GUIDE_ENTRANCE_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.GUIDE_ENTRANCE_FILE);
RSConstants.GUIDE_FLAG_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.GUIDE_FLAG_FILE);
RSConstants.GUIDE_DOT_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.GUIDE_DOT_FILE);
RSConstants.GUIDE_STEP1_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.GUIDE_STEP1_FILE);
RSConstants.GUIDE_STEP2_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.GUIDE_STEP2_FILE);
RSConstants.GUIDE_STEP3_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.GUIDE_STEP3_FILE);
RSConstants.GUIDE_STEP4_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.GUIDE_STEP4_FILE);
RSConstants.GUIDE_STEP5_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.GUIDE_STEP5_FILE);
RSConstants.GUIDE_STEP6_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.GUIDE_STEP6_FILE);
RSConstants.GUIDE_STEP7_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.GUIDE_STEP7_FILE);
RSConstants.GUIDE_STEP8_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.GUIDE_STEP8_FILE);
RSConstants.GUIDE_STEP9_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.GUIDE_STEP9_FILE);
RSConstants.DRAGON_GLYPH_TEXTURE = string.format(RSConstants.TEXTURE_PATH, RSConstants.DRAGON_GLYFH_FILE);

---============================================================================
-- Guide constants
---============================================================================

RSConstants.TRANSPORT = "T"
RSConstants.ENTRANCE = "E"
RSConstants.PATH_START = "P"
RSConstants.FLAG = "F"
RSConstants.DOT = "D"
RSConstants.STEP1 = "1"
RSConstants.STEP2 = "2"
RSConstants.STEP3 = "3"
RSConstants.STEP4 = "4"
RSConstants.STEP5 = "5"
RSConstants.STEP6 = "6"
RSConstants.STEP7 = "7"

---============================================================================
-- Dialogs
---============================================================================

RSConstants.APPLY_COLLECTIONS_LOOT_FILTERS = "RARESCANNER_APPLY_COLLECTIONS_LOOT_FILTERS"
RSConstants.EXPLORER_FILTERING_DIALOG = "RARESCANNER_EXPLORER_FILTERING_DIALOG"
RSConstants.EXPLORER_SCAN_NOT_DONE = "RARESCANNER_EXPLORER_SCAN_NOT_DONE"
RSConstants.ITEM_LIST_VALIDATION_ERROR = "RARESCANNER_INFO_DIALOG"
RSConstants.ITEM_LIST_WRONG_IDS_ERROR = "RARESCANNER_ITEM_LIST_WRONG_IDS_ERROR"
RSConstants.DELETE_GROUP_CONFIRMATION = "RARESCANNER_DELETE_GROUP_CONFIRMATION"
RSConstants.RESET_ROUTE_CONFIRMATION = "RARESCANNER_RESET_ROUTE_CONFIRMATION"

---============================================================================
-- Explorer filters
---============================================================================

RSConstants.EXPLORER_FILTER_DROP_MOUNTS = 1
RSConstants.EXPLORER_FILTER_DROP_PETS = 2
RSConstants.EXPLORER_FILTER_DROP_TOYS = 3
RSConstants.EXPLORER_FILTER_DROP_APPEARANCES = 4
RSConstants.EXPLORER_FILTER_DROP_CLASS_APPEARANCES = 10
RSConstants.EXPLORER_FILTER_DROP_DRAKEWATCHER = 9
RSConstants.EXPLORER_FILTER_DROP_DECOR = 11
RSConstants.EXPLORER_FILTER_DROP_CUSTOM = "c%s"
RSConstants.EXPLORER_FILTER_ACHIEVEMENT_CRITERIA = 5
RSConstants.EXPLORER_FILTER_DEAD = 6
RSConstants.EXPLORER_FILTER_FILTERED = 7
RSConstants.EXPLORER_FILTER_WITHOUT_COLLECTIBLES = 8

---============================================================================
-- Others
---============================================================================

RSConstants.RAID_WARNING_SHOWING_TIME = 3
RSConstants.MINIMUM_DISTANCE_PINS_WORLD_MAP = 0.005
RSConstants.TOOLTIP_MAX_WIDTH = 300
RSConstants.TOOLTIP_MIN_WIDTH = 100

---============================================================================
-- Auxiliar functions
---============================================================================

function RSConstants.IsScanneableAtlas(atlasName)
	return RSConstants.IsEventAtlas(atlasName) or RSConstants.IsNpcAtlas(atlasName) or RSConstants.IsContainerAtlas(atlasName)
end

function RSConstants.IsEventAtlas(atlasName)
	return atlasName == RSConstants.EVENT_VIGNETTE or atlasName == RSConstants.EVENT_ELITE_VIGNETTE or atlasName == RSConstants.EVENT_TORMENTORS_VIGNETTE or atlasName == RSConstants.EVENT_HORN
end

function RSConstants.IsNpcAtlas(atlasName)
	return atlasName == RSConstants.NPC_VIGNETTE or atlasName == RSConstants.NPC_LEGION_VIGNETTE or atlasName == RSConstants.NPC_VIGNETTE_ELITE or atlasName == RSConstants.NPC_NAZJATAR_VIGNETTE or atlasName == RSConstants.NPC_WARFRONT_NEUTRAL_HERO_VIGNETTE or atlasName == RSConstants.NPC_TORMENTORS_VIGNETTE or atlasName == RSConstants.NPC_WARLOCK_PORTAL_GOBLIN
end

function RSConstants.IsContainerAtlas(atlasName)
	return atlasName == RSConstants.CONTAINER_VIGNETTE or atlasName == RSConstants.CONTAINER_ELITE_VIGNETTE or atlasName == RSConstants.CONTAINER_LOCKED_VIGNETTE or atlasName == RSConstants.CONTAINER_ELITE_LOCKED_VIGNETTE or atlasName == RSConstants.CONTAINER_LORE_OBJECT or atlasName == RSConstants.CONTAINER_HIGH_PEAK_OBJECT or atlasName == RSConstants.CONTAINER_PVP_AIRPLANE_OBJECT or atlasName == RSConstants.CONTAINER_PVP_FLAGS_OBJECT
end

function RSConstants.IsHighPeakAtlas(atlasName)
	return atlasName == RSConstants.CONTAINER_HIGH_PEAK_OBJECT
end

function RSConstants.IsContainerPvpAtlas(atlasName)
	return atlasName == RSConstants.CONTAINER_PVP_AIRPLANE_OBJECT or atlasName == RSConstants.CONTAINER_PVP_FLAGS_OBJECT
end
