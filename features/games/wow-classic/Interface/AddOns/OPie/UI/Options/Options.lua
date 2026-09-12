local COMPAT, _, T = select(4,GetBuildInfo()), ...
local MODERN, CF_WRATH = COMPAT >= 10e4, COMPAT < 10e4 and COMPAT >= 3e4
local L, EV, TS, XU, PC, config, frame = T.L, T.Evie, T.TenSettings, T.exUI, T.OPieCore, T.config, nil
local GameTooltip = T.NotGameTooltip or GameTooltip

local REQ_POINTER, DISABLED_TEXT = {1, 1}, "|cffa0a0a0" .. L"Disabled"
local OPC_Options = {
	{ "section", caption=L"Interaction" },
		{"radio", "InteractionMode", {L"Quick", L"Relaxed", L"Mouse-less"}},
		{"twof", tag="OnPrimaryPress", caption=L"On ring binding press:", menuOption="RingAtMouse"},
		{"twof", tag="OnPrimaryRelease", caption=L"On ring binding release:", menuOption="QuickActionOnRelease", depOn="InteractionMode", depValueSet={nil, 2, 3}},
		{"twof", tag="OnLeft", caption=L"On left click:", menuOption="NoClose", depOn="InteractionMode", depValue=2, otherwise=DISABLED_TEXT},
		{"twof", tag="OnRight", caption=L"On right click:"},
		{"twof", "QuickAction", caption=L"Quick action repeat trigger:", depOn="InteractionMode", depValueSet=REQ_POINTER, otherwise=DISABLED_TEXT},
		{"twof", "PadSupportMode", caption=L"Controller directional input:", reqFeature="GamePad", depOn="InteractionMode", depValueSet=REQ_POINTER, otherwise=DISABLED_TEXT, globalOnly=true, menu={"freelook", "freelook1", "cursor", "none", freelook=L"Camera analog stick", freelook1=L"Movement analog stick", cursor=L"Virtual mouse cursor", none=L"None"}},
		{"twof", "SliceBinding", caption=L"Per-slice bindings:", depOn="InteractionMode"},
		{"bool", "ClickPriority", caption=L"Prevent other UI interactions", captionTop=L"While a ring is open:", depOn="InteractionMode", depValueSet=REQ_POINTER, otherwise=false},
		{"navi", tag="InRingBindingNav", caption=L"Customize in-ring bindings"},
	{ "section", caption=L"Behavior" },
		{"bool", "UseDefaultBindings", caption=L"Use default ring bindings"},
		{"bool", "DeclutterOnOpen", caption=L"Hide toasts on ring open"},
		{"bool", "DuckRingBinds", caption=L"Duck ring bindings with main UI"},
		{"bool", "HideStanceBar", caption=L"Hide stance bar", globalOnly=true},
		{"bool", "PerCharRotationStore", caption=L"Per-character ring rotations", globalOnly=true},
		{"range", "RingScale", 0.1, 2, caption=L"Ring scale", valueFormat="%0.1f"},
	{ "section", tag="_Appearance", caption=L"Appearance" },
		{"bool", "GhostMIRings", caption=L"Nested rings"},
		{"bool", "ShowKeys", caption=L"Per-slice bindings", depOn="SliceBinding", depValue=true, otherwise=false},
		{"bool", "ShowCooldowns", caption=L"Show cooldown numbers", depIndicatorFeature="CooldownNumbers"},
		{"bool", "ShowRecharge", caption=L"Show recharge numbers", depIndicatorFeature="CooldownNumbers"},
		{"twof", "UseGameTooltip", caption=L"Show tooltips:"},
		{"bool", "ShowShortLabels", caption=L"Show slice labels", depIndicatorFeature="ShortLabels"},
	{ "section", caption=L"Animation"},
		{"bool", "XTAnimation", caption=L"Animate transitions"},
		{"bool", "MISpinOnHide", caption=L"Outward spiral on hide", depOn="XTAnimation", depValue=true, otherwise=false},
		{"bool", "XTPointerSnap", caption=L"Instant pointer rotation"},
		{"bool", "MIScale", caption=L"Enlarge selected slice"},
}

frame = TS:CreateOptionsPanel(L"Options", "OPie")
	frame.version:SetFormattedText("%s", PC:GetVersion() or "")
	frame.desc:SetText(L"Customize OPie's appearance and behavior. Right clicking a checkbox restores it to its default state."
		.. (MODERN and "\n" .. L"Profiles activate automatically when you switch character specializations." or ""))
local OPC_Profile = XU:Create("DropDown", nil, frame)
	OPC_Profile:SetPoint("TOPLEFT", frame, 0, -80)
	OPC_Profile:SetWidth(250)
	T.OPC_Profile = OPC_Profile
local OPC_OptionDomain = XU:Create("DropDown", nil, frame)
	OPC_OptionDomain:SetPoint("LEFT", OPC_Profile, "RIGHT", 44, 0)
	OPC_OptionDomain:SetWidth(300)

local OPC_AlterOption, OPC_AlterOptionW, OPC_AlterOptionQ, OPC_BlockInput
local OPC_UpdateControlReqs, OPC_UpdateViewport, OPC_IsViewDirty, OR_CurrentOptionsDomain

