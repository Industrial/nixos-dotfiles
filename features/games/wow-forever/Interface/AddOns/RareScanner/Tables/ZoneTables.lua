
-------------------------------------------------------------------------------
-- AddOn namespace.
-------------------------------------------------------------------------------
local FOLDER_NAME, private = ...

private.CONTINENT_ZONE_IDS = {
	[905] = { zonefilter = true, npcfilter = true, id = 9, zones = {830,882,885} }; --Argus
	[619] = { zonefilter = true, npcfilter = true, id = 8, zones = {627,630,646,790,650,634,680,641,649,650,750} }; --Broken Isles
	[572] = { zonefilter = true, npcfilter = true, id = 7, zones = {525,534,535,539,542,543,550,582,588,590} }; --Draenor
	[13] = { zonefilter = true, npcfilter = true, id = 2, zones = {14,15,17,18,21,22,23,25,26,27,32,36,37,47,48,49,50,51,52,56,76,84,87,90,94,95,201,203,204,205,210,217,241,425,465,469,943,1470,2404} }; --Eastern Kingdoms
	[12] = { zonefilter = true, npcfilter = true, id = 1, zones = {1,7,10,57,62,63,64,65,66,69,70,71,76,77,78,80,81,83,85,88,97,103,106,198,199,249,327,338,1332,1469,2403,1527,1571} }; --Kalimdor
	[113] = { zonefilter = true, npcfilter = true, id = 4, zones = {114,115,116,117,118,119,120,121,126,127} }; --Northrend
	[424] = { zonefilter = true, npcfilter = true, id = 6, zones = {371,376,379,388,390,418,422,433,507,504,554,1530,1570} }; --Pandaria
	[101] = { zonefilter = true, npcfilter = true, id = 3, zones = {100,102,104,105,107,108,109} }; --Outland
	[948] = { zonefilter = true, npcfilter = true, id = 5, zones = {207} }; --The Maelstrom
	[876] = { zonefilter = true, npcfilter = true, id = 10, zones = {895,896,942,1161,1462} }; --Kul Tiras
	[875] = { zonefilter = true, npcfilter = true, id = 11, zones = {862,863,864,1165} }; --Zandalar
	[1355] = { zonefilter = true, npcfilter = true, id = 12, zones = {1355} }; --Nazjatar
	[1550] = { zonefilter = true, npcfilter = true, id = 13, zones = {1409,1525,1533,1536,1543,1565,1618,1961,1970,2030} }; --Shadowlands
	[1978] = { zonefilter = true, npcfilter = true, id = 14, zones = {2112,2118,2022,2023,2024,2025,2085,2107,2133,2151,2199,2200,2239,2262} }; --Dragon Isles
	[2274] = { zonefilter = true, npcfilter = true, id = 15, zones = {2213,2216,2248,2215,2216,2214,2255,2339,2346,2369,2371,2472} }; --Khaz Algar
	[2537] = { zonefilter = true, npcfilter = true, id = 16, zones = {2393,2424,2432,2395,2437,2405,2413,2444,2509,2512,2536,2541,2545,2599,2600}, current = { "all" } }; --Quel'Thalas
	[9999] = { zonefilter = true, npcfilter = true, zones = {276,378,628,629,672,734,702,695,747,739} }; --Class Halls
	[9998] = { zonefilter = true, npcfilter = true, zones = {407}, current = { "all" } }; --Darkmoon Island
	[9997] = { zonefilter = true, npcfilter = true, zones = {35,219,229,237,243,251,274,279,280,301,302,306,316,317,318,616,677,703,706,713,731,733,749,845,897,903,974,1004,1015,1041,1490,1663,1666,1675,1669,1674,1677,1683,1692,2093,2303,2579,2580,2582} }; --Dungeons or scenarios
	[9996] = { zonefilter = true, npcfilter = true, zones = {366,508,764,850,909,2047,2166,2406} }; --Raids
	[9995] = { zonefilter = false, npcfilter = true, zones = {0} }; --Unknown
	[9994] = { zonefilter = true, npcfilter = true, zones = {981,1022,1032,1033,1034,1035,1036,1037,1336,1337,1501,1502} }; --Expedition islands
	[9993] = { zonefilter = true, npcfilter = true, zones = {2302,2310,2312,2347,2249,2250,2251,2259,2269,2277,2301,2302,2310,2347,2348,2396,2420,2453,2502,2505,2506,2510,2504,2525,2528,2522,2535,2545,2547,2585,2594,2633,2635,2647} }; --Delves
}

