-- src/corrections/compat.lua
--
-- The module surface Questie's correction files expect.
--
-- Owned correction files retain the module-based authoring format imported from Questie.
-- Scoped stand-ins provide `QuestieLoader`, the handful of modules those files import,
-- and the icon constants their providers read later. The loader is
-- installed only while correction files load. The `Questie` stand-in exists in the global
-- namespace only while a registered provider runs, and both globals are restored afterwards.

local _, LibQuestieDB = ...

local compat = {}

local constants = LibQuestieDB.Enum

-- Derive authoring views once per namespace, after schemas and constants have loaded.
-- Keep operations out of canonical keys/getters and retain identities across Install calls.
for _, entityType in ipairs(LibQuestieDB.config.entityTypes) do
  local keys = {}
  for name, index in pairs(LibQuestieDB.Meta[entityType.name].keys) do
    assert(index > 0 and index < 1000 and index % 1 == 0,
      "Correction aliases require canonical indices below the reserved operation range")
    keys[name] = index
    -- Scalar aliases let misuse report the field and operation instead of a nil table key.
    keys[name .. "_add"] = index + 1000
    keys[name .. "_remove"] = index - 1000
  end
  constants[entityType.keysField] = keys
end

--------------------------------------------------------------------------------------------
-- Module stand-ins
--------------------------------------------------------------------------------------------

--- `QuestieCorrections.itemObjectiveFirst[503] = true` and friends are module-level side
--- effects in the correction files. They are consumer hints about objective ordering, not
--- entity data, so they are collected and published rather than merged into the database.
compat.objectiveFirst = {
  killCreditObjectiveFirst = {},
  objectObjectiveFirst = {},
  itemObjectiveFirst = {},
  eventObjectiveFirst = {},
  spellObjectiveFirst = {},
}

-- Inactive seasonal files still define providers, but their hint writes must not enter the
-- published tables. Keep both collections stable for modules that capture local references.
local discardedObjectiveFirst = {}
for field in pairs(compat.objectiveFirst) do discardedObjectiveFirst[field] = {} end

---@param hints table<string, table<number, boolean>>
---@return nil
local function clearHints(hints)
  for _, ids in pairs(hints) do
    for id in pairs(ids) do ids[id] = nil end
  end
end

---Select the hint destination before the next correction file imports its modules.
---This does not suppress provider definitions or alter any entity-data stand-in.
---@param enabled boolean
---@return nil
function compat.SelectObjectiveFirstScope(enabled)
  compat.modules.QuestieCorrections = enabled and compat.objectiveFirst or discardedObjectiveFirst
end

--- Direct writes such as `QuestieDB.questData[5640] = {}` — how `LoadMissingQuests` and the
--- `InsertMissing*Ids` helpers make the database emit a row at all. Captured per datatype so
--- the apply path can fold them in alongside the function's return value.
compat.captured = { Quest = {}, Npc = {}, Item = {}, Object = {} }

local DATA_FIELD_TO_TYPE = {
  questData = "Quest", npcData = "Npc", itemData = "Item", objectData = "Object",
}

local ACTIVE_FLAVOR_CONSTANTS = { classKeys = true, npcFlags = true }

---Selects shared constants, then flavor tables, then the flavor's explicit rules fallback.
---Fallback replaces whole tables, never missing keys within a flavor-owned table.
---@param name string Constant table name.
---@param flavor table Validated supported flavor.
---@return table value
local function pick(name, flavor)
  -- These `Enum` entries are the active flavor's tables published by api.lua, not shared constants.
  local shared = (not ACTIVE_FLAVOR_CONSTANTS[name]) and constants[name] or nil
  if shared ~= nil then return shared end

  local byExpansion = constants.byExpansion
  local expansionConstants = byExpansion and byExpansion[flavor.expansion]
  if type(expansionConstants) ~= "table" then
    error("correction compat: constants are missing expansion data for " .. flavor.expansion, 0)
  end

  local value = expansionConstants[name]
  if value == nil and flavor.rules then
    value = byExpansion[flavor.rules][name]
  end
  if value == nil then
    error(("correction compat: unknown constant `%s` for expansion `%s`")
      :format(name, flavor.expansion), 0)
  end
  return value
end

---Builds the QuestieDB stand-in with constants selected for one explicit flavor.
---@param flavor table Validated supported flavor.
---@return table QuestieDB
local function buildQuestieDB(flavor)
  local QuestieDB = {
    -- Share the schema-derived authoring views with public correction consumers.
    questKeys = constants.questKeys,
    npcKeys = constants.npcKeys,
    itemKeys = constants.itemKeys,
    objectKeys = constants.objectKeys,
    raceKeys = pick("raceKeys", flavor),
    classKeys = pick("classKeys", flavor),
    sortKeys = pick("sortKeys", flavor),
    specialFlags = pick("specialFlags", flavor),
    factionIDs = pick("factionIDs", flavor),
    questFlags = pick("questFlags", flavor),
    npcFlags = pick("npcFlags", flavor),
    itemClasses = pick("itemClasses", flavor),
    waypointPresets = pick("waypointPresets", flavor),
  }

  for name, datatype in pairs(DATA_FIELD_TO_TYPE) do
    QuestieDB[name] = compat.captured[datatype]
  end

  -- The reversed maps exist only to render a CI warning message in Questie's merge helper;
  -- they are provided so a file that touches them does not fault.
  local function reverse(keys)
    local reversed = {}
    for key, index in pairs(keys) do reversed[index] = key end
    return reversed
  end
  QuestieDB.questKeysReversed = reverse(QuestieDB.questKeys)
  QuestieDB.npcKeysReversed = reverse(QuestieDB.npcKeys)
  QuestieDB.itemKeysReversed = reverse(QuestieDB.itemKeys)
  QuestieDB.objectKeysReversed = reverse(QuestieDB.objectKeys)

  return QuestieDB
