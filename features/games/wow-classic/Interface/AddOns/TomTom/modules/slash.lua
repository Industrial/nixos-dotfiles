--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- Slash commands: /tomtom, /way, /cway and /wayb.

local addonName, addon = ...
local TomTom = addon
local L = addon.L
local hbd = addon.hbd
addon.private = addon.private or {}
local private = addon.private
local RoundCoords = private.RoundCoords
local NameToMapId = TomTom.NameToMapId

function TomTom:DebugListLocalWaypoints()
    local m,x,y = self:GetCurrentPlayerPosition()
    local ctxt = RoundCoords(x, y, 2)
    local czone = hbd:GetLocalizedMap(m) or L["Unnamed Map"]
    self:Printf(L["You are at (%s) in '%s' (map: %s)"], ctxt, czone , tostring(m))
    if TomTom.waypoints[m] then
        for key, wp in pairs(TomTom.waypoints[m]) do
            local ctxt = RoundCoords(wp[2], wp[3], 2)
            local desc = wp.title and wp.title or L["Unknown waypoint"]
            local indent = "   "
            self:Printf(L["%s%s - %s (map: %d)"], indent, desc, ctxt, wp[1])
        end
    else
        local indent = "   "
        self:Printf(L["%sNo waypoints in this zone"], indent)
    end
end

function TomTom:DebugListAllWaypoints()
    local m,x,y = self:GetCurrentPlayerPosition()
    local ctxt = RoundCoords(x, y, 2)
    local czone = hbd:GetLocalizedMap(m) or L["Unnamed Map"]
    self:Printf(L["You are at (%s) in '%s' (map: %s)"], ctxt, czone, tostring(m))
    for m in pairs(TomTom.waypoints) do
        local c,z,w = TomTom:GetCZWFromMapID(m)
        local zoneName = hbd:GetLocalizedMap(m) or L["Unnamed Map"]
        self:Printf(L["%s: (map: %d, zone: %s, continent: %s, world: %s)"], zoneName, m, tostring(z), tostring(c), tostring(w))
        for key, wp in pairs(TomTom.waypoints[m]) do
            local ctxt = RoundCoords(wp[2], wp[3], 2)
            local desc = wp.title and wp.title or L["Unknown waypoint"]
            local indent = "   "
            self:Printf(L["%s%s - %s %s %s %s"], indent, desc, ctxt, wp[1], (wp.minimap_icon or "*"), (wp.worldmap_icon or "*"))
        end
    end
end

local function usage()
    ChatFrame1:AddMessage(L["|cffffff78TomTom |r/way /tway /tomtomway /cway /wayb /wayback /ttpase /tomtom |cffffff78Usage:|r"])
    ChatFrame1:AddMessage(L["|cffffff78/tomtom |r - Open the TomTom options panel"])
    ChatFrame1:AddMessage(L["|cffffff78/ttpaste |r - Open a window to paste and execute multiple TomTom commands"])
    ChatFrame1:AddMessage(L["|cffffff78/cway |r - Activate the closest waypoint"])
    ChatFrame1:AddMessage(L["|cffffff78/wayb [desc] |r - Save the current position with optional description"])
    ChatFrame1:AddMessage(L["|cffffff78/way /tway /tomtomway |r - Commands to set a waypoint: one should work."])
    ChatFrame1:AddMessage(L["|cffffff78/way <x> <y> [desc]|r - Adds a waypoint at x,y with description desc"])
    ChatFrame1:AddMessage(L["|cffffff78/way <zone> <x> <y> [desc]|r - Adds a waypoint at x,y in zone with description desc"])
    ChatFrame1:AddMessage(L["|cffffff78/way reset all|r - Resets all waypoints"])
    ChatFrame1:AddMessage(L["|cffffff78/way reset away|r - Resets all waypoints not in current zone"])
    ChatFrame1:AddMessage(L["|cffffff78/way reset <zone>|r - Resets all waypoints in zone"])
    ChatFrame1:AddMessage(L["|cffffff78/way reset not <zone>|r - Resets all waypoints not in zone"])
    ChatFrame1:AddMessage(L["|cffffff78/way local|r - Lists active waypoints in current zone"])
    ChatFrame1:AddMessage(L["|cffffff78/way list|r - Lists all active waypoints"])
    ChatFrame1:AddMessage(L["|cffffff78/way arrow|r - Prints status of the Crazy Arrow"])
    ChatFrame1:AddMessage(L["|cffffff78/way arrow clear|r - Clears the waypoint from the Crazy Arrow"])
    ChatFrame1:AddMessage(L["|cffffff78/way arrow remove|r - Removes the waypoint on the Crazy Arrow"])
    ChatFrame1:AddMessage(L["|cffffff78/way block|r - Prints status of the Coordinate Block"])
end

