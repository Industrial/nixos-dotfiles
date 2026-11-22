local _, ns = ...

local MapSearch = ns.MapSearch








function MapSearch:HandleUISearchClick(data, forceGuide)
    if not data then return end
    if data.placeOf then self.ResolvePlace(data) end
    self._selected = data

    local isGlobalResult = data.isZone or data.isDungeonEntrance








    if ns.MapTab and ns.MapTab.OpenWithQuery and data.query then
        ns.MapTab:OpenWithQuery(data.query)
    end

    if isGlobalResult then



        MapSearch.OpenMap()
        if forceGuide then


            self:SelectResult(data, false)
        elseif data.entranceMapID and data.entranceX and data.entranceY then
            MapSearch.TurnMap(data.entranceMapID)
            self:ShowWaypointAt(data.entranceX, data.entranceY,
                data.entranceIcon or data.icon, data.entranceCategory or data.category)
        elseif data.zoneMapID then
            MapSearch.TurnMap(data.zoneMapID)
        end
    else





        local x, y = data.x, data.y
        if data.mapID and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            self:SetActivePinState({
                mapID = data.mapID,
                x = x, y = y,
                icon = data.icon, category = data.category, displayID = data.displayID,
                isLocal = true,
            })
            self:RefreshAllClearButtons()
            MapSearch.OpenMap(data.mapID)
            self:ShowWaypointAt(x, y, data.icon, data.category, nil, data.displayID)
            if not forceGuide and EasyFind.db.localMapDirectOpen then
                self:TrackActivePin()
            end
        end
    end
end



function MapSearch.NearestSpot(spots)
    local m = C_Map.GetBestMapForUnit("player")
    local pos = m and C_Map.GetPlayerMapPosition(m, "player")
    local pci, wp
    if pos then pci, wp = C_Map.GetWorldPosFromMapPos(m, pos) end
    if not (pci and wp) then return nil end
    local px, py = wp:GetXY()
    local best, bestD
    for i = 1, #spots do
        local s = spots[i]
        local ci, sp = C_Map.GetWorldPosFromMapPos(s.coordMapID or s.mapID, CreateVector2D(s.x, s.y))
        if ci == pci and sp then
            local sx, sy = sp:GetXY()
            local d = (sx - px) ^ 2 + (sy - py) ^ 2
            if not bestD or d < bestD then best, bestD = s, d end
        end
    end
    return best
end




function MapSearch:ShowProviderPlaces(p, row)
    local spots = p.places and self.ProviderSpots(p, row)
    if not spots then return false end
    local data = { name = row.name, category = p.category, icon = row.icon, matchNote = p.label,
                   providerRow = row, placeOf = p.place, spots = spots, allInstances = spots }
    local near = self.NearestSpot(spots) or spots[1]
    data.mapID, data.coordMapID, data.x, data.y = near.mapID, near.mapID, near.x, near.y
    data.step, data.destName = near.step, near.destName
    if ns.MapTab and ns.MapTab.OpenWithQuery then ns.MapTab:OpenWithQuery(row.name) end
    MapSearch.OpenMap()
    self:SelectResult(data)
    return true
end
