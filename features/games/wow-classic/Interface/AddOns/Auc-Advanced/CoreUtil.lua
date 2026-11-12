--[[
	Auctioneer
	Version: 2.5.6733 (SwimmingSeadragon)
	Revision: $Id: CoreUtil.lua 6733 2022-01-25 11:42:44Z none $
	URL: http://auctioneeraddon.com/

	This is an addon for World of Warcraft that adds statistical history to the auction data that is collected
	when the auction is scanned, so that you can easily determine what price
	you will be able to sell an item for at auction or at a vendor whenever you
	mouse-over an item in the game

	License:
		This program is free software; you can redistribute it and/or
		modify it under the terms of the GNU General Public License
		as published by the Free Software Foundation; either version 2
		of the License, or (at your option) any later version.

		This program is distributed in the hope that it will be useful,
		but WITHOUT ANY WARRANTY; without even the implied warranty of
		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
		GNU General Public License for more details.

		You should have received a copy of the GNU General Public License
		along with this program(see GPL.txt); if not, write to the Free Software
		Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

	Note:
		This AddOn's source code is specifically designed to work with
		World of Warcraft's interpreted AddOn system.
		You have an implicit license to use this AddOn with these facilities
		since that is its designated purpose as per:
		http://www.fsf.org/licensing/licenses/gpl-faq.html#InterpreterIncompat
]]

local lib = AucAdvanced
if not lib then return end
lib.CoreFileCheckIn("CoreUtil")

-- Predefine some dummy functions to protect against a load error cascade
-- These will be overwritten by the real functions, unless an error or ABORTLOAD condition occurs
lib.NewModule = lib.NOPFUNCTION
lib.SendProcessorMessage = lib.NOPFUNCTION
lib.localizations = lib.RETFUNCTION
-- End dummy functions

local tooltip = lib.Libraries.TipHelper or {}
local Const = lib.Const
local Resources = lib.Resources

local _G = _G
local pairs, ipairs, tinsert, wipe = pairs, ipairs, tinsert, wipe
local type, tonumber, tostring = type, tonumber, tostring
local pcall = pcall
local strmatch = strmatch
local select = select

local coremodule, internalUtil, private = lib.GetCoreModule("CoreUtil", "Util", true)
if coremodule and internalUtil then

	function coremodule.OnLoad(addon)
		if addon == "auc-advanced" then
			private.FactionOnLoad()
		end
	end

	coremodule.Processors = {}
	function coremodule.Processors.auctionopen()
		-- temporary check
		if private.checkAuthorizedModules then
			private.checkAuthorizedModules()
		end
	end
	function coremodule.Processors.newmodule(event, libType, libName)
		-- the only newmodule messages should come from AucAdvanced.NewModule
		-- ### this is a temporary check, until we are sure nothing else is still sending these messages
		if private.newmoduleCheckName ~= libName then
			error("Auctioneer has detected unauthorized newmodule message")
		end
	end
else
	-- if there's aleady an abort error condition, we should avoid throwing unneccesary additional errors
	if not lib.ABORTLOAD then
		local errtext = "CoreUtil was unable to register with CoreModule"
		lib.ABORTLOAD = errtext
		geterrorhandler()("Auctioneer load error: "..errtext)
	end
end

--Localization via babylonian
local Babylonian = lib.Libraries.Babylonian
if Babylonian then
	local babylonian = Babylonian(AuctioneerLocalizations)
	function lib.localizations(stringKey)
		local locale = lib.Settings.GetSetting("SelectedLocale")--locales are user choose-able
		-- translated key or english Key or Raw Key
		return babylonian(locale, stringKey) or babylonian[stringKey] or stringKey
	end
end

--The following function will build tables correlating Chat Frame names with their index numbers, and return different formats according to an option passed in.
function lib.getFrameNames(option)
	local frames = {}
	local frameName = ""
--This iterates through the first 10 ChatWindows, getting the name associated with it.
	for i=1, 10 do
		local name, fontSize, r, g, b, a, shown, locked, docked = GetChatWindowInfo(i)
		--If the name isn't blank, then we build tables where the Chat Frame names are the keys, and indexes the values if the frame is either shown or docked.
		if (name ~= "" and (shown or docked)) then
			frames[name] = i
		end
	end
	--Next, if a number was passed as an option, we simply retrieve the frame name and assign it to frameName
	if (type(option) == "number") then
		local name, fontSize, r, g, b, a, shown, locked, docked = GetChatWindowInfo(option);
		frameName = name
		return frameName
	--If no option was specified, we return the Name=>Index table
	elseif (not option) then
		return frames
	end
end

--This function will be called by our configuration screen to build the appropriate list.
function lib.configFramesList()
	local configFrames = {}
	for i=1, 10 do
		local name, fontSize, r, g, b, a, shown, locked, docked = GetChatWindowInfo(i)
		if (name ~= "") and (docked or shown) then
			tinsert(configFrames, {name, name})
		end
	end
	return configFrames
end
--This function will retrieve the index we've got stored for the user
function lib.getFrameIndex()
	--Check to make sure AucAdvanced.Settings exists, if not initialize it
	if (not lib.Settings) then
		lib.Settings = {}
	end
	local get = lib.Settings.GetSetting
	--Get the value of AucAdvanced.Settings["printwindow"]
	local value = get("printwindow")
	--If that value doesn't exist, we return a default of 0
	if (not value) then
		return 0
	end
	--Otherwise, we return the value
	return value
