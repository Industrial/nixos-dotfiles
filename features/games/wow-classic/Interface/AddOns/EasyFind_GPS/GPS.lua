-- GPS: step by step directions to a zone or point of interest.
-- The route is per character (EasyFind.db.gpsChar); the map page and the pop-out both render it.

-- A companion: it lives in EasyFind's namespace, never its own.
local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).tooOld then return end
local L = ns.L
local Utils = ns.Utils

local GPS = {}
ns.GPS = GPS
-- Its own glyph, as every extension ships its art.
GPS.ICON_TEX = "Interface\\AddOns\\EasyFind_GPS\\textures\\gps-icon"

-- The steps' ink. The pop-out wears the theme's fill, light on a light
-- theme, so its text there is the theme's own dark ink; beside the map and
-- on the dock the art is dark whatever the theme.
do
    local DARK = { primary = { 1, 0.97, 0.86 }, num = ns.GOLD_COLOR, next = ns.TEXT_NEXT, dim = ns.TEXT_DIM,
        aside = ns.TEXT_ASIDE, hover = { 1, 1, 1 }, glyph = { 0.8, 0.8, 0.82 } }
    local LIGHT = { light = true, primary = {}, num = { 0.78, 0.45, 0.0 }, next = {}, dim = {}, aside = {}, hover = {}, glyph = {},
        field = {} }
    -- A shade darker than the theme's own: the asides and the fields' text
    -- read better on the light fill (2026-10-27).
    local DARKER = { aside = 0.8, field = 0.85 }
    local FROM = { primary = "pathColorHover", next = "leafColor", dim = "textFaint", aside = "accent",
        hover = "pathColorHover", glyph = "chromeGlyph", field = "leafColor" }
    function GPS.Ink(frame)
        local theme = frame and frame.isPopout and ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
        if not (theme and theme.lightTheme) then return DARK end
        for key, field in pairs(FROM) do
            local c, dst, k = theme[field] or theme.leafColor, LIGHT[key], DARKER[key] or 1
            dst[1], dst[2], dst[3] = c[1] * k, c[2] * k, c[3] * k
        end
        return LIGHT
    end
    -- Painted in the frame's ink now and on each theme change: paint(ink).
    function GPS.Inked(frame, paint)
        frame.inkPaints = frame.inkPaints or {}
        frame.inkPaints[#frame.inkPaints + 1] = paint
        paint(GPS.Ink(frame))
    end
    function GPS.RepaintInk(frame)
        local ink = GPS.Ink(frame)
        for i = 1, #(frame.inkPaints or {}) do frame.inkPaints[i](ink) end
    end
end

local CreateFrame = CreateFrame
local UIParent = UIParent
local GameTooltip = GameTooltip
local GameTooltip_Hide = GameTooltip_Hide
local sformat = string.format
local mmax = math.max
local mfloor = math.floor
local unpack = unpack
local mpi = math.pi
local GetAtlasInfo = C_Texture.GetAtlasInfo

-- Arrival rings: a step's spot; the last step to a creature or other spot
-- (beside it); a crossing's far spot, where it drops you, give or take.
local ARRIVE = { yards = 40, spot = 8, cross = 300 }
local LEFT_DOCK_YARDS = 400   -- a zeppelin's step, this far from its dock unridden: off the route
-- A lift: its near door's reach, and the far door's for one stepped off.
local LIFT_YARDS, LIFT_OFF = 15, 3
local LIFT_ABOARD = 6   -- on its platform: this near the middle of its doors
local ROUTE_MAX_AGE = 2 * 60 * 60
local ARRIVED_LINGER = 8
local START_YARDS = 60      -- this close to a planned route's start, the player is on it
local ROW_H = 22
-- Beside the map the steps read at the pop-out's small type and follow the
-- map search's font size choice.
local MAP_STEP_PX = 10
-- The page's text scale: the map tab's font size, or the floating
-- window's own setting; nil leaves the fonts as made.
local function MapScale(container)
    if container.mapFont then return (EasyFind.db and EasyFind.db.mapTabFontSize) or 1 end
    local s = container.isPopout and EasyFind.db and EasyFind.db.gpsPopoutText
    return type(s) == "number" and s ~= 1 and s or nil
end
local function SizeFont(fs, px)
    local file, _, flags = fs:GetFont()
    if file then fs:SetFont(file, px, flags) end
end
-- The trip editor sizes its text as the page's steps.
GPS.SizeFont = SizeFont
-- A font string at the page's size, or its own font again at none.
local function ScaleFont(fs, object, px)
    if px then SizeFont(fs, px) else fs:SetFontObject(object) end
end

function GPS.MapTextPx(container)
    local scale = MapScale(container)
    return scale and MAP_STEP_PX * scale or nil
end
local HIT_ROWS = 8            -- results shown under the pop-out's search box
-- Pop-out sizes on offer: the cog's radio rows. A nil height fits the steps.
local SIZE_WIDTHS = { { 240, "GPS_SIZE_NARROW" }, { 300, "GPS_SIZE_NORMAL" }, { 380, "GPS_SIZE_WIDE" }, { 460, "GPS_SIZE_WIDER" } }
local SIZE_HEIGHTS = { { nil, "GPS_SIZE_FIT" }, { 160, "GPS_SIZE_SHORT" }, { 240, "GPS_SIZE_MEDIUM" }, { 340, "GPS_SIZE_TALL" } }

local ticker
local surfaces = {}     -- every container that renders the route
GPS.Surfaces = function() return surfaces end   -- dev tools
local popoutFrame       -- built on first use by the pop-out below

local function DB()
    return EasyFind and EasyFind.db
end

-- The ways of travel switched off. Until 1.7.0 one switch, "teleport", held
-- the hearthstone and the teleports: a save or profile from then has both off.
function GPS.Avoids()
    local db = DB()
    local avoid = db and db.gpsAvoid
    if avoid and avoid.teleport then
        avoid.teleport, avoid.hearth, avoid.teleports = nil, true, true
    end
    return avoid
end

-- This character's slot: the route in progress and whether its pop-out was open.
-- Style, dock slot and size are shared settings.
local function CharKey()
    return ns.CurrentCharacterKey()
end

local function CharDB()
    local db = DB()
    if not db then return nil end
    db.gpsChar = db.gpsChar or {}
    local key = CharKey()
    db.gpsChar[key] = db.gpsChar[key] or {}
    return db.gpsChar[key]
end

local function Route()
    local c = CharDB()
    return c and c.route
end
GPS.CurrentRoute = Route

-- A start other than where the player stands ({ name, mapID, x, y }), set
-- from the From line or a result's Route from here; nil: the player's spot.
local function Start()
    local c = CharDB()
    return c and c.start
end
GPS.Start = Start   -- the trip editor's first field

-- The search box's hint: picking a start, where to from a start, or plain.
local function SearchHint(frame)
    local box = frame.search
    if not (box and box.Instructions) then return end
    local s = Start()
    if GPS.picking == frame then
        box.Instructions:SetText(L["GPS_FROM_PLACEHOLDER"])
    elseif GPS.along == frame then
        box.Instructions:SetText(L["GPS_ALONG"])
    elseif s and not Route() then
        box.Instructions:SetText(sformat(L["GPS_SEARCH_FROM_FMT"], s.name or "?"))
    else
        box.Instructions:SetText(L["GPS_SEARCH_PLACEHOLDER"] or SEARCH or "Search")
    end
end

-- Route model

local WorldPos   -- defined below with the position helpers

-- Not places: battlegrounds and arenas (orphan maps, and newer zones sharing
-- an orphan's name), dungeon insides, the world and the cosmos. The client
-- filters by map type: unfiltered, every map in the game came back as a
-- table to keep a few dozen (24 ms in the first render with a zone row).
local orphanNames
local function IsOrphanName(name)
    if not orphanNames then
        orphanNames = {}
        local ok, kids = pcall(C_Map.GetMapChildrenInfo, 946, Enum.UIMapType.Orphan, true)
        if ok and kids then
            for i = 1, #kids do
                local k = kids[i]
                if k.mapType == Enum.UIMapType.Orphan and k.name then orphanNames[k.name:lower()] = true end
            end
        end
    end
    return name ~= nil and orphanNames[name:lower()] == true
end

-- Where a row leads: the place it stands for (a boss's door), else its
-- provider's place(row), asked a few seconds apart; else the row itself.
function GPS.LeadsTo(data)
    if data.gpsDest then return data.gpsDest end
    if data.placeOf or data.x ~= nil then return data end
    local Extensions = ns.Extensions
    local provider = Extensions and Extensions.ProviderOf and Extensions.ProviderOf(data)
    if not (provider and provider.place) then return data end
    local now = GetTime()
    if not (data._gpsPlaceAt and now - data._gpsPlaceAt < 5) then
        data._gpsPlaceAt = now
        local ok, place = Extensions.Run(provider.place, data)
        data._gpsPlace = ok and type(place) == "table" and place.mapID and place.x and place.y
            and { name = place.name, mapID = place.mapID, x = place.x, y = place.y, step = place.step,
                  icon = place.icon or data.icon } or nil
    end
    return data._gpsPlace or data
end

function GPS:CanNavigate(data)
    if not data then return false end
    data = GPS.LeadsTo(data)
    -- An extension's row: where it is right now (MapSearch.ResolvePlace).
    if data.placeOf and ns.MapSearch and ns.MapSearch.ResolvePlace then ns.MapSearch.ResolvePlace(data) end
    local mapID = data.zoneMapID or data.mapID
    if not mapID then return false end
    if not (data.isZone or (data.x ~= nil and data.y ~= nil)) then return false end
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    if not (info and info.mapType and Enum and Enum.UIMapType) then return false end
    local mt = info.mapType
    if mt == Enum.UIMapType.Cosmic or mt == Enum.UIMapType.World or mt == Enum.UIMapType.Orphan then return false end
    if mt == Enum.UIMapType.Dungeon and not data.isDungeonEntrance then return false end
    -- A zone under another zone that shares a battleground's name is its newer
    -- edition (Warsong Gulch under the Barrens); Nazjatar, under the world map, stays.
    if data.isZone and IsOrphanName(info.name) then
        local parent = info.parentMapID and C_Map.GetMapInfo(info.parentMapID)
        if parent and parent.mapType == Enum.UIMapType.Zone then return false end
    end
    return WorldPos(mapID, data.x or 0.5, data.y or 0.5) ~= nil
end

-- The GPS button just left of a navigable result row's own icon: a click
-- navigates there (onNavigate(data), else the GPS page). Made once per row;
-- nil, hidden, with the option off or nowhere to go. glyph: { r, g, b }.
function GPS.RowButton(row, data, size, onNavigate, glyph)
    local btn = row.gpsBtn
    local db = DB()
    if (db and db.gpsRowButton == false) or not GPS:CanNavigate(data) then
        if btn then btn:Hide() end
        return nil
    end
    if not btn then
        -- starts shown: placed and shown below, on a row being filled
        btn = CreateFrame("Button", nil, row)
        btn:RegisterForClicks("LeftButtonUp")
        btn.tex = btn:CreateTexture(nil, "ARTWORK")
        btn.tex:SetAllPoints()
        btn.tex:SetTexture(GPS.ICON_TEX)
        btn:SetScript("OnClick", function(self)
            if not self.data then return end
            if self.onNavigate then self.onNavigate(self.data) else GPS:NavigateTo(self.data) end
        end)
        btn:SetScript("OnEnter", function(self)
            self.tex:SetAlpha(1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["CTX_GPS"])
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            self.tex:SetAlpha(0.75)
            GameTooltip_Hide()
        end)
        row.gpsBtn = btn
    end
    btn.data, btn.onNavigate = data, onNavigate
    btn:SetSize(size, size)
    if glyph then btn.tex:SetVertexColor(glyph[1], glyph[2], glyph[3]) else btn.tex:SetVertexColor(1, 1, 1) end
    btn.tex:SetAlpha(btn:IsMouseOver() and 1 or 0.75)
    btn:Show()
    return btn
end

-- Whether a left-click on a spot pinned on the world map starts the GPS
-- there (the setting's default) rather than placing the game's waypoint.
function GPS.MapClickNavigates()
    local db = DB()
    return db ~= nil and db.gpsMapClick ~= "pin"
end

-- Where a row points: a POI's coordinates, a zone's marker on the parent map, else
-- the zone's middle. A dungeon row names its continent: the door is in the entrance list.
-- An instance's portal under its map label (a cave's far end): the 4th
-- return true, the 5th its instance map.
local function EntranceOf(data)
    local list = ns.GetDungeonEntrancesForMap and ns.GetDungeonEntrancesForMap(data.entranceMapID or data.mapID)
    for i = 1, list and #list or 0 do
        local e = list[i]
        if e.name == data.name then
            if e.zoneMapID and e.doorX then return e.zoneMapID, e.doorX, e.doorY, true, e.instanceMapID end
            if e.zoneMapID and e.zoneX then return e.zoneMapID, e.zoneX, e.zoneY, false, e.instanceMapID end
            if e.position then return data.entranceMapID or data.mapID, e.position.x, e.position.y end
        end
    end
    return nil
end

-- Instances carry isZone in search, but their entrance is the spot to reach.
local INSTANCE_CATEGORIES = { dungeon = true, raid = true, delve = true }

local function Destination(data)
    -- questMark: "offer" or "turnin", the quest button its end wears;
    -- questID: a log quest's, tracked itself on the last step; followGUID:
    -- a group member followed (UnitDirections.lua); npc: the name a Target
    -- press finds near the end (Arrow.lua); quietArrival: no arrival sound
    -- (a guide followed moves straight on); hold: a trip's stop the route
    -- never moves past on its own (a guide's, till the guide moves on);
    -- direct: led there in a straight line, no way planned (a guide's
    -- step that glides or flies to its spot).
    local dest = { name = data.destName or data.name, icon = data.icon, category = data.category, displayID = data.displayID,
                   step = type(data.step) == "string" and data.step or nil, questMark = data.questMark,
                   questID = data.questID, followGUID = data.followGUID, quietArrival = data.quietArrival or nil,
                   hold = data.hold or nil, direct = data.direct or nil }
    if data.npcName then
        dest.npc = data.npcName
    elseif data.npcID or data.category == "npc" then
        dest.npc = data.name
    end
    -- An instance: its portal, past the map label (Wailing Caverns' cave);
    -- reached there or once inside.
    local em, ex, ey, door, instance
    if data.isDungeonEntrance then em, ex, ey, door, instance = EntranceOf(data) end
    dest.instance = instance or data.instanceID
    if em and (door or not (data.x and data.y)) then
        dest.mapID, dest.x, dest.y, dest.door = em, ex, ey, door or nil
    elseif data.x and data.y and data.mapID then
        dest.mapID, dest.x, dest.y, dest.door = data.mapID, data.x, data.y, data.door or nil
    else
        -- A zone or a continent itself, not a spot on it: reached on entering it.
        dest.mapID, dest.x, dest.y = data.zoneMapID or data.mapID, 0.5, 0.5
        if data.isZone and not INSTANCE_CATEGORIES[data.category] then dest.zone = true end
    end
    return dest
end

-- The engine plans over the recorded travel graph; with no data or no cover,
-- the route is one step of traveling there.
local PlayerWorldPos   -- defined below with the position helpers

-- Where this character's hearth lands, learned from its last hearth and
-- kept while the bind is the same inn; nothing until then.

local function HearthPoint()
    local db = DB()
    local h = db and db.gpsHearth and db.gpsHearth[CharKey()]
    if not h then return nil end
    local bind = GetBindLocation and GetBindLocation()
    if bind and h.bind and h.bind ~= bind then return nil end
    return h
end

local function LearnHearth()
    local db = DB()
    if not db then return end
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local ci, wx, wy = PlayerWorldPos()
    if not (mapID and ci) then return end
    local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    local x, y = 0.5, 0.5
    if pos then x, y = pos:GetXY() end
    db.gpsHearth = db.gpsHearth or {}
    db.gpsHearth[CharKey()] = { bind = GetBindLocation and GetBindLocation() or nil, m = mapID, x = x, y = y, ci = ci, wx = wx, wy = wy }
end
GPS.LearnHearth = LearnHearth

-- A long walk reads as one step per zone it crosses ("Walk through Dun
-- Morogh to Loch Modan"), each previewed on its own map.
local CONTINENT = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
local ZONE = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
local continentOf = {}

local function ContinentAbove(mapID)
    local depth = 0
    while mapID and depth < 8 do
        local info = C_Map.GetMapInfo(mapID)
        if not info then return nil end
        if info.mapType == CONTINENT then return mapID end
        mapID = info.parentMapID
        depth = depth + 1
    end
    return nil
end

local function ZoneAt(ci, wx, wy)
    local cont = continentOf[ci]
    if not (cont and C_Map.GetMapInfoAtPosition) then return nil end
    local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, ci, CreateVector2D(wx, wy), cont)
    if not (ok and pos) then return nil end
    local x, y = pos:GetXY()
    local info = x and C_Map.GetMapInfoAtPosition(cont, x, y)
    if info and info.mapID and info.mapID ~= cont then return info.mapID, info.name end
    return nil
end
GPS.ZoneAt = ZoneAt

local function MapPos(ci, wx, wy, mapID)
    local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, ci, CreateVector2D(wx, wy), mapID)
    if ok and pos then return pos:GetXY() end
    return nil
end

-- A city is a zone map without exploration to uncover.
local function IsCity(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info ~= nil and info.mapType == ZONE and info.flags ~= nil and bit.band(info.flags, 2) == 0
end
GPS.IsCity = IsCity

-- Cities under a roof throughout, by each client's map (Undercity and
-- Ironforge on Era, TBC and Forever, then on MoP Classic): open ground
-- inside their map's box is the land over them (Route.lua WalkPieces).
GPS.ROOFED = { [1458] = true, [1455] = true, [998] = true, [87] = true }

local function SplitWalks(steps, dest, origin)
    local Route = ns.GPSRoute
    local ci, wx, wy
    if origin then ci, wx, wy = origin.ci, origin.wx, origin.wy else ci, wx, wy = PlayerWorldPos() end
    if not (Route and Route.SplitWalks and ci and C_Map.GetMapPosFromWorldPos) then return steps end
    local here = origin and origin.m or C_Map.GetBestMapForUnit("player")
    continentOf[ci] = continentOf[ci] or ContinentAbove(here)
    for i = 1, #steps do
        local p = steps[i].arrive
        if p and p.ci and p.m and not continentOf[p.ci] then continentOf[p.ci] = ContinentAbove(p.m) end
    end
    local start = { ci = ci, wx = wx, wy = wy }
    local hereInfo = here and IsCity(here) and C_Map.GetMapInfo(here)
    local db = DB()
    local ok, out = pcall(Route.SplitWalks, steps, start, ns.GPSData, {
        zoneAt = ZoneAt, mapPos = MapPos, isCity = IsCity,
        startCity = hereInfo and { map = here, name = hereInfo.name, roofed = GPS.ROOFED[here] } or nil,
        goalCity = dest.mapID and IsCity(dest.mapID) and { map = dest.mapID, name = (C_Map.GetMapInfo(dest.mapID) or {}).name,
                                                        roofed = GPS.ROOFED[dest.mapID] } or nil,
        goalZone = dest.zone and dest.mapID or nil,
        wholeWalks = db ~= nil and db.gpsZoneSteps == false,
    })
    if ok and out and #out > 0 then return out end
    return steps
end

-- A ghost's corpse as a world point, on the ghost's map or one above it.
local function CorpsePoint()
    local get = C_DeathInfo and C_DeathInfo.GetCorpseMapPosition
    local mapID = get and C_Map.GetBestMapForUnit("player")
    for _ = 1, 4 do
        if not mapID then return nil end
        local pos = get(mapID)
        local x, y
        if pos and pos.GetXY then x, y = pos:GetXY() elseif pos then x, y = pos.x, pos.y end
        if x and (x ~= 0 or y ~= 0) then
            local ci, wx, wy = WorldPos(mapID, x, y)
            if ci then return { m = mapID, x = x, y = y, ci = ci, wx = wx, wy = wy } end
        end
        local info = C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID
    end
    return nil
end

-- Where a plan starts with no start picked: where the player stands, or a
-- ghost's corpse, where it rises; one point the whole plan reads.
function GPS.PlayerStart()
    if UnitIsGhost and UnitIsGhost("player") then
        local p = CorpsePoint()
        if p then return p end
    end
    local m = C_Map.GetBestMapForUnit("player")
    local ok, pos
    if m then ok, pos = pcall(C_Map.GetPlayerMapPosition, m, "player") end
    if not (ok and pos) then return nil end
    local x, y = pos:GetXY()
    if not x or (x == 0 and y == 0) then return nil end
    local ci, wx, wy = WorldPos(m, x, y)
    if not ci then return nil end
    return { m = m, x = x, y = y, ci = ci, wx = wx, wy = wy }
end

-- The start as a world point { m, x, y, ci, wx, wy }, or nil for the player.
local function StartPoint()
    local s = Start()
    if not s then return nil end
    local ci, wx, wy = WorldPos(s.mapID, s.x, s.y)
    if not ci then return nil end
    return { m = s.mapID, x = s.x, y = s.y, ci = ci, wx = wx, wy = wy }
end

-- avoid: ways to leave out, the settings' by default; quick: no advice;
-- draw: "first" draws the walk set out on (a route to show), nothing
-- otherwise (a route to compare); startFrom: a world point to set out
-- from, false for the player whatever start is set, nil for the start
-- as set, else the player.
-- The flight points the player dropped from the trip dest belongs to.
function GPS.SkipFor(dest)
    local route = Route()
    if not (route and route.skipLearn and dest) then return nil end
    for _, s in ipairs(route.stops or { route.dest }) do
        if s.name == dest.name and s.mapID == dest.mapID then return route.skipLearn end
    end
    return nil
end

function GPS:BuildRoute(dest, via, avoid, quick, draw, startFrom, dropLimit)
    local Route = ns.GPSRoute
    local planned = startFrom or (startFrom == nil and StartPoint()) or nil
    local origin = planned or GPS.PlayerStart()
    if Route and ns.GPSData and not dest.direct then
        local h = HearthPoint()
        local db = DB()
        -- Set out from where the player stands: indoors there or not (a
        -- building's hall, Buildings.lua).
        local opts = { hearth = h and { point = h } or nil, via = via, avoid = avoid or GPS.Avoids() or nil,
                       start = origin, draw = draw, dropLimit = dropLimit,
                       startIndoors = not planned and IsIndoors and IsIndoors() or nil,
                       autoLearn = not (db and db.gpsAutoLearn == false), skipLearn = GPS.SkipFor(dest) }
        -- The advice feeds the lines and the stops learned on the way: with
        -- both off it is not worked out.
        if quick or (db and db.gpsShowDetours == false and db.gpsAutoLearn == false) then opts.advise = false end
        local ok, steps, advice, _
        local co = coroutine.running()
        local Nav = ns.GPSNav
        if co then
            if Nav then Nav.yieldCo = co end
            steps, _, advice = Route.Build(Route, dest, opts)
            if Nav then Nav.yieldCo = nil end
            ok = true
        else
            ok, steps, _, advice = pcall(Route.Build, Route, dest, opts)
        end
        if ok and steps and #steps > 0 then
            for i = 1, #steps do steps[i].name = steps[i].name or dest.name end
            steps = SplitWalks(steps, dest, origin)
            -- A walk to a zone ends at its border: the total follows the split.
            local total = 0
            for i = 1, #steps do total = total + (steps[i].sec or 0) end
            return steps, total, advice
        end
        if via then return nil end   -- no way with that stop: the route stays as it was
    end
    -- No way through the data, or none asked for (dest.direct: flown, so
    -- no walk is drawn on it after): a plain leg, priced as the crow flies when
    -- the spot is on this continent; on another, the step says there is
    -- no way from here, and nothing follows it.
    local sec
    local Engine = ns.GPSRoute
    local ci, px, py
    if origin then ci, px, py = origin.ci, origin.wx, origin.wy else ci, px, py = PlayerWorldPos() end
    local tci, tx, ty = WorldPos(dest.mapID, dest.x or 0.5, dest.y or 0.5)
    local noWay = ci ~= nil and tci ~= nil and tci ~= ci
    if ci and tci == ci and tx and Engine and Engine.TravelSeconds then
        sec = Engine:TravelSeconds(((px - tx) ^ 2 + (py - ty) ^ 2) ^ 0.5)
    end
    return {
        { kind = "travel", name = dest.name, mapID = dest.mapID, x = dest.x, y = dest.y, sec = sec, noWay = noWay or nil,
          fly = dest.direct or nil,
          arrive = tci and { m = dest.mapID, x = dest.x, y = dest.y, ci = tci, wx = tx, wy = ty } or nil,
          text = (not noWay and dest.step) or sformat(L[noWay and "GPS_STEP_NO_WAY_FMT" or "GPS_STEP_TRAVEL_FMT"], dest.name or "?") },
    }, sec
end

WorldPos = function(mapID, x, y)
    if not (mapID and x and y and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, ci, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
    if ok and pos then
        local wx, wy = pos:GetXY()
        return ci, wx, wy
    end
    return nil
end

GPS.WorldPos = WorldPos   -- the trip's legs start at a stop's world spot

-- Where a route's plans set out from now: its start as set until the
-- player reaches it, the player from then on (false: whatever start is set).
function GPS.RouteStart(route)
    if route.origin and not route.joined then return route.origin end
    return false
end

-- The route's stops planned leg by leg (Trip.lua); one stop is the route itself.
function GPS:BuildStops(route, via, avoid, quick, draw)
    local Trip = ns.GPSTrip
    local from = GPS.RouteStart(route)
    if Trip and route.stops and #route.stops > 1 then return Trip.Build(route.stops, via, avoid, quick, draw, from) end
    return self:BuildRoute(route.dest, via, avoid, quick, draw, from)
end

PlayerWorldPos = function()
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not pos then return nil end
    local x, y = pos:GetXY()
    if not x or (x == 0 and y == 0) then return nil end
    return WorldPos(mapID, x, y)
end

local function Refresh()
    for i = 1, #surfaces do
        local s = surfaces[i]
        if s:IsShown() and s.Render then s:Render() end
    end
    if ns.MapTab and ns.MapTab.RefreshPageBar then ns.MapTab:RefreshPageBar() end
    if ns.GPSWorldPin then ns.GPSWorldPin:Refresh() end
    if ns.GPSArrow then ns.GPSArrow:Refresh() end
    if ns.GPSMinimap then ns.GPSMinimap:Refresh() end
end
GPS.RefreshSurfaces = Refresh

-- Whether one of the GPS's own views is on screen (its window, the map's
-- page, the dock): the advice and the other ways show only there.
function GPS.AnySurfaceVisible()
    for i = 1, #surfaces do
        if surfaces[i]:IsVisible() then return true end
    end
    return false
end

-- Plans run a slice a frame, so a long one never stalls the game: a bigger
-- slice for the plan someone waits on (a route to show), a smaller one for
-- the work after it. One at a time: a newer plan replaces one still
-- running. A plan that fails runs once more at once, guarded, so its
-- fallback still comes.
local PLAN_BUDGET_MS, PLAN_BUDGET_BACK_MS = 12, 6
local Planner = { frame = CreateFrame("Frame"), IDLE_RELEASE = 60, dots = 1,
                  labels = setmetatable({}, { __mode = "k" }) }

-- A label saying a way is being found, its dots counting one to three
-- while the plan runs; the locale's own trailing dots make way for them.
function Planner.Show(fs)
    local text = sformat(L["GPS_PLANNING_FMT"], GPS.planning.name or "?")
    text = text:gsub("%.%.%.$", ""):gsub("\226\128\166$", "") .. string.rep(".", Planner.dots)
    fs:SetText(text)
    Planner.labels[fs] = text
end

-- Every 0.35 s of a plan: the next count on each label still saying it.
function Planner.Tick()
    if not GPS.planning then
        if Planner.dotTicker then Planner.dotTicker:Cancel() end
        Planner.dotTicker = nil
        wipe(Planner.labels)
        return
    end
    Planner.dots = Planner.dots % 3 + 1
    for fs, shown in pairs(Planner.labels) do
        if fs:GetText() == shown then Planner.Show(fs) else Planner.labels[fs] = nil end
    end
end

-- A minute after the last plan the grid's decoded data goes (Nav.Release);
-- what the arrow still reads stays, and the check comes round again
-- while anything is held. With no route left, the drawn walks and the
-- searches' grown tables go too.
function Planner.ReleaseLater()
    if Planner.releaseWaits then return end
    Planner.releaseWaits = true
    Utils.SafeAfter(Planner.IDLE_RELEASE, function()
        Planner.releaseWaits = false
        local Nav = ns.GPSNav
        if GPS:IsPlanning() or (Nav and Nav.Release(Planner.IDLE_RELEASE)) then Planner.ReleaseLater() end
        local route = Route()
        if Nav and not GPS:IsPlanning() and not (route and not route.arrived) then
            Nav.FreshScratch()
            ns.GPSRoute.ForgetWalkPaths()
            ns.GPSRoute.ShowWalks(nil)
        end
    end)
end

local function PlanStep()
    local co = Planner.co
    if not co then
        Planner.frame:SetScript("OnUpdate", nil)
        return
    end
    local Nav = ns.GPSNav
    if Nav then Nav.sliceEnd = debugprofilestop() + (GPS.planning and PLAN_BUDGET_MS or PLAN_BUDGET_BACK_MS) end
    local before = collectgarbage("count")
    local ok, a, b, c = coroutine.resume(co)
    if Nav then Nav.sliceEnd = nil end
    -- The collector keeps pace with the slice: what the plan left behind
    -- goes now, not once the heap has doubled.
    local grew = collectgarbage("count") - before
    if grew > 0 then ns.Utils.GCStep(1) end
    if coroutine.status(co) ~= "dead" or Planner.co ~= co then return end
    Planner.co = nil
    Planner.frame:SetScript("OnUpdate", nil)
    local done, build, quiet = Planner.done, Planner.build, Planner.quiet
    Planner.done, Planner.build, Planner.quiet = nil, nil, nil
    GPS.planning = nil
    if not ok then
        Utils.ErrorHandler(a)
        a, b, c = build()
    end
    done(a, b, c)
    if not quiet then Refresh() end
    Planner.ReleaseLater()
end

-- build() runs in the plan; done gets what it returns. name: the place the
-- surfaces say a way is being found to. quiet: nothing on the surfaces
-- changes (a walk drawn for the follower): they are not drawn again.
function GPS:Plan(name, build, done, quiet)
    Planner.co = coroutine.create(build)
    Planner.done, Planner.build, Planner.quiet = done, build, quiet
    GPS.planning = name and { name = name } or nil
    Planner.dots = 1
    if name and not Planner.dotTicker then Planner.dotTicker = C_Timer.NewTicker(0.35, Planner.Tick) end
    if not quiet then Refresh() end
    Planner.frame:SetScript("OnUpdate", PlanStep)
    PlanStep()
end

function GPS:IsPlanning() return Planner.co ~= nil end
GPS._planner = Planner   -- dev tools

-- The map point for a step's waypoint. A map that refuses user waypoints
-- (dungeon-type cities, underground continents), or a point past its map's
-- edge (a city left at its gate), hands it to the nearest ancestor that takes one.
local function WaypointPoint(step)
    local mapID, x, y = step.mapID, step.x, step.y
    if not (mapID and x and y) then return nil end
    local can = C_Map and C_Map.CanSetUserWaypointOnMap
    local onMap = x >= 0 and x <= 1 and y >= 0 and y <= 1
    if onMap and (not can or can(mapID)) then return mapID, x, y end
    local p = step.go or step.arrive
    local ci, wx, wy
    if p and p.wx then ci, wx, wy = p.ci, p.wx, p.wy else ci, wx, wy = WorldPos(mapID, x, y) end
    if not (ci and C_Map.GetMapInfo and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    local cur, depth = mapID, 0
    while cur and depth < 6 do
        local info = C_Map.GetMapInfo(cur)
        cur = info and info.parentMapID
        depth = depth + 1
        if cur and (not can or can(cur)) then
            local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, ci, CreateVector2D(wx, wy), cur)
            if ok and pos then
                local px, py = pos:GetXY()
                if px and px >= 0 and px <= 1 and py >= 0 and py <= 1 then return cur, px, py end
            end
        end
    end
    return nil
end

-- The game's pin off the map, when it is still ours on this step's end.
local function LiftPin(route)
    GPS.DropWaitingPin()
    local step = route and route.steps and route.steps[route.active or 1]
    local mapID, x, y
    if step then mapID, x, y = WaypointPoint(step) end
    local wp = mapID and C_Map and C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    if not (wp and wp.uiMapID == mapID and wp.position) then return end
    if math.abs(wp.position.x - x) > 0.001 or math.abs(wp.position.y - y) > 0.001 then return end
    if ns.MapSearch and ns.MapSearch.SetEasyFindWaypointPlaced then ns.MapSearch:SetEasyFindWaypointPlaced(false) end
    GPS.TrackGamePin(false)
    if C_Map.ClearUserWaypoint then GPS.GamePinChange("clear", C_Map.ClearUserWaypoint) end
end

-- A flight path to learn at or after the active step.
function GPS.StepAhead(route, kind)
    for i = route.active or 1, #route.steps do
        if route.steps[i].kind == kind then return true end
    end
    return false
end

-- The game's waypoint and super-track, changed through the map search's
-- waits (MapSearch.WaypointChange): never under an open world map.
function GPS.GamePinChange(kind, fn)
    local MS = ns.MapSearch
    if MS and MS.WaypointChange then MS.WaypointChange(kind, fn) else fn() end
end
function GPS.TrackGamePin(on)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        GPS.GamePinChange("track", function() C_SuperTrack.SetSuperTrackedUserWaypoint(on) end)
    end
end
-- The quest a route's last step tracks in place of the game's pin: the
-- destination's, while it is in the log and the client tracks quests.
function GPS.EndQuest(route, index)
    local quest = route.dest and route.dest.questID
    if not (quest and index == #route.steps and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID) then return nil end
    local QL = C_QuestLog
    return QL and QL.GetLogIndexForQuestID and QL.GetLogIndexForQuestID(quest) and quest or nil
end
function GPS.TrackQuest(quest)
    GPS.GamePinChange("quest", function() C_SuperTrack.SetSuperTrackedQuestID(quest) end)
end
function GPS.DropWaitingPin()
    local MS = ns.MapSearch
    if MS and MS.DropWaypointChange then MS.DropWaypointChange("place") end
end

-- The pin a step before set, while the game still shows it: taken off.
function GPS.DropPin(route)
    GPS.DropWaitingPin()
    local pin, wp = route.pin, C_Map and C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    route.pin = nil
    if not (pin and wp and wp.uiMapID == pin[1] and wp.position) then return end
    if math.abs(wp.position.x - pin[2]) > 0.001 or math.abs(wp.position.y - pin[3]) > 0.001 then return end
    if ns.MapSearch and ns.MapSearch.SetEasyFindWaypointPlaced then ns.MapSearch:SetEasyFindWaypointPlaced(false) end
    GPS.TrackGamePin(false)
    if C_Map.ClearUserWaypoint then GPS.GamePinChange("clear", C_Map.ClearUserWaypoint) end
end

local REACH_YARDS = 40
local ShowGameMenu   -- defined with the menus below; the rows are built before it
local TrackStep      -- defined below; the jump above needs it

-- A deliberate jump to a step, announced: a plain click never does this.
function GPS.GoToStep(index)
    local route = Route()
    if not (route and route.steps[index]) then return end
    TrackStep(index)
end

-- A click on a step away from the map: the map opens on the GPS page
-- with the step shown.
function GPS.ShowStep(index)
    local route = Route()
    if not (route and route.steps[index] and ns.GPSPreview) then return end
    if GPS:Open() then ns.GPSPreview:Show(index) end
end

-- A step's right-click: the route restarted there (as Shift-click), then
-- feedback on that step, the full route beside it so the two read apart.
-- Surfaces without a menu of their own (the map's page) show it at the cursor.
function GPS.ShowStepMenu(container, index)
    local defs = {
        { kind = "action", label = L["GPS_RESTART_FROM_STEP"], onClick = function() GPS.GoToStep(index) end },
        { kind = "action", label = L["GPS_FEEDBACK_STEP"], onClick = function() GPS:ReportRoute(index) end },
        { kind = "action", label = L["GPS_FEEDBACK_ROUTE"], onClick = function() GPS:ReportRoute() end },
    }
    -- A stop taken up from a suggestion is optional: it can go again.
    local route = Route()
    local step = route and not route.arrived and route.steps[index]
    if step and step.kind == "learn" and step.nodeID then
        table.insert(defs, 2, { kind = "action", label = L["GPS_REMOVE_STEP"], onClick = function() GPS:DropLearn(step.nodeID) end })
    end
    if container.ShowMenu then return container.ShowMenu(defs) end
    if not ns.ShowTogglePopup then return end
    local anchor = GPS.stepMenuAnchor
    if not anchor then
        -- starts shown: an empty 1 px point the menu hangs from
        anchor = CreateFrame("Frame", nil, UIParent)
        anchor:SetSize(1, 1)
        GPS.stepMenuAnchor = anchor
    end
    local cx, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    anchor:ClearAllPoints()
    anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
    ns.ShowTogglePopup("EasyFindGPSStepMenu", anchor, defs, {})
end


-- A crossing still a way off reads as reaching it (portal, dock, flight master),
-- then as taking it once there.
-- A timed boat's next departure from its stop, as "leaves in 1:20".
local function DepartureText(step)
    local Boats = ns.GPSBoats
    local wait = Boats and step.route and step.stop and Boats.WaitAt(step.route, step.stop, 0)
    if not wait then return nil end
    return sformat(L["GPS_LEAVES_IN_FMT"], sformat("%d:%02d", math.floor(wait / 60), math.floor(wait % 60)))
end

-- A spot's world place, by its own or its map's coordinates.
local function SpotWorld(p)
    if p.wx then return p.ci, p.wx, p.wy end
    return WorldPos(p.m, p.x, p.y)
end

-- On a lift's platform: its doors flank the shaft, the platform between them.
local function OnLift(step)
    if not (step.go and step.arrive) then return false end
    local ci, px, py = PlayerWorldPos()
    local aci, ax, ay = SpotWorld(step.go)
    local bci, bx, by = SpotWorld(step.arrive)
    if not (ci and ax and bx and aci == ci and bci == ci) then return false end
    return (px - (ax + bx) / 2) ^ 2 + (py - (ay + by) / 2) ^ 2 <= LIFT_ABOARD * LIFT_ABOARD
end

local function StepText(step, active)
    -- A walk that jumps down a ledge says how (Jumps.lua).
    local jump = ns.GPSJumps and ns.GPSJumps.StepText(step)
    if jump then return (step.text or "") .. ". " .. jump end
    if active and step and step.kind == "elevator" and step.aboardText and OnLift(step) then return step.aboardText end
    -- On board, docked or under way: stay on until it lands.
    local Boats = ns.GPSBoats
    if active and step and step.kind ~= "elevator" and step.aboardText and step.go and Boats and Boats.Aboard then
        local ci, px, py = PlayerWorldPos()
        local bci, bx, by = step.go.ci, step.go.wx, step.go.wy
        if not bx then bci, bx, by = WorldPos(step.go.m, step.go.x, step.go.y) end
        if Boats.Aboard(ci, px, py, bci, bx, by) then
            local leaves = not Boats.Carried() and step.route and DepartureText(step)
            return leaves and (step.aboardText .. " " .. leaves) or step.aboardText
        end
    end
    local departs = active and step and step.route and DepartureText(step)
    if departs then return (step.text or "") .. " " .. departs end
    if not (active and step and step.reach and step.go) or step.reached then return step and step.text or "" end
    local ci, px, py = PlayerWorldPos()
    local tci, tx, ty
    if step.go.wx then tci, tx, ty = step.go.ci, step.go.wx, step.go.wy
    else tci, tx, ty = WorldPos(step.go.m, step.go.x, step.go.y) end
    if ci and tci == ci and tx then
        local d = ((px - tx) ^ 2 + (py - ty) ^ 2) ^ 0.5
        if d > REACH_YARDS then return step.reachText or sformat(L["GPS_STEP_REACH_FMT"], step.reach) end
        -- Once there, moving away is the ride itself (the boat under way, the
        -- flight): the step keeps its own words.
        step.reached = true
    end
    return step.text or ""
end
GPS.StepText = StepText
GPS.PlayerWorldPos = function() return PlayerWorldPos() end

TrackStep = function(index)
    local route = Route()
    local step = route and route.steps[index]
    if not step then return end
    route.active = index
    route.arrived = nil
    step.reached, step.liftLevel, step.boarded = nil, nil, nil
    -- A teleport counts as taken only once cast, or once off this continent.
    route.castAt = nil
    route.stepCi = PlayerWorldPos()
    -- The game's pin, at this step's end only: the beacon stands on it.
    -- None for a spot in a building's hall: on the city's map it reads as
    -- the ground outside and the game leads back out (Buildings.lua); the
    -- pin set before goes too, and the arrow and minimap line lead.
    -- The last step to a quest in the log tracks the quest itself: its own
    -- icon is the end's mark (the game's pin drew over it), and the beacon
    -- stands on the game's way to it.
    local MapSearch = ns.MapSearch
    local mapID, x, y
    local quest = GPS.EndQuest(route, index)
    route.questTracked = quest
    if step.inside or quest then GPS.DropPin(route) end
    if quest then
        if not route.untracked then GPS.TrackQuest(quest) end
    elseif not (step.noWay or step.inside) then
        mapID, x, y = WaypointPoint(step)
    end
    if mapID and UiMapPoint and MapSearch and MapSearch.PlaceUserWaypoint then
        MapSearch:PlaceUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
        route.pin = { mapID, x, y }
        if not route.untracked then
            GPS.ClearQuestSuperTrack()
            GPS.TrackGamePin(true)
        end
        if MapSearch.RefreshAllClearButtons then MapSearch:RefreshAllClearButtons() end
    end
    Refresh()
    if ns.GPSPreview and ns.GPSPreview.Follow then ns.GPSPreview:Follow() end
end

local function StopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

-- Whether the player stands on this map or one nested in it.
local function OnMap(mapID)
    if not (mapID and C_Map and C_Map.GetBestMapForUnit) then return false end
    local cur = C_Map.GetBestMapForUnit("player")
    local depth = 0
    while cur and depth < 8 do
        if cur == mapID then return true end
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(cur)
        cur = info and info.parentMapID
        depth = depth + 1
    end
    return false
end

local function Arrive(route)
    route.arrived = true
    EasyFind.API.Fire("gps", "arrived", route.dest)
    if route.report and route.report.t then route.tookSec = time() - route.report.t end
    StopTicker()
    LiftPin(route)
    local dest = route.dest
    if dest and EasyFind.db.autoPinClear ~= false and ns.MapSearch and ns.MapSearch.ClearPinAt then
        ns.MapSearch:ClearPinAt(dest.mapID, dest.x, dest.y)
    end
    Refresh()
    if not (dest and dest.quietArrival) and PlaySound and SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE then
        pcall(PlaySound, SOUNDKIT.IG_QUEST_LIST_COMPLETE)
    end
    Utils.SafeAfter(ARRIVED_LINGER, function()
        local r = Route()
        if not (r and r.arrived) then return end
        GPS:Clear()
        local db = DB()
        if db and db.gpsAutoClose and GPS:IsWindowOpen() then GPS:CloseWindow() end
    end)
end

-- The arrival line, with the floor the last walk named (an inn's upper floor).
function GPS.ArrivedText(route)
    local fmt = L["GPS_ARRIVED_AT_FMT"]
    if not fmt then return L["GPS_ARRIVED"] end
    local last = route.steps and route.steps[#route.steps]
    local name = route.dest and route.dest.name or "?"
    local Engine = ns.GPSRoute
    if last and last.floor and Engine and Engine.WithFloor then name = Engine.WithFloor(name, last.floor) end
    return sformat(fmt, name)
end

-- The step followed: the yards along its way at the last tick and when,
-- the seconds moved on it and the fastest pace the game gave meanwhile
-- (its speed, once enough), what the last tick answered, and the estimate.
local closing = {}
local walkOpts = {}
local SPEED_AFTER_SECONDS = 6
local ETA_SMOOTH = 0.3

-- The time still to go, as a car's navigation reckons it: the way left to
-- the current step's spot along its drawn way, at the speed planned until
-- the game's pace on this step tells more (on foot, mounted under level
-- 40, a buff), then that step's crossing and every step after it, their
-- walks at that pace too. The pace is the game's, never the yards gained
-- along the way: a step aside or across a bend jumps those. Off a drawn
-- way the straight line stands in. Standing still holds the estimate.
local function RemainingSeconds(route)
    local i = route.active or 1
    local step = route.steps[i]
    local Engine = ns.GPSRoute
    if not (step and Engine and Engine.TravelSeconds) then return route.eta end
    local now = GetTime and GetTime() or 0
    if closing.step ~= i then
        closing.step, closing.along, closing.at, closing.d = i, nil, nil, nil
        closing.secs, closing.fastest, closing.speed, closing.held, closing.eta = 0, 0, nil, nil, nil
    end
    local planned = Engine.GroundSpeed(ns.GPSData)
    local total
    if step.kind == "teleport" then
        total = step.edgeSec or step.sec or 0
    else
        local onTaxi = step.kind == "taxi" and UnitOnTaxi and UnitOnTaxi("player")
        local f = not onTaxi and ns.GPSFollow and ns.GPSFollow.Now()
        local moved = false
        if f and f.path then
            if closing.at and now > closing.at then
                moved = math.abs(f.along - closing.along) > 0.5
                local cur, run = GetUnitSpeed("player")
                if not (issecretvalue and (issecretvalue(cur) or issecretvalue(run))) and cur > 0 and run > 0 then
                    closing.secs, closing.fastest = closing.secs + math.min(2, now - closing.at), mmax(closing.fastest, run)
                    if closing.secs >= SPEED_AFTER_SECONDS then closing.speed = closing.fastest end
                end
            end
            closing.along, closing.at = f.along, now
            local left = mmax(0, f.path.len - f.along)
            total = left * (f.path.time / mmax(1, f.path.len)) / (closing.speed or planned) + (step.edgeSec or 0)
        else
            local ci, px, py = PlayerWorldPos()
            local target = onTaxi and step.arrive or (step.go or step.arrive)
            local tci, tx, ty
            if target and target.wx then tci, tx, ty = target.ci, target.wx, target.wy
            elseif target then tci, tx, ty = WorldPos(target.m, target.x, target.y) end
            if ci and tci == ci and tx then
                local d = ((px - tx) ^ 2 + (py - ty) ^ 2) ^ 0.5
                moved = closing.d ~= nil and (closing.d - d > 0.5 or d - closing.d > 0.5)
                closing.d = d
                if onTaxi then
                    total = Engine:TravelSeconds(d, { taxi = true })
                else
                    walkOpts.wind = step.wind
                    total = Engine:TravelSeconds(d, walkOpts) + (step.edgeSec or 0)
                end
            else
                total = step.sec or 0
            end
        end
        if not moved and closing.held then total = closing.held end
        closing.held = total
    end
    route.stepEta = total
    local k = closing.speed and planned / closing.speed or 1
    for j = i + 1, #route.steps do
        local s = route.steps[j]
        total = total + (s.sec or 0) * (s.kind == "travel" and k or 1)
    end
    closing.eta = closing.eta and (closing.eta + (total - closing.eta) * ETA_SMOOTH) or total
    return closing.eta
end

-- The time still to go in minutes, and hours past one; under a minute
-- reads <1 min. Our own unit words: the game's carry a grammar token that
-- some text does not render.
local function EtaText(sec)
    local H, M = L["GPS_UNIT_HR"] or "%d hr", L["GPS_UNIT_MIN"] or "%d min"
    sec = sec or 0
    if sec < 60 then return "<" .. sformat(M, 1) end
    local m = mfloor(sec / 60 + 0.5)
    local h = mfloor(m / 60)
    m = m % 60
    if h > 0 then return sformat(H, h) .. (m > 0 and (" " .. sformat(M, m)) or "") end
    return sformat(M, m)
end
GPS.EtaText = EtaText

-- A distance in the unit picked in options. A banana is 7 inches, a
-- football field 100 yards.
function GPS.DistanceText(yards)
    local db = DB()
    local unit = db and db.gpsUnits
    if unit == "m" then return sformat(L["GPS_UNIT_M"], mfloor(yards * 0.9144 + 0.5)) end
    if unit == "banana" then return sformat(L["GPS_UNIT_BANANA"], mfloor(yards * 36 / 7 + 0.5)) end
    if unit == "field" then return sformat(L["GPS_UNIT_FIELD"], yards / 100) end
    return sformat(L["GPS_UNIT_YD"], mfloor(yards))
end

-- The destination line: the name, with the time still to go after it.
local function DestText(route)
    local name = route.dest.name or "?"
    if route.arrived or not (route.eta and route.eta > 0) then return sformat(L["GPS_TO_FMT"], name) end
    return sformat(L["GPS_TO_ETA_FMT"], name, EtaText(route.eta))
end

-- The time on every surface, without a full redraw.
local function UpdateEtaText(route)
    local eta = ""
    if route and not route.arrived and route.eta and route.eta > 0 then eta = EtaText(route.eta) end
    for i = 1, #surfaces do
        local s = surfaces[i]
        if s.SetEta then s:SetEta(route)
        elseif s.eta then
            s.eta:SetText(eta)
            if s.PlaceEtaTag then s:PlaceEtaTag(eta ~= "") end
        end
        if route and s.PlaceSearch then s:PlaceSearch(true) end
    end
end

local OFF_ROUTE_YARDS = 250   -- this far from a walk's way, the route starts over from here
local OFF_ROUTE_TICKS = 3     -- seconds off it first: a loading screen or a jump is no detour
local REROUTE_EVERY = 10
local offRoute = { ticks = 0, at = 0 }

local function PointWorld(p)
    if not p then return nil end
    if p.wx then return p.ci, p.wx, p.wy end
    return WorldPos(p.m, p.x, p.y)
end

local function ToSegment(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local len2 = dx * dx + dy * dy
    local t = len2 > 0 and mmax(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / len2)) or 0
    return ((px - ax - t * dx) ^ 2 + (py - ay - t * dy) ^ 2) ^ 0.5
end

-- Whether the player has left the current walk's way: off its straight
-- line and off its way on foot, or on another continent.
local function OffRoute(route, ci, px, py)
    local i = route.active or 1
    local step = route.steps[i]
    local fci, fx, fy = PointWorld(i > 1 and route.steps[i - 1].arrive or route.from)
    if step.kind ~= "travel" then
        -- A crossing taken wrong (the portal beside the planned one): the
        -- player is on a continent that is neither where it is taken nor
        -- where it lands. A ride in progress is always on one of the two.
        local gci = step.go and PointWorld(step.go) or fci
        local aci = step.arrive and PointWorld(step.arrive) or gci
        if ci ~= nil and gci ~= nil and ci ~= gci and ci ~= aci and ci ~= fci then return true end
        -- The tower's other zeppelin taken: landed far from both ends, not carried.
        local Boats = ns.GPSBoats
        if step.kind == "zeppelin" and ci ~= nil and ci == gci and not (Boats and Boats.Carried and Boats.Carried()) then
            local _, gx, gy = PointWorld(step.go)
            local _, ax, ay = PointWorld(step.arrive)
            local nearEnd = aci == ci and ax and (px - ax) ^ 2 + (py - ay) ^ 2 <= ARRIVE.cross * ARRIVE.cross
            return gx ~= nil and not nearEnd and (px - gx) ^ 2 + (py - gy) ^ 2 > LEFT_DOCK_YARDS * LEFT_DOCK_YARDS
        end
        -- Another way taken (flown to the city the hearth was for): on the
        -- destination's map and well away from where this step set out,
        -- the route starts over from here.
        local dest = route.dest
        if dest and dest.mapID and not dest.zone and fci ~= nil and fx and OnMap(dest.mapID)
            and (ci ~= fci or (px - fx) ^ 2 + (py - fy) ^ 2 > OFF_ROUTE_YARDS * OFF_ROUTE_YARDS) then
            return true
        end
        return false
    end
    local tci, tx, ty = PointWorld(step.go or step.arrive)
    if not (fci and tci and fci == tci) then return false end
    if ci ~= tci then return true end
    if step.fly or ToSegment(px, py, fx, fy, tx, ty) <= OFF_ROUTE_YARDS then return false end
    local Engine = ns.GPSRoute
    local way = Engine and Engine.WalkPath and Engine.WalkPath(tci, fx, fy, tx, ty, true, step.near)
    -- Its way not drawn yet: nothing to be off.
    if way == nil then return false end
    local pts = way and way.pts or {}
    for v = 1, #pts - 3, 2 do
        if ToSegment(px, py, pts[v], pts[v + 1], pts[v + 2], pts[v + 3]) <= OFF_ROUTE_YARDS then return false end
    end
    return true
end

-- A walk on to another walk is done once its spot is passed: within
-- PASS_YARDS of it and nearer the next step's spot than it is, a corner
-- cut past it. The walk on is found from there and joins ahead, never
-- back to the spot: the shortest walk from here to the next spot is never
-- longer than the one by this spot, and still goes by it where it must.
-- A field, not a local: the file is at Lua's 200 locals.
function GPS.StepPassed(route, ci, px, py)
    local PASS_YARDS, PASS_MARGIN = 250, 20
    local i = route.active or 1
    local step, nxt = route.steps[i], route.steps[i + 1]
    if not (step and nxt and step.kind == "travel" and nxt.kind == "travel") then return false end
    if step.fly or nxt.fly or step.corpse or step.inside then return false end
    -- A roofed city's door, or a place the game names, is gone through:
    -- no corner cuts past it under the ground (the sewers' tunnel winds
    -- round nearer the next spot than its own pipe is).
    if step.door or step.enterSub then return false end
    local sci, sx, sy = PointWorld(step.arrive or step.go)
    local nci, nx, ny = PointWorld(nxt.go or nxt.arrive)
    if not (sci and nci and sci == ci and nci == ci) then return false end
    if (px - sx) ^ 2 + (py - sy) ^ 2 > PASS_YARDS * PASS_YARDS then return false end
    local toNext = ((px - nx) ^ 2 + (py - ny) ^ 2) ^ 0.5
    return toNext < ((sx - nx) ^ 2 + (sy - ny) ^ 2) ^ 0.5 - PASS_MARGIN
end

-- Whether the player is through the door the active step ends at: past
-- its spot along the last stretch of the step's own way. Within reach of
-- it on the near side the step stays (the way on lies over the tunnel);
-- true where the way is not known. A field: the file is at 200 locals.
function GPS.ThroughDoor(route, ci, px, py)
    local i = route.active or 1
    local step = route.steps[i]
    local fci, fx, fy = PointWorld(i > 1 and route.steps[i - 1].arrive or route.from)
    local tci, tx, ty = PointWorld(step.go or step.arrive)
    local Engine = ns.GPSRoute
    if not (fci and tci == fci and ci == tci and Engine and Engine.WalkPath) then return true end
    local way = Engine.WalkPath(tci, fx, fy, tx, ty, true, step.near)
    local pts = way and way.pts
    for v = pts and #pts - 3 or 0, 1, -2 do
        local dx, dy = tx - pts[v], ty - pts[v + 1]
        if dx * dx + dy * dy > 1 then return (px - tx) * dx + (py - ty) * dy >= 0 end
    end
    return true
end

-- While a crossing is the step (a hearth, a flight), a later step the
-- player stands at, whatever way got him there (flown to the city the
-- hearth was for): the furthest one. At its spot it is taken up; at where
-- it lands, the step after it, or the journey's end. A walk's own
-- detours are the reroute's and StepPassed's.
function GPS.StepReached(route, ci, px, py)
    local steps, active = route.steps, route.active or 1
    local step = steps[active]
    if not step or step.kind == "travel" or step.corpse then return nil end
    local reach = ARRIVE.yards * ARRIVE.yards
    for k = #steps, active + 1, -1 do
        local later = steps[k]
        local aci, ax, ay = PointWorld(later.arrive)
        if aci == ci and ax and (px - ax) ^ 2 + (py - ay) ^ 2 <= reach then
            return steps[k + 1] and k + 1 or "arrive"
        end
        local gci, gx, gy = PointWorld(later.go)
        if gci == ci and gx and (px - gx) ^ 2 + (py - gy) ^ 2 <= reach then return k end
    end
    return nil
end

-- Any lift ridden, not only the route's: boarded from one door's side,
-- then out past the other door. The route's lift step ahead it stands
-- for, and true when it was another lift up or down to the same level
-- (Undercity's three). A field, not a local: the file is at 200 locals.
function GPS.LiftRidden(route, ci, px, py)
    local w = GPS.liftWatch
    if not w then w = {} GPS.liftWatch = w end
    local now = GetTime()
    local fresh = w.at and now - w.at <= 3 and w.ci == ci
    local lx, ly = w.px, w.py
    w.ci, w.px, w.py, w.at = ci, px, py, now
    local function Through(e, x, y)
        local dx, dy = e.to.wx - e.from.wx, e.to.wy - e.from.wy
        return ((x - e.from.wx) * dx + (y - e.from.wy) * dy) / (dx * dx + dy * dy)
    end
    local e = w.e
    if e and (not fresh or e.from.ci ~= ci) then e, w.e = nil, nil end
    if not e then
        for _, edge in ipairs(ns.GPSData and ns.GPSData.edges or {}) do
            local a, b = edge.from, edge.to
            if edge.kind == "elevator" and a.ci == ci and b.ci == ci and a.wx and b.wx
                and (px - (a.wx + b.wx) / 2) ^ 2 + (py - (a.wy + b.wy) / 2) ^ 2 <= LIFT_ABOARD * LIFT_ABOARD then
                -- Where it was boarded from: the tick before, beside one door.
                local t = fresh and Through(edge, lx, ly)
                w.e, w.enter = edge, t and (t < 0.25 or t > 0.75) and t or nil
                break
            end
        end
        return nil
    end
    local t = Through(e, px, py)
    local out
    if w.enter and w.enter < 0.5 and t >= 1 then out = e.to
    elseif w.enter and w.enter > 0.5 and t <= 0 then out = e.from end
    local mx, my = (e.from.wx + e.to.wx) / 2, (e.from.wy + e.to.wy) / 2
    if out or (px - mx) ^ 2 + (py - my) ^ 2 > LIFT_YARDS * LIFT_YARDS then w.e = nil end
    if not out then return nil end
    for k = route.active or 1, #route.steps do
        local s = route.steps[k]
        if s.kind == "elevator" then
            local aci, ax, ay = PointWorld(s.arrive)
            if aci == ci and ax and (ax - out.wx) ^ 2 + (ay - out.wy) ^ 2 <= LIFT_ABOARD * LIFT_ABOARD then return k, false end
            if s.arrive and s.arrive.area and s.arrive.area == out.area then return k, true end
            return nil
        end
    end
    return nil
end

-- A plan of the same trip taken up: its steps and times, and its start
-- where the plan set out from (BuildStops), so the drawn way begins there.
function GPS.Replanned(route, steps, total, advice)
    route.steps, route.eta, route.total, route.advice, route.t, route.there = steps, total, total, advice, time(), nil
    if ns.GPSRoute and ns.GPSRoute.ShowWalks then ns.GPSRoute.ShowWalks(nil) end
    local here = GPS.RouteStart(route) or GPS.PlayerStart()
    route.from = here and { ci = here.ci, wx = here.wx, wy = here.wy } or nil
    closing.step = nil
end

-- The route again from where it stands (the start as set until reached,
-- the player from then on), to the same place. A stop to learn a flight
-- master stays until that master is learned.
local function Reroute(route)
    if GPS:IsPlanning() then return end
    local via = GPS.ViaLeft(route, ns.GPSRoute and ns.GPSRoute.recordedKnown)
    GPS:Plan(nil, function() return GPS:BuildStops(route, via, route.wayAvoid, true, "first") end,
        function(steps, total, advice)
            if steps and Route() == route then GPS.Rerouted(route, via, steps, total, advice) end
        end)
end

function GPS.Rerouted(route, via, steps, total, advice)
    local here = GPS.RouteStart(route) or GPS.PlayerStart()
    local ci, wx, wy
    if here then ci, wx, wy = here.ci, here.wx, here.wy end
    -- The report keeps the first plan, and counts the starts over.
    local report = route.report
    if report then report.re = (report.re or 0) + 1 end
    CharDB().route = { dest = route.dest, steps = steps, active = 1, t = time(), eta = total, total = total, advice = advice,
                       via = via, from = ci and { ci = ci, wx = wx, wy = wy } or nil, report = report,
                       origin = route.origin, joined = route.joined, stops = route.stops, skipLearn = route.skipLearn,
                       wayAvoid = route.wayAvoid, dangerSeen = route.dangerSeen }
    closing.step = nil
    if GPS.AfterRoute then GPS.AfterRoute() end
    if ns.GPSPreview and ns.GPSPreview.Reset then ns.GPSPreview:Reset() end
    TrackStep(1)
    if UnitIsGhost("player") then GPS.LeadToCorpse() end
end

-- Dead on the way: released, the ghost is led to its corpse first, a step
-- of its own before the one it was on; risen, that step goes and the
-- route carries on from there.

-- The steps changed under the route: every surface starts afresh and the
-- walks are drawn again from their new starts.
local function StepsChanged(route, active)
    if ns.GPSFollow then ns.GPSFollow.Reset() end
    if ns.GPSPreview and ns.GPSPreview.Reset then ns.GPSPreview:Reset() end
    TrackStep(active)
    if GPS.AfterRoute then GPS.AfterRoute(true) end
end

-- The Spirit Healer a ghost on a death skip is led to, as a corpse point
-- with its name: where the guide's own step puts it (GPS.deathSkipAt),
-- else the catalog's beside the ghost (within 200 yards); nil without
-- either. Zephras Isle's are in no catalog, so its ghosts were led back
-- to their corpses (2026-11-21).
function GPS.SpiritHealerPoint()
    local Npcs = ns.Npcs
    local spot = Npcs and Npcs.SpotOfID and Npcs.SpotOfID(6491)   -- every graveyard's Spirit Healer
    local at = GPS.deathSkipAt
    local name = (spot and spot.name) or (at and at.name)
    if at and name then
        local aci, awx, awy = WorldPos(at.mapID, at.x, at.y)
        if aci then return { m = at.mapID, x = at.x, y = at.y, ci = aci, wx = awx, wy = awy, name = name } end
    end
    if not (spot and spot.mapID and spot.x and spot.name) then return nil end
    local ci, wx, wy = WorldPos(spot.mapID, spot.x, spot.y)
    local pci, px, py = PlayerWorldPos()
    if not (ci and ci == pci and (wx - px) ^ 2 + (wy - py) ^ 2 <= 200 * 200) then return nil end
    return { m = spot.mapID, x = spot.x, y = spot.y, ci = ci, wx = wx, wy = wy, name = spot.name }
end

local function LeadToCorpse()
    local route = Route()
    if not (route and route.steps and not route.arrived) then return end
    local i = route.active or 1
    if route.steps[i] and route.steps[i].corpse then return end
    -- A guide's death skip: risen at the Spirit Healer beside the ghost.
    local healer = GPS.deathSkip and GPS.SpiritHealerPoint()
    local p = healer or CorpsePoint()
    if not p then return end
    local ci, px, py = PlayerWorldPos()
    table.insert(route.steps, i, { kind = "travel", corpse = true, spirit = healer and true or nil,
                                   text = healer and L["GPS_STEP_SPIRIT_HEALER_FMT"]:format(healer.name) or L["GPS_STEP_CORPSE"],
                                   npc = healer and healer.name or nil,
                                   mapID = p.m, x = p.x, y = p.y, go = p, arrive = p, sec = 0,
                                   from = ci and { ci = ci, wx = px, wy = py } or nil })
    StepsChanged(route, i)
end

-- Set while a guide's step says to die and respawn (the gps deathSkip
-- action): true, or the Spirit Healer's own spot { mapID, x, y, name } as
-- the guide's step gives it. A ghost already led to one is led to the
-- other, and to a spot that changed.
function GPS.SetDeathSkip(on)
    local at = type(on) == "table" and on.mapID and on.x and on.y and on or nil
    on = on and true or nil
    local was = GPS.deathSkipAt
    local sameSpot = (at == nil and was == nil)
        or (at ~= nil and was ~= nil and at.mapID == was.mapID and at.x == was.x and at.y == was.y)
    if on == GPS.deathSkip and sameSpot then return end
    GPS.deathSkip, GPS.deathSkipAt = on, at
    local route = Route()
    if not (route and route.steps and UnitIsGhost and UnitIsGhost("player")) then return end
    for i = 1, #route.steps do
        local step = route.steps[i]
        if step.corpse then
            if step.spirit == on and sameSpot then return end
            table.remove(route.steps, i)
            break
        end
    end
    LeadToCorpse()
end

local function Risen()
    local route = Route()
    if not (route and route.steps) then return end
    for i = 1, #route.steps do
        if route.steps[i].corpse then
            table.remove(route.steps, i)
            local active = route.active or 1
            if active > i then active = active - 1 end
            if not route.steps[active] then return Arrive(route) end
            StepsChanged(route, active)
            -- Risen away from where it goes on (a spirit healer): from here.
            local ci, px, py = PlayerWorldPos()
            if ci and OffRoute(route, ci, px, py) then Reroute(route) end
            return
        end
    end
end

local function GhostOrRisen()
    if UnitIsGhost("player") then LeadToCorpse() else Risen() end
end
GPS.LeadToCorpse, GPS.Risen = LeadToCorpse, Risen   -- dev tools

-- The route moves on to step target ("arrive": its end), unless a stop
-- that holds comes first (a guide's): it never goes past one on its own;
-- the next trip comes from whoever sent this one. A field: 200 locals.
function GPS.MoveOn(route, target)
    local steps, active = route.steps, route.active or 1
    for i = active, target == "arrive" and #steps or target - 1 do
        local stop = steps[i] and steps[i].tripStop
        if stop and stop.hold and steps[i + 1] then
            if i ~= active then TrackStep(i) end
            return
        end
    end
    if target == "arrive" then Arrive(route) else TrackStep(target) end
end

local function Tick()
    local route = Route()
    if not route or route.arrived then StopTicker() return end
    local step = route.steps[route.active or 1]
    if not step then StopTicker() return end
    -- Through an instance's portal before its last yards: there all the same.
    local into = route.dest and route.dest.instance
    if into and IsInInstance and IsInInstance() and select(8, GetInstanceInfo()) == into then
        Arrive(route)
        return
    end
    -- Planned from elsewhere: no countdown and no starting over until the
    -- player reaches the start.
    local planned = route.origin and not route.joined
    if planned then
        local pci, ppx, ppy = PlayerWorldPos()
        local o = route.origin
        if pci == o.ci and ppx and (ppx - o.wx) ^ 2 + (ppy - o.wy) ^ 2 <= START_YARDS * START_YARDS then
            route.joined, planned = true, false
        end
    end
    -- The estimate follows the player: the way still ahead, every second.
    if not planned then
        route.eta = RemainingSeconds(route)
        UpdateEtaText(route)
    end
    -- A ghost without its corpse leg (the route rewritten under it), or a
    -- risen player still carrying one: put right here, every second. A
    -- ghost on its way to its corpse: nothing else counts until it rises.
    local ghost = UnitIsGhost("player") == true
    if ghost ~= (step.corpse == true) then GhostOrRisen() return end
    if ghost then return end
    -- Reaching a crossing's spot changes what its step says: redraw then.
    local there = StepText(step, true) == (step.text or "")
    if route.there ~= there then
        route.there = there
        Refresh()
    end
    -- A zone is reached when you are in it, wherever its map's middle is;
    -- a flight path to learn on the way there still comes first, and so
    -- does a lift up (Thunder Bluff's map reaches its lifts' feet).
    if route.dest and route.dest.zone and not INSTANCE_CATEGORIES[route.dest.category] and OnMap(route.dest.mapID)
        and not GPS.StepAhead(route, "learn") and not GPS.StepAhead(route, "elevator") then
        Arrive(route)
        return
    end
    -- A walk through a zone ends on entering the next one, wherever the
    -- border is crossed; leaving a city ends its step the same way.
    if step.enter and OnMap(step.enter) then
        GPS.MoveOn(route, route.steps[(route.active or 1) + 1] and (route.active or 1) + 1 or "arrive")
        return
    end
    local ci, px, py = PlayerWorldPos()
    if not ci then return end
    -- Backtracked or wandered off: the route starts over from here.
    if not planned and not (UnitOnTaxi and UnitOnTaxi("player")) and OffRoute(route, ci, px, py) then
        offRoute.ticks = offRoute.ticks + 1
        local now = GetTime()
        if offRoute.ticks >= OFF_ROUTE_TICKS and now - offRoute.at >= REROUTE_EVERY then
            offRoute.ticks, offRoute.at = 0, now
            Reroute(route)
            return
        end
    else
        offRoute.ticks = 0
    end
    -- A lift ridden while the route still had it ahead (the walk to it not
    -- counted, or another of the city's lifts taken): on from its far door.
    if not planned and not (UnitOnTaxi and UnitOnTaxi("player")) then
        local k, other = GPS.LiftRidden(route, ci, px, py)
        if other and not GPS:IsPlanning() then
            Reroute(route)
            return
        elseif k then
            GPS.MoveOn(route, route.steps[k + 1] and k + 1 or "arrive")
            return
        end
    end
    if not planned and GPS.StepPassed(route, ci, px, py) then
        GPS.MoveOn(route, (route.active or 1) + 1)
        return
    end
    if not planned and not (UnitOnTaxi and UnitOnTaxi("player")) then
        local reached = GPS.StepReached(route, ci, px, py)
        if reached then
            GPS.MoveOn(route, reached)
            return
        end
    end
    -- A step is done where it lands you (the far side of a portal or a
    -- flight), which is not always where it starts.
    local arrive = step.arrive
    local sci, sx, sy
    if arrive and arrive.wx then sci, sx, sy = arrive.ci, arrive.wx, arrive.wy
    elseif arrive then sci, sx, sy = WorldPos(arrive.m, arrive.x, arrive.y)
    else sci, sx, sy = WorldPos(step.mapID, step.x, step.y) end
    if not sci or sci ~= ci then return end
    if step.kind == "teleport" and ci == route.stepCi
        and not (route.castAt and GetTime() - route.castAt < 300) then return end
    -- A stop to learn a flight path is done when the flight master's map
    -- shows it learned, not on arriving.
    if step.kind == "learn" then return end
    -- Into a building: done once indoors in its hall; out of one: once out
    -- of doors (its stairs, the street).
    if step.kind == "enter" or step.kind == "leave" then
        local Engine = ns.GPSRoute
        local indoors = IsIndoors and IsIndoors()
        local inHall = indoors and Engine and Engine.InHall and Engine.InHall(step.area, ci, px, py)
        if step.kind == "enter" and not inHall then return end
        if step.kind == "leave" and indoors then return end
        GPS.MoveOn(route, route.steps[(route.active or 1) + 1] and (route.active or 1) + 1 or "arrive")
        return
    end
    -- A lift's far door is a few yards from its near one: ridden once the
    -- level's name under the player (the hall's, the city's) has changed.
    if step.kind == "elevator" then
        local level = GetSubZoneText and GetSubZoneText() or ""
        if not step.liftLevel then
            local go = step.go
            if go and go.wx and (px - go.wx) ^ 2 + (py - go.wy) ^ 2 <= LIFT_YARDS * LIFT_YARDS then step.liftLevel = level end
            return
        end
        -- Off its platform through the far door: ridden, though the name
        -- may stay (Undercity's east lift reads the Ruins at both ends).
        if OnLift(step) then step.boarded = true end
        local through = step.boarded and ns.GPSFollow and ns.GPSFollow.ThroughLift(step, ci, px, py)
        if level == step.liftLevel and (px - sx) ^ 2 + (py - sy) ^ 2 > LIFT_OFF * LIFT_OFF
            and not (through and through >= 1) then return end
    end
    local crossing = step.kind ~= "travel"
    -- A crossing to another continent is done the moment you are on it;
    -- one that stays on this continent is done near its far spot.
    -- The walk to a dock reached by a tight ring: carried off, it is done.
    local Boats = ns.GPSBoats
    local carried = step.arriveYards and Boats and Boats.Carried and Boats.Carried()
    -- Into a place the game names (Undercity's sewers): done on entering it.
    local named = step.enterSub ~= nil and GetSubZoneText ~= nil and GetSubZoneText() == step.enterSub
    if not named and not carried and not (crossing and step.go and step.go.ci ~= sci) then
        local radius = crossing and ARRIVE.cross or step.arriveYards or ARRIVE.yards
        -- The marks stay on a creature until the player stands beside it
        -- (several stand in a town); an entrance keeps the wider ring.
        local dest = route.dest
        local spot = not crossing and not route.steps[(route.active or 1) + 1] and dest and not dest.zone
           and (dest.door or not INSTANCE_CATEGORIES[dest.category])
        if spot then radius = ARRIVE.spot end
        local dx, dy = px - sx, py - sy
        if (dx * dx + dy * dy) > radius * radius then return end
        if step.door and not GPS.ThroughDoor(route, ci, px, py) then return end
        -- Over the spot on another floor (the ring above an auction house).
        if ns.GPSFloors and not ns.GPSFloors.SameLevel(ci, sx, sy) then return end
        -- Upstairs or below in a room nothing tells the floors apart: the
        -- route stays until ended, unless set to end there anyway.
        if spot and (step.floor == "upper" or step.floor == "lower") then
            local db = DB()
            if not (db and db.gpsArriveAnyFloor) then return end
        end
        -- A cave under its hill, or the hill over one: the game says which.
        local Nav = ns.GPSNav
        if spot and Nav and Nav.InsideAt and IsIndoors then
            local inside = Nav.InsideAt(ci, sx, sy)
            if inside ~= nil and inside ~= (IsIndoors() and true or false) then return end
        end
    end
    GPS.MoveOn(route, route.steps[(route.active or 1) + 1] and (route.active or 1) + 1 or "arrive")
end

local function StartTicker()
    if ticker or not C_Timer then return end
    ticker = C_Timer.NewTicker(1, Tick)
end

GPS.Destination = Destination   -- the trip editor's stops

-- A caller's ways to leave out (opts.avoid, a guide keeping the
-- Hearthstone for its own steps) on top of the player's; nil without.
function GPS.CallerAvoid(opts)
    local extra = opts and opts.avoid
    if type(extra) ~= "table" then return nil end
    local avoid = {}
    for k, v in pairs(GPS.Avoids() or {}) do avoid[k] = v end
    for k, v in pairs(extra) do
        if v then avoid[k] = true end
    end
    return avoid
end

function GPS:NavigateTo(data, opts)
    if data then data = GPS.LeadsTo(data) end
    if not self:CanNavigate(data) then return false end
    local db = DB()
    if not db then return false end
    local dest = Destination(data)
    -- Started from the main search bar: the window, not the map.
    if opts and opts.popout then
        self:ShowWindow()
    elseif not (opts and opts.quiet) then
        self:Open()
    end
    -- A map search's place: the map's own pin on it too, as a click in the
    -- map tab leaves it (its glow, its tooltip, a right-click clears it).
    local MapSearch = ns.MapSearch
    if data.mapSearchResult and not dest.zone and data.x and data.y and MapSearch and MapSearch.SelectResult then
        if WorldMapFrame and WorldMapFrame:IsShown() then
            MapSearch:SelectResult(data, true)
        elseif MapSearch.SetActivePinState then
            MapSearch:SetActivePinState({ mapID = data.coordMapID or data.mapID, x = data.x, y = data.y, icon = data.icon,
                                          category = data.category, displayID = data.displayID, isLocal = false })
        end
    end
    local avoid = GPS.CallerAvoid(opts)
    self:Plan(dest.name, function() return self:BuildRoute(dest, nil, avoid, true, "first") end,
        function(steps, total, advice)
            GPS.Navigated(dest, steps, total, advice, nil, avoid)
        end)
    return true
end

-- A trip through several places in order, as the trip editor plans one;
-- places the GPS cannot reach are left out.
function GPS:NavigateTrip(list, opts)
    local Trip = ns.GPSTrip
    if not (Trip and DB() and type(list) == "table") then return false end
    local stops = {}
    for i = 1, #list do
        local data = list[i] and GPS.LeadsTo(list[i])
        if data and self:CanNavigate(data) then stops[#stops + 1] = Destination(data) end
    end
    if #stops == 0 then return false end
    if opts and opts.popout then
        self:ShowWindow()
    elseif not (opts and opts.quiet) then
        self:Open()
    end
    local dest = stops[#stops]
    local avoid = GPS.CallerAvoid(opts)
    self:Plan(dest.name, function() return Trip.Build(stops, nil, avoid, true, "first") end,
        function(steps, total, advice)
            if steps then GPS.Navigated(dest, steps, total, advice, stops, avoid) end
        end)
    return true
end

-- avoid: the caller's ways left out, kept for the route's replans.
function GPS.Navigated(dest, steps, total, advice, stops, avoid)
    local db = DB()
    if not db then return end
    -- Planned from elsewhere: the route waits there until the player comes.
    local origin = StartPoint()
    local here = origin or GPS.PlayerStart()
    local from = here and { ci = here.ci, wx = here.wx, wy = here.wy } or nil
    local Engine = ns.GPSRoute
    local flies = Engine and select(2, Engine.Riding(ns.GPSData)) ~= nil
    -- The report's start: the world spot and the map spot it was on.
    local start = here and { ci = here.ci, wx = here.wx, wy = here.wy, m = here.m, x = here.x, y = here.y } or nil
    -- The same trip planned again keeps the flight points dropped from it.
    local old = Route()
    local same = old and old.dest and old.dest.name == dest.name and old.dest.mapID == dest.mapID
    CharDB().route = { dest = dest, steps = steps, active = 1, t = time(), eta = total, total = total, advice = advice,
                       from = from, origin = origin, stops = stops or { dest }, skipLearn = same and old.skipLearn or nil,
                       dangerSeen = same and old.dangerSeen or nil, wayAvoid = avoid,
                       report = { from = start, total = total, t = time(), fly = flies,
                                  steps = Engine and Engine.StepsCode and Engine.StepsCode(steps) or nil } }
    if GPS.AfterRoute then GPS.AfterRoute() end
    EasyFind.API.Fire("gps", "routeStarted", dest)
    -- A new route opens up, whatever the last one was folded to.
    db.gpsPopoutCollapsed = nil
    for i = 1, #surfaces do
        if surfaces[i].SyncFold then surfaces[i]:SyncFold() end
    end
    TrackStep(1)
    if UnitIsGhost("player") then GPS.LeadToCorpse() end
    StartTicker()
end

-- The trip's stops still to learn, as a list (one saved alone before
-- stops could be several); nil when none is left.
function GPS.ViaLeft(route, learned)
    local via = route.via
    local list = via and (via.id and { via } or via) or {}
    local left = {}
    for i = 1, #list do
        if not (learned and learned[list[i].id]) then left[#left + 1] = list[i] end
    end
    return #left > 0 and left or nil
end

-- The trip again with a stop to learn a flight master on it: among its
-- other stops where the trip meets it, on the way it was chosen.
function GPS:AddStop(tip)
    local route = Route()
    local Engine = ns.GPSRoute
    if not (route and route.dest and Engine and tip and tip.id) then return end
    local via = GPS.ViaLeft(route, { [tip.id] = true }) or {}
    local at = #via + 1
    for i = 1, #via do
        if via[i].id == tip.before then at = i break end
    end
    table.insert(via, at, { id = tip.id, name = tip.name, p = tip.p })
    self:Plan(route.dest.name, function() return self:BuildStops(route, via, route.wayAvoid, nil, "first") end,
        function(steps, total, advice)
            if steps and Route() == route then GPS.StopAdded(route, via, tip, steps, total, advice) end
        end)
end

-- A learning stop dropped: the trip again without it, and it is not
-- taken or offered again on this trip.
function GPS:DropLearn(nodeID)
    local route = Route()
    if not (route and route.dest and nodeID) then return end
    route.skipLearn = route.skipLearn or {}
    route.skipLearn[nodeID] = true
    local keepVia = GPS.ViaLeft(route, { [nodeID] = true })
    self:Plan(route.dest.name, function() return self:BuildStops(route, keepVia, route.wayAvoid, nil, "first") end,
        function(steps, total, advice)
            if steps and Route() == route then GPS.StopAdded(route, keepVia, keepVia or {}, steps, total, advice) end
        end)
end

function GPS.StopAdded(route, via, tip, steps, total, advice)
    GPS.Replanned(route, steps, total, advice)
    route.via = via
    if route.report and tip.id then route.report.via = tip.id end
    TrackStep(1)
    if GPS.AfterRoute then GPS.AfterRoute(true) end
end

-- What the navigation is doing right now, for the dev command.
function GPS:Status()
    local out = {}
    out[#out + 1] = ns.GPSWorldPin and ns.GPSWorldPin:Status() or "world pin: file not loaded"
    if popoutFrame then
        local f = popoutFrame
        local b = f.border
        out[#out + 1] = sformat("pop-out: shown %s, folded %s, size %.0fx%.0f, scale %.2f | border shown %s, extends top %s bottom %s | glyph top %s",
            tostring(f:IsShown()), tostring(f.collapsed == true), f:GetWidth() or 0, f:GetHeight() or 0, f:GetEffectiveScale() or 1,
            tostring(b and b:IsShown()), b and b:GetTop() and f:GetTop() and sformat("%.0f", b:GetTop() - f:GetTop()) or "?",
            b and b:GetBottom() and f:GetBottom() and sformat("%.0f", f:GetBottom() - b:GetBottom()) or "?",
            f.glyph and f.glyph:GetTop() and f:GetTop() and sformat("%.0f", f:GetTop() - f.glyph:GetTop()) or "?")
        local sdb = DB()
        out[#out + 1] = sformat("pop-out rim: skin %s, skinOff %s, chrome classic %s forever %s, palette chrome %s, frame art %s | border setting %s, rim %s | ring wanted %s, backdrop %s, band shown %s",
            tostring(f._efSkin), tostring(f._efSkinOff), tostring(ns.IsClassicChrome and ns.IsClassicChrome()),
            tostring(ns.IsForeverChrome and ns.IsForeverChrome()), tostring(ns.ACTIVE_UI_PALETTE and ns.ACTIVE_UI_PALETTE.chrome),
            tostring(ns.FrameArtOn and ns.FrameArtOn()), tostring(sdb and sdb.gpsPopoutBorder), tostring(sdb and sdb.gpsPopoutRim),
            tostring(f._efRingWanted), tostring(f.GetBackdrop and f:GetBackdrop() ~= nil),
            tostring(f._efForever and f._efForever.border and f._efForever.border:IsShown()))
    end
    local ed = popoutFrame and popoutFrame.trip
    out[#out + 1] = sformat("window drag %s (stops missed %d) | planning %s, plan %s | fields: editing %s, closing %s, drag %s",
        tostring(popoutFrame and popoutFrame.dragging == true), popoutFrame and popoutFrame.dragLost or 0,
        tostring(GPS.planning and GPS.planning.name), Planner.co and coroutine.status(Planner.co) or "none",
        tostring(ed and ed.editing ~= nil), tostring(ed and ed.closeAt ~= nil), tostring(ed and ed.drag ~= nil))
    local h = HearthPoint()
    out[#out + 1] = h and sformat("hearth lands at %s (bound %s): map %s %.3f,%.3f, continent %s at %.0f,%.0f",
        tostring(h.m and C_Map.GetMapInfo(h.m) and C_Map.GetMapInfo(h.m).name), tostring(h.bind), tostring(h.m), h.x or 0, h.y or 0,
        tostring(h.ci), h.wx or 0, h.wy or 0) or "hearth landing not learned yet"
    local route = Route()
    if not route then out[#out + 1] = "no route" return out end
    local step = route.steps[route.active or 1]
    local d = route.dest
    out[#out + 1] = sformat("route to %s: step %d of %d%s, ticker %s", tostring(d and d.name),
        route.active or 1, #route.steps, route.arrived and " (arrived)" or "", ticker and "running" or "stopped")
    if d then
        out[#out + 1] = sformat("destination: map %s at %.3f,%.3f, %s, category %s", tostring(d.mapID), d.x or 0, d.y or 0,
            d.zone and "a zone (reached on entering it)" or "a spot", tostring(d.category))
    end
    for i = 1, #route.steps do
        local s = route.steps[i]
        local a = s.arrive or s.go
        out[#out + 1] = sformat("  %d. %s %q: map %s at %.3f,%.3f%s", i, tostring(s.kind), tostring(s.text), tostring(s.mapID),
            s.x or 0, s.y or 0, a and a.wx and sformat(", lands on continent %s at %.0f,%.0f", tostring(a.ci), a.wx, a.wy) or "")
    end
    if step then
        local mapID, x, y = WaypointPoint(step)
        out[#out + 1] = sformat("step: %s | pin map %s at %.3f,%.3f (step map %s%s)", tostring(step.text), tostring(mapID),
            x or -1, y or -1, tostring(step.mapID), (C_Map and C_Map.CanSetUserWaypointOnMap and step.mapID and not C_Map.CanSetUserWaypointOnMap(step.mapID)) and ", refuses waypoints" or "")
        local ci, px, py = PlayerWorldPos()
        local arrive = step.arrive
        local sci, sx, sy
        if arrive and arrive.wx then sci, sx, sy = arrive.ci, arrive.wx, arrive.wy
        elseif arrive then sci, sx, sy = WorldPos(arrive.m, arrive.x, arrive.y)
        else sci, sx, sy = WorldPos(step.mapID, step.x, step.y) end
        if ci and sci then
            out[#out + 1] = sformat("player continent %s, arrival continent %s, distance %s yd (advances within %d)", tostring(ci), tostring(sci),
                ci == sci and tostring(math.floor(((px - sx) ^ 2 + (py - sy) ^ 2) ^ 0.5)) or "other continent", ARRIVE.yards)
        else
            out[#out + 1] = "player or arrival position unknown"
        end
    end
    if GPS.DockStatus then
        for _, line in ipairs(GPS.DockStatus()) do out[#out + 1] = line end
    end
    local wp = C_Map and C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    out[#out + 1] = sformat("native waypoint: %s | super-tracked: %s", wp and sformat("map %s %.3f,%.3f", tostring(wp.uiMapID), wp.position.x, wp.position.y) or "none",
        tostring(C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint and C_SuperTrack.IsSuperTrackingUserWaypoint()))
    return out
end

-- Other ways: the route planned again without its main way of travel,
-- and with no transport at all; up to OTHER_WAYS that differ from it.
local OTHER_WAYS = 2
local WAY_ORDER = { "teleport", "portal", "boat", "zeppelin", "taxi" }
local NO_TRANSPORT = { "taxi", "boat", "zeppelin", "portal", "hearth", "teleports" }

-- The main way a route travels: its first transport by WAY_ORDER, else "walk".
local function WayOf(steps)
    local kinds = ns.GPSRoute and ns.GPSRoute.AVOID_KIND or {}
    local seen = {}
    for i = 1, #steps do
        local k = kinds[steps[i].kind]
        if k then seen[k] = true end
    end
    for _, k in ipairs(WAY_ORDER) do
        if seen[k] then return k end
    end
    return "walk"
end

local function OtherWays(route)
    local db = DB()
    if db and db.gpsShowOtherWays == false then return nil end
    local base = route.wayAvoid or GPS.Avoids() or {}
    local best = WayOf(route.steps)
    local found, ways = { [best] = true }, {}
    local function Try(extra, label)
        local avoid = {}
        for k, v in pairs(base) do avoid[k] = v end
        for i = 1, #extra do avoid[extra[i]] = true end
        local steps, total = GPS:BuildStops(route, nil, avoid, true)
        if not (steps and total and total > 0) then return end
        local way = label or WayOf(steps)
        if found[way] then return end
        found[way] = true
        ways[#ways + 1] = { way = way, total = total, avoid = avoid }
    end
    -- A route that jumps down a ledge: the way without, for who would rather not.
    local J = ns.GPSJumps
    if J and J.Any(route.steps) then Try({ "jumps" }, "nojump") end
    -- A teleport is the hearthstone's or a spell's: both switches.
    if best ~= "walk" then Try(best == "teleport" and { "hearth", "teleports" } or { best }) end
    Try(NO_TRANSPORT)
    table.sort(ways, function(a, b) return a.total < b.total end)
    for i = #ways, OTHER_WAYS + 1, -1 do ways[i] = nil end
    return ways
end

-- A planner job for the next frame; the follower's walks wait behind it.
local jobsPending = 0
local function Soon(fn)
    jobsPending = jobsPending + 1
    Utils.SafeAfter(0, function()
        jobsPending = jobsPending - 1
        fn()
    end)
end

-- Planned once the route is on screen, never in the way of showing it: what
-- to pick up on the way, then the other ways.
local function PlanOtherWays()
    Soon(function()
        local route = Route()
        if not (route and route.dest and not route.arrived) or GPS:IsPlanning() then return end
        -- Shown only in the GPS's own views: with none on screen, worked
        -- out once one is (about 40% of the game's time for seconds after
        -- every route, a guide sending one each step, 2026-11-19).
        if not GPS.AnySurfaceVisible() then
            route.othersWanted = true
            return
        end
        route.othersWanted = nil
        GPS:Plan(nil, function()
            local _, _, advice = GPS:BuildStops(route, route.via, route.wayAvoid)
            local ways = OtherWays(route)
            -- What a parachute would save, beside the other ways.
            local J = ns.GPSJumps
            local shop = ways and J and J.ShopTip(route)
            GPS.SettleGrid()
            return advice, ways, shop
        end, function(advice, ways, shop)
            if Route() ~= route then return end
            route.advice, route.others, route.shop = advice or route.advice, ways, shop or nil
        end)
    end)
end
GPS.PlanOtherWays = PlanOtherWays

-- The route's drawn walks, saved with it for the next session's login
-- (Route.KeepWalk), keyed as DrawWalks asks for them.
local function KeptWalks(steps, from)
    local Engine = ns.GPSRoute
    local out = {}
    for i = 1, #steps do
        local s = steps[i]
        local a, b = s.from or (i > 1 and steps[i - 1].arrive) or from, s.go or s.arrive
        if s.kind == "travel" and not s.fly and a and b and a.wx and b.wx and a.ci == b.ci then
            out[#out + 1] = Engine.SaveWalk(a.ci, a.wx, a.wy, b.wx, b.wy, s.near)
        end
    end
    return out
end

-- The grid back under the shown route's own settings. Every plan leaves
-- its own behind: the parachute tip's (any drop) stayed after each route,
-- the route's ways kept under the old ones were found no more, and every
-- walk searched from then on took any drop (2026-11-19). A field: the
-- file is at Lua's 200 locals.
function GPS.SettleGrid()
    local route, Engine = Route(), ns.GPSRoute
    if route and Engine and Engine.Settle then
        Engine.Settle({ avoid = route.wayAvoid or GPS.Avoids() }, route.from and route.from.ci or 0)
    end
end

-- The route's walks past the one set out on, drawn now that the route is
-- on screen: each timed by its way, split by zone, the total following;
-- then, unless onlyDraw, the advice and the other ways. Its ways as kept
-- now are the shown ones from here on (Route.ShowWalks).
local function AfterRoute(onlyDraw)
    local shownRoute = Route()
    if shownRoute and ns.GPSRoute and ns.GPSRoute.ShowWalks then
        ns.GPSRoute.ShowWalks(shownRoute, shownRoute.steps, shownRoute.from)
    end
    Soon(function()
        local route = Route()
        local Engine = ns.GPSRoute
        if not (route and route.dest and route.from and not route.arrived and Engine and Engine.DrawWalks)
            or GPS:IsPlanning() then
            if not onlyDraw then PlanOtherWays() end
            return
        end
        GPS:Plan(nil, function()
            local Nav = ns.GPSNav
            GPS.SettleGrid()
            if Nav then Nav.yieldCo = coroutine.running() end
            Engine.DrawWalks(route.steps, route.from)
            if Nav then Nav.yieldCo = nil end
            return true
        end, function()
            if Route() ~= route then return end
            local current = route.steps[route.active or 1]
            local steps = SplitWalks(route.steps, route.dest, route.from)
            for i = 1, #steps do
                if steps[i] == current then route.active = i end
            end
            local total = 0
            for i = 1, #steps do total = total + (steps[i].sec or 0) end
            route.steps, route.total, route.eta = steps, total, total
            if Engine.ShowWalks then Engine.ShowWalks(route, steps, route.from) end
            route.walks = Engine.SaveWalk and KeptWalks(steps, route.from) or nil
            if route.report and Engine.StepsCode then route.report.steps = Engine.StepsCode(steps) end
            closing.eta = nil
            if ns.GPSFollow and ns.GPSFollow.Reset then ns.GPSFollow.Reset() end
            if ns.GPSPreview and ns.GPSPreview.Follow then ns.GPSPreview:Follow() end
            Refresh()
            if not onlyDraw then PlanOtherWays() end
        end)
    end)
end
GPS.AfterRoute = AfterRoute

-- A walk the follower needs (from where the player strayed to), drawn in
-- the planner's slices; the follower reads it once it is there. Refused
-- while the planner runs or a job waits for it: asked again.
function GPS.DrawWalk(ci, sx, sy, tx, ty, near)
    local Engine = ns.GPSRoute
    if jobsPending > 0 or GPS:IsPlanning() or not (Engine and Engine.WalkPath) then return false end
    GPS:Plan(nil, function()
        local Nav = ns.GPSNav
        GPS.SettleGrid()
        if Nav then Nav.yieldCo = coroutine.running() end
        Engine.WalkPath(ci, sx, sy, tx, ty, nil, near)
        if Nav then Nav.yieldCo = nil end
        return true
    end, function()
        if ns.GPSPreview and ns.GPSPreview.Follow then ns.GPSPreview:Follow() end
    end, true)
    return true
end

-- Takes one of the other ways: the route keeps to it, starting over too.
function GPS:TakeOtherWay(other)
    local route = Route()
    if not (route and route.dest and other) then return end
    self:Plan(route.dest.name, function() return self:BuildStops(route, nil, other.avoid, true, "first") end,
        function(steps, total, advice)
            if not (steps and Route() == route) then return end
            GPS.Replanned(route, steps, total, advice)
            route.wayAvoid, route.others = other.avoid, nil
            TrackStep(1)
            AfterRoute()
        end)
end

-- A folded surface opens for a field to type in: the window's fold or
-- the section's, which share one saved state.
function GPS.Unfold(frame)
    if frame.collapsed and frame.collapseBtn then frame.collapseBtn:Click() end
    if frame.expanded == false and frame.fold then frame.fold:Click() end
end

-- Picking a start in a surface's search box: its hits set the start.
-- Where the trip's fields show, the start's own field takes it.
function GPS:PickStart(frame)
    if frame and frame.trip then
        GPS.Unfold(frame)
        if frame.trip:FocusStart() then return end
    end
    GPS:EndAlong()
    GPS.picking = frame
    Refresh()
    local box = frame and frame.search
    if box then
        box:Show()
        box._blockAutoFocus = nil
        box:SetFocus()
    end
end

function GPS:EndPick()
    if not GPS.picking then return end
    GPS.picking = nil
    Refresh()
end

-- Places along the route ahead in a surface's search: the trip's field
-- before the destination where the trip's fields show, else the search
-- box, tagged. A pick is a stop before the destination.
function GPS:SearchAlong(frame)
    local route = Route()
    if not (route and not route.arrived and frame) then return end
    GPS:EndPick()
    GPS.Unfold(frame)
    if frame.trip then
        frame.trip:SearchAlong()
        return
    end
    local box = frame.search
    if not box then return end
    GPS.along = frame
    ns.GPSTrip.Tag(box, true)
    box:SetText("")
    frame:ShowHits(nil)
    Refresh()
    box:Show()
    box._blockAutoFocus = nil
    box:SetFocus()
    -- Its X ends the search; the client's box hides it when empty and
    -- unfocused, and a box that never took focus had no way out.
    if box.clearButton then box.clearButton:Show() end
end

function GPS:EndAlong()
    local frame = GPS.along
    if not frame then return end
    GPS.along = nil
    local box = frame.search
    if box then
        ns.GPSTrip.Tag(box, false)
        if box.clearButton and not box:HasFocus() and (box:GetText() or "") == "" then box.clearButton:Hide() end
    end
    Refresh()
end

-- Starts routes at data's place ({ name, mapID, x, y }), or at the player
-- again with nil. A route on screen is planned again from there; with none,
-- the GPS window asks where to. quiet: the start alone, the caller plans.
function GPS:SetStart(data, quiet)
    local c = CharDB()
    if not c then return end
    c.start = data and { name = data.name, mapID = data.zoneMapID or data.mapID, x = data.x or 0.5, y = data.y or 0.5 } or nil
    GPS.picking = nil
    for i = 1, #surfaces do
        local box = surfaces[i].search
        if box then
            box:SetText("")
            box:ClearFocus()
        end
    end
    if quiet then return end
    local route = Route()
    local dest = route and route.dest
    if dest and not route.arrived then
        -- The trip again from the new start, every stop kept.
        if ns.GPSTrip and route.stops and #route.stops > 1 then
            ns.GPSTrip.Navigate({ quiet = true })
        else
            GPS:NavigateTo({ name = dest.name, icon = dest.icon, category = dest.category, isZone = dest.zone,
                             displayID = dest.displayID, questMark = dest.questMark, questID = dest.questID,
                             followGUID = dest.followGUID, door = dest.door, instanceID = dest.instance,
                             mapID = dest.mapID, x = not dest.zone and dest.x or nil, y = not dest.zone and dest.y or nil },
                           { quiet = true })
        end
    elseif data then
        GPS:TogglePopout(true)
        local box = popoutFrame and popoutFrame.search
        if box then
            box._blockAutoFocus = nil
            box:SetFocus()
        end
    end
    Refresh()
end

-- A route that went wrong: the issue form, filled in with the route, and
-- with the step when the feedback is about one.
function GPS:ReportRoute(stepIndex)
    local route = Route()
    local Engine = ns.GPSRoute
    if not (route and Engine and Engine.ReportCode and EasyFind.OpenRouteReport) then return end
    local code = Engine.ReportCode(route, { version = ns.version, avoid = route.wayAvoid or GPS.Avoids(),
                                            hearth = HearthPoint() })
    local step = stepIndex and route.steps and route.steps[stepIndex]
    local line
    if step then
        local a = step.arrive
        line = sformat("%d/%d %s%s %s", stepIndex, #route.steps, Engine.StepsCode({ step }),
            (a and a.m and a.x) and sformat(" at %d:%.4f:%.4f", a.m, a.x, a.y or 0) or "", step.text or "")
    end
    if code then EasyFind:OpenRouteReport(code, line) end
end

-- The route put away; the map tab goes back to its search unless the
-- caller stays (the trip's last stop cleared to type another).
function GPS:Clear(opts)
    local route = Route()
    if route then EasyFind.API.Fire("gps", "routeCleared") end
    if route and not route.arrived then LiftPin(route) end
    local MapSearch = ns.MapSearch
    if MapSearch and MapSearch.ClearRouteEnd then MapSearch:ClearRouteEnd() end
    -- The map's pin on the journey's end goes with the route, whether the
    -- route put it there or the click that started the route did.
    local dest = route and route.dest
    if dest and MapSearch and MapSearch.ClearPinAt then MapSearch:ClearPinAt(dest.mapID, dest.x, dest.y) end
    local c = CharDB()
    if c then c.route, c.start = nil, nil end
    GPS.picking = nil
    GPS:EndAlong()
    StopTicker()
    -- Nothing to follow now: what its walks decoded goes after a minute.
    Planner.ReleaseLater()
    Refresh()
    if not (opts and opts.stay) and ns.MapTab and ns.MapTab.ShowSearchView then ns.MapTab:ShowSearchView() end
end

function GPS:Open()
    if ns.MapTab and ns.MapTab.ShowPage and ns.MapTab:ShowPage("gps") then return true end
    -- The full-screen classic map has no side panel to hold the page: the
    -- opener shows the map alone, and the route is drawn on it.
    return WorldMapFrame ~= nil and WorldMapFrame:IsShown()
end

-- Rendering, shared by the page and the pop-out

-- Teleport step icon: a secure button for the spell, toy or item.
-- Attributes change only out of combat; in combat it hides.
local CAST_MASK_SCALE = 64 / 45

-- Where an item sits in the bags, for its own tooltip.
local function BagSlotOf(itemID)
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemID) then return nil end
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            if C_Container.GetContainerItemID(bag, slot) == itemID then return bag, slot end
        end
    end
    return nil
end

-- The swipe follows the spell's or item's cooldown.
local function UpdateCooldown(btn)
    if not (btn and btn.cd) then return end
    local start, duration, rate = 0, 0, nil
    if btn.itemID and C_Container and C_Container.GetItemCooldown then
        local ok, s, d = pcall(C_Container.GetItemCooldown, btn.itemID)
        if ok then start, duration = s or 0, d or 0 end
    elseif btn.spellID and C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, btn.spellID)
        if ok and info then start, duration, rate = info.startTime or 0, info.duration or 0, info.modRate end
    end
    -- A secret cooldown (WoW Forever withholds the numbers in a fight) still
    -- draws: the swipe takes secret values, a comparison of them errors.
    if issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then
        btn.cd:SetCooldown(start, duration, rate)
    elseif duration and duration > 1.5 then
        btn.cd:SetCooldown(start, duration, rate)
    else
        btn.cd:Clear()
    end
end

local castButtons = {}   -- every cast button, hidden as a fight begins

-- A secure button protects every frame it hangs from in a fight, so it belongs to
-- UIParent: pinned to its row out of combat, hidden and unpinned as a fight begins.
local function CastButton(row, inset)
    local btn = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    btn.row, btn.inset = row, inset
    castButtons[#castButtons + 1] = btn
    row:HookScript("OnHide", function()
        if not (InCombatLockdown and InCombatLockdown()) then btn:Hide() end
    end)
    btn:SetSize(20, 20)
    -- The game acts on the down-click by default now; take both and act
    -- on the up-click only, so one press is one cast.
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("useOnKeyDown", false)
    -- The action bar's button, scaled down: the icon uncropped under the
    -- rounded mask, the frame sitting on the icon's edge, not outside it.
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    -- The mask's rounded square fills the middle 45/64 of its texture:
    -- drawn larger than the icon so the square covers it.
    local mask = btn:CreateMaskTexture()
    mask:SetPoint("CENTER", btn.icon, "CENTER", 0, 0)
    mask:SetTexture("Interface\\HUD\\UIActionBarIconFrameMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    btn.icon:AddMaskTexture(mask)
    local function FitMask(self, w, h)
        mask:SetSize((w or self:GetWidth()) * CAST_MASK_SCALE, (h or self:GetHeight()) * CAST_MASK_SCALE)
    end
    btn:SetScript("OnSizeChanged", FitMask)
    FitMask(btn, 20, 20)
    local frame = btn:CreateTexture(nil, "OVERLAY")
    frame:SetAtlas("UI-HUD-ActionBar-IconFrame")
    frame:SetAllPoints(btn.icon)
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    -- The cooldown swipe over the icon, as the action bar shows it.
    btn.cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cd:SetAllPoints(btn.icon)
    btn.cd:SetDrawEdge(false)
    btn.cd:SetHideCountdownNumbers(true)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        -- Toy box or bag tooltip: they carry the cooldown line, the plain item tooltip does not.
        if self.spellID and not self.itemID then GameTooltip:SetSpellByID(self.spellID)
        elseif self.itemID and self.toy and GameTooltip.SetToyByItemID then GameTooltip:SetToyByItemID(self.itemID)
        elseif self.itemID then
            local bag, slot = BagSlotOf(self.itemID)
            if bag then GameTooltip:SetBagItem(bag, slot) else GameTooltip:SetItemByID(self.itemID) end
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    -- Pulsed while its step is hovered: the thing to press.
    local pulse = btn:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local grow = pulse:CreateAnimation("Scale")
    grow:SetScaleFrom(1, 1)
    grow:SetScaleTo(1.25, 1.25)
    grow:SetDuration(0.4)
    grow:SetSmoothing("IN_OUT")
    btn.pulse = pulse
    btn:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    btn:RegisterEvent("BAG_UPDATE_COOLDOWN")
    btn:SetScript("OnEvent", UpdateCooldown)
    btn:Hide()
    return btn
end

-- Every step still ahead offers its button, the one that is up bright
-- and a later one dimmed; a taken teleport shows none.
local function SetupCast(btn, step, active, ahead)
    if not btn then return false end
    -- In a fight a secure button can be neither hidden nor changed: it was
    -- hidden as the fight began and comes back after it.
    if InCombatLockdown and InCombatLockdown() then return false end
    local row = btn.row
    -- Not our child, so a list that clips does not clip it: a row scrolled
    -- out of sight takes its button along.
    local clip, outside = row:GetParent(), false
    if clip and clip.DoesClipChildren and clip:DoesClipChildren() then
        local top, bottom, rt, rb = clip:GetTop(), clip:GetBottom(), row:GetTop(), row:GetBottom()
        outside = top and rt and (rt > top + 1 or rb < bottom - 1) or false
    end
    -- A teleport's spell or item, or what lands the character at a walk's ledge.
    local J = ns.GPSJumps
    local spellID, itemID, toy
    if J then spellID, itemID, toy = J.StepCast(step) end
    if not (active or ahead) or not (spellID or itemID)
        or outside or not row:IsVisible() or row:GetEffectiveAlpha() < 0.05 then
        btn:Hide()
        return false
    end
    btn:ClearAllPoints()
    btn:SetPoint("RIGHT", row, "RIGHT", btn.inset, 0)
    btn:SetFrameStrata(row:GetFrameStrata())
    btn:SetFrameLevel(row:GetFrameLevel() + 3)
    btn:SetAlpha(active and 1 or 0.55)
    btn.spellID, btn.itemID, btn.toy = spellID, itemID, toy
    local tex
    if itemID then
        if toy then
            btn:SetAttribute("type", "toy")
            btn:SetAttribute("toy", itemID)
        else
            btn:SetAttribute("type", "item")
            btn:SetAttribute("item", "item:" .. itemID)
        end
        tex = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
    else
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", spellID)
        tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    end
    btn.icon:SetTexture(tex or 134400)
    UpdateCooldown(btn)
    btn:Show()
    return true
end

local function StepRow(container, i)
    local rows = container.rows
    local row = rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, container.list)
    row:SetHeight(ROW_H)
    row:SetPoint("LEFT", container.list, "LEFT", 0, 0)
    row:SetPoint("RIGHT", container.list, "RIGHT", 0, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- The menus' own rounded hover wash, not a flat square.
    Utils.InstallMenuRowHighlight(row)
    -- Numbers sit against the text column, right-aligned in their box;
    -- the danger line starts where their ink does.
    row.num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.num:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.num:SetWidth(18)
    row.num:SetJustifyH("RIGHT")
    row.num._efOwnColor = true
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text._efOwnColor = true
    -- Anchored from the top so a wrapped step grows the row downward;
    -- a single line sits at the same place either way.
    row.text:SetPoint("TOPLEFT", row.num, "TOPRIGHT", 6, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)
    row.num:ClearAllPoints()
    row.num:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -4)
    -- A teleport's icon near the row's right edge, with a little room.
    row.cast = CastButton(row, -8)
    -- A learning step drops from the trip with the X its row shows on hover.
    row.drop = ns.CreateCloseX(row, 10)
    row.drop:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -4)
    row.drop:Hide()
    row.drop:SetScript("OnClick", function() if row.learnID then GPS:DropLearn(row.learnID) end end)
    Utils.AttachDelayedTooltip(row.drop, "ANCHOR_TOP", function() return L["GPS_SKIP_LEARN"] end)
    row.drop:HookScript("OnLeave", function() if not row:IsMouseOver() then row.drop:Hide() end end)
    -- A plain click never moves the route: it shows the step's preview
    -- (beside the map it pins it); Shift-click jumps; right-click gives feedback.
    row:SetScript("OnClick", function(self, button)
        if not self.index then return end
        if button == "RightButton" then
            GPS.ShowStepMenu(container, self.index)
        elseif IsShiftKeyDown() then
            GPS.GoToStep(self.index)
        elseif container.previewOnHover and ns.GPSPreview then
            ns.GPSPreview:Show(self.index)
        else
            GPS.ShowStep(self.index)
        end
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.text:GetText() or "")
        GameTooltip:AddLine(L["GPS_STEP_TT"], 1, 1, 1, true)
        GameTooltip:Show()
        -- A spell or an item pulses its own icon.
        if self.cast and self.cast:IsShown() and self.cast.pulse then self.cast.pulse:Play() end
        if self.learnID then self.drop:Show() end
    end)
    row:SetScript("OnLeave", function(self)
        GameTooltip_Hide()
        if self.cast and self.cast.pulse then self.cast.pulse:Stop() end
        if not self.drop:IsMouseOver() then self.drop:Hide() end
    end)
    rows[i] = row
    return row
end

-- A tip's click could be an accident: the stop is added only once
-- confirmed, with what it does to this trip spelled out.
local function TipClick(self)
    local tip = self.tip
    if tip and tip.report then
        GPS:ReportRoute()
        return
    end
    if tip and tip.other then
        GPS:TakeOtherWay(tip.other)
        return
    end
    -- The shop tip searches for the item.
    local S = ns.Search
    local bar = tip and tip.shop and S and S.GetSearchFrame and S:GetSearchFrame()
    if bar and bar.editBox then
        S:Show(true)
        bar.editBox:SetText(tip.shop.name)
        return
    end
    local route = Route()
    if not (tip and tip.p and tip.viaTotal and route) then return end
    -- What the stop costs this trip, then what it gives the trips after.
    local now = route.total or route.eta or tip.viaTotal
    local text = sformat(L["GPS_STOP_CONFIRM_FMT"], tip.name or "?", EtaText(mmax(0, tip.viaTotal - now)),
        EtaText(tip.viaTotal), EtaText(now))
    if tip.after then text = text .. " " .. sformat(L["GPS_STOP_AFTER_FMT"], EtaText(tip.after)) end
    ns.ShowThemedDialog({ text = text, acceptText = L["GPS_STOP_ADD"], cancelText = _G["CANCEL"],
                          onAccept = function() GPS:AddStop(tip) end })
end

local function TipEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.text:GetText() or "", nil, nil, nil, nil, true)
    local tip = self.tip
    local key = tip and (tip.report and "GPS_REPORT_TT" or tip.other and "GPS_OTHER_WAY_TT"
        or tip.detour and "GPS_ADVICE_DETOUR_TT" or tip.shop and "GPS_SHOP_TT") or "GPS_ADVICE_TT"
    -- A detour lists the way trips like this would go once it is learned.
    local way = tip and tip.detour and tip.way
    if way and #way > 0 then
        GameTooltip:AddLine(L["GPS_ADVICE_DETOUR_WAY_TT"], 1, 1, 1, true)
        for _, text in ipairs(way) do GameTooltip:AddLine("- " .. text, 0.8, 0.8, 0.8, true) end
        GameTooltip:AddLine(L["GPS_ADVICE_ADD_STOP_TT"], 1, 1, 1, true)
    else
        GameTooltip:AddLine(L[key], 1, 1, 1, true)
    end
    GameTooltip:Show()
end

-- Advice under the steps: flight paths worth learning. A click routes
-- to that flight master.
local function TipRow(container, i)
    container.tips = container.tips or {}
    local row = container.tips[i]
    if row then return row end
    row = CreateFrame("Button", nil, container.list)
    row:SetHeight(ROW_H)
    Utils.InstallMenuRowHighlight(row)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text._efOwnColor = true
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 30, -4)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button ~= "RightButton" then return TipClick(self) end
        if container.ShowMenu then container.ShowMenu() end
    end)
    row:SetScript("OnEnter", TipEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    container.tips[i] = row
    return row
end

-- The advice as lines: masters on the way first (with what learning one
-- saves when the engine priced it), then the best one elsewhere.
-- The step whose leg passes nearest a spot: where a tip about that spot
-- is read among the steps.
function GPS.StepNear(route, p)
    local Follow = ns.GPSFollow
    if not (Follow and p and p.ci and p.wx and route.steps) then return nil end
    local best, bestD
    for i = 1, #route.steps do
        local s = route.steps[i]
        if s.kind == "travel" then
            local sci, sx, sy = Follow.StartOf(route, i)
            local tci, tx, ty = Follow.World(s.go or s.arrive)
            if sci == p.ci and tci == p.ci and sx and tx then
                local d = ToSegment(p.wx, p.wy, sx, sy, tx, ty)
                if not bestD or d < bestD then best, bestD = i, d end
            end
        end
    end
    return best
end

-- The tips read after step i (their spot lies along it), or, with i nil,
-- those read after the last step: the route's other ways, the shop.
local function TipsAfter(tips, i, n)
    local out = {}
    for t = 1, tips and #tips or 0 do
        local step = tips[t].step
        if (i and step == i) or (not i and (not step or step > n)) then out[#out + 1] = tips[t] end
    end
    return out
end

local function AdviceLines(route)
    if route and route.arrived then return { { text = L["GPS_REPORT"], report = true } } end
    if not route then return nil end
    -- Put off while no view showed them: worked out now that one does.
    if route.othersWanted and GPS.AnySurfaceVisible() then PlanOtherWays() end
    -- Suggest detours off: no flight path to learn, on the way or off it.
    local db = DB()
    local a = (db and db.gpsShowDetours == false) and {} or route.advice or {}
    local out = {}
    local learn = a.learn
    for i = 1, #(a.pickups or {}) do
        local p = a.pickups[i]
        local text
        local after
        if learn and learn.id == p.id then
            text = sformat(L["GPS_ADVICE_PICKUP_SAVE_FMT"], p.name or "?", EtaText(learn.save))
            after = learn.total
            learn = nil
        else
            text = sformat(L["GPS_ADVICE_PICKUP_FMT"], p.name or "?")
        end
        out[#out + 1] = { text = text, id = p.id, name = p.name, p = p.p, viaTotal = p.viaTotal, after = after,
                          before = p.before, step = GPS.StepNear(route, p.p) }
    end
    if learn and learn.extra then
        -- Out of the way: what it costs now, what it saves every time after.
        out[#out + 1] = { text = sformat(L["GPS_ADVICE_DETOUR_FMT"], learn.name or "?", EtaText(learn.extra), EtaText(learn.save)),
                          id = learn.id, name = learn.name, p = learn.p, viaTotal = learn.viaTotal, after = learn.total, detour = true,
                          way = learn.way, step = GPS.StepNear(route, learn.p) }
    end
    for _, other in ipairs(route.others or {}) do
        -- Against the route shown, both as planned: the header runs at the
        -- pace seen (on foot where a mount was planned), a planned total never.
        local more = other.total - (route.total or other.total)
        local diff = sformat(L[more >= 0 and "GPS_WAY_LONGER_FMT" or "GPS_WAY_SHORTER_FMT"], EtaText(math.abs(more)))
        local way = sformat(L["GPS_WAY_" .. other.way:upper() .. "_FMT"], diff)
        out[#out + 1] = { text = sformat(L["GPS_OTHER_WAY_FMT"], way), other = other }
    end
    local shop = route.shop
    if shop then out[#out + 1] = { text = sformat(L["GPS_SHOP_FMT"], shop.name, EtaText(shop.save)), shop = shop } end
    return #out > 0 and out or nil
end

-- The warning that the route ahead walks through ground whose creatures
-- con skull to the player, naming the zone it starts in; nil with none,
-- once put away, or while its walks are not all drawn. Kept per steps.
GPS.dangerFound = setmetatable({}, { __mode = "k" })
function GPS.DangerText(route)
    local db = DB()
    if route.dangerSeen or route.arrived or (db and db.gpsDangerWarn == false) then return nil end
    local Npcs, Engine, Follow = ns.Npcs, ns.GPSRoute, ns.GPSFollow
    local level = UnitLevel("player")
    if not (Npcs and Npcs.DeadlyAlong and Engine and Engine.WalkPath and Follow and level) then return nil end
    local steps, active = route.steps, route.active or 1
    local c = GPS.dangerFound[steps]
    if c and c.n == #steps and c.active == active and c.level == level then return c.text or nil end
    local faction = UnitFactionGroup("player")
    local text, drawn = false, true
    for i = active, #steps do
        local step = steps[i]
        if step.kind == "travel" and not step.fly and not step.corpse then
            local sci, sx, sy = Follow.StartOf(route, i)
            local tci, tx, ty = Follow.World(step.go or step.arrive)
            local path = sci and sci == tci and Engine.WalkPath(sci, sx, sy, tx, ty, true, step.near)
            if path == nil then
                drawn = false
            elseif path then
                local d = Npcs.DeadlyAlong(path, sci, level, faction)
                if not d then return nil end
                -- The first met ahead; the red stretches say where, no zone named.
                if d.skull or d.guard then
                    text = L[(d.guard and (not d.skull or d.guard < d.skull)) and "GPS_DANGER_GUARDS" or "GPS_DANGER"]
                    break
                end
            end
        end
    end
    if text or drawn then GPS.dangerFound[steps] = { n = #steps, active = active, level = level, text = text } end
    return text or nil
end

-- The client's red; a font set anew takes its own color, so set after.
GPS.DANGER_RGB = RED_FONT_COLOR and { RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b } or { 1, 0.13, 0.13 }

-- A surface's red warning line, built on first use: its X puts it away
-- for the trip.
function GPS.DangerLine(holder, parent, font)
    local row = holder.dangerLine
    if row then return row end
    row = CreateFrame("Frame", nil, parent)
    row.text = row:CreateFontString(nil, "ARTWORK", font)
    row.text._efOwnColor = true
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetWordWrap(true)
    row.text:SetTextColor(unpack(GPS.DANGER_RGB))
    row.close = ns.CreateCloseX(row, 10)
    row.close:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -1)
    row.close:SetScript("OnClick", function()
        local route = Route()
        if route then route.dangerSeen = true end
        GPS.RefreshSurfaces()
    end)
    holder.dangerLine = row
    return row
end

local StyleTrackButton, RouteTracked   -- defined with the tracking toggle below; the surfaces render before it

-- The route's start in the panel: where the player stands or the place
-- picked; a click picks another, Reset goes back to the player's spot.
local function FromRow(container)
    local row = container.fromRow
    if row then return row end
    row = CreateFrame("Button", nil, container.list)
    row:SetHeight(ROW_H)
    Utils.InstallMenuRowHighlight(row)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text._efOwnColor = true
    row.text:SetPoint("LEFT", row, "LEFT", 30, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    local reset = CreateFrame("Button", nil, row)
    reset:SetHeight(14)
    local label = reset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("RIGHT", reset, "RIGHT", 0, 0)
    label:SetText(_G["RESET"] or "Reset")
    GPS.Inked(container, function(ink) label:SetTextColor(unpack(ink.dim)) end)
    label._efOwnColor = true
    reset:SetWidth((label:GetStringWidth() or 40) + 4)
    reset:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    reset:SetScript("OnEnter", function() label:SetTextColor(unpack(GPS.Ink(container).hover)) end)
    reset:SetScript("OnLeave", function() label:SetTextColor(unpack(GPS.Ink(container).dim)) end)
    reset:SetScript("OnClick", function() GPS:SetStart(nil) end)
    row.reset = reset
    row.text:SetPoint("RIGHT", reset, "LEFT", -6, 0)
    row:SetScript("OnClick", function() GPS:PickStart(container) end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["GPS_FROM_TT"], 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    container.fromRow = row
    return row
end

local function Render(container)
    local route = Route()
    SearchHint(container)
    -- Picking a start: the search and its hits in the steps' place.
    if GPS.picking == container then route = nil end
    local rows = container.rows
    if container.glyphTex then
        container.glyphTex:SetVertexColor(unpack(ns.ChromeGlyphColor()))
        container.glyphTex:SetAlpha(1)
    end
    if container.track then StyleTrackButton(container.track, route ~= nil and RouteTracked()) end
    if not route then
        if ns.GPSPreview and ns.GPSPreview.Reset then ns.GPSPreview:Reset() end
        if GPS.planning then Planner.Show(container.title) else container.title:SetText("") end
        for i = 1, #rows do rows[i]:Hide() end
        for i = 1, #(container.tips or {}) do container.tips[i]:Hide() end
        if container.fromRow then container.fromRow:Hide() end
        if container.dangerLine then container.dangerLine:Hide() end
        container.list:SetHeight(1)
        container.contentHeight = 0
        if container.search then container.search:Show() end
        -- A first way being found says so in the hint's place, under the
        -- trip's fields (the title saying it sits behind them); else the
        -- search box says what to do, or the hint does.
        local finding = container.trip and GPS.planning
        if finding then
            ns.GPSTrip.PlaceEmpty(container, true)
            Planner.Show(container.empty)
        elseif not container.search then
            container.empty:SetText(L["GPS_EMPTY"])
        end
        container.empty:SetShown(finding or not container.search)
        if container.trip then container.trip:Refresh(nil) end
        if container.OnRouteChanged then container:OnRouteChanged(false) end
        return
    end
    container.empty:Hide()
    if container.search then
        container.search:Show()
        -- A new route: places typed before it go.
        if container.shownRoute ~= route then
            container.shownRoute = route
            container.search:SetText("")
            container:ShowHits(nil)
        end
    end
    -- Folded, the title names the stop a trip heads for now, not its last.
    local nowStep = not route.arrived and route.steps and route.steps[route.active or 1]
    if GPS.planning then
        Planner.Show(container.title)
    else
        container.title:SetText(sformat(L["GPS_TO_FMT"], nowStep and nowStep.name or route.dest.name or "?"))
    end
    if route.arrived then
        -- Arrived: the announcement in the body where the time line and
        -- the steps were, nothing left to follow.
        container.eta:SetText("")
        container:PlaceEtaTag(false)
        if container.trip then ns.GPSTrip.PlaceEmpty(container, false) end
        container.empty:SetText(GPS.ArrivedText(route))
        container.empty:Show()
    else
        local eta = ""
        if route.eta and route.eta > 0 then eta = EtaText(route.eta) end
        -- The trip editor stands where the title was: a plan under way says so here.
        if container.trip and GPS.planning then Planner.Show(container.eta) else container.eta:SetText(eta) end
    end
    if container.trip then
        container.trip:Refresh(route)
        -- The time line and the Clear link in the page's size, as the steps.
        local px = GPS.MapTextPx(container)
        local linkText = container.clearBtn and container.clearBtn.text
        if px and linkText then
            SizeFont(container.eta, px)
            SizeFont(container.etaTagText, px)
            SizeFont(linkText, px)
            container.clearBtn:SetWidth(container.noClear and container.fieldsBtn:GetWidth()
                or (linkText:GetStringWidth() or 60) + 4)
            if container.note then SizeFont(container.note, px) end
        end
    end
    local y = 0
    local offset = container.scrollOffset or 0
    local shown = route.arrived and 0 or #route.steps
    -- The window set to the next step alone: that step, nothing else.
    local dbo = DB()
    local only = container.isPopout and dbo and dbo.gpsPopoutNextOnly and shown > 0 and (route.active or 1) or nil
    -- Done steps hidden (the setting): the list starts at the active step.
    local first = only or ((dbo and dbo.gpsHideDone and not route.arrived) and (route.active or 1)) or 1
    local scale = MapScale(container)
    local rowBase = scale and mfloor(ROW_H * scale + 0.5) or ROW_H
    if container.isPopout and container.eta and container.etaScale ~= (scale or 0) then
        container.etaScale = scale or 0
        ScaleFont(container.eta, "GameFontHighlightSmall", scale and MAP_STEP_PX * scale)
        ScaleFont(container.etaTagText, "GameFontHighlightSmall", scale and MAP_STEP_PX * scale)
    end
    -- The tag after the time, sized with the fonts above; not while a plan is under way.
    container:PlaceEtaTag(not route.arrived and not GPS.planning and route.eta ~= nil and route.eta > 0)
    -- A wrapped line is measured at the width it is given outright: a new
    -- row's anchors may not be placed yet when it is measured.
    local listW = container.list:GetWidth() or 0
    local from = FromRow(container)
    if route.arrived or only or container.trip then
        from:Hide()
    else
        local s = Start()
        from:ClearAllPoints()
        from:SetPoint("TOPLEFT", container.list, "TOPLEFT", 0, -y + offset)
        from:SetPoint("RIGHT", container.list, "RIGHT", 0, 0)
        from.text:SetText(sformat(L["GPS_FROM_FMT"], s and s.name or L["GPS_FROM_HERE"]))
        from.text:SetTextColor(unpack(GPS.Ink(container).dim))
        from.reset:SetShown(s ~= nil)
        from:SetHeight(rowBase)
        from:Show()
        y = y + rowBase
    end
    local warn = not only and GPS.DangerText(route)
    if warn then
        local row = GPS.DangerLine(container, container.list, "GameFontHighlightSmall")
        if row.fontScale ~= (scale or 0) then
            row.fontScale = scale or 0
            ScaleFont(row.text, "GameFontHighlightSmall", scale and MAP_STEP_PX * scale)
        end
        -- The text starts where a step number's ink does: the number box's
        -- right edge less one number's width, measured in the numbers' font.
        local probe = container.list.numProbe
        if not probe then
            probe = container.list:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            probe:Hide()
            container.list.numProbe = probe
        end
        ScaleFont(probe, "GameFontNormalSmall", scale and MAP_STEP_PX * scale)
        probe:SetText("1.")
        local numW = scale and mfloor(18 * scale + 0.5) or 18
        local inset = mmax(0, numW - (probe:GetStringWidth() or 0))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", container.list, "TOPLEFT", 6 + inset, -y - 4 + offset)
        row:SetPoint("RIGHT", container.list, "RIGHT", -8, 0)
        row.text:SetWidth(mmax(40, listW - 30 - inset))
        row.text:SetText(warn)
        local h = row.text:GetStringHeight() or 0
        row:SetHeight(mmax(10, h))
        row:Show()
        y = y + mmax(rowBase, h + 8)
    elseif container.dangerLine then
        container.dangerLine:Hide()
    end
    local tips = not only and AdviceLines(route)
    local nTips = 0
    local function PlaceTips(list)
        for t = 1, #list do
            nTips = nTips + 1
            local row = TipRow(container, nTips)
            row.tip = list[t]
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", container.list, "TOPLEFT", 0, -y + offset)
            row:SetPoint("RIGHT", container.list, "RIGHT", 0, 0)
            if row.fontScale ~= (scale or 0) then
                row.fontScale = scale or 0
                ScaleFont(row.text, "GameFontHighlightSmall", scale and (MAP_STEP_PX - 1) * scale)
            end
            row.text:SetWidth(mmax(40, listW - 36))
            row.text:SetText(list[t].text)
            row.text:SetTextColor(unpack(GPS.Ink(container).aside))
            local rowH = mmax(rowBase, (row.text:GetStringHeight() or 0) + 8)
            row:SetHeight(rowH)
            row:Show()
            y = y + rowH
        end
    end
    for i = first, only or shown do
        local step = route.steps[i]
        local row = StepRow(container, i)
        row.index = i
        if row.fontScale ~= (scale or 0) then
            row.fontScale = scale or 0
            ScaleFont(row.text, "GameFontHighlightSmall", scale and MAP_STEP_PX * scale)
            ScaleFont(row.num, "GameFontNormalSmall", scale and MAP_STEP_PX * scale)
            row.num:SetWidth(scale and mfloor(18 * scale + 0.5) or 18)
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", container.list, "TOPLEFT", 0, -y + offset)
        row:SetPoint("RIGHT", container.list, "RIGHT", 0, 0)
        row.num:SetText(tostring(i) .. ".")
        local active = (route.active or 1) == i and not route.arrived
        local done = route.arrived or i < (route.active or 1)
        SetupCast(row.cast, step, active, not done)
        -- Room for the button in or out of view: FitPage places it again.
        local cast = not done and ns.GPSJumps and ns.GPSJumps.HasCast(step)
        row.learnID = step.kind == "learn" and not route.arrived and step.nodeID or nil
        if not row.learnID then row.drop:Hide() end
        row.text:SetWidth(mmax(40, listW - 12 - row.num:GetWidth() - ((cast or row.learnID) and 32 or 6)))
        row.text:SetText(StepText(step, active))
        local rowH = mmax(rowBase, (row.text:GetStringHeight() or 0) + 8)
        row:SetHeight(rowH)
        local ink = GPS.Ink(container)
        if active then
            row.text:SetTextColor(unpack(ink.primary))
            row.num:SetTextColor(unpack(ink.num))
        elseif done then
            row.text:SetTextColor(unpack(ink.dim))
            row.num:SetTextColor(unpack(ink.dim))
        else
            row.text:SetTextColor(unpack(ink.next))
            row.num:SetTextColor(unpack(ink.next))
        end
        row:Show()
        y = y + rowH
        if tips then PlaceTips(TipsAfter(tips, i, #route.steps)) end
    end
    for i = 1, first - 1 do rows[i]:Hide() end
    for i = (only or shown) + 1, #rows do rows[i]:Hide() end
    -- Arrived: the report line goes under the announcement.
    if route.arrived and container.empty:IsShown() then
        local eb, lt = container.empty:GetBottom(), container.list:GetTop()
        y = (eb and lt) and mmax(0, lt - eb + 4) or ((container.empty:GetStringHeight() or 12) + 8)
    end
    if tips then PlaceTips(TipsAfter(tips, nil, #route.steps)) end
    for t = nTips + 1, #(container.tips or {}) do container.tips[t]:Hide() end
    container.contentHeight = y
    container.list:SetHeight(mmax(1, y))
    -- Rows made this render carry the font's shadow until flattened.
    if ns.ShadeText then ns.ShadeText(container.list) end
    if container.OnRouteChanged then container:OnRouteChanged(true) end
end

-- With no route, a search box beside the glyph lists the map search's routable
-- results underneath; a click starts navigation. Nothing is focused on open.
local function PickHit(frame, data)
    -- A trip field's finds: that field takes the place.
    local ed = frame.trip
    if ed and frame.hitsFor == ed then
        ed:Pick(data)
        return
    end
    if ns.MapTab and ns.MapTab.PushRecentSearch then ns.MapTab:PushRecentSearch(frame.search:GetText()) end
    if GPS.picking == frame then
        GPS:SetStart(data)
        return
    end
    if GPS.along == frame then
        frame.search:SetText("")
        frame.search:ClearFocus()
        GPS:EndAlong()
        ns.GPSTrip.Insert(GPS.Destination(data))
        return
    end
    frame.search:SetText("")
    frame.search:ClearFocus()
    GPS:NavigateTo(data, { quiet = true })
end

-- Towns the map search lacks (Menethil Harbor, Auberdine), drawn as its subzones: a name
-- starting with the query above the map rows, one containing it below.
local towns
local mergedHits = {}
local listedNames = {}   -- the map search's names this keystroke, for the towns to skip

local function WithTowns(q, results)
    if not towns then
        towns = {}
        local data = ns.GPSData
        local binds = data and data.binds or {}
        for area, p in pairs(binds) do
            local name = C_Map.GetAreaInfo and C_Map.GetAreaInfo(area)
            local info = name and C_Map.GetMapInfo(p.m)
            if info then
                towns[#towns + 1] = { lower = name:lower(), row = { name = name, mapID = p.m, x = p.x, y = p.y,
                    zoneName = info.name, category = "subzone" } }
            end
        end
    end
    wipe(mergedHits)
    wipe(listedNames)
    for i = 1, results and #results or 0 do
        local name = results[i].name
        if name then listedNames[name] = true end
    end
    local lq = q:lower()
    for i = 1, #towns do
        local t = towns[i]
        if t.lower:find(lq, 1, true) == 1 and not listedNames[t.row.name] then mergedHits[#mergedHits + 1] = t.row end
    end
    for i = 1, results and #results or 0 do mergedHits[#mergedHits + 1] = results[i] end
    for i = 1, #towns do
        local t = towns[i]
        local at = t.lower:find(lq, 1, true)
        if at and at > 1 and not listedNames[t.row.name] then mergedHits[#mergedHits + 1] = t.row end
    end
    GPS.AddRideHits(lq, mergedHits)
    return mergedHits
end

-- Each boat, zeppelin, skyship and tram leg as a place at its boarding
-- spot, named as GPS names the ride and said where it leaves from.
function GPS.RideRows()
    if GPS.rideRows then return GPS.rideRows end
    local rows, data = {}, ns.GPSData
    local icons = ns.MapSearchData and ns.MapSearchData.CATEGORY_ICONS or {}
    local symbol = { boat = "boat", ferry = "boat", zeppelin = "zeppelin", skyship = "skyship", tram = "tram" }
    local word = { boat = L["GPS_AVOID_BOAT"], ferry = L["GPS_AVOID_BOAT"], zeppelin = L["GPS_AVOID_ZEPPELIN"],
                   skyship = L["GPS_AVOID_ZEPPELIN"], tram = L["GPS_LINE_TRAM"] }
    for _, r in ipairs(data and data.routes or {}) do
        local sym, f = symbol[r.kind], r.from
        if sym and r.n and f and f.m and f.x and f.y then
            local from = f.area and C_Map.GetAreaInfo and C_Map.GetAreaInfo(f.area)
            if not from then
                local info = C_Map.GetMapInfo(f.m)
                from = info and info.name
            end
            rows[#rows + 1] = {
                hay = (r.n .. " " .. (from or "") .. " " .. r.kind .. " " .. (word[r.kind] or "")):lower(),
                row = { name = r.n, mapID = f.m, x = f.x, y = f.y, category = sym, icon = icons[sym],
                        zoneName = from and L["GPS_RIDE_FROM_FMT"]:format(from) or nil },
            }
        end
    end
    GPS.rideRows = rows
    return rows
end

-- The rides whose name, kind or leaving place hold every word typed
-- ("zeppelin", "boat menethil", "zep undercity"), after the places.
function GPS.AddRideHits(lq, out)
    if #lq < 3 then return end
    for _, ride in ipairs(GPS.RideRows()) do
        local all = true
        for w in lq:gmatch("%S+") do
            if not ride.hay:find(w, 1, true) then all = false break end
        end
        if all then out[#out + 1] = ride.row end
    end
end

-- Places for a typed name, for the trip editor: the map search's, then towns.
-- The GPS searches keep the map tab's Show choices (EasyFind.db.mapTabFilters),
-- the buckets its cog offers, reachable from the window's and section's menus.
GPS.searchFrames = {}

function GPS.FilterHits(results)
    local Pass = ns.MapSearch and ns.MapSearch.PassesFilter
    local filters = EasyFind.db.mapTabFilters
    if not (Pass and filters and results) then return results end
    local out = {}
    for i = 1, #results do
        if Pass(results[i], filters) then out[#out + 1] = results[i] end
    end
    return out
end

-- A Show choice changed: every box with a query searches again.
function GPS.RefreshSearches()
    for i = 1, #GPS.searchFrames do
        local frame = GPS.searchFrames[i]
        if frame.RunSearch then frame.RunSearch() end
    end
end

-- The search bar's place rows for the query, so both list the same places.
function GPS.SearchPlaces(q)
    local MapSearch = ns.MapSearch
    if not (MapSearch and MapSearch.PlacesForQuery) then return WithTowns(q, nil) end
    return WithTowns(q, GPS.FilterHits(MapSearch:PlacesForQuery(q)))
end

-- The search list's two choices, each surface its own: the window's, the
-- section's (snapped in or floating), and beside the map the map tab's.
-- Parent zones start off in the window and the section: only the matches.
GPS.LIST_CHOICES = {
    recent = { map = "mapTabShowRecent", popout = "gpsPopoutShowRecent", dock = "gpsDockShowRecent",
        label = "MAP_SHOW_RECENT", tooltip = "GPS_SHOW_RECENT_TT" },
    parents = { map = "mapTabShowParents", popout = "gpsPopoutShowParents", dock = "gpsDockShowParents",
        label = "MAP_SHOW_PARENTS", tooltip = "MAP_SHOW_PARENTS_TT", offInGPS = true },
    expand = { map = "mapTabAutoExpand", popout = "gpsPopoutAutoExpand", dock = "gpsDockAutoExpand",
        label = "MAP_AUTO_EXPAND", tooltip = "MAP_AUTO_EXPAND_TT" },
}

function GPS.ListChoiceKey(frame, which)
    return GPS.LIST_CHOICES[which][(frame.mapFont and "map") or (frame.isPopout and "popout") or "dock"]
end

function GPS.ListChoice(frame, which)
    local db = DB()
    local on = db and db[GPS.ListChoiceKey(frame, which)]
    if on == nil then return not (GPS.LIST_CHOICES[which].offInGPS and not frame.mapFont) end
    return on
end

function GPS.ListChoiceRow(frame, which)
    local choice = GPS.LIST_CHOICES[which]
    return { kind = "check", label = L[choice.label], tooltip = L[choice.tooltip],
        get = function() return GPS.ListChoice(frame, which) end,
        set = function(v)
            local db = DB()
            if db then db[GPS.ListChoiceKey(frame, which)] = v and true or false end
            if frame.RefreshHits then frame:RefreshHits() end
        end }
end

-- The search box's right end at (rel, point, x), room left for its gear.
function GPS.SearchRight(f, rel, point, x)
    f.search:SetPoint("RIGHT", rel, point, x - ((f.searchCog and f.searchCog:IsShown()) and 21 or 0), 0)
end

-- How the pop-outs wear their settings cog: "hover" (the default: while
-- the cursor is on the window), "show" or "hide"; the old off switch hides.
function GPS.CogMode()
    local db = DB()
    local v = db and db.gpsCog
    if v == false or v == "hide" then return "hide" end
    return v == "show" and "show" or "hover"
end

function GPS.CogsShown() return GPS.CogMode() ~= "hide" end

-- On hover the cog keeps its place, seen only while the cursor is on win.
function GPS.CogHover(cog, win)
    if GPS.CogMode() ~= "hover" then
        Utils.SafeOnUpdate(cog, nil)
        cog:SetAlpha(1)
        return
    end
    cog:SetAlpha(win:IsMouseOver() and 1 or 0)
    local wait = 0
    Utils.SafeOnUpdate(cog, function(self, dt)
        wait = wait - dt
        if wait > 0 then return end
        wait = 0.1
        self:SetAlpha(win:IsMouseOver() and 1 or 0)
    end)
end

-- A settings cog opening menu(): a surface's whole menu, as its right-click.
function GPS.SettingsCog(parent, menu)
    local MapTab = ns.MapTab
    local cog = MapTab and MapTab.CreateFilterCog and MapTab.CreateFilterCog(parent)
    if not cog then return nil end
    cog:SetSize(15, 16)
    cog:SetScript("OnClick", function() menu() end)
    return cog
end

-- The setting changed: each pop-out's cogs shown or not, its box fitted.
function GPS.ApplyCogs()
    local on = GPS.CogsShown()
    for _, frame in ipairs(GPS.searchFrames) do
        if frame.searchCog and frame.ShowMenu then
            frame.searchCog:SetShown(on)
            GPS.CogHover(frame.searchCog, frame)
            GPS.SearchRight(frame, frame, "RIGHT", -frame.searchPad)
        end
        if frame.headCog then GPS.CogHover(frame.headCog, frame) end
    end
    Refresh()
end

local function BuildSearch(frame, glyph, padRight, bodyPad)
    -- The tracking face's art spills 6 px past its frame: more room after it.
    local boxGap = frame.track and 16 or 12
    local box = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    box:SetHeight(20)
    box:SetPoint("LEFT", glyph, "RIGHT", boxGap, 0)
    -- The map tab's gear after the box (shown and hidden with it): its Show
    -- choices, then this box's own.
    local MapTab = ns.MapTab
    local cog = MapTab and MapTab.CreateFilterCog and MapTab.ShowDefs and MapTab.CreateFilterCog(box)
    if cog then
        frame.searchCog, frame.searchPad = cog, padRight
        cog:SetSize(15, 16)
        cog:SetPoint("LEFT", box, "RIGHT", 6, 0)
        -- A pop-out's cog: its whole menu, and the setting may leave it out.
        local shown = not frame.ShowMenu or GPS.CogsShown()
        cog:SetShown(shown)
        if frame.ShowMenu then GPS.CogHover(cog, frame) end
        box:SetPoint("RIGHT", frame, "RIGHT", -(padRight + (shown and 21 or 0)), 0)
        cog:SetScript("OnClick", function()
            if frame.ShowMenu then return frame.ShowMenu() end
            local defs = MapTab.ShowDefs()
            defs[#defs + 1] = { kind = "separator" }
            for _, which in ipairs({ "recent", "parents", "expand" }) do defs[#defs + 1] = GPS.ListChoiceRow(frame, which) end
            ns.ShowTogglePopup("EasyFindGPSSearchOptions", cog, defs, {})
        end)
    else
        box:SetPoint("RIGHT", frame, "RIGHT", -padRight, 0)
    end
    box:SetAutoFocus(false)
    box:SetMaxLetters(60)
    Utils.ReleaseFocusOnOutsideClick(box)
    if box.Instructions then
        box.Instructions:SetText(L["GPS_SEARCH_PLACEHOLDER"] or SEARCH or "Search")
        box.Instructions:SetWordWrap(false)   -- cut with an ellipsis when the box is narrow
        -- Faint, as the main search bar's placeholder is: the theme's faint
        -- text where a theme is active, the dim text otherwise; beside the
        -- map, the client's own.
        if not frame.gameLook then
            local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
            local c = (theme and theme.textFaint) or ns.TEXT_DIM
            box.Instructions:SetTextColor(c[1], c[2], c[3], 1)
            box.Instructions._efOwnColor = true
        end
    end
    -- On a light theme the hint, the words, the glass and the X are one
    -- blue, as in the trip's fields; again after the client's own focus
    -- scripts, which tint the glass.
    if not frame.gameLook then
        local function PaintBox(ink)
            ink = ink or GPS.Ink(frame)
            if not ink.light then return end
            local c = ink.field
            box:SetTextColor(c[1], c[2], c[3], 1)
            if box.Instructions then box.Instructions:SetTextColor(c[1], c[2], c[3], 1) end
            if box.searchIcon then box.searchIcon:SetVertexColor(c[1], c[2], c[3]) end
            if box.clearButton and box.clearButton.texture then box.clearButton.texture:SetVertexColor(c[1], c[2], c[3]) end
        end
        GPS.Inked(frame, PaintBox)
        box:HookScript("OnEditFocusGained", function() PaintBox() end)
        box:HookScript("OnEditFocusLost", function() PaintBox() end)
    end
    -- The client focuses a fresh visible EditBox on its own; refuse that.
    box._blockAutoFocus = true
    box:HookScript("OnEditFocusGained", function(self) if self._blockAutoFocus then self:ClearFocus() end end)
    box:HookScript("OnMouseDown", function(self) self._blockAutoFocus = nil end)
    Utils.SafeAfter(0, function() Utils.SafeAfter(0, function() box._blockAutoFocus = nil; box:ClearFocus() end) end)
    box:HookScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        -- Escape leaves a start being picked; with no route, drops a start set.
        if GPS.picking == frame then GPS:EndPick() elseif Start() and not Route() then GPS:SetStart(nil) end
        if GPS.along == frame then GPS:EndAlong() end
    end)
    -- Beside the map, Ctrl+plus, minus or 0 sets the text size, as Ctrl+wheel does.
    box:HookScript("OnKeyDown", function(_, key)
        if not (frame.mapFont and IsControlKeyDown() and ns.MapTab and ns.MapTab.StepFontSize) then return end
        if key == "=" or key == "EQUALS" or key == "PLUS" or key == "NUMPADPLUS" then ns.MapTab.StepFontSize(1)
        elseif key == "-" or key == "MINUS" or key == "NUMPADMINUS" then ns.MapTab.StepFontSize(-1)
        elseif key == "0" or key == "NUMPAD0" then ns.MapTab.StepFontSize(0) end
    end)
    -- Left empty for elsewhere: a click on its own list (a recent search)
    -- takes the focus first, and the pick or search along stays on for it.
    function frame.LeftEmpty(self)
        local list = frame.hitList
        return (self:GetText() or "") == "" and not (list and list:IsShown() and list:IsMouseOver())
    end
    box:HookScript("OnEditFocusLost", function(self)
        if GPS.picking == frame and frame.LeftEmpty(self) then GPS:EndPick() end
        if GPS.along == frame and frame.LeftEmpty(self) then GPS:EndAlong() end
    end)
    if box.clearButton then
        box.clearButton:HookScript("OnClick", function() if GPS.along == frame then GPS:EndAlong() end end)
    end
    -- The box covers most of a folded window: dragging it moves the window.
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", function() if frame.BeginWindowDrag then frame:BeginWindowDrag() end end)
    box:SetScript("OnDragStop", function() if frame.EndWindowDrag then frame:EndWindowDrag() end end)
    frame.search = box

    -- The hits scroll inside whatever height the window gives them, as the
    -- search results do: a scroll frame, the rows on its child, the thin bar.
    local hitList = CreateFrame("ScrollFrame", nil, frame)
    hitList:SetPoint("TOPLEFT", glyph, "BOTTOMLEFT", -6, -8)
    hitList:SetPoint("RIGHT", frame, "RIGHT", -(bodyPad - 4), 0)
    hitList:SetHeight(1)
    local hitChild = CreateFrame("Frame", nil, hitList)
    hitChild:SetSize(1, 1)
    hitList:SetScrollChild(hitChild)
    -- The rows stop short of the thin bar while it shows.
    -- Snapped in, the 3 px bar clears the fold buttons, and the banners end
    -- where the section's header does.
    local function FitHitChild()
        local room = frame.isPopout and frame.hitBar and frame.hitBar:IsShown()
            and (ns.SCROLLBAR_THUMB_W + ns.SCROLLBAR_EDGE_INSET + 4) or 0
        hitChild:SetWidth(mmax(1, (hitList:GetWidth() or 0) - room))
    end
    hitList:SetScript("OnSizeChanged", FitHitChild)
    frame.hitList, frame.hitChild = hitList, hitChild
    frame.hitBar = Utils.CreateMinimalScrollBar(hitList, hitList)
    -- The map search's own list: its groups, its rows, its first page.
    frame.places = ns.PlaceList.New(hitChild, {
        click = function(row, button)
            if row.data.isRecentSearch then
                local ed = frame.hitsFor
                local field = ed and ed.editing and ed.editing.box
                if field then
                    field:SetFocus()
                    field:SetText(row.data.query)
                    ed:Typed(ed.editing, row.data.query)
                else
                    box:SetText(row.data.query)
                end
            elseif button ~= "RightButton" then
                PickHit(frame, row.data)
            end
        end,
        headerClick = function(data) if GPS:CanNavigate(data) then PickHit(frame, data) end end,
        refresh = function() frame:DrawHits() end,
        searchBox = function() return frame.search end,
        fontScale = function() return MapScale(frame) or 1 end,
        autoExpand = function() return GPS.ListChoice(frame, "expand") end,
        headerSkin = function() return GPS.HitSkin(frame) end,
        deleteRecent = function(query)
            if ns.MapTab and ns.MapTab.ForgetRecentSearch then ns.MapTab:ForgetRecentSearch(query) end
            frame:RefreshHits()
        end,
        -- A hovered place shown on the map, while the map is open.
        preview = function(data)
            local MapSearch = ns.MapSearch
            if WorldMapFrame and WorldMapFrame:IsShown() and MapSearch and MapSearch.RunHoverPreview then
                MapSearch:RunHoverPreview(data)
            end
        end,
        endPreview = function()
            local MapSearch = ns.MapSearch
            if WorldMapFrame and WorldMapFrame:IsShown() and MapSearch and MapSearch.EndHoverPreview then
                MapSearch:EndHoverPreview()
            end
        end,
        -- In the window, rows wear the theme's text and highlight.
        decorate = function(row)
            ns.GPSTrip.Note(row)
            if frame.isPopout then Utils.InstallMenuRowHighlight(row) end
        end,
        fill = function(row, data)
            local secs = frame.hitSecs
            row.note:SetText(data and secs and secs[data] and ns.GPSTrip.AddsText(secs[data]) or "")
            row.note:SetTextColor(unpack(GPS.Ink(frame).dim))
            local theme = frame.isPopout and data and not data.isRecentSearch
                and ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
            if theme then row.text:SetTextColor(unpack(theme.leafColor)) end
        end,
        pad = 0,
    })

    -- The hits' visible height: at most what they need, the rest scrolls.
    function frame:SetHitView(h)
        local content = self.hitHeight or 0
        h = math.min(h, content)
        hitList:SetHeight(mmax(1, h))
        local scrolls = content > h + 0.5
        self.hitBar:SetShown(scrolls)
        if scrolls then self.hitBar:UpdateThumb(content, h) end
        FitHitChild()
    end

    -- The last searches, while the box is focused and empty (this
    -- surface's choice); false when they do not show.
    -- ed: a trip field's editor (the window's fields), the list then its.
    function frame:ShowRecent(ed)
        local db = DB()
        local saved = db and db.mapTabRecentSearches
        local field = ed and ed.editing and ed.editing.box or box
        if not (field:HasFocus() and (field:GetText() or "") == "" and (ed or not self.hitsFor) and GPS.along ~= self
            and GPS.ListChoice(self, "recent") and saved and #saved > 0) then
            return false
        end
        local limit = ns.MapTab and ns.MapTab.GetRecentLimit and ns.MapTab.GetRecentLimit() or 3
        local recent = {}
        for i = 1, math.min(#saved, limit) do recent[i] = saved[i] end
        self.hitsFor = ed
        self.hitSecs = nil
        self.hitArgs = { query = "", recent = recent }
        hitList:SetVerticalScroll(0)
        self:DrawHits()
        return true
    end

    -- The list again after a choice changed: the query's places, or the
    -- last searches, or nothing.
    function frame:RefreshHits()
        local ed = self.hitsFor
        if ed then
            local field = ed.editing and ed.editing.box
            if field and (field:GetText() or "") == "" and not self:ShowRecent(ed) then ed:ShowHits(nil) end
            return
        end
        if (box:GetText() or "") ~= "" then
            self.RunSearch()
        elseif not self:ShowRecent() then
            self:ShowHits(nil)
        end
    end

    -- The hits' height on a window that grows with them.
    function frame:HitViewH()
        return math.min(self.hitHeight or 0, HIT_ROWS * ROW_H)
    end

    -- nil puts the list away. secs, along the way: by place, the seconds
    -- a stop there adds, those places kept in that order. A new query
    -- opens the groups again at the first page.
    function frame:ShowHits(results, secs, query)
        self.hitSecs = secs
        self.hitArgs = nil
        if results then
            local routable = {}
            for i = 1, #results do
                if GPS:CanNavigate(results[i]) then routable[#routable + 1] = results[i] end
            end
            -- Searched and nothing found: says so in the list's place, never
            -- the route's steps back under a search.
            -- Along the way the places keep their order; else under their
            -- zones, or (this surface's choice) only the matches.
            local entries
            if not secs and GPS.ListChoice(self, "parents") then
                entries = ns.PlaceList.WorldEntries(routable)
            else
                entries = ns.PlaceList.FlatEntries(routable)
            end
            self.hitArgs = { query = query or {}, globalEntries = entries, emptyText = L["MAP_NO_MATCHES"] }
        end
        hitList:SetVerticalScroll(0)
        self:DrawHits()
    end

    function frame:DrawHits()
        local list = self.places
        if self.hitArgs then
            list:Render(self.hitArgs)
        else
            list:Clear()
            hitChild:SetHeight(1)
        end
        local n = self.hitArgs and list.lines or 0
        self.hitHeight = n > 0 and list.height or 0
        local had = (self.hitCount or 0) > 0
        self.hitCount = n
        self:SetHitView(HIT_ROWS * ROW_H)
        -- Hits over the steps, or the steps back: drawn again, so what
        -- belongs to the steps alone (the danger line) goes and returns with them.
        if (n > 0) ~= had and self.Render then
            self:Render()
        elseif self.OnRouteChanged then
            self:OnRouteChanged(Route() ~= nil and GPS.picking ~= self)
        end
    end

    local pending
    frame.RunSearch = function()
        local MapSearch = ns.MapSearch
        local q = box:GetText() or ""
        if q == "" or not (MapSearch and MapSearch.BuildResults) then return end
        if GPS.along == frame then
            local results, secs = ns.GPSTrip.AlongPlaces(q)
            frame:ShowHits(results, secs, q)
            return
        end
        local ok, results = pcall(MapSearch.BuildResults, MapSearch, q, true, true)
        frame:ShowHits(WithTowns(q, GPS.FilterHits(ok and results or nil)), nil, q)
    end
    GPS.searchFrames[#GPS.searchFrames + 1] = frame
    box:HookScript("OnEditFocusGained", function(self)
        if self:HasFocus() and (self:GetText() or "") == "" then frame:ShowRecent() end
    end)
    -- Put away a moment later: a press on one of them takes the focus
    -- first, and its click still lands.
    box:HookScript("OnEditFocusLost", function()
        Utils.SafeAfter(0.2, function()
            if box:HasFocus() or (box:GetText() or "") ~= "" then return end
            if frame.hitArgs and frame.hitArgs.recent then frame:ShowHits(nil) end
        end)
    end)
    box:HookScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if text == "" then
            if not frame:ShowRecent() then frame:ShowHits(nil) end
            return
        end
        if pending then return end
        pending = true
        Utils.SafeAfter(0.15, function()
            pending = nil
            frame.RunSearch()
        end)
    end)
end

-- Title, buttons, empty hint and step list laid into any frame; it gains Render().
-- opts: padX, padY, padRight, popoutButton, search, onRouteChanged.
local POI_NORMAL, POI_NORMAL_ON = "UI-QuestPoi-QuestNumber", "UI-QuestPoi-QuestNumber-SuperTracked"
local POI_PUSHED, POI_PUSHED_ON = "UI-QuestPoi-QuestNumber-Pressed", "UI-QuestPoi-QuestNumber-Pressed-SuperTracked"
local POI_HIGHLIGHT, POI_GLOW = "UI-QuestPoi-InnerGlow", "UI-QuestPoi-OuterGlow"
-- The game's art this client has: Classic Era and Anniversary lack 11.0's
-- POI and tracker atlases and the quest log's border template, and get
-- what their own quest map and watch frame draw (the POI faces cut from
-- the number sheet at QuestDataProvider's coords).
local GAME_ART = {
    poi = GetAtlasInfo(POI_NORMAL) ~= nil,
    tracker = GetAtlasInfo("UI-QuestTracker-Secondary-Objective-Header") ~= nil,
    questRim = C_XMLUtil.GetTemplateInfo("QuestLogBorderFrameTemplate") ~= nil and ns.Caps.questLogAtlas ~= false,
    poiSheet = "Interface\\WorldMap\\UI-QuestPoi-NumberIcons",
    poiGlow = "Interface\\WorldMap\\UI-QuestPoi-IconGlow",
    poiCut = {
        off = { 0.875, 1, 0.375, 0.5 }, offDown = { 0.75, 0.875, 0.375, 0.5 },
        on = { 0.5, 0.625, 0.375, 0.5 }, onDown = { 0.375, 0.5, 0.375, 0.5 },
        hover = { 0.625, 0.75, 0.875, 1 },
    },
}
local PIN_ON_FACE_OFF = ns.GOLD_COLOR         -- the window glyph's gold on the dark face
local PIN_ON_FACE_ON  = { 0.25, 0.13, 0.03 }  -- dark pin on the gold face

RouteTracked = function()
    local route = Route()
    return route ~= nil and not route.untracked
end

-- The arrow and the beacon follow the route, or let go of it for the
-- tracker's quests.
-- The route lets go of the game's super-track, the arrow and beacon free
-- for a quest. The map search must stop treating the pin as its own, or
-- it re-tracks it the moment nothing else is tracked.
function GPS.ReleaseTracking(route)
    route.untracked = true
    if ns.MapSearch and ns.MapSearch.SetEasyFindWaypointPlaced then ns.MapSearch:SetEasyFindWaypointPlaced(false) end
    GPS.TrackGamePin(false)
end

-- The route takes the super-track: a quest's goes, so the tracker never
-- lights a quest beside the route.
function GPS.ClearQuestSuperTrack()
    local ST = C_SuperTrack
    if ST and ST.IsSuperTrackingQuest and ST.IsSuperTrackingQuest() and ST.SetSuperTrackedQuestID then
        GPS.GamePinChange("quest", function() ST.SetSuperTrackedQuestID(0) end)
    end
end

local function ToggleRouteTracking()
    local route = Route()
    if not route then return end
    if RouteTracked() then
        GPS.ReleaseTracking(route)
    else
        route.untracked = nil
        GPS.ClearQuestSuperTrack()
        if C_SuperTrack and C_SuperTrack.GetSuperTrackedVignette and C_SuperTrack.GetSuperTrackedVignette()
            and C_SuperTrack.ClearAllSuperTrackedVignettes then
            GPS.GamePinChange("vignette", C_SuperTrack.ClearAllSuperTrackedVignettes)
        end
        TrackStep(route.active or 1)
    end
    Refresh()
end

-- A quest super-tracked while the route is: the player's pick comes with
-- a click on a frame (its POI, the quest map, a tracker) in that frame,
-- and the route lets go, as its own toggle does, so one is lit. One with
-- no click is an addon's or the game's (a guide tracking its step's
-- quest, 2026-11-19): the route takes the super-track back.
do
    local watch = CreateFrame("Frame")
    local clickAt
    Utils.RegisterEventIfValid(watch, "SUPER_TRACKING_CHANGED")
    Utils.RegisterEventIfValid(watch, "GLOBAL_MOUSE_DOWN")
    Utils.RegisterEventIfValid(watch, "GLOBAL_MOUSE_UP")
    watch:SetScript("OnEvent", function(_, event)
        local at = GetTime()
        if event ~= "SUPER_TRACKING_CHANGED" then
            local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
            if foci[1] and foci[1] ~= WorldFrame then clickAt = at end
            return
        end
        Utils.SafeAfter(0, function()
            local route = Route()
            local ST = C_SuperTrack
            if not (route and RouteTracked() and not route.arrived and ST and ST.IsSuperTrackingQuest
                and ST.IsSuperTrackingQuest()) then
                return
            end
            -- The route's own last step tracking its quest: no pick of the player's.
            if route.questTracked and ST.GetSuperTrackedQuestID and ST.GetSuperTrackedQuestID() == route.questTracked then
                return
            end
            if clickAt ~= at then
                TrackStep(route.active or 1)
                return
            end
            GPS.ReleaseTracking(route)
            Refresh()
        end)
    end)
end

-- The toggle's faces: the game's POI atlases, or the classic sheet's cuts.
local function PoiFaces(track, on)
    if GAME_ART.poi then
        track:SetNormalAtlas(on and POI_NORMAL_ON or POI_NORMAL)
        track:SetPushedAtlas(on and POI_PUSHED_ON or POI_PUSHED)
        return
    end
    track:SetNormalTexture(GAME_ART.poiSheet)
    track:SetPushedTexture(GAME_ART.poiSheet)
    track:GetNormalTexture():SetTexCoord(unpack(on and GAME_ART.poiCut.on or GAME_ART.poiCut.off))
    track:GetPushedTexture():SetTexCoord(unpack(on and GAME_ART.poiCut.onDown or GAME_ART.poiCut.offDown))
end

-- The toggle as the game's POI button: 32-pixel faces on a 20-pixel button, hover and
-- on glows at the atlas's own size (smaller reads dimmer), our pin in the middle. Hidden until placed.
local function BuildTrackButton(parent)
    local track = CreateFrame("Button", nil, parent)
    track:SetSize(20, 20)
    PoiFaces(track, false)
    if GAME_ART.poi then
        track:SetHighlightAtlas(POI_HIGHLIGHT, "ADD")
    else
        track:SetHighlightTexture(GAME_ART.poiSheet, "ADD")
        track:GetHighlightTexture():SetTexCoord(unpack(GAME_ART.poiCut.hover))
    end
    for _, tex in ipairs({ track:GetNormalTexture(), track:GetPushedTexture(), track:GetHighlightTexture() }) do
        if tex then
            tex:ClearAllPoints()
            tex:SetSize(32, 32)
            tex:SetPoint("CENTER")
        end
    end
    local glow = track:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("CENTER")
    if GAME_ART.poi then
        glow:SetAtlas(POI_GLOW, true)
    else
        glow:SetTexture(GAME_ART.poiGlow)
        glow:SetSize(48, 48)
    end
    glow:SetBlendMode("ADD")
    glow:Hide()
    track.glow = glow
    local pin = track:CreateTexture(nil, "ARTWORK", nil, 1)
    pin:SetSize(11, 15)
    pin:SetPoint("CENTER", track, "CENTER", 0, 0)
    pin:SetTexture(GPS.ICON_TEX)
    pin:SetVertexColor(PIN_ON_FACE_OFF[1], PIN_ON_FACE_OFF[2], PIN_ON_FACE_OFF[3], 1)
    track.pin = pin
    track:SetScript("OnClick", ToggleRouteTracking)
    Utils.AttachDelayedTooltip(track, "ANCHOR_RIGHT", function()
        return RouteTracked() and L["GPS_TRACK_OFF"] or L["GPS_TRACK_ON"]
    end)
    track:Hide()
    return track
end

-- The faces for on (the arrow follows the route) or off.
StyleTrackButton = function(track, on)
    PoiFaces(track, on)
    local col = on and PIN_ON_FACE_ON or PIN_ON_FACE_OFF
    track.pin:SetVertexColor(col[1], col[2], col[3], 1)
    track.glow:SetShown(on)
end

local function BuildSurface(frame, opts)
    frame.rows = {}
    local padX, padY, padRight = opts.padX or 8, opts.padY or 8, opts.padRight or 8
    frame.padRight = padRight   -- the trip editor keeps its first row clear of the header's buttons
    -- The header's right padding clears its buttons; the body below only
    -- clears the edge.
    local bodyPad = opts.bodyPadRight or padRight

    -- On a child frame above the panel's gloss; its gold is re-applied every
    -- render in case a theme pass touches it.
    local head, glyph
    if opts.trackGlyph then
        -- The window's icon is the tracking toggle the section has, so it
        -- reads the same way: lit while the arrow follows the route.
        head = CreateFrame("Frame", nil, frame)
        head:SetFrameLevel(frame:GetFrameLevel() + 10)
        head:SetSize(20, 20)
        -- The face's art spills past its 20 px: it sits 4 px further out,
        -- clear of the box beside it (SetHeaderPad places it the same way).
        head:SetPoint("TOPLEFT", frame, "TOPLEFT", padX - 4, -(padY - 2))
        local track = BuildTrackButton(frame)
        track:SetFrameLevel(frame:GetFrameLevel() + 10)
        track:SetPoint("TOPLEFT", head, "TOPLEFT", 0, 0)
        track:Show()
        glyph = head
        frame.glyph = head
        frame.track = track
        Utils.RegisterEventIfValid(frame, "SUPER_TRACKING_CHANGED")
        frame:HookScript("OnEvent", function(self, event) if event == "SUPER_TRACKING_CHANGED" and self:IsShown() then self:Render() end end)
    else
        head = CreateFrame("Frame", nil, frame)
        head:SetFrameLevel(frame:GetFrameLevel() + 10)
        head:SetSize(16, 16)
        head:SetPoint("TOPLEFT", frame, "TOPLEFT", padX, -padY)
        glyph = head:CreateTexture(nil, "OVERLAY", nil, 7)
        glyph:SetTexture(GPS.ICON_TEX)
        glyph:SetAllPoints(head)
        glyph:SetVertexColor(unpack(ns.ChromeGlyphColor()))
        glyph._efOwnColor = true
        frame.glyph = head
        frame.glyphTex = glyph
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", glyph, "RIGHT", 6, 0)
    title:SetPoint("RIGHT", frame, "RIGHT", -padRight, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    GPS.Inked(frame, function(ink) title:SetTextColor(unpack(ink.primary)) end)
    title._efOwnColor = true
    frame.title = title
    if not opts.titleOpensMap then
        -- A click on the destination line holds the whole route on the
        -- map, as a click on a step holds that step; right-click is the menu.
        local over = CreateFrame("Button", nil, frame)
        over:SetAllPoints(title)
        over:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        over:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                if frame.ShowMenu then frame.ShowMenu() end
            elseif frame.previewOnHover and ns.GPSPreview then
                ns.GPSPreview:Show(0)
            end
        end)
    end
    if opts.titleOpensMap then
        -- The destination line opens the map's GPS page, as a quest in
        -- the tracker opens its log entry; the steps keep their own click.
        local btn = CreateFrame("Button", nil, frame)
        btn:SetAllPoints(title)
        btn:SetScript("OnEnter", function() title:SetTextColor(unpack(GPS.Ink(frame).num)) end)
        btn:SetScript("OnLeave", function() title:SetTextColor(unpack(GPS.Ink(frame).primary)) end)
        btn:SetScript("OnClick", function() GPS:Open() end)
        btn:Hide()
        frame.titleBtn = btn
    end

    -- The time estimate on its own line under the name.
    local eta = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    eta:SetPoint("TOPLEFT", glyph, "BOTTOMLEFT", 16 + 6, -4)   -- under the name, not the glyph
    eta:SetJustifyH("LEFT")
    eta:SetWordWrap(false)
    GPS.Inked(frame, function(ink) eta:SetTextColor(unpack(ink.dim)) end)
    eta._efOwnColor = true
    frame.eta = eta

    -- The time is still being tuned: a (WIP) after it says so on hover.
    local tag = CreateFrame("Button", nil, frame)
    local tagText = tag:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tagText:SetPoint("LEFT")
    tagText:SetText(L["GPS_ETA_WIP"])
    GPS.Inked(frame, function(ink) tagText:SetTextColor(unpack(ink.dim)) end)
    tagText._efOwnColor = true
    tag:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["GPS_ETA_WIP_TT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tag:SetScript("OnLeave", GameTooltip_Hide)
    tag:Hide()
    frame.etaTag, frame.etaTagText = tag, tagText
    frame.PlaceEtaTag = function(self, shown)
        local w, h = tagText:GetStringWidth() or 0, tagText:GetStringHeight() or 0
        tag:SetSize(mmax(1, w), mmax(1, h))
        -- Right after the time's words: the line itself spans to the Clear link.
        tag:ClearAllPoints()
        tag:SetPoint("LEFT", eta, "LEFT", (eta:GetStringWidth() or 0) + 4, 0)
        tag:SetShown(shown and self.eta:IsShown())
    end

    -- Clear route as a small text link at the right end of the time line:
    -- always in view, never a button competing with the steps.
    do
        local link = CreateFrame("Button", nil, frame)
        link:SetHeight(14)
        local text = link:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("RIGHT", link, "RIGHT", 0, 0)
        text:SetText(L["GPS_CLEAR"])
        GPS.Inked(frame, function(ink) text:SetTextColor(unpack(ink.dim)) end)
        text._efOwnColor = true
        link.text = text
        link:SetWidth((text:GetStringWidth() or 60) + 4)
        -- On the time line's row, anchored to the frame (the line then
        -- ends at the link; anchoring the two to each other would loop).
        link:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -(padY + 16 + 4))
        link:SetScript("OnEnter", function() text:SetTextColor(unpack(GPS.Ink(frame).hover)) end)
        link:SetScript("OnLeave", function() text:SetTextColor(unpack(GPS.Ink(frame).dim)) end)
        link:SetScript("OnClick", function() GPS:Clear() end)
        eta:SetPoint("RIGHT", link, "LEFT", -8, 0)
        frame.clearBtn = link
    end

    if opts.popoutButton then
        -- The pop-out icon, a box with an arrow leaving its corner, at the
        -- header's right in the close button's stroke style.
        local btn = CreateFrame("Button", nil, frame)
        btn:SetSize(18, 18)
        btn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -padRight, -(padY - 1))
        local strokes = {}
        local function stroke(w, h, x, y, rot)
            local tex = btn:CreateTexture(nil, "OVERLAY")
            tex:SetTexture("Interface\\Buttons\\WHITE8x8")
            tex:SetSize(w, h)
            tex:SetPoint("CENTER", btn, "CENTER", x, y)
            if rot then tex:SetRotation(rot) end
            strokes[#strokes + 1] = tex
        end
        -- Pixel-aligned: even stroke widths on whole-pixel centers, the
        -- shaft overlapping the head so the corner reads as one line.
        stroke(2, 11, -6, -1.5)          -- box: left
        stroke(11, 2, -1.5, -6)          -- box: bottom
        stroke(6, 2, -4, 3)              -- box: top, left part
        stroke(2, 6, 3, -4)              -- box: right, bottom part
        stroke(2, 12, 3, 3, -mpi / 4)    -- arrow shaft, from the box out to the tip
        stroke(7, 2, 3.5, 7)             -- arrowhead: the tip's corner
        stroke(2, 7, 7, 3.5)
        local function tint(r, g, b)
            for i = 1, #strokes do strokes[i]:SetVertexColor(r, g, b, 1) end
        end
        tint(unpack(ns.TEXT_DIM))
        btn:SetScript("OnEnter", function() tint(1, 1, 1) end)
        btn:SetScript("OnLeave", function() tint(unpack(ns.TEXT_DIM)) end)
        btn:SetScript("OnClick", function()
            GPS:OpenWindow()
            -- Popping out is leaving the map for the small window.
            if WorldMapFrame and WorldMapFrame:IsShown() and HideUIPanel then HideUIPanel(WorldMapFrame) end
        end)
        title:SetPoint("RIGHT", btn, "LEFT", -6, 0)
        Utils.AttachDelayedTooltip(btn, "ANCHOR_TOP", function() return L["GPS_POPOUT"], L["GPS_POPOUT_TT"] end)
        frame.popoutBtn = btn
    end

    if opts.search then
        BuildSearch(frame, glyph, padRight, bodyPad)
        -- With a route the box moves to the time line, after the time and
        -- before the Clear link, and the places it finds take the steps' place.
        -- The places' banners clear the window's left edge as its right.
        local hitX = 8
        frame.PlaceSearch = function(self, hasRoute)
            local box, hits = self.search, self.hitList
            box:ClearAllPoints()
            hits:ClearAllPoints()
            if hasRoute then
                -- After the time's words, and its (WIP) tag when that shows.
                if self.etaTag:IsShown() then
                    box:SetPoint("LEFT", self.etaTag, "RIGHT", 10, 0)
                else
                    box:SetPoint("LEFT", self.eta, "LEFT", (self.eta:GetStringWidth() or 0) + 10, 0)
                end
                box:SetPoint("RIGHT", self.clearBtn, "LEFT", -8, 0)
                hits:SetPoint("TOPLEFT", self.list, "TOPLEFT", hitX, 0)
                hits:SetPoint("RIGHT", self.list, "RIGHT", 0, 0)
            else
                box:SetPoint("LEFT", glyph, "RIGHT", self.track and 16 or 12, 0)
                box:SetPoint("RIGHT", self, "RIGHT", -padRight, 0)
                -- Under the trip's fields where they show, as the steps start.
                if self.trip then
                    hits:SetPoint("TOPLEFT", self.trip, "BOTTOMLEFT", (self.trip.listX or -6) + hitX, -8)
                else
                    hits:SetPoint("TOPLEFT", glyph, "BOTTOMLEFT", -6 + hitX, -8)
                end
                hits:SetPoint("RIGHT", self, "RIGHT", -(bodyPad - 4), 0)
            end
        end
    end

    local empty = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    empty:SetPoint("TOPLEFT", glyph, "BOTTOMLEFT", 0, -10)
    empty:SetPoint("RIGHT", frame, "RIGHT", -bodyPad, 0)
    empty:SetJustifyH("LEFT")
    empty:SetWordWrap(true)
    empty:SetText(L["GPS_EMPTY"])
    GPS.Inked(frame, function(ink) empty:SetTextColor(unpack(ink.dim)) end)
    empty._efOwnColor = true
    frame.empty = empty
    -- With a search box the hint has no text at all: the box says what to do.
    if opts.search then
        empty:SetText("")
        empty:Hide()
    end

    -- The list hangs from the glyph's frame: rows carry secure buttons, and a secure frame
    -- cannot be positioned through a FontString or Texture. The time line gets a fixed height.
    local etaH = math.ceil((eta.GetLineHeight and eta:GetLineHeight()) or 12)
    eta:SetHeight(etaH)
    frame.listGap = opts.listGap or 8   -- the room between the time line and the first step
    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", -6, -(4 + etaH + frame.listGap))
    list:SetPoint("RIGHT", frame, "RIGHT", -(bodyPad - 4), 0)
    list:SetHeight(1)
    frame.list = list

    frame.OnRouteChanged = function(self, hasRoute)
        self.clearBtn:SetShown(hasRoute and not self.noClear)
        self.eta:SetShown(hasRoute)
        if not hasRoute then self.etaTag:Hide() end
        if self.titleBtn then self.titleBtn:SetShown(hasRoute) end
        -- With the trip's fields the track toggle sits on the time line.
        if self.track and self.trip then self.track:SetShown(hasRoute) end
        if self.search then
            -- While a way is found the title says so in the box's place.
            -- With the trip editor up, its fields do the searching.
            local searching = not GPS.planning and not self.trip
            self.search:SetShown(searching)
            local typed = (self.hitCount or 0) > 0
            self.hitList:SetShown((searching and (not hasRoute or typed)) or (self.hitsFor ~= nil and typed))
            self:PlaceSearch(hasRoute)
        end
        if opts.onRouteChanged then opts.onRouteChanged(self, hasRoute) end
    end
    frame.Render = Render
    surfaces[#surfaces + 1] = frame
    frame:HookScript("OnShow", function(self) self:Render() end)
end

-- The page under the map search tab

-- The steps stop above the foot rule and scroll under the wheel; the rule
-- under the time line shows with a route.
local function FitPage(self, hasRoute)
    if self.headRule then self.headRule:SetShown(hasRoute and true or false) end
    -- A new route starts at its first step.
    local route = Route()
    if self.fitRoute ~= route then
        self.fitRoute = route
        if (self.scrollOffset or 0) > 0 then
            self.scrollOffset = 0
            self:Render()
            return
        end
    end
    local top, foot = self.list:GetTop(), self.footRule and self.footRule:GetTop()
    if not (top and foot) then return end
    local avail = mmax(1, top - foot - 8)
    local maxOffset = mmax(0, (self.contentHeight or 0) - avail)
    if (self.scrollOffset or 0) > maxOffset then
        self.scrollOffset = maxOffset
        self:Render()
        return
    end
    local h = mmax(1, math.min(self.contentHeight or 0, avail))
    self.list:SetHeight(h)
    self.list:SetClipsChildren(true)
    local bar = self.scrollBar
    if bar then
        self.maxOffset = maxOffset
        local total = self.contentHeight or 0
        self.syncingBar = true
        bar:SetVisibleExtentPercentage(total > 0 and math.min(1, avail / total) or 1)
        bar:SetScrollPercentage(maxOffset > 0 and (self.scrollOffset or 0) / maxOffset or 0)
        self.syncingBar = nil
    end
    -- The cast buttons again, inside the fitted list; never a new render,
    -- which sets the list's full height and comes back here.
    if hasRoute and route then
        for _, row in ipairs(self.rows or {}) do
            local step = row.index and row:IsShown() and route.steps[row.index]
            if step then
                SetupCast(row.cast, step, (route.active or 1) == row.index and not route.arrived,
                          row.index >= (route.active or 1) and not route.arrived)
            end
        end
    end
end

local function Rule(frame)
    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    GPS.Inked(frame, function(ink) rule:SetColorTexture(ink.dim[1], ink.dim[2], ink.dim[3], 0.35) end)
    rule:SetPoint("LEFT", frame, "LEFT", 12, 0)
    rule:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    return rule
end

-- A surface's menu at the cursor: the defs given, else its whole menu.
local function CursorMenu(f, name)
    local anchor = CreateFrame("Frame", nil, f)
    anchor:SetSize(1, 1)
    return function(defs)
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        anchor:ClearAllPoints()
        anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
        if ns.ShowTogglePopup then ns.ShowTogglePopup(name, anchor, defs or GPS.MenuRows(f), {}) end
    end
end

local function BuildPage(frame)
    frame.gameLook = true         -- its fields are the map's own, not the theme's
    BuildSurface(frame, { popoutButton = true, listGap = 14, onRouteChanged = FitPage })
    frame.previewOnHover = true   -- this surface sits beside the map
    frame.mapFont = true          -- its steps follow the map search's font size
    -- Right-click: the window's menu, as on the window and the section.
    frame.ShowMenu = CursorMenu(frame, "EasyFindGPSPageMenu")
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then frame.ShowMenu() end
    end)
    if ns.GPSTrip then ns.GPSTrip.BuildEditor(frame) end
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
        if IsControlKeyDown() then
            if ns.MapTab and ns.MapTab.StepFontSize then ns.MapTab.StepFontSize(delta) end
            return
        end
        if not Route() then return end
        self.scrollOffset = mmax(0, (self.scrollOffset or 0) - delta * ROW_H)
        self:Render()
    end)
    frame:HookScript("OnSizeChanged", function(self) if self:IsShown() then self:Render() end end)
    -- The steps' scroll bar where the map search keeps its own, in the strip
    -- right of the panel.
    local panel = frame:GetParent()
    local bar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
    bar:SetFrameStrata("HIGH")
    -- Shown while the page is, as the map search's own bar is.
    bar:SetPoint("TOPLEFT", panel, "TOPRIGHT", panel.barGap or 8, 2)
    bar:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", panel.barGap or 8, -4)
    if bar.RegisterCallback and bar.Event and bar.Event.OnScroll then
        bar:RegisterCallback(bar.Event.OnScroll, function(_, pct)
            if frame.syncingBar then return end
            local offset = mfloor(pct * (frame.maxOffset or 0) + 0.5)
            if offset == (frame.scrollOffset or 0) then return end
            frame.scrollOffset = offset
            frame:Render()
        end, frame)
    end
    frame.scrollBar = bar
    -- A rule under the time line sets the steps apart from it.
    frame.headRule = Rule(frame)
    frame.headRule:SetPoint("TOP", frame.clearBtn, "BOTTOM", 0, -4)
    frame.headRule:Hide()
    -- At its foot, under a rule: GPS is experimental and where to say so.
    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.note = note
    local exp = ns.CreateFeatureTag(frame, "exp", L["TAG_EXP_TITLE"], L["GPS_EXP_TT"])
    note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12 + exp:GetWidth() + 6, 10)
    note:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
    note:SetJustifyH("LEFT")
    note:SetText(L["GPS_EXP_NOTE"])
    GPS.Inked(frame, function(ink) note:SetTextColor(unpack(ink.dim)) end)
    note._efOwnColor = true
    exp:SetPoint("TOPRIGHT", note, "TOPLEFT", -6, 1)
    -- The note's click, as its badge's: the bug report form.
    local noteBtn = CreateFrame("Button", nil, frame)
    noteBtn:SetAllPoints(note)
    noteBtn:SetScript("OnClick", function() if EasyFind.OpenBugReport then EasyFind:OpenBugReport() end end)
    noteBtn:SetScript("OnEnter", function() note:SetTextColor(unpack(GPS.Ink(frame).hover)) end)
    noteBtn:SetScript("OnLeave", function() note:SetTextColor(unpack(GPS.Ink(frame).dim)) end)
    frame.footRule = Rule(frame)
    frame.footRule:SetPoint("BOTTOM", exp, "TOP", 0, 7)
end

if ns.MapTab and ns.MapTab.RegisterPage then
    -- The route view lives inside the Map search tab, under its search bar;
    -- the directions bar above the results leads back to it.
    ns.MapTab:RegisterPage({
        id = "gps",
        noTab = true,
        keepSearch = true,
        title = L["APP_GPS"],
        hasContent = function() return Route() ~= nil end,
        clear = function() GPS:Clear() end,
        barText = function()
            local route = Route()
            return route and sformat(L["GPS_RESUME_FMT"], route.dest.name or "?") or L["APP_GPS"]
        end,
        -- Right-click on the bar: the route's own actions without opening it.
        onBarMenu = function(anchor)
            if not ns.ShowTogglePopup then return end
            ns.ShowTogglePopup("EasyFindGPSBarPopup", anchor, {
                { kind = "action", label = L["GPS_POPOUT"], onClick = function() GPS:OpenWindow() end },
                { kind = "action", label = L["GPS_CLEAR"], onClick = function() GPS:Clear() end },
                { kind = "separator" },
                GPS.LaunchRow(),
            }, {})
        end,
        build = BuildPage,
        onShow = function(frame) frame:Render() end,
    })
end

-- The objective tracker dock: a section in the tracker's own look at a slot picked by
-- dragging. Drop the window on the tracker to dock, drag the section clear to float.

local dockFrame
local RenderDock            -- defined below; the ghost helpers above it call it
local SectionLook           -- defined with it; the placing reads it
local PopoutSize            -- defined with the pop-out below; the floating section uses it
local DOCK_REACH = 24
local DOCK_HEADER_H = 25
local DOCK_INDENT = 20
local DOCK_LINE_GAP = 4

-- The section's other looks: the Era watch's (its lines wrap past W, are
-- LINE tall, its titles in TITLE) and ClassicUI's restyled tracker's.
local Look = { W = 280, LINE = 13, TITLE = { 0.75, 0.61, 0 }, greys = {} }

function Look.Grey(c)
    local g = Look.greys[c]
    if not g then
        g = { c, c, c }
        Look.greys[c] = g
    end
    return g
end

-- A tracker line in its color, gold while the cursor is on a line that
-- does something: the game's tracker brightens a hovered quest's lines.
function Look.ShadeLine(row)
    local c = row.shade or ns.TEXT_DIM
    if row.hovered and (row.index or row.tip or row.from) then c = ns.GOLD_COLOR end
    row.text:SetTextColor(c[1], c[2], c[3])
    if row.dash then row.dash:SetTextColor(c[1], c[2], c[3]) end
end

function Look.HoverLine(row, on)
    row.hovered = on or nil
    Look.ShadeLine(row)
end

local function ClientTracker()
    local t = _G.ObjectiveTrackerFrame
    if t and type(t.modules) == "table" then return t end
    return nil
end

-- The game's tracker while it is up: it hides itself with nothing to
-- show, and another tracker (Questie's) hides it too.
local function ShownTracker()
    local t = ClientTracker()
    return t and t:IsShown() and t or nil
end

function Look.QuestieTracker()
    local q = _G.Questie_BaseFrame
    return q and q:IsShown() and q or nil
end

-- What the section snaps into: "game" the game's tracker, "classic" that
-- tracker restyled by ClassicUI Forever, "era" its Era quest watch,
-- "questie" Questie's tracker in the game's place, or nil with none to
-- snap into (the trackers hidden, or a watch without room).
local function Host()
    local Replacement = ns.SearchOpeners and ns.SearchOpeners.Replacement
    local api = Replacement and Replacement("questWatch")
    if api then return api.WatchRoom and "era" or nil, api end
    -- The tracker hidden by Toggle Objective Tracker: nothing to snap into.
    local db = DB()
    if db and db.objectiveTrackerHidden then return nil end
    local hidden = Replacement and Replacement("hideObjectiveTracker")
    if not hidden and ShownTracker() then
        return (Replacement and Replacement("questTracker")) and "classic" or "game"
    end
    return Look.QuestieTracker() and "questie" or nil
end

-- The tracker the section snaps into: the game's, or Questie's.
local function Tracker()
    local host = Host()
    if host == "game" or host == "classic" then return ClientTracker() end
    if host == "questie" then return Look.QuestieTracker() end
    return nil
end

-- The Era watch and its API, while the section snaps into it.
local function Watch()
    local host, api = Host()
    if host ~= "era" then return nil end
    return api.GetFrame("questWatch"), api
end

-- A frame's edges in screen pixels: left, top, right, bottom.
function Look.ScreenRect(r)
    local l, b, w, h = r:GetRect()
    if not l then return nil end
    local s = r:GetEffectiveScale()
    return l * s, (b + h) * s, (l + w) * s, b * s
end

-- The menu row for the beacon in the world (on unless turned off).
function GPS.WorldPinRow()
    return { kind = "check", label = L["GPS_WORLD_PIN"], tooltip = L["GPS_WORLD_PIN_TT"],
        get = function() local db = DB() return not (db and db.gpsWorldPin == false) end,
        set = function(v)
            local db = DB()
            if db then db.gpsWorldPin = Utils.OffOrNil(v) end
            Refresh()
        end }
end

-- The menu row for the arrow at the character (on unless turned off). It
-- points only while the route is tracked, so a route let go for a quest
-- shows it off, and checking it tracks the route again: the way back to a
-- lost arrow from every surface's menu.
function GPS.ArrowRow()
    return { kind = "check", label = L["GPS_ARROW"], tooltip = L["GPS_ARROW_MENU_TT"],
        get = function()
            local db, route = DB(), Route()
            return not (db and db.gpsArrow == false) and not (route and route.untracked)
        end,
        set = function(v)
            local db, route = DB(), Route()
            if db then db.gpsArrow = Utils.OffOrNil(v) end
            if v and route and route.untracked then ToggleRouteTracking() end
            Refresh()
        end }
end

-- Back under the character, shown only while it has a place of its own.
function GPS.ArrowResetRow()
    local db = DB()
    if not (db and db.gpsArrowPos) then return nil end
    return { kind = "action", label = L["GPS_ARROW_RESET_MENU"], onClick = function()
        local Arrow = ns.GPSArrow
        if Arrow and Arrow.ResetPlace then Arrow.ResetPlace() else db.gpsArrowPos = nil end
    end }
end

-- The menu row for learning cheap flight points on the way (on unless
-- turned off); the trip on screen is planned again either way.
-- The menu rows for two of the advice lines: a detour to learn a flight
-- master, and the other ways there (not planned while hidden).
function GPS.DetoursRow()
    return { kind = "check", label = L["GPS_SHOW_DETOURS"], tooltip = L["GPS_SHOW_DETOURS_TT"],
        get = function() local db = DB() return not (db and db.gpsShowDetours == false) end,
        set = function(v)
            local db = DB()
            if db then db.gpsShowDetours = Utils.OffOrNil(v) end
            -- Not worked out while both it and learning on the way were off.
            if v and Route() then PlanOtherWays() end
            Refresh()
        end }
end

function GPS.OtherWaysRow()
    return { kind = "check", label = L["GPS_SHOW_OTHER_WAYS"], tooltip = L["GPS_SHOW_OTHER_WAYS_TT"],
        get = function() local db = DB() return not (db and db.gpsShowOtherWays == false) end,
        set = function(v)
            local db = DB()
            if db then db.gpsShowOtherWays = Utils.OffOrNil(v) end
            local route = Route()
            if route and not v then route.others = nil end
            if route and v then PlanOtherWays() end
            Refresh()
        end }
end

function GPS.AutoLearnRow()
    return { kind = "check", label = L["GPS_AUTO_LEARN"], tooltip = L["GPS_AUTO_LEARN_TT"],
        get = function() local db = DB() return not (db and db.gpsAutoLearn == false) end,
        set = function(v)
            local db = DB()
            if db then db.gpsAutoLearn = Utils.OffOrNil(v) end
            local route = Route()
            if route and route.dest and not route.arrived then
                GPS:Plan(route.dest.name, function() return GPS:BuildStops(route, nil, route.wayAvoid, nil, "first") end,
                    function(steps, total, advice)
                        if steps and Route() == route then GPS.StopAdded(route, nil, {}, steps, total, advice) end
                    end)
            end
        end }
end

-- What Extensions' GPS opens: the map page, or the window as it was left.
function GPS.LaunchesWindow()
    local db = DB()
    return db and db.gpsLaunchWindow == true or false
end

function GPS:Launch()
    if GPS.LaunchesWindow() then return GPS:OpenWindow() end
    return GPS:Open()
end

-- The ways of travel a route may avoid, and each one's switch: the
-- settings page and Route planning's Avoid flyout share them.
function GPS.AvoidKinds()
    local kinds = { "taxi", "boat", "zeppelin", "portal", "hearth" }
    -- A character with no teleport of its own gets no switch for them.
    if ns.GPSRoute and ns.GPSRoute.HasTeleports(ns.GPSData) then kinds[#kinds + 1] = "teleports" end
    if ns.NPC_DATA and ns.NPC_DATA.danger then kinds[#kinds + 1] = "danger" end
    if ns.GPSNav and ns.GPSNav.HasRoads and ns.GPSNav.HasRoads(0) then kinds[#kinds + 1] = "offroad" end
    if ns.GPSNav and ns.GPSNav.DropHeights and ns.GPSNav.DropHeights(0) then kinds[#kinds + 1] = "jumps" end
    return kinds
end

local AVOID_OWN_TIP = { danger = true, offroad = true, jumps = true }
GPS.AVOID_ON = { danger = true }   -- avoided until turned off: saved only as false

function GPS.AvoidRow(kind)
    local key = "GPS_AVOID_" .. kind:upper()
    local default = GPS.AVOID_ON[kind] or false
    return { kind = "check", label = L[key], tooltip = AVOID_OWN_TIP[kind] and L[key .. "_TT"] or L["GPS_AVOID_TT"],
        get = function()
            local avoid = GPS.Avoids()
            local on = avoid and avoid[kind]
            if on == nil then return default end
            return on
        end,
        set = function(on)
            local d = DB()
            if not d then return end
            d.gpsAvoid = GPS.Avoids() or {}
            on = on and true or false
            if on == default then d.gpsAvoid[kind] = nil else d.gpsAvoid[kind] = on end
            local route = Route()
            if route and not route.arrived then Reroute(route) end
        end }
end

-- The box under the arrow and the beacon: shown unless switched off, its
-- lines each a switch of their own (2026-11-19: "as much/little as ppl
-- want"), all stored only when off. The last is no line: a long step
-- runs onto more lines, where off cuts it to one (2026-11-21).
GPS.BOX_LINES = {
    { key = "gpsBoxStep", label = _G["QUEST_DESCRIPTION"] or "Description" },
    { key = "gpsBoxThisStep", label = L["GPS_BOX_THIS_STEP"] },
    { key = "gpsBoxTotal", label = L["GPS_BOX_TOTAL"] },
    { key = "gpsBoxWrap", label = L["GPS_BOX_WRAP"] },
}

function GPS.ArrowBoxShown()
    local db = DB()
    return not (db and db.gpsArrowBox == false)
end

function GPS.SetArrowBox(on)
    local db = DB()
    if not db or on == GPS.ArrowBoxShown() then return end
    db.gpsArrowBox = Utils.OffOrNil(on)
    Refresh()
end

function GPS.BoxLineShown(key)
    local db = DB()
    return not (db and db[key] == false)
end

function GPS.SetBoxLine(key, on)
    local db = DB()
    if not db or on == GPS.BoxLineShown(key) then return end
    db[key] = Utils.OffOrNil(on)
    Refresh()
end

-- The Arrow text choice the switches replaced: full, step and distance
-- (no trip time), step only, or off (the box hidden, its choice kept).
function GPS.MigrateArrowText(db)
    local mode = db.gpsArrowText
    if mode == "off" then
        db.gpsArrowBox = false
        mode = db.gpsArrowTextWas
    end
    if mode == "step" then db.gpsBoxThisStep = false end
    if mode == "step" or mode == "range" then db.gpsBoxTotal = false end
    db.gpsArrowText, db.gpsArrowTextWas = nil, nil
end

-- A line an extension puts under the step in that box (the gps setStatus
-- action: a guide's grind progress), or nil.
function GPS.SetStatus(text)
    GPS.status = type(text) == "string" and text ~= "" and text or nil
end

-- A guide's farm circuit (the gps setCircuit action): its spots, { mapID,
-- x, y } each in map fractions, drawn as a closed loop on the world map
-- and the minimap; nil, fewer than three or across continents, none.
function GPS.SetCircuit(list)
    local c
    if type(list) == "table" and #list >= 3 then
        c = { pts = {} }
        for _, s in ipairs(list) do
            local ci, wx, wy = WorldPos(s.mapID, s.x, s.y)
            if not ci or (c.ci and ci ~= c.ci) then
                c = nil
                break
            end
            c.ci = ci
            c.pts[#c.pts + 1], c.pts[#c.pts + 2] = wx, wy
        end
    end
    GPS.circuit = c
    if ns.GPSPreview and ns.GPSPreview.Redraw then ns.GPSPreview.Redraw() end
    if ns.GPSMinimap and ns.GPSMinimap.Redraw then ns.GPSMinimap.Redraw() end
end

-- The menu row hiding the steps already done (off unless turned on).
function GPS.HideDoneRow()
    return { kind = "check", label = L["GPS_HIDE_DONE"], tooltip = L["GPS_HIDE_DONE_TT"],
        get = function() local db = DB() return db ~= nil and db.gpsHideDone == true end,
        set = function(v)
            local db = DB()
            if db then db.gpsHideDone = v or nil end
            Refresh()
        end }
end

-- The menu row showing the window's next step alone (off unless turned on).
function GPS.NextOnlyRow()
    return { kind = "check", label = L["GPS_SIZE_NEXT_ONLY"],
        get = function() local db = DB() return db and db.gpsPopoutNextOnly == true end,
        set = function(v)
            local db = DB()
            if db then db.gpsPopoutNextOnly = v or nil end
            if popoutFrame then
                popoutFrame.scrollOffset = 0
                popoutFrame:Render()
            end
        end }
end

function GPS.LaunchRow()
    return { kind = "check", label = L["GPS_LAUNCH_WINDOW"], tooltip = L["GPS_LAUNCH_WINDOW_TT"], get = GPS.LaunchesWindow,
        set = function(v)
            local db = DB()
            if db then db.gpsLaunchWindow = v or nil end
        end }
end

-- The menu row for snapping into the tracker (on unless turned off); off
-- while snapped in, the section leaves for the window.
function GPS.SnapRow()
    return { kind = "check", label = L["GPS_SNAP_TRACKER"],
        get = function() local db = DB() return not (db and db.gpsNeverDock) end,
        set = function(v)
            local db = DB()
            if db then db.gpsNeverDock = (not v) or nil end
            if not v and GPS:IsDocked() then
                if dockFrame and dockFrame.docked and dockFrame:IsShown() then
                    GPS:TogglePopout(true)
                elseif db then
                    db.gpsDocked = nil
                end
            end
        end }
end

-- A check row on the game's own menu: it stays up and redraws the box
-- after a click; an error in the flip is reported, not swallowed.
local function AddGameCheck(parent, d)
    local box = parent:CreateCheckbox(d.label, function() return d.get() and true or false end, function()
        local ok, err = pcall(d.set, not d.get())
        if not ok and EasyFind.Print then EasyFind:Print("GPS menu: " .. tostring(err)) end
        return MenuResponse and MenuResponse.Refresh or nil
    end)
    if d.tooltip and box and box.SetTooltip then
        box:SetTooltip(function(tip)
            tip:SetText(d.label, 1, 1, 1)
            tip:AddLine(d.tooltip, nil, nil, nil, true)
        end)
    end
    return box
end

-- Our menu rows on the game's own context menu, for surfaces in the game's look.
-- False when the game's menu API is missing.
ShowGameMenu = function(owner, defs)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return false end
    -- A flyout's rows (ShowTogglePopup's): one with get is a check, one
    -- with picked a radio; a row's own flyout nests under it.
    local function AddRows(parent, rows)
        rows = type(rows) == "function" and rows() or rows
        for i = 1, #rows do
            local r = rows[i]
            local el
            if r.isSeparator then
                parent:CreateDivider()
            elseif r.check then
                el = AddGameCheck(parent, r.check)
            elseif r.get then
                el = AddGameCheck(parent, { label = r.text, tooltip = r.tooltip, get = r.get, set = function() r.onClick() end })
            else
                local onClick = r.onClick
                if r.copy and ns.CopyToClipboard then
                    onClick = function() ns.CopyToClipboard(r.copy, r.copyLink) end
                end
                if r.picked ~= nil then
                    el = parent:CreateRadio(r.text, function() return r.picked end, onClick or function() end)
                else
                    el = parent:CreateButton(r.text, onClick or function() end)
                end
            end
            if el and r.disabled and el.SetEnabled then el:SetEnabled(false) end
            if el and r.submenu then AddRows(el, r.submenu) end
        end
    end
    local ok = pcall(MenuUtil.CreateContextMenu, owner, function(_, root)
        for _, d in ipairs(defs) do
            if d.kind == "separator" then
                root:CreateDivider()
            elseif d.kind == "title" then
                root:CreateTitle(d.label)
            elseif d.kind == "check" then
                AddGameCheck(root, d)
            elseif d.kind == "radio" then
                root:CreateRadio(d.label, function() return d.get() == d.value end, function()
                    local ok2, err = pcall(d.set)
                    if not ok2 and EasyFind.Print then EasyFind:Print("GPS menu: " .. tostring(err)) end
                end)
            elseif d.kind == "action" and d.onClick then
                root:CreateButton(d.label, d.onClick)
            elseif d.kind == "submenu" then
                AddRows(root:CreateButton(d.label), d.rows)
            end
        end
    end)
    return ok
end
GPS.ShowGameMenu = ShowGameMenu

local function HideMenus()
    if ns.HideTogglePopup then
        ns.HideTogglePopup("EasyFindGPSDockMenu")
        ns.HideTogglePopup("EasyFindGPSWindowMenu")
        ns.HideTogglePopup("EasyFindGPSBeaconMenu")
    end
end

-- The window's look: the themed window, or the tracker section look
-- floating on its own.
local function PopoutStyle()
    local db = DB()
    return (db and db.gpsPopoutStyle) or "easyfind"
end

local VisibleModules   -- defined below; the drop zone reads the sections

-- A drop docks over the tracker, from its top to the end of what it shows (its frame
-- runs far lower; on Forever most of the screen), or a header's height when empty.
local function NearTracker(f)
    local t = Tracker()
    local db = DB()
    if db and db.gpsNeverDock then return false end
    local watch = Watch()
    if watch and f:GetLeft() then
        -- Over the Era watch's column: its lines run left from its right edge.
        local wl, wt, wr, wb = Look.ScreenRect(watch)
        local fl, ft, fr, fb = Look.ScreenRect(f)
        if not (wl and fl) then return false end
        local s = watch:GetEffectiveScale()
        local cx = (fl + fr) / 2
        return cx > math.min(wl, wr - Look.W * s) and cx < wr
            and ft > wb - DOCK_REACH * s and fb < wt + DOCK_REACH * s
    end
    if not (t and f:GetLeft() and t:GetLeft() and t:GetTop()) then return false end
    local top = t:GetTop()
    local bottom = top - DOCK_HEADER_H * 2
    -- Questie's frame ends where its lines do.
    if not t.modules and t:GetBottom() then bottom = math.min(bottom, t:GetBottom()) end
    local mods = VisibleModules(t)
    for i = 1, #mods do
        local b = mods[i]:GetBottom()
        if b and b < bottom then bottom = b end
    end
    if dockFrame and dockFrame.docked and dockFrame:GetBottom() and dockFrame:GetBottom() < bottom then
        bottom = dockFrame:GetBottom()
    end
    -- Onto it, not beside it: the frame's middle over the tracker's columns,
    -- so a window can sit right next to the tracker without docking.
    local cx = (f:GetLeft() + f:GetRight()) / 2
    return cx > t:GetLeft() and cx < t:GetRight()
        and f:GetTop() > bottom - DOCK_REACH and f:GetBottom() < top + DOCK_REACH
end

-- The tracker's shown sections, top to bottom; Questie's has none.
VisibleModules = function(t)
    local out = {}
    for i = 1, type(t.modules) == "table" and #t.modules or 0 do
        local m = t.modules[i]
        local h = m.GetContentsHeight and m:GetContentsHeight() or m:GetHeight()
        if m:IsShown() and h and h > 0 then out[#out + 1] = m end
    end
    return out
end

-- The slot a frame whose top edge is at screen height y lands in: over or
-- under the Era watch's quests; in the game's tracker always under its
-- sections, the one place that needs no room made inside it.
local function SlotAt(y)
    local watch = Watch()
    if watch then
        -- Above the Era watch's middle: over its quests; else under them.
        local _, wt, _, wb = Look.ScreenRect(watch)
        local s = UIParent:GetEffectiveScale()
        return (wt and y * s > (wt + wb) / 2) and { top = true } or { bottom = true }
    end
    return { bottom = true }
end

local function SameSlot(a, b)
    if not a or not b then return false end
    return a.top == b.top and a.after == b.after and a.bottom == b.bottom
end

-- The room the Era watch keeps for the section, given back. The game's
-- tracker never holds anything of ours: a value it reads taints its every
-- layout, and in a fight that layout reads secret auras.
local function ClearInsert()
    if not dockFrame then return end
    local ins = dockFrame.insert
    dockFrame.insert = nil
    if ins and ins.api then ins.api.WatchRoom(ins.side, nil) end
end

-- Room in the Era watch above or under its quests, in its scale; kept
-- until the side or the size changes.
function Look.WatchInsert(api, watch, slot, height, width)
    local side = slot and slot.top and "top" or "bottom"
    local k = dockFrame:GetEffectiveScale() / watch:GetEffectiveScale()
    local h, w = mfloor(height * k + 0.5), mfloor(width * k + 0.5)
    local ins = dockFrame.insert
    if ins and ins.api and ins.side == side and ins.height == h and ins.width == w then return side end
    ClearInsert()
    api.WatchRoom(side, h, w)
    dockFrame.insert = { api = api, side = side, height = h, width = w }
    return side
end

-- In the room the Era watch keeps: its top left, or its bottom left.
function Look.PlaceInWatch(watch, api)
    local gap = dockFrame.dragGap
    if gap then
        Look.WatchInsert(api, watch, gap.slot, gap.height, gap.width or Look.W)
        return
    end
    if not dockFrame.docked or dockFrame.dragging or dockFrame.ghost then return end
    local db = DB()
    local side = Look.WatchInsert(api, watch, db and db.gpsWatchSlot, dockFrame:GetHeight() or 13, dockFrame:GetWidth() or Look.W)
    local wl, wt, _, wb = Look.ScreenRect(watch)
    -- Kept out of sight until the watch has a spot (it is built after login).
    local alpha = (wl and watch:IsVisible()) and 1 or 0
    if dockFrame:GetAlpha() ~= alpha then dockFrame:SetAlpha(alpha) end
    if not wl then return end
    local s = dockFrame:GetEffectiveScale()
    local lvl = (watch:GetFrameLevel() or 0) + 5
    if dockFrame:GetFrameLevel() ~= lvl then dockFrame:SetFrameLevel(lvl) end
    dockFrame:ClearAllPoints()
    if side == "top" then
        dockFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", wl / s, wt / s)
    else
        dockFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", wl / s, wb / s)
    end
end

-- A faded section takes no mouse: nothing of ours to hover or click
-- under a folded tracker. Out of a fight only (the cast buttons are
-- protected); rows made later are walked on the next placing.
local function DockMouse(on)
    if InCombatLockdown() then return end
    -- Every pooled hit row, four times a second, was 150 ms a tick: shown,
    -- walked only to turn back on; folded, only what is shown takes a mouse.
    if on and not dockFrame.efMouseOffAny then return end
    local function walk(f)
        local kids = { f:GetChildren() }
        for i = 1, #kids do
            local c = kids[i]
            if on then
                if c.efMouseOff then
                    c.efMouseOff = nil
                    c:EnableMouse(true)
                end
                walk(c)
            elseif c:IsShown() then
                if c:IsMouseEnabled() then
                    c.efMouseOff = true
                    c:EnableMouse(false)
                    dockFrame.efMouseOffAny = true
                end
                walk(c)
            end
        end
    end
    walk(dockFrame)
    if on then dockFrame.efMouseOffAny = nil end
end

-- Hung on the screen at left, top, width wide; anchored again only when
-- the place changed (this runs four times a second), or when something
-- else anchored it since (a drag's ghost rides the window).
function Look.HangDock(left, top, width)
    local placed = dockFrame.placed
    local _, hungOn = dockFrame:GetPoint(1)
    if placed and hungOn == UIParent and placed.left == left and placed.top == top and placed.width == width then
        return
    end
    placed = placed or {}
    placed.left, placed.top, placed.width = left, top, width
    dockFrame.placed = placed
    dockFrame:ClearAllPoints()
    dockFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    dockFrame:SetWidth(width)
end

-- Under Questie's tracker at its left, a section wide at least and kept on
-- screen, hung from where its frame ends.
Look.QUESTIE_MIN_W, Look.QUESTIE_GAP = 240, 6
function Look.QuestieWidth(t)
    return mmax(Look.QUESTIE_MIN_W, t:GetWidth() or 0)
end

function Look.PlaceUnderQuestie(t)
    if dockFrame:GetAlpha() ~= 1 then dockFrame:SetAlpha(1) end
    DockMouse(true)
    local tl, _, _, tb = Look.ScreenRect(t)
    if not tl then return end
    local s = dockFrame:GetEffectiveScale()
    local width = Look.QuestieWidth(t)
    local left = math.min(tl / s, UIParent:GetWidth() - width)
    Look.HangDock(left, tb / s - Look.QUESTIE_GAP, width)
end

local function PlaceDock()
    if not dockFrame then return end
    -- ClassicUI's tracker pick changed under it: drawn again in the new look.
    if (dockFrame.docked or dockFrame.floating) and dockFrame.look ~= SectionLook(dockFrame) then
        return RenderDock(dockFrame)
    end
    -- Nothing left to snap into (the tracker hidden or emptied): the window,
    -- snapped back in when a tracker shows again.
    if dockFrame.docked and not (dockFrame.dragging or dockFrame.ghost) and Host() == nil then
        GPS:Undock()
        GPS:TogglePopout(true)
        local db = DB()
        if db then db.gpsDocked = true end
        return GPS.AwaitHost(0)
    end
    local watch, api = Watch()
    if watch then return Look.PlaceInWatch(watch, api) end
    local t = Tracker()
    if not t then return end
    if dockFrame.dragGap or not dockFrame.docked or dockFrame.dragging or dockFrame.ghost then return end
    if not t.modules then return Look.PlaceUnderQuestie(t) end
    -- Above the tracker's own blocks: they take the mouse, and where the
    -- two overlap they would swallow the header's clicks and drags.
    local lvl = (t:GetFrameLevel() or 0) + 40
    if dockFrame:GetFrameLevel() ~= lvl then dockFrame:SetFrameLevel(lvl) end
    local collapsed = t.IsCollapsed and t:IsCollapsed()
    -- The player folding the tracker folds the section with it; opened or
    -- routed to while folded, it shows alone under the folded header.
    if collapsed and not dockFrame.wasFolded then dockFrame.showFolded = nil end
    dockFrame.wasFolded = collapsed
    local hidden = collapsed and not dockFrame.showFolded
    -- Faded with a folded tracker; its cast button, not ours to fade, hides.
    local alpha = hidden and 0 or 1
    if dockFrame:GetAlpha() ~= alpha then
        dockFrame:SetAlpha(alpha)
        Refresh()
    end
    DockMouse(not hidden)
    -- Under the tracker's last shown section, under its header with none;
    -- hung on the screen from what the tracker's frames read, never on them.
    local mods = VisibleModules(t)
    local last = mods[#mods]
    local ref = last or t.modules[1]
    local margin = ref and ref.leftMargin or 0
    local refW = ref and ref.GetWidth and ref:GetWidth() or 0
    local tl, tt, tr = Look.ScreenRect(t)
    local top
    if last then
        local _, _, _, lb = Look.ScreenRect(last)
        top = lb and lb - (t.moduleSpacing or 10) * t:GetEffectiveScale()
    elseif tt then
        local head = t.Header
        local hb
        if head then hb = select(4, Look.ScreenRect(head)) end
        top = hb or (tt - DOCK_HEADER_H * t:GetEffectiveScale())
    end
    if not (tl and top) then return end
    local s = dockFrame:GetEffectiveScale()
    -- Exactly a section's width, else inset by the left margin on both sides.
    local width = (refW and refW > 0) and refW or mmax(1, (tr - tl) / s - 2 * margin)
    Look.HangDock(tl / s + margin, top / s, width)
end

-- A drag in progress over the tracker: open (or move) the room at the
-- slot under the dragged frame; nil ends it.
local function DragGap(frame, height)
    if not dockFrame then return end
    local t = Tracker()
    if not (t or Watch()) then return end
    local want
    if frame and NearTracker(frame) then
        want = { slot = SlotAt(frame:GetTop() or 0), height = height, width = dockFrame:GetWidth() }
    end
    local had = dockFrame.dragGap
    if (want == nil) ~= (had == nil) or (want and had and (not SameSlot(want.slot, had.slot) or want.height ~= had.height)) then
        dockFrame.dragGap = want
        if not want then ClearInsert() end
        PlaceDock()
    end
end

-- The section look as a ghost under a dragged window: the section frame
-- rides on the window, at the tracker's width, and the window fades.
local function ShowSectionGhost(window)
    local t = Tracker()
    if not (dockFrame and (t or Watch())) then return end
    dockFrame.ghost = true
    dockFrame.docked = true
    RenderDock(dockFrame)
    dockFrame.docked = nil
    dockFrame:ClearAllPoints()
    if t then dockFrame:SetWidth(t.modules and (t:GetWidth() or 260) or Look.QuestieWidth(t)) end
    dockFrame:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    dockFrame:SetFrameStrata("HIGH")
    dockFrame:SetAlpha(1)
    dockFrame:Show()
    window:SetAlpha(0)
end

local function HideSectionGhost(window)
    if dockFrame and dockFrame.ghost then
        dockFrame.ghost = nil
        dockFrame:Hide()
        dockFrame:SetFrameStrata("LOW")
    end
    window:SetAlpha(1)
end

-- The window look as a ghost under a dragged section: the window rides
-- on the section and the section fades.
local function ShowWindowGhost(section)
    if not popoutFrame then return end
    popoutFrame:ClearAllPoints()
    popoutFrame:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    popoutFrame:SetAlpha(1)
    popoutFrame:Show()
    popoutFrame:Render()
    section:SetAlpha(0)
end

local function HideWindowGhost(section)
    if popoutFrame and popoutFrame.ghosting then
        popoutFrame.ghosting = nil
        popoutFrame:Hide()
    end
    section:SetAlpha(1)
end

local function DockLine(f, i)
    local rows = f.lines
    if rows[i] then return rows[i] end
    local row = CreateFrame("Button", nil, f)
    row:SetPoint("LEFT", f, "LEFT", DOCK_INDENT, 0)
    row:SetPoint("RIGHT", f, "RIGHT", -4, 0)
    row.dash = row:CreateFontString(nil, "ARTWORK", "ObjectiveTrackerLineFont")
    row.dash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.dash:SetText(QUEST_DASH or "- ")
    row.text = row:CreateFontString(nil, "ARTWORK", "ObjectiveTrackerLineFont")
    row.text:SetPoint("TOPLEFT", row.dash, "TOPRIGHT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if not self.index then return end
        if button == "RightButton" then
            GPS.ShowStepMenu(f, self.index)
        elseif IsShiftKeyDown() then GPS.GoToStep(self.index)
        else GPS.ShowStep(self.index) end
    end)
    row:SetScript("OnEnter", function(self) Look.HoverLine(self, true) end)
    row:SetScript("OnLeave", function(self) Look.HoverLine(self, false) end)
    -- A teleport's icon at the line's right edge, flush with the section's.
    row.cast = CastButton(row, -4)
    row.cast:SetSize(16, 16)
    rows[i] = row
    return row
end

-- The window's flight path advice, as tracker lines under the steps.
local function DockTipLine(f, i)
    f.tipLines = f.tipLines or {}
    local row = f.tipLines[i]
    if row then return row end
    row = CreateFrame("Button", nil, f)
    row.dash = row:CreateFontString(nil, "ARTWORK", "ObjectiveTrackerLineFont")
    row.dash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.dash:SetText(QUEST_DASH or "- ")
    row.text = row:CreateFontString(nil, "ARTWORK", "ObjectiveTrackerLineFont")
    row.text:SetPoint("TOPLEFT", row.dash, "TOPRIGHT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button ~= "RightButton" then return TipClick(self) end
        if f.ShowMenu then f.ShowMenu() end
    end)
    row:SetScript("OnEnter", function(self)
        Look.HoverLine(self, true)
        TipEnter(self)
    end)
    row:SetScript("OnLeave", function(self)
        Look.HoverLine(self, false)
        GameTooltip_Hide()
    end)
    f.tipLines[i] = row
    return row
end

-- The section's line for a start picked, with Reset back to the player.
local function DockFromLine(f)
    if f.fromLine then return f.fromLine end
    local row = CreateFrame("Button", nil, f)
    row.dash = row:CreateFontString(nil, "ARTWORK", "ObjectiveTrackerLineFont")
    row.dash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.dash:SetText(QUEST_DASH or "- ")
    row.text = row:CreateFontString(nil, "ARTWORK", "ObjectiveTrackerLineFont")
    row.text:SetPoint("TOPLEFT", row.dash, "TOPRIGHT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    local reset = CreateFrame("Button", nil, row)
    reset:SetHeight(12)
    local label = reset:CreateFontString(nil, "ARTWORK", "ObjectiveTrackerLineFont")
    label:SetPoint("RIGHT", reset, "RIGHT", 0, 0)
    label:SetText(_G["RESET"] or "Reset")
    label:SetTextColor(unpack(ns.TEXT_DIM))
    reset:SetWidth((label:GetStringWidth() or 40) + 4)
    reset:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    reset:SetScript("OnEnter", function() label:SetTextColor(1, 1, 1) end)
    reset:SetScript("OnLeave", function() label:SetTextColor(unpack(ns.TEXT_DIM)) end)
    reset:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    reset:SetScript("OnClick", function(_, button)
        if button ~= "RightButton" then return GPS:SetStart(nil) end
        if f.ShowMenu then f.ShowMenu() end
    end)
    row.reset = reset
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(_, button)
        if button ~= "RightButton" then return GPS:PickStart(f) end
        if f.ShowMenu then f.ShowMenu() end
    end)
    row.from = true
    row:SetScript("OnEnter", function(self)
        Look.HoverLine(self, true)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["GPS_FROM_TT"], 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        Look.HoverLine(self, false)
        GameTooltip_Hide()
    end)
    f.fromLine = row
    return row
end

-- Where a drop leaves the section: its slot in the tracker, or its side of the Era watch.
local function SaveDockSlot(slot)
    local db = DB()
    if not (db and slot) then return end
    if Watch() then db.gpsWatchSlot = slot else db.gpsDockSlot = slot end
end

-- The section's look: the Era watch's, ClassicUI's restyled tracker's or
-- the game's; floating, the window style picked.
SectionLook = function(f)
    local host = Host()
    if f.docked then
        if host == "era" or host == "classic" or host == "questie" then return host end
        return "game"
    end
    if PopoutStyle() == "era" then return "era" end
    return host == "classic" and "classic" or "game"
end

-- ClassicUI's tracker sizes: 12 a header, 11 a title, 10 a line, each up by
-- what the game's Text Size adds to its line font past 12.
Look.FONT = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
function Look.ClassicSize(base)
    local font = _G.ObjectiveTrackerLineFont
    if not font then return base end
    local _, h = font:GetFont()
    if type(h) ~= "number" or (issecretvalue and issecretvalue(h)) then return base end
    return base + mmax(0, mfloor(h + 0.5) - 12)
end

-- The floating window's text scale (its setting); nil docked, or as made.
local function PopoutTextScale(f)
    if f.docked then return nil end
    local db = DB()
    local s = db and db.gpsPopoutText
    return type(s) == "number" and s ~= 1 and s or nil
end

function Look.LineH(scale)
    return scale and mfloor(Look.LINE * scale + 0.5) or Look.LINE
end

-- Questie's tracker as it draws (`/efd questielook`, in its frame's units):
-- the game's font, the zone line 12 at 10 in, a quest title 10 at 61 (its icons before it),
-- objectives 10 at 71, a title's row 17 tall, lines 3 apart.
-- Its quest icon: about 9 across, centered 28 left of its fold button's middle.
Look.Q = { HEAD = 17, ZONE_X = 10, TITLE_X = 61, LINE_X = 71, GAP = 3,
           TRACK_SCALE = 0.45, ICON_DX = 28,
           ZONE = { 0.85, 0.85, 0.85 }, TITLE = { 1, 1, 0 }, k = 1 }

-- Questie's units in the section's: its frame may be scaled apart.
function Look.QuestieScale(f)
    local q = Look.QuestieTracker()
    local s = f:GetEffectiveScale()
    return q and s > 0 and q:GetEffectiveScale() / s or 1
end

function Look.Restyle(fs, look, base, object, scale)
    local key = scale and look .. scale or look
    if look == "questie" then key = key .. Look.Q.k end
    if fs.look == key then return end
    fs.look = key
    if look == "questie" then
        fs:SetFont(Look.FONT, mfloor((base >= 12 and 12 or 10) * (scale or 1) * Look.Q.k + 0.5), "")
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    elseif look == "classic" then
        fs:SetFont(Look.FONT, mfloor(Look.ClassicSize(base) * (scale or 1) + 0.5), "")
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    elseif scale then
        local font = _G[object]
        local file, h, flags
        if font and font.GetFont then file, h, flags = font:GetFont() end
        if type(h) ~= "number" or (issecretvalue and issecretvalue(h)) then h = base + 2 end
        fs:SetFont(file or Look.FONT, mfloor(h * scale + 0.5), flags or "")
    else
        fs:SetFontObject(object)
    end
end

-- ClassicUI's fold button: its sheet's module open and shut, each pushed.
Look.FOLD_SHEET = "Interface\\Buttons\\QuestTrackerButtons"
Look.FOLD_OPEN, Look.FOLD_OPEN_DOWN = { 0.273438, 0.390625, 0.265625, 0.484375 }, { 0.273438, 0.390625, 0.015625, 0.234375 }
Look.FOLD_SHUT, Look.FOLD_SHUT_DOWN = { 0.40625, 0.523438, 0.265625, 0.484375 }, { 0.40625, 0.523438, 0.015625, 0.234375 }
-- The game's fold: 11.0's tracker art, or on Classic Era and Anniversary,
-- which lack it, their watch frame's hide button (the sheet's top half shut).
Look.HIDE_SHEET = "Interface\\Buttons\\UI-Panel-QuestHideButton"
Look.HIDE_OPEN, Look.HIDE_OPEN_DOWN = { 0, 0.5, 0.5, 1 }, { 0.5, 1, 0.5, 1 }
Look.HIDE_SHUT, Look.HIDE_SHUT_DOWN = { 0, 0.5, 0, 0.5 }, { 0.5, 1, 0, 0.5 }
function Look.GameFold(fold, open)
    if GAME_ART.tracker then
        if fold.ClearPushedTexture then fold:ClearPushedTexture() end
        fold:SetNormalAtlas(open and "UI-QuestTrackerButton-Secondary-Collapse" or "UI-QuestTrackerButton-Secondary-Expand")
        return
    end
    fold:SetNormalTexture(Look.HIDE_SHEET)
    fold:SetPushedTexture(Look.HIDE_SHEET)
    fold:GetNormalTexture():SetTexCoord(unpack(open and Look.HIDE_OPEN or Look.HIDE_SHUT))
    fold:GetPushedTexture():SetTexCoord(unpack(open and Look.HIDE_OPEN_DOWN or Look.HIDE_SHUT_DOWN))
end
function Look.FoldHighlight(fold, look)
    if look == "questie" then
        fold:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    elseif GAME_ART.tracker then
        fold:SetHighlightAtlas("UI-QuestTrackerButton-Yellow-Highlight")
    else
        fold:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    end
    local hl = fold:GetHighlightTexture()
    if hl then hl:SetBlendMode("ADD") end
end

function Look.FoldArt(fold, look, open)
    if fold.lit ~= look then
        fold.lit = look
        Look.FoldHighlight(fold, look)
    end
    if look == "classic" then
        fold:SetNormalTexture(Look.FOLD_SHEET)
        fold:SetPushedTexture(Look.FOLD_SHEET)
        fold:GetNormalTexture():SetTexCoord(unpack(open and Look.FOLD_OPEN or Look.FOLD_SHUT))
        fold:GetPushedTexture():SetTexCoord(unpack(open and Look.FOLD_OPEN_DOWN or Look.FOLD_SHUT_DOWN))
        fold:SetSize(15, 14)
    elseif look == "questie" then
        -- The classic quest log's +/- where Questie's quests have their button.
        local name = open and "Minus" or "Plus"
        fold:SetNormalTexture("Interface\\Buttons\\UI-" .. name .. "Button-Up")
        fold:SetPushedTexture("Interface\\Buttons\\UI-" .. name .. "Button-Down")
        fold:GetNormalTexture():SetTexCoord(0, 1, 0, 1)
        fold:GetPushedTexture():SetTexCoord(0, 1, 0, 1)
        local size = mfloor(14 * Look.Q.k + 0.5)
        fold:SetSize(size, size)
    else
        Look.GameFold(fold, open)
        fold:SetSize(16, 15)
    end
end

-- The list's group headers dressed for where it sits: snapped in or
-- floating, as the tracker's own section headers in that look; in the
-- window, the theme's buttons. Beside the map, the map's own.
GPS.hitSkins = {}
function GPS.HitSkin(frame)
    if frame.mapFont then return nil end
    local skins = GPS.hitSkins
    if frame.isPopout then
        local gen = ns.uiThemeGeneration or 0
        if not (skins.theme and skins.theme.gen == gen) then skins.theme = GPS.ThemeSkin(gen) end
        return skins.theme
    end
    local look = frame.look or "game"
    skins[look] = skins[look] or GPS.TrackerSkin(look)
    return skins[look]
end

function GPS.TrackerSkin(look)
    local plate = look == "game" and GAME_ART.tracker
    local skin = {}
    function skin.paint(hdr)
        local bg, hover = hdr.bg, hdr.hoverOverlay
        hdr.fill:Hide()
        bg:ClearAllPoints()
        hover:ClearAllPoints()
        hover:SetAllPoints()
        hover:SetBlendMode("ADD")
        if plate then
            bg:SetAtlas("UI-QuestTracker-Secondary-Objective-Header", false)
            bg:SetAllPoints()
            bg:Show()
            hover:SetAtlas("UI-QuestTracker-Secondary-Objective-Header", false)
            hover:SetAlpha(0.35)
        else
            bg:Hide()
            hover:SetColorTexture(1, 1, 1, 0.06)
            hover:SetAlpha(1)
        end
        local t = hdr.toggleBtn
        t:SetSize(16, 16)
        if look == "classic" then t.icon:SetSize(15, 14) else t.icon:SetSize(16, 15) end
        if GAME_ART.tracker and look ~= "classic" then
            t:SetHighlightAtlas("UI-QuestTrackerButton-Yellow-Highlight")
        else
            t:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
        end
        local hl = t:GetHighlightTexture()
        if hl then hl:SetBlendMode("ADD") end
    end
    function skin.toggle(icon, collapsed)
        if look == "classic" then
            icon:SetTexture(Look.FOLD_SHEET)
            icon:SetTexCoord(unpack(collapsed and Look.FOLD_SHUT or Look.FOLD_OPEN))
        elseif GAME_ART.tracker then
            icon:SetAtlas(collapsed and "UI-QuestTrackerButton-Secondary-Expand" or "UI-QuestTrackerButton-Secondary-Collapse")
        else
            icon:SetTexture(Look.HIDE_SHEET)
            icon:SetTexCoord(unpack(collapsed and Look.HIDE_SHUT or Look.HIDE_OPEN))
        end
    end
    function skin.color(_, hover)
        if hover then return 1, 1, 1 end
        return 1, 0.82, 0
    end
    function skin.setFont(fs, scale)
        if scale == 1 then scale = nil end
        Look.Restyle(fs, look, 12, "ObjectiveTrackerHeaderFont", scale)
    end
    return skin
end

-- In the window: under the Classic skin the 1.x red panel button, gold
-- text and its +/- buttons; on the other themes a rounded button in the
-- window's field well (dark inset, the theme's line as its ring) that
-- lifts to the button fill under the mouse. The toggle lights apart from
-- the row: a disc behind its glyph, the glyph full.
function GPS.ThemeSkin(gen)
    local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
    local red = ns.ClassicLook and ns.ClassicLook()
    local palette = ns.ACTIVE_UI_PALETTE
    local line = palette and palette.separator or { 0.42, 0.42, 0.42 }
    local ring = palette and palette.borderColor or { line[1], line[2], line[3], 0.7 }
    local rest = theme and theme.toggleNormalAlpha or 0.6
    local skin = { gen = gen }
    local function Face(hdr)
        local face = hdr.efFace
        if face then return face end
        -- The well under the label: the label and toggle ride above its inset.
        face = CreateFrame("Frame", nil, hdr)
        face:SetAllPoints()
        face:SetFrameLevel(hdr:GetFrameLevel())
        ns.CreateRingedWell(face, 6)
        local text = CreateFrame("Frame", nil, hdr)
        text:SetAllPoints()
        text:SetFrameLevel(face:GetFrameLevel() + 2)
        hdr.label:SetParent(text)
        hdr.toggleBtn:SetFrameLevel(face:GetFrameLevel() + 3)
        hdr.efFace = face
        return face
    end
    function skin.paint(hdr)
        hdr.bg:Hide()
        hdr.fill:Hide()
        hdr.hoverOverlay:Hide()
        local t = hdr.toggleBtn
        t:SetSize(20, 20)
        t.icon:SetSize(red and 16 or 14, red and 16 or 14)
        if red then
            if hdr.efFace then hdr.efFace:Hide() end
            ns.PaintRedButton(hdr, ns.BTN_FILL_NORMAL)
            t:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
            t.icon:SetAlpha(1)
        else
            if hdr._efRed then for _, tex in pairs(hdr._efRed) do tex:Hide() end end
            Face(hdr):Show()
            ns.PaintRingedWell(hdr.efFace, ring, ns.EDITBOX_INSET_FILL)
            if t.ClearHighlightTexture then t:ClearHighlightTexture() end
            t.btnBg:SetTexture(ns.PORTRAIT_ALPHA_MASK)
            local f = ns.BTN_FILL_HOVER
            t.btnBg:SetVertexColor(f[1], f[2], f[3], 1)
            t.icon:SetAlpha(rest)
        end
        hdr.label:SetShadowColor(0, 0, 0, red and 1 or 0)
    end
    function skin.hover(hdr, on)
        if red then
            ns.PaintRedButton(hdr, on and ns.BTN_FILL_HOVER or ns.BTN_FILL_NORMAL)
        else
            ns.PaintRingedWell(hdr.efFace, ring, on and ns.BTN_FILL_NORMAL or ns.EDITBOX_INSET_FILL)
        end
    end
    function skin.toggleHover(btn, on)
        if red then return end
        btn.btnBg:SetShown(on)
        btn.icon:SetAlpha(on and 1 or rest)
    end
    function skin.toggle(icon, collapsed)
        if red and theme then
            icon:SetTexture(collapsed and theme.expandIcon or theme.collapseIcon)
        else
            ns.SetQuestLogToggle(icon, collapsed, theme)
        end
    end
    function skin.color(_, hover)
        if red then
            if hover then return 1, 1, 1 end
            return 1, 0.82, 0
        end
        local c = theme and (hover and theme.pathColorHover or theme.pathColor) or ns.GOLD_COLOR
        return c[1], c[2], c[3]
    end
    return skin
end

-- The widgets of one look shown, the other's hidden.
function Look.Apply(f, look, scale)
    if f.look == look and f.textScale == scale then return end
    f.look, f.textScale = look, scale
    local era = look == "era"
    f.head:SetShown(not era)
    f.plate:SetShown(look == "game")
    f.eraTitle:SetShown(era)
    f.eraGrip:SetShown(era)
    f.searchAnchor:ClearAllPoints()
    f.hitList:ClearAllPoints()
    if era then
        f.title:Hide()
        f.titleBtn:Hide()
        f.track:Hide()
        for i = 1, #f.lines do f.lines[i]:Hide() end
        for i = 1, #(f.tipLines or {}) do f.tipLines[i]:Hide() end
        if f.fromLine then f.fromLine:Hide() end
        f.searchAnchor:SetPoint("LEFT", f.eraTitle, "RIGHT", 4, 0)
        f.hitList:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(Look.LineH(scale) + 4))
        f.hitList:SetPoint("RIGHT", f, "RIGHT", 0, 0)
        return
    end
    for i = 1, #f.eraLines do f.eraLines[i]:Hide() end
    -- In Questie's look: the header as its zone line, the title as a quest's.
    local q = look == "questie" and Look.Q or nil
    local headH = q and mfloor(q.HEAD * q.k + 0.5) or DOCK_HEADER_H
    f.head:SetHeight(headH)
    f.grip:SetHeight(headH)
    -- The header is all grip there; the fold sits left of the title (RenderDock).
    f.grip:ClearAllPoints()
    f.grip:SetPoint("TOPLEFT", f.head, "TOPLEFT", 0, 0)
    if q then
        f.grip:SetPoint("RIGHT", f.head, "RIGHT", 0, 0)
    else
        f.fold:ClearAllPoints()
        f.fold:SetPoint("RIGHT", f.head, "RIGHT", 1, 0)
        f.grip:SetPoint("RIGHT", f.fold, "LEFT", -4, 0)
    end
    f.header:ClearAllPoints()
    f.header:SetPoint("LEFT", f.head, "LEFT", q and q.ZONE_X * q.k or 7, 0)
    f.searchAnchor:SetPoint("LEFT", f.header, "RIGHT", -2, 0)
    f.hitList:SetPoint("TOPLEFT", f, "TOPLEFT", DOCK_INDENT, -(headH + 4))
    f.hitList:SetPoint("RIGHT", f.head, "RIGHT", 0, 0)
    Look.Restyle(f.header, look, 12, "ObjectiveTrackerHeaderFont", scale)
    f.header:SetTextColor(unpack(q and q.ZONE or ns.GOLD_COLOR))
    Look.Restyle(f.title, look, 11, "ObjectiveTrackerLineFont", scale)
    f.titleColor = q and q.TITLE or ns.GOLD_COLOR
    f.title:SetTextColor(unpack(f.titleColor))
end

-- A line laid as the Era watch lays one: on one line, or wrapped at its width.
function Look.EraFill(fs, text, line)
    line = line or Look.LINE
    fs:SetWidth(0)
    fs:SetText(text)
    local w = fs:GetStringWidth() or 0
    if w <= Look.W then
        fs:SetSize(w, line)
        return w, line
    end
    fs:SetWidth(Look.W)
    local h = mmax(line, fs:GetStringHeight() or line)
    fs:SetHeight(h)
    return Look.W, h
end

function Look.EraLine(f, i)
    local row = f.eraLines[i]
    if row then return row end
    row = CreateFrame("Button", nil, f)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetIndentedWordWrap(true)
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if self.index and not (self.tip or self.from) then GPS.ShowStepMenu(f, self.index)
            elseif f.ShowMenu then f.ShowMenu() end
        elseif self.tip then
            TipClick(self)
        elseif self.from then
            GPS:PickStart(f)
        elseif self.index and IsShiftKeyDown() then
            GPS.GoToStep(self.index)
        elseif self.index then
            GPS.ShowStep(self.index)
        end
    end)
    row:SetScript("OnEnter", function(self)
        Look.HoverLine(self, true)
        if self.tip then TipEnter(self) end
    end)
    row:SetScript("OnLeave", function(self)
        Look.HoverLine(self, false)
        GameTooltip_Hide()
    end)
    -- A teleport's icon just past the line's end.
    row.cast = CastButton(row, 18)
    row.cast:SetSize(16, 16)
    f.eraLines[i] = row
    return row
end

-- Line n of the Era block at depth tall, its text in gray c: the row, its
-- width and the depth under it.
function Look.EraRow(f, n, text, c, tall, scale, line)
    local row = Look.EraLine(f, n)
    Look.Restyle(row.text, "era", 10, "GameFontHighlight", scale)
    local w, h = Look.EraFill(row.text, " - " .. text, line)
    row.index, row.tip, row.from = nil, nil, nil
    row.shade = Look.Grey(c)
    Look.ShadeLine(row)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -tall)
    row:SetSize(mmax(1, w), h)
    row:Show()
    return row, w, tall + h
end

-- The section in the Era watch's look: the route's title as a quest's,
-- its steps as the quest's lines, the current one white.
function Look.RenderEra(f)
    local route = Route()
    SearchHint(f)
    if GPS.picking == f then route = nil end
    if f.dangerLine then f.dangerLine:Hide() end
    local scale = PopoutTextScale(f)
    local lineH = Look.LineH(scale)
    Look.Restyle(f.eraTitle, "era", 10, "GameFontHighlight", scale)
    local text = route and DestText(route) or L["APP_GPS"]
    local hits = route and f.search and (f.hitCount or 0) > 0
    -- A start picked: its line above the destination's, in the title's gold,
    -- so a route from elsewhere reads so at once; a click picks another.
    local start = route and not route.arrived and not hits and Start()
    local lead, fromW = 0, 0
    if start then
        local row = Look.EraLine(f, 1)
        Look.Restyle(row.text, "era", 10, "GameFontHighlight", scale)
        fromW, lead = Look.EraFill(row.text, sformat(L["GPS_FROM_FMT"], start.name or "?"), lineH)
        row.index, row.tip, row.from = nil, nil, true
        row.shade = Look.TITLE
        Look.ShadeLine(row)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        row:SetSize(mmax(1, fromW), lead)
        row:Show()
    end
    f.eraTitle:ClearAllPoints()
    f.eraTitle:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -lead)
    local widest, tall = Look.EraFill(f.eraTitle, text, lineH)
    widest, tall = mmax(widest, fromW), tall + lead
    if f.eraGrip:IsMouseOver() then f.eraTitle:SetTextColor(1, 1, 1) else f.eraTitle:SetTextColor(unpack(Look.TITLE)) end
    local n = start and 1 or 0
    if route and f.search then
        -- The box after the title; the places it finds take the steps' place.
        GPS.SearchRight(f, f, "RIGHT", -10)
        f.search:Show()
        f.hitList:SetShown(hits)
    end
    if hits then
        local h = f:HitViewH()
        f:SetHitView(h)
        widest = Look.W
        tall = tall + 4 + h + 4
    elseif route then
        local row, w
        local warn = GPS.DangerText(route)
        if warn then
            local line = GPS.DangerLine(f, f, "GameFontHighlight")
            Look.Restyle(line.text, "era", 10, "GameFontHighlight", scale)
            line.text:SetTextColor(unpack(GPS.DANGER_RGB))
            local lw, lh = Look.EraFill(line.text, warn, lineH)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -tall)
            line:SetSize(lw + 16, lh)
            line:Show()
            widest = mmax(widest, lw + 16)
            tall = tall + lh
        end
        local items = route.steps
        if route.arrived then
            items = { { text = GPS.ArrivedText(route) } }
        end
        local at = route.active or 1
        local tips = AdviceLines(route)
        local function EraTips(list)
            for _, tip in ipairs(list) do
                n = n + 1
                row, w, tall = Look.EraRow(f, n, tip.text, 1, tall, scale, lineH)
                row.shade, row.tip = ns.TEXT_ASIDE, tip
                Look.ShadeLine(row)
                widest = mmax(widest, w)
            end
        end
        local hideDone = DB() and DB().gpsHideDone and not route.arrived
        for i = hideDone and at or 1, #items do
            local active = at == i and not route.arrived
            n = n + 1
            row, w, tall = Look.EraRow(f, n, StepText(items[i], active), (active or route.arrived) and 1 or (i < at and 0.5 or 0.8), tall,
                                       scale, lineH)
            row.index = (not route.arrived) and i or nil
            Look.ShadeLine(row)
            widest = mmax(widest, w + (SetupCast(row.cast, items[i], active, i >= at and not route.arrived) and 20 or 0))
            EraTips(TipsAfter(tips, i, #items))
        end
        EraTips(TipsAfter(tips, nil, #items))
    elseif f.search then
        -- The search box right of the name, and the places it finds under it.
        GPS.SearchRight(f, f, "RIGHT", -10)
        f.search:Show()
        f.hitList:Show()
        local h = f:HitViewH()
        f:SetHitView(h)
        widest = Look.W
        if h > 0 then tall = tall + 4 + h + 4 end
    end
    for i = n + 1, #f.eraLines do f.eraLines[i]:Hide() end
    f:SetSize(mmax(1, widest), mmax(lineH, tall))
    PlaceDock()
end

RenderDock = function(f)
    if not (f.docked or f.floating) then return end
    local look = SectionLook(f)
    local scale = PopoutTextScale(f)
    if look == "questie" then Look.Q.k = Look.QuestieScale(f) end
    Look.Apply(f, look, scale)
    if look == "era" then return Look.RenderEra(f) end
    -- Questie's look sits as its quests do: the title and lines further in,
    -- closer together, the lines without a dash.
    local q = look == "questie" and Look.Q or nil
    local k = q and q.k or 1
    local headH = q and mfloor(q.HEAD * k + 0.5) or DOCK_HEADER_H
    local titleX = q and q.TITLE_X * k or DOCK_INDENT
    local lineX = q and q.LINE_X * k or DOCK_INDENT
    local gap = q and q.GAP * k or DOCK_LINE_GAP
    local minH = q and 10 or 12
    local dash = q and "" or (QUEST_DASH or "- ")
    local route = Route()
    local y = -(headH + (q and 0 or 8))
    local nTips = 0
    SearchHint(f)
    if GPS.picking == f then route = nil end
    if f.fromLine then f.fromLine:Hide() end
    if f.dangerLine then f.dangerLine:Hide() end
    local hits = route and f.search and (f.hitCount or 0) > 0
    if route and f.search then
        -- The box after the name in the banner; the places it finds take
        -- the steps' place.
        -- Questie's look keeps the fold by the title: the box runs to the edge.
        if q then GPS.SearchRight(f, f.head, "RIGHT", 0) else GPS.SearchRight(f, f.fold, "LEFT", -4) end
        f.search:Show()
        f.hitList:SetShown(hits)
    end
    if hits then
        f.title:Hide()
        f.titleBtn:Hide()
        f.track:Hide()
        for i = 1, #f.lines do f.lines[i]:Hide() end
        local h = f:HitViewH()
        f:SetHitView(h)
        y = -headH - (4 + h + 4)
    elseif route then
        f.title:SetText(DestText(route))
        f.title:Show()
        f.titleBtn:Show()
        local start = not route.arrived and Start()
        -- Widths are set, not anchored: a fresh line's anchors are not
        -- resolved yet when its height is read, and it would read as one line.
        local lineW = (f.head:GetWidth() or 260) - lineX
        local dbf = DB()
        f.expanded = not (dbf and dbf.gpsPopoutCollapsed)
        -- A start picked: its line above the destination's, in the title's
        -- gold, so a route from elsewhere reads so at once; a click picks another.
        if start and f.expanded ~= false then
            local line = DockFromLine(f)
            Look.Restyle(line.text, look, 11, "ObjectiveTrackerLineFont", scale)
            line.dash:SetText("")
            line.text:SetText(sformat(L["GPS_FROM_FMT"], start.name or "?"))
            line.text:SetWidth(mmax(40, lineW - (line.reset:GetWidth() or 40) - 6))
            line.shade = ns.GOLD_COLOR
            Look.ShadeLine(line)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", f, "TOPLEFT", lineX, y)
            line:SetPoint("RIGHT", f.head, "RIGHT", 0, 0)
            local h = mmax(minH, line.text:GetStringHeight() or 12)
            line:SetHeight(h)
            line:Show()
            y = y - h - gap
        end
        f.title:ClearAllPoints()
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", titleX, y)
        f.title:SetWidth((f.head:GetWidth() or 260) - titleX)
        -- The tracking toggle in the quest POI button's spot, lit while the
        -- arrow follows the route.
        f.track:ClearAllPoints()
        if q then
            -- Questie's look: the fold in its quests' button spot left of the
            -- title, the tracking toggle small in their icons' column.
            f.fold:ClearAllPoints()
            f.fold:SetPoint("TOPRIGHT", f.title, "TOPLEFT", -8 * k, 2 * k)
            f.track:SetScale(q.TRACK_SCALE * k)
            f.track:SetPoint("CENTER", f.fold, "CENTER", -q.ICON_DX * k / f.track:GetScale(), 0)
        else
            f.track:SetScale(1)
            f.track:SetPoint("TOPRIGHT", f.title, "TOPLEFT", -7, 4)
        end
        StyleTrackButton(f.track, RouteTracked())
        f.track:Show()
        y = y - (f.title:GetStringHeight() or 14) - gap
        local n = 0
        -- One fold state for the section and the window (read above), so it
        -- survives a trip through the tracker either way.
        if f.expanded == false then
            -- Folded: the header alone, as the tracker's own sections fold;
            -- in Questie's look the title stays, as a folded quest's does.
            if not q then
                f.title:Hide()
                f.titleBtn:Hide()
                f.track:Hide()
                y = -headH
            end
        else
            local warn = GPS.DangerText(route)
            if warn then
                local line = GPS.DangerLine(f, f, "ObjectiveTrackerLineFont")
                Look.Restyle(line.text, look, 10, "ObjectiveTrackerLineFont", scale)
                line.text:SetTextColor(unpack(GPS.DANGER_RGB))
                line.text:SetWidth(mmax(40, lineW - 16))
                line.text:SetText(warn)
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", f, "TOPLEFT", lineX, y)
                line:SetPoint("RIGHT", f.head, "RIGHT", 0, 0)
                local h = mmax(minH, line.text:GetStringHeight() or 12)
                line:SetHeight(h)
                line:Show()
                y = y - h - gap
            end
            -- Arrived: one line with the announcement in the steps' place.
            local items = route.steps
            if route.arrived then
                items = { { text = GPS.ArrivedText(route) } }
            end
            local tips = AdviceLines(route)
            local function DockTips(list)
                for _, tip in ipairs(list) do
                    nTips = nTips + 1
                    local row = DockTipLine(f, nTips)
                    Look.Restyle(row.text, look, 10, "ObjectiveTrackerLineFont", scale)
                    Look.Restyle(row.dash, look, 10, "ObjectiveTrackerLineFont", scale)
                    row.dash:SetText(dash)
                    row.tip = tip
                    row.text:SetText(tip.text)
                    row.text:SetWidth(mmax(40, lineW - (row.dash:GetStringWidth() or 8)))
                    row.shade = ns.TEXT_ASIDE
                    Look.ShadeLine(row)
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", f, "TOPLEFT", lineX, y)
                    row:SetPoint("RIGHT", f.head, "RIGHT", 0, 0)
                    local h = mmax(minH, row.text:GetStringHeight() or 12)
                    row:SetHeight(h)
                    row:Show()
                    y = y - h - gap
                end
            end
            local hideDone = DB() and DB().gpsHideDone and not route.arrived
            for i = hideDone and (route.active or 1) or 1, #items do
                n = n + 1
                local row = DockLine(f, n)
                Look.Restyle(row.text, look, 10, "ObjectiveTrackerLineFont", scale)
                Look.Restyle(row.dash, look, 10, "ObjectiveTrackerLineFont", scale)
                row.dash:SetText(dash)
                row.index = (not route.arrived) and i or nil
                row.text:SetText(StepText(items[i], (route.active or 1) == i and not route.arrived))
                local cast = SetupCast(row.cast, items[i], (route.active or 1) == i and not route.arrived,
                                       i >= (route.active or 1) and not route.arrived)
                row.text:SetWidth(mmax(40, lineW - (row.dash:GetStringWidth() or 8) - (cast and 24 or 0)))
                local active = (route.active or 1) == i and not route.arrived
                local done = i < (route.active or 1)
                row.shade = Look.Grey((active or route.arrived) and 1 or (done and 0.5 or 0.8))
                Look.ShadeLine(row)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", f, "TOPLEFT", lineX, y)
                row:SetPoint("RIGHT", f.head, "RIGHT", 0, 0)   -- the section's visual width
                local h = mmax(minH, row.text:GetStringHeight() or 12)
                row:SetHeight(h)
                row:Show()
                y = y - h - gap
                DockTips(TipsAfter(tips, i, #items))
            end
            DockTips(TipsAfter(tips, nil, #items))
        end
        for i = n + 1, #f.lines do f.lines[i]:Hide() end
        y = y + gap   -- no gap after the last line
    else
        f.title:Hide()
        f.titleBtn:Hide()
        f.track:Hide()
        for i = 1, #f.lines do f.lines[i]:Hide() end
        if f.search then
            -- The search box, and the places it finds, in the steps' place.
            GPS.SearchRight(f, f, "RIGHT", -10)
            f.search:Show()
            f.hitList:Show()
            local h = f:HitViewH()
            f:SetHitView(h)
            y = -headH - (h > 0 and (4 + h + 4) or 0)
        end
    end
    for t = nTips + 1, #(f.tipLines or {}) do f.tipLines[t]:Hide() end
    -- Nothing to fold without a route.
    -- In Questie's look the fold rides on the title.
    f.fold:SetShown(route ~= nil and (not q or f.title:IsShown()))
    Look.FoldArt(f.fold, look, f.expanded ~= false)
    f:SetHeight(mmax(headH, -y))
    PlaceDock()   -- the room in the tracker follows the height
end

-- A short log of the section's drag, dock and float steps, read back by
-- the dev probe when a drag goes wrong.
local dragLog = {}
local function DLog(fmt, ...)
    local ok, line = pcall(sformat, fmt, ...)
    dragLog[#dragLog + 1] = sformat("%.1f %s", GetTime and GetTime() or 0, ok and line or tostring(fmt))
    if #dragLog > 40 then table.remove(dragLog, 1) end
end

local function RectOf(r)
    if not (r and r.GetLeft and r:GetLeft()) then return "no rect" end
    return sformat("l %.0f t %.0f r %.0f b %.0f", r:GetLeft(), r:GetTop(), r:GetRight(), r:GetBottom())
end

local function FrameState(r)
    if not r then return "nil" end
    return sformat("shown %s visible %s alpha %.1f %s/%d mouse %s movable %s %s",
        tostring(r:IsShown()), tostring(r:IsVisible()), r:GetAlpha() or 1, tostring(r:GetFrameStrata()), r:GetFrameLevel() or 0,
        tostring(r.IsMouseEnabled and r:IsMouseEnabled()), tostring(r.IsMovable and r:IsMovable()), RectOf(r))
end

-- Everything about the section a drag depends on, plus the log.
function GPS.DragProbe()
    local out = {}
    local d = dockFrame
    if not d then out[1] = "no section built" return out end
    out[#out + 1] = "section: " .. FrameState(d)
    out[#out + 1] = sformat("flags: docked %s floating %s dragging %s ghost %s expanded %s parent %s",
        tostring(d.docked == true), tostring(d.floating == true), tostring(d.dragging == true), tostring(d.ghost == true),
        tostring(d.expanded), d:GetParent() and d:GetParent():GetName() or "?")
    out[#out + 1] = "head: " .. FrameState(d.head)
    out[#out + 1] = "grip: " .. FrameState(d.grip)
    out[#out + 1] = "fold: " .. FrameState(d.fold)
    if popoutFrame then
        out[#out + 1] = sformat("window: %s ghosting %s", FrameState(popoutFrame), tostring(popoutFrame.ghosting == true))
    end
    local t = Tracker()
    if t then out[#out + 1] = "tracker: " .. FrameState(t) end
    for i = 1, #dragLog do out[#out + 1] = "log " .. dragLog[i] end
    return out
end

-- A GPS window on the game windows' layer: raised when it opens or is
-- clicked, so it covers the bars and a bag opened after it covers it.
function GPS.RaiseLikeAWindow(window)
    local function Lift()
        if window.docked then return end
        window:Raise()
        -- Cast buttons hang from UIParent: back over their rows.
        if InCombatLockdown and InCombatLockdown() then return end
        for i = 1, #castButtons do
            local btn = castButtons[i]
            if btn:IsShown() and btn.row:IsVisible() then btn:SetFrameLevel(btn.row:GetFrameLevel() + 3) end
        end
    end
    local function Clicked()
        local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
        for i = 1, #foci do
            local f, depth = foci[i], 0
            while f and depth < 8 and not f:IsForbidden() do
                if f == window then return Lift() end
                f, depth = f:GetParent(), depth + 1
            end
        end
    end
    local catch = CreateFrame("Frame", nil, window)
    catch:SetScript("OnShow", function(self)
        Lift()
        Utils.RegisterEventIfValid(self, "GLOBAL_MOUSE_DOWN")
    end)
    catch:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
    catch:SetScript("OnEvent", Clicked)
    if window:IsVisible() then Utils.RegisterEventIfValid(catch, "GLOBAL_MOUSE_DOWN") end
    window.Lift = Lift
end

local function BuildDock()
    local f = CreateFrame("Frame", "EasyFindGPSDock", UIParent)
    f:SetSize(260, DOCK_HEADER_H)
    f:SetFrameStrata("LOW")
    f:SetFrameLevel(5)
    GPS.RaiseLikeAWindow(f)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f.lines = {}

    -- Header as the tracker's sections: 260-pixel strip, secondary header art centered
    -- at native size, text 7 from the left, fold button at its right.
    local head = CreateFrame("Frame", nil, f)
    head:SetSize(260, DOCK_HEADER_H)
    head:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.head = head
    local bg = head:CreateTexture(nil, "BACKGROUND")
    -- Classic Era and Anniversary lack the art; their watch frame has no plate either.
    if GAME_ART.tracker then bg:SetAtlas("UI-QuestTracker-Secondary-Objective-Header", true) end
    bg:SetPoint("CENTER", head, "CENTER", 0, 0)
    f.plate = bg

    local header = head:CreateFontString(nil, "ARTWORK", "ObjectiveTrackerHeaderFont")
    header:SetPoint("LEFT", head, "LEFT", 7, 0)
    header:SetJustifyV("MIDDLE")
    header:SetText(L["APP_GPS"])
    header:SetTextColor(1, 0.82, 0)
    f.header = header
    -- The tag rides the name's top right corner, above the search box's
    -- magnifier that follows the name.
    local exp = ns.CreateFeatureTag(head, "exp", L["TAG_EXP_TITLE"], L["GPS_EXP_TT"], true)
    exp:SetPoint("BOTTOMLEFT", header, "LEFT", (header:GetStringWidth() or 0) - 7, 7)

    -- The fold button as the tracker's own section headers place theirs.
    local fold = CreateFrame("Button", nil, head)
    fold:SetSize(16, 16)
    fold:SetPoint("RIGHT", head, "RIGHT", 1, 0)
    if GAME_ART.tracker then
        fold:SetNormalAtlas("UI-QuestTrackerButton-Secondary-Collapse")
        fold:SetPushedAtlas("UI-QuestTrackerButton-Secondary-Collapse-Pressed")
        fold:SetHighlightAtlas("UI-QuestTrackerButton-Yellow-Highlight")
    else
        Look.GameFold(fold, true)
        fold:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    end
    if fold:GetHighlightTexture() then fold:GetHighlightTexture():SetBlendMode("ADD") end
    fold:SetScript("OnClick", function()
        local db = DB()
        if db then db.gpsPopoutCollapsed = (f.expanded ~= false) or nil end
        if popoutFrame and popoutFrame.SyncFold then popoutFrame:SyncFold() end
        RenderDock(f)
    end)
    f.fold = fold

    -- The header is the handle: drag to move among the sections or out
    -- of the tracker; right-click for the route's actions.
    local grip = CreateFrame("Button", nil, head)
    grip:SetPoint("TOPLEFT", head, "TOPLEFT", 0, 0)
    grip:SetPoint("RIGHT", fold, "LEFT", -4, 0)
    grip:SetHeight(DOCK_HEADER_H)
    grip:RegisterForClicks("RightButtonUp")
    grip:RegisterForDrag("LeftButton")
    local function Report(ok, err)
        if not ok and EasyFind.Print then EasyFind:Print("GPS drag: " .. tostring(err)) end
    end
    f.grip = grip
    local function DragStart()
        Report(pcall(function()
        DLog("drag start: docked %s floating %s %s", tostring(f.docked == true), tostring(f.floating == true), RectOf(f))
        HideMenus()
        if not f:IsMovable() then f:SetMovable(true) end
        -- Its width came from the tracker's edges; keep a size of its own
        -- for the ride, and ride above the tracker.
        local w, h = f:GetWidth() or 260, f:GetHeight() or DOCK_HEADER_H
        local left, top = f:GetLeft(), f:GetTop()
        f.dragging = true
        f:ClearAllPoints()
        f:SetSize(w, h)
        if left and top then f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top) end
        f:SetFrameStrata("HIGH")
        f:StartMoving()
        DragGap(f, h)
        end))
    end
    local function DragStop()
        -- Once per drop: the handler must not run again from inside itself.
        if f.stopping then return end
        f.stopping = true
        Report(pcall(function()
        f:StopMovingOrSizing()
        f.dragging = nil
        f:SetFrameStrata("LOW")
        local near = NearTracker(f)
        local slot = near and SlotAt(f:GetTop() or 0) or nil
        local left, top = f:GetLeft(), f:GetTop()
        DLog("drag stop: near %s style %s docked %s floating %s at %s,%s", tostring(near), tostring(PopoutStyle()),
             tostring(f.docked == true), tostring(f.floating == true), tostring(left), tostring(top))
        DragGap(nil)
        HideWindowGhost(f)
        if near and f.floating then
            -- A floating section dropped on the tracker docks there.
            GPS:Dock(slot)
            DLog("-> docked: %s", FrameState(f))
        elseif near then
            SaveDockSlot(slot)
            PlaceDock()
            DLog("-> placed: %s", FrameState(f))
        elseif PopoutStyle() ~= "easyfind" then
            -- Stays a section, floating where it was dropped, never hidden
            -- on the way (see Undock).
            GPS:Undock(true)
            GPS.FloatDockAt(left, top)
            DLog("-> floating: %s", FrameState(f))
        else
            GPS:Undock(true)
            f.floating = nil
            GPS:TogglePopout(true)
            -- The section leaves on the next frame, never inside its own
            -- drag-stop handler.
            f:SetAlpha(0)
            Utils.SafeAfter(0, function()
                if not (f.docked or f.floating or f.dragging) then f:Hide() end
                f:SetAlpha(1)
            end)
            DLog("-> window: %s", FrameState(popoutFrame))
            if popoutFrame and left and top then
                popoutFrame:ClearAllPoints()
                popoutFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
                local db = DB()
                if db then db.gpsPopout = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = left, y = top } end
            end
        end
        end))
        f.stopping = nil
    end
    grip:SetScript("OnDragStart", DragStart)
    grip:SetScript("OnDragStop", DragStop)
    -- The menu anchors at the cursor, not the header: a click anywhere on
    -- the header then closes it, and the header keeps its drag.
    local menuAnchor = CreateFrame("Frame", nil, f)
    menuAnchor:SetSize(1, 1)
    -- The section's options: on the game's own menu, as the tracker's
    -- sections have theirs; the styled popup only if that is missing.
    local function ShowDockMenu(defs)
            defs = defs or GPS.MenuRows(f)
            if ShowGameMenu(f, defs) then return end
            if not ns.ShowTogglePopup then return end
            local cx, cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            menuAnchor:ClearAllPoints()
            menuAnchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
            ns.ShowTogglePopup("EasyFindGPSDockMenu", menuAnchor, defs, {})
    end
    f.ShowMenu = ShowDockMenu
    grip:SetScript("OnClick", function(self, button)
        if button == "RightButton" then ShowDockMenu() end
    end)

    -- The Era watch's look: the title line, as a quest's, is the handle; a
    -- click opens the map's GPS page.
    local eraTitle = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    eraTitle:SetJustifyH("LEFT")
    eraTitle:SetJustifyV("TOP")
    eraTitle:SetIndentedWordWrap(true)
    eraTitle:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    eraTitle:Hide()
    f.eraTitle = eraTitle
    f.eraLines = {}
    local eraGrip = CreateFrame("Button", nil, f)
    eraGrip:SetAllPoints(eraTitle)
    eraGrip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    eraGrip:RegisterForDrag("LeftButton")
    eraGrip:SetScript("OnDragStart", DragStart)
    eraGrip:SetScript("OnDragStop", DragStop)
    eraGrip:SetScript("OnClick", function(_, button)
        if button == "RightButton" then ShowDockMenu() elseif Route() then GPS:Open() end
    end)
    eraGrip:SetScript("OnEnter", function() eraTitle:SetTextColor(1, 1, 1) end)
    eraGrip:SetScript("OnLeave", function() eraTitle:SetTextColor(unpack(Look.TITLE)) end)
    eraGrip:Hide()
    f.eraGrip = eraGrip

    local title = f:CreateFontString(nil, "ARTWORK", "ObjectiveTrackerLineFont")
    title:SetJustifyH("LEFT")
    title:SetWordWrap(true)
    title:SetTextColor(1, 0.82, 0)
    f.title = title
    -- The destination line opens the map's GPS page and lights up under the
    -- cursor, as a quest header does; a right-click, the section's options.
    -- Steps keep their own click.
    local titleBtn = CreateFrame("Button", nil, f)
    titleBtn:SetAllPoints(title)
    titleBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    titleBtn:SetScript("OnEnter", function() title:SetTextColor(1, 1, 1) end)
    titleBtn:SetScript("OnLeave", function() title:SetTextColor(unpack(f.titleColor or ns.GOLD_COLOR)) end)
    titleBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then ShowDockMenu() else GPS:Open() end
    end)
    titleBtn:Hide()
    f.titleBtn = titleBtn
    -- With no route, a search box in the banner right of the name, from the
    -- same builder as the window's folded row. Its finds list below.
    local searchAnchor = CreateFrame("Frame", nil, f)
    searchAnchor:SetSize(1, 20)
    searchAnchor:SetPoint("LEFT", header, "RIGHT", -2, 0)
    f.searchAnchor = searchAnchor
    BuildSearch(f, searchAnchor, 10, 8)
    f.search:SetFrameLevel(head:GetFrameLevel() + 5)   -- above the header's grip
    -- Dressed for the banner: shorter, no inset chrome or field, just the
    -- magnifier, a gray hint and the typed text in gold.
    do
        local box = f.search
        box:SetHeight(16)
        for _, key in ipairs({ "Left", "Middle", "Right" }) do
            if box[key] then box[key]:SetAlpha(0) end
        end
        box:SetTextColor(1, 1, 1, 1)
        box:SetFontObject("ObjectiveTrackerLineFont")
        if box.Instructions then
            box.Instructions:SetFontObject("ObjectiveTrackerLineFont")
            box.Instructions:SetTextColor(0.6, 0.6, 0.6, 1)
        end
        if box.searchIcon then
            -- The template hangs its magnifier low for a taller box; center
            -- it on this one.
            box.searchIcon:SetVertexColor(0.7, 0.7, 0.7, 0.9)
            box.searchIcon:ClearAllPoints()
            box.searchIcon:SetPoint("LEFT", box, "LEFT", 2, 0)
        end
        -- A right-click on the box opens the section's options, as on the
        -- header beside it.
        box:HookScript("OnMouseUp", function(_, button)
            if button == "RightButton" and f.ShowMenu then f.ShowMenu() end
        end)
    end
    f.hitList:ClearAllPoints()
    f.hitList:SetPoint("TOPLEFT", f, "TOPLEFT", DOCK_INDENT, -(DOCK_HEADER_H + 4))
    f.hitList:SetPoint("RIGHT", head, "RIGHT", 0, 0)
    f.OnRouteChanged = function(self) RenderDock(self) end

    -- Tracking toggle where a quest's POI button sits: in the 20-pixel indent
    -- left of the title, a little outside the section's left edge.
    local track = BuildTrackButton(f)
    track:SetPoint("TOPRIGHT", title, "TOPLEFT", -7, 4)
    f.track = track
    -- The arrow can move to a quest from the tracker's own buttons.
    Utils.RegisterEventIfValid(f, "SUPER_TRACKING_CHANGED")
    f:SetScript("OnEvent", function(self) if self.docked or self.floating then RenderDock(self) end end)

    -- Follow the tracker's own relayouts, and check on a light throttle
    -- for anything that moves without one.
    local t = ClientTracker()
    if t and not GPS.trackerHooked then
        GPS.trackerHooked = true
        pcall(hooksecurefunc, t, "Update", function() PlaceDock() end)
    end
    local since = 0
    f:SetScript("OnUpdate", function(self, dt)
        since = since + dt
        if self.dragging then
            -- The button up with no drag stop delivered: the drag is over.
            if not IsMouseButtonDown("LeftButton") then
                self.dragLost = (self.dragLost or 0) + 1
                DragStop()
                return
            end
            if since < 0.05 then return end
            since = 0
            if NearTracker(self) then
                if popoutFrame and popoutFrame.ghosting then HideWindowGhost(self) end
                DragGap(self, self:GetHeight() or DOCK_HEADER_H)
            else
                DragGap(nil)
                if PopoutStyle() == "easyfind" and GPS.EnsurePopout and not (popoutFrame and popoutFrame.ghosting) then
                    GPS.EnsurePopout()
                    popoutFrame.ghosting = true
                    ShowWindowGhost(self)
                end
            end
            return
        end
        if since < 0.25 then return end
        since = 0
        PlaceDock()
    end)

    -- The time on the destination line; the section is laid out again
    -- only when the line grows or shrinks.
    f.SetEta = function(self, route)
        if not (route and self:IsShown()) or GPS.picking == self then return end
        local text = DestText(route)
        if self.look == "era" then
            if self.eraTitle:GetText() ~= text then RenderDock(self) end
        elseif self.title:IsShown() then
            local h = self.title:GetStringHeight()
            self.title:SetText(text)
            if self.title:GetStringHeight() ~= h then RenderDock(self) end
        end
    end
    f.Render = RenderDock
    surfaces[#surfaces + 1] = f
    f:Hide()
    return f
end

function GPS:IsDocked()
    local db = DB()
    return db and db.gpsDocked == true
end

-- Whether the route shows anywhere on screen already: the window, the
-- floating section, or the section in the tracker.
function GPS:IsWindowOpen()
    if popoutFrame and popoutFrame:IsShown() then return true end
    if dockFrame and dockFrame:IsShown() and (dockFrame.docked or dockFrame.floating) then return true end
    return false
end

-- The section as a window of its own, at a spot or at the saved one.
function GPS.FloatDockAt(left, top)
    dockFrame = dockFrame or BuildDock()
    if not dockFrame then return end
    dockFrame.docked = nil
    dockFrame.floating = true
    dockFrame:SetFrameStrata("MEDIUM")
    -- A section's width, floating or not.
    local t = ClientTracker()
    local ref = t and t.modules and t.modules[1]
    local w = ref and ref.GetWidth and ref:GetWidth() or 0
    dockFrame:SetWidth(w > 0 and w or 260)
    dockFrame:ClearAllPoints()
    local db = DB()
    if not (left and top) then
        local pos = db and db.gpsPopout
        if pos and pos.point == "TOPLEFT" then left, top = pos.x, pos.y end
    end
    if left and top then
        dockFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        if db then db.gpsPopout = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = left, y = top } end
    else
        dockFrame:SetPoint("TOPRIGHT", UIParent, "RIGHT", -40, 200)
    end
    dockFrame:SetAlpha(1)
    dockFrame:Show()
    dockFrame.Lift()
    -- A grip the game stopped drawing (shown, yet not visible under a
    -- visible header) comes back with a hide and show.
    if dockFrame.grip and dockFrame.head and dockFrame.head:IsVisible() and not dockFrame.grip:IsVisible() then
        dockFrame.grip:Hide()
        dockFrame.grip:Show()
    end
    RenderDock(dockFrame)
    local c = CharDB()
    if c then c.popoutOpen = true end
end

local MENU_CHECK = "Interface\\Buttons\\UI-CheckBox-Check"

-- A setting's picks as flyout rows: choices { { value, key }, ... }, the
-- one in use ticked (a radio on the game's own menu).
local TEXT_SIZES = { { 0.85, "OPT_FONT_SMALL" }, { 1, "GPS_SIZE_NORMAL" }, { 1.2, "OPT_FONT_LARGE" }, { 1.4, "OPT_FONT_XL" } }

local function PickRows(choices, current, pick)
    local rows = {}
    for i = 1, #choices do
        local value, key = choices[i][1], choices[i][2]
        local on = current == value
        rows[i] = { text = L[key], icon = on and MENU_CHECK or nil, picked = on,
                    onClick = function() pick(value) end }
    end
    return rows
end

function GPS.PicksMenu(label, choices, current, pick)
    return { kind = "submenu", label = label, rows = PickRows(choices, current, pick) }
end

-- A check row inside a flyout: ticked while on; a click leaves it open.
local function CheckFlyoutRow(d)
    return { text = d.label, tooltip = d.tooltip, keepOpen = true, check = d,
             icon = d.get() and MENU_CHECK or nil, onClick = function() d.set(not d.get()) end }
end
GPS.CheckFlyoutRow = CheckFlyoutRow   -- the arrow box's flyout (WorldPin)

-- Learning flight paths on the way and the advice lines under the route;
-- under a line, which steps the list shows (the next alone: the window's).
function GPS.PlanningMenu(f)
    -- Listed on each open: a click redraws the flyout with its checks.
    local function avoid()
        local out = {}
        for _, kind in ipairs(GPS.AvoidKinds()) do out[#out + 1] = CheckFlyoutRow(GPS.AvoidRow(kind)) end
        return out
    end
    return { kind = "submenu", label = L["GPS_PLANNING"], rows = function()
        local rows = { CheckFlyoutRow(GPS.AutoLearnRow()), CheckFlyoutRow(GPS.DetoursRow()),
                       CheckFlyoutRow(GPS.OtherWaysRow()), { text = L["GPS_AVOID"], submenu = avoid },
                       { isSeparator = true }, CheckFlyoutRow(GPS.HideDoneRow()) }
        if f and f.isPopout then rows[#rows + 1] = CheckFlyoutRow(GPS.NextOnlyRow()) end
        return rows
    end }
end

-- A theme with frame art of its own (Classic, Forever): the pop-out's
-- border is that art or the quest log's paper, by its own choice.
function GPS.ThemeHasChrome()
    local p = ns.ACTIVE_UI_PALETTE
    return p ~= nil and (p.chrome == "classic" or p.chrome == "forever")
end

-- The pop-out's rim: "iron" (the theme's frame art, only where it has
-- one), "quest" (the quest log's paper), "line" (the search bar's) or
-- "off". The theme's own art by default; an older "border off" is the line.
-- The quest log's paper, where the client has it; never round a light
-- theme's window, its dark art a frame the theme does not wear.
function GPS.QuestRimOffered()
    if not GAME_ART.questRim then return false end
    local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
    return not (theme and theme.lightTheme)
end

function GPS.PopoutRim()
    local db = DB()
    local rim = db and db.gpsPopoutRim
    if rim == "off" then return rim end
    if rim == nil and db and db.gpsPopoutBorder == false then rim = "line" end
    if rim ~= "quest" and rim ~= "line" then rim = "iron" end
    if rim == "iron" and not GPS.ThemeHasChrome() then rim = "quest" end
    if rim == "quest" and not GPS.QuestRimOffered() then rim = "line" end
    return rim
end

-- The style flyout for the cog popup and the section's menu; border: the
-- window's border row, under the looks.
function GPS.StyleMenu(border)
    local function pick(style)
        return function()
            local db = DB()
            if not db or PopoutStyle() == style then return end
            HideMenus()
            -- Swap the open window for the other look at the same spot.
            local open, left, top = false, nil, nil
            if popoutFrame and popoutFrame:IsShown() then open, left, top = true, popoutFrame:GetLeft(), popoutFrame:GetTop() end
            if dockFrame and dockFrame.floating and dockFrame:IsShown() then open, left, top = true, dockFrame:GetLeft(), dockFrame:GetTop() end
            db.gpsPopoutStyle = style
            if open then
                if popoutFrame then popoutFrame:Hide() end
                if dockFrame and dockFrame.floating then dockFrame.floating = nil dockFrame:Hide() end
                GPS:TogglePopout(true)
                if left and top then
                    local f = (style ~= "easyfind") and dockFrame or popoutFrame
                    if f then
                        f:ClearAllPoints()
                        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
                        db.gpsPopout = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = left, y = top }
                    end
                end
            end
        end
    end
    local looks = { { "easyfind", "GPS_STYLE_EASYFIND" }, { "tracker", "GPS_STYLE_TRACKER" }, { "era", "GPS_STYLE_ERA" } }
    return { kind = "submenu", label = L["GPS_STYLE"], rows = function()
        local rows = PickRows(looks, PopoutStyle(), function(style) pick(style)() end)
        local db = DB()
        rows[#rows + 1] = { text = L["GPS_POPOUT_TEXT"], submenu = PickRows(TEXT_SIZES, db and db.gpsPopoutText or 1, function(v)
            if not db then return end
            db.gpsPopoutText = (v ~= 1) and v or nil
            HideMenus()
            Refresh()
        end) }
        if border then
            rows[#rows + 1] = { isSeparator = true }
            local rims = { { "line", "GPS_BORDER_LINE" } }
            if GPS.QuestRimOffered() then table.insert(rims, 1, { "quest", "GPS_BORDER_QUEST" }) end
            if GPS.ThemeHasChrome() then table.insert(rims, 1, { "iron", "GPS_BORDER_IRON" }) end
            local function setRim(rim)
                local d = DB()
                if not d then return end
                d.gpsPopoutRim, d.gpsPopoutBorder = rim, nil
                HideMenus()
                if popoutFrame then
                    popoutFrame:ApplyBorderShape()
                    popoutFrame:Render()
                end
            end
            local rim = GPS.PopoutRim()
            -- One border to have: on or off. More: a pick, Off among them.
            if #rims == 1 then
                rows[#rows + 1] = { text = border.label, icon = rim ~= "off" and MENU_CHECK or nil, picked = rim ~= "off",
                    onClick = function() setRim(rim == "off" and "line" or "off") end }
            else
                local picks = PickRows(rims, rim, setRim)
                local off = PickRows({ { "off", "GPS_BORDER_OFF" } }, rim, setRim)[1]
                off.text = _G["OFF"] or off.text
                table.insert(picks, off)
                rows[#rows + 1] = { text = border.label, submenu = picks }
            end
        end
        return rows
    end }
end

GPS.PlaceDock = PlaceDock

function GPS:Dock(slot)
    if not (Tracker() or Watch()) then return false end
    HideMenus()
    dockFrame = dockFrame or BuildDock()
    local db = DB()
    if db then db.gpsDocked = true end
    SaveDockSlot(slot)
    if popoutFrame then popoutFrame:Hide() end
    dockFrame.docked = true
    dockFrame.floating = nil
    dockFrame:Show()
    RenderDock(dockFrame)
    PlaceDock()
    return true
end

-- The tracker not up yet (Questie's shows a moment after a reload) or gone
-- (hidden, emptied): the section waits for one and snaps in when it shows.
-- The window opens meanwhile, after the grace, and leaves for the tracker
-- on its return. The wait ends with the window closed or snapping off.
local HOST_GRACE = 5
function GPS.AwaitHost(grace)
    if GPS.hostWait then return end
    local started = GetTime()
    GPS.hostWait = C_Timer.NewTicker(0.5, function()
        local db, c = DB(), CharDB()
        local wanted = db and db.gpsDocked and not db.gpsNeverDock and not (c and c.popoutOpen == false)
        if not wanted or (dockFrame and dockFrame.docked) then return GPS.StopAwaitingHost() end
        if dockFrame and dockFrame.dragging then return end
        if Tracker() or Watch() then
            GPS.StopAwaitingHost()
            if GPS:Dock() then
                if c then c.popoutOpen = true end
                GPS.ShowWhileFolded()
            end
        elseif not GPS:IsWindowOpen() and GetTime() - started >= grace then
            GPS:TogglePopout(true)
            db.gpsDocked = true
        end
    end)
end

function GPS.StopAwaitingHost()
    if GPS.hostWait then
        GPS.hostWait:Cancel()
        GPS.hostWait = nil
    end
end

-- The window as it was left: snapped into the tracker when it was there
-- (and there is one), else the window at its last spot. atLogin: the
-- tracker may be a moment away, so the window waits for it too.
function GPS:OpenWindow(atLogin)
    local db = DB()
    local snap = db and db.gpsDocked and not db.gpsNeverDock
    if snap and GPS:Dock() then
        local c = CharDB()
        if c then c.popoutOpen = true end
        GPS.ShowWhileFolded()
        return
    end
    if snap then
        GPS.AwaitHost(atLogin and HOST_GRACE or 0)
        if atLogin then return end
    end
    GPS:TogglePopout(true)
    if snap then db.gpsDocked = true end
end

-- Opened or routed to with the tracker folded: the section shows on its
-- own until the player folds the tracker again.
function GPS.ShowWhileFolded()
    local t = Tracker()
    if not (dockFrame and dockFrame.docked and t and t.IsCollapsed and t:IsCollapsed()) then return end
    dockFrame.showFolded, dockFrame.wasFolded = true, true
    PlaceDock()
end

-- A route started from a search row: a window on screen stays where it
-- is, snapped in or floating; else it opens as it was left.
function GPS:ShowWindow()
    if self:IsWindowOpen() then GPS.ShowWhileFolded() else self:OpenWindow() end
end

-- Closed where it is: a snapped-in section snaps back in on the next open.
function GPS:CloseWindow()
    if dockFrame and dockFrame.docked and dockFrame:IsShown() then
        GPS:Undock()
        local db = DB()
        if db then db.gpsDocked = true end
    else
        GPS:TogglePopout(false)
    end
    local c = CharDB()
    if c then c.popoutOpen = false end
end

-- keepShown: the section stays on screen (about to float, or being dragged).
-- Hiding a frame in its own drag-stop re-fires the handler and kills its grip until reload.
function GPS:Undock(keepShown)
    HideMenus()
    local db = DB()
    if db then db.gpsDocked = nil end
    if dockFrame then
        dockFrame.docked = nil
        dockFrame.ghost = nil
        if not keepShown then dockFrame:Hide() end
        dockFrame:SetFrameStrata("LOW")
        ClearInsert()   -- the Era watch closes ranks, now
    end
end

-- Section and tracker geometry for the dev readout.
function GPS.DockStatus()
    local out = {}
    if dockFrame then
        local d = dockFrame
        local ins = d.insert
        out[#out + 1] = sformat("section: shown %s alpha %.1f strata %s | docked %s floating %s ghost %s dragging %s (stops missed %d, stopping %s, gap %s) | size %.0fx%.0f | room on %s height %s pad %s",
            tostring(d:IsShown()), d:GetAlpha() or 1, tostring(d:GetFrameStrata()), tostring(d.docked == true), tostring(d.floating == true),
            tostring(d.ghost == true), tostring(d.dragging == true), d.dragLost or 0, tostring(d.stopping == true), tostring(d.dragGap ~= nil),
            d:GetWidth() or 0, d:GetHeight() or 0,
            ins and (ins.side and ("watch " .. ins.side) or ins.module and (ins.module:GetName() or "?")) or "none",
            tostring(ins and ins.height), tostring(ins and ins.pad))
        local watch = Watch()
        out[#out + 1] = sformat("host %s look %s | watch %s", tostring((Host())), tostring(d.look),
            watch and FrameState(watch) or "none")
        local t = Tracker()
        if t then
            local mods = VisibleModules(t)
            local parts = {}
            for i = 1, #mods do
                local m = mods[i]
                parts[#parts + 1] = sformat("%s top %.0f bottom %.0f w %.0f", m:GetName() or "?", m:GetTop() or 0, m:GetBottom() or 0, m:GetWidth() or 0)
            end
            out[#out + 1] = sformat("tracker: %s | section top %s bottom %s", table.concat(parts, "; "), tostring(d:GetTop() and math.floor(d:GetTop())), tostring(d:GetBottom() and math.floor(d:GetBottom())))
        end
    end
    return out
end

-- The pop-out

PopoutSize = function()
    local db = DB()
    local size = db and db.gpsPopoutSize or {}
    return size.w or 300, size.h
end

local function SetPopoutSize(w, h)
    local db = DB()
    if not db then return end
    db.gpsPopoutSize = { w = w, h = h }
    if popoutFrame then
        popoutFrame:SetWidth(w)
        popoutFrame.scrollOffset = 0
        popoutFrame:Render()
    end
end

-- One menu for every surface (the section, snapped in or floating, and
-- the window): the route's actions, the settings, then the window's look.
function GPS.MenuRows(f)
    local defs = {}
    local route = Route()
    if f.docked then
        defs[#defs + 1] = { kind = "action", label = L["GPS_POPOUT"], onClick = function() GPS:Undock() GPS:TogglePopout(true) end }
        -- Closing the section ends the route with it.
        defs[#defs + 1] = { kind = "action", label = L["GPS_CLOSE_SECTION"], onClick = function()
            GPS:Clear()
            GPS:CloseWindow()
        end }
    elseif f.mapFont then
        defs[#defs + 1] = { kind = "action", label = L["GPS_POPOUT"], onClick = function() GPS:OpenWindow() end }
    else
        defs[#defs + 1] = { kind = "action", label = L["GPS_CLOSE"], onClick = function() GPS:TogglePopout(false) end }
    end
    if route then defs[#defs + 1] = { kind = "action", label = L["GPS_CLEAR"], onClick = function() GPS:Clear() end } end
    -- The trip's fields have a start field only with a route.
    if route or not f.trip then
        defs[#defs + 1] = { kind = "action", label = L["GPS_FROM_PICK"], onClick = function() GPS:PickStart(f) end }
    end
    if route and not route.arrived then
        defs[#defs + 1] = { kind = "action", label = L["GPS_ALONG"], onClick = function() GPS:SearchAlong(f) end }
    end
    -- The Era look has no tracking button beside the title.
    if f.look == "era" and route then
        defs[#defs + 1] = { kind = "action", label = RouteTracked() and L["GPS_TRACK_OFF"] or L["GPS_TRACK_ON"],
            onClick = ToggleRouteTracking }
    end
    -- The route as a link another EasyFind user clicks to be routed there too.
    local share = route and ns.ResultLinks and ns.ResultLinks.BuildRouteText
        and ns.ResultLinks:BuildRouteText(route.dest)
    local sendRows = share and ns.BuildSendLinkRows and ns.BuildSendLinkRows(share)
    if route then defs[#defs + 1] = { kind = "action", label = L["GPS_REPORT"], onClick = function() GPS:ReportRoute() end } end
    -- A section's flyouts come after its rows, on every surface alike.
    if sendRows then defs[#defs + 1] = { kind = "submenu", label = L["CTX_SEND_LINK"], rows = sendRows } end
    -- The search's Show buckets, the map tab's own, so the box finds what
    -- the tab would; under a line, the list's choices and the beacon.
    if ns.MapTab and ns.MapTab.FilterRows then
        local buckets = ns.MapTab.FilterRows(GPS.RefreshSearches)
        defs[#defs + 1] = { kind = "submenu", label = _G["SHOW"] or "Show", rows = function()
            local rows = buckets()
            rows[#rows + 1] = { isSeparator = true }
            if f.search then
                for _, which in ipairs({ "recent", "parents", "expand" }) do
                    rows[#rows + 1] = CheckFlyoutRow(GPS.ListChoiceRow(f, which))
                end
            end
            rows[#rows + 1] = CheckFlyoutRow(GPS.WorldPinRow())
            return rows
        end }
    end
    defs[#defs + 1] = { kind = "separator" }
    defs[#defs + 1] = GPS.ArrowRow()
    defs[#defs + 1] = GPS.ArrowResetRow()
    defs[#defs + 1] = GPS.SnapRow()
    defs[#defs + 1] = GPS.LaunchRow()
    defs[#defs + 1] = GPS.PlanningMenu(f)
    -- Snapped in, the section has one look; the map's page wears the map's.
    if f.docked or f.mapFont then return defs end
    defs[#defs + 1] = GPS.StyleMenu(f.isPopout and { label = L["GPS_SIZE_BORDER"] } or nil)
    if not f.isPopout then return defs end
    local width, height = PopoutSize()
    defs[#defs + 1] = GPS.PicksMenu(L["GPS_SIZE_WIDTH"], SIZE_WIDTHS, width,
        function(px) SetPopoutSize(px, (select(2, PopoutSize()))) end)
    defs[#defs + 1] = GPS.PicksMenu(L["GPS_SIZE_HEIGHT"], SIZE_HEIGHTS, height,
        function(px) SetPopoutSize((select(1, PopoutSize())), px) end)
    return defs
end

local function BuildPopout()
    local f = CreateFrame("Frame", "EasyFindGPSPopout", UIParent, "BackdropTemplate")
    f.isPopout = true
    -- Its Classic frame at a window's full weight.
    f._efClassicStyle = "window"
    f:SetSize((PopoutSize()), 120)
    f:SetFrameStrata("MEDIUM")
    GPS.RaiseLikeAWindow(f)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    local function BeginWindowDrag(self)
        self.dragging = true
        self:StartMoving()
        if Tracker() or Watch() then dockFrame = dockFrame or BuildDock() end
    end
    local function EndWindowDrag(self)
        self:StopMovingOrSizing()
        self.dragging = nil
        local near = (Tracker() or Watch()) and NearTracker(self)
        local slot = near and SlotAt(self:GetTop() or 0) or nil
        DragGap(nil)
        HideSectionGhost(self)
        -- Dropped on the objective tracker: it docks at the spot it was dropped.
        if near and GPS:Dock(slot) then return end
        -- Kept by its top-left corner, so a height change grows or
        -- shrinks the bottom edge and the header stays put.
        local left, top = self:GetLeft(), self:GetTop()
        if left and top then
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            local db = DB()
            if db then db.gpsPopout = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = left, y = top } end
        end
    end
    f:SetScript("OnDragStart", BeginWindowDrag)
    f:SetScript("OnDragStop", EndWindowDrag)
    f.BeginWindowDrag, f.EndWindowDrag = BeginWindowDrag, EndWindowDrag
    -- The results window's own panel object: rounded rect, theme fill,
    -- opacity setting, live restyle on a theme flip.
    ns.StyleMenuPanel(f)
    ns.SetRoundedRectBarHeight(f, 14)
    -- The quest log's border, as around the map search panel, where the
    -- client has it. The template anchors itself a few pixels outside its
    -- parent; decorative only.
    local border = GAME_ART.questRim and CreateFrame("Frame", nil, f, "QuestLogBorderFrameTemplate") or nil
    if border then
        border:SetFrameLevel(f:GetFrameLevel() + 2)
        border:EnableMouse(false)
        -- The template hangs 7 pixels above and 6 below its parent, made for
        -- the quest log's paper. Here it hugs the panel: 3 pixels all round.
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", f, "TOPLEFT", -4, 4)
        border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 4, -4)
    end
    -- Nine-slice instead of the template's one stretched atlas (squashed on a short
    -- window). A thin band: the rim only, the atlas's inner shadow read as a dark strip.
    local BAND = 8
    local info = border and GetAtlasInfo("questlog-frame")
    if info and info.file and info.width and info.height and border.Border then
        border.Border:Hide()
        local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
        local du, dv = (r - l) * BAND / info.width, (b - t) * BAND / info.height
        local function piece(u0, u1, v0, v1)
            local tex = border:CreateTexture(nil, "BORDER")
            tex:SetTexture(info.file)
            tex:SetTexCoord(l + u0 * (r - l), l + u1 * (r - l), t + v0 * (b - t), t + v1 * (b - t))
            return tex
        end
        local cu, cv = du / (r - l), dv / (b - t)   -- the band as a fraction of the atlas
        local tl, tr, bl, br = piece(0, cu, 0, cv), piece(1 - cu, 1, 0, cv), piece(0, cu, 1 - cv, 1), piece(1 - cu, 1, 1 - cv, 1)
        local top, bottom = piece(cu, 1 - cu, 0, cv), piece(cu, 1 - cu, 1 - cv, 1)
        local left, right = piece(0, cu, cv, 1 - cv), piece(1 - cu, 1, cv, 1 - cv)
        for _, c in ipairs({ tl, tr, bl, br }) do c:SetSize(BAND, BAND) end
        tl:SetPoint("TOPLEFT"); tr:SetPoint("TOPRIGHT"); bl:SetPoint("BOTTOMLEFT"); br:SetPoint("BOTTOMRIGHT")
        top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
        bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
        left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
        right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    end
    f.border = border
    -- With the square quest-log border the fill is square too (1-pixel corner):
    -- rounded corners curve away from its straight edges.
    -- on: the rim at all, a plain theme's switch. A theme with frame art of
    -- its own is the rim there, unless the quest rim is picked instead.
    -- The rim by GPS.PopoutRim: the theme's own frame art (iron, whatever
    -- the frame art switch says elsewhere), the quest log's paper, or the
    -- line the search bar wears; square corners under art, rounded with
    -- the line alone.
    function f:ApplyBorderShape()
        local rim = GPS.PopoutRim()
        self._efSkinOff = (rim ~= "iron") or nil
        self._efSkinForced = (rim == "iron") or nil
        local dressed = ns.ApplySkin ~= nil and ns.ApplySkin(self)
        local paper = rim == "quest"
        if self.border then self.border:SetShown(paper) end
        if ns.SetRoundedRectRingShown then ns.SetRoundedRectRingShown(self, rim ~= "off") end
        ns.SetRoundedRectBarHeight(self, (paper or dressed) and 2 or 14)
    end
    f:ApplyBorderShape()
    -- The theme's frame art comes and goes with the theme.
    ns.RegisterThemeCallback(function()
        f:ApplyBorderShape()
        if f.glyphTex then f.glyphTex:SetVertexColor(unpack(ns.ChromeGlyphColor())) end
        -- The text follows the fill: lifted over a talent tree, dark on a light theme.
        GPS.RepaintInk(f)
        Refresh()
    end)

    -- The calculator's stroke close, not a stock round button. The header's
    -- buttons are small, a click a little round each.
    local BTN, BTN_GAP = 14, 18
    local close = ns.CreateCloseX(f, 13)
    close:SetSize(BTN, BTN)
    close:SetHitRectInsets(-3, -3, -3, -3)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -10)
    close:SetScript("OnClick", function() GPS:TogglePopout(false) end)
    f.closeBtn = close

    -- Header top padding: 9 open, 8 in one tight row. The rest of the
    -- header hangs off the glyph and the close. above: the buttons in a
    -- strip of their own over the trip's fields, the settings cog at its
    -- left end; else centered on the folded title row, the cog left out.
    f.headStrip = 11
    local STRIP_TOP = 6
    function f:SetHeaderPad(pad, above)
        self.glyph:ClearAllPoints()
        -- The tracking face's art spills past its frame: it sits 4 px further out.
        self.glyph:SetPoint("TOPLEFT", self, "TOPLEFT", self.track and 4 or 8, -(pad + (above and self.headStrip or 0)))
        close:ClearAllPoints()
        if above then
            close:SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -STRIP_TOP)
        else
            -- On the header row: the trip's one field, else the folded title.
            local row = self.trip and self.trip:IsShown() and self.trip.rows[1]
            local h = row and row:GetHeight() or self.glyph:GetHeight()
            close:SetPoint("RIGHT", self, "TOPRIGHT", -8, -(pad + h / 2))
        end
        if self.headCog then
            self.headCog:ClearAllPoints()
            self.headCog:SetPoint("LEFT", self, "TOPLEFT", 6, -(STRIP_TOP + BTN / 2))
            self.headCog:SetShown(above and GPS.CogsShown())
        end
    end

    -- Left of the close: maximize, back to the GPS page on the map. A
    -- square outline in the close's stroke style.
    local maximize = CreateFrame("Button", nil, f)
    maximize:SetSize(BTN, BTN)
    maximize:SetHitRectInsets(-3, -3, -3, -3)
    maximize:SetPoint("CENTER", close, "CENTER", -BTN_GAP, 0)
    local edges = {}
    local function edge(w, h, point, x, y)
        local tex = maximize:CreateTexture(nil, "OVERLAY")
        tex:SetTexture("Interface\\Buttons\\WHITE8x8")
        tex:SetSize(w, h)
        tex:SetPoint(point, maximize, "CENTER", x, y)
        edges[#edges + 1] = tex
    end
    edge(9, 1.5, "TOP", 0, 4.5)
    edge(9, 1.5, "BOTTOM", 0, -4.5)
    edge(1.5, 9, "LEFT", -4.5, 0)
    edge(1.5, 9, "RIGHT", 4.5, 0)
    local function tintMax(r, g, b)
        for i = 1, #edges do edges[i]:SetVertexColor(r, g, b, 1) end
    end
    GPS.Inked(f, function(ink) tintMax(unpack(ink.dim)) end)
    maximize:SetScript("OnEnter", function() tintMax(unpack(GPS.Ink(f).hover)) end)
    maximize:SetScript("OnLeave", function() tintMax(unpack(GPS.Ink(f).dim)) end)
    maximize:SetScript("OnClick", function()
        if ns.MapTab and ns.MapTab.ShowPage then ns.MapTab:ShowPage("gps") end
    end)
    f.maximize = maximize

    -- Then minimize: the window folds to its title line and back. One
    -- stroke when open, a plus when folded.
    local collapse = CreateFrame("Button", nil, f)
    collapse:SetSize(BTN, BTN)
    collapse:SetHitRectInsets(-3, -3, -3, -3)
    collapse:SetPoint("CENTER", maximize, "CENTER", -BTN_GAP, 0)
    local bar = collapse:CreateTexture(nil, "OVERLAY")
    bar:SetTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetSize(9, 1.5)
    bar:SetPoint("CENTER")
    local post = collapse:CreateTexture(nil, "OVERLAY")
    post:SetTexture("Interface\\Buttons\\WHITE8x8")
    post:SetSize(1.5, 9)
    post:SetPoint("CENTER")
    local function tintFold(r, g, b)
        bar:SetVertexColor(r, g, b, 1)
        post:SetVertexColor(r, g, b, 1)
    end
    GPS.Inked(f, function(ink) tintFold(unpack(ink.dim)) end)
    collapse:SetScript("OnEnter", function() tintFold(unpack(GPS.Ink(f).hover)) end)
    collapse:SetScript("OnLeave", function() tintFold(unpack(GPS.Ink(f).dim)) end)
    collapse:SetScript("OnClick", function()
        f.collapsed = not f.collapsed or nil
        local db = DB()
        if db then db.gpsPopoutCollapsed = f.collapsed end
        post:SetShown(f.collapsed == true)
        f:Render()
    end)
    local db1 = DB()
    f.collapsed = db1 and db1.gpsPopoutCollapsed or nil
    post:SetShown(f.collapsed == true)
    f.collapseBtn = collapse
    -- The header's buttons are glyphs only: each says what it does.
    local function Tip(btn, text)
        btn:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(text(), 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:HookScript("OnLeave", GameTooltip_Hide)
    end
    Tip(maximize, function() return L["GPS_TO_MAP_PAGE"] end)
    Tip(collapse, function() return f.collapsed and L["GPS_UNFOLD"] or L["GPS_FOLD"] end)
    Tip(close, function() return L["GPS_CLOSE"] end)
    -- The saved fold state, shared with the tracker section.
    f.SyncFold = function(self)
        local db = DB()
        self.collapsed = db and db.gpsPopoutCollapsed or nil
        post:SetShown(self.collapsed == true)
    end

    -- Settings on a right-click anywhere on the window, the menu at the cursor;
    -- no cog in the header.
    local ShowWindowMenu = CursorMenu(f, "EasyFindGPSWindowMenu")
    f:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then ShowWindowMenu() end
    end)
    f.ShowMenu = ShowWindowMenu
    -- The settings cog over the trip's fields: the window's menu, as a right-click.
    f.headCog = GPS.SettingsCog(f, ShowWindowMenu)
    if f.headCog then
        f.headCog:SetSize(12, 13)
        GPS.CogHover(f.headCog, f)
    end

    BuildSurface(f, {
        padX = 12, padY = 9, padRight = 64, bodyPadRight = 12, search = true, compact = true, titleOpensMap = true,
        onRouteChanged = function(self)
            -- The fold button folds a route; with none there is nothing to fold.
            if self.collapseBtn then self.collapseBtn:SetShown(Route() ~= nil) end
            local hits = self.search ~= nil and (self.hitCount or 0) > 0
            local folded = self.collapsed == true and Route() ~= nil
            local bare = self.fieldsHidden and Route() ~= nil and not folded
            if self.trip then
                ns.GPSTrip.Fold(self, folded)
                if bare then self.trip:Hide() end
            end
            if self.fieldsBtn then
                self.fieldsBtn:SetShown(Route() ~= nil and not folded)
                self.fieldsBtn:Point(not bare)
            end
            -- The header row: the trip's fields while they show (one pixel
            -- hidden, the time line then at the top), else the icon.
            local headRow = (self.trip and (self.trip:IsShown() or bare)) and self.trip:GetHeight() or 20
            -- The buttons' own strip over a route's fields; with none, or
            -- folded, they share the one header row (typing keeps it so).
            local above = Route() ~= nil and not folded
            local strip = above and self.headStrip or 0
            local tight = (not Route() and not hits and not GPS.planning) or folded
            if tight then
                -- One tight title row: a folded route, or no route, where the row
                -- holds the search box and typed results unfold below.
                -- The one "where to" field: 8 round its box, not round its
                -- row, which is taller by the gap between fields.
                local gap = 0
                local field = not Route() and self.trip and self.trip:IsShown() and self.trip.rows[1]
                if field and field.box then gap = mmax(0, (field:GetHeight() - field.box:GetHeight()) / 2) end
                self:SetHeaderPad(8 - gap, above)
                self:SetHeight(8 - gap + strip + headRow + 8 - gap)
                self.list:Hide(); self.eta:Hide(); self.etaTag:Hide(); self.clearBtn:Hide(); self.empty:Hide()
                if self.search then
                    self.search:SetShown(not (Route() or GPS.planning or self.trip))
                    self.hitList:Hide()
                end
                return
            end
            self:SetHeaderPad(9, above)
            local _, fixed = PopoutSize()
            local head = 9 + strip + headRow + 8   -- pad, the buttons' strip, the header row, gap
            local line = 4 + 14 + 8   -- the time line under the name
            local h
            -- With a route, typed places take the steps' place.
            self.list:SetShown(not (Route() and hits))
            if Route() and hits then
                h = head + line + self:HitViewH() + 12
            elseif Route() then
                h = head + line + (self.contentHeight or 0) + 4   -- the last row carries its own padding
            elseif hits then
                h = head + self:HitViewH() + 12
            elseif GPS.planning then
                h = head + 2 + (self.empty:GetStringHeight() or 14) + 12   -- "Finding a way to ..."
            elseif self.search then
                h = head + 4   -- the search box alone, in the header row
            else
                h = head + 2 + (self.empty:GetStringHeight() or 24) + 14
            end
            if fixed then
                -- A fixed height: the step list, or the hits, scroll inside it.
                self:SetHeight(fixed)
                if hits then self:SetHitView(fixed - head - (Route() and line or 0) - 12) end
                local avail = fixed - (head + line + 12)
                self.list:SetHeight(mmax(1, math.min(self.contentHeight or 0, avail)))
                self.list:SetClipsChildren(true)
            else
                self:SetHeight(mmax(60, h))
                if hits then self:SetHitView(HIT_ROWS * ROW_H) end
                self.list:SetClipsChildren(false)
                self.scrollOffset = 0
            end
        end,
    })
    -- The trip's fields in the window too, as on the map page, the first
    -- its full width under the buttons' strip.
    f.buttonsAbove = true
    f.firstRowRight = 30   -- with no route, the field ends short of map and close
    if ns.GPSTrip then ns.GPSTrip.BuildEditor(f) end

    -- In Clear route's place an arrow hides the fields, the steps alone
    -- under the time line; the destination's own clear button ends a route.
    f.noClear = true
    local fields = CreateFrame("Button", nil, f)
    fields:SetSize(BTN + 2, BTN + 2)
    fields:SetHitRectInsets(-3, -3, -3, -3)
    fields:SetPoint("RIGHT", f.clearBtn, "RIGHT", 0, 0)
    local function chevron(x)
        local tex = fields:CreateTexture(nil, "OVERLAY")
        tex:SetTexture("Interface\\Buttons\\WHITE8x8")
        tex:SetSize(7, 1.5)
        tex:SetPoint("CENTER", fields, "CENTER", x, 0)
        return tex
    end
    local left, right = chevron(-2.5), chevron(2.5)
    local function tintFields(r, g, b)
        left:SetVertexColor(r, g, b, 1)
        right:SetVertexColor(r, g, b, 1)
    end
    GPS.Inked(f, function(ink) tintFields(unpack(ink.dim)) end)
    -- up: the fields show, a click hides them.
    function fields:Point(up)
        self.up = up
        left:SetRotation(up and mpi / 4 or -mpi / 4)
        right:SetRotation(up and -mpi / 4 or mpi / 4)
    end
    fields:SetScript("OnEnter", function(self)
        tintFields(unpack(GPS.Ink(f).hover))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.up and L["GPS_FIELDS_HIDE"] or L["GPS_FIELDS_SHOW"])
        GameTooltip:Show()
    end)
    fields:SetScript("OnLeave", function()
        tintFields(unpack(GPS.Ink(f).dim))
        GameTooltip_Hide()
    end)
    fields:SetScript("OnClick", function(self)
        f.fieldsHidden = not f.fieldsHidden or nil
        local db = DB()
        if db then db.gpsPopoutFieldsHidden = f.fieldsHidden end
        if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
        f:Render()
    end)
    local db2 = DB()
    f.fieldsHidden = db2 and db2.gpsPopoutFieldsHidden or nil
    fields:Point(not f.fieldsHidden)
    fields:Hide()
    f.fieldsBtn = fields
    f.clearBtn:SetWidth(fields:GetWidth())   -- the time line runs up to the arrow
    -- While the window is dragged over the tracker, the tracker opens the
    -- gap the section would take.
    local dragSince = 0
    f:SetScript("OnUpdate", function(self, dt)
        if not self.dragging then return end
        -- The button up with no drag stop delivered: the drag is over.
        if not IsMouseButtonDown("LeftButton") then
            self.dragLost = (self.dragLost or 0) + 1
            EndWindowDrag(self)
            return
        end
        dragSince = dragSince + dt
        if dragSince < 0.05 then return end
        dragSince = 0
        if NearTracker(self) then
            if dockFrame then
                ShowSectionGhost(self)
                DragGap(self, dockFrame:GetHeight() or DOCK_HEADER_H)
            end
        else
            DragGap(nil)
            HideSectionGhost(self)
        end
    end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        local _, fixed = PopoutSize()
        if not fixed or not Route() then return end
        local avail = self.list:GetHeight() or 0
        local maxOffset = mmax(0, (self.contentHeight or 0) - avail)
        self.scrollOffset = math.max(0, math.min(maxOffset, (self.scrollOffset or 0) - delta * ROW_H))
        self:Render()
    end)

    -- No Escape close: the window is a companion that stays put; only its
    -- own close button hides it.

    local db = DB()
    local pos = db and db.gpsPopout
    if pos and pos.point == "TOPLEFT" then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x or 0, pos.y or 0)
    else
        f:SetPoint("TOPRIGHT", UIParent, "RIGHT", -40, 200)
    end
    f:Hide()
    if ns.KeepTextShaded then ns.KeepTextShaded(f) end
    return f
end

function GPS.EnsurePopout()
    popoutFrame = popoutFrame or BuildPopout()
    return popoutFrame
end

function GPS:TogglePopout(show)
    HideMenus()
    if PopoutStyle() ~= "easyfind" then
        -- The window is the section, floating.
        local open = dockFrame and dockFrame.floating and dockFrame:IsShown()
        if show == nil then show = not open end
        if show then
            if GPS:IsDocked() then GPS:Undock() end
            if popoutFrame then popoutFrame:Hide() end
            GPS.FloatDockAt()
        elseif dockFrame and dockFrame.floating then
            dockFrame.floating = nil
            dockFrame:Hide()
        end
        local c = CharDB()
        if c then c.popoutOpen = show or nil end
        return
    end
    popoutFrame = popoutFrame or BuildPopout()
    if show == nil then show = not popoutFrame:IsShown() end
    if show and GPS:IsDocked() then GPS:Undock() end
    if show and dockFrame and dockFrame.floating then dockFrame.floating = nil dockFrame:Hide() end
    popoutFrame:SetShown(show)
    if show and popoutFrame.SyncFold then popoutFrame:SyncFold() end
    if show then popoutFrame:Render() end
    -- Open or closed survives a reload, like the route does.
    local c = CharDB()
    if c then c.popoutOpen = show or nil end
end

-- Login: a route saved before a reload picks up where it was

-- A hearth is learned as it happens: the cast of any bind-based ability
-- in the data, then the loading screen, then where the character stands.
local hearthSpells
local function IsHearthSpell(spellID)
    if not hearthSpells then
        hearthSpells = {}
        for _, a in ipairs(ns.GPSData and ns.GPSData.abilities or {}) do
            if a.bind and a.id then hearthSpells[a.id] = true end
        end
        hearthSpells[556] = true   -- Astral Recall lands at the bind too
    end
    return hearthSpells[spellID] == true
end
local hearthCastAt

-- Flight masters seen as known at a flight master: covers a client whose
-- world map listing cannot say.
local function RecordKnownFlights()
    local c = CharDB()
    local mapID = GetTaxiMapID and GetTaxiMapID()
    if not (c and mapID and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and Enum and Enum.FlightPathState) then return end
    local ok, list = pcall(C_TaxiMap.GetAllTaxiNodes, mapID)
    if not (ok and list) then return end
    local state = Enum.FlightPathState
    c.flights = c.flights or {}
    local here, open, learned = nil, {}, false
    for i = 1, #list do
        local n = list[i]
        if n.nodeID and (n.state == state.Current or n.state == state.Reachable) then
            if not c.flights[n.nodeID] then learned = true end
            c.flights[n.nodeID] = true
            open[n.nodeID] = true
            if n.state == state.Current then here = n.nodeID end
        end
    end
    local Engine = ns.GPSRoute
    if Engine then
        Engine.recordedKnown = c.flights
        Engine.ForgetKnown()
    end
    -- Replan from here when this master's answer differs from the plan:
    -- newly learned, or a planned flight it does not offer.
    local route = c.route
    if not (route and route.dest and not route.arrived) then return end
    local stale = learned
    for i = route.active or 1, #route.steps do
        local s = route.steps[i]
        if s.kind == "taxi" and s.nodeID == here and not (s.toID and open[s.toID]) then stale = true end
    end
    if not stale then return end
    route.via = GPS.ViaLeft(route, c.flights)
    GPS:Plan(nil, function()
        local steps, total, advice = GPS:BuildStops(route, route.via, route.wayAvoid, nil, "first")
        if not steps then
            route.via = nil
            steps, total, advice = GPS:BuildStops(route, nil, route.wayAvoid, nil, "first")
        end
        return steps, total, advice
    end, function(steps, total, advice)
        if not (steps and Route() == route) then return end
        GPS.Replanned(route, steps, total, advice)
        TrackStep(1)
        AfterRoute(true)
    end)
end

-- The GPS page in the options' Extensions tab: line colors, the beacon
-- and arrow, switches and the ways of travel to avoid.
local OptionsPage = {}
do
    OptionsPage.LINE_WAYS = { { "walk", "GPS_LINE_WALK" }, { "taxi", "GPS_AVOID_TAXI" }, { "boat", "GPS_AVOID_BOAT" },
                        { "zeppelin", "GPS_AVOID_ZEPPELIN" }, { "tram", "GPS_LINE_TRAM" } }

    function OptionsPage.LineColor(kind)
        return ns.GPSPreview and ns.GPSPreview.LineColor(kind) or ns.GOLD_COLOR
    end

    -- rgb nil: back to the theme's color.
    function OptionsPage.SetLineColor(kind, rgb)
        local db = DB()
        if not db then return end
        if rgb then
            db.gpsLineColors = db.gpsLineColors or {}
            db.gpsLineColors[kind] = rgb
        elseif db.gpsLineColors then
            db.gpsLineColors[kind] = nil
            if next(db.gpsLineColors) == nil then db.gpsLineColors = nil end
        end
        if ns.GPSPreview and ns.GPSPreview.ColorsChanged then ns.GPSPreview.ColorsChanged() end
    end

    function OptionsPage.PickLineColor(kind, after)
        if not ns.PickColor then return end
        local c = OptionsPage.LineColor(kind)
        ns.PickColor(c[1], c[2], c[3], function(r, g, b)
            OptionsPage.SetLineColor(kind, { r, g, b })
            if after then after() end
        end)
    end

    -- Danger needs the creature catalog, roads and jumps the walking grid.
    OptionsPage.AvoidKinds = GPS.AvoidKinds

    -- The page's settings as data: its controls and the search bar's rows.
    -- label is the page's own text; name the bar's, its heading in front.
    function OptionsPage.Rows()
        local WorldPin = ns.GPSWorldPin
        local Under = ns.SettingsRows.Under
        local rows = {}
        local function Add(key, label, name, control)
            rows[#rows + 1] = { key = key, label = label, name = name or label, control = control }
            rows[key] = rows[#rows]
        end
        for _, way in ipairs(OptionsPage.LINE_WAYS) do
            local kind, label = way[1], L[way[2]]
            Add("color_" .. kind, label, Under(L["GPS_LINE_COLORS"], label),
                { kind = "button", tooltip = L["GPS_LINE_COLOR_TT"], press = function() OptionsPage.PickLineColor(kind) end })
        end
        local function Choice(key, label, tooltip, choices, default, get, set)
            Add(key, label, nil, { kind = "choice", tooltip = tooltip, choices = choices, default = default, get = get, set = set })
        end
        Choice("beacon", L["GPS_BEACON_STYLE"], L["GPS_BEACON_STYLE_TT"], {
                { label = L["GPS_BEACON_CALM"], value = "calm" }, { label = L["GPS_BEACON_FLAME"], value = "flame" },
                { label = _G["OFF"] or "Off", value = "off" },
            }, WorldPin and WorldPin.DefaultStyle() or "calm",
            function()
                local db = DB()
                if db and db.gpsWorldPin == false then return "off" end
                return WorldPin and WorldPin.Style() or "calm"
            end,
            function(v)
                local db = DB()
                if not db then return end
                db.gpsWorldPin = Utils.OffOrNil(v ~= "off")
                if v ~= "off" then db.gpsBeaconStyle = v end
                Refresh()
            end)
        Choice("line", L["GPS_LINE_WIDTH"], L["GPS_LINE_WIDTH_TT"], {
                { label = L["GPS_LINE_THIN"], value = "thin" }, { label = L["GPS_SIZE_NORMAL"], value = "normal" },
                { label = L["GPS_LINE_THICK"], value = "thick" },
            }, "normal",
            function() local db = DB() return db and db.gpsLineWidth or "normal" end,
            function(v)
                local db = DB()
                if db then db.gpsLineWidth = (v ~= "normal") and v or nil end
            end)
        Choice("miniLine", L["GPS_MINIMAP_WIDTH"], L["GPS_MINIMAP_WIDTH_TT"], {
                { label = L["GPS_LINE_THIN"], value = "thin" }, { label = L["GPS_SIZE_NORMAL"], value = "normal" },
                { label = L["GPS_LINE_THICK"], value = "thick" },
            }, "normal",
            function() local db = DB() return db and db.gpsMinimapWidth or "normal" end,
            function(v)
                local db = DB()
                if db then db.gpsMinimapWidth = (v ~= "normal") and v or nil end
                Refresh()
            end)
        -- The game's own waypoint marks the step elsewhere.
        if ns.GPSMinimap and ns.GPSMinimap.OWN_MARK then
            Choice("miniDot", L["GPS_MINIMAP_DOT"], L["GPS_MINIMAP_DOT_TT"], {
                    { label = L["OPT_FONT_SMALL"], value = "small" }, { label = L["GPS_SIZE_NORMAL"], value = "normal" },
                    { label = L["OPT_FONT_LARGE"], value = "large" },
                }, "normal",
                function() local db = DB() return db and db.gpsMinimapDot or "normal" end,
                function(v)
                    local db = DB()
                    if db then db.gpsMinimapDot = (v ~= "normal") and v or nil end
                    Refresh()
                end)
        end
        Choice("click", L["GPS_MAP_CLICK"], L["GPS_MAP_CLICK_TT"], {
                { label = L["CTX_GPS"], value = "gps" }, { label = L["GPS_MAP_CLICK_PIN"], value = "pin" },
            }, "gps",
            function() local db = DB() return db and db.gpsMapClick or "gps" end,
            function(v)
                local db = DB()
                if db then db.gpsMapClick = (v ~= "gps") and v or nil end
            end)
        Choice("units", L["GPS_UNITS"], nil, {
                { label = L["GPS_UNITS_YARDS"], value = "yd" }, { label = L["GPS_UNITS_METERS"], value = "m" },
                { label = L["GPS_UNITS_BANANAS"], value = "banana" }, { label = L["GPS_UNITS_FIELDS"], value = "field" },
            }, "yd",
            function() local db = DB() return db and db.gpsUnits or "yd" end,
            function(v)
                local db = DB()
                if db then db.gpsUnits = (v ~= "yd") and v or nil end
                Refresh()
            end)
        local sizes = {}
        for i, c in ipairs(TEXT_SIZES) do sizes[i] = { label = L[c[2]], value = c[1] } end
        Choice("textSize", L["GPS_POPOUT_TEXT"], L["GPS_POPOUT_TEXT_TT"], sizes, 1,
            function() local db = DB() return db and db.gpsPopoutText or 1 end,
            function(v)
                local db = DB()
                if db then db.gpsPopoutText = (v ~= 1) and v or nil end
                Refresh()
            end)
        local function Check(key, label, tooltip, get, set, name)
            Add(key, label, name, { kind = "check", tooltip = tooltip, get = get, set = set })
        end
        Check("plateBorder", L["GPS_PLATE_BORDER"], L["GPS_PLATE_BORDER_TT"],
            function() local d = DB() return d ~= nil and d.gpsPlateBorder == true end,
            function(on)
                local d = DB()
                if d then d.gpsPlateBorder = on or nil end
                if ns.GPSWorldPin and ns.GPSWorldPin.ApplyPlateBorders then ns.GPSWorldPin.ApplyPlateBorders() end
            end)
        -- A switch stored only when off.
        local function Switch(key, label, tip, after)
            Check(key, label, tip,
                function() local d = DB() return not (d and d[key] == false) end,
                function(on)
                    local d = DB()
                    if d then d[key] = Utils.OffOrNil(on) end
                    after()
                end)
        end
        Switch("gpsArrow", L["GPS_ARROW"], L["GPS_ARROW_TT"], Refresh)
        Check("gpsArrowBox", L["GPS_PLATE_SHOWN"], L["GPS_PLATE_SHOWN_TT"], GPS.ArrowBoxShown, GPS.SetArrowBox)
        for _, line in ipairs(GPS.BOX_LINES) do
            Check(line.key, line.label, nil, function() return GPS.BoxLineShown(line.key) end,
                function(on) GPS.SetBoxLine(line.key, on) end, Under(L["GPS_PLATE_SHOWN"], line.label))
        end
        local marks = { { label = _G["NONE"] or "None", value = 0 } }
        for i = 1, 8 do
            marks[#marks + 1] = { label = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i .. ":14|t "
                .. (_G["RAID_TARGET_" .. i] or tostring(i)), value = i }
        end
        Choice("gpsTargetMark", L["GPS_TARGET_MARK"], L["GPS_TARGET_MARK_TT"], marks, 8,
            function() return ns.GPSArrow and ns.GPSArrow.TargetMark() or 8 end,
            function(v)
                local d = DB()
                if not d then return end
                if v == 8 then d.gpsTargetMark = nil else d.gpsTargetMark = v end
                Refresh()
            end)
        Switch("gpsMinimap", L["GPS_MINIMAP_LINE"], L["GPS_MINIMAP_LINE_TT"], Refresh)
        Switch("gpsClickPulse", L["GPS_CLICK_PULSE"], L["GPS_CLICK_PULSE_TT"], function() end)
        -- Danger is known only where the creature catalog says it.
        if ns.NPC_DATA and ns.NPC_DATA.danger then
            Switch("gpsDangerWarn", L["GPS_DANGER_WARN"], L["GPS_DANGER_WARN_TT"], Refresh)
            Switch("gpsDangerRed", L["GPS_DANGER_RED"], L["GPS_DANGER_RED_TT"], function()
                if ns.GPSPreview and ns.GPSPreview.ColorsChanged then ns.GPSPreview.ColorsChanged() end
            end)
        end
        Switch("gpsZoneSteps", L["GPS_ZONE_STEPS"], L["GPS_ZONE_STEPS_TT"], function()
            local route = Route()
            if route and not route.arrived then Reroute(route) end
        end)
        Switch("gpsRowButton", L["GPS_ROW_BUTTON"], L["GPS_ROW_BUTTON_TT"], function()
            if ns.Search and ns.Search.RefreshResults then ns.Search:RefreshResults() end
            if ns.MapTab and ns.MapTab.RefreshIfOpen then ns.MapTab:RefreshIfOpen() end
        end)
        Choice("gpsCog", L["GPS_COG"], L["GPS_COG_TT"], {
                { label = L["GPS_COG_HOVER"], value = "hover" }, { label = _G["SHOW"] or "Show", value = "show" },
                { label = _G["HIDE"] or "Hide", value = "hide" },
            }, "hover",
            function() return GPS.CogMode() end,
            function(v)
                local db = DB()
                if db then db.gpsCog = (v ~= "hover") and v or nil end
                GPS.ApplyCogs()
            end)
        Check("hideDone", L["GPS_HIDE_DONE"], L["GPS_HIDE_DONE_TT"],
            function() local d = DB() return d ~= nil and d.gpsHideDone == true end,
            function(on)
                local d = DB()
                if d then d.gpsHideDone = on or nil end
                Refresh()
            end)
        Check("autoClose", L["GPS_AUTO_CLOSE"], L["GPS_AUTO_CLOSE_TT"],
            function() local d = DB() return d ~= nil and d.gpsAutoClose == true end,
            function(on)
                local d = DB()
                if d then d.gpsAutoClose = on or nil end
            end)
        Check("arriveAnyFloor", L["GPS_ARRIVE_ANY_FLOOR"], L["GPS_ARRIVE_ANY_FLOOR_TT"],
            function() local d = DB() return d ~= nil and d.gpsArriveAnyFloor == true end,
            function(on)
                local d = DB()
                if d then d.gpsArriveAnyFloor = on or nil end
            end)
        for _, kind in ipairs(GPS.AvoidKinds()) do
            local d = GPS.AvoidRow(kind)
            Check("avoid_" .. kind, d.label, d.tooltip, d.get, d.set, Under(L["GPS_AVOID"], d.label))
        end
        return rows
    end

    function OptionsPage.Build(page, kit)
        local rows = OptionsPage.Rows()
        local colorRow = CreateFrame("Frame", nil, page)
        colorRow:SetSize(kit.ROW_WIDTH, 24)
        colorRow:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -6)
        local colorHead = colorRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        colorHead:SetPoint("LEFT", colorRow, "LEFT", 8, 0)
        colorHead:SetText(L["GPS_LINE_COLORS"])
        local prevRow = colorRow
        local swatches = {}
        local function PaintSwatches()
            local set = DB() and DB().gpsLineColors
            for i = 1, #swatches do
                local c = OptionsPage.LineColor(swatches[i].kind)
                swatches[i].fill:SetColorTexture(c[1], c[2], c[3], 1)
                swatches[i].revert:SetShown(set ~= nil and set[swatches[i].kind] ~= nil)
            end
        end
        local function Revert(kind)
            OptionsPage.SetLineColor(kind, nil)
            PaintSwatches()
        end
        for _, way in ipairs(OptionsPage.LINE_WAYS) do
            local kind = way[1]
            local label = rows["color_" .. kind].label
            local wrow = CreateFrame("Frame", nil, page)
            wrow:SetSize(kit.ROW_WIDTH, 22)
            wrow:SetPoint("TOPLEFT", prevRow, "BOTTOMLEFT", 0, prevRow == colorRow and -2 or 0)
            local text = wrow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", wrow, "LEFT", 8, 0)
            text:SetText(label)
            local swatch = CreateFrame("Button", nil, wrow)
            swatch:SetSize(18, 18)
            -- Its left edge on the dropdowns' left edge.
            swatch:SetPoint("LEFT", wrow, "RIGHT", -kit.BUTTON_WIDTH - 8, 0)
            swatch:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            ns.SquareOutline(swatch)
            local fill = swatch:CreateTexture(nil, "ARTWORK")
            fill:SetPoint("TOPLEFT", 1, -1)
            fill:SetPoint("BOTTOMRIGHT", -1, 1)
            swatch.fill, swatch.kind = fill, kind
            swatch.revert = ns.CreateRevertButton(wrow, 16, function() Revert(kind) end)
            swatch.revert:SetPoint("LEFT", swatch, "RIGHT", 6, 0)
            swatches[#swatches + 1] = swatch
            swatch:SetScript("OnClick", function(_, button)
                if not DB() then return end
                if button == "RightButton" then
                    Revert(kind)
                    return
                end
                OptionsPage.PickLineColor(kind, PaintSwatches)
            end)
            Utils.AttachDelayedTooltip(swatch, "ANCHOR_RIGHT", function() return label, L["GPS_LINE_COLOR_TT"] end)
            prevRow = wrow
        end
        PaintSwatches()
        -- The rest under a heading of its own: dropdowns, then switches.
        local generalHead = page:CreateFontString(nil, "ARTWORK", kit.Font and kit.Font("GameFontNormal") or "GameFontNormal")
        generalHead:SetPoint("TOPLEFT", prevRow, "BOTTOMLEFT", 8, -14)
        generalHead:SetText(_G["GENERAL"] or "General")
        local function Control(key)
            local r = rows[key]
            local c = r.control
            if c.kind == "choice" then return kit.Choice(page, r.label, c.choices, c.get, c.set, c.tooltip, c.default) end
            return kit.Checkbox(page, r.label, c.get, c.set, c.tooltip)
        end
        local prev, gap = generalHead, -4
        local function Place(key, x, y)
            local control = Control(key)
            control:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", x or 0, y or 0)
            prev = control
        end
        Place("beacon", -8, gap)
        for _, key in ipairs({ "line", "miniLine", "miniDot", "click", "units", "textSize" }) do
            if rows[key] then Place(key, 0, -4) end
        end
        Place("plateBorder", 0, -6)
        Place("gpsArrow")
        Place("gpsArrowBox")
        -- The box's lines stand in under its switch.
        for i, line in ipairs(GPS.BOX_LINES) do Place(line.key, i == 1 and 16 or 0) end
        local back = -16
        for _, key in ipairs({ "gpsTargetMark", "gpsMinimap", "gpsClickPulse", "gpsZoneSteps", "gpsDangerWarn",
                               "gpsDangerRed", "gpsRowButton", "hideDone", "autoClose", "arriveAnyFloor" }) do
            if rows[key] then
                Place(key, back)
                back = 0
            end
        end
        -- Ways of travel a route leaves out unless nothing else gets there.
        local head = page:CreateFontString(nil, "ARTWORK", kit.Font and kit.Font("GameFontNormal") or "GameFontNormal")
        head:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -14)
        head:SetText(L["GPS_AVOID"])
        prev = head
        for _, kind in ipairs(OptionsPage.AvoidKinds()) do Place("avoid_" .. kind, 0, prev == head and -4 or 0) end
    end
end

-- The extension: its tile opens the map's GPS page or the window, by the
-- menu's choice, and closes it the way it opened.
EasyFind.API.RegisterExtension({
    id = "gps", name = L["APP_GPS"], description = L["APP_DESC_GPS"],
    icon = GPS.ICON_TEX, experimental = L["GPS_EXP_TT"],
    open = function() GPS:Launch() end,
    isOpen = function()
        if GPS.LaunchesWindow() then return GPS:IsWindowOpen() end
        local MapTab = ns.MapTab
        return WorldMapFrame ~= nil and WorldMapFrame:IsShown() and MapTab ~= nil and MapTab.IsPageShowing ~= nil
            and MapTab:IsPageShowing("gps") or false
    end,
    close = function()
        if GPS.LaunchesWindow() then return GPS:CloseWindow() end
        if WorldMapFrame and WorldMapFrame:IsShown() and ToggleWorldMap then ToggleWorldMap() end
    end,
    settings = OptionsPage.Build, settingsRows = OptionsPage.Rows,
})
-- What other extensions ask of it. dest: { name, mapID, x, y } (map
-- coordinates 0..1). Events: routeStarted(dest), arrived(dest), routeCleared.
EasyFind.API.RegisterAction("gps", "navigate", function(dest, opts) return GPS:NavigateTo(dest, opts) end)
EasyFind.API.RegisterAction("gps", "navigateTrip", function(list, opts) return GPS:NavigateTrip(list, opts) end)
EasyFind.API.RegisterAction("gps", "canNavigate", function(dest) return GPS:CanNavigate(dest) end)
-- A guide's creatures under the arrow, a Target button each: { name, kind }.
EasyFind.API.RegisterAction("gps", "setTargets", function(list) if ns.GPSArrow then ns.GPSArrow.SetTargets(list) end end)
EasyFind.API.RegisterAction("gps", "setUses", function(list) if ns.GPSArrow then ns.GPSArrow.SetUses(list) end end)
-- No argument: whether the box under the arrow shows; true or false: show or hide it.
EasyFind.API.RegisterAction("gps", "arrowBox", function(on)
    if on == nil then return GPS.ArrowBoxShown() end
    GPS.SetArrowBox(on and true or false)
end)
EasyFind.API.RegisterAction("gps", "deathSkip", function(on) GPS.SetDeathSkip(on) end)
EasyFind.API.RegisterAction("gps", "setStatus", function(text) GPS.SetStatus(text) end)
EasyFind.API.RegisterAction("gps", "setCircuit", function(list) GPS.SetCircuit(list) end)
EasyFind.API.RegisterAction("gps", "setStart", function(dest) return GPS:SetStart(dest) end)
EasyFind.API.RegisterAction("gps", "clear", function() GPS:Clear() end)
EasyFind.API.RegisterAction("gps", "mapClickNavigates", function() return GPS.MapClickNavigates() end)
-- For EasyFind's own rows and pins: the GPS button a row wears, and where the route goes.
EasyFind.API.RegisterAction("gps", "rowButton", function(row, data, size, onNavigate, glyph)
    return GPS.RowButton(row, data, size, onNavigate, glyph)
end)
EasyFind.API.RegisterAction("gps", "destination", function()
    local route = GPS.CurrentRoute()
    return route and route.dest
end)
-- EasyFind's news: the tracker shown or hidden (the dock follows it), the
-- map search's filters or text size changed (its lists and steps follow).
EasyFind.API.On("easyfind", "trackerChanged", function() GPS.PlaceDock() end)
EasyFind.API.On("easyfind", "mapFiltersChanged", function() GPS.RefreshSearches() end)
EasyFind.API.On("easyfind", "mapTextSizeChanged", function() GPS.RefreshSurfaces() end)

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("TAXIMAP_OPENED")
loginFrame:RegisterEvent("HEARTHSTONE_BOUND")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
loginFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loginFrame:RegisterEvent("PLAYER_ALIVE")
loginFrame:RegisterEvent("PLAYER_UNGHOST")
loginFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
loginFrame:SetScript("OnEvent", function(self, event, unit, _, spellID)
    if event == "PLAYER_REGEN_ENABLED" then
        Refresh()   -- the cast icons hidden for combat come back
        return
    end
    -- The last moment before the lockdown a secure button may still hide.
    if event == "PLAYER_REGEN_DISABLED" then
        for i = 1, #castButtons do
            castButtons[i]:Hide()
            castButtons[i]:ClearAllPoints()
        end
        return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if IsHearthSpell(spellID) then hearthCastAt = GetTime() end
        local route = Route()
        local step = route and not route.arrived and route.steps[route.active or 1]
        if step and step.kind == "teleport" and step.spellID == spellID then route.castAt = GetTime() end
        return
    end
    if event == "TAXIMAP_OPENED" then
        Utils.SafeAfter(0, RecordKnownFlights)
        return
    end
    -- Bound at an innkeeper: where the character stands is where a hearth lands.
    if event == "HEARTHSTONE_BOUND" then
        Utils.SafeAfter(0.5, LearnHearth)
        return
    end
    -- Released to a graveyard, risen, or back in the world as either.
    if event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        GhostOrRisen()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        Utils.SafeAfter(1, GhostOrRisen)
        if hearthCastAt and GetTime() - hearthCastAt < 90 then
            hearthCastAt = nil
            Utils.SafeAfter(1.5, LearnHearth)
        end
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    local db = DB()
    local cc = CharDB()
    if cc and ns.GPSRoute then
        ns.GPSRoute.recordedKnown = cc.flights
    end
    -- A stale field of older saves.
    if cc then cc.groundSpeed = nil end
    -- Routes once lived on the account; one left there is dropped, not
    -- handed to whichever character logs in next.
    if db then db.gpsRoute, db.gpsPopoutOpen = nil, nil end
    if db and db.gpsArrowText then GPS.MigrateArrowText(db) end
    local c = CharDB()
    -- Open as it was left; nil while snapped in is a save from before
    -- closing it was remembered.
    if c and (c.popoutOpen or (c.popoutOpen == nil and db and db.gpsDocked)) then GPS:OpenWindow(true) end
    local route = Route()
    if not route then return end
    -- A route is for the trip in progress; one left from another day is
    -- noise, not directions.
    if route.arrived or (time() - (route.t or 0)) > ROUTE_MAX_AGE then
        if c then c.route = nil end
        return
    end
    StartTicker()
    -- The arrow, beacon and minimap line start for it now: the plan below
    -- refreshes them only if the planner is free, and at login it may not
    -- be (the arrow stayed away after a reload, /efd arrowgone, 2026-11-16).
    Refresh()
    -- Its walks and other ways as the last session found them: only what
    -- is missing is worked out now.
    local Engine = ns.GPSRoute
    if Engine and Engine.KeepWalk then
        for _, w in ipairs(route.walks or {}) do Engine.KeepWalk(w) end
    end
    -- Its end a journey's end again: a cave's floor, not the hill over it.
    local Floors, last = ns.GPSFloors, route.steps and route.steps[#route.steps]
    local p = last and (last.go or last.arrive)
    if Floors and Floors.Goal and route.dest and not route.dest.zone and p and p.wx then Floors.Goal(p.ci, p.wx, p.wy) end
    AfterRoute(route.others ~= nil)
end)
