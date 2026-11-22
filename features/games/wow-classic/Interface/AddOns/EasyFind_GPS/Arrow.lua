-- EasyFind GPS: the arrow at the character.
--
-- While a route is followed, an arrow under the character points the way
-- on foot as it runs: at a spot a little ahead along the walk, so it turns
-- with every bend, with the step, the yards left on the walk and the times
-- left in the beacon's plate under it. A walk hardly longer than the line
-- to its spot and close beside it is aimed at the spot, past the grid's
-- wiggles; a way round (out along a pier) is followed. A few yards
-- beside the walk it leads alongside it, not back onto it, where nothing
-- stands between. At a ride's boarding spot it points there; on board, and
-- where the game gives no facing (instances), it rests. Shift-drag moves it.
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).tooOld then return end
local Arrow = {}
ns.GPSArrow = Arrow

local mmax, mmin, mabs, matan2, mpi = math.max, math.min, math.abs, math.atan2 or math.atan, math.pi

local TEX_ARROW = "Interface\\AddOns\\EasyFind\\MapSearch\\Images\\arrow-hq"   -- points down as drawn
local SIZE = 44
local HOME_Y = -130            -- under the character, from the screen's center
local AHEAD = 25               -- yards along the walk the arrow aims at
local NEAR_STRAIGHT = 1.1      -- a walk within this of the straight line is aimed at its spot
local WIGGLE = 10              -- yards it may stray from that line: two or three grid cells
local LANE = 10                -- yards beside the walk still walked alongside it
local AT_RIDE = 60             -- yards from a ride's boarding spot: still pointing at it
local THROTTLE = 0.03

local frame, art, plate, driver
local since = 0
local aimCi                    -- the continent the last aim was taken on

local function DB() return EasyFind and EasyFind.db end
local function Route() local g = ns.GPS return g and g.CurrentRoute and g.CurrentRoute() end
local function Enabled() local db = DB() return not (db and db.gpsArrow == false) end

-- The way from (px, py) to (ax, ay) as the game turns: from north toward west.
local function Bearing(ci, px, py, ax, ay)
    local a = ns.GPSFollow.Axes(ci)
    if not a then return nil end
    local dx, dy = ax - px, ay - py
    return matan2(dx * a[3] + dy * a[4], dx * a[1] + dy * a[2])
end
Arrow._Bearing = Bearing   -- tests

local function Clear(ci, px, py, x, y)
    local Nav = ns.GPSNav
    return Nav and Nav.Straight and Nav.Straight(ci, px, py, x, y, IsIndoors and IsIndoors()) == true
end

-- How far the rest of the walk (from stretch s) strays from the line from
-- (px, py) to its spot d yards off, in yards.
local function Spread(path, s, px, py, tx, ty, d)
    if d < 1 then return 0 end
    local pts, far = path.pts, 0
    local ux, uy = (tx - px) / d, (ty - py) / d
    for v = s + 1, #pts / 2 do
        local off = mabs((pts[2 * v - 1] - px) * uy - (pts[2 * v] - py) * ux)
        if off > far then far = off end
    end
    return far
end
Arrow._Spread = Spread   -- the dev probe

-- Where the arrow points from where the player stands, and the yards left,
-- or nothing to point at.
local function Aim()
    local f = ns.GPSFollow.Now()
    if not f then return nil end
    aimCi = f.ci
    local px, py = f.px, f.py
    if f.ride then
        if f.straight > AT_RIDE then return nil end
        return px, py, f.tx, f.ty, f.straight
    end
    local path = f.path
    if not path then return px, py, f.tx, f.ty, f.straight end
    local left = mmax(0, path.len - f.along)
    -- A walk hardly longer than the line to the spot and never far beside
    -- it bends only round the grid's small blocks (a bush, a post):
    -- straight at the spot. Far off it, the walk is a way round.
    if left <= f.straight * NEAR_STRAIGHT and Spread(path, f.seg, px, py, f.tx, f.ty, f.straight) <= WIGGLE then
        return px, py, f.tx, f.ty, left
    end
    local ax, ay = ns.GPSFollow.PointAt(path, f.along + AHEAD, f.seg)
    -- Beside the walk: alongside it, up to LANE out, closing in on the
    -- last stretch so the spot itself is reached.
    local keep = f.off > 0.5 and mmin(1, LANE / f.off) * mmax(0, mmin(1, (left - AHEAD) / AHEAD)) or 0
    if keep > 0 then
        local sx, sy = (px - f.qx) * keep, (py - f.qy) * keep
        for _ = 1, 2 do
            if Clear(f.ci, px, py, ax + sx, ay + sy) then return px, py, ax + sx, ay + sy, left end
            sx, sy = sx / 2, sy / 2
        end
    end
    return px, py, ax, ay, left