local function arrowUsage()
    ChatFrame1:AddMessage(L["|cffffff78TomTom |r/way arrow |cffffff78Usage:|r"])
    ChatFrame1:AddMessage(L["|cffffff78/way arrow|r - Prints status of the Crazy Arrow"])
    ChatFrame1:AddMessage(L["|cffffff78/way arrow clear|r - Clears the waypoint from the Crazy Arrow"])
    ChatFrame1:AddMessage(L["|cffffff78/way arrow remove|r - Removes the waypoint on the Crazy Arrow"])
end

local arrowActions = {
    clear = false,
    remove = true,
}

local function ArrowCommand(action)
    if not action then
        TomTom:DebugCrazyArrow()
        return
    end

    local remove = arrowActions[action:lower()]
    if remove == nil then
        arrowUsage()
    elseif TomTom:IsCrazyArrowEmpty() then
        ChatFrame1:AddMessage(L["The Crazy Arrow has no waypoint"])
    else
        TomTom:ClearCrazyArrowPoint(remove)
    end
end

TomTom.slashCommandUsage = usage

SLASH_TOMTOM1 = "/tomtom"
SlashCmdList["TOMTOM"] = function(msg)
    local tokens = {}
    for token in msg:gmatch("%S+") do table.insert(tokens, token) end

    if tokens[1] and tokens[1]:lower() == "help" then
        TomTom.slashCommandUsage()
        return
    end

    private.OpenSettings()
end

SLASH_TOMTOM_CLOSEST_WAYPOINT1 = "/cway"
SLASH_TOMTOM_CLOSEST_WAYPOINT2 = "/closestway"
SlashCmdList["TOMTOM_CLOSEST_WAYPOINT"] = function(msg)
    TomTom:SetClosestWaypoint(true)
end

SLASH_TOMTOM_WAYBACK1 = "/wayb"
SLASH_TOMTOM_WAYBACK2 = "/wayback"
SlashCmdList["TOMTOM_WAYBACK"] = function(msg)
    local title = L["Wayback"]
    if msg and msg:match("%S") then
        title = msg
    end

    local backm,backx,backy = TomTom:GetCurrentPlayerPosition()
    TomTom:AddWaypoint(backm,backx, backy, {
        title = title,
        from = "TomTom/wayb"
    })
end

SLASH_TOMTOM_WAY1 = "/way"
SLASH_TOMTOM_WAY2 = "/tway"
SLASH_TOMTOM_WAY3 = "/tomtomway"

local wrongseparator = "(%d)" .. (tonumber("1.1") and "," or ".") .. "(%d)"
local rightseparator =   "%1" .. (tonumber("1.1") and "." or ",") .. "%2"

-- Make comparison only using lowercase letters and no spaces
local function lowergsub(s) return s:lower():gsub("[%s]", "") end

