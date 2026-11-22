





local _, ns = ...
if not (ns.Caps and (ns.Caps.forever or ns.Caps.classic)) then return end

local L = ns.L
local Utils = ns.Utils
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GameTooltip_Hide = GameTooltip_Hide

local PIN_SIZE = 20
local CHECK_EVERY = 0.1
local FALLBACK_TEX = "Interface\\Minimap\\Dungeon"

local overlay
local pins = {}
local shownMap, shownWidth
local since = 0

local function Canvas()
    local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
    return sc and sc.Child
end


local function Enabled()
    local db = EasyFind and EasyFind.db
    return not (db and db.foreverInstancePins == false)
end

local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function PinOnEnter(self)
    local e = self.entry
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(e.name or "")
    GameTooltip:AddLine(e.isRaid and (_G["RAID"] or "Raid") or (_G["LFG_TYPE_DUNGEON"] or "Dungeon"), 1, 1, 1)
    GameTooltip:AddLine(L["INSTANCE_PIN_TT"], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end


local function PinOnClick(self)
    local e = self.entry
    if not (e and e.zoneMapID) then return end
    local dest = { name = e.name, mapID = e.zoneMapID, x = e.zoneX, y = e.zoneY, isDungeonEntrance = true,
                   category = e.isRaid and "raid" or "dungeon" }
    local API = EasyFind.API
    if API.CallAction("gps", "mapClickNavigates") and API.CallAction("gps", "navigate", dest) then return end
    local MapSearch = ns.MapSearch
    if MapSearch and MapSearch.PlaceUserWaypoint and UiMapPoint then
        MapSearch:PlaceUserWaypoint(UiMapPoint.CreateFromCoordinates(e.zoneMapID, e.zoneX, e.zoneY))
        if MapSearch.TrackWaypoint then MapSearch.TrackWaypoint(true) end
    end
end

local function NewPin(i)
    local pin = CreateFrame("Button", nil, overlay)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    pin.glow = pin:CreateTexture(nil, "HIGHLIGHT")
    pin.glow:SetAllPoints()
    pin.glow:SetBlendMode("ADD")
    pin:SetScript("OnEnter", PinOnEnter)
    pin:SetScript("OnLeave", GameTooltip_Hide)
    pin:SetScript("OnClick", PinOnClick)
    pins[i] = pin
    return pin
end

local function SetIcon(tex, raid)
    local atlas = raid and "Raid" or "Dungeon"
    if HasAtlas(atlas) then
        tex:SetAtlas(atlas)
    else
        tex:SetTexture(FALLBACK_TEX)
    end
end

local function Refresh(mapID)
    for i = 1, #pins do pins[i]:Hide() end
    local canvas = Canvas()
    if not (canvas and mapID and Enabled()) then return end
    local list = ns.GetDungeonEntrancesForMap(mapID)
    if not list then return end
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    local size = ns.UIToCanvas(PIN_SIZE)
    for i = 1, #list do
        local e = list[i]
        local pin = pins[i] or NewPin(i)
        pin.entry = e
        pin:SetSize(size, size)
        SetIcon(pin.icon, e.isRaid)
        SetIcon(pin.glow, e.isRaid)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", canvas, "TOPLEFT", e.position.x * w, -e.position.y * h)
        pin:Show()
    end
end


local function Watch(_, elapsed)
    since = since + elapsed
    if since < CHECK_EVERY then return end
    since = 0
    local canvas = Canvas()
    local mapID = WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    local width = canvas and canvas:GetWidth()
    if mapID == shownMap and width == shownWidth then return end
    shownMap, shownWidth = mapID, width
    Refresh(mapID)
end


function ns.RefreshInstancePins()
    shownMap = nil
end

local function Build()
    local canvas = Canvas()
    if overlay or not canvas then return end
    overlay = CreateFrame("Frame", "EasyFindInstancePins", canvas)
    overlay:SetAllPoints(canvas)
    overlay:SetFrameLevel(canvas:GetFrameLevel() + 200)
    overlay:EnableMouse(false)
    Utils.SafeOnUpdate(overlay, Watch)
end


local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_WorldMap" then return end
    Utils.SafeAfter(0, function()
        Build()
        if overlay then self:UnregisterAllEvents() end
    end)
end)
