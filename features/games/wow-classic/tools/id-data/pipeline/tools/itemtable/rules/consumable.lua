local M = { }
local FLASK_MIN_DURATION = 3600000 * 2
M.FLASK_MIN_DURATION = FLASK_MIN_DURATION
local STAT_AURAS = {
  APPLY_AURA = true,
  MOD_STAT = true,
  MOD_TOTAL_STAT_PERCENTAGE = true,
  -- Armor elixirs: the adapter names physical-school MOD_RESISTANCE as statType "ARMOR".
  MOD_RESISTANCE = true
}
local statAura
statAura = function(ctx, item, stat)
  local pair = ctx.findEffect(item, function(effect)
    return STAT_AURAS[effect.auraType or ""] and effect.statType == stat
  end)
  if not (pair) then
    return nil
  end
  return math.abs(pair.effect.amount or 1), pair.spell
end
local statBuff
statBuff = function(stat, kind)
  return function(ctx, item)
    -- A food's stats are Well Fed, owned by the Consumable.Food.Buff.* sets;
    -- counting them here would offer a fish as a Stamina elixir.
    if item.subclass == "Food" then
      return nil
    end
    local amount, spell = statAura(ctx, item, stat)
    if not (amount) then
      return nil
    end
    local duration = spell.duration or 0
    local isFlask = duration >= FLASK_MIN_DURATION
    if kind == "flask" and not isFlask then
      return nil
    end
    if kind == "self" and isFlask then
      return nil
    end
    return amount
  end
end
local isFood
isFood = function(ctx, item)
  return item.subclass == "Food"
end
local foodBuff
foodBuff = function(stat)
  return function(ctx, item)
    if not (isFood(ctx, item)) then
      return nil
    end
    local amount = statAura(ctx, item, stat)
    return amount
  end
end
local restores
restores = function(auraType)
  return function(ctx, item)
    local pair = ctx.findEffect(item, function(effect)
      return effect.auraType == auraType
    end)
    if not (pair) then
      return nil
    end
    return math.abs(pair.effect.amount or 1)
  end
end
local instantRestore
instantRestore = function(auraType)
  return function(ctx, item)
    local pair = ctx.findEffect(item, function(effect)
      return effect.auraType == auraType
    end)
    if not (pair) then
      return nil
    end
    return math.abs(pair.effect.amount or 1)
  end
end
local potion
potion = function(auraType)
  return function(ctx, item)
    if not (item.subclass == "Potion") then
      return nil
    end
    return instantRestore(auraType)(ctx, item)
  end
end
local isConjured
isConjured = function(item)
  return (item.name or ""):lower():find("conjured", 1, true) ~= nil
end
local weaponBuff
weaponBuff = function(discriminator)
  return function(ctx, item)
    local pair = ctx.findEffect(item, function(effect)
      return effect.auraType == "ENCHANT_HELD_ITEM"
    end)
    if not (pair) then
      return nil
    end
    if not (discriminator(pair.effect, item)) then
      return nil
    end
    return math.abs(pair.effect.amount or 1)
  end
end
-- AURA BUFFS, verified against Forever 1.60.1.71037 (tools/id-data). A
-- buff of `auraType` on the item's own use spell (index < 100: not a
-- triggered restore or Well Fed tick), split flask / self by duration like
-- statBuff. Food never counts: its stats are Well Fed, which the food sets own.
local auraBuff = function(auraType, kind, miscTest)
  return function(ctx, item)
    if item.subclass == "Food" then
      return nil
    end
    local pair = ctx.findEffect(item, function(effect)
      return effect.auraType == auraType and (effect.index or 1) < 100
        and (miscTest == nil or miscTest(effect.miscValue))
    end)
    if not pair then
      return nil
    end
    local isFlask = (pair.spell.duration or 0) >= FLASK_MIN_DURATION
    if kind == "flask" and not isFlask then
      return nil
    end
    if kind == "self" and isFlask then
      return nil
    end
    return math.abs(pair.effect.amount or 1)
  end
end
-- Well Fed: a buff the food's periodic trigger applies (index >= 200).
local wellFed = function(auraType, miscTest)
  return function(ctx, item)
    if not isFood(ctx, item) then
      return nil
    end
    local pair = ctx.findEffect(item, function(effect)
      return effect.auraType == auraType and (effect.index or 1) >= 200
        and (miscTest == nil or miscTest(effect.miscValue))
    end)
    return pair and math.abs(pair.effect.amount or 1) or nil
  end
