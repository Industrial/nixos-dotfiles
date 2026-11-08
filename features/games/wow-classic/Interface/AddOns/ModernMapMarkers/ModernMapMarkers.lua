-- ModernMapMarkers.lua (WoW: Forever 1.60+, interface 16001)
-- Core logic: point index, marker pool, rendering, event handling.
-- UI (dropdowns, tooltip, Find Marker panel) is in ModernMapMarkers_UI.lua.
-- Marker data is defined in MarkerData.lua as MMM_DefaultPoints.
--
-- Forever runs the Retail (Mainline) UI code, so the map is driven by
-- uiMapIDs and the MapCanvas (WorldMapFrame:SetMapID / :GetMapID / :GetCanvas)
-- instead of the 3.3.5a continent/zone indices and WORLD_MAP_UPDATE.

-- ============================================================
-- Constants
-- ============================================================

local HOVER_SIZE_MULTIPLIER   = 1.15
local HOVER_ALPHA             = 0.5
local FIND_SIZE_MULTIPLIER    = 1.4
local FIND_HIGHLIGHT_ALPHA    = 0.9
local FIND_HIGHLIGHT_DURATION = 3.5
local MARKER_SIZE_LARGE       = 48
local MARKER_SIZE_SMALL       = 32
local MAX_POOL_SIZE           = 50
local PIN_LEVEL_FALLBACK      = 1000 -- above the canvas if the level manager is unavailable

local TEXTURES = {
	dungeon   = "Interface\\AddOns\\ModernMapMarkers\\Textures\\dungeon.tga",
	raid      = "Interface\\AddOns\\ModernMapMarkers\\Textures\\raid.tga",
	worldboss = "Interface\\AddOns\\ModernMapMarkers\\Textures\\worldboss.tga",
	zepp      = "Interface\\AddOns\\ModernMapMarkers\\Textures\\zepp.tga",
	boat      = "Interface\\AddOns\\ModernMapMarkers\\Textures\\boat.tga",
	tram      = "Interface\\AddOns\\ModernMapMarkers\\Textures\\tram.tga",
	portal    = "Interface\\AddOns\\ModernMapMarkers\\Textures\\portal.tga",
	skyship   = "Interface\\AddOns\\ModernMapMarkers\\Textures\\skyship.tga",
	leyline   = "Interface\\AddOns\\ModernMapMarkers\\Textures\\leyline.blp",
	convergence = "Interface\\AddOns\\ModernMapMarkers\\Textures\\convergence.blp",
	bgalliance = "Interface\\AddOns\\ModernMapMarkers\\Textures\\alliancebg.tga",
	bghorde   = "Interface\\AddOns\\ModernMapMarkers\\Textures\\hordebg.tga",
}

local TRANSPORT_KINDS = { boat = true, zepp = true, tram = true, portal = true, skyship = true }

-- Small pins: transports/battlegrounds plus the many-per-zone Skyborne resource nodes.
local SMALL_KINDS = { leyline = true, convergence = true, battleground = true }

-- Race-restricted kinds: only shown to the listed race(s), by race ID (the
-- third return of UnitRace, so it works on any client language). Both Skyborne
-- races share the token "Skyborne", so the token cannot tell them apart.
-- Run /mmm race to see what your character returns.
local RACE_ONLY = {
	leyline     = { 95 },  -- High Order Skyborne
	convergence = { 96 },  -- Windshaper Skyborne
}

-- ============================================================
-- Cached globals
-- ============================================================

local pairs, ipairs, type = pairs, ipairs, type
local tinsert  = table.insert
local tconcat  = table.concat
local math_sin = math.sin
local strfind  = string.find
local strsub   = string.sub

-- ============================================================
-- State
-- ============================================================

local pointsByMap        = {}
local markerPool         = {}
local markerPoolCount    = 0
local activeMarkers      = {}
local activeMarkersCount = 0
local initialized        = false
local setupDone          = false
local lastMapID          = 0
local frame              = CreateFrame("Frame")
local updateEnabled      = true
local flatDataCache
local pendingOriginMap

