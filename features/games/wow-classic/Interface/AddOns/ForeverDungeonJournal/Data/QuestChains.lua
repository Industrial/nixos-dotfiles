local ADDON_NAME, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
local ALBA_FAIRMOON_LOCATION = FDJ.Constants.ALBA_FAIRMOON_LOCATION

FDJ.QUEST_PREREQ_CHAINS = {
    -- These lists are intentionally "required to unlock" lists, not merely
    -- Wowhead storyline/series lists. Optional breadcrumbs are excluded.

    -- Hall of Thanes.
    -- Underground Map is the actual prerequisite for Old Ironforge Incursion.
    [96393] = {
        { id = 96391, name = "Underground Map" },
    },

    -- Wailing Caverns.
    -- Smart Drinks is only offered after completing Raptor Horns.
    [1491] = {
        { id = 865, name = "Raptor Horns" },
    },

    -- Required path to unlock Leaders of the Fang:
    -- Forgotten Pools -> Stagnant Oasis -> Altered Beings ->
    -- Hamuul Runetotem -> Nara Wildmane -> Leaders of the Fang.
    -- "The Barrens Oases" is an optional breadcrumb/alternate entry into the
    -- oasis chain, so it is deliberately not shown as required.
    [914] = {
        { id = 870, name = "The Forgotten Pools" },
        { id = 877, name = "The Stagnant Oasis" },
        { id = 880, name = "Altered Beings" },
        { id = 1489, name = "Hamuul Runetotem" },
        { id = 1490, name = "Nara Wildmane" },
    },

    -- Deadmines.
    -- Red Silk Bandanas has two gates: Red Leather Bandanas and progression
    -- through the Defias Brotherhood chain far enough to unlock the final
    -- VanCleef stage.
    [214] = {
        { id = 65, name = "The Defias Brotherhood" },
        { id = 132, name = "The Defias Brotherhood" },
        { id = 135, name = "The Defias Brotherhood" },
        { id = 141, name = "The Defias Brotherhood" },
        { id = 142, name = "The Defias Brotherhood" },
        { id = 155, name = "The Defias Brotherhood" },
    },

    -- Speak with Shoni is a breadcrumb into Underground Assault, not a hard
    -- prerequisite; Shoni offers Underground Assault directly.

    -- Final VanCleef quest: all earlier Defias Brotherhood steps are required.
    [166] = {
        { id = 65, name = "The Defias Brotherhood" },
        { id = 132, name = "The Defias Brotherhood" },
        { id = 135, name = "The Defias Brotherhood" },
        { id = 141, name = "The Defias Brotherhood" },
        { id = 142, name = "The Defias Brotherhood" },
        { id = 155, name = "The Defias Brotherhood" },
    },

    -- Forever's Toxic Soil storyline is sequential; every prior step below is
    -- required before the dungeon step Destruction in Deadmines (92753).
    [92753] = {
        { id = 92742, name = "Testing the Wells" },
        { id = 92744, name = "Murloc Gills" },
        { id = 92745, name = "The State of the Mines" },
        { id = 92747, name = "Moonbrook Espionage" },
        { id = 92748, name = "Explosive Consultation" },
        { id = 92749, name = "A Dynamite Plan" },
        { id = 92750, name = "Detonation at a Distance" },
        { id = 92751, name = "Detonation at a Distance" },
        { id = 92752, name = "Explosive Consultation" },
        { id = 92753, name = "Destruction in Deadmines" },
        { id = 92819, name = "Destruction in Deadmines" },
    },

    -- The Stockade.
    -- The Fury Runs Deep is only offered after completing The Dark Iron War.
    [378] = {
        { id = 303, name = "The Dark Iron War" },
    },

    -- The Stockade Riots is the dungeon step of the chain that begins with
    -- The Unsent Letter from Edwin VanCleef, followed by Bazil Thredd.
    [391] = {
        { id = 373, name = "The Unsent Letter" },
        { id = 389, name = "Bazil Thredd" },
    },

    -- Ragefire Chasm.
    [5728] = {
        { id = 5726, name = "Hidden Enemies" },
        { id = 5727, name = "Hidden Enemies" },
    },



    -- Gnomeregan ring chain. The faction-specific upgrade quest is the
    -- journal entry; Grime-Encrusted Ring and Return of the Ring are the
    -- required steps that unlock it.
    [2948] = {
        { id = 2945, name = "Grime-Encrusted Ring" },
        { id = 2947, name = "Return of the Ring" },
    },
    [2950] = {
        -- gnomerhorde (2.0.9): for the route: the ring drops inside, and it
        -- is cleaned at the Sparklematic inside, so both come after the run
        { id = 2945, name = "Grime-Encrusted Ring", startsInDungeon = true },
        { id = 2949, name = "Return of the Ring", needsDungeon = true },
    },

    -- Gnomeregan. Optional breadcrumb quests are intentionally excluded.
    -- Tinkmaster Overspark -> Save Techbot's Brain!, The Day After -> Gnogaine,
    -- and Castpipe's Task -> Data Rescue are storyline/breadcrumb links, not
    -- hard requirements in Forever. Gnogaine itself IS required before
    -- The Only Cure is More Green Glow.
    [2962] = {
        { id = 2926, name = "Gnogaine" },
    },
    -- rigwarsfix (2.0.9, M 16 Nov 2026): fixed in Forever, Rig Wars no longer
    -- has to be in the log for Chief Engineer Scooty; it is its own quest only.
    [2843] = {
        { id = 2842, name = "Chief Engineer Scooty" },
    },

    -- Razorfen Kraul / Scarlet Monastery: Graveyard.
    [1101] = {
        { id = 1100, name = "Lonebrow's Journal" },
    },
    [1113] = {
        { id = 1109, name = "Going, Going, Guano!" },
    },

    -- Blackfathom Deeps.
    -- Researching the Corruption intentionally has NO prerequisite entry here.
    -- The Corruption Abroad is an optional breadcrumb; Gershala offers it directly.
    -- The Essence of Aku'Mai intentionally has NO prerequisite entry here.
    -- Trouble in the Deeps is a breadcrumb and is not required to accept it.

    -- Gnomeregan: Data Rescue needs the Prismatic Punch Card, built up card
    -- by card through four Matrix Punchograph terminals. These are item
    -- steps (placeholder IDs), shown so players know the whole route.
    -- NOT a prerequisite: Data Rescue is picked up straight away. These
    -- are shown as a How to complete guide (QUEST_GUIDE_CHAINS below).
    [2930] = {
        { id = 2930001, name = "White Punch Card", itemStep = true },
        { id = 2930002, name = "Yellow Punch Card (Punchograph 3005-A)", itemStep = true },
        { id = 2930003, name = "Blue Punch Card (Punchograph 3005-B)", itemStep = true },
        { id = 2930004, name = "Red Punch Card (Punchograph 3005-C)", itemStep = true },
        { id = 2930005, name = "Prismatic Punch Card (Punchograph 3005-D)", itemStep = true },
    },

    [6565] = {
        { id = 6564, name = "Allegiance to the Old Gods" },
    },

    -- Excavation Site: Wetlands (Alliance): Horrors in the Highland only
    -- becomes available after completing Rethiel the Greenwarden's Wetlands
    -- chain. 2.0.38: The Greenwarden (463, First Mate Fitzsimmons in Menethil
    -- Harbor) is only a breadcrumb to Rethiel and no longer a required step:
    -- the chain starts with Tramping Paws at Rethiel himself.
    [95646] = {
        { id = 276, name = "Tramping Paws" },
        { id = 277, name = "Fire Taboo" },
        { id = 275, name = "Blisters on The Land" },
    },

    -- Excavation Site: Wetlands (Alliance): Highland Hides requires
    -- Young Crocolisk Skins. Daily Delivery is only a breadcrumb in Forever
    -- and is not required for Highland Hides.
    [98815] = {
        { id = 484, name = "Young Crocolisk Skins" },
    },

    -- Excavation Site: Wetlands (Horde): Dragonmaw Rumors is the
    -- required lead-in to Open the Maw.
    [95682] = {
        { id = 95663, name = "Dragonmaw Rumors" },
    },

    -- Excavation Site: Wetlands (Alliance): Heartwoven follows
    -- Lost in the Thicket Things.
    [95809] = {
        { id = 95647, name = "Lost in the Thicket Things" },
    },

    -- Dungeons added in 1.6.5.

    -- brotherinneed (2.0.8): Scarlet Monastery: Cathedral, Alliance Paladins.
    [79946] = {
        { id = 78088, name = "A Strange Artifact" },
        { id = 78089, name = "Advice From Stormwind" },
        { id = 78090, name = "A Second Opinion" },
        { id = 78091, name = "Earning Your Salt" },
        { id = 78092, name = "It Must Be Destroyed" },
        { id = 78093, name = "Return to Delgren" },
        { id = 96438, name = "Battle at the Mannoroc Coven" },
        { id = 79939, name = "The Broken Hammer" },
        { id = 79940, name = "A Lost Brother" },
        { id = 79945, name = "Orders from the Grand Crusader" },
    },
    [1053] = {
        { id = 261, name = "Down the Scarlet Path" },
        { id = 1052, name = "Down the Scarlet Path" },
    },
    [3525] = {
        { id = 3523, name = "Scourge of the Downs" },
    },
    [6521] = {
        { id = 6522, name = "An Unholy Alliance" },
    },
    [722] = {
        { id = 720, name = "A Sign of Hope" },
        { id = 721, name = "A Sign of Hope" },
    },
    [704] = {
        { id = 738, name = "Find Agmond" },
        { id = 739, name = "Murdaloc" },
    },
    [1139] = {
        { id = 720, name = "A Sign of Hope" },
        { id = 721, name = "A Sign of Hope" },
        { id = 722, name = "Amulet of Secrets" },
        { id = 723, name = "Prospect of Faith" },
        { id = 724, name = "Prospect of Faith" },
        { id = 725, name = "Passing Word of a Threat" },
        { id = 726, name = "Passing Word of a Threat" },
        { id = 762, name = "An Ambassador of Evil" },
    },
    [2201] = {
        { id = 2198, name = "The Shattered Necklace" },
        { id = 2199, name = "Lore for a Price" },
        { id = 2200, name = "Back to Uldaman" },
    },
    [2204] = {
        { id = 2198, name = "The Shattered Necklace" },
        { id = 2199, name = "Lore for a Price" },
        { id = 2200, name = "Back to Uldaman" },
        { id = 2201, name = "Find the Gems" },
    },
    [2339] = {
        { id = 2283, name = "Necklace Recovery" },
        { id = 2284, name = "Necklace Recovery, Take 2" },
        { id = 2318, name = "Translating the Journal" },
        { id = 2338, name = "Translating the Journal" },
    },
    [17] = {
        { id = 2500, name = "Badlands Reagent Run" },
    },
    [2202] = {
        { id = 2258, name = "Badlands Reagent Run" },
    },
    [2279] = {
        { id = 2278, name = "The Platinum Discs" },
    },
    [2280] = {
        { id = 2278, name = "The Platinum Discs" },
    },
    [1956] = {
        { id = 1954, name = "The Infernal Orb" },
        { id = 1955, name = "The Exorcism" },
    },
    [2991] = {
        { id = 2988, name = "Witherbark Cages" },
        { id = 2989, name = "The Altar of Zul" },
        { id = 2990, name = "Thadius Grimshade" },
    },
    [2936] = {
        { id = 2933, name = "Venom Bottles" },
        { id = 2934, name = "Undamaged Venom Sac" },
        { id = 2935, name = "Consult Master Gadrin" },
    },
    [3527] = {
        { id = 3520, name = "Screecher Spirits" },
    },
    [1475] = {
        { id = 1448, name = "In Search of The Temple" },
        { id = 1449, name = "To The Hinterlands" },
        { id = 1450, name = "Gryphon Master Talonaxe" },
        { id = 1451, name = "Rhapsody Shindigger" },
        { id = 1452, name = "Rhapsody's Kalimdor Kocktail" },
        { id = 1469, name = "Rhapsody's Tale" },
    },
    [1445] = {
        { id = 1424, name = "Pool of Tears" },
        { id = 1429, name = "The Atal'ai Exile" },
        { id = 1444, name = "Return to Fel'Zerul" },
    },
    [3446] = {
        { id = 3444, name = "The Stone Circle" },
    },
    [3447] = {
        { id = 3444, name = "The Stone Circle" },
    },
    [3528] = {
        { id = 3520, name = "Screecher Spirits" },
        { id = 3527, name = "The Prophecy of Mosh'aru" },
        { id = 4787, name = "The Ancient Egg" },
    },
    [4143] = {
        { id = 4141, name = "Muigin and Larion" },
        { id = 4142, name = "A Visit to Gregan" },
    },
    [4146] = {
        { id = 4145, name = "Larion and Muigin" },
        { id = 4147, name = "Marvon's Workshop" },
    },
    [9053] = {
        { id = 9052, name = "Bloodpetal Poison" },
        { id = 9051, name = "Toxic Test" },
    },
    [8232] = {
        { id = 8153, name = "Courser Antlers" },
        { id = 8231, name = "Wavethrashing" },
    },
    [8253] = {
        { id = 8251, name = "Magic Dust" },
        { id = 8252, name = "The Siren's Coral" },
    },
    [8418] = {
        { id = 8414, name = "Dispelling Evil" },
        { id = 8416, name = "Inert Scourgestones" },
    },
    [8257] = {
        { id = 8255, name = "Of Coursers We Know" },
        { id = 8256, name = "The Ichor of Undeath" },
    },
    [8236] = {
        { id = 8234, name = "Sealed Azure Bag" },
        { id = 8235, name = "Encoded Fragments" },
    },
    [8413] = {
        { id = 8410, name = "Elemental Mastery" },
        { id = 8412, name = "Spirit Totem" },
    },
    [8422] = {
        { id = 8419, name = "An Imp's Request" },
        { id = 8420, name = "Hot and Itchy" },
        { id = 8421, name = "The Wrong Stuff" },
    },
    [8425] = {
        { id = 8423, name = "Warrior Kinship" },
        { id = 8424, name = "War on the Shadowsworn" },
    },
    [3802] = {
        { id = 3801, name = "Dark Iron Legacy" },
    },
    [7046] = {
        { id = 7044, name = "Legends of Maraudon" },
    },
    -- Forever Maraudon: Word of the Woods (93594) is the direct prerequisite
    -- for Rot and Regret (93404), as listed in the Forever quest series.
    -- Hub-unlock prerequisites are not yet independently verified; use the
    -- temporary map placeholder on the Word of the Woods chain step.
    [93404] = {
        { id = 93594, name = "Word of the Woods", level = 43, requires = 35 },
    },
    [4263] = {
        { id = 4262, name = "Overmaster Pyron" },
    },
    [4362] = {
        { id = 3702, name = "The Smoldering Ruins of Thaurissan" },
        { id = 3701, name = "The Smoldering Ruins of Thaurissan" },
        { id = 4341, name = "Kharan Mighthammer" },
        { id = 4342, name = "Kharan's Tale" },
        { id = 4361, name = "The Bearer of Bad News" },
    },
    [4322] = {
        { id = 4182, name = "Dragonkin Menace" },
        { id = 4183, name = "The True Masters" },
        { id = 4184, name = "The True Masters" },
        { id = 4185, name = "The True Masters" },
        { id = 4186, name = "The True Masters" },
        { id = 4223, name = "The True Masters" },
        { id = 4224, name = "The True Masters" },
        { id = 4241, name = "Marshal Windsor" },
        { id = 4242, name = "Abandoned Hope" },
        { id = 4264, name = "A Crumpled Up Note" },
        { id = 4282, name = "A Shred of Hope" },
    },
    [3907] = {
        { id = 3906, name = "Disharmony of Flame" },
    },
    [7201] = {
        { id = 3906, name = "Disharmony of Flame" },
    },
    [4003] = {
        { id = 3906, name = "Disharmony of Flame" },
        { id = 3981, name = "Commander Gor'shak" },
        { id = 3982, name = "What Is Going On?" },
        { id = 4001, name = "What Is Going On?" },
        { id = 4002, name = "The Eastern Kingdoms" },
    },
    [3982] = {
        { id = 3906, name = "Disharmony of Flame" },
        { id = 3981, name = "Commander Gor'shak" },
    },
    [4082] = {
        { id = 4081, name = "KILL ON SIGHT: Dark Iron Dwarves" },
    },
    [4132] = {
        { id = 4081, name = "KILL ON SIGHT: Dark Iron Dwarves" },
        { id = 4082, name = "KILL ON SIGHT: High Ranking Dark Iron Officials" },
        { id = 4122, name = "Grark Lorkrub" },
        { id = 4121, name = "Precarious Predicament" },
    },
    [4063] = {
        { id = 4061, name = "The Rise of the Machines" },
        { id = 4062, name = "The Rise of the Machines" },
    },
    [5081] = {
        { id = 5001, name = "Bijou's Belongings" },
        { id = 5002, name = "Message to Maxwell" },
    },
    [4982] = {
        { id = 4981, name = "Operative Bijou" },
    },
    [4788] = {
        { id = 3520, name = "Screecher Spirits" },
        { id = 3527, name = "The Prophecy of Mosh'aru" },
        { id = 4787, name = "The Ancient Egg" },
        { id = 3528, name = "The God Hakkar" },
        { id = 5065, name = "The Lost Tablets of Mosh'aru" },
    },
    [4743] = {
        { id = 4742, name = "Seal of Ascension" },
    },
    [4735] = {
        { id = 4726, name = "Broodling Essence" },
        { id = 4808, name = "Felnok Steelspring" },
        { id = 4809, name = "Chillwind Horns" },
        { id = 4810, name = "Return to Tinkee" },
        { id = 4907, name = "Tinkee Steamboil" },
        { id = 4734, name = "Egg Freezing" },
    },
    [4974] = {
        { id = 4903, name = "Warlord's Command" },
        { id = 4941, name = "Eitrigg's Wisdom" },
    },
    [6569] = {
        { id = 4903, name = "Warlord's Command" },
        { id = 4941, name = "Eitrigg's Wisdom" },
        { id = 4974, name = "For The Horde!" },
        { id = 6566, name = "What the Wind Carries" },
        { id = 6567, name = "The Champion of the Horde" },
        { id = 6568, name = "The Testament of Rexxar" },
    },
    [6502] = {
        { id = 4182, name = "Dragonkin Menace" },
        { id = 4183, name = "The True Masters" },
        { id = 4184, name = "The True Masters" },
        { id = 4185, name = "The True Masters" },
        { id = 4186, name = "The True Masters" },
        { id = 4223, name = "The True Masters" },
        { id = 4224, name = "The True Masters" },
        { id = 4241, name = "Marshal Windsor" },
        { id = 4242, name = "Abandoned Hope" },
        { id = 4264, name = "A Crumpled Up Note" },
        { id = 4282, name = "A Shred of Hope" },
        { id = 4322, name = "Jail Break!" },
        { id = 6402, name = "Stormwind Rendezvous" },
        { id = 6403, name = "The Great Masquerade" },
        { id = 6501, name = "The Dragon's Eye" },
    },
    [6602] = {
        { id = 4903, name = "Warlord's Command" },
        { id = 4941, name = "Eitrigg's Wisdom" },
        { id = 4974, name = "For The Horde!" },
        { id = 6566, name = "What the Wind Carries" },
        { id = 6567, name = "The Champion of the Horde" },
        { id = 6568, name = "The Testament of Rexxar" },
        { id = 6569, name = "Oculus Illusions" },
        { id = 6570, name = "Emberstrife" },
        { id = 6582, name = "The Test of Skulls, Scryer" },
        { id = 6583, name = "The Test of Skulls, Somnus" },
        { id = 6584, name = "The Test of Skulls, Chronalis" },
        { id = 6585, name = "The Test of Skulls, Axtroz" },
        { id = 6601, name = "Ascension..." },
    },
    [5102] = {
        { id = 5089, name = "General Drakkisath's Command" },
    },
    [5526] = {
        { id = 5527, name = "A Reliquary of Purity" },
    },
    [5247] = {
        { id = 5244, name = "The Ruins of Kel'Theril" },
        { id = 5245, name = "Troubled Spirits of Kel'Theril" },
        { id = 5246, name = "Fragments of the Past" },
    },
    [7643] = {
        { id = 7637, name = "Emphasis on Sacrifice" },
        { id = 7639, name = "To Show Due Judgment" },
        { id = 7640, name = "Exorcising Terrordale" },
        { id = 7641, name = "The Work of Grimand Elmore" },
        { id = 7642, name = "Collection of Goods" },
        { id = 7648, name = "Grimand's Finest Work" },
        { id = 7645, name = "Manna-Enriched Horse Feed" },
    },
    [7631] = {
        { id = 7563, name = "Rage of Blood" },
        { id = 7564, name = "Wildeyes" },
        { id = 7623, name = "Lord Banehollow" },
        { id = 7624, name = "Ulathek the Traitor" },
        { id = 7625, name = "Xorothian Stardust" },
        { id = 7626, name = "Bell of Dethmoora" },
        { id = 7627, name = "Wheel of the Black March" },
        { id = 7628, name = "Doomsday Candle" },
        { id = 7629, name = "Imp Delivery" },
        { id = 7630, name = "Arcanite" },
    },
    [5515] = {
        { id = 5382, name = "Doctor Theolen Krastinov, the Butcher" },
    },
    [5384] = {
        { id = 5382, name = "Doctor Theolen Krastinov, the Butcher" },
        { id = 5515, name = "Krastinov's Bag of Horrors" },
    },
    [5466] = {
        { id = 5382, name = "Doctor Theolen Krastinov, the Butcher" },
        { id = 5515, name = "Krastinov's Bag of Horrors" },
        { id = 5384, name = "Kirtonos the Herald" },
        { id = 5461, name = "The Human, Ras Frostwhisper" },
        { id = 5462, name = "The Dying, Ras Frostwhisper" },
        { id = 5463, name = "Menethil's Gift" },
        { id = 5464, name = "Menethil's Gift" },
        { id = 5465, name = "Soulbound Keepsake" },
    },
    [4771] = {
        { id = 4726, name = "Broodling Essence" },
        { id = 4808, name = "Felnok Steelspring" },
        { id = 4809, name = "Chillwind Horns" },
        { id = 4810, name = "Return to Tinkee" },
        { id = 4907, name = "Tinkee Steamboil" },
        { id = 4734, name = "Egg Freezing" },
        { id = 4735, name = "Egg Collection" },
        { id = 5522, name = "Leonid Barthalomew" },
        { id = 5531, name = "Betina Bigglezink" },
    },
    [7629] = {
        { id = 7563, name = "Rage of Blood" },
        { id = 7564, name = "Wildeyes" },
        { id = 7623, name = "Lord Banehollow" },
        { id = 7624, name = "Ulathek the Traitor" },
        { id = 7625, name = "Xorothian Stardust" },
    },
    [7647] = {
        { id = 7637, name = "Emphasis on Sacrifice" },
        { id = 7639, name = "To Show Due Judgment" },
        { id = 7640, name = "Exorcising Terrordale" },
        { id = 7641, name = "The Work of Grimand Elmore" },
        { id = 7642, name = "Collection of Goods" },
        { id = 7648, name = "Grimand's Finest Work" },
        { id = 7645, name = "Manna-Enriched Horse Feed" },
        { id = 7643, name = "Ancient Equine Spirit" },
        { id = 7644, name = "Blessed Arcanite Barding" },
        { id = 7646, name = "The Divination Scryer" },
    },
    [7668] = {
        { id = 7667, name = "Material Assistance" },
    },
    [5262] = {
        { id = 5251, name = "The Archivist" },
    },
    [5848] = {
        { id = 5542, name = "Demon Dogs" },
        { id = 5543, name = "Blood Tinged Skies" },
        { id = 5544, name = "Carrion Grubbage" },
        { id = 5742, name = "Redemption" },
        { id = 5781, name = "Of Forgotten Memories" },
        { id = 5845, name = "Of Lost Honor" },
        { id = 5846, name = "Of Love and Family" },
    },
    [5213] = {
        { id = 5212, name = "The Flesh Does Not Lie" },
    },
    [5263] = {
        { id = 5251, name = "The Archivist" },
        { id = 5262, name = "The Truth Comes Crashing Down" },
    },
    [6163] = {
        { id = 6133, name = "The Ranger Lord's Behest" },
        { id = 6042, name = "Un-Life's Little Annoyances" },
        { id = 6022, name = "To Kill With Purpose" },
        { id = 6135, name = "Duskwing, Oh How I Hate Thee..." },
        { id = 6136, name = "The Corpulent One" },
    },
    [5463] = {
        { id = 5382, name = "Doctor Theolen Krastinov, the Butcher" },
        { id = 5515, name = "Krastinov's Bag of Horrors" },
        { id = 5384, name = "Kirtonos the Herald" },
        { id = 5461, name = "The Human, Ras Frostwhisper" },
        { id = 5462, name = "The Dying, Ras Frostwhisper" },
    },
    [5125] = {
        { id = 5122, name = "The Medallion of Faith" },
    },
}

