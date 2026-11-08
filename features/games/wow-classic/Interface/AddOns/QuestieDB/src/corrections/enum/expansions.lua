-- Correction constants. Source origins and extraction history: PROVENANCE.md.
-- Named sets live under byExpansion; src/api.lua publishes faction masks for the active flavor.

local _, LibQuestieDB = ...
local constants = LibQuestieDB.Enum

-- Actual race IDs to single-bit requiredRaces mask values, not bit indices or a per-flavor playability list.
-- Legacy entries retain Questie's encoding. Forever ChrRaces build 1.60.1.69893
-- assigns IDs 95/96 to bits 32/33, not raceID - 1. Unknown IDs stay absent.
-- Shared with consumers; read-only by contract.
constants.raceMaskById = {
  [1] = 1, -- HUMAN
  [2] = 2, -- ORC
  [3] = 4, -- DWARF
  [4] = 8, -- NIGHT_ELF
  [5] = 16, -- UNDEAD
  [6] = 32, -- TAUREN
  [7] = 64, -- GNOME
  [8] = 128, -- TROLL
  [9] = 256, -- GOBLIN
  [10] = 512, -- BLOOD_ELF
  [11] = 1024, -- DRAENEI
  [22] = 2097152, -- WORGEN
  [24] = 8388608, -- PANDAREN
  [25] = 16777216, -- PANDAREN_ALLIANCE
  [26] = 33554432, -- PANDAREN_HORDE
  [95] = 4294967296, -- SKYBORNE_ALLIANCE
  [96] = 8589934592, -- SKYBORNE_HORDE
}
local raceMaskById = constants.raceMaskById

-- Build faction masks once from explicit membership, not every named race in a flavor's raceKeys.
-- Adding distinct bits avoids truncating Forever's bits 32/33 through the client's 32-bit bit library.
-- Neutral Pandaren are excluded.
local classicAlliance = raceMaskById[1] + raceMaskById[3] + raceMaskById[4] + raceMaskById[7]
local classicHorde = raceMaskById[2] + raceMaskById[5] + raceMaskById[6] + raceMaskById[8]
local tbcAlliance = classicAlliance + raceMaskById[11]
local tbcHorde = classicHorde + raceMaskById[10]
local cataAlliance = tbcAlliance + raceMaskById[22]
local cataHorde = tbcHorde + raceMaskById[9]

