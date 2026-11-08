---@class QuestieTBCItemFixes
local QuestieTBCItemFixes = QuestieLoader:CreateModule("QuestieTBCItemFixes")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

function QuestieTBCItemFixes:Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

-- This should allow manual fix for item availability
function QuestieTBCItemFixes:LoadFactionFixes()
    local itemKeys = QuestieDB.itemKeys

    local itemFixesHorde = {
        [17126] = { -- Elegant Letter
            [itemKeys.npcDrops] = {3327,3328,3401,4582,4583,4584,15285,16279,16684,16685,16686},
        },
        [25911] = { -- Salvaged Wood
            [itemKeys.objectDrops] = {182936},
        },
        [25912] = { -- Salvaged Metal
            [itemKeys.objectDrops] = {182937, 182938},
        },
        [30712] = { -- The Doctor's Key
            [itemKeys.npcDrops] = {21779},
        },
        [30713] = { -- The Art of Fel Reaver Maintenance
            [itemKeys.objectDrops] = {185233},
        },
    }

    local itemFixesAlliance = {
        [17126] = { -- Elegant Letter
            [itemKeys.npcDrops] = {332,918,4163,4214,4215,5165,5166,5167},
        },
        [25911] = { -- Salvaged Wood
            [itemKeys.objectDrops] = {182799},
        },
        [25912] = { -- Salvaged Metal
            [itemKeys.objectDrops] = {182798, 182797},
        },
        [30712] = { -- The Doctor's Key
            [itemKeys.npcDrops] = {21778},
        },
        [30713] = { -- The Art of Fel Reaver Maintenance
            [itemKeys.objectDrops] = {184947},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return itemFixesHorde
    else
        return itemFixesAlliance
    end
end
