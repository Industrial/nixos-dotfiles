local R = _G.idUpkeep_UpkeepRules
local SPELL = {
  MARK_OF_THE_WILD = 1126,
  GIFT_OF_THE_WILD = 21849,
  THORNS = 467,
  OMEN_OF_CLARITY = 16864
}
R.register("DRUID", R.classRules({
  role = "hybrid",
  rules = {
    R.groupBuff(SPELL.MARK_OF_THE_WILD, {
      targets = "all",
      satisfiedBy = {
        SPELL.GIFT_OF_THE_WILD
      }
    }),
    R.selfBuff(SPELL.THORNS),
    R.groupBuff(SPELL.THORNS, {
      targets = "tank",
      label = "Thorns (tanks)"
    }),
    R.selfBuff(SPELL.OMEN_OF_CLARITY)
  }
}))
_G.idUpkeep_UpkeepClassDRUID = SPELL
return SPELL
