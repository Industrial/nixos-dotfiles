-- ModernMapMarkers_Dungeons.lua
-- Standalone native classic dungeon map renderer

-- Force this file to use the exact same global namespace as ModernMapMarkers.lua
MMM = MMM or {}

-- ==========================================
-- 1. MAP DATA
-- ==========================================
-- pattern "f_t" = multi-floor (Folder1_1), "t" = single-floor (Folder1)
-- Keys are now string atlasIDs (matching the debug prints) instead of numeric IDs.
local DUNGEON_MAPS = {
    -- Base Vanilla Dungeons
    ["ragefire_chasm"]           = { folder = "Ragefire",             pattern = "f_t", floors = { 1 }, name = "Ragefire Chasm" },
    ["wailing_caverns_instance"] = { folder = "WailingCaverns",       pattern = "f_t", floors = { 1 }, name = "Wailing Caverns", customPath = true },
    ["deadmines"]                = { folder = "TheDeadmines",         pattern = "f_t", floors = { 1, 2 }, name = "The Deadmines" },
    ["shadowfang_keep"]          = { folder = "ShadowfangKeep",       pattern = "f_t", floors = { 1, 2, 3, 4, 5, 6, 7 }, name = "Shadowfang Keep" },
    ["blackfathom_deeps"]        = { folder = "BlackFathomDeeps",     pattern = "f_t", floors = { 1, 2, 3 }, name = "Blackfathom Deeps" },
    ["gnomeregan"]               = { folder = "Gnomeregan",           pattern = "f_t", floors = { 1, 2, 3, 4 }, name = "Gnomeregan" },
    ["gnomeregan_approach"]      = { folder = "Gnomeregan",           pattern = "f_t", floors = { 1, 2, 3, 4 }, name = "Gnomeregan" },
    ["stockade"]                 = { folder = "TheStockade",          pattern = "f_t", floors = { 1 }, name = "The Stockade" },
    ["razorfen_kraul"]           = { folder = "RazorfenKraul",        pattern = "f_t", floors = { 1 }, name = "Razorfen Kraul" },
    ["razorfen_downs"]           = { folder = "RazorfenDowns",        pattern = "f_t", floors = { 1 }, name = "Razorfen Downs" },
    ["maraudon"]                 = { folder = "Maraudon",             pattern = "f_t", floors = { 1, 2 }, name = "Maraudon" },
    ["zul_farrak"]               = { folder = "ZulFarrak",            pattern = "t",   floors = { 1 }, name = "Zul'Farrak" },
    ["scholomance"]              = { folder = "Scholomance",          pattern = "f_t", floors = { 1, 2, 3, 4 }, name = "Scholomance", customPath = true },
    ["blackrock_depths"]         = { folder = "BlackrockDepths",      pattern = "f_t", floors = { 1, 2 }, name = "Blackrock Depths", defaultFloor = 1, customFloors = { [1] = true } },
    ["sunken_temple"]            = { folder = "TheTempleofAtalhakkar",pattern = "f_t", floors = { 1, 2, 3, 4, 5 }, name = "The Temple of Atal'hakkar", defaultFloor = 2, customFloors = { [2] = true, [3] = true, [4] = true, [5] = true, } },
    ["stratholme"]               = { folder = "Stratholme",           pattern = "f_t", floors = { 1, 2 }, name = "Stratholme" },

    -- Uldaman
    ["uldaman"]                  = { folder = "Uldaman",              pattern = "f_t", floors = { 1, 2, 18 }, name = "Uldaman" },
    ["uldaman_approach"]         = { folder = "Uldaman",              pattern = "f_t", floors = { 1, 2, 18 }, name = "Uldaman" },
    
    -- Scarlet Monastery Wings
    ["scarlet_graveyard"]        = { folder = "ScarletMonastery",     pattern = "f_t", floors = { 1, 2, 3, 4 }, name = "Scarlet Monastery", defaultFloor = 1 },
    ["scarlet_library"]          = { folder = "ScarletMonastery",     pattern = "f_t", floors = { 1, 2, 3, 4 }, name = "Scarlet Monastery", defaultFloor = 2 },
    ["scarlet_armory"]           = { folder = "ScarletMonastery",     pattern = "f_t", floors = { 1, 2, 3, 4 }, name = "Scarlet Monastery", defaultFloor = 3 },
    ["scarlet_cathedral"]        = { folder = "ScarletMonastery",     pattern = "f_t", floors = { 1, 2, 3, 4 }, name = "Scarlet Monastery", defaultFloor = 4 },
    
    -- Dire Maul Wings
    ["dire_maul_west"]           = { folder = "DireMaul",             pattern = "f_t", floors = { 2, 3, 4 }, name = "Dire Maul", defaultFloor = 2 },
    ["dire_maul_east"]           = { folder = "DireMaul",             pattern = "f_t", floors = { 5, 6 }, name = "Dire Maul", defaultFloor = 5 },
    ["dire_maul_north"]          = { folder = "DireMaul",             pattern = "f_t", floors = { 1 }, name = "Dire Maul", defaultFloor = 1 },
    ["dire_maul_exterior"]       = { folder = "DireMaul",             pattern = "f_t", floors = { 1, 2, 3, 4, 5, 6 }, name = "Dire Maul", defaultFloor = 1 },
    
    -- Blackrock Spire (Lower vs Upper)
    ["lower_blackrock_spire"]    = { folder = "BlackrockSpire",       pattern = "f_t", floors = { 1, 2, 3, 4, 5, 6 }, name = "Blackrock Spire", defaultFloor = 4 },
    ["upper_blackrock_spire"]    = { folder = "BlackrockSpire",       pattern = "f_t", floors = { 7, 8, 9 }, name = "Blackrock Spire", defaultFloor = 9, customFloors = { [8] = true, [9] = true } },

    -- The missing Classic Raids
    ["zul_gurub"]                = { folder = "ZulGurub",             pattern = "t",   floors = { 1 }, name = "Zul'Gurub" },
    ["molten_core"]              = { folder = "MoltenCore",           pattern = "f_t", floors = { 1 }, name = "Molten Core" },
    ["blackwing_lair"]           = { folder = "BlackwingLair",        pattern = "f_t", floors = { 1, 2, 3, 4 }, name = "Blackwing Lair" },
    ["ruins_of_ahnqiraj"]        = { folder = "RuinsofAhnQiraj",      pattern = "t",   floors = { 1 }, name = "Ruins of Ahn'Qiraj" },
    ["temple_of_ahnqiraj"]       = { folder = "AhnQiraj",             pattern = "f_t", floors = { 1, 2, 3 }, name = "Temple of Ahn'Qiraj" },
    ["onyxias_lair"]             = { folder = "OnyxiasLair",          pattern = "f_t", floors = { 1 }, name = "Onyxia's Lair" },

    -- Forever Dungeons
    ["hall_of_thanes"]           = { folder = "HallOfThanes",         pattern = "f_t", floors = { 1 }, name = "The Hall of Thanes", customPath = true },
    ["ruins_of_lordaeron"]       = { folder = "RuinsOfLordaeron",     pattern = "f_t", floors = { 1 }, name = "Ruins of Lordaeron", customPath = true },
    ["excavation_site_wetlands"] = { folder = "ExcavationSiteWetlands", pattern = "f_t", floors = { 1 }, name = "Excavation Site: Wetlands", customPath = true },
    ["city_of_dalaran"]          = { folder = "CityOfDalaran",        pattern = "f_t", floors = { 1,2 }, name = "City of Dalaran", customPath = true },
    ["the_drowned_city"]         = { folder = "TheDrownedCity",       pattern = "f_t", floors = { 1 }, name = "The Drowned City", customPath = true, comingSoon = true },
    ["kroldok_stronghold"]       = { folder = "KroldokStronghold",    pattern = "f_t", floors = { 1 }, name = "Krol'dok Stronghold", customPath = true, comingSoon = true },
    ["alcaz_prison"]             = { folder = "AlcazPrison",          pattern = "f_t", floors = { 1 }, name = "Alcaz Prison", customPath = true, comingSoon = true },
    ["blackmaw_hold"]            = { folder = "BlackmawHold",         pattern = "f_t", floors = { 1 }, name = "Blackmaw Hold", customPath = true, comingSoon = true },
    ["shapers_terrace"]          = { folder = "ShapersTerrace",       pattern = "f_t", floors = { 1 }, name = "Shaper’s Terrace", customPath = true, comingSoon = true },
}


