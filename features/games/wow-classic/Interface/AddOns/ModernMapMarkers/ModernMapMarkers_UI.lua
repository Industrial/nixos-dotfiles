-- ModernMapMarkers_UI.lua (WoW: Forever 1.60+, interface 16001)
-- Marker tooltip, destination popup, filter dropdown, Find Marker panel, slash command.
-- Everything here is created from MMM.SetupUI(), which the core calls once
-- WorldMapFrame exists.

local strfind    = string.find
local strsub     = string.sub
local tsort      = table.sort
local tinsert    = table.insert
local math_floor = math.floor
local math_min   = math.min
local sformat    = string.format
local slower     = string.lower

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

MMM = MMM or {}

-- ============================================================
-- Marker tooltip
-- (GameTooltip anchored to the pin; replaces the 3.3.5a custom
--  label that sat under WorldMapFrameAreaLabel.)
-- ============================================================

local FACTION_COLORS = {
	Alliance = {0.15, 0.59, 0.75},
	Horde    = {0.89, 0.16, 0.10},
	Neutral  = {1,    0.82, 0   },
}

local function GetLevelColor(level)
	local delta = level - UnitLevel("player")
	if     delta >= 5  then return 1,    0.1,  0.1
	elseif delta >= 1  then return 1,    0.5,  0.25
	elseif delta >= -4 then return 1,    1,    0
	elseif delta >= -9 then return 0.25, 0.75, 0.25
	else                    return 0.6,  0.6,  0.6
	end
end

function MMM.ShowMarkerInfo(owner, name, info, hint)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")

	-- Name may carry a comment after "\n" (already colour-coded in the data).
	local nl = strfind(name, "\n")
	if nl then
		GameTooltip:AddLine(strsub(name, 1, nl - 1), 1, 0.82, 0)
		GameTooltip:AddLine(strsub(name, nl + 1), 1, 1, 1)
	else
		GameTooltip:AddLine(name, 1, 0.82, 0)
	end

	if info and info ~= "" then
		local color = FACTION_COLORS[info]
		if color then
			GameTooltip:AddLine("(" .. info .. ")", color[1], color[2], color[3])
		else
			local _, _, _, maxStr = strfind(info, "^(%d+)-(%d+)$")
			local maxLevel = tonumber(maxStr or info)
			if maxLevel then
				local r, g, b = GetLevelColor(maxLevel)
				GameTooltip:AddLine("(Level " .. sformat("|cFF%02X%02X%02X%s|r", r * 255, g * 255, b * 255, info) .. ")", 1, 0.82, 0)
			else
				GameTooltip:AddLine("(" .. info .. ")", 1, 0.82, 0)
			end
		end
	end

	if hint and hint ~= "" then
		GameTooltip:AddLine(hint, 0.8, 0.8, 0.8, false)
	end
	
	if C_Map and C_Map.SetUserWaypoint then
		-- Only show Dungeon/Raid tooltips if it's actually a dungeon or raid pin
		if owner and (owner.markerKind == "dungeon" or owner.markerKind == "raid") then
			-- Check if HiddenMaps is installed
			if SlashCmdList and SlashCmdList.HIDDENMAPSMAP then
				GameTooltip:AddLine("|cFFFFD700Left Click:|r Open Dungeon Map", 0.8, 0.8, 0.8, false)
			end
			-- Check if ForeverDungeonJournal is installed
			if SlashCmdList and SlashCmdList.FOREVERDUNGEONJOURNAL then
				GameTooltip:AddLine("|cFFFFD700Right Click:|r Open Dungeon Journal", 0.8, 0.8, 0.8, false)
			end
		end
		
		-- Always show the waypoint hint since it's a native game feature
		GameTooltip:AddLine("|cFFFFD700Ctrl+Left Click:|r Set map pin here", 0.8, 0.8, 0.8, false)
	end
	
	GameTooltip:Show()
end

function MMM.HideMarkerInfo()
	local owner = GameTooltip:GetOwner()
	if owner and owner.markerName and owner.originalSize then
		GameTooltip:Hide()
	end
