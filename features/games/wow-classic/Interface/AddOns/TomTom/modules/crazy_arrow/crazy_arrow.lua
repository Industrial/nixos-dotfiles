--[[--------------------------------------------------------------------------
--  TomTom - A navigational assistant for World of Warcraft
--
--  CrazyTaxi: A crazy-taxi style arrow used for waypoint navigation.
--    concept taken from MapNotes2 (Thanks to Mery for the idea, along
--    with the original artwork.)
----------------------------------------------------------------------------]]

local addonName, addon = ...
local TomTom = addon

local L = addon.L
addon.private = addon.private or {}
local private = addon.private

local IMAGE_ARROW_UP = "Interface\\AddOns\\TomTom\\Images\\Arrow-UP-1024"

-- SetScale(0) is an error. Older versions let the sliders go to 0, so a
-- saved profile can still hold 0.
local MIN_SCALE = 0.05

local themeHandler = addon.CrazyArrowThemeHandler

-- The frame, the theme handler and the public arrow methods exist also while
-- the module is off: other addons hook them and replace the OnClick script
-- (integrations.md 3.4 items 1 and 8). The defaults of the arrow namespace
-- are in core/settings.lua, because the core reads some of them.
local module = {settingsKey = "arrow"}
private.AddModule(module, "CrazyArrow")

local wayframe = CreateFrame("Button", "TomTomCrazyArrow", UIParent)
wayframe:EnableMouse(true)
wayframe:SetMovable(true)
wayframe:SetClampedToScreen(true)
wayframe:Hide()

-- Frame used to control the scaling of the title and friends
local titleframe = CreateFrame("Frame", nil, wayframe)

wayframe.title = titleframe:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
wayframe.status = titleframe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
wayframe.tta = titleframe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
wayframe.title:SetPoint("TOP", wayframe, "BOTTOM", 0, 0)
wayframe.status:SetPoint("TOP", wayframe.title, "BOTTOM", 0, 0)
wayframe.tta:SetPoint("TOP", wayframe.status, "BOTTOM", 0, 0)

-- The first cell of each theme's sprite sheet, for the settings images.
local THEME_IMAGES = {
	classic = {
		texture = "Interface\\AddOns\\TomTom\\Images\\Arrow-1024",
		texW = 1024, texH = 1024, cellW = 112, cellH = 84,
	},
	modern = {
		texture = "Interface\\AddOns\\TomTom\\Images\\Modern\\ArrowNavColour",
		texW = 2304, texH = 3072, cellW = 256, cellH = 256,
	},
	["modern-top-down"] = {
		texture = "Interface\\AddOns\\TomTom\\Images\\Modern\\ArrowNavTopDownColour",
		texW = 2304, texH = 3072, cellW = 256, cellH = 256,
	},
}

local function ThemeImage(key, size)
	-- An unknown key can come from an old or shared profile. Show the
	-- arrow.theme default, as the theme handler does.
	local image = THEME_IMAGES[key] or THEME_IMAGES.modern
	return {
		texture = image.texture,
		coords = {0, image.cellW / image.texW, 0, image.cellH / image.texH},
		width = size,
		height = size * image.cellH / image.cellW,
	}
end

local function ThemeMarkup(key, size)
	local image = THEME_IMAGES[key]
	if not image then
		return ""
	end
	-- Keep the cell's aspect ratio; the classic cells are 112 x 84.
	local height = math.floor(size * image.cellH / image.cellW + 0.5)
	return string.format("|T%s:%d:%d:0:0:%d:%d:0:%d:0:%d|t ", image.texture, height, size,
		image.texW, image.texH, image.cellW, image.cellH)
end

local function ThemeValues()
	local values = {}
	for key, theme in pairs(themeHandler.themes) do
		values[key] = ThemeMarkup(key, 16) .. theme.name
	end
	return values
end

