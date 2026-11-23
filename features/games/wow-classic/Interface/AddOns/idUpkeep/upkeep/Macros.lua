local lua_type = _G.type
local Macros = { }
Macros.MAX_NAME = 16
Macros.MAX_BODY = 255
Macros.ICON = "INV_MISC_QUESTIONMARK"
Macros.SPECS = {
  {
    job = "buffs",
    name = "Upkeep Buffs",
    button = "idUpkeepBuffsButton",
    action = "click"
  },
  {
    job = "health",
    name = "Upkeep Health",
    button = "idUpkeepHealthButton",
    action = "use"
  },
  {
    job = "mana",
    name = "Upkeep Mana",
    button = "idUpkeepManaButton",
    action = "use"
  }
}
Macros.clickLine = function(spec)
  return "/click " .. tostring(spec.button)
end
Macros.actionLine = function(spec, use)
  if not (spec.action == "use") then
    return Macros.clickLine(spec)
  end
  if not (use and use ~= "") then
    return nil
  end
  return "/use " .. tostring(use)
end
Macros.bodyFor = function(spec, hint, use)
  local show
  if hint and hint ~= "" then
    show = "#showtooltip " .. tostring(hint)
  else
    show = "#showtooltip"
  end
  local action = Macros.actionLine(spec, use)
  if not (action) then
    return show
  end
  return tostring(show) .. "\n" .. tostring(action)
end
Macros.hintForStep = function(step)
  if not (step) then
    return nil
  end
  if step.showHint then
    return step.showHint
  end
  if step.kind == "spell" and step.spell then
    return tostring(step.spell)
  end
  if step.kind == "item" and step.item then
    return ("item:%d"):format(step.item)
  end
  return nil
end
Macros.useForStep = function(step)
  return step and step.useHint or nil
end
Macros.liveApi = function()
  return {
    createMacro = _G.CreateMacro,
    editMacro = _G.EditMacro,
    getMacroIndexByName = _G.GetMacroIndexByName,
    getMacroInfo = _G.GetMacroInfo,
    getNumMacros = _G.GetNumMacros,
    maxAccountMacros = _G.MAX_ACCOUNT_MACROS or 120
  }
end
Macros.bodyPresses = function(body, spec)
  if not (lua_type(body) == "string") then
    return false
  end
  if not (spec.action == "use") then
    return (body:find(Macros.clickLine(spec), 1, true)) ~= nil
  end
  return (body:find("\n/use ")) ~= nil or (body:match("^%s*/use ")) ~= nil
end
Macros.isOurs = function(body, spec)
  if not (lua_type(body) == "string") then
    return false
  end
  local trimmed = body:gsub("^%s+", ""):gsub("%s+$", "")
  if trimmed == "" then
    return false
  end
  local click = Macros.clickLine(spec)
  local mine
  mine = function(line)
    if line:match("^#showtooltip") then
      return true
    end
    if line == click then
      return true
    end
    if spec.action == "use" and line:match("^/use ") then
      return true
    end
    return false
  end
  for line in trimmed:gmatch("[^\n]+") do
    if not (mine(line)) then
      return false
    end
  end
  return true
end
Macros.planFor = function(api, spec, hint, use)
  if not (api and api.getMacroIndexByName and api.createMacro) then
    return "skip", "no macro API"
  end
  local ok, index = pcall(api.getMacroIndexByName, spec.name)
  if not (ok) then
    return "skip", "cannot read the macro list"
  end
  if not index or index == 0 then
    return "create", nil
  end
  if not (api.getMacroInfo) then
    return "skip", "cannot read the macro body"
  end
  local ok2, _, body
  ok2, _, _, body = pcall(api.getMacroInfo, index)
  if not (ok2) then
    return "skip", "cannot read the macro body"
  end
  if Macros.isOurs(body, spec) then
    if body ~= Macros.bodyFor(spec, hint, use) then
      return "retune", nil
    end
    return "keep", nil
  end
  if Macros.bodyPresses(body, spec) then
    return "keep", nil
  end
  return "repair", nil
