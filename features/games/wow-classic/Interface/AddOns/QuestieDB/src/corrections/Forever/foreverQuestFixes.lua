---@class ForeverQuestFixes
local ForeverQuestFixes = QuestieLoader:CreateModule("ForeverQuestFixes")

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

QuestieCorrections.itemObjectiveFirst[92682] = true
QuestieCorrections.killCreditObjectiveFirst[94489] = true
QuestieCorrections.objectObjectiveFirst[95885] = true
QuestieCorrections.itemObjectiveFirst[97277] = true
QuestieCorrections.itemObjectiveFirst[97485] = true
QuestieCorrections.killCreditObjectiveFirst[98386] = true

-- Static Corrections: shared by all characters and folded in during Generation.
function ForeverQuestFixes:Load()
  -- Static body stripped at package time (tools/distribution/strip-static.lua): this correction is
  -- already folded into the TOC metadata store. The repository copy keeps the full body.
  return {}
end

-- Dynamic Corrections: selected from character/game facts such as faction, race or class.
-- These override legacy Dynamic Corrections and all Static Corrections at query time.
function ForeverQuestFixes:LoadDynamic()
    local questKeys = QuestieDB.questKeys
    local zoneIDs = ZoneDB.zoneIDs
    local raceIDs = QuestieDB.raceKeys
    local classIDs = QuestieDB.classKeys
    local sortKeys = QuestieDB.sortKeys
    local specialFlags = QuestieDB.specialFlags
    local profKeys = QuestieProfessions.professionKeys
    local specKeys = QuestieProfessions.specializationKeys
    local factionIDs = QuestieDB.factionIDs
    local rankKeys = QuestieProfessions.rankNames
    local playerClass = UnitClassBase("player")

    local questFixesHorde = {
        [78124] = { -- Nar'thalas Almanac
            [questKeys.startedBy] = {{211022},{409496}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Nar'thalas Almanac, Vol. 74' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [78127] = { -- The Dalaran Digest
            [questKeys.startedBy] = {{211022},{409501}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'The Dalaran Digest, Vol. 23' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [78142] = { -- Bewitchments and Glamours
            [questKeys.startedBy] = {{211022},{409562}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Bewitchments and Glamours' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [78143] = { -- Secrets of the Dreamers
            [questKeys.startedBy] = {{211022},{409692}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Secrets of the Dreamers' located just outside the Wailing Cavern dungeon and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [78145] = { -- Arcanic Systems Manual
            [questKeys.startedBy] = {{211022},{409700}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Arcanic Systems Manual' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [78146] = { -- Goaz Scrolls
            [questKeys.startedBy] = {{211022},{409717}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Goaz Scrolls' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [78147] = { -- Crimes Against Anatomy
            [questKeys.startedBy] = {{211022},{409735}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Crimes Against Anatomy' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [78148] = { -- Runes of the Sorcerer-Kings
            [questKeys.startedBy] = {{211022},{409731}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Runes of the Sorcerer-Kings' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [78149] = { -- Fury of the Land
            [questKeys.startedBy] = {{211022},{409711}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Fury of the Land' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [78150] = { -- Friend of the Library
            [questKeys.startedBy] = {{211022}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"You will need to hand in 10 books to complete this quest, however you can hand 1 in at any time."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79091] = { -- Archmage Antonidas: The Unabridged Autobiography
            [questKeys.startedBy] = {{211022},{386691}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Archmage Antonidas: The Unabridged Autobiography' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79092] = { -- Archmage Theocritus' Research Journal
            [questKeys.startedBy] = {{211022},{386759}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Archmage Theocritus' Research Journal' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79093] = { -- Rumi of Gnomeregan: The Collected Works
            [questKeys.startedBy] = {{211022},{408014}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Rumi of Gnomeregan: The Collected Works' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79094] = { -- The Lessons of Ta'zo
            [questKeys.startedBy] = {{211022},{405149}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'The Lessons of Ta'zo' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79095] = { -- The Apothecary's Metaphysical Primer
            [questKeys.startedBy] = {{211022},{405879}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'The Apothecary's Metaphysical Primer' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79096] = { -- Ataeric: On Arcane Curiosities
            [questKeys.startedBy] = {{211022},{410299}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Ataeric: On Arcane Curiosities' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79097] = { -- Baxtan: On Destructive Magics
            [questKeys.startedBy] = {{211022},{407566}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Baxtan: On Destructive Magics' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79535] = { -- Basilisks: Should Petrification be Feared?
            [questKeys.startedBy] = {{211022},{421526}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Basilisks: Should Petrification be Feared?' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79536] = { -- Greater Friend of the Library
            [questKeys.startedBy] = {{211022}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"You will need to hand in 20 books to complete this quest, however you can hand 1 in at any time."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79947] = { -- Geomancy: The Stone-Cold Truth
            [questKeys.startedBy] = {{211022},{423895}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Geomancy: The Stone-Cold Truth' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79948] = { -- Defensive Magics 101
            [questKeys.startedBy] = {{211022},{423896}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Defensive Magics 101' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79949] = { -- A Web of Lies: Debunking Myths and Legends
            [questKeys.startedBy] = {{211022},{423897}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'A Web of Lies: Debunking Myths and Legends' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79950] = { -- Demons and You
            [questKeys.startedBy] = {{211022},{423898}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Demons and You' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79951] = { -- Mummies: A Guide to the Unsavory Undead
            [questKeys.startedBy] = {{211022},{423899}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Mummies: A Guide to the Unsavory Undead' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79952] = { -- RwlRwlRwlRwl!
            [questKeys.startedBy] = {{211022},{423900}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'RwlRwlRwlRwl!' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [79953] = { -- A Ludite's Guide to Caring for Your Demonic Pet
            [questKeys.startedBy] = {{211022},{423901}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'A Ludite's Guide to Caring for Your Demonic Pet' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [81947] = { -- Sanguine Sorcery
            [questKeys.startedBy] = {{211022},{441247}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Sanguine Sorcery' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [81949] = { -- Legends of the Tidesages
            [questKeys.startedBy] = {{211022},{441248}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Legends of the Tidesages' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [81951] = { -- The Liminal and the Arcane
            [questKeys.startedBy] = {{211022},{441249}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'The Liminal and the Arcane' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [81952] = { -- Everyday Etiquette
            [questKeys.startedBy] = {{211022},{441250}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Everyday Etiquette' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [81953] = { -- Stonewrought Design
            [questKeys.startedBy] = {{211022},{441251}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Stonewrought Design' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [81954] = { -- Venomous Journeys
            [questKeys.startedBy] = {{211022},{441252}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Venomous Journeys' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [81955] = { -- A Mind of Metal
            [questKeys.startedBy] = {{211022},{441253}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'A Mind of Metal' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [81956] = { -- Conjurer's Codex
            [questKeys.startedBy] = {{211022},{441254}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.objectivesText] = {"Collect 'Conjurer's Codex' and bring it to Owen Thadd in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [82208] = { -- Greater Friend of the Library
            [questKeys.startedBy] = {{211022}},
            [questKeys.finishedBy] = {{211022}},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [84395] = { -- Undead Potatoes
            [questKeys.startedBy] = {{7825},{463213}},
            [questKeys.finishedBy] = {{7825}},
            [questKeys.objectivesText] = {"Collect 'Undead Potatoes' and bring it to Oran Snakewrithe in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [84396] = { -- Magma or Lava?
            [questKeys.startedBy] = {{7825},{463206}},
            [questKeys.finishedBy] = {{7825}},
            [questKeys.objectivesText] = {"Collect 'Magma or Lava?' and bring it to Oran Snakewrithe in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [84397] = { -- Northern Kalimdor - A Comprehensive Guide
            [questKeys.startedBy] = {{7825},{463209}},
            [questKeys.finishedBy] = {{7825}},
            [questKeys.objectivesText] = {"Collect 'Northern Kalimdor - A Comprehensive Guide' and bring it to Oran Snakewrithe in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [84398] = { -- A Study of the Light
            [questKeys.startedBy] = {{7825},{463207}},
            [questKeys.finishedBy] = {{7825}},
            [questKeys.objectivesText] = {"Collect 'A Study of the Light' and bring it to Oran Snakewrithe in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [84399] = { -- Ka-Boom!
            [questKeys.startedBy] = {{7825},{463214}},
            [questKeys.finishedBy] = {{7825}},
            [questKeys.objectivesText] = {"Collect 'Ka-Boom!' and bring it to Oran Snakewrithe in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [84400] = { -- The Knight and the Lady
            [questKeys.startedBy] = {{7825},{463208}},
            [questKeys.finishedBy] = {{7825}},
            [questKeys.objectivesText] = {"Collect 'The Knight and the Lady' and bring it to Oran Snakewrithe in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [84401] = { -- Scourge: Undead Menace or Misunderstood?
            [questKeys.startedBy] = {{7825},{463212}},
            [questKeys.finishedBy] = {{7825}},
            [questKeys.objectivesText] = {"Collect 'Scourge: Undead Menace or Misunderstood?' and bring it to Oran Snakewrithe in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [84402] = { -- Necromancy 101
            [questKeys.startedBy] = {{7825},{463211}},
            [questKeys.finishedBy] = {{7825}},
            [questKeys.objectivesText] = {"Collect 'Necromancy 101' and bring it to Oran Snakewrithe in Undercity."},
            [questKeys.zoneOrSort] = zoneIDs.UNDERCITY,
        },
        [97286] = { -- Research Access
            [questKeys.startedBy] = {{211022}},
            [questKeys.finishedBy] = {{211022}},
        },
    }

    local questFixesAlliance = {
        [78124] = { -- Nar'thalas Almanac
            [questKeys.startedBy] = {{211033},{409496}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Nar'thalas Almanac, Vol. 74' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [78127] = { -- The Dalaran Digest
            [questKeys.startedBy] = {{211033},{409501}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'The Dalaran Digest, Vol. 23' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [78142] = { -- Bewitchments and Glamours
            [questKeys.startedBy] = {{211033},{409562}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Bewitchments and Glamours' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [78143] = { -- Secrets of the Dreamers
            [questKeys.startedBy] = {{211033},{409692}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Secrets of the Dreamers' located just outside the Wailing Cavern dungeon and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [78145] = { -- Arcanic Systems Manual
            [questKeys.startedBy] = {{211033},{409700}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Arcanic Systems Manual' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [78146] = { -- Goaz Scrolls
            [questKeys.startedBy] = {{211033},{409717}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Goaz Scrolls' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [78147] = { -- Crimes Against Anatomy
            [questKeys.startedBy] = {{211033},{409735}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Crimes Against Anatomy' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [78148] = { -- Runes of the Sorcerer-Kings
            [questKeys.startedBy] = {{211033},{409731}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Runes of the Sorcerer-Kings' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [78149] = { -- Fury of the Land
            [questKeys.startedBy] = {{211033},{409711}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Fury of the Land' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [78150] = { -- Friend of the Library
            [questKeys.startedBy] = {{211033}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"You will need to hand in 10 books to complete this quest, however you can hand 1 in at any time."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79091] = { -- Archmage Antonidas: The Unabridged Autobiography
            [questKeys.startedBy] = {{211033},{386691}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Archmage Antonidas: The Unabridged Autobiography' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79092] = { -- Archmage Theocritus' Research Journal
            [questKeys.startedBy] = {{211033},{386759}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Archmage Theocritus' Research Journal' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79093] = { -- Rumi of Gnomeregan: The Collected Works
            [questKeys.startedBy] = {{211033},{408014}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Rumi of Gnomeregan: The Collected Works' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79094] = { -- The Lessons of Ta'zo
            [questKeys.startedBy] = {{211033},{405149}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'The Lessons of Ta'zo' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79095] = { -- The Apothecary's Metaphysical Primer
            [questKeys.startedBy] = {{211033},{405879}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'The Apothecary's Metaphysical Primer' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79096] = { -- Ataeric: On Arcane Curiosities
            [questKeys.startedBy] = {{211033},{410299}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Ataeric: On Arcane Curiosities' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79097] = { -- Baxtan: On Destructive Magics
            [questKeys.startedBy] = {{211033},{407566}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Baxtan: On Destructive Magics' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79535] = { -- Basilisks: Should Petrification be Feared?
            [questKeys.startedBy] = {{211033},{421526}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Basilisks: Should Petrification be Feared?' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79536] = { -- Greater Friend of the Library
            [questKeys.startedBy] = {{211033}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"You will need to hand in 20 books to complete this quest, however you can hand 1 in at any time."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79947] = { -- Geomancy: The Stone-Cold Truth
            [questKeys.startedBy] = {{211033},{423895}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Geomancy: The Stone-Cold Truth' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79948] = { -- Defensive Magics 101
            [questKeys.startedBy] = {{211033},{423896}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Defensive Magics 101' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79949] = { -- A Web of Lies: Debunking Myths and Legends
            [questKeys.startedBy] = {{211033},{423897}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'A Web of Lies: Debunking Myths and Legends' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79950] = { -- Demons and You
            [questKeys.startedBy] = {{211033},{423898}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Demons and You' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79951] = { -- Mummies: A Guide to the Unsavory Undead
            [questKeys.startedBy] = {{211033},{423899}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Mummies: A Guide to the Unsavory Undead' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79952] = { -- RwlRwlRwlRwl!
            [questKeys.startedBy] = {{211033},{423900}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'RwlRwlRwlRwl!' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [79953] = { -- A Ludite's Guide to Caring for Your Demonic Pet
            [questKeys.startedBy] = {{211033},{423901}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'A Ludite's Guide to Caring for Your Demonic Pet' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [81947] = { -- Sanguine Sorcery
            [questKeys.startedBy] = {{211033},{441247}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Sanguine Sorcery' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [81949] = { -- Legends of the Tidesages
            [questKeys.startedBy] = {{211033},{441248}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Legends of the Tidesages' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [81951] = { -- The Liminal and the Arcane
            [questKeys.startedBy] = {{211033},{441249}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'The Liminal and the Arcane' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [81952] = { -- Everyday Etiquette
            [questKeys.startedBy] = {{211033},{441250}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Everyday Etiquette' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [81953] = { -- Stonewrought Design
            [questKeys.startedBy] = {{211033},{441251}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Stonewrought Design' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [81954] = { -- Venomous Journeys
            [questKeys.startedBy] = {{211033},{441252}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Venomous Journeys' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [81955] = { -- A Mind of Metal
            [questKeys.startedBy] = {{211033},{441253}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'A Mind of Metal' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [81956] = { -- Conjurer's Codex
            [questKeys.startedBy] = {{211033},{441254}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.objectivesText] = {"Collect 'Conjurer's Codex' and bring it to Garion Wendell in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [82208] = { -- Greater Friend of the Library
            [questKeys.startedBy] = {{211033}},
            [questKeys.finishedBy] = {{211033}},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [84395] = { -- Undead Potatoes
            [questKeys.startedBy] = {{5497},{463213}},
            [questKeys.finishedBy] = {{5497}},
            [questKeys.objectivesText] = {"Collect 'Undead Potatoes' and bring it to Jennea Cannon in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [84396] = { -- Magma or Lava?
            [questKeys.startedBy] = {{5497},{463206}},
            [questKeys.finishedBy] = {{5497}},
            [questKeys.objectivesText] = {"Collect 'Magma or Lava?' and bring it to Jennea Cannon in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [84397] = { -- Northern Kalimdor - A Comprehensive Guide
            [questKeys.startedBy] = {{5497},{463209}},
            [questKeys.finishedBy] = {{5497}},
            [questKeys.objectivesText] = {"Collect 'Northern Kalimdor - A Comprehensive Guide' and bring it to Jennea Cannon in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [84398] = { -- A Study of the Light
            [questKeys.startedBy] = {{5497},{463207}},
            [questKeys.finishedBy] = {{5497}},
            [questKeys.objectivesText] = {"Collect 'A Study of the Light' and bring it to Jennea Cannon in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [84399] = { -- Ka-Boom!
            [questKeys.startedBy] = {{5497},{463214}},
            [questKeys.finishedBy] = {{5497}},
            [questKeys.objectivesText] = {"Collect 'Ka-Boom!' and bring it to Jennea Cannon in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [84400] = { -- The Knight and the Lady
            [questKeys.startedBy] = {{5497},{463208}},
            [questKeys.finishedBy] = {{5497}},
            [questKeys.objectivesText] = {"Collect 'The Knight and the Lady' and bring it to Jennea Cannon in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [84401] = { -- Scourge: Undead Menace or Misunderstood?
            [questKeys.startedBy] = {{5497},{463212}},
            [questKeys.finishedBy] = {{5497}},
            [questKeys.objectivesText] = {"Collect 'Scourge: Undead Menace or Misunderstood?' and bring it to Jennea Cannon in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [84402] = { -- Necromancy 101
            [questKeys.startedBy] = {{5497},{463211}},
            [questKeys.finishedBy] = {{5497}},
            [questKeys.objectivesText] = {"Collect 'Necromancy 101' and bring it to Jennea Cannon in Stormwind."},
            [questKeys.zoneOrSort] = zoneIDs.STORMWIND_CITY,
        },
        [97286] = { -- Research Access
            [questKeys.startedBy] = {{211033}},
            [questKeys.finishedBy] = {{211033}},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return questFixesHorde
    else
        return questFixesAlliance
    end
end