private.AddSettingsSection{
	page = "arrow", pageName = L["Waypoint Arrow"], pageOrder = 10,
	settingsKey = "arrow",
	feature = {name = L["Enable floating waypoint arrow"]},
	rows = {
		{type = "text", text = L["TomTom provides an arrow that can be placed anywhere on the screen.  Similar to the arrow in \"Crazy Taxi\" it will point you towards your next waypoint"]},
		{type = "toggle", key = "autoqueue", name = L["Automatically set waypoint arrow"],
		 tooltip = L["When a new waypoint is added, TomTom can automatically set the new waypoint as the \"Crazy Arrow\" waypoint."]},
		{type = "toggle", key = "lock", name = L["Lock waypoint arrow"],
		 tooltip = L["Locks the waypoint arrow, so it can't be moved accidentally"]},
		{type = "toggle", key = "menu", name = L["Enable the right-click contextual menu"],
		 tooltip = L["Enables a menu when right-clicking on the waypoint arrow allowing you to clear or remove waypoints"]},
		{type = "toggle", key = "noclick", name = L["Disable all mouse input"],
		 tooltip = L["Disables the crazy taxi arrow for mouse input, allowing all clicks to pass through"]},
		{type = "toggle", key = "setclosest", name = L["Automatically set to next closest waypoint"], suppress = "arrow.setclosest",
		 tooltip = L["When the current waypoint is cleared (either by the user or automatically) and this option is set, TomTom will automatically set the closest waypoint in the current zone as active waypoint."]},
		{type = "toggle", key = "closestusecontinent", name = L["Allow closest waypoint to be outside current zone"],
		 tooltip = L["Normally when TomTom sets the closest waypoint it chooses the waypoint in your current zone. This option will cause TomTom to search for any waypoints on your current continent. This may lead you outside your current zone, so it is disabled by default."]},
		{type = "range", key = "arrival", name = L["\"Arrival Distance\""],
		 tooltip = L["This setting will control the distance at which the waypoint arrow switches to a downwards arrow, indicating you have arrived at your destination"],
		 min = 0, max = 150, step = 1},
		{type = "toggle", key = "enablePing", name = L["Play a sound when arriving at a waypoint"],
		 tooltip = L["When you 'arrive' at a waypoint (this distance is controlled by the 'Arrival Distance' setting in this group) a sound can be played to indicate this.  You can enable or disable this sound using this setting."]},
		{type = "select", key = "pingChannel", name = L["Channel to play the ping through"],
		 tooltip = L["When a 'ping' is played, use the indicated sound channel so the volume can be controlled."],
		 values = {
			["Master"] = MASTER_VOLUME,
			["SFX"] = SOUND_VOLUME,
			["Music"] = MUSIC_VOLUME,
			["Ambience"] = AMBIENCE_VOLUME,
			["Dialog"] = DIALOG_VOLUME,
		 }},
		{type = "toggle", key = "hideDuringPetBattles", name = L["Hide the crazy arrow display during pet battles"],
		 tooltip = L["When a pet battle begins, the crazy arrow will be hidden from view. When you exit the pet battle, it will be re-shown."]},
		{type = "toggle", key = "stickycorpse", name = L["Allow the corpse arrow to override other waypoints"],
		 tooltip = L["When the player is dead and has a waypoint towards their corpse, it will prevent other waypoints from changing the crazy arrow"]},
		{type = "toggle", key = "highstrata", name = L["Place the arrow in the HIGH strata"],
		 tooltip = L["If your arrow is covered up by something else, try this to bump it up a layer."]},

		{type = "header", name = L["Themes"]},
		{type = "text", text = L["There are a few different themes that you can apply to the waypoint arrow, use this section to configure."]},
		{type = "select", key = "theme", name = L["Theme"],
		 tooltip = L["You can customize the display of the crazy arrow with a variety of themes."],
		 values = ThemeValues, sorting = {"classic", "modern", "modern-top-down"}},
		{type = "preview", watch = {"theme"},
		 imageFunc = function() return ThemeImage(TomTom.db.profile.arrow.theme, 64) end,
		 textFunc = function()
			local theme = themeHandler.themes[TomTom.db.profile.arrow.theme]
			return theme and theme.name or ""
		 end},

		{type = "header", name = L["Arrow display"]},
		{type = "text", text = L["These options let you customize the size and opacity of the waypoint arrow, making it larger or partially transparent, as well as limiting the size of the title display."]},
		{type = "toggle", key = "showtta", name = L["Show estimated time to arrival"],
		 tooltip = L["Shows an estimate of how long it will take you to reach the waypoint at your current speed"]},
		{type = "toggle", key = "showdistance", name = L["Show the distance to the waypoint"],
		 tooltip = L["Shows the distance (in yards) to the waypoint"]},
		{type = "select", key = "distanceUnits", name = L["Distance unit to use"],
		 tooltip = L["Configures which unit (yards, metrics, auto) to show distances in"],
		 values = {
			["auto"] = "Automatic (yards for US, metric elsewhere)",
			["yards"] = "Show the distance in yards",
			["meters"] = "Show the distance in meters",
			["humanyards"] = "Show distance in miles and yards",
			["humanmeters"] = "Show distance in km and meters",
		 }},
		{type = "range", key = "scale", name = L["Scale"],
		 tooltip = L["This setting allows you to change the scale of the waypoint arrow, making it larger or smaller"],
		 min = MIN_SCALE, max = 3, step = 0.05},
		{type = "range", key = "alpha", name = L["Alpha"],
		 tooltip = L["This setting allows you to change the opacity of the waypoint arrow, making it transparent or opaque"],
		 min = 0.1, max = 1.0, step = 0.05},
		{type = "range", key = "title_width", name = L["Title Width"],
		 tooltip = L["This setting allows you to specify the maximum width of the title text.  Any titles that are longer than this width (in game pixels) will be wrapped to the next line."],
		 min = 0, max = 500, step = 1},
		{type = "range", key = "title_height", name = L["Title Height"],
		 tooltip = L["This setting allows you to specify the maximum height of the title text.  Any titles that are longer than this height (in game pixels) will be truncated."],
		 min = 0, max = 300, step = 1},
		{type = "range", key = "title_scale", name = L["Title Scale"],
		 tooltip = L["This setting allows you to specify the scale of the title text."],
		 min = MIN_SCALE, max = 3, step = 0.05},
		{type = "range", key = "title_alpha", name = L["Title Alpha"],
		 tooltip = L["This setting allows you to change the opacity of the title text, making it transparent or opaque"],
		 min = 0, max = 1.0, step = 0.05},
		{type = "execute", name = L["Reset Position"],
		 tooltip = L["Resets the position of the waypoint arrow if it has been dragged off screen"],
		 func = function()
			wayframe:ClearAllPoints()
			local pos = {"CENTER", nil , "CENTER", 0, 0}
			private.SetSetting("arrow", "position", pos)
			wayframe:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])
		 end},

		{type = "header", name = L["Arrow colors"]},
		{type = "text", text = L["The floating waypoint arrow can change color depending on whether or not you are facing your destination.  By default it will display green when you are facing it directly, and red when you are facing away from it.  These colors can be changed in this section.  Setting these options to the same color will cause the arrow to not change color at all"]},
		{type = "color", key = "goodcolor", name = L["Good color"],
		 tooltip = L["The color to be displayed when you are moving in the direction of the active waypoint"]},
		{type = "color", key = "middlecolor", name = L["Middle color"],
		 tooltip = L["The color to be displayed when you are halfway between the direction of the active waypoint and the completely wrong direction"]},
		{type = "color", key = "badcolor", name = L["Bad color"],
		 tooltip = L["The color to be displayed when you are moving in the opposite direction of the active waypoint"]},
		{type = "color", key = "exactcolor", name = L["Exact color"],
		 tooltip = L["The color to be displayed when you are moving in the exact direction of the active waypoint"]},
	},
}

