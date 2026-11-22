local _, ns = ...





















local Utils = ns.Utils
local L = ns.L
local Results = ns.Results

local CreateFrame = CreateFrame
local UIParent = UIParent
local Minimap = Minimap
local GetCursorPosition = GetCursorPosition
local GameTooltip = GameTooltip
local GameTooltip_Hide = GameTooltip_Hide
local IsMouseButtonDown = IsMouseButtonDown
local mfloor, mmax, mmin, msqrt = math.floor, math.max, math.min, math.sqrt
local mdeg, matan2 = math.deg, math.atan2
local tremove, tinsert = table.remove, table.insert

local ExtensionButtons = {}
ns.ExtensionButtons = ExtensionButtons

local BASE_SIZE = 34
local MIN_SCALE, MAX_SCALE = 0.6, 2.0
local SNAP_RANGE = 60
local DRAG_START = 5
local MENU_ROW_H = 24
local MENU_PAD = 6
local MENU_ICON = 16
local MENU_W = 120
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local GLOW_TEX = "Interface\\AddOns\\EasyFind\\textures\\filter-glow"
local TRASH_TEX = "Interface\\AddOns\\EasyFind\\textures\\trash-icon"
local TRASH_SIZE = 44
local BRAND = "EasyFind"

local RING_R, RING_G, RING_B = 0.42, 0.42, 0.42
local CLASSIC_TREE_ART = "Interface\\TalentFrame\\"
local CLASSIC_MARBLE = "Interface\\FrameGeneral\\UI-Background-Marble"
local CLASSIC_STONE = { 0.62, 0.61, 0.60 }




local MICRO_W, MICRO_H = 32, 40
local MICRO_BG_UP = "UI-HUD-MicroMenu-ButtonBG-Up"
local MICRO_BG_DOWN = "UI-HUD-MicroMenu-ButtonBG-Down"
local MICRO_HOVER = "UI-HUD-MicroMenu-Highlightalert"
local MICRO_ICON = 18
local MICRO_DROP_MARGIN = 12

local buttons = {}
local dragGhost
local folderMenu



local function Store()
    if not (EasyFind and EasyFind.db) then return nil end
    EasyFind.db.extensionButtons = EasyFind.db.extensionButtons or {}
    return EasyFind.db.extensionButtons
end

local function SnapOn(rec) return rec.snap ~= false end




local hiddenApps = {}
local function AppHidden(rec)
    return rec and not rec.micro and #rec.apps == 1 and hiddenApps[rec.apps[1]] == true
end









local function BorderGroup(rec)
    return (rec and rec.angle) and "minimap" or "free"
end

local function BorderGroups()
    local db = EasyFind and EasyFind.db
    if not db then return {} end
    db.extensionButtonBorders = db.extensionButtonBorders or {}
    return db.extensionButtonBorders
end

local function BorderStyle(rec)
    local group = BorderGroup(rec)
    local s = BorderGroups()[group]
    if s == "easyfind" or s == "minimap" or s == "none" then return s end
    if group == "minimap" then return "minimap" end
    local db = EasyFind and EasyFind.db
    return (db and db.windowBorder == false) and "none" or "easyfind"
end



local function AppEntry(id)
    return ns.FindApplicationEntry and ns.FindApplicationEntry(id) or nil
end

local function AppIcon(app)
    local def = ns.ResultIcons and (ns.ResultIcons:GetAppGlyphIcon(app)
        or ns.ResultIcons:GetFlatCategoryIcon(app))
    return (def and def.tex) or app.icon, def and def.coords
end

local function ShortkeyText(app)
    local Shortkeys = ns.Shortkeys
    if not (Shortkeys and app) then return nil end
    if app.quicklistID and ns.Quicklists then return ns.Quicklists:KeyOf(app.quicklistID) end
    local rowKey = Shortkeys:GetEntryKey(app)
    local info = rowKey and Shortkeys:Get(rowKey)
    return info and info.key or nil
end



local function LaunchApp(app)
    if not app then return end
    if ns.ToggleApplication then
        ns.ToggleApplication(app)
        return
    end
    if Results and Results.HideResults then Results:HideResults() end
    if ns.ResultHandlers and ns.ResultHandlers.SelectResult then
        ns.ResultHandlers:SelectResult(app)
    end
end







local virtualMouse
function ExtensionButtons:SetVirtualMouse(x, y, down)
    virtualMouse = { x = x, y = y, down = down and true or false }
end
function ExtensionButtons:ClearVirtualMouse()
    virtualMouse = nil
end

local function CursorUI()
    if virtualMouse then return virtualMouse.x, virtualMouse.y end
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
end

local function LeftDown()
    if virtualMouse then return virtualMouse.down end
    return IsMouseButtonDown("LeftButton")
end

local function Moved(press, threshold)
    local x, y = CursorUI()
    return (x - press.x) ^ 2 + (y - press.y) ^ 2 >= threshold * threshold
end

local function NearMinimap(x, y)
    if not Minimap or not Minimap:IsShown() then return nil end
    local mx, my = Minimap:GetCenter()
    if not mx then return nil end
    local k = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
    mx, my = mx * k, my * k
    local r = (Minimap:GetWidth() / 2) * k
    local d = msqrt((x - mx) ^ 2 + (y - my) ^ 2)
    if d > r + SNAP_RANGE then return nil end
    return mdeg(matan2(y - my, x - mx))
end

local function Place(btn)
    local rec = btn.rec


    local scale = rec.angle and 1 or (rec.scale or 1)
    btn:ClearAllPoints()
    btn:SetScale(scale)
    if rec.angle and ns.MinimapEdgeOffset and Minimap then
        local x, y = ns.MinimapEdgeOffset(rec.angle)
        local k = Minimap:GetEffectiveScale() / btn:GetEffectiveScale()
        btn:SetPoint("CENTER", Minimap, "CENTER", x * k, y * k)
    else
        btn:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (rec.x or 400) / scale, (rec.y or 400) / scale)
    end
end

local function ButtonUnder(x, y, except)
    for i = 1, #buttons do
        local b = buttons[i]
        if b and b ~= except and b:IsShown() then
            local k = b:GetEffectiveScale() / UIParent:GetEffectiveScale()
            local cx, cy = b:GetCenter()
            if cx then
                cx, cy = cx * k, cy * k
                local r = (b:GetWidth() / 2) * k + 6
                if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r then return b end
            end
        end
    end
    return nil
end



local foldTarget
local function ShowFoldTarget(over)
    if not over then
        if foldTarget then foldTarget:Hide() end
        return
    end
    if not foldTarget then
        foldTarget = CreateFrame("Frame", nil, UIParent)
        foldTarget:Hide()
        local t = foldTarget:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints()
        t:SetColorTexture(1, 0.82, 0, 0.35)
        local mask = foldTarget:CreateMaskTexture()
        mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(t)
        t:AddMaskTexture(mask)
    end
    foldTarget:SetParent(over)
    foldTarget:ClearAllPoints()
    foldTarget:SetPoint("CENTER", over, "CENTER")
    local d = over.disc and over.disc:IsShown() and over.disc:GetWidth() or over:GetWidth()
    foldTarget:SetSize(d, d)
    foldTarget:SetFrameLevel(over:GetFrameLevel() + 5)
    foldTarget:Show()
