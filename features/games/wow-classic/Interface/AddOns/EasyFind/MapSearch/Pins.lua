local _, ns = ...

local MapSearch = ns.MapSearch
local Utils = ns.Utils

local ipairs = Utils.ipairs
local mmax = Utils.mmax
local pcall = Utils.pcall
local GetPlayerMapPosition = C_Map.GetPlayerMapPosition




local highlightedNativePin = nil

local function RestoreNativePinScale()
    local p = highlightedNativePin
    if not p then return end
    if p._easyfindOriginalScale and p.SetScale then
        pcall(p.SetScale, p, p._easyfindOriginalScale)
    end
    p._easyfindOriginalScale = nil
    highlightedNativePin = nil
end

function MapSearch:GetNearestInstance(instances, mapID)
    if #instances == 1 then return instances[1] end
    local pos = GetPlayerMapPosition(mapID, "player")
    if not pos then return instances[1] end
    local px, py = pos:GetXY()
    local nearest, bestDist = instances[1], math.huge
    for _, inst in ipairs(instances) do
        if inst.x and inst.y then
            local dx, dy = inst.x - px, inst.y - py
            local dist = dx * dx + dy * dy
            if dist < bestDist then
                bestDist = dist
                nearest = inst
            end
        end
    end
    return nearest
end

function MapSearch:TrackActivePin()
    local activePinState = self:GetActivePinState()
    if not activePinState then return end
    local mapID = activePinState.mapID
    local x, y
    if activePinState.instances then
        local nearest = self:GetNearestInstance(activePinState.instances, mapID)
        if nearest then
            x, y = nearest.x, nearest.y

            self:ShowWaypointAt(x, y, nil, nearest.category)
        end
    else
        x, y = activePinState.x, activePinState.y
    end
    if not mapID or not x or not y then return end
    if x < 0 or x > 1 or y < 0 or y > 1 then return end

    self:PlaceUserWaypointAt(mapID, x, y)
    self.TrackWaypoint(true)
end

function MapSearch:UpdateBlinkingPins()
    local blinking = EasyFind.db.blinkingPins

    local function Toggle(frame)
        if not frame or not frame.animGroup then return end
        if blinking and frame:IsShown() then
            frame.animGroup:Play()
        else
            frame.animGroup:Stop()
            frame:SetAlpha(1)
        end
    end

    local waypointPin, highlightFrame = self:GetMapVisualFrames()


    Toggle(waypointPin)
    Toggle(highlightFrame)

    if self.extraPins then
        for _, pin in ipairs(self.extraPins) do Toggle(pin) end
    end
    if self.extraHighlights then
        for _, hl in ipairs(self.extraHighlights) do Toggle(hl) end
    end
end

function MapSearch:UpdatePinHighlight()
    local _, highlightFrame = self:GetMapVisualFrames()
    if highlightFrame and highlightFrame:IsShown() then
        self:ApplyHighlightStyle(highlightFrame)
    end
    if self.extraHighlights then
        for _, hl in ipairs(self.extraHighlights) do
            if hl:IsShown() then
                self:ApplyHighlightStyle(hl)
            end
        end
    end
end

function MapSearch:UpdateIconScales()
    local canvas = WorldMapFrame.ScrollContainer.Child
    if not canvas then return end

    local userScale = EasyFind.db.iconScale or 0.8

    local iconSize      = ns.UIToCanvas(ns.PIN_SIZE)       * userScale
    local glowSize      = ns.UIToCanvas(ns.PIN_GLOW_SIZE)  * userScale
    local highlightSize = ns.UIToCanvas(ns.HIGHLIGHT_SIZE) * userScale
    local indicatorSize     = ns.UIToCanvas(ns.ICON_SIZE)      * userScale
    local indicatorGlowSize = ns.UIToCanvas(ns.ICON_GLOW_SIZE) * userScale

    local function resizeIndicator(frame, aSize, gSize)
        if not frame then return end
        frame:SetSize(aSize, aSize)
        if frame.indicator then frame.indicator:SetSize(aSize, aSize) end
        if frame.glow then frame.glow:SetSize(gSize, gSize) end
    end

    local waypointPin, highlightFrame, indicatorFrame = self:GetMapVisualFrames()

    if waypointPin then
        waypointPin:SetSize(iconSize, iconSize)
        if waypointPin.glow then
            waypointPin.glow:SetSize(glowSize, glowSize)
        end
    end

    if highlightFrame and highlightFrame:IsShown() then
        highlightFrame:SetSize(highlightSize, highlightSize)
        self:ResizeHighlightBorders(highlightFrame)
    end

    resizeIndicator(indicatorFrame, indicatorSize, indicatorGlowSize)

    local zoneIndSize     = ns.UIToCanvas(ns.ZONE_ICON_SIZE)      * userScale
    local zoneIndGlowSize = ns.UIToCanvas(ns.ZONE_ICON_GLOW_SIZE) * userScale
    local zoneHighlightFrame = self.GetZoneHighlightFrame and self:GetZoneHighlightFrame()
    if zoneHighlightFrame and zoneHighlightFrame.indicator then
        resizeIndicator(zoneHighlightFrame.indicator, zoneIndSize, zoneIndGlowSize)
    end

    local ms = ns.MULTI_SCALE
    local multiIconSize      = ns.UIToCanvas(ns.PIN_SIZE       * ms) * userScale
    local multiGlowSize      = ns.UIToCanvas(ns.PIN_GLOW_SIZE  * ms) * userScale
    local multiHighlightSize = ns.UIToCanvas(ns.HIGHLIGHT_SIZE * ms) * userScale
    local multiIndSize       = ns.UIToCanvas(ns.ICON_SIZE      * ms) * userScale
    local multiIndGlowSize   = ns.UIToCanvas(ns.ICON_GLOW_SIZE * ms) * userScale

    if self.extraPins then
        for _, pin in ipairs(self.extraPins) do
            if pin:IsShown() then
                pin:SetSize(multiIconSize, multiIconSize)
                if pin.glow then
                    pin.glow:SetSize(multiGlowSize, multiGlowSize)
                end
            end
        end
    end

    if self.extraHighlights then
        for _, hl in ipairs(self.extraHighlights) do
            if hl:IsShown() then
                hl:SetSize(multiHighlightSize, multiHighlightSize)
                self:ResizeHighlightBorders(hl)
            end
        end
    end

    if self.extraIndicators then
        for _, arr in ipairs(self.extraIndicators) do
            resizeIndicator(arr, multiIndSize, multiIndGlowSize)
        end
    end
