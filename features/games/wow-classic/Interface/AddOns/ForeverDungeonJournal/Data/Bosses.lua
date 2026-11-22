local ADDON_NAME, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS

FDJ.BOSS_LEVELS = {
    ["Excavation Site: Wetlands"] = {
        ["Saltspine"] = "28",
        ["Shadetooth"] = "29",
        ["Relic Guardian"] = "31",
    },
    ["City of Dalaran"] = {
        ["Atrexis the Grave Knight"] = "29",
        ["Arcane Anomaly"] = "30",
        ["Unstable Sentinel"] = "31",
        ["Fel Ancient"] = "32",
        ["Mana Devourer"] = "31",
        ["Arcanic Enigma"] = "30",
        ["Shade of the Archmage"] = "33",
    },
    ["Shaper's Terrace"] = {
        ["Titanosaur"] = "61",
        ["Venomridge"] = "61",
        ["Thunderhoof"] = "61",
        ["Direhorn Matriarch"] = "61",
        ["Cinder"] = "61",
        ["Bolt"] = "62",
        ["Snowtalon"] = "62",
        ["Vitrix"] = "62",
        ["Izha'Rel and Tor'Rel"] = "61",
        ["Nanaya"] = "62",
    },
    ["Blackmaw Hold"] = {
        ["Withermaw"] = "58",
        ["Impaan the Imprisoner"] = "57",
        ["Bonesnout the Unbroken"] = "58",
        ["Varrox Bleakhoof"] = "60",
        ["Elder Shaman Bloodmane"] = "59",
        ["Blackmaw Behemoth"] = "59",
        ["Unbound Spirit"] = "59",
        ["Moontouched Wanderer"] = "55",
        ["Gortek the Apprentice"] = "55",
        ["Tunnelweb Matriarch"] = "55",
    },
    ["Alcaz Prison"] = {
        ["Overseer Wrex"] = "50",
        ["Tidemistress Ca'zass"] = "50",
        ["Katerina the Cleaner"] = "52",
        ["The Questioner"] = "51",
        ["Blazeroar"] = "53",
    },
    ["Krol'dok Stronghold"] = {
        ["Slavecrusher Grox"] = "42",
        ["Twilight Commander Zarmok"] = "43",
        ["War Handler Ashka"] = "43",
        ["Nar'gurk"] = "44",
        ["Bossman Toof"] = "42",
        ["Overlord Mugg"] = "45",
        ["Kroog"] = "41", -- in-game screenshot, 12 Nov 2026
    },
    ["Gnomeregan"] = {
        ["Grubbis"] = "32",
        ["Viscous Fallout"] = "30",
        ["Electrocutioner 6000"] = "32",
        ["Crowd Pummeler 9-60"] = "32",
        ["Mekgineer Thermaplugg"] = "34",
        ["Dark Iron Ambassador"] = "33",
    },
    ["Razorfen Kraul"] = {
        ["Roogug"] = "28",
        ["Aggem Thorncurse"] = "30",
        ["Death Speaker Jargba"] = "30",
        ["Overlord Ramtusk"] = "32",
        ["Agathelos the Raging"] = "33",
        ["Charlga Razorflank"] = "33",
        ["Blind Hunter"] = "32",
        ["Earthcaller Halmgar"] = "32",
    },
    ["Scarlet Monastery: Graveyard"] = {
        ["Interrogator Vishas"] = "32",
        ["Azshir the Sleepless"] = "33",
        ["Fallen Champion"] = "33",
        ["Ironspine"] = "33",
        ["Bloodmage Thalnos"] = "34",
    },
    ["Scarlet Monastery: Library"] = {
        ["Houndmaster Loksey"] = "34",
        ["Arcanist Doan"] = "37",
    },
    ["Scarlet Monastery: Armory"] = {
        ["Herod"] = "40",
    },
    ["Scarlet Monastery: Cathedral"] = {
        ["High Inquisitor Fairbanks"] = "40",
        ["Scarlet Commander Mograine"] = "42",
        ["High Inquisitor Whitemane"] = "42",
    },
    ["Uldaman"] = {
        ["Revelosh"] = "40",
        ["The Lost Dwarves"] = "41",
        ["Ironaya"] = "40",
        ["Obsidian Sentinel"] = "42",
        ["Ancient Stone Keeper"] = "44",
        ["Galgann Firehammer"] = "45",
        ["Grimlok"] = "45",
        ["Archaedas"] = "47",
    },
    ["Zul'Farrak"] = {
        ["Theka the Martyr"] = "46",
        ["Antu'sul"] = "48",
        ["Witch Doctor Zum'rah"] = "46",
        ["Nekrum Gutchewer"] = "45",
        ["Shadowpriest Sezz'ziz"] = "47",
        ["Sergeant Bly"] = "45",
        ["Hydromancer Velratha"] = "46",
        ["Gahz'rilla"] = "46",
        ["Zerillis"] = "45",
        ["Sandarr Dunereaver"] = "45",
        ["Dustwraith"] = "45",
        ["Ruuzlu"] = "46",
        ["Chief Ukorz Sandscalp"] = "48",
    },
    ["Sunken Temple"] = {
        -- altarbosses (2.0.24): Wowhead Forever levels (the group itself shows
        -- none, 2.0.25).
        ["Gasher"] = "51",
        ["Loro"] = "51",
        ["Zolo"] = "51",
        ["Hukku"] = "52",
        ["Mijan"] = "52",
        ["Zul'Lor"] = "52",
        ["Atal'alarion"] = "50",
        ["Dreamscythe & Weaver"] = "51-53",
        ["Avatar of Hakkar"] = "55",
        ["Jammal'an the Prophet"] = "54",
        ["Ogom the Wretched"] = "53",
        ["Morphaz & Hazzas"] = "52-53",
        ["Shade of Eranikus"] = "55",
    },
    ["Scholomance"] = {
        ["Kirtonos the Herald"] = "60",
        ["Jandice Barov"] = "61",
        ["Rattlegore"] = "61",
        ["Marduk Blackpool"] = "58",
        ["Vectus"] = "60",
        ["Ras Frostwhisper"] = "62",
        ["Instructor Malicia"] = "60",
        ["Doctor Theolen Krastinov"] = "60",
        ["Lorekeeper Polkelt"] = "60",
        ["The Ravenian"] = "60",
        ["Lord Alexei Barov"] = "60",
        ["Lady Illucia Barov"] = "60",
        ["Darkmaster Gandling"] = "61",
        ["Death Knight Darkreaver"] = "62", -- darkreaver (2.0.8): Wowhead Forever, elite
        ["Kormok"] = "60", -- kormok (2.0.8): Wowhead Forever, elite
    },
    ["Maraudon"] = {
        ["Noxxion"] = "48",
        ["Razorlash"] = "48",
        ["Lord Vyletongue"] = "47",
        ["Meshlok the Harvester"] = "48",
        ["Celebras the Cursed"] = "49",
        ["Landslide"] = "50",
        ["Tinkerer Gizlock"] = "50",
        ["Rotgrip"] = "50",
        ["Princess Theradras"] = "51",
    },
    ["Dire Maul: East"] = {
        ["Pusillin"] = "57",
        ["Zevrim Thornhoof"] = "57",
        ["Hydrospawn"] = "57",
        ["Lethtendris"] = "57",
        ["Alzzin the Wildshaper"] = "58",
    },
    ["Dire Maul: West"] = {
        ["Tendris Warpwood"] = "60",
        ["Illyanna Ravenoak"] = "60",
        ["Tsu'zee"] = "59",
        ["Magister Kalendris"] = "60",
        ["Immol'thar"] = "61",
        ["Lord Hel'nurath"] = "62",
        ["Prince Tortheldrin"] = "61",
    },
    ["Dire Maul: North"] = {
        ["Guard Mol'dar"] = "59",
        ["Stomper Kreeg"] = "59",
        ["Guard Fengus"] = "59",
        ["Guard Slip'kik"] = "59",
        ["Captain Kromcrush"] = "61",
        ["Cho'Rush the Observer"] = "60",
        ["King Gordok"] = "62",
    },
    ["Stratholme: Living"] = {
        ["Skul"] = "58",
        ["Hearthsinger Forresten"] = "57",
        ["The Unforgiven"] = "57",
        ["Timmy the Cruel"] = "58",
        ["Malor the Zealous"] = "60",
        ["Postmaster Malown"] = "60",
        ["Ezra Grimm"] = "61", -- ezragrimm (2.0.8): Wowhead Forever
        ["Cannon Master Willey"] = "60",
        ["Archivist Galford"] = "60",
        ["Balnazzar"] = "62",
    },
    ["Stratholme: Undead"] = {
        ["Stonespine"] = "60",
        ["Magistrate Barthilas"] = "58",
        ["Nerub'enkan"] = "60",
        ["Baroness Anastari"] = "59",
        ["Maleki the Pallid"] = "61",
        ["Ramstein the Gorger"] = "61",
        ["Baron Rivendare"] = "62",
    },
    ["Blackrock Depths"] = {
        ["High Interrogator Gerstahn"] = "52",
        ["Lord Roccor"] = "51",
        ["Houndmaster Grebmar"] = "52",
        ["Gorosh the Dervish"] = "56",
        ["Grizzle"] = "54",
        ["Eviscerator"] = "54",
        ["Ok'thor the Breaker"] = "53",
        ["Anub'shiah"] = "54",
        ["Hedrum the Creeper"] = "53",
        ["Pyromancer Loregrain"] = "52",
        ["Fineous Darkvire"] = "54",
        ["Warder Stilgiss"] = "56",
        ["Lord Incendius"] = "55",
        ["Bael'Gar"] = "54",
        ["General Angerforge"] = "57",
        ["Golem Lord Argelmach"] = "57",
        ["Hurley Blackbreath"] = "55",
        ["Phalanx"] = "55",
        ["Ribbly Screwspigot"] = "53",
        ["Theldren"] = "60",
        ["Plugger Spazzring"] = "55",
        ["Ambassador Flamelash"] = "57",
        ["Panzor the Invincible"] = "57",
        ["The Seven"] = "57",
        ["Magmus"] = "57",
        ["Princess Moira Bronzebeard"] = "58",
        ["Emperor Dagran Thaurissan"] = "59",
    },
    ["Upper Blackrock Spire"] = {
        ["Pyroguard Emberseer"] = "60",
        ["Solakar Flamewreath"] = "60",
        ["Jed Runewatcher"] = "59",
        ["Goraluk Anvilcrack"] = "61",
        ["Gyth"] = "62",
        ["Warchief Rend Blackhand"] = "62",
        ["The Beast"] = "62",
        ["Lord Valthalak"] = "62",
        ["General Drakkisath"] = "62",
    },
    ["Lower Blackrock Spire"] = {
        ["Spirestone Butcher"] = "57",
        ["Spirestone Battle Lord"] = "58",
        ["Spirestone Lord Magus"] = "58",
        ["Highlord Omokk"] = "59",
        ["Shadow Hunter Vosh'gajin"] = "58",
        ["War Master Voone"] = "59",
        ["Mother Smolderweb"] = "59",
        ["Crystal Fang"] = "60",
        ["Urok Doomhowl"] = "60",
        ["Bannok Grimaxe"] = "59",
        ["Quartermaster Zigris"] = "59",
        ["Halycon"] = "59",
        ["Gizrul the Slavener"] = "60",
        ["Ghok Bashguud"] = "59",
        ["Overlord Wyrmthalak"] = "60",
    },
    ["Razorfen Downs"] = {
        ["Tuten'kash"] = "40",
        ["Mordresh Fire Eye"] = "39",
        ["Glutton"] = "40",
        ["Ragglesnout"] = "37",
        ["Plaguemaw the Rotting"] = "40",
        ["Amnennar the Coldbringer"] = "41",
    },
    ["Hall of Thanes"] = {
        ["Faldrim Anvilmar"] = "16",
        ["Magmatus"] = "16",
        ["Plunder"] = "16",
        ["Durgen Dirgehammer"] = "16",
    },
    ["Ruins of Lordaeron"] = {
        ["The Baron"] = "17",
        ["Witherfang"] = "17",
        ["The Abandoned"] = "18",
        ["Bjork"] = "19",
        ["Rath'mael"] = "20",
        ["Viktor the Vile"] = "19",
        ["Lordaeron Captain"] = "19",
    },
    ["Ragefire Chasm"] = {
        ["Oggleflint"] = "16",
        ["Taragaman the Hungerer"] = "16",
        ["Jergosh the Invoker"] = "16",
        ["Bazzalan"] = "16",
    },
    ["The Deadmines"] = {
        ["Rhahk'Zor"] = "19",
        ["Miner Johnson"] = "19",
        ["Sneed's Shredder"] = "20",
        ["Sneed"] = "20",
        ["Gilnid"] = "20",
        ["Mr. Smite"] = "20",
        ["Captain Greenskin"] = "20",
        ["Edwin VanCleef"] = "21",
        ["Cookie"] = "20",
    },
    ["Wailing Caverns"] = {
        ["Lord Cobrahn"] = "20",
        ["Lady Anacondra"] = "20",
        ["Kresh"] = "20",
        ["Lord Pythas"] = "21",
        ["Skum"] = "21",
        ["Lord Serpentis"] = "21",
        ["Verdan the Everliving"] = "21",
        ["Mutanus the Devourer"] = "22",
        ["Deviate Faerie Dragon"] = "20",
    },
    ["Shadowfang Keep"] = {
        ["Rethilgore"] = "20",
        ["Fel Steed / Shadow Charger"] = "19-21",
        ["Razorclaw the Butcher"] = "22",
        ["Baron Silverlaine"] = "24",
        ["Commander Springvale"] = "24",
        ["Odo the Blindwatcher"] = "24",
        ["Deathsworn Captain"] = "25",
        ["Arugal's Voidwalker"] = "24-25",
        ["Fenrus the Devourer"] = "25",
        ["Wolf Master Nandos"] = "25",
        ["Archmage Arugal"] = "24",
    },
    ["The Stockade"] = {
        ["Targorr the Dread"] = "24",
        ["Kam Deepfury"] = "27",
        ["Hamhock"] = "28",
        ["Dextren Ward"] = "26",
        ["Bazil Thredd"] = "29",
        ["Bruegal Ironknuckle"] = "26",
    },
    ["Blackfathom Deeps"] = {
        ["Ghamoo-ra"] = "25",
        ["Lady Sarevess"] = "25",
        ["Gelihast"] = "26",
        ["Lorgus Jett"] = "26",
        ["Baron Aquanis"] = "28",
        ["Old Serra'kis"] = "26",
        ["Twilight Lord Kelris"] = "27",
        ["Aku'mai"] = "28",
    },
}