end












local function MicroBar()
    local bar = _G.MicroMenu
    if bar and bar.MarkDirty and bar.numButtons then return bar end
    return nil
end



local function MicroChildren(except)
    local bar = MicroBar()
    local list = {}
    if not bar then return list end
    for _, child in ipairs({ bar:GetChildren() }) do
        if child ~= except and child.layoutIndex then list[#list + 1] = child end
    end
    table.sort(list, function(a, b) return a.layoutIndex < b.layoutIndex end)
    return list
end

local function MicroRelayout(bar)
    bar.stride = bar.isStacked and mfloor(bar.numButtons / 2) or bar.numButtons
    bar:MarkDirty()
    local container = _G.MicroMenuContainer
    if container and container.Layout then pcall(container.Layout, container) end
end




local function MicroInsert(frame, k)
    local bar = MicroBar()
    if not bar then return nil end
    local list = MicroChildren(frame)
    k = mmax(1, mmin(#list + 1, k or (#list + 1)))



    if frame:GetParent() == bar and frame.layoutIndex == k then return k end
    tinsert(list, k, frame)
    for i = 1, #list do list[i].layoutIndex = i end
    if frame:GetParent() ~= bar then
        frame:SetParent(bar)
        local peer = _G.CharacterMicroButton
        if peer and peer.GetFrameLevel then frame:SetFrameLevel(peer:GetFrameLevel()) end
    end




    frame:SetClampedToScreen(false)
    frame:SetScale(1)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.numButtons = #list
    MicroRelayout(bar)
    return k
end

local function MicroRemove(frame)
    local bar = MicroBar()
    if not (bar and frame.layoutIndex) then return end
    local list = MicroChildren(frame)
    for i = 1, #list do list[i].layoutIndex = i end
    frame.layoutIndex = nil
    frame:SetParent(UIParent)
    bar.numButtons = #list
    MicroRelayout(bar)
end





local function MicroSlotAt(x, y, except)
    local bar = MicroBar()
    if not (bar and bar:IsShown()) then return nil end
    local k = bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local l, r, t, b = bar:GetLeft(), bar:GetRight(), bar:GetTop(), bar:GetBottom()
    if not l then return nil end
    l, r, t, b = l * k, r * k, t * k, b * k
    local m = MICRO_DROP_MARGIN
    if x < l - m or x > r + m or y < b - m or y > t + m then return nil end
    local list = MicroChildren(except)
    local horizontal = bar.isHorizontal ~= false
    local function Pos(c)
        local cx, cy = c:GetCenter()
        if not cx then return nil end
        local s = c:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return horizontal and cx * s or -cy * s
    end
    local shown = {}
    for i = 1, #list do
        if list[i]:IsShown() and Pos(list[i]) then shown[#shown + 1] = list[i] end
    end
    table.sort(shown, function(a, c) return Pos(a) < Pos(c) end)
    local cursor = horizontal and x or -y
    local before, after
    for i = 1, #shown do
        if Pos(shown[i]) < cursor then before = shown[i] else after = after or shown[i] end
    end
    local reversed = (horizontal and bar.layoutFramesGoingRight == false)
        or (not horizontal and bar.layoutFramesGoingUp == true)
    local anchor = reversed and after or before
    if not anchor then return 1 end
    for i = 1, #list do
        if list[i] == anchor then return i + 1 end
    end
    return 1
end







local function BuildDisc(frame)
    local function Circle(layer, size)
        local t = frame:CreateTexture(nil, layer)
        t:SetSize(size, size)
        t:SetPoint("CENTER")
        t:SetColorTexture(1, 1, 1, 1)
        local mask = frame:CreateMaskTexture()
        mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(t)
        t:AddMaskTexture(mask)
        return t
    end
    frame.ringLine = Circle("BACKGROUND", BASE_SIZE - 4)
    frame.disc = Circle("BORDER", BASE_SIZE - 6)
    local ring = frame:CreateTexture(nil, "OVERLAY")
    ring:SetSize(BASE_SIZE * 50 / 31, BASE_SIZE * 50 / 31)
    ring:SetTexture(136430)
    ring:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    ring:Hide()
    frame.ring = ring
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(16, 16)
    frame.icon:SetPoint("CENTER")
end

local function PaintDisc(frame, rec)
    frame._efBorderGroup = BorderGroup(rec)
    local palette = ns.ACTIVE_UI_PALETTE
    local classic = palette and palette.chrome == "classic"
    local disc = frame.disc
    if classic then


        local db = EasyFind and EasyFind.db
        local tree = db and db.classicArt
        if tree and tree ~= "marble" then
            disc:SetTexture(CLASSIC_TREE_ART .. tree .. "-TopLeft")
            disc:SetTexCoord(0.3, 0.8, 0.35, 0.85)
        else
            disc:SetTexture(CLASSIC_MARBLE, "REPEAT", "REPEAT")
            disc:SetTexCoord(0, 0.15, 0, 0.15)
        end
        disc:SetVertexColor(1, 1, 1, 1)
    else
        local fill = (palette and palette.windowFill) or ns.SEARCH_WINDOW_FILL_COLOR or { 0.05, 0.05, 0.06 }
        disc:SetColorTexture(1, 1, 1, 1)
        disc:SetTexCoord(0, 1, 0, 1)
        disc:SetVertexColor(fill[1], fill[2], fill[3], 1)
    end
    local style = BorderStyle(rec)



    local line = (palette and (palette.borderColor or (classic and CLASSIC_STONE) or palette.backdropBorder))
        or { RING_R, RING_G, RING_B }
    frame.ringLine:SetVertexColor(line[1], line[2], line[3], 1)
    frame.ringLine:SetShown(style == "easyfind")
    frame.ring:SetShown(style == "minimap")


    local cuif = style == "minimap" and _G["ClassicUIForeverAPI"]
    if cuif and cuif.ThemeMinimapButton then cuif.ThemeMinimapButton(frame) end



    local k = BASE_SIZE / 31
    local discSize = style == "minimap" and 24 * k or BASE_SIZE - 6
    frame.disc:ClearAllPoints()
    frame.disc:SetPoint("CENTER")
    frame.disc:SetSize(discSize, discSize)
    frame.icon:ClearAllPoints()
    frame.icon:SetPoint("CENTER")
    if frame.SetHighlightTexture then
        if style == "minimap" then
            frame:SetHighlightTexture(136477)
        else
            frame:SetHighlightTexture(GLOW_TEX)
            local hl = frame:GetHighlightTexture()
            hl:ClearAllPoints()
            hl:SetSize(BASE_SIZE + 6, BASE_SIZE + 6)
            hl:SetPoint("CENTER")
            hl:SetBlendMode("ADD")
            hl:SetAlpha(0.6)
        end
    end
end



local function SetBorderStyle(group, style)
    BorderGroups()[group] = style
    for i = 1, #buttons do
        local b = buttons[i]
        if b and b.rec and not b.rec.micro and BorderGroup(b.rec) == group then
            PaintDisc(b, b.rec)
        end
    end
end

local function PaintIcon(btn)
    local rec = btn.rec
    local apps = rec.apps
    local tex, coords
    if #apps == 1 then
        local app = AppEntry(apps[1])
        if app then tex, coords = AppIcon(app) end
    end
    if not tex then tex = ns.EXTENSIONS_ICON_TEX end
    btn.icon:SetTexture(tex)
    if coords then btn.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else btn.icon:SetTexCoord(0, 1, 0, 1) end
    btn.icon:SetDesaturated(true)
    if rec.micro then

        btn.icon:SetVertexColor(1, 1, 1, 1)
        return
    end
    local gc = ns.ChromeGlyphColor and ns.ChromeGlyphColor() or { 1, 1, 1 }
    btn.icon:SetVertexColor(gc[1], gc[2], gc[3], 1)
    PaintDisc(btn, rec)
end


local function BuildMicroArt(btn)
    if btn.micro then return btn.micro end
    local m = {}
    m.bg = btn:CreateTexture(nil, "BACKGROUND")
    m.bg:SetAtlas(MICRO_BG_UP, true)
    m.bg:SetPoint("CENTER")
    m.bgDown = btn:CreateTexture(nil, "BACKGROUND")
    m.bgDown:SetAtlas(MICRO_BG_DOWN, true)
    m.bgDown:SetPoint("CENTER")
    btn.micro = m
    return m
end

local function MicroOpen(btn)
    local apps = btn.rec.apps
    if #apps ~= 1 then return false end
    local app = AppEntry(apps[1])
    return app ~= nil and ns.IsApplicationOpen ~= nil and ns.IsApplicationOpen(app) or false
end



local function PaintMicroState(btn)
    local m = btn.micro
    if not (m and btn.rec.micro) then return end
    local open = MicroOpen(btn)
    m.bg:SetShown(not open)
    m.bgDown:SetShown(open)
    btn.icon:ClearAllPoints()
    btn.icon:SetPoint("CENTER", btn, "CENTER", open and 1 or 0, open and -2 or 0)
end

local function RefreshMicroStates()
    for i = 1, #buttons do
        local b = buttons[i]
        if b and b.rec and b.rec.micro then PaintMicroState(b) end
    end
end




local microHooks = {}
function ExtensionButtons:RefreshOpenStates() Utils.SafeAfter(0, RefreshMicroStates) end
local function EnsureMicroStateHooks()
    local function Later() Utils.SafeAfter(0, RefreshMicroStates) end
    if not microHooks.core then
        microHooks.core = true
        if Results and Results.HideResults then Utils.PostHook(Results, "HideResults", Later) end
        if ns.Search and ns.Search.Hide then Utils.PostHook(ns.Search, "Hide", Later) end
    end
    local opts = ns.optionsFrame
    if opts and not microHooks[opts] then
        microHooks[opts] = true
        opts:HookScript("OnShow", Later)
        opts:HookScript("OnHide", Later)
    end
end



local function GhostMicroLook(g, on)
    if on then
        g.ringLine:Hide()
        g.disc:Hide()
        g.ring:Hide()
        local m = BuildMicroArt(g)
        m.bg:Show()
        g:SetSize(MICRO_W, MICRO_H)
        g.icon:SetSize(MICRO_ICON, MICRO_ICON)
        g.icon:ClearAllPoints()
        g.icon:SetPoint("CENTER")
        g.icon:SetVertexColor(1, 1, 1, 1)
        g.icon:SetAlpha(1)
    else
        if g.micro then
            g.micro.bg:Hide()
            g.micro.bgDown:Hide()
        end
        g:SetFrameStrata("TOOLTIP")
        g:SetSize(BASE_SIZE, BASE_SIZE)
        g.icon:SetSize(16, 16)
        g.disc:Show()
        PaintDisc(g, nil)
        local gc = ns.ChromeGlyphColor and ns.ChromeGlyphColor() or { 1, 1, 1 }
        g.icon:SetVertexColor(gc[1], gc[2], gc[3], 1)
    end
end

local function ShowMicroArt(btn, shown)
    local m = BuildMicroArt(btn)
    m.bg:SetShown(shown)
    if not shown then m.bgDown:Hide() end
end



local function ApplyMode(btn)
    local rec = btn.rec
    if rec.micro and not MicroBar() then rec.micro = nil end
    if rec.micro then
        btn.ringLine:Hide()
        btn.disc:Hide()
        btn.ring:Hide()
        btn.grabber:Hide()
        ShowMicroArt(btn, true)
        btn:SetSize(MICRO_W, MICRO_H)
        btn.icon:SetSize(MICRO_ICON, MICRO_ICON)
        btn:SetHighlightAtlas(MICRO_HOVER)
        local hl = btn:GetHighlightTexture()
        hl:ClearAllPoints()
        hl:SetAllPoints(btn)
        hl:SetBlendMode("BLEND")
        hl:SetAlpha(0.5)
        PaintIcon(btn)
        rec.micro = MicroInsert(btn, rec.micro) or rec.micro
        PaintMicroState(btn)
        EnsureMicroStateHooks()
    else
        if btn.layoutIndex then MicroRemove(btn) end
        if btn.micro then ShowMicroArt(btn, false) end
        btn:SetParent(UIParent)

        btn:SetFrameStrata("HIGH")
        btn:SetFrameLevel(8)
        btn:SetClampedToScreen(true)
        btn:SetSize(BASE_SIZE, BASE_SIZE)
        btn.icon:SetSize(16, 16)
        btn.icon:ClearAllPoints()
        btn.icon:SetPoint("CENTER")
        btn.disc:Show()
        PaintIcon(btn)
        Place(btn)
    end
end

local function Title(btn)
    local apps = btn.rec.apps
    local name
    if #apps == 1 then
        local app = AppEntry(apps[1])
        name = app and app.name or "?"
    else
        name = L["FILTER_EXTENSIONS"]
    end
    return BRAND .. ": " .. name
end

local function ShowTooltip(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
    GameTooltip:SetText(Title(btn))
    local apps = btn.rec.apps
    if #apps == 1 then
        local app = AppEntry(apps[1])
        local desc = ns.ApplicationDescription and ns.ApplicationDescription(app)
        if desc then GameTooltip:AddLine(desc, 1, 1, 1, true) end
        local key = ShortkeyText(app)
        if key then GameTooltip:AddLine((L["SHORTKEY_FOR"]):format(key), 0.7, 0.7, 0.7) end
    else
        for i = 1, #apps do
            local app = AppEntry(apps[i])
            if app then
                local key = ShortkeyText(app)
                if key then GameTooltip:AddDoubleLine(app.name, key, 1, 1, 1, 0.7, 0.7, 0.7)
                else GameTooltip:AddLine(app.name, 1, 1, 1) end
            end
        end
    end
    GameTooltip:AddLine(L["EXTBTN_TT_HINT"], 0.7, 0.7, 0.7)
    if not btn.rec.locked then GameTooltip:AddLine(L["MINIMAP_TT_DRAG"], 0.7, 0.7, 0.7) end
    GameTooltip:Show()
end








local trashTarget

local function EnsureTrashTarget()
    if trashTarget then return trashTarget end
    local t = CreateFrame("Frame", "EasyFindExtensionTrash", UIParent)
    t:SetSize(TRASH_SIZE, TRASH_SIZE)
    t:SetPoint("TOP", UIParent, "TOP", 0, -70)
    t:SetFrameStrata("HIGH")
    t:EnableMouse(false)
    BuildDisc(t)
    t.icon:SetSize(22, 22)
    t.icon:SetTexture(TRASH_TEX)
    t.icon:SetTexCoord(0, 1, 0, 1)
    t.glow = t:CreateTexture(nil, "OVERLAY")
    t.glow:SetTexture(GLOW_TEX)
    t.glow:SetSize(TRASH_SIZE + 10, TRASH_SIZE + 10)
    t.glow:SetPoint("CENTER")
    t.glow:SetBlendMode("ADD")
    t.glow:SetAlpha(0)
    t.label = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.label:SetPoint("TOP", t, "BOTTOM", 0, -4)
    t.label:SetText(L["EXTBTN_TRASH"])
    t:Hide()
    trashTarget = t
    return t
end

local function PaintTrash(over)
    local t = trashTarget
    if not t then return end
    t.glow:SetAlpha(over and 0.7 or 0)
    if over then
        t.icon:SetVertexColor(1, 0.35, 0.35, 1)
    else
        t.icon:SetVertexColor(0.85, 0.85, 0.85, 1)
    end
    t.icon:SetDesaturated(not over)
end

local function ShowTrash(show)
    local t = EnsureTrashTarget()
    if show then
        PaintDisc(t, nil)
        t.ringLine:Show()
        t.ring:Hide()
        PaintTrash(false)
    end
    t:SetShown(show)
end

local function OverTrash(x, y)
    local t = trashTarget
    if not (t and t:IsShown()) then return false end
    local cx, cy = t:GetCenter()
    if not cx then return false end
    local k = t:GetEffectiveScale() / UIParent:GetEffectiveScale()
    cx, cy = cx * k, cy * k
    local r = (TRASH_SIZE / 2) * k + 8
    local over = (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r
    PaintTrash(over)
    return over
end



local function EnsureFolderMenu()
    if folderMenu then return folderMenu end
    local menu = CreateFrame("Frame", "EasyFindExtensionFolderMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(9000)
    menu:EnableMouse(true)
    ns.StyleMenuPanel(menu)
    menu.rows = {}

    menu.measure = menu:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    menu.measure:Hide()

    Utils.RegisterClickGuard(menu)
    menu:Hide()
    menu:HookScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    menu:HookScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        self.owner = nil
    end)
    menu:SetScript("OnEvent", function(self, event)
        if event ~= "GLOBAL_MOUSE_DOWN" then return end
        if self.dragging then return end
        if not (Utils.IsFrameVisiblyMouseOver(self) or (self.owner and Utils.IsFrameVisiblyMouseOver(self.owner))) then
            self:Hide()
        end
    end)
    folderMenu = menu
    return menu
end

local LayoutFolderRows

local function EnsureRowGhost(menu)
    if menu.ghost then return menu.ghost end
    local g = CreateFrame("Frame", nil, UIParent)
    g:SetFrameStrata("TOOLTIP")
    g:SetSize(MENU_W - MENU_PAD * 2, MENU_ROW_H)
    g.icon = g:CreateTexture(nil, "ARTWORK")
    g.icon:SetSize(MENU_ICON, MENU_ICON)
    g.icon:SetPoint("LEFT", g, "LEFT", 2, 0)
    g.label = g:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    g.label:SetPoint("LEFT", g.icon, "RIGHT", 8, 0)
    g.label:SetJustifyH("LEFT")
    menu.ghost = g
    return g
end

local function FolderDragEnd(menu)
    local row = menu.dragging
    if not row then return end
    menu:SetScript("OnUpdate", nil)
    if menu.ghost then menu.ghost:Hide() end
    row:SetAlpha(1)
    local from, to = row.index, menu.dragIndex
    menu.dragging = nil
    local x, y = CursorUI()
    local trash = OverTrash(x, y)
    ShowTrash(false)
    if not Utils.IsFrameVisiblyMouseOver(menu) then


        local target = ButtonUnder(x, y, nil)
        local id = tremove(menu.rec.apps, from)

        if not trash then
            if target and target ~= menu.owner then
                ExtensionButtons:AddAppTo(target, id)
            else
                ExtensionButtons:CreateButtonAt(id, x, y)
            end
        end
        if #menu.rec.apps == 0 then
            ExtensionButtons:RemoveButton(menu.owner)
        else
            PaintIcon(menu.owner)
        end
        menu:Hide()
        return
    end
    if from ~= to then
        local id = tremove(menu.rec.apps, from)
        tinsert(menu.rec.apps, to, id)
    end
    menu.dragIndex = nil
    LayoutFolderRows(menu)
end

local function FolderDragBegin(row)
    local menu = row.menu
    menu.dragging = row
    menu.dragIndex = row.index
    row:SetAlpha(0.35)
    GameTooltip:Hide()
    ShowTrash(true)
    local g = EnsureRowGhost(menu)
    g.icon:SetTexture(row.icon:GetTexture())
    g.icon:SetTexCoord(row.icon:GetTexCoord())
    g.icon:SetDesaturated(row.icon:IsDesaturated())
    g.icon:SetVertexColor(row.icon:GetVertexColor())
    g.label:SetText(row.label:GetText())
    g:SetScale(menu:GetEffectiveScale() / UIParent:GetEffectiveScale())
    do
        local x, y = CursorUI()
        local s = g:GetEffectiveScale() / UIParent:GetEffectiveScale()
        g:ClearAllPoints()
        g:SetPoint("LEFT", UIParent, "BOTTOMLEFT", (x - 10) / s, y / s)
    end
    g:Show()
    menu:SetScript("OnUpdate", function(self)
        if not LeftDown() then
            FolderDragEnd(self)
            return
        end
        local x, y = CursorUI()
        local s = g:GetEffectiveScale() / UIParent:GetEffectiveScale()
        g:ClearAllPoints()
        g:SetPoint("LEFT", UIParent, "BOTTOMLEFT", (x - 10) / s, y / s)
        g:SetAlpha(OverTrash(x, y) and 0.5 or 1)

        local k = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local top = self:GetTop() * k
        local slot = mfloor((top - y - MENU_PAD * k) / (MENU_ROW_H * k)) + 1
        slot = mmax(1, mmin(#self.rec.apps, slot))
        if slot ~= self.dragIndex then
            self.dragIndex = slot
            LayoutFolderRows(self)
        end
    end)
end


local function FolderRowPress(row, button)
    if button ~= "LeftButton" then return end
    local x, y = CursorUI()
    row._press = { x = x, y = y }
    row:SetScript("OnUpdate", function(self)
        local press = self._press
        if not press then self:SetScript("OnUpdate", nil); return end
        if not LeftDown() then
            self._press = nil
            self:SetScript("OnUpdate", nil)
            return
        end
        if Moved(press, DRAG_START) then
            self._press = nil
            self:SetScript("OnUpdate", nil)
            FolderDragBegin(self)
        end
    end)
end

LayoutFolderRows = function(menu)
    local apps = menu.rec.apps
    local dragging = menu.dragging


    local order = {}
    local others = {}
    for i = 1, #apps do
        if not (dragging and i == dragging.index) then others[#others + 1] = i end
    end
    local oi = 1
    for slot = 1, #apps do
        if dragging and slot == menu.dragIndex then
            order[slot] = dragging.index
        else
            order[slot] = others[oi]
            oi = oi + 1
        end
    end
    for slot = 1, #apps do
        local row = menu.rows[order[slot]]
        if row then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_PAD, -MENU_PAD - (slot - 1) * MENU_ROW_H)
            row:SetPoint("RIGHT", menu, "RIGHT", -MENU_PAD, 0)
        end
    end
end

local function OpenFolderMenu(btn)
    local menu = EnsureFolderMenu()
    if menu:IsShown() and menu.owner == btn then menu:Hide(); return end
    menu.owner = btn
    menu.rec = btn.rec
    local apps = btn.rec.apps
    for i = 1, #apps do
        local row = menu.rows[i]
        if not row then
            row = CreateFrame("Button", nil, menu)
            row:SetHeight(MENU_ROW_H)
            row.menu = menu
            Utils.InstallMenuRowHighlight(row)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(MENU_ICON, MENU_ICON)
            row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
            row.label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.label:SetJustifyH("LEFT")
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row:HookScript("OnMouseDown", FolderRowPress)
            row:SetScript("OnClick", function(self, button)
                if menu.dragging then return end
                if button == "RightButton" then
                    ExtensionButtons:ShowAppMenu(self, self.app)
                    return
                end
                menu:Hide()
                LaunchApp(self.app)
            end)
            row:SetScript("OnEnter", function(self)
                if menu.dragging then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(BRAND .. ": " .. (self.app and self.app.name or ""))
                local desc = ns.ApplicationDescription and ns.ApplicationDescription(self.app)
                if desc then GameTooltip:AddLine(desc, 1, 1, 1, true) end
                local key = ShortkeyText(self.app)
                if key then GameTooltip:AddLine((L["SHORTKEY_FOR"]):format(key), 0.7, 0.7, 0.7) end
                GameTooltip:AddLine(L["EXTMENU_TT_DRAG"], 0.7, 0.7, 0.7, true)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", GameTooltip_Hide)
            menu.rows[i] = row
        end
        row.index = i
        row.app = AppEntry(apps[i])
        local tex, coords
        if row.app then tex, coords = AppIcon(row.app) end
        if tex then
            row.icon:SetTexture(tex)
            if coords then row.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            else row.icon:SetTexCoord(0, 1, 0, 1) end
            ns.PaintAppGlyph(row.icon)
            row.icon:Show()
        else
            row.icon:Hide()
        end
        row.label:SetText(row.app and row.app.name or "?")
        row:SetAlpha(1)
        row:Show()
    end
    for i = #apps + 1, #menu.rows do menu.rows[i]:Hide() end
    menu.dragIndex = nil
    menu.dragging = nil

    local widest = 0
    for i = 1, #apps do
        menu.measure:SetText(menu.rows[i].label:GetText() or "")
        widest = mmax(widest, menu.measure:GetStringWidth() or 0)
    end
    local menuW = mmax(MENU_W, mfloor(MENU_PAD * 2 + 2 + MENU_ICON + 8 + widest + 12 + 0.5))
    menu:SetSize(menuW, MENU_PAD * 2 + #apps * MENU_ROW_H)
    menu:SetScale(btn:GetScale())
    LayoutFolderRows(menu)
    Utils.RefreshMenuRowHighlights(menu, menu.rows)
    Utils.OpenFlyoutBeside(menu, btn, 4)
    menu:Show()
end



local function ShortkeyRow(app)
    local Shortkeys = ns.Shortkeys
    if not (Shortkeys and app) then return nil end
    local has = Shortkeys:Get(Shortkeys:GetEntryKey(app)) ~= nil
    return {
        kind = "action",
        label = has and L["CTX_EDIT_SHORTKEY"] or L["CTX_ADD_SHORTKEY"],
        onClick = function() Shortkeys:PromptForKey(app) end,
    }
end






local SETTINGS_PAGES = { snippets = true, clipboard = true, notes = true, quicklists = true }
local function SettingsRow(appID)
    local has = appID and SETTINGS_PAGES[appID]
    for _, def in ipairs(not has and appID and ns.ExtensionPages or {}) do
        if def.id == appID then has = true end
    end
    if not has then return nil end
    return {
        kind = "action", label = _G["SETTINGS"] or "Settings",
        onClick = function() EasyFind.API.OpenSettings(appID) end,
    }
end

local function AddAppRows(defs, appID)
    local before = #defs
    local rows = ns.ApplicationMenuRows and ns.ApplicationMenuRows(appID)
    for i = 1, #(rows or {}) do defs[#defs + 1] = rows[i] end
    local settings = SettingsRow(appID)
    if settings then defs[#defs + 1] = settings end
    if #defs > before then defs[#defs + 1] = { kind = "separator" } end
end

function ExtensionButtons:ShowAppMenu(anchor, app, inMenu)
    local defs = {}
    AddAppRows(defs, ns.ApplicationEntryID and ns.ApplicationEntryID(app))
    local row = ShortkeyRow(app)
    if row then
        defs[#defs + 1] = row
        defs[#defs + 1] = { kind = "separator" }
    end
    local appID = ns.ApplicationEntryID and ns.ApplicationEntryID(app)


    if appID and self:HasButtonsFor(appID) then
        defs[#defs + 1] = {
            kind = "action", label = L["EXTBTN_REMOVE_FROM_SCREEN"],
            onClick = function() ExtensionButtons:RemoveButtonsFor(appID) end,
        }
    end
    if appID and not self:FindButtonFor(appID) then
        defs[#defs + 1] = {
            kind = "action", label = L["EXTBTN_POP_OUT"],
            onClick = function()
                local x, y = GetCursorPosition()
                local scale = UIParent:GetEffectiveScale()
                ExtensionButtons:CreateButtonAt(appID, x / scale, y / scale)
            end,
        }
    end

    if inMenu and appID and ns.AppsMenu and ns.AppsMenu.SetHidden then
        defs[#defs + 1] = {
            kind = "action", label = L["EXTMENU_HIDE"], tooltip = L["EXTMENU_HIDE_TT"],
            onClick = function() ns.AppsMenu:SetHidden(appID, true) end,
        }
    end
    if #defs == 0 then return end
    ns.ShowTogglePopup("EasyFindExtensionAppPopup", anchor, defs)
end

local function ShowButtonMenu(btn)
    local rec = btn.rec
    local defs = {}
    if #rec.apps == 1 then
        AddAppRows(defs, rec.apps[1])
        local row = ShortkeyRow(AppEntry(rec.apps[1]))
        if row then
            defs[#defs + 1] = row
            defs[#defs + 1] = { kind = "separator" }
        end
    end
    defs[#defs + 1] = {
        kind = "check", label = L["EXTBTN_LOCK"],
        get = function() return rec.locked end,
        set = function(v)
            rec.locked = v or nil
            ExtensionButtons:Refresh(btn)
        end,
    }
    if rec.micro then

        defs[#defs + 1] = { kind = "separator" }
        defs[#defs + 1] = {
            kind = "action", label = L["EXTBTN_LEAVE_MICRO"],
            onClick = function() ExtensionButtons:LeaveMicroMenu(btn) end,
        }
        defs[#defs + 1] = {
            kind = "action", label = L["EXTBTN_REMOVE"],
            onClick = function() ExtensionButtons:RemoveButton(btn) end,
        }
        ns.ShowTogglePopup("EasyFindExtensionButtonPopup", btn, defs)
        return
    end
    defs[#defs + 1] = {
        kind = "check", label = L["EXTBTN_SNAP"],
        get = function() return SnapOn(rec) end,
        set = function(v)
            rec.snap = Utils.OffOrNil(v)
            if not v and rec.angle then

                local cx, cy = btn:GetCenter()
                local k = btn:GetEffectiveScale() / UIParent:GetEffectiveScale()
                rec.x, rec.y, rec.angle = cx * k, cy * k, nil
                ExtensionButtons:Refresh(btn)
            end
        end,
    }
    defs[#defs + 1] = { kind = "separator" }


    local group = BorderGroup(rec)
    defs[#defs + 1] = {
        kind = "title",
        label = L[group == "minimap" and "EXTBTN_MINIMAP_BORDERS" or "EXTBTN_BORDERS"],
    }
    local function BorderRadio(value, labelKey)
        return {
            kind = "radio", label = L[labelKey], value = value,
            get = function() return BorderStyle(rec) end,
            set = function(v) SetBorderStyle(BorderGroup(rec), v) end,
        }
    end
    defs[#defs + 1] = BorderRadio("easyfind", "EXTBTN_BORDER_EASYFIND")
    defs[#defs + 1] = BorderRadio("minimap", "EXTBTN_BORDER_MINIMAP")
    defs[#defs + 1] = BorderRadio("none", "EXTBTN_BORDER_NONE")
    defs[#defs + 1] = { kind = "separator" }
    defs[#defs + 1] = {
        kind = "action", label = L["EXTBTN_RESET_SIZE"],
        onClick = function()
            rec.scale = nil
            Place(btn)
        end,
    }
    defs[#defs + 1] = {
        kind = "action", label = L["EXTBTN_REMOVE"],
        onClick = function() ExtensionButtons:RemoveButton(btn) end,
    }
    ns.ShowTogglePopup("EasyFindExtensionButtonPopup", btn, defs)
end



local function MoveTickPlace(self)
    local x, y = CursorUI()
    local rec = self.rec

    if OverTrash(x, y) then
        ShowFoldTarget(nil)
        if rec.micro then
            rec.micro = nil
            ApplyMode(self)
            self:SetAlpha(1)
        end
        self.icon:SetAlpha(0.5)
        rec.angle = nil
        rec.x, rec.y = x, y
        Place(self)
        return
    end
    local over = ButtonUnder(x, y, self)
    ShowFoldTarget(over)



    local slot = (not over) and MicroSlotAt(x, y, self) or nil
    if slot then
        if rec.micro ~= slot then
            rec.micro = slot
            ApplyMode(self)
        end
        self:SetAlpha(0.75)
        return
    end
    if rec.micro then
        rec.micro = nil
        rec.angle = nil
        rec.x, rec.y = x, y
        ApplyMode(self)
        self:SetAlpha(1)
    elseif self.micro and self.micro.bg:IsShown() then
        ShowMicroArt(self, false)
    end
    self.icon:SetAlpha(over and 0.5 or 1)
    if not over and SnapOn(rec) then
        local angle = NearMinimap(x, y)
        if angle then
            rec.angle = angle
            Place(self)
            return
        end
    end
    rec.angle = nil
    rec.x, rec.y = x, y
    Place(self)
end



local function MoveTick(self)
    MoveTickPlace(self)
    if not self.rec.micro and self._efBorderGroup ~= BorderGroup(self.rec) then
        PaintDisc(self, self.rec)
    end
end

local function MoveEnd(self)
    ShowFoldTarget(nil)
    self.icon:SetAlpha(1)
    self:SetAlpha(1)
    do
        local x, y = CursorUI()
        local trash = OverTrash(x, y)
        ShowTrash(false)
        if trash then
            ExtensionButtons:RemoveButton(self)
            return
        end
    end
    if self.rec.micro then

        ExtensionButtons:PlaceInMicroMenu(self, self.rec.micro)
        return
    end
    local x, y = CursorUI()
    local over = ButtonUnder(x, y, self)
    if over then

        local mine = self.rec.apps
        for i = 1, #mine do ExtensionButtons:AddAppTo(over, mine[i]) end
        ExtensionButtons:RemoveButton(self)
        return
    end
    Place(self)
end







local escCatcher
local function EnsureEscCatcher()
    if escCatcher then return escCatcher end
    escCatcher = CreateFrame("Frame", nil, UIParent)
    escCatcher:SetSize(1, 1)
    escCatcher:SetPoint("TOPLEFT")
    escCatcher:EnableMouse(false)
    escCatcher:Hide()
    Utils.AttachEscClose(escCatcher, function()
        local cancel = escCatcher.onCancel
        escCatcher.onCancel = nil
        escCatcher:Hide()
        if cancel then cancel() end
    end)
    return escCatcher
end

local function DisarmDragEscape()
    if not escCatcher then return end
    escCatcher.onCancel = nil
    escCatcher:Hide()
end




function ExtensionButtons:CancelDrag()
    local f = escCatcher
    local cancel = f and f.onCancel
    if not cancel then return false end
    f.onCancel = nil
    cancel()
    DisarmDragEscape()
    return true
end

local function ArmDragEscape(onCancel)
    local f = EnsureEscCatcher()
    f.onCancel = onCancel
    f:Show()
end




local function CancelButtonDrag(btn)
    if not btn._dragging then return end
    local from = btn._dragFrom
    btn._dragging, btn._press, btn._dragFrom = nil, nil, nil
    btn:SetScript("OnUpdate", nil)
    btn:SetAlpha(1)
    btn.icon:SetAlpha(1)
    local rec = btn.rec
    if from then
        rec.x, rec.y, rec.angle, rec.micro = from.x, from.y, from.angle, from.micro
    end
    ApplyMode(btn)
    ShowTrash(false)
    ShowFoldTarget(nil)
    DisarmDragEscape()
end




local function StartDrag(btn, press)
    btn._dragging = true
    btn._dragged = true
    GameTooltip:Hide()
    local rec = btn.rec
    btn._dragFrom = { x = rec.x, y = rec.y, angle = rec.angle, micro = rec.micro }
    ArmDragEscape(function() CancelButtonDrag(btn) end)
    ShowTrash(true)


    if rec.micro then ExtensionButtons:LeaveMicroMenu(btn, press.x, press.y) end

    if ns.HideTogglePopup then ns.HideTogglePopup("EasyFindExtensionButtonPopup") end
end


local function DragLoop(btn)
    local press = btn._press
    if not LeftDown() then
        btn._press = nil
        btn:SetScript("OnUpdate", nil)
        if btn._dragging then
            btn._dragging = nil
            btn._dragFrom = nil



            if virtualMouse then btn._dragged = nil end
            DisarmDragEscape()
            MoveEnd(btn)
        end
        return
    end
    if btn._dragging then
        MoveTick(btn)
        return
    end
    if press and not btn.rec.locked and Moved(press, DRAG_START) then
        StartDrag(btn, press)
    end
end



local function ButtonPress(self, button)
    if button ~= "LeftButton" then return end
    local x, y = CursorUI()
    self._press = { x = x, y = y }
    self._dragged = nil
    self:SetScript("OnUpdate", DragLoop)
end



function ExtensionButtons:BeginVirtualDrag(btn)
    if not (btn and btn.rec) then return end
    local x, y = CursorUI()
    btn._press = { x = x, y = y }
    btn._dragged = nil
    StartDrag(btn, btn._press)
    btn:SetScript("OnUpdate", DragLoop)
end




local function ScaleTick(btn)
    local x, y = CursorUI()
    local cx, cy = btn:GetCenter()
    if not cx then return end
    local k = btn:GetEffectiveScale() / UIParent:GetEffectiveScale()
    cx, cy = cx * k, cy * k
    local d = msqrt((x - cx) ^ 2 + (y - cy) ^ 2)
    local wanted = (d * 0.7071) / (BASE_SIZE / 2)
    btn.rec.scale = mmax(MIN_SCALE, mmin(MAX_SCALE, wanted))
    Place(btn)
end





local function GrabberPress(self, button)
    if button ~= "LeftButton" then return end
    local btn = self:GetParent()
    if btn.rec.angle or btn.rec.micro then return end
    GameTooltip:Hide()
    btn._resizing = true
    btn:SetScript("OnUpdate", function(b)
        if not LeftDown() then
            b:SetScript("OnUpdate", nil)
            b._resizing = nil
            b.rec.scale = mfloor((b.rec.scale or 1) * 20 + 0.5) / 20
            Place(b)
            if not (b:IsMouseOver() or b.grabber:IsMouseOver()) then b.grabber:Hide() end
            return
        end
        ScaleTick(b)
    end)
end

local function CreateButtonFrame(index, rec)
    local btn = CreateFrame("Button", "EasyFindExtensionButton" .. index, UIParent)
    btn.rec = rec
    btn:SetSize(BASE_SIZE, BASE_SIZE)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(8)
    btn:SetClampedToScreen(true)


    Utils.RegisterClickGuard(btn)
    BuildDisc(btn)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnMouseDown", ButtonPress)
    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ShowButtonMenu(self)
            return
        end

        if self._dragged then
            self._dragged = nil
            return
        end
        if #self.rec.apps == 1 then
            LaunchApp(AppEntry(self.rec.apps[1]))
            if self.rec.micro then
                Utils.SafeAfter(0.05, function() EnsureMicroStateHooks(); RefreshMicroStates() end)
            end
        else
            OpenFolderMenu(self)
        end
    end)
    btn:SetScript("OnEnter", function(self)
        if self._dragging then return end
        ShowTooltip(self)

        if not (self.rec.locked or self.rec.micro or self.rec.angle) then self.grabber:Show() end
    end)
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if self._resizing then return end
        if not self.grabber:IsMouseOver() then self.grabber:Hide() end
    end)

    local grabber = CreateFrame("Button", nil, btn)
    grabber:SetSize(16, 16)
    grabber:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 6, -6)
    grabber:SetFrameLevel(btn:GetFrameLevel() + 5)
    grabber:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grabber:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grabber:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grabber:SetScript("OnMouseDown", GrabberPress)
    grabber:SetScript("OnLeave", function(self)
        if btn._resizing then return end
        if not btn:IsMouseOver() then self:Hide() end
    end)
    grabber:Hide()
    btn.grabber = grabber

    btn.badge = ns.CreateCountBadge and ns.CreateCountBadge(btn, 11) or nil
    if btn.badge then
        btn.badge:SetFrameLevel(btn:GetFrameLevel() + 6)

        btn.badge:SetPoint("CENTER", btn.icon, "TOPRIGHT", -1, -1)
    end

    btn._efOnThemeRestyle = function(self) PaintIcon(self) end
    ns._menuPanels = ns._menuPanels or setmetatable({}, { __mode = "k" })
    ns._menuPanels[btn] = true
    return btn
end

local function PaintBadge(btn)
    if not (btn and btn.badge and btn.rec) then return end
    local n = 0
    for _, id in ipairs(btn.rec.apps) do n = n + (ns.GetApplicationBadge and ns.GetApplicationBadge(id) or 0) end
    btn.badge:SetCount(n)
end

function ExtensionButtons:Refresh(btn)
    if not btn then return end
    ApplyMode(btn)
    if btn.rec.locked then btn.grabber:Hide() end
    PaintBadge(btn)
end

function ExtensionButtons:RefreshBadges()
    for i = 1, #buttons do PaintBadge(buttons[i]) end
end

function ExtensionButtons:PlaceInMicroMenu(btn, slot)
    local rec = btn.rec
    rec.micro = slot or rec.micro or 1
    rec.angle = nil
    ApplyMode(btn)
end


function ExtensionButtons:LeaveMicroMenu(btn, x, y)
    local rec = btn.rec
    if not x then
        local cx, cy = btn:GetCenter()
        local k = btn:GetEffectiveScale() / UIParent:GetEffectiveScale()
        x = cx and cx * k or 400
        y = cy and (cy * k + 48) or 400
    end
    rec.micro = nil
    rec.angle = nil
    rec.x, rec.y = x, y
    ApplyMode(btn)
end

function ExtensionButtons:CreateButtonInMicroMenu(appID, slot)
    local btn = self:CreateButtonAt(appID, 400, 400)
    if btn then self:PlaceInMicroMenu(btn, slot) end
    return btn
end



function ExtensionButtons:CreateButtonAt(appID, x, y)
    local store = Store()
    if not store then return nil end
    local rec = { apps = { appID }, x = x, y = y, scale = 1 }

    local angle = NearMinimap(x, y)
    if angle then rec.angle = angle end
    store[#store + 1] = rec
    local btn = CreateButtonFrame(#store, rec)
    buttons[#store] = btn
    self:Refresh(btn)
    btn:SetShown(not AppHidden(rec))
    return btn
end

function ExtensionButtons:AddAppTo(btn, appID)
    local apps = btn.rec.apps
    for i = 1, #apps do
        if apps[i] == appID then return end
    end
    apps[#apps + 1] = appID
    self:Refresh(btn)
end

function ExtensionButtons:RemoveButton(btn)
    local store = Store()
    if not store then return end
    for i = 1, #store do
        if store[i] == btn.rec then
            tremove(store, i)
            break
        end
    end
    if folderMenu and folderMenu.owner == btn then folderMenu:Hide() end
    if btn.layoutIndex then MicroRemove(btn) end
    btn:Hide()
    if ns._menuPanels then ns._menuPanels[btn] = nil end
    for i = 1, #buttons do
        if buttons[i] == btn then tremove(buttons, i); break end
    end
end




function ExtensionButtons:SetAppButtonsHidden(appID, hidden)
    hiddenApps[appID] = hidden and true or nil
    for i = 1, #buttons do
        local b = buttons[i]
        if b and b.rec and not b.rec.micro and #b.rec.apps == 1 and b.rec.apps[1] == appID then
            b:SetShown(not hidden)
        end
    end
end

function ExtensionButtons:FindButtonFor(appID)
    for i = #buttons, 1, -1 do
        local b = buttons[i]
        if b and b.rec and #b.rec.apps == 1 and b.rec.apps[1] == appID then return b end
    end
    return nil
end

function ExtensionButtons:HasButtonsFor(appID)
    for i = 1, #buttons do
        local apps = buttons[i] and buttons[i].rec and buttons[i].rec.apps
        for j = 1, #(apps or {}) do
            if apps[j] == appID then return true end
        end
    end
    return false
end



function ExtensionButtons:RemoveButtonsFor(appID)
    for i = #buttons, 1, -1 do
        local btn = buttons[i]
        local apps = btn and btn.rec and btn.rec.apps
        if apps then
            for j = #apps, 1, -1 do
                if apps[j] == appID then tremove(apps, j) end
            end
            if #apps == 0 then
                self:RemoveButton(btn)
            else
                PaintIcon(btn)
                self:Refresh(btn)
            end
        end
    end
end

function ExtensionButtons:Owns(btn)
    for i = 1, #buttons do
        if buttons[i] == btn then return true end
    end
    return false
end



local function EnsureGhost()
    if dragGhost then return dragGhost end
    local g = CreateFrame("Frame", "EasyFindExtensionDragGhost", UIParent)
    g:SetFrameStrata("TOOLTIP")
    g:SetSize(BASE_SIZE, BASE_SIZE)
    BuildDisc(g)
    g:SetAlpha(0.85)
    g:Hide()
    dragGhost = g
    return g
end



function ExtensionButtons:BeginDragFromMenu(app)
    local appID = ns.ApplicationEntryID and ns.ApplicationEntryID(app)
    if not appID then return end
    local g = EnsureGhost()
    local tex, coords = AppIcon(app)
    g.icon:SetTexture(tex or ns.EXTENSIONS_ICON_TEX)
    if coords then g.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else g.icon:SetTexCoord(0, 1, 0, 1) end
    ns.PaintAppGlyph(g.icon)
    PaintDisc(g, nil)


    local sx, sy = CursorUI()
    g:ClearAllPoints()
    g:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sx, sy)
    g:Show()
    ShowTrash(true)

    ArmDragEscape(function()
        g:SetScript("OnUpdate", nil)
        if g.slot then
            MicroRemove(g)
            g.slot = nil
            GhostMicroLook(g, false)
        end
        ShowTrash(false)
        ShowFoldTarget(nil)
        g:Hide()
    end)
    g:SetScript("OnUpdate", function(self)
        local x, y = CursorUI()
        local trash = OverTrash(x, y)
        local over = (not trash) and ButtonUnder(x, y, nil) or nil
        ShowFoldTarget(over)
        local slot = (not over and not trash) and MicroSlotAt(x, y, self) or nil
        if slot then

            if self.slot ~= slot then
                if not self.slot then GhostMicroLook(self, true) end
                MicroInsert(self, slot)
                self.slot = slot
            end
        else
            if self.slot then
                MicroRemove(self)
                self.slot = nil
                GhostMicroLook(self, false)
            end
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
            self.icon:SetAlpha((over or trash) and 0.5 or 1)
        end
        if LeftDown() then return end
        self:SetScript("OnUpdate", nil)
        DisarmDragEscape()
        ShowTrash(false)
        ShowFoldTarget(nil)
        local held = self.slot
        if held then
            MicroRemove(self)
            self.slot = nil
            GhostMicroLook(self, false)
        end
        self:Hide()
        if trash then
            return
        elseif over then
            ExtensionButtons:AddAppTo(over, appID)
        elseif held then
            ExtensionButtons:CreateButtonInMicroMenu(appID, held)
        else
            ExtensionButtons:CreateButtonAt(appID, x, y)
        end
    end)
end



function ExtensionButtons:Initialize()
    local store = Store()
    if not store then return end

    for i = #store, 1, -1 do
        local rec = store[i]
        local apps = rec.apps or {}
        for j = #apps, 1, -1 do
            if not AppEntry(apps[j]) then tremove(apps, j) end
        end
        if #apps == 0 then tremove(store, i) end
        rec.border = nil
    end
    local inBar = {}
    for i = 1, #store do
        local btn = buttons[i] or CreateButtonFrame(i, store[i])
        btn.rec = store[i]
        buttons[i] = btn
        if store[i].micro then inBar[#inBar + 1] = btn else self:Refresh(btn) end
        btn:SetShown(not AppHidden(store[i]))
    end


    table.sort(inBar, function(a, b) return (a.rec.micro or 0) < (b.rec.micro or 0) end)
    for i = 1, #inBar do self:Refresh(inBar[i]) end
    for i = 1, #inBar do inBar[i].rec.micro = inBar[i].layoutIndex or inBar[i].rec.micro end
    for i = #store + 1, #buttons do
        buttons[i]:Hide()
        buttons[i] = nil
    end
end

function ExtensionButtons:RefreshAll()
    for i = 1, #buttons do self:Refresh(buttons[i]) end
end



function ExtensionButtons:Reload()
    for i = 1, #buttons do
        local btn = buttons[i]
        if btn.layoutIndex then MicroRemove(btn) end
        btn:Hide()
    end
    self:Initialize()
end







local registeredSurfaces = false
function ExtensionButtons:RegisterLaunchSurfaces()
    if registeredSurfaces then return end
    registeredSurfaces = true
    local apps = ns.BuildApplicationEntries and ns.BuildApplicationEntries() or {}
    local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
    for i = 1, #apps do
        local app = apps[i]
        local name = BRAND .. ": " .. (app.name or "?")
        local tex = AppIcon(app)
        if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
            AddonCompartmentFrame:RegisterAddon({
                text = name,
                icon = tex,
                notCheckable = true,
                registerForAnyClick = true,
                func = function() LaunchApp(app) end,
            })
        end
        if ldb and not ldb:GetDataObjectByName(name) then
            ldb:NewDataObject(name, {
                type = "launcher",
                label = name,
                icon = tex,
                OnClick = function(self)


                    if self and ns.brokerLauncherButtons then ns.brokerLauncherButtons[self] = true end
                    LaunchApp(app)
                end,
                OnTooltipShow = function(tooltip)
                    tooltip:SetText(name)
                    local key = ShortkeyText(app)
                    if key then tooltip:AddLine((L["SHORTKEY_FOR"]):format(key), 1, 1, 1) end
                end,
            })
        end
    end
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    Utils.SafeAfter(0, function()
        ExtensionButtons:Initialize()
        ExtensionButtons:RegisterLaunchSurfaces()
    end)
end)
