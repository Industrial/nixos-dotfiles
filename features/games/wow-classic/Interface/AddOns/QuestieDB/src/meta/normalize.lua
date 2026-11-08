-- src/meta/normalize.lua
--
-- Nil and empty semantics. The single definition of what a field read must return, shared by
-- Generation, Source mode, Baked mode and the verifier — so "what I see in dev is what ships"
-- follows from shared code rather than from a test.
--
-- Nil, empty, and tuple-shape rules retain Questie's caller-visible semantics. Coordinates
-- are the deliberate exception: the TOC store preserves authored and Derived Pass precision.
-- Literal expectations in tools/validation/storage-cases.lua protect these rules independently
-- of the shared implementation. See docs/storage-format.md, "Nil and empty semantics".
--
--   | Source value      | Read back as                                        |
--   | constant field    | schema placeholder, regardless of source value      |
--   | number nil        | 0      — lossy and deliberate; writers emit `value or 0`
--   | number n          | n
--   | string nil        | nil
--   | string ""         | ""     — distinct from nil, must survive
--   | table nil         | nil
--   | table {}          | nil    — empty tables never come back
--   | pair {0, 0}       | nil    — Questie's documented hack
--   | unknown entity ID | nil
--   | coordinate c      | c      — raw authored or Derived Pass value, ADR 0006
--
-- Verified against Questie/Database/compiler.lua:
--   readers["u12pair"]/["s24pair"]   `if a == 0 and b == 0 then return nil end`
--   readers["u8u24array"] and kin    `if count == 0 then return nil end`
--   writers["u8"] and kin            `stream:WriteByte(value or 0)`
--   readers["faction"]               3 -> nil, 2 -> "AH", 1 -> "H", else "A"
--   writers["faction"]               nil -> 3, "A" -> 0, "H" -> 1, "" -> 3, else -> 2

local _, LibQuestieDB = ...

local normalize = {}

local type, next = type, next

--------------------------------------------------------------------------------------------
-- Coordinate tuple normalization (ADR 0006)
--------------------------------------------------------------------------------------------
--
-- TOC metadata can store Lua numbers directly, so production preserves raw authored and
-- Derived Pass coordinates instead of inheriting the legacy compiler's 12-bit loss. Shape
-- remains canonical for existing callers: explicit instance sentinels have two elements,
-- phase 0 is omitted from spawns, and waypoint rows never carry a third element.
--
-- `{0,0}` and sub-grid coordinates are real values here, not the legacy compiler's
-- zero-pair sentinel. Rows without numeric x and y pass through; validators, not normalization,
-- own malformed-data diagnostics.

---Normalize one coordinate tuple without changing its x/y values.
---@param row any Coordinate tuple or malformed value.
---@param keepPhase boolean Whether a nonzero spawn phase survives.
---@return any normalized Fresh tuple for valid coordinates; malformed values pass through.
local function normalizeCoordinateRow(row, keepPhase)
  if type(row) ~= "table" or type(row[1]) ~= "number" or type(row[2]) ~= "number" then
    return row
  end
  if row[1] == -1 and row[2] == -1 then return { -1, -1 } end
  if keepPhase and (row[3] or 0) ~= 0 then return { row[1], row[2], row[3] } end
  return { row[1], row[2] }
end

