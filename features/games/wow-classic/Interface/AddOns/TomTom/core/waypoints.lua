--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- The waypoint store and the public waypoint functions.

local addonName, addon = ...
local TomTom = addon
local L = addon.L
local hbd = addon.hbd
addon.private = addon.private or {}
local private = addon.private
local RoundCoords = private.RoundCoords
local waypointDropdownGenerator = private.waypointDropdownGenerator

local waypoints = {}
TomTom.waypoints = waypoints

private.AddSettingsSection{
    page = "main", order = 10, settingsKey = "general",
    header = L["General Options"],
    rows = {
        {type = "toggle", key = "announce", name = L["Announce new waypoints when they are added"],
         tooltip = L["TomTom can announce new waypoints to the default chat frame when they are added"]},
        {type = "toggle", key = "confirmremoveall", name = L["Ask for confirmation on \"Remove All\""],
         tooltip = L["This option will toggle whether or not you are asked to confirm removing all waypoints.  If enabled, a dialog box will appear, requiring you to confirm removing the waypoints"]},
    },
}

-- A section of its own, so that the page reset also resets this namespace.
private.AddSettingsSection{
    page = "main", order = 11, settingsKey = "persistence",
    rows = {
        {type = "toggle", key = "savewaypoints", name = L["Save new waypoints until I remove them"],
         tooltip = L["This option will not remove any waypoints that are currently set to persist, but only effects new waypoints that get set"]},
        {type = "range", key = "cleardistance", name = L["Clear waypoint distance"],
         tooltip = L["Waypoints can be automatically cleared when you reach them.  This slider allows you to customize the distance in yards that signals your \"arrival\" at the waypoint.  A setting of 0 turns off the auto-clearing feature\n\nChanging this setting only takes effect after reloading your interface."],
         min = 0, max = 150, step = 1},
        {type = "execute", name = L["Reset waypoint display options to current"],
         tooltip = L["Makes every saved waypoint ask for its minimap and world map pins again, so that it follows the Minimap and World Map settings, and gives it the current clear and arrival distances."],
         func = function()
             TomTom:ResetWaypointOptions()
             TomTom:ReloadWaypoints()
         end},
    },
}

-- Some utility functions that can pack/unpack data from a waypoint

-- Returns a hashable 'key' for a given waypoint consisting of the
-- map, x, y and the waypoints title. This isn't truly
-- unique, but should be close enough to determine duplicates, etc.
function TomTom:GetKey(waypoint)
    local m,x,y = unpack(waypoint)
    return self:GetKeyArgs(m, x, y, waypoint.title)
end

function TomTom:GetKeyArgs(m, x, y, title)
	-- Fudge the x/y values so they avoid precision/printf issues
	local x = x * 10000
	local y = y * 10000

    local key = string.format("%d:%s:%s:%s", m, x*10e4, y*10e4, tostring(title))
	return key
end

--[[--------------------------------------------------------------------------
--  Active waypoints
--
--  SetWaypoint adds a uid to the active set and ClearWaypoint removes it.
--  The distance service and the pins follow the active set. Other addons
--  hook these methods (docs/integrations.md 3.4), so TomTom calls them
--  through the addon table, never as locals.
--
--  Messages, each with the uid:
--    TOMTOM_WAYPOINT_ADDED        the uid is active
--    TOMTOM_WAYPOINT_REMOVED      the uid is not active (also on a reload)
--    TOMTOM_WAYPOINT_VISIBILITY   HideWaypoint or ShowWaypoint changed it
----------------------------------------------------------------------------]]

local active = {}

-- Calling it again for an active uid replaces its display options.
function TomTom:SetWaypoint(uid, callbacks, show_minimap, show_world)
    active[uid] = {
        callbacks = callbacks,
        minimap = not not show_minimap,
        world = not not show_world,
    }
    private.TrackDistance(uid, callbacks)
    self:FireMessage("TOMTOM_WAYPOINT_ADDED", uid)
end

