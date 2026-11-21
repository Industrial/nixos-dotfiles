--@curseforge-project-slug: libcandybar-3-0@
--- **LibCandyBar-3.0** provides elegant timerbars with icons for use in addons.
-- It is based of the original ideas of the CandyBar and CandyBar-2.0 library.
-- In contrary to the earlier libraries LibCandyBar-3.0 provides you with a timerbar object with a simple API.
--
-- Creating a new timerbar using the ':New' function will return a new timerbar object. This timerbar object inherits all of the barPrototype functions listed here. \\
--
-- @usage
-- local candy = LibStub("LibCandyBar-3.0")
-- local texture = "Interface\\AddOns\\MyAddOn\\statusbar"
-- local mybar = candy:New(texture, 100, 16)
-- mybar:SetLabel("Yay!")
-- mybar:SetDuration(60)
-- mybar:Start()
-- @class file
-- @name LibCandyBar-3.0

local GetTime, next = GetTime, next
local CreateFrame, error, setmetatable, UIParent = CreateFrame, error, setmetatable, UIParent
local NewTimer = C_Timer.NewTimer

if not LibStub then error("LibCandyBar-3.0 requires LibStub.") end
local cbh = LibStub:GetLibrary("CallbackHandler-1.0")
if not cbh then error("LibCandyBar-3.0 requires CallbackHandler-1.0") end
local lib = LibStub:NewLibrary("LibCandyBar-3.0", 115) -- Bump minor on changes
if not lib then return end
lib.callbacks = lib.callbacks or cbh:New(lib)
local cb = lib.callbacks
lib.dummyFrame = lib.dummyFrame or CreateFrame("Frame")
lib.barFrameMT = lib.barFrameMT or {__index = lib.dummyFrame}
lib.barPrototype = lib.barPrototype or setmetatable({}, lib.barFrameMT)
local barPrototype = lib.barPrototype
lib.barPrototype_mt = lib.barPrototype_mt or {}
lib.barPrototype_mt.__index = function(self, key)
	if key == "remaining" then
		return self:GetRemainingTime()
	end
	return barPrototype[key]
end
lib.barCache = lib.barCache or {}

local barPrototype_meta = lib.barPrototype_mt
local barCache = lib.barCache

local GameFontHighlightSmallOutline = GameFontHighlightSmallOutline
local _fontName, _fontSize = GameFontHighlightSmallOutline:GetFont()
local _fontShadowX, _fontShadowY = GameFontHighlightSmallOutline:GetShadowOffset()
local _fontShadowR, _fontShadowG, _fontShadowB, _fontShadowA = GameFontHighlightSmallOutline:GetShadowColor()
local SetWidth, SetHeight, SetSize, SetFrameLevel = lib.dummyFrame.SetWidth, lib.dummyFrame.SetHeight, lib.dummyFrame.SetSize, lib.dummyFrame.SetFrameLevel

-- ------------------------------------------------------------------------------
-- Bar functions
--

local function restyleBar(self)
	if not self.running then return end

	self.candyBarBar:ClearAllPoints()
	if self:IsIconVisible() then
		self.candyBarIconFrame:ClearAllPoints()
		self.candyBarIconFrame:SetWidth(self.height)
		if self:GetIconPosition() == "RIGHT" then
			self.candyBarIconFrame:SetPoint("TOPRIGHT", self)
			self.candyBarIconFrame:SetPoint("BOTTOMRIGHT", self)
			self.candyBarBar:SetPoint("TOPRIGHT", self, "TOPRIGHT", -self.height, 0)
			self.candyBarBar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -self.height, 0)
			self.candyBarBar:SetPoint("TOPLEFT", self)
			self.candyBarBar:SetPoint("BOTTOMLEFT", self)
		else
			self.candyBarIconFrame:SetPoint("TOPLEFT")
			self.candyBarIconFrame:SetPoint("BOTTOMLEFT")
			self.candyBarBar:SetPoint("TOPLEFT", self, "TOPLEFT", self.height, 0)
			self.candyBarBar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", self.height, 0)
			self.candyBarBar:SetPoint("TOPRIGHT", self)
			self.candyBarBar:SetPoint("BOTTOMRIGHT", self)
		end
		self.candyBarIconFrame:Show()
	else
		self.candyBarBar:SetPoint("TOPLEFT", self)
		self.candyBarBar:SetPoint("BOTTOMRIGHT", self)
		self.candyBarIconFrame:Hide()
	end
	if self:IsLabelVisible() then
		self.candyBarLabel:Show()
	else
		self.candyBarLabel:Hide()
	end
	if self:IsTimeVisible() then
		self.candyBarDuration:Show()
	else
		self.candyBarDuration:Hide()
	end
