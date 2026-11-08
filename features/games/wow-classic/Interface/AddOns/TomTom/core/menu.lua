--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- The waypoint context menu and the remove-all confirmation.

local addonName, addon = ...
local TomTom = addon
local L = addon.L
addon.private = addon.private or {}
local private = addon.private

--[[-------------------------------------------------------------------
--  Dropdown menu code
-------------------------------------------------------------------]]--

StaticPopupDialogs["TOMTOM_REMOVE_ALL_CONFIRM"] = {
	preferredIndex = STATICPOPUPS_NUMDIALOGS,
    text = L["Are you sure you would like to remove ALL TomTom waypoints?"],
    button1 = L["Yes"],
    button2 = L["No"],
    -- The reset runs ReloadWaypoints through the AceDB OnProfileReset
    -- callback (core/settings.lua).
    OnAccept = function()
        TomTom.waydb:ResetProfile()
    end,
    timeout = 30,
    whileDead = 1,
    hideOnEscape = 1,
}

local function waypointDropdownGenerator(owner, rootDescription)
	rootDescription:CreateTitle(L["Waypoint Options"]);

    rootDescription:CreateButton(L["Set as waypoint arrow"], function()
        local uid = TomTom.dropdown_uid
        local data = uid
        addon:SetCrazyArrow(uid, addon.profile.arrow.arrival, data.title or L["TomTom waypoint"])
    end)

	-- Waypoint communications
    local sendWaypoint = rootDescription:CreateButton(L["Send waypoint to"])
	sendWaypoint:CreateTitle(L["Waypoint communication"])
	sendWaypoint:CreateButton(L["Send to party"], function()
		addon:SendWaypoint(addon.dropdown_uid, "PARTY")
	end)
	sendWaypoint:CreateButton(L["Send to raid"], function()
		addon:SendWaypoint(addon.dropdown_uid, "RAID")
	end)
	sendWaypoint:CreateButton(L["Send to battleground"], function()
		addon:SendWaypoint(addon.dropdown_uid, "INSTANCE_CHAT")
	end)
	sendWaypoint:CreateButton(L["Send to guild"], function()
		addon:SendWaypoint(addon.dropdown_uid, "GUILD")
	end)

	rootDescription:CreateButton(L["Clear waypoint from crazy arrow"], function()
		addon:ClearCrazyArrowPoint(false)
	end)

	rootDescription:CreateButton(L["Remove waypoint"], function()
		local uid = addon.dropdown_uid
		addon:RemoveWaypoint(uid)
	end)

	rootDescription:CreateButton(L["Remove all waypoints from this zone"], function()
		for _, waypoint in ipairs(private.WaypointList(addon.dropdown_uid[1])) do
			addon:RemoveWaypoint(waypoint)
		end
	end)

	rootDescription:CreateButton(L["Remove all waypoints"], function()
		if addon.db.profile.general.confirmremoveall then
			StaticPopup_Show("TOMTOM_REMOVE_ALL_CONFIRM")
		else
			StaticPopupDialogs["TOMTOM_REMOVE_ALL_CONFIRM"].OnAccept()
			return
		end
	end)

    local isDropdownWaypointSaved = function()
        local uid = addon.dropdown_uid
        return not not addon:UIDIsSaved(uid)
    end

    local setDropdownWaypointSaved = function()
        local uid = addon.dropdown_uid
        if not uid then
            return false
        end

        local key = addon:GetKey(uid)
        local mapId = uid[1]
        local saved = addon:UIDIsSaved(uid)

        if saved then
            addon.waypointprofile[mapId][key] = nil
        else
            addon.waypointprofile[mapId][key] = uid
        end
    end

    rootDescription:CreateCheckbox(L["Save this waypoint between sessions"], isDropdownWaypointSaved, setDropdownWaypointSaved)
end

private.waypointDropdownGenerator = waypointDropdownGenerator
