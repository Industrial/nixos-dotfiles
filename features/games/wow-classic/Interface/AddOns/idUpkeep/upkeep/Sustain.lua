local tostring = _G.tostring
local lua_type = _G.type
local Sustain = { }
Sustain.SETS = {
  health = {
    safe = {
      {
        set = "Consumable.Food.Edible.Basic.Conjured",
        conjured = true
      },
      {
        set = "Consumable.Food.Edible.Basic.Non-Conjured"
      },
      {
        set = "Consumable.Bandage.Basic",
        bandage = true
      }
    },
    combat = {
      {
        set = "Consumable.Cooldown.Stone.Health.Warlock",
        free = true
      },
      {
        set = "Consumable.Potion.Recovery.Healing.Basic"
      },
      {
        set = "Consumable.Cooldown.Potion.Health.Basic"
      }
    }
  },
  mana = {
    safe = {
      {
        set = "Consumable.Water.Conjured",
        conjured = true
      },
      {
        set = "Consumable.Water.Basic"
      }
    },
    combat = {
      {
        set = "Consumable.Cooldown.Stone.Mana.Mana Stone",
        free = true
      },
      {
        set = "Consumable.Potion.Recovery.Mana.Basic"
      },
      {
        set = "Consumable.Cooldown.Potion.Mana.Basic"
      }
    }
  }
}
local Restock_isConjuredName
Restock_isConjuredName = function(name)
  return _G.idUpkeep_UpkeepRules.isConjuredName(name)
end
Sustain.isConjuredName = Restock_isConjuredName
local candidatesFor
candidatesFor = function(ctx, counts, def)
  local Consumables = _G.idUpkeep_UpkeepConsumables
  local out = { }
  if not (Consumables and ctx.lib) then
    return out
  end
  for itemId, count in pairs((counts or { })) do
    local _continue_0 = false
    repeat
      local value = Consumables.valueIn(ctx.lib, itemId, def.set)
      if not (value) then
        _continue_0 = true
        break
      end
      local usable = nil
      if ctx.usable then
        local ok, u = pcall(ctx.usable, itemId)
        if ok then
          usable = u
        end
      end
      if usable == false then
        _continue_0 = true
        break
      end
      local name = nil
      if ctx.itemName then
        local okName, n = pcall(ctx.itemName, itemId)
        if okName and lua_type(n) == "string" and n ~= "" then
          name = n
        end
      end
      out[#out + 1] = {
        itemId = itemId,
        name = name,
        count = count,
        value = value,
        conjured = def.conjured == true or Restock_isConjuredName(name),
        bandage = def.bandage == true,
        free = def.free == true
      }
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  Sustain.sortCandidates(out)
  return out
end
Sustain.sortCandidates = function(list)
  table.sort(list, _G.idUpkeep_UpkeepRules.betterRestore)
  return list
end
Sustain.pick = function(job, branch, counts, ctx)
  if ctx == nil then
    ctx = { }
  end
  local spec = Sustain.SETS[job]
  if not (spec and spec[branch]) then
    return nil
  end
  local byId = { }
  for tier, def in ipairs(spec[branch]) do
    local _list_0 = candidatesFor(ctx, counts, def)
    for _index_0 = 1, #_list_0 do
      local candidate = _list_0[_index_0]
      candidate.tier = tier
      local prev = byId[candidate.itemId]
      if prev then
        if candidate.conjured then
          prev.conjured = true
        end
      else
        byId[candidate.itemId] = candidate
      end
    end
  end
  local all
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _, candidate in pairs(byId) do
      _accum_0[_len_0] = candidate
      _len_0 = _len_0 + 1
    end
    all = _accum_0
  end
  if #all == 0 then
    return nil
  end
  Sustain.sortCandidates(all)
  return all[1]
end
local refer
refer = function(candidate, mode)
  if not (candidate) then
    return nil
  end
  if mode == "action" and candidate.name then
    return candidate.name
  end
  return ("item:%d"):format(candidate.itemId)
end
Sustain.conditional = function(chosen, mode)
  if mode == nil then
    mode = "action"
  end
  if not (chosen) then
    return nil
  end
  local combat, safe = refer(chosen.combat, mode), refer(chosen.safe, mode)
  if combat and safe then
    return ("[combat] %s; %s"):format(combat, safe)
  end
  if combat then
    return ("[combat] %s"):format(combat)
  end
  if safe then
    return ("[nocombat] %s"):format(safe)
  end
  return nil
end
Sustain.macroFor = function(job, counts, ctx)
  if ctx == nil then
    ctx = { }
  end
  local chosen = {
    combat = Sustain.pick(job, "combat", counts, ctx),
    safe = Sustain.pick(job, "safe", counts, ctx)
  }
  local conditional = Sustain.conditional(chosen, "action")
  if not (conditional) then
    return nil, chosen
  end
  return ("/use %s"):format(conditional), chosen
end
Sustain.step = function(job, counts, ctx)
  if ctx == nil then
    ctx = { }
  end
  local text, chosen = Sustain.macroFor(job, counts, ctx)
  if not (text) then
    return nil, "nothing for " .. tostring(job) .. " in the bags"
  end
  local label
  if chosen.combat and chosen.safe then
    label = tostring(job) .. ": combat + safe"
  elseif chosen.combat then
    label = tostring(job) .. ": combat only"
  else
    label = tostring(job) .. ": out of combat only"
  end
  return {
    kind = "macro",
    macrotext = text,
    label = label,
    job = job,
    key = "sustain:" .. tostring(job) .. ":" .. tostring(text),
    chosen = chosen,
    showHint = Sustain.conditional(chosen, "display"),
    useHint = Sustain.conditional(chosen, "action")
  }, nil
end
Sustain.explain = function(job, counts, ctx)
  if ctx == nil then
    ctx = { }
  end
  local step, reason = Sustain.step(job, counts, ctx)
  if not (step) then
    return {
      "[" .. tostring(job) .. "] nothing: " .. tostring(tostring(reason))
    }
  end
  local lines = { }
  local _list_0 = {
    "combat",
    "safe"
  }
  for _index_0 = 1, #_list_0 do
    local branch = _list_0[_index_0]
    local c = step.chosen[branch]
    if c then
      lines[#lines + 1] = ("[%s] %s: item %d (restores %s, stack of %d)"):format(job, branch, c.itemId, tostring(c.value), (c.count or 0))
    else
      lines[#lines + 1] = ("[%s] %s: nothing in the bags"):format(job, branch)
    end
  end
  lines[#lines + 1] = "[" .. tostring(job) .. "] macro: " .. tostring(step.macrotext)
  return lines
end
_G.idUpkeep_UpkeepSustain = Sustain
return Sustain