function TomTom:ClearWaypoint(uid)
    if not active[uid] then return end
    active[uid] = nil
    private.UntrackDistance(uid)
    self:FireMessage("TOMTOM_WAYPOINT_REMOVED", uid)
end

-- The pins stay hidden until ShowWaypoint, also when the map draws again.
function TomTom:HideWaypoint(uid, minimap, worldmap)
    local display = active[uid]
    if not display then return end
    display.minimapHidden = display.minimapHidden or not not minimap
    display.worldHidden = display.worldHidden or not not worldmap
    self:FireMessage("TOMTOM_WAYPOINT_VISIBILITY", uid)
end

function TomTom:ShowWaypoint(uid)
    local display = active[uid]
    if not display then return end
    display.minimapHidden = nil
    display.worldHidden = nil
    self:FireMessage("TOMTOM_WAYPOINT_VISIBILITY", uid)
end

-- The display options of an active uid, or nil. Do not change the table.
function private.GetWaypointDisplay(uid)
    return active[uid]
end

-- True when the uid is active, its pin of that kind is on, and it is not
-- hidden. kind is "minimap" or "world".
function private.ShowsPin(uid, kind)
    local display = active[uid]
    return display ~= nil and display[kind] and not display[kind .. "Hidden"]
end

function private.IterateActiveWaypoints()
    return pairs(active)
end

-- The uids as a new list, so that the caller can remove waypoints while it
-- walks the list: a WaypointRemoved listener can add waypoints. With mapId,
-- only the waypoints of that map.
function private.WaypointList(mapId)
    local list = {}
    for map, entries in pairs(waypoints) do
        if not mapId or map == mapId then
            for _, uid in pairs(entries) do
                table.insert(list, uid)
            end
        end
    end
    return list
end

function TomTom:ClearAllWaypoints()
    for mapId, entries in pairs(waypoints) do
        for key, waypoint in pairs(entries) do
            -- The waypoint IS the UID now
            self:ClearWaypoint(waypoint)
        end
    end
end

-- The minimap and world map settings apply to every waypoint that asks for
-- a pin, so the reset makes each saved waypoint ask for both.
function TomTom:ResetWaypointOptions()
    local cleardistance = self.profile.persistence.cleardistance
    local arrivaldistance = self.profile.arrow.arrival

	for map, data in pairs(self.waypointprofile) do
		for key, waypoint in pairs(data) do
			waypoint.minimap = true
			waypoint.world = true
			waypoint.cleardistance = cleardistance
			waypoint.arrivaldistance = arrivaldistance
		end
	end
end

function TomTom:ReloadWaypoints()
    self:ClearAllWaypoints()

    local dropped = waypoints
    waypoints = {}
    self.waypoints = waypoints
    self.waypointprofile = self.waydb.profile

    -- The saved waypoints come back with new uids, so every old uid is
    -- removed for the other addons.
    for _, entries in pairs(dropped) do
        for _, uid in pairs(entries) do
            private.FireCallback("WaypointRemoved", uid)
        end
    end

    -- A WaypointAdded listener can save new waypoints, so walk a copy.
    local saved = {}
    for _, data in pairs(self.waypointprofile) do
        for _, waypoint in pairs(data) do
            table.insert(saved, waypoint)
        end
    end

    for _, waypoint in ipairs(saved) do
            local m,x,y = unpack(waypoint)
            local title = waypoint.title

			-- Set up default options
			local options = {
				desc = title,
				title = title,
				persistent = waypoint.persistent,
				callbacks = nil,
				silent = true,
				from = "Anon",
			}

			-- Override options with what is stored in the profile
			for k,v in pairs(waypoint) do
				if type(k) == "string" then
					if k ~= "callbacks" then
						-- we can never import callbacks, so ditch them
						options[k] = v
					end
				end
			end

            self:AddWaypoint(m, x, y, options)
    end

    self:FireMessage("TOMTOM_WAYPOINTS_RELOADED")
    private.FireCallback("WaypointsReloaded")
