-- The trip: a route's stops in order, planned leg by leg, and the map
-- page's editor for them: the start first, each stop a field with the
-- map search under it, a grip to drag a stop to another place, the
-- field's own clear button to drop it, and a row to add one.
local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).tooOld then return end

local Trip = {}
ns.GPSTrip = Trip

local L = ns.L
local Utils = ns.Utils
local mmax, mmin, msqrt = math.max, math.min, math.sqrt
local tremove, tinsert, tsort = table.remove, table.insert, table.sort
local sformat = string.format

local ROW_H, ADD_H, MARK, GRIP_W, DROP_ROWS, DROP_ROW_H = 30, 26, 16, 9, 6, 20
local ALONG_H, ALONG_GAP = 20, 16   -- the along click's own line; its room off the add row's words
local DROP_PAD = 4
local TEX_RING = "Interface\\AddOns\\EasyFind_GPS\\textures\\clock-ring"   -- a 1.5 px line at 16 px
local PIN = 22
local RING = 13   -- a ring's size; MARK stays the column the marks center in
local DIM, RING_GREY = { 0.55, 0.55, 0.58 }, { 0.8, 0.8, 0.82 }
local ALONG_MAX = 300   -- the most seconds a stop may add and be along the way
local ALONG_ROWS = 30

local function Route() local g = ns.GPS return g and g.CurrentRoute and g.CurrentRoute() end

-- A route planned before stops were kept has its one destination.
local function Stops(route)
    route.stops = route.stops or { route.dest }
    return route.stops
end

-- The world spot a stop is reached at, the leg after it starts there.
local function StopPoint(stop)
    local ci, wx, wy = ns.GPS.WorldPos(stop.mapID, stop.x or 0.5, stop.y or 0.5)
    if not ci then return nil end
    return { ci = ci, wx = wx, wy = wy, m = stop.mapID, x = stop.x or 0.5, y = stop.y or 0.5, name = stop.name }
end

-- The stops planned leg by leg, the first from startFrom (as BuildRoute
-- takes it), each after from the stop before: the steps joined, the times
-- added, the first leg's advice. Nil when a leg has no way.
function Trip.Build(stops, via, avoid, quick, draw, startFrom)
    local g = ns.GPS
    local steps, total, priced, advice = {}, 0, true, nil
    local from = startFrom
    for k = 1, #stops do
        local legSteps, legTotal, legAdvice = g:BuildRoute(stops[k], k == 1 and via or nil, avoid, quick, draw, from)
        if not legSteps then return nil end
        for i = 1, #legSteps do steps[#steps + 1] = legSteps[i] end
        -- The leg's last step knows the trip's stop it reaches: the map marks
        -- it with the stop's own icon (step.stop is a crossing's stop number).
        if #legSteps > 0 then legSteps[#legSteps].tripStop = stops[k] end
        if legTotal then total = total + legTotal else priced = false end
        advice = advice or legAdvice
        from = StopPoint(stops[k])
        if not from and k < #stops then return nil end
    end
    return steps, priced and total or nil, advice
end