private.SUBZONES_IDS = {
	[125] = {126}; --Dalaran (old)
	[764] = {765,766,767,768,769,770,771,772}; --The Nighthold
	[850] = {851,852,853,854,855,856}; --Tomb of Sargeras
	[677] = {678,679,710,711,712}; --Vault of the Wardens
	[703] = {704,705,829}; --Halls of Valor
	[706] = {707,708}; --Maw of Souls
	[845] = {846,847,848,849}; --Cathedral of Eternal Night
	[306] = {307,308,309,476,477,478,479}; --Scholomance
	[508] = {509,510,511,512,513,514,515}; --Throne of Thunder
	[302] = {303,304,305,314}; --Scarlet Monastery
	[616] = {617,618}; --Upper Blackrock Spire
	[749] = {798}; --The Arcway
	[680] = {682,683,684,685,686}; --Suramar (Legion)
	[650] = {651,652,654,655,657,658,659,750}; --Highmountain (Legion)
	[641] = {642}; --Val'Sharah (Legion)
	[634] = {636}; --Stormheim (Legion)
	[630] = {631}; --Azsuna (Legion)
	[407] = {408}; --Darkmoon Island
	[734] = {735}; --Hall of the Guardian (mage class hall)
	[672] = {674,675,719,720,721,879,880,861}; --Mardum, the Shattered Abyss (demon hunter class hall)
	[276] = {725,726,839,948}; --The Heart of Azeroth (shaman class hall)
	[378] = {709}; --The Wandering Isle (monk class hall)
	[71] = {72,73}; --Tanaris minimaps
	[27] = {29,31}; --Dun Morogh minimaps
	[1] = {5}; --Durotar minimaps
	[78] = {79}; --Un'goro crater minimaps
	[37] = {40}; --Elwynn forest minimaps
	[66] = {67}; --Desolace minimaps
	[52] = {55}; --Westfall minimaps
	[237] = {238}; --Diremaul
	[251] = {252, 253, 254, 255}; --Blackrock spire
	[366] = {350,351,352,353,354,355,356,357,358,359,360,361,362,363,364,365}; --Karazhan (Outland raid)
	[7] = {462}; --Mulgore minimaps
	[504] = {505}; --Isle of Thunder
	[554] = {555}; --Timeless Isle
	[390] = {395}; --Valley of Eternal Blossom minimaps
	[32] = {33,35}; --Searing Gorge minimaps
	[543] = {549}; --Gorgrond minimaps
	[535] = {537}; --Talador minimaps
	[627] = {626,628,629}; --Dalaran Legion
	[830] = {833}; --Krokuun minimap
	[942] = {1183}; --Stormsong Valley minimap
	[1015] = {1016,1017,1018,1019}; --Waycrest manor
	[974] = {975,976,977,978,979,980}; --Tol Dagor
	[1041] = {1042}; --The underrot
	[1525] = {1644}; --The ember court
	[1536] = {1649}; --Vault in Maldraxxus
	[1618] = {1619,1620,1621,1623,1624,1627,1628,1629,1630,1631,1632,1635,1636,1641,1645,1656,1705,1712,1716,1720,1721,1736,1749,1751,1752,1753,1754,1757,1758,1759,1760,1761,1762,1763,1764,1765,1766,1767,1768,1769,1770,1771,1772,1773,1774,1776,1777,1778,1779,1780,1781,1782,1783,1784,1785,1786,1787,1788,1789,1791,1792,1793,1794,1795,1796,1797,1798,1799,1800,1801,1802,1803,1804,1805,1806,1807,1808,1809,1810,1811,1812}; --Torghast
	[1663] = {1664,1665}; --Halls of atonement
	[1675] = {1676}; --Sanguine depths
	[1677] = {1678,1679,1680}; --The other side
	[1692] = {1693,1694,1695}; --Spires of Ascension
	[1666] = {1667,1668}; --The necrotic wake
	[1683] = {1684,1685,1686,1687}; --Theater of pain
	[1674] = {1697}; --Plaguefall
	[1970] = {2027,2028,2029,2030,2066}; --Zereth Mortis
	[2047] = {2048,2049,2050,2051,2052,2055,2061}; --Sepulcher of the First Ones
	[2024] = {2132}; -- The Azure Span minimaps
	[2151] = {2100,2101,2102,2154}; --The Forbidden Reach (10.0.7) (Dragonflight)
	[2133] = {2184,2165}; --Zaralek Cavern minimaps (10.1.0) (Dragonflight)
	[2166] = {2167,2168,2169,2170,2171,2172,2173,2174,2211}; --Aberrus, the Shadowed Crucible
	[2025] = {2199,2112}; --Thaldraszus minimaps
	[2200] = {2254}; --Emerald Dream minimaps
	[2255] = {2256,2213,2216}; --Azj-Kahet
	[2213] = {2216}; --City of Threads
	[2248] = {2339}; --Isle of Dorn
	[2369] = {2375}; --Isle Siren
	[2406] = {2406,2407,2408,2409,2411,2428}; --Liberation of Undermine
	[1490] = {1491,1493,1494,1497}; --Operation: Mechagon
	[2420] = {2421,2422,2423}; --Sidestreet Sluice
	[371] = { 372, 373 }; --The jade forest (Pandaria)
	[388] = { 389 }; --Townlong steppes (Pandaria)
	[379] = { 380, 381, 382, 384, 385, 434 }; --Kun lai summit (Pandaria)
	[2371] = { 2477 }; --K'aresh
	[2453] = { 2476, 2454, 2455, 2476 }; --Archival Assault
	[2405] = { 2526, 2444, 2526, 2527,  }; --Archival Assault
	[2413] = { 2576 }; --Harandar (Midnight)
	[2528] = { 2571 }; --Sunkiller Sanctum (Midnight)
	[2599] = { 2618, 2620, 2621 }; --Val (Midnight)
	[2600] = { 2646 }; -- Naigtal (Midnight)
	[2504] = { 2503 }; -- Twilight Crypts (Midnight)
	[2512] = { 2613, 2639, 2642, 2644, 2645 }; --The Coiled Isle (Midnight)
	[2509] = { 2636, 2638 }; --Vaults of Atal'Utek (Midnight)
	[2647] = { 2648 }; --The labyrinth of Kindo'jan (Midnight)
}