end
-- MOD_DAMAGE_DONE's misc is a school mask: 126 is every magic school, a
-- single bit is one school (4 fire, 16 frost, 32 shadow).
local ALL_MAGIC = function(mask) return mask == 126 or mask == 127 end
local SCHOOL = function(bit) return function(mask) return mask == bit end end
-- Effects an upkeep consumable is made of. An item carrying any of these is
-- never excluded as out of scope: it either matches a set or blocks the gate.
M.UPKEEP_AURAS = {
  PERIODIC_HEAL = true, PERIODIC_ENERGIZE = true, HEAL = true, ENERGIZE = true,
  MOD_STAT = true, MOD_TOTAL_STAT_PERCENTAGE = true, APPLY_AURA = true,
  MOD_ATTACK_POWER = true, MOD_RANGED_ATTACK_POWER = true, MOD_DAMAGE_DONE = true,
  MOD_RESISTANCE = true, MOD_HEALTH_REGEN_IN_COMBAT = true, MOD_INCREASE_HEALTH = true,
  OBS_MOD_HEALTH = true, OBS_MOD_POWER = true
}
-- Named effects known to have no upkeep set. A raw client number is an aura
-- the adapter deliberately leaves unnamed; a NAME outside both lists is new
-- vocabulary the rules have never seen, so it is never excluded.
M.OTHER_AURAS = {
  PERIODIC_DAMAGE = true, SCHOOL_ABSORB = true, CREATE_ITEM = true, SUMMON = true,
  ENCHANT_HELD_ITEM = true
}
local knownIrrelevant
knownIrrelevant = function(effect)
  local aura = effect.auraType
  if aura == nil or tonumber(aura) ~= nil then
    return true
  end
  if M.UPKEEP_AURAS[aura] then
    return false
  end
  if aura == "ENCHANT_HELD_ITEM" then
    return (effect.enchantKind or "OTHER") == "OTHER"
  end
  return M.OTHER_AURAS[aura] == true
end
local unsupported
unsupported = function(reason)
  return {
    unsupported = reason
  }
end
M.scope = function(item)
  return item.class == "Consumable"
