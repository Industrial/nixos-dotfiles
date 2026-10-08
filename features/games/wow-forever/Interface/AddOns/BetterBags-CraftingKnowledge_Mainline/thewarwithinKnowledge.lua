local addonName, addon = ...

local TWW_Knowledge = {
    -- #Alchemy
    226265, -- Earthen Iron Powder
    226266, -- Metal Dornogal Frame
    226268, -- Engraved Stirring Rod
    226267, -- Reinforced Beaker
    226269, -- Chemist's Purified Water
    226270, -- Sanctified Mortar and Pestle
    226272, -- Dark Apothecary's Vial
    226271, -- Nerubian Mixing Salts
    224024, -- Theories of Bodily Transmutation, Chapter 8
    222546, -- Algari Treatise on Alchemy
    225235, -- Deepstone Crucible
    228773, -- Algari Alchemist's Notebook
    227409, -- Faded Alchemist's Research
    224645, -- Jewel-Etched Alchemy Notes
    228725, -- Glimmer of Alchemy Knowledge
    235865, -- Ethereal Tome of Alchemy Knowledge
    232499, -- Undermine Treatise on Alchemy
    228724, -- Flicker of Alchemy Knowledge
    225234, -- Alchemical Sediment
    -- #Blacksmithing
    226277, -- Dornogal Hammer
    226276, -- Ancient Earthen Anvil
    226279, -- Earthen Chisels
    226278, -- Ringing Hammer Vise
    226281, -- Radiant Tongs
    226280, -- Holy Flame Forge
    226283, -- Spiderling's Wire Brush
    226282, -- Nerubian Smith's Kit
    224038, -- Smithing After Saronite
    225233, -- Dense Bladestone
    224038, -- Smithing After Saronite
    222554, -- Algari Treatise on Blacksmithing
    228727, -- Glimmer of Blacksmithing Knowledge
    198791, -- Glimmer of Blacksmithing Wisdom
    228774, -- Algari Blacksmith's Journal
    224647, -- Jewel-Etched Blacksmithing Notes
    225232, -- Coreway Billet
    227407, -- Faded Blacksmith's Diagrams
    227418, -- Exceptional Blacksmith's Diagrams
    228726, -- Flicker of Blacksmithing Knowledge
    235864, -- Ethereal Tome of Blacksmithing Knowledge
    232500, -- Undermine Treatise on Blacksmithing
    -- #Enchanting
    226285, -- Silver Dornogal Rod
    226284, -- Grinded Earthen Gem
    226287, -- Animated Enchanting Dust
    226286, -- Soot-Coated Orb
    226289, -- Enchanted Arathi Scroll
    226288, -- Essence of Holy Fire
    226291, -- Void Shard
    226290, -- Book of Dark Magic
    224050, -- Web Sparkles: Pretty and Powerful
    225230, -- Crystalline Repository
    227667, -- Algari Enchanter's Folio
    225231, -- Powdered Fulgurance
    224652, -- Jewel-Etched Enchanting Notes
    227659, -- Fleeting Arcane Manifestation
    222550, -- Algari Treatise on Enchanting
    228729, -- Glimmer of Enchanting Knowledge
    235863, -- Ethereal Tome of Enchanting Knowledge
    232501, -- Undermine Treatise on Enchanting
    -- #Engineering
    226293, -- Dornogal Spectacles
    226292, -- Rock Engineer's Wrench
    226295, -- Earthen Construct Blueprints
    226294, -- Inert Mining Bomb
    226297, -- Arathi Safety Gloves
    226296, -- Holy Firework Dud
    226298, -- Puppated Mechanical Spider
    226299, -- Emptied Venom Canister
    224052, -- Clocks, Gears, Sprockets, and Legs
    227412, -- Faded Engineer's Scribblings
    224653, -- Machine-Learned Engineering Notes
    228731, -- Glimmer of Engineering Knowledge
    235862, -- Ethereal Tome of Engineering Knowledge
    232507, -- Undermine Treatise on Engineering
    -- #Herbalism
    226301, -- Dornogal Gardening Scythe
    226300, -- Ancient Flower
    226303, -- Fungarian Slicer's Knife
    226302, -- Earthen Digging Fork
    226304, -- Arathi Garden Trowel
    226305, -- Arathi Herb Pruner
    226307, -- Tunneler's Shovel
    226306, -- Web-Entangled Lotus
    224023, -- Herbal Embalming Techniques
    222552, -- Algari Treatise on Herbalism
    224835, -- Deepgrove Roots
    224264, -- Deepgrove Petal
    227415, -- Faded Herbalist's Notes
    224656, -- Void-Lit Herbalism Notes
    224817, -- Algari Herbalist's Notes
    224265, -- Deepgrove Rose
    227426, -- Exceptional Herbalist's Notes
    235861, -- Ethereal Tome of Herbalism Knowledge
    232503, -- Undermine Treatise on Herbalism
    -- #Inscription
    226308, -- Dornogal Scribe's Quill
    226309, -- Historian's Dip Pen
    226311, -- Blue Earthen Pigment
    226310, -- Runic Scroll
    226313, -- Calligrapher's Chiseled Marker
    226312, -- Informant's Fountain Pen
    226314, -- Nerubian Texts
    226315, -- Venomancer's Ink Well
    222548, -- Algari Treatise on Inscription
    225227, -- Wax-Sealed Records
    224053, -- Eight Views on Defense against Hostile Runes
    228733, -- Glimmer of Inscription Knowledge
    235860, -- Ethereal Tome of Inscription Knowledge
    232508, -- Undermine Treatise on Inscription
    -- #Jewelcrafting
    226317, -- Earthen Gem Pliers
    226316, -- Gentle Jewel Hammer
    226319, -- Jeweler's Delicate Drill
    226318, -- Carved Stone File
    226321, -- Librarian's Magnifiers
    226320, -- Arathi Sizing Gauges
    226323, -- Nerubian Bench Blocks
    226322, -- Ritual Caster's Crystal
    227413, -- Faded Jeweler's Illustrations
    225225, -- Deepstone Fragment
    222551, -- Algari Treatise on Jewelcrafting
    224054, -- Emergent Crystals of the Surface-Dwellers
    228735, -- Glimmer of Jewelcrafting Knowledge
    235859, -- Ethereal Tome of Jewelcrafting Knowledge
    232504, -- Undermine Treatise on Jewelcrafting
    -- #Leatherworking
    226324, -- Earthen Lacing Tools
    226325, -- Dornogal Craftsman's Flat Knife
    226327, -- Earthen Awl
    226326, -- Underground Stropping Compound
    226329, -- Arathi Leather Burnisher
    226328, -- Arathi Beveler Set
    226331, -- Curved Nerubian Skinning Knife
    226330, -- Nerubian Tanning Mallet
    222549, -- Algari Treatise on Leatherworking
    225223, -- Sturdy Nerubian Carapace
    224007, -- Uses for Leftover Husks (How to Take Them Apart)
    224056, -- Uses for Leftover Husks (After You Take Them Apart)
    225222, -- Stone-Leather Swatch
    228737, -- Glimmer of Leatherworking Knowledge
    235858, -- Ethereal Tome of Leatherworking Knowledge
    232505, -- Undermine Treatise on Leatherworking
    -- #Mining
    226333, -- Dornogal Chisel
    226332, -- Earthen Miner's Gavel
    226335, -- Regenerating Ore
    226334, -- Earthen Excavator's Shovel
    226337, -- Devout Archaeologist's Excavator
    226336, -- Arathi Precision Drill
    226338, -- Heavy Spider Crusher
    226339, -- Nerubian Mining Supplies
    224055, -- A Rocky Start
    224583, -- Slab of Slate
    224818, -- Algari Miner's Notes
    227427, -- Exceptional Miner's Notes
    224651, -- Machine-Learned Mining Notes
    227416, -- Faded Miner's Notes
    222553, -- Algari Treatise on Mining
    224584, -- Erosion Polished Slate
    224838, -- Null Sliver
    235857, -- Ethereal Tome of Mining Knowledge
    232509, -- Undermine Treatise on Mining
    -- #Skinning
    226340, -- Dornogal Carving Knife
    226341, -- Earthen Worker's Beams
    226343, -- Fungarian's Rich Tannin
    226342, -- Artisan's Drawing Knife
    226345, -- Arathi Craftsman's Spokeshave
    226344, -- Arathi Tanning Agent
    226347, -- Carapace Shiner
    226346, -- Nerubian's Slicking Iron
    224780, -- Toughened Tempest Pelt
    222649, -- Algari Treatise on Skinning
    224807, -- Algari Skinner's Notes
    224782, -- Razor Talon
    224780, -- Toughened Tempest Pelt
    235856, -- Ethereal Tome of Skinning Knowledge
    232506, -- Undermine Treatise on Skinning
    -- #Tailoring
    226348, -- Dornogal Seam Ripper
    226349, -- Earthen Tape Measure
    226351, -- Earthen Stitcher's Snips
    226350, -- Runed Earthen Pins
    226352, -- Arathi Rotary Cutter
    226353, -- Royal Outfitter's Protractor
    226354, -- Nerubian Quilt
    226355, -- Nerubian's Pincushion
    224036, -- And That's a Web-Wrap!
    228739, -- Glimmer of Tailoring Knowledge
    228738, -- Flicker of Tailoring Knowledge
    228779, -- Algari Tailor's Notebook
    225220, -- Chitin Needle
    225221, -- Spool of Webweave
    224648, -- Jewel-Etched Tailoring Notes
    227410, -- Faded Tailor's Diagrams
    222547, -- Algari Treatise on Tailoring
    228739, -- Glimmer of Tailoring Knowledge
    235855, -- Ethereal Tome of Tailoring Knowledge
    232502, -- Undermine Treatise on Tailoring
}

addon.TWW_Knowledge = TWW_Knowledge