end

--- Sets the frame level of the bar.
-- @param level Frame level of the bar.
function barPrototype:SetFrameLevel(level)
	SetFrameLevel(self, level)
	local frameLevel = self:GetFrameLevel() - 1
	self.candyBarBackdrop:SetFrameLevel(frameLevel)
	self.candyBarIconFrameBackdrop:SetFrameLevel(frameLevel)
end

--- Set whether the bar should drain (default) or fill up.
-- @param fill Boolean true/false
function barPrototype:SetFill(fill)
	self.fill = fill
	if self.running then
		if not self.paused then
			-- Enum.StatusBarInterpolation.Immediate = 0 | Enum.StatusBarTimerDirection: ElapsedTime = 0, RemainingTime = 1
			self.candyBarBar:SetTimerDuration(self.durationObject, 0, fill and 0 or 1)
		elseif self.remainingTime and self.remainingTime > 0 then
			self.candyBarBar:SetValue(fill and self.totalDuration - self.remainingTime or self.remainingTime)
		else
			self.candyBarBar:SetMinMaxValues(0, 1)
			self.candyBarBar:SetValue(1)
		end
	end
end
--- Deprecated.
function barPrototype:AddUpdateFunction() end
--- Sets user data in the timerbar object.
-- @param key Key to use for the data storage.
-- @param data Data to store.
function barPrototype:Set(key, data) self.data[key] = data end
--- Retrieves user data from the timerbar object.
-- @param key Key to retrieve
function barPrototype:Get(key) return self.data[key] end
--- Sets the color of the bar.
-- This is basically a wrapper to candyBarBar:SetStatusBarColor.
-- @paramsig r, g, b, a
-- @param r Red component (0-1)
-- @param g Green component (0-1)
-- @param b Blue component (0-1)
-- @param a Alpha (0-1)
function barPrototype:SetColor(...) self.candyBarBar:SetStatusBarColor(...) end
--- Sets the background color of the bar.
-- This is basically a wrapper to candyBarBackground:SetVertexColor.
-- @paramsig r, g, b, a
-- @param r Red component (0-1)
-- @param g Green component (0-1)
-- @param b Blue component (0-1)
-- @param a Alpha (0-1)
function barPrototype:SetBackgroundColor(...) self.candyBarBackground:SetVertexColor(...) end
--- Sets the color of the bar label and bar duration text.
-- @paramsig r, g, b, a
-- @param r Red component (0-1)
-- @param g Green component (0-1)
-- @param b Blue component (0-1)
-- @param a Alpha (0-1)
function barPrototype:SetTextColor(...)
	self.candyBarLabel:SetTextColor(...)
	self.candyBarDuration:SetTextColor(...)
end
--- Sets the shadow color of the bar label and bar duration text.
-- @paramsig r, g, b, a
-- @param r Red component (0-1)
-- @param g Green component (0-1)
-- @param b Blue component (0-1)
-- @param a Alpha (0-1)
function barPrototype:SetShadowColor(...)
	self.candyBarLabel:SetShadowColor(...)
	self.candyBarDuration:SetShadowColor(...)
