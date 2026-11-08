-- src/support/data.lua
--
-- Support data: game reference data consumed as whole tables rather than through the TOC
-- metadata store — zone mappings, quest XP, drop tables, faction templates.
--
-- It stays plain Lua rather than becoming metadata because callers want the whole table, not
-- lazy per-field access. Lazy decoding buys nothing when the first read materialises
-- everything anyway.
--
-- **Only the data moves.** The modules that wrap it — `zoneDB.lua`, `QuestieXP.lua`,
-- `dropDB.lua` — are `QuestieLoader` modules with runtime behaviour and stay with the
-- consumer. They read what this file publishes.
--
-- Both TOC modes select applicable files before their assignments execute.

local _, LibQuestieDB = ...

local support = {}

--- moduleName -> the table that module's data files assigned into.
--- e.g. `Support.Get("ZoneDB").private.areaIdToUiMapId`, `Support.Get("QuestXP").db`
support.modules = {}

local saved

--- Install a `QuestieLoader` shim that routes support-data assignments here instead of into
--- the consumer's modules. Scoped exactly like the entity-data and correction shims.
---
--- `dungeons.lua` is the one support file that is data *and* logic: it branches on
--- `Expansions.Current` to fix up three dungeon entries per expansion. The module is therefore
--- seeded rather than left empty, or those branches compare against nil.
---@param flavor table? An entry from config.flavors
function support.Install(flavor)
  saved = rawget(_G, "QuestieLoader")
  support.modules = {}

  ---@param name string
  ---@return table module
  local function moduleFor(name)
    local modules = support.modules
    local module = modules[name]
    if not module then
      module = { private = {} }
      modules[name] = module
    end
    return module
  end

  local constants = LibQuestieDB.Enum
  -- Publish the shared symbols through the existing support API, not a second data table.
  moduleFor("ZoneDB").zoneIDs = constants.zoneIDs

  -- `itemDropCorrections.lua` reads `DropDB.correctionKeys` — negative sentinels that mark a
  -- correction's provenance (Wowhead, private server, manual). They live in `dropDB.lua`, the
  -- logic module staying with the consumer, so they are extracted alongside the entity
  -- constants and seeded here.
  if constants.dropCorrectionKeys then
    moduleFor("DropDB").correctionKeys = constants.dropCorrectionKeys
  end

  local order = LibQuestieDB.config.expansionOrder
  local expansions = moduleFor("Expansions")
  expansions.Era, expansions.Classic, expansions.Tbc = order.Classic, order.Classic, order.TBC
  expansions.Wotlk, expansions.Cata, expansions.MoP = order.Wotlk, order.Cata, order.MoP
  expansions.Current = (flavor and order[flavor.rules or flavor.expansion]) or order.Classic

  _G.QuestieLoader = {
    ImportModule = function(_, name) return moduleFor(name) end,
    CreateModule = function(_, name) return moduleFor(name) end,
  }
end

function support.Remove()
  _G.QuestieLoader = saved
  saved = nil
end

--- Whole-table access, which is the entire point of keeping this out of metadata.
---@param moduleName string "ZoneDB" | "QuestXP" | "DropDB" | "QuestieDB" | ...
function support.Get(moduleName)
  return support.modules[moduleName]
end

--- Every module the loaded support files populated, for a consumer that wants to enumerate.
function support.GetAll()
  return support.modules
end

LibQuestieDB.Support = support

return support
