local _, ns = ...

local MapSearch = ns.MapSearch
local Utils = ns.Utils
local MapUtils = ns.MapUtils
local MapFrames = ns.MapSearchFrames
local DebugPrint = Utils.DebugPrint

local pairs, ipairs = Utils.pairs, Utils.ipairs
local mmin, mmax = Utils.mmin, Utils.mmax
local pcall = Utils.pcall

local YELLOW_HIGHLIGHT = ns.YELLOW_HIGHLIGHT
local STAR_GLOW_TEXTURE = ns.MAP_SEARCH_STAR_GLOW_TEXTURE or "Interface\\Cooldown\\star4"

local CreateFrame = CreateFrame
local GetMapInfo = C_Map.GetMapInfo
local GetMapInfoAtPosition = C_Map.GetMapInfoAtPosition
local GetMapRectOnMap = C_Map.GetMapRectOnMap
local GetMapHighlightInfoAtPosition = C_Map.GetMapHighlightInfoAtPosition
local FindContainingZone = MapUtils.FindContainingZone
local GetMapRectViaContinent = MapUtils.GetMapRectViaContinent
local ResolveZoneForMap = MapUtils.ResolveZoneForMap

local zoneHighlightFrame
function MapSearch:CreateZoneHighlightFrame()
    zoneHighlightFrame = CreateFrame("Frame", "EasyFindZoneHighlight", WorldMapFrame.ScrollContainer.Child)
    zoneHighlightFrame:SetFrameStrata("TOOLTIP")
    zoneHighlightFrame:SetFrameLevel(400)
    zoneHighlightFrame:SetAllPoints(WorldMapFrame.ScrollContainer.Child)


    zoneHighlightFrame:EnableMouse(false)
    zoneHighlightFrame:Hide()

    zoneHighlightFrame.highlights = {}

    for i = 1, 10 do
        local highlight = zoneHighlightFrame:CreateTexture("EasyFindZoneHighlight"..i, "OVERLAY")
        highlight:SetColorTexture(Utils.RGB(YELLOW_HIGHLIGHT, 0.5))
        highlight:SetDrawLayer("OVERLAY", 7)
        highlight:Hide()
        zoneHighlightFrame.highlights[i] = highlight
    end

    MapFrames.AttachBounceAnimation(zoneHighlightFrame, { fromAlpha = 0.75, toAlpha = 0.5 })

    local zoneInd = MapFrames.CreateIndicatorFrame("EasyFindZoneIndicator", WorldMapFrame.ScrollContainer.Child, {
        strata = "TOOLTIP",
        level = 500,
        size = ns.ICON_SIZE,
        moveKey = "translateAnim",
    })

    zoneInd:Hide()
    zoneHighlightFrame.indicator = zoneInd
end



local function ScanZoneBoundsOnMap(targetMapID, viewMapID, projL, projR, projT, projB)
    local pad = 0.05
    local minX = mmax(0, (projL or 0) - pad)
    local maxX = mmin(1, (projR or 1) + pad)
    local minY = mmax(0, (projT or 0) - pad)
    local maxY = mmin(1, (projB or 1) + pad)

    local step = 0.01
    local foundL, foundR, foundT, foundB
    local x = minX
    while x <= maxX do
        local y = minY
        while y <= maxY do
            local info = GetMapInfoAtPosition(viewMapID, x, y)
            if info and info.mapID == targetMapID then
                if not foundL then
                    foundL, foundR, foundT, foundB = x, x, y, y
                else
                    if x < foundL then foundL = x end
                    if x > foundR then foundR = x end
                    if y < foundT then foundT = y end
                    if y > foundB then foundB = y end
                end
            end
            y = y + step
        end
        x = x + step
    end

    if not foundL then return nil end
    local inset = step * 0.5
    return foundL + inset, foundR - inset, foundT + inset, foundB - inset
end





