local lua_type = _G.type
local PetDeath = { }
PetDeath.DEAD_GLOBALS = {
  "PETTAME_DEAD",
  "ERR_PET_SPELL_DEAD",
  "SPELL_FAILED_PET_IS_DEAD"
}
PetDeath.DEAD_LITERALS = {
  "Your pet is dead"
}
PetDeath.ALIVE_GLOBALS = {
  "PETTAME_NOTDEAD"
}
PetDeath.ALIVE_LITERALS = {
  "Your pet is not dead"
}
PetDeath.REVIVE_PET_ID = 982
local normalize
normalize = function(s)
  if not (lua_type(s) == "string") then
    return nil
  end
  return (s:lower():gsub("[%s%.!]+$", ""))
end
PetDeath.normalize = normalize
PetDeath.messageIn = function(msg, globals, literals)
  local m = normalize(msg)
  if not (m and m ~= "") then
    return false
  end
  local _list_0 = (globals or { })
  for _index_0 = 1, #_list_0 do
    local name = _list_0[_index_0]
    local g = normalize(_G[name])
    if g and g ~= "" and g == m then
      return true
    end
  end
  local _list_1 = (literals or { })
  for _index_0 = 1, #_list_1 do
    local lit = _list_1[_index_0]
    if normalize(lit) == m then
      return true
    end
  end
  return false
end
PetDeath.errorText = function(...)
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if lua_type(v) == "string" then
      return v
    end
  end
  return nil
end
PetDeath.spellNameOf = function(id)
  if not (id) then
    return nil
  end
  local C = _G.C_Spell
  if C and C.GetSpellInfo then
    local ok, info = pcall(C.GetSpellInfo, id)
    if ok and lua_type(info) == "table" then
      return info.name
    end
  end
  if _G.GetSpellInfo then
    local ok, name = pcall(_G.GetSpellInfo, id)
    if ok then
      return name
    end
  end
  return nil
end
PetDeath.set = function(store, dead)
  if not (store) then
    return false
  end
  local value
  if dead then
    value = true
  else
    value = nil
  end
  if store.petDead == value then
    return false
  end
  store.petDead = value
  return true
end
PetDeath.isDead = function(store)
  return (store and store.petDead) == true
end
PetDeath.track = function(store, isSecret)
  local read
  read = function(fn)
    if not (fn) then
      return nil
    end
    local ok, v = pcall(fn, "pet")
    if not (ok) then
      return nil
    end
    if isSecret and isSecret(v) then
      return nil
    end
    return v
  end
  if not (read(_G.UnitExists) == true) then
    return false
  end
  local dead = read(_G.UnitIsDead)
  if dead == nil then
    return false
  end
  return PetDeath.set(store, dead == true)
end
PetDeath.onReviveResult = function(store, spellId)
  if not (spellId and PetDeath.isDead(store)) then
    return false
  end
  local revive = PetDeath.spellNameOf(PetDeath.REVIVE_PET_ID)
  if spellId == PetDeath.REVIVE_PET_ID or (revive and PetDeath.spellNameOf(spellId) == revive) then
    return PetDeath.set(store, false)
  end
  return false
end
PetDeath.onError = function(store, ...)
  local msg = PetDeath.errorText(...)
  if PetDeath.messageIn(msg, PetDeath.DEAD_GLOBALS, PetDeath.DEAD_LITERALS) then
    return PetDeath.set(store, true)
  end
  if PetDeath.messageIn(msg, PetDeath.ALIVE_GLOBALS, PetDeath.ALIVE_LITERALS) then
    return PetDeath.set(store, false)
  end
  return false
end
_G.idUpkeep_UpkeepPetDeath = PetDeath
return PetDeath
