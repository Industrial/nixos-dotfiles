
local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).stale then return end









local ThemeStudio = {}
ns.ThemeStudio = ThemeStudio

local Utils = ns.Utils
local L = ns.L

local type = type
local xpcall = Utils.xpcall
local ErrorHandler = Utils.ErrorHandler
local mfloor, mceil = Utils.mfloor, Utils.mceil
local tremove = Utils.tremove
local strtrim = strtrim
local CreateFrame = CreateFrame
local UIParent = UIParent

local PREVIEW_NAME = "Studio Preview"
local NAME_MAX = 24
local DEFAULT_DRAFT_COLOR = { 0.5, 0.5, 0.5 }
local CIRCLE_TEX = "Interface\\AddOns\\EasyFind\\textures\\FilterButtonCircle"

local WINDOW_W, WINDOW_H = 780, 530


local MOCK_ROW_H = 38
local MOCK_ROW_COUNT = 2

local MOCK_TOP = -94
local LIST_W = 168
local PANEL_PAD = 12
local CONTROLS_W = 216

local SLOT_LABEL_KEYS = {
    windowFill       = "OPT_SLOT_WINDOW_FILL",
    windowFillBottom = "OPT_SLOT_GRADIENT_BOTTOM",
    windowFillTop    = "OPT_SLOT_GRADIENT_TOP",
    pathColor        = "OPT_SLOT_SUBTEXT",
    pathColorHover   = "OPT_SLOT_SUBTEXT_HOVER",
    leafColor        = "OPT_SLOT_MAIN_TEXT",
    chromeGlyph      = "OPT_SLOT_CHROME_GLYPHS",
    mutedGlyph       = "OPT_SLOT_MUTED_HINTS",
    textFaint        = "OPT_SLOT_FAINT_TEXT",
    accent           = "OPT_SLOT_ACCENT",
    controlAccent    = "OPT_SLOT_CONTROL_ACCENT",
    rowHover         = "OPT_SLOT_ROW_HOVER",
    borderColor      = "OPT_SLOT_BORDER",
    selection        = "OPT_SLOT_SELECTION",
    separator        = "OPT_SLOT_SEPARATORS",
    backdropColor    = "OPT_SLOT_BACKDROP",
    backdropBorder   = "OPT_SLOT_BACKDROP_BORDER",
}
local SLOT_HAS_ALPHA = {
    pathColor = true, pathColorHover = true, mutedGlyph = true, accent = true,
    selection = true, separator = true, backdropColor = true, backdropBorder = true,
    rowHover = true, borderColor = true,
}



local MOCK_SPECIFIC_ICONS = { 132261, 133877 }

local studio
local draft
local swatchRows = {}
local themeListRows = {}
local borderCheck, nameBox, deleteBtn, iconModeMenu
local preview

local pageIndex = 1
local pageUI = {}
local previewToken = 0



local themedTexts = {}
local function RegisterStudioText(fs, alpha)
    fs._efOwnColor = true
    fs._studioAlpha = alpha
    themedTexts[#themedTexts + 1] = fs
end
local function RepaintStudioTexts()
    local r, g, b = ns.TooltipTextColor()
    for i = 1, #themedTexts do
        local fs = themedTexts[i]
        fs:SetTextColor(r, g, b, fs._studioAlpha or 1)
    end
    for i = 1, #swatchRows do
        local label = swatchRows[i].label
        if label then label:SetTextColor(r, g, b, 1) end
    end
    for i = 1, #themeListRows do
        local label = themeListRows[i].label
        if label then label:SetTextColor(r, g, b, 1) end
    end
    if studio and studio._efThemeSeps and ns.RetintMenuSeparators then
        ns.RetintMenuSeparators(studio)
    end
end

local function DraftStore()
    if not (EasyFind and EasyFind.db) then return nil end
    EasyFind.db.themeStudioDraft = type(EasyFind.db.themeStudioDraft) == "table"
        and EasyFind.db.themeStudioDraft or {}
    local store = EasyFind.db.themeStudioDraft
    if type(store.palette) ~= "table" then store.palette = {} end
    return store
end

local function CopyColor(c)
    if type(c) ~= "table" then return nil end
    return { c[1], c[2], c[3], c[4] }
end



local CopyPaletteInto
function CopyPaletteInto(dst, src)
    wipe(dst)
    local slots = ns.ThemeShare and ns.ThemeShare.COLOR_SLOTS or {}
    for i = 1, #slots do
        local key = slots[i].key
        dst[key] = CopyColor(src and src[key])
    end
    if src and src.light then dst.light = true end
    if src and src.borderHidden then dst.borderHidden = true end
    if src and type(src.fillTexture) == "string" then dst.fillTexture = src.fillTexture end
    if src and type(src.surfaces) == "table" then
        for id, look in pairs(src.surfaces) do
            if type(look) == "table" then
                dst.surfaces = dst.surfaces or {}
                dst.surfaces[id] = {}
                CopyPaletteInto(dst.surfaces[id], look)
                dst.surfaces[id].surfaces = nil
            end
        end
    end
end

local function DraftValid()
    if not (draft and ns.ThemeShare) then return false end
    local slots = ns.ThemeShare.COLOR_SLOTS
    for i = 1, #slots do
        local slot = slots[i]
        if slot.required and type(draft.palette[slot.key]) ~= "table" then return false end
    end
    return true
end

local function DraftColor(key, fallback)
    local c = draft and draft.palette[key]
    if c then return c[1], c[2], c[3], c[4] end
    local f = fallback or DEFAULT_DRAFT_COLOR
    return f[1], f[2], f[3], f[4]
end



local function Pages()
    local out = { { label = L["THEME_PAGE_ALL"] } }
    for _, surface in ipairs(ns.THEME_SURFACES or {}) do out[#out + 1] = surface end
    return out
end

local function CurrentPage()
    local pages = Pages()
    if pageIndex > #pages then pageIndex = 1 end
    return pages[pageIndex]
end

local function OwnLook(id)
    local surfaces = draft and draft.palette.surfaces
    return id and surfaces and surfaces[id] or nil
end



local function TargetLook()
    return OwnLook(CurrentPage().id) or draft.palette
end







local RepaintWindowMock



local function PageMock(page)
    if not page.preview and page.addon and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, page.addon)
    end
    if not page.preview then return nil end
    preview.mocks = preview.mocks or {}
    local mock = preview.mocks[page.id]
    if not mock then
        mock = page.preview(studio, preview.card:GetWidth())
        mock:SetPoint("TOPLEFT", preview.card, "TOPLEFT", 0, 0)
        preview.mocks[page.id] = mock
    end
    return mock
end

local function RepaintPreviewCard()
    if not (preview and draft) then return end
    local page = CurrentPage()
    local mock = page.id and PageMock(page)
    for _, m in pairs(preview.mocks or {}) do m:SetShown(m == mock) end
    preview.card:SetShown(page.id == nil)
    preview.card:SetHeight(mock and mock.pageHeight or preview.cardHeight)
    if preview.window then preview.window.card:SetShown(page.id ~= nil and not mock) end
    if mock then
        if mock.Repaint then mock.Repaint() end
        return
    end
    if page.id then
        RepaintWindowMock(page)
        return
    end
    if ns.SetRoundedRectRingShown then ns.SetRoundedRectRingShown(preview.card, not draft.palette.borderHidden) end
    local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
    if not theme then return end
    local light = theme.lightTheme



    local glyph = theme.chromeGlyph or { 1, 1, 1 }
    local blend = light and "BLEND" or "ADD"
    preview.glyph:SetVertexColor(glyph[1], glyph[2], glyph[3], 1)
    preview.filterArrow:SetBlendMode(blend)
    preview.filterArrow:SetVertexColor(glyph[1], glyph[2], glyph[3], 1)
    for i = 1, #preview.appDots do
        preview.appDots[i]:SetVertexColor(glyph[1], glyph[2], glyph[3], 1)
    end

    local faint = theme.textFaint or { 0.5, 0.5, 0.5 }
    preview.placeholder:SetTextColor(faint[1], faint[2], faint[3], 1)
    preview.placeholder:SetShadowColor(0, 0, 0, light and 0 or 1)
    local sep = theme.separatorColor or { 0.5, 0.45, 0.3, 0.35 }
    preview.barLine:SetColorTexture(sep[1], sep[2], sep[3], sep[4] or 0.35)

    local leaf = theme.leafColor or { 0.9, 0.9, 0.9 }
    local path = theme.pathColor or { 0.65, 0.6, 0.55 }
    local hover = theme.pathColorHover or { 1, 1, 1 }
    local shadow = light and 0 or 1



    local SetScaledFont = ns.Results and ns.Results.SetScaledFont

    local iconMode = EasyFind.db.iconVisibility or "all"
    local showGeneral = iconMode == "all" or iconMode == "general"
    local showSpecific = iconMode == "all" or iconMode == "specific"
    for i = 1, #preview.rows do
        local row = preview.rows[i]
        if SetScaledFont then
            ns.Results:SetScaledFont(row.name, theme.pathFont or ns.LEAF_FONT)
            ns.Results:SetScaledFont(row.sub, ns.LEAF_FONT)
        end
        row.name:SetTextColor(leaf[1], leaf[2], leaf[3], 1)
        row.name:SetShadowColor(0, 0, 0, shadow)
        if row.hovered then
            row.sub:SetTextColor(hover[1], hover[2], hover[3], 1)
        else
            row.sub:SetTextColor(path[1], path[2], path[3], path[4] or 1)
        end
        row.sub:SetShadowColor(0, 0, 0, shadow)



        Utils.UpdateRoundedRowWash(row, row.hovered)
        local washShown = row.hoverWash and row.hoverWash:IsShown()
        row.glow:SetShown(row.hovered and not washShown)


        row.leftIcon:SetVertexColor(glyph[1], glyph[2], glyph[3], 1)
        row.leftIcon:SetShown(showGeneral)
        row.rightIcon:SetShown(showSpecific)
    end
end



local function SetLightFromFill(look)
    local c = look and look.windowFill
    if not c then return end
    look.light = (0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3] > 0.5) or nil
