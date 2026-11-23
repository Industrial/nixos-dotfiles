local lua_type = _G.type
local tonumber
tonumber = function(v)
  return _G.tonumber(v)
end
local Consumables = { }
Consumables._spellCache = { }
local valueIn
valueIn = function(lib, itemId, set)
  if not (lib) then
    return nil
  end
  local ok, v = pcall(lib.ItemInSet, lib, itemId, set)
  if not (ok and v) then
    return nil
  end
  local n = tonumber(v)
  return n or 1
end
Consumables.valueIn = valueIn
local LIB_PREFERENCE = {
  "idLibItemTable-1.0",
  "LibPeriodicTable-3.1"
}
Consumables.isEmpty = function(lib)
  if not (lib and lib.Sets) then
    return false
  end
  local ok, sets = pcall(lib.Sets, lib)
  if not (ok and lua_type(sets) == "table") then
    return false
  end
  return #sets == 0
end
Consumables.lib = function()
  local LibStub = _G.LibStub
  if not (LibStub) then
    return nil
  end
  local fallback = nil
  for _index_0 = 1, #LIB_PREFERENCE do
    local _continue_0 = false
    repeat
      local name = LIB_PREFERENCE[_index_0]
      local ok, lib = pcall(LibStub, name, true)
      if not (ok and lib) then
        _continue_0 = true
        break
      end
      if not (Consumables.isEmpty(lib)) then
        return lib
      end
      fallback = fallback or lib
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return fallback
end
local cachedSpell
cachedSpell = function(ctx, itemId)
  local hit = Consumables._spellCache[itemId]
  if hit then
    return hit
  end
  if not (ctx.itemSpell) then
    return nil
  end
  local ok, name, id = pcall(ctx.itemSpell, itemId)
  if not (ok and (name or id)) then
    return nil
  end
  hit = {
    name = name,
    id = id
  }
  Consumables._spellCache[itemId] = hit
  return hit
end
local auraMapFor
auraMapFor = function(ctx, set)
  local names, ids = { }, { }
  local lib = ctx.lib
  if not (lib and lib.IterateSet) then
    return names, ids
  end
  local ok, iter, state = pcall(lib.IterateSet, lib, set)
  if not (ok and lua_type(iter) == "function") then
    return names, ids
  end
  local control = nil
  while true do
    local _continue_0 = false
    repeat
      local iterOk, itemId, value = pcall(iter, state, control)
      if not (iterOk and itemId ~= nil) then
        break
      end
      control = itemId
      if not (lua_type(itemId) == "number") then
        _continue_0 = true
        break
      end
      local v = tonumber(value) or 1
      local spell = cachedSpell(ctx, itemId)
      if spell then
        if spell.name then
          names[spell.name] = math.max(names[spell.name] or 0, v)
        end
        if spell.id then
          ids[spell.id] = math.max(ids[spell.id] or 0, v)
        end
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return names, ids
end
local candidate
candidate = function(ctx, itemId, count, value, extra)
  local usable = nil
  if ctx.usable then
    local ok, u = pcall(ctx.usable, itemId)
    if ok then
      usable = u
    end
  end
  local c = {
    itemId = itemId,
    value = value,
    count = count,
    usable = usable
  }
  if extra then
    for k, v in pairs(extra) do
      c[k] = v
    end
  end
  return c
end
local bagCandidates
bagCandidates = function(ctx, counts, set, extra)
  local out = { }
  for itemId, count in pairs(counts) do
    local v = valueIn(ctx.lib, itemId, set)
    if v then
      out[#out + 1] = candidate(ctx, itemId, count, v, extra)
    end
  end
  table.sort(out, function(a, b)
    return a.itemId < b.itemId
  end)
  return out
end
local mergedCandidates
mergedCandidates = function(ctx, counts, sets)
  local byId = { }
  for _index_0 = 1, #sets do
    local def = sets[_index_0]
    local _list_0 = bagCandidates(ctx, counts, def.set, {
      conjured = def.conjured == true
    })
    for _index_1 = 1, #_list_0 do
      local c = _list_0[_index_1]
      local prev = byId[c.itemId]
      if not prev or (c.value or 0) > (prev.value or 0) then
        byId[c.itemId] = c
      end
    end
  end
  local out
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _, c in pairs(byId) do
      _accum_0[_len_0] = c
      _len_0 = _len_0 + 1
    end
    out = _accum_0
  end
  table.sort(out, function(a, b)
    return a.itemId < b.itemId
  end)
  return out
end
Consumables.build = function(counts, ctx)
  if ctx == nil then
    ctx = { }
  end
  counts = counts or { }
  local Rules = _G.idUpkeep_UpkeepRules
  local result = {
    consumables = { },
    foodBuffs = { },
    food = { },
    water = { },
    weaponItems = { }
  }
  if not (ctx.lib and Rules) then
    return result
  end
  local _list_0 = (ctx.consumables or Rules.CONSUMABLES)
  for _index_0 = 1, #_list_0 do
    local cat = _list_0[_index_0]
    local names, ids = auraMapFor(ctx, cat.set)
    result.consumables[cat.set] = {
      items = bagCandidates(ctx, counts, cat.set, {
        flask = cat.flask == true
      }),
      auraNames = names,
      auraIds = ids
    }
  end
  local _list_1 = (ctx.foodBuffs or Rules.FOOD_BUFFS)
  for _index_0 = 1, #_list_1 do
    local cat = _list_1[_index_0]
    result.foodBuffs[cat.set] = bagCandidates(ctx, counts, cat.set)
  end
  result.food = mergedCandidates(ctx, counts, Rules.FOOD_SETS)
  result.water = mergedCandidates(ctx, counts, Rules.WATER_SETS)
  local buffFood = { }
  for _, list in pairs(result.foodBuffs) do
    for _index_0 = 1, #list do
      local c = list[_index_0]
      buffFood[c.itemId] = true
    end
  end
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_2 = result.food
    for _index_0 = 1, #_list_2 do
      local c = _list_2[_index_0]
      if not buffFood[c.itemId] then
        _accum_0[_len_0] = c
        _len_0 = _len_0 + 1
      end
    end
    result.food = _accum_0
  end
  for key, set in pairs(Rules.WEAPON_SETS) do
    result.weaponItems[key] = bagCandidates(ctx, counts, set)
  end
  return result
end
_G.idUpkeep_UpkeepConsumables = Consumables
return Consumables