end

-- ============================================================
-- Destination popup menu (transports with 3+ destinations)
-- ============================================================

local destMenu
local destMenuPin

local function HideDestMenu()
	if destMenu then
		destMenu:Hide()
		destMenu.intercept:Hide()
	end
	destMenuPin = nil
end

function MMM.HideDestMenu() HideDestMenu() end

local function CreateDestMenu()
	local level = MMM.GetPinLevel()
	destMenu = CreateFrame("Frame", "MMMDestMenu", WorldMapFrame, BACKDROP_TEMPLATE)
	destMenu:SetFrameStrata("FULLSCREEN_DIALOG")
	destMenu:SetFrameLevel(level + 20)
	destMenu:SetBackdrop({
		bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = {left = 4, right = 4, top = 4, bottom = 4},
	})
	destMenu:SetBackdropColor(0, 0, 0, 0.85)
	destMenu.buttons = {}
	destMenu:Hide()

	-- Full-map click catcher so a click outside the menu closes it.
	destMenu.intercept = CreateFrame("Button", nil, WorldMapFrame)
	destMenu.intercept:SetAllPoints(WorldMapFrame.ScrollContainer or WorldMapFrame)
	destMenu.intercept:SetFrameStrata("FULLSCREEN_DIALOG")
	destMenu.intercept:SetFrameLevel(level + 19)
	destMenu.intercept:SetScript("OnClick", HideDestMenu)
	destMenu.intercept:Hide()
end

local MENU_BUTTON_HEIGHT = 22
local MENU_BUTTON_WIDTH  = 160
local MENU_PADDING       = 8

function MMM.ShowDestMenu(pin)
	if not destMenu then CreateDestMenu() end
	if destMenuPin == pin and destMenu:IsShown() then HideDestMenu(); return end

	destMenuPin = pin
	local dests = pin.dests
	local count = #dests

	for i = 1, count do
		if not destMenu.buttons[i] then
			local btn = CreateFrame("Button", nil, destMenu)
			btn:SetHeight(MENU_BUTTON_HEIGHT)
			btn:SetNormalFontObject("GameFontNormalSmall")
			btn:SetHighlightFontObject("GameFontHighlightSmall")
			btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
			btn:SetScript("OnClick", function(self)
				local d = self.destTable[self.destIndex]
				local currentMap = WorldMapFrame:GetMapID()
				local ownerPin = destMenuPin
				HideDestMenu()
				if d.map == currentMap then
					MMM.HighlightOtherPin(currentMap, ownerPin)
				else
					MMM.NavigateToTransportDest(d.map, currentMap)
				end
			end)
			destMenu.buttons[i] = btn
		end
		local btn = destMenu.buttons[i]
		btn.destIndex = i
		btn.destTable = dests
		btn:SetText(dests[i].label or ("Destination " .. i))
		btn:SetWidth(MENU_BUTTON_WIDTH)
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", destMenu, "TOPLEFT", MENU_PADDING, -(MENU_PADDING + (i - 1) * MENU_BUTTON_HEIGHT))
		btn:Show()
	end

	for i = count + 1, #destMenu.buttons do destMenu.buttons[i]:Hide() end
	destMenu:SetWidth(MENU_BUTTON_WIDTH + MENU_PADDING * 2)
	destMenu:SetHeight(MENU_BUTTON_HEIGHT * count + MENU_PADDING * 2)
	destMenu:ClearAllPoints()
	destMenu:SetPoint("BOTTOMLEFT", pin, "TOPRIGHT", 4, -4)
	destMenu:Show()
	destMenu.intercept:Show()
end

-- ============================================================
-- Filter dropdown
-- ============================================================

local function ApplyChange()
	MMM.ForceRedraw()
	MMM.UpdateMarkers()
end