local widgetControl, optionControl = {}, {} do -- Widget construction
	local controlViewport = CreateFrame("Frame", nil, frame)
	controlViewport:SetPoint("TOPLEFT", 0, -115)
	controlViewport:SetPoint("BOTTOMRIGHT", -30, 8)
	controlViewport:SetClipsChildren(true)
	local optionsScrollBar = XU:Create("ScrollBar", nil, frame)
	optionsScrollBar:SetPoint("TOPLEFT", controlViewport, "TOPRIGHT", 2, 8)
	optionsScrollBar:SetPoint("BOTTOMLEFT", controlViewport, "BOTTOMRIGHT", 2, -8)
	optionsScrollBar:SetWheelScrollTarget(controlViewport, 0, -2, -8, -8)
	optionsScrollBar:SetCoverTarget(controlViewport)
	optionsScrollBar:SetValueStep(30)
	local controlContainer = CreateFrame("Frame", nil, controlViewport)
	optionsScrollBar:SetScript("OnValueChanged", function(_, nv)
		controlContainer:SetPoint("TOPLEFT", 0, nv)
	end)
	local sharedDrop = XU:Create("DropDown")
	sharedDrop.xOffset, sharedDrop.yOffset = -6, 6
	sharedDrop:Hide()

	local function onCheckboxClick(self, btn)
		local v = nil
		if btn ~= "RightButton" then
			v = not not self:GetChecked()
		end
		return OPC_AlterOptionW(self, v)
	end
	local function onValueChanged(self, nv)
		return OPC_AlterOptionW(self, nv)
	end
	local function onEnabledChange(self)
		local a = self:IsEnabled() and 1 or 0.6
		widgetControl[self].text:SetVertexColor(a,a,a)
	end
	local function onDropDownSelect(_, nv, drop)
		return OPC_AlterOptionW(drop, nv)
	end
	local function twofMenuInitializer(self)
		local c = widgetControl[self.owner]
		local menu, info, cv = c.menu, {func=onDropDownSelect, arg2=self.owner, minWidth=240}, c.cv
		for i=1, #menu do
			local ak = menu[i]
			info.text, info.arg1, info.checked = menu[ak], ak, ak == cv
			UIDropDownMenu_AddButton(info)
		end
	end
	local function onTwofClick(self, _button)
		local c = widgetControl[self]
		local menuInit = c.menuInitializer or c.menu and twofMenuInitializer
		if menuInit then
			config.ui.HideTooltip(self)
			sharedDrop:ClearAllPoints()
			sharedDrop:SetAllPoints(self)
			sharedDrop.initialize, sharedDrop.owner = menuInit, self
			sharedDrop:Click()
		end
	end
	local function onTwofRefresh(c, v)
		local text = c.menu and c.menu[v]
		if text then
			c.cv = v
			if not c.widget:IsEnabled() then
				text = not c.outOfScope and c.otherwise or ("|cffa0a0a0" .. text)
			end
			c.text:SetText(text)
		end
	end
	local function onTwofEnter(self)
		local c = widgetControl[self]
		local isOutOfScope = c.outOfScope and not self:IsEnabled()
		if (c.label:IsTruncated() or isOutOfScope) and (UIDROPDOWNMENU_OPEN_MENU ~= sharedDrop or sharedDrop.owner ~= self or not DropDownList1:IsVisible()) then
			GameTooltip:SetOwner(self, "ANCHOR_NONE")
			GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, -1)
			GameTooltip:SetText((c.label:GetText():gsub("%s*:%s*$", "")))
			if isOutOfScope then
				local c = HIGHLIGHT_FONT_COLOR
				GameTooltip:AddLine(L"Not configurable per-ring.", c.r, c.g, c.b, 1)
			end
			GameTooltip:Show()
		end
	end
	local function onTwofTextSet(fs)
		local p = fs:GetParent()
		local ws = math.max(fs:GetStringWidth()+5, widgetControl[p].label:GetStringWidth()-20, 50)
		p:SetHitRectInsets(2, -ws, 2, 2)
	end
	local function handlesLeftClicks(self, button, _ev)
		return self:IsEnabled() and button == "LeftButton" and UIDROPDOWNMENU_OPEN_MENU == sharedDrop and sharedDrop.owner == self
	end
	local function onNaviEnter(self)
		if self:GetFontString():IsTruncated() then
			GameTooltip:SetOwner(self, "ANCHOR_NONE")
			GameTooltip:SetPoint("BOTTOM", self, "TOP", 0, 1)
			GameTooltip:SetText(self:GetText())
			GameTooltip:Show()
		end
	end
	local function onNaviClick(self)
		PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
		return widgetControl[self]:OnClick(self)
	end

	local boolSetEnabledHook, twofTextSetTextHook
	local build = {}
	function build.bool(v, ofsY, halfpoint, rowHeight, rframe)
		local b, exY = TS:CreateOptionsCheckButton(nil, controlContainer), 0
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnEnter", config.ui.ShowControlTooltip)
		b:SetScript("OnLeave", config.ui.HideTooltip)
		b:SetMotionScriptsWhileDisabled(true)
		b.tooltipOwnerPoint = "ANCHOR_RIGHT"
		if v.captionTop then
			local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			fs:SetText(v.captionTop)
			fs:SetPoint("BOTTOMLEFT", b, "TOPLEFT", 3.5, -0.75)
			exY, v.textTop = 16, fs
		end
		b.Text:SetPoint("LEFT", b, "RIGHT", 2, 0)
		v.text = b.Text
		b:SetPoint("TOPLEFT", rframe, "TOPLEFT", halfpoint and 315 or 15, ofsY+2-exY)
		b:SetScript("OnClick", onCheckboxClick)
		if boolSetEnabledHook == nil then
			hooksecurefunc(b, "SetEnabled", onEnabledChange)
			boolSetEnabledHook = b.SetEnabled
		end
		b.SetEnabled = boolSetEnabledHook
		return b, ofsY - (halfpoint and math.max(rowHeight, 20+exY) or 0), not halfpoint, halfpoint and 0 or (20 + exY)
	end
	function build.range(v, ofsY, halfpoint, rowHeight, rframe)
		if halfpoint then
			ofsY = ofsY - rowHeight
		end
		local t, s, leftMargin, centerLine = nil, XU:Create("OPie:OptionsSlider", nil, controlContainer)
		s:SetWidth(242)
		s:SetPoint("TOPLEFT", rframe, "TOPLEFT", 319-leftMargin, ofsY-3)
		t = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		t:SetPoint("LEFT", rframe, "TOPLEFT", 42, ofsY-3-centerLine)
		t:SetJustifyH("LEFT")
		t:Show()
		v.text = t
		s:SetValueStep(v[5] or 0.1)
		s:SetMinMaxValues(v[3] < v[4] and v[3] or -v[3], v[4] > v[3] and v[4] or -v[4])
		s:SetObeyStepOnDrag(true)
		s:SetScript("OnValueChanged", onValueChanged)
		s:SetRangeLabelText((v.valueFormat or "%s"):format(v[3]), (v.valueFormat or "%s"):format(v[4]))
		s:SetTipValueFormat(v.valueFormat)
		return s, ofsY - 20, false, 0
	end
	function build.radio(v, ofsY, halfpoint, rowHeight, rframe)
		local radio, opts = XU:Create("OPie:RadioSet", nil, controlContainer), v[3]
		radio:SetPoint("TOPLEFT", rframe, "TOPLEFT", 18, halfpoint and ofsY - rowHeight or ofsY)
		for i=1,#opts do
			radio:SetOptionText(i, opts[i])
		end
		radio:Reflow(400)
		radio:SetScript("OnValueChanged", onValueChanged)
		return radio, ofsY-34, false, 0
	end
	function build.section(v, ofsY, halfpoint, rowHeight, rframe)
		local fs = controlContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		ofsY = (halfpoint or ofsY ~= 0 or rframe ~= controlContainer) and ofsY-10-rowHeight or ofsY
		fs:SetPoint("TOPLEFT", rframe, "TOPLEFT", 16, ofsY)
		fs:SetText(v.caption)
		return fs, ofsY-20, false, 0
	end
	function build.navi(v, ofsY, halfpoint, rowHeight, rframe)
		local b = CreateFrame("Button", nil, controlContainer, "UIPanelButtonTemplate")
		b:SetSize(250, 24)
		b:SetPoint("TOPLEFT", rframe, halfpoint and 316 or 16, ofsY-3)
		b:SetText(v.caption)
		b:SetScript("OnEnter", onNaviEnter)
		b:SetScript("OnLeave", config.ui.HideTooltip)
		b:SetScript("OnClick", onNaviClick)
		local fs = b:GetFontString()
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", 6, -0.5)
		fs:SetPoint("RIGHT", -6, -0.5)
		fs:SetJustifyH("CENTER")
		fs:SetMaxLines(1)
		return b, halfpoint and ofsY - math.max(rowHeight, 30) or ofsY, not halfpoint, halfpoint and 0 or 30
	end
	function build.twof(v, ofsY, halfpoint, rowHeight, rframe)
		local tb = CreateFrame("Button", nil, controlContainer)
		tb:SetSize(24,24)
		tb:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up]])
		tb:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Down]])
		tb:SetDisabledTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Disabled]])
		tb:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]])
		tb:GetHighlightTexture():SetBlendMode("ADD")
		tb:SetPoint("TOPLEFT", rframe, "TOPLEFT", halfpoint and 316 or 16, ofsY-13.5)
		tb:SetScript("OnClick", onTwofClick)
		tb:SetScript("OnEnter", onTwofEnter)
		tb:SetScript("OnLeave", config.ui.HideTooltip)
		tb:SetMotionScriptsWhileDisabled(true)
		local label = tb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("BOTTOMLEFT", tb, "TOPLEFT", 2.5, -1.5)
		label:SetWidth(285)
		label:SetText(v.caption)
		label:SetJustifyH("LEFT")
		label:SetMaxLines(1)
		local text = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 23, -5)
		text:SetWidth(240)
		text:SetJustifyH("LEFT")
		text:SetMaxLines(1)
		if not twofTextSetTextHook then
			hooksecurefunc(text, "SetText", onTwofTextSet)
			twofTextSetTextHook = text.SetText
		end
		v.label, v.text, v.refresh, text.SetText = label, text, onTwofRefresh, twofTextSetTextHook
		tb.HandlesGlobalMouseEvent = handlesLeftClicks
		return tb, halfpoint and ofsY - math.max(rowHeight, 38) or ofsY, not halfpoint, halfpoint and 0 or 38
	end

	controlContainer:SetPoint("TOPLEFT")
	controlContainer:SetSize(600, 10)
	local cY, halfpoint, rframe, rowHeight, wj = 0, false, controlContainer
	for _, vj in ipairs(OPC_Options) do
		wj, cY, halfpoint, rowHeight = build[vj[1]](vj, cY, halfpoint, rowHeight, rframe)
		widgetControl[wj], optionControl[vj[2] or 0], optionControl[vj.tag or 0] = vj, vj, vj
		vj.widget = wj
	end
	optionControl[0] = nil
	local beam = CreateFrame("Frame", nil, controlContainer)
	beam:SetPoint("TOPLEFT")
	beam:SetPoint("BOTTOMRIGHT", wj, 0, -1)
	function OPC_UpdateViewport()
		local ch, vh = beam:GetHeight(), controlViewport:GetHeight()
		if not (vh and ch and vh > 0 and ch > 0) then return end
		optionsScrollBar:SetShown(vh < ch)
		optionsScrollBar:SetMinMaxValues(0, ch - vh)
		optionsScrollBar:SetWindowRange(vh)
		optionsScrollBar:SetStepsPerPage(math.max(vh/4/30, 50))
		OPC_IsViewDirty = false
	end
	beam:SetScript("OnSizeChanged", OPC_UpdateViewport)
	beam:SetScript("OnShow", OPC_UpdateViewport)
