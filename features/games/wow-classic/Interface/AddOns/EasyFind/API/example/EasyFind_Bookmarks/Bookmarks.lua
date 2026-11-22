-- Bookmarks for EasyFind: an example extension built on EasyFind.API.
-- Saves the spot you stand on; type its name in EasyFind to find it, and
-- a click asks EasyFind's GPS for directions. MIT licensed: copy freely.

local API = EasyFind and EasyFind.API
if not (API and API.VERSION == 1) then return end

-- Drawn with API/icons/make_icon.py (draw_bookmark) in EasyFind's style.
local ICON = "Interface\\AddOns\\EasyFind_Bookmarks\\bookmark"

-- Saved variables arrive after this file runs: read them when needed.
local function DB()
    EasyFindBookmarksDB = EasyFindBookmarksDB or {}
    local db = EasyFindBookmarksDB
    db.marks = db.marks or {}
    if db.showZone == nil then db.showZone = true end
    return db
end

local function ZoneName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or "?"
end

-- The spot under the player, named; tells listeners and refreshes search.
local function AddHere(name)
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    local x, y = pos:GetXY()
    local mark = { name = (name and name ~= "") and name or ZoneName(mapID), mapID = mapID, x = x, y = y }
    table.insert(DB().marks, mark)
    API.RefreshSearchProvider("bookmarks")
    API.Fire("bookmarks", "added", mark)
    return mark
end

local function AskName()
    API.ShowDialog({
        text = "Name this bookmark",
        acceptText = "Save",
        hasEditBox = true,
        editBoxDefault = GetSubZoneText() ~= "" and GetSubZoneText() or GetZoneText(),
        onAccept = AddHere,
    })
end

-- Directions from EasyFind's GPS when it is there, else the game's own
-- map pin.
local function GoTo(mark)
    local dest = { name = mark.name, mapID = mark.mapID, x = mark.x, y = mark.y }
    if API.HasAction("gps", "navigate") then
        API.CallAction("gps", "navigate", dest)
    elseif C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mark.mapID) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mark.mapID, mark.x, mark.y))
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
end

-- The tile: its surface is the @bookmarks list in the search bar.
API.RegisterExtension({
    id = "bookmarks",
    name = "Bookmarks",
    description = "Spots you saved, found by name.",
    icon = ICON,
    keywords = { "bookmark", "saved places" },
    scope = "bookmarks",
    menu = function()
        return { { kind = "action", label = "Bookmark this spot", onClick = AskName } }
    end,
    settings = function(page, kit)
        local below = kit.Title(page, "Bookmarks", "Spots you saved. Type a name in EasyFind to find one.")
        local zone = kit.Checkbox(page, "Show the zone under each name",
            function() return DB().showZone end,
            function(on)
                DB().showZone = on
                API.RefreshSearchProvider("bookmarks")
            end)
        zone:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -8)
        local add = kit.Button(page, "Bookmark this spot", 160, 22)
        add:SetPoint("TOPLEFT", zone, "BOTTOMLEFT", 8, -12)
        add:SetScript("OnClick", AskName)
    end,
})

-- The rows a search finds: each bookmark, by name.
API.RegisterSearchProvider({
    key = "bookmarks",
    label = "Bookmarks",
    extension = "bookmarks",
    words = { "bookmark", "bookmarks" },
    eager = true,
    aliases = { "bm", "bookmarks" },
    rows = function()
        local rows = {}
        for i, mark in ipairs(DB().marks) do
            rows[i] = {
                name = mark.name,
                searchCommandDesc = DB().showZone and ZoneName(mark.mapID) or nil,
                markIndex = i,
            }
        end
        return rows
    end,
    select = function(row)
        local mark = DB().marks[row.markIndex]
        if mark then GoTo(mark) end
    end,
    tooltip = function(row, tooltip)
        local mark = DB().marks[row.markIndex]
        if not mark then return false end
        tooltip:SetText(mark.name)
        tooltip:AddLine(string.format("%s  %.1f, %.1f", ZoneName(mark.mapID), mark.x * 100, mark.y * 100), 1, 1, 1)
        return true
    end,
})

-- For other extensions: save the spot here under a name.
API.RegisterAction("bookmarks", "add", AddHere)

-- Heard from the GPS: arriving at a bookmark says so.
API.On("gps", "arrived", function(dest)
    for _, mark in ipairs(DB().marks) do
        if dest and dest.mapID == mark.mapID and dest.name == mark.name then
            print("|cff66ccffBookmarks:|r arrived at " .. mark.name)
            return
        end
    end
end)
