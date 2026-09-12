local ADDON, T = ...
local H, PC, TS, XU, config, L = {}, T.OPieCore, T.TenSettings, T.exUI, T.config, T.L

local frame = TS:CreateOptionsPanel("OPie", nil, {
	forceRootVersion=true,
	selfBrandedRoot=true,
	tabText="|TInterface/Buttons/UI-HomeButton:16:18:0:-4|t"
})
frame.version:SetText(PC:GetVersion() or "")
T.ConfigHomePanel = frame
local oy = TS.PANEL_VIEW_MARGIN_TOP_TITLESHIFT - 16
local t, ta = frame:CreateFontString(nil, "OVERLAY", "GameFont_Gigantic")
t:SetTextColor(1,1,1)
t:SetText("OPie")
t:SetPoint("TOP", 0, oy)
oy, t = oy - 32, frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
t:SetPoint("TOP", 0, oy)
t:SetText("|cffb0b0b0" .. GAME_VERSION_LABEL .. "|r " .. frame.version:GetText())

local navView = CreateFrame("Frame", nil, frame) do
	navView:SetHeight(100) -- going to overflow; it's fine
	navView:SetPoint("TOPLEFT", 0, oy - 32)
	navView:SetPoint("TOPRIGHT", 0, oy - 32)
	local function onNavClick(self)
		return H.HandleNavClick(self:GetID())
	end

	local actLineAnchor = CreateFrame("Frame", nil, navView)
	actLineAnchor:SetPoint("TOP")
	actLineAnchor:SetSize(500+32, 30)
	actLineAnchor:Hide()
	local b3st = DoesTemplateExist("BigRedThreeSliceButtonTemplate")
	local oy, t = 0
	local function makeActButton(id, text, w)
		t, ta = CreateFrame("Button", nil, navView, b3st and "BigRedThreeSliceButtonTemplate" or "UIPanelButtonTemplate", id), t
		t:SetSize(w or 160, 32)
		t:SetNormalFontObject(GameFontNormalMed2)
		t:SetHighlightFontObject(GameFontHighlightMed2)
		t:SetPushedTextOffset(b3st and 2 or -1, -1)
		t:SetText(text)
		t:SetScript("OnClick", onNavClick)
		if ta then
			t:SetPoint("LEFT", ta, "RIGHT", 16, 0)
		else
			t:SetPoint("LEFT", actLineAnchor, "LEFT", 0, oy)
		end
		local fs = t:GetFontString()
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", 9, 0)
		fs:SetPoint("RIGHT", -9, 0)
		fs:SetMaxLines(1)
		fs:SetJustifyH("CENTER")
	end
	makeActButton(1, L"What's New")
	makeActButton(2, L"Report an Issue", 180)
	makeActButton(3, L"Translate OPie")

	local function makeNav(id, title, text, y1)
		oy, t = oy - (y1 or 40), CreateFrame("Button", nil, navView, nil, id)
		t:SetSize(24,24)
		t:SetPoint("TOPLEFT", 18, oy)
		t:SetNormalFontObject(GameFontNormalLarge)
		t:SetHighlightFontObject(GameFontHighlightLarge)
		t:SetNormalTexture("Interface/Glues/Common/Glue-RightArrow-Button-Up")
		t:SetPushedTexture("Interface/Glues/Common/Glue-RightArrow-Button-Down")
		t:SetHighlightTexture("Interface/Glues/Common/Glue-RightArrow-Button-Highlight")
		t:SetPushedTextOffset(0,0)
		t:SetHitRectInsets(0, -150, 0, 0)
		t:SetScript("OnClick", onNavClick)
		t:SetText(title)
		t, ta = t:GetFontString(), t
		t:ClearAllPoints()
		t:SetPoint("LEFT", ta, "RIGHT", 3, -1)
		oy, t, ta = oy - 26, navView:CreateFontString(nil, "OVERLAY", "GameFontHighlight"), t
		t:SetTextColor(0.85, 0.85, 0.85)
		t:SetText(text)
		t:SetPoint("TOPLEFT", ta, "BOTTOMLEFT", 0, -6)
	end

	makeNav(4, L"Options", L"Customize OPie's appearance and behavior.", 75)
	makeNav(5, L"Ring Bindings", L"Customize OPie ring and in-ring key bindings.")
	makeNav(6, L"Custom Rings", L"Edit existing rings, or create your own custom OPie rings.")
	local svWarning = CreateFrame("Button", nil, navView) do
		oy = oy - 60
		svWarning:SetSize(300, 18)
		svWarning:SetPoint("TOPLEFT", 18, oy)
		svWarning:SetNormalFontObject(GameFontRed)
		svWarning:SetHighlightFontObject(GameFontHighlight)
		svWarning:SetScript("OnClick", function() config.checkSVState(frame, true) end)
		svWarning:SetScript("OnShow", function()
			if config.checkSVState(frame) then
				svWarning:Hide()
			end
		end)
		svWarning:SetText("|TInterface/EncounterJournal/UI-EJ-WarningTextIcon:0|t " .. L"Any changes you make now will not be saved.")
		local fs = svWarning:GetFontString()
		fs:ClearAllPoints()
		fs:SetPoint("LEFT")
		svWarning:SetWidth(math.max(300, fs:GetStringWidth()))
	end
