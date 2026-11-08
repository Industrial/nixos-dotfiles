--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- The LibDataBroker feeds: player coordinates and the crazy arrow.
--
-- LibDataBroker cannot remove a data object. A feed that is turned off stops
-- its updates and clears its text. When it is turned on again, it uses the
-- same data object.

local addonName, addon = ...
local TomTom = addon
local L = addon.L
local ldb = LibStub("LibDataBroker-1.1")
addon.private = addon.private or {}
local private = addon.private
local RoundCoords = private.RoundCoords

local IMAGE_ARROW = "Interface\\Addons\\TomTom\\Images\\Arrow-1024"
local IMAGE_STATIC_ARROW = "Interface\\Addons\\TomTom\\Images\\StaticArrow"

local twopi = math.pi * 2

-- Two modules share the namespace, and a namespace has one set of defaults.
private.RegisterDefaults("feeds", {
    coords = false,
    coords_throttle = 0.3,
    coords_accuracy = 2,
    arrow = false,
    arrow_throttle = 0.1,
})

local coordFeed = {settingsKey = "feeds", enableSetting = {"feeds", "coords"}}
private.AddModule(coordFeed, "CoordFeed")

local arrowFeed = {settingsKey = "feeds", enableSetting = {"feeds", "arrow"}}
private.AddModule(arrowFeed, "ArrowFeed")

private.AddSettingsSection{
    page = "feeds", pageName = L["Data Feed Options"], pageOrder = 70, order = 10,
    settingsKey = "feeds",
    rows = {
        {type = "text", text = L["TomTom is capable of providing data sources via LibDataBroker, which allows them to be displayed in any LDB compatible display.  These options enable or disable the individual feeds."]},
    },
}

private.AddSettingsSection{
    page = "feeds", pageName = L["Data Feed Options"], pageOrder = 70, order = 20,
    settingsKey = "feeds",
    feature = {name = L["Provide an LDB data source for coordinates"], path = "feeds.coords"},
    rows = {
        {type = "range", key = "coords_throttle", name = L["Coordinate feed throttle"],
         tooltip = L["Controls the frequency of updates for the coordinate LDB feed."],
         min = 0, max = 2.0, step = 0.05},
        {type = "range", key = "coords_accuracy", name = L["Coordinate feed accuracy"],
         tooltip = L["Coordinates can be displayed as simple XX, YY coordinate, or as more precise XX.XX, YY.YY.  This setting allows you to control that precision"],
         min = 0, max = 2, step = 1},
    },
}

private.AddSettingsSection{
    page = "feeds", pageName = L["Data Feed Options"], pageOrder = 70, order = 30,
    settingsKey = "feeds",
    feature = {name = L["Provide a LDB data source for the crazy-arrow"], path = "feeds.arrow"},
    rows = {
        {type = "range", key = "arrow_throttle", name = L["Crazy Arrow feed throttle"],
         tooltip = L["Controls the frequency of updates for the crazy arrow LDB feed."],
         min = 0, max = 2.0, step = 0.05},
    },
}

--[[--------------------------------------------------------------------------
--  Coordinate feed
----------------------------------------------------------------------------]]

local coordObject, coordFrame
local coordThrottle, coordCounter = 0, 0

local function UpdateCoordThrottle()
    coordThrottle = TomTom.db.profile.feeds.coords_throttle
end

local function CoordFeed_OnUpdate(self, elapsed)
    coordCounter = coordCounter + elapsed
    if coordCounter < coordThrottle then
        return
    end

    coordCounter = 0
    local m, x, y = TomTom:GetCurrentPlayerPosition()

    if x and y then
        local opt = TomTom.db.profile.feeds
        coordObject.text = string.format("%s", RoundCoords(x, y, opt.coords_accuracy))
    end
end

function coordFeed:OnInitialize()
    coordObject = ldb:NewDataObject("TomTom_Coords", {
        type = "data source",
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        text = "",
    })

    coordFrame = CreateFrame("Frame")
    coordFrame:Hide()
    coordFrame:SetScript("OnUpdate", CoordFeed_OnUpdate)
end

function coordFeed:OnEnable()
    UpdateCoordThrottle()
    coordCounter = 0
    coordFrame:Show()
end

function coordFeed:OnDisable()
    coordFrame:Hide()
    coordObject.text = ""
end

-- coords_accuracy needs nothing here: the next update reads it.
function coordFeed:OnSettingChanged(key)
    if key == "coords_throttle" then
        UpdateCoordThrottle()
    end
end

function coordFeed:OnProfileChanged()
    UpdateCoordThrottle()
end

function TomTom:UpdateCoordFeedThrottle()
    UpdateCoordThrottle()