-- ============================================================
-- Global namespace  (shared with ModernMapMarkers_UI.lua)
-- ============================================================

MMM = MMM or {}

function MMM.ForceRedraw()
	lastMapID = 0
end

-- ============================================================
-- Small helpers
-- ============================================================

local function PlayClickSound()
	if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end
end

local function PlayPingSound()
	-- Path-based, like the 3.3.5a original. A missing file is silently ignored.
	PlaySoundFile("Sound\\Interface\\MapPing.wav")
end
MMM.PlayClickSound = PlayClickSound

local function IsAddOnLoadedCompat(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
	if IsAddOnLoaded then return IsAddOnLoaded(name) end
	return false
end
MMM.IsAddOnLoaded = IsAddOnLoadedCompat

local function GetCanvas()
	if WorldMapFrame.GetCanvas then return WorldMapFrame:GetCanvas() end
	return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end

local function GetPinLevel()
	local canvas = GetCanvas()
	local level
	if WorldMapFrame.GetPinFrameLevelsManager then
		local ok, v = pcall(function()
			return WorldMapFrame:GetPinFrameLevelsManager():GetValidFrameLevel("PIN_FRAME_LEVEL_TOPMOST")
		end)
		if ok and type(v) == "number" then level = v end
	end
	return level or ((canvas and canvas:GetFrameLevel() or 0) + PIN_LEVEL_FALLBACK)
end
MMM.GetPinLevel = GetPinLevel

-- Resolve an old {continent, zone} pair (or a raw uiMapID >= 1000) to a uiMapID.
local function ResolveMap(continent, zone)
	if type(zone) ~= "number" then return nil end
	if zone >= 1000 then return zone end
	local byContinent = MMM_ZoneToUiMap and MMM_ZoneToUiMap[continent]
	return byContinent and byContinent[zone] or nil
end

-- Walk up the parent chain until we reach Kalimdor (1414) or Eastern Kingdoms (1415).
-- Returns 1 or 2 (the continent indices used by the data), or nil.
function MMM.GetContinentForMap(mapID)
	local depth = 0
	while mapID and mapID > 0 and depth < 8 do
		local c = MMM_ContinentMaps and MMM_ContinentMaps[mapID]
		if c then return c end
		local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
		mapID = info and info.parentMapID
		depth = depth + 1
	end
	return nil
end

-- Turn the raw slot-8 destination data into a list of {map, label, nopulse}
-- plus a mode: "single", "dual" or "multi". Unresolvable destinations
-- (Outland, Northrend, Exodar, ...) are dropped.
local function NormalizeDest(dest)
	if type(dest) ~= "table" then return nil end
	local list = {}
	if type(dest[1]) == "table" then
		for i = 1, #dest do
			local d = dest[i]
			local map = ResolveMap(d[1], d[2])
			if map then
				tinsert(list, {
					map     = map,
					label   = (d[3] ~= "nopulse") and d[3] or nil,
					nopulse = (d[3] == "nopulse"),
				})
			end
		end
	else
		local map = ResolveMap(dest[1], dest[2])
		if map then list[1] = { map = map, nopulse = (dest[3] == "nopulse") } end
	end
	local n = #list
	if n == 0 then return nil end
	return list, (n == 1 and "single") or (n == 2 and "dual") or "multi"
end

-- ============================================================
-- ForeverDungeonJournal Lookup
-- ============================================================
local fdjLookup = {
	["ragefire_chasm"] = "rfc",
	["hall_of_thanes"] = "hall",
	["deadmines"] = "dm",
	["ruins_of_lordaeron"] = "ruins",
	["wailing_caverns_instance"] = "wc",
	["shadowfang_keep"] = "sfk",
	["blackfathom_deeps"] = "bfd"
}

-- ============================================================
-- Point index
-- ============================================================

local function BuildPointIndex()
	wipe(pointsByMap)
	flatDataCache = nil
	if not MMM_DefaultPoints then return end

	for continent, entries in pairs(MMM_DefaultPoints) do
		for i = 1, #entries do
			local p    = entries[i]
			local map  = ResolveMap(continent, p[1])
			local slot = p[8]
			if map then
				local rec = {
					continent = continent,
					map       = map,
					x         = p[2],
					y         = p[3],
					name      = p[4],
					kind      = p[5],
					info      = p[6],
					atlasID   = p[7],
					race      = p[9],
					noList    = (slot == "nolist"),
					dropdown  = (slot == "dropdown"),
					floor     = (type(slot) == "number") and slot or nil,
				}
				local keep = true
				if TRANSPORT_KINDS[p[5]] then
					rec.dests, rec.destMode = NormalizeDest(slot)
					keep = rec.dests ~= nil
				end
				if keep then
					local bucket = pointsByMap[map]
					if not bucket then
						bucket = {}
						pointsByMap[map] = bucket
					end
					tinsert(bucket, rec)
				end
			end
		end
	end
end

-- Returns a flat list of { continent, map, name, type, description, atlasID }
-- for the Find Marker panel. Transport and portal types are excluded.
-- Built once on first call and cached for the session.
function MMM.GetFlatData()
	if flatDataCache then return flatDataCache end
	local result = {}
	for _, bucket in pairs(pointsByMap) do
		for i = 1, #bucket do
			local rec = bucket[i]
			if not TRANSPORT_KINDS[rec.kind] and not rec.noList then
				tinsert(result, {
					continent   = rec.continent,
					map         = rec.map,
					name        = rec.name,
					type        = rec.kind,
					description = rec.info,
					atlasID     = rec.atlasID,
				})
			end
		end
	end
	flatDataCache = result
	return result
end

-- ============================================================
-- Pin sizing
-- ============================================================

local function ApplyPinSize(pin)
	local s = pin.originalSize * (pin.sizeMult or 1)
	pin:SetSize(s, s)
end

-- ============================================================
-- Marker pool
-- ============================================================

local function GetMarkerFromPool()
	if markerPoolCount > 0 then
		local marker = markerPool[markerPoolCount]
		markerPool[markerPoolCount] = nil
		markerPoolCount = markerPoolCount - 1
		return marker
	end
	local marker = CreateFrame("Button", nil, GetCanvas())
	marker.texture   = marker:CreateTexture(nil, "OVERLAY")
	marker.highlight = marker:CreateTexture(nil, "HIGHLIGHT")
	marker.highlight:SetBlendMode("ADD")
	return marker
end

local function ReturnMarkerToPool(marker)
	marker:Hide()
	marker:ClearAllPoints()
	marker:SetScript("OnEnter", nil)
	marker:SetScript("OnLeave", nil)
	marker:SetScript("OnClick", nil)
	marker:SetScript("OnUpdate", nil)
	marker.findTimer     = nil
	marker.sizeMult      = nil
	marker.markerName    = nil
	marker.markerDisplay = nil
	marker.markerInfo    = nil
	marker.markerHint    = nil
	marker.markerKind    = nil
	marker.atlasID       = nil
	marker.dungeonFloor  = nil
	marker.dests         = nil
	marker.destMode      = nil
	marker.originalSize  = nil
	if markerPoolCount < MAX_POOL_SIZE then
		markerPoolCount = markerPoolCount + 1
		markerPool[markerPoolCount] = marker
	else
		marker:SetParent(nil)
	end
end

-- ============================================================
-- Highlight (Find Marker / transport return pulse)
-- ============================================================

local function StartPinHighlight(pin)
	pin.highlight:SetAlpha(0)
	pin.findTimer = 0
	pin:SetScript("OnUpdate", function(self, elapsed)
		self.findTimer = self.findTimer + elapsed
		local progress = self.findTimer / FIND_HIGHLIGHT_DURATION
		if progress >= 1 then
			self.sizeMult = 1
			ApplyPinSize(self)
			self.highlight:SetAlpha(0)
			self.findTimer = nil
			self:SetScript("OnUpdate", nil)
		else
			local envelope = 1 - progress
			local pulse    = (math_sin(progress * 3.14159 * 8) + 1) * 0.5
			self.sizeMult  = 1 + (FIND_SIZE_MULTIPLIER - 1) * pulse * envelope
			ApplyPinSize(self)
			self.highlight:SetAlpha(FIND_HIGHLIGHT_ALPHA * pulse * envelope)
		end
	end)
end

-- Does this pin lead to map `mapID`?
local function PinLeadsTo(pin, mapID)
	local d = pin.dests
	if not d then return false end
	for i = 1, #d do
		if d[i].map == mapID then return true end
	end
	return false
end

-- Pulse the first active pin (other than `except`) that leads to `mapID`.
function MMM.HighlightOtherPin(mapID, except)
	for i = 1, activeMarkersCount do
		local pin = activeMarkers[i]
		if pin and pin ~= except and PinLeadsTo(pin, mapID) then
			StartPinHighlight(pin)
			return
		end
	end
end

-- ============================================================
-- Click handlers
-- ============================================================

local function SetMap(mapID)
	if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(mapID) end
end

-- Ctrl+Click on any marker (dungeon/raid/worldboss/transport alike): drop the
-- game's own map pin (the shift-click waypoint arrow) on that marker's exact
-- spot and start tracking it, instead of the marker's normal left/right click
-- behaviour.
local function SetWaypointAtPin(pin)
	if not (C_Map and C_Map.SetUserWaypoint and pin.waypointMap) then
		return false
	end
	if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(pin.waypointMap) then
		if UIErrorsFrame then
			UIErrorsFrame:AddMessage("Can't set a map pin here.", 1, 0.1, 0.1)
		end
		return false
	end

	local mapPointType = Enum and Enum.UIMapPointType and Enum.UIMapPointType.Map
	local point = {
		uiMapID      = pin.waypointMap,
		position     = CreateVector2D(pin.waypointX, pin.waypointY),
		mapPointType = mapPointType,
	}
	C_Map.SetUserWaypoint(point)
	if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
		C_SuperTrack.SetSuperTrackedUserWaypoint(true)
	end
	PlayPingSound()
	return true
end
MMM.SetWaypointAtPin = SetWaypointAtPin

-- Called by the destination popup in ModernMapMarkers_UI.lua.
function MMM.NavigateToTransportDest(destMapID, originMapID)
	pendingOriginMap = originMapID
	PlayPingSound()
	SetMap(destMapID)
	MMM.UpdateMarkers() -- no-op if the OnMapChanged hook already redrew
end

local function OnTransportClick(pin, button)
	local dests = pin.dests
	if not dests then return end

	-- Three or more destinations: delegate to the popup menu.
	if pin.destMode == "multi" then
		MMM.ShowDestMenu(pin)
		return
	end

	local chosen
	if pin.destMode == "dual" then
		chosen = (button == "RightButton") and dests[2] or dests[1]
	else
		chosen = dests[1]
	end

	local currentMap = WorldMapFrame:GetMapID()
	PlayPingSound()

	-- Same-map transport: highlight the other pin without navigating.
	if chosen.map == currentMap then
		MMM.HighlightOtherPin(currentMap, pin)
		return
	end

	-- Different map: navigate to destination and highlight the return marker.
	-- A "nopulse" destination intentionally skips the return highlight.
	if not chosen.nopulse then
		pendingOriginMap = currentMap
	end
	SetMap(chosen.map)
	MMM.UpdateMarkers() -- no-op if the OnMapChanged hook already redrew
end

-- ============================================================
-- Pin creation
-- ============================================================

local function CreateMapPin(rec, size, texture, mapWidth, mapHeight, mapID)
	local pin = GetMarkerFromPool()
	local canvas = GetCanvas()
	pin:SetParent(canvas)
	pin.originalSize = size
	pin.sizeMult     = 1
	ApplyPinSize(pin)
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", canvas, "TOPLEFT", rec.x * mapWidth, -rec.y * mapHeight)
	pin:SetFrameLevel(GetPinLevel())
	pin.texture:SetAllPoints()
	pin.texture:SetTexture(texture)
	pin.highlight:SetAllPoints()
	pin.highlight:SetTexture(texture)
	pin.highlight:SetAlpha(0)

	-- Own location, kept for the ctrl-click "set map pin" shortcut below.
	pin.waypointMap = mapID
	pin.waypointX   = rec.x
	pin.waypointY   = rec.y

	-- "dropdown" sentinel: comment shown only in Find Marker, not on the map.
	pin.markerDisplay = nil
	if rec.dropdown then
		local nl = strfind(rec.name, "\n")
		if nl then pin.markerDisplay = strsub(rec.name, 1, nl - 1) end
	end
	pin.markerName = rec.name
	pin.markerInfo = rec.info
	pin.markerKind = rec.kind
	pin.atlasID    = rec.atlasID
	pin.dungeonFloor = rec.floor
	pin.dests      = rec.dests
	pin.destMode   = rec.destMode
	pin.markerHint = nil

	if pin.destMode == "multi" then
		-- Hint line lists all destinations; the popup handles actual navigation.
		local parts = {}
		for i = 1, #pin.dests do
			tinsert(parts, pin.dests[i].label or ("Destination " .. i))
		end
		pin.markerHint = "|cFFFFD700Click for destinations:|r " .. tconcat(parts, ", ")
	elseif pin.destMode == "dual" then
		pin.markerHint = "|cFFFFD700Left-click:|r " .. (pin.dests[1].label or "Destination 1")
			.. "   |cFFFFD700Right-click:|r " .. (pin.dests[2].label or "Destination 2")
	end

	pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	pin:SetScript("OnEnter", function(self)
		local hint = ModernMapMarkersDB.showTransportHints and self.markerHint or nil
		MMM.ShowMarkerInfo(self, self.markerDisplay or self.markerName, self.markerInfo, hint)
		self.sizeMult = HOVER_SIZE_MULTIPLIER
		ApplyPinSize(self)
		self.highlight:SetAlpha(HOVER_ALPHA)
	end)
	pin:SetScript("OnLeave", function(self)
		MMM.HideMarkerInfo()
		self.sizeMult = 1
		ApplyPinSize(self)
		self.highlight:SetAlpha(0)
	end)
	pin:SetScript("OnClick", function(self, button)
		if IsControlKeyDown() then
			SetWaypointAtPin(self)
			return
		end
		if TRANSPORT_KINDS[self.markerKind] then
			OnTransportClick(self, button)
			return
		end
        
		-- Left-Click: Show the Dungeon/Raid Map overlay
		if self.markerKind == "dungeon" or self.markerKind == "raid" then
			local journalID = self.atlasID
			
			-- Handle Left-Click: Show the native Dungeon Map overlay
			if button == "LeftButton" then
				if MMM.ShowDungeonMapByID then
					MMM.ShowDungeonMapByID(journalID, self.dungeonFloor or 1)
			else
				print("MMM Debug: ERROR - MMM.ShowDungeonMapByID is nil!")
			end
		end

			-- Right-Click: Open ForeverDungeonJournal (Standard behavior)
			if button == "RightButton" then
				if SlashCmdList and SlashCmdList.FOREVERDUNGEONJOURNAL then
					local fdjQuery = journalID and fdjLookup[journalID] or ""
					SlashCmdList.FOREVERDUNGEONJOURNAL(fdjQuery)
					return
				end
				
				-- Fallback if FDJ is not installed: clear map and zoom out
				if MMM.HideDungeonMap then MMM.HideDungeonMap() end
				if WorldMapFrame and WorldMapFrame.NavigateToParentMap then
					WorldMapFrame:NavigateToParentMap()
				end
				return
			end
		end
	end)
	pin:Show()
	return pin
end

-- ============================================================
-- Marker display
-- ============================================================

local function ClearMarkers()
	for i = 1, activeMarkersCount do
		ReturnMarkerToPool(activeMarkers[i])
		activeMarkers[i] = nil
	end
	activeMarkersCount = 0
	MMM.HideMarkerInfo()
	if MMM.HideDestMenu then MMM.HideDestMenu() end
end

function MMM.ClearMarkers()
	ClearMarkers()
end

-- True if the player's race ID is in `ids` (a single ID or a list of IDs).
-- /mmm allraces (db.showAllRaces) bypasses every race restriction for testing.
local function RaceIDMatches(ids)
	local db = ModernMapMarkersDB
	if db and db.showAllRaces then return true end
	local _, _, raceID = UnitRace("player")
	if type(ids) == "table" then
		for i = 1, #ids do
			if ids[i] == raceID then return true end
		end
		return false
	end
	return ids == raceID
end

-- True if `kind` has no race restriction, or the player's race is allowed.
local function RaceAllowed(kind)
	local gate = RACE_ONLY[kind]
	if not gate then return true end
	return RaceIDMatches(gate)
end
MMM.RaceAllowed = RaceAllowed

local function ShouldDisplay(db, rec)
	local kind = rec.kind
	if not RaceAllowed(kind) then return false end
	-- Per-marker race restriction (MarkerData slot 9), e.g. a Skyborne-only portal.
	if rec.race and not RaceIDMatches(rec.race) then return false end
	if kind == "dungeon"   then return db.showDungeons end
	if kind == "raid"      then return db.showRaids end
	if kind == "worldboss" then return db.showWorldBosses end
	if kind == "leyline" then return db.showLeylines end
	if kind == "convergence" then return db.showConvergences end

	local factionKey
	if kind == "boat" then
		if not db.showBoats then return false end
		factionKey = db.transportFaction
	elseif kind == "zepp" then
		if not db.showZeppelins then return false end
		factionKey = db.transportFaction
	elseif kind == "skyship" then
		if not db.showSkyships then return false end
		factionKey = db.transportFaction
	elseif kind == "tram" then
		if not db.showTrams then return false end
		factionKey = db.transportFaction
	elseif kind == "portal" then
		if not db.showPortals then return false end
		factionKey = db.portalFaction
	elseif kind == "battleground" then
		if not db.showBattlegrounds then return false end
		factionKey = db.bgFaction
	else
		return false
	end
	if factionKey ~= "all" then
		return rec.info == factionKey or rec.info == "Neutral"
	end
	return true
end

local function UpdateMarkers()
	if not initialized or not setupDone or not updateEnabled then return end
	if not ModernMapMarkersDB.showMarkers or not WorldMapFrame:IsShown() then return end

	local mapID = WorldMapFrame:GetMapID()
	if not mapID or mapID == 0 then return end
	if mapID == lastMapID then return end

	lastMapID = mapID

	ClearMarkers()

	local canvas = GetCanvas()
	if not canvas then return end
	local mapWidth, mapHeight = canvas:GetWidth(), canvas:GetHeight()
	if not mapWidth or mapWidth == 0 or mapHeight == 0 then
		-- Canvas not laid out yet; try again on the next map event.
		lastMapID = 0
		return
	end

	local relevantPoints = pointsByMap[mapID]
	if not relevantPoints then return end

	local db = ModernMapMarkersDB
	for i = 1, #relevantPoints do
		local rec = relevantPoints[i]
		if ShouldDisplay(db, rec) then
			local size = (TRANSPORT_KINDS[rec.kind] or SMALL_KINDS[rec.kind]) and MARKER_SIZE_SMALL or MARKER_SIZE_LARGE
			local texture = TEXTURES[rec.kind]
			if rec.kind == "battleground" then
				-- Entrances are faction-specific: the icon follows the info field.
				texture = (rec.info == "Horde") and TEXTURES.bghorde or TEXTURES.bgalliance
			end
			local pin  = CreateMapPin(rec, size, texture, mapWidth, mapHeight, mapID)
			activeMarkersCount = activeMarkersCount + 1
			activeMarkers[activeMarkersCount] = pin
		end
	end

	-- Trigger a Find Marker highlight if one is pending.
	if MMM.pendingHighlight then
		local target = MMM.pendingHighlight
		MMM.pendingHighlight = nil
		for i = 1, activeMarkersCount do
			local pin = activeMarkers[i]
			if pin and pin.markerName == target then
				StartPinHighlight(pin)
				break
			end
		end
	end

	-- Highlight the return transport after a transport click.
	if pendingOriginMap then
		local origin = pendingOriginMap
		pendingOriginMap = nil
		for i = 1, activeMarkersCount do
			local pin = activeMarkers[i]
			if pin and PinLeadsTo(pin, origin) then
				StartPinHighlight(pin)
				break
			end
		end
	end
end

function MMM.UpdateMarkers()
	UpdateMarkers()
end

-- Enable/disable redrawing (used by the "All Markers" toggle).
function MMM.SetUpdateEnabled(state)
	updateEnabled = state and true or false
end

function MMM.RefreshVisibleTooltip()
	local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
	if owner and owner.markerName and owner.originalSize then
		local hint = ModernMapMarkersDB.showTransportHints and owner.markerHint or nil
		MMM.ShowMarkerInfo(owner, owner.markerDisplay or owner.markerName, owner.markerInfo, hint)
	end
end

-- ============================================================
-- Saved variables
-- ============================================================

local DEFAULTS = {
	showMarkers        = true,
	showDungeons       = true,
	showRaids          = true,
	showWorldBosses    = true,
	showBoats          = true,
	showZeppelins      = true,
	showSkyships       = true,
	showTrams          = true,
	showPortals        = true,
	showLeylines       = true,
	showConvergences   = true,
	showAllRaces       = false, -- debug: /mmm allraces
	transportFaction   = "all",
	portalFaction      = "all",
	showBattlegrounds  = true,
	bgFaction          = "all",
	showTransportHints = true,
}

-- Forever's SavedVariables layer has been seen writing booleans back as the
-- numbers 1/0 instead of true/false. That is NOT a cosmetic difference in
-- Lua: unlike most languages, 0 is truthy here (only nil and false are
-- falsy), so a stored "off" (0) would silently behave as "on" everywhere
-- we check "if db.showX then", and "not db.showX" toggles would misfire.
-- Coerce anything we get back to a real boolean before using it.
local function ToBoolean(value, default)
	if value == nil    then return default end
	if value == true  or value == 1 then return true end
	if value == false or value == 0 then return false end
	return default
end

local function InitializeSavedVariables()
	if not ModernMapMarkersDB then ModernMapMarkersDB = {} end
	local db = ModernMapMarkersDB
	for k, v in pairs(DEFAULTS) do
		if type(v) == "boolean" then
			db[k] = ToBoolean(db[k], v)
		elseif db[k] == nil then
			db[k] = v
		end
	end
end

-- ============================================================
-- Setup: hook the map once WorldMapFrame exists
-- ============================================================

local function TrySetup()
	if setupDone or not initialized then return end
	if not WorldMapFrame or not GetCanvas() then return end
	setupDone = true

	-- MapCanvasMixin:OnMapChanged runs after every SetMapID / navigation.
	if WorldMapFrame.OnMapChanged then
		hooksecurefunc(WorldMapFrame, "OnMapChanged", function() UpdateMarkers() end)
	end
    
	-- NEW: When you right-click the map to zoom out, automatically clear the dungeon map overlay
	if WorldMapFrame.NavigateToParentMap then
		hooksecurefunc(WorldMapFrame, "NavigateToParentMap", function()
			if MMM.HideDungeonMap then MMM.HideDungeonMap() end
		end)
	end

	WorldMapFrame:HookScript("OnShow", function()
		lastMapID = 0
		UpdateMarkers()
	end)
	WorldMapFrame:HookScript("OnHide", function()
		ClearMarkers()
		lastMapID = 0
	end)

	if MMM.SetupUI then MMM.SetupUI() end

	if WorldMapFrame:IsShown() then UpdateMarkers() end
end

-- ============================================================
-- Event handling
-- ============================================================

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "ModernMapMarkers" then
			InitializeSavedVariables()
			BuildPointIndex()
			initialized = true
			TrySetup()
		elseif arg1 == "Blizzard_WorldMap" then
			-- WorldMapFrame can be load-on-demand; finish setup once it exists.
			TrySetup()
		end
	elseif event == "PLAYER_LOGIN" then
		-- SavedVariables can arrive late on the beta; make sure defaults exist.
		if initialized then InitializeSavedVariables() end
		TrySetup()
	elseif event == "PLAYER_ENTERING_WORLD" then
		lastMapID = 0
		TrySetup()
	end
end)
