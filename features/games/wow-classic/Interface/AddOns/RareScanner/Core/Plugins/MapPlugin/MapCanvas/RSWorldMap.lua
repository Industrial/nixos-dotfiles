-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local LibStub = _G.LibStub
local ADDON_NAME, private = ...

local RSWorldMap = private.NewLib("RareScannerWorldMap")
local RSRoute

local RSConstants = private.ImportLib("RareScannerConstants")
local RSConfigDB = private.ImportLib("RareScannerConfigDB")

function RSWorldMap:OnLoad()
	self.pinPools = {};
	self.pinTemplateTypes = {};
	self.dataProviders = {};
	self:GetMapFrame()
	
	if (RSConfigDB.IsShowingPlayerPinOnTop()) then
		self:CreatePlayerPin()
	end
end

function RSWorldMap:OnShow()
    for provider in pairs(self.dataProviders) do
        provider:OnShow()
    end
end

function RSWorldMap:OnHide()
    for provider in pairs(self.dataProviders) do
        provider:OnHide()
    end
end

function RSWorldMap:GetMapFrame()
    if (not self.mapFrame) then
        local canvas
        local scroll = WorldMapFrame.ScrollContainer
        if (scroll and scroll.Child) then
            canvas = scroll.Child
        else
            canvas = WorldMapFrame:GetCanvasContainer()
        end
        
        self.mapFrame = CreateFrame("Frame", nil, canvas)
        self.mapFrame:SetAllPoints(canvas)
        self.mapFrame:SetFrameLevel(canvas:GetFrameLevel() + 10)
        
        -- OnMapChanged
        EventRegistry:RegisterCallback("MapCanvas.MapSet", function(_, mapID)       
            self.mapID = mapID
            for provider in pairs(RSWorldMap.dataProviders) do
                provider:OnMapChanged()
            end
            
            if (RSConstants.DEBUG_MODE) then
                RSWorldMap:UpdateDebugText(string.format("MAPID-ARTID [%s]-[%s]", mapID, C_Map.GetMapArtID(mapID)))
            end

            if (not RSRoute) then
                RSRoute = private.ImportLib("RareScannerRoute")
            end
            RSRoute.RefreshRoute()
        end)
        
        -- Helper para refrescar la escala de todas las pins activas
        local function UpdateAllPinsScale()
            for pinTemplate, pool in pairs(RSWorldMap.pinPools) do
                for pin in pool:EnumerateActive() do
                    pin:UpdateScale()
                end
            end
        end

        -- OnSizeChanged (maximize, minimize)
        hooksecurefunc(WorldMapFrame, "OnFrameSizeChanged", function(self)
            if (WorldMapFrame:IsShown()) then
                UpdateAllPinsScale()
            end
        end)
        
        -- OnCanvasScaleChanged (zoom)
        if WorldMapFrame.OnCanvasScaleChanged then
            hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", function()
                UpdateAllPinsScale()
            end)
        -- Just in case the event fails
        else
            local function OnZoomUpdate(self)
                local scale = canvas:GetScale()
                if (self.lastScale ~= scale) then
                    self.lastScale = scale
                    UpdateAllPinsScale()
                end
            end

            self.mapFrame:HookScript("OnShow", function(self)
                self:SetScript("OnUpdate", OnZoomUpdate)
            end)

            self.mapFrame:HookScript("OnHide", function(self)
                self:SetScript("OnUpdate", nil)
            end)
        end
        
        self.mapFrame:SetScript("OnShow", function()
            RSWorldMap:OnShow()
        end)
        
        self.mapFrame:SetScript("OnHide", function()
            RSWorldMap:OnHide()
        end)
        
        -- DEBUG info
        if (RSConstants.DEBUG_MODE) then
            self.mapFrame.debugText = self.mapFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            self.mapFrame.debugText:SetFont("Fonts\\FRIZQT__.TTF", 30, "OUTLINE")
            self.mapFrame.debugText:SetPoint("BOTTOMLEFT", 5, 5)
            self.mapFrame.debugText:SetTextColor(1, 1, 0)
        end
    end
    
    return self.mapFrame
end

function RSWorldMap:UpdateDebugText(text)
    if (self.mapFrame and self.mapFrame.debugText) then
        self.mapFrame.debugText:SetText(text)
    end
end

function RSWorldMap:AddDataProvider(dataProvider)
	self.dataProviders[dataProvider] = true;
	dataProvider:OnAdded(self);
end

function RSWorldMap:RemoveDataProvider(dataProvider)
	dataProvider:RemoveAllData();
	self.dataProviders[dataProvider] = nil;
	dataProvider:OnRemoved(self);
end

function RSWorldMap:GetPinTemplateType(pinTemplate)
	-- Can always be overridden by manually calling SetPinTemplateType, but by default this will use the template
	-- to look up type information and discover the most likely type so that pins can avoid needing to call
	-- SetPinTemplateType.
	local pinTemplateType = self.pinTemplateTypes[pinTemplate];
	if (not pinTemplateType) then
		local templateInfo = C_XMLUtil.GetTemplateInfo(pinTemplate);
		pinTemplateType = templateInfo and templateInfo.type or "FRAME";
		self.pinTemplateTypes[pinTemplate] = pinTemplateType;
	end

	return pinTemplateType;
end