end

function TomTom:UIDIsSaved(uid)
    if type(uid) ~= "table" then error("TomTom:UIDIsSaved(uid) UID is not a table."); end
    local data = uid
    if data then
        local key = TomTom:GetKey(data)
        local mapId = data[1]

        if data then
            return not not TomTom.waypointprofile[mapId][key]
        end
    end
    return false
end

--[[-------------------------------------------------------------------
--  Define callback functions
-------------------------------------------------------------------]]--
local function _minimap_onclick(event, uid, self, button)
    if TomTom.db.profile.minimap.menu then
        TomTom.dropdown_uid = uid
        MenuUtil.CreateContextMenu(self, waypointDropdownGenerator)
    end
end

local function _world_onclick(event, uid, self, button)
    if TomTom.db.profile.worldmap.menu then
        TomTom.dropdown_uid = uid
        MenuUtil.CreateContextMenu(self, waypointDropdownGenerator)
    end
end

local function _both_tooltip_show(event, tooltip, uid, dist)
    local data = uid

    tooltip:SetText(data.title or L["Unknown waypoint"])
    if dist and tonumber(dist) then
        tooltip:AddLine(string.format(L["%s yards away"], math.floor(dist)), 1, 1, 1)
    else
        tooltip:AddLine(L["Unknown distance"])
    end
    local m,x,y = unpack(data)
    local zoneName = hbd:GetLocalizedMap(m) or L["Unnamed Map"]

    tooltip:AddLine(string.format(L["%s (%.2f, %.2f)"], zoneName, x*100, y*100), 0.7, 0.7, 0.7)
    tooltip:AddLine(string.format(L["From: %s"], data.from or "?"))
    tooltip:Show()
end

-- Returning false tells the pin not to show the tooltip (B24).
local function _minimap_tooltip_show(event, tooltip, uid, dist)
    if not TomTom.db.profile.minimap.tooltip then
        tooltip:Hide()
        return false
    end
    return _both_tooltip_show(event, tooltip, uid, dist)
end

local function _world_tooltip_show(event, tooltip, uid, dist)
    if not TomTom.db.profile.worldmap.tooltip then
        tooltip:Hide()
        return false
    end
    return _both_tooltip_show(event, tooltip, uid, dist)
end

local function _both_tooltip_update(event, tooltip, uid, dist)
    if dist and tonumber(dist) then
        tooltip.lines[2]:SetFormattedText(L["%s yards away"], math.floor(dist), 1, 1, 1)
    else
        tooltip.lines[2]:SetText(L["Unknown distance"])
    end
end

local function _both_clear_distance(event, uid, range, distance, lastdistance)
	-- Only clear the waypoint if we weren't inside it when it was set
    if lastdistance and not UnitOnTaxi("player") then
        TomTom:RemoveWaypoint(uid)
    end
end

local function _both_ping_arrival(event, uid, range, distance, lastdistance)
    if TomTom.profile.arrow.enablePing then
        PlaySoundFile("Interface\\AddOns\\TomTom\\Media\\ping.mp3", TomTom.profile.arrow.pingChannel)
    end
end

function TomTom:RemoveWaypoint(uid)
    if not uid then return end
    if type(uid) ~= "table" then error("TomTom:RemoveWaypoint(uid) UID is not a table."); end
    local data = uid
    self:ClearWaypoint(uid)

    local key = TomTom:GetKey(data)
    local mapId = data[1]
    local sv = TomTom.waypointprofile[mapId]

    if sv and sv[key] then
        sv[key] = nil
    end

    -- Remove this entry from the waypoints table
    if waypoints[mapId] and waypoints[mapId][key] then
        waypoints[mapId][key] = nil
        private.FireCallback("WaypointRemoved", uid)
    end
end


function TomTom:AddWaypointToCurrentZone(x, y, desc)
    local m = TomTom:GetCurrentPlayerPosition()
    if not m then
        return
    end

    return self:AddWaypoint(m, x/100, y/100, {title = desc, from="TomTom/AWTCZ"})
