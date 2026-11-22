local ADDON_NAME, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
local DB = FDJ.DB or {}

-- Exterior / approach locations used by the journal's dungeon-location button.
-- Coordinates are normalized map coordinates for the Classic/Forever map IDs.
local entrances = {
    ["City of Dalaran"] = {
        mapID = 1416, x = 0.085, y = 0.593,
        label = "City of Dalaran Entrance",
        detail = "Enter through the city's sewers: drop through a grate in the streets and follow the Underbelly pipe to the portal",
        markerType = "dungeon",
    },
    ["The Drowned City"] = {
        mapID = 1434, x = 0.214, y = 0.279,
        label = "The Drowned City Entrance",
        detail = "Underwater west of the Vile Reef: swim to Sunken Hollow by the island with the water elementals; the cave has a large tablet beside it",
        markerType = "dungeon",
    },
    -- Forever's new dungeons (entrance guides, Nov 2026).
    ["Krol'dok Stronghold"] = {
        mapID = 2548, x = 0.375, y = 0.373,
        label = "Krol'dok Stronghold Entrance",
        detail = "Northern Riverglades, on the hill above Sunnyglade: not the big fortress gates but the small cave just west of them",
        markerType = "dungeon",
    },
    ["Alcaz Prison"] = {
        mapID = 1445, x = 0.753, y = 0.141,
        label = "Alcaz Prison Entrance",
        detail = "On Alcaz Island, off north-east Dustwallow Marsh: from the dock take the path up the hill to the prison building at the north end; the portal is in its cellar",
        markerType = "dungeon",
    },
    ["Blackmaw Hold"] = {
        mapID = 1447, x = 0.386, y = 0.332,
        label = "Blackmaw Hold Entrance",
        detail = "Northern Azshara, at the old furbolg gate: follow the long tunnel into the mountain; the portal is at its far end, under Darkwhisper Gorge by the Winterspring border",
        markerType = "dungeon",
    },
    ["Shaper's Terrace"] = {
        mapID = 1449, x = 0.481, y = 0.061,
        label = "Shaper's Terrace Entrance",
        detail = "Northern rim of Un'Goro Crater, on the hill right above Marshal's Refuge: climb the stairs to the titan temple",
        markerType = "dungeon",
    },
    ["Gnomeregan"] = {
        mapID = 1426, x = 0.243, y = 0.398,
        label = "Gnomeregan Entrance",
        detail = "Take the elevator down in north-west Dun Morogh, then keep left through the tunnels to the portal",
        markerType = "dungeon",
    },
    ["Razorfen Kraul"] = {
        mapID = 1413, x = 0.429, y = 0.902,
        label = "Razorfen Kraul Entrance",
        detail = "Southern Barrens, at the end of the thorny corridor",
        markerType = "dungeon",
    },
    ["Scarlet Monastery: Library"] = {
        -- smlibrary (2.0.16): the Library's own door inside the Monastery
        -- (measured in the game: Systems/ScarletWing.lua), where its route's
        -- walked way ends.
        mapID = 1420, x = 0.8535, y = 0.3239,
        label = "Scarlet Monastery Entrance",
        detail = "Inside the Scarlet Monastery; the Library has its own portal door",
        markerType = "dungeon",
    },
    ["Scarlet Monastery: Armory"] = {
        mapID = 1420, x = 0.826, y = 0.338,
        label = "Scarlet Monastery Entrance",
        detail = "Inside the Scarlet Monastery; the Armory door needs The Scarlet Key from the Library",
        markerType = "dungeon",
    },
    ["Scarlet Monastery: Cathedral"] = {
        mapID = 1420, x = 0.826, y = 0.338,
        label = "Scarlet Monastery Entrance",
        detail = "Inside the Scarlet Monastery; the Cathedral door needs The Scarlet Key from the Library",
        markerType = "dungeon",
    },
    ["Razorfen Downs"] = {
        mapID = 1413, x = 0.500, y = 0.920,
        label = "Razorfen Downs Entrance",
        detail = "Far south of the Barrens, at the border with Thousand Needles: through the thorny tunnel to the entrance",
        markerType = "dungeon",
    },
    ["Dire Maul: East"] = {
        mapID = 1444, x = 0.590, y = 0.450,
        label = "Dire Maul Entrance",
        detail = "Central Feralas, inside the ruins of Eldre'Thalas: the East wing is reached through the Broken Commons and the gate on the east side",
        markerType = "dungeon",
    },
    ["Dire Maul: West"] = {
        mapID = 1444, x = 0.590, y = 0.450,
        label = "Dire Maul Entrance",
        detail = "Central Feralas, inside the ruins of Eldre'Thalas: the West wing door, opened with the Crescent Key",
        markerType = "dungeon",
    },
    ["Dire Maul: North"] = {
        mapID = 1444, x = 0.590, y = 0.450,
        label = "Dire Maul Entrance",
        detail = "Central Feralas, inside the ruins of Eldre'Thalas: the North (Gordok) wing door, opened with the Crescent Key",
        markerType = "dungeon",
    },
    ["Stratholme: Living"] = {
        mapID = 1423, x = 0.300, y = 0.150,
        label = "Stratholme Main Gate",
        detail = "North-west Eastern Plaguelands: the main gate of Stratholme",
        markerType = "dungeon",
    },
    ["Stratholme: Undead"] = {
        mapID = 1423, x = 0.440, y = 0.190,
        label = "Stratholme Service Entrance",
        detail = "North of the Eastern Plaguelands: the service entrance on the east side of the city",
        markerType = "dungeon",
    },
    ["Lower Blackrock Spire"] = {
        mapID = 1427, x = 0.348, y = 0.840,
        label = "Lower Blackrock Spire Entrance",
        detail = "Blackrock Mountain, between Searing Gorge and the Burning Steppes: climb to the upper ledge to the Blackrock Spire portal",
        markerType = "dungeon",
    },
    ["Upper Blackrock Spire"] = {
        mapID = 1427, x = 0.348, y = 0.840,
        label = "Upper Blackrock Spire Entrance",
        detail = "Blackrock Mountain, between Searing Gorge and the Burning Steppes: climb to the upper ledge to the Blackrock Spire portal, then through Lower Blackrock Spire to the sealed door",
        markerType = "dungeon",
    },
    ["Blackrock Depths"] = {
        mapID = 1427, x = 0.348, y = 0.840,
        label = "Blackrock Depths Entrance",
        detail = "Blackrock Mountain, between Searing Gorge and the Burning Steppes: take the chain down from the Blackrock Spire ledge and follow the lower path to the Depths portal",
        markerType = "dungeon",
    },
    ["Sunken Temple"] = {
        mapID = 1435, x = 0.695, y = 0.535,
        label = "Sunken Temple Entrance",
        detail = "Swamp of Sorrows: dive into the Pool of Tears and follow the stairs down to the temple door",
        markerType = "dungeon",
    },
    ["Scholomance"] = {
        mapID = 1422, x = 0.697, y = 0.732,
        label = "Scholomance Entrance",
        detail = "Caer Darrow, the island in Darrowmere Lake, Western Plaguelands: the crypt door at the back of the keep",
        markerType = "dungeon",
    },
    ["Maraudon"] = {
        mapID = 1443, x = 0.291, y = 0.625,
        label = "Maraudon Entrance",
        detail = "Western Desolace: through the Valley of Spears into the cave mouth below the Maraudon cliffs",
        markerType = "dungeon",
    },
    ["Uldaman"] = {
        mapID = 1418, x = 0.443, y = 0.120,
        label = "Uldaman Entrance",
        detail = "Northern Badlands: through the excavation cave north of Angor Fortress to the stone door at the back",
        markerType = "dungeon",
    },
    ["Zul'Farrak"] = {
        mapID = 1446, x = 0.387, y = 0.200,
        label = "Zul'Farrak Entrance",
        detail = "North-west Tanaris, at the gate of the troll city",
        markerType = "dungeon",
    },
    ["Scarlet Monastery: Graveyard"] = {
        -- smhorde (2.0.12): the Graveyard's own door (measured in the game:
        -- Systems/ScarletWing.lua), where its route's walked way ends.
        mapID = 1420, x = 0.8480, y = 0.3037,
        label = "Scarlet Monastery Entrance",
        detail = "Inside the Scarlet Monastery courtyard; the Graveyard is the portal on the right",
        markerType = "dungeon",
    },
    ["Hall of Thanes"] = {
        mapID = 1455, x = 0.435, y = 0.520,
        label = "Hall of Thanes Entrance",
        detail = "Dungeon entrance beneath Ironforge",
        markerType = "dungeon",
    },
    ["Wailing Caverns"] = {
        mapID = 1413, x = 0.460, y = 0.364,
        label = "Wailing Caverns Entrance",
        detail = "Cave entrance at Lushwater Oasis",
        markerType = "dungeon",
    },
    ["Excavation Site: Wetlands"] = {
        mapID = 1437, x = 0.477, y = 0.562,
        label = "Excavation Site: Wetlands Entrance",
        detail = "Blue mist portal under a large tree, in the hills southeast of Whelgar's Excavation, reached from Thelgen Rock",
        markerType = "dungeon",
    },
    ["Ruins of Lordaeron"] = {
        mapID = 1420, x = 0.634, y = 0.674,
        label = "Ruins of Lordaeron Entrance",
        detail = "Dungeon entrance in the Ruins of Lordaeron",
        markerType = "dungeon",
    },
    ["The Deadmines"] = {
        mapID = 1436, x = 0.425, y = 0.717,
        label = "The Deadmines Entrance",
        detail = "Dungeon entrance in Moonbrook",
        markerType = "dungeon",
    },
    ["Blackfathom Deeps"] = {
        mapID = 1440, x = 0.145, y = 0.142,
        label = "Blackfathom Deeps Entrance",
        detail = "Dungeon entrance on the Zoram Strand",
        markerType = "dungeon",
    },
    ["Ragefire Chasm"] = {
        mapID = 1454, x = 0.526, y = 0.490,
        label = "Ragefire Chasm Entrance",
        detail = "Dungeon entrance in the Cleft of Shadow",
        markerType = "dungeon",
    },
    ["The Stockade"] = {
        mapID = 1453, x = 0.524, y = 0.700,
        label = "The Stockade Entrance",
        detail = "Dungeon entrance in Stormwind's Canal District",
        markerType = "dungeon",
    },
    ["Shadowfang Keep"] = {
        mapID = 1421, x = 0.448, y = 0.678,
        label = "Shadowfang Keep Entrance",
        detail = "Dungeon entrance north of Pyrewood Village",
        markerType = "dungeon",
    },
}

for dungeonName, entrance in pairs(entrances) do
    if DB[dungeonName] then
        DB[dungeonName].entrance = entrance
    end
end
