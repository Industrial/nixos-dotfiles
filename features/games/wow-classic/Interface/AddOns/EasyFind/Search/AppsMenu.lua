local _, ns = ...
local L = ns.L

local Results = ns.Results
local Utils = ns.Utils

local CreateFrame = CreateFrame
local UIParent = UIParent
local tremove, tinsert, sformat, strtrim, time = table.remove, table.insert, string.format, strtrim, time



local AppsMenu = {}
ns.AppsMenu = AppsMenu

local ROW_H = 24
local PAD = 6
local ICON = 16



function ns.BuildApplicationEntries()
    return ns.Extensions.Entries()
end

function ns.ApplicationDescription(app)
    local def = ns.Extensions.Get(ns.ApplicationEntryID(app))
    return def and def.description or app and app.description or nil
end



function ns.ApplicationEntryID(app)
    if not app then return nil end
    if app.extensionID then return app.extensionID end
    if app.quicklistID then return "quicklist:" .. app.quicklistID end
    for flag, id in pairs(ns.Extensions.LEGACY_FLAGS) do
        if app[flag] then return id end
    end
    return nil
end




function ns.IsApplicationLauncher(data)
    return data ~= nil and not data.quicklistID and not data.snippetsLauncher
        and ns.ApplicationEntryID(data) ~= nil
end



function ns.FindApplicationEntry(idOrData)
    if not idOrData then return nil end
    local id = type(idOrData) == "table" and ns.ApplicationEntryID(idOrData) or idOrData
    if not id then return nil end
    local apps = ns.BuildApplicationEntries()
    for i = 1, #apps do
        if ns.ApplicationEntryID(apps[i]) == id then return apps[i] end
    end
    return nil
end




local function QuicklistShowing(listID)
    local Filters = ns.Filters
    local qf = Filters and Filters.GetQuickFilter and Filters:GetQuickFilter()
    local rf = ns.Search and ns.Search.GetResultsFrame and ns.Search:GetResultsFrame()
    return rf ~= nil and rf:IsShown() and qf ~= nil and qf.quicklistID ~= nil
        and (listID == nil or qf.quicklistID == listID)
end

function ns.IsApplicationOpen(app)
    if not app then return false end
    if app.quicklistID then return QuicklistShowing(app.quicklistID) end
    return ns.Extensions.IsOpen(ns.ApplicationEntryID(app))
end

function ns.CloseApplication(app)
    if not app then return end
    if app.quicklistID then
        if ns.Filters and ns.Filters.ClearQuickFilter then ns.Filters:ClearQuickFilter(false) end
        if Results and Results.HideResults then Results:HideResults() end
        return
    end
    ns.Extensions.Close(ns.ApplicationEntryID(app))
end



function ns.CurrentApplicationSurfaceID()
    if QuicklistShowing() then return "quicklist:" .. ns.Filters:GetQuickFilter().quicklistID end
    return ns.Extensions.ScopeShowing()
end







local DISMISS_GRACE = 0.6
local dismissedID, dismissedAt
function ns.NoteApplicationDismissed(id)
    if not id then return end
    dismissedID, dismissedAt = id, GetTime()
end
local function JustDismissed(app)
    if not dismissedID then return false end
    if GetTime() - (dismissedAt or 0) > DISMISS_GRACE then
        dismissedID = nil
        return false
    end
    return ns.ApplicationEntryID(app) == dismissedID
end





local launchOpenedBar = {}



local function BarShown()
    local sf = ns.Search and ns.Search.GetSearchFrame and ns.Search:GetSearchFrame()
    if not (sf and sf:IsShown()) then return false end
    local db = EasyFind and EasyFind.db
    if db and db.smartShow and not db.autoHide and sf.smartShowVisible then
        return sf.smartShowVisible() and true or false
    end
    return (sf:GetAlpha() or 1) > 0.01
end
local function HideBarIfLaunchOpened(app)
    local id = ns.ApplicationEntryID(app)
    if not (id and launchOpenedBar[id]) then return end
    launchOpenedBar[id] = nil
    if BarShown() and ns.Search.Hide then ns.Search:Hide() end
end




local appBadges = {}



local BADGE_DIGIT_TEX = "Interface\\AddOns\\EasyFind\\textures\\badge-digits"
local BADGE_DIGIT_BAND = 0.8106
local BADGE_DIGIT_V0, BADGE_DIGIT_V1 = 0.19603, 0.80397
local BADGE_DIGITS = {
    ["0"] = { 0.01400, 0.07584, 0.6597 },
    ["1"] = { 0.11494, 0.15459, 0.4229 },
    ["2"] = { 0.19540, 0.25381, 0.6230 },
    ["3"] = { 0.28463, 0.34428, 0.6362 },
    ["4"] = { 0.37308, 0.43552, 0.6660 },
    ["5"] = { 0.46544, 0.52284, 0.6123 },
    ["6"] = { 0.55400, 0.61397, 0.6396 },
    ["7"] = { 0.64682, 0.70084, 0.5762 },
    ["8"] = { 0.73367, 0.79368, 0.6401 },
    ["9"] = { 0.82353, 0.88350, 0.6396 },
    ["+"] = { 0.91182, 0.97490, 0.6729 },
}
local badgeTiles = setmetatable({}, { __mode = "k" })
local PaintTileBadge
function ns.SetApplicationBadge(id, count)
    count = (type(count) == "number" and count > 0) and count or nil
    if not id or appBadges[id] == count then return end
    appBadges[id] = count
    for row in pairs(badgeTiles) do
        if row:IsShown() and row.item then PaintTileBadge(row) end
    end
    if ns.ExtensionButtons and ns.ExtensionButtons.RefreshBadges then ns.ExtensionButtons:RefreshBadges() end
