local _, ns = ...

local Search = ns.Search
local SearchFocus = ns.SearchFocus
local Results = ns.Results
local Rows = ns.ResultRows
local Utils = ns.Utils
local L = ns.L

local sformat = Utils.sformat
local mfloor = Utils.mfloor
local mmax = Utils.mmax

local CreateFrame = CreateFrame
local GameTooltip = GameTooltip

local function RefocusSearchEditBox()
    SearchFocus:RefocusSearchEditBox()
end

function Rows.CreateSettingWidgets(resultRow)






    local settingState = resultRow:CreateTexture(nil, "OVERLAY")
    settingState:SetSize(16, 16)
    settingState:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
    settingState:SetAtlas("checkbox-minimal")
    settingState:Hide()
    resultRow.settingState = settingState

    local settingCheck = resultRow:CreateTexture(nil, "OVERLAY", nil, 1)
    settingCheck:SetSize(16, 16)
    settingCheck:SetPoint("CENTER", settingState, "CENTER", 0, 0)
    settingCheck:SetAtlas("checkmark-minimal")
    settingCheck:Hide()
    resultRow.settingCheck = settingCheck





    local sliderGroup = CreateFrame("Frame", nil, resultRow)
    sliderGroup:SetSize(140, 18)
    sliderGroup:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
    sliderGroup:SetFrameLevel(resultRow:GetFrameLevel() + 5)
    sliderGroup:Hide()
    resultRow.settingSliderGroup = sliderGroup

    local function applySettingValue(variable, newVal)
        if variable then Rows:WriteSettingVariable(variable, newVal) end
    end

    local function clampToRange(value, slider)
        local minV, maxV = slider:GetMinMaxValues()
        if value < minV then return minV end
        if value > maxV then return maxV end
        return value
    end

    local stepBack = CreateFrame("Button", nil, sliderGroup)
    stepBack:SetSize(11, 18)
    stepBack:SetPoint("LEFT", sliderGroup, "LEFT", 0, 0)
    stepBack:EnableMouse(true)
    local stepBackTex = stepBack:CreateTexture(nil, "ARTWORK")
    stepBackTex:SetAllPoints()
    stepBackTex:SetAtlas("Minimal_SliderBar_Button_Left")
    stepBack:SetHighlightAtlas("Minimal_SliderBar_Button_Left", "ADD")
    resultRow.settingStepBack = stepBack

    local stepFwd = CreateFrame("Button", nil, sliderGroup)
    stepFwd:SetSize(11, 18)
    stepFwd:SetPoint("RIGHT", sliderGroup, "RIGHT", 0, 0)
    stepFwd:EnableMouse(true)
    local stepFwdTex = stepFwd:CreateTexture(nil, "ARTWORK")
    stepFwdTex:SetAllPoints()
    stepFwdTex:SetAtlas("Minimal_SliderBar_Button_Right")
    stepFwd:SetHighlightAtlas("Minimal_SliderBar_Button_Right", "ADD")
    resultRow.settingStepFwd = stepFwd

    local settingSlider = CreateFrame("Slider", nil, sliderGroup)
    settingSlider:SetPoint("LEFT", stepBack, "RIGHT", 2, 0)
    settingSlider:SetPoint("RIGHT", stepFwd, "LEFT", -2, 0)
    settingSlider:SetHeight(16)
    settingSlider:EnableMouse(true)
    settingSlider:SetOrientation("HORIZONTAL")



    local trackLeft = settingSlider:CreateTexture(nil, "ARTWORK")
    trackLeft:SetAtlas("Minimal_SliderBar_Left", true)
    trackLeft:SetPoint("LEFT", 0, 0)
    local trackRight = settingSlider:CreateTexture(nil, "ARTWORK")
    trackRight:SetAtlas("Minimal_SliderBar_Right", true)
    trackRight:SetPoint("RIGHT", 0, 0)
    local trackMid = settingSlider:CreateTexture(nil, "ARTWORK")
    trackMid:SetAtlas("_Minimal_SliderBar_Middle", false)
    trackMid:SetPoint("LEFT", trackLeft, "RIGHT", 0, 0)
    trackMid:SetPoint("RIGHT", trackRight, "LEFT", 0, 0)
    trackMid:SetHeight(16)




    settingSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = settingSlider:GetThumbTexture()
    if thumb then
        thumb:SetAtlas("Minimal_SliderBar_Button", true)
        thumb:SetSize(20, 19)
    end
    if settingSlider.SetObeyStepOnDrag then settingSlider:SetObeyStepOnDrag(true) end
    settingSlider:EnableMouseWheel(false)
    settingSlider:SetScript("OnMouseWheel", nil)
    settingSlider:SetScript("OnValueChanged", function(self, newVal)
        if self._updating then return end
        applySettingValue(self._settingVar, newVal)
        local valText = resultRow.settingSliderValue
        if not valText then return end
        local fmt = self._settingFormatter
        if not fmt and ns.BlizzOptionsSearch and ns.BlizzOptionsSearch.GetFormatterForVariable then
            fmt = ns.BlizzOptionsSearch.GetFormatterForVariable(self._settingVar)
            if fmt then self._settingFormatter = fmt end
        end
        local displayVal
        if fmt then
            local fok, formatted = pcall(fmt, newVal)
            if fok and formatted ~= nil then
                local ft = type(formatted)
                if ft == "string" and formatted ~= "" then
                    displayVal = formatted
                elseif ft == "number" then
                    displayVal = (formatted == mfloor(formatted))
                        and tostring(mfloor(formatted))
                        or sformat("%.2f", formatted)
                end
            end
        end
        if not displayVal then
            displayVal = (newVal == mfloor(newVal))
                and tostring(mfloor(newVal))
                or sformat("%.2f", newVal)
        end
        valText:SetText(displayVal)
    end)
    resultRow.settingSlider = settingSlider




    settingSlider:HookScript("OnMouseUp", function() Search:RefreshResults() end)

    stepBack:SetScript("OnClick", function()
        local slider = resultRow.settingSlider
        if not slider:IsShown() then return end
        local cur = slider:GetValue()
        local step = slider:GetValueStep()
        if step == 0 then step = 1 end
        slider:SetValue(clampToRange(cur - step, slider))
    end)
    stepFwd:SetScript("OnClick", function()
        local slider = resultRow.settingSlider
        if not slider:IsShown() then return end
        local cur = slider:GetValue()
        local step = slider:GetValueStep()
        if step == 0 then step = 1 end
        slider:SetValue(clampToRange(cur + step, slider))
    end)






    local function refocusEditbox()
        if not (Search:GetSearchFrame() and Search:GetSearchFrame().editBox) then return end
        if Search:GetNavFrame() and Search:GetNavFrame():IsKeyboardEnabled() then return end
        Search:GetSearchFrame().editBox.blockFocus = nil
        Search:GetSearchFrame().editBox:SetFocus()
    end
    settingSlider:HookScript("OnMouseUp", refocusEditbox)
    stepBack:HookScript("OnMouseUp", refocusEditbox)
    stepFwd:HookScript("OnMouseUp", refocusEditbox)




    local keybindGroup = CreateFrame("Frame", nil, resultRow)
    keybindGroup:SetSize(140, 20)
    keybindGroup:SetPoint("RIGHT", resultRow, "RIGHT", -6, 0)
    keybindGroup:SetFrameLevel(resultRow:GetFrameLevel() + 5)
    keybindGroup:Hide()
    resultRow.settingKeybindGroup = keybindGroup

    local function MakeKeybindButton(parent)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(66, 20)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.08, 0.08, 0.08, 0.85)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.4, 0.4, 0.5, 0.4)
        btn:SetNormalFontObject("GameFontHighlightSmall")
        btn:SetText(_G["NOT_BOUND"] or "Not Bound")
        local txt = btn:GetFontString()
        if txt then txt:SetPoint("CENTER") end
        local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        border:SetAllPoints()
        if border.SetBackdrop then
            border:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            border:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.7)
        end




        btn:HookScript("OnEnter", function(self)
            local rowEnter = resultRow:GetScript("OnEnter")
            if rowEnter then rowEnter(resultRow) end
        end)
        btn:HookScript("OnLeave", function(self)
            local rowLeave = resultRow:GetScript("OnLeave")
            if rowLeave then rowLeave(resultRow) end
        end)
        return btn
    end

    local kb1 = MakeKeybindButton(keybindGroup)
    kb1:SetPoint("LEFT", keybindGroup, "LEFT", 0, 0)
    resultRow.settingKeybind1 = kb1

    local kb2 = MakeKeybindButton(keybindGroup)
    kb2:SetPoint("RIGHT", keybindGroup, "RIGHT", 0, 0)
    resultRow.settingKeybind2 = kb2

    local function StopKeybindCapture(btn)
        if not btn._waitingForKey then return end
        btn._waitingForKey = false
        Utils.DisarmBindingCapture(btn)
        btn:UnlockHighlight()
        if Search:GetActiveKeybindButton() == btn then Search:SetActiveKeybindButton(nil) end
        if btn._refresh then btn._refresh() end





        Utils.SafeAfter(0, function()
            if Search:GetSearchFrame() and Search:GetSearchFrame().editBox then
                Search:GetSearchFrame().editBox:SetEnabled(true)
            end
            refocusEditbox()
        end)
    end
    kb1._stopCapture = StopKeybindCapture
    kb2._stopCapture = StopKeybindCapture

    local function StartKeybindCapture(btn, action, slot)
        if btn._waitingForKey then
            StopKeybindCapture(btn)
            return
        end
        local activeKeybindBtn = Search:GetActiveKeybindButton()
        if activeKeybindBtn and activeKeybindBtn ~= btn then
            StopKeybindCapture(activeKeybindBtn)
        end
        Search:SetActiveKeybindButton(btn)
        btn._waitingForKey = true
        btn:SetText(L["OPT_KB_PRESS_KEY"])
        btn:LockHighlight()
        if Search:GetSearchFrame() and Search:GetSearchFrame().editBox then
            Search:GetSearchFrame().editBox.blockFocus = true
            Search:GetSearchFrame().editBox:ClearFocus()
            Search:GetSearchFrame().editBox:SetEnabled(false)
        end
        Utils.ArmBindingCapture(btn, function(self, combo)
            if combo == "stop" then
                StopKeybindCapture(self)
                return
            end
            if self._accountKeybind then
                EasyFind:SetAccountKeybind(action, combo)
                StopKeybindCapture(self)
                return
            end


            local k1, k2 = GetBindingKey(action)
            local oldKey = (slot == 1) and k1 or k2
            if oldKey then SetBinding(oldKey) end
            SetBinding(combo, action)
            SaveBindings(GetCurrentBindingSet())
            StopKeybindCapture(self)
        end)
    end

    local function MakeBindingClickHandler(slot)
        return function(self, mouseButton)
            local action = self._bindingAction
            if not action then return end
            if mouseButton == "RightButton" then
                if self._waitingForKey then StopKeybindCapture(self); return end
                if self._accountKeybind then
                    EasyFind:SetAccountKeybind(action, nil)
                else
                    local k1, k2 = GetBindingKey(action)
                    local oldKey = (slot == 1) and k1 or k2
                    if oldKey then SetBinding(oldKey) end
                    SaveBindings(GetCurrentBindingSet())
                end
                if self._refresh then self._refresh() end
                refocusEditbox()
                return
            end
            StartKeybindCapture(self, action, slot)
        end
    end
    kb1:SetScript("OnClick", MakeBindingClickHandler(1))
    kb2:SetScript("OnClick", MakeBindingClickHandler(2))





    local function MakeKbHoverHandler(slotLabel)
        return function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(sformat(L["KB_BIND_SLOT"], slotLabel), 1, 1, 1)
            GameTooltip:AddLine(L["KB_PRESS_COMBO"], 0.85, 0.78, 0.55, true)
            GameTooltip:AddLine(L["KB_RIGHT_CLICK_CLEAR"], 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end
    local function KbLeaveHandler()
        GameTooltip:Hide()
    end
    kb1:HookScript("OnEnter", MakeKbHoverHandler(L["KB_SLOT_PRIMARY"]))
    kb1:HookScript("OnLeave", KbLeaveHandler)
    kb2:HookScript("OnEnter", MakeKbHoverHandler(L["KB_SLOT_ALTERNATE"]))
    kb2:HookScript("OnLeave", KbLeaveHandler)









    local dropdownGroup = CreateFrame("Frame", nil, resultRow)
    dropdownGroup:SetSize(180, 25)
    dropdownGroup:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
    dropdownGroup:SetFrameLevel(resultRow:GetFrameLevel() + 5)
    dropdownGroup:Hide()
    resultRow.settingDropdownGroup = dropdownGroup

    local function MakePaddleButton(parent, iconAtlas)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(25, 25)
        local body = btn:CreateTexture(nil, "BACKGROUND")
        body:SetAllPoints()
        body:SetAtlas("common-dropdown-c-button-hover-2", false)
        local icon = btn:CreateTexture(nil, "OVERLAY")
        icon:SetSize(17, 17)
        icon:SetAtlas(iconAtlas, false)
        icon:SetPoint("CENTER", 0, 0)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetAtlas("common-dropdown-c-button-hover-2", false)
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.4)
        return btn
    end

    local ddPrev = MakePaddleButton(dropdownGroup, "common-dropdown-icon-back")
    ddPrev:SetPoint("LEFT", dropdownGroup, "LEFT", 0, 0)
    resultRow.settingDropdownPrev = ddPrev

    local ddNext = MakePaddleButton(dropdownGroup, "common-dropdown-icon-next")
    ddNext:SetPoint("RIGHT", dropdownGroup, "RIGHT", 0, 0)
    resultRow.settingDropdownNext = ddNext






    local PADDLE_OVERLAP = 6
    local ddCenter = CreateFrame("Button", nil, dropdownGroup)
    ddCenter:SetPoint("LEFT", ddPrev, "RIGHT", -PADDLE_OVERLAP, 0)
    ddCenter:SetPoint("RIGHT", ddNext, "LEFT", PADDLE_OVERLAP, 0)
    ddCenter:SetHeight(25)
    ddCenter:SetFrameLevel(ddPrev:GetFrameLevel() + 1)
    local ddBg = ddCenter:CreateTexture(nil, "BACKGROUND")
    ddBg:SetAllPoints()
    ddBg:SetAtlas("common-dropdown-c-button-hover-1", false)
    local ddHover = ddCenter:CreateTexture(nil, "HIGHLIGHT")
    ddHover:SetAllPoints()
    ddHover:SetAtlas("common-dropdown-c-button-hover-1", false)
    ddHover:SetBlendMode("ADD")
    ddHover:SetAlpha(0.4)
    local ddArrow = ddCenter:CreateTexture(nil, "OVERLAY")
    ddArrow:SetSize(12, 5)
    ddArrow:SetAtlas("common-dropdown-c-button-hover-arrow", false)
    ddArrow:SetPoint("RIGHT", ddCenter, "RIGHT", -8, 0)
    ddCenter:SetNormalFontObject("GameFontNormal")
    local ddTxt = ddCenter:GetFontString()
    if ddTxt then
        ddTxt:SetTextColor(1, 0.82, 0, 1)
        ddTxt:SetPoint("LEFT", ddCenter, "LEFT", 8, 0)
        ddTxt:SetPoint("RIGHT", ddArrow, "LEFT", -4, 0)
        ddTxt:SetJustifyH("CENTER")
        ddTxt:SetWordWrap(false)
        ddTxt:SetNonSpaceWrap(false)
        ddTxt:SetMaxLines(1)
    end
    resultRow.settingDropdownLabel = ddCenter














    local TEXT_LEFT_PAD       = 8
    local FS_RIGHT_OFFSET     = 4
    local TEXT_TO_CHEVRON_GAP = 16
    local function ComputeMaxTextW(btn)
        local btnLeft = btn:GetLeft()
        local arrowLeft = ddArrow:GetLeft()
        if not btnLeft or not arrowLeft then return nil end




        local regionW = arrowLeft - btnLeft - TEXT_LEFT_PAD - FS_RIGHT_OFFSET
        local maxW = regionW - 2 * (TEXT_TO_CHEVRON_GAP - FS_RIGHT_OFFSET)
        if maxW <= 0 then return nil end
        return maxW
    end

    local function ApplyDropdownTruncation(btn)
        local value = btn._fullText
        if not value or value == "" then
            btn:SetText("")
            return
        end
        btn:SetText(value)
        local fs = btn:GetFontString()
        if not fs then return end
        local maxW = ComputeMaxTextW(btn)
        if not maxW then return end
        local function getW()
            return (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth())
                or (fs.GetStringWidth and fs:GetStringWidth())
                or 0
        end
        if getW() <= maxW then return end
        for cut = #value - 1, 1, -1 do
            btn:SetText(value:sub(1, cut) .. "...")
            if getW() <= maxW then return end
        end
    end




    ddCenter:HookScript("OnSizeChanged", function(self)
        if self._fullText then ApplyDropdownTruncation(self) end
    end)

    resultRow.SetSettingDropdownText = function(self, value)
        local btn = self.settingDropdownLabel
        if not btn then return end
        btn._fullText = value or ""
        ApplyDropdownTruncation(btn)
    end







    ddCenter:SetScript("OnClick", function(self)
        local rowData = resultRow.data
        if not rowData or not rowData.settingVariable then return end
        local var = rowData.dropdownVariable or rowData.settingVariable
        local opts = rowData.settingOptions
        if not opts and ns.BlizzOptionsSearch and ns.BlizzOptionsSearch.GetOptionsForVariable then
            opts = ns.BlizzOptionsSearch.GetOptionsForVariable(var)
            if opts then rowData.settingOptions = opts end
        end
        if not opts or #opts == 0 then return end
        Rows.ToggleInlineSettingDropdown(self, opts,
            function() return Rows:ReadSettingVariable(var) end,
            function(value, written) Results:SetSettingDropdownValue(rowData, value, written) end, var)
    end)

    ddPrev:SetScript("OnClick", function()
        if resultRow.data then Results:CycleSettingDropdown(resultRow.data, -1) end
    end)
    ddNext:SetScript("OnClick", function()
        if resultRow.data then Results:CycleSettingDropdown(resultRow.data, 1) end
    end)


    local function ArmArrow(arrow, step)
        local rowData = resultRow.data
        local var, value = Results:NextSettingDropdownValue(rowData, step)
        if not (var and Rows.SecureOptionMacro(var, value)) then return end
        Rows.ArmOptionPad(arrow, var, value, function()
            Results:SetSettingDropdownValue(rowData, value, true)
            if arrow:IsVisible() then ArmArrow(arrow, step) end
        end)
    end
    ddPrev:HookScript("OnEnter", function(self) ArmArrow(self, -1) end)
    ddNext:HookScript("OnEnter", function(self) ArmArrow(self, 1) end)

    ddPrev:HookScript("OnMouseUp", refocusEditbox)
    ddNext:HookScript("OnMouseUp", refocusEditbox)
    ddCenter:HookScript("OnMouseUp", refocusEditbox)

    local settingSliderValue = sliderGroup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    settingSliderValue:SetPoint("BOTTOM", sliderGroup, "TOP", 0, -2)
    settingSliderValue:SetTextColor(0.7, 0.7, 0.7, 1.0)
    settingSliderValue:SetShadowOffset(1, -1)
    resultRow.settingSliderValue = settingSliderValue






    local APPLY_EXT_H = 22
    local applyExt = CreateFrame("Frame", nil, resultRow)
    applyExt:SetHeight(APPLY_EXT_H)
    applyExt:SetPoint("TOPLEFT", resultRow, "BOTTOMLEFT", 6, -2)
    applyExt:SetPoint("TOPRIGHT", resultRow, "BOTTOMRIGHT", -6, -2)
    applyExt:Hide()

    local applyExtSep = applyExt:CreateTexture(nil, "ARTWORK")
    applyExtSep:SetColorTexture(0.85, 0.78, 0.55, 0.55)
    applyExtSep:SetHeight(1)
    applyExtSep:SetPoint("TOPLEFT", applyExt, "TOPLEFT", 0, 0)
    applyExtSep:SetPoint("TOPRIGHT", applyExt, "TOPRIGHT", 0, 0)

    local resetBtn = CreateFrame("Button", nil, applyExt, "UIPanelButtonTemplate")
    resetBtn:SetSize(58, 18)
    resetBtn:SetText(_G["RESET"] or "Reset")
    resetBtn:SetPoint("RIGHT", applyExt, "CENTER", -2, -2)
    local applyBtn = CreateFrame("Button", nil, applyExt, "UIPanelButtonTemplate")
    applyBtn:SetSize(58, 18)
    applyBtn:SetText(_G["APPLY"] or "Apply")
    applyBtn:SetPoint("LEFT", applyExt, "CENTER", 2, -2)


    local function rowVars(d)
        if not d then return nil end
        local primary = d.settingVariable
        local slider = d.sliderVariable ~= primary and d.sliderVariable or nil
        local dropdown = d.dropdownVariable ~= primary and d.dropdownVariable or nil
        return primary, slider, dropdown
    end


    function applyExt:Label(d)
        local custom = d and Rows:CustomSetting(d.settingVariable)
        resetBtn:SetText(custom and custom.revertText or _G["RESET"] or "Reset")
        applyBtn:SetText(custom and custom.applyText or _G["APPLY"] or "Apply")
        local resetW, applyW = mmax(58, resetBtn:GetTextWidth() + 20), mmax(58, applyBtn:GetTextWidth() + 20)
        resetBtn:SetWidth(resetW)
        applyBtn:SetWidth(applyW)

        local shift = (resetW - applyW) / 2
        resetBtn:ClearAllPoints()
        resetBtn:SetPoint("RIGHT", applyExt, "CENTER", shift - 2, -2)
        applyBtn:ClearAllPoints()
        applyBtn:SetPoint("LEFT", applyExt, "CENTER", shift + 2, -2)
    end
    local function Custom()
        return resultRow.data and Rows:CustomSetting(resultRow.data.settingVariable)
    end
    applyBtn:SetScript("OnClick", function()
        local custom = Custom()
        if custom then
            if custom.apply then custom.apply() end
            return
        end
        if not ns.BlizzOptionsSearch or not ns.BlizzOptionsSearch.ApplyVariable then return end
        ns.BlizzOptionsSearch:ApplyVariable(rowVars(resultRow.data))
        Search:RefreshResults()
        RefocusSearchEditBox()
    end)
    resetBtn:SetScript("OnClick", function()
        local custom = Custom()
        if custom then
            if custom.revert then custom.revert() end
            Search:RefreshResults()
            RefocusSearchEditBox()
            return
        end
        if not ns.BlizzOptionsSearch or not ns.BlizzOptionsSearch.RevertVariable then return end
        local primary, slider, dropdown = rowVars(resultRow.data)
        if primary then ns.BlizzOptionsSearch:RevertVariable(primary) end
        if slider then ns.BlizzOptionsSearch:RevertVariable(slider) end
        if dropdown then ns.BlizzOptionsSearch:RevertVariable(dropdown) end
        Search:RefreshResults()
        RefocusSearchEditBox()
    end)
    resultRow.settingApplyExt = applyExt
    resultRow.settingApplyExtH = APPLY_EXT_H

end
