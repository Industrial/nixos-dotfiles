local M = { }
local MIN_BUFF_DURATION = 60000
M.MIN_BUFF_DURATION = MIN_BUFF_DURATION
local SELF_AURAS = {
  APPLY_AURA = true,
  MOD_STAT = true,
  MOD_TOTAL_STAT_PERCENTAGE = true
}
local PARTY_AURAS = {
  APPLY_AURA_PARTY = true,
  APPLY_AREA_AURA_PARTY = true
}
local RAID_AURAS = {
  APPLY_AURA_RAID = true,
  APPLY_AREA_AURA_RAID = true
}
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
local lastingAura
lastingAura = function(family)
  return function(ctx, spell)
    if not ((spell.duration or 0) >= MIN_BUFF_DURATION) then
      return nil
    end
    local effect = ctx.findSpellEffect(spell, function(e)
      return family[e.auraType or ""]
    end)
    if not (effect) then
      return nil
    end
    return math.abs(effect.amount or 1)
  end
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
    predicate = lastingAura(SELF_AURAS)
  },
  ["Spell.Buff.Party"] = {
    predicate = lastingAura(PARTY_AURAS)
  },
  ["Spell.Buff.Raid"] = {
    predicate = lastingAura(RAID_AURAS)
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
  ["Spell.Conjure.Food"] = unsupported("model has no spell -> created-item link"),
  ["Spell.Conjure.Water"] = unsupported("model has no spell -> created-item link")
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