FDJ.QUEST_PREREQ_DETAILS = {
    -- Maraudon (Forever): temporary, offline-safe first-step page while
    -- the Shen'dralas quest-hub unlock requirements are being researched.
    [93594] = {
        level = 43,
        requires = 35,
        -- Temporary instruction page until the complete hub-unlock chain is verified.
        hubPlaceholder = true,
        objective = "Need to unlock |cffffd36bShen'dralas|r quest hub.\nUpdating soon with full details",
        -- Evenshade's Overlook: documented location of Mordent Evenshade.
        -- This marks a known Shen'dralas questing landmark, not a verified
        -- exact pickup NPC for Word of the Woods.
        hubMap = {
            mapID = 2652, x = 0.350, y = 0.466,
            label = "Shen'dralas quest hub - Evenshade's Overlook",
            detail = "Evenshade's Overlook, Shen'dralas (35.0, 46.6); temporary hub marker",
        },
    },

    -- brotherinneed (2.0.8): M's audit, 15 Nov 2026. Places as players give them.
    [78088] = { objective = "Loot the Strange Orb on top of the Tower of Althalaxx in Darkshore and bring it to Delgren the Purifier in Ashenvale.",
        pickup = "Strange Orb, top of the Tower of Althalaxx, Darkshore", turnin = "Delgren the Purifier, Maestra's Post, Ashenvale",
        startObject = {"Strange Orb", "Interface\\Icons\\INV_Misc_Orb_05", "On top of the Tower of Althalaxx, Darkshore (about 56.2, 26.4)"},
        map = { mapID = 1439, x = 0.562, y = 0.264, label = "Strange Orb — Tower of Althalaxx, Darkshore", detail = "On top of the tower" },
        turninMap = { mapID = 1440, x = 0.262, y = 0.387, label = "Delgren the Purifier — Ashenvale", targetName = "Delgren the Purifier" } },
    [78089] = { objective = "Speak with Katherine the Pure in the Cathedral of Light in Stormwind.",
        pickup = "Delgren the Purifier, Ashenvale", turnin = "Katherine the Pure, Cathedral of Light, Stormwind",
        map = { mapID = 1440, x = 0.262, y = 0.387, label = "Delgren the Purifier — Ashenvale", targetName = "Delgren the Purifier" },
        turninMap = { mapID = 1453, x = 0.485, y = 0.491, label = "Katherine the Pure — Cathedral of Light, Stormwind", targetName = "Katherine the Pure" } },
    [78090] = { objective = "Speak with Ursula Deline in the Mage Quarter of Stormwind.",
        pickup = "Katherine the Pure, Cathedral of Light, Stormwind", turnin = "Ursula Deline, Mage Quarter, Stormwind",
        map = { mapID = 1453, x = 0.485, y = 0.491, label = "Katherine the Pure — Cathedral of Light, Stormwind", targetName = "Katherine the Pure" } },
    [78091] = { objective = "Collect 14 Summoner's Salt from the Blackrock orcs in Redridge Mountains and return to Ursula Deline.",
        pickup = "Ursula Deline, Mage Quarter, Stormwind", turnin = "Ursula Deline, Mage Quarter, Stormwind" },
    [78092] = { objective = "Collect 12 Motes of Mannoroth from the demons in Demon Fall Canyon, Ashenvale, then use the Spear of Mannoroth there to destroy the orb.",
        pickup = "Ursula Deline, Mage Quarter, Stormwind", turnin = "Spear of Mannoroth, Demon Fall Canyon, Ashenvale",
        objectiveMap = { mapID = 1440, x = 0.890, y = 0.770, label = "Spear of Mannoroth — Demon Fall Canyon, Ashenvale" } },
    [78093] = { objective = "Bring the Orb Fragments to Delgren the Purifier in Ashenvale. Reward: Cloak of the Divine Storm.",
        pickup = "Shattered Orb, Demon Fall Canyon, Ashenvale", turnin = "Delgren the Purifier, Ashenvale",
        map = { mapID = 1440, x = 0.890, y = 0.770, label = "Shattered Orb — Demon Fall Canyon, Ashenvale" },
        turninMap = { mapID = 1440, x = 0.262, y = 0.387, label = "Delgren the Purifier — Ashenvale", targetName = "Delgren the Purifier" } },
    [96438] = { requires = 35, objective = "Investigate the Broken Warhammer at the Mannoroc Coven in Desolace.",
        pickup = "Katherine the Pure, Cathedral of Light, Stormwind", turnin = "Broken Warhammer, Mannoroc Coven, Desolace",
        map = { mapID = 1453, x = 0.485, y = 0.491, label = "Katherine the Pure — Cathedral of Light, Stormwind", targetName = "Katherine the Pure" },
        turninMap = { mapID = 1443, x = 0.527, y = 0.848, label = "Broken Warhammer — Mannoroc Coven, Desolace" } },
    [79939] = { requires = 35, objective = "Find the Torn Letter (a player reports it from a Burning Blade Summoner) and return to Katherine the Pure.",
        pickup = "Broken Warhammer, Mannoroc Coven, Desolace", turnin = "Katherine the Pure, Cathedral of Light, Stormwind",
        map = { mapID = 1443, x = 0.527, y = 0.848, label = "Broken Warhammer — Mannoroc Coven, Desolace" },
        turninMap = { mapID = 1453, x = 0.485, y = 0.491, label = "Katherine the Pure — Cathedral of Light, Stormwind", targetName = "Katherine the Pure" } },
    [79940] = { requires = 35, objective = "Listen to Katherine the Pure about the hammer and Aeonas.",
        pickup = "Katherine the Pure, Cathedral of Light, Stormwind", turnin = "Katherine the Pure, Cathedral of Light, Stormwind",
        map = { mapID = 1453, x = 0.485, y = 0.491, label = "Katherine the Pure — Cathedral of Light, Stormwind", targetName = "Katherine the Pure" } },
    [79945] = { requires = 35, objective = "Players report: speak to the fishing trainer by the docks of Menethil Harbor, take the small boat south of the docks to Aeonas's hut on the coast, inspect the fallen Scarlet Crusader, defeat the level 40 elite assassin and loot the orders. Use them and return to Katherine the Pure.",
        pickup = "Orders, looted from the assassin at Aeonas's hut, Wetlands coast", turnin = "Katherine the Pure, Cathedral of Light, Stormwind",
        turninMap = { mapID = 1453, x = 0.485, y = 0.491, label = "Katherine the Pure — Cathedral of Light, Stormwind", targetName = "Katherine the Pure" } },

    -- Pre-quests for the dungeons added in 1.6.5.

    [261] = {
        level = 39, requires = 34,
        objective = "Destroy 30 Undead Ravagers, then return to Brother Anton at Nijel's Point.",
        pickup = "Brother Anton, Desolace",
        turnin = "Brother Anton, Desolace",
        map = { mapID = 1443, x = 0.664, y = 0.078, label = "Brother Anton — Desolace", targetName = "Brother Anton" },
        -- stepgoal (2.0.8): where it is done, until it is done
        objectiveMap = { mapID = 1443, x = 0.640, y = 0.820, label = "Undead Ravagers — Valley of Bones, Desolace", detail = "Through the arch with the red banners, south of the centaur village with the ponds" },
    },
    [1052] = {
        level = 40, requires = 34,
        objective = "Take Brother Anton's Letter of Commendation to Raleigh the Devout in Southshore.",
        pickup = "Brother Anton, Desolace",
        turnin = "Raleigh the Devout",
        map = { mapID = 1443, x = 0.664, y = 0.078, label = "Brother Anton — Desolace", targetName = "Brother Anton" },
    },
    [3523] = {
        startsInDungeon = true,
        level = 37, requires = 32,
        objective = "If you agree to aid Belnistrasz, speak with him again and hand the Oathstone he gave you back to him.",
        pickup = "Belnistrasz, Razorfen Downs",
        turnin = "Belnistrasz, Razorfen Downs",
    },
    [6522] = {
        level = 36, requires = 28,
        objective = "Take the Small Scroll to Varimathras in the Undercity.",
        pickup = "Small Scroll (drops from Charlga Razorflank in Razorfen Kraul)",
        turnin = "Varimathras, Undercity",
        startItem = {17008, "Small Scroll", 1, "Dropped by Charlga Razorflank in Razorfen Kraul"},
    },
    [720] = {
        level = 35, requires = 35,
        objective = "Find Prospector Ryedol and let him know Hammertoe Grez is alive.",
        pickup = "Crumpled Map",
        turnin = "Prospector Ryedol, Badlands",
        startObject = {"Crumpled Map", "Interface\\Icons\\INV_Misc_Map_01", "Lying at the dwarf dig site west of Hammertoe's Digsite, Badlands"},
        map = { mapID = 1418, x = 0.530, y = 0.341, label = "Crumpled Map — Badlands", targetName = "Crumpled Map" },
    },
    [721] = {
        level = 35, requires = 35,
        objective = "Find Hammertoe Grez in Uldaman.",
        pickup = "Prospector Ryedol, Badlands",
        turnin = "Hammertoe Grez, Uldaman excavation (outside the instance)",
    },
    [738] = {
        level = 38, requires = 30,
        objective = "Find Agmond.",
        pickup = "Prospector Ironband, Loch Modan",
        turnin = "Battered Dwarven Skeleton",
        map = { mapID = 1432, x = 0.658, y = 0.654, label = "Prospector Ironband — Loch Modan", targetName = "Prospector Ironband" },
    },
    [739] = {
        level = 42, requires = 30,
        objective = "Slay Agmond's killer, Murdaloc. Slay 12 Stonevault Bonesnappers. Report to Prospector Ironband in Loch Modan.",
        pickup = "Battered Dwarven Skeleton",
        turnin = "Prospector Ironband, Loch Modan",
        startObject = {"Battered Dwarven Skeleton", "Interface\\Icons\\INV_Misc_Bone_DwarfSkull_01", "On the ground at Agmond's End, southern Badlands"},
    },
    [722] = {
        level = 40, requires = 35,
        objective = "Find Hammertoe's Amulet and return it to him in Uldaman.",
        pickup = "Hammertoe Grez, Uldaman excavation (outside the instance)",
        turnin = "Hammertoe Grez, Uldaman excavation (outside the instance)",
    },
    [723] = {
        level = 40, requires = 35,
        objective = "Take Hammertoe's Amulet to Prospector Ryedol in the Badlands.",
        pickup = "Hammertoe Grez",
        turnin = "Prospector Ryedol, Badlands",
    },
    [724] = {
        level = 40, requires = 35,
        objective = "Take Hammertoe's Amulet to Historian Karnik in Ironforge.",
        pickup = "Prospector Ryedol, Badlands",
        turnin = "Historian Karnik, Ironforge",
        map = { mapID = 1418, x = 0.534, y = 0.432, label = "Prospector Ryedol — Badlands", targetName = "Prospector Ryedol" },
    },
    [725] = {
        level = 40, requires = 35,
        objective = "Find Advisor Belgrum and give him his note.",
        pickup = "Historian Karnik, Ironforge",
        turnin = "Advisor Belgrum, Ironforge",
        map = { mapID = 1455, x = 0.764, y = 0.122, label = "Historian Karnik — Ironforge", targetName = "Historian Karnik" },
    },
    [726] = {
        level = 40, requires = 35,
        objective = "Speak to Historian Karnik.",
        pickup = "Advisor Belgrum, Ironforge",
        turnin = "Historian Karnik, Ironforge",
        map = { mapID = 1455, x = 0.764, y = 0.108, label = "Advisor Belgrum — Ironforge", targetName = "Advisor Belgrum" },
    },
    [762] = {
        level = 44, requires = 35,
        objective = "Kill Ambassador Infernus in Angor Fortress and bring proof of his death to Advisor Belgrum in Ironforge.",
        pickup = "Historian Karnik, Ironforge",
        turnin = "Advisor Belgrum, Ironforge",
        map = { mapID = 1455, x = 0.764, y = 0.122, label = "Historian Karnik — Ironforge", targetName = "Historian Karnik" },
    },
    [2198] = {
        level = 41, requires = 37,
        objective = "Search for the original creator of the shattered necklace to learn of its potential value.",
        -- necklaceout (2.1.3, M 21 Nov 2026: "it's not a dungeon chain step. It
        -- doesn't start inside a dungeon ... The shattered necklace can drop from
        -- mobs outside as well"): the elites at the Uldaman dig site drop it
        -- (Wowhead Forever: Stonevault Rockchewer, Cave Hunter, Shadowforge
        -- Ruffian, Digger, Surveyor; Stonevault Oracle inside; SOURCES.txt).
        pickup = "Shattered Necklace (drops outside and in Uldaman)",
        turnin = "Talvash del Kissel, Ironforge",
        startItem = {7666, "Shattered Necklace", 2, "Drops from the elite troggs and Shadowforge dwarves outside Uldaman (and from troggs inside)"},
    },
    [2199] = {
        level = 41, requires = 37,
        objective = "Bring five silver bars to Talvash del Kissel in Ironforge.",
        pickup = "Talvash del Kissel, Ironforge",
        turnin = "Talvash del Kissel, Ironforge",
        map = { mapID = 1455, x = 0.360, y = 0.040, label = "Talvash del Kissel — Ironforge", targetName = "Talvash del Kissel" },
    },
    [2200] = {
        level = 42, requires = 37,
        objective = "Search for clues as to the current disposition of Talvash's necklace within Uldaman. The slain paladin he mentioned was the person who has it last.",
        pickup = "Talvash del Kissel, Ironforge",
        turnin = "Remains of a Paladin, Uldaman",
        map = { mapID = 1455, x = 0.360, y = 0.040, label = "Talvash del Kissel — Ironforge", targetName = "Talvash del Kissel" },
    },
    [2201] = {
        startsInDungeon = true,
        level = 43, requires = 37,
        objective = "Find the ruby, sapphire, and topaz that are scattered throughout Uldaman. Once acquired, contact Talvash del Kissel remotely by using the Phial of Scrying he previously gave you.",
        pickup = "Remains of a Paladin, Uldaman",
        turnin = "Talvash del Kissel (Phial of Scrying)",
    },
    [2283] = {
        level = 41, requires = 37,
        objective = "Look for a valuable necklace within the Uldaman dig site and bring it back to Dran Droffers in Orgrimmar. The necklace may be damaged.",
        pickup = "Dran Droffers, Orgrimmar",
        turnin = "Dran Droffers, Orgrimmar",
    },
    [2284] = {
        level = 41, requires = 37,
        objective = "Find a clue as to the gems' whereabouts in the depths of Uldaman.",
        pickup = "Dran Droffers, Orgrimmar",
        turnin = "Remains of a Paladin, Uldaman",
    },
    [2318] = {
        startsInDungeon = true,
        level = 42, requires = 37,
        objective = "Find someone who can translate the paladin's journal. The closest location that might have someone is Kargath, in the Badlands.",
        pickup = "Remains of a Paladin",
        turnin = "Jarkal Mossmeld, Badlands",
    },
    [2338] = {
        level = 42, requires = 37,
        objective = "Let Jarkal borrow the necklace. In exchange, he will translate the journal for you.",
        pickup = "Jarkal Mossmeld, Badlands",
        turnin = "Jarkal Mossmeld, Badlands",
        map = { mapID = 1418, x = 0.024, y = 0.460, label = "Jarkal Mossmeld — Badlands", targetName = "Jarkal Mossmeld" },
    },
    [2500] = {
        level = 39, requires = 36,
        objective = "Acquire the reagents Ghak Healtouch needs from the Badlands, then return to him in Thelsamar.",
        pickup = "Ghak Healtouch, Loch Modan",
        turnin = "Ghak Healtouch, Loch Modan",
        map = { mapID = 1432, x = 0.370, y = 0.492, label = "Ghak Healtouch — Loch Modan", targetName = "Ghak Healtouch" },
    },
    [2258] = {
        level = 39, requires = 36,
        objective = "Bring 5 Buzzard Gizzards, 10 Crag Coyote Fangs, and 5 Rock Elemental Shards to Jarkal Mossmeld in Kargath, Badlands.",
        pickup = "Jarkal Mossmeld, Badlands",
        turnin = "Jarkal Mossmeld, Badlands",
        map = { mapID = 1418, x = 0.024, y = 0.460, label = "Jarkal Mossmeld — Badlands", targetName = "Jarkal Mossmeld" },
    },
    [2278] = {
        startsInDungeon = true,
        level = 47, requires = 40,
        objective = "Speak with stone watcher and learn what ancient lore it keeps. Once you have learned what lore it has to offer, activate the Discs of Norgannon.",
        pickup = "The Discs of Norgannon, Uldaman",
        turnin = "The Discs of Norgannon, Uldaman",
        startObject = {"The Discs of Norgannon", "Interface\\Icons\\INV_Misc_PlatnumDisks", "In the Map Chamber beyond Archaedas, inside Uldaman"},
    },
    [1954] = {
        level = 40, requires = 35,
        objective = "Bring an Infernal Orb to Tabetha in Dustwallow Marsh.",
        pickup = "Tabetha, Dustwallow Marsh",
        turnin = "Tabetha, Dustwallow Marsh",
        map = { mapID = 1445, x = 0.460, y = 0.570, label = "Tabetha — Dustwallow Marsh", targetName = "Tabetha" },
    },
    [1955] = {
        level = 40, requires = 35,
        objective = "Kill the Demon of the Orb, then speak with Tabetha.",
        pickup = "Tabetha, Dustwallow Marsh",
        turnin = "Tabetha, Dustwallow Marsh",
        map = { mapID = 1445, x = 0.460, y = 0.570, label = "Tabetha — Dustwallow Marsh", targetName = "Tabetha" },
    },
    [2988] = {
        level = 45, requires = 40,
        objective = "Check the cages at the two Witherbark villages, then return to Gryphon Master Talonaxe.",
        pickup = "Gryphon Master Talonaxe, The Hinterlands",
        turnin = "Gryphon Master Talonaxe, The Hinterlands",
        map = { mapID = 1425, x = 0.098, y = 0.444, label = "Gryphon Master Talonaxe — The Hinterlands", targetName = "Gryphon Master Talonaxe" },
    },
    [2989] = {
        level = 48, requires = 40,
        objective = "Check the top of the Altar of Zul, then return to Gryphon Master Talonaxe.",
        pickup = "Gryphon Master Talonaxe, The Hinterlands",
        turnin = "Gryphon Master Talonaxe, The Hinterlands",
        map = { mapID = 1425, x = 0.098, y = 0.444, label = "Gryphon Master Talonaxe — The Hinterlands", targetName = "Gryphon Master Talonaxe" },
    },
    [2990] = {
        level = 47, requires = 40,
        objective = "Bring Sharpbeak's Feather to Thadius Grimshade in the Blasted Lands.",
        pickup = "Gryphon Master Talonaxe, The Hinterlands",
        turnin = "Thadius Grimshade",
        map = { mapID = 1425, x = 0.098, y = 0.444, label = "Gryphon Master Talonaxe — The Hinterlands", targetName = "Gryphon Master Talonaxe" },
    },
    [2933] = {
        level = 43, requires = 40,
        objective = "Bring a Venom Bottle to an apothecary in Tarren Mill.",
        pickup = "Venom Bottle",
        turnin = "Apothecary Lydon, Hillsbrad Foothills",
        startObject = {"Venom Bottle", "Interface\\Icons\\INV_Potion_19", "On the ground in the Witherbark troll camps, The Hinterlands"},
        map = { mapID = 1425, x = 0.230, y = 0.578, label = "Venom Bottles — The Hinterlands", targetName = "Venom Bottle" },
    },
    [2934] = {
        level = 45, requires = 40,
        objective = "Bring an Undamaged Venom Sac to Apothecary Lydon in Tarren Mill.",
        pickup = "Apothecary Lydon, Hillsbrad Foothills",
        turnin = "Apothecary Lydon, Hillsbrad Foothills",
        map = { mapID = 1424, x = 0.614, y = 0.192, label = "Apothecary Lydon — Hillsbrad Foothills", targetName = "Apothecary Lydon" },
    },
    [2935] = {
        level = 45, requires = 40,
        objective = "Speak with Master Gadrin in Sen'jin Village.",
        pickup = "Apothecary Lydon, Hillsbrad Foothills",
        turnin = "Master Gadrin",
        map = { mapID = 1424, x = 0.614, y = 0.192, label = "Apothecary Lydon — Hillsbrad Foothills", targetName = "Apothecary Lydon" },
    },
    [3520] = {
        level = 44, requires = 40,
        objective = "Capture the spirits of 3 screechers in Feralas, then return to Yeh'kinya in Steamwheedle Port.",
        pickup = "Yeh'kinya, Tanaris",
        turnin = "Yeh'kinya, Tanaris",
        map = { mapID = 1446, x = 0.670, y = 0.224, label = "Yeh'kinya — Tanaris", targetName = "Yeh'kinya" },
    },
    [1448] = {
        level = 43, requires = 38,
        objective = "Brohann Caskbelly in Stormwind wants you to search for the Temple of Atal'Hakkar.",
        pickup = "Brohann Caskbelly, Stormwind",
        turnin = "Brohann Caskbelly, Stormwind",
        map = { mapID = 1453, x = 0.695, y = 0.404, label = "Brohann Caskbelly — Stormwind", targetName = "Brohann Caskbelly" },
    },
    [1449] = {
        level = 43, requires = 38,
        objective = "Speak with High Thane Falstad Wildhammer at Aerie Peak in the Hinterlands.",
        pickup = "Brohann Caskbelly, Stormwind",
        turnin = "Falstad Wildhammer, The Hinterlands",
        map = { mapID = 1453, x = 0.695, y = 0.404, label = "Brohann Caskbelly — Stormwind", targetName = "Brohann Caskbelly" },
    },
    [1450] = {
        level = 43, requires = 38,
        objective = "Speak with Gryphon Master Talonaxe inside the Aerie Peak Aviary.",
        pickup = "Falstad Wildhammer, The Hinterlands",
        turnin = "Gryphon Master Talonaxe, The Hinterlands",
        map = { mapID = 1425, x = 0.118, y = 0.468, label = "Falstad Wildhammer — The Hinterlands", targetName = "Falstad Wildhammer" },
    },
    [1451] = {
        level = 43, requires = 38,
        objective = "Seek out Rhapsody Shindigger in The Hinterlands.",
        pickup = "Gryphon Master Talonaxe, The Hinterlands",
        turnin = "Rhapsody Shindigger, The Hinterlands",
        map = { mapID = 1425, x = 0.098, y = 0.444, label = "Gryphon Master Talonaxe — The Hinterlands", targetName = "Gryphon Master Talonaxe" },
    },
    [1452] = {
        level = 43, requires = 38,
        objective = "Rhapsody Shindigger in The Hinterlands wants you to bring him 3 Roc Gizzards, 3 Groddoc Livers and 3 Ironfur Livers.",
        pickup = "Rhapsody Shindigger, The Hinterlands",
        turnin = "Rhapsody Shindigger, The Hinterlands",
        map = { mapID = 1425, x = 0.268, y = 0.484, label = "Rhapsody Shindigger — The Hinterlands", targetName = "Rhapsody Shindigger" },
    },
    [1469] = {
        level = 43, requires = 38,
        objective = "Bring the Atal'ai Tablet Fragment to Brohann Caskbelly in Stormwind.",
        pickup = "Rhapsody Shindigger, The Hinterlands",
        turnin = "Brohann Caskbelly, Stormwind",
        map = { mapID = 1425, x = 0.268, y = 0.484, label = "Rhapsody Shindigger — The Hinterlands", targetName = "Rhapsody Shindigger" },
    },
    [1424] = {
        level = 43, requires = 38,
        objective = "Fel'zerul in Stonard wants you to gather 10 Atal'ai Artifacts.",
        pickup = "Fel'zerul, Swamp of Sorrows",
        turnin = "Fel'zerul, Swamp of Sorrows",
        map = { mapID = 1435, x = 0.480, y = 0.550, label = "Fel'zerul — Swamp of Sorrows", targetName = "Fel'zerul" },
    },
    [1429] = {
        level = 44, requires = 38,
        objective = "Bring the Bundle of Atal'ai Artifacts to the Atal'ai Exile in the Hinterlands.",
        pickup = "Fel'zerul, Swamp of Sorrows",
        turnin = "Atal'ai Exile, The Hinterlands",
        map = { mapID = 1435, x = 0.480, y = 0.550, label = "Fel'zerul — Swamp of Sorrows", targetName = "Fel'zerul" },
    },
    [1444] = {
        level = 44, requires = 38,
        objective = "Return to Fel'Zerul in Stonard.",
        pickup = "Atal'ai Exile, The Hinterlands",
        turnin = "Fel'zerul, Swamp of Sorrows",
        map = { mapID = 1425, x = 0.336, y = 0.752, label = "Atal'ai Exile — The Hinterlands", targetName = "Atal'ai Exile" },
    },
    [3444] = {
        level = 51, requires = 46,
        objective = "Retrieve the Stone Circle from Marvon Rivetseeker's workshop in Ratchet.",
        pickup = "Marvon Rivetseeker, Tanaris",
        turnin = "Marvon Rivetseeker, Tanaris",
        map = { mapID = 1446, x = 0.526, y = 0.458, label = "Marvon Rivetseeker — Tanaris", targetName = "Marvon Rivetseeker" },
    },
    [3527] = {
        level = 47, requires = 40,
        objective = "Bring the First and Second Mosh'aru Tablets to Yeh'kinya in Tanaris.",
        pickup = "Yeh'kinya, Steamwheedle Port, Tanaris",
        turnin = "Yeh'kinya, Steamwheedle Port, Tanaris",
    },
    [4787] = {
        level = 50, requires = 40,
        objective = "Bring the Ancient Egg to Yeh'kinya in Tanaris.",
        pickup = "Yeh'kinya, Tanaris",
        turnin = "Yeh'kinya, Tanaris",
        map = { mapID = 1446, x = 0.670, y = 0.224, label = "Yeh'kinya — Tanaris", targetName = "Yeh'kinya" },
    },
    [4141] = {
        level = 52, requires = 47,
        objective = "Collect 15 Bloodpetals and return to Muigin.",
        pickup = "Muigin, Un'Goro Crater",
        turnin = "Muigin, Un'Goro Crater",
        map = { mapID = 1449, x = 0.430, y = 0.094, label = "Muigin — Un'Goro Crater", targetName = "Muigin" },
    },
    [4142] = {
        level = 52, requires = 47,
        objective = "Take a Bloodpetal to Gregan Brewspewer in Feralas.",
        pickup = "Muigin, Un'Goro Crater",
        turnin = "Gregan Brewspewer, Feralas",
        map = { mapID = 1449, x = 0.430, y = 0.094, label = "Muigin — Un'Goro Crater", targetName = "Muigin" },
    },
    [4145] = {
        level = 52, requires = 47,
        objective = "Hunt 5 Bloodpetal Lashers, 5 Bloodpetal Threshers, 5 Bloodpetal Flayers and 5 Bloodpetal Trappers for Larion at Marshal's Refuge.",
        pickup = "Larion, Un'Goro Crater",
        turnin = "Larion, Un'Goro Crater",
        map = { mapID = 1449, x = 0.454, y = 0.086, label = "Larion — Un'Goro Crater", targetName = "Larion" },
    },
    [4147] = {
        level = 52, requires = 47,
        objective = "Travel to Marvon Rivetseeker's workshop in Ratchet.",
        pickup = "Larion, Un'Goro Crater",
        turnin = "Liv Rizzlefix, The Barrens",
        map = { mapID = 1449, x = 0.454, y = 0.086, label = "Larion — Un'Goro Crater", targetName = "Larion" },
    },
    [9052] = {
        level = 52, requires = 50,
        objective = "Collect 8 Bloodcap and 8 Gorishi Stings, and return to Torwa Pathfinder in Un'Goro Crater.",
        pickup = "Torwa Pathfinder, Un'Goro Crater",
        turnin = "Torwa Pathfinder, Un'Goro Crater",
        map = { mapID = 1449, x = 0.716, y = 0.760, label = "Torwa Pathfinder — Un'Goro Crater", targetName = "Torwa Pathfinder" },
    },
    [9051] = {
        level = 52, requires = 50,
        objective = "Stab a Devilsaur with the Devilsaur Barb. Return to Torwa Pathfinder in Un'Goro Crater when you have completed this task.",
        pickup = "Torwa Pathfinder, Un'Goro Crater",
        turnin = "Torwa Pathfinder, Un'Goro Crater",
        map = { mapID = 1449, x = 0.716, y = 0.760, label = "Torwa Pathfinder — Un'Goro Crater", targetName = "Torwa Pathfinder" },
    },
    [8153] = {
        level = 52, requires = 50,
        objective = "Bring a pair of Perfect Courser Antlers to Ogtinc in Azshara. Ogtinc resides atop the cliffs northeast of the Ruins of Eldarath.",
        pickup = "Ogtinc, Azshara",
        turnin = "Ogtinc, Azshara",
        map = { mapID = 1447, x = 0.424, y = 0.426, label = "Ogtinc — Azshara", targetName = "Ogtinc" },
    },
    [8231] = {
        level = 52, requires = 50,
        objective = "Bring 6 Wavethrasher Scales to Ogtinc in Azshara. Ogtinc resides atop the cliffs northeast the Ruins of Eldarath.",
        pickup = "Ogtinc, Azshara",
        turnin = "Ogtinc, Azshara",
        map = { mapID = 1447, x = 0.424, y = 0.426, label = "Ogtinc — Azshara", targetName = "Ogtinc" },
    },
    [8251] = {
        level = 52, requires = 50,
        objective = "Bring 10 Glittering Dust to Archmage Xylem.",
        pickup = "Archmage Xylem, Azshara",
        turnin = "Archmage Xylem, Azshara",
        map = { mapID = 1447, x = 0.292, y = 0.402, label = "Archmage Xylem — Azshara", targetName = "Archmage Xylem" },
    },
    [8252] = {
        level = 52, requires = 50,
        objective = "Collect 6 Enchanted Coral and return them to Archmage Xylem.",
        pickup = "Archmage Xylem, Azshara",
        turnin = "Archmage Xylem, Azshara",
        map = { mapID = 1447, x = 0.292, y = 0.402, label = "Archmage Xylem — Azshara", targetName = "Archmage Xylem" },
    },
    [8414] = {
        level = 52, requires = 50,
        objective = "Collect 20 Minion's Scourgestones and bring them to High Priest Thel'danis in the Western Plaguelands.",
        pickup = "Commander Ashlam Valorfist, Western Plaguelands",
        turnin = "High Priest Thel'danis, Western Plaguelands",
        map = { mapID = 1422, x = 0.428, y = 0.840, label = "Commander Ashlam Valorfist — Western Plaguelands", targetName = "Commander Ashlam Valorfist" },
    },
    [8416] = {
        level = 52, requires = 50,
        objective = "Bring the Inert Scourgestone to Commander Ashlan Valorfist in Chillwind Point.",
        pickup = "High Priest Thel'danis, Western Plaguelands",
        turnin = "Commander Ashlam Valorfist, Western Plaguelands",
        map = { mapID = 1422, x = 0.518, y = 0.824, label = "High Priest Thel'danis — Western Plaguelands", targetName = "High Priest Thel'danis" },
    },
    [8255] = {
        level = 52, requires = 50,
        objective = "Acquire 4 Healthy Courser Glands and bring them to Ogtinc in Azshara. Ogtinc resides atop the cliffs northeast the Ruins of Eldarath.",
        pickup = "Ogtinc, Azshara",
        turnin = "Ogtinc, Azshara",
        map = { mapID = 1447, x = 0.424, y = 0.426, label = "Ogtinc — Azshara", targetName = "Ogtinc" },
    },
    [8256] = {
        level = 52, requires = 50,
        objective = "Acquire an Ichor of Undeath for Ogtinc in Azshara. Ogtinc resides atop the cliffs northeast the Ruins of Eldarath.",
        pickup = "Ogtinc, Azshara",
        turnin = "Ogtinc, Azshara",
        map = { mapID = 1447, x = 0.424, y = 0.426, label = "Ogtinc — Azshara", targetName = "Ogtinc" },
    },
    [8234] = {
        level = 52, requires = 50,
        objective = "Retrieve the Sealed Azure Bag from the Timbermaw Shaman in Azshara. Then take the bag to Archmage Xylem, also found in Azshara.",
        pickup = "Lord Jorach Ravenholdt, Alterac Mountains",
        turnin = "Archmage Xylem, Azshara",
        map = { mapID = 1416, x = 0.860, y = 0.790, label = "Lord Jorach Ravenholdt — Alterac Mountains", targetName = "Lord Jorach Ravenholdt" },
    },
    [8235] = {
        level = 52, requires = 50,
        objective = "Bring 10 Encoded Fragments to Archmage Xylem in Azshara.",
        pickup = "Archmage Xylem, Azshara",
        turnin = "Archmage Xylem, Azshara",
        map = { mapID = 1447, x = 0.292, y = 0.402, label = "Archmage Xylem — Azshara", targetName = "Archmage Xylem" },
    },
    [8410] = {
        level = 52, requires = 50,
        objective = "Collect a sample of air, fire, earth and water for Bath'rah the Windwatcher.",
        pickup = "Beram Skychaser, Thunder Bluff",
        turnin = "Bath'rah the Windwatcher, Alterac Mountains",
        map = { mapID = 1456, x = 0.222, y = 0.190, label = "Beram Skychaser — Thunder Bluff", targetName = "Beram Skychaser" },
    },
    [8412] = {
        level = 52, requires = 50,
        objective = "Bring the pieces for the spirit totem to Bath'rah the Windwatcher.",
        pickup = "Bath'rah the Windwatcher, Alterac Mountains",
        turnin = "Bath'rah the Windwatcher, Alterac Mountains",
        map = { mapID = 1416, x = 0.804, y = 0.668, label = "Bath'rah the Windwatcher — Alterac Mountains", targetName = "Bath'rah the Windwatcher" },
    },
    [8419] = {
        level = 52, requires = 50,
        objective = "Bring a piece of felcloth to Impsy in Felwood.",
        pickup = "Your class trainer",
        turnin = "Impsy, Felwood",
    },
    [8420] = {
        level = 52, requires = 50,
        objective = "Bring a piece of felcloth to Impsy in Felwood.",
        pickup = "Impsy, Felwood",
        turnin = "Impsy, Felwood",
        map = { mapID = 1448, x = 0.414, y = 0.448, label = "Impsy — Felwood", targetName = "Impsy" },
    },
    [8421] = {
        level = 52, requires = 50,
        objective = "Bring 10 Rotting Wood and 4 Bloodvenom Essence to Impsy in Felwood.",
        pickup = "Impsy, Felwood",
        turnin = "Impsy, Felwood",
        map = { mapID = 1448, x = 0.414, y = 0.448, label = "Impsy — Felwood", targetName = "Impsy" },
    },
    [8423] = {
        level = 52, requires = 50,
        objective = "Kill 7 Helboar in the Blasted Lands and return to the Fallen Hero of the Horde.",
        pickup = "Fallen Hero of the Horde, Swamp of Sorrows",
        turnin = "Fallen Hero of the Horde, Swamp of Sorrows",
        map = { mapID = 1435, x = 0.342, y = 0.660, label = "Fallen Hero of the Horde — Swamp of Sorrows", targetName = "Fallen Hero of the Horde" },
    },
    [8424] = {
        level = 52, requires = 50,
        objective = "Slaughter the Shadowsworn in the Blasted Lands and return to the Fallen Hero of the Horde.",
        pickup = "Fallen Hero of the Horde, Swamp of Sorrows",
        turnin = "Fallen Hero of the Horde, Swamp of Sorrows",
        map = { mapID = 1435, x = 0.342, y = 0.660, label = "Fallen Hero of the Horde — Swamp of Sorrows", targetName = "Fallen Hero of the Horde" },
    },
    [3801] = {
        level = 52, requires = 48,
        objective = "Speak with Franclorn Forgewright if you are interested in obtaining a key to the city major.",
        pickup = "Franclorn Forgewright, Blackrock Mountain",
        turnin = "Franclorn Forgewright, Blackrock Mountain",
        warning = "You have to be dead to talk to this guy. He's in Blackrock Mountain, in a room while walking the chain down to BRD.",
    },
    [7044] = {
        level = 49, requires = 41,
        objective = "Recover the two parts of the Scepter of Celebras: the Celebrian Rod and the Celebrian Diamond. Find a way to speak with Celebras.",
        pickup = "Cavindra, Maraudon Orange Entrance, Desolace",
        turnin = "Celebras the Redeemed, Maraudon",
    },
    [4262] = {
        level = 52, requires = 48,
        objective = "Slay Overmaster Pyron and return to Jalinda Sprig. You recall Jalinda talking about Pyron guarding the quarry. Perhaps you should search there?",
        pickup = "Jalinda Sprig, Burning Steppes",
        turnin = "Jalinda Sprig, Burning Steppes",
        map = { mapID = 1428, x = 0.854, y = 0.700, label = "Jalinda Sprig — Burning Steppes", targetName = "Jalinda Sprig" },
    },
    [3702] = {
        level = 54, requires = 50,
        objective = "Listen to Royal Historian Archesonus recant the history of Thaurissan.",
        pickup = "Royal Historian Archesonus, Ironforge",
        turnin = "Royal Historian Archesonus, Ironforge",
        map = { mapID = 1455, x = 0.384, y = 0.554, label = "Royal Historian Archesonus — Ironforge", targetName = "Royal Historian Archesonus" },
    },
    [3701] = {
        level = 54, requires = 50,
        objective = "Venture to the Ruins of Thaurissan in the Burning Steppes and recover information from the Thaurissan Relics. Return to Royal Historian Archesonus when you have recovered the information.",
        pickup = "Royal Historian Archesonus, Ironforge",
        turnin = "Royal Historian Archesonus, Ironforge",
        map = { mapID = 1455, x = 0.384, y = 0.554, label = "Royal Historian Archesonus — Ironforge", targetName = "Royal Historian Archesonus" },
    },
    [4341] = {
        level = 59, requires = 50,
        objective = "Travel to Blackrock Depths and find Kharan Mighthammer. The King mentioned that Kharan was being held prisoner there - perhaps you should try looking for a prison.",
        pickup = "King Magni Bronzebeard, Ironforge",
        turnin = "Kharan Mighthammer",
        map = { mapID = 1455, x = 0.394, y = 0.558, label = "King Magni Bronzebeard — Ironforge", targetName = "King Magni Bronzebeard" },
    },
    [4342] = {
        startsInDungeon = true,
        level = 59, requires = 50,
        objective = "Listen as Kharan Mighthammer tells his story.",
        pickup = "Kharan Mighthammer",
        turnin = "Kharan Mighthammer",
    },
    [4361] = {
        startsInDungeon = true,
        level = 59, requires = 50,
        objective = "Return to Ironforge and deliver the bad news to King Magni Bronzebeard.",
        pickup = "Kharan Mighthammer",
        turnin = "King Magni Bronzebeard, Ironforge",
    },
    [4182] = {
        level = 54, requires = 48,
        objective = "Slay 15 Black Broodlings, 10 Black Dragonspawn, 4 Black Wyrmkin and 1 Black Drake. Return to Helendis Riverhorn when the task is complete.",
        pickup = "Helendis Riverhorn, Burning Steppes",
        turnin = "Helendis Riverhorn, Burning Steppes",
        map = { mapID = 1428, x = 0.854, y = 0.688, label = "Helendis Riverhorn — Burning Steppes", targetName = "Helendis Riverhorn" },
    },
    [4183] = {
        level = 54, requires = 48,
        objective = "Travel to Lakeshire and deliver Helendis Riverhorn's Letter to Magistrate Solomon.",
        pickup = "Helendis Riverhorn, Burning Steppes",
        turnin = "Magistrate Solomon, Redridge Mountains",
        map = { mapID = 1428, x = 0.854, y = 0.688, label = "Helendis Riverhorn — Burning Steppes", targetName = "Helendis Riverhorn" },
    },
    [4184] = {
        level = 54, requires = 48,
        objective = "Travel to Stormwind and deliver Solomon's Plea to Highlord Bolvar Fordragon. Bolvar resides in Stormwind Keep.",
        pickup = "Magistrate Solomon, Redridge Mountains",
        turnin = "Highlord Bolvar Fordragon, Stormwind",
        map = { mapID = 1433, x = 0.298, y = 0.446, label = "Magistrate Solomon — Redridge Mountains", targetName = "Magistrate Solomon" },
    },
    [4185] = {
        level = 54, requires = 48,
        objective = "Speak with Highlord Bolvar Fordragon after speaking with Lady Katrana Prestor.",
        pickup = "Highlord Bolvar Fordragon, Stormwind",
        turnin = "Highlord Bolvar Fordragon, Stormwind",
        map = { mapID = 1453, x = 0.802, y = 0.383, label = "Highlord Bolvar Fordragon — Stormwind", targetName = "Highlord Bolvar Fordragon" },
    },
    [4186] = {
        level = 54, requires = 48,
        objective = "Take Bolvar's Decree to Magistrate Solomon in Lakeshire.",
        pickup = "Highlord Bolvar Fordragon, Stormwind",
        turnin = "Magistrate Solomon, Redridge Mountains",
        map = { mapID = 1453, x = 0.802, y = 0.383, label = "Highlord Bolvar Fordragon — Stormwind", targetName = "Highlord Bolvar Fordragon" },
    },
    [4223] = {
        level = 54, requires = 48,
        objective = "Speak with Marshal Maxwell in the Burning Steppes.",
        pickup = "Magistrate Solomon, Redridge Mountains",
        turnin = "Marshal Maxwell, Burning Steppes",
        map = { mapID = 1433, x = 0.298, y = 0.446, label = "Magistrate Solomon — Redridge Mountains", targetName = "Magistrate Solomon" },
    },
    [4224] = {
        level = 54, requires = 48,
        objective = "Speak with Ragged John to learn of Marshal Windsor's fate and return to Marshal Maxwell when you have completed this task. You recall Marshal Maxwell telling you to search for him in a cave to the north.",
        pickup = "Marshal Maxwell, Burning Steppes",
        turnin = "Marshal Maxwell, Burning Steppes",
        map = { mapID = 1428, x = 0.846, y = 0.688, label = "Marshal Maxwell — Burning Steppes", targetName = "Marshal Maxwell" },
    },
    [4241] = {
        level = 54, requires = 48,
        objective = "Travel to Blackrock Mountain in the northwest and enter Blackrock Depths. Find out what became of Marshal Windsor. You recall Ragged John talking about Windsor being dragged off to a prison.",
        pickup = "Marshal Maxwell, Burning Steppes",
        turnin = "Marshal Windsor",
        map = { mapID = 1428, x = 0.846, y = 0.688, label = "Marshal Maxwell — Burning Steppes", targetName = "Marshal Maxwell" },
    },
    [4242] = {
        startsInDungeon = true,
        level = 54, requires = 48,
        objective = "Give Marshal Maxwell the bad news.",
        pickup = "Marshal Windsor",
        turnin = "Marshal Maxwell, Burning Steppes",
    },
    [4264] = {
        level = 58, requires = 50,
        objective = "You may have just stumbled on to something that Marshal Windsor would be interested in seeing. There may be hope, after all.",
        pickup = "A Crumpled Up Note (drops from Dark Iron dwarves)",
        turnin = "Marshal Windsor",
        startItem = {11446, "A Crumpled Up Note", 1, "Drops from Dark Iron dwarves in Blackrock Depths once Abandoned Hope is turned in"},
    },
    [4282] = {
        startsInDungeon = true,
        level = 58, requires = 50,
        objective = "Return Marshal Windsor's Lost Information. Marshal Windsor believes that the information is being held by Golem Lord Argelmach and General Angerforge.",
        pickup = "Marshal Windsor",
        turnin = "Marshal Windsor",
    },
    [3906] = {
        level = 52, requires = 48,
        objective = "Travel to the quarry in Blackrock Mountain and slay Overmaster Pyron. Return to Thunderheart when you have completed this assignment.",
        pickup = "Thunderheart, Badlands",
        turnin = "Thunderheart, Badlands",
        map = { mapID = 1418, x = 0.034, y = 0.482, label = "Thunderheart — Badlands", targetName = "Thunderheart" },
    },
    [3981] = {
        level = 52, requires = 48,
        objective = "Find Commander Gor'shak in Blackrock Depths. You recall that the crudely drawn picture of the orc included bars drawn over the portrait. Perhaps you should search for a prison of some sort.",
        pickup = "Galamav the Marksman, Badlands",
        turnin = "Commander Gor'shak",
        map = { mapID = 1418, x = 0.058, y = 0.474, label = "Galamav the Marksman — Badlands", targetName = "Galamav the Marksman" },
    },
    [3982] = {
        startsInDungeon = true,
        level = 54, requires = 48,
        objective = "Defend Gor'shak.",
        pickup = "Commander Gor'shak, Blackrock Depths",
        turnin = "Commander Gor'shak, Blackrock Depths",
    },
    [4001] = {
        startsInDungeon = true,
        level = 54, requires = 48,
        objective = "Speak with Kharan Mighthammer and gather information about Princess Moira Bronzebeard's kidnapping. Take that information to Thrall in Orgrimmar. You recall Gor'shak mentioning that Kharan is being held in a cell nearby.",
        pickup = "Commander Gor'shak",
        turnin = "Thrall, Orgrimmar",
    },
    [4002] = {
        level = 54, requires = 48,
        objective = "Speak with Thrall if you are prepared to take on the mission he has planned.",
        pickup = "Thrall, Orgrimmar",
        turnin = "Thrall, Orgrimmar",
        map = { mapID = 1454, x = 0.320, y = 0.378, label = "Thrall — Orgrimmar", targetName = "Thrall" },
    },
    [4081] = {
        level = 52, requires = 48,
        objective = "Venture to Blackrock Depths and destroy the vile aggressors! Warlord Goretooth wants you to kill 15 Anvilrage Guardsmen, 10 Anvilrage Wardens and 5 Anvilrage Footmen. Return to him once your task is complete.",
        pickup = "Wanted poster, Kargath, Badlands",
        turnin = "Warlord Goretooth, Kargath, Badlands",
        startObject = {"WANTED poster", "Interface\\Icons\\INV_Misc_Note_01", "On the wall in Kargath, Badlands"},
        map = { mapID = 1418, x = 0.038, y = 0.475, label = "WANTED poster — Kargath, Badlands", targetName = "WANTED" },
    },
    [4082] = {
        level = 54, requires = 50,
        objective = "Venture to Blackrock Depths and destroy the vile aggressors! Warlord Goretooth wants you to kill 10 Anvilrage Medics, 10 Anvilrage Soldiers and 10 Anvilrage Officers. Return to him once your task is complete.",
        pickup = "Wanted poster, Kargath, Badlands",
        turnin = "Warlord Goretooth, Kargath, Badlands",
        startObject = {"KILL ON SIGHT poster", "Interface\\Icons\\INV_Misc_Note_01", "On the wall in Kargath, Badlands"},
        map = { mapID = 1418, x = 0.040, y = 0.468, label = "KILL ON SIGHT poster — Kargath, Badlands", targetName = "KILL ON SIGHT" },
    },
    [4122] = {
        level = 58, requires = 52,
        objective = "Travel to the Burning Steppes and find Grark Lorkrub. You recall Lexlort mentioning that he was last seen in a massive Blackrock fortress. When you find Grark Lorkrub, use the Thorium Shackles to bind him and then lead him back through Blackrock Mountain to the Searing Gorge. Lexlort will have his men waiting on the other side to take Grark into custody.",
        pickup = "Lexlort, Badlands",
        turnin = "Grark Lorkrub, Burning Steppes",
        map = { mapID = 1418, x = 0.058, y = 0.474, label = "Lexlort — Badlands", targetName = "Lexlort" },
    },
    [4121] = {
        level = 58, requires = 52,
        objective = "Escort your prisoner, Grark Lorkrub, through Burning Steppes and through Blackrock Mountain to the Searing Gorge. You recall Lexlort mentioning that he would have his men waiting on the other side to take Grark into custody. You will also be required to hand over your Thorium Shackles to Lexlort.",
        pickup = "Grark Lorkrub, Burning Steppes",
        turnin = "Lexlort, Badlands",
        map = { mapID = 1428, x = 0.400, y = 0.346, label = "Grark Lorkrub — Burning Steppes", targetName = "Grark Lorkrub" },
    },
    [4061] = {
        level = 54, requires = 52,
        objective = "Venture to the Burning Steppes and recover 10 Fractured Elemental Shards for Hierophant Theodora Mulvadania. You recall Theodora mentioning the golems and elementals of that region as being a source for these shards.",
        pickup = "Hierophant Theodora Mulvadania, Badlands",
        turnin = "Hierophant Theodora Mulvadania, Badlands",
        map = { mapID = 1418, x = 0.030, y = 0.478, label = "Hierophant Theodora Mulvadania — Badlands", targetName = "Hierophant Theodora Mulvadania" },
    },
    [4062] = {
        level = 54, requires = 52,
        objective = "Take the Elemental Shard Sample to Lotwil Veriatus. You recall Theodora saying that Lotwil was stationed in a camp to the east.",
        pickup = "Hierophant Theodora Mulvadania, Badlands",
        turnin = "Lotwil Veriatus",
        map = { mapID = 1418, x = 0.030, y = 0.478, label = "Hierophant Theodora Mulvadania — Badlands", targetName = "Hierophant Theodora Mulvadania" },
    },
    [5001] = {
        startsInDungeon = true,
        level = 59, requires = 55,
        objective = "Find Bijou's Belongings and return them to her. Good luck!",
        pickup = "Bijou, Lower Blackrock Spire",
        turnin = "Bijou, Lower Blackrock Spire",
    },
    [5002] = {
        startsInDungeon = true,
        level = 59, requires = 55,
        objective = "Travel to the Burning Steppes and give Bijou's Information to Marshal Maxwell.",
        pickup = "Bijou",
        turnin = "Marshal Maxwell, Burning Steppes",
    },
    [4981] = {
        level = 59, requires = 55,
        objective = "Travel to Blackrock Spire and find out what happened to Bijou.",
        pickup = "Lexlort, Badlands",
        turnin = "Bijou",
        map = { mapID = 1418, x = 0.058, y = 0.474, label = "Lexlort — Badlands", targetName = "Lexlort" },
    },
    [3528] = {
        level = 53, requires = 40,
        objective = "Bring the Filled Egg of Hakkar to Yeh'kinya in Tanaris.",
        pickup = "Yeh'kinya, Steamwheedle Port, Tanaris",
        turnin = "Yeh'kinya, Steamwheedle Port, Tanaris",
    },
    [5065] = {
        level = 58, requires = 40,
        objective = "Bring the Third and Fourth Mosh'aru Tablets to Prospector Ironboot in Tanaris.",
        pickup = "Prospector Ironboot, Tanaris",
        turnin = "Prospector Ironboot, Tanaris",
        map = { mapID = 1446, x = 0.668, y = 0.240, label = "Prospector Ironboot — Tanaris", targetName = "Prospector Ironboot" },
    },
    [4742] = {
        startsInDungeon = true,
        level = 60, requires = 57,
        objective = "Find the three gemstones of command: the Gemstone of Smolderthorn, Gemstone of Spirestone and Gemstone of Bloodaxe. Return them, along with the Unadorned Seal of Ascension, to Vaelan. The generals are War Master Voone of the Smolderthorn, Highlord Omokk of the Spirestone and Overlord Wyrmthalak of the Bloodaxe.",
        pickup = "Vaelan (Scarshield Infiltrator), Lower Blackrock Spire",
        turnin = "Vaelan (Scarshield Infiltrator), Lower Blackrock Spire",
        requiredItems = {{12336, "Gemstone of Spirestone", 2, "Dropped by Highlord Omokk, Lower Blackrock Spire"}, {12335, "Gemstone of Smolderthorn", 2, "Dropped by War Master Voone, Lower Blackrock Spire"}, {12337, "Gemstone of Bloodaxe", 2, "Dropped by Overlord Wyrmthalak, Lower Blackrock Spire"}, {12219, "Unadorned Seal of Ascension", 1, "Random drop from Blackrock Spire trash"}},
    },
    [4726] = {
        level = 52, requires = 50,
        objective = "Bring 8 Broodling Essence and the Draco-Incarcinatrix 900 to Tinkee Steamboil at the Flame Crest in the Burning Steppes.",
        pickup = "Tinkee Steamboil, Burning Steppes",
        turnin = "Tinkee Steamboil, Burning Steppes",
        map = { mapID = 1428, x = 0.652, y = 0.238, label = "Tinkee Steamboil — Burning Steppes", targetName = "Tinkee Steamboil" },
    },
    [4808] = {
        level = 54, requires = 50,
        objective = "Give Tinkee's Letter to Felnok Steelspring.",
        pickup = "Tinkee Steamboil, Burning Steppes",
        turnin = "Felnok Steelspring, Winterspring",
        map = { mapID = 1428, x = 0.652, y = 0.238, label = "Tinkee Steamboil — Burning Steppes", targetName = "Tinkee Steamboil" },
    },
    [4809] = {
        level = 54, requires = 50,
        objective = "Bring 8 Uncracked Chillwind Horns to Felnok Steelspring.",
        pickup = "Felnok Steelspring, Winterspring",
        turnin = "Felnok Steelspring, Winterspring",
        map = { mapID = 1452, x = 0.614, y = 0.384, label = "Felnok Steelspring — Winterspring", targetName = "Felnok Steelspring" },
    },
    [4810] = {
        level = 54, requires = 50,
        objective = "Bring Felnok's Package to Tinkee Steamboil in the Burning Steppes.",
        pickup = "Felnok Steelspring, Winterspring",
        turnin = "Tinkee Steamboil, Burning Steppes",
        map = { mapID = 1452, x = 0.614, y = 0.384, label = "Felnok Steelspring — Winterspring", targetName = "Felnok Steelspring" },
    },
    [4907] = {
        level = 60, requires = 57,
        objective = "Speak with Tinkee Steamboil.",
        pickup = "Felnok Steelspring, Winterspring",
        turnin = "Tinkee Steamboil, Burning Steppes",
        map = { mapID = 1452, x = 0.614, y = 0.384, label = "Felnok Steelspring — Winterspring", targetName = "Felnok Steelspring" },
    },
    [4734] = {
        level = 60, requires = 57,
        objective = "Use the Eggscilloscope Prototype on an egg in the Rookery.",
        pickup = "Tinkee Steamboil, Burning Steppes",
        turnin = "Tinkee Steamboil, Burning Steppes",
        map = { mapID = 1428, x = 0.652, y = 0.238, label = "Tinkee Steamboil — Burning Steppes", targetName = "Tinkee Steamboil" },
    },
    [4903] = {
        level = 60, requires = 55,
        objective = "Slay Highlord Omokk, War Master Voone, and Overlord Wyrmthalak. Recover Important Blackrock Documents. Return to Warlord Goretooth in Kargath when the mission has been accomplished.",
        pickup = "Warlord Goretooth, Kargath, Badlands",
        turnin = "Warlord Goretooth, Kargath, Badlands",
    },
    [4941] = {
        level = 60, requires = 55,
        objective = "Speak with Eitrigg in Orgrimmar. When you have discussed matters with Eitrigg, seek council from Thrall. You recall having seen Eitrigg in Thrall's chamber.",
        pickup = "Warlord Goretooth, Badlands",
        turnin = "Thrall, Orgrimmar",
        map = { mapID = 1418, x = 0.058, y = 0.474, label = "Warlord Goretooth — Badlands", targetName = "Warlord Goretooth" },
    },
    [4974] = {
        level = 60, requires = 55,
        objective = "Travel to Blackrock Spire and slay Warchief Rend Blackhand. Take his head and return to Orgrimmar.",
        pickup = "Thrall, Orgrimmar",
        turnin = "Thrall, Orgrimmar",
        map = { mapID = 1454, x = 0.320, y = 0.378, label = "Thrall — Orgrimmar", targetName = "Thrall" },
    },
    [6566] = {
        level = 60, requires = 55,
        objective = "Listen to Thrall.",
        pickup = "Thrall, Orgrimmar",
        turnin = "Thrall, Orgrimmar",
        map = { mapID = 1454, x = 0.320, y = 0.378, label = "Thrall — Orgrimmar", targetName = "Thrall" },
    },
    [6567] = {
        level = 60, requires = 55,
        objective = "Seek out Rexxar. The Warchief has instructed you as to his whereabouts. Search the paths of Desolace, between the Stonetalon Mountains and Feralas.",
        pickup = "Thrall, Orgrimmar",
        turnin = "Rexxar, Feralas",
        map = { mapID = 1454, x = 0.320, y = 0.378, label = "Thrall — Orgrimmar", targetName = "Thrall" },
    },
    [6568] = {
        level = 60, requires = 55,
        objective = "Deliver Rexxar's Testament to Myranda the Hag in the Western Plaguelands.",
        pickup = "Rexxar, Feralas",
        turnin = "Myranda the Hag, Western Plaguelands",
        map = { mapID = 1444, x = 0.448, y = 0.074, label = "Rexxar — Feralas", targetName = "Rexxar" },
    },
    [4322] = {
        startsInDungeon = true,
        level = 58, requires = 50,
        objective = "Help Marshal Windsor get his gear back and free his friends. Return to Marshal Maxwell if you succeed.",
        pickup = "Marshal Windsor, Blackrock Depths",
        turnin = "Marshal Maxwell, Morgan's Vigil, Burning Steppes",
    },
    [6402] = {
        level = 60, requires = 50,
        objective = "Travel to Stormwind City and venture to the city gates. Speak with Squire Rowe so that he may let Marshal Windsor know that you have arrived.",
        pickup = "Marshal Maxwell, Burning Steppes",
        turnin = "Reginald Windsor, Elwynn Forest",
        map = { mapID = 1428, x = 0.846, y = 0.688, label = "Marshal Maxwell — Burning Steppes", targetName = "Marshal Maxwell" },
    },
    [6403] = {
        level = 60, requires = 50,
        objective = "Follow Reginald Windsor through Stormwind. Protect him from harm!",
        pickup = "Reginald Windsor, Elwynn Forest",
        turnin = "Highlord Bolvar Fordragon, Stormwind",
        map = { mapID = 1429, x = 0.320, y = 0.492, label = "Reginald Windsor — Elwynn Forest", targetName = "Reginald Windsor" },
    },
    [6501] = {
        level = 60, requires = 50,
        objective = "You must search the world for a being capable of restoring the power to the Fragment of the Dragon's Eye. The only information you possess about such a being is that they exist.",
        pickup = "Highlord Bolvar Fordragon, Stormwind",
        turnin = "Haleh, Winterspring",
        map = { mapID = 1453, x = 0.802, y = 0.383, label = "Highlord Bolvar Fordragon — Stormwind", targetName = "Highlord Bolvar Fordragon" },
    },
    [6569] = {
        level = 60, requires = 55,
        objective = "Travel to Blackrock Spire and collect 20 Black Dragonspawn Eyes. Return to Myranda the Hag when the task is complete.",
        pickup = "Myranda the Hag, Sorrow Hill, Western Plaguelands",
        turnin = "Myranda the Hag, Sorrow Hill, Western Plaguelands",
        map = { mapID = 1422, x = 0.508, y = 0.778, label = "Myranda the Hag — Western Plaguelands", targetName = "Myranda the Hag" },
    },
    [6570] = {
        level = 60, requires = 55,
        objective = "Travel to the Wyrmbog in Dustwallow Marsh and seek out Emberstrife's Den. Once inside, wear the Amulet of Draconic Subversion and speak with Emberstrife.",
        pickup = "Myranda the Hag, Western Plaguelands",
        turnin = "Emberstrife, Dustwallow Marsh",
        map = { mapID = 1422, x = 0.508, y = 0.778, label = "Myranda the Hag — Western Plaguelands", targetName = "Myranda the Hag" },
    },
    [6582] = {
        level = 60, requires = 55,
        objective = "You must find the blue dragonflight drake champion, Scryer, and slay him. Pry his skull from his corpse and return it to Emberstrife. You know that Scryer can be found in Winterspring.",
        pickup = "Emberstrife, Dustwallow Marsh",
        turnin = "Emberstrife, Dustwallow Marsh",
        map = { mapID = 1445, x = 0.562, y = 0.880, label = "Emberstrife — Dustwallow Marsh", targetName = "Emberstrife" },
    },
    [6583] = {
        level = 60, requires = 55,
        objective = "Destroy the drake champion of the Green Flight, Somnus. Take his skull and return it to Emberstrife.",
        pickup = "Emberstrife, Dustwallow Marsh",
        turnin = "Emberstrife, Dustwallow Marsh",
        map = { mapID = 1445, x = 0.562, y = 0.880, label = "Emberstrife — Dustwallow Marsh", targetName = "Emberstrife" },
    },
    [6584] = {
        level = 60, requires = 55,
        objective = "Guarding the Caverns of Time in the Tanaris Desert is Chronalis, child of Nozdormu. Destroy him and return his skull to Emberstrife.",
        pickup = "Emberstrife, Dustwallow Marsh",
        turnin = "Emberstrife, Dustwallow Marsh",
        map = { mapID = 1445, x = 0.562, y = 0.880, label = "Emberstrife — Dustwallow Marsh", targetName = "Emberstrife" },
    },
    [6585] = {
        level = 60, requires = 55,
        objective = "Travel to Grim Batol and track down Axtroz, drake champion of the Red Flight. Destroy him and take his skull. Return the skull to Emberstrife.",
        pickup = "Emberstrife, Dustwallow Marsh",
        turnin = "Emberstrife, Dustwallow Marsh",
        map = { mapID = 1445, x = 0.562, y = 0.880, label = "Emberstrife — Dustwallow Marsh", targetName = "Emberstrife" },
    },
    [6601] = {
        level = 60, requires = 55,
        objective = "It would appear as if the charade is over. You know that the Amulet of Draconic Subversion that Myranda the Hag created for you will not function inside Blackrock Spire. Perhaps you should find Rexxar and explain your predicament. Show him the Dull Drakefire Amulet. Hopefully he will know what to do next.",
        pickup = "Emberstrife, Dustwallow Marsh",
        turnin = "Rexxar, Feralas",
        map = { mapID = 1445, x = 0.562, y = 0.880, label = "Emberstrife — Dustwallow Marsh", targetName = "Emberstrife" },
    },
    [5089] = {
        level = 60, requires = 55,
        objective = "Take General Drakkisath's Command to Marshal Maxwell in Burning Steppes.",
        pickup = "General Drakkisath's Command (drops from Overlord Wyrmthalak)",
        turnin = "Marshal Maxwell, Burning Steppes",
        startItem = {12780, "General Drakkisath's Command", 1, "Dropped by Overlord Wyrmthalak in Lower Blackrock Spire"},
    },
    [5527] = {
        level = 60, requires = 56,
        objective = "Travel to Silithus and search for a Reliquary of Purity within the ruins of Southwind Village. If you are able to find it, return with it to Rabine Saturna in Nighthaven, Moonglade.",
        pickup = "Rabine Saturna, Moonglade",
        turnin = "Rabine Saturna, Moonglade",
        map = { mapID = 1450, x = 0.516, y = 0.444, label = "Rabine Saturna — Moonglade", targetName = "Rabine Saturna" },
    },
    [5244] = {
        level = 56, requires = 53,
        objective = "Speak with Jaron Stoneshaper in Starfall Village.",
        pickup = "Wynd Nightchaser, Winterspring",
        turnin = "Jaron Stoneshaper, Winterspring",
        map = { mapID = 1452, x = 0.520, y = 0.302, label = "Wynd Nightchaser — Winterspring", targetName = "Wynd Nightchaser" },
    },
    [5245] = {
        level = 56, requires = 53,
        objective = "Use Jaron's Pick to find the four Highborne Relic Fragments. Bring them to Aurora Skycaller in Eastern Plaguelands.",
        pickup = "Jaron Stoneshaper, Winterspring",
        turnin = "Aurora Skycaller, Eastern Plaguelands",
        map = { mapID = 1452, x = 0.520, y = 0.304, label = "Jaron Stoneshaper — Winterspring", targetName = "Jaron Stoneshaper" },
    },
    [5246] = {
        level = 56, requires = 53,
        objective = "Find the Sacred Highborne Writings in the Temple of Zin-Malor in Azshara, and bring them to Aurora Skycaller near the Northpass Tower in Eastern Plaguelands.",
        pickup = "Aurora Skycaller, Eastern Plaguelands",
        turnin = "Aurora Skycaller, Eastern Plaguelands",
        map = { mapID = 1423, x = 0.475, y = 0.168, label = "Aurora Skycaller — Eastern Plaguelands", targetName = "Aurora Skycaller" },
    },
    [7637] = {
        level = 60, requires = 60,
        objective = "Travel to Ironforge and get High Priest Rohan's Exorcism Censer. You will need to make a donation of 150 gold in order to secure it.",
        pickup = "Lord Grayson Shadowbreaker, Stormwind",
        turnin = "High Priest Rohan, Ironforge",
        map = { mapID = 1453, x = 0.484, y = 0.502, label = "Lord Grayson Shadowbreaker — Stormwind", targetName = "Lord Grayson Shadowbreaker" },
    },
    [7639] = {
        level = 60, requires = 60,
        objective = "Return the Exorcism Censer to Lord Grayson Shadowbreaker in the Cathedral District of Stormwind.",
        pickup = "High Priest Rohan, Ironforge",
        turnin = "Lord Grayson Shadowbreaker, Stormwind",
        map = { mapID = 1455, x = 0.247, y = 0.082, label = "High Priest Rohan — Ironforge", targetName = "High Priest Rohan" },
    },
    [7640] = {
        level = 60, requires = 60,
        objective = "Use the Exorcism Censer to drive out the spirits that torment Terrordale. When you have slain 25 Terrordale Spirits, return to Lord Grayson Shadowbreaker in the Cathedral District of Stormwind.",
        pickup = "Lord Grayson Shadowbreaker, Stormwind",
        turnin = "Lord Grayson Shadowbreaker, Stormwind",
        map = { mapID = 1453, x = 0.484, y = 0.502, label = "Lord Grayson Shadowbreaker — Stormwind", targetName = "Lord Grayson Shadowbreaker" },
    },
    [7641] = {
        level = 60, requires = 60,
        objective = "Speak with Grimand Elmore in Stormwind's Dwarven District.",
        pickup = "Lord Grayson Shadowbreaker, Stormwind",
        turnin = "Grimand Elmore, Stormwind",
        map = { mapID = 1453, x = 0.484, y = 0.502, label = "Lord Grayson Shadowbreaker — Stormwind", targetName = "Lord Grayson Shadowbreaker" },
    },
    [7642] = {
        level = 60, requires = 60,
        objective = "Bring 40 Runecloth, 6 Arcanite Bars, 10 Arthas' Tears, 5 Stratholme Holy Water vials, and 150 gold to Grimand Elmore in the Dwarven District of Stormwind.",
        pickup = "Grimand Elmore, Stormwind",
        turnin = "Grimand Elmore, Stormwind",
        map = { mapID = 1453, x = 0.597, y = 0.338, label = "Grimand Elmore — Stormwind", targetName = "Grimand Elmore" },
    },
    [7648] = {
        level = 60, requires = 60,
        objective = "Take the Arcanite Barding to Lord Grayson Shadowbreaker in Stormwind's Cathedral District for his inspection.",
        pickup = "Grimand Elmore, Stormwind",
        turnin = "Lord Grayson Shadowbreaker, Stormwind",
        map = { mapID = 1453, x = 0.597, y = 0.338, label = "Grimand Elmore — Stormwind", targetName = "Grimand Elmore" },
    },
    [7645] = {
        level = 60, requires = 60,
        objective = "Retrieve 20 Enriched Manna Biscuits - the key ingredient in making Manna-Enriched Horse Feed - for Merideth Carlson at Southshore in the Hillsbrad Foothills. The Argent Dawn is known as the sole purveyor of the biscuits. You also need to give her 50 gold to soothe her ruffled sensibilities.",
        pickup = "Merideth Carlson, Hillsbrad Foothills",
        turnin = "Merideth Carlson, Hillsbrad Foothills",
        map = { mapID = 1424, x = 0.520, y = 0.556, label = "Merideth Carlson — Hillsbrad Foothills", targetName = "Merideth Carlson" },
    },
    [7563] = {
        level = 58, requires = 60,
        objective = "Bring 30 bottles of Raging Beast's Blood to Mor'zul Bloodbringer in the Burning Steppes.",
        pickup = "Mor'zul Bloodbringer, Burning Steppes",
        turnin = "Mor'zul Bloodbringer, Burning Steppes",
        map = { mapID = 1428, x = 0.126, y = 0.314, label = "Mor'zul Bloodbringer — Burning Steppes", targetName = "Mor'zul Bloodbringer" },
    },
    [7564] = {
        level = 58, requires = 60,
        objective = "Bring the Case of Blood to Gorzeeki Wildeyes in the Burning Steppes.",
        pickup = "Mor'zul Bloodbringer, Burning Steppes",
        turnin = "Gorzeeki Wildeyes, Burning Steppes",
        map = { mapID = 1428, x = 0.126, y = 0.314, label = "Mor'zul Bloodbringer — Burning Steppes", targetName = "Mor'zul Bloodbringer" },
    },
    [7623] = {
        level = 58, requires = 60,
        objective = "Purchase Shadowy Potions from Gorzeeki in the Burning Steppes. Use the potions to travel through Jaedenar, and speak with Lord Banehollow.",
        pickup = "Gorzeeki Wildeyes, Burning Steppes",
        turnin = "Lord Banehollow, Felwood",
        map = { mapID = 1428, x = 0.124, y = 0.314, label = "Gorzeeki Wildeyes — Burning Steppes", targetName = "Gorzeeki Wildeyes" },
    },
    [7624] = {
        level = 58, requires = 60,
        objective = "Confront Ulathek, then bring The Traitor's Heart to Lord Banehollow in Jaedenar.",
        pickup = "Lord Banehollow, Felwood",
        turnin = "Lord Banehollow, Felwood",
        map = { mapID = 1448, x = 0.360, y = 0.444, label = "Lord Banehollow — Felwood", targetName = "Lord Banehollow" },
    },
    [7625] = {
        level = 60, requires = 60,
        objective = "Purchase Xorothian Stardust from Ur'dan. Bring it to Gorzeeki Wildeyes in the Burning Steppes.",
        pickup = "Lord Banehollow, Felwood",
        turnin = "Gorzeeki Wildeyes, Burning Steppes",
        map = { mapID = 1448, x = 0.360, y = 0.444, label = "Lord Banehollow — Felwood", targetName = "Lord Banehollow" },
    },
    [7626] = {
        level = 60, requires = 60,
        objective = "Bring 10 Elixirs of Shadow Power to Gorzeeki Wildeyes in the Burning Steppes.",
        pickup = "Mor'zul Bloodbringer, Burning Steppes",
        turnin = "Gorzeeki Wildeyes, Burning Steppes",
        map = { mapID = 1428, x = 0.126, y = 0.314, label = "Mor'zul Bloodbringer — Burning Steppes", targetName = "Mor'zul Bloodbringer" },
    },
    [7627] = {
        level = 60, requires = 60,
        objective = "Bring 6 Large Brilliant Shards and 25 Dark Iron Ore to Gorzeeki in the Burning Steppes.",
        pickup = "Mor'zul Bloodbringer, Burning Steppes",
        turnin = "Gorzeeki Wildeyes, Burning Steppes",
        map = { mapID = 1428, x = 0.126, y = 0.314, label = "Mor'zul Bloodbringer — Burning Steppes", targetName = "Mor'zul Bloodbringer" },
    },
    [7628] = {
        level = 60, requires = 60,
        objective = "Bring 35 Black Dragonscales to Gorzeeki Wildeyes in the Burning Steppes.",
        pickup = "Mor'zul Bloodbringer, Burning Steppes",
        turnin = "Gorzeeki Wildeyes, Burning Steppes",
        map = { mapID = 1428, x = 0.126, y = 0.314, label = "Mor'zul Bloodbringer — Burning Steppes", targetName = "Mor'zul Bloodbringer" },
    },
    [7629] = {
        level = 60, requires = 60,
        objective = "Bring the Imp in a Jar to the alchemy lab in the Scholomance. After the parchment is created, return the jar to Gorzeeki Wildeyes.",
        pickup = "Gorzeeki Wildeyes, Altar of Storms, Burning Steppes",
        turnin = "Gorzeeki Wildeyes, Altar of Storms, Burning Steppes",
        map = { mapID = 1428, x = 0.124, y = 0.314, label = "Gorzeeki Wildeyes — Burning Steppes", targetName = "Gorzeeki Wildeyes" },
    },
    [7630] = {
        level = 60, requires = 60,
        objective = "Bring 3 Arcanite Bars to Gorzeeki in the Burning Steppes.",
        pickup = "Gorzeeki Wildeyes, Burning Steppes",
        turnin = "Gorzeeki Wildeyes, Burning Steppes",
        map = { mapID = 1428, x = 0.124, y = 0.314, label = "Gorzeeki Wildeyes — Burning Steppes", targetName = "Gorzeeki Wildeyes" },
    },
    [5382] = {
        level = 60, requires = 55,
        objective = "Find Doctor Theolen Krastinov inside the Scholomance. Destroy him, then burn the Remains of Eva Sarkhoff and the Remains of Lucien Sarkhoff. Return to Eva Sarkhoff when the task is complete.",
        pickup = "Eva Sarkhoff, Caer Darrow, Western Plaguelands",
        turnin = "Eva Sarkhoff, Caer Darrow, Western Plaguelands",
    },
    [5515] = {
        level = 60, requires = 55,
        objective = "Locate Jandice Barov in the Scholomance and destroy her. From her corpse recover Krastinov's Bag of Horrors. Return the bag to Eva Sarkhoff.",
        pickup = "Eva Sarkhoff, Caer Darrow, Western Plaguelands",
        turnin = "Eva Sarkhoff, Caer Darrow, Western Plaguelands",
    },
    [5384] = {
        level = 60, requires = 55,
        objective = "Return to the Scholomance with the Blood of Innocents. Find the porch and place the Blood of Innocents in the brazier. Kirtonos will come to feast upon your soul. Fight valiantly, do not give an inch! Destroy Kirtonos and return to Eva Sarkhoff.",
        pickup = "Eva Sarkhoff, Caer Darrow, Western Plaguelands",
        turnin = "Eva Sarkhoff, Caer Darrow, Western Plaguelands",
    },
    [5461] = {
        level = 60, requires = 57,
        objective = "Travel to the Arathi Highlands, to the ruins of Stromgarde. Search Stromgarde for a Keepsake of Remembrance. If you find such an item, return with it to Magistrate Marduke.",
        pickup = "Magistrate Marduke, Western Plaguelands",
        turnin = "Magistrate Marduke, Western Plaguelands",
        map = { mapID = 1422, x = 0.704, y = 0.740, label = "Magistrate Marduke — Western Plaguelands", targetName = "Magistrate Marduke" },
    },
    [5462] = {
        level = 60, requires = 57,
        objective = "Travel to Light's Hope in Eastern Plaguelands and seek out Leonid Barthalomew the Revered. Show him the Keepsake of Remembrance and tell him all that you have discovered.",
        pickup = "Magistrate Marduke, Western Plaguelands",
        turnin = "Leonid Barthalomew the Revered, Eastern Plaguelands",
        map = { mapID = 1422, x = 0.704, y = 0.740, label = "Magistrate Marduke — Western Plaguelands", targetName = "Magistrate Marduke" },
    },
    [5463] = {
        level = 60, requires = 57,
        objective = "Travel to Stratholme and find Menethil's Gift. Place the Keepsake of Remembrance upon the unholy ground.",
        pickup = "Leonid Barthalomew the Revered, Light's Hope Chapel, Eastern Plaguelands",
        turnin = "Menethil's Gift, Stratholme",
        map = { mapID = 1423, x = 0.739, y = 0.490, label = "Leonid Barthalomew the Revered — Eastern Plaguelands", targetName = "Leonid Barthalomew the Revered" },
    },
    [5464] = {
        level = 60, requires = 57,
        objective = "Take the Soulbound Keepsake to Leonid Barthalomew in Eastern Plaguelands.",
        pickup = "Menethil's Gift",
        turnin = "Leonid Barthalomew the Revered, Eastern Plaguelands",
        startObject = {"Menethil's Gift", "Interface\\Icons\\Spell_Holy_PrayerOfSpirit", "The glowing rune on the floor of Baron Rivendare's room, Stratholme (Undead side)"},
    },
    [5465] = {
        level = 60, requires = 57,
        objective = "Return to Magistrate Marduke in Caer Darrow. Show him the Soulbound Keepsake.",
        pickup = "Leonid Barthalomew the Revered, Eastern Plaguelands",
        turnin = "Magistrate Marduke, Western Plaguelands",
        map = { mapID = 1423, x = 0.739, y = 0.490, label = "Leonid Barthalomew the Revered — Eastern Plaguelands", targetName = "Leonid Barthalomew the Revered" },
    },
    [4735] = {
        level = 60, requires = 57,
        objective = "Bring 8 Collected Dragon Eggs and the Collectronic Module to Tinkee Steamboil at Flame Crest in the Burning Steppes.",
        pickup = "Tinkee Steamboil, Flame Crest, Burning Steppes",
        turnin = "Tinkee Steamboil, Flame Crest, Burning Steppes",
    },
    [5522] = {
        level = 60, requires = 57,
        objective = "Bring the Frozen Eggs to Leonid Barthalomew in the Eastern Plaguelands.",
        pickup = "Tinkee Steamboil, Burning Steppes",
        turnin = "Leonid Barthalomew the Revered, Eastern Plaguelands",
        map = { mapID = 1428, x = 0.652, y = 0.238, label = "Tinkee Steamboil — Burning Steppes", targetName = "Tinkee Steamboil" },
    },
    [5531] = {
        level = 60, requires = 57,
        objective = "Bring the Frozen Eggs to Betina Bigglezink.",
        pickup = "Leonid Barthalomew the Revered, Eastern Plaguelands",
        turnin = "Betina Bigglezink",
        map = { mapID = 1423, x = 0.739, y = 0.490, label = "Leonid Barthalomew the Revered — Eastern Plaguelands", targetName = "Leonid Barthalomew the Revered" },
    },
    [7643] = {
        level = 60, requires = 60,
        objective = "Acquire special horse feed used for feeding a spirit horse. Merideth Carlson in Southshore apparently is the source for such food. Travel to the Dire Maul dungeon in Feralas and slay Tendris Warpwood. Doing so will free the Ancient Equine Spirit. Feed it the special horse feed, thereby soothing the spirit. Finally, give it the Arcanite Barding so it may bless it.",
        pickup = "Lord Grayson Shadowbreaker, Cathedral of Light, Stormwind",
        turnin = "Ancient Equine Spirit, Dire Maul",
        map = { mapID = 1453, x = 0.484, y = 0.502, label = "Lord Grayson Shadowbreaker — Stormwind", targetName = "Lord Grayson Shadowbreaker" },
    },
    [7644] = {
        startsInDungeon = true,
        level = 60, requires = 60,
        objective = "Return with the Blessed Arcanite Barding to Lord Grayson Shadowbreaker in the Cathedral District of Stormwind.",
        pickup = "Ancient Equine Spirit",
        turnin = "Lord Grayson Shadowbreaker, Stormwind",
    },
    [7646] = {
        level = 60, requires = 60,
        objective = "Bring an Azerothian Diamond and a Pristine Black Diamond to Lord Grayson Shadowbreaker in the Cathedral District of Stormwind.",
        pickup = "Lord Grayson Shadowbreaker, Stormwind",
        turnin = "Lord Grayson Shadowbreaker, Stormwind",
        map = { mapID = 1453, x = 0.484, y = 0.502, label = "Lord Grayson Shadowbreaker — Stormwind", targetName = "Lord Grayson Shadowbreaker" },
    },
    [7667] = {
        level = 60, requires = 58,
        objective = "If you are interested in helping Sagorne Crestrider in Orgrimmar's Valley of Wisdom, bring him an Azerothian Diamond and a Pristine Black Diamond.",
        pickup = "Sagorne Creststrider, Orgrimmar",
        turnin = "Sagorne Creststrider, Orgrimmar",
        map = { mapID = 1454, x = 0.384, y = 0.360, label = "Sagorne Creststrider — Orgrimmar", targetName = "Sagorne Creststrider" },
    },
    [5251] = {
        level = 60, requires = 55,
        objective = "Travel to Stratholme and find Archivist Galford of the Scarlet Crusade. Destroy him and burn down the Scarlet Archive.",
        pickup = "Duke Nicholas Zverenhoff, Light's Hope Chapel, Eastern Plaguelands",
        turnin = "Duke Nicholas Zverenhoff, Light's Hope Chapel, Eastern Plaguelands",
        map = { mapID = 1423, x = 0.737, y = 0.508, label = "Duke Nicholas Zverenhoff — Eastern Plaguelands", targetName = "Duke Nicholas Zverenhoff" },
    },
    [5542] = {
        level = 56, requires = 52,
        objective = "Slay 20 Plaguehound Runts, 5 Plaguehounds and 5 Frenzied Plaguehounds. Return to Tirion Fordring when the task is complete.",
        pickup = "Tirion Fordring, Eastern Plaguelands",
        turnin = "Tirion Fordring, Eastern Plaguelands",
        map = { mapID = 1423, x = 0.043, y = 0.361, label = "Tirion Fordring — Eastern Plaguelands", targetName = "Tirion Fordring" },
    },
    [5543] = {
        level = 56, requires = 52,
        objective = "Slay 30 Plaguebats and return to Tirion Fordring.",
        pickup = "Tirion Fordring, Eastern Plaguelands",
        turnin = "Tirion Fordring, Eastern Plaguelands",
        map = { mapID = 1423, x = 0.043, y = 0.361, label = "Tirion Fordring — Eastern Plaguelands", targetName = "Tirion Fordring" },
    },
    [5544] = {
        level = 56, requires = 52,
        objective = "Seek out the Carrion Grubs and Devourers of the region. Slay them and harvest their meat. Return to Tirion Fordring when you have gathered 15 Slabs of Carrion Worm Meat.",
        pickup = "Tirion Fordring, Eastern Plaguelands",
        turnin = "Tirion Fordring, Eastern Plaguelands",
        map = { mapID = 1423, x = 0.043, y = 0.361, label = "Tirion Fordring — Eastern Plaguelands", targetName = "Tirion Fordring" },
    },
    [5742] = {
        level = 56, requires = 52,
        objective = "Listen to what Tirion Fordring has to say.",
        pickup = "Tirion Fordring, Eastern Plaguelands",
        turnin = "Tirion Fordring, Eastern Plaguelands",
        map = { mapID = 1423, x = 0.043, y = 0.361, label = "Tirion Fordring — Eastern Plaguelands", targetName = "Tirion Fordring" },
    },
    [5781] = {
        level = 57, requires = 52,
        objective = "Travel to the Undercroft - at the southernmost section of the Eastern Plaguelands - and recover Taelan's Hammer. Return to Tirion Fordring upon completion of your objective.",
        pickup = "Tirion Fordring, Eastern Plaguelands",
        turnin = "Tirion Fordring, Eastern Plaguelands",
        map = { mapID = 1423, x = 0.043, y = 0.361, label = "Tirion Fordring — Eastern Plaguelands", targetName = "Tirion Fordring" },
    },
    [5845] = {
        level = 58, requires = 52,
        objective = "Travel to Northdale, in the northeastern region of the Eastern Plaguelands, and recover the Symbol of Lost Honor. Return to Tirion Fordring upon completion of your objective.",
        pickup = "Tirion Fordring, Eastern Plaguelands",
        turnin = "Tirion Fordring, Eastern Plaguelands",
        map = { mapID = 1423, x = 0.043, y = 0.361, label = "Tirion Fordring — Eastern Plaguelands", targetName = "Tirion Fordring" },
    },
    [5846] = {
        level = 58, requires = 52,
        objective = "Travel to island of Caer Darrow, in the south-central region of the Plaguelands, and look for any clues as to the whereabouts of the painting.",
        pickup = "Tirion Fordring, Eastern Plaguelands",
        turnin = "Artist Renfray",
        map = { mapID = 1423, x = 0.043, y = 0.361, label = "Tirion Fordring — Eastern Plaguelands", targetName = "Tirion Fordring" },
    },
    [5212] = {
        level = 60, requires = 55,
        objective = "Recover 20 Plagued Flesh Samples from Stratholme and return them to Betina Bigglezink. You suspect that any creature in Stratholme would have said flesh sample.",
        pickup = "Betina Bigglezink, Light's Hope Chapel, Eastern Plaguelands",
        turnin = "Betina Bigglezink, Light's Hope Chapel, Eastern Plaguelands",
    },
    [5262] = {
        startsInDungeon = true,
        level = 60, requires = 55,
        objective = "Take the Head of Balnazzar to Duke Nicholas Zverenhoff in the Eastern Plaguelands.",
        pickup = "Head of Balnazzar (drops from Balnazzar)",
        turnin = "Duke Nicholas Zverenhoff, Light's Hope Chapel, Eastern Plaguelands",
    },
    [6133] = {
        level = 60, requires = 54,
        objective = "Travel to the northern borders of the Eastern Plaguelands and recover the Quel'Thalas Registry. The item is somewhere in the Quel'Lithien lodge. You must also slay 8 Rangers, 8 Pathstriders, and 8 Woodsmen.",
        pickup = "Nathanos Blightcaller, Eastern Plaguelands",
        turnin = "Nathanos Blightcaller, Eastern Plaguelands",
        map = { mapID = 1423, x = 0.222, y = 0.643, label = "Nathanos Blightcaller — Eastern Plaguelands", targetName = "Nathanos Blightcaller" },
    },
    [6042] = {
        level = 58, requires = 54,
        objective = "Slay 20 Noxious Plaguebats and 10 Monstrous Plaguebats. Return to Nathanos Blightcaller when you are finished.",
        pickup = "Nathanos Blightcaller, Eastern Plaguelands",
        turnin = "Nathanos Blightcaller, Eastern Plaguelands",
        map = { mapID = 1423, x = 0.222, y = 0.643, label = "Nathanos Blightcaller — Eastern Plaguelands", targetName = "Nathanos Blightcaller" },
    },
    [6022] = {
        level = 58, requires = 54,
        objective = "Travel to Corin's Crossing to the east and slaughter the Scourge that inhabit the town. Collect 7 pieces of Living Rot in under 10 minutes. Use the Mortar and Pestle to grind the Living Rot into Coagulated Rot.",
        pickup = "Nathanos Blightcaller, Eastern Plaguelands",
        turnin = "Nathanos Blightcaller, Eastern Plaguelands",
        map = { mapID = 1423, x = 0.222, y = 0.643, label = "Nathanos Blightcaller — Eastern Plaguelands", targetName = "Nathanos Blightcaller" },
    },
    [6135] = {
        level = 60, requires = 56,
        objective = "Find Duskwing and slay him. From the corpse, recover a Patch of Duskwing's Fur and return it to Nathanos Blightcaller. It is said that Duskwing roams the countryside to the north of Marris Stead.",
        pickup = "Nathanos Blightcaller, Eastern Plaguelands",
        turnin = "Nathanos Blightcaller, Eastern Plaguelands",
        map = { mapID = 1423, x = 0.222, y = 0.643, label = "Nathanos Blightcaller — Eastern Plaguelands", targetName = "Nathanos Blightcaller" },
    },
    [6136] = {
        level = 60, requires = 56,
        objective = "Find Borelgore in the northern wastes of Eastern Plaguelands and destroy him. Return to Nathanos Blightcaller when the mission is complete.",
        pickup = "Nathanos Blightcaller, Eastern Plaguelands",
        turnin = "Nathanos Blightcaller, Eastern Plaguelands",
        map = { mapID = 1423, x = 0.222, y = 0.643, label = "Nathanos Blightcaller — Eastern Plaguelands", targetName = "Nathanos Blightcaller" },
    },
    [5122] = {
        startsInDungeon = true,
        level = 60, requires = 55,
        objective = "Retrieve the Medallion of Faith from Malor the Zealous in the Scarlet Bastion and bring it back to Aurius.",
        pickup = "Aurius, Stratholme",
        turnin = "Aurius, Stratholme",
    },
    [463] = {
        level = 21, requires = 20,
        objective = "Find Rethiel the Greenwarden in the Wetlands.",
        pickup = "First Mate Fitzsimmons, Menethil Harbor, Wetlands",
        turnin = "Rethiel the Greenwarden, The Green Belt, Wetlands",
        description = "Optional breadcrumb to Rethiel; not required for Horrors in the Highland.",
        map = { mapID = 1437, x = 0.108, y = 0.596, label = "First Mate Fitzsimmons — Menethil Harbor", detail = "Start The Greenwarden here" },
    },
    [276] = {
        level = 21, requires = 20,
        objective = "Kill 15 Mosshide Gnolls and 10 Mosshide Mongrels, then return to Rethiel the Greenwarden.",
        pickup = "Rethiel the Greenwarden, The Green Belt, Wetlands",
        turnin = "Rethiel the Greenwarden, The Green Belt, Wetlands",
        description = "First required step before Horrors in the Highland.",
        map = { mapID = 1437, x = 0.562, y = 0.406, label = "Rethiel the Greenwarden — Wetlands", detail = "Continue with Tramping Paws here" },
    },
    [277] = {
        level = 23, requires = 20,
        objective = "Bring Rethiel the Greenwarden 9 Crude Flints.",
        pickup = "Rethiel the Greenwarden, The Green Belt, Wetlands",
        turnin = "Rethiel the Greenwarden, The Green Belt, Wetlands",
        description = "Second required step before Horrors in the Highland.",
        map = { mapID = 1437, x = 0.562, y = 0.406, label = "Rethiel the Greenwarden — Wetlands", detail = "Continue with Fire Taboo here" },
    },
    [275] = {
        level = 26, requires = 20,
        objective = "Kill 12 Fen Creepers, then return to Rethiel the Greenwarden.",
        pickup = "Rethiel the Greenwarden, The Green Belt, Wetlands",
        turnin = "Rethiel the Greenwarden, The Green Belt, Wetlands",
        description = "Final required step before Horrors in the Highland.",
        map = { mapID = 1437, x = 0.562, y = 0.406, label = "Rethiel the Greenwarden — Wetlands", detail = "Continue with Blisters on The Land here" },
    },

    [484] = {
        level = 22,
        requires = 18,
        objective = "Obtain 4 Young Crocolisk Skins for James Halloran in Menethil Harbor.",
        pickup = "James Halloran, Menethil Harbor, Wetlands",
        turnin = "James Halloran, Menethil Harbor, Wetlands",
        description = "Required before Highland Hides. Daily Delivery is not required in Forever.",
        map = { mapID = 1437, x = 0.080, y = 0.550, label = "James Halloran — Menethil Harbor", detail = "Start Young Crocolisk Skins here" },
    },

    [95663] = { level = 31, requires = 24, objective = "Travel to the Wetlands and meet the Deathstalker Agent in the hills above the Dragonmaw camp.", pickup = "Zaruk, Hammerfall, Arathi Highlands", turnin = "Deathstalker Agent, hills above the Dragonmaw camp, Wetlands", description = "Required before Open the Maw.", map = { mapID = 1417, x = 0.7454, y = 0.3563, label = "Zaruk — Hammerfall", detail = "Start Dragonmaw Rumors here" } },
    [95647] = { level = 31, requires = 24, objective = "Find Ardin Grassman in the Excavation Sites. Learn what happened to Ardin Grassman.", pickup = "Caitlin Grassman, Menethil Harbor, Wetlands", turnin = "Ardin Grassman, inside Excavation Site: Wetlands", description = "Required before Heartwoven.", map = { mapID = 1437, x = 0.119, y = 0.588, label = "Caitlin Grassman — Menethil Harbor", detail = "Start Lost in the Thicket Things here" } },


    -- Gnomeregan ring-chain prerequisite steps.
    [2945] = {
        level = 34,
        requires = 28,
        objective = "Find a way to remove the grime from the Grime-Encrusted Ring by using the Sparklematic 5200.",
        pickup = "Grime-Encrusted Ring, dropped by Dark Iron dwarves in Gnomeregan",
        turnin = "The Sparklematic 5200, inside Gnomeregan",
        startItem = {9326, "Grime-Encrusted Ring", 1, "Dropped by Dark Iron dwarves in Gnomeregan"},
    },
    [2947] = {
        level = 34,
        requires = 28,
        objective = "Take the Brilliant Gold Ring to Talvash del Kissel in Ironforge.",
        pickup = "The Sparklematic 5200, inside Gnomeregan",
        turnin = "Talvash del Kissel, Mystic Ward, Ironforge",
        description = "Alliance step required before Gnome Improvement.",
    },
    [2949] = {
        level = 34,
        requires = 28,
        objective = "Take the Brilliant Gold Ring to Nogg in Orgrimmar.",
        pickup = "The Sparklematic 5200, inside Gnomeregan",
        turnin = "Nogg, Valley of Honor, Orgrimmar",
        description = "Horde step required before Nogg's Ring Redo.",
    },

    -- Gnomeregan prerequisite steps.
    [2926] = { level = 27, requires = 20, objective = "Use the Empty Leaden Collection Phial on a living Irradiated Invader or Irradiated Pillager, then return the full phial to Ozzie Togglevolt.", pickup = "Ozzie Togglevolt, Kharanos, Dun Morogh", turnin = "Ozzie Togglevolt, Kharanos, Dun Morogh", description = "Required before The Only Cure is More Green Glow.", map = { mapID = 1426, x = 0.450, y = 0.490, label = "Ozzie Togglevolt — Kharanos", detail = "Start Gnogaine here" }, requiredItems = { {9284, "Full Leaden Collection Phial", 1, "Use the Vial on an Irradiated Invader just outside the instance", map = { mapID = 1426, x = 0.243, y = 0.398, label = "Irradiated Invaders — outside Gnomeregan", detail = "Use the Vial on an Irradiated Invader just outside the instance" }} } },
    [2841] = { level = 35, requires = 25, objective = "Retrieve the Rig Blueprints and Thermaplugg's Safe Combination and bring them to Nogg in Orgrimmar.", pickup = "Nogg, Valley of Honor, Orgrimmar", turnin = "Nogg, Orgrimmar", map = { mapID = 1454, x = 0.760, y = 0.250, label = "Nogg — Valley of Honor, Orgrimmar", detail = "Accept Rig Wars here" } },
    [2842] = { level = 35, requires = 20, objective = "Speak with Scooty in Booty Bay.", pickup = "Sovik, Valley of Honor, Orgrimmar", turnin = "Scooty, Booty Bay, Stranglethorn Vale", description = "Required before Gnomer-gooooone!", map = { mapID = 1454, x = 0.756, y = 0.252, label = "Sovik — Valley of Honor, Orgrimmar", detail = "Start Chief Engineer Scooty here" } },

    -- Razorfen Kraul / Scarlet Monastery prerequisite steps.
    [1100] = { level = 27, requires = 23, objective = "Read Henrig Lonebrow's Journal and take it to Falfindel Waywarder in Thalanaar.", pickup = "Henrig Lonebrow's Journal beside his corpse at the bottom of the Great Lift", turnin = "Falfindel Waywarder, Thalanaar, Feralas", description = "Required before The Crone of the Kraul.", map = { mapID = 1441, x = 0.307, y = 0.244, label = "Henrig Lonebrow — bottom of the Great Lift", detail = "Loot Lonebrow's Journal here",
        -- spawns (2.0.36): the journal has two spots (Wowhead Forever comments,
        -- Nov 2026): by his body at the lift's foot, and by a second body about
        -- 110 yards down the road (31.3, 28.1). The arrow tries the nearest first.
        spawns = { { x = 0.307, y = 0.244 }, { x = 0.313, y = 0.281 } } },
        -- The book gives Henrig Lonebrow's Journal (item 5791), which starts the
        -- quest: in the bags, the route goes on (and says to use it).
        lootItem = { 5791, "Henrig Lonebrow's Journal" } },
    [1109] = { level = 33, requires = 30, objective = "Bring 1 pile of Kraul Guano to Master Apothecary Faranell in the Undercity.", pickup = "Master Apothecary Faranell, Apothecarium, Undercity", turnin = "Master Apothecary Faranell, Apothecarium, Undercity", description = "Required before Hearts of Zeal.", map = { mapID = 1458, x = 0.480, y = 0.690, label = "Master Apothecary Faranell — Apothecarium", detail = "Start Going, Going, Guano! here" } },
    [96391] = { level = 15, requires = 9, objective = "Deliver the Dark Iron Map to Earthseer Farsen in Dun Morogh.", pickup = "Dark Iron Map, dropped by Dark Iron Spies at Ironband's Compound, Dun Morogh", turnin = "Earthseer Farsen, Dun Morogh", description = "The Dark Iron Map starts this quest and leads directly into Old Ironforge Incursion.", map = { mapID = 1426, x = 0.770, y = 0.600, label = "Dark Iron Spies — Ironband's Compound", detail = "Farm Dark Iron Spies here for the Dark Iron Map" } },

    [865]  = { level = 18, requires = 13, objective = "Gather 5 Intact Raptor Horns from Sunscale Scytheclaws and bring them to Mebok Mizzyrix.", pickup = "Mebok Mizzyrix, Ratchet, The Barrens", turnin = "Mebok Mizzyrix, Ratchet, The Barrens", description = "Required before Smart Drinks becomes available.", map = { mapID = 1413, x = 0.6280, y = 0.3670, label = "Mebok Mizzyrix — Ratchet", detail = "Start Raptor Horns here" } },

    [870]  = { level = 13, requires = 10, objective = "Explore the waters of the Forgotten Pools northwest of the Crossroads, then report back.", pickup = "Tonga Runetotem, The Crossroads", turnin = "Tonga Runetotem, The Crossroads", description = "Investigate the fissure beneath the Forgotten Pools.", map = { mapID = 1413, x = 0.520, y = 0.320, label = "Tonga Runetotem — The Crossroads", detail = "Start The Forgotten Pools here" } },
    [877]  = { level = 16, requires = 10, objective = "Take the Dried Seeds to the Stagnant Oasis and test them at the fissure, then return to Tonga.", pickup = "Tonga Runetotem, The Crossroads", turnin = "Tonga Runetotem, The Crossroads", description = "The next required oasis investigation after The Forgotten Pools." },
    [880]  = { level = 16, requires = 10, objective = "Bring 8 Altered Snapjaw Shells to Tonga Runetotem at the Crossroads.", pickup = "Tonga Runetotem, The Crossroads", turnin = "Tonga Runetotem, The Crossroads", description = "Completing Altered Beings unlocks Hamuul Runetotem." },
    [1489] = { level = 16, requires = 10, objective = "Speak with Hamuul Runetotem on Elder Rise in Thunder Bluff.", pickup = "Tonga Runetotem, The Crossroads", turnin = "Hamuul Runetotem, Elder Rise, Thunder Bluff", description = "Tonga sends you to Hamuul after Altered Beings." },
    [1490] = { level = 16, requires = 10, objective = "Speak with Nara Wildmane in Thunder Bluff.", pickup = "Hamuul Runetotem, Elder Rise, Thunder Bluff", turnin = "Nara Wildmane, Thunder Bluff", description = "Nara Wildmane is the final prerequisite before Leaders of the Fang becomes available." },

    [153]  = { level = 15, requires = 9, objective = "Bring 15 Red Leather Bandanas to Scout Galiaan at Sentinel Hill.", pickup = "Scout Galiaan, Sentinel Hill, Westfall", turnin = "Scout Galiaan, Sentinel Hill, Westfall", description = "Required before Red Silk Bandanas.", map = { mapID = 1436, x = 0.566, y = 0.473, label = "Scout Galiaan — Sentinel Hill", detail = "Start Red Leather Bandanas here" } },
    [65]   = { level = 18, requires = 14, objective = "Talk to Wiley the Black in Lakeshire.", pickup = "Gryan Stoutmantle, Sentinel Hill, Westfall", turnin = "Wiley the Black, Lakeshire, Redridge Mountains", description = "First step of the required Defias Brotherhood chain.", map = { mapID = 1436, x = 0.562, y = 0.476, label = "Gryan Stoutmantle — Sentinel Hill", detail = "Start The Defias Brotherhood here" } },
    [132]  = { level = 18, requires = 14, objective = "Take Wiley's Note back to Gryan Stoutmantle in Westfall.", pickup = "Wiley the Black, Lakeshire, Redridge Mountains", turnin = "Gryan Stoutmantle, Sentinel Hill, Westfall", description = "Second step of the Defias Brotherhood chain." },
    [135]  = { level = 18, requires = 14, objective = "Take Wiley's Note to Master Mathias Shaw in Stormwind.", pickup = "Gryan Stoutmantle, Sentinel Hill, Westfall", turnin = "Master Mathias Shaw, Old Town, Stormwind", description = "Shaw investigates the connection between the Defias and the Stonemasons." },
    [141]  = { level = 18, requires = 14, objective = "Take Shaw's Report to Gryan Stoutmantle in Westfall.", pickup = "Master Mathias Shaw, Old Town, Stormwind", turnin = "Gryan Stoutmantle, Sentinel Hill, Westfall", description = "Returns Shaw's findings about Edwin VanCleef to Gryan." },
    [142]  = { level = 18, requires = 14, objective = "Track down the Defias Messenger in Westfall and bring his message to Gryan Stoutmantle.", pickup = "Gryan Stoutmantle, Sentinel Hill, Westfall", turnin = "Gryan Stoutmantle, Sentinel Hill, Westfall", description = "The messenger travels the roads between Moonbrook, Gold Coast Quarry and Jangolode Mine.", note = "The Defias Messenger patrols the roads between Moonbrook, Gold Coast Quarry and Jangolode Mine." },
    [155]  = { level = 18, requires = 14, objective = "Escort the Defias Traitor until he reveals the Defias hideout, then return to Gryan Stoutmantle.", pickup = "Defias Traitor, Sentinel Hill, Westfall", turnin = "Gryan Stoutmantle, Sentinel Hill, Westfall", description = "Final prerequisite before the dungeon step of The Defias Brotherhood." },

    [2041] = { level = 15, requires = 15, objective = "Speak with Shoni the Shilent in Stormwind.", pickup = "Gnoarn, Tinker Town, Ironforge", turnin = "Shoni the Shilent, Dwarven District, Stormwind", description = "This leads directly into Underground Assault.", map = { mapID = 1455, x = 0.692, y = 0.505, label = "Gnoarn — Tinker Town", detail = "Start Speak with Shoni here" } },

    [92742] = { level = 12, requires = 9, objective = "Use the Well Water Sample Kit at the Jansen Stead and Molsen Farm wells.", pickup = ALBA_FAIRMOON_LOCATION, turnin = ALBA_FAIRMOON_LOCATION, description = "First quest of the Toxic Soil chain.", map = { mapID = 1436, x = 0.530, y = 0.533, label = "Alba Fairmoon — Sentinel Hill inn", detail = "Start Testing the Wells here" } },
    [92744] = { level = 12, requires = 9, objective = "Collect 7 Longshore Murloc Gills along the Westfall shoreline.", pickup = ALBA_FAIRMOON_LOCATION, turnin = ALBA_FAIRMOON_LOCATION, description = "Second quest of the Toxic Soil chain.", map = { mapID = 1436, x = 0.530, y = 0.533, label = "Alba Fairmoon — Sentinel Hill inn", detail = "Alba Fairmoon is inside the Sentinel Hill inn" }},
    [92745] = { level = 14, requires = 9, objective = "Slay 4 Kobold Diggers in Jangolode Mine and 6 Riverpaw Miners in Gold Coast Quarry.", pickup = ALBA_FAIRMOON_LOCATION, turnin = ALBA_FAIRMOON_LOCATION, description = "Investigate whether Westfall's mines are causing the contamination.", map = { mapID = 1436, x = 0.530, y = 0.533, label = "Alba Fairmoon — Sentinel Hill inn", detail = "Alba Fairmoon is inside the Sentinel Hill inn" }},
    [92747] = { level = 16, requires = 9, objective = "Collect 8 Suspicious Industrial Supplies from Moonbrook.", pickup = ALBA_FAIRMOON_LOCATION, turnin = ALBA_FAIRMOON_LOCATION, description = "The supplies are found in the caves leading toward the Deadmines entrance.", map = { mapID = 1436, x = 0.530, y = 0.533, label = "Alba Fairmoon — Sentinel Hill inn", detail = "Alba Fairmoon is inside the Sentinel Hill inn" }},
    [92748] = { level = 16, requires = 9, objective = "Travel to the Dwarven District in Stormwind and find an engineer who can help with explosives.", pickup = ALBA_FAIRMOON_LOCATION, turnin = "Sprite Jumpsprocket, Dwarven District, Stormwind", description = "Begins the explosives portion of the Toxic Soil chain.", map = { mapID = 1436, x = 0.530, y = 0.533, label = "Alba Fairmoon — Sentinel Hill inn", detail = "Alba Fairmoon is inside the Sentinel Hill inn" }},
    [92749] = { level = 16, requires = 9, objective = "Obtain 10 Rough Dynamite from crafting, trading, or the auction house, then return to Sprite Jumpsprocket in the Dwarven District of Stormwind.", pickup = "Sprite Jumpsprocket, Dwarven District, Stormwind", turnin = "Sprite Jumpsprocket, Dwarven District, Stormwind", description = "Rough Dynamite can be crafted, traded or bought from the auction house.", note = "Rough Dynamite can be crafted, traded or bought from the auction house." },
    [92750] = { level = 16, requires = 9, objective = "Talk to Stormwind Intelligence about acquiring a remote detonator.", pickup = "Sprite Jumpsprocket, Dwarven District, Stormwind", turnin = "Stormwind Intelligence, Stormwind", description = "You need a remote detonator for the planned explosion." },
    [92751] = { level = 16, requires = 9, objective = "Bring the Remote Detonator Kit back to Sprite Jumpsprocket in the Dwarven District.", pickup = "Jasper Fel, SI:7, Old Town, Stormwind", turnin = "Sprite Jumpsprocket, Dwarven District, Stormwind", description = "Returns the remote detonator to the engineer." },
    [92752] = { level = 16, requires = 9, objective = "Return to Alba Fairmoon at the Sentinel Hill inn in Westfall with the completed explosives.", pickup = "Sprite Jumpsprocket, Dwarven District, Stormwind", turnin = ALBA_FAIRMOON_LOCATION, description = "Final preparation before Destruction in Deadmines." },
    [92753] = { level = 18, requires = 9, objective = "Find the forge in the Deadmines and plant the Extra-Destructive Explosives beside it.", pickup = "Extra-Destructive Explosives quest-start item", startItem = {254553, "Extra-Destructive Explosives", 1, "Supplied by Sprite Jumpsprocket during Explosive Consultation; plant it at the Deadmines forge"}, turnin = ALBA_FAIRMOON_LOCATION, description = "Plant the explosives at the forge, then return to Alba Fairmoon." },
    [92819] = { level = 18, requires = 9, objective = "Use the detonator.", pickup = ALBA_FAIRMOON_LOCATION, turnin = ALBA_FAIRMOON_LOCATION, description = "Final step of the Toxic Soil chain.", map = { mapID = 1436, x = 0.530, y = 0.533, label = "Alba Fairmoon — Sentinel Hill inn", detail = "Alba Fairmoon is inside the Sentinel Hill inn" }},

    -- The Stockade prerequisite chains.
    [303] = { level = 30, requires = 25, objective = "Kill 10 Dark Iron Dwarves, 5 Dark Iron Tunnelers, 5 Dark Iron Saboteurs and 5 Dark Iron Demolitionists at Dun Modr.", pickup = "Motley Garmason, Dun Modr, Wetlands", turnin = "Motley Garmason, Dun Modr, Wetlands", description = "Complete The Dark Iron War to unlock The Fury Runs Deep.", map = { mapID = 1437, x = 0.496, y = 0.182, label = "Motley Garmason — Dun Modr", detail = "Start The Dark Iron War here" } },
    [373] = { level = 22, requires = 16, objective = "Take An Unsent Letter from Edwin VanCleef to Baros Alexston in Stormwind.", pickup = "Use An Unsent Letter, looted from Edwin VanCleef in The Deadmines", turnin = "Baros Alexston, City Hall, Cathedral Square, Stormwind", description = "First required step leading to The Stockade Riots.", startItem = {2874, "An Unsent Letter", 1, "Looted from Edwin VanCleef"} },
    [389] = { level = 22, requires = 16, objective = "Speak with Warden Thelwater outside The Stockade.", pickup = "Baros Alexston, City Hall, Cathedral Square, Stormwind", turnin = "Warden Thelwater, outside The Stockade, Stormwind", description = "Second required step leading to The Stockade Riots.", map = { mapID = 1453, x = 0.577, y = 0.479, label = "Baros Alexston — Stormwind", detail = "Continue the chain with Bazil Thredd here" } },

    [5726] = { level = 12, requires = 9, objective = "Bring a Lieutenant's Insignia from the Burning Blade in Skull Rock to Thrall.", pickup = "Thrall, Valley of Wisdom, Orgrimmar", turnin = "Thrall, Valley of Wisdom, Orgrimmar", description = "First required Hidden Enemies step for the Ragefire Chasm chain.", map = { mapID = 1454, x = 0.320, y = 0.378, label = "Thrall — Orgrimmar", detail = "Start Hidden Enemies here" } },
    [5727] = { level = 12, requires = 9, objective = "Speak with Neeru Fireblade in the Cleft of Shadow, then return to Thrall.", pickup = "Thrall, Valley of Wisdom, Orgrimmar", turnin = "Thrall, Valley of Wisdom, Orgrimmar", description = "Neeru is in the Cleft of Shadow near the Ragefire Chasm entrance." },

    [3765] = { level = 24, requires = 18, objective = "Travel to Gershala Nightwhisper in Auberdine, Darkshore.", pickup = "Argos Nightwhisper, The Park, Stormwind", turnin = "Gershala Nightwhisper, Auberdine, Darkshore", description = "Optional Alliance breadcrumb leading to Researching the Corruption.", map = { mapID = 1453, x = 0.363, y = 0.674, label = "Argos Nightwhisper — The Park", detail = "Argos Nightwhisper is in The Park, beside the moonwell area." } },
    [1198] = { level = 24, requires = 18, objective = "Seek out Argent Guard Thaelrid inside Blackfathom Deeps.", pickup = "Dawnwatcher Shaedlass, Darnassus", turnin = "Argent Guard Thaelrid, inside Blackfathom Deeps", description = "Optional lead-in to the Alliance version of Blackfathom Villainy: hand it in before accepting Blackfathom Villainy, or it can no longer be completed.", map = { mapID = 1457, x = 0.550, y = 0.240, label = "Dawnwatcher Shaedlass — Darnassus", detail = "Start In Search of Thaelrid here" } },
    [6564] = { level = 22, requires = 17, objective = "Bring the Damp Note to Je'neu Sancrea in Ashenvale.", pickup = "Damp Note", startItem = {16790, "Damp Note", 1, "Drops from Blackfathom Tide Priestess in the entrance tunnels leading to Blackfathom Deeps."}, turnin = "Je'neu Sancrea, Zoram'gar Outpost, Ashenvale" },
    -- Data Rescue punch card steps (item steps, not quests).
    [2930001] = { level = 30, requires = 25, objective = "Kill mobs in the outer Gnomeregan area until a White Punch Card drops.", pickup = "Caverndeep Pillagers, Caverndeep Invaders, Irradiated Invaders and Addled Lepers, outside the instance", turnin = "Keep the card for Matrix Punchograph 3005-A", description = "Random drop; you usually get it during your first clear of the outer area.", startItem = {9279, "White Punch Card", 1, "Random drop from mobs outside the Gnomeregan instance"}, map = { mapID = 1426, x = 0.243, y = 0.393, label = "Gnomeregan — outer area", detail = "White Punch Cards drop from the mobs here" } },
    [2930002] = { level = 30, requires = 25, objective = "Use Matrix Punchograph 3005-A with the White Punch Card to get a Yellow Punch Card.", pickup = "Matrix Punchograph 3005-A, Workshop area of the Train Depot, outside the instance", turnin = "You receive a Yellow Punch Card", description = "The only punchographs outside the instance: on the raised platform in the Train Depot and by the Workshop (back door) entrance.", startItem = {9280, "Yellow Punch Card", 1, "From Matrix Punchograph 3005-A"} },
    [2930003] = { level = 30, requires = 25, objective = "Use Matrix Punchograph 3005-B with the Yellow Punch Card to get a Blue Punch Card.", pickup = "Matrix Punchograph 3005-B, The Dormitory (just past the Clean Zone), inside the instance", turnin = "You receive a Blue Punch Card", description = "Inside the instance, in the Dormitory.", startItem = {9282, "Blue Punch Card", 1, "From Matrix Punchograph 3005-B"} },
    [2930004] = { level = 30, requires = 25, objective = "Use Matrix Punchograph 3005-C with the Blue Punch Card to get a Red Punch Card.", pickup = "Matrix Punchograph 3005-C, upper platform of the Launch Bay with Electrocutioner 6000", turnin = "You receive a Red Punch Card", description = "On Electrocutioner 6000's platform.", startItem = {9281, "Red Punch Card", 1, "From Matrix Punchograph 3005-C"} },
    [2930005] = { level = 30, requires = 25, objective = "Use Matrix Punchograph 3005-D with the Red Punch Card to get the Prismatic Punch Card, then bring it to Master Mechanic Castpipe in Ironforge.", pickup = "Matrix Punchograph 3005-D, west side of the lower level of the Engineering Labs", turnin = "Master Mechanic Castpipe, Tinker Town, Ironforge", description = "Take the elevator down; the terminal is in the first passage on the right.", startItem = {9316, "Prismatic Punch Card", 1, "From Matrix Punchograph 3005-D"} },

}

-- questguide: chains that are HOW to complete the quest, not quests needed
-- before it. The journal shows them behind a red Guide button (quest list)
-- and a How to complete button (quest page) instead of the chain icon and
-- "Requires a quest chain first.".
FDJ.QUEST_GUIDE_CHAINS = FDJ.QUEST_GUIDE_CHAINS or {}
FDJ.QUEST_GUIDE_CHAINS[2930] = true -- Data Rescue: the punch cards

-- Pre-quests that also start a dungeon quest elsewhere in the journal reuse
-- that quest's giver location for their Show on Map button.
for id, details in pairs(FDJ.QUEST_PREREQ_DETAILS) do
    if not details.map and FDJ.QUEST_START_MAPS and FDJ.QUEST_START_MAPS[id] then
        details.map = FDJ.QUEST_START_MAPS[id]
    end
end

-- Pre-quests are only listed inside their chain: a quest that is a required
-- step of another quest in the same dungeon is hidden from the main quest
-- list (it stays reachable from the chain).
for _, dungeon in pairs(FDJ.DB or {}) do
    if type(dungeon) == "table" and type(dungeon.quests) == "table" then
        local steps = {}
        for _, quest in ipairs(dungeon.quests) do
            local chain = quest.id and FDJ.QUEST_PREREQ_CHAINS[quest.id]
            if chain then
                for _, step in ipairs(chain) do
                    -- standalone: a step also listed on its own (Rig Wars)
                    if step.id and step.id ~= quest.id and not step.standalone then steps[step.id] = true end
                end
            end
        end
        for _, quest in ipairs(dungeon.quests) do
            if quest.id and steps[quest.id] then quest.hideFromMainList = true end
        end
    end
end
