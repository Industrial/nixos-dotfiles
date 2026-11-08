---@class QuestieNPCFixes
local QuestieNPCFixes = QuestieLoader:CreateModule("QuestieNPCFixes")
-------------------------
--Import modules.
-------------------------
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type Phasing
local Phasing = QuestieLoader:ImportModule("Phasing")

-- Further information on how to use this can be found at the wiki
-- https://github.com/Questie/Questie/wiki/Corrections

function QuestieNPCFixes:Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

-- some quest items are shared across factions but require different sources for each faction (not sure if there is a better way to implement this)
function QuestieNPCFixes:LoadFactionFixes()
    local npcKeys = QuestieDB.npcKeys
    local zoneIDs = ZoneDB.zoneIDs

    local npcFixesHorde = {
        [5676] = { -- Summoned Voidwalker
            [npcKeys.spawns] = {
                [zoneIDs.UNDERCITY] = {{86.62,27.05}},
                [zoneIDs.ORGRIMMAR] = {{49.43,50.04}},
            },
            [npcKeys.zoneID] = zoneIDs.ORGRIMMAR,
        },
        [5677] = { -- Summoned Succubus
            [npcKeys.spawns] = {
                [zoneIDs.UNDERCITY] = {{86.62,27.05}},
                [zoneIDs.ORGRIMMAR] = {{49.43,50.04}},
            },
            [npcKeys.zoneID] = zoneIDs.ORGRIMMAR,
        },
        [6492] = { -- Rift Spawn
            [npcKeys.spawns] = {[zoneIDs.UNDERCITY] = {{53.29,74.56},{53.67,76.81},{52.01,75.96},{53.2,71.44}}},
            [npcKeys.zoneID] = zoneIDs.UNDERCITY,
        },
        [12138] = { -- Lunaclaw
            [npcKeys.spawns] = {[zoneIDs.THE_BARRENS] = {{41.96,60.79}}},
            [npcKeys.zoneID] = zoneIDs.THE_BARRENS,
        },
        [12144] = { -- Lunaclaw Spirit
            [npcKeys.spawns] = {[zoneIDs.THE_BARRENS] = {{41.96,60.79}}},
            [npcKeys.zoneID] = zoneIDs.THE_BARRENS,
        },
        [13778] = { -- PvP Tower Credit Marker
            [npcKeys.spawns] = {[zoneIDs.ALTERAC_VALLEY] = {{52.8,44},{50.8,30.8},{45.2,14.6},{44,18.1}}},
            [npcKeys.zoneID] = zoneIDs.ALTERAC_VALLEY,
        },
        [15898] = { -- Lunar Festival Vendor
            [npcKeys.spawns] = {
                [zoneIDs.ORGRIMMAR] = {{41.27,32.36}},
                [zoneIDs.THUNDER_BLUFF] = {{70.56,27.83}},
                [zoneIDs.UNDERCITY] = {{66.45,36.02}},
                [zoneIDs.MOONGLADE] = {{36.58,58.1},{36.3,58.53}},
            },
        },
        [16788] = { -- Festival Flamekeeper
            [npcKeys.spawns] = {
                [zoneIDs.ORGRIMMAR] = {{42.61,34.21}},
                [zoneIDs.UNDERCITY] = {{65.6,35.99}},
                [zoneIDs.THUNDER_BLUFF] = {{21.55,26.18}},
            },
            [npcKeys.zoneID] = zoneIDs.ORGRIMMAR,
        },
        [185335] = { -- Summoned Incubus
            [npcKeys.spawns] = {
                [zoneIDs.UNDERCITY] = {{86.62,27.05}},
                [zoneIDs.ORGRIMMAR] = {{49.43,50.04}},
            },
            [npcKeys.zoneID] = zoneIDs.ORGRIMMAR,
        },
    }

    local npcFixesAlliance = {
        [5676] = { -- Summoned Voidwalker
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{25.09,77.45}}},
            [npcKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [5677] = { -- Summoned Succubus
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{25.09,77.45}}},
            [npcKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [6492] = { -- Rift Spawn
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{40.87,89.04},{40.75,92.13},{41.27,90.54},{40.26,88.13},{40.89,87.75},{40.47,91.94}}},
            [npcKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [12138] = { -- Lunaclaw
            [npcKeys.spawns] = {[zoneIDs.DARKSHORE] = {{43.33,45.85}}},
            [npcKeys.zoneID] = zoneIDs.DARKSHORE,
        },
        [12144] = { -- Lunaclaw Spirit
            [npcKeys.spawns] = {[zoneIDs.DARKSHORE] = {{43.33,45.85}}},
            [npcKeys.zoneID] = zoneIDs.DARKSHORE,
        },
        [13778] = { -- PvP Tower Credit Marker
            [npcKeys.spawns] = {[zoneIDs.ALTERAC_VALLEY] = {{48.5,58.3},{50.2,65.3},{49.3,84.4},{48.3,84.3}}},
            [npcKeys.zoneID] = zoneIDs.ALTERAC_VALLEY,
        },
        [15898] = { -- Lunar Festival Vendor
            [npcKeys.spawns] = {
                [zoneIDs.STORMWIND_CITY] = {{22.78,51.19}},
                [zoneIDs.IRONFORGE] = {{29.92,14.21}},
                [zoneIDs.MOONGLADE] = {{36.58,58.1},{36.3,58.53}},
                [zoneIDs.DARNASSUS] = {{31.56,13.69}},
            },
            [npcKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [16788] = { -- Festival Flamekeeper
            [npcKeys.spawns] = {
                [zoneIDs.TELDRASSIL] = {{56.56,91.94}},
                [zoneIDs.STORMWIND_CITY] = {{38.4,61.29}},
                [zoneIDs.IRONFORGE] = {{63.54,24.67}},
            },
            [npcKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [185335] = { -- Summoned Incubus
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{25.09,77.45}}},
            [npcKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return npcFixesHorde
    else
        return npcFixesAlliance
    end
end