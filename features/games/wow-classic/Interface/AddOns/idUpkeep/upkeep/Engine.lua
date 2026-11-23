local tonumber
tonumber = function(v)
  return _G.tonumber(v)
end
local lua_type = _G.type
local tostring = _G.tostring
local Engine = { }
local PHASES = {
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
Engine.PHASES = PHASES
Engine.PHASE_GROUPS = {
  buffs = {
    "pet",
    "conjure",
    "selfLong",
    "group",
    "weapon",
    "consumables",
    "foodBuff",
    "selfShort"
  },
  rest = {
    "rest"
  }
}
Engine.phaseFilter = function(phases)
  if not (phases) then
    return nil
  end
  local list
  if lua_type(phases) == "string" then
    list = Engine.PHASE_GROUPS[phases]
  else
    list = phases
  end
  if not (list) then
    return nil
  end
  local set = { }
  for _index_0 = 1, #list do
    local name = list[_index_0]
    set[name] = true
  end
  return set
end
local PARTY_UNITS = {
  "party1",
  "party2",
  "party3",
  "party4"
}
local SLOT_IDS = {
  mh = 16,
  oh = 17
}
local INF = math.huge
local DEFAULT_OPTS = {
  restThreshold = 80,
  includeParty = true,
  useConsumables = true
}
local withDefaults
withDefaults = function(opts)
  local o = { }
  for k, v in pairs(DEFAULT_OPTS) do
    o[k] = v
  end
  if opts then
    for k, v in pairs(opts) do
      o[k] = v
    end
  end
  o.recent = o.recent or { }
  return o
end
local spellOf
spellOf = function(snap, id)
  return snap.spells and snap.spells[id]
end
local spellName
spellName = function(snap, id)
  local s = spellOf(snap, id)
  return s and s.name
end
local unitOf
unitOf = function(snap, unit)
  return snap.units and snap.units[unit]
end
local itemCount
itemCount = function(snap, id)
  return (snap.items and snap.items[id]) or 0
end
local itemUsable
itemUsable = function(snap, id)
  local info = snap.itemInfo and snap.itemInfo[id]
  if not (info) then
    return true
  end
  return info.usable ~= false
end
local itemIcon
itemIcon = function(snap, id)
  local info = snap.itemInfo and snap.itemInfo[id]
  return info and info.icon
end
local remaining
remaining = function(snap, aura)
  local exp = aura.expires
  if exp == nil or exp == 0 then
    return INF
  end
  return exp - (snap.now or 0)
end
local findAura
findAura = function(snap, unitData, ids, names)
  if not (unitData and unitData.auras) then
    return nil
  end
  local wanted = { }
  local byId = { }
  local _list_0 = (ids or { })
  for _index_0 = 1, #_list_0 do
    local id = _list_0[_index_0]
    byId[id] = true
    local n = spellName(snap, id)
    if n then
      wanted[n] = true
    end
  end
  local _list_1 = (names or { })
  for _index_0 = 1, #_list_1 do
    local n = _list_1[_index_0]
    wanted[n] = true
  end
  local _list_2 = unitData.auras
  for _index_0 = 1, #_list_2 do
    local aura = _list_2[_index_0]
    if (aura.spellId and byId[aura.spellId]) or (aura.name and wanted[aura.name]) then
      return aura
    end
  end
  return nil
end
local firstKnown
firstKnown = function(snap, ids)
  local _list_0 = (ids or { })
  for _index_0 = 1, #_list_0 do
    local id = _list_0[_index_0]
    local s = spellOf(snap, id)
    if s and s.known and s.name then
      return id, s
    end
  end
  return nil
end
local castable
castable = function(s)
  if not (s and s.known and s.name) then
    return false, "spell not known"
  end
  if s.noMana then
    return false, "insufficient mana/power"
  end
  if s.usable == false then
    return false, "spell not usable"
  end
  return true
end
local targetable
targetable = function(ud)
  if not (ud and ud.exists) then
    return false, "not present"
  end
  if ud.connected == false then
    return false, "offline"
  end
  if ud.dead then
    return false, "dead"
  end
  if ud.visible == false then
    return false, "not visible"
  end
  if ud.inRange == false then
    return false, "out of range"
  end
  return true
end
local wantsBuff
wantsBuff = function(targets, ud)
  if targets == nil or targets == "all" then
    return true
  end
  if targets == "mana" then
    return ud.usesMana == true
  end
  if lua_type(targets) == "function" then
    return (targets(ud.class, ud)) == true
  end
  return false
end
local fmtSeconds
fmtSeconds = function(s)
  if s == INF then
    return "no expiry"
  end
  return tostring(math.floor(s)) .. "s left"
end
local entry
entry = function(phase, label, status, reason, step)
  return {
    phase = phase,
    label = label,
    status = status,
    reason = reason,
    step = step
  }
end
local spellStep
spellStep = function(snap, phase, id, s, unit, label, reason)
  return {
    kind = "spell",
    spell = s.name,
    spellId = id,
    unit = unit,
    label = label,
    reason = reason,
    phase = phase,
    icon = s.icon,
    key = "spell:" .. tostring(s.name) .. ":" .. tostring(unit or '')
  }
end
local itemStep
itemStep = function(snap, phase, itemId, unit, targetSlot, label, reason)
  return {
    kind = "item",
    item = itemId,
    unit = unit,
    targetSlot = targetSlot,
    label = label,
    reason = reason,
    phase = phase,
    icon = itemIcon(snap, itemId),
    key = "item:" .. tostring(itemId) .. ":" .. tostring(targetSlot or '')
  }
end
local needsCasterForm
needsCasterForm = function(snap)
  return snap.class == "DRUID" and (tonumber(snap.shapeshiftForm) or 0) ~= 0
end
Engine.needsCasterForm = needsCasterForm
local offer
offer = function(ctx, phase, label, step)
  if ctx.opts.recent[step.key] then
    return entry(phase, label, "skip", "just used (waiting for the game to update)")
  end
  if needsCasterForm(ctx.snap) then
    step.cancelForm = true
  end
  return entry(phase, label, "do", step.reason, step)
end
local ruleLabel
ruleLabel = function(snap, rule, id)
  return rule.label or (id and spellName(snap, id)) or rule.kind
end
local whenFails
whenFails = function(rule, snap)
  return rule.when and not rule.when(snap)
end
local buffOnUnit
buffOnUnit = function(ctx, rule, phase, unit, castId, s)
  local snap = ctx.snap
  local ud = unitOf(snap, unit)
  local label = ruleLabel(snap, rule, castId)
  if unit ~= "player" then
    label = tostring(label) .. " -> " .. tostring(unit)
  end
  local ids = { }
  local _list_0 = rule.spells
  for _index_0 = 1, #_list_0 do
    local id = _list_0[_index_0]
    ids[#ids + 1] = id
  end
  local _list_1 = rule.satisfiedBy
  for _index_0 = 1, #_list_1 do
    local id = _list_1[_index_0]
    ids[#ids + 1] = id
  end
  local aura = findAura(snap, ud, ids, rule.auraNames)
  local left = aura and remaining(snap, aura)
  if aura and left > rule.refresh then
    return entry(phase, label, "done", "active (" .. tostring(fmtSeconds(left)) .. ")")
  end
  if unit ~= "player" then
    local ok, why = targetable(ud)
    if not (ok) then
      return entry(phase, label, "skip", why)
    end
  end
  local ok, why = castable(s)
  if not (ok) then
    return entry(phase, label, "skip", why)
  end
  local reason
  if aura then
    reason = "expiring (" .. tostring(fmtSeconds(left)) .. ")"
  else
    reason = "missing"
  end
  return offer(ctx, phase, label, spellStep(snap, phase, castId, s, unit, label, reason))
end
local EVAL = { }
EVAL.selfBuff = function(ctx, rule, phase)
  local snap = ctx.snap
  local castId, s = firstKnown(snap, rule.spells)
  if not (castId) then
    return {
      entry(phase, ruleLabel(snap, rule, rule.spells[1]), "skip", "spell not known")
    }
  end
  return {
    buffOnUnit(ctx, rule, phase, "player", castId, s)
  }
end
EVAL.groupBuff = function(ctx, rule, phase)
  local snap = ctx.snap
  local castId, s = firstKnown(snap, rule.spells)
  if not (castId) then
    return {
      entry(phase, ruleLabel(snap, rule, rule.spells[1]), "skip", "spell not known")
    }
  end
  if phase == "selfLong" then
    local player = unitOf(snap, "player")
    if not (player and wantsBuff(rule.targets, player)) then
      return { }
    end
    return {
      buffOnUnit(ctx, rule, phase, "player", castId, s)
    }
  end
  local out = { }
  local units = { }
  if ctx.opts.includeParty then
    for _index_0 = 1, #PARTY_UNITS do
      local u = PARTY_UNITS[_index_0]
      units[#units + 1] = u
    end
  end
  if rule.includePet then
    units[#units + 1] = "pet"
  end
  for _index_0 = 1, #units do
    local _continue_0 = false
    repeat
      local unit = units[_index_0]
      local ud = unitOf(snap, unit)
      if not (ud and ud.exists) then
        _continue_0 = true
        break
      end
      if not (wantsBuff(rule.targets, ud)) then
        _continue_0 = true
        break
      end
      out[#out + 1] = buffOnUnit(ctx, rule, phase, unit, castId, s)
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return out
end
EVAL.pet = function(ctx, rule, phase)
  local snap = ctx.snap
  local pet = snap.pet or { }
  local label = rule.label or "Pet"
  if pet.exists and not pet.dead then
    return {
      entry(phase, label, "done", "pet is out")
    }
  end
  if pet.dead and rule.revive then
    local s = spellOf(snap, rule.revive)
    local ok, why = castable(s)
    if not (ok) then
      return {
        entry(phase, label, "skip", "revive: " .. tostring(why))
      }
    end
    return {
      offer(ctx, phase, label, spellStep(snap, phase, rule.revive, s, nil, s.name, "pet is dead"))
    }
  end
  local castId, s = firstKnown(snap, rule.summon)
  if not (castId) then
    return {
      entry(phase, label, "skip", "no summon spell known")
    }
  end
  local ok, why = castable(s)
  if not (ok) then
    return {
      entry(phase, label, "skip", why)
    }
  end
  return {
    offer(ctx, phase, label, spellStep(snap, phase, castId, s, nil, s.name, "no pet"))
  }
end
EVAL.conjure = function(ctx, rule, phase)
  local snap = ctx.snap
  local castId, s = firstKnown(snap, rule.spells)
  local label = ruleLabel(snap, rule, castId or rule.spells[1])
  if not (castId) then
    return {
      entry(phase, label, "skip", "spell not known")
    }
  end
  local have = 0
  local _list_0 = rule.items
  for _index_0 = 1, #_list_0 do
    local id = _list_0[_index_0]
    have = have + itemCount(snap, id)
  end
  if have >= rule.minCount then
    return {
      entry(phase, label, "done", "have " .. tostring(have) .. "/" .. tostring(rule.minCount))
    }
  end
  local ok, why = castable(s)
  if not (ok) then
    return {
      entry(phase, label, "skip", why)
    }
  end
  return {
    offer(ctx, phase, label, spellStep(snap, phase, castId, s, "player", label, "have " .. tostring(have) .. "/" .. tostring(rule.minCount)))
  }
end
local weaponState
weaponState = function(snap, rule)
  local w = snap.weapon and snap.weapon[rule.slot]
  if not (w and w.isWeapon) then
    return nil, "no weapon in " .. tostring(rule.slot)
  end
  if w.hasEnchant and (w.remaining or INF) > rule.refresh then
    return nil, "enchanted (" .. tostring(fmtSeconds(w.remaining or INF)) .. ")", true
  end
  return w
end
EVAL.weaponEnchant = function(ctx, rule, phase)
  local snap = ctx.snap
  local label = rule.label or "Weapon (" .. tostring(rule.slot) .. ")"
  local w, why, done = weaponState(snap, rule)
  if not (w) then
    return {
      entry(phase, label, (done and "done" or "skip"), why)
    }
  end
  local _list_0 = rule.items
  for _index_0 = 1, #_list_0 do
    local id = _list_0[_index_0]
    if itemCount(snap, id) > 0 and itemUsable(snap, id) then
      local reason
      if w.hasEnchant then
        reason = "enchant expiring"
      else
        reason = "no enchant"
      end
      return {
        offer(ctx, phase, label, itemStep(snap, phase, id, nil, SLOT_IDS[rule.slot], label, reason))
      }
    end
  end
  return {
    entry(phase, label, "skip", "none in bags")
  }
end
EVAL.weaponImbue = function(ctx, rule, phase)
  local snap = ctx.snap
  local castId, s = firstKnown(snap, rule.spells)
  local label = rule.label or tostring(ruleLabel(snap, rule, castId or rule.spells[1])) .. " (" .. tostring(rule.slot) .. ")"
  if rule.slot ~= "mh" then
    return {
      entry(phase, label, "skip", "spell imbues only apply to the main hand")
    }
  end
  local w, why, done = weaponState(snap, rule)
  if not (w) then
    return {
      entry(phase, label, (done and "done" or "skip"), why)
    }
  end
  if not (castId) then
    return {
      entry(phase, label, "skip", "spell not known")
    }
  end
  local ok, why2 = castable(s)
  if not (ok) then
    return {
      entry(phase, label, "skip", why2)
    }
  end
  local reason
  if w.hasEnchant then
    reason = "enchant expiring (" .. tostring(fmtSeconds(w.remaining or INF)) .. ")"
  else
    reason = "no enchant"
  end
  return {
    offer(ctx, phase, label, spellStep(snap, phase, castId, s, "player", label, reason))
  }
end
local bestCandidate
bestCandidate = function(list)
  local best = nil
  local better
  better = function(c, than)
    if not (than) then
      return true
    end
    local cConjured, tConjured = c.conjured == true, than.conjured == true
    if cConjured ~= tConjured then
      return cConjured
    end
    local cValue, tValue = (c.value or 0), (than.value or 0)
    if cValue ~= tValue then
      return cValue > tValue
    end
    local cCount, tCount = (c.count or 0), (than.count or 0)
    if cCount ~= tCount then
      return cCount < tCount
    end
    return (c.itemId or 0) < (than.itemId or 0)
  end
  local _list_0 = (list or { })
  for _index_0 = 1, #_list_0 do
    local _continue_0 = false
    repeat
      local c = _list_0[_index_0]
      if not ((c.count or 0) > 0 and c.usable ~= false) then
        _continue_0 = true
        break
      end
      if better(c, best) then
        best = c
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return best
end
EVAL.weaponConsumable = function(ctx, rule, phase)
  local snap = ctx.snap
  local label = rule.label or "Weapon (" .. tostring(rule.slot) .. ")"
  local w, why, done = weaponState(snap, rule)
  if not (w) then
    return {
      entry(phase, label, (done and "done" or "skip"), why)
    }
  end
  local category = rule.category
  if category == "stone" then
    if w.blunt then
      category = "weight"
    else
      category = "sharpening"
    end
  end
  local best = bestCandidate(snap.weaponItems and snap.weaponItems[category])
  if not (best) then
    return {
      entry(phase, label, "skip", "no " .. tostring(category) .. " in bags")
    }
  end
  local reason
  if w.hasEnchant then
    reason = "enchant expiring"
  else
    reason = "no enchant"
  end
  return {
    offer(ctx, phase, label, itemStep(snap, phase, best.itemId, nil, SLOT_IDS[rule.slot], label, reason))
  }
end
local activeValue
activeValue = function(snap, data)
  local player = unitOf(snap, "player")
  if not (player and player.auras and data) then
    return 0
  end
  local best = 0
  local _list_0 = player.auras
  for _index_0 = 1, #_list_0 do
    local aura = _list_0[_index_0]
    local v = (aura.spellId and data.auraIds and data.auraIds[aura.spellId]) or (aura.name and data.auraNames and data.auraNames[aura.name])
    if v and v > best then
      best = v
    end
  end
  return best
end
local consumablesPhase
consumablesPhase = function(ctx, phase)
  local snap, rules = ctx.snap, ctx.rules
  if not (ctx.opts.useConsumables) then
    return {
      entry(phase, "Consumables", "skip", "disabled in options")
    }
  end
  local all = snap.consumables or { }
  local flaskActive = false
  local _list_0 = (rules.consumables or { })
  for _index_0 = 1, #_list_0 do
    local cat = _list_0[_index_0]
    if cat.flask and activeValue(snap, all[cat.set]) > 0 then
      flaskActive = true
    end
  end
  local out = { }
  local _list_1 = (rules.consumables or { })
  for _index_0 = 1, #_list_1 do
    local _continue_0 = false
    repeat
      local cat = _list_1[_index_0]
      local data = all[cat.set]
      local best = data and bestCandidate(data.items)
      if not (best) then
        _continue_0 = true
        break
      end
      local label = cat.label or cat.set
      local active = activeValue(snap, data)
      if active > 0 and active >= (best.value or 0) then
        out[#out + 1] = entry(phase, label, "done", "equal or stronger effect active")
      elseif cat.flask and flaskActive and active == 0 then
        out[#out + 1] = entry(phase, label, "skip", "another flask is active")
      else
        local reason
        if active > 0 then
          reason = "stronger than active effect"
        else
          reason = "missing"
        end
        out[#out + 1] = offer(ctx, phase, label, itemStep(snap, phase, best.itemId, "player", nil, label, reason))
        if cat.flask then
          flaskActive = true
        end
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return out
end
local foodBuffPhase
foodBuffPhase = function(ctx, phase)
  local snap, rules = ctx.snap, ctx.rules
  local label = "Well Fed"
  if not (ctx.opts.useConsumables) then
    return {
      entry(phase, label, "skip", "disabled in options")
    }
  end
  local player = unitOf(snap, "player")
  local wf = snap.wellFed or { }
  if findAura(snap, player, wf.ids, wf.names) then
    return {
      entry(phase, label, "done", "active")
    }
  end
  local all = snap.foodBuffs or { }
  local _list_0 = (rules.foodBuffs or { })
  for _index_0 = 1, #_list_0 do
    local cat = _list_0[_index_0]
    local best = bestCandidate(all[cat.set])
    if best then
      return {
        offer(ctx, phase, label, itemStep(snap, phase, best.itemId, "player", nil, label, "missing"))
      }
    end
  end
  return {
    entry(phase, label, "skip", "no buff food in bags")
  }
end
local restPhase
restPhase = function(ctx, phase)
  local snap = ctx.snap
  local p = snap.player or { }
  local thr = ctx.opts.restThreshold or 80
  local out = { }
  local needEat = (p.healthPct or 100) < thr
  local needDrink = p.usesMana and (p.manaPct or 100) < thr
  if needEat then
    if snap.isEating then
      out[#out + 1] = entry(phase, "Eat", "done", "eating")
    else
      local best = bestCandidate(snap.food)
      if best then
        out[#out + 1] = offer(ctx, phase, "Eat", itemStep(snap, phase, best.itemId, "player", nil, "Eat", "health " .. tostring(math.floor(p.healthPct or 0)) .. "% < " .. tostring(thr) .. "%"))
      else
        out[#out + 1] = entry(phase, "Eat", "skip", "no usable food in bags")
      end
    end
  else
    out[#out + 1] = entry(phase, "Eat", "done", "health " .. tostring(math.floor(p.healthPct or 100)) .. "%")
  end
  if p.usesMana then
    if needDrink then
      if snap.isDrinking then
        out[#out + 1] = entry(phase, "Drink", "done", "drinking")
      else
        local best = bestCandidate(snap.water)
        if best then
          out[#out + 1] = offer(ctx, phase, "Drink", itemStep(snap, phase, best.itemId, "player", nil, "Drink", "mana " .. tostring(math.floor(p.manaPct or 0)) .. "% < " .. tostring(thr) .. "%"))
        else
          out[#out + 1] = entry(phase, "Drink", "skip", "no usable water in bags")
        end
      end
    else
      out[#out + 1] = entry(phase, "Drink", "done", "mana " .. tostring(math.floor(p.manaPct or 100)) .. "%")
    end
  end
  return out
end
local blocker
blocker = function(snap)
  if not (snap) then
    return "no snapshot"
  end
  if snap.inCombat then
    return "in combat"
  end
  if snap.unreadable then
    return "auras unreadable: " .. tostring(snap.unreadable)
  end
  if snap.player and snap.player.dead then
    return "player is dead"
  end
  if snap.casting then
    return "casting"
  end
  return nil
end
Engine.explain = function(snap, rules, opts)
  local why = blocker(snap)
  if why then
    return {
      entry("*", "Upkeep", "skip", why)
    }
  end
  local ctx = {
    snap = snap,
    rules = rules or {
      rules = { }
    },
    opts = withDefaults(opts)
  }
  local out = { }
  local push
  push = function(list)
    for _index_0 = 1, #list do
      local e = list[_index_0]
      out[#out + 1] = e
    end
  end
  local resting = snap.isEating or snap.isDrinking
  local wanted = Engine.phaseFilter(ctx.opts.phases)
  for _index_0 = 1, #PHASES do
    local _continue_0 = false
    repeat
      local phase = PHASES[_index_0]
      if wanted and not wanted[phase] then
        _continue_0 = true
        break
      end
      if resting and phase ~= "rest" then
        _continue_0 = true
        break
      end
      if phase == "consumables" then
        push(consumablesPhase(ctx, phase))
      elseif phase == "foodBuff" then
        push(foodBuffPhase(ctx, phase))
      elseif phase == "rest" then
        push(restPhase(ctx, phase))
      else
        local _list_0 = (ctx.rules.rules or { })
        for _index_1 = 1, #_list_0 do
          local _continue_1 = false
          repeat
            local rule = _list_0[_index_1]
            if not (rule.phases and rule.phases[phase]) then
              _continue_1 = true
              break
            end
            if whenFails(rule, snap) then
              out[#out + 1] = entry(phase, ruleLabel(snap, rule, rule.spells and rule.spells[1]), "skip", "condition not met")
              _continue_1 = true
              break
            end
            local evaluator = EVAL[rule.kind]
            if evaluator then
              push(evaluator(ctx, rule, phase))
            end
            _continue_1 = true
          until true
          if not _continue_1 then
            break
          end
        end
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  if resting then
    table.insert(out, 1, entry("*", "Upkeep", "skip", "eating/drinking: only rest steps"))
  end
  return out
end
Engine.nextStep = function(snap, rules, opts)
  local entries = Engine.explain(snap, rules, opts)
  for _index_0 = 1, #entries do
    local e = entries[_index_0]
    if e.status == "do" then
      return e.step, e.reason
    end
  end
  local why = blocker(snap)
  if why then
    return nil, why
  end
  if snap.isEating or snap.isDrinking then
    return nil, "resting"
  end
  return nil, "nothing to do"
end
Engine.formatEntry = function(e)
  return "[" .. tostring(e.phase) .. "] " .. tostring(e.status:upper()) .. " " .. tostring(e.label or '?') .. ": " .. tostring(tostring(e.reason))
end
_G.idUpkeep_UpkeepEngine = Engine
return Engine
