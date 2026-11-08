---@class QuestieWotlkItemFixes
local QuestieWotlkItemFixes = QuestieLoader:CreateModule("QuestieWotlkItemFixes")
local _QuestieWotlkItemFixes = {}

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

-- Further information on how to use this can be found at the wiki
-- https://github.com/Questie/Questie/wiki/Corrections

function QuestieWotlkItemFixes:Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

function _QuestieWotlkItemFixes:InsertMissingItemIds()
    -- Boost quest items
    QuestieDB.itemData[199335] = {} -- Teleport Scroll: Menethil Harbor
    QuestieDB.itemData[199336] = {} -- Teleport Scroll: Stormwind Harbor
    QuestieDB.itemData[199777] = {} -- Teleport Scroll: Orgrimmar Zeppelin Tower
    QuestieDB.itemData[199778] = {} -- Teleport Scroll: Undercity Zeppelin Tower
    QuestieDB.itemData[200068] = {} -- Teleport Scroll: Shattrath City
    QuestieDB.itemData[211206] = {} -- Defiler's Medallion
    QuestieDB.itemData[211207] = {} -- Mysterious Artifact
end

-- This should allow manual fix for item availability
function QuestieWotlkItemFixes:LoadFactionFixes()
    local itemKeys = QuestieDB.itemKeys

    local itemFixesHorde = {
        [49698] = { -- Ancient Dragonforged Blades
            [itemKeys.npcDrops] = {36669},
        },
    }

    local itemFixesAlliance = {
        [49698] = { -- Ancient Dragonforged Blades
            [itemKeys.npcDrops] = {36670},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return itemFixesHorde
    else
        return itemFixesAlliance
    end
end
