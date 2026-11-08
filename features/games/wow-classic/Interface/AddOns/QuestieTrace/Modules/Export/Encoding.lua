---@class QuestieTraceCore
local Core = QuestieTraceCore

---------------------------------------------------------------------------
-- Encoding (CBOR + compression + print-safe encoding)
---------------------------------------------------------------------------
-- Handles serialization of payload tables into compressed, print-safe strings.
-- Pipeline: Lua table -> CBOR -> Deflate compress -> EncodeForPrint
---------------------------------------------------------------------------

-- LibDeflate for print-safe encoding of compressed binary payloads.
---@type LibDeflate
local LibDeflate = LibStub("LibDeflate", true)

---------------------------------------------------------------------------
-- Encoding support checking
---------------------------------------------------------------------------

--- Check whether the client has the required compression and encoding APIs.
--- Every supported WoW client should have these; if missing, fail loudly.
---@return boolean
function Core.HasCodecSupport()
  local hasBlizzardEncoding = C_EncodingUtil ~= nil
    and C_EncodingUtil.SerializeCBOR ~= nil
    and C_EncodingUtil.DeserializeCBOR ~= nil
    and C_EncodingUtil.CompressString ~= nil
    and C_EncodingUtil.DecompressString ~= nil

  local hasDeflateEnums = Enum ~= nil
    and Enum.CompressionMethod ~= nil
    and Enum.CompressionMethod.Deflate ~= nil
    and Enum.CompressionLevel ~= nil
    and Enum.CompressionLevel.Default ~= nil

  local hasLibDeflate = LibDeflate ~= nil
    and LibDeflate.EncodeForPrint ~= nil
    and LibDeflate.DecodeForPrint ~= nil

  return hasBlizzardEncoding and hasDeflateEnums and hasLibDeflate
end

---------------------------------------------------------------------------
-- Encoding/Decoding
---------------------------------------------------------------------------

--- Encode a payload table into a compressed, print-safe string.
--- Pipeline: Lua table -> CBOR -> Deflate compress -> EncodeForPrint
---@param payload table
---@return string? encodedPayload Nil if codec support is missing or encoding fails.
---@return string? err Failure reason when encoding was attempted but failed. Nil if codec support is missing.
function Core.EncodeExportPayload(payload)
  if (not Core.HasCodecSupport()) then
    return nil
  end

  local ok, encoded = pcall(function()
    local cbor = C_EncodingUtil.SerializeCBOR(payload)
    local compressed = C_EncodingUtil.CompressString(cbor, Enum.CompressionMethod.Deflate, Enum.CompressionLevel.Default)
    return LibDeflate:EncodeForPrint(compressed)
  end)

  if ok and type(encoded) == "string" then
    return encoded
  end

  if (not ok) then
    local stringOk, message = pcall(tostring, encoded)
    if stringOk and type(message) == "string" then
      return nil, message
    end
    return nil, "unknown error"
  end

  return nil, "unexpected result type: " .. type(encoded)
end

--- Decode a string built by Core.EncodeExportPayload back into a table.
---@param encoded string
---@return table? payload Nil if codec support is missing or decoding fails.
function Core.DecodeExportPayload(encoded)
  if (not Core.HasCodecSupport()) then
    return nil
  end

  local ok, decoded = pcall(function()
    local compressed = LibDeflate:DecodeForPrint(encoded)
    local cbor = C_EncodingUtil.DecompressString(compressed, Enum.CompressionMethod.Deflate)
    return C_EncodingUtil.DeserializeCBOR(cbor)
  end)

  if ok and type(decoded) == "table" then
    return decoded
  end

  return nil
end
