local schema = dofile("tools/itemtable/schema.lua")
local M = { }
local isInt
isInt = function(v)
  return type(v) == "number" and v == math.floor(v)
end
local checkers = {
  int = isInt,
  number = function(v)
    return type(v) == "number"
  end,
  string = function(v)
    return type(v) == "string"
  end,
  bool = function(v)
    return type(v) == "boolean"
  end
}
local checkFields
checkFields = function(record, value, path, errors)
  for name, spec in pairs(record.fields) do
    local v = value[name]
    if v == nil then
      if spec.required then
        errors[#errors + 1] = {
          path = tostring(path) .. "." .. tostring(name),
          message = "required field missing"
        }
      end
    elseif not checkers[spec.kind](v) then
      errors[#errors + 1] = {
        path = tostring(path) .. "." .. tostring(name),
        message = ("expected %s, got %s"):format(spec.kind, type(v))
      }
    end
  end
  for name in pairs(value) do
    if not (record.fields[name]) then
      errors[#errors + 1] = {
        path = tostring(path) .. "." .. tostring(name),
        message = "unknown field"
      }
    end
  end
end
M.validate = function(doc)
  local errors = { }
  if not (type(doc) == "table") then
    return false, {
      {
        path = "",
        message = "document is not a table"
      }
    }
  end
  for name, spec in pairs(schema.document) do
    local v = doc[name]
    if v == nil then
      if spec.required then
        errors[#errors + 1] = {
          path = name,
          message = "required field missing"
        }
      end
    elseif not checkers[spec.kind](v) then
      errors[#errors + 1] = {
        path = name,
        message = ("expected %s, got %s"):format(spec.kind, type(v))
      }
    end
  end
  if isInt(doc.schemaVersion) and doc.schemaVersion ~= schema.SCHEMA_VERSION then
    errors[#errors + 1] = {
      path = "schemaVersion",
      message = ("unsupported schema version %d (this tool speaks %d)"):format(doc.schemaVersion, schema.SCHEMA_VERSION)
    }
    return false, errors
  end
  for recordName, record in pairs(schema.records) do
    local _continue_0 = false
    repeat
      local list = doc[recordName]
      if list == nil then
        if record.optional then
          _continue_0 = true
          break
        end
        errors[#errors + 1] = {
          path = recordName,
          message = "required collection missing"
        }
      elseif type(list) ~= "table" then
        errors[#errors + 1] = {
          path = recordName,
          message = "expected a list"
        }
      else
        local seen = { }
        for i, value in ipairs(list) do
          local path = ("%s[%d]"):format(recordName, i)
          if type(value) ~= "table" then
            errors[#errors + 1] = {
              path = path,
              message = "expected a record table"
            }
          else
            checkFields(record, value, path, errors)
            if record.key then
              local k = value[record.key]
              if k ~= nil then
                if seen[k] then
                  errors[#errors + 1] = {
                    path = tostring(path) .. "." .. tostring(record.key),
                    message = ("duplicate key %s (first seen at index %d)"):format(tostring(k), seen[k])
                  }
                end
                seen[k] = i
              end
            end
          end
        end
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  local itemIds, spellIds = { }, { }
  local _list_0 = (doc.items or { })
  for _index_0 = 1, #_list_0 do
    local it = _list_0[_index_0]
    itemIds[it.id] = true
  end
  local _list_1 = (doc.spells or { })
  for _index_0 = 1, #_list_1 do
    local sp = _list_1[_index_0]
    spellIds[sp.id] = true
  end
  for i, fx in ipairs(doc.itemEffects or { }) do
    local _continue_0 = false
    repeat
      if not (type(fx) == "table") then
        _continue_0 = true
        break
      end
      if fx.itemId and not itemIds[fx.itemId] then
        errors[#errors + 1] = {
          path = ("itemEffects[%d].itemId"):format(i),
          message = ("references unknown item %s"):format(tostring(fx.itemId))
        }
      end
      if fx.spellId and not spellIds[fx.spellId] then
        errors[#errors + 1] = {
          path = ("itemEffects[%d].spellId"):format(i),
          message = ("references unknown spell %s"):format(tostring(fx.spellId))
        }
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  for i, se in ipairs(doc.spellEffects or { }) do
    local _continue_0 = false
    repeat
      if not (type(se) == "table") then
        _continue_0 = true
        break
      end
      if se.spellId and not spellIds[se.spellId] then
        errors[#errors + 1] = {
          path = ("spellEffects[%d].spellId"):format(i),
          message = ("references unknown spell %s"):format(tostring(se.spellId))
        }
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  local _list_2 = {
    "spellClass",
    "spellLevels",
    "spellReagents",
    "spellPeriodic"
  }
  for _index_0 = 1, #_list_2 do
    local collection = _list_2[_index_0]
    for i, row in ipairs(doc[collection] or { }) do
      local _continue_0 = false
      repeat
        if not (type(row) == "table") then
          _continue_0 = true
          break
        end
        if row.spellId and not spellIds[row.spellId] then
          errors[#errors + 1] = {
            path = ("%s[%d].spellId"):format(collection, i),
            message = ("references unknown spell %s"):format(tostring(row.spellId))
          }
        end
        if row.itemId and not itemIds[row.itemId] then
          errors[#errors + 1] = {
            path = ("%s[%d].itemId"):format(collection, i),
            message = ("references unknown item %s"):format(tostring(row.itemId))
          }
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
  end
  local specIds = { }
  local _list_3 = (doc.specs or { })
  for _index_0 = 1, #_list_3 do
    local row = _list_3[_index_0]
    if type(row) == "table" then
      specIds[row.specId] = true
    end
  end
  local treeIds = { }
  local _list_4 = (doc.talentTrees or { })
  for _index_0 = 1, #_list_4 do
    local row = _list_4[_index_0]
    if type(row) == "table" then
      treeIds[row.treeId] = true
    end
  end
  local nodeIds = { }
  local _list_5 = (doc.talentNodes or { })
  for _index_0 = 1, #_list_5 do
    local row = _list_5[_index_0]
    if type(row) == "table" then
      nodeIds[row.nodeId] = true
    end
  end
  for i, row in ipairs(doc.talentTrees or { }) do
    local _continue_0 = false
    repeat
      if not (type(row) == "table") then
        _continue_0 = true
        break
      end
      if row.specId and not specIds[row.specId] then
        errors[#errors + 1] = {
          path = ("talentTrees[%d].specId"):format(i),
          message = ("references unknown spec %s"):format(tostring(row.specId))
        }
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  for i, row in ipairs(doc.talentNodes or { }) do
    local _continue_0 = false
    repeat
      if not (type(row) == "table") then
        _continue_0 = true
        break
      end
      if row.treeId and not treeIds[row.treeId] then
        errors[#errors + 1] = {
          path = ("talentNodes[%d].treeId"):format(i),
          message = ("references unknown talent tree %s"):format(tostring(row.treeId))
        }
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  for i, row in ipairs(doc.talentEntries or { }) do
    local _continue_0 = false
    repeat
      if not (type(row) == "table") then
        _continue_0 = true
        break
      end
      if row.nodeId and not nodeIds[row.nodeId] then
        errors[#errors + 1] = {
          path = ("talentEntries[%d].nodeId"):format(i),
          message = ("references unknown talent node %s"):format(tostring(row.nodeId))
        }
      end
      if row.spellId and not spellIds[row.spellId] then
        errors[#errors + 1] = {
          path = ("talentEntries[%d].spellId"):format(i),
          message = ("references unknown spell %s"):format(tostring(row.spellId))
        }
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  for i, row in ipairs(doc.spellClass or { }) do
    local _continue_0 = false
    repeat
      if not (type(row) == "table") then
        _continue_0 = true
        break
      end
      if row.specId and next(specIds) and not specIds[row.specId] then
        errors[#errors + 1] = {
          path = ("spellClass[%d].specId"):format(i),
          message = ("references unknown spec %s"):format(tostring(row.specId))
        }
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return #errors == 0, errors
end
M.toJsonSchema = function()
  local props, required = { }, { }
  for name, spec in pairs(schema.document) do
    props[name] = {
      type = spec.kind == "int" and "integer" or spec.kind
    }
    if spec.required then
      required[#required + 1] = name
    end
  end
  for recordName, record in pairs(schema.records) do
    local itemProps, itemRequired = { }, { }
    for fname, fspec in pairs(record.fields) do
      local t = fspec.kind
      itemProps[fname] = {
        type = t == "int" and "integer" or (t == "bool" and "boolean" or t),
        description = fspec.note
      }
      if fspec.required then
        itemRequired[#itemRequired + 1] = fname
      end
    end
    table.sort(itemRequired)
    props[recordName] = {
      type = "array",
      items = {
        type = "object",
        properties = itemProps,
        required = itemRequired
      }
    }
    required[#required + 1] = recordName
  end
  table.sort(required)
  return {
    ["$schema"] = "http://json-schema.org/draft-07/schema#",
    title = "idAutomation item-table normalized model",
    type = "object",
    properties = props,
    required = required
  }
end
return M