end
Macros.freeSlots = function(api)
  if not (api and api.getNumMacros) then
    return nil
  end
  local ok, account = pcall(api.getNumMacros)
  if not (ok and lua_type(account) == "number") then
    return nil
  end
  return (api.maxAccountMacros or 120) - account
end
Macros.ensure = function(api, hints, uses)
  if hints == nil then
    hints = { }
  end
  if uses == nil then
    uses = { }
  end
  local results, problems = { }, { }
  local _list_0 = Macros.SPECS
  for _index_0 = 1, #_list_0 do
    local _continue_0 = false
    repeat
      local spec = _list_0[_index_0]
      local hint, use = hints[spec.job], uses[spec.job]
      local action, why = Macros.planFor(api, spec, hint, use)
      if action == "skip" then
        results[spec.job] = "skipped"
        problems[#problems + 1] = ("%s: %s"):format(spec.name, (why or "unavailable"))
        _continue_0 = true
        break
      end
      if action == "keep" then
        results[spec.job] = "kept"
        _continue_0 = true
        break
      end
      local body = Macros.bodyFor(spec, hint, use)
      if action == "create" then
        local free = Macros.freeSlots(api)
        if free ~= nil and free <= 0 then
          results[spec.job] = "skipped"
          problems[#problems + 1] = ("%s: the account macro list is full"):format(spec.name)
          _continue_0 = true
          break
        end
        local ok, err = pcall(api.createMacro, spec.name, Macros.ICON, body)
        if not (ok) then
          results[spec.job] = "skipped"
          problems[#problems + 1] = ("%s: %s"):format(spec.name, tostring(err))
          _continue_0 = true
          break
        end
        results[spec.job] = "created"
      else
        if not (api.editMacro) then
          results[spec.job] = "skipped"
          problems[#problems + 1] = ("%s: cannot edit macros"):format(spec.name)
          _continue_0 = true
          break
        end
        local okIndex, index = pcall(api.getMacroIndexByName, spec.name)
        if not (okIndex and index and index ~= 0) then
          results[spec.job] = "skipped"
          problems[#problems + 1] = ("%s: disappeared before it could be repaired"):format(spec.name)
          _continue_0 = true
          break
        end
        local ok, err = pcall(api.editMacro, index, spec.name, Macros.ICON, body)
        if not (ok) then
          results[spec.job] = "skipped"
          problems[#problems + 1] = ("%s: %s"):format(spec.name, tostring(err))
          _continue_0 = true
          break
        end
        if action == "retune" then
          results[spec.job] = "retuned"
        else
          results[spec.job] = "repaired"
        end
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return results, problems
end
Macros.describe = function(api, hints, uses)
  if hints == nil then
    hints = { }
  end
  if uses == nil then
    uses = { }
  end
  local lines = { }
  local _list_0 = Macros.SPECS
  for _index_0 = 1, #_list_0 do
    local spec = _list_0[_index_0]
    local hint, use = hints[spec.job], uses[spec.job]
    local action = Macros.planFor(api, spec, hint, use)
    local state
    local _exp_0 = action
    if "create" == _exp_0 then
      state = "missing (will be created)"
    elseif "repair" == _exp_0 then
      state = "present but does not press the button (will be repaired)"
    elseif "retune" == _exp_0 then
      state = "icon out of date (will be updated)"
    elseif "keep" == _exp_0 then
      state = "ready"
    else
      state = "unavailable"
    end
    local performs = Macros.actionLine(spec, use) or "(nothing)"
    lines[#lines + 1] = ("%s -> %s | shows %s [%s]"):format(spec.name, performs, (hint or "nothing"), state)
  end
  return lines
end
_G.idUpkeep_UpkeepMacros = Macros
return Macros