end
--- Sets the shadow offset of the bar label and bar duration text.
-- @number offsetX
-- @number offsetY
function barPrototype:SetShadowOffset(...)
	self.candyBarLabel:SetShadowOffset(...)
	self.candyBarDuration:SetShadowOffset(...)
end
--- Sets the font of the bar label and bar duration text.
-- @string fontFile
-- @number height
-- @string flags
function barPrototype:SetFont(...)
	self.candyBarLabel:SetFont(...)
	self.candyBarDuration:SetFont(...)
end
--- Sets the texture of the bar.
-- This should only be needed on running bars that get changed on the fly.
-- @param texture Path to the bar texture.
function barPrototype:SetTexture(texture)
	self.candyBarBar:SetStatusBarTexture(texture)
	self.candyBarBackground:SetTexture(texture)
end
--- Sets the width of the bar.
-- This should only be needed on running bars that get changed on the fly.
-- @param width Width of the bar.
function barPrototype:SetWidth(width)
	self.width = width
	SetWidth(self, width)
end
--- Sets the height of the bar.
-- This should only be needed on running bars that get changed on the fly.
-- @param height Height of the bar.
function barPrototype:SetHeight(height)
	self.height = height
	SetHeight(self, height)
	restyleBar(self)
end
--- Sets the size of the bar.
-- This should only be needed on running bars that get changed on the fly.
-- @param width Width of the bar.
-- @param height Height of the bar.
function barPrototype:SetSize(width, height)
	self.width = width
	self.height = height
	SetSize(self, width, height)
	restyleBar(self)
end
--- Returns the label (text) currently set on the bar.
function barPrototype:GetLabel()
	return self.candyBarLabel:GetText()
end
--- Sets the label on the bar.
-- @param text Label text.
function barPrototype:SetLabel(text)
	self.candyBarLabel:SetText(text)
end
--- Returns the icon texture path currently set on the bar, if it has an icon set.
function barPrototype:GetIcon()
	return self.candyBarIconFrame:GetTexture()
end
--- Sets the icon next to the bar using a standard texture.
-- @param icon Path to the icon texture or nil to not display an icon.
-- @param ... Optional icon coordinates for texture trimming.
function barPrototype:SetIcon(icon, ...)
	self:Set("LCBiconIsAtlas", false)
	self.candyBarIconFrame:SetTexture(icon)
	if ... then
		self.candyBarIconFrame:SetTexCoord(...)
	else
		self.candyBarIconFrame:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
end
--- Returns the atlas name currently set on the bar, if it has an icon set.
function barPrototype:GetIconAtlas()
	return self.candyBarIconFrame:GetAtlas()
end
--- Sets the icon next to the bar using an atlas.
-- @param atlas Atlas name.
function barPrototype:SetIconAtlas(atlas)
	self:Set("LCBiconIsAtlas", true)
	self.candyBarIconFrame:SetAtlas(atlas)
end
--- Returns true if the icon is an atlas, false otherwise.
function barPrototype:IsIconAtlas()
	return self:Get("LCBiconIsAtlas")
end
--- Sets which side of the bar the icon should appear.
-- @param position Position of the icon according to the bar, either "LEFT" or "RIGHT" as a string. Set to "LEFT" by default.
function barPrototype:SetIconPosition(position)
	if position == "RIGHT" then
		self:Set("LCBiconPosition", position)
	else
		self:Set("LCBiconPosition", "LEFT")
	end
	restyleBar(self)
end
--- Returns the side of the bar where the icon should appear.
function barPrototype:GetIconPosition()
	return self:Get("LCBiconPosition")
end
--- Sets wether or not the icon on the side of the bar should be shown.
-- Icon is shown by default.
-- @param bool true to show the icon, false/nil to hide the icon.
function barPrototype:SetIconVisibility(bool)
	if bool then
		self:Set("LCBiconVisible", true)
		self.candyBarIconFrame:Show()
	else
		self:Set("LCBiconVisible", false)
		self.candyBarIconFrame:Hide()
	end
	restyleBar(self)