private.ZONES_WITHOUT_VIGNETTE = {
	----[zoneId] = { artID };
	[77] = { 82 }; --Felwood
	[10] = { 11 }; --Northern barrens
	[69] = { 74 }; --Feralas
	[210] = { 215 }; --The cape of stranglethorn
	[199] = { 204 }; --Southern barrens
	[62] = { 67 }; --Darkshore
	[47] = { 52 }; --Duskwood
	[15] = { 16 }; --Badlands
	[83] = { 88 }; --Winterspring
	[17] = { 18 }; --Blasted lands
	[52] = { 57 }; --Westfall
	[27] = { 28 }; --Dun morogh
	[7] = { 8 }; --Mulgore
	[84] = { 89 }; --Stormwind city
	[57] = { 62 }; --Teldrassil
	[76] = { 81 }; --Azshara
	[25] = { 26 }; --Hillsbrad foothills
	[66] = { 71 }; --Desolace
	[78] = { 83 }; --Ungoro crater
	[1] = { 2 }; --Durotar
	[469] = { 481 }; --New tinkertown
	[18] = { 19 }; --Tirisfal glades
	[14] = { 15 }; --Arathi highlands
	[26] = { 27 }; --The hinterlands
	[37] = { 41 }; --Elwynn forest
	[81] = { 962,86 }; --Silithus
	[48] = { 53 }; --Loch modan
	[23] = { 24 }; --Eastern plaguelands
	[63] = { 68 }; --Ashenvale
	[65] = { 70 }; --Stonetalon mountains
	[70] = { 498,75 }; --Dustwallow marsh
	[21] = { 22 }; --Silverpine forest
	[64] = { 69 }; --Thousand needles
	[36] = { 37 }; --Burning steppes
	[49] = { 54 }; --Redridge mountains
	[50] = { 55 }; --Northern stranglethorn
	[56] = { 61 }; --Wetlands
	[32] = { 33 }; --Searing gorge
	[22] = { 23 }; --Western plaguelands
	[51] = { 56 }; --Swamp of sorrows
	[71] = { 76 }; --Tanaris
	[80] = { 85 }; --Moonglade
	[465] = { 477 }; --Deathknell
	[327] = { 339 }; --Ahn qiraj the fallen kingdom
	[104] = { 109 }; --Shadowmoon valley
	[109] = { 114 }; --Netherstorm
	[100] = { 105 }; --Hellfire peninsula
	[105] = { 110 }; --Blades edge mountains
	[106] = { 111 }; --Bloodmyst isle
	[102] = { 107 }; --Zangarmarsh
	[108] = { 113 }; --Terokkar forest
	[107] = { 112 }; --Nagrand
	[95] = { 100 }; --Ghostlands
	[94] = { 99 }; --Eversong woods
	[114] = { 119 }; --Borean tundra
	[115] = { 120 }; --Dragonblight
	[116] = { 121 }; --Grizzly hills
	[117] = { 122 }; --Howling fjord
	[118] = { 123 }; --Icecrown
	[119] = { 124 }; --Sholazar basin
	[120] = { 125 }; --The storm peaks
	[121] = { 126 }; --Zul drak
	[125] = { 130 }; --Dalaran
	[126] = { 131 }; --Dalaran (underbelly)
	[127] = { 132 }; --Crystalsong Forest
	[207] = { 212 }; --Deepholm
	[198] = { 203,227 }; --Mount hyjal
	[241] = { 338,252 }; --Twilight highlands
	[205] = { 210 }; --Shimmering expanse
	[204] = { 209 }; --Abyssal depths
	[338] = { 350 }; --Molten front
	[249] = { 260,289 }; --Uldum
	[201] = { 206 }; --Kelp thar forest
	[203] = { 208 }; --Vashj ir
	[73] = { 77 }; --The gaping chasm
	[72] = { 78 }; --The noxious lair
	[29] = { 31 }; --The grizzled den
	[5] = { 7 }; --Skull rock
	[31] = { 30 }; --Golbolar quarry
	[79] = { 84 }; --The slithering scar
	[40] = { 42 }; --Jasperlode mine
	[280] = { 291 }; --Maraudon
	[67] = { 72 }; --Maraudon out1
	[316] = { 328 }; --Shadowfang keep7
	[55] = { 60 }; --Deadmines out
	[229] = { 240 }; --Gnomeregan
	[237] = { 248 }; --Dire maul3
	[238] = { 249 }; --Dire maul4
	[219] = { 230 }; --Zulfarrak
	[251] = { 262 }; --Blackrock spire2
	[252] = { 263 }; --Blackrock spire3
	[253] = { 264 }; --Blackrock spire4
	[255] = { 266 }; --Blackrock spire6
	[279] = { 290 }; --Wailing caverns
	[11] = { 12 }; --Wailing caverns
	[318] = { 330 }; --Stratholme undead
	[317] = { 329 }; --Stratholme human
	[243] = { 254 }; --Blackrock depths2
	[33] = { 34 }; --Searing gorge2
	[35] = { 36 }; --Searing gorge3
	[301] = { 313 }; --Razorfen kraul
	[351] = { 363 }; --Karazhan
	[274] = { 285 }; --Old hillsbrad foothills
	[462] = { 474 }; --Camp Narache
	[425] = { 437 }; --Northshire
	--[2112]  = { 1748 }; --Valdrakken
	[2022] = { 1706 }; --The walking shores
	[2023] = { 1705 }; --Ohn'ahran plains
	[2024] = { 1707 }; --The Azure span
	[2025] = { 1708 }; --Thaldraszus
	--[2085]  = { 1736 }; --The primalist future
	--[2133]  = { 1775 }; --Zaralek cavern
	--[2151]  = { 1781 }; --The forbidden reach
	--[2199]  = { 1805 }; --Tyrhold reservoir
	--[2200]  = { 1806 }; --Emerald dream
}