-- Instances whose map art isn't available yet (no DUNGEON_MAPS entry, or flagged comingSoon above)
local COMING_SOON_IDS = { hyjal_summit = true, barrow_deeps = true }
local COMING_SOON_MSG = "|cff7fff7fModernMapMarkers:|r Map data coming soon from Santiago Reyes - https://asguevara433.wixsite.com/srmaps/post/proyecto-atlas-de-azeroth-forever"

local function GetDungeonTilePath(data, floor, tile)
    local folder = data.folder
    local pattern = data.pattern

    -- Custom addon textures: no folder prefix in the filename
    local isCustom = data.customPath == true
        or (data.customFloors and data.customFloors[floor])

    if isCustom then
        local basePath = "Interface\\AddOns\\ModernMapMarkers\\Textures\\Dungeons\\" .. folder .. "\\"
        if pattern == "t" then
            return basePath .. tile
        end
        return basePath .. floor .. "_" .. tile
    end

    -- Manual path or native Blizzard path: filenames carry the folder prefix
    local basePath
    if type(data.customPath) == "string" then
        basePath = data.customPath
    else
        basePath = "Interface\\WorldMap\\" .. folder .. "\\"
    end

    if pattern == "t" then
        return basePath .. folder .. tile
    end
    return basePath .. folder .. floor .. "_" .. tile