---Normalize `spawnlist`: zoneId -> { {x, y, phase?}, ... }.
---@param value any
---@return any normalized
local function normalizeSpawnlist(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for zoneId, rows in pairs(value) do
    if type(rows) == "table" then
      local outRows = {}
      for i, row in pairs(rows) do
        outRows[i] = normalizeCoordinateRow(row, true)
      end
      out[zoneId] = outRows
    else
      out[zoneId] = rows
    end
  end
  return out
end

---Normalize `waypointlist`, whose paths add one nesting level over spawns.
---@param value any
---@return any normalized
local function normalizeWaypointlist(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for zoneId, paths in pairs(value) do
    if type(paths) == "table" then
      local outPaths = {}
      for pathIndex, path in pairs(paths) do
        if type(path) == "table" then
          local outPath = {}
          for i, row in pairs(path) do
            outPath[i] = normalizeCoordinateRow(row, false)
          end
          outPaths[pathIndex] = outPath
        else
          outPaths[pathIndex] = path
        end
      end
      out[zoneId] = outPaths
    else
      out[zoneId] = paths
    end
  end
  return out
end

---Normalize the spawnlist nested in `trigger`: { text, spawnlist }.
---@param value any
---@return any normalized
local function normalizeTrigger(value)
  if type(value) ~= "table" or type(value[2]) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[k] = v end
  out[2] = normalizeSpawnlist(value[2])
  return out
end

---Normalize spawnlists inside `extraobjectives` while preserving every other slot.
---@param value any
---@return any normalized
local function normalizeExtraObjectives(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for i, row in pairs(value) do
    if type(row) == "table" and type(row[1]) == "table" then
      local outRow = {}
      for k, v in pairs(row) do outRow[k] = v end
      outRow[1] = normalizeSpawnlist(row[1])
      out[i] = outRow
    else
      out[i] = row
    end
  end
  return out
end

local normalizeCoordinatesByStructure = {
  spawnlist = normalizeSpawnlist,
  waypointlist = normalizeWaypointlist,
  trigger = normalizeTrigger,
  extraobjectives = normalizeExtraObjectives,
}

--------------------------------------------------------------------------------------------
-- Element-level nil semantics (ADR 0005)
--------------------------------------------------------------------------------------------
--
-- Questie's `nil number -> 0` rule is NOT field-level. Its tuple readers read every slot they
-- wrote, and its writers emit `value or 0`, so an absent numeric slot *inside* a structured
-- value reads back as 0 rather than nil. Verified against Database/compiler.lua:
--
--   writers["objective"]        WriteByte(pair[3] or 0)          -> entry[3] = 0
--   writers["spellobjective"]   WriteInt24(data[3] or 0)         -> entry[3] = 0
--   writers["objectives"]       WriteByte(killobjective[4] or 0) -> killCredit[4] = 0
--   writers["extraobjectives"]  WriteInt24(data[4] or 0)         -> row[4] = 0
--
-- This matters to consumers because 0 is truthy in Lua: `if objective[3] then` is true through
-- the compiler and was false here. String slots are written `value or ""` and read back as nil
-- for "", so they are deliberately NOT padded.

--- Copy a list of tuples, defaulting one numeric slot to 0 where it is absent.
local function padSlot(list, slot)
  if type(list) ~= "table" then return list end
  local out = {}
  for index, entry in pairs(list) do
    if type(entry) == "table" then
      local padded = {}
      for k, v in pairs(entry) do padded[k] = v end
      if padded[slot] == nil then padded[slot] = 0 end
      out[index] = padded
    else
      out[index] = entry
    end
  end
  return out
end

--- `objectives`: { creature, object, item, reputation, killCredits, spell }.
--- Slots 4 (a pair) and any string slot keep their own semantics.
local function padObjectives(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[k] = v end
  out[1] = padSlot(value[1], 3) -- creatureObjective  {id, text, icon}
  out[2] = padSlot(value[2], 3) -- objectObjective
  out[3] = padSlot(value[3], 3) -- itemObjective
  out[5] = padSlot(value[5], 4) -- killCreditObjective {ids, baseId, baseText, icon}
  out[6] = padSlot(value[6], 3) -- spellObjective     {spell, text, item}
  return out
end

--- `extraobjectives`: rows of { spawnlist, icon, text, objectiveIndex, reflist }.
local function padExtraObjectives(value)
  return padSlot(value, 4)
end

local padByStructure = {
  objectives = padObjectives,
  extraobjectives = padExtraObjectives,
}

--- Structures whose compiler reader ALWAYS constructs a table, so the field is never nil for
--- an entity that exists:
---
---   readers["questgivers"]  returns { array, array, array } unconditionally
---   readers["objectives"]   returns { ... } unconditionally
---
-- Both can be empty — a quest with no starters reads `{}`, not nil — which is why
-- `if QueryQuestSingle(id, "startedBy") then` is true upstream. Absence still encodes nil on
-- the wire; the empty table is reconstituted on read, so this costs no stored bytes.
normalize.neverNilStructures = {
  questgivers = true,
  objectives = true,
}

--------------------------------------------------------------------------------------------
-- Named normalizers
--------------------------------------------------------------------------------------------

--- `friendlyToFaction` carries "A", "H", or both. Questie encodes it as one byte and collapses
--- every "both" spelling to "AH"; nil and "" are indistinguishable after the round trip.
function normalize.faction(value)
  if value == nil or value == "" then return nil end
  if value == "A" then return "A" end
  if value == "H" then return "H" end
  return "AH"
end

normalize.byName = {
  faction = normalize.faction,
}

--------------------------------------------------------------------------------------------
-- Field normalization
--------------------------------------------------------------------------------------------

--- Canonical read-back value for one field of one entity.
---
--- This is deliberately total: given the raw source value it returns exactly what every read
--- path must produce, so Generation can decide what to store, Source mode can serve raw
--- tables, and the verifier can compute an expectation without a fourth opinion.
---@param meta table Entity meta from src/meta/<entity>Meta.lua
---@param fieldIndex number
---@param value any Raw source value
---@return any
function normalize.field(meta, fieldIndex, value)
  -- Deprecated constant fields keep their positional interface while dropping obsolete source
  -- data from storage. An explicit nil check distinguishes an absent declaration from any
  -- configured placeholder value.
  local constantValues = meta.constantValues
  if constantValues then
    local constant = constantValues[fieldIndex]
    if constant ~= nil then return constant end
  end

  local storage = meta.types[fieldIndex]

  if storage == "number" then
    -- Numeric getters default to 0, never nil. 0 is truthy in Lua, so consumers already test
    -- `~= 0`; returning nil would change behaviour at every one of those sites.
    if value == nil then return 0 end
    return value
  end

  if storage == "string" then
    local named = meta.normalize[fieldIndex]
    if named then
      local fn = normalize.byName[named]
      if not fn then
        error("normalize: unknown normalizer '" .. tostring(named) .. "'", 0)
      end
      return fn(value)
    end
    -- nil stays nil; "" stays "" and is distinct from nil.
    return value
  end

  if storage == "table" then
    local structure = meta.structures and meta.structures[fieldIndex]
    local neverNil = structure ~= nil and normalize.neverNilStructures[structure] == true

    if value == nil then
      -- A fresh table per call, never a shared constant: every table a read hands out is the
      -- caller's to mutate (ADR 0003 D10).
      if neverNil then return {} end
      return nil
    end
    if type(value) ~= "table" then return value end
    -- Empty tables never come back — except where the compiler's reader builds one anyway.
    if next(value) == nil then
      if neverNil then return {} end
      return nil
    end
    if meta.zeroPairIsNil[fieldIndex] and (value[1] or 0) == 0 and (value[2] or 0) == 0 then
      return nil
    end
    local coordinateNormalizer = structure and normalizeCoordinatesByStructure[structure]
    if coordinateNormalizer then value = coordinateNormalizer(value) end
    local padder = structure and padByStructure[structure]
    if padder then value = padder(value) end
    return value
  end

  error("normalize: field " .. tostring(fieldIndex) .. " of " .. tostring(meta.entity) ..
        " has unknown storage type " .. tostring(storage), 0)
end

---Default value for a field that has no stored metadata.
---@param meta table Entity meta from src/meta/<entity>Meta.lua
---@param fieldIndex number
---@return any
function normalize.default(meta, fieldIndex)
  local constantValues = meta.constantValues
  if constantValues then
    local constant = constantValues[fieldIndex]
    if constant ~= nil then return constant end
  end

  if meta.types[fieldIndex] == "number" then return 0 end
  local structure = meta.structures and meta.structures[fieldIndex]
  if structure and normalize.neverNilStructures[structure] then return {} end
  return nil
end

if LibQuestieDB then
  LibQuestieDB.Meta = LibQuestieDB.Meta or {}
  LibQuestieDB.Meta.normalize = normalize
end

return normalize
