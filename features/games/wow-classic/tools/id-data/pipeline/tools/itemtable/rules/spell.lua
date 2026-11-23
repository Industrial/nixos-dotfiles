local M = { }
local MIN_BUFF_DURATION = 60000
M.MIN_BUFF_DURATION = MIN_BUFF_DURATION
-- BUFFS, read from Forever 1.60.1.71037 (tools/id-data). A buff is an aura
-- effect (APPLY_AURA, or an area aura a paladin or hunter radiates) that
-- outlasts a minute or lasts until cancelled, on a spell that is not passive.
-- Who it lands on is the effect's target: the caster alone (Self), one
-- friendly unit (Party: Arcane Intellect, Blessings) or everyone in the
-- caster's group around it (Raid: Gift of the Wild, Battle Shout).
local BUFF_EFFECTS = {
  APPLY_AURA = true,
  APPLY_AREA_AURA_PARTY = true,
  APPLY_AREA_AURA_RAID = true
}
local AREA_AURA = {
  APPLY_AREA_AURA_PARTY = true,
  APPLY_AREA_AURA_RAID = true
}
-- Auras that switch a mode rather than buff: forms and stances, stealth,
-- tracking. They last until cancelled, so duration alone would call them buffs.
local TOGGLE_AURAS = {
  MOD_SHAPESHIFT = true,
  MOD_STEALTH = true,
  TRACK_CREATURES = true,
  TRACK_RESOURCES = true,
  TRACK_STEALTHED = true,
  FEIGN_DEATH = true,
  MOUNTED = true
}
M.TOGGLE_AURAS = TOGGLE_AURAS
-- A form, stance, stealth or tracking spell: any effect switching a mode.
M.isToggle = function(ctx, spell)
  return ctx.findSpellEffect(spell, function(e)
    return TOGGLE_AURAS[e.auraType or ""] == true
  end) ~= nil
end
local lasting
lasting = function(spell)
  if spell.passive or spell.channeled then
    return false
  end
  local d = spell.duration or 0
  return d == -1 or d >= MIN_BUFF_DURATION
end
M.lasting = lasting
-- The buff effect landing on `who` (SELF counts area auras: they radiate from
-- the caster). nil when the spell has none.
local buffEffect
buffEffect = function(ctx, spell, who)
  return ctx.findSpellEffect(spell, function(e)
    if not (BUFF_EFFECTS[e.effect or ""] and not TOGGLE_AURAS[e.auraType or ""]) then
      return false
    end
    if who == "SELF" then
      return AREA_AURA[e.effect] or e.target == "SELF" or e.target == nil
    end
    return e.target == who
  end)
end
local buffOn
buffOn = function(who)
  return function(ctx, spell)
    if not (lasting(spell)) or M.isToggle(ctx, spell) then
      return nil
    end
    local effect = buffEffect(ctx, spell, who)
    if not (effect) then
      return nil
    end
    if who == "SELF" and (buffEffect(ctx, spell, "FRIEND") or buffEffect(ctx, spell, "GROUP")) then
      return nil
    end
    return math.abs(effect.amount or 1)
  end
end
-- CONJURING: CREATE_ITEM, split by what the made item restores when used.
local itemsById = setmetatable({ }, { __mode = "k" })
local itemById
itemById = function(ctx, id)
  local byId = itemsById[ctx]
  if not (byId) then
    byId = { }
    for _, it in ipairs(ctx.doc.items or { }) do
      byId[it.id] = it
    end
    itemsById[ctx] = byId
  end
  return byId[id]
end
local createdItemOf
createdItemOf = function(ctx, spell)
  local e = ctx.findSpellEffect(spell, function(e)
    return (e.effect == "CREATE_ITEM" or e.auraType == "CREATE_ITEM") and e.createdItem ~= nil
  end)
  return e and itemById(ctx, e.createdItem) or nil
end
local conjures
conjures = function(restore)
  return function(ctx, spell)
    local item = createdItemOf(ctx, spell)
    if not (item) then
      return nil
    end
    for _, pair in ipairs(ctx.effectsOf(item)) do
      if pair.effect.auraType == restore and (pair.effect.index or 1) < 200 then
        return math.abs(pair.effect.amount or 1)
      end
    end
    return nil
  end
