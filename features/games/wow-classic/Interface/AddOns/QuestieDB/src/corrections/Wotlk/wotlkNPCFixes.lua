---@class QuestieWotlkNpcFixes
local QuestieWotlkNpcFixes = QuestieLoader:CreateModule("QuestieWotlkNpcFixes")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type Phasing
local Phasing = QuestieLoader:ImportModule("Phasing")

function QuestieWotlkNpcFixes:Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

function QuestieWotlkNpcFixes:LoadAutomatics()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

-- This should allow manual fix for NPC availability
function QuestieWotlkNpcFixes:LoadFactionFixes()
    local npcKeys = QuestieDB.npcKeys
    local zoneIDs = ZoneDB.zoneIDs

    local npcFixesHorde = {
        [15898] = { -- Lunar Festival Vendor
            [npcKeys.spawns] = {
                [zoneIDs.ORGRIMMAR] = {{41.27,32.36}},
                [zoneIDs.THUNDER_BLUFF] = {{70.56,27.83}},
                [zoneIDs.UNDERCITY] = {{66.45,36.02}},
                [zoneIDs.MOONGLADE] = {{36.58,58.1},{36.3,58.53}},
                [zoneIDs.SHATTRATH_CITY] = {{52.63,33.25},{48.64,36.29}},
                [zoneIDs.SILVERMOON_CITY] = {{73.41,82.17}},
                [zoneIDs.DALARAN] = {{47.93,43.32}},
            },
        },
        [26221] = { -- Earthen Ring Elder
            [npcKeys.spawns] = {[zoneIDs.UNDERCITY] = {{66.9,13.53}},[zoneIDs.ORGRIMMAR] = {{46.44,38.69}},[zoneIDs.THUNDER_BLUFF] = {{22.16,23.98}},[zoneIDs.SHATTRATH_CITY] = {{60.68,30.62}},[zoneIDs.SILVERMOON_CITY] = {{68.67,42.94}}},
        },
        [29579] = { -- Brann Bronzebeard
            [npcKeys.spawns] = {[zoneIDs.STORM_PEAKS] = {{36.62,49.27}}},
        },
        [34806] = { -- Spirit of Sharing
            [npcKeys.name] = "Spirit of Sharing",
            [npcKeys.spawns] = {
                [zoneIDs.STORM_PEAKS] = {{40.38,85.5}},
                [zoneIDs.ZUL_DRAK] = {{41.2,68.25}},
                [zoneIDs.GRIZZLY_HILLS] = {{22.43,65.94}},
                [zoneIDs.HOWLING_FJORD] = {{49.14,13.05}},
                [zoneIDs.DRAGONBLIGHT] = {{37.25,47.11}},
                [zoneIDs.BOREAN_TUNDRA] = {{40.95,52.44},{40.62,52.88}},
                [zoneIDs.SHOLAZAR_BASIN] = {{47.59,60.92}},
                [zoneIDs.SHATTRATH_CITY] = {{43.42,51.93},{43.17,50.29},{42.96,48.61},{42.7,46.84}},
                [zoneIDs.SHADOWMOON_VALLEY] = {{29.97,28.77}},
                [zoneIDs.NAGRAND] = {{56.65,33.94}},
                [zoneIDs.ZANGARMARSH] = {{32.75,51.19}},
                [zoneIDs.BLADES_EDGE_MOUNTAINS] = {{52.28,54.96}},
                [zoneIDs.NETHERSTORM] = {{33.9,64.43}},
                [zoneIDs.HELLFIRE_PENINSULA] = {{56.44,38.39},{56.02,37.74}},
                [zoneIDs.WINTERSPRING] = {{60.26,36.41}},
                [zoneIDs.TANARIS] = {{51.95,25.55}},
                [zoneIDs.SILITHUS] = {{51.89,37.71}},
                [zoneIDs.FERALAS] = {{74.88,43.33}},
                [zoneIDs.THOUSAND_NEEDLES] = {{45.54,51.59}},
                [zoneIDs.STRANGLETHORN_VALE] = {{32.35,28.3}},
                [zoneIDs.SWAMP_OF_SORROWS] = {{46.2,56.66}},
                [zoneIDs.BURNING_STEPPES] = {{63.96,31.66}},
                [zoneIDs.BADLANDS] = {{5.02,48.98}},
                [zoneIDs.ARATHI_HIGHLANDS] = {{74.86,36.88}},
                [zoneIDs.HILLSBRAD_FOOTHILLS] = {{61.03,20.84}},
                [zoneIDs.THE_HINTERLANDS] = {{79,80.76}},
                [zoneIDs.EASTERN_PLAGUELANDS] = {{74.11,52.14}},
                [zoneIDs.DUROTAR] = {{46.32,14.58},{46.37,15.08},{46.66,15.02},{46.64,14.58},{52.98,43.89},{52.99,43.54}},
                [zoneIDs.GHOSTLANDS] = {{44.85,30.98}},
                [zoneIDs.EVERSONG_WOODS] = {{55.65,53.15},{55.61,53.53},{55.3,53.18},{55.29,53.64},{46.52,46.64},{46.5,46.94},{46.46,47.27}},
                [zoneIDs.UNDERCITY] = {{64.1,14.23},{67.82,14.3},{67.98,7.85},{64.37,7.86}},
                [zoneIDs.TIRISFAL_GLADES] = {{58.81,51.17},{59.12,51.21},{59.38,51.26}},
                [zoneIDs.SILVERPINE_FOREST] = {{44.33,42.33}},
                [zoneIDs.THUNDER_BLUFF] = {{29.83,62.24},{31.24,66.99},{30.21,67.43},{28.76,62.4}},
                [zoneIDs.MULGORE] = {{46.43,59.57},{46.23,59.77}},
                [zoneIDs.THE_BARRENS] = {{51.52,29.52},{51.62,29.42},{62.48,38.22}},
                [zoneIDs.STONETALON_MOUNTAINS] = {{46.25,59.98}},
                [zoneIDs.ASHENVALE] = {{73.9,60.47}},
                [zoneIDs.DUSTWALLOW_MARSH] = {{35.68,31.53}},
                [zoneIDs.DESOLACE] = {{25.41,72.09}},
            },
        },
        [34907] = { -- Kvaldir Harpooner
            [npcKeys.spawns] = {[zoneIDs.HROTHGARS_LANDING] = {{43.43,53.57},{43.1,53.5},{42.94,53.83},{43.92,54.36},{44.07,54.44},{43.82,54.64},{42.62,53.3},{42.85,53.33},{44.23,54.41},{43.36,53.87}}},
        },
        [34947] = { -- Kvaldir Berserker
            [npcKeys.spawns] = {[zoneIDs.HROTHGARS_LANDING] = {{43.43,53.57},{43.1,53.5},{42.94,53.83},{43.92,54.36},{44.07,54.44},{43.82,54.64},{42.62,53.3},{42.85,53.33},{44.23,54.41},{43.36,53.87}}},
        },
        [35060] = { -- North Sea Thresher
            [npcKeys.spawns] = {[zoneIDs.ICECROWN] = {{74.14,10.52},{74.7,9.72},{74.15,9.14},{73.76,9.69}}},
            [npcKeys.zoneID] = zoneIDs.ICECROWN,
        },
        [35061] = { -- North Sea Blue Shark
            [npcKeys.spawns] = {[zoneIDs.ICECROWN] = {{74.14,10.52},{74.7,9.72},{74.15,9.14},{73.76,9.69}}},
            [npcKeys.zoneID] = zoneIDs.ICECROWN,
        },
        [35071] = { -- North Sea Mako
            [npcKeys.spawns] = {[zoneIDs.ICECROWN] = {{74.14,10.52},{74.7,9.72},{74.15,9.14},{73.76,9.69}}},
            [npcKeys.zoneID] = zoneIDs.ICECROWN,
        },
        [37214] = { -- Crown Lackey
            [npcKeys.spawns] = {[zoneIDs.DUROTAR] = {{40.3,15.8},{40.1,15.5},{40.5,15.5},{40.5,15.2},{40.3,15.0}}},
        },
        [37715] = { -- Snivel Rustrocket
            [npcKeys.spawns] = {[zoneIDs.DUROTAR] = {{50.63,13.13}}},
        },
        [37917] = { -- Crown Thug
            [npcKeys.spawns] = {[zoneIDs.SILVERPINE_FOREST] = {{55.2,61.0},{55.3,62.0},{54.9,63.1},{54.6,62.3}}},
        },
        [38340] = { -- [DND] Holiday - Love - Bank Bunny
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{49,68.96}}}
        },
        [38341] = { -- [DND] Holiday - Love - AH Bunny
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{54.26,63.77}}}
        },
        [38342] = { -- [DND] Holiday - Love - Barber Bunny
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{47.21,54.09}}}
        },
    }

    local npcFixesAlliance = {
        [5676] = { -- Summoned Voidwalker
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{39.09,84.36}}},
        },
        [5677] = { -- Summoned Succubus
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{39.09,84.36}}},
        },
        [6492] = { -- Rift Spawn
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{51.32,92.34},{50.83,92.63},{51.61,94.5},{51.21,95.73},{50.99,95.58},{51.3,93.34}}},
            [npcKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [15898] = { -- Lunar Festival Vendor
            [npcKeys.spawns] = {
                [zoneIDs.STORMWIND_CITY] = {{37.32,64.04}},
                [zoneIDs.IRONFORGE] = {{29.92,14.21}},
                [zoneIDs.DARNASSUS] = {{34.57,12.8}},
                [zoneIDs.MOONGLADE] = {{36.58,58.1},{36.3,58.53}},
                [zoneIDs.SHATTRATH_CITY] = {{52.63,33.25},{48.64,36.29}},
                [zoneIDs.THE_EXODAR] = {{74.02,58.23}},
                [zoneIDs.DALARAN] = {{47.93,43.32}},
            },
        },
        [26221] = { -- Earthen Ring Elder
            [npcKeys.spawns] = {[zoneIDs.TELDRASSIL] = {{56.1,92.16}},[zoneIDs.SHATTRATH_CITY] = {{60.68,30.62}},[zoneIDs.IRONFORGE] = {{65.14,27.71}},[zoneIDs.STORMWIND_CITY] = {{49.32,72.3}},[zoneIDs.THE_EXODAR] = {{43.27,26.26}}},
        },
        [29579] = { -- Brann Bronzebeard
            [npcKeys.spawns] = {[zoneIDs.STORM_PEAKS] = {{30.1,73.9}}},
        },
        [34806] = { -- Spirit of Sharing
            [npcKeys.name] = "Spirit of Sharing",
            [npcKeys.spawns] = {
                [zoneIDs.STORM_PEAKS] = {{40.38,85.5}},
                [zoneIDs.ZUL_DRAK] = {{41.2,68.25}},
                [zoneIDs.GRIZZLY_HILLS] = {{31.3,59.59}},
                [zoneIDs.HOWLING_FJORD] = {{60.45,16.74}},
                [zoneIDs.DRAGONBLIGHT] = {{77.78,50.85}},
                [zoneIDs.BOREAN_TUNDRA] = {{56.93,67.48},{56.92,67.82}},
                [zoneIDs.SHOLAZAR_BASIN] = {{47.59,60.92}},
                [zoneIDs.SHATTRATH_CITY] = {{43.42,51.93},{43.17,50.29},{42.96,48.61},{42.7,46.84}},
                [zoneIDs.SHADOWMOON_VALLEY] = {{37.78,55.62}},
                [zoneIDs.NAGRAND] = {{54.03,75.49}},
                [zoneIDs.ZANGARMARSH] = {{67.72,51.16}},
                [zoneIDs.BLADES_EDGE_MOUNTAINS] = {{37.9,61.97}},
                [zoneIDs.NETHERSTORM] = {{33.9,64.43}},
                [zoneIDs.HELLFIRE_PENINSULA] = {{55.07,63.22},{56.45,63.92}},
                [zoneIDs.THE_EXODAR] = {{75.74,52.29},{75.75,50.51},{76.95,51.26},{77.21,53.08}},
                [zoneIDs.AZUREMYST_ISLE] = {{51.71,52.11},{51.69,51.14}},
                [zoneIDs.BLOODMYST_ISLE] = {{56.03,58.75}},
                [zoneIDs.DARKSHORE] = {{36.91,43.65}},
                [zoneIDs.WINTERSPRING] = {{62.17,37.03}},
                [zoneIDs.DARNASSUS] = {{69.56,38.23},{67.85,38.08},{67.81,36.09},{69.47,36.08}},
                [zoneIDs.TELDRASSIL] = {{56.44,58.4},{56.36,56.92}},
                [zoneIDs.TANARIS] = {{51.2,29.42}},
                [zoneIDs.SILITHUS] = {{51.89,37.71}},
                [zoneIDs.FERALAS] = {{29.96,43.41}},
                [zoneIDs.ELWYNN_FOREST] = {{34.33,51.18},{34.58,50.81},{34.81,50.45},{41.52,64.04},{41.43,64.65},{41.67,64.83}},
                [zoneIDs.DUN_MOROGH] = {{52.77,36.41},{52.76,36.74},{52.76,37.03},{46.69,55.41},{46.66,55.12},{46.64,54.75},{46.19,52.91}},
                [zoneIDs.WESTFALL] = {{53.21,52.61}},
                [zoneIDs.STRANGLETHORN_VALE] = {{37.87,3.78}},
                [zoneIDs.DUSKWOOD] = {{77.64,43.85}},
                [zoneIDs.BLASTED_LANDS] = {{66.54,23.66}},
                [zoneIDs.REDRIDGE_MOUNTAINS] = {{32.23,53.35}},
                [zoneIDs.BURNING_STEPPES] = {{85.83,69.78}},
                [zoneIDs.LOCH_MODAN] = {{32.16,48.4}},
                [zoneIDs.WETLANDS] = {{9.19,60.77},},
                [zoneIDs.ARATHI_HIGHLANDS] = {{46,45.97}},
                [zoneIDs.HILLSBRAD_FOOTHILLS] = {{49.61,61.05}},
                [zoneIDs.THE_HINTERLANDS] = {{13.91,46.87}},
                [zoneIDs.EASTERN_PLAGUELANDS] = {{74.81,54.22}},
                [zoneIDs.WESTERN_PLAGUELANDS] = {{43.73,84.72}},
                [zoneIDs.THE_BARRENS] = {{62.64,38.23}},
                [zoneIDs.DUSTWALLOW_MARSH] = {{68,50.78}},
                [zoneIDs.DESOLACE] = {{65.19,8.73}},
                [zoneIDs.ASHENVALE] = {{35.26,50.41}},
            },
        },
        [34907] = { -- Kvaldir Harpooner
            [npcKeys.spawns] = {[zoneIDs.HROTHGARS_LANDING] = {{50.21,49.08},{50.14,49.47},{49.75,49.51},{50.06,49.08},{50.63,48.98},{51.18,48.81},{50.43,49.05},{49.9,49.59},{50.3,49.61},{51,48.53}}},
        },
        [34947] = { -- Kvaldir Berserker
            [npcKeys.spawns] = {[zoneIDs.HROTHGARS_LANDING] = {{50.21,49.08},{50.14,49.47},{49.75,49.51},{50.06,49.08},{50.63,48.98},{51.18,48.81},{50.43,49.05},{49.9,49.59},{50.3,49.61},{51,48.53}}},
        },
        [35060] = { -- North Sea Thresher
            [npcKeys.spawns] = {[zoneIDs.ICECROWN] = {{66.87,8.97},{66.36,8.08},{67.31,8.2},{66.92,7.55}}},
            [npcKeys.zoneID] = zoneIDs.ICECROWN,
        },
        [35061] = { -- North Sea Blue Shark
            [npcKeys.spawns] = {[zoneIDs.ICECROWN] = {{66.87,8.97},{66.36,8.08},{67.31,8.2},{66.92,7.55}}},
            [npcKeys.zoneID] = zoneIDs.ICECROWN,
        },
        [35071] = { -- North Sea Mako
            [npcKeys.spawns] = {[zoneIDs.ICECROWN] = {{66.87,8.97},{66.36,8.08},{67.31,8.2},{66.92,7.55}}},
            [npcKeys.zoneID] = zoneIDs.ICECROWN,
        },
        [37214] = { -- Crown Lackey
            [npcKeys.spawns] = {[zoneIDs.ELWYNN_FOREST] = {{29.1,66.5},{28.8,66.2},{29.5,65.7},{28.8,65.7},{29.2,65.2}}},
        },
        [37715] = { -- Snivel Rustrocket
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{27.43,34.83}}},
        },
        [37917] = { -- Crown Thug
            [npcKeys.spawns] = {[zoneIDs.DARKSHORE] = {{43.3,79.9},{43.2,79.9},{43.2,79.5},{42.7,79.5},{43.0,79.4}}},
        },
        [38340] = { -- [DND] Holiday - Love - Bank Bunny
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{63.08,78.86}}},
        },
        [38341] = { -- [DND] Holiday - Love - AH Bunny
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{60.81,70.03}}},
        },
        [38342] = { -- [DND] Holiday - Love - Barber Bunny
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{61.33,65.64}}},
        },
        [185335] = { -- Summoned Incubus
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{39.09,84.36}}},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return npcFixesHorde
    else
        return npcFixesAlliance
    end
end