local function RegionBoundsOnMap(targetMapID, viewMapID, l, r, t, b)
    local GetWorldPos = C_Map.GetWorldPosFromMapPos
    if not (GetWorldPos and CreateVector2D) then return nil end
    local instance = GetWorldPos(targetMapID, CreateVector2D(0.5, 0.5))
    if not instance then return nil end
    local step = 0.02
    local pos = CreateVector2D(0, 0)
    local minX, maxX, minY, maxY
    for x = mmax(0, l), mmin(1, r), step do
        for y = mmax(0, t), mmin(1, b), step do
            pos:SetXY(x, y)
            if GetWorldPos(viewMapID, pos) == instance then
                if not minX or x < minX then minX = x end
                if not maxX or x > maxX then maxX = x end
                if not minY or y < minY then minY = y end
                if not maxY or y > maxY then maxY = y end
            end
        end
    end
    if not minX then return nil end
    return minX, mmin(1, maxX + step), minY, mmin(1, maxY + step)
end




function MapSearch:PreviewZoneHighlight(mapID)
    if not zoneHighlightFrame then return end
    if not WorldMapFrame or not WorldMapFrame.ScrollContainer then return end
    local canvas = WorldMapFrame.ScrollContainer.Child
    if not canvas then return end

    local parentMapID = WorldMapFrame:GetMapID()
    if not parentMapID then return end

    local resolved = ResolveZoneForMap(mapID, parentMapID)
    if resolved ~= mapID then mapID = resolved end


    local zoneInfo = GetMapInfo(mapID)
    if not zoneInfo or zoneInfo.parentMapID ~= parentMapID then return end

    local ok, left, right, top, bottom = pcall(GetMapRectOnMap, mapID, parentMapID)
    if not ok or not left then return end

    if left == 0 and right == 0 and top == 0 and bottom == 0 then
        local pL, pR, pT, pB = GetMapRectViaContinent(mapID, parentMapID)
        if not pL then return end
        left, right, top, bottom = pL, pR, pT, pB
    end


    if (right - left) < 0.01 or (bottom - top) < 0.01 then return end
    if (right - left) > 1.05 or (bottom - top) > 1.05 then return end
    if right < 0.02 or left > 0.98 or bottom < 0.02 or top > 0.98 then return end

    local clampedL = mmax(0, left)
    local clampedR = mmin(1, right)
    local clampedT = mmax(0, top)
    local clampedB = mmin(1, bottom)
    if (clampedR - clampedL) < 0.01 or (clampedB - clampedT) < 0.01 then return end

    if (clampedR - clampedL) >= 0.95 and (clampedB - clampedT) >= 0.95 then return end

    local canvasWidth, canvasHeight = canvas:GetSize()
    local centerX = (left + right) / 2
    local centerY = (top + bottom) / 2
    local zoneCenterPxX = centerX * canvasWidth
    local zoneCenterPxY = centerY * canvasHeight


    for i = 1, #zoneHighlightFrame.highlights do
        local hl = zoneHighlightFrame.highlights[i]
        hl:Hide()
        hl:ClearAllPoints()
        hl:SetTexture(nil)
        hl:SetTexCoord(0, 1, 0, 1)
    end



    local highlightSuccess, fileDataID, atlasID, texPercentX, texPercentY, texWidth, texHeight, posX, posY =
        pcall(GetMapHighlightInfoAtPosition, parentMapID, centerX, centerY)

    local hasTexture = highlightSuccess and posX and posY and texPercentX and texPercentY
        and ((fileDataID and fileDataID > 0) or (atlasID and atlasID ~= ""))

    if hasTexture then
        local resolvedInfo = GetMapInfoAtPosition(parentMapID, centerX, centerY)
        if resolvedInfo and resolvedInfo.mapID ~= mapID then
            hasTexture = false
        end
    end

    if hasTexture then
        local pixelPosX = posX * canvasWidth
        local pixelPosY = posY * canvasHeight
        local pixelWidth = texWidth * canvasWidth
        local pixelHeight = texHeight * canvasHeight
        local isAtlas = not fileDataID or fileDataID == 0

        local layers = isAtlas and 2 or 4
        for i = 1, layers do
            local hl = zoneHighlightFrame.highlights[i]
            if hl then
                hl:ClearAllPoints()
                if not isAtlas then
                    hl:SetTexture(fileDataID)
                    hl:SetTexCoord(0, texPercentX, 0, texPercentY)
                    hl:SetPoint("TOPLEFT", canvas, "TOPLEFT", pixelPosX, -pixelPosY)
                    hl:SetSize(pixelWidth, pixelHeight)
                    hl:SetVertexColor(Utils.RGB(YELLOW_HIGHLIGHT, 1))
                else
                    hl:SetAtlas(atlasID, true)
                    hl:SetPoint("CENTER", canvas, "TOPLEFT", zoneCenterPxX, -zoneCenterPxY)
                    hl:SetVertexColor(Utils.RGB(YELLOW_HIGHLIGHT, 0.6))
                end
                hl:SetBlendMode("ADD")
                hl:Show()
            end
        end
    else

        local x = clampedL * canvasWidth
        local y = clampedT * canvasHeight
        local w = (clampedR - clampedL) * canvasWidth
        local h = (clampedB - clampedT) * canvasHeight

        local highlight = zoneHighlightFrame.highlights[1]
        if highlight then
            highlight:ClearAllPoints()
            highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
            highlight:SetTexCoord(0, 1, 0, 1)
            highlight:SetVertexColor(Utils.RGB(YELLOW_HIGHLIGHT, 0.20))
            highlight:SetBlendMode("BLEND")
            highlight:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -y)
            highlight:SetSize(w, h)
            highlight:Show()
        end
    end

    zoneHighlightFrame:Show()
