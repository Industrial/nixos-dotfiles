--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]] ---

---@class CliqueAddon: AddonCore
local addon = select(2, ...)

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local useEncodingUtil = true

function addon:GetExportString()
    local data = addon.db.profile.bindings

    -- Default to the new encoding method, rather than libserialize/libdeflate
    if useEncodingUtil then
        local serialized = C_EncodingUtil.SerializeJSON(data)
        local compressed = C_EncodingUtil.CompressString(serialized)
        local encoded = C_EncodingUtil.EncodeHex(compressed)
        return string.format("CL02:%s", encoded)
    else
        local serialized = LibSerialize:Serialize(data)
        local compressed = LibDeflate:CompressDeflate(serialized)
        local encoded = LibDeflate:EncodeForPrint(compressed)

        return string.format("CL01:%s", encoded)
    end
end

function addon:DecodeExportString(text)
    local header = string.sub(text, 1, 5)
    local payload = string.sub(text, 6, string.len(text))

    -- Legacy method using LibSerialize and LibDeflate
    if header == "CL01:" then
        local decoded = LibDeflate:DecodeForPrint(payload)
        if not decoded then return end
        local decompressed = LibDeflate:DecompressDeflate(decoded)
        if not decompressed then return end
        local success, data = LibSerialize:Deserialize(decompressed)
        if not success then return end
        return data

    -- Using C_EncodingUtil for speed and support
    elseif header == "CL02:" then
        local decoded = C_EncodingUtil.DecodeHex(payload)
        local decompressed = C_EncodingUtil.DecompressString(decoded)
        local data = C_EncodingUtil.DeserializeJSON(decompressed)
        return data
    end
end