constants.byExpansion = {
  Classic = {
    classKeys = {
      NONE = 0,
      WARRIOR = 1,
      PALADIN = 2,
      HUNTER = 4,
      ROGUE = 8,
      PRIEST = 16,
      DEATH_KNIGHT = 32,
      SHAMAN = 64,
      MAGE = 128,
      WARLOCK = 256,
      MONK = 512,
      DRUID = 1024,
      ALL_CLASSES = 1503,
    },
    npcFlags = {
      NONE = 0,
      GOSSIP = 1,
      QUEST_GIVER = 2,
      VENDOR = 4,
      FLIGHT_MASTER = 8,
      TRAINER = 16,
      SPIRIT_HEALER = 32,
      SPIRIT_GUIDE = 64,
      INNKEEPER = 128,
      BANKER = 256,
      PETITIONER = 512,
      TABARD_DESIGNER = 1024,
      BATTLEMASTER = 2048,
      AUCTIONEER = 4096,
      STABLEMASTER = 8192,
      REPAIR = 16384,
    },
    raceKeys = {
      NONE = 0,
      HUMAN = raceMaskById[1],
      ORC = raceMaskById[2],
      DWARF = raceMaskById[3],
      NIGHT_ELF = raceMaskById[4],
      UNDEAD = raceMaskById[5],
      TAUREN = raceMaskById[6],
      GNOME = raceMaskById[7],
      ALL_ALLIANCE = classicAlliance,
      TROLL = raceMaskById[8],
      ALL_HORDE = classicHorde,
      GOBLIN = raceMaskById[9],
      BLOOD_ELF = raceMaskById[10],
      DRAENEI = raceMaskById[11],
      WORGEN = raceMaskById[22],
      PANDAREN = raceMaskById[24],
      PANDAREN_ALLIANCE = raceMaskById[25],
      PANDAREN_HORDE = raceMaskById[26],
    },
  },

  TBC = {
    classKeys = {
      NONE = 0,
      WARRIOR = 1,
      PALADIN = 2,
      HUNTER = 4,
      ROGUE = 8,
      PRIEST = 16,
      DEATH_KNIGHT = 32,
      SHAMAN = 64,
      MAGE = 128,
      WARLOCK = 256,
      MONK = 512,
      DRUID = 1024,
      ALL_CLASSES = 1503,
    },
    npcFlags = {
      NONE = 0,
      GOSSIP = 1,
      QUEST_GIVER = 2,
      TRAINER = 16,
      VENDOR = 128,
      REPAIR = 4096,
      FLIGHT_MASTER = 8192,
      SPIRIT_HEALER = 16384,
      SPIRIT_GUIDE = 32768,
      INNKEEPER = 65536,
      BANKER = 131072,
      PETITIONER = 262144,
      TABARD_DESIGNER = 524288,
      BATTLEMASTER = 1048576,
      AUCTIONEER = 2097152,
      STABLEMASTER = 4194304,
    },
    raceKeys = {
      NONE = 0,
      HUMAN = raceMaskById[1],
      ORC = raceMaskById[2],
      DWARF = raceMaskById[3],
      NIGHT_ELF = raceMaskById[4],
      UNDEAD = raceMaskById[5],
      TAUREN = raceMaskById[6],
      GNOME = raceMaskById[7],
      TROLL = raceMaskById[8],
      GOBLIN = raceMaskById[9],
      BLOOD_ELF = raceMaskById[10],
      ALL_HORDE = tbcHorde,
      DRAENEI = raceMaskById[11],
      ALL_ALLIANCE = tbcAlliance,
      WORGEN = raceMaskById[22],
      PANDAREN = raceMaskById[24],
      PANDAREN_ALLIANCE = raceMaskById[25],
      PANDAREN_HORDE = raceMaskById[26],
    },
  },

  Wotlk = {
    classKeys = {
      NONE = 0,
      WARRIOR = 1,
      PALADIN = 2,
      HUNTER = 4,
      ROGUE = 8,
      PRIEST = 16,
      DEATH_KNIGHT = 32,
      SHAMAN = 64,
      MAGE = 128,
      WARLOCK = 256,
      MONK = 512,
      DRUID = 1024,
      ALL_CLASSES = 1535,
    },
    npcFlags = {
      NONE = 0,
      GOSSIP = 1,
      QUEST_GIVER = 2,
      TRAINER = 16,
      VENDOR = 128,
      REPAIR = 4096,
      FLIGHT_MASTER = 8192,
      SPIRIT_HEALER = 16384,
      SPIRIT_GUIDE = 32768,
      INNKEEPER = 65536,
      BANKER = 131072,
      PETITIONER = 262144,
      TABARD_DESIGNER = 524288,
      BATTLEMASTER = 1048576,
      AUCTIONEER = 2097152,
      STABLEMASTER = 4194304,
      BARBER = 33554432,
    },
    raceKeys = {
      NONE = 0,
      HUMAN = raceMaskById[1],
      ORC = raceMaskById[2],
      DWARF = raceMaskById[3],
      NIGHT_ELF = raceMaskById[4],
      UNDEAD = raceMaskById[5],
      TAUREN = raceMaskById[6],
      GNOME = raceMaskById[7],
      TROLL = raceMaskById[8],
      GOBLIN = raceMaskById[9],
      BLOOD_ELF = raceMaskById[10],
      ALL_HORDE = tbcHorde,
      DRAENEI = raceMaskById[11],
      ALL_ALLIANCE = tbcAlliance,
      WORGEN = raceMaskById[22],
      PANDAREN = raceMaskById[24],
      PANDAREN_ALLIANCE = raceMaskById[25],
      PANDAREN_HORDE = raceMaskById[26],
    },
  },

  Cata = {
    classKeys = {
      NONE = 0,
      WARRIOR = 1,
      PALADIN = 2,
      HUNTER = 4,
      ROGUE = 8,
      PRIEST = 16,
      DEATH_KNIGHT = 32,
      SHAMAN = 64,
      MAGE = 128,
      WARLOCK = 256,
      MONK = 512,
      DRUID = 1024,
      ALL_CLASSES = 1535,
    },
    npcFlags = {
      NONE = 0,
      GOSSIP = 1,
      QUEST_GIVER = 2,
      TRAINER = 16,
      VENDOR = 128,
      REPAIR = 4096,
      FLIGHT_MASTER = 8192,
      SPIRIT_HEALER = 16384,
      SPIRIT_GUIDE = 32768,
      INNKEEPER = 65536,
      BANKER = 131072,
      PETITIONER = 262144,
      TABARD_DESIGNER = 524288,
      BATTLEMASTER = 1048576,
      AUCTIONEER = 2097152,
      STABLEMASTER = 4194304,
      BARBER = 33554432,
      ARCANE_REFORGER = 134217728,
      TRANSMOGRIFIER = 268435456,
    },
    raceKeys = {
      NONE = 0,
      HUMAN = raceMaskById[1],
      ORC = raceMaskById[2],
      DWARF = raceMaskById[3],
      NIGHT_ELF = raceMaskById[4],
      UNDEAD = raceMaskById[5],
      TAUREN = raceMaskById[6],
      GNOME = raceMaskById[7],
      TROLL = raceMaskById[8],
      GOBLIN = raceMaskById[9],
      BLOOD_ELF = raceMaskById[10],
      ALL_HORDE = cataHorde,
      DRAENEI = raceMaskById[11],
      WORGEN = raceMaskById[22],
      ALL_ALLIANCE = cataAlliance,
      PANDAREN = raceMaskById[24],
      PANDAREN_ALLIANCE = raceMaskById[25],
      PANDAREN_HORDE = raceMaskById[26],
    },
  },

  MoP = {
    classKeys = {
      NONE = 0,
      WARRIOR = 1,
      PALADIN = 2,
      HUNTER = 4,
      ROGUE = 8,
      PRIEST = 16,
      DEATH_KNIGHT = 32,
      SHAMAN = 64,
      MAGE = 128,
      WARLOCK = 256,
      MONK = 512,
      DRUID = 1024,
      ALL_CLASSES = 2047,
    },
    npcFlags = {
      NONE = 0,
      GOSSIP = 1,
      QUEST_GIVER = 2,
      TRAINER = 16,
      VENDOR = 128,
      REPAIR = 4096,
      FLIGHT_MASTER = 8192,
      SPIRIT_HEALER = 16384,
      SPIRIT_GUIDE = 32768,
      INNKEEPER = 65536,
      BANKER = 131072,
      PETITIONER = 262144,
      TABARD_DESIGNER = 524288,
      BATTLEMASTER = 1048576,
      AUCTIONEER = 2097152,
      STABLEMASTER = 4194304,
      BARBER = 33554432,
      ARCANE_REFORGER = 134217728,
      TRANSMOGRIFIER = 268435456,
    },
    raceKeys = {
      NONE = 0,
      HUMAN = raceMaskById[1],
      ORC = raceMaskById[2],
      DWARF = raceMaskById[3],
      NIGHT_ELF = raceMaskById[4],
      UNDEAD = raceMaskById[5],
      TAUREN = raceMaskById[6],
      GNOME = raceMaskById[7],
      TROLL = raceMaskById[8],
      GOBLIN = raceMaskById[9],
      BLOOD_ELF = raceMaskById[10],
      DRAENEI = raceMaskById[11],
      WORGEN = raceMaskById[22],
      PANDAREN = raceMaskById[24],
      PANDAREN_ALLIANCE = raceMaskById[25],
      ALL_ALLIANCE = cataAlliance + raceMaskById[25],
      PANDAREN_HORDE = raceMaskById[26],
      ALL_HORDE = cataHorde + raceMaskById[26],
    },
  },

  -- Forever
  Forever = {
    npcFlags = {
      NONE = 0,
      GOSSIP = 1,
      QUEST_GIVER = 2,
      VENDOR = 4,
      FLIGHT_MASTER = 8,
      TRAINER = 16,
      SPIRIT_HEALER = 32,
      SPIRIT_GUIDE = 64,
      INNKEEPER = 128,
      BANKER = 256,
      PETITIONER = 512,
      TABARD_DESIGNER = 1024,
      BATTLEMASTER = 2048,
      AUCTIONEER = 4096,
      STABLEMASTER = 8192,
      REPAIR = 16384,
      BARBER = 33554432,
      TRANSMOGRIFIER = 536870912, -- using this bit since era/forever DB has some NPCs with 268435456
    },
    raceKeys = {
      NONE = 0,
      HUMAN = raceMaskById[1],
      ORC = raceMaskById[2],
      DWARF = raceMaskById[3],
      NIGHT_ELF = raceMaskById[4],
      UNDEAD = raceMaskById[5],
      TAUREN = raceMaskById[6],
      GNOME = raceMaskById[7],
      TROLL = raceMaskById[8],
      GOBLIN = raceMaskById[9],
      SKYBORNE_ALLIANCE = raceMaskById[95],
      ALL_ALLIANCE = classicAlliance + raceMaskById[95],
      SKYBORNE_HORDE = raceMaskById[96],
      ALL_HORDE = classicHorde + raceMaskById[96],
    },
  },
}