end
--- Returns true if the icon is visible, false otherwise.
function barPrototype:IsIconVisible()
	return self:Get("LCBiconVisible")
end
--- Sets wether or not the time indicator should be shown.
-- Time is shown by default.
-- @param bool true to show the time, false/nil to hide the time.
function barPrototype:SetTimeVisibility(bool)
	if bool then
		self:Set("LCBtimeVisible", true)
		self.candyBarDuration:Show()
		if self.running and not self.paused then
			self.durationBinding:SetEnabled(true)
		end
	else
		self:Set("LCBtimeVisible", false)
		self.candyBarDuration:Hide()
		self.durationBinding:SetEnabled(false)
	end
end
--- Returns true if the time is visible, false otherwise.
function barPrototype:IsTimeVisible()
	return self:Get("LCBtimeVisible")
end
do
	local minuteBreakpoint = {
		threshold = 60,
		format = "%d:%02d",
		components = {
			{ div = 60, step = 1, rounding = 2 }, -- Enum.NumericRuleFormatRounding.Down = 2
			{ mod = 60, step = 1, rounding = 2 },
		},
	}
	local hourBreakpoint = {
		threshold = 3600,
		format = "%d:%02d:%02d",
		components = {
			{ div = 3600, step = 1, rounding = 2 },
			{ div = 60, mod = 60, step = 1, rounding = 2 },
			{ mod = 60, step = 1, rounding = 2 },
		},
	}
	local noDecimalsBreakpoints = {
		{ threshold = 0, format = "%.0f" },
		minuteBreakpoint,
		hourBreakpoint,
	}
	local customDecimalsBreakpoint = { threshold = 10, format = "%.0f" }
	local customDecimalsBreakpoints = {
		{ threshold = 0, format = "%.1f" },
		customDecimalsBreakpoint,
		minuteBreakpoint,
		hourBreakpoint,
	}
	local allDecimalsBreakpoints = {
		{ threshold = 0, format = "%.1f" },
		minuteBreakpoint,
		hourBreakpoint,
	}
	--- Sets the threshold in seconds at which decimal points begin to show on the bar.
	-- @param threshold Number of seconds. Defaults to 10.
	function barPrototype:SetDecimalsThreshold(threshold)
		if self.decimalsThreshold ~= threshold then
			self.decimalsThreshold = threshold
			local formatter = self.formatter
			if threshold <= 0 then
				formatter:SetBreakpoints(noDecimalsBreakpoints)
			elseif threshold < 60 then
				customDecimalsBreakpoint.threshold = threshold
				formatter:SetBreakpoints(customDecimalsBreakpoints)
			else
				formatter:SetBreakpoints(allDecimalsBreakpoints)
			end
			if self.running and self.paused and self.remainingTime and self.remainingTime > 0 then
				self.candyBarDuration:SetText(formatter:FormatNumber(self.remainingTime))
			end
		end
	end
end
--- Sets wether or not the label should be shown.
-- label is shown by default.
-- @param bool true to show the label, false/nil to hide the label.
function barPrototype:SetLabelVisibility(bool)
	if bool then
		self:Set("LCBlabelVisible", true)
		self.candyBarLabel:Show()
	else
		self:Set("LCBlabelVisible", false)
		self.candyBarLabel:Hide()
	end
end
--- Returns true if the label is visible, false otherwise.
function barPrototype:IsLabelVisible()
	return self:Get("LCBlabelVisible")
end
--- Sets wether or not the bar should pause when its done.
-- It will show as full and the time label will be hidden
-- @param value Seconds to pause the bar when done or true for indefinitely
function barPrototype:SetPauseWhenDone(value)
	if type(value) == "number" and value > 0 then
		self.maxPauseDuration = value
		self.pauseWhenDone = true
	else
		self.maxPauseDuration = nil
		self.pauseWhenDone = value and value ~= 0 or nil
	end
