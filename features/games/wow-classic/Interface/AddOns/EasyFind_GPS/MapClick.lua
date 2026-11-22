-- Alt-click for directions: a spot on the world map or a pin on it (the
-- game's own waypoint pin says so in its tooltip), or a map pin linked in
-- chat; a right-click on a pin or a quest's objective area opens its menu
-- with the directions. Read from the mouse events and after the client's
-- own handling, never inside its click: a hook there would run the rest
-- of the pin's click in our name.
local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).tooOld then return end

local GPS = ns.GPS
if not GPS then return end
local L, Utils = ns.L, ns.Utils
local sformat = string.format

local MapClick = {}
ns.GPSMapClick = MapClick

-- A spot's name: the map's, then where on it.
function MapClick.PointName(mapID, x, y)
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return sformat(L["GPS_MAP_POINT_FMT"], info and info.name or ("#" .. mapID), x * 100, y * 100)
end

-- The map pin under the cursor, if any: a frame the world map placed.
local function PinUnder(map)
    local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
    for _, f in ipairs(foci) do
        if type(f) == "table" and f.owningMap == map and f.GetPosition then return f end
    end
end

local function PinName(pin)
    if not pin then return nil end
    local info = pin.poiInfo or pin.areaPoiInfo or pin.taxiNodeData or pin.vignetteInfo
    local name = pin.name or (info and info.name)
    if not name and pin.questID and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        name = C_QuestLog.GetTitleForQuestID(pin.questID)
    end
    return type(name) == "string" and name ~= "" and name or nil
end

-- A quest pin's quest, for the route to track it on its last step.
local function QuestOf(pin)
    return type(pin.questID) == "number" and pin.questID > 0 and pin.questID or nil
end

