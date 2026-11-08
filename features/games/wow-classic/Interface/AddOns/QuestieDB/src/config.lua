-- src/config.lua
--
-- Shared configuration for the QuestieDB addon and its offline generator.
--
-- This file is dual-mode: the WoW client loads it as an addon file (where `...` is
-- `addonName, addonTable`), and the offline tooling loads it with `dofile` (where `...` is
-- empty and the return value is used). Every file under src/ that the generator also needs
-- follows this pattern.

local _, LibQuestieDB = ...

local config = {}

config.addonName = "QuestieDB"

--- Bumped when the shape of the public API or the storage format changes in a way a consumer
--- can observe. Questie checks this at init and fails with a specific message on mismatch.
config.contractVersion = 4

--- The oldest consumer contract this release still honors. `RequireContract` passes any
--- required version in [minSupportedContract, contractVersion]; raise this floor only when a
--- breaking change genuinely abandons older consumers (ADR 0003 D12).
config.minSupportedContract = 1

-- Generation and the loaded addon share this gate; invalid ranges must never be published.
for _, field in ipairs({ "contractVersion", "minSupportedContract" }) do
  local value = config[field]
  if type(value) ~= "number" or value < 1 or value % 1 ~= 0 then
    error("QuestieDB: " .. field .. " must be a positive integer", 0)
  end
end
if config.minSupportedContract > config.contractVersion then
  error("QuestieDB: minSupportedContract must not exceed contractVersion", 0)
end

--- Values longer than this many bytes are stored as a Chunked metadata value.
--- See docs/storage-format.md.
config.maxValueLength = 1000

--------------------------------------------------------------------------------------------
-- Client flavors
--------------------------------------------------------------------------------------------
--
-- `suffix` is the client TOC suffix, including its separator. The client searches for flavour-suffixed TOCs
-- first and falls back to the base `QuestieDB.toc` only if none are found, which is what
-- selects Baked mode over Source mode at no cost.
--
-- `expansion` is the directory under data/ holding this flavor's raw entity data.
-- `dataPrefix` is the filename prefix inside that directory.
-- `rules` selects legacy ordering and fallback constants, not authored input ownership.
-- Flavor-specific constant tables take precedence over that fallback.
-- `gameType` is the default native persona; `gameTypeAliases` adds names for the same flavor.
-- `aliases` names byte-identical Baked TOCs, independently of native file-condition tokens.
-- `interface` records the supported client Interface values.

---Legacy rules ordering, not flavor ownership. Forever selects Classic through `rules`.
---@type table<string, integer>
config.expansionOrder = { Classic = 1, TBC = 2, Wotlk = 3, Cata = 4, MoP = 5 }

config.flavors = {
  { name = "Vanilla", suffix = "_Vanilla", expansion = "Classic", dataPrefix = "classic", rules = "Classic", gameType = "vanilla", interface = "11508, 11509" },
  { name = "TBC",     suffix = "_TBC",     expansion = "TBC",     dataPrefix = "tbc",     rules = "TBC", gameType = "tbc", interface = "20506" },
  { name = "Wrath",   suffix = "_Wrath",   expansion = "Wotlk",   dataPrefix = "wotlk",   rules = "Wotlk", gameType = "wrath", interface = "30405, 38000, 38001, 38002" },
  { name = "Cata",    suffix = "_Cata",    expansion = "Cata",    dataPrefix = "cata",    rules = "Cata", gameType = "cata", interface = "40402" },
  { name = "Mists",   suffix = "_Mists",   expansion = "MoP",     dataPrefix = "mop",     rules = "MoP", gameType = "mists", interface = "50503, 50504" },
  { name = "Forever", suffix = "_Forever", aliases = { "_Camelot" }, expansion = "Forever", dataPrefix = "forever", rules = "Classic", gameType = "camelot", gameTypeAliases = { "forever" }, interface = "16001" },
}

config.flavorByName = {}
for _, flavor in ipairs(config.flavors) do
  config.flavorByName[flavor.name] = flavor
end

--------------------------------------------------------------------------------------------
-- Entity types
--------------------------------------------------------------------------------------------
--
-- `name` is the Entity global's base name — `Quest` becomes `LibQuestieDB.Quest` and the
-- `QuestDB` global alias.
-- `keysField` / `dataField` are the names the owned entity data files use.
-- `metaPrefix` is the per-type key prefix inside the combined TOC metadata store; see
-- docs/storage-format.md, "Combined-addon prefix".

