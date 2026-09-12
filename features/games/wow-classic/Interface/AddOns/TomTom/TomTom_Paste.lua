local _, addon = ...
local L = addon.L

local ldb = LibStub("LibDataBroker-1.1")
local ldbicon = LibStub("LibDBIcon-1.0")

local function initPasteWindow()
	if addon.pasteWindow then
		return addon.pasteWindow
	end

	addon.pasteWindow = CreateFrame("Frame", "TomTomPaste", UIParent, "DefaultPanelTemplate,ClickToDragTemplate")

	local frame = addon.pasteWindow
	frame:SetHeight(475)
	frame:SetWidth(465)
	frame:SetFrameStrata("HIGH")
	frame:ClearAllPoints()
	frame.TitleContainer.TitleText:SetText(L["TomTom Paste"])
	frame:SetPoint("CENTER", 0, 200)
	frame:Hide()

	-- Edit box time!
	frame.EditBox = CreateFrame("Frame", "TomTomPasteEditBox", frame, "TomTomScrollingEditBoxTemplate")
	local editBox = frame.EditBox

	editBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -80)
	editBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 65)

	local label = L["Add several /way commands here and click Paste or press Ctrl+Enter"]
	editBox.Label = editBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	editBox.Label:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 0, 5)
	editBox.Label:SetPoint("BOTTOMRIGHT", editBox, "TOPRIGHT", 0, 5)
	editBox.Label:SetWordWrap(true)
	editBox.Label:SetMaxLines(9)
	editBox.Label:SetJustifyV("BOTTOM")
	editBox.Label:SetJustifyH("LEFT")
	editBox.Label:SetText(label)

	local function executePaste()
		local text = frame.EditBox.ScrollingEditBox:GetText()
		local lines = {string.split("\n", text)}

		for idx, line in ipairs(lines) do
			line = line:gsub("^%S+", "")
			if line:match("%S+") then
				addon.SlashWayCommand(line)
			end
		end

		if addon.db.profile.paste.autoclose then
			frame:Hide()
		end
	end

	local function OnEscapePressed(o, editBox)
		editBox:ClearFocus()
	end

	local function OnEnterPressed(o, editBox)
		if IsControlKeyDown() then
			editBox:ClearFocus()
			executePaste()
			return
		end

		local text = editBox:GetText()
		text = text .. "\n"
		editBox:SetText(text)
	end

	editBox.ScrollingEditBox:RegisterCallback("OnEscapePressed", OnEscapePressed, editBox)
	editBox.ScrollingEditBox:RegisterCallback("OnEnterPressed", OnEnterPressed, editBox)

	local scrollBox = editBox.ScrollingEditBox:GetScrollBox()
	ScrollUtil.RegisterScrollBoxWithScrollBar(scrollBox, editBox.ScrollBar)

	local scrollBoxAnchorsWithBar = {
		CreateAnchor("TOPLEFT", editBox.ScrollingEditBox, "TOPLEFT", 0, 0),
		CreateAnchor("BOTTOMRIGHT", editBox.ScrollingEditBox, "BOTTOMRIGHT", -18, -1),
	}
	local scrollBoxAnchorsWithoutBar = {
		scrollBoxAnchorsWithBar[1],
		CreateAnchor("BOTTOMRIGHT", editBox.ScrollingEditBox, "BOTTOMRIGHT", -2, -1),
	}
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, editBox.ScrollBar, scrollBoxAnchorsWithBar, scrollBoxAnchorsWithoutBar)

	frame.ExportButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.ExportButton:SetText(L["Export waypoints"])
	frame.ExportButton:SetHeight(23)
	frame.ExportButton:SetWidth(165)
	frame.ExportButton:ClearAllPoints()
	frame.ExportButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 5)
	frame.ExportButton:SetScript("OnClick", function(button)
		local text = addon:GetWaypointsExportString()
		frame.EditBox.ScrollingEditBox:SetText(text)
	end)

	frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.CloseButton:SetText(L["Close"])
	frame.CloseButton:SetHeight(23)
	frame.CloseButton:SetWidth(100)
	frame.CloseButton:ClearAllPoints()
	frame.CloseButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 5)
	frame.CloseButton:SetScript("OnClick", function(button)
		frame:SetShown(false)
	end)

	frame.PasteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.PasteButton:SetText(L["Paste"])
	frame.PasteButton:SetHeight(23)
	frame.PasteButton:SetWidth(100)
	frame.PasteButton:ClearAllPoints()
	frame.PasteButton:SetPoint("RIGHT", frame.CloseButton, "LEFT", 0, 0)
	frame.PasteButton:SetScript("OnClick", executePaste)

	frame.AutoCloseCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	frame.AutoCloseCheck:SetSize(24, 24)
	frame.AutoCloseCheck:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 33)
	frame.AutoCloseCheck:SetChecked(addon.db.profile.paste.autoclose)
	frame.AutoCloseCheck:SetScript("OnClick", function(btn)
		addon.db.profile.paste.autoclose = btn:GetChecked()
	end)

	local autoCloseLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	autoCloseLabel:SetPoint("LEFT", frame.AutoCloseCheck, "RIGHT", 4, 0)
	autoCloseLabel:SetText(L["Auto-close after paste"])

	return addon.pasteWindow
