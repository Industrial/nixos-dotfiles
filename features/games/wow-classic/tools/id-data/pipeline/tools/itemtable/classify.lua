local M = { }
M.index = function(doc)
  local idx = {
    items = { },
    spellsById = { },
    effectsByItem = { },
    effectsBySpell = { }
  }
  local _list_0 = (doc.items or { })
  for _index_0 = 1, #_list_0 do
    local item = _list_0[_index_0]
    idx.items[item.id] = item
  end
  local _list_1 = (doc.spells or { })
  for _index_0 = 1, #_list_1 do
    local sp = _list_1[_index_0]
    idx.spellsById[sp.id] = sp
  end
  local _list_2 = (doc.itemEffects or { })
  for _index_0 = 1, #_list_2 do
    local fx = _list_2[_index_0]
    local list = idx.effectsByItem[fx.itemId]
    if not (list) then
      list = { }
      idx.effectsByItem[fx.itemId] = list
    end
    list[#list + 1] = fx
  end
  local _list_3 = (doc.spellEffects or { })
  for _index_0 = 1, #_list_3 do
    local se = _list_3[_index_0]
    local list = idx.effectsBySpell[se.spellId]
    if not (list) then
      list = { }
      idx.effectsBySpell[se.spellId] = list
    end
    list[#list + 1] = se
  end
  return idx
end
M.context = function(doc)
  local idx = M.index(doc)
  local ctx = {
    doc = doc,
    idx = idx
  }
  ctx.effectsOf = function(item, trigger)
    if trigger == nil then
      trigger = "use"
    end
    local out = { }
    local _list_0 = (idx.effectsByItem[item.id] or { })
    for _index_0 = 1, #_list_0 do
      local _continue_0 = false
      repeat
        local fx = _list_0[_index_0]
        if not (fx.trigger == trigger) then
          _continue_0 = true
          break
        end
        local spell = idx.spellsById[fx.spellId]
        if not (spell) then
          _continue_0 = true
          break
        end
        local _list_1 = (idx.effectsBySpell[fx.spellId] or { })
        for _index_1 = 1, #_list_1 do
          local se = _list_1[_index_1]
          out[#out + 1] = {
            spell = spell,
            effect = se
          }
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    return out
  end
  ctx.findEffect = function(item, fn, trigger)
    local _list_0 = ctx.effectsOf(item, trigger)
    for _index_0 = 1, #_list_0 do
      local pair = _list_0[_index_0]
      if fn(pair.effect, pair.spell) then
        return pair
      end
    end
    return nil
  end
  -- The shared cooldown group an item's use belongs to (nil when none).
  ctx.cooldownCategoryOf = function(item)
    local _list_0 = (idx.effectsByItem[item.id] or { })
    for _index_0 = 1, #_list_0 do
      local fx = _list_0[_index_0]
      if fx.trigger == "use" and (fx.cooldownCategory or 0) > 0 then
        return fx.cooldownCategory
      end
    end
    return nil
  end
  -- The shared cooldown group most consumables of a subclass use: the potion
  -- cooldown for "Potion", the eating group for "Food". Derived from the
  -- data, so no category number is written down.
  local dominant = { }
  ctx.dominantCategory = function(subclass)
    if dominant[subclass] ~= nil then
      return dominant[subclass] or nil
    end
    local counts, best, bestN = { }, nil, 0
    local _list_0 = doc.items or { }
    for _index_0 = 1, #_list_0 do
      local item = _list_0[_index_0]
      if item.class == "Consumable" and item.subclass == subclass then
        local cat = ctx.cooldownCategoryOf(item)
        if cat then
          counts[cat] = (counts[cat] or 0) + 1
          if counts[cat] > bestN then
            best, bestN = cat, counts[cat]
          end
        end
      end
    end
    dominant[subclass] = best or false
    return best
  end
  ctx.potionCategory = function()
    return ctx.dominantCategory("Potion")
  end
  ctx.hasNoEffect = function(item)
    return #(idx.effectsByItem[item.id] or { }) == 0
  end
  ctx.effectsOfSpell = function(spell)
    return idx.effectsBySpell[spell.id] or { }
  end
  ctx.findSpellEffect = function(spell, fn)
    local _list_0 = ctx.effectsOfSpell(spell)
    for _index_0 = 1, #_list_0 do
      local effect = _list_0[_index_0]
      if fn(effect) then
        return effect
      end
    end
    return nil
  end
  ctx.spellHasNoEffect = function(spell)
    return #ctx.effectsOfSpell(spell) == 0
  end
  return ctx
end
M.identifierOf = function(rules)
  if rules and rules.identify then
    return rules.identify
  end
  local field = (rules and rules.idField) or "id"
  return function(entity)
    return entity[field]
  end
end
M.entitiesOf = function(doc, rules)
  if rules and rules.entities then
    return rules.entities(doc) or { }
  end
  return doc.items or { }
end
M.run = function(doc, rules)
  local ctx = M.context(doc)
  local result = {
    sets = { },
    unclassified = { },
    excluded = { },
    unsupported = { }
  }
  for setName, rule in pairs(rules.sets or { }) do
    if rule.unsupported then
      result.unsupported[setName] = rule.unsupported
    end
  end
  local inScope
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = M.entitiesOf(doc, rules)
    for _index_0 = 1, #_list_0 do
      local entity = _list_0[_index_0]
      if rules.scope(entity) then
        _accum_0[_len_0] = entity
        _len_0 = _len_0 + 1
      end
    end
    inScope = _accum_0
  end
  local identify = M.identifierOf(rules)
  table.sort(inScope, function(a, b)
    return identify(a) < identify(b)
  end)
  for _index_0 = 1, #inScope do
    local _continue_0 = false
    repeat
      local entity = inScope[_index_0]
      local key = identify(entity)
      local matched = false
      local override = (rules.overrides or { })[key]
      if override then
        local _list_0 = (override.sets or { })
        for _index_1 = 1, #_list_0 do
          local setName = _list_0[_index_1]
          local _update_0 = setName
          result.sets[_update_0] = result.sets[_update_0] or { }
          result.sets[setName][key] = override.value or 1
          matched = true
        end
      end
      if not (matched) then
        for setName, rule in pairs(rules.sets or { }) do
          local _continue_1 = false
          repeat
            if rule.unsupported then
              _continue_1 = true
              break
            end
            local value = rule.predicate(ctx, entity)
            if not (value) then
              _continue_1 = true
              break
            end
            local _update_0 = setName
            result.sets[_update_0] = result.sets[_update_0] or { }
            result.sets[setName][key] = value
            matched = true
            _continue_1 = true
          until true
          if not _continue_1 then
            break
          end
        end
      end
      if matched then
        _continue_0 = true
        break
      end
      local reason = nil
      local _list_0 = (rules.exclusions or { })
      for _index_1 = 1, #_list_0 do
        local exclusion = _list_0[_index_1]
        if exclusion.match(ctx, entity) then
          reason = exclusion.reason
        end
        if reason then
          break
        end
      end
      if reason then
        result.excluded[key] = reason
      else
        result.unclassified[#result.unclassified + 1] = key
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return result
end
M.encodeSet = function(members)
  local ids
  do
    local _accum_0 = { }
    local _len_0 = 1
    for id in pairs(members or { }) do
      _accum_0[_len_0] = id
      _len_0 = _len_0 + 1
    end
    ids = _accum_0
  end
  table.sort(ids)
  local parts
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #ids do
      local id = ids[_index_0]
      local value = members[id]
      local _value_0
      if value == 1 then
        _value_0 = tostring(id)
      else
        _value_0 = ("%d:%s"):format(id, tostring(value))
      end
      _accum_0[_len_0] = _value_0
      _len_0 = _len_0 + 1
    end
    parts = _accum_0
  end
  return table.concat(parts, ",")
end
return M
