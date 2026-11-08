-- src/corrections/registry.lua
--
-- Registration, application and recomposition of Corrections.
--
-- Two categories, declared by the author. There is no automatic promotion, and therefore
-- nothing that can misfire:
--
--   Static Correction   folded in during Generation. Never shipped to end users. In Source
--                       mode it is applied to base data through the same path the generator
--                       uses, which is what makes *deleting* one observable — something an
--                       overlay-based dev addon could never manage.
--   Dynamic Correction  conditional, or otherwise not knowable before Generation. Applied at
--                       query time through the Correction Overlay.
--
-- Ported from Getters/GetterDB/Corrections/Corrections.lua, which already solved load-order
-- namespacing, collision reporting, and holding corrections behind functions so the data
-- materialises only on apply. Three things changed:
--
--   * Registration is owner-scoped. Third-party addons declare `## Dependencies: Questie` and
--     therefore register *after* Questie has already applied, so applying has to be
--     addressable per owner.
--   * A load-order collision no longer displaces the sitting entry by probing upward. That
--     cascaded: the displaced entry could take the slot the next registrant wanted, silently
--     reordering things. Entries are kept in a list and sorted by (loadOrder, registration
--     sequence), so a collision is reported and resolved without moving anyone.
--   * Consumers get a data-shaped write-through form, `Set(owner, datatype, name, rows)`: no
--     provider function, no explicit apply, no loadOrder. Function entries memoize their
--     successful materialization (refreshed on their own owner's apply), and recomposition is scoped
--     to the written datatype — which is what makes write-through affordable (ADR 0009).

local _, LibQuestieDB = ...

local registry = {}

local type, pairs, ipairs, next = type, pairs, ipairs, next
local sort = table.sort
local format = string.format

--------------------------------------------------------------------------------------------
-- Load-order namespaces
--------------------------------------------------------------------------------------------
--
-- Each expansion or seasonal variant gets a 100-wide window. Variant windows follow their
-- base database; auto-generated sets sit below hand-maintained ones so hand corrections win.
--
-- `loadOrder` means "sequence within an owner", not a global sequence. Precedence is
-- two-level — outer by the order owners FIRST applied, inner by loadOrder — and within a
-- field the later-ranked owner wins. An owner's rank is fixed at first apply; re-applying
-- refreshes that owner's layer in place. That follows load order naturally:
-- QuestieDB < Questie < third-party.

registry.loadOrder = {
  EraStatic = 0,      EraDynamic = 100,
  SoDStatic = 200,    SoDDynamic = 300,
  TbcStatic = 400,    TbcDynamic = 500,
  WotlkStatic = 600,  WotlkDynamic = 700,
  TitanStatic = 800,  TitanDynamic = 900,
  CataStatic = 1000,  CataDynamic = 1100,
  MoPStatic = 1200,   MoPDynamic = 1300,
  -- Forever-only Static window: after inherited Era sets, before authored Forever fixes.
  -- MoP Dynamic shares this number but never registers for the owned Forever flavor.
  ForeverDeltaBaseStatic = 1300,
  ForeverStatic = 1400, ForeverDynamic = 1500,
}

registry.OWNER = "QuestieDB"

--------------------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------------------

--- owner -> { name, sequence, entries = { <entry>, ... } }
registry.owners = {}
--- Owners in the order they were first seen, which is load order.
registry.ownerOrder = {}
--- Owners in the order `ApplyRegisteredCorrections` last ran for them. Outer precedence.
registry.appliedOrder = {}

--- datatype -> id -> fieldIndex -> value. The composed Correction Overlay.
registry.composed = {}
--- datatype -> id -> fieldIndex -> owner. Which owner supplied the winning value.
registry.provenance = {}

--- Set true to log when one owner overrides another on the same field.
registry.debug = false

--- datatype -> true while a Dynamic Correction change awaits recomposition. An owner's apply,
--- a withdrawal, and `Set` mark it; the next flush consumes it — so only the touched datatypes
--- rebuild and drop their read caches. Their Name indexes survive unrelated field changes.
--- Registration alone marks nothing: an unapplied entry must not republish its datatype.
registry.dirty = {}

local registrationSequence = 0

local VALID_DATATYPES = { Quest = true, Npc = true, Item = true, Object = true }

--- Accept `"quest"` as well as `"Quest"`: the prototype and Questie's own correction files use
--- lowercase, and refusing it would make porting them a rename exercise for no gain.
local function canonicalDatatype(datatype)
  if type(datatype) ~= "string" then return nil end
  local canonical = datatype:sub(1, 1):upper() .. datatype:sub(2):lower()
  if VALID_DATATYPES[canonical] then return canonical end
  return nil
end

registry.CanonicalDatatype = canonicalDatatype

local function ownerRecord(owner)
  local record = registry.owners[owner]
  if not record then
    record = { name = owner, entries = {}, pending = true }
    registry.owners[owner] = record
    registry.ownerOrder[#registry.ownerOrder + 1] = owner
  end
  return record
end

local function warn(message)
  if type(rawget(_G, "print")) == "function" then
    print("|cFFFFD100QuestieDB:|r " .. message)
  end
end

--------------------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------------------

local function register(owner, datatype, name, func, loadOrder, dynamic)
  if type(owner) ~= "string" or owner == "" then
    error("RegisterCorrection: owner must be a non-empty string", 2)
  end
  local canonical = canonicalDatatype(datatype)
  if not canonical then
    error("RegisterCorrection: datatype must be one of Quest, Npc, Item, Object — got " ..
          tostring(datatype), 2)
  end
  if type(func) ~= "function" then
    -- Corrections are held behind functions so the data materialises only on apply. A
    -- multi-megabyte literal never lives in memory between load and apply, and constants the
    -- body reads are resolved at apply time rather than load time.
    error("RegisterCorrection: func must be a function returning the correction table, not the " ..
          "table itself", 2)
  end
  if loadOrder ~= nil and type(loadOrder) ~= "number" then
    error("RegisterCorrection: loadOrder must be a number or nil", 2)
  end

  local record = ownerRecord(owner)
  registrationSequence = registrationSequence + 1

  if loadOrder ~= nil then
    for _, existing in ipairs(record.entries) do
      if existing.datatype == canonical and existing.dynamic == dynamic and
         existing.loadOrder == loadOrder then
        -- Reported, not silently overwritten, and not displaced either: the tie breaks on
        -- registration sequence, which is deterministic and does not move the sitting entry.
        warn(format("load order %d is claimed by both '%s' and '%s' for %s %s corrections " ..
                    "(owner %s). Applying in registration order.",
          loadOrder, tostring(existing.name), tostring(name), canonical,
          dynamic and "dynamic" or "static", owner))
        break
      end
    end
  end

  local entry = {
    owner = owner,
    datatype = canonical,
    name = name or ("correction#" .. registrationSequence),
    func = func,
    loadOrder = loadOrder or (registrationSequence * 0.001),
    sequence = registrationSequence,
    dynamic = dynamic,
  }
  record.entries[#record.entries + 1] = entry
  record.pending = true
  return entry
end

--- Register a Static Correction — folded in during Generation, applied to base data in Source
--- mode, never shipped to end users.
function registry.RegisterCorrection(owner, datatype, name, func, loadOrder)
  return register(owner, datatype, name, func, loadOrder, false)
end

--- Register a Dynamic Correction — applied at query time through the Correction Overlay.
function registry.RegisterRuntimeCorrection(owner, datatype, name, func, loadOrder)
  return register(owner, datatype, name, func, loadOrder, true)
end

--- Withdraw a registration. Recomposition rebuilds from the registry rather than accumulating
--- into it, so re-applying after this genuinely removes the correction's effect — which the
--- previous merge-only `addOverride` could not do.
function registry.UnregisterCorrection(owner, datatype, name)
  local record = registry.owners[owner]
  if not record then return false end
  local canonical = canonicalDatatype(datatype)
  for index, entry in ipairs(record.entries) do
    if entry.datatype == canonical and entry.name == name then
      table.remove(record.entries, index)
      record.pending = true
      if entry.dynamic then registry.dirty[canonical] = true end
      return true
    end
  end
  return false
end

--- Optional convenience wrapper so a consumer does not repeat its own name.
function registry.GetRegistrar(owner)
  return {
    owner = owner,
    RegisterCorrection = function(datatype, name, func, loadOrder)
      return registry.RegisterCorrection(owner, datatype, name, func, loadOrder)
    end,
    RegisterRuntimeCorrection = function(datatype, name, func, loadOrder)
      return registry.RegisterRuntimeCorrection(owner, datatype, name, func, loadOrder)
    end,
    Apply = function() return registry.ApplyRegisteredCorrections(owner) end,
    Set = function(datatype, name, rows) return registry.Set(owner, datatype, name, rows) end,
  }
end

--------------------------------------------------------------------------------------------
-- Selection
--------------------------------------------------------------------------------------------

local function compareEntries(a, b)
  if a.loadOrder ~= b.loadOrder then return a.loadOrder < b.loadOrder end
  return a.sequence < b.sequence
end

--- Every registered entry matching the filters, in apply order.
---@param filter table { owner?, datatype?, dynamic? }
function registry.Select(filter)
  filter = filter or {}
  local selected = {}
  local owners = filter.owner and { filter.owner } or registry.ownerOrder
  for _, owner in ipairs(owners) do
    local record = registry.owners[owner]
    if record then
      for _, entry in ipairs(record.entries) do
        local matches = true
        if filter.datatype and entry.datatype ~= canonicalDatatype(filter.datatype) then matches = false end
        if filter.dynamic ~= nil and entry.dynamic ~= filter.dynamic then matches = false end
        if matches then selected[#selected + 1] = entry end
      end
    end
  end
  sort(selected, compareEntries)
  return selected
end

--------------------------------------------------------------------------------------------
-- Applying Static Corrections to base data
--------------------------------------------------------------------------------------------

-- Older Baked manifests can load updated Lua files without loading the operation engine.
-- Keep replacements working, but never let encoded operations leak into canonical rows.
local function resolveFields(fields, meta, context, id, base, fallback, noOverwrites, nilSentinel)
  if LibQuestieDB.TablePatch then
    return LibQuestieDB.TablePatch.Resolve(fields, meta, context, id, base, fallback, noOverwrites, nilSentinel)
  end
  for key in pairs(fields) do
    if type(key) == "number" and (key <= 0 or key >= 1000) then
      local field = key >= 1000 and key - 1000 or key + 1000
      error(format("Correction %s/%s %s %s field %s %s: table operations require an updated TOC; regenerate the Baked artifact",
        tostring(context and context.owner or "?"), tostring(context and context.name or "?"),
        tostring(meta and meta.entity or context and context.datatype or "?"), tostring(id),
        tostring(meta and meta.names[field] or field), key >= 1000 and "add" or "remove"), 0)
    end
  end
  return fields
end

--- Merge one correction table into a set of entity rows.
---
--- Shape is `id -> fieldIndex -> value`, matching Questie's. Two of Questie's idioms carry
--- over unchanged:
---
---   * `[key] = nil` in a correction literal is a no-op, because Lua's table constructor drops
---     it and `pairs` never visits the key. Occurrences in the ported files are documentation.
---   * `[key] = {}` is the delete idiom. An empty table reads back as nil under
---     docs/storage-format.md, so writing `{}` into base data removes the field for every
---     reader — the generator omits the line, Source mode normalizes it away.
---
--- An id absent from the base data is normally created, which is how `LoadMissingQuests`
--- and the `InsertMissing*Ids` helpers make the database emit a row at all. `noNewEntries`
--- forbids creation outright. Inherited Static Corrections additionally set
--- `allowNamedInheritedEntry`, matching Questie's exception for a Correction whose field 1 names
--- a complete entity rather than adding fields to an entity a later expansion removed.
---@param entities table id -> field array
---@param corrections table id -> fieldIndex -> value
---@param options table? { noOverwrites = boolean, noNewEntries = boolean, allowNamedInheritedEntry = boolean }
---@param context table? { datatype, owner?, name? }; required for table operations.
---@return number applied
function registry.MergeInto(entities, corrections, options, context)
  options = options or {}
  local applied = 0
  local meta = context and LibQuestieDB.Meta[canonicalDatatype(context.datatype)]
  for id, fields in pairs(corrections) do
    local row = entities[id]
    local resolved = resolveFields(fields, meta, context, id, row, nil, options.noOverwrites)
    local replacementOnly = resolved == fields
    fields = resolved
    local mayCreate = not options.noNewEntries
      or (options.allowNamedInheritedEntry and fields[1] ~= nil)
    if not row and mayCreate and (replacementOnly or next(fields) ~= nil) then
      row = {}
      entities[id] = row
    end
    if row then
      for fieldIndex, value in pairs(fields) do
        if type(fieldIndex) == "number" then
          if options.noOverwrites then
            if row[fieldIndex] == nil then
              row[fieldIndex] = value
              applied = applied + 1
            end
          else
            row[fieldIndex] = value
            applied = applied + 1
          end
        end
      end
    end
  end
  return applied
end

--- Resolve merge policy for one Static Correction in the target flavor.
--- Older-expansion Corrections may update surviving entities but cannot resurrect entities the
--- target expansion removed. A field-1 name is the explicit exception for a complete entity.
--- The exception is confined here so generic `noNewEntries` remains strict.
---@param entry table Registered Static Correction
---@param flavor table? Target flavor
---@return table? options Merge options, or the entry's original options when no overlay is needed
local function staticMergeOptions(entry, flavor)
  if not flavor or not entry.sourceExpansionOrder then return entry.options end

  local targetOrder = LibQuestieDB.config.expansionOrder[flavor.rules or flavor.expansion]
  if not targetOrder or targetOrder <= entry.sourceExpansionOrder then return entry.options end

  local options = {}
  for key, value in pairs(entry.options or {}) do options[key] = value end
  options.noNewEntries = true
  options.allowNamedInheritedEntry = true
  return options
end

--- Apply every Static Correction for one entity type to a loaded table.
---
--- Used by Generation and by Source mode. Same code, same order, same result — which is the
--- whole point: "what I see in dev is what ships" follows from shared code rather than from a
--- test.
---@param datatype string "Quest" | "Npc" | "Item" | "Object"
---@param entities table
---@param flavor table? An entry from config.flavors
---@param owner string? Restrict to one owner; Generation passes "QuestieDB"
---@return number applied
function registry.ApplyStaticToEntities(datatype, entities, flavor, owner)
  local applied = 0
  for _, entry in ipairs(registry.Select({ datatype = datatype, dynamic = false, owner = owner })) do
    if registry.EntryApplies(entry, flavor) then
      local corrections = entry.func()
      if type(corrections) == "table" then
        applied = applied + registry.MergeInto(
          entities, corrections, staticMergeOptions(entry, flavor), entry)
      end
    end
  end
  return applied
end

--- Whether an entry applies to a flavor. An entry may declare `expansions = { Classic = true }`
--- or `minExpansion = 2`; declaring nothing means "every flavor".
function registry.EntryApplies(entry, flavor)
  if not flavor then return true end
  if entry.expansions and not entry.expansions[flavor.expansion] then return false end
  if entry.minExpansionOrder then
    local order = LibQuestieDB.config.expansionOrder[flavor.rules or flavor.expansion]
    if not order or order < entry.minExpansionOrder then return false end
  end
  return true
end

--------------------------------------------------------------------------------------------
-- Composing the Correction Overlay
--------------------------------------------------------------------------------------------

-- Snapshot caller/provider-owned rows, never backend data. Function results are copied
-- only when refreshed, so unrelated writes reuse their independent materialization.
local function copyRows(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, child in pairs(value) do result[key] = copyRows(child) end
  return result
end

--- Rebuild the composed view for the given datatypes.
---
--- Recomposition is **idempotent by construction** — it rebuilds from the registry instead of
--- accumulating into it. That is what makes a withdrawn correction actually disappear, and
--- what lets a data-shaped `Set` hand a contested field back to whatever layer sits beneath.
---
--- Two scopes keep it cheap enough to run write-through:
---
---   * only the datatypes passed in rebuild — an Item write leaves the composed Quest, Npc,
---     and Object views, their read caches, and their shared ID maps untouched;
---   * a function-shaped entry materializes once and the result is memoized on the entry.
---     Re-applying an owner clears only that owner's memos, so its providers run again while
---     every other owner's layer reuses its last materialization. QuestieDB's own Dynamic
---     sets are session-constant, which is what makes reuse safe — and what keeps a consumer
---     write from re-materializing the multi-thousand-row SoD base sets on every change.
---@param flavor table? Active flavor, from LibQuestieDB.flavor
---@param datatypes table<string, true> Datatypes to rebuild
local function recompose(flavor, datatypes)
  local normalize = LibQuestieDB.Meta.normalize

  -- A rejected operation must leave reads, provenance and caches on the previous view.
  local composed, provenance = {}, {}
  local dataSnapshots = {}

  for _, owner in ipairs(registry.appliedOrder) do
    for _, entry in ipairs(registry.Select({ owner = owner, dynamic = true })) do
      if datatypes[entry.datatype] and registry.EntryApplies(entry, flavor) then
        if entry.data then dataSnapshots[entry] = copyRows(entry.data) end
        -- Publish from the snapshot too: retained caller tables may change before
        -- their next Set, including while a replacement and an invalid patch coexist.
        local corrections = dataSnapshots[entry]
        if corrections == nil then
          corrections = entry.materialized
          if corrections == nil then
            corrections = copyRows(entry.func())
            entry.materialized = corrections
          end
        end
        if type(corrections) == "table" then
          local datatype = entry.datatype
          local meta = LibQuestieDB.Meta[datatype]
          local byType = composed[datatype]
          if not byType then byType = {}; composed[datatype] = byType end
          local provByType = provenance[datatype]
          if not provByType then provByType = {}; provenance[datatype] = provByType end

          for id, fields in pairs(corrections) do
            -- Rows are created only when a write survives validation. In particular, a
            -- Correction containing only ignored constant fields must not invent an entity.
            local row = byType[id]
            local provRow = provByType[id]
            local entity = LibQuestieDB[datatype]
            fields = resolveFields(fields, meta, entry, id, row,
              entity and entity.GetRaw, entry.options and entry.options.noOverwrites, registry.NIL)

            for fieldIndex, value in pairs(fields) do
              if type(fieldIndex) == "number" and meta and fieldIndex <= meta.fieldCount then
                local constantValues = meta.constantValues
                if constantValues and constantValues[fieldIndex] ~= nil then
                  -- Constant fields no longer accept runtime ownership. Reads keep the schema
                  -- placeholder and provenance remains with QuestieDB.
                  if registry.debug then
                    warn(format('owner "%s" wrote deprecated constant %s %s field %s — dropped',
                      owner, datatype, tostring(id), tostring(meta.names[fieldIndex])))
                  end
                elseif type(value) == "table" and next(value) ~= nil and
                       meta.types[fieldIndex] ~= "table" then
                  -- A non-empty table arriving at a scalar-typed field is a correction-author
                  -- error. Generation fails loudly on the same input; the overlay reports and
                  -- drops the write rather than raising out of recomposition.
                  warn(format('owner "%s" wrote a table into %s-typed %s %s field %s — dropped',
                    owner, tostring(meta.types[fieldIndex]), datatype, tostring(id),
                    tostring(meta.names[fieldIndex])))
                else
                  if not row then row = {}; byType[id] = row end
                  if not provRow then provRow = {}; provByType[id] = provRow end

                  -- `[key] = {}` is the delete idiom for every field type. Scalar deletes are
                  -- decided here because normalize passes tables through scalar branches.
                  if type(value) == "table" and next(value) == nil then
                    row[fieldIndex] = registry.NIL
                    provRow[fieldIndex] = owner
                  else
                    if registry.debug and provRow[fieldIndex] and provRow[fieldIndex] ~= owner then
                      warn(format('owner "%s" overrode "%s" on %s %s field %s',
                        owner, provRow[fieldIndex], datatype, tostring(id),
                        tostring(meta.names[fieldIndex])))
                    end
                    -- The overlay stores normalized values so `{0,0}` and other nil semantics
                    -- match base data without another read-time decision.
                    local normalized = normalize.field(meta, fieldIndex, value)
                    if normalized == nil then
                      row[fieldIndex] = registry.NIL
                    else
                      row[fieldIndex] = normalized
                    end
                    provRow[fieldIndex] = owner
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  for entry, snapshot in pairs(dataSnapshots) do entry.lastSuccessfulData = snapshot end
  for datatype in pairs(datatypes) do
    registry.composed[datatype] = composed[datatype]
    registry.provenance[datatype] = provenance[datatype]
  end
end

--- Sentinel for "the overlay sets this field to nil", which a plain nil cannot express.
registry.NIL = setmetatable({}, { __tostring = function() return "<overlay nil>" end })

---Publish only the changed datatypes, clearing their fields and ID maps. Entity globals
---preserve their Name indexes unless corrected names or composed membership may have changed.
---@param datatypes table<string, true> Datatypes to publish.
---@return nil
local function publish(datatypes)
  local config = LibQuestieDB.config
  for _, entityType in ipairs(config.entityTypes) do
    if datatypes[entityType.name] then
      local entity = LibQuestieDB[entityType.name]
      if entity then
        entity.SetOverlay(registry.composed[entityType.name] or {})
      end
    end
  end
end

--- Fix an owner's rank on its first apply or first `Set`. Moving a re-applying owner to the
--- end would let a consumer state refresh hoist one owner's whole layer above corrections
--- registered later, inverting the documented QuestieDB < Questie < third-party order.
local function rankOwner(owner)
  for _, applied in ipairs(registry.appliedOrder) do
    if applied == owner then return end
  end
  registry.appliedOrder[#registry.appliedOrder + 1] = owner
end

--- Recompose dirty datatypes. Set scopes the flush so unrelated failed providers cannot
--- block its write; Apply retries all dirty work as one staged publication.
---@param datatype string? Restrict the flush to a Set's written datatype.
local function flushDirty(datatype)
  if next(registry.dirty) == nil then return end
  local datatypes = datatype and { [datatype] = true } or registry.dirty
  -- Both read modes publish their flavor as LibQuestieDB.flavor (source.lua, baked.lua), so
  -- entry-level expansion filters compose identically in both — reading only the Source
  -- backend here left them inert in Baked mode.
  local ok, err = pcall(recompose, LibQuestieDB.flavor, datatypes)
  if not ok then
    -- Retrying must call providers again, not reuse a rejected materialization. Keep dirty
    -- datatypes and pending owners until composition succeeds; the published view is intact.
    for _, owner in ipairs(registry.appliedOrder) do
      for _, entry in ipairs(registry.owners[owner].entries) do
        if entry.dynamic and entry.func and datatypes[entry.datatype] then
          entry.materialized = nil
          registry.owners[owner].pending = true
        end
      end
    end
    error(err, 0)
  end
  publish(datatypes)
  for changed in pairs(datatypes) do registry.dirty[changed] = nil end
end

--- Apply pending Corrections.
---
--- The owner parameter selects **which layer is being refreshed**, never which layers are
--- visible: recomposition always includes every live layer. This is required by load order,
--- not a convenience — a third-party addon declares `## Dependencies: Questie` and therefore
--- registers after Questie has already applied.
---
--- Refreshing an owner re-runs that owner's provider functions; every other owner's layer
--- reuses its successful materialization. Failed composition leaves affected providers pending
--- and discards their memos, so a no-argument retry can use corrected captured state.
---@param owner string? One owner, or every pending owner when omitted
function registry.ApplyRegisteredCorrections(owner)
  local owners
  if owner then
    if not registry.owners[owner] then return 0 end
    owners = { owner }
  else
    owners = {}
    for _, name in ipairs(registry.ownerOrder) do
      if registry.owners[name].pending then owners[#owners + 1] = name end
    end
  end

  for _, name in ipairs(owners) do
    rankOwner(name)
    registry.owners[name].pending = true
    -- This owner is the layer being refreshed: forget its materializations so its providers
    -- run again, and mark its datatypes for recomposition.
    for _, entry in ipairs(registry.owners[name].entries) do
      if entry.dynamic then
        entry.materialized = nil
        registry.dirty[entry.datatype] = true
      end
    end
  end

  flushDirty()
  for _, name in ipairs(owners) do registry.owners[name].pending = false end
  return #owners
end

--------------------------------------------------------------------------------------------
-- Data-shaped corrections
--------------------------------------------------------------------------------------------

--- Write one correction as data and publish it immediately: no provider function, no
--- separate `Apply()`, no loadOrder — within an owner, slots take effect in creation order.
---
--- Each (owner, datatype, name) is a slot. Writing it again replaces the previous rows in
--- place; `rows = nil` removes the slot, so whatever an earlier layer put underneath shows
--- through again; `{}` keeps the slot but contributes nothing. Precedence follows the same
--- rules as the function-shaped API: the owner's rank is fixed by its first write or apply.
---
--- Data-shaped because consumer corrections are small state-driven tables — the
--- multi-megabyte-literal reason the function shape exists does not apply to them. The
--- function shape remains for exactly that reason.
---@param owner string
---@param datatype string "Quest" | "Npc" | "Item" | "Object"
---@param name string Slot name, unique per owner and datatype
---@param rows table? id -> fieldIndex -> value; nil removes the slot
---@return boolean changed False only when removing a slot that does not exist
function registry.Set(owner, datatype, name, rows)
  if type(owner) ~= "string" or owner == "" then
    error("Set: owner must be a non-empty string", 2)
  end
  local canonical = canonicalDatatype(datatype)
  if not canonical then
    error("Set: datatype must be one of Quest, Npc, Item, Object — got " .. tostring(datatype), 2)
  end
  if type(name) ~= "string" or name == "" then
    error("Set: name must be a non-empty string", 2)
  end
  if rows ~= nil and type(rows) ~= "table" then
    error("Set: rows must be a table of id -> fieldIndex -> value, or nil to remove the slot", 2)
  end

  local record = registry.owners[owner]
  local entry
  if record then
    -- Match on datatype+name across ALL of the owner's entries: a Static or function-shaped
    -- Dynamic entry sharing the name must be refused below, never silently shadowed — or,
    -- worse, removed by the nil path in the data slot's place.
    for _, existing in ipairs(record.entries) do
      if existing.datatype == canonical and existing.name == name then
        entry = existing
        break
      end
    end
  end
  if entry and entry.func then
    error(("Set: '%s' is already a function-shaped %s correction of owner '%s'; update its " ..
      "captured state and re-apply instead of mixing in a data write"):format(name, canonical, owner), 2)
  end

  -- Stage the slot edit as well as the view: a rejected patch must not poison later writes.
  local previousData = entry and entry.lastSuccessfulData
  local previousDirty = registry.dirty[canonical]
  local newOwner = record == nil
  local previousIndex
  local wasRanked = false
  for _, applied in ipairs(registry.appliedOrder) do if applied == owner then wasRanked = true end end
  if rows == nil then
    if not entry then return false end
    for index, existing in ipairs(record.entries) do
      if existing == entry then
        previousIndex = index
        table.remove(record.entries, index)
        break
      end
    end
    registry.dirty[canonical] = true
  elseif entry then
    entry.data = rows
    registry.dirty[canonical] = true
  else
    record = ownerRecord(owner)
    registrationSequence = registrationSequence + 1
    record.entries[#record.entries + 1] = {
      owner = owner,
      datatype = canonical,
      name = name,
      data = rows,
      loadOrder = registrationSequence * 0.001,
      sequence = registrationSequence,
      dynamic = true,
    }
    registry.dirty[canonical] = true
  end

  rankOwner(owner)
  local ok, err = pcall(flushDirty, canonical)
  if not ok then
    if entry then
      -- The caller may have mutated the retained rows in place. Restore an independent
      -- copy so subsequent mutations cannot corrupt the last successful snapshot.
      entry.data = copyRows(previousData)
      if previousIndex then table.insert(record.entries, previousIndex, entry) end
    else
      table.remove(record.entries)
    end
    if not wasRanked then table.remove(registry.appliedOrder) end
    if newOwner then
      registry.owners[owner] = nil
      table.remove(registry.ownerOrder)
    end
    registry.dirty[canonical] = previousDirty
    error(err, 0)
  end
  -- A successful Set must not consume this owner's retry for a different failed datatype.
  -- Set-only owners with no remaining dirty work still need no explicit Apply.
  record.pending = false
  for _, existing in ipairs(record.entries) do
    if existing.dynamic and registry.dirty[existing.datatype] then
      record.pending = true
      break
    end
  end
  return true
end

--- Which owner supplied the winning value for a field, for bug reports.
function registry.GetProvenance(datatype, id, key)
  local canonical = canonicalDatatype(datatype)
  if not canonical then return nil end
  local meta = LibQuestieDB.Meta[canonical]
  local fieldIndex = (meta and meta.keys[key]) or (type(key) == "number" and key or nil)
  if not fieldIndex then return nil end
  local byType = registry.provenance[canonical]
  local row = byType and byType[id]
  if row and row[fieldIndex] then return row[fieldIndex] end
  -- No Dynamic Correction won, so the value came from base data — which in Baked mode already
  -- has QuestieDB's Static Corrections folded in.
  return registry.OWNER
end

--- Owners in applied order, so a debug view can show precedence.
function registry.GetOwners()
  local owners = {}
  for index, name in ipairs(registry.appliedOrder) do owners[index] = name end
  return owners
end

function registry.Reset()
  registry.owners = {}
  registry.ownerOrder = {}
  registry.appliedOrder = {}
  registry.composed = {}
  registry.provenance = {}
  registry.dirty = {}
  registrationSequence = 0
end

LibQuestieDB.Corrections = registry

return registry