end

-- Return a set of default callbacks that can be used by addons to provide
-- more detailed functionality without losing the tooltip and onclick
-- functionality.
--
-- Options that are used in this 'opts' table in this function:
--  * cleardistance - When the player is this far from the waypoint, the
--    waypoint will be removed.
--  * arrivaldistance - When the player is within this radius of the waypoint,
--    the crazy arrow will change to the 'downwards' arrow, indicating that
--    the player has arrived.

function TomTom:DefaultCallbacks(opts)
    opts = opts or {}

	local callbacks = {
		minimap = {
			onclick = _minimap_onclick,
			tooltip_show = _minimap_tooltip_show,
			tooltip_update = _both_tooltip_update,
		},
		world = {
			onclick = _world_onclick,
			tooltip_show = _world_tooltip_show,
			tooltip_update = _both_tooltip_update,
		},
		distance = {
		},
	}

    local cleardistance = self.profile.persistence.cleardistance
    local arrivaldistance = self.profile.arrow.arrival

    -- Allow both of these to be overriden by options
    if opts.cleardistance then
        cleardistance = opts.cleardistance
    end
    if opts.arrivaldistance then
        arrivaldistance = opts.arrivaldistance
    end

    -- User wants ping, they get ping!
    if TomTom.profile.arrow.enablePing then
        if arrivaldistance <= 0 then
            arrivaldistance = 1
        end
        if arrivaldistance < cleardistance then
            arrivaldistance = cleardistance
        end
    end

    if cleardistance == arrivaldistance then
        callbacks.distance[cleardistance] = function(...)
            _both_clear_distance(...);
            _both_ping_arrival(...);
        end
    else
        if cleardistance > 0 then
            callbacks.distance[cleardistance] = _both_clear_distance
        end
        if arrivaldistance > 0 then
            callbacks.distance[arrivaldistance] = _both_ping_arrival
        end
    end

	return callbacks
end

function TomTom:AddWaypoint(m, x, y, opts)
	opts = opts or {}

	-- Default values
    if opts.persistent == nil then opts.persistent = self.profile.persistence.savewaypoints end
    -- The pin modules apply the minimap and world map settings when they
    -- run, so a waypoint asks for both pins unless its caller says no.
    if opts.minimap == nil then opts.minimap = true end
    if opts.world == nil then opts.world = true end
    if opts.crazy == nil then opts.crazy = self.profile.arrow.autoqueue end
	if opts.cleardistance == nil then opts.cleardistance = self.profile.persistence.cleardistance end
	if opts.arrivaldistance == nil then opts.arrivaldistance = self.profile.arrow.arrival end

    if not opts.callbacks then
		opts.callbacks = TomTom:DefaultCallbacks(opts)
	end

    local zoneName = hbd:GetLocalizedMap(m) or L["Unnamed Map"]

    -- Ensure there isn't already a waypoint at this location
    local key = self:GetKey({m, x, y, title = opts.title})
    if waypoints[m] and waypoints[m][key] then
        return waypoints[m][key]
    end

    -- uid is the 'new waypoint' called this for historical reasons
    -- README documented "source" for a long time, so addons pass it.
    local uid = {m, x, y, title = opts.title, from=(opts.from or opts.source or "?")}

    -- Copy over any options, so we have them
    for k,v in pairs(opts) do
        if not uid[k] then
            uid[k] = v
        end
    end

    -- No need to convert x and y because they're already 0-1 instead of 0-100
    self:SetWaypoint(uid, opts.callbacks, opts.minimap, opts.world)

    waypoints[m] = waypoints[m] or {}
    waypoints[m][key] = uid

    -- If this is a persistent waypoint, then add it to the waypoints table
    if opts.persistent then
        self.waypointprofile[m][key] = uid
    end

    -- After the store, so that an ArrowTargetChanged listener sees a valid
    -- waypoint.
    if opts.crazy then
        self:SetCrazyArrow(uid, opts.arrivaldistance, opts.title)
    end

    if not opts.silent and self.profile.general.announce then
        local ctxt = RoundCoords(x, y, 2)
        local desc = opts.title and opts.title or ""
        local sep = opts.title and " - " or ""
        local msg = string.format(L["|cffffff78TomTom:|r Added a waypoint (%s%s%s) in %s"], desc, sep, ctxt, zoneName)
        ChatFrame1:AddMessage(msg)
    end

    private.FireCallback("WaypointAdded", uid)
    return uid