end

--[[--------------------------------------------------------------------------
--  Minimap Button
----------------------------------------------------------------------------]]

local ldb_feed
local iconName = "TomTom-Paste"
local compartmentShown

local function getMinimapPasteButton()
    if not ldb_feed then
        ldb_feed = ldb:NewDataObject("TomTom-Paste", {
            type = "data source",
            icon = "interface/icons/inv_misc_note_03",
            text = L["TomTom Paste"],
            OnTooltipShow = function(tooltip)
                tooltip:AddLine(L["Toggle the TomTom Paste Window"])
            end,
            OnClick = function()
                local window = initPasteWindow()
                window:SetShown(not window:IsShown())
            end,
        })

        ldbicon:Register(iconName, ldb_feed, addon.db.profile.paste.button)
    end
end

--[[--------------------------------------------------------------------------
--  Convert all waypoints to /way commands that can be pasted
----------------------------------------------------------------------------]]
function addon:GetWaypointsExportString()
	local bits = {}

	for mapId, data in pairs(self.waypointprofile) do
		for key, waypoint in pairs(data) do
			local m, x, y = unpack(waypoint)
			local title = waypoint.title
			bits[#bits+1] = string.format("/way #%d %0.2f %0.2f %s", m, x*100, y*100, title)
		end
	end

	return table.concat(bits, "\n")
end


--[[--------------------------------------------------------------------------
--  Config Handler for /ttpaste
----------------------------------------------------------------------------]]

function addon:PasteConfigChanged()
    getMinimapPasteButton()
    ldbicon:Refresh(iconName, addon.db.profile.paste.button)

    local wantCompartment = addon.db.profile.paste.addon_compartment
    if wantCompartment ~= compartmentShown then
        compartmentShown = wantCompartment
        if wantCompartment then
            ldbicon:AddButtonToCompartment(iconName)
        else
            ldbicon:RemoveButtonFromCompartment(iconName)
        end
    end

    if addon.pasteWindow then
        addon.pasteWindow.AutoCloseCheck:SetChecked(addon.db.profile.paste.autoclose)
    end
end

--[[--------------------------------------------------------------------------
--  Slash Command for /ttpaste
----------------------------------------------------------------------------]]

SLASH_TOMTOM_PASTE1 = "/ttpaste"
SLASH_TOMTOM_PASTE2 = "/tomtompaste"
SLASH_TOMTOM_PASTE3 = "/ttp"

local slashModule = {}

function slashModule:InitPageDB()
	if not addon.db.profile.pastePages then
		addon.db.profile.pastePages = {}
	end
end

function slashModule:Toggle()
    local window = initPasteWindow()
    window:SetShown(not window:IsShown())
end

function slashModule:GetPage(title)
	self:InitPageDB()
	return addon.db.profile.pastePages[title]
end

function slashModule:SetPage(title, contents)
	self:InitPageDB()
	addon.db.profile.pastePages[title] = contents
end

function slashModule:DeletePage(title)
	self:InitPageDB()
	addon.db.profile.pastePages[title] = nil
end

function slashModule:ListPages()
    self:InitPageDB()
    local titles = {}
    for k,v in pairs(addon.db.profile.pastePages or {}) do
        table.insert(titles, k)
    end

    if #titles > 0 then
        addon:Printf(L["Saved pages: %s"], table.concat(titles, ", "))
    else
        addon:Printf(L["No pages saved"])
    end
end

function slashModule:getEditBoxText()
    return addon.pasteWindow.EditBox.ScrollingEditBox:GetText()
end

function slashModule:setEditBoxText(text)
    return addon.pasteWindow.EditBox.ScrollingEditBox:SetText(text)
end

function slashModule:SavePage(title)
    local contents = self:getEditBoxText()
    if not contents or #contents <= 0 then
        addon:Printf(L["No contents to save"])
        return
    end

    if not title then
        addon:Printf(L["Must specify page name"])
        return
    end

	self:SetPage(title, contents)
    addon:Printf(L["Saved %d characters to page '%s'"], #contents, title)
end

function slashModule:LoadPage(title)
    if not title then
        addon:Printf(L["Must specify a page title to load"])
        return
    end

	local contents = self:GetPage(title)
    if not contents then
        addon:Printf(L["No page found with title '%s'"], title)
        return
    end

    local window = initPasteWindow()
    window:SetShown(true)

    self:setEditBoxText(contents)
    addon:Printf(L["Loaded %d characters from page '%s'"], #contents, title)
end

function slashModule:RemovePage(title)
    if not title then
        addon:Printf(L["Must specify a page title to remove"])
        return
    end

    local contents = self:GetPage(title)
    if not contents then
        addon:Printf(L["No page found with title '%s'"], title)
        return
    end

	self:DeletePage(title)
    addon:Printf(L["Removed %d characters from page '%s'"], #contents, title)
end

function slashModule:ToggleMinimap(action)
    local hidden = addon.db.profile.paste.button.hide

    if action == "show" then
        hidden = false
    elseif action == "hide" then
        hidden = true
    else
        hidden = not hidden
    end

    if hidden then
        addon:Printf(L["Hiding the TomTom-Paste minimap button"])
    else
        addon:Printf(L["Showing the TomTom-Paste minimap button"])
    end

    addon.db.profile.paste.button.hide = hidden
    addon:PasteConfigChanged()
end

SlashCmdList["TOMTOM_PASTE"] = function(msg)
    local subCommand, remainder
    if not msg then
        subCommand = L["toggle"]
    else
        subCommand, remainder = msg:match("(%S+)%s*(.*)$")
        subCommand = subCommand and subCommand:lower()
    end

    if not subCommand then
        slashModule:Toggle()
    elseif subCommand == L["toggle"] then
        slashModule:Toggle()
    elseif subCommand == L["list"] then
        slashModule:ListPages()
    elseif subCommand == L["save"] then
        slashModule:SavePage(remainder)
    elseif subCommand == L["load"] then
        slashModule:LoadPage(remainder)
    elseif subCommand == L["remove"] then
        slashModule:RemovePage(remainder)
    elseif subCommand == L["minimap"] then
        slashModule:ToggleMinimap(remainder)
    else
        addon:Printf(L["Usage: /ttpaste [command]"])
        addon:Printf(L["  /ttpaste toggle - Show/hide the paste window"])
        addon:Printf(L["  /ttpaste list - List the titles of pages that have been saved"])
        addon:Printf(L["  /ttpaste save [title] - Save the current contents of the window with the given name"])
        addon:Printf(L["  /ttpaste load [title] - Load a saved page to the paste window"])
        addon:Printf(L["  /ttpaste remove [title] - Remove a saved page"])
        addon:Printf(L["  /ttpaste minimap - Show or Hide the minimap button for the paste window"])
        addon:Printf(L["  /ttpaste help - This help message"])
    end
end
