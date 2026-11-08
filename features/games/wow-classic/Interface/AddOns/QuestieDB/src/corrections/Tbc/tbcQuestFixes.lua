---@class QuestieTBCQuestFixes
local QuestieTBCQuestFixes = QuestieLoader:CreateModule("QuestieTBCQuestFixes")
local _QuestieTBCQuestFixes = {}

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ContentPhases
local ContentPhases = QuestieLoader:ImportModule("ContentPhases")
---@type Expansions
local Expansions = QuestieLoader:ImportModule("Expansions")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type QuestieProfessions
local QuestieProfessions = QuestieLoader:ImportModule("QuestieProfessions")
---@type QuestieCorrections
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")


QuestieCorrections.killCreditObjectiveFirst[10503] = true -- The Bladespire Threat


function QuestieTBCQuestFixes:Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

function QuestieTBCQuestFixes:LoadFactionFixes()
    local questKeys = QuestieDB.questKeys
    local raceIDs = QuestieDB.raceKeys
    local playerClass = UnitClassBase("player")
    local playerRace = select(2, UnitRace("player"))
    local factionIDs = QuestieDB.factionIDs

    local questFixesHorde = {
        [1393] = { -- Galen's Escape
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [1718] = { -- The Islander
            [questKeys.startedBy] = {{3041,3354,4595}},
        },
        [1947] = { -- Journey to the Marsh
            [questKeys.startedBy] = {{3048,4568,5885,16652}},
        },
        [1953] = { -- Return to the Marsh
            [questKeys.startedBy] = {{3048,4568,5885,16652}},
        },
        [2861] = { -- Tabetha's Task
            [questKeys.startedBy] = {{4568,5885,16651}}
        },
        [4738] = { -- In Search of Menara Voidrender
            [questKeys.startedBy] = {{16646}},
        },
        [8151] = { -- The Hunter's Charm
            [questKeys.startedBy] = {{3039,3352,16673}},
        },
        [8233] = { -- A Simple Request
            [questKeys.startedBy] = {{3328,4583,16684}},
        },
        [8250] = { -- Magecraft
            [questKeys.startedBy] = {{3047,4567,7311,16652}},
        },
        [8254] = { -- Cenarion Aid
            [questKeys.startedBy] = {{3045,6018,16658}},
        },
        [8410] = { -- Elemental Mastery
            [questKeys.startedBy] = {{3032,13417}},
        },
        [8417] = { -- A Troubled Spirit
            [questKeys.startedBy] = {{3041,3354,4593}},
        },
        [8419] = { -- An Imp's Request
            [questKeys.startedBy] = {{3326,4563,16647}},
        },
        [8619] = { -- Morndeep the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8635] = { -- Splitrock the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8636] = { -- Rumblerock the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8642] = { -- Silvervein the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8643] = { -- Highpeak the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8644] = { -- Stonefort the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8645] = { -- Obsidian the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8646] = { -- Hammershout the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8647] = { -- Bellowrage the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8648] = { -- Darkcore the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8649] = { -- Stormbrow the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8650] = { -- Snowcrown the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8651] = { -- Ironband the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8652] = { -- Graveborn the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8653] = { -- Goldwell the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8654] = { -- Primestone the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8670] = { -- Runetotem the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8671] = { -- Ragetotem the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8672] = { -- Stonespire the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8673] = { -- Bloodhoof the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8674] = { -- Winterhoof the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8675] = { -- Skychaser the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8676] = { -- Wildmane the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8677] = { -- Darkhorn the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8678] = { -- Proudhorn the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8679] = { -- Grimtotem the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8680] = { -- Windtotem the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8681] = { -- Thunderhorn the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8682] = { -- Skyseer the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8683] = { -- Dawnstrider the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8684] = { -- Dreamseer the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8685] = { -- Mistwalker the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8686] = { -- High Mountain the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8688] = { -- Windrun the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8713] = { -- Starsong the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8714] = { -- Moonstrike the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8715] = { -- Bladeleaf the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8716] = { -- Starglade the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8717] = { -- Moonwarden the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8718] = { -- Bladeswift the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8719] = { -- Bladesing the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8720] = { -- Skygleam the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8721] = { -- Starweave the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8722] = { -- Meadowrun the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8723] = { -- Nightwind the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8724] = { -- Morningdew the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8725] = { -- Riversong the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8726] = { -- Brightspear the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8727] = { -- Farwhisper the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8866] = { -- Bronzebeard the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,75}},
        },
        [8978] = { -- Return to Mokvar
            [questKeys.nextQuestInChain] = ({
                ["DRUID"]   = 8927,
                ["HUNTER"]  = 8938,
                ["MAGE"]    = 8939,
                ["PALADIN"] = 10495,
                ["PRIEST"]  = 8940,
                ["ROGUE"]   = 8941,
                ["SHAMAN"]  = 8942,
                ["WARLOCK"] = 8943,
                ["WARRIOR"] = 8944,
            })[playerClass],
        },
        [8998] = { -- Back to the Beginning
            [questKeys.nextQuestInChain] = ({
                ["DRUID"]   = 9007,
                ["HUNTER"]  = 9008,
                ["MAGE"]    = 9014,
                ["PALADIN"] = 10499,
                ["PRIEST"]  = 9009,
                ["ROGUE"]   = 9010,
                ["SHAMAN"]  = 9011,
                ["WARLOCK"] = 9012,
                ["WARRIOR"] = 9013,
            })[playerClass],
        },
        [9015] = { -- The Challenge
            [questKeys.nextQuestInChain] = ({
                ["DRUID"]   = 9016,
                ["HUNTER"]  = 9017,
                ["MAGE"]    = 9018,
                ["PALADIN"] = 10497,
                ["PRIEST"]  = 9019,
                ["ROGUE"]   = 9020,
                ["SHAMAN"]  = 8957,
                ["WARLOCK"] = 9021,
                ["WARRIOR"] = 9022,
            })[playerClass],
        },
        [9063] = { -- Torwa Pathfinder
            [questKeys.startedBy] = {{3033,12042,16655}},
        },
        [9990] = { -- Investigate Tuurem
            [questKeys.nextQuestInChain] = 9995,
        },
        [10858] = { -- Karynaku
            [questKeys.nextQuestInChain] = 10866,
        },
        [11392] = { -- Call the Headless Horseman
            [questKeys.nextQuestInChain] = 11403,
        },
    }

    local questFixesAlliance = {
        [1393] = { -- Galen's Escape
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [1718] = { -- The Islander
            [questKeys.startedBy] = {{5113,5479,16771}},
        },
        [1947] = { -- Journey to the Marsh
            [questKeys.startedBy] = {{5144,5497,17513}},
        },
        [1953] = { -- Return to the Marsh
            [questKeys.startedBy] = {{5144,5497,17513}},
        },
        [2861] = { -- Tabetha's Task
            [questKeys.startedBy] = {{5144,5497,17514}}
        },
        [4738] = { -- In Search of Menara Voidrender
            [questKeys.startedBy] = {{461}},
        },
        [5054] = { -- Ursius of the Shardtooth
            [questKeys.reputationReward] = {},
        },
        [5057] = { -- Past Endeavors
            [questKeys.reputationReward] = {},
        },
        [8151] = { -- The Hunter's Charm
            [questKeys.startedBy] = {{4205,5116,5516,17505}},
        },
        [8250] = { -- Magecraft
            [questKeys.startedBy] = {{331,7312,17513}},
        },
        [8254] = { -- Cenarion Aid
            [questKeys.startedBy] = {{5489,11406,16756}},
        },
        [8410] = { -- Elemental Mastery
            [questKeys.startedBy] = {{17219,20407,23127}},
        },
        [8417] = { -- A Troubled Spirit
            [questKeys.startedBy] = {{5113,5479,7315,17120}},
        },
        [8419] = { -- An Imp's Request
            [questKeys.startedBy] = {{461,5172}},
        },
        [8619] = { -- Morndeep the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8635] = { -- Splitrock the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8636] = { -- Rumblerock the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8642] = { -- Silvervein the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8643] = { -- Highpeak the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8644] = { -- Stonefort the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8645] = { -- Obsidian the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8646] = { -- Hammershout the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8647] = { -- Bellowrage the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8648] = { -- Darkcore the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8649] = { -- Stormbrow the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8650] = { -- Snowcrown the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8651] = { -- Ironband the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8652] = { -- Graveborn the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8653] = { -- Goldwell the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8654] = { -- Primestone the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8670] = { -- Runetotem the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8671] = { -- Ragetotem the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8672] = { -- Stonespire the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8673] = { -- Bloodhoof the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8674] = { -- Winterhoof the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8675] = { -- Skychaser the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8676] = { -- Wildmane the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8677] = { -- Darkhorn the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8678] = { -- Proudhorn the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8679] = { -- Grimtotem the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8680] = { -- Windtotem the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8681] = { -- Thunderhorn the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8682] = { -- Skyseer the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8683] = { -- Dawnstrider the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8684] = { -- Dreamseer the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8685] = { -- Mistwalker the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8686] = { -- High Mountain the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8688] = { -- Windrun the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8713] = { -- Starsong the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8714] = { -- Moonstrike the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8715] = { -- Bladeleaf the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8716] = { -- Starglade the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8717] = { -- Moonwarden the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8718] = { -- Bladeswift the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8719] = { -- Bladesing the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8720] = { -- Skygleam the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8721] = { -- Starweave the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8722] = { -- Meadowrun the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8723] = { -- Nightwind the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8724] = { -- Morningdew the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8725] = { -- Riversong the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8726] = { -- Brightspear the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8727] = { -- Farwhisper the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8866] = { -- Bronzebeard the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,75}},
        },
        [8977] = { -- Return to Deliana
            [questKeys.nextQuestInChain] = ({
                ["DRUID"]   = 8926,
                ["HUNTER"]  = 8931,
                ["MAGE"]    = 8932,
                ["PALADIN"] = 8933,
                ["PRIEST"]  = 8934,
                ["ROGUE"]   = 8935,
                ["SHAMAN"]  = 10494,
                ["WARLOCK"] = 8936,
                ["WARRIOR"] = 8937,
            })[playerClass],
        },
        [8997] = { -- Back to the Beginning
            [questKeys.nextQuestInChain] = ({
                ["DRUID"]   = 8999,
                ["HUNTER"]  = 9000,
                ["MAGE"]    = 9001,
                ["PALADIN"] = 9002,
                ["PRIEST"]  = 9003,
                ["ROGUE"]   = 9004,
                ["SHAMAN"]  = 10498,
                ["WARLOCK"] = 9005,
                ["WARRIOR"] = 9006,
            })[playerClass],
        },
        [9015] = { -- The Challenge
            [questKeys.nextQuestInChain] = ({
                ["DRUID"]   = 8951,
                ["HUNTER"]  = 8952,
                ["MAGE"]    = 8953,
                ["PALADIN"] = 8954,
                ["PRIEST"]  = 8955,
                ["ROGUE"]   = 8956,
                ["SHAMAN"]  = 10496,
                ["WARLOCK"] = 8958,
                ["WARRIOR"] = 8959,
            })[playerClass],
        },
        [9063] = { -- Torwa Pathfinder
            [questKeys.startedBy] = {{4217,5505,12042,16721}},
        },
        [9990] = { -- Investigate Tuurem
            [questKeys.nextQuestInChain] = 9994,
        },
        [10858] = { -- Karynaku
            [questKeys.nextQuestInChain] = playerRace == "Human" and 10872 or 10866,
        },
        [11392] = { -- Call the Headless Horseman
            [questKeys.nextQuestInChain] = 11242,
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return questFixesHorde
    else
        return questFixesAlliance
    end
end