local function RefreshFilterChecks()
	-- Re-evaluates every button's checked() so radios/toggles update in place.
	if UIDropDownMenu_Refresh and MMMFilterDropdown then
		pcall(UIDropDownMenu_Refresh, MMMFilterDropdown, nil, 1)
	end
end

local function InitFilterDropdown()
	local db = ModernMapMarkersDB

	local function addToggle(text, key)
		local info = {
			text = text, keepShownOnClick = true, isNotRadio = true,
			checked = function() return db[key] end,
		}
		info.func = function() db[key] = not db[key]; ApplyChange(); RefreshFilterChecks() end
		UIDropDownMenu_AddButton(info, 1)
	end

	local function addHeader(text)
		UIDropDownMenu_AddButton({text = text, isTitle = true, notCheckable = true}, 1)
	end

	local function addFactionRadio(text, dbKey, value)
		local info = {
			text = text, keepShownOnClick = true,
			checked = function() return db[dbKey] == value end,
		}
		info.func = function() db[dbKey] = value; ApplyChange(); RefreshFilterChecks() end
		UIDropDownMenu_AddButton(info, 1)
	end

	local all = {
		text = "All Markers", keepShownOnClick = true, isNotRadio = true,
		checked = function() return db.showMarkers end,
	}
	all.func = function()
		db.showMarkers = not db.showMarkers
		if not db.showMarkers then MMM.ClearMarkers(); MMM.SetUpdateEnabled(false)
		else MMM.SetUpdateEnabled(true) end
		ApplyChange()
		RefreshFilterChecks()
	end
	UIDropDownMenu_AddButton(all, 1)

	addToggle("Dungeons",     "showDungeons")
	addToggle("Raids",        "showRaids")
	addToggle("World Bosses", "showWorldBosses")
	addToggle("Battlegrounds", "showBattlegrounds")
	addHeader("Transports")
	addToggle("Boats",        "showBoats")
	addToggle("Zeppelins",    "showZeppelins")
	addToggle("Skyships",     "showSkyships")
	addToggle("Trams",        "showTrams")
	addToggle("Portals",      "showPortals")
	-- Race-restricted markers: only list the toggles the player can actually use.
	local canLey, canConv = MMM.RaceAllowed("leyline"), MMM.RaceAllowed("convergence")
	if canLey or canConv then
		addHeader("Skyborne")
		if canLey  then addToggle("Ley Lines",              "showLeylines") end
		if canConv then addToggle("Elemental Convergences", "showConvergences") end
	end
	addHeader("Transport Faction")
	addFactionRadio("Show All",               "transportFaction", "all")
	addFactionRadio("|cFF2592C5Alliance|r",   "transportFaction", "Alliance")
	addFactionRadio("|cFFE32A19Horde|r",      "transportFaction", "Horde")
	addHeader("Portal Faction")
	addFactionRadio("Show All",               "portalFaction", "all")
	addFactionRadio("|cFF2592C5Alliance|r",   "portalFaction", "Alliance")
	addFactionRadio("|cFFE32A19Horde|r",      "portalFaction", "Horde")
	addHeader("Battleground Faction")
	addFactionRadio("Show All",               "bgFaction", "all")
	addFactionRadio("|cFF2592C5Alliance|r",   "bgFaction", "Alliance")
	addFactionRadio("|cFFE32A19Horde|r",      "bgFaction", "Horde")
end

-- ============================================================
-- Find Marker panel
-- ============================================================

local FIND_CONTINENTS = {
	{id = 1, label = "Kalimdor"},
	{id = 2, label = "Eastern Kingdoms"},
}
local FIND_TYPES = {
	{id = "dungeon",   label = "Dungeons"},
	{id = "raid",      label = "Raids"},
	{id = "worldboss", label = "World Bosses"},
}

