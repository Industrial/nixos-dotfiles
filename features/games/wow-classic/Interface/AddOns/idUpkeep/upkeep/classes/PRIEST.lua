local R = _G.idUpkeep_UpkeepRules
local SPELL = {
  INNER_FIRE = 588,
  POWER_WORD_FORTITUDE = 1243,
  PRAYER_OF_FORTITUDE = 21562,
  DIVINE_SPIRIT = 14752,
  PRAYER_OF_SPIRIT = 27681,
  SHADOW_PROTECTION = 976,
  PRAYER_OF_SHADOW_PROTECTION = 27683,
  FEAR_WARD = 6346,
  SHADOWGUARD = 18137,
  TOUCH_OF_WEAKNESS = 2652
}
R.register("PRIEST", R.classRules({
  role = "caster",
  rules = {
    R.selfBuff(SPELL.INNER_FIRE),
    R.groupBuff(SPELL.POWER_WORD_FORTITUDE, {
      targets = "all",
      satisfiedBy = {
        SPELL.PRAYER_OF_FORTITUDE
      }
    }),
    R.groupBuff(SPELL.DIVINE_SPIRIT, {
      targets = "mana",
      satisfiedBy = {
        SPELL.PRAYER_OF_SPIRIT
      }
    }),
    R.groupBuff(SPELL.SHADOW_PROTECTION, {
      targets = "all",
      satisfiedBy = {
        SPELL.PRAYER_OF_SHADOW_PROTECTION
      }
    }),
    R.selfBuff(SPELL.FEAR_WARD),
    R.selfBuff(SPELL.SHADOWGUARD),
    R.selfBuff(SPELL.TOUCH_OF_WEAKNESS)
  }
}))
_G.idUpkeep_UpkeepClassPRIEST = SPELL
return SPELL
