-- src/read/shared.lua
--
-- Everything the two read modes have in common: named getters, the generic getter, the
-- Decoded field cache, Correction Overlay lookup, field defaults, the fresh-per-read
-- value contract, and the Name index.
--
-- The seam between Source mode and Baked mode is `readField` and `getAllIds`. Baked mode
-- also provides `scalarRow` and `tableProducer`: one native decode fills every stored scalar
-- slot, while a table Producer retains CBOR bytes and returns a fresh value per call. Source
-- mode and Generation apply Static Corrections through the same path, so "what I see in dev
-- is what ships" follows from shared code rather than from a test.
--
-- ## Value ownership (ADR 0003 Decision 10, revised)
--
-- Table reads return a **fresh, mutable, deeply independent copy on every read** — the
-- caller owns it outright, exactly as Questie's compiler semantics always promised. The
-- mechanism is a cached Producer: a Baked Producer decodes retained CBOR bytes, while Source
-- and Correction Overlay Producers deep-copy retained values. Every read executes the cached
-- Producer. Scalars are immutable. In Baked mode, the first field read installs the entity's
-- decoded Scalar row as its cache row.

local _, LibQuestieDB = ...

local shared = {}

local type, rawget, setmetatable, ipairs = type, rawget, setmetatable, ipairs

--------------------------------------------------------------------------------------------
-- Freezing
--------------------------------------------------------------------------------------------
--
-- `table.freeze` is a VM-level flag, not a metatable proxy: reads are completely unaffected,
-- `rawset` is blocked, and `getmetatable` still returns nil. It does not exist in standard
-- Lua 5.1, which is what the generator, verify.lua and the offline harness run on, so
-- capability detection is mandatory and the harness installs a pure-Lua substitute.
--
-- Since ADR 0003 Decision 10 was revised, freezing guards **QuestieDB-internal shared
-- structures only** — Source mode's base entity tables, which a Correction or consumer must
-- not corrupt. Values returned from reads are never frozen: they are fresh copies the caller
-- owns. The taint-ownership findings that motivated the revision (loadstring chunks are
-- owned by `*** ForceTaint_Strong ***`, so addon code can never freeze what the decoder
-- builds) are recorded in docs/client-metadata-probes.md.
--
-- Freezing still degrades rather than fails: if the VM refuses, the structure stays
-- unfrozen and the refusal is counted, because a load failing over an optional guard is
-- strictly worse than the guard being absent.

local luaTable = rawget(_G, "table")
local freeze = luaTable and rawget(luaTable, "freeze")
local isFrozen = luaTable and rawget(luaTable, "isfrozen")

shared.canFreeze = freeze ~= nil

--- How many times the VM refused to freeze a value, and the last reason. Diagnostic only —
--- consumers never see the failure, so this is the only way to know the guard is not holding.
shared.freezeRefused = 0
shared.lastFreezeError = nil

local function freezeDeep(value)
  if isFrozen and isFrozen(value) then return value end
  for _, inner in pairs(value) do
    if type(inner) == "table" then freezeDeep(inner) end
  end
  return freeze(value)
end

--- Deep-freeze a value the database owns. Measured on Classic Era 1.15.9 at 0 KiB allocated
--- against CopyTable's ~357 KiB, and 8-20% faster — see docs/table.freeze.md.
---
--- Re-freezing must be harmless: a table field is frozen when the base data loads and again
--- when a read caches it, and the Correction Overlay produces fresh objects on every
--- recomposition.
---
--- Always returns `value`, frozen if the VM allowed it and untouched if it did not.
function shared.Freeze(value)
  if not freeze or type(value) ~= "table" then return value end
  -- One pcall around the whole recursion rather than one per nested table: partial freezing
  -- is a fine outcome, and the inner loop stays free of error handling.
  local ok, err = pcall(freezeDeep, value)
  if not ok then
    shared.freezeRefused = shared.freezeRefused + 1
    shared.lastFreezeError = err
  end
  return value
end

--- Install a freeze implementation. Used by the offline harness's focused freeze tests and
--- `equivalence.lua --freeze` — see emulator/freeze.lua.
function shared.SetFreezeImplementation(implementation)
  freeze = implementation
  shared.canFreeze = implementation ~= nil
end

function shared.SetIsFrozenImplementation(implementation)
  isFrozen = implementation
end

function shared.IsFrozen(value)
  if not isFrozen then return false end
  return isFrozen(value) == true
end

--------------------------------------------------------------------------------------------
-- Entity access
--------------------------------------------------------------------------------------------

local NIL = setmetatable({}, { __tostring = function() return "<nil>" end })

