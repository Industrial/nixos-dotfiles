local lua_type = _G.type
local tonumber
tonumber = function(v)
  return _G.tonumber(v)
end
local Spells = { }
local LIB_NAME = "idLibSpellTable-1.0"
Spells.LIB_NAME = LIB_NAME
local FALLBACK_KINDS = {
  ["Spell.Buff.Self"] = {
    selfBuff = true
  },
  ["Spell.Buff.Party"] = {
    groupBuff = true
  },
  ["Spell.Buff.Raid"] = {
    groupBuff = true
  },
  ["Spell.Conjure"] = {
    conjure = true
  },
  ["Spell.Pet.Summon"] = {
    pet = true
  }
}
Spells.FALLBACK_KINDS = FALLBACK_KINDS
Spells.canFallBack = function(set)
  return FALLBACK_KINDS[set] ~= nil
end
Spells.lib = function()
  local LibStub = _G.LibStub
  if not (LibStub) then
    return nil
  end
  local ok, lib = pcall(LibStub, LIB_NAME, true)
  if not (ok) then
    return nil
  end
  return lib
end
local sorted
sorted = function(list)
  table.sort(list, function(a, b)
    return a.spellId < b.spellId
  end)
  return list
end
Spells.fromLibrary = function(set, lib)
  if lib == nil then
    lib = Spells.lib()
  else
    lib = lib
  end
  local out = { }
  if not (lib and lib.IterateSet) then
    return out
  end
  local ok, iter, state = pcall(lib.IterateSet, lib, set)
  if not (ok and lua_type(iter) == "function") then
    return out
  end
  local control = nil
  while true do
    local _continue_0 = false
    repeat
      local iterOk, spellId, value = pcall(iter, state, control)
      if not (iterOk and spellId ~= nil) then
        break
      end
      control = spellId
      if not (lua_type(spellId) == "number") then
        _continue_0 = true
        break
      end
      out[#out + 1] = {
        spellId = spellId,
        value = tonumber(value) or 1
      }
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return sorted(out)
end
Spells.fromClassRules = function(set, classToken, rulesLib)
  local out = { }
  local kinds = FALLBACK_KINDS[set]
  if not (kinds) then
    return out
  end
  local Rules = rulesLib or _G.idUpkeep_UpkeepRules
  if not (Rules and Rules.forClass) then
    return out
  end
  local ok, classRules = pcall(Rules.forClass, classToken)
  if not (ok and classRules) then
    return out
  end
  local seen = { }
  local add
  add = function(id)
    if not (lua_type(id) == "number" and not seen[id]) then
      return 
    end
    seen[id] = true
    out[#out + 1] = {
      spellId = id,
      value = 1
    }
  end
  local _list_0 = (classRules.rules or { })
  for _index_0 = 1, #_list_0 do
    local _continue_0 = false
    repeat
      local rule = _list_0[_index_0]
      if not (kinds[rule.kind]) then
        _continue_0 = true
        break
      end
      local _list_1 = (rule.spells or { })
      for _index_1 = 1, #_list_1 do
        local id = _list_1[_index_1]
        add(id)
      end
      local _list_2 = (rule.summon or { })
      for _index_1 = 1, #_list_2 do
        local id = _list_2[_index_1]
        add(id)
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return sorted(out)
end
Spells.activeSpec = function()
  local getIndex = _G.GetSpecialization
  local getInfo = _G.GetSpecializationInfo
  if not (getIndex and getInfo) then
    return nil
  end
  local ok, index = pcall(getIndex)
  if not (ok and index) then
    return nil
  end
  local ok2, specId, name = pcall(getInfo, index)
  if not (ok2 and name and lua_type(name) == "string") then
    return nil
  end
  return {
    specId = specId,
    name = name
  }
end
Spells.specSetName = function(set, classToken, specName)
  if not (set and classToken and specName) then
    return nil
  end
  local family = set:gsub("^Spell%.", "")
  return ("Spell.Spec.%s.%s.%s"):format(classToken, (specName:gsub("%s+", "")), family)
end
Spells.resolve = function(set, classToken, deps)
  if deps == nil then
    deps = { }
  end
  local lib
  if deps.lib == nil then
    lib = Spells.lib()
  else
    lib = deps.lib
  end
  local spec
  if deps.spec == nil then
    spec = Spells.activeSpec()
  else
    spec = deps.spec
  end
  if spec and spec.name then
    local specSet = Spells.specSetName(set, classToken, spec.name)
    local fromSpec = Spells.fromLibrary(specSet, lib)
    if #fromSpec > 0 then
      return fromSpec, "library-spec", Spells.canFallBack(set)
    end
  end
  local fromLib = Spells.fromLibrary(set, lib)
  if #fromLib > 0 then
    return fromLib, "library", Spells.canFallBack(set)
  end
  local fallback = Spells.fromClassRules(set, classToken, deps.rules)
  if #fallback > 0 then
    return fallback, "class-table", true
  end
  return { }, "none", Spells.canFallBack(set)
end
Spells.known = function(list, snap)
  if not (snap and snap.spells) then
    return { }
  end
  local out = { }
  local _list_0 = (list or { })
  for _index_0 = 1, #_list_0 do
    local entry = _list_0[_index_0]
    local s = snap.spells[entry.spellId]
    if s and s.known and s.name then
      out[#out + 1] = entry
    end
  end
  return out
end
Spells.best = function(list)
  local best = nil
  local _list_0 = (list or { })
  for _index_0 = 1, #_list_0 do
    local _continue_0 = false
    repeat
      local entry = _list_0[_index_0]
      if not (entry and entry.spellId) then
        _continue_0 = true
        break
      end
      if not best then
        best = entry
        _continue_0 = true
        break
      end
      local value, bestValue = (entry.value or 0), (best.value or 0)
      if value > bestValue or (value == bestValue and entry.spellId < best.spellId) then
        best = entry
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return best
end
_G.idUpkeep_UpkeepSpells = Spells
return Spells