end

function ns.GetApplicationBadge(id)
    return id and appBadges[id] or nil
end



function ns.CreateCountBadge(parent, height)
    local badge = CreateFrame("Frame", nil, parent)
    badge._efNoAutoRetint = true
    badge:SetSize(height, height)
    ns.CreateRoundedRectBorder(badge)
    ns.SetRoundedRectBarHeight(badge, height)
    ns.SetRoundedRectBorderBgAlpha(badge, 1)
    ns.SetRoundedRectBorderEdgeShown(badge, false)

    local em = height * 0.66
    badge.glyphs = {}
    function badge:SetCount(n, r, g, b)
        if not n or n <= 0 then self:Hide() return end
        local s = n > 99 and "99+" or tostring(n)
        local total = 0
        for i = 1, #s do total = total + BADGE_DIGITS[s:sub(i, i)][3] * em end
        self:SetWidth(math.max(height, math.ceil(total + height * 0.55)))
        local x = -total / 2
        for i = 1, #s do
            local d = BADGE_DIGITS[s:sub(i, i)]
            local glyph = self.glyphs[i]
            if not glyph then
                glyph = self:CreateTexture(nil, "OVERLAY")
                glyph:SetTexture(BADGE_DIGIT_TEX)
                self.glyphs[i] = glyph
            end
            local w = d[3] * em
            glyph:SetTexCoord(d[1], d[2], BADGE_DIGIT_V0, BADGE_DIGIT_V1)
            glyph:SetSize(w, BADGE_DIGIT_BAND * em)
            glyph:ClearAllPoints()
            glyph:SetPoint("CENTER", self, "CENTER", x + w / 2, 0)
            glyph:Show()
            x = x + w
        end
        for i = #s + 1, #self.glyphs do self.glyphs[i]:Hide() end
        ns.SetRoundedRectFill(self, r or 0.89, g or 0.22, b or 0.21, 1, true)
        self:Show()
    end
    badge:Hide()
    return badge
end

PaintTileBadge = function(row)
    local item = row.item
    local n = 0
    if item.group then
        for _, id in ipairs(item.group.apps) do n = n + (appBadges[id] or 0) end
    elseif item.app then
        n = appBadges[ns.ApplicationEntryID(item.app) or ""] or 0
    end
    if n == 0 and not row.badge then return end
    if not row.badge then
        row.badge = ns.CreateCountBadge(row, 11)
        row.badge:SetFrameLevel(row:GetFrameLevel() + 4)
        row.badge:SetPoint("CENTER", row.icon, "TOPRIGHT", -1, -1)
    end
    row.badge:SetCount(n)
end



function ns.ApplicationMenuRows(id)
    local def = ns.Extensions.Get(id)
    if not (def and def.menu) then return nil end
    local ok, rows = ns.Extensions.Run(def.menu)
    return ok and rows or nil
end

function ns.ToggleApplication(app)
    if not app then return end
    if JustDismissed(app) then
        dismissedID = nil
        HideBarIfLaunchOpened(app)
        return
    end
    if ns.IsApplicationOpen(app) then
        ns.CloseApplication(app)
        HideBarIfLaunchOpened(app)
        return
    end
    local id = ns.ApplicationEntryID(app)

    if InCombatLockdown() then return id and ns.Extensions.Launch(id) end
    if id then launchOpenedBar[id] = not BarShown() end
    Results:HideResults()
    ns.ResultHandlers:SelectResult(app)
end






