-- The journal's size and scale.
-- Rescale (the grip in the bottom-right corner): drag to scale the whole
-- window, right-click to reset. The scale is saved between sessions.
-- resizemode (2.0.10, M 17 Nov 2026: "put the scale back and add resize as an
-- option in the option panel under General called Resize; when clicked it
-- opens the journal and lets the user pull the 4 corners and resize as he
-- pleases; a little popup in our usual style pointing at the corners: Drag
-- the corners to resize"): Options > General > Resize opens the journal with
-- a handle on its corners (not the top right, where the close button is).
-- Dragging one makes the window itself bigger (more room for bosses, loot,
-- cards and maps; not smaller than the normal 850 x 590, not past the
-- screen); right-click on a handle resets the size. A note at each corner
-- (black box, yellow arrow pointing into it, OK; it bounces and flashes)
-- says so; OK closes the notes, the corners stay draggable until the
-- journal is closed, then the corner grip is Rescale again. The size is
-- saved between sessions.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local MIN_SCALE, MAX_SCALE = 0.6, 1.6
local BASE_W, BASE_H = 850, 590
local ARROW = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\QuestNextArrow"
local GRABBER = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-"

local function L(key, ...)
    if FDJ.L then return FDJ.L(key, ...) end
    return key
end

local function Clamp(v)
    if v < MIN_SCALE then return MIN_SCALE end
    if v > MAX_SCALE then return MAX_SCALE end
    return v
end

-- Popups that are not children of the journal (the Favourites window lives on
-- UIParent so it can stay open on its own) follow the journal's size here.
function FDJ.SyncPopupScale()
    local frame = _G.ForeverDungeonJournalFrame
    local fav = _G.ForeverDungeonJournalFavourites
    if frame and fav and fav.SetScale then fav:SetScale(frame:GetScale() or 1) end
end

function FDJ.SetJournalScale(scale)
    local frame = _G.ForeverDungeonJournalFrame
    if not frame then return end
    scale = Clamp(tonumber(scale) or 1)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    ForeverDungeonJournalDB.scale = scale
    frame:SetScale(scale)
    FDJ.SyncPopupScale()
    return scale
end

-- ------------------------------------------------------------------ size
-- The biggest the window can be: the screen, in the window's own units.
local function MaxSize(frame)
    local s = frame:GetScale() or 1
    local w = (UIParent and UIParent:GetWidth() or 1920) / s
    local h = (UIParent and UIParent:GetHeight() or 1080) / s
    return math.max(BASE_W, math.floor(w)), math.max(BASE_H, math.floor(h))
end

local function ClampSize(frame, w, h)
    local maxW, maxH = MaxSize(frame)
    w = math.max(BASE_W, math.min(maxW, math.floor(tonumber(w) or BASE_W)))
    h = math.max(BASE_H, math.min(maxH, math.floor(tonumber(h) or BASE_H)))
    return w, h
end

local function SetBounds(frame)
    local maxW, maxH = MaxSize(frame)
    -- nojump: never below the size it has now (a window made big and then
    -- Rescaled up would otherwise snap smaller the moment a corner is held)
    maxW = math.max(maxW, math.ceil(frame:GetWidth() or 0))
    maxH = math.max(maxH, math.ceil(frame:GetHeight() or 0))
    if frame.SetResizeBounds then
        frame:SetResizeBounds(BASE_W, BASE_H, maxW, maxH)
    else
        if frame.SetMinResize then frame:SetMinResize(BASE_W, BASE_H) end
        if frame.SetMaxResize then frame:SetMaxResize(maxW, maxH) end
    end
end

-- nojump (M 17 Nov 2026: "sometimes when I click on the corner the window
-- jumps like crazy before me dragging"): the window is normally held by its
-- centre (or wherever it was last dragged to), so taking a corner made it
-- grow from that point and leap. Before a corner is taken, the window is
-- pinned at the opposite corner, where it is on screen now; then only the
-- corner being dragged moves.
local OPPOSITE_CORNER = { TOPLEFT = "BOTTOMRIGHT", TOPRIGHT = "BOTTOMLEFT", BOTTOMLEFT = "TOPRIGHT", BOTTOMRIGHT = "TOPLEFT" }
local function PinOpposite(frame, point)
    local fixed = OPPOSITE_CORNER[point]
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not (fixed and left and right and top and bottom) then return end
    local x = fixed:find("LEFT") and left or right
    local y = fixed:find("TOP") and top or bottom
    frame:ClearAllPoints()
    frame:SetPoint(fixed, UIParent, "BOTTOMLEFT", x, y)
end

-- smoothsize (M 17 Nov 2026: "I still got jumpy window when clicking the
-- corners to resize"): the game's own corner dragging (StartSizing) could
-- still make the window leap the moment a corner was taken (a rescaled
-- window above all). The journal sizes itself now: the window grows or
-- shrinks by exactly how far the mouse has moved since the corner was
-- taken, the opposite corner stays where it is, and the dragged corner
-- stops at the screen's edge. Dragging the window itself is off meanwhile.
local function CursorIn(frame)
    local x, y = GetCursorPosition()
    local s = frame:GetEffectiveScale() or 1
    if s <= 0 then s = 1 end
    return x / s, y / s
end

local function BeginSizing(frame, handle, point)
    PinOpposite(frame, point)
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not (left and right and top and bottom) then return end
    handle.startX, handle.startY = CursorIn(frame)
    handle.startW, handle.startH = frame:GetWidth(), frame:GetHeight()
    local ratio = (UIParent:GetEffectiveScale() or 1) / (frame:GetEffectiveScale() or 1)
    local screenW = (UIParent:GetWidth() or 1920) * ratio
    local screenH = (UIParent:GetHeight() or 1080) * ratio
    local maxW = point:find("RIGHT") and (screenW - left) or right
    local maxH = point:find("TOP") and (screenH - bottom) or top
    handle.maxW = math.max(handle.startW, math.floor(maxW))
    handle.maxH = math.max(handle.startH, math.floor(maxH))
    handle.point = point
    FDJ.journalSizing = true
    handle.dragging = true
end

local function UpdateSizing(frame, handle)
    local x, y = CursorIn(frame)
    local dx, dy = x - handle.startX, y - handle.startY
    local w = handle.startW + (handle.point:find("RIGHT") and dx or -dx)
    local h = handle.startH + (handle.point:find("TOP") and dy or -dy)
    w = math.max(BASE_W, math.min(handle.maxW, w))
    h = math.max(BASE_H, math.min(handle.maxH, h))
    if math.abs(w - (frame:GetWidth() or 0)) >= 0.5 or math.abs(h - (frame:GetHeight() or 0)) >= 0.5 then
        frame:SetSize(w, h)
    end
end

-- Done resizing: keep the size and lay the shown page out for it.
local function FinishSizing(frame)
    FDJ.journalSizing = false
    frame:StopMovingOrSizing()
    local w, h = ClampSize(frame, frame:GetWidth(), frame:GetHeight())
    frame:SetSize(w, h)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    if w == BASE_W and h == BASE_H then
        ForeverDungeonJournalDB.journalSize = nil
    else
        ForeverDungeonJournalDB.journalSize = { w, h }
    end
    if FDJ.RelayoutForSize then pcall(FDJ.RelayoutForSize) end
end

local function ResetSize(frame)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    ForeverDungeonJournalDB.journalSize = nil
    frame:SetSize(BASE_W, BASE_H)
    if FDJ.RelayoutForSize then pcall(FDJ.RelayoutForSize) end
end

-- resetsize (M 17 Nov 2026: Options > General > Reset Size): the journal
-- back to its normal size and scale.
function FDJ.ResetJournalSize()
    local frame = _G.ForeverDungeonJournalFrame
    if not frame then return end
    if FDJ.journalSizing then FinishSizing(frame) end
    FDJ.SetJournalScale(1)
    ResetSize(frame)
end

-- ------------------------------------------------------- resize mode
-- The corners that can be dragged (not the top right: the close button is
-- there; M 17 Nov 2026, "useless"). coords: turn the bottom-right grabber
-- to face the corner; turn: the arrow's (radians, counter-clockwise from
-- pointing right); dx, dy: from the corner into the window; left: the note's
-- arrow is on its left (else its right).
local CORNERS = {
    { point = "TOPLEFT",     coords = { 1, 0, 1, 0 }, turn = 3 * math.pi / 4,  dx = 1,  dy = -1, left = true },
    { point = "BOTTOMLEFT",  coords = { 1, 0, 0, 1 }, turn = -3 * math.pi / 4, dx = 1,  dy = 1,  left = true },
    { point = "BOTTOMRIGHT", coords = { 0, 1, 0, 1 }, turn = -math.pi / 4,     dx = -1, dy = 1,  left = false },
}
local OPPOSITE = { TOPLEFT = "BOTTOMRIGHT", BOTTOMLEFT = "TOPRIGHT", BOTTOMRIGHT = "TOPLEFT" }

local handles, notes

local function SetGrabberArt(tex, part, c)
    tex:SetTexture(GRABBER .. part)
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
    tex:SetAllPoints()
end

function FDJ.HideResizeNotes()
    for _, n in ipairs(notes or {}) do n:Hide() end
end

function FDJ.StopResizeMode()
    local frame = _G.ForeverDungeonJournalFrame
    if frame and FDJ.journalSizing then FinishSizing(frame) end
    for _, h in ipairs(handles or {}) do h.dragging = false; h:Hide() end
    for _, n in ipairs(notes or {}) do n:Hide() end
    if frame and frame.resizeGrip then frame.resizeGrip:Show() end
    FDJ.resizeMode = nil
end

-- A note in the journal's usual note style (the tracker's: black box, grey
-- edge, white text, yellow arrow, OK), set at a corner, its arrow pointing
-- into that corner.
local function MakeNote(frame, handle, c, level)
    local n = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    n:SetFrameLevel(level + 2)
    n:EnableMouse(true)
    n:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    n:SetBackdropColor(0, 0, 0, 1)
    n:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    n.arrow = n:CreateTexture(nil, "OVERLAY")
    n.arrow:SetTexture(ARROW)
    n.arrow:SetSize(20, 20)
    if n.arrow.SetRotation then n.arrow:SetRotation(c.turn) end
    n.text = n:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    n.text:SetTextColor(1, 1, 1)
    n.text:SetShadowColor(0, 0, 0, 1)
    n.text:SetShadowOffset(1, -1)
    n.ok = CreateFrame("Button", nil, n, "UIPanelButtonTemplate")
    if FDJ.OwnFonts then FDJ.OwnFonts(n.ok) end
    n.ok:SetSize(40, 18)
    n.ok:SetNormalFontObject("ForeverDJ_GameFontNormalSmall")
    n.ok:SetHighlightFontObject("ForeverDJ_GameFontHighlightSmall")
    n.ok:SetText(OKAY or "OK")
    -- OK closes the notes only: the corners stay draggable until the
    -- journal is closed (M 17 Nov 2026)
    n.ok:SetScript("OnClick", function() FDJ.HideResizeNotes() end)
    if c.left then -- [arrow] text [OK]
        n.text:SetPoint("LEFT", 30, 0)
        n.ok:SetPoint("LEFT", n.text, "RIGHT", 8, 0)
    else           -- text [OK] [arrow]
        n.text:SetPoint("LEFT", 10, 0)
        n.ok:SetPoint("LEFT", n.text, "RIGHT", 8, 0)
    end
    -- a soft golden glow round the box (flashes with the edge)
    n.glow = n:CreateTexture(nil, "BACKGROUND", nil, -8)
    n.glow:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\TickGlow")
    n.glow:SetBlendMode("ADD")
    n.glow:SetVertexColor(1, 0.78, 0.2)
    n.glow:SetPoint("TOPLEFT", -16, 14)
    n.glow:SetPoint("BOTTOMRIGHT", 16, -14)
    n.corner = c
    n.handle = handle
    -- right next to its corner's handle, inside the window
    n:SetPoint(c.point, handle, OPPOSITE[c.point], c.dx * 2, c.dy * 2)
    -- noticebounce (M 17 Nov 2026: "I want the popups to flash and bounce a
    -- bit, they are barely noticeable"): the box bounces toward its corner
    -- (bigger hops for the first second), its edge and glow flash gold, and
    -- the arrow breathes and nudges toward the corner.
    n:SetScript("OnUpdate", function(self, elapsed)
        self.t = (self.t or 0) + elapsed
        local t = self.t
        local hop = math.abs(math.sin(t * 5))
        local amp = 5 + 9 * math.max(0, 1 - t / 1.2)
        local b = 2 + hop * amp
        self:ClearAllPoints()
        self:SetPoint(c.point, self.handle, OPPOSITE[c.point], c.dx * b, c.dy * b)
        local f = 0.5 + 0.5 * math.sin(t * 6)
        self:SetBackdropBorderColor(0.6 + 0.4 * f, 0.6 + 0.22 * f, 0.6 - 0.6 * f, 1)
        self.glow:SetAlpha(0.25 + 0.6 * f)
        local s = math.sin(t * 4)
        local d = 2 * math.abs(s)
        self.arrow:SetAlpha(0.55 + 0.45 * s)
        self.arrow:ClearAllPoints()
        if c.left then
            self.arrow:SetPoint("LEFT", 6 - d, -c.dy * d)
        else
            self.arrow:SetPoint("RIGHT", -6 + d, -c.dy * d)
        end
    end)
    n:Hide()
    return n
end

local function Build(frame)
    if handles then return end
    handles, notes = {}, {}
    local level = (frame:GetFrameLevel() or 1) + 70
    for i, c in ipairs(CORNERS) do
        local h = CreateFrame("Button", nil, frame)
        handles[i] = h
        h:SetSize(20, 20)
        h:SetPoint(c.point, frame, c.point, c.dx * 4, c.dy * 4)
        h:SetFrameLevel(level)
        h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        h.art = h:CreateTexture(nil, "ARTWORK")
        SetGrabberArt(h.art, "Up", c.coords)
        h.hl = h:CreateTexture(nil, "HIGHLIGHT")
        SetGrabberArt(h.hl, "Highlight", c.coords)
        h.hl:SetBlendMode("ADD")
        h:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            SetGrabberArt(self.art, "Down", c.coords)
            SetBounds(frame)
            BeginSizing(frame, self, c.point) -- smoothsize
        end)
        h:SetScript("OnMouseUp", function(self, button)
            SetGrabberArt(self.art, "Up", c.coords)
            if button == "RightButton" then ResetSize(frame) return end
            if self.dragging then
                self.dragging = false
                FinishSizing(frame)
            end
        end)
        h:SetScript("OnUpdate", function(self)
            if not self.dragging then return end
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                self.dragging = false
                SetGrabberArt(self.art, "Up", c.coords)
                FinishSizing(frame)
            else
                UpdateSizing(frame, self) -- smoothsize
            end
        end)
        h:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText(L("OPT_RESIZE"), 1, 0.82, 0.27)
            GameTooltip:AddLine(L("RESIZE_CORNER_TIP"), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        h:Hide()
        notes[i] = MakeNote(frame, h, c, level)
    end
    -- closing the journal ends it
    frame:HookScript("OnHide", function() if FDJ.resizeMode then FDJ.StopResizeMode() end end)
end

function FDJ.StartResizeMode()
    local frame = _G.ForeverDungeonJournalFrame
    if not frame then return end
    if not frame:IsShown() and FDJ.ToggleJournal then pcall(FDJ.ToggleJournal) end
    -- the options window out of the way, so the whole journal can be seen
    local settings = _G.ForeverDungeonJournalSettings
    if settings and settings:IsShown() then settings:Hide() end
    Build(frame)
    FDJ.resizeMode = true
    if frame.resizeGrip then frame.resizeGrip:Hide() end -- (the Rescale grip sits in that corner)
    for _, h in ipairs(handles) do h:Show() end
    for _, n in ipairs(notes) do
        n.text:SetText(L("RESIZE_HINT"))
        local w = math.max(120, n.text:GetStringWidth() or 0)
        n:SetSize(w + 30 + 8 + 40 + 10, 30)
        if not n.corner.left then n:SetWidth(w + 10 + 8 + 40 + 30) end
        n.t = 0
        n:Show()
    end
end

-- ------------------------------------------------------------- setup
local function Setup()
    local frame = _G.ForeverDungeonJournalFrame
    if not frame or frame.resizeGrip then return end
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    if ForeverDungeonJournalDB.scale then frame:SetScale(Clamp(tonumber(ForeverDungeonJournalDB.scale) or 1)) end
    if frame.SetResizable then frame:SetResizable(true) end
    local saved = ForeverDungeonJournalDB.journalSize
    if type(saved) == "table" then
        frame:SetSize(ClampSize(frame, saved[1], saved[2]))
    end
    -- smoothsize: no dragging the window while a corner is being dragged
    local dragStart = frame:GetScript("OnDragStart")
    if dragStart then
        frame:SetScript("OnDragStart", function(self, ...)
            if FDJ.journalSizing then return end
            return dragStart(self, ...)
        end)
    end

    -- Rescale: the grip in the bottom-right corner scales the whole window.
    local grip = CreateFrame("Button", nil, frame)
    frame.resizeGrip = grip
    grip:SetSize(18, 18)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel((frame:GetFrameLevel() or 1) + 60)
    grip:SetNormalTexture(GRABBER .. "Up")
    grip:SetHighlightTexture(GRABBER .. "Highlight")
    grip:SetPushedTexture(GRABBER .. "Down")
    grip:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local x = GetCursorPosition()
        self.startX, self.startScale = x, frame:GetScale() or 1
        self.unit = (frame:GetWidth() or BASE_W) * (UIParent:GetEffectiveScale() or 1)
        self.dragging = true
    end)
    grip:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then FDJ.SetJournalScale(1) end
        if self.dragging then
            self.dragging = false
            FDJ.SetJournalScale(frame:GetScale() or 1)
        end
    end)
    grip:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            self.dragging = false
            FDJ.SetJournalScale(frame:GetScale() or 1)
            return
        end
        local x = GetCursorPosition()
        -- The window grows from its centre, so the corner moves half as far as it grows.
        local scale = Clamp(self.startScale + 2 * (x - self.startX) / self.unit)
        frame:SetScale(scale)
        FDJ.SyncPopupScale()
    end)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(L("RESIZE_TIP_TITLE"), 1, 0.82, 0.27)
        GameTooltip:AddLine(L("RESIZE_TIP"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function() pcall(Setup) end)
