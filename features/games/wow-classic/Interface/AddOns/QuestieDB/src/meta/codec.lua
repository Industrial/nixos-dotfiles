-- src/meta/codec.lua
--
-- Chunk-marker decoding for the TOC metadata store. Entity values and localization blocks
-- use C_EncodingUtil after src/read/baked.lua reassembles any numbered parts.

local _, LibQuestieDB = ...

local codec = {}

local tonumber = tonumber
local match = string.match

---Memoized `~N~` -> N. A chunk header is the only stored value of that exact shape.
codec.chunkCount = setmetatable({}, {
  __index = function(self, key)
    local count = match(key, "^~(%d+)~$")
    if count then
      count = tonumber(count)
      self[key] = count
      return count
    end
    return nil
  end,
})

-- Warm the common cases so the hot path never builds a pattern match.
for i = 1, 32 do codec.chunkCount["~" .. i .. "~"] = i end

if LibQuestieDB then
  LibQuestieDB.Meta = LibQuestieDB.Meta or {}
  LibQuestieDB.Meta.codec = codec
end

return codec
