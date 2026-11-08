---@class QuestieObjectFixes
local QuestieObjectFixes = QuestieLoader:CreateModule("QuestieObjectFixes")
-------------------------
--Import modules.
-------------------------
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

-- Further information on how to use this can be found at the wiki
-- https://github.com/Questie/Questie/wiki/Corrections

function QuestieObjectFixes:Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

-- some objects are shared across factions but require different sources for each faction
function QuestieObjectFixes:LoadFactionFixes()
    local objectKeys = QuestieDB.objectKeys
    local zoneIDs = ZoneDB.zoneIDs

    local objectFixesHorde = {
        [103574] = { -- Filled Containment Coffer
            [objectKeys.spawns] = {[zoneIDs.UNDERCITY] = {{53.29,74.56},{53.67,76.81},{52.01,75.96},{53.2,71.44}}},
            [objectKeys.zoneID] = zoneIDs.UNDERCITY,
        },
        [105174] = { -- Chest of Containment Coffers
            [objectKeys.spawns] = {[zoneIDs.UNDERCITY] = {{85.67,9.91},{85.53,10.03},{85.48,9.9},{85.58,9.95}}},
        },
        [105175] = { -- Cantation of Manifestation
            [objectKeys.spawns] = {[zoneIDs.UNDERCITY] = {{85.78,10.05},{85.7,10.11},{85.65,10.18}}},
        },
        [177525] = { -- Moonkin Stone
            [objectKeys.spawns] = {[zoneIDs.THE_BARRENS] = {{41.96,60.81}}},
            [objectKeys.zoneID] = zoneIDs.THE_BARRENS,
        },
        [180743] = { -- Carefully Wrapped Present
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{52.39,69.52}}},
        },
        [180746] = { -- Gently Shaken Gift
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{52.33,69.42}}},
        },
        [180747] = { -- Gaily Wrapped Present
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{52.3,69.18}}},
        },
        [180748] = { -- Ticking Present
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{52.28,69.29}}},
        },
        [180793] = { -- Festive Gift
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{52.42,69.32}}},
        },
    }

    local objectFixesAlliance = {
        [103574] = { -- Filled Containment Coffer
            [objectKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{40.87,89.04},{40.75,92.13},{41.27,90.54},{40.26,88.13},{40.89,87.75},{40.47,91.94}}},
            [objectKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [105174] = { -- Chest of Containment Coffers
            [objectKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{38.48,78.89},{38.55,79.04},{38.54,78.97},{38.62,79.02}}},
        },
        [105175] = { -- Cantation of Manifestation
            [objectKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{38.68,78.73},{38.69,78.81},{38.73,78.84}}},
        },
        [177525] = { -- Moonkin Stone
            [objectKeys.spawns] = {[zoneIDs.DARKSHORE] = {{43.5,45.97}}},
            [objectKeys.zoneID] = zoneIDs.DARKSHORE,
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
    }

    if UnitFactionGroup("Player") == "Horde" then
        return objectFixesHorde
    else
        return objectFixesAlliance
    end
end
