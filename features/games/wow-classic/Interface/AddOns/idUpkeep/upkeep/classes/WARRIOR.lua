local R = _G.idUpkeep_UpkeepRules
local SPELL = {
  BATTLE_SHOUT = 6673,
  COMMANDING_SHOUT = 403215,
  VALOR_OF_AZEROTH = 461475
}
R.register("WARRIOR", R.classRules({
  role = "melee",
  rules = {
    R.weaponConsumable({
      slot = "mh",
      category = "stone",
      label = "Weapon stone (main hand)"
    }),
    R.weaponConsumable({
      slot = "oh",
      category = "stone",
      label = "Weapon stone (off hand)"
    }),
    R.selfBuff(SPELL.BATTLE_SHOUT, {
      short = true,
      refresh = 30
    }),
    R.selfBuff(SPELL.COMMANDING_SHOUT, {
      short = true,
      refresh = 30
    }),
    R.selfBuff(SPELL.VALOR_OF_AZEROTH)
  }
}))
_G.idUpkeep_UpkeepClassWARRIOR = SPELL
return SPELL