local function ShowCrazyArrow()
	wayframe:Show()
end

local function OnDragStart(self, button)
	if not TomTom.db.profile.arrow.lock then
		self:StartMoving()
	end
end

local function OnDragStop(self, button)
	self:StopMovingOrSizing()
	self:SetUserPlaced(false)
	-- point, relativeTo, relativePoint, xOfs, yOfs
	TomTom.profile.arrow.position = { self:GetPoint() }
	TomTom.profile.arrow.position[2] = nil  -- Note we are relative to UIParent
end

local function OnEvent(self, event, ...)
	if (event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED") and TomTom.profile.arrow.enable then
		ShowCrazyArrow()
		return
	end
	if (event == "PLAYER_ENTERING_WORLD") then
		wayframe:ClearAllPoints()
		if not TomTom.profile.arrow.position then
			TomTom.profile.arrow.position = {"CENTER", nil , "CENTER", 0, 0}
		end
		local pos = TomTom.profile.arrow.position
		wayframe:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])
	end
end

wayframe:SetScript("OnDragStart", OnDragStart)
wayframe:SetScript("OnDragStop", OnDragStop)
wayframe:RegisterForDrag("LeftButton")
wayframe:RegisterEvent("ZONE_CHANGED_NEW_AREA")
wayframe:RegisterEvent("ZONE_CHANGED")
wayframe:RegisterEvent("PLAYER_ENTERING_WORLD")
wayframe:SetScript("OnEvent", OnEvent)



