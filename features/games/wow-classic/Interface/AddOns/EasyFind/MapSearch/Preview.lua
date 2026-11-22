local _, ns = ...

local MapSearch = ns.MapSearch
local Utils = ns.Utils
local MapUtils = ns.MapUtils
local pcall = Utils.pcall

local GetMapInfo = C_Map.GetMapInfo
local GetMapRectOnMap = C_Map.GetMapRectOnMap
local GetMapRectViaContinent = MapUtils.GetMapRectViaContinent
local ResolveZoneForMap = MapUtils.ResolveZoneForMap



function MapSearch:GetPreviewCoords(data)
    local currentMapID = WorldMapFrame:GetMapID()
    if data.allInstances then



        local valid = MapSearch.SpotsOnMap(data.allInstances, currentMapID)
        if #valid > 1 then
            return { instances = valid }
        elseif #valid == 1 then
            local single = valid[1]
            return { x = single.x, y = single.y, icon = single.icon, category = single.category,
                displayID = single.displayID }
        else
            return nil
        end
    end

    local px, py, pIcon, pCat, pMapID
    if data.isZone then
        px, py = data.entranceX, data.entranceY
        pIcon = data.entranceIcon or data.icon
        pCat = data.entranceCategory or data.category
        pMapID = data.entranceMapID
    elseif data.x and data.y then
        px, py = data.x, data.y
        pIcon = data.icon
        pCat = data.category


        pMapID = data.entranceMapID or data.coordMapID or data.mapID
    end






    if px and py and (not pMapID or pMapID == currentMapID) then
        local pin = data.pin
        if (not pin or not pin:IsShown())
           and self.FindNativePinByName and data.name then
            pin = self:FindNativePinByName(data.name)
        end
        return { x = px, y = py, icon = pIcon, category = pCat, pin = pin, displayID = data.displayID }
    end

    if data.isDungeonEntrance or data.category == "dungeon"
       or data.category == "raid" or data.category == "delve" then
        local ex, ey = self:FindEntranceOnMap(data.name, currentMapID)
        if ex then
            return { x = ex, y = ey, icon = pIcon or data.icon, category = pCat or data.category }
        end
    end





    if data.isZone and data.zoneMapID then
        local zMap = data.zoneMapID
        local resolved = ResolveZoneForMap(zMap, currentMapID)
        if resolved ~= zMap then zMap = resolved end



        local zInfo = GetMapInfo(zMap)
        if zInfo and zInfo.parentMapID == currentMapID then
            local ok, left, right, top, bottom = pcall(GetMapRectOnMap, zMap, currentMapID)
            if ok and left then
                if left == 0 and right == 0 and top == 0 and bottom == 0 then
                    local pL, pR, pT, pB = GetMapRectViaContinent(zMap, currentMapID)
                    if pL then left, right, top, bottom = pL, pR, pT, pB end
                end
                if left and (right - left) > 0.005 and (bottom - top) > 0.005
                   and (right - left) < 1.05 and (bottom - top) < 1.05 then
                    local cx = (left + right) / 2
                    local cy = (top + bottom) / 2
                    return { x = cx, y = cy, arrowOnly = true }
                end
            end
        end
    end
    return nil
end