end

-- ==========================================
-- 2. GEOMETRY & UI OVERLAY
-- ==========================================
local COLS, ROWS = 4, 3
local NTILE = COLS * ROWS
local CONTENT_W, CONTENT_H, TILE_PX = 1002, 668, 256

local overlay
local currentMapData
local RefreshPins -- defined in the instance pins section below

local function layoutTiles()
    if not overlay then return end
    local W, H = overlay:GetWidth(), overlay:GetHeight()
    if not W or W <= 1 or not H or H <= 1 then return end
    
    -- Calculate aspect fit to prevent letterboxing
    local aspect = CONTENT_W / CONTENT_H
    local fitW, fitH
    if (W / H) > aspect then 
        fitH = H; fitW = H * aspect 
    else 
        fitW = W; fitH = W / aspect 
    end
    
    local s = fitW / CONTENT_W
    local x0, y0 = (W - fitW) / 2, (H - fitH) / 2
    
    -- Store calculated boundaries so your marker logic can anchor to them
    overlay.fitX0, overlay.fitY0, overlay.fitW, overlay.fitH = x0, y0, fitW, fitH
    
    for i = 1, NTILE do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        
        -- Crop the black padding off the right and bottom edges
        local cw = (col == COLS - 1) and (CONTENT_W - TILE_PX * (COLS - 1)) or TILE_PX
        local ch = (row == ROWS - 1) and (CONTENT_H - TILE_PX * (ROWS - 1)) or TILE_PX
        
        local t = overlay.tiles[i]
        t.crR, t.crB = cw / TILE_PX, ch / TILE_PX
        t:SetTexCoord(0, t.crR, 0, t.crB)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", overlay, "TOPLEFT", x0 + TILE_PX * col * s, -(y0 + TILE_PX * row * s))
        t:SetSize(cw * s, ch * s)
    end
    
    if RefreshPins then RefreshPins() end
end