end

--[[--------------------------------------------------------------------------
--  Crazy arrow feed
----------------------------------------------------------------------------]]

local function getCoords(column, row)
    local xstart = (column * 56) / 512
    local ystart = (row * 42) / 512
    local xend = ((column + 1) * 56) / 512
    local yend = ((row + 1) * 42) / 512
    return xstart, xend, ystart, yend
end

local texcoords = setmetatable({}, {__index = function(t, k)
    local col,row = k:match("(%d+):(%d+)")
    col,row = tonumber(col), tonumber(row)
    local obj = {getCoords(col, row)}
    rawset(t, k, obj)
    return obj
end})

local arrowObject, arrowFrame
local arrowThrottle, arrowCounter = 0, 0

local function UpdateArrowThrottle()
    arrowThrottle = TomTom.db.profile.feeds.arrow_throttle
end

local function ArrowFeed_OnUpdate(self, elapsed)
    arrowCounter = arrowCounter + elapsed
    if arrowCounter < arrowThrottle then
        return
    end

    arrowCounter = 0
    local point, title = private.GetCrazyArrowTarget()
    if not point then
        self:Hide()
    end
    local angle = TomTom:GetDirectionToWaypoint(point)
    local player = GetPlayerFacing()
    if not angle or not player then
        arrowObject.iconCoords = texcoords["1:1"]
        arrowObject.iconR = 0.2
        arrowObject.iconG = 1.0
        arrowObject.iconB = 0.2
        arrowObject.text = "No waypoint"
        return
    end

    angle = angle - player

    local perc = math.abs((math.pi - math.abs(angle)) / math.pi)

    local gr,gg,gb = unpack(TomTom.db.profile.arrow.goodcolor)
    local mr,mg,mb = unpack(TomTom.db.profile.arrow.middlecolor)
    local br,bg,bb = unpack(TomTom.db.profile.arrow.badcolor)
    local r,g,b = addon:ColorGradient(perc, br, bg, bb, mr, mg, mb, gr, gg, gb)

    -- If we're 98% heading in the right direction, then use the exact
    -- color instead of the gradient. This allows us to distinguish 'good'
    -- from 'on target'. Thanks to Gregor_Curse for the suggestion.
    if perc > 0.98 then
        r,g,b = unpack(TomTom.db.profile.arrow.exactcolor)
    end

    arrowObject.iconR = r
    arrowObject.iconG = g
    arrowObject.iconB = b

    local cell = math.floor(angle / twopi * 108 + 0.5) % 108
    local column = cell % 9
    local row = math.floor(cell / 9)

    local key = column .. ":" .. row
    arrowObject.iconCoords = texcoords[key]
    arrowObject.text = title or L["Unknown waypoint"]
end

function arrowFeed:OnInitialize()
    arrowObject = ldb:NewDataObject("TomTom_CrazyArrow", {
        type = "data source",
        icon = IMAGE_ARROW,
        staticIcon = IMAGE_STATIC_ARROW,
        text = "Crazy",
        iconR = 0.2,
        iconG = 1.0,
        iconB = 0.2,
        iconCoords = texcoords["1:1"],
        OnTooltipShow = function(tooltip)
            local point, title = private.GetCrazyArrowTarget()
            local dist = TomTom:GetDistanceToWaypoint(point)
            if dist then
                tooltip:AddLine(title or L["Unknown waypoint"])
                tooltip:AddLine(string.format(L["%d yards"], dist), 1, 1, 1)
            end
        end,
        OnClick = private.CrazyArrow_OnClick,
    })

    arrowFrame = CreateFrame("Frame")
    arrowFrame:Hide()
    arrowFrame:SetScript("OnUpdate", ArrowFeed_OnUpdate)
end

-- The update stops itself when the arrow has no target, so a new target
-- must start it again.
function arrowFeed:TOMTOM_ARROW_TARGET_CHANGED()
    arrowFrame:Show()
end

function arrowFeed:OnEnable()
    UpdateArrowThrottle()
    arrowCounter = 0
    arrowFrame:Show()
    self:RegisterMessage("TOMTOM_ARROW_TARGET_CHANGED")
end

function arrowFeed:OnDisable()
    self:UnregisterMessage("TOMTOM_ARROW_TARGET_CHANGED")
    arrowFrame:Hide()
    arrowObject.text = ""
end

function arrowFeed:OnSettingChanged(key)
    if key == "arrow_throttle" then
        UpdateArrowThrottle()
    end
end

function arrowFeed:OnProfileChanged()
    UpdateArrowThrottle()
end

function TomTom:UpdateArrowFeedThrottle()
    UpdateArrowThrottle()
end
