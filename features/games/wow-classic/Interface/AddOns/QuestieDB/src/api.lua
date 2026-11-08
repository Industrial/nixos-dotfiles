-- src/api.lua
--
-- The public surface. Another addon can read entity fields, discover the schema, register its
-- own Corrections, and detect an incompatible version through this file alone.
--
-- Questie is the first consumer, but nothing here assumes it.

local ADDON_NAME, LibQuestieDB = ...

local config = LibQuestieDB.config
local shared = LibQuestieDB.shared

--------------------------------------------------------------------------------------------
-- Entity globals
--------------------------------------------------------------------------------------------

local mode = LibQuestieDB.mode or "source"
local backendFactory = LibQuestieDB.read[mode]
if not backendFactory then
  error("QuestieDB: no read backend for mode '" .. tostring(mode) .. "'", 0)
end

for _, entityType in ipairs(config.entityTypes) do
  local meta = LibQuestieDB.Meta[entityType.name]
  if meta then
    local entity = shared.CreateEntity(meta, backendFactory.CreateBackend(meta))
    LibQuestieDB[entityType.name] = entity
    -- `QuestDB`, `NpcDB`, `ItemDB`, `ObjectDB` — the shorthand the tracer bullet and
    -- `/dump` use, and what the prototypes exposed.
    _G[entityType.name .. "DB"] = entity
  end
end

--------------------------------------------------------------------------------------------
-- Schema
--------------------------------------------------------------------------------------------
--
-- The schema is public so consumers can name fields rather than index them. Two spellings are
-- exposed: `Meta.Quest` is the internal shape, and `Meta.QuestMeta.questKeys` is the spelling
-- DESIGN.md documents. They are the same tables, not copies.

for _, entityType in ipairs(config.entityTypes) do
  local meta = LibQuestieDB.Meta[entityType.name]
  if meta then
    local lower = entityType.name:sub(1, 1):lower() .. entityType.name:sub(2)
    LibQuestieDB.Meta[entityType.name .. "Meta"] = {
      [lower .. "Keys"] = meta.keys,
      names = meta.names,
      types = meta.types,
      structures = meta.structures,
      compilerTypes = meta.compilerTypes,
      fieldCount = meta.fieldCount,
      l10nFields = meta.l10nFields,
    }
  end
end

-- The provider flavor is already selected by native Source files or Baked metadata.
-- Consumers share these active faction masks; read-only by contract.
local raceKeys = LibQuestieDB.Enum.byExpansion[LibQuestieDB.flavor.expansion].raceKeys
LibQuestieDB.Enum.factionRaceMasks = {
  Alliance = raceKeys.ALL_ALLIANCE,
  Horde = raceKeys.ALL_HORDE,
}

-- Same selection as correction compat: the flavor's own table, else its rules flavor's table.
local flavor = LibQuestieDB.flavor
local byExpansion = LibQuestieDB.Enum.byExpansion

---@param name string The named constants table to return.
---@return table<string, integer> Active provider flavor's named constants, or the rules flavor's if the active flavor lacks them.
local function activeConstants(name)
  return byExpansion[flavor.expansion][name] or byExpansion[flavor.rules][name]
end

LibQuestieDB.Enum.classKeys = activeConstants("classKeys")
LibQuestieDB.Enum.npcFlags = activeConstants("npcFlags")

--------------------------------------------------------------------------------------------
-- Contract
--------------------------------------------------------------------------------------------

--- Independent release cycles make skew inevitable. A hard `## Dependencies: QuestieDB`
--- covers *absence*; it does not cover *presence with the wrong version*. A consumer checks
--- this at init and fails with a specific message.
LibQuestieDB.contractVersion = config.contractVersion
LibQuestieDB.minSupportedContract = config.minSupportedContract

LibQuestieDB.addonName = ADDON_NAME

