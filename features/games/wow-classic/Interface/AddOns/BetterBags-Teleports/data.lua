---@type string, AddonNS
local _, addon = ...

addon.data = {}

local function isNotRetail()
    return not addon.data.isRetail
end

addon.data.enablePortalReagents = {
    {17031}, -- Rune of Teleportation
    {17032}, -- Rune of Portals
}

addon.data.classic = {
    {6948}, -- Hearthstone
    {17690}, -- Frostwolf Insignia Rank 1
    {17691}, -- Stormpike Insignia Rank 1
    {17900}, -- Stormpike Insignia Rank 2
    {17901}, -- Stormpike Insignia Rank 3
    {17902}, -- Stormpike Insignia Rank 4
    {17903}, -- Stormpike Insignia Rank 5
    {17904}, -- Stormpike Insignia Rank 6
    {17905}, -- Frostwolf Insignia Rank 2
    {17906}, -- Frostwolf Insignia Rank 3
    {17907}, -- Frostwolf Insignia Rank 4
    {17908}, -- Frostwolf Insignia Rank 5
    {17909}, -- Frostwolf Insignia Rank 6
    {18149}, -- Rune of Recall (Frostwolf Keep)
    {18150}, -- Rune of Recall (Dun Baldar)
    {18984}, -- Dimensional Ripper - Everlook
    {18986}, -- Ultrasafe Transporter - Gadgetzan
    {22589}, -- Atiesh, Greatstaff of the Guardian (Mage)
    {22630}, -- Atiesh, Greatstaff of the Guardian (Warlock)
    {22631}, -- Atiesh, Greatstaff of the Guardian (Priest)
    {22632}, -- Atiesh, Greatstaff of the Guardian (Druid)
}

addon.data.tbc = {
    {28585}, -- Ruby Slippers
    {29796}, -- Socrethar's Teleportation Stone
    {30542}, -- Dimensional Ripper - Area 52
    {30544}, -- Ultrasafe Transporter - Toshley's Station
    {32757}, -- Blessed Medallion of Karabor
    {35230}, -- Darnarian's Scroll of Teleportation
    {37118}, -- Scroll of Recall
    {37863}, -- Direbrew's Remote
    {184871, condition = isNotRetail}, -- Dark Portal (TBC)
}

addon.data.wotlk = {
    {40585}, -- Signet of the Kirin Tor
    {40586}, -- Band of the Kirin Tor
    {43824}, -- The Schools of Arcane Magic - Mastery (spires atop the Violet Citadel)
    {44314}, -- Scroll of Recall II
    {44315}, -- Scroll of Recall III
    {44934}, -- Loop of the Kirin Tor
    {44935}, -- Ring of the Kirin Tor
    {45688}, -- Inscribed Band of the Kirin Tor
    {45689}, -- Inscribed Loop of the Kirin Tor
    {45690}, -- Inscribed Ring of the Kirin Tor
    {45691}, -- Inscribed Signet of the Kirin Tor
    {46874}, -- Argent Crusader's Tabard
    {48933}, -- Wormhole Generator: Northrend
    {48954}, -- Etched Band of the Kirin Tor
    {48955}, -- Etched Loop of the Kirin Tor
    {48956}, -- Etched Ring of the Kirin Tor
    {48957}, -- Etched Signet of the Kirin Tor
    {50287}, -- Boots of the Bay
    {51557}, -- Runed Signet of the Kirin Tor
    {51558}, -- Runed Loop of the Kirin Tor
    {51559}, -- Runed Ring of the Kirin Tor
    {51560}, -- Runed Band of the Kirin Tor
    {52251}, -- Jaina's Locket
    {54452}, -- Ethereal Portal
    {199335, condition = isNotRetail}, -- Teleport Scroll: Menethil Harbor
    {199336, condition = isNotRetail}, -- Teleport Scroll: Stormwind Harbor
    {199777, condition = isNotRetail}, -- Teleport Scroll: Orgrimmar Zepplin Tower
    {199778, condition = isNotRetail}, -- Teleport Scroll: Undercity Zepplin Tower
    {200068, condition = isNotRetail}, -- Teleport Scroll: Shattrath City
}

addon.data.cata = {
    {58487}, -- Potion of Deepholm
    {61379}, -- Gidwin's Hearthstone
    {63206}, -- Wrap of Unity: Stormwind
    {63207}, -- Wrap of Unity: Orgrimmar
    {63352}, -- Shroud of Cooperation: Stormwind
    {63353}, -- Shroud of Cooperation: Orgrimmar
    {63378}, -- Hellscream's Reach Tabard
    {63379}, -- Baradin's Wardens Tabard
    {64457}, -- The Last Relic of Argus
    {64488}, -- The Innkeeper's Daughter
    {65274}, -- Cloak of Coordination: Orgrimmar
    {65360}, -- Cloak of Coordination: Stormwind
    {68808}, -- Hero's Hearthstone
    {68809}, -- Veteran's Hearthstone
}

