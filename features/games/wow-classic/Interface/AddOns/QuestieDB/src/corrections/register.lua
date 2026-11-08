-- src/corrections/register.lua
--
-- Turns loaded correction files into registry entries.
--
-- `src/corrections/manifest.lua` says which functions each owned file provides and whether each is
-- Static or Dynamic. That classification is **declared, never inferred** —
-- folder names are not a reliable signal, as the prototype's `Sod/static/…` file registering
-- dynamic demonstrates.

local _, LibQuestieDB = ...

local register = {}

local registry = LibQuestieDB.Corrections
local compat = LibQuestieDB.CorrectionCompat

--- Wrap one function from a correction module into something the registry can apply.
---
--- Two shapes have to work. Most functions return the correction table. A few — Questie's
--- `LoadMissingQuests` and the `InsertMissing*Ids` helpers called from inside `Load` — instead
--- write straight into `QuestieDB.questData[id]` to make the database emit a row at all. The
--- compat shim captures those writes, and both contributions are merged here, direct writes
--- first so a returned value wins.
---@param module table
---@param functionName string
---@param datatype string
---@return fun(): table
local function wrap(module, functionName, datatype)
  return function()
    compat.BeginCapture()
    local returned = compat.Invoke(module[functionName], module)
    local captured = compat.EndCapture(datatype)

    local merged = {}
    for id, fields in pairs(captured) do
      local row = {}
      for key, value in pairs(fields) do row[key] = value end
      merged[id] = row
    end
    if type(returned) == "table" then
      for id, fields in pairs(returned) do
        local row = merged[id]
        if not row then row = {}; merged[id] = row end
        for key, value in pairs(fields) do row[key] = value end
      end
    end
    return merged
  end
end

---Whether a manifest entry belongs to the file-gated SoD variant.
---@param spec table Correction manifest entry.
---@return boolean
function register.IsSod(spec)
  return spec.file:find("^Sod/") ~= nil
end

---Whether a manifest entry belongs to the file-gated Titan Reforged variant.
---@param spec table Correction manifest entry.
---@return boolean
function register.IsTitanReforged(spec)
  return spec.file:find("^Titan/") ~= nil
end

--- Whether the running client actually has Season of Discovery active (ADR 0003 D9).
--- SoD is a Dynamic Correction set over the Era database, but it must never apply on
--- ordinary non-seasonal Era — expansion gating alone let 10,640 SoD ids leak onto plain
--- Vanilla. Offline and in the emulator, `C_Seasons.GetActiveSeason()` returns 0, so the
--- default everywhere without a live seasonal client is "not active".
---@param flavor table? Active provider flavor.
---@return boolean active
function register.IsSodActive(flavor)
  flavor = flavor or LibQuestieDB.flavor
  if not flavor or flavor.name ~= "Vanilla" then return false end
  local seasons = rawget(_G, "C_Seasons")
  if not seasons or type(seasons.GetActiveSeason) ~= "function" then return false end
  local enum = rawget(_G, "Enum")
  local sodId = enum and enum.SeasonID and enum.SeasonID.SeasonOfDiscovery or 2
  return seasons.GetActiveSeason() == sodId
end

--- Whether the running client is Titan Reforged: Wrath plus active season 109.
---
--- Checking the season alone is insufficient. Emulator personas proved Cata and Mists would
--- otherwise accept the Titan set when reporting the same season id. `flavor` is explicit so
--- offline registration follows the same rule without depending on a global runtime backend.
---@param flavor table? Active database flavor; nil keeps the variant closed.
---@return boolean active
function register.IsTitanReforgedActive(flavor)
  if not flavor or flavor.expansion ~= "Wotlk" then return false end
  local seasons = rawget(_G, "C_Seasons")
  if not seasons or type(seasons.GetActiveSeason) ~= "function" then return false end
  return seasons.GetActiveSeason() == 109
end