ns.ExtensionPages = ns.ExtensionPages or {}
function ns.RegisterExtensionPage(def)
    if not (def and def.id and def.build) then return end
    local pages = ns.ExtensionPages
    for i = 1, #pages do
        if pages[i].id == def.id then pages[i] = def; return end
    end
    pages[#pages + 1] = def
    if ns.Options and ns.Options.RefreshExtensionPages then ns.Options:RefreshExtensionPages() end
end





local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function CreateGridGlyph(parent, size)
    local glyph = CreateFrame("Frame", nil, parent)
    glyph:SetSize(size, size)
    local cell = size / 3
    local dot = cell * 0.72
    glyph.dots = {}
    for row = 0, 2 do
        for col = 0, 2 do
            local tex = glyph:CreateTexture(nil, "OVERLAY")
            tex:SetColorTexture(1, 1, 1, 1)
            tex:SetSize(dot, dot)
            tex:SetPoint("CENTER", glyph, "TOPLEFT", (col + 0.5) * cell, -(row + 0.5) * cell)
            local mask = glyph:CreateMaskTexture()
            mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(tex)
            tex:AddMaskTexture(mask)
            glyph.dots[#glyph.dots + 1] = tex
        end
    end
    return glyph
end


ns.CreateGridGlyph = CreateGridGlyph

function AppsMenu:SetGlyphColor(r, g, b, a)
    local glyph = self.button and self.button.glyph
    if not glyph then return end
    for i = 1, #glyph.dots do
        glyph.dots[i]:SetVertexColor(r, g, b, a or 1)
    end
end




local LABEL_POSITIONS = { "right", "below", "above", "left", "hidden" }
AppsMenu.LABEL_POSITIONS = LABEL_POSITIONS
AppsMenu.LABEL_SIZES = { { "OPT_FONT_SMALL", 0.85 }, { "OPT_FONT_MED", 1 }, { "OPT_FONT_LARGE", 1.15 }, { "OPT_FONT_XL", 1.3 } }
AppsMenu.ICON_SIZES = { { "OPT_FONT_SMALL", 0.85 }, { "OPT_FONT_MED", 1 }, { "OPT_FONT_LARGE", 1.25 }, { "OPT_FONT_XL", 1.5 } }
AppsMenu.ROWS_CHOICES = { 4, 6, 8, 10, 12 }
AppsMenu.ROWS_DEFAULT = 6
local TILE_ICON = 20
local GAP = 4
local GROUP_HOLD = 0.45
local BuildRows
local function Settings()
    local db = EasyFind and EasyFind.db
    if not db then return { rows = AppsMenu.ROWS_DEFAULT, labels = "right", labelSize = 1, iconSize = 1 } end
    local s = db.appsMenu
    if not s then s = {} db.appsMenu = s end
    s.rows = s.rows or AppsMenu.ROWS_DEFAULT
    s.columns = nil
    s.labels = s.labels or "right"
    s.labelSize = s.labelSize or 1
    s.iconSize = s.iconSize or 1
    s.font = nil
    return s
end
AppsMenu.Settings = Settings



function AppsMenu:IsHidden(id)
    local hidden = Settings().hidden
    return hidden ~= nil and hidden[id] == true
end

function AppsMenu:SetHidden(id, on)
    local s = Settings()
    if on then
        s.hidden = s.hidden or {}
        s.hidden[id] = true
    elseif s.hidden then
        s.hidden[id] = nil
        if next(s.hidden) == nil then s.hidden = nil end
    end
    self:Rebuild()
    if self.hiddenChanged then self.hiddenChanged() end
end



local function IconPx(s)
    local k = s.iconSize or 1
    return ICON * k, TILE_ICON * k
end


local function Cell(i, rows)
    return math.floor((i - 1) / rows) + 1, (i - 1) % rows
end

local function GroupByID(s, id)
    for _, g in ipairs(s.groups or {}) do if g.id == id then return g end end
    return nil
end

local function ByName(a, b) return (a.name or "") < (b.name or "") end




local function MenuItems(groupID)
    local s = Settings()
    local hidden = s.hidden or {}
    local apps = ns.BuildApplicationEntries and ns.BuildApplicationEntries() or {}
    local byID = {}
    for _, app in ipairs(apps) do
        local id = ns.ApplicationEntryID(app)
        if id and not hidden[id] then byID[id] = app end
    end
    local items = {}
    if groupID then
        local g = GroupByID(s, groupID)
        for _, id in ipairs(g and g.apps or {}) do
            if byID[id] then items[#items + 1] = { app = byID[id], id = id, name = byID[id].name } end
        end
        return items, g
    end
    local function Shows(g)
        for _, id in ipairs(g.apps) do
            if byID[id] then return true end
        end
        return false
    end
    local grouped, placed = {}, {}
    for _, g in ipairs(s.groups or {}) do
        for _, id in ipairs(g.apps) do grouped[id] = true end
    end
    for _, id in ipairs(s.order or {}) do
        local gid = id:match("^group:(.+)$")
        local g = gid and GroupByID(s, gid)
        if g and not placed[id] then
            if Shows(g) then items[#items + 1] = { group = g, id = id, name = g.name } end
            placed[id] = true
        elseif not gid and byID[id] and not grouped[id] and not placed[id] then
            items[#items + 1] = { app = byID[id], id = id, name = byID[id].name }
            placed[id] = true
        end
    end
    local rest = {}
    for _, g in ipairs(s.groups or {}) do
        if not placed["group:" .. g.id] and Shows(g) then
            rest[#rest + 1] = { group = g, id = "group:" .. g.id, name = g.name }
        end
    end
    for id, app in pairs(byID) do
        if not grouped[id] and not placed[id] then rest[#rest + 1] = { app = app, id = id, name = app.name or "" } end
    end
    table.sort(rest, ByName)
    for _, it in ipairs(rest) do items[#items + 1] = it end
    return items, nil
end
AppsMenu.MenuItems = MenuItems

local function TintGlyph(tex)
    local gc = ns.ChromeGlyphColor()
    tex:SetDesaturated(true)
    tex:SetVertexColor(gc[1], gc[2], gc[3], 1)
end


ns.PaintAppGlyph = TintGlyph

local function AppGlyph(app)



    local iconDef = ns.ResultIcons and (ns.ResultIcons:GetAppGlyphIcon(app)
        or ns.ResultIcons:GetFlatCategoryIcon(app))
    return (iconDef and iconDef.tex) or app.icon, iconDef and iconDef.coords
end

local function EnsureTile(dropdown, i)
    local row = dropdown.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, dropdown)
    row:SetSize(100, ROW_H)


    Utils.InstallMenuRowHighlight(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)

    row.minis = {}
    for k = 1, 4 do
        local mini = row:CreateTexture(nil, "ARTWORK")
        mini:Hide()
        row.minis[k] = mini
    end
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetWordWrap(false)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        local item = self.item
        if not item then return end

        if self._efDragged then
            self._efDragged = nil
            return
        end
        if item.back then
            BuildRows(dropdown, nil)
            return
        end
        if button == "RightButton" then
            AppsMenu:ShowTileMenu(self)
            return
        end
        if item.group then
            BuildRows(dropdown, item.group.id)
            return
        end
        dropdown:Hide()
        ns.ToggleApplication(item.app)
    end)
    row:HookScript("OnEnter", function(self)
        local item = self.item
        if not item or item.back then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(item.name or "")
        local desc = item.app and ns.ApplicationDescription(item.app)
        if desc then GameTooltip:AddLine(desc, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    row:HookScript("OnLeave", function() GameTooltip:Hide() end)






    row:HookScript("OnMouseDown", function(self, button)
        local item = self.item
        self._efDragged = nil
        if button ~= "LeftButton" or not item or item.back then return end
        local sx, sy = GetCursorPosition()
        self._efPress = { x = sx, y = sy }
        self:SetScript("OnUpdate", function(row2)
            local press = row2._efPress
            if not press then row2:SetScript("OnUpdate", nil); return end
            if not IsMouseButtonDown("LeftButton") then
                row2._efPress = nil
                row2:SetScript("OnUpdate", nil)
                return
            end
            local cx, cy = GetCursorPosition()
            if (cx - press.x) ^ 2 + (cy - press.y) ^ 2 < 36 then return end
            row2._efPress = nil
            row2:SetScript("OnUpdate", nil)
            row2._efDragged = true
            AppsMenu:BeginArrangeDrag(dropdown, row2)
        end)
    end)
    dropdown.rows[i] = row
    return row
end


local function PlaceTile(row, labels)
    local icon, label = row.icon, row.label
    local iconPx, tilePx = IconPx(Settings())
    icon:ClearAllPoints()
    label:ClearAllPoints()
    label:SetShown(labels ~= "hidden")
    if labels == "below" or labels == "above" then
        icon:SetSize(tilePx, tilePx)
        label:SetJustifyH("CENTER")
        label:SetPoint("LEFT", row, "LEFT", 3, 0)
        label:SetPoint("RIGHT", row, "RIGHT", -3, 0)
        if labels == "below" then
            icon:SetPoint("TOP", row, "TOP", 0, -5)
            label:SetPoint("TOP", icon, "BOTTOM", 0, -4)
        else
            label:SetPoint("TOP", row, "TOP", 0, -5)
            icon:SetPoint("TOP", label, "BOTTOM", 0, -4)
        end
    elseif labels == "hidden" then
        icon:SetSize(tilePx, tilePx)
        icon:SetPoint("CENTER", row, "CENTER", 0, 0)
    elseif labels == "left" then
        icon:SetSize(iconPx, iconPx)
        icon:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        label:SetJustifyH("RIGHT")
        label:SetPoint("RIGHT", icon, "LEFT", -8, 0)
        label:SetPoint("LEFT", row, "LEFT", 4, 0)
    else
        icon:SetSize(iconPx, iconPx)
        icon:SetPoint("LEFT", row, "LEFT", 2, 0)
        label:SetJustifyH("LEFT")
        label:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    end

    local half = icon:GetWidth() / 2
    for k = 1, 4 do
        local mini = row.minis[k]
        mini:SetSize(half - 1, half - 1)
        mini:ClearAllPoints()
        mini:SetPoint("TOPLEFT", icon, "TOPLEFT", ((k - 1) % 2) * half, -math.floor((k - 1) / 2) * half)
    end
end

local function PaintTile(row, item, dropdown)
    row.item = item
    local labels = Settings().labels
    PlaceTile(row, labels)
    for k = 1, 4 do row.minis[k]:Hide() end
    if item.back then
        row.icon:SetTexture(nil)
        Utils.SetChevronTexture(row.icon)
        row.icon:SetRotation(-math.pi / 2)
        TintGlyph(row.icon)
        row.icon:Show()
    elseif item.group then
        row.icon:SetRotation(0)
        row.icon:Hide()
        local shown = 0
        for _, id in ipairs(item.group.apps) do
            local app = not AppsMenu:IsHidden(id) and ns.FindApplicationEntry(id)
            if app and shown < 4 then
                shown = shown + 1
                local mini = row.minis[shown]
                local tex, coords = AppGlyph(app)
                mini:SetTexture(tex or ns.EXTENSIONS_ICON_TEX)
                mini:SetTexCoord(unpack(coords or { 0, 1, 0, 1 }))
                ns.PaintAppGlyph(mini)
                mini:Show()
            end
        end
    else
        row.icon:SetRotation(0)
        local tex, coords = AppGlyph(item.app)
        if tex then
            row.icon:SetTexture(tex)
            row.icon:SetTexCoord(unpack(coords or { 0, 1, 0, 1 }))
            ns.PaintAppGlyph(row.icon)
            row.icon:Show()
        else
            row.icon:Hide()
        end
    end
    badgeTiles[row] = true
    if item.back then
        if row.badge then row.badge:Hide() end
    else
        PaintTileBadge(row)
    end
    row.label:SetText(item.name or "")


    local bar = ns.Search and ns.Search.GetSearchFrame and ns.Search:GetSearchFrame()
    local ref = bar and bar.editBox and bar.editBox.placeholder
    local file, size, flags
    if ref then file, size, flags = ref:GetFont() end
    if file and size then row.label:SetFont(file, size * Settings().labelSize, flags) end

    local exp = item.app and item.app.experimental
    if exp and not row.expTag then
        row.expTag = ns.CreateFeatureTag(dropdown, "exp", L["TAG_EXP_TITLE"], exp, true)
    end
    if row.expTag then
        local shown = exp ~= nil and labels ~= "hidden"

        if labels == "left" then
            row.label:SetPoint("RIGHT", row.icon, "LEFT", -8 - (shown and row.expTag:GetWidth() + 1 or 0), 0)
        end
        ns.SuperscriptTag(row.expTag, row.label)
        row.expTag:SetShown(shown)
    end
    row:Show()
end


local function TileWidth(row, labels)
    local iconPx, tilePx = IconPx(Settings())
    if labels == "hidden" then return tilePx + 12 end
    local w = (row.label:GetStringWidth() or 0) + (row.expTag and row.expTag:IsShown() and row.expTag:GetWidth() + 1 or 0)
    if labels == "below" or labels == "above" then return math.min(140, math.max(tilePx, w) + 12) end
    return math.min(188 + iconPx - ICON, iconPx + 8 + w + 10)
end





local colWidths = {}
local function TileMetrics(dropdown, n)
    local s = Settings()
    local rows = math.max(1, s.rows)
    local cols = math.max(1, math.ceil(n / rows))
    local fontH = 12
    wipe(colWidths)

    local floor = (s.labels == "below" or s.labels == "above") and 52 or (s.labels == "hidden" and 32)
        or (cols == 1 and 78 or 0)
    for c = 1, cols do colWidths[c] = floor end
    for i = 1, n do
        local row = dropdown.rows[i]
        local c = Cell(i, rows)
        colWidths[c] = math.max(colWidths[c], TileWidth(row, s.labels))
        fontH = row.label:GetStringHeight() or fontH
    end
    local iconPx, tilePx = IconPx(s)
    local h
    if s.labels == "below" or s.labels == "above" then h = tilePx + 4 + fontH + 10
    elseif s.labels == "hidden" then h = tilePx + 12
    else h = math.max(ROW_H, iconPx + 8, math.ceil(fontH) + 10) end
    return colWidths, h, cols, rows
end

function BuildRows(dropdown, groupID)
    dropdown.rows = dropdown.rows or {}
    dropdown.groupID = groupID
    local items, group = MenuItems(groupID)
    if group then
        table.insert(items, 1, { back = true, name = group.name, id = "back" })
    end
    for i = 1, #items do
        PaintTile(EnsureTile(dropdown, i), items[i], dropdown)
    end
    for i = #items + 1, #dropdown.rows do
        dropdown.rows[i]:Hide()
        dropdown.rows[i].item = nil
        if dropdown.rows[i].expTag then dropdown.rows[i].expTag:Hide() end
    end


    Utils.RefreshMenuRowHighlights(dropdown, dropdown.rows)
    local widths, h, cols, rows = TileMetrics(dropdown, #items)
    for i = 1, #items do
        local row = dropdown.rows[i]
        local c, r = Cell(i, rows)
        local x = PAD
        for k = 1, c - 1 do x = x + widths[k] + GAP end
        row.index = i
        row:SetSize(widths[c], h)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", dropdown, "TOPLEFT", x, -PAD - r * (h + GAP))
    end
    local lines = math.max(1, math.min(rows, #items))
    local menuW = PAD * 2 + (cols - 1) * GAP
    for k = 1, cols do menuW = menuW + widths[k] end
    dropdown:SetSize(menuW, PAD * 2 + lines * h + (lines - 1) * GAP)
    return #items
end


function AppsMenu:Rebuild()
    local dropdown = self.dropdown
    if dropdown and dropdown:IsShown() then BuildRows(dropdown, dropdown.groupID) end
end







local function TileIDs(dropdown)
    local ids = {}
    for i = 1, #dropdown.rows do
        local item = dropdown.rows[i].item
        if item and not item.back then ids[#ids + 1] = item.id end
    end
    return ids
end

local function RemoveID(list, id)
    for i = #list, 1, -1 do if list[i] == id then tremove(list, i) end end
end

local function WriteIDs(dropdown, ids)
    local s = Settings()
    if dropdown.groupID then
        local g = GroupByID(s, dropdown.groupID)
        if g then g.apps = ids end
    else
        s.order = ids
    end
end

local function DeleteGroupIfEmpty(s, g)
    if #g.apps > 0 then return end
    for i = #s.groups, 1, -1 do if s.groups[i] == g then tremove(s.groups, i) end end
    if s.order then RemoveID(s.order, "group:" .. g.id) end
end

local function PromptGroupName(g, onDone)
    ns.ShowThemedDialog({
        text = L["EXTMENU_GROUP_NAME"], hasEditBox = true, editBoxDefault = g.name, maxLetters = 24,
        acceptText = _G["OKAY"] or "Okay", cancelText = _G["CANCEL"] or "Cancel",
        onAccept = function(value)
            value = strtrim(value or "")
            if value ~= "" then g.name = value end
            if onDone then onDone() end
        end,
    })
end


local function MakeGroup(dropdown, targetID, movedID)
    local s = Settings()
    s.groups = s.groups or {}
    local g = { id = sformat("%d.%d", time(), #s.groups + 1), name = L["EXTMENU_GROUP_DEFAULT"], apps = { targetID, movedID } }
    s.groups[#s.groups + 1] = g
    local ids = TileIDs(dropdown)
    RemoveID(ids, movedID)
    for i = 1, #ids do if ids[i] == targetID then ids[i] = "group:" .. g.id end end
    s.order = ids
    PromptGroupName(g, function() AppsMenu:Rebuild() end)
end




local function DropTarget(dropdown, x, y, from)
    local best, bestD
    local dl, db = dropdown:GetLeft(), dropdown:GetBottom()
    for i = 1, #dropdown.rows do
        local row = dropdown.rows[i]
        if row:IsShown() and row ~= from and row.item then
            local cx = row:GetLeft() - dl + row:GetWidth() / 2
            local cy = row:GetBottom() - db + row:GetHeight() / 2
            local d = (x - cx) ^ 2 + (y - cy) ^ 2
            if not bestD or d < bestD then best, bestD = row, d end
        end
    end
    if not best then return nil, nil end
    local l, b = best:GetLeft() - dl, best:GetBottom() - db
    local w, h = best:GetWidth(), best:GetHeight()
    local joins = best.item.back or (best.item.group and from.item.app)
        or (best.item.app and from.item.app and not dropdown.groupID)
    local candidate = joins and math.abs(x - (l + w / 2)) < w * 0.3 and math.abs(y - (b + h / 2)) < h * 0.3
        and best or nil
    if best.item.back then return candidate, nil end

    local after = y < b + h / 2
    return candidate, after and best.index + 1 or best.index
end

local function StopGhost(ghost)
    ghost:SetScript("OnUpdate", nil)
    ghost:Hide()
    ghost.line:Hide()
    ghost.target:Hide()
    ghost.from:SetAlpha(1)
end

local function EndArrangeDrag(dropdown)
    local ghost = dropdown.ghost
    StopGhost(ghost)
    local from = ghost.from
    local moved = from.item
    local s = Settings()
    if ghost.over then
        local t = ghost.over.item
        if t.back then

            local g = GroupByID(s, dropdown.groupID)
            if g then
                RemoveID(g.apps, moved.id)
                local top = {}
                for _, it in ipairs(MenuItems(nil)) do top[#top + 1] = it.id end
                s.order = top
                DeleteGroupIfEmpty(s, g)
                if #g.apps == 0 then dropdown.groupID = nil end
            end
        elseif t.group and moved.app then
            local ids = TileIDs(dropdown)
            RemoveID(ids, moved.id)
            s.order = ids
            t.group.apps[#t.group.apps + 1] = moved.id
        elseif t.app and moved.app then
            MakeGroup(dropdown, t.id, moved.id)
        end
    elseif ghost.slot then
        local ids = TileIDs(dropdown)
        local fromIdx
        for i = 1, #ids do if ids[i] == moved.id then fromIdx = i end end
        local to = ghost.slot - (dropdown.groupID and 1 or 0)
        if fromIdx then
            tremove(ids, fromIdx)
            if to > fromIdx then to = to - 1 end
            tinsert(ids, math.max(1, math.min(#ids + 1, to)), moved.id)
            WriteIDs(dropdown, ids)
        end
    end
    BuildRows(dropdown, dropdown.groupID)
end

function AppsMenu:BeginArrangeDrag(dropdown, row)
    local ghost = dropdown.ghost
    if not ghost then
        ghost = CreateFrame("Frame", nil, dropdown)
        ghost:SetFrameLevel(dropdown:GetFrameLevel() + 20)
        ghost:SetSize(select(2, IconPx(Settings())), select(2, IconPx(Settings())))
        ghost.icon = ghost:CreateTexture(nil, "OVERLAY")
        ghost.icon:SetAllPoints()
        ghost.line = dropdown:CreateTexture(nil, "OVERLAY")
        ghost.line:SetColorTexture(1, 0.82, 0, 0.9)
        ghost.target = dropdown:CreateTexture(nil, "ARTWORK")
        ghost.target:SetColorTexture(1, 0.82, 0, 0.22)
        dropdown.ghost = ghost
    end
    local tex, coords
    if row.item.group then tex = ns.EXTENSIONS_ICON_TEX else tex, coords = AppGlyph(row.item.app) end
    ghost.icon:SetTexture(tex or ns.EXTENSIONS_ICON_TEX)
    ghost.icon:SetTexCoord(unpack(coords or { 0, 1, 0, 1 }))
    ns.PaintAppGlyph(ghost.icon)
    ghost.from = row
    ghost.resting, ghost.restSince = nil, nil
    row:SetAlpha(0.35)
    ghost:Show()
    ghost:SetScript("OnUpdate", function(self)
        local cx, cy = GetCursorPosition()
        local scale = dropdown:GetEffectiveScale()
        local x, y = cx / scale - dropdown:GetLeft(), cy / scale - dropdown:GetBottom()
        local outside = x < -8 or y < -8 or x > dropdown:GetWidth() + 8 or y > dropdown:GetHeight() + 8


        if outside and row.item.app and ns.ExtensionButtons then
            StopGhost(self)
            dropdown:Hide()
            ns.ExtensionButtons:BeginDragFromMenu(row.item.app)
            return
        end
        self:ClearAllPoints()
        self:SetPoint("CENTER", dropdown, "BOTTOMLEFT", x, y)
        local candidate, slot = nil, nil
        if not outside then candidate, slot = DropTarget(dropdown, x, y, row) end

        if candidate ~= self.resting then
            self.resting, self.restSince = candidate, GetTime()
        end
        local over = candidate and GetTime() - self.restSince >= GROUP_HOLD and candidate or nil
        if over then slot = nil end
        self.over, self.slot = over, slot
        self.target:SetShown(over ~= nil)
        if over then
            self.target:ClearAllPoints()
            self.target:SetAllPoints(over)
        end
        local at = slot and dropdown.rows[slot]
        local last = slot and not at and dropdown.rows[slot - 1]
        local beside = at or last
        self.line:SetShown(beside ~= nil)
        if beside then
            self.line:ClearAllPoints()
            self.line:SetSize(beside:GetWidth(), 2)
            if at then self.line:SetPoint("BOTTOM", at, "TOP", 0, 1)
            else self.line:SetPoint("TOP", last, "BOTTOM", 0, -1) end
        end
        if not IsMouseButtonDown("LeftButton") then EndArrangeDrag(dropdown) end
    end)
end



function AppsMenu:ShowTileMenu(row)
    local dropdown, item = self.dropdown, row.item
    if item.app then
        if ns.ExtensionButtons then ns.ExtensionButtons:ShowAppMenu(row, item.app, true) end
        return
    end
    local g = item.group
    local s = Settings()
    Utils.ShowCursorMenu("EasyFindAppsTileMenu", {
        { text = L["EXTMENU_RENAME"], onClick = function() PromptGroupName(g, function() AppsMenu:Rebuild() end) end },
        { text = L["EXTMENU_UNGROUP"], onClick = function()
            local ids = s.order or TileIDs(dropdown)
            local at = #ids + 1
            for i = 1, #ids do if ids[i] == "group:" .. g.id then at = i end end
            RemoveID(ids, "group:" .. g.id)
            for k = #g.apps, 1, -1 do tinsert(ids, at, g.apps[k]) end
            s.order = ids
            g.apps = {}
            DeleteGroupIfEmpty(s, g)
            AppsMenu:Rebuild()
        end },
    }, {})
end

function AppsMenu:Create(searchFrame, filterBtn)
    if self.button then return self.button end





    local apps = ns.BuildApplicationEntries and ns.BuildApplicationEntries() or {}
    if #apps == 0 then return nil end

    local btn = CreateFrame("Button", "EasyFindUIAppsButton", searchFrame)
    btn:SetPoint("TOP", searchFrame, "TOP", 0, 0)
    btn:SetPoint("BOTTOM", searchFrame, "BOTTOM", 0, 0)






    btn:SetPoint("RIGHT", filterBtn, "LEFT", 4, 0)
    btn:SetWidth(searchFrame:GetHeight() - 6)
    btn:SetFrameLevel(searchFrame:GetFrameLevel() + 50)

    local glyph = CreateGridGlyph(btn, 16)
    glyph:SetPoint("CENTER")
    btn.glyph = glyph
    btn:SetHighlightTexture(130757)





    if searchFrame.editBox then
        searchFrame.editBox:SetPoint("RIGHT", btn, "LEFT", -4, 0)
    end


    local dropdown = CreateFrame("Frame", "EasyFindUIAppsDropdown", UIParent, "BackdropTemplate")
    dropdown:SetFrameStrata("DIALOG")


    dropdown:SetFrameLevel(9000)

    dropdown:SetClampedToScreen(true)
    dropdown:EnableMouse(true)
    dropdown:Hide()
    ns.StyleMenuPanel(dropdown)







    dropdown:HookScript("OnShow", function(self)
        self:RegisterEvent("GLOBAL_MOUSE_DOWN")
    end)
    dropdown:HookScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    end)


    dropdown:SetScript("OnEvent", function(self, event)
        if event ~= "GLOBAL_MOUSE_DOWN" then return end
        if Utils.IsFrameVisiblyMouseOver(self) or Utils.IsFrameVisiblyMouseOver(btn) then return end
        local surface = ns.OptionsSurface
        if surface and surface:IsOptionsSurfaceMouseOver() then return end
        if Utils.IsCursorMenuMouseOver() then return end
        self:Hide()
    end)







    local appsFocus = 0
    local function SetAppsFocus(idx)
        local rows = dropdown.rows or {}
        local prev = rows[appsFocus]
        if prev and prev.SetMenuHighlightFocused then prev:SetMenuHighlightFocused(false) end
        appsFocus = idx
        local target = rows[idx]
        if target and target.SetMenuHighlightFocused then target:SetMenuHighlightFocused(true) end
    end
    local function VisibleAppRows()
        local rows = dropdown.rows or {}
        local n = 0
        for i = 1, #rows do
            if rows[i]:IsShown() then n = n + 1 end
        end
        return n
    end
    Utils.SafeCallMethod(dropdown, "EnableKeyboard", false)
    Utils.SafeCallMethod(dropdown, "SetPropagateKeyboardInput", false)
    dropdown:SetScript("OnKeyDown", function(self, key)
        Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
        local count = VisibleAppRows()
        if (key == "DOWN" or key == "TAB") and count > 0 then
            SetAppsFocus(appsFocus % count + 1)
        elseif key == "UP" and count > 0 then
            SetAppsFocus((appsFocus - 2) % count + 1)
        elseif key == "ENTER" then
            local row = dropdown.rows and dropdown.rows[appsFocus]
            if row then row:Click() end
        elseif key == "ESCAPE" or key == "LEFT" then
            self:Hide()
        else
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", true)
        end
    end)
    dropdown:HookScript("OnHide", function(self)
        SetAppsFocus(0)
        Utils.SafeCallMethod(self, "EnableKeyboard", false)
        local nav = ns.Search and ns.Search.GetNavFrame and ns.Search:GetNavFrame()
        if nav and btn.keyboardFocused then
            Utils.SafeCallMethod(nav, "EnableKeyboard", true)
        end
    end)

    btn:SetScript("OnClick", function()
        if dropdown:IsShown() then
            dropdown:Hide()
            return
        end


        if BuildRows(dropdown) == 0 then return end



        local barScale = EasyFind.db.uiSearchScale or 1.0
        dropdown:SetScale(barScale)
        local scale = searchFrame:GetEffectiveScale() / (UIParent:GetEffectiveScale() * barScale)
        local left = btn:GetLeft() * scale

        local room = UIParent:GetWidth() / barScale
        if left + dropdown:GetWidth() > room then left = math.max(0, room - dropdown:GetWidth()) end
        dropdown:ClearAllPoints()
        if EasyFind.db.uiResultsAbove then
            dropdown:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, searchFrame:GetTop() * scale)
        else
            dropdown:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, searchFrame:GetBottom() * scale)
        end
        dropdown:Show()


        if btn.keyboardFocused then
            local nav = ns.Search and ns.Search.GetNavFrame and ns.Search:GetNavFrame()
            if nav then Utils.SafeCallMethod(nav, "EnableKeyboard", false) end
            Utils.SafeCallMethod(dropdown, "EnableKeyboard", true)
            SetAppsFocus(1)
        end
    end)




    dropdown:HookScript("OnHide", function(self)
        self.groupID = nil
    end)
    dropdown:HookScript("OnShow", function() btn:LockHighlight() end)
    dropdown:HookScript("OnHide", function()




        if not btn.keyboardFocused then btn:UnlockHighlight() end
    end)



    Utils.InstallBarControlReveal(btn,
        function() return EasyFind.db.showAppsButton ~= false end,
        function() return dropdown:IsShown() end)
    dropdown:HookScript("OnShow", btn.RefreshReveal)
    dropdown:HookScript("OnHide", btn.RefreshReveal)

    self.button = btn
    self.dropdown = dropdown
    searchFrame.appsBtn = btn
    searchFrame.appsDropdown = dropdown



    if Results.CloseFilterDropdownIfOpen then
        btn:HookScript("OnClick", function()
            if dropdown:IsShown() then Results:CloseFilterDropdownIfOpen() end
        end)
    end
    return btn
end
