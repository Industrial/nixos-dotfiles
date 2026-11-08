-- Correction constants. Source origins and extraction history: PROVENANCE.md.

local _, LibQuestieDB = ...
local constants = LibQuestieDB.Enum

constants.questFlags = {
  NONE = 0,
  STAY_ALIVE = 1,
  PARTY_ACCEPT = 2,
  EXPLORATION = 4,
  SHARABLE = 8,
  UNUSED1 = 16,
  EPIC = 32,
  RAID = 64,
  UNUSED2 = 128,
  UNKNOWN = 256,
  HIDDEN_REWARDS = 512,
  AUTO_REWARDED = 1024,
  DAILY = 4096,
  WEEKLY = 32768,
  MONTHLY = 65536,
}

constants.specialFlags = {
  NONE = 0,
  REPEATABLE = 1,
}

constants.sortKeys = {
  -- General quest categories
  SPECIALTEMP = -1000,
  REPUTATION = -367,
  LEGENDARY = -344,
  SPECIAL = -284,
  TREASURE_MAP = -221,
  UNDERCITY = -23,
  EPIC = -1,

  -- Classes
  MONK = -395,
  DEATHKNIGHT = -372,
  DRUID = -263,
  PRIEST = -262,
  HUNTER = -261,
  ROGUE = -162,
  MAGE = -161,
  PALADIN = -141,
  SHAMAN = -82,
  WARRIOR = -81,
  WARLOCK = -61,

  -- Professions and skills
  RIDING = -398,
  ARCHAEOLOGY = -377,
  JEWELCRAFTING = -373,
  INSCRIPTION = -371,
  FIRST_AID = -324,
  COOKING = -304,
  TAILORING = -264,
  ENGINEERING = -201,
  LEATHERWORKING = -182,
  ALCHEMY = -181,
  BLACKSMITHING = -121,
  FISHING = -101,
  HERBALISM = -24,

  -- Holidays and recurring events
  WINTER_VEIL = -404,
  HARVEST_FESTIVAL = -402,
  CHILDRENS_WEEK = -378,
  LOVE_IS_IN_THE_AIR = -376,
  PILGRIMS_BOUNTY = -375,
  NOBLEGARDEN = -374,
  BREWFEST = -370,
  MIDSUMMER = -369,
  LUNAR_FESTIVAL = -366,
  DARKMOON_FAIRE = -364,
  DAY_OF_THE_DEAD = -41,
  SEASONAL = -22,
  HALLOWS_END = -21,

  -- Classic and Wrath: battlegrounds and world events
  INVASION = -368,
  AHN_QIRAJ_WAR = -365,
  TOURNAMENT = -241,
  BATTLEGROUNDS = -25,

  -- Cataclysm: campaigns
  ELEMENTAL_BONDS = -381,
  THE_ZANDALARI = -380,
  FIRELANDS_INVASION = -379,

  -- Mists of Pandaria: campaigns and activities
  PROVING_GROUNDS = -400,
  BRAWLERS_GUILD = -399,
  PANDAREN_CAMPAIGN = -397,
  LANDFALL = -396,
  PET_BATTLE = -394,
  SCENARIO = -392,
  PANDAREN_BREWMASTERS = -391,

  -- Seasonal realms: Season of Discovery and Titan Reforged
  TITAN_REFORGED_REALM = -662,
  BLACKROCK_ERUPTION = -644,
  NIGHTMARE_INCURSIONS = -641,

  -- Forever [quest categories]
  NIGHT_ELF = -676,
  CAMPING = -666,
  THE_HIGH_ORDER = -660,
}
