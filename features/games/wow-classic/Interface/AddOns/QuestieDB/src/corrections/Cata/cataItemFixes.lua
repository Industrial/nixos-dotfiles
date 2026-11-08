---@class CataItemFixes
local CataItemFixes = QuestieLoader:CreateModule("CataItemFixes")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

function CataItemFixes.Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

-- This should allow manual fix for item availability
function CataItemFixes:LoadFactionFixes()
    local itemKeys = QuestieDB.itemKeys

    local itemFixesHorde = {
        [17662] = { -- Stolen Treats
            [itemKeys.objectDrops] = {209506},
        },
        [56188] = { -- Rescue Flare
            [itemKeys.objectDrops] = {203410},
        },
        [71034] = { -- Windswept Balloon
            [itemKeys.objectDrops] = {209058},
        },
    }

    local itemFixesAlliance = {
        [17662] = { -- Stolen Treats
            [itemKeys.objectDrops] = {209497},
        },
        [56188] = { -- Rescue Flare
            [itemKeys.objectDrops] = {203403},
        },
        [71034] = { -- Windswept Balloon
            [itemKeys.objectDrops] = {209242},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return itemFixesHorde
    else
        return itemFixesAlliance
    end
end
