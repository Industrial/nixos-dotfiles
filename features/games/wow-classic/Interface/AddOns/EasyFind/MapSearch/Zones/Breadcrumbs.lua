local _, ns = ...

local MapSearch = ns.MapSearch
local Utils = ns.Utils
local MapUtils = ns.MapUtils
local MapFrames = ns.MapSearchFrames
local DebugPrint = Utils.DebugPrint

local ipairs, type, select = Utils.ipairs, Utils.type, Utils.select

local GOLD_COLOR = ns.GOLD_COLOR
local L = ns.L
local CreateFrame = CreateFrame
local UIParent = UIParent
local GetMapInfo = C_Map.GetMapInfo
local GetMapPath = MapUtils.GetMapPath
function MapSearch:HighlightBreadcrumbForNavigation(dcaMapID, finalTargetMapID, targetParentPath, dcaIndex)
    DebugPrint("HighlightBreadcrumbForNavigation: DCA=", dcaMapID, "finalTarget=", finalTargetMapID)

    local guide = self._zoneGuide
    self:ClearZoneHighlight()
    self._zoneGuide = guide

    local navBar = WorldMapFrame.NavBar
    if not navBar then


        self:ShowZoomOutHint(finalTargetMapID)
        return
    end

    DebugPrint("Searching for breadcrumb button for DCA ID:", dcaMapID)

    local buttonToHighlight = self:FindBreadcrumbButton(navBar, dcaMapID)

    if not buttonToHighlight then
        DebugPrint("DCA button not found, trying ancestors...")
        for i = dcaIndex - 1, 1, -1 do
            local ancestorMapID = targetParentPath[i] and targetParentPath[i].mapID
            if ancestorMapID then
                DebugPrint("Trying ancestor:", ancestorMapID)
                buttonToHighlight = self:FindBreadcrumbButton(navBar, ancestorMapID)
                if buttonToHighlight then
                    DebugPrint("Found button for ancestor:", ancestorMapID)
                    break
                end
            end
        end
    else
        DebugPrint("Found button for DCA directly")
    end

    if buttonToHighlight and buttonToHighlight:IsShown() then
        DebugPrint("Button found and shown, highlighting it")
        self:ShowBreadcrumbHighlight(buttonToHighlight, finalTargetMapID)
    else
        DebugPrint("No button found, walking current path for fallback")
        local currentMapID = WorldMapFrame:GetMapID()
        local currentPath = GetMapPath(currentMapID)
        for i = 1, #currentPath - 1 do
            local breadcrumbBtn = self:FindBreadcrumbButton(navBar, currentPath[i].mapID)
            if breadcrumbBtn and breadcrumbBtn:IsShown() then
                buttonToHighlight = breadcrumbBtn
                DebugPrint("Using path fallback:", currentPath[i].name, currentPath[i].mapID)
                break
            end
        end
        if buttonToHighlight then
            self.pendingZoneHighlight = finalTargetMapID
            self:ShowBreadcrumbHighlight(buttonToHighlight, finalTargetMapID)
        else
            DebugPrint("No breadcrumb at all, navigating directly to DCA")

            self.pendingZoneHighlight = finalTargetMapID
            DebugPrint("Set pendingZoneHighlight BEFORE the turn:", finalTargetMapID)
            MapSearch.TurnMap(dcaMapID)
        end
    end
end

