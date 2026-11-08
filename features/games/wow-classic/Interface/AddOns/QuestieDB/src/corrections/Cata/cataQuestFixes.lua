---@class CataQuestFixes
local CataQuestFixes = QuestieLoader:CreateModule("CataQuestFixes")

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

QuestieCorrections.objectObjectiveFirst[14125] = true
QuestieCorrections.objectObjectiveFirst[24817] = true
QuestieCorrections.objectObjectiveFirst[25371] = true
QuestieCorrections.objectObjectiveFirst[25731] = true
QuestieCorrections.objectObjectiveFirst[25813] = true
QuestieCorrections.objectObjectiveFirst[26659] = true
QuestieCorrections.objectObjectiveFirst[26809] = true
QuestieCorrections.objectObjectiveFirst[27161] = true
QuestieCorrections.objectObjectiveFirst[30099] = true
QuestieCorrections.killCreditObjectiveFirst[52] = true
QuestieCorrections.killCreditObjectiveFirst[13798] = true
QuestieCorrections.killCreditObjectiveFirst[25015] = true
QuestieCorrections.killCreditObjectiveFirst[25801] = true
QuestieCorrections.killCreditObjectiveFirst[26058] = true
QuestieCorrections.killCreditObjectiveFirst[26621] = true
QuestieCorrections.killCreditObjectiveFirst[26875] = true
QuestieCorrections.killCreditObjectiveFirst[27715] = true
QuestieCorrections.killCreditObjectiveFirst[29290] = true

function CataQuestFixes.Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