private.RESETABLE_KILLS_ZONE_IDS = {
	----[zoneId] = { artID or "all"};
	[539] = { "all" }; --Shadowmoon Valley (WOD)
	[550] = { "all" }; --Nagrand (WOD)
	[535] = { "all" }; --Talador (WOD)
	[543] = { "all" }; --Gorgrond (WOD)
	[542] = { "all" }; --Spires of Arak (WOD)
	[525] = { "all" }; --Frostfire ridge (WOD)
	[534] = { "all" }; --Tanaan jungle (WOD)
	[830] = { "all" }; --Krokun (Legion)
	[882] = { "all" }; --Mac-Aree (Legion)
	[885] = { "all" }; --Antoran wastes (Legion)
	[646] = { "all" }; --The broken shore (Legion)
	[630] = { "all" }; -- Azsuna (Legion)
	[641] = { "all" }; -- Val'Sharah (Legion)
	[634] = { "all" }; -- Stormheim (Legion)
	[650] = { "all" }; -- Highmountain (Legion)
	[680] = { "all" }; -- Suramar (Legion)
	[649] = { "all" }; -- Helheim (Legion)
	[81] = { 962 }; --Silithus (Legion, BFA)
	[1355] = { "all" }; --Nazjatar (BFA)
	[1462] = { "all" }; --Mechagon (BFA)
	[1530] = { "all" }; --Valley of eternal blossoms 8.3.0 invassion (BFA)
	[1527] = { "all" }; --Uldum 8.3.0 invassion (BFA)
	[1570] = { "all" }; --Valley of eternal blossoms 8.3.0 horror vision (BFA)
	[1571] = { "all" }; --Uldum 8.3.0 horror vision (BFA)
	[14] = { 1137 }; --Warfront Arathi (BFA)
	[62] = { 1176 }; --Warfront Darkshore (BFA)
	[1533] = { "all" }; --Bastion (Shadowlands)
	[1536] = { "all" }; --Maldraxxus (Shadowlands)
	[1565] = { "all" }; --Ardenweald (Shadowlands)
	[1525] = { "all" }; --Ravendreth (Shadowlands)
	[1543] = { "all" }; --The Maw (Shadowlands)
	[1961] = { "all" }; --Korthia (Shadowlands)
	[1970] = { "all" }; --Zereth Mortis (Shadowlands)
	[2030] = { "all" }; --Zereth Mortis (Nexus of Actualization) (Shadowlands)
	[2022] = { "all" }; --The Walking Shores (Nexus of Actualization) (Shadowlands)
	[2023] = { "all" }; --Ohn'Ahran Plains (Nexus of Actualization) (Shadowlands)
	[2024] = { "all" }; --The Azure Span (Dragonflight)
	[2025] = { "all" }; --Thaldraszus (Dragonflight)
	[2118] = { "all" }; --The Forbidden Reach (evoker zone) (Dragonflight)
	[2026] = { "all" }; --The Forbidden Reach (Dragonflight)
	[2151] = { "all" }; --The Forbidden Reach (10.0.7) (Dragonflight)
	[2133] = { "all" }; --Zaralek Cavern (10.1.0) (Dragonflight)
	[2200] = { "all" }; --Emerald Dream (10.2.0) (Dragonflight)
	[2248] = { "all" }; --Isle of Dorn (The War Within)
	[2215] = { "all" }; --Hallowfall (The War Within)
	[2214] = { "all" }; --The Ringing Deeps (The War Within)
	[2255] = { "all" }; --Azj-Kahet (The War Within)
	[2213] = { "all" }; --Nerub'ar (The War Within)
	[2369] = { "all" }; --Isle Siren (The War Within)
	[2346] = { "all" }; --The undermine (The War Within)
	[2371] = { "all" }; --K'aresh (The War Within)
	[2472] = { "all" }; --Tazavesh (The War Within)
	[2393] = { "all" }; --Silvermoon City (Midnight)
	[2432] = { "all" }; --Isle of Quel'Danas (Midnight)
	[2395] = { "all" }; --Eversong Woods (Midnight)
	[2437] = { "all" }; --Zul'Aman (Midnight)
	[2405] = { "all" }; --Voidstorm (Midnight)
	[2413] = { "all" }; --Harandar (Midnight)
}

