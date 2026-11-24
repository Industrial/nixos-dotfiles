local tonumber
tonumber = function(v)
  return _G.tonumber(v)
end
local lua_type = _G.type
local unpack = _G.unpack or table.unpack
local tostring = _G.tostring
local Snapshot = { }
local PARTY_UNITS = {
  "party1",
  "party2",
  "party3",
  "party4"
}
local MAX_AURAS = 40
local SLOTS = {
  mh = 16,
  oh = 17
}
local WEAPON_CLASS = 2
-- Armor class 4, subclass 6: a shield (what Righteous Fury keys on).
local ARMOR_CLASS, SHIELD_SUBCLASS = 4, 6
local RANGED_SUBCLASS = {
  [2] = true,
  [3] = true,
  [16] = true,
  [18] = true,
  [19] = true,
  [20] = true
}
local BLUNT_SUBCLASS = {
  [4] = true,
  [5] = true,
  [10] = true,
  [13] = true
}
local pack
pack = function(...)
  return {
    n = select("#", ...),
    ...
  }
end
local safe
safe = function(fn, ...)
  if not (fn) then
    return nil
  end
  local r = pack(pcall(fn, ...))
  if not (r[1]) then
    return nil
  end
  return unpack(r, 2, r.n)
end
Snapshot.safe = safe
local isSecret
isSecret = function(v)
  local f = _G.issecretvalue
  if not (f and v ~= nil) then
    return false
  end
  local ok, res = pcall(f, v)
  return ok and res == true
end
Snapshot.isSecret = isSecret
local readable
readable = function(v)
  if isSecret(v) then
    return nil
  else
    return v
  end
end
local spellInfo
spellInfo = function(id)
  local C = _G.C_Spell
  if C and C.GetSpellInfo then
    local info = safe(C.GetSpellInfo, id)
    if lua_type(info) == "table" then
      return info.name, info.iconID
    end
  end
  if _G.GetSpellInfo then
    local name, _, icon = safe(_G.GetSpellInfo, id)
    return name, icon
  end
  return nil
end
local spellKnown
spellKnown = function(id, name)
  local IsPlayerSpell, IsSpellKnown = _G.IsPlayerSpell, _G.IsSpellKnown
  if IsPlayerSpell and safe(IsPlayerSpell, id) == true then
    return true
  end
  if IsSpellKnown and safe(IsSpellKnown, id) == true then
    return true
  end
  if IsSpellKnown and safe(IsSpellKnown, id, true) == true then
    return true
  end
  if not IsPlayerSpell and not IsSpellKnown and name and _G.GetSpellInfo then
    return safe(_G.GetSpellInfo, name) ~= nil
  end
  return false
end
local spellUsable
spellUsable = function(name)
  local C = _G.C_Spell
  if C and C.IsSpellUsable then
    local usable, noMana = safe(C.IsSpellUsable, name)
    return readable(usable), readable(noMana)
  end
  if _G.IsUsableSpell then
    local usable, noMana = safe(_G.IsUsableSpell, name)
    return readable(usable), readable(noMana)
  end
  return nil, nil
end
Snapshot.readSpell = function(id)
  local name, icon = spellInfo(id)
  name = readable(name)
  local s = {
    name = name,
    icon = icon,
    known = false
  }
  if not (name) then
    return s
  end
  s.known = spellKnown(id, name)
  if s.known then
    local usable, noMana = spellUsable(name)
    if usable == nil then
      s.usable = nil
    else
      s.usable = (usable and true or false)
    end
    s.noMana = noMana and true or false
  end
  return s
end
Snapshot.readAuras = function(unit)
  local list = { }
  local C = _G.C_UnitAuras
  if C and C.GetAuraDataByIndex then
    for i = 1, MAX_AURAS do
      local ok, data = pcall(C.GetAuraDataByIndex, unit, i, "HELPFUL")
      if not (ok) then
        return nil, "aura read failed (" .. tostring(tostring(data)) .. ")"
      end
      if not (data) then
        break
      end
      if isSecret(data) or isSecret(data.name) or isSecret(data.spellId) then
        return nil, "aura data is secret"
      end
      local fromPlayer = data.sourceUnit == "player" or data.sourceUnit == "pet"
      if isSecret(data.sourceUnit) then
        fromPlayer = false
      end
      list[#list + 1] = {
        name = data.name,
        spellId = data.spellId,
        expires = readable(data.expirationTime),
        fromPlayer = fromPlayer
      }
    end
    return list
  end
  local legacy = _G.UnitBuff or (_G.UnitAura and function(u, i)
    return _G.UnitAura(u, i, "HELPFUL")
  end)
  if legacy then
    for i = 1, MAX_AURAS do
      local r = pack(pcall(legacy, unit, i))
      if not (r[1]) then
        return nil, "aura read failed (" .. tostring(tostring(r[2])) .. ")"
      end
      local name = r[2]
      if not (name) then
        break
      end
      local expires, source, spellId = r[7], r[8], r[11]
      if isSecret(name) or isSecret(spellId) then
        return nil, "aura data is secret"
      end
      list[#list + 1] = {
        name = name,
        spellId = spellId,
        expires = readable(expires),
        fromPlayer = source == "player" or source == "pet"
      }
    end
    return list
  end
  return nil, "no aura API"
