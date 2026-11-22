local ADDON_NAME, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS

FDJ.QUEST_START_MAPS = {
    -- Excavation Site: Wetlands prerequisite quest giver.
    [95663] = { mapID = 1417, x = 0.7454, y = 0.3563, label = "Zaruk — Hammerfall", targetName = "Zaruk", detail = "Start Dragonmaw Rumors here" },

    -- Hall of Thanes quest givers.
    [96394] = { mapID = 1455, x = 0.333, y = 0.481, label = "Afadra Dunwall — top of Old Ironforge", targetName = "Afadra Dunwall", detail = "Top of Old Ironforge, outside the dungeon" },
    [96393] = { mapID = 1426, x = 0.647, y = 0.584, label = "Earthseer Farsen — Gol'Bolar Quarry, Dun Morogh", targetName = "Earthseer Farsen" },
    [96403] = { mapID = 1455, x = 0.435, y = 0.520, label = "Thom Filch — Hall of Thanes portal, Ironforge", targetName = "Thom Filch" },

    -- Ruins of Lordaeron quest givers / entrance.
    [92401] = { mapID = 1421, x = 0.4450, y = 0.4300, label = "Tabitha Heartweaver — The Sepulcher" },
    [92421] = { mapID = 1458, x = 0.5790, y = 0.8950, label = "Morbin Lightbane — Royal Quarter" },
    [95216] = { mapID = 1458, x = 0.4650, y = 0.7160, label = "Theodore Griffs — Apothecarium" },
    [92422] = { mapID = 1420, x = 0.6520, y = 0.6020, label = "Deathguard Kristof — southeast of Brill" },

    [214]  = { mapID = 1436, x = 0.5667, y = 0.4735, label = "Scout Riell" },
    -- swmap (2.0.9): the Stormwind markers moved to Forever's Stormwind map
    -- (they were at their places on the old map): Wilder Thistlenettle,
    -- Nikova Raskol, Brohann Caskbelly, Shylamiir, Lord Grayson
    -- Shadowbreaker (here and in QuestChains.lua), Highlord Bolvar
    -- Fordragon, Grimand Elmore, Furen Longbeard (QuestUpdates.lua). Forever
    -- client tables (their spawns).
    [168]  = { mapID = 1453, x = 0.703, y = 0.408, label = "Wilder Thistlenettle" },
    [167]  = { mapID = 1453, x = 0.703, y = 0.408, label = "Wilder Thistlenettle" },
    [2040] = { mapID = 1453, x = 0.6300, y = 0.3400, label = "Shoni the Shilent — Dwarven District, Stormwind", targetName = "Shoni the Shilent" },
    [166]  = { mapID = 1436, x = 0.5640, y = 0.4750, label = "Gryan Stoutmantle" },

    -- Ragefire Chasm quest givers.
    [5723] = { mapID = 1456, x = 0.701, y = 0.295, label = "Rahauro" },
    [5722] = { mapID = 1456, x = 0.701, y = 0.295, label = "Rahauro" },
    [5728] = { mapID = 1454, x = 0.3200, y = 0.3780, label = "Thrall" },
    [5761] = { mapID = 1454, x = 0.4960, y = 0.5060, label = "Neeru Fireblade" },
    [5725] = { mapID = 1458, x = 0.5620, y = 0.9260, label = "Varimathras" },
    [6521] = { mapID = 1458, x = 0.5620, y = 0.9260, label = "Varimathras — Royal Quarter, Undercity" },

    -- The Stockade quest givers.
    [386] = { mapID = 1433, x = 0.212, y = 0.466, label = "Guard Berton — Lakeshire" },
    [377] = { mapID = 1431, x = 0.720, y = 0.478, label = "Councilman Millstipe — Darkshire" },
    [387] = { mapID = 1453, x = 0.518, y = 0.693, label = "Warden Thelwater — The Stockade", targetName = "Warden Thelwater" },
    -- Nikova Raskol walks a loop around Old Town. The old spot was Classic's
    -- (73.6, 46.6), which on Forever's Stormwind map is north of Old Town.
    -- Her path: Wowhead's sightings moved onto Forever's map (they match the
    -- spots Forever players report: 73.4, 62.3 and 71.8, 60.1).
    -- On the map the pin walks her loop (x/y: the middle of it, for
    -- "near the spot" checks).
    [388] = { mapID = 1453, x = 0.764, y = 0.637, label = "Nikova Raskol — Old Town", targetName = "Nikova Raskol",
        patrol = { { 0.734, 0.554 }, { 0.763, 0.602 }, { 0.761, 0.637 }, { 0.737, 0.622 }, { 0.722, 0.608 } } },
    [378] = { mapID = 1437, x = 0.496, y = 0.182, label = "Motley Garmason — Dun Modr" },
    [391] = { mapID = 1453, x = 0.518, y = 0.693, label = "Warden Thelwater — The Stockade", targetName = "Warden Thelwater" },

    -- Blackfathom Deeps quest givers (Classic map positions used by Forever).
    [971]  = { mapID = 1455, x = 0.5083, y = 0.0561, label = "Gerrig Bonegrip" },
    [1275] = { mapID = 1439, x = 0.3830, y = 0.4310, label = "Gershala Nightwhisper" },
    [3765] = { mapID = 1453, x = 0.363, y = 0.674, label = "Argos Nightwhisper — The Park", targetName = "Argos Nightwhisper" },
    [1198] = { mapID = 1457, x = 0.5500, y = 0.2400, label = "Dawnwatcher Shaedlass" },
    [1199] = { mapID = 1457, x = 0.5500, y = 0.2400, label = "Argent Guard Manados" },
    [6563] = { mapID = 1440, x = 0.1200, y = 0.3400, label = "Je'neu Sancrea" },
    [6562] = { mapID = 1442, x = 0.4720, y = 0.6420, label = "Tsunaman — Sun Rock Retreat" },
    [6565] = { mapID = 1440, x = 0.1200, y = 0.3400, label = "Je'neu Sancrea" },
    [6921] = { mapID = 1440, x = 0.1200, y = 0.3400, label = "Je'neu Sancrea" },

    -- Wailing Caverns quest givers.
    [1486] = { mapID = 1413, x = 0.4660, y = 0.3630, label = "Nalpak" },
    [1487] = { mapID = 1413, x = 0.4660, y = 0.3570, label = "Ebru" },
    [962] = { mapID = 1456, x = 0.2300, y = 0.2100, label = "Apothecary Zamah — Pools of Vision, Thunder Bluff", detail = "Serpentbloom starts from Apothecary Zamah in the Pools of Vision beneath Spirit Rise" },
    [1491] = { mapID = 1413, x = 0.6280, y = 0.3670, label = "Mebok Mizzyrix" },
    [959] = { mapID = 1413, x = 0.6390, y = 0.3830, label = "Crane Operator Bigglefuzz" },
    [914] = { mapID = 1456, x = 0.7530, y = 0.3130, label = "Nara Wildmane" },
    [6981] = { mapID = 1456, x = 0.7060, y = 0.3000, label = "Falla Sagewind" },

    -- Shadowfang Keep quest givers.
    [1098] = { mapID = 1421, x = 0.4340, y = 0.4090, label = "High Executor Hadrec" },
    [1740] = { mapID = 1413, x = 0.4930, y = 0.5720, label = "Doan Karhan" },
    [1013] = { mapID = 1458, x = 0.5370, y = 0.5450, label = "Keeper Bel'dugur" },
    [1014] = { mapID = 1421, x = 0.4420, y = 0.3980, label = "Dalar Dawnweaver" },

    -- Gnomeregan quest givers.
    [2922] = { mapID = 1455, x = 0.690, y = 0.500, label = "Tinkmaster Overspark — Tinker Town, Ironforge", targetName = "Tinkmaster Overspark" },
    [2926] = { mapID = 1426, x = 0.450, y = 0.490, label = "Ozzie Togglevolt — Kharanos", targetName = "Ozzie Togglevolt" },
    [2962] = { mapID = 1426, x = 0.450, y = 0.490, label = "Ozzie Togglevolt — Kharanos", targetName = "Ozzie Togglevolt" },
    [2928] = { mapID = 1453, x = 0.630, y = 0.340, label = "Shoni the Shilent — Dwarven District, Stormwind", targetName = "Shoni the Shilent" },
    [2924] = { mapID = 1455, x = 0.670, y = 0.460, label = "Klockmort Spannerspan — Tinker Town, Ironforge", targetName = "Klockmort Spannerspan" },
    [2930] = { mapID = 1455, x = 0.690, y = 0.480, label = "Master Mechanic Castpipe — Tinker Town, Ironforge", targetName = "Master Mechanic Castpipe" },
    [2929] = { mapID = 1455, x = 0.680, y = 0.490, label = "High Tinker Mekkatorque — Tinker Town, Ironforge", targetName = "High Tinker Mekkatorque" },
    [2843] = { mapID = 1434, x = 0.280, y = 0.770, label = "Scooty — Booty Bay", targetName = "Scooty" },
    [2841] = { mapID = 1454, x = 0.760, y = 0.250, label = "Nogg — Valley of Honor, Orgrimmar", targetName = "Nogg" },
    [2948] = { mapID = 1455, x = 0.357, y = 0.040, label = "Talvash del Kissel — Mystic Ward, Ironforge", targetName = "Talvash del Kissel" },
    [2950] = { mapID = 1454, x = 0.760, y = 0.250, label = "Nogg — Valley of Honor, Orgrimmar", targetName = "Nogg" },

    -- Razorfen Kraul quest givers.
    [1221] = { mapID = 1413, x = 0.624, y = 0.376, label = "Mebok Mizzyrix — Ratchet", targetName = "Mebok Mizzyrix" },
    [1101] = { mapID = 1444, x = 0.896, y = 0.466, label = "Falfindel Waywarder — Thalanaar", targetName = "Falfindel Waywarder" },
    [1102] = { mapID = 1456, x = 0.360, y = 0.590, label = "Auld Stonespire — Thunder Bluff", targetName = "Auld Stonespire" },
    [1109] = { mapID = 1458, x = 0.480, y = 0.690, label = "Master Apothecary Faranell — Apothecarium", targetName = "Master Apothecary Faranell" },

    -- Scarlet Monastery: Graveyard quest giver outside the instance.
    [1113] = { mapID = 1458, x = 0.480, y = 0.690, label = "Master Apothecary Faranell — Apothecarium", targetName = "Master Apothecary Faranell" },

    -- Quest givers for the dungeons added in 1.6.5 (positions from Wowhead).
    -- Stormwind uses the newer city map in this client, so those use retail positions.
    [17] = { mapID = 1432, x = 0.370, y = 0.492, label = "Ghak Healtouch — Loch Modan", targetName = "Ghak Healtouch" },
    [704] = { mapID = 1432, x = 0.658, y = 0.654, label = "Prospector Ironband — Loch Modan", targetName = "Prospector Ironband" },
    [709] = { mapID = 1418, x = 0.514, y = 0.764, label = "Theldurin the Lost — Badlands", targetName = "Theldurin the Lost" },
    [721] = { mapID = 1418, x = 0.534, y = 0.432, label = "Prospector Ryedol — Badlands", targetName = "Prospector Ryedol" },
    [1048] = { mapID = 1458, x = 0.562, y = 0.924, label = "Varimathras — Undercity", targetName = "Varimathras" },
    [1049] = { mapID = 1456, x = 0.344, y = 0.472, label = "Sage Truthseeker — Thunder Bluff", targetName = "Sage Truthseeker" },
    [1050] = { mapID = 1455, x = 0.740, y = 0.134, label = "Librarian Mae Paledust — Ironforge", targetName = "Librarian Mae Paledust" },
    [1053] = { mapID = 1424, x = 0.514, y = 0.584, label = "Raleigh the Devout — Hillsbrad Foothills", targetName = "Raleigh the Devout" },
    [1139] = { mapID = 1455, x = 0.764, y = 0.108, label = "Advisor Belgrum — Ironforge", targetName = "Advisor Belgrum" },
    [1360] = { mapID = 1455, x = 0.742, y = 0.098, label = "Krom Stoutarm — Ironforge", targetName = "Krom Stoutarm" },
    [1394] = { mapID = 1458, x = 0.574, y = 0.654, label = "Parqual Fintallas — Undercity", targetName = "Parqual Fintallas" },
    [1445] = { mapID = 1435, x = 0.480, y = 0.550, label = "Fel'zerul — Swamp of Sorrows", targetName = "Fel'zerul" },
    [1446] = { mapID = 1425, x = 0.336, y = 0.752, label = "Atal'ai Exile — The Hinterlands", targetName = "Atal'ai Exile" },
    [1475] = { mapID = 1453, x = 0.695, y = 0.404, label = "Brohann Caskbelly — Stormwind", targetName = "Brohann Caskbelly" },
    [2200] = { mapID = 1455, x = 0.360, y = 0.034, label = "Talvash del Kissel — Ironforge", targetName = "Talvash del Kissel" },
    [2202] = { mapID = 1418, x = 0.024, y = 0.460, label = "Jarkal Mossmeld — Badlands", targetName = "Jarkal Mossmeld" },
    [2283] = { mapID = 1454, x = 0.594, y = 0.368, label = "Dran Droffers — Orgrimmar", targetName = "Dran Droffers" },
    [2284] = { mapID = 1454, x = 0.594, y = 0.368, label = "Dran Droffers — Orgrimmar", targetName = "Dran Droffers" },
    [2339] = { mapID = 1418, x = 0.024, y = 0.460, label = "Jarkal Mossmeld — Badlands", targetName = "Jarkal Mossmeld" },
    [2342] = { mapID = 1458, x = 0.624, y = 0.484, label = "Patrick Garrett — Undercity", targetName = "Patrick Garrett" },
    [2398] = { mapID = 1455, x = 0.746, y = 0.117, label = "Prospector Stormpike — Ironforge", targetName = "Prospector Stormpike" },
    [2418] = { mapID = 1418, x = 0.424, y = 0.524, label = "Rigglefuzz — Badlands", targetName = "Rigglefuzz" },
    [2768] = { mapID = 1446, x = 0.524, y = 0.284, label = "Chief Engineer Bilgewhizzle — Tanaris", targetName = "Chief Engineer Bilgewhizzle" },
    [2770] = { mapID = 1441, x = 0.780, y = 0.770, label = "Wizzle Brassbolts — Thousand Needles", targetName = "Wizzle Brassbolts" },
    [2846] = { mapID = 1445, x = 0.460, y = 0.570, label = "Tabetha — Dustwallow Marsh", targetName = "Tabetha" },
    [2865] = { mapID = 1446, x = 0.514, y = 0.268, label = "Tran'rek — Tanaris", targetName = "Tran'rek" },
    [2936] = { mapID = 1411, x = 0.558, y = 0.744, label = "Master Gadrin — Durotar", targetName = "Master Gadrin" },
    [2991] = { mapID = 1419, x = 0.670, y = 0.194, label = "Thadius Grimshade — Blasted Lands", targetName = "Thadius Grimshade" },
    [3042] = { mapID = 1446, x = 0.514, y = 0.286, label = "Trenton Lighthammer — Tanaris", targetName = "Trenton Lighthammer" },
    [3341] = { mapID = 1458, x = 0.740, y = 0.324, label = "Andrew Brownell — Undercity", targetName = "Andrew Brownell" },
    [3446] = { mapID = 1446, x = 0.526, y = 0.458, label = "Marvon Rivetseeker — Tanaris", targetName = "Marvon Rivetseeker" },
    [3447] = { mapID = 1446, x = 0.526, y = 0.458, label = "Marvon Rivetseeker — Tanaris", targetName = "Marvon Rivetseeker" },
    [3527] = { mapID = 1446, x = 0.670, y = 0.224, label = "Yeh'kinya — Tanaris", targetName = "Yeh'kinya" },
    [3528] = { mapID = 1446, x = 0.670, y = 0.224, label = "Yeh'kinya — Tanaris", targetName = "Yeh'kinya" },
    [3636] = { mapID = 1453, x = 0.496, y = 0.448, label = "Archbishop Benedictus — Stormwind", targetName = "Archbishop Benedictus" },
    [3907] = { mapID = 1418, x = 0.034, y = 0.482, label = "Thunderheart — Badlands", targetName = "Thunderheart" },
    [3981] = { mapID = 1418, x = 0.058, y = 0.474, label = "Galamav the Marksman — Badlands", targetName = "Galamav the Marksman" },
    [4003] = { mapID = 1454, x = 0.320, y = 0.378, label = "Thrall — Orgrimmar", targetName = "Thrall" },
    [4024] = { mapID = 1428, x = 0.948, y = 0.316, label = "Cyrus Therepentous — Burning Steppes", targetName = "Cyrus Therepentous" },
    [4063] = { mapID = 1418, x = 0.258, y = 0.450, label = "Lotwil Veriatus — Badlands", targetName = "Lotwil Veriatus" },
    [4081] = { mapID = 1418, x = 0.038, y = 0.475, label = "WANTED poster — Kargath, Badlands", targetName = "WANTED" },
    [4082] = { mapID = 1418, x = 0.040, y = 0.468, label = "KILL ON SIGHT poster — Kargath, Badlands", targetName = "KILL ON SIGHT" },
    [4123] = { mapID = 1428, x = 0.652, y = 0.238, label = "Maxwort Uberglint — Burning Steppes", targetName = "Maxwort Uberglint" },
    [4126] = { mapID = 1426, x = 0.468, y = 0.524, label = "Ragnar Thunderbrew — Dun Morogh", targetName = "Ragnar Thunderbrew" },
    [4132] = { mapID = 1418, x = 0.058, y = 0.474, label = "Warlord Goretooth — Badlands", targetName = "Warlord Goretooth" },
    [4134] = { mapID = 1418, x = 0.030, y = 0.476, label = "Shadowmage Vivian Lagrave — Badlands", targetName = "Shadowmage Vivian Lagrave" },
    [4136] = { mapID = 1428, x = 0.660, y = 0.220, label = "Yuka Screwspigot — Burning Steppes", targetName = "Yuka Screwspigot" },
    [4241] = { mapID = 1428, x = 0.846, y = 0.688, label = "Marshal Maxwell — Burning Steppes", targetName = "Marshal Maxwell" },
    [4263] = { mapID = 1428, x = 0.854, y = 0.700, label = "Jalinda Sprig — Burning Steppes", targetName = "Jalinda Sprig" },
    [4362] = { mapID = 1455, x = 0.394, y = 0.558, label = "King Magni Bronzebeard — Ironforge", targetName = "King Magni Bronzebeard" },
    [4701] = { mapID = 1428, x = 0.854, y = 0.688, label = "Helendis Riverhorn — Burning Steppes", targetName = "Helendis Riverhorn" },
    [4724] = { mapID = 1418, x = 0.058, y = 0.474, label = "Galamav the Marksman — Badlands", targetName = "Galamav the Marksman" },
    [4729] = { mapID = 1428, x = 0.658, y = 0.220, label = "Kibler — Burning Steppes", targetName = "Kibler" },
    [4734] = { mapID = 1428, x = 0.652, y = 0.238, label = "Tinkee Steamboil — Burning Steppes", targetName = "Tinkee Steamboil" },
    [4735] = { mapID = 1428, x = 0.652, y = 0.238, label = "Tinkee Steamboil — Burning Steppes", targetName = "Tinkee Steamboil" },
    [4771] = { mapID = 1423, x = 0.737, y = 0.505, label = "Betina Bigglezink — Eastern Plaguelands", targetName = "Betina Bigglezink" },
    [4862] = { mapID = 1428, x = 0.658, y = 0.220, label = "Kibler — Burning Steppes", targetName = "Kibler" },
    [4866] = { mapID = 1428, x = 0.650, y = 0.236, label = "Ragged John — Burning Steppes", targetName = "Ragged John" },
    [4903] = { mapID = 1418, x = 0.058, y = 0.474, label = "Warlord Goretooth — Badlands", targetName = "Warlord Goretooth" },
    [4974] = { mapID = 1454, x = 0.320, y = 0.378, label = "Thrall — Orgrimmar", targetName = "Thrall" },
    [5081] = { mapID = 1428, x = 0.846, y = 0.688, label = "Marshal Maxwell — Burning Steppes", targetName = "Marshal Maxwell" },
    [5102] = { mapID = 1428, x = 0.846, y = 0.688, label = "Marshal Maxwell — Burning Steppes", targetName = "Marshal Maxwell" },
    [5127] = { mapID = 1452, x = 0.638, y = 0.738, label = "Lorax — Winterspring", targetName = "Lorax" },
    [5212] = { mapID = 1423, x = 0.737, y = 0.505, label = "Betina Bigglezink — Eastern Plaguelands", targetName = "Betina Bigglezink" },
    [5213] = { mapID = 1423, x = 0.737, y = 0.505, label = "Betina Bigglezink — Eastern Plaguelands", targetName = "Betina Bigglezink" },
    [5214] = { mapID = 1423, x = 0.728, y = 0.492, label = "Smokey LaRue — Eastern Plaguelands", targetName = "Smokey LaRue" },
    [5243] = { mapID = 1423, x = 0.739, y = 0.490, label = "Leonid Barthalomew the Revered — Eastern Plaguelands", targetName = "Leonid Barthalomew the Revered" },
    [5251] = { mapID = 1423, x = 0.737, y = 0.508, label = "Duke Nicholas Zverenhoff — Eastern Plaguelands", targetName = "Duke Nicholas Zverenhoff" },
    [5263] = { mapID = 1423, x = 0.737, y = 0.508, label = "Duke Nicholas Zverenhoff — Eastern Plaguelands", targetName = "Duke Nicholas Zverenhoff" },
    [5282] = { mapID = 1423, x = 0.109, y = 0.272, label = "Egan — Eastern Plaguelands", targetName = "Egan" },
    [5341] = { mapID = 1420, x = 0.830, y = 0.714, label = "Alexi Barov — Tirisfal Glades", targetName = "Alexi Barov" },
    [5343] = { mapID = 1422, x = 0.434, y = 0.834, label = "Weldon Barov — Western Plaguelands", targetName = "Weldon Barov" },
    [5382] = { mapID = 1422, x = 0.702, y = 0.738, label = "Eva Sarkhoff — Western Plaguelands", targetName = "Eva Sarkhoff" },
    [5384] = { mapID = 1422, x = 0.702, y = 0.738, label = "Eva Sarkhoff — Western Plaguelands", targetName = "Eva Sarkhoff" },
    [5466] = { mapID = 1422, x = 0.704, y = 0.740, label = "Magistrate Marduke — Western Plaguelands", targetName = "Magistrate Marduke" },
    [5515] = { mapID = 1422, x = 0.702, y = 0.738, label = "Eva Sarkhoff — Western Plaguelands", targetName = "Eva Sarkhoff" },
    [5529] = { mapID = 1423, x = 0.737, y = 0.505, label = "Betina Bigglezink — Eastern Plaguelands", targetName = "Betina Bigglezink" },
    [5848] = { mapID = 1422, x = 0.656, y = 0.754, label = "Artist Renfray — Western Plaguelands", targetName = "Artist Renfray" },
    [6163] = { mapID = 1423, x = 0.222, y = 0.643, label = "Nathanos Blightcaller — Eastern Plaguelands", targetName = "Nathanos Blightcaller" },
    [6502] = { mapID = 1452, x = 0.544, y = 0.512, label = "Haleh — Winterspring", targetName = "Haleh" },
    [6602] = { mapID = 1444, x = 0.448, y = 0.074, label = "Rexxar — Feralas", targetName = "Rexxar" },
    [6626] = { mapID = 1413, x = 0.490, y = 0.948, label = "Myriam Moonsinger — The Barrens", targetName = "Myriam Moonsinger" },
    [7028] = { mapID = 1443, x = 0.620, y = 0.394, label = "Willow — Desolace", targetName = "Willow" },
    [7029] = { mapID = 1443, x = 0.232, y = 0.702, label = "Vark Battlescar — Desolace", targetName = "Vark Battlescar" },
    [7041] = { mapID = 1443, x = 0.684, y = 0.088, label = "Talendria — Desolace", targetName = "Talendria" },
    [7064] = { mapID = 1443, x = 0.268, y = 0.776, label = "Selendra — Desolace", targetName = "Selendra" },
    [7065] = { mapID = 1443, x = 0.638, y = 0.106, label = "Keeper Marandis — Desolace", targetName = "Keeper Marandis" },
    [7067] = { mapID = 1443, x = 0.434, y = 0.848, label = "Centaur Pariah — Desolace", targetName = "Centaur Pariah" },
    [7068] = { mapID = 1454, x = 0.388, y = 0.854, label = "Uthel'nay — Orgrimmar", targetName = "Uthel'nay" },
    -- 2.0.4 (reported by Nyby): he is in the tower on Theramore Isle, not near
    -- Brackenwall Village (ForeverChanges: 66.4, 49.3).
    [7070] = { mapID = 1445, x = 0.664, y = 0.493, label = "Archmage Tervosh — Dustwallow Marsh", targetName = "Archmage Tervosh" },
    [7441] = { mapID = 1444, x = 0.768, y = 0.374, label = "Azj'Tordin — Feralas", targetName = "Azj'Tordin" },
    [7481] = { mapID = 1444, x = 0.744, y = 0.440, label = "Sage Korolusk — Feralas", targetName = "Sage Korolusk" },
    [7482] = { mapID = 1444, x = 0.310, y = 0.442, label = "Scholar Runethorn — Feralas", targetName = "Scholar Runethorn" },
    [7488] = { mapID = 1444, x = 0.304, y = 0.460, label = "Latronicus Moonspear — Feralas", targetName = "Latronicus Moonspear" },
    [7489] = { mapID = 1444, x = 0.760, y = 0.438, label = "Talo Thornhoof — Feralas", targetName = "Talo Thornhoof" },
    [92456] = { mapID = 1453, x = 0.315, y = 0.626, label = "Shylamiir — Stormwind", targetName = "Shylamiir" },
    [92457] = { mapID = 1421, x = 0.684, y = 0.452, label = "Image of Archmage Modera — Silverpine Forest", targetName = "Image of Archmage Modera" },
    [92458] = { mapID = 1421, x = 0.684, y = 0.452, label = "Image of Archmage Modera — Silverpine Forest", targetName = "Image of Archmage Modera" },
    [92489] = { mapID = 1453, x = 0.488, y = 0.874, label = "High Sorcerer Andromath — Stormwind", targetName = "High Sorcerer Andromath" },
    [95646] = { mapID = 1437, x = 0.562, y = 0.404, label = "Rethiel the Greenwarden — Wetlands", targetName = "Rethiel the Greenwarden" },
    [95682] = { mapID = 1437, x = 0.514, y = 0.592, label = "Deathstalker Agent — Wetlands", targetName = "Deathstalker Agent" },
    [95697] = { mapID = 1454, x = 0.574, y = 0.534, label = "Borstan — Orgrimmar", targetName = "Borstan" },
    [95772] = { mapID = 1433, x = 0.256, y = 0.464, label = "Dorin Songblade — Redridge Mountains", targetName = "Dorin Songblade" },
    [96800] = { mapID = 1416, x = 0.094, y = 0.626, label = "Magus Olvek — Dalaran", targetName = "Magus Olvek" },
    [96984] = { mapID = 1421, x = 0.684, y = 0.452, label = "Image of Archmage Modera — Silverpine Forest", targetName = "Image of Archmage Modera" },
    [96986] = { mapID = 1424, x = 0.624, y = 0.204, label = "Melisara — Hillsbrad Foothills", targetName = "Melisara" },
    [96988] = { mapID = 1458, x = 0.458, y = 0.732, label = "Doctor Martin Felben — Undercity", targetName = "Doctor Martin Felben" },
    [98815] = { mapID = 1437, x = 0.084, y = 0.558, label = "James Halloran — Wetlands", targetName = "James Halloran" },
    [98823] = { mapID = 1456, x = 0.702, y = 0.336, label = "Bashana Runetotem — Thunder Bluff", targetName = "Bashana Runetotem" },
    [98824] = { mapID = 1437, x = 0.388, y = 0.522, label = "Prospector Whelgar — Wetlands", targetName = "Prospector Whelgar" },

    -- Quest givers added from the Classic Era quest compendium.
    [1956] = { mapID = 1445, x = 0.460, y = 0.570, label = "Tabetha — Dustwallow Marsh", targetName = "Tabetha" },
    [4143] = { mapID = 1444, x = 0.450, y = 0.254, label = "Gregan Brewspewer — Feralas", targetName = "Gregan Brewspewer" },
    [4146] = { mapID = 1413, x = 0.624, y = 0.386, label = "Liv Rizzlefix — The Barrens", targetName = "Liv Rizzlefix" },
    [9053] = { mapID = 1449, x = 0.716, y = 0.760, label = "Torwa Pathfinder — Un'Goro Crater", targetName = "Torwa Pathfinder" },
    [8232] = { mapID = 1447, x = 0.424, y = 0.426, label = "Ogtinc — Azshara", targetName = "Ogtinc" },
    [8253] = { mapID = 1447, x = 0.292, y = 0.402, label = "Archmage Xylem — Azshara", targetName = "Archmage Xylem" },
    [8418] = { mapID = 1422, x = 0.428, y = 0.840, label = "Commander Ashlam Valorfist — Western Plaguelands", targetName = "Commander Ashlam Valorfist" },
    [8257] = { mapID = 1447, x = 0.424, y = 0.426, label = "Ogtinc — Azshara", targetName = "Ogtinc" },
    [8236] = { mapID = 1447, x = 0.292, y = 0.402, label = "Archmage Xylem — Azshara", targetName = "Archmage Xylem" },
    [8413] = { mapID = 1416, x = 0.804, y = 0.668, label = "Bath'rah the Windwatcher — Alterac Mountains", targetName = "Bath'rah the Windwatcher" },
    [8422] = { mapID = 1448, x = 0.414, y = 0.448, label = "Impsy — Felwood", targetName = "Impsy" },
    [8425] = { mapID = 1435, x = 0.342, y = 0.660, label = "Fallen Hero of the Horde — Swamp of Sorrows", targetName = "Fallen Hero of the Horde" },
    [7201] = { mapID = 1418, x = 0.030, y = 0.476, label = "Shadowmage Vivian Lagrave — Badlands", targetName = "Shadowmage Vivian Lagrave" },
    [4286] = { mapID = 1428, x = 0.844, y = 0.684, label = "Oralius — Burning Steppes", targetName = "Oralius" },
    [4788] = { mapID = 1446, x = 0.668, y = 0.240, label = "Prospector Ironboot — Tanaris", targetName = "Prospector Ironboot" },
    [6569] = { mapID = 1422, x = 0.508, y = 0.778, label = "Myranda the Hag — Western Plaguelands", targetName = "Myranda the Hag" },
    [4764] = { mapID = 1428, x = 0.848, y = 0.690, label = "Mayara Brightwing — Burning Steppes", targetName = "Mayara Brightwing" },
    [4768] = { mapID = 1418, x = 0.030, y = 0.476, label = "Shadowmage Vivian Lagrave — Badlands", targetName = "Shadowmage Vivian Lagrave" },
    [5526] = { mapID = 1450, x = 0.516, y = 0.444, label = "Rabine Saturna — Moonglade", targetName = "Rabine Saturna" },
    [5247] = { mapID = 1423, x = 0.475, y = 0.168, label = "Aurora Skycaller — Eastern Plaguelands", targetName = "Aurora Skycaller" },
    [7643] = { mapID = 1453, x = 0.484, y = 0.502, label = "Lord Grayson Shadowbreaker — Stormwind", targetName = "Lord Grayson Shadowbreaker" },
    [7631] = { mapID = 1428, x = 0.126, y = 0.314, label = "Mor'zul Bloodbringer — Burning Steppes", targetName = "Mor'zul Bloodbringer" },
    [7629] = { mapID = 1428, x = 0.124, y = 0.314, label = "Gorzeeki Wildeyes — Burning Steppes", targetName = "Gorzeeki Wildeyes" },
    [7647] = { mapID = 1453, x = 0.484, y = 0.502, label = "Lord Grayson Shadowbreaker — Stormwind", targetName = "Lord Grayson Shadowbreaker" },
    [7668] = { mapID = 1454, x = 0.384, y = 0.360, label = "Sagorne Creststrider — Orgrimmar", targetName = "Sagorne Creststrider" },
    [5463] = { mapID = 1423, x = 0.739, y = 0.490, label = "Leonid Barthalomew the Revered — Eastern Plaguelands", targetName = "Leonid Barthalomew the Revered" },
    [707] = { mapID = 1455, x = 0.746, y = 0.117, label = "Prospector Stormpike — Ironforge", targetName = "Prospector Stormpike" },
    [8415] = { mapID = 1453, x = 0.484, y = 0.502, label = "Lord Grayson Shadowbreaker — Stormwind", targetName = "Lord Grayson Shadowbreaker" },
    [5281] = { mapID = 1423, x = 0.718, y = 0.544, label = "Caretaker Alen — Eastern Plaguelands", targetName = "Caretaker Alen" },
    [5961] = { mapID = 1458, x = 0.580, y = 0.916, label = "Lady Sylvanas Windrunner — Undercity", targetName = "Lady Sylvanas Windrunner" },
    [722] = { mapID = 1418, x = 0.379, y = 0.106, label = "Hammertoe Grez — Uldaman excavation (outside the instance)", detail = "Hammertoe is in the outer excavation caves, before the instance portal" },
    -- Starter locations from the Forever starter-location guide (safety net).
    [132] = { mapID = 1433, x = 0.214, y = 0.454, label = "Wiley the Black — Redridge Mountains", targetName = "Wiley the Black", detail = "Wiley the Black: Lakeshire inn, Redridge Mountains" },
    [135] = { mapID = 1436, x = 0.563, y = 0.475, label = "Gryan Stoutmantle — Westfall", targetName = "Gryan Stoutmantle", detail = "Gryan Stoutmantle: Sentinel Hill, Westfall" },
    [141] = { mapID = 1453, x = 0.783, y = 0.707, label = "Master Mathias Shaw — Stormwind", targetName = "Master Mathias Shaw", detail = "Master Mathias Shaw: SI:7, Old Town, Stormwind" },
    [142] = { mapID = 1436, x = 0.563, y = 0.475, label = "Gryan Stoutmantle — Westfall", targetName = "Gryan Stoutmantle", detail = "Gryan Stoutmantle: Sentinel Hill, Westfall" },
    [155] = { mapID = 1436, x = 0.557, y = 0.475, label = "Defias Traitor — Westfall", targetName = "Defias Traitor", detail = "Defias Traitor: Sentinel Hill, Westfall" },
    [739] = { mapID = 1418, x = 0.509, y = 0.624, label = "Battered Dwarven Skeleton — Badlands", targetName = "Battered Dwarven Skeleton", detail = "Battered Dwarven Skeleton: Agmond's End, Badlands" },
    [877] = { mapID = 1413, x = 0.523, y = 0.319, label = "Tonga Runetotem — The Barrens", targetName = "Tonga Runetotem", detail = "Tonga Runetotem: The Crossroads, The Barrens" },
    [880] = { mapID = 1413, x = 0.523, y = 0.319, label = "Tonga Runetotem — The Barrens", targetName = "Tonga Runetotem", detail = "Tonga Runetotem: The Crossroads, The Barrens" },
    [1489] = { mapID = 1413, x = 0.523, y = 0.319, label = "Tonga Runetotem — The Barrens", targetName = "Tonga Runetotem", detail = "Tonga Runetotem: The Crossroads, The Barrens" },
    [1490] = { mapID = 1456, x = 0.786, y = 0.286, label = "Arch Druid Hamuul Runetotem — Thunder Bluff", targetName = "Arch Druid Hamuul Runetotem", detail = "Arch Druid Hamuul Runetotem: Elder Rise, Thunder Bluff" },
    [1652] = { mapID = 1436, x = 0.417, y = 0.892, label = "Daphne Stilwell — southern Westfall", targetName = "Daphne Stilwell", detail = "Daphne Stilwell: Stilwell farm, southern Westfall" },
    [1653] = { mapID = 1453, x = 0.505, y = 0.475, label = "Duthorian Rall — Stormwind", targetName = "Duthorian Rall", detail = "Duthorian Rall: Cathedral of Light, Stormwind" },
    [2769] = { mapID = 1455, x = 0.679, y = 0.461, label = "Klockmort Spannerspan — Ironforge", targetName = "Klockmort Spannerspan", detail = "Klockmort Spannerspan: Tinker Town, Ironforge" },
    [2864] = { mapID = 1434, x = 0.269, y = 0.772, label = "Krazek — upper floor", targetName = "Krazek", detail = "Krazek: Booty Bay inn, upper floor" },
    [4128] = { mapID = 1419, x = 0.636, y = 0.206, label = "Enohar Thunderbrew — Blasted Lands", targetName = "Enohar Thunderbrew", detail = "Enohar Thunderbrew: Nethergarde Keep, Blasted Lands" },
    [4133] = { mapID = 1458, x = 0.501, y = 0.680, label = "Apothecary Zinge — Undercity", targetName = "Apothecary Zinge", detail = "Apothecary Zinge: The Apothecarium, Undercity" },
    [4324] = { mapID = 1446, x = 0.670, y = 0.240, label = "Yorba Screwspigot — Tanaris", targetName = "Yorba Screwspigot", detail = "Yorba Screwspigot: Steamwheedle Port, Tanaris" },
    [4766] = { mapID = 1453, x = 0.769, y = 0.478, label = "Count Remington Ridgewell — Stormwind Keep", targetName = "Count Remington Ridgewell", detail = "Count Remington Ridgewell: Stormwind Keep" },
    [4769] = { mapID = 1458, x = 0.501, y = 0.680, label = "Apothecary Zinge — Undercity", targetName = "Apothecary Zinge", detail = "Apothecary Zinge: The Apothecarium, Undercity" },
    [5250] = { mapID = 1438, x = 0.554, y = 0.922, label = "Daryn Lightwind — Teldrassil", targetName = "Daryn Lightwind", detail = "Daryn Lightwind: Rut'theran Village, Teldrassil" },
    [5727] = { mapID = 1454, x = 0.317, y = 0.378, label = "Thrall — Orgrimmar", targetName = "Thrall", detail = "Thrall: Grommash Hold, Orgrimmar" },
    [6141] = { mapID = 1453, x = 0.526, y = 0.432, label = "Brother Crowley — Stormwind", targetName = "Brother Crowley", detail = "Brother Crowley: Cathedral of Light, Stormwind" },
    [7044] = { mapID = 1443, x = 0.321, y = 0.640, label = "Cavindra — Desolace", targetName = "Cavindra", detail = "Cavindra: Maraudon orange-side caverns, Desolace" },
    [96776] = { mapID = 1412, x = 0.338, y = 0.237, label = "Olana Brighthoof - Skywatcher Plateau, Mulgore", targetName = "Olana Brighthoof", detail = "Olana Brighthoof: Camp Gev'rek, Skywatcher Plateau, Mulgore (33.8, 23.7)" },
    [7492] = { mapID = 1458, x = 0.639, y = 0.441, label = "Harbinger Balthazad — Undercity (walks around)", targetName = "Harbinger Balthazad", detail = "Harbinger Balthazad: Trade Quarter, Undercity (walks around)" },
    [7494] = { mapID = 1453, x = 0.564, y = 0.741, label = "Crier Goodman — Stormwind (walks around)", targetName = "Crier Goodman", detail = "Crier Goodman: Trade District, Stormwind (walks around)" },
    [8945] = { mapID = 1423, x = 0.261, y = 0.113, label = "Anthion Harmon — outside the Stratholme main gate (needs the Ghost Revealer)", targetName = "Anthion Harmon", detail = "Anthion Harmon: outside the Stratholme main gate (needs the Ghost Revealer)" },
    [92749] = { mapID = 1453, x = 0.619, y = 0.306, label = "Sprite Jumpsprocket — Stormwind", targetName = "Sprite Jumpsprocket", detail = "Sprite Jumpsprocket: Dwarven District, Stormwind" },
    [92750] = { mapID = 1453, x = 0.619, y = 0.306, label = "Sprite Jumpsprocket — Stormwind", targetName = "Sprite Jumpsprocket", detail = "Sprite Jumpsprocket: Dwarven District, Stormwind" },
    [92751] = { mapID = 1453, x = 0.803, y = 0.701, label = "Jasper Fel — Stormwind", targetName = "Jasper Fel", detail = "Jasper Fel: SI:7, Old Town, Stormwind" },
    [92752] = { mapID = 1453, x = 0.619, y = 0.306, label = "Sprite Jumpsprocket — Stormwind", targetName = "Sprite Jumpsprocket", detail = "Sprite Jumpsprocket: Dwarven District, Stormwind" },
}