end
do -- customized widgets
	local offsetPanel, offsetControl = CreateFrame("Frame", nil, frame, "UIDropDownCustomMenuEntryTemplate"), {"panel", "IndicationOffset"} do
		offsetPanel:Hide()
		offsetPanel:SetSize(0, 78)
		local function onOffsetValueChanged(self, nv)
			return OPC_AlterOption(offsetControl, self:GetID() == 1 and "IndicationOffsetX" or "IndicationOffsetY", nv)
		end
		for i=1, 2 do
			local t, s, leftMargin, _centerLine = nil, XU:Create("OPie:OptionsSlider", nil, offsetPanel)
			s:SetID(i)
			s:SetPoint("TOPLEFT", -leftMargin, 27-42*i)
			s:SetPoint("TOPRIGHT", -5, 27-42*i)
			t = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			t:SetJustifyH("LEFT")
			t:SetPoint("BOTTOMLEFT", s, "TOPLEFT", leftMargin, 3)
			t:SetText(i == 1 and L"Move rings right" or L"Move rings down")
			t:Show()
			s:SetValueStep(50)
			s:SetMinMaxValues(-500, 500)
			s:SetObeyStepOnDrag(true)
			s:SetScript("OnValueChanged", onOffsetValueChanged)
			s:SetRangeLabelText("", "")
			offsetControl[2+i], offsetControl[4+i] = s, t
		end
		function offsetPanel:OnSetOwningButton()
			getmetatable(self).__index.ClearAllPoints(self)
			self:SetPoint("TOPRIGHT", self.owningButton)
		end
		function offsetPanel:GetPreferredEntryWidth()
			return 200
		end
		function offsetPanel:ClearAllPoints()
			-- called by UIDropDownMenu_CheckAddCustomFrame after OnSetOwningButton runs; keep our TOPRIGHT to size panel with button/dropdown
		end
		function offsetControl:refresh()
			local ox = PC:GetOption("IndicationOffsetX", OR_CurrentOptionsDomain)
			local oy = PC:GetOption("IndicationOffsetY", OR_CurrentOptionsDomain)
			OPC_BlockInput = OPC_BlockInput or "IndicationOffset"
			self[3]:SetValue(ox)
			self[4]:SetValue(oy)
			OPC_BlockInput = OPC_BlockInput ~= "IndicationOffset" and OPC_BlockInput or nil
			self[5]:SetFormattedText("%s |cffffd500(%+d)|r", L"Move rings right", ox)
			self[6]:SetFormattedText("%s |cffffd500(%+d)|r", L"Move rings down", oy)
		end
		if UIDropDownMenu_StopCounting then
			local waitForLeave
			local function waitForEnter(self)
				if self:IsMouseOver() then
					UIDropDownMenu_StopCounting(self:GetOwningDropdown())
					self:SetScript("OnUpdate", waitForLeave)
				end
			end
			function waitForLeave(self)
				if not self:IsMouseOver() then
					if DropDownList1:IsMouseOver() then
						-- it's Someone Else's Problem now
						self:SetScript("OnUpdate", nil)
					else
						UIDropDownMenu_StartCounting(self:GetOwningDropdown())
						self:SetScript("OnUpdate", waitForEnter)
					end
				end
			end
			offsetPanel:SetScript("OnLeave", function(self) self:SetScript("OnUpdate", waitForLeave) end)
			offsetPanel:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
			offsetPanel:SetScript("OnEnter", function(self)
				UIDropDownMenu_StopCounting(self:GetOwningDropdown())
				self:SetScript("OnUpdate", nil)
			end)
		end
		offsetControl.widget, optionControl[offsetControl[2]], widgetControl[offsetPanel] = offsetPanel, offsetControl, offsetControl
	end
	local function onMenuOptionToggle(_, option, owner, checked)
		-- checked comes pre-toggled iff keepShownOnClick
		OPC_AlterOption(widgetControl[owner], option, (not checked) == (not DropDownList1:IsShown()))
	end
	local function onMenuOptionSetClick(_, pref, owner)
		local c = widgetControl[owner]
		OPC_AlterOption(c, c.menuOption, pref)
	end
	function optionControl.InteractionMode:refresh(newval)
		local widget = self.widget
		widget:SetValue(newval)
		local doNothingText = "|cffa0a0a0" .. L"Do nothing"
		optionControl.OnRight.widget:Disable()
		optionControl.OnRight.text:SetText(newval ~= 3 and L"Close ring" or doNothingText)
		optionControl.OnPrimaryRelease.otherwise = newval == 1 and L"Use slice and close ring" or doNothingText
		optionControl.ClickPriority.widget:SetShown(newval ~= 3)
		optionControl.SliceBinding.forced = newval == 3
		OPC_IsViewDirty = true
	end
	local function onPrimaryPressReopenClick(_, pref, owner)
		pref = pref == "Refresh" and 0 or pref == "Rehome" and 1 or pref == "Close" and 2 or nil
		if pref then
			OPC_AlterOption(widgetControl[owner], "ReOpenAction", pref)
		end
	end
	function optionControl.OnPrimaryPress.menuInitializer()
		local c = optionControl.OnPrimaryPress
		local info = {func=onMenuOptionSetClick, arg2=c.widget, minWidth=240}
		local atMouse = PC:GetOption("RingAtMouse", OR_CurrentOptionsDomain)
		local reOpen = PC:GetOption("ReOpenAction", OR_CurrentOptionsDomain)
		info.text, info.arg1, info.checked = L"Open ring at screen center", false, not atMouse
		UIDropDownMenu_AddButton(info)
		info.text, info.arg1, info.checked = L"Open ring at mouse", true, atMouse
		UIDropDownMenu_AddButton(info)

		UIDropDownMenu_AddSeparator()
		info.text, info.isTitle, info.func, info.checked = L"If the ring is already open:", true, onPrimaryPressReopenClick
		UIDropDownMenu_AddButton(info)
		info.text, info.arg1, info.checked, info.isTitle, info.disabled = L"Reopen ring", "Refresh", reOpen == 0, nil
		UIDropDownMenu_AddButton(info)
		info.text, info.arg1, info.checked = L"Close ring", "Close", reOpen == 2
		UIDropDownMenu_AddButton(info)

		UIDropDownMenu_AddSeparator()
		info.customFrame, info.func, info.text, info.arg1 = offsetPanel
		UIDropDownMenu_AddButton(info)
		offsetControl:refresh()
	end
	function optionControl.OnPrimaryPress:refresh()
		local atMouse = PC:GetOption("RingAtMouse", OR_CurrentOptionsDomain)
		self.text:SetText(atMouse and L"Open ring at mouse" or L"Open ring at screen center")
	end
	local function currentDomainHasQA()
		return PC:GetOption("CenterAction", OR_CurrentOptionsDomain) or PC:GetOption("MotionAction", OR_CurrentOptionsDomain)
	end
	local function onPrimaryReleaseOption(_, pref)
		local c = optionControl.OnPrimaryRelease
		if pref == "close" or pref == "no-close" then
			OPC_AlterOption(c, "CloseOnRelease", pref == "close")
		elseif pref == "qa-close" or pref == "no-qa-close" then
			OPC_AlterOption(c, "QuickActionOnRelease", pref == "qa-close")
		end
	end
	function optionControl.OnPrimaryRelease:refresh()
		local im = PC:GetOption("InteractionMode", OR_CurrentOptionsDomain)
		self.text:SetText(not self.widget:IsEnabled() and self.otherwise
		                  or im == 3 and PC:GetOption("CloseOnRelease", OR_CurrentOptionsDomain) and L"Close ring"
		                  or im == 2 and PC:GetOption("QuickActionOnRelease", OR_CurrentOptionsDomain) and currentDomainHasQA() and L"Close ring after quick action"
		                  or L"Do nothing")
	end
	function optionControl.OnPrimaryRelease.menuInitializer()
		local info = {func=onPrimaryReleaseOption, minWidth=240, tooltipWhileDisabled=true, tooltipOnButton=true}
		local qaOnRelease = PC:GetOption("QuickActionOnRelease", OR_CurrentOptionsDomain)
		local closeOnRelease = PC:GetOption("CloseOnRelease", OR_CurrentOptionsDomain)
		local im, hasQA = PC:GetOption("InteractionMode", OR_CurrentOptionsDomain), currentDomainHasQA()
		if im == 3 then
			info.text, info.arg1, info.checked = L"Close ring", "close", closeOnRelease
			UIDropDownMenu_AddButton(info)
		else
			info.text, info.arg1, info.checked = L"Close ring after quick action", "qa-close", hasQA and qaOnRelease
			if not hasQA then
				local opt = "|cffffffff" .. (L"Quick action repeat trigger:"):gsub("%s*:%s*$", "") .. "|r"
				info.disabled, info.tooltipTitle, info.tooltipText = true, info.text, (L"Select a %s interaction to enable this option."):format(opt)
			end
			UIDropDownMenu_AddButton(info)
			info.disabled, info.tooltipTitle, info.tooltipText = nil
		end
		info.text, info.arg1, info.checked = L"Do nothing", im == 3 and "no-close" or "no-qa-close", not (im == 3 and closeOnRelease or im ~= 3 and qaOnRelease)
		UIDropDownMenu_AddButton(info)
	end
	function optionControl.QuickAction.menuInitializer()
		local c = optionControl.QuickAction
		local info = {func=onMenuOptionToggle, arg2=c.widget, minWidth=240, isNotRadio=true, keepShownOnClick=true}
		info.text, info.arg1, info.checked = L"Quick action at ring center", "CenterAction", PC:GetOption("CenterAction", OR_CurrentOptionsDomain)
		UIDropDownMenu_AddButton(info)
		info.text, info.arg1, info.checked = L"Quick action if mouse remains still", "MotionAction", PC:GetOption("MotionAction", OR_CurrentOptionsDomain)
		UIDropDownMenu_AddButton(info)
	end
	function optionControl.QuickAction:refresh()
		local enabled = self.widget:IsEnabled()
		local center = enabled and PC:GetOption("CenterAction", OR_CurrentOptionsDomain)
		local motion = enabled and PC:GetOption("MotionAction", OR_CurrentOptionsDomain)
		self.text:SetText(
			center and motion and L"Unmoved cursor, or at ring center" or
			center and L"At ring center" or
			motion and L"Unmoved cursor" or
			((enabled and "" or "|cffa0a0a0") .. L"Disabled")
		)
		optionControl.OnPrimaryRelease:refresh()
	end
	function optionControl.OnLeft.menuInitializer()
		local c = optionControl.OnLeft
		local info = {func=onMenuOptionSetClick, arg2=c.widget, minWidth=240}
		local doClose = not PC:GetOption("NoClose", OR_CurrentOptionsDomain)
		info.text, info.arg1, info.checked = L"Use slice and close ring", false, doClose
		UIDropDownMenu_AddButton(info)
		info.text, info.arg1, info.checked = L"Use slice", true, not doClose
		UIDropDownMenu_AddButton(info)
	end
	function optionControl.OnLeft:refresh()
		local enabled = self.widget:IsEnabled()
		local noClose = PC:GetOption("NoClose", OR_CurrentOptionsDomain)
		self.text:SetText(
			enabled and noClose and L"Use slice" or
			enabled and L"Use slice and close ring" or
			("|cffa0a0a0" .. L"Do nothing")
		)
	end
	local function onSliceBindingOptionClick(_, pref, owner, checked)
		if pref == "ToggleNoClose" then
			pref = not checked and "UseNoClose" -- toggle original checked state
		else
			OPC_AlterOption(widgetControl[owner], "SliceBinding", pref ~= "None")
		end
		OPC_AlterOption(widgetControl[owner], "NoCloseOnSlice", pref == "UseNoClose")
	end
	local function onRunOnDownClick(_, pref, owner)
		OPC_AlterOption(widgetControl[owner], "RunBindingsOnDown", pref == "OnDown")
	end
	function optionControl.SliceBinding.menuInitializer()
		local c = optionControl.SliceBinding
		local info = {func=onSliceBindingOptionClick, arg2=c.widget, minWidth=240}
		local noClose = PC:GetOption("NoCloseOnSlice", OR_CurrentOptionsDomain)
		local runOnDown = PC:GetOption("RunBindingsOnDown", OR_CurrentOptionsDomain)
		if c.forced then
			info.text, info.arg1, info.checked, info.isNotRadio = L"Leave open after use", "ToggleNoClose", noClose, true
			UIDropDownMenu_AddButton(info)
		else
			local doBind = PC:GetOption("SliceBinding", OR_CurrentOptionsDomain)
			info.text, info.arg1, info.checked = L"Use slice and close ring", "UseClose", doBind and not noClose
			UIDropDownMenu_AddButton(info)
			info.text, info.arg1, info.checked = L"Use slice", "UseNoClose", doBind and noClose
			UIDropDownMenu_AddButton(info)
			info.text, info.arg1, info.checked = L"Do nothing", "None", not doBind
			UIDropDownMenu_AddButton(info)
		end
		UIDropDownMenu_AddSeparator()
		info.func, info.isNotRadio = onRunOnDownClick, nil
		info.text, info.arg1, info.checked = L"Trigger on binding press", "OnDown", runOnDown
		UIDropDownMenu_AddButton(info)
		info.text, info.arg1, info.checked = L"Trigger on binding release", "OnUp", not runOnDown
		UIDropDownMenu_AddButton(info)
	end
	function optionControl.SliceBinding:refresh()
		local doBind = self.forced or PC:GetOption("SliceBinding", OR_CurrentOptionsDomain)
		local noClose = PC:GetOption("NoCloseOnSlice", OR_CurrentOptionsDomain)
		self.text:SetText(
			doBind and noClose and L"Use slice" or
			doBind and L"Use slice and close ring" or
			L"Do nothing"
		)
	end
	function optionControl.InRingBindingNav:OnClick(_w)
		T.ShowSliceBindingPanel(OR_CurrentOptionsDomain)
	end
	local function onTooltipAnchorSelect(_, pref, owner)
		OPC_AlterOptionQ("UseGameTooltip", pref ~= "none")
		OPC_AlterOption(widgetControl[owner], "TooltipAnchor", pref == "side" and pref or nil)
	end
	function optionControl.UseGameTooltip.menuInitializer()
		local c = optionControl.UseGameTooltip
		local info = {func=onTooltipAnchorSelect, arg2=c.widget, minWidth=240}
		local useAny = PC:GetOption("UseGameTooltip", OR_CurrentOptionsDomain)
		local anchor = useAny and PC:GetOption("TooltipAnchor", OR_CurrentOptionsDomain) or "none"
		info.text, info.arg1, info.checked = L"Ring-side", "side", anchor == "side"
		UIDropDownMenu_AddButton(info)
		info.text, info.arg1, info.checked = L"At HUD Tooltip position", "hud", useAny and anchor ~= "side"
		UIDropDownMenu_AddButton(info)
		info.text, info.arg1, info.checked = L"Do not show", "none", anchor == "none"
		UIDropDownMenu_AddButton(info)
	end
	function optionControl.UseGameTooltip:refresh()
		local useAny = PC:GetOption("UseGameTooltip", OR_CurrentOptionsDomain)
		local anchor = useAny and PC:GetOption("TooltipAnchor", OR_CurrentOptionsDomain)
		self.text:SetText(
			useAny == false and L"Do not show" or
			anchor == "side" and L"Ring-side" or
			L"At HUD Tooltip position"
		)
	end
	function EV:CVAR_UPDATE(cvar)
		if cvar == "GamePadEnable" and frame:IsVisible() then
			OPC_UpdateControlReqs(optionControl.PadSupportMode)
		end
	end