local active_point, arrive_distance, showDownArrow, point_title
local ClearTarget
-- Set when the target waypoint was removed: the next OnUpdate moves the
-- arrow to the closest waypoint. It waits for OnUpdate, because at the time
-- of the removal the waypoint is still in the store.
local closestPending

-- The frame also shows with no target (ShowHideCrazyArrow, a zone change),
-- and the next OnUpdate hides it. Such a frame shows nothing useful, so it
-- does not count, and ArrowVisibilityChanged does not fire twice for it.
-- After the target is removed, the next OnUpdate picks the closest
-- waypoint (closestPending); that frame counts, so a retarget does not
-- fire "hidden" and then "shown".
local arrowShown = false

local function IsArrowShown()
	return wayframe:IsVisible()
		and (active_point ~= nil or closestPending == true or wayframe.hijacked == true)
end

local function UpdateArrowShown()
	local shown = IsArrowShown()
	if shown ~= arrowShown then
		arrowShown = shown
		TomTom:FireMessage("TOMTOM_ARROW_VISIBILITY_CHANGED", shown)
	end
end

wayframe:SetScript("OnShow", UpdateArrowShown)
wayframe:SetScript("OnHide", UpdateArrowShown)
TomTom:RegisterMessage("TOMTOM_ARROW_TARGET_CHANGED", UpdateArrowShown)

function TomTom:SetCrazyArrow(uid, dist, title)
	if active_point and active_point.corpse and self.db.profile.arrow.stickycorpse then
		-- do not change the waypoint arrow from corpse
		return
	end

	active_point = uid
	arrive_distance = dist
	point_title = title
	closestPending = false

	-- Set also while the arrow is off, so it has the title when it comes on.
	wayframe.title:SetText(title or L["Unknown waypoint"])
	if self.profile.arrow.enable then
		ShowCrazyArrow()
	end

	-- Last: a listener can set another target.
	self:FireMessage("TOMTOM_ARROW_TARGET_CHANGED", uid)
end

-- The target also clears without SetCrazyArrow, so this tells the feed and
-- the public ArrowTargetChanged callback.
ClearTarget = function()
	active_point = nil
	TomTom:FireMessage("TOMTOM_ARROW_TARGET_CHANGED", nil)
end

-- For the arrow LDB feed (modules/feeds.lua).
function private.GetCrazyArrowTarget()
	return active_point, point_title
end

function TomTom:IsCrazyArrowEmpty()
	return not active_point
end

-- The target leaves the active set (removed, or dropped by a reload). Also
-- while the arrow is off, hidden or hijacked, so that IsCrazyArrowEmpty and
-- ArrowTargetChanged are right.
TomTom:RegisterMessage("TOMTOM_WAYPOINT_REMOVED", function(_, uid)
	if uid == active_point then
		-- Set before the clear: the arrow that waits for the closest
		-- waypoint still counts as shown (IsArrowShown).
		closestPending = true
		ClearTarget()
		closestPending = not active_point
	end
end)