end
local logView, clipBar = CreateFrame("Frame", nil, frame) do
	logView:SetHeight(100) -- going to overflow; it's fine
	logView:SetPoint("TOPLEFT", 0, oy - 32)
	logView:SetPoint("TOPRIGHT", 0, oy - 32)
	logView:Hide()
	logView:SetScript("OnHyperLinkClick", function(_, link, text)
		local url = link == "url" and text:match("|h(.-)|h") or link:match("^url:.-(%w+://.+)")
		if url then
			TS:ShowCopyOverlay(frame, BROWSER_COPY_LINK, " ", url, L"Copy the URL shown above and visit it using a web browser.", OKAY, 1)
		end
	end)
	local isLinkCursorSet
	local function clearLinkCursor()
		if isLinkCursorSet then
			isLinkCursorSet = nil
			SetCursor(nil)
		end
	end
	logView:SetScript("OnHyperlinkEnter", function()
		isLinkCursorSet = 1
		SetCursor("Interface/Cursor/Interact")
	end)
	logView:SetScript("OnHyperlinkLeave", clearLinkCursor)
	logView:SetScript("OnHide", clearLinkCursor)
	logView:SetHyperlinksEnabled(true)

	local oy, t = 0, logView:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	t:SetPoint("TOPLEFT", 20, oy)
	t:SetText(L"What's New")
	t = CreateFrame("Button", nil, logView, "UIPanelCloseButtonNoScripts")
	t:SetPoint("TOPRIGHT", -10, oy+6)
	t:SetScript("OnClick", function() frame.refresh() end)

	oy, t = oy-25, logView:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	t:SetPoint("TOPLEFT", 20, oy)
	t:SetPoint("TOPRIGHT", -20, oy)
	t:SetJustifyH("LEFT")
	local link = "|cff00a0ff|Hurl|hhttps://townlong-yak.com/addons/opie/release|h|r"
	local intro = (L"Selected highlights from recent updates to OPie are summarized below. For full release notes, please visit %s"):format(link)
	local MARK_TEXTURE = "Interface/AddOns/" .. ADDON .. "/gfx/mark.png"
	local uvMark = "|T" .. MARK_TEXTURE .. ":0:0:0:-4:2:1:1:2:0:1:221:102:0|t"
	intro = intro .. "\n\n" .. (L"Changes marked with %s were inspired by submitted feedback."):format(uvMark)
	t:SetFormattedText(intro, link)
	t:SetSpacing(3)

	local vGradient = {x=0, y=7}
	local clipHost = CreateFrame("Frame", nil, logView)
	clipHost:SetClipsChildren(true)
	clipHost:SetFlattensRenderLayers(true)
	clipHost:SetAlphaGradient(0, vGradient)
	clipHost:SetAlphaGradient(1, vGradient)
	clipHost:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -12)
	clipHost:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 12)
	clipHost:SetHyperlinkPropagateToParent(true)
	local clipAnchor = CreateFrame("Frame", nil, clipHost)
	clipAnchor:SetHeight(0.125)
	clipAnchor:SetPoint("TOPLEFT", 20, 0)
	clipAnchor:SetPoint("TOPRIGHT", 0, 0)
	clipBar = XU:Create("ScrollBar", nil, logView), t
	clipBar:SetPoint("TOPLEFT", clipHost, "TOPRIGHT", 2, 20)
	clipBar:SetPoint("BOTTOMLEFT", clipHost, "BOTTOMRIGHT", 2, -16)
	clipBar:SetWheelScrollTarget(clipHost, -2, -5, -2, -1)
	clipBar:SetCoverTarget(clipHost)
	clipBar:SetScript("OnValueChanged", function(_, nv)
		clipAnchor:SetPoint("TOPLEFT", 20, nv)
		clipAnchor:SetPoint("TOPRIGHT", 0, nv)
	end)
	local anchorTo, anchorX, anchorY = clipAnchor, 0, -4
	local function syncScrollRange()
		local ch = clipAnchor:GetTop() - anchorTo:GetBottom()
		local vh = math.max(1, clipHost:GetHeight() - 8)
		clipBar:SetShown(ch > vh)
		clipBar:SetMinMaxValues(0, math.max(0,ch-vh))
		clipBar:SetWindowRange(vh)
		clipBar:SetValueStep(30)
		clipBar:SetStepsPerPage(math.max(1,vh/30/8), math.max(1,vh/30/4))
	end
	clipHost:SetScript("OnShow", syncScrollRange)
	local function li(text, uv)
		local oy, b = anchorY, clipHost:CreateTexture(nil, "OVERLAY")
		b:SetSize(14, 14)
		b:SetPoint("TOPRIGHT", anchorTo, "BOTTOMLEFT", anchorX-4, oy+1)
		b:SetTexture(MARK_TEXTURE)
		b:SetTexCoord(uv and 0.5 or 0, uv and 1 or 0.5, 0, 1)
		if uv then
			b:SetVertexColor(221/255, 102/255, 0)
		end
		local t = clipHost:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		t:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", anchorX, oy)
		t:SetPoint("TOPRIGHT", anchorTo, "BOTTOMRIGHT", 0, oy)
		t:SetJustifyH("LEFT")
		t:SetText((text:gsub("<tt>(.-)</tt>", "|cffa0ff00%1|r"):gsub("<b>(.-)</b>", NORMAL_FONT_COLOR_CODE .. "%1|r")))
		t:SetSpacing(3)
		anchorTo, anchorX, anchorY = t, 0, -8
	end
	local function uv(text)
		return li(text, true)
	end
	local function vh(text)
		local oy, t = anchorTo ~= clipAnchor and anchorY -12 or -2, clipHost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		t:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", anchorX-20, oy)
		t:SetPoint("TOPRIGHT", anchorTo, "BOTTOMRIGHT", 0, oy)
		t:SetJustifyH("LEFT")
		t:SetText(text)
		anchorTo, anchorX, anchorY = t, 20, -4
	end
	securecall(T.WhatsNewData, vh, uv, li)