local PANEL_WIDTH      = 260
local ROW_HEIGHT       = 16
local MAX_VISIBLE_ROWS = 12
local BUTTON_HEIGHT    = 20
local BUTTON_SPACING   = 2
local PANEL_PADDING    = 8
local CONT_PER_ROW     = 2
local CONT_ROWS        = math.ceil(#FIND_CONTINENTS / CONT_PER_ROW)
-- continent rows + one row of type buttons
local LIST_AREA_TOP    = PANEL_PADDING + (BUTTON_HEIGHT + BUTTON_SPACING) * (CONT_ROWS + 1) + 4

local findActiveContinent = 1
local findActiveType      = "dungeon"
local findDisplayList     = {}
local findScratchList     = {}  -- reused scratch, avoids alloc on each rebuild
local findVisibleTypes    = {}  -- reused in UpdateFindButtonStates
local findTotalSlots      = 0
local findPanel
local findContButtons     = {}
local findTypeButtons     = {}
local findRowButtons      = {}
local findScrollFrame

local function CreateSelectorButton(name, parent, width, text)
	local btn = CreateFrame("Button", name, parent, BACKDROP_TEMPLATE)
	btn:SetSize(width, BUTTON_HEIGHT)
	btn:SetBackdrop({
		bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = {left = 2, right = 2, top = 2, bottom = 2},
	})
	local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("CENTER", 0, 0)
	label:SetText(text)
	btn.label = label
	btn:SetScript("OnEnter", function(self)
		if not self.isActive then self:SetBackdropColor(0.3, 0.3, 0.3, 1) end
	end)
	btn:SetScript("OnLeave", function(self)
		if not self.isActive then self:SetBackdropColor(0.15, 0.15, 0.15, 1) end
	end)
	btn.isActive = false
	btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
	btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
	return btn
end

local function SetSelectorActive(btn, active)
	btn.isActive = active
	if active then
		btn:SetBackdropColor(0.2, 0.4, 0.7, 1)
		btn:SetBackdropBorderColor(0.4, 0.6, 1.0, 1)
		btn.label:SetTextColor(1, 1, 1)
	else
		btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
		btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
		btn.label:SetTextColor(0.8, 0.8, 0.8)
	end
end

local function SortByLevelThenName(a, b)
	local _, _, av = strfind(a.description or "", "^(%d+)")
	local _, _, bv = strfind(b.description or "", "^(%d+)")
	local an, bn = tonumber(av) or 0, tonumber(bv) or 0
	if an == bn then return (a.name or "") < (b.name or "") end
	return an < bn
end

local function DrawFindRows()
	local offset = FauxScrollFrame_GetOffset(findScrollFrame)
	for i = 1, MAX_VISIBLE_ROWS do
		local row     = findRowButtons[i]
		local slotIdx = offset + i
		-- Reset highlight before assigning new content.
		row.hlTex:Hide()

		if slotIdx <= findTotalSlots then
			local slot = findDisplayList[slotIdx]
			if slot.kind == "name" then
				row:EnableMouse(true)
				row.nameRow = nil
				row.nameText:SetTextColor(1, 1, 1)
				row.nameText:SetText(slot.text)
				row.lvlText:SetText(slot.lvlText or "")
				local rw = row.rowWidth or row:GetWidth()
				row.rowWidth = rw
				row.nameText:SetWidth(rw - row.lvlText:GetStringWidth() - 16)
				row.dataMap  = slot.map
				row.dataName = slot.dataName
				if slot.hasComment and i < MAX_VISIBLE_ROWS then
					row.hlTex:ClearAllPoints()
					row.hlTex:SetPoint("TOPLEFT",     row, "TOPLEFT",     0,  0)
					row.hlTex:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -ROW_HEIGHT)
				else
					row.hlTex:SetAllPoints(row)
				end
			else
				local parent = findDisplayList[slotIdx - 1]
				row:EnableMouse(true)
				row.nameText:SetText(slot.text)
				row.nameText:SetTextColor(0.55, 0.55, 0.55)
				local rw = row.rowWidth or row:GetWidth()
				row.rowWidth = rw
				row.nameText:SetWidth(rw - 8)
				row.lvlText:SetText("")
				row.dataMap  = parent.map
				row.dataName = parent.dataName
				row.nameRow  = findRowButtons[i - 1]
			end
			row:Show()
		else
			row.nameText:SetText("")
			row.lvlText:SetText("")
			row.nameText:SetTextColor(1, 1, 1)
			row.dataMap  = nil
			row.dataName = nil
			row.hlTex:SetAllPoints(row)
			row.nameRow = nil
			row:Hide()
		end
	end
