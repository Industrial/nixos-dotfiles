-- src/read/baked.lua
--
-- Baked mode: entity reads resolve from CBOR rows in the TOC metadata store.
--
-- This file and src/read/source.lua are the only two places the modes diverge. Both provide
-- `readField(id, fieldIndex)` and `getAllIds()`. Baked mode also provides `scalarRow` and
-- `tableProducer` so shared.lua can cache one decoded Scalar row per touched entity while
-- retaining CBOR bytes for fresh table values on every read.

local ADDON_NAME, LibQuestieDB = ...

local codec = LibQuestieDB.Meta.codec
local concat = table.concat
local floor = math.floor
local Encoding = C_EncodingUtil

local baked = {}

-- `C_AddOns.GetAddOnMetadata` in a live client; the offline harness installs a stand-in with
-- the same signature. See emulator/metadata.lua and emulator/client.lua.
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata

---Read one stored value, reassembling a Chunked metadata value transparently.
---@param key string Base Metadata field key.
---@return string? value
local function getStored(key)
  local value = GetAddOnMetadata(ADDON_NAME, key)
  if not value then return nil end

  -- Base64 payloads never start with `~`; only a chunk header can. Avoid the pattern lookup
  -- on the ordinary entity and localization read paths.
  if value:byte(1) ~= 126 then return value end
  local parts = codec.chunkCount[value]
  if not parts then return value end

  local buffer = {}
  for i = 1, parts do
    local part = GetAddOnMetadata(ADDON_NAME, key .. "-" .. i)
    if not part then
      -- A truncated chunk set is corruption, not a missing value. Say so rather than
      -- silently returning a short string.
      error(("QuestieDB: metadata key %s declares %d parts but part %d is missing")
        :format(key, parts, i), 0)
    end
    buffer[i] = part
  end
  return concat(buffer)
end

baked.getStored = getStored

--- Build the Baked-mode backend for one entity type.
---@param meta table Entity meta from src/meta/<entity>Meta.lua
---@return table backend
function baked.CreateBackend(meta)
  local prefix = "X-" .. meta.metaPrefix
  local constantValues = meta.constantValues
  local tableBits = {}
  for fieldIndex = 1, meta.fieldCount do
    if meta.types[fieldIndex] == "table" then
      tableBits[fieldIndex] = 2 ^ (fieldIndex - 1)
    end
  end

  -- The ID header is the only eager entity decode. Existence checks stay plain table lookups
  -- after addon load, while Scalar rows and table values remain proportional to what is read.
  local encodedIds = getStored(prefix .. "IDS")
  if not encodedIds then error("QuestieDB: missing metadata key " .. prefix .. "IDS", 0) end
  local idList = Encoding.DeserializeCBOR(
    Encoding.DecompressString(Encoding.DecodeBase64(encodedIds), 1))
  local idMap = {}
  for index = 1, #idList do idMap[idList[index]] = true end

  local backend = { mode = "baked", hasScalarRows = true }

  ---Return a fresh Scalar row that the shared cache owns and may compose in place.
  ---This backend never retains or shares the decoded table.
  ---@param id number Entity ID.
  ---@return table? row
  function backend.scalarRow(id)
    local stored = getStored(prefix .. id .. "-S")
    if stored == nil then return nil end
    local row = Encoding.DeserializeCBOR(Encoding.DecodeBase64(stored))
    -- Constant fields reconstruct from schema defaults even if a stale or hand-written
    -- artifact places conflicting scalar slots in the row.
    if constantValues then
      for fieldIndex in pairs(constantValues) do row[fieldIndex] = nil end
    end
    return row
  end

  ---Read table presence from the Scalar row without touching the table's Metadata field.
  ---@param row table?
  ---@param fieldIndex number
  ---@return boolean
  local function tableIsPresent(row, fieldIndex)
    local bit = tableBits[fieldIndex]
    if not bit or not row or not row.p then return false end
    return floor(row.p / bit) % 2 == 1
  end

  ---Decode one uncached base field for GetRaw or the shared Source-compatible path.
  ---@param id number Entity ID.
  ---@param fieldIndex number
  ---@return any value
  function backend.readField(id, fieldIndex)
    if constantValues and constantValues[fieldIndex] ~= nil then return nil end

    local row = backend.scalarRow(id)
    if meta.types[fieldIndex] ~= "table" then
      return row and row[fieldIndex] or nil
    end
    if not tableIsPresent(row, fieldIndex) then return nil end

    local stored = getStored(prefix .. id .. "-" .. fieldIndex)
    if stored == nil then return nil end
    return Encoding.DeserializeCBOR(Encoding.DecodeBase64(stored))
  end

  ---Build the cached Producer for one present table field. Base64 decoding happens once;
  ---each Producer call performs a native CBOR decode and returns a fresh tree.
  ---@param id number Entity ID.
  ---@param fieldIndex number
  ---@param row table Decoded Scalar row carrying the Presence mask.
  ---@return function? producer
  function backend.tableProducer(id, fieldIndex, row)
    if constantValues and constantValues[fieldIndex] ~= nil then return nil end
    if not tableIsPresent(row, fieldIndex) then return nil end

    local stored = getStored(prefix .. id .. "-" .. fieldIndex)
    if stored == nil then return nil end
    local bytes = Encoding.DecodeBase64(stored)
    return function() return Encoding.DeserializeCBOR(bytes) end
  end

  ---Return the decoded ID header in list and existence-map forms.
  ---@return number[] ids
  ---@return table<number, boolean> idMap
  function backend.getAllIds()
    return idList, idMap
  end

  return backend
end

-- The artifact names its own flavor, so the correction block that loads after this file knows
-- which expansion's Dynamic Corrections apply without asking the client.
local flavorName = GetAddOnMetadata(ADDON_NAME, "X-Flavor")
LibQuestieDB.flavor = flavorName and LibQuestieDB.config.flavorByName[flavorName] or nil

LibQuestieDB.read = LibQuestieDB.read or {}
LibQuestieDB.read.baked = baked
LibQuestieDB.mode = "baked"

return baked
