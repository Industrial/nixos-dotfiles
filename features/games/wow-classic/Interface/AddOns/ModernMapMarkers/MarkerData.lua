-- ModernMapMarkers - MarkerData.lua  (WoW: Forever 1.60+, interface 16001)
-- ============================================================
-- Entry format
-- ============================================================
--
--   { zoneID, x, y, name, type, info, dungeonID [, slot8] }
--
--   zoneID   : EITHER the old 3.3.5a zone index within the continent (1-53;
--              translated to a uiMapID by MMM_ZoneToUiMap below), OR a raw
--              uiMapID (any value >= 1000). Use raw uiMapIDs for anything
--              new to Forever -- /mmm here prints a ready-to-paste line.
--   x, y     : zone-map coordinates, 0-1 (same as the 3.3.5a data)
--   name     : marker name shown on hover and in the Find Marker panel
--              may contain an embedded comment after \n
--              example: "Gnomeregan\n|cFF808080(Workshop Entrance)|r"
--              the comment is shown as a second line in the Find Marker panel
--   type     : "dungeon", "raid", "worldboss", "boat", "zepp", "tram", "skyship", "portal", "leyline", "convergence" & "battleground"
--   info     : level range, examples: "52-60" or "60"
--              faction string: "Alliance", "Horde" & "Neutral"
--   dungeonID : used for dungeons and raids
--   slot8    : optional, one of:
--
--              - Transport destination(s) -- boat / zepp / tram / portal only:
--                  single - {continent, zone}
--                  dual   - {{continent, zone}, {continent, zone}}
--                           left-click navigates to dest[1]
--                           right-click navigates to dest[2]
--                  multi  - {{continent, zone, "Label"}, ...}  (3 or more)
--                           opens a popup menu listing all destinations
--                  Destinations that do not resolve to a Forever map are
--                  dropped at load; a marker left with none is skipped.
--
--              - "nopulse"  -- used inside a dest table as the third element:
--                              {continent, zone, "nopulse"}
--                              navigates normally but suppresses the return
--                              highlight pulse on the destination marker
--
--              - "nolist"   -- excludes the entry from the Find Marker panel
--                              while still showing it on the world map
--
--   slot9    : optional race restriction, a raceID or a list of raceIDs
--              (third return of UnitRace). The marker is only shown to those
--              races. 95 = High Order Skyborne, 96 = Windshaper Skyborne.
--              example: {1, 0.120, 0.562, "Portal to Stormwind", "portal",
--                        "Alliance", nil, {2, 21}, 95}
--
--              - "dropdown" -- the marker comment is shown only in the
--                              Find Marker panel, not on the world map
--                              hover tooltip
--              - Floor number --  dungeon / raid only:
--                  		opens the dungeon map on that floor instead of its default
--
-- ============================================================
-- Continent IDs
-- ============================================================
--
--   [1] Kalimdor        [2] Eastern Kingdoms
--
-- Forever is original Azeroth only: no Outland, no Northrend, no WDM dataset.
-- Content from TBC/WotLK (Old Hillsbrad, Karazhan, Sunwell, Blasted Lands mage
-- portals, Northrend transports, ...) was removed from the 3.3.5a data.

-- 3.3.5a zone index -> uiMapID (Classic-era/Forever map IDs).
-- nil = the zone does not exist in Forever (Exodar, Azuremyst, Silvermoon...).
MMM_ZoneToUiMap = {
	[1] = { -- Kalimdor
		[1]  = 1440, -- Ashenvale
		[2]  = 1447, -- Azshara
		[5]  = 1439, -- Darkshore
		[6]  = 1457, -- Darnassus
		[7]  = 1443, -- Desolace
		[8]  = 1411, -- Durotar
		[9]  = 1445, -- Dustwallow Marsh
		[10] = 1448, -- Felwood
		[11] = 1444, -- Feralas
		[12] = 1450, -- Moonglade
		[13] = 1412, -- Mulgore
		[14] = 1454, -- Orgrimmar
		[15] = 1451, -- Silithus
		[16] = 1442, -- Stonetalon Mountains
		[17] = 1446, -- Tanaris
		[18] = 1438, -- Teldrassil
		[19] = 1413, -- The Barrens
		[21] = 1441, -- Thousand Needles
		[22] = 1456, -- Thunder Bluff
		[23] = 1449, -- Un'Goro Crater
		[24] = 1452, -- Winterspring
		[25] = 2482, -- Mt. Hyjal
		[26] = 2521, -- Zephras Isle
		[27] = 2652, -- Shen'dralas
	},
	[2] = { -- Eastern Kingdoms
		[1]  = 1416, -- Alterac Mountains
		[2]  = 1417, -- Arathi Highlands
		[3]  = 1418, -- Badlands
		[4]  = 1419, -- Blasted Lands
		[5]  = 1428, -- Burning Steppes
		[6]  = 1430, -- Deadwind Pass
		[7]  = 1426, -- Dun Morogh
		[8]  = 1431, -- Duskwood
		[9]  = 1423, -- Eastern Plaguelands
		[10] = 1429, -- Elwynn Forest
		[13] = 1424, -- Hillsbrad Foothills
		[14] = 1455, -- Ironforge
		[16] = 1432, -- Loch Modan
		[17] = 1433, -- Redridge Mountains
		[18] = 1427, -- Searing Gorge
		[20] = 1421, -- Silverpine Forest
		[21] = 1453, -- Stormwind City
		[22] = 1434, -- Stranglethorn Vale
		[23] = 1435, -- Swamp of Sorrows
		[24] = 1425, -- The Hinterlands
		[25] = 1420, -- Tirisfal Glades
		[26] = 1458, -- Undercity
		[27] = 1422, -- Western Plaguelands
		[28] = 1436, -- Westfall
		[29] = 1437, -- Wetlands
		[30] = 2548, -- Riverglades
	},
}

-- Continent map IDs (used to work out which continent a map belongs to).
MMM_ContinentMaps = { [1414] = 1, [1415] = 2 }