end

function MapSearch:HighlightZone(mapID)
    DebugPrint("HighlightZone called for mapID:", mapID)

    if not zoneHighlightFrame then
        DebugPrint("HighlightZone: no zoneHighlightFrame!")
        return
    end



    local savedPending, savedGuide = self.pendingZoneHighlight, self._zoneGuide
    local hintShown = self.zoomOutHint ~= nil and self.zoomOutHint:IsShown()
    DebugPrint("HighlightZone: saved pending:", savedPending)

    self:ClearZoneHighlight()

    self.pendingZoneHighlight, self._zoneGuide = savedPending, savedGuide
    if hintShown then self.zoomOutHint:Show() end
    DebugPrint("HighlightZone: restored pending:", self.pendingZoneHighlight)

    local canvas = WorldMapFrame.ScrollContainer.Child
    if not canvas then
        DebugPrint("HighlightZone: no canvas!")
        return
    end

    local mapInfo = GetMapInfo(mapID)
    if not mapInfo then
        DebugPrint("HighlightZone: no mapInfo for", mapID)
        return
    end
    DebugPrint("HighlightZone: zone name:", mapInfo.name, "mapType:", mapInfo.mapType)

    local parentMapID = WorldMapFrame:GetMapID()
    if not parentMapID then return end

    local resolved = ResolveZoneForMap(mapID, parentMapID)
    if resolved ~= mapID then
        mapID = resolved
        mapInfo = GetMapInfo(mapID)
        if not mapInfo then return end
    end

    local isZone = mapInfo.mapType == Enum.UIMapType.Zone

    local success, left, right, top, bottom = pcall(GetMapRectOnMap, mapID, parentMapID)

    if not success or not left then return end


    if left == 0 and right == 0 and top == 0 and bottom == 0 then
        local pL, pR, pT, pB = GetMapRectViaContinent(mapID, parentMapID)
        if pL then
            left, right, top, bottom = pL, pR, pT, pB
            DebugPrint("HighlightZone: used continent projection for coords")
        else

            local minX, maxX, minY, maxY = 2, -1, 2, -1
            for sx = 0.025, 0.975, 0.05 do
                for sy = 0.025, 0.975, 0.05 do
                    local info = GetMapInfoAtPosition(parentMapID, sx, sy)
                    if info and info.mapID == mapID then
                        if sx < minX then minX = sx end
                        if sx > maxX then maxX = sx end
                        if sy < minY then minY = sy end
                        if sy > maxY then maxY = sy end
                    end
                end
            end
            if maxX > minX then
                left, right, top, bottom = minX, maxX, minY, maxY
                DebugPrint("HighlightZone: found via blind scan", minX, maxX, minY, maxY)
            else
                MapSearch.TurnMap(mapID)
                return
            end
        end
    end

    local canvasWidth, canvasHeight = canvas:GetSize()
    local centerX = (left + right) / 2
    local centerY = (top + bottom) / 2
    local zoneCenterPxX = centerX * canvasWidth
    local zoneCenterPxY = centerY * canvasHeight
    local width = (right - left) * canvasWidth
    local height = (bottom - top) * canvasHeight
    local zoneTopPx = top * canvasHeight
    local zoneBottomPx = bottom * canvasHeight
    local zoneLeftPx = left * canvasWidth
    local zoneRightPx = right * canvasWidth

    local highlightSuccess, fileDataID, atlasID, texPercentX, texPercentY, texWidth, texHeight, posX, posY =
        pcall(GetMapHighlightInfoAtPosition, parentMapID, centerX, centerY)

    local highlight = zoneHighlightFrame.highlights[1]
    if not highlight then return end
    highlight:ClearAllPoints()

    local hasTexture = highlightSuccess and posX and posY and texPercentX and texPercentY
        and ((fileDataID and fileDataID > 0) or (atlasID and atlasID ~= ""))


    if hasTexture and isZone then
        local resolvedInfo = GetMapInfoAtPosition(parentMapID, centerX, centerY)
        if resolvedInfo and resolvedInfo.mapID ~= mapID then
            hasTexture = false
        end
    end




    if not hasTexture and isZone then
        local parentMapInfo = GetMapInfo(parentMapID)
        if parentMapInfo and parentMapInfo.mapType == Enum.UIMapType.Continent then
            local cx = (left + right) * 0.5
            local cy = (top + bottom) * 0.5
            local centerInfo = GetMapInfoAtPosition(parentMapID, cx, cy)
            local isBuggedZone = not centerInfo
                or centerInfo.mapType ~= Enum.UIMapType.Zone
            if not isBuggedZone then
                local containing = FindContainingZone(mapID, parentMapID)
                if containing then
                    self.pendingZoneHighlight = mapID
                    self:HighlightZone(containing.mapID)
                    return
                end
            end
        end
    end
    if hasTexture then
        local pixelPosX = posX * canvasWidth
        local pixelPosY = posY * canvasHeight
        local pixelWidth = texWidth * canvasWidth
        local pixelHeight = texHeight * canvasHeight
        local isAtlas = not fileDataID or fileDataID == 0



        if not isAtlas then
            zoneLeftPx, zoneTopPx = pixelPosX, pixelPosY
            zoneRightPx, zoneBottomPx = pixelPosX + pixelWidth, pixelPosY + pixelHeight
            zoneCenterPxX, zoneCenterPxY = pixelPosX + pixelWidth / 2, pixelPosY + pixelHeight / 2



            local l, r, t, b = posX, posX + texWidth, posY, posY + texHeight
            if l < 0 or r > 1 or t < 0 or b > 1 or (r - l) * (b - t) > 0.3 then
                local sL, sR, sT, sB = RegionBoundsOnMap(mapID, parentMapID, l, r, t, b)
                if sL then
                    zoneLeftPx, zoneTopPx = sL * canvasWidth, sT * canvasHeight
                    zoneRightPx, zoneBottomPx = sR * canvasWidth, sB * canvasHeight
                    zoneCenterPxX, zoneCenterPxY = (zoneLeftPx + zoneRightPx) / 2, (zoneTopPx + zoneBottomPx) / 2
                end
            end
        end

        local layers = isAtlas and 2 or 4
        for i = 1, layers do
            local hl = zoneHighlightFrame.highlights[i]
            if hl then
                hl:ClearAllPoints()
                if not isAtlas then
                    hl:SetTexture(fileDataID)
                    hl:SetTexCoord(0, texPercentX, 0, texPercentY)
                    hl:SetPoint("TOPLEFT", canvas, "TOPLEFT", pixelPosX, -pixelPosY)
                    hl:SetSize(pixelWidth, pixelHeight)
                    hl:SetVertexColor(Utils.RGB(YELLOW_HIGHLIGHT, 1))
                else
                    hl:SetAtlas(atlasID, true)
                    hl:SetPoint("CENTER", canvas, "TOPLEFT", zoneCenterPxX, -zoneCenterPxY)
                    hl:SetVertexColor(Utils.RGB(YELLOW_HIGHLIGHT, 0.6))
                end
                hl:SetBlendMode("ADD")
                hl:Show()
            end
        end
    else
        if isZone then
            local parentMapInfo = GetMapInfo(parentMapID)



            if parentMapInfo and parentMapInfo.mapType == Enum.UIMapType.Zone then
                local sL, sR, sT, sB = ScanZoneBoundsOnMap(mapID, parentMapID, left, right, top, bottom)
                local projW, projH = right - left, bottom - top
                if sL and (sR - sL) > projW * 0.15 and (sB - sT) > projH * 0.15 then
                    left, right, top, bottom = sL, sR, sT, sB
                    DebugPrint("HighlightZone: using scanned bounds")
                else
                    DebugPrint("HighlightZone: scan too small, using projection")
                end
                centerX = (left + right) / 2
                centerY = (top + bottom) / 2
                width = (right - left) * canvasWidth
                height = (bottom - top) * canvasHeight
                zoneCenterPxX = centerX * canvasWidth
                zoneCenterPxY = centerY * canvasHeight
                zoneTopPx = top * canvasHeight
                zoneBottomPx = bottom * canvasHeight
                zoneLeftPx = left * canvasWidth
                zoneRightPx = right * canvasWidth
            end
        end


        local isFinalTarget = self.pendingZoneHighlight == mapID


        if isFinalTarget then
            DebugPrint("Final target, adding click overlay for:", mapID)
            if not zoneHighlightFrame.clickOverlay then
                zoneHighlightFrame.clickOverlay = CreateFrame("Button", nil, canvas)
                zoneHighlightFrame.clickOverlay:SetFrameStrata("DIALOG")
            end
            local overlay = zoneHighlightFrame.clickOverlay
            overlay:ClearAllPoints()
            overlay:SetPoint("TOPLEFT", canvas, "TOPLEFT", zoneLeftPx, -zoneTopPx)
            overlay:SetSize(width, height)
            overlay.targetMapID = mapID
            overlay:SetScript("OnClick", function(self)
                self:Hide()
                local ms = ns.MapSearch
                if ms then ms.pendingZoneHighlight = nil end
                MapSearch.TurnMap(self.targetMapID)
            end)
            overlay:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                local info = GetMapInfo(self.targetMapID)
                GameTooltip:SetText(info and info.name or "")
                GameTooltip:Show()
            end)
            overlay:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            overlay:Show()
        end

        if isFinalTarget and not hasTexture then
            if not zoneHighlightFrame.centerGlow then
                local glow = canvas:CreateTexture(nil, "ARTWORK")
                glow:SetTexture(STAR_GLOW_TEXTURE)
                glow:SetVertexColor(Utils.RGB(YELLOW_HIGHLIGHT, 0.4))
                glow:SetBlendMode("ADD")
                zoneHighlightFrame.centerGlow = glow
                zoneHighlightFrame.centerGlowAnim = MapFrames.AttachBounceAnimation(glow, {
                    fromAlpha = 0.25,
                    toAlpha = 0.55,
                    duration = 0.8,
                    smoothing = "IN_OUT",
                })
            end
            local glow = zoneHighlightFrame.centerGlow
            local glowSize = mmin(width, height) * 1.2
            glow:ClearAllPoints()
            glow:SetPoint("CENTER", canvas, "TOPLEFT",
                zoneLeftPx + width * 0.5, -(zoneTopPx + height * 0.5))
            glow:SetSize(glowSize, glowSize)
            glow:Show()
            zoneHighlightFrame.centerGlowAnim:Play()
        end

        if not isFinalTarget then

            local borderW = 2
            highlight:SetColorTexture(Utils.RGB(YELLOW_HIGHLIGHT, 0.15))
            highlight:SetBlendMode("BLEND")
            highlight:SetPoint("TOPLEFT", canvas, "TOPLEFT", zoneLeftPx, -zoneTopPx)
            highlight:SetSize(width, height)
            highlight:Show()

            local edges = {
                { "TOPLEFT", "TOPLEFT", zoneLeftPx, -zoneTopPx, width, borderW },
                { "TOPLEFT", "TOPLEFT", zoneLeftPx, -(zoneTopPx + height - borderW), width, borderW },
                { "TOPLEFT", "TOPLEFT", zoneLeftPx, -zoneTopPx, borderW, height },
                { "TOPLEFT", "TOPLEFT", zoneLeftPx + width - borderW, -zoneTopPx, borderW, height },
            }
            for i = 1, 4 do
                local hl = zoneHighlightFrame.highlights[i + 1]
                if hl then
                    local e = edges[i]
                    hl:ClearAllPoints()
                    hl:SetColorTexture(Utils.RGB(YELLOW_HIGHLIGHT, 0.8))
                    hl:SetBlendMode("BLEND")
                    hl:SetPoint(e[1], canvas, e[2], e[3], e[4])
                    hl:SetSize(e[5], e[6])
                    hl:Show()
                end
            end
        end
    end

    DebugPrint("HighlightZone: About to show frame")
    zoneHighlightFrame:Show()
    DebugPrint("HighlightZone: zoneHighlightFrame:IsShown() =", zoneHighlightFrame:IsShown())
    zoneHighlightFrame.animGroup:Play()
    DebugPrint("HighlightZone: highlight and frame shown")

    if zoneHighlightFrame.indicator then
        local zoneInd = zoneHighlightFrame.indicator
        local userScale = EasyFind.db.iconScale or 0.8
        local indicatorSize     = ns.UIToCanvas(ns.ZONE_ICON_SIZE)      * userScale
        local indicatorGlowSize = ns.UIToCanvas(ns.ZONE_ICON_GLOW_SIZE) * userScale
        zoneInd:SetSize(indicatorSize, indicatorSize)
        zoneInd:SetFrameStrata("TOOLTIP")
        zoneInd:SetFrameLevel(500)
        if zoneInd.glow then
            zoneInd.glow:SetSize(indicatorGlowSize, indicatorGlowSize)
        end

        local margin = 50

        zoneInd:ClearAllPoints()

        DebugPrint("HighlightZone: indicator positioning - zoneTopPx:", zoneTopPx, "margin+indicatorSize:", margin + indicatorSize)

        local gap = 25
        if zoneTopPx > margin + indicatorSize then
            zoneInd.indicatorDirection = "down"
            zoneInd:SetPoint("BOTTOM", canvas, "TOPLEFT", zoneCenterPxX, -(zoneTopPx - gap))
            DebugPrint("Indicator placed ABOVE zone")
        elseif (canvasHeight - zoneBottomPx) > margin + indicatorSize then
            zoneInd.indicatorDirection = "up"
            zoneInd:SetPoint("TOP", canvas, "TOPLEFT", zoneCenterPxX, -(zoneBottomPx + gap))
            DebugPrint("Indicator placed BELOW zone")
        elseif zoneLeftPx > margin + indicatorSize then
            zoneInd.indicatorDirection = "right"
            zoneInd:SetPoint("RIGHT", canvas, "TOPLEFT", zoneLeftPx - gap, -zoneCenterPxY)
            DebugPrint("Indicator placed LEFT of zone")
        else
            zoneInd.indicatorDirection = "left"
            zoneInd:SetPoint("LEFT", canvas, "TOPLEFT", zoneRightPx + gap, -zoneCenterPxY)
            DebugPrint("Indicator placed RIGHT of zone")
        end

        if zoneInd.translateAnim then
            if zoneInd.indicatorDirection == "down" then
                zoneInd.translateAnim:SetOffset(0, -10)
            elseif zoneInd.indicatorDirection == "up" then
                zoneInd.translateAnim:SetOffset(0, 10)
            elseif zoneInd.indicatorDirection == "right" then
                zoneInd.translateAnim:SetOffset(10, 0)
            elseif zoneInd.indicatorDirection == "left" then
                zoneInd.translateAnim:SetOffset(-10, 0)
            end
        end

        zoneInd:Show()
        if zoneInd.animGroup then
            zoneInd.animGroup:Play()
        end
        DebugPrint("Indicator shown")
    else
        DebugPrint("HighlightZone: no indicator frame!")
    end

    DebugPrint("HighlightZone: COMPLETE for zone:", mapInfo.name)

    return true
