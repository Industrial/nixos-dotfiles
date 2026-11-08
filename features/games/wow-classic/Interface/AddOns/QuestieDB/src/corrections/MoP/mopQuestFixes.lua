---@class MopQuestFixes
local MopQuestFixes = QuestieLoader:CreateModule("MopQuestFixes")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type QuestieProfessions
local QuestieProfessions = QuestieLoader:ImportModule("QuestieProfessions")
---@type QuestieCorrections
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

QuestieCorrections.spellObjectiveFirst[10068] = true
QuestieCorrections.spellObjectiveFirst[10069] = true
QuestieCorrections.spellObjectiveFirst[10070] = true
QuestieCorrections.spellObjectiveFirst[10071] = true
QuestieCorrections.spellObjectiveFirst[10072] = true
QuestieCorrections.spellObjectiveFirst[10073] = true
QuestieCorrections.spellObjectiveFirst[14007] = true
QuestieCorrections.spellObjectiveFirst[14008] = true
QuestieCorrections.spellObjectiveFirst[14010] = true
QuestieCorrections.spellObjectiveFirst[14011] = true
QuestieCorrections.spellObjectiveFirst[14012] = true
QuestieCorrections.spellObjectiveFirst[14013] = true
QuestieCorrections.spellObjectiveFirst[14266] = true
QuestieCorrections.spellObjectiveFirst[14272] = true
QuestieCorrections.spellObjectiveFirst[14274] = true
QuestieCorrections.spellObjectiveFirst[14276] = true
QuestieCorrections.spellObjectiveFirst[14279] = true
QuestieCorrections.spellObjectiveFirst[14281] = true
QuestieCorrections.spellObjectiveFirst[14283] = true
QuestieCorrections.spellObjectiveFirst[24526] = true
QuestieCorrections.spellObjectiveFirst[24527] = true
QuestieCorrections.spellObjectiveFirst[24528] = true
QuestieCorrections.spellObjectiveFirst[24530] = true
QuestieCorrections.spellObjectiveFirst[24531] = true
QuestieCorrections.spellObjectiveFirst[24532] = true
QuestieCorrections.spellObjectiveFirst[24533] = true
QuestieCorrections.spellObjectiveFirst[24640] = true
QuestieCorrections.spellObjectiveFirst[24752] = true
QuestieCorrections.spellObjectiveFirst[24760] = true
QuestieCorrections.spellObjectiveFirst[24766] = true
QuestieCorrections.spellObjectiveFirst[24772] = true
QuestieCorrections.spellObjectiveFirst[24784] = true
QuestieCorrections.spellObjectiveFirst[24964] = true
QuestieCorrections.spellObjectiveFirst[24965] = true
QuestieCorrections.spellObjectiveFirst[24966] = true
QuestieCorrections.spellObjectiveFirst[24967] = true
QuestieCorrections.spellObjectiveFirst[24968] = true
QuestieCorrections.spellObjectiveFirst[24969] = true
QuestieCorrections.spellObjectiveFirst[25139] = true
QuestieCorrections.spellObjectiveFirst[25141] = true
QuestieCorrections.spellObjectiveFirst[25143] = true
QuestieCorrections.spellObjectiveFirst[25145] = true
QuestieCorrections.spellObjectiveFirst[25147] = true
QuestieCorrections.spellObjectiveFirst[25149] = true
QuestieCorrections.spellObjectiveFirst[26198] = true
QuestieCorrections.spellObjectiveFirst[26200] = true
QuestieCorrections.spellObjectiveFirst[26201] = true
QuestieCorrections.spellObjectiveFirst[26204] = true
QuestieCorrections.spellObjectiveFirst[26207] = true
QuestieCorrections.spellObjectiveFirst[26274] = true
QuestieCorrections.spellObjectiveFirst[26904] = true
QuestieCorrections.spellObjectiveFirst[26913] = true
QuestieCorrections.spellObjectiveFirst[26914] = true
QuestieCorrections.spellObjectiveFirst[26915] = true
QuestieCorrections.spellObjectiveFirst[26916] = true
QuestieCorrections.spellObjectiveFirst[26918] = true
QuestieCorrections.spellObjectiveFirst[26919] = true
QuestieCorrections.spellObjectiveFirst[26940] = true
QuestieCorrections.spellObjectiveFirst[26945] = true
QuestieCorrections.spellObjectiveFirst[26946] = true
QuestieCorrections.spellObjectiveFirst[26947] = true
QuestieCorrections.spellObjectiveFirst[26948] = true
QuestieCorrections.spellObjectiveFirst[26949] = true
QuestieCorrections.spellObjectiveFirst[26958] = true
QuestieCorrections.spellObjectiveFirst[26963] = true
QuestieCorrections.spellObjectiveFirst[26966] = true
QuestieCorrections.spellObjectiveFirst[26968] = true
QuestieCorrections.spellObjectiveFirst[26969] = true
QuestieCorrections.spellObjectiveFirst[26970] = true
QuestieCorrections.spellObjectiveFirst[27020] = true
QuestieCorrections.spellObjectiveFirst[27021] = true
QuestieCorrections.spellObjectiveFirst[27023] = true
QuestieCorrections.spellObjectiveFirst[27027] = true
QuestieCorrections.spellObjectiveFirst[27066] = true
QuestieCorrections.spellObjectiveFirst[27067] = true
QuestieCorrections.spellObjectiveFirst[27091] = true
QuestieCorrections.killCreditObjectiveFirst[29555] = true
QuestieCorrections.killCreditObjectiveFirst[29578] = true
QuestieCorrections.objectObjectiveFirst[29628] = true
QuestieCorrections.objectObjectiveFirst[29726] = true
QuestieCorrections.objectObjectiveFirst[29730] = true
QuestieCorrections.itemObjectiveFirst[29749] = true
QuestieCorrections.objectObjectiveFirst[30325] = true
QuestieCorrections.killCreditObjectiveFirst[30457] = true
QuestieCorrections.killCreditObjectiveFirst[30466] = true
QuestieCorrections.killCreditObjectiveFirst[30527] = true
QuestieCorrections.itemObjectiveFirst[30607] = true
QuestieCorrections.itemObjectiveFirst[30800] = true
QuestieCorrections.objectObjectiveFirst[30932] = true
QuestieCorrections.killCreditObjectiveFirst[31019] = true
QuestieCorrections.spellObjectiveFirst[31138] = true
QuestieCorrections.spellObjectiveFirst[31142] = true
QuestieCorrections.spellObjectiveFirst[31147] = true
QuestieCorrections.spellObjectiveFirst[31151] = true
QuestieCorrections.spellObjectiveFirst[31157] = true
QuestieCorrections.spellObjectiveFirst[31162] = true
QuestieCorrections.spellObjectiveFirst[31166] = true
QuestieCorrections.spellObjectiveFirst[31169] = true
QuestieCorrections.spellObjectiveFirst[31171] = true
QuestieCorrections.spellObjectiveFirst[31173] = true
QuestieCorrections.spellObjectiveFirst[31467] = true
QuestieCorrections.spellObjectiveFirst[31471] = true
QuestieCorrections.spellObjectiveFirst[31474] = true
QuestieCorrections.spellObjectiveFirst[31476] = true
QuestieCorrections.spellObjectiveFirst[31477] = true
QuestieCorrections.spellObjectiveFirst[31480] = true
QuestieCorrections.killCreditObjectiveFirst[31945] = true
QuestieCorrections.killCreditObjectiveFirst[31946] = true
QuestieCorrections.killCreditObjectiveFirst[31947] = true
QuestieCorrections.killCreditObjectiveFirst[31949] = true
QuestieCorrections.killCreditObjectiveFirst[32247] = true
QuestieCorrections.killCreditObjectiveFirst[32250] = true
QuestieCorrections.killCreditObjectiveFirst[32282] = true
QuestieCorrections.objectObjectiveFirst[32333] = true
QuestieCorrections.killCreditObjectiveFirst[32551] = true
QuestieCorrections.killCreditObjectiveFirst[32643] = true
QuestieCorrections.killCreditObjectiveFirst[32646] = true
QuestieCorrections.killCreditObjectiveFirst[32648] = true
QuestieCorrections.killCreditObjectiveFirst[32650] = true
QuestieCorrections.killCreditObjectiveFirst[32657] = true
QuestieCorrections.killCreditObjectiveFirst[32659] = true
QuestieCorrections.itemObjectiveFirst[32809] = true
QuestieCorrections.killCreditObjectiveFirst[32943] = true
QuestieCorrections.killCreditObjectiveFirst[32945] = true
QuestieCorrections.objectObjectiveFirst[33228] = true

