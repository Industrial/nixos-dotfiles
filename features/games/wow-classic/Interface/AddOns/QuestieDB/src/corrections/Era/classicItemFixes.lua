---@class QuestieItemFixes
local QuestieItemFixes = QuestieLoader:CreateModule("QuestieItemFixes")
-------------------------
--Import modules.
-------------------------
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB");

-- Further information on how to use this can be found at the wiki
-- https://github.com/Questie/Questie/wiki/Corrections

function QuestieItemFixes:Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

-- some quest items are shared across factions but require different sources for each faction
function QuestieItemFixes:LoadFactionFixes()
    local itemKeys = QuestieDB.itemKeys

    local itemFixesHorde = {
        [3713] = { -- Soothing Spices
            [itemKeys.relatedQuests] = {7321, 1218},
            [itemKeys.npcDrops] = {2397, 8307},
            [itemKeys.objectDrops] = {},
        },
        [15882] = { -- Half Pendant of Aquatic Endurance
            [itemKeys.objectDrops] = {177844},
        },
        [15883] = { -- Half Pendant of Aquatic Agility
            [itemKeys.objectDrops] = {177794},
        },
        [17126] = { -- Elegant Letter
            [itemKeys.npcDrops] = {3327,3328,3401,4582,4583,4584},
        },
        [20810] = { -- Signed Field Duty Papers
            [itemKeys.npcDrops] = {15612},
        },
    }

    local itemFixesAlliance = {
        [3713] = { -- Soothing Spices
            [itemKeys.name] = "Soothing Spices",
            [itemKeys.relatedQuests] = {555, 1218},
            [itemKeys.npcDrops] = {2381, 4897},
            [itemKeys.objectDrops] = {},
        },
        [15882] = { -- Half Pendant of Aquatic Endurance
            [itemKeys.objectDrops] = {177790},
        },
        [15883] = { -- Half Pendant of Aquatic Agility
            [itemKeys.objectDrops] = {177792},
        },
        [17126] = { -- Elegant Letter
            [itemKeys.npcDrops] = {332,918,4163,4214,4215,5165,5166,5167},
        },
        [20810] = { -- Signed Field Duty Papers
            [itemKeys.npcDrops] = {15440},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return itemFixesHorde
    else
        return itemFixesAlliance
    end
end