end
--- Sets a one-time callback to fire after reaching a certain time remaining on the bar
-- @param func The callback function to fire
-- @number time The time the bar will have remaining when the callback triggers
function barPrototype:SetTimeCallback(func, time)
	if self.timeCallbackTimer then
		self.timeCallbackTimer:Cancel()
		self.timeCallbackTimer = nil
	end
	self.timeCallback = func
	self.timeCallbackTrigger = time
	if func and time and self.running and not self.paused then
		local delay = (self.exp - GetTime()) - time
		self.timeCallbackTimer = NewTimer(delay > 0 and delay or 0, self.onTimeCallback)
	end
end
--- Sets the duration of the bar.
-- This can also be used while the bar is running to adjust the time remaining, within the bounds of the original duration.
-- @param duration Duration of the bar in seconds.
function barPrototype:SetDuration(duration)
	self.remainingTime = duration
	if self.running and duration then
		if duration > self.totalDuration then
			self.totalDuration = duration
		end
		if not self.paused then
			self.exp = GetTime() + duration
			self.durationObject:SetTimeFromEnd(self.exp, self.totalDuration)
			-- Enum.StatusBarInterpolation.Immediate = 0 | Enum.StatusBarTimerDirection: ElapsedTime = 0, RemainingTime = 1
			self.candyBarBar:SetTimerDuration(self.durationObject, 0, self.fill and 0 or 1)
			self.durationBinding:SetDuration(self.durationObject)
			if self.expTimer then
				self.expTimer:Cancel()
			end
			self.expTimer = NewTimer(duration > 0 and duration or 0, self.onExpire)
			if self.timeCallbackTimer then
				self.timeCallbackTimer:Cancel()
				local delay = duration - self.timeCallbackTrigger
				self.timeCallbackTimer = NewTimer(delay > 0 and delay or 0, self.onTimeCallback)
			end
		else
			if duration <= 0 then
				self.remainingTime = 0
				self.candyBarDuration:ClearText()
				self.candyBarBar:SetMinMaxValues(0, 1)
				self.candyBarBar:SetValue(1)
				if self.maxPauseDuration and not self.maxPauseDurationCallback then
					self.maxPauseDurationCallback = NewTimer(self.maxPauseDuration, self.onMaxPauseExpire)
				end
			else
				if self.maxPauseDurationCallback then
					self.maxPauseDurationCallback:Cancel()
					self.maxPauseDurationCallback = nil
				end
				self.candyBarDuration:SetText(self.formatter:FormatNumber(duration))
				self.candyBarBar:SetMinMaxValues(0, self.totalDuration)
				self.candyBarBar:SetValue(self.fill and self.totalDuration - duration or duration)
			end
		end
	end
end
--- Returns the time remaining on the bar in seconds.
function barPrototype:GetRemainingTime()
	if self.running and not self.paused then
		return self.exp - GetTime()
	end
	return self.remainingTime
end
--- Shows the bar and starts it.
-- @param maxValue Number. If you don't wish your bar to start full, you can set a max value. A maxValue of 10 on a bar with a duration of 5 would start it at 50%.
function barPrototype:Start(maxValue)
	local time = self:GetRemainingTime()
	if self.expTimer then
		self.expTimer:Cancel()
		self.expTimer = nil
	end
	if self.timeCallbackTimer then
		self.timeCallbackTimer:Cancel()
		self.timeCallbackTimer = nil
	end
	if self.maxPauseDurationCallback then
		self.maxPauseDurationCallback:Cancel()
		self.maxPauseDurationCallback = nil
	end
	self.running = true
	self.paused = nil
	self.remainingTime = time
	local totalDuration = (maxValue and maxValue > time) and maxValue or time
	self.totalDuration = totalDuration
	restyleBar(self)
	self.exp = GetTime() + time

	self.durationObject:SetTimeFromEnd(self.exp, totalDuration)
	-- Enum.StatusBarInterpolation.Immediate = 0 | Enum.StatusBarTimerDirection: ElapsedTime = 0, RemainingTime = 1
	self.candyBarBar:SetTimerDuration(self.durationObject, 0, self.fill and 0 or 1)
	self.durationBinding:SetDuration(self.durationObject)
	self.durationBinding:SetEnabled(self:IsTimeVisible())

	self.expTimer = NewTimer(time > 0 and time or 0, self.onExpire)
	if self.timeCallback and self.timeCallbackTrigger then
		local delay = time - self.timeCallbackTrigger
		self.timeCallbackTimer = NewTimer(delay > 0 and delay or 0, self.onTimeCallback)
	end
	self:Show()