end

local function RebuildFindList()
	local flatData = MMM.GetFlatData()
	wipe(findScratchList)
	for i = 1, #flatData do
		local d = flatData[i]
		if d.continent == findActiveContinent and d.type == findActiveType then
			tinsert(findScratchList, d)
		end
	end
	tsort(findScratchList, SortByLevelThenName)

	wipe(findDisplayList)
	for i = 1, #findScratchList do
		local data     = findScratchList[i]
		local baseName = data.name
		local comment
		local nl = strfind(baseName, "\n")
		if nl then
			comment  = strsub(baseName, nl + 1)
			baseName = strsub(baseName, 1, nl - 1)
		end

		local lvlStr = ""
		if data.description then
			local _, _, _, maxStr = strfind(data.description, "^(%d+)-(%d+)$")
			local maxLevel = tonumber(maxStr or data.description)
			if maxLevel then
				local r, g, b = GetLevelColor(maxLevel)
				lvlStr = sformat("Level |cff%02X%02X%02X%s|r", r * 255, g * 255, b * 255, data.description)
			else
				lvlStr = "Level " .. data.description
			end
		end

		tinsert(findDisplayList, {
			kind = "name", text = baseName, lvlText = lvlStr,
			map = data.map, dataName = data.name, hasComment = (comment ~= nil),
		})

		if comment then
			local s = comment
			local _, ce = strfind(s, "^|c%x%x%x%x%x%x%x%x")
			if ce then s = strsub(s, ce + 1) end
			local rs = strfind(s, "|r$")
			if rs then s = strsub(s, 1, rs - 1) end
			tinsert(findDisplayList, {kind = "comment", text = s})
		end
	end

	findTotalSlots = #findDisplayList
	findPanel:SetHeight(LIST_AREA_TOP + math_min(findTotalSlots, MAX_VISIBLE_ROWS) * ROW_HEIGHT + PANEL_PADDING + 4)
	FauxScrollFrame_SetOffset(findScrollFrame, 0)
	FauxScrollFrame_Update(findScrollFrame, findTotalSlots, MAX_VISIBLE_ROWS, ROW_HEIGHT)
	DrawFindRows()
end

local function UpdateFindButtonStates()
	for i = 1, #FIND_CONTINENTS do
		SetSelectorActive(findContButtons[i], FIND_CONTINENTS[i].id == findActiveContinent)
	end

	local flatData    = MMM.GetFlatData()
	local typeVisible = {}
	for i = 1, #FIND_TYPES do typeVisible[i] = false end
	for di = 1, #flatData do
		local d = flatData[di]
		if d.continent == findActiveContinent then
			for i = 1, #FIND_TYPES do
				if FIND_TYPES[i].id == d.type then typeVisible[i] = true end
			end
		end
	end

	-- Fall back to first visible type if the active type has no data here.
	local valid = false
	for i = 1, #FIND_TYPES do
		if FIND_TYPES[i].id == findActiveType and typeVisible[i] then valid = true; break end
	end
	if not valid then
		for i = 1, #FIND_TYPES do
			if typeVisible[i] then findActiveType = FIND_TYPES[i].id; break end
		end
	end

	wipe(findVisibleTypes)
	for i = 1, #FIND_TYPES do
		if typeVisible[i] then tinsert(findVisibleTypes, findTypeButtons[i]); findTypeButtons[i]:Show()
		else findTypeButtons[i]:Hide() end
	end
	local n = #findVisibleTypes
	if n > 0 then
		local btnW   = (PANEL_WIDTH - PANEL_PADDING * 2 - BUTTON_SPACING * (n - 1)) / n
		local anchor = findContButtons[(CONT_ROWS - 1) * CONT_PER_ROW + 1]
		for j = 1, n do
			local btn = findVisibleTypes[j]
			btn:SetWidth(btnW)
			btn:ClearAllPoints()
			if j == 1 then
				btn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -BUTTON_SPACING)
			else
				btn:SetPoint("TOPLEFT", findVisibleTypes[j - 1], "TOPRIGHT", BUTTON_SPACING, 0)
			end
		end
	end
	for i = 1, #FIND_TYPES do
		SetSelectorActive(findTypeButtons[i], FIND_TYPES[i].id == findActiveType)
	end