end

-- Check to see if a given uid/waypoint is actually set somewhere
function TomTom:IsValidWaypoint(waypoint)
    if type(waypoint) ~= "table" then error("TomTom:IsValidWaypoint(waypoint) UID is not a table."); end
    local m = waypoint[1]
    local key = self:GetKey(waypoint)
    if waypoints[m] and waypoints[m][key] then
        return true
    else
        return false
    end
end

function TomTom:WaypointHasSameMapXYTitle(waypoint, map, x, y, title)
    -- This is a hack that relies on the UID format, do not use this
    -- in your addons, please.
    local pm, px, py = unpack(waypoint)
    if map == pm and x == px and y == py and waypoint.title == title then
        return true
    end

    return false
end

function TomTom:WaypointExists(m, x, y, desc)
    local key = self:GetKeyArgs(m, x, y, desc)
    if waypoints[m] and waypoints[m][key] then
        return true
    else
        return false
    end
end

function TomTom:SetCustomWaypoint(m, x, y, opts)
    opts.persistent = false
    return self:AddWaypoint(m, x, y, opts)
end

function TomTom:GetClosestWaypoint()
    local m,x,y = self:GetCurrentPlayerPosition()
    local c,z,w = TomTom:GetCZWFromMapID(m)

    local closest_waypoint = nil
    local closest_dist = nil

    if not self.profile.arrow.closestusecontinent then
		-- Simple search within this zone
		if waypoints[m] then
			for key, waypoint in pairs(waypoints[m]) do
				local dist = TomTom:GetDistanceToWaypoint(waypoint)
				if (dist and closest_dist == nil) or (dist and dist < closest_dist) then
					closest_dist = dist
					closest_waypoint = waypoint
				end
			end
		end
	else
		-- Search all waypoints on this continent
		for map, waypoints in pairs(waypoints) do
			if c == TomTom:GetCZWFromMapID(map) then
				for key, waypoint in pairs(waypoints) do
					local dist = TomTom:GetDistanceToWaypoint(waypoint)
					if (dist and closest_dist == nil) or (dist and dist < closest_dist) then
						closest_dist = dist
						closest_waypoint = waypoint
					end
				end
			end
		end
	end

    if closest_dist then
        return closest_waypoint
    end
end

function TomTom:SetClosestWaypoint(verbose)
    local uid = self:GetClosestWaypoint()
    if uid then
        local data = uid
        TomTom:SetCrazyArrow(uid, TomTom.profile.arrow.arrival, data.title)
        local m, x, y = unpack(data)
        local zoneName = hbd:GetLocalizedMap(m) or L["Unnamed Map"]
        local ctxt = RoundCoords(x, y, 2)
        local desc = data.title and data.title or ""
        local sep = data.title and " - " or ""
        if self.profile.general.announce then
            local msg = string.format(L["|cffffff78TomTom:|r Selected waypoint (%s%s%s) in %s"], desc, sep, ctxt, zoneName)
            ChatFrame1:AddMessage(msg)
        end
    else
        local msg
        if not self.profile.arrow.closestusecontinent then
           msg = L["|cffffff78TomTom:|r Could not find a closest waypoint in this zone."]
        else
           msg = L["|cffffff78TomTom:|r Could not find a closest waypoint in this continent."]
        end
        if verbose then
            ChatFrame1:AddMessage(msg)
        end
    end
    return uid
end