end

local OPC_AppearanceFactory = XU:Create("DropDown", nil, frame)
OPC_AppearanceFactory:SetPoint("LEFT", optionControl._Appearance.widget, "LEFT", 284, -1)
OPC_AppearanceFactory:SetWidth(250)

T.OPC_RingScopePrefixes = {
	[30] = "|cff25bdff",
	[20] = "|c" .. RAID_CLASS_COLORS[select(2,UnitClass("player"))].colorStr,
	[10] = "|cffabffd5",
}

function OPC_UpdateControlReqs(v)
	local enabled, globalOnly, disabledHint = true, v.globalOnly, nil
	local outOfScope, scopeEnabled = globalOnly and OR_CurrentOptionsDomain
	local optionScope = not globalOnly and OR_CurrentOptionsDomain or nil
	v.outOfScope = outOfScope and true or nil
	if v.depOn then
		local dv = PC:GetOption(v.depOn, OR_CurrentOptionsDomain)
		enabled = v.depValueSet and v.depValueSet[dv] or (v.depValueSet or v.depValue) == nil or dv == v.depValue
	elseif v.depIndicatorFeature then
		enabled = T.OPieUI:DoesIndicatorConstructorSupport(PC:GetOption("IndicatorFactory", OR_CurrentOptionsDomain), v.depIndicatorFeature)
		disabledHint = L"Not supported by selected appearance."
	end
	if enabled and v.reqFeature == "GamePad" and not C_GamePad.IsEnabled() then
		enabled, disabledHint = false, nil
	end
	if enabled and outOfScope then
		scopeEnabled, enabled, disabledHint = enabled, false, HIGHLIGHT_FONT_COLOR_CODE .. L"Not configurable per-ring."
	end
	v.widget:SetEnabled(enabled)
	if v.refresh then
		v:refresh(v[2] and PC:GetOption(v[2], optionScope))
	elseif v[1] == "bool" then
		local checked, disabled = v.otherwise, not enabled or nil
		if enabled or scopeEnabled then
			checked = PC:GetOption(v[2], optionScope)
		end
		v.widget:SetChecked(checked or nil)
		v.widget.tooltipText, v.widget.tooltipTitle = disabled and disabledHint, disabled and disabledHint and v.caption or nil
	end
