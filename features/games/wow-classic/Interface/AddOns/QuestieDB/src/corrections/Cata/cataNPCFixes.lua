---@class CataNpcFixes
local CataNpcFixes = QuestieLoader:CreateModule("CataNpcFixes")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type Phasing
local Phasing = QuestieLoader:ImportModule("Phasing")

function CataNpcFixes.Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

-- This should allow manual fix for NPC availability
function CataNpcFixes:LoadFactionFixes()
    local npcKeys = QuestieDB.npcKeys
    local zoneIDs = ZoneDB.zoneIDs
    local phases = Phasing.phases

    local npcFixesHorde = {
        [5676] = { -- Summoned Voidwalker
            [npcKeys.spawns] = {
                [zoneIDs.UNDERCITY] = {{86.62,27.05}},
                [zoneIDs.ORGRIMMAR] = {{49.89,58.73}},
            },
        },
        [5677] = { -- Summoned Succubus
            [npcKeys.spawns] = {
                [zoneIDs.UNDERCITY] = {{86.62,27.05}},
                [zoneIDs.ORGRIMMAR] = {{49.89,58.73}},
            },
        },
        [7783] = { -- Loramus Thalipedes
            [npcKeys.spawns] = {[zoneIDs.BLASTED_LANDS] = {{39.36,35.78}}},
        },
        [15898] = { -- Lunar Festival Vendor
            [npcKeys.spawns] = {
                [zoneIDs.THUNDER_BLUFF] = {{70.56,27.83}},
                [zoneIDs.UNDERCITY] = {{66.45,36.02}},
                [zoneIDs.MOONGLADE] = {{36.58,58.1},{36.3,58.53}},
                [zoneIDs.SHATTRATH_CITY] = {{52.63,33.25},{48.64,36.29}},
                [zoneIDs.SILVERMOON_CITY] = {{73.41,82.17}},
                [zoneIDs.DALARAN] = {{47.93,43.32}},
            },
        },
        [23537] = { -- Headless Horseman - Fire (DND)
            [npcKeys.spawns] = {
                [zoneIDs.TIRISFAL_GLADES] = {{56.98,53.02},{56.84,53.36},{56.67,53.21},{56.44,53.33},{56.32,53.05}},
                [zoneIDs.DUROTAR] = {{49.28,43.08},{49.24,42.9},{49.1,42.99},{49.16,43.16},{49.3,43.41}},
                [zoneIDs.EVERSONG_WOODS] = {{46.25,55.3},{46.36,55.33},{46.49,55.34},{46.55,55.19},{46.61,55.02}},
            },
        },
        [24108] = { -- Self-Turning and Oscillating Utility Target
            [npcKeys.spawns] = {[zoneIDs.DUROTAR] = {{41.74,17.2}}},
        },
        [24202] = { -- [DND] Brewfest Barker Bunny 1
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{51.41,78.7}}},
        },
        [24203] = { -- [DND] Brewfest Barker Bunny 2
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{67.64,47.83}}},
        },
        [24204] = { -- [DND] Brewfest Barker Bunny 3
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{44.18,48.95}}},
        },
        [24205] = { -- [DND] Brewfest Barker Bunny 4
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{37.68,75.58}}},
        },
        [26221] = { -- Earthen Ring Elder
            [npcKeys.spawns] = {
                [zoneIDs.TIRISFAL_GLADES] = {{62.01,67.92}},
                [zoneIDs.ORGRIMMAR] = {{47.26,37.89}},
                [zoneIDs.THUNDER_BLUFF] = {{21.21,24.06}},
                [zoneIDs.SHATTRATH_CITY] = {{60.68,30.62}},
                [zoneIDs.SILVERMOON_CITY] = {{68.67,42.94}},
            },
        },
        --[[[34806] = { -- Spirit of Sharing
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
        [37214] = { -- Crown Lackey
            [npcKeys.spawns] = {[zoneIDs.DUROTAR] = {{40.3,15.8},{40.1,15.5},{40.5,15.5},{40.5,15.2},{40.3,15.0}}},
        },
        [37917] = { -- Crown Thug
            [npcKeys.spawns] = {[zoneIDs.SILVERPINE_FOREST] = {{55.2,61.0},{55.3,62.0},{54.9,63.1},{54.6,62.3}}},
        },]]
        [29579] = { -- Brann Bronzebeard
            [npcKeys.spawns] = {[zoneIDs.STORM_PEAKS] = {{36.62,49.27}}},
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
        [37715] = { -- Snivel Rustrocket
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{51.66,56.75}}},
        },
        [37984] = { -- Crown Duster
            [npcKeys.spawns] = {[zoneIDs.HILLSBRAD_FOOTHILLS] = {{33.33,58.2},{33.78,57.52},{34.02,57.36},{34.09,58.03},{34.39,57.9},{34.89,58.18},{34.63,58.19},{34.26,58.86},{33.72,58.19},{33.5,58.69},{33.58,59.36},{34.24,59.29},{34.52,59.58},{34.89,58.98},{35.1,58.43}}},
        },
        [38340] = { -- [DND] Holiday - Love - Bank Bunny
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{49.3,81.99}}},
        },
        [38341] = { -- [DND] Holiday - AH - Bank Bunny
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{52.91,74.82}}},
        },
        [38342] = { -- [DND] Holiday - Barber - Bank Bunny
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{40.61,60.74}}},
        },
        [39237] = { -- x3 JC Quest Stardust Applied
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{72.5,36.2}}},
        },
        [41600] = { -- Erunak Stonespeaker
            [npcKeys.spawns] = {
                [zoneIDs.ABYSSAL_DEPTHS] = {
                    {51.57,60.9,phases.VASHJIR_ERANUK_AT_CAVERN},
                    {42.69,37.91,phases.VASHJIR_ERANUK_AT_PROMONTORY_POINT},
                },
            },
        },
        [41814] = { -- Merciless One in Control of You
            [npcKeys.spawns] = {[zoneIDs.ABYSSAL_DEPTHS] = {{51.49,60.85}}},
        },
        [42486] = { -- Boarding Submarine Credit Bunny
            [npcKeys.spawns] = {[zoneIDs.SHIMMERING_EXPANSE] = {{50.72,66.47}}},
        },
        [42790] = { -- Bloodlord Mandokir
            [npcKeys.spawns] = {[zoneIDs.STRANGLETHORN_VALE] = {{38.4,48.6}}},
        },
        [48416] = { -- Ozumat
            [npcKeys.spawns] = {[zoneIDs.ABYSSAL_DEPTHS] = {{53.83,61.91}}},
        },
        [52234] = { -- Bwemba
            [npcKeys.spawns] = {[zoneIDs.STRANGLETHORN_VALE] = {{64.3,39.7}}},
        },
        [52762] = { -- [DND] At the Digsite
            [npcKeys.spawns] = {[zoneIDs.THE_CAPE_OF_STRANGLETHORN] = {{35.13,29.33}}},
            [npcKeys.zoneID] = zoneIDs.THE_CAPE_OF_STRANGLETHORN,
        },
        [53422] = { -- Dragonwrath, Tarecgosa's Rest
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{48.27,71.74}}},
        },
        [54114] = { -- Unleashed Void
            [npcKeys.spawns] = {[zoneIDs.TIRISFAL_GLADES] = {{65.77,74.8}}},
        },
        [185335] = { -- Summoned Incubus
            [npcKeys.spawns] = {
                [zoneIDs.UNDERCITY] = {{86.62,27.05}},
                [zoneIDs.ORGRIMMAR] = {{49.89,58.73}},
            },
        },
    }

    local npcFixesAlliance = {
        [5676] = { -- Summoned Voidwalker
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{39.12,84.34}}},
        },
        [5677] = { -- Summoned Succubus
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{39.12,84.34}}},
        },
        [7783] = { -- Loramus Thalipedes
            [npcKeys.spawns] = {[zoneIDs.BLASTED_LANDS] = {{62.31,26.09}}},
        },
        [15898] = { -- Lunar Festival Vendor
            [npcKeys.spawns] = {
                [zoneIDs.ELWYNN_FOREST] = {{34.81,50.33}},
                [zoneIDs.IRONFORGE] = {{29.92,14.21}},
                [zoneIDs.DARNASSUS] = {{39.93,30.82}},
                [zoneIDs.MOONGLADE] = {{36.58,58.1},{36.3,58.53}},
                [zoneIDs.SHATTRATH_CITY] = {{52.63,33.25},{48.64,36.29}},
                [zoneIDs.THE_EXODAR] = {{74.02,58.23}},
                [zoneIDs.DALARAN] = {{47.93,43.32}},
            },
        },
        [23537] = { -- Headless Horseman - Fire (DND)
            [npcKeys.spawns] = {
                [zoneIDs.ELWYNN_FOREST] = {{42.63,60},{42.39,59.71},{42.55,59.3},{42.74,59.34},{42.9,59.36}},
                [zoneIDs.DUN_MOROGH] = {{54.42,55.31},{54.54,55.48},{54.41,55.51},{54.43,55.75},{54.3,55.64}},
                [zoneIDs.AZUREMYST_ISLE] = {{43.44,51.52},{43.79,51.92},{43.64,52.07},{43.5,51.92},{43.35,51.74}},
            },
        },
        [24108] = { -- Self-Turning and Oscillating Utility Target
            [npcKeys.spawns] = {[zoneIDs.DUN_MOROGH] = {{54.8,37.54}}},
        },
        [24202] = { -- [DND] Brewfest Barker Bunny 1
            [npcKeys.spawns] = {[zoneIDs.IRONFORGE] = {{30.2,66.5}}},
        },
        [24203] = { -- [DND] Brewfest Barker Bunny 2
            [npcKeys.spawns] = {[zoneIDs.IRONFORGE] = {{64,78.2}}},
        },
        [24204] = { -- [DND] Brewfest Barker Bunny 3
            [npcKeys.spawns] = {[zoneIDs.IRONFORGE] = {{64.3,24.3}}},
        },
        [24205] = { -- [DND] Brewfest Barker Bunny 4
            [npcKeys.spawns] = {[zoneIDs.IRONFORGE] = {{32.2,21}}},
        },
        [26221] = { -- Earthen Ring Elder
            [npcKeys.spawns] = {
                [zoneIDs.DARNASSUS] = {{62.11,49.13}},
                [zoneIDs.SHATTRATH_CITY] = {{60.68,30.62}},
                [zoneIDs.IRONFORGE] = {{65.14,27.71}},
                [zoneIDs.STORMWIND_CITY] = {{49.31,72.29}},
                [zoneIDs.THE_EXODAR] = {{43.27,26.26}},
            },
        },
        --[[[34806] = { -- Spirit of Sharing
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
        [37214] = { -- Crown Lackey
            [npcKeys.spawns] = {[zoneIDs.ELWYNN_FOREST] = {{29.1,66.5},{28.8,66.2},{29.5,65.7},{28.8,65.7},{29.2,65.2}}},
        },]]
        [29579] = { -- Brann Bronzebeard
            [npcKeys.spawns] = {[zoneIDs.STORM_PEAKS] = {{30.1,73.9}}},
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
        [37715] = { -- Snivel Rustrocket
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{27.43,34.83}}},
        },
        [37917] = { -- Crown Thug
            [npcKeys.spawns] = {[zoneIDs.DARKSHORE] = {{44.14,78.16},{44.25,77.89},{44.05,76.85},{44.45,77.31},{44.24,77.52},{44.08,77.41},{43.82,77.39},{43.97,77.78},{43.82,78.18},{44.01,78.57},{44.32,78.54},{44.7,78.26},{44.49,78.09},{44.68,77.6}}},
        },
        [37984] = { -- Crown Duster
            [npcKeys.spawns] = {[zoneIDs.DUSKWOOD] = {{76.82,57.21},{77.56,55.72},{78.01,54.3},{77.98,53.45},{77.43,52.17},{77.02,52.95},{76.67,53.68},{76.2,52.75},{75.82,51.86},{75.46,52.83},{75.61,53.77},{75.63,54.5},{75.76,55.79},{75.37,56.55}}},
        },
        [38340] = { -- [DND] Holiday - Love - Bank Bunny
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{63.02,78.73}}},
        },
        [38341] = { -- [DND] Holiday - AH - Bank Bunny
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{61.39,71.61}}},
        },
        [38342] = { -- [DND] Holiday - Barber - Bank Bunny
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{61.32,65.57}}},
        },
        [39237] = { -- x3 JC Quest Stardust Applied
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{63.8,60.8}}},
        },
        [41600] = { -- Erunak Stonespeaker
            [npcKeys.spawns] = {
                [zoneIDs.ABYSSAL_DEPTHS] = {
                    {55.71,72.98,phases.VASHJIR_ERANUK_AT_CAVERN},
                    {42.69,37.91,phases.VASHJIR_ERANUK_AT_PROMONTORY_POINT},
                },
            },
        },
        [41814] = { -- Merciless One in Control of You
            [npcKeys.spawns] = {[zoneIDs.ABYSSAL_DEPTHS] = {{55.51,72.9}}},
        },
        [42486] = { -- Boarding Submarine Credit Bunny
            [npcKeys.spawns] = {[zoneIDs.SHIMMERING_EXPANSE] = {{56.68,76.62}}},
        },
        [42790] = { -- Bloodlord Mandokir
            [npcKeys.spawns] = {[zoneIDs.STRANGLETHORN_VALE] = {{47.2,10.6}}},
        },
        [48416] = { -- Ozumat
            [npcKeys.spawns] = {[zoneIDs.ABYSSAL_DEPTHS] = {{55.83,76.21}}},
        },
        [52234] = { -- Bwemba
            [npcKeys.spawns] = {[zoneIDs.STRANGLETHORN_VALE] = {{52.82,66.71}}},
        },
        [52762] = { -- [DND] At the Digsite
            [npcKeys.spawns] = {[zoneIDs.THE_CAPE_OF_STRANGLETHORN] = {{55.5,41.26}}},
            [npcKeys.zoneID] = zoneIDs.THE_CAPE_OF_STRANGLETHORN,
        },
        [53422] = { -- Dragonwrath, Tarecgosa's Rest
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{57.24,59.26}}},
        },
        [54114] = { -- Unleashed Void
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{55.39,43.41}}},
        },
        [185335] = { -- Summoned Incubus
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{39.12,84.34}}},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return npcFixesHorde
    else
        return npcFixesAlliance
    end
end
