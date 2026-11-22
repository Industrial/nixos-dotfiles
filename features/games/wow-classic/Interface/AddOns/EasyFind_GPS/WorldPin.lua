-- EasyFind GPS: the beacon in the world.
--
-- While the arrow follows a route, the game's own floating waypoint marker
-- carries our beacon instead of its icon: a column of light rising from
-- the spot, wisps streaming down it, the addon's emblem in flames where it
-- lands, and a small plate under it naming the step and how far it is
-- (under the character's arrow instead while that shows).
-- Our own art, in the companion's textures folder. The game keeps placing
-- and fading its marker; only its face changes. Off the screen, our arrow
-- at the edge points the way.
--
-- Two looks, picked in the GPS settings page: calm, a still funnel of
-- light narrowing onto the emblem (the default on WoW Forever), and flame,
-- below. Colors come from the active UI theme: the Flame theme is the fire it
-- was drawn as; every other theme lends its accent, so a Midnight beacon
-- burns blue. The wisps move on animation groups, not Lua: the engine
-- runs those at full rate while the camera moves. The column fades in at
-- its top and out at its foot through one gradient mask.
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).tooOld then return end
local WorldPin = {}
ns.GPSWorldPin = WorldPin

local mmax, mmin, mabs, matan2, mpi = math.max, math.min, math.abs, math.atan2, math.pi
local sformat = string.format

local MEDIA = "Interface\\AddOns\\EasyFind_GPS\\textures\\"
local TEX_ARROW = "Interface\\AddOns\\EasyFind\\MapSearch\\Images\\arrow-hq"   -- points down as drawn
local TEX_CORE, TEX_HELIX, TEX_FLARE, TEX_MASK = MEDIA .. "beam_core", MEDIA .. "beam_helix", MEDIA .. "beam_flare", MEDIA .. "beam_mask"
local TEX_FUNNEL = MEDIA .. "beam_funnel"    -- the calm look's light, narrowing to its foot
local TEX_EMBLEM = MEDIA .. "emblem_mask"      -- the ring and glass, torn and warped
local TEX_FLAMES = MEDIA .. "emblem_flames"    -- the air around and above its lines
local WHITE = "Interface\\Buttons\\WHITE8x8"

local THROTTLE = 0.05
local PLATE_MAX_W = 240
local WRAP_LINES = 4   -- a wrapped step's lines at most; the rest on hover
local BEAM_H = 520
local CORE_W, GLOW_W, HELIX_W = 18, 34, 60
local EMBLEM = 64
-- The wisps are stacked copies of the art (128 by 1024, made to wrap),
-- each drawn at a set height, and the stack slides by exactly one copy per
-- loop, so the loop point cannot show.
local SCROLL = HELIX_W * 8
local COPIES = 3
-- Wisp layers: loop seconds, alpha, width as a multiple of the column, a
-- sideways offset and a sway, so some drift wide and it is no clean tube.
local HELIX = {
    { secs = 5.0, a = 1.0, w = 1.0, x = 0, sway = 0 },
    { secs = 8.0, a = 0.6, w = 1.6, x = -9, sway = 7 },
    { secs = 3.6, a = 0.55, w = 1.2, x = 7, sway = 4 },
    { secs = 6.6, a = 0.35, w = 2.2, x = 3, sway = 12 },
}
local SCALE_DIST = 1000             -- the beam is full size this far away
-- The calm funnel: wide and faint at the top, narrowing onto the emblem.
local CALM_H, CALM_TOP_W, CALM_CORE_W = 380, 110, 36
local CALM_EMBLEM = 44

local frame, beam, calm, plate, edge, driver
local styled          -- the game's own face is hidden under ours
local since = 0
local sizeMult = 1
local paint = {}      -- every tinted texture with its role, for a repaint

local function DB() return EasyFind and EasyFind.db end
local function Route() local g = ns and ns.GPS return g and g.CurrentRoute and g.CurrentRoute() end
local function Enabled() local db = DB() return not (db and db.gpsWorldPin == false) end

-- The look: "calm", a still funnel of light onto the emblem, or "flame",
-- the moving fire. Calm is the default on WoW Forever, flame on retail.
local function DefaultStyle() return (ns.Caps and ns.Caps.forever) and "calm" or "flame" end
local function Style()
    local db = DB()
    local s = db and db.gpsBeaconStyle
    if s == "calm" or s == "flame" then return s end
    return DefaultStyle()
end
WorldPin.Style = Style
WorldPin.DefaultStyle = DefaultStyle
-- The game's waypoint, or on a last step to a log quest the quest itself.
local function Tracked(route)
    local ST = C_SuperTrack
    if not ST then return false end
    if route and route.questTracked and ST.GetSuperTrackedQuestID then
        return ST.GetSuperTrackedQuestID() == route.questTracked
    end
    return ST.IsSuperTrackingUserWaypoint and ST.IsSuperTrackingUserWaypoint() or false
end
-- The engine's own navigation region carries the screen position and the
-- clamping; the game's drawn face (icon, range, arrow) is a separate frame
-- it anchors there. Ours is anchored the same way, never parented to the
-- engine's region, which it creates and destroys as it likes.
local function Host()
    return C_Navigation and C_Navigation.GetFrame and C_Navigation.GetFrame() or nil
end
local function Face()
    return _G.SuperTrackedFrame
end

-- ---------------------------------------------------------------------------
-- Colors from the theme
-- ---------------------------------------------------------------------------