end
local unsupported
unsupported = function(reason)
  return {
    unsupported = reason
  }
end
M.entities = function(doc)
  return doc.spells or { }
end
M.scope = function(spell)
  return spell.__castable == true
end
local SCHOOL_MASK = {
  PHYSICAL = 1,
  HOLY = 2,
  FIRE = 4,
  NATURE = 8,
  FROST = 16,
  SHADOW = 32,
  ARCANE = 64
}
M.SCHOOL_MASK = SCHOOL_MASK
local periodicOf
periodicOf = function(spell)
  local p = spell.__periodic
  if not (p) then
    return nil
  end
  if p.periodConflict then
    return nil
  end
  if not (p.period and p.period > 0) then
    return nil
  end
  if not (p.amount and p.amount > 0) then
    return nil
  end
  if not (spell.duration and spell.duration > 0) then
    return nil
  end
  return p
end
M.periodicOf = periodicOf
local periodicField
periodicField = function(pick)
  return function(_ctx, spell)
    local p = periodicOf(spell)
    if not (p) then
      return nil
    end
    return pick(p, spell)
  end
end
M.annotate = function(doc)
  local castable = { }
  local _list_0 = (doc.spellClass or { })
  for _index_0 = 1, #_list_0 do
    local row = _list_0[_index_0]
    castable[row.spellId] = true
  end
  local periodic = { }
  local _list_1 = (doc.spellPeriodic or { })
  for _index_0 = 1, #_list_1 do
    local _continue_0 = false
    repeat
      local row = _list_1[_index_0]
      if not (row.spellId and row.period and row.baseAmount) then
        _continue_0 = true
        break
      end
      local p = periodic[row.spellId]
      if not (p) then
        periodic[row.spellId] = {
          amount = row.baseAmount,
          period = row.period,
          coefficient = row.coefficient or 0,
          apCoefficient = row.apCoefficient or 0,
          school = row.school
        }
        _continue_0 = true
        break
      end
      if row.period ~= p.period then
        p.periodConflict = true
      end
      p.amount = p.amount + row.baseAmount
      p.coefficient = p.coefficient + (row.coefficient or 0)
      p.apCoefficient = p.apCoefficient + (row.apCoefficient or 0)
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  local _list_2 = (doc.spells or { })
  for _index_0 = 1, #_list_2 do
    local spell = _list_2[_index_0]
    spell.__castable = castable[spell.id] == true
    spell.__periodic = periodic[spell.id]
  end
  return doc
end
local instant
instant = function(auraType)
  return function(ctx, spell)
    local effect = ctx.findSpellEffect(spell, function(e)
      return e.auraType == auraType
    end)
    if not (effect) then
      return nil
    end
    return math.abs(effect.amount or 1)
  end
