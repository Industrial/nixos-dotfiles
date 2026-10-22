-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

local LibStub = _G.LibStub
local RareScanner = LibStub("AceAddon-3.0"):GetAddon("RareScanner")
local AL = LibStub("AceLocale-3.0"):GetLocale("RareScanner", false)
local LibDialog = LibStub("LibDialog-1.0RS")

local RSGeneralOptions = private.NewLib("RareScannerGeneralOptions")

-- RareScanner database libraries
local RSConfigDB = private.ImportLib("RareScannerConfigDB")

-- RareScanner services
local RSMacro = private.ImportLib("RareScannerMacro")
local RSEventHandler = private.ImportLib("RareScannerEventHandler")

-- RareScanner internal libraries
local RSConstants = private.ImportLib("RareScannerConstants")

local options

-----------------------------------------------------------------------
-- Target markers
-----------------------------------------------------------------------

private.TARGET_MARKERS = {
	["Star"] = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_1",
	["Circle"] = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_2",
	["Diamond"] = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_3",
	["Triangle"] = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_4",
	["Moon"] = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_5",
	["Square"] = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_6",
	["Cross"] = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7",
	["Skull"] = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8",
}

-----------------------------------------------------------------------
-- Functions
-----------------------------------------------------------------------

local orderedMarkers