local function mix(c, t, w)   -- c toward t by w
    return { c[1] + (t[1] - c[1]) * w, c[2] + (t[2] - c[2]) * w, c[3] + (t[3] - c[3]) * w }
end
local function dim(c, f) return { c[1] * f, c[2] * f, c[3] * f } end
local WHITE_C = { 1, 1, 1 }

-- The base is the theme's own beacon color, or its accent; the hot color
-- is the base pushed most of the way to white.
local function Colors()
    local pal = ns.ACTIVE_UI_PALETTE or (ns.UI_THEME_PALETTES and ns.UI_THEME_PALETTES.Black)
    local base, hot
    if pal and pal.beacon then
        base, hot = pal.beacon.base, pal.beacon.hot
    elseif pal and pal.accent then
        base = { pal.accent[1], pal.accent[2], pal.accent[3] }
    end
    base = base or { 1, 0.5, 0.08 }
    hot = hot or mix(base, WHITE_C, 0.7)
    return {
        body = dim(base, 0.5),            -- plain paint under the light
        core = hot,
        glow = mix(base, WHITE_C, 0.3),
        wispBody = dim(base, 0.55),
        wisp = base,
        extrude = dim(base, 0.42),
        face = dim(base, 0.55),
        rim = mix(base, WHITE_C, 0.55),
        shine = mix(base, WHITE_C, 0.45),
        fire = base,
        fire2 = mix(base, WHITE_C, 0.45),
        halo = base,
        halo2 = mix(base, WHITE_C, 0.25),
        arrow = mix(base, WHITE_C, 0.35),
        edgeGlow = base,
        -- Under the map's end emblem: the theme's window fill.
        disc = (pal and (pal.windowFillBottom or pal.windowFill)) or { 0.05, 0.05, 0.06 },
    }
end