end
M.sets = {
  ["Spell.Buff.Self"] = {
    predicate = buffOn("SELF")
  },
  ["Spell.Buff.Party"] = {
    predicate = buffOn("FRIEND")
  },
  ["Spell.Buff.Raid"] = {
    predicate = buffOn("GROUP")
  },
  ["Spell.Heal.Direct"] = {
    predicate = instant("HEAL")
  },
  ["Spell.Restore.Mana"] = {
    predicate = instant("ENERGIZE")
  },
  ["Spell.Pet.Summon"] = {
    predicate = instant("SUMMON")
  },
  ["Spell.Conjure"] = {
    predicate = instant("CREATE_ITEM")
  },
  ["Spell.DoT.Amount"] = {
    predicate = periodicField(function(p)
      return p.amount
    end)
  },
  ["Spell.DoT.Period"] = {
    predicate = periodicField(function(p)
      return p.period
    end)
  },
  ["Spell.DoT.Duration"] = {
    predicate = periodicField(function(_p, spell)
      return spell.duration
    end)
  },
  ["Spell.DoT.Coefficient"] = {
    predicate = periodicField(function(p)
      return p.coefficient
    end)
  },
  ["Spell.DoT.ApCoefficient"] = {
    predicate = periodicField(function(p)
      return p.apCoefficient
    end)
  },
  ["Spell.DoT.School"] = {
    predicate = periodicField(function(p)
      return p.school and SCHOOL_MASK[p.school] or nil
    end)
  },
  ["Spell.Conjure.Food"] = {
    predicate = conjures("PERIODIC_HEAL")
  },
  ["Spell.Conjure.Water"] = {
    predicate = conjures("PERIODIC_ENERGIZE")
  }
}
M.exclusions = {
  {
    reason = "castable spell with no recorded effect",
    match = function(ctx, spell)
      return ctx.spellHasNoEffect(spell)
    end
  }
}
M.gate = "ratchet"
M.overrides = { }
M.reachability = function(doc)
  local specsById, byClass = { }, { }
  local _list_0 = (doc.specs or { })
  for _index_0 = 1, #_list_0 do
    local _continue_0 = false
    repeat
      local spec = _list_0[_index_0]
      if not (spec.specId and spec.classFile) then
        _continue_0 = true
        break
      end
      specsById[spec.specId] = spec
      local _update_0 = spec.classFile
      byClass[_update_0] = byClass[_update_0] or { }
      byClass[spec.classFile][#byClass[spec.classFile] + 1] = spec.specId
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  local reach = { }
  local add
  add = function(specId, spellId)
    if not (specId and spellId) then
      return 
    end
    local _update_0 = specId
    reach[_update_0] = reach[_update_0] or { }
    reach[specId][spellId] = true
  end
  local _list_1 = (doc.spellClass or { })
  for _index_0 = 1, #_list_1 do
    local _continue_0 = false
    repeat
      local row = _list_1[_index_0]
      if not (row.spellId) then
        _continue_0 = true
        break
      end
      if row.specId then
        add(row.specId, row.spellId)
      elseif row.classFile then
        local _list_2 = (byClass[row.classFile] or { })
        for _index_1 = 1, #_list_2 do
          local specId = _list_2[_index_1]
          add(specId, row.spellId)
        end
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  local trees, nodes = { }, { }
  local _list_2 = (doc.talentTrees or { })
  for _index_0 = 1, #_list_2 do
    local t = _list_2[_index_0]
    trees[t.treeId] = t
  end
  local _list_3 = (doc.talentNodes or { })
  for _index_0 = 1, #_list_3 do
    local n = _list_3[_index_0]
    nodes[n.nodeId] = n
  end
  local _list_4 = (doc.talentEntries or { })
  for _index_0 = 1, #_list_4 do
    local _continue_0 = false
    repeat
      local entry = _list_4[_index_0]
      if not (entry.spellId) then
        _continue_0 = true
        break
      end
      local node = entry.nodeId and nodes[entry.nodeId]
      local tree = node and node.treeId and trees[node.treeId]
      if not (tree) then
        _continue_0 = true
        break
      end
      if tree.specId then
        add(tree.specId, entry.spellId)
      elseif tree.classFile then
        local _list_5 = (byClass[tree.classFile] or { })
        for _index_1 = 1, #_list_5 do
          local specId = _list_5[_index_1]
          add(specId, entry.spellId)
        end
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return reach, specsById
end
M.familyOf = function(setName)
  return setName:gsub("^Spell%.", "")
end
M.specSetName = function(classFile, specName, family)
  return ("Spell.Spec.%s.%s.%s"):format(classFile, (specName:gsub("%s+", "")), family)
end
local specFiltered
specFiltered = function(base, reachable)
  return function(ctx, spell)
    if not (reachable[spell.id]) then
      return nil
    end
    return base(ctx, spell)
  end
end
M.setsFor = function(doc)
  local sets = { }
  for name, rule in pairs(M.sets) do
    sets[name] = rule
  end
  local reach, specsById = M.reachability(doc)
  for specId, spec in pairs(specsById) do
    local reachable = reach[specId] or { }
    for name, rule in pairs(M.sets) do
      local _continue_0 = false
      repeat
        if rule.unsupported then
          _continue_0 = true
          break
        end
        local filtered = M.specSetName(spec.classFile, spec.name, M.familyOf(name))
        sets[filtered] = {
          predicate = specFiltered(rule.predicate, reachable)
        }
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
  end
  return sets
end
M.forDocument = function(doc)
  M.annotate(doc)
  return {
    entities = M.entities,
    scope = M.scope,
    sets = M.setsFor(doc),
    exclusions = M.exclusions,
    overrides = M.overrides,
    gate = M.gate
  }
end
return M
