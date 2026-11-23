local R = _G.idUpkeep_UpkeepRules
local ITEM = {
  INSTANT = {
    8928,
    8927,
    8926,
    6950,
    6949,
    6947
  },
  DEADLY = {
    20844,
    8985,
    8984,
    2893,
    2892
  },
  WOUND = {
    10922,
    10921,
    10920,
    10918
  },
  CRIPPLING = {
    3776,
    3775
  },
  MIND_NUMBING = {
    9186,
    6951,
    5237
  }
}
local concat
concat = function(...)
  local out = { }
  local _list_0 = {
    ...
  }
  for _index_0 = 1, #_list_0 do
    local list = _list_0[_index_0]
    for _index_1 = 1, #list do
      local id = list[_index_1]
      out[#out + 1] = id
    end
  end
  return out
end
local MAIN_HAND = concat(ITEM.INSTANT, ITEM.DEADLY, ITEM.WOUND, ITEM.CRIPPLING, ITEM.MIND_NUMBING)
local OFF_HAND = concat(ITEM.DEADLY, ITEM.INSTANT, ITEM.CRIPPLING, ITEM.WOUND, ITEM.MIND_NUMBING)
R.register("ROGUE", R.classRules({
  role = "melee",
  rules = {
    R.weaponEnchant({
      slot = "mh",
      items = MAIN_HAND,
      label = "Poison (main hand)"
    }),
    R.weaponEnchant({
      slot = "oh",
      items = OFF_HAND,
      label = "Poison (off hand)"
    }),
    R.weaponConsumable({
      slot = "mh",
      category = "stone",
      label = "Weapon stone (main hand)"
    }),
    R.weaponConsumable({
      slot = "oh",
      category = "stone",
      label = "Weapon stone (off hand)"
    })
  }
}))
_G.idUpkeep_UpkeepClassROGUE = ITEM
return ITEM