local function ensureOverlay()
    if overlay then return overlay end
    local wmf = _G.WorldMapFrame
    if not (wmf and wmf.ScrollContainer) then return nil end
    
    -- High strata to swallow map clicks beneath it
    local o = CreateFrame("Frame", "ModernMapMarkers_DungeonOverlay", wmf)
    o:SetFrameStrata("HIGH")
    o:SetAllPoints(wmf.ScrollContainer)
    o:EnableMouse(true)
    o:EnableMouseWheel(true)
    o:SetScript("OnMouseWheel", function() end)
    o:SetScript("OnSizeChanged", layoutTiles)
    
    -- Close map on right click (matches standard navigation)
    o:SetScript("OnMouseUp", function(_, btn)
        if btn == "RightButton" then
            o:Hide()
        end
    end)
    o:Hide()

    -- Opaque background cover
    o.bg = o:CreateTexture(nil, "BACKGROUND")
    o.bg:SetAllPoints(o)
    o.bg:SetColorTexture(0, 0, 0, 1)

    -- Generate 12 texture tiles
    o.tiles = {}
    for i = 1, NTILE do 
        o.tiles[i] = o:CreateTexture(nil, "ARTWORK") 
    end
    
    -- Create the Floor Dropdown Selector
    o.floorDropdown = CreateFrame("DropdownButton", nil, o, "WowStyle1DropdownTemplate")
    o.floorDropdown:SetSize(130, 24)
    -- Anchors it to the top-left of the dungeon map canvas
    o.floorDropdown:SetPoint("TOPLEFT", o, "TOPLEFT", 10, -10)
    o.floorDropdown:SetFrameStrata("HIGH")
    o.floorDropdown:SetFrameLevel(o:GetFrameLevel() + 10)
    o.floorDropdown:Hide()

    overlay = o
    return o
end