-- The trip planned again from its stops, from the start as set.
function Trip.Navigate(opts)
    local g = ns.GPS
    local route = Route()
    if not route then return false end
    local stops = Stops(route)
    if #stops == 0 then return false end
    local list = {}
    for i = 1, #stops do list[i] = stops[i] end
    local dest = list[#list]
    if not (opts and opts.quiet) then g:Open() end
    g:Plan(dest.name, function() return Trip.Build(list, nil, route.wayAvoid, true, "first") end,
        function(steps, total, advice)
            if steps then g.Navigated(dest, steps, total, advice, list) end
        end)
    return true
end

function Trip.Add(dest)
    local route = Route()
    if not route then return end
    local stops = Stops(route)
    stops[#stops + 1] = dest
    Trip.Navigate({ quiet = true })
end

-- A stop on the way: before the destination.
function Trip.Insert(dest)
    local route = Route()
    if not route then return end
    local stops = Stops(route)
    tinsert(stops, mmax(1, #stops), dest)
    Trip.Navigate({ quiet = true })
end

function Trip.Replace(i, dest)
    local route = Route()
    if not (route and Stops(route)[i]) then return end
    route.stops[i] = dest
    Trip.Navigate({ quiet = true })
end

function Trip.Remove(i)
    local route = Route()
    if not (route and Stops(route)[i]) then return end
    tremove(route.stops, i)
    if #route.stops == 0 then ns.GPS:Clear({ stay = true }) else Trip.Navigate({ quiet = true }) end
end

-- Stop i goes to place j.
function Trip.Move(i, j)
    local route = Route()
    local stops = route and Stops(route)
    if not (stops and stops[i] and j >= 1 and j <= #stops) or i == j then return end
    tinsert(stops, j, tremove(stops, i))
    Trip.Navigate({ quiet = true })
end

-- The player's own position, as the start row stands for it.
local HERE = {}

-- Where the player stands now, as a place a trip can pass through.
local function HerePlace()
    local m = C_Map.GetBestMapForUnit("player")
    local pos = m and C_Map.GetPlayerMapPosition(m, "player")
    if not pos then return nil end
    local x, y = pos:GetXY()
    return { name = L["GPS_TRIP_FROM"], mapID = m, x = x, y = y }
end

-- The whole trip in order, the start first (1), moved from i to j. A place
-- moved to the top becomes the start; the player's own position moved down
-- becomes a stop where the player stands now.
function Trip.Reorder(i, j)
    local g = ns.GPS
    local route = Route()
    local stops = route and Stops(route)
    if not stops or i == j then return end
    local order = { (g.Start and g.Start()) or HERE }
    for k = 1, #stops do order[k + 1] = stops[k] end
    if not (order[i] and j >= 1 and j <= #order) then return end
    tinsert(order, j, tremove(order, i))
    local list = {}
    for k = 2, #order do
        local p = order[k] == HERE and HerePlace() or order[k]
        if p and p ~= HERE then list[#list + 1] = p end
    end
    if #list == 0 then return end
    for k = #stops, 1, -1 do stops[k] = nil end
    for k = 1, #list do stops[k] = list[k] end
    local first = order[1]
    if first == HERE then g:SetStart(nil, true)
    else g:SetStart({ name = first.name, mapID = first.mapID, x = first.x, y = first.y }, true) end
    Trip.Navigate({ quiet = true })
end

-- Along the way ------------------------------------------------------------

local function World(p)
    if not p then return nil end
    if p.ci and p.wx then return p.ci, p.wx, p.wy end
    return ns.GPS.WorldPos(p.m, p.x, p.y)
end

-- A piece of the way, flat: ci, a, b, the seconds a yard takes, then the
-- circle (middle, radius squared) holding every spot within ALONG_MAX of
-- it, and its length.
local function Piece(out, ci, ax, ay, bx, by, pace)
    if ax == bx and ay == by then return end
    local len = msqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
    local reach = (len + ALONG_MAX / pace) / 2
    local n = #out
    out[n + 1], out[n + 2], out[n + 3], out[n + 4], out[n + 5], out[n + 6] = ci, ax, ay, bx, by, pace
    out[n + 7], out[n + 8], out[n + 9], out[n + 10] = (ax + bx) / 2, (ay + by) / 2, reach * reach, len
end

-- The walks of the route ahead as straight pieces: as drawn, straight
-- where not drawn yet, the current one from the player on. Flights,
-- boats and portals are left out: no stop on those.
local function Corridor(route)
    local out = {}
    local Engine, Follow = ns.GPSRoute, ns.GPSFollow
    if not (Engine and Follow and route.steps) then return out end
    local walkPace = 1 / Engine.GroundSpeed(ns.GPSData)
    local now = Follow.Now and Follow.Now()
    for i = route.active or 1, #route.steps do
        local s = route.steps[i]
        local ci, sx, sy = Follow.StartOf(route, i)
        local tci, tx, ty = World(s.go or s.arrive)
        if s.kind == "travel" and ci and ci == tci then
            local path, first, ax, ay
            if now and now.route == route and now.index == i and now.path then
                path, first, ax, ay = now.path, (now.seg or 0) + 1, now.px, now.py
            else
                path = not s.fly and Engine.WalkPath(ci, sx, sy, tx, ty, true, s.near) or nil
                first, ax, ay = 2, sx, sy
                if path then ax, ay = path.pts[1], path.pts[2] end
            end
            -- A flown leg goes straight, at the pace it was priced at.
            local straight = s.fly and msqrt((tx - ax) ^ 2 + (ty - ay) ^ 2)
            local pace = path and s.sec and s.sec > 0 and path.len > 1 and s.sec / path.len
                or straight and straight > 1 and s.sec and s.sec / straight or walkPace
            if path then
                local pts = path.pts
                for v = first, #pts / 2 do
                    Piece(out, ci, ax, ay, pts[2 * v - 1], pts[2 * v], pace)
                    ax, ay = pts[2 * v - 1], pts[2 * v]
                end
            else
                Piece(out, ci, ax, ay, tx, ty, pace)
            end
        end
    end
    return out
end

-- The seconds a stop at (ci, x, y) adds to the way: the least extra way
-- through it off any piece, at that piece's pace; nil past ALONG_MAX.
local function DetourOf(c, ci, x, y)
    local best
    for p = 1, #c, 10 do
        if c[p] == ci then
            local dx, dy = x - c[p + 6], y - c[p + 7]
            if dx * dx + dy * dy <= c[p + 8] then
                local extra = msqrt((x - c[p + 1]) ^ 2 + (y - c[p + 2]) ^ 2)
                    + msqrt((x - c[p + 3]) ^ 2 + (y - c[p + 4]) ^ 2) - c[p + 9]
                local sec = extra * c[p + 5]
                if not best or sec < best then best = sec end
            end
        end
    end
    if best and best <= ALONG_MAX then return mmax(0, best) end
    return nil
end

-- For the route ahead: a function of a world spot giving the seconds a
-- stop there adds, nil when it is not along the way. Nil with no way left.
function Trip.Detour(route)
    local c = Corridor(route)
    if #c == 0 then return nil end
    return function(ci, x, y) return DetourOf(c, ci, x, y) end
end

local alongList, alongSec, alongFound, alongNames = {}, {}, {}, {}
local function LeastOutOfTheWay(a, b) return alongSec[a] < alongSec[b] end

local function KeepAlong(r, detour)
    local g = ns.GPS
    if alongSec[r] or not (r.x and r.y) or not g:CanNavigate(r) then return end
    local ci, wx, wy = g.WorldPos(r.zoneMapID or r.mapID, r.x, r.y)
    local sec = ci and detour(ci, wx, wy)
    if sec then
        alongList[#alongList + 1] = r
        alongSec[r] = sec
    end
end

-- Places for a typed name along the route ahead, the least out of the way
-- first, and by place the seconds a stop there adds.
function Trip.AlongPlaces(q)
    wipe(alongList)
    wipe(alongSec)
    local route = Route()
    local detour = route and not route.arrived and Trip.Detour(route)
    if not detour then return alongList, alongSec end
    -- The map search's places, less its creatures (those near the player);
    -- then the creatures, each at its spot nearest the way, but for those
    -- a place kept already names (EasyFind's own Innkeeper Renee).
    local places = ns.GPS.SearchPlaces and ns.GPS.SearchPlaces(q)
    for i = 1, places and #places or 0 do
        if not places[i].catalog then KeepAlong(places[i], detour) end
    end
    wipe(alongNames)
    for i = 1, #alongList do
        local r = alongList[i]
        local low = r.nameLower or (r.name and r.name:lower())
        if low then alongNames[low] = true end
    end
    local npcs = ns.Npcs
    wipe(alongFound)
    if npcs and npcs.Append then npcs.Append(alongFound, alongNames, q, nil, nil, detour) end
    for i = 1, #alongFound do KeepAlong(alongFound[i], detour) end
    tsort(alongList, LeastOutOfTheWay)
    for i = #alongList, ALONG_ROWS + 1, -1 do alongList[i] = nil end
    return alongList, alongSec
end

-- What a stop adds, beside its place.
function Trip.AddsText(sec)
    if sec < 60 then return L["GPS_ALONG_ON_WAY"] end
    return sformat(L["GPS_ALONG_ADDS_FMT"], ns.GPS.EtaText(sec))
end

-- The along-route tag at a search box's right end beside typed text (the
-- empty box's hint says it then, never under it); typed text stops short.
function Trip.Tag(box, on)
    local tag = box.alongTag
    if not tag then
        if not on then return end
        tag = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tag:SetPoint("RIGHT", box, "RIGHT", -22, 0)
        tag:SetText(L["GPS_ALONG_TAG"])
        tag:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
        tag._efOwnColor = true
        box.alongTag = tag
        box.tagInsets = { box:GetTextInsets() }
        box:HookScript("OnTextChanged", function(self)
            self.alongTag:SetShown(self.alongOn == true and (self:GetText() or "") ~= "")
        end)
    end
    box.alongOn = on and true or nil
    tag:SetShown(on and (box:GetText() or "") ~= "")
    local i = box.tagInsets
    box:SetTextInsets(i[1], i[2] + (on and (tag:GetStringWidth() + 8) or 0), i[3], i[4])
end

-- A hit row's note: what a stop there adds.
function Trip.Note(row)
    local note = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    note:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
    note._efOwnColor = true
    row.text:SetPoint("RIGHT", note, "LEFT", -6, 0)
    row.note = note
    return note
end

-- The editor ---------------------------------------------------------------

local Editor = {}

local function DropRow(ed, i)
    local row = ed.dropRows[i]
    if row then return row end
    row = CreateFrame("Button", nil, ed.drop)
    row:SetHeight(DROP_ROW_H)
    row:SetPoint("LEFT", ed.drop, "LEFT", DROP_PAD, 0)
    row:SetPoint("RIGHT", ed.drop, "RIGHT", -DROP_PAD, 0)
    Utils.InstallMenuRowHighlight(row)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    Trip.Note(row)
    if ed.px and ns.GPS.SizeFont then
        ns.GPS.SizeFont(row.text, ed.px)
        ns.GPS.SizeFont(row.note, ed.px)
    end
    row:SetScript("OnClick", function(self) if self.data then ed:Pick(self.data) end end)
    ed.dropRows[i] = row
    return row
end

-- The places found for what was typed: in a window with a list of its
-- own, in the steps' place; else under the field being edited. secs,
-- along the way: by place, the seconds a stop there adds. query: what
-- was typed, so the window's list starts over for a new one.
function Editor:ShowHits(results, secs, query)
    local frame = self.frame
    if frame.ShowHits then
        self.drop:Hide()
        frame.hitsFor = (results and self.editing) and self or nil
        frame:ShowHits(frame.hitsFor and results or nil, secs, query)
        return
    end
    local n = 0
    for i = 1, results and #results or 0 do
        local r = results[i]
        if n < DROP_ROWS and ns.GPS:CanNavigate(r) then
            n = n + 1
            local row = DropRow(self, n)
            row.data = r
            row:SetPoint("TOP", self.drop, "TOP", 0, -DROP_PAD - (n - 1) * DROP_ROW_H)
            local where = r.matchNote or r.zoneName or r.parentName or r.category
            row.text:SetText((r.name or "?") .. (where and where ~= r.name and ("  |cff999999" .. tostring(where) .. "|r") or ""))
            row.text:SetTextColor(1, 1, 1)
            row.note:SetText(secs and secs[r] and Trip.AddsText(secs[r]) or "")
            row:EnableMouse(true)
            row:Show()
        end
    end
    -- Searched and nothing found: says so, as the window does.
    if results and n == 0 then
        n = 1
        local row = DropRow(self, 1)
        row.data = nil
        row:SetPoint("TOP", self.drop, "TOP", 0, -DROP_PAD)
        row.text:SetText(L["MAP_NO_MATCHES"])
        row.text:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
        row.note:SetText("")
        row:EnableMouse(false)
        row:Show()
    end
    for i = n + 1, #self.dropRows do self.dropRows[i]:Hide() end
    if ns.ShadeText then ns.ShadeText(self.drop) end
    self.drop:SetHeight(mmax(1, n * DROP_ROW_H + DROP_PAD * 2))
    self.drop:SetShown(n > 0 and self.editing ~= nil)
end

-- The finds put away, wherever they show.
function Editor:DropHits()
    self.drop:Hide()
    local frame = self.frame
    if frame.hitsFor == self then
        frame.hitsFor = nil
        frame:ShowHits(nil)
    end
end

-- Per-frame work only while a drag or a pending close needs it.
function Editor:Watch()
    self:SetScript("OnUpdate", (self.drag or self.closeAt) and self.OnUpdate or nil)
end

function Editor:Open(row)
    self.editing = row
    row.typed = nil
    self.closeAt = nil
    self:Watch()
    self.drop:ClearAllPoints()
    self.drop:SetPoint("TOPLEFT", row.box, "BOTTOMLEFT", 0, -2)
    self.drop:SetPoint("RIGHT", row.box, "RIGHT", 0, 0)
    self:ShowRecentOrNone()
end

-- An empty field: the last searches, as the map's search box shows them.
function Editor:ShowRecentOrNone()
    local frame = self.frame
    if frame.ShowRecent and frame:ShowRecent(self) then return end
    self:ShowHits(nil)
end

-- Closed: the field reads what it stands for again; an add row with
-- nothing chosen goes.
function Editor:Close()
    local row = self.editing
    self.editing = nil
    self.closeAt = nil
    self:Watch()
    self:DropHits()
    if row and row.adding then self.adding, self.along = nil, nil end
    self:Refresh(Route())
end

-- A click on a hit comes after the field loses focus: the close waits.
function Editor:CloseSoon()
    self.closeAt = GetTime() + 0.25
    self:Watch()
end

function Editor:Typed(row, text)
    if self.editing ~= row then self:Open(row) end
    row.typed = text ~= "" or nil
    if text == "" then self:ShowRecentOrNone() return end
    if self.pending then return end
    self.pending = true
    Utils.SafeAfter(0.15, function()
        self.pending = nil
        local box = self.editing and self.editing.box
        local q = box and box:GetText() or ""
        if q == "" or not ns.GPS.SearchPlaces then return end
        if self.along and self.editing.adding then
            local results, secs = Trip.AlongPlaces(q)
            self:ShowHits(results, secs, q)
        else
            self:ShowHits(ns.GPS.SearchPlaces(q), nil, q)
        end
    end)
end

-- The start's field, focused to type a place to start from; false with
-- no route, where the trip has no start field.
function Editor:FocusStart()
    local row = self.orderRows[1]
    if not (row and row.index == 0) then return false end
    row.box._blockAutoFocus = nil
    row.box:SetFocus()
    return true
end

-- A field before the destination whose places are those along the way.
function Editor:SearchAlong()
    self.adding, self.along = "focus", true
    self:Refresh(Route())
end

-- The add row's along click: at its right end, or on a line of its own
-- under its words where the two do not fit; the height that line adds.
-- Shown while there is a way ahead.
function Editor:LayAlong(route)
    local along, text, add = self.alongBtn, self.alongText, self.add
    along:SetShown(route ~= nil and not route.arrived)
    if not along:IsShown() then return 0 end
    local left = GRIP_W + MARK / 2 + RING / 2 + 8   -- where the add row's words start
    local w = text:GetStringWidth() or 0
    local room = (add:GetWidth() or 0) - left
    along:ClearAllPoints()
    if room <= 0 or (self.addText:GetStringWidth() or 0) + ALONG_GAP + w <= room then
        along:SetPoint("TOPRIGHT", add, "TOPRIGHT", 0, 0)
        along:SetWidth(w + 4)
        along:SetHeight(ADD_H)
        text:SetJustifyH("RIGHT")
        return 0
    end
    along:SetPoint("TOPLEFT", add, "BOTTOMLEFT", left, 0)
    along:SetPoint("TOPRIGHT", add, "BOTTOMRIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    local h = mmax(ALONG_H, (text:GetStringHeight() or 0) + 6)
    along:SetHeight(h)
    return h
end

function Editor:Pick(data)
    local row = self.editing
    if not row then return end
    local g = ns.GPS
    local index = row.index
    -- What was typed joins the map search's recent searches, as a pick
    -- from its own list does.
    if ns.MapTab and ns.MapTab.PushRecentSearch then ns.MapTab:PushRecentSearch(row.box:GetText()) end
    row.box:ClearFocus()
    self.editing, self.closeAt = nil, nil
    self:DropHits()
    if index == 0 then
        g:SetStart(data)
    elseif row.adding and not Route() then
        -- The first field of all: the route starts here, where it was typed.
        self.adding = nil
        g:NavigateTo(data, { quiet = true })
    elseif row.adding and self.along then
        self.adding, self.along = nil, nil
        Trip.Insert(g.Destination(data))
    elseif row.adding then
        self.adding = nil
        Trip.Add(g.Destination(data))
    else
        Trip.Replace(index, g.Destination(data))
    end
end

-- The field's own clear button drops the stop, or sets the start back
-- to the player; while a place is being typed it only clears the text.
function Editor:Cleared(row)
    -- Mid-typing the x clears the words only; a field merely focused
    -- still stands for its stop, and the x drops that stop.
    if self.editing == row and row.typed then return end
    if row.index == 0 then
        ns.GPS:SetStart(nil)
    elseif row.adding then
        self.adding, self.along = nil, nil
        self:Refresh(Route())
    else
        Trip.Remove(row.index)
    end
end

-- A row's place: its top y down from the editor's, and its right end.
-- The first row shares its line with the header's buttons: the window's
-- fold and close, the page's pop-out centered on it 6 in from the edge
-- (the editor stops 14 short). On the page every row ends where the
-- first does, 5 short of the button.
local function Lay(ed, row, slot, y, planned)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", ed, "TOPLEFT", 0, -y)
    local frame, btn = ed.frame, ed.frame.popoutBtn
    if btn then
        row:SetPoint("TOPRIGHT", ed, "TOPRIGHT", -(btn:GetWidth() + 5 - 8), -y)
    elseif slot == 1 and not (frame.buttonsAbove and planned) then
        row:SetPoint("RIGHT", ed, "RIGHT", -(frame.firstRowRight or mmax(0, (frame.padRight or 0) - 14)), 0)
    else
        row:SetPoint("RIGHT", ed, "RIGHT", 0, 0)
    end
end

-- Dragging a row by its grip: the row rides with the cursor and the
-- others step into the order its drop would make; the drop makes it. The
-- rows' places are taken as the drag starts and the cursor read against
-- them, the rows themselves being on the move.
local function CursorY(ed)
    local _, cy = GetCursorPosition()
    return cy / ed:GetEffectiveScale()
end

-- The order position the dragged row would take: before the first slot
-- whose middle the cursor is above.
function Editor:Target()
    local cy, top = CursorY(self), self:GetTop() or 0
    local slots, i = self.slots, self.drag
    local j = #slots + 1
    for k = 1, #slots do
        if cy > top - slots[k] - self.slotH / 2 then j = k break end
    end
    return j > i and j - 1 or j
end

function Editor:DragStart(row)
    if self.drag then return end
    local top = self:GetTop() or 0
    self.slots = {}
    for k = 1, #self.orderRows do self.slots[k] = top - (self.orderRows[k]:GetTop() or top) end
    self.slotH = row:GetHeight()
    self.drag, self.dragRow, self.dropAt = row.index + 1, row, row.index + 1
    self.grab = (row:GetTop() or top) - CursorY(self)
    self.level = row:GetFrameLevel()
    row:SetFrameLevel(self.level + 10)
    row:SetAlpha(0.8)
    self:Watch()
end

-- The drop: the trip in the order shown, or the rows back in their places.
function Editor:DragStop()
    local i, row = self.drag, self.dragRow
    if not i then return end
    local j = self.dropAt
    self.drag, self.dragRow, self.slots = nil, nil, nil
    row:SetFrameLevel(self.level)
    row:SetAlpha(1)
    self:Watch()
    if j == i then self:Refresh(Route()) else Trip.Reorder(i, j) end
end

-- The rows as the drag stands: the dragged one under the cursor, within
-- the rows' span, the others in the order its drop would make.
function Editor:LayDrag()
    local i, n = self.drag, #self.slots
    if #self.orderRows ~= n then
        self.dropAt = i
        self:DragStop()
        return
    end
    local j = self:Target()
    self.dropAt = j
    for p = 1, n do
        if p ~= i then
            local slot = p
            if p < i and p >= j then slot = p + 1 elseif p > i and p <= j then slot = p - 1 end
            Lay(self, self.orderRows[p], slot, self.slots[slot], true)
        end
    end
    local y = (self:GetTop() or 0) - (CursorY(self) + self.grab)
    Lay(self, self.dragRow, j, mmax(self.slots[1], mmin(self.slots[n], y)), true)
end

-- Each frame: the drag's rows; a pending close once a hit's click had
-- its chance.
function Editor:OnUpdate()
    -- The grip shows on the row under the cursor, while a drag holds it.
    for i = 1, #self.orderRows do
        local r = self.orderRows[i]
        r.grip:SetShown(r.canDrag and (self.drag == r.index + 1 or r:IsMouseOver()))
    end
    -- The button up ends the drag whether or not the grip heard the drop.
    if self.drag then
        if IsMouseButtonDown("LeftButton") then self:LayDrag() else self:DragStop() end
    end
    if self.closeAt and GetTime() >= self.closeAt then
        local frame = self.frame
        if (self.drop:IsShown() and self.drop:IsMouseOver())
            or (frame.hitsFor == self and frame.hitList:IsMouseOver()) then
            self.closeAt = GetTime() + 0.25
        else
            self:Close()
        end
    end
end

-- A row's mark, right of the room the drag grip takes: the start's open
-- ring, a stop's pin, the add row's ring with a plus. Three dots above a
-- row join it to the one before.
local function Mark(parent)
    local mark = parent:CreateTexture(nil, "ARTWORK")
    mark:SetSize(MARK, MARK)
    mark:SetPoint("CENTER", parent, "LEFT", GRIP_W + MARK / 2, 0)
    return mark
end

-- A field in the theme's own well, not the stock search art: the dark
-- inset its edit boxes use (a button's fill read washed out under the
-- dim placeholder), ringed in the theme's line color, softened (its
-- results border is no color on Classic: white, a tint for its art).
-- Repainted with the theme.
-- On a light theme a near-white well in the window's border color.
local wells = {}
local function PaintWell(well)
    local palette = ns.ACTIVE_UI_PALETTE
    local line = palette and palette.separator or { 0.42, 0.42, 0.42 }
    local ring = palette and palette.borderColor or { line[1], line[2], line[3], 0.7 }
    if palette and ns.GPS.Ink(well.owner).light then
        local c = palette.windowFillTop or palette.windowFill or { 0.9, 0.9, 0.9 }
        ns.PaintRingedWell(well, palette.backdropBorder or ring,
            { c[1] + (1 - c[1]) * 0.8, c[2] + (1 - c[2]) * 0.8, c[3] + (1 - c[3]) * 0.8 })
        return
    end
    ns.PaintRingedWell(well, ring, ns.EDITBOX_INSET_FILL or { 0.02, 0.02, 0.03 })
end

-- The field's glass: the client's gray, white once in use; the ink's on a
-- light theme, where white is lost.
local function TintGlass(box, ink)
    if not box.searchIcon then return end
    local on = box:HasFocus() or (box:GetText() or "") ~= ""
    if ink.light then
        local c = ink.field
        box.searchIcon:SetVertexColor(c[1], c[2], c[3])
    else
        local v = on and 1 or 0.6
        box.searchIcon:SetVertexColor(v, v, v)
    end
end
if ns.ApplyUITheme then
    Utils.PostHook(ns, "ApplyUITheme", function()
        for i = 1, #wells do PaintWell(wells[i]) end
    end)
end

local function Field(ed, i)
    local row = ed.rows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, ed)
    row:SetHeight(ROW_H)
    row.mark = Mark(row)
    row.dots = {}
    for k = 1, 3 do
        local dot = Utils.CreateDot(row, 2.5, DIM)
        dot:SetPoint("CENTER", row, "TOPLEFT", GRIP_W + MARK / 2, (2 - k) * 3)
        row.dots[k] = dot
    end
    -- The drag grip: six dots left of the mark, the grip itself the whole
    -- margin up to the field, mark and all, so a press lands on it; shown
    -- while the cursor is on a row that can move.
    local grip = CreateFrame("Button", nil, row)
    grip:SetWidth(GRIP_W + MARK)
    grip:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    grip:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    local dots = CreateFrame("Frame", nil, grip)
    dots:SetSize(GRIP_W, 20)
    dots:SetPoint("LEFT", grip, "LEFT", 0, 0)
    Utils.AddGripDots(dots, DIM)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function() ed:DragStart(row) end)
    grip:SetScript("OnDragStop", function() ed:DragStop() end)
    -- Shown while the cursor is on the row (the grip is part of it), or
    -- while a drag holds it; no per-frame poll. The row takes the cursor's
    -- motion, not its clicks, so leaving it from any spot is heard.
    local function SyncGrip()
        grip:SetShown(row.canDrag and (ed.drag == row.index + 1 or row:IsMouseOver()))
    end
    row.SyncGrip = SyncGrip
    row:HookScript("OnEnter", SyncGrip)
    row:HookScript("OnLeave", SyncGrip)
    -- After the hooks, which left its clicks on (measured): a press on
    -- the row's free space drags the window.
    if row.SetMouseClickEnabled then
        row:SetMouseMotionEnabled(true)
        row:SetMouseClickEnabled(false)
    else
        row:EnableMouse(true)
    end
    grip:SetScript("OnEnter", SyncGrip)
    grip:SetScript("OnLeave", SyncGrip)
    if Utils.AttachDelayedTooltip then
        Utils.AttachDelayedTooltip(grip, "ANCHOR_LEFT", function() return L["GPS_TRIP_DRAG"] end)
    end
    grip:Hide()
    row.grip = grip
    local box = CreateFrame("EditBox", nil, row, "SearchBoxTemplate")
    box:SetHeight(20)
    box:SetPoint("LEFT", row, "LEFT", GRIP_W + MARK + 8, 0)
    box:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(60)
    ns.Utils.ReleaseFocusOnOutsideClick(box)
    -- Beside the world map the fields keep the client's own search box, as
    -- the map tab's search does; the theme's well is for EasyFind's window.
    if ns.CreateRingedWell and not ed.frame.gameLook then
        for _, key in ipairs({ "Left", "Middle", "Right" }) do
            if box[key] then box[key]:SetAlpha(0) end
        end
        -- The stock art reached 5 left of the box, round its search glass.
        local well = CreateFrame("Frame", nil, row)
        well:SetPoint("TOPLEFT", box, "TOPLEFT", -5, 1)
        well:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, -1)
        well:SetFrameLevel(row:GetFrameLevel())
        well.owner = ed.frame
        ns.CreateRingedWell(well, 6)
        box:SetFrameLevel(well:GetFrameLevel() + 2)   -- over the ring and its inset
        PaintWell(well)
        wells[#wells + 1] = well
    end
    if box.Instructions then
        box.Instructions:SetWordWrap(false)
        box.Instructions._efOwnColor = true
    end
    row.textColor = { box:GetTextColor() }
    -- The client focuses a fresh visible EditBox on its own; refuse that.
    box._blockAutoFocus = true
    box:HookScript("OnEditFocusGained", function(self)
        if self._blockAutoFocus then self:ClearFocus() return end
        self:HighlightText()
        ed:Open(row)
    end)
    box:HookScript("OnMouseDown", function(self) self._blockAutoFocus = nil end)
    box:HookScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- After the client's own focus scripts, which tint the glass.
    box:HookScript("OnEditFocusGained", function(self) TintGlass(self, ns.GPS.Ink(ed.frame)) end)
    box:HookScript("OnEditFocusLost", function(self) TintGlass(self, ns.GPS.Ink(ed.frame)) end)
    box:HookScript("OnEnterPressed", function()
        local frame = ed.frame
        local first = (frame.hitsFor == ed and frame.places:FirstPlaceRow()) or ed.dropRows[1]
        if first and first:IsShown() and first.data then ed:Pick(first.data) end
    end)
    box:HookScript("OnEditFocusLost", function() ed:CloseSoon() end)
    box:HookScript("OnTextChanged", function(self, user) if user then ed:Typed(row, self:GetText() or "") end end)
    if box.clearButton then
        box.clearButton:HookScript("OnClick", function() ed:Cleared(row) end)
        box.clearButton:HookScript("OnEnter", SyncGrip)
        box.clearButton:HookScript("OnLeave", SyncGrip)
    end
    box:HookScript("OnEnter", SyncGrip)
    box:HookScript("OnLeave", SyncGrip)
    row.box = box
    ed.rows[i] = row
    return row
end

-- The rows as the route stands: the start, each stop, the add row. Text
-- in the page's size, the one the steps follow.
function Editor:Refresh(route)
    local g = ns.GPS
    local stops = route and Stops(route) or {}
    local start = g.Start and g.Start()
    local px = g.MapTextPx and g.MapTextPx(self.frame)
    self.px = px
    local ink = g.Ink(self.frame)
    local dim = ink.dim
    if self.PaintAdd then self:PaintAdd(ink) end
    local boxH = mmax(20, (px or 12) + 8)
    local rowH = boxH + 10
    local y, n = 0, 0
    local function Show(index, text, placeholder, pin, adding)
        n = n + 1
        local row = Field(self, n)
        row.index, row.adding = index, adding or nil
        if self.editing ~= row then
            row.box:SetText(text or "")
            if row.box.Instructions then row.box.Instructions:SetText(placeholder or "") end
        end
        Trip.Tag(row.box, adding and self.along or false)
        if row.box.alongTag then row.box.alongTag:SetTextColor(dim[1], dim[2], dim[3], 1) end
        -- On a light theme the hint, the words, the glass and the X are one
        -- blue, the theme's a shade darker; the dim hint otherwise.
        local hint = ink.light and ink.field or dim
        if row.box.Instructions then row.box.Instructions:SetTextColor(hint[1], hint[2], hint[3], 1) end
        local typed = ink.light and ink.field or row.textColor
        row.box:SetTextColor(typed[1], typed[2], typed[3], 1)
        TintGlass(row.box, ink)
        -- The along field keeps its X while open, typed in or not: the
        -- client's box hid it when empty and unfocused, and a field that
        -- never took focus had no way to close.
        row.along = (adding and self.along) or nil
        local clear = row.box.clearButton
        if clear then clear:SetShown(row.along or row.box:HasFocus() or (row.box:GetText() or "") ~= "") end
        if clear and clear.texture then
            local c = ink.light and ink.field or ink.hover
            clear.texture:SetVertexColor(c[1], c[2], c[3])
        end
        if px and g.SizeFont then
            g.SizeFont(row.box, px)
            if row.box.Instructions then g.SizeFont(row.box.Instructions, px) end
        end
        row.box:SetHeight(boxH)
        if pin then
            local gold = ns.GOLD_COLOR
            row.mark:SetTexture(ns.GPS.ICON_TEX)
            row.mark:SetSize(PIN, PIN)
            row.mark:SetVertexColor(gold[1], gold[2], gold[3], 1)
        else
            row.mark:SetTexture(TEX_RING)
            row.mark:SetSize(RING, RING)
            row.mark:SetVertexColor(ink.glyph[1], ink.glyph[2], ink.glyph[3], 1)
        end
        for k = 1, 3 do
            row.dots[k]:SetShown(n > 1)
            row.dots[k]:SetColorTexture(dim[1], dim[2], dim[3], 1)
        end
        -- Any row of a planned trip drags, the start too: two rows swap.
        row.canDrag = not adding and #stops >= 1
        row:SetHeight(rowH)
        local btn = self.frame.popoutBtn
        if btn and n == 1 then
            btn:ClearAllPoints()
            btn:SetPoint("RIGHT", self, "TOPRIGHT", 8, -rowH / 2)
        end
        Lay(self, row, n, y, route ~= nil)
        row:Show()
        y = y + rowH
        return row
    end
    wipe(self.stopRows)
    wipe(self.orderRows)
    -- No route yet: the one field, where to; the start and the add row
    -- once it is planned.
    local first = #stops == 0
    if first and self.adding ~= "focus" then self.adding = nil end
    if first or not self.adding then self.along = nil end
    local adding = self.adding or first
    local along = adding and self.along
    local function AddRow()
        -- Along the way the field is a stop before the destination: a ring.
        local row = Show(#stops + 1, "", along and L["GPS_ALONG"] or L["GPS_TRIP_TO"], not along, true)
        if self.adding == "focus" then
            -- Focused after the click that made the row, not inside it.
            self.adding = true
            Utils.SafeAfter(0, function()
                row.box._blockAutoFocus = nil
                row.box:SetFocus()
            end)
        end
    end
    if not first then
        self.orderRows[1] = Show(0, start and start.name or "", L["GPS_TRIP_FROM"], false)
        -- The pin marks where the trip ends; every stop before it a ring.
        for i = 1, #stops do
            if along and i == #stops then AddRow() end
            self.stopRows[i] = Show(i, stops[i].name or "?", L["GPS_TRIP_TO"], i == #stops and (along or not adding))
            self.orderRows[i + 1] = self.stopRows[i]
        end
    end
    if adding and not along then AddRow() end
    for i = n + 1, #self.rows do self.rows[i]:Hide() end
    -- Laid again under a still cursor: each grip as the cursor stands now.
    for i = 1, n do self.rows[i].SyncGrip() end
    if self.drag then self:LayDrag() end
    if px and g.SizeFont then
        g.SizeFont(self.addText, px)
        g.SizeFont(self.alongText, px)
    end
    self.add:ClearAllPoints()
    self.add:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
    self.add:SetPoint("RIGHT", self, "RIGHT", 0, 0)
    for k = 1, 3 do self.addDots[k]:SetShown(not adding) end
    self.add:SetShown(not adding)
    if not adding then y = y + ADD_H + self:LayAlong(route) end
    -- Hidden in the window, the fields take no room: the time line rises.
    self:SetHeight((self.frame.fieldsHidden and route) and 1 or mmax(1, y))
end

-- The editor at the top of a route page, in the title line's place: the
-- fields say where the trip goes, so the title does not.
function Trip.BuildEditor(frame)
    if frame.trip or not (frame.glyph and frame.eta and frame.list and frame.clearBtn) then return end
    local ed = CreateFrame("Frame", nil, frame)
    for k, v in pairs(Editor) do ed[k] = v end
    ed.frame = frame
    ed.rows, ed.stopRows, ed.orderRows, ed.dropRows = {}, {}, {}, {}
    -- With the pop-out button at the first field's end, the fields start
    -- a little left of the icon to keep their width.
    local shift = frame.popoutBtn and 6 or 0
    ed.listX = -6 + shift   -- where the steps start, left of the fields
    ed:SetPoint("TOPLEFT", frame.glyph, "TOPLEFT", -shift, 0)
    ed:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    ed:SetHeight(1)
    frame.title:Hide()
    if frame.glyphTex then frame.glyphTex:Hide() end

    -- The add row: a ring with a plus in it under the marks, the words after.
    local add = CreateFrame("Button", nil, ed)
    add:SetHeight(ADD_H)
    local ring = Mark(add)
    ring:SetSize(RING, RING)
    ring:SetTexture(TEX_RING)
    ring:SetVertexColor(RING_GREY[1], RING_GREY[2], RING_GREY[3], 1)
    local plus = add:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    plus:SetPoint("CENTER", ring, "CENTER", 0, 0)
    plus:SetText("+")
    plus:SetTextColor(RING_GREY[1], RING_GREY[2], RING_GREY[3], 1)
    plus._efOwnColor = true
    ed.addDots = {}
    for k = 1, 3 do
        local dot = Utils.CreateDot(add, 2.5, DIM)
        dot:SetPoint("CENTER", add, "TOPLEFT", GRIP_W + MARK / 2, (2 - k) * 3)
        ed.addDots[k] = dot
    end
    local addText = add:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    addText:SetPoint("LEFT", ring, "RIGHT", 8, 0)
    addText:SetText(L["GPS_TRIP_ADD"])
    addText:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
    addText._efOwnColor = true
    add:SetScript("OnEnter", function() addText:SetTextColor(Utils.RGB(ns.GPS.Ink(frame).hover)) end)
    add:SetScript("OnLeave", function() addText:SetTextColor(Utils.RGB(ns.GPS.Ink(frame).dim)) end)
    -- In the window's ink, again with each refresh (a theme change).
    function ed:PaintAdd(ink)
        ring:SetVertexColor(ink.glyph[1], ink.glyph[2], ink.glyph[3], 1)
        plus:SetTextColor(ink.glyph[1], ink.glyph[2], ink.glyph[3], 1)
        for k = 1, 3 do self.addDots[k]:SetColorTexture(ink.dim[1], ink.dim[2], ink.dim[3], 1) end
        local c = add:IsMouseOver() and ink.hover or ink.dim
        addText:SetTextColor(c[1], c[2], c[3], 1)
        c = self.alongBtn:IsMouseOver() and ink.hover or ink.dim
        self.alongText:SetTextColor(c[1], c[2], c[3], 1)
    end
    add:SetScript("OnClick", function()
        ed.adding = "focus"
        ed:Refresh(Route())
    end)
    ed.add, ed.addText = add, addText

    -- Search along the route, the add row's other click (Editor:LayAlong).
    local along = CreateFrame("Button", nil, add)
    local alongText = along:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    alongText:SetAllPoints(along)
    alongText:SetText(L["GPS_ALONG"])
    alongText:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
    alongText._efOwnColor = true
    along:SetScript("OnEnter", function() alongText:SetTextColor(Utils.RGB(ns.GPS.Ink(frame).hover)) end)
    along:SetScript("OnLeave", function() alongText:SetTextColor(Utils.RGB(ns.GPS.Ink(frame).dim)) end)
    along:SetScript("OnClick", function() ns.GPS:SearchAlong(frame) end)
    ed.alongBtn, ed.alongText = along, alongText

    -- Our menus' panel, above the route's step buttons (a teleport's icon
    -- sits in its own frame over its row).
    local drop = CreateFrame("Frame", nil, ed)
    drop:SetFrameStrata("TOOLTIP")
    drop:SetFrameLevel(9500)
    drop:EnableMouse(true)
    ns.StyleMenuPanel(drop)
    drop:Hide()
    ed.drop = drop

    -- The time line and the steps hang from the editor now, the arrival
    -- announcement too.
    local etaH = frame.eta:GetHeight() or 12
    frame.eta:ClearAllPoints()
    frame.eta:SetPoint("TOPLEFT", ed, "BOTTOMLEFT", GRIP_W + MARK / 2 + shift, -4)
    frame.eta:SetPoint("RIGHT", frame.clearBtn, "LEFT", -8, 0)
    -- The link's top hangs from the editor, not the time line, whose right
    -- end is anchored to the link: the client refuses the cycle.
    frame.clearBtn:ClearAllPoints()
    frame.clearBtn:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    frame.clearBtn:SetPoint("TOP", ed, "BOTTOM", 0, -3)
    frame.list:SetPoint("TOPLEFT", ed, "BOTTOMLEFT", -6 + shift, -(4 + etaH + (frame.listGap or 8)))
    -- The announcement in line with the time line's text, not the grip.
    ed.emptyX, ed.emptyStepsY = GRIP_W + MARK / 2 + shift, -(4 + etaH + (frame.listGap or 8))

    frame.trip = ed
    Trip.PlaceEmpty(frame, false)
    ed:Refresh(Route())
end

-- The hint's place: right under the fields while a first way is found (the
-- window's height counts it there), else where the steps were, under the
-- Clear link's row, for the arrival announcement.
function Trip.PlaceEmpty(frame, underFields)
    local ed, empty = frame.trip, frame.empty
    if not (ed and empty) then return end
    empty:SetPoint("TOPLEFT", ed, "BOTTOMLEFT", ed.emptyX, underFields and -10 or ed.emptyStepsY)
end

-- Folded, the window shows its title row: the fields go, the title and
-- the track toggle take the header; open, the toggle sits on the time line.
function Trip.Fold(frame, folded)
    local ed = frame.trip
    if not ed then return end
    ed:SetShown(not folded)
    frame.title:SetShown(folded)
    -- Folded, the title row wears the GPS glyph in the fields' place.
    if frame.glyphTex then frame.glyphTex:SetShown(folded) end
end