-- Resolve a user-supplied zone string to a map ID, returning mapId, zoneName
-- on success or nil plus a message to display on failure.
--
-- A "#1234" zone is parsed as a literal map ID rather than looked up in
-- NameToMapId.  That table only holds maps Blizzard has typed as a zone,
-- continent or micro map, so the escape hatch has to bypass it entirely to be
-- useful for maps that are mistyped (a zone marked as a dungeon, say).  It also
-- avoids the fuzzy match, where "#12" would match "#120" and every other map
-- sharing the prefix.
local function ResolveZone(zone)
    local forcedId = zone:match("^#(%d+)$")
    if forcedId then
        local mapId = tonumber(forcedId)
        if not hbd.mapData[mapId] then
            return nil, nil, string.format(L["No map data is available for map #%d."], mapId)
        end
        return mapId, hbd:GetLocalizedMap(mapId) or zone
    end

    local matches = {}
    local lzone = lowergsub(zone)

    for name in pairs(NameToMapId) do
        local lname = lowergsub(name)
        if lname == lzone then
            -- We have an exact match
            matches = {name}
            break
        elseif lname:find(lzone, 1, true) then
            table.insert(matches, name)
        end
    end

    if #matches > 7 then
        return nil, nil, string.format(L["Found %d possible matches for zone %s.  Please be more specific"], #matches, zone)
    elseif #matches > 1 then
        table.sort(matches)
        return nil, nil, string.format(L["Found multiple matches for zone '%s'.  Did you mean: %s"], zone, table.concat(matches, ", "))
    elseif #matches == 0 then
        return nil, nil, string.format(L["Could not find any matches for zone %s."], zone)
    end

    local zoneName = matches[1]
    return NameToMapId[zoneName], zoneName
end

-- Removes the waypoints of every map other than keepMap, with one line for
-- each map.
local function RemoveFromOtherMaps(keepMap)
    local removed, order = {}, {}
    for _, uid in ipairs(private.WaypointList()) do
        local map = uid[1]
        if map ~= keepMap then
            TomTom:RemoveWaypoint(uid)
            if not removed[map] then
                removed[map] = 0
                table.insert(order, map)
            end
            removed[map] = removed[map] + 1
        end
    end
    for _, map in ipairs(order) do
        local zoneName = hbd:GetLocalizedMap(map) or L["Unnamed Map"]
        ChatFrame1:AddMessage(L["Removed %d waypoints from %s"]:format(removed[map], zoneName))
    end
end

addon.SlashWayCommand = function(msg)
    msg = msg:gsub("(%d)[%.,] (%d)", "%1 %2"):gsub(wrongseparator, rightseparator)
    local tokens = {}
    for token in msg:gmatch("%S+") do table.insert(tokens, token) end

    -- Lower the first token
    local ltoken = tokens[1] and tokens[1]:lower()

    if ltoken == "local" then
        TomTom:DebugListLocalWaypoints()
        return
    elseif ltoken == "list" then
        TomTom:DebugListAllWaypoints()
        return
    elseif ltoken == "arrow" then
        ArrowCommand(tokens[2])
        return
    elseif ltoken == "block" then
        TomTom:DebugCoordBlock()
        return
    elseif ltoken == "reset" then
        local ltoken2 = tokens[2] and tokens[2]:lower()
        if ltoken2 == "all" then
            if TomTom.db.profile.general.confirmremoveall then
                StaticPopup_Show("TOMTOM_REMOVE_ALL_CONFIRM")
            else
                StaticPopupDialogs["TOMTOM_REMOVE_ALL_CONFIRM"].OnAccept()
                return
            end
        elseif ltoken2 == "away" then
            local m = TomTom:GetCurrentPlayerPosition()
            RemoveFromOtherMaps(m)
        elseif tokens[2] then
            -- Reset the named zone
            local notHere = false
            local zone = ""
            if lowergsub(tokens[2]) == "not" then
                notHere = true
                zone = table.concat(tokens, " ", 3)
            else
                zone = table.concat(tokens, " ", 2)
            end
            local mapId, zoneName, errorMsg = ResolveZone(zone)
            if not mapId then
                ChatFrame1:AddMessage(errorMsg)
                return
            end

            if notHere then
                RemoveFromOtherMaps(mapId)
                return
            end

            if TomTom.waypoints[mapId] then
                local list = private.WaypointList(mapId)
                for _, uid in ipairs(list) do
                    TomTom:RemoveWaypoint(uid)
                end
                ChatFrame1:AddMessage(L["Removed %d waypoints from %s"]:format(#list, zoneName))
            else
                ChatFrame1:AddMessage(L["There were no waypoints to remove in %s"]:format(zoneName))
            end
        end
    elseif tokens[1] and not tonumber(tokens[1]) then
        -- Example: /way Elwynn Forest 34.2 50.7 Party in the forest!
        -- tokens[1] = Elwynn
        -- tokens[2] = Forest
        -- tokens[3] = 34.2
        -- tokens[4] = 50.7
        -- tokens[5] = Party
        -- ...
        --
        -- Find the first numeric token
        local zoneEnd
        for idx = 1, #tokens do
            local token = tokens[idx]
            if tonumber(token) then
                -- We've encountered a number, so the zone name must have
                -- ended at the prior token
                zoneEnd = idx - 1
                break
            end
        end

        if not zoneEnd then
            usage()
            return
        end

        -- This is a waypoint set, with a zone before the coords
        local zone = table.concat(tokens, " ", 1, zoneEnd)
        local x,y,desc = select(zoneEnd + 1, unpack(tokens))

        if desc then desc = table.concat(tokens, " ", zoneEnd + 3) end

        local mapId, _, errorMsg = ResolveZone(zone)
        if not mapId then
            ChatFrame1:AddMessage(errorMsg)
            return
        end

        x = x and tonumber(x)
        y = y and tonumber(y)

        if not x or not y then
            return usage()
        end

        x = tonumber(x)
        y = tonumber(y)
        TomTom:AddWaypoint(mapId, x/100, y/100, {
            title = desc or L["TomTom waypoint"],
            from = "TomTom/way",
        })
    elseif tonumber(tokens[1]) then
        -- A vanilla set command
        local x,y,desc = unpack(tokens)
        if not x or not tonumber(x) then
            return usage()
        elseif not y or not tonumber(y) then
            return usage()
        end
        if desc then
            desc = table.concat(tokens, " ", 3)
        end
        x = tonumber(x)
        y = tonumber(y)

        local m = TomTom:GetCurrentPlayerPosition()
        if m and x and y then
            TomTom:AddWaypoint(m, x/100, y/100, {
                title = desc or L["TomTom waypoint"],
                from = "TomTom/way",
            })
        end
    else
        return usage()
    end
end

SlashCmdList["TOMTOM_WAY"] = addon.SlashWayCommand
