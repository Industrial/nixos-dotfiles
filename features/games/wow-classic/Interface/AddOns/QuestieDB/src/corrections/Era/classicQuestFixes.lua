---@class QuestieQuestFixes
local QuestieQuestFixes = QuestieLoader:CreateModule("QuestieQuestFixes")
-------------------------
--Import modules.
-------------------------
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

QuestieCorrections.itemObjectiveFirst[503] = true
QuestieCorrections.itemObjectiveFirst[5088] = true

-- Further information on how to use this can be found at the wiki
-- https://github.com/Questie/Questie/wiki/Corrections

function QuestieQuestFixes:Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

function QuestieQuestFixes:LoadFactionFixes()
    local questKeys = QuestieDB.questKeys
    local raceIDs = QuestieDB.raceKeys
    local playerClass = UnitClassBase("player")
    local factionIDs = QuestieDB.factionIDs

    local questFixesHorde = {
        [113] = { -- Insect Part Analysis
            [questKeys.nextQuestInChain] = 32,
        },
        [687] = { -- Theldurin the Lost
            [questKeys.startedBy] = {{2787}},
        },
        [709] = { -- Solution to Doom
            [questKeys.nextQuestInChain] = 728,
        },
        [737] = { -- Forbidden Knowledge
            [questKeys.startedBy] = {{2934}},
        },
        [1198] = { -- In Search of Thaelrid
            [questKeys.nextQuestInChain] = 0,
        },
        [1393] = { -- Galen's Escape
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [1718] = { -- The Islander
            [questKeys.startedBy] = {{3041, 3354, 4595}},
        },
        [1947] = { -- Journey to the Marsh
            [questKeys.startedBy] = {{3048, 4568, 5885}},
        },
        [1953] = { -- Return to the Marsh
            [questKeys.startedBy] = {{3048, 4568, 5885}},
        },
        [2861] = { -- Tabetha's Task
            [questKeys.startedBy] = {{4568, 5885}},
        },
        [2954] = { -- The Stone Watcher
            [questKeys.nextQuestInChain] = 2967,
        },
        [3741] = { -- Hilary's Necklace
            [questKeys.reputationReward] = {}, -- doable as horde, but no SW reputation for horde side
        },
        [4507] = { -- Pawn Captures Queen
            [questKeys.nextQuestInChain] = 4509,
        },
        [4985] = { -- The Wildlife Suffers Too
            [questKeys.nextQuestInChain] = 4987,
        },
        [5021] = { -- Better Late Than Never
            [questKeys.nextQuestInChain] = 5023,
        },
        [5050] = { -- Good Luck Charm
            [questKeys.startedBy] = {{8403}},
        },
        [6981] = { -- The Glowing Shard
            [questKeys.nextQuestInChain] = 3369,
        },
        [7562] = { -- Mor'zul Bloodbringer
            [questKeys.startedBy] = {{5753, 5815}},
            [questKeys.requiredRaces] = raceIDs.NONE,
        },
        [8151] = { -- The Hunter's Charm
            [questKeys.startedBy] = {{3039, 3352}},
        },
        [8233] = { -- A Simple Request
            [questKeys.startedBy] = {{3328, 4583}},
        },
        [8250] = { -- Magecraft
            [questKeys.startedBy] = {{3047, 4567, 7311}},
        },
        [8254] = { -- Cenarion Aid
            [questKeys.startedBy] = {{3045, 6018}},
        },
        [8315] = { -- The Calling
            [questKeys.nextQuestInChain] = ({
                ["DRUID"] = 8382,
                ["HUNTER"] = 8377,
                ["MAGE"] = 8381,
                ["PALADIN"] = 8376,
                ["PRIEST"] = 8379,
                ["ROGUE"] = 8378,
                ["SHAMAN"] = 8380,
                ["WARLOCK"] = 8381,
                ["WARRIOR"] = 8316,
            })[playerClass],
        },
        [8417] = { -- A Troubled Spirit
            [questKeys.startedBy] = {{3041, 3354, 4593}},
        },
        [8419] = { -- An Imp's Request
            [questKeys.startedBy] = {{3326, 4563}},
        },
        [8619] = { -- Morndeep the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8635] = { -- Splitrock the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8636] = { -- Rumblerock the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8642] = { -- Silvervein the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8643] = { -- Highpeak the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8644] = { -- Stonefort the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8645] = { -- Obsidian the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8646] = { -- Hammershout the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8647] = { -- Bellowrage the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8648] = { -- Darkcore the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8649] = { -- Stormbrow the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8650] = { -- Snowcrown the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8651] = { -- Ironband the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8652] = { -- Graveborn the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8653] = { -- Goldwell the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8654] = { -- Primestone the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8670] = { -- Runetotem the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8671] = { -- Ragetotem the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8672] = { -- Stonespire the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8673] = { -- Bloodhoof the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8674] = { -- Winterhoof the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8675] = { -- Skychaser the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8676] = { -- Wildmane the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8677] = { -- Darkhorn the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8678] = { -- Proudhorn the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8679] = { -- Grimtotem the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8680] = { -- Windtotem the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8681] = { -- Thunderhorn the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8682] = { -- Skyseer the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8683] = { -- Dawnstrider the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8684] = { -- Dreamseer the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8685] = { -- Mistwalker the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8686] = { -- High Mountain the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8688] = { -- Windrun the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8713] = { -- Starsong the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8714] = { -- Moonstrike the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8715] = { -- Bladeleaf the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8716] = { -- Starglade the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8717] = { -- Moonwarden the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8718] = { -- Bladeswift the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8719] = { -- Bladesing the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8720] = { -- Skygleam the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8721] = { -- Starweave the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8722] = { -- Meadowrun the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8723] = { -- Nightwind the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8724] = { -- Morningdew the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8725] = { -- Riversong the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8726] = { -- Brightspear the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8727] = { -- Farwhisper the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8866] = { -- Bronzebeard the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE, 50}},
        },
        [8928] = { -- A Shifty Merchant
            [questKeys.nextQuestInChain] = 8978,
        },
        [8978] = { -- Return to Mokvar
            [questKeys.nextQuestInChain] = ({
                ["DRUID"] = 8927,
                ["HUNTER"] = 8938,
                ["MAGE"] = 8939,
                ["PRIEST"] = 8940,
                ["ROGUE"] = 8941,
                ["SHAMAN"] = 8942,
                ["WARLOCK"] = 8943,
                ["WARRIOR"] = 8944,
            })[playerClass],
        },
        [8996] = { -- Return to Bodley
            [questKeys.nextQuestInChain] = 8998,
        },
        [8998] = { -- Back to the Beginning
            [questKeys.nextQuestInChain] = ({
                ["DRUID"] = 9007,
                ["HUNTER"] = 9008,
                ["MAGE"] = 9014,
                ["PRIEST"] = 9009,
                ["ROGUE"] = 9010,
                ["SHAMAN"] = 9011,
                ["WARLOCK"] = 9012,
                ["WARRIOR"] = 9013,
            })[playerClass],
        },
        [9015] = { -- The Challenge
            [questKeys.nextQuestInChain] = ({
                ["DRUID"] = 9016,
                ["HUNTER"] = 9017,
                ["MAGE"] = 9018,
                ["PRIEST"] = 9019,
                ["ROGUE"] = 9020,
                ["SHAMAN"] = 8957,
                ["WARLOCK"] = 9021,
                ["WARRIOR"] = 9022,
            })[playerClass],
        },
        [9063] = { -- Torwa Pathfinder
            [questKeys.startedBy] = {{3033, 12042}},
        },
        [9388] = { -- Flickering Flames in Kalimdor
            [questKeys.startedBy] = {{16818}},
        },
        [9389] = { -- Flickering Flames in the Eastern Kingdoms
            [questKeys.startedBy] = {{16818}},
        },
    }

    local questFixesAlliance = {
        [113] = { -- Insect Part Analysis
            [questKeys.nextQuestInChain] = 162,
        },
        [687] = { -- Theldurin the Lost
            [questKeys.startedBy] = {{2786}},
        },
        [709] = { -- Solution to Doom
            [questKeys.nextQuestInChain] = 727,
        },
        [737] = { -- Forbidden Knowledge
            [questKeys.startedBy] = {{2786}},
        },
        [1198] = { -- In Search of Thaelrid
            [questKeys.breadcrumbForQuestId] = 1200,
        },
        [1393] = { -- Galen's Escape
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [1718] = { -- The Islander
            [questKeys.startedBy] = {{5113, 5479}},
        },
        [1947] = { -- Journey to the Marsh
            [questKeys.startedBy] = {{5144, 5497}},
        },
        [1953] = { -- Return to the Marsh
            [questKeys.startedBy] = {{5144, 5497}},
        },
        [2861] = { -- Tabetha's Task
            [questKeys.startedBy] = {{5144, 5497}},
        },
        [2954] = { -- The Stone Watcher
            [questKeys.nextQuestInChain] = 2977,
        },
        [4507] = { -- Pawn Captures Queen
            [questKeys.nextQuestInChain] = 4508,
        },
        [4985] = { -- The Wildlife Suffers Too
            [questKeys.nextQuestInChain] = 4986,
        },
        [5021] = { -- Better Late Than Never
            [questKeys.nextQuestInChain] = 5022,
        },
        [5050] = { -- Good Luck Charm
            [questKeys.startedBy] = {{3520}},
        },
        [6804] = { -- Poisoned Water
            [questKeys.reputationReward] = {}, -- need to check if horde actually gets any reputation at all
        },
        [6981] = { -- The Glowing Shard
            [questKeys.nextQuestInChain] = 3370,
        },
        [7562] = { -- Mor'zul Bloodbringer
            [questKeys.startedBy] = {{5520, 6382}},
            [questKeys.requiredRaces] = raceIDs.NONE,
        },
        [8151] = { -- The Hunter's Charm
            [questKeys.startedBy] = {{4205, 5116, 5516}},
        },
        [8233] = { -- A Simple Request
            [questKeys.startedBy] = {{918, 4163, 5165, 5167}},
        },
        [8250] = { -- Magecraft
            [questKeys.startedBy] = {{331, 7312}},
        },
        [8254] = { -- Cenarion Aid
            [questKeys.startedBy] = {{5489, 11406}},
        },
        [8315] = { -- The Calling
            [questKeys.nextQuestInChain] = ({
                ["DRUID"] = 8382,
                ["HUNTER"] = 8377,
                ["MAGE"] = 8381,
                ["PALADIN"] = 8376,
                ["PRIEST"] = 8379,
                ["ROGUE"] = 8378,
                ["SHAMAN"] = 8380,
                ["WARLOCK"] = 8381,
                ["WARRIOR"] = 8316,
            })[playerClass],
        },
        [8417] = { -- A Troubled Spirit
            [questKeys.startedBy] = {{5113, 5479, 7315}},
        },
        [8419] = { -- An Imp's Request
            [questKeys.startedBy] = {{461, 5172}},
        },
        [8619] = { -- Morndeep the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8635] = { -- Splitrock the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8636] = { -- Rumblerock the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8642] = { -- Silvervein the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8643] = { -- Highpeak the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8644] = { -- Stonefort the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8645] = { -- Obsidian the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8646] = { -- Hammershout the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8647] = { -- Bellowrage the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8648] = { -- Darkcore the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8649] = { -- Stormbrow the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8650] = { -- Snowcrown the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8651] = { -- Ironband the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8652] = { -- Graveborn the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8653] = { -- Goldwell the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8654] = { -- Primestone the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8670] = { -- Runetotem the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8671] = { -- Ragetotem the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8672] = { -- Stonespire the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8673] = { -- Bloodhoof the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8674] = { -- Winterhoof the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8675] = { -- Skychaser the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8676] = { -- Wildmane the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8677] = { -- Darkhorn the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8678] = { -- Proudhorn the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8679] = { -- Grimtotem the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8680] = { -- Windtotem the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8681] = { -- Thunderhorn the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8682] = { -- Skyseer the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8683] = { -- Dawnstrider the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8684] = { -- Dreamseer the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8685] = { -- Mistwalker the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8686] = { -- High Mountain the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8688] = { -- Windrun the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8713] = { -- Starsong the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8714] = { -- Moonstrike the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8715] = { -- Bladeleaf the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8716] = { -- Starglade the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8717] = { -- Moonwarden the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8718] = { -- Bladeswift the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8719] = { -- Bladesing the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8720] = { -- Skygleam the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8721] = { -- Starweave the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8722] = { -- Meadowrun the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8723] = { -- Nightwind the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8724] = { -- Morningdew the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8725] = { -- Riversong the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8726] = { -- Brightspear the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8727] = { -- Farwhisper the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8866] = { -- Bronzebeard the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE, 50}},
        },
        [8928] = { -- A Shifty Merchant
            [questKeys.nextQuestInChain] = 8977,
        },
        [8977] = { -- Return to Deliana
            [questKeys.nextQuestInChain] = ({
                ["DRUID"] = 8926,
                ["HUNTER"] = 8931,
                ["MAGE"] = 8932,
                ["PALADIN"] = 8933,
                ["PRIEST"] = 8934,
                ["ROGUE"] = 8935,
                ["WARLOCK"] = 8936,
                ["WARRIOR"] = 8937,
            })[playerClass],
        },
        [8996] = { -- Return to Bodley
            [questKeys.nextQuestInChain] = 8997,
        },
        [8997] = { -- Back to the Beginning
            [questKeys.nextQuestInChain] = ({
                ["DRUID"] = 8999,
                ["HUNTER"] = 9000,
                ["MAGE"] = 9001,
                ["PALADIN"] = 9002,
                ["PRIEST"] = 9003,
                ["ROGUE"] = 9004,
                ["WARLOCK"] = 9005,
                ["WARRIOR"] = 9006,
            })[playerClass],
        },
        [9015] = { -- The Challenge
            [questKeys.nextQuestInChain] = ({
                ["DRUID"] = 8951,
                ["HUNTER"] = 8952,
                ["MAGE"] = 8953,
                ["PALADIN"] = 8954,
                ["PRIEST"] = 8955,
                ["ROGUE"] = 8956,
                ["WARLOCK"] = 8958,
                ["WARRIOR"] = 8959,
            })[playerClass],
        },
        [9063] = { -- Torwa Pathfinder
            [questKeys.startedBy] = {{4217, 5505, 12042}},
        },
        [9388] = { -- Flickering Flames in Kalimdor
            [questKeys.startedBy] = {{16817}},
        },
        [9389] = { -- Flickering Flames in the Eastern Kingdoms
            [questKeys.startedBy] = {{16817}},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return questFixesHorde
    else
        return questFixesAlliance
    end
end