local function GetOrderedMarkers()
	if (not orderedMarkers) then
		orderedMarkers = {}
	
		for _, v in pairs(private.TARGET_MARKERS) do
			orderedMarkers[#orderedMarkers+1] = v
		end
		table.sort(orderedMarkers, function(a,b) return string.upper(a) < string.upper(b) end)
	end
	
	return orderedMarkers
end

local function SetMarker(key)
	if (key) then
		for k, m in pairs (private.TARGET_MARKERS) do
			if (k == key) then
				for index, v in ipairs(GetOrderedMarkers()) do
					if (m == v) then
						RSConfigDB.SetMarkerOnTarget(index)
					end
				end
			end
		end
	end
end

local function GetMarker()
	for index, v in ipairs(GetOrderedMarkers()) do
		if (private.db.general.marker == index) then
			for key, m in pairs (private.TARGET_MARKERS) do
				if (m == v) then
					return key
				end
			end
		end
	end
end

-----------------------------------------------------------------------
-- Options tab: General
-----------------------------------------------------------------------

function RSGeneralOptions.GetGeneralOptions()
	if (not options) then
		options = {
			type = "group",
			name = _G.GENERAL_LABEL,
			handler = RareScanner,
			desc = AL["options"],
			args = {
				rescanTimer = {
					order = 0,
					type = "range",
					name = AL["RESCAN_TIMER"],
					desc = AL["RESCAN_TIMER_DESC"],
					min	= 1,
					max	= 60,
					step = 1,
					bigStep = 1,
					get = function() return RSConfigDB.GetRescanTimer() end,
					set = function(_, value)
						RSConfigDB.SetRescanTimer(value)
					end,
					width = "full",
				},
				scanRares = {
					order = 1,
					name = AL["ENABLE_SCAN_RARES"],
					desc = AL["ENABLE_SCAN_RARES_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsScanningForNpcs() end,
					set = function(_, value)
						RSConfigDB.SetScanningForNpcs(value)
					end,
					width = "full",
				},
				scanContainers = {
					order = 2,
					name = AL["ENABLE_SCAN_CONTAINERS"],
					desc = AL["ENABLE_SCAN_CONTAINERS_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsScanningForContainers() end,
					set = function(_, value)
						RSConfigDB.SetScanningForContainers(value)
					end,
					width = "full",
				},
				scanEvents = {
					order = 3,
					name = AL["ENABLE_SCAN_EVENTS"],
					desc = AL["ENABLE_SCAN_EVENTS_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsScanningForEvents() end,
					set = function(_, value)
						RSConfigDB.SetScanningForEvents(value)
					end,
					width = "full",
				},
				scanChatAlerts = {
					order = 4,
					name = AL["ENABLE_SCAN_CHAT"],
					desc = AL["ENABLE_SCAN_CHAT_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsScanningChatAlerts() end,
					set = function(_, value)
						RSConfigDB.SetScanningChatAlerts(value)
					end,
					width = "full",
				},
				scanGarrison = {
					order = 5,
					name = AL["ENABLE_SCAN_GARRISON_CHEST"],
					desc = AL["ENABLE_SCAN_GARRISON_CHEST_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsShowingGarrisonCache() end,
					set = function(_, value)
						RSConfigDB.SetShowingGarrisonCache(value)
					end,
					width = "full",
				},
				scanInstances = {
					order = 6,
					name = AL["ENABLE_SCAN_IN_INSTANCE"],
					desc = AL["ENABLE_SCAN_IN_INSTANCE_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsScanningInInstances() end,
					set = function(_, value)
						RSConfigDB.SetScanningInInstance(value)
					end,
					width = "full",
				},
				scanOnTaxi = {
					order = 7,
					name = AL["ENABLE_SCAN_ON_TAXI"],
					desc = AL["ENABLE_SCAN_ON_TAXI_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsScanningWhileOnTaxi() end,
					set = function(_, value)
						RSConfigDB.SetScanningWhileOnTaxi(value)
					end,
					width = "full",
				},
				scanOnRacingQuest = {
					order = 8,
					name = AL["ENABLE_SCAN_ON_RACING_QUEST"],
					desc = AL["ENABLE_SCAN_ON_RACING_QUEST_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsScanningWhileOnRacingQuest() end,
					set = function(_, value)
						RSConfigDB.SetScanningWhileOnRacingQuest(value)
					end,
					width = "full",
				},
				scanOnPetBattle = {
					order = 9,
					name = AL["ENABLE_SCAN_ON_PET_BATTLE"],
					desc = AL["ENABLE_SCAN_ON_PET_BATTLE_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsScanningWhileOnPetBattle() end,
					set = function(_, value)
						RSConfigDB.SetScanningWhileOnPetBattle(value)
					end,
					width = "full",
				},
				ignoreCompletedEntities = {
					order = 10,
					name = AL["IGNORE_SCAN_COMPLETED_ENTITIES"],
					desc = AL["IGNORE_SCAN_COMPLETED_ENTITIES_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsIgnoringCompletedEntities() end,
					set = function(_, value)
						RSConfigDB.SetIgnoringCompletedEntities(value)
					end,
					width = "full",
				},
				autoHideButtonInstances = {
					order = 11,
					name = AL["AUTOHIDE_BUTTON_INSTANCES"],
					desc = AL["AUTOHIDE_BUTTON_INSTANCES_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsAutohidingInIntances() end,
					set = function(_, value)
						RSConfigDB.SetAutohidingInIntances(value)
					end,
					width = "full",
				},
				showMaker = {
					order = 12,
					name = AL["ENABLE_MARKER"],
					desc = AL["ENABLE_MARKER_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsDisplayingMarkerOnTarget() end,
					set = function(_, value)
						RSConfigDB.SetDisplayingMarkerOnTarget(value)
					end,
					width = "full",
				},
				marker = {
					order = 13,
					type = "select",
					dialogControl = 'RS_Markers',
					name = AL["MARKER"],
					desc = AL["MARKER_DESC"],
					values = private.TARGET_MARKERS,
					get = function() return GetMarker() end,
					set = function(_, value)
						SetMarker(value)
					end,
					width = "normal",
					disabled = function() return not RSConfigDB.IsDisplayingMarkerOnTarget() end,
				},
				pingTarget = {
					order = 14,
					name = AL["ENABLE_PING"],
					desc = AL["ENABLE_PING_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsPingingTarget() end,
					set = function(_, value)
						RSConfigDB.SetPingingTarget(value)
					end,
					width = "full",
				},
				separatorTrackingSystems = {
					order = 15,
					type = "header",
					name = AL["TRACKING_SYSTEMS"],
				},
				scanWorldMapVignettes = {
					order = 16,
					name = AL["ENABLE_SCAN_WORLDMAP_VIGNETTES"],
					desc = AL["ENABLE_SCAN_WORLDMAP_VIGNETTES_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsScanningWorldMapVignettes() end,
					set = function(_, value)
						RSConfigDB.SetScanningWorldMapVignettes(value)
					end,
					width = "full",
				},
				scanSoftInteract = {
					order = 17,
					name = AL["ENABLE_SCAN_SOFT_INTERACT"],
					desc = AL["ENABLE_SCAN_SOFT_INTERACT_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsScanningSoftInteract() end,
					set = function(_, value)
						RSConfigDB.SetScanningSoftInteract(value)
						RSEventHandler.UpdateSoftInteractCVars(value)
					end,
					width = "full",
				},
				scanWithMacro = {
					order = 18,
					name = AL["ENABLE_SCAN_MACRO"],
					desc = AL["ENABLE_SCAN_MACRO_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsScanningWithMacro() end,
					set = function(_, value)
						RSConfigDB.SetScanningWithMacro(value)
						if (value) then
							RSMacro.CreateMacro()
						else
							RSConfigDB.SetScanningWithMacroPerChar(false)
							RSMacro.DeleteMacro()
						end
					end,
					validate = function(_, value)
						-- Check numer of macros
						if (value and not RSMacro.IsAvailableMacroSlot()) then
							return AL["ENABLE_SCAN_MACRO_ERROR"]
						end
						
						return true
					end,
					width = "full",
				},
				scanWithMacroPerChar = {
					order = 19,
					name = AL["ENABLE_SCAN_MACRO_PER_CHAR"],
					desc = AL["ENABLE_SCAN_MACRO_PER_CHAR_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsScanningWithMacroPerChar() end,
					set = function(_, value)
						RSConfigDB.SetScanningWithMacroPerChar(value)
						if (RSConfigDB.IsScanningWithMacro()) then
							RSMacro.DeleteMacro()
							RSMacro.CreateMacro()
							RSMacro.UpdateMacro(true)
						end
					end,
					validate = function(_, value)
						if (value and RSConfigDB.IsScanningWithMacro()) then
							local _, numPerChar = GetNumMacros()
							if (numPerChar >= (_G.MAX_CHARACTER_MACROS or 30)) then
								return AL["ENABLE_SCAN_MACRO_ERROR"]
							end
						elseif (not value and RSConfigDB.IsScanningWithMacro()) then
							local numAccount = GetNumMacros()
							if (numAccount >= (_G.MAX_ACCOUNT_MACROS or 120)) then
								return AL["ENABLE_SCAN_MACRO_ERROR"]
							end
						end
						return true
					end,
					width = "full",
					disabled = function() return not RSConfigDB.IsScanningWithMacro() end,
				},
				separatorWaypoints = {
					order = 20,
					type = "header",
					name = AL["INGAME_WAYPOINTS"],
				},
				enableWaypointsSupport = {
					order = 21,
					name = AL["ENABLE_WAYPOINTS_SUPPORT"],
					desc = AL["ENABLE_WAYPOINTS_SUPPORT_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsWaypointsSupportEnabled() end,
					set = function(_, value)
						RSConfigDB.SetWaypointsSupportEnabled(value)
						if (not value) then
							RSConfigDB.SetAddingWaypointsAutomatically(false)
						end
					end,
					width = "full",
				},
				autoWaypoints = {
					order = 22,
					name = AL["ENABLE_AUTO_WAYPOINTS"],
					desc = AL["ENABLE_AUTO_WAYPOINTS_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsAddingWaypointsAutomatically() end,
					set = function(_, value)
						RSConfigDB.SetAddingWaypointsAutomatically(value)
					end,
					width = "full",
					disabled = function() return not RSConfigDB.IsWaypointsSupportEnabled() end,
				},
				separatorTomtomWaypoints = {
					order = 23,
					type = "header",
					name = AL["TOMTOM_WAYPOINTS"],
				},
				enableTomtomSupport = {
					order = 24,
					name = AL["ENABLE_TOMTOM_SUPPORT"],
					desc = AL["ENABLE_TOMTOM_SUPPORT_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsTomtomSupportEnabled() end,
					set = function(_, value)
						RSConfigDB.SetTomtomSupportEnabled(value)
						if (not value) then
							RSConfigDB.SetAddingTomtomWaypointsAutomatically(false)
						end
					end,
					width = "full",
					disabled = function() return not TomTom end,
				},
				autoTomtomWaypoints = {
					order = 25,
					name = AL["ENABLE_AUTO_TOMTOM_WAYPOINTS"],
					desc = AL["ENABLE_AUTO_TOMTOM_WAYPOINTS_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsAddingTomtomWaypointsAutomatically() end,
					set = function(_, value)
						RSConfigDB.SetAddingTomtomWaypointsAutomatically(value)
					end,
					width = "full",
					disabled = function() return not RSConfigDB.IsTomtomSupportEnabled() end,
				},
				showTomtomMinimapIcon = {
					order = 26,
					name = AL["SHOW_TOMTOM_MINIMAP_ICON"],
					desc = AL["SHOW_TOMTOM_MINIMAP_ICON_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsShowingTomtomMinimapIcon() end,
					set = function(_, value)
						RSConfigDB.SetShowingTomtomMinimapIcon(value)
					end,
					width = "full",
					disabled = function() return not TomTom end,
				},
				showTomtomWorldmapIcon = {
					order = 27,
					name = AL["SHOW_TOMTOM_WORLDMAP_ICON"],
					desc = AL["SHOW_TOMTOM_WORLDMAP_ICON_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsShowingTomtomWorldmapIcon() end,
					set = function(_, value)
						RSConfigDB.SetShowingTomtomWorldmapIcon(value)
					end,
					width = "full",
					disabled = function() return not TomTom end,
				},
				separatorWaypointUIWaypoints = {
					order = 28,
					type = "header",
					name = AL["WAYPOINTUI_WAYPOINTS"],
				},
				enableWaypointUISupport = {
					order = 29,
					name = AL["ENABLE_WAYPOINTUI_SUPPORT"],
					desc = AL["ENABLE_WAYPOINTUI_SUPPORT_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsWaypointUISupportEnabled() end,
					set = function(_, value)
						RSConfigDB.SetWaypointUISupportEnabled(value)
						if (not value) then
							RSConfigDB.SetAddingWaypointUIWaypointsAutomatically(false)
						end
					end,
					width = "full",
					disabled = function() return not WaypointUIAPI end,
				},
				autoWaypointUIWaypoints = {
					order = 30,
					name = AL["ENABLE_AUTO_TOMTOM_WAYPOINTS"],
					desc = AL["ENABLE_AUTO_TOMTOM_WAYPOINTS_DESC"],
					type = "toggle",
					get = function() return RSConfigDB.IsAddingWaypointUIWaypointsAutomatically() end,
					set = function(_, value)
						RSConfigDB.SetAddingWaypointUIWaypointsAutomatically(value)
					end,
					width = "full",
					disabled = function() return not RSConfigDB.IsWaypointUISupportEnabled() end,
				},
			},
		}
	end

	return options
end