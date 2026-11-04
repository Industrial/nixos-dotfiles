-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

local LibStub = _G.LibStub
local LibDialog = LibStub("LibDialog-1.0RS")
local AL = LibStub("AceLocale-3.0"):GetLocale("RareScanner")
local HBD = LibStub("HereBeDragons-2.0")

local RSRoute = private.NewLib("RareScannerRoute")

-- RareScanner libraries
local RSConstants = private.ImportLib("RareScannerConstants")
local RSConfigDB = private.ImportLib("RareScannerConfigDB")
local RSNpcDB = private.ImportLib("RareScannerNpcDB")
local RSGeneralDB = private.ImportLib("RareScannerGeneralDB")
local RSWorldMap = private.ImportLib("RareScannerWorldMap")
local RSMap = private.ImportLib("RareScannerMap")
local RSUtils = private.ImportLib("RareScannerUtils")
local RSLogger = private.ImportLib("RareScannerLogger")
local RSRoutines = private.ImportLib("RareScannerRoutines")

-- Visual constants
local MINIMAP_LINE_THICKNESS = 2
local ARROW_LENGTH = 6
local ARROW_WIDTH = 4
local ICON_PADDING_START = 12
local ICON_PADDING_END = 14
local CHECKPOINT_DISTANCE_YARDS = 40
local MINIMAP_EDGE_RATIO = 0.98
local WINDOW_NOT_MAXIMIZED_SCALE_FACTOR = 1.45
local WINDOW_MAXIMIZED_SCALE_FACTOR = 1.0