end
local unitUsesMana
unitUsesMana = function(unit)
  local maxMana = readable(safe(_G.UnitPowerMax, unit, 0))
  if maxMana and maxMana > 0 then
    return true
  end
  return readable(safe(_G.UnitPowerType, unit)) == 0
end
Snapshot.readUnit = function(unit)
  local exists
  if unit == "player" then
    exists = true
  else
    exists = readable(safe(_G.UnitExists, unit)) == true
  end
  local ud = {
    exists = exists
  }
  if not (exists) then
    return ud
  end
  local _, classToken = safe(_G.UnitClass, unit)
  ud.class = readable(classToken)
  local dead = safe(_G.UnitIsDeadOrGhost, unit) or safe(_G.UnitIsDead, unit)
  ud.dead = readable(dead) == true
  if _G.UnitIsConnected then
    ud.connected = readable(safe(_G.UnitIsConnected, unit)) ~= false
  end
  if _G.UnitIsVisible then
    ud.visible = readable(safe(_G.UnitIsVisible, unit)) ~= false
  end
  if unit ~= "player" and _G.UnitInRange then
    local inRange, checked = safe(_G.UnitInRange, unit)
    inRange, checked = readable(inRange), readable(checked)
    if checked == false or inRange == nil then
      ud.inRange = nil
    else
      ud.inRange = (inRange and true or false)
    end
  end
  ud.usesMana = unitUsesMana(unit)
  -- A tank: the raid's Main Tank assignment, or the Tank group role.
  local mainTank = _G.GetPartyAssignment and readable(safe(_G.GetPartyAssignment, "MAINTANK", unit))
  local role = _G.UnitGroupRolesAssigned and readable(safe(_G.UnitGroupRolesAssigned, unit))
  ud.tank = mainTank == true or role == "TANK"
  return ud