end

local function CreateFindPanel(anchorFrame)
	findPanel = CreateFrame("Frame", "MMMFindPanel", WorldMapFrame, BACKDROP_TEMPLATE)
	findPanel:SetFrameStrata("DIALOG")
	findPanel:SetFrameLevel(100)
	findPanel:SetSize(PANEL_WIDTH, 100)
	findPanel:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 16, 0)
	findPanel:SetBackdrop({
		bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = {left = 4, right = 4, top = 4, bottom = 4},
	})
	findPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
	findPanel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	findPanel:Hide()

	local halfWidth = (PANEL_WIDTH - PANEL_PADDING * 2 - BUTTON_SPACING) / 2
	for i = 1, #FIND_CONTINENTS do
		local cont = FIND_CONTINENTS[i]
		local col  = (i - 1) % CONT_PER_ROW
		local row  = math_floor((i - 1) / CONT_PER_ROW)
		local btn  = CreateSelectorButton("MMMFind_Cont" .. i, findPanel, halfWidth, cont.label)
		if col == 0 then
			if row == 0 then
				btn:SetPoint("TOPLEFT", findPanel, "TOPLEFT", PANEL_PADDING, -PANEL_PADDING)
			else
				btn:SetPoint("TOPLEFT", findContButtons[i - CONT_PER_ROW], "BOTTOMLEFT", 0, -BUTTON_SPACING)
			end
		else
			btn:SetPoint("TOPLEFT", findContButtons[i - 1], "TOPRIGHT", BUTTON_SPACING, 0)
		end
		local c = cont.id
		btn:SetScript("OnClick", function()
			findActiveContinent = c; UpdateFindButtonStates(); RebuildFindList()
		end)
		findContButtons[i] = btn
	end

	local numType   = #FIND_TYPES
	local typeWidth = (PANEL_WIDTH - PANEL_PADDING * 2 - BUTTON_SPACING * (numType - 1)) / numType
	local lastContRowFirst = findContButtons[(CONT_ROWS - 1) * CONT_PER_ROW + 1]
	for i = 1, numType do
		local tp  = FIND_TYPES[i]
		local btn = CreateSelectorButton("MMMFind_Type" .. i, findPanel, typeWidth, tp.label)
		if i == 1 then
			btn:SetPoint("TOPLEFT", lastContRowFirst, "BOTTOMLEFT", 0, -BUTTON_SPACING)
		else
			btn:SetPoint("TOPLEFT", findTypeButtons[i - 1], "TOPRIGHT", BUTTON_SPACING, 0)
		end
		local t = tp.id
		btn:SetScript("OnClick", function()
			findActiveType = t; UpdateFindButtonStates(); RebuildFindList()
		end)
		findTypeButtons[i] = btn
	end

	findScrollFrame = CreateFrame("ScrollFrame", "MMMFindScroll", findPanel, "FauxScrollFrameTemplate")
	findScrollFrame:SetPoint("TOPLEFT",     findPanel, "TOPLEFT",      PANEL_PADDING,           -LIST_AREA_TOP)
	findScrollFrame:SetPoint("BOTTOMRIGHT", findPanel, "BOTTOMRIGHT", -PANEL_PADDING - 22,       PANEL_PADDING)
	findScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, DrawFindRows)
	end)

	for i = 1, MAX_VISIBLE_ROWS do
		local row = CreateFrame("Button", "MMMFind_Row" .. i, findPanel)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("TOPLEFT", findScrollFrame, "TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
		row:SetPoint("RIGHT",   findScrollFrame, "RIGHT",   0, 0)

		local hlTex = row:CreateTexture(nil, "OVERLAY")
		hlTex:SetAllPoints(row)
		hlTex:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		hlTex:SetBlendMode("ADD")
		hlTex:SetAlpha(0.7)
		hlTex:Hide()
		row.hlTex = hlTex

		local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		nameText:SetPoint("TOPLEFT",     row, "TOPLEFT",     4, 0)
		nameText:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
		nameText:SetJustifyH("LEFT")
		nameText:SetJustifyV("MIDDLE")
		row.nameText = nameText

		local lvlText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		lvlText:SetPoint("TOPRIGHT",    row, "TOPRIGHT",    -4, 0)
		lvlText:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 0)
		lvlText:SetJustifyH("RIGHT")
		lvlText:SetJustifyV("MIDDLE")
		row.lvlText = lvlText

		row:SetScript("OnClick", function(self)
			if self.dataMap then
				MMM.FindMarker(self.dataMap, self.dataName)
			end
		end)
		row:SetScript("OnEnter", function(self)
			if self.dataName then
				if self.nameRow then self.nameRow.hlTex:Show() else self.hlTex:Show() end
			end
		end)
		row:SetScript("OnLeave", function(self)
			if self.nameRow then self.nameRow.hlTex:Hide() else self.hlTex:Hide() end
		end)

		row:Hide()
		findRowButtons[i] = row
	end

	-- HookScript (not SetScript) so we never replace Blizzard's handler.
	WorldMapFrame:HookScript("OnHide", function() findPanel:Hide() end)