-- Quadrant definitions for minimap shapes
local minimap_shapes = {
    ["ROUND"]                 = { true,  true,  true,  true },
    ["SQUARE"]                = { false, false, false, false },
    ["CORNER-TOPLEFT"]        = { true,  false, false, false },
    ["CORNER-TOPRIGHT"]       = { false, false, true,  false },
    ["CORNER-BOTTOMLEFT"]     = { false, true,  false, false },
    ["CORNER-BOTTOMRIGHT"]    = { false, false, false, true },
    ["SIDE-LEFT"]             = { true,  true,  false, false },
    ["SIDE-RIGHT"]            = { false, false, true,  true },
    ["SIDE-TOP"]              = { true,  false, true,  false },
    ["SIDE-BOTTOM"]           = { false, true,  false, true },
    ["TRICORNER-TOPLEFT"]     = { true,  true,  true,  false },
    ["TRICORNER-TOPRIGHT"]    = { true,  false, true,  true },
    ["TRICORNER-BOTTOMLEFT"]  = { true,  true,  false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { false, true,  true,  true },
}

-- Minimap view radius fallback by zoom level
local MINIMAP_SIZE = {
    indoor = {
        [0] = 300,
        [1] = 240,
        [2] = 180,
        [3] = 120,
        [4] = 80,
        [5] = 50,
    },
    outdoor = {
        [0] = 466 + 2/3,
        [1] = 400,
        [2] = 333 + 1/3,
        [3] = 266 + 2/3,
        [4] = 200,
        [5] = 133 + 1/3,
    },
}

-- Active route state
local activeRoute = {
    mapID = nil,
    nodes = {},
    isCompleted = false,
}

-- WorldMap frames and pools
local routeFrame = nil
local linePool = {}
local trackerTicker = nil

-- Minimap frames and pools
local minimapRouteFrame = nil
local minimapLinePool = {}
local minimapUpdateFrame = nil

--- Dynamic color resolver from options
local function GetRouteColor()
    local r, g, b = RSConfigDB.GetRouteColour()
    return r, g, b, 0.75
end

--- ============================================================================
--- WorldMap Frame & Pool Management
--- ============================================================================
local function GetCanvasZoomFactor()
    if (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetCanvasScale) then
        local scale = WorldMapFrame.ScrollContainer:GetCanvasScale()
        if (scale and scale > 0) then
            return scale
        end
    end
    if (WorldMapFrame and WorldMapFrame.GetCanvasZoomPercent) then
        local zoomPercent = WorldMapFrame:GetCanvasZoomPercent() or 0
        if (zoomPercent > 0) then
            return 1.0 + zoomPercent
        end
    end
    return 1.0
end

local function GetRouteFrame()
    if (routeFrame) then return routeFrame end

    local mapFrame = RSWorldMap:GetMapFrame()
    if (not mapFrame) then return nil end

    routeFrame = CreateFrame("Frame", nil, mapFrame)
    routeFrame:SetAllPoints(mapFrame)
    routeFrame:SetFrameStrata("HIGH")
    routeFrame:SetFrameLevel(math.max(1, mapFrame:GetFrameLevel() - 1))

    local function OnMapRedrawNeeded()
        if (RSRoute.HasActiveRoute() and not RSRoute.IsCompleted() and WorldMapFrame:IsShown()) then
            RSRoute.RedrawCurrentRoute()
        end
    end

    if (WorldMapFrame and WorldMapFrame.OnCanvasScaleChanged) then
        hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", OnMapRedrawNeeded)
    end
    if (WorldMapFrame and WorldMapFrame.SetMaximized) then
        hooksecurefunc(WorldMapFrame, "SetMaximized", OnMapRedrawNeeded)
    end

    return routeFrame
end

local function ClearRoute()
    for _, line in ipairs(linePool) do 
        line:Hide() 
    end
end

local function AcquireLine(parent)
    for _, line in ipairs(linePool) do
        if (not line:IsShown()) then
            line:Show()
            return line
        end
    end
    local line = parent:CreateLine(nil, "OVERLAY")
    line:SetTexture([[Interface\Buttons\WHITE8X8]])
    table.insert(linePool, line)
    return line
end

--- ============================================================================
--- Minimap Frame & Pool Management
--- ============================================================================
local function GetMinimapRouteFrame()
    if (minimapRouteFrame) then 
        return minimapRouteFrame 
    end
    if (not Minimap) then 
        return nil 
    end

    minimapRouteFrame = CreateFrame("Frame", nil, Minimap)
    minimapRouteFrame:SetAllPoints(Minimap)
    minimapRouteFrame:SetFrameLevel(math.max(1, Minimap:GetFrameLevel() + 1))
    return minimapRouteFrame
end

local function ClearMinimapRoute()
    for _, line in ipairs(minimapLinePool) do 
        line:Hide() 
    end
end

local function AcquireMinimapLine(parent)
    for _, line in ipairs(minimapLinePool) do
        if (not line:IsShown()) then
            line:Show()
            return line
        end
    end

    local line = parent:CreateLine(nil, "OVERLAY")
    line:SetTexture([[Interface\Buttons\WHITE8X8]])
    line:SetThickness(MINIMAP_LINE_THICKNESS)

    if (Minimap.GetMaskTexture and Minimap:GetMaskTexture()) then
        line:AddMaskTexture(Minimap:GetMaskTexture())
    end

    table.insert(minimapLinePool, line)
    return line
end

--- ============================================================================
--- Minimap Clipping Math
--- ============================================================================
local function IsPointInsideMinimapShape(u, v)
    local shapeName = (GetMinimapShape and GetMinimapShape()) or "ROUND"
    local shape = minimap_shapes[shapeName] or minimap_shapes["ROUND"]
    
    local quadIdx = (u < 0) and 1 or 3
    local isRound = (v < 0) and shape[quadIdx + 1] or shape[quadIdx]
    
    if (isRound) then
        return (u * u + v * v) <= (MINIMAP_EDGE_RATIO * MINIMAP_EDGE_RATIO)
    else
        return (math.max(math.abs(u), math.abs(v)) <= MINIMAP_EDGE_RATIO)
    end
end

local function ClipRayFromCenter(u, v)
    local shapeName = (GetMinimapShape and GetMinimapShape()) or "ROUND"
    local shape = minimap_shapes[shapeName] or minimap_shapes["ROUND"]

    local quadIdx = (u < 0) and 1 or 3
    local isRound = (v < 0) and shape[quadIdx + 1] or shape[quadIdx]

    if (isRound) then
        local dist = math.sqrt(u * u + v * v)
        if (dist > MINIMAP_EDGE_RATIO and dist > 0) then
            local scale = MINIMAP_EDGE_RATIO / dist
            return u * scale, v * scale
        end
    else
        local maxCoord = math.max(math.abs(u), math.abs(v))
        if (maxCoord > MINIMAP_EDGE_RATIO and maxCoord > 0) then
            local scale = MINIMAP_EDGE_RATIO / maxCoord
            return u * scale, v * scale
        end
    end

    return u, v
end

local function ClipSegmentToMinimapShape(u1, v1, u2, v2)
    local in1 = IsPointInsideMinimapShape(u1, v1)
    local in2 = IsPointInsideMinimapShape(u2, v2)

    if (in1 and in2) then
        return u1, v1, u2, v2, true
    end

    local dx = u2 - u1
    local dy = v2 - v1
    local segLenSq = dx * dx + dy * dy
    if (segLenSq == 0) then
        return nil, nil, nil, nil, false
    end

    local tClosest = math.max(0, math.min(1, - (u1 * dx + v1 * dy) / segLenSq))
    local closestU = u1 + tClosest * dx
    local closestV = v1 + tClosest * dy
    if (not IsPointInsideMinimapShape(closestU, closestV)) then
        return nil, nil, nil, nil, false
    end

    local t0, t1 = 0, 1
    if (not in1) then
        local low, high = 0, tClosest
        for _ = 1, 8 do
            local mid = (low + high) * 0.5
            if (IsPointInsideMinimapShape(u1 + mid * dx, v1 + mid * dy)) then 
                high = mid 
            else 
                low = mid 
            end
        end
        t0 = high
    end

    if (not in2) then
        local low, high = tClosest, 1
        for _ = 1, 8 do
            local mid = (low + high) * 0.5
            if (IsPointInsideMinimapShape(u1 + mid * dx, v1 + mid * dy)) then 
                low = mid 
            else 
                high = mid 
            end
        end
        t1 = low
    end

    if (t0 >= t1) then 
        return nil, nil, nil, nil, false end

    return u1 + t0 * dx, v1 + t0 * dy, u1 + t1 * dx, v1 + t1 * dy, true
end

--- ============================================================================
--- WorldMap Segment Drawing
--- ============================================================================
local function DrawSegment(parent, mapWidth, mapHeight, p1, p2, r, g, b, a, zoomFactor)
    zoomFactor = (zoomFactor and zoomFactor > 0) and zoomFactor or 1.0

    local lineThickness = RSConfigDB.GetRouteLineThickness() / zoomFactor
    local arrowLen = ARROW_LENGTH / zoomFactor
    local arrowWidth = ARROW_WIDTH / zoomFactor

    local startX, startY = p1.x * mapWidth, -p1.y * mapHeight
    local endX, endY = p2.x * mapWidth, -p2.y * mapHeight

    local dx, dy = endX - startX, endY - startY
    local dist = math.sqrt(dx * dx + dy * dy)

    -- If spots too close ignore line
    if (dist <= 0.1) then 
        return 
    end

    -- Line to join icons
    local line = AcquireLine(parent)
    line:SetThickness(lineThickness)
    line:SetVertexColor(r, g, b, a)
    line:SetStartPoint("TOPLEFT", parent, startX, startY)
    line:SetEndPoint("TOPLEFT", parent, endX, endY)

    -- Directional arrow
    if (dist > arrowLen) and (not RSConfigDB or not RSConfigDB.IsShowingRouteArrows or RSConfigDB.IsShowingRouteArrows()) then
        local ux, uy = dx / dist, dy / dist
        local nx, ny = -uy, ux

        local midX = startX + dx * 0.5
        local midY = startY + dy * 0.5

        local wing1X = midX - (ux * arrowLen) + (nx * arrowWidth)
        local wing1Y = midY - (uy * arrowLen) + (ny * arrowWidth)
        local wing2X = midX - (ux * arrowLen) - (nx * arrowWidth)
        local wing2Y = midY - (uy * arrowLen) - (ny * arrowWidth)

        local leftWing = AcquireLine(parent)
        leftWing:SetThickness(lineThickness)
        leftWing:SetVertexColor(r, g, b, 1.0)
        leftWing:SetStartPoint("TOPLEFT", parent, midX, midY)
        leftWing:SetEndPoint("TOPLEFT", parent, wing1X, wing1Y)

        local rightWing = AcquireLine(parent)
        rightWing:SetThickness(lineThickness)
        rightWing:SetVertexColor(r, g, b, 1.0)
        rightWing:SetStartPoint("TOPLEFT", parent, midX, midY)
        rightWing:SetEndPoint("TOPLEFT", parent, wing2X, wing2Y)
    end
end
-----------------------------------------------------------------------
-- Held-Karp async with Progress Bar
-----------------------------------------------------------------------
local progressBar = nil
local activeCalculationRoutine = nil

local function GetProgressBar()
    if (progressBar) then 
        return progressBar 
    end

    local parent = (WorldMapFrame and WorldMapFrame.ScrollContainer) or WorldMapFrame
    if (not parent) then
        return nil
    end

    local barFrame = CreateFrame("Frame", "RSRouteProgressBar", parent, "BackdropTemplate")
    barFrame:SetSize(220, 20)
    barFrame:SetPoint("TOP", parent, "TOP", 0, -100)
    barFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    barFrame:SetFrameLevel(9999)
    barFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    barFrame:SetBackdropColor(0, 0, 0, 0.8)
    barFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)

    local statusBar = CreateFrame("StatusBar", nil, barFrame)
    statusBar:SetPoint("TOPLEFT", barFrame, "TOPLEFT", 3, -3)
    statusBar:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", -3, 3)
    statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    if (statusBar:GetStatusBarTexture()) then
        statusBar:GetStatusBarTexture():SetHorizTile(false)
    end

    statusBar:SetMinMaxValues(0, 100)
    statusBar:SetValue(0)

    local text = statusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", statusBar, "CENTER", 0, 0)
    text:SetText("")

    barFrame.statusBar = statusBar
    barFrame.text = text
    barFrame:Hide()

    progressBar = barFrame
    return progressBar
