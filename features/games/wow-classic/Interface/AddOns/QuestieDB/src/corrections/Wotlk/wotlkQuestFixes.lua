---@class QuestieWotlkQuestFixes
local QuestieWotlkQuestFixes = QuestieLoader:CreateModule("QuestieWotlkQuestFixes")
local _QuestieWotlkQuestFixes = {}

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


QuestieCorrections.killCreditObjectiveFirst[11652] = true
QuestieCorrections.killCreditObjectiveFirst[12100] = true
QuestieCorrections.killCreditObjectiveFirst[12546] = true
QuestieCorrections.killCreditObjectiveFirst[12561] = true
QuestieCorrections.killCreditObjectiveFirst[12762] = true
QuestieCorrections.killCreditObjectiveFirst[12779] = true
QuestieCorrections.killCreditObjectiveFirst[12919] = true
QuestieCorrections.killCreditObjectiveFirst[13086] = true
QuestieCorrections.killCreditObjectiveFirst[13373] = true
QuestieCorrections.killCreditObjectiveFirst[13376] = true
QuestieCorrections.killCreditObjectiveFirst[13380] = true
QuestieCorrections.killCreditObjectiveFirst[13382] = true
QuestieCorrections.killCreditObjectiveFirst[13404] = true
QuestieCorrections.killCreditObjectiveFirst[13406] = true
QuestieCorrections.killCreditObjectiveFirst[24498] = true
QuestieCorrections.killCreditObjectiveFirst[24507] = true

function QuestieWotlkQuestFixes:Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

function QuestieWotlkQuestFixes:LoadFactionFixes()
    local questKeys = QuestieDB.questKeys
    local factionIDs = QuestieDB.factionIDs

    local questFixesHorde = {
        [13012] = { -- Sardis the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13013] = { -- Beldak the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13014] = { -- Morthie the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13015] = { -- Fargal the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13016] = { -- Northal the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13017] = { -- Jarten the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13018] = { -- Sandrene the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13019] = { -- Thoim the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13020] = { -- Stonebeard the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13021] = { -- Igasho the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13022] = { -- Nurgen the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13023] = { -- Kilias the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13024] = { -- Wanikaya the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13025] = { -- Lunaro the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13026] = { -- Bluewolf the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13027] = { -- Tauros the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13028] = { -- Graymane the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13029] = { -- Pamuya the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13030] = { -- Whurain the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13031] = { -- Skywarden the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13032] = { -- Muraco the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13033] = { -- Arp the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13065] = { -- Ohanzee the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13066] = { -- Yurauk the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [13067] = { -- Chogan'gada the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
    }

    local questFixesAlliance = {
        [13012] = { -- Sardis the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13013] = { -- Beldak the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13014] = { -- Morthie the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13015] = { -- Fargal the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13016] = { -- Northal the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13017] = { -- Jarten the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13018] = { -- Sandrene the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13019] = { -- Thoim the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13020] = { -- Stonebeard the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13021] = { -- Igasho the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13022] = { -- Nurgen the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13023] = { -- Kilias the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13024] = { -- Wanikaya the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13025] = { -- Lunaro the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13026] = { -- Bluewolf the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13027] = { -- Tauros the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13028] = { -- Graymane the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13029] = { -- Pamuya the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13030] = { -- Whurain the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13031] = { -- Skywarden the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13032] = { -- Muraco the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13033] = { -- Arp the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13065] = { -- Ohanzee the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13066] = { -- Yurauk the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [13067] = { -- Chogan'gada the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return questFixesHorde
    else
        return questFixesAlliance
    end
end