end

--This function is used to store the user's preferred chatframe
function lib.setFrame(frame)
	local set = lib.Settings.SetSetting
	--If called with no argument
	if (not frame) then
		frame = 0
	--Compatibility, for those who had set this previously.
	elseif (type(frame) == "number" and frame > 0 and frame < 10) then
		frame = GetChatWindowInfo(frame)
	--If the frame argument is a string, set that as the frameNumber
	elseif (type(frame) == "string") then
		set("printwindow", frame)
	--Otherwise set it to 0
	else
		set("printwindow", 0)
	end
end

--This is the printing function.  If the user has selected a preferred chatframe, we'll use it.  If not, we'll default to the first one.
function lib.Print(...)
	local output, part, frameIndex
	local frame = lib.getFrameIndex()
	local allFrames = lib.getFrameNames()
	if (type(frame) == "string") then
		if (allFrames[frame]) then
			frameIndex = allFrames[frame]
		else
			frameIndex = 1
		end
	--For backward compatibility
	elseif (type(frame) == "number" and frame > 0 and frame < 9) then
		frameIndex = frame
	elseif (frame == 0) then
		frameIndex = 1
	else
		frameIndex = 1
	end
	local frameReference = _G["ChatFrame"..frameIndex]
	for i=1, select("#", ...) do
		part = select(i, ...)
		part = tostring(part):gsub("{{", "|cffddeeff"):gsub("}}", "|r")
		if (output) then output = output .. " " .. part
		else output = part end
	end
	--If we have a stored chat frame, print our output there
	if (frameReference) then
		frameReference:AddMessage(output, 0.3, 0.9, 0.8)
	--Otherwise, print it to the client's DEFAULT_CHAT_FRAME
	else
		DEFAULT_CHAT_FRAME:AddMessage(output, 0.3, 0.9, 0.8)
	end
end

--Creates the list of locales to choose from
function lib.changeLocale()
	local localizations, default = {}, lib.Settings.GetSetting("SelectedLocale") --get the user choosen locale make it first on the list
	for i in pairs(AuctioneerLocalizations) do
		if default == i then
			tinsert(localizations,1, {i, i})
		else
			tinsert(localizations, {i, i})
		end
	end
	return localizations
end

-- Creates the list of Pricing Models for use in dropdowns
-- Usage: gui:AddControl(id, "Selectbox",  column, indent, AucAdvanced.selectorPriceModels, "util.modulename.model")
do
	local pricemodels
	function private.resetPriceModels()
		-- called every time a new module loads
		pricemodels = nil
	end
	function lib.selectorPriceModels()
		if not pricemodels then
			-- delay creating table until function is first called, to give all modules a chance to load first
			pricemodels = {}
			tinsert(pricemodels,{"market", lib.localizations("ADV_Interface_MarketPrice")})--Market Price
			local algoList, algoNames = lib.API.GetAlgorithms()
			for pos, name in ipairs(algoList) do
				tinsert(pricemodels,{name, format(lib.localizations("ADV_Interface_Algorithm_Price"), algoNames[pos])})--%s Price
			end
		end
		return pricemodels
	end
end

-- Common Dropdown Tables
-- Usage: gui:AddControl(id, "Selectbox",  column, indent, AucAdvanced.selectorXXXX, "libtype.modulename.yyyy")
do
	local auctionlength = {
		{12, FORMATED_HOURS:format(12)},
		{24, FORMATED_HOURS:format(24)},
		{48, FORMATED_HOURS:format(48)},
	}

    if AucAdvanced.Classic == 1 then
        auctionlength = {
            {2, FORMATED_HOURS:format(2)},
            {8, FORMATED_HOURS:format(8)},
            {24, FORMATED_HOURS:format(24)},
        }
    end

	-- List of Auction Durations for use in deposit cost dropdowns
	function lib.selectorAuctionLength()
		return auctionlength
	end

	local alevelA = {
		{Const.ALEVEL_OFF, "Off"},
		{Const.ALEVEL_LOW, "Low"},
		{Const.ALEVEL_MED, "Medium"},
		{Const.ALEVEL_HI, "High"},
	}
	-- Creates a list of Activity Levels for general use
	-- ALEVEL constants are numbers of increasing value, so modules may test for example: value >= Const.ALEVEL_MED
	-- Proposed to introduce variations of this table in future, with different combinations of values
	-- thus this variant has been called type 'A', having values OFF, LOW, MED, HI
	function lib.selectorActivityLevelA()
		return alevelA
	end

	-- MIN, LOW, MED, HI - for settings where 'OFF' would be inappropriate
	local alevelB = {
		{Const.ALEVEL_MIN, "Minimum"},
		{Const.ALEVEL_LOW, "Low"},
		{Const.ALEVEL_MED, "Medium"},
		{Const.ALEVEL_HI, "High"},
	}
	function lib.selectorActivityLevelB()
		return alevelB
	end

end


function lib.GetFactor(...) return tooltip:GetFactor(...) end
function lib.SanitizeLink(link, ...)
	-- nTipHelper's normalizer is a classic 10-field item-link regex. On modern
	-- clients it corrupts item links (it rewrites the level field), while the
	-- retail scan stores links verbatim from GetReplicateItemLink. Keep query
	-- links verbatim too, otherwise GetMarketValue/QueryImage/stat lookups can
	-- never match the stored image and tooltips show "Not Available".
	return link
