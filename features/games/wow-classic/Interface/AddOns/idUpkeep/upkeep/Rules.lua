local lua_type = _G.type
local Rules = { }
Rules.PHASES = {
  "pet",
  "conjure",
  "selfLong",
  "group",
  "weapon",
  "consumables",
  "foodBuff",
  "selfShort",
  "rest"
}
local asList
asList = function(x)
  if x == nil then
    return { }
  end
  if lua_type(x) == "table" then
    return x
  end
  return {
    x
  }
end
Rules.asList = asList
Rules.selfBuff = function(spell, opts)
  if opts == nil then
    opts = { }
  end
  return {
    kind = "selfBuff",
    phases = {
      [opts.short and "selfShort" or "selfLong"] = true
    },
    spells = asList(spell),
    satisfiedBy = asList(opts.satisfiedBy),
    auraNames = asList(opts.auraNames),
    refresh = opts.refresh or (opts.short and 30 or 60),
    when = opts.when,
    label = opts.label
  }
end
Rules.groupBuff = function(spell, opts)
  if opts == nil then
    opts = { }
  end
  return {
    kind = "groupBuff",
    phases = {
      selfLong = true,
      group = true
    },
    spells = asList(spell),
    satisfiedBy = asList(opts.satisfiedBy),
    auraNames = asList(opts.auraNames),
    refresh = opts.refresh or 60,
    targets = opts.targets or "all",
    includePet = opts.includePet ~= false,
    when = opts.when,
    label = opts.label
  }
end
Rules.petStep = function(opts)
  if opts == nil then
    opts = { }
  end
  return {
    kind = "pet",
    phases = {
      pet = true
    },
    summon = asList(opts.summon),
    revive = opts.revive,
    when = opts.when,
    label = opts.label
  }
end
Rules.conjure = function(spell, items, minCount, opts)
  if minCount == nil then
    minCount = 1
  end
  if opts == nil then
    opts = { }
  end
  return {
    kind = "conjure",
    phases = {
      conjure = true
    },
    spells = asList(spell),
    items = asList(items),
    minCount = minCount,
    when = opts.when,
    label = opts.label
  }
end
Rules.weaponEnchant = function(opts)
  if opts == nil then
    opts = { }
  end
  return {
    kind = "weaponEnchant",
    phases = {
      weapon = true
    },
    slot = opts.slot or "mh",
    items = asList(opts.items),
    refresh = opts.refresh or 60,
    when = opts.when,
    label = opts.label
  }
end
Rules.weaponImbue = function(opts)
  if opts == nil then
    opts = { }
  end
  return {
    kind = "weaponImbue",
    phases = {
      weapon = true
    },
    slot = opts.slot or "mh",
    spells = asList(opts.spells),
    refresh = opts.refresh or 60,
    when = opts.when,
    label = opts.label
  }
end
Rules.weaponConsumable = function(opts)
  if opts == nil then
    opts = { }
  end
  return {
    kind = "weaponConsumable",
    phases = {
      weapon = true
    },
    slot = opts.slot or "mh",
    category = opts.category or "stone",
    refresh = opts.refresh or 60,
    when = opts.when,
    label = opts.label
  }