config.entityTypes = {
  { name = "Quest",  keysField = "questKeys",  dataField = "questData",  metaPrefix = "Quest-",  fileSuffix = "QuestDB" },
  { name = "Npc",    keysField = "npcKeys",    dataField = "npcData",    metaPrefix = "Npc-",    fileSuffix = "NpcDB" },
  { name = "Item",   keysField = "itemKeys",   dataField = "itemData",   metaPrefix = "Item-",   fileSuffix = "ItemDB" },
  { name = "Object", keysField = "objectKeys", dataField = "objectData", metaPrefix = "Object-", fileSuffix = "ObjectDB" },
}

config.entityTypeByName = {}
for _, entityType in ipairs(config.entityTypes) do
  config.entityTypeByName[entityType.name] = entityType
end

--------------------------------------------------------------------------------------------
-- Localization
--------------------------------------------------------------------------------------------
--
-- enUS is deliberately absent: base entity data is already English, so the l10n store carries
-- only translations. Keep this order stable so generated blocks remain byte-identical.

config.locales = { "deDE", "esES", "esMX", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }
-- Raw lookup directories under l10n/<expansion>/, loaded directly only in Source mode.
config.l10nLookupDirs = { "lookupQuests", "lookupNpcs", "lookupItems", "lookupObjects" }

config.l10nVersion = 1
config.l10nHeaderKey = "X-l10n-Version"
config.l10nMetaPrefix = "l10n-"

---Storage key for one locale and entity type's compressed localization columns.
---@param typeName string
---@param locale string
---@return string key
function config.l10nBlockKey(typeName, locale)
  -- A key ending in `-deDE` is interpreted as a localized TOC directive and disappears on an
  -- enUS client. Keep the entity type last so every locale's block remains directly addressable.
  return "X-" .. config.l10nMetaPrefix .. locale .. "-" .. typeName
end

--------------------------------------------------------------------------------------------
-- Addon file lists
--------------------------------------------------------------------------------------------
--
-- `src/read/` is the only place the two modes diverge, so the two lists differ by one file
-- plus, for Source mode, the raw entity data.

config.runtimeFiles = {
  head = {
    "src/config.lua",
    "src/meta/normalize.lua",
    "src/meta/codec.lua",
    "src/meta/questMeta.lua",
    "src/meta/npcMeta.lua",
    "src/meta/itemMeta.lua",
    "src/meta/objectMeta.lua",
    "src/corrections/tablePatch.lua",
  },
  bakedReader = "src/read/baked.lua",
  sourceReader = "src/read/source.lua",
  tail = {
    "src/l10n/overlay.lua",
    "src/l10n/Titan/zhCN.lua",
    "src/ui/modeIndicator.lua",
    "src/api.lua",
    "src/support/eraToForever.lua",
  },
}

-- The initializer must precede the subject files in both TOCs and offline loaders.
config.enumFiles = {
  "src/corrections/enum/constants.lua",
  "src/corrections/enum/items.lua",
  "src/corrections/enum/quests.lua",
  "src/corrections/enum/professions.lua",
  "src/corrections/enum/factions.lua",
  "src/corrections/enum/zones.lua",
  "src/corrections/enum/phases.lua",
  "src/corrections/enum/icons.lua",
  "src/corrections/enum/waypoints.lua",
  "src/corrections/enum/expansions.lua",
}