function MopQuestFixes.Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

function MopQuestFixes:LoadFactionFixes()
    local questKeys = QuestieDB.questKeys

    ---@format disable
    local questFixesHorde = {
        [30376] = { -- Hope Springs Eternal
            [questKeys.preQuestSingle] = {},
            [questKeys.preQuestGroup] = {30174,30273},
            [questKeys.exclusiveTo] = {30241},
        },
        [30632] = { -- The Ruins of Guo-Lai
            [questKeys.preQuestGroup] = {31511,30649},
        },
        [31695] = { -- Beyond The Wall
            [questKeys.preQuestGroup] = {30655,30656,30661},
        },
        [32428] = { -- Pandaren Spirit Tamer
            [questKeys.startedBy] = {{64582}},
            [questKeys.finishedBy] = {{64582}},
        },
        [32603] = { -- Beasts of Fable
            [questKeys.startedBy] = {{64582}},
            [questKeys.finishedBy] = {{64582}},
        },
        [32604] = { -- Beasts of Fable Book I
            [questKeys.startedBy] = {{64582}},
            [questKeys.finishedBy] = {{64582}},
        },
        [32836] = { -- A Knockoff Grumplefloot
            [questKeys.finishedBy] = {{70751}},
        },
        [32837] = { -- Grandpa Grumplefloot
            [questKeys.startedBy] = {{70751}},
            [questKeys.finishedBy] = {{70751}},
        },
        [32838] = { -- A Tale of Romance and Chivalry
            [questKeys.finishedBy] = {{70751}},
        },
        [32839] = { -- The Bear and the Lady Fair
            [questKeys.startedBy] = {{70751}},
            [questKeys.finishedBy] = {{70751}},
        },
        [32840] = { -- Boom Boom's Fuse
            [questKeys.finishedBy] = {{70751}},
        },
        [32841] = { -- Master Boom Boom
            [questKeys.startedBy] = {{70751}},
            [questKeys.finishedBy] = {{70751}},
        },
        [32842] = { -- Teeth Like Swords
            [questKeys.finishedBy] = {{70751}},
        },
        [32843] = { -- Razorgrin
            [questKeys.startedBy] = {{70751}},
            [questKeys.finishedBy] = {{70751}},
        },
        [32844] = { -- Secret of the Ooze
            [questKeys.finishedBy] = {{70751}},
        },
        [32845] = { -- Splat
            [questKeys.startedBy] = {{70751}},
            [questKeys.finishedBy] = {{70751}},
        },
        [32846] = { -- Modified Chomping Apparatus
            [questKeys.finishedBy] = {{70751}},
        },
        [32847] = { -- Mecha-Bruce
            [questKeys.startedBy] = {{70751}},
            [questKeys.finishedBy] = {{70751}},
        },
        [32848] = { -- Frost-Tipped Eggshell
            [questKeys.finishedBy] = {{70751}},
        },
        [32849] = { -- Dippy and Doopy
            [questKeys.startedBy] = {{70751}},
            [questKeys.finishedBy] = {{70751}},
        },
        [32850] = { -- Last Year's Model
            [questKeys.finishedBy] = {{70751}},
        },
        [32851] = { -- Blingtron 3000
            [questKeys.startedBy] = {{70751}},
            [questKeys.finishedBy] = {{70751}},
        },
        [32852] = { -- The Digmaster's Earthblade
            [questKeys.finishedBy] = {{70751}},
        },
        [32853] = { -- Mingus Diggs
            [questKeys.startedBy] = {{70751}},
            [questKeys.finishedBy] = {{70751}},
        },
        [32854] = { -- Well-Worn Blindfold
            [questKeys.finishedBy] = {{70751}},
        },
        [32855] = { -- The Blind Hero
            [questKeys.startedBy] = {{70751}},
            [questKeys.finishedBy] = {{70751}},
        },
        [32856] = { -- Paper-Covered Rock
            [questKeys.finishedBy] = {{70751}},
        },
        [32857] = { -- Ro-Shambo
            [questKeys.startedBy] = {{70751}},
            [questKeys.finishedBy] = {{70751}},
        },
        [32858] = { -- Raptorhide Boxing Gloves
            [questKeys.finishedBy] = {{70751}},
        },
        [32859] = { -- Ty'thar
            [questKeys.startedBy] = {{70751}},
            [questKeys.finishedBy] = {{70751}},
        },
        [32863] = { -- What We've Been Training For
            [questKeys.startedBy] = {{63626,64582}},
            [questKeys.finishedBy] = {{63626,64582}},
        },
        [32868] = { -- Beasts of Fable Book II
            [questKeys.startedBy] = {{64582}},
            [questKeys.finishedBy] = {{64582}},
        },
        [32869] = { -- Beasts of Fable Book III
            [questKeys.startedBy] = {{64582}},
            [questKeys.finishedBy] = {{64582}},
        },
    }

    ---@format disable
    local questFixesAlliance = {
        [30376] = { -- Hope Springs Eternal
            [questKeys.preQuestSingle] = {},
            [questKeys.preQuestGroup] = {30273,30445},
            [questKeys.exclusiveTo] = {30360},
        },
        [30632] = { -- The Ruins of Guo-Lai
            [questKeys.preQuestGroup] = {31512,30631},
        },
        [31695] = { -- Beyond The Wall
            [questKeys.preQuestGroup] = {30650,30651,30660},
        },
        [32428] = { -- Pandaren Spirit Tamer
            [questKeys.startedBy] = {{64572}},
            [questKeys.finishedBy] = {{64572}},
        },
        [32603] = { -- Beasts of Fable
            [questKeys.startedBy] = {{64572}},
            [questKeys.finishedBy] = {{64572}},
        },
        [32604] = { -- Beasts of Fable Book I
            [questKeys.startedBy] = {{64572}},
            [questKeys.finishedBy] = {{64572}},
        },
        [32836] = { -- A Knockoff Grumplefloot
            [questKeys.finishedBy] = {{70752}},
        },
        [32837] = { -- Grandpa Grumplefloot
            [questKeys.startedBy] = {{70752}},
            [questKeys.finishedBy] = {{70752}},
        },
        [32838] = { -- A Tale of Romance and Chivalry
            [questKeys.finishedBy] = {{70752}},
        },
        [32839] = { -- The Bear and the Lady Fair
            [questKeys.startedBy] = {{70752}},
            [questKeys.finishedBy] = {{70752}},
        },
        [32840] = { -- Boom Boom's Fuse
            [questKeys.finishedBy] = {{70752}},
        },
        [32841] = { -- Master Boom Boom
            [questKeys.startedBy] = {{70752}},
            [questKeys.finishedBy] = {{70752}},
        },
        [32842] = { -- Teeth Like Swords
            [questKeys.finishedBy] = {{70752}},
        },
        [32843] = { -- Razorgrin
            [questKeys.startedBy] = {{70752}},
            [questKeys.finishedBy] = {{70752}},
        },
        [32844] = { -- Secret of the Ooze
            [questKeys.finishedBy] = {{70752}},
        },
        [32845] = { -- Splat
            [questKeys.startedBy] = {{70752}},
            [questKeys.finishedBy] = {{70752}},
        },
        [32846] = { -- Modified Chomping Apparatus
            [questKeys.finishedBy] = {{70752}},
        },
        [32847] = { -- Mecha-Bruce
            [questKeys.startedBy] = {{70752}},
            [questKeys.finishedBy] = {{70752}},
        },
        [32848] = { -- Frost-Tipped Eggshell
            [questKeys.finishedBy] = {{70752}},
        },
        [32849] = { -- Dippy and Doopy
            [questKeys.startedBy] = {{70752}},
            [questKeys.finishedBy] = {{70752}},
        },
        [32850] = { -- Last Year's Model
            [questKeys.finishedBy] = {{70752}},
        },
        [32851] = { -- Blingtron 3000
            [questKeys.startedBy] = {{70752}},
            [questKeys.finishedBy] = {{70752}},
        },
        [32852] = { -- The Digmaster's Earthblade
            [questKeys.finishedBy] = {{70752}},
        },
        [32853] = { -- Mingus Diggs
            [questKeys.startedBy] = {{70752}},
            [questKeys.finishedBy] = {{70752}},
        },
        [32854] = { -- Well-Worn Blindfold
            [questKeys.finishedBy] = {{70752}},
        },
        [32855] = { -- The Blind Hero
            [questKeys.startedBy] = {{70752}},
            [questKeys.finishedBy] = {{70752}},
        },
        [32856] = { -- Paper-Covered Rock
            [questKeys.finishedBy] = {{70752}},
        },
        [32857] = { -- Ro-Shambo
            [questKeys.startedBy] = {{70752}},
            [questKeys.finishedBy] = {{70752}},
        },
        [32858] = { -- Raptorhide Boxing Gloves
            [questKeys.finishedBy] = {{70752}},
        },
        [32859] = { -- Ty'thar
            [questKeys.startedBy] = {{70752}},
            [questKeys.finishedBy] = {{70752}},
        },
        [32863] = { -- What We've Been Training For
            [questKeys.startedBy] = {{63596,64572}},
            [questKeys.finishedBy] = {{63596,64572}},
        },
        [32868] = { -- Beasts of Fable Book II
            [questKeys.startedBy] = {{64572}},
            [questKeys.finishedBy] = {{64572}},
        },
        [32869] = { -- Beasts of Fable Book III
            [questKeys.startedBy] = {{64572}},
            [questKeys.finishedBy] = {{64572}},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return questFixesHorde
    else
        return questFixesAlliance
    end
end