end
--- Pauses a running bar
function barPrototype:Pause()
	if self.running and not self.paused then
		if self.expTimer then
			self.expTimer:Cancel()
			self.expTimer = nil
		end
		if self.timeCallbackTimer then
			self.timeCallbackTimer:Cancel()
			self.timeCallbackTimer = nil
		end
		local time = self.exp - GetTime()
		self.paused = true
		self.durationBinding:SetEnabled(false)
		if time <= 0 then
			self.remainingTime = 0
			self.candyBarDuration:ClearText()
			self.candyBarBar:SetMinMaxValues(0, 1)
			self.candyBarBar:SetValue(1)
			if self.maxPauseDuration and not self.maxPauseDurationCallback then
				self.maxPauseDurationCallback = NewTimer(self.maxPauseDuration, self.onMaxPauseExpire)
			end
		else
			self.remainingTime = time
			self.candyBarDuration:SetText(self.formatter:FormatNumber(time))
			self.candyBarBar:SetMinMaxValues(0, self.totalDuration)
			self.candyBarBar:SetValue(self.fill and self.totalDuration - time or time)
		end
	end
end
--- Resumes a paused bar
function barPrototype:Resume()
	if self.running and self.paused then
		if self.maxPauseDurationCallback then
			self.maxPauseDurationCallback:Cancel()
			self.maxPauseDurationCallback = nil
		end
		local time = self.remainingTime
		self.exp = GetTime() + time
		self.paused = nil

		self.durationObject:SetTimeFromEnd(self.exp, self.totalDuration)
		-- Enum.StatusBarInterpolation.Immediate = 0 | Enum.StatusBarTimerDirection: ElapsedTime = 0, RemainingTime = 1
		self.candyBarBar:SetTimerDuration(self.durationObject, 0, self.fill and 0 or 1)
		self.durationBinding:SetDuration(self.durationObject)
		self.durationBinding:SetEnabled(self:IsTimeVisible())

		self.expTimer = NewTimer(time > 0 and time or 0, self.onExpire)
		if self.timeCallback and self.timeCallbackTrigger then
			local delay = time - self.timeCallbackTrigger
			self.timeCallbackTimer = NewTimer(delay > 0 and delay or 0, self.onTimeCallback)
		end
	end
end

do
	local function stopBar(bar)
		if bar.expTimer then
			bar.expTimer:Cancel()
			bar.expTimer = nil
		end
		if bar.timeCallbackTimer then
			bar.timeCallbackTimer:Cancel()
			bar.timeCallbackTimer = nil
		end
		if bar.maxPauseDurationCallback then
			bar.maxPauseDurationCallback:Cancel()
			bar.maxPauseDurationCallback = nil
		end
		bar.durationBinding:SetEnabled(false)
		bar:ClearScripts()
		bar.data = nil
		bar.running = nil
		bar.paused = nil
		bar.pauseWhenDone = nil
		bar.maxPauseDuration = nil
		bar.timeCallback = nil
		bar.timeCallbackTrigger = nil
		bar.exp = nil
		bar.totalDuration = nil
		bar.remainingTime = nil
		bar:Hide()
		bar:SetParent(UIParent)
	end

	--- Stops the bar.
	-- This will stop the bar, fire the LibCandyBar_Stop callback, and recycle the bar into the candybar pool.
	-- Note: make sure you remove all references to the bar in your addon upon receiving the LibCandyBar_Stop callback.
	-- @usage
	-- -- The example below shows the use of the LibCandyBar_Stop callback by printing the contents of the label in the chatframe
	-- local function barstopped( callback, bar )
	--   print( bar:GetLabel(), "stopped")
	-- end
	-- LibStub("LibCandyBar-3.0"):RegisterCallback(myaddonobject, "LibCandyBar_Stop", barstopped)
	-- @param ... Optional args to pass across in the LibCandyBar_Stop callback.
	function barPrototype:Stop(...)
		cb:Fire("LibCandyBar_Stop", self, ...)
		stopBar(self)
		barCache[self] = true
	end