end

local function SetLightEverywhere()
    SetLightFromFill(draft.palette)
    for _, look in pairs(draft.palette.surfaces or {}) do SetLightFromFill(look) end
end



local function RunPreview()
    if not (draft and DraftValid() and ns.UI_THEME_PALETTES and ns.ApplyUITheme) then return end
    SetLightEverywhere()
    ns.UI_THEME_PALETTES[PREVIEW_NAME] = draft.palette



    ns.ApplyUITheme(PREVIEW_NAME)
    RepaintPreviewCard()

    if ns.RetintPanelText and studio then ns.RetintPanelText(studio) end
    RepaintStudioTexts()
    local of = ns.optionsFrame
    if of and of.RepaintTheme and of:IsShown() then
        xpcall(of.RepaintTheme, ErrorHandler, of)
    end
end

local function SchedulePreview()
    previewToken = previewToken + 1
    local token = previewToken
    Utils.SafeAfter(0.05, function()
        if token == previewToken then RunPreview() end
    end)
end

local function ClearPreview()
    previewToken = previewToken + 1
    if ns.UI_THEME_PALETTES then ns.UI_THEME_PALETTES[PREVIEW_NAME] = nil end
    if ns.ApplyUITheme and EasyFind and EasyFind.db then
        ns.ApplyUITheme(EasyFind.db.uiTheme)
        if ns.RetintPanelText and studio then ns.RetintPanelText(studio) end
        RepaintStudioTexts()
        local of = ns.optionsFrame
        if of and of.RepaintTheme and of:IsShown() then
            xpcall(of.RepaintTheme, ErrorHandler, of)
        end
    end
end

local function PaintSwatch(row)
    local color = draft and TargetLook()[row.slotKey]
    if color then
        row.swatch:SetColorTexture(color[1], color[2], color[3], 1)
    else
        row.swatch:SetColorTexture(DEFAULT_DRAFT_COLOR[1], DEFAULT_DRAFT_COLOR[2],
            DEFAULT_DRAFT_COLOR[3], 0.35)
    end
    if row.label then
        local tr, tg, tb = ns.TooltipTextColor()
        row.label:SetTextColor(tr, tg, tb, 1)
    end
end

local RefreshThemeList

local ICON_MODES = {
    { value = "all",      label = L["OPT_ICONS_ALL"] },
    { value = "general",  label = L["OPT_ICONS_GENERAL"] },
    { value = "specific", label = L["OPT_ICONS_SPECIFIC"] },
}

local function RefreshIconModeButtons()
    local mode = EasyFind.db.iconVisibility or "all"
    for _, m in ipairs(ICON_MODES) do
        if m.value == mode and iconModeMenu then iconModeMenu:SetLabel(m.label) end
    end
end



local function Dropdown(parent, name, width, choices)
    local btn = ns.CreateModernButton(parent, "", width, 20)
    local label = btn._label
    label:ClearAllPoints()
    label:SetPoint("LEFT", btn, "LEFT", 8, 0)
    label:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    btn.chevron = btn:CreateTexture(nil, "OVERLAY")
    btn.chevron:SetSize(10, 10)
    btn.chevron:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    Utils.SetChevronTexture(btn.chevron)
    btn:SetScript("OnClick", function(self) ns.ShowTogglePopup(name, self, choices()) end)
    function btn:SetLabel(text) label:SetText(text) end
    return btn
end

local function RefreshEditor()
    if not draft then return end
    for i = 1, #swatchRows do PaintSwatch(swatchRows[i]) end
    local page = CurrentPage()

    if borderCheck then
        borderCheck:SetShown(page.id == nil)
        borderCheck:SetChecked(not draft.palette.borderHidden)
    end
    if pageUI.menu then pageUI.menu:SetLabel(page.label) end
    if pageUI.check then
        pageUI.check:SetShown(page.id ~= nil)
        pageUI.check:SetChecked(OwnLook(page.id) ~= nil)
    end
    RefreshIconModeButtons()
    if nameBox and not nameBox:HasFocus() then nameBox:SetText(draft.name or "") end
    if deleteBtn then
        deleteBtn:SetShown(draft.sourceCustom ~= nil and ns.ThemeShare
            and ns.ThemeShare:IsCustomTheme(draft.sourceCustom))
    end
    if RefreshThemeList then RefreshThemeList() end
    RepaintPreviewCard()
end





local history, historyIndex = {}, 0
local historyToken = 0
local HISTORY_CAP = 50
local undoBtn, redoBtn

local function HistorySnapshot()
    local snap = { name = draft and draft.name or "", palette = {},
        baseName = draft and draft.baseName, sourceCustom = draft and draft.sourceCustom }
    if draft then CopyPaletteInto(snap.palette, draft.palette) end
    return snap
end

local function SnapshotKey(snap)
    if not (ns.ThemeShare and ns.ThemeShare.ExportPalette) then return tostring(snap) end
    return ns.ThemeShare:ExportPalette(snap.name or "", snap.palette) or ""