end
function lib.DecodeLink(...) return tooltip:DecodeLink(...) end
function lib.GetLinkQuality(...) return tooltip:GetLinkQuality(...) end
function lib.ShowItemLink(...) return tooltip:ShowItemLink(...) end
function lib.ShowPetLink(...) return tooltip:ShowPetLink(...) end

-- Caching for GetItemInfo, provided by LibAucItemCache (via TipHelper)
-- returns = lib.GetItemInfoCache(item, select)
	-- item is the parameter to be used in GetItemInfo
	-- select specifies the first return value, like the lua select function (i.e. if select = 11, only return values 11 - 17 will be returned)
lib.GetItemInfoCache = tooltip.GetItemInfoCache

-- Tools for splitting BonusIDs (from LibAucSplitBonus)
-- BONUSIDPATTERNS : lookup table containg match templates
-- ParseToBonusIDString(BonusIDCount, Tail) : function
lib.GetBonusIDStringTools = function() return tooltip.BONUSIDPATTERNS, tooltip.ParseToBonusIDString end

do -- Faction related functions
	local lookupfaction = {
		["alliance"] = "Alliance",
		[FACTION_ALLIANCE:lower()] = "Alliance",
		["horde"] = "Horde",
		[FACTION_HORDE:lower()] = "Horde",
		["neutral"] = "Neutral",
	}
	-- Used to check user text input for some form of a faction name; returns standardized form if found
	-- Possible results are "Alliance", "Horde", "Neutral" or nil if not found
	function lib.IsFaction(faction)
		if type(faction) == "string" then
			return lookupfaction[faction:lower()]
		end
	end

	function lib.GetFaction()
		-- Compatibility function. Deprecated
		return Resources.ServerKey, Const.PlayerRealm, Resources.CurrentFaction
	end

	function lib.GetFactionGroup()
		-- Compatibility function. Deprecated
		return Resources.CurrentFaction
	end

	function private.FactionOnLoad()
		private.FactionOnLoad = nil
		local alliance = lib.localizations("ADV_Interface_FactionAlliance")
		local horde = lib.localizations("ADV_Interface_FactionHorde")
		local neutral = lib.localizations("ADV_Interface_FactionNeutral")

		lookupfaction[alliance:lower()] = "Alliance"
		lookupfaction[horde:lower()] = "Horde"
		lookupfaction[neutral:lower()] = "Neutral"
	end
end

function private.relevelFrame(frame)
	return private.relevelFrames(frame:GetFrameLevel() + 2, frame:GetChildren())
end

function private.relevelFrames(myLevel, ...)
	for i = 1, select("#", ...) do
		local child = select(i, ...)
		child:SetFrameLevel(myLevel)
		private.relevelFrame(child)
	end
end

