local R = _G.idUpkeep_UpkeepRules
local SPELL = {
  LIGHTNING_SHIELD = 324,
  WATER_SHIELD = 408510,
  ROCKBITER_WEAPON = 8017,
  FLAMETONGUE_WEAPON = 8024,
  FROSTBRAND_WEAPON = 8033,
  WINDFURY_WEAPON = 8232
}
R.register("SHAMAN", R.classRules({
  role = "hybrid",
  rules = {
    R.selfBuff(SPELL.LIGHTNING_SHIELD, {
      satisfiedBy = {
        SPELL.WATER_SHIELD
      },
      refresh = 0
    }),
    R.weaponImbue({
      slot = "mh",
      spells = {
        SPELL.WINDFURY_WEAPON,
        SPELL.ROCKBITER_WEAPON,
        SPELL.FLAMETONGUE_WEAPON
      },
      refresh = 60,
      label = "Weapon imbue (main hand)"
    })
  }
}))
_G.idUpkeep_UpkeepClassSHAMAN = SPELL
return SPELL
