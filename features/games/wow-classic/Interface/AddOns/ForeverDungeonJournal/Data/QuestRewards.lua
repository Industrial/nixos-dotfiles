local ADDON_NAME, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS

FDJ.FOREVER_QUEST_XP_FALLBACK = {
    -- Offline quest XP. Client-cache values replace superseded server multipliers.
    [93594] = 360, -- Word of the Woods (Maraudon prerequisite; Forever)
    [96391] = 1050, -- Underground Map
    [95647] = 4900, -- Lost in the Thicket Things (Excavation Site prerequisite)
    [870] = 680,    -- The Forgotten Pools
    [877] = 1150,   -- The Stagnant Oasis
    [880] = 1150,   -- Altered Beings
    [1489] = 290,   -- Hamuul Runetotem
    [1490] = 115,   -- Nara Wildmane
    [865] = 1350,   -- Raptor Horns
    [65] = 1350,    -- Defias Brotherhood 1
    [132] = 680,    -- Defias Brotherhood 2
    [135] = 680,    -- Defias Brotherhood 3
    [141] = 340,    -- Defias Brotherhood 4
    [142] = 1350,   -- Defias Brotherhood 5
    [155] = 1700,   -- Defias Traitor escort
    [5722] = 880,   -- Searching for the Lost Satchel
    [5726] = 910,   -- Hidden Enemies 1
    [5727] = 460,   -- Hidden Enemies 2
    [3765] = 1450,  -- The Corruption Abroad
    [6564] = 1300,  -- Allegiance to the Old Gods
    [1198] = 2400,  -- In Search of Thaelrid
    [92742] = 460,  -- Testing the Wells
    [92744] = 460,  -- Murloc Gills
    [92745] = 490,  -- The State of the Mines
    [92747] = 580,  -- Moonbrook Espionage
    -- 92748 has no XP reward in the current Forever data.
    [92749] = 575,  -- A Dynamite Plan
    -- 92750 and 92751 have no XP reward in the current Forever data.
    [92752] = 580,  -- Explosive Consultation (return to Alba)
    [92753] = 1350, -- Destruction in Deadmines (dungeon step)
    [92819] = 680,  -- Destruction in Deadmines (detonator step)
    -- Hall of Thanes
    [96395] = 1050,
    [96403] = 1350,
    [96394] = 1050,
    [96393] = 1450,
    [98423] = 1150,

    -- Wailing Caverns
    [1486] = 1600,
    [962] = 1700,
    [1491] = 1350,
    [959] = 1350,
    [914] = 2200,
    [6981] = 2650,

    -- Ruins of Lordaeron
    [95250] = 1650,
    [97288] = 1650,
    [92401] = 2200,
    [95195] = 2600,
    [95189] = 2600,
    [95204] = 2600,
    [92421] = 2200,
    [92415] = 2600,
    [95216] = 2600,

    -- Deadmines
    [214] = 1250,
    [168] = 1350,
    [92753] = 1350,
    [167] = 1550,
    [2040] = 1550,
    [166] = 2600,
    [373] = 870,

    -- The Stockade prerequisite quests
    [303] = 2450,
    [1144] = 3050, -- Willix the Importer (client-cache base reward)
    [389] = 440,

    -- Blackfathom Deeps
    [971] = 2750,
    [1275] = 2400,
    [1198] = 2400,
    [1199] = 2550,
    [1200] = 3300,
    [6564] = 1300,
    [6562] = 435,
    [6563] = 1750,
    [6565] = 6300,  -- xpfix (2.0.10): Wowhead Forever (was 6489)
    [6561] = 3300,
    [6921] = 6550,  -- xpfix (2.0.10): Wowhead Forever (was 6746)
    [6922] = 7250,  -- xpfix (2.0.10): Wowhead Forever (was 7468)

    -- Ragefire Chasm
    [5723] = 1050,
    [5722] = 880,
    [5724] = 1450,
    [5728] = 1150,
    [5761] = 1150,
    [5725] = 1450,

    -- Shadowfang Keep
    [1098] = 2000,
    [1740] = 2550,
    [1013] = 2100,
    [1014] = 3300,
}

FDJ.FOREVER_QUEST_BASE_XP = {
    -- Hall of Thanes
    [96395] = 1050,
    [96403] = 1350,
    [96394] = 1050,
    [96393] = 1450,
    [98423] = 1150,

    -- Wailing Caverns
    [1486] = 1600,
    [962] = 1700,
    [1491] = 1350,
    [959] = 1350,
    [914] = 2200,
    [6981] = 2650,

    -- Ruins of Lordaeron
    [95250] = 1650,
    [97288] = 1650,
    [92401] = 2200,
    [95195] = 2600,
    [95189] = 2600,
    [95204] = 2600,
    [92421] = 2200,
    [92415] = 2600,
    [95216] = 2600,

    -- Deadmines
    [214] = 1250,
    [168] = 1350,
    [92753] = 1350,
    [167] = 1550,
    [2040] = 1550,
    [166] = 2600,
    [373] = 870,

    -- Razorfen Kraul
    [1144] = 3050, -- Willix the Importer Classic/base XP

    -- Blackfathom Deeps
    [971] = 2750,
    [1275] = 2400,
    [1198] = 2400,
    [1199] = 2550,
    [1200] = 3300,
    [6564] = 1300,
    [6562] = 435,
    [6563] = 1750,
    [6565] = 2650,
    [6561] = 3300,
    [6921] = 2750,

    -- Ragefire Chasm
    [5723] = 1050,
    [5722] = 880,
    [5724] = 1450,
    [5728] = 1150,
    [5761] = 1150,
    [5725] = 1450,

    -- Shadowfang Keep
    [1098] = 2000,
    [1740] = 2550,
    [1013] = 2100,
    [1014] = 3300,
}

FDJ.PREREQ_REWARD_ITEMS_FALLBACK = {
    -- Raptor Horns: both rewards are received.
    [865] = {
        items = {
            {5342, "Raptor Punch", 1},
            {5343, "Barkeeper's Cloak", 2},
        },
        choice = false,
    },
}

FDJ.PREREQ_REWARD_MONEY_FALLBACK = {
    [303] = 2500,
    [96391] = 700,
    [880] = 800,
    [5726] = 250,
    [6564] = 1100,
    [92742] = 250,
    [92744] = 250,
    [92745] = 300,
    [92747] = 400,
    [92749] = 200,
    [92752] = 400,
}
