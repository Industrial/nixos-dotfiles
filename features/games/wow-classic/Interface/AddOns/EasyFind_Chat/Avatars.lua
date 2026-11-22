local _, chatNS = ...

local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not (ns and ns.Utils) or chatNS.tooOld then return end

-- A chat's own picture in place of its letter: a class circle or any macro
-- icon, picked from a grid. Kept on the conversation as convo.icon: a
-- FileDataID, an icon path, or "class:MAGE".
local Avatars = {}
chatNS.Avatars = Avatars

local UI = chatNS.UI
local Utils = ns.Utils
local CreateFrame = CreateFrame
local wipe = wipe
local tonumber = tonumber
local strtrim = strtrim
local sfind, slower = Utils.sfind, Utils.slower
local mmax, mmin = Utils.mmax, Utils.mmin
local mfloor, mceil = math.floor, math.ceil

local CLASS_SHEET = "Interface\\TargetingFrame\\UI-Classes-Circles"
-- An icon's outer rim is dark: cut off inside the circle.
local ICON_CROP = 0.08
local COLS, ROWS, CELL, GAP, PAD = 9, 7, 32, 4, 10
local STEP = CELL + GAP
local GRID_W, GRID_H = COLS * STEP - GAP, ROWS * STEP - GAP
local BAR_ROOM = 10
local TITLE_H, FIELD_H, BUTTON_H, SPACE = 18, 22, 22, 8

local function ClassOf(icon)
    return type(icon) == "string" and icon:match("^class:(%u+)$") or nil
end

-- False for a class this client has no circle for.
local function SetIcon(tex, icon)
    local class = ClassOf(icon)
    if class then
        local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
        if not coords then return false end
        tex:SetTexture(CLASS_SHEET)
        tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        return true
    end
    tex:SetTexture(icon)
    tex:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    return true
end

