-- Correction constants. Source origins and extraction history: PROVENANCE.md.

local _, LibQuestieDB = ...
local constants = LibQuestieDB.Enum

constants.professionKeys = {
  -- Primary crafting professions
  BLACKSMITHING = 164,
  LEATHERWORKING = 165,
  ALCHEMY = 171,
  TAILORING = 197,
  ENGINEERING = 202,
  ENCHANTING = 333,
  JEWELCRAFTING = 755,
  INSCRIPTION = 773,

  -- Primary gathering professions
  HERBALISM = 182,
  MINING = 186,
  SKINNING = 393,

  -- Secondary professions
  FIRST_AID = 129,
  COOKING = 185,
  FISHING = 356,
  ARCHAEOLOGY = 794,

  -- Riding skill
  RIDING = 762,

  -- Forever [add professions and skills here]
}

constants.rankNames = {
  APPRENTICE = 1,
  JOURNEYMAN = 2,
  EXPERT = 3,
  ARTISAN = 4,
  MASTER = 5,
  GRAND_MASTER = 6,
  ILLUSTRIOUS_GRAND_MASTER = 7,
  ZEN_MASTER = 8,

  -- Forever [add skill ranks here]
}

constants.specializationKeys = {
  -- Blacksmithing
  BLACKSMITHING = 164,
  BLACKSMITHING_WEAPON = 9787,
  BLACKSMITHING_ARMOR = 9788,
  BLACKSMITHING_WEAPON_SWORD = 17039,
  BLACKSMITHING_WEAPON_HAMMER = 17040,
  BLACKSMITHING_WEAPON_AXE = 17041,

  -- Leatherworking
  LEATHERWORKING = 165,
  LEATHERWORKING_DRAGONSCALE = 10656,
  LEATHERWORKING_ELEMENTAL = 10658,
  LEATHERWORKING_TRIBAL = 10660,

  -- Alchemy
  ALCHEMY = 171,
  ALCHEMY_TRANSMUTATION = 28672,
  ALCHEMY_POTION = 28675,
  ALCHEMY_ELIXIR = 28677,

  -- Tailoring
  TAILORING = 197,
  TAILORING_SPELLFIRE = 26797,
  TAILORING_MOONCLOTH = 26798,
  TAILORING_SHADOWEAVE = 26801,

  -- Engineering
  ENGINEERING = 202,
  ENGINEERING_GNOMISH = 20219,
  ENGINEERING_GOBLIN = 20222,

  -- Forever [add profession specializations here]
}
