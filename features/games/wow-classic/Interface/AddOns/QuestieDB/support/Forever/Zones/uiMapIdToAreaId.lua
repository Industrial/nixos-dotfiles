-- Manually completed Forever handoff for build 1.60.1.69893.
-- Regenerating with generate.py will overwrite these additions.
-- See docs/forever-data.md and docs/forever-map-override-audit.md.
-- Local consumer compatibility additions must survive any future exporter refresh.

local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

-- Canonical synthetic continent/world areas, matching the forward aliases.
---@type string
ZoneDB.private.uiMapIdToAreaIdOverride = [[return {
    [947] = 10089, -- Azeroth
    [1414] = 10073, -- Kalimdor
    [1415] = 10074, -- Eastern Kingdoms

    -- Legacy consumer pre-entrance lookup only, NOT native Forever floor maps.
    -- These 27 dungeon areas and 13 synthetic aliases occur in entity location fields.
    -- Retire after the consumer resolves instances before indexing by UiMapID.
    [310] = 209, -- Referenced dungeon area
    [301] = 491, -- Referenced dungeon area
    [225] = 717, -- Referenced dungeon area
    [279] = 718, -- Referenced dungeon area
    [221] = 719, -- Referenced dungeon area
    [226] = 721, -- Referenced dungeon area
    [300] = 722, -- Referenced dungeon area
    [302] = 796, -- Referenced dungeon area
    [219] = 1176, -- Referenced dungeon area
    [230] = 1337, -- Referenced dungeon area
    [220] = 1477, -- Referenced dungeon area
    [291] = 1581, -- Referenced dungeon area
    [253] = 1583, -- Referenced dungeon area
    [242] = 1584, -- Referenced dungeon area
    [243] = 1585, -- Referenced dungeon area
    [233] = 1977, -- Referenced dungeon area
    [317] = 2017, -- Referenced dungeon area
    [306] = 2057, -- Referenced dungeon area
    [280] = 2100, -- Referenced dungeon area
    [248] = 2159, -- Referenced dungeon area
    [213] = 2437, -- Referenced dungeon area
    [234] = 2557, -- Referenced dungeon area
    [287] = 2677, -- Referenced dungeon area
    [232] = 2717, -- Referenced dungeon area
    [320] = 3428, -- Referenced dungeon area
    [247] = 3429, -- Referenced dungeon area
    [166] = 3456, -- Referenced dungeon area
    [281] = 10000, -- Referenced synthetic dungeon alias
    [255] = 10007, -- Referenced synthetic dungeon alias
    [307] = 10011, -- Referenced synthetic dungeon alias
    [308] = 10012, -- Referenced synthetic dungeon alias
    [222] = 10020, -- Referenced synthetic dungeon alias
    [235] = 10022, -- Referenced synthetic dungeon alias
    [236] = 10023, -- Referenced synthetic dungeon alias
    [237] = 10024, -- Referenced synthetic dungeon alias
    [238] = 10025, -- Referenced synthetic dungeon alias
    [239] = 10026, -- Referenced synthetic dungeon alias
    [240] = 10027, -- Referenced synthetic dungeon alias
    [227] = 10030, -- Referenced synthetic dungeon alias
    [229] = 10032, -- Referenced synthetic dungeon alias
}]]

-- Keep the 54 direct AreaIDs canonical; do not invert the many-to-one descendant lookup.
---@type string
ZoneDB.private.uiMapIdToAreaId = [[return {
    [1411] = 14, -- Durotar
    [1412] = 215, -- Mulgore
    [1413] = 17, -- The Barrens
    [1416] = 36, -- Alterac Mountains
    [1417] = 45, -- Arathi Highlands
    [1418] = 3, -- Badlands
    [1419] = 4, -- Blasted Lands
    [1420] = 85, -- Tirisfal Glades
    [1421] = 130, -- Silverpine Forest
    [1422] = 28, -- Western Plaguelands
    [1423] = 139, -- Eastern Plaguelands
    [1424] = 267, -- Hillsbrad Foothills
    [1425] = 47, -- The Hinterlands
    [1426] = 1, -- Dun Morogh
    [1427] = 51, -- Searing Gorge
    [1428] = 46, -- Burning Steppes
    [1429] = 12, -- Elwynn Forest
    [1430] = 41, -- Deadwind Pass
    [1431] = 10, -- Duskwood
    [1432] = 38, -- Loch Modan
    [1433] = 44, -- Redridge Mountains
    [1434] = 33, -- Stranglethorn Vale
    [1435] = 8, -- Swamp of Sorrows
    [1436] = 40, -- Westfall
    [1437] = 11, -- Wetlands
    [1438] = 141, -- Teldrassil
    [1439] = 148, -- Darkshore
    [1440] = 331, -- Ashenvale
    [1441] = 400, -- Thousand Needles
    [1442] = 406, -- Stonetalon Mountains
    [1443] = 405, -- Desolace
    [1444] = 357, -- Feralas
    [1445] = 15, -- Dustwallow Marsh
    [1446] = 440, -- Tanaris
    [1447] = 16, -- Azshara
    [1448] = 361, -- Felwood
    [1449] = 490, -- Un'Goro Crater
    [1450] = 493, -- Moonglade
    [1451] = 1377, -- Silithus
    [1452] = 618, -- Winterspring
    [1453] = 1519, -- Stormwind City
    [1454] = 1637, -- Orgrimmar
    [1455] = 1537, -- Ironforge
    [1456] = 1638, -- Thunder Bluff
    [1457] = 1657, -- Darnassus
    [1458] = 1497, -- Undercity
    [1459] = 2597, -- Alterac Valley
    [1460] = 3277, -- Warsong Gulch
    [1461] = 3358, -- Arathi Basin
    [2482] = 616, -- Mount Hyjal
    [2521] = 16593, -- Zephras Isle
    [2524] = 16606, -- Darkspear Islands
    [2548] = 16591, -- Riverglades
    [2652] = 16651, -- Shen'dralas
}]]