--- Build one Entity global over a backend.
---
---@param meta table Entity meta from src/meta/<entity>Meta.lua
---@param backend table { readField(id, fieldIndex) -> value|nil, getAllIds() -> list, map }
---@return table entity
function shared.CreateEntity(meta, backend)
  local normalize = LibQuestieDB.Meta.normalize
  local types = meta.types
  local keys = meta.keys
  local fieldCount = meta.fieldCount

  -- What a field with no stored value reads as, resolved once per entity type from the single
  -- definition in normalize.lua rather than restated here: numerics default to 0, the
  -- never-nil structures default to `{}`, everything else stays nil (ADR 0003 D6, ADR 0005).
  --
  -- Stored in the cache's own convention -- a plain value for scalars, a producer for tables --
  -- so a default can be cached exactly like a decoded one and a table default still hands out
  -- a fresh copy per read. `nil` here means "this field really does read nil".
  local defaults = {}
  for fieldIndex = 1, fieldCount do
    local default = normalize.default(meta, fieldIndex)
    if type(default) == "table" then
      defaults[fieldIndex] = function() return normalize.default(meta, fieldIndex) end
    elseif default ~= nil then
      defaults[fieldIndex] = default
    end
  end

  local entity = {
    meta = meta,
    backend = backend,
  }

  -- Decoded field cache. Source mode creates an empty row and fills fields on demand. Baked
  -- mode adopts the decoded scalar row itself, avoiding a copy and a second table per entity.
  -- Its `p` presence mask stays under a string key and cannot collide with field indices.
  -- Before installing that row, the cache applies scalar Corrections and active translations
  -- once. Stored scalars are then ordinary cache hits; omitted defaults settle only when read
  -- instead of pre-filling every missing slot. Table fields cache Producer functions so every
  -- hit returns a fresh mutable copy.
  local cache = {}

  local function cacheField(byId, fieldIndex, value)
    byId[fieldIndex] = value
  end

  local function missingScalar(byId, fieldIndex)
    local default = defaults[fieldIndex]
    if default ~= nil then
      byId[fieldIndex] = default
      return default
    end
    byId[fieldIndex] = NIL
    return nil
  end

  -- Correction Overlay: the composed query-time layer of Dynamic Corrections. Reads resolve
  -- through it first and fall back to base data. Recomposed on apply rather than resolved at
  -- read time, so this stays a single lookup. Populated by src/corrections/registry.lua.
  local overlay = {}
  entity.overlay = overlay

  -- Composed ids: the union of backend ids and overlay-added ids (ADR 0003 D7). An entity a
  -- Dynamic Correction adds is readable, enumerable, and exists — all three or none. Built
  -- lazily, dropped whenever the overlay is replaced.
  local unionList, unionMap, baseIdMap

  local function buildUnion()
    local list, map = backend.getAllIds()
    baseIdMap = map
    local extra = false
    for id in pairs(overlay) do
      if map[id] ~= true then extra = true break end
    end
    if not extra then
      unionList, unionMap = list, map
      return
    end
    unionMap = {}
    for id in pairs(map) do unionMap[id] = true end
    unionList = {}
    for i = 1, #list do unionList[i] = list[i] end
    for id in pairs(overlay) do
      if unionMap[id] ~= true then
        unionMap[id] = true
        unionList[#unionList + 1] = id
      end
    end
    table.sort(unionList)
  end

  --- Deep copy of a plain normalized value tree. Correction and Source values carry no
  --- metatables and no cycles — normalization and the registry guarantee plain data.
  local function deepCopy(value)
    local out = {}
    for k, v in pairs(value) do
      if type(v) == "table" then out[k] = deepCopy(v) else out[k] = v end
    end
    return out
  end

  --- A producer over a value the database retains: each call returns a fresh copy, so the
  --- retained original can never be reached — or corrupted — through a read.
  local function copyProducer(value)
    return function() return deepCopy(value) end
  end

  -- The l10n overlay is attached after the Entity globals exist. A nil provider means this
  -- entity type has no localization data and avoids all per-read localization probes.
  local l10nProvider
  local l10nScalarFields
  local l10nIsActive

  ---Attach the localization provider and the scalar fields to resolve when a row is installed.
  ---@param provider function?
  ---@param scalarFields table<number, boolean>?
  ---@param isActive function?
  function entity.SetL10nProvider(provider, scalarFields, isActive)
    l10nProvider = provider
    l10nScalarFields = scalarFields
    l10nIsActive = isActive
    entity.InvalidateCache(nil)
  end

  function entity.HasL10nProvider()
    return l10nProvider ~= nil
  end

  ---Compose every scalar Correction and active translation before the row becomes authoritative.
  ---Later scalar reads skip both layers and must see the values installed here.
  ---@param id number Entity ID.
  ---@param row table Decoded Scalar row owned by the cache.
  local function resolveScalarRow(id, row)
    local layer = overlay[id]
    if layer then
      for scalarIndex, overlayValue in pairs(layer) do
        if type(scalarIndex) == "number" and types[scalarIndex] ~= "table" then
          if overlayValue == LibQuestieDB.Corrections.NIL then
            row[scalarIndex] = defaults[scalarIndex] or NIL
          else
            row[scalarIndex] = overlayValue
          end
        end
      end
    end

    if l10nProvider and l10nScalarFields and l10nIsActive and l10nIsActive() then
      for scalarIndex in pairs(l10nScalarFields) do
        local translated = l10nProvider(id, scalarIndex)
        if translated ~= nil then
          row[scalarIndex] = translated
        elseif row[scalarIndex] == nil then
          missingScalar(row, scalarIndex)
        end
      end
    end
  end

  local function get(id, fieldIndex)
    if type(id) ~= "number" then return nil end
    local byId = cache[id]
    if byId then
      local cached = byId[fieldIndex]
      if cached ~= nil then
        if cached == NIL then return nil end
        if types[fieldIndex] ~= "table" then return cached end
        -- A cached producer: execute it for a fresh mutable copy the caller owns.
        return cached()
      elseif backend.hasScalarRows and types[fieldIndex] ~= "table" then
        -- resolveScalarRow already applied every layer that can change a scalar. A missing
        -- slot can settle its default without repeating the overlay and l10n probes.
        return missingScalar(byId, fieldIndex)
      end
    elseif backend.hasScalarRows then
      byId = backend.scalarRow(id)
      if not byId then
        -- A valid entity can have no stored values at all. Build the composed id map before
        -- deciding whether to cache its empty row; truly unknown ids leave no cache entry.
        if not unionMap then buildUnion() end
        if unionMap[id] ~= true then return nil end
        byId = {}
      end
      resolveScalarRow(id, byId)
      cache[id] = byId
      if types[fieldIndex] ~= "table" then
        local cached = byId[fieldIndex]
        if cached ~= nil then
          if cached == NIL then return nil end
          return cached
        end
        return missingScalar(byId, fieldIndex)
      end
    else
      byId = {}
      cache[id] = byId
    end

    -- Entity Corrections supply the English fallback. Active translations are authoritative
    -- for translatable fields; a missing translation must still preserve an explicit delete.
    local value, corrected
    local layer = overlay[id]
    if layer ~= nil then
      local overlayValue = layer[fieldIndex]
      if overlayValue ~= nil then
        corrected = true
        -- The registry's sentinel for "this Correction sets the field to nil", which a plain
        -- nil in the overlay table cannot express.
        if overlayValue ~= LibQuestieDB.Corrections.NIL then value = overlayValue end
      end
    end

    local translated
    if l10nProvider and (not l10nIsActive or l10nIsActive()) then
      translated = l10nProvider(id, fieldIndex)
    end
    if translated ~= nil then
      value = translated
    elseif not corrected then
      if value == nil then
        if types[fieldIndex] == "table" and backend.tableProducer then
          -- The Producer closes over CBOR bytes. Its Presence-mask check uses the Scalar row
          -- already in hand, so an absent table needs no metadata call.
          local producer = backend.tableProducer(id, fieldIndex, byId)
          if producer then
            cacheField(byId, fieldIndex, producer)
            return producer()
          end
        elseif backend.hasScalarRows then
          -- The scalar row was decoded on this entity's first cache miss. Read the base value
          -- directly, then let defaults and the layers above settle the cached result.
          value = byId[fieldIndex]
        else
          value = backend.readField(id, fieldIndex)
        end
      end
    end

    if value == nil then
      -- Defaults apply only to an entity that exists in the composed view. An unknown id reads
      -- nil for every field, so a missing entity can never masquerade as a valid all-zero row
      -- or as a quest that simply has no questgivers (ADR 0003 D6).
      local default = defaults[fieldIndex]
      if default ~= nil then
        if not unionMap then buildUnion() end
        if unionMap[id] == true then
          cacheField(byId, fieldIndex, default)
          if type(default) == "function" then return default() end
          return default
        end
      end
      cacheField(byId, fieldIndex, NIL)
      return nil
    end

    if type(value) == "table" then
      -- Overlay, translated, and Source-backend tables reach here: cache a producer closing
      -- over the retained value. Only copies ever escape, so the original — which may be the
      -- overlay's composed row or Source mode's frozen base — stays unreachable.
      local producer = copyProducer(value)
      cacheField(byId, fieldIndex, producer)
      return producer()
    end
    cacheField(byId, fieldIndex, value)
    return value
  end

  --- Positional access without the name mapping. Validates the index like `Get` does, so an
  --- out-of-range or non-numeric index returns nil identically in both modes rather than
  --- reaching the Source normalizer and raising (ADR 0003 parity).
  function entity.GetByIndex(id, fieldIndex)
    if type(fieldIndex) ~= "number" or fieldIndex < 1 or fieldIndex > fieldCount then return nil end
    return get(id, fieldIndex)
  end

  --- Field access by canonical name or positional index.
  function entity.Get(id, key)
    local fieldIndex = keys[key] or (type(key) == "number" and key or nil)
    if not fieldIndex or fieldIndex < 1 or fieldIndex > fieldCount then return nil end
    return get(id, fieldIndex)
  end

  --- Bulk field access. Returns a **packed** table — values in requested order plus `n`,
  --- because nullable fields leave holes that make `#` and a bare `unpack` undefined.
  --- Consume with `unpack(values, 1, values.n)`. An unknown entity returns nil (ADR D6/D11).
  function entity.GetAll(id, requestedKeys)
    if not entity.Exists(id) then return nil end
    local n = #requestedKeys
    local values = { n = n }
    for i = 1, n do
      local key = requestedKeys[i]
      local fieldIndex = keys[key] or (type(key) == "number" and key or nil)
      if fieldIndex and fieldIndex >= 1 and fieldIndex <= fieldCount then
        values[i] = get(id, fieldIndex)
      end
    end
    return values
  end

  --- Base data only, bypassing the Correction Overlay and localization. For tooling and
  --- debugging. Table values are fresh copies here too, and an out-of-range or unknown key
  --- returns nil identically in both modes (ADR 0003).
  function entity.GetRaw(id, key)
    if type(id) ~= "number" then return nil end
    local fieldIndex = keys[key] or (type(key) == "number" and key or nil)
    if not fieldIndex or fieldIndex < 1 or fieldIndex > fieldCount then return nil end
    local value = backend.readField(id, fieldIndex)
    if value == nil then
      -- Same defaults, but GetRaw's existence gate is the backend alone: it bypasses the
      -- overlay, so an overlay-added entity legitimately has no raw row.
      local default = defaults[fieldIndex]
      if default ~= nil then
        local _, map = backend.getAllIds()
        if map[id] == true then
          if type(default) == "function" then return default() end
          return default
        end
      end
      return nil
    end
    if type(value) == "table" then return deepCopy(value) end
    return value
  end

  --- Every id in the composed view: backend ids plus overlay-added ids (ADR D7). The list is
  --- ascending; the hashmap form is a drop-in for Questie's `*Pointers[id]` checks. Callers
  --- must treat both as read-only — they are shared, not copies.
  function entity.GetAllIds(hashmap)
    if not unionList then buildUnion() end
    if hashmap == true then return unionMap end
    return unionList
  end

  function entity.Exists(id)
    if not unionMap then buildUnion() end
    return unionMap[id] == true
  end

  ------------------------------------------------------------------------------------------
  -- Name index (ADR 0008)
  ------------------------------------------------------------------------------------------
  --
  -- The reverse of the `name` getter: current composed name -> ascending ids. Built from the
  -- same `get` every read goes through, so it answers exactly what `Entity.name(id)` would —
  -- the active locale, the English fallback, and any overlay-added entity.
  --
  -- Built lazily on the first lookup, or explicitly through `BuildNameIndex` or
  -- `BuildNameIndexAsync` so a consumer chooses when to pay for the full pass. Never patched:
  -- name or membership changes drop it, while unrelated Correction fields leave it intact.
  -- Locale changes and explicit invalidation still force a rebuild. Only a type with a `name`
  -- field carries one, which today includes all four.

  local nameFieldIndex = keys.name
  local nameIndex
  local nameIndexRevision = 0

  if nameFieldIndex then
    ---Keep unfinished buckets private; invalidation during a yield restarts the full pass.
    ---@param iterationsPerCycle integer? IDs between coroutine yields; nil stays synchronous.
    ---@return nil
    local function buildNameIndex(iterationsPerCycle)
      while not nameIndex do
        local revision = nameIndexRevision
        local index = {}
        local ids = entity.GetAllIds()
        for i = 1, #ids do
          local id = ids[i]
          local name = get(id, nameFieldIndex)
          if type(name) == "string" then
            local bucket = index[name]
            if bucket then
              bucket[#bucket + 1] = id
            else
              index[name] = { id }
            end
          end
          if iterationsPerCycle and i % iterationsPerCycle == 0 and i < #ids then
            coroutine.yield()
            -- A lookup or another builder may have completed the current index while suspended.
            if nameIndex then return end
            if revision ~= nameIndexRevision then break end
          end
        end
        if revision == nameIndexRevision then nameIndex = index end
      end
    end

    ---Build synchronously, or do nothing if the index already exists. Warms every name read.
    ---Use BuildNameIndexAsync in a coroutine to split the full pass across frames.
    ---@return nil
    function entity.BuildNameIndex()
      buildNameIndex(nil)
    end

    ---Yield between batches, returning only when the complete index is ready.
    ---Must run inside a caller-owned coroutine; creates no timers or background work.
    ---@async
    ---@param iterationsPerCycle integer? Positive IDs per batch; defaults to 250.
    ---@return nil
    function entity.BuildNameIndexAsync(iterationsPerCycle)
      if iterationsPerCycle == nil then iterationsPerCycle = 250 end
      if type(iterationsPerCycle) ~= "number" or iterationsPerCycle < 1 or
          iterationsPerCycle == math.huge or iterationsPerCycle % 1 ~= 0 then
        error("BuildNameIndexAsync: iterationsPerCycle must be a positive integer", 2)
      end
      buildNameIndex(iterationsPerCycle)
    end

    --- Every composed id whose current name equals `name` exactly, ascending, or nil when
    --- none does — an unknown name reads nil like an unknown id, never an empty list, and a
    --- non-string never raises. The list is shared and read-only, like `GetAllIds`.
    function entity.IdsByName(name)
      if type(name) ~= "string" then return nil end
      if not nameIndex then entity.BuildNameIndex() end
      return nameIndex[name]
    end
  end

  ---Compare only Correction rows, without reading or decoding every base entity name.
  ---Before the first enumeration, conservatively treat added/removed rows as membership changes
  ---instead of materializing Source data just to check whether those IDs exist in the backend.
  ---@param composed table Replacement Correction Overlay.
  ---@return boolean changed Whether names or composed membership may have changed.
  local function overlayChangesNames(composed)
    if not nameFieldIndex then return false end
    for id, previous in pairs(overlay) do
      local replacement = composed[id]
      if previous[nameFieldIndex] ~= (replacement and replacement[nameFieldIndex]) then return true end
      if not replacement and (not baseIdMap or baseIdMap[id] ~= true) then return true end
    end
    for id, replacement in pairs(composed) do
      if not overlay[id] and (replacement[nameFieldIndex] ~= nil or not baseIdMap or baseIdMap[id] ~= true) then
        return true
      end
    end
    return false
  end

  ---Clear decoded fields independently of the Name index; `get` retains this cache table.
  ---@param id number? Nil clears every entity's fields.
  ---@return nil
  local function clearFieldCache(id)
    if id == nil then
      for key in pairs(cache) do cache[key] = nil end
    else
      cache[id] = nil
    end
  end

  ---Drop complete and suspended Name indexes so the next build uses the current name view.
  ---@return nil
  local function invalidateNameIndex()
    nameIndexRevision = nameIndexRevision + 1
    nameIndex = nil
  end

  ---Replace Correction fields and enumeration; retain the Name index for unrelated field changes.
  ---An unchanged name view also lets a suspended async pass continue without restarting.
  ---@param composed table? Replacement Correction Overlay; nil withdraws it.
  ---@return nil
  function entity.SetOverlay(composed)
    composed = composed or {}
    if overlayChangesNames(composed) then invalidateNameIndex() end
    overlay = composed
    entity.overlay = overlay
    unionList, unionMap = nil, nil
    clearFieldCache(nil)
  end

  ---Force cached fields and the Name index to rebuild, even for a single entity.
  ---Locale/provider changes and explicit invalidation cannot guarantee an unchanged name view.
  ---@param id number? Nil clears every entity's fields.
  ---@return nil
  function entity.InvalidateCache(id)
    invalidateNameIndex()
    clearFieldCache(id)
  end

  -- Named getters, generated from the schema. `QuestDB.name(2)` reads field 1 of quest 2.
  for fieldIndex = 1, fieldCount do
    local name = meta.names[fieldIndex]
    if name then
      entity[name] = function(id) return get(id, fieldIndex) end
    end
  end

  return entity
end

if LibQuestieDB then
  LibQuestieDB.shared = shared
end

return shared