end

local function ShowProgressBar(percent)
    local bar = GetProgressBar()
    if (not bar) then 
        return 
    end
    
    local r, g, b = RSConfigDB.GetRouteColour()
    bar.statusBar:SetStatusBarColor(r, g, b, 0.85)
    bar.statusBar:SetValue(percent)
    local pattern = AL["MAP_ROUTES_CALCULATING"]
    bar.text:SetText(string.format(pattern, percent))
    if (not bar:IsShown()) then
        bar:Show()
    end
end

local function HideProgressBar()
    if (progressBar) then
        progressBar:Hide()
    end
end

local function SolveHeldKarpAsync(startPos, targets, onFinishedCallback)
    local n = #targets
    if (n == 0) then 
        if (onFinishedCallback) then 
            onFinishedCallback({}) 
        end

        return 
    end
    if (n == 1) then 
        if (onFinishedCallback) then 
            onFinishedCallback({ targets[1] }) 
        end

        return 
    end

    if (activeCalculationRoutine) then
        activeCalculationRoutine:Reset()
        activeCalculationRoutine = nil
    end

    local dist = {}
    for i = 0, n do dist[i] = {} end

    for j = 1, n do
        dist[0][j] = RSUtils.DistanceBetweenPointsNoFix(startPos, targets[j])
        dist[j][0] = dist[0][j]
    end

    for i = 1, n do
        for j = 1, n do
            dist[i][j] = (i == j) and 0 or RSUtils.DistanceBetweenPointsNoFix(targets[i], targets[j])
        end
    end

    local dp, parent = {}, {}
    local numStates = bit.lshift(1, n)

    for mask = 0, numStates - 1 do
        dp[mask], parent[mask] = {}, {}
    end

    for i = 1, n do
        local mask = bit.lshift(1, i - 1)
        dp[mask][i] = dist[0][i]
        parent[mask][i] = 0
    end

    local BATCH_SIZE = 512
    local totalSteps = math.ceil((numStates - 1) / BATCH_SIZE)

    ShowProgressBar(0)

    local hkRoutine = RSRoutines.LoopIndexRoutineNew()
    activeCalculationRoutine = hkRoutine

    hkRoutine:Init(
        totalSteps, 
        function(ctx, step)
            if (activeCalculationRoutine ~= hkRoutine) then
                return
            end

            local startMask = ((step - 1) * BATCH_SIZE) + 1
            local endMask = math.min(step * BATCH_SIZE, numStates - 1)

            for mask = startMask, endMask do
                for last = 1, n do
                    if (bit.band(mask, bit.lshift(1, last - 1)) ~= 0 and dp[mask][last]) then
                        for nextNode = 1, n do
                            if (bit.band(mask, bit.lshift(1, nextNode - 1)) == 0) then
                                local nextMask = bit.bor(mask, bit.lshift(1, nextNode - 1))
                                local newCost = dp[mask][last] + dist[last][nextNode]

                                if (not dp[nextMask][nextNode] or newCost < dp[nextMask][nextNode]) then
                                    dp[nextMask][nextNode] = newCost
                                    parent[nextMask][nextNode] = last
                                end
                            end
                        end
                    end
                end
            end

            local pct = math.min(99, math.floor((step / totalSteps) * 100))
            ShowProgressBar(pct)
        end,
        function(ctx)
            if (activeCalculationRoutine ~= hkRoutine) then
                return
            end
            activeCalculationRoutine = nil
            HideProgressBar()

            local fullMask = numStates - 1
            local bestLastNode = 1
            local minTotalCost = math.huge

            for i = 1, n do
                if dp[fullMask][i] and dp[fullMask][i] < minTotalCost then
                    minTotalCost = dp[fullMask][i]
                    bestLastNode = i
                end
            end

            local revRoute = {}
            local currMask, currNode = fullMask, bestLastNode

            while (currNode ~= 0) do
                table.insert(revRoute, targets[currNode])
                local prevNode = parent[currMask][currNode]
                currMask = bit.bxor(currMask, bit.lshift(1, currNode - 1))
                currNode = prevNode
            end

            local route = {}
            for i = #revRoute, 1, -1 do
                table.insert(route, revRoute[i])
            end

            if (onFinishedCallback) then
                onFinishedCallback(route, minTotalCost)
            end
        end
    )

    hkRoutine:Run()