-- ==========================================
-- 3. CORE LOGIC
-- ==========================================
local function SetFloor(idx)
    if not currentMapData or not overlay then return end
    idx = math.max(1, math.min(idx, #currentMapData.floors))
    local floor = currentMapData.floors[idx]
    overlay.floorIdx = idx
    
    for i = 1, NTILE do
        local t = overlay.tiles[i]
        t:SetTexture(GetDungeonTilePath(currentMapData, floor, i))
        if t.crR then t:SetTexCoord(0, t.crR, 0, t.crB) end
    end
    
    if overlay.floorDropdown and overlay.floorDropdown.SetDefaultText then 
        overlay.floorDropdown:SetDefaultText("Floor " .. idx) 
    end
    
    if RefreshPins then RefreshPins() end
end

-- ==========================================
-- 3b. INSTANCE PINS (bosses / floor changes / entrances)
-- ==========================================
-- Data lives in MarkerData.lua (MMM_InstancePins, keyed by DUNGEON_MAPS id).
local PIN_TEX = {
    boss     = "Interface\\AddOns\\ModernMapMarkers\\Textures\\boss",
    entrance = "Interface\\AddOns\\ModernMapMarkers\\Textures\\entrance",
}
local PIN_BASE_SIZE = 24

local pinIndex          -- [folder][floorNumber] = list of pin records
local pinFrames = {}

local function BuildPinIndex()
    pinIndex = {}
    local raw = MMM_InstancePins
    if not raw then return end

    for dungeonID, floors in pairs(raw) do
        local dm = DUNGEON_MAPS[dungeonID]
        if dm then
            -- pins are stored per texture folder so wings / approaches share them
            local byFloor = pinIndex[dm.folder]
            if not byFloor then byFloor = {}; pinIndex[dm.folder] = byFloor end

            for floor, list in pairs(floors) do
                local out, bossAt = {}, {}
                for _, p in ipairs(list) do
                    local kind, x, y = p[1], p[2], p[3]
                    if kind == "boss" then
                        -- bosses sharing a spot become one pin with several names
                        local key = string.format("%.3f:%.3f", x, y)
                        local rec = bossAt[key]
                        if not rec then
                            rec = { kind = "boss", x = x, y = y, bosses = {} }
                            bossAt[key] = rec
                            out[#out + 1] = rec
                        end
                        local dupe = false
                        for _, b in ipairs(rec.bosses) do
                            if b.name == p[5] then dupe = true break end
                        end
                        if not dupe then
                            rec.bosses[#rec.bosses + 1] = { name = p[5], level = p[6], optional = (p[8] == 2) }
                        end
                    elseif kind == "level" then
                        out[#out + 1] = { kind = "level", x = x, y = y, toFloor = p[4], up = (p[5] == true) }
                    elseif kind == "entrance" then
                        out[#out + 1] = { kind = "entrance", x = x, y = y }
                    end
                end
                byFloor[floor] = out
            end
        end
    end
end

local function FloorIndexOf(floorNum)
    if not currentMapData then return nil end
    for i, f in ipairs(currentMapData.floors) do
        if f == floorNum then return i end
    end
end

local function ShowPinTooltip(pin)
    local rec = pin.rec
    if not rec then return end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")

    if rec.kind == "boss" then
        for i, b in ipairs(rec.bosses) do
            local name, title = (b.name or ""):match("^(.-)%s*<(.-)>$")
            name = name or b.name
            if i == 1 then GameTooltip:SetText(name, 1, 0.82, 0) else GameTooltip:AddLine(name, 1, 0.82, 0) end
            if title then GameTooltip:AddLine("<" .. title .. ">", 0.7, 0.7, 0.7) end
            if type(b.level) == "number" and b.level < 9000 then
                GameTooltip:AddLine("Level " .. b.level, 1, 1, 1)
            end
            if b.optional then GameTooltip:AddLine("Optional boss", 0.6, 0.6, 0.6) end
        end
    elseif rec.kind == "level" then
        local idx = FloorIndexOf(rec.toFloor)
        GameTooltip:SetText((rec.up and "Up to Floor " or "Down to Floor ") .. (idx or "?"), 1, 0.82, 0)
        GameTooltip:AddLine("Click to switch floors", 0.7, 0.7, 0.7)
    else
        GameTooltip:SetText("Entrance / Exit", 1, 0.82, 0)
    end
    GameTooltip:Show()
end

local function GetPin(i)
    local pin = pinFrames[i]
    if pin then return pin end

    pin = CreateFrame("Button", nil, overlay)
    pin:SetFrameLevel(overlay:GetFrameLevel() + 5)
    pin:RegisterForClicks("LeftButtonUp")

    pin.tex = pin:CreateTexture(nil, "ARTWORK")
    pin.tex:SetAllPoints(pin)

    pin.hl = pin:CreateTexture(nil, "HIGHLIGHT")
    pin.hl:SetAllPoints(pin)
    pin.hl:SetBlendMode("ADD")
    pin.hl:SetAlpha(0.5)

    pin:SetScript("OnEnter", ShowPinTooltip)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pin:SetScript("OnClick", function(self)
        local rec = self.rec
        if rec and rec.kind == "level" then
            local idx = FloorIndexOf(rec.toFloor)
            if idx then
                GameTooltip:Hide()
                SetFloor(idx)
            end
        end
    end)

    pinFrames[i] = pin
    return pin
end

RefreshPins = function()
    for _, pin in ipairs(pinFrames) do pin:Hide() end
    if not (overlay and currentMapData and overlay.floorIdx and overlay.fitW) then return end

    if not pinIndex then BuildPinIndex() end
    local byFloor = pinIndex[currentMapData.folder]
    local list = byFloor and byFloor[currentMapData.floors[overlay.floorIdx]]
    if not list then return end

    local size = math.max(14, math.min(36, PIN_BASE_SIZE * (overlay.fitW / CONTENT_W)))
    local n = 0
    for _, rec in ipairs(list) do
        -- floor-change pins only make sense when the target floor exists here
        if rec.kind ~= "level" or FloorIndexOf(rec.toFloor) then
            n = n + 1
            local pin = GetPin(n)
            local path = (rec.kind == "boss") and PIN_TEX.boss or PIN_TEX.entrance
            pin.rec = rec
            pin.tex:SetTexture(path)
            pin.hl:SetTexture(path)

            -- the arrow art points up; flip it for "down" floor changes
            local rot = (rec.kind == "level" and not rec.up) and math.pi or 0
            if pin.tex.SetRotation then
                pin.tex:SetRotation(rot)
                pin.hl:SetRotation(rot)
            end

            pin:SetSize(size, size)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", overlay, "TOPLEFT",
                overlay.fitX0 + rec.x * overlay.fitW,
                -(overlay.fitY0 + rec.y * overlay.fitH))
            pin:Show()
        end
    end
end

local function BuildFloorDropdown(data, currentFloorIdx)
    local dd = overlay.floorDropdown
    if not dd then return end
    
    -- Hide if the dungeon only has 1 floor
    if #data.floors <= 1 then 
        dd:Hide() 
        return 
    end            
    
    dd:SetupMenu(function(dropdown, root)
        for j = 1, #data.floors do
            local label = "Floor " .. j
            root:CreateRadio(label,
                function() return overlay.floorIdx == j end,
                function()
                    currentFloorIdx = j
                    SetFloor(j)
                end
            )
        end
    end)
    
    dd:SetDefaultText("Floor " .. currentFloorIdx)
    dd:Show()
end

local function ShowDungeonMap(data, floorIdx)
    if InCombatLockdown() then return false end
    local wmf = _G.WorldMapFrame
    if not (wmf and ensureOverlay()) then return false end
    
    currentMapData = data
    
    -- Use the requested floor, the default floor, or floor 1
    floorIdx = data.defaultFloor or floorIdx or 1
    floorIdx = math.max(1, math.min(floorIdx, #data.floors))
    
    SetFloor(floorIdx)
    BuildFloorDropdown(data, floorIdx)
    layoutTiles()
    
    overlay:Show()
    return true
end

local function HideDungeonMap()
    if overlay then overlay:Hide() end
    currentMapData = nil
end

local function normalizeString(s) 
    return (s or ""):lower():gsub("[^%w]", "") 
end

local function GetDungeonDataByName(name)
    local q = normalizeString(name)
    if q == "" then return nil end
    
    for id, d in pairs(DUNGEON_MAPS) do
        if normalizeString(d.folder) == q or normalizeString(d.name) == q then 
            return d 
        end
    end
    return nil
end

local function autoLoadForInstance()
    if InCombatLockdown() then return end
    if not IsInInstance() then return end
    local name, itype = GetInstanceInfo()
    if itype ~= "party" and itype ~= "raid" then return end
    
    local data = GetDungeonDataByName(name)
    if data and not data.comingSoon then
        ShowDungeonMap(data, 1)
    end
end

-- ==========================================
-- 4. BOOTSTRAP EVENTS
-- ==========================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(_, event)
    local wmf = _G.WorldMapFrame
    if wmf and not wmf._mmmDungeonAutoShow then
        wmf._mmmDungeonAutoShow = true
        wmf:HookScript("OnShow", autoLoadForInstance)
        wmf:HookScript("OnHide", HideDungeonMap)
    end
    
    -- Drop map if we leave the instance while the map is open
    if event == "PLAYER_ENTERING_WORLD" and overlay and overlay:IsShown() and not IsInInstance() then
        HideDungeonMap()
    end
end)

-- Expose to your main file if you need manual triggers
MMM.ShowDungeonMap = ShowDungeonMap
MMM.HideDungeonMap = HideDungeonMap
MMM.GetDungeonOverlay = function() return overlay end

MMM.ShowDungeonMapByID = function(id, floorIdx)
    local data = DUNGEON_MAPS[id]
    if COMING_SOON_IDS[id] or (data and data.comingSoon) then
        print(COMING_SOON_MSG)
        return
    end
    if data then 
        -- Use the requested floor, OR the default floor defined in the table, OR floor 1
        local startFloor = data.defaultFloor or floorIdx or 1
        ShowDungeonMap(data, startFloor) 
    else
        print("MMM Debug: ERROR - No map data found in DUNGEON_MAPS for ID:", id)
    end
end