end

---Builds all copied-provider module stand-ins for one explicit flavor.
---@param flavor table Validated supported flavor.
---@return table modules
local function buildModules(flavor)
  local modules = {}

  modules.QuestieDB = buildQuestieDB(flavor)
  modules.ZoneDB = { zoneIDs = pick("zoneIDs", flavor) }
  modules.QuestieProfessions = {
    professionKeys = pick("professionKeys", flavor),
    specializationKeys = pick("specializationKeys", flavor),
    rankNames = pick("rankNames", flavor),
  }
  modules.QuestieCorrections = compat.objectiveFirst
  modules.Phasing = { phases = pick("phases", flavor) }

  -- `l10n(...)` appears ~100 times in classicQuestFixes and ~207 times in tbcQuestFixes,
  -- always inside `extraObjectives`. **Store the enUS string, translate at render time** —
  -- Questie's l10n is keyed by the English string, so the output is identical and the database
  -- stays locale-free. The prototype's correction files stubbed it exactly this way.
  modules.l10n = setmetatable({}, { __call = function(_, text) return text end })

  -- Preserve the provider-facing spellings; numeric ordering belongs to config.
  local order = LibQuestieDB.config.expansionOrder
  modules.Expansions = {
    Era = order.Classic, Classic = order.Classic, Tbc = order.TBC,
    Wotlk = order.Wotlk, Cata = order.Cata, MoP = order.MoP,
    Current = order[flavor.rules or flavor.expansion],
  }

  return modules
end

--------------------------------------------------------------------------------------------
-- Scoped installation
--------------------------------------------------------------------------------------------

local saved

-- Copied providers resolve these constants through the global at invocation time. Keep the
-- stand-in private between calls so Questie's duplicate-installation check sees an unclaimed
-- global when it loads after QuestieDB.
local correctionQuestie = {}
for name, value in pairs(constants.iconTypes) do correctionQuestie[name] = value end

---Installs the loader shim while the copied correction files define their modules.
---@param flavor table Active supported database flavor.
---@return fun(): nil remove Restores the previous `QuestieLoader`.
function compat.Install(flavor)
  if type(flavor) ~= "table" then
    error("correction compat: Install requires an explicit flavor table", 2)
  end

  local expansionName = flavor.rules or flavor.expansion
  local configuredFlavor = LibQuestieDB.config.flavorByName[flavor.name]
  local expansionOrder = LibQuestieDB.config.expansionOrder
  local order = expansionOrder[expansionName]
  if not configuredFlavor or configuredFlavor.expansion ~= flavor.expansion or
     (configuredFlavor.rules or configuredFlavor.expansion) ~= expansionName or not order then
    error(("correction compat: unsupported flavor `%s` / expansion `%s`")
      :format(tostring(flavor.name), tostring(expansionName)), 2)
  end
  if type(constants.byExpansion) ~= "table" or
     type(constants.byExpansion[expansionName]) ~= "table" then
    error("correction compat: constants are missing expansion data for " .. expansionName, 2)
  end

  -- Build before changing globals so malformed constants fail without side effects.
  local modules = buildModules(flavor)

  -- A reinstall starts a new load without replacing the published table identities.
  clearHints(compat.objectiveFirst)
  clearHints(discardedObjectiveFirst)
  saved = { QuestieLoader = rawget(_G, "QuestieLoader") }
  compat.modules = modules

  _G.QuestieLoader = {
    ImportModule = function(_, name)
      modules[name] = modules[name] or {}
      return modules[name]
    end,
    CreateModule = function(_, name)
      modules[name] = modules[name] or {}
      return modules[name]
    end,
  }

  return compat.Remove
end

--- Restores the loader global saved by `Install`.
---@return nil
function compat.Remove()
  if not saved then return end
  _G.QuestieLoader = saved.QuestieLoader
  saved = nil
  clearHints(discardedObjectiveFirst)
  compat.modules.QuestieCorrections = compat.objectiveFirst
end

--- Invokes a copied correction provider with its private `Questie` constants available.
--- Restoration happens before an error is rethrown, so a bad provider cannot block Questie.
---@param func fun(...): table? Copied correction provider.
---@param ... any Provider receiver and arguments.
---@return table? corrections Provider result.
function compat.Invoke(func, ...)
  local previousQuestie = rawget(_G, "Questie")
  rawset(_G, "Questie", correctionQuestie)

  local ok, returned = pcall(func, ...)
  rawset(_G, "Questie", previousQuestie)

  if not ok then error(returned, 0) end
  return returned
end

--------------------------------------------------------------------------------------------
-- Capture
--------------------------------------------------------------------------------------------

--- Clear the direct-write buffers before invoking a correction function.
function compat.BeginCapture()
  for datatype in pairs(compat.captured) do
    local buffer = compat.captured[datatype]
    for id in pairs(buffer) do buffer[id] = nil end
  end
end

--- What a correction function wrote directly, for one datatype.
function compat.EndCapture(datatype)
  return compat.captured[datatype]
end

LibQuestieDB.CorrectionCompat = compat

return compat
