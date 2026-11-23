local M = { }
local FLASK_MIN_DURATION = 3600000 * 2
M.FLASK_MIN_DURATION = FLASK_MIN_DURATION
local STAT_AURAS = {
  APPLY_AURA = true,
  MOD_STAT = true,
  MOD_TOTAL_STAT_PERCENTAGE = true
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
  ["Consumable.Buff.Attack Power.Flask"] = unsupported("aura vocabulary unverified against a real extraction"),
  ["Consumable.Buff.Attack Power.Self"] = unsupported("aura vocabulary unverified against a real extraction"),
  ["Consumable.Buff.Spell Damage.Flask"] = unsupported("aura vocabulary unverified against a real extraction"),
  ["Consumable.Buff.Spell Damage.Self"] = unsupported("aura vocabulary unverified against a real extraction"),
  ["Consumable.Buff.Fire Power"] = unsupported("aura vocabulary unverified against a real extraction"),
  ["Consumable.Buff.Frost Power"] = unsupported("aura vocabulary unverified against a real extraction"),
  ["Consumable.Buff.Shadow Power"] = unsupported("aura vocabulary unverified against a real extraction"),
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
  ["Consumable.Food.Buff.Attack Power"] = unsupported("aura vocabulary unverified against a real extraction"),
  ["Consumable.Food.Buff.Spell Damage"] = unsupported("aura vocabulary unverified against a real extraction"),
  ["Consumable.Food.Buff.HP Regen"] = unsupported("aura vocabulary unverified against a real extraction"),
  ["Consumable.Food.Buff.Mana Regen"] = unsupported("aura vocabulary unverified against a real extraction"),
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
      return effect.miscValue == 1
    end)
  },
  ["Consumable.Weapon Buff.Stone.Weight Stone"] = {
    predicate = weaponBuff(function(effect)
      return effect.miscValue == 2
    end)
  },
  ["Consumable.Weapon Buff.Oil.Wizard"] = {
    predicate = weaponBuff(function(effect)
      return effect.miscValue == 3
    end)
  },
  ["Consumable.Weapon Buff.Oil.Mana"] = {
    predicate = weaponBuff(function(effect)
      return effect.miscValue == 4
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
  }
}
M.overrides = { }
return M