function MapSearch:FindBreadcrumbButton(navBar, mapID)
    DebugPrint("FindBreadcrumbButton looking for mapID:", mapID)

    for i = 1, select("#", navBar:GetChildren()) do
        local child = select(i, navBar:GetChildren())
        if child.GetID and child:GetID() == mapID then
            DebugPrint("Found button via GetID:", mapID)
            return child
        end
        if child.data and child.data.id == mapID then
            DebugPrint("Found button via data.id:", mapID)
            return child
        end
    end

    if navBar.navList then
        DebugPrint("navList has", #navBar.navList, "entries")
        for i, buttonData in ipairs(navBar.navList) do
            DebugPrint("  navList[" .. i .. "] id:", buttonData.id, "type:", type(buttonData))
            if buttonData.id == mapID then
                if buttonData.IsShown and buttonData:IsShown() then
                    DebugPrint("buttonData itself is the button frame!")
                    return buttonData
                end
                if buttonData.Button then
                    DebugPrint("Found buttonData.Button")
                    return buttonData.Button
                end
            end
        end
    else
        DebugPrint("navBar.navList is nil!")
    end

    if navBar.home and navBar.home:IsShown() then

        local targetInfo = GetMapInfo(mapID)
        if targetInfo and targetInfo.mapType == Enum.UIMapType.Cosmic then
            DebugPrint("Cosmic map requested, returning home button")
            return navBar.home
        end
        local homeMapID = navBar.home.id or (navBar.home.data and navBar.home.data.id)
        DebugPrint("Home button ID:", homeMapID)
        if homeMapID == mapID then
            return navBar.home
        end
        if not homeMapID and navBar.home.GetText then
            local homeText = navBar.home:GetText()
            if homeText and targetInfo and homeText == targetInfo.name then
                DebugPrint("Found home button via text:", homeText)
                return navBar.home
            end
        end
    else
        DebugPrint("No home button or not shown")
    end

    local buttonName = "WorldMapNavBarButton"
    for i = 1, 10 do
        local mapBtn = _G[buttonName .. i]
        if mapBtn and mapBtn:IsShown() and mapBtn.data and mapBtn.data.id == mapID then
            DebugPrint("Found via global name:", buttonName .. i)
            return mapBtn
        end
    end

    local targetName = GetMapInfo(mapID)
    targetName = targetName and targetName.name
    if targetName then
        for i = 1, select("#", navBar:GetChildren()) do
            local child = select(i, navBar:GetChildren())
            if child:IsShown() and child.GetText then
                local text = child:GetText()
                if text and text == targetName then
                    DebugPrint("Found button via text match:", text)
                    return child
                end
            end
        end
    end

    return nil
end

function MapSearch:ShowBreadcrumbHighlight(button, finalTargetMapID)
    DebugPrint("ShowBreadcrumbHighlight, finalTarget:", finalTargetMapID)

    if not self.breadcrumbHighlight then
        local hl = CreateFrame("Frame", "EasyFindBreadcrumbHighlight", WorldMapFrame)
        hl:SetFrameStrata("TOOLTIP")
        hl:SetFrameLevel(300)

        hl:EnableMouse(false)

        MapFrames.AttachBounceAnimation(hl, {
            fromAlpha = 1,
            toAlpha = 0.3,
            duration = 0.8,
            groupKey = "pulseAnim",
        })


        local GLOW_LAYERS = 3
        hl.glowTextures = {}
        for i = 1, GLOW_LAYERS do
            local g = hl:CreateTexture(nil, "ARTWORK", nil, i)
            g:SetAllPoints()
            g:SetBlendMode("ADD")
            g:SetVertexColor(Utils.RGB(GOLD_COLOR, 1))
            g:Hide()
            hl.glowTextures[i] = g
        end

        hl:SetScript("OnHide", function(self)
            for _, g in ipairs(self.glowTextures) do g:Hide() end
            if self.button then
                if self.button.UnlockHighlight then self.button:UnlockHighlight() end
                local hlTex = self.button.GetHighlightTexture and self.button:GetHighlightTexture()
                if hlTex then
                    hlTex:SetBlendMode("BLEND")
                    hlTex:SetVertexColor(1, 1, 1, 1)
                end
                self.button = nil
            end
        end)


        local bcIndFrame = MapFrames.CreateIndicatorFrame(nil, UIParent, {
            strata = "TOOLTIP",
            level = 301,
            size = ns.BREADCRUMB_SIZE,
            iconSize = ns.BREADCRUMB_SIZE,
            glowSize = ns.ICON_GLOW_SIZE,
            moveKey = "bounceAnim",
        })
        bcIndFrame:SetPoint("BOTTOM", hl, "TOP", 0, 8)

        hl.indicatorFrame = bcIndFrame
        hl.indicator = bcIndFrame.indicator

        self.breadcrumbHighlight = hl
    end

    local hl = self.breadcrumbHighlight

    if hl.button and hl.button ~= button then
        if hl.button.UnlockHighlight then hl.button:UnlockHighlight() end
        local prevTex = hl.button.GetHighlightTexture and hl.button:GetHighlightTexture()
        if prevTex then
            prevTex:SetBlendMode("BLEND")
            prevTex:SetVertexColor(1, 1, 1, 1)
        end
    end
    hl.button = button

    if button.LockHighlight then button:LockHighlight() end
    local hlTex = button.GetHighlightTexture and button:GetHighlightTexture()
    if hlTex then
        hlTex:SetBlendMode("ADD")
        hlTex:SetVertexColor(Utils.RGB(GOLD_COLOR, 1))
    end

    for i = 1, #hl.glowTextures do
        local g = hl.glowTextures[i]
        if hlTex then
            local atlas = hlTex:GetAtlas()
            if atlas then
                g:SetAtlas(atlas)
            else
                g:SetTexture(hlTex:GetTexture())
                g:SetTexCoord(hlTex:GetTexCoord())
            end
            g:Show()
        else
            g:Hide()
        end
    end

    hl:ClearAllPoints()
    hl:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    hl:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    hl:Show()
    if hl.pulseAnim then hl.pulseAnim:Play() end

    if hl.indicatorFrame then
        self:UpdateBreadcrumbPosition()
        hl.indicatorFrame:Show()
        if hl.indicatorFrame.animGroup then
            hl.indicatorFrame.animGroup:Play()
        end
    end

    self.pendingZoneHighlight = finalTargetMapID
    DebugPrint("ShowBreadcrumbHighlight - SET pendingZoneHighlight to:", finalTargetMapID)
end





local ZOOM_HINT_GLYPH = 28
function MapSearch:ShowZoomOutHint(finalTargetMapID)
    local hint = self.zoomOutHint
    if not hint then
        hint = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer or WorldMapFrame)
        hint:SetFrameStrata("TOOLTIP")
        hint:SetFrameLevel(300)
        hint:EnableMouse(false)
        hint:SetHeight(ZOOM_HINT_GLYPH + 2)
        hint:SetPoint("BOTTOM", hint:GetParent(), "BOTTOM", 0, 14)
        hint.glyph = hint:CreateTexture(nil, "OVERLAY")
        hint.glyph:SetSize(ZOOM_HINT_GLYPH, ZOOM_HINT_GLYPH)
        hint.glyph:SetPoint("LEFT")
        hint.glyph:SetAtlas("NPE_RightClick")
        hint.text = hint:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        hint.text:SetPoint("LEFT", hint.glyph, "RIGHT", 6, 0)
        hint.text:SetTextColor(Utils.RGB(GOLD_COLOR, 1))
        hint.text:SetShadowColor(0, 0, 0, 1)
        hint.text:SetShadowOffset(1, -1)
        MapFrames.AttachBounceAnimation(hint, { fromAlpha = 1, toAlpha = 0.55, duration = 0.8, groupKey = "pulseAnim" })
        WorldMapFrame:HookScript("OnHide", function() hint:Hide() end)
        self.zoomOutHint = hint
    end
    hint.text:SetText(L["MAP_GUIDE_ZOOM_OUT"])
    hint:SetWidth(ZOOM_HINT_GLYPH + 6 + math.ceil(hint.text:GetStringWidth()))
    hint:Show()
    if hint.pulseAnim then hint.pulseAnim:Play() end
    self.pendingZoneHighlight = finalTargetMapID
end



function MapSearch:UpdateBreadcrumbPosition()
    local hl = self.breadcrumbHighlight
    if not hl or not hl.indicatorFrame then return end
    local indFrame = hl.indicatorFrame
    indFrame:ClearAllPoints()
    local mapIsMaximized = WorldMapFrame.IsMaximized and WorldMapFrame:IsMaximized()
    if mapIsMaximized then
        indFrame:SetPoint("TOP", hl, "BOTTOM", 0, -8)
        if indFrame.bounceAnim then
            indFrame.bounceAnim:SetOffset(0, 10)
        end
        indFrame.indicatorDirection = "up"
    else
        indFrame:SetPoint("BOTTOM", hl, "TOP", 0, 8)
        if indFrame.bounceAnim then
            indFrame.bounceAnim:SetOffset(0, -10)
        end
        indFrame.indicatorDirection = nil
    end
    ns.UpdateIndicator(indFrame)
    if indFrame:IsShown() and indFrame.animGroup then
        indFrame.animGroup:Stop()
        indFrame.animGroup:Play()
    end
end