-- The target is gone. A listener of the clear can set a new target, and
-- that target stays. Returns true when the arrow has something to do.
local function TargetGone()
	ClearTarget()
	if active_point then
		return true
	end
	if private.ShouldSetClosest() then
		TomTom:SetClosestWaypoint()
		return true
	end
	return false
end

-- The arrow texture of the active theme (integrations.md I4). The theme
-- changes fire the ArrowThemeChanged callback.
function TomTom:GetCrazyArrowTexture()
	local active = themeHandler.active
	return active and active.tbl.arrowTexture
end

local status = wayframe.status
local tta = wayframe.tta
local last_distance = 0
local tta_throttle = 0
local speed = 0
local speed_count = 0

local function OnUpdate(self, elapsed)
	if not active_point then
		if closestPending then
			closestPending = false
			if private.ShouldSetClosest() then
				TomTom:SetClosestWaypoint()
				if active_point then return end
			end
		end
		self:Hide()
		return
	end

	local dist,x,y = TomTom:GetDistanceToWaypoint(active_point)

	-- The only time we cannot calculate the distance is when the waypoint
	-- is on another continent, or we are in an instance
	if not dist then
		if not TomTom:IsValidWaypoint(active_point) and TargetGone() then
			return
		end

		self:Hide()
		return
	end

	status:SetText(addon:GetFormattedDistance(dist))

	-- Showing the arrival arrow?
	if dist <= arrive_distance then
		if not showDownArrow then
			themeHandler:SwitchToArrivalArrow(wayframe)
			showDownArrow = true
		end

		themeHandler:ArrivalArrow_OnUpdate(elapsed)
	else
		if showDownArrow then
			themeHandler:SwitchToNavigationArrow(wayframe)
			showDownArrow = false
		end

		local angle = TomTom:GetDirectionToWaypoint(active_point)
		local player = GetPlayerFacing()

		if not player then
			if not TomTom:IsValidWaypoint(active_point) and TargetGone() then
				return
			end
			self:Hide()
			return
		end

		angle = angle - player

		themeHandler:NavigationArrow_OnUpdate(elapsed, angle)
	end

	-- Calculate the TTA every second  (%01d:%02d)

	tta_throttle = tta_throttle + elapsed

	if tta_throttle >= 1.0 then
		-- Calculate the speed in yards per sec at which we're moving
		local current_speed = (last_distance - dist) / tta_throttle

		if last_distance == 0 then
			current_speed = 0
		end

		if speed_count < 2 then
			speed = (speed + current_speed) / 2
			speed_count = speed_count + 1
		else
			speed_count = 0
			speed = current_speed
		end

		if speed > 0 then
			local eta = math.abs(dist / speed)
			tta:SetFormattedText("%s:%02d", math.floor(eta / 60), math.floor(eta % 60))
		else
			tta:SetText("***")
		end

		last_distance = dist
		tta_throttle = 0
	end
end