MMM_DefaultPoints = {
	-- -------------------------------------------------------------------------
	[1] = { -- Kalimdor
		-- Dungeons
		{9, 0.750, 0.140, "Alcaz Prison", "dungeon", "48-53", "alcaz_prison"},
		{1, 0.123, 0.128, "Blackfathom Deeps", "dungeon", "24-32", "blackfathom_deeps"},
		{2, 0.380, 0.324, "Blackmaw Hold", "dungeon", "55-60", "blackmaw_hold"},
		{11, 0.648, 0.303, "Dire Maul - East", "dungeon", "55-58", "dire_maul_east"},
		{11, 0.771, 0.369, "Dire Maul - East\n|cFF808080(The Hidden Reach)|r", "dungeon", "55-58", "dire_maul_east"},
		{11, 0.671, 0.34, "Dire Maul - East\n|cFF808080(Side Entrance)|r", "dungeon", "55-58", "dire_maul_exterior"},
		{11, 0.624, 0.249, "Dire Maul - North", "dungeon", "57-60", "dire_maul_north"},
		{11, 0.604, 0.311, "Dire Maul - West", "dungeon", "57-60", "dire_maul_west"},
		{7, 0.29, 0.629, "Maraudon", "dungeon", "46-55", "maraudon"},
		{14, 0.53, 0.486, "Ragefire Chasm", "dungeon", "13-18", "ragefire_chasm"},
		{19, 0.508, 0.94, "Razorfen Downs", "dungeon", "37-46", "razorfen_downs"},
		{19, 0.423, 0.9, "Razorfen Kraul", "dungeon", "29-38", "razorfen_kraul"},
		{23, 0.426, 0.061, "Shaper's Terrace", "dungeon", "58-60", "shapers_terrace"},
		{19, 0.462, 0.357, "Wailing Caverns", "dungeon", "17-24", "wailing_caverns_instance"},
		{17, 0.389, 0.184, "Zul'Farrak", "dungeon", "44-54", "zul_farrak"},
		-- Raids
		{25, 0.890, 0.324, "Hyjal Summit", "raid", "60", "hyjal_summit"},
		{9, 0.529, 0.777, "Onyxia's Lair", "raid", "60", "onyxias_lair"},
		{15, 0.305, 0.987, "Ruins of Ahn'Qiraj", "raid", "60", "ruins_of_ahnqiraj"},
		{15, 0.269, 0.987, "Temple of Ahn'Qiraj", "raid", "60", "temple_of_ahnqiraj"},
		{25, 0.704, 0.627, "The Barrow Deeps", "raid", "60", "barrow_deeps"},
		{24, 0.503, 0.479, "The Barrow Deeps", "raid", "60", "barrow_deeps"},
		-- World Bosses
		{2, 0.535, 0.816, "Azuregos", "worldboss", "60", nil},
		{1, 0.937, 0.355, "Emerald Dragon\n|cFF808080(Bough Shadow)|r", "worldboss", "60", nil},
		{11, 0.512, 0.108, "Emerald Dragon\n|cFF808080(Dream Bough)|r", "worldboss", "60", nil},
		-- Battlegrounds (entrance markers; info = the faction that can use the entrance).
		-- Entries marked "approx" are estimates: stand on the portal and use /mmm here
		-- to get exact coordinates.
		{1, 0.620, 0.830, "Warsong Gulch", "battleground", "Alliance", nil, "nolist"},
		{19, 0.430, 0.100, "Warsong Gulch", "battleground", "Horde", nil, "nolist"}, -- approx
		{19, 0.643, 0.333, "Darkspear Islands", "battleground", "Horde", nil, "nolist"},
		{9, 0.543, 0.081, "Darkspear Islands", "battleground", "Alliance", nil, "nolist"},
		-- Transport
		{8, 0.512, 0.135, "Zeppelins to Tirisfal Glades & Grom'Gol", "zepp", "Horde", nil, {{2, 25, "Tirisfal Glades"}, {2, 22, "Grom'Gol"}}},
		{13, 0.346, 0.244, "Skyship to Zephras Isle", "skyship", "Horde", nil, {1, 26}},
		{26, 0.579, 0.807, "Skyship to Mulgore", "skyship", "Horde", nil, {1, 13}},
		{26, 0.657, 0.832, "Skyship to Dalaran", "skyship", "Alliance", nil, {2, 1}},
		{19, 0.636, 0.389, "Boat to Booty Bay", "boat", "Neutral", nil, {2, 22}},
		{5, 0.333, 0.399, "Boat to Rut'Theran Village", "boat", "Alliance", nil, {1, 18}},
		{5, 0.313, 0.406, "Boat to Stormwind Harbor", "boat", "Alliance", nil, {2, 21}},
		{5, 0.325, 0.436, "Boat to Menethil Harbor", "boat", "Alliance", nil, {2, 29}},
		{9, 0.718, 0.566, "Boat to Menethil Harbor", "boat", "Alliance", nil, {2, 29}},
		{11, 0.311, 0.395, "Boat to Forgotten Coast", "boat", "Alliance", nil, {1, 11}},
		{11, 0.431, 0.428, "Boat to Sardor Isle", "boat", "Alliance", nil, {1, 11}},
		{18, 0.552, 0.949, "Boat to Auberdine", "boat", "Alliance", nil, {1, 5}},
		{17, 0.681, 0.226, "Boat to Powderfuse Port", "boat", "Neutral", nil, {2, 30}},
		-- Skyborne: Ley Lines & Elemental Convergences (race-restricted)
		{1413, 0.443, 0.160, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1413, 0.446, 0.904, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1413, 0.467, 0.392, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1413, 0.468, 0.827, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1413, 0.486, 0.241, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1413, 0.489, 0.363, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1413, 0.517, 0.485, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1413, 0.558, 0.342, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1413, 0.568, 0.240, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1413, 0.574, 0.510, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1413, 0.591, 0.396, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1439, 0.360, 0.861, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1439, 0.423, 0.301, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1439, 0.431, 0.595, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1439, 0.444, 0.217, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1439, 0.452, 0.503, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1439, 0.463, 0.382, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1439, 0.571, 0.261, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1439, 0.602, 0.193, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1440, 0.074, 0.142, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1440, 0.136, 0.309, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1440, 0.203, 0.426, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1440, 0.221, 0.529, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1440, 0.291, 0.295, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1440, 0.360, 0.546, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1440, 0.606, 0.556, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1440, 0.668, 0.821, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1440, 0.755, 0.657, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1440, 0.814, 0.489, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1442, 0.349, 0.603, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1442, 0.364, 0.124, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1442, 0.485, 0.468, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1442, 0.587, 0.659, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1442, 0.697, 0.520, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1442, 0.737, 0.865, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{2521, 0.339, 0.555, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{2521, 0.355, 0.338, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{2521, 0.388, 0.476, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{2521, 0.458, 0.808, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{2521, 0.463, 0.179, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{2521, 0.483, 0.585, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{2521, 0.505, 0.334, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{2521, 0.525, 0.660, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{2521, 0.538, 0.663, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{2521, 0.551, 0.506, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{2521, 0.588, 0.336, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{2521, 0.639, 0.742, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{2521, 0.640, 0.462, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{2521, 0.691, 0.620, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1411, 0.451, 0.157, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1413, 0.448, 0.550, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1413, 0.457, 0.698, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1413, 0.497, 0.346, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1413, 0.498, 0.286, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1413, 0.530, 0.221, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1413, 0.540, 0.266, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1413, 0.546, 0.149, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1413, 0.548, 0.347, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1413, 0.563, 0.416, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1413, 0.631, 0.411, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1440, 0.099, 0.279, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1440, 0.111, 0.135, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1440, 0.158, 0.196, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1440, 0.207, 0.322, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1440, 0.259, 0.425, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1440, 0.328, 0.394, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1440, 0.336, 0.678, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1440, 0.481, 0.695, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1440, 0.621, 0.616, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1441, 0.234, 0.304, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1441, 0.273, 0.415, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1441, 0.422, 0.494, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1441, 0.548, 0.483, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1441, 0.674, 0.622, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1441, 0.686, 0.520, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1442, 0.334, 0.639, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1442, 0.493, 0.360, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1442, 0.657, 0.460, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1442, 0.726, 0.576, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1442, 0.749, 0.945, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1442, 0.809, 0.905, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{2521, 0.341, 0.599, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{2521, 0.360, 0.336, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{2521, 0.466, 0.381, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{2521, 0.477, 0.695, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{2521, 0.484, 0.204, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{2521, 0.485, 0.558, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{2521, 0.485, 0.805, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{2521, 0.528, 0.576, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{2521, 0.593, 0.800, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{2521, 0.617, 0.517, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{2521, 0.649, 0.380, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{2521, 0.683, 0.750, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{2521, 0.684, 0.661, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{2521, 0.701, 0.614, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1412, 0.386, 0.447, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1412, 0.520, 0.342, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1413, 0.470, 0.802, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1413, 0.509, 0.145, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1439, 0.584, 0.198, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1412, 0.502, 0.535, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1440, 0.600, 0.630, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1440, 0.763, 0.675, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1440, 0.861, 0.587, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1440, 0.894, 0.498, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
	},
	-- -------------------------------------------------------------------------
	[2] = { -- Eastern Kingdoms
		-- Dungeons
		{18, 0.387, 0.833, "Blackrock Depths\n|cFF808080(Searing Gorge)|r", "dungeon", "52-60", "blackrock_depths", "dropdown"},
		{5, 0.328, 0.365, "Blackrock Depths\n|cFF808080(Burning Steppes)|r", "dungeon", "52-60", "blackrock_depths", "dropdown"},
		{1, 0.090, 0.600, "City of Dalaran", "dungeon", "28-33", "city_of_dalaran"},
		{28, 0.423, 0.726, "The Deadmines", "dungeon", "17-26", "deadmines"},
		{29, 0.545, 0.645, "Excavation Site: Wetlands", "dungeon", "24-29", "excavation_site_wetlands"},
		{7, 0.178, 0.392, "Gnomeregan", "dungeon", "29-38", "gnomeregan"},
		{7, 0.216, 0.30, "Gnomeregan\n|cFF808080(Workshop Entrance)|r", "dungeon", "29-38", "gnomeregan_approach"},
		{14, 0.448, 0.523, "Hall of Thanes", "dungeon", "13-18", "hall_of_thanes"},
		{30, 0.379, 0.376, "Krol'dok Stronghold", "dungeon", "40-45", "kroldok_stronghold"},
		{5, 0.32, 0.39, "Lower Blackrock Spire\n|cFF808080(Burning Steppes)|r", "dungeon", "55-60", "lower_blackrock_spire", "dropdown"},
		{18, 0.379, 0.858, "Lower Blackrock Spire\n|cFF808080(Searing Gorge)|r", "dungeon", "55-60", "lower_blackrock_spire", "dropdown"},
		{25, 0.646, 0.688, "Ruins of Lordaeron", "dungeon", "15-20", "ruins_of_lordaeron"},
		{25, 0.87, 0.325, "Scarlet Monastery\n|cFF808080(Armory)|r", "dungeon", "32-42", "scarlet_armory"},
		{25, 0.862, 0.295, "Scarlet Monastery\n|cFF808080(Cathedral)|r", "dungeon", "35-45", "scarlet_cathedral"},
		{25, 0.839, 0.283, "Scarlet Monastery\n|cFF808080(Graveyard)|r", "dungeon", "26-36", "scarlet_graveyard"},
		{25, 0.85, 0.335, "Scarlet Monastery\n|cFF808080(Library)|r", "dungeon", "29-39", "scarlet_library"},
		{27, 0.69, 0.729, "Scholomance", "dungeon", "58-60", "scholomance"},
		{20, 0.448, 0.678, "Shadowfang Keep", "dungeon", "22-30", "shadowfang_keep"},
		{21, 0.508, 0.67, "The Stockade", "dungeon", "24-32", "stockade"},
		{9, 0.258, 0.104, "Stratholme", "dungeon", "58-60", "stratholme", 1},
		{9, 0.413, 0.170, "Stratholme\n|cFF808080(Back Gate)|r", "dungeon", "58-60", "stratholme", 2},
		{23, 0.703, 0.55, "The Temple of Atal'Hakkar", "dungeon", "50-60", "sunken_temple"},
		{22, 0.218, 0.284, "The Drowned City", "dungeon", "35-45", "the_drowned_city"},
		{3, 0.429, 0.13, "Uldaman", "dungeon", "41-51", "uldaman"},
		{3, 0.657, 0.438, "Uldaman\n|cFF808080(Back Entrance)|r", "dungeon", "41-51", "uldaman_approach"},
		{5, 0.312, 0.365, "Upper Blackrock Spire\n|cFF808080(Burning Steppes)|r", "dungeon", "55-60", "upper_blackrock_spire", "dropdown"},
		{18, 0.371, 0.833, "Upper Blackrock Spire\n|cFF808080(Searing Gorge)|r", "dungeon", "55-60", "upper_blackrock_spire", "dropdown"},
		-- Raids
		{18, 0.332, 0.833, "Blackwing Lair\n|cFF808080(Searing Gorge)|r", "raid", "60", "blackwing_lair", "dropdown"},
		{5, 0.273, 0.363, "Blackwing Lair\n|cFF808080(Burning Steppes)|r", "raid", "60", "blackwing_lair", "dropdown"},
		{18, 0.332, 0.86, "Molten Core\n|cFF808080(Searing Gorge)|r", "raid", "60", "molten_core", "dropdown"},
		{5, 0.273, 0.39, "Molten Core\n|cFF808080(Burning Steppes)|r", "raid", "60", "molten_core", "dropdown"},
		{22, 0.53, 0.172, "Zul'Gurub", "raid", "60", "zul_gurub"},
		-- World Bosses
		{8, 0.465, 0.357, "Emerald Dragon\n|cFF808080(The Twilight Grove)|r", "worldboss", "60", nil},
		{24, 0.632, 0.217, "Emerald Dragon\n|cFF808080(Seradane)|r", "worldboss", "60", nil},
		-- Battlegrounds (see the note in the Kalimdor section)
		{2, 0.460, 0.470, "Arathi Basin", "battleground", "Alliance", nil, "nolist"}, -- approx
		{2, 0.740, 0.340, "Arathi Basin", "battleground", "Horde", nil, "nolist"}, -- approx
		{1, 0.397, 0.797, "Alterac Valley", "battleground", "Alliance", nil, "nolist"}, -- approx
		{1, 0.641, 0.584, "Alterac Valley", "battleground", "Horde", nil, "nolist"}, -- approx
		-- Transport
		{1, 0.126, 0.520, "Skyship to Zephras Isle", "skyship", "Alliance", nil, {1, 26}},
		{21, 0.677, 0.325, "Tram to Ironforge", "tram", "Alliance", nil, {2, 14}},
		{14, 0.762, 0.511, "Tram to Stormwind", "tram", "Alliance", nil, {2, 21}},
		{29, 0.051, 0.634, "Boat to Auberdine via Southshore", "boat", "Alliance", nil, {2, 13}},
		{13, 0.506, 0.697, "Boat to Auberdine", "boat", "Alliance", nil, {1, 5}},
		{29, 0.082, 0.635, "Boat to Theramore Isle", "boat", "Alliance", nil, {1, 9}},
		{22, 0.257, 0.73, "Boat to Ratchet", "boat", "Neutral", nil, {1, 19}},
		{25, 0.606, 0.583, "Zeppelins to Durotar & Grom'Gol", "zepp", "Horde", nil, {{1, 8, "Durotar"}, {2, 22, "Grom'Gol"}}},
		{22, 0.312, 0.298, "Zeppelins to Tirisfal Glades & Durotar", "zepp", "Horde", nil, {{2, 25, "Tirisfal Glades"}, {1, 8, "Durotar"}}},
		{21, 0.216, 0.562, "Boat to Auberdine", "boat", "Alliance", nil, {1, 5}},
		{30, 0.798, 0.512, "Boat to Steamwheedle Port", "boat", "Neutral", nil, {1, 17}},
		{1, 0.120, 0.562, "Portal to Stormwind\n|cFF808080(Skyborne Only)|r", "portal", "Alliance", nil, {2, 21}, 95},
		{21, 0.500, 0.870, "Portal to Dalaran\n|cFF808080(Skyborne Only)|r", "portal", "Alliance", nil, {2, 1}, 95},

		-- Skyborne: Ley Lines & Elemental Convergences (race-restricted)
		{1426, 0.384, 0.388, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1426, 0.459, 0.442, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1426, 0.566, 0.456, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1426, 0.638, 0.506, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1426, 0.768, 0.519, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1431, 0.185, 0.572, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1431, 0.256, 0.345, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1431, 0.341, 0.709, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1431, 0.630, 0.734, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1431, 0.725, 0.305, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1431, 0.783, 0.354, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1437, 0.147, 0.372, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1437, 0.402, 0.384, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1437, 0.463, 0.251, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1437, 0.538, 0.645, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1437, 0.550, 0.297, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1437, 0.562, 0.640, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1437, 0.690, 0.364, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1429, 0.279, 0.948, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1429, 0.372, 0.561, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1429, 0.384, 0.736, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1429, 0.649, 0.674, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1429, 0.755, 0.520, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1429, 0.846, 0.765, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1436, 0.351, 0.734, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1436, 0.424, 0.252, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1436, 0.459, 0.198, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1436, 0.463, 0.588, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1436, 0.514, 0.221, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1436, 0.511, 0.675, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1436, 0.596, 0.315, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1433, 0.125, 0.727, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1433, 0.196, 0.515, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1433, 0.305, 0.545, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1433, 0.307, 0.458, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1433, 0.549, 0.649, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1433, 0.654, 0.749, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1433, 0.685, 0.444, "Ley Line", "leyline", "High Order Skyborne", nil, "nolist"},
		{1421, 0.455, 0.210, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1421, 0.481, 0.754, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1421, 0.494, 0.525, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1421, 0.525, 0.704, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1421, 0.548, 0.240, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1421, 0.550, 0.661, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1421, 0.560, 0.464, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1421, 0.562, 0.103, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1421, 0.612, 0.793, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1417, 0.254, 0.300, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1417, 0.520, 0.507, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1417, 0.683, 0.304, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1420, 0.492, 0.639, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1424, 0.603, 0.106, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1424, 0.729, 0.636, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1424, 0.808, 0.453, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1424, 0.891, 0.588, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1432, 0.275, 0.521, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1432, 0.590, 0.366, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1434, 0.134, 0.150, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1436, 0.348, 0.731, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1436, 0.416, 0.820, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1436, 0.597, 0.362, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
		{1437, 0.541, 0.269, "Elemental Convergence", "convergence", "Windshaper Skyborne", nil, "nolist"},
	},
	-- -------------------------------------------------------------------------
}

-- ============================================================
-- Instance pins (drawn on the dungeon map overlay)
-- ============================================================
--   MMM_InstancePins[ dungeonID ][ floorNumber ] = { pin, pin, ... }
--
--   dungeonID   : the key used in ModernMapMarkers_Dungeons.lua DUNGEON_MAPS.
--                 Dungeon IDs that share a texture folder (Scarlet wings, Dire
--                 Maul wings, *_approach, ...) share pins, so each floor only
--                 needs listing once, under whichever ID owns it.
--   floorNumber : the real texture floor (<folder><floor>_<tile>), NOT the
--                 dropdown index.
--
--   { "boss",     x, y, npcID, name, level, encounterID, bossType }
--        bossType : 1 = boss, 2 = optional / rare boss, 3 = raid boss
--        level    : number, or false / 9999 when not shown
--        bosses sharing the same x,y are merged into one pin
--   { "level",    x, y, targetFloor [, true] }   floor change
--        true = the target is UP (arrow points up), else DOWN
--   { "entrance", x, y [, "raid"] }              instance entrance / exit
--   { "item",     x, y, itemID }                 (not drawn yet)
--   x, y are 0-1 over the 1002x668 map content area.
-- ============================================================
MMM_InstancePins = {
	-- Dungeons
	["alcaz_prison"] = {  -- placeholder, no pin data yet
		[1] = {},
	},
	["blackfathom_deeps"] = {  -- [seq] floors assumed to follow source IDs in order; verify in-game
		[1] = {
			{"entrance", 0.453, 0.108},
			{"level", 0.621, 0.741, 2},
			{"boss", 0.329, 0.602, 4887, "Ghamoo-ra", 25, 5027, 1},
			{"boss", 0.101, 0.360, 4831, "Lady Sarevess", 25, 4979, 1},
			{"boss", 0.536, 0.568, 6243, "Gelihast", 26, 1773, 1},
			{"boss", 0.614, 0.625, 12902, "Lorgus Jett", 26, 12822, 1},
		},
		[2] = {
			{"level", 0.477, 0.707, 3},
			{"level", 0.350, 0.290, 1},
			{"boss", 0.519, 0.816, 4832, "Twilight Lord Kelris", 27, 4939, 1},
			{"boss", 0.856, 0.866, 4829, "Aku'mai", 28, 2837, 1},
		},
		[3] = {
			{"level", 0.300, 0.612, 2, true},
			{"boss", 0.606, 0.312, 4830, "Old Serra'kis", 26, 1816, 1},
			{"boss", 0.234, 0.498, 12876, "Baron Aquanis", 28, 110, 1},
		},
	},
	["blackmaw_hold"] = {  -- placeholder, no pin data yet
		[1] = {},
	},
	["blackrock_depths"] = {
		[1] = {
			{"entrance", 0.333, 0.791},
			{"level", 0.655, 0.294, 2, true},
			{"level", 0.420, 0.650, 2, true},
			{"boss", 0.475, 0.928, 9018, "High Interrogator Gerstahn <Twilight's Hammer Interrogator>", 52, 8761, 1},
			{"boss", 0.520, 0.615, 9319, "Houndmaster Grebmar", 52, 9212, 1},
			{"boss", 0.252, 0.522, 9016, "Bael'Gar", 54, 12162, 1},
			{"boss", 0.561, 0.312, 9017, "Lord Incendius", 55, 1204, 1},
			{"boss", 0.633, 0.215, 9056, "Fineous Darkvire <Chief Architect>", 54, 8704, 1},
			{"boss", 0.558, 0.675, 9024, "Lord Roccor", 51, 5781, 1},
			{"boss", 0.505, 0.635, 9031, "Anub'shiah / Eviscerator / Gorosh the Dervish / Grizzle / Hedrum the Creeper / Ok'thor the Breaker", 56, 3004, 1},
		},
		[2] = {
			{"level", 0.595, 0.547, 1},
			{"level", 0.445, 0.900, 1},
			{"boss", 0.367, 0.822, 9033, "General Angerforge", 57, 8756, 1},
			{"boss", 0.545, 0.975, 9024, "Pyromancer Loregrain", 52, 8762, 1},
			{"boss", 0.595, 0.662, 9041, "Warder Stilgiss / Verek", 56, 9089, 1},
			{"boss", 0.367, 0.650, 8983, "Golem Lord Argelmach", 57, 8759, 1},
			{"boss", 0.528, 0.649, 9502, "Phalanx", 55, 8177, 1},
			{"boss", 0.490, 0.625, 9543, "Ribbly Screwspigot", 53, 8667, 1},
			{"boss", 0.500, 0.609, 9499, "Plugger Spazzring", 55, 8652, 1},
			{"boss", 0.538, 0.488, 9156, "Ambassador Flamelash", 57, 8329, 1},
			{"boss", 0.805, 0.119, 9938, "Magmus", 57, 12162, 1},
			{"boss", 0.537, 0.248, 9039, "Doom'rel / Dope'rel / Hate'rel / Seeth'rel / Vile'rel / Gloom'rel / Anger'rel", 57, 8687, 1},
			{"boss", 0.918, 0.119, 9019, "Emperor Dagran Thaurissan", 59, 8807, 1},
			{"boss", 0.935, 0.119, 8929, "Princess Moira Bronzebeard <Princess of Ironforge>", 58, 8705, 1},
			{"boss", 0.480, 0.580, 9537, "Hurley Blackbreath", 55, 8658, 1},
			{"boss", 0.505, 0.354, 8923, "Panzor the Invincible", 57, 8270, 2},
		},
	},
	["city_of_dalaran"] = {
		[1] = {
			{"level", 0.616, 0.542, 2},
			{"level", 0.513, 0.684, 2},
			{"level", 0.531, 0.365, 2},
			{"boss", 0.524, 0.840, 245999, "Arcane Anomaly", 30, 129891, 1},
			{"boss", 0.565, 0.230, 246020, "Shade of the Archmage", 33, 130061, 1},
			{"boss", 0.517, 0.551, 246003, "Fel Ancient", 32, 129894, 1},
			{"boss", 0.613, 0.424, 246017, "Unstable Sentinel", 31, 129954, 1},
			{"boss", 0.668, 0.516, 246016, "Arcanic Enigma", 30, 129900, 1},
			{"boss", 0.418, 0.729, 246008, "Mana Devourer", 31, 129895, 1},
		},
		[2] = {
			{"entrance", 0.184, 0.840},
			{"level", 0.765, 0.570, 1, true},
			{"boss", 0.545, 0.510, 247126, "Atrexis the Grave Knight", 29, 145787, 1},
			{"boss", 0.680, 0.180, 247032, "Lyn the Ignored", 31, 130235, 2},
		},
	},
	["deadmines"] = {
		[1] = {
			{"entrance", 0.297, 0.133},
			{"level", 0.655, 0.667, 2},
			{"boss", 0.374, 0.610, 644, "Rhahk'Zor <The Foreman>", 19, 14403, 1},
			{"boss", 0.523, 0.510, 3586, "Miner Johnson", 19, 556, 2},
			{"boss", 0.493, 0.862, 642, "Sneed's Shredder / Sneed", 20, 1269, 1},
			{"boss", 0.607, 0.572, 1763, "Gilnid <The Smelter>", 20, 7124, 1},
		},
		[2] = {
			{"level", 0.123, 0.883, 1, true},
			{"boss", 0.561, 0.265, 646, "Mr. Smite <The Ship's First Mate>", 20, 2026, 1},
			{"boss", 0.632, 0.389, 647, "Captain Greenskin", 20, 7113, 1},
			{"boss", 0.603, 0.455, 639, "Edwin VanCleef <Defias Kingpin>", 21, 2029, 1},
			{"boss", 0.668, 0.398, 645, "Cookie <The Ship's Cook>", 20, 1305, 1},
		},
	},
	["dire_maul_east"] = {
		[5] = {
			{"entrance", 0.070, 0.392},
			{"entrance", 0.164, 0.853},
			{"entrance", 0.954, 0.508},
			{"level", 0.505, 0.630, 6},
			{"boss", 0.122, 0.310, 14354, "Pusillin", 57, 7552, 1},
			{"boss", 0.437, 0.477, 11490, "Zevrim Thornhoof", 57, 11335, 1},
		},
		[6] = {
			{"entrance", 0.281, 0.555},
			{"level", 0.633, 0.844, 5, true},
			{"boss", 0.554, 0.269, 11492, "Alzzin the Wildshaper", 58, 14416, 1},
			{"boss", 0.533, 0.713, 13280, "Hydrospawn", 57, 5489, 1},
			{"boss", 0.576, 0.732, 14327, "Lethtendris", 57, 14378, 1},
		},
	},
	["dire_maul_north"] = {
		[1] = {
			{"entrance", 0.718, 0.926},
			{"boss", 0.694, 0.752, 14326, "Guard Mol'dar", 59, 11561, 1},
			{"boss", 0.609, 0.681, 14322, "Stomper Kreeg <The Drunk>", 59, 11545, 1},
			{"boss", 0.495, 0.780, 14321, "Guard Fengus", 59, 11561, 1},
			{"boss", 0.265, 0.567, 14323, "Guard Slip'kik", 59, 11561, 1},
			{"boss", 0.318, 0.498, 14325, "Captain Kromcrush", 61, 11564, 1},
			{"boss", 0.304, 0.254, 14324, "Cho'Rush the Observer", 60, 11537, 1},
			{"boss", 0.319, 0.259, 11501, "King Gordok", 62, 11583, 1},
		},
	},
	["dire_maul_west"] = {
		[2] = {
			{"entrance", 0.935, 0.721},
			{"entrance", 0.936, 0.510},
			{"level", 0.270, 0.190, 3},
			{"level", 0.304, 0.430, 4},
			{"boss", 0.332, 0.530, 11489, "Tendris Warpwood", 60, 14383, 1},
			{"boss", 0.212, 0.782, 11488, "Illyanna Ravenoak", 60, 11270, 1},
		},
		[3] = {
			{"level", 0.415, 0.120, 2},
			{"boss", 0.335, 0.436, 11487, "Magister Kalendris", 60, 14384, 1},
			{"boss", 0.322, 0.143, 11467, "Tsu'zee", 59, 11250, 1},
		},
		[4] = {
			{"level", 0.745, 0.400, 2, true},
			{"boss", 0.350, 0.576, 11496, "Immol'thar", 61, 14173, 1},
			{"boss", 0.620, 0.230, 11486, "Prince Tortheldrin", 61, 11256, 1},
		},
	},
	["excavation_site_wetlands"] = {
		[1] = {
			{"entrance", 0.075, 0.650},
			{"boss", 0.475, 0.500, 260322, "Saltspine", false, 144209, 1},
			{"boss", 0.600, 0.260, 260326, "Relic Guardian", false, 144224, 1},
			{"boss", 0.738, 0.500, 260325, "Shadetooth", false, 144210, 1},
			{"boss", 0.870, 0.710, 260808, "Highland Horror", 28, 9010, 1},
		},
	},
	["gnomeregan"] = {  -- [seq] floors assumed to follow source IDs in order; verify in-game
		[1] = {
			{"entrance", 0.644, 0.275},
			{"level", 0.345, 0.640, 2},
			{"level", 0.470, 0.870, 2},
			{"level", 0.551, 0.440, 2},
			{"boss", 0.770, 0.670, 7361, "Grubbis", 32, 6533, 1},
		},
		[2] = {
			{"level", 0.245, 0.580, 3},
			{"level", 0.430, 0.830, 1, true},
			{"level", 0.640, 0.580, 1, true},
			{"boss", 0.755, 0.450, 7079, "Viscous Fallout", 30, 5497, 1},
			{"boss", 0.245, 0.700, 6235, "Electrocutioner 6000", 32, 6915, 1},
		},
		[3] = {
			{"entrance", 0.870, 0.480},
			{"level", 0.488, 0.710, 4},
			{"level", 0.273, 0.308, 4},
			{"level", 0.445, 0.430, 2, true},
			{"boss", 0.438, 0.865, 6229, "Crowd Pummeler 9-60", 32, 6774, 1},
		},
		[4] = {
			{"level", 0.481, 0.540, 3, true},
			{"level", 0.710, 0.773, 3, true},
			{"boss", 0.295, 0.540, 6228, "Dark Iron Ambassador", 41, 6669, 2},
			{"boss", 0.313, 0.300, 7800, "Mekgineer Thermaplugg", 34, 6980, 1},
		},
	},
	["hall_of_thanes"] = {
		[1] = {
			{"entrance", 0.511, 0.948},
			{"boss", 0.509, 0.666, 261306, "Faldrim Anvilmar", 16, 142826, 1},
			{"boss", 0.717, 0.465, 261316, "Magmatus", 16, 1070, 1},
			{"boss", 0.509, 0.516, 261311, "Plunder", 16, 142840, 1},
			{"boss", 0.510, 0.167, 261319, "Durgen Dirgehammer", 16, 142837, 1},
		},
	},
	["kroldok_stronghold"] = {  -- placeholder, no pin data yet
		[1] = {},
	},
	["lower_blackrock_spire"] = {  -- placeholder, no pin data yet
		[1] = {
			{"level", 0.640, 0.692, 2},
			{"level", 0.590, 0.600, 2},
			{"boss", 0.520, 0.542, 9237, "War Master Voone / Mor Grayhoof", 59, 142826, 1},
			{"boss", 0.475, 0.620, 9596, "Bannok Grimaxe <Firebrand Legion Champion> (Rare)", 16, 142826, 2},
		},
		[2] = {
			{"level", 0.640, 0.692, 1},
			{"level", 0.590, 0.600, 1},
			{"level", 0.535, 0.500, 3},
			{"boss", 0.550, 0.690, 9236, "Shadow Hunter Vosh'gajin", 58, 142826, 1},
			{"boss", 0.550, 0.750, 10376, "Crystal Fang (Rare)", 60, 142826, 2},
			{"boss", 0.617, 0.733, 10596, "Mother Smolderweb", 60, 142826, 1},
		},
		[3] = {
			{"level", 0.540, 0.380, 4},
			{"level", 0.535, 0.510, 2},
			{"boss", 0.385, 0.582, 9196, "Highlord Omokk", 59, 142826, 1},
		},
		[4] = {
			{"entrance", 0.370, 0.420},
			{"level", 0.540, 0.380, 3},
			{"level", 0.425, 0.725, 5},
			{"boss", 0.450, 0.550, 10584, "Urok Doomhowl", 60, 142826, 1},
		},
		[5] = {
			{"level", 0.425, 0.725, 4},
			{"level", 0.400, 0.595, 6},
			{"boss", 0.540, 0.840, 9736, "Quartermaster Zigris <Bloodaxe Legion>", 59, 142826, 1},
			{"boss", 0.380, 0.825, 10220, "Halycon / Gizrul the Slavener", 60, 142826, 1},
			{"boss", 0.340, 0.660, 9236, "Ghok Bashguud <Bloodaxe Champion>", 59, 142826, 2},
		},
		[6] = {
			{"level", 0.400, 0.595, 5},
			{"boss", 0.570, 0.600, 9568, "Overlord Wyrmthalak", 60, 142826, 1},
		},
	},
	["maraudon"] = {
		[1] = {
			{"entrance", 0.768, 0.657},
			{"level", 0.145, 0.570, 2},
			{"entrance", 0.622, 0.281},
			{"boss", 0.348, 0.107, 13282, "Noxxion", 48, 11172, 1},
			{"boss", 0.162, 0.340, 12258, "Razorlash", 48, 12389, 1},
			{"boss", 0.377, 0.694, 12236, "Lord Vyletongue", 47, 12334, 1},
			{"boss", 0.246, 0.874, 12237, "Meshlok the Harvester", 48, 9014, 2},
		},
		[2] = {
			{"level", 0.295, 0.040, 1, true},
			{"boss", 0.245, 0.144, 12225, "Celebras the Cursed", 49, 12350, 1},
			{"boss", 0.406, 0.482, 12203, "Landslide", 50, 12293, 1},
			{"boss", 0.484, 0.686, 13601, "Tinkerer Gizlock", 50, 7125, 1},
			{"boss", 0.333, 0.771, 13596, "Rotgrip", 50, 13589, 1},
			{"boss", 0.242, 0.784, 12201, "Princess Theradras", 51, 12292, 1},
		},
	},
	["ragefire_chasm"] = {
		[1] = {
			{"entrance", 0.611, 0.072},
			{"boss", 0.564, 0.372, 11517, "Oggleflint <Ragefire Chieftain>", 16, 11611, 1},
			{"boss", 0.406, 0.574, 11520, "Taragaman the Hungerer", 16, 7970, 1},
			{"boss", 0.338, 0.840, 11518, "Jergosh the Invoker", 16, 11429, 1},
			{"boss", 0.422, 0.857, 11519, "Bazzalan", 16, 2007, 1},
		},
	},
	["razorfen_downs"] = {
		[1] = {
			{"entrance", 0.237, 0.190},
			{"boss", 0.470, 0.200, 7356, "Plaguemaw the Rotting", 40, 6124, 1},
			{"boss", 0.857, 0.465, 7357, "Mordresh Fire Eye", 39, 8055, 1},
			{"boss", 0.350, 0.670, 8567, "Glutton", 40, 7864, 1},
			{"boss", 0.529, 0.672, 7354, "Ragglesnout", 40, 11382, 1},
			{"boss", 0.443, 0.596, 7358, "Amnennar the Coldbringer", 41, 7971, 1},
			{"boss", 0.590, 0.339, 7355, "Tuten'kash", 40, 7845, 1},
		},
	},
	["razorfen_kraul"] = {
		[1] = {
			{"entrance", 0.715, 0.837},
			{"boss", 0.810, 0.510, 6168, "Roogug", 28, 6110, 1},
			{"boss", 0.865, 0.410, 4424, "Aggem Thorncurse <Death's Head Prophet>", 30, 6097, 1},
			{"boss", 0.570, 0.300, 4428, "Death Speaker Jargba <Death's Head Captain>", 30, 4644, 1},
			{"boss", 0.215, 0.300, 4420, "Overlord Ramtusk", 32, 4652, 1},
			{"boss", 0.112, 0.724, 4422, "Agathelos the Raging", 33, 2450, 1},
			{"boss", 0.110, 0.303, 4425, "Blind Hunter", 32, 4735, 2},
			{"boss", 0.080, 0.690, 4421, "Charlga Razorflank <The Crone>", 33, 4642, 1},
			{"boss", 0.494, 0.471, 4842, "Earthcaller Halmgar", 32, 6102, 2},
		},
	},
	["ruins_of_lordaeron"] = {
		[1] = {
			{"entrance", 0.612, 0.216},
			{"boss", 0.704, 0.389, 250483, "Witherfang", 17, 144189, 1},
			{"boss", 0.606, 0.696, 250660, "The Baron", 17, 144188, 1},
			{"boss", 0.382, 0.670, 256035, "Viktor the Vile", 19, 139455, 1},
			{"boss", 0.406, 0.534, 250631, "The Abandoned", 18, 138667, 1},
			{"boss", 0.424, 0.385, 256097, "Bjork", 19, 144170, 1},
			{"boss", 0.463, 0.623, 250657, "Rath'mael", 20, 144175, 1},
			{"boss", 0.433, 0.269, 255699, "Lordaeron Captain", 19, 139050, 2},
			{"item", 0.347, 0.207, 275521},
			{"item", 0.376, 0.493, 275521},
			{"item", 0.433, 0.290, 275521},
			{"item", 0.566, 0.596, 275521},
			{"item", 0.591, 0.680, 280438},
			{"item", 0.671, 0.493, 275521},
		},
	},
	["scarlet_armory"] = {
		[3] = {
			{"entrance", 0.610, 0.955},
			{"boss", 0.785, 0.103, 3975, "Herod <The Scarlet Champion>", 40, 2041, 1},
		},
	},
	["scarlet_cathedral"] = {
		[4] = {
			{"entrance", 0.623, 0.920},
			{"boss", 0.487, 0.280, 3976, "Scarlet Commander Mograine", 42, 2042, 1},
			{"boss", 0.493, 0.160, 3977, "High Inquisitor Whitemane", 42, 2043, 1},
			{"boss", 0.559, 0.243, 4542, "High Inquisitor Fairbanks", 40, 2605, 1},
		},
	},
	["scarlet_graveyard"] = {
		[1] = {
			{"entrance", 0.840, 0.830},
			{"boss", 0.721, 0.593, 3983, "Interrogator Vishas", 32, 2044, 1},
			{"boss", 0.250, 0.560, 4543, "Bloodmage Thalnos", 34, 11396, 1},
			{"boss", 0.325, 0.660, 6490, "Azshir the Sleepless", 33, 5534, 2},
			{"boss", 0.400, 0.460, 6488, "Fallen Champion", 33, 5230, 2},
			{"boss", 0.400, 0.660, 6489, "Ironspine", 33, 5231, 2},
		},
	},
	["scarlet_library"] = {
		[2] = {
			{"entrance", 0.130, 0.248},
			{"boss", 0.300, 0.850, 3974, "Houndmaster Loksey", 34, 2040, 1},
			{"boss", 0.835, 0.740, 6487, "Arcanist Doan", 37, 5266, 1},
		},
	},
	["scholomance"] = {  -- [seq] floors assumed to follow source IDs in order; verify in-game
		[1] = {
			{"entrance", 0.390, 0.652},
			{"level", 0.666, 0.322, 2},
		},
		[2] = {
			{"level", 0.618, 0.293, 1, true},
			{"level", 0.288, 0.322, 3},
			{"level", 0.293, 0.844, 3},
			{"level", 0.397, 0.891, 4},
			{"level", 0.636, 0.533, 3},
			{"boss", 0.441, 0.634, 10433, "Marduk Blackpool", 60, nil, 1},
			{"boss", 0.486, 0.636, 10432, "Vectus", 60, nil, 1},
			{"boss", 0.492, 0.098, 10506, "Kirtonos the Herald", 60, nil, 2},
		},
		[3] = {
			{"level", 0.283, 0.166, 2, true},
			{"level", 0.351, 0.801, 2, true},
			{"level", 0.580, 0.623, 2, true},
			{"level", 0.706, 0.458, 4},
			{"boss", 0.311, 0.640, 11622, "Rattlegore", 60, nil, 1},
			{"boss", 0.536, 0.141, 10503, "Jandice Barov", 60, nil, 1},
			{"boss", 0.720, 0.221, 10901, "Lorekeeper Polkelt", 60, nil, 1},
			{"boss", 0.885, 0.454, 11261, "Doctor Theolen Krastinov <The Butcher>", 60, nil, 1},
			{"boss", 0.723, 0.702, 10505, "Instructor Malicia", 60, nil, 1},
		},
		[4] = {
			{"level", 0.648, 0.293, 3, true},
			{"level", 0.479, 0.553, 2, true},
			{"boss", 0.406, 0.884, 10508, "Ras Frostwhisper", 62, 7919, 1},
			{"boss", 0.666, 0.147, 10502, "Lady Illucia Barov", 60, nil, 1},
			{"boss", 0.785, 0.289, 10504, "Lord Alexei Barov", 60, nil, 1},
			{"boss", 0.669, 0.479, 10507, "The Ravenian", 60, nil, 1},
			{"boss", 0.671, 0.296, 1853, "Darkmaster Gandling", 61, nil, 1},
		},
	},
	["shadowfang_keep"] = {  -- [seq] floors assumed to follow source IDs in order; verify in-game
		[1] = {
			{"entrance", 0.705, 0.606},
			{"level", 0.367, 0.392, 2},
			{"level", 0.148, 0.866, 2},
			{"level", 0.355, 0.666, 7, true},
			{"boss", 0.650, 0.715, 3914, "Rethilgore <The Cell Keeper>", 20, 524, 1},
			{"boss", 0.278, 0.601, 4278, "Commander Springvale", 24, 3223, 1},
		},
		[2] = {
			{"level", 0.593, 0.121, 1, true},
			{"level", 0.273, 0.881, 1, true},
			{"boss", 0.301, 0.762, 3887, "Baron Silverlaine", 24, 3222, 1},
			{"boss", 0.472, 0.277, 3886, "Razorclaw the Butcher", 22, 524, 1},
		},
		[3] = {
			{"level", 0.516, 0.904, 7, true},
			{"level", 0.533, 0.600, 4, true},
		},
		[4] = {
			{"level", 0.442, 0.749, 5, true},
			{"level", 0.526, 0.872, 3},
			{"boss", 0.544, 0.537, 4274, "Fenrus the Devourer", 25, 2352, 1},
		},
		[5] = {
			{"level", 0.437, 0.743, 6, true},
			{"level", 0.490, 0.780, 4},
		},
		[6] = {
			{"level", 0.420, 0.842, 5},
			{"boss", 0.553, 0.627, 3927, "Wolf Master Nandos", 25, 11179, 1},
			{"boss", 0.639, 0.200, 4275, "Archmage Arugal", 26, 2353, 1},
		},
		[7] = {
			{"level", 0.239, 0.745, 1},
			{"level", 0.436, 0.331, 3, true},
			{"boss", 0.595, 0.820, 4279, "Odo the Blindwatcher", 24, 522, 1},
			{"boss", 0.690, 0.770, 3872, "Deathsworn Captain", 25, 3224, 2},
		},
	},
	["shapers_terrace"] = {  -- placeholder, no pin data yet
		[1] = {},
	},
	["stockade"] = {
		[1] = {
			{"entrance", 0.500, 0.815},
			{"boss", 0.440, 0.446, 1696, "Targorr the Dread", 24, 517, 1},
			{"boss", 0.691, 0.300, 1666, "Kam Deepfury", 27, 825, 1},
			{"boss", 0.780, 0.454, 1717, "Hamhock", 28, 3250, 1},
			{"boss", 0.745, 0.562, 1716, "Bazil Thredd", 29, 1621, 1},
			{"boss", 0.213, 0.260, 1663, "Dextren Ward", 26, 2149, 1},
			{"boss", 0.497, 0.222, 1720, "Bruegal Ironknuckle", 26, 2142, 2},
		},
	},
	["stratholme"] = {
		[1] = {
			{"entrance", 0.640, 0.880},
			{"boss", 0.392, 0.287, 10808, "Timmy the Cruel", 58, 571, 2},
			{"entrance", 0.686, 0.880},
			{"level", 0.900, 0.330, 2, true},
			{"boss", 0.815, 0.438, 10393, "Skul", 58, 2606, 2},
			{"boss", 0.847, 0.454, 10558, "Hearthsinger Forresten", 57, 10482, 2},
			{"boss", 0.729, 0.193, 10516, "The Unforgiven", 57, 10771, 1},
			{"boss", 0.304, 0.400, 11032, "Malor the Zealous", 60, 10458, 1},
			{"boss", 0.036, 0.501, 10997, "Cannon Master Willey", 60, 10674, 1},
			{"boss", 0.271, 0.751, 10811, "Archivist Galford", 60, 10544, 1},
			{"boss", 0.188, 0.837, 10813, "Balnazzar", 62, 10691, 1},
		},
		[2] = {
			{"level", 0.355, 0.390, 1},
			{"level", 0.570, 0.770, 1},
			{"boss", 0.649, 0.489, 10809, "Stonespine", 60, 7856, 2},
			{"boss", 0.750, 0.468, 10436, "Baroness Anastari", 59, 10698, 1},
			{"boss", 0.564, 0.469, 10437, "Nerub'enkan", 60, 9793, 1},
			{"boss", 0.682, 0.199, 10438, "Maleki the Pallid", 61, 10546, 1},
			{"boss", 0.644, 0.752, 10435, "Magistrate Barthilas", 58, 10433, 1},
			{"boss", 0.372, 0.199, 10440, "Baron Rivendare", 62, 10729, 1},
			{"boss", 0.455, 0.200, 10439, "Ramstein the Gorger", 61, 12818, 1},
		},
	},
	["sunken_temple"] = {
		[1] = {
			{"level", 0.600, 0.150, 2},
			{"boss", 0.525, 0.450, 5721, "Dreamscythe", 53, 7553, 1},
			{"boss", 0.470, 0.450, 5720, "Weaver", 51, 6375, 1},
			{"boss", 0.760, 0.370, 5710, "Jammal'an the Prophet", 54, 6708, 1},
			{"boss", 0.767, 0.361, 5711, "Ogom the Wretched", 53, 6709, 1},
			{"boss", 0.491, 0.845, 5719, "Morphaz", 52, 7975, 1},
			{"boss", 0.448, 0.851, 5722, "Hazzas", 53, 9584, 1},
			{"boss", 0.686, 0.874, 5709, "Shade of Eranikus", 55, 7806, 1},
			{"boss", 0.240, 0.457, 8443, "Avatar of Hakkar", 49, 8053, 1},
		},
		[2] = {
			{"entrance", 0.500, 0.250},
			{"level", 0.700, 0.200, 1},
			{"level", 0.305, 0.200, 3},
			{"level", 0.290, 0.450, 5},
			{"level", 0.745, 0.450, 5},
			{"level", 0.300, 0.490, 4},
			{"level", 0.700, 0.500, 4},
		},
		[3] = {
			{"level", 0.390, 0.310, 2},
			{"boss", 0.501, 0.785, 8580, "Atal'alarion <Guardian of the Idol>", 50, 7873, 1},
		},
		[4] = {
			{"level", 0.380, 0.175, 2},
			{"level", 0.590, 0.145, 2},
			{"level", 0.420, 0.748, 5},
			{"level", 0.630, 0.725, 5},
		},
		[5] = {
			{"level", 0.315, 0.125, 2},
			{"level", 0.660, 0.125, 2},
			{"level", 0.330, 0.930, 4},
			{"level", 0.690, 0.920, 4},
			{"boss", 0.415, 0.700, 5713, "Gasher", 51, 6698, 1},
			{"boss", 0.585, 0.700, 5714, "Loro", 51, 6700, 1},
			{"boss", 0.335, 0.500, 5715, "Hukku", 52, 6702, 1},
			{"boss", 0.655, 0.500, 5712, "Zolo", 51, 6699, 1},
			{"boss", 0.415, 0.275, 5717, "Mijan", 52, 6707, 1},
			{"boss", 0.585, 0.275, 5716, "Zul'Lor", 52, 6701, 1},
		},
	},
	["the_drowned_city"] = {  -- placeholder, no pin data yet
		[1] = {},
	},
	["uldaman"] = {
		[1] = {
			{"entrance", 0.285, 0.692},
			{"level", 0.485, 0.210, 2},
			{"entrance", 0.680, 0.725},
			{"boss", 0.541, 0.722, 6910, "Revelosh", 40, 5945, 1},
			{"boss", 0.585, 0.910, 6906, "Baelog / Eric \"The Swift\" / Olaf", 41, 5710, 1},
			{"boss", 0.474, 0.407, 7206, "Ancient Stone Keeper", 44, 10798, 1},
			{"boss", 0.258, 0.360, 7291, "Galgann Firehammer", 45, 6059, 1},
			{"boss", 0.212, 0.248, 4854, "Grimlok <Stonevault Chieftain>", 45, 11165, 1},
			{"boss", 0.360, 0.730, 7228, "Ironaya", 40, 6089, 1},
		},
		[2] = {
			{"level", 0.645, 0.410, 1, true},
			{"boss", 0.554, 0.506, 2748, "Archaedas <Ancient Stone Watcher>", 47, 5988, 1},
		},
	},
	["upper_blackrock_spire"] = {  -- placeholder, no pin data yet
		[7] = {
			{"level", 0.285, 0.395, 8},
			{"boss", 0.335, 0.245, 10509, "Jed Runewatcher <Blackhand Legion>", 59, 4313, 2},
			{"boss", 0.290, 0.250, 10899, "Goraluk Anvilcrack <Blackhand Legion Armorsmith>", 61, 4313, 2},
			{"boss", 0.485, 0.245, 10429, "Warchief Rend Blackhand", 63, 4313, 1},
			{"boss", 0.640, 0.315, 10430, "The Beast", 63, 276, 1},
			{"boss", 0.350, 0.490, 10363, "General Drakkisath", 63, 4313, 1},
},
		[8] = {
			{"level", 0.300, 0.135, 9},
			{"level", 0.285, 0.395, 7},
			{"boss", 0.300, 0.265, 9816, "Pyroguard Emberseer", 63, 276, 1},
			{"boss", 0.378, 0.378, 10264, "Solakar Flamewreath", 60, 4313, 2},
		},
		[9] = {
			{"entrance", 0.370, 0.315},
			{"level", 0.300, 0.135, 8},
		},
	},
	["wailing_caverns_instance"] = {
		[1] = {
			{"entrance", 0.463, 0.590},
			{"boss", 0.400, 0.271, 3671, "Lady Anacondra <Fanglord>", 20, 4313, 1},
			{"boss", 0.300, 0.300, 3671, "Lady Anacondra <Fanglord>", 20, 4313, 1},
			{"boss", 0.310, 0.430, 3671, "Lady Anacondra <Fanglord>", 20, 4313, 1},
			{"boss", 0.460, 0.440, 3671, "Lady Anacondra <Fanglord>", 20, 4313, 1},
			{"boss", 0.156, 0.585, 3669, "Lord Cobrahn <Fanglord>", 20, 4213, 1},
			{"boss", 0.418, 0.356, 3653, "Kresh", 20, 5126, 1},
			{"boss", 0.856, 0.299, 3670, "Lord Pythas <Fanglord>", 21, 4214, 1},
			{"boss", 0.924, 0.782, 3674, "Skum", 21, 4203, 1},
			{"boss", 0.613, 0.537, 3673, "Lord Serpentis <Fanglord>", 21, 4215, 1},
			{"boss", 0.555, 0.475, 5775, "Verdan the Everliving", 21, 4256, 1},
			{"boss", 0.642, 0.410, 5912, "Deviate Faerie Dragon", 20, 1267, 2},
			{"boss", 0.338, 0.133, 3654, "Mutanus the Devourer", 22, 4088, 1},
			{"boss", 0.920, 0.537, 5912, "Deviate Faerie Dragon", 20, 1267, 2},
		},
	},
	["zul_farrak"] = {
		[1] = {
			{"entrance", 0.566, 0.901},
			{"boss", 0.690, 0.256, 8127, "Antu'sul <Overseer of Sul>", 48, 7353, 1},
			{"boss", 0.554, 0.296, 7272, "Theka the Martyr", 46, 6696, 1},
			{"boss", 0.440, 0.160, 7271, "Witch Doctor Zum'rah", 46, 6434, 1},
			{"boss", 0.255, 0.130, 7604, "Sergeant Bly", 45, 6433, 1},
			{"boss", 0.289, 0.403, 7795, "Hydromancer Velratha", 46, 6685, 1},
			{"boss", 0.420, 0.360, 7797, "Ruuzlu", 46, 6687, 1},
			{"boss", 0.440, 0.330, 7267, "Chief Ukorz Sandscalp", 48, 6439, 1},
			{"boss", 0.538, 0.373, 10082, "Zerillis", 45, 9293, 2},
			{"boss", 0.463, 0.578, 10080, "Sandarr Dunereaver", 45, 9291, 2},
			{"boss", 0.317, 0.460, 10081, "Dustwraith", 45, 9292, 2},
			{"boss", 0.235, 0.183, 7796, "Nekrum Gutchewer", 46, 6690, 1},
			{"boss", 0.334, 0.170, 7275, "Shadowpriest Sezz'ziz", 47, 6441, 1},
			{"boss", 0.305, 0.400, 7273, "Gahz'rilla", 46, 7271, 1},
		},
	},

	-- Raids
	["barrow_deeps"] = {},  -- placeholder, not in DUNGEON_MAPS yet (floors TBD)
	["blackwing_lair"] = {  -- [seq] floors assumed to follow source IDs in order; verify in-game
		[1] = {
			{"entrance", 0.527, 0.836, "raid"},
			{"level", 0.435, 0.300, 2, true},
			{"level", 0.360, 0.130, 2, true},
		},
		[2] = {
			{"level", 0.525, 0.320, 1},
			{"level", 0.463, 0.198, 1},
		},
	},
	["hyjal_summit"] = {},  -- placeholder, not in DUNGEON_MAPS yet (floors TBD)
	["molten_core"] = {
		[1] = {
			{"entrance", 0.264, 0.226, "raid"},
			{"boss", 0.660, 0.370, 12118, "Lucifron", 9999, 13031, 3},
			{"boss", 0.695, 0.230, 11982, "Magmadar", 9999, 10193, 3},
			{"boss", 0.350, 0.490, 12259, "Gehennas", 9999, 13030, 3},
			{"boss", 0.315, 0.690, 12057, "Garr", 9999, 12110, 3},
			{"boss", 0.550, 0.850, 12264, "Shazzrah", 9999, 13032, 3},
			{"boss", 0.535, 0.750, 12056, "Baron Geddon", 9999, 12129, 3},
			{"boss", 0.810, 0.820, 12098, "Sulfuron Harbinger", 9999, 13030, 3},
			{"boss", 0.685, 0.570, 11988, "Golemagg the Incinerator", 9999, 11986, 3},
			{"boss", 0.840, 0.660, 12018, "Majordomo Executus", 9999, 12029, 3},
			{"boss", 0.548, 0.540, 11502, "Ragnaros", 9999, 11121, 3},
		},
	},
	["onyxias_lair"] = {
		[1] = {
			{"entrance", 0.341, 0.205, "raid"},
			{"boss", 0.670, 0.310, 10184, "Onyxia", 9999, 8570, 3},
		},
	},
	["ruins_of_ahnqiraj"] = {
		[1] = {
			{"entrance", 0.595, 0.108, "raid"},
			{"boss", 0.544, 0.348, 15348, "Kurinaxx", 9999, nil, 3},
			{"boss", 0.568, 0.479, 15341, "General Rajaxx", 9999, nil, 3},
			{"boss", 0.680, 0.607, 15370, "Buru the Gorger", 9999, nil, 3},
			{"boss", 0.601, 0.879, 15369, "Ayamiss the Hunter", 9999, nil, 3},
			{"boss", 0.320, 0.358, 15340, "Moam", 9999, nil, 3},
			{"boss", 0.419, 0.679, 15339, "Ossirian the Unscarred", 9999, nil, 3},
		},
	},
	["temple_of_ahnqiraj"] = {
		[1] = {
			{"level", 0.343, 0.452, 2, true},
			{"boss", 0.280, 0.491, 15511, "Lord Kri / Princess Yauj / Vem", 9999, nil, 2},
			{"boss", 0.442, 0.333, 15516, "Battleguard Sartura", 9999, nil, 3},
			{"boss", 0.619, 0.225, 15510, "Fankriss the Unyielding", 9999, nil, 3},
			{"boss", 0.718, 0.182, 15299, "Viscidus", 9999, nil, 2},
			{"boss", 0.430, 0.502, 15509, "Princess Huhuran", 9999, nil, 3},
			{"boss", 0.618, 0.642, 15276, "Emperor Vek'lor", 9999, nil, 3},
			{"boss", 0.628, 0.737, 15275, "Emperor Vek'nilash", 9999, nil, 3},
			{"boss", 0.299, 0.811, 15517, "Ouro", 9999, nil, 2},
		},
		[2] = {
			{"entrance", 0.522, 0.265, "raid"},
			{"boss", 0.454, 0.510, 15263, "The Prophet Skeram", 9999, nil, 3},
			{"level", 0.488, 0.636, 1},
			{"level", 0.590, 0.687, 3},
		},
		[3] = {
			{"level", 0.586, 0.419, 1, true},
			{"boss", 0.568, 0.630, 15727, "C'Thun", 9999, nil, 3},
		},
	},
	["zul_gurub"] = {
		[1] = {
			{"entrance", 0.290, 0.490, "raid"},
			{"boss", 0.390, 0.730, 14517, "High Priestess Jeklik", 9999, 15219, 3},
			{"boss", 0.515, 0.540, 14507, "High Priest Venoxis", 9999, 15217, 3},
			{"boss", 0.470, 0.770, 14510, "High Priestess Mar'li", 9999, 15220, 3},
			{"boss", 0.625, 0.680, 11382, "Bloodlord Mandokir", 9999, 11288, 3},
			{"boss", 0.600, 0.462, 15082, "Gri'lek / Hazza'rah / Renataki / Wushoolay", 9999, 8390, 3},
			{"boss", 0.535, 0.320, 15114, "Gahz'ranka", 9999, 15288, 3},
			{"boss", 0.620, 0.340, 14509, "High Priest Thekal", 9999, 15216, 3},
			{"boss", 0.475, 0.190, 14515, "High Priestess Arlokk", 9999, 15218, 3},
			{"boss", 0.310, 0.240, 11380, "Jin'do the Hexxer", 9999, 11311, 3},
			{"boss", 0.505, 0.390, 14834, "Hakkar", 9999, 15295, 3},
		},
	},
}