--- Register everything the manifest describes, for one flavor.
---
--- The generator runs offline with only QuestieDB present, so it can only ever bake
--- corrections owned by QuestieDB. Anything registered by Questie or a third party is Dynamic
--- by definition; the owner recorded here makes that enforceable rather than conventional.
---@param flavor table? An entry from config.flavors; nil keeps file-gated variants closed.
---@param moduleFor fun(name: string): table? Resolves a module name to its loaded table
---@return number registered
---@return number skipped
function register.FromManifest(flavor, moduleFor)
  local manifest = LibQuestieDB.CorrectionManifest
  if not manifest then return 0, 0 end

  local order = registry.loadOrder
  local registered, skipped = 0, 0

  -- Baked mode never applies Static Corrections: Generation already folded them into the
  -- metadata store, and ApplyStaticToEntities is only called by Source mode and the
  -- generator. Skip the registrations rather than build wrap() closures nothing can ever
  -- run — the packaged copies of these files have their static bodies stripped anyway
  -- (tools/distribution/strip-static.lua, issue #5). Offline (`generator/runtime.lua`) and in Source
  -- mode `LibQuestieDB.mode` is never "baked", so statics register there as before.
  local registerStatics = LibQuestieDB.mode ~= "baked"

  for index, spec in ipairs(manifest) do
    local applies = LibQuestieDB.config.correctionApplies(spec, flavor)
    if applies and register.IsSod(spec) and not register.IsSodActive(flavor) then
      applies = false
    end
    if applies and register.IsTitanReforged(spec) and
       not register.IsTitanReforgedActive(flavor) then
      applies = false
    end

    local module = applies and moduleFor(spec.module) or nil
    if not module then
      if applies then skipped = skipped + 1 end
    else
      -- Load-order constants, not literal numbers. The prototype's SoD files passed a literal
      -- 70 rather than SoDBaseDynamicOrder, so despite the comment "Sod will always load last"
      -- they applied *before* Era's faction fixes at 120. Deriving the window from the file's
      -- own expansion makes that class of mistake unrepresentable.
      local window = spec.window or register.WindowFor(spec)

      if registerStatics then
        for offset, functionName in ipairs(spec.static or {}) do
          if type(module[functionName]) == "function" then
            local entry = registry.RegisterCorrection(registry.OWNER, spec.datatype,
              spec.file .. ":" .. functionName,
              wrap(module, functionName, spec.datatype),
              order[window .. "Static"] + (spec.generated and 1 or 10) + offset)
            entry.expansions = spec.expansions
            entry.minExpansionOrder = spec.minExpansionOrder
            -- Expansion-gated files start in their minimum expansion. Only ungated Era files
            -- need a separate source order in the manifest.
            entry.sourceExpansionOrder = spec.sourceExpansionOrder or spec.minExpansionOrder
            entry.options = spec.options
            registered = registered + 1
          end
        end
      end

      for offset, functionName in ipairs(spec.dynamic or {}) do
        if type(module[functionName]) == "function" then
          local entry = registry.RegisterRuntimeCorrection(registry.OWNER, spec.datatype,
            spec.file .. ":" .. functionName,
            wrap(module, functionName, spec.datatype),
            order[window .. "Dynamic"] + (spec.generated and 1 or 10) + offset)
          entry.expansions = spec.expansions
          entry.minExpansionOrder = spec.minExpansionOrder
          entry.options = spec.options
          registered = registered + 1
        end
      end
    end
    manifest[index].loaded = module ~= nil
  end

  return registered, skipped
end

---Returns the load-order window for one manifest entry.
---Variant windows follow their base database so SoD wins over Era and Titan wins over WotLK.
---@param spec table Correction manifest entry.
---@return string window
function register.WindowFor(spec)
  if spec.file:find("^Sod/") then return "SoD" end
  if spec.file:find("^Era/") then return "Era" end
  if spec.file:find("^Tbc/") then return "Tbc" end
  if spec.file:find("^Wotlk/") then return "Wotlk" end
  if spec.file:find("^Titan/") then return "Titan" end
  if spec.file:find("^Cata/") then return "Cata" end
  if spec.file:find("^MoP/") then return "MoP" end
  return "Era" -- Shared/, which applies to every flavor
end

LibQuestieDB.CorrectionRegister = register

return register