local function ApplyArrowSettings(self)
	if self.profile.arrow.enable then
		if self.profile.arrow.hideDuringPetBattles and C_PetBattles and C_PetBattles.IsInBattle() then
			wayframe:Hide()
			return
		end

		ShowCrazyArrow()

		if self.profile.arrow.noclick then
			wayframe:EnableMouse(false)
		else
			wayframe:EnableMouse(true)
		end

		-- Set the scale and alpha
		wayframe:SetScale(math.max(TomTom.db.profile.arrow.scale, MIN_SCALE))
		-- Do not allow the arrow to be invisible
		if TomTom.db.profile.arrow.alpha < 0.1 then
			TomTom.db.profile.arrow.alpha = 1.0
		end
		-- Set the stratum
		if TomTom.db.profile.arrow.highstrata then
			wayframe:SetFrameStrata("HIGH")
		else
			wayframe:SetFrameStrata("MEDIUM")
		end
		wayframe:SetAlpha(TomTom.db.profile.arrow.alpha)
		local width = TomTom.db.profile.arrow.title_width
		local height = TomTom.db.profile.arrow.title_height
		local scale = TomTom.db.profile.arrow.title_scale

		wayframe.title:SetWidth(width)
		wayframe.title:SetHeight(height)
		titleframe:SetScale(math.max(scale, MIN_SCALE))
		titleframe:SetAlpha(TomTom.db.profile.arrow.title_alpha)

		if self.profile.arrow.showdistance then
			wayframe.status:Show()
			wayframe.tta:ClearAllPoints()
			wayframe.tta:SetPoint("TOP", wayframe.status, "BOTTOM", 0, 0)
		else
			wayframe.status:Hide()
			wayframe.tta:ClearAllPoints()
			wayframe.tta:SetPoint("TOP", wayframe, "BOTTOM", 0, 0)
		end

		-- Set the theme
		local theme = self.profile.arrow.theme
		themeHandler:SetActiveTheme(wayframe, theme, showDownArrow)

		if self.profile.arrow.showtta then
			tta:Show()
		else
			tta:Hide()
		end
	else
		wayframe:Hide()
	end
end

-- The settings code runs in a local function, so the event also fires
-- after the early return of a pet battle. Kaliel's Tracker replaces this
-- method and calls the original, so the event still fires.
local applyingSettings = false

function TomTom:ShowHideCrazyArrow()
	ApplyArrowSettings(self)
	-- A listener can call ShowHideCrazyArrow. Without this guard, that
	-- call would fire the event again, with no end.
	if not applyingSettings then
		applyingSettings = true
		self:FireMessage("TOMTOM_ARROW_SETTINGS_APPLIED", IsArrowShown())
		applyingSettings = false
	end
end

wayframe:SetScript("OnUpdate", OnUpdate)

-- Kaliel's Tracker replaces ShowHideCrazyArrow, so each change goes through
-- the addon table (integrations.md 3.4 item 7). ReloadOptions calls it on a
-- profile change, so the module has no OnProfileChanged.
function module:OnEnable()
	TomTom:ShowHideCrazyArrow()
end

function module:OnDisable()
	TomTom:ShowHideCrazyArrow()
end

function module:OnSettingChanged()
	TomTom:ShowHideCrazyArrow()
end

-- OnSettingChanged runs only while the arrow is on. Kaliel's Tracker
-- applies its overrides (for example arrow.setclosest) in its replacement,
-- so a change while the arrow is off still calls the method. The module
-- system handles arrow.enable itself.
TomTom:RegisterMessage("TOMTOM_SETTING_CHANGED", function(_, namespace, key)
	if namespace == "arrow" and key ~= "enable" and not module:IsEnabled() then
		TomTom:ShowHideCrazyArrow()
	end
end)


--[[-------------------------------------------------------------------------
--  Dropdown
-------------------------------------------------------------------------]]--

local function crazyArrowDropdownGenerator(owner, rootDescription)
	rootDescription:CreateTitle(L["TomTom Waypoint Arrow"]);

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
		addon:ClearCrazyArrowPoint(true)
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

	local locked = addon.db.profile.arrow.lock
	rootDescription:CreateButton(locked and L["Unlock crazy arrow"] or L["Lock crazy arrow"], function()
		private.SetSetting("arrow", "lock", not locked)
	end)
end

local function WayFrame_OnClick(self, button)
	if active_point then
		if addon.db.profile.arrow.menu then
			addon.dropdown_uid = active_point
			MenuUtil.CreateContextMenu(self, crazyArrowDropdownGenerator)
		end
	end
end

wayframe:RegisterForClicks("RightButtonUp")
wayframe:SetScript("OnClick", WayFrame_OnClick)
private.CrazyArrow_OnClick = WayFrame_OnClick