local function OnPinReleased(pinPool, pin)
	pin:OnReleased();
end

function RSWorldMap:AcquirePin(pinTemplate, ...)
	if (not pinTemplate) then
		return
	end
	
	if (not self.pinPools[pinTemplate]) then
		local pinTemplateType = self:GetPinTemplateType(pinTemplate);
		self.pinPools[pinTemplate] = CreateFramePool(pinTemplateType, self:GetMapFrame(), pinTemplate, OnPinReleased);
	end
	
	local pin, newPin = self.pinPools[pinTemplate]:Acquire();
	
	if (newPin) then
		pin:OnLoad()
	end
	
	pin:OnAcquired(...);
	pin.pinTemplate = pinTemplate
	pin:Show();
	
	return pin
end

function RSWorldMap:RemoveAllPinsByTemplate(pinTemplate)
	if (self.pinPools[pinTemplate]) then
		self.pinPools[pinTemplate]:ReleaseAll();
	end
end

function RSWorldMap:RemovePin(pin)
	self.pinPools[pin.pinTemplate]:Release(pin);
end

function RSWorldMap:EnumeratePinsByTemplate(pinTemplate)
	if (self.pinPools[pinTemplate]) then
		return self.pinPools[pinTemplate]:EnumerateActive();
	end
	return nop;
end

function RSWorldMap:GetNumActivePinsByTemplate(pinTemplate)
	if (self.pinPools[pinTemplate]) then
		return self.pinPools[pinTemplate]:GetNumActive();
	end
	return 0;
end

function RSWorldMap:RefreshAllDataProviders(fromOnShow)
	for dataProvider in pairs(self.dataProviders) do
		dataProvider:RefreshAllData(fromOnShow)
	end
end

function RSWorldMap:GetMapID()
	return self.mapID or MapUtil.GetDisplayableMapForPlayer();
end

function RSWorldMap:TriggerEvent(eventName, ...)
    for dataProvider in pairs(self.dataProviders) do
		local func = dataProvider[eventName]
		if (func) then
            func(dataProvider, ...)
        end
	end
end

function RSWorldMap:CreatePlayerPin()
    if self.playerPin then return end

    local canvas = self:GetMapFrame()
    local pin = CreateFrame("Frame", "RSPlayerPin", canvas)
    pin:SetSize(24, 24)
    pin:SetFrameStrata("DIALOG")

    local tex = pin:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas("UI-WorldMapArrow", true)
    tex:SetSize(28, 28)
    tex:SetPoint("CENTER", pin, "CENTER")
    pin.Texture = tex

	local lastX, lastY, lastScale, lastFacing
    local function OnUpdateHandler(self, elapsed)
    	if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
    
        local mapID = RSWorldMap:GetMapID()
        if not mapID then return end
        
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if not pos then 
            pin:Hide()
            return
        else
            pin:Show() 
        end
        
        local scale = (1.0 / WorldMapFrame:GetCanvasScale())
        if (scale ~= lastScale) then
            self:SetScale(scale)
            lastScale = scale
        end

        local width, height = canvas:GetWidth(), canvas:GetHeight()
        local x = (pos.x * width) / scale
        local y = -(pos.y * height) / scale
        
        if (x ~= lastX or y ~= lastY) then
            self:SetPoint("CENTER", canvas, "TOPLEFT", x, y)
            lastX, lastY = x, y
        end

        -- Rotación según facing
        local facing = GetPlayerFacing()
        if (facing and facing ~= lastFacing) then
            self.Texture:SetRotation(facing)
            lastFacing = facing
        end
    end
    
    local function UpdatePinState()
    	if (not WorldMapFrame:IsShown() or IsInInstance()) then
            pin:Hide()
            pin:SetScript("OnUpdate", nil)
            return
        end

        pin:Show()
        pin:SetScript("OnUpdate", OnUpdateHandler)
    end
    
    EventRegistry:RegisterCallback("MapCanvas.MapSet", function(_, mapID)
        UpdatePinState()
    end)

    self.mapFrame:HookScript("OnShow", function()
        UpdatePinState()
    end)
    
    self.mapFrame:HookScript("OnHide", function()
        pin:Hide()
        pin:SetScript("OnUpdate", nil)
    end)

    pin:Show()
    self.playerPin = pin
end

function RSWorldMap:DisablePlayerPin()
	if (self.playerPin) then
		self.playerPin:Hide()
		self.playerPin:SetScript("OnUpdate", nil)
		self.playerPin = nil
	end
end

function RSWorldMap:WaitForCanvasReady(callback)
    local attempts = 0
    local maxAttempts = 300

    local function Check()
        local canvas = WorldMapFrame and WorldMapFrame:GetCanvasContainer()

        if (canvas and canvas.zoomLevels) then
            callback(true)
            return
        end

        attempts = attempts + 1
        if (attempts < maxAttempts) then
            C_Timer.After(0.1, Check)
        else
        	callback(false)
        end
    end

    Check()
end

if (WorldMapFrame and WorldMapFrame.TriggerEvent) then
	hooksecurefunc(WorldMapFrame, "TriggerEvent", function(self, event, ...)
		if (event == "SetBounty") then
			for dataProvider in pairs(RSWorldMap.dataProviders) do
				if (dataProvider.SetBounty) then
					dataProvider:SetBounty(...)
				end
			end
		end
	end)
end