end

local navDialogs = {"ShowWhatsNew", "ShowReportIssuePrompt", "ShowTranslatePrompt",
                    "ShowOptionsPanel", "ShowBindingsPanel", "ShowCustomRingsPanel"}

function H.HandleNavClick(id)
	return H[navDialogs[id]]()
end
function H.ShowWhatsNew()
	if not frame:IsVisible() then
		clipBar:SetValue(0)
		frame:OpenPanel()
	end
	navView:Hide()
	logView:Show()
end
function H.ShowReportIssuePrompt()
	local text = L"If something in OPie does not behave correctly (or if you'd like it to behave differently), create an issue by visiting:"
	local url = "https://townlong-yak.com/addons/opie/issues"
	local hint = L"Copy the URL shown above and visit it using a web browser."
	TS:ShowCopyOverlay(frame, L"Report an Issue", text, url, hint, OKAY, 0.85)
end
function H.ShowTranslatePrompt()
	local text = L"You can help translate OPie by visiting:"
	local url = "https://townlong-yak.com/addons/opie/localization"
	local hint = L"Copy the URL shown above and visit it using a web browser."
	TS:ShowCopyOverlay(frame, L"Translate OPie", text, url, hint, OKAY, 0.85)
end
function H.ShowOptionsPanel()
	T.ShowOPieOptionsPanel()
end
function H.ShowBindingsPanel()
	T.ShowRingBindingPanel()
end
function H.ShowCustomRingsPanel()
	T.ShowCustomRingsPanel()
end

function frame.refresh()
	navView:Show()
	logView:Hide()
end

T.AddSlashSuffix(H.ShowWhatsNew, "w", "new")