--- Check compatibility from a consumer's init in one call, so the failure message is specific
--- rather than an obscure nil index three files later.
---
--- The check is a **range, not an equality** (ADR 0003 D12): a consumer written against an
--- older contract keeps working across additive releases, down to `minSupportedContract`.
--- Equality would force lockstep updates — the exact thing two independent release streams
--- exist to avoid.
---@param required integer The positive contract version the consumer was written against
---@return boolean ok
---@return string? message
function LibQuestieDB.RequireContract(required)
  if type(required) == "number" and required >= 1 and required % 1 == 0 and
     required >= config.minSupportedContract and required <= config.contractVersion then
    return true
  end
  return false, ("QuestieDB contract mismatch: this consumer needs version %s, the installed " ..
    "QuestieDB provides %s (supporting consumers back to %s). Update whichever is older.")
    :format(tostring(required), tostring(config.contractVersion),
            tostring(config.minSupportedContract))
end

--- "source" or "baked". Mode must be unmistakable, so this is public rather than internal.
LibQuestieDB.readMode = mode

--------------------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------------------

--- Drop cached values for one entity, or for everything when both arguments are omitted.
--- Registering a Correction after `ApplyRegisteredCorrections` has run must stay legal, which
--- is what this is for.
function LibQuestieDB.InvalidateCache(datatype, id)
  if datatype == nil then
    for _, entityType in ipairs(config.entityTypes) do
      local entity = LibQuestieDB[entityType.name]
      if entity then entity.InvalidateCache(nil) end
    end
    return
  end
  -- Accept the same case-insensitive datatype spellings the corrections API accepts;
  -- `InvalidateCache("quest", 2)` silently doing nothing was a live-probed defect.
  local canonical = LibQuestieDB.Corrections.CanonicalDatatype(datatype)
  local entity = canonical and LibQuestieDB[canonical]
  if entity then entity.InvalidateCache(id) end
end

--------------------------------------------------------------------------------------------
-- Own corrections
--------------------------------------------------------------------------------------------

--- QuestieDB applies its own layer at load, so base data is queryable immediately and
--- correctly — step 1 of the initialization order in DESIGN.md. A consumer then registers its
--- policy Corrections and calls `ApplyRegisteredCorrections("<its own name>")` in its staged
--- init; recomposition always includes every live layer, so QuestieDB's stays visible.
LibQuestieDB.ApplyRegisteredCorrections = LibQuestieDB.Corrections.ApplyRegisteredCorrections
LibQuestieDB.RegisterCorrection = LibQuestieDB.Corrections.RegisterCorrection
LibQuestieDB.RegisterRuntimeCorrection = LibQuestieDB.Corrections.RegisterRuntimeCorrection
LibQuestieDB.GetRegistrar = LibQuestieDB.Corrections.GetRegistrar
---Report the owner of the value returned by composed reads, including localization.
---@param datatype string
---@param id number
---@param key string|number
---@return string?
function LibQuestieDB.GetProvenance(datatype, id, key)
  local l10n = LibQuestieDB.l10n
  local translatedOwner = l10n and l10n.GetProvenance and l10n.GetProvenance(datatype, id, key)
  if translatedOwner then return translatedOwner end
  return LibQuestieDB.Corrections.GetProvenance(datatype, id, key)
end
LibQuestieDB.GetOwners = LibQuestieDB.Corrections.GetOwners
LibQuestieDB.SetCorrection = LibQuestieDB.Corrections.Set

LibQuestieDB.Corrections.ApplyRegisteredCorrections(LibQuestieDB.Corrections.OWNER)

--- Localization attaches after the Entity globals exist, and is a no-op when the artifact
--- carries no l10n data.
if LibQuestieDB.l10n and LibQuestieDB.l10n.Initialize then
  LibQuestieDB.l10n.Initialize()
end

--- Mode must be unmistakable in-game, so the indicator comes up as part of loading rather
--- than waiting for a consumer to ask for it.
if LibQuestieDB.ModeIndicator then
  LibQuestieDB.ModeIndicator.Initialize()
end

_G.LibQuestieDB = LibQuestieDB

return LibQuestieDB