-- Independently maintained providers are not import destinations.
config.ownedCorrections = {
  -- Inherited baseline: preserve its ordering; add new work in forever*Fixes.lua below.
  { owned = 'Forever', file = 'Forever/legacy/classicQuestFixes.lua', module = 'QuestieQuestFixes', datatype = 'Quest', static = {'Load'}, dynamic = {'LoadFactionFixes'}, sourceExpansionOrder = 1, window = 'Era' },
  { owned = 'Forever', file = 'Forever/legacy/classicNPCFixes.lua', module = 'QuestieNPCFixes', datatype = 'Npc', static = {'Load'}, dynamic = {'LoadFactionFixes'}, sourceExpansionOrder = 1, window = 'Era' },
  { owned = 'Forever', file = 'Forever/legacy/classicItemFixes.lua', module = 'QuestieItemFixes', datatype = 'Item', static = {'Load'}, dynamic = {'LoadFactionFixes'}, sourceExpansionOrder = 1, window = 'Era' },
  { owned = 'Forever', file = 'Forever/legacy/classicObjectFixes.lua', module = 'QuestieObjectFixes', datatype = 'Object', static = {'Load'}, dynamic = {'LoadFactionFixes'}, sourceExpansionOrder = 1, window = 'Era' },
  { owned = 'Forever', file = 'Forever/legacy/classicQuestReputationFixes.lua', module = 'QuestieClassicQuestReputationFixes', datatype = 'Quest', static = {'Load'}, expansions = {['Forever']=true}, generated = true, window = 'Era' },
  { owned = 'Forever', file = 'Forever/legacy/itemStartFixes.lua', module = 'QuestieItemStartFixes', datatype = 'Item', static = {'LoadAutomaticQuestStarts'}, options = {['noNewEntries']=true,['noOverwrites']=true}, generated = true, window = 'Era' },
  -- Generated delta-base follows all inherited Static Corrections, before traces and authored fixes.
  { owned = 'Forever', file = 'Forever/generated/foreverBaseNpc.lua', module = 'ForeverBaseNpc', datatype = 'Npc', static = {'Load'}, generated = true, window = 'ForeverDeltaBase' },
  { owned = 'Forever', file = 'Forever/generated/foreverBaseObject.lua', module = 'ForeverBaseObject', datatype = 'Object', static = {'Load'}, generated = true, window = 'ForeverDeltaBase' },
  { owned = 'Forever', file = 'Forever/generated/foreverBaseQuest.lua', module = 'ForeverBaseQuest', datatype = 'Quest', static = {'Load'}, generated = true, window = 'ForeverDeltaBase' },
  { owned = 'Forever', file = 'Forever/generated/foreverBaseItem.lua', module = 'ForeverBaseItem', datatype = 'Item', static = {'Load'}, generated = true, window = 'ForeverDeltaBase' },
  -- Machine-generated from player traces (tools/trace-analyzer); never hand-edited. Applies
  -- after the generated delta-base and before authored forever*Fixes.lua, which may override it.
  { owned = 'Forever', file = 'Forever/traces/foreverQuestTraces.lua', module = 'ForeverQuestTraces', datatype = 'Quest', static = {'Load'}, generated = true, window = 'Forever' },
  { owned = 'Forever', file = 'Forever/traces/foreverNpcTraces.lua', module = 'ForeverNpcTraces', datatype = 'Npc', static = {'Load'}, generated = true, window = 'Forever' },
  { owned = 'Forever', file = 'Forever/traces/foreverItemTraces.lua', module = 'ForeverItemTraces', datatype = 'Item', static = {'Load'}, generated = true, window = 'Forever' },
  { owned = 'Forever', file = 'Forever/traces/foreverObjectTraces.lua', module = 'ForeverObjectTraces', datatype = 'Object', static = {'Load'}, generated = true, window = 'Forever' },
  -- Authored Forever corrections follow legacy, generated base and trace data; Dynamic precedence is unchanged.
  { owned = 'Forever', file = 'Forever/foreverQuestFixes.lua', module = 'ForeverQuestFixes', datatype = 'Quest', static = {'Load'}, dynamic = {'LoadDynamic'}, window = 'Forever' },
  { owned = 'Forever', file = 'Forever/foreverNPCFixes.lua', module = 'ForeverNpcFixes', datatype = 'Npc', static = {'Load'}, dynamic = {'LoadDynamic'}, window = 'Forever' },
  { owned = 'Forever', file = 'Forever/foreverItemFixes.lua', module = 'ForeverItemFixes', datatype = 'Item', static = {'Load'}, dynamic = {'LoadDynamic'}, window = 'Forever' },
  { owned = 'Forever', file = 'Forever/foreverObjectFixes.lua', module = 'ForeverObjectFixes', datatype = 'Object', static = {'Load'}, dynamic = {'LoadDynamic'}, window = 'Forever' },
}

---Whether a provider belongs to a flavor. Forever owns providers rather than inheriting legacy ones.
---@param spec table Correction manifest entry.
---@param flavor table Configured flavor.
---@return boolean
function config.correctionApplies(spec, flavor)
  if not flavor then return false end
  if spec.owned then return spec.owned == flavor.name end
  if flavor.name == "Forever" then return false end
  return (not spec.expansions or spec.expansions[flavor.expansion] == true) and
    (not spec.minExpansionOrder or (config.expansionOrder[flavor.expansion] or 0) >= spec.minExpansionOrder)
end