end

-- ------------------------------------------------------------------------------
-- Library functions
--

local function initDurationObjects(bar)
	local formatter = C_StringUtil.CreateNumericRuleFormatter()
	bar.formatter = formatter

	local durationBinding = C_DurationUtil.CreateDurationTextBinding()
	durationBinding:SetFormatter(formatter)
	durationBinding:SetFontString(bar.candyBarDuration)
	durationBinding:SetExpiredText("")
	durationBinding:SetZeroDurationText("")
	durationBinding:SetEnabled(false)
	bar.durationBinding = durationBinding

	bar.durationObject = C_DurationUtil.CreateDuration()

	bar.onMaxPauseExpire = function()
		bar.maxPauseDurationCallback = nil
		bar:Stop()
	end
	bar.onExpire = function()
		bar.expTimer = nil
		if bar.pauseWhenDone then
			bar.exp = 0
			bar:Pause()
		else
			bar:Stop()
		end
	end
	bar.onTimeCallback = function()
		bar.timeCallbackTimer = nil
		local callback = bar.timeCallback
		if callback then
			bar.timeCallback = nil
			bar.timeCallbackTrigger = nil
			callback(bar)
		end
	end
end

--- Creates a new timerbar object and returns it. Don't forget to set the duration, label and :Start the timer bar after you get a hold of it!
-- @paramsig texture, width, height
-- @param texture Path to the texture used for the bar.
-- @param width Width of the bar.
-- @param height Height of the bar.
-- @usage
-- mybar = LibStub("LibCandyBar-3.0"):New("Interface\\AddOns\\MyAddOn\\media\\statusbar", 100, 16)
function lib:New(texture, width, height)
	local bar = next(barCache)
	if not bar then
		local frame = CreateFrame("Frame", nil, UIParent)
		frame:Hide()
		bar = setmetatable(frame, barPrototype_meta)

		local icon = bar:CreateTexture()
		icon:SetSnapToPixelGrid(false)
		icon:SetTexelSnappingBias(0)
		icon:Show()
		bar.candyBarIconFrame = icon

		local statusbar = CreateFrame("StatusBar", nil, bar)
		bar.candyBarBar = statusbar
		local statusBarTexture = statusbar:CreateTexture()
		statusBarTexture:SetSnapToPixelGrid(false)
		statusBarTexture:SetTexelSnappingBias(0)
		statusbar:SetStatusBarTexture(statusBarTexture)

		local bg = statusbar:CreateTexture(nil, "BACKGROUND")
		bg:SetSnapToPixelGrid(false)
		bg:SetTexelSnappingBias(0)
		bar.candyBarBackground = bg

		local backdrop = CreateFrame("Frame", nil, bar, "BackdropTemplate") -- Used by bar stylers for backdrops
		backdrop:Hide()
		bar.candyBarBackdrop = backdrop

		local iconBackdrop = CreateFrame("Frame", nil, bar, "BackdropTemplate") -- Used by bar stylers for backdrops
		iconBackdrop:Hide()
		bar.candyBarIconFrameBackdrop = iconBackdrop

		local label = statusbar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
		bar.candyBarLabel = label

		local duration = statusbar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
		bar.candyBarDuration = duration

		initDurationObjects(bar)
	else
		barCache[bar] = nil
		if not bar.durationBinding then -- Upgrade code for pre 114
			if bar.updater then
				bar.updater:Stop()
				bar.updater = nil
				bar.repeater = nil
			end
			bar.remaining = nil
			bar.funcs = nil
			initDurationObjects(bar)
		end

		-- Clear secrets from icon textures
		bar.candyBarIconFrame:SetToDefaults()
		bar.candyBarIconFrame:ClearAllPoints()
		bar.candyBarIconFrame:SetSnapToPixelGrid(false) -- We shouldn't need to do this if we ever get an alternative to SetToDefaults
		bar.candyBarIconFrame:SetTexelSnappingBias(0)
		bar.candyBarIconFrameBackdrop:ClearBackdrop()
		bar.candyBarIconFrameBackdrop:ClearAllPoints()
		bar.candyBarIconFrameBackdrop:Hide()

		-- Clear secrets from fontstrings
		bar.candyBarLabel:ClearText()
		bar.candyBarDuration:ClearText()
		bar.candyBarLabel:ClearAllPoints()
		bar.candyBarDuration:ClearAllPoints()

		-- Clear secrets from the bar texture
		bar.candyBarBackdrop:ClearBackdrop()
		bar.candyBarBackdrop:ClearAllPoints()
		bar.candyBarBackdrop:Hide()
		bar.candyBarBackground:ClearAllPoints()
		bar.candyBarBar:ClearAllPoints()
	end

	-- RESET ALL THE THINGS!
	bar.data = {
		LCBiconPosition = "LEFT",
		LCBiconVisible = true,
		LCBtimeVisible = true,
		LCBlabelVisible = true,
	}
	bar.fill = nil

	bar:SetFrameStrata("MEDIUM")
	bar:SetFrameLevel(100) -- Lots of room to create above or below this level
	bar.candyBarBar:SetStatusBarTexture(texture)
	bar.candyBarBackground:SetTexture(texture)
	bar.width = width
	bar.height = height
	bar.candyBarLabel:SetPoint("TOPLEFT", bar.candyBarBar, "TOPLEFT", 2, 0)
	bar.candyBarLabel:SetPoint("BOTTOMRIGHT", bar.candyBarBar, "BOTTOMRIGHT", -2, 0)
	bar.candyBarDuration:SetPoint("TOPLEFT", bar.candyBarBar, "TOPLEFT", 2, 0)
	bar.candyBarDuration:SetPoint("BOTTOMRIGHT", bar.candyBarBar, "BOTTOMRIGHT", -2, 0)
	bar.candyBarBar:SetPoint("TOPRIGHT")
	bar.candyBarBar:SetPoint("BOTTOMRIGHT")
	bar.candyBarBackground:SetAllPoints()

	bar:SetBackgroundColor(0.5, 0.5, 0.5, 0.3)
	bar:SetColor(0.5, 0.5, 0.5, 1)
	bar:SetTextColor(1,1,1,1)
	bar:ClearAllPoints()
	SetSize(bar, width, height)
	bar:SetScale(1)
	bar:SetAlpha(1)
	bar:SetClampedToScreen(false)
	bar:EnableMouse(false)
	bar:SetFont(_fontName, _fontSize)
	bar:SetShadowOffset(_fontShadowX, _fontShadowY)
	bar:SetShadowColor(_fontShadowR, _fontShadowG, _fontShadowB, _fontShadowA)

	bar.candyBarLabel:SetJustifyH("LEFT")
	bar.candyBarLabel:SetJustifyV("MIDDLE")

	bar.candyBarDuration:SetJustifyH("RIGHT")
	bar.candyBarDuration:SetJustifyV("MIDDLE")

	bar:SetIcon()
	bar:SetDuration()
	bar:SetDecimalsThreshold(10)

	return bar
end