end
local MELEE = {
  melee = true
}
local CASTER = {
  caster = true
}
Rules.CONSUMABLES = {
  {
    set = "Consumable.Buff.Health.Flask",
    flask = true,
    label = "Flask (health)"
  },
  {
    set = "Consumable.Buff.Spell Damage.Flask",
    flask = true,
    roles = CASTER,
    label = "Flask (spell power)"
  },
  {
    set = "Consumable.Buff.Intellect.Flask",
    flask = true,
    roles = CASTER,
    label = "Flask (intellect)"
  },
  {
    set = "Consumable.Buff.Regen Mana.Flask",
    flask = true,
    roles = CASTER,
    label = "Flask (mana regen)"
  },
  {
    set = "Consumable.Buff.Strength.Flask",
    flask = true,
    roles = MELEE,
    label = "Flask (strength)"
  },
  {
    set = "Consumable.Buff.Agility.Flask",
    flask = true,
    roles = MELEE,
    label = "Flask (agility)"
  },
  {
    set = "Consumable.Buff.Attack Power.Flask",
    flask = true,
    roles = MELEE,
    label = "Flask (attack power)"
  },
  {
    set = "Consumable.Buff.Agility.Self",
    roles = MELEE,
    label = "Agility elixir"
  },
  {
    set = "Consumable.Buff.Strength.Self",
    roles = MELEE,
    label = "Strength elixir"
  },
  {
    set = "Consumable.Buff.Attack Power.Self",
    roles = MELEE,
    label = "Attack power elixir"
  },
  {
    set = "Consumable.Buff.Spell Damage.Self",
    roles = CASTER,
    label = "Spell power elixir"
  },
  {
    set = "Consumable.Buff.Intellect.Self",
    roles = CASTER,
    label = "Intellect elixir"
  },
  {
    set = "Consumable.Buff.Regen Mana.Self",
    roles = CASTER,
    label = "Mana regen elixir"
  },
  {
    set = "Consumable.Buff.Fire Power",
    roles = CASTER,
    label = "Fire power elixir"
  },
  {
    set = "Consumable.Buff.Frost Power",
    roles = CASTER,
    label = "Frost power elixir"
  },
  {
    set = "Consumable.Buff.Shadow Power",
    roles = CASTER,
    label = "Shadow power elixir"
  },
  {
    set = "Consumable.Buff.Armor.Self",
    label = "Armor elixir"
  },
  {
    set = "Consumable.Buff.Stamina.Self",
    label = "Stamina elixir"
  },
  {
    set = "Consumable.Buff.Agility.Target",
    roles = MELEE,
    label = "Agility scroll"
  },
  {
    set = "Consumable.Buff.Strength.Target",
    roles = MELEE,
    label = "Strength scroll"
  },
  {
    set = "Consumable.Buff.Intellect.Target",
    roles = CASTER,
    label = "Intellect scroll"
  },
  {
    set = "Consumable.Buff.Stamina.Target",
    label = "Stamina scroll"
  },
  {
    set = "Consumable.Buff.Armor.Target",
    label = "Protection scroll"
  }
}
Rules.FOOD_BUFFS = {
  {
    set = "Consumable.Food.Buff.Strength",
    roles = MELEE
  },
  {
    set = "Consumable.Food.Buff.Agility",
    roles = MELEE
  },
  {
    set = "Consumable.Food.Buff.Attack Power",
    roles = MELEE
  },
  {
    set = "Consumable.Food.Buff.Spell Damage",
    roles = CASTER
  },
  {
    set = "Consumable.Food.Buff.Intellect",
    roles = CASTER
  },
  {
    set = "Consumable.Food.Buff.Mana Regen",
    roles = CASTER
  },
  {
    set = "Consumable.Food.Buff.Spirit",
    roles = CASTER
  },
  {
    set = "Consumable.Food.Buff.Stamina"
  },
  {
    set = "Consumable.Food.Buff.HP Regen"
  }
}
-- Conjured is a property of the ITEM, not of the set an item library happens
-- to file it in: LibPeriodicTable files mage bread and water under its Basic
-- sets. Every mage item is named "Conjured ...", so the name decides too.
Rules.isConjuredName = function(name)
  if not (lua_type(name) == "string") then
    return false
  end
  return (name:lower():find("conjured", 1, true)) ~= nil
end
Rules.isConjured = function(fromSet, name)
  return fromSet == true or Rules.isConjuredName(name)
end
-- THE restore ranking, shared by every food/water/health/mana pick: any
-- conjured item before any other (free, and gone on logout anyway), then the
-- caller's tier, then the bigger restore, then the smaller stack (use it up),
-- then the lower id. True when `a` ranks before `b`.
Rules.betterRestore = function(a, b)
  local aConjured, bConjured = a.conjured == true, b.conjured == true
  if aConjured ~= bConjured then
    return aConjured
  end
  local at, bt = (a.tier or 1), (b.tier or 1)
  if at ~= bt then
    return at < bt
  end
  local av, bv = (a.value or 0), (b.value or 0)
  if av ~= bv then
    return av > bv
  end
  local ac, bc = (a.count or 0), (b.count or 0)
  if ac ~= bc then
    return ac < bc
  end
  return (a.itemId or 0) < (b.itemId or 0)
