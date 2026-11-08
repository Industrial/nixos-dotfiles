---@class ForeverObjectFixes
local ForeverObjectFixes = QuestieLoader:CreateModule("ForeverObjectFixes")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

-- Static Corrections: shared by all characters and folded in during Generation.
function ForeverObjectFixes:Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

-- Dynamic Corrections: selected from character/game facts such as faction, race or class.
-- These override legacy Dynamic Corrections and all Static Corrections at query time.
function ForeverObjectFixes:LoadDynamic()
    local objectKeys = QuestieDB.objectKeys
    local zoneIDs = ZoneDB.zoneIDs

    return {
        -- [objectId] = { [objectKeys.name] = "Character-specific name" },
    }
end
