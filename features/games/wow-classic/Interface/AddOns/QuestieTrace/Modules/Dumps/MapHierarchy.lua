---@type QuestieTraceCore
local Core = QuestieTraceCore

---@type number
local MAP_DUMP_SCHEMA_VERSION = 1
---@type number[]
local MAP_DUMP_ROOT_SEEDS = { 947, 1414, 1415 }

--- Append a map ID once.
---@param list number[]
---@param seen table<number, boolean>
---@param mapID any
local function AddUniqueMapID(list, seen, mapID)
  if type(mapID) ~= "number" or mapID <= 0 or seen[mapID] then return end
  seen[mapID] = true
  list[#list + 1] = mapID
end

--- Build a unique list of top-level candidate maps by walking each seed map up to parentMapID=0.
---@param seedMapIDs number[]
---@return number[] topUiMapIDs
local function BuildTopUiMapIDs(seedMapIDs)
  ---@type number[]
  local topUiMapIDs = {}
  ---@type table<number, boolean>
  local seenTop = {}

  for i = 1, #seedMapIDs do
    ---@type number
    local mapID = seedMapIDs[i]
    while mapID > 0 and not seenTop[mapID] do
      seenTop[mapID] = true
      topUiMapIDs[#topUiMapIDs + 1] = mapID

      ---@type UiMapDetails?
      local info = C_Map.GetMapInfo(mapID)
      if not info or type(info.parentMapID) ~= "number" then
        break
      end
      mapID = info.parentMapID
    end
  end

  table.sort(topUiMapIDs)
  return topUiMapIDs
end

--- Build and persist the static C_Map hierarchy dump.
---@return boolean success
---@return string? warning
local function DumpMapHierarchy()
  ---@type number
  local fallbackWorldMapID = C_Map.GetFallbackWorldMapID()
  ---@type number[]
  local rootSeeds = {}
  ---@type table<number, boolean>
  local seedSeen = {}
  for i = 1, #MAP_DUMP_ROOT_SEEDS do
    AddUniqueMapID(rootSeeds, seedSeen, MAP_DUMP_ROOT_SEEDS[i])
  end
  AddUniqueMapID(rootSeeds, seedSeen, fallbackWorldMapID)

  ---@type number[]
  local topUiMapIDs = BuildTopUiMapIDs(rootSeeds)

  ---@type number[]
  local allMapIDs = {}
  ---@type table<number, boolean>
  local seenMapIDs = {}
  for i = 1, #topUiMapIDs do
    AddUniqueMapID(allMapIDs, seenMapIDs, topUiMapIDs[i])
    ---@type UiMapDetails[]
    local descendants = C_Map.GetMapChildrenInfo(topUiMapIDs[i], nil, true) or {}
    for j = 1, #descendants do
      AddUniqueMapID(allMapIDs, seenMapIDs, descendants[j].mapID)
    end
  end
  table.sort(allMapIDs)

  ---@type table<number, QuestieTraceMapEntry>
  local maps = {}
  ---@type number[]
  local mapsWithChildren = {}

  for i = 1, #allMapIDs do
    ---@type number
    local mapID = allMapIDs[i]
    ---@type UiMapDetails?
    local info = C_Map.GetMapInfo(mapID)
    ---@type QuestieTraceMapEntry
    local entry = {
      name = info and info.name or "Unknown",
      parentMapID = info and info.parentMapID or 0,
      mapType = info and info.mapType or 0,
      children = {},
    }

    ---@type UiMapDetails[]
    local children = C_Map.GetMapChildrenInfo(mapID) or {}
    ---@type table<number, boolean>
    local seenChildren = {}
    for j = 1, #children do
      AddUniqueMapID(entry.children, seenChildren, children[j].mapID)
    end
    table.sort(entry.children)
    if #entry.children > 0 then
      mapsWithChildren[#mapsWithChildren + 1] = mapID
    end

    if entry.parentMapID > 0 then
      ---@type number?, number?, number?, number?
      local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(mapID, entry.parentMapID)
      if minX and maxX and minY and maxY then
        entry.rect = {
          minX = minX,
          maxX = maxX,
          minY = minY,
          maxY = maxY,
        }
      end
    end

    maps[mapID] = entry
  end

  table.sort(mapsWithChildren)

  ---@type table<number, table<number, MapRectData>>
  local rectOnMap = {}
  for i = 1, #allMapIDs do
    ---@type number
    local mapID = allMapIDs[i]
    ---@type table<number, MapRectData>?
    local rectByTop = nil

    for j = 1, #mapsWithChildren do
      ---@type number
      local topUiMapID = mapsWithChildren[j]
      ---@type number?, number?, number?, number?
      local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(mapID, topUiMapID)
      if minX and maxX and minY and maxY then
        rectByTop = rectByTop or {}
        rectByTop[topUiMapID] = {
          minX = minX,
          maxX = maxX,
          minY = minY,
          maxY = maxY,
        }
      end
    end

    if rectByTop then
      rectOnMap[mapID] = rectByTop
    end
  end

  QuestieTraceDumps = type(QuestieTraceDumps) == "table" and QuestieTraceDumps or {}
  QuestieTraceDumps.schemaVersion = type(QuestieTraceDumps.schemaVersion) == "number" and QuestieTraceDumps.schemaVersion or 1
  QuestieTraceDumps.dumps = type(QuestieTraceDumps.dumps) == "table" and QuestieTraceDumps.dumps or {}

  ---@type MapHierarchyDumpData
  QuestieTraceDumps.dumps.map_hierarchy = {
    schemaVersion = MAP_DUMP_SCHEMA_VERSION,
    ---@diagnostic disable-next-line: assign-type-mismatch
    capturedAt = date("%Y-%m-%d_%H-%M-%S"),
    fallbackWorldMapID = fallbackWorldMapID,
    rootSeeds = rootSeeds,
    topUiMapIDs = topUiMapIDs,
    mapsWithChildren = mapsWithChildren,
    maps = maps,
    rectOnMap = rectOnMap,
  }

  Core.Debug("Map dump refreshed. maps:", #allMapIDs, "top maps:", #topUiMapIDs)
  return true
end

Core.RegisterDump({
  key = "map_hierarchy",
  helpText = "/qlt dumpmap - Refresh static C_Map hierarchy dump",
  slashCommands = { "dumpmap" },
  events = { "PLAYER_LOGIN" },
  Run = DumpMapHierarchy,
})