end

-- ============================================================
-- Find Marker navigation
-- ============================================================

function MMM.FindMarker(mapID, markerName)
	if not WorldMapFrame:IsShown() and ToggleWorldMap then ToggleWorldMap() end
	MMM.PlayClickSound()
	MMM.pendingHighlight = markerName
	if WorldMapFrame:GetMapID() == mapID then
		MMM.ForceRedraw()
		MMM.UpdateMarkers()
	else
		WorldMapFrame:SetMapID(mapID)
		MMM.UpdateMarkers() -- no-op if the OnMapChanged hook already redrew
	end
end

-- ============================================================
-- Dropdowns
-- ============================================================

-- Both dropdowns sit over the top-left corner of the map canvas.
local DROPDOWN_ANCHOR_X = 16
local DROPDOWN_ANCHOR_Y = 0

local function CreateDropdowns()
	local filterDropdown = CreateFrame("Frame", "MMMFilterDropdown", WorldMapFrame, "UIDropDownMenuTemplate")
	local findDropdown   = CreateFrame("Frame", "MMMFindDropdown",   WorldMapFrame, "UIDropDownMenuTemplate")

	local anchor = WorldMapFrame.ScrollContainer or WorldMapFrame
	filterDropdown:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", DROPDOWN_ANCHOR_X, DROPDOWN_ANCHOR_Y)
	findDropdown:SetPoint("TOPLEFT", filterDropdown, "BOTTOMLEFT", 0, 0)


	local baseLevel = MMM.GetPinLevel() + 10
	filterDropdown:SetFrameLevel(baseLevel)
	findDropdown:SetFrameLevel(baseLevel)
	-- SetFrameLevel does not re-level existing children, so lift the buttons too.
	if MMMFilterDropdownButton then MMMFilterDropdownButton:SetFrameLevel(baseLevel + 2) end
	if MMMFindDropdownButton   then MMMFindDropdownButton:SetFrameLevel(baseLevel + 2) end

	UIDropDownMenu_SetWidth(filterDropdown, 120)
	UIDropDownMenu_SetButtonWidth(filterDropdown, 125)
	UIDropDownMenu_SetWidth(findDropdown, 120)
	UIDropDownMenu_SetButtonWidth(findDropdown, 125)
	UIDropDownMenu_SetText(filterDropdown, "Filter Markers")
	UIDropDownMenu_SetText(findDropdown,   "Find Marker")
	UIDropDownMenu_Initialize(findDropdown, function() end)
	UIDropDownMenu_Initialize(filterDropdown, InitFilterDropdown)

	local findBtn = MMMFindDropdownButton
	if findBtn then
		findBtn:SetScript("OnClick", function()
			MMM.PlayClickSound()
			if not findPanel then
				CreateFindPanel(findDropdown)
			end
			if findPanel:IsShown() then
				findPanel:Hide()
			else
				-- Open on the map's current continent if we can tell.
				local c = MMM.GetContinentForMap(WorldMapFrame:GetMapID())
				if c then findActiveContinent = c end
				UpdateFindButtonStates()
				RebuildFindList()
				findPanel:Show()
			end
		end)
	end