--[[-------------------------------------------------------------------------
--  API for manual control of Crazy Arrow
--
--  This allow for an addon to specify their own control of the waypoint
--  arrow without needing to tip-toe around the API.  It may not integrate
--  properly, but in general it should work.
--
--  Example Usage:
--
--  if not TomTom:CrazyArrowIsHijacked() then
--    TomTom:HijackCrazyArrow(function(self, elapsed)
--      -- Random angle
--      local angle = math.random(math.pi * 2)
--      TomTom:SetCrazyArrowDirection(angle)
--      -- Random color
--      local r = math.random(100) / 100
--      local g = math.random(100) / 100
--      local b = math.random(100) / 100
--      TomTom:SetCrazyArrowColor(r, g, b)
--      -- Titles
--      TomTom:SetCrazyArrowTitle("Hijacked arrow", "Hijacked", "You will never arrive")
--    end)
--  end
--
--  -- At some point later
--  TomTom:ReleaseCrazyArrow()
-------------------------------------------------------------------------]]--

-- This function changes showDownArrow, so the normal OnUpdate knows which
-- texture shows after the release.
local function ShowNavigationArrow()
	if showDownArrow then
		themeHandler:SwitchToNavigationArrow(wayframe)
		showDownArrow = false
	end
end

-- Set the direction of the crazy arrow without taking the player's facing
-- into consideration.  This can be accomplished by subtracting
-- GetPlayerFacing() from the angle before passing it in.
function TomTom:SetCrazyArrowDirection(angle)
	ShowNavigationArrow()
	themeHandler:SetDirection(angle)
end

-- Convenience function to set the color of the crazy arrow
function TomTom:SetCrazyArrowColor(r, g, b, a)
	themeHandler:SetColor(r, g, b, a)
end

-- Convenience function to set the title/status and time to arrival text
-- of the crazy arrow.
function TomTom:SetCrazyArrowTitle(title, status, tta)
	wayframe.title:SetText(title)
	wayframe.status:SetText(status)
	wayframe.tta:SetText(tta)
end

-- Function to actually hijack the crazy arrow by replacing the OnUpdate script
function TomTom:HijackCrazyArrow(onupdate)
	-- With the arrow off, ShowHideCrazyArrow never applied a theme, so the
	-- frame would show with no texture (B19).
	if not themeHandler.active then
		themeHandler:SetActiveTheme(wayframe, TomTom.profile.arrow.theme, showDownArrow)
	end
	wayframe:SetScript("OnUpdate", onupdate)
	wayframe.hijacked = true
	ShowCrazyArrow()
	-- OnShow does not run when the frame already shows.
	UpdateArrowShown()
end

-- Releases the crazy arrow by restoring the original OnUpdate script
function TomTom:ReleaseCrazyArrow()
	-- The modern themes never set a vertex color themselves, so the hijack
	-- color would stay. Classic sets its color again in the normal OnUpdate
	-- and in SwitchToArrivalArrow. The normal OnUpdate calls
	-- SwitchToArrivalArrow again, because showDownArrow is now false.
	ShowNavigationArrow()
	themeHandler:ResetColor()
	wayframe:SetScript("OnUpdate", OnUpdate)
	wayframe.hijacked = false
	UpdateArrowShown()
end

-- Returns whether or not the crazy arrow is currently hijacked
function TomTom:CrazyArrowIsHijacked()
	return wayframe.hijacked
end

-- Logs Crazy Arrow status
function TomTom:DebugCrazyArrow()
	local msg
	msg = string.format(L["|cffffff78TomTom:|r CrazyArrow %s hijacked"], (wayframe.hijacked and L["is"]) or L["not"])
	ChatFrame1:AddMessage(msg)
	msg = string.format(L["|cffffff78TomTom:|r CrazyArrow %s visible"], (wayframe:IsVisible() and L["is"]) or L["not"])
	ChatFrame1:AddMessage(msg)
	msg = string.format(L["|cffffff78TomTom:|r Waypoint %s valid"], (active_point and TomTom:IsValidWaypoint(active_point) and L["is"]) or L["not"])
	ChatFrame1:AddMessage(msg)

	local dist,x,y = TomTom:GetDistanceToWaypoint(active_point)
	msg = string.format("|cffffff78TomTom:|r Waypoint distance=%s", tostring(dist))
	ChatFrame1:AddMessage(msg)

	if wayframe:IsVisible() then
		local point, relativeTo, relativePoint, xOfs, yOfs = wayframe:GetPoint(1)
		relativeTo = (relativeTo and relativeTo:GetName()) or "UIParent"
		msg = string.format("|cffffff78TomTom:|r CrazyArrow point=%s frame=%s rpoint=%s xo=%.2f yo=%.2f",  point, relativeTo, relativePoint, xOfs, yOfs)
		ChatFrame1:AddMessage(msg)
	end