end

--- ============================================================================
--- WorldMap Redraw
--- ============================================================================
function RSRoute.RedrawCurrentRoute()
    ClearRoute()

    if (IsInInstance() or activeRoute.isCompleted or #activeRoute.nodes == 0) then
        return
    end

    local frame = GetRouteFrame()
    if (not frame or not WorldMapFrame:IsShown()) then 
        return end

    local currentMapID = RSWorldMap.mapID or WorldMapFrame:GetMapID()
    if (not currentMapID or currentMapID ~= activeRoute.mapID) then 
        return
    end

    local playerPos = C_Map.GetPlayerMapPosition(currentMapID, "player")
    if (not playerPos) then return end

    local mapWidth, mapHeight = frame:GetWidth(), frame:GetHeight()
    if (not mapWidth or mapWidth == 0 or not mapHeight or mapHeight == 0) then 
        return end

    local zoomFactor = GetCanvasZoomFactor()
    local r, g, b, a = GetRouteColor()
    local prevNode = { x = playerPos.x, y = playerPos.y }
    for _, targetNode in ipairs(activeRoute.nodes) do
        DrawSegment(frame, mapWidth, mapHeight, prevNode, targetNode, r, g, b, a, zoomFactor)
        prevNode = targetNode
    end
end

function RSRoute.RefreshRoute()
    if (RSRoute.HasActiveRoute() and not RSRoute.IsCompleted()) then
        RSRoute.RedrawCurrentRoute()
        RSRoute.UpdateMinimapRoute()
    else
        ClearRoute()
        ClearMinimapRoute()
    end
end

--- ============================================================================
--- Minimap Redraw
--- ============================================================================
function RSRoute.UpdateMinimapRoute()
    ClearMinimapRoute()

    if (IsInInstance() or not RSRoute.HasActiveRoute() or RSRoute.IsCompleted()) then
        return
    end

    local playerMapID = C_Map.GetBestMapForUnit("player")
    if (not playerMapID or playerMapID ~= activeRoute.mapID) then 
        return 
    end

    if (RSConfigDB and RSConfigDB.IsShowingMinimapRoute and not RSConfigDB.IsShowingMinimapRoute()) then return end
    if (not Minimap or not Minimap:IsShown() or not HBD) then 
        return
    end

    local playerWX, playerWY, playerInstance = HBD:GetPlayerWorldPosition()
    if (not playerWX or not playerWY) then 
        return
    end

    local mapRadius
    if (C_Minimap and C_Minimap.GetViewRadius) then
        mapRadius = C_Minimap.GetViewRadius()
    else
        local zoom = Minimap:GetZoom()
        local indoors = (GetCVar("minimapZoom") + 0 == zoom) and "outdoor" or "indoor"
        mapRadius = (MINIMAP_SIZE[indoors] and MINIMAP_SIZE[indoors][zoom] or 200) / 2
    end

    if (not mapRadius or mapRadius <= 0) then 
        return 
    end

    local rotateMinimap = GetCVar("rotateMinimap") == "1"
    local mapSin, mapCos
    if (rotateMinimap) then
        local facing = GetPlayerFacing()
        if (facing) then
            mapSin, mapCos = math.sin(facing), math.cos(facing)
        end
    end

    local halfWidth, halfHeight = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2

    local function WorldToNormalizedCoords(targetWX, targetWY)
        local xDist = playerWX - targetWX
        local yDist = playerWY - targetWY

        if (rotateMinimap and mapSin and mapCos) then
            local dx, dy = xDist, yDist
            xDist = dx * mapCos - dy * mapSin
            yDist = dx * mapSin + dy * mapCos
        end

        return (xDist / mapRadius), - (yDist / mapRadius)
    end

    local parentFrame = GetMinimapRouteFrame()
    if (not parentFrame) then 
        return
    end

    local r, g, b, a = GetRouteColor()

    -- First segment: Player position to next target
    local firstNode = activeRoute.nodes[1]
    if (firstNode) then
        local nodeWX, nodeWY, nodeInstance = HBD:GetWorldCoordinatesFromZone(firstNode.x, firstNode.y, activeRoute.mapID)
        if (nodeWX and nodeInstance == playerInstance) then
            local u, v = WorldToNormalizedCoords(nodeWX, nodeWY)
            local endU, endV = ClipRayFromCenter(u, v)

            local line = AcquireMinimapLine(parentFrame)
            line:SetVertexColor(r, g, b, a)
            line:SetStartPoint("CENTER", Minimap, 0, 0)
            line:SetEndPoint("CENTER", Minimap, endU * halfWidth, endV * halfHeight)
        end
    end

    -- Subsequent segments between targets
    local maxDisplayDist = mapRadius * 4
    for i = 1, math.min(#activeRoute.nodes - 1, 5) do
        local n1, n2 = activeRoute.nodes[i], activeRoute.nodes[i + 1]

        local w1X, w1Y, inst1 = HBD:GetWorldCoordinatesFromZone(n1.x, n1.y, activeRoute.mapID)
        local w2X, w2Y, inst2 = HBD:GetWorldCoordinatesFromZone(n2.x, n2.y, activeRoute.mapID)

        if (w1X and w2X and inst1 == playerInstance and inst2 == playerInstance) then
            local d1 = math.sqrt((playerWX - w1X)^2 + (playerWY - w1Y)^2)
            local d2 = math.sqrt((playerWX - w2X)^2 + (playerWY - w2Y)^2)

            if (d1 <= maxDisplayDist or d2 <= maxDisplayDist) then
                local u1, v1 = WorldToNormalizedCoords(w1X, w1Y)
                local u2, v2 = WorldToNormalizedCoords(w2X, w2Y)

                local cu1, cv1, cu2, cv2, isVisible = ClipSegmentToMinimapShape(u1, v1, u2, v2)
                if (isVisible) then
                    local line = AcquireMinimapLine(parentFrame)
                    line:SetVertexColor(r, g, b, a)
                    line:SetStartPoint("CENTER", Minimap, cu1 * halfWidth, cv1 * halfHeight)
                    line:SetEndPoint("CENTER", Minimap, cu2 * halfWidth, cv2 * halfHeight)
                end
            end
        end
    end
end

local function StartMinimapUpdateTicker()
    if (not minimapUpdateFrame) then
        minimapUpdateFrame = CreateFrame("Frame")
        local elapsedAccumulator = 0
        minimapUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
            elapsedAccumulator = elapsedAccumulator + elapsed
            if (elapsedAccumulator >= 0.05) then
                elapsedAccumulator = 0
                RSRoute.UpdateMinimapRoute()
            end
        end)
    end
    minimapUpdateFrame:Show()
end

local function StopMinimapUpdateTicker()
    if (minimapUpdateFrame) then 
        minimapUpdateFrame:Hide() 
    end

    ClearMinimapRoute()
end

--- ============================================================================
--- Proximity Checking
--- ============================================================================
local function OnCheckProximity()
    local playerMapID = C_Map.GetBestMapForUnit("player")
    if (IsInInstance() or not playerMapID or playerMapID ~= activeRoute.mapID) then
        return
    end

    if (activeRoute.isCompleted or #activeRoute.nodes == 0) then
        RSRoute.CancelRoute()
        return
    end

    local playerPos = C_Map.GetPlayerMapPosition(activeRoute.mapID, "player")
    if (not playerPos) then 
        return
    end

    local currentTarget = activeRoute.nodes[1]
    if (not currentTarget) then 
        return end

    local distanceYards = RSUtils.GetDistanceInYards(activeRoute.mapID, playerPos.x, playerPos.y, currentTarget.x, currentTarget.y)
    if (distanceYards and distanceYards > 0 and distanceYards <= CHECKPOINT_DISTANCE_YARDS) then
        table.remove(activeRoute.nodes, 1)

        if (#activeRoute.nodes == 0) then
            RSRoute.CancelRoute()
        else
            PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_REMOVE)
            RSRoute.RedrawCurrentRoute()
            RSRoute.UpdateMinimapRoute()
        end
    else
        if (WorldMapFrame:IsShown()) then
            RSRoute.RedrawCurrentRoute()
        end
    end
end

--- ============================================================================
--- Route Initialization & Control
--- ============================================================================
local function IsValidNpcTarget(poi)
    if (not poi or not poi.isNpc or not poi.x or not poi.y) then 
        return false 
    end
    
    if (not RSConfigDB.IsShowingNpcs()) then 
        return false 
    end

    if (poi.isDead or RSNpcDB.IsNpcKilled(poi.entityID)) then 
        return false 
    end

    if (poi.isFriendly or RSNpcDB.IsInternalNpcFriendly(poi.entityID)) then 
        return false 
    end

    if (not poi.isDiscovered and not RSConfigDB.IsShowingNotDiscoveredNpcs()) then 
        return false 
    end

    if (RSConfigDB.IsNpcFiltered(poi.entityID) or RSConfigDB.IsNpcFilteredOnlyWorldmap(poi.entityID)) then 
        return false 
    end

    if (poi.custom and poi.group and RSConfigDB.IsCustomNpcGroupFiltered(poi.group)) then 
        return false 
    end

    return true
end

function RSRoute.GetRoutableTargets(mapID)
    if (not mapID or IsInInstance() or not RSConfigDB.IsShowingNpcs()) then
        return {}
    end

    local POIs = RSMap.GetMapPOIs(mapID, true, false)
    if (not POIs or #POIs == 0) then 
        return {} end

    local targets = {}
    local function AddTarget(poi)
        table.insert(targets, {
            entityID = poi.entityID,
            x = RSUtils.FixCoord(poi.x),
            y = RSUtils.FixCoord(poi.y),
            name = poi.name
        })
    end

    for _, poi in ipairs(POIs) do
        if (poi.isGroup and poi.POIs) then
            for _, subPOI in ipairs(poi.POIs) do
                if (IsValidNpcTarget(subPOI)) then AddTarget(subPOI) end
            end
        elseif (IsValidNpcTarget(poi)) then
            AddTarget(poi)
        end
    end

    return targets
end

function RSRoute.StartNewRoute()
    if (IsInInstance()) then 
        return 
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    if (not mapID) then 
        return 
    end

    local playerPos = C_Map.GetPlayerMapPosition(mapID, "player")
    if (not playerPos) then 
        return 
    end

    local targets = RSRoute.GetRoutableTargets(mapID)
    if (#targets <= 1) then
        RSLogger:PrintMessage(AL["MAP_ROUTES_NOT_ENOUGH_RARES"])
        return
    end

    local startPos = { x = playerPos.x, y = playerPos.y }
    SolveHeldKarpAsync(startPos, targets, function(orderedTargets, minTotalCost)
        activeRoute.mapID = mapID
        activeRoute.nodes = orderedTargets
        activeRoute.isCompleted = false

        if (trackerTicker) then trackerTicker:Cancel() end
        trackerTicker = C_Timer.NewTicker(1.0, OnCheckProximity)

        StartMinimapUpdateTicker()
        RSRoute.RedrawCurrentRoute()
        RSRoute.UpdateMinimapRoute()
    end)
end

function RSRoute.ToggleOrRestartRoute()
    if (IsInInstance()) then 
        return
    end

    if (RSRoute.HasActiveRoute() and not RSRoute.IsCompleted()) then
        LibDialog:Spawn(RSConstants.RESET_ROUTE_CONFIRMATION)
    else
        RSRoute.StartNewRoute()
    end
end

function RSRoute.CancelRoute()
    if (activeCalculationRoutine) then
        activeCalculationRoutine:Reset()
        activeCalculationRoutine = nil
    end
    HideProgressBar()

    activeRoute.nodes = {}
    activeRoute.isCompleted = true
    if (trackerTicker) then
        trackerTicker:Cancel()
        trackerTicker = nil
    end
    StopMinimapUpdateTicker()
    ClearRoute()
    ClearMinimapRoute()
end

function RSRoute.HasActiveRoute()
    return activeRoute.nodes ~= nil and #activeRoute.nodes > 0
end

function RSRoute.GetActiveRouteMapID()
    return activeRoute.mapID
end

function RSRoute.IsCompleted()
    return activeRoute.isCompleted
end

function RSRoute.OnMapEntitiesChanged()
    if (not RSRoute.HasActiveRoute() or RSRoute.IsCompleted()) then 
        return 
    end

    local currentTargets = RSRoute.GetRoutableTargets(activeRoute.mapID)
    local validEntities = {}
    for _, t in ipairs(currentTargets) do
        validEntities[tonumber(t.entityID)] = true
    end

    local remainingNodes = {}
    for _, node in ipairs(activeRoute.nodes) do
        if (validEntities[tonumber(node.entityID)]) then
            table.insert(remainingNodes, node)
        end
    end

    activeRoute.nodes = remainingNodes

    if (#activeRoute.nodes == 0) then
        RSRoute.CancelRoute()
    else
        RSRoute.RedrawCurrentRoute()
        RSRoute.UpdateMinimapRoute()
    end
end

--- ============================================================================
--- Dynamic Target Updates
--- ============================================================================
function RSRoute.OnEntityFound(entityID, mapID, realX, realY)
    if (not RSRoute.HasActiveRoute() or RSRoute.IsCompleted() or activeRoute.mapID ~= mapID) then
        return
    end

    local fixedX = RSUtils.FixCoord(realX)
    local fixedY = RSUtils.FixCoord(realY)
    if (not fixedX or not fixedY) then 
        return 
    end

    for _, node in ipairs(activeRoute.nodes) do
        if (tonumber(node.entityID) == tonumber(entityID)) then
            if (node.x ~= fixedX or node.y ~= fixedY) then
                node.x = fixedX
                node.y = fixedY
                RSRoute.RedrawCurrentRoute()
                RSRoute.UpdateMinimapRoute()
            end
            break
        end
    end
end

function RSRoute.OnEntityDead(entityID)
    if (not RSRoute.HasActiveRoute() or RSRoute.IsCompleted()) then 
        return 
    end
    if (not RSNpcDB.IsNpcKilled(entityID)) then 
        return 
    end

    for i, node in ipairs(activeRoute.nodes) do
        if (tonumber(node.entityID) == tonumber(entityID)) then
            table.remove(activeRoute.nodes, i)
            if (#activeRoute.nodes == 0) then
                RSRoute.CancelRoute()
            else
                RSRoute.RedrawCurrentRoute()
                RSRoute.UpdateMinimapRoute()
            end
            break
        end
    end
end