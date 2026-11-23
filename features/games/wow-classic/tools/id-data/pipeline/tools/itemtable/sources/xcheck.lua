local M = { }
M.adapters = { }
M.register = function(name, fn)
  M.adapters[name] = fn
end
M.register("questiedb", function(opts)
  if opts == nil then
    opts = { }
  end
  return nil, "QuestieDB's Forever dataset is codec-encoded (src/meta/codec.lua); " .. "decoding it is unimplemented, so this adapter abstains"
end)
M.loadSnapshot = function(path)
  local env = { }
  local chunk, err
  if setfenv then
    chunk, err = loadfile(path)
    if chunk then
      setfenv(chunk, env)
    end
  else
    chunk, err = loadfile(path, "t", env)
  end
  if not (chunk) then
    return nil, ("cannot load %s: %s"):format(path, tostring(err))
  end
  local ok, result = pcall(chunk)
  if not (ok) then
    return nil, ("error executing %s: %s"):format(path, tostring(result))
  end
  if not (type(result) == "table") then
    return nil, ("%s returned no table"):format(path)
  end
  return result
end
M.compare = function(model, crossRef)
  local report = {
    checked = 0,
    agreed = 0,
    discrepancies = { },
    missing = { }
  }
  if not (type(model) == "table" and type(crossRef) == "table") then
    return report
  end
  local ours = { }
  local _list_0 = (model.items or { })
  for _index_0 = 1, #_list_0 do
    local item = _list_0[_index_0]
    ours[item.id] = item
  end
  local ids
  do
    local _accum_0 = { }
    local _len_0 = 1
    for id in pairs(crossRef) do
      _accum_0[_len_0] = id
      _len_0 = _len_0 + 1
    end
    ids = _accum_0
  end
  table.sort(ids)
  for _index_0 = 1, #ids do
    local _continue_0 = false
    repeat
      local id = ids[_index_0]
      local theirs = crossRef[id]
      if not (type(theirs) == "table") then
        _continue_0 = true
        break
      end
      local mine = ours[id]
      if not (mine) then
        report.missing[#report.missing + 1] = id
        _continue_0 = true
        break
      end
      report.checked = report.checked + 1
      local disagreed = false
      local _list_1 = {
        "name",
        "class",
        "subclass"
      }
      for _index_1 = 1, #_list_1 do
        local _continue_1 = false
        repeat
          local fieldName = _list_1[_index_1]
          local a, b = mine[fieldName], theirs[fieldName]
          if b == nil then
            _continue_1 = true
            break
          end
          if a ~= b then
            disagreed = true
            report.discrepancies[#report.discrepancies + 1] = {
              itemId = id,
              field = fieldName,
              ours = a,
              theirs = b
            }
          end
          _continue_1 = true
        until true
        if not _continue_1 then
          break
        end
      end
      if not (disagreed) then
        report.agreed = report.agreed + 1
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return report
end
M.format = function(name, report)
  local lines = {
    ("%s: %d checked, %d agreed, %d discrepancies, %d unknown to us"):format(name, report.checked, report.agreed, #report.discrepancies, #report.missing)
  }
  local _list_0 = report.discrepancies
  for _index_0 = 1, #_list_0 do
    local d = _list_0[_index_0]
    lines[#lines + 1] = ("  item %d %s: ours=%s theirs=%s"):format(d.itemId, d.field, tostring(d.ours), tostring(d.theirs))
  end
  return lines
end
M.runAll = function(model, opts)
  if opts == nil then
    opts = { }
  end
  local results = { }
  local names
  do
    local _accum_0 = { }
    local _len_0 = 1
    for name in pairs(M.adapters) do
      _accum_0[_len_0] = name
      _len_0 = _len_0 + 1
    end
    names = _accum_0
  end
  table.sort(names)
  for _index_0 = 1, #names do
    local name = names[_index_0]
    local data, reason = M.adapters[name](opts)
    if data then
      results[#results + 1] = {
        name = name,
        report = M.compare(model, data)
      }
    else
      results[#results + 1] = {
        name = name,
        abstained = reason
      }
    end
  end
  return results
end
return M