end

Arrow._Aim = Aim   -- tests

local function SavePlace()
    local cx, cy = frame:GetCenter()
    if not (cx and cy) then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
    local db = DB()
    if db then db.gpsArrowPos = { x = cx, y = cy } end
end

local function Build()
    frame = CreateFrame("Frame", "EasyFindGPSArrow", UIParent)
    frame:SetSize(SIZE, SIZE)
    frame:SetFrameStrata("LOW")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(false)
    frame:RegisterForDrag("LeftButton")
    local db = DB()
    local pos = db and db.gpsArrowPos
    if pos and pos.x and pos.y then
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, HOME_Y)
    end
    art = frame:CreateTexture(nil, "ARTWORK")
    art:SetAllPoints(frame)
    art:SetTexture(TEX_ARROW)
    ns.GPSWorldPin.Tint(art, "arrow", 1)
    plate = ns.GPSWorldPin.NewPlate(frame)
    plate:SetPoint("TOP", frame, "BOTTOM", 0, -7)
    -- Clicks pass through to the world; Shift held, the arrow and a grip
    -- over the plate take them to move it. The plate's right-click stays.
    local grip = CreateFrame("Frame", nil, plate)
    grip:SetAllPoints(plate)
    grip:EnableMouse(false)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnMouseDown", function(_, button) plate:GetScript("OnMouseDown")(plate, button) end)
    grip:SetScript("OnMouseUp", function(_, button) plate:GetScript("OnMouseUp")(plate, button) end)
    -- Unlocked, the grip takes the mouse over the plate: its hover is the
    -- plate's (a cut step read whole), which the plate alone never got.
    grip:SetScript("OnEnter", function()
        local enter = plate:GetScript("OnEnter")
        if enter then enter(plate) end
    end)
    grip:SetScript("OnLeave", function()
        local leave = plate:GetScript("OnLeave")
        if leave then leave(plate) end
    end)
    -- The arrow's own right-click opens the plate's menu, the plate hidden
    -- too; its other clicks pass through to the world.
    local clicker = CreateFrame("Frame", nil, frame)
    clicker:SetAllPoints(frame)
    clicker:EnableMouse(false)
    clicker:SetScript("OnMouseDown", grip:GetScript("OnMouseDown"))
    clicker:SetScript("OnMouseUp", grip:GetScript("OnMouseUp"))
    local passing = false
    -- Unlocked (the plate's menu), it takes a plain drag; locked, Shift held.
    local function Unlocked() local d = DB() return d ~= nil and d.gpsArrowUnlocked == true end
    local function DragStart() if IsShiftKeyDown() or Unlocked() then frame:StartMoving() end end
    local function DragStop()
        frame:StopMovingOrSizing()
        SavePlace()
    end
    local function TakeMouse()
        local take = IsShiftKeyDown() or Unlocked()
        frame:EnableMouse(take)
        grip:EnableMouse(take)
        clicker:EnableMouse(passing and not take)
    end
    plate.isArrow = true
    function Arrow.SetUnlocked(on)
        local d = DB()
        if d then d.gpsArrowUnlocked = on or nil end
        TakeMouse()
    end
    function Arrow.ResetPlace()
        local d = DB()
        if d then d.gpsArrowPos = nil end
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, HOME_Y)
    end
    -- The game refuses the pass-through in a fight: built in one, the plate
    -- takes no clicks until it ends.
    local function PassClicks()
        local ok, why = ns.Utils.SafeCallMethod(plate, "SetPropagateMouseClicks", true)
        if why == "combat" then return frame:RegisterEvent("PLAYER_REGEN_ENABLED") end
        frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        plate:EnableMouse(ok)
        passing = ns.Utils.SafeCallMethod(clicker, "SetPropagateMouseClicks", true) and true or false
        TakeMouse()
    end
    frame:SetScript("OnDragStart", DragStart)
    frame:SetScript("OnDragStop", DragStop)
    grip:SetScript("OnDragStart", DragStart)
    grip:SetScript("OnDragStop", DragStop)
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then PassClicks() else TakeMouse() end
    end)
    frame:SetScript("OnShow", function(self)
        self:RegisterEvent("MODIFIER_STATE_CHANGED")
        TakeMouse()
    end)
    frame:SetScript("OnHide", function(self)
        self:UnregisterEvent("MODIFIER_STATE_CHANGED")
        self:EnableMouse(false)
    end)
    plate:EnableMouse(false)
    PassClicks()
    frame:Hide()
