local _, ns = ...

local Filters = ns.Filters
local Utils = ns.Utils
local L = ns.L

local CreateFrame = CreateFrame
local C_Timer = C_Timer
local UIParent = UIParent
local ipairs = Utils.ipairs
local sformat = string.format
local mmax, mceil = math.max, math.ceil
local UnitClass = UnitClass
local GetNumClasses = GetNumClasses
local GetClassInfo = GetClassInfo
local GetNumSpecializationsForClassID = GetNumSpecializationsForClassID
local GetSpecializationInfoForClassID = GetSpecializationInfoForClassID
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo

local RADIO_OFF_TEX = ns.RADIO_OFF_TEX
local RADIO_ON_TEX = ns.RADIO_ON_TEX
local FLYOUT_ROW_H = 20

local allClassSpecs
local function GetAllClassSpecs()
    if allClassSpecs then return allClassSpecs end
    allClassSpecs = {}
    for classIdx = 1, GetNumClasses() do
        local className, classFile, classID = GetClassInfo(classIdx)
        if className then
            local specs = {}


            for specIdx = 1, (GetNumSpecializationsForClassID and GetNumSpecializationsForClassID(classID)) or 0 do
                local sid, sname = GetSpecializationInfoForClassID(classID, specIdx)
                if sid then specs[#specs + 1] = { specID = sid, specName = sname } end
            end
            allClassSpecs[#allClassSpecs + 1] = {
                classID = classID, className = className, classFile = classFile, specs = specs,
            }
        end
    end
    return allClassSpecs
end

local function ColorStr(classFile)
    local c = RAID_CLASS_COLORS[classFile]
    return c and sformat("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) or ""
end

local function PlayerSpecID()
    local si = GetSpecialization and GetSpecialization()
    if si and GetSpecializationInfo then return (GetSpecializationInfo(si)) end
end


local RADIO_TEXT_INSET = 22

local POPUP_MARGIN = 8

local function CreateRadioRow(parent, width)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width - POPUP_MARGIN * 2, FLYOUT_ROW_H)
    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetSize(14, 14)
    tex:SetTexture(RADIO_OFF_TEX)
    tex:SetPoint("LEFT", 4, 0)
    local lbl = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    ns.ShadeText(lbl)
    lbl:SetPoint("LEFT", tex, "RIGHT", 4, 0)
    Utils.InstallMenuRowHighlight(btn)
    btn._label = lbl
    btn._setChecked = function(on) tex:SetTexture(on and RADIO_ON_TEX or RADIO_OFF_TEX) end
    return btn
end



local function FitPopupWidth(rows, count, extraContentW, minWidth)
    local contentW = RADIO_TEXT_INSET + Utils.MaxRowLabelWidth(rows, count)
    if extraContentW and extraContentW > contentW then contentW = extraContentW end
    return mmax(minWidth or ns.FLYOUT_MIN_WIDTH, mceil(contentW) + POPUP_MARGIN * 2)
end



















function Filters:BuildClassSpecSelector(opts)
    local parent = opts.parent
    local width = opts.width
    local hasSpec = opts.hasSpec and true or false
    local guards = opts.guardFrames
    local getScale = opts.getScale or function() return 1.0 end
    local POPUP_WIDTH = opts.popupWidth or 180
    local FLYOUT_WIDTH = opts.flyoutWidth or 160

    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, 27)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", opts.x or 0, opts.y or 0)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    Utils.StyleDropdownBg(bg)
    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetAtlas("common-dropdown-a-button-hover")
    arrow:SetSize(22, 22)
    arrow:SetPoint("RIGHT", -10, -1)
    arrow:SetVertexColor(0.7, 0.7, 0.7)
    local label = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    ns.ShadeText(label)
    label:SetPoint("LEFT", 14, 0)
    label:SetPoint("RIGHT", arrow, "LEFT", -2, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    btn:SetScript("OnEnter", function() arrow:SetVertexColor(1, 1, 1) end)
    btn:SetScript("OnLeave", function() arrow:SetVertexColor(0.7, 0.7, 0.7) end)
    btn._label = label
    btn._chev = arrow

    local function UpdateLabel()
        local f = opts.getFilter()
        if f == "all" then
            label:SetText(_G["ALL_CLASSES"] or "All Classes")
            return
        end
        if not f then
            local className, classFile = UnitClass("player")
            local color = ColorStr(classFile)
            if hasSpec then
                local sid = PlayerSpecID()
                local sname
                if sid then
                    for _, c in ipairs(GetAllClassSpecs()) do
                        for _, s in ipairs(c.specs) do
                            if s.specID == sid then sname = s.specName end
                        end
                    end
                end
                if sname and className then
                    label:SetText(color .. className .. " (" .. sname .. ")|r")
                    return
                end
            end
            label:SetText(color .. (className or L["FILTER_CURRENT_SPEC"]) .. "|r")
            return
        end
        local cls
        for _, c in ipairs(GetAllClassSpecs()) do
            if c.classID == f.classID then cls = c; break end
        end
        if not cls then label:SetText("?"); return end
        local color = ColorStr(cls.classFile)
        if hasSpec and f.specID then
            local sname
            for _, s in ipairs(cls.specs) do
                if s.specID == f.specID then sname = s.specName; break end
            end
            label:SetText(color .. cls.className .. " (" .. (sname or "?") .. ")|r")
        else
            label:SetText(color .. cls.className .. "|r")
        end
    end


    local function IsMatch(filterVal)
        local f = opts.getFilter()
        if filterVal == "all" then return f == "all" end
        if type(filterVal) ~= "table" then return false end
        if not f then
            local _, _, cid = UnitClass("player")
            if filterVal.classID ~= cid then return false end
            if hasSpec then
                return filterVal.specID ~= nil and filterVal.specID == PlayerSpecID()
            end
            return not filterVal.specID
        end
        if type(f) ~= "table" or filterVal.classID ~= f.classID then return false end
        return filterVal.specID == f.specID
    end


    local function IsClassMatch(val)
        local f = opts.getFilter()
        if val == "all" then return f == "all" end
        if type(val) ~= "table" then return false end
        if type(f) == "table" then return val.classID == f.classID end
        if not f then
            local _, _, cid = UnitClass("player")
            return val.classID == cid
        end
        return false
    end

    local specPopup = CreateFrame("Frame", opts.popupName, UIParent, "BackdropTemplate")
    specPopup:SetFrameStrata("TOOLTIP")
    specPopup:SetFrameLevel(parent:GetFrameLevel() + 20)
    opts.stylePopup(specPopup)
    specPopup:EnableMouse(true)
    specPopup:Hide()
    if guards then guards[#guards + 1] = specPopup end

    local function Choose(val)
        opts.setFilter(val)
        UpdateLabel()
        specPopup:Hide()
        if opts.onChange then opts.onChange() end
    end

    local LayoutPopup
    local GetPopupNavRows
    local classFlyout, GetFlyoutNavRows

    if not hasSpec then

        local rows = {}
        local allRow = CreateRadioRow(specPopup, POPUP_WIDTH)
        allRow._label:SetText(_G["ALL_CLASSES"] or "All Classes")
        allRow:SetScript("OnClick", function() Choose("all") end)
        rows[#rows + 1] = allRow
        for _, cls in ipairs(GetAllClassSpecs()) do
            local r = CreateRadioRow(specPopup, POPUP_WIDTH)
            r._label:SetText(ColorStr(cls.classFile) .. cls.className .. "|r")
            r._classID = cls.classID
            r:SetScript("OnClick", function() Choose({ classID = cls.classID }) end)
            rows[#rows + 1] = r
        end
        LayoutPopup = function()
            local py = -6
            for _, r in ipairs(rows) do
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", specPopup, "TOPLEFT", 8, py)
                r:Show()
                r._setChecked(r._classID and IsMatch({ classID = r._classID }) or (not r._classID and IsMatch("all")))
                py = py - FLYOUT_ROW_H
            end
            local w = FitPopupWidth(rows, nil, nil, POPUP_WIDTH)
            for _, r in ipairs(rows) do r:SetWidth(w - POPUP_MARGIN * 2) end
            specPopup:SetSize(w, -py + 6)
            Utils.RefreshMenuRowHighlights(specPopup, rows)
        end
        GetPopupNavRows = function() return rows end
    else

        classFlyout = CreateFrame("Frame", opts.flyoutName, UIParent, "BackdropTemplate")
        classFlyout:SetFrameStrata("TOOLTIP")
        classFlyout:SetFrameLevel(parent:GetFrameLevel() + 30)
        opts.stylePopup(classFlyout)
        classFlyout:EnableMouse(true)
        classFlyout:Hide()
        if guards then guards[#guards + 1] = classFlyout end

        local function CurrentClass()
            local f = opts.getFilter()
            if type(f) == "table" and f.classID then
                for _, c in ipairs(GetAllClassSpecs()) do
                    if c.classID == f.classID then return c end
                end
            end
            local _, _, cid = UnitClass("player")
            for _, c in ipairs(GetAllClassSpecs()) do
                if c.classID == cid then return c end
            end
            return GetAllClassSpecs()[1]
        end

        local LayoutClassFlyout
        local flyoutRows = {}
        local allRow = CreateRadioRow(classFlyout, FLYOUT_WIDTH)
        allRow._label:SetText(_G["ALL_CLASSES"] or "All Classes")
        allRow._val = "all"
        allRow:SetScript("OnClick", function()
            opts.setFilter("all"); UpdateLabel(); classFlyout:Hide(); specPopup:Hide()
            if opts.onChange then opts.onChange() end
        end)
        flyoutRows[#flyoutRows + 1] = allRow
        for _, cls in ipairs(GetAllClassSpecs()) do
            local r = CreateRadioRow(classFlyout, FLYOUT_WIDTH)
            r._label:SetText(ColorStr(cls.classFile) .. cls.className .. "|r")
            r._val = { classID = cls.classID }
            r:SetScript("OnClick", function()
                opts.setFilter({ classID = cls.classID }); UpdateLabel()


                local viaKeyboard = classFlyout:IsKeyboardEnabled()
                classFlyout:Hide()
                if viaKeyboard then specPopup:Hide() end
                if opts.onChange then opts.onChange() end
                if specPopup:IsShown() then LayoutPopup() end
            end)
            flyoutRows[#flyoutRows + 1] = r
        end
        LayoutClassFlyout = function()
            local fy = -6
            for _, r in ipairs(flyoutRows) do
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", classFlyout, "TOPLEFT", 8, fy)
                r:Show()
                r._setChecked(IsClassMatch(r._val))
                fy = fy - FLYOUT_ROW_H
            end
            local w = FitPopupWidth(flyoutRows, nil, nil, FLYOUT_WIDTH)
            for _, r in ipairs(flyoutRows) do r:SetWidth(w - POPUP_MARGIN * 2) end
            classFlyout:SetSize(w, -fy + 6)
            Utils.RefreshMenuRowHighlights(classFlyout, flyoutRows)
        end

        local classRow = CreateFrame("Button", nil, specPopup)
        classRow:SetSize(POPUP_WIDTH - 16, FLYOUT_ROW_H)
        local crLabel = classRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        ns.ShadeText(crLabel)
        crLabel:SetPoint("LEFT", 8, 0)
        crLabel:SetText(_G["CLASS"] or "Class")
        local crArrow = classRow:CreateTexture(nil, "ARTWORK")
        crArrow:SetSize(16, 16)
        crArrow:SetPoint("RIGHT", -4, 0)
        Utils.SetChevronTexture(crArrow)
        Utils.InstallMenuRowHighlight(classRow)
        local function OpenClassFlyout()
            LayoutClassFlyout()
            classFlyout:SetScale(getScale())
            Utils.OpenFlyoutBeside(classFlyout, classRow, 2)
            classFlyout:Show()
        end
        classRow:SetScript("OnEnter", OpenClassFlyout)
        classRow:SetScript("OnClick", OpenClassFlyout)

        local classHeader = CreateFrame("Frame", nil, specPopup)
        classHeader:SetSize(POPUP_WIDTH - 16, FLYOUT_ROW_H)
        local chLabel = classHeader:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        ns.ShadeText(chLabel)
        chLabel:SetPoint("LEFT", 8, 0)

        local MAX_SPECS = 5
        local specRows = {}
        for i = 1, MAX_SPECS do
            local r = CreateRadioRow(specPopup, POPUP_WIDTH)
            r:SetScript("OnEnter", function() classFlyout:Hide() end)
            r:Hide()
            specRows[i] = r
        end

        LayoutPopup = function()
            local cls = CurrentClass()
            local py = -6
            classRow:ClearAllPoints()
            classRow:SetPoint("TOPLEFT", specPopup, "TOPLEFT", 8, py)
            classRow:Show()
            py = py - FLYOUT_ROW_H
            if not cls then
                classHeader:Hide()
                for _, r in ipairs(specRows) do r:Hide() end
                local w = FitPopupWidth(specRows, 0, 8 + (crLabel:GetStringWidth() or 0) + 24, POPUP_WIDTH)
                classRow:SetWidth(w - POPUP_MARGIN * 2)
                specPopup:SetSize(w, -py + 6)
                Utils.RefreshMenuRowHighlights(specPopup)
                return
            end
            chLabel:SetText(ColorStr(cls.classFile) .. cls.className .. "|r")
            classHeader:ClearAllPoints()
            classHeader:SetPoint("TOPLEFT", specPopup, "TOPLEFT", 8, py)
            classHeader:Show()
            py = py - FLYOUT_ROW_H
            local ri = 1
            for _, spec in ipairs(cls.specs) do
                local r = specRows[ri]
                local val = { classID = cls.classID, specID = spec.specID }
                r._label:SetText(spec.specName)
                r._setChecked(IsMatch(val))
                r:SetScript("OnClick", function() Choose(val) end)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", specPopup, "TOPLEFT", 8, py)
                r:Show()
                py = py - FLYOUT_ROW_H
                ri = ri + 1
            end
            local allSpecRow = specRows[ri]
            if allSpecRow then
                local val = { classID = cls.classID }
                allSpecRow._label:SetText(_G["ALL_SPECS"] or "All Specializations")
                allSpecRow._setChecked(IsMatch(val))
                allSpecRow:SetScript("OnClick", function() Choose(val) end)
                allSpecRow:ClearAllPoints()
                allSpecRow:SetPoint("TOPLEFT", specPopup, "TOPLEFT", 8, py)
                allSpecRow:Show()
                py = py - FLYOUT_ROW_H
                ri = ri + 1
            end
            for hi = ri, MAX_SPECS do specRows[hi]:Hide() end

            local extraW = mmax(8 + (crLabel:GetStringWidth() or 0) + 24,
                8 + (chLabel:GetStringWidth() or 0))
            local w = FitPopupWidth(specRows, ri - 1, extraW, POPUP_WIDTH)
            classRow:SetWidth(w - POPUP_MARGIN * 2)
            classHeader:SetWidth(w - POPUP_MARGIN * 2)
            for si = 1, ri - 1 do specRows[si]:SetWidth(w - POPUP_MARGIN * 2) end
            specPopup:SetSize(w, -py + 6)
            Utils.RefreshMenuRowHighlights(specPopup)
        end

        GetFlyoutNavRows = function() return flyoutRows end
        GetPopupNavRows = function()
            local navRows = { classRow }
            for _, r in ipairs(specRows) do
                if r:IsShown() then navRows[#navRows + 1] = r end
            end
            return navRows
        end






        local hoverAccum = 0
        Utils.SafeOnUpdate(classFlyout, function(self, elapsed)
            hoverAccum = hoverAccum + (elapsed or 0)
            if hoverAccum < 0.05 then return end
            hoverAccum = 0
            if self:IsKeyboardEnabled() then return end
            if not self:IsMouseOver() and not specPopup:IsMouseOver() then
                if not self._leaveTimer then
                    self._leaveTimer = C_Timer.NewTimer(0.2, function()
                        self._leaveTimer = nil
                        if not self:IsMouseOver() and not classRow:IsMouseOver() then
                            self:Hide()
                        end
                    end)
                end
            else
                if self._leaveTimer then
                    self._leaveTimer:Cancel()
                    self._leaveTimer = nil
                end
            end
        end)

        specPopup:HookScript("OnHide", function() classFlyout:Hide() end)
    end

    btn:SetScript("OnClick", function()
        if specPopup:IsShown() then
            specPopup:Hide()
            return
        end
        LayoutPopup()
        specPopup:SetScale(getScale())
        Utils.OpenDropdownBelow(specPopup, btn, 2)
        specPopup:Show()
    end)
    Filters.AttachOutsideClickClose(specPopup)

    if opts.keyboardNav then
        opts.keyboardNav(specPopup, GetPopupNavRows)
        if classFlyout then opts.keyboardNav(classFlyout, GetFlyoutNavRows) end
    end

    UpdateLabel()
    return { button = btn, Refresh = UpdateLabel, popup = specPopup, flyout = classFlyout }
end
