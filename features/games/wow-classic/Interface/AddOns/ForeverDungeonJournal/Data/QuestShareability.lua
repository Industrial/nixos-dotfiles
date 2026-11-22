-- Uses the addon namespace (the journal reads FDJ.QUEST_SHAREABILITY_AUDIT from it).
local ADDON_NAME, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS

-- Audited quest shareability for dungeon quests and their prerequisite chains.
-- Entries here override the runtime predicate so the journal can show reliable
-- information even when the quest is not currently in the player's quest log.
-- Quests omitted from this table intentionally fall back to
-- C_QuestLog.IsPushableQuest(questID), which is authoritative on Forever.
FDJ.QUEST_SHAREABILITY_AUDIT = {
    -- Hall of Thanes
    [96395] = true,   -- An Ancient Grudge
    [96403] = true,   -- Important Heirlooms
    [96394] = true,   -- The Restless Dead
    [96393] = true,   -- Old Ironforge Incursion
    [96391] = false,  -- Underground Map

    -- Wailing Caverns
    [1486] = true,    -- Deviate Hides
    [1491] = true,    -- Smart Drinks
    [959] = true,     -- Trouble at the Docks
    [1487] = true,    -- Deviate Eradication
    [6981] = false,   -- The Glowing Shard
    [914] = true,     -- Leaders of the Fang
    [962] = true,     -- Serpentbloom
    [865] = true,     -- Raptor Horns
    [870] = true,     -- The Forgotten Pools
    [877] = false,    -- The Stagnant Oasis
    [880] = true,     -- Altered Beings
    [1489] = true,    -- Hamuul Runetotem
    [1490] = true,    -- Nara Wildmane

    -- Ruins of Lordaeron
    [95250] = true,   -- Abominable Creatures
    [97288] = true,   -- Unending Torment
    [92401] = true,   -- A Frightened Request
    [95195] = true,   -- Bloodied Insignia
    [95189] = true,   -- Crest of Lordaeron (Alliance)
    [95204] = true,   -- Crest of Lordaeron (Horde)
    [92421] = true,   -- Light's Justice
    [92415] = false,  -- Remember That I Love You
    [95216] = true,   -- The New Plague
    [92422] = true,   -- The Wrath of Rath'mael

    -- The Deadmines
    [214] = true,     -- Red Silk Bandanas
    [168] = true,     -- Collecting Memories
    [92753] = false,  -- Destruction in Deadmines
    [167] = true,     -- Oh Brother...
    [2040] = true,    -- Underground Assault
    [166] = true,     -- The Defias Brotherhood (dungeon finale)
    [373] = false,    -- The Unsent Letter

    -- The Defias Brotherhood prerequisite chain
    [65] = true,
    [132] = false,
    [135] = false,
    [141] = false,
    [142] = true,
    [155] = false,

    -- Deadmines / Toxic Soil prerequisite chain
    [92742] = false,  -- Testing the Wells
    [92744] = true,   -- Murloc Gills
    [92745] = true,   -- The State of the Mines
    -- 92747, 92748, 92750 and 92751 intentionally use the live client predicate.
    [92749] = true,   -- A Dynamite Plan
    [92752] = false,  -- Explosive Consultation
    [92819] = true,   -- Detonation at a Distance (final use step)

    -- Blackfathom Deeps
    [971] = true,     -- Knowledge in the Deeps
    [1275] = true,    -- Researching the Corruption
    [1198] = true,    -- In Search of Thaelrid
    [1200] = true,    -- Blackfathom Villainy (Alliance)
    [1199] = true,    -- Twilight Falls
    [6564] = false,   -- Allegiance to the Old Gods (item-start step)
    [6922] = false,   -- Baron Aquanis (item-start quest from Strange Water Globe)
    [6562] = true,    -- Trouble in the Deeps
    [6563] = true,    -- Essence of Aku'Mai
    [6565] = true,    -- Allegiance to the Old Gods (final)
    [6561] = true,    -- Blackfathom Villainy (Horde)
    [6921] = true,    -- Amongst the Ruins
    [3765] = true,    -- The Corruption Abroad

    -- Ragefire Chasm
    [5723] = true,    -- Testing an Enemy's Strength
    [5722] = true,    -- Searching for the Lost Satchel
    [5724] = false,   -- Returning the Lost Satchel
    [5728] = true,    -- Hidden Enemies (dungeon step)
    [5761] = true,    -- Slaying the Beast
    [5725] = true,    -- The Power to Destroy...
    [5726] = true,    -- Hidden Enemies, step 1
    [5727] = false,   -- Hidden Enemies, step 2

    -- Gnomeregan ring chain
    [2945] = false,  -- Grime-Encrusted Ring
    [2947] = false,  -- Return of the Ring (Alliance)
    [2948] = false,  -- Gnome Improvement
    [2949] = false,  -- Return of the Ring (Horde)
    [2950] = false,  -- Nogg's Ring Redo

    -- Shadowfang Keep
    [1098] = true,    -- Deathstalkers in Shadowfang
    [1740] = true,    -- The Orb of Soran'ruk
    [1013] = true,    -- The Book of Ur
    [1014] = true,    -- Arugal Must Die

    -- The Stockade
    [386] = true,     -- What Comes Around...
    [377] = true,     -- Crime and Punishment
    [387] = true,     -- Quell The Uprising
    [388] = true,     -- The Color of Blood
    [378] = true,     -- The Fury Runs Deep
    [391] = true,     -- The Stockade Riots
    [303] = true,     -- The Dark Iron War
    [389] = true,     -- Bazil Thredd

    -- Classic Era sharing index (Maraudon onwards), 22 Oct 2026. Quests and their chain steps.
    -- Maraudon
    [7067] = false,  -- The Pariah's Instructions
    [7068] = true,   -- Shadowshard Fragments
    [7070] = true,   -- Shadowshard Fragments
    [7029] = false,  -- Vyletongue Corruption
    [7041] = false,  -- Vyletongue Corruption
    [7028] = true,   -- Twisted Evils
    [7044] = true,   -- Legends of Maraudon
    [7064] = true,   -- Corruption of Earth and Seed
    [7065] = true,   -- Corruption of Earth and Seed
    [7066] = false,  -- Seed of Life
    [7046] = false,  -- The Scepter of Celebras
    -- Sunken Temple
    [1475] = true,   -- Into The Temple of Atal'Hakkar
    [1448] = true,   -- In Search of The Temple
    [1449] = true,   -- To The Hinterlands
    [1450] = true,   -- Gryphon Master Talonaxe
    [1451] = true,   -- Rhapsody Shindigger
    [1452] = true,   -- Rhapsody's Kalimdor Kocktail
    [1469] = false,  -- Rhapsody's Tale
    [1445] = true,   -- The Temple of Atal'Hakkar
    [1424] = true,   -- Pool of Tears
    [1429] = false,  -- The Atal'ai Exile
    [1444] = true,   -- Return to Fel'Zerul
    [3446] = false,  -- Into the Depths
    [3444] = true,   -- The Stone Circle
    [3447] = true,   -- Secret of the Circle
    [1446] = true,   -- Jammal'an the Prophet
    [3528] = false,  -- The God Hakkar
    [3520] = false,  -- Screecher Spirits
    [3527] = true,   -- The Prophecy of Mosh'aru
    [4787] = true,   -- The Ancient Egg
    [3373] = false,  -- The Essence of Eranikus
    [4143] = true,   -- Haze of Evil
    [4141] = true,   -- Muigin and Larion
    [4142] = false,  -- A Visit to Gregan
    [4146] = false,  -- Zapper Fuel
    [4145] = true,   -- Larion and Muigin
    [4147] = true,   -- Marvon's Workshop
    [9063] = false,  -- Torwa Pathfinder
    [9053] = false,  -- A Better Ingredient
    [9052] = false,  -- Bloodpetal Poison
    [8151] = false,  -- The Hunter's Charm
    [8232] = false,  -- The Green Drake
    [8153] = false,  -- Courser Antlers
    [8231] = false,  -- Wavethrashing
    [8250] = false,  -- Magecraft
    [8253] = false,  -- Destroy Morphaz
    [8251] = false,  -- Magic Dust
    [8252] = false,  -- The Siren's Coral
    [8415] = false,  -- Chillwind Point
    [8418] = true,   -- Forging the Mightstone
    [8414] = false,  -- Dispelling Evil
    [8416] = false,  -- Inert Scourgestones
    [8254] = true,   -- Cenarion Aid
    [8257] = false,  -- Blood of Morphaz
    [8255] = true,   -- Of Coursers We Know
    [8256] = false,  -- The Ichor of Undeath
    [8233] = false,  -- A Simple Request
    [8236] = false,  -- The Azure Key
    [8234] = true,   -- Sealed Azure Bag
    [8235] = false,  -- Encoded Fragments
    [8413] = false,  -- Da Voodoo
    [8410] = false,  -- Elemental Mastery
    [8412] = false,  -- Spirit Totem
    [8422] = false,  -- Trolls of a Feather
    [8419] = false,  -- An Imp's Request
    [8420] = false,  -- Hot and Itchy
    [8421] = false,  -- The Wrong Stuff
    [8417] = false,  -- A Troubled Spirit
    [8425] = false,  -- Voodoo Feathers
    [8423] = false,  -- Warrior Kinship
    [8424] = false,  -- War on the Shadowsworn
    [9051] = false,  -- Toxic Test
    -- Blackrock Depths
    [3802] = true,   -- Dark Iron Legacy
    [3801] = true,   -- Dark Iron Legacy
    [4123] = true,   -- The Heart of the Mountain
    [4083] = true,   -- The Spectral Chalice
    [4324] = true,   -- Yuka Screwspigot
    [4136] = true,   -- Ribbly Screwspigot
    [4201] = false,  -- The Love Potion
    [4128] = true,   -- Ragnar Thunderbrew
    [4126] = true,   -- Hurley Blackbreath
    [4133] = true,   -- Vivian Lagrave
    [4134] = true,   -- Lost Thunderbrew Recipe
    [4263] = true,   -- Incendius!
    [4262] = true,   -- Overmaster Pyron
    [3907] = true,   -- Disharmony of Fire
    [3906] = true,   -- Disharmony of Flame
    [7201] = true,   -- The Last Element
    [4182] = true,   -- Dragonkin Menace
    [4183] = false,  -- The True Masters
    [4184] = false,  -- The True Masters
    [4185] = true,   -- The True Masters
    [4186] = false,  -- The True Masters
    [4223] = true,   -- The True Masters
    [4224] = true,   -- The True Masters
    [4241] = true,   -- Marshal Windsor
    [4242] = true,   -- Abandoned Hope
    [4264] = false,  -- A Crumpled Up Note
    [4282] = true,   -- A Shred of Hope
    [3981] = true,   -- Commander Gor'shak
    [4063] = true,   -- The Rise of the Machines
    [4061] = true,   -- The Rise of the Machines
    [4062] = false,  -- The Rise of the Machines
    [4081] = true,   -- KILL ON SIGHT: Dark Iron Dwarves
    [4082] = true,   -- KILL ON SIGHT: High Ranking Dark Iron Officials
    [4132] = true,   -- Operation: Death to Angerforge
    [4122] = false,  -- Grark Lorkrub
    [4024] = false,  -- A Taste of Flame
    [4362] = true,   -- The Fate of the Kingdom
    [3702] = true,   -- The Smoldering Ruins of Thaurissan
    [3701] = true,   -- The Smoldering Ruins of Thaurissan
    [4341] = true,   -- Kharan Mighthammer
    [4342] = true,   -- Kharan's Tale
    [4361] = true,   -- The Bearer of Bad News
    [4003] = true,   -- The Royal Rescue
    [4001] = true,   -- What Is Going On?
    [4002] = true,   -- The Eastern Kingdom
    [4286] = true,   -- The Good Stuff
    [7848] = false,  -- Attunement to the Core
    [7604] = false,  -- A Binding Contract
    [4322] = false,  -- Jail Break!
    [3982] = false,  -- What Is Going On?
    [4121] = false,  -- Precarious Predicament
    -- Lower Blackrock Spire
    [4742] = true,   -- Seal of Ascension
    [5001] = true,   -- Bijou's Belongings
    [4982] = true,   -- Bijou's Belongings
    [4981] = true,   -- Operative Bijou
    [5081] = true,   -- Maxwell's Mission
    [5002] = false,  -- Message to Maxwell
    [4903] = false,  -- Warlord's Command
    [4701] = true,   -- Put Her Down
    [4724] = true,   -- The Pack Mistress
    [4729] = false,  -- Kibler's Exotic Pets
    [4862] = true,   -- En-Ay-Es-Tee-Why
    [4866] = true,   -- Mother's Milk
    [4867] = false,  -- Urok Doomhowl
    [5089] = false,  -- General Drakkisath's Command
    [4788] = true,   -- The Final Tablets
    [5065] = true,   -- The Lost Tablets of Mosh'aru
    -- Upper Blackrock Spire
    [4743] = false,  -- Seal of Ascension
    [7761] = false,  -- Blackhand's Command
    [4735] = false,  -- Egg Collection
    [4726] = false,  -- Broodling Essence
    [4808] = false,  -- Felnok Steelspring
    [4809] = true,   -- Chillwind Horns
    [4810] = false,  -- Return to Tinkee
    [4907] = true,   -- Tinkee Steamboil
    [5102] = true,   -- General Drakkisath's Demise
    [4974] = true,   -- For The Horde!
    [4941] = true,   -- Eitrigg's Wisdom
    [6569] = true,   -- Oculus Illusions
    [6566] = true,   -- What the Wind Carries
    [6567] = true,   -- The Champion of the Horde
    [6568] = false,  -- The Testament of Rexxar
    [6502] = true,   -- Drakefire Amulet
    [6402] = true,   -- Stormwind Rendezvous
    [6501] = false,  -- The Dragon's Eye
    [6602] = true,   -- Blood of the Black Dragon Champion
    [6570] = false,  -- Emberstrife
    [6582] = true,   -- The Test of Skulls, Scryer
    [6583] = true,   -- The Test of Skulls, Somnus
    [6584] = true,   -- The Test of Skulls, Chronalis
    [6585] = true,   -- The Test of Skulls, Axtroz
    [6601] = false,  -- Ascension...
    [5127] = false,  -- The Demon Forge
    [4766] = true,   -- Mayara Brightwing
    [4764] = true,   -- Doomrigger's Clasp
    [4769] = true,   -- Vivian Lagrave and the Darkstone Tablet
    [4768] = true,   -- The Darkstone Tablet
    [5047] = false,  -- Finkle Einhorn, At Your Service!
    [5160] = false,  -- The Matron Protectorate
    [4734] = false,  -- Egg Freezing
    [6403] = false,  -- The Great Masquerade
    -- Dire Maul: East
    [7441] = true,   -- Pusillin and the Elder Azj'Tordin
    [7494] = true,   -- Feathermoon Stronghold
    [7488] = true,   -- Lethtendris's Web
    [7492] = true,   -- Camp Mojache
    [7489] = true,   -- Lethtendris's Web
    [5526] = false,  -- Shards of the Felvine
    [5527] = true,   -- A Reliquary of Purity
    [7463] = true,   -- Arcane Refreshment
    -- Dire Maul: West
    [7461] = true,   -- The Madness Within
    [7481] = true,   -- Elven Legends
    [7482] = true,   -- Elven Legends
    [5250] = true,   -- Starfall
    [5247] = false,  -- Fragments of the Past
    [5244] = true,   -- The Ruins of Kel'Theril
    [5245] = false,  -- Troubled Spirits of Kel'Theril
    [5246] = true,   -- Fragments of the Past
    [7643] = false,  -- Ancient Equine Spirit
    [7637] = false,  -- Emphasis on Sacrifice
    [7639] = false,  -- To Show Due Judgment
    [7640] = false,  -- Exorcising Terrordale
    [7641] = false,  -- The Work of Grimand Elmore
    [7642] = false,  -- Collection of Goods
    [7648] = false,  -- Grimand's Finest Work
    [7645] = false,  -- Manna-Enriched Horse Feed
    [7703] = false,  -- Unfinished Gordok Business
    [7631] = false,  -- Dreadsteed of Xoroth
    [7563] = true,   -- Rage of Blood
    [7564] = false,  -- Wildeyes
    [7623] = false,  -- Lord Banehollow
    [7624] = false,  -- Ulathek the Traitor
    [7625] = false,  -- Xorothian Stardust
    [7626] = false,  -- Bell of Dethmoora
    [7627] = false,  -- Wheel of the Black March
    [7628] = false,  -- Doomsday Candle
    [7629] = false,  -- Imp Delivery
    [7630] = false,  -- Arcanite
    -- Dire Maul: North
    [5525] = true,   -- Free Knot!
    [5518] = true,   -- The Gordok Ogre Suit
    [7506] = false,  -- The Emerald Dream...
    [7503] = false,  -- The Greatest Race of Hunters
    [7500] = false,  -- The Arcanist's Cookbook
    [7501] = false,  -- The Light and How To Swing It
    [7504] = false,  -- Holy Bologna: What the Light Won't Tell You
    [7498] = false,  -- Garona: A Study on Stealth and Treachery
    [7505] = false,  -- Frost Shock and You
    [7502] = false,  -- Harnessing Shadows
    [7499] = false,  -- Codex of Defense
    [7507] = false,  -- Foror's Compendium
    [7483] = true,   -- Libram of Rapidity
    [7484] = true,   -- Libram of Focus
    [7485] = true,   -- Libram of Protection
    -- Scholomance
    [5384] = false,  -- Kirtonos the Herald
    [5382] = true,   -- Doctor Theolen Krastinov, the Butcher
    [5515] = true,   -- Krastinov's Bag of Horrors
    [5466] = false,  -- The Lich, Ras Frostwhisper
    [5461] = true,   -- The Human, Ras Frostwhisper
    [5462] = false,  -- The Dying, Ras Frostwhisper
    [5463] = false,  -- Menethil's Gift
    [5464] = false,  -- Menethil's Gift
    [5465] = false,  -- Soulbound Keepsake
    [5343] = true,   -- Barov Family Fortune
    [5341] = true,   -- Barov Family Fortune
    [5522] = false,  -- Leonid Barthalomew
    [5531] = false,  -- Betina Bigglezink
    [5529] = true,   -- Plagued Hatchlings
    [7647] = false,  -- Judgment and Redemption
    [7644] = false,  -- Blessed Arcanite Barding
    [7646] = false,  -- The Divination Scryer
    [7668] = false,  -- The Darkreaver Menace (legacy / alternate record)
    [7667] = false,  -- Material Assistance
    [4771] = false,  -- Dawn's Gambit
    -- Stratholme: Living
    [5251] = true,   -- The Archivist
    [5262] = false,  -- The Truth Comes Crashing Down
    [5212] = true,   -- The Flesh Does Not Lie
    [5243] = true,   -- Houses of the Holy
    [5214] = true,   -- The Great Fras Siabi
    [5848] = true,   -- Of Love and Family
    [5742] = true,   -- Redemption
    [5781] = true,   -- Of Forgotten Memories
    [5845] = true,   -- Of Lost Honor
    [5846] = true,   -- Of Love and Family
    [5122] = true,   -- The Medallion of Faith
    [5281] = true,   -- The Restless Souls
    [5282] = false,  -- The Restless Souls
    -- Stratholme: Undead
    [5263] = true,   -- Above and Beyond
    [5213] = true,   -- The Active Agent
    [6163] = true,   -- Ramstein
    [6133] = true,   -- The Ranger Lord's Behest
    [6042] = true,   -- Un-Life's Little Annoyances
    [6022] = false,  -- To Kill With Purpose
    [6135] = true,   -- Duskwing, Oh How I Hate Thee...
    [6136] = true,   -- The Corpulent One
    [5125] = true,   -- Aurius' Reckoning
    [8945] = true,   -- Dead Man's Plea
    -- Zul'Farrak (sharing index)
    [2769] = true,   -- The Brassbolts Brothers
    [2770] = true,   -- Gahz'rilla
    [2861] = true,   -- Tabetha's Task
    [2846] = true,   -- Tiara of the Deep
    [2768] = true,   -- Divino-matic Rod
    [2864] = true,   -- Tran'rek
    [2865] = true,   -- Scarab Shells
    [3042] = true,   -- Troll Temper
    [2991] = true,   -- Nekrum's Medallion
    [2988] = true,   -- Witherbark Cages
    [2989] = true,   -- The Altar of Zul
    [2990] = false,  -- Thadius Grimshade
    [2936] = true,   -- The Spider God
    [2933] = false,  -- Venom Bottles
    [2934] = true,   -- Undamaged Venom Sac
    [2935] = true,   -- Consult Master Gadrin
}