end

local function UpdateHistoryButtons()
    if undoBtn then undoBtn:SetAlpha(historyIndex > 1 and 1 or 0.35) end
    if redoBtn then redoBtn:SetAlpha(historyIndex < #history and 1 or 0.35) end
end

local function PushHistoryNow()
    historyToken = historyToken + 1
    if not draft then return end
    local snap = HistorySnapshot()
    if historyIndex >= 1 and history[historyIndex]
       and SnapshotKey(history[historyIndex]) == SnapshotKey(snap) then
        return
    end
    for i = #history, historyIndex + 1, -1 do history[i] = nil end
    history[#history + 1] = snap
    if #history > HISTORY_CAP then
        tremove(history, 1)
    end
    historyIndex = #history
    UpdateHistoryButtons()
end

local function ScheduleHistoryPush()
    historyToken = historyToken + 1
    local token = historyToken
    Utils.SafeAfter(0.6, function()
        if token == historyToken then PushHistoryNow() end
    end)
end

local function RestoreHistorySnapshot(snap)
    if not (draft and snap) then return end
    draft.name = snap.name
    draft.baseName = snap.baseName
    draft.sourceCustom = snap.sourceCustom
    CopyPaletteInto(draft.palette, snap.palette)
    RefreshEditor()
    RefreshThemeList()
    SchedulePreview()
    UpdateHistoryButtons()
end

local function DoUndo()
    PushHistoryNow()
    if historyIndex <= 1 then return end
    historyIndex = historyIndex - 1
    RestoreHistorySnapshot(history[historyIndex])
end

local function DoRedo()
    if historyIndex >= #history then return end
    historyIndex = historyIndex + 1
    RestoreHistorySnapshot(history[historyIndex])
end

local pickerSlotKey, pickerPrior



local function PickerReader(method)
    local picker = ColorPickerFrame
    if picker[method] then return picker end
    local inner = picker.Content and picker.Content.ColorPicker
    if inner and inner[method] then return inner end
    return nil
end

local function ReadPickerColor()
    local rgb = PickerReader("GetColorRGB")
    if not rgb then return nil end
    local r, g, b = rgb:GetColorRGB()
    if type(r) ~= "number" then return nil end
    local alphaSource = PickerReader("GetColorAlpha")
    local a = alphaSource and alphaSource:GetColorAlpha() or nil
    return r, g, b, a
end

local function ApplyPickerColor()
    if not (draft and pickerSlotKey) then return end
    local r, g, b, a = ReadPickerColor()
    if not r then return end
    local look = TargetLook()
    local color = look[pickerSlotKey]
    if not color then
        color = {}
        look[pickerSlotKey] = color
    end
    color[1], color[2], color[3] = r, g, b
    if SLOT_HAS_ALPHA[pickerSlotKey] and a then
        color[4] = a
    end
    for i = 1, #swatchRows do
        if swatchRows[i].slotKey == pickerSlotKey then PaintSwatch(swatchRows[i]) end
    end
    SchedulePreview()
    ScheduleHistoryPush()
end

local function CancelPickerColor()
    if not (draft and pickerSlotKey) then return end
    TargetLook()[pickerSlotKey] = pickerPrior and CopyColor(pickerPrior) or nil
    RefreshEditor()
    SchedulePreview()
end

local function OpenPickerForSlot(slotKey)
    if not (draft and ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then return end
    pickerSlotKey = slotKey
    local look = TargetLook()
    pickerPrior = CopyColor(look[slotKey])
    local seed = look[slotKey] or look.windowFill or DEFAULT_DRAFT_COLOR
    local info = {
        hasOpacity = SLOT_HAS_ALPHA[slotKey] or false,
        opacity = seed[4] or 1,
        r = seed[1], g = seed[2], b = seed[3],
        swatchFunc = ApplyPickerColor,
        opacityFunc = ApplyPickerColor,
        cancelFunc = CancelPickerColor,
    }
    ColorPickerFrame:SetupColorPickerAndShow(info)
    if ColorPickerFrame.SetFrameStrata then ColorPickerFrame:SetFrameStrata("TOOLTIP") end
    if ColorPickerFrame.Raise then ColorPickerFrame:Raise() end


    local watch = ThemeStudio.pickerWatch
    if not watch then
        watch = CreateFrame("Frame")
        ThemeStudio.pickerWatch = watch
    end
    local lastR, lastG, lastB, lastA
    watch:SetScript("OnUpdate", function(self)
        if not (ColorPickerFrame:IsShown() and pickerSlotKey) then
            self:SetScript("OnUpdate", nil)
            return
        end
        local r, g, b, a = ReadPickerColor()
        if r and (r ~= lastR or g ~= lastG or b ~= lastB or a ~= lastA) then
            lastR, lastG, lastB, lastA = r, g, b, a
            ApplyPickerColor()
        end
    end)
end

local function LoadBase(name)
    local palette = ns.UI_THEME_PALETTES and ns.UI_THEME_PALETTES[name]
    if not (draft and palette) then return end
    CopyPaletteInto(draft.palette, palette)
    if ns.ThemeShare and ns.ThemeShare:IsCustomTheme(name) then
        draft.name = name
        draft.sourceCustom = name
    else
        draft.sourceCustom = nil
        draft.name = name
    end
    draft.baseName = name
    RefreshEditor()
    SchedulePreview()
    PushHistoryNow()
end

local function DoSave()
    if not (draft and ns.ThemeShare) then return end



    if ns.ThemeShare.IsBuiltinName and ns.ThemeShare:IsBuiltinName(draft.name) then
        if ns.ShowThemedDialog then
            ns.ShowThemedDialog({
                text = (L["THEME_NAME_RESERVED"]):format(strtrim(draft.name or "")),
                acceptText = _G["OKAY"] or "Okay",
                onAccept = function()
                    if nameBox then
                        nameBox:SetFocus()
                        nameBox:HighlightText()
                    end
                end,
            })
        end
        return
    end
    SetLightEverywhere()
    local finalName = ns.ThemeShare:SaveCustomTheme(draft.name or "", draft.palette)
    if not finalName then return end
    draft.name = finalName
    draft.sourceCustom = finalName
    draft.baseName = finalName
    if ns.UI_THEME_PALETTES then ns.UI_THEME_PALETTES[PREVIEW_NAME] = nil end
    EasyFind.db.uiTheme = finalName
    if ns.ApplyUITheme then ns.ApplyUITheme(finalName) end
    local of = ns.optionsFrame
    if of then
        if of.RebuildThemeFlyout then xpcall(of.RebuildThemeFlyout, ErrorHandler) end
        if of.RepaintTheme and of:IsShown() then xpcall(of.RepaintTheme, ErrorHandler, of) end
        if of.themeBtnText then of.themeBtnText:SetText(finalName) end
    end
    RefreshEditor()
end

local function DoExport()
    if not (draft and ns.ThemeShare) then return end
    local code = ns.ThemeShare:ExportPalette(draft.name or "Theme", draft.palette)
    if code then Utils.CopyToClipboard(code) end
end

local function DoDelete()
    if not (draft and draft.sourceCustom and ns.ThemeShare) then return end
    ns.ThemeShare:DeleteCustomTheme(draft.sourceCustom)
    draft.sourceCustom = nil
    draft.baseName = nil
    ClearPreview()
    local of = ns.optionsFrame
    if of then
        if of.RebuildThemeFlyout then xpcall(of.RebuildThemeFlyout, ErrorHandler) end
        if of.themeBtnText then of.themeBtnText:SetText(EasyFind.db.uiTheme or "Black") end
    end
    RefreshEditor()
end



local function BuiltinBases()
    local out = {}
    for _, name in ipairs(ns.UI_THEME_ORDER or {}) do
        local pal = ns.UI_THEME_PALETTES and ns.UI_THEME_PALETTES[name]
        if pal and not pal.fillTexture and not (ns.ThemeShare and ns.ThemeShare:IsCustomTheme(name)) then
            out[#out + 1] = name
        end
    end
    return out
end




function RefreshThemeList()
    if not studio then return end
    local order = {}
    for _, name in ipairs(ns.UI_THEME_ORDER or {}) do
        if ns.ThemeShare and ns.ThemeShare:IsCustomTheme(name) then order[#order + 1] = name end
    end
    if studio.noThemes then studio.noThemes:SetShown(#order == 0) end
    for i = 1, #order do
        local name = order[i]
        local row = themeListRows[i]
        if not row then
            row = CreateFrame("Button", nil, studio.listPane)
            row:SetHeight(22)
            row:SetPoint("TOPLEFT", studio.listPane, "TOPLEFT", 4, -54 - (i - 1) * 22)
            row:SetPoint("RIGHT", studio.listPane, "RIGHT", -4, 0)
            row.sel = row:CreateTexture(nil, "BACKGROUND")
            row.sel:SetAllPoints()
            row.sel:Hide()
            row.dot = row:CreateTexture(nil, "ARTWORK")
            row.dot:SetSize(12, 12)
            row.dot:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.dot:SetTexture(CIRCLE_TEX)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", row.dot, "RIGHT", 6, 0)
            row.label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.label:SetJustifyH("LEFT")
            row.label:SetWordWrap(false)
            row.lock = row:CreateTexture(nil, "OVERLAY")
            row.lock:SetSize(12, 12)
            row.lock:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.lock:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-LOCK")
            row.lock:SetTexCoord(0, 0.72, 0, 0.72)
            row.lock:Hide()
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.06)
            row:SetScript("OnClick", function(self)
                if self.themeName and not self.locked then LoadBase(self.themeName) end
            end)
            themeListRows[i] = row
        end
        row.themeName = name
        row.label:SetText(name)
        local palette = ns.UI_THEME_PALETTES and ns.UI_THEME_PALETTES[name]
        if palette and ns.ThemeSwatchColor then
            row.dot:SetVertexColor(ns.ThemeSwatchColor(palette))
        else
            row.dot:SetVertexColor(0.5, 0.5, 0.5)
        end


        row.locked = (palette and palette.fillTexture
            and not (ns.ThemeShare and ns.ThemeShare:IsCustomTheme(name))) and true or nil
        row.lock:SetShown(row.locked or false)
        row.label:SetAlpha(row.locked and 0.75 or 1)
        local isBase = draft and draft.baseName == name
        row.sel:SetShown(isBase)
        if isBase then
            local sr, sg, sb, sa = DraftColor("selection", { 0.25, 0.5, 0.9, 0.35 })
            row.sel:SetColorTexture(sr, sg, sb, (sa or 0.35) * 0.7)
        end
        row:Show()
    end
    for i = #order + 1, #themeListRows do
        themeListRows[i]:Hide()
        themeListRows[i].themeName = nil
    end
end

local function BuildPreviewCard(parent)
    preview = {}
    local card = CreateFrame("Frame", nil, parent)
    preview.card = card

    card:SetPoint("TOPLEFT", parent, "TOPLEFT", LIST_W + PANEL_PAD, MOCK_TOP)
    card:SetPoint("RIGHT", parent, "RIGHT", -(CONTROLS_W + PANEL_PAD), 0)
    preview.cardHeight = (ns.SEARCHBAR_HEIGHT or 30) + 8 + MOCK_ROW_COUNT * MOCK_ROW_H
    card:SetHeight(preview.cardHeight)




    ns.StyleMenuPanel(card)

    local barH = ns.SEARCHBAR_HEIGHT or 30
    local contentSz = barH * (ns.SEARCHBAR_FILL or 0.62)
    local iconSz = contentSz * (ns.SEARCHBAR_ICON_SCALE or 0.8)




    preview.glyph = card:CreateTexture(nil, "OVERLAY")
    preview.glyph:SetSize(iconSz, iconSz)
    preview.glyph:SetPoint("TOPLEFT", card, "TOPLEFT", (barH - iconSz) / 2, -(barH - iconSz) / 2)
    preview.glyph:SetTexture(ns.SEARCH_ICON_TEX)

    preview.placeholder = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")


    preview.placeholder._efOwnColor = true
    preview.placeholder:SetPoint("LEFT", preview.glyph, "RIGHT", 8, 0)
    preview.placeholder:SetJustifyH("LEFT")
    preview.placeholder:SetText(L["THEME_PREVIEW_PLACEHOLDER"])


    preview.filterArrow = card:CreateTexture(nil, "OVERLAY")
    preview.filterArrow:SetSize(11, 11)
    preview.filterArrow:SetPoint("TOPRIGHT", card, "TOPRIGHT", -(barH - 11) / 2, -(barH - 11) / 2)
    preview.filterArrow:SetTexture(ns.FILTER_ARROW_TEX)



    preview.appDots = {}
    local gridSize = 14
    local cell = gridSize / 3
    local dotSize = cell * 0.72
    local gridRight = -(barH - 11) / 2 - 11 - 8
    for gy = 0, 2 do
        for gx = 0, 2 do
            local dot = card:CreateTexture(nil, "OVERLAY")
            dot:SetColorTexture(1, 1, 1, 1)
            dot:SetSize(dotSize, dotSize)
            dot:SetPoint("CENTER", card, "TOPRIGHT",
                gridRight - gridSize + (gx + 0.5) * cell,
                -(barH - gridSize) / 2 - (gy + 0.5) * cell)
            local mask = card:CreateMaskTexture()
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
                "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(dot)
            dot:AddMaskTexture(mask)
            preview.appDots[#preview.appDots + 1] = dot
        end
    end

    preview.barLine = card:CreateTexture(nil, "ARTWORK")
    preview.barLine:SetHeight(1)
    preview.barLine:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -barH)
    preview.barLine:SetPoint("RIGHT", card, "RIGHT", -8, 0)




    preview.rows = {}
    for i = 1, MOCK_ROW_COUNT do
        local row = CreateFrame("Frame", nil, card)
        row:SetHeight(MOCK_ROW_H - 2)

        row:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -barH - 6 - (i - 1) * MOCK_ROW_H)
        row:SetPoint("RIGHT", card, "RIGHT", -4, 0)
        row.hovered = (i == 2)


        row.glow = row:CreateTexture(nil, "BACKGROUND")
        row.glow:SetAllPoints()
        row.glow:SetBlendMode("ADD")
        row.glow:SetColorTexture(1, 1, 1, 0.08)
        row.glow:Hide()
        row.leftIcon = row:CreateTexture(nil, "ARTWORK")
        row.leftIcon:SetSize(ns.RESULT_ICON_SIZE or 18, ns.RESULT_ICON_SIZE or 18)
        row.leftIcon:SetPoint("LEFT", row, "LEFT", 10, 0)
        row.leftIcon:SetTexture(ns.COMMANDS_ICON_TEX)
        row.rightIcon = row:CreateTexture(nil, "ARTWORK")
        row.rightIcon:SetSize(ns.RESULT_ICON_SIZE or 18, ns.RESULT_ICON_SIZE or 18)
        row.rightIcon:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.rightIcon:SetTexture(MOCK_SPECIFIC_ICONS[i])


        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name._efOwnColor = true
        row.name:SetPoint("BOTTOMLEFT", row, "LEFT", 40, 0)
        row.name:SetText(L["THEME_PREVIEW_PRIMARY"])
        row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.sub._efOwnColor = true
        row.sub:SetPoint("TOPLEFT", row, "LEFT", 40, -1)
        row.sub:SetText(L["THEME_PREVIEW_SECONDARY"])
        preview.rows[i] = row
    end
end





local function BuildWindowMock(parent)
    local w = {}
    preview.window = w
    local card = CreateFrame("Frame", nil, parent)
    w.card = card
    card:SetAllPoints(preview.card)
    ns.StyleMenuPanel(card)
    card:Hide()
    local function Text(font, x, y)
        local fs = card:CreateFontString(nil, "OVERLAY", font)
        fs._efOwnColor = true
        fs:SetPoint("TOPLEFT", card, "TOPLEFT", x, y)
        fs:SetPoint("RIGHT", card, "RIGHT", -10, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        return fs
    end
    w.title = Text("GameFontNormal", 10, -8)
    w.rule = card:CreateTexture(nil, "ARTWORK")
    w.rule:SetHeight(1)
    w.rule:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -26)
    w.rule:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    w.body = Text("GameFontHighlight", 10, -34)
    w.body:SetText(L["THEME_PREVIEW_PRIMARY"])
    w.note = Text("GameFontHighlightSmall", 10, -52)
    w.note:SetText(L["THEME_PREVIEW_SECONDARY"])
    local function Pill(label, x)
        local pill = CreateFrame("Frame", nil, card)
        pill:SetSize(84, 22)
        pill:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", x, 10)
        ns.CreateRoundedRectBorder(pill)
        ns.SetRoundedRectBarHeight(pill, 10)
        ns.SetRoundedRectBorderEdgeShown(pill, false)
        pill.text = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pill.text._efOwnColor = true
        pill.text:SetPoint("LEFT", pill, "LEFT", 4, 0)
        pill.text:SetPoint("RIGHT", pill, "RIGHT", -4, 0)
        pill.text:SetWordWrap(false)
        pill.text:SetText(label)
        return pill
    end
    w.button = Pill(_G["OKAY"] or "Okay", 10)
    w.selected = Pill(L["THEME_PREVIEW_SELECTED"], 100)
    w.input = CreateFrame("Frame", nil, card)
    w.input:SetHeight(22)
    w.input:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 192, 10)
    w.input:SetPoint("RIGHT", card, "RIGHT", -10, 0)

    w.inputText = ns.CreateRingedWell(w.input, 6):CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.inputText._efOwnColor = true
    w.inputText:SetPoint("LEFT", w.input, "LEFT", 8, 0)
    w.inputText:SetPoint("RIGHT", w.input, "RIGHT", -8, 0)
    w.inputText:SetJustifyH("LEFT")
    w.inputText:SetWordWrap(false)
    w.inputText:SetText(L["THEME_PREVIEW_INPUT"])
end



function RepaintWindowMock(page)
    local w = preview.window
    if not w then return end
    w.card._efSurface = page.id
    ns.ApplyThemeFill(w.card)
    local set = ns.ThemeSet(page.id)
    local theme = set.theme
    local function Ink(fs, c, a) fs:SetTextColor(c[1], c[2], c[3], a or c[4] or 1) end
    w.title:SetText(page.label)
    Ink(w.title, theme.leafColor)
    local sep = theme.separatorColor
    w.rule:SetColorTexture(sep[1], sep[2], sep[3], sep[4] or 0.35)
    Ink(w.body, theme.leafColor)
    Ink(w.note, theme.pathColor)
    local btn, sel = set.BTN_FILL_NORMAL, set.NAV_SELECTED_FILL
    ns.SetRoundedRectFill(w.button, btn[1], btn[2], btn[3], 1, true)
    ns.SetRoundedRectFill(w.selected, sel[1], sel[2], sel[3], 1, true)
    Ink(w.button.text, set.TEXT_PRIMARY, 1)
    Ink(w.selected.text, set.TEXT_PRIMARY, 1)
    local palette = set.palette or ns.ACTIVE_UI_PALETTE or {}
    local line = palette.separator or { 0.42, 0.42, 0.42 }
    ns.PaintRingedWell(w.input, palette.borderColor or { line[1], line[2], line[3], 0.7 },
        set.EDITBOX_INSET_FILL)
    Ink(w.inputText, theme.textFaint, 1)
end




local rings, ringsUsed = {}, 0
local RING_COLOR = { 1, 0.82, 0 }

local function Ring()
    ringsUsed = ringsUsed + 1
    local ring = rings[ringsUsed]
    if ring then return ring end
    ring = CreateFrame("Frame", nil, preview.card:GetParent())
    ring:SetFrameLevel(preview.card:GetFrameLevel() + 20)
    local function Edge(p1, p2)
        local e = ring:CreateTexture(nil, "OVERLAY")
        e:SetColorTexture(RING_COLOR[1], RING_COLOR[2], RING_COLOR[3], 1)
        e:SetPoint(p1)
        e:SetPoint(p2)
        return e
    end
    Edge("TOPLEFT", "TOPRIGHT"):SetHeight(1)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT"):SetHeight(1)
    Edge("TOPLEFT", "BOTTOMLEFT"):SetWidth(1)
    Edge("TOPRIGHT", "BOTTOMRIGHT"):SetWidth(1)
    ring.pulse = ring:CreateAnimationGroup()
    ring.pulse:SetLooping("BOUNCE")
    local fade = ring.pulse:CreateAnimation("Alpha")
    fade:SetDuration(0.5)
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    rings[ringsUsed] = ring
    return ring
end


local function Outline(pad, ...)
    local left, right, top, bottom
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region and region:IsShown() then
            local l, r, t, b = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
            if l and r and t and b then
                left = left and math.min(left, l) or l
                right = right and math.max(right, r) or r
                top = top and math.max(top, t) or t
                bottom = bottom and math.min(bottom, b) or b
            end
        end
    end
    local card = preview.card
    local cl, ct = card:GetLeft(), card:GetTop()
    if not (left and cl and ct) then return end
    local ring = Ring()
    ring:ClearAllPoints()
    ring:SetPoint("TOPLEFT", card, "TOPLEFT", left - cl - pad, top - ct + pad)
    ring:SetSize(right - left + 2 * pad, top - bottom + 2 * pad)
    ring:Show()
    ring.pulse:Play()
end

local function HideSlotHighlights()
    for i = 1, ringsUsed do
        rings[i].pulse:Stop()
        rings[i]:Hide()
    end
    ringsUsed = 0
end



local function ShowSlotHighlight(slotKey)
    HideSlotHighlights()
    if not preview then return end
    if EasyFind and EasyFind.db and EasyFind.db.themeStudioHoverPreview == false then return end
    local w = preview.window
    if w and w.card:IsShown() then
        if slotKey == "windowFill" or slotKey == "windowFillBottom" or slotKey == "windowFillTop" then
            Outline(-3, w.card)
        elseif slotKey == "borderColor" then
            Outline(3, w.card, w.input)
        elseif slotKey == "leafColor" then
            Outline(2, w.title, w.body)
        elseif slotKey == "pathColor" then
            Outline(2, w.note)
        elseif slotKey == "textFaint" then
            Outline(2, w.inputText)
        elseif slotKey == "separator" then
            Outline(3, w.rule)
        elseif slotKey == "controlAccent" or slotKey == "accent" then
            Outline(2, w.button, w.selected)
        end
        return
    end
    local card = preview.card
    local rows = preview.rows
    if slotKey == "windowFill" or slotKey == "windowFillBottom"
       or slotKey == "windowFillTop" then
        Outline(-3, card)
    elseif slotKey == "borderColor" then
        Outline(3, card)
    elseif slotKey == "textFaint" then
        Outline(2, preview.placeholder)
    elseif slotKey == "separator" then
        Outline(3, preview.barLine)
    elseif slotKey == "chromeGlyph" then
        Outline(2, preview.glyph)
        Outline(2, preview.filterArrow, unpack(preview.appDots))
        Outline(2, rows[1] and rows[1].leftIcon)
    elseif slotKey == "leafColor" then
        Outline(2, rows[1] and rows[1].name)
        Outline(2, rows[2] and rows[2].name)
    elseif slotKey == "pathColor" then
        Outline(2, rows[1] and rows[1].sub)
    elseif slotKey == "pathColorHover" then
        Outline(2, rows[2] and rows[2].sub)
    elseif slotKey == "rowHover" or slotKey == "accent" then
        Outline(1, rows[2])
    end
end





local function BuildSlotGrid(parent)


    local hoverPrevCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    hoverPrevCheck:SetSize(18, 18)
    hoverPrevCheck:SetPoint("TOPLEFT", preview.card, "BOTTOMLEFT", 0, -6)
    if Utils.SetCheckboxTextures then Utils.SetCheckboxTextures(hoverPrevCheck, 15) end
    hoverPrevCheck:SetChecked(EasyFind.db.themeStudioHoverPreview ~= false)
    local hoverPrevLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hoverPrevLabel:SetPoint("LEFT", hoverPrevCheck, "RIGHT", 3, 0)
    hoverPrevLabel:SetText(L["OPT_STUDIO_HOVER_PREVIEW"])
    RegisterStudioText(hoverPrevLabel, 0.9)
    hoverPrevCheck:SetScript("OnClick", function(self)
        EasyFind.db.themeStudioHoverPreview = self:GetChecked() and true or false
        if not self:GetChecked() then HideSlotHighlights() end
    end)

    local grid = CreateFrame("Frame", nil, parent)
    grid:SetPoint("TOPLEFT", hoverPrevCheck, "BOTTOMLEFT", 0, -6)
    grid:SetPoint("RIGHT", preview.card, "RIGHT", 0, 0)
    local slots = ns.ThemeShare and ns.ThemeShare.COLOR_SLOTS or {}
    local COLS = 4
    local CELL_W, CELL_H = 93, 20


    local perCol = mceil(#slots / COLS)
    for i = 1, #slots do
        local slotKey = slots[i].key
        local cell = CreateFrame("Button", nil, grid)
        cell:SetSize(CELL_W, CELL_H)
        cell._efNoAutoRetint = true
        local col = mfloor((i - 1) / perCol)
        local rowIdx = (i - 1) % perCol
        cell:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (CELL_W + 2), -rowIdx * (CELL_H + 2))
        cell.slotKey = slotKey
        cell.optional = not slots[i].required

        cell.swatch = cell:CreateTexture(nil, "ARTWORK")
        cell.swatch:SetSize(13, 13)
        cell.swatch:SetPoint("LEFT", cell, "LEFT", 2, 0)
        cell.swatchBorder = cell:CreateTexture(nil, "BORDER")
        cell.swatchBorder:SetPoint("TOPLEFT", cell.swatch, "TOPLEFT", -1, 1)
        cell.swatchBorder:SetPoint("BOTTOMRIGHT", cell.swatch, "BOTTOMRIGHT", 1, -1)
        cell.swatchBorder:SetColorTexture(0.5, 0.5, 0.55, 0.6)

        cell.label = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cell.label._efOwnColor = true
        cell.label:SetPoint("LEFT", cell.swatch, "RIGHT", 5, 0)
        cell.label:SetPoint("RIGHT", cell, "RIGHT", -2, 0)
        cell.label:SetJustifyH("LEFT")
        cell.label:SetWordWrap(false)
        cell.label:SetText(L[SLOT_LABEL_KEYS[slotKey] or slotKey])

        cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        cell:SetScript("OnClick", function(self, button)
            if button == "RightButton" and self.optional and draft then
                TargetLook()[self.slotKey] = nil
                RefreshEditor()
                SchedulePreview()
                PushHistoryNow()
                return
            end
            OpenPickerForSlot(self.slotKey)
        end)
        cell:SetScript("OnEnter", function(self)
            ns.ShowHintTooltip(self, "ANCHOR_TOP", nil, L[SLOT_LABEL_KEYS[self.slotKey] or self.slotKey])
            ShowSlotHighlight(self.slotKey)
        end)
        cell:SetScript("OnLeave", function(self)
            ns.HideHintTooltip(self)
            HideSlotHighlights()
        end)
        local hl = cell:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.06)
        swatchRows[#swatchRows + 1] = cell
    end
    grid:SetHeight(perCol * (CELL_H + 2))
end

local function BuildStudio()
    studio = CreateFrame("Frame", "EasyFindThemeStudio", UIParent)
    studio:SetSize(WINDOW_W, WINDOW_H)
    studio:SetPoint("CENTER")
    studio:SetFrameStrata("DIALOG")
    studio:SetFrameLevel(900)
    studio:EnableMouse(true)
    studio:SetMovable(true)
    studio:SetClampedToScreen(true)
    studio:RegisterForDrag("LeftButton")
    studio:SetScript("OnDragStart", studio.StartMoving)
    studio:SetScript("OnDragStop", studio.StopMovingOrSizing)
    ns.CreateRoundedRectBorder(studio)
    ns.SetRoundedRectBarHeight(studio, 14)
    ns.ApplyThemeFill(studio)
    if ns.RegisterThemeCallback then
        ns.RegisterThemeCallback(function()
            if studio then
                ns.ApplyThemeFill(studio)
                RepaintStudioTexts()
                if studio:IsShown() then RepaintPreviewCard() end
            end
        end)
    end

    studio.title = studio:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    studio.title:SetPoint("TOPLEFT", studio, "TOPLEFT", 16, -14)
    studio.title:SetText(L["OPT_THEME_STUDIO"])
    RegisterStudioText(studio.title)

    local exp = ns.CreateFeatureTag(studio, "exp", L["TAG_EXP_TITLE"], L["THEME_STUDIO_EXP_TT"], true)
    ns.SuperscriptTag(exp, studio.title)

    local x = ns.CreateCloseX(studio, 14)
    x:SetPoint("TOPRIGHT", -10, -10)
    x:SetScript("OnClick", function() studio:Hide() end)
    ns.AttachEscClose(studio)





    local MID_LEFT = LIST_W + PANEL_PAD
    local MID_RIGHT = CONTROLS_W + PANEL_PAD
    local undoAtlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("common-icon-undo")
    local function HistoryButton(name, mirrored, tip, onClick)
        local btn = CreateFrame("Button", name, studio)
        btn:SetSize(20, 20)
        btn.icon = btn:CreateTexture(nil, "OVERLAY")
        btn.icon:SetSize(16, 16)
        btn.icon:SetPoint("CENTER")

        if undoAtlas then
            btn.icon:SetTexture(undoAtlas.file)
            local l, r = undoAtlas.leftTexCoord, undoAtlas.rightTexCoord
            if mirrored then l, r = r, l end
            btn.icon:SetTexCoord(l, r, undoAtlas.topTexCoord, undoAtlas.bottomTexCoord)
        end
        btn:SetScript("OnClick", onClick)
        btn:SetScript("OnEnter", function(self) ns.ShowHintTooltip(self, "ANCHOR_TOP", nil, tip) end)
        btn:SetScript("OnLeave", function(self) ns.HideHintTooltip(self) end)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        return btn
    end
    undoBtn = HistoryButton("EasyFindStudioUndoBtn", false, L["OPT_STUDIO_UNDO"], DoUndo)
    undoBtn:SetPoint("TOPLEFT", studio, "TOPLEFT", MID_LEFT, -48)
    redoBtn = HistoryButton("EasyFindStudioRedoBtn", true, L["OPT_STUDIO_REDO"], DoRedo)
    redoBtn:SetPoint("LEFT", undoBtn, "RIGHT", 2, 0)

    local resetBtn = ns.CreateModernButton(studio, _G["RESET"] or "Reset", 56, 20)
    resetBtn:SetPoint("LEFT", redoBtn, "RIGHT", 8, 0)
    resetBtn:SetScript("OnClick", function()

        if draft and draft.baseName then LoadBase(draft.baseName) end
    end)



    local function PageArrow(step, rotation, tip)
        local btn = CreateFrame("Button", nil, studio)
        btn:SetSize(18, 18)
        btn.arrow = btn:CreateTexture(nil, "OVERLAY")
        btn.arrow:SetSize(12, 12)
        btn.arrow:SetPoint("CENTER")
        Utils.SetChevronTexture(btn.arrow)
        btn.arrow:SetRotation(rotation)
        btn:SetScript("OnClick", function()
            local n = #Pages()
            pageIndex = (pageIndex - 1 + step) % n + 1
            HideSlotHighlights()
            RefreshEditor()
        end)
        btn:SetScript("OnEnter", function(self) ns.ShowHintTooltip(self, "ANCHOR_TOP", nil, tip) end)
        btn:SetScript("OnLeave", function(self) ns.HideHintTooltip(self) end)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        return btn
    end
    pageUI.next = PageArrow(1, Utils.mpi / 2, L["OPT_STUDIO_NEXT_PAGE"])
    pageUI.next:SetPoint("TOPRIGHT", studio, "TOPRIGHT", -MID_RIGHT - 2, -49)
    pageUI.menu = Dropdown(studio, "EasyFindStudioPagePopup", 120, function()
        local defs = {}
        for i, page in ipairs(Pages()) do
            defs[i] = { kind = "radio", label = page.label, value = i,
                get = function() return pageIndex end,
                set = function(v)
                    pageIndex = v
                    HideSlotHighlights()
                    RefreshEditor()
                end }
        end
        return defs
    end)
    pageUI.menu:SetPoint("RIGHT", pageUI.next, "LEFT", -4, 0)
    pageUI.prev = PageArrow(-1, -Utils.mpi / 2, L["OPT_STUDIO_PREV_PAGE"])
    pageUI.prev:SetPoint("RIGHT", pageUI.menu, "LEFT", -4, 0)



    pageUI.check = CreateFrame("CheckButton", nil, studio, "UICheckButtonTemplate")
    pageUI.check:SetSize(18, 18)
    pageUI.check:SetPoint("TOPLEFT", studio, "TOPLEFT", MID_LEFT - 2, -71)
    if Utils.SetCheckboxTextures then Utils.SetCheckboxTextures(pageUI.check, 15) end
    local ownLabel = pageUI.check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ownLabel:SetPoint("LEFT", pageUI.check, "RIGHT", 3, 0)
    ownLabel:SetText(L["OPT_STUDIO_OWN_LOOK"])
    RegisterStudioText(ownLabel)
    pageUI.check:SetScript("OnClick", function(self)
        local id = CurrentPage().id
        if not (draft and id) then return end
        local surfaces = draft.palette.surfaces
        if self:GetChecked() then

            local own = {}
            CopyPaletteInto(own, draft.palette)
            own.surfaces = nil
            draft.palette.surfaces = surfaces or {}
            draft.palette.surfaces[id] = own
        elseif surfaces then
            surfaces[id] = nil
            if next(surfaces) == nil then draft.palette.surfaces = nil end
        end
        RefreshEditor()
        SchedulePreview()
        PushHistoryNow()
    end)
    pageUI.check:SetScript("OnEnter", function(self)
        ns.ShowHintTooltip(self, "ANCHOR_TOP", L["OPT_STUDIO_OWN_LOOK"], L["OPT_STUDIO_OWN_LOOK_TT"])
    end)
    pageUI.check:SetScript("OnLeave", function(self) ns.HideHintTooltip(self) end)

    local bindsArmed = false
    local bindRegenWatcher
    local function ArmStudioBinds()
        if bindsArmed or InCombatLockdown() then return end
        bindsArmed = true
        SetOverrideBindingClick(studio, false, "CTRL-Z", "EasyFindStudioUndoBtn")
        SetOverrideBindingClick(studio, false, "CTRL-Y", "EasyFindStudioRedoBtn")
        SetOverrideBindingClick(studio, false, "CTRL-SHIFT-Z", "EasyFindStudioRedoBtn")
    end
    local function DisarmStudioBinds()
        if not bindsArmed then return end
        if InCombatLockdown() then
            if not bindRegenWatcher then
                bindRegenWatcher = CreateFrame("Frame")
                bindRegenWatcher:SetScript("OnEvent", function(self)
                    self:UnregisterAllEvents()
                    if not (studio and studio:IsShown()) then
                        bindsArmed = false
                        ClearOverrideBindings(studio)
                    end
                end)
            end
            bindRegenWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        bindsArmed = false
        ClearOverrideBindings(studio)
    end
    studio:HookScript("OnShow", ArmStudioBinds)
    studio:HookScript("OnHide", DisarmStudioBinds)


    studio.listPane = CreateFrame("Frame", nil, studio)
    studio.listPane:SetPoint("TOPLEFT", studio, "TOPLEFT", 10, -40)
    studio.listPane:SetPoint("BOTTOMLEFT", studio, "BOTTOMLEFT", 10, 12)
    studio.listPane:SetWidth(LIST_W - 10)
    local listHeader = studio.listPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listHeader:SetPoint("TOPLEFT", studio.listPane, "TOPLEFT", 4, -6)
    listHeader:SetText(L["THEME_STUDIO_YOURS"])
    RegisterStudioText(listHeader, 0.85)


    local baseBtn = ns.CreateModernButton(studio.listPane, L["THEME_STUDIO_START_FROM"], LIST_W - 18, 20)
    baseBtn:SetPoint("TOPLEFT", studio.listPane, "TOPLEFT", 4, -26)
    baseBtn:SetScript("OnClick", function(self)
        local defs = {}
        for _, name in ipairs(BuiltinBases()) do
            defs[#defs + 1] = { kind = "action", label = name, onClick = function() LoadBase(name) end }
        end
        if #defs > 0 then ns.ShowTogglePopup("EasyFindStudioBasePopup", self, defs) end
    end)
    studio.baseBtn = baseBtn
    studio.noThemes = studio.listPane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    studio.noThemes:SetPoint("TOPLEFT", studio.listPane, "TOPLEFT", 8, -58)
    studio.noThemes:SetPoint("RIGHT", studio.listPane, "RIGHT", -6, 0)
    studio.noThemes:SetJustifyH("LEFT")
    studio.noThemes:SetWordWrap(true)
    studio.noThemes:SetText(L["THEME_STUDIO_NONE_YET"])



    studio._efThemeSeps = {}
    local sepOffsets = { LIST_W + 1, WINDOW_W - CONTROLS_W - PANEL_PAD / 2 }
    for i = 1, #sepOffsets do
        local line = studio:CreateTexture(nil, "ARTWORK")
        line:SetWidth(1)
        line:SetPoint("TOPLEFT", studio, "TOPLEFT", sepOffsets[i], -40)
        line:SetPoint("BOTTOMLEFT", studio, "BOTTOMLEFT", sepOffsets[i], 12)
        studio._efThemeSeps[#studio._efThemeSeps + 1] = line
    end
    ns.RetintMenuSeparators(studio)

    BuildPreviewCard(studio)
    BuildWindowMock(studio)
    BuildSlotGrid(studio)


    local controls = CreateFrame("Frame", nil, studio)
    studio.controls = controls
    controls:SetPoint("TOPRIGHT", studio, "TOPRIGHT", -12, -40)
    controls:SetPoint("BOTTOMRIGHT", studio, "BOTTOMRIGHT", -12, 12)
    controls:SetWidth(CONTROLS_W - 12)

    local nameLabel = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", 2, -4)
    nameLabel:SetText(L["OPT_STUDIO_NAME"])
    RegisterStudioText(nameLabel, 0.85)

    local nameShell = CreateFrame("Frame", nil, controls)
    nameShell:SetHeight(22)
    nameShell:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
    nameShell:SetPoint("RIGHT", controls, "RIGHT", -2, 0)
    ns.CreateRoundedRectBorder(nameShell)
    ns.SetRoundedRectBarHeight(nameShell, 8)
    ns.SetRoundedRectBorderShown(nameShell, false)
    local inset = ns.EDITBOX_INSET_FILL or { 0.02, 0.02, 0.03 }
    ns.SetRoundedRectFill(nameShell, inset[1], inset[2], inset[3], 1, true)

    nameBox = CreateFrame("EditBox", nil, nameShell)
    Utils.ReleaseFocusOnOutsideClick(nameBox)
    nameBox:SetPoint("TOPLEFT", nameShell, "TOPLEFT", 8, 0)
    nameBox:SetPoint("BOTTOMRIGHT", nameShell, "BOTTOMRIGHT", -8, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(NAME_MAX)
    nameBox:SetFontObject(GameFontHighlightSmall)
    RegisterStudioText(nameBox)
    nameBox:SetScript("OnTextChanged", function(self)
        if draft then
            draft.name = self:GetText() or ""
            ScheduleHistoryPush()
        end
    end)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)



    local iconVisLabel = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iconVisLabel:SetPoint("TOPLEFT", nameShell, "BOTTOMLEFT", 0, -10)
    iconVisLabel:SetText(L["OPT_ICON_VISIBILITY"])
    RegisterStudioText(iconVisLabel, 0.85)
    iconModeMenu = Dropdown(controls, "EasyFindStudioIconPopup", CONTROLS_W - 16, function()
        local defs = {}
        for i, mode in ipairs(ICON_MODES) do
            defs[i] = { kind = "radio", label = mode.label, value = mode.value,
                get = function() return EasyFind.db.iconVisibility or "all" end,
                set = function(v)
                    EasyFind.db.iconVisibility = v
                    RefreshIconModeButtons()
                    RepaintPreviewCard()
                    if ns.Search and ns.Search.RefreshResults then ns.Search:RefreshResults() end
                end }
        end
        return defs
    end)
    iconModeMenu:SetPoint("TOPLEFT", iconVisLabel, "BOTTOMLEFT", 0, -4)
    iconModeMenu:HookScript("OnEnter", function(self)
        ns.ShowHintTooltip(self, "ANCHOR_TOP", L["OPT_ICON_VISIBILITY"], L["OPT_ICON_VISIBILITY_TT"])
    end)
    iconModeMenu:HookScript("OnLeave", function(self) ns.HideHintTooltip(self) end)


    borderCheck = CreateFrame("CheckButton", nil, controls, "UICheckButtonTemplate")
    borderCheck:SetSize(20, 20)
    borderCheck:SetPoint("TOPLEFT", iconModeMenu, "BOTTOMLEFT", -2, -8)
    if Utils.SetCheckboxTextures then Utils.SetCheckboxTextures(borderCheck, 16) end
    local borderLabel = borderCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    borderLabel:SetPoint("LEFT", borderCheck, "RIGHT", 4, 0)
    borderLabel:SetText(L["OPT_WINDOW_BORDER"])
    RegisterStudioText(borderLabel)
    borderCheck:SetScript("OnClick", function(self)
        if not draft then return end
        draft.palette.borderHidden = (not self:GetChecked()) and true or nil
        SchedulePreview()
        PushHistoryNow()
    end)
    borderCheck:SetScript("OnEnter", function(self)
        ns.ShowHintTooltip(self, "ANCHOR_TOP", L["OPT_WINDOW_BORDER"], L["OPT_WINDOW_BORDER_TT"])
    end)
    borderCheck:SetScript("OnLeave", function(self) ns.HideHintTooltip(self) end)

    local saveBtn = ns.CreateModernButton(controls, _G["SAVE"] or "Save", 64, 22)
    saveBtn:SetPoint("BOTTOMLEFT", controls, "BOTTOMLEFT", 0, 2)
    saveBtn:SetScript("OnClick", function() xpcall(DoSave, ErrorHandler) end)

    local exportBtn = ns.CreateModernButton(controls, L["SHORTKEY_EXPORT"], 64, 22)
    exportBtn:SetPoint("LEFT", saveBtn, "RIGHT", 6, 0)
    exportBtn:SetScript("OnClick", function() xpcall(DoExport, ErrorHandler) end)

    deleteBtn = ns.CreateModernButton(controls, _G["DELETE"] or "Delete", 64, 22)
    deleteBtn:SetPoint("LEFT", exportBtn, "RIGHT", 6, 0)
    deleteBtn:SetScript("OnClick", function() xpcall(DoDelete, ErrorHandler) end)




    studio:HookScript("OnHide", ClearPreview)
    studio:Hide()
end

function ThemeStudio:Open()
    local store = DraftStore()
    if not store then return end
    draft = store
    if not studio then BuildStudio() end
    if not DraftValid() then



        local active = EasyFind.db.uiTheme
            or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.uiTheme) or "Black"
        local activePal = ns.UI_THEME_PALETTES and ns.UI_THEME_PALETTES[active]
        if activePal and activePal.fillTexture then
            active = "Black"
            activePal = ns.UI_THEME_PALETTES and ns.UI_THEME_PALETTES[active]
        end
        CopyPaletteInto(draft.palette, activePal)
        draft.name = draft.name ~= "" and draft.name or active
        draft.baseName = active
    end

    local label = pageUI.menu._label
    local measure = label.GetUnboundedStringWidth or label.GetStringWidth
    local widest = 0
    for _, page in ipairs(Pages()) do
        label:SetText(page.label)
        widest = math.max(widest, measure(label) or 0)
    end
    pageUI.menu:SetWidth(mceil(widest) + 30)
    studio:Show()
    if studio.Raise then studio:Raise() end
    RefreshEditor()
    SchedulePreview()

    wipe(history)
    historyIndex = 0
    PushHistoryNow()
end

function ThemeStudio:Toggle()
    if studio and studio:IsShown() then studio:Hide() else self:Open() end
end

return ThemeStudio