-- A person's icon is theirs, not the chat's: kept by who they are (the
-- realm-qualified name, a Battle.net friend's BattleTag), so a chat deleted
-- and begun again wears it still. Channels keep theirs on the chat.
local function PersonKey(convo)
    if not convo then return nil end
    if convo.kind == "player" then return convo.key end
    if convo.kind == "bn" and type(convo.battleTag) == "string" and convo.battleTag ~= "" then
        return "bn:" .. slower(convo.battleTag)
    end
    return nil
end

local function KeptIcons()
    local db = type(EasyFindChatDB) == "table" and EasyFindChatDB
    if not db then return nil end
    if type(db.personIcons) ~= "table" then
        db.personIcons = {}
        -- Once: the icons chats carried before move to their people.
        for _, convo in pairs(UI:GetChatConversationStore().byKey) do
            local key = PersonKey(convo)
            if key and convo.icon and db.personIcons[key] == nil then db.personIcons[key] = convo.icon end
        end
    end
    return db.personIcons
end

-- The macro icons, gathered only to draw a chat's random one and let go.
local macroPool
local function MacroPool()
    if macroPool then return macroPool end
    local raw, seen = {}, {}
    if GetMacroIcons then GetMacroIcons(raw) end
    if GetMacroItemIcons then GetMacroItemIcons(raw) end
    macroPool = {}
    for i = 1, #raw do
        local icon = tonumber(raw[i]) or ("Interface\\Icons\\" .. raw[i])
        if not seen[icon] then
            seen[icon] = true
            macroPool[#macroPool + 1] = icon
        end
    end
    C_Timer.After(5, function() macroPool = nil end)
    return macroPool
end

-- A chat's random icon, drawn once and kept, so it stays its own.
local function RandomIcon(db, key)
    db.drawnIcons = type(db.drawnIcons) == "table" and db.drawnIcons or {}
    local icon = db.drawnIcons[key]
    if icon then return icon end
    local pool = MacroPool()
    if #pool == 0 then return nil end
    icon = pool[math.random(#pool)]
    db.drawnIcons[key] = icon
    return icon
end

-- None picked (Extensions > Chat, both off by default): a player's class
-- circle, else a random macro icon for a chat of its own (a speaker in a
-- channel with no chat keeps the letter).
local function AutoIcon(convo)
    local db = type(EasyFindChatDB) == "table" and EasyFindChatDB
    if not db then return nil end
    if db.classIcons and convo.kind == "player" and type(convo.class) == "string"
        and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[convo.class] then
        return "class:" .. convo.class
    end
    local kind = convo.kind
    if db.randomIcons and not convo.speaker and (kind == "player" or kind == "bn" or kind == "channel") then
        local key = PersonKey(convo) or convo.key
        return key and RandomIcon(db, key) or nil
    end
    return nil
end

local function IconOf(convo)
    if not convo then return nil end
    -- First: the old chats' icons are moved before any chat can go.
    local kept = KeptIcons()
    if convo.icon then return convo.icon end
    local key = PersonKey(convo)
    return key and kept and kept[key] or AutoIcon(convo)
end
Avatars.IconOf = IconOf

-- A folder's avatar: its newest chats' circles inside its own, as a phone
-- draws a group chat. Each is that chat's avatar, its icon or its color,
-- with its letter where the circle has room for one. Placed as
-- { x, y, diameter } in parts of the folder's circle.
local CLUSTER = {
    { { 0.50, 0.50, 0.62 } },
    { { 0.38, 0.38, 0.52 }, { 0.68, 0.68, 0.44 } },
    { { 0.40, 0.36, 0.50 }, { 0.76, 0.60, 0.38 }, { 0.42, 0.77, 0.34 } },
}
local LETTER_ROOM = 12

local function MaskedTexture(bg, sublevel)
    local tex = bg:CreateTexture(nil, "ARTWORK", nil, sublevel)
    local mask = bg:CreateMaskTexture()
    mask:SetTexture(ns.PORTRAIT_ALPHA_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
    return tex
end

local function ClusterCircle(bg, i)
    bg._chatCluster = bg._chatCluster or {}
    local c = bg._chatCluster[i]
    if c then return c end
    -- Each later circle draws over the one before, its ring first.
    c = { ring = MaskedTexture(bg, i * 2 - 2), fill = MaskedTexture(bg, i * 2 - 1),
          icon = MaskedTexture(bg, i * 2 - 1), letter = bg:CreateFontString(nil, "OVERLAY") }
    c.letter:SetDrawLayer("OVERLAY", i)
    bg._chatCluster[i] = c
    return c
end

local function HideCluster(bg)
    local pool = bg._chatCluster
    for i = 1, pool and #pool or 0 do
        local c = pool[i]
        c.ring:Hide()
        c.fill:Hide()
        c.icon:Hide()
        c.letter:Hide()
    end
end

local function PlaceCircle(tex, bg, x, y, d)
    tex:ClearAllPoints()
    tex:SetSize(d, d)
    tex:SetPoint("CENTER", bg, "TOPLEFT", x, y)
end

-- members: up to three { convo, initial, r, g, b }; ringR, ringG, ringB the
-- folder's own fill, a thin edge between circles that touch.
function Avatars:PaintCluster(bg, letter, members, ringR, ringG, ringB)
    HideCluster(bg)
    local n = mmin(#members, #CLUSTER)
    if n == 0 then return end
    local size = bg:GetWidth() or 24
    local font = letter:GetFont()
    local lr, lg, lb = letter:GetTextColor()
    for i = 1, n do
        local m, spot, c = members[i], CLUSTER[n][i], ClusterCircle(bg, i)
        local d = size * spot[3]
        local x, y = size * spot[1], -size * spot[2]
        PlaceCircle(c.ring, bg, x, y, d + 2)
        c.ring:SetColorTexture(ringR, ringG, ringB, 1)
        c.ring:Show()
        local icon = IconOf(m.convo)
        local shown = icon and SetIcon(c.icon, icon) or false
        PlaceCircle(c.icon, bg, x, y, d)
        c.icon:SetShown(shown)
        PlaceCircle(c.fill, bg, x, y, d)
        c.fill:SetColorTexture(m.r, m.g, m.b, 1)
        c.fill:SetShown(not shown)
        local room = not shown and font and d >= LETTER_ROOM
        if room then
            c.letter:SetFont(font, mfloor(d * 0.58), "")
            c.letter:SetTextColor(lr, lg, lb)
            c.letter:SetText(m.initial or "")
            c.letter:ClearAllPoints()
            c.letter:SetPoint("CENTER", bg, "TOPLEFT", x, y)
        end
        c.letter:SetShown(room and true or false)
    end
    letter:Hide()
end

-- The chat's icon over its avatar circle, else its letter.
function Avatars:Paint(bg, letter, convo)
    HideCluster(bg)
    local icon = IconOf(convo)
    local tex = bg._chatIcon
    if icon and not tex then
        tex = bg:CreateTexture(nil, "ARTWORK", nil, 7)
        tex:SetAllPoints(bg)
        local mask = bg:CreateMaskTexture()
        mask:SetTexture(ns.PORTRAIT_ALPHA_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(tex)
        tex:AddMaskTexture(mask)
        bg._chatIcon = tex
    end
    local shown = icon and SetIcon(tex, icon) or false
    if tex then tex:SetShown(shown) end
    letter:SetShown(not shown)
end

-- The client's playable classes, as (file, name) pairs.
local classes
local function Classes()
    if classes then return classes end
    classes = {}
    local n = GetNumClasses and GetNumClasses() or 0
    for id = 1, n do
        local name, file = GetClassInfo(id)
        if file and name and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[file] then
            classes[#classes + 1] = { file = file, name = name }
        end
    end
    return classes
end

local picker, cells, scroll, child, bar, searchBox, placeholder, removeButton
-- The grid's icons and their hover names (class names, search hits).
local list, names, hits = {}, {}, {}
local offset = 0
local pickKey
-- The avatar the picker opened from: its own press toggles.
local anchorRegion

local function Convo()
    local store = pickKey and UI:GetChatConversationStore()
    local views = chatNS.Views
    return store and (store.byKey[pickKey] or (views and views:Get(pickKey))) or nil
end

local function TotalRows() return mceil(#list / COLS) end

local function Repaint()
    local convo = Convo()
    local current = IconOf(convo)
    for i = 1, #cells do
        local cell = cells[i]
        local index = offset * COLS + i
        local icon = list[index]
        cell.index = index
        if icon and SetIcon(cell.tex, icon) then
            cell.picked:SetShown(icon == current)
            cell:Show()
        else
            cell:Hide()
        end
    end
    removeButton:SetEnabled(current ~= nil)
    removeButton:SetAlpha(current ~= nil and 1 or 0.45)
end

local function SetRange()
    local contentH = TotalRows() * STEP
    child:SetHeight(mmax(1, contentH))
    scroll:SetVerticalScroll(0)
    offset = 0
    if TotalRows() > ROWS then
        bar:Show()
        bar:UpdateThumb(contentH, GRID_H)
    else
        bar:Hide()
    end
end

local function AddIcon(icon, name)
    list[#list + 1] = icon
    if name then names[#list] = name end
end

-- No query: the class circles, then the macro picker's icons. A query
-- matches class names, and icon names once the icons extension loads.
local function Fill(query)
    wipe(list)
    wipe(names)
    query = slower(strtrim(query or ""))
    local classList = Classes()
    for i = 1, #classList do
        local c = classList[i]
        if query == "" or sfind(slower(c.name), query, 1, true) then AddIcon("class:" .. c.file, c.name) end
    end
    if query == "" then
        local raw, seen = {}, {}
        if GetMacroIcons then GetMacroIcons(raw) end
        if GetMacroItemIcons then GetMacroItemIcons(raw) end
        for i = 1, #raw do
            local v = raw[i]
            local icon = tonumber(v) or ("Interface\\Icons\\" .. v)
            if not seen[icon] then
                seen[icon] = true
                AddIcon(icon)
            end
        end
    elseif ns.RequestIconSearch and ns.RequestIconSearch() and ns.IconSearch then
        local n = ns.IconSearch:Filter(query, hits)
        for i = 1, n do
            local name, fdid = ns.IconSearch:GetIcon(hits[i])
            if fdid then AddIcon(fdid, name) end
        end
        wipe(hits)
    end
    SetRange()
    Repaint()
end

local function Pick(icon)
    local convo = Convo()
    if convo then
        convo.icon = icon
        local key, kept = PersonKey(convo), KeptIcons()
        if key and kept then kept[key] = icon end
        -- All, System and Combat Log keep theirs apart from the chats.
        local views = chatNS.Views
        if views and views:IsView(pickKey) then views:SetIcon(pickKey, icon) end
        UI:RefreshChatMessenger()
    end
    picker:Hide()
end

local function OnCellEnter(cell)
    local name = names[cell.index]
    if name then ns.ShowHintTooltip(cell, "ANCHOR_RIGHT", name) end
end

local function OnCellLeave(cell) ns.HideHintTooltip(cell) end

local function OnCellClick(cell)
    local icon = list[cell.index]
    if icon then Pick(icon) end
end

local function OnCellWheel(_, delta) bar:ScrollByDelta(delta) end

local function Build(host)
    picker = CreateFrame("Frame", "EasyFindChatIconPicker", host)
    -- Built hidden: a new frame starts shown.
    picker:Hide()
    picker:SetFrameStrata("DIALOG")
    picker:SetToplevel(true)
    picker:EnableMouse(true)
    picker:SetClampedToScreen(true)
    picker:SetSize(PAD + GRID_W + BAR_ROOM + PAD,
        PAD + TITLE_H + SPACE + FIELD_H + SPACE + GRID_H + SPACE + BUTTON_H + PAD)
    ns.StyleMenuPanel(picker)

    local title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetHeight(TITLE_H)
    title:SetText("Chat icon")
    local close = ns.CreateCloseX(picker, 16)
    close:SetPoint("TOPRIGHT", -PAD + 2, -PAD + 1)
    close:SetScript("OnClick", function() picker:Hide() end)
    title:SetPoint("RIGHT", close, "LEFT", -6, 0)
    title:SetJustifyH("LEFT")

    local shell = CreateFrame("Frame", nil, picker)
    shell:SetPoint("TOPLEFT", PAD, -(PAD + TITLE_H + SPACE))
    shell:SetPoint("RIGHT", -PAD, 0)
    shell:SetHeight(FIELD_H)
    UI:StyleChatComposerInputSurface(shell, 7, 0.96)
    shell:EnableMouse(true)
    placeholder = shell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 9, 0)
    placeholder:SetPoint("RIGHT", -9, 0)
    placeholder:SetJustifyH("LEFT")
    placeholder:SetText("Search icons")
    searchBox = CreateFrame("EditBox", nil, shell)
    searchBox:SetPoint("LEFT", 9, 0)
    searchBox:SetPoint("RIGHT", -9, 0)
    searchBox:SetHeight(18)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject(GameFontHighlightSmall)
    local themed = chatNS.RegisterThemedText
    if themed then
        themed(title)
        themed(placeholder, 0.5)
        themed(searchBox)
    end
    shell:SetScript("OnMouseDown", function() searchBox:SetFocus() end)
    searchBox:SetScript("OnTextChanged", function(self, userInput)
        placeholder:SetShown((self:GetText() or "") == "")
        if userInput then Fill(self:GetText()) end
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    Utils.ReleaseFocusOnOutsideClick(searchBox)

    scroll = CreateFrame("ScrollFrame", nil, picker)
    scroll:SetPoint("TOPLEFT", shell, "BOTTOMLEFT", 0, -SPACE)
    scroll:SetSize(GRID_W + BAR_ROOM, GRID_H)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    bar = Utils.CreateMinimalScrollBar(scroll, picker)
    -- The bar sets the scroll script; the grid follows it in whole rows.
    scroll:HookScript("OnVerticalScroll", function()
        local rows = mmax(0, TotalRows() - ROWS)
        local row = mmin(rows, mmax(0, mfloor(scroll:GetVerticalScroll() / STEP + 0.5)))
        if row ~= offset then
            offset = row
            Repaint()
        end
    end)

    cells = {}
    for i = 1, COLS * ROWS do
        local cell = CreateFrame("Button", nil, picker)
        cell:SetSize(CELL, CELL)
        local col, row = (i - 1) % COLS, mfloor((i - 1) / COLS)
        cell:SetPoint("TOPLEFT", scroll, "TOPLEFT", col * STEP, -row * STEP)
        cell:SetFrameLevel(scroll:GetFrameLevel() + 2)
        cell.picked = cell:CreateTexture(nil, "BACKGROUND")
        cell.picked:SetPoint("TOPLEFT", -2, 2)
        cell.picked:SetPoint("BOTTOMRIGHT", 2, -2)
        cell.picked:SetColorTexture(1, 0.82, 0.2, 0.9)
        cell.tex = cell:CreateTexture(nil, "ARTWORK")
        cell.tex:SetAllPoints()
        cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        cell:SetScript("OnEnter", OnCellEnter)
        cell:SetScript("OnLeave", OnCellLeave)
        cell:SetScript("OnClick", OnCellClick)
        cell:EnableMouseWheel(true)
        cell:SetScript("OnMouseWheel", OnCellWheel)
        cells[i] = cell
    end

    removeButton = ns.CreateModernButton(picker, "", 120, BUTTON_H)
    removeButton:SetText("Use the letter")
    removeButton:SetWidth(mceil(removeButton._label:GetUnboundedStringWidth()) + 24)
    removeButton:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    removeButton:SetScript("OnClick", function() Pick(nil) end)

    Utils.RegisterClickGuard(picker)
    picker:SetScript("OnEvent", function(self, event)
        if event ~= "GLOBAL_MOUSE_DOWN" then return end
        if self:IsMouseOver() or (anchorRegion and anchorRegion:IsMouseOver()) then return end
        self:Hide()
    end)
    picker:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    -- Fresh tables, not wiped: thousands of icons leave their room behind.
    picker:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        searchBox:ClearFocus()
        list, names, hits = {}, {}, {}
        pickKey, anchorRegion = nil, nil
        local iconsShown = ns.Results and ns.Results.IsIconGridShown and ns.Results:IsIconGridShown()
        if ns.IconSearch and ns.IconSearch.ReleaseMemory and not iconsShown then ns.IconSearch:ReleaseMemory() end
    end)
    -- After its own scripts: SetScript drops the hooks this adds.
    Utils.AttachEscClose(picker)
end

-- Opens the grid beside the chat window for one chat; the same avatar
-- pressed again closes it.
function Avatars:OpenPicker(key, anchor)
    local host = UI._chatComposer and UI._chatComposer.frame
    if not (key and host) then return end
    if picker and picker:IsShown() and pickKey == key then
        picker:Hide()
        return
    end
    if not picker then Build(host) end
    picker:Hide()
    pickKey, anchorRegion = key, anchor
    picker:ClearAllPoints()
    picker:SetPoint("TOPLEFT", host, "TOPRIGHT", 6, 0)
    searchBox:SetText("")
    placeholder:Show()
    picker:Show()
    Fill("")
end

function Avatars:IsPickerFor(key)
    return picker ~= nil and picker:IsShown() and pickKey == key
end