end
Rules.FOOD_SETS = {
  {
    set = "Consumable.Food.Edible.Basic.Conjured",
    conjured = true
  },
  {
    set = "Consumable.Food.Edible.Basic.Non-Conjured"
  }
}
Rules.WATER_SETS = {
  {
    set = "Consumable.Water.Conjured",
    conjured = true
  },
  {
    set = "Consumable.Water.Basic"
  }
}
Rules.WEAPON_SETS = {
  sharpening = "Consumable.Weapon Buff.Stone.Sharpening Stone",
  weight = "Consumable.Weapon Buff.Stone.Weight Stone",
  wizardOil = "Consumable.Weapon Buff.Oil.Wizard",
  manaOil = "Consumable.Weapon Buff.Oil.Mana"
}
Rules.AURA_SPELLS = {
  food = {
    433
  },
  drink = {
    430
  },
  wellFed = {
    19705,
    19706,
    19708,
    19709,
    19710,
    19711,
    24870,
    24799,
    25694,
    25941
  },
  wellFedById = {
    18191,
    25661,
    18192,
    18193,
    22730,
    18194,
    18222,
    18125
  }
}
Rules.AURA_FALLBACK_NAMES = {
  food = {
    "Food"
  },
  drink = {
    "Drink"
  },
  wellFed = {
    "Well Fed"
  }
}
local roleAllows
roleAllows = function(roles, role)
  if not (roles) then
    return true
  end
  if role == "hybrid" or role == nil then
    return true
  end
  return roles[role] == true
end
Rules.roleAllows = roleAllows
Rules.classRules = function(def)
  if def == nil then
    def = { }
  end
  local role = def.role or "hybrid"
  return {
    class = def.class,
    role = role,
    rules = def.rules or { },
    consumables = (function()
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = (def.consumables or Rules.CONSUMABLES)
      for _index_0 = 1, #_list_0 do
        local c = _list_0[_index_0]
        if roleAllows(c.roles, role) then
          _accum_0[_len_0] = c
          _len_0 = _len_0 + 1
        end
      end
      return _accum_0
    end)(),
    foodBuffs = (function()
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = (def.foodBuffs or Rules.FOOD_BUFFS)
      for _index_0 = 1, #_list_0 do
        local c = _list_0[_index_0]
        if roleAllows(c.roles, role) then
          _accum_0[_len_0] = c
          _len_0 = _len_0 + 1
        end
      end
      return _accum_0
    end)()
  }
end
Rules.classes = Rules.classes or { }
Rules.register = function(classToken, classRules)
  classRules.class = classToken
  Rules.classes[classToken] = classRules
  return classRules
end
Rules.forClass = function(classToken)
  return Rules.classes[classToken] or Rules.classRules({
    class = classToken,
    role = "hybrid"
  })
end
Rules.collectSpellIds = function(classRules)
  local seen, list = { }, { }
  local add
  add = function(id)
    if not (id and not seen[id]) then
      return 
    end
    seen[id] = true
    return table.insert(list, id)
  end
  local _list_0 = (classRules and classRules.rules or { })
  for _index_0 = 1, #_list_0 do
    local rule = _list_0[_index_0]
    local _list_1 = (rule.spells or { })
    for _index_1 = 1, #_list_1 do
      local id = _list_1[_index_1]
      add(id)
    end
    local _list_2 = (rule.satisfiedBy or { })
    for _index_1 = 1, #_list_2 do
      local id = _list_2[_index_1]
      add(id)
    end
    local _list_3 = (rule.summon or { })
    for _index_1 = 1, #_list_3 do
      local id = _list_3[_index_1]
      add(id)
    end
    add(rule.revive)
  end
  for _, ids in pairs(Rules.AURA_SPELLS) do
    for _index_0 = 1, #ids do
      local id = ids[_index_0]
      add(id)
    end
  end
  return list
end
_G.idUpkeep_UpkeepRules = Rules
return Rules
