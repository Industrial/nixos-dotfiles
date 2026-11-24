local M = { }
M.decodeSet = function(raw)
  local out = { }
  if not (type(raw) == "string") then
    return out
  end
  for entry in raw:gmatch("[^,]+") do
    local id, value = entry:match("^(%-?%d+):(%-?%d+%.?%d*)$")
    if id then
      out[tonumber(id)] = tonumber(value)
    else
      local bare = entry:match("^(%-?%d+)$")
      if bare then
        out[tonumber(bare)] = 1
      end
    end
  end
  return out
end
M.loadCommitted = function(path)
  local captured = nil
  local saved = _G.LibStub
  local stub = {
    NewLibrary = function(self)
      return nil
    end,
    GetLibrary = function(self)
      return {
        AddData = function(_, _domain, _revision, data)
          captured = data, {
            AddManifest = function()
              return true
            end
          }
        end
      }
    end
  }
  _G.LibStub = setmetatable(stub, {
    __call = function(_, ...)
      return stub:GetLibrary(...)
    end
  })
  local chunk = loadfile(path)
  if chunk then
    pcall(chunk)
  end
  _G.LibStub = saved
  return captured
end
M.diff = function(committed, fresh)
  committed = committed or { }
  local report = {
    addedSets = { },
    removedSets = { },
    changes = { }
  }
  local names = { }
  for name in pairs(committed) do
    names[name] = true
  end
  for name in pairs(fresh) do
    names[name] = true
  end
  local ordered
  do
    local _accum_0 = { }
    local _len_0 = 1
    for n in pairs(names) do
      _accum_0[_len_0] = n
      _len_0 = _len_0 + 1
    end
    ordered = _accum_0
  end
  table.sort(ordered)
  for _index_0 = 1, #ordered do
    local _continue_0 = false
    repeat
      local name = ordered[_index_0]
      local old = committed[name] and M.decodeSet(committed[name])
      local new = fresh[name]
      if not old and new then
        report.addedSets[#report.addedSets + 1] = name
        _continue_0 = true
        break
      end
      if old and not new then
        report.removedSets[#report.removedSets + 1] = name
        _continue_0 = true
        break
      end
      local added, removed, changed = { }, { }, { }
      for id, value in pairs(new) do
        if old[id] == nil then
          added[#added + 1] = id
        elseif old[id] ~= value then
          changed[#changed + 1] = {
            id = id,
            from = old[id],
            to = value
          }
        end
      end
      for id in pairs(old) do
        if new[id] == nil then
          removed[#removed + 1] = id
        end
      end
      if #added == 0 and #removed == 0 and #changed == 0 then
        _continue_0 = true
        break
      end
      table.sort(added)
      table.sort(removed)
      table.sort(changed, function(a, b)
        return a.id < b.id
      end)
      report.changes[#report.changes + 1] = {
        set = name,
        added = added,
        removed = removed,
        changed = changed
      }
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return report
end
M.isEmpty = function(report)
  return #report.addedSets == 0 and #report.removedSets == 0 and #report.changes == 0
end
M.format = function(report)
  if M.isEmpty(report) then
    return {
      "no changes"
    }
  end
  local lines = { }
  local _list_0 = report.addedSets
  for _index_0 = 1, #_list_0 do
    local n = _list_0[_index_0]
    lines[#lines + 1] = ("+ set %s"):format(n)
  end
  local _list_1 = report.removedSets
  for _index_0 = 1, #_list_1 do
    local n = _list_1[_index_0]
    lines[#lines + 1] = ("- set %s"):format(n)
  end
  local _list_2 = report.changes
  for _index_0 = 1, #_list_2 do
    local change = _list_2[_index_0]
    local parts = { }
    if #change.added > 0 then
      parts[#parts + 1] = ("+%d"):format(#change.added)
    end
    if #change.removed > 0 then
      parts[#parts + 1] = ("-%d"):format(#change.removed)
    end
    if #change.changed > 0 then
      parts[#parts + 1] = ("~%d"):format(#change.changed)
    end
    lines[#lines + 1] = ("  %s: %s"):format(change.set, table.concat(parts, " "))
    local _list_3 = change.added
    for _index_1 = 1, #_list_3 do
      local id = _list_3[_index_1]
      lines[#lines + 1] = ("    + %d"):format(id)
    end
    local _list_4 = change.removed
    for _index_1 = 1, #_list_4 do
      local id = _list_4[_index_1]
      lines[#lines + 1] = ("    - %d"):format(id)
    end
    local _list_5 = change.changed
    for _index_1 = 1, #_list_5 do
      local c = _list_5[_index_1]
      lines[#lines + 1] = ("    ~ %d: %s -> %s"):format(c.id, tostring(c.from), tostring(c.to))
    end
  end
  return lines
end
return M