-- BEGIN turninspots
-- Turn-in NPCs who give no quest of their own here, for the quest tracker's
-- ? button. In-game coordinates from Warcraft Tavern's WoW Forever guide to
-- the Ruins of Lordaeron quests.
FDJ.TURNIN_SPOTS = {
    { mapID = 1453, x = 0.690, y = 0.828, label = "General Marcus Jonathan — Valley of Heroes, Stormwind", targetName = "General Marcus Jonathan" },
    { mapID = 1453, x = 0.692, y = 0.277, label = "Lady Dena Kennedy — Stormwind Keep, Stormwind", targetName = "Lady Dena Kennedy" },
    { mapID = 1453, x = 0.562, y = 0.540, label = "Orphan Matron Nightingale — Cathedral Square, Stormwind", targetName = "Orphan Matron Nightingale" },
    { mapID = 1458, x = 0.733, y = 0.326, label = "Oran Snakewrithe — Magic Quarter, Undercity", targetName = "Oran Snakewrithe" },
}
-- END turninspots

-- BEGIN mapquests
-- Quest spots inside the dungeons, shown on the dungeon maps: objects to
-- loot or use, quest givers / turn-ins inside, places to explore.
-- Positions: the Classic spawn database (CMaNGOS classic-db), converted
-- with the client's UiMapAssignment regions (as the boss spots); the
-- floor checked on the map art. Spots next to a boss portrait sit just
-- beside it. acts: start / end / loot / use / explore. dungeon: the
-- journal page that lists the quest; main: its journal entry (a chain
-- step's own quest).
FDJ.MAP_QUEST_PINS = {
    ["Blackfathom Deeps"] = {
        { floor = 1, x = 0.329, y = 0.412, spots = {
            { name = "Pitted Iron Chest", quests = {
                { id = 971, name = "Knowledge in the Deeps", dungeon = "Blackfathom Deeps", acts = { "loot" }, item = 5359, itemName = "Lorgalis Manuscript", textKey = "MAP_OBJ_BFD_CHEST" },
            } },
        } },
        { floor = 1, x = 0.208, y = 0.753, spots = {
            { name = "Argent Guard Thaelrid", quests = {
                { id = 1198, name = "In Search of Thaelrid", dungeon = "Blackfathom Deeps", acts = { "end" } },
                { id = 1200, name = "Blackfathom Villainy", dungeon = "Blackfathom Deeps", acts = { "start" } },
                { id = 6561, name = "Blackfathom Villainy", dungeon = "Blackfathom Deeps", acts = { "start" } },
            } },
        } },
        { floor = 2, x = 0.406, y = 0.804, spots = {
            { name = "Fathom Stone", quests = {
                { id = 6921, name = "Amongst the Ruins", dungeon = "Blackfathom Deeps", acts = { "loot" }, item = 16762, itemName = "Fathom Core", textKey = "MAP_OBJ_BFD_FATHOM" },
            } },
        } },
    },
    ["Blackrock Depths"] = {
        { floor = 1, x = 0.509, y = 0.844, spots = {
            { name = "Commander Gor'shak", quests = {
                { id = 3982, name = "What Is Going On?", dungeon = "Blackrock Depths", acts = { "start", "end" } },
                { id = 3981, name = "Commander Gor'shak", dungeon = "Blackrock Depths", main = 3982, acts = { "end" } },
                { id = 4001, name = "What Is Going On?", dungeon = "Blackrock Depths", main = 4003, acts = { "start" } },
            } },
            { name = "Kharan Mighthammer", quests = {
                { id = 4341, name = "Kharan Mighthammer", dungeon = "Blackrock Depths", main = 4362, acts = { "end" } },
                { id = 4342, name = "Kharan's Tale", dungeon = "Blackrock Depths", main = 4362, acts = { "start", "end" } },
                { id = 4361, name = "The Bearer of Bad News", dungeon = "Blackrock Depths", main = 4362, acts = { "start" } },
            } },
        } },
        { floor = 1, x = 0.532, y = 0.928, spots = {
            { name = "Marshal Windsor", quests = {
                { id = 4322, name = "Jail Break!", dungeon = "Blackrock Depths", acts = { "start" } },
                { id = 4241, name = "Marshal Windsor", dungeon = "Blackrock Depths", main = 4322, acts = { "end" } },
                { id = 4242, name = "Abandoned Hope", dungeon = "Blackrock Depths", main = 4322, acts = { "start" } },
                { id = 4264, name = "A Crumpled Up Note", dungeon = "Blackrock Depths", main = 4322, acts = { "end" } },
                { id = 4282, name = "A Shred of Hope", dungeon = "Blackrock Depths", main = 4322, acts = { "start", "end" } },
            } },
        } },
        { floor = 2, x = 0.551, y = 0.331, spots = {
            { name = "Spectral Chalice", quests = {
                { id = 4083, name = "The Spectral Chalice", dungeon = "Blackrock Depths", acts = { "start", "end" } },
            } },
        } },
        { floor = 2, x = 0.693, y = 0.370, spots = {
            { name = "Core Fragment", quests = {
                { id = 7848, name = "Attunement to the Core", dungeon = "Blackrock Depths", acts = { "loot" }, item = 18412, itemName = "Core Fragment" },
            } },
        } },
        { floor = 2, x = 0.514, y = 0.591, spots = {
            { name = "Mistress Nagmara", quests = {
                { id = 4201, name = "The Love Potion", dungeon = "Blackrock Depths", acts = { "start", "end" } },
            } },
            { name = "Lokhtos Darkbargainer", quests = {
                { id = 7604, name = "A Binding Contract", dungeon = "Blackrock Depths", acts = { "end" } },
            } },
        } },
        { floor = 2, x = 0.632, y = 0.732, spots = {
            { name = "Heart of the Mountain", quests = {
                { id = 4123, name = "The Heart of the Mountain", dungeon = "Blackrock Depths", acts = { "loot" }, item = 11309, itemName = "The Heart of the Mountain" },
            } },
            { name = "Dark Coffer", quests = {
                { id = 4083, name = "The Spectral Chalice", dungeon = "Blackrock Depths", acts = { "loot" }, item = 7910, itemName = "Star Ruby" },
            } },
        } },
        { floor = 2, x = 0.615, y = 0.950, spots = {
            { name = "Monument of Franclorn Forgewright", quests = {
                { id = 3802, name = "Dark Iron Legacy", dungeon = "Blackrock Depths", acts = { "end" } },
            } },
        } },
    },
    ["Dire Maul: North"] = {
        { floor = 1, x = 0.217, y = 0.526, spots = {
            { name = "Ogre Tannin Basket", quests = {
                { id = 5518, name = "The Gordok Ogre Suit", dungeon = "Dire Maul: North", acts = { "loot" }, item = 18240, itemName = "Ogre Tannin" },
            } },
        } },
        { floor = 1, x = 0.321, y = 0.599, spots = {
            { name = "Knot Thimblejack", quests = {
                { id = 5525, name = "Free Knot!", dungeon = "Dire Maul: North", acts = { "start", "end" } },
                { id = 5518, name = "The Gordok Ogre Suit", dungeon = "Dire Maul: North", acts = { "start", "end" } },
            } },
        } },
    },
    ["Dire Maul: West"] = {
        { floor = 1, x = 0.484, y = 0.538, spots = {
            { name = "Shen'dralar Ancient", quests = {
                { id = 7461, name = "The Madness Within", dungeon = "Dire Maul: West", acts = { "start", "end" } },
            } },
        } },
        { floor = 3, x = 0.747, y = 0.113, spots = {
            { name = "Lorekeeper Javon", quests = {
                { id = 7506, name = "The Emerald Dream...", dungeon = "Dire Maul: North", acts = { "end" } },
                { id = 7504, name = "Holy Bologna: What the Light Won't Tell You", dungeon = "Dire Maul: North", acts = { "end" } },
                { id = 7505, name = "Frost Shock and You", dungeon = "Dire Maul: North", acts = { "end" } },
            } },
        } },
        { floor = 3, x = 0.802, y = 0.114, spots = {
            { name = "Lorekeeper Mykos", quests = {
                { id = 7503, name = "The Greatest Race of Hunters", dungeon = "Dire Maul: North", acts = { "end" } },
                { id = 7501, name = "The Light and How To Swing It", dungeon = "Dire Maul: North", acts = { "end" } },
                { id = 7502, name = "Harnessing Shadows", dungeon = "Dire Maul: North", acts = { "end" } },
            } },
        } },
        { floor = 3, x = 0.737, y = 0.171, spots = {
            { name = "Lorekeeper Lydros", quests = {
                { id = 7463, name = "Arcane Refreshment", dungeon = "Dire Maul: East", acts = { "start", "end" } },
                { id = 7507, name = "Nostro's Compendium", dungeon = "Dire Maul: North", acts = { "end" } },
                { id = 7483, name = "Libram of Rapidity", dungeon = "Dire Maul: North", acts = { "start", "end" } },
                { id = 7484, name = "Libram of Focus", dungeon = "Dire Maul: North", acts = { "start", "end" } },
                { id = 7485, name = "Libram of Protection", dungeon = "Dire Maul: North", acts = { "start", "end" } },
            } },
        } },
        { floor = 3, x = 0.845, y = 0.230, spots = {
            { name = "Lorekeeper Kildrath", quests = {
                { id = 7500, name = "The Arcanist's Cookbook", dungeon = "Dire Maul: North", acts = { "end" } },
                { id = 7498, name = "Garona: A Study on Stealth and Treachery", dungeon = "Dire Maul: North", acts = { "end" } },
                { id = 7499, name = "Codex of Defense", dungeon = "Dire Maul: North", acts = { "end" } },
            } },
        } },
        { floor = 3, x = 0.573, y = 0.276, spots = {
            { name = "The Prince's Chest", quests = {
                { id = 7703, name = "Unfinished Gordok Business", dungeon = "Dire Maul: West", acts = { "loot" }, item = 18336, itemName = "Gauntlet of Gordok Might" },
            } },
        } },
    },
    -- No spawn data for WoW Forever's own dungeons: placed from Warcraft
    -- Tavern's screenshots (Ardin on the wooden tower by the Relic Guardian,
    -- beside its portrait; Daewyn's body in a tent at the Lost Dig Site).
    ["Excavation Site: Wetlands"] = {
        { floor = 1, x = 0.262, y = 0.668, spots = {
            { name = "Ardin Grassman", quests = {
                { id = 95647, name = "Lost in the Thicket Things", dungeon = "Excavation Site: Wetlands", main = 95809, acts = { "end" } },
                { id = 95809, name = "Heartwoven", dungeon = "Excavation Site: Wetlands", acts = { "start" } },
            } },
        } },
        { floor = 1, x = 0.074, y = 0.497, spots = {
            { name = "Daewyn Songblade", quests = {
                { id = 95772, name = "Songblade Search", dungeon = "Excavation Site: Wetlands", acts = { "end" } },
                { id = 95795, name = "Fallen in the Fen", dungeon = "Excavation Site: Wetlands", acts = { "start" } },
            } },
        } },
    },
    ["Gnomeregan"] = {
        { floor = 1, x = 0.427, y = 0.660, spots = {
            { name = "The Sparklematic 5200", quests = {
                { id = 2951, name = "The Sparklematic 5200!", dungeon = "Gnomeregan", acts = { "start", "end" } },
                { id = 2945, name = "Grime-Encrusted Ring", dungeon = "Gnomeregan", main = 2948, acts = { "end" } },
                { id = 2947, name = "Return of the Ring", dungeon = "Gnomeregan", main = 2948, acts = { "start" } },
                { id = 2949, name = "Return of the Ring", dungeon = "Gnomeregan", main = 2950, acts = { "start" } },
            } },
        } },
        { floor = 4, x = 0.354, y = 0.177, spots = {
            { name = "Thermaplugg's Safe", quests = {
                { id = 2841, name = "Rig Wars", dungeon = "Gnomeregan", acts = { "loot" }, item = 9153, itemName = "Rig Blueprints" }, -- its own quest
            } },
        } },
    },
    ["Ragefire Chasm"] = {
        { floor = 1, x = 0.618, y = 0.387, spots = {
            { name = "Maur Grimtotem", quests = {
                { id = 5724, name = "Returning the Lost Satchel", dungeon = "Ragefire Chasm", acts = { "start" } },
                { id = 5722, name = "Searching for the Lost Satchel", dungeon = "Ragefire Chasm", main = 5724, acts = { "end" } },
            } },
        } },
    },
    ["Razorfen Downs"] = {
        { floor = 1, x = 0.775, y = 0.152, spots = {
            { name = "Belnistrasz", quests = {
                { id = 3525, name = "Extinguishing the Idol", dungeon = "Razorfen Downs", acts = { "start", "end" } },
                { id = 3523, name = "Scourge of the Downs", dungeon = "Razorfen Downs", main = 3525, acts = { "start", "end" } },
            } },
        } },
        { floor = 1, x = 0.469, y = 0.223, spots = {
            { name = "Belnistrasz's Brazier", quests = {
                { id = 3525, name = "Extinguishing the Idol", dungeon = "Razorfen Downs", acts = { "end" } },
            } },
        } },
    },
    ["Razorfen Kraul"] = {
        { floor = 1, x = 0.364, y = 0.324, spots = {
            { name = "Willix the Importer", quests = {
                { id = 1144, name = "Willix the Importer", dungeon = "Razorfen Kraul", acts = { "start", "end" } },
            } },
            { name = "Heralath Fallowbrook", quests = {
                { id = 1142, name = "Mortality Wanes", dungeon = "Razorfen Kraul", acts = { "start" } },
            } },
        } },
    },
    ["Ruins of Lordaeron"] = {
        { floor = 1, x = 0.612, y = 0.272, spots = {
            { name = "Captain Truman", quests = {
                { id = 95250, name = "Abominable Creatures", dungeon = "Ruins of Lordaeron", acts = { "start", "end" } },
            } },
        } },
    },
    ["Scarlet Monastery: Graveyard"] = {
        { floor = 1, x = 0.719, y = 0.514, spots = {
            { name = "Vorrel Sengutz", quests = {
                { id = 1051, name = "Vorrel's Revenge", dungeon = "Scarlet Monastery: Graveyard", acts = { "start" } },
            } },
        } },
    },
    ["Scarlet Monastery: Library"] = {
        { floor = 1, x = 0.593, y = 0.122, spots = {
            { name = "Mythology of the Titans", quests = {
                { id = 1050, name = "Mythology of the Titans", dungeon = "Scarlet Monastery: Library", acts = { "loot" }, item = 5536, itemName = "Mythology of the Titans" },
            } },
        } },
        { floor = 1, x = 0.822, y = 0.140, spots = {
            { name = "Compendium of the Fallen", quests = {
                { id = 1049, name = "Compendium of the Fallen", dungeon = "Scarlet Monastery: Library", acts = { "loot" }, item = 5535, itemName = "Compendium of the Fallen" },
            } },
        } },
        { floor = 1, x = 0.454, y = 0.322, spots = {
            { name = "Beginnings of the Undead Threat", quests = {
                { id = 1160, name = "Test of Lore", dungeon = "Scarlet Monastery: Library", main = 1394, acts = { "loot" }, item = 5861, itemName = "Beginnings of the Undead Threat" },
            } },
        } },
    },
    ["Shadowfang Keep"] = {
        { floor = 1, x = 0.336, y = 0.550, spots = {
            { name = "Jordan's Hammer", quests = {
                { id = 1654, name = "The Test of Righteousness", dungeon = "Shadowfang Keep", main = 1806, acts = { "loot" }, item = 6895, itemName = "Jordan's Smithing Hammer" },
            } },
        } },
        { floor = 1, x = 0.558, y = 0.622, spots = {
            { name = "Deathstalker Vincent", quests = {
                { id = 1098, name = "Deathstalkers in Shadowfang", dungeon = "Shadowfang Keep", acts = { "end" } },
            } },
        } },
        { floor = 3, x = 0.472, y = 0.793, spots = {
            { name = "The Book of Ur", quests = {
                { id = 1013, name = "The Book of Ur", dungeon = "Shadowfang Keep", acts = { "loot" }, item = 6283, itemName = "The Book of Ur" },
            } },
        } },
    },
    ["Stratholme: Living"] = {
        { floor = 1, x = 0.310, y = 0.408, spots = {
            { name = "Malor's Strongbox", quests = {
                { id = 5122, name = "The Medallion of Faith", dungeon = "Stratholme: Living", acts = { "loot" }, item = 12845, itemName = "Medallion of Faith" },
            } },
        } },
        { floor = 1, x = 0.307, y = 0.818, spots = {
            { name = "Scarlet Archive", quests = {
                { id = 5251, name = "The Archivist", dungeon = "Stratholme: Living", acts = { "use" } },
            } },
            { name = "Unfinished Painting", quests = {
                { id = 5848, name = "Of Love and Family", dungeon = "Stratholme: Living", acts = { "loot" }, item = 14679, itemName = "Of Love and Family" },
            } },
        } },
    },
    ["Stratholme: Undead"] = {
        { floor = 1, x = 0.695, y = 0.146, spots = {
            { name = "Scourge Data", quests = {
                { id = 5213, name = "The Active Agent", dungeon = "Stratholme: Undead", acts = { "loot" }, item = 13176, itemName = "Scourge Data" },
            } },
        } },
        { floor = 1, x = 0.414, y = 0.258, spots = {
            { name = "Menethil's Gift", quests = {
                { id = 5463, name = "Menethil's Gift", dungeon = "Stratholme: Undead", acts = { "end" } },
            } },
        } },
        { floor = 1, x = 0.803, y = 0.463, spots = {
            { name = "Scourge Data", quests = {
                { id = 5213, name = "The Active Agent", dungeon = "Stratholme: Undead", acts = { "loot" }, item = 13176, itemName = "Scourge Data" },
            } },
        } },
        { floor = 1, x = 0.530, y = 0.520, spots = {
            { name = "Scourge Data", quests = {
                { id = 5213, name = "The Active Agent", dungeon = "Stratholme: Undead", acts = { "loot" }, item = 13176, itemName = "Scourge Data" },
            } },
        } },
        { floor = 1, x = 0.678, y = 0.729, spots = {
            { name = "Aurius", quests = {
                { id = 5122, name = "The Medallion of Faith", dungeon = "Stratholme: Undead", main = 5125, acts = { "start", "end" } },
                { id = 5125, name = "Aurius' Reckoning", dungeon = "Stratholme: Undead", acts = { "start", "end" } },
            } },
        } },
    },
    ["Sunken Temple"] = {
        { floor = 1, x = 0.501, y = 0.358, spots = {
            { name = "Altar of Hakkar", quests = {
                { id = 3446, name = "Into the Depths", dungeon = "Sunken Temple", acts = { "end" } },
            } },
        } },
        { floor = 1, x = 0.501, y = 0.477, spots = {
            { name = "Idol of Hakkar", quests = {
                { id = 3447, name = "Secret of the Circle", dungeon = "Sunken Temple", acts = { "end" } },
            } },
        } },
        { floor = 1, x = 0.719, y = 0.803, spots = {
            { name = "Essence Font", quests = {
                { id = 3373, name = "The Essence of Eranikus", dungeon = "Sunken Temple", acts = { "end" } },
            } },
        } },
    },
    ["Uldaman"] = {
        -- pinclear (2.1.3, M 21 Nov 2026: "The tablet of will is also next to
        -- Galgann Firehammer. So you can put it a bit more to his left, but
        -- still inside the room"; was 0.207, 0.341)
        { floor = 1, x = 0.253, y = 0.327, spots = {
            { name = "Tablet of Will", quests = {
                { id = 1139, name = "The Lost Tablets of Will", dungeon = "Uldaman", acts = { "loot" }, item = 5824, itemName = "Tablet of Will" },
            } },
            { name = "Shadowforge Cache", quests = {
                { id = 2201, name = "Find the Gems", dungeon = "Uldaman", acts = { "loot" }, item = 7669, itemName = "Shattered Necklace Ruby" },
                { id = 2339, name = "Find the Gems and Power Source", dungeon = "Uldaman", acts = { "loot" }, item = 7669, itemName = "Shattered Necklace Ruby" },
            } },
        } },
        { floor = 1, x = 0.533, y = 0.638, spots = {
            { name = "Remains of a Paladin", quests = {
                { id = 2200, name = "Back to Uldaman", dungeon = "Uldaman", acts = { "end" } },
                { id = 2201, name = "Find the Gems", dungeon = "Uldaman", acts = { "start" } },
                { id = 2284, name = "Necklace Recovery, Take 2", dungeon = "Uldaman", acts = { "end" } },
                { id = 2318, name = "Translating the Journal", dungeon = "Uldaman", main = 2339, acts = { "start" } },
            } },
        } },
        -- pinclear (2.1.3, M 21 Nov 2026: "the hidden chamber question mark is
        -- wrong. It should be literally on the same spot as Ironaya ... in the
        -- same room": beside her, on the right; was 0.316, 0.719)
        { floor = 1, x = 0.388, y = 0.739, spots = {
            { quests = {
                { id = 2240, name = "The Hidden Chamber", dungeon = "Uldaman", acts = { "explore" } },
            } },
        } },
        -- pinclear (2.1.3, M 21 Nov 2026: The Lost Dwarves' ? "on the lost
        -- dwarf pin a little bit more to the left ... the same room"; was
        -- 0.638, 0.948)
        { floor = 1, x = 0.5665, y = 0.920, spots = {
            { name = "Baelog", quests = {
                { id = 2398, name = "The Lost Dwarves", dungeon = "Uldaman", acts = { "end" } },
                { id = 2240, name = "The Hidden Chamber", dungeon = "Uldaman", acts = { "start" } },
            } },
            { name = "Conspicuous Urn", quests = {
                { id = 2201, name = "Find the Gems", dungeon = "Uldaman", acts = { "loot" }, item = 7671, itemName = "Shattered Necklace Topaz" },
                { id = 2339, name = "Find the Gems and Power Source", dungeon = "Uldaman", acts = { "loot" }, item = 7671, itemName = "Shattered Necklace Topaz" },
            } },
        } },
        { floor = 2, x = 0.501, y = 0.331, spots = {
            { name = "The Discs of Norgannon", quests = {
                { id = 2278, name = "The Platinum Discs", dungeon = "Uldaman", acts = { "start", "end" } },
                { id = 2279, name = "The Platinum Discs", dungeon = "Uldaman", acts = { "start" } },
                { id = 2280, name = "The Platinum Discs", dungeon = "Uldaman", acts = { "start" } },
            } },
        } },
    },
}
-- END mapquests