end
M.sets = {
  ["Consumable.Buff.Agility.Flask"] = {
    predicate = statBuff("AGILITY", "flask")
  },
  ["Consumable.Buff.Agility.Self"] = {
    predicate = statBuff("AGILITY", "self")
  },
  ["Consumable.Buff.Intellect.Flask"] = {
    predicate = statBuff("INTELLECT", "flask")
  },
  ["Consumable.Buff.Intellect.Self"] = {
    predicate = statBuff("INTELLECT", "self")
  },
  ["Consumable.Buff.Strength.Flask"] = {
    predicate = statBuff("STRENGTH", "flask")
  },
  ["Consumable.Buff.Strength.Self"] = {
    predicate = statBuff("STRENGTH", "self")
  },
  ["Consumable.Buff.Stamina.Self"] = {
    predicate = statBuff("STAMINA", "self")
  },
  ["Consumable.Buff.Health.Flask"] = {
    predicate = statBuff("HEALTH", "flask")
  },
  ["Consumable.Buff.Regen Mana.Flask"] = {
    predicate = statBuff("MANA", "flask")
  },
  ["Consumable.Buff.Regen Mana.Self"] = {
    predicate = statBuff("MANA", "self")
  },
  ["Consumable.Buff.Armor.Self"] = {
    predicate = statBuff("ARMOR", "self")
  },
  ["Consumable.Buff.Agility.Target"] = unsupported("model has no targeting data"),
  ["Consumable.Buff.Armor.Target"] = unsupported("model has no targeting data"),
  ["Consumable.Buff.Intellect.Target"] = unsupported("model has no targeting data"),
  ["Consumable.Buff.Stamina.Target"] = unsupported("model has no targeting data"),
  ["Consumable.Buff.Strength.Target"] = unsupported("model has no targeting data"),
  ["Consumable.Buff.Attack Power.Flask"] = {
    predicate = auraBuff("MOD_ATTACK_POWER", "flask")
  },
  ["Consumable.Buff.Attack Power.Self"] = {
    predicate = auraBuff("MOD_ATTACK_POWER", "self")
  },
  ["Consumable.Buff.Spell Damage.Flask"] = {
    predicate = auraBuff("MOD_DAMAGE_DONE", "flask", ALL_MAGIC)
  },
  ["Consumable.Buff.Spell Damage.Self"] = {
    predicate = auraBuff("MOD_DAMAGE_DONE", "self", ALL_MAGIC)
  },
  ["Consumable.Buff.Fire Power"] = {
    predicate = auraBuff("MOD_DAMAGE_DONE", nil, SCHOOL(4))
  },
  ["Consumable.Buff.Frost Power"] = {
    predicate = auraBuff("MOD_DAMAGE_DONE", nil, SCHOOL(16))
  },
  ["Consumable.Buff.Shadow Power"] = {
    predicate = auraBuff("MOD_DAMAGE_DONE", nil, SCHOOL(32))
  },
  ["Consumable.Food.Buff.Agility"] = {
    predicate = foodBuff("AGILITY")
  },
  ["Consumable.Food.Buff.Intellect"] = {
    predicate = foodBuff("INTELLECT")
  },
  ["Consumable.Food.Buff.Spirit"] = {
    predicate = foodBuff("SPIRIT")
  },
  ["Consumable.Food.Buff.Stamina"] = {
    predicate = foodBuff("STAMINA")
  },
  ["Consumable.Food.Buff.Strength"] = {
    predicate = foodBuff("STRENGTH")
  },
  ["Consumable.Food.Buff.Attack Power"] = {
    predicate = wellFed("MOD_ATTACK_POWER")
  },
  ["Consumable.Food.Buff.Spell Damage"] = {
    predicate = wellFed("MOD_DAMAGE_DONE", ALL_MAGIC)
  },
  ["Consumable.Food.Buff.HP Regen"] = {
    predicate = wellFed("MOD_HEALTH_REGEN_IN_COMBAT")
  },
  -- Aura 85 restores mana while seated (the drink) AND is the mp5 Well Fed
  -- buff; the band (>= 200) is what tells them apart.
  ["Consumable.Food.Buff.Mana Regen"] = {
    predicate = wellFed("PERIODIC_ENERGIZE")
  },
  ["Consumable.Food.Edible.Basic.Conjured"] = {
    predicate = function(ctx, item)
      if not (isFood(ctx, item)) then
        return nil
      end
      if not (isConjured(item)) then
        return nil
      end
      return restores("PERIODIC_HEAL")(ctx, item)
    end
  },
  ["Consumable.Food.Edible.Basic.Non-Conjured"] = {
    predicate = function(ctx, item)
      if not (isFood(ctx, item)) then
        return nil
      end
      if isConjured(item) then
        return nil
      end
      return restores("PERIODIC_HEAL")(ctx, item)
    end
  },
  ["Consumable.Water.Conjured"] = {
    predicate = function(ctx, item)
      if not (isConjured(item)) then
        return nil
      end
      return restores("PERIODIC_ENERGIZE")(ctx, item)
    end
  },
  ["Consumable.Water.Basic"] = {
    predicate = function(ctx, item)
      if isConjured(item) then
        return nil
      end
      return restores("PERIODIC_ENERGIZE")(ctx, item)
    end
  },
  ["Consumable.Potion.Recovery.Healing.Basic"] = {
    predicate = potion("HEAL")
  },
  ["Consumable.Potion.Recovery.Mana.Basic"] = {
    predicate = potion("ENERGIZE")
  },
  ["Consumable.Bandage.Basic"] = {
    predicate = function(ctx, item)
      if not (item.subclass == "Bandage") then
        return nil
      end
      local amount = instantRestore("HEAL")(ctx, item)
      return amount or restores("PERIODIC_HEAL")(ctx, item)
    end
  },
  ["Consumable.Cooldown.Potion.Health.Basic"] = unsupported("model has no spell cooldown-category field"),
  ["Consumable.Cooldown.Potion.Mana.Basic"] = unsupported("model has no spell cooldown-category field"),
  ["Consumable.Cooldown.Stone.Health.Warlock"] = unsupported("model has no spell -> created-item link"),
  ["Consumable.Cooldown.Stone.Mana.Mana Stone"] = unsupported("model has no spell -> created-item link"),
  ["Consumable.Weapon Buff.Stone.Sharpening Stone"] = {
    predicate = weaponBuff(function(effect)
      return effect.enchantKind == "SHARPEN"
    end)
  },
  ["Consumable.Weapon Buff.Stone.Weight Stone"] = {
    predicate = weaponBuff(function(effect)
      return effect.enchantKind == "WEIGHT"
    end)
  },
  ["Consumable.Weapon Buff.Oil.Wizard"] = {
    predicate = weaponBuff(function(effect)
      return effect.enchantKind == "WIZARD_OIL"
    end)
  },
  ["Consumable.Weapon Buff.Oil.Mana"] = {
    predicate = weaponBuff(function(effect)
      return effect.enchantKind == "MANA_OIL"
    end)
  }
}
M.exclusions = {
  {
    reason = "no use effect: nothing to classify",
    match = function(ctx, item)
      return ctx.hasNoEffect(item)
    end
  },
  {
    reason = "use effect has no recognised aura",
    match = function(ctx, item)
      return #ctx.effectsOf(item) == 0
    end
  },
  -- SCOPE: the sets above are what idUpkeep asks for (food, water, potions,
  -- bandages, stones, elixirs/flasks, weapon stones and oils). The categories
  -- below have no set because nothing consumes them; each is excluded by what
  -- the item DOES, never by its id. An item with any upkeep-relevant effect
  -- is never excluded here, so a real miss still blocks the gate.
  {
    reason = "gear or weapon enchant with no upkeep set (engraving runes, proc oils)",
    match = function(ctx, item)
      return ctx.findEffect(item, function(effect)
        return effect.auraType == "ENCHANT_HELD_ITEM" and (effect.enchantKind or "OTHER") == "OTHER"
      end) ~= nil and ctx.findEffect(item, function(effect)
        return M.UPKEEP_AURAS[effect.auraType or ""] == true
      end) == nil
    end
  },
  {
    reason = "permanent item enhancement (armor kits, weapon chains, scopes)",
    match = function(ctx, item)
      return item.subclass == "Item Enhancement"
    end
  },
  {
    reason = "explosive or engineering device",
    match = function(ctx, item)
      return item.subclass == "Explosives"
    end
  },
  {
    reason = "use effect neither restores, buffs a stat nor enchants a weapon",
    match = function(ctx, item)
      return ctx.findEffect(item, function(effect)
        return not knownIrrelevant(effect)
      end) == nil
    end
  }
}
M.overrides = { }
return M