function CataQuestFixes:LoadFactionFixes()
    local questKeys = QuestieDB.questKeys
    local factionIDs = QuestieDB.factionIDs

    local questFixesHorde = {
        [2280] = { -- The Platinum Discs
            [questKeys.requiredLevel] = 35,
            [questKeys.finishedBy] = {{46236}},
        },
        [12318] = { -- Save Brewfest!
            [questKeys.startedBy] = {},
        },
        [24911] = { -- Tropical Paradise Beckons
            [questKeys.startedBy] = {{44374}},
        },
        [25095] = { -- Thunderdrome: Sarinexx!
            [questKeys.nextQuestInChain] = 25591,
        },
        [25619] = { -- Reoccupation
            [questKeys.preQuestSingle] = {},
            [questKeys.preQuestGroup] = {25952,25953,25954,25955,25956},
        },
        [25858] = { -- By Her Lady's Word
            [questKeys.objectives] = {{{42072,nil,Questie.ICON_TYPE_TALK},{42071,nil,Questie.ICON_TYPE_TALK},{41455,nil,Questie.ICON_TYPE_TALK}}},
            [questKeys.preQuestSingle] = {},
            [questKeys.preQuestGroup] = {25964,25965},
        },
        [25629] = { -- Her Lady's Hand
            [questKeys.preQuestSingle] = {25973},
        },
        [25896] = { -- Devout Assembly
            [questKeys.preQuestSingle] = {25973},
        },
        [26111] = { -- ... It Will Come
            [questKeys.preQuestSingle] = {},
            [questKeys.preQuestGroup] = {26072,26096},
        },
        [26191] = { -- The Culmination of Our Efforts
            [questKeys.nextQuestInChain] = 25967,
        },
        [27203] = { -- The Maelstrom
            [questKeys.startedBy] = {{45244}},
        },
        [27683] = { -- Into the Woods
            [questKeys.startedBy] = {{10840,44456,44462}},
        },
        [27861] = { -- The Crucible of Carnage: The Bloodeye Bruiser!
            [questKeys.nextQuestInChain] = 27865,
        },
        [27862] = { -- The Crucible of Carnage: The Bloodeye Bruiser!
            [questKeys.nextQuestInChain] = 27865,
        },
        [27863] = { -- The Crucible of Carnage: The Bloodeye Bruiser!
            [questKeys.nextQuestInChain] = 27865,
        },
        [27865] = { -- The Crucible of Carnage: The Wayward Wildhammer!
            [questKeys.nextQuestInChain] = 27866,
        },
        [27866] = { -- The Crucible of Carnage: Calder's Creation!
            [questKeys.nextQuestInChain] = 27867,
        },
        [27867] = { -- The Crucible of Carnage: The Earl of Evisceration!
            [questKeys.nextQuestInChain] = 27868,
        },
        [27927] = { -- Down to the Scar
            [questKeys.startedBy] = {{46660}},
            [questKeys.nextQuestInChain] = 27713,
        },
        [28052] = { -- Operation: Stir the Cauldron
            [questKeys.extraObjectives] = {{nil, Questie.ICON_TYPE_TALK, l10n("Talk to the Flight Master"), 0, {{"monster", 3305}}}},
        },
        [28512] = { -- To the Aid of the Thorium Brotherhood
            [questKeys.startedBy] = {{46660}},
            [questKeys.nextQuestInChain] = 27963,
        },
        [29067] = { -- Potion Master
            [questKeys.startedBy] = {{3347}},
            [questKeys.finishedBy] = {{3347,3009,4611,16642}},
        },
        [29389] = { -- Guardians of Hyjal: Firelands Invasion!
            [questKeys.preQuestGroup] = {25612,25807,25520,25372},
        },
        [29475] = { -- Goblin Engineering
            [questKeys.startedBy] = {{11017,11031,16667,29513,52651}},
            [questKeys.finishedBy] = {{11017,11031,16667,29513,52651}},
            [questKeys.exclusiveTo] = {3526,3629,3633,4181,29476,29477,3630,3632,3634,3635,3637},
        },
        [29477] = { -- Gnomish Engineering
            [questKeys.startedBy] = {{11017,11031,16667,29513,52651}},
            [questKeys.finishedBy] = {{11017,11031,16667,29513,52651}},
            [questKeys.exclusiveTo] = {3630,3632,3634,3635,3637,29475,29476,3526,3629,3633,4181},
        },
        [29481] = { -- Elixir Master
            [questKeys.startedBy] = {{3347}},
            [questKeys.finishedBy] = {{3347,3009,4611,16642}},
        },
        [29482] = { -- Transmutation Master
            [questKeys.startedBy] = {{3347}},
            [questKeys.finishedBy] = {{3347,3009,4611,16642}},
        },
        [29734] = { -- Deepforge the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,3}},
        },
        [29735] = { -- Stonebrand the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,3}},
        },
        [29736] = { -- Darkfeather the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,3}},
        },
        [29737] = { -- Firebeard the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,3}},
        },
        [29738] = { -- Moonlance the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,3}},
        },
        [29739] = { -- Windsong the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,3}},
        },
        [29740] = { -- Evershade the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,3}},
        },
        [29741] = { -- Sekhemi the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,3}},
        },
        [29742] = { -- Menkhaf the Elder
            [questKeys.reputationReward] = {{factionIDs.HORDE,3}},
        },
        [29836] = { -- Just Checkin'
            [questKeys.nextQuestInChain] = 29840,
            [questKeys.exclusiveTo] = {13098},
        },
    }

    local questFixesAlliance = {
        [2280] = { -- The Platinum Discs
            [questKeys.requiredLevel] = 35,
            [questKeys.finishedBy] = {{46234}},
        },
        [12318] = { -- Save Brewfest!
            [questKeys.startedBy] = {{27584}},
        },
        [24911] = { -- Tropical Paradise Beckons
            [questKeys.startedBy] = {{38578}},
        },
        [25422] = { -- The Darkmist Legacy
            [questKeys.preQuestSingle] = {25350},
        },
        [25423] = { -- Ancient Suffering
            [questKeys.preQuestSingle] = {25350},
        },
        [25513] = { -- Thunderdrome: Grudge Match!
            [questKeys.preQuestGroup] = {25065,25095},
        },
        [25619] = { -- Reoccupation
            [questKeys.preQuestSingle] = {},
            [questKeys.preQuestGroup] = {25579,25580,25581,25582,25583},
        },
        [25629] = { -- Her Lady's Hand
            [questKeys.preQuestSingle] = {25911},
        },
        [25896] = { -- Devout Assembly
            [questKeys.preQuestSingle] = {25911},
        },
        [25858] = { -- By Her Lady's Word
            [questKeys.objectives] = {{{42072,nil,Questie.ICON_TYPE_TALK},{42071,nil,Questie.ICON_TYPE_TALK},{41455,nil,Questie.ICON_TYPE_TALK}}},
            [questKeys.preQuestSingle] = {},
            [questKeys.preQuestGroup] = {25753,25754},
        },
        [26111] = { -- ... It Will Come
            [questKeys.preQuestSingle] = {},
            [questKeys.preQuestGroup] = {26072,26096},
        },
        [26191] = { -- The Culmination of Our Efforts
            [questKeys.nextQuestInChain] = 25892,
        },
        [27203] = { -- The Maelstrom
            [questKeys.startedBy] = {{45226}},
        },
        [27861] = { -- The Crucible of Carnage: The Bloodeye Bruiser!
            [questKeys.nextQuestInChain] = 27864,
        },
        [27862] = { -- The Crucible of Carnage: The Bloodeye Bruiser!
            [questKeys.nextQuestInChain] = 27864,
        },
        [27863] = { -- The Crucible of Carnage: The Bloodeye Bruiser!
            [questKeys.nextQuestInChain] = 27864,
        },
        [27864] = { -- The Crucible of Carnage: The Deadly Dragonmaw!
            [questKeys.nextQuestInChain] = 27866,
        },
        [27866] = { -- The Crucible of Carnage: Calder's Creation!
            [questKeys.nextQuestInChain] = 27867,
        },
        [27867] = { -- The Crucible of Carnage: The Earl of Evisceration!
            [questKeys.nextQuestInChain] = 27868,
        },
        [27927] = { -- Down to the Scar
            [questKeys.startedBy] = {{46930}},
            [questKeys.nextQuestInChain] = 27713,
        },
        [28052] = { -- Operation: Stir the Cauldron
            [questKeys.extraObjectives] = {{nil, Questie.ICON_TYPE_TALK, l10n("Talk to the Flight Master"), 0, {{"monster", 2941}}}},
        },
        [28512] = { -- To the Aid of the Thorium Brotherhood
            [questKeys.startedBy] = {{46930}},
            [questKeys.nextQuestInChain] = 27963,
        },
        [29067] = { -- Potion Master
            [questKeys.startedBy] = {{5499}},
            [questKeys.finishedBy] = {{5499,1537,4160,16723}},
        },
        [29389] = { -- Guardians of Hyjal: Firelands Invasion!
            [questKeys.preQuestGroup] = {25611,25807,25520,25372},
        },
        [29475] = { -- Goblin Engineering
            [questKeys.startedBy] = {{5174,5518,16726,52636}},
            [questKeys.finishedBy] = {{5174,5518,16726,52636}},
            [questKeys.exclusiveTo] = {3526,3629,3633,4181,29476,29477,3630,3632,3634,3635,3637},
        },
        [29477] = { -- Gnomish Engineering
            [questKeys.startedBy] = {{5174,5518,16726,52636}},
            [questKeys.finishedBy] = {{5518,7944,16726,52636}},
            [questKeys.exclusiveTo] = {3630,3632,3634,3635,3637,29475,29476,3526,3629,3633,4181},
        },
        [29481] = { -- Elixir Master
            [questKeys.startedBy] = {{5499}},
            [questKeys.finishedBy] = {{5499,1537,4160,16723}},
        },
        [29482] = { -- Transmutation Master
            [questKeys.startedBy] = {{5499}},
            [questKeys.finishedBy] = {{5499,1537,4160,16723}},
        },
        [29734] = { -- Deepforge the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,3}},
        },
        [29735] = { -- Stonebrand the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,3}},
        },
        [29736] = { -- Darkfeather the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,3}},
        },
        [29737] = { -- Firebeard the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,3}},
        },
        [29738] = { -- Moonlance the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,3}},
        },
        [29739] = { -- Windsong the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,3}},
        },
        [29740] = { -- Evershade the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,3}},
        },
        [29741] = { -- Sekhemi the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,3}},
        },
        [29742] = { -- Menkhaf the Elder
            [questKeys.reputationReward] = {{factionIDs.ALLIANCE,3}},
        },
        [29836] = { -- Just Checkin'
            [questKeys.nextQuestInChain] = 29844,
            [questKeys.exclusiveTo] = {13098},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return questFixesHorde
    else
        return questFixesAlliance
    end
end