end



function MapSearch:ClearZoneHighlight(preserveBreadcrumb)

    if self.zoomOutHint and not preserveBreadcrumb then self.zoomOutHint:Hide() end
    if not zoneHighlightFrame then return end

    for _, highlight in ipairs(zoneHighlightFrame.highlights) do
        highlight:SetTexture(nil)
        highlight:SetTexCoord(0, 1, 0, 1)
        highlight:Hide()
    end

    if zoneHighlightFrame.border then
        for _, border in pairs(zoneHighlightFrame.border) do
            border:Hide()
        end
    end

    if zoneHighlightFrame.centerGlow then
        zoneHighlightFrame.centerGlow:Hide()
        if zoneHighlightFrame.centerGlowAnim then
            zoneHighlightFrame.centerGlowAnim:Stop()
        end
    end

    if zoneHighlightFrame.clickOverlay then
        zoneHighlightFrame.clickOverlay:Hide()
    end

    if zoneHighlightFrame.indicator then
        zoneHighlightFrame.indicator:Hide()
        if zoneHighlightFrame.indicator.animGroup then
            zoneHighlightFrame.indicator.animGroup:Stop()
        end
    end

    if zoneHighlightFrame.animGroup then
        zoneHighlightFrame.animGroup:Stop()
    end

    zoneHighlightFrame:Hide()

    if preserveBreadcrumb then return end

    if self.breadcrumbHighlight then
        if self.breadcrumbHighlight.indicatorFrame then
            self.breadcrumbHighlight.indicatorFrame:Hide()
            if self.breadcrumbHighlight.indicatorFrame.animGroup then
                self.breadcrumbHighlight.indicatorFrame.animGroup:Stop()
            end
        end
        if self.breadcrumbHighlight.glowAnim then
            self.breadcrumbHighlight.glowAnim:Stop()
        end
        self.breadcrumbHighlight:Hide()
    end


    self.pendingZoneHighlight = nil
    self._zoneGuide = nil
end

function MapSearch:IsOnContinentMap()
    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return false end

    local mapInfo = GetMapInfo(mapID)
    if not mapInfo then return false end

    return mapInfo.mapType == Enum.UIMapType.Continent or mapInfo.mapType == Enum.UIMapType.World
end


function MapSearch:GetZoneHighlightFrame()
    return zoneHighlightFrame
end
