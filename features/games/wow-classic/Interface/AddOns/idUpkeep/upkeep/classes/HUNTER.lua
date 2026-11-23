local R = _G.idUpkeep_UpkeepRules
local SPELL = {
  CALL_PET = 883,
  REVIVE_PET = 982,
  ASPECT_OF_THE_HAWK = 13165,
  ASPECT_OF_THE_MONKEY = 13163,
  ASPECT_OF_THE_CHEETAH = 5118,
  ASPECT_OF_THE_PACK = 13159,
  ASPECT_OF_THE_WILD = 20043,
  ASPECT_OF_THE_BEAST = 13161,
  TRUESHOT_AURA = 19506
}
local OTHER_ASPECTS = {
  SPELL.ASPECT_OF_THE_CHEETAH,
  SPELL.ASPECT_OF_THE_PACK,
  SPELL.ASPECT_OF_THE_WILD,
  SPELL.ASPECT_OF_THE_BEAST
}
local notStrength
notStrength = function(list)
  local _accum_0 = { }
  local _len_0 = 1
  for _index_0 = 1, #list do
    local c = list[_index_0]
    if not c.set:find("%.Strength") then
      _accum_0[_len_0] = c
      _len_0 = _len_0 + 1
    end
  end
  return _accum_0
end
R.register("HUNTER", R.classRules({
  role = "melee",
  consumables = notStrength(R.CONSUMABLES),
  foodBuffs = notStrength(R.FOOD_BUFFS),
  rules = {
    R.petStep({
      summon = SPELL.CALL_PET,
      revive = SPELL.REVIVE_PET
    }),
    R.selfBuff({
      SPELL.ASPECT_OF_THE_HAWK,
      SPELL.ASPECT_OF_THE_MONKEY
    }, {
      satisfiedBy = OTHER_ASPECTS,
      label = "Aspect"
    }),
    R.selfBuff(SPELL.TRUESHOT_AURA)
  }
}))
_G.idUpkeep_UpkeepClassHUNTER = {
  SPELL = SPELL
}
return SPELL
