local R = _G.idUpkeep_UpkeepRules
local SPELL = {
  DEVOTION_AURA = 465,
  RETRIBUTION_AURA = 7294,
  CONCENTRATION_AURA = 19746,
  SHADOW_RESISTANCE_AURA = 19876,
  FROST_RESISTANCE_AURA = 19888,
  FIRE_RESISTANCE_AURA = 19891,
  SANCTITY_AURA = 20218,
  BLESSING_OF_MIGHT = 19740,
  BLESSING_OF_WISDOM = 19742,
  BLESSING_OF_KINGS = 20217,
  GREATER_BLESSING_OF_MIGHT = 25782,
  GREATER_BLESSING_OF_WISDOM = 25894,
  GREATER_BLESSING_OF_KINGS = 25898,
  RIGHTEOUS_FURY = 25780,
  HORN_OF_LORDAERON = 425600
}
local OTHER_AURAS = {
  SPELL.RETRIBUTION_AURA,
  SPELL.CONCENTRATION_AURA,
  SPELL.SHADOW_RESISTANCE_AURA,
  SPELL.FROST_RESISTANCE_AURA,
  SPELL.FIRE_RESISTANCE_AURA,
  SPELL.SANCTITY_AURA
}
local MIGHT_CLASSES = {
  WARRIOR = true,
  ROGUE = true
}
local knowsKings
knowsKings = function(snap)
  local s = snap and snap.spells and snap.spells[SPELL.BLESSING_OF_KINGS]
  return (s and s.known and s.name) and true or false
end
local blessingFor
blessingFor = function(classToken, unitData)
  if MIGHT_CLASSES[classToken] then
    return "might"
  end
  if unitData and unitData.usesMana then
    return "wisdom"
  end
  return "might"
end
local wantsMight
wantsMight = function(cls, ud)
  return blessingFor(cls, ud) == "might"
end
local wantsWisdom
wantsWisdom = function(cls, ud)
  return blessingFor(cls, ud) == "wisdom"
end
-- Righteous Fury only when tanking, which for a paladin means a shield in the
-- off hand. A healer with a shield can cancel it; a two-hander never gets it.
local holdsShield
holdsShield = function(snap)
  local oh = snap and snap.weapon and snap.weapon.oh
  return (oh and oh.isShield) == true
end
local withoutKings
withoutKings = function(snap)
  return not knowsKings(snap)
end
R.register("PALADIN", R.classRules({
  role = "hybrid",
  rules = {
    R.selfBuff(SPELL.DEVOTION_AURA, {
      label = "Aura",
      satisfiedBy = OTHER_AURAS
    }),
    R.selfBuff(SPELL.RIGHTEOUS_FURY, {
      when = holdsShield
    }),
    R.selfBuff(SPELL.HORN_OF_LORDAERON, {
      short = true,
      refresh = 30
    }),
    R.groupBuff(SPELL.BLESSING_OF_KINGS, {
      targets = "all",
      satisfiedBy = {
        SPELL.GREATER_BLESSING_OF_KINGS
      },
      when = knowsKings
    }),
    R.groupBuff(SPELL.BLESSING_OF_MIGHT, {
      targets = wantsMight,
      satisfiedBy = {
        SPELL.GREATER_BLESSING_OF_MIGHT
      },
      when = withoutKings
    }),
    R.groupBuff(SPELL.BLESSING_OF_WISDOM, {
      targets = wantsWisdom,
      satisfiedBy = {
        SPELL.GREATER_BLESSING_OF_WISDOM
      },
      when = withoutKings
    })
  }
}))
_G.idUpkeep_UpkeepClassPALADIN = {
  SPELL = SPELL,
  blessingFor = blessingFor,
  holdsShield = holdsShield
}
return SPELL
