---@class QuestieWotlkObjectFixes
local QuestieWotlkObjectFixes = QuestieLoader:CreateModule("QuestieWotlkObjectFixes")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

function QuestieWotlkObjectFixes:Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

-- This should allow manual fix for object availability
function QuestieWotlkObjectFixes:LoadFactionFixes()
    local objectKeys = QuestieDB.objectKeys
    local zoneIDs = ZoneDB.zoneIDs

    local objectFixesHorde = {
        [201873] = { -- Gunship Armory
            [objectKeys.spawns] = {[zoneIDs.ICECROWN_CITADEL_RAMPART_OF_SKULLS] = {{47.9,77.3}},[zoneIDs.ICECROWN_CITADEL] = {{-1,-1}}},
        },
    }

    local objectFixesAlliance = {
        [103574] = { -- Filled Containment Coffer
            [objectKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{51.32,92.34},{50.83,92.63},{51.61,94.5},{51.21,95.73},{50.99,95.58},{51.3,93.34}}},
            [objectKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [105174] = { -- Chest of Containment Coffers
            [objectKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{49.45,85.48},{49.51,85.6},{49.5,85.55},{49.56,85.58}}},
        },
        [105175] = { -- Cantation of Manifestation
            [objectKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{49.64,85.44},{49.6,85.36},{49.61,85.42}}},
        },
        [201873] = { -- Gunship Armory
            [objectKeys.spawns] = {[zoneIDs.ICECROWN_CITADEL_RAMPART_OF_SKULLS] = {{42.55,76.8}},[zoneIDs.ICECROWN_CITADEL] = {{-1,-1}}},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return objectFixesHorde
    else
        return objectFixesAlliance
    end
end