FDJ.STATIC_DISPLAY_IDS = {
    -- Wailing Caverns
    [3669] = 4213,  -- Lord Cobrahn
    [3671] = 4313,  -- Lady Anacondra
    [3653] = 5126,  -- Kresh
    [3670] = 4214,  -- Lord Pythas
    [3674] = 4203,  -- Skum
    [3673] = 4215,  -- Lord Serpentis
    [5775] = 4256,  -- Verdan the Everliving
    [3654] = 4088,  -- Mutanus the Devourer
    [5912] = 1267,  -- Deviate Faerie Dragon

    -- The Deadmines
    [644]  = 14403, -- Rhahk'Zor
    [3586] = 556,   -- Miner Johnson
    [642]  = 1269,  -- Sneed's Shredder
    [643]  = 7125,  -- Sneed
    [1763] = 7124,  -- Gilnid
    [646]  = 2026,  -- Mr. Smite
    [647]  = 7113,  -- Captain Greenskin
    [639]  = 2029,  -- Edwin VanCleef
    [645]  = 1305,  -- Cookie

    -- Blackfathom Deeps
    [4887]  = 5027,  -- Ghamoo-ra
    [4831]  = 4979,  -- Lady Sarevess
    [6243]  = 1773,  -- Gelihast
    [12902] = 12822, -- Lorgus Jett
    [12876] = 110,   -- Baron Aquanis
    [4830]  = 1816,  -- Old Serra'kis
    [4832]  = 4939,  -- Twilight Lord Kelris
    [4829]  = 2837,  -- Aku'mai

    -- Ragefire Chasm
    [11517] = 11611, -- Oggleflint
    [11520] = 7970,  -- Taragaman the Hungerer
    [11518] = 11429, -- Jergosh the Invoker
    [11519] = 2007,  -- Bazzalan

    -- Shadowfang Keep
    [3914] = 524,   -- Rethilgore
    [3864] = 1951,  -- Fel Steed / Shadow Charger
    [3886] = 524,   -- Razorclaw the Butcher
    [3887] = 3222,  -- Baron Silverlaine
    [4278] = 3223,  -- Commander Springvale
    [4279] = 522,   -- Odo the Blindwatcher
    [3872] = 3224,  -- Deathsworn Captain
    [4627] = 1131,  -- Arugal's Voidwalker
    [4274] = 2352,  -- Fenrus the Devourer
    [3927] = 11179, -- Wolf Master Nandos
    [4275] = 2353,  -- Archmage Arugal

    -- Resolved by the Forever client (build 70170) and bundled so these
    -- portraits render immediately instead of waiting on the model resolver.

    -- Hall of Thanes
    [261306] = 142826,  -- Faldrim Anvilmar
    [261311] = 142840,  -- Plunder
    [261319] = 142837,  -- Durgen Dirgehammer

    -- Ruins of Lordaeron
    [250660] = 144188,  -- The Baron
    [250483] = 144189,  -- Witherfang
    [250631] = 138667,  -- The Abandoned
    [256097] = 144170,  -- Bjork
    [250657] = 144175,  -- Rath'mael
    [256035] = 139455,  -- Viktor the Vile

    -- The Stockade
    [1696] = 517,       -- Targorr the Dread
    [1666] = 825,       -- Kam Deepfury
    [1717] = 3250,      -- Hamhock
    [1663] = 2149,      -- Dextren Ward
    [1716] = 1621,      -- Bazil Thredd
    [1720] = 2142,      -- Bruegal Ironknuckle

    -- Excavation Site: Wetlands
    [260322] = 144209,  -- Saltspine
    [260325] = 144210,  -- Shadetooth
    [260326] = 144224,  -- Relic Guardian
    [260808] = 9010,    -- Highland Horror (quest target, Wowhead Forever)

    -- City of Dalaran
    [247126] = 145787,  -- Atrexis the Grave Knight
    [245999] = 129891,  -- Arcane Anomaly
    [246003] = 129894,  -- Fel Ancient
    [246017] = 129954,  -- Unstable Sentinel
    [246931] = 130220,  -- Mana Wraith
    [246008] = 129895,  -- Mana Devourer
    [246016] = 129900,  -- Arcanic Enigma (Mana Elemental)
    [247032] = 130235,  -- Lyn the Ignored
    [246020] = 130061,  -- Shade of the Archmage

    -- Gnomeregan
    [7361] = 144378,    -- Grubbis
    [7079] = 5497,      -- Viscous Fallout
    [6235] = 6915,      -- Electrocutioner 6000
    [6229] = 6774,      -- Crowd Pummeler 9-60
    [7800] = 6980,      -- Mekgineer Thermaplugg
    [6228] = 6669,      -- Dark Iron Ambassador

    -- Razorfen Kraul
    [6168] = 6110,      -- Roogug
    [4424] = 6097,      -- Aggem Thorncurse
    [4428] = 4644,      -- Death Speaker Jargba
    [4420] = 4652,      -- Overlord Ramtusk
    [4422] = 2450,      -- Agathelos the Raging
    [4421] = 4642,      -- Charlga Razorflank
    [4425] = 4735,      -- Blind Hunter
    [4842] = 6102,      -- Earthcaller Halmgar

    -- Scarlet Monastery: Graveyard
    [3983] = 2044,      -- Interrogator Vishas
    [6490] = 5534,      -- Azshir the Sleepless
    [6488] = 5230,      -- Fallen Champion
    [6489] = 5231,      -- Ironspine
    [4543] = 11396,     -- Bloodmage Thalnos

    -- Scarlet Monastery: Library
    [3974] = 2040,      -- Houndmaster Loksey
    [6487] = 5266,      -- Arcanist Doan

    -- Scarlet Monastery: Armory
    [3975] = 2041,      -- Herod

    -- Scarlet Monastery: Cathedral
    [4542] = 2605,      -- High Inquisitor Fairbanks
    [3976] = 2042,      -- Scarlet Commander Mograine
    [3977] = 2043,      -- High Inquisitor Whitemane

    -- Razorfen Downs
    [7355] = 7845,      -- Tuten'kash
    [7357] = 8055,      -- Mordresh Fire Eye
    [8567] = 7864,      -- Glutton
    [7354] = 11382,     -- Ragglesnout
    [7356] = 6124,      -- Plaguemaw the Rotting
    [7358] = 7971,      -- Amnennar the Coldbringer

    -- Lower Blackrock Spire
    [9219] = 11574,  -- Spirestone Butcher
    [9218] = 11576,  -- Spirestone Battle Lord
    [9217] = 11578,  -- Spirestone Lord Magus
    [9196] = 11565,  -- Highlord Omokk
    [9236] = 9732,  -- Shadow Hunter Vosh'gajin
    [9237] = 9733,  -- War Master Voone
    [10596] = 9929,  -- Mother Smolderweb
    [10376] = 9755,  -- Crystal Fang
    [10584] = 11583,  -- Urok Doomhowl
    [9596] = 9668,  -- Bannok Grimaxe
    [9736] = 9738,  -- Quartermaster Zigris
    [10220] = 9567,  -- Halycon
    [10268] = 9564,  -- Gizrul the Slavener
    [9718] = 11809,  -- Ghok Bashguud
    [9568] = 8711,  -- Overlord Wyrmthalak

    -- Upper Blackrock Spire
    [9816] = 2172,  -- Pyroguard Emberseer
    [10264] = 9581,  -- Solakar Flamewreath
    [10509] = 9686,  -- Jed Runewatcher
    [10899] = 10222,  -- Goraluk Anvilcrack
    [10339] = 9806,  -- Gyth
    [10429] = 9778,  -- Warchief Rend Blackhand
    [10430] = 10193,  -- The Beast
    [16042] = 14308,  -- Lord Valthalak
    [10363] = 10115,  -- General Drakkisath

    -- Blackrock Depths
    [9018] = 8761,  -- High Interrogator Gerstahn
    [9025] = 5781,  -- Lord Roccor
    [9319] = 9212,  -- Houndmaster Grebmar
    [9027] = 8760,  -- Gorosh the Dervish
    [9028] = 7873,  -- Grizzle
    [9029] = 523,  -- Eviscerator
    [9030] = 11538,  -- Ok'thor the Breaker
    [9031] = 3004,  -- Anub'shiah
    [9032] = 8271,  -- Hedrum the Creeper
    [9024] = 8762,  -- Pyromancer Loregrain
    [9056] = 8704,  -- Fineous Darkvire
    [9041] = 9089,  -- Warder Stilgiss
    [9017] = 1204,  -- Lord Incendius
    [9016] = 12162,  -- Bael'Gar
    [9033] = 8756,  -- General Angerforge
    [8983] = 8759,  -- Golem Lord Argelmach
    [9537] = 8658,  -- Hurley Blackbreath
    [9502] = 8177,  -- Phalanx
    [9543] = 8667,  -- Ribbly Screwspigot
    [9499] = 8652,  -- Plugger Spazzring
    [9156] = 8329,  -- Ambassador Flamelash
    [8923] = 8270,  -- Panzor the Invincible
    [9039] = 8687,  -- The Seven
    [9938] = 12162,  -- Magmus
    [8929] = 8705,  -- Princess Moira Bronzebeard
    [9019] = 8807,  -- Emperor Dagran Thaurissan

    -- Dire Maul: East
    [11490] = 11335,  -- Zevrim Thornhoof
    [14354] = 7552,   -- Pusillin
    [13280] = 5489,   -- Hydrospawn
    [14327] = 14378,  -- Lethtendris
    [11492] = 14416,  -- Alzzin the Wildshaper

    -- Dire Maul: West
    [11489] = 14383,  -- Tendris Warpwood
    [11488] = 11270,  -- Illyanna Ravenoak
    [11467] = 11250,  -- Tsu'zee
    [11487] = 14384,  -- Magister Kalendris
    [11496] = 14173,  -- Immol'thar
    [14506] = 14556,  -- Lord Hel'nurath
    [11486] = 11256,  -- Prince Tortheldrin

    -- Dire Maul: North
    [14326] = 11561,  -- Guard Mol'dar
    [14322] = 11545,  -- Stomper Kreeg
    [14321] = 11561,  -- Guard Fengus
    [14323] = 11561,  -- Guard Slip'kik
    [14325] = 11564,  -- Captain Kromcrush
    [14324] = 11537,  -- Cho'Rush the Observer
    [11501] = 11583,  -- King Gordok

    -- Stratholme: Living
    [10393] = 2606,   -- Skul
    [10558] = 10482,  -- Hearthsinger Forresten
    [10516] = 10771,  -- The Unforgiven
    [10808] = 571,    -- Timmy the Cruel
    [11032] = 10458,  -- Malor the Zealous
    [11143] = 10669,  -- Postmaster Malown
    [10997] = 10674,  -- Cannon Master Willey
    [10811] = 10544,  -- Archivist Galford
    [10813] = 10691,  -- Balnazzar

    -- Stratholme: Undead
    [10809] = 7856,   -- Stonespine
    [10435] = 10433,  -- Magistrate Barthilas
    [10437] = 9793,   -- Nerub'enkan
    [10436] = 10698,  -- Baroness Anastari
    [10438] = 10546,  -- Maleki the Pallid
    [10439] = 12818,  -- Ramstein the Gorger
    [10440] = 10729,  -- Baron Rivendare

    -- Sunken Temple
    -- altarbosses (2.0.24): the six troll guardians (Wowhead Forever display IDs).
    [5713] = 6698,   -- Gasher
    [5715] = 6702,   -- Hukku
    [5714] = 6700,   -- Loro
    [5717] = 6707,   -- Mijan
    [5712] = 6699,   -- Zolo
    [5716] = 6701,   -- Zul'Lor
    [8580] = 7873,   -- Atal'alarion
    [5721] = 7553,   -- Dreamscythe
    [5720] = 6375,   -- Weaver
    [8443] = 8053,   -- Avatar of Hakkar
    [5710] = 6708,   -- Jammal'an the Prophet
    [5711] = 6709,   -- Ogom the Wretched
    [5719] = 7975,   -- Morphaz
    [5722] = 9584,   -- Hazzas
    [5709] = 7806,   -- Shade of Eranikus

    -- Scholomance
    [10506] = 143673, -- Kirtonos the Herald
    [10503] = 11073,  -- Jandice Barov
    [11622] = 12073,  -- Rattlegore
    [10433] = 10248,  -- Marduk Blackpool
    [10432] = 2606,   -- Vectus
    [10508] = 7919,   -- Ras Frostwhisper
    [10505] = 11069,  -- Instructor Malicia
    [11261] = 10901,  -- Doctor Theolen Krastinov
    [10901] = 11492,  -- Lorekeeper Polkelt
    [10507] = 10433,  -- The Ravenian
    [10504] = 11072,  -- Lord Alexei Barov
    [10502] = 11835,  -- Lady Illucia Barov
    [1853] = 11070,  -- Darkmaster Gandling
    [14516] = 14591,  -- Death Knight Darkreaver (darkreaver 2.0.8: Wowhead Forever NPC page)
    [16118] = 16020,  -- Kormok (kormok 2.0.8: Wowhead Forever NPC page)
    [11058] = 10475,  -- Ezra Grimm (ezragrimm 2.0.8: Wowhead Forever NPC page)

    -- Maraudon
    [13282] = 11172,  -- Noxxion
    [12258] = 12389,  -- Razorlash
    [12236] = 12334,  -- Lord Vyletongue
    [12237] = 9014,   -- Meshlok the Harvester
    [12225] = 12350,  -- Celebras the Cursed
    [12203] = 12293,  -- Landslide
    [13601] = 7125,   -- Tinkerer Gizlock
    [13596] = 13589,  -- Rotgrip
    [12201] = 12292,  -- Princess Theradras

    -- Uldaman
    [6910] = 5945,  -- Revelosh
    [6906] = 5710,  -- The Lost Dwarves
    [7228] = 6089,  -- Ironaya
    [7206] = 10798, -- Ancient Stone Keeper
    [7291] = 6059,  -- Galgann Firehammer
    [4854] = 11165, -- Grimlok
    [2748] = 5988,  -- Archaedas

    -- Zul'Farrak
    [7272] = 6696,  -- Theka the Martyr
    [8127] = 7353,  -- Antu'sul
    [7271] = 6434,  -- Witch Doctor Zum'rah
    [7796] = 6690,  -- Nekrum Gutchewer
    [7275] = 6441,  -- Shadowpriest Sezz'ziz
    [7604] = 6433,  -- Sergeant Bly (Wowhead Forever model)
    [7795] = 6685,  -- Hydromancer Velratha
    [7273] = 7271,  -- Gahz'rilla
    [10082] = 9293,  -- Zerillis
    [10080] = 9291,  -- Sandarr Dunereaver
    [10081] = 9292,  -- Dustwraith
    [7797] = 6687,  -- Ruuzlu
    [7267] = 6439,  -- Chief Ukorz Sandscalp

    -- 1.9.4: the Forever dungeons added since, so their portraits are drawn
    -- at login with the rest instead of waiting for the game to know the
    -- creature (question marks until then). Wowhead Forever NPC pages' model.
    -- The Drowned City
    [258905] = 144475,  -- Zul'Alai
    [258924] = 144487,  -- Var'Taka
    [260042] = 142144,  -- Captain Dreadrise
    [270885] = 142245,  -- Deathless Marrow (the client's "Staging Area" copy)
    [270887] = 129945,  -- Primeval Elemental (the client's "Staging Area" copy)
    [264177] = 144023,  -- Gill
    [264172] = 144022,  -- Umbra
    [260468] = 142457,  -- "Pyromancer" Braxton
    [260274] = 142322,  -- Min'loth the Serpent
    -- Krol'dok Stronghold
    [258966] = 141217,  -- Slavecrusher Grox
    [258972] = 141219,  -- Twilight Commander Zarmok
    [259281] = 141443,  -- War Handler Ashka
    [258964] = 141215,  -- Nar'gurk
    [264773] = 14424,   -- Bossman Toof
    [258968] = 141218,  -- Overlord Mugg
    [262716] = 17273,   -- Kroog (rare)
    [268423] = 145448,  -- Zalfan Moonshadow (quest target, Wowhead Forever; zalfanpin)
    [259256] = 144671,  -- Tunk (quest target; tunkpin; the look M's game gave him, 20 Nov 2026)
    -- Alcaz Prison
    [255391] = 7914,    -- Overseer Wrex
    [255997] = 4973,    -- Tidemistress Ca'zass
    [257016] = 2317,    -- Katerina the Cleaner
    [256236] = 140092,  -- The Questioner
    [255702] = 6374,    -- Blazeroar
    -- Shaper's Terrace
    [253201] = 142989,  -- Titanosaur
    [261813] = 144511,  -- Venomridge
    [261812] = 144514,  -- Thunderhoof
    [262127] = 144515,  -- Direhorn Matriarch
    [262081] = 143063,  -- Bolt
    [272561] = 147098,  -- Vitrix
    [261809] = 143832,  -- Nanaya
    [253218] = 143040,  -- Izha'Rel
    [261811] = 143039,  -- Tor'Rel
    -- Blackmaw Hold
    [247195] = 140708,  -- Withermaw
    [247206] = 130432,  -- Impaan the Imprisoner
    [247209] = 130440,  -- Elder Shaman Bloodmane
    [247198] = 130427,  -- Bonesnout the Unbroken
    [247234] = 130447,  -- Varrox Bleakhoof
    [247207] = 130436,  -- Blackmaw Behemoth
    [247231] = 131644,  -- Unbound Spirit
    [269104] = 12235,   -- Moontouched Wanderer
    [269111] = 145808,  -- Gortek the Apprentice
    -- bakelooks (2.0.9): the five bosses that were known by NPC ID only:
    -- their looks as the game gave them on M's client (15 Nov 2026; Obsidian
    -- Sentinel's and Theldren's are AzerothCore's too). Each has its bundled
    -- picture, so nothing is asked of the game for them any more.
    [7023] = 5285,      -- Obsidian Sentinel (Uldaman)
    [16101] = 16018,    -- Jarien (jariensothos 2.0.9: https://octowow.st/db/?npc=16101)
    [16102] = 16003,    -- Sothos (https://octowow.st/db/?npc=16102)
    [16080] = 15997,    -- Mor Grayhoof (morgrayhoof 2.0.9: https://octowow.st/db/?npc=16080)
    [16097] = 16000,    -- Isalien (isalien 2.1.1: Wowhead Forever NPC 16097, model 16000)
    [10263] = 5047,     -- Burning Felguard (lbrsaudit 2.0.9: https://octowow.st/db/?npc=10263)
    [16059] = 15981,    -- Theldren (Blackrock Depths)
    [250034] = 2424,    -- Tunnelweb Matriarch (Blackmaw Hold)
    [269151] = 6829,    -- Sabella No-Eyes (Blackmaw Hold; sabella 2.1.2: Wowhead Forever NPC 269151, model 6829)
    [261974] = 143035,  -- Cinder (Shaper's Terrace)
    [262297] = 143122,  -- Snowtalon (Shaper's Terrace)
}

-- 1.9.4: Primeval Elemental (The Drowned City) has no NPC ID of its own yet:
-- its picture from the client's "Staging Area" copy, like Deathless Marrow.
do
    local drowned = FDJ.DB and FDJ.DB["The Drowned City"]
    for _, boss in ipairs((drowned and drowned.bosses) or {}) do
        if boss.name == "Primeval Elemental" and not boss.npcID and not boss.portraitNpcID then boss.portraitNpcID = 270887 end
    end
end

-- Trash mobs named as the source of a trash drop: name -> creature display ID
-- (Wowhead Forever NPC pages). Used to draw their portraits on the loot row.
FDJ.TRASH_MOB_DISPLAY_IDS = {
    ["Druid of the Fang"] = 4211, -- npc 3840
    ["Skeleton"] = 9786, -- npc 250618
    ["Shrieking Banshee"] = 10728, -- npc 250620
    ["Ragged Ghoul"] = 414, -- npc 250622
    ["Skeletal Mage"] = 7550, -- npc 250624
    ["Skeletal Soldier"] = 7848, -- npc 250626
    ["Ghoul"] = 1065, -- npc 250627
    ["Plague Ghoul"] = 559, -- npc 250630
    ["Flesh Golem"] = 1693, -- npc 255109
    ["Stone Watcher"] = 7534, -- npc 250629
    ["Fallen Necromancer"] = 9785, -- npc 255964
    ["Goblin Engineer"] = 7109, -- npc 622
    ["Defias Overseer"] = 2316, -- npc 634
    ["Defias Blackguard"] = 2314, -- npc 636
    ["Defias Pirate"] = 2347, -- npc 657
    ["Defias Evoker"] = 2318, -- npc 1729
    ["Defias Squallshaper"] = 2349, -- npc 1732
    ["Defias Strip Miner"] = 2438, -- npc 4416
    ["Defias Taskmaster"] = 2440, -- npc 4417
    ["Defias Wizard"] = 2447, -- npc 4418
    -- City of Dalaran
    ["Dark Caster"] = 7555, -- npc 255072
    ["Fallen Mage"] = 9783, -- npc 255066
    ["Kirin Tor Necromancer"] = 145809, -- npc 269134
    ["Fragmented Sentry"] = 130102, -- npc 246664
    -- Scarlet Monastery
    ["Scarlet Defender"] = 2462, -- npc 4298
    ["Scarlet Myrmidon"] = 2514, -- npc 4295
    ["Scarlet Champion"] = 2460, -- npc 4302
    ["Scarlet Centurion"] = 2499, -- npc 4301
    -- The Drowned City
    ["Risen Sentry"] = 145398, -- npc 258792
    ["Champion of the Deep"] = 145404, -- npc 258797
    ["Brinescale Sorceress"] = 4975, -- npc 258804
    ["Makrura Snapper"] = 2426, -- npc 258897
    -- Krol'dok Stronghold
    ["Twilight Grunt"] = 140001, -- npc 258042
    ["Twilight Lieutenant"] = 143142, -- npc 258104
    ["Redridge Prisoner"] = 487, -- npc 257900
    -- Alcaz Prison
    ["Alcaz Chaplain"] = 138722, -- npc 255262
    ["Alcaz Jailer"] = 138843, -- npc 255377 and 271784
    ["Strashaz Soldier"] = 4764, -- npc 255995
    ["Slavering Hound"] = 6195, -- npc 255267
    ["Defias Truthfinder"] = 144356, -- npc 255271
    -- sttrash (2.0.28): Sunken Temple
    ["Spawn of Hakkar"] = 4065, -- npc 5708
    ["Murk Worm"] = 7549, -- npc 5226
    -- (Atal'ai Witch Doctor: by NPC ID below, 2.0.29; Wowhead's display 56741
    -- drew nothing in the game.)
    -- brdrecipes / lbrsrecipes (2.0.7): the mobs that drop Blackrock Depths' and
    -- Lower Blackrock Spire's trash recipes (display IDs: octowow.st Classic
    -- database, https://octowow.st/db/?npc=<id>)
    ["Weapon Technician"] = 8894, -- npc 8920
    ["Doomforge Craftsman"] = 8803, -- npc 8897
    ["Doomforge Arcanasmith"] = 8812, -- npc 8900
    ["Ribbly's Crony"] = 9233, -- npc 10043
    ["Hammered Patron"] = 8681, -- npc 9554
    ["Bloodaxe Veteran"] = 9633, -- npc 9583
    ["Firebrand Pyromancer"] = 9656, -- npc 9264
    ["Firebrand Legionnaire"] = 9660, -- npc 9260
    ["Spirestone Warlord"] = 11582, -- npc 9216
    ["Spirestone Mystic"] = 11579, -- npc 9198
    -- ubrsrecipes (2.0.7): Upper Blackrock Spire
    ["Blackhand Elite"] = 9734, -- npc 10317
    -- lootaudit (2.0.8, M 15 Nov 2026): the new loot rows' mobs, their
    -- displays from Wowhead Forever's NPC pages
    ["Goblin Shipbuilder"] = 7112, -- npc 3947
    ["Razorfen Spearhide"] = 6078, -- npc 4438
    ["Wildspawn Rogue"] = 2021, -- npc 11452
    ["Wildspawn Betrayer"] = 10032, -- npc 11454
    -- dmtrash (2.0.9, M 16 Nov 2026): Dire Maul trash, by their looks (octowow.st
    -- Classic database, https://octowow.st/db/?npc=<id>; Phase Lasher also
    -- classicdb.ch). Were by NPC ID first: the game's lookup gave several of
    -- them another mob's look (a flower as a tree, trees as satyrs).
    ["Warpwood Crusher"] = 12929, -- npc 13021
    ["Warpwood Stomper"] = 6350, -- npc 11465
    ["Wildspawn Satyr"] = 11345, -- npc 11451
    ["Phase Lasher"] = 13109, -- npc 13196
    ["Mana Remnant"] = 14272, -- npc 11483
    ["Arcane Aberration"] = 14253, -- npc 11480
    ["Residual Monstrosity"] = 14254, -- npc 11484
    -- mobpics (2.0.9): a row shows no portraits at all while one of its mobs
    -- is unknown (the Wand had Arcane Torrent, the Talisman a family name)
    ["Arcane Torrent"] = 10315, -- npc 14399
    ["Eldreth Spirit"] = 10751, -- npc 11472 (stands for all Eldreth spirits)
    ["Ironbark Protector"] = 13489, -- npc 11459
    ["Petrified Treant"] = 2078, -- npc 11458
    ["Scarlet Soldier"] = 2522, -- npc 4286
    ["Scarlet Gallant"] = 2463, -- npc 4287
    ["Scarlet Beastmaster"] = 2497, -- npc 4288
    ["Scarlet Guardsman"] = 2511, -- npc 4290
    ["Scarlet Protector"] = 2476, -- npc 4292
    ["Scarlet Chaplain"] = 2501, -- npc 4299
    ["Scarlet Monk"] = 2603, -- npc 4540
    ["Arcanist Doan"] = 5266, -- npc 6487
    -- bakelooks (2.0.9): the mobs known by NPC ID only (TRASH_MOB_NPC_IDS,
    -- below), now with their look, so the bundled picture shows at once and
    -- nothing is asked of the game for them: the look the game itself gave
    -- for the NPC on M's client (/dj bake, 15 Nov 2026); where the game gave
    -- none, AzerothCore's creature_template_model (marked). Phantasm, Mana
    -- Stalker and Mindless Horror are still found in the game.
    ["Scarlet Diviner"] = 2507, -- npc 4291 (AzerothCore)
    ["Atal'ai Witch Doctor"] = 6671, -- npc 5259
    ["Spectral Citizen"] = 10484, -- npc 10384
    ["Thuzadin Shadowcaster"] = 10632, -- npc 10398
    ["Thuzadin Necromancer"] = 10542, -- npc 10400
    ["Ghoul Ravener"] = 10626, -- npc 10406
    ["Fleshflayer Ghoul"] = 414, -- npc 10407 (AzerothCore)
    ["Rockwing Gargoyle"] = 7533, -- npc 10408
    ["Rockwing Screecher"] = 11071, -- npc 10409
    ["Crypt Crawler"] = 6841, -- npc 10412
    ["Crypt Beast"] = 9758, -- npc 10413
    ["Patchwork Horror"] = 1693, -- npc 10414 (AzerothCore)
    ["Bile Spewer"] = 9760, -- npc 10416
    ["Venom Belcher"] = 12819, -- npc 10417
    ["Crimson Guardsman"] = 10495, -- npc 10418
    ["Crimson Conjuror"] = 10490, -- npc 10419
    ["Crimson Initiate"] = 10497, -- npc 10420
    ["Crimson Defender"] = 10500, -- npc 10421
    ["Crimson Sorcerer"] = 10504, -- npc 10422
    ["Crimson Priest"] = 10509, -- npc 10423
    ["Crimson Gallant"] = 10515, -- npc 10424
    ["Crimson Battle Mage"] = 10530, -- npc 10425
    ["Crimson Inquisitor"] = 10516, -- npc 10426
    ["Wailing Banshee"] = 8782, -- npc 10464
    ["Scholomance Adept"] = 11161, -- npc 10469
    ["Scholomance Occultist"] = 11126, -- npc 10472
    ["Scholomance Necromancer"] = 11155, -- npc 10477
    ["Splintered Skeleton"] = 9788, -- npc 10478
    ["Risen Warrior"] = 7847, -- npc 10486
    ["Risen Protector"] = 11489, -- npc 10487
    ["Risen Construct"] = 12074, -- npc 10488
    ["Risen Bonewarder"] = 11397, -- npc 10491
    ["Diseased Ghoul"] = 519, -- npc 10495
    ["Spectral Researcher"] = 3942, -- npc 10499 (AzerothCore)
    ["Spectral Teacher"] = 3942, -- npc 10500
    ["Crimson Monk"] = 10534, -- npc 11043
    ["Scholomance Handler"] = 11124, -- npc 11257
    ["Scholomance Dark Summoner"] = 11177, -- npc 11582
    ["Mana Echo"] = 14272, -- npc 246600
    ["Arcane Elemental"] = 130208, -- npc 246888
    ["Arcane Echo"] = 130218, -- npc 246992
    ["Saturated Remnant"] = 130223, -- npc 247001
    ["Seeking Remnant"] = 130224, -- npc 247003
    ["Legashi Summoner"] = 2875, -- npc 247248
    ["Fallen Warrior"] = 200, -- npc 255069
    ["Skeletal Warder"] = 612, -- npc 255070
    ["Blackmaw Druid"] = 3024, -- npc 258516
    ["Krol'dok Brute"] = 1045, -- npc 258687
    ["Marsh Crocolisk"] = 1035, -- npc 260796
    ["Young Riptooth"] = 960, -- npc 260799
    ["Thicket Lurker"] = 1337, -- npc 260800
    ["Thicket Hunter"] = 11315, -- npc 260801
    ["Thicket Matriarch"] = 1339, -- npc 260802
    ["Highland Spider"] = 1088, -- npc 260803
    ["Highland Lurker"] = 545, -- npc 260804
    ["Highland Snapper"] = 7114, -- npc 260810
    ["Marsh Skulker"] = 807, -- npc 274715
}

-- trashnpc (2.0.22): trash mobs whose look is not known yet, by NPC ID
-- (Wowhead Forever and Icy Veins Forever NPC pages). Their portraits are
-- found in the game as the bosses' are (a hidden model of the NPC tells its
-- display), then drawn on the loot row like the ones above.
FDJ.TRASH_MOB_NPC_IDS = {
    -- Sunken Temple (2.0.29)
    ["Atal'ai Witch Doctor"] = 5259,
    -- City of Dalaran
    ["Mana Echo"] = 246600,
    ["Arcane Elemental"] = 246888,
    ["Phantasm"] = 246990,
    ["Arcane Echo"] = 246992,
    ["Mana Stalker"] = 246993,
    ["Saturated Remnant"] = 247001,
    ["Seeking Remnant"] = 247003,
    ["Mindless Horror"] = 255068,
    ["Fallen Warrior"] = 255069,
    ["Skeletal Warder"] = 255070,
    -- Stratholme (strattrash, 2.0.6; Wowhead Forever / Icy Veins Forever NPC IDs;
    -- Shrieking Banshee and Plague Ghoul: already drawn above, by their look)
    ["Crimson Guardsman"] = 10418,
    ["Crimson Conjuror"] = 10419,
    ["Crimson Initiate"] = 10420,
    ["Crimson Defender"] = 10421,
    ["Crimson Sorcerer"] = 10422,
    ["Crimson Priest"] = 10423,
    ["Crimson Gallant"] = 10424,
    ["Crimson Battle Mage"] = 10425,
    ["Crimson Inquisitor"] = 10426,
    ["Crimson Monk"] = 11043,
    ["Rockwing Gargoyle"] = 10408,
    ["Rockwing Screecher"] = 10409,
    ["Wailing Banshee"] = 10464,
    ["Ghoul Ravener"] = 10406,
    ["Fleshflayer Ghoul"] = 10407,
    ["Crypt Crawler"] = 10412,
    ["Crypt Beast"] = 10413,
    ["Thuzadin Necromancer"] = 10400,
    ["Thuzadin Shadowcaster"] = 10398,
    ["Bile Spewer"] = 10416,
    ["Venom Belcher"] = 10417,
    ["Patchwork Horror"] = 10414,
    ["Spectral Citizen"] = 10384,
    -- Blackmaw Hold (2.0.6; Wowhead Forever "Dropped by" NPC IDs)
    ["Legashi Summoner"] = 247248,
    ["Blackmaw Druid"] = 258516,
    -- Scholomance (scholotrash, 2.0.6; Wowhead Forever / Icy Veins Forever NPC IDs)
    ["Scholomance Adept"] = 10469,
    ["Scholomance Necromancer"] = 10477,
    ["Scholomance Occultist"] = 10472,
    ["Scholomance Dark Summoner"] = 11582,
    ["Scholomance Handler"] = 11257,
    ["Diseased Ghoul"] = 10495,
    ["Spectral Researcher"] = 10499,
    ["Spectral Teacher"] = 10500,
    ["Splintered Skeleton"] = 10478,
    ["Risen Construct"] = 10488,
    ["Risen Bonewarder"] = 10491,
    ["Risen Warrior"] = 10486,
    ["Risen Protector"] = 10487,
    -- Excavation Site: Wetlands (2.0.30; the client's npc table)
    ["Highland Lurker"] = 260804,
    ["Marsh Crocolisk"] = 260796,
    ["Highland Spider"] = 260803,
    ["Thicket Hunter"] = 260801,
    ["Marsh Skulker"] = 274715,
    ["Thicket Matriarch"] = 260802,
    ["Thicket Lurker"] = 260800,
    ["Young Riptooth"] = 260799,
    ["Highland Snapper"] = 260810,
    -- lootaudit2 (2.0.8): their looks found in the game by NPC ID (Wowhead
    -- Forever was asking for a human check, so no display IDs this time)
    ["Krol'dok Brute"] = 258687,
    -- lootaudit3 (2.0.9): Alcaz Prison, the Enchantresses' Spire (Wowhead Forever npc)
    ["Strashaz Enchantress"] = 255373,

    ["Scarlet Diviner"] = 4291,
}