end
function OPC_AlterOptionQ(option, newval)
	config.undo:saveActiveProfile()
	PC:SetOption(option, newval, OR_CurrentOptionsDomain)
end
function OPC_AlterOptionW(widget, newval, ...)
	if OPC_BlockInput then return end
	local control = widgetControl[widget]
	local option = control[2]
	if control.setValueTransform then
		option, newval = control:setValueTransform(newval, ...)
	elseif control[1] == "range" and control[3] > control[4] and type(newval) == "number" then
		newval = -newval
	end
	if option then
		return OPC_AlterOption(control, option, newval)
	end
end
function OPC_AlterOption(control, option, newval)
	if OPC_BlockInput then return end
	config.undo:saveActiveProfile()
	PC:SetOption(option, newval, OR_CurrentOptionsDomain)
	local ctype, setval = control[1], PC:GetOption(option, OR_CurrentOptionsDomain)
	if control.refresh then
		control:refresh(setval)
	elseif ctype == "range" then
		local text, vf = control.caption, control.valueFormat
		if vf then
			text = text .. " |cffffd500(" .. vf:format(setval) .. ")|r"
		end
		control.text:SetText(text)
		OPC_BlockInput = true
		control.widget:SetValue(setval * (control[3] > control[4] and -1 or 1))
		OPC_BlockInput = false
	elseif ctype == "radio" then
		control.widget:SetValue(setval)
	elseif setval ~= newval then
		control.widget:SetChecked(setval and 1 or nil)
	end
	for _,v in ipairs(OPC_Options) do
		if v.depOn == option then
			OPC_UpdateControlReqs(v)
		end
	end
	if OPC_IsViewDirty then
		OPC_UpdateViewport()
	end