end

-- Clear the waypoint from the crazy arrow
--   remove: true if the waypoint should be removed entirely, otherwise
--   this method only clears it from the crazy arrow itself.
function TomTom:ClearCrazyArrowPoint(remove)
	if active_point then
		if remove then
			local uid = active_point
			TomTom:RemoveWaypoint(uid)
		else
			local prior = active_point
			ClearTarget()
			if active_point then
				return
			end
			if private.ShouldSetClosest() then
				local uid = TomTom:GetClosestWaypoint()
				if uid and uid ~= prior then
					TomTom:SetClosestWaypoint()
					return
				end
			end
		end
	end
end

local regionsAreMetric = {
	false, -- US
	true,
	true,
	true,
	true,
}

function TomTom:RegionIsMetric()
	if self.accountRegion == nil then
		local gameAccountInfo = C_BattleNet.GetGameAccountInfoByGUID(UnitGUID("player"))
		local regionID = gameAccountInfo and gameAccountInfo.regionID or GetCurrentRegion()
		self.accountRegion = regionID
	end

	if regionsAreMetric[self.accountRegion] ~= nil then
		return regionsAreMetric[self.accountRegion]
	else
		-- Default to true
		return true
	end
end

local floor = math.floor

local function yardsToMeters(yards)
	local meters = yards * 0.9144
	return meters
end

local function humanizeYardsMiles(yards)
	local yardsInMile = 1760 -- yards in a mile
	local miles = floor(yards / yardsInMile)
	local remaining = floor(yards % yardsInMile)
	return miles, remaining
end

local function humanizeYardsKilometers(yards)
	local meters = yards * 0.9144
	local km = floor(meters / 1000)
	local remaining = floor(meters % 1000)
	return km, remaining
end

-- Return the formatted distance, taking the player options
-- into account and converting to Metric in appropriate circumstances
-- Thanks to Lotimar for the contribution
function TomTom:GetFormattedDistance(distanceInYards)
	local distanceMode = "humanmeters"

	if self.db.profile.arrow.distanceUnits == "auto" then
		if not self:RegionIsMetric() then
			distanceMode = "yards"
		end
	elseif self.db.profile.arrow.distanceUnits == "yards" then
		distanceMode = "yards"
	elseif self.db.profile.arrow.distanceUnits == "meters" then
		distanceMode = "meters"
	elseif self.db.profile.arrow.distanceUnits == "humanyards" then
		distanceMode = "humanyards"
	elseif self.db.profile.arrow.distanceUnits == "humanmeters" then
		distanceMode = "humanmeters"
	end

	if distanceMode == "humanmeters" then
		local km, meters = humanizeYardsKilometers(distanceInYards)
		if km == 0 then
			return L["%dm away"]:format(meters)
		else
			return L["%dkm %dm away"]:format(km, meters)
		end
	elseif distanceMode == "humanyards" then
		local miles, yards = humanizeYardsMiles(distanceInYards)
		if miles == 0 then
			return L["%d yards away"]:format(yards)
		elseif miles == 1 then
			return L["%d mile %d yards away"]:format(miles, yards)
		else
			return L["%d miles %d yards away"]:format(miles, yards)
		end
	elseif distanceMode == "meters" then
		local meters = yardsToMeters(distanceInYards)
		return L["%dm away"]:format(meters)
	elseif distanceMode == "yards" then
		return L["%d yards away"]:format(distanceInYards)
	end
end