-- A texture tinted by role, remembered so a theme change repaints it.
-- Alpha and an optional darkening factor are the texture's own.
local function Tint(tex, role, a, f)
    paint[#paint + 1] = { tex = tex, role = role, a = a, f = f }
    local c = Colors()[role]
    if f then c = dim(c, f) end
    tex:SetVertexColor(c[1], c[2], c[3], a)
end

-- The theme's beacon color, for what should match the beacon.
function WorldPin.ThemeBase() return Colors().wisp end

-- The emblem's shape as a flat fill on host, at an offset: a mask of its
-- own anchored where it sits.
local function Shaped(host, dx, dy, sub, role, a, f, blend)
    local m = host:CreateMaskTexture()
    m:SetTexture(TEX_EMBLEM, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetPoint("TOPLEFT", host, "TOPLEFT", dx, dy)
    m:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", dx, dy)
    local t = host:CreateTexture(nil, "ARTWORK", nil, sub)
    t:SetTexture(WHITE)
    t:SetPoint("TOPLEFT", host, "TOPLEFT", dx, dy)
    t:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", dx, dy)
    t:SetBlendMode(blend or "BLEND")
    Tint(t, role, a, f)
    t:AddMaskTexture(m)
    return t, m
end

-- The addon's mark as the calm beacon wears it: the shape in relief with
-- its rim lit and a soft glow behind, in the theme's colors, filling
-- whatever size its frame is given. The map's journey's end wears it too,
-- solid: a disc in the theme's fill under the shape, so the map's pins
-- and art stop showing through its glass.
local DISC = 0.86   -- of the frame: up to the ring
function WorldPin.NewEmblem(parent, solid)
    local seat = CreateFrame("Frame", nil, parent)
    if solid then
        local disc = seat:CreateTexture(nil, "ARTWORK", nil, 0)
        disc:SetTexture(WHITE)
        disc:SetPoint("CENTER")
        local m = seat:CreateMaskTexture()
        m:SetTexture(ns.PORTRAIT_ALPHA_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(disc)
        disc:AddMaskTexture(m)
        Tint(disc, "disc", 0.94)
        -- The disc sized with the frame by the one call that sizes it: a
        -- size event is not to be had while the map sizes the mark hidden.
        function seat:Fit(size)
            self:SetSize(size, size)
            disc:SetSize(size * DISC, size * DISC)
        end
        seat.disc = disc
    end
    local glow = seat:CreateTexture(nil, "ARTWORK", nil, 1)
    glow:SetTexture(TEX_FLARE)
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(seat)
    Tint(glow, "halo", 0.35)
    Shaped(seat, 0.8, -1.2, 3, "extrude", 1)
    Shaped(seat, 0, 0, 4, "face", 1)
    Shaped(seat, -1, 1, 5, "rim", 0.5, nil, "ADD")
    return seat
end

-- The plate as the keybind buttons are: a block in the theme's own
-- window fill (the Classic marble, a window from the middle of a picked
-- tree's painting, Forever's page) with the theme's text. The live color
-- tables follow the theme; Repaint reads them again on a theme change.
local plates = {}   -- the beacon's and the arrow's
WorldPin._plates = plates   -- dev tools
local function PaintPlate(p)
    p._efArtPath = ns.ClassicTreePiece("TopLeft")
    p._efArtCenter = p._efArtPath ~= nil
    ns.ApplyThemeFill(p)
    local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
    local main = ns.TEXT_PRIMARY or { 1, 1, 1 }
    local faint = (theme and theme.lightTheme and theme.textFaint) or ns.TEXT_DIM or main
    p.text:SetTextColor(main[1], main[2], main[3], 1)
    p.note:SetTextColor(main[1], main[2], main[3], 1)
    p.sub:SetTextColor(faint[1], faint[2], faint[3], 1)
    p.sub2:SetTextColor(faint[1], faint[2], faint[3], 1)
end

local function Repaint()
    local colors = Colors()
    for i = 1, #paint do
        local p = paint[i]
        local c = colors[p.role]
        if p.f then c = dim(c, p.f) end
        p.tex:SetVertexColor(c[1], c[2], c[3], p.a)
    end
    for i = 1, #plates do PaintPlate(plates[i]) end
    WorldPin.ApplyPlateBorders()
end

-- The plate's border, by the Arrow caption border switch: the theme's own
-- frame art where it has one, else the line the search bar wears; none off.
function WorldPin.ApplyPlateBorder(p)
    local db = DB()
    local on = db ~= nil and db.gpsPlateBorder == true
    p._efForeverSurface, p._efClassicSurface = on or nil, on or nil
    p._efSkinOff, p._efSkinForced = (not on) or nil, on or nil
    local dressed = ns.ApplySkin ~= nil and ns.ApplySkin(p)
    if ns.SetRoundedRectBorderEdgeShown then ns.SetRoundedRectBorderEdgeShown(p, on and not dressed) end
end

function WorldPin.ApplyPlateBorders()
    for i = 1, #plates do WorldPin.ApplyPlateBorder(plates[i]) end
end

-- The arrow at the character wears the beacon's colors too.
WorldPin.Tint = Tint
if ns.ApplyUITheme then ns.Utils.PostHook(ns, "ApplyUITheme", Repaint) end

-- A plate in the keybind buttons' look: the step, then the distance and
-- this step's time, then the trip's. Under the beacon, or under the
-- arrow while it shows.
function WorldPin.NewPlate(parent)
    local p = CreateFrame("Frame", nil, parent)
    if ns.CreateRoundedRectBorder then
        ns.CreateRoundedRectBorder(p)
        ns.SetRoundedRectBorderBgAlpha(p, 0.96)
        ns.SetRoundedRectBorderEdgeShown(p, false)
    end
    local font = (ns.LEAF_FONT and _G[ns.LEAF_FONT]) and ns.LEAF_FONT or "GameFontHighlight"
    local text = p:CreateFontString(nil, "OVERLAY", font)
    text:SetPoint("TOP", p, "TOP", 0, -6)
    text:SetJustifyH("CENTER")
    text:SetWordWrap(false)
    text:SetShadowColor(0, 0, 0, 0)
    text._efOwnColor = true
    p.text = text
    local function Line(above)
        local fs = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOP", above, "BOTTOM", 0, -2)
        fs:SetJustifyH("CENTER")
        fs:SetWordWrap(false)
        fs:SetShadowColor(0, 0, 0, 0)
        fs._efOwnColor = true
        return fs
    end
    p.note = Line(text)   -- an extension's line (GPS.status), under the step
    p.sub = Line(text)
    p.sub2 = Line(p.sub)
    PaintPlate(p)
    plates[#plates + 1] = p
    WorldPin.ApplyPlateBorder(p)
    -- A right-click: clear the route, or bring the window up when nothing
    -- on screen shows the route yet. The menu at the cursor.
    local menuAnchor = CreateFrame("Frame", nil, p)
    menuAnchor:SetSize(1, 1)
    p:EnableMouse(true)
    -- A step cut to fit ("..."): the whole of it on hover.
    if ns.Utils and ns.Utils.AttachDelayedTooltip then
        ns.Utils.AttachDelayedTooltip(p, "ANCHOR_TOP", function(self)
            if self.text:IsTruncated() then return self.shownText end
        end)
    end
    -- A right-drag that turned the camera is not a click on the plate.
    local downX, downY
    p:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then downX, downY = GetCursorPosition() end
    end)
    p:SetScript("OnMouseUp", function(_, button)
        if button ~= "RightButton" or not (ns.ShowTogglePopup and ns.GPS) then return end
        local L = ns.L
        local cx, cy = GetCursorPosition()
        if downX and (math.abs(cx - downX) > 4 or math.abs(cy - downY) > 4) then return end
        local scale = UIParent:GetEffectiveScale()
        menuAnchor:ClearAllPoints()
        menuAnchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
        local defs = {}
        if not (ns.GPS.IsWindowOpen and ns.GPS:IsWindowOpen()) then
            defs[#defs + 1] = { kind = "action", label = L["GPS_POPOUT"], onClick = function() ns.GPS:OpenWindow() end }
        end
        defs[#defs + 1] = { kind = "action", label = L["GPS_CLEAR"], onClick = function() ns.GPS:Clear() end }
        defs[#defs + 1] = { kind = "separator" }
        -- The box's switch on its row (off, the arrow's own right-click opens
        -- this menu to bring it back); its border and lines in the flyout.
        defs[#defs + 1] = { kind = "check", label = L["GPS_PLATE_SHOWN"],
            get = function() return ns.GPS.ArrowBoxShown() end,
            set = function(on) ns.GPS.SetArrowBox(on) end,
            rows = function()
                local GPS = ns.GPS
                local rows = { GPS.CheckFlyoutRow({ label = L["GPS_PLATE_BORDER_MENU"], tooltip = L["GPS_PLATE_BORDER_TT"],
                    get = function() local d = DB() return d ~= nil and d.gpsPlateBorder == true end,
                    set = function(on)
                        local d = DB()
                        if not d then return end
                        d.gpsPlateBorder = on or nil
                        WorldPin.ApplyPlateBorders()
                    end }), { isSeparator = true } }
                for _, line in ipairs(GPS.BOX_LINES) do
                    rows[#rows + 1] = GPS.CheckFlyoutRow({ label = line.label,
                        get = function() return GPS.BoxLineShown(line.key) end,
                        set = function(on) GPS.SetBoxLine(line.key, on) end })
                end
                return rows
            end }
        -- The arrow's plate: unlocked, the arrow takes a plain drag.
        local Arrow = p.isArrow and ns.GPSArrow
        if Arrow and Arrow.SetUnlocked then
            local db = DB()
            local unlocked = db ~= nil and db.gpsArrowUnlocked == true
            defs[#defs + 1] = { kind = "separator" }
            -- The row names what a click does: Unlock while locked, Lock while not.
            defs[#defs + 1] = { kind = "action", label = unlocked and L["GPS_ARROW_UNLOCKED"] or L["GPS_ARROW_LOCKED"],
                tooltip = L["GPS_ARROW_LOCK_TT"], onClick = function() Arrow.SetUnlocked(not unlocked) end }
            defs[#defs + 1] = { kind = "action", label = L["GPS_ARROW_RESET"], onClick = function() Arrow.ResetPlace() end }
        end
        ns.ShowTogglePopup("EasyFindGPSBeaconMenu", menuAnchor, defs, {})
    end)
    return p
end

-- One line of a plate under the shown one above it (none: at the top);
-- an empty line hides and takes no room. The plate's height so far back.
local function StackLine(p, fs, s, above, h)
    fs:SetShown(s ~= "")
    if s == "" then return above, h end
    fs:ClearAllPoints()
    if above then
        fs:SetPoint("TOP", above, "BOTTOM", 0, -2)
        h = h + 2
    else
        fs:SetPoint("TOP", p, "TOP", 0, -6)
    end
    return fs, h + (fs:GetStringHeight() or 10)
end

-- A line's width written out on one line, whatever width it was last set to.
local function Natural(fs)
    local unbounded = fs.GetUnboundedStringWidth
    return unbounded and unbounded(fs) or fs:GetStringWidth() or 0
end

-- New lines on a plate, sized to them, the shown ones stacked from the
-- top; the same again does nothing. A step too long for the plate runs
-- onto more lines (WRAP_LINES at most), unless its switch cuts it to one.
function WorldPin.FillPlate(p, text, sub, sub2, note)
    text, sub, sub2, note = text or "", sub or "", sub2 or "", note or ""
    local GPS = ns.GPS
    local wrap = not (GPS and GPS.BoxLineShown) or GPS.BoxLineShown("gpsBoxWrap")
    if text == p.shownText and sub == p.shownSub and sub2 == p.shownSub2 and note == p.shownNote
        and wrap == p.shownWrap then
        return
    end
    p.shownText, p.shownSub, p.shownSub2, p.shownNote, p.shownWrap = text, sub, sub2, note, wrap
    p.text:SetWordWrap(wrap)
    p.text:SetMaxLines(wrap and WRAP_LINES or 1)
    p.text:SetText(text)
    p.note:SetText(note)
    p.sub:SetText(sub)
    p.sub2:SetText(sub2)
    local w = mmax(Natural(p.text), Natural(p.note), Natural(p.sub), Natural(p.sub2))
    local inner = mmin(PLATE_MAX_W, mmax(60, w))
    p.text:SetWidth(inner)
    p.note:SetWidth(inner)
    p.sub:SetWidth(inner)
    p.sub2:SetWidth(inner)
    local above, h = StackLine(p, p.text, text, nil, 6)
    above, h = StackLine(p, p.note, note, above, h)
    above, h = StackLine(p, p.sub, sub, above, h)
    h = select(2, StackLine(p, p.sub2, sub2, above, h))
    p:SetSize(inner + 20, h + 6)
end

-- What the plate says, each line by its switch: the step; "This step: 119
-- yds, 1 min"; the time for the whole trip, when more steps follow; and an
-- extension's line. Nothing with the box off or every line empty.
function WorldPin.PlateLines(route, yards)
    local GPS = ns.GPS
    if not (GPS and GPS.ArrowBoxShown()) then return nil end
    local L = ns.L
    local active = route.active or 1
    local step = route.steps and route.steps[active]
    local text, line, trip = "", "", ""
    if GPS.BoxLineShown("gpsBoxStep") then
        text = GPS.StepText and GPS.StepText(step, true) or (step and step.text or "")
    end
    local note = GPS.status or ""
    local Eta = GPS.EtaText
    if GPS.BoxLineShown("gpsBoxThisStep") then
        local range = yards and yards > 0 and GPS.DistanceText(yards) or nil
        local left = Eta and (route.stepEta or (step and step.sec))
        local time = left and left > 0 and Eta(left) or nil
        if range and time then line = sformat(L["GPS_PLATE_STEP_BOTH_FMT"], range, time)
        elseif range or time then line = sformat(L["GPS_PLATE_STEP_FMT"], range or time) end
    end
    if GPS.BoxLineShown("gpsBoxTotal") and Eta and route.eta and route.eta > 0 and route.steps and #route.steps > active then
        trip = sformat(L["GPS_PLATE_TRIP_FMT"], Eta(route.eta))
    end
    if text == "" and line == "" and trip == "" and note == "" then return nil end
    return text, line, trip, note
end

-- ---------------------------------------------------------------------------
-- Building it
-- ---------------------------------------------------------------------------

local anchoredTo

-- On the spot the marker marks: the face's icon when there is one, else
-- the engine's region itself. Re-anchored whenever that object changes.
local function Anchor(host)
    local face = Face()
    local spot = (face and face.Icon) or host
    if spot == anchoredTo then return end
    anchoredTo = spot
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", spot, "CENTER", 0, 0)
end

-- Stacked copies of the wisp art rising through a mask: each texture
-- slides on its own, so the mask, which belongs to the frame, stays put.
local function RisingFire(parent, mask, w, h, layers, sub)
    for i, fl in ipairs(layers) do
        for k = 1, COPIES do
            local tex = parent:CreateTexture(nil, "ARTWORK", nil, sub + i)
            tex:SetTexture(TEX_HELIX)
            tex:SetBlendMode("ADD")
            tex:SetSize(w, h)
            tex:SetPoint("TOP", parent, "TOP", 0, -(k - 1) * h)
            Tint(tex, fl.role, fl.a)
            tex:AddMaskTexture(mask)
            local g = tex:CreateAnimationGroup()
            g:SetLooping("REPEAT")
            local slide = g:CreateAnimation("Translation")
            slide:SetOffset(0, h)
            slide:SetDuration(fl.secs)
            g:Play()
        end
    end
end

local function Build(host)
    frame = CreateFrame("Frame", "EasyFindGPSWorldPin", UIParent)
    frame:SetSize(1, 1)
    frame:SetFrameStrata("LOW")
    frame:SetFrameLevel(10)
    Anchor(host)

    -- The beam, on its own frame so distance can scale it without the plate.
    beam = CreateFrame("Frame", nil, frame)
    beam:SetSize(HELIX_W, BEAM_H)
    beam:SetPoint("BOTTOM", frame, "CENTER", 0, 0)

    -- One mask for every layer of the column: nothing at the top, full in
    -- the middle, gone again at the foot; wide enough for the wisps that
    -- drift out past the column.
    local mask = beam:CreateMaskTexture()
    mask:SetTexture(TEX_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetPoint("TOPLEFT", beam, "TOPLEFT", -HELIX_W, 0)
    mask:SetPoint("BOTTOMRIGHT", beam, "BOTTOMRIGHT", HELIX_W, 0)

    local function column(width, sub, role, a, blend)
        local tex = beam:CreateTexture(nil, "ARTWORK", nil, sub)
        tex:SetTexture(TEX_CORE)
        tex:SetBlendMode(blend or "ADD")
        tex:SetSize(width, BEAM_H)
        tex:SetPoint("BOTTOM")
        Tint(tex, role, a)
        tex:AddMaskTexture(mask)
        return tex
    end
    -- Added light alone washes out against a bright sky, so a body is
    -- painted first, plainly, and the light adds onto it.
    column(GLOW_W + 6, 0, "body", 0.95, "BLEND")
    column(CORE_W, 7, "core", 0.85)
    column(GLOW_W, 1, "glow", 0.4)

    -- The wisps: stacked copies sliding down inside a clipped box. Two
    -- motions, two frames: a holder drifts sideways, the strip inside it
    -- falls; two translations on one frame fight each other.
    local clip = CreateFrame("Frame", nil, beam)
    clip:SetPoint("TOPLEFT", beam, "TOPLEFT", -HELIX_W, 0)
    clip:SetPoint("BOTTOMRIGHT", beam, "BOTTOMRIGHT", HELIX_W, 0)
    clip:SetClipsChildren(true)
    for i, L in ipairs(HELIX) do
        local w = HELIX_W * L.w
        local holder = CreateFrame("Frame", nil, clip)
        holder:SetSize(w, SCROLL * COPIES)
        holder:SetPoint("BOTTOM", clip, "BOTTOM", L.x, 0)
        local strip = CreateFrame("Frame", nil, holder)
        strip:SetAllPoints(holder)
        for k = 1, COPIES do
            local body = strip:CreateTexture(nil, "ARTWORK", nil, 1)
            body:SetTexture(TEX_HELIX)
            body:SetBlendMode("BLEND")
            body:SetSize(w, SCROLL)
            body:SetPoint("BOTTOM", strip, "BOTTOM", 0, (k - 1) * SCROLL)
            Tint(body, "wispBody", L.a * 0.9)
            body:AddMaskTexture(mask)
            local tex = strip:CreateTexture(nil, "ARTWORK", nil, 2 + i)
            tex:SetTexture(TEX_HELIX)
            tex:SetBlendMode("ADD")
            tex:SetSize(w, SCROLL)
            tex:SetPoint("BOTTOM", strip, "BOTTOM", 0, (k - 1) * SCROLL)
            Tint(tex, "wisp", L.a)
            tex:AddMaskTexture(mask)
        end
        local g = strip:CreateAnimationGroup()
        g:SetLooping("REPEAT")
        local slide = g:CreateAnimation("Translation")
        slide:SetOffset(0, -SCROLL)
        slide:SetDuration(L.secs)
        g:Play()
        if L.sway > 0 then
            local s = holder:CreateAnimationGroup()
            s:SetLooping("BOUNCE")
            local drift = s:CreateAnimation("Translation")
            drift:SetOffset(L.sway, 0)
            drift:SetDuration(2.2 + i * 0.7)
            drift:SetSmoothing("IN_OUT")
            s:Play()
        end
    end

    -- The emblem in flames where the beam lands: the addon's mark as a
    -- mask over moving fire, in relief, with flames licking off its lines.
    local orb = CreateFrame("Frame", nil, beam)
    orb:SetFrameLevel(beam:GetFrameLevel() + 3)
    orb:SetSize(EMBLEM, EMBLEM)
    orb:SetPoint("CENTER", beam, "BOTTOM", 0, 0)
    -- Two slow halos turning behind it for the beam to land in.
    local function halo(size, role, a, x, y, secs, dir)
        local t = orb:CreateTexture(nil, "ARTWORK", nil, 1)
        t:SetTexture(TEX_FLARE)
        t:SetBlendMode("ADD")
        t:SetSize(size, size)
        t:SetPoint("CENTER", orb, "CENTER", x, y)
        Tint(t, role, a)
        local spin = t:CreateAnimationGroup()
        spin:SetLooping("REPEAT")
        local rot = spin:CreateAnimation("Rotation")
        rot:SetDegrees(360 * dir)
        rot:SetDuration(secs)
        spin:Play()
    end
    halo(EMBLEM * 1.7, "halo", 0.28, 3, -2, 9, 1)
    halo(EMBLEM * 1.4, "halo2", 0.24, -4, 3, 13, -1)

    -- Depth: the shape repeated below and to the right, darker each step,
    -- an extrusion the face sits on.
    for k = 4, 1, -1 do
        Shaped(orb, k * 0.7, -k * 1.0, 3, "extrude", 1, 1 - k * 0.14)
    end
    local _, faceMask = Shaped(orb, 0, 0, 4, "face", 1)

    -- The fire inside the shape.
    local fire = CreateFrame("Frame", nil, orb)
    fire:SetFrameLevel(orb:GetFrameLevel() + 1)
    fire:SetAllPoints(orb)
    fire:SetClipsChildren(true)
    local fireMask = fire:CreateMaskTexture()
    fireMask:SetTexture(TEX_EMBLEM, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    fireMask:SetAllPoints(orb)
    RisingFire(fire, fireMask, EMBLEM, EMBLEM * 2,
        { { secs = 2.4, role = "fire", a = 1 }, { secs = 3.6, role = "fire2", a = 0.75 } }, 5)

    -- The lit edge of the relief, and the shape's own light, flickering.
    Shaped(orb, -1, 1, 7, "rim", 0.45, nil, "ADD")
    local shine = orb:CreateTexture(nil, "ARTWORK", nil, 7)
    shine:SetTexture(WHITE)
    shine:SetAllPoints(orb)
    shine:SetBlendMode("ADD")
    Tint(shine, "shine", 0.4)
    shine:AddMaskTexture(faceMask)
    local flicker = shine:CreateAnimationGroup()
    flicker:SetLooping("BOUNCE")
    local dimmer = flicker:CreateAnimation("Alpha")
    dimmer:SetFromAlpha(1)
    dimmer:SetToAlpha(0.4)
    dimmer:SetDuration(0.35)
    flicker:Play()

    -- Flames coming off the shapes: rising fire through a mask that covers
    -- a band around every line and the air above it, on a wider frame so
    -- the tongues reach past the emblem's bounds.
    local FRINGE = EMBLEM / 0.62
    local fringe = CreateFrame("Frame", nil, orb)
    fringe:SetFrameLevel(orb:GetFrameLevel() + 2)
    fringe:SetSize(FRINGE, FRINGE)
    fringe:SetPoint("CENTER", orb, "CENTER", 0, 0)
    fringe:SetClipsChildren(true)
    local fringeMask = fringe:CreateMaskTexture()
    fringeMask:SetTexture(TEX_FLAMES, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    fringeMask:SetAllPoints(fringe)
    RisingFire(fringe, fringeMask, FRINGE, FRINGE * 2,
        { { secs = 2.2, role = "fire", a = 0.95 }, { secs = 3.4, role = "fire2", a = 0.65 } }, 3)

    -- The calm look: a still funnel of light narrowing onto the emblem,
    -- nothing moving; drawn symmetric in its own art (stretching a strip's
    -- corners warps it unevenly). The emblem: flat shape, lit rim, soft glow.
    calm = CreateFrame("Frame", nil, frame)
    calm:SetSize(CALM_TOP_W, CALM_H)
    calm:SetPoint("BOTTOM", frame, "CENTER", 0, 0)
    local function funnel(w, sub, role, a)
        local tex = calm:CreateTexture(nil, "ARTWORK", nil, sub)
        tex:SetTexture(TEX_FUNNEL)
        tex:SetBlendMode("ADD")
        tex:SetSize(w, CALM_H)
        tex:SetPoint("BOTTOM")
        Tint(tex, role, a)
        return tex
    end
    funnel(CALM_TOP_W, 1, "glow", 0.55)
    funnel(CALM_CORE_W, 2, "core", 0.7)
    local seat = CreateFrame("Frame", nil, calm)
    seat:SetFrameLevel(calm:GetFrameLevel() + 2)
    seat:SetSize(CALM_EMBLEM, CALM_EMBLEM)
    seat:SetPoint("CENTER", calm, "BOTTOM", 0, 0)
    local glow = seat:CreateTexture(nil, "ARTWORK", nil, 1)
    glow:SetTexture(TEX_FLARE)
    glow:SetBlendMode("ADD")
    glow:SetSize(CALM_EMBLEM * 1.6, CALM_EMBLEM * 1.6)
    glow:SetPoint("CENTER")
    Tint(glow, "halo", 0.3)
    Shaped(seat, 0.8, -1.2, 3, "extrude", 1)
    Shaped(seat, 0, 0, 4, "face", 1)
    Shaped(seat, -1, 1, 5, "rim", 0.5, nil, "ADD")
    calm:Hide()

    -- The pointer for when the spot is off the screen: the game clamps its
    -- marker to the screen edge on the line from the screen's middle, so
    -- our arrow at that spot, turned along that line, points the way.
    edge = CreateFrame("Frame", nil, frame)
    edge:SetSize(48, 48)
    edge:SetPoint("CENTER", frame, "CENTER", 0, 0)
    local edgeGlow = edge:CreateTexture(nil, "ARTWORK", nil, 1)
    edgeGlow:SetTexture(TEX_FLARE)
    edgeGlow:SetBlendMode("ADD")
    edgeGlow:SetSize(96, 96)
    edgeGlow:SetPoint("CENTER")
    Tint(edgeGlow, "edgeGlow", 0.5)
    local arrow = edge:CreateTexture(nil, "ARTWORK", nil, 3)
    arrow:SetTexture(TEX_ARROW)
    arrow:SetAllPoints(edge)
    Tint(arrow, "arrow", 1)
    edge.arrow = arrow
    local pulse = edge:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local grow = pulse:CreateAnimation("Scale")
    grow:SetScaleFrom(1, 1)
    grow:SetScaleTo(1.2, 1.2)
    grow:SetDuration(0.6)
    grow:SetSmoothing("IN_OUT")
    edge.pulse = pulse
    edge:Hide()

    plate = WorldPin.NewPlate(frame)
    plate:SetPoint("TOP", frame, "CENTER", 0, -44)
    frame:Hide()
end

-- ---------------------------------------------------------------------------
-- The game's own face, hidden under ours
-- ---------------------------------------------------------------------------

-- Hidden outright, and kept hidden through hooks on Show and SetShown,
-- since the game shows its icon and range again as it updates them.
local function Keep(obj, hidden)
    if hidden then
        if not obj._efGPSHook then
            obj._efGPSHook = true
            hooksecurefunc(obj, "Show", function(self) if self._efGPSHidden then self:Hide() end end)
            if obj.SetShown then
                hooksecurefunc(obj, "SetShown", function(self, shown) if shown and self._efGPSHidden then self:Hide() end end)
            end
        end
        obj._efGPSHidden = true
        if obj:IsShown() then obj:Hide() end
    else
        obj._efGPSHidden = nil
        if not obj:IsShown() then obj:Show() end
    end
end

local function StyleTree(owner, on, depth)
    if owner.GetRegions then
        for i = 1, select("#", owner:GetRegions()) do
            local r = select(i, owner:GetRegions())
            if r then Keep(r, on) end
        end
    end
    if depth > 0 and owner.GetChildren then
        for i = 1, select("#", owner:GetChildren()) do
            local c = select(i, owner:GetChildren())
            if c and c ~= frame then Keep(c, on) end
        end
    end
end

local function StyleHost(host, on)
    local face = Face()
    if face then StyleTree(face, on, 3) end
    if host and host ~= face then StyleTree(host, on, 3) end
    styled = on
end

-- ---------------------------------------------------------------------------
-- Every pass
-- ---------------------------------------------------------------------------

-- Far away the beam stands full height; close by it shrinks, so it never
-- fills the screen over the spot you are standing on. Eased a little on
-- every pass, never stepped.
local function Resize(dist, dt)
    local target = 1
    if dist and dist > 0 then target = mmax(0.3, mmin(1.2, 0.5 * (SCALE_DIST / dist))) end
    if mabs(target - sizeMult) > 0.003 then
        sizeMult = sizeMult + (target - sizeMult) * mmin(1, (dt or THROTTLE) * 2)
        beam:SetScale(sizeMult)
        calm:SetScale(sizeMult)
    end
end

-- The game's face kept hidden: walked again on a new host and once a
-- second for parts it adds, not on every pass.
local styledHost, restyleAt = nil, 0
local function HideFace(host)
    local now = GetTime()
    if styled and host == styledHost and now < restyleAt then return end
    StyleHost(host, true)
    styledHost, restyleAt = host, now + 1
end

local plateAt   -- where the plate was last placed

local function PlacePlate(at)
    if at == plateAt then return end
    plateAt = at
    plate:ClearAllPoints()
    if at == "above" then plate:SetPoint("BOTTOM", frame, "CENTER", 0, 34)
    elseif at == "below" then plate:SetPoint("TOP", frame, "CENTER", 0, -34)
    else plate:SetPoint("TOP", frame, "CENTER", 0, -44) end
end

-- A waypoint carries no floor: indoors, a spot in a building with no map
-- of its own (Stormwind's Wizard's Sanctum) reads to the game as the ground
-- outside, and its marker leads out through the way out (57 yards against a
-- straight 31). Past a floor's rise and OVER yards beyond the straight way
-- the marker leads elsewhere; it shows again SETTLE yards under that.
local RISE, OVER, SETTLE = 20, 10, 5
local aim = { step = nil }
local leadsElsewhere = false
local function MarkerLeadsElsewhere(step)
    if not (IsIndoors and IsIndoors()) then
        leadsElsewhere = false
        return false
    end
    local d = C_Navigation and C_Navigation.GetDistance and C_Navigation.GetDistance()
    local GPS = ns.GPS
    if not (d and GPS and GPS.PlayerWorldPos) or (issecretvalue and issecretvalue(d)) then return false end
    -- Where the game's waypoint stands, read once a step.
    if aim.step ~= step then
        aim.step, aim.ci = step, nil
        local wp = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
        if wp and wp.position then
            local ci, pos = C_Map.GetWorldPosFromMapPos(wp.uiMapID, wp.position)
            if ci and pos then aim.ci, aim.x, aim.y = ci, pos:GetXY() end
        end
    end
    local ci, px, py = GPS.PlayerWorldPos()
    if not (aim.ci and ci == aim.ci) then return false end
    local straight = ((aim.x - px) ^ 2 + (aim.y - py) ^ 2) ^ 0.5
    local limit = (straight * straight + RISE * RISE) ^ 0.5 + OVER
    if leadsElsewhere then limit = limit - SETTLE end
    leadsElsewhere = d > limit
    return leadsElsewhere
end
WorldPin.MarkerLeadsElsewhere = MarkerLeadsElsewhere

local function Update(dt)
    local host = Host()
    local route = Route()
    local on = Enabled() and route ~= nil and not route.arrived and not route.untracked and Tracked(route)
        and host ~= nil and host:IsShown()
    if not on then
        if frame then frame:Hide() end
        if styled then StyleHost(host, false) end
        return
    end
    if not frame then Build(host) end
    -- A step that is a spell or an item has nowhere to walk to: no beacon,
    -- and the game's own marker stays hidden too.
    local current = route.steps and route.steps[route.active or 1]
    if current and (current.kind == "teleport" or current.noWay or (ns.GPSFollow and ns.GPSFollow.AtBuilding(current))) then
        frame:Hide()
        HideFace(host)
        return
    end
    -- The game's marker heads for a way out, not the spot: neither shows,
    -- the arrow and the minimap line still lead.
    if MarkerLeadsElsewhere(current) then
        frame:Hide()
        HideFace(host)
        return
    end
    Anchor(host)
    HideFace(host)
    -- The game fades its own face under the cursor and as the spot comes
    -- close; the beacon does not follow that, it stays as it is.
    if (beam:GetAlpha() or 1) ~= 1 then beam:SetAlpha(1) end
    local still = Style() == "calm"
    frame:Show()
    local clamped = C_Navigation and C_Navigation.WasClampedToScreen and C_Navigation.WasClampedToScreen()
    beam:SetShown(not clamped and not still)
    calm:SetShown(not clamped and still)
    -- The arrow at the character leads the way: none here pointing straight at the spot.
    local led = ns.GPSArrow and ns.GPSArrow:Guiding()
    edge:SetShown(clamped and not led or false)
    -- The off-screen arrow breathes only with the moving look.
    if still then
        if edge.pulse:IsPlaying() then edge.pulse:Stop() end
    elseif not edge.pulse:IsPlaying() then
        edge.pulse:Play()
    end
    if clamped then
        local cx, cy = host:GetCenter()
        local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
        if cx and cy then
            -- The art points down at rest, the angle -pi/2; turn it by the
            -- difference to the line's angle.
            local ang = matan2(cy - sh / 2, cx - sw / 2)
            edge.arrow:SetRotation(ang + mpi / 2)
            PlacePlate(cy < sh / 2 and "above" or "below")
        else
            PlacePlate("below")
        end
    else
        PlacePlate("under")
    end
    -- The arrow carries the plate while it shows.
    local d = C_Navigation and C_Navigation.GetDistance and C_Navigation.GetDistance() or 0
    local text, line, trip, note
    if not led then text, line, trip, note = WorldPin.PlateLines(route, d) end
    plate:SetShown(text ~= nil)
    if text then WorldPin.FillPlate(plate, text, line, trip, note) end
    Resize(d, dt or THROTTLE)
end

-- One line for the dev status: why the beacon shows or not, and what the
-- game's marker is made of.
function WorldPin:Status()
    local host = Host()
    local route = Route()
    local parts = {}
    local face = Face()
    for _, owner in ipairs({ face, host }) do
        if owner and owner.GetRegions then
            for i = 1, select("#", owner:GetRegions()) do
                local r = select(i, owner:GetRegions())
                parts[#parts + 1] = sformat("%s(%s %s)", r:GetObjectType(), tostring((r.GetAtlas and r:GetAtlas()) or (r.GetTexture and r:GetTexture()) or "?"), r:IsShown() and "shown" or "hidden")
            end
        end
        if owner and owner.GetChildren then
            for i = 1, select("#", owner:GetChildren()) do
                local c = select(i, owner:GetChildren())
                if c ~= frame then parts[#parts + 1] = sformat("child %s %s", c:GetName() or c:GetObjectType(), c:IsShown() and "shown" or "hidden") end
            end
        end
    end
    return sformat("world pin: enabled %s route %s arrived %s tracked %s host %s shown %s clamped %s distance %s | ours %s scale %.2f | marker: %s",
        tostring(Enabled()), tostring(route ~= nil), tostring(route and route.arrived == true), tostring(Tracked(route)),
        host and (host:GetName() or "frame") or "none", tostring(host and host:IsShown()),
        tostring(C_Navigation and C_Navigation.WasClampedToScreen and C_Navigation.WasClampedToScreen()),
        tostring(C_Navigation and C_Navigation.GetDistance and C_Navigation.GetDistance()),
        frame and (frame:IsShown() and "shown" or "hidden") or "not built", sizeMult, table.concat(parts, ", "))
end

local function Tick(_, dt)
    since = since + dt
    if since < THROTTLE then return end
    local elapsed = since
    since = 0
    Update(elapsed)
end

-- A route change, the arrow letting go, the option flipped: look now, and
-- keep looking only while a route is followed.
function WorldPin:Refresh()
    local route = Route()
    since = 0
    driver:SetScript("OnUpdate", (route and not route.arrived) and Tick or nil)
    Update(THROTTLE)
end

driver = CreateFrame("Frame")
WorldPin._driver = driver   -- dev tools
