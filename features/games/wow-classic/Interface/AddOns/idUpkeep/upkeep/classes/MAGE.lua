local R = _G.idUpkeep_UpkeepRules
local SPELL = {
  ARCANE_INTELLECT = 1459,
  ARCANE_BRILLIANCE = 23028,
  FROST_ARMOR = 168,
  ICE_ARMOR = 7302,
  MAGE_ARMOR = 6117,
  CONJURE_WATER = 5504,
  CONJURE_FOOD = 587,
  CONJURE_MANA_RUBY = 10054,
  CONJURE_MANA_CITRINE = 10053,
  CONJURE_MANA_JADE = 3552,
  CONJURE_MANA_AGATE = 759
}
local ITEM = {
  WATER = {
    5350,
    2288,
    2136,
    3772,
    8077,
    8078,
    8079
  },
  FOOD = {
    5349,
    1113,
    1114,
    1487,
    8075,
    8076,
    22895
  },
  MANA_GEMS = {
    8008,
    8007,
    5513,
    5514
  }
}
local MIN = {
  WATER = 20,
  FOOD = 10,
  MANA_GEM = 1
}
local ARMORS_INSTANCE = {
  SPELL.MAGE_ARMOR,
  SPELL.ICE_ARMOR,
  SPELL.FROST_ARMOR
}
local ARMORS_WORLD = {
  SPELL.ICE_ARMOR,
  SPELL.FROST_ARMOR,
  SPELL.MAGE_ARMOR
}
R.register("MAGE", R.classRules({
  role = "caster",
  rules = {
    R.conjure(SPELL.CONJURE_WATER, ITEM.WATER, MIN.WATER),
    R.conjure(SPELL.CONJURE_FOOD, ITEM.FOOD, MIN.FOOD),
    R.conjure({
      SPELL.CONJURE_MANA_RUBY,
      SPELL.CONJURE_MANA_CITRINE,
      SPELL.CONJURE_MANA_JADE,
      SPELL.CONJURE_MANA_AGATE
    }, ITEM.MANA_GEMS, MIN.MANA_GEM, {
      label = "Conjure mana gem"
    }),
    R.selfBuff(ARMORS_INSTANCE, {
      label = "Armor",
      when = function(snap)
        return snap.inInstance == true
      end
    }),
    R.selfBuff(ARMORS_WORLD, {
      label = "Armor",
      when = function(snap)
        return snap.inInstance ~= true
      end
    }),
    R.groupBuff(SPELL.ARCANE_INTELLECT, {
      targets = "mana",
      satisfiedBy = {
        SPELL.ARCANE_BRILLIANCE
      }
    }),
    R.weaponConsumable({
      slot = "mh",
      category = "wizardOil",
      label = "Wizard oil"
    })
  }
}))
_G.idUpkeep_UpkeepClassMAGE = {
  SPELL = SPELL,
  ITEM = ITEM
}
return SPELL