addon.data.mists = {
    {87215}, -- Wormhole Generator: Pandaria
    {87548}, -- Lorewalker's Lodestone
    {92510}, -- Vol'jin's Hearthstone
    {93672}, -- Dark Portal (MoP)
    {95050}, -- The Brassiest Knuckle (Brawl'gar Arena)
    {95051}, -- The Brassiest Knuckle (Bizmo's Brawlpub)
    {95567}, -- Kirin Tor Beacon
    {95568}, -- Sunreaver Beacon
    {103678}, -- Time-Lost Artifact
}

addon.data.wod = {
    {110560}, -- Garrison Hearthstone
    {112059}, -- Wormhole Centrifuge
    {117389}, -- Draenor Archaeologist's Lodestone
    {118662}, -- Bladespire Relic
    {118663}, -- Relic of Karabor
    {118907}, -- Pit Fighter's Punching Ring (Bizmo's Brawlpub)
    {118908}, -- Pit Fighter's Punching Ring (Brawl'gar Arena)
    {119183}, -- Scroll of Risky Recall
    {128502}, -- Hunter's Seeking Crystal
    {128503}, -- Master Hunter's Seeking Crystal
    {128353}, -- Admiral's Compass
}

addon.data.legion = {
    {129276}, -- Beginner's Guide to Dimensional Rifting
    {132119}, -- Orgrimmar Portal Stone
    {132120}, -- Stormwind Portal Stone
    {132517}, -- Intra-Dalaran Wormhole Generator
    {132523}, -- Reaves Battery
    {132524}, -- Reaves Module: Wormhole Generator Mode
    {138448}, -- Emblem of Margoss
    {139590}, -- Scroll of Teleport: Ravenholdt
    {139599}, -- Empowered Ring of the Kirin Tor
    {140192}, -- Dalaran Hearthstone
    {140493}, -- Adept's Guide to Dimensional Rifting
    {141013}, -- Scroll of Town Portal: Shala'nir
    {141014}, -- Scroll of Town Portal: Sashj'tar
    {141015}, -- Scroll of Town Portal: Kal'delar
    {141016}, -- Scroll of Town Portal: Faronaar
    {141017}, -- Scroll of Town Portal: Lian'tril
    {141324}, -- Talisman of the Shal'dorei
    {141605}, -- Flight Master's Whistle
    {142298}, -- Astonishingly Scarlet Slippers
    {142469}, -- Violet Seal of the Grand Magus
    {142542}, -- Tome of Town Portal (Diablo 3 event)
    {142543}, -- Scroll of Town Portal (Diablo 3 event)
    {144341}, -- Rechargeable Reaves Battery
    {144391}, -- Pugilist's Powerful Punching Ring (Alliance)
    {144392}, -- Pugilist's Powerful Punching Ring (Horde)
    {150733}, -- Scroll of Town Portal (Ar'gorok in Arathi)
    {151652}, -- Wormhole Generator: Argus
}

addon.data.bfa = {
    {159224}, -- Zuldazar Hearthstone
    {160219}, -- Scroll of Town Portal (Stromgarde in Arathi)
    {162973}, -- Greatfather Winter's Hearthstone
    {163045}, -- Headless Horseman's Hearthstone
    {163694}, -- Scroll of Luxurious Recall
    {166559}, -- Commander's Signet of Battle
    {166560}, -- Captain's Signet of Command
    {165669}, -- Lunar Elder's Hearthstone
    {165670}, -- Peddlefeet's Lovely Hearthstone
    {165802}, -- Noble Gardener's Hearthstone
    {166746}, -- Fire Eater's Hearthstone
    {166747}, -- Brewfest Reveler's Hearthstone
    {167075}, -- Ultrasafe Transporter: Mechagon
    {168807}, -- Wormhole Generator: Kul Tiras
    {168808}, -- Wormhole Generator: Zandalar
    {168862}, -- G.E.A.R. Tracking Beacon
    {168907}, -- Holographic Digitalization Hearthstone
    {169064}, -- Montebank's Colorful Cloak
    {169297}, -- Stormpike Insignia
    {169862}, -- Alluring Bloom
}

addon.data.sl = {
    {172179}, -- Eternal Traveler's Hearthstone
    {172203}, -- Cracked Hearthstone
    {172924}, -- Wormhole Generator: Shadowlands
    {173373}, -- Faol's Hearthstone
    {173430}, -- Nexus Teleport Scroll
    {173523}, -- Tirisfal Camp Scroll
    {173526}, -- Caer Darrow Scroll
    {173527}, -- Duskwood Scroll
    {173528}, -- Gilded Hearthstone
    {173530}, -- Duskwood Scroll
    {173531}, -- Blasted Lands Scroll
    {173532}, -- Elwynn Forest Scroll
    {173537}, -- Glowing Hearthstone
    {173716}, -- Mossy Hearthstone
    {180290}, -- Night Fae Hearthstone
    {180817}, -- Cypher of Relocation (Ve'nari's Refuge)
    {181163}, -- Scroll of Teleport: Theater of Pain
    {182773}, -- Necrolord's Hearthstone
    {183716}, -- Venthyr Sinstone
    {184353}, -- Kyrian Hearthstone
    {184500}, -- Attendant's Pocket Portal: Bastion
    {184501}, -- Attendant's Pocket Portal: Revendreth
    {184502}, -- Attendant's Pocket Portal: Maldraxxus
    {184503}, -- Attendant's Pocket Portal: Ardenweald
    {184504}, -- Attendant's Pocket Portal: Oribos
    {188952}, -- Dominated Hearthstone
    {189827}, -- Cartel Xy's Proof of Initiation
    {190196}, -- Enlightened Hearthstone
    {190234}, -- Enlightened Portal Research
    {190237}, -- Broker Translocation Matrix
    {191029}, -- Lilian's Hearthstone
}

addon.data.df = {
    {193000}, -- Ring-Bound Hourglass
    {193588}, -- Timewalker's Hearthstone
    {198156}, -- Wyrmhole Generator: Dragon Isles
    {200613}, -- Aylaag Windstone Fragment
    {200630}, -- Ohn'ir Windsage's Hearthstone
    {201957}, -- Thrall's Hearthstone
    {202046}, -- Lucky Tortollan Charm
    {204481}, -- Morqut Hearth Totem
    {204802}, -- Scroll of Teleport: Zskera Vaults
    {205255}, -- Niffen Diggin' Mitts
    {205456}, -- Lost Dragonscale (1)
    {205458}, -- Lost Dragonscale (2)
    {206195}, -- Path of the Naaru
    {209035}, -- Hearthstone of the Flame
    {210455}, -- Draenic Hologem
    {211788}, -- Tess's Peacebloom
    {212337}, -- Stone of the Hearth
    {217930}, -- Nostwin's Voucher (Remix)
    {219222}, -- Time-Lost Artifact (Remix)
}

addon.data.tww = {
    {208704}, -- Deepdweller's Earthen Hearthstone
    {221965}, -- Prototype: Wormhole Generator: Khaz Algar
    {221966}, -- Wormhole Generator: Khaz Algar
    {223988}, -- Dalaran Hearthstone (Quest Item)
    {228940}, -- Notorious Thread's Hearthstone
    {228996}, -- Relic of Crystal Connections
    {235016}, -- Redeployment Module
    {230850}, -- Delve-O-Bot 7001
    {235037}, -- Crumpled Schematic: Wormhole Generator: Undermine
    {236687}, -- Explosive Hearthstone
    {234389}, -- Gallagio Loyalty Rewards Card: Silver
    {234390}, -- Gallagio Loyalty Rewards Card: Gold
    {234391}, -- Gallagio Loyalty Rewards Card: Platinum
    {234392}, -- Gallagio Loyalty Rewards Card: Black
    {234393}, -- Gallagio Loyalty Rewards Card: Diamond
    {234394}, -- Gallagio Loyalty Rewards Card: Legendary
    {238727}, -- Nostwin's Voucher (Lemix)
    {243056}, -- Delver's Mana-Bound Ethergate
    {245970}, -- P.O.S.T. Master's Express Hearthstone
    {246565}, -- Cosmic Hearthstone
    {249699}, -- Shadowguard Translocator
    {249229}, -- Black Temple Scroll (Lemix)
    {249230}, -- Temple of Zin-Malor (Lemix)
    {250411}, -- Timerunner's Hearthstone (Lemix)
}

addon.data.midnight = {
    {238379}, -- Warping Wise
    {239151}, -- Light's Summon
    {248131}, -- Key to the Arcantina
    {248485}, -- Wormhole Generator: Quel'thalas
    {252607}, -- Abundant Beacon
    {253629}, -- Personal Key to the Arcantina
    {257736}, -- Lightcalled Hearthstone
    {258736}, -- Scroll of Town Portal
    {263933}, -- Preyseeker's Hearthstone
    {265100}, -- Corewarden's Hearthstone
}

addon.data.patchContent = {}