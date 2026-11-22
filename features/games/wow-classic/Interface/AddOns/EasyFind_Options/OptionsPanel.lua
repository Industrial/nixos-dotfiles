


local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns then return end


if ns.BUILD ~= "5.5.0" then select(2, ...).stale = true return end

local Options = {}
ns.Options = Options

local Utils   = ns.Utils
local L       = ns.L
local mfloor, mmin, mmax = Utils.mfloor, Utils.mmin, Utils.mmax
local sformat = Utils.sformat
local tostring = Utils.tostring
local tinsert = Utils.tinsert
local IsMouseButtonDown = IsMouseButtonDown


local OPT_FONTS = {}
for _, name in ipairs({ "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontDisableSmall",
        "GameFontNormal", "GameFontHighlight", "GameFontNormalHuge" }) do
    local copy = "EasyFindOptions" .. name
    local font = _G[copy] or CreateFont(copy)
    font:CopyFontObject(_G[name])
    local file, size, flags = font:GetFont()
    font:SetFont(file, size + 2, flags)
    OPT_FONTS[name] = copy
end
local SMALL_HIGHLIGHT_FONT = _G[OPT_FONTS.GameFontHighlightSmall]



local function ShowResetConfirm(text, onAccept)
    ns.ShowThemedDialog({ text = text, acceptText = _G["RESET"] or "Reset", onAccept = onAccept })
end




local STYLE_LABEL_KEY = {
    ["EasyFind Arrow"]      = "OPT_INDICATOR_STYLE_EASYFIND",
    ["Chevrons"]            = "OPT_INDICATOR_STYLE_CHEVRONS",
    ["Classic Quest Arrow"] = "OPT_INDICATOR_STYLE_CLASSIC",
    ["Minimap Player Arrow"] = "OPT_INDICATOR_STYLE_MINIMAP",
    ["Low-res Gauntlet"]    = "OPT_INDICATOR_STYLE_LOWRES",
    ["HD Gauntlet"]         = "OPT_INDICATOR_STYLE_HD",
}
local COLOR_LABEL_KEY = {
    Yellow = "OPT_COLOR_YELLOW", Gold = "OPT_COLOR_GOLD", Orange = "OPT_COLOR_ORANGE",
    Red = "OPT_COLOR_RED", Green = "OPT_COLOR_GREEN", Blue = "OPT_COLOR_BLUE",
    Purple = "OPT_COLOR_PURPLE", White = "OPT_COLOR_WHITE",
}
local function StyleLabel(value)
    local key = value and STYLE_LABEL_KEY[value]
    return (key and L[key]) or value
end
local function ColorLabel(value)
    local key = value and COLOR_LABEL_KEY[value]
    return (key and L[key]) or value
end

local OPTIONS_PANEL_ALPHA = 0.9
local OPTIONS_FRAME_STRATA = "FULLSCREEN_DIALOG"
local OPTIONS_FRAME_LEVEL = 700

local optionsFrame








local function OpenTutorialWizard()
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end
    if not (ns.RequestOnboarding and ns.RequestOnboarding()) then return end
    if Options.embedded and _G.SettingsPanel and _G.HideUIPanel then
        _G.HideUIPanel(_G.SettingsPanel)
    else
        optionsFrame:Hide()
    end
    if ns.Wizard and ns.Wizard.Show then ns.Wizard:Show(ns.Wizard.FEATURES_PAGE) end
end
local isInitialized = false

local VISIBILITY_AUTO   = ns.VISIBILITY_AUTO
local VISIBILITY_SMART  = ns.VISIBILITY_SMART
local VISIBILITY_ALWAYS = ns.VISIBILITY_ALWAYS
local RESULTS_BELOW = 0
local RESULTS_ABOVE = 1



local UI_RESET_KEYS = {
    "smartShow", "autoHide", "combatHide", "combatDim", "moveDim", "windowBorder", "themeFrameArt",
    "showAppsButton", "showFilterButton", "learnFromPicks", "macroPickerSearch", "lockPosition",
    "uiResultsAbove", "showResultShortcutHints", "fontSize", "searchWindowOpacity", "uiSearchScale",
    "uiSearchWidth", "uiSearchBarHeight", "uiResultsScale", "uiResultsWidth", "uiSearchPosition",
    "uiResultsRows", "wowheadLocale", "uiSearchFilters", "uiMapFilters", "housingCollection",
    "housingDyeableOnly", "housingCollectionBonusOnly", "housingIndoors", "housingOutdoors", "lootSpecs",
    "lootSearchSlots", "lootSearchStats", "lootUpgradesOnly", "lootDifficulty", "mountFilterCollected",
    "mountFilterNotCollected", "mountFilterUnusable", "mountTypeGround", "mountTypeFlying",
    "mountTypeAquatic", "mountTypeRideAlong", "mountSourceFilters", "achievementFilterMode",
    "hideAchievementHeaders", "hideGuildAchievements", "appearanceSetClass", "appearanceSetCollected",
    "appearanceSetNotCollected", "appearanceSetPvE", "appearanceSetPvP", "uiMapSearchLocal",
}



local MAP_RESET_KEYS = {
    "iconScale", "mapPinStyle", "blinkingPins", "autoPinClear", "mapWaypointOnly",
    "autoTrackPins", "globalSearchFilters", "localSearchFilters",
    "mapTabFilters", "alwaysShowRares", "mapTabShowRecent",
    "mapTabAutoExpand", "mapTabShowParents", "mapTabRecentCount", "mapTabFontSize",
}

local UI_POSITION_KEYS = {
    "uiSearchPosition", "uiSearchScale", "uiSearchWidth", "uiSearchBarHeight",
    "uiResultsScale", "uiResultsWidth", "uiResultsRows",
}

local CloneTable = ns.Utils.DeepCopy

local function ApplyDefaultKeys(keys)
    for i = 1, #keys do
        local key = keys[i]
        local value = ns.DB_DEFAULTS[key]
        if type(value) == "table" then
            EasyFind.db[key] = CloneTable(value)
        else
            EasyFind.db[key] = value
        end
    end
end

local function ResetOptionsPosition()
    EasyFind.db.optionsPosition = nil
    if optionsFrame then
        optionsFrame:ClearAllPoints()
        optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function RunSoon(fn)
    Utils.SafeAfter(0, fn)
end

local function ClearMapRuntime()
    ns.ClearMapRuntime()
end



local function RefreshUIRuntime(resetPosition)
    ns.ApplyUISettings(resetPosition)
end

local function RefreshMapRuntime()
    ns.ApplyMapSettings()
end

local function GetVisibilityModeValue()
    return ns.GetVisibilityMode()
end

local function GetResultsDirectionValue()
    return EasyFind and EasyFind.db
        and EasyFind.db.uiResultsAbove
        and RESULTS_ABOVE
        or RESULTS_BELOW
end

local function SyncOptionControls()
    if not optionsFrame then return end

    if optionsFrame.uiFontPresetRow then optionsFrame.uiFontPresetRow:SetValue(EasyFind.db.fontSize or ns.DEFAULT_FONT_SIZE) end
    if optionsFrame.searchScaleRow then optionsFrame.searchScaleRow:SetValue(EasyFind.db.uiSearchScale or 1.0) end
    if optionsFrame.resultRowsRow then optionsFrame.resultRowsRow:SetValue(EasyFind.db.uiResultsRows or 6) end
    if optionsFrame.SetWowheadSelection then optionsFrame.SetWowheadSelection(EasyFind.db.wowheadLocale or "auto") end
    if optionsFrame.searchOpacityRow then optionsFrame.searchOpacityRow:SetValue(mfloor((EasyFind.db.searchWindowOpacity or ns.SEARCH_WINDOW_ALPHA) * 100 + 0.5)) end
    if optionsFrame.mapIconPresetRow then optionsFrame.mapIconPresetRow:SetValue(EasyFind.db.iconScale or 0.8) end
    if optionsFrame.recentCountStepper then optionsFrame.recentCountStepper:SetValue(EasyFind.db.mapTabRecentCount or 3) end

    if optionsFrame.visibilityModeRow then optionsFrame.visibilityModeRow:SetValue(GetVisibilityModeValue()) end
    if optionsFrame.lockPositionCheckbox then optionsFrame.lockPositionCheckbox:SetChecked(EasyFind.db.lockPosition or false) end
    if optionsFrame.resultsDirectionRow then optionsFrame.resultsDirectionRow:SetValue(GetResultsDirectionValue()) end
    if optionsFrame.resultShortcutHintsCheckbox then optionsFrame.resultShortcutHintsCheckbox:SetChecked(EasyFind.db.showResultShortcutHints ~= false) end
    if optionsFrame.RefreshBorderRow then optionsFrame.RefreshBorderRow() end
    if optionsFrame.classicBgRow then optionsFrame.classicBgRow:SetValue(EasyFind.db.classicArt or "marble") end
    if optionsFrame.UpdateClassicRows then optionsFrame.UpdateClassicRows() end
    if optionsFrame.searchAutocompleteCheckbox then optionsFrame.searchAutocompleteCheckbox:SetChecked(EasyFind.db.searchAutocomplete ~= false) end
    if optionsFrame.showAppsButtonCheckbox then optionsFrame.showAppsButtonCheckbox:SetChecked(EasyFind.db.showAppsButton ~= false) end
    if optionsFrame.showFilterButtonCheckbox then optionsFrame.showFilterButtonCheckbox:SetChecked(EasyFind.db.showFilterButton ~= false) end
    if optionsFrame.learnPicksCheckbox then optionsFrame.learnPicksCheckbox:SetChecked(EasyFind.db.learnFromPicks ~= false) end
    if optionsFrame.macroPickerSearchCheckbox then optionsFrame.macroPickerSearchCheckbox:SetChecked(EasyFind.db.macroPickerSearch ~= false) end
    if optionsFrame.clickSelectsCheckbox then optionsFrame.clickSelectsCheckbox:SetChecked(EasyFind.db.clickSelectsRow == true) end
    if optionsFrame.UpdateFocusBindEnabled then optionsFrame.UpdateFocusBindEnabled() end
    if optionsFrame.minimapBtnCheckbox then optionsFrame.minimapBtnCheckbox:SetChecked(EasyFind.db.showMinimapButton ~= false) end
    if optionsFrame.updateNotifyCheckbox then optionsFrame.updateNotifyCheckbox:SetChecked(EasyFind.db.updateNotify ~= false) end
    if optionsFrame.extTipsCheckbox then optionsFrame.extTipsCheckbox:SetChecked(EasyFind.db.hideExtensionTips == true) end
    if optionsFrame.rareTrackCheckbox then optionsFrame.rareTrackCheckbox:SetChecked(EasyFind.db.alwaysShowRares or false) end

    if optionsFrame.mapTabShowRecentCheckbox then optionsFrame.mapTabShowRecentCheckbox:SetChecked(EasyFind.db.mapTabShowRecent ~= false) end
    if optionsFrame.UpdateRecentCountEnabled then optionsFrame.UpdateRecentCountEnabled() end
    if optionsFrame.mapPinStyleRow then optionsFrame.mapPinStyleRow:SetValue(EasyFind.db.mapPinStyle or "glow") end
    if optionsFrame.blinkingPinsCheckbox then optionsFrame.blinkingPinsCheckbox:SetChecked(EasyFind.db.blinkingPins or false) end
    if optionsFrame.autoTrackPinsCheckbox then optionsFrame.autoTrackPinsCheckbox:SetChecked(EasyFind.db.autoTrackPins ~= false) end
    if optionsFrame.autoPinClearCheckbox then optionsFrame.autoPinClearCheckbox:SetChecked(EasyFind.db.autoPinClear ~= false) end
    if optionsFrame.waypointOnlyCheckbox then optionsFrame.waypointOnlyCheckbox:SetChecked(EasyFind.db.mapWaypointOnly == true) end
    if optionsFrame.UpdateMapToggleVisual then optionsFrame.UpdateMapToggleVisual() end

    if optionsFrame.RetintIndicatorPreviews then optionsFrame.RetintIndicatorPreviews() end
    if optionsFrame.fontBtnText then optionsFrame.fontBtnText:SetText(EasyFind.db.font or (_G["DEFAULT"] or "Default")) end

    local clr = EasyFind.db.indicatorColor or "Yellow"
    local rgb = ns.INDICATOR_COLORS[clr] or ns.INDICATOR_COLORS.Yellow
    if optionsFrame.colorBtnText then
        optionsFrame.colorBtnText:SetText(ColorLabel(clr))
        optionsFrame.colorBtnText:SetTextColor(Utils.RGB(rgb))
    end
    if optionsFrame.themeBtnText then
        optionsFrame.themeBtnText:SetText(EasyFind.db.uiTheme or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.uiTheme) or "Midnight")
    end
    if optionsFrame.SetIndicatorSelection then optionsFrame.SetIndicatorSelection(EasyFind.db.indicatorStyle or "EasyFind Arrow") end


    if optionsFrame.toggleFocusBtn then optionsFrame.toggleFocusBtn:SetText(EasyFind:GetAccountKeybind("EASYFIND_TOGGLE_FOCUS") or (_G["NOT_BOUND"] or "Not Bound")) end
    if optionsFrame.focusBarBtn then optionsFrame.focusBarBtn:SetText(EasyFind:GetAccountKeybind("EASYFIND_FOCUS_BAR") or (_G["NOT_BOUND"] or "Not Bound")) end
    if optionsFrame.mapFocusBtn then optionsFrame.mapFocusBtn:SetText(EasyFind:GetAccountKeybind("EASYFIND_MAP_FOCUS") or (_G["NOT_BOUND"] or "Not Bound")) end
    if optionsFrame.clearBtn then optionsFrame.clearBtn:SetText(EasyFind:GetAccountKeybind("EASYFIND_CLEAR") or (_G["NOT_BOUND"] or "Not Bound")) end
end

local PaintRoundedFill = ns.SetRoundedRectFill


local function Look() return ns.ThemeSet("options") end


local SECTION_TABLE_FILL = ns.SECTION_TABLE_FILL
local function HideRoundedBorder(frame)
    ns.SetRoundedRectBorderEdgeShown(frame, false)
end
local HideRoundedFrameBorder = HideRoundedBorder

local function PaintControlFill(frame, color, alpha)


    local kind = ns.LIVE_FILL_NAMES[color]
    if kind then
        frame._efControlFillKind = kind
        frame._efControlFillAlpha = alpha
    end
    PaintRoundedFill(frame, color[1], color[2], color[3], alpha or 1, true)
end




local function InRoundedCard(frame)
    if frame._efInCard == nil then
        frame._efInCard = false
        local parent = frame:GetParent()
        for _ = 1, 5 do
            if not parent then break end
            if parent.combinedBorder then
                frame._efInCard = true
                break
            end
            parent = parent:GetParent()
        end
    end
    return frame._efInCard
end



local classicSelectors = {}
local ERA_FRAME = "Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame"
local function DressSelector(btn)
    local classic = ns.ClassicLook()
    local era = btn._efEra
    if classic and not era then
        local k = 28 / 33
        local up = 15 * k + (28 - (btn:GetHeight() or 22)) / 2
        era = {}
        for i, u in ipairs({ { 0, 0.1953125 }, { 0.1953125, 0.8046875 }, { 0.8046875, 1 } }) do
            local t = btn:CreateTexture(nil, "BACKGROUND", nil, 2)
            t:SetTexture(ERA_FRAME)
            t:SetTexCoord(u[1], u[2], 0, 1)
            t:SetHeight(64 * k)
            era[i] = t
        end
        era[1]:SetWidth(25 * k)
        era[1]:SetPoint("TOPLEFT", btn, "TOPLEFT", -13 * k, up)
        era[3]:SetWidth(25 * k)
        era[3]:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 13 * k, up)
        era[2]:SetPoint("TOPLEFT", era[1], "TOPRIGHT")
        era[2]:SetPoint("TOPRIGHT", era[3], "TOPLEFT")
        era.arrow = btn:CreateTexture(nil, "ARTWORK")
        era.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        era.arrow:SetSize(24 * k, 24 * k)
        era.arrow:SetPoint("RIGHT", btn, "RIGHT", 1, 0)
        era.hl = btn:CreateTexture(nil, "HIGHLIGHT")
        era.hl:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        era.hl:SetBlendMode("ADD")
        era.hl:SetAllPoints(era.arrow)
        btn._efEra = era
    end
    if era then
        for _, t in pairs(era) do t:SetShown(classic) end
    end
    ns.SetRoundedRectBorderShown(btn, not classic)
    HideRoundedFrameBorder(btn)
    if btn.arrow then btn.arrow:SetShown(not classic) end
end

local function StyleSelectorButton(btnFrame, height)
    btnFrame:SetBackdrop(nil)
    ns.CreateRoundedRectBorder(btnFrame)
    ns.SetRoundedRectBarHeight(btnFrame, mmin(height or 22, 10))
    HideRoundedFrameBorder(btnFrame)
    PaintControlFill(btnFrame, ns.BTN_FILL_NORMAL, 1)
    ns.RampButton(btnFrame)
    classicSelectors[#classicSelectors + 1] = btnFrame
    btnFrame:HookScript("OnEnter", function(self)
        if self:IsEnabled() then PaintControlFill(self, ns.BTN_FILL_HOVER, 1) end
    end)
    btnFrame:HookScript("OnLeave", function(self)
        if self:IsEnabled() then PaintControlFill(self, ns.BTN_FILL_NORMAL, 1) end
    end)
    btnFrame:HookScript("OnMouseDown", function(self)
        if self:IsEnabled() then PaintControlFill(self, ns.BTN_FILL_PRESSED, 1) end
    end)
    btnFrame:HookScript("OnMouseUp", function(self)
        if self:IsEnabled() then
            PaintControlFill(self, self:IsMouseOver() and ns.BTN_FILL_HOVER or ns.BTN_FILL_NORMAL, 1)
        end
    end)
end



local PROFILE_SECTION_LABEL_KEY = ns.SettingsRows.PROFILE_SECTION_LABEL_KEY

local function ParkScrollBarInMargin(bar, card, top)
    if not bar then return end
    bar:ClearAllPoints()
    bar:SetPoint("TOPRIGHT", card, "TOPRIGHT", -3, -(top + 4))
    bar:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -3, 10)
end

local function CreateFlyoutSelector(parent, globalPrefix, width, anchor, initialText)
    local btnFrame = CreateFrame("Button", globalPrefix .. "Button", parent, "BackdropTemplate")
    btnFrame:SetSize(width, 22)
    btnFrame:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    StyleSelectorButton(btnFrame, 22)

    local btnText = btnFrame:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    btnFrame._efText = btnText
    btnText:SetPoint("LEFT", btnFrame, "LEFT", 8, 0)
    btnText:SetPoint("RIGHT", btnFrame, "RIGHT", -18, 0)
    btnText:SetJustifyH("CENTER")
    btnText:SetText(initialText)

    local arrow = btnFrame:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    arrow:SetPoint("RIGHT", btnFrame, "RIGHT", -6, 0)
    arrow:SetText("v")
    btnFrame.arrow = arrow
    DressSelector(btnFrame)

    return btnFrame, btnText
end



local optionsFlyouts = {}




local ERA_LIST = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
local function PaintFlyoutWell(flyout)

    local classic = ns.ClassicLook()
    local back = flyout._efEraList
    if classic and not back then
        back = CreateFrame("Frame", nil, flyout, "BackdropTemplate")
        back:SetPoint("TOPLEFT", flyout, "TOPLEFT", -9, 9)
        back:SetPoint("BOTTOMRIGHT", flyout, "BOTTOMRIGHT", 9, -9)
        back:SetFrameLevel(flyout:GetFrameLevel())
        back:EnableMouse(false)
        back:SetBackdrop(ERA_LIST)
        flyout._efEraList = back
    end
    if back then back:SetShown(classic) end
    ns.SetRoundedRectBorderShown(flyout, not classic)
    ns.SetRoundedRectBorderEdgeShown(flyout, false)
    if flyout.ringInset then flyout.ringInset:SetShown(not classic) end
    local theme = Look().theme
    local ring = theme and theme.resultsBackdropBorderColor or { 0.42, 0.42, 0.42 }
    flyout._efNoAutoRetint = true
    ns.SetRoundedRectFill(flyout, ring[1], ring[2], ring[3], 1, true)
    PaintControlFill(flyout.ringInset, SECTION_TABLE_FILL, 1)
end



local searchWells = {}
local function PaintSearchWell(shell)
    local look = ns.ThemeSetOf(shell)
    local palette = look.palette
    local line = palette and palette.separator or { 0.42, 0.42, 0.42 }
    local ring = palette and palette.borderColor or { line[1], line[2], line[3], 0.7 }
    ns.PaintRingedWell(shell, ring, look.EDITBOX_INSET_FILL or { 0.02, 0.02, 0.03 })
end
local function SearchWell(shell)
    ns.CreateRingedWell(shell, 6)
    searchWells[#searchWells + 1] = shell
    PaintSearchWell(shell)
end



local function AddSearchClear(shell, box)
    local clear = Utils.CreateClearButton(shell)
    clear:SetFrameLevel(box:GetFrameLevel() + 1)
    box:SetPoint("RIGHT", clear, "LEFT", -4, 0)
    clear:SetScript("OnClick", function()
        local onEscape = box:GetScript("OnEscapePressed")
        if onEscape then onEscape(box) else box:SetText("") end
    end)
    box:HookScript("OnTextChanged", function(self) clear:SetShown((self:GetText() or "") ~= "") end)
    return clear
end



local groupRings = {}



local function PaintGroupRing(ring)
    local palette = ns.ThemeSetOf(ring).palette
    local line = palette and palette.separator or { 0.42, 0.42, 0.42 }
    local c = palette and palette.borderColor or { line[1], line[2], line[3], 0.7 }
    ns.SetRoundedRectFill(ring, c[1], c[2], c[3], c[4] or 1, true)
    ns.SetRoundedRectBorderShown(ring, not ns.ClassicLook())
end

local function CreateFlyoutPanel(btnFrame, globalPrefix, width, numChoices)


    local flyout = CreateFrame("Frame", globalPrefix .. "Flyout", optionsFrame or btnFrame, "BackdropTemplate")
    optionsFlyouts[#optionsFlyouts + 1] = flyout
    flyout._efButton = btnFrame
    btnFrame:HookScript("OnHide", function() flyout:Hide() end)
    flyout:SetSize(width, numChoices * 20 + 6)
    flyout:SetPoint("TOPRIGHT", btnFrame, "BOTTOMRIGHT", 0, -2)
    flyout:SetFrameStrata("FULLSCREEN_DIALOG")
    flyout:SetFrameLevel((optionsFrame and optionsFrame:GetFrameLevel() or OPTIONS_FRAME_LEVEL) + 20)
    flyout:SetBackdrop(nil)

    ns.CreateRingedWell(flyout, 5)
    PaintFlyoutWell(flyout)
    flyout:Hide()

    btnFrame:SetScript("OnClick", function()
        local opening = not flyout:IsShown()
        if opening then
            for i = 1, #optionsFlyouts do
                if optionsFlyouts[i] ~= flyout then optionsFlyouts[i]:Hide() end
            end

            flyout:ClearAllPoints()
            local bottom = btnFrame:GetBottom()
            local room = bottom and bottom * btnFrame:GetEffectiveScale() - (Utils.MENU_EDGE or 8)
            if room and room < flyout:GetHeight() * flyout:GetEffectiveScale() then
                flyout:SetPoint("BOTTOMRIGHT", btnFrame, "TOPRIGHT", 0, 2)
            else
                flyout:SetPoint("TOPRIGHT", btnFrame, "BOTTOMRIGHT", 0, -2)
            end
        end
        flyout:SetShown(opening)
        if btnFrame.arrow then btnFrame.arrow:SetText(opening and "^" or "v") end
    end)

    flyout:SetScript("OnShow", function(self)
        self:SetFrameLevel((optionsFrame and optionsFrame:GetFrameLevel() or OPTIONS_FRAME_LEVEL) + 20)


        local level = self:GetFrameLevel()
        self.ringInset:SetFrameLevel(level + 1)
        for _, row in ipairs({ self:GetChildren() }) do
            if row ~= self.ringInset then
                row:SetFrameLevel(level + 2)
                for _, part in ipairs({ row:GetChildren() }) do part:SetFrameLevel(level + 3) end
            end
        end
        self:SetScript("OnUpdate", function(self)
            if not self:IsMouseOver() and not btnFrame:IsMouseOver() then
                if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then




                    ns._efFlyoutClosedAt = GetTime()
                    self:Hide()
                end
            end
        end)
    end)
    flyout:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        if btnFrame.arrow then btnFrame.arrow:SetText("v") end
    end)

    return flyout
end



local function DefaultTag(label)
    return label .. " (" .. (_G["DEFAULT"] or "Default") .. ")"
end



local function AddFlyoutChecks(flyout, defs, itemWidth)
    local rows, y = {}, -3
    local function Sync()
        for i = 1, #rows do rows[i]:SetChecked(rows[i].def.get() and true or false) end
    end
    for _, def in ipairs(defs) do
        if def.separator then
            local line = flyout.ringInset:CreateTexture(nil, "ARTWORK")
            line:SetHeight(1)
            line:SetPoint("TOPLEFT", flyout, "TOPLEFT", 8, y - 3)
            line:SetPoint("TOPRIGHT", flyout, "TOPRIGHT", -8, y - 3)
            line:SetColorTexture(1, 1, 1, 0.12)
            y = y - 7
        else
            local row = CreateFrame("CheckButton", nil, flyout)
            row:SetSize(itemWidth, 18)
            row:SetPoint("TOPLEFT", flyout, "TOPLEFT", 3, y)
            Utils.SetCheckboxTextures(row, 14)
            local rowBg = CreateFrame("Frame", nil, row)
            rowBg:SetAllPoints()
            rowBg:EnableMouse(false)
            ns.CreateRoundedRectBorder(rowBg)
            ns.SetRoundedRectBarHeight(rowBg, 9)
            HideRoundedFrameBorder(rowBg)
            PaintRoundedFill(rowBg, 1, 1, 1, 0)
            local label = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
            label:SetPoint("LEFT", row:GetNormalTexture(), "RIGHT", 4, 0)
            label:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            label:SetJustifyH("LEFT")
            label:SetText(def.label)
            row._label, row.def = label, def
            row:SetScript("OnEnter", function() PaintRoundedFill(rowBg, 1, 1, 1, 0.06) end)
            row:SetScript("OnLeave", function() PaintRoundedFill(rowBg, 1, 1, 1, 0) end)
            row:SetScript("OnClick", function(self)
                def.set(self:GetChecked() and true or false)
                Sync()
            end)
            rows[#rows + 1] = row
            y = y - 20
        end
    end
    flyout:HookScript("OnShow", Sync)

    local contentW = 0
    for i = 1, #rows do
        local w = 24 + rows[i]._label:GetUnboundedStringWidth() + 6
        if w > contentW then contentW = w end
    end
    local rowW = mmax(itemWidth, mfloor(contentW + 0.5))
    for i = 1, #rows do rows[i]:SetWidth(rowW) end
    flyout:SetSize(rowW + 6, 3 - y)
end





local function HoverPreview(flyout, getter, apply)
    local saved, shown, token
    flyout:HookScript("OnShow", function() saved, shown = getter(), nil end)
    flyout:HookScript("OnHide", function()
        token = nil
        if shown ~= nil and shown ~= saved then apply(saved) end
        shown = nil
    end)
    local function Hover(value)
        local mine = {}
        token = mine
        Utils.SafeAfter(0.12, function()
            if token ~= mine or not flyout:IsShown() or value == (shown or saved) then return end
            shown = value
            apply(value)
        end)
    end
    local function Keep(value) saved, shown, token = value, nil, nil end
    return Hover, Keep
end


local function AddFlyoutOptions(flyout, choices, itemWidth, onSelect, labelFn, styleFn, onHover)



    local btnFrame = flyout._efButton or flyout:GetParent()
    local selectorRow = btnFrame and btnFrame:GetParent()
    local shownText = btnFrame and btnFrame._efText
    if selectorRow and shownText and (selectorRow._efControl == nil or selectorRow._efControl.fromFlyout) then
        local list = {}
        for _, name in ipairs(choices) do list[#list + 1] = { value = name, label = labelFn and labelFn(name) or name } end
        selectorRow._efControl = {
            kind = "choice", fromFlyout = true, choices = list, set = onSelect,
            get = function()
                local text = shownText:GetText()
                for _, c in ipairs(list) do
                    if c.label == text then return c.value end
                end
            end,
        }
    end
    local rows = {}
    for i, name in ipairs(choices) do
        local flyoutBtn = CreateFrame("Button", nil, flyout)
        flyoutBtn:SetSize(itemWidth, 18)
        flyoutBtn:SetPoint("TOPLEFT", flyout, "TOPLEFT", 3, -3 - (i - 1) * 20)
        local rowBg = CreateFrame("Frame", nil, flyoutBtn)
        rowBg:SetAllPoints()
        rowBg:EnableMouse(false)
        ns.CreateRoundedRectBorder(rowBg)
        ns.SetRoundedRectBarHeight(rowBg, 9)
        HideRoundedFrameBorder(rowBg)
        PaintRoundedFill(rowBg, 1, 1, 1, 0)
        local label = flyoutBtn:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
        label:SetPoint("LEFT", flyoutBtn, "LEFT", 6, 0)
        label:SetPoint("RIGHT", flyoutBtn, "RIGHT", -6, 0)
        label:SetJustifyH("LEFT")
        label:SetText(labelFn and labelFn(name) or name)
        flyoutBtn._label = label
        if styleFn then styleFn(flyoutBtn, name, label) end
        flyoutBtn:SetScript("OnEnter", function()
            PaintRoundedFill(rowBg, 1, 1, 1, 0.06)
            if onHover then onHover(name) end
        end)
        flyoutBtn:SetScript("OnLeave", function()
            PaintRoundedFill(rowBg, 1, 1, 1, 0)
        end)
        flyoutBtn:SetScript("OnClick", function()
            onSelect(name)
            flyout:Hide()
        end)
        rows[i] = flyoutBtn
    end



    local contentW = 0
    for i = 1, #rows do
        local label = rows[i]._label
        local getter = label.GetUnboundedStringWidth or label.GetStringWidth
        local w = 6 + getter(label) + 6 + (rows[i]._rightIconW or 0)
        if w > contentW then contentW = w end
    end
    local rowW = mmax(itemWidth, mfloor(contentW + 0.5))
    if rowW > itemWidth then
        for i = 1, #rows do rows[i]:SetWidth(rowW) end
        flyout:SetWidth(rowW + 6)
    end
    return rows
end







local settingChecks = setmetatable({}, { __mode = "k" })
local function EraBox(checkbox, track)
    local box = checkbox._efEraBox
    if box then return box end
    box = CreateFrame("Frame", nil, checkbox)
    box:SetSize(24, 24)
    box:SetPoint("CENTER", track, "CENTER", 0, 0)
    box:EnableMouse(false)
    box.up = box:CreateTexture(nil, "ARTWORK")
    box.up:SetAllPoints()
    box.up:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box.hl = box:CreateTexture(nil, "OVERLAY", nil, 1)
    box.hl:SetAllPoints()
    box.hl:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    box.hl:SetBlendMode("ADD")
    box.check = box:CreateTexture(nil, "OVERLAY", nil, 2)
    box.check:SetAllPoints()
    checkbox._efEraBox = box
    return box
end

local function CreateCheckbox(parent, name, label, tooltipText, compact, width, toggleLeft)
    local frameName = name and ("EasyFindOptions" .. name .. "Checkbox") or nil
    local rowH = compact and 22 or 28
    local toggleW = compact and 28 or 32
    local toggleH = compact and 14 or 16
    local knobSize = toggleH - 2
    local checkbox = CreateFrame("CheckButton", frameName, parent)
    local rowW = width or (compact and 264 or 396)
    checkbox:SetSize(rowW, rowH)
    checkbox:RegisterForClicks("LeftButtonUp")



    local toggleRightOff = compact and 4 or 8
    if toggleLeft then
        checkbox:SetHitRectInsets(toggleLeft - 8, math.max(0, rowW - toggleLeft - toggleW - 8), 0, 0)
    else
        checkbox:SetHitRectInsets(rowW - toggleW - toggleRightOff - 8, 0, 0, 0)
    end

    local rowBg = CreateFrame("Frame", nil, checkbox)
    rowBg:EnableMouse(false)
    ns.CreateRoundedRectBorder(rowBg)
    ns.SetRoundedRectBarHeight(rowBg, toggleH + 10)
    HideRoundedFrameBorder(rowBg)
    PaintRoundedFill(rowBg, 1, 1, 1, 0)
    checkbox.rowBg = rowBg

    local text = checkbox:CreateFontString(nil, "OVERLAY", compact and OPT_FONTS.GameFontHighlightSmall or OPT_FONTS.GameFontNormalSmall)
    text:SetPoint("LEFT", checkbox, "LEFT", compact and 6 or 8, 0)
    text:SetJustifyH("LEFT")
    checkbox.Text = text
    text._efSearchLabel = true
    checkbox._efTooltip = tooltipText

    local track = CreateFrame("Frame", nil, checkbox)
    track:SetSize(toggleW, toggleH)
    if toggleLeft then
        track:SetPoint("LEFT", checkbox, "LEFT", toggleLeft, 0)
    else
        track:SetPoint("RIGHT", checkbox, "RIGHT", -toggleRightOff, 0)
    end
    track:EnableMouse(false)
    ns.CreateRoundedRectBorder(track)
    ns.SetRoundedRectBarHeight(track, toggleH)
    HideRoundedFrameBorder(track)
    checkbox.track = track



    rowBg:SetPoint("TOPLEFT", track, "TOPLEFT", -6, 5)
    rowBg:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 6, -5)

    text:SetPoint("RIGHT", track, "LEFT", -8, 0)
    ns.MakeEllipsisLabel(text, label or "")

    local knob = CreateFrame("Frame", nil, track)
    knob:SetSize(knobSize, knobSize)
    knob:EnableMouse(false)
    ns.CreateRoundedRectBorder(knob)
    ns.SetRoundedRectBarHeight(knob, knobSize)
    HideRoundedFrameBorder(knob)
    PaintRoundedFill(knob, 0.96, 0.96, 0.96, 1)
    checkbox.knob = knob

    local function UpdateVisual(self)
        local enabled = self:IsEnabled()
        local checked = self:GetChecked()
        local rowAlpha = self._efHover and enabled and 0.055 or 0
        PaintRoundedFill(self.rowBg, 1, 1, 1, rowAlpha)




        if enabled then
            local pal = Look().palette
            local theme = not InRoundedCard(self) and pal and pal.light
                and Look().theme
            if theme and theme.leafColor then
                text:SetTextColor(theme.leafColor[1], theme.leafColor[2], theme.leafColor[3], 1)
            else
                text:SetTextColor(0.92, 0.92, 0.92, 1)
            end
        else
            text:SetTextColor(0.50, 0.50, 0.50, 1)
        end
        local classic = ns.ClassicLook()
        track:SetShown(not classic)
        if classic then
            local box = EraBox(self, track)
            box:Show()
            box.up:SetDesaturated(not enabled)
            box.hl:SetShown(self._efHover and enabled or false)
            box.check:SetTexture(enabled and "Interface\\Buttons\\UI-CheckBox-Check"
                or "Interface\\Buttons\\UI-CheckBox-Check-Disabled")
            box.check:SetShown(checked and true or false)
            return
        elseif self._efEraBox then
            self._efEraBox:Hide()
        end
        local accent = Look().CONTROL_ACCENT
        if checked and enabled then
            PaintRoundedFill(track, accent[1], accent[2], accent[3], 1)
        elseif checked then
            PaintRoundedFill(track, accent[1] * 0.45, accent[2] * 0.45, accent[3] * 0.45, 1)
        elseif enabled then
            PaintRoundedFill(track, 0.23, 0.23, 0.25, 1)
        else
            PaintRoundedFill(track, 0.13, 0.13, 0.14, 1)
        end

        knob:ClearAllPoints()
        if checked then
            knob:SetPoint("RIGHT", track, "RIGHT", -1, 0)
        else
            knob:SetPoint("LEFT", track, "LEFT", 1, 0)
        end
    end

    local rawSetChecked = checkbox.SetChecked
    checkbox.SetChecked = function(self, checked)
        rawSetChecked(self, checked)
        UpdateVisual(self)
    end
    checkbox.RefreshVisual = UpdateVisual
    checkbox.GetFontString = function(self) return self.Text end
    checkbox.SetText = function(self, value)
        self.Text:SetText(value or "")
    end



    local rawSetScript = checkbox.SetScript
    checkbox.SetScript = function(self, scriptType, handler)
        if scriptType == "OnClick" and handler then
            rawSetScript(self, "OnClick", function(s, ...)
                UpdateVisual(s)
                handler(s, ...)
            end)
        else
            rawSetScript(self, scriptType, handler)
        end
    end

    checkbox:HookScript("OnClick", UpdateVisual)
    checkbox:HookScript("OnEnter", function(self)
        self._efHover = true
        UpdateVisual(self)
    end)
    checkbox:HookScript("OnLeave", function(self)
        self._efHover = nil
        UpdateVisual(self)
    end)
    if tooltipText then
        Utils.AttachDelayedTooltip(checkbox, "ANCHOR_RIGHT", function()
            return label, tooltipText
        end)
    end
    checkbox:HookScript("OnEnable", UpdateVisual)
    checkbox:HookScript("OnDisable", UpdateVisual)

    settingChecks[checkbox] = true
    UpdateVisual(checkbox)
    return checkbox
end

local DISABLED_TEXT = { 0.5, 0.5, 0.5 }
local NORMAL_TEXT = {1.0, 1.0, 1.0}
local OPTIONS_PANEL_SCALE = 0.88
local TEXT_DIM = ns.TEXT_DIM
local SECTION_TITLE_TEXT = ns.GOLD_COLOR
local NAV_SELECTED = ns.NAV_SELECTED_FILL
local NAV_HOVER = ns.NAV_HOVER_FILL
local NAV_CLEAR = { 0, 0, 0, 0 }

local function TintRoundedFill(frame, r, g, b)
    ns.SetRoundedRectFill(frame, r, g, b, 1, true)
end

local function StyleWizardBackground(frame)


    ns.StyleWizardPanel(frame, 1)
end

local SetModernButtonFill = ns.SetRoundedRectBorderFillColor
local SetModernButtonAlpha = ns.SetRoundedRectBorderBgAlpha



local CLASSIC_LIST_HL = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

local function SetNavButtonBg(btn, color)
    local classic = ns.ClassicLook()
    local hl = btn._efListHL
    if classic and not hl then
        hl = btn:CreateTexture(nil, "BACKGROUND")
        hl:SetTexture(CLASSIC_LIST_HL)
        hl:SetBlendMode("ADD")
        hl:SetAllPoints(btn)
        btn._efListHL = hl
    end
    if hl then
        hl:SetShown(classic and color ~= NAV_CLEAR)
        hl:SetAlpha(color == NAV_HOVER and 0.5 or 1)
    end



    if color == NAV_CLEAR or classic then
        ns.SetRoundedRectBorderShown(btn, false)
        return
    end
    ns.SetRoundedRectBorderShown(btn, true)
    ns.SetRoundedRectRingShown(btn, false)
    SetModernButtonFill(btn, Utils.RGB(color, 1))
    SetModernButtonAlpha(btn, color[4] or 1)
end


local function CreateModernButton(parent, text, width, height)
    local btn = ns.CreateModernButton(parent, text, width, height)
    btn._label:SetFontObject(OPT_FONTS.GameFontNormalSmall)
    btn._label:SetTextColor(1, 1, 1, 1)
    ns.ShadeText(btn._label)
    btn:SetText(text)
    ns.PaintButtonRamp(btn)
    return btn
end

local function CreateSettingsGroup(parent, width, height)
    local group = CreateFrame("Frame", nil, parent)
    group:SetSize(width, height)
    ns.CreateRoundedRectBorder(group)
    ns.SetRoundedRectBarHeight(group, 8)
    HideRoundedBorder(group)
    ns.ApplyCardFill(group)
    local ring = CreateFrame("Frame", nil, group)
    ring:SetPoint("TOPLEFT", group, "TOPLEFT", -1, 1)
    ring:SetPoint("BOTTOMRIGHT", group, "BOTTOMRIGHT", 1, -1)
    ring:SetFrameLevel(math.max(0, group:GetFrameLevel() - 1))
    ring._efNoAutoRetint = true
    ns.CreateRoundedRectBorder(ring)
    ns.SetRoundedRectBarHeight(ring, 10)
    ns.SetRoundedRectRingShown(ring, false)
    groupRings[#groupRings + 1] = ring
    PaintGroupRing(ring)
    group.controls = {}
    group.AddControl = function(self, control)
        if control then tinsert(self.controls, control) end
        return control
    end
    group.SetGroupEnabled = function(self, enabled)
        self:SetAlpha(enabled and 1.0 or 0.35)
        for _, control in ipairs(self.controls) do
            if control.SetGroupEnabled then
                control:SetGroupEnabled(enabled)
            elseif control.Enable and control.Disable then
                if enabled then control:Enable() else control:Disable() end
            end
        end
    end
    return group
end


local function FindNearestChoice(choices, value)
    local best = choices[1]
    if type(value) ~= "number" then
        for _, choice in ipairs(choices) do
            if choice.value == value then return choice end
        end
        return best
    end
    local bestDelta
    for _, choice in ipairs(choices) do
        local delta = math.abs((value or choice.value) - choice.value)
        if not bestDelta or delta < bestDelta then
            best = choice
            bestDelta = delta
        end
    end
    return best
end

local function PaintPresetButton(btn, active, hover, enabled)
    if not enabled then
        PaintControlFill(btn, ns.BTN_FILL_DISABLED, 1)
        if btn._label then btn._label:SetTextColor(Utils.RGB(TEXT_DIM, 1)) end
    elseif active then
        PaintControlFill(btn, ns.CONTROL_ACCENT, 1)
        if btn._label then
            local windowFill = Look().SEARCH_WINDOW_FILL_COLOR
            btn._label:SetTextColor(windowFill[1], windowFill[2], windowFill[3], 1)
        end
    elseif hover then
        PaintControlFill(btn, ns.BTN_FILL_HOVER, 1)
        if btn._label then


            if Look().palette and Look().palette.light then
                btn._label:SetTextColor(0.96, 0.96, 0.96, 1)
            else
                btn._label:SetTextColor(Utils.RGB(Look().TEXT_PRIMARY, 1))
            end
        end
    else


        PaintControlFill(btn, ns.SEARCH_WINDOW_FILL_COLOR, 1)
        if btn._label then
            local presetTheme = Look().theme
            local presetLeaf = presetTheme and presetTheme.leafColor
            if presetLeaf then
                btn._label:SetTextColor(presetLeaf[1], presetLeaf[2], presetLeaf[3], 1)
            else
                btn._label:SetTextColor(Utils.RGB(Look().TEXT_BODY, 1))
            end
        end
    end
end






local function ApplyRowLabelColor(label, enabled, host)



    label._efOwnColor = true
    if not enabled then
        label:SetTextColor(Utils.RGB(DISABLED_TEXT, 1))
        return
    end
    if host and InRoundedCard(host) then
        label:SetTextColor(Utils.RGB(NORMAL_TEXT, 1))
        return
    end
    local pal = Look().palette
    local theme = pal and pal.light and Look().theme
    if theme and theme.leafColor then
        label:SetTextColor(theme.leafColor[1], theme.leafColor[2], theme.leafColor[3], 1)
    else
        label:SetTextColor(Utils.RGB(NORMAL_TEXT, 1))
    end
end

local function CreateSegmentedPresetRow(parent, labelText, choices, getter, setter, tooltipText, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width or 396, 30)
    row.enabled = true
    row._efControl = { kind = "choice", get = getter, set = setter, choices = choices, tooltip = tooltipText }

    local label = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalSmall)
    label:SetPoint("LEFT", row, "LEFT", 8, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -188, 0)
    label:SetJustifyH("LEFT")
    ApplyRowLabelColor(label, true, row)
    ns.MakeEllipsisLabel(label, labelText)
    row.label = label
    row.RefreshVisual = function(self) ApplyRowLabelColor(label, self.enabled, self) end



    local trackW, trackH = 170, 22
    local track = CreateFrame("Frame", nil, row, "BackdropTemplate")
    track:SetSize(trackW, trackH)
    track:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    ns.CreateRoundedRectBorder(track)
    ns.SetRoundedRectBarHeight(track, trackH)
    PaintControlFill(track, ns.BTN_FILL_NORMAL, 0.96)
    HideRoundedFrameBorder(track)
    row.track = track

    local node = CreateFrame("Frame", nil, track, "BackdropTemplate")
    node:SetFrameLevel(track:GetFrameLevel() + 1)
    node:SetHeight(trackH - 4)
    ns.CreateRoundedRectBorder(node)
    ns.SetRoundedRectBarHeight(node, trackH - 4)
    HideRoundedFrameBorder(node)
    PaintControlFill(node, ns.SEARCH_WINDOW_FILL_COLOR, 1)
    row.node = node

    row.buttons = {}
    local halfW = (trackW - 4) / 2
    for i = 1, 2 do
        local choice = choices[i]
        local btn = CreateFrame("Button", nil, track)
        btn:SetFrameLevel(track:GetFrameLevel() + 2)
        btn:SetSize(halfW, trackH)
        btn:SetPoint("LEFT", track, "LEFT", 2 + (i - 1) * halfW, 0)
        btn.choice = choice
        local text = btn:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
        text:SetPoint("LEFT", btn, "LEFT", 4, 0)
        text:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
        text:SetJustifyH("CENTER")
        ns.MakeEllipsisLabel(text, choice.label, { tooltip = false })


        text._efOwnColor = true
        btn._label = text
        btn:SetScript("OnClick", function(self)
            if not row.enabled then return end
            local value = self.choice.value
            row:SetValue(value)
            RunSoon(function() setter(value) end)
        end)
        Utils.AttachDelayedTooltip(btn, "ANCHOR_RIGHT", function(self)
            local tipBody = self.choice.tooltip or tooltipText
            if not tipBody then return nil end
            return self.choice.tooltip and self.choice.label or labelText, tipBody
        end)
        row.buttons[i] = btn
    end

    row.SetValue = function(self, value)
        local choice = FindNearestChoice(choices, value)
        self.activeValue = choice and choice.value
        local activeIndex = self.activeValue == choices[2].value and 2 or 1
        node:ClearAllPoints()
        node:SetWidth(halfW)
        node:SetPoint("LEFT", track, "LEFT", 2 + (activeIndex - 1) * halfW, 0)


        PaintControlFill(node, ns.SEARCH_WINDOW_FILL_COLOR, 1)
        local segTheme = Look().theme
        local segLeaf = segTheme and segTheme.leafColor
        for i = 1, #self.buttons do
            local active = activeIndex == i
            if self.enabled and active and segLeaf then
                self.buttons[i]._label:SetTextColor(segLeaf[1], segLeaf[2], segLeaf[3], 1)
            else
                local c = self.enabled and NORMAL_TEXT or DISABLED_TEXT
                self.buttons[i]._label:SetTextColor(Utils.RGB(c, 1))
            end
        end
    end
    row.SetGroupEnabled = function(self, enabled)
        self.enabled = enabled
        self:SetAlpha(enabled and 1.0 or 0.35)
        if self.label then ApplyRowLabelColor(self.label, enabled, self) end
        PaintControlFill(track, enabled and ns.BTN_FILL_NORMAL or ns.BTN_FILL_DISABLED, 0.96)
        for _, btn in ipairs(self.buttons) do
            if enabled then btn:Enable() else btn:Disable() end
        end
        self:SetValue(self.activeValue or getter())
    end

    row:SetValue(getter())
    return row
end

local function CreatePresetRow(parent, labelText, choices, getter, setter, tooltipText, width)
    if #choices == 2 then
        return CreateSegmentedPresetRow(parent, labelText, choices, getter, setter, tooltipText, width)
    end

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width or 396, 28)
    row.enabled = true
    row._efControl = { kind = "choice", get = getter, set = setter, choices = choices, tooltip = tooltipText }

    local label = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalSmall)
    label:SetPoint("LEFT", row, "LEFT", 8, 0)
    local controlW = (#choices == 3) and 174 or 184
    label:SetPoint("RIGHT", row, "RIGHT", -controlW - 18, 0)
    label:SetJustifyH("LEFT")
    ApplyRowLabelColor(label, true, row)
    ns.MakeEllipsisLabel(label, labelText)
    row.label = label
    row.RefreshVisual = function(self) ApplyRowLabelColor(label, self.enabled, self) end

    row.buttons = {}
    local btnW = math.floor(controlW / #choices)
    local right = -8
    for i = #choices, 1, -1 do
        local choice = choices[i]
        local btn = CreateModernButton(row, choice.label, btnW, 20)
        ns.SetRoundedRectBarHeight(btn, 16)
        btn.choice = choice
        btn:SetPoint("RIGHT", row, "RIGHT", right, 0)
        right = right - btnW - 2
        btn:SetScript("OnClick", function(self)
            if not row.enabled then return end
            local value = self.choice.value
            row:SetValue(value)
            RunSoon(function() setter(value) end)
        end)
        btn:SetScript("OnEnter", function(self)
            PaintPresetButton(self, row.activeValue == self.choice.value, true, row.enabled)
        end)
        btn:SetScript("OnLeave", function(self)
            PaintPresetButton(self, row.activeValue == self.choice.value, false, row.enabled)
        end)
        if tooltipText then
            Utils.AttachDelayedTooltip(btn, "ANCHOR_RIGHT", function()
                return labelText, tooltipText
            end)
        end
        row.buttons[i] = btn
    end

    row.SetValue = function(self, value)
        local choice = FindNearestChoice(choices, value)
        self.activeValue = choice and choice.value
        for _, btn in ipairs(self.buttons) do
            PaintPresetButton(btn, self.activeValue == btn.choice.value, false, self.enabled)
        end
    end
    row.SetGroupEnabled = function(self, enabled)
        self.enabled = enabled
        self:SetAlpha(enabled and 1.0 or 0.35)
        if self.label then ApplyRowLabelColor(self.label, enabled, self) end
        for _, btn in ipairs(self.buttons) do
            if enabled then btn:Enable() else btn:Disable() end
            PaintPresetButton(btn, self.activeValue == btn.choice.value, false, enabled)
        end
    end

    row:SetValue(getter())
    return row
end

local function CreateStepperRow(parent, labelText, minVal, maxVal, getter, setter, tooltipText, width, step)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width or 396, 28)
    row.enabled = true
    row._efControl = { kind = "slider", get = getter, set = setter, min = minVal, max = maxVal, step = step or 1,
                       tooltip = tooltipText }

    local label = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalSmall)
    label:SetPoint("LEFT", row, "LEFT", 8, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -112, 0)
    label:SetJustifyH("LEFT")
    ApplyRowLabelColor(label, true, row)
    label:SetText(labelText)
    row.RefreshVisual = function(self)
        ApplyRowLabelColor(label, self.enabled, self)
        if self.RestyleStepButtons then self.RestyleStepButtons() end
    end

    local function StyleStepperButton(stepBtn)
        stepBtn._efWindowFill = true
        local washR, washG, washB = ns.RowWashColor()
        if washR then
            ns.SetRoundedRectFill(stepBtn, washR, washG, washB, 1, true)
            stepBtn._efControlFillKind = false
        else
            PaintControlFill(stepBtn, ns.BTN_FILL_NORMAL, 1)
        end
        local stepTheme = Look().theme
        local stepLeaf = stepTheme and stepTheme.leafColor
        if stepBtn._label then
            if stepLeaf and stepBtn:IsEnabled() then
                stepBtn._label:SetTextColor(stepLeaf[1], stepLeaf[2], stepLeaf[3], 1)
            elseif not stepBtn:IsEnabled() then
                stepBtn._label:SetTextColor(0.65, 0.65, 0.65, 1)
            end
        end
    end

    local plusBtn = CreateModernButton(row, "+", 24, 20)
    plusBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)




    local valueShell = CreateFrame("Frame", nil, row)
    valueShell:SetSize(38, 20)
    valueShell:SetPoint("RIGHT", plusBtn, "LEFT", -4, 0)
    ns.CreateRoundedRectBorder(valueShell)
    ns.SetRoundedRectBarHeight(valueShell, 10)
    HideRoundedFrameBorder(valueShell)
    PaintControlFill(valueShell, ns.EDITBOX_INSET_FILL, 1)
    local valueText = CreateFrame("EditBox", nil, valueShell)
    valueText:SetPoint("TOPLEFT", valueShell, "TOPLEFT", 4, 0)
    valueText:SetPoint("BOTTOMRIGHT", valueShell, "BOTTOMRIGHT", -4, 0)
    valueText:SetFontObject(OPT_FONTS.GameFontHighlightSmall)
    valueText:SetJustifyH("CENTER")
    valueText:SetAutoFocus(false)
    valueText:SetNumeric(true)
    valueText:SetMaxLetters(4)
    valueShell:EnableMouse(true)
    valueShell:SetScript("OnMouseDown", function()
        if row.enabled then valueText:SetFocus() end
    end)
    local minusBtn = CreateModernButton(row, "-", 24, 20)
    minusBtn:SetPoint("RIGHT", valueShell, "LEFT", -4, 0)
    StyleStepperButton(plusBtn)
    StyleStepperButton(minusBtn)
    row.RestyleStepButtons = function()
        StyleStepperButton(plusBtn)
        StyleStepperButton(minusBtn)
    end

    local function SetValue(value)
        value = mmax(minVal, mmin(maxVal, mfloor((value or minVal) + 0.5)))
        setter(value)
        valueText:SetText(tostring(value))
    end
    local function Step(delta)
        if row.enabled then SetValue((getter() or minVal) + delta) end
    end
    minusBtn:SetScript("OnClick", function() Step(-(step or 1)) end)
    plusBtn:SetScript("OnClick", function() Step(step or 1) end)

    valueText:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    valueText:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    valueText:SetScript("OnEscapePressed", function(self)
        self._efCancelled = true
        self:ClearFocus()
    end)
    valueText:SetScript("OnEditFocusLost", function(self)
        if self._efCancelled then
            self._efCancelled = nil
            self:SetText(tostring(getter() or minVal))
            return
        end
        if row.enabled then
            SetValue(self:GetNumber())
        else
            self:SetText(tostring(getter() or minVal))
        end
        self:HighlightText(0, 0)
    end)
    Utils.ReleaseFocusOnOutsideClick(valueText)

    if tooltipText then
        row:EnableMouse(true)
        Utils.AttachDelayedTooltip(row, "ANCHOR_RIGHT", function()
            return labelText, tooltipText
        end)
    end

    row.SetValue = function(_, value)
        valueText:SetText(tostring(mmax(minVal, mmin(maxVal, mfloor((value or minVal) + 0.5)))))
    end
    row.SetGroupEnabled = function(self, enabled)
        self.enabled = enabled
        self:SetAlpha(enabled and 1.0 or 0.35)
        ApplyRowLabelColor(label, enabled, self)
        if enabled then
            minusBtn:Enable()
            plusBtn:Enable()
            valueText:Enable()
        else
            minusBtn:Disable()
            plusBtn:Disable()
            valueText:ClearFocus()
            valueText:Disable()
        end
    end
    row:SetValue(getter())
    return row
end

local function SetControlsEnabled(controls, enabled)
    for _, ctrl in ipairs(controls) do
        local objType = ctrl.GetObjectType and ctrl:GetObjectType()
        if objType == "CheckButton" then
            if enabled then ctrl:Enable() else ctrl:Disable() end
            if ctrl.Text then
                local r, g, b = enabled and 1.0 or DISABLED_TEXT[1], enabled and 1.0 or DISABLED_TEXT[2], enabled and 1.0 or DISABLED_TEXT[3]
                ctrl.Text:SetTextColor(r, g, b)
            end
            if ctrl.RefreshVisual then ctrl:RefreshVisual() end
        elseif objType == "Slider" then
            if enabled then ctrl:Enable() else ctrl:Disable() end
            if ctrl.Text then
                ctrl.Text:SetTextColor(enabled and NORMAL_TEXT[1] or DISABLED_TEXT[1], enabled and NORMAL_TEXT[2] or DISABLED_TEXT[2], enabled and NORMAL_TEXT[3] or DISABLED_TEXT[3])
            end
            if ctrl.Low then ctrl.Low:SetTextColor(enabled and 0.7 or 0.4, enabled and 0.7 or 0.4, enabled and 0.7 or 0.4) end
            if ctrl.High then ctrl.High:SetTextColor(enabled and 0.7 or 0.4, enabled and 0.7 or 0.4, enabled and 0.7 or 0.4) end
            if ctrl.valueText then ctrl.valueText:SetTextColor(enabled and 1.0 or 0.4, enabled and 1.0 or 0.4, enabled and 1.0 or 0.4) end
            if ctrl.inputBox then
                if enabled then ctrl.inputBox:Enable(); ctrl.inputBox:SetTextColor(1, 1, 1)
                else ctrl.inputBox:Disable(); ctrl.inputBox:SetTextColor(0.4, 0.4, 0.4) end
            end
            if ctrl.suffixLabel then ctrl.suffixLabel:SetTextColor(enabled and 1 or 0.4, enabled and 1 or 0.4, enabled and 1 or 0.4) end
            if ctrl.resetBtn then
                if enabled then ctrl.resetBtn:Enable() else ctrl.resetBtn:Disable() end
            end
        elseif objType == "Button" then
            if enabled then ctrl:Enable() else ctrl:Disable() end
        elseif objType == "Frame" then
            if ctrl.SetGroupEnabled then
                ctrl:SetGroupEnabled(enabled)
            else
                ctrl:SetAlpha(enabled and 1.0 or 0.35)
            end
        end
    end
end






local function BuildHomeTab(ctx)
    local CreateTab, SwitchToTab, FRAME_W = ctx.CreateTab, ctx.SwitchToTab, ctx.FRAME_W
    local FlashBindButton = ctx.FlashBindButton
    local homeTab = CreateTab(L["OPT_TAB_HOME"])
    local homeIcon = homeTab:CreateTexture(nil, "ARTWORK")
    homeIcon:SetSize(80, 80)
    homeIcon:SetPoint("TOPLEFT", homeTab, "TOPLEFT", 12, -8)
    homeIcon:SetTexture("Interface\\AddOns\\EasyFind\\textures\\Spyglass")

    local homeTitle = homeTab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalHuge)
    local titlePath, _, titleFlags = homeTitle:GetFont()
    if titlePath then homeTitle:SetFont(titlePath, 28, titleFlags) end
    homeTitle:SetPoint("LEFT", homeIcon, "RIGHT", 14, 0)
    homeTitle:SetText(L["OPT_ADDON_NAME"])
    homeTitle._efNoIndex = true

    local homeVersion = homeTab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    homeVersion:SetPoint("BOTTOMLEFT", homeTitle, "BOTTOMRIGHT", 6, 2)
    local tocVersion = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("EasyFind", "Version")
    homeVersion:SetText("v" .. (tocVersion or ""))




    local homeUpdateNotice = homeTab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    homeUpdateNotice:SetPoint("TOPLEFT", homeTitle, "BOTTOMLEFT", 1, -4)
    homeUpdateNotice:SetJustifyH("LEFT")
    local gold = ns.GOLD_COLOR
    homeUpdateNotice:SetTextColor(gold[1], gold[2], gold[3], 1)
    local function RefreshHomeUpdateNotice()
        local newer = ns.VersionCheck and ns.VersionCheck:GetAvailableVersion()
        homeUpdateNotice:SetShown(newer ~= nil)
        if newer then
            homeUpdateNotice:SetText(sformat(L["UPDATE_AVAILABLE_HINT"], newer))
        end
    end
    RefreshHomeUpdateNotice()




    local function UpdateHomeVersion()
        local pal = Look().palette
        local theme = pal and pal.light and Look().theme
        if theme and theme.pathColor then
            homeVersion:SetTextColor(theme.pathColor[1], theme.pathColor[2], theme.pathColor[3], 1)
        else
            homeVersion:SetTextColor(0.53, 0.53, 0.53, 1)
        end
    end
    UpdateHomeVersion()
    optionsFrame.UpdateHomeVersion = UpdateHomeVersion
    function Options:RefreshVersionLabel()
        RefreshHomeUpdateNotice()
    end

    local FLOW_FONT = OPT_FONTS.GameFontHighlightSmall
    local FLOW_W = FRAME_W - 24

    local homeQuick = ns.BuildFlowText(homeTab, L["OPT_HOME_QUICKSTART"], {
        width = FLOW_W,
        font = FLOW_FONT,
        textColor = { 1, 1, 1 },
        linkDispatch = {
            setbind = function()
                if ctx.bindsTabIndex then SwitchToTab(ctx.bindsTabIndex) end
                FlashBindButton()
            end,
            maptab = function()
                if ns.MapTab and ns.MapTab.Focus then ns.MapTab:Focus() end
            end,
            tutorial = OpenTutorialWizard,
        },
    })
    homeQuick:SetPoint("TOPLEFT", homeIcon, "BOTTOMLEFT", 0, -20)
    local thankYou = homeTab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    thankYou:SetPoint("BOTTOMRIGHT", homeTab, "BOTTOMRIGHT", -16, 4)
    thankYou:SetText(L["OPT_HOME_WELCOME"])
    thankYou:SetTextColor(1, 1, 1, 1)

    local function CreateURLBox(parent, url, anchor, yOff)

        local shell = CreateFrame("Frame", nil, parent)
        shell:SetSize(FRAME_W - 60, 20)
        shell:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
        SearchWell(shell)
        local box = CreateFrame("EditBox", nil, shell)
        box:SetFrameLevel(shell.ringInset:GetFrameLevel() + 2)
        box:SetPoint("TOPLEFT", shell, "TOPLEFT", 8, 0)
        box:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", -8, 0)
        box:SetAutoFocus(false)
        box:SetFontObject(SMALL_HIGHLIGHT_FONT)
        ns.ShadeText(box)
        box:SetText(url)
        box:SetCursorPosition(0)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)




        box:SetScript("OnEditFocusGained", function(self)
            self:HighlightText()
            self:RegisterEvent("GLOBAL_MOUSE_DOWN")
        end)
        box:SetScript("OnEditFocusLost", function(self)
            self:HighlightText(0, 0)
            self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        end)
        Utils.ReleaseFocusOnOutsideClick(box)
        box:SetScript("OnEvent", function(self, event)
            if event == "GLOBAL_MOUSE_DOWN" and not self:IsMouseOver() then
                self:ClearFocus()
            end
        end)
        box:SetScript("OnTextChanged", function(self) self:SetText(url); self:SetCursorPosition(0) end)
        return shell
    end

    CreateURLBox(homeTab, "https://www.curseforge.com/wow/addons/easyfind", homeQuick, -6)
end

local function BuildGeneralBindsTab(ctx)
    local CreateTab, GetCurrentKeybindText, MakeKeybindTooltip = ctx.CreateTab, ctx.GetCurrentKeybindText, ctx.MakeKeybindTooltip
    local StartCapture, SELECTOR_ROW_W, SELECTOR_BTN_W = ctx.StartCapture, ctx.SELECTOR_ROW_W, ctx.SELECTOR_BTN_W
    local sec3 = CreateTab(L["OPT_TAB_GENERAL_BINDS"])
    ctx.bindsTabIndex = sec3.tabIndex


    local function CreateSelectorRow(anchor, labelText)
        local row = CreateFrame("Frame", nil, sec3)
        row:SetSize(SELECTOR_ROW_W, 24)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
        local label = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalSmall)
        label:SetPoint("LEFT", row, "LEFT", 8, 0)
        label:SetPoint("RIGHT", row, "RIGHT", -SELECTOR_BTN_W - 18, 0)
        label:SetJustifyH("LEFT")
        label:SetTextColor(Utils.RGB(NORMAL_TEXT, 1))
        label:SetText(labelText)
        return row, label
    end

    local updateNotifyCheckbox = CreateCheckbox(sec3, "UpdateNotify", L["OPT_UPDATE_NOTIFY"],
        L["OPT_UPDATE_NOTIFY_TT"])
    updateNotifyCheckbox:SetPoint("TOPLEFT", sec3, "TOPLEFT", 8, -8)
    updateNotifyCheckbox:SetChecked(EasyFind.db.updateNotify ~= false)
    updateNotifyCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.updateNotify = self:GetChecked() and true or false
        if ns.VersionCheck then ns.VersionCheck:RefreshSurfaces() end
    end)
    optionsFrame.updateNotifyCheckbox = updateNotifyCheckbox

    local minimapBtnCheckbox = CreateCheckbox(sec3, "MinimapBtn", L["OPT_SHOW_MINIMAP_BUTTON"],
        L["OPT_MINIMAP_BTN_TT"])

    minimapBtnCheckbox:SetPoint("TOPLEFT", updateNotifyCheckbox, "BOTTOMLEFT", 0, -2)
    minimapBtnCheckbox:SetChecked(EasyFind.db.showMinimapButton ~= false)
    minimapBtnCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.showMinimapButton = self:GetChecked()
        EasyFind:UpdateMinimapButton()
    end)
    optionsFrame.minimapBtnCheckbox = minimapBtnCheckbox

    local extTipsCheckbox = CreateCheckbox(sec3, "HideExtTips", L["OPT_HIDE_EXT_TIPS"])
    extTipsCheckbox:SetPoint("TOPLEFT", minimapBtnCheckbox, "BOTTOMLEFT", 0, -2)
    extTipsCheckbox:SetChecked(EasyFind.db.hideExtensionTips == true)
    extTipsCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.hideExtensionTips = self:GetChecked() or nil
        if ns.MapTab and ns.MapTab.RefreshExtensionTip then ns.MapTab.RefreshExtensionTip() end
    end)
    optionsFrame.extTipsCheckbox = extTipsCheckbox

    local themeRow, themeLabel = CreateSelectorRow(extTipsCheckbox, L["OPT_UI_THEME"])
    local themeChoices = ns.UI_THEME_ORDER or { "Midnight" }
    local themeBtnFrame, themeBtnText = CreateFlyoutSelector(
        themeRow, "EasyFindTheme", SELECTOR_BTN_W, themeLabel,
        EasyFind.db.uiTheme or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.uiTheme) or "Midnight"
    )
    optionsFrame.themeBtnText = themeBtnText
    local defaultTheme = (ns.DB_DEFAULTS and ns.DB_DEFAULTS.uiTheme) or "Midnight"


    local function ThemeFlyoutLabel(name)
        if name == defaultTheme then return DefaultTag(name) end
        return name
    end
    local themeFlyout = CreateFlyoutPanel(themeBtnFrame, "EasyFindTheme", SELECTOR_BTN_W, #themeChoices + 1)
    local themeHover, keepTheme = HoverPreview(themeFlyout,
        function() return EasyFind.db.uiTheme or defaultTheme end,
        function(name)
            if ns.ApplyUITheme then ns.ApplyUITheme(name) end
            optionsFrame:RepaintTheme()
            if ns.RepaintWizardTheme then pcall(ns.RepaintWizardTheme) end
        end)
    local function SelectTheme(name)
        keepTheme(name)
        EasyFind.db.uiTheme = name
        themeBtnText:SetText(name)
        if ns.ApplyUITheme then ns.ApplyUITheme(name) end
        optionsFrame:RepaintTheme()

        if ns.RepaintWizardTheme then pcall(ns.RepaintWizardTheme) end
    end
    local function StyleThemeFlyoutRow(flyoutBtn, name, label)


        local swatch = label:GetParent():CreateTexture(nil, "OVERLAY")
        swatch:SetSize(13, 13)
        swatch:SetPoint("RIGHT", label:GetParent(), "RIGHT", -4, 0)
        local palette = ns.UI_THEME_PALETTES and ns.UI_THEME_PALETTES[name]
        if palette then
            swatch:SetTexture("Interface\\AddOns\\EasyFind\\textures\\FilterButtonCircle")
            swatch:SetVertexColor(ns.ThemeSwatchColor(palette))
        else
            swatch:Hide()
        end
        flyoutBtn._rightIconW = 13 + 4
    end


    local themeRows, themeImportRow
    local function RebuildThemeFlyout()
        if themeRows then
            for i = 1, #themeRows do themeRows[i]:Hide() end
        end
        local order = ns.UI_THEME_ORDER or themeChoices
        themeRows = AddFlyoutOptions(themeFlyout, order, SELECTOR_BTN_W - 6,
            SelectTheme, ThemeFlyoutLabel, StyleThemeFlyoutRow, themeHover)
        if not themeImportRow then
            themeImportRow = CreateFrame("Button", nil, themeFlyout)
            themeImportRow:SetSize(SELECTOR_BTN_W - 6, 18)
            local importBg = CreateFrame("Frame", nil, themeImportRow)
            importBg:SetAllPoints()
            importBg:EnableMouse(false)
            ns.CreateRoundedRectBorder(importBg)
            ns.SetRoundedRectBarHeight(importBg, 9)
            HideRoundedFrameBorder(importBg)
            PaintRoundedFill(importBg, 1, 1, 1, 0)
            local importLabel = themeImportRow:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
            importLabel:SetPoint("LEFT", themeImportRow, "LEFT", 6, 0)
            importLabel:SetText(L["OPT_IMPORT_THEME"])
            themeImportRow:SetScript("OnEnter", function() PaintRoundedFill(importBg, 1, 1, 1, 0.06) end)
            themeImportRow:SetScript("OnLeave", function() PaintRoundedFill(importBg, 1, 1, 1, 0) end)
            Utils.AttachDelayedTooltip(themeImportRow, "ANCHOR_RIGHT", function()
                return L["OPT_IMPORT_THEME"], L["OPT_IMPORT_THEME_TT"]
            end)
            themeImportRow:SetScript("OnClick", function()
                themeFlyout:Hide()
                ns.ThemeShare:ShowImportDialog({ onImported = function(name)
                    SelectTheme(name)
                    RebuildThemeFlyout()
                end })
            end)
        end
        themeImportRow:ClearAllPoints()
        themeImportRow:SetPoint("TOPLEFT", themeFlyout, "TOPLEFT", 3, -3 - #order * 20)
        themeImportRow:SetWidth(themeFlyout:GetWidth() - 6)
        themeFlyout:SetHeight((#order + 1) * 20 + 6)
    end
    RebuildThemeFlyout()
    optionsFrame.RebuildThemeFlyout = RebuildThemeFlyout


    local studioBtn = CreateFrame("Button", nil, themeRow)
    studioBtn:SetSize(20, 20)

    local studioExp = ns.CreateFeatureTag(themeRow, "exp", L["TAG_EXP_TITLE"], L["THEME_STUDIO_EXP_TT"], true)
    studioBtn:SetPoint("RIGHT", themeBtnFrame, "LEFT", -7 - studioExp:GetWidth(), 0)
    studioExp:SetPoint("BOTTOMLEFT", studioBtn, "RIGHT", 0, 2)
    local studioFill = studioBtn:CreateTexture(nil, "BACKGROUND")
    studioFill:SetAllPoints()
    studioFill:SetTexture("Interface\\AddOns\\EasyFind\\textures\\FilterButtonCircle")
    local studioRing = studioBtn:CreateTexture(nil, "ARTWORK")
    studioRing:SetAllPoints()
    studioRing:SetTexture("Interface\\AddOns\\EasyFind\\textures\\FilterButtonCircle")
    local STUDIO_DOT_COLORS = {
        { 0.90, 0.30, 0.30 }, { 0.35, 0.75, 0.40 }, { 0.35, 0.55, 0.95 },
    }
    for d = 1, 3 do
        local dot = studioBtn:CreateTexture(nil, "OVERLAY")
        dot:SetSize(5, 5)
        dot:SetTexture("Interface\\AddOns\\EasyFind\\textures\\FilterButtonCircle")
        local c = STUDIO_DOT_COLORS[d]
        dot:SetVertexColor(c[1], c[2], c[3], 1)
        dot:SetPoint("CENTER", studioBtn, "CENTER",
            (d == 1 and -4) or (d == 2 and 4) or 0, (d == 3 and -4) or 3)
    end
    local function PaintStudioRing()
        local ringTheme = Look().theme
        local glyph = ringTheme and ringTheme.chromeGlyph
        if glyph then
            studioRing:SetVertexColor(glyph[1], glyph[2], glyph[3], 0.35)
        else
            studioRing:SetVertexColor(1, 1, 1, 0.35)
        end
        local buttonFill = Look().BTN_FILL_NORMAL or { 0.13, 0.13, 0.14 }
        studioFill:SetVertexColor(buttonFill[1], buttonFill[2], buttonFill[3], 1)
    end
    PaintStudioRing()
    ns.RegisterThemeCallback(PaintStudioRing)
    studioBtn:SetScript("OnEnter", function(self)
        studioRing:SetAlpha(1)
        ns.ShowHintTooltip(self, "ANCHOR_TOP", nil, L["OPT_THEME_STUDIO"])
    end)
    studioBtn:SetScript("OnLeave", function(self)
        studioRing:SetAlpha(0.75)
        ns.HideHintTooltip(self)
    end)
    studioBtn:SetScript("OnClick", function()

        optionsFrame:Hide()
        ns.ThemeStudio:Open()
    end)



    local classicBgRow
    do
        local function Redress()
            optionsFrame:RepaintTheme()
            ns.SettingsRows.RedressClassic()
        end
        local bgRow = ctx.CreateFlyoutPresetRow(sec3, L["OPT_CLASSIC_BG"], ns.SettingsRows.ClassicBgChoices(),
            function() return EasyFind.db.classicArt or "marble" end,
            function(value)
                EasyFind.db.classicArt = value ~= "marble" and value or nil
                Redress()
            end, "EasyFindClassicBg", "marble", L["OPT_CLASSIC_BG_TT"], nil, true)
        bgRow:SetPoint("TOPLEFT", themeRow, "BOTTOMLEFT", 0, -8)
        classicBgRow = bgRow
        optionsFrame.classicBgRow = bgRow

        optionsFrame.UpdateClassicRows = function()
            bgRow:SetGroupEnabled(ns.ClassicLook() and true or false)
        end
        optionsFrame.UpdateClassicRows()
    end

    local indicatorRow, indicatorLabel = CreateSelectorRow(classicBgRow, L["OPT_INDICATOR_STYLE"])

    local indicatorChoices = {"EasyFind Arrow", "Chevrons", "Classic Quest Arrow", "Minimap Player Arrow", "Low-res Gauntlet", "HD Gauntlet"}
    if ns.Caps and ns.Caps.classic then table.remove(indicatorChoices) end

    local indicatorBtnFrame, indicatorBtnText = CreateFlyoutSelector(
        indicatorRow, "EasyFindIndicator", SELECTOR_BTN_W, indicatorLabel, StyleLabel(EasyFind.db.indicatorStyle or "EasyFind Arrow")
    )


    local function ApplyIndicatorIcon(tex, name)
        local info = ns.GetIndicatorStyleInfo and ns.GetIndicatorStyleInfo(name)
        if not info then tex:Hide() return end
        tex:SetTexture(info.texture)
        if info.texCoord then
            tex:SetTexCoord(unpack(info.texCoord))
        else
            tex:SetTexCoord(0, 1, 0, 1)
        end
        local rgb = ns.INDICATOR_COLORS[EasyFind.db.indicatorColor or "Yellow"]
            or ns.INDICATOR_COLORS.Yellow
        tex:SetVertexColor(Utils.RGB(rgb))
        tex:Show()
    end
    local indicatorRowIcons = {}
    local indicatorBtnIcon = indicatorBtnFrame:CreateTexture(nil, "OVERLAY")
    indicatorBtnIcon:SetSize(14, 14)



    local function SetIndicatorSelection(name)
        indicatorBtnText:SetText(StyleLabel(name))
        ApplyIndicatorIcon(indicatorBtnIcon, name)
        indicatorBtnIcon:ClearAllPoints()
        indicatorBtnIcon:SetPoint("LEFT", indicatorBtnText, "CENTER",
            (indicatorBtnText:GetStringWidth() / 2) + 5, 0)
    end
    SetIndicatorSelection(EasyFind.db.indicatorStyle or "EasyFind Arrow")
    optionsFrame.SetIndicatorSelection = SetIndicatorSelection
    local defaultIndicatorStyle = (ns.DB_DEFAULTS and ns.DB_DEFAULTS.indicatorStyle) or "EasyFind Arrow"
    local function IndicatorStyleFlyoutLabel(name)
        local label = StyleLabel(name)
        if name == defaultIndicatorStyle then label = DefaultTag(label) end
        return label
    end
    local indicatorFlyout = CreateFlyoutPanel(indicatorBtnFrame, "EasyFindIndicator", SELECTOR_BTN_W, #indicatorChoices)
    AddFlyoutOptions(indicatorFlyout, indicatorChoices, SELECTOR_BTN_W - 6, function(name)
        EasyFind.db.indicatorStyle = name
        SetIndicatorSelection(name)
        if ns.MapSearch then
            ns.MapSearch:RefreshIndicators()
        end
    end, IndicatorStyleFlyoutLabel, function(flyoutBtn, name, label)
        local icon = label:GetParent():CreateTexture(nil, "OVERLAY")
        icon:SetSize(13, 13)
        icon:SetPoint("RIGHT", label:GetParent(), "RIGHT", -4, 0)
        ApplyIndicatorIcon(icon, name)
        indicatorRowIcons[#indicatorRowIcons + 1] = { icon = icon, style = name }
        flyoutBtn._rightIconW = 13 + 4
    end)
    local function RetintIndicatorPreviews()
        SetIndicatorSelection(EasyFind.db.indicatorStyle or "EasyFind Arrow")
        for i = 1, #indicatorRowIcons do
            ApplyIndicatorIcon(indicatorRowIcons[i].icon, indicatorRowIcons[i].style)
        end
    end
    optionsFrame.indicatorBtnText = indicatorBtnText
    optionsFrame.SetIndicatorSelection = SetIndicatorSelection
    optionsFrame.RetintIndicatorPreviews = RetintIndicatorPreviews
    optionsFrame.indicatorFlyout = indicatorFlyout

    local colorRow, colorLabel = CreateSelectorRow(indicatorRow, L["OPT_INDICATOR_COLOR"])

    local colorChoices = {"Yellow", "Gold", "Orange", "Red", "Green", "Blue", "Purple", "White"}
    local colorRGB = ns.INDICATOR_COLORS

    local colorBtnFrame, colorBtnText = CreateFlyoutSelector(
        colorRow, "EasyFindColor", SELECTOR_BTN_W, colorLabel, ColorLabel(EasyFind.db.indicatorColor or "Yellow")
    )
    local currentColor = EasyFind.db.indicatorColor or "Yellow"
    local currentRGB = colorRGB[currentColor] or colorRGB.Yellow
    colorBtnText:SetTextColor(Utils.RGB(currentRGB))

    local colorFlyout = CreateFlyoutPanel(colorBtnFrame, "EasyFindColor", SELECTOR_BTN_W, #colorChoices)

    local defaultIndicatorColor = (ns.DB_DEFAULTS and ns.DB_DEFAULTS.indicatorColor) or "Yellow"
    local colorRowBtns = {}
    for i, name in ipairs(colorChoices) do
        local rgb = colorRGB[name]
        local colorBtn = CreateFrame("Button", nil, colorFlyout)
        colorBtn:SetSize(SELECTOR_BTN_W - 6, 18)
        colorBtn:SetPoint("TOPLEFT", colorFlyout, "TOPLEFT", 3, -3 - (i - 1) * 20)
        local rowBg = CreateFrame("Frame", nil, colorBtn)
        rowBg:SetAllPoints()
        rowBg:EnableMouse(false)
        ns.CreateRoundedRectBorder(rowBg)
        ns.SetRoundedRectBarHeight(rowBg, 9)
        HideRoundedFrameBorder(rowBg)
        PaintRoundedFill(rowBg, 1, 1, 1, 0)

        local label = colorBtn:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
        label:SetPoint("LEFT", colorBtn, "LEFT", 6, 0)
        label:SetPoint("RIGHT", colorBtn, "RIGHT", -6, 0)
        label:SetJustifyH("CENTER")
        label:SetText(name == defaultIndicatorColor and DefaultTag(ColorLabel(name)) or ColorLabel(name))
        label:SetTextColor(Utils.RGB(NORMAL_TEXT, 1))
        colorBtn._label = label
        colorRowBtns[i] = colorBtn

        colorBtn:SetScript("OnEnter", function(self)
            PaintRoundedFill(rowBg, 1, 1, 1, 0.06)
            label:SetTextColor(1, 1, 1)
        end)
        colorBtn:SetScript("OnLeave", function(self)
            PaintRoundedFill(rowBg, 1, 1, 1, 0)
            label:SetTextColor(Utils.RGB(NORMAL_TEXT, 1))
        end)
        colorBtn:SetScript("OnClick", function()
            EasyFind.db.indicatorColor = name
            colorBtnText:SetText(ColorLabel(name))
            colorBtnText:SetTextColor(Utils.RGB(rgb))
            colorFlyout:Hide()
            if ns.MapSearch then
                ns.MapSearch:RefreshIndicators()
            end
            if optionsFrame.RetintIndicatorPreviews then optionsFrame.RetintIndicatorPreviews() end
        end)
    end
    local colorContentW = 0
    for i = 1, #colorRowBtns do
        local label = colorRowBtns[i]._label
        local getter = label.GetUnboundedStringWidth or label.GetStringWidth
        local w = 6 + getter(label) + 6
        if w > colorContentW then colorContentW = w end
    end
    local colorRowW = mmax(SELECTOR_BTN_W - 6, mfloor(colorContentW + 0.5))
    if colorRowW > SELECTOR_BTN_W - 6 then
        for i = 1, #colorRowBtns do colorRowBtns[i]:SetWidth(colorRowW) end
        colorFlyout:SetWidth(colorRowW + 6)
    end


    local colorList = {}
    for i, name in ipairs(colorChoices) do colorList[i] = { value = name, label = ColorLabel(name) } end
    colorRow._efControl = {
        kind = "choice", choices = colorList,
        get = function() return EasyFind.db.indicatorColor or defaultIndicatorColor end,
        set = function(name)
            for i, n in ipairs(colorChoices) do
                if n == name then colorRowBtns[i]:Click() end
            end
        end,
    }

    optionsFrame.colorBtnText = colorBtnText
    optionsFrame.colorFlyout = colorFlyout



    indicatorRow:EnableMouse(true)
    Utils.AttachDelayedTooltip(indicatorRow, "ANCHOR_RIGHT", function()
        return L["OPT_INDICATOR_STYLE"], L["OPT_INDICATOR_STYLE_TT"]
    end)
    colorRow:EnableMouse(true)
    Utils.AttachDelayedTooltip(colorRow, "ANCHOR_RIGHT", function()
        return L["OPT_INDICATOR_COLOR"], L["OPT_INDICATOR_COLOR_TT"]
    end)

    local fontRow, fontLabel = CreateSelectorRow(colorRow, L["OPT_FONT"])

    local fontChoices = ns.FONT_CHOICES
    local function FontLabel(name)
        if name == "Default" then return _G["DEFAULT"] or "Default" end
        return name
    end
    local fontBtnFrame, fontBtnText = CreateFlyoutSelector(
        fontRow, "EasyFindFont", SELECTOR_BTN_W, fontLabel, FontLabel(EasyFind.db.font or "Default")
    )
    local fontFlyout = CreateFlyoutPanel(fontBtnFrame, "EasyFindFont", SELECTOR_BTN_W, #fontChoices)
    local function StyleFontChoiceRow(_, name, label)



        label._efFontPreview = true
        local path = ns.GetFontChoicePath and ns.GetFontChoicePath(name)
        if path then
            local prevPath, size, flags = label:GetFont()
            if not label:SetFont(path, size, flags) then


                label:SetFont(prevPath, size, flags)
            end
        end
    end
    local function ApplyFont(name)
        EasyFind.db.font = name
        if ns.RegisterAddonFontsIn then ns.RegisterAddonFontsIn(optionsFrame) end
        if ns.RefreshAddonFont then ns.RefreshAddonFont() end
        if ns.Search then
            if ns.Search.UpdateFontSize then ns.Search:UpdateFontSize() end
            if ns.Search.RefreshResults then ns.Search:RefreshResults() end
        end
    end
    local fontHover, keepFont = HoverPreview(fontFlyout, function() return EasyFind.db.font or "Default" end, ApplyFont)
    AddFlyoutOptions(fontFlyout, fontChoices, SELECTOR_BTN_W - 6, function(name)
        keepFont(name)
        ApplyFont(name)
        fontBtnText:SetText(FontLabel(name))
    end, FontLabel, StyleFontChoiceRow, fontHover)
    optionsFrame.fontBtnText = fontBtnText
    optionsFrame.fontFlyout = fontFlyout

    local keybindHeader = sec3:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalSmall)
    keybindHeader:SetPoint("TOPLEFT", fontRow, "BOTTOMLEFT", 8, -18)
    keybindHeader:SetText(L["OPT_KEYBINDS_HEADER"])
    keybindHeader:SetTextColor(Utils.RGB(SECTION_TITLE_TEXT, 1))

    local keybindDefs = {
        { label = L["OPT_KEYBIND_TOGGLE_SEARCH"], action = "EASYFIND_TOGGLE_FOCUS" },
        { label = L["OPT_KEYBIND_FOCUS_BAR"],     action = "EASYFIND_FOCUS_BAR",
          needsAlwaysShow = true },
        { label = L["OPT_KEYBIND_OPEN_MAP_TAB"],  action = "EASYFIND_MAP_FOCUS" },
        { label = L["OPT_KEYBIND_CLEAR_ALL"],     action = "EASYFIND_CLEAR" },
    }

    local keybindTooltips = {
        EASYFIND_TOGGLE_FOCUS = { L["OPT_KEYBIND_TOGGLE_SEARCH"], L["OPT_KB_TOGGLE_TT_DESC"] },
        EASYFIND_FOCUS_BAR    = { L["OPT_KEYBIND_FOCUS_BAR"],     L["OPT_KB_FOCUS_TT_DESC"] },
        EASYFIND_MAP_FOCUS    = { L["OPT_KEYBIND_OPEN_MAP_TAB"],  L["OPT_KB_MAP_TT_DESC"] },
        EASYFIND_CLEAR        = { L["OPT_KEYBIND_CLEAR_ALL"],     L["OPT_KB_CLEAR_TT_DESC"] },
    }

    local keybindButtons = {}
    local KEYBIND_ROW_H = 24
    local KEYBIND_BTN_W = 140
    local KEYBIND_LABEL_W = 200
    local keybindSettings = CreateSettingsGroup(sec3, SELECTOR_ROW_W, KEYBIND_ROW_H * #keybindDefs + 8)
    keybindSettings:SetPoint("TOPLEFT", keybindHeader, "BOTTOMLEFT", 0, -3)
    optionsFrame.keybindSettings = keybindSettings

    for i, def in ipairs(keybindDefs) do
        local row = i - 1

        local rowFrame = CreateFrame("Frame", nil, keybindSettings)
        rowFrame:SetSize(SELECTOR_ROW_W, KEYBIND_ROW_H)
        rowFrame:SetPoint("TOPLEFT", keybindSettings, "TOPLEFT", 0, -4 - row * KEYBIND_ROW_H)

        local rowLabel = rowFrame:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalSmall)
        rowLabel:SetPoint("LEFT", rowFrame, "LEFT", 8, 0)
        rowLabel:SetText(def.label .. ":")

        rowFrame._efControl = { kind = "keybind", action = def.action }
        rowLabel:SetTextColor(Utils.RGB(NORMAL_TEXT, 1))

        local keybindBtn = CreateModernButton(rowFrame)
        keybindBtn:SetNormalFontObject(OPT_FONTS.GameFontHighlightSmall)
        keybindBtn:SetHighlightFontObject(OPT_FONTS.GameFontHighlightSmall)
        ns.StyleBgFillButton(keybindBtn)
        keybindBtn:SetSize(KEYBIND_BTN_W, 20)
        keybindBtn:SetPoint("LEFT", rowLabel, "LEFT", KEYBIND_LABEL_W, 0)
        keybindBtn:SetText(GetCurrentKeybindText(def.action))
        keybindBtn:SetScript("OnClick", function(self, button)




            if ns._efFlyoutClosedAt and GetTime() - ns._efFlyoutClosedAt < 0.30 then
                return
            end
            if button == "RightButton" then
                EasyFind:SetAccountKeybind(def.action, nil)
                self:SetText((_G["NOT_BOUND"] or "Not Bound"))
            else
                StartCapture(self, def.action)
            end
        end)
        keybindBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local tip = keybindTooltips[def.action]
        if tip then
            MakeKeybindTooltip(keybindBtn, tip[1], tip[2])
        end

        if def.needsAlwaysShow then
            keybindBtn._efRowLabel = rowLabel


            keybindBtn:SetMotionScriptsWhileDisabled(true)
        end
        keybindButtons[def.action] = keybindBtn
    end
    optionsFrame.toggleFocusBtn = keybindButtons["EASYFIND_TOGGLE_FOCUS"]
    optionsFrame.focusBarBtn    = keybindButtons["EASYFIND_FOCUS_BAR"]
    optionsFrame.mapFocusBtn    = keybindButtons["EASYFIND_MAP_FOCUS"]
    optionsFrame.clearBtn       = keybindButtons["EASYFIND_CLEAR"]



    optionsFrame.UpdateFocusBindEnabled = function()
        local focusBtn = keybindButtons["EASYFIND_FOCUS_BAR"]
        if not focusBtn then return end
        local enabled = ns.GetVisibilityMode() == ns.VISIBILITY_ALWAYS
        focusBtn:SetEnabled(enabled)
        focusBtn:SetAlpha(enabled and 1 or 0.4)
        if focusBtn._efRowLabel then
            focusBtn._efRowLabel:SetAlpha(enabled and 1 or 0.4)
        end
    end
    optionsFrame.UpdateFocusBindEnabled()


    ctx.sec3 = sec3
end

local function BuildSearchTab(ctx)
    local CreateTab, SELECTOR_ROW_W, SELECTOR_BTN_W = ctx.CreateTab, ctx.SELECTOR_ROW_W, ctx.SELECTOR_BTN_W
    local CreateFlyoutPresetRow = ctx.CreateFlyoutPresetRow
    local sec1 = CreateTab(L["OPT_TAB_SEARCH"])


    local CHECK_COL_GAP = 8
    local CHECK_COL_W = (SELECTOR_ROW_W - CHECK_COL_GAP) / 2

    local visibilityModeRow
    local function ApplyVisibilityMode(value)
        ns.SetVisibilityMode(value)
        if visibilityModeRow then visibilityModeRow:SetValue(value) end
        RunSoon(function()
            if not ns.Search then return end
            if value == VISIBILITY_SMART then
                if ns.Search.Show then ns.Search:Show(false) end
                if ns.Search.UpdateSmartShow then ns.Search:UpdateSmartShow() end
            elseif value == VISIBILITY_ALWAYS then
                if ns.Search.UpdateSmartShow then ns.Search:UpdateSmartShow() end
                if ns.Search.Show then ns.Search:Show(false) end
            else
                if ns.Search.UpdateSmartShow then ns.Search:UpdateSmartShow() end
                if ns.Search.Hide then ns.Search:Hide() end
            end


            if Utils.RefreshEscArm then Utils.RefreshEscArm() end
            if optionsFrame.UpdateFocusBindEnabled then
                optionsFrame.UpdateFocusBindEnabled()
            end
        end)
    end

    local function SetVisibilityMode(value)
        ApplyVisibilityMode(value)
    end

    local visibilityTooltip =
        L["OPT_VISIBILITY_AUTOHIDE"] .. " - " .. L["OPT_VISIBILITY_AUTOHIDE_TT"]
        .. "\n\n" .. L["OPT_VISIBILITY_SMARTSHOW"] .. " - " .. L["OPT_VISIBILITY_SMARTSHOW_TT"]
        .. "\n\n" .. L["OPT_VISIBILITY_ALWAYS"] .. " - " .. L["OPT_VISIBILITY_ALWAYS_TT"]




    local VIS_CHOICES = { VISIBILITY_AUTO, VISIBILITY_SMART, VISIBILITY_ALWAYS }
    local function VisLabelFor(value)
        if value == VISIBILITY_SMART then return L["OPT_VISIBILITY_SMARTSHOW"] end
        if value == VISIBILITY_ALWAYS then return L["OPT_VISIBILITY_ALWAYS"] end
        return L["OPT_VISIBILITY_AUTOHIDE"]
    end

    visibilityModeRow = CreateFrame("Frame", nil, sec1)
    visibilityModeRow:SetSize(SELECTOR_ROW_W, 24)
    local visLabel = visibilityModeRow:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalSmall)
    visLabel:SetPoint("LEFT", visibilityModeRow, "LEFT", 8, 0)
    visLabel:SetPoint("RIGHT", visibilityModeRow, "RIGHT", -SELECTOR_BTN_W - 18, 0)
    visLabel:SetJustifyH("LEFT")
    visLabel:SetTextColor(Utils.RGB(NORMAL_TEXT, 1))
    visLabel:SetText(L["OPT_VISIBILITY"])

    local visBtnFrame, visBtnText = CreateFlyoutSelector(visibilityModeRow,
        "EasyFindVisibilityMode", SELECTOR_BTN_W, visLabel,
        VisLabelFor(GetVisibilityModeValue()))
    local visFlyout = CreateFlyoutPanel(visBtnFrame, "EasyFindVisibilityMode",
        SELECTOR_BTN_W, #VIS_CHOICES)




    local combatChecks = {}
    local function RefreshCombatChecks()
        local isAlways = ns.GetVisibilityMode() == VISIBILITY_ALWAYS
        for i = 1, #combatChecks do
            local line = combatChecks[i]
            local enabled = isAlways and (not line.needsCombatShown
                or EasyFind.db.combatHide == false)
            line.check:SetShown(line.getter())
            local dim = enabled and 1 or 0.4
            line.box:SetAlpha(dim)
            line.check:SetAlpha(dim)
            line.lbl:SetAlpha(dim)
            line.enabled = enabled
        end
    end

    local function PickVisibility(value)
        SetVisibilityMode(value)
        visBtnText:SetText(VisLabelFor(value))
        RefreshCombatChecks()
    end

    local COMBAT_SUB_H = 16
    AddFlyoutOptions(visFlyout, VIS_CHOICES, SELECTOR_BTN_W - 6,
        PickVisibility,
        function(value)
            if value == VISIBILITY_AUTO then return DefaultTag(VisLabelFor(value)) end
            return VisLabelFor(value)
        end,
        function(flyoutBtn, value, label)
            if value ~= VISIBILITY_ALWAYS then return end





            flyoutBtn:SetHeight(18 + COMBAT_SUB_H * 3)
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", flyoutBtn, "TOPLEFT", 6, -3)
            label:SetPoint("RIGHT", flyoutBtn, "RIGHT", -6, 0)
            local function AddCheckLine(lineText, lineTT, yOffset, opts)
                local lineBtn = CreateFrame("Button", nil, flyoutBtn)
                lineBtn:SetHeight(COMBAT_SUB_H)
                lineBtn:SetPoint("TOPLEFT", flyoutBtn, "TOPLEFT", 14, yOffset)
                local box = lineBtn:CreateTexture(nil, "ARTWORK")
                box:SetSize(12, 12)
                box:SetPoint("LEFT", lineBtn, "LEFT", 0, 0)
                box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
                box:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                local check = lineBtn:CreateTexture(nil, "OVERLAY")
                check:SetSize(12, 12)
                check:SetPoint("CENTER", box, "CENTER", 0, 0)
                check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
                check:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                local lbl = lineBtn:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
                lbl:SetPoint("LEFT", box, "RIGHT", 3, 0)
                lbl:SetText(lineText)
                lineBtn:SetWidth(12 + 3 + lbl:GetStringWidth() + 4)
                Utils.AttachDelayedTooltip(lineBtn, "ANCHOR_RIGHT", function()
                    return lineText, lineTT
                end)
                local line = {
                    box = box, check = check, lbl = lbl,
                    getter = opts.getter, needsCombatShown = opts.needsCombatShown,
                }
                lineBtn:SetScript("OnClick", function()
                    if line.needsCombatShown and EasyFind.db.combatHide ~= false
                        and ns.GetVisibilityMode() == VISIBILITY_ALWAYS then
                        return
                    end
                    opts.setter(not opts.getter())
                    PickVisibility(VISIBILITY_ALWAYS)
                end)
                combatChecks[#combatChecks + 1] = line
            end
            AddCheckLine(L["OPT_COMBAT_HIDE_SHORT"], L["OPT_COMBAT_HIDE_TT"], -18, {
                getter = function() return EasyFind.db.combatHide ~= false end,
                setter = function(v) EasyFind.db.combatHide = v and true or false end,
            })
            AddCheckLine(L["OPT_COMBAT_DIM"], L["OPT_COMBAT_DIM_TT"],
                -18 - COMBAT_SUB_H, {
                getter = function() return EasyFind.db.combatDim == true end,
                setter = function(v) EasyFind.db.combatDim = v and true or false end,
                needsCombatShown = true,
            })
            AddCheckLine(L["OPT_MOVE_DIM"], L["OPT_MOVE_DIM_TT"],
                -18 - COMBAT_SUB_H * 2, {
                getter = function() return EasyFind.db.moveDim == true end,
                setter = function(v)
                    EasyFind.db.moveDim = v and true or false
                    if ns.Search and ns.Search.UpdateMoveDim then
                        ns.Search:UpdateMoveDim()
                    end
                end,
            })
            RefreshCombatChecks()
        end)


    visFlyout:SetHeight(#VIS_CHOICES * 20 + 6 + COMBAT_SUB_H * 3)

    visibilityModeRow:EnableMouse(true)
    Utils.AttachDelayedTooltip(visibilityModeRow, "ANCHOR_RIGHT", function()
        return L["OPT_VISIBILITY"], visibilityTooltip
    end)
    Utils.AttachDelayedTooltip(visBtnFrame, "ANCHOR_RIGHT", function()
        return L["OPT_VISIBILITY"], visibilityTooltip
    end)
    visibilityModeRow.SetValue = function(_, value)
        visBtnText:SetText(VisLabelFor(value))
        RefreshCombatChecks()
    end
    optionsFrame.visibilityModeRow = visibilityModeRow

    local initialVisibility = GetVisibilityModeValue()
    ns.SetVisibilityMode(initialVisibility)
    visibilityModeRow:SetValue(initialVisibility)

    local lockPositionCheckbox = CreateCheckbox(sec1, "LockPosition", L["OPT_LOCK_POSITION"],
        L["OPT_LOCK_POSITION_TT"], true, CHECK_COL_W)
    lockPositionCheckbox:SetPoint("TOPLEFT", visibilityModeRow, "BOTTOMLEFT", 0, -2)
    lockPositionCheckbox:SetChecked(EasyFind.db.lockPosition or false)
    lockPositionCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.lockPosition = self:GetChecked()
    end)
    optionsFrame.lockPositionCheckbox = lockPositionCheckbox

    local resultsDirectionRow = CreatePresetRow(sec1, L["OPT_RESULTS_DIRECTION"],
        {
            { label = L["OPT_RESULTS_BELOW"], value = RESULTS_BELOW,
              tooltip = L["OPT_RESULTS_BELOW_TT"] },
            { label = L["OPT_RESULTS_ABOVE"], value = RESULTS_ABOVE,
              tooltip = L["OPT_RESULTS_ABOVE_TT"] },
        },
        GetResultsDirectionValue,
        function(value)
            EasyFind.db.uiResultsAbove = value == RESULTS_ABOVE
            if optionsFrame.resultsDirectionRow then
                optionsFrame.resultsDirectionRow:SetValue(value)
            end
            RunSoon(function()
                if ns.Search and ns.Search.RefreshResults then ns.Search:RefreshResults() end
            end)
        end,
        nil,
        SELECTOR_ROW_W)


    resultsDirectionRow:SetPoint("TOPLEFT", sec1, "TOPLEFT", 16, -8)
    visibilityModeRow:SetPoint("TOPLEFT", resultsDirectionRow, "BOTTOMLEFT", 0, -2)
    optionsFrame.resultsDirectionRow = resultsDirectionRow






    local resultShortcutHintsCheckbox = CreateCheckbox(sec1, "ResultShortcutHints",
        L["OPT_SHOW_ALT_HINTS"],
        L["OPT_ALT_HINTS_TT"], true, CHECK_COL_W)


    resultShortcutHintsCheckbox.Text:SetPoint("RIGHT", resultShortcutHintsCheckbox, "RIGHT", -36, 0)
    local function UpdateAltHintExample()
        local r, g, b = 255, 255, 255
        local theme = Look().theme
        if theme and theme.lightTheme and theme.chromeGlyph then
            r = mfloor(theme.chromeGlyph[1] * 255 + 0.5)
            g = mfloor(theme.chromeGlyph[2] * 255 + 0.5)
            b = mfloor(theme.chromeGlyph[3] * 255 + 0.5)
        end
        local altHintExample = (" (|TInterface\\AddOns\\EasyFind\\textures\\alt-key:16:16:0:0:128:128:0:128:0:128:%d:%d:%d|t1)"):format(r, g, b)
        ns.MakeEllipsisLabel(resultShortcutHintsCheckbox.Text, L["OPT_SHOW_ALT_HINTS"] .. altHintExample)
    end
    optionsFrame.UpdateAltHintExample = UpdateAltHintExample
    UpdateAltHintExample()
    resultShortcutHintsCheckbox:SetPoint("TOPLEFT", resultsDirectionRow, "BOTTOMLEFT", 0, -2)
    resultShortcutHintsCheckbox:SetChecked(EasyFind.db.showResultShortcutHints ~= false)
    resultShortcutHintsCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.showResultShortcutHints = self:GetChecked()
        if self.RefreshVisual then self:RefreshVisual() end
        RunSoon(function()
            if ns.Search and ns.Search.RefreshResults then ns.Search:RefreshResults() end
            if ns.ResultShortcuts and ns.ResultShortcuts.UpdateVisibleResultShortcuts then
                ns.ResultShortcuts:UpdateVisibleResultShortcuts()
            end
        end)
        RunSoon(function()
            if ns.Search and ns.Search.RefreshResults then
                ns.Search:RefreshResults()
            end
        end)
    end)
    optionsFrame.resultShortcutHintsCheckbox = resultShortcutHintsCheckbox



    local function BorderChoices()
        local t = { { label = _G["OFF"] or "Off", value = "off" }, { label = L["GPS_BORDER_LINE"], value = "line" } }
        if ns.ThemeHasChrome() then t[#t + 1] = { label = L["GPS_BORDER_IRON"], value = "iron" } end
        return t
    end
    local function BorderValue()
        if EasyFind.db.windowBorder == false then return "off" end
        if ns.ThemeHasChrome() and EasyFind.db.themeFrameArt ~= false then return "iron" end
        return "line"
    end
    local borderRow = CreateFlyoutPresetRow(sec1, L["GPS_SIZE_BORDER"], BorderChoices(), BorderValue,
        function(v)
            EasyFind.db.windowBorder = v ~= "off"
            if v ~= "off" then EasyFind.db.themeFrameArt = v == "iron" end
            RunSoon(function()
                if ns.Search and ns.Search.UpdateWindowBorders then ns.Search:UpdateWindowBorders() end

                if optionsFrame.RepaintTheme then optionsFrame:RepaintTheme() end
                if ns.RepaintWizardTheme then ns.RepaintWizardTheme() end
            end)
        end, "EasyFindBorder", nil, L["OPT_WINDOW_BORDER_TT"])
    optionsFrame.borderRow = borderRow
    optionsFrame.RefreshBorderRow = function()
        borderRow:SetChoices(BorderChoices())
        borderRow:SetValue(BorderValue())
    end


    local searchAutocompleteCheckbox = CreateCheckbox(sec1, "SearchAutocomplete",
        L["OPT_INLINE_AUTOCOMPLETE"], L["OPT_INLINE_AUTOCOMPLETE_TT"], true, CHECK_COL_W)
    searchAutocompleteCheckbox:SetChecked(EasyFind.db.searchAutocomplete ~= false)
    searchAutocompleteCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.searchAutocomplete = self:GetChecked() and true or false
        if self.RefreshVisual then self:RefreshVisual() end
        if not EasyFind.db.searchAutocomplete then
            local frame = ns.Search and ns.Search.GetSearchFrame and ns.Search:GetSearchFrame()
            local box = frame and frame.editBox
            if box and box.StripAutocomplete then box:StripAutocomplete() end
        end
    end)
    optionsFrame.searchAutocompleteCheckbox = searchAutocompleteCheckbox

    local showAppsButtonCheckbox = CreateCheckbox(sec1, "ShowAppsButton",
        L["OPT_SHOW_APPS_BUTTON"], L["OPT_SHOW_APPS_BUTTON_TT"], true, CHECK_COL_W)
    showAppsButtonCheckbox:SetChecked(EasyFind.db.showAppsButton ~= false)
    showAppsButtonCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.showAppsButton = self:GetChecked() and true or false
        if self.RefreshVisual then self:RefreshVisual() end
        RunSoon(function()
            if ns.Search and ns.Search.RefreshBarControlReveal then
                ns.Search:RefreshBarControlReveal()
            end
        end)
    end)
    optionsFrame.showAppsButtonCheckbox = showAppsButtonCheckbox

    local showFilterButtonCheckbox = CreateCheckbox(sec1, "ShowFilterButton",
        L["OPT_SHOW_FILTER_BUTTON"], L["OPT_SHOW_FILTER_BUTTON_TT"], true, CHECK_COL_W)
    showFilterButtonCheckbox:SetChecked(EasyFind.db.showFilterButton ~= false)
    showFilterButtonCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.showFilterButton = self:GetChecked() and true or false
        if self.RefreshVisual then self:RefreshVisual() end
        RunSoon(function()
            if ns.Search and ns.Search.RefreshBarControlReveal then
                ns.Search:RefreshBarControlReveal()
            end
        end)
    end)
    optionsFrame.showFilterButtonCheckbox = showFilterButtonCheckbox

    local learnPicksCheckbox = CreateCheckbox(sec1, "LearnPicks",
        L["OPT_LEARN_PICKS"], L["OPT_LEARN_PICKS_TT"], true, CHECK_COL_W)
    learnPicksCheckbox:SetChecked(EasyFind.db.learnFromPicks ~= false)
    learnPicksCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.learnFromPicks = self:GetChecked() and true or false
        if self.RefreshVisual then self:RefreshVisual() end
    end)
    optionsFrame.learnPicksCheckbox = learnPicksCheckbox

    local macroPickerSearchCheckbox = CreateCheckbox(sec1, "MacroPickerSearch",
        L["OPT_MACRO_PICKER_SEARCH"], L["OPT_MACRO_PICKER_SEARCH_TT"], true, CHECK_COL_W)
    macroPickerSearchCheckbox:SetChecked(EasyFind.db.macroPickerSearch ~= false)
    macroPickerSearchCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.macroPickerSearch = self:GetChecked() and true or false
        if self.RefreshVisual then self:RefreshVisual() end


        if not ns.IconPickerSearch and EasyFind.db.macroPickerSearch
           and ns.RequestIconSearch then
            ns.RequestIconSearch()
        end
        if ns.IconPickerSearch and ns.IconPickerSearch.Refresh then
            ns.IconPickerSearch:Refresh()
        end
    end)
    optionsFrame.macroPickerSearchCheckbox = macroPickerSearchCheckbox
    if not ns.Caps.iconSearch then macroPickerSearchCheckbox:Hide() end

    local clickSelectsCheckbox = CreateCheckbox(sec1, "ClickSelects",
        L["OPT_CLICK_SELECTS"], L["OPT_CLICK_SELECTS_TT"], true, CHECK_COL_W)
    clickSelectsCheckbox:SetChecked(EasyFind.db.clickSelectsRow == true)
    clickSelectsCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.clickSelectsRow = self:GetChecked() and true or false
        if self.RefreshVisual then self:RefreshVisual() end
    end)
    optionsFrame.clickSelectsCheckbox = clickSelectsCheckbox

    local iconVisChoices = {
        { label = L["OPT_ICONS_ALL"],      value = "all" },
        { label = L["OPT_ICONS_GENERAL"],  value = "general" },
        { label = L["OPT_ICONS_SPECIFIC"], value = "specific" },
    }
    local iconVisRow = CreateFlyoutPresetRow(sec1, L["OPT_ICON_VISIBILITY"], iconVisChoices,
        function() return EasyFind.db.iconVisibility or "all" end,
        function(value)
            EasyFind.db.iconVisibility = value
            if ns.Search and ns.Search.RefreshResults then
                ns.Search:RefreshResults()
            end
        end, "EasyFindIconVis", "all")
    iconVisRow:SetPoint("TOPLEFT", visibilityModeRow, "BOTTOMLEFT", 0, -4)

    local fontSizeChoices = {
        { label = L["OPT_FONT_SMALL"], value = 0.80 },
        { label = L["OPT_FONT_MED"],   value = 0.90 },
        { label = L["OPT_FONT_LARGE"], value = 1.15 },
        { label = L["OPT_FONT_XL"],    value = 1.35 },
    }
    local uiFontPresetRow = CreateFlyoutPresetRow(sec1, L["OPT_FONT_SIZE"], fontSizeChoices,
        function() return EasyFind.db.fontSize or ns.DEFAULT_FONT_SIZE end,
        function(value)
            EasyFind.db.fontSize = value
            if ns.Search and ns.Search.UpdateFontSize then
                ns.Search:UpdateFontSize()
            end
        end, "EasyFindFontSize", ns.DEFAULT_FONT_SIZE, L["OPT_FONT_SIZE_TT"])
    uiFontPresetRow:SetPoint("TOPLEFT", iconVisRow, "BOTTOMLEFT", 0, -4)
    optionsFrame.uiFontPresetRow = uiFontPresetRow



    local scaleChoices = {
        { label = "50%",  value = 0.5  }, { label = "75%",  value = 0.75 },
        { label = "100%", value = 1.0  }, { label = "125%", value = 1.25 },
        { label = "150%", value = 1.5  },
    }
    local scaleRow = CreateFlyoutPresetRow(sec1, L["OPT_SEARCH_SCALE"], scaleChoices,
        function() return EasyFind.db.uiSearchScale or 1.0 end,
        function(value)
            EasyFind.db.uiSearchScale = value


            EasyFind.db.uiResultsScale = 1.0
            if ns.Search and ns.Search.UpdateScale then ns.Search:UpdateScale() end
        end, "EasyFindSearchScale", 1.0, L["OPT_SEARCH_SCALE_TT"])
    scaleRow:SetPoint("TOPLEFT", uiFontPresetRow, "BOTTOMLEFT", 0, -4)
    optionsFrame.searchScaleRow = scaleRow




    do
        local flyout = scaleRow.flyout
        local resizeRow = CreateFrame("Button", nil, flyout)
        resizeRow:SetSize(SELECTOR_BTN_W - 6, 18)
        resizeRow:SetPoint("TOPLEFT", flyout, "TOPLEFT", 3, -3 - #scaleChoices * 20)
        local resizeBg = CreateFrame("Frame", nil, resizeRow)
        resizeBg:SetAllPoints()
        resizeBg:EnableMouse(false)
        ns.CreateRoundedRectBorder(resizeBg)
        ns.SetRoundedRectBarHeight(resizeBg, 9)
        HideRoundedFrameBorder(resizeBg)
        PaintRoundedFill(resizeBg, 1, 1, 1, 0)
        local resizeLabel = resizeRow:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
        resizeLabel:SetPoint("LEFT", resizeRow, "LEFT", 6, 0)
        resizeLabel:SetText(L["OPT_RESIZE_UI_SEARCH"])
        local widthGetter = resizeLabel.GetUnboundedStringWidth or resizeLabel.GetStringWidth
        local neededW = 6 + widthGetter(resizeLabel) + 12
        if neededW > flyout:GetWidth() then flyout:SetWidth(neededW) end
        resizeRow:SetWidth(flyout:GetWidth() - 6)
        resizeRow:SetScript("OnEnter", function() PaintRoundedFill(resizeBg, 1, 1, 1, 0.06) end)
        resizeRow:SetScript("OnLeave", function() PaintRoundedFill(resizeBg, 1, 1, 1, 0) end)
        Utils.AttachDelayedTooltip(resizeRow, "ANCHOR_RIGHT", function()
            return L["OPT_RESIZE_UI_SEARCH"], L["OPT_RESIZE_UI_TT"]
        end)
        resizeRow:SetScript("OnClick", function()
            flyout:Hide()
            if ns.Rescaler then ns.Rescaler:Enter("ui") end
        end)
        flyout:SetHeight(#scaleChoices * 20 + 6 + 20)
    end




    local resultRowsChoices = {}
    for i = ns.RESULT_ROWS_MIN, ns.RESULT_ROWS_MAX do
        resultRowsChoices[#resultRowsChoices + 1] = { label = tostring(i), value = i }
    end
    local resultRowsRow = CreateFlyoutPresetRow(sec1, L["OPT_RESULT_ROWS"], resultRowsChoices,
        function() return EasyFind.db.uiResultsRows or 6 end,
        function(value)
            EasyFind.db.uiResultsRows = value
            RunSoon(function()
                if ns.Search and ns.Search.RefreshResults then ns.Search:RefreshResults() end
            end)
        end, "EasyFindResultRows", 6, L["OPT_RESULT_ROWS_TT"])
    resultRowsRow:SetPoint("TOPLEFT", scaleRow, "BOTTOMLEFT", 0, -4)
    optionsFrame.resultRowsRow = resultRowsRow



    local searchOpacityRow = CreateStepperRow(sec1, L["OPT_SEARCH_OPACITY"], 50, 100,
        function() return mfloor((EasyFind.db.searchWindowOpacity or ns.SEARCH_WINDOW_ALPHA) * 100 + 0.5) end,
        function(value)
            EasyFind.db.searchWindowOpacity = value / 100
            RunSoon(function()
                if ns.Search and ns.Search.UpdateOpacity then ns.Search:UpdateOpacity() end
            end)
        end, L["OPT_SEARCH_OPACITY_TT"], SELECTOR_ROW_W)
    searchOpacityRow:SetPoint("TOPLEFT", resultRowsRow, "BOTTOMLEFT", 0, -4)
    optionsFrame.searchOpacityRow = searchOpacityRow





    local wowheadValues, wowheadLabelByValue = {}, {}
    for _, entry in ipairs(ns.WOWHEAD_LOCALES) do
        wowheadValues[#wowheadValues + 1] = entry.value
        wowheadLabelByValue[entry.value] = entry.label
    end
    local function WowheadLocaleLabel(v)
        if v == "auto" then return L["WOWHEAD_LOCALE_AUTO"] end
        return wowheadLabelByValue[v] or v
    end

    local wowheadRow = CreateFrame("Frame", nil, sec1)
    wowheadRow:SetSize(SELECTOR_ROW_W, 24)


    wowheadRow:SetPoint("TOPLEFT", resultRowsRow, "BOTTOMLEFT", 0, -4)
    searchOpacityRow:ClearAllPoints()
    borderRow:SetPoint("TOPLEFT", wowheadRow, "BOTTOMLEFT", 0, -4)
    searchOpacityRow:SetPoint("TOPLEFT", borderRow, "BOTTOMLEFT", 0, -4)
    local wowheadRowLabel = wowheadRow:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalSmall)
    wowheadRowLabel:SetPoint("LEFT", wowheadRow, "LEFT", 8, 0)
    wowheadRowLabel:SetPoint("RIGHT", wowheadRow, "RIGHT", -SELECTOR_BTN_W - 18, 0)
    wowheadRowLabel:SetJustifyH("LEFT")
    wowheadRowLabel:SetTextColor(Utils.RGB(NORMAL_TEXT, 1))
    wowheadRowLabel:SetText(L["OPT_WOWHEAD_LOCALE"])

    local wowheadBtnFrame, wowheadBtnText = CreateFlyoutSelector(
        wowheadRow, "EasyFindWowhead", SELECTOR_BTN_W, wowheadRowLabel,
        WowheadLocaleLabel(EasyFind.db.wowheadLocale or "auto")
    )
    local function WowheadFlyoutLabel(v)
        if v == "auto" then
            return DefaultTag(WowheadLocaleLabel(v))
        end
        return WowheadLocaleLabel(v)
    end
    local wowheadFlyout = CreateFlyoutPanel(wowheadBtnFrame, "EasyFindWowhead", SELECTOR_BTN_W, #wowheadValues)
    AddFlyoutOptions(wowheadFlyout, wowheadValues, SELECTOR_BTN_W - 6, function(value)
        EasyFind.db.wowheadLocale = value
        wowheadBtnText:SetText(WowheadLocaleLabel(value))
    end, WowheadFlyoutLabel)
    optionsFrame.wowheadBtnText = wowheadBtnText
    optionsFrame.SetWowheadSelection = function(value)
        wowheadBtnText:SetText(WowheadLocaleLabel(value))
    end
    optionsFrame.wowheadFlyout = wowheadFlyout
    wowheadRow:EnableMouse(true)
    Utils.AttachDelayedTooltip(wowheadRow, "ANCHOR_RIGHT", function()
        return L["OPT_WOWHEAD_LOCALE"], L["OPT_WOWHEAD_LOCALE_TT"]
    end)
    Utils.AttachDelayedTooltip(wowheadBtnFrame, "ANCHOR_RIGHT", function()
        return L["OPT_WOWHEAD_LOCALE"], L["OPT_WOWHEAD_LOCALE_TT"]
    end)

    optionsFrame:HookScript("OnShow", function(self)
        if ns.RegisterAddonFontsIn then ns.RegisterAddonFontsIn(self) end
    end)

    lockPositionCheckbox:ClearAllPoints()


    lockPositionCheckbox:SetPoint("TOPLEFT", searchOpacityRow, "BOTTOMLEFT", 0, -4)
    resultShortcutHintsCheckbox:ClearAllPoints()
    resultShortcutHintsCheckbox:SetPoint("TOPLEFT", lockPositionCheckbox, "TOPRIGHT", CHECK_COL_GAP, 0)
    showAppsButtonCheckbox:SetPoint("TOPLEFT", lockPositionCheckbox, "BOTTOMLEFT", 0, -2)
    showFilterButtonCheckbox:SetPoint("TOPLEFT", showAppsButtonCheckbox, "TOPRIGHT", CHECK_COL_GAP, 0)
    learnPicksCheckbox:SetPoint("TOPLEFT", showAppsButtonCheckbox, "BOTTOMLEFT", 0, -2)
    macroPickerSearchCheckbox:SetPoint("TOPLEFT", learnPicksCheckbox, "TOPRIGHT", CHECK_COL_GAP, 0)
    searchAutocompleteCheckbox:SetPoint("TOPLEFT", learnPicksCheckbox, "BOTTOMLEFT", 0, -2)
    clickSelectsCheckbox:SetPoint("TOPLEFT", searchAutocompleteCheckbox, "TOPRIGHT", CHECK_COL_GAP, 0)

    local function RefreshUIPresetRows()
        if optionsFrame.uiFontPresetRow then
            optionsFrame.uiFontPresetRow:SetValue(EasyFind.db.fontSize or ns.DEFAULT_FONT_SIZE)
        end
    end
    optionsFrame.RefreshUIPresetRows = RefreshUIPresetRows



    local SEARCH_RESET_BTN_W = 124
    local resetUIBtn = CreateModernButton(sec1)
    resetUIBtn:SetSize(SEARCH_RESET_BTN_W, 20)
    resetUIBtn:SetPoint("LEFT", sec1, "LEFT", 16, 0)


    resetUIBtn:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, 10)
    optionsFrame.resetButtons = optionsFrame.resetButtons or {}
    optionsFrame.resetButtons[#optionsFrame.resetButtons + 1] = resetUIBtn
    resetUIBtn:SetText(L["OPT_RESET_SETTINGS"])
    resetUIBtn:SetScript("OnClick", function()
        ShowResetConfirm(L["POPUP_RESET_UI_SEARCH_SETTINGS"], function() Options:DoResetUI() end)
    end)

    local resetUIPosBtn = CreateModernButton(sec1)
    resetUIPosBtn:SetSize(SEARCH_RESET_BTN_W, 20)
    resetUIPosBtn:SetPoint("LEFT", resetUIBtn, "RIGHT", 8, 0)
    resetUIPosBtn:SetText(L["OPT_RESET_POSITIONS"])
    resetUIPosBtn:SetScript("OnClick", function()
        ShowResetConfirm(L["POPUP_RESET_UI_SEARCH_POSITIONS"], function() Options:DoResetUIPositions() end)
    end)




    local forgetLearnedBtn = CreateModernButton(sec1)
    forgetLearnedBtn:SetSize(SEARCH_RESET_BTN_W, 20)
    forgetLearnedBtn:SetPoint("LEFT", resetUIPosBtn, "RIGHT", 8, 0)
    forgetLearnedBtn:SetText(L["OPT_FORGET_LEARNED"])
    forgetLearnedBtn:SetScript("OnClick", function()
        ns.ShowThemedDialog({
            text = L["POPUP_FORGET_LEARNED"],
            messageColor = ns.GOLD_COLOR,
            acceptText = _G["DELETE"] or "Delete",
            onAccept = function()
                if ns.Learned then ns.Learned:ClearAll() end
            end,
        })
    end)
    Utils.AttachDelayedTooltip(forgetLearnedBtn, "ANCHOR_TOP", function()
        return L["OPT_FORGET_LEARNED"], L["OPT_FORGET_LEARNED_TT"]
    end)
    ns.FitButtonRow({ resetUIBtn, resetUIPosBtn, forgetLearnedBtn }, ctx.FRAME_W - 24, 8, SEARCH_RESET_BTN_W)

end

local function BuildMapTab(ctx)
    local CreateTab, FRAME_W, COL_LEFT = ctx.CreateTab, ctx.FRAME_W, ctx.COL_LEFT
    local RESET_BTN_W = ctx.RESET_BTN_W
    local sec2 = CreateTab(L["OPT_TAB_MAP"])

    local mapEnableCheckbox = CreateCheckbox(sec2, "EnableMap", L["OPT_ENABLE_MAP_MODULE"],
        L["OPT_ENABLE_MAP_TT"],
        false, 222)
    mapEnableCheckbox:SetPoint("TOPLEFT", sec2, "TOPLEFT", COL_LEFT, -6)
    mapEnableCheckbox:SetChecked(EasyFind.db.enableMapSearch ~= false)

    local mapControls = {}
    local function UpdateMapToggleVisual()
        local enabled = EasyFind.db.enableMapSearch ~= false
        mapEnableCheckbox:SetChecked(enabled)
        SetControlsEnabled(mapControls, enabled)
        if optionsFrame.UpdateRecentCountEnabled then optionsFrame.UpdateRecentCountEnabled() end
    end
    optionsFrame.UpdateMapToggleVisual = UpdateMapToggleVisual


    mapEnableCheckbox:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        ns.SettingsRows.SetMapEnabled(on)
        if not on then self:SetChecked(true) end
    end)

    local mapSep = sec2:CreateTexture(nil, "ARTWORK")
    mapSep:SetPoint("TOPLEFT", sec2, "TOPLEFT", 6, -40)
    mapSep:SetPoint("RIGHT", sec2, "RIGHT", -6, 0)
    mapSep:SetHeight(1)


    local function RestyleMapSep()
        local theme = Look().theme
        local sep = theme and theme.lightTheme and theme.separatorColor
        if sep then
            mapSep:SetColorTexture(sep[1], sep[2], sep[3], 0.8)
        else
            mapSep:SetColorTexture(0.8, 0.65, 0.0, 0.6)
        end
    end
    RestyleMapSep()
    optionsFrame.RestyleMapSep = RestyleMapSep

    local GROUP_W = FRAME_W - 16
    local ROW_H = 28

    local mapTabLabel = sec2:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalSmall)
    mapTabLabel:SetPoint("TOPLEFT", sec2, "TOPLEFT", 8, -48)
    mapTabLabel:SetText(L["OPT_MAP_TAB_SECTION"])
    mapTabLabel:SetTextColor(Utils.RGB(SECTION_TITLE_TEXT, 1))

    local mapTabSettings = CreateSettingsGroup(sec2, GROUP_W, ROW_H * 4 + 8)
    mapTabSettings:SetPoint("TOPLEFT", mapTabLabel, "BOTTOMLEFT", 0, -3)
    optionsFrame.mapTabSettings = mapTabSettings

    local mapTabShowRecentCheckbox = CreateCheckbox(mapTabSettings, "MapTabShowRecent", L["OPT_SHOW_RECENT_SEARCHES"],
        L["OPT_SHOW_RECENT_TT"], false, GROUP_W)
    mapTabShowRecentCheckbox:SetPoint("TOPLEFT", mapTabSettings, "TOPLEFT", 0, -4)
    mapTabShowRecentCheckbox:SetChecked(EasyFind.db.mapTabShowRecent ~= false)
    optionsFrame.mapTabShowRecentCheckbox = mapTabShowRecentCheckbox

    local recentCountStepper = CreateStepperRow(mapTabSettings, L["OPT_RECENT_COUNT"], 1, 10,
        function() return EasyFind.db.mapTabRecentCount or 3 end,
        function(value)
            EasyFind.db.mapTabRecentCount = value
            local list = EasyFind.db.mapTabRecentSearches
            if list then
                while #list > value do table.remove(list) end
            end
            if ns.MapTab and ns.MapTab.RefreshIfOpen then ns.MapTab:RefreshIfOpen() end
        end,
        L["OPT_RECENT_COUNT_TT"], GROUP_W)
    recentCountStepper:SetPoint("TOPLEFT", mapTabShowRecentCheckbox, "BOTTOMLEFT", 0, 0)
    optionsFrame.recentCountStepper = recentCountStepper

    local mapAutocompleteCheckbox = CreateCheckbox(mapTabSettings, "MapTabAutocomplete",
        L["OPT_INLINE_AUTOCOMPLETE"], L["OPT_INLINE_AUTOCOMPLETE_TT"], false, GROUP_W)
    mapAutocompleteCheckbox:SetPoint("TOPLEFT", recentCountStepper, "BOTTOMLEFT", 0, 0)
    mapAutocompleteCheckbox:SetChecked(EasyFind.db.mapTabAutocomplete ~= false)
    mapAutocompleteCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.mapTabAutocomplete = self:GetChecked() and true or false
        if self.RefreshVisual then self:RefreshVisual() end
        if not EasyFind.db.mapTabAutocomplete then
            local box = ns.MapTab and ns.MapTab.searchBox
            if box and box.StripAutocomplete then box:StripAutocomplete() end
        end
    end)
    optionsFrame.mapAutocompleteCheckbox = mapAutocompleteCheckbox

    local mapShowParentsCheckbox = CreateCheckbox(mapTabSettings, "MapTabShowParents",
        L["MAP_SHOW_PARENTS"], L["MAP_SHOW_PARENTS_TT"], false, GROUP_W)
    mapShowParentsCheckbox:SetPoint("TOPLEFT", mapAutocompleteCheckbox, "BOTTOMLEFT", 0, 0)
    mapShowParentsCheckbox:SetChecked(EasyFind.db.mapTabShowParents ~= false)
    mapShowParentsCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.mapTabShowParents = self:GetChecked() and true or false
        if self.RefreshVisual then self:RefreshVisual() end
        if ns.MapTab and ns.MapTab.RefreshIfOpen then ns.MapTab:RefreshIfOpen() end
    end)
    optionsFrame.mapShowParentsCheckbox = mapShowParentsCheckbox

    local function UpdateRecentCountEnabled()
        recentCountStepper:SetGroupEnabled(EasyFind.db.enableMapSearch ~= false and EasyFind.db.mapTabShowRecent ~= false)
    end
    optionsFrame.UpdateRecentCountEnabled = UpdateRecentCountEnabled
    mapTabShowRecentCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.mapTabShowRecent = self:GetChecked()
        if self.RefreshVisual then self:RefreshVisual() end
        UpdateRecentCountEnabled()
        RunSoon(function()
            if ns.MapTab and ns.MapTab.RefreshIfOpen then ns.MapTab:RefreshIfOpen() end
        end)
    end)
    UpdateRecentCountEnabled()

    mapTabSettings:AddControl(mapTabShowRecentCheckbox)
    mapTabSettings:AddControl(recentCountStepper)

    local mapIconsLabel = sec2:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalSmall)
    mapIconsLabel:SetPoint("TOPLEFT", mapTabSettings, "BOTTOMLEFT", 0, -6)
    mapIconsLabel:SetText(L["OPT_EF_MAP_ICONS_SECTION"])
    mapIconsLabel:SetTextColor(Utils.RGB(SECTION_TITLE_TEXT, 1))

    local mapIconSettings = CreateSettingsGroup(sec2, GROUP_W, ROW_H * 6 + 8)
    mapIconSettings:SetPoint("TOPLEFT", mapIconsLabel, "BOTTOMLEFT", 0, -3)
    optionsFrame.mapIconSettings = mapIconSettings

    local pinStyleChoices = {
        { label = L["OPT_PIN_GLOW"], value = "glow" },
        { label = L["OPT_PIN_BOX"],  value = "box" },
        { label = _G["NONE"] or "None", value = "off" },
    }
    local mapPinStyleRow = CreatePresetRow(mapIconSettings, L["OPT_PIN_HIGHLIGHT"], pinStyleChoices,
        function() return EasyFind.db.mapPinStyle or "glow" end,
        function(value)
            EasyFind.db.mapPinStyle = value
            if ns.MapSearch and ns.MapSearch.UpdatePinHighlight then ns.MapSearch:UpdatePinHighlight() end
        end,
        L["OPT_PIN_HIGHLIGHT_TT"], GROUP_W)
    optionsFrame.mapPinStyleRow = mapPinStyleRow

    local blinkingPinsCheckbox = CreateCheckbox(mapIconSettings, "BlinkingPins", L["OPT_BLINKING"],
        L["OPT_BLINKING_TT"], false, GROUP_W)
    blinkingPinsCheckbox:SetPoint("TOPLEFT", mapIconSettings, "TOPLEFT", 0, -4)
    blinkingPinsCheckbox:SetChecked(EasyFind.db.blinkingPins or false)
    blinkingPinsCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.blinkingPins = self:GetChecked()
        if self.RefreshVisual then self:RefreshVisual() end
        RunSoon(function()
            if ns.MapSearch and ns.MapSearch.UpdateBlinkingPins then ns.MapSearch:UpdateBlinkingPins() end
        end)
    end)
    optionsFrame.blinkingPinsCheckbox = blinkingPinsCheckbox

    local iconSizeChoices = {
        { label = L["OPT_FONT_SMALL"], value = 0.65 },
        { label = L["OPT_FONT_MED"],   value = 0.80 },
        { label = L["OPT_FONT_LARGE"], value = 1.05 },
        { label = L["OPT_FONT_XL"],    value = 1.30 },
    }
    local mapIconPresetRow = CreatePresetRow(mapIconSettings, L["OPT_ICON_SIZE"], iconSizeChoices,
        function() return EasyFind.db.iconScale or 0.8 end,
        function(value)
            EasyFind.db.iconScale = value
            if ns.MapSearch and ns.MapSearch.UpdateIconScales then
                ns.MapSearch:UpdateIconScales()
            end
            local uiInd = _G["EasyFindIndicatorFrame"]
            if uiInd then
                uiInd:SetScale(EasyFind.db.iconScale or 0.8)
            end
        end,
        L["OPT_ICON_SIZE_TT"], GROUP_W)
    optionsFrame.mapIconPresetRow = mapIconPresetRow

    mapIconSettings:AddControl(blinkingPinsCheckbox)




    local rareTrackCheckbox = CreateCheckbox(mapIconSettings, "RareTrack", L["OPT_AUTO_TRACK_RARES"],
        L["OPT_AUTO_TRACK_RARES_TT"], false, GROUP_W)
    rareTrackCheckbox:SetPoint("TOPLEFT", blinkingPinsCheckbox, "BOTTOMLEFT", 0, 0)
    rareTrackCheckbox:SetChecked(EasyFind.db.alwaysShowRares or false)
    rareTrackCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.alwaysShowRares = self:GetChecked()
        if self.RefreshVisual then self:RefreshVisual() end
        RunSoon(function()
            if ns.MapSearch then
                ns.MapSearch:UpdateRareTracking()
                if ns.MapSearch.UpdateAutoTrackLabel then
                    ns.MapSearch:UpdateAutoTrackLabel()
                end
            end
        end)
    end)
    optionsFrame.rareTrackCheckbox = rareTrackCheckbox

    local autoTrackPinsCheckbox = CreateCheckbox(mapIconSettings, "AutoTrackPins", L["OPT_AUTO_TRACK_MAP_PINS"],
        L["OPT_AUTO_TRACK_PINS_TT"], false, GROUP_W)
    autoTrackPinsCheckbox:SetPoint("TOPLEFT", rareTrackCheckbox, "BOTTOMLEFT", 0, 0)
    autoTrackPinsCheckbox:SetChecked(EasyFind.db.autoTrackPins ~= false)
    autoTrackPinsCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.autoTrackPins = self:GetChecked()
    end)
    optionsFrame.autoTrackPinsCheckbox = autoTrackPinsCheckbox

    local autoPinClearCheckbox = CreateCheckbox(mapIconSettings, "AutoPinClear", L["OPT_AUTO_CLEAR_MAP_PINS"],
        L["OPT_AUTO_PIN_CLEAR_TT"], false, GROUP_W)
    autoPinClearCheckbox:SetPoint("TOPLEFT", autoTrackPinsCheckbox, "BOTTOMLEFT", 0, 0)
    autoPinClearCheckbox:SetChecked(EasyFind.db.autoPinClear ~= false)
    autoPinClearCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.autoPinClear = self:GetChecked()
    end)
    optionsFrame.autoPinClearCheckbox = autoPinClearCheckbox

    mapIconSettings:AddControl(rareTrackCheckbox)
    mapIconSettings:AddControl(autoTrackPinsCheckbox)
    mapIconSettings:AddControl(autoPinClearCheckbox)


    local lastCheckbox = autoPinClearCheckbox
    if ns.MapSearch and ns.MapSearch.HasGameWaypoint then
        local waypointOnlyCheckbox = CreateCheckbox(mapIconSettings, "MapWaypointOnly", L["OPT_MAP_WAYPOINT_ONLY"],
            L["OPT_MAP_WAYPOINT_ONLY_TT"], false, GROUP_W)
        waypointOnlyCheckbox:SetPoint("TOPLEFT", autoPinClearCheckbox, "BOTTOMLEFT", 0, 0)
        waypointOnlyCheckbox:SetChecked(EasyFind.db.mapWaypointOnly == true)
        waypointOnlyCheckbox:SetScript("OnClick", function(self)
            EasyFind.db.mapWaypointOnly = self:GetChecked() or nil
        end)
        optionsFrame.waypointOnlyCheckbox = waypointOnlyCheckbox
        mapIconSettings:AddControl(waypointOnlyCheckbox)
        lastCheckbox = waypointOnlyCheckbox
    end


    mapPinStyleRow:SetPoint("TOPLEFT", lastCheckbox, "BOTTOMLEFT", 0, 0)
    mapIconSettings:AddControl(mapPinStyleRow)
    mapIconPresetRow:SetPoint("TOPLEFT", mapPinStyleRow, "BOTTOMLEFT", 0, 0)
    mapIconSettings:AddControl(mapIconPresetRow)

    local resetMapBtn = CreateModernButton(sec2)
    resetMapBtn:SetSize(RESET_BTN_W, 20)
    resetMapBtn:SetPoint("TOPRIGHT", sec2, "TOPRIGHT", -8, -8)
    resetMapBtn:SetText(L["OPT_RESET_SETTINGS"])
    resetMapBtn:SetScript("OnClick", function()
        ShowResetConfirm(L["POPUP_RESET_MAP_SEARCH_SETTINGS"], function() Options:DoResetMap() end)
    end)

    mapControls = {
        resetMapBtn, mapTabSettings, mapIconSettings
    }
    UpdateMapToggleVisual()

end

local function BuildShortcutsTab(ctx)
    local CreateTab, FRAME_W = ctx.CreateTab, ctx.FRAME_W
    local sec4 = CreateTab(L["OPT_TAB_SHORTCUTS"])

    local shortcutText = sec4:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    shortcutText:SetPoint("TOPLEFT", sec4, "TOPLEFT", 8, -8)
    shortcutText:SetWidth(FRAME_W - 60)
    shortcutText:SetJustifyH("LEFT")
    shortcutText:SetSpacing(2)




    local function UpdateShortcutColors()
        local body = L["OPT_SHORTCUTS_TEXT"]
        local theme = Look().theme
        if theme and theme.lightTheme then
            local acc = theme.pathColorHover or theme.leafColor
            local accHex = ("%02X%02X%02X"):format(
                mfloor(acc[1] * 255 + 0.5), mfloor(acc[2] * 255 + 0.5), mfloor(acc[3] * 255 + 0.5))
            body = body:gsub("|cFFFFD100", "|cFF" .. accHex):gsub("|cFF00FF00", "|cFF0E6B2D")
        end
        shortcutText:SetText(body)
    end
    optionsFrame.UpdateShortcutColors = UpdateShortcutColors
    UpdateShortcutColors()

end

local function BuildAliasesTab(ctx)
    local CreateTab, FRAME_W, RESET_BTN_W = ctx.CreateTab, ctx.FRAME_W, ctx.RESET_BTN_W
    local sec3 = ctx.sec3
    local aliasesTab = CreateTab(L["OPT_TAB_ALIASES"])
    Options._aliasesTabIndex = aliasesTab.tabIndex

    local aliasTitle = aliasesTab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormal)
    aliasTitle:SetPoint("TOPLEFT", aliasesTab, "TOPLEFT", 8, -8)
    aliasTitle:SetText(L["OPT_SAVED_ALIASES"])

    local aliasHeader = aliasesTab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    aliasHeader:SetPoint("TOPLEFT", aliasTitle, "BOTTOMLEFT", 0, -6)
    aliasHeader:SetPoint("RIGHT", aliasesTab, "RIGHT", -10, 0)
    aliasHeader:SetJustifyH("LEFT")
    aliasHeader:SetText(L["OPT_ALIASES_EMPTY_HINT"])

    local RefreshAliasList
    local aliasTools = CreateFrame("Frame", nil, aliasesTab)
    aliasTools:SetPoint("TOPLEFT", aliasHeader, "BOTTOMLEFT", 0, -8)
    aliasTools:SetPoint("RIGHT", aliasesTab, "RIGHT", -8, 0)
    aliasTools:SetHeight(24)

    local clearAliasesBtn = CreateModernButton(aliasTools, L["OPT_CLEAR_ALL_BTN"], 78, 22)
    Options:AddAction("aliasesClear", clearAliasesBtn)
    clearAliasesBtn:SetPoint("RIGHT", aliasTools, "RIGHT", 0, 0)

    local aliasSearchShell = CreateFrame("Frame", nil, aliasTools)
    aliasSearchShell:SetPoint("LEFT", aliasTools, "LEFT", 0, 0)
    aliasSearchShell:SetPoint("RIGHT", clearAliasesBtn, "LEFT", -8, 0)
    aliasSearchShell:SetHeight(22)
    SearchWell(aliasSearchShell)

    local aliasSearchIcon = aliasSearchShell.ringInset:CreateTexture(nil, "OVERLAY")
    aliasSearchIcon:SetSize(13, 13)
    aliasSearchIcon:SetPoint("LEFT", aliasSearchShell, "LEFT", 7, 0)
    aliasSearchIcon:SetAtlas("common-search-magnifyingglass")

    local aliasSearchBox = CreateFrame("EditBox", nil, aliasSearchShell)
    Utils.ReleaseFocusOnOutsideClick(aliasSearchBox)
    aliasSearchBox:SetFrameLevel(aliasSearchShell.ringInset:GetFrameLevel() + 2)
    aliasSearchBox:SetPoint("LEFT", aliasSearchIcon, "RIGHT", 6, 0)
    aliasSearchBox:SetPoint("RIGHT", aliasSearchShell, "RIGHT", -8, 0)
    aliasSearchBox:SetHeight(18)
    aliasSearchBox:SetAutoFocus(false)


    optionsFrame.ShowInAliasTable = function(text)
        ctx.SwitchToTab(aliasesTab.tabIndex)
        aliasSearchBox:SetText(text or "")
        if RefreshAliasList then RefreshAliasList() end
    end
    aliasSearchBox:SetFontObject(SMALL_HIGHLIGHT_FONT)
    aliasSearchBox:SetMaxLetters(64)

    local aliasSearchPlaceholder = aliasSearchBox:CreateFontString(nil, "ARTWORK", OPT_FONTS.GameFontDisableSmall)
    aliasSearchPlaceholder:SetPoint("LEFT", aliasSearchBox, "LEFT", 0, 0)
    aliasSearchPlaceholder:SetText(L["OPT_SEARCH_ALIASES_PLACEHOLDER"])
    Utils.StyleSearchHint(aliasSearchPlaceholder, aliasSearchIcon)
    aliasSearchBox.placeholder = aliasSearchPlaceholder
    aliasSearchBox:SetScript("OnTextChanged", function(self)
        aliasSearchPlaceholder:SetShown((self:GetText() or "") == "")
        if RefreshAliasList then RefreshAliasList() end
    end)
    aliasSearchBox:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then
            self:SetText("")
        else
            self:ClearFocus()
        end
    end)


    local exportInclAlias, exportInclShortkey = true, true
    local function CurrentScope()
        if exportInclAlias and exportInclShortkey then return "both" end
        if exportInclAlias then return "alias" end
        if exportInclShortkey then return "shortkey" end
        return nil
    end
    local CHECK_TEX = "Interface\\Buttons\\UI-CheckBox-Check"
    local cogBtn
    local ShowExportScopeMenu


    local function ExportScopeMenuArgs()
        return "EasyFindExportScopeMenu", {
            { text = L["SHORTKEY_SCOPE_ALIASES"], icon = exportInclAlias and CHECK_TEX or nil,
              onClick = function() exportInclAlias = not exportInclAlias; ShowExportScopeMenu() end },
            { text = L["SHORTKEY_SCOPE_SHORTKEYS"], icon = exportInclShortkey and CHECK_TEX or nil,
              onClick = function() exportInclShortkey = not exportInclShortkey; ShowExportScopeMenu() end },
        }, {


            stayOpen = true,
            anchorFrame = cogBtn,
            toggleOwner = cogBtn,
            point = "TOPRIGHT", relativePoint = "BOTTOMRIGHT", offsetY = -2,
        }
    end
    ShowExportScopeMenu = function()
        Utils.ShowCursorMenu(ExportScopeMenuArgs())
    end

    local sharePopup
    local function BuildSharePopup()
        local f = CreateFrame("Frame", "EasyFindSharePopup", UIParent, "BackdropTemplate")
        f._efSurface = "options"
        f:SetSize(440, 200)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:SetClampedToScreen(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        ns.StyleMenuPanel(f)

        f.title = f:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormal)
        f.title._efOwnColor = true
        f.title:SetPoint("TOP", 0, -12)

        local boxFrame = CreateFrame("Frame", nil, f)
        boxFrame:SetPoint("TOPLEFT", 14, -34)
        boxFrame:SetPoint("TOPRIGHT", -14, -34)
        boxFrame:SetHeight(112)
        ns.CreateRoundedRectBorder(boxFrame)
        ns.SetRoundedRectBarHeight(boxFrame, 8)
        ns.SetRoundedRectBorderShown(boxFrame, false)
        ns.SetRoundedRectFill(boxFrame, 0.02, 0.02, 0.03, 1)



        local scroll = CreateFrame("ScrollFrame", "EasyFindShareScroll", boxFrame)
        scroll:SetPoint("TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", -14, 8)

        local eb = CreateFrame("EditBox", nil, scroll)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject(OPT_FONTS.GameFontHighlightSmall)
        eb:SetWidth(384)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
        scroll:SetScrollChild(eb)
        f.editBox = eb



        local function FocusBox()
            eb:SetFocus()
            if eb._efReadOnlyText then eb:HighlightText() else eb:SetCursorPosition(#(eb:GetText() or "")) end
        end
        boxFrame:EnableMouse(true)
        boxFrame:SetScript("OnMouseDown", FocusBox)
        scroll:EnableMouse(true)
        scroll:SetScript("OnMouseDown", FocusBox)
        Utils.CreateMinimalScrollBar(scroll, boxFrame)



        Utils.AttachCopiedFlash(eb, f, boxFrame, -4)

        f.importBtn = ns.CreateModernButton(f, L["SHORTKEY_IMPORT"], 90, 22)
        f.importBtn:SetPoint("BOTTOMRIGHT", -14, 12)

        f.hint = f:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
        f.hint:SetPoint("BOTTOMLEFT", 14, 16)

        f.hintBtn = CreateFrame("Button", nil, f)
        f.hintBtn:SetAllPoints(f.hint)
        f.hintBtn:SetScript("OnEnter", function() f.hint:SetTextColor(1, 1, 1, 1) end)
        f.hintBtn:SetScript("OnLeave", function() f.hint:SetTextColor(0.5, 0.5, 0.5, 1) end)
        f.hintBtn:Hide()

        local x = ns.CreateCloseX(f, 14)
        x:SetPoint("TOPRIGHT", -8, -8)
        x:SetScript("OnClick", function() f:Hide() end)


        ns.AttachEscClose(f)
        f:Hide()
        return f
    end




    local PREVIEW_ROWS = 10
    local function SectionLabel(id)
        if id == "aliases" then return L["SHORTKEY_SCOPE_ALIASES"] end
        if id == "shortkeys" then return L["SHORTKEY_SCOPE_SHORTKEYS"] end
        if id == "blacklist" then return L["OPT_TAB_BLACKLIST"] end
        if id == "quicklists" then return L["FILTER_QUICKLISTS"] end
        return L["FILTER_SNIPPETS"]
    end
    local REFUSAL_TEXT = {
        key = "IMPORT_REFUSED_KEY", command = "IMPORT_REFUSED_COMMAND", length = "IMPORT_REFUSED_LENGTH",
    }
    local function ScopeTitle(scope)
        if scope == "blacklist" then return L["OPT_TAB_BLACKLIST"] end
        if scope == "snippet" then return L["FILTER_SNIPPETS"] end
        if scope == "quicklist" then return L["FILTER_QUICKLISTS"] end
        if scope == "profile" then return L["OPT_TAB_PROFILES"] end
        return L["OPT_TAB_ALIASES"]
    end





    local PV_W, PV_ROW_H, PV_PAD, PV_DETAIL_H = 480, 20, 14, 76
    local previewFrame
    local function BuildPreviewFrame()
        local f = CreateFrame("Frame", "EasyFindImportPreview", UIParent, "BackdropTemplate")
        f._efSurface = "options"
        f:SetSize(PV_W, 300)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:SetClampedToScreen(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        ns.StyleMenuPanel(f)

        f.title = f:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormal)
        f.title._efOwnColor = true
        f.title:SetPoint("TOP", 0, -12)

        f.warn = f:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
        f.warn:SetPoint("TOPLEFT", PV_PAD, -34)
        f.warn:SetPoint("RIGHT", -PV_PAD, 0)
        f.warn:SetJustifyH("LEFT")
        f.warn:SetWordWrap(true)
        f.warn:SetTextColor(ns.GOLD_COLOR[1], ns.GOLD_COLOR[2], ns.GOLD_COLOR[3], 1)

        local listBox = CreateFrame("Frame", nil, f)
        listBox:SetPoint("LEFT", PV_PAD, 0)
        listBox:SetPoint("RIGHT", -PV_PAD, 0)
        ns.CreateRoundedRectBorder(listBox)
        ns.SetRoundedRectBarHeight(listBox, 8)
        ns.SetRoundedRectBorderShown(listBox, false)
        ns.SetRoundedRectFill(listBox, 0.02, 0.02, 0.03, 1)
        f.listBox = listBox
        local scroll = CreateFrame("ScrollFrame", nil, listBox)
        scroll:SetPoint("TOPLEFT", 6, -6)
        scroll:SetPoint("BOTTOMRIGHT", -6, 6)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(PV_W - PV_PAD * 2 - 12, 1)
        scroll:SetScrollChild(content)
        f.scroll, f.content = scroll, content
        f.scrollBar = Utils.CreateMinimalScrollBar(scroll, listBox)
        ParkScrollBarInMargin(f.scrollBar, listBox, 2)
        f.rows = {}

        local detail = CreateFrame("Frame", nil, f)
        detail:SetPoint("LEFT", PV_PAD, 0)
        detail:SetPoint("RIGHT", -PV_PAD, 0)
        detail:SetHeight(PV_DETAIL_H)
        ns.CreateRoundedRectBorder(detail)
        ns.SetRoundedRectBarHeight(detail, 8)
        ns.SetRoundedRectBorderShown(detail, false)
        ns.SetRoundedRectFill(detail, 0.02, 0.02, 0.03, 1)
        f.detail = detail
        f.detailText = detail:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
        f.detailText:SetPoint("TOPLEFT", 8, -8)
        f.detailText:SetPoint("BOTTOMRIGHT", -8, 8)
        f.detailText:SetJustifyH("LEFT")
        f.detailText:SetJustifyV("TOP")
        f.detailText:SetWordWrap(true)
        f.detailText:SetNonSpaceWrap(true)

        f.importBtn = ns.CreateModernButton(f, L["SHORTKEY_IMPORT"], 90, 22)
        f.importBtn:SetPoint("BOTTOMRIGHT", -PV_PAD, 12)
        f.cancelBtn = ns.CreateModernButton(f, _G["CANCEL"] or "Cancel", 90, 22)
        f.cancelBtn:SetPoint("RIGHT", f.importBtn, "LEFT", -8, 0)
        f.cancelBtn:SetScript("OnClick", function() f:Hide() end)
        local x = ns.CreateCloseX(f, 14)
        x:SetPoint("TOPRIGHT", -8, -8)
        x:SetScript("OnClick", function() f:Hide() end)
        ns.AttachEscClose(f)
        f:Hide()
        return f
    end

    local function PreviewRow(f, i)
        local row = f.rows[i]
        if row then return row end
        row = CreateFrame("Button", nil, f.content)
        row:SetHeight(PV_ROW_H)
        row:SetPoint("LEFT", f.content, "LEFT", 0, 0)
        row:SetPoint("RIGHT", f.content, "RIGHT", 0, 0)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0)
        row.label = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
        row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        row.status = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
        row.status:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.status:SetJustifyH("RIGHT")
        row.status:SetWordWrap(false)
        row.label:SetPoint("RIGHT", row.status, "LEFT", -8, 0)
        row:SetScript("OnEnter", function(self)
            if self.def and self.def.detail then self.bg:SetColorTexture(1, 1, 1, 0.06) end
        end)
        row:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(1, 1, 1, self.selected and 0.10 or 0)
        end)
        row:SetScript("OnClick", function(self)
            local def = self.def
            if not (def and def.detail) then return end
            for _, other in ipairs(f.rows) do
                other.selected = nil
                other.bg:SetColorTexture(1, 1, 1, 0)
            end
            self.selected = true
            self.bg:SetColorTexture(1, 1, 1, 0.10)
            f.detailText:SetText(def.detail)
            f.detailText:SetTextColor(0.92, 0.92, 0.92, 1)
        end)
        f.rows[i] = row
        return row
    end




    function ns.ShowImportPreview(opts)
        if not previewFrame then previewFrame = BuildPreviewFrame() end
        local f = previewFrame
        local shareTheme = Look().theme
        if shareTheme and shareTheme.lightTheme then
            f.title:SetTextColor(unpack(shareTheme.leafColor))
        else
            f.title:SetTextColor(1.0, 0.82, 0)
        end
        f.title:SetText((L["IMPORT_PREVIEW_TITLE_FMT"]):format(ScopeTitle(opts.scope)))
        f.warn:SetText(opts.warn or "")
        local y = -34
        if opts.warn and opts.warn ~= "" then y = y - f.warn:GetStringHeight() - 8 end
        f.listBox:ClearAllPoints()
        f.listBox:SetPoint("TOPLEFT", PV_PAD, y)
        f.listBox:SetPoint("RIGHT", -PV_PAD, 0)
        local rows = opts.rows or {}
        for i = 1, #rows do
            local row = PreviewRow(f, i)
            local def = rows[i]
            row.def = def
            row.selected = nil
            row.bg:SetColorTexture(1, 1, 1, 0)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -(i - 1) * PV_ROW_H)
            row:SetPoint("RIGHT", f.content, "RIGHT", 0, 0)
            if def.header then
                row.label:SetFontObject(OPT_FONTS.GameFontNormalSmall)
                row.label:SetText(def.header)
                row.status:SetText("")
            else
                row.label:SetFontObject(OPT_FONTS.GameFontHighlightSmall)
                row.label:SetText("    " .. (def.label or ""))
                row.status:SetText(def.status or "")
            end
            row:Show()
        end
        for i = #rows + 1, #f.rows do f.rows[i]:Hide() end
        local listH = math.min(#rows, PREVIEW_ROWS) * PV_ROW_H + 12
        f.listBox:SetHeight(listH)
        f.content:SetHeight(math.max(1, #rows * PV_ROW_H))
        f.scroll:SetVerticalScroll(0)
        if f.scrollBar then
            if #rows > PREVIEW_ROWS then
                f.scrollBar:Show()
                f.scrollBar:UpdateThumb(#rows * PV_ROW_H, listH - 12)
            else
                f.scrollBar:Hide()
            end
        end
        local anyDetail = false
        for i = 1, #rows do
            if rows[i].detail then anyDetail = true end
        end
        f.detail:ClearAllPoints()
        f.detail:SetPoint("TOPLEFT", f.listBox, "BOTTOMLEFT", 0, -8)
        f.detail:SetPoint("RIGHT", -PV_PAD, 0)
        f.detail:SetShown(anyDetail)
        f.detailText:SetText(L["IMPORT_PREVIEW_PICK"])
        f.detailText:SetTextColor(0.55, 0.55, 0.55, 1)
        local bottom = anyDetail and (PV_DETAIL_H + 8) or 0
        f:SetHeight(-y + listH + 8 + bottom + 22 + 12 + 12)
        f.importBtn:SetScript("OnClick", function()
            f:Hide()
            if opts.onImport then opts.onImport() end
        end)
        f:Show()
    end






    local function DetailFor(section, r)
        if section == "aliases" then return (r.text or "?") .. "  >  " .. (r.name or "?") end
        if section == "shortkeys" then return (r.b or "?") .. "  >  " .. (r.n or "?") end
        if section == "snippets" then
            local head = (r.name or "?") .. ((r.keyword and r.keyword ~= "") and ("  (" .. r.keyword .. ")") or "")
            return head .. "\n" .. (r.body or "")
        end
        return (r.name or "?") .. ((r.category and r.category ~= "") and ("  (" .. r.category .. ")") or "")
    end
    local function LabelFor(section, r)
        if section == "aliases" then return r.text or "?" end
        if section == "shortkeys" then return (r.b or "?") .. "  " .. (r.n or "?") end
        if section == "snippets" then
            return ((r.keyword and r.keyword ~= "") and (r.keyword .. "  ") or "") .. (r.name or "?")
        end
        return r.name or "?"
    end
    local function ImportPreviewRows(analysis)
        local rows, any, risky = {}, false, false
        local conflictsBy = {}
        for _, c in ipairs(analysis.conflicts) do
            conflictsBy[c.section] = conflictsBy[c.section] or {}
            table.insert(conflictsBy[c.section], c.row)
        end
        for _, section in ipairs({ "aliases", "shortkeys", "blacklist", "snippets", "quicklists" }) do
            local fresh = analysis.newRows[section] or {}
            local replacing = conflictsBy[section] or {}
            local total = #fresh + #replacing
            if total > 0 then
                any = true
                rows[#rows + 1] = { header = SectionLabel(section) .. ": " .. total }
                for _, r in ipairs(fresh) do
                    if ns.Shortkeys.RunsCommands(section, r) then risky = true end
                    rows[#rows + 1] = { label = LabelFor(section, r), status = L["IMPORT_STATUS_NEW"], detail = DetailFor(section, r) }
                end
                for _, r in ipairs(replacing) do
                    if ns.Shortkeys.RunsCommands(section, r) then risky = true end
                    rows[#rows + 1] = { label = LabelFor(section, r), status = L["IMPORT_STATUS_REPLACES"], detail = DetailFor(section, r) }
                end
            end
        end
        local skipped = analysis.skipped or {}
        if #skipped > 0 then
            rows[#rows + 1] = { header = L["IMPORT_PREVIEW_LEFT_OUT"] .. ": " .. #skipped }
            for _, s in ipairs(skipped) do
                rows[#rows + 1] = {
                    label = s.label,
                    status = (L["IMPORT_STATUS_LEFT_OUT_FMT"]):format(L[REFUSAL_TEXT[s.reason] or "IMPORT_REFUSED_LENGTH"]),
                }
            end
        end
        return rows, any, risky
    end





    local function OpenLeftOut(entry)
        local row = entry.row or {}
        if entry.section == "snippets" then
            if ns.Snippets and ns.Snippets.FindConflict and ns.Snippets.OpenEditor then
                local _, index = ns.Snippets:FindConflict(row.name, row.keyword)
                if index then ns.Snippets:OpenEditor(index) end
            end
        elseif entry.section == "blacklist" then
            if optionsFrame.ShowInBlacklistTable then optionsFrame.ShowInBlacklistTable(row.name or "") end
        elseif optionsFrame.ShowInAliasTable then
            optionsFrame.ShowInAliasTable(entry.section == "aliases" and row.text or row.n or "")
        end
    end
    local function ShowLeftOut(anchor, rows)
        local defs = { { kind = "title", label = L["IMPORT_PREVIEW_LEFT_OUT"] } }
        for i = 1, #rows do
            local entry = rows[i]
            defs[#defs + 1] = {
                kind = "action",
                label = entry.label .. "  (" .. L[REFUSAL_TEXT[entry.reason] or "IMPORT_REFUSED_LENGTH"] .. ")",
                onClick = function()
                    if sharePopup then sharePopup:Hide() end
                    OpenLeftOut(entry)
                end,
            }
        end
        ns.ShowTogglePopup("EasyFindLeftOutPopup", anchor, defs, {})
    end

    local function ShowShareString(isExport, str, scope, onImported, leftOut, leftOutRows)
        if not sharePopup then sharePopup = BuildSharePopup() end
        local f = sharePopup

        local shareTheme = Look().theme
        if shareTheme and shareTheme.lightTheme then
            f.title:SetTextColor(unpack(shareTheme.leafColor))
        else
            f.title:SetTextColor(1.0, 0.82, 0)
        end
        if isExport then
            f.title:SetText(L["SHORTKEY_EXPORT_TITLE"] .. " (Ctrl+C)")
            if leftOut and leftOut > 0 and leftOutRows then
                f.hint:SetText((L["EXPORT_LEFT_OUT_FMT"]):format(leftOut))
                f.hintBtn:Show()
                f.hintBtn:SetScript("OnClick", function(self) ShowLeftOut(self, leftOutRows) end)
            else
                f.hint:SetText("")
                f.hintBtn:Hide()
            end
            Utils.SetEditBoxReadOnlyText(f.editBox, str or "")
            f.importBtn:Hide()
            f:Show()
            f.editBox:SetFocus()
            f.editBox:HighlightText()
        else
            f.title:SetText(L["SHORTKEY_IMPORT_TITLE"])
            f.hint:SetText(L["SHORTKEY_IMPORT_HINT"])
            Utils.SetEditBoxReadOnlyText(f.editBox, nil)
            f.editBox:SetText("")
            f.importBtn:Show()
            f.importBtn:SetScript("OnClick", function()


                if scope == "profile" then
                    local text = f.editBox:GetText()
                    f:Hide()
                    local payload = ns.Profiles and ns.Profiles:Decode(text)
                    if not payload then
                        if EasyFind and EasyFind.Print then EasyFind:Print(L["SHORTKEY_IMPORT_BAD"]) end
                        return
                    end



                    local inspect = ns.Profiles:InspectImport(payload)
                    local rows = { { header = L["PROFILE_IMPORT_PREVIEW"] } }
                    for _, entry in ipairs(inspect.sections) do
                        rows[#rows + 1] = { label = L[PROFILE_SECTION_LABEL_KEY[entry.id] or "PROFILE_SECTION_SETTINGS"], status = tostring(entry.count) }
                    end
                    if inspect.leftOut > 0 then
                        rows[#rows + 1] = { header = L["IMPORT_PREVIEW_LEFT_OUT"] .. ": " .. inspect.leftOut }
                    end
                    ns.ShowImportPreview({
                        scope = "profile",
                        warn = inspect.risky > 0 and L["IMPORT_TRUST_WARN"] or nil,
                        rows = rows,
                        onImport = function()
                            local name = ns.Profiles:Import(text)
                            if not name then
                                if EasyFind and EasyFind.Print then EasyFind:Print(L["SHORTKEY_IMPORT_BAD"]) end
                                return
                            end
                            if onImported then onImported() end
                            ns.ShowThemedDialog({
                                text = (L["PROFILE_IMPORT_SWITCH_FMT"]):format(ns.Profiles:DisplayName(name)),
                                messageColor = ns.GOLD_COLOR,
                                acceptText = L["PROFILE_SWITCH"],
                                onAccept = function() ns.Profiles:Pick(name) end,
                                cancelText = L["PROFILE_KEEP_CURRENT"],
                            })
                        end,
                    })
                    return
                end
                local decoded = ns.Shortkeys and ns.Shortkeys:DecodeString(f.editBox:GetText())
                f:Hide()
                if not decoded then
                    if EasyFind and EasyFind.Print then EasyFind:Print(L["SHORTKEY_IMPORT_BAD"]) end
                    return
                end

                local over = ns.Shortkeys:CheckImportLimits(decoded, scope)
                if over then
                    if EasyFind and EasyFind.Print then
                        EasyFind:Print((L["IMPORT_OVER_CAP_FMT"]):format(SectionLabel(over.section), over.count, over.cap))
                    end
                    return
                end
                local analysis = ns.Shortkeys:AnalyzeImport(decoded, scope)
                local conflicts = analysis.conflicts


                local applySet = analysis.newRows

                local function finish()
                    ns.Shortkeys:ApplyResolvedImport(applySet)
                    if onImported then onImported() end
                end



                local function resolve(i, forced)
                    while i <= #conflicts do
                        local c = conflicts[i]
                        if not forced then
                            ns.ShowThemedDialog({
                                text = c.label .. "\n\n" .. L["IMPORT_CONFLICT_ITEM"],
                                messageColor = ns.GOLD_COLOR,
                                checkboxText = L["IMPORT_APPLY_TO_ALL"],
                                acceptText = L["IMPORT_REPLACE"],
                                onAccept = function(_, all)
                                    local list = applySet[c.section]
                                    list[#list + 1] = c.row
                                    resolve(i + 1, all and "replace" or nil)
                                end,
                                thirdText = L["IMPORT_SKIP"],
                                onThird = function(all)
                                    resolve(i + 1, all and "skip" or nil)
                                end,
                                cancelText = _G["CANCEL"] or "Cancel",
                            })
                            return
                        end
                        if forced == "replace" then
                            local list = applySet[c.section]
                            list[#list + 1] = c.row
                        end
                        i = i + 1
                    end
                    finish()
                end

                local function startConflicts()
                    if #conflicts == 0 then finish() else resolve(1, nil) end
                end

                local function afterPreview()
                    if #analysis.disruptive > 0 then
                        ns.ShowThemedDialog({
                            text = (L["IMPORT_SYSCMD_WARN"]):format(#analysis.disruptive,
                                table.concat(analysis.disruptive, ", ")),
                            messageColor = ns.GOLD_COLOR,
                            acceptText = _G["CONTINUE"] or L["SHORTKEY_IMPORT"],
                            onAccept = startConflicts,
                            cancelText = _G["CANCEL"] or "Cancel",
                        })
                    else
                        startConflicts()
                    end
                end



                local rows, any, risky = ImportPreviewRows(analysis)
                if not any and #(analysis.skipped or {}) == 0 then
                    if EasyFind and EasyFind.Print then EasyFind:Print(L["IMPORT_PREVIEW_EMPTY"]) end
                    return
                end
                ns.ShowImportPreview({
                    scope = scope,
                    warn = risky and L["IMPORT_TRUST_WARN"] or nil,
                    rows = rows,
                    onImport = afterPreview,
                })
            end)
            f:Show()
            f.editBox:SetFocus()
        end
    end
    optionsFrame.ShowShareString = ShowShareString

    local shareTools = CreateFrame("Frame", nil, aliasesTab)
    shareTools:SetPoint("TOPLEFT", aliasTools, "BOTTOMLEFT", 0, -6)
    shareTools:SetPoint("RIGHT", aliasesTab, "RIGHT", -8, 0)
    shareTools:SetHeight(22)




    local SHARE_BTN_W = 110
    local function UseShareButtonFill(btn)
        PaintControlFill(btn, ns.BTN_FILL_NORMAL, 0.92)
        btn:HookScript("OnLeave", function(self)
            if self:IsEnabled() then PaintControlFill(self, ns.BTN_FILL_NORMAL, 0.92) end
        end)
        btn:HookScript("OnMouseUp", function(self)
            if self:IsEnabled() and not self:IsMouseOver() then
                PaintControlFill(self, ns.BTN_FILL_NORMAL, 0.92)
            end
        end)
    end

    local exportBtn = CreateModernButton(shareTools, L["SHORTKEY_EXPORT"], SHARE_BTN_W, 22)
    Options:AddAction("aliasesExport", exportBtn)
    exportBtn:SetPoint("LEFT", shareTools, "LEFT", 0, 0)
    UseShareButtonFill(exportBtn)

    exportBtn._label:ClearAllPoints()
    exportBtn._label:SetPoint("CENTER", exportBtn, "CENTER", -9, 0)
    exportBtn:SetScript("OnClick", function()
        local str, leftOut, leftOutRows = "", 0, nil
        if ns.Shortkeys then str, leftOut, leftOutRows = ns.Shortkeys:BuildExportString(CurrentScope()) end
        ShowShareString(true, str, nil, nil, leftOut, leftOutRows)
    end)

    cogBtn = ns.CreateCogButton(exportBtn)
    cogBtn:SetPoint("RIGHT", exportBtn, "RIGHT", -4, 0)
    cogBtn:SetScript("OnClick", function()
        Utils.ToggleCursorMenu(ExportScopeMenuArgs())
    end)

    local importBtn = CreateModernButton(shareTools, L["SHORTKEY_IMPORT"], SHARE_BTN_W, 22)
    Options:AddAction("aliasesImport", importBtn)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
    UseShareButtonFill(importBtn)
    importBtn:SetScript("OnClick", function()
        ShowShareString(false, nil, CurrentScope(), RefreshAliasList)
    end)

    Utils.AttachDelayedTooltip(exportBtn, "ANCHOR_TOP", function()
        return L["SHORTKEY_EXPORT"], L["OPT_EXPORT_BTN_TT"]
    end)
    Utils.AttachDelayedTooltip(importBtn, "ANCHOR_TOP", function()
        return L["SHORTKEY_IMPORT"], L["OPT_IMPORT_BTN_TT"]
    end)




    local COL_GAP = 6
    local REMOVE_RIGHT = 4
    local REMOVE_W = 20
    local SK_COL_W = 104
    local ALIAS_COL_W = 144
    local NAME_LEFT = 10
    local HEADER_H = 14

    local HEADER_TOP = 7
    local DIVIDER_Y = HEADER_TOP + HEADER_H + 3
    local SCROLL_TOP = DIVIDER_Y + 4

    local aliasList = CreateFrame("Frame", nil, aliasesTab)
    aliasList:SetPoint("TOPLEFT", shareTools, "BOTTOMLEFT", 0, -8)
    ctx.AnchorListCardBottom(aliasList, aliasesTab)
    ns.CreateRoundedRectBorder(aliasList)
    ns.SetRoundedRectBarHeight(aliasList, 8)
    HideRoundedFrameBorder(aliasList)
    ns.ApplyCardFill(aliasList)


    local aliasColHeader = CreateFrame("Frame", nil, aliasList)
    aliasColHeader:SetSize(FRAME_W - 42, HEADER_H)
    aliasColHeader:SetPoint("TOPLEFT", aliasList, "TOPLEFT", 10, -HEADER_TOP)
    local function MakeColHeader(text, justify)
        local fs = aliasColHeader:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
        fs:SetText(text)
        fs:SetJustifyH(justify)
        fs:SetTextColor(0.92, 0.92, 0.92, 1)
        return fs
    end
    local hSk = MakeColHeader(L["OPT_COL_SHORTKEY"], "CENTER")
    hSk:SetWidth(SK_COL_W)
    hSk:SetPoint("RIGHT", aliasColHeader, "RIGHT", -(REMOVE_RIGHT + REMOVE_W + COL_GAP), 0)
    local hAlias = MakeColHeader(L["OPT_COL_ALIAS"], "CENTER")
    hAlias:SetWidth(ALIAS_COL_W)
    hAlias:SetPoint("RIGHT", hSk, "LEFT", -COL_GAP, 0)
    local hObject = MakeColHeader(L["OPT_COL_OBJECT"], "LEFT")
    hObject:SetPoint("LEFT", aliasColHeader, "LEFT", NAME_LEFT, 0)
    hObject:SetPoint("RIGHT", hAlias, "LEFT", -8, 0)

    local headerDivider = aliasList:CreateTexture(nil, "ARTWORK")
    headerDivider:SetColorTexture(1, 1, 1, 0.09)
    headerDivider:SetHeight(1)
    headerDivider:SetPoint("TOPLEFT", aliasList, "TOPLEFT", 8, -DIVIDER_Y)
    headerDivider:SetPoint("TOPRIGHT", aliasList, "TOPRIGHT", -8, -DIVIDER_Y)

    local aliasScroll = CreateFrame("ScrollFrame", nil, aliasList)
    aliasScroll:SetPoint("TOPLEFT", aliasList, "TOPLEFT", 6, -SCROLL_TOP)
    aliasScroll:SetPoint("BOTTOMRIGHT", aliasList, "BOTTOMRIGHT", -10, 6)

    local aliasContent = CreateFrame("Frame", nil, aliasScroll)
    aliasContent:SetSize(FRAME_W - 42, 1)
    aliasScroll:SetScrollChild(aliasContent)

    local aliasScrollBar = ns.Utils and ns.Utils.CreateMinimalScrollBar and ns.Utils.CreateMinimalScrollBar(aliasScroll, aliasList)
    ParkScrollBarInMargin(aliasScrollBar, aliasList, SCROLL_TOP)
    local aliasEmpty = aliasContent:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
    aliasEmpty:SetPoint("TOPLEFT", aliasContent, "TOPLEFT", 8, -8)
    aliasEmpty:SetText(L["OPT_NO_SAVED_ALIASES"])
    aliasEmpty:SetTextColor(0.92, 0.92, 0.92, 1)

    local aliasRowPool = {}
    local function ReleaseAliasRows()
        for i = 1, #aliasRowPool do aliasRowPool[i]:Hide() end
    end
    local function UpdateAliasScrollBar()
        if not aliasScrollBar then return end
        local contentH = aliasContent:GetHeight() or 0
        local viewH = aliasScroll:GetHeight() or 0
        if contentH > viewH + 1 then
            aliasScrollBar:Show()
            aliasScrollBar:UpdateThumb(contentH, viewH)
        else
            aliasScroll:SetVerticalScroll(0)
            aliasScrollBar:Hide()
        end
    end


    local truncTipToken = 0
    local function ShowTruncTip(anchor, fontString, fullText)
        truncTipToken = truncTipToken + 1
        if not (fontString and fontString.IsTruncated and fontString:IsTruncated()) then return end
        if not fullText or fullText == "" then return end
        local myToken = truncTipToken
        Utils.SafeAfter(0.5, function()
            if myToken ~= truncTipToken or not anchor:IsMouseOver() then return end
            GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
            GameTooltip:SetText(fullText, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
    end
    local function HideTruncTip()
        truncTipToken = truncTipToken + 1
        GameTooltip:Hide()
    end

    local function AcquireAliasRow(idx)
        local row = aliasRowPool[idx]
        if row then row:Show(); return row end
        row = CreateFrame("Frame", nil, aliasContent)
        row:SetSize(FRAME_W - 42, 26)
        row:EnableMouse(true)
        row.bg = CreateFrame("Frame", nil, row)
        row.bg:SetAllPoints()
        row.bg:EnableMouse(false)
        ns.CreateRoundedRectBorder(row.bg)
        ns.SetRoundedRectBarHeight(row.bg, 8)
        HideRoundedFrameBorder(row.bg)
        PaintRoundedFill(row.bg, 1, 1, 1, 0)

        row.removeBtn = CreateModernButton(row, "x", REMOVE_W, 18)
        row.removeBtn:SetPoint("RIGHT", row, "RIGHT", -REMOVE_RIGHT, 0)


        row.skBtn = CreateModernButton(row, "", SK_COL_W, 20)
        row.skBtn:SetPoint("RIGHT", row.removeBtn, "LEFT", -COL_GAP, 0)
        row.skBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        ns.StyleNavPillButton(row.skBtn)

        row.aliasBtn = CreateModernButton(row, "", ALIAS_COL_W, 20)
        row.aliasBtn:SetPoint("RIGHT", row.skBtn, "LEFT", -COL_GAP, 0)
        ns.StyleNavPillButton(row.aliasBtn)


        row.aliasBtn._label:SetWidth(ALIAS_COL_W - 10)
        row.aliasBtn._label:SetWordWrap(false)
        row.aliasBtn:HookScript("OnEnter", function(self)
            ShowTruncTip(self, self._label, self._fullText)
        end)
        row.aliasBtn:HookScript("OnLeave", HideTruncTip)

        row.nameText = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
        row.nameText:SetPoint("LEFT", row, "LEFT", NAME_LEFT, 0)
        row.nameText:SetPoint("RIGHT", row.aliasBtn, "LEFT", -8, 0)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetWordWrap(false)


        ns.ShadeText(row.nameText)


        row.nameHover = CreateFrame("Frame", nil, row)
        row.nameHover:SetPoint("TOPLEFT", row, "TOPLEFT", NAME_LEFT, 0)
        row.nameHover:SetPoint("BOTTOMRIGHT", row.aliasBtn, "BOTTOMLEFT", -8, 0)
        row.nameHover:EnableMouse(true)
        row.nameHover:SetScript("OnEnter", function(self)
            PaintRoundedFill(row.bg, 1, 1, 1, 0.055)
            ShowTruncTip(self, row.nameText, row.nameText._fullText)
        end)
        row.nameHover:SetScript("OnLeave", function()
            PaintRoundedFill(row.bg, 1, 1, 1, 0)
            HideTruncTip()
        end)

        row:SetScript("OnEnter", function(self)
            PaintRoundedFill(self.bg, 1, 1, 1, 0.055)
        end)
        row:SetScript("OnLeave", function(self)
            PaintRoundedFill(self.bg, 1, 1, 1, 0)
        end)
        aliasRowPool[idx] = row
        return row
    end



    RefreshAliasList = function()
        ReleaseAliasRows()
        local query = (aliasSearchBox and aliasSearchBox:GetText() or ""):lower()

        local byKey, order = {}, {}
        local function ensure(rk, name)
            local e = byKey[rk]
            if not e then
                e = { key = rk, name = name, aliases = {} }
                byKey[rk] = e
                order[#order + 1] = e
            end
            if name and (not e.name or e.name == "") then e.name = name end
            return e
        end
        if ns.Aliases then
            ns.Aliases:ForEach(function(text, info)
                if info.key then
                    local e = ensure(info.key, info.name)
                    e.aliases[#e.aliases + 1] = info.text or text
                end
            end)
        end
        if ns.Shortkeys then
            ns.Shortkeys:ForEach(function(rk, info, isChar)
                local e = ensure(rk, info.name)
                e.shortkey = info.key
                e.charSpecific = isChar
            end)
        end

        local total = #order
        local entries = {}
        for i = 1, total do
            local e = order[i]
            e.aliasText = table.concat(e.aliases, ", ")
            local haystack = (e.aliasText .. " " .. (e.name or "") .. " " .. (e.shortkey or "")):lower()
            if query == "" or string.find(haystack, query, 1, true) then
                entries[#entries + 1] = e
            end
        end
        table.sort(entries, function(a, b) return (a.name or ""):lower() < (b.name or ""):lower() end)

        clearAliasesBtn:SetEnabled(total > 0)
        clearAliasesBtn:SetAlpha(total > 0 and 1 or 0.45)
        aliasEmpty:SetText(total == 0 and L["OPT_NO_SAVED_ALIASES"] or L["OPT_NO_ALIASES_MATCH"])
        aliasEmpty:SetShown(#entries == 0)

        local rowH = 28
        local y = -4




        local lightCells = Look().palette and Look().palette.light
        local function CellText(value)
            if not value or value == "" then return L["SHORTKEY_CELL_ADD"] end
            if lightCells then return value end
            return "|cFF8CD3FF" .. value .. "|r"
        end
        for i = 1, #entries do
            local e = entries[i]
            local row = AcquireAliasRow(i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", aliasContent, "TOPLEFT", 4, y)
            row.aliasBtn:SetText(CellText(e.aliasText))
            row.skBtn:SetText(CellText(e.shortkey))


            row.skBtn:SetShown(not (e.key and Utils.sfind(e.key, "mapcat:", 1, true) == 1))
            row.aliasBtn:RefreshVisual()
            row.skBtn:RefreshVisual()
            row.nameText:SetText(e.name or "?")
            row.aliasBtn._fullText = e.aliasText
            row.nameText._fullText = e.name

            row.aliasBtn:SetScript("OnClick", function()
                ns.ShowThemedDialog({
                    text = (L["PROMPT_ALIAS_FOR"]):format(e.name or "?"),
                    hasEditBox = true,
                    editBoxDefault = e.aliasText,
                    maxLetters = 64,
                    acceptText = _G["SAVE"] or "Save",
                    onAccept = function(txt)
                        txt = strtrim(txt or "")
                        if not (e.key and ns.Aliases) then return end
                        ns.Aliases:RemoveByKey(e.key)
                        if txt ~= "" then ns.Aliases:AddByKey(txt, e.key, e.name) end
                        if RefreshAliasList then RefreshAliasList() end
                    end,
                })
            end)
            row.skBtn:SetScript("OnClick", function(_, button)
                if button == "RightButton" then
                    if ns.Shortkeys then ns.Shortkeys:Remove(e.key) end
                    RefreshAliasList()
                    return
                end
                if not ns.Shortkeys then return end
                local cs = e.charSpecific
                if cs == nil then
                    local d = ns.Aliases and ns.Aliases:FindEntryByKey(e.key)
                    cs = (d and ns.Shortkeys:IsCharacterSpecific(d)) or false
                end
                ns.Shortkeys:PromptForKeyByKey(e.key, e.name, cs)
            end)
            row.removeBtn:SetScript("OnClick", function()
                if ns.Aliases then ns.Aliases:RemoveByKey(e.key) end
                if ns.Shortkeys then ns.Shortkeys:Remove(e.key) end
                RefreshAliasList()
            end)
            y = y - rowH
        end
        aliasContent:SetHeight(math.max(32, -y + 4))
        UpdateAliasScrollBar()
        Utils.SafeAfter(0, UpdateAliasScrollBar)
    end
    aliasScroll:SetScript("OnSizeChanged", UpdateAliasScrollBar)
    aliasContent:HookScript("OnSizeChanged", UpdateAliasScrollBar)
    aliasesTab:HookScript("OnShow", RefreshAliasList)
    optionsFrame.RefreshAliasList = RefreshAliasList




    ns.RefreshBindTables = function()
        if optionsFrame.RefreshAliasList then optionsFrame.RefreshAliasList() end
        if optionsFrame.RefreshBlacklistList then optionsFrame.RefreshBlacklistList() end
    end

    clearAliasesBtn:SetScript("OnClick", function()
        ns.ShowThemedDialog({
            text = L["POPUP_CLEAR_ALIASES"],
            acceptText = _G["CLEAR"] or "Clear",
            onAccept = function()
                if ns.Aliases then ns.Aliases:ClearAll() end
                if ns.Shortkeys then ns.Shortkeys:ClearAll() end
                RefreshAliasList()
            end,
        })
    end)

    local resetAllBtn = CreateModernButton(sec3)
    resetAllBtn:SetSize(RESET_BTN_W, 20)
    resetAllBtn:SetPoint("LEFT", sec3, "LEFT", 16, 0)


    resetAllBtn:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, 10)
    optionsFrame.resetButtons = optionsFrame.resetButtons or {}
    optionsFrame.resetButtons[#optionsFrame.resetButtons + 1] = resetAllBtn
    resetAllBtn:SetText(L["OPT_RESET_ALL_SETTINGS"])
    resetAllBtn:SetScript("OnClick", function()
        Options:ConfirmResetAll()
    end)
    Utils.AttachDelayedTooltip(resetAllBtn, "ANCHOR_TOP", function()
        return L["OPT_RESET_ALL_SETTINGS"], L["OPT_RESET_ALL_TT_DESC"], L["OPT_RESET_ALL_TT_CMD"]
    end)

    local resetPosBtn = CreateModernButton(sec3)
    resetPosBtn:SetSize(RESET_BTN_W, 20)
    resetPosBtn:SetPoint("LEFT", resetAllBtn, "RIGHT", 8, 0)
    resetPosBtn:SetText(L["OPT_RESET_ALL_POSITIONS"])
    resetPosBtn:SetScript("OnClick", function()
        ShowResetConfirm(L["POPUP_RESET_ALL_POSITIONS"], function() Options:DoResetPositions() end)
    end)
    Utils.AttachDelayedTooltip(resetPosBtn, "ANCHOR_TOP", function()
        return L["OPT_RESET_ALL_POSITIONS"], L["OPT_RESET_POS_TT_DESC"], L["OPT_RESET_POS_TT_CMD"]
    end)
    ns.FitButtonRow({ resetAllBtn, resetPosBtn }, FRAME_W - 24, 8, RESET_BTN_W)

end

local function BuildBlacklistTab(ctx)
    local CreateTab, FRAME_W = ctx.CreateTab, ctx.FRAME_W
    local blacklistTab = CreateTab(L["OPT_TAB_BLACKLIST"])
    Options._blacklistTabIndex = blacklistTab.tabIndex

    local blTitle = blacklistTab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormal)
    blTitle:SetPoint("TOPLEFT", blacklistTab, "TOPLEFT", 8, -8)
    blTitle:SetText(L["OPT_SAVED_BLACKLIST"])

    local blHeader = blacklistTab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    blHeader:SetPoint("TOPLEFT", blTitle, "BOTTOMLEFT", 0, -6)
    blHeader:SetPoint("RIGHT", blacklistTab, "RIGHT", -10, 0)
    blHeader:SetJustifyH("LEFT")
    blHeader:SetText(L["OPT_BLACKLIST_EMPTY_HINT"])

    local RefreshBlacklistList
    local blTools = CreateFrame("Frame", nil, blacklistTab)
    blTools:SetPoint("TOPLEFT", blHeader, "BOTTOMLEFT", 0, -8)
    blTools:SetPoint("RIGHT", blacklistTab, "RIGHT", -8, 0)
    blTools:SetHeight(24)

    local clearBlacklistBtn = CreateModernButton(blTools, L["OPT_CLEAR_ALL_BTN"], 78, 22)
    Options:AddAction("blacklistClear", clearBlacklistBtn)
    clearBlacklistBtn:SetPoint("RIGHT", blTools, "RIGHT", 0, 0)

    local blSearchShell = CreateFrame("Frame", nil, blTools)
    blSearchShell:SetPoint("LEFT", blTools, "LEFT", 0, 0)
    blSearchShell:SetPoint("RIGHT", clearBlacklistBtn, "LEFT", -8, 0)
    blSearchShell:SetHeight(22)
    SearchWell(blSearchShell)

    local blSearchIcon = blSearchShell.ringInset:CreateTexture(nil, "OVERLAY")
    blSearchIcon:SetSize(13, 13)
    blSearchIcon:SetPoint("LEFT", blSearchShell, "LEFT", 7, 0)
    blSearchIcon:SetAtlas("common-search-magnifyingglass")

    local blSearchBox = CreateFrame("EditBox", nil, blSearchShell)
    Utils.ReleaseFocusOnOutsideClick(blSearchBox)
    blSearchBox:SetFrameLevel(blSearchShell.ringInset:GetFrameLevel() + 2)
    blSearchBox:SetPoint("LEFT", blSearchIcon, "RIGHT", 6, 0)
    blSearchBox:SetPoint("RIGHT", blSearchShell, "RIGHT", -8, 0)
    blSearchBox:SetHeight(18)
    optionsFrame.ShowInBlacklistTable = function(text)
        ctx.SwitchToTab(blacklistTab.tabIndex)
        blSearchBox:SetText(text or "")
        if RefreshBlacklistList then RefreshBlacklistList() end
    end
    blSearchBox:SetAutoFocus(false)
    blSearchBox:SetFontObject(SMALL_HIGHLIGHT_FONT)
    blSearchBox:SetMaxLetters(64)

    local blSearchPlaceholder = blSearchBox:CreateFontString(nil, "ARTWORK", OPT_FONTS.GameFontDisableSmall)
    blSearchPlaceholder:SetPoint("LEFT", blSearchBox, "LEFT", 0, 0)
    blSearchPlaceholder:SetText(L["OPT_SEARCH_BLACKLIST_PLACEHOLDER"])
    Utils.StyleSearchHint(blSearchPlaceholder, blSearchIcon)
    blSearchBox:SetScript("OnTextChanged", function(self)
        blSearchPlaceholder:SetShown((self:GetText() or "") == "")
        if RefreshBlacklistList then RefreshBlacklistList() end
    end)
    blSearchBox:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then
            self:SetText("")
        else
            self:ClearFocus()
        end
    end)

    local blShare = CreateFrame("Frame", nil, blacklistTab)
    blShare:SetPoint("TOPLEFT", blTools, "BOTTOMLEFT", 0, -6)
    blShare:SetPoint("RIGHT", blacklistTab, "RIGHT", -8, 0)
    blShare:SetHeight(22)

    local blExportBtn = CreateModernButton(blShare, L["SHORTKEY_EXPORT"], 92, 22)
    Options:AddAction("blacklistExport", blExportBtn)
    blExportBtn:SetPoint("LEFT", blShare, "LEFT", 0, 0)
    blExportBtn:SetScript("OnClick", function()
        local str, leftOut, leftOutRows = "", 0, nil
        if ns.Shortkeys then str, leftOut, leftOutRows = ns.Shortkeys:BuildExportString("blacklist") end
        if optionsFrame.ShowShareString then optionsFrame.ShowShareString(true, str, nil, nil, leftOut, leftOutRows) end
    end)

    local blImportBtn = CreateModernButton(blShare, L["SHORTKEY_IMPORT"], 92, 22)
    Options:AddAction("blacklistImport", blImportBtn)
    blImportBtn:SetPoint("LEFT", blExportBtn, "RIGHT", 8, 0)
    blImportBtn:SetScript("OnClick", function()
        if optionsFrame.ShowShareString then
            optionsFrame.ShowShareString(false, nil, "blacklist", RefreshBlacklistList)
        end
    end)

    local NAME_LEFT = 10
    local REMOVE_W = 20
    local REMOVE_RIGHT = 4
    local HEADER_H = 14
    local HEADER_TOP = 7
    local DIVIDER_Y = HEADER_TOP + HEADER_H + 3
    local SCROLL_TOP = DIVIDER_Y + 4

    local blList = CreateFrame("Frame", nil, blacklistTab)
    blList:SetPoint("TOPLEFT", blShare, "BOTTOMLEFT", 0, -8)
    ctx.AnchorListCardBottom(blList, blacklistTab)
    ns.CreateRoundedRectBorder(blList)
    ns.SetRoundedRectBarHeight(blList, 8)
    HideRoundedFrameBorder(blList)
    ns.ApplyCardFill(blList)

    local blColHeader = CreateFrame("Frame", nil, blList)
    blColHeader:SetSize(FRAME_W - 42, HEADER_H)
    blColHeader:SetPoint("TOPLEFT", blList, "TOPLEFT", 10, -HEADER_TOP)
    local hObject = blColHeader:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
    hObject:SetText(L["OPT_COL_OBJECT"])
    hObject:SetJustifyH("LEFT")
    hObject:SetTextColor(0.92, 0.92, 0.92, 1)
    hObject:SetPoint("LEFT", blColHeader, "LEFT", NAME_LEFT, 0)
    hObject:SetPoint("RIGHT", blColHeader, "RIGHT", -(REMOVE_RIGHT + REMOVE_W + 6), 0)

    local blDivider = blList:CreateTexture(nil, "ARTWORK")
    blDivider:SetColorTexture(1, 1, 1, 0.09)
    blDivider:SetHeight(1)
    blDivider:SetPoint("TOPLEFT", blList, "TOPLEFT", 8, -DIVIDER_Y)
    blDivider:SetPoint("TOPRIGHT", blList, "TOPRIGHT", -8, -DIVIDER_Y)

    local blScroll = CreateFrame("ScrollFrame", nil, blList)
    blScroll:SetPoint("TOPLEFT", blList, "TOPLEFT", 6, -SCROLL_TOP)
    blScroll:SetPoint("BOTTOMRIGHT", blList, "BOTTOMRIGHT", -10, 6)

    local blContent = CreateFrame("Frame", nil, blScroll)
    blContent:SetSize(FRAME_W - 42, 1)
    blScroll:SetScrollChild(blContent)

    local blScrollBar = Utils.CreateMinimalScrollBar and Utils.CreateMinimalScrollBar(blScroll, blList)
    ParkScrollBarInMargin(blScrollBar, blList, SCROLL_TOP)
    local blEmpty = blContent:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
    blEmpty:SetPoint("TOPLEFT", blContent, "TOPLEFT", 8, -8)
    blEmpty:SetText(L["OPT_NO_BLACKLISTED"])
    blEmpty:SetTextColor(0.92, 0.92, 0.92, 1)

    local blRowPool = {}
    local function ReleaseBlacklistRows()
        for i = 1, #blRowPool do blRowPool[i]:Hide() end
    end
    local function UpdateBlacklistScrollBar()
        if not blScrollBar then return end
        local contentH = blContent:GetHeight() or 0
        local viewH = blScroll:GetHeight() or 0
        if contentH > viewH + 1 then
            blScrollBar:Show()
            blScrollBar:UpdateThumb(contentH, viewH)
        else
            blScroll:SetVerticalScroll(0)
            blScrollBar:Hide()
        end
    end

    local function AcquireBlacklistRow(idx)
        local row = blRowPool[idx]
        if row then row:Show(); return row end
        row = CreateFrame("Frame", nil, blContent)
        row:SetSize(FRAME_W - 42, 26)
        row:EnableMouse(true)
        row.bg = CreateFrame("Frame", nil, row)
        row.bg:SetAllPoints()
        row.bg:EnableMouse(false)
        ns.CreateRoundedRectBorder(row.bg)
        ns.SetRoundedRectBarHeight(row.bg, 8)
        HideRoundedFrameBorder(row.bg)
        PaintRoundedFill(row.bg, 1, 1, 1, 0)

        row.removeBtn = CreateModernButton(row, "x", REMOVE_W, 18)
        row.removeBtn:SetPoint("RIGHT", row, "RIGHT", -REMOVE_RIGHT, 0)

        row.nameText = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
        row.nameText:SetPoint("LEFT", row, "LEFT", NAME_LEFT, 0)
        row.nameText:SetPoint("RIGHT", row.removeBtn, "LEFT", -8, 0)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetWordWrap(false)
        ns.ShadeText(row.nameText)

        row:SetScript("OnEnter", function(self)
            PaintRoundedFill(self.bg, 1, 1, 1, 0.055)
        end)
        row:SetScript("OnLeave", function(self)
            PaintRoundedFill(self.bg, 1, 1, 1, 0)
        end)
        blRowPool[idx] = row
        return row
    end

    RefreshBlacklistList = function()
        ReleaseBlacklistRows()
        local query = (blSearchBox and blSearchBox:GetText() or ""):lower()

        local entries, total = {}, 0
        if ns.Blacklist then
            ns.Blacklist:ForEach(function(key, info)
                total = total + 1
                local name = info.name or key
                if query == "" or string.find(name:lower(), query, 1, true) then
                    entries[#entries + 1] = { key = key, name = name }
                end
            end)
        end
        table.sort(entries, function(a, b) return a.name:lower() < b.name:lower() end)

        clearBlacklistBtn:SetEnabled(total > 0)
        clearBlacklistBtn:SetAlpha(total > 0 and 1 or 0.45)
        blEmpty:SetText(total == 0 and L["OPT_NO_BLACKLISTED"] or L["OPT_NO_BLACKLIST_MATCH"])
        blEmpty:SetShown(#entries == 0)

        local rowH = 28
        local y = -4
        for i = 1, #entries do
            local e = entries[i]
            local row = AcquireBlacklistRow(i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", blContent, "TOPLEFT", 4, y)
            row.nameText:SetText(e.name)
            row.removeBtn:SetScript("OnClick", function()
                if ns.Blacklist then ns.Blacklist:RemoveByKey(e.key) end
                RefreshBlacklistList()
            end)
            y = y - rowH
        end
        blContent:SetHeight(math.max(32, -y + 4))
        UpdateBlacklistScrollBar()
        Utils.SafeAfter(0, UpdateBlacklistScrollBar)
    end
    blScroll:SetScript("OnSizeChanged", UpdateBlacklistScrollBar)
    blContent:HookScript("OnSizeChanged", UpdateBlacklistScrollBar)
    blacklistTab:HookScript("OnShow", RefreshBlacklistList)
    optionsFrame.RefreshBlacklistList = RefreshBlacklistList

    clearBlacklistBtn:SetScript("OnClick", function()
        ns.ShowThemedDialog({
            text = L["OPT_CLEAR_BLACKLIST_CONFIRM"],
            acceptText = _G["CLEAR"] or "Clear",
            onAccept = function()
                if ns.Blacklist then ns.Blacklist:ClearAll() end
                RefreshBlacklistList()
            end,
        })
    end)
end


local function BuildSnippetsPage(ctx, page)
    local FRAME_W = ctx.FRAME_W
    local snippetsTab = page

    local snTitle = snippetsTab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormal)
    snTitle:SetPoint("TOPLEFT", snippetsTab, "TOPLEFT", 8, -8)
    snTitle:SetText(L["FILTER_SNIPPETS"])

    local snHeader = snippetsTab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    snHeader:SetPoint("TOPLEFT", snTitle, "BOTTOMLEFT", 0, -6)
    snHeader:SetPoint("RIGHT", snippetsTab, "RIGHT", -10, 0)
    snHeader:SetJustifyH("LEFT")
    snHeader:SetText(L["OPT_SNIPPETS_HINT"])

    local RefreshSnippetsList


    local trigger = ns.Snippets and ns.Snippets.TriggerChar and ns.Snippets.TriggerChar() or "\\"
    local snExpandCheckbox = CreateCheckbox(snippetsTab, "SnippetChatExpansion",
        sformat(L["SNIPPET_EXPAND_IN_CHAT"], trigger), sformat(L["SNIPPET_KEYWORD_HINT"], trigger), true)
    snExpandCheckbox:SetPoint("TOPLEFT", snHeader, "BOTTOMLEFT", 0, -4)
    snExpandCheckbox:SetChecked(EasyFind.db.snippetChatExpansion ~= false)
    snExpandCheckbox:SetScript("OnClick", function(self)
        EasyFind.db.snippetChatExpansion = self:GetChecked() and true or false
    end)
    local snTools = CreateFrame("Frame", nil, snippetsTab)
    snTools:SetPoint("TOPLEFT", snExpandCheckbox, "BOTTOMLEFT", 0, -4)
    snTools:SetPoint("RIGHT", snippetsTab, "RIGHT", -8, 0)
    snTools:SetHeight(24)



    local snShare = CreateFrame("Frame", nil, snippetsTab)
    snShare:SetPoint("TOPLEFT", snTools, "BOTTOMLEFT", 0, -6)
    snShare:SetPoint("RIGHT", snippetsTab, "RIGHT", -8, 0)
    snShare:SetHeight(22)
    local snClearBtn = CreateModernButton(snShare, L["OPT_CLEAR_ALL_BTN"], 78, 22)
    Options:AddAction("snippetsClear", snClearBtn)
    snClearBtn:SetPoint("RIGHT", snShare, "RIGHT", 0, 0)
    snClearBtn:SetScript("OnClick", function()
        ns.ShowThemedDialog({
            text = L["POPUP_CLEAR_SNIPPETS"],
            acceptText = _G["CLEAR"] or "Clear",
            onAccept = function()
                if ns.Snippets and ns.Snippets.ClearAll then ns.Snippets:ClearAll() end
                if RefreshSnippetsList then RefreshSnippetsList() end
            end,
        })
    end)

    local snExportBtn = CreateModernButton(snShare, L["SHORTKEY_EXPORT"], 92, 22)
    Options:AddAction("snippetsExport", snExportBtn)
    snExportBtn:SetPoint("LEFT", snShare, "LEFT", 0, 0)
    snExportBtn:SetScript("OnClick", function()
        local str, leftOut, leftOutRows = "", 0, nil
        if ns.Shortkeys then str, leftOut, leftOutRows = ns.Shortkeys:BuildExportString("snippet") end
        if optionsFrame.ShowShareString then optionsFrame.ShowShareString(true, str, nil, nil, leftOut, leftOutRows) end
    end)
    local snImportBtn = CreateModernButton(snShare, L["SHORTKEY_IMPORT"], 92, 22)
    Options:AddAction("snippetsImport", snImportBtn)
    snImportBtn:SetPoint("LEFT", snExportBtn, "RIGHT", 8, 0)
    snImportBtn:SetScript("OnClick", function()
        if optionsFrame.ShowShareString then
            optionsFrame.ShowShareString(false, nil, "snippet", function()
                if RefreshSnippetsList then RefreshSnippetsList() end
            end)
        end
    end)


    local createSnippetBtn = CreateModernButton(snTools, L["SNIPPET_CREATE"], 130, 22)
    Options:AddAction("snippetsCreate", createSnippetBtn)
    createSnippetBtn:SetPoint("RIGHT", snTools, "RIGHT", 0, 0)
    createSnippetBtn:SetScript("OnClick", function()
        if ns.Snippets then ns.Snippets:OpenEditor(nil) end
    end)




    createSnippetBtn._label:ClearAllPoints()
    createSnippetBtn._label:SetPoint("CENTER", createSnippetBtn, "CENTER", -9, 0)
    local snTrigCog = ns.CreateCogButton(createSnippetBtn)
    snTrigCog:SetPoint("RIGHT", createSnippetBtn, "RIGHT", -4, 0)
    snTrigCog:SetScript("OnClick", function(self)
        if ns.Snippets and ns.Snippets.ToggleTriggerMenu then
            ns.Snippets.ToggleTriggerMenu(self)
        end
    end)
    Utils.AttachDelayedTooltip(snTrigCog, "ANCHOR_TOP", function()
        if not (ns.Snippets and ns.Snippets.TriggerChar) then return end
        return sformat(L["SNIPPET_TRIGGER"], ns.Snippets.TriggerChar()), L["SNIPPET_TRIGGER_NOTE"]
    end)

    local snSearchShell = CreateFrame("Frame", nil, snTools)
    snSearchShell:SetPoint("LEFT", snTools, "LEFT", 0, 0)
    snSearchShell:SetPoint("RIGHT", createSnippetBtn, "LEFT", -8, 0)
    snSearchShell:SetHeight(22)
    SearchWell(snSearchShell)

    local snSearchIcon = snSearchShell.ringInset:CreateTexture(nil, "OVERLAY")
    snSearchIcon:SetSize(13, 13)
    snSearchIcon:SetPoint("LEFT", snSearchShell, "LEFT", 7, 0)
    snSearchIcon:SetAtlas("common-search-magnifyingglass")

    local snSearchBox = CreateFrame("EditBox", nil, snSearchShell)
    Utils.ReleaseFocusOnOutsideClick(snSearchBox)
    snSearchBox:SetFrameLevel(snSearchShell.ringInset:GetFrameLevel() + 2)
    snSearchBox:SetPoint("LEFT", snSearchIcon, "RIGHT", 6, 0)
    snSearchBox:SetPoint("RIGHT", snSearchShell, "RIGHT", -8, 0)
    snSearchBox:SetHeight(18)
    snSearchBox:SetAutoFocus(false)
    snSearchBox:SetFontObject(SMALL_HIGHLIGHT_FONT)
    snSearchBox:SetMaxLetters(64)

    local snSearchPlaceholder = snSearchBox:CreateFontString(nil, "ARTWORK", OPT_FONTS.GameFontDisableSmall)
    snSearchPlaceholder:SetPoint("LEFT", snSearchBox, "LEFT", 0, 0)
    snSearchPlaceholder:SetText(L["OPT_SEARCH_SNIPPETS_PLACEHOLDER"])
    Utils.StyleSearchHint(snSearchPlaceholder, snSearchIcon)
    snSearchBox:SetScript("OnTextChanged", function(self)
        snSearchPlaceholder:SetShown((self:GetText() or "") == "")
        if RefreshSnippetsList then RefreshSnippetsList() end
    end)
    snSearchBox:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then
            self:SetText("")
        else
            self:ClearFocus()
        end
    end)

    local NAME_LEFT = 10
    local REMOVE_W = 20
    local REMOVE_RIGHT = 4
    local KEYWORD_W = 132
    local HEADER_H = 14
    local HEADER_TOP = 7
    local DIVIDER_Y = HEADER_TOP + HEADER_H + 3
    local SCROLL_TOP = DIVIDER_Y + 4

    local snList = CreateFrame("Frame", nil, snippetsTab)
    snList:SetPoint("TOPLEFT", snShare, "BOTTOMLEFT", 0, -8)
    ctx.AnchorListCardBottom(snList, snippetsTab)
    ns.CreateRoundedRectBorder(snList)
    ns.SetRoundedRectBarHeight(snList, 8)
    HideRoundedFrameBorder(snList)
    ns.ApplyCardFill(snList)

    local snColHeader = CreateFrame("Frame", nil, snList)
    snColHeader:SetSize(FRAME_W - 42, HEADER_H)
    snColHeader:SetPoint("TOPLEFT", snList, "TOPLEFT", 10, -HEADER_TOP)
    local hName = snColHeader:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
    hName:SetText(L["SNIPPET_NAME"])
    hName:SetJustifyH("LEFT")
    hName:SetTextColor(0.92, 0.92, 0.92, 1)
    hName:SetPoint("LEFT", snColHeader, "LEFT", NAME_LEFT, 0)
    local hKeyword = snColHeader:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
    hKeyword:SetText(L["SNIPPET_KEYWORD"])
    hKeyword:SetJustifyH("LEFT")
    hKeyword:SetTextColor(0.92, 0.92, 0.92, 1)
    hKeyword:SetPoint("RIGHT", snColHeader, "RIGHT", -(REMOVE_RIGHT + REMOVE_W + 6), 0)
    hKeyword:SetWidth(KEYWORD_W)

    local snDivider = snList:CreateTexture(nil, "ARTWORK")
    snDivider:SetColorTexture(1, 1, 1, 0.09)
    snDivider:SetHeight(1)
    snDivider:SetPoint("TOPLEFT", snList, "TOPLEFT", 8, -DIVIDER_Y)
    snDivider:SetPoint("TOPRIGHT", snList, "TOPRIGHT", -8, -DIVIDER_Y)

    local snScroll = CreateFrame("ScrollFrame", nil, snList)
    snScroll:SetPoint("TOPLEFT", snList, "TOPLEFT", 6, -SCROLL_TOP)
    snScroll:SetPoint("BOTTOMRIGHT", snList, "BOTTOMRIGHT", -10, 6)

    local snContent = CreateFrame("Frame", nil, snScroll)
    snContent:SetSize(FRAME_W - 42, 1)
    snScroll:SetScrollChild(snContent)

    local snScrollBar = Utils.CreateMinimalScrollBar and Utils.CreateMinimalScrollBar(snScroll, snList)
    ParkScrollBarInMargin(snScrollBar, snList, SCROLL_TOP)
    local snEmpty = snContent:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
    snEmpty:SetPoint("TOPLEFT", snContent, "TOPLEFT", 8, -8)
    snEmpty:SetText(L["OPT_NO_SNIPPETS"])
    snEmpty:SetTextColor(0.92, 0.92, 0.92, 1)

    local snRowPool = {}
    local function ReleaseSnippetRows()
        for i = 1, #snRowPool do snRowPool[i]:Hide() end
    end
    local function UpdateSnippetScrollBar()
        if not snScrollBar then return end
        local contentH = snContent:GetHeight() or 0
        local viewH = snScroll:GetHeight() or 0
        if contentH > viewH + 1 then
            snScrollBar:Show()
            snScrollBar:UpdateThumb(contentH, viewH)
        else
            snScroll:SetVerticalScroll(0)
            snScrollBar:Hide()
        end
    end

    local function AcquireSnippetRow(idx)
        local row = snRowPool[idx]
        if row then row:Show(); return row end
        row = CreateFrame("Button", nil, snContent)
        row:SetSize(FRAME_W - 42, 26)
        row:EnableMouse(true)
        row.bg = CreateFrame("Frame", nil, row)
        row.bg:SetAllPoints()
        row.bg:EnableMouse(false)
        ns.CreateRoundedRectBorder(row.bg)
        ns.SetRoundedRectBarHeight(row.bg, 8)
        HideRoundedFrameBorder(row.bg)
        PaintRoundedFill(row.bg, 1, 1, 1, 0)

        row.removeBtn = CreateModernButton(row, "x", REMOVE_W, 18)
        row.removeBtn:SetPoint("RIGHT", row, "RIGHT", -REMOVE_RIGHT, 0)

        row.keywordText = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
        row.keywordText:SetPoint("RIGHT", row.removeBtn, "LEFT", -6, 0)
        row.keywordText:SetWidth(KEYWORD_W)
        row.keywordText:SetJustifyH("LEFT")
        row.keywordText:SetWordWrap(false)
        ns.ShadeText(row.keywordText)

        row.nameText = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
        row.nameText:SetPoint("LEFT", row, "LEFT", NAME_LEFT, 0)
        row.nameText:SetPoint("RIGHT", row.keywordText, "LEFT", -8, 0)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetWordWrap(false)
        ns.ShadeText(row.nameText)

        row:SetScript("OnEnter", function(self)
            PaintRoundedFill(self.bg, 1, 1, 1, 0.055)
        end)
        row:SetScript("OnLeave", function(self)
            PaintRoundedFill(self.bg, 1, 1, 1, 0)
        end)
        snRowPool[idx] = row
        return row
    end

    RefreshSnippetsList = function()
        ReleaseSnippetRows()
        local query = (snSearchBox and snSearchBox:GetText() or ""):lower()

        local list = (EasyFindDB and EasyFindDB.snippets) or {}
        local entries, total = {}, 0
        for i = 1, #list do
            local snippet = list[i]
            if type(snippet) == "table" and snippet.name then
                total = total + 1
                local keyword = snippet.keyword or ""
                if query == "" or string.find(snippet.name:lower(), query, 1, true)
                   or (keyword ~= "" and string.find(keyword:lower(), query, 1, true)) then
                    entries[#entries + 1] = { index = i, name = snippet.name, keyword = keyword }
                end
            end
        end

        snEmpty:SetText(total == 0 and L["OPT_NO_SNIPPETS"] or L["OPT_NO_BLACKLIST_MATCH"])
        snClearBtn:SetEnabled(total > 0)
        snClearBtn:SetAlpha(total > 0 and 1 or 0.45)
        snEmpty:SetShown(#entries == 0)

        local rowH = 28
        local y = -4
        for i = 1, #entries do
            local e = entries[i]
            local row = AcquireSnippetRow(i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", snContent, "TOPLEFT", 4, y)
            row.nameText:SetText(e.name)
            row.keywordText:SetText(e.keyword)
            row:SetScript("OnClick", function()
                if ns.Snippets then ns.Snippets:OpenEditor(e.index) end
            end)
            row.removeBtn:SetScript("OnClick", function()
                if ns.Snippets then ns.Snippets:DeleteWithConfirm(e.index) end
            end)
            y = y - rowH
        end
        snContent:SetHeight(math.max(32, -y + 4))
        UpdateSnippetScrollBar()
        Utils.SafeAfter(0, UpdateSnippetScrollBar)
    end
    snScroll:SetScript("OnSizeChanged", UpdateSnippetScrollBar)
    snContent:HookScript("OnSizeChanged", UpdateSnippetScrollBar)
    snippetsTab:HookScript("OnShow", RefreshSnippetsList)

    RefreshSnippetsList()

    Options.RefreshSnippetsList = RefreshSnippetsList
end




function Options:OpenAtClipboard()
    self:OpenAtExtension("clipboard")
end



local RefreshQuicklistsPage

local function BuildQuicklistsPage(ctx, page)
    local FRAME_W = ctx.FRAME_W
    local Store = ns.QuicklistStore
    local Quicklists = ns.Quicklists
    local selectedID

    local title = page:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormal)
    title:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -8)
    title:SetText(L["FILTER_QUICKLISTS"])

    local hint = page:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    hint:SetPoint("RIGHT", page, "RIGHT", -10, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L["OPT_QUICKLISTS_HINT"])

    local tools = CreateFrame("Frame", nil, page)
    tools:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
    tools:SetPoint("RIGHT", page, "RIGHT", -8, 0)
    tools:SetHeight(22)
    local newBtn = CreateModernButton(tools, L["QUICKLIST_NEW"], 140, 22)
    Options:AddAction("quicklistsNew", newBtn)
    newBtn:SetPoint("RIGHT", tools, "RIGHT", 0, 0)

    local searchShell = CreateFrame("Frame", nil, tools)
    searchShell:SetPoint("LEFT", tools, "LEFT", 0, 0)
    searchShell:SetPoint("RIGHT", newBtn, "LEFT", -8, 0)
    searchShell:SetHeight(22)
    SearchWell(searchShell)
    local searchIcon = searchShell.ringInset:CreateTexture(nil, "OVERLAY")
    searchIcon:SetSize(13, 13)
    searchIcon:SetPoint("LEFT", searchShell, "LEFT", 7, 0)
    searchIcon:SetAtlas("common-search-magnifyingglass")
    local searchBox = CreateFrame("EditBox", nil, searchShell)
    Utils.ReleaseFocusOnOutsideClick(searchBox)
    searchBox:SetFrameLevel(searchShell.ringInset:GetFrameLevel() + 2)
    searchBox:SetPoint("LEFT", searchIcon, "RIGHT", 6, 0)
    searchBox:SetPoint("RIGHT", searchShell, "RIGHT", -8, 0)
    searchBox:SetHeight(18)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject(SMALL_HIGHLIGHT_FONT)
    searchBox:SetMaxLetters(64)
    local searchPlaceholder = searchBox:CreateFontString(nil, "ARTWORK", OPT_FONTS.GameFontDisableSmall)
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 0, 0)
    searchPlaceholder:SetText(L["OPT_SEARCH_QUICKLISTS_PLACEHOLDER"])
    Utils.StyleSearchHint(searchPlaceholder, searchIcon)
    searchBox:SetScript("OnTextChanged", function(self)
        searchPlaceholder:SetShown((self:GetText() or "") == "")
        if RefreshQuicklistsPage then RefreshQuicklistsPage() end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then
            self:SetText("")
        else
            self:ClearFocus()
        end
    end)
    newBtn:SetScript("OnClick", function()
        if Quicklists then
            Quicklists:PromptNew(function(list)
                selectedID = list.id
                searchBox:SetText("")
            end)
        end
    end)



    local share = CreateFrame("Frame", nil, page)
    share:SetPoint("TOPLEFT", tools, "BOTTOMLEFT", 0, -6)
    share:SetPoint("RIGHT", page, "RIGHT", -8, 0)
    share:SetHeight(22)
    local exportBtn = CreateModernButton(share, L["SHORTKEY_EXPORT"], 92, 22)
    Options:AddAction("quicklistsExport", exportBtn)
    exportBtn:SetPoint("LEFT", share, "LEFT", 0, 0)
    exportBtn:SetScript("OnClick", function()
        local str, leftOut, leftOutRows = "", 0, nil
        if ns.Shortkeys then str, leftOut, leftOutRows = ns.Shortkeys:BuildExportString("quicklist") end
        if optionsFrame.ShowShareString then optionsFrame.ShowShareString(true, str, nil, nil, leftOut, leftOutRows) end
    end)
    local importBtn = CreateModernButton(share, L["SHORTKEY_IMPORT"], 92, 22)
    Options:AddAction("quicklistsImport", importBtn)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
    importBtn:SetScript("OnClick", function()
        if optionsFrame.ShowShareString then
            optionsFrame.ShowShareString(false, nil, "quicklist", function()
                if RefreshQuicklistsPage then RefreshQuicklistsPage() end
            end)
        end
    end)
    local clearBtn = CreateModernButton(share, L["OPT_CLEAR_ALL_BTN"], 78, 22)
    Options:AddAction("quicklistsClear", clearBtn)
    clearBtn:SetPoint("RIGHT", share, "RIGHT", 0, 0)
    clearBtn:SetScript("OnClick", function()
        ns.ShowThemedDialog({
            text = L["POPUP_CLEAR_QUICKLISTS"],
            acceptText = _G["CLEAR"] or "Clear",
            onAccept = function()
                if Store then Store.ClearAll() end
                if Quicklists then Quicklists:Changed() end
            end,
        })
    end)

    local NAME_LEFT = 10
    local BTN_W = 20
    local KEY_W = 116
    local HOLD_W = 52
    local MACRO_W = 60
    local HEADER_H = 14
    local HEADER_TOP = 7
    local DIVIDER_Y = HEADER_TOP + HEADER_H + 3
    local SCROLL_TOP = DIVIDER_Y + 4
    local ROW_H = 28

    local function Card(anchor, header)
        local card = CreateFrame("Frame", nil, page)
        card:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
        card:SetPoint("RIGHT", page, "RIGHT", -8, 0)
        ns.CreateRoundedRectBorder(card)
        ns.SetRoundedRectBarHeight(card, 8)
        HideRoundedFrameBorder(card)
        ns.ApplyCardFill(card)
        card.header = CreateFrame("Frame", nil, card)
        card.header:SetSize(FRAME_W - 42, HEADER_H)
        card.header:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -HEADER_TOP)
        card.title = card.header:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
        card.title:SetJustifyH("LEFT")
        card.title:SetTextColor(0.92, 0.92, 0.92, 1)
        card.title:SetPoint("LEFT", card.header, "LEFT", NAME_LEFT, 0)
        card.title:SetText(header)
        local divider = card:CreateTexture(nil, "ARTWORK")
        divider:SetColorTexture(1, 1, 1, 0.09)
        divider:SetHeight(1)
        divider:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -DIVIDER_Y)
        divider:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -DIVIDER_Y)
        card.scroll = CreateFrame("ScrollFrame", nil, card)
        card.scroll:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -SCROLL_TOP)
        card.scroll:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, 6)
        card.content = CreateFrame("Frame", nil, card.scroll)
        card.content:SetSize(FRAME_W - 42, 1)
        card.scroll:SetScrollChild(card.content)
        card.bar = Utils.CreateMinimalScrollBar and Utils.CreateMinimalScrollBar(card.scroll, card, { moreBelow = true })
        ParkScrollBarInMargin(card.bar, card, SCROLL_TOP)
        card.empty = card.content:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
        card.empty:SetPoint("TOPLEFT", card.content, "TOPLEFT", 8, -8)
        card.empty:SetTextColor(0.92, 0.92, 0.92, 1)
        card.pool = {}
        card.UpdateBar = function()
            if not card.bar then return end
            local contentH = card.content:GetHeight() or 0
            local viewH = card.scroll:GetHeight() or 0
            if contentH > viewH + 1 then
                card.bar:Show()
                card.bar:UpdateThumb(contentH, viewH)
            else
                card.scroll:SetVerticalScroll(0)
                card.bar:Hide()
            end
        end
        card.scroll:SetScript("OnSizeChanged", card.UpdateBar)
        card.content:HookScript("OnSizeChanged", card.UpdateBar)
        return card
    end

    local function NewRow(card, withKey)
        local row = CreateFrame("Button", nil, card.content)
        row:SetSize(FRAME_W - 42, ROW_H - 2)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.bg = CreateFrame("Frame", nil, row)
        row.bg:SetAllPoints()
        row.bg:EnableMouse(false)
        ns.CreateRoundedRectBorder(row.bg)
        ns.SetRoundedRectBarHeight(row.bg, 8)
        HideRoundedFrameBorder(row.bg)
        PaintRoundedFill(row.bg, 1, 1, 1, 0)
        row.removeBtn = CreateModernButton(row, "x", BTN_W, 18)
        row.removeBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.downBtn = CreateModernButton(row, "v", BTN_W, 18)
        row.downBtn:SetPoint("RIGHT", row.removeBtn, "LEFT", -4, 0)
        row.upBtn = CreateModernButton(row, "^", BTN_W, 18)
        row.upBtn:SetPoint("RIGHT", row.downBtn, "LEFT", -2, 0)
        local textRight = row.upBtn
        if withKey then
            row.holdCheck = CreateCheckbox(row, nil, "", L["QUICKLIST_HOLD_TT"], true, HOLD_W)
            row.holdCheck:SetPoint("RIGHT", row.upBtn, "LEFT", -4, 0)
            row.keyBtn = CreateModernButton(row, "", KEY_W, 18)
            row.keyBtn:SetNormalFontObject(OPT_FONTS.GameFontHighlightSmall)
            row.keyBtn:SetHighlightFontObject(OPT_FONTS.GameFontHighlightSmall)
            row.keyBtn:SetPoint("RIGHT", row.holdCheck, "LEFT", -4, 0)
            row.macroBtn = CreateModernButton(row, _G["MACRO"] or "Macro", MACRO_W, 18)
            row.macroBtn:SetNormalFontObject(OPT_FONTS.GameFontHighlightSmall)
            row.macroBtn:SetHighlightFontObject(OPT_FONTS.GameFontHighlightSmall)
            row.macroBtn:SetPoint("RIGHT", row.keyBtn, "LEFT", -4, 0)

            row.macroBtn:HookScript("OnEnter", function(self)
                ns.ShowHintTooltip(self, "ANCHOR_TOP", nil, L["QUICKLIST_MACRO_TT"])
            end)
            row.macroBtn:HookScript("OnLeave", function(self) ns.HideHintTooltip(self) end)
            textRight = row.macroBtn
        end
        row.nameText = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
        row.nameText:SetPoint("LEFT", row, "LEFT", NAME_LEFT, 0)
        row.nameText:SetPoint("RIGHT", textRight, "LEFT", -8, 0)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetWordWrap(false)
        ns.ShadeText(row.nameText)
        row:SetScript("OnEnter", function(self)
            if not self.selected then PaintRoundedFill(self.bg, 1, 1, 1, 0.055) end
        end)
        row:SetScript("OnLeave", function(self)
            if not self.selected then PaintRoundedFill(self.bg, 1, 1, 1, 0) end
        end)
        return row
    end

    local function AcquireRow(card, idx, withKey)
        local row = card.pool[idx]
        if not row then
            row = NewRow(card, withKey)
            card.pool[idx] = row
        end
        row:Show()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", card.content, "TOPLEFT", 4, -4 - (idx - 1) * ROW_H)
        return row
    end

    local function FinishCard(card, shown, emptyText)
        for i = shown + 1, #card.pool do card.pool[i]:Hide() end
        card.empty:SetText(emptyText)
        card.empty:SetShown(shown == 0)


        local rowsH, view = shown * ROW_H, card.scroll:GetHeight() or 0
        card.content:SetHeight(rowsH > view and rowsH + 8 or math.max(32, view))
        card.UpdateBar()
        Utils.SafeAfter(0, card.UpdateBar)
    end

    local listsCard = Card(share, L["FILTER_QUICKLISTS"])

    listsCard:SetHeight(SCROLL_TOP + 3 * ROW_H + 14)
    local keyHeader = listsCard.header:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
    keyHeader:SetJustifyH("LEFT")
    keyHeader:SetTextColor(0.92, 0.92, 0.92, 1)
    keyHeader:SetPoint("RIGHT", listsCard.header, "RIGHT", -(4 + BTN_W * 3 + 10 + HOLD_W + 4 + 8), 0)
    keyHeader:SetWidth(KEY_W)
    keyHeader:SetText(L["QUICKLIST_COL_KEY"])
    local holdHeader = listsCard.header:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
    holdHeader:SetJustifyH("LEFT")
    holdHeader:SetTextColor(0.92, 0.92, 0.92, 1)
    holdHeader:SetPoint("LEFT", keyHeader, "RIGHT", 4, 0)
    holdHeader:SetText(L["QUICKLIST_COL_HOLD"])

    local itemsCard = Card(listsCard, "")
    ctx.AnchorListCardBottom(itemsCard, page)

    local function Matches(text, query)
        return query == "" or (text and string.find(text:lower(), query, 1, true)) ~= nil
    end


    local function ListMatches(list, query)
        if Matches(list.name, query) then return true end
        for i = 1, #list.items do
            if Matches(list.items[i].n or list.items[i].k, query) then return true end
        end
        return false
    end

    RefreshQuicklistsPage = function()
        if not Store then return end
        local query = (searchBox:GetText() or ""):lower()
        local lists = Store.All()
        local shown = {}
        for i = 1, #lists do
            if ListMatches(lists[i], query) then shown[#shown + 1] = lists[i] end
        end
        local selectedShown
        for i = 1, #shown do
            if shown[i].id == selectedID then selectedShown = true end
        end
        if not selectedShown then selectedID = shown[1] and shown[1].id or nil end
        clearBtn:SetEnabled(#lists > 0)
        clearBtn:SetAlpha(#lists > 0 and 1 or 0.45)
        for i = 1, #shown do
            local list = shown[i]
            local id = list.id
            local row = AcquireRow(listsCard, i, true)
            row.selected = id == selectedID
            PaintRoundedFill(row.bg, 1, 1, 1, row.selected and 0.10 or 0)
            row.nameText:SetText(list.name)
            row.keyBtn:SetText(list.key or L["SHORTKEY_CLICK_TO_BIND"])
            row.keyBtn:SetScript("OnClick", function()
                if Quicklists then Quicklists:PromptForKey(id, RefreshQuicklistsPage) end
            end)
            row.macroBtn:SetScript("OnClick", function()
                if Quicklists then Quicklists:CreateMacro(id) end
            end)
            row.holdCheck:SetChecked(list.hold and true or false)
            row.holdCheck:SetScript("OnClick", function(self)
                Store.SetHold(id, self:GetChecked())
                if self.RefreshVisual then self:RefreshVisual() end
            end)
            row.upBtn:SetScript("OnClick", function()
                if Store.Move(id, -1) and Quicklists then Quicklists:Changed() end
            end)
            row.downBtn:SetScript("OnClick", function()
                if Store.Move(id, 1) and Quicklists then Quicklists:Changed() end
            end)
            row.removeBtn:SetScript("OnClick", function()
                if Quicklists then Quicklists:DeleteWithConfirm(id) end
            end)
            row:SetScript("OnClick", function(_, button)
                if button == "RightButton" then
                    if Quicklists then Quicklists:PromptRename(id) end
                    return
                end
                selectedID = id
                RefreshQuicklistsPage()
            end)
        end
        FinishCard(listsCard, #shown, #lists == 0 and L["OPT_NO_QUICKLISTS"] or L["OPT_NO_BLACKLIST_MATCH"])

        local selected = Store.Get(selectedID)
        local items = selected and selected.items or {}
        itemsCard.title:SetText(selected and sformat(L["QUICKLIST_ITEMS_FMT"], selected.name) or "")

        local wholeList = selected and Matches(selected.name, query)
        local count = 0
        for i = 1, #items do
            local item = items[i]
            if wholeList or Matches(item.n or item.k, query) then
                count = count + 1
                local row = AcquireRow(itemsCard, count, false)
                row.selected = nil
                PaintRoundedFill(row.bg, 1, 1, 1, 0)
                row.nameText:SetText(item.n or item.k)
                row.upBtn:SetScript("OnClick", function()
                    if Store.MoveItem(selectedID, i, -1) and Quicklists then Quicklists:Changed() end
                end)
                row.downBtn:SetScript("OnClick", function()
                    if Store.MoveItem(selectedID, i, 1) and Quicklists then Quicklists:Changed() end
                end)
                row.removeBtn:SetScript("OnClick", function()
                    if Store.Remove(selectedID, item.k) and Quicklists then Quicklists:Changed() end
                end)
                row:SetScript("OnClick", nil)
            end
        end
        FinishCard(itemsCard, count, selected and L["QUICKLIST_NO_ITEMS"]
            or (#shown > 0 or query == "") and L["QUICKLIST_SELECT_HINT"] or "")
    end
    page:HookScript("OnShow", RefreshQuicklistsPage)

    RefreshQuicklistsPage()
end

function Options:RefreshQuicklistsPage()
    if RefreshQuicklistsPage and optionsFrame and optionsFrame:IsShown() then RefreshQuicklistsPage() end
end

function Options:OpenAtQuicklists()
    self:OpenAtExtension("quicklists")
end








local extensionsTab, extensionStrip, extensionHint
local extensionPages = {}
local extensionCurrent
local extensionCtx



local function BuildExtensionsMenuPage(ctx, page)
    local AppsMenu = ns.AppsMenu
    local title = page:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormal)
    title:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -8)
    title:SetText(L["OPT_EXT_MENU_PAGE"])
    local hint = page:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    hint:SetPoint("RIGHT", page, "RIGHT", -10, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L["OPT_EXT_MENU_HINT"])
    local function S() return AppsMenu.Settings() end
    local function Changed() if AppsMenu.Rebuild then AppsMenu:Rebuild() end end
    local rowsPer = {}
    for i, n in ipairs(AppsMenu.ROWS_CHOICES) do rowsPer[i] = { label = tostring(n), value = n } end
    local columnsRow = ctx.CreateFlyoutPresetRow(page, L["OPT_EXT_ROWS"], rowsPer,
        function() return S().rows end, function(v) S().rows = v Changed() end,
        "EasyFindExtMenuRows", AppsMenu.ROWS_DEFAULT)
    columnsRow:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -8, -10)
    local labels = {}
    for _, pos in ipairs(AppsMenu.LABEL_POSITIONS) do
        labels[#labels + 1] = { label = L["OPT_EXT_LABEL_" .. pos:upper()], value = pos }
    end
    local labelsRow = ctx.CreateFlyoutPresetRow(page, L["OPT_EXT_LABELS"], labels,
        function() return S().labels end, function(v) S().labels = v Changed() end,
        "EasyFindExtMenuLabels", "right")
    labelsRow:SetPoint("TOPLEFT", columnsRow, "BOTTOMLEFT", 0, -4)
    local sizes = {}
    for _, size in ipairs(AppsMenu.LABEL_SIZES) do sizes[#sizes + 1] = { label = L[size[1]], value = size[2] } end
    local sizeRow = ctx.CreateFlyoutPresetRow(page, L["OPT_EXT_LABEL_SIZE"], sizes,
        function() return S().labelSize end, function(v) S().labelSize = v Changed() end,
        "EasyFindExtMenuLabelSize", 1)
    sizeRow:SetPoint("TOPLEFT", labelsRow, "BOTTOMLEFT", 0, -4)
    local iconSizes = {}
    for _, size in ipairs(AppsMenu.ICON_SIZES) do iconSizes[#iconSizes + 1] = { label = L[size[1]], value = size[2] } end
    local iconRow = ctx.CreateFlyoutPresetRow(page, L["OPT_EXT_ICON_SIZE"], iconSizes,
        function() return S().iconSize end, function(v) S().iconSize = v Changed() end,
        "EasyFindExtMenuIconSize", 1)
    iconRow:SetPoint("TOPLEFT", sizeRow, "BOTTOMLEFT", 0, -4)
    local sortBtn = CreateModernButton(page, L["OPT_EXT_SORT_NAME"], 120, 22)
    sortBtn:SetPoint("TOPLEFT", iconRow, "BOTTOMLEFT", 8, -10)
    sortBtn:SetScript("OnClick", function() S().order = nil Changed() end)
    Utils.AttachDelayedTooltip(sortBtn, "ANCHOR_TOP", function() return L["OPT_EXT_SORT_NAME_TT"] end)



    local shownTitle = page:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormal)
    shownTitle:SetPoint("TOPLEFT", sortBtn, "BOTTOMLEFT", -8, -16)
    shownTitle:SetText(L["OPT_EXT_SHOWN"])
    local shownHint = page:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    shownHint:SetPoint("TOPLEFT", shownTitle, "BOTTOMLEFT", 0, -4)
    shownHint:SetPoint("RIGHT", page, "RIGHT", -10, 0)
    shownHint:SetJustifyH("LEFT")
    shownHint:SetText(L["OPT_EXT_SHOWN_HINT"])
    local colW = math.floor(ctx.SELECTOR_ROW_W / 2)
    local boxes = {}
    local function ShownBox(id, name)
        local box = boxes[id]
        if box then return box end
        box = ctx.CreateCheckbox(page, nil, name, nil, true, colW)
        box:SetScript("OnClick", function(self)
            if self.RefreshVisual then self:RefreshVisual() end
            AppsMenu:SetHidden(id, not self:GetChecked())
        end)
        boxes[id] = box
        return box
    end
    local function RefreshShown()
        local apps = ns.BuildApplicationEntries and ns.BuildApplicationEntries() or {}
        table.sort(apps, function(a, b) return (a.name or "") < (b.name or "") end)
        for _, box in pairs(boxes) do box:Hide() end
        local n = 0
        for _, app in ipairs(apps) do
            local id = ns.ApplicationEntryID(app)
            if id then
                local box = ShownBox(id, app.name or id)
                box:ClearAllPoints()
                box:SetPoint("TOPLEFT", shownHint, "BOTTOMLEFT", -8 + (n % 2) * colW, -(6 + math.floor(n / 2) * 22))
                box:SetChecked(not AppsMenu:IsHidden(id))
                if box.RefreshVisual then box:RefreshVisual() end
                box:Show()
                n = n + 1
            end
        end
    end
    RefreshShown()
    page:HookScript("OnShow", RefreshShown)
    AppsMenu.hiddenChanged = function() if page:IsVisible() then RefreshShown() end end
end

local function ExtensionPageDefs()
    local defs = {}
    if ns.AppsMenu then
        defs[#defs + 1] = { id = "menu", name = L["OPT_EXT_MENU_PAGE"], core = true, build = BuildExtensionsMenuPage,
            reset = function()
                local s = ns.AppsMenu.Settings()
                s.rows, s.labels, s.labelSize, s.iconSize, s.order, s.hidden = nil, nil, nil, nil, nil, nil
                if ns.AppsMenu.Rebuild then ns.AppsMenu:Rebuild() end
                if ns.AppsMenu.hiddenChanged then ns.AppsMenu.hiddenChanged() end
            end }
    end
    if not (ns.IsCompanionLoadable and not ns.IsCompanionLoadable("EasyFind_Snippets")) then
        defs[#defs + 1] = { id = "snippets", name = L["FILTER_SNIPPETS"], icon = ns.SNIPPET_ICON_TEX,
            coords = ns.SNIPPET_ICON_COORDS, core = true, fills = true, build = BuildSnippetsPage }
    end
    if not (ns.IsCompanionLoadable and not ns.IsCompanionLoadable("EasyFind_Quicklists")) then
        defs[#defs + 1] = { id = "quicklists", name = L["FILTER_QUICKLISTS"], icon = ns.QUICKLIST_ICON_TEX,
            core = true, fills = true, build = BuildQuicklistsPage }
    end
    for _, def in ipairs(ns.ExtensionPages or {}) do
        if not (def.companion and ns.IsCompanionLoadable and not ns.IsCompanionLoadable(def.companion)) then
            defs[#defs + 1] = def
        end
    end
    return defs
end





local function ScrollingPage(holder)
    local scroll = CreateFrame("ScrollFrame", nil, holder)
    scroll:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)


    scroll:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -12, 14)
    local page = CreateFrame("Frame", nil, scroll)
    page:SetSize(1, 1)
    scroll:SetScrollChild(page)
    local bar = Utils.CreateMinimalScrollBar and Utils.CreateMinimalScrollBar(scroll, holder, { moreBelow = true })

    if bar then
        bar:ClearAllPoints()
        bar:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -2, -4)
        bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -2, 4)
    end
    local function Fit()
        page:SetWidth(scroll:GetWidth())
        local top, low = page:GetTop(), nil
        if not top then return end
        local function Lower(region)
            local bottom = region:IsShown() and region:GetBottom()
            if bottom and (not low or bottom < low) then low = bottom end
        end
        for _, kid in ipairs({ page:GetChildren() }) do Lower(kid) end
        for _, region in ipairs({ page:GetRegions() }) do Lower(region) end


        local view = scroll:GetHeight() or 0
        local height = low and (top - low) or 1
        height = height > view and height + 12 or math.max(1, view)
        page:SetHeight(height)
        if not bar then return end
        if height > view + 1 then
            bar:Show()
            bar:UpdateThumb(height, view)
        else
            scroll:SetVerticalScroll(0)
            bar:Hide()
        end
    end
    scroll:SetScript("OnSizeChanged", Fit)
    holder:SetScript("OnShow", function() Utils.SafeAfter(0, Fit) end)

    holder.Reveal = function(target)
        local top, at = page:GetTop(), target and target.GetTop and target:GetTop()
        if not (top and at) then return end
        local most = math.max(0, page:GetHeight() - (scroll:GetHeight() or 0))
        scroll:SetVerticalScroll(math.min(most, math.max(0, top - at - 8)))
    end
    return page, Fit
end

local function EnsureExtensionPage(entry)
    if entry.frame then return entry.frame end
    local holder = CreateFrame("Frame", nil, extensionsTab)
    holder:SetPoint("TOPLEFT", extensionStrip, "BOTTOMLEFT", 0, -8)
    holder:SetPoint("BOTTOMRIGHT", extensionsTab, "BOTTOMRIGHT", 0, 0)
    entry.frame = holder
    if entry.def.core and not entry.def.fills then
        local page, Fit = ScrollingPage(holder)
        entry.def.build(extensionCtx, page)
        Utils.SafeAfter(0, Fit)
    elseif entry.def.core then
        entry.def.build(extensionCtx, holder)
    else


        local page, Fit = ScrollingPage(holder)
        entry.def.build(page, extensionCtx)
        Utils.SafeAfter(0, Fit)
    end

    if ns.RetintPanelText then ns.RetintPanelText(holder) end
    return holder
end

local function SelectExtensionPage(id)
    if optionsFrame and optionsFrame.ClearPageSearch and id ~= extensionCurrent then optionsFrame.ClearPageSearch() end
    extensionCurrent = id
    if ns.SettingsRows then ns.SettingsRows.extensionPage = id end
    for _, entry in ipairs(extensionPages) do
        local on = entry.def.id == id
        if on then
            EnsureExtensionPage(entry)
            extensionsTab.currentEntry = entry
        end
        if entry.frame then entry.frame:SetShown(on) end
    end
    if extensionsTab and extensionsTab.picker then extensionsTab.picker.Refresh() end

    local reset = extensionsTab and extensionsTab.resetBtn
    if reset then
        local can = extensionsTab.currentEntry ~= nil and extensionsTab.currentEntry.def.reset ~= nil
        reset:SetEnabled(can)
        reset:SetAlpha(can and 1 or 0.5)
    end
end



local function LayoutExtensionReset(anchor)
    local reset = extensionsTab.resetBtn
    if not reset then
        local measure = extensionStrip.measure
        measure:SetText(L["OPT_EXT_RESET"])
        reset = CreateModernButton(extensionStrip, L["OPT_EXT_RESET"], math.ceil(measure:GetStringWidth() or 0) + 24, 22)
        reset:SetScript("OnClick", function()
            local entry = extensionsTab.currentEntry
            if not (entry and entry.def.reset) then return end
            ShowResetConfirm(sformat(L["POPUP_RESET_EXTENSION"], entry.def.name or entry.def.id), function()
                entry.def.reset()
                Options:SyncControls()
            end)
        end)
        Utils.AttachDelayedTooltip(reset, "ANCHOR_TOP", function()
            local entry = extensionsTab.currentEntry
            return (entry and entry.def.reset) and L["OPT_EXT_RESET_TT"] or L["OPT_EXT_RESET_NONE_TT"]
        end)
        extensionsTab.resetBtn = reset
    end
    reset:ClearAllPoints()
    reset:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
end

local function RevealOnExtensionPage(id, target)
    for _, entry in ipairs(extensionPages) do
        if entry.def.id == id and entry.frame and entry.frame.Reveal then entry.frame.Reveal(target) end
    end
end


local function EnsureAllExtensionPages()
    for _, entry in ipairs(extensionPages) do
        EnsureExtensionPage(entry)
        entry.frame:SetShown(entry.def.id == extensionCurrent)
    end
end





local pickerSerial = 0
local function LayoutExtensionPicker()
    local defs = ExtensionPageDefs()
    local byID = {}
    for _, entry in ipairs(extensionPages) do byID[entry.def.id] = entry end
    local ordered = {}
    for _, def in ipairs(defs) do
        local entry = byID[def.id]
        if not entry then
            entry = { def = def }
            extensionPages[#extensionPages + 1] = entry
        end
        entry.def = def
        ordered[#ordered + 1] = entry
    end
    if extensionsTab.picker then
        extensionsTab.picker.button:Hide()
        extensionsTab.picker.flyout:Hide()
        extensionsTab.picker = nil
    end
    extensionHint:SetShown(#ordered == 0)
    if #ordered == 0 then return end
    local values, names = {}, {}
    for _, entry in ipairs(ordered) do
        values[#values + 1] = entry.def.id
        names[entry.def.id] = entry.def.name or entry.def.id
    end
    local found = false
    for _, entry in ipairs(ordered) do
        if entry.def.id == extensionCurrent then found = true end
    end
    if not found then extensionCurrent = ordered[1].def.id end
    local function LabelFor(id) return names[id] or tostring(id) end
    local measure = extensionStrip.measure
    local widest = 0
    for _, id in ipairs(values) do
        measure:SetText(LabelFor(id))
        widest = mmax(widest, measure:GetStringWidth() or 0)
    end
    local width = math.ceil(widest) + 8 + 18 + 6
    pickerSerial = pickerSerial + 1
    local prefix = "EasyFindExtensionPick" .. pickerSerial
    local btnFrame, btnText = CreateFlyoutSelector(extensionStrip, prefix, width,
        extensionStrip.title, LabelFor(extensionCurrent))
    btnFrame:ClearAllPoints()
    btnFrame:SetPoint("LEFT", extensionStrip.title, "RIGHT", 10, 0)
    LayoutExtensionReset(btnFrame)
    local flyout = CreateFlyoutPanel(btnFrame, prefix, width, #values)
    AddFlyoutOptions(flyout, values, width - 6, function(id)
        SelectExtensionPage(id)
    end, LabelFor)
    extensionsTab.picker = {
        button = btnFrame, flyout = flyout,
        Refresh = function() btnText:SetText(LabelFor(extensionCurrent)) end,
    }
    SelectExtensionPage(extensionCurrent)
end

local function BuildExtensionsTab(ctx)
    local CreateTab = ctx.CreateTab
    extensionsTab = CreateTab(L["FILTER_EXTENSIONS"])
    extensionCtx = ctx
    extensionCurrent = ns.SettingsRows and ns.SettingsRows.extensionPage or extensionCurrent
    Options._extensionsTabIndex = extensionsTab.tabIndex

    extensionStrip = CreateFrame("Frame", nil, extensionsTab)
    extensionStrip:SetPoint("TOPLEFT", extensionsTab, "TOPLEFT", 8, -8)
    extensionStrip:SetPoint("RIGHT", extensionsTab, "RIGHT", -8, 0)
    extensionStrip:SetHeight(24)
    local title = extensionStrip:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormal)
    title:SetPoint("LEFT", extensionStrip, "LEFT", 0, 0)
    title:SetText(L["FILTER_EXTENSIONS"])
    extensionStrip.title = title
    extensionStrip.measure = extensionStrip:CreateFontString(nil, "ARTWORK", OPT_FONTS.GameFontHighlightSmall)
    extensionStrip.measure:Hide()
    extensionHint = extensionsTab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    extensionHint:SetPoint("TOPLEFT", extensionStrip, "BOTTOMLEFT", 0, -6)
    extensionHint:SetPoint("RIGHT", extensionsTab, "RIGHT", -10, 0)
    extensionHint:SetJustifyH("LEFT")
    extensionHint:SetText(L["OPT_EXTENSIONS_HINT"])
    LayoutExtensionPicker()
end


function Options:RefreshExtensionPages()
    if extensionsTab and extensionCtx then LayoutExtensionPicker() end
end

function Options:AddAction(key, btn)
    optionsFrame.actions = optionsFrame.actions or {}
    optionsFrame.actions[key] = btn
end



function Options:RunAction(key, tab, pageID)
    self:OpenAtSetting(tab, pageID, nil)
    local btn = optionsFrame and optionsFrame.actions and optionsFrame.actions[key]
    if btn and btn:IsShown() and btn:IsEnabled() then btn:Click() end
end

function Options:RefreshProfilesTab()
    if optionsFrame and optionsFrame.RefreshProfilesTab then optionsFrame.RefreshProfilesTab() end
end


function Options:SyncControls()
    if not optionsFrame then return end
    pcall(SyncOptionControls)
    if optionsFrame:IsShown() then
        if ns.RegisterAddonFontsIn then ns.RegisterAddonFontsIn(optionsFrame) end
        optionsFrame:RepaintTheme()
    end
end

function Options:SelectExtensionPage(id)
    if extensionsTab then SelectExtensionPage(id) end
end

function Options:ShowResultKind(key)
    if optionsFrame and optionsFrame.ShowResultKind then optionsFrame.ShowResultKind(key) end
end


local function LabelMatches(label, name)
    label = label:gsub(":%s*$", "")
    if label == name then return true end
    local cut = label:match("^(.-)%.%.%.$")
    return cut ~= nil and cut ~= "" and name:sub(1, #cut) == cut
end


function Options:OpenAtSetting(tab, pageID, name)
    self:Show()
    if not (optionsFrame and optionsFrame.SettingsIndex) then return end
    local first
    for _, hit in ipairs(optionsFrame.SettingsIndex()) do
        if optionsFrame.TabName(hit.tab) == tab and (pageID == nil or hit.pageID == pageID) then
            if name and LabelMatches(hit.label, name) then
                optionsFrame.JumpToSetting(hit)
                return
            end
            first = first or hit
        end
    end
    if first then optionsFrame.JumpToSetting(first) end
end




local function ControlOf(target)
    if target._efControl then return target._efControl end
    local kind = target.GetObjectType and target:GetObjectType()
    if kind == "CheckButton" then
        return {
            kind = "check", tooltip = target._efTooltip,
            get = function() return target:GetChecked() and true or false end,
            set = function(on)
                if target:IsEnabled() and (target:GetChecked() and true or false) ~= on then target:Click() end
            end,
        }
    elseif kind == "Button" and target:GetScript("OnClick") then
        return { kind = "button", press = function() if target:IsEnabled() then target:Click() end end }
    end
    return nil
end



function Options:SettingsIndexRows()
    self:Initialize()
    if not (optionsFrame and optionsFrame.SettingsIndex) then return nil end
    local rows = {}
    for _, hit in ipairs(optionsFrame.SettingsIndex()) do
        local path = { optionsFrame.TabName(hit.tab) }
        if hit.pageName then path[2] = hit.pageName end


        local control = ControlOf(hit.target)
        if control then rows[#rows + 1] = {
            name = (hit.label:gsub(":%s*$", "")), path = path, control = control,
            open = function()
                Options:Show()
                optionsFrame.JumpToSetting(hit)
            end,
        } end
    end
    return rows
end

function Options:ExtensionPageFrames()
    if not extensionsTab then return {} end
    EnsureAllExtensionPages()
    local out = {}
    for _, entry in ipairs(extensionPages) do
        if entry.frame then out[#out + 1] = { id = entry.def.id, name = entry.def.name, frame = entry.frame } end
    end
    return out
end

function Options:OpenAtExtension(id)
    self:Show()
    if optionsFrame and optionsFrame.SwitchToTab and self._extensionsTabIndex then
        optionsFrame.SwitchToTab(self._extensionsTabIndex)
    end
    if extensionsTab and id then SelectExtensionPage(id) end

    if id == "snippets" and ns.FeatureSpotlight then ns.FeatureSpotlight:Complete("snippets31") end
end


function Options:CurrentExtensionPage()
    if not extensionsTab then return nil end
    local shown = optionsFrame and self._extensionsTabIndex and extensionsTab:IsShown()
    return shown and extensionCurrent or nil
end




local ROWACT_ROW_H, ROWACT_BTN_W = 26, 116
local function BuildRowActionsList(ctx, tab, above)
    local RowActions = ns.ResultRowActions
    if not RowActions then return end
    local header = tab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormal)
    header:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -18)
    header:SetText(L["OPT_ROWACT_HEADER"])
    local hint = tab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    hint:SetPoint("RIGHT", tab, "RIGHT", -12, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(L["OPT_ROWACT_HINT"])


    local searchShell = CreateFrame("Frame", nil, tab)
    searchShell:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -4, -8)
    searchShell:SetPoint("RIGHT", tab, "RIGHT", -ctx.LIST_CARD_SIDE_INSET, 0)
    searchShell:SetHeight(22)
    SearchWell(searchShell)
    local searchIcon = searchShell.ringInset:CreateTexture(nil, "OVERLAY")
    searchIcon:SetSize(13, 13)
    searchIcon:SetPoint("LEFT", searchShell, "LEFT", 7, 0)
    searchIcon:SetAtlas("common-search-magnifyingglass")
    local searchBox = CreateFrame("EditBox", nil, searchShell)
    Utils.ReleaseFocusOnOutsideClick(searchBox)
    searchBox:SetFrameLevel(searchShell.ringInset:GetFrameLevel() + 2)
    searchBox:SetPoint("LEFT", searchIcon, "RIGHT", 6, 0)
    searchBox:SetPoint("RIGHT", searchShell, "RIGHT", -8, 0)
    searchBox:SetHeight(18)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject(SMALL_HIGHLIGHT_FONT)
    searchBox:SetMaxLetters(64)
    local placeholder = searchBox:CreateFontString(nil, "ARTWORK", OPT_FONTS.GameFontDisableSmall)
    placeholder:SetPoint("LEFT", searchBox, "LEFT", 0, 0)
    placeholder:SetPoint("RIGHT", searchBox, "RIGHT", 0, 0)
    placeholder:SetJustifyH("LEFT")
    placeholder:SetWordWrap(false)
    placeholder:SetText(L["OPT_SEARCH_ROWACT_PLACEHOLDER"])
    Utils.StyleSearchHint(placeholder, searchIcon)

    local card = CreateFrame("Frame", nil, tab)
    card:SetPoint("TOPLEFT", searchShell, "BOTTOMLEFT", 0, -6)
    ctx.AnchorListCardBottom(card, tab)
    ns.CreateRoundedRectBorder(card)
    ns.SetRoundedRectBarHeight(card, 8)
    HideRoundedFrameBorder(card)
    ns.ApplyCardFill(card)
    local scroll = CreateFrame("ScrollFrame", nil, card)
    scroll:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, 6)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    local bar = Utils.CreateMinimalScrollBar and Utils.CreateMinimalScrollBar(scroll, card)
    ParkScrollBarInMargin(bar, card, 2)
    local empty = content:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
    empty:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
    empty:SetText(L["OPT_NO_BLACKLIST_MATCH"])
    empty:SetTextColor(0.92, 0.92, 0.92, 1)

    local rows = {}

    optionsFrame.rowActionRows = rows
    local function KeyText(id)
        return RowActions.ChordText(RowActions.KeyOf(id)) or (_G["NOT_BOUND"] or "Not Bound")
    end
    local function Refresh()
        for _, row in ipairs(rows) do
            if row:IsShown() then row.keyBtn:SetText(KeyText(row.actionId)) end
        end
    end
    local function StopCapture(btn)
        btn.waitingForKey = false
        btn:UnlockHighlight()
        Utils.DisarmBindingCapture(btn)
        Refresh()
    end
    local function MakeRow(i)
        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(ROWACT_ROW_H)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROWACT_ROW_H)
        row:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.keyBtn = CreateModernButton(row)
        row.keyBtn:SetNormalFontObject(OPT_FONTS.GameFontHighlightSmall)
        row.keyBtn:SetHighlightFontObject(OPT_FONTS.GameFontHighlightSmall)
        ns.StyleBgFillButton(row.keyBtn)
        row.keyBtn:SetSize(ROWACT_BTN_W, 20)
        row.keyBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.label = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalSmall)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        row.label:SetTextColor(Utils.RGB(NORMAL_TEXT, 1))
        row.keyBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.keyBtn:SetScript("OnClick", function(btn, button)

            if ns._efFlyoutClosedAt and GetTime() - ns._efFlyoutClosedAt < 0.30 then return end
            if button == "RightButton" then
                if btn.waitingForKey then StopCapture(btn) end
                RowActions.Set(row.actionId, nil)
                Refresh()
                return
            end
            if btn.waitingForKey then

                local combo = Utils.ModifierCombo("CLICK")
                if combo ~= "CLICK" then
                    local refusal = RowActions.Refusal(combo)
                    if refusal then
                        ns.ShowHintTooltip(btn, "ANCHOR_RIGHT", RowActions.ChordText(combo), refusal)
                        return
                    end
                    RowActions.Set(row.actionId, combo)
                end
                StopCapture(btn)
                return
            end
            btn.waitingForKey = true
            btn:SetText(L["OPT_KB_PRESS_KEY"])
            btn:LockHighlight()
            Utils.ArmBindingCapture(btn, function(self, combo)
                if combo == "stop" then
                    StopCapture(self)
                    return
                end
                local refusal = RowActions.Refusal(combo)
                if refusal then
                    ns.ShowHintTooltip(self, "ANCHOR_RIGHT", RowActions.ChordText(combo), refusal)
                    return
                end
                RowActions.Set(row.actionId, combo)
                StopCapture(self)
            end)
        end)
        Utils.AttachDelayedTooltip(row.keyBtn, "ANCHOR_RIGHT", function()
            return row.label:GetText(), nil, L["OPT_KB_CLEAR_HINT"]
        end)
        rows[i] = row
        return row
    end

    local shown = {}
    local function Build()
        local query = (searchBox:GetText() or ""):lower()
        local list = shown
        wipe(list)
        for _, action in ipairs(RowActions.List()) do
            if query == "" or action.label:lower():find(query, 1, true)
                or KeyText(action.id):lower():find(query, 1, true) then
                list[#list + 1] = action
            end
        end
        empty:SetShown(#list == 0)
        for i, action in ipairs(list) do
            local row = rows[i] or MakeRow(i)
            row.actionId = action.id
            row.label:SetText(action.label)

            row.label:ClearAllPoints()
            if action.icon then
                Utils.SetIconTexture(row.icon, action.icon)
                if action.iconCoords then row.icon:SetTexCoord(unpack(action.iconCoords)) else row.icon:SetTexCoord(0, 1, 0, 1) end
                row.icon:Show()
                row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            else
                row.icon:Hide()
                row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
            end
            row.label:SetPoint("RIGHT", row.keyBtn, "LEFT", -8, 0)
            row:Show()
        end
        for i = #list + 1, #rows do rows[i]:Hide() end
        content:SetHeight(math.max(#list, 1) * ROWACT_ROW_H)
        content:SetWidth(scroll:GetWidth() or 1)
        Refresh()
        if bar then
            local viewH = scroll:GetHeight() or 0
            if content:GetHeight() > viewH + 1 then
                bar:Show()
                bar:UpdateThumb(content:GetHeight(), viewH)
            else
                scroll:SetVerticalScroll(0)
                bar:Hide()
            end
        end
    end
    tab:HookScript("OnShow", Build)
    scroll:SetScript("OnSizeChanged", Build)
    searchBox:SetScript("OnTextChanged", function(self)
        placeholder:SetShown((self:GetText() or "") == "")
        scroll:SetVerticalScroll(0)
        Build()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then
            self:SetText("")
        else
            self:ClearFocus()
        end
    end)
end





local function BuildResultClicksTab(ctx)
    local CreateTab, CreateFlyoutPresetRow, RESET_BTN_W = ctx.CreateTab, ctx.CreateFlyoutPresetRow, ctx.RESET_BTN_W
    local Gestures = ns.ResultGestures
    local tab = CreateTab(L["OPT_TAB_RESULT_CLICKS"])
    local hint = tab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    hint:SetPoint("TOPLEFT", tab, "TOPLEFT", 12, -10)
    hint:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -12, -10)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(L["OPT_RESULT_CLICKS_HINT"])
    local SettingsRows = ns.SettingsRows
    local KIND_LABEL = SettingsRows.ResultKindLabels()
    local kinds = Gestures.Kinds()
    local kindChoices = {}
    for i = 1, #kinds do kindChoices[i] = { value = kinds[i].key, label = KIND_LABEL[kinds[i].key] } end
    local current = SettingsRows.ResultKind()
    local gestureRows, shiftLine, reset = {}, nil, nil
    local shiftRow = #Gestures.GESTURES
    local function ShowKind(kind)
        current = kind
        SettingsRows.resultKind = kind.key
        for i = 1, #Gestures.GESTURES do
            gestureRows[i]:SetChoices(Gestures.Choices(kind))
            gestureRows[i]:SetValue(Gestures.Get(kind.key, Gestures.GESTURES[i]))
        end

        local drag = kind.defaults.shift
        gestureRows[shiftRow]:SetShown(drag == nil)
        shiftLine:SetShown(drag ~= nil)
        if drag then shiftLine:SetText("Shift: " .. Gestures.V[kind.byAction[drag].word]) end
        reset:ClearAllPoints()
        reset:SetPoint("TOPLEFT", drag and shiftLine or gestureRows[shiftRow], "BOTTOMLEFT", drag and -8 or 0, -12)
    end
    local kindRow = CreateFlyoutPresetRow(tab, L["OPT_RESULT_KIND"], kindChoices,
        function() return current.key end,
        function(v) ShowKind(Gestures.Kind(v)) end, "EasyFindResultClicksKind")
    kindRow:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -8, -12)
    optionsFrame.ShowResultKind = function(key)
        local kind = Gestures.Kind(key)
        if not kind then return end
        ShowKind(kind)
        kindRow:SetValue(key)
    end
    local sep = tab:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", kindRow, "BOTTOMLEFT", 6, -6)
    sep:SetPoint("RIGHT", tab, "RIGHT", -12, 0)
    sep:SetHeight(1)
    local function RestyleClicksSep()
        local theme = Look().theme
        local tone = theme and theme.lightTheme and theme.separatorColor
        if tone then sep:SetColorTexture(tone[1], tone[2], tone[3], 0.8) else sep:SetColorTexture(0.8, 0.65, 0.0, 0.6) end
    end
    RestyleClicksSep()
    optionsFrame.RestyleClicksSep = RestyleClicksSep
    local anchor = sep
    for i = 1, #Gestures.GESTURES do
        local gesture = Gestures.GESTURES[i]
        local row = CreateFlyoutPresetRow(tab, SettingsRows.GestureLabel(gesture), Gestures.Choices(current),
            function() return Gestures.Get(current.key, gesture) end,
            function(v) Gestures.Set(current.key, gesture, v) end,
            "EasyFindResultClicks" .. gesture)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", i == 1 and -6 or 0, i == 1 and -6 or 0)
        gestureRows[i] = row
        anchor = row
    end
    shiftLine = tab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
    shiftLine:SetPoint("TOPLEFT", gestureRows[shiftRow - 1], "BOTTOMLEFT", 8, -6)
    reset = CreateModernButton(tab, L["OPT_RESET_SETTINGS"], RESET_BTN_W, 22)
    reset:SetScript("OnClick", function()
        Gestures.Reset()
        ShowKind(current)
    end)
    ShowKind(current)
    BuildRowActionsList(ctx, tab, reset)
end

local function BuildFeedbackTab(ctx)
    local CreateTab, RESET_BTN_W = ctx.CreateTab, ctx.RESET_BTN_W
    local feedbackTab = CreateTab(L["OPT_TAB_FEEDBACK"])

    local feedbackDesc = feedbackTab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    feedbackDesc:SetPoint("TOPLEFT", feedbackTab, "TOPLEFT", 12, -16)
    feedbackDesc:SetPoint("RIGHT", feedbackTab, "RIGHT", -12, 0)
    feedbackDesc:SetJustifyH("LEFT")
    feedbackDesc:SetSpacing(3)
    feedbackDesc:SetText(L["OPT_FEEDBACK_DESC"])

    local bugBtn = CreateModernButton(feedbackTab)
    bugBtn:SetSize(RESET_BTN_W, 20)
    bugBtn:SetPoint("TOPLEFT", feedbackDesc, "BOTTOMLEFT", 0, -12)
    bugBtn:SetText(L["OPT_REPORT_BUG"])
    bugBtn:SetScript("OnClick", function()
        EasyFind:OpenBugReport()
    end)
    Utils.AttachDelayedTooltip(bugBtn, "ANCHOR_TOP", function()
        return L["OPT_REPORT_BUG"], L["OPT_REPORT_BUG_TT_DESC"], L["OPT_REPORT_BUG_TT_CMD"]
    end)

    local featureBtn = CreateModernButton(feedbackTab)
    featureBtn:SetSize(RESET_BTN_W, 20)
    featureBtn:SetPoint("LEFT", bugBtn, "RIGHT", 12, 0)
    featureBtn:SetText(L["OPT_REQUEST_FEATURE"])
    featureBtn:SetScript("OnClick", function()
        EasyFind:OpenFeatureRequest()
    end)
    Utils.AttachDelayedTooltip(featureBtn, "ANCHOR_TOP", function()
        return L["OPT_REQUEST_FEATURE"], L["OPT_REQUEST_FEATURE_TT_DESC"], L["OPT_REQUEST_FEATURE_TT_CMD"]
    end)
    ns.FitButtonRow({ bugBtn, featureBtn }, ctx.FRAME_W - 24, 12, RESET_BTN_W)
end









local profilesTab
local profileFlyoutSerial = 0
local function BuildProfilesTab(ctx)
    local Profiles = ns.Profiles
    if not Profiles then return end
    local CreateTab = ctx.CreateTab
    local BTN_W = 132
    profilesTab = CreateTab(L["OPT_TAB_PROFILES"])
    Options._profilesTabIndex = profilesTab.tabIndex
    local RefreshTab

    local desc = profilesTab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    desc:SetPoint("TOPLEFT", profilesTab, "TOPLEFT", 12, -14)
    desc:SetPoint("RIGHT", profilesTab, "RIGHT", -12, 0)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(2)
    desc:SetText(L["OPT_PROFILES_DESC"])



    local function NameFlyout(holder, width, text, names, onPick, styleFn)
        local key = table.concat(names, "\n")
        local picker = holder.picker
        if not picker then
            profileFlyoutSerial = profileFlyoutSerial + 1
            local prefix = "EasyFindProfileFlyout" .. profileFlyoutSerial
            local btnFrame, btnText = CreateFlyoutSelector(holder, prefix, width, nil, text)
            picker = { button = btnFrame, text = btnText, prefix = prefix, serial = 0 }
            holder.picker = picker
        end
        if picker.key ~= key then
            if picker.flyout then picker.flyout:Hide() end
            picker.serial = picker.serial + 1
            local prefix = picker.prefix .. "_" .. picker.serial
            picker.flyout = CreateFlyoutPanel(picker.button, prefix, width, mmax(1, #names))
            AddFlyoutOptions(picker.flyout, names, width - 6, onPick, function(name)
                return Profiles:DisplayName(name)
            end, styleFn)
            picker.key = key
        end
        picker.text:SetText(text)
        picker.button:SetEnabled(#names > 0)
        picker.button:SetAlpha(#names > 0 and 1 or 0.5)
        return picker.button
    end


    local pickRow = CreateFrame("Frame", nil, profilesTab)
    pickRow:SetSize(ctx.SELECTOR_ROW_W, 24)
    pickRow:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -8, -6)
    local pickLabel = pickRow:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalSmall)
    pickLabel:SetPoint("LEFT", pickRow, "LEFT", 8, 0)
    pickLabel:SetTextColor(Utils.RGB(NORMAL_TEXT, 1))
    pickLabel:SetText(L["PROFILE_CURRENT"])
    pickRow:EnableMouse(true)
    local function PickTooltip() return L["PROFILE_CURRENT"], L["PROFILE_CURRENT_TT"] end
    Utils.AttachDelayedTooltip(pickRow, "ANCHOR_RIGHT", PickTooltip)


    local newBtn = CreateModernButton(profilesTab)
    Options:AddAction("profileNew", newBtn)
    newBtn:SetSize(BTN_W, 20)
    newBtn:SetPoint("TOPLEFT", pickRow, "BOTTOMLEFT", 8, -6)
    newBtn:SetText(L["PROFILE_NEW"])
    local renameBtn = CreateModernButton(profilesTab)
    Options:AddAction("profileRename", renameBtn)
    renameBtn:SetSize(BTN_W, 20)
    renameBtn:SetPoint("LEFT", newBtn, "RIGHT", 8, 0)
    renameBtn:SetText(L["PROFILE_RENAME"])
    local resetBtn = CreateModernButton(profilesTab)
    resetBtn:SetSize(BTN_W, 20)
    resetBtn:SetPoint("LEFT", renameBtn, "RIGHT", 8, 0)
    resetBtn:SetText(L["PROFILE_RESET"])
    local copyHolder = CreateFrame("Frame", nil, profilesTab)
    copyHolder:SetSize(BTN_W + 8, 22)
    copyHolder:SetPoint("TOPLEFT", newBtn, "BOTTOMLEFT", 0, -4)
    local deleteHolder = CreateFrame("Frame", nil, profilesTab)
    deleteHolder:SetSize(BTN_W + 8, 22)
    deleteHolder:SetPoint("LEFT", copyHolder, "RIGHT", 0, 0)

    local function AskName(prompt, default, onName)
        ns.ShowThemedDialog({
            text = prompt,
            hasEditBox = true, maxLetters = 48, editBoxDefault = default,
            acceptText = _G["OKAY"] or "Okay",
            cancelText = _G["CANCEL"] or "Cancel",
            onAccept = function(value)
                local name = strtrim(value or "")
                if name == "" then return end
                if Profiles:Exists(name) then
                    EasyFind:Print(L["PROFILE_NAME_TAKEN"])
                    return
                end
                onName(name)
            end,
        })
    end
    newBtn:SetScript("OnClick", function()
        AskName(L["PROFILE_NEW_PROMPT"], "", function(name)
            Profiles:Create(name, Profiles:Active())
            Profiles:Pick(name)
        end)
    end)
    renameBtn:SetScript("OnClick", function()
        local active = Profiles:Active()
        if active == Profiles.DEFAULT then return end
        AskName(L["PROFILE_RENAME_PROMPT"], active, function(name)
            Profiles:Rename(active, name)
            RefreshTab()
        end)
    end)
    resetBtn:SetScript("OnClick", function()
        ns.ShowThemedDialog({
            text = (L["PROFILE_RESET_CONFIRM_FMT"]):format(Profiles:DisplayName(Profiles:Active())),
            messageColor = ns.GOLD_COLOR,
            acceptText = _G["RESET"] or L["PROFILE_RESET"],
            onAccept = function() Profiles:ResetActive() end,
            cancelText = _G["CANCEL"] or "Cancel",
        })
    end)


    local specTitle = profilesTab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormal)
    specTitle:SetPoint("TOPLEFT", copyHolder, "BOTTOMLEFT", 0, -12)
    specTitle:SetText(L["PROFILE_SPEC_TITLE"])
    local specEnable = CreateCheckbox(profilesTab, "ProfileSpecEnable", L["PROFILE_SPEC_ENABLE"],
        L["PROFILE_SPEC_ENABLE_TT"], true, 240)
    specEnable:SetPoint("TOPLEFT", specTitle, "BOTTOMLEFT", -8, -2)
    specEnable:SetScript("OnClick", function(self)
        Profiles:SetSpecProfilesEnabled(self:GetChecked() and true or false)
        RefreshTab()
    end)
    local specRows = {}
    local lastAnchor = specEnable
    for i, spec in ipairs(Profiles:ClassSpecs()) do
        local row = CreateFrame("Frame", nil, profilesTab)
        row:SetSize(ctx.SELECTOR_ROW_W, 22)
        row:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -2)
        local label = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalSmall)
        label:SetPoint("LEFT", row, "LEFT", 8, 0)
        label:SetTextColor(Utils.RGB(NORMAL_TEXT, 1))
        row.label, row.spec = label, spec
        specRows[i] = row
        lastAnchor = row
    end


    local exportTitle = profilesTab:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormal)
    exportTitle:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 8, -12)
    exportTitle:SetText(L["PROFILE_EXPORT_TITLE"])
    local inclRow = CreateFrame("Frame", nil, profilesTab)
    inclRow:SetSize(ctx.SELECTOR_ROW_W, 24)
    inclRow:SetPoint("TOPLEFT", exportTitle, "BOTTOMLEFT", -8, -4)
    local inclLabel = inclRow:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalSmall)
    inclLabel:SetPoint("LEFT", inclRow, "LEFT", 8, 0)
    inclLabel:SetTextColor(Utils.RGB(NORMAL_TEXT, 1))
    inclLabel:SetText(L["PROFILE_EXPORT_INCLUDE"])

    local function AllIncluded()
        for _, sec in ipairs(Profiles.SECTIONS) do
            if not Profiles:ExportIncluded(sec.id) then return false end
        end
        return true
    end
    local function IncludeLabel()
        local n = 0
        for _, sec in ipairs(Profiles.SECTIONS) do
            if Profiles:ExportIncluded(sec.id) then n = n + 1 end
        end
        if n == #Profiles.SECTIONS then return L["PROFILE_INCL_ALL"] end
        return (L["PROFILE_INCL_COUNT_FMT"]):format(n, #Profiles.SECTIONS)
    end
    local inclBtn, inclText = CreateFlyoutSelector(inclRow, "EasyFindProfileInclude", ctx.SELECTOR_BTN_W, nil,
        IncludeLabel())
    local function RepaintInclude()
        inclText:SetText(IncludeLabel())
    end


    local inclDefs = {
        { label = L["FILTER_TOGGLE_ALL"], get = AllIncluded,
          set = function()
              local on = not AllIncluded()
              for _, sec in ipairs(Profiles.SECTIONS) do Profiles:SetExportIncluded(sec.id, on) end
              RepaintInclude()
          end },
        { separator = true },
    }
    for _, sec in ipairs(Profiles.SECTIONS) do
        inclDefs[#inclDefs + 1] = {
            label = L[PROFILE_SECTION_LABEL_KEY[sec.id] or "PROFILE_SECTION_SETTINGS"],
            get = function() return Profiles:ExportIncluded(sec.id) end,
            set = function(v)
                Profiles:SetExportIncluded(sec.id, v)
                RepaintInclude()
            end,
        }
    end
    AddFlyoutChecks(CreateFlyoutPanel(inclBtn, "EasyFindProfileInclude", ctx.SELECTOR_BTN_W, #inclDefs),
        inclDefs, ctx.SELECTOR_BTN_W - 6)

    local exportBtn = CreateModernButton(profilesTab)
    Options:AddAction("profileExport", exportBtn)
    exportBtn:SetSize(BTN_W, 20)
    exportBtn:SetPoint("TOPLEFT", inclRow, "BOTTOMLEFT", 8, -6)
    exportBtn:SetText(L["PROFILE_EXPORT"])
    Utils.AttachDelayedTooltip(exportBtn, "ANCHOR_TOP", function()
        return L["PROFILE_EXPORT"], L["PROFILE_EXPORT_TT"]
    end)
    exportBtn:SetScript("OnClick", function()
        local code = Profiles:Export()
        if not code then
            EasyFind:Print(L["PROFILE_EXPORT_EMPTY"])
            return
        end
        if optionsFrame and optionsFrame.ShowShareString then
            optionsFrame.ShowShareString(true, code, "profile")
        end
    end)
    local importBtn = CreateModernButton(profilesTab)
    Options:AddAction("profileImport", importBtn)
    importBtn:SetSize(BTN_W, 20)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
    importBtn:SetText(L["PROFILE_IMPORT"])
    importBtn:SetScript("OnClick", function()
        if optionsFrame and optionsFrame.ShowShareString then
            optionsFrame.ShowShareString(false, nil, "profile", RefreshTab)
        end
    end)

    RefreshTab = function()
        if not profilesTab:IsShown() then return end
        local active = Profiles:Active()
        local names = Profiles:Names()
        local pickNames, isSuggestion = {}, {}
        for _, name in ipairs(names) do pickNames[#pickNames + 1] = name end
        for _, name in ipairs(Profiles:Suggestions()) do
            pickNames[#pickNames + 1] = name
            isSuggestion[name] = true
        end
        local pickBtn = NameFlyout(pickRow, ctx.SELECTOR_BTN_W, Profiles:DisplayName(active), pickNames,
            function(name) Profiles:Pick(name) end,
            function(_, name, label)
                if isSuggestion[name] then label:SetTextColor(0.55, 0.55, 0.55) end
            end)
        Utils.AttachDelayedTooltip(pickBtn, "ANCHOR_RIGHT", PickTooltip)
        local canRename = active ~= Profiles.DEFAULT
        renameBtn:SetEnabled(canRename)
        renameBtn:SetAlpha(canRename and 1 or 0.5)

        local others = {}
        for _, name in ipairs(names) do
            if name ~= active then others[#others + 1] = name end
        end
        local copyBtn = NameFlyout(copyHolder, BTN_W, L["PROFILE_COPY_FROM"], others, function(name)
            ns.ShowThemedDialog({
                text = (L["PROFILE_COPY_CONFIRM_FMT"]):format(
                    Profiles:DisplayName(Profiles:Active()), Profiles:DisplayName(name)),
                messageColor = ns.GOLD_COLOR,
                acceptText = _G["OKAY"] or "Okay",
                onAccept = function() Profiles:CopyFrom(name) end,
                cancelText = _G["CANCEL"] or "Cancel",
            })
        end)
        local deleteBtn = NameFlyout(deleteHolder, BTN_W, L["PROFILE_DELETE"], Profiles:Deletable(), function(name)
            ns.ShowThemedDialog({
                text = (L["PROFILE_DELETE_CONFIRM_FMT"]):format(Profiles:DisplayName(name)),
                messageColor = ns.GOLD_COLOR,
                acceptText = _G["DELETE"] or L["PROFILE_DELETE"],
                onAccept = function()
                    Profiles:Delete(name)
                    RefreshTab()
                end,
                cancelText = _G["CANCEL"] or "Cancel",
            })
        end)
        Options:AddAction("profileCopyFrom", copyBtn)
        Options:AddAction("profileDelete", deleteBtn)

        local specOn = Profiles:SpecProfilesEnabled()
        specEnable:SetChecked(specOn)
        local currentSpec = Profiles:CurrentSpecID()
        for _, row in ipairs(specRows) do
            local spec = row.spec
            local text = spec.id == currentSpec and (L["PROFILE_SPEC_ACTIVE_FMT"]):format(spec.name) or spec.name
            row.label:SetText(text)
            local btn = NameFlyout(row, ctx.SELECTOR_BTN_W, Profiles:DisplayName(Profiles:SpecProfile(spec.id)),
                names, function(name)
                    Profiles:SetSpecProfile(spec.id, name)
                    RefreshTab()
                end)
            btn:SetEnabled(specOn)
            row:SetAlpha(specOn and 1 or 0.5)
        end
        RepaintInclude()
    end
    profilesTab:HookScript("OnShow", RefreshTab)
    optionsFrame.RefreshProfilesTab = RefreshTab
end

function Options:Initialize()
    if isInitialized then return end

    local WINDOW_W   = ns.OPTIONS_WINDOW_W
    local WINDOW_H   = ns.OPTIONS_WINDOW_H
    local SIDEBAR_W  = 150
    local FRAME_W    = WINDOW_W - SIDEBAR_W - 46
    local COL_LEFT   = 4
    local SIDEBAR_BOTTOM_INSET = 10
    local CLASSIC_EDGE = 14
    local CONTENT_BOTTOM_INSET = 14
    local LIST_CARD_SIDE_INSET = 8




    local function AnchorListCardBottom(card, tab)
        card:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT",
            -LIST_CARD_SIDE_INSET, SIDEBAR_BOTTOM_INSET - CONTENT_BOTTOM_INSET)
    end

    optionsFrame = CreateFrame("Frame", "EasyFindOptionsFrame", UIParent, "BackdropTemplate")

    optionsFrame._efSurface = "options"
    ns.optionsFrame = optionsFrame
    optionsFrame:SetSize(WINDOW_W, WINDOW_H)
    optionsFrame:SetScale(OPTIONS_PANEL_SCALE)
    if EasyFind.db.optionsPosition then
        local pos = EasyFind.db.optionsPosition
        optionsFrame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    optionsFrame:SetFrameStrata(OPTIONS_FRAME_STRATA)
    optionsFrame:SetFrameLevel(OPTIONS_FRAME_LEVEL)
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:SetClampedToScreen(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        EasyFind.db.optionsPosition = {point, relPoint, x, y}
    end)




    ns.AttachEscClose(optionsFrame, function()
        local closedAny = false
        for i = 1, #optionsFlyouts do
            if optionsFlyouts[i]:IsShown() then
                optionsFlyouts[i]:Hide()
                closedAny = true
            end
        end
        if not closedAny then optionsFrame:Hide() end
    end)

    optionsFrame:SetBackdrop(nil)

    local bgTex = CreateFrame("Frame", nil, optionsFrame)
    bgTex:SetAllPoints(optionsFrame)
    bgTex:EnableMouse(false)
    StyleWizardBackground(bgTex)
    bgTex:SetAlpha(OPTIONS_PANEL_ALPHA)
    optionsFrame.bgTex = bgTex
    optionsFrame._efTreeHost = bgTex






    function optionsFrame:RepaintTheme()
        if self.bgTex then
            ns.StyleWizardPanel(self.bgTex, 1)
            if ns.ApplyClassicHeader then ns.ApplyClassicHeader(self.bgTex, "EasyFind") end
            if self.PlaceFrameEdges then self.PlaceFrameEdges() end
            local theme = Look().theme
            self.bgTex:SetAlpha((theme and theme.lightTheme) and 1 or OPTIONS_PANEL_ALPHA)
        end
        if ns.RetintPanelText then ns.RetintPanelText(self) end
        if self.RepaintTabs then pcall(self.RepaintTabs) end
        if self.UpdateAltHintExample then pcall(self.UpdateAltHintExample) end
        if self.RestyleSidebar then pcall(self.RestyleSidebar) end
        if self.UpdateShortcutColors then pcall(self.UpdateShortcutColors) end
        if self.RestyleTutorialLink then pcall(self.RestyleTutorialLink) end
        if self.UpdateHomeVersion then pcall(self.UpdateHomeVersion) end
        if self.RestyleMapSep then pcall(self.RestyleMapSep) end
        if self.RestyleClicksSep then pcall(self.RestyleClicksSep) end
        if self.RestyleSettingsSearch then pcall(self.RestyleSettingsSearch) end
        if self.RepaintFlyouts then pcall(self.RepaintFlyouts) end
        if self.RefreshBorderRow then pcall(self.RefreshBorderRow) end
        if self.UpdateClassicRows then self.UpdateClassicRows() end
        if self.themeBtnText then
            self.themeBtnText:SetText(EasyFind.db.uiTheme
                or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.uiTheme) or "Midnight")
        end



        pcall(SyncOptionControls)
    end
    optionsFrame:HookScript("OnShow", function(self)
        self:RepaintTheme()
    end)

    function ns.RepaintOptionsPanelTheme()
        if optionsFrame:IsShown() then optionsFrame:RepaintTheme() end
    end

    local sidebar = CreateFrame("Frame", nil, optionsFrame)
    sidebar:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 10, -10)
    sidebar:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 10, SIDEBAR_BOTTOM_INSET)
    sidebar:SetWidth(SIDEBAR_W)
    optionsFrame.sidebar = sidebar
    sidebar._efNoAutoRetint = true
    ns.CreateRoundedRectBorder(sidebar)
    ns.SetRoundedRectBarHeight(sidebar, 14)
    ns.SetRoundedRectBorderBgAlpha(sidebar, 0.72)
    HideRoundedBorder(sidebar)
    TintRoundedFill(sidebar, 0.022, 0.022, 0.028)

    local divider = optionsFrame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, -2)
    divider:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 8, 2)
    divider:SetWidth(1)
    divider:SetColorTexture(1, 1, 1, 0.08)
    optionsFrame.sidebarDivider = divider


    local sidebarIron = ns.CreateIronLine(optionsFrame, true)
    sidebarIron:SetPoint("LEFT", sidebar, "RIGHT", 4, 0)
    sidebarIron:SetPoint("TOP", optionsFrame, "TOP", 0, -12)
    sidebarIron:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, 11)
    sidebarIron:SetFrameLevel(sidebar:GetFrameLevel() + 2)


    local function RestyleSidebar()

        local glossLevel = optionsFrame.bgTex and optionsFrame.bgTex:GetFrameLevel() or 0
        if sidebar:GetFrameLevel() <= glossLevel then
            sidebar:SetFrameLevel(glossLevel + 1)
        end
        local pal = Look().palette
        local classic = ns.IsClassicChrome()
        if classic then

            sidebar._efThemeFillTarget = nil
            if sidebar._efArtCells then
                for _, cell in pairs(sidebar._efArtCells) do cell:Hide() end
            end
        elseif pal and pal.light then

            local card = ns.SECTION_TABLE_FILL
            sidebar._efThemeFillTarget = nil
            if sidebar._efArtCells then
                for _, cell in pairs(sidebar._efArtCells) do cell:Hide() end
            end
            ns.SetRoundedRectFill(sidebar, card[1], card[2], card[3], 1, true)
            ns.SetRoundedRectBorderBgAlpha(sidebar, card[4] or 0.92)
        else

            ns.ApplyThemeFill(sidebar)
            ns.SetRoundedRectBorderBgAlpha(sidebar, 0.72)
        end
        divider:SetColorTexture(1, 1, 1, 0.08)
        ns.SetRoundedRectBorderShown(sidebar, not classic)
        HideRoundedBorder(sidebar)
        divider:SetShown(not classic)
        sidebarIron:SetShown(classic)
        if optionsFrame.titleText then
            if pal and pal.light then
                optionsFrame.titleText:SetTextColor(1, 1, 1, 1)
            else
                optionsFrame.titleText:SetTextColor(Utils.RGB(Look().TEXT_BODY, 1))
            end
        end




        if optionsFrame.closeBtn and optionsFrame.closeBtn.SetXColors then
            optionsFrame.closeBtn:SetXColors(nil, nil)
        end
    end
    optionsFrame.RestyleSidebar = RestyleSidebar
    RestyleSidebar()

    local title = optionsFrame:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    title:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 4, -6)
    title:SetText(L["OPT_SETTINGS_TITLE"])
    title:SetTextColor(Utils.RGB(Look().TEXT_BODY, 1))
    optionsFrame.titleText = title

    RestyleSidebar()

    local closeBtn = ns.CreateCloseX(optionsFrame)
    closeBtn:SetPoint("TOPRIGHT", -10, -10)
    closeBtn:SetScript("OnClick", function() optionsFrame:Hide() end)
    optionsFrame.closeBtn = closeBtn



    function optionsFrame.PlaceFrameEdges()
        local pad = ns.IsClassicChrome() and CLASSIC_EDGE or 10
        closeBtn:ClearAllPoints()
        closeBtn:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -pad, -pad)
        sidebar:ClearAllPoints()
        sidebar:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", pad, -pad)
        sidebar:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", pad, pad)
        for _, btn in ipairs(optionsFrame.resetButtons or {}) do
            btn:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, pad)
        end
    end

    local contentBorder = CreateFrame("Frame", nil, optionsFrame)


    contentBorder:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", SIDEBAR_W + 32, -42)
    contentBorder:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -14, CONTENT_BOTTOM_INSET)
    optionsFrame.contentBorder = contentBorder

    local tabFrames = {}
    local tabButtons = {}
    optionsFrame.tabNames, optionsFrame.tabIndexByName = {}, {}




    local function PaintTabLabel(label, hovered)
        local pal = Look().palette
        if ns.ClassicLook() then

            if hovered then label:SetTextColor(1, 1, 1, 1) else label:SetTextColor(1, 0.82, 0, 1) end
        elseif pal and pal.light then
            label:SetTextColor(1, 1, 1, 1)
        else
            label:SetTextColor(Utils.RGB(hovered and Look().TEXT_PRIMARY or Look().TEXT_BODY, 1))
        end
    end

    local function SetTabActive(btn, active)
        btn.isActive = active
        if active then
            SetNavButtonBg(btn, NAV_SELECTED)


            local pal = Look().palette
            if ns.ClassicLook() then
                btn.label:SetTextColor(1, 1, 1, 1)
            elseif pal and pal.light then
                local card = ns.SECTION_TABLE_FILL
                btn.label:SetTextColor(card[1], card[2], card[3], 1)
            else
                btn.label:SetTextColor(Utils.RGB(Look().TEXT_PRIMARY, 1))
            end
        else
            SetNavButtonBg(btn, NAV_CLEAR)
            PaintTabLabel(btn.label, false)
        end
    end

    local function SwitchToTab(index)
        for i, tf in ipairs(tabFrames) do
            tf:SetShown(i == index)
            SetTabActive(tabButtons[i], i == index)
        end
    end
    optionsFrame.SwitchToTab = SwitchToTab



    local function RepaintTabs()
        for i = 1, #tabButtons do
            SetTabActive(tabButtons[i], tabButtons[i].isActive and true or false)
        end
    end
    optionsFrame.RepaintTabs = RepaintTabs




    local function FlashFrame(target)
        if not target then return end
        local glow = target.efBindGlow
        if not glow then
            glow = CreateFrame("Frame", nil, target)
            glow:SetPoint("TOPLEFT", target, "TOPLEFT", -3, 3)
            glow:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 3, -3)
            glow:SetFrameLevel(target:GetFrameLevel() + 4)
            local function MakeEdge()
                local edge = glow:CreateTexture(nil, "OVERLAY")
                edge:SetColorTexture(1, 0.82, 0, 1)
                return edge
            end
            local topEdge = MakeEdge()
            topEdge:SetPoint("TOPLEFT"); topEdge:SetPoint("TOPRIGHT"); topEdge:SetHeight(2)
            local bottomEdge = MakeEdge()
            bottomEdge:SetPoint("BOTTOMLEFT"); bottomEdge:SetPoint("BOTTOMRIGHT"); bottomEdge:SetHeight(2)
            local leftEdge = MakeEdge()
            leftEdge:SetPoint("TOPLEFT"); leftEdge:SetPoint("BOTTOMLEFT"); leftEdge:SetWidth(2)
            local rightEdge = MakeEdge()
            rightEdge:SetPoint("TOPRIGHT"); rightEdge:SetPoint("BOTTOMRIGHT"); rightEdge:SetWidth(2)
            local pulse = glow:CreateAnimationGroup()
            for i = 1, 3 do
                local up = pulse:CreateAnimation("Alpha")
                up:SetFromAlpha(0); up:SetToAlpha(1); up:SetDuration(0.22); up:SetOrder(i * 2 - 1)
                local down = pulse:CreateAnimation("Alpha")
                down:SetFromAlpha(1); down:SetToAlpha(0); down:SetDuration(0.22); down:SetOrder(i * 2)
            end
            pulse:SetScript("OnFinished", function() glow:Hide() end)
            glow.pulse = pulse
            target.efBindGlow = glow
        end
        glow.pulse:Stop()
        glow:SetAlpha(0)
        glow:Show()
        glow.pulse:Play()
    end
    local function FlashBindButton()
        FlashFrame(optionsFrame.toggleFocusBtn)
    end

    local function CreateTab(tabName)
        local index = #tabFrames + 1

        local btn = CreateFrame("Button", nil, sidebar)
        btn:SetSize(SIDEBAR_W - 16, 28)
        btn:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, -34 - (index - 1) * 32)
        btn._efNoAutoRetint = true
        ns.CreateRoundedRectBorder(btn)
        ns.SetRoundedRectBarHeight(btn, 10)
        ns.SetRoundedRectBorderBgAlpha(btn, 0)
        HideRoundedBorder(btn)
        SetNavButtonBg(btn, NAV_CLEAR)

        local label = btn:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
        label:SetPoint("LEFT", btn, "LEFT", 10, 0)
        label:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
        label:SetJustifyH("LEFT")
        label:SetText(tabName)
        PaintTabLabel(label, false)
        btn.label = label

        btn:SetScript("OnEnter", function(self)
            if not self.isActive then
                SetNavButtonBg(self, NAV_HOVER)
                PaintTabLabel(self.label, true)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if not self.isActive then
                SetNavButtonBg(self, NAV_CLEAR)
                PaintTabLabel(self.label, false)
            end
        end)
        btn:SetScript("OnClick", function() SwitchToTab(index) end)
        tinsert(tabButtons, btn)

        local content = CreateFrame("Frame", nil, contentBorder)
        content:SetAllPoints(contentBorder)
        content:Hide()
        content.tabIndex = index
        tinsert(tabFrames, content)
        optionsFrame.tabNames[index] = tabName
        optionsFrame.tabIndexByName[tabName] = index

        return content
    end




    local tutorialBtn = CreateFrame("Button", nil, sidebar)
    tutorialBtn:SetSize(SIDEBAR_W - 16, 28)
    tutorialBtn:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 8, 8)
    tutorialBtn._efNoAutoRetint = true
    ns.CreateRoundedRectBorder(tutorialBtn)
    ns.SetRoundedRectBarHeight(tutorialBtn, 10)
    ns.SetRoundedRectBorderBgAlpha(tutorialBtn, 0)
    HideRoundedBorder(tutorialBtn)
    SetNavButtonBg(tutorialBtn, NAV_CLEAR)



    local TUT_LINK = { 0.44, 0.84, 1.0 }
    local TUT_LINK_HOVER = { 0.72, 0.94, 1.0 }
    local tutorialLabel = tutorialBtn:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    tutorialLabel:SetPoint("LEFT", tutorialBtn, "LEFT", 10, 0)
    tutorialLabel:SetPoint("RIGHT", tutorialBtn, "RIGHT", -10, 0)
    tutorialLabel:SetJustifyH("LEFT")
    tutorialLabel:SetText(L["OPT_TAB_TUTORIAL"])
    local function RestyleTutorialLink()
        tutorialLabel:SetTextColor(TUT_LINK[1], TUT_LINK[2], TUT_LINK[3], 1)
    end
    RestyleTutorialLink()
    optionsFrame.RestyleTutorialLink = RestyleTutorialLink
    tutorialBtn:SetScript("OnEnter", function(self)
        SetNavButtonBg(self, NAV_HOVER)
        tutorialLabel:SetTextColor(TUT_LINK_HOVER[1], TUT_LINK_HOVER[2], TUT_LINK_HOVER[3], 1)
    end)
    tutorialBtn:SetScript("OnLeave", function(self)
        SetNavButtonBg(self, NAV_CLEAR)
        RestyleTutorialLink()
    end)
    tutorialBtn:SetScript("OnClick", OpenTutorialWizard)



    local pagedTutorial = CreateFrame("Button", nil, optionsFrame)
    pagedTutorial:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -16, -12)
    local pagedTutorialLabel = pagedTutorial:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
    pagedTutorialLabel:SetPoint("RIGHT")
    pagedTutorialLabel:SetText(L["OPT_TAB_TUTORIAL"])
    pagedTutorialLabel:SetTextColor(TUT_LINK[1], TUT_LINK[2], TUT_LINK[3], 1)
    pagedTutorial:SetSize(math.ceil(pagedTutorialLabel:GetStringWidth() + 4), 18)
    pagedTutorial:SetScript("OnEnter", function()
        pagedTutorialLabel:SetTextColor(TUT_LINK_HOVER[1], TUT_LINK_HOVER[2], TUT_LINK_HOVER[3], 1)
    end)
    pagedTutorial:SetScript("OnLeave", function()
        pagedTutorialLabel:SetTextColor(TUT_LINK[1], TUT_LINK[2], TUT_LINK[3], 1)
    end)
    pagedTutorial:SetScript("OnClick", OpenTutorialWizard)
    pagedTutorial:Hide()





    function optionsFrame.SetPagedLayout(paged)
        paged = paged and true or false
        if optionsFrame.paged == paged then return end
        optionsFrame.paged = paged
        sidebar:SetShown(not paged)
        divider:SetShown(not paged)
        pagedTutorial:SetShown(paged)
        local shell = optionsFrame.settingsSearchShell
        contentBorder:ClearAllPoints()
        local side = (WINDOW_W - FRAME_W) / 2
        if paged then
            contentBorder:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", side, -42)
            contentBorder:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -side, CONTENT_BOTTOM_INSET)
            pagedTutorial:ClearAllPoints()
            pagedTutorial:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -side, -12)
            if shell then
                shell:SetParent(optionsFrame)
                shell:ClearAllPoints()
                shell:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", side, -10)
                shell:SetWidth(SIDEBAR_W + 60)
                shell:SetFrameLevel(optionsFrame.bgTex:GetFrameLevel() + 2)
            end
        else
            contentBorder:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", SIDEBAR_W + 32, -42)
            contentBorder:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -14, CONTENT_BOTTOM_INSET)
            if shell then
                shell:SetParent(sidebar)
                shell:ClearAllPoints()
                shell:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, -6)
                shell:SetPoint("RIGHT", sidebar, "RIGHT", -8, 0)
            end
        end
        if optionsFrame.PlacePageSearch then optionsFrame.PlacePageSearch() end
    end



    function optionsFrame.PlacePageSearch()
        local pageShell = optionsFrame.pageSearchShell
        if not pageShell then return end
        pageShell:ClearAllPoints()
        if optionsFrame.paged then
            pageShell:SetPoint("RIGHT", pagedTutorial, "LEFT", -12, 0)
        else
            pageShell:SetPoint("RIGHT", optionsFrame.closeBtn, "LEFT", -10, 0)
        end
    end

    local function GetCurrentKeybindText(action)


        return EasyFind:GetAccountKeybind(action) or (_G["NOT_BOUND"] or "Not Bound")
    end

    local function StopCapture(keybindBtn, action)
        keybindBtn.waitingForKey = false
        keybindBtn:SetText(GetCurrentKeybindText(action))
        keybindBtn:UnlockHighlight()
        Utils.DisarmBindingCapture(keybindBtn)
    end

    local function StartCapture(keybindBtn, action)
        if keybindBtn.waitingForKey then
            StopCapture(keybindBtn, action)
        else
            keybindBtn.waitingForKey = true
            keybindBtn:SetText(L["OPT_KB_PRESS_KEY"])
            keybindBtn:LockHighlight()
            Utils.ArmBindingCapture(keybindBtn, function(self, combo)
                if combo == "stop" then
                    StopCapture(self, action)
                    return
                end
                EasyFind:SetAccountKeybind(action, combo)
                StopCapture(self, action)
            end)
        end
    end

    local function MakeKeybindTooltip(keybindBtn, titleText, line1)
        Utils.AttachDelayedTooltip(keybindBtn, "ANCHOR_RIGHT", function()
            return titleText, line1, L["OPT_KB_CLEAR_HINT"]
        end)
    end

    local SELECTOR_ROW_W = FRAME_W - 16
    local SELECTOR_BTN_W = 204







    local function CreateFlyoutPresetRow(parent, labelText, choices, getter, setter, globalPrefix, defaultValue, tooltipText, onHover, preview)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(SELECTOR_ROW_W, 24)
        row._efControl = { kind = "choice", get = getter, set = setter, choices = choices, tooltip = tooltipText }
        local label = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontNormalSmall)
        label:SetPoint("LEFT", row, "LEFT", 8, 0)
        label:SetPoint("RIGHT", row, "RIGHT", -SELECTOR_BTN_W - 18, 0)
        label:SetJustifyH("LEFT")
        label:SetTextColor(Utils.RGB(NORMAL_TEXT, 1))
        label:SetText(labelText)

        local function LabelFor(value)
            for _, c in ipairs(choices) do
                if c.value == value then return c.label end
            end
            return tostring(value)
        end



        local function FlyoutLabelFor(value)
            if defaultValue ~= nil and value == defaultValue then
                return LabelFor(value) .. " (" .. (_G["DEFAULT"] or "Default") .. ")"
            end
            return LabelFor(value)
        end
        local btnFrame, btnText = CreateFlyoutSelector(row, globalPrefix, SELECTOR_BTN_W, label, LabelFor(getter()))
        local values = {}
        for i = 1, #choices do values[i] = choices[i].value end
        local flyout = CreateFlyoutPanel(btnFrame, globalPrefix, SELECTOR_BTN_W, #values)
        local keep
        if preview then onHover, keep = HoverPreview(flyout, getter, setter) end
        local function Pick(value)
            if keep then keep(value) end
            setter(value)
            btnText:SetText(LabelFor(value))
        end
        local flyoutRows = AddFlyoutOptions(flyout, values, SELECTOR_BTN_W - 6, Pick, FlyoutLabelFor, nil, onHover)


        flyout:HookScript("OnShow", function()
            for i = 1, #flyoutRows do
                local c = choices[i]
                local off = c and c.disabled and c.disabled() or false
                flyoutRows[i]:SetEnabled(not off)
                flyoutRows[i]._label:SetAlpha(off and 0.4 or 1)
            end
        end)

        row.SetChoices = function(_, list)
            for i = #choices, 1, -1 do choices[i] = nil end
            for i = 1, #list do choices[i] = list[i] end
            for i = 1, #flyoutRows do flyoutRows[i]:Hide() end
            local vals = {}
            for i = 1, #choices do vals[i] = choices[i].value end
            flyout:SetHeight(#vals * 20 + 6)
            flyoutRows = AddFlyoutOptions(flyout, vals, SELECTOR_BTN_W - 6, Pick, FlyoutLabelFor, nil, onHover)
            btnText:SetText(LabelFor(getter()))
        end

        if tooltipText then
            row:EnableMouse(true)
            Utils.AttachDelayedTooltip(row, "ANCHOR_RIGHT", function()
                return labelText, tooltipText
            end)
            Utils.AttachDelayedTooltip(btnFrame, "ANCHOR_RIGHT", function()
                return labelText, tooltipText
            end)
        end

        row.flyout = flyout
        row.SetValue = function(self, value) btnText:SetText(LabelFor(value)) end
        row.SetGroupEnabled = function(self, enabled)
            self:SetAlpha(enabled and 1.0 or 0.35)
            ApplyRowLabelColor(label, enabled, self)
            btnFrame:SetEnabled(enabled)
            if not enabled then flyout:Hide() end
        end
        return row
    end
    local RESET_BTN_W = 144


    local ctx = {
        Fonts = OPT_FONTS, CreateButton = CreateModernButton,
        CreateTab = CreateTab, SwitchToTab = SwitchToTab,
        FRAME_W = FRAME_W, COL_LEFT = COL_LEFT,
        FlashBindButton = FlashBindButton,
        GetCurrentKeybindText = GetCurrentKeybindText,
        MakeKeybindTooltip = MakeKeybindTooltip, StartCapture = StartCapture,
        SELECTOR_ROW_W = SELECTOR_ROW_W, SELECTOR_BTN_W = SELECTOR_BTN_W,
        CreateFlyoutPresetRow = CreateFlyoutPresetRow,
        CreateStepperRow = CreateStepperRow,
        CreateCheckbox = CreateCheckbox,
        RESET_BTN_W = RESET_BTN_W,
        AnchorListCardBottom = AnchorListCardBottom, LIST_CARD_SIDE_INSET = LIST_CARD_SIDE_INSET,
    }
    BuildHomeTab(ctx)
    BuildGeneralBindsTab(ctx)
    BuildSearchTab(ctx)
    BuildMapTab(ctx)
    BuildAliasesTab(ctx)
    BuildBlacklistTab(ctx)


    BuildExtensionsTab(ctx)
    BuildResultClicksTab(ctx)


    BuildProfilesTab(ctx)
    BuildShortcutsTab(ctx)
    BuildFeedbackTab(ctx)



    do
        local shell = CreateFrame("Frame", nil, optionsFrame)
        shell:Hide()

        shell:SetFrameLevel(optionsFrame.bgTex:GetFrameLevel() + 2)
        shell:SetSize(190, 22)
        SearchWell(shell)
        local icon = shell.ringInset:CreateTexture(nil, "OVERLAY")
        icon:SetSize(13, 13)
        icon:SetPoint("LEFT", shell, "LEFT", 7, 0)
        icon:SetAtlas("common-search-magnifyingglass")
        local box = CreateFrame("EditBox", nil, shell)
        Utils.ReleaseFocusOnOutsideClick(box)
        box:SetFrameLevel(shell.ringInset:GetFrameLevel() + 2)
        box:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        box:SetPoint("RIGHT", shell, "RIGHT", -8, 0)
        box:SetHeight(18)
        box:SetAutoFocus(false)
        box:SetFontObject(SMALL_HIGHLIGHT_FONT)
        box:SetMaxLetters(48)
        local placeholder = box:CreateFontString(nil, "ARTWORK", OPT_FONTS.GameFontDisableSmall)
        placeholder:SetPoint("LEFT", box, "LEFT", 0, 0)
        placeholder:SetText(L["OPT_PAGE_SEARCH_PLACEHOLDER"])
        Utils.StyleSearchHint(placeholder, icon)
        optionsFrame.pageSearchBox = box
        optionsFrame.pageSearchShell = shell
        optionsFrame.PlacePageSearch()

        local hidden, moved, resized = {}, {}, {}
        local function RestorePage()
            for obj in pairs(hidden) do obj:Show() end
            for obj, points in pairs(moved) do
                obj:ClearAllPoints()
                for _, p in ipairs(points) do obj:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
            end
            for frame, height in pairs(resized) do frame:SetHeight(height) end
            wipe(hidden)
            wipe(moved)
            wipe(resized)
        end
        local function CurrentTab()
            for i, tf in ipairs(tabFrames) do
                if tf:IsShown() then return i, tf end
            end
            return nil
        end
        local function Matches(lower, words)
            for i = 1, #words do
                if not string.find(lower, words[i], 1, true) then return false end
            end
            return true
        end
        local function Covers(a, b)
            local top, bottom = a:GetTop(), a:GetBottom()
            local bTop, bBottom = b:GetTop(), b:GetBottom()
            if not (top and bottom and bTop and bBottom) then return false end
            local center = (bTop + bBottom) / 2
            return center <= top + 1 and center >= bottom - 1
        end

        local function BelowPoint(p, rp)
            return string.find(p or "", "^TOP") ~= nil and string.find(rp or "", "^BOTTOM") ~= nil
        end
        local function Reanchor(obj)
            local n = obj:GetNumPoints()
            local orig, points, changed = {}, {}, false
            for i = 1, n do
                local p, rel, rp, x, y = obj:GetPoint(i)
                orig[i] = { p, rel, rp, x, y }
                if rel and hidden[rel] and BelowPoint(p, rp) then
                    local guard = 0
                    repeat
                        local hp, hrel, hrp, hx, hy = rel:GetPoint(1)
                        if not hrel then break end
                        x, y, rp, rel = (x or 0) + (hx or 0), hy, hrp, hrel
                        guard = guard + 1
                    until not (hidden[rel] and BelowPoint(hp, hrp)) or guard >= 64
                    changed = true
                end
                points[i] = { p, rel, rp, x, y }
            end
            if not changed then return end
            moved[obj] = orig
            obj:ClearAllPoints()
            for i = 1, n do
                local q = points[i]
                obj:SetPoint(q[1], q[2], q[3], q[4], q[5])
            end
        end
        local function Members(list)
            local out = {}
            local children = { list:GetChildren() }
            for i = 1, #children do
                if children[i]:IsShown() then out[#out + 1] = children[i] end
            end
            local regions = { list:GetRegions() }
            for i = 1, #regions do
                local r = regions[i]
                if r:IsShown() and r.IsObjectType and r:IsObjectType("FontString") then out[#out + 1] = r end
            end
            return out
        end


        local function StackedRow(m, list)
            if not m.GetChildren then return false end
            for k = 1, m:GetNumPoints() do
                local p, rel = m:GetPoint(k)
                if rel ~= list or string.find(p, "^BOTTOM") then return false end
            end
            local p = m:GetPoint(1)
            return string.find(p or "", "^TOP") ~= nil
        end
        local function Compact(list, members, resize)
            local slots, rows = {}, {}
            for _, m in ipairs(members) do
                if StackedRow(m, list) then
                    local y = select(5, m:GetPoint(1))
                    slots[#slots + 1] = y
                    if not hidden[m] then rows[#rows + 1] = { m, y } end
                end
            end
            if #rows == 0 or #rows == #slots then return end
            table.sort(slots, function(a, b) return a > b end)
            table.sort(rows, function(a, b) return a[2] > b[2] end)
            for i, r in ipairs(rows) do
                local m = r[1]
                local points = {}
                for k = 1, m:GetNumPoints() do points[k] = { m:GetPoint(k) } end
                if not moved[m] then moved[m] = points end
                m:ClearAllPoints()
                for k, q in ipairs(points) do
                    m:SetPoint(q[1], q[2], q[3], q[4], k == 1 and slots[i] or q[5])
                end
            end
            if resize then
                resized[list] = list:GetHeight()
                list:SetHeight(list:GetHeight() - (slots[#rows] - slots[#slots]))
            end
        end

        local function Narrow(text)
            RestorePage()
            local words = {}
            for w in string.lower(text or ""):gmatch("%S+") do words[#words + 1] = w end
            if #words == 0 then return end
            local tab, tf = CurrentTab()
            if not tab then return end
            local onExtensions = tab == Options._extensionsTabIndex
            local pageID = onExtensions and extensionCurrent or nil
            local roots = { [tf] = true }
            local entry = onExtensions and extensionsTab.currentEntry
            if entry and entry.frame then roots[entry.frame] = true end
            local hits = {}
            for _, hit in ipairs(optionsFrame.SettingsIndex()) do
                if hit.tab == tab and hit.pageID == pageID and hit.region and hit.region:IsVisible() then
                    hits[#hits + 1] = hit
                end
            end


            local holds = {}
            for _, hit in ipairs(hits) do
                local f = hit.target:GetParent()
                while f and not holds[f] do
                    holds[f] = true
                    if f == tf then break end
                    f = f:GetParent()
                end
            end
            local function IsList(f)
                if roots[f] or holds[f] then return true end
                local parent = f:GetParent()
                return parent ~= nil and parent.IsObjectType and parent:IsObjectType("ScrollFrame")
            end
            local kept, whole, lists, headers = {}, {}, {}, {}
            for _, hit in ipairs(hits) do
                local t = hit.target
                local match = Matches(hit.lower, words)
                if IsList(t) then
                    lists[t] = true
                    headers[#headers + 1] = hit
                    if match then kept[hit.region] = true end
                else
                    lists[t:GetParent()] = true
                    if match then kept[t] = true end
                end
            end

            for _, h in ipairs(headers) do
                if kept[h.region] then
                    local bottom, nextTop = h.region:GetBottom() or 0, nil
                    for _, o in ipairs(headers) do
                        local top = o.target == h.target and o.region:GetTop()
                        if top and top < bottom and (not nextTop or top > nextTop) then nextTop = top end
                    end
                    for _, m in ipairs(Members(h.target)) do
                        local top = m:GetTop()
                        if top and top <= bottom + 1 and (not nextTop or top > nextTop + 1) then whole[m] = true end
                    end
                end
            end
            local keptBelow = {}
            for obj in pairs(kept) do
                local f = obj:GetParent()
                while f and not keptBelow[f] do keptBelow[f] = true f = f:GetParent() end
            end
            for obj in pairs(whole) do
                local f = obj:GetParent()
                while f and not keptBelow[f] do keptBelow[f] = true f = f:GetParent() end
            end
            local function InsideWhole(f)
                while f do
                    if whole[f] then return true end
                    if f == tf then return false end
                    f = f:GetParent()
                end
                return false
            end
            local done = {}
            for list in pairs(lists) do
                if not InsideWhole(list) then
                    local members = Members(list)
                    local reps = {}
                    for _, m in ipairs(members) do
                        if kept[m] or whole[m] or keptBelow[m] then reps[#reps + 1] = m end
                    end
                    for _, m in ipairs(members) do
                        if not (kept[m] or whole[m] or keptBelow[m]) then
                            local stay = m.IsObjectType and (m:IsObjectType("ScrollFrame") or m:IsObjectType("Slider"))
                            for i = 1, #reps do
                                if stay then break end
                                stay = Covers(m, reps[i]) or Covers(reps[i], m)
                            end
                            if not stay then
                                hidden[m] = true
                                m:Hide()
                            end
                        end
                    end
                    done[list] = members
                end
            end
            for list, members in pairs(done) do
                for _, m in ipairs(members) do
                    if not hidden[m] then Reanchor(m) end
                end
                Compact(list, members, not roots[list])
            end
        end
        box:SetScript("OnTextChanged", function(self)
            local text = self:GetText() or ""
            placeholder:SetShown(text == "")
            Narrow(text)
        end)
        box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        box:SetScript("OnEscapePressed", function(self)
            self:SetText("")
            self:ClearFocus()
        end)
        AddSearchClear(shell, box)

        local noBox = { [L["OPT_TAB_HOME"]] = true, [L["OPT_TAB_FEEDBACK"]] = true }
        local function SyncShown()
            local i = CurrentTab()
            local label = i and tabButtons[i] and tabButtons[i].label and tabButtons[i].label:GetText()
            shell:SetShown(i ~= nil and not noBox[label])
        end
        for _, tf in ipairs(tabFrames) do
            tf:HookScript("OnHide", function() if box:GetText() ~= "" then box:SetText("") end end)
            tf:HookScript("OnShow", SyncShown)
        end
        SyncShown()
        optionsFrame.ClearPageSearch = function() if box:GetText() ~= "" then box:SetText("") end end
    end






    do
        local shell = CreateFrame("Frame", nil, sidebar)
        optionsFrame.settingsSearchShell = shell
        shell:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, -6)
        shell:SetPoint("RIGHT", sidebar, "RIGHT", -8, 0)
        shell:SetHeight(22)


        SearchWell(shell)
        optionsFrame.RestyleSettingsSearch = function()
            for i = 1, #searchWells do PaintSearchWell(searchWells[i]) end
            for i = 1, #groupRings do PaintGroupRing(groupRings[i]) end
            for i = 1, #classicSelectors do DressSelector(classicSelectors[i]) end
            for cb in pairs(settingChecks) do cb:RefreshVisual() end
        end
        optionsFrame.RepaintFlyouts = function()
            for i = 1, #optionsFlyouts do PaintFlyoutWell(optionsFlyouts[i]) end
        end
        local icon = shell.ringInset:CreateTexture(nil, "OVERLAY")
        icon:SetSize(13, 13)
        icon:SetPoint("LEFT", shell, "LEFT", 7, 0)
        icon:SetAtlas("common-search-magnifyingglass")
        local box = CreateFrame("EditBox", nil, shell)
        box:SetFrameLevel(shell.ringInset:GetFrameLevel() + 2)
        box:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        box:SetPoint("RIGHT", shell, "RIGHT", -8, 0)
        box:SetHeight(18)
        box:SetAutoFocus(false)
        box:SetFontObject(SMALL_HIGHLIGHT_FONT)
        box:SetMaxLetters(48)
        local placeholder = box:CreateFontString(nil, "ARTWORK", OPT_FONTS.GameFontDisableSmall)
        placeholder:SetPoint("LEFT", box, "LEFT", 0, 0)
        placeholder:SetText(L["OPT_SEARCH_PLACEHOLDER"])
        Utils.StyleSearchHint(placeholder, icon)
        optionsFrame.settingsSearchBox = box

        local index





        local function IndexableLabel(fs)
            if fs._efNoIndex then return false end
            if fs._efSearchLabel then return true end


            local owner = fs.GetParent and fs:GetParent()
            if owner and owner.IsObjectType and owner:IsObjectType("Button") then return false end
            local fontObj = fs.GetFontObject and fs:GetFontObject()
            local fontName = fontObj and fontObj.GetName and fontObj:GetName()

            return fontName ~= nil and string.find(fontName, "^GameFontNormal") ~= nil
                or fontName ~= nil and string.find(fontName, "^EasyFindOptionsGameFontNormal") ~= nil
        end
        local function IndexFrame(frame, tabIndex, pageName, pageID, pageByFrame, seen)
            if not frame or frame == shell then return end
            local regions = { frame:GetRegions() }
            for i = 1, #regions do
                local r = regions[i]
                if r.IsObjectType and r:IsObjectType("FontString") and IndexableLabel(r) then
                    local text = r:GetText()
                    if text and text ~= "" and #text <= 60 then
                        local plain = Utils.StripMarkup and Utils.StripMarkup(text) or text
                        local key = tabIndex .. "|" .. (pageID or "") .. "|" .. plain

                        if plain:find("[%w\128-\255]") and not seen[key] then
                            seen[key] = true
                            index[#index + 1] = {
                                label = plain, lower = string.lower(plain), region = r,
                                tab = tabIndex, pageID = pageID, pageName = pageName, target = frame,
                            }
                        end
                    end
                end
            end
            local children = { frame:GetChildren() }
            for i = 1, #children do
                local child = children[i]
                local page = pageByFrame[child]
                IndexFrame(child, tabIndex, page and page.name or pageName,
                    page and page.id or pageID, pageByFrame, seen)
            end
        end
        local function BuildIndex()
            index = {}
            local seen = {}
            local pageByFrame = {}
            for _, p in ipairs(Options:ExtensionPageFrames()) do pageByFrame[p.frame] = p end
            for ti, tf in ipairs(tabFrames) do
                IndexFrame(tf, ti, nil, nil, pageByFrame, seen)
            end
        end
        optionsFrame.InvalidateSettingsIndex = function() index = nil end
        optionsFrame.SettingsIndex = function()
            if not index then BuildIndex() end
            return index
        end
        optionsFrame.TabName = function(i)
            local btn = tabButtons[i]
            return btn and btn.label and btn.label:GetText() or ""
        end

        local results = CreateFrame("Frame", "EasyFindSettingsSearchResults", UIParent, "BackdropTemplate")
        results._efSurface = "options"
        results:SetFrameStrata("TOOLTIP")
        results:SetFrameLevel(9600)
        results:EnableMouse(true)
        ns.StyleMenuPanel(results)
        results.rows = {}


        results.measure = results:CreateFontString(nil, "ARTWORK", OPT_FONTS.GameFontHighlightSmall)
        results.measure:Hide()
        results.measurePath = results:CreateFontString(nil, "ARTWORK", OPT_FONTS.GameFontDisableSmall)
        results.measurePath:Hide()
        Utils.RegisterClickGuard(results)
        results:Hide()
        local ROW_H, PAD, RESULTS_W, MAX_HITS = 22, 6, 200, 12
        local hits, selected = {}, 0
        local function Jump(hit)
            results:Hide()
            box:ClearFocus()
            SwitchToTab(hit.tab)
            if hit.pageID then
                SelectExtensionPage(hit.pageID)
                RevealOnExtensionPage(hit.pageID, hit.target)
            end
            FlashFrame(hit.target)
        end
        optionsFrame.JumpToSetting = Jump
        local function PaintSelection()
            for i, row in ipairs(results.rows) do
                if row:IsShown() and row.SetMenuHighlightFocused then
                    row:SetMenuHighlightFocused(i == selected)
                end
            end
        end
        local function ShowHits()
            local n = math.min(#hits, MAX_HITS)
            for i = 1, n do
                local row = results.rows[i]
                if not row then
                    row = CreateFrame("Button", nil, results)
                    row:SetHeight(ROW_H)
                    Utils.InstallMenuRowHighlight(row)
                    row.label = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontHighlightSmall)
                    row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
                    row.label:SetJustifyH("LEFT")
                    row.label:SetWordWrap(false)
                    row.path = row:CreateFontString(nil, "OVERLAY", OPT_FONTS.GameFontDisableSmall)
                    row.path:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                    row.path:SetJustifyH("RIGHT")
                    row.path:SetWordWrap(false)
                    row.label:SetPoint("RIGHT", row.path, "LEFT", -6, 0)
                    row:SetScript("OnClick", function(self) Jump(self.hit) end)


                    row:HookScript("OnEnter", function(self)
                        if self.index and self.index ~= selected then
                            selected = self.index
                            PaintSelection()
                        end
                    end)
                    results.rows[i] = row
                end
                local hit = hits[i]
                row.index = i
                row.hit = hit
                row.label:SetText(hit.label)
                local tabBtn = tabButtons[hit.tab]
                local tabName = tabBtn and tabBtn.label and tabBtn.label:GetText() or ""
                row.path:SetText(hit.pageName and (tabName .. " > " .. hit.pageName) or tabName)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", results, "TOPLEFT", PAD, -PAD - (i - 1) * ROW_H)
                row:SetPoint("RIGHT", results, "RIGHT", -PAD, 0)
                row:Show()
            end
            for i = n + 1, #results.rows do results.rows[i]:Hide() end
            if n == 0 then results:Hide(); return end
            local widest = 0
            for i = 1, n do
                results.measure:SetText(hits[i].label or "")
                results.measurePath:SetText(results.rows[i].path:GetText() or "")
                widest = math.max(widest, (results.measure:GetStringWidth() or 0)
                    + 6 + (results.measurePath:GetStringWidth() or 0))
            end
            results:SetSize(math.max(RESULTS_W, math.ceil(PAD * 2 + 6 + widest + 6)), PAD * 2 + n * ROW_H)
            results:SetScale(optionsFrame:GetEffectiveScale() / UIParent:GetEffectiveScale())
            Utils.RefreshMenuRowHighlights(results, results.rows)
            Utils.OpenDropdownBelow(results, shell, 2)
            results:Show()
            selected = 1
            PaintSelection()
        end
        local function Run(text)
            if not index then BuildIndex() end
            local q = Utils.StripMarkup and Utils.StripMarkup(text) or text
            q = string.lower(q or "")
            hits = {}
            if q == "" then results:Hide(); return end
            local Database = ns.Database
            local qLen = #q
            for _, entry in ipairs(index) do
                local score = 0
                if Database and Database.ScoreName then
                    score = Database:ScoreName(entry.lower, q, qLen) or 0
                elseif string.find(entry.lower, q, 1, true) then
                    score = 1
                end
                if score > 0 then
                    hits[#hits + 1] = { score = score, label = entry.label, tab = entry.tab,
                        pageID = entry.pageID, pageName = entry.pageName, target = entry.target }
                end
            end
            table.sort(hits, function(a, b)
                if a.score ~= b.score then return a.score > b.score end
                return a.label < b.label
            end)
            ShowHits()
        end
        box:SetScript("OnTextChanged", function(self, userInput)
            local text = self:GetText() or ""
            placeholder:SetShown(text == "")
            if userInput then Run(text) end
        end)
        box:SetScript("OnEnterPressed", function()
            if hits[selected] then Jump(hits[selected]) end
        end)
        box:SetScript("OnEscapePressed", function(self)
            if (self:GetText() or "") ~= "" then
                self:SetText("")
                results:Hide()
            else
                self:ClearFocus()
            end
        end)
        box:SetScript("OnKeyDown", function(_, key)
            if not results:IsShown() then return end
            local n = math.min(#hits, MAX_HITS)
            if n == 0 then return end
            if key == "DOWN" then
                selected = selected % n + 1
                PaintSelection()
            elseif key == "UP" then
                selected = (selected - 2) % n + 1
                PaintSelection()
            end
        end)
        box:SetScript("OnEditFocusGained", function(self)
            if (self:GetText() or "") ~= "" then Run(self:GetText()) end
        end)
        Utils.ReleaseFocusOnOutsideClick(box)
        AddSearchClear(shell, box)
        results:HookScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
        results:HookScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
        results:SetScript("OnEvent", function(self, event)
            if event ~= "GLOBAL_MOUSE_DOWN" then return end
            if Utils.IsFrameVisiblyMouseOver(self) or Utils.IsFrameVisiblyMouseOver(shell) then return end
            self:Hide()
        end)
        optionsFrame:HookScript("OnHide", function() results:Hide() end)
    end

    SwitchToTab(1)

    optionsFrame:Hide()

    isInitialized = true
end

function Options:DoResetPositions()
    ApplyDefaultKeys(UI_POSITION_KEYS)
    if ns.Search and ns.Search.ResetPosition then ns.Search:ResetPosition() end
    ResetOptionsPosition()
    SyncOptionControls()
    RefreshUIRuntime(true)
end

function Options:ConfirmResetAll()
    ShowResetConfirm(L["POPUP_RESET_ALL_SETTINGS"], function() Options:DoResetAll() end)
end

function Options:ConfirmResetPositions()
    ShowResetConfirm(L["POPUP_RESET_ALL_POSITIONS"], function() Options:DoResetPositions() end)
end



function Options:OnProfileSwitched()
    if not isInitialized then return end
    SyncOptionControls()
    if ns.RefreshBindTables then ns.RefreshBindTables() end
    if optionsFrame and optionsFrame.RefreshProfilesTab then optionsFrame.RefreshProfilesTab() end
end

function Options:DoResetAll()
    local needsReload = EasyFind.db.enableMapSearch == false
    EasyFind:ResetSettingsToDefaults()
    if EasyFind.ResetAccountKeybindsToDefaults then
        EasyFind:ResetAccountKeybindsToDefaults()
    end
    ResetOptionsPosition()
    ClearMapRuntime()

    SyncOptionControls()
    if ns.RefreshAddonFont then ns.RefreshAddonFont() end
    RefreshUIRuntime(true)
    RefreshMapRuntime()
    EasyFind:UpdateMinimapButton()

    if needsReload then ns.SettingsRows.ShowReloadPrompt() end
end

function Options:DoResetUI()
    ApplyDefaultKeys(UI_RESET_KEYS)
    SyncOptionControls()
    RefreshUIRuntime(true)
end

function Options:DoResetMap()
    ApplyDefaultKeys(MAP_RESET_KEYS)
    SyncOptionControls()
    RefreshMapRuntime()
end

function Options:DoResetUIPositions()
    ApplyDefaultKeys(UI_POSITION_KEYS)
    SyncOptionControls()
    RefreshUIRuntime(true)
end







local function FitToHost(host)
    local w, h = host:GetSize()
    local fw, fh = optionsFrame:GetWidth(), optionsFrame:GetHeight()
    if not (w and h and w > 1 and h > 1) then
        C_Timer.After(0, function()
            if optionsFrame:GetParent() == host and optionsFrame.paged and host:GetWidth() > 1 then FitToHost(host) end
        end)
        return
    end
    optionsFrame:SetScale(math.min(w / fw, h / fh))
    optionsFrame:ClearAllPoints()
    optionsFrame:SetPoint("CENTER", host, "CENTER", 0, 0)
end


function Options:EmbedInBlizzardPanel(panel, pageName)
    if not isInitialized then Options:Initialize() end
    Options.embedded = true
    Options.embedding = true
    optionsFrame.SetPagedLayout(ns.OptionsSubcategories ~= nil)

    optionsFrame.titleText:Hide()
    optionsFrame.closeBtn:Hide()



    optionsFrame.bgTex:Show()
    optionsFrame:SetBackdrop(nil)
    optionsFrame:SetScale(1)

    optionsFrame:SetParent(panel)
    optionsFrame:ClearAllPoints()
    optionsFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -10)
    if optionsFrame.paged then
        FitToHost(panel)
        if not panel.efFitHooked then
            panel.efFitHooked = true
            panel:HookScript("OnSizeChanged", function(self)
                if optionsFrame:GetParent() == self and optionsFrame.paged then FitToHost(self) end
            end)
        end
    end
    optionsFrame:SetFrameStrata("HIGH")
    optionsFrame:SetMovable(false)
    optionsFrame:RegisterForDrag()

    Options:Show()
    if optionsFrame.paged then optionsFrame.SwitchToTab(optionsFrame.tabIndexByName[pageName or ""] or 1) end
    Options.embedding = false
end

function Options:OnBlizzardPanelHide()
    if not Options.embedded then return end
    Options:RestoreStandalone()
    optionsFrame:Hide()
end

function Options:OpenAtAliases()
    self:Show()
    if optionsFrame and optionsFrame.SwitchToTab and self._aliasesTabIndex then
        optionsFrame.SwitchToTab(self._aliasesTabIndex)
    end
end

function Options:OpenAtSnippets()
    self:OpenAtExtension("snippets")
end

function Options:Show()
    if not isInitialized then
        self:Initialize()
    end

    if self.embedded and not self.embedding then
        self:RestoreStandalone()
    end

    SyncOptionControls()

    if not self.embedded and optionsFrame.bgTex then
        optionsFrame.bgTex:SetAlpha(OPTIONS_PANEL_ALPHA)
        optionsFrame:SetFrameStrata(OPTIONS_FRAME_STRATA)
        optionsFrame:SetFrameLevel(OPTIONS_FRAME_LEVEL)
    end
    optionsFrame:Show()
    optionsFrame:Raise()
end

function Options:RestoreStandalone()
    self.embedded = false
    optionsFrame.SetPagedLayout(false)

    optionsFrame.titleText:Show()
    optionsFrame.closeBtn:Show()
    optionsFrame.bgTex:Show()
    optionsFrame.bgTex:SetAlpha(OPTIONS_PANEL_ALPHA)
    optionsFrame:SetBackdrop(nil)
    optionsFrame:SetScale(OPTIONS_PANEL_SCALE)

    optionsFrame:SetParent(UIParent)
    optionsFrame:SetFrameStrata(OPTIONS_FRAME_STRATA)
    optionsFrame:SetFrameLevel(OPTIONS_FRAME_LEVEL)
    optionsFrame:SetMovable(true)
    optionsFrame:RegisterForDrag("LeftButton")

    optionsFrame:ClearAllPoints()
    if EasyFind.db.optionsPosition then
        local pos = EasyFind.db.optionsPosition
        optionsFrame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function Options:Hide()
    if optionsFrame then
        optionsFrame:Hide()
    end
end

function Options:Toggle()
    if not isInitialized then
        self:Initialize()
    end

    if self.embedded then
        self:RestoreStandalone()
        self:Show()
        return
    end

    if optionsFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end