private.PERMANENT_KILLS_ZONE_IDS = {
	[525] = { "all" };
	[539] = { "all" };
	[542] = { "all" };
	[543] = { "all" };
	[550] = { "all" };
	[535] = { "all" };
	[625] = { "all" };
	[790] = { "all" };
	[942] = { "all" };
	[895] = { "all" };
	[896] = { "all" };
	[1161] = { "all" };
	[864] = { "all" };
	[863] = { "all" };
	[862] = { "all" };
	[1165] = { "all" };
	[1618] = { "all" };
}

-- Monster emotes
private.MONSTER_EMOTE = {
	-- Mechagon construction projects
	["TR28"] = 153206; --Ol' Big Tusk
	["TR35"] = 150342; --Earthbreaker Gulroc
	["CC61"] = 154701; --Gorged Gear-Cruncher
	["CC73"] = 154739; --Caustic Mechaslime
	["CC88"] = 152113; --The Kleptoboss
	["JD41"] = 153200; --Boilburn
	["JD99"] = 153205; --Gemicide
	-- Lurker of the deeps
	["As the earthen machinery turns, something begins to stir in the nearby lake."] = 220285;
	-- Tka'ktath <Queen's Sweetie>
	["The shadow of a hungering beast moves over the city."] = 216046;
	["La sombra de una bestia hambrienta se mueve sobre la ciudad."] = 216046;
}

-- Relation between mapIDs and MajorFactionIDs
private.MAP_RENOWN_IDS = {
	[2413] = { factionID = 2704, containers = true, npcs = false }; --Hara'ti
	[2576] = { factionID = 2704, containers = true, npcs = false }; --Hara'ti
	[2594] = { factionID = 2792, containers = true, npcs = true }; --Ritual places
}

-- SpellIDs associated to entities
private.SPELL_IDS_ENTITY = {
	-- Patient Treasure
	[1269521] = { id = 540505, isContainer = true, isNpc = false };
	[1235378] = { id = 540505, isContainer = true, isNpc = false };
}