end

local function Update()
    local px, py, ax, ay, left = Aim()
    local facing = px and GetPlayerFacing and GetPlayerFacing()
    local bearing = facing and not (issecretvalue and issecretvalue(facing)) and Bearing(aimCi, px, py, ax, ay)
    if not bearing then
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    -- Facing turns from north toward west too; the art points down at rest.
    art:SetRotation(bearing - facing + mpi)
    local Pin = ns.GPSWorldPin
    local text, line, trip, note = Pin.PlateLines(Route(), left)
    plate:SetShown(text ~= nil)
    if text then Pin.FillPlate(plate, text, line, trip, note) end
    frame:Show()
end

local function Tick(_, dt)
    since = since + dt
    if since < THROTTLE then return end
    since = 0
    Update()
end

-- Whether the arrow points the way now: the beacon's own edge arrow stays
-- away while it does.
function Arrow:Guiding() return frame ~= nil and frame:IsShown() end

-- Target buttons under the plate: a guide's creatures while it sets them
-- (setTargets), and the NPC a route leads to near its spot. The game
-- targets and marks only on the player's press: a secure macro each. They
-- hang from UIParent at the plate's foot, so a fight locks nothing of the
-- arrow; in one they stay as they were.
local TARGET_YARDS, TARGET_EVERY, TARGET_MAX, ROW_H, ROW_GAP = 40, 0.5, 6, 24, 2
local KIND_ICON = { kill = "Interface\\Cursor\\Attack", talk = "Interface\\GossipFrame\\GossipGossipIcon" }
-- btns, rows, guide (set from outside), npc { dest, name, ci, wx, wy },
-- closed (a route's dest), closedNames (a guide's), ticker, menuAnchor;
-- uses (a guide's things to use), useBtns, closedUses (by row)
local target = { btns = {}, rows = {}, closedNames = {}, useBtns = {}, closedUses = {} }
local USE_MAX = 4
local USE_KINDS = { item = true, spell = true, macro = true }

function Arrow.TargetMark()
    local db = DB()
    local mark = db and db.gpsTargetMark
    if mark == nil then return 8 end
    return mark
end

-- The route's NPC on the walk in (40 yd) until arrival (8 yd beside it),
-- unless closed from its right-click menu.
-- The end of the leg being walked: a trip's next stop, else the route's.
local function LegEnd(route)
    for i = route.active or 1, #(route.steps or {}) do
        local stop = route.steps[i].tripStop
        if stop then return stop end
    end
    return route.dest
end

local function TargetNpc()
    local route = Route()
    -- A ghost on a death skip: the Spirit Healer its step leads to.
    local step = route and route.steps and route.steps[route.active or 1]
    local dest = route and not route.arrived and (step and step.spirit and step or LegEnd(route))
    if dest and dest.npc and dest ~= target.closed and dest.mapID and dest.x and ns.GPS.WorldPos then
        if not (target.npc and target.npc.dest == dest) then
            local ci, wx, wy = ns.GPS.WorldPos(dest.mapID, dest.x, dest.y)
            target.npc = ci and { dest = dest, name = dest.npc, ci = ci, wx = wx, wy = wy } or nil
        end
    else
        target.npc = nil
    end
    return target.npc
end

local function HideButton(btn)
    btn:Hide()
    btn:ClearAllPoints()
    btn:SetAttribute("type", nil)
    btn.macro, btn.label, btn.x, btn.y, btn.row, btn.use = nil, nil, nil, nil, nil, nil
end

local TargetTick

-- A right-click: a menu at the cursor, as the plate's. Close takes the row
-- it opened on, though the rows moved since: a route's NPC for that route,
-- a guide's creature until the guide's list changes.
local function TargetMenu(btn)
    local row = btn.row
    if not (row and ns.ShowTogglePopup) then return end
    local isUse = btn.isUse
    local dest = row.route and target.npc and target.npc.dest
    local anchor = target.menuAnchor
    if not anchor then
        anchor = CreateFrame("Frame", nil, UIParent)
        anchor:SetSize(1, 1)
        target.menuAnchor = anchor
    end
    local cx, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    anchor:ClearAllPoints()
    anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
    ns.ShowTogglePopup("EasyFindGPSTargetMenu", anchor, {
        { kind = "action", label = _G["CLOSE"] or "Close", onClick = function()
            if isUse then
                target.closedUses[row] = true
            elseif row.route then
                target.closed = dest
            else
                target.closedNames[row.name] = true
            end
            TargetTick()
        end },
    }, {})
end

local function StackButton(pool, i, name)
    -- starts shown: hidden at the end of its setup
    local btn = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    btn:SetFrameStrata("LOW")
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("useOnKeyDown", false)
    -- Right-click runs btn.rowMenu (the template's own-function action;
    -- "menu" is the template's unit menu).
    btn:SetAttribute("type2", "rowMenu")
    btn.rowMenu = TargetMenu
    local look = ns.GPSWorldPin.NewPlate(btn)
    look:SetAllPoints(btn)
    look:EnableMouse(false)
    look.text:ClearAllPoints()
    look.text:SetPoint("CENTER")
    btn.look = look
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    btn:Hide()
    pool[i] = btn
    return btn
end

local function TargetButton(i)
    return target.btns[i] or StackButton(target.btns, i, i == 1 and "EasyFindGPSTarget" or ("EasyFindGPSTarget" .. i))
end

local function UseButton(i)
    local btn = target.useBtns[i]
    if btn then return btn end
    btn = StackButton(target.useBtns, i, "EasyFindGPSUse" .. i)
    btn.isUse = true
    return btn
end

-- A row's words, its width for them and its place in the stack.
local function PlaceRow(btn, label, x, top)
    if btn.label ~= label then
        btn.label = label
        btn.look.text:SetText(label)
        btn:SetSize(btn.look.text:GetStringWidth() + 20, ROW_H)
    end
    if btn.x ~= x or btn.y ~= top then
        btn.x, btn.y = x, top
        btn:ClearAllPoints()
        btn:SetPoint("TOP", UIParent, "BOTTOMLEFT", x, top)
    end
    btn:Show()
end

-- The stack's top on UIParent: under the plate while the arrow shows; at
-- the arrow's own spot once it is gone (arrived, or its setting off).
local function TargetPlace()
    local under = frame and frame:IsShown() and (plate:IsShown() and plate or frame)
    local cx, bottom = under and under:GetCenter(), under and under:GetBottom()
    if cx and bottom then
        local s = under:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return math.floor(cx * s + 0.5), math.floor(bottom * s + 0.5) - 4
    end
    local db = DB()
    local pos = db and db.gpsArrowPos
    if pos and pos.x and pos.y then return pos.x, pos.y end
    local w, h = UIParent:GetSize()
    return w / 2, h / 2 + HOME_Y
end

-- The rows: the guide's creatures, then the route's NPC when near and not
-- one of them.
local function TargetRows()
    local rows = target.rows
    for i = #rows, 1, -1 do rows[i] = nil end
    local named = {}
    for _, t in ipairs(target.guide or {}) do
        if #rows < TARGET_MAX and not named[t.name] and not target.closedNames[t.name] then
            named[t.name] = true
            rows[#rows + 1] = t
        end
    end
    local npc = TargetNpc()
    if npc and not named[npc.name] and #rows < TARGET_MAX then
        local ci, px, py = ns.GPS.PlayerWorldPos()
        if ci == npc.ci and px and (px - npc.wx) ^ 2 + (py - npc.wy) ^ 2 <= TARGET_YARDS * TARGET_YARDS then
            rows[#rows + 1] = { name = npc.name, route = true }
        end
    end
    return rows
end

TargetTick = function()
    if InCombatLockdown() then return end
    local rows = TargetRows()
    local mark = Arrow.TargetMark()
    local markIcon = mark > 0 and ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. mark .. ":14|t ") or ""
    local x, y = TargetPlace()
    for i, row in ipairs(rows) do
        local btn = TargetButton(i)
        btn.row = row
        -- Cleared first: a name not found leaves no other unit to mark.
        local macro = "/cleartarget\n/targetexact " .. row.name
        if mark > 0 then macro = macro .. "\n/tm [@target,exists] !" .. mark end
        if btn.macro ~= macro then
            btn.macro = macro
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", macro)
        end
        -- The route's NPC alone keeps the plain word; among others, names.
        local kind = KIND_ICON[row.kind]
        local label = markIcon .. (kind and ("|T" .. kind .. ":14|t ") or "")
            .. ((row.route and #rows == 1) and (_G["TARGET"] or "Target") or row.name)
        PlaceRow(btn, label, x, y - (i - 1) * (ROW_H + ROW_GAP))
    end
    for i = #rows + 1, #target.btns do
        if target.btns[i]:IsShown() then HideButton(target.btns[i]) end
    end
    -- A guide's things to use, under the targets: the press uses the item,
    -- casts the spell or runs the macro.
    local used = 0
    if target.uses then
        for _, use in ipairs(target.uses) do
            if used < USE_MAX and not target.closedUses[use] then
                used = used + 1
                local btn = UseButton(used)
                btn.row = use
                if btn.use ~= use then
                    btn.use = use
                    btn:SetAttribute("type", use.kind)
                    btn:SetAttribute("item", use.kind == "item" and ("item:" .. use.id) or nil)
                    btn:SetAttribute("spell", use.kind == "spell" and (use.name or use.id) or nil)
                    btn:SetAttribute("macrotext", use.kind == "macro" and use.macro or nil)
                end
                PlaceRow(btn, use.label, x, y - (#rows + used - 1) * (ROW_H + ROW_GAP))
            end
        end
    end
    for i = used + 1, #target.useBtns do
        if target.useBtns[i]:IsShown() then HideButton(target.useBtns[i]) end
    end
    if not (target.guide or target.npc or target.uses) and target.ticker then
        target.ticker:Cancel()
        target.ticker = nil
    end
end

local function TargetSync()
    if (TargetNpc() or target.guide or target.uses) and not target.ticker then
        target.ticker = C_Timer.NewTicker(TARGET_EVERY, TargetTick)
    end
    TargetTick()
end

-- A guide's creatures, { name, kind = "kill" | "talk" } each, shown while
-- set; nil or none takes them away. A new list opens rows closed before.
function Arrow.SetTargets(list)
    target.guide = type(list) == "table" and #list > 0 and list or nil
    wipe(target.closedNames)
    TargetSync()
end

-- A guide's things to use for its step, each { kind = "item" | "spell" |
-- "macro", id, name, icon, macro (its text) }: a button under the target
-- rows while set; nil or none takes them away. One with no kind or nothing
-- to press is left out.
function Arrow.SetUses(list)
    local uses
    for _, use in ipairs(type(list) == "table" and list or {}) do
        local ok = type(use) == "table" and USE_KINDS[use.kind]
            and (use.kind == "macro" and type(use.macro) == "string"
                or use.kind == "item" and type(use.id) == "number"
                or use.kind == "spell" and (use.name or use.id) ~= nil)
        if ok then
            use.label = (use.icon and ("|T" .. use.icon .. ":14|t ") or "") .. (use.name or _G["USE"] or "Use")
            uses = uses or {}
            uses[#uses + 1] = use
        end
    end
    target.uses = uses
    wipe(target.closedUses)
    TargetSync()
end

_G["BINDING_HEADER_EASYFIND_GPS"] = "EasyFind GPS"
_G["BINDING_NAME_CLICK EasyFindGPSTarget:LeftButton"] = ns.L["GPS_TARGET_BIND"]

-- A route change or the option flipped: runs only while there is a way to point.
function Arrow:Refresh()
    local route = Route()
    local on = Enabled() and route ~= nil and not route.arrived and not route.untracked
    if on then
        since = 0
        driver:SetScript("OnUpdate", Tick)
        Update()
    else
        driver:SetScript("OnUpdate", nil)
        if frame then frame:Hide() end
    end
    TargetSync()
end

driver = CreateFrame("Frame")
Arrow._driver = driver   -- dev tools
