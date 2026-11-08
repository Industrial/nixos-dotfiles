--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- Waypoint sharing through addon messages.

local addonName, addon = ...
local TomTom = addon
local L = addon.L
local hbd = addon.hbd
addon.private = addon.private or {}
local private = addon.private

-- Sharing has no setting: TomTom always accepts shared waypoints (D10).
local module = {
    IsEnabledInSettings = function() return true end,
}
private.AddModule(module, "Comm")

-- Since we are now using just (map, x, y), register a new protocol number
local COMM_PREFIX = "TOMTOM4"
-- Addon messages have a limit of 255 bytes. The API documentation does not
-- give the limit. We also subtract the prefix length, to be safe.
local COMM_MAX_MESSAGE = 255 - #COMM_PREFIX

-- Cut a string to at most maxBytes bytes without splitting a UTF-8 character.
local function TruncateUTF8(str, maxBytes)
    if #str <= maxBytes then return str end
    if maxBytes <= 0 then return "" end
    local cut = maxBytes
    -- A byte of the form 10xxxxxx continues a character; cut before the lead byte.
    while cut > 0 do
        local byte = str:byte(cut + 1)
        if byte < 0x80 or byte >= 0xC0 then break end
        cut = cut - 1
    end
    return str:sub(1, cut)
end

-- All supported clients return a SendAddonMessageResult value. The checks
-- for a boolean or no value protect against a change in the API. Only a
-- clear failure counts as a failure.
-- Returns the failure code and a name for it, or nil on success.
local function GetSendFailure(result)
    local resultEnum = Enum and Enum.SendAddonMessageResult
    if type(result) == "number" then
        if result == (resultEnum and resultEnum.Success or 0) then return nil end
        for name, value in pairs(resultEnum or {}) do
            if value == result then return result, name end
        end
        return result, tostring(result)
    elseif result == false then
        return result, "false"
    end
    return nil
end

function TomTom:SendWaypoint(uid, channel)
    if type(uid) ~= "table" then error("TomTom:SendWaypoint(uid) UID is not a table."); end
    local data = uid
    local m, x, y = unpack(data)
    local header = string.format("%d:%f:%f:", m, x, y)
    local maxTitle = COMM_MAX_MESSAGE - #header
    local title = tostring(data.title or "")
    if #title > maxTitle then
        -- A cut inside a color, texture or link code breaks the receiver's
        -- chat line. Remove these codes before the cut. Keep the link text.
        title = title:gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1")
            :gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        title = TruncateUTF8(title, maxTitle)
    end
    local result = C_ChatInfo.SendAddonMessage(COMM_PREFIX, header .. title, channel)

    local failure, failureName = GetSendFailure(result)
    if failureName == nil then return end

    local lockdown = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.AddOnMessageLockdown
    if lockdown and failure == lockdown then
        ChatFrame1:AddMessage(L["|cffffff78TomTom|r: Could not send the waypoint. The game blocks addon messages inside instances."])
    else
        ChatFrame1:AddMessage(string.format(L["|cffffff78TomTom|r: Could not send the waypoint (error: %s)."], failureName))
    end
end

function TomTom:CHAT_MSG_ADDON(event, prefix, data, channel, sender)
    if prefix ~= COMM_PREFIX then return end
    -- The game can send the name as "Name-Realm", but UnitName returns "Name" only.
    if Ambiguate(sender, "none") == UnitName("player") then return end

    -- The title is the rest of the message, so it can contain ":".
    local m, x, y, title = string.match(data, "^([^:]+):([^:]+):([^:]+):(.*)$")
    m = tonumber(m)
    x = tonumber(x)
    y = tonumber(y)
    if not (m and x and y) then return end
    -- A map ID is a positive whole number. NaN fails the first test.
    if m ~= math.floor(m) or m <= 0 or m == math.huge then return end
    if x ~= x or y ~= y or math.abs(x) == math.huge or math.abs(y) == math.huge then return end

    if not title:match("%S") then
        title = string.format(L["Waypoint from %s"], sender)
    end

    local zoneName = hbd:GetLocalizedMap(m) or L["Unnamed Map"]
    self:AddWaypoint(m, x, y, {title = title, from=("TomTom/"..sender)})
    local msg = string.format(L["|cffffff78TomTom|r: Added '%s' (sent from %s) to zone %s"], title, sender, zoneName)
    ChatFrame1:AddMessage(msg)
end

function module:OnEnable()
    C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
    self:RegisterEvent("CHAT_MSG_ADDON")
end

function module:OnDisable()
    self:UnregisterEvent("CHAT_MSG_ADDON")
end

function module:CHAT_MSG_ADDON(...)
    TomTom:CHAT_MSG_ADDON(...)
end
