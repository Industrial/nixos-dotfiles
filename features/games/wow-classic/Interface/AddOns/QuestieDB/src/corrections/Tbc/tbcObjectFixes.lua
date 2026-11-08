---@class QuestieTBCObjectFixes
local QuestieTBCObjectFixes = QuestieLoader:CreateModule("QuestieTBCObjectFixes")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

function QuestieTBCObjectFixes:Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

-- This should allow manual fix for object availability
function QuestieTBCObjectFixes:LoadFactionFixes()
    local objectKeys = QuestieDB.objectKeys
    local zoneIDs = ZoneDB.zoneIDs

    local objectFixesHorde = {
        [186189] = { -- Complimentary Brewfest Sampler
            [objectKeys.spawns] = {[zoneIDs.DUROTAR] = {{45.27,13.53},{45.27,13.54},{45.28,13.55},{45.26,13.53},{45.08,16.66},{45.08,16.68},{45.1,16.68},{45.1,16.65},{45.27,13.53},{45.28,17.47},{45.28,17.45},{44.86,17.42},{44.87,17.41},{45.16,17.52},{45.19,17.51},{45.17,17.49},{45.18,17.48},{45.26,17.46},{45.27,17.48},{44.85,17.4},{44.87,17.43},{44.53,16.53},{44.52,16.56},{44.51,16.53},{44.53,16.56},{43.97,17.98},{44.22,18.01},{43.96,17.98},{44.21,17.99},{43.61,17.3},{43.62,17.32},{43.61,17.28},{43.96,17.94},{43.63,17.3},{44.19,18.01},{44.2,18.0},{43.98,17.95},{43.86,16.83},{43.84,16.84},{43.85,16.8},{43.83,16.82},{43.63,17.3}}},
            [objectKeys.zoneID] = zoneIDs.DUROTAR,
        },
        [186887] = { -- Large Jack-o'-Lantern
            [objectKeys.spawns] = {
                [zoneIDs.DUROTAR] = {{52.6,42.5}},
                [zoneIDs.TIRISFAL_GLADES] = {{60.9,52.7}},
                [zoneIDs.EVERSONG_WOODS] = {{47.58,46.24}},
            },
        },
        [187236] = { -- Winter Veil Gift
            [objectKeys.spawns] = {
                [zoneIDs.ORGRIMMAR] = {{52.43,69.27}},
            },
        },
    }

    local objectFixesAlliance = {
        [186189] = { -- Complimentary Brewfest Sampler
            [objectKeys.spawns] = {[zoneIDs.DUN_MOROGH] = {{46.92,40.66},{46.92,40.69},{46.94,40.65},{47.06,40.06},{47.07,40.08},{47.56,39.68},{47.56,39.66},{47.68,39.65},{47.57,39.66},{47.67,39.66},{47.69,39.66},{47.58,39.69},{47.68,39.67},{47.58,39.67},{47.67,39.65},{48.2,39.01},{48.18,39.03},{47.57,39.66},{48.2,39.05},{47.58,39.69},{47.58,39.67},{47.69,39.66},{47.56,39.66},{48.2,39.05},{47.68,39.67},{48.2,39.03},{47.58,39.69},{48.58,39.91},{48.56,39.92},{48.57,39.91},{49.41,38.44},{49.39,38.45},{48.51,38.24},{48.53,38.24},{49.14,39.69},{49.41,38.47},{49.14,39.72},{49.16,39.68},{48.78,38.19},{48.79,38.16},{48.77,38.16},{49.4,38.48},{49.17,39.71},{48.79,38.18},{48.55,38.25},{47.68,39.67},{48.57,39.91},{46.94,40.65},{48.2,39.03},{48.77,38.16},{48.18,39.03},{48.2,39.05},{48.21,39.04},{49.4,38.48},{48.18,39.03},{47.58,39.69},{48.2,39.03},{47.58,39.67},{47.56,39.68},{48.2,39.05},{48.21,39.04},{49.16,39.68},{52.65,35.28},{52.63,35.29}}},
            [objectKeys.zoneID] = zoneIDs.DUN_MOROGH,
        },
        [186887] = { -- Large Jack-o'-Lantern
            [objectKeys.spawns] = {
                [zoneIDs.ELWYNN_FOREST] = {{42.5,65.8}},
                [zoneIDs.DUN_MOROGH] = {{46.4,52.2}},
                [zoneIDs.AZUREMYST_ISLE] = {{48.99,51.02}},
            },
        },
        [187236] = { -- Winter Veil Gift
            [objectKeys.spawns] = {
                [zoneIDs.IRONFORGE] = {{33.71,65.85}},
            },
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return objectFixesHorde
    else
        return objectFixesAlliance
    end
end
