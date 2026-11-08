---@class MopObjectFixes
local MopObjectFixes = QuestieLoader:CreateModule("MopObjectFixes")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

function MopObjectFixes.Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

function MopObjectFixes:LoadFactionFixes()
    local objectKeys = QuestieDB.objectKeys
    local zoneIDs = ZoneDB.zoneIDs

    local objectFixesHorde = {
        [209621] = { -- Sniper Rifle
            [objectKeys.spawns] = {[zoneIDs.THE_JADE_FOREST] = {{62.56, 82.14}}},
            [objectKeys.zoneID] = zoneIDs.THE_JADE_FOREST,
        },
    }

    local objectFixesAlliance = {
        [209621] = { -- Sniper Rifle
            [objectKeys.spawns] = {[zoneIDs.THE_JADE_FOREST] = {{28.59, 54.42}}},
            [objectKeys.zoneID] = zoneIDs.THE_JADE_FOREST,
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return objectFixesHorde
    else
        return objectFixesAlliance
    end
end