end
-- Who the group buffs go to after the player, in order: the player's own
-- party (party1-4), then the rest of the raid by subgroup. The player's own
-- party also has raid tokens; those are skipped so nobody is listed twice.
Snapshot.groupUnits = function()
  local out = { }
  for _index_0 = 1, #PARTY_UNITS do
    out[#out + 1] = PARTY_UNITS[_index_0]
  end
  if not (safe(_G.IsInRaid) == true) then
    return out
  end
  local n = tonumber(safe(_G.GetNumGroupMembers)) or 0
  local raid = { }
  for i = 1, math.min(n, 40) do
    local unit = "raid" .. tostring(i)
    local own = readable(safe(_G.UnitIsUnit, unit, "player")) == true
    for _index_0 = 1, #PARTY_UNITS do
      if not own and readable(safe(_G.UnitIsUnit, unit, PARTY_UNITS[_index_0])) == true then
        own = true
      end
    end
    if not own then
      local _, _, subgroup = safe(_G.GetRaidRosterInfo, i)
      raid[#raid + 1] = {
        unit = unit,
        group = tonumber(readable(subgroup)) or 9,
        index = i
      }
    end
  end
  table.sort(raid, function(a, b)
    if a.group ~= b.group then
      return a.group < b.group
    end
    return a.index < b.index
  end)
  for _index_0 = 1, #raid do
    out[#out + 1] = raid[_index_0].unit
  end
  return out
end
Snapshot.readBags = function()
  local counts = { }
  local C = _G.C_Container
  local numSlots = (C and C.GetContainerNumSlots) or _G.GetContainerNumSlots
  local lastBag = _G.NUM_BAG_SLOTS or 4
  if not (numSlots) then
    return counts
  end
  for bag = 0, lastBag do
    local n = safe(numSlots, bag) or 0
    for slot = 1, n do
      local itemId, count = nil, nil
      if C and C.GetContainerItemInfo then
        local info = safe(C.GetContainerItemInfo, bag, slot)
        if lua_type(info) == "table" then
          itemId, count = info.itemID, info.stackCount
        end
      elseif _G.GetContainerItemInfo then
        local r = pack(safe(_G.GetContainerItemInfo, bag, slot))
        count, itemId = r[2], r[10]
      end
      if itemId then
        counts[itemId] = (counts[itemId] or 0) + (count or 1)
      end
    end
  end
  return counts
end
local itemInstant
itemInstant = function(itemId)
  local C = _G.C_Item
  local fn = (C and C.GetItemInfoInstant) or _G.GetItemInfoInstant
  if not (fn) then
    return nil
  end
  local r = pack(safe(fn, itemId))
  return r[5], r[6], r[7]
end
Snapshot.itemUsable = function(itemId, level)
  local C = _G.C_Item
  local usableFn = (C and C.IsUsableItem) or _G.IsUsableItem
  local usable = nil
  if usableFn then
    usable = (safe(usableFn, itemId) and true or false)
  end
  local infoFn = (C and C.GetItemInfo) or _G.GetItemInfo
  if infoFn and level then
    local r = pack(safe(infoFn, itemId))
    local minLevel = r[5]
    if lua_type(minLevel) == "number" and minLevel > level then
      return false
    end
  end
  return usable
end
Snapshot.itemName = function(itemId)
  local C = _G.C_Item
  local fn = (C and C.GetItemInfo) or _G.GetItemInfo
  if not (fn) then
    return nil
  end
  local name = safe(fn, itemId)
  return lua_type(name) == "string" and name or nil
end
Snapshot.itemSpell = function(itemId)
  local C = _G.C_Item
  local fn = (C and C.GetItemSpell) or _G.GetItemSpell
  if not (fn) then
    return nil
  end
  local name, id = safe(fn, itemId)
  return readable(name), readable(id)
end
Snapshot.readWeapons = function()
  local out = { }
  local enchant = pack(safe(_G.GetWeaponEnchantInfo))
  local state = {
    mh = {
      has = enchant[1],
      exp = enchant[2]
    },
    oh = {
      has = enchant[5],
      exp = enchant[6]
    }
  }
  for key, slot in pairs(SLOTS) do
    local itemId = safe(_G.GetInventoryItemID, "player", slot)
    local w = {
      itemId = itemId,
      isWeapon = false
    }
    if itemId then
      local _, classID, subclassID = itemInstant(itemId)
      w.isWeapon = classID == WEAPON_CLASS and not RANGED_SUBCLASS[subclassID]
      w.blunt = BLUNT_SUBCLASS[subclassID] == true
      w.isShield = classID == ARMOR_CLASS and subclassID == SHIELD_SUBCLASS
    end
    w.hasEnchant = readable(state[key].has) and true or false
    local exp = readable(state[key].exp)
    w.remaining = (lua_type(exp) == "number" and exp / 1000) or nil
    out[key] = w
  end
  return out
end
local pct
pct = function(cur, max)
  cur, max = readable(cur), readable(max)
  if not (lua_type(cur) == "number" and lua_type(max) == "number" and max > 0) then
    return 100
  end
  return cur / max * 100
end
local namesFor
namesFor = function(snap, ids, fallback)
  local names = { }
  local _list_0 = (ids or { })
  for _index_0 = 1, #_list_0 do
    local id = _list_0[_index_0]
    local s = snap.spells[id]
    if s and s.name then
      names[#names + 1] = s.name
    end
  end
  local _list_1 = (fallback or { })
  for _index_0 = 1, #_list_1 do
    local n = _list_1[_index_0]
    names[#names + 1] = n
  end
  return names
end
local hasAuraNamed
hasAuraNamed = function(unitData, names)
  if not (unitData and unitData.auras) then
    return false
  end
  local set = { }
  for _index_0 = 1, #names do
    local n = names[_index_0]
    set[n] = true
  end
  local _list_0 = unitData.auras
  for _index_0 = 1, #_list_0 do
    local aura = _list_0[_index_0]
    if aura.name and set[aura.name] then
      return true
    end
  end
  return false
end
Snapshot.classToken = function()
  local _, token = safe(_G.UnitClass, "player")
  return token
end
Snapshot.build = function(classRules, opts)
  if opts == nil then
    opts = { }
  end
  local Rules = _G.idUpkeep_UpkeepRules
  local snap = {
    class = Snapshot.classToken(),
    level = safe(_G.UnitLevel, "player") or 1,
    now = safe(_G.GetTime) or 0,
    spells = { },
    units = { }
  }
  local inInstance = safe(_G.IsInInstance)
  snap.inInstance = inInstance == true
  local lockdown = safe(_G.InCombatLockdown) == true
  snap.inCombat = lockdown or readable(safe(_G.UnitAffectingCombat, "player")) == true
  local casting = readable(safe(_G.UnitCastingInfo, "player")) or readable(safe(_G.UnitChannelInfo, "player"))
  snap.casting = casting ~= nil and casting or nil
  snap.shapeshiftForm = tonumber(readable(safe(_G.GetShapeshiftForm))) or 0
  local inForm = snap.class == "DRUID" and snap.shapeshiftForm ~= 0
  if Rules then
    local _list_0 = Rules.collectSpellIds(classRules)
    for _index_0 = 1, #_list_0 do
      local id = _list_0[_index_0]
      local s = Snapshot.readSpell(id)
      if inForm and s.known then
        s.usable, s.noMana = nil, nil
      end
      snap.spells[id] = s
    end
  end
  snap.player = {
    healthPct = pct(safe(_G.UnitHealth, "player"), safe(_G.UnitHealthMax, "player")),
    manaPct = pct(safe(_G.UnitPower, "player", 0), safe(_G.UnitPowerMax, "player", 0)),
    usesMana = unitUsesMana("player"),
    dead = readable(safe(_G.UnitIsDeadOrGhost, "player")) == true
  }
  if not (snap.inCombat) then
    snap.groupOrder = Snapshot.groupUnits()
    local units = {
      "player",
      "pet"
    }
    for _index_0 = 1, #snap.groupOrder do
      units[#units + 1] = snap.groupOrder[_index_0]
    end
    for _index_0 = 1, #units do
      local unit = units[_index_0]
      local ud = Snapshot.readUnit(unit)
      if ud.exists then
        local auras, err = Snapshot.readAuras(unit)
        if not (auras) then
          snap.unreadable = tostring(unit) .. ": " .. tostring(err)
          break
        end
        ud.auras = auras
      end
      snap.units[unit] = ud
    end
  end
  local pet = snap.units.pet or { }
  snap.pet = {
    exists = pet.exists == true,
    dead = pet.dead == true
  }
  if snap.class == "HUNTER" and opts.petDead and not snap.pet.exists then
    snap.pet.dead = true
  end
  local spellsAura = (Rules and Rules.AURA_SPELLS) or { }
  local fallback = (Rules and Rules.AURA_FALLBACK_NAMES) or { }
  local player = snap.units.player
  snap.isEating = hasAuraNamed(player, namesFor(snap, spellsAura.food, fallback.food))
  snap.isDrinking = hasAuraNamed(player, namesFor(snap, spellsAura.drink, fallback.drink))
  local wellFedIds
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = (spellsAura.wellFed or { })
    for _index_0 = 1, #_list_0 do
      local id = _list_0[_index_0]
      _accum_0[_len_0] = id
      _len_0 = _len_0 + 1
    end
    wellFedIds = _accum_0
  end
  local _list_0 = (spellsAura.wellFedById or { })
  for _index_0 = 1, #_list_0 do
    local id = _list_0[_index_0]
    wellFedIds[#wellFedIds + 1] = id
  end
  snap.wellFed = {
    ids = wellFedIds,
    names = namesFor(snap, spellsAura.wellFed, fallback.wellFed)
  }
  snap.items = Snapshot.readBags()
  snap.itemInfo = { }
  for itemId in pairs(snap.items) do
    local icon = itemInstant(itemId)
    snap.itemInfo[itemId] = {
      usable = Snapshot.itemUsable(itemId, snap.level),
      icon = icon
    }
  end
  snap.weapon = Snapshot.readWeapons()
  local Consumables = _G.idUpkeep_UpkeepConsumables
  if Consumables and opts.consumables ~= false then
    local data = Consumables.build(snap.items, {
      lib = Consumables.lib(),
      usable = function(id)
        return snap.itemInfo[id] and snap.itemInfo[id].usable
      end,
      itemSpell = Snapshot.itemSpell,
      itemName = Snapshot.itemName,
      consumables = classRules and classRules.consumables,
      foodBuffs = classRules and classRules.foodBuffs
    })
    for k, v in pairs(data) do
      snap[k] = v
    end
  end
  return snap
end
_G.idUpkeep_UpkeepSnapshot = Snapshot
return Snapshot
