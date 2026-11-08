---@class CataObjectFixes
local CataObjectFixes = QuestieLoader:CreateModule("CataObjectFixes")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")


function CataObjectFixes.Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

function CataObjectFixes:LoadFactionFixes()
    local objectKeys = QuestieDB.objectKeys
    local zoneIDs = ZoneDB.zoneIDs

    local objectFixesHorde = {
        [180449] = { -- Forsaken Stink Bomb
            [objectKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{71.9,73.37},{72.97,66.13},{73.77,59.68},{73.62,52.32},{71.2,46.14},{65.58,40.17},{61.68,30.26},{62.75,33.49},{58.73,36.76},{55.11,44.8},{55.47,48.75},{58.21,53.72},{54.01,54.66},{50.43,52.9},{46.47,53.99},{48.12,62.84},{48.34,67.39},{50.01,71.56},{53.45,71.01},{57.88,68.15},{60.17,71.63},{62.18,73.99},{65.23,75.58},{67.4,79.36}}},
        },
        [180743] = { -- Carefully Wrapped Present
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{49.29,78.27}}},
        },
        [180746] = { -- Gently Shaken Gift
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{49.19,77.75}}},
        },
        [180747] = { -- Gaily Wrapped Present
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{49.53,78.1}}},
        },
        [180748] = { -- Ticking Present
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{49.19,77.75}}},
        },
        [180793] = { -- Festive Gift
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{49.54,77.82}}},
        },
        [186189] = { -- Complimentary Brewfest Sampler
            [objectKeys.spawns] = {[zoneIDs.DUROTAR] = {{41.56,17.56},{41.52,17.5},{41.39,17.42},{40.74,16.82},{40.34,16.81},{40.13,17.48},{40.39,18.04},{40.85,18.28},{40.9,18.31}}},
        },
        [186234] = { -- Water Barrel
            [objectKeys.spawns] = {
                [zoneIDs.TIRISFAL_GLADES] = {{56.63,52.55},{61.02,53.64}},
                [zoneIDs.DUROTAR] = {{49.16,44.5},{52.54,41.29}},
                [zoneIDs.EVERSONG_WOODS] = {{46.35,55.02},{47.19,46.62}},
            },
        },
        [186887] = { -- Large Jack-o'-Lantern
            [objectKeys.spawns] = {
                [zoneIDs.DUROTAR] = {{52.45,42.27}},
                [zoneIDs.TIRISFAL_GLADES] = {{60.9,52.72}},
                [zoneIDs.EVERSONG_WOODS] = {{47.58,46.24}},
            },
        },
        [187236] = { -- Winter Veil Gift
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{49.39,77.62}}},
        },
        [195122] = { -- Forsaken Stink Bomb Cloud
            [objectKeys.spawns] = {[zoneIDs.UNDERCITY] = {{83.7,47.97},{81.66,37.08},{77.76,27.23},{64.27,19.51},{54.97,24.69},{51.59,31.68},{49.66,41.7},{51.01,53.73},{56.21,63.97},{63.71,68.2},{71.03,63.23},{78.75,59.37},{84.11,52.19},{71.06,20.77},{65.98,24.28},{66.01,37.53},{67.8,41.42},{64.28,41.54},{63.66,47.05},{67.2,47.66},{69.54,38.78},{68.4,33.68},{63.31,33.81},{59.41,39.68},{58.97,47.16},{62.18,53.13},{67.4,55.15},{71.57,51.18},{73.04,44.58},{71.95,38.48},{65.9,31.49},{62.32,20.03},{57.95,22.51}}},
        },
        [203461] = { -- Fuel Sampling Station
            [objectKeys.spawns] = {[zoneIDs.ABYSSAL_DEPTHS] = {{51.49,60.41}}},
        },
        [207125] = { -- Crate of Left Over Supplies
            [objectKeys.spawns] = {[zoneIDs.BURNING_STEPPES] = {{54.79,24.41}}},
        },
    }

    local objectFixesAlliance = {
        [180449] = { -- Forsaken Stink Bomb
            [objectKeys.spawns] = {[zoneIDs.UNDERCITY] = {{83.7,47.97},{81.66,37.08},{77.76,27.23},{64.27,19.51},{54.97,24.69},{51.59,31.68},{49.66,41.7},{51.01,53.73},{56.21,63.97},{63.71,68.2},{71.03,63.23},{78.75,59.37},{84.11,52.19},{71.06,20.77},{65.98,24.28},{66.01,37.53},{67.8,41.42},{64.28,41.54},{63.66,47.05},{67.2,47.66},{69.54,38.78},{68.4,33.68},{63.31,33.81},{59.41,39.68},{58.97,47.16},{62.18,53.13},{67.4,55.15},{71.57,51.18},{73.04,44.58},{71.95,38.48},{65.9,31.49},{62.32,20.03},{57.95,22.51}}},
        },
        [180743] = { -- Carefully Wrapped Present
            [objectKeys.spawns] = {[zoneIDs.IRONFORGE] = {{33.86,65.69}}},
        },
        [180746] = { -- Gently Shaken Gift
            [objectKeys.spawns] = {[zoneIDs.IRONFORGE] = {{33.46,65.57}}},
        },
        [180747] = { -- Gaily Wrapped Present
            [objectKeys.spawns] = {[zoneIDs.IRONFORGE] = {{33.78,66.4}}},
        },
        [180748] = { -- Ticking Present
            [objectKeys.spawns] = {[zoneIDs.IRONFORGE] = {{33.9,66.68}}},
        },
        [180793] = { -- Festive Gift
            [objectKeys.spawns] = {[zoneIDs.IRONFORGE] = {{33.96,65.86}}},
        },
        [186189] = { -- Complimentary Brewfest Sampler
            [objectKeys.spawns] = {[zoneIDs.DUN_MOROGH] = {{54.03,38.92},{54.03,38.95},{54.17,38.31},{54.67,37.93},{54.8,37.9},{54.69,37.94},{55.32,37.26},{55.3,37.28},{55.7,38.16},{55.67,38.17},{56.53,36.68},{55.63,36.48},{55.65,36.48},{56.26,37.94},{56.26,37.97},{55.9,36.43},{55.9,36.4},{56.29,37.96},{59.79,33.5},{59.77,33.51}}},
        },
        [186234] = { -- Water Barrel
            [objectKeys.spawns] = {
                [zoneIDs.ELWYNN_FOREST] = {{42.5,64.49},{42.73,62.01}},
                [zoneIDs.DUN_MOROGH] = {{53.41,51.53},{53.52,55.45}},
                [zoneIDs.AZUREMYST_ISLE] = {{49.24,51.28},{43.67,51.56}},
            },
        },
        [186887] = { -- Large Jack-o'-Lantern
            [objectKeys.spawns] = {
                [zoneIDs.ELWYNN_FOREST] = {{42.5,65.8}},
                [zoneIDs.DUN_MOROGH] = {{53.53,52.09}},
                [zoneIDs.AZUREMYST_ISLE] = {{48.99,51.02}},
            },
        },
        [187236] = { -- Winter Veil Gift
            [objectKeys.spawns] = {[zoneIDs.IRONFORGE] = {{33.71,65.85}}},
        },
        [195122] = { -- Forsaken Stink Bomb Cloud
            [objectKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{71.9,73.37},{72.97,66.13},{73.77,59.68},{73.62,52.32},{71.2,46.14},{65.58,40.17},{61.68,30.26},{62.75,33.49},{58.73,36.76},{55.11,44.8},{55.47,48.75},{58.21,53.72},{54.01,54.66},{50.43,52.9},{46.47,53.99},{48.12,62.84},{48.34,67.39},{50.01,71.56},{53.45,71.01},{57.88,68.15},{60.17,71.63},{62.18,73.99},{65.23,75.58},{67.4,79.36}}},
        },
        [203461] = { -- Fuel Sampling Station
            [objectKeys.spawns] = {[zoneIDs.ABYSSAL_DEPTHS] = {{55.8,72.44}}},
        },
        [207125] = { -- Crate of Left Over Supplies
            [objectKeys.spawns] = {[zoneIDs.BURNING_STEPPES] = {{73.73,67.34}}},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return objectFixesHorde
    else
        return objectFixesAlliance
    end
end