-- Retail tab tracking (since AuctionFrameTab1..N globals don't exist in retail)
private.RetailTabs = {}
private.RetailTabFrames = {} -- maps tab button to its content frame

function lib.GetAHTabTemplate()
	return "AuctionHouseFrameTabTemplate"
end

function lib.HideAllRetailTabs()
	for _, tab in ipairs(private.RetailTabs) do
		local frame = private.RetailTabFrames[tab]
		if frame then frame:Hide() end
	end
end

function lib.HideBuiltinAHContent()
	if not AuctionHouseFrame then return end
	local builtInFrames = {
		"CategoriesList", "SearchBar", "BrowseResultsFrame",
		"CommoditiesBuyFrame", "ItemBuyFrame", "WoWTokenResults",
		"CommoditiesSellFrame", "CommoditiesSellList",
		"ItemSellFrame", "ItemSellList", "WoWTokenSellFrame",
		"AuctionsFrame",
	}
	for _, name in ipairs(builtInFrames) do
		local frame = AuctionHouseFrame[name]
		if frame and frame:IsShown() then
			pcall(frame.Hide, frame)
		end
	end
end

function lib.AddTab(tabButton, tabFrame)
	local isRetail = true

	if isRetail then
		local ahFrame = AuctionHouseFrame
		if not ahFrame then return end

		for _, tab in ipairs(private.RetailTabs) do
			if tab:GetName() == tabButton:GetName() then
				lib.Print("Tab with that name already exists")
				return
			end
		end

		table.insert(private.RetailTabs, tabButton)
		private.RetailTabFrames[tabButton] = tabFrame

		-- Content frame: parent to ahFrame, inset from the NineSlice border
		-- so custom tabs stay inside the Auction House window on retail.
		tabFrame:SetParent(ahFrame)
		tabFrame:SetPoint("TOPLEFT", ahFrame, "TOPLEFT", 12, -12)
		tabFrame:SetPoint("BOTTOMRIGHT", ahFrame, "BOTTOMRIGHT", -12, 0)
		tabFrame:Hide()
		private.relevelFrame(tabFrame)

		-- Tab button: parent to ahFrame
		tabButton:SetParent(ahFrame)
		tabButton:SetScript("OnShow", nil)
		tabButton:SetScript("OnEvent", nil)
		-- Retail: template provides the visual, just ensure size/font
		if isRetail then
			tabButton:SetWidth(120)
			tabButton:SetHeight(24)
			tabButton:SetNormalFontObject(GameFontNormalSmall)
			tabButton:SetHighlightFontObject(GameFontHighlightSmall)
			tabButton:SetText(tabButton:GetText() or "")
			-- Disable text truncation on the font string
			local fs = tabButton:GetFontString()
			if fs then
				fs:SetMaxLines(1)
				fs:SetWidth(110)
			end

			-- Keep tabs at the same level as the AH frame
			tabButton:SetFrameStrata(ahFrame:GetFrameStrata())
			tabButton:SetFrameLevel(ahFrame:GetFrameLevel() + 5)
		else
		-- Set deselected texture state with proper tex coords
		tabButton.Left:SetTexture("Interface\\Buttons\\UI-Panel-Tab-Up-Left")
		tabButton.Left:SetTexCoord(0, 0.25, 0, 0.5)
		tabButton.Middle:SetTexture("Interface\\Buttons\\UI-Panel-Tab-Up-Middle")
		tabButton.Middle:SetTexCoord(0.25, 0.75, 0, 0.5)
		tabButton.Right:SetTexture("Interface\\Buttons\\UI-Panel-Tab-Up-Right")
		tabButton.Right:SetTexCoord(0.75, 1, 0, 0.5)
		end

		-- Custom checked state (LibSideTabFrame approach)
		tabButton._checked = false
		tabButton.GetChecked = function(self) return self._checked end
		tabButton.SetChecked = function(self, checked) self._checked = checked end

		-- Preserve the module's original OnClick handler
		local moduleOnClick = tabButton:GetScript("OnClick")

		-- Helper to manage tab visual state manually (PanelTemplates_SetChecked doesn't exist in WoW Forever)
		local function SetRetailTabChecked(tab, checked)
			if not tab then return end
			tab._checked = checked
			-- Show/hide active textures
			if tab.LeftActive then tab.LeftActive:SetShown(checked) end
			if tab.MiddleActive then tab.MiddleActive:SetShown(checked) end
			if tab.RightActive then tab.RightActive:SetShown(checked) end
			-- Show/hide normal textures
			if tab.Left then tab.Left:SetShown(not checked) end
			if tab.Middle then tab.Middle:SetShown(not checked) end
			if tab.Right then tab.Right:SetShown(not checked) end
		end

		-- Tab click handler: manages tab selection and hides built-in content
		tabButton:SetScript("OnClick", function(self)
			-- Deselect previous custom tab
			if ahFrame.currentCustomTab and ahFrame.currentCustomTab ~= self then
				SetRetailTabChecked(ahFrame.currentCustomTab, false)
			end
			-- Deselect all built-in tabs
			ahFrame.selectedTab = nil
			if ahFrame.Tabs then
				for _, tab in ipairs(ahFrame.Tabs) do
					PanelTemplates_DeselectTab(tab)
				end
			end
			-- Play the same tab click sound Blizzard uses
			PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
			ahFrame.currentCustomTab = self
			SetRetailTabChecked(self, true)
			-- Let Blizzard handle hiding built-in content
			pcall(function() ahFrame:SetDisplayMode("") end)
			-- Call the module's original OnClick handler
			if moduleOnClick then
				moduleOnClick(self)
			end
		end)

		-- Hook SetDisplayMode to re-show built-in content and hide custom content
		-- when a built-in tab is clicked
		if not private.displayModeHooked then
			private.displayModeHooked = true
			hooksecurefunc(ahFrame, "SetDisplayMode", function(_, mode)
				if mode and #mode > 0 then
					-- A built-in display mode was selected, hide all custom content
					lib.HideAllRetailTabs()
					if ahFrame.currentCustomTab then
						SetRetailTabChecked(ahFrame.currentCustomTab, false)
						ahFrame.currentCustomTab = nil
					end
				end
			end)
		end

		-- Position at bottom of frame after built-in tabs
		local tabCount = #private.RetailTabs
		if tabCount > 1 then
			local prevTab = private.RetailTabs[tabCount - 1]
			tabButton:SetPoint("LEFT", prevTab, "RIGHT", 2, 0)
		else
			tabButton:SetPoint("BOTTOMLEFT", ahFrame, "BOTTOMLEFT", 256, -22)
		end
		tabButton:SetID(tabCount)
		tabButton:Show()

		-- Hook ahFrame show/hide to manage custom tabs
		if not private.closeHooked then
			private.closeHooked = true
			ahFrame:HookScript("OnShow", function()
				for _, tab in ipairs(private.RetailTabs) do
					tab:Show()
				end
			end)
			ahFrame:HookScript("OnHide", function()
				lib.HideAllRetailTabs()
				for _, tab in ipairs(private.RetailTabs) do
					SetRetailTabChecked(tab, false)
					tab:Hide()
				end
				ahFrame.currentCustomTab = nil
			end)
		end
	else
		local tabCount = 1
		while (_G["AuctionFrameTab"..(tabCount)]) do
			if _G["AuctionFrameTab"..(tabCount)]:GetName() == tabButton:GetName() then
				lib.Print("Tab with that name already exists")
				return
			end
			tabCount = tabCount + 1
		end

		local tabIndex = 1
		while (_G["AuctionFrameTab"..(tabIndex)] and
		       _G["AuctionFrameTab"..(tabIndex)]:GetName() ~= "AuctionFrameTabUtilBeanCounter") do
			tabIndex = tabIndex + 1
		end

		for index = tabCount, tabIndex + 1, -1 do
			_G["AuctionFrameTab"..(index)] = _G["AuctionFrameTab"..(index - 1)]
			_G["AuctionFrameTab"..(index)]:SetID(index)
		end

		if not tabFrame:GetParent() then
			tabFrame:SetParent(AucAuctionFrame)
		end
		tabFrame:SetPoint("TOPLEFT", "AucAuctionFrame", "TOPLEFT", 0, 0)
		private.relevelFrame(tabFrame)

		_G["AuctionFrameTab"..tabIndex] = tabButton
		if not tabButton:GetParent() then
			tabButton:SetParent(AucAuctionFrame)
		end
		tabButton:SetPoint("TOPLEFT", _G["AuctionFrameTab"..(tabIndex - 1)]:GetName(), "TOPRIGHT", -8, 0)
		tabButton:SetID(tabIndex)
		tabButton:Show()

		if (tabIndex < tabCount) then
			local nextTabButton = _G["AuctionFrameTab"..(tabIndex + 1)]
			nextTabButton:SetPoint("TOPLEFT", tabButton:GetName(), "TOPRIGHT", -8, 0)
		end

		PanelTemplates_SetNumTabs(AucAuctionFrame, tabCount)
	end
end

function lib.RemoveTab(tabButton, tabFrame)
	local isRetail = true

	if isRetail then
		for i, tab in ipairs(private.RetailTabs) do
			if tab:GetName() == tabButton:GetName() then
				table.remove(private.RetailTabs, i)
				private.RetailTabFrames[tab] = nil
				break
			end
		end
		for i, tab in ipairs(private.RetailTabs) do
			if i > 1 then
				local prevTab = private.RetailTabs[i - 1]
				tab:ClearAllPoints()
				tab:SetPoint("LEFT", prevTab, "RIGHT", -15, 0)
			end
		end
		tabFrame:Hide()
		tabButton:Hide()
	else
		local tabCount = 0
		while (_G["AuctionFrameTab"..(tabCount+1)]) do
			tabCount = tabCount + 1
		end

		local tabIndex, tabFound = 1
		while _G["AuctionFrameTab"..(tabIndex)] do
			if _G["AuctionFrameTab"..(tabIndex)]:GetName() == tabButton:GetName() then
				tabFound = tabIndex
				break
			end
			tabIndex = tabIndex + 1
		end

		if not tabFound then return end

		if tabFound and (tabFound < tabCount) then
			local nextTabButton = _G["AuctionFrameTab"..(tabFound + 1)]
			nextTabButton:SetPoint("TOPLEFT", _G["AuctionFrameTab"..(tabFound - 1)]:GetName(), "TOPRIGHT", -8, 0)
		end

		_G["AuctionFrameTab"..(tabFound)] = nil
		for index = tabFound, tabCount do
			local tab = _G["AuctionFrameTab"..(index + 1)]
			if tab then
				_G["AuctionFrameTab"..(index)] = tab
				_G["AuctionFrameTab"..(index)]:SetID(index)
			else
				_G["AuctionFrameTab"..(index)] = nil
			end
		end

		tabFrame:Hide()
		tabButton:Hide()
		PanelTemplates_SetNumTabs(AucAuctionFrame, tabCount - 1)
	end
end

-- Table management functions:
local function replicate(source, depth, history)
	if type(source) ~= "table" then return source end
	assert(depth==nil or tonumber(depth), "Unknown depth: " .. tostring(depth))
	if not depth then depth = 0 history = {} end
	assert(history, "Have depth but without history")
	assert(depth < 100, "Structure is too deep")
	local dest = {} history[source] = dest
	for k, v in pairs(source) do
		if type(v) == "table" then
			if history[v] then dest[k] = history[v]
			else dest[k] = replicate(v, depth+1, history) end
		else dest[k] = v end
	end
	return dest
end
local function empty(item)
	if type(item) == 'table' then wipe(item) end
end
local function fill(item, ...)
	if type(item) ~= 'table' then return end
	wipe(item)
	local n = select('#', ...)
	for i = 1,n do item[i] = select(i, ...) end
end
-- End table management functions

-- Old functions (compatability)
lib.Recycle = function() end
lib.Acquire = function(...) return {...} end
lib.Clone = replicate
lib.Scrub = empty
-- New functions
lib.Replicate = replicate
lib.Empty = empty
lib.Fill = fill

--[[
Functions for establishing a new copy of the library.
Recommended method:

  local libType, libName = "myType", "myName"
  local lib,parent,private = AucAdvanced.NewModule(libType, libName)
  if not lib then return end
  local aucPrint,decode,_,_,replicate,empty,get,set,default,debugPrint,fill,_TRANS = AucAdvanced.GetModuleLocals()

--]]

do -- Module Functions
	-- local variables for module functions
	local moduleNameLower = {}
	local moduleSortedLists = {All = {}, Util = {}, Stat = {}, Match = {}, Filter = {}}
	local moduleNameLookups = {All = {}, Util = {}, Stat = {}, Match = {}, Filter = {}}
	local moduleNameLookupAll = moduleNameLookups.All -- local ref to this entry for quick lookup by GetModule
	local moduleTypeLookup = { -- used to validate module types (libType)
		filter = "Filter",
		Filter = "Filter",
		match = "Match",
		Match = "Match",
		stat = "Stat",
		Stat = "Stat",
		util = "Util",
		Util = "Util",
	}
	local moduleOnLoadNames
	local moduleLoadCallbacks

	-- constants
	local MODULE_LOADED = "^loaded"

	function private.checkAuthorizedModules()
		-- check the publicly accessible modules tables, notifying of any modules that have been inserted directly
		-- called once per session, when auctionhouse first opened
		-- ### temp function for debugging
		private.checkAuthorizedModules = nil
		for typeName, typeTable in pairs(lib.Modules) do
			for moduleName, moduleTable in pairs(typeTable) do
				if not moduleNameLookupAll[moduleName] then
					-- note: using geterrorhandler() instead of error here allows us to report multiple entries
					-- and avoids halting the processor event
					geterrorhandler()(format("Auctioneer has detected unauthorized entry %s(%s) in AucAdvanced.Modules.%s",
						tostring(moduleName), type(moduleTable), typeName))
				end
			end
		end
	end

	-- Functions for special access by other Core modules
	function internalUtil.GetModuleForName(addonName)
		-- Allows CoreMain OnLoad handler to match an AddOn name to the related module, if one exists
		-- Must *not* be called from anywhere else
		-- The match is based on the AddOn name (5th parameter) supplied to NewModule
		if not moduleOnLoadNames then return end
		local module = moduleOnLoadNames[addonName] -- expect addonName to be all lowercase
		if not module then return end
		moduleOnLoadNames[addonName] = nil
		if not next(moduleOnLoadNames) then moduleOnLoadNames = nil end -- delete lookup table if empty
		return module
	end

	function internalUtil.SendModuleCallbacks(module)
		-- Specified module has fully loaded:
		-- Flag it as loaded
		module[MODULE_LOADED] = true
		-- Flush the SPM cache
		internalUtil.ResetSPMArray()
		-- Send all the callbacks
		if not moduleLoadCallbacks then return end
		local moduleName = module:GetName():lower()
		local list = moduleLoadCallbacks[moduleName]
		if not list then return end
		moduleLoadCallbacks[moduleName] = nil
		if not next(moduleLoadCallbacks) then moduleLoadCallbacks = nil end -- delete lookup table if empty
		for _, callback in ipairs(list) do
			pcall(callback, module)
		end
	end

	-- function to store references to the module in multiple tables, for fast retrieval by GetModule and GetAllModules
	local function UpdateModuleTables(moduleLib, moduleName, moduleType, lowerName)
		-- update the internal lookup tables
		moduleNameLower[lowerName] = moduleLib
		moduleNameLookups.All[moduleName] = moduleLib
		moduleNameLookups[moduleType][moduleName] = moduleLib

		-- sorted lists - used by GetAllModules so as to always return modules in a specific order
		-- sublists are sorted by lowercase name (ascending)
		local tpos
		local typeList = moduleSortedLists[moduleType]
		for index, module in ipairs(typeList) do
			if lowerName < module.GetName():lower() then
				tpos = index
				break
			end
		end
		tpos = tpos or #typeList + 1
		tinsert(typeList, tpos, moduleLib)
		-- the All list is sorted first by module type (descending) then by lower name (ascending, as in the sublists)
		local apos
		local allList = moduleSortedLists.All
		for index, module in ipairs(allList) do
			local curtype = module.GetLibType()
			if moduleType > curtype then
				apos = index
				break
			elseif moduleType == curtype then
				-- we already found the insertion point based on lowerName - tpos
				apos = index + tpos - 1
				break
			end
		end
		tinsert(allList, apos or #allList + 1, moduleLib)

		-- install in public table for direct access by other mods (compatibility)
		lib.Modules[moduleType][moduleName] = moduleLib
	end

	--[[

	Usage:
	  local lib,parent[,private] = AucAdvanced.NewModule(libtype, libName [, libTable, noExtras, addonName])

	  libType must be one of "Filter" "Match" "Stat" "Util"
	  libName must be unique (and may not be one of "Filter" "Match" "Stat" "Util")
	  libTable (optional) table to be used as the lib; this may already contain entries
	  noExtras (optional) boolean: true will prevent the creation of certain 'convenience' entries (currently only the Private subtable)
	  addonName (optional) if provided must exactly match the name of the AddOn calling this function
	    (not needed if the AddOn name matches the Module name, according to the "Auc-libType-libName" convention)

	  Note: the caller must always check the return return from NewModule, and abort loading if it is nil

	--]]
	if not lib.ABORTLOAD then -- don't install if there is an error condition
		function lib.NewModule(libType, libName, libTable, noExtras, addonName)
			local tmp = moduleTypeLookup[libType] -- use a temp variable so we can report libType in the error message
			if not tmp then
				error("Invalid libType specified for NewModule: "..tostring(libType), 2)
			end
			libType = tmp
			if type(libName) ~= "string" then
				error("Module name must be a string for NewModule", 2)
			end
			if libTable and type(libTable) ~= "table" then
				error("Invalid module table provided to NewModule", 2)
			end
			local lowerName = libName:lower()
			if moduleNameLower[lowerName] then
				error("Module name '"..lowerName.."' already in use by NewModule", 2)
			end
			if moduleTypeLookup[lowerName] then
				-- block using one of the libTypes as a name (may add more reserved names in future)
				error("Module name "..lowerName.." is not a valid name", 2)
			end
			local typeTable = lib.Modules[libType] -- ### temp
			assert(typeTable) -- ### temp
			assert(not typeTable[libName]) -- ### temp
			if addonName then
				if type(addonName) ~= "string" then
					error("AddOn name must be a string or nil for NewModule", 2)
				end
				addonName = addonName:lower()
				if moduleOnLoadNames and moduleOnLoadNames[addonName] then
					error("AddOn name already registered with NewModule", 2)
				end
				-- if addonName matches the Auc naming convention we do not need to take any special action with it
				-- also explicitly block "auc-advanced" as only Core modules should use that name, and they get special handling
				if addonName == "auc-advanced" or addonName == strjoin("-", "Auc", libType, libName):lower() then
					addonName = nil
				end
			end

			local module = libTable or {}
			module.libName = libName
			module.libType = libType
			module.GetName = function() return libName end
			module.GetLibType = function() return libType end
			if not module.GetLocalName then -- don't create if it already exists
				module.GetLocalName = module.GetName
			end
			if not noExtras and not module.Private then
				module.Private = {} -- assign a private table if it is wanted and does not already exist
			end

			UpdateModuleTables(module, libName, libType, lowerName)
			if addonName then
				if not moduleOnLoadNames then
					moduleOnLoadNames = {}
				end
				moduleOnLoadNames[addonName] = module
			end

			private.resetPriceModels()
			internalUtil.ResetSPMArray()

			private.newmoduleCheckName = libName -- ### temp
			lib.SendProcessorMessage("newmodule", libType, libName)
			private.newmoduleCheckName = nil -- ### temp
			return module, lib, module.Private
		end
	end

	--[[

	Usage:
	  local aucPrint,decode,_,_,replicate,empty,get,set,default,debugPrint,fill,_TRANS = AucAdvanced.GetModuleLocals()

	-- ]]
	function lib.GetModuleLocals()
		return lib.Print, lib.DecodeLink,
		lib.Recycle, lib.Acquire, lib.Replicate, lib.Empty,
		lib.Settings.GetSetting, lib.Settings.SetSetting, lib.Settings.SetDefault,
		lib.Debug.DebugPrint, lib.Fill, lib.localizations
	end

	--[[

	Usage:
	  local libCopy = AucAdvanced.GetModule(libName) -- short form
	  local libCopy = AucAdvanced.GetModule(libType, libName, having)

	  libName: (required) module name (either correct case or lowercase)
	  libType: (optional) one of the valid module types (either correct case or lowercase)
	  having: (optional) checks that the module has this method (can also find other types of key)

	  No errors are thrown for invalid parameters, just a nil return

	--]]
	function lib.GetModule(libType, libName, having)
		if libName then
			local module = moduleNameLookupAll[libName] or moduleNameLower[libName]
			if module and (not having or module[having]) then
				if libType then
					if module.GetLibType() == moduleTypeLookup[libType] then
						return module
					end
				else
					return module
				end
			end
		else
			-- 'libType' is really the module name
			return moduleNameLookupAll[libType] or moduleNameLower[libType]
		end
	end

	--[[

	Usage:
	  local moduleList = AucAdvanced.GetAllModules(having, libType, useTable, mode)
	  local moduleLib = AucAdvanced.GetAllModules(having, libType, libName) -- deprecated form - included for compatibility

	  All parameters are optional
	  having: name of method that modules should contain (or any other key)
	  libType: one of the valid modules types (either correct case or lowercase)
	  useTable: function will use, and return, this table instead of creating an empty table
		(if useTable is not empty, new entries will be inserted after the existing ones)
	  mode: if provided, modules will be inserted as key = engineLib pairs (instead of an indexed list)
		mode = 1 : keys are module names

	  (deprecated) libName: a module name (correct case or lowercase) - only this lib will be returned (not a list)
		should use AucAdvanced.GetModule(libType, libName, having) instead

	  moduleList is a table containing a list of moduleLibs matching the specified parameters
		in a specific order: sorted by libType-descending then lowerName-ascending (unless key mode was specified)
		if no modules matching the parameters are found the table will be empty (or unchanged if useTable was supplied)

	  Returns nil if any parameters were invalid

	--]]
	function lib.GetAllModules(having, findSystem, useTable, mode)
		local modules

		if useTable then
			local t = type(useTable)
			if t == "table" then
				modules = useTable
			elseif t == "string" then
				lib.API.ShowDeprecationAlert("GetModule")
				return lib.GetModule(findSystem, useTable, having)
			else
				return
			end
		else
			modules = {}
		end

		if findSystem then
			findSystem = moduleTypeLookup[findSystem]
			if not findSystem then return end
		else
			findSystem = "All"
		end

		if mode == 1 then
			-- key mode: entries are name~lib pairs
			if having then
				for name, module in pairs(moduleNameLookups[findSystem]) do
					if module[having] then
						modules[name] = module
					end
				end
			else
				for name, module in pairs(moduleNameLookups[findSystem]) do
					modules[name] = module
				end
			end
		else -- default, mode == 0
			-- sorted list mode
			if having then
				for _, module in ipairs(moduleSortedLists[findSystem]) do
					if module[having] then
						tinsert(modules, module)
					end
				end
			else
				for _, module in ipairs(moduleSortedLists[findSystem]) do
					tinsert(modules, module)
				end
			end
		end

		return modules
	end

	--[[

	Usage:
	  AucAdvanced.RegisterModuleCallback(moduleName, callbackFunction)

	  Used when you want to access features of another module, which will not be available until that module has fully loaded
	  Particularly useful when your module may load before the module you want to access

	  callbackFunction should be of the form:
		function callbackFunction(moduleLib)

	  Note: if the module is already loaded the callback will be triggered before this function returns

	--]]
	function lib.RegisterModuleCallback(moduleName, callback)
		if type(moduleName) ~= "string" then
			error("Module name must for a string for RegisterModuleCallback", 2)
		end
		if type(callback) ~= "function" then
			error("Callback must be a function for RegisterModuleCallback", 2)
		end
		moduleName = moduleName:lower()

		local module = lib.GetModule(moduleName)
		if module and module[MODULE_LOADED] then
			-- already loaded, fire callback immediately
			pcall(callback, module)
			return
		end

		if not moduleLoadCallbacks then
			moduleLoadCallbacks = {}
		end
		local list = moduleLoadCallbacks[moduleName]
		if not list then
			list = {}
			moduleLoadCallbacks[moduleName] = list
		end
		tinsert(list, callback)
	end

	--[[

	Usage:
	  AucAdvanced.NotifyModuleLoaded(moduleLib [, loadName])

	  Optional function to flag a module as Loaded, where the auto-detection features do not work
	  i.e. where the AddOn name does not match the Auc-LibType-LibName convention, and was not supplied to NewModule

	  Should *only* be called by the AddOn that created the module

	--]]
	function lib.NotifyModuleLoaded(module, loadName)
		if module[MODULE_LOADED] then return end

		loadName = loadName or module:GetName() -- if loadName not provided, use module name instead
		lib.SendProcessorMessage("load", loadName:lower()) -- always lowercase, to emulate CoreMain OnLoad

		internalUtil.SendModuleCallbacks(module) -- also sets Loaded flag
	end

end -- end of Module Functions


local spmArray = {}
if not lib.ABORTLOAD then -- don't install function if there is an error condtion
	function lib.SendProcessorMessage(spmMsg, ...)
		local spmp = spmArray[spmMsg]
		if (spmp) then
			for i=1,#spmp do
				local x = spmp[i]
				local f = x.Func

				local good,msg=pcall(f, spmMsg, ...)
				if not good then
					msg = "Error trapped for Processor message '"..spmMsg.."' in module "..x.Name..":\n"..msg
					lib.Debug.DebugPrint(msg, "SendProcessorMessage", "Processor Error in "..x.Name, 0, "Debug")
					geterrorhandler()(msg)
				end
			end
		else
			spmp = {}
			spmArray[spmMsg] = spmp

			local modules = lib.GetAllModules("Processors")
			for pos, engineLib in ipairs(modules) do
				local f = engineLib.Processors[spmMsg]
				if f then
					local x = {}
					x.Name = engineLib.GetName()
					if (spmMsg=="tooltip") then
						local f1 = f
						x.Func = function(spmMsg, ...)
							-- TODO: Make these defaults configurable
							tooltip:SetColor(0.3, 0.9, 0.8)
							tooltip:SetMoneyAsText(false)
							tooltip:SetEmbed(false)
							f1(spmMsg, ...)
						end
					else
						x.Func = f
					end
					tinsert(spmp, x)
					local good,msg=pcall(f, spmMsg, ...)
					if not good then
						msg = "Error trapped for Processor message '"..spmMsg.."' in module "..x.Name..":\n"..msg
						lib.Debug.DebugPrint(msg, "SendProcessorMessage", "Processor Error in "..x.Name, 0, "Debug")
						geterrorhandler()(msg)
					end
				end
			end

			modules = lib.GetAllModules("Processor")
			for pos, engineLib in ipairs(modules) do
				if (not engineLib.Processors) then
					local x = {}
					x.Name = engineLib.GetName()
					x.Func = engineLib.Processor
					lib.Debug.DebugPrint("Module "..x.Name.." using deprecated 'Processor' function for "..(spmMsg or "Unknown").." processor messages.", "SendProcessorMessage", "Deprecated Function Seen in "..x.Name, 0, "Warning")
					tinsert(spmp, x)
					local good,msg=pcall(engineLib.Processor, spmMsg, ...)
					if not good then
						msg = "Error trapped for Processor message '"..spmMsg.."' in module "..x.Name..":\n"..msg
						lib.Debug.DebugPrint(msg, "SendProcessorMessage", "Processor Error in "..x.Name, 0, "Debug")
						geterrorhandler()(msg)
					end
				end
			end
		end
	end
end

function internalUtil.ResetSPMArray() -- make available to CoreMain
	wipe(spmArray)
end

-- Returns the tooltip helper
function lib.GetTooltip()
	return tooltip
end

-- Turns a copper amount into colorized text
function lib.Coins(amount, graphic)
	return (tooltip:Coins(amount, graphic))
end

-- Creates a new coin object
function lib.CreateMoney(height)
	return (tooltip:CreateMoney(height))
end

lib.RegisterRevision("$URL: Auc-Advanced/CoreUtil.lua $", "$Rev: 6733 $")
lib.CoreFileCheckOut("CoreUtil")