function MapSearch:RunHoverPreview(data)
    if not data then return end




    if not self._previewing then
        self._savedPinState = self:GetActivePinState()
    end
    self._previewing = true






    self._previewingZone = nil
    if data.isZone and data.zoneMapID and self.PreviewZoneHighlight and not self._zoneGuide then
        self:PreviewZoneHighlight(data.zoneMapID)
        self._previewingZone = data.zoneMapID
    end

    if not self.GetPreviewCoords then return end
    local coords = self:GetPreviewCoords(data)
    if not coords then


        return
    end


    local composite = {}
    local saved = self._savedPinState
    if saved and saved.mapID == WorldMapFrame:GetMapID() then
        if saved.instances then
            for i = 1, #saved.instances do
                composite[#composite + 1] = saved.instances[i]
            end
        elseif saved.x and saved.y then


            composite[#composite + 1] = {
                x = saved.x, y = saved.y,
                icon = saved.icon, category = saved.category, displayID = saved.displayID,
            }
        end
    end

    if coords.pin and coords.pin:IsShown() then


        if #composite > 0 then self:ShowMultipleWaypoints(composite) end
        self:HighlightPin(coords.pin, coords.x, coords.y, coords.icon, coords.category)
    elseif coords.instances then
        for i = 1, #coords.instances do
            composite[#composite + 1] = coords.instances[i]
        end
        self:ShowMultipleWaypoints(composite)
    elseif coords.x and coords.y then
        if coords.arrowOnly then



            self:ShowWaypointAt(coords.x, coords.y, nil, nil, true)
        else
            composite[#composite + 1] = {
                x = coords.x, y = coords.y,
                icon = coords.icon, category = coords.category, displayID = coords.displayID,
            }
            if #composite > 1 then
                self:ShowMultipleWaypoints(composite)
            else
                self:ShowWaypointAt(coords.x, coords.y, coords.icon, coords.category, nil, coords.displayID)
            end
        end
    end






    self:SetActivePinState(self._savedPinState)
end

function MapSearch:EndHoverPreview()
    if not self._previewing then return end
    self._previewing = nil
    if self._previewingZone then



        self:ClearZoneHighlight(true)
        self._previewingZone = nil
    end
    local saved = self._savedPinState
    self._savedPinState = nil
    local mapID = WorldMapFrame and WorldMapFrame:GetMapID()







    local current = self:GetActivePinState()
    local function stateOnMap(s)
        return s and s.mapID == mapID
            and (s.instances or (s.x and s.y))
    end
    local function statesDiffer(a, b)
        if not a or not b then return a ~= b end
        if a.mapID ~= b.mapID then return true end
        if a.x ~= b.x or a.y ~= b.y then return true end
        return false
    end
    if stateOnMap(current) and statesDiffer(current, saved) then

        self:ClearHighlight()
        if current.instances then
            self:ShowMultipleWaypoints(current.instances)
        else
            self:ShowWaypointAt(current.x, current.y, current.icon, current.category, nil, current.displayID)
        end
        self:SetActivePinState(current)
        return
    end
    self:ClearHighlight()
    if saved and saved.mapID == mapID then
        if saved.instances then
            self:ShowMultipleWaypoints(saved.instances)
        elseif saved.x and saved.y then
            self:ShowWaypointAt(saved.x, saved.y, saved.icon, saved.category, nil, saved.displayID)
        end


        self:SetActivePinState(saved)
    end
end




function MapSearch:PreviewUIResult(data)
    if not data or not WorldMapFrame or not WorldMapFrame:IsShown() then return false end
    local coords = self:GetPreviewCoords(data)
    if not coords then return false end
    self._savedPinState = self:GetActivePinState()
    self._previewing = true
    if coords.instances then
        self:ShowMultipleWaypoints(coords.instances)
    elseif coords.pin and coords.pin:IsShown() then
        self:HighlightPin(coords.pin, coords.x, coords.y, coords.icon, coords.category)
    else
        self:ShowWaypointAt(coords.x, coords.y, coords.icon, coords.category, nil, coords.displayID)
    end
    self:SetActivePinState(self._savedPinState)
    return true
end


function MapSearch:ClearUIPreview()
    if not self._previewing then return end
    self._previewing = nil
    self:ClearHighlight()
    local saved = self._savedPinState
    self._savedPinState = nil
    if saved and WorldMapFrame and WorldMapFrame:IsShown()
       and saved.mapID == WorldMapFrame:GetMapID() then
        if saved.instances then
            self:ShowMultipleWaypoints(saved.instances)
        else
            self:ShowWaypointAt(saved.x, saved.y, saved.icon, saved.category, nil, saved.displayID)
        end
        self:SetActivePinState(saved)
    end
end