end

-- ============================================================
-- Slash command
-- ============================================================

local function Say(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cFF7FFF7FMMM:|r " .. msg)
end

-- Prints where you are standing as a ready-to-paste MarkerData line.
-- Stand on a dungeon/raid entrance and run /mmm here.
local function PrintHere()
	if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
		Say("C_Map is not available.")
		return
	end
	local mapID = C_Map.GetBestMapForUnit("player")
	local pos   = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then
		Say("No map position for you here (instance, or the map has no coordinates).")
		return
	end
	local x, y  = pos:GetXY()
	local info  = C_Map.GetMapInfo(mapID)
	local cont  = MMM.GetContinentForMap(mapID)
	Say(sformat("uiMapID %d (%s), continent bucket %s, x=%.3f y=%.3f",
		mapID, info and info.name or "?", cont and (cont == 1 and "[1] Kalimdor" or "[2] Eastern Kingdoms") or "unknown", x, y))
	Say(sformat("|cFFFFFF00{%d, %.3f, %.3f, \"NAME\", \"dungeon\", \"LEVELS\", nil},|r", mapID, x, y))
end

SLASH_MMM1 = "/mmm"
SlashCmdList["MMM"] = function(msg)
	msg = slower(strtrim(msg or ""))
	if msg == "hints" then
		ModernMapMarkersDB.showTransportHints = not ModernMapMarkersDB.showTransportHints
		MMM.RefreshVisibleTooltip()
		return
	elseif msg == "here" then
		PrintHere()
		return
	elseif msg == "race" then
		local name, file, id = UnitRace("player")
		Say(sformat("UnitRace: name=%s token=%s id=%s", tostring(name), tostring(file), tostring(id)))
		return
	elseif msg == "allraces" then
		local db = ModernMapMarkersDB
		db.showAllRaces = not db.showAllRaces
		Say("Show race-restricted markers for all races: " .. (db.showAllRaces and "ON" or "OFF"))
		MMM.ForceRedraw()
		MMM.UpdateMarkers()
		return
	elseif msg ~= "" then
		Say("/mmm  -- show/hide the map dropdowns")
		Say("/mmm hints  -- toggle transport click hints")
		Say("/mmm here  -- print your position as a MarkerData line")
		Say("/mmm race  -- print your race name/token (for the Skyborne marker filter)")
		Say("/mmm allraces  -- show race-restricted markers regardless of your race")
		return
	end
	if MMMFilterDropdown then
		if MMMFilterDropdown:IsShown() then MMMFilterDropdown:Hide()
		else MMMFilterDropdown:Show() end
	end
	if MMMFindDropdown then
		if MMMFindDropdown:IsShown() then
			MMMFindDropdown:Hide()
			if findPanel then findPanel:Hide() end
		else
			MMMFindDropdown:Show()
		end
	end
end

-- ============================================================
-- Initialisation (called by the core once WorldMapFrame exists)
-- ============================================================

local uiCreated = false
function MMM.SetupUI()
	if uiCreated then return end
	uiCreated = true
	CreateDropdowns()
end
