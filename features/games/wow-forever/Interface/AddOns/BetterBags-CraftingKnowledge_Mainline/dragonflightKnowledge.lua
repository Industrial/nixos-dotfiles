local addonName, addon = ...

local DF_Knowledge = {
    --#Alchemy
    193891, -- Experimental Substance
    193897, -- Reawakened Catalyst
    198599, -- Experimental Decay Sample
    198608, -- Alchemy Notes
    198663, -- Frostforged Potion
    198685, -- Well Insulated Mug
    198697, -- Contraband Concoction
    198710, -- Canteen of Suspicious Water
    198712, -- Firewater Powder Sample
    198963, -- Decaying Phlegm
    198964, -- Elementious Splinter
    201003, -- Furry Gloop
    200974, -- Dusty Alchemist's Research
    201270, -- Rare Alchemist's Research
    201281, -- Ancient Alchemist's Research
    201706, -- Notebook of Crafting Knowledge (Alchemy)
    203471, -- Tasty Candy
    204226, -- Blazehoof Ashes
    205211, -- Nutrient Diluted Protofluid
    205212, -- Marrow-Ripened Slime
    205213, -- Suspicious Mold
    205353, -- Niffen Notebook of Alchemy Knowledge
    205429, -- Bartered Alchemy Notes
    205440, -- Bartered Alchemy Journal
    --#Blacksmithing
    192131, -- Valdrakken Weapon Chain
    192132, -- Draconium Blade Sharpener
    198606, -- Blacksmith's Writ
    198791, -- Glimmer of Blacksmithing Wisdom
    198965, -- Primeval Earth Fragment
    198966, -- Molten Globule
    201004, -- Ancient Spear Shards
    201005, -- Curious Ingots
    201006, -- Draconic Flux
    201007, -- Ancient Monument
    201008, -- Molten Ingot
    201009, -- Falconer Gauntlet Drawings
    201010, -- Qalashi Weapon Diagram
    201011, -- Spelltouched Tongs
    200972, -- Dusty Blacksmith's Diagrams
    201268, -- Rare Blacksmith's Diagrams
    201279, -- Ancient Blacksmith's Diagrams
    201708, -- Notebook of Crafting Knowledge (Blacksmithing)
    204230, -- Dense Seaforged Javelin
    205352, -- Niffen Notebook of Blacksmithing Knowledge
    205986, -- Well-Worn Kiln
    205987, -- Brimstone Rescue Ring
    205988, -- Zaqali Elder Spear
    205428, -- Bartered Blacksmithing Notes
    205439, -- Bartered Blacksmithing Journal
    --#Enchanting
    193900, -- Prismatic Focusing Shard
    198610, -- Enchanter's Script
    198675, -- Lava-Infused Seed
    198689, -- Stormbound Horn
    198694, -- Enriched Earthen Shard
    198967, -- Primordial Aether
    198968, -- Primalist Charm
    198798, -- Flashfrozen Scroll
    198799, -- Forgotten Arcane Tome
    198800, -- Fractured Titanic Sphere
    201012, -- Enchanted Debris
    201013, -- Faintly Enchanted Remains
    200976, -- Dusty Enchanter's Research
    201272, -- Rare Enchanter's Research
    201283, -- Ancient Enchanter's Research
    201356, -- Glimmer of Fire
    201357, -- Glimmer of Frost
    201358, -- Glimmer of Air
    201359, -- Glimmer of Earth
    201360, -- Glimmer of Order
    201709, -- Notebook of Crafting Knowledge (Enchanting)
    204224, -- Speck of Arcane Awareness
    204990, -- Lava-Drenched Shadow Crystal
    204999, -- Shimmering Aqueous Orb
    205001, -- Resonating Arcane Crystal
    205351, -- Niffen Notebook of Enchanting Knowledge
    205427, -- Bartered Enchanting Notes
    205438, -- Bartered Enchanting Journal
    --#Engineering
    193902, -- Eroded Titan Gizmo
    193903, -- Watcher Power Core
    198611, -- Engineering Details
    198789, -- Intact Coil Capacitor
    198611, -- Engineering Details
    198969, -- Keeper's Mark
    198970, -- Infinitely Attachable Pair o' Docks
    201014, -- Boomthyr Rocket
    200977, -- Dusty Engineer's Scribblings
    201273, -- Rare Engineer's Scribblings
    201284, -- Ancient Engineer's Scribblings
    201710, -- Notebook of Crafting Knowledge (Engineering)
    204227, -- Everflowing Antifreeze
    204469, -- Misplaced Aberrus Outflow Blueprints
    204470, -- Haphazardly Discarded Bomb
    204471, -- Defective Survival Pack
    204475, -- Busted Wyrmhole Generator
    204480, -- Inconspicuous Data Miner
    204850, -- Handful of Khaz'gorite Bolts
    204853, -- Discarded Dracothyst Drill
    204855, -- Overclocked Determination Core
    205349, -- Niffen Notebook of Engineering Knowledge
    205425, -- Bartered Engineering Notes
    205436, -- Bartered Engineering Journal
    --#Herbalism
    194041, -- Driftbloom Sprout
    194054, -- Dredged Seedling
    194055, -- Primordial Soil
    194061, -- Suffocating Spores
    194080, -- Peculiar Bud
    194081, -- Mutated Root
    199115, -- Herbalism Field Notes
    200677, -- Dreambloom Petal
    200678, -- Dreambloom
    200980, -- Dusty Herbalist's Notes
    201276, -- Rare Herbalist's Notes
    201287, -- Ancient Herbalist's Notes
    201705, -- Notebook of Crafting Knowledge (Herbalism)
    201717, -- Notebook of Crafting Knowledge (Herbalism)
    202014, -- Infused Pollen
    204228, -- Undigested Hochenblume Petal
    205358, -- Niffen Notebook of Herbalism Knowledge
    205434, -- Bartered Herbalism Notes
    205445, -- Bartered Herbalism Journal
    --#Inscription
    193904, -- Phoenix Feather Quill
    193905, -- Iskaaran Trading Ledger
    198607, -- Scribe's Glyphs
    198659, -- Forgetful Apprentice's Tome
    198669, -- How to Train Your Whelpling
    198686, -- Frosted Parchment
    198693, -- Dusty Darkmoon Card
    198703, -- Sign Language Reference Sheet
    198704, -- -lsing Earth Rune
    198971, -- Curious Djaradin Rune
    198972, -- Draconic Glamour
    201015, -- Counterfeit Darkmoon Deck
    200973, -- Dusty Scribe's Runic Drawings
    201269, -- Rare Scribe's Runic Drawings
    201280, -- Ancient Scribe's Runic Drawings
    201711, -- Notebook of Crafting Knowledge (Inscriptioin)
    204229, -- Glimmering Rune of Arcantrix
    205354, -- Niffen Notebook of Inscription Knowledge
    205430, -- Bartered Inscription Notes
    205441, -- Bartered Inscription Journal
    206031, -- Intricate Zaqali Runes
    206034, -- Hissing Rune Draft
    206035, -- Ancient Research
    --#Jewelcrafting
    193907, -- Chipped Tyrstone
    193909, -- Ancient Gem Fragments
    198656, -- Painter's Pretty Jewel
    198660, -- Fragmented Key
    198612, -- Jeweler's Cuts
    198664, -- Crystalline Overgrowth
    198670, -- Lofty Malygite
    198682, -- Alexstraszite Cluster
    198687, -- Closely Guarded Shiny
    198974, -- Elegantly Engraved Embellishment
    201016, -- Harmonic Crystal Harmonizer
    201017, -- Igneous Gem
    200978, -- Dusty Jeweler's Illustrations
    201274, -- Rare Jeweler's Illustrations
    201285, -- Ancient Jeweler's Illustrations
    201712, -- Notebook of Crafting Knowledge (Jewelcrafting)
    204222, -- Conductive Ametrine Shard
    205214, -- Snubbed Snail Shells
    205216, -- Gently Jostled Jewels
    205219, -- Broken Barter Boulder
    205348, -- Niffen Notebook of Jewelcrafting Knowledge
    205424, -- Bartered Jewelcrafting Notes
    205435, -- Bartered Jewelcrafting Journal
    --#Leatherworking
    193910, -- Molted Dragon Scales
    193913, -- Preserved Animal Parts
    198613, -- Leatherworking Designs
    198658, -- Decay-Infused Tanning Oil
    198667, -- Spare Djaradin Tools
    198690, -- Decayed Scales
    198696, -- Wind-Blessed Hide
    198683, -- Treated Hides
    198711, -- Poacher's Pack
    198975, -- Ossified Hide
    198976, -- Exceedingly Soft Skin
    201018, -- Well-Danced Drum
    200979, -- Dusty Leatherworker's Diagrams
    201275, -- Rare Leatherworker's Diagrams
    201286, -- Ancient Leatherworker's Diagrams
    201713, -- Notebook of Crafting Knowledge (Leatherworking)
    204232, -- Slyvern Alpha Claw
    204986, -- Flame-Infused Scale Oil
    204987, -- Lava-Forged Leatherworker's "Knife"
    204988, -- Sulfur-Soaked Skins
    205350, -- Niffen Notebook of Leatherworking Knowledge
    205426, -- Bartered Leatherworking Notes
    205437, -- Bartered Leatherworking Journal
    --#Mining
    194039, -- Heated Ore Sample
    194062, -- Unyielding Stone Chunk
    194063, -- Glowing Fragment
    194064, -- Intricate Geode
    194078, -- Perfect Draconium Scale
    194079, -- Pure Serevite Nugget
    199122, -- Mining Field Notes
    200981, -- Dusty Miner's Notes
    201277, -- Rare Miner's Notes
    201288, -- Ancient Miner's Notes
    201300, -- Iridescent Ore Fragments
    201301, -- Iridescent Ore
    201700, -- Notebook of Crafting Knowledge (Mining)
    201716, -- Notebook of Crafting Knowledge (Mining)
    202011, -- Elementally-Charged Stone
    204233, -- Impenetrable Elemental Core
    204632, -- Tectonic Rock Fragment
    205356, -- Niffen Notebook of Mining Knowledge
    205432, -- Bartered Mining Notes
    205443, -- Bartered Mining Journal
    --#Skinning
    198837, -- Curious Hide Scraps
    198841, -- Large Sample of Curious Hide
    199128, -- Skinning Field Notes
    200982, -- Dusty Skinner's Notes
    201278, -- Rare Skinner's Notes
    201289, -- Ancient Skinner's Notes
    201714, -- Notebook of Crafting Knowledge (Skinning)
    201718, -- Notebook of Crafting Knowledge (Skinning)
    202016, -- Saturated Bone
    204231, -- Kingly Sheepskin Pelt
    205357, -- Niffen Notebook of Skinning Knowledge
    205443, -- Bartered Skinning Notes
    205444, -- Bartered Skinning Journal
    --#Tailoring
    193898, -- Umbral Bone Needle
    193899, -- Primalweave Spindle
    198609, -- Tailoring Examples
    198662, -- Intriguing Bolt of Blue Cloth
    198680, -- Decaying Brackenhide Blanket
    198684, -- Miniature Bronze Dragonflight Banner
    198692, -- Noteworthy Scrap of Carpet
    198699, -- Mysterious Banner
    198702, -- Itinerant Singed Fabric
    198977, -- Ohn'arhan Weave
    198978, -- Stupidly Effective Stitchery
    201019, -- Ancient Dragonweave Bolt
    201020, -- Silky Surprise
    200975, -- Dusty Tailor's Diagrams
    201271, -- Rare Tailor's Diagrams
    201282, -- Ancient Tailor's Diagrams
    201715, -- Notebook of Crafting Knowledge (Tailoring)
    204225, -- Perfect Windfeather
    205355, -- Niffen Notebook of Tailoring Knowledge
    205431, -- Bartered Tailoring Notes
    205442, -- Bartered Tailoring Journal
    206019, -- Abandoned Reserve Chute
    206025, -- Used Medical Wrap Kit
    206030, -- Exquisitely Embroidered Banner
    --#Treatise
    198454, -- Draconic Treatise on Blacksmithing
    194697, -- Draconic Treatise on Alchemy
    194698, -- Draconic Treatise on Tailoring
    194699, -- Draconic Treatise on Inscription
    194700, -- Draconic Treatise on Leatherworking
    194702, -- Draconic Treatise on Enchanting
    194703, -- Draconic Treatise on Jewelcrafting
    194704, -- Draconic Treatise on Herbalism
    194708, -- Draconic Treatise on Mining
    198510, -- Draconic Treatise on Engineering
    201023, -- Draconic Treatise on Skinning
    --#Misc
    191784, -- Dragon Shard of Knowledge
}

addon.DF_Knowledge = DF_Knowledge
