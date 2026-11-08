-- Table Correction operations. Schema shapes determine the unit of equality and mutation;
-- nested tuples are complete values, not instructions to merge arbitrary Lua tables.
local _, LibQuestieDB = ...
local patch = {}
local OFFSET = 1000

local function copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, child in pairs(value) do out[key] = copy(child) end
  return out
end

local function equal(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for key, value in pairs(a) do if not equal(value, b[key]) then return false end end
  for key in pairs(b) do if a[key] == nil then return false end end
  return true
end

local function contains(list, value)
  for _, existing in ipairs(list or {}) do if equal(existing, value) then return true end end
  return false
end

local function integer(value)
  return type(value) == "number" and value > -math.huge and value < math.huge and value % 1 == 0
end

-- Lists are dense; fixed tuples may have optional holes, but never unknown slots.
local validate
local function tuple(value, slots)
  if type(value) ~= "table" then return false end
  for key, child in pairs(value) do
    if not integer(key) or not slots[key] or not validate(slots[key], child) then return false end
  end
  return true
end

local function list(value, shape)
  if type(value) ~= "table" then return false end
  local count = 0
  for key, child in pairs(value) do
    if not integer(key) or key < 1 or not validate(shape, child) then return false end
    count = count + 1
  end
  for index = 1, count do if value[index] == nil then return false end end
  return true
end

local objectiveGroups = { "objectiveList", "objectiveList", "objectiveList", "pair", "killList", "objectiveList" }
local grouped = { questgivers = true, objectives = true, spawnlist = true, waypointlist = true }
local atomic = { pair = true, trigger = true }

validate = function(shape, value)
  if shape == "integer" then return integer(value) end
  if shape == "number" then return type(value) == "number" and value > -math.huge and value < math.huge end
  if shape == "string" then return type(value) == "string" end
  if shape == "referenceKind" then return value == "monster" or value == "object" or value == "item" end
  if shape == "pair" then return tuple(value, { "integer", "integer" }) end
  if shape == "reputationpair" then
    return tuple(value, { "integer", "number" }) and value[1] ~= nil and value[2] ~= nil
  end
  if shape == "coordinate" then
    return tuple(value, { "number", "number", "integer" }) and value[1] ~= nil and value[2] ~= nil
  end
  if shape == "objective" then return tuple(value, { "integer", "string", "integer" }) end
  if shape == "kill" then return tuple(value, { "idarray", "integer", "string", "integer" }) end
  if shape == "reference" then return tuple(value, { "referenceKind", "integer" }) end
  if shape == "extra" then return tuple(value, { "spawnlist", "integer", "string", "integer", "references" }) end
  if shape == "trigger" then return tuple(value, { "string", "spawnlist" }) end
  if shape == "questgivers" then return tuple(value, { "idarray", "idarray", "idarray" }) end
  if shape == "objectives" then return tuple(value, objectiveGroups) end
  if shape == "spawnlist" or shape == "waypointlist" then
    if type(value) ~= "table" then return false end
    for zone, rows in pairs(value) do
      if not integer(zone) or not list(rows, shape == "spawnlist" and "coordinate" or "path") then return false end
    end
    return true
  end
  local elements = {
    idarray = "integer", stringarray = "string", pairs = "pair", reputationpairs = "reputationpair", extraobjectives = "extra",
    objectiveList = "objective", killList = "kill", references = "reference", path = "coordinate",
  }
  return elements[shape] ~= nil and list(value, elements[shape])
end

local function fail(meta, context, id, field, operation, reason)
  error(("Correction %s/%s %s %s field %s %s: %s"):format(
    tostring(context and context.owner or "?"), tostring(context and context.name or "?"),
    tostring(meta and meta.entity or context and context.datatype or "?"), tostring(id),
    tostring(meta and meta.names[field] or field), operation, reason), 0)
end

---Resolve operation keys before either Static storage or Dynamic composition sees a row.
---Replacement-only rows return unchanged; operands are validated before normalization.
function patch.Resolve(fields, meta, context, id, base, fallback, noOverwrites, nilSentinel)
  local operations
  for key, operand in pairs(fields) do
    if type(key) == "number" and (key <= 0 or key >= OFFSET) then
      local operation = key >= OFFSET and "add" or "remove"
      local field = key >= OFFSET and key - OFFSET or key + OFFSET
      if not integer(key) or not meta or not meta.names[field] then
        fail(meta, context, id, field, operation, "unknown operation key " .. tostring(key))
      end
      if meta.types[field] ~= "table" then fail(meta, context, id, field, operation, "target is not table-valued") end
      if not validate(meta.structures[field], operand) then
        fail(meta, context, id, field, operation, "malformed " .. tostring(meta.structures[field]) .. " operand (expected table)")
      end
      if fields[field] ~= nil then fail(meta, context, id, field, operation, "replacement and operation share a field") end
      operations = operations or {}
      operations[field] = operations[field] or {}
      operations[field][operation] = operand
    elseif type(key) == "number" and (key % 1 ~= 0 or (meta and key > meta.fieldCount)) then
      fail(meta, context, id, key, "replace", "unknown field key")
    end
  end
  if not operations then return fields end

  local out = {}
  for key, value in pairs(fields) do
    if type(key) ~= "number" or (key > 0 and key < OFFSET) then out[key] = value end
  end
  for field, operands in pairs(operations) do
    local shape = meta.structures[field]
    local operation = operands.add and (operands.remove and "add/remove" or "add") or "remove"
    local normalize = LibQuestieDB.Meta.normalize.field
    local added = operands.add and normalize(meta, field, operands.add) or {}
    local removed = operands.remove and normalize(meta, field, operands.remove) or {}
    added, removed = added or {}, removed or {}

    -- Conflicts are checked independently of the current base and of pairs() iteration order.
    if atomic[shape] and next(added) and next(removed) then
      fail(meta, context, id, field, operation, "atomic records cannot add and remove in one row; use replacement")
    end
    local groups = grouped[shape] and added or { added }
    local removals = grouped[shape] and removed or { removed }
    for group, values in pairs(groups) do
      local other = removals[group]
      if other then
        if atomic[shape] or (shape == "objectives" and group == 4) then
          if next(values) and equal(values, other) then
            fail(meta, context, id, field, operation, "same value requested for add and remove")
          end
        else
          for _, value in ipairs(values) do
            if contains(other, value) then fail(meta, context, id, field, operation, "same value requested for add and remove") end
          end
        end
      end
    end

    -- Empty operands do not acquire ownership, create an entity, or resurrect a deletion.
    if next(added) or next(removed) then
      local existing = base and base[field]
      if existing == nil and fallback then existing = fallback(id, field) end
      if existing == nilSentinel then existing = nil end
      if existing ~= nil and not validate(shape, existing) then
        fail(meta, context, id, field, operation, "malformed existing " .. shape .. " value (expected table)")
      end
      existing = existing and normalize(meta, field, existing) or nil
      if not noOverwrites or not (base and base[field] ~= nil) then
        local result = copy(existing or {})
        local targets = grouped[shape] and result or { result }
        local adds = grouped[shape] and added or { added }
        local removes = grouped[shape] and removed or { removed }
        local touched = {}
        for group in pairs(adds) do touched[group] = true end
        for group in pairs(removes) do touched[group] = true end
        for group in pairs(touched) do
          local current, add, remove = targets[group] or {}, adds[group] or {}, removes[group] or {}
          if atomic[shape] or (shape == "objectives" and group == 4) then
            if next(remove) and equal(current, remove) then current = {} end
            if next(add) then
              if next(current) and not equal(current, add) then
                fail(meta, context, id, field, operation, "different atomic value already exists; use replacement")
              end
              current = copy(add)
            end
          else
            local kept = {}
            for _, value in ipairs(current) do if not contains(remove, value) then kept[#kept + 1] = value end end
            for _, value in ipairs(add) do if not contains(kept, value) then kept[#kept + 1] = copy(value) end end
            current = kept
          end
          targets[group] = next(current) and current or nil
        end
        out[field] = grouped[shape] and targets or targets[1] or {}
      end
    end
  end
  return out
end

if LibQuestieDB then LibQuestieDB.TablePatch = patch end
return patch