end
local function OPC_OptionDomain_click(_, ringName)
	OR_CurrentOptionsDomain, frame.resetOnHide = ringName or nil, nil
	frame.refresh()
end
local function OPC_OptionDomain_Format(key, list)
	return list[key], OR_CurrentOptionsDomain == (key or nil)
end
function OPC_OptionDomain:initialize()
	local list = {false, [false]=L"Defaults for all rings"}
	local ct = T.OPC_RingScopePrefixes
	for key, name, scope in PC:IterateRings(IsAltKeyDown()) do
		local color = ct and ct[scope] or "|cffacd7e6"
		list[#list+1], list[key] = key, (L"Ring: %s"):format(color .. (name or key) .. "|r")
	end
	XU:Create("ScrollableDropDownList", 1, list, OPC_OptionDomain_Format, OPC_OptionDomain_click)
end
function OPC_OptionDomain:text()
	local label = L"Defaults for all rings"
	if OR_CurrentOptionsDomain then
		local name, key = PC:GetRingInfo(OR_CurrentOptionsDomain)
		label = (L"Ring: %s"):format("|cffaaffff" .. (name or key) .."|r")
	end
	self:SetText(label)
end
local function OPC_Profile_FormatName(ident)
	return ident == "default" and L"default" or ident or "|cffff0000-???-|r"
end
do -- OPC_Profile:initialize
	local curProfile
	local function dup(n, v)
		if n > 0 then
			return v, dup(n-1, v)
		end
	end
	local function prependCount(...)
		return select("#", ...), ...
	end
	local function CallDeleteProfile(msg, ...)
		if msg == "archive-unwind" then
			config.undo:saveSpecProfiles()
		end
		return PC:DeleteProfile(...)
	end
	local function OPC_Profile_format(ident, list)
		return list[ident], curProfile == ident, ident
	end
	local function OPC_Profile_switch(_, ident)
		config.undo:saveSpecProfiles()
		PC:SwitchProfile(ident)
	end
	local function OPC_Profile_new_callback(self, text, apply, _frame)
		local name = text:match("^%s*(.-)%s*$")
		if name == "" or PC:ProfileExists(name) then
			if apply then self:SetText("") end
			return false
		elseif apply then
			config.undo:saveSpecProfiles()
			PC:SwitchProfile(name, true)
			if not config.undo:search("OPieProfile#" .. name) then
				config.undo:push("OPieProfile#" .. name, CallDeleteProfile, name)
			end
		end
		return true
	end
	local function OPC_Profile_new(_, _, frame)
		TS:ShowPromptOverlay(frame, L"Create a New Profile", L"New profile name:", L"Profiles save options and ring bindings.", L"Create Profile", OPC_Profile_new_callback)
	end
	local function OPC_Profile_delete()
		config.undo:saveActiveProfile()
		PC:DeleteProfile(PC:GetCurrentProfile())
	end
	local function OPC_Profile_assignAllSpecs(_, curProfile)
		config.undo:saveSpecProfiles()
		PC:SetSpecProfiles(dup(select("#", PC:GetSpecProfiles()), curProfile))
	end
	function OPC_Profile:initialize()
		local hasPartialSpecProfiles, ns, p1, p2, p3, p4, plist = false, prependCount(PC:GetSpecProfiles())
		curProfile, plist, ns = PC:GetCurrentProfile(), PC:GetAllProfiles(), ns > 1 and ns or 0
		for k=1, #plist do
			local ident = plist[k]
			local name, suf, ni = OPC_Profile_FormatName(ident), "", 0
			for i=1, ns do
				if ident == select(i, p1, p2, p3, p4) then
					if MODERN then
						local _, _, _, ico = GetSpecializationInfo(i)
						ni, suf = ni + 1, (ni > 0 and suf .. "|T" or " |T") .. (ico or "Interface/Icons/INV_Misc_QuestionMark") .. ":16:16:4:0:64:64:4:60:4:60|t"
					elseif CF_WRATH then
						ni, suf = ni + 1, suf .. " |cffff99ff[" .. i .."]|r"
					end
				end
			end
			if ni > 0 and ni < ns then
				name, hasPartialSpecProfiles = name .. suf, true
			end
			plist[ident] = name
		end
		XU:Create("ScrollableDropDownList", 1, plist, OPC_Profile_format, OPC_Profile_switch, true)
		UIDropDownMenu_AddSeparator()
		local info = {arg2=self:GetParent(), notCheckable=true, justifyH="CENTER"}
		info.text, info.disabled, info.func, info.arg1 = L"Assign to all specializations", not hasPartialSpecProfiles, OPC_Profile_assignAllSpecs, curProfile
		if ns > 1 then
			UIDropDownMenu_AddButton(info)
		end
		info.text, info.minWidth, info.func, info.arg1, info.disabled = L"Create a new profile", self:GetWidth()-40, OPC_Profile_new, nil, nil
		UIDropDownMenu_AddButton(info)
		info.text, info.func = curProfile ~= "default" and L"Delete current profile" or L"Restore default settings", OPC_Profile_delete
		UIDropDownMenu_AddButton(info)
	end
end
function OPC_Profile:text()
	self:SetText(L"Profile" .. ": " .. OPC_Profile_FormatName(PC:GetCurrentProfile()))
end
function OPC_AppearanceFactory:formatText(key, outOfDate, name, disabled)
	name = name or T.OPieUI:GetIndicatorConstructorName(key)
	if not name then
		name = "|cffa0a0a0*[" .. (T.OPieUI:GetIndicatorConstructorName() or "??") .. "]|r"
	end
	if disabled then
		name = "|cff909090" .. name .. "|r"
	elseif outOfDate then
		name = "|cffef2020" .. name .. "|r"
	end
	if key == "mirage" then
		name = "|cff00e800" .. name .. "|r"
	elseif key == "_" then
		name = L"Not customized" .. " (|cffb0b0b0" .. name .. "|r)"
	end
	return name
end
function OPC_AppearanceFactory:text()
	local key, own, text = PC:GetOption("IndicatorFactory", OR_CurrentOptionsDomain)
	if OR_CurrentOptionsDomain and own == nil then
		text = L"Use global setting"
	else
		local name, avail = T.OPieUI:GetIndicatorConstructorName(key)
		key, name = avail and key or nil, avail and name or nil
		text = self:formatText(key, nil, name) .. (avail and "" or "|cff909090*")
	end
	self:SetText(text)
end
local function OPC_AppearanceFactory_set(_, key)
	PC:SetOption("IndicatorFactory", key, OR_CurrentOptionsDomain)
	OPC_AppearanceFactory:text()
	for _,v in ipairs(OPC_Options) do
		if v.depIndicatorFeature then
			OPC_UpdateControlReqs(v)
		end
	end
end
function OPC_AppearanceFactory:initialize()
	local info = {func=OPC_AppearanceFactory_set, minWidth=UIDROPDOWNMENU_OPEN_MENU:GetWidth()-40, tooltipOnButton=true, tooltipWhileDisabled=true}
	local current, own = PC:GetOption("IndicatorFactory", OR_CurrentOptionsDomain)
	for k, name, outOfDate, err in T.OPieUI:EnumerateRegisteredIndicatorConstructors() do
		if k == "_" then
			UIDropDownMenu_AddSeparator()
		end
		name = self:formatText(k, outOfDate, name, err ~= nil)
		if err then
			info.tooltipTitle, info.tooltipText = "|cffff2020" .. L"Update required", L"Install an updated version of this appearance to select it." .. "\n\n|cff909090" .. err
		elseif outOfDate then
			info.tooltipTitle, info.tooltipText = "|cffff2020" .. L"Update required", L"This appearance may not support all OPie features."
		else
			info.tooltipTitle, info.tooltipText = nil
		end
		info.arg1, info.text, info.checked, info.disabled = k, name, k == own or (own == nil and not OR_CurrentOptionsDomain and current == k), err ~= nil
		UIDropDownMenu_AddButton(info)
	end
	if OR_CurrentOptionsDomain then
		info.text, info.arg1, info.checked = L"Use global setting", nil, own == nil
		info.tooltipTitle, info.tooltipText = nil
		UIDropDownMenu_AddButton(info)
	end
end
local function refreshControls()
	if OR_CurrentOptionsDomain and not PC:GetRingInfo(OR_CurrentOptionsDomain) then
		OR_CurrentOptionsDomain = nil
	end
	OPC_AppearanceFactory:SetShown(T.OPieUI:HasMultipleIndicatorConstructors())
	for _, control in ipairs(OPC_Options) do
		local widget, ctype, option = control.widget, control[1], control[2]
		if control.refresh then
			control:refresh(option and PC:GetOption(option, OR_CurrentOptionsDomain) or nil, option)
		elseif ctype == "range" then
			widget:SetValue(PC:GetOption(option, OR_CurrentOptionsDomain) * (control[3] < control[4] and 1 or -1))
			local text = control.caption
			if control.valueFormat then
				local vf = control.valueFormat:format(widget:GetValue())
				text = text .. " |cffffd500(" .. vf .. ")|r"
			end
			control.text:SetText(text)
		elseif ctype == "bool" then
			widget:SetChecked(PC:GetOption(option, OR_CurrentOptionsDomain) or nil)
			control.text:SetText(control.caption)
		end
		if control.depOn or control.depIndicatorFeature or control.reqFeature or control.globalOnly then
			OPC_UpdateControlReqs(control)
		end
	end
	OPC_OptionDomain:text()
	OPC_Profile:text()
	OPC_AppearanceFactory:text()
end
function frame.refresh()
	OPC_BlockInput = true
	securecall(refreshControls)
	OPC_BlockInput = false
	config.checkSVState(frame)
end
local function resetView()
	OR_CurrentOptionsDomain = nil
end
frame.cancel, frame.okay = resetView, resetView
function frame.default()
	config.undo:saveActiveProfile()
	PC:ResetOptions(true)
	frame.refresh()
end
frame:SetScript("OnShow", frame.refresh)
frame:SetScript("OnHide", function()
	if frame.resetOnHide then
		OR_CurrentOptionsDomain, frame.resetOnHide = nil
	end
end)

function EV:OPIE_PROFILE_SWITCHED(_new, _old)
	if frame:IsVisible() then
		frame.refresh()
	end
end

function T.ShowOPieOptionsPanel(ringKey)
	frame:OpenPanel()
	OPC_OptionDomain_click(nil, ringKey)
	if ringKey then
		frame.resetOnHide = true
		OPC_OptionDomain:Pulse()
	end
end
T.AddSlashSuffix(function() T.ShowOPieOptionsPanel() end, "o", "opt", "options")