-- What a right-click is on: a pin, or with areas a quest's objective area
-- (the map's quest layer, asked where the client asks for its tooltip).
local function TargetUnder(map, areas)
    local pin = PinUnder(map)
    local x, y
    if pin then x, y = pin:GetPosition() end
    if x then return { mapID = map:GetMapID(), x = x, y = y, name = PinName(pin), questID = QuestOf(pin) } end
    if not areas then return nil end
    x, y = map:GetNormalizedCursorPosition()
    for blob in map:EnumeratePinsByTemplate("QuestBlobPinTemplate") do
        local questID = blob:IsShown() and blob:UpdateMouseOverTooltip(x, y)
        if questID then
            local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
            return { mapID = map:GetMapID(), x = x, y = y, name = title ~= "" and title or nil, questID = questID }
        end
    end
end

-- Where the map calls each click handler in a secure call of its own
-- (MapCanvasSecureUtil), a right-click on a target is claimed and the
-- map's zoom out skipped; elsewhere the handler would run the rest of
-- every map click as ours.
local claims = false

local function Go(mapID, x, y, name, questID)
    if not (mapID and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1) then return end
    GPS:NavigateTo({ name = name or MapClick.PointName(mapID, x, y), mapID = mapID, x = x, y = y, questID = questID })
end

-- A right-click on a pin or a quest's area: its menu, the directions to it
-- and, with a route up, a stop there; on the game's own menu where the
-- game has one. Not over a menu the client opened on that click. The bare
-- map keeps the game's zoom out.
local menuAnchor
local function PinMenu(p)
    local manager = Menu and Menu.GetManager and Menu.GetManager()
    if manager and manager.IsAnyMenuOpen and manager:IsAnyMenuOpen() then return end
    local name = p.name or MapClick.PointName(p.mapID, p.x, p.y)
    local defs = {
        { kind = "title", label = name },
        { kind = "action", label = L["GPS_MENU_EASYFIND_DIRECTIONS"], onClick = function() Go(p.mapID, p.x, p.y, p.name, p.questID) end },
    }
    local Trip = ns.GPSTrip
    if Trip and Trip.Insert and GPS.CurrentRoute and GPS.CurrentRoute() then
        defs[#defs + 1] = { kind = "action", label = L["GPS_STOP_ADD"], onClick = function()
            Trip.Insert({ name = name, mapID = p.mapID, x = p.x, y = p.y })
        end }
    end
    if not menuAnchor then
        menuAnchor = CreateFrame("Frame", nil, UIParent)
        menuAnchor:SetSize(1, 1)
    end
    local cx, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    menuAnchor:ClearAllPoints()
    menuAnchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
    if GPS.ShowGameMenu and GPS.ShowGameMenu(menuAnchor, defs) then return end
    if ns.ShowTogglePopup then ns.ShowTogglePopup("EasyFindGPSPinMenu", menuAnchor, defs, {}) end
end

-- A press over the map: with Alt, the spot (a pin's own, under the cursor)
-- taken on the press, the route started on the release, the client's own
-- zoom into a zone on that click put back; the right button on a pin, the
-- pin's menu on the release.
local pressed, pressedPin
local watch = CreateFrame("Frame")
watch:SetScript("OnEvent", function(_, event, button)
    local map = WorldMapFrame
    if event == "GLOBAL_MOUSE_DOWN" then
        pressed, pressedPin = nil, nil
        local right = button == "RightButton"
        if not right and (button ~= "LeftButton" or not IsAltKeyDown()) then return end
        if not (map:IsVisible() and map.ScrollContainer and map.ScrollContainer:IsMouseOver()) then return end
        if right then
            pressedPin = TargetUnder(map, claims)
            return
        end
        local pin = PinUnder(map)
        local x, y
        if pin then x, y = pin:GetPosition() end
        if not x then x, y = map:GetNormalizedCursorPosition() end
        pressed = { mapID = map:GetMapID(), x = x, y = y, name = PinName(pin), questID = pin and QuestOf(pin) }
    elseif pressed then
        local p = pressed
        pressed = nil
        Utils.SafeAfter(0, function()
            if map:IsShown() and map:GetMapID() ~= p.mapID then ns.MapSearch.TurnMap(p.mapID) end
        end)
        Go(p.mapID, p.x, p.y, p.name, p.questID)
    elseif pressedPin and button == "RightButton" then
        local p = pressedPin
        pressedPin = nil
        Utils.SafeAfter(0, function() if map:IsShown() then PinMenu(p) end end)
    end
end)

function MapClick.Install()
    local map = WorldMapFrame
    if MapClick.installed or not map then return end
    MapClick.installed = true
    -- The mouse watched only while the map is up.
    map:HookScript("OnShow", function()
        Utils.RegisterEventIfValid(watch, "GLOBAL_MOUSE_DOWN")
        Utils.RegisterEventIfValid(watch, "GLOBAL_MOUSE_UP")
    end)
    map:HookScript("OnHide", function()
        pressed, pressedPin = nil, nil
        watch:UnregisterAllEvents()
    end)
    if map:IsShown() then map:GetScript("OnShow")(map) end

    -- Last in line, after the client's own handlers (a report on a group
    -- member's dot in a battleground).
    if MapCanvasSecureUtil and map.AddCanvasClickHandler then
        claims = true
        map:AddCanvasClickHandler(function(_, button)
            return button == "RightButton" and TargetUnder(map, true) ~= nil
        end, -10)
    end

    -- The game's waypoint pin: its tooltip names the Alt-click beside its own.
    GameTooltip:HookScript("OnShow", function(tip)
        local owner = tip:GetOwner()
        if not (owner and owner.owningMap == map and owner.CopySlashCommandToClipboard) then return end
        local c = GREEN_FONT_COLOR
        tip:AddLine(L["GPS_ALT_CLICK_PIN"], c and c.r or 0.1, c and c.g or 1, c and c.b or 0.1)
        tip:Show()
    end)

    -- A map pin linked in chat, Alt-clicked: after the client's own handling.
    hooksecurefunc("SetItemRef", function(link, _, button)
        if button ~= "LeftButton" or not IsAltKeyDown() or type(link) ~= "string" then return end
        local mapID, x, y = link:match("^worldmap:(%d+):(%d+):(%d+)")
        if mapID then Go(tonumber(mapID), tonumber(x) / 10000, tonumber(y) / 10000) end
    end)
end

-- The world map may load after us: at login or when it arrives.
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_WorldMap" then return end
    MapClick.Install()
    if MapClick.installed then self:UnregisterAllEvents() end
end)
