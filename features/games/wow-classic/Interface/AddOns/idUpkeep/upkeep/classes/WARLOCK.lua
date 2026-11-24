local R = _G.idUpkeep_UpkeepRules
local SPELL = {
  SUMMON_IMP = 688,
  SUMMON_VOIDWALKER = 697,
  SUMMON_SUCCUBUS = 712,
  SUMMON_FELHUNTER = 691,
  DEMON_SKIN = 687,
  DEMON_ARMOR = 706,
  FEL_ARMOR = 403619,
  CREATE_HEALTHSTONE = {
    11730,
    11729,
    5699,
    6202,
    6201
  },
  CREATE_SOULSTONE = {
    20757,
    20756,
    20755,
    20752,
    693
  }
}
local ITEM = {
  HEALTHSTONES = {
    9421,
    5510,
    5509,
    5511,
    5512,
    19012,
    19013,
    19010,
    19011,
    19008,
    19009,
    19006,
    19007,
    19004,
    19005
  },
  SOULSTONES = {
    16896,
    16895,
    16893,
    16892,
    5232
  },
  SOUL_SHARD = 6265
}
local SHARD_DEMONS = {
  SPELL.SUMMON_FELHUNTER,
  SPELL.SUMMON_SUCCUBUS,
  SPELL.SUMMON_VOIDWALKER
}
local shardDemonReady
shardDemonReady = function(snap)
  for _index_0 = 1, #SHARD_DEMONS do
    local id = SHARD_DEMONS[_index_0]
    local s = snap.spells and snap.spells[id]
    if s and s.known and s.name then
      return s.usable ~= false
    end
  end
  return false
end
R.register("WARLOCK", R.classRules({
  role = "caster",
  rules = {
    R.petStep({
      summon = SHARD_DEMONS,
      label = "Demon",
      when = shardDemonReady
    }),
    R.petStep({
      summon = SPELL.SUMMON_IMP,
      label = "Demon",
      when = function(snap)
        return not shardDemonReady(snap)
      end
    }),
    R.conjure(SPELL.CREATE_HEALTHSTONE, ITEM.HEALTHSTONES, 1, {
      label = "Create Healthstone"
    }),
    R.conjure(SPELL.CREATE_SOULSTONE, ITEM.SOULSTONES, 1, {
      label = "Create Soulstone"
    }),
    R.selfBuff({
      SPELL.FEL_ARMOR,
      SPELL.DEMON_ARMOR,
      SPELL.DEMON_SKIN
    }, {
      label = "Demon Armor"
    })
  }
}))
_G.idUpkeep_UpkeepClassWARLOCK = {
  SPELL = SPELL,
  ITEM = ITEM
}
return SPELL