end

function MapSearch:RefreshIndicators()
    local mapInd = _G["EasyFindMapIndicator"]
    if mapInd then ns.UpdateIndicator(mapInd) end

    local zoneInd = _G["EasyFindZoneIndicator"]
    if zoneInd then ns.UpdateIndicator(zoneInd) end

    if self.breadcrumbHighlight and self.breadcrumbHighlight.indicatorFrame then
        ns.UpdateIndicator(self.breadcrumbHighlight.indicatorFrame)
    end

    if self.extraIndicators then
        for _, ind in ipairs(self.extraIndicators) do
            ns.UpdateIndicator(ind)
        end
    end

    local guideInd = _G["EasyFindIndicatorFrame"]
    if guideInd then ns.UpdateIndicator(guideInd) end
end

function MapSearch:HighlightPin(pin, x, y, icon, category)
    local waypointPin, highlightFrame, indicatorFrame = self:GetMapVisualFrames()
    waypointPin:Hide()


    RestoreNativePinScale()

    if not pin or not pin:IsShown() then


        if x and y then
            self:ShowWaypointAt(x, y, icon, category)
            return
        end
        self:ClearHighlight()
        return
    end



    if x and y then
        self:SetActivePinState({
            mapID = WorldMapFrame:GetMapID(),
            x = x, y = y,
            icon = icon, category = category,
            isLocal = not MapSearch:IsGlobalSearchActive(),
        })
    end




    local userScale = EasyFind.db.iconScale or 0.8
    local nativePinScale = (EasyFind.db.nativePinScale or 1.5) * userScale
    if pin.SetScale and pin.GetScale then
        pin._easyfindOriginalScale = pin._easyfindOriginalScale or (pin:GetScale() or 1)
        pcall(pin.SetScale, pin, pin._easyfindOriginalScale * nativePinScale)
        highlightedNativePin = pin
    end

    local width, height = pin:GetSize()
    local minPinSize = ns.UIToCanvas(36) * userScale
    width = mmax(width or 24, minPinSize)
    height = mmax(height or 24, minPinSize)

    local indicatorSize     = ns.UIToCanvas(ns.ICON_SIZE)      * userScale
    local indicatorGlowSize = ns.UIToCanvas(ns.ICON_GLOW_SIZE) * userScale
    indicatorFrame:SetSize(indicatorSize, indicatorSize)
    indicatorFrame.glow:SetSize(indicatorGlowSize, indicatorGlowSize)

    highlightFrame:SetSize(width, height)
    highlightFrame:ClearAllPoints()
    highlightFrame:SetPoint("CENTER", pin, "CENTER", 0, 0)
    self:ResizeHighlightBorders(highlightFrame)
    highlightFrame:Show()
    self:ApplyHighlightStyle(highlightFrame)
    indicatorFrame:Show()

    if indicatorFrame.animGroup then
        indicatorFrame.animGroup:Play()
    end
    if EasyFind.db.blinkingPins and highlightFrame.animGroup then
        highlightFrame.animGroup:Play()
    end
end

function MapSearch:ClearHighlight()
    local waypointPin, highlightFrame, indicatorFrame = self:GetMapVisualFrames()
    if not highlightFrame then return end


    RestoreNativePinScale()

    highlightFrame:Hide()
    highlightFrame.top:Show()
    highlightFrame.bottom:Show()
    highlightFrame.left:Show()
    highlightFrame.right:Show()

    indicatorFrame:Hide()
    waypointPin:Hide()



    waypointPin:SetFrameStrata("HIGH")
    waypointPin:SetFrameLevel(2000)
    waypointPin:EnableMouse(true)



    self:RefreshAllClearButtons()
    waypointPin.waypointX = nil
    waypointPin.waypointY = nil
    waypointPin.isLocalSearch = nil
    if highlightFrame.animGroup then
        highlightFrame.animGroup:Stop()
    end
    if indicatorFrame.animGroup then
        indicatorFrame.animGroup:Stop()
    end
    if waypointPin.animGroup then
        waypointPin.animGroup:Stop()
    end


    if self.extraPins then
        for _, pin in ipairs(self.extraPins) do
            pin:Hide()
            pin:EnableMouse(true)
            pin.waypointX = nil
            pin.waypointY = nil
            pin.isLocalSearch = nil
            if pin.animGroup then pin.animGroup:Stop() end
        end
    end
    if self.extraHighlights then
        for _, hl in ipairs(self.extraHighlights) do
            hl:Hide()
            if hl.animGroup then hl.animGroup:Stop() end
        end
    end
    if self.extraIndicators then
        for _, arr in ipairs(self.extraIndicators) do
            arr:Hide()
            if arr.animGroup then arr.animGroup:Stop() end
        end
    end

end



