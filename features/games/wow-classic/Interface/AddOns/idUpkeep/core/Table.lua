local Table
do
  local _class_0
  local _base_0 = {
    _resolve_parent = function(tbl, parts, createMissing)
      if createMissing == nil then
        createMissing = true
      end
      local current = tbl
      for i = 1, #parts - 1 do
        local part = parts[i]
        if type(current[part]) ~= "table" then
          if not (createMissing) then
            return nil
          end
          current[part] = { }
        end
        current = current[part]
      end
      return {
        current,
        parts[#parts]
      }
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "Table"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.deep_copy = function(value)
    if type(value) ~= "table" then
      return nil
    end
    local copy = { }
    for k, v in pairs(value) do
      if type(v) == "table" then
        copy[k] = Table.deep_copy(v)
      else
        copy[k] = v
      end
    end
    return copy
  end
  self.deep_merge = function(source, target, overwrite)
    if overwrite == nil then
      overwrite = true
    end
    for key, value in pairs(source) do
      if type(value) == "table" then
        if type(target[key]) ~= "table" then
          target[key] = { }
        end
        Table.deep_merge(value, target[key], overwrite)
      elseif overwrite or target[key] == nil then
        target[key] = value
      end
    end
    return target
  end
  self.merge_defaults = function(defaults, target)
    return Table.deep_merge(defaults, target, false)
  end
  self.split_path = function(dotPath)
    local _accum_0 = { }
    local _len_0 = 1
    for part in string.gmatch(dotPath, "[^%.]+") do
      _accum_0[_len_0] = part
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end
  self.rename_field = function(tbl, oldPath, newPath)
    local parent, oldKey
    do
      local _obj_0 = Table._resolve_parent(tbl, Table.split_path(oldPath), false)
      parent, oldKey = _obj_0[1], _obj_0[2]
    end
    if not (parent and parent[oldKey] ~= nil) then
      return false
    end
    local value = parent[oldKey]
    parent[oldKey] = nil
    local newParent, newKey
    do
      local _obj_0 = Table._resolve_parent(tbl, Table.split_path(newPath), true)
      newParent, newKey = _obj_0[1], _obj_0[2]
    end
    newParent[newKey] = value
    return true
  end
  self.add_field = function(tbl, path, defaultValue)
    local parent, key
    do
      local _obj_0 = Table._resolve_parent(tbl, Table.split_path(path), true)
      parent, key = _obj_0[1], _obj_0[2]
    end
    if parent[key] == nil then
      parent[key] = defaultValue
      return true
    end
    return false
  end
  self.remove_field = function(tbl, path)
    local res = Table._resolve_parent(tbl, Table.split_path(path), false)
    if not (res) then
      return false
    end
    local parent, key = res[1], res[2]
    if not (parent and parent[key] ~= nil) then
      return false
    end
    parent[key] = nil
    return true
  end
  self.transform_field = function(tbl, path, fn)
    local parent, key
    do
      local _obj_0 = Table._resolve_parent(tbl, Table.split_path(path), false)
      parent, key = _obj_0[1], _obj_0[2]
    end
    if not (parent and parent[key] ~= nil) then
      return false
    end
    local ok, newVal = pcall(fn, parent[key])
    if not (ok) then
      return false
    end
    parent[key] = newVal
    return true
  end
  self.move_data = function(tbl, fromPath, toPath, removeOriginal)
    if removeOriginal == nil then
      removeOriginal = true
    end
    local pFrom, kFrom
    do
      local _obj_0 = Table._resolve_parent(tbl, Table.split_path(fromPath), false)
      pFrom, kFrom = _obj_0[1], _obj_0[2]
    end
    if not (pFrom and pFrom[kFrom] ~= nil) then
      return false
    end
    local value = pFrom[kFrom]
    local pTo, kTo
    do
      local _obj_0 = Table._resolve_parent(tbl, Table.split_path(toPath), true)
      pTo, kTo = _obj_0[1], _obj_0[2]
    end
    pTo[kTo] = value
    if removeOriginal then
      pFrom[kFrom] = nil
    end
    return true
  end
  self.map_list = function(tbl, fn)
    local res = { }
    for idx, val in ipairs(tbl) do
      table.insert(res, fn(val, idx))
    end
    return res
  end
  self.filter_list = function(tbl, predicate)
    local res = { }
    for idx, val in ipairs(tbl) do
      if predicate(val, idx) then
        table.insert(res, val)
      end
    end
    return res
  end
  self.reduce_list = function(tbl, fn, initial)
    if initial == nil then
      initial = nil
    end
    local acc = initial
    for idx, val in ipairs(tbl) do
      if acc == nil and idx == 1 then
        acc = val
      else
        acc = fn(acc, val, idx)
      end
    end
    return acc
  end
  self.map_object = function(tbl, fn)
    local res = { }
    for k, v in pairs(tbl) do
      res[k] = fn(v, k)
    end
    return res
  end
  self.filter_object = function(tbl, predicate)
    local res = { }
    for k, v in pairs(tbl) do
      if predicate(v, k) then
        res[k] = v
      end
    end
    return res
  end
  self.reduce_object = function(tbl, fn, initial)
    if initial == nil then
      initial = nil
    end
    local acc = initial
    local first = true
    for k, v in pairs(tbl) do
      if acc == nil and first then
        acc = v
      else
        acc = fn(acc, v, k)
      end
      first = false
    end
    return acc
  end
  self.find_list = function(tbl, predicate)
    for idx, val in ipairs(tbl) do
      if predicate(val, idx) then
        return val, idx
      end
    end
    return nil
  end
  self.find_object = function(tbl, predicate)
    for k, v in pairs(tbl) do
      if predicate(v, k) then
        return v, k
      end
    end
    return nil
  end
  self.find = function(tbl, predicate)
    if Table.is_list(tbl) then
      return Table.find_list(tbl, predicate)
    else
      return Table.find_object(tbl, predicate)
    end
  end
  self.is_list = function(tbl)
    if type(tbl) ~= "table" then
      return false
    end
    local n = #tbl
    local count = 0
    for k in pairs(tbl) do
      if type(k) ~= "number" then
        return false
      end
      count = count + 1
    end
    return count == n
  end
  self.map = function(tbl, fn)
    if Table.is_list(tbl) then
      return Table.map_list(tbl, fn)
    else
      return Table.map_object(tbl, fn)
    end
  end
  self.filter = function(tbl, predicate)
    if Table.is_list(tbl) then
      return Table.filter_list(tbl, predicate)
    else
      return Table.filter_object(tbl, predicate)
    end
  end
  self.reduce = function(tbl, fn, initial)
    if initial == nil then
      initial = nil
    end
    if Table.is_list(tbl) then
      return Table.reduce_list(tbl, fn, initial)
    else
      return Table.reduce_object(tbl, fn, initial)
    end
  end
  Table = _class_0
end
_G.idUpkeep_Table = Table
return Table