---Resolved correction block for one flavor; native selection uses this same applicability.
---@param flavor table
---@param mode string
---@return string[]
function config.correctionFiles(flavor, mode)
  if not config.correctionManifest then return {} end
  local files = {}
  for _, file in ipairs(config.enumFiles) do files[#files + 1] = file end
  for _, file in ipairs({ "src/corrections/compat.lua", "src/corrections/register.lua", "src/corrections/_begin.lua" }) do
    files[#files + 1] = file
  end
  local seasonal
  for _, spec in ipairs(config.correctionManifest) do
    if config.correctionApplies(spec, flavor) and
       (mode ~= "baked" or (spec.dynamic and #spec.dynamic > 0)) then
      local scope = spec.file:match("^(Sod)/") or spec.file:match("^(Titan)/")
      if seasonal ~= scope then
        files[#files + 1] = "src/corrections/scopes/" .. (scope or (seasonal .. "End")) .. ".lua"
        seasonal = scope
      end
      files[#files + 1] = "src/corrections/" .. spec.file
    end
  end
  files[#files + 1] = "src/corrections/manifest.lua"
  files[#files + 1] = "src/corrections/_end.lua"
  return files
end

--- The derived-pass block, bracketed by the files that install and remove its loader shim.
---
--- Source mode only. Baked artifacts never list these files: Generation already applied every
--- pass before encoding, exactly as it already folded in Static Corrections, so a baked client
--- would be re-running a transform over data that has had it (ADR 0004 D3).
config.derivedFiles = {
  "src/derived/registry.lua",
  "src/derived/_begin.lua",
  "src/derived/RamerDouglasPeucker.lua",
  "src/derived/requiredRaces.lua",
  "src/derived/waypoints.lua",
  "src/derived/_end.lua",
}

--------------------------------------------------------------------------------------------
-- Support data
--------------------------------------------------------------------------------------------
--
-- Baked TOCs select one flavor here. The base Source TOC lists each payload once,
-- with native conditions so another flavor never executes its payload assignments.

config.supportData = {
  shared = {
    "support/Zones/dungeons.lua",
    "support/Zones/subZoneToParentZone.lua",
    "support/Zones/instanceIdToAreaId.lua",
    "support/DropTables/itemDropCorrections.lua",
  },
  perFlavor = {
    Vanilla = {
      "support/Zones/areaIdToUiMapId.lua", "support/Zones/uiMapIdToAreaId.lua",
      "support/QuestXP/xpDB-classic.lua", "support/FactionTemplates/factionTemplateClassic.lua",
      "support/DropTables/classicItemDrops.lua",
    },
    TBC = {
      "support/Zones/areaIdToUiMapId.lua", "support/Zones/uiMapIdToAreaId.lua",
      "support/QuestXP/xpDB-tbc.lua", "support/FactionTemplates/factionTemplateTBC.lua",
      "support/DropTables/tbcItemDrops.lua",
    },
    Wrath = {
      "support/Zones/areaIdToUiMapId.lua", "support/Zones/uiMapIdToAreaId.lua",
      "support/QuestXP/xpDB-wotlk.lua", "support/FactionTemplates/factionTemplateWotlk.lua",
      "support/DropTables/wotlkItemDrops.lua",
    },
    Cata = {
      "support/Zones/areaIdToUiMapId.lua", "support/Zones/uiMapIdToAreaId.lua",
      "support/QuestXP/xpDB-cata.lua", "support/FactionTemplates/factionTemplateCata.lua",
      "support/DropTables/cataItemDrops.lua",
    },
    -- Mists uses its own zone maps, and loads Cata's drop table alongside its own, exactly as
    -- Questie-Mists.toc does.
    Mists = {
      "support/Zones/MoP/areaIdToUiMapId.lua", "support/Zones/MoP/uiMapIdToAreaId.lua",
      "support/QuestXP/xpDB-mop.lua", "support/FactionTemplates/factionTemplateMoP.lua",
      "support/DropTables/mopItemDrops.lua", "support/DropTables/cataItemDrops.lua",
    },
  },
}

-- These paths are explicit: future Era additions must not silently become Forever inputs.
config.supportData.perFlavor.Forever = {
  "support/Forever/Zones/dungeons.lua", "support/Forever/Zones/subZoneToParentZone.lua",
  "support/Forever/Zones/instanceIdToAreaId.lua",
  "support/Forever/DropTables/itemDropCorrections.lua",
  "support/Forever/Zones/areaIdToUiMapId.lua", "support/Forever/Zones/uiMapIdToAreaId.lua",
  "support/Forever/QuestXP/xpDB-classic.lua", "support/Forever/FactionTemplates/factionTemplateClassic.lua",
  "support/Forever/DropTables/classicItemDrops.lua",
}

---@param flavor table
---@return string[] Resolved support paths in load order.
function config.supportFiles(flavor)
  assert(flavor, "supportFiles requires a flavor")
  local files = {}
  for _, file in ipairs(config.enumFiles) do files[#files + 1] = file end
  files[#files + 1] = "src/support/data.lua"
  files[#files + 1] = "src/support/_begin.lua"
  if flavor.name ~= "Forever" then
    for _, file in ipairs(config.supportData.shared) do files[#files + 1] = file end
  end
  for _, file in ipairs(config.supportData.perFlavor[flavor.name]) do files[#files + 1] = file end
  files[#files + 1] = "src/support/_end.lua"
  return files
end

--- Append `source` to `target`, skipping anything already listed.
---
--- Each block declares its own prerequisites — the support block and the correction block both
--- need `config.enumFiles`, and neither can assume the other ran. Composing here is what
--- makes that safe: the client rejects a file listed twice with
--- `Duplicate File Load Detected`, and rebuilding the constants would invalidate references
--- captured by earlier files even if the client allowed it.
---
--- First occurrence wins, because a block's prerequisites are listed ahead of it and the
--- earliest position is the one that satisfies every later block.
local function append(target, source, seen)
  for _, file in ipairs(source) do
    if not seen[file] then
      seen[file] = true
      target[#target + 1] = file
    end
  end
  return target
end

--- Files a generated flavour TOC lists, in load order.
function config.bakedFileList(flavor)
  local files, seen = {}, {}
  append(files, config.runtimeFiles.head, seen)
  append(files, { config.runtimeFiles.bakedReader }, seen)
  append(files, config.supportFiles(flavor), seen)
  append(files, { "src/read/shared.lua", "src/corrections/registry.lua" }, seen)
  append(files, config.correctionFiles(flavor, "baked"), seen)
  -- Authored SoD data is owned here, outside the copied-provider manifest.
  if config.correctionManifest and flavor.expansion == "Classic" then
    append(files, { "src/corrections/Sod/sodRequiredRaces.lua" }, seen)
  end
  append(files, config.runtimeFiles.tail, seen)
  return files
end

---Source entries keep paths separate from applicability and merge each path once.
---The phase order matters: all payloads must finish before their shim is removed.
---@return table[] entries Each entry has path and gameTypes (an ordered token list).
function config.sourceFileEntries()
  local entries, byPath = {}, {}
  ---@param path string
  ---@param flavor table? Nil means unconditional.
  ---@return nil
  local function add(path, flavor)
    local entry = byPath[path]
    if not entry then
      entry = { path = path, gameTypes = {} }
      entries[#entries + 1], byPath[path] = entry, entry
    end
    if flavor then
      for _, token in ipairs(entry.gameTypes) do if token == flavor.gameType then return end end
      entry.gameTypes[#entry.gameTypes + 1] = flavor.gameType
      for _, alias in ipairs(flavor.gameTypeAliases or {}) do
        entry.gameTypes[#entry.gameTypes + 1] = alias
      end
    end
  end
  for _, path in ipairs(config.runtimeFiles.head) do add(path) end
  for _, flavor in ipairs(config.flavors) do add("src/flavors/" .. flavor.name .. ".lua", flavor) end
  add(config.runtimeFiles.sourceReader)
  for _, flavor in ipairs(config.flavors) do
    for _, entity in ipairs(config.entityTypes) do add(config.dataPath(flavor, entity), flavor) end
  end
  add("data/_end.lua")
  -- Resolve support bodies separately so shared teardown cannot precede another flavor's data.
  for _, path in ipairs(config.enumFiles) do add(path) end
  for _, path in ipairs({ "src/support/data.lua", "src/support/_begin.lua" }) do add(path) end
  -- Mists precedes Cata so its cumulative drop tables keep the MoP-then-Cata ordering.
  for _, name in ipairs({ "Vanilla", "TBC", "Wrath", "Mists", "Cata", "Forever" }) do
    local flavor = config.flavorByName[name]
    for _, path in ipairs(config.supportFiles(flavor)) do
      if path:match("^support/") then add(path, flavor) end
    end
  end
  add("src/support/_end.lua")
  add("src/read/shared.lua")
  add("src/corrections/registry.lua")
  if config.correctionManifest then
    for _, path in ipairs({ "src/corrections/compat.lua", "src/corrections/register.lua", "src/corrections/_begin.lua" }) do add(path) end
    local seasonal
    for _, spec in ipairs(config.correctionManifest) do
      local scope = spec.file:match("^(Sod)/") or spec.file:match("^(Titan)/")
      if scope ~= seasonal then
        add("src/corrections/scopes/" .. (scope or (seasonal .. "End")) .. ".lua")
        seasonal = scope
      end
      for _, flavor in ipairs(config.flavors) do
        if config.correctionApplies(spec, flavor) then add("src/corrections/" .. spec.file, flavor) end
      end
    end
    add("src/corrections/manifest.lua")
    add("src/corrections/_end.lua")
    add("src/corrections/Sod/sodRequiredRaces.lua", config.flavorByName.Vanilla)
  end
  for _, path in ipairs(config.derivedFiles) do add(path) end
  -- Source mode loads the raw lookups; their locale guards keep only the client locale.
  add("src/l10n/source/_begin.lua")
  for _, flavor in ipairs(config.flavors) do
    for _, dir in ipairs(config.l10nLookupDirs) do
      for _, locale in ipairs(config.locales) do
        add(("l10n/%s/%s/%s.lua"):format(flavor.expansion, dir, locale), flavor)
      end
    end
  end
  add("src/l10n/source/_traces.lua")
  -- Trace files are optional per type and locale; list those present when the TOC is generated.
  for _, dir in ipairs(config.l10nLookupDirs) do
    for _, locale in ipairs(config.locales) do
      local path = ("l10n/Forever/traces/%s/%s.lua"):format(dir, locale)
      local file = io and io.open(path, "r")
      if file then
        file:close()
        add(path, config.flavorByName.Forever)
      end
    end
  end
  for _, name in ipairs({ "TBC", "Wrath", "Cata", "Mists" }) do
    add("l10n/lookupOverrides.lua", config.flavorByName[name])
  end
  add("src/l10n/source/_end.lua")
  for _, path in ipairs(config.runtimeFiles.tail) do add(path) end
  return entries
end

---Rendered native file lines, or resolved paths for an explicit offline flavor.
---@param flavor table? Nil emits conditions.
---@return string[]
function config.sourceFileList(flavor)
  local files = {}
  for _, entry in ipairs(config.sourceFileEntries()) do
    local include = #entry.gameTypes == 0
    for _, token in ipairs(entry.gameTypes) do
      if flavor and token == flavor.gameType then include = true end
    end
    if not flavor then
      local condition = ""
      if #entry.gameTypes > 0 then
        local directive, tokens = "AllowLoadGameType", entry.gameTypes
        local forever = config.flavorByName.Forever
        if tokens[1] == forever.gameType and #tokens == 1 + #(forever.gameTypeAliases or {}) then
          -- An all-unknown allow list passes on older clients, loading Forever over TBC.
          -- Exclude known legacy types instead. Deliberately do not exclude mainline.
          directive = "ExcludeLoadGameType"
          tokens = { "vanilla", "tbc", "wrath", "cata", "mists" }
        end
        condition = " [" .. directive .. " " .. table.concat(tokens, ", ") .. "]"
      end
      files[#files + 1] = entry.path .. condition
    elseif include then files[#files + 1] = entry.path end
  end
  return files
end

--- Every interface version QuestieDB supports, for the base TOC. A single comma-separated
--- list is what lets one committed TOC load on any supported client, which is what source mode
--- needs — a fresh clone has no suffixed TOC to match.
function config.allInterfaceVersions()
  local seen, parts = {}, {}
  for _, flavor in ipairs(config.flavors) do
    for version in flavor.interface:gmatch("%d+") do
      if not seen[version] then
        seen[version] = true
        parts[#parts + 1] = version
      end
    end
  end
  return table.concat(parts, ", ")
end

--------------------------------------------------------------------------------------------
-- Paths (offline generation only)
--------------------------------------------------------------------------------------------

config.paths = {
  data = "data",
  support = "support",
  meta = "src/meta",
  l10n = "l10n",
}

--- Raw entity data file for one flavor and entity type, relative to the repo root.
function config.dataPath(flavor, entityType)
  return config.paths.data .. "/" .. flavor.expansion .. "/" .. flavor.dataPrefix .. entityType.fileSuffix .. ".lua"
end

--- Generated TOC filename for one flavor.
function config.tocPath(flavor)
  return config.addonName .. flavor.suffix .. ".toc"
end

if LibQuestieDB then
  LibQuestieDB.config = config
end

return config
