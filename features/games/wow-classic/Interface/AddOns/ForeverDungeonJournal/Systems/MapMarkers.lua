local ADDON_NAME, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
local QUEST_START_MAPS = FDJ.QUEST_START_MAPS or {}
local function L(key, ...)
    if FDJ and FDJ.L then return FDJ.L(key, ...) end
    return key
end
local function FreeText(text)
    return FDJ.LocalizeFreeText and FDJ.LocalizeFreeText(text) or text
end

-- Forever currently exposes the map canvas, but its user-waypoint API is not
-- reliable. Use our own pins on the Blizzard map instead of C_Map.SetUserWaypoint.
-- Multiple pins are kept at once so players can mark several quest givers/starts
-- before planning a route through the zone.
local mapTargets = {}
local mapMarkers = {}
local questStartMapTicker

-- Optional full-route overlay used by travel guides. The route is stored as a
-- series of zone-local points and translated to the requested continent map.
local activeRouteMap
local routeOverlayParent
local routeOverlayCanvas
local routeOverlayFrame
local routeOverlayLines = {}
local routeOverlayShadows = {}
local routeOverlayDots = {}

-- Quest-giver raid-target priority requested for navigation:
-- Blue Square, Diamond, Triangle, Circle, Skull, Moon, Star.
-- Red X is intentionally skipped.
local QUEST_GIVER_MARK_PRIORITY = { 6, 3, 4, 2, 8, 5, 1 }
local QUEST_GIVER_MARK_NAMES = {
    [1] = "Star",
    [2] = "Circle",
    [3] = "Diamond",
    [4] = "Triangle",
    [5] = "Moon",
    [6] = "Square",
    [8] = "Skull",
}

local function GetWorldMapCanvasChild()
    if not WorldMapFrame then return nil end
    if type(WorldMapFrame.GetCanvas) == "function" then
        local ok, canvas = pcall(WorldMapFrame.GetCanvas, WorldMapFrame)
        if ok and canvas then return canvas end
    end
    if WorldMapFrame.ScrollContainer then
        return WorldMapFrame.ScrollContainer.Child or WorldMapFrame.ScrollContainer
    end
    return nil
end

local function TargetKey(loc)
    if not loc then return nil end
    return table.concat({
        tostring(loc.mapID or ""),
        string.format("%.5f", tonumber(loc.x) or 0),
        string.format("%.5f", tonumber(loc.y) or 0),
        tostring(loc.markerType or "quest"),
        tostring(loc.label or "")
    }, "|")
end

local function IsTargetableNPCMarker(target)
    if not target then return false end
    return target.markerType ~= "dungeon" and target.markerType ~= "location"
end

local function RemoveTarget(target)
    if not target then return end
    local key = target._fdjKey or TargetKey(target)
    if key then mapTargets[key] = nil end
    if FDJ.ClearWaypointArrow then FDJ.ClearWaypointArrow(target) end -- arrow
    local marker = key and mapMarkers[key]
    if marker then
        marker:Hide()
        marker.target = nil
    end
    GameTooltip:Hide()
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd36bDungeonJournal:|r " .. L("MAP_MARKER_REMOVED"))
    end
end

local function QuestGiverName(target)
    if not IsTargetableNPCMarker(target) then return nil end
    local name = target.targetName or target.label
    if type(name) ~= "string" then return nil end
    -- Labels may include a location after an em dash, e.g.
    -- "Guard Berton — Lakeshire". Only the NPC name belongs in /targetexact.
    name = name:match("^%s*(.-)%s+—%s+.+$") or name
    name = name:gsub("[\r\n]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    return name
end

local function RaidMarkIndexForTarget(target)
    local npcName = QuestGiverName(target)
    if not npcName then return nil end

    -- Reuse the same icon when two active quest pins point at the same NPC.
    local used = {}
    for _, active in pairs(mapTargets) do
        if active and IsTargetableNPCMarker(active) then
            local activeName = QuestGiverName(active)
            if activeName == npcName and active.raidMarkIndex then
                return active.raidMarkIndex
            end
            if active.raidMarkIndex then
                used[active.raidMarkIndex] = true
            end
        end
    end

    for _, index in ipairs(QUEST_GIVER_MARK_PRIORITY) do
        if not used[index] then return index end
    end
    return nil
end

local function PlayerIsNearRecordedLocation(target)
    if not target or not target.mapID or not C_Map then return false end
    if type(C_Map.GetBestMapForUnit) ~= "function" or type(C_Map.GetPlayerMapPosition) ~= "function" then
        return false
    end

    local okMap, playerMapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not okMap or not playerMapID or playerMapID ~= target.mapID then return false end

    local okPos, pos = pcall(C_Map.GetPlayerMapPosition, target.mapID, "player")
    if not okPos or not pos then return false end

    local px, py
    if type(pos.GetXY) == "function" then
        local okXY, x, y = pcall(pos.GetXY, pos)
        if okXY then px, py = x, y end
    elseif type(pos.x) == "number" and type(pos.y) == "number" then
        px, py = pos.x, pos.y
    end
    if type(px) ~= "number" or type(py) ~= "number" then return false end

    local dx = px - (tonumber(target.x) or 0)
    local dy = py - (tonumber(target.y) or 0)
    -- Keep automatic targeting deliberately short-range. The recorded map point
    -- is for navigation; once the player is roughly within local targeting range
    -- we enable /targetexact. Distant Show on Map clicks remain map-only.
    return (dx * dx + dy * dy) <= (0.04 * 0.04)
end

local function BuildTargetAndMarkMacro(target)
    local npcName = QuestGiverName(target)
    if not npcName then return nil, nil end
    local markIndex = target.raidMarkIndex or RaidMarkIndexForTarget(target)
    if not markIndex then return nil, nil end

    -- Keep targeting and raid marking inside the hardware-click macro. The '~'
    -- form applies the icon only when the target does not already have one, so
    -- repeated clicks never toggle an existing marker off. This also avoids
    -- reading UnitName/GetRaidTargetIndex values that may be secret on Forever.
    local text = "/targetexact " .. npcName .. "\n/tm ~" .. tostring(markIndex)
    return text, markIndex
end

local function ApplyQuestGiverRaidMark(button, target)
    -- Targeting and marking are handled by the secure click macro above. Do not
    -- inspect UnitName/GetRaidTargetIndex here: those values can be secret on
    -- tainted execution paths and comparing them raises a Lua error.
end

local function ConfigureTargetAndMarkAction(button, target, requireNearby)
    if not button or not button._fdjCanTarget then return end
    if InCombatLockdown and InCombatLockdown() then
        button._fdjPendingTarget = target
        return
    end

    button._fdjPendingTarget = nil
    if not IsTargetableNPCMarker(target) or (requireNearby and not PlayerIsNearRecordedLocation(target)) then
        button:SetAttribute("type1", nil)
        button:SetAttribute("macrotext1", nil)
        button:SetAttribute("macrotext", nil)
        button._fdjTargetName = nil
        button._fdjRaidMarkIndex = nil
        button._fdjTargetEnabled = false
        return
    end

    local macroText, markIndex = BuildTargetAndMarkMacro(target)
    if macroText then
        button:SetAttribute("type1", "macro")
        button:SetAttribute("macrotext1", macroText)
        button:SetAttribute("useOnKeyDown", false)
        button._fdjTargetName = QuestGiverName(target)
        button._fdjRaidMarkIndex = markIndex
        button._fdjTargetEnabled = true
    else
        button:SetAttribute("type1", nil)
        button:SetAttribute("macrotext1", nil)
        button:SetAttribute("macrotext", nil)
        button._fdjTargetName = nil
        button._fdjRaidMarkIndex = nil
        button._fdjTargetEnabled = false
    end
end

local function ConfigureMarkerTargetAction(marker, target)
    -- Map pins should only try to target when the player is close to the recorded
    -- quest giver. Distant pins remain navigation-only and produce no target error.
    ConfigureTargetAndMarkAction(marker, target, true)
end

-- The dungeon entrance icon is drawn this much larger than the Blizzard
-- "Dungeon" atlas' native size (which is what the old marker showed).
local DUNGEON_ENTRANCE_ICON_SCALE = 1.4
local DUNGEON_ENTRANCE_ICON_FALLBACK = 24

-- Turn-in pins use the game's own quest button for a quest to hand in (as
-- on the world map and in the objective tracker): round dark button with a
-- gold ring and the yellow ?, lit up on mouse-over. A game without that art
-- gets the journal's own drawing of it (Media/TurnInMark.tga).
-- (One table, not separate locals: this file is at Lua's 200-local limit.)
local TURN_IN = {
    size = 38,
    ring = "UI-QuestPoi-QuestNumber",
    lit = "UI-QuestPoi-InnerGlow",
    icon = "UI-QuestIcon-TurnIn-Normal",
    art = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\TurnInMark",
}
function TURN_IN.HasAtlas()
    if TURN_IN.hasAtlas == nil then
        local get = C_Texture and C_Texture.GetAtlasInfo
        local ok = type(get) == "function"
        for _, atlas in ipairs({ TURN_IN.ring, TURN_IN.lit, TURN_IN.icon }) do
            if ok then
                local fine, info = pcall(get, atlas)
                ok = fine and info ~= nil
            end
        end
        TURN_IN.hasAtlas = ok
    end
    return TURN_IN.hasAtlas
end

local function CreateMapMarker(key)
    local parent = GetWorldMapCanvasChild()
    if not parent then return nil end

    -- Use the insecure action template when available so a real hardware click can
    -- run /targetexact without turning the Blizzard world-map canvas into a
    -- protected frame. It only performs the target action out of combat.
    local marker
    local ok, created = pcall(CreateFrame, "Button", nil, parent, "InsecureActionButtonTemplate")
    if ok and created then
        marker = created
        marker._fdjCanTarget = true
    else
        marker = CreateFrame("Button", nil, parent)
        marker._fdjCanTarget = false
    end
    marker:SetSize(44, 44)
    marker:SetFrameLevel(10000)
    marker:EnableMouse(true)
    marker._fdjKey = key

    -- Dark disc behind the X so it reads on pale parts of the map.
    marker.backing = marker:CreateTexture(nil, "BACKGROUND", nil, -2)
    marker.backing:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    marker.backing:SetVertexColor(0, 0, 0, 0.62)
    marker.backing:SetSize(32, 32)
    marker.backing:SetPoint("CENTER")

    -- Soft ring that ripples outwards, so the pin catches the eye.
    marker.pulse = marker:CreateTexture(nil, "BACKGROUND", nil, -3)
    marker.pulse:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    marker.pulse:SetVertexColor(1.00, 0.30, 0.10, 0.55)
    marker.pulse:SetBlendMode("ADD")
    marker.pulse:SetSize(32, 32)
    marker.pulse:SetPoint("CENTER")
    -- The ring rests invisible; each ripple fades in, expands and fades out,
    -- then pauses. Nothing snaps back into view when the loop restarts.
    marker.pulse:SetAlpha(0)
    pcall(function()
        local group = marker.pulse:CreateAnimationGroup()
        group:SetLooping("REPEAT")
        local grow = group:CreateAnimation("Scale")
        grow:SetDuration(1.8)
        if grow.SetScaleFrom then grow:SetScaleFrom(0.9, 0.9); grow:SetScaleTo(2.0, 2.0) else grow:SetScale(2.0, 2.0) end
        grow:SetOrigin("CENTER", 0, 0)
        grow:SetEndDelay(0.7)
        local fadeIn = group:CreateAnimation("Alpha")
        fadeIn:SetDuration(0.45)
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(0.55)
        local fadeOut = group:CreateAnimation("Alpha")
        fadeOut:SetStartDelay(0.45)
        fadeOut:SetDuration(1.35)
        fadeOut:SetFromAlpha(0.55)
        fadeOut:SetToAlpha(0)
        fadeOut:SetEndDelay(0.7)
        marker.pulseAnim = group
    end)

    marker.glow = marker:CreateFontString(nil, "BACKGROUND", "ForeverDJ_GameFontNormalLarge")
    marker.glow:SetPoint("CENTER", marker, "CENTER", 0, 0)
    marker.glow:SetText("X")
    marker.glow:SetTextColor(1.00, 0.82, 0.20, 0.32)
    marker.glow:SetScale(1.80)

    marker.outline = {}
    local offsets = { {-1, 0}, {1, 0}, {0, -1}, {0, 1} }
    for i = 1, #offsets do
        local shadow = marker:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
        shadow:SetPoint("CENTER", marker, "CENTER", offsets[i][1], offsets[i][2])
        shadow:SetText("X")
        shadow:SetTextColor(0, 0, 0, 1)
        shadow:SetScale(1.35)
        marker.outline[i] = shadow
    end

    marker.x = marker:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
    marker.x:SetPoint("CENTER", marker, "CENTER", 0, 0)
    marker.x:SetText("X")
    marker.x:SetTextColor(1.00, 0.88, 0.10, 1)
    marker.x:SetScale(1.35)

    -- Turn-in pin: the game's quest button instead of the X.
    do
        local button = CreateFrame("Frame", nil, marker)
        marker.turnInButton = button
        button:SetSize(TURN_IN.size, TURN_IN.size)
        button:SetPoint("CENTER")
        button:EnableMouse(false)
        if TURN_IN.HasAtlas() then
            button.ring = button:CreateTexture(nil, "ARTWORK")
            button.ring:SetAtlas(TURN_IN.ring)
            button.ring:SetSize(TURN_IN.size, TURN_IN.size)
            button.ring:SetPoint("CENTER")
            button.lit = button:CreateTexture(nil, "OVERLAY", nil, 1)
            button.lit:SetAtlas(TURN_IN.lit)
            button.lit:SetBlendMode("ADD")
            button.lit:SetSize(TURN_IN.size, TURN_IN.size)
            button.lit:SetPoint("CENTER")
            button.lit:Hide()
            button.icon = button:CreateTexture(nil, "OVERLAY", nil, 2)
            button.icon:SetAtlas(TURN_IN.icon)
            button.icon:SetSize(TURN_IN.size, TURN_IN.size)
            button.icon:SetPoint("CENTER")
        else
            button.icon = button:CreateTexture(nil, "OVERLAY")
            button.icon:SetTexture(TURN_IN.art)
            button.icon:SetSize(TURN_IN.size, TURN_IN.size)
            button.icon:SetPoint("CENTER")
        end
        button:Hide()
    end

    marker.dungeonIcon = marker:CreateTexture(nil, "OVERLAY")
    marker.dungeonIcon:SetPoint("CENTER")
    local atlasOK = false
    if marker.dungeonIcon.SetAtlas then
        atlasOK = pcall(marker.dungeonIcon.SetAtlas, marker.dungeonIcon, "Dungeon", true)
    end
    -- SetAtlas(..., true) resizes the texture to the atlas' small native size,
    -- which is why the entrance icon looked tiny. Force the size afterwards.
    local nativeSize = atlasOK and marker.dungeonIcon:GetWidth() or 0
    if not nativeSize or nativeSize < 8 then nativeSize = DUNGEON_ENTRANCE_ICON_FALLBACK / DUNGEON_ENTRANCE_ICON_SCALE end
    local iconSize = math.floor(nativeSize * DUNGEON_ENTRANCE_ICON_SCALE + 0.5)
    marker.dungeonIcon:SetSize(iconSize, iconSize)
    if not atlasOK then
        marker.dungeonIcon:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
        marker.dungeonIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    marker.dungeonIcon:Hide()

    marker.dungeonGlow = marker:CreateTexture(nil, "BACKGROUND")
    marker.dungeonGlow:SetPoint("CENTER")
    local glowAtlasOK = false
    if marker.dungeonGlow.SetAtlas then
        glowAtlasOK = pcall(marker.dungeonGlow.SetAtlas, marker.dungeonGlow, "Dungeon", true)
    end
    marker.dungeonGlow:SetSize(iconSize + 8, iconSize + 8)
    if not glowAtlasOK then
        marker.dungeonGlow:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
        marker.dungeonGlow:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    marker.dungeonGlow:SetBlendMode("ADD")
    marker.dungeonGlow:SetVertexColor(1.00, 0.86, 0.35, 0.42)
    marker.dungeonGlow:SetAlpha(0.55)
    marker.dungeonGlow:Hide()

    marker:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if marker._fdjCanTarget then
        marker:SetAttribute("useOnKeyDown", false)
        -- PostClick preserves the action template's own click handler. The previous
        -- OnClick override was why left-click targeting never actually fired.
        marker:SetScript("PostClick", function(self, button)
            if button == "RightButton" then
                RemoveTarget(self.target)
            end
        end)
    else
        marker:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                RemoveTarget(self.target)
            end
        end)
    end
    marker:SetScript("OnEnter", function(self)
        local target = self.target
        if not target then return end
        -- Refresh immediately before the hardware click. This also picks up a
        -- newly assigned symbol after other quest pins have been added/removed.
        ConfigureMarkerTargetAction(self, target)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local labelText = FreeText(target.label)
        local detailText = FreeText(target.detail)
        -- Dungeon entrance markers: when the label has no translation of its own,
        -- build it from the translated dungeon name.
        if target.markerType == "dungeon" and type(target.label) == "string" and labelText == target.label then
            local dungeonName = target.label:gsub(" Entrance$", "")
            if FDJ.DB and not FDJ.DB[dungeonName] and FDJ.DB[dungeonName .. ": Graveyard"] then
                dungeonName = dungeonName .. ": Graveyard"
            end
            local localName = FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(dungeonName) or dungeonName
            if FDJ.DB and FDJ.DB[dungeonName] and localName and localName ~= dungeonName then
                labelText = localName
                if detailText == target.detail then
                    local place = FDJ.LocalizeDungeonField and FDJ.LocalizeDungeonField(dungeonName, "location", nil)
                    detailText = L("DUNGEON_ENTRANCE")
                    if type(place) == "string" and place ~= "" then detailText = detailText .. ": " .. place end
                end
            end
        end
        -- Quest pins read "NPC — Quest title" instead of "NPC — place".
        if target.markerType ~= "dungeon" and type(target.questTitle) == "string" and target.questTitle ~= "" and type(labelText) == "string" then
            local dash = " \226\128\148 "
            local cut = labelText:find(dash, 1, true)
            local npc = cut and labelText:sub(1, cut - 1) or labelText
            labelText = npc .. dash .. target.questTitle
        end
        GameTooltip:SetText(labelText or (target.markerType == "dungeon" and L("DUNGEON_ENTRANCE") or L("QUEST_GIVER")))
        local fallbackDetail = target.markerType == "dungeon" and L("DUNGEON_ENTRANCE") or L("QUEST_STARTS_HERE")
        if target.turnIn then detailText, fallbackDetail = nil, L("TURN_IN_HERE") end
        GameTooltip:AddLine(detailText or fallbackDetail, 1, 0.82, 0.05)
        if type(target.patrol) == "table" then
            GameTooltip:AddLine(L("MAP_PATROL"), 1.00, 0.86, 0.35, true)
        end
        if IsTargetableNPCMarker(target) and self._fdjCanTarget then
            GameTooltip:AddLine(L("MAP_LEFT_TARGET"), 0.35, 1.00, 0.35)
        end
        GameTooltip:AddLine(L("MAP_RIGHT_REMOVE"), 1, 1, 1)
        GameTooltip:Show()
    end)
    marker:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- The turn-in button lights up on mouse-over, like the game's.
    marker:HookScript("OnEnter", function(self)
        local lit = self.turnInButton and self.turnInButton.lit
        if lit and self.turnInButton:IsShown() then lit:Show() end
    end)
    marker:HookScript("OnLeave", function(self)
        local lit = self.turnInButton and self.turnInButton.lit
        if lit then lit:Hide() end
    end)
    marker:Hide()
    return marker
end

local function EnsureMarkerForTarget(target)
    local key = target and target._fdjKey
    if not key then return nil end
    local marker = mapMarkers[key]
    if not marker then
        marker = CreateMapMarker(key)
        mapMarkers[key] = marker
    end
    return marker
end

local function GetCurrentMapID()
    if not WorldMapFrame or type(WorldMapFrame.GetMapID) ~= "function" then return nil end
    local ok, value = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
    if ok then return value end
    return nil
end

local function PositionMarker(marker, target, parent)
    if not marker or not target or not parent then return end
    if marker:GetParent() ~= parent then marker:SetParent(parent) end
    marker:SetFrameLevel(10000)
    if marker.target ~= target then
        marker.target = target
        ConfigureMarkerTargetAction(marker, target)
    elseif marker._fdjPendingTarget and (not InCombatLockdown or not InCombatLockdown()) then
        ConfigureMarkerTargetAction(marker, target)
    end

    -- patrolpath: the pin of an NPC that walks around walks its path.
    local px, py = target.x, target.y
    if type(target.patrol) == "table" and FDJ.MapPatrol and FDJ.MapPatrol.Position then
        local ok, ax, ay = pcall(FDJ.MapPatrol.Position, target, marker, parent)
        if ok and ax and ay then px, py = ax, ay end
    end
    local positioned = false
    if type(WorldMapFrame.SetPinPosition) == "function" then
        local ok = pcall(WorldMapFrame.SetPinPosition, WorldMapFrame, marker, px, py)
        positioned = ok
    end
    if not positioned then
        local width, height = parent:GetWidth(), parent:GetHeight()
        if not width or not height or width <= 1 or height <= 1 then return end
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", parent, "TOPLEFT", width * px, -height * py)
    end

    local isDungeon = target.markerType == "dungeon"
    local isTurnIn = not isDungeon and target.turnIn and marker.turnInButton ~= nil
    local showX = not isDungeon and not isTurnIn
    marker.dungeonIcon:SetShown(isDungeon)
    marker.dungeonGlow:SetShown(isDungeon)
    if marker.turnInButton then marker.turnInButton:SetShown(isTurnIn and true or false) end
    marker.glow:SetShown(showX)
    marker.x:SetShown(showX)
    for _, shadow in ipairs(marker.outline) do shadow:SetShown(showX) end
    if marker.backing then marker.backing:SetShown(showX) end
    if marker.pulse then
        marker.pulse:SetShown(not isDungeon)
        if marker.pulseAnim then
            if isDungeon then marker.pulseAnim:Stop() elseif not marker.pulseAnim:IsPlaying() then marker.pulseAnim:Play() end
        end
    end

    marker:Show()
end

-- patrolpath: an NPC that walks around (target.patrol = points on the pin's
-- own map, x/y 0-1) gets its path drawn as a closed loop, in the travel
-- route's style (a line with a dark edge), and its pin walks along it so it
-- reads as a patrol. The pin stops while the mouse is on it, so it can be
-- clicked. target.patrolLoop = false: walked back and forth, not a loop.
-- (In a do-block, reached through FDJ.MapPatrol: this file is at Lua's
-- 200-locals limit.)
do
local Patrol = {
    lines = {}, shadowLines = {}, joints = {}, shadowJoints = {},
    state = setmetatable({}, { __mode = "k" }),
    COLOR = { 1.00, 0.55, 0.15 }, SHADOW_COLOR = { 0.05, 0.01, 0.01, 0.75 },
    THICK = 3, SHADOW_THICK = 6,
}
FDJ.MapPatrol = Patrol

function Patrol.Hide()
    Patrol.key = nil
    for _, pool in ipairs({ Patrol.lines, Patrol.shadowLines, Patrol.joints, Patrol.shadowJoints }) do
        for _, piece in ipairs(pool) do piece:Hide() end
    end
end

function Patrol.Line(index, shadow)
    local pool = shadow and Patrol.shadowLines or Patrol.lines
    local line = pool[index]
    if not line and type(Patrol.frame.CreateLine) == "function" then
        line = Patrol.frame:CreateLine(nil, "OVERLAY", nil, shadow and 5 or 6)
        if shadow then
            local c = Patrol.SHADOW_COLOR
            line:SetColorTexture(c[1], c[2], c[3], c[4])
        else
            local c = Patrol.COLOR
            line:SetColorTexture(c[1], c[2], c[3], 1)
        end
        line:SetThickness(shadow and Patrol.SHADOW_THICK or Patrol.THICK)
        pool[index] = line
    end
    return line
end

-- Round joints, like the route's: no notches where the short pieces meet.
function Patrol.Joint(index, shadow)
    local pool = shadow and Patrol.shadowJoints or Patrol.joints
    local dot = pool[index]
    if not dot then
        dot = Patrol.frame:CreateTexture(nil, "OVERLAY", nil, shadow and 5 or 6)
        dot:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        local c = shadow and Patrol.SHADOW_COLOR or Patrol.COLOR
        dot:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        local size = shadow and Patrol.SHADOW_THICK or Patrol.THICK
        dot:SetSize(size, size)
        pool[index] = dot
    end
    return dot
end

-- Catmull-Rom through the points (pixels), closed for a loop.
function Patrol.Curve(points, loop)
    local n = #points
    local function P(i)
        if loop then return points[(i - 1) % n + 1] end
        if i < 1 then i = 1 elseif i > n then i = n end
        return points[i]
    end
    local out = {}
    for i = 1, loop and n or (n - 1) do
        local p0, p1, p2, p3 = P(i - 1), P(i), P(i + 1), P(i + 2)
        for s = 0, 15 do
            local t = s / 16
            local t2, t3 = t * t, t * t * t
            out[#out + 1] = {
                x = 0.5 * (2 * p1.x + (p2.x - p0.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2
                    + (3 * p1.x - p0.x - 3 * p2.x + p3.x) * t3),
                y = 0.5 * (2 * p1.y + (p2.y - p0.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2
                    + (3 * p1.y - p0.y - 3 * p2.y + p3.y) * t3),
            }
        end
    end
    local last = loop and points[1] or points[n]
    out[#out + 1] = { x = last.x, y = last.y }
    return out
end

-- The path of a target on a canvas of this size, in canvas units, with the
-- distance along it at every point (cached on the target).
function Patrol.Path(target, width, height)
    if type(target.patrol) ~= "table" or not width or not height or width <= 1 or height <= 1 then return nil end
    local key = math.floor(width + 0.5) .. "x" .. math.floor(height + 0.5)
    local cached = target._fdjPatrolPath
    if cached and cached.key == key then return cached end
    local points = {}
    for _, p in ipairs(target.patrol) do
        local px, py = tonumber(p[1] or p.x), tonumber(p[2] or p.y)
        if px and py then points[#points + 1] = { x = px * width, y = py * height } end
    end
    if #points < 2 then return nil end
    local curve = Patrol.Curve(points, target.patrolLoop ~= false)
    local cum, total = { 0 }, 0
    for i = 2, #curve do
        local dx, dy = curve[i].x - curve[i - 1].x, curve[i].y - curve[i - 1].y
        total = total + math.sqrt(dx * dx + dy * dy)
        cum[i] = total
    end
    if total <= 0 then return nil end
    cached = { key = key, curve = curve, cum = cum, total = total, loop = target.patrolLoop ~= false }
    target._fdjPatrolPath = cached
    return cached
end

-- Where the walking pin is now (x/y 0-1). One lap takes 6-16 seconds.
function Patrol.Position(target, marker, parent)
    local width, height = parent:GetWidth(), parent:GetHeight()
    local path = Patrol.Path(target, width, height)
    if not path then return nil end
    local now = (GetTime and GetTime()) or 0
    local st = Patrol.state[target]
    if not st then
        st = { dist = 0, last = now }
        Patrol.state[target] = st
    end
    local dt = now - st.last
    st.last = now
    if dt < 0 or dt > 0.5 then dt = 0 end -- the map was closed: carry on from there
    local lap = math.max(6, math.min(16, path.total / 16))
    local span = path.loop and path.total or path.total * 2
    if not (marker and marker.IsMouseOver and marker:IsMouseOver()) then
        st.dist = (st.dist + dt * path.total / lap) % span
    end
    local d = st.dist
    if not path.loop and d > path.total then d = span - d end -- on the way back
    local cum, curve = path.cum, path.curve
    local lo, hi = 1, #cum
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if cum[mid] <= d then lo = mid else hi = mid end
    end
    local seg = cum[hi] - cum[lo]
    local f = seg > 0 and (d - cum[lo]) / seg or 0
    local a, b = curve[lo], curve[hi]
    return (a.x + (b.x - a.x) * f) / width, (a.y + (b.y - a.y) * f) / height
end

function Patrol.Update(parent, currentMapID)
    local list = {}
    for _, target in pairs(mapTargets) do
        if type(target.patrol) == "table" and #target.patrol >= 2 and target.mapID == currentMapID then
            list[#list + 1] = target
        end
    end
    local width, height = parent:GetWidth(), parent:GetHeight()
    if #list == 0 or not width or not height or width <= 1 or height <= 1 then
        Patrol.Hide()
        return
    end
    table.sort(list, function(a, b) return tostring(a._fdjKey) < tostring(b._fdjKey) end)
    local key = tostring(currentMapID) .. ":" .. math.floor(width + 0.5) .. "x" .. math.floor(height + 0.5)
    for _, target in ipairs(list) do key = key .. ":" .. tostring(target._fdjKey) end
    if not Patrol.frame then
        Patrol.frame = CreateFrame("Frame", nil, parent)
        Patrol.frame:EnableMouse(false)
    end
    local frame = Patrol.frame
    if frame:GetParent() ~= parent then
        frame:SetParent(parent)
        Patrol.key = nil
    end
    frame:ClearAllPoints()
    frame:SetAllPoints(parent)
    frame:SetFrameLevel(9990) -- under the pins (10000)
    frame:Show()
    if Patrol.key == key then return end
    Patrol.key = key

    local usedLines, usedJoints = 0, 0
    for _, target in ipairs(list) do
        local path = Patrol.Path(target, width, height)
        local curve = path and path.curve or {}
        for i = 1, #curve do
            local a = curve[i]
            usedJoints = usedJoints + 1
            for _, shadow in ipairs({ true, false }) do
                local dot = Patrol.Joint(usedJoints, shadow)
                dot:ClearAllPoints()
                dot:SetPoint("CENTER", frame, "TOPLEFT", a.x, -a.y)
                dot:Show()
            end
            local b = curve[i + 1]
            if b then
                usedLines = usedLines + 1
                for _, shadow in ipairs({ true, false }) do
                    local line = Patrol.Line(usedLines, shadow)
                    if line then
                        line:SetStartPoint("TOPLEFT", frame, a.x, -a.y)
                        line:SetEndPoint("TOPLEFT", frame, b.x, -b.y)
                        line:Show()
                    end
                end
            end
        end
    end
    for i = usedLines + 1, #Patrol.lines do Patrol.lines[i]:Hide() end
    for i = usedLines + 1, #Patrol.shadowLines do Patrol.shadowLines[i]:Hide() end
    for i = usedJoints + 1, #Patrol.joints do Patrol.joints[i]:Hide() end
    for i = usedJoints + 1, #Patrol.shadowJoints do Patrol.shadowJoints[i]:Hide() end
end
end

-- The smoothed polyline only depends on the route, the open map and the canvas
-- size, so it is rebuilt only when one of those changes (the map ticker runs
-- every 50 ms).
local routeGeometryCache = { key = nil, segments = nil }

-- Route colours and hover state (the line turns orange while hovered).
local ROUTE_COLOR = { 0.95, 0.08, 0.05 }
local ROUTE_HOVER_COLOR = { 1.00, 0.55, 0.15 }
local ROUTE_HOVER_DISTANCE = 8 -- UI units from the line that count as "on it"
local routeHovered = false

local HideRouteWaypointsHook -- set once the waypoint code below is defined

local function HideRouteOverlay()
    routeGeometryCache.key = nil
    routeGeometryCache.segments = nil
    if HideRouteWaypointsHook then HideRouteWaypointsHook() end
    for _, line in ipairs(routeOverlayLines) do line:Hide() end
    for _, line in ipairs(routeOverlayShadows) do line:Hide() end
    for _, dot in ipairs(routeOverlayDots) do dot:Hide() end
end

-- Rectangle of `mapID` expressed in the coordinates of `onMapID`, cached.
-- Returns minX, maxX, minY, maxY or nil.
local routeRectCache = {}
local function MapRectOn(mapID, onMapID)
    if mapID == onMapID then return 0, 1, 0, 1 end
    local key = tostring(mapID) .. ":" .. tostring(onMapID)
    local cached = routeRectCache[key]
    if cached ~= nil then
        if cached == false then return nil end
        return cached[1], cached[2], cached[3], cached[4]
    end
    local result = false
    if C_Map and type(C_Map.GetMapRectOnMap) == "function" then
        local ok, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, mapID, onMapID)
        if ok and minX and maxX and minY and maxY and maxX > minX and maxY > minY then
            result = { minX, maxX, minY, maxY }
        end
    end
    routeRectCache[key] = result
    if not result then return nil end
    return result[1], result[2], result[3], result[4]
end

-- World-position round trip, used when the client exposes no rectangle for a
-- map pair (some city maps). Results are cached per point and target map.
local function WorldRoundTrip(pointMapID, x, y, targetMapID)
    if not (C_Map and type(C_Map.GetWorldPosFromMapPos) == "function"
        and type(C_Map.GetMapPosFromWorldPos) == "function") then
        return nil
    end
    local pos = (type(CreateVector2D) == "function" and CreateVector2D(x, y)) or { x = x, y = y }
    local okWorld, continentID, worldPos = pcall(C_Map.GetWorldPosFromMapPos, pointMapID, pos)
    if not okWorld or not continentID or not worldPos then return nil end
    local okMap, _, mapPos = pcall(C_Map.GetMapPosFromWorldPos, continentID, worldPos, targetMapID)
    if not okMap or not mapPos then return nil end
    local mx, my = mapPos.x, mapPos.y
    if (not mx or not my) and mapPos.GetXY then mx, my = mapPos:GetXY() end
    return mx, my
end

-- Project one stored route point (native zone/city coordinates) onto the map
-- that is currently open. The route's continent is used as the common frame,
-- so points from neighbouring zones land in the right place when zoomed in.
-- True when `ancestorID` is the world map (or any map) that contains the
-- route continent, e.g. Azeroth (947) for Eastern Kingdoms (1415).
local routeAncestorCache = {}
local function MapIsAncestorOf(ancestorID, mapID)
    if not ancestorID or not mapID or ancestorID == mapID then return false end
    local key = tostring(ancestorID) .. "<" .. tostring(mapID)
    local cached = routeAncestorCache[key]
    if cached ~= nil then return cached end
    local found = false
    if C_Map and type(C_Map.GetMapInfo) == "function" then
        local id, guard = mapID, 0
        while id and id ~= 0 and guard < 12 do
            local ok, info = pcall(C_Map.GetMapInfo, id)
            if not ok or not info then break end
            if info.parentMapID == ancestorID then found = true; break end
            id = info.parentMapID
            guard = guard + 1
        end
    end
    routeAncestorCache[key] = found
    return found
end

local function ProjectRoutePoint(point, targetMapID, continentID)
    local px, py = tonumber(point.x), tonumber(point.y)
    if not point.mapID or not px or not py then return nil end
    if point.mapID == targetMapID then return px, py end

    -- World map (or anything above the continent): go point -> continent ->
    -- the continent's rectangle on that map. No world-position fallback here,
    -- because that is what used to drop the line into the sea.
    if MapIsAncestorOf(targetMapID, continentID) then
        local aMinX, aMaxX, aMinY, aMaxY = MapRectOn(point.mapID, continentID)
        local cMinX, cMaxX, cMinY, cMaxY = MapRectOn(continentID, targetMapID)
        if not aMinX or not cMinX then return nil end
        local cx = aMinX + (aMaxX - aMinX) * px
        local cy = aMinY + (aMaxY - aMinY) * py
        return cMinX + (cMaxX - cMinX) * cx, cMinY + (cMaxY - cMinY) * cy
    end

    local aMinX, aMaxX, aMinY, aMaxY = MapRectOn(point.mapID, continentID)
    local tMinX, tMaxX, tMinY, tMaxY = MapRectOn(targetMapID, continentID)
    if aMinX and tMinX then
        local cx = aMinX + (aMaxX - aMinX) * px
        local cy = aMinY + (aMaxY - aMinY) * py
        return (cx - tMinX) / (tMaxX - tMinX), (cy - tMinY) / (tMaxY - tMinY)
    end
    return WorldRoundTrip(point.mapID, px, py, targetMapID)
end

-- Kept for callers elsewhere in the file / addon.
local function RoutePointOnMap(routeMapID, point)
    return ProjectRoutePoint(point, routeMapID, routeMapID)
end

-- Draw the travel route on a dedicated high-level frame above the Blizzard
-- map canvas. Map-reveal addons commonly add their own full-zone textures on
-- top of the normal map artwork; drawing directly on the canvas can leave our
-- route hidden underneath those textures, which looks like broken/missing
-- line sections. Keeping a transparent overlay frame above the canvas makes
-- the route remain continuous with both explored and reveal-all map addons.
local function GetRouteOverlayFrame(canvas)
    if not canvas then return nil end

    if not routeOverlayFrame then
        routeOverlayFrame = CreateFrame("Frame", nil, canvas)
        routeOverlayFrame:EnableMouse(false)
    elseif routeOverlayCanvas ~= canvas then
        routeOverlayFrame:SetParent(canvas)
    end

    routeOverlayCanvas = canvas
    routeOverlayFrame:ClearAllPoints()
    routeOverlayFrame:SetAllPoints(canvas)

    -- Keep this comfortably above map reveal / fog textures while remaining
    -- confined to the map canvas itself.
    if type(routeOverlayFrame.SetFrameStrata) == "function" then
        routeOverlayFrame:SetFrameStrata("HIGH")
    end
    if type(routeOverlayFrame.SetFrameLevel) == "function" then
        local baseLevel = (type(canvas.GetFrameLevel) == "function" and canvas:GetFrameLevel()) or 0
        routeOverlayFrame:SetFrameLevel(math.max(baseLevel + 500, 10000))
    end
    routeOverlayFrame:Show()
    return routeOverlayFrame
end

local function ResetRouteOverlayForParent(parent)
    if routeOverlayParent == parent then return end
    HideRouteOverlay()
    routeOverlayParent = parent
    routeOverlayLines = {}
    routeOverlayShadows = {}
    routeOverlayDots = {}
end

local ROUTE_LINE_THICKNESS = 3
local ROUTE_SHADOW_THICKNESS = 6

local function EnsureRouteLine(parent, index, shadow)
    local pool = shadow and routeOverlayShadows or routeOverlayLines
    local line = pool[index]
    if not line and parent and type(parent.CreateLine) == "function" then
        line = parent:CreateLine(nil, "OVERLAY", nil, shadow and 5 or 6)
        if shadow then
            line:SetColorTexture(0.05, 0.01, 0.01, 0.75)
        else
            local c = routeHovered and ROUTE_HOVER_COLOR or ROUTE_COLOR
            line:SetColorTexture(c[1], c[2], c[3], 1.00)
        end
        pool[index] = line
    end
    if line then
        line:SetThickness(shadow and ROUTE_SHADOW_THICKNESS or ROUTE_LINE_THICKNESS)
    end
    return line
end

-- Round joint caps. Short Line segments leave small notches where they meet
-- at an angle; a disc the width of the line at every vertex closes them so
-- the route reads as one continuous stroke.
local function EnsureRouteDot(parent, index, shadow)
    local slot = index * 2 - (shadow and 1 or 0)
    local dot = routeOverlayDots[slot]
    if not dot and parent then
        dot = parent:CreateTexture(nil, "OVERLAY", nil, shadow and 5 or 6)
        dot:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        if shadow then
            dot:SetVertexColor(0.05, 0.01, 0.01, 0.75)
        else
            local c = routeHovered and ROUTE_HOVER_COLOR or ROUTE_COLOR
            dot:SetVertexColor(c[1], c[2], c[3], 1.00)
        end
        routeOverlayDots[slot] = dot
    end
    if dot then
        local size = shadow and ROUTE_SHADOW_THICKNESS or ROUTE_LINE_THICKNESS
        dot:SetSize(size, size)
    end
    return dot
end

-- Centripetal Catmull-Rom through the traced road points, split at points
-- flagged `corner` (junctions) so real turns stay sharp. Output is in pixels
-- and densified so each drawn segment is only a few pixels long.
local function CatmullRomRun(run, out, stepPx)
    local n = #run
    if n == 1 then out[#out + 1] = run[1]; return end
    local function P(i)
        if i < 1 then
            return { x = 2 * run[1].x - run[2].x, y = 2 * run[1].y - run[2].y }
        elseif i > n then
            return { x = 2 * run[n].x - run[n - 1].x, y = 2 * run[n].y - run[n - 1].y }
        end
        return run[i]
    end
    local function tj(ti, a, b)
        local dx, dy = b.x - a.x, b.y - a.y
        local d = math.sqrt(dx * dx + dy * dy)
        return ti + math.max(math.sqrt(d), 1e-4)
    end
    for i = 1, n - 1 do
        local p0, p1, p2, p3 = P(i - 1), P(i), P(i + 1), P(i + 2)
        local t0 = 0
        local t1 = tj(t0, p0, p1)
        local t2 = tj(t1, p1, p2)
        local t3 = tj(t2, p2, p3)
        local dx, dy = p2.x - p1.x, p2.y - p1.y
        local steps = math.max(1, math.min(24, math.floor(math.sqrt(dx * dx + dy * dy) / stepPx + 0.5)))
        out[#out + 1] = { x = p1.x, y = p1.y }
        for s = 1, steps - 1 do
            local t = t1 + (t2 - t1) * (s / steps)
            local a1x = (t1 - t) / (t1 - t0) * p0.x + (t - t0) / (t1 - t0) * p1.x
            local a1y = (t1 - t) / (t1 - t0) * p0.y + (t - t0) / (t1 - t0) * p1.y
            local a2x = (t2 - t) / (t2 - t1) * p1.x + (t - t1) / (t2 - t1) * p2.x
            local a2y = (t2 - t) / (t2 - t1) * p1.y + (t - t1) / (t2 - t1) * p2.y
            local a3x = (t3 - t) / (t3 - t2) * p2.x + (t - t2) / (t3 - t2) * p3.x
            local a3y = (t3 - t) / (t3 - t2) * p2.y + (t - t2) / (t3 - t2) * p3.y
            local b1x = (t2 - t) / (t2 - t0) * a1x + (t - t0) / (t2 - t0) * a2x
            local b1y = (t2 - t) / (t2 - t0) * a1y + (t - t0) / (t2 - t0) * a2y
            local b2x = (t3 - t) / (t3 - t1) * a2x + (t - t1) / (t3 - t1) * a3x
            local b2y = (t3 - t) / (t3 - t1) * a2y + (t - t1) / (t3 - t1) * a3y
            out[#out + 1] = {
                x = (t2 - t) / (t2 - t1) * b1x + (t - t1) / (t2 - t1) * b2x,
                y = (t2 - t) / (t2 - t1) * b1y + (t - t1) / (t2 - t1) * b2y,
            }
        end
    end
    out[#out + 1] = { x = run[n].x, y = run[n].y }
end

local function SmoothRoutePixels(points, stepPx)
    local out = {}
    local run = {}
    for i, p in ipairs(points) do
        run[#run + 1] = p
        if (p.corner and #run > 1) or i == #points then
            local seg = {}
            CatmullRomRun(run, seg, stepPx)
            local startIndex = (#out > 0) and 2 or 1
            for k = startIndex, #seg do out[#out + 1] = seg[k] end
            run = { p }
        end
    end
    return out
end

-- Liang-Barsky clip of a segment to the canvas (pixels, y down as positive).
local function ClipSegment(x1, y1, x2, y2, w, h)
    local dx, dy = x2 - x1, y2 - y1
    local t0, t1 = 0, 1
    local p = { -dx, dx, -dy, dy }
    local q = { x1, w - x1, y1, h - y1 }
    for i = 1, 4 do
        if p[i] == 0 then
            if q[i] < 0 then return nil end
        else
            local r = q[i] / p[i]
            if p[i] < 0 then
                if r > t1 then return nil end
                if r > t0 then t0 = r end
            else
                if r < t0 then return nil end
                if r < t1 then t1 = r end
            end
        end
    end
    return x1 + t0 * dx, y1 + t0 * dy, x1 + t1 * dx, y1 + t1 * dy
end

local function BuildRouteSegments(currentMapID, width, height)
    local continentID = activeRouteMap.mapID
    local projected = {}
    for _, point in ipairs(activeRouteMap.points or {}) do
        local x, y = ProjectRoutePoint(point, currentMapID, continentID)
        if x and y then
            projected[#projected + 1] = { x = x * width, y = y * height, corner = point.corner }
        end
    end
    if #projected < 2 then return {} end

    -- Skip the route entirely on maps it never comes near.
    local near = false
    for _, p in ipairs(projected) do
        if p.x >= -width * 0.05 and p.x <= width * 1.05 and p.y >= -height * 0.05 and p.y <= height * 1.05 then
            near = true
            break
        end
    end
    if not near then return {} end

    -- Keep the drawn pieces around 4 px long regardless of zoom level.
    local smooth = SmoothRoutePixels(projected, 4)
    local segments = {}
    for i = 1, #smooth - 1 do
        local a, b = smooth[i], smooth[i + 1]
        local x1, y1, x2, y2 = ClipSegment(a.x, a.y, b.x, b.y, width, height)
        if x1 and ((x2 - x1) ~= 0 or (y2 - y1) ~= 0) then
            segments[#segments + 1] = { x1, y1, x2, y2 }
        end
    end
    return segments
end

-- ---------------------------------------------------------------------------
-- Route waypoints (e.g. the Tarren Mill flight path) and hover-to-remove.
-- ---------------------------------------------------------------------------
local routeWaypointFrames = {}
local routeHoverButton
local routeHoverDriver
local ClearRouteOnMap -- forward declaration

local function SetRouteTint(color)
    for _, line in ipairs(routeOverlayLines) do
        line:SetColorTexture(color[1], color[2], color[3], 1.00)
    end
    for slot, dot in pairs(routeOverlayDots) do
        if slot % 2 == 0 then dot:SetVertexColor(color[1], color[2], color[3], 1.00) end
    end
end

local WAYPOINT_ICONS = {
    flightpath = "Interface\\Minimap\\Tracking\\FlightMaster",
}

local function EnsureWaypointFrame(parent, index)
    local frame = routeWaypointFrames[index]
    if frame and frame:GetParent() ~= parent then frame:SetParent(parent) end
    if not frame then
        frame = CreateFrame("Frame", nil, parent)
        frame:SetSize(22, 22)
        frame:EnableMouse(true)
        frame.icon = frame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetPoint("CENTER")
        frame.icon:SetSize(20, 20)
        frame:SetScript("OnEnter", function(self)
            if not GameTooltip or not self.waypoint then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L(self.waypoint.titleKey), 1, 0.82, 0)
            if self.waypoint.textKey then
                GameTooltip:AddLine(L(self.waypoint.textKey), 1, 1, 1, true)
            end
            GameTooltip:AddLine(L("ROUTE_REMOVE_HINT"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        frame:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" then
                if ClearRouteOnMap then ClearRouteOnMap() end
            elseif button == "LeftButton" and self.opensMapID and WorldMapFrame
                and type(WorldMapFrame.SetMapID) == "function" then
                if GameTooltip then GameTooltip:Hide() end
                pcall(WorldMapFrame.SetMapID, WorldMapFrame, self.opensMapID)
            end
        end)
        routeWaypointFrames[index] = frame
    end
    frame:SetFrameLevel(10001)
    return frame
end

local function HideRouteWaypoints()
    for _, frame in ipairs(routeWaypointFrames) do frame:Hide() end
end
HideRouteWaypointsHook = HideRouteWaypoints

-- Runs every map tick: cheap (a handful of points) and needs to follow zoom,
-- because the icon is counter-scaled to keep a constant on-screen size.
local function UpdateRouteWaypoints(parent, currentMapID, width, height)
    local waypoints = activeRouteMap and activeRouteMap.waypoints
    if not waypoints or #waypoints == 0 then HideRouteWaypoints(); return end
    local canvasScale = parent:GetScale() or 1
    if canvasScale <= 0 then canvasScale = 1 end
    local shown = 0
    for i, waypoint in ipairs(waypoints) do
        local frame = EnsureWaypointFrame(parent, i)
        local x, y = ProjectRoutePoint(waypoint, currentMapID, activeRouteMap.mapID)
        if frame and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            frame.waypoint = waypoint
            if waypoint.mapID ~= currentMapID then
                frame.opensMapID = waypoint.mapID
            else
                frame.opensMapID = nil
            end
            frame.icon:SetTexture(WAYPOINT_ICONS[waypoint.icon] or WAYPOINT_ICONS.flightpath)
            frame:SetScale(1 / canvasScale)
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", parent, "TOPLEFT", width * x * canvasScale, -height * y * canvasScale)
            frame:Show()
            shown = i
        elseif frame then
            frame:Hide()
        end
    end
    for i = #waypoints + 1, #routeWaypointFrames do routeWaypointFrames[i]:Hide() end
end

local function DistanceToSegmentSq(px, py, x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    local len = dx * dx + dy * dy
    local t = 0
    if len > 0 then
        t = ((px - x1) * dx + (py - y1) * dy) / len
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
    end
    local qx, qy = x1 + t * dx - px, y1 + t * dy - py
    return qx * qx + qy * qy
end

local function EnsureRouteHoverButton(parent)
    if not routeHoverButton then
        routeHoverButton = CreateFrame("Button", nil, parent)
        routeHoverButton:SetSize(24, 24)
        routeHoverButton:RegisterForClicks("RightButtonUp")
        -- Let left clicks through to the map where the client supports it.
        if type(routeHoverButton.SetPassThroughButtons) == "function" then
            pcall(routeHoverButton.SetPassThroughButtons, routeHoverButton, "LeftButton", "MiddleButton")
        end
        routeHoverButton:SetScript("OnClick", function(_, button)
            if button == "RightButton" and ClearRouteOnMap then ClearRouteOnMap() end
        end)
        routeHoverButton:Hide()
    end
    if routeHoverButton:GetParent() ~= parent then routeHoverButton:SetParent(parent) end
    routeHoverButton:SetFrameLevel(9999)
    return routeHoverButton
end

local function SetRouteHovered(hovered, parent)
    if hovered == routeHovered then return end
    routeHovered = hovered
    SetRouteTint(hovered and ROUTE_HOVER_COLOR or ROUTE_COLOR)
    if hovered then
        if GameTooltip and routeHoverButton then
            GameTooltip:SetOwner(routeHoverButton, "ANCHOR_NONE")
            GameTooltip:ClearAllPoints()
            -- Sit to the right of the cursor so the tooltip never covers the line.
            GameTooltip:SetPoint("LEFT", routeHoverButton, "RIGHT", 10, 0)
            GameTooltip:SetText(L("ROUTE_REMOVE_HINT"), 1, 1, 1)
            GameTooltip:Show()
        end
    else
        if routeHoverButton then routeHoverButton:Hide() end
        if GameTooltip and routeHoverButton and GameTooltip:GetOwner() == routeHoverButton then
            GameTooltip:Hide()
        end
    end
end

local function UpdateRouteHover()
    local segments = routeGeometryCache.segments
    local parent = routeOverlayParent
    if not activeRouteMap or not segments or #segments == 0 or not parent
        or not WorldMapFrame or not WorldMapFrame:IsShown() or not parent:IsVisible() then
        SetRouteHovered(false)
        return
    end
    -- Ignore the cursor while it is over our own waypoint icons.
    for _, frame in ipairs(routeWaypointFrames) do
        if frame:IsShown() and frame:IsMouseOver() then SetRouteHovered(false); return end
    end
    local scroll = WorldMapFrame.ScrollContainer
    if (scroll and not scroll:IsMouseOver()) or (not scroll and not parent:IsMouseOver()) then
        SetRouteHovered(false)
        return
    end

    local scale = parent:GetEffectiveScale()
    local left, top = parent:GetLeft(), parent:GetTop()
    if not scale or scale <= 0 or not left or not top then SetRouteHovered(false); return end
    local cx, cy = GetCursorPosition()
    local px, py = cx / scale - left, top - cy / scale

    local uiScale = (UIParent and UIParent:GetEffectiveScale()) or 1
    local threshold = ROUTE_HOVER_DISTANCE * uiScale / scale
    local thresholdSq = threshold * threshold
    local near = false
    for _, seg in ipairs(segments) do
        if DistanceToSegmentSq(px, py, seg[1], seg[2], seg[3], seg[4]) <= thresholdSq then
            near = true
            break
        end
    end

    if near then
        local button = EnsureRouteHoverButton(parent)
        local canvasScale = parent:GetScale() or 1
        if canvasScale <= 0 then canvasScale = 1 end
        button:SetScale(1 / canvasScale)
        button:ClearAllPoints()
        button:SetPoint("CENTER", parent, "TOPLEFT", px * canvasScale, -py * canvasScale)
        button:Show()
        SetRouteHovered(true, parent)
    else
        SetRouteHovered(false)
    end
end

local function StartRouteHoverDriver()
    if routeHoverDriver then routeHoverDriver:Show(); return end
    routeHoverDriver = CreateFrame("Frame")
    routeHoverDriver.elapsed = 0
    routeHoverDriver:SetScript("OnUpdate", function(self, elapsed)
        if not activeRouteMap then self:Hide(); SetRouteHovered(false); return end
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 0.02 then return end
        self.elapsed = 0
        UpdateRouteHover()
    end)
end

-- Draw on the route's continent, the maps inside it, and the world map above
-- it (handled by ProjectRoutePoint). Other continents never show the route.
local routeMapInsideCache = {}
local function MapIsInsideContinent(mapID, continentID)
    if mapID == continentID then return true end
    local key = tostring(mapID) .. ">" .. tostring(continentID)
    local cached = routeMapInsideCache[key]
    if cached ~= nil then return cached end
    local inside = false
    if C_Map and type(C_Map.GetMapInfo) == "function" then
        local id, guard = mapID, 0
        while id and id ~= 0 and guard < 12 do
            local ok, info = pcall(C_Map.GetMapInfo, id)
            if not ok or not info then break end
            if info.parentMapID == continentID then inside = true; break end
            id = info.parentMapID
            guard = guard + 1
        end
    end
    routeMapInsideCache[key] = inside
    return inside
end

-- When the player switches maps, the Blizzard canvas can report the new map ID
-- for a frame while its size/scale still belong to the previous map. Drawing
-- in that frame put the route in the wrong place for a split second. The map
-- state must therefore be seen unchanged on two consecutive checks before the
-- route is drawn.
local routeStability = { key = nil, stable = false }
local routeMapChangeHooked = false
local function HookRouteMapChanges()
    if routeMapChangeHooked or not WorldMapFrame or type(hooksecurefunc) ~= "function" then return end
    if type(WorldMapFrame.OnMapChanged) == "function" then
        routeMapChangeHooked = pcall(hooksecurefunc, WorldMapFrame, "OnMapChanged", function()
            routeStability.key = nil
            routeStability.stable = false
            HideRouteOverlay()
        end)
    end
end

local function UpdateRouteOverlay()
    if not activeRouteMap or not WorldMapFrame or not WorldMapFrame:IsShown() then
        routeStability.key = nil
        routeStability.stable = false
        HideRouteOverlay()
        return
    end

    local currentMapID = GetCurrentMapID()
    if not currentMapID or not (MapIsInsideContinent(currentMapID, activeRouteMap.mapID)
        or MapIsAncestorOf(currentMapID, activeRouteMap.mapID)) then
        routeStability.key = nil
        routeStability.stable = false
        HideRouteOverlay()
        return
    end

    local canvas = GetWorldMapCanvasChild()
    if not canvas then return end
    local parent = GetRouteOverlayFrame(canvas)
    if not parent then return end
    if routeOverlayParent ~= parent then routeGeometryCache.key = nil end
    ResetRouteOverlayForParent(parent)

    -- Geometry is still measured from the actual map canvas. The dedicated
    -- overlay is anchored 1:1 to it, so these coordinates remain identical.
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    if not width or not height or width <= 1 or height <= 1 then return end

    local key = tostring(activeRouteMap) .. ":" .. currentMapID .. ":" .. math.floor(width + 0.5) .. "x" .. math.floor(height + 0.5)

    if routeStability.key ~= key then
        -- Map (or canvas size) just changed: hide now, draw on the next check.
        routeStability.key = key
        routeStability.stable = false
        HideRouteOverlay()
        return
    end
    routeStability.stable = true

    -- Some reveal-map addons rebuild/re-level their overlay frames when the
    -- zone changes. Re-assert our route layer after the map has stabilised.
    if routeOverlayFrame then
        if type(routeOverlayFrame.SetFrameStrata) == "function" then
            routeOverlayFrame:SetFrameStrata("HIGH")
        end
        if type(routeOverlayFrame.SetFrameLevel) == "function" then
            local baseLevel = (type(canvas.GetFrameLevel) == "function" and canvas:GetFrameLevel()) or 0
            routeOverlayFrame:SetFrameLevel(math.max(baseLevel + 500, 10000))
        end
    end

    UpdateRouteWaypoints(parent, currentMapID, width, height)
    if routeGeometryCache.key == key and routeGeometryCache.drawn then return end

    local segments = BuildRouteSegments(currentMapID, width, height)
    routeGeometryCache.key = key
    routeGeometryCache.segments = segments

    if #segments == 0 then
        HideRouteOverlay()
        routeGeometryCache.key = key
        routeGeometryCache.drawn = true
        return
    end

    for i, seg in ipairs(segments) do
        local x1, y1, x2, y2 = seg[1], -seg[2], seg[3], -seg[4]

        local shadow = EnsureRouteLine(parent, i, true)
        if shadow then
            shadow:SetStartPoint("TOPLEFT", parent, x1, y1)
            shadow:SetEndPoint("TOPLEFT", parent, x2, y2)
            shadow:Show()
        end
        local line = EnsureRouteLine(parent, i, false)
        if line then
            line:SetStartPoint("TOPLEFT", parent, x1, y1)
            line:SetEndPoint("TOPLEFT", parent, x2, y2)
            line:Show()
        end

        for _, isShadow in ipairs({ true, false }) do
            local dot = EnsureRouteDot(parent, i, isShadow)
            if dot then
                dot:ClearAllPoints()
                dot:SetPoint("CENTER", parent, "TOPLEFT", x1, y1)
                dot:Show()
            end
        end
    end

    local n = #segments
    for i = n + 1, #routeOverlayLines do routeOverlayLines[i]:Hide() end
    for i = n + 1, #routeOverlayShadows do routeOverlayShadows[i]:Hide() end
    for slot = n * 2 + 1, #routeOverlayDots do
        if routeOverlayDots[slot] then routeOverlayDots[slot]:Hide() end
    end
    routeGeometryCache.drawn = true
    SetRouteTint(routeHovered and ROUTE_HOVER_COLOR or ROUTE_COLOR)
end

local function UpdateMapMarkers()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        for _, marker in pairs(mapMarkers) do marker:Hide() end
        FDJ.MapPatrol.Hide()
        return false
    end

    local currentMapID = GetCurrentMapID()
    local parent = GetWorldMapCanvasChild()
    if not parent then return true end

    for key, target in pairs(mapTargets) do
        local marker = EnsureMarkerForTarget(target)
        if marker then
            if currentMapID and currentMapID ~= target.mapID then
                marker:Hide()
            else
                PositionMarker(marker, target, parent)
            end
        end
    end

    -- Hide any orphaned marker frames whose targets were removed.
    for key, marker in pairs(mapMarkers) do
        if not mapTargets[key] then marker:Hide() end
    end
    pcall(FDJ.MapPatrol.Update, parent, currentMapID)
    UpdateRouteOverlay()
    return true
end

local function StartQuestStartMapTicker()
    if questStartMapTicker then return end
    questStartMapTicker = CreateFrame("Frame")
    questStartMapTicker.elapsed = 0
    questStartMapTicker:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 0.05 then return end
        self.elapsed = 0
        UpdateMapMarkers()
    end)
end

local function ForceWorldMapMapID(mapID)
    if not WorldMapFrame or not mapID then return false end
    if not WorldMapFrame:IsShown() then
        -- In combat only the game itself opens the map (M key, or the secure
        -- click Show on Map uses); trying from here would just be blocked.
        if InCombatLockdown and InCombatLockdown() then return false end
        local shown = false
        if type(ShowUIPanel) == "function" then shown = pcall(ShowUIPanel, WorldMapFrame) end
        if not shown then pcall(WorldMapFrame.Show, WorldMapFrame) end
    end
    if type(WorldMapFrame.SetMapID) == "function" then
        local ok = pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID)
        if ok then return true end
    end
    return false
end

local function ShowRecordedLocationOnMap(loc, fallbackText)
    if not loc then return end

    local key = TargetKey(loc)
    if not key then return end
    local target = {}
    for k, v in pairs(loc) do target[k] = v end
    target._fdjKey = key
    -- The journal names the quest this pin was opened for; the tooltip shows it.
    target.questTitle = FDJ.pendingMarkerQuestTitle
    FDJ.pendingMarkerQuestTitle = nil
    -- Opened from a Show Turn In button: the pin is where it is handed in.
    target.turnIn = FDJ.pendingMarkerTurnIn and true or nil
    FDJ.pendingMarkerTurnIn = nil
    -- autoclear: the quest this pin is for; the pin goes away by itself
    -- once that quest is picked up / handed in / its objective done.
    target.fdjAutoQuest = tonumber(FDJ.pendingMarkerQuestID)
    target.fdjAutoObjective = FDJ.pendingMarkerObjective and true or nil
    FDJ.pendingMarkerQuestID, FDJ.pendingMarkerObjective = nil, nil
    if target.fdjAutoQuest and FDJ.MapMarkers.SnapshotAutoClear then FDJ.MapMarkers.SnapshotAutoClear(target) end
    local existing = mapTargets[key]
    if existing and existing.raidMarkIndex then
        target.raidMarkIndex = existing.raidMarkIndex
    elseif IsTargetableNPCMarker(target) then
        target.raidMarkIndex = RaidMarkIndexForTarget(target)
    end
    mapTargets[key] = target
    -- arrow: the waypoint arrow points here too (see the end of this file).
    if FDJ.SetWaypointArrow then FDJ.SetWaypointArrow(target) end
    -- padmap (2.1.1, kaanu's controller report: Show on Map broke the game's
    -- controller mode every time). With the game's controller mode on, the
    -- game opens and closes its windows itself, with protected code; the
    -- world map opened by an addon puts the addon's code in that path and
    -- the game blocks the controller (as the Dungeon Tracker's Reset popup
    -- did). So with a controller the map is not opened: the spot is marked
    -- (its pin shows when the player opens the map) and the chat says so.
    -- M 20 Nov 2026: no arrow here ("the arrow is our routing guide").
    if FDJ.GamePadMode and FDJ.GamePadMode() then
        StartQuestStartMapTicker()
        UpdateMapMarkers()
        if DEFAULT_CHAT_FRAME then
            local padText = FreeText(target.label or fallbackText or "recorded location")
            padText = tostring(padText):gsub("%s*\226\128\148%s*", " - "):gsub("%s*\226\128\147%s*", " - ")
            if not padText:find(" - ", 1, true) and target.mapID and C_Map and C_Map.GetMapInfo then
                local ok, info = pcall(C_Map.GetMapInfo, target.mapID)
                if ok and info and info.name and info.name ~= "" then padText = padText .. " - " .. info.name end
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd36bDungeonJournal:|r " .. L("MAP_PAD_MARKED", padText))
        end
        return
    end

    local opened = false
    local inCombat = InCombatLockdown and InCombatLockdown()
    if inCombat then
        -- The map is only open now if Show on Map's secure click opened it (or
        -- the player did); otherwise jump to the spot when they open it.
        opened = ForceWorldMapMapID(target.mapID)
        if not opened and FDJ.RememberCombatMapSpot then FDJ.RememberCombatMapSpot(target.mapID) end
    else
        if C_Map and type(C_Map.OpenWorldMap) == "function" then
            local ok = pcall(C_Map.OpenWorldMap, target.mapID)
            opened = ok
        elseif type(OpenWorldMap) == "function" then
            local ok = pcall(OpenWorldMap, target.mapID)
            opened = ok
        end
        opened = ForceWorldMapMapID(target.mapID) or opened
    end
    StartQuestStartMapTicker()
    UpdateMapMarkers()

    if C_Timer and type(C_Timer.After) == "function" then
        for _, delay in ipairs({0.03, 0.10, 0.25, 0.50}) do
            C_Timer.After(delay, function()
                if not mapTargets[key] then return end
                ForceWorldMapMapID(target.mapID)
                UpdateMapMarkers()
            end)
        end
    end

    if DEFAULT_CHAT_FRAME then
        local mapText = FreeText(target.label or fallbackText or "recorded location")
        -- Short dash in chat ("Alba Fairmoon - Sentinel Hill inn"), like the game's own lines.
        mapText = tostring(mapText):gsub("%s*\226\128\148%s*", " - "):gsub("%s*\226\128\147%s*", " - ")
        -- Labels without a place ("Thrall") get the zone name: "Thrall - Orgrimmar".
        if not mapText:find(" - ", 1, true) and target.mapID and C_Map and C_Map.GetMapInfo then
            local ok, info = pcall(C_Map.GetMapInfo, target.mapID)
            if ok and info and info.name and info.name ~= "" then mapText = mapText .. " - " .. info.name end
        end
        if opened then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd36bDungeonJournal:|r " .. L("MAP_MARKED", mapText))
        elseif inCombat then
            local key = GetBindingKey and GetBindingKey("TOGGLEWORLDMAP")
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd36bDungeonJournal:|r " .. L("MAP_COMBAT", key or "M"))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd36bDungeonJournal:|r " .. L("MAP_OPEN_FAILED"))
        end
    end
end

local function ShowRouteOnMap(routeMap)
    if not routeMap or not routeMap.mapID or not routeMap.points or #routeMap.points < 2 then return end
    activeRouteMap = routeMap
    routeGeometryCache.key = nil
    HookRouteMapChanges()
    StartRouteHoverDriver()

    local opened = false
    if not (InCombatLockdown and InCombatLockdown()) then
        if C_Map and type(C_Map.OpenWorldMap) == "function" then
            opened = pcall(C_Map.OpenWorldMap, routeMap.mapID)
        elseif type(OpenWorldMap) == "function" then
            opened = pcall(OpenWorldMap, routeMap.mapID)
        end
    elseif FDJ.RememberCombatMapSpot and not (WorldMapFrame and WorldMapFrame:IsShown()) then
        FDJ.RememberCombatMapSpot(routeMap.mapID)
    end

    ForceWorldMapMapID(routeMap.mapID)
    StartQuestStartMapTicker()
    UpdateMapMarkers()

    if C_Timer and type(C_Timer.After) == "function" then
        for _, delay in ipairs({0.03, 0.10, 0.25, 0.50}) do
            C_Timer.After(delay, function()
                if activeRouteMap ~= routeMap then return end
                ForceWorldMapMapID(routeMap.mapID)
                UpdateMapMarkers()
            end)
        end
    end
end

-- Removes the travel-route overlay (right-click on the line or a route icon).
ClearRouteOnMap = function()
    activeRouteMap = nil
    SetRouteHovered(false)
    if routeHoverButton then routeHoverButton:Hide() end
    HideRouteOverlay()
    if GameTooltip then GameTooltip:Hide() end
end

local function ShowQuestStartOnMap(quest)
    if not quest then return end
    local loc = QUEST_START_MAPS[quest.id]
    if not loc then return end
    ShowRecordedLocationOnMap(loc, quest.pickup or quest.name)
end

FDJ.MapMarkers = FDJ.MapMarkers or {}
FDJ.MapMarkers.ShowRecordedLocationOnMap = ShowRecordedLocationOnMap
FDJ.MapMarkers.ShowRouteOnMap = ShowRouteOnMap
FDJ.MapMarkers.ClearRouteOnMap = ClearRouteOnMap
FDJ.MapMarkers.ShowQuestStartOnMap = ShowQuestStartOnMap
FDJ.MapMarkers.UpdateMapMarkers = UpdateMapMarkers
FDJ.MapMarkers.ConfigureTargetAndMarkAction = ConfigureTargetAndMarkAction
FDJ.MapMarkers.ApplyQuestGiverRaidMark = ApplyQuestGiverRaidMark
FDJ.MapMarkers.RaidMarkIndexForTarget = RaidMarkIndexForTarget
FDJ.MapMarkers.QuestGiverName = QuestGiverName

-- BEGIN autoclear
-- A pin put on the map for a quest clears itself: a quest giver's once the
-- quest is picked up, a turn-in pin once it is handed in, an objective pin
-- (Sputtervalve) once the objective is done. Only a change after the pin was
-- placed counts (marking the giver of a quest already in the log leaves the
-- pin until that quest is handed in). Built inside a function: this file is
-- at Lua's 200-local limit.
FDJ.MapMarkers.InitAutoClear = function()
    local justTurnedIn = {}
    local function State(id)
        return {
            log = (FDJ.IsQuestInLog and FDJ.IsQuestInLog(id)) and true or false,
            done = (justTurnedIn[id] or (FDJ.QuestTurnedIn and FDJ.QuestTurnedIn(id))) and true or false,
            finished = (FDJ.IsQuestFinished and FDJ.IsQuestFinished(id)) and true or false,
        }
    end
    FDJ.MapMarkers.SnapshotAutoClear = function(target)
        if target and target.fdjAutoQuest then target.fdjAutoWas = State(target.fdjAutoQuest) end
    end
    local function Sweep()
        local gone = {}
        for _, target in pairs(mapTargets) do
            local id, was = target.fdjAutoQuest, target.fdjAutoWas
            if id and was then
                local now = State(id)
                local handedIn = now.done and not was.done
                local clear
                if target.turnIn then
                    clear = handedIn
                elseif target.fdjAutoObjective then
                    clear = handedIn or (now.finished and not was.finished)
                else
                    clear = handedIn or (now.log and not was.log)
                end
                if clear then gone[#gone + 1] = target end
            end
        end
        for _, target in ipairs(gone) do RemoveTarget(target) end
        if #gone > 0 then UpdateMapMarkers() end
    end
    local watch = CreateFrame("Frame")
    watch:RegisterEvent("QUEST_ACCEPTED")
    watch:RegisterEvent("QUEST_TURNED_IN")
    watch:RegisterEvent("QUEST_LOG_UPDATE")
    -- turninclear (2.0.13, M 18 Nov 2026, Magus Wordeen Voidglare's ? for
    -- Prison Break In still on the map after handing it in: "once we turn
    -- in the quest, it should be gone instantly by itself ... for every
    -- single kind of quest"): a "Turn in here" pin put on the map without
    -- its quest's number (a click on the arrow) goes by the quest's name:
    -- the game's name of the quest handed in, and the journal's.
    local function NamesOf(id)
        local names = {}
        if C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
            local ok, title = pcall(C_QuestLog.GetTitleForQuestID, id)
            if ok and type(title) == "string" and title ~= "" then names[title] = true end
        end
        local function Add(name)
            if type(name) ~= "string" or name == "" then return end
            names[name] = true
            local shown = FDJ.LocalizeQuestField and FDJ.LocalizeQuestField(id, "name", name)
            if type(shown) == "string" and shown ~= "" then names[shown] = true end
        end
        for _, chain in pairs(FDJ.QUEST_PREREQ_CHAINS or {}) do
            if type(chain) == "table" then
                for _, step in ipairs(chain) do
                    if type(step) == "table" and step.id == id then Add(step.name) end
                end
            end
        end
        for _, dungeon in pairs(FDJ.DB or {}) do
            if type(dungeon) == "table" and type(dungeon.quests) == "table" then
                for _, quest in ipairs(dungeon.quests) do
                    if type(quest) == "table" and quest.id == id then Add(quest.name) end
                end
            end
        end
        return names
    end
    local function SweepByName(id)
        local names, gone = nil, {}
        for _, target in pairs(mapTargets) do
            if target.turnIn and not target.fdjAutoQuest and type(target.questTitle) == "string" then
                names = names or NamesOf(id)
                if names[target.questTitle] then gone[#gone + 1] = target end
            end
        end
        for _, target in ipairs(gone) do RemoveTarget(target) end
        if #gone > 0 then UpdateMapMarkers() end
    end
    watch:SetScript("OnEvent", function(_, event, a)
        if event == "QUEST_TURNED_IN" and tonumber(a) then justTurnedIn[tonumber(a)] = true end
        if next(mapTargets) == nil then return end
        if event == "QUEST_TURNED_IN" and tonumber(a) then pcall(SweepByName, tonumber(a)) end
        if next(mapTargets) == nil then return end
        local ok = pcall(Sweep)
        if not ok then return end
    end)
end
FDJ.MapMarkers.InitAutoClear()
-- END autoclear
FDJ.MapMarkers.QUEST_GIVER_MARK_PRIORITY = QUEST_GIVER_MARK_PRIORITY
FDJ.MapMarkers.QUEST_GIVER_MARK_NAMES = QUEST_GIVER_MARK_NAMES

-- BEGIN combatmap
-- ------------------------------------------------ Show on Map in combat
-- The game blocks addon code from opening the world map in combat, but a
-- secure click on its own map button (what the M key does) is allowed. A
-- protected button can't sit inside the journal (the journal would then be
-- stuck open or closed during combat), so when combat starts with a quest page
-- open, an invisible secure button is laid over Show on Map and Show Turn In
-- for the fight. It presses the game's map button, then the spot is marked as
-- usual. Secure buttons can't move during combat: if the journal closes,
-- scrolls or changes page in the fight, a plain frame covers the old spot so
-- no stray click toggles the map, and the real button falls back to "press M"
-- (the map then jumps to the spot when it opens). All of it ends with combat.
local GAME_MAP_BUTTONS = { "WorldMapMicroButton", "MiniMapWorldMapButton" }
local combatClicks = {}

local function GameMapButtonName()
    for _, name in ipairs(GAME_MAP_BUTTONS) do
        local b = _G[name]
        if type(b) == "table" and b.Click then return name end
    end
end

-- Show on Map pressed in combat with the map closed: when the player opens
-- the map (within two minutes), show the zone of that spot.
local pendingSpot
local mapShowHooked = false
function FDJ.RememberCombatMapSpot(mapID)
    if not mapID then return end
    pendingSpot = { mapID = mapID, at = GetTime and GetTime() or 0 }
    if mapShowHooked or not (WorldMapFrame and WorldMapFrame.HookScript) then return end
    mapShowHooked = true
    WorldMapFrame:HookScript("OnShow", function()
        local spot = pendingSpot
        pendingSpot = nil
        if not spot or (GetTime and GetTime() - spot.at > 120) then return end
        local function Apply()
            if WorldMapFrame:IsShown() and WorldMapFrame.SetMapID then
                pcall(WorldMapFrame.SetMapID, WorldMapFrame, spot.mapID)
            end
        end
        Apply()
        if C_Timer and C_Timer.After then
            for _, delay in ipairs({ 0.03, 0.10, 0.25 }) do C_Timer.After(delay, Apply) end
        end
    end)
end

-- Screen rectangle of a journal button, in UIParent units.
local function CoverRect(real)
    local l, b, w, h = real:GetLeft(), real:GetBottom(), real:GetWidth(), real:GetHeight()
    if not (l and b and w and h) then return nil end
    local s = real:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return l * s, b * s, w * s, h * s
end

local function MakeCombatClick(i)
    if InCombatLockdown and InCombatLockdown() then return nil end
    local ok, o = pcall(CreateFrame, "Button", "ForeverDungeonJournalMapClick" .. i, UIParent, "SecureActionButtonTemplate")
    if not ok or not o then return nil end
    o:Hide()
    o:RegisterForClicks("LeftButtonUp")
    o:SetAttribute("useOnKeyDown", false)
    -- Looks and tooltip of the journal button underneath.
    o:SetScript("OnEnter", function(self)
        local real = self.fdjReal
        if not (real and real:IsVisible()) then return end
        local enter = real:GetScript("OnEnter")
        if enter then pcall(enter, real) end
        if real.LockHighlight then real:LockHighlight() end
    end)
    o:SetScript("OnLeave", function(self)
        local real = self.fdjReal
        if real and real.UnlockHighlight then real:UnlockHighlight() end
        GameTooltip:Hide()
    end)
    -- After the secure click has opened the map: mark the spot as usual.
    o:SetScript("PostClick", function(self)
        local real = self.fdjReal
        if not (real and real:IsVisible()) then return end
        local open = real:GetScript("PostClick") or real:GetScript("OnClick")
        if open then pcall(open, real, "LeftButton", false) end
    end)
    local blocker = CreateFrame("Frame", nil, UIParent)
    blocker:EnableMouse(true)
    blocker:Hide()
    o.fdjBlocker = blocker
    return o
end

-- While armed: cover a secure button whose journal button is gone or moved.
local combatWatch = CreateFrame("Frame")
combatWatch:Hide()
combatWatch.t = 0
combatWatch:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t + elapsed
    if self.t < 0.1 then return end
    self.t = 0
    for _, o in pairs(combatClicks) do
        if o:IsShown() then
            local real, r = o.fdjReal, o.fdjRect
            local stray = true
            if real and r and real:IsVisible() then
                local l, b, w, h = CoverRect(real)
                stray = not l or math.abs(l - r[1]) > 1 or math.abs(b - r[2]) > 1
                    or math.abs(w - r[3]) > 1 or math.abs(h - r[4]) > 1
            end
            if o.fdjBlocker:IsShown() ~= stray then o.fdjBlocker:SetShown(stray) end
        end
    end
end)

-- PLAYER_REGEN_DISABLED comes just before the combat lock: last chance to
-- place secure buttons for this fight.
local function ArmCombatClicks()
    if InCombatLockdown and InCombatLockdown() then return end
    local journal = _G.ForeverDungeonJournalFrame
    local mapButton = GameMapButtonName()
    if not (journal and journal:IsVisible() and mapButton) then return end
    local armed = false
    for i, real in ipairs({ journal.questMapButton, journal.questTurninMapButton }) do
        if real and real:IsVisible() then
            combatClicks[i] = combatClicks[i] or MakeCombatClick(i)
            local o = combatClicks[i]
            local l, b, w, h = CoverRect(real)
            if o and l then
                o.fdjReal = real
                o.fdjRect = { l, b, w, h }
                o:SetAttribute("type", "macro")
                o:SetAttribute("macrotext", "/click " .. mapButton)
                o:SetFrameStrata(journal:GetFrameStrata())
                o:SetFrameLevel(math.min(9000, journal:GetFrameLevel() + 300))
                o:ClearAllPoints()
                o:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
                o:SetSize(w, h)
                o:Show()
                local blocker = o.fdjBlocker
                blocker:SetFrameStrata(o:GetFrameStrata())
                blocker:SetFrameLevel(o:GetFrameLevel() + 1)
                blocker:ClearAllPoints()
                blocker:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
                blocker:SetSize(w, h)
                blocker:Hide()
                armed = true
            end
        end
    end
    if armed then combatWatch:Show() end
end

local function DisarmCombatClicks()
    combatWatch:Hide()
    for _, o in pairs(combatClicks) do
        o:Hide()
        o.fdjBlocker:Hide()
        if o.fdjReal and o.fdjReal.UnlockHighlight then o.fdjReal:UnlockHighlight() end
        o.fdjReal = nil
    end
end

local combatEvents = CreateFrame("Frame")
combatEvents:RegisterEvent("PLAYER_LOGIN")
combatEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
combatEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
combatEvents:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        pcall(ArmCombatClicks)
    elseif event == "PLAYER_REGEN_ENABLED" then
        pcall(DisarmCombatClicks)
    elseif event == "PLAYER_LOGIN" then
        for i = 1, 2 do combatClicks[i] = combatClicks[i] or MakeCombatClick(i) end
        -- Dev: /dj devmap says what the combat path found (off for release).
        local base = SlashCmdList and SlashCmdList.FOREVERDUNGEONJOURNAL
        if false and base then
            SlashCmdList.FOREVERDUNGEONJOURNAL = function(msg, ...)
                local cmd = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
                if cmd == "devmap" then
                    local made, armed = 0, 0
                    for _, o in pairs(combatClicks) do
                        made = made + 1
                        if o:IsShown() then armed = armed + 1 end
                    end
                    local protected = WorldMapFrame and WorldMapFrame.IsProtected and WorldMapFrame:IsProtected()
                    print("|cffd8a83cDungeon Journal:|r map in combat (dev): game map button "
                        .. tostring(GameMapButtonName() or "NOT FOUND") .. ", secure buttons " .. made
                        .. ", armed now " .. armed .. ", world map protected " .. tostring(protected))
                    return
                end
                return base(msg, ...)
            end
        end
    end
end)
-- END combatmap

-- BEGIN devmapdump
-- Test builds 1.6.9 and 1.6.10 saved every map floor for research. That is
-- done: drop the saved copy.
local dumpCleanup = CreateFrame("Frame")
dumpCleanup:RegisterEvent("PLAYER_LOGIN")
dumpCleanup:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if type(ForeverDungeonJournalDB) == "table" then ForeverDungeonJournalDB.devMapDump = nil end
end)
-- END devmapdump


-- BEGIN mapquests
-- Quest spots on the dungeon maps (FDJ.MAP_QUEST_PINS, Data/QuestMaps.lua):
-- a yellow ! where a quest starts, a yellow ? where one is handed in or
-- done on the spot (an object to loot or use, a place to explore). Only
-- the quests the quest list shows (its faction, class quests as set, RPG
-- Mode's unlocked ones). Hover: what to do there; click: the quest's page.
-- pinlog: a spot with something to do for a quest in the player's log (hand
-- it in, loot, use, explore) shows ?, like the game's own NPCs, even when
-- another quest also starts there (Daewyn Songblade: Songblade Search is
-- handed in, Fallen in the Fen starts); a quest already taken or done does
-- not make a !. The pins follow the quest log while the map is open.
do
    local pool = {}

    -- A thin black edge around a ! / ? icon, so it stands out on the light
    -- map parchment: eight black copies of the icon just behind it.
    local STROKE = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
    function FDJ.StrokeIcon(owner, icon, size)
        if not owner or not icon then return end
        local tex = icon.GetTexture and icon:GetTexture()
        if not tex then return end
        local w = math.max(1, math.floor((size or 24) * 0.06 + 0.5))
        owner.fdjStroke = owner.fdjStroke or {}
        for i, o in ipairs(STROKE) do
            local s = owner.fdjStroke[i]
            if not s then
                s = owner:CreateTexture(nil, "ARTWORK")
                owner.fdjStroke[i] = s
            end
            s:SetTexture(tex)
            s:SetVertexColor(0, 0, 0, 1)
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", icon, "TOPLEFT", o[1] * w, o[2] * w)
            s:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", o[1] * w, o[2] * w)
            s:Show()
        end
    end

    local function L(key, ...)
        if FDJ.L then return FDJ.L(key, ...) end
        return key
    end

    local function Plain(v)
        if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
        return v
    end

    -- The quest's entry in the journal (a chain step: its chain's entry).
    local function Entry(q)
        local d = FDJ.DB and FDJ.DB[q.dungeon]
        local want = q.main or q.id
        for _, quest in ipairs((d and d.quests) or {}) do
            if type(quest) == "table" and quest.id == want then return quest end
        end
    end

    local function Shown(q, faction)
        local entry = Entry(q)
        if not entry then return false end
        if faction and FDJ.QuestMatchesFaction and not FDJ.QuestMatchesFaction(entry, faction) then return false end
        if FDJ.RPGQuestHidden and FDJ.RPGQuestHidden(q.dungeon, entry) then return false end
        return true
    end

    local function ItemName(id, fallback)
        local name
        if id and GetItemInfo then
            local ok, n = pcall(GetItemInfo, id)
            if ok then name = Plain(n) end
        end
        if not name and id and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
        if type(name) == "string" and name ~= "" then return name end
        return fallback or ""
    end

    local function Title(q)
        if FDJ.LocalizeQuestField then
            local ok, name = pcall(FDJ.LocalizeQuestField, q.id, "name", q.name)
            if ok and type(name) == "string" and name ~= "" then return name end
        end
        return q.name or ""
    end

    -- What to do there, one line per thing.
    local function Lines(q)
        if q.textKey then return { L(q.textKey) } end
        local out = {}
        for _, act in ipairs(q.acts or {}) do
            if act == "start" then
                out[#out + 1] = L("QUEST_STARTS_HERE")
            elseif act == "end" then
                out[#out + 1] = L("TURN_IN_HERE")
            elseif act == "loot" then
                out[#out + 1] = L("MAP_OBJ_LOOT", ItemName(q.item, q.itemName))
            elseif act == "use" then
                out[#out + 1] = L("MAP_OBJ_USE")
            elseif act == "explore" then
                out[#out + 1] = L("MAP_OBJ_EXPLORE")
            end
        end
        return out
    end

    local function OnEnter(self)
        local spots = self.fdjSpots
        if not spots then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local first = true
        local function Add(text, r, g, b, wrap)
            if first then
                GameTooltip:SetText(text, r, g, b, 1, wrap)
                first = false
            else
                GameTooltip:AddLine(text, r, g, b, wrap)
            end
        end
        for i, spot in ipairs(spots) do
            if i > 1 then GameTooltip:AddLine(" ") end
            if spot.name and spot.name ~= "" then
                Add(FDJ.LocalizeFreeText and FDJ.LocalizeFreeText(spot.name) or spot.name, 1, 1, 1)
            end
            for _, q in ipairs(spot.shown) do
                Add(Title(q), 1, 0.82, 0)
                for _, line in ipairs(Lines(q)) do Add(line, 0.92, 0.92, 0.92, true) end
            end
        end
        GameTooltip:Show()
    end

    local function OnClick(self)
        local q = self.fdjFirst
        if not q then return end
        local main = q.main or q.id
        local step = q.main and q.id or nil
        GameTooltip:Hide()
        -- On the world map (the dungeon map shown over M): the journal opens.
        if FDJ.IsWorldMapOverlayAttached and FDJ.IsWorldMapOverlayAttached() and FDJ.OpenQuestFromWorldMap then
            FDJ.OpenQuestFromWorldMap(q.dungeon, main, step)
            return
        end
        if step and FDJ.OpenQuestChainStep then
            FDJ.OpenQuestChainStep(q.dungeon, main, step)
        elseif FDJ.OpenQuestPage then
            FDJ.OpenQuestPage(q.dungeon, main)
        end
    end

    local last -- the last call's arguments, to redraw the pins alone
    -- Called by the dungeon map (Core/Journal.lua) for the level it shows.
    function FDJ.RenderMapQuestPins(dungeonName, floorIndex, holder, artW, artH, baseH, faction)
        last = { dungeonName, floorIndex, holder, artW, artH, baseH, faction }
        local list = (FDJ.MAP_QUEST_PINS and FDJ.MAP_QUEST_PINS[dungeonName]) or {}
        -- The quest tracker's ? / ! for a quest already marks it here: no
        -- second one for that quest.
        local mapData = FDJ.DUNGEON_MAPS and FDJ.DUNGEON_MAPS[dungeonName]
        local tracked = mapData and FDJ.dungeonTurnIns and FDJ.dungeonTurnIns[mapData]
        local skip = tracked and (tracked.floor or 1) == floorIndex and tracked.questID or nil
        local n = 0
        local inLog = FDJ.IsQuestInLog or function() return false end
        local turnedIn = FDJ.QuestTurnedIn or function() return false end
        -- hidequests (2.0.15): Hide quests ticked: only the spot a quest's
        -- Show on Map just opened the map on (its quest, else where it is).
        local hideAll = FDJ.MapQuestsHidden and FDJ.MapQuestsHidden(dungeonName)
        local focus = FDJ.dungeonMapFocus
        if focus and ((GetTime and GetTime()) or 0) > (focus.untilT or 0) then focus = nil end
        local function Wanted(pin)
            if not hideAll then return true end
            if not focus then return false end
            if focus.x and focus.y and (focus.floor or 1) == (pin.floor or 1)
                and math.abs(focus.x - pin.x) < 0.015 and math.abs(focus.y - pin.y) < 0.015 then return true end
            for _, spot in ipairs(pin.spots or {}) do
                for _, q in ipairs(spot.quests or {}) do
                    if focus.questID and (q.id == focus.questID or q.main == focus.questID) then return true end
                end
            end
            return false
        end
        for _, pin in ipairs(list) do
            if (pin.floor or 1) == floorIndex and Wanted(pin) then
                local spots, start, firstQuest = {}, false, nil
                local logged, available, firstLogged = false, false, nil -- pinlog
                local allRepeat = true -- repeaticon (2.0.44)
                for _, spot in ipairs(pin.spots or {}) do
                    local shown = {}
                    for _, q in ipairs(spot.quests or {}) do
                        if q.id ~= skip and Shown(q, faction) then
                            shown[#shown + 1] = q
                            if not (FDJ.IsRepeatableQuest and FDJ.IsRepeatableQuest(q.id)) then allRepeat = false end
                            firstQuest = firstQuest or q
                            local have = inLog(q.id) and true or false
                            for _, act in ipairs(q.acts or {}) do
                                if act == "start" then
                                    start = true
                                    if not have and not turnedIn(q.id) then available = true end
                                elseif have then
                                    logged = true
                                    firstLogged = firstLogged or q
                                end
                            end
                        end
                    end
                    if #shown > 0 then spots[#spots + 1] = { name = spot.name, shown = shown } end
                end
                -- pinlog: ? for a quest in the log, else ! for one to take;
                -- nothing to do there now (quests not taken yet, or taken or
                -- done already): its usual icon, greyed.
                local bang = (not logged) and (available or start)
                local idle = not logged and not available
                firstQuest = firstLogged or firstQuest
                if #spots > 0 then
                    n = n + 1
                    local b = pool[n]
                    if not b then
                        b = CreateFrame("Button", nil, holder)
                        b.icon = b:CreateTexture(nil, "OVERLAY")
                        b.icon:SetAllPoints()
                        b:SetScript("OnEnter", OnEnter)
                        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
                        b:SetScript("OnClick", OnClick)
                        pool[n] = b
                    end
                    if b:GetParent() ~= holder then b:SetParent(holder) end
                    b.fdjSpots, b.fdjFirst, b.fdjStart = spots, firstQuest, bang
                    b.fdjFloor, b.fdjX, b.fdjY = pin.floor or 1, pin.x, pin.y -- mapfocus
                    -- repeaticon (2.0.44): only repeatable quests there: the blue ?
                    if FDJ.SetQuestIconTexture then
                        FDJ.SetQuestIconTexture(b.icon, allRepeat, bang and "Interface\\GossipFrame\\AvailableQuestIcon" or "Interface\\GossipFrame\\ActiveQuestIcon")
                    else
                        b.icon:SetTexture(bang and "Interface\\GossipFrame\\AvailableQuestIcon" or "Interface\\GossipFrame\\ActiveQuestIcon")
                    end
                    if b.icon.SetDesaturated then b.icon:SetDesaturated(idle) end
                    b.icon:SetAlpha(idle and 0.75 or 1)
                    local size = math.max(22, math.floor((baseH or 0) * 0.07))
                    b:SetSize(size, size)
                    FDJ.StrokeIcon(b, b.icon, size)
                    b:SetFrameLevel(holder:GetFrameLevel() + 15)
                    b:ClearAllPoints()
                    -- pinclear (2.1.3, M 21 Nov 2026 on Uldaman's map: "make sure
                    -- they don't overlap too much, but it's in the same room"):
                    -- a quest's spot beside a boss's pin in the same room, and
                    -- at any zoom moved just clear of the boss's ring
                    local qx, qy = pin.x * artW, pin.y * artH
                    local journal = _G.ForeverDungeonJournalFrame
                    for _, m in ipairs((journal and journal.dungeonMapBossMarkers) or {}) do
                        if m:IsShown() and m:GetParent() == holder then
                            local okP, _, _, _, mx, my = pcall(m.GetPoint, m, 1)
                            if okP and type(mx) == "number" and type(my) == "number" then
                                my = -my
                                local ring = ((m.border and m.border:GetWidth()) or (m:GetWidth() * 1.55)) * 0.42
                                local need = ring + size * 0.36 + 2
                                local dx, dy = qx - mx, qy - my
                                local d = math.sqrt(dx * dx + dy * dy)
                                if d < need then
                                    if d < 0.5 then dx, dy, d = -1, 0, 1 end
                                    qx, qy = mx + dx / d * need, my + dy / d * need
                                end
                            end
                        end
                    end
                    b:SetPoint("CENTER", holder, "TOPLEFT", qx, -qy)
                    b:Show()
                end
            end
        end
        for i = n + 1, #pool do pool[i]:Hide() end
        return n
    end

    -- autohidequests (2.0.52, inside only 2.0.53): true when every quest
    -- with a mark on this dungeon's map (the character's own: faction,
    -- class, profession) is done as far as the inside goes: handed in, or
    -- in the log with its objectives complete and no hand-in inside. A
    -- quest still to start, do or hand in inside keeps the marks. False
    -- when the map has no quest of the character's at all.
    function FDJ.MapQuestsAllDoneInside(dungeonName)
        local list = dungeonName and FDJ.MAP_QUEST_PINS and FDJ.MAP_QUEST_PINS[dungeonName]
        if type(list) ~= "table" then return false end
        local faction = UnitFactionGroup and select(1, UnitFactionGroup("player")) or nil
        local inLog = FDJ.IsQuestInLog or function() return false end
        local turnedIn = FDJ.QuestTurnedIn or function() return false end
        local function Complete(id)
            if C_QuestLog and C_QuestLog.IsComplete then
                local ok, done = pcall(C_QuestLog.IsComplete, id)
                if ok and done ~= nil then return done == true end
            end
            if IsQuestComplete then
                local ok, done = pcall(IsQuestComplete, id)
                if ok then return done == true or done == 1 end
            end
            return false
        end
        local seen = 0
        for _, pin in ipairs(list) do
            for _, spot in ipairs(pin.spots or {}) do
                for _, q in ipairs(spot.quests or {}) do
                    if q.id and Shown(q, faction) then
                        seen = seen + 1
                        if not turnedIn(q.id) then
                            if not inLog(q.id) then return false end -- still to take (or to do)
                            for _, act in ipairs(q.acts or {}) do
                                if act == "end" then return false end -- handed in inside
                            end
                            if not Complete(q.id) then return false end
                        end
                    end
                end
            end
        end
        return seen > 0
    end

    -- The quest tracker's ? taken off the map (right-click): its quest's
    -- own spot comes back.
    function FDJ.RefreshMapQuestPins()
        if last then return FDJ.RenderMapQuestPins(unpack(last, 1, 7)) end
    end

    -- pinlog: a quest taken, handed in or dropped while the map is open
    -- turns its spot's ! into ? (and back) right away.
    local watcher = CreateFrame("Frame")
    for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED" }) do
        pcall(watcher.RegisterEvent, watcher, event)
    end
    local pending = false
    watcher:SetScript("OnEvent", function()
        if pending or not last or not (last[3] and last[3].IsVisible and last[3]:IsVisible()) then return end
        pending = true
        local function Redraw()
            pending = false
            if last and last[3] and last[3]:IsVisible() then pcall(FDJ.RefreshMapQuestPins) end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.5, Redraw) else Redraw() end
    end)

    -- The pins (shown ones first), for the tests.
    function FDJ.MapQuestPinButtons() return pool end

    -- A quest item found on one of these spots (the BFD manuscript's chest):
    -- the dungeon map and level where it is, for the item's click.
    function FDJ.MapQuestItemSpot(questID, itemID)
        if not questID or not itemID then return nil end
        for name, list in pairs(FDJ.MAP_QUEST_PINS or {}) do
            for _, pin in ipairs(list) do
                for _, spot in ipairs(pin.spots or {}) do
                    for _, q in ipairs(spot.quests or {}) do
                        if q.item == itemID and (q.id == questID or q.main == questID) then
                            return { dungeon = name, floor = pin.floor or 1, x = pin.x, y = pin.y, label = spot.name, questID = questID }
                        end
                    end
                end
            end
        end
    end
end
-- END mapquests

-- BEGIN arrow
-- The waypoint arrow. A spot shown with Show on Map, Show Turn In, a
-- dungeon's Show Location or a ! / ? in the quest tracker also gets an arrow
-- on the screen that points the way, with the distance, under the quest's
-- name. A tracked quest chain page (the Cozy Sleeping Bag) moves it on by
-- itself: to where the next step is picked up, then to where it is handed in.
-- On another continent it points to the boat or zeppelin that gets there
-- first ("Take the boat to Darkshore"), then on from where it lands. When a
-- flight point the character has found saves enough of the way, it points to
-- the flight master first ("Fly to The Sepulcher"), and in the air counts
-- down the flight (as long as it took last time; the first time, from the
-- length of the flight's path). Near an NPC who stands well
-- below or above the ground around (a crypt, a tower top), it says so ("Below
-- ground: find the way down") and does not take standing over them as there.
-- Close to a quest NPC, a click on it targets and marks the NPC; elsewhere a
-- click shows the spot on the map. Drag it (by the arrow itself) anywhere;
-- right-click hides it; it goes away on arrival (a chain's spot only
-- steps aside until the step moves on) and is not shown inside instances.
do
    local ART = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\WaypointArrow"
    local FALLBACK_ART = "Interface\\Minimap\\MinimapArrow" -- until the game has seen the new file
    do -- upstairs (2.0.13)
        local strings = { enUS = "Go upstairs", deDE = "Geh nach oben", frFR = "Montez à l'étage", esES = "Sube al piso de arriba", itIT = "Sali al piano di sopra",
            ptBR = "Suba ao andar de cima", ruRU = "Поднимитесь наверх", koKR = "위층으로 올라가세요", zhCN = "上楼", zhTW = "上樓" }
        strings.esMX = strings.esES
        for locale, text in pairs(strings) do
            local t = FDJ.Locales and FDJ.Locales[locale]
            if t and t.ARROW_UPSTAIRS == nil then t.ARROW_UPSTAIRS = text end
        end
    end
    do -- arrowkill (2.0.13)
        local strings = { enUS = "Kill %s", deDE = "Töte %s", frFR = "Tuez %s", esES = "Mata a %s", itIT = "Uccidi %s", ptBR = "Mate %s",
            ruRU = "Убейте: %s", koKR = "%s 처치", zhCN = "击杀%s", zhTW = "擊殺%s" }
        strings.esMX = strings.esES
        for locale, text in pairs(strings) do
            local t = FDJ.Locales and FDJ.Locales[locale]
            if t and t.ARROW_KILL == nil then t.ARROW_KILL = text end
        end
    end
    local ARRIVED = 8      -- yards: there
    local STEP = 0.05      -- seconds between redraws
    local PLAN_EVERY = 0.5 -- seconds between working out the way again
    local DOCK = 25        -- yards: at the boat's or zeppelin's dock
    local OFF_DOCK = 1000  -- yards: that far from the dock again, not on the boat after all
    local NEAR_NPC = 120   -- yards: a click targets and marks the NPC
    local AT_MASTER = 12   -- yards: at the flight master
    local FLY_SPEED = 2.5  -- a flight covers the ground this many times faster
    local FLY_EXTRA = 100  -- yards' worth of time a flight costs on top (the flight master, landing)
    local FLY_MIN = 500    -- yards: shorter ways are not worth a flight
    local FLY_WORTH = 0.85 -- fly when that takes less than this share of the way there
    local FLIGHT_SPEED = 30  -- yards a second along a flight's path (Classic gryphons and wind riders)
    local FLIGHT_STOP = 2    -- seconds each hop costs on top (taking off, landing)
    local FLIGHT_CURVE = 1.4 -- a path not known: this many times the straight line (known paths: half are under 1.38)
    local FAR_ZONE = 500   -- yards: a flight point in another zone than where one stands (or is going) counts this much farther (zone borders are mostly mountains: Brackenwall is not 750 yards from the Field of Giants)
    local FLOOR_NEAR = 100 -- yards: near enough for "below / above ground" to matter

    do
        local strings = {
            enUS = { ARROW_NEXT_SPAWN = "Not found? Next spot (%d/%d)", ARROW_USE_ITEM = "Use %s in your bags to start the quest", ARROW_DISTANCE = "%d yds", ARROW_TIP_MOVE = "Drag to move.", ARROW_TIP_HIDE = "Shift + right-click to hide the arrow.",
                ARROW_BOAT = "Take the boat to %s", ARROW_ZEPPELIN = "Take the zeppelin to %s", ARROW_FLY = "Fly to %s", ARROW_FLY_FROM = "Fly from %s to %s" },
            deDE = { ARROW_NEXT_SPAWN = "Nicht gefunden? Nächster Ort (%d/%d)", ARROW_USE_ITEM = "Benutze %s in deinen Taschen, um die Quest anzunehmen", ARROW_DISTANCE = "%d m", ARROW_TIP_MOVE = "Ziehen zum Verschieben.", ARROW_TIP_HIDE = "Umschalt + Rechtsklick blendet den Pfeil aus.",
                ARROW_BOAT = "Nimm das Schiff nach %s", ARROW_ZEPPELIN = "Nimm den Zeppelin nach %s", ARROW_FLY = "Flieg nach %s", ARROW_FLY_FROM = "Flieg von %s nach %s" },
            frFR = { ARROW_NEXT_SPAWN = "Introuvable ? Endroit suivant (%d/%d)", ARROW_USE_ITEM = "Utilisez %s dans vos sacs pour commencer la quête", ARROW_DISTANCE = "%d m", ARROW_TIP_MOVE = "Faites glisser pour déplacer.", ARROW_TIP_HIDE = "Maj + clic droit pour masquer la flèche.",
                ARROW_BOAT = "Prenez le bateau pour %s", ARROW_ZEPPELIN = "Prenez le zeppelin pour %s", ARROW_FLY = "Volez vers %s", ARROW_FLY_FROM = "Volez de %s vers %s" },
            esES = { ARROW_NEXT_SPAWN = "¿No está? Siguiente lugar (%d/%d)", ARROW_USE_ITEM = "Usa %s de tus bolsas para empezar la misión", ARROW_DISTANCE = "%d m", ARROW_TIP_MOVE = "Arrastra para mover.", ARROW_TIP_HIDE = "Mayús + clic derecho para ocultar la flecha.",
                ARROW_BOAT = "Toma el barco a %s", ARROW_ZEPPELIN = "Toma el zepelín a %s", ARROW_FLY = "Vuela a %s", ARROW_FLY_FROM = "Vuela de %s a %s" },
            itIT = { ARROW_NEXT_SPAWN = "Non trovato? Prossimo punto (%d/%d)", ARROW_USE_ITEM = "Usa %s nelle borse per iniziare la missione", ARROW_DISTANCE = "%d m", ARROW_TIP_MOVE = "Trascina per spostare.", ARROW_TIP_HIDE = "Maiusc + clic destro per nascondere la freccia.",
                ARROW_BOAT = "Prendi la nave per %s", ARROW_ZEPPELIN = "Prendi lo zeppelin per %s", ARROW_FLY = "Vola a %s", ARROW_FLY_FROM = "Vola da %s a %s" },
            ptBR = { ARROW_NEXT_SPAWN = "Não achou? Próximo local (%d/%d)", ARROW_USE_ITEM = "Use %s nas bolsas para começar a missão", ARROW_DISTANCE = "%d m", ARROW_TIP_MOVE = "Arraste para mover.", ARROW_TIP_HIDE = "Shift + clique com o botão direito para ocultar a seta.",
                ARROW_BOAT = "Pegue o barco para %s", ARROW_ZEPPELIN = "Pegue o zepelim para %s", ARROW_FLY = "Voe para %s", ARROW_FLY_FROM = "Voe de %s para %s" },
            ruRU = { ARROW_NEXT_SPAWN = "Не нашли? Следующее место (%d/%d)", ARROW_USE_ITEM = "Используйте %s из сумки, чтобы взять задание", ARROW_DISTANCE = "%d м", ARROW_TIP_MOVE = "Перетащите, чтобы переместить.", ARROW_TIP_HIDE = "Shift + щелчок правой кнопкой, чтобы скрыть стрелку.",
                ARROW_BOAT = "Корабль: %s", ARROW_ZEPPELIN = "Дирижабль: %s", ARROW_FLY = "Полёт: %s", ARROW_FLY_FROM = "Полёт: %s → %s" },
            koKR = { ARROW_NEXT_SPAWN = "없나요? 다음 장소 (%d/%d)", ARROW_USE_ITEM = "가방의 %s|1을;를; 사용해 퀘스트를 시작하세요", ARROW_DISTANCE = "%d미터", ARROW_TIP_MOVE = "드래그하여 이동합니다.", ARROW_TIP_HIDE = "Shift + 오른쪽 클릭으로 화살표를 숨깁니다.",
                ARROW_BOAT = "%s행 배를 타세요", ARROW_ZEPPELIN = "%s행 비행선을 타세요", ARROW_FLY = "%s(으)로 비행하세요", ARROW_FLY_FROM = "%s에서 %s(으)로 비행하세요" },
            zhCN = { ARROW_NEXT_SPAWN = "没找到？下一个地点 (%d/%d)", ARROW_USE_ITEM = "使用背包中的%s以开始任务", ARROW_DISTANCE = "%d码", ARROW_TIP_MOVE = "拖动以移动。", ARROW_TIP_HIDE = "Shift+右键点击隐藏箭头。",
                ARROW_BOAT = "乘船前往%s", ARROW_ZEPPELIN = "乘坐飞艇前往%s", ARROW_FLY = "飞往%s", ARROW_FLY_FROM = "从%s飞往%s" },
            zhTW = { ARROW_NEXT_SPAWN = "沒找到？下一個地點 (%d/%d)", ARROW_USE_ITEM = "使用背包中的%s以開始任務", ARROW_DISTANCE = "%d碼", ARROW_TIP_MOVE = "拖曳以移動。", ARROW_TIP_HIDE = "Shift+右鍵點擊隱藏箭頭。",
                ARROW_BOAT = "搭船前往%s", ARROW_ZEPPELIN = "搭乘飛艇前往%s", ARROW_FLY = "飛往%s", ARROW_FLY_FROM = "從%s飛往%s" },
        }
        local more = {
            enUS = { ARROW_TALK_TO = "Talk to %s", ARROW_DIVE_DOWN = "Dive straight down", ARROW_PICK_UP_BOTTOM = "Pick it up at the bottom", ARROW_SWIM_UNDER = "Swim underwater", ARROW_PICK_UP = "Pick it up", ARROW_GET_TO = "Get to %s", ARROW_FLYING = "Flying to %s", ARROW_BELOW = "Below ground: find the way down", ARROW_ABOVE = "Upstairs: find the way up", ARROW_TIP_MAP = "Click to show it on the map.",
                ARROW_PORTAL = "Take the portal to %s", ARROW_HEARTH = "Hearth to %s", ARROW_ELEVATOR = "Take the elevator up" },
            deDE = { ARROW_TALK_TO = "Sprich mit %s", ARROW_DIVE_DOWN = "Tauche gerade nach unten", ARROW_PICK_UP_BOTTOM = "Heb es am Grund auf", ARROW_SWIM_UNDER = "Tauche unter Wasser", ARROW_PICK_UP = "Heb es auf", ARROW_GET_TO = "Begib dich nach %s", ARROW_FLYING = "Flug nach %s", ARROW_BELOW = "Unter der Erde: such den Weg nach unten", ARROW_ABOVE = "Weiter oben: such den Weg nach oben", ARROW_TIP_MAP = "Klicken zeigt es auf der Karte.",
                ARROW_PORTAL = "Nimm das Portal nach %s", ARROW_HEARTH = "Ruhestein nach %s", ARROW_ELEVATOR = "Nimm den Aufzug nach oben" },
            frFR = { ARROW_TALK_TO = "Parlez à %s", ARROW_DIVE_DOWN = "Plongez tout droit", ARROW_PICK_UP_BOTTOM = "Ramassez-le au fond", ARROW_SWIM_UNDER = "Nagez sous l'eau", ARROW_PICK_UP = "Ramassez-le", ARROW_GET_TO = "Rendez-vous à %s", ARROW_FLYING = "Vol vers %s", ARROW_BELOW = "Sous terre : trouvez le chemin pour descendre", ARROW_ABOVE = "En hauteur : trouvez le chemin pour monter", ARROW_TIP_MAP = "Cliquez pour l'afficher sur la carte.",
                ARROW_PORTAL = "Prenez le portail vers %s", ARROW_HEARTH = "Pierre de foyer vers %s", ARROW_ELEVATOR = "Prenez l'ascenseur pour monter" },
            esES = { ARROW_TALK_TO = "Habla con %s", ARROW_DIVE_DOWN = "Bucea hacia abajo", ARROW_PICK_UP_BOTTOM = "Recógelo en el fondo", ARROW_SWIM_UNDER = "Bucea bajo el agua", ARROW_PICK_UP = "Recógelo", ARROW_GET_TO = "Ve a %s", ARROW_FLYING = "Volando a %s", ARROW_BELOW = "Bajo tierra: busca el camino para bajar", ARROW_ABOVE = "Arriba: busca el camino para subir", ARROW_TIP_MAP = "Haz clic para verlo en el mapa.",
                ARROW_PORTAL = "Toma el portal a %s", ARROW_HEARTH = "Piedra de hogar a %s", ARROW_ELEVATOR = "Toma el ascensor para subir" },
            itIT = { ARROW_TALK_TO = "Parla con %s", ARROW_DIVE_DOWN = "Immergiti dritto verso il fondo", ARROW_PICK_UP_BOTTOM = "Raccoglilo sul fondo", ARROW_SWIM_UNDER = "Nuota sott'acqua", ARROW_PICK_UP = "Raccoglilo", ARROW_GET_TO = "Raggiungi %s", ARROW_FLYING = "In volo verso %s", ARROW_BELOW = "Sottoterra: trova la via per scendere", ARROW_ABOVE = "Più in alto: trova la via per salire", ARROW_TIP_MAP = "Clicca per vederlo sulla mappa.",
                ARROW_PORTAL = "Prendi il portale per %s", ARROW_HEARTH = "Pietra del ritorno: %s", ARROW_ELEVATOR = "Prendi l'ascensore per salire" },
            ptBR = { ARROW_TALK_TO = "Fale com %s", ARROW_DIVE_DOWN = "Mergulhe direto para baixo", ARROW_PICK_UP_BOTTOM = "Pegue-o no fundo", ARROW_SWIM_UNDER = "Nade debaixo d'água", ARROW_PICK_UP = "Pegue-o", ARROW_GET_TO = "Vá para %s", ARROW_FLYING = "Voando para %s", ARROW_BELOW = "No subsolo: encontre o caminho para descer", ARROW_ABOVE = "Mais acima: encontre o caminho para subir", ARROW_TIP_MAP = "Clique para ver no mapa.",
                ARROW_PORTAL = "Pegue o portal para %s", ARROW_HEARTH = "Pedra de regresso para %s", ARROW_ELEVATOR = "Pegue o elevador para subir" },
            ruRU = { ARROW_TALK_TO = "Поговорите: %s", ARROW_DIVE_DOWN = "Ныряйте прямо вниз", ARROW_PICK_UP_BOTTOM = "Подберите на дне", ARROW_SWIM_UNDER = "Ныряйте под воду", ARROW_PICK_UP = "Подберите", ARROW_GET_TO = "Доберитесь: %s", ARROW_FLYING = "Полёт: %s", ARROW_BELOW = "Под землёй: найдите спуск", ARROW_ABOVE = "Выше: найдите подъём", ARROW_TIP_MAP = "Щелкните, чтобы показать на карте.",
                ARROW_PORTAL = "Портал: %s", ARROW_HEARTH = "Камень возвращения: %s", ARROW_ELEVATOR = "Поднимитесь на лифте" },
            koKR = { ARROW_TALK_TO = "%s|1과;와; 대화하세요", ARROW_DIVE_DOWN = "똑바로 아래로 잠수하세요", ARROW_PICK_UP_BOTTOM = "바닥에서 주우세요", ARROW_SWIM_UNDER = "물속으로 잠수하세요", ARROW_PICK_UP = "주우세요", ARROW_GET_TO = "%s(으)로 가세요", ARROW_FLYING = "%s(으)로 비행 중", ARROW_BELOW = "지하: 내려가는 길을 찾으세요", ARROW_ABOVE = "위층: 올라가는 길을 찾으세요", ARROW_TIP_MAP = "클릭하면 지도에 표시합니다.",
                ARROW_PORTAL = "%s행 차원문을 타세요", ARROW_HEARTH = "귀환석: %s", ARROW_ELEVATOR = "승강기를 타고 올라가세요" },
            zhCN = { ARROW_TALK_TO = "与%s交谈", ARROW_DIVE_DOWN = "径直下潜", ARROW_PICK_UP_BOTTOM = "在水底拾取", ARROW_SWIM_UNDER = "潜入水下", ARROW_PICK_UP = "拾取它", ARROW_GET_TO = "前往%s", ARROW_FLYING = "正在飞往%s", ARROW_BELOW = "在地下：找路下去", ARROW_ABOVE = "在上方：找路上去", ARROW_TIP_MAP = "点击在地图上显示。",
                ARROW_PORTAL = "使用传送门前往%s", ARROW_HEARTH = "炉石回到%s", ARROW_ELEVATOR = "乘升降梯上去" },
            zhTW = { ARROW_TALK_TO = "與%s交談", ARROW_DIVE_DOWN = "徑直下潛", ARROW_PICK_UP_BOTTOM = "在水底拾取", ARROW_SWIM_UNDER = "潛入水下", ARROW_PICK_UP = "拾取它", ARROW_GET_TO = "前往%s", ARROW_FLYING = "正在飛往%s", ARROW_BELOW = "在地下：找路下去", ARROW_ABOVE = "在上方：找路上去", ARROW_TIP_MAP = "點擊在地圖上顯示。",
                ARROW_PORTAL = "使用傳送門前往%s", ARROW_HEARTH = "爐石回到%s", ARROW_ELEVATOR = "搭升降梯上去" },
        }
        for locale, entries in pairs(more) do
            for key, value in pairs(entries) do strings[locale][key] = value end
        end
        -- skipnow (2.0.13)
        local skipnow = {
            enUS = { "Skip for now", "Leave this quest off the Route for now and go on to what's next. Tick it in the tracker to put it back." },
            deDE = { "Vorerst überspringen", "Diese Quest vorerst aus der Route nehmen und mit dem Nächsten weitermachen. Hake sie im Tracker an, um sie zurückzuholen." },
            frFR = { "Passer pour l'instant", "Retirer cette quête de l'itinéraire pour l'instant et passer à la suite. Cochez-la dans le suivi pour la remettre." },
            esES = { "Saltar por ahora", "Quitar esta misión de la ruta por ahora y seguir con lo siguiente. Márcala en el seguimiento para volver a añadirla." },
            itIT = { "Salta per ora", "Togli questa missione dal percorso per ora e passa alla successiva. Spuntala nel tracker per rimetterla." },
            ptBR = { "Pular por enquanto", "Tirar esta missão da rota por enquanto e seguir para a próxima. Marque-a no rastreador para colocá-la de volta." },
            ruRU = { "Пропустить пока", "Убрать это задание из маршрута на время и перейти к следующему. Отметьте его в списке, чтобы вернуть." },
            koKR = { "일단 건너뛰기", "이 퀘스트를 일단 경로에서 빼고 다음으로 넘어갑니다. 추적기에서 체크하면 다시 넣을 수 있습니다." },
            zhCN = { "暂时跳过", "暂时将此任务移出路线，继续下一步。在追踪器中勾选即可放回。" },
            zhTW = { "暫時跳過", "暫時將此任務移出路線，繼續下一步。在追蹤器中勾選即可放回。" },
        }
        for locale, pair in pairs(skipnow) do
            if strings[locale] then strings[locale].ARROW_SKIP_NOW, strings[locale].ARROW_SKIP_NOW_TIP = pair[1], pair[2] end
        end
        -- plankjump (2.0.13): Test of Faith's planks
        local jump = { enUS = "Jump off the planks", deDE = "Spring von den Planken", frFR = "Sautez des planches",
            esES = "Salta desde los tablones", itIT = "Salta giù dalle assi", ptBR = "Pule das tábuas",
            ruRU = "Прыгните с досок", koKR = "널빤지에서 뛰어내리세요", zhCN = "从木板上跳下去", zhTW = "從木板上跳下去" }
        for locale, text in pairs(jump) do
            if strings[locale] then strings[locale].ARROW_JUMP_PLANKS = text end
        end
        -- patrolline (2.0.13): Rok'Alim the Pounder
        local patrol = { enUS = "Find Rok'Alim: he patrols the west side", deDE = "Finde Rok'Alim: Er patrouilliert auf der Westseite",
            frFR = "Trouvez Rok'Alim : il patrouille du côté ouest", esES = "Busca a Rok'Alim: patrulla por el lado oeste",
            itIT = "Trova Rok'Alim: pattuglia il lato ovest", ptBR = "Encontre Rok'Alim: ele patrulha o lado oeste",
            ruRU = "Он патрулирует западную часть зоны", koKR = "지역 서쪽을 순찰합니다", zhCN = "它在区域西侧巡逻", zhTW = "牠在區域西側巡邏" }
        for locale, text in pairs(patrol) do
            if strings[locale] then strings[locale].ARROW_ROKALIM_PATROL = text end
        end
        for locale, entries in pairs(strings) do
            local t = FDJ.Locales and FDJ.Locales[locale]
            if t then
                for key, value in pairs(entries) do
                    if t[key] == nil then t[key] = value end
                end
            end
        end
    end

    local function Number(v)
        if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
        return type(v) == "number" and v or nil
    end
    local function Saved()
        if type(ForeverDungeonJournalDB) ~= "table" then ForeverDungeonJournalDB = {} end
        if type(ForeverDungeonJournalDB.arrow) ~= "table" then ForeverDungeonJournalDB.arrow = {} end
        return ForeverDungeonJournalDB.arrow
    end
    -- The followed spots the character has reached or hidden, by source.
    local function Done()
        if type(ForeverDungeonJournalCharacterDB) ~= "table" then ForeverDungeonJournalCharacterDB = {} end
        local db = ForeverDungeonJournalCharacterDB
        if type(db.arrowDone) ~= "table" then db.arrowDone = {} end
        return db.arrowDone
    end

    local function SpotKey(spot)
        return string.format("%s|%.4f|%.4f", tostring(spot.mapID), tonumber(spot.x) or 0, tonumber(spot.y) or 0)
    end

    -- Map spot -> world position (yards) and continent.
    local function World(mapID, x, y)
        if not (C_Map and type(C_Map.GetWorldPosFromMapPos) == "function") then return nil end
        if type(x) ~= "number" or type(y) ~= "number" then return nil end
        local vector = (type(CreateVector2D) == "function" and CreateVector2D(x, y)) or { x = x, y = y }
        local ok, continent, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, vector)
        if not ok or type(pos) ~= "table" then return nil end
        local wx, wy = pos.x, pos.y
        if (wx == nil or wy == nil) and pos.GetXY then wx, wy = pos:GetXY() end
        wx, wy = Number(wx), Number(wy)
        if not wx or not wy then return nil end
        return wx, wy, Number(continent)
    end
    local worldCache = {}
    local function SpotWorld(spot)
        local key = SpotKey(spot)
        local hit = worldCache[key]
        if hit == nil then
            local wx, wy, continent = World(spot.mapID, tonumber(spot.x) or 0, tonumber(spot.y) or 0)
            -- spotlearn (2.0.8): where the NPC really stands, once talked to
            if wx and FDJ.SpotFix then
                local ok, fx, fy = pcall(FDJ.SpotFix, spot, wx, wy, continent)
                if ok and fx and fy then wx, wy = fx, fy end
            end
            hit = wx and { wx, wy, continent, map = tonumber(spot.mapID) } or false
            worldCache[key] = hit
        end
        return hit or nil
    end
    FDJ.ResetSpotWorlds = function() for k in pairs(worldCache) do worldCache[k] = nil end end -- spotlearn

    local function PlayerWorld()
        if type(UnitPosition) == "function" then
            local ok, px, py, _, continent = pcall(UnitPosition, "player")
            if ok then
                px, py = Number(px), Number(py)
                if px and py then return px, py, Number(continent) end
            end
        end
        if C_Map and type(C_Map.GetBestMapForUnit) == "function" and type(C_Map.GetPlayerMapPosition) == "function" then
            local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
            mapID = okMap and Number(mapID) or nil
            if mapID then
                local okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
                if okPos and type(pos) == "table" then
                    local mx, my = pos.x, pos.y
                    if (mx == nil or my == nil) and pos.GetXY then mx, my = pos:GetXY() end
                    mx, my = Number(mx), Number(my)
                    if mx and my then return World(mapID, mx, my) end
                end
            end
        end
        return nil
    end

    local function InInstance()
        if type(IsInInstance) ~= "function" then return false end
        local ok, inside = pcall(IsInInstance)
        if not ok or (type(issecretvalue) == "function" and issecretvalue(inside)) then return false end
        return inside == true or inside == 1
    end
    local function OnTaxi()
        if type(UnitOnTaxi) ~= "function" then return false end
        local ok, flying = pcall(UnitOnTaxi, "player")
        if not ok or (type(issecretvalue) == "function" and issecretvalue(flying)) then return false end
        return flying == true or flying == 1
    end

    local function Indoors()
        if type(IsIndoors) ~= "function" then return false end
        local ok, inside = pcall(IsIndoors)
        if not ok or (type(issecretvalue) == "function" and issecretvalue(inside)) then return false end
        return inside == true or inside == 1
    end

    local function Yards(ax, ay, bx, by)
        local dx, dy = ax - bx, ay - by
        return math.sqrt(dx * dx + dy * dy)
    end
    -- killzone (2.0.8): yards from the player to a spot (nil: not known, or
    -- another continent). An FDJ field: this scope has no locals to spare.
    FDJ.YardsToSpot = function(spot)
        if type(spot) ~= "table" or not spot.mapID then return nil end
        local at = SpotWorld(spot)
        local px, py, continent = PlayerWorld()
        if not (at and px and py) then return nil end
        if at[3] and continent and at[3] ~= continent then return nil end
        return Yards(px, py, at[1], at[2])
    end
    local function Faction()
        if type(UnitFactionGroup) ~= "function" then return nil end
        local ok, faction = pcall(UnitFactionGroup, "player")
        if not ok or (type(issecretvalue) == "function" and issecretvalue(faction)) then return nil end
        return faction
    end

    -- way (1.9.2): places the straight line cannot be walked out of. Each is
    -- a region of its own, joined to the rest only by RIDES (portals, boats)
    -- and flights: Darnassus and the top of Teldrassil (1001), and Rut'theran
    -- Village at the foot of the tree (1002: the Teldrassil map south of
    -- SHORE). Anywhere else a region is the continent.
    local Way = {
        ISLANDS = { [1457] = 1001, [1438] = 1001 },
        SHORE = { [1438] = { 0.84, 1002 } },
        axes = {},
        RIDE_COST = { boat = 1200, zeppelin = 1200, portal = 30 }, -- yards' worth of time: waiting for it and the crossing
        RIDE_WORTH = 3000,  -- yards: a way this long in one region also looks for boats on the way
        HEARTH_ITEM = 6948, HEARTH_SPELL = 8690,
        HEARTH_CAST = 100,  -- yards' worth: casting it
        HEARTH_SAVES = 800, -- yards: only said when it saves this much
        HEARTH_NEAR = 300,  -- yards: standing about there already
        -- hearthfar (2.1.1, M 20 Nov 2026, told to hearth from Riverglades to
        -- Stormwind and fly to Southshore from there: "unless you're changing
        -- continent, or you're maybe hearthing from Booty Bay to Ironforge,
        -- just prefer taking the flight"): to a place on the same continent the
        -- hearthstone is only said when it saves a trip about that long
        -- (Booty Bay to Ironforge by air: some 5,700 yards' worth).
        HEARTH_SAVES_SAME = 4500,
        NAME_NEAR = 600,    -- yards: a flight point this close to where a ride lands names the place
        -- The capitals' innkeepers (Wowhead Forever): where a hearthstone
        -- set there lands, with the English names of the place.
        INNS = {
            { 1457, 0.672, 0.156, "Craftsmen's Terrace", "Darnassus" },
            -- hearthhere (2.0.9): the Gilded Rose on Forever's Stormwind map
            -- (Innkeeper Allison, spawn of NPC 6740); 52.6, 65.6 was its place
            -- on the old map.
            { 1453, 0.604, 0.753, "Trade District", "Stormwind", "Stormwind City" },
            { 1455, 0.185, 0.515, "The Commons", "Ironforge" },
            { 1454, 0.541, 0.685, "Valley of Strength", "Orgrimmar" },
            { 1456, 0.457, 0.640, "Thunder Bluff" },
            { 1458, 0.674, 0.382, "Trade Quarter", "Undercity" },
        },
    }
    -- Map y (0 north .. 1 south) of a world point on a map.
    function Way.MapY(mapID, wx, wy)
        local axis = Way.axes[mapID]
        if axis == nil then
            local ax, ay = World(mapID, 0, 0)
            local bx, by = World(mapID, 0, 1)
            axis = (ax and bx) and { ax, ay, bx - ax, by - ay } or false
            Way.axes[mapID] = axis
        end
        if not axis then return nil end
        local len2 = axis[3] * axis[3] + axis[4] * axis[4]
        if len2 == 0 then return nil end
        return ((wx - axis[1]) * axis[3] + (wy - axis[2]) * axis[4]) / len2
    end
    function Way.Region(continent, mapID, wx, wy)
        local region = mapID and Way.ISLANDS[mapID]
        if not region or not continent then return continent end
        local shore = Way.SHORE[mapID]
        if shore and wx and wy then
            local y = Way.MapY(mapID, wx, wy)
            if y and y >= shore[1] then return shore[2] end
        end
        return region
    end

    -- Boats and zeppelins between the continents (WoW Forever's own routes,
    -- Auberdine -> Menethil -> Southshore -> Auberdine being one way round):
    -- from where it leaves to where it lands, { map, x, y }: where the game's
    -- own NPCs stand at each dock (dock and zeppelin masters, sentries, the
    -- dock's world marker; SOURCES.txt).
    local RIDES = {
        { kind = "boat", faction = "Alliance", from = { 1453, 0.2322, 0.5505 }, to = { 1439, 0.3079, 0.4082 } }, -- Stormwind Harbor -> Auberdine
        { kind = "boat", faction = "Alliance", from = { 1439, 0.3079, 0.4082 }, to = { 1453, 0.2322, 0.5505 } }, -- Auberdine -> Stormwind Harbor
        { kind = "boat", faction = "Alliance", from = { 1439, 0.3230, 0.4376 }, to = { 1437, 0.0483, 0.5704 } }, -- Auberdine -> Menethil Harbor
        { kind = "boat", faction = "Alliance", from = { 1424, 0.5068, 0.6935 }, to = { 1439, 0.3230, 0.4376 } }, -- Southshore -> Auberdine
        { kind = "boat", faction = "Alliance", from = { 1437, 0.0521, 0.6371 }, to = { 1445, 0.7128, 0.5629 } }, -- Menethil Harbor -> Theramore
        { kind = "boat", faction = "Alliance", from = { 1445, 0.7128, 0.5629 }, to = { 1437, 0.0521, 0.6371 } }, -- Theramore -> Menethil Harbor
        { kind = "boat", from = { 1434, 0.2608, 0.7335 }, to = { 1413, 0.6374, 0.3850 } }, -- Booty Bay -> Ratchet
        { kind = "boat", from = { 1413, 0.6374, 0.3850 }, to = { 1434, 0.2608, 0.7335 } }, -- Ratchet -> Booty Bay
        { kind = "boat", from = { 1446, 0.6757, 0.2310 }, to = { 2548, 0.7938, 0.5341 } }, -- Steamwheedle Port -> Powderfuse Port
        { kind = "boat", from = { 2548, 0.7938, 0.5341 }, to = { 1446, 0.6757, 0.2310 } }, -- Powderfuse Port -> Steamwheedle Port
        { kind = "zeppelin", faction = "Horde", from = { 1411, 0.5082, 0.1354 }, to = { 1420, 0.6074, 0.5887 } }, -- Orgrimmar -> Undercity
        { kind = "zeppelin", faction = "Horde", from = { 1420, 0.6074, 0.5887 }, to = { 1411, 0.5082, 0.1354 } }, -- Undercity -> Orgrimmar
        { kind = "zeppelin", faction = "Horde", from = { 1411, 0.5069, 0.1289 }, to = { 1434, 0.3143, 0.2991 } }, -- Orgrimmar -> Grom'gol
        { kind = "zeppelin", faction = "Horde", from = { 1434, 0.3143, 0.2991 }, to = { 1411, 0.5069, 0.1289 } }, -- Grom'gol -> Orgrimmar
        { kind = "zeppelin", faction = "Alliance", from = { 2521, 0.6569, 0.8322 }, to = { 1416, 0.1230, 0.5649 } }, -- Zephras Isle -> Dalaran
        { kind = "zeppelin", faction = "Horde", from = { 2521, 0.5798, 0.8057 }, to = { 1412, 0.3340, 0.2250 } }, -- Zephras Isle -> Mulgore
        -- way (1.9.2): Teldrassil. The portals: west of the Temple Gardens
        -- in Darnassus (30, 41) and on the hill in Rut'theran Village (55,
        -- 89); the Moonspray's piers in Rut'theran (south of Nessa
        -- Shadowsong, 56.2, 92.4) and Auberdine (the northern pier): where
        -- they are on the maps, to a few yards.
        { kind = "portal", from = { 1457, 0.3000, 0.4120 }, to = { 1438, 0.5530, 0.8930 } }, -- Darnassus -> Rut'theran Village
        { kind = "portal", from = { 1438, 0.5520, 0.8920 }, to = { 1457, 0.3010, 0.4130 } }, -- Rut'theran Village -> Darnassus
        { kind = "boat", from = { 1438, 0.5560, 0.9650 }, to = { 1439, 0.3240, 0.3980 } }, -- Rut'theran Village -> Auberdine
        { kind = "boat", from = { 1439, 0.3240, 0.3980 }, to = { 1438, 0.5560, 0.9650 } }, -- Auberdine -> Rut'theran Village
    }
    local rideWorld = {}
    -- Both ends in world yards { x, y, continent } (nil: not on this client).
    local function Ends(ride)
        local hit = rideWorld[ride]
        if hit == nil then
            local fx, fy, fc = World(ride.from[1], ride.from[2], ride.from[3])
            local tx, ty, tc = World(ride.to[1], ride.to[2], ride.to[3])
            -- way: each end's region and map too.
            hit = (fx and fc and tx and tc) and {
                { fx, fy, fc, region = Way.Region(fc, ride.from[1], fx, fy), map = ride.from[1] },
                { tx, ty, tc, region = Way.Region(tc, ride.to[1], tx, ty), map = ride.to[1] } } or false
            rideWorld[ride] = hit
        end
        if hit then return hit[1], hit[2] end
        return nil
    end
    local function Rides(faction, ride)
        return not ride.faction or ride.faction == faction
    end

    -- The flight points the character has found, by continent: the game's own
    -- list (the world map's flight points), { x, y, name } in world yards.
    local CONTINENT_MAPS = { 1415, 1414, 2665 } -- Eastern Kingdoms, Kalimdor, the Skyborne's isles
    local flights, flightsAt = nil, 0
    local function PlaceName(name)
        if type(name) ~= "string" then return "" end
        return name:match("^%s*(.-)%s*,") or name
    end
    local function OurSide(nodeFaction, faction)
        if nodeFaction == 1 then return faction == "Horde" end
        if nodeFaction == 2 then return faction == "Alliance" end
        return true
    end
    -- The flight points this character has found, by the flight map's names
    -- (lower case): the ones a flight master's map listed as where the
    -- character is (CURRENT) or can fly to (REACHABLE), kept in the
    -- character's saved variables. Only the flight map tells: the world
    -- map's isUndiscovered is not to be trusted on WoW Forever. 1.7.4: the
    -- list kept before took more than that, so it is started again once
    -- (flightPointsVersion) and filled at the next flight master.
    local FLIGHT_POINTS_VERSION = 2
    local flightsLearned = 0 -- goes up when the flight map shows a newly found one
    local function FoundFlights()
        if type(ForeverDungeonJournalCharacterDB) ~= "table" then ForeverDungeonJournalCharacterDB = {} end
        local db = ForeverDungeonJournalCharacterDB
        if db.flightPointsVersion ~= FLIGHT_POINTS_VERSION or type(db.flightPoints) ~= "table" then
            db.flightPoints = {}
            db.flightPointsVersion = FLIGHT_POINTS_VERSION
        end
        return db.flightPoints
    end
    -- fpfix (2.0.8, M 15 Nov 2026: "Fly to Chillwind Camp" though he has
    -- never been there): the flight map is the last word for every place it
    -- lists: one it shows as not found is taken off the list again, so a
    -- wrong entry is put right at the next flight master. Read only while
    -- a flight map is open (FDJ.taxiMapOpen). What it listed last:
    -- FDJ.lastTaxiTypes (for /dj flights).
    -- fpdistant (2.0.8, M 15 Nov 2026, /dj flights at Southshore's gryphon
    -- master): the Forever client calls the ones never found DISTANT, not
    -- NONE (Chillwind Camp, Aerie Peak, Light's Hope: none of them on his
    -- flight map, and Chillwind Camp and Aerie Peak fly straight to
    -- Southshore), so only CURRENT and REACHABLE count as found; anything
    -- else it lists is taken off.
    local function RecordFlightMap()
        if type(NumTaxiNodes) ~= "function" or type(TaxiNodeName) ~= "function" then return end
        if not FDJ.taxiMapOpen then return end
        local ok, count = pcall(NumTaxiNodes)
        local found, any = FoundFlights(), false
        if type(TaxiNodeGetType) ~= "function" then return end -- no way to tell which are found
        FDJ.lastTaxiTypes = {}
        for i = 1, (ok and Number(count)) or 0 do
            local okType, kind = pcall(TaxiNodeGetType, i)
            local okName, name = pcall(TaxiNodeName, i)
            if type(issecretvalue) == "function" and (issecretvalue(name) or issecretvalue(kind)) then name = nil end
            if okName and type(name) == "string" and name ~= "" and okType and type(kind) == "string" then
                local key = string.lower(name)
                FDJ.lastTaxiTypes[#FDJ.lastTaxiTypes + 1] = { name, kind }
                if kind == "CURRENT" or kind == "REACHABLE" then
                    if not found[key] then any = true flightsLearned = flightsLearned + 1 end
                    found[key] = true
                elseif found[key] then
                    found[key] = nil -- fpfix, fpdistant: the flight map says it isn't found (NONE, DISTANT)
                    any = true
                end
            end
        end
        if any then flights = nil end
    end
    FDJ.FoundFlightNames = FoundFlights -- fpfix: /dj flights (an FDJ field: no locals to spare here)
    local function Found(node)
        local name = type(node.name) == "string" and string.lower(node.name) or nil
        return name ~= nil and FoundFlights()[name] == true
    end
    local function ReadFlights()
        flights = {}
        if not (C_TaxiMap and type(C_TaxiMap.GetTaxiNodesForMap) == "function") then return end
        local faction, seen = Faction(), {}
        local function Add(mapID, zoned)
            local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
            if not ok or type(nodes) ~= "table" then return 0 end
            local added = 0
            for _, node in ipairs(nodes) do
                local id = type(node) == "table" and Number(node.nodeID)
                if id and Found(node) and OurSide(node.faction, faction) and type(node.position) == "table" then
                    if seen[id] then
                        if seen[id].maps then seen[id].maps[mapID] = true end -- the same flight point on another map (a city's and its zone's)
                    else
                        local nx, ny = node.position.x, node.position.y
                        if (nx == nil or ny == nil) and node.position.GetXY then nx, ny = node.position:GetXY() end
                        local wx, wy, c = World(mapID, Number(nx), Number(ny))
                        if wx and c then
                            local entry = { wx, wy, name = PlaceName(node.name), node = node.name, c = c, maps = zoned and { [mapID] = true } or nil, -- routeauto: node = the flight map's own name
                                region = Way.Region(c, zoned and mapID or nil, wx, wy) } -- way: Rut'theran's is on its own
                            seen[id] = entry
                            flights[c] = flights[c] or {}
                            table.insert(flights[c], entry)
                            added = added + 1
                        end
                    end
                end
            end
            return added
        end
        -- Zone by zone (cities too), so each flight point knows the maps it
        -- is on; the continent's own list only when a game has no zone lists.
        for _, mapID in ipairs(CONTINENT_MAPS) do
            local added = 0
            if C_Map and type(C_Map.GetMapChildrenInfo) == "function" then
                local ok, zones = pcall(C_Map.GetMapChildrenInfo, mapID, 3, true)
                if ok and type(zones) == "table" then
                    for _, zone in ipairs(zones) do
                        if type(zone) == "table" and zone.mapID then added = added + Add(zone.mapID, true) end
                    end
                end
            end
            if added == 0 then Add(mapID) end
        end
    end
    local function FlightPoints(continent)
        local now = (GetTime and GetTime()) or 0
        if not flights or now - flightsAt > 60 then
            ReadFlights()
            flightsAt = now
        end
        return flights[continent]
    end
    -- fpgossip (2.1.3, M 21 Nov 2026 at Aerie Peak: the arrow said "Fly to
    -- Menethil Harbor" and led away from Aerie Peak's gryphon master, "it
    -- should just send me to the flight path here"): the flight map is not
    -- the only way a flight point is found. Talking to its flight master
    -- finds it ("New flight path discovered!"), even for a quest, and one
    -- found that way (Gryphon Master Talonaxe, a quest giver) was not known
    -- here until his flight map was opened. On that message, or a gossip
    -- with a flight option: this side's flight point nearest to the player,
    -- within 100 yards, is kept as found.
    function FDJ.FlightPathFoundHere()
        if not (C_TaxiMap and type(C_TaxiMap.GetTaxiNodesForMap) == "function" and C_Map and type(C_Map.GetBestMapForUnit) == "function") then return end
        local px, py, here = PlayerWorld()
        if not (px and here) then return end
        local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        mapID = okMap and Number(mapID) or nil
        local faction, best, bestYards, guard = Faction(), nil, nil, 0
        while mapID and guard < 4 do
            local okN, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
            for _, node in ipairs((okN and type(nodes) == "table") and nodes or {}) do
                if type(node) == "table" and type(node.name) == "string" and type(node.position) == "table"
                    and OurSide(node.faction, faction) and not Found(node) then
                    local nx, ny = node.position.x, node.position.y
                    if (nx == nil or ny == nil) and node.position.GetXY then nx, ny = node.position:GetXY() end
                    local wx, wy, c = World(mapID, Number(nx), Number(ny))
                    if wx and c == here then
                        local d = Yards(px, py, wx, wy)
                        if d <= 100 and (not bestYards or d < bestYards) then best, bestYards = node, d end
                    end
                end
            end
            local okI, info = pcall(C_Map.GetMapInfo, mapID)
            mapID = okI and type(info) == "table" and Number(info.parentMapID) or nil
            if mapID == 0 then mapID = nil end
            guard = guard + 1
        end
        if not best then return end
        FoundFlights()[string.lower(best.name)] = true
        flights, FDJ.fpMissing = nil, nil
        if FDJ.FollowRoutes then pcall(FDJ.FollowRoutes) end
    end
    -- "New flight path discovered!"
    function FDJ.FlightPathHeard(...)
        local text = _G.ERR_NEWTAXIPATH
        if type(text) ~= "string" then return end
        for i = 1, select("#", ...) do
            if select(i, ...) == text then return FDJ.FlightPathFoundHere() end
        end
    end
    -- A gossip with a flight option (the flight icon, or type "taxi")
    function FDJ.FlightMasterGossip()
        local taxi = false
        if C_GossipInfo and type(C_GossipInfo.GetOptions) == "function" then
            local ok, options = pcall(C_GossipInfo.GetOptions)
            for _, o in ipairs((ok and type(options) == "table") and options or {}) do
                local icon = type(o) == "table" and o.icon or nil
                if icon == 132057 or (type(o) == "table" and o.type == "taxi")
                    or (type(icon) == "string" and string.find(string.lower(icon), "taxi", 1, true)) then taxi = true break end
            end
        end
        if not taxi and type(GetGossipOptions) == "function" then
            local list = { pcall(GetGossipOptions) }
            if list[1] then
                for i = 3, #list, 2 do
                    if list[i] == "taxi" then taxi = true break end
                end
            end
        end
        if taxi then FDJ.FlightPathFoundHere() end
    end
    do
        -- A flight point found, or the flight map opened: read them again.
        local watch = CreateFrame("Frame")
        for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "TAXI_NODE_STATUS_CHANGED", "UI_INFO_MESSAGE", "GOSSIP_SHOW" }) do
            pcall(watch.RegisterEvent, watch, event)
        end
        watch:SetScript("OnEvent", function(_, event, ...)
            if event == "GOSSIP_SHOW" then pcall(FDJ.FlightMasterGossip) return end -- fpgossip
            if event == "UI_INFO_MESSAGE" then pcall(FDJ.FlightPathHeard, ...) end -- fpgossip
            if event == "TAXIMAP_OPENED" then FDJ.taxiMapOpen = true end -- fpfix
            if event == "TAXIMAP_CLOSED" then FDJ.taxiMapOpen = nil end
            if event == "TAXIMAP_OPENED" or event == "TAXI_NODE_STATUS_CHANGED" then pcall(RecordFlightMap) end
            flights = nil
        end)
    end

    -- The flight under way: from / to (the flight map's names), at (when
    -- picked), up (when it took off), guess (seconds, a first guess). How long
    -- each flight took is kept (ForeverDungeonJournalDB.flightTimes, by
    -- "from>to") for the count-down next time.
    local flight
    local function FlightTimes()
        if type(ForeverDungeonJournalDB) ~= "table" then ForeverDungeonJournalDB = {} end
        if type(ForeverDungeonJournalDB.flightTimes) ~= "table" then ForeverDungeonJournalDB.flightTimes = {} end
        return ForeverDungeonJournalDB.flightTimes
    end
    local function NodeNamed(name)
        if not name then return nil end
        FlightPoints(0)
        for _, list in pairs(flights or {}) do
            for _, node in ipairs(list) do
                if node.name == name then return node end
            end
        end
        return nil
    end
    -- The flight map's names of where the player is and of the picked slot.
    local function TaxiName(i)
        if type(TaxiNodeName) ~= "function" or i == nil then return nil end
        local ok, name = pcall(TaxiNodeName, i)
        if not ok or (type(issecretvalue) == "function" and issecretvalue(name)) then return nil end
        return type(name) == "string" and name ~= "" and name or nil
    end
    local function TaxiNames(slot)
        local Name = TaxiName
        local from
        if type(NumTaxiNodes) == "function" and type(TaxiNodeGetType) == "function" then
            local ok, count = pcall(NumTaxiNodes)
            for i = 1, (ok and Number(count)) or 0 do
                local okType, kind = pcall(TaxiNodeGetType, i)
                if okType and kind == "CURRENT" then
                    from = Name(i)
                    break
                end
            end
        end
        return from, Name(slot)
    end
    -- How long a flight takes the first time (1.8.5): the yards it flies
    -- along its path, from Blizzard's TaxiPath tables of Classic Era (by way
    -- of the travel tables gathered offline): the flight masters
    -- { continent, wx, wy } by node id, and the one-way flights from, to,
    -- yards. A flight that changes gryphons on the way flies each hop.
    local TAXI_NODES = {
        [2] = { 0, -8840.6, 489.7 }, [4] = { 0, -10628.9, 1036.7 }, [5] = { 0, -9429.1, -2231.4 }, [6] = { 0, -4821.8, -1155.4 },
        [7] = { 0, -3792.3, -783.3 }, [8] = { 0, -5421.9, -2930 }, [10] = { 0, 478.9, 1536.6 }, [11] = { 0, 1568.6, 268 },
        [12] = { 0, -10515.5, -1261.7 }, [13] = { 0, -0.1, -859.9 }, [14] = { 0, -711.5, -515.5 }, [16] = { 0, -1240.5, -2515.1 },
        [17] = { 0, -916.3, -3496.9 }, [18] = { 0, -14444.3, 509.6 }, [19] = { 0, -14473, 464.1 }, [20] = { 0, -12414.2, 146.3 },
        [21] = { 0, -6634, -2180.1 }, [22] = { 1, -1197.2, 29.7 }, [23] = { 1, 1677.6, -4315.7 }, [25] = { 1, -441.8, -2596.1 },
        [26] = { 1, 6341.4, 557.7 }, [27] = { 1, 8643.6, 841 }, [28] = { 1, 2827.3, -289.2 }, [29] = { 1, 966.6, 1040.3 },
        [30] = { 1, -5407.7, -2414.3 }, [31] = { 1, -4491.9, -775.9 }, [32] = { 1, -3825.4, -4516.6 }, [33] = { 1, 2681.1, 1461.7 },
        [37] = { 1, 139.2, 1325.8 }, [38] = { 1, -1767.6, 3263.9 }, [39] = { 1, -7224, -3734.6 }, [40] = { 1, -7048.9, -3780.4 },
        [41] = { 1, -4373.8, 3338.6 }, [42] = { 1, -4419.9, 199.3 }, [43] = { 0, 283.7, -2002.8 }, [44] = { 1, 3661.5, -4390.4 },
        [45] = { 0, -11112.2, -3435.7 }, [48] = { 1, 5068.4, -337.2 }, [49] = { 1, 7458.5, -2487.2 }, [52] = { 1, 6799.2, -4742.4 },
        [53] = { 1, 6813.1, -4611.1 }, [55] = { 1, -3147.4, -2842.2 }, [56] = { 0, -10457, -3279.2 }, [58] = { 1, 3374.7, 997 },
        [61] = { 1, 2302.4, -2524.6 }, [62] = { 1, 7793.6, -2403.5 }, [63] = { 1, 7787.7, -2404.1 }, [64] = { 1, 2722, -3880.6 },
        [65] = { 1, 6205.9, -1949.6 }, [66] = { 0, 931.3, -1430.1 }, [67] = { 0, 2271.1, -5340.8 }, [68] = { 0, 2327.4, -5286.9 },
        [69] = { 1, 7470.4, -2123.4 }, [70] = { 0, -7504, -2187.5 }, [71] = { 0, -8364.6, -2738.4 }, [72] = { 1, -6811.4, 836.7 },
        [73] = { 1, -6761.8, 772 }, [74] = { 0, -6552.6, -1168.3 }, [75] = { 0, -6554.9, -1100.1 }, [76] = { 0, -635.3, -4720.5 },
        [77] = { 1, -2380.7, -1882.7 }, [79] = { 1, -6113.8, -1142.7 }, [80] = { 1, -894.6, -3773 },
    }
    local TAXI_FLOWN = {
        2, 4, 2319, 2, 5, 3368, 2, 6, 7748, 2, 12, 3469, 2, 19, 7317, 2, 45, 5268, 2, 71, 4700, 4, 2, 2565,
        4, 5, 3890, 4, 12, 2897, 4, 19, 5561, 5, 2, 3374, 5, 4, 4003, 5, 12, 1812, 5, 71, 1825, 6, 2, 6307,
        6, 7, 3861, 6, 8, 3037, 6, 14, 7938, 6, 16, 7585, 6, 43, 8941, 6, 66, 8816, 6, 67, 10440, 6, 74, 2594,
        7, 6, 2658, 7, 8, 4877, 7, 14, 3215, 7, 16, 3388, 8, 6, 3266, 8, 7, 4564, 8, 16, 4902, 10, 11, 3345,
        10, 13, 2847, 11, 10, 3180, 11, 13, 4224, 11, 17, 9014, 11, 21, 14630, 11, 68, 7849, 11, 76, 8530, 12, 2, 2629,
        12, 4, 2794, 12, 5, 1787, 12, 19, 5135, 12, 45, 2903, 13, 10, 2969, 13, 11, 4172, 13, 17, 3532, 13, 76, 5840,
        14, 6, 6174, 14, 7, 3301, 14, 16, 2214, 14, 43, 2139, 14, 66, 2418, 16, 6, 8109, 16, 7, 3776, 16, 8, 5113,
        16, 14, 2596, 16, 43, 2152, 17, 11, 7763, 17, 13, 3493, 17, 21, 7760, 17, 76, 2705, 18, 20, 3047, 18, 21, 12190,
        18, 56, 7986, 19, 2, 6585, 19, 4, 5439, 19, 12, 5242, 20, 18, 2422, 20, 21, 9802, 20, 56, 6151, 21, 11, 14918,
        21, 17, 7881, 21, 18, 12493, 21, 20, 9376, 21, 56, 8424, 21, 70, 2593, 21, 75, 1682, 22, 23, 6213, 22, 25, 4752,
        22, 29, 5439, 22, 30, 6113, 22, 38, 4772, 22, 40, 8693, 22, 42, 7563, 22, 44, 8070, 22, 55, 7149, 22, 77, 2599,
        23, 22, 6745, 23, 25, 3304, 23, 40, 12500, 23, 44, 2965, 23, 48, 7558, 23, 53, 9582, 23, 55, 6853, 23, 61, 2680,
        25, 22, 5461, 25, 23, 4252, 25, 29, 4495, 25, 30, 5532, 25, 40, 9093, 25, 42, 7547, 25, 44, 5051, 25, 48, 7603,
        25, 55, 4878, 25, 58, 6902, 25, 61, 4871, 25, 77, 2705, 25, 80, 1545, 26, 27, 2525, 26, 28, 5270, 26, 32, 20249,
        26, 33, 5432, 26, 37, 8723, 26, 41, 14168, 26, 49, 4525, 26, 64, 8981, 26, 65, 5682, 27, 26, 2551, 28, 26, 4426,
        28, 33, 4599, 28, 64, 4428, 29, 22, 5227, 29, 25, 4477, 29, 38, 4297, 30, 22, 6764, 30, 25, 5810, 30, 40, 2782,
        30, 42, 3685, 30, 77, 4111, 31, 32, 4780, 31, 39, 5122, 31, 41, 5335, 32, 26, 18600, 32, 31, 4887, 32, 37, 10013,
        32, 39, 4694, 32, 64, 7052, 32, 80, 3446, 33, 26, 5304, 33, 28, 4613, 33, 37, 3803, 37, 26, 8458, 37, 32, 9220,
        37, 33, 3581, 37, 41, 6949, 38, 22, 5342, 38, 29, 5966, 38, 42, 5873, 39, 31, 5304, 39, 32, 4606, 39, 73, 5907,
        39, 79, 3115, 40, 22, 9107, 40, 23, 10495, 40, 25, 9008, 40, 30, 2602, 40, 42, 5973, 40, 55, 6647, 40, 72, 6976,
        40, 79, 3218, 41, 26, 14014, 41, 31, 4635, 41, 37, 6797, 41, 73, 4774, 42, 22, 7777, 42, 25, 7915, 42, 30, 3215,
        42, 38, 6016, 42, 40, 6024, 42, 72, 3897, 43, 6, 7658, 43, 14, 2039, 43, 16, 2267, 43, 66, 1590, 43, 67, 4922,
        44, 22, 7700, 44, 23, 3622, 44, 25, 5163, 44, 48, 6955, 44, 53, 3905, 44, 61, 2795, 45, 2, 5672, 45, 12, 2748,
        45, 71, 6251, 48, 23, 7747, 48, 25, 7227, 48, 44, 7221, 48, 53, 5700, 48, 69, 4947, 49, 26, 4247, 49, 52, 3900,
        49, 65, 1840, 52, 49, 3639, 52, 64, 5265, 52, 65, 3670, 53, 23, 9115, 53, 44, 4041, 53, 48, 5853, 53, 69, 4016,
        55, 22, 6729, 55, 23, 6496, 55, 25, 4848, 55, 40, 6660, 56, 18, 7798, 56, 20, 5646, 56, 21, 8555, 56, 70, 5916,
        58, 25, 6827, 58, 61, 5013, 61, 23, 2869, 61, 25, 4806, 61, 44, 2870, 61, 58, 4995, 62, 27, 4559, 63, 22, 16313,
        64, 26, 9038, 64, 28, 4578, 64, 32, 7242, 64, 52, 5355, 64, 65, 8502, 64, 80, 4062, 65, 26, 5622, 65, 49, 2005,
        65, 52, 3601, 65, 64, 8465, 66, 6, 7782, 66, 14, 2559, 66, 43, 1958, 66, 67, 4390, 67, 6, 11024, 67, 43, 4871,
        67, 66, 4484, 68, 11, 7837, 68, 76, 4232, 69, 48, 4713, 69, 53, 4256, 70, 21, 2994, 70, 56, 6376, 70, 75, 2154,
        71, 2, 4528, 71, 5, 1884, 71, 45, 6288, 71, 74, 3090, 72, 40, 7224, 72, 42, 3895, 72, 79, 2896, 73, 39, 5652,
        73, 41, 5239, 73, 79, 2745, 74, 6, 2802, 74, 71, 2865, 75, 21, 2090, 75, 70, 2297, 76, 11, 8538, 76, 13, 4767,
        76, 17, 2785, 76, 68, 4159, 77, 22, 3410, 77, 25, 2380, 77, 30, 3750, 79, 39, 3100, 79, 40, 3396, 79, 72, 3003,
        79, 73, 2823, 80, 25, 2041, 80, 32, 3149, 80, 64, 3960,
    }
    local flown
    local function Flown()
        if not flown then
            flown = {}
            for i = 1, #TAXI_FLOWN - 2, 3 do
                local a = TAXI_FLOWN[i]
                flown[a] = flown[a] or {}
                flown[a][TAXI_FLOWN[i + 1]] = TAXI_FLOWN[i + 2]
            end
        end
        return flown
    end
    -- The node id of a flight point (one of FlightPoints'), by where it is.
    local function TaxiID(node)
        if type(node) ~= "table" then return nil end
        for id, n in pairs(TAXI_NODES) do
            if n[1] == node.c and Yards(node[1], node[2], n[2], n[3]) <= 60 then return id end
        end
        return nil
    end
    -- The shortest way from node id a to b through the flights (only
    -- through ids in allowed, when given): yards and hops.
    local function ShortestFlight(a, b, allowed)
        local graph = Flown()
        local dist, hops, done = { [a] = 0 }, { [a] = 0 }, {}
        while true do
            local u, best
            for id, d in pairs(dist) do
                if not done[id] and (not best or d < best) then u, best = id, d end
            end
            if not u then return nil end
            if u == b then return best, hops[u] end
            done[u] = true
            for v, yards in pairs(graph[u] or {}) do
                if (v == b or not allowed or allowed[v]) and not done[v] and (not dist[v] or best + yards < dist[v]) then
                    dist[v], hops[v] = best + yards, hops[u] + 1
                end
            end
        end
    end
    -- Seconds a picked flight takes: hop by hop as the flight map lists
    -- them, else the shortest way through the flight points the character
    -- has found, else the straight line bent by FLIGHT_CURVE.
    local function FlightGuess(slot, from, to)
        local function Node(name) return name and NodeNamed(PlaceName(name)) or nil end
        if type(GetNumRoutes) == "function" and type(TaxiGetNodeSlot) == "function" then
            local ok, count = pcall(GetNumRoutes, slot)
            count = ok and Number(count) or 0
            local total = 0
            for hop = 1, count do
                local okA, sa = pcall(TaxiGetNodeSlot, slot, hop, true)
                local okB, sb = pcall(TaxiGetNodeSlot, slot, hop, false)
                local a, b = okA and Node(TaxiName(sa)), okB and Node(TaxiName(sb))
                local ia, ib = TaxiID(a), TaxiID(b)
                local yards = ia and ib and Flown()[ia] and Flown()[ia][ib]
                if not yards and a and b then yards = Yards(a[1], a[2], b[1], b[2]) * FLIGHT_CURVE end
                if not yards then total = nil break end
                total = total + yards / FLIGHT_SPEED + FLIGHT_STOP
            end
            if total and count > 0 then return total end
        end
        local a, b = Node(from), Node(to)
        local ia, ib = TaxiID(a), TaxiID(b)
        if ia and ib then
            local allowed = {}
            for _, list in pairs(flights or {}) do
                for _, node in ipairs(list) do
                    local id = TaxiID(node)
                    if id then allowed[id] = true end
                end
            end
            local yards, hops = ShortestFlight(ia, ib, allowed)
            if not yards then yards, hops = ShortestFlight(ia, ib) end
            if yards then return yards / FLIGHT_SPEED + FLIGHT_STOP * hops end
        end
        if a and b then return Yards(a[1], a[2], b[1], b[2]) * FLIGHT_CURVE / FLIGHT_SPEED + FLIGHT_STOP end
        return nil
    end
    local function Clock(seconds)
        seconds = math.max(0, math.floor(seconds + 0.5))
        return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    end
    -- Watches a picked flight take off and land (also with the arrow hidden).
    local clock = CreateFrame("Frame")
    clock:Hide()
    clock:SetScript("OnUpdate", function(self, elapsed)
        self.fdjWait = (self.fdjWait or 0) - (elapsed or 0)
        if self.fdjWait > 0 then return end
        self.fdjWait = 0.5
        local now = (GetTime and GetTime()) or 0
        if not flight then
            self:Hide()
        elseif OnTaxi() then
            flight.up = flight.up or now
        elseif flight.up then
            local took = now - flight.up
            if flight.from and flight.to and took >= 5 then
                FlightTimes()[flight.from .. ">" .. flight.to] = math.floor(took + 0.5)
            end
            flight = nil
            self:Hide()
        elseif now - (flight.at or now) > 20 then
            flight = nil -- never took off
            self:Hide()
        end
    end)
    local function Watch(new)
        flight = new
        clock.fdjWait = 0
        clock:Show()
    end
    if type(hooksecurefunc) == "function" and type(TakeTaxiNode) == "function" then
        hooksecurefunc("TakeTaxiNode", function(slot)
            local from, to = TaxiNames(slot)
            local picked = { from = from, to = to, at = (GetTime and GetTime()) or 0 }
            picked.guess = FlightGuess(slot, from, to)
            Watch(picked)
        end)
    end

    -- The map the player stands on (a zone, or a city), for the zone rule.
    local function PlayerMap()
        if not (C_Map and type(C_Map.GetBestMapForUnit) == "function") then return nil end
        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        return ok and Number(mapID) or nil
    end
    -- swimstraight (2.1.3, M 21 Nov 2026 on Stranglethorn's Savage Coast,
    -- the arrow to Enemies in the Water leading him up the coast: "it
    -- should just point me straight into the water"): the walking net keeps
    -- to the land, so a place out in the sea was reached round by the
    -- shore. A spot marked swim is swum to in a straight line from its own
    -- zone, within SWIM yards (further off, the roads are quicker).
    -- (on Way: this scope is at Lua's limit of locals)
    function Way.SwimStraight(entry, plan, px, py)
        local spot = type(entry) == "table" and entry.spot or nil
        if type(spot) ~= "table" or not spot.swim or type(plan) ~= "table" then return false end
        if plan.via or plan.fly or plan.ride or not (plan.x and plan.y and px and py) then return false end
        if PlayerMap() ~= tonumber(spot.mapID) then return false end
        local goal = SpotWorld(spot)
        if not goal or Yards(goal[1], goal[2], plan.x, plan.y) > 80 then return false end
        return Yards(px, py, plan.x, plan.y) <= 1000
    end
    -- What a flight point costs on top when it is not on the given map
    -- (nil map, or a flight point whose maps are not known: nothing).
    local function Far(node, mapID)
        if not mapID or not node.maps then return 0 end
        return node.maps[mapID] and 0 or FAR_ZONE
    end
    -- zonewalk (2.0.9, M at Stormwind's gryphon master, 15 Nov 2026, the
    -- arrow to the Rebel Camp: "why is it not telling me to fly to the
    -- closest spot? It should tell me to fly to Duskwood and then run"):
    -- a walk was measured in a straight line, so 2,573 yards from Stormwind
    -- across Elwynn and Duskwood beat the flight to Darkshire and 1,300
    -- yards on foot. Every zone border a walk crosses now counts FAR_ZONE
    -- (borders are mostly mountains and rivers, with few ways through): the
    -- zones along the straight line are asked of the game's map, at 13
    -- points. nil when the game cannot tell (then as before).
    -- (on Way: this scope is at Lua's limit of locals)
    Way.borderCache, Way.borderCount = {}, 0
    function Way.Borders(c, ax, ay, bx, by)
        if not (C_Map and type(C_Map.GetMapInfoAtPosition) == "function" and type(C_Map.GetMapPosFromWorldPos) == "function") then return nil end
        local continentMap = (c == 0 and 1415) or (c == 1 and 1414) or nil
        if not continentMap or not ax or not bx then return nil end
        local key = string.format("%d|%d|%d|%d|%d", c, math.floor(ax / 25), math.floor(ay / 25), math.floor(bx / 25), math.floor(by / 25))
        local hit = Way.borderCache[key]
        if hit ~= nil then return hit end
        local last, count = nil, 0
        for i = 0, 12 do
            local wx, wy = ax + (bx - ax) * i / 12, ay + (by - ay) * i / 12
            local vector = (type(CreateVector2D) == "function" and CreateVector2D(wx, wy)) or { x = wx, y = wy }
            local okPos, _, pos = pcall(C_Map.GetMapPosFromWorldPos, c, vector, continentMap)
            local mx, my
            if okPos and type(pos) == "table" then
                mx, my = pos.x, pos.y
                if (mx == nil or my == nil) and pos.GetXY then mx, my = pos:GetXY() end
            end
            local okInfo, info
            if Number(mx) and Number(my) then okInfo, info = pcall(C_Map.GetMapInfoAtPosition, continentMap, mx, my) end
            local id = okInfo and type(info) == "table" and Number(info.mapID) or nil
            if not id then count = nil break end
            if last and id ~= last then count = count + 1 end
            last = id
        end
        if not count then return nil end -- (not kept: the game may tell next time)
        if Way.borderCount > 400 then Way.borderCache, Way.borderCount = {}, 0 end
        Way.borderCache[key], Way.borderCount = count, Way.borderCount + 1
        return count
    end
    -- A walk's yards with its zone borders; to or from a flight point: the
    -- borders when the game tells them, else Far as before.
    function Way.Walk(c, ax, ay, bx, by)
        local borders = Way.Borders(c, ax, ay, bx, by)
        return Yards(ax, ay, bx, by) + (borders or 0) * FAR_ZONE
    end
    function Way.WalkNode(c, x, y, node, mapID)
        local borders = Way.Borders(c, x, y, node[1], node[2])
        if borders then return Yards(x, y, node[1], node[2]) + borders * FAR_ZONE end
        return Yards(x, y, node[1], node[2]) + Far(node, mapID)
    end

    -- The three flight points nearest to (x, y).
    local function Nearest(nodes, x, y)
        local a, b, c, da, db, dc
        for _, node in ipairs(nodes) do
            local d = Yards(x, y, node[1], node[2])
            if not da or d < da then
                c, dc, b, db, a, da = b, db, a, da, node, d
            elseif not db or d < db then
                c, dc, b, db = b, db, node, d
            elseif not dc or d < dc then
                c, dc = node, d
            end
        end
        return { a, b, c }
    end
    -- The best flight from (px, py) to (qx, qy) on continent c: from, to and
    -- what it costs (in yards on foot), counting the walks to and from it.
    -- fromMap / toMap: the maps (zones) where (px, py) and (qx, qy) are; a
    -- flight point on another map counts FAR_ZONE yards farther.
    -- way: fromR / toR, the regions the flight leaves from and lands in
    -- (nil: any).
    local function FlyCost(c, px, py, qx, qy, fromMap, toMap, fromR, toR)
        local nodes = FlightPoints(c)
        if not nodes or #nodes < 2 then return nil end
        local starts, ends = nodes, nodes
        if fromR or toR then
            starts, ends = {}, {}
            for _, node in ipairs(nodes) do
                local r = node.region or node.c
                if not fromR or r == fromR then starts[#starts + 1] = node end
                if not toR or r == toR then ends[#ends + 1] = node end
            end
        end
        local best, bestTo, least
        for _, a in ipairs(Nearest(starts, px, py)) do
            for _, b in ipairs(Nearest(ends, qx, qy)) do
                if a ~= b then
                    local cost = Way.WalkNode(c, px, py, a, fromMap) + Yards(a[1], a[2], b[1], b[2]) / FLY_SPEED + FLY_EXTRA + Way.WalkNode(c, qx, qy, b, toMap)
                    if not least or cost < least then best, bestTo, least = a, b, cost end
                end
            end
        end
        return best, bestTo, least
    end
    -- How long the way is, in yards on foot: walking, or flying when quicker.
    -- way: between two regions only a flight gets there (nil: none).
    local function Travel(c, px, py, qx, qy, fromMap, toMap, fromR, toR)
        if fromR and toR and fromR ~= toR then
            local _, _, cost = FlyCost(c, px, py, qx, qy, fromMap, toMap, fromR, toR)
            return cost
        end
        local walk = Yards(px, py, qx, qy)
        if walk < FLY_MIN then return walk end
        walk = Way.Walk(c, px, py, qx, qy) -- zonewalk
        local _, _, cost = FlyCost(c, px, py, qx, qy, fromMap, toMap, fromR, toR)
        return (cost and cost < walk) and cost or walk
    end
    -- The flight to take from (px, py) to (qx, qy), when it saves enough of
    -- the way (keep: the one already chosen, kept while it saves any).
    -- way: between two regions (fromR, toR) the flight is the only way.
    -- netwalk (2.1.1): walkYards, the walking net's own yards for the way
    -- (Plan), when longer than the straight line and its borders.
    local function Flight(c, px, py, qx, qy, keep, fromMap, toMap, fromR, toR, walkYards)
        local across = fromR ~= nil and toR ~= nil and fromR ~= toR
        local walk = across and math.huge or math.max(Way.Walk(c, px, py, qx, qy), walkYards or 0) -- zonewalk
        -- fpdistant: kept only while both ends are still found (a flight
        -- map can take one off the list).
        if keep and keep[1].c == c and (not fromR or (keep[1].region or keep[1].c) == fromR)
            and (not toR or (keep[2].region or keep[2].c) == toR)
            and Found({ name = keep[1].node }) and Found({ name = keep[2].node }) then
            local a, b = keep[1], keep[2]
            local cost = Way.WalkNode(c, px, py, a, fromMap) + Yards(a[1], a[2], b[1], b[2]) / FLY_SPEED + FLY_EXTRA + Way.WalkNode(c, qx, qy, b, toMap)
            if cost < walk then return a, b end
        end
        if not across and walk < FLY_MIN then return nil end
        local a, b, cost = FlyCost(c, px, py, qx, qy, fromMap, toMap, fromR, toR)
        if a and (across or cost < walk * FLY_WORTH) then return a, b end
        return nil
    end

    -- way (1.9.2): the quickest way from p to t, points { x, y, continent,
    -- region =, map = }: on foot or by flight, and through as many boats,
    -- zeppelins and portals as it takes (Darnassus -> the portal -> the
    -- Moonspray -> Auberdine -> the boat to Stormwind). Returns the first
    -- ride to take (nil: none, straight there or by flight) and what the
    -- whole way costs in yards on foot (nil: no way known).
    function Way.Leg(a, b)
        if not a[3] or a[3] ~= b[3] then return nil end
        return Travel(a[3], a[1], a[2], b[1], b[2], a.map, b.map, a.region, b.region)
    end
    -- Ride end to ride end: the same until another flight point is found.
    function Way.CachedLeg(a, b)
        if Way.cacheFlights ~= flights then Way.cache, Way.cacheFlights = {}, flights end
        local row = Way.cache[a]
        if not row then
            row = {}
            Way.cache[a] = row
        end
        local hit = row[b]
        if hit == nil then
            hit = Way.Leg(a, b) or false
            row[b] = hit
        end
        return hit or nil
    end
    function Way.Search(p, t)
        local faction = Faction()
        local best = Way.Leg(p, t)
        local bestFirst
        local rides = {}
        for _, ride in ipairs(RIDES) do
            if Rides(faction, ride) then
                local from, to = Ends(ride)
                if from then rides[#rides + 1] = { ride = ride, from = from, to = to } end
            end
        end
        local cost, first, done = {}, {}, {}
        for i, r in ipairs(rides) do
            local leg = r.from[3] == p[3] and Way.Leg(p, r.from) or nil
            if leg then cost[i], first[i] = leg + (Way.RIDE_COST[r.ride.kind] or 0), r.ride end
        end
        while true do
            local u
            for i, c in pairs(cost) do
                if not done[i] and (not u or c < cost[u]) then u = i end
            end
            if not u or (best and cost[u] >= best) then break end
            done[u] = true
            local land = rides[u].to
            local rest = land[3] == t[3] and Way.Leg(land, t) or nil
            if rest and (not best or cost[u] + rest < best) then best, bestFirst = cost[u] + rest, first[u] end
            for i, r in ipairs(rides) do
                if not done[i] and r.from[3] == land[3] then
                    local leg = Way.CachedLeg(land, r.from)
                    if leg then
                        local c = cost[u] + leg + (Way.RIDE_COST[r.ride.kind] or 0)
                        if not cost[i] or c < cost[i] then cost[i], first[i] = c, first[u] end
                    end
                end
            end
        end
        return bestFirst, best
    end

    -- way: the hearthstone. Where it goes: where this character last set
    -- it or came out of it (ForeverDungeonJournalCharacterDB.hearthSpot,
    -- under the game's own name of the place), else the flight point of
    -- that name (most inns stand by one), else a capital's inn.
    function Way.MapName(mapID)
        if not (C_Map and type(C_Map.GetMapInfo) == "function") then return "" end
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        local name = ok and type(info) == "table" and info.name or nil
        if type(issecretvalue) == "function" and issecretvalue(name) then name = nil end
        return type(name) == "string" and name or ""
    end
    function Way.BindName()
        if type(GetBindLocation) ~= "function" then return nil end
        local ok, name = pcall(GetBindLocation)
        if not ok or (type(issecretvalue) == "function" and issecretvalue(name)) then return nil end
        return type(name) == "string" and name ~= "" and name or nil
    end
    function Way.Point(mapID, x, y)
        local w = SpotWorld({ mapID = mapID, x = x, y = y })
        if not w then return nil end
        return { w[1], w[2], w[3], region = Way.Region(w[3], mapID, w[1], w[2]), map = mapID }
    end
    -- Every flight point of the world (found or not), for their names.
    function Way.AllNodes()
        if Way.nodes then return Way.nodes end
        local list = {}
        if C_TaxiMap and type(C_TaxiMap.GetTaxiNodesForMap) == "function" and C_Map and type(C_Map.GetMapChildrenInfo) == "function" then
            local seen = {}
            for _, continentMap in ipairs(CONTINENT_MAPS) do
                local okZones, zones = pcall(C_Map.GetMapChildrenInfo, continentMap, 3, true)
                for _, zone in ipairs((okZones and type(zones) == "table") and zones or {}) do
                    local okNodes, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, zone.mapID)
                    for _, node in ipairs((okNodes and type(nodes) == "table") and nodes or {}) do
                        local id = type(node) == "table" and Number(node.nodeID)
                        if id and not seen[id] and type(node.position) == "table" and type(node.name) == "string" then
                            local nx, ny = node.position.x, node.position.y
                            if (nx == nil or ny == nil) and node.position.GetXY then nx, ny = node.position:GetXY() end
                            local point = Way.Point(zone.mapID, Number(nx), Number(ny))
                            if point then
                                seen[id] = true
                                point.name = PlaceName(node.name)
                                list[#list + 1] = point
                            end
                        end
                    end
                end
            end
        end
        if #list > 0 then Way.nodes = list end
        return list
    end
    -- The place a ride lands at, by the flight point there ("Rut'theran
    -- Village", "Menethil Harbor"), else the zone or city.
    function Way.PlaceAt(mapID, x, y)
        local point = Way.Point(mapID, x, y)
        local best, bestD
        if point then
            for _, node in ipairs(Way.AllNodes()) do
                if node[3] == point[3] then
                    local d = Yards(node[1], node[2], point[1], point[2])
                    if d <= Way.NAME_NEAR and (not bestD or d < bestD) then best, bestD = node, d end
                end
            end
        end
        if best and best.name ~= "" then return best.name end
        return Way.MapName(mapID)
    end
    function Way.CharDB()
        if type(ForeverDungeonJournalCharacterDB) ~= "table" then ForeverDungeonJournalCharacterDB = {} end
        return ForeverDungeonJournalCharacterDB
    end
    function Way.BindSpot()
        local name = Way.BindName()
        if not name then return nil end
        local saved = Way.CharDB().hearthSpot
        -- hearthhere (2.0.9): a spot saved before could be where the
        -- hearthstone was used from, not where it went (v 2: checked)
        if type(saved) == "table" and saved.v == 2 and saved.name == name and saved.mapID and saved.x and saved.y then
            local point = Way.Point(saved.mapID, saved.x, saved.y)
            if point then return name, point end
        end
        local lower = string.lower(name)
        for _, inn in ipairs(Way.INNS) do
            local match = string.lower(Way.MapName(inn[1])) == lower
            for i = 4, #inn do
                if string.lower(inn[i]) == lower then match = true end
            end
            if match then return name, Way.Point(inn[1], inn[2], inn[3]) end
        end
        for _, node in ipairs(Way.AllNodes()) do
            if string.lower(node.name) == lower then return name, node end
        end
        return nil
    end
    function Way.HearthReady()
        local count = (C_Item and C_Item.GetItemCount) or GetItemCount
        if type(count) ~= "function" then return false end
        local ok, n = pcall(count, Way.HEARTH_ITEM)
        n = ok and Number(n) or nil
        if not n or n < 1 then return false end
        local cooldown = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
        if type(cooldown) ~= "function" then return true end
        local okCD, start, duration, enable = pcall(cooldown, Way.HEARTH_ITEM)
        if not okCD then return true end
        start, duration = Number(start) or 0, Number(duration) or 0
        if enable == 0 or enable == false then return false end -- held back (in combat)
        if start == 0 or duration <= 1.5 then return true end -- 1.5: the global cooldown
        return start + duration - ((GetTime and GetTime()) or 0) <= 0
    end
    -- plan.hearth = the place's name when the hearthstone is ready and
    -- going from there is the quicker way by HEARTH_SAVES at least (looked
    -- at every 2 seconds).
    -- hearthhere (2.0.9, M in Stormwind, 15 Nov 2026: "why does it say
    -- hearth to Stormwind when I'm already in Stormwind"): standing in the
    -- place the hearthstone goes to (its zone or sub-zone by name), it is
    -- never the way.
    function Way.AtBind(name)
        if type(name) ~= "string" then return false end
        local lower = string.lower(name)
        for _, get in ipairs({ GetZoneText, GetSubZoneText, GetRealZoneText }) do
            if type(get) == "function" then
                local ok, here = pcall(get)
                if ok and type(here) == "string" and here ~= "" and string.lower(here) == lower then return true end
            end
        end
        return false
    end
    function Way.Hearth(entry, plan, p, t, cost)
        local now = (GetTime and GetTime()) or 0
        if entry.hearthAt and now - entry.hearthAt < 2 then
            plan.hearth = entry.hearth
            return
        end
        entry.hearthAt, entry.hearth = now, nil
        if not cost or cost < Way.HEARTH_SAVES + Way.HEARTH_CAST or not Way.HearthReady() then return end
        local name, spot = Way.BindSpot()
        if not spot then return end
        if spot[3] == p[3] and Yards(p[1], p[2], spot[1], spot[2]) < Way.HEARTH_NEAR then return end
        if Way.AtBind(name) then return end
        local _, from = Way.Search(spot, t)
        -- hearthfar: the stricter rule only for a way that stays on the
        -- continent (crossover, 2.1.1, M at the Talondeep Path on his way to
        -- Undercity: "my Hearthstone is ready, which will save a lot of time")
        local need = (spot[3] == p[3] and t[3] == p[3]) and Way.HEARTH_SAVES_SAME or Way.HEARTH_SAVES -- hearthfar
        if from and Way.HEARTH_CAST + from + need <= cost then entry.hearth = name end
        plan.hearth = entry.hearth
    end
    do
        -- Where the hearthstone goes: the inn where it is set, and where it
        -- lands (any language: under the game's own name of the place).
        local pending
        local function Record()
            local name = Way.BindName()
            if not name or InInstance() or OnTaxi() then return end
            if not (C_Map and type(C_Map.GetBestMapForUnit) == "function" and type(C_Map.GetPlayerMapPosition) == "function") then return end
            local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
            mapID = okMap and Number(mapID) or nil
            if not mapID then return end
            local okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
            if not okPos or type(pos) ~= "table" then return end
            local mx, my = pos.x, pos.y
            if (mx == nil or my == nil) and pos.GetXY then mx, my = pos:GetXY() end
            mx, my = Number(mx), Number(my)
            if not mx or not my then return end
            Way.CharDB().hearthSpot = { name = name, mapID = mapID, x = mx, y = my, v = 2 }
        end
        local watch = CreateFrame("Frame")
        for _, event in ipairs({ "HEARTHSTONE_BOUND", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_ENTERING_WORLD" }) do
            pcall(watch.RegisterEvent, watch, event)
        end
        watch:SetScript("OnEvent", function(_, event, unit, _, spellID)
            local now = (GetTime and GetTime()) or 0
            if event == "HEARTHSTONE_BOUND" then
                if C_Timer and C_Timer.After then C_Timer.After(0.5, Record) else Record() end
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                if unit == "player" and spellID == Way.HEARTH_SPELL then
                    pending = now
                    -- hearthhere (2.0.9): where it was used from. Two seconds
                    -- on, the spot is only taken once the player has really
                    -- been moved: during a loading screen the game still gives
                    -- the old place (that was saved as the hearthstone's
                    -- place), so then the end of the loading screen records it.
                    local okP, fx, fy, _, fc = pcall(UnitPosition, "player")
                    local startX, startY, startC = okP and Number(fx) or nil, okP and Number(fy) or nil, okP and fc or nil
                    if C_Timer and C_Timer.After then
                        C_Timer.After(2, function()
                            if not pending then return end
                            local okN, nx, ny, _, nc = pcall(UnitPosition, "player")
                            nx, ny = okN and Number(nx) or nil, okN and Number(ny) or nil
                            local moved = nx and ny and startX and startY and (nc ~= startC or Yards(nx, ny, startX, startY) > Way.HEARTH_NEAR)
                            if moved then
                                pending = nil
                                Record()
                            end
                        end)
                    end
                end
            elseif event == "PLAYER_ENTERING_WORLD" and pending and now - pending < 60 then
                pending = nil
                Record()
            end
        end)
    end

    -- What to do next on the way to the spot: x, y where the arrow points;
    -- ride: the boat or zeppelin to take (aboard: at its dock or on it);
    -- fly: the flight point to fly to (atMaster: at the flight master);
    -- final: the arrow points at the spot itself. nil: no way known.
    -- way (1.9.2): by regions (Teldrassil's portals and pier), through any
    -- number of rides, and with the hearthstone when it is the quicker way.
    local function Plan(entry, px, py, here, target)
        local gx, gy = target[1], target[2]
        local playerMap, goalMap = PlayerMap(), target.map
        local hereR = Way.Region(here, playerMap, px, py)
        local goalR = Way.Region(target[3], goalMap, gx, gy)
        local plan = { here = hereR }
        if not target[3] or not here or entry.source == "corpse" then -- (corpserun: a ghost walks; no flight, boat or hearthstone)
            plan.final, plan.x, plan.y = true, gx, gy
            return plan
        end
        local p = { px, py, here, region = hereR, map = playerMap }
        local t = { gx, gy, target[3], region = goalR, map = goalMap }
        -- On the boat or zeppelin taken, until well away from where it left.
        local ride = entry.ride
        if ride then
            local from = Ends(ride)
            if from and from.region == hereR and Yards(px, py, from[1], from[2]) <= OFF_DOCK then
                plan.ride, plan.aboard = ride, true
                -- dockaim (2.0.11, M 18 Nov 2026 on Orgrimmar's zeppelin tower,
                -- its two docks 24 yards apart: "it should point at the one
                -- going to undercity here, not just lose the arrow"): at the
                -- tower the arrow keeps pointing at this ride's own dock
                -- (where its zeppelin master stands) until the player stands
                -- there; after that it is gone, as before, for the crossing.
                -- dockback (M, same night: "if i step away the arrow does not
                -- reappear"): walked off the dock again (12 yards), the arrow
                -- is back. Carried away without walking (the place changes
                -- while the character's own speed is 0) is the crossing: no
                -- arrow for the rest of it.
                local d = Yards(px, py, from[1], from[2])
                if type(GetUnitSpeed) == "function" and entry.rideLastX then
                    local ok, speed = pcall(GetUnitSpeed, "player")
                    -- carriedtwice (M: "it worked ... then i tried again and it
                    -- didnt reappear"): stopping after a few steps looked like
                    -- being carried once (moved, speed 0). Carried only counts
                    -- three looks in a row; walking near the dock clears it.
                    if ok and speed == 0 and Yards(px, py, entry.rideLastX, entry.rideLastY) > 1.5 then
                        entry.rideCarriedN = (entry.rideCarriedN or 0) + 1
                        if entry.rideCarriedN >= 3 then entry.rideCarried = true end
                    else
                        entry.rideCarriedN = nil
                        if ok and speed and speed > 0 and d <= 45 then entry.rideCarried = nil end
                    end
                end
                entry.rideLastX, entry.rideLastY = px, py
                -- onboard (M, standing on the docked zeppelin: "the arrow should
                -- understand when im on the zeppelin, its telling me to go
                -- back"): the game does not say one stands on a zeppelin, so
                -- it goes by the side of the dock one is on. Landward: toward
                -- the middle of the tower (halfway to the tower's other dock)
                -- or, at a dock on its own, toward where the player came
                -- from. Past the dock on the far side is aboard: no arrow.
                -- The arrow is back only on the landward side.
                if ride.inland == nil then
                    ride.inland = false
                    for _, other in ipairs(RIDES) do
                        local o = other ~= ride and other.kind ~= "portal" and Ends(other)
                        if o and o[3] == from[3] then
                            local gap = Yards(o[1], o[2], from[1], from[2])
                            if gap > 5 and gap <= 60 then ride.inland = { (o[1] + from[1]) / 2, (o[2] + from[2]) / 2 } break end
                        end
                    end
                end
                local land = ride.inland or (entry.rideFromX and Yards(entry.rideFromX, entry.rideFromY, from[1], from[2]) >= 10 and { entry.rideFromX, entry.rideFromY }) or nil
                local side = land and (Yards(px, py, land[1], land[2]) - Yards(from[1], from[2], land[1], land[2])) or nil
                if d <= 8 or (side and side > 3) then
                    entry.rideAtDock = true
                elseif d >= 12 and not entry.rideCarried and (not side or side < -3) then
                    entry.rideAtDock = nil
                end
                if not entry.rideAtDock and not entry.rideCarried and d <= 45 and ride.kind ~= "portal" then plan.dockX, plan.dockY = from[1], from[2] end
                return plan
            end
            entry.ride, entry.rideAtDock, entry.rideCarried, entry.rideLastX, entry.rideLastY = nil, nil, nil, nil, nil
            entry.rideCarriedN = nil
        end
        local cost = hereR == goalR and Way.Leg(p, t) or nil
        -- flyland (2.0.9, M 16 Nov 2026 in Hillsbrad, the arrow to The
        -- Drowned City switching between "Take the boat to Auberdine" and
        -- "Fly to Sentinel Hill": "I'm in the same continent as the
        -- dungeon, and I have the flight path ... just fly"): on the
        -- place's own continent (and land), when a flight gets there, no
        -- boat, zeppelin or portal is looked for, even a quicker one.
        local flyHere = cost and here == target[3] and Flight(here, px, py, gx, gy, nil, playerMap, goalMap, hereR, goalR) ~= nil
        if hereR ~= goalR or not cost or (cost > Way.RIDE_WORTH and not flyHere) then
            ride, cost = Way.Search(p, t)
            if not cost then return nil end
        else
            ride = nil
        end
        local toR = goalR
        if ride then
            plan.ride = ride
            local from = Ends(ride)
            if ride.kind ~= "portal" and Yards(px, py, from[1], from[2]) <= DOCK then
                if entry.ride ~= ride then entry.rideAtDock, entry.rideFromX, entry.rideFromY = nil, px, py end -- dockaim, onboard
                entry.ride = ride
                plan.aboard = true
                if Yards(px, py, from[1], from[2]) <= 8 then entry.rideAtDock = true end -- dockaim
                if not entry.rideAtDock then plan.dockX, plan.dockY = from[1], from[2] end
                return plan
            end
            gx, gy = from[1], from[2]
            goalMap, toR = ride.from[1], from.region
        else
            plan.final = true
        end
        local a, b = Flight(here, px, py, gx, gy, entry.fly, playerMap, goalMap, hereR, toR)
        -- netwalk (2.1.1, M 20 Nov 2026 at the Talondeep Path, the arrow
        -- saying to walk 7,219 yards to the zeppelin tower with Sun Rock
        -- Retreat's wind rider right there: "there is no way the right call
        -- here is to walk to get the Zeppelin"): the walk was weighed as a
        -- straight line (4,065 yards and its borders) while the way on foot
        -- is the walking net's, round the mountains: no flight chosen, the
        -- flight is weighed again against the net's yards.
        -- The way's cost (for the hearthstone) takes the net's yards too: on
        -- foot to the flight master, or all the way when no flight.
        if hereR == toR and FDJ.WalkNetYards and Yards(px, py, gx, gy) >= FLY_MIN then
            local yards = not a and FDJ.WalkNetYards(px, py, gx, gy, here) or nil
            if yards then
                a, b = Flight(here, px, py, gx, gy, entry.fly, playerMap, goalMap, hereR, toR, yards)
                if not a and cost then cost = cost + math.max(0, yards - Way.Walk(here, px, py, gx, gy)) end
            end
            if a and cost and Yards(px, py, a[1], a[2]) >= FLY_MIN then
                local toMaster = FDJ.WalkNetYards(px, py, a[1], a[2], here)
                if toMaster then cost = cost + math.max(0, toMaster - Way.WalkNode(here, px, py, a, playerMap)) end
            end
        end
        entry.fly = a and { a, b } or nil
        if a then
            plan.final, plan.fly, plan.flyFrom = nil, b, a -- flyfrom (2.1.3)
            if Yards(px, py, a[1], a[2]) <= AT_MASTER then
                plan.atMaster = true
                return plan
            end
            gx, gy = a[1], a[2]
        end
        plan.x, plan.y = gx, gy
        Way.Hearth(entry, plan, p, t, cost)
        return plan
    end

    -- arrowvia: the way to a spot the straight line does not reach
    -- (FDJ.ARROW_VIAS[SpotKey]: a mountain in the way, a Horde post to go
    -- round): the arrow leads to each point of a route in turn, then to
    -- the spot. A spot has one route (a list of points) or several
    -- ({ routes = { list, list } }: from each place players come from); the
    -- route followed is the one whose next point is the quickest to reach
    -- (on foot or by flight), and it is only changed for one whose next
    -- point is much quicker (VIA_SWITCH). A point
    -- counts as passed within VIA_REACHED yards of it, and so does every
    -- point before it on its route (a player joining the route halfway).
    local VIA_REACHED = 30
    local VIA_LEG = 25      -- yards from the way between a point and the next: already past the point
    local VIA_AT_SPOT = 60  -- yards from the spot itself: no point on the way is left
    local VIA_SWITCH = 0.5
    local VIA_JUMP = 200    -- yards moved since the last look (a flight, a hearthstone): the route is chosen afresh
    local function ViaRoutes(entry)
        local vias = FDJ.ARROW_VIAS and entry.spot and FDJ.ARROW_VIAS[SpotKey(entry.spot)]
        if type(vias) ~= "table" then return nil end
        if type(vias.routes) == "table" then return vias.routes end
        return { vias }
    end
    -- Yards from (px, py) to the line between two points.
    local function LegYards(px, py, ax, ay, bx, by)
        local dx, dy = bx - ax, by - ay
        local len2 = dx * dx + dy * dy
        local t = 0
        if len2 > 0 then t = math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / len2)) end
        return Yards(px, py, ax + t * dx, ay + t * dy)
    end
    -- climb (1.8.4): a point passed only once the player is up there (the
    -- fallen cart at Thoradin's Wall). The game gives no height, so a small
    -- grid of the place from walking maps (via.climb: rows of '#' only
    -- raised ground, '.' only plain ground, '+' both or beside it) says it
    -- by where the player stands: the cell under the player, or nil off the
    -- grid.
    local climbFrames = setmetatable({}, { __mode = "k" })
    local function ClimbCell(grid, px, py, here)
        if type(grid) ~= "table" or type(grid.rows) ~= "table" then return nil end
        local f = climbFrames[grid]
        if f == nil then
            local a = SpotWorld({ mapID = grid.mapID, x = grid.x0, y = grid.y0 })
            local b = SpotWorld({ mapID = grid.mapID, x = grid.x0 + grid.step, y = grid.y0 })
            local c = SpotWorld({ mapID = grid.mapID, x = grid.x0, y = grid.y0 + grid.step })
            f = false
            if a and b and c and a[3] == b[3] and a[3] == c[3] then
                local ux, uy, vx, vy = b[1] - a[1], b[2] - a[2], c[1] - a[1], c[2] - a[2]
                local det = ux * vy - uy * vx
                if det ~= 0 then f = { a[1], a[2], ux, uy, vx, vy, det, a[3] } end
            end
            climbFrames[grid] = f
        end
        if not f or f[8] ~= here then return nil end
        local dx, dy = px - f[1], py - f[2]
        local i = math.floor((dx * f[6] - dy * f[5]) / f[7] + 0.5) + 1
        local j = math.floor((f[3] * dy - f[4] * dx) / f[7] + 0.5) + 1
        local line = grid.rows[j]
        if type(line) ~= "string" or i < 1 or i > #line then return nil end
        return line:sub(i, i)
    end

    -- The route's next point for this player: its world position and the
    -- point; nil when the route is walked or not for this faction. A point
    -- is passed within VIA_REACHED yards of it, or VIA_LEG yards of the way
    -- from it to the route's next point. A climb point only within its
    -- reach (yards) or on its grid's raised ground; it is taken back on its
    -- grid's plain ground and after a jump (the spirit healer, a flight).
    -- ucelevator (2.0.7): down in Undercity, a way that leads out of the city
    -- goes up one of the elevators first (east and west of the Trade
    -- Quarter's ring): the arrow points at the nearer one, not straight
    -- through the rock at the zeppelin tower. Not when the way stays in the
    -- city (a quest giver there, the bat handler). Up in the ruins (the
    -- same map) it is the straight line as before: outdoors, in the
    -- subzone named Ruins of Lordaeron, in the hall north of the tomb, or
    -- for a minute after standing at an elevator (riding it up).
    Way.UC = { map = 1458, center = { 0.6600, 0.4405 }, lifts = { { 0.6069, 0.4405 }, { 0.7136, 0.4405 } }, ruinsArea = 153 }
    function Way.UndercityLift(entry, plan, px, py, here, target)
        local UC = Way.UC
        if PlayerMap() ~= UC.map then entry.ucTop, entry.ucRode = nil, nil return nil end
        local c = SpotWorld({ mapID = UC.map, x = UC.center[1], y = UC.center[2] })
        if not c or c[3] ~= here then return nil end
        if not Indoors() then entry.ucTop = true return nil end
        local now = (GetTime and GetTime()) or 0
        local d, north = Yards(px, py, c[1], c[2]), px - c[1]
        -- the subzone's name, where the game gives it
        if C_Map and type(C_Map.GetAreaInfo) == "function" and type(GetSubZoneText) == "function" then
            local okA, ruins = pcall(C_Map.GetAreaInfo, UC.ruinsArea)
            local okS, sub = pcall(GetSubZoneText)
            if okA and okS and type(ruins) == "string" and ruins ~= "" and type(sub) == "string"
                and not (type(issecretvalue) == "function" and (issecretvalue(sub) or issecretvalue(ruins))) and sub == ruins then
                entry.ucTop = true
            end
        end
        if entry.ucTop then
            if d > 70 and north < 70 then entry.ucTop = nil end -- far from the tomb, not towards the throne room: down in the city
        elseif north >= 88 and north <= 104 and math.abs(py - c[2]) < 12 then
            entry.ucTop = true
        end
        if entry.ucTop then return nil end
        -- does the way stay in the city?
        if plan.final and target and target.map == UC.map then return nil end
        if plan.fly and plan.x and Yards(plan.x, plan.y, c[1], c[2]) <= 80 then return nil end
        local best, bestD
        for _, lift in ipairs(UC.lifts) do
            local w = SpotWorld({ mapID = UC.map, x = lift[1], y = lift[2] })
            if w then
                local ld = Yards(px, py, w[1], w[2])
                if not bestD or ld < bestD then best, bestD = w, ld end
            end
        end
        if not best then return nil end
        if bestD <= 14 then entry.ucRode = now return best end
        if entry.ucRode and now - entry.ucRode < 60 then return nil end
        return best
    end
    -- ucway (2.0.11, M 18 Nov 2026 on the road from the zeppelin tower, the
    -- arrow to a quest giver down in Undercity: "its not understanding the
    -- road to undercity, im standing here and its telling me to go back"):
    -- the walking net knows no elevators, so its only way down into the city
    -- was round by the sewers. To a spot down in the city, from outside or
    -- from up in the ruins, the way is the front door: the ruins' gate, the
    -- throne room, then the nearer elevator down. The gate and the throne
    -- room lie straight north of the tomb the city's map is centred on (the
    -- throne room hall 88 to 104 yards north of it, as above; the gate by
    -- the Tirisfal map, 61.9, 65.1). Returns the point to aim at, and
    -- whether the walking net may lead to it (outside the walls).
    Way.UC.gate, Way.UC.throne = { 0.6600, 0.0124 }, { 0.6600, 0.2858 }
    function Way.UndercityIn(entry, plan, px, py, here, target)
        local UC = Way.UC
        if not (plan and plan.final and target and target.map == UC.map) then return nil end
        if PlayerMap() == UC.map and not entry.ucTop then return nil end -- down in the city already
        local c = SpotWorld({ mapID = UC.map, x = UC.center[1], y = UC.center[2] })
        if not c or c[3] ~= here or target[3] ~= here then return nil end
        -- a spot up in the ruins themselves (not down in the city): as before
        if Yards(target[1], target[2], c[1], c[2]) > 330 then return nil end
        local north, side = px - c[1], math.abs(py - c[2])
        -- ucdown (M, down in the Apothecarium, the quest giver on his left and
        -- the arrow sending him 1,850 yards the other way): parts of the city
        -- below count as outdoors to the game, which looked like standing up
        -- in the ruins. On the city's map, up in the ruins is only their own
        -- strip (the tomb, the throne room, the courtyard: within 75 yards
        -- east or west of the middle, not south of the tomb); anywhere else
        -- is down in the city. Having stood at an elevator, it is the ride
        -- down for the next minute and a half.
        if PlayerMap() == UC.map then
            if side > 75 or north < -30 then return nil end
            local now = (GetTime and GetTime()) or 0
            if entry.ucDownAt and now - entry.ucDownAt < 90 then return nil end
        end
        local gate = SpotWorld({ mapID = UC.map, x = UC.gate[1], y = UC.gate[2] })
        local throne = SpotWorld({ mapID = UC.map, x = UC.throne[1], y = UC.throne[2] })
        if not gate or not throne then return nil end
        if north > (gate[1] - c[1]) + 10 or (side > 45 and north > 110) or north < -60 or side > 150 then
            return gate, true -- outside the walls: to the gate, along the roads
        end
        if north > (throne[1] - c[1]) + 6 then return throne, false end
        local best, bestD
        for _, lift in ipairs(UC.lifts) do
            local w = SpotWorld({ mapID = UC.map, x = lift[1], y = lift[2] })
            if w then
                local ld = Yards(px, py, w[1], w[2])
                if not bestD or ld < bestD then best, bestD = w, ld end
            end
        end
        if best and bestD <= 14 then entry.ucDownAt = (GetTime and GetTime()) or 0 return nil end -- ucdown: on the elevator
        return best, false
    end
    -- ucroyal (2.0.12): up in the ruins (as Way.UndercityIn tells it), not down in the city
    function Way.UCUp(entry, px, py)
        local UC = Way.UC
        if PlayerMap() ~= UC.map then return false end
        -- (ucTop alone is not enough: the Apothecarium and other parts of the
        -- city below count as outdoors to the game, which sets it; M 18 Nov
        -- 2026, still the straight line at the door)
        if not entry.ucTop then return false end
        local c = SpotWorld({ mapID = UC.map, x = UC.center[1], y = UC.center[2] })
        if not c then return false end
        local north, side = px - c[1], math.abs(py - c[2])
        if side > 75 or north < -30 then return false end
        local now = (GetTime and GetTime()) or 0
        if entry.ucDownAt and now - entry.ucDownAt < 90 then return false end
        return true
    end
    -- orgroads (2.0.8): inside Orgrimmar the arrow follows the roads. The
    -- straight line to Borstan in the Drag from the Valley of Strength went
    -- through the cliff (M, 15 Nov 2026). The city's roads from the patrol
    -- paths drawn on M's Orgrimmar map (orange lines, walked ground: the Valley of Strength's
    -- ring, the Drag, the north road, the west road, the Cleft of Shadow),
    -- read off M's map screenshot; the Valleys of Honor, Wisdom and Spirits
    -- and the two gates from the map's art (rougher). The arrow aims at the
    -- next corner of the shortest way along them; the yards are the whole
    -- way. A way that leaves the city (a zeppelin, a spot outside) goes to
    -- the gate first. Only while the player is on the city's map.
    Way.ROADS = {
        [1454] = {
            near = 220, -- yards: further than this from every road is not in the city
            gates = { "G2", "P6" },
            nodes = {
                S1 = { 0.4945, 0.6012 }, S2 = { 0.5041, 0.6263 }, S3 = { 0.5089, 0.6371 }, S4 = { 0.5041, 0.6515 }, S5 = { 0.4873, 0.6587 },
                S6 = { 0.4729, 0.6479 }, S7 = { 0.4681, 0.6407 }, R1 = { 0.4825, 0.5814 }, R2 = { 0.4681, 0.5796 }, R3 = { 0.4441, 0.5904 },
                R4 = { 0.4297, 0.6120 }, R5 = { 0.4201, 0.6479 }, R6 = { 0.4225, 0.6731 }, R7 = { 0.4393, 0.7091 }, R8 = { 0.4537, 0.7523 },
                R9 = { 0.4729, 0.7847 }, R10 = { 0.5041, 0.7955 }, R11 = { 0.5209, 0.7883 }, R12 = { 0.5281, 0.7667 }, R13 = { 0.5209, 0.7379 },
                R14 = { 0.5089, 0.7055 }, V1 = { 0.5173, 0.6767 }, G1 = { 0.5185, 0.8171 }, G2 = { 0.5233, 0.8459 }, D1 = { 0.5137, 0.5796 },
                D2 = { 0.5329, 0.5670 }, D3 = { 0.5568, 0.5760 }, D4 = { 0.5784, 0.5742 }, D5 = { 0.5976, 0.5580 }, D6 = { 0.6084, 0.5364 },
                D7 = { 0.6096, 0.4932 }, D8 = { 0.6108, 0.4500 }, D9 = { 0.6144, 0.4032 }, H1 = { 0.6240, 0.4014 }, H2 = { 0.6750, 0.3450 },
                H3 = { 0.7230, 0.3000 }, H4 = { 0.7780, 0.2250 }, N1 = { 0.5928, 0.3924 }, N2 = { 0.5760, 0.3780 }, N3 = { 0.5544, 0.3600 },
                N4 = { 0.5329, 0.3528 }, N5 = { 0.4969, 0.3582 }, N6 = { 0.4585, 0.3618 }, N7 = { 0.4393, 0.3636 }, N8 = { 0.4309, 0.3816 },
                N9 = { 0.4297, 0.4032 }, T1 = { 0.4000, 0.3650 }, T2 = { 0.3570, 0.3670 }, W1 = { 0.4129, 0.4320 }, W2 = { 0.4010, 0.4572 },
                W3 = { 0.3938, 0.4932 }, W4 = { 0.3890, 0.5220 }, W5 = { 0.3830, 0.5472 }, W6 = { 0.3866, 0.5760 }, W7 = { 0.4010, 0.6228 },
                W8 = { 0.4106, 0.6415 }, W9 = { 0.4177, 0.6695 }, W10 = { 0.4177, 0.6875 }, W11 = { 0.4010, 0.7127 }, W12 = { 0.3770, 0.7379 },
                F1 = { 0.4441, 0.6415 }, C1 = { 0.5736, 0.3996 }, C2 = { 0.5640, 0.4086 }, C3 = { 0.5448, 0.4032 }, C4 = { 0.5329, 0.4050 },
                C5 = { 0.5269, 0.4212 }, C6 = { 0.5245, 0.4464 }, C7 = { 0.5209, 0.4572 }, C8 = { 0.4969, 0.4824 }, C9 = { 0.4729, 0.5004 },
                C10 = { 0.4489, 0.5184 }, C11 = { 0.4417, 0.5328 }, C12 = { 0.4465, 0.5472 }, C13 = { 0.4393, 0.5616 }, C14 = { 0.4201, 0.5724 },
                C15 = { 0.4082, 0.5580 }, P1 = { 0.3190, 0.7190 }, P2 = { 0.2940, 0.6590 }, P3 = { 0.2790, 0.5910 }, P4 = { 0.2390, 0.5690 },
                P5 = { 0.2000, 0.5910 }, P6 = { 0.1800, 0.6050 },
                -- orgtower (2.0.9, M 16 Nov 2026 in the Valley of Strength at
                -- 48.5, 66.0, the wind rider tower on his right and the arrow
                -- sending him back round the city): the ramp up the tower
                -- starts at S7, at the valley's west end (the walking map has
                -- its floors climbing there, 35 to 61 yards up); Doras on top.
                FM = { 0.4512, 0.6392 },
                -- orgauction (2.0.10, M 17 Nov 2026 on the road to the
                -- auction house, the arrow sending him back round by the
                -- Drag): the road east from the Valley of Strength into the
                -- auction house, its only way in (the Forever client's
                -- walking map with its floors, the navigation grid, read
                -- as data: 82 yards from 51.5, 64.3 to the auctioneers).
                AH1 = { 0.5263, 0.6469 }, AH2 = { 0.5530, 0.6469 },
            },
            edges = {
                { "S1", "S2" }, { "S2", "S3" }, { "S3", "S4" }, { "S4", "S5" }, { "S5", "S6" }, { "S6", "S7" }, { "S1", "R1" }, { "R1", "R2" },
                { "R2", "R3" }, { "R3", "R4" }, { "R4", "R5" }, { "R5", "R6" }, { "R6", "R7" }, { "R7", "R8" }, { "R8", "R9" }, { "R9", "R10" },
                { "R10", "R11" }, { "R11", "R12" }, { "R12", "R13" }, { "R13", "R14" }, { "R14", "V1" }, { "V1", "S3" }, { "R10", "G1" }, { "G1", "G2" },
                { "R11", "G1" }, { "S1", "D1" }, { "D1", "D2" }, { "D2", "D3" }, { "D3", "D4" }, { "D4", "D5" }, { "D5", "D6" }, { "D6", "D7" },
                { "D7", "D8" }, { "D8", "D9" }, { "D9", "H1" }, { "H1", "H2" }, { "H2", "H3" }, { "H3", "H4" }, { "D9", "N1" }, { "N1", "N2" },
                { "N2", "N3" }, { "N3", "N4" }, { "N4", "N5" }, { "N5", "N6" }, { "N6", "N7" }, { "N7", "N8" }, { "N8", "N9" }, { "N7", "T1" },
                { "T1", "T2" }, { "N9", "W1" }, { "W1", "W2" }, { "W2", "W3" }, { "W3", "W4" }, { "W4", "W5" }, { "W5", "W6" }, { "W6", "W7" },
                { "W7", "W8" }, { "W8", "W9" }, { "W9", "W10" }, { "W10", "W11" }, { "W11", "W12" }, { "W8", "R5" }, { "R5", "F1" }, { "W9", "R6" },
                { "N2", "C1" }, { "C1", "C2" }, { "C2", "C3" }, { "C3", "C4" }, { "C4", "C5" }, { "C5", "C6" }, { "C6", "C7" }, { "C7", "C8" },
                { "C8", "C9" }, { "C9", "C10" }, { "C10", "C11" }, { "C11", "C12" }, { "C12", "C13" }, { "C13", "C14" }, { "C14", "C15" }, { "C15", "W4" },
                { "W12", "P1" }, { "P1", "P2" }, { "P2", "P3" }, { "P3", "P4" }, { "P4", "P5" }, { "P5", "P6" },
                { "S7", "FM" }, -- orgtower (2.0.9)
                { "S3", "AH1" }, { "S4", "AH1" }, { "AH1", "AH2" }, -- orgauction (2.0.10)
            },
        },
        -- bbroads (2.0.9, M 16 Nov 2026 on Booty Bay's west dock, the arrow
        -- to Scooty pointing at the cliff, 360 yards round: "I don't think it
        -- understands Booty Bay's structure"): the town's docks, stairs and
        -- piers, walked between its NPCs and the tunnel north on the
        -- Forever client's walking map with its floors (the navigation grid,
        -- read as data), cut down to their corners. Rides (the boat) leave
        -- from inside the town (docks): not through the tunnel.
        [1434] = {
            near = 60, docks = true,
            gates = { "GT" },
            nodes = {
                B1 = { 0.2791, 0.7669 }, B2 = { 0.2782, 0.7684 }, B3 = { 0.2797, 0.7651 }, B4 = { 0.2782, 0.7669 }, B5 = { 0.3088, 0.6934 },
                GT = { 0.3079, 0.6866 }, B7 = { 0.3091, 0.6983 }, B8 = { 0.3098, 0.6959 }, B9 = { 0.2646, 0.7365 }, B10 = { 0.2662, 0.7365 },
                B11 = { 0.2660, 0.7354 }, B12 = { 0.2646, 0.7349 }, B13 = { 0.2631, 0.7365 }, B14 = { 0.2627, 0.7349 }, B15 = { 0.2746, 0.7757 },
                B16 = { 0.2746, 0.7739 }, B17 = { 0.2696, 0.7683 }, B18 = { 0.2713, 0.7698 }, B19 = { 0.2678, 0.7656 }, B20 = { 0.2850, 0.7066 },
                B21 = { 0.2834, 0.7052 }, B22 = { 0.2869, 0.7071 }, B23 = { 0.2785, 0.7655 }, B24 = { 0.2800, 0.7634 }, B25 = { 0.2782, 0.7666 },
                B26 = { 0.3092, 0.7013 }, B27 = { 0.3079, 0.6974 }, B28 = { 0.2714, 0.7762 }, B29 = { 0.2713, 0.7777 }, B30 = { 0.2714, 0.7763 },
                B31 = { 0.2726, 0.7757 }, B32 = { 0.2700, 0.7742 }, B33 = { 0.2728, 0.7739 }, B34 = { 0.2885, 0.7501 }, B35 = { 0.2885, 0.7481 },
                B36 = { 0.2849, 0.7421 }, B37 = { 0.2896, 0.7502 }, B38 = { 0.2886, 0.7526 }, B39 = { 0.2833, 0.7402 }, B40 = { 0.2799, 0.7398 },
                B41 = { 0.2798, 0.7742 }, B42 = { 0.2782, 0.7759 }, B43 = { 0.2817, 0.7734 }, B44 = { 0.2792, 0.7706 }, B45 = { 0.2785, 0.7708 },
                B46 = { 0.2794, 0.7689 }, B47 = { 0.2824, 0.7657 }, B48 = { 0.2814, 0.7649 }, B49 = { 0.2816, 0.7632 }, B50 = { 0.2833, 0.7686 },
                B51 = { 0.2797, 0.7659 }, B52 = { 0.2781, 0.7682 }, B53 = { 0.2987, 0.7224 }, B54 = { 0.2985, 0.7240 }, B55 = { 0.3040, 0.7224 },
                B56 = { 0.2971, 0.7220 }, B57 = { 0.2896, 0.7545 }, B58 = { 0.3095, 0.7116 }, B59 = { 0.3092, 0.7167 }, B60 = { 0.3057, 0.7219 },
                B61 = { 0.3085, 0.7091 }, B62 = { 0.3085, 0.7066 }, B63 = { 0.3094, 0.7062 }, B64 = { 0.2852, 0.7578 }, B65 = { 0.2870, 0.7556 },
                B66 = { 0.2824, 0.7587 }, B67 = { 0.2821, 0.7434 }, B68 = { 0.2820, 0.7497 }, B69 = { 0.2681, 0.7356 }, B70 = { 0.2696, 0.7375 },
                B71 = { 0.2682, 0.7374 }, B72 = { 0.2693, 0.7356 }, B73 = { 0.2954, 0.7216 }, B74 = { 0.2942, 0.7193 }, B75 = { 0.2942, 0.7228 },
                B76 = { 0.2954, 0.7242 }, B77 = { 0.2876, 0.7542 }, B78 = { 0.2795, 0.7708 }, B79 = { 0.2798, 0.7711 }, B80 = { 0.2613, 0.7349 },
                B81 = { 0.2693, 0.7738 }, B82 = { 0.2712, 0.7401 }, B83 = { 0.2710, 0.7381 }, B84 = { 0.2730, 0.7416 }, B85 = { 0.2729, 0.7405 },
                B86 = { 0.2697, 0.7397 }, B87 = { 0.2764, 0.7687 }, B88 = { 0.2675, 0.7637 }, B89 = { 0.2660, 0.7652 }, B90 = { 0.2666, 0.7633 },
                B91 = { 0.2726, 0.7385 }, B92 = { 0.2759, 0.7405 }, B93 = { 0.2804, 0.7032 }, B94 = { 0.2817, 0.7038 }, B95 = { 0.2868, 0.7679 },
                B96 = { 0.2846, 0.7698 }, B97 = { 0.2972, 0.7242 }, B98 = { 0.3040, 0.7238 }, B99 = { 0.2739, 0.7405 }, B100 = { 0.2745, 0.7422 },
                B101 = { 0.2831, 0.7757 }, B102 = { 0.2887, 0.7092 }, B103 = { 0.2769, 0.7689 }, B104 = { 0.2767, 0.7681 }, B105 = { 0.2710, 0.7700 },
                B106 = { 0.2712, 0.7689 }, B107 = { 0.2697, 0.7713 }, B108 = { 0.2726, 0.7689 }, B109 = { 0.2762, 0.7704 }, B110 = { 0.2733, 0.7718 },
                B111 = { 0.2729, 0.7703 }, B112 = { 0.2729, 0.7738 }, B113 = { 0.2745, 0.7705 }, B114 = { 0.2794, 0.7480 }, B115 = { 0.2780, 0.7460 },
                B116 = { 0.2799, 0.7499 }, B117 = { 0.2785, 0.7477 }, B118 = { 0.2745, 0.7689 }, B119 = { 0.2733, 0.7689 }, B120 = { 0.2834, 0.7502 },
                B121 = { 0.2811, 0.7504 }, B122 = { 0.2767, 0.7765 }, B123 = { 0.2772, 0.7779 }, B124 = { 0.2739, 0.7747 }, B125 = { 0.2715, 0.7762 },
                B126 = { 0.2698, 0.7735 }, B127 = { 0.2687, 0.7708 }, B128 = { 0.2700, 0.7689 }, B129 = { 0.2770, 0.7418 }, B130 = { 0.2782, 0.7400 },
                B131 = { 0.2780, 0.7421 }, B132 = { 0.2766, 0.7399 }, B133 = { 0.2764, 0.7739 }, B134 = { 0.2778, 0.7747 }, B135 = { 0.2811, 0.7728 },
                B136 = { 0.2817, 0.7710 }, B137 = { 0.2743, 0.7745 }, B138 = { 0.2659, 0.7623 }, B139 = { 0.2667, 0.7610 }, B140 = { 0.2814, 0.7549 },
                B141 = { 0.2791, 0.7502 }, B142 = { 0.2795, 0.7402 }, B143 = { 0.2817, 0.7584 }, B144 = { 0.2844, 0.7571 }, B145 = { 0.2837, 0.7528 },
                B146 = { 0.2815, 0.7607 }, B147 = { 0.2834, 0.7704 }, B148 = { 0.2795, 0.7376 }, B149 = { 0.2844, 0.7685 }, B150 = { 0.2952, 0.7261 },
                B151 = { 0.2922, 0.7302 }, B152 = { 0.2824, 0.7307 }, B153 = { 0.2968, 0.7258 }, B154 = { 0.2767, 0.7448 }, B155 = { 0.2847, 0.7512 },
                B156 = { 0.2748, 0.7707 }, B157 = { 0.2752, 0.7689 }, B158 = { 0.2769, 0.7669 }, B159 = { 0.2886, 0.7071 }, B160 = { 0.3094, 0.7039 },
                B161 = { 0.2772, 0.7669 }, B162 = { 0.2687, 0.7395 }, B163 = { 0.2778, 0.7728 }, B164 = { 0.2821, 0.7052 }, B165 = { 0.2778, 0.7708 },
                B166 = { 0.3085, 0.7032 }, B167 = { 0.2800, 0.7781 }, B168 = { 0.2814, 0.7806 }, B169 = { 0.2648, 0.7326 },
            },
            edges = {
                { "B1", "B2" }, { "B1", "B3" }, { "B1", "B4" }, { "B2", "B4" }, { "B2", "B44" }, { "B2", "B45" }, { "B2", "B46" }, { "B2", "B87" },
                { "B3", "B23" }, { "B3", "B24" }, { "B4", "B158" }, { "B5", "GT" }, { "B5", "B7" }, { "B5", "B8" }, { "GT", "B27" }, { "B7", "B8" },
                { "B7", "B26" }, { "B7", "B27" }, { "B9", "B10" }, { "B9", "B11" }, { "B9", "B12" }, { "B9", "B13" }, { "B10", "B11" }, { "B10", "B12" },
                { "B10", "B69" }, { "B10", "B71" }, { "B11", "B12" }, { "B11", "B69" }, { "B11", "B71" }, { "B12", "B14" }, { "B12", "B169" }, { "B13", "B14" },
                { "B14", "B80" }, { "B15", "B16" }, { "B16", "B110" }, { "B16", "B133" }, { "B16", "B137" }, { "B17", "B18" }, { "B17", "B19" }, { "B18", "B111" },
                { "B19", "B88" }, { "B19", "B89" }, { "B19", "B90" }, { "B20", "B21" }, { "B20", "B22" }, { "B21", "B94" }, { "B21", "B164" }, { "B22", "B102" },
                { "B22", "B159" }, { "B23", "B24" }, { "B23", "B25" }, { "B24", "B146" }, { "B25", "B51" }, { "B25", "B52" }, { "B25", "B104" }, { "B25", "B161" },
                { "B26", "B160" }, { "B26", "B166" }, { "B28", "B29" }, { "B28", "B30" }, { "B28", "B31" }, { "B28", "B32" }, { "B28", "B33" }, { "B29", "B30" },
                { "B30", "B31" }, { "B30", "B32" }, { "B31", "B33" }, { "B31", "B112" }, { "B32", "B81" }, { "B33", "B110" }, { "B33", "B112" }, { "B33", "B113" },
                { "B34", "B35" }, { "B34", "B37" }, { "B34", "B38" }, { "B35", "B36" }, { "B36", "B39" }, { "B38", "B57" }, { "B38", "B65" }, { "B38", "B77" },
                { "B39", "B40" }, { "B40", "B130" }, { "B40", "B142" }, { "B40", "B148" }, { "B41", "B42" }, { "B41", "B43" }, { "B42", "B122" }, { "B42", "B167" },
                { "B43", "B101" }, { "B43", "B147" }, { "B44", "B45" }, { "B44", "B46" }, { "B45", "B163" }, { "B47", "B48" }, { "B47", "B49" }, { "B47", "B50" },
                { "B48", "B49" }, { "B48", "B51" }, { "B49", "B51" }, { "B49", "B66" }, { "B50", "B96" }, { "B50", "B147" }, { "B51", "B52" }, { "B52", "B79" },
                { "B52", "B103" }, { "B52", "B104" }, { "B53", "B54" }, { "B53", "B55" }, { "B53", "B56" }, { "B54", "B97" }, { "B54", "B98" }, { "B55", "B60" },
                { "B55", "B98" }, { "B56", "B73" }, { "B56", "B76" }, { "B58", "B59" }, { "B58", "B61" }, { "B58", "B63" }, { "B59", "B60" }, { "B60", "B98" },
                { "B61", "B62" }, { "B62", "B63" }, { "B63", "B160" }, { "B64", "B65" }, { "B64", "B66" }, { "B65", "B77" }, { "B67", "B68" }, { "B68", "B120" },
                { "B68", "B121" }, { "B69", "B70" }, { "B69", "B71" }, { "B69", "B72" }, { "B70", "B71" }, { "B70", "B72" }, { "B70", "B83" }, { "B70", "B86" },
                { "B71", "B86" }, { "B71", "B162" }, { "B73", "B74" }, { "B73", "B75" }, { "B73", "B76" }, { "B74", "B102" }, { "B75", "B76" }, { "B76", "B97" },
                { "B76", "B150" }, { "B78", "B79" }, { "B79", "B136" }, { "B82", "B83" }, { "B82", "B84" }, { "B82", "B85" }, { "B82", "B86" }, { "B83", "B91" },
                { "B84", "B85" }, { "B84", "B99" }, { "B84", "B100" }, { "B85", "B100" }, { "B86", "B162" }, { "B87", "B156" }, { "B87", "B157" }, { "B87", "B158" },
                { "B88", "B89" }, { "B88", "B90" }, { "B89", "B90" }, { "B90", "B139" }, { "B91", "B92" }, { "B92", "B129" }, { "B92", "B132" }, { "B93", "B94" },
                { "B94", "B164" }, { "B95", "B96" }, { "B96", "B147" }, { "B97", "B153" }, { "B99", "B100" }, { "B100", "B154" }, { "B102", "B159" }, { "B103", "B104" },
                { "B103", "B109" }, { "B104", "B113" }, { "B104", "B118" }, { "B104", "B161" }, { "B105", "B106" }, { "B105", "B107" }, { "B105", "B108" }, { "B106", "B108" },
                { "B106", "B128" }, { "B107", "B126" }, { "B107", "B127" }, { "B107", "B128" }, { "B109", "B113" }, { "B109", "B133" }, { "B109", "B165" }, { "B110", "B111" },
                { "B110", "B112" }, { "B110", "B113" }, { "B111", "B113" }, { "B111", "B118" }, { "B111", "B119" }, { "B112", "B137" }, { "B113", "B118" }, { "B114", "B115" },
                { "B114", "B116" }, { "B114", "B117" }, { "B115", "B117" }, { "B115", "B154" }, { "B116", "B117" }, { "B116", "B121" }, { "B116", "B140" }, { "B116", "B141" },
                { "B118", "B119" }, { "B120", "B145" }, { "B120", "B155" }, { "B121", "B140" }, { "B122", "B123" }, { "B122", "B124" }, { "B124", "B125" }, { "B125", "B126" },
                { "B129", "B130" }, { "B129", "B131" }, { "B129", "B132" }, { "B130", "B131" }, { "B130", "B132" }, { "B130", "B142" }, { "B130", "B148" }, { "B131", "B142" },
                { "B133", "B134" }, { "B133", "B137" }, { "B134", "B135" }, { "B135", "B136" }, { "B136", "B149" }, { "B138", "B139" }, { "B140", "B143" }, { "B143", "B144" },
                { "B143", "B146" }, { "B144", "B145" }, { "B145", "B155" }, { "B148", "B152" }, { "B150", "B151" }, { "B150", "B153" }, { "B151", "B152" }, { "B156", "B157" },
                { "B160", "B166" }, { "B167", "B168" },
            },
        },
        -- dalroads (2.0.9, M 16 Nov 2026 on Dalaran's great stairs, the arrow
        -- to Abra Cadabra pointing left, at the wall: "I don't think he
        -- understands that I'm on the stairs ... without understanding the
        -- buildings"): the city's streets, stairs and bridges, walked
        -- between its NPCs and the foot of the great stairs (the way out) on
        -- the Forever client's walking map with its floors (the navigation grid,
        -- read as data), cut down to their corners.
        [1416] = {
            near = 45, targetNear = 160, -- (a place this near the streets is in the city: no way out by the stairs)
            gates = { "DG" },
            nodes = {
                D1 = { 0.1958, 0.6846 }, D2 = { 0.2016, 0.6861 }, D3 = { 0.1985, 0.6894 }, D4 = { 0.1662, 0.6695 }, D5 = { 0.1617, 0.6714 },
                D6 = { 0.1692, 0.6609 }, D7 = { 0.1728, 0.6694 }, D8 = { 0.1745, 0.6460 }, D9 = { 0.1793, 0.6426 }, D10 = { 0.1705, 0.6421 },
                D11 = { 0.1744, 0.6367 }, D12 = { 0.1250, 0.5274 }, D13 = { 0.1253, 0.6457 }, D14 = { 0.1254, 0.6376 }, D15 = { 0.1318, 0.6420 },
                D16 = { 0.1986, 0.7590 }, D17 = { 0.1972, 0.7459 }, D18 = { 0.1158, 0.5949 }, D19 = { 0.1377, 0.5936 }, D20 = { 0.1434, 0.6012 },
                D21 = { 0.1451, 0.5920 }, D22 = { 0.1548, 0.6985 }, D23 = { 0.1474, 0.6972 }, D24 = { 0.1547, 0.7055 }, D25 = { 0.2010, 0.7908 },
                D26 = { 0.1982, 0.7816 }, D27 = { 0.1362, 0.6680 }, D28 = { 0.1312, 0.6722 }, D29 = { 0.1435, 0.6688 }, D30 = { 0.1927, 0.6241 },
                D31 = { 0.1906, 0.6882 }, D32 = { 0.1645, 0.6805 }, D33 = { 0.1704, 0.6799 }, D34 = { 0.1257, 0.5409 }, D35 = { 0.1319, 0.5472 },
                D36 = { 0.1204, 0.5353 }, D37 = { 0.1269, 0.5543 }, D38 = { 0.1279, 0.6686 }, D39 = { 0.1901, 0.6749 }, D40 = { 0.1941, 0.6680 },
                D41 = { 0.1889, 0.6657 }, D42 = { 0.1733, 0.7131 }, D43 = { 0.1657, 0.7072 }, D44 = { 0.1987, 0.7718 }, D45 = { 0.1499, 0.5596 },
                D46 = { 0.1401, 0.5489 }, D47 = { 0.1542, 0.5667 }, D48 = { 0.1475, 0.6462 }, D49 = { 0.1511, 0.6564 }, D50 = { 0.1452, 0.6528 },
                D51 = { 0.1515, 0.6396 }, D52 = { 0.1178, 0.5717 }, D53 = { 0.1222, 0.5813 }, D54 = { 0.1309, 0.5577 }, D55 = { 0.1364, 0.5535 },
                D56 = { 0.1512, 0.6686 }, D57 = { 0.1810, 0.6575 }, D58 = { 0.1905, 0.6329 }, D59 = { 0.1392, 0.6968 }, D60 = { 0.1331, 0.6995 },
                D61 = { 0.1329, 0.6904 }, D62 = { 0.1409, 0.5567 }, D63 = { 0.2047, 0.6908 }, D64 = { 0.2086, 0.6948 }, D65 = { 0.1859, 0.7041 },
                D66 = { 0.1867, 0.7145 }, D67 = { 0.1865, 0.6978 }, D68 = { 0.1465, 0.6112 }, D69 = { 0.1407, 0.6113 }, D70 = { 0.1308, 0.6448 },
                D71 = { 0.1282, 0.6591 }, D72 = { 0.1900, 0.6429 }, D73 = { 0.1957, 0.6439 }, D74 = { 0.1911, 0.6522 }, D75 = { 0.1463, 0.6373 },
                D76 = { 0.1451, 0.5313 }, D77 = { 0.1368, 0.5345 }, D78 = { 0.1410, 0.6911 }, D79 = { 0.2094, 0.6368 }, D80 = { 0.2060, 0.6447 },
                D81 = { 0.1095, 0.6267 }, D82 = { 0.1138, 0.6334 }, D83 = { 0.1449, 0.6815 }, D84 = { 0.1498, 0.5687 }, D85 = { 0.2037, 0.7834 },
                D86 = { 0.1376, 0.6392 }, D87 = { 0.1510, 0.6312 }, D88 = { 0.1963, 0.7323 }, D89 = { 0.2011, 0.7447 }, D90 = { 0.1594, 0.5949 },
                D91 = { 0.1521, 0.6058 }, D92 = { 0.1596, 0.7199 }, D93 = { 0.1578, 0.7350 }, D94 = { 0.1375, 0.5437 }, D95 = { 0.1858, 0.6824 },
                D96 = { 0.1748, 0.6772 }, D97 = { 0.2093, 0.6549 }, D98 = { 0.2048, 0.6574 }, D99 = { 0.2044, 0.6535 }, D100 = { 0.2057, 0.8092 },
                D101 = { 0.1815, 0.7107 }, D102 = { 0.1527, 0.5750 }, D103 = { 0.1488, 0.7062 }, D104 = { 0.1594, 0.7102 }, D105 = { 0.1922, 0.6595 },
                D106 = { 0.1964, 0.6541 }, D107 = { 0.1431, 0.6581 }, D108 = { 0.1635, 0.5567 }, D109 = { 0.1602, 0.7400 }, D110 = { 0.1998, 0.6549 },
                D111 = { 0.1340, 0.6838 }, D112 = { 0.1277, 0.6928 }, D113 = { 0.1229, 0.6833 }, D114 = { 0.1190, 0.6892 }, D115 = { 0.1569, 0.6363 },
                D116 = { 0.1613, 0.6360 }, D117 = { 0.1272, 0.5815 }, D118 = { 0.1362, 0.5688 }, D119 = { 0.1449, 0.5652 }, D120 = { 0.1317, 0.5949 },
                D121 = { 0.1275, 0.5649 }, D122 = { 0.1410, 0.6816 }, D123 = { 0.1472, 0.6895 }, D124 = { 0.1781, 0.6053 }, D125 = { 0.1116, 0.5815 },
                D126 = { 0.1840, 0.6488 }, D127 = { 0.1224, 0.5655 }, D128 = { 0.1676, 0.7400 }, D129 = { 0.1644, 0.5748 }, D130 = { 0.2259, 0.7407 },
                D131 = { 0.2290, 0.6438 }, D132 = { 0.2277, 0.6536 }, D133 = { 0.2227, 0.6440 }, D134 = { 0.2134, 0.6503 }, D135 = { 0.1644, 0.6462 },
                D136 = { 0.1503, 0.7712 }, D137 = { 0.1615, 0.6529 }, D138 = { 0.1317, 0.7154 }, D139 = { 0.1359, 0.7039 }, D140 = { 0.1117, 0.6400 },
                D141 = { 0.1056, 0.6388 }, D142 = { 0.1727, 0.6263 }, D143 = { 0.1976, 0.6322 }, D144 = { 0.1674, 0.6348 }, D145 = { 0.1320, 0.6333 },
                D146 = { 0.1180, 0.6382 }, D147 = { 0.1838, 0.6648 }, D148 = { 0.2000, 0.6433 }, D149 = { 0.2037, 0.7520 }, D150 = { 0.1298, 0.6106 },
                D151 = { 0.1568, 0.6917 }, D152 = { 0.2249, 0.6957 }, D153 = { 0.2180, 0.6529 }, D154 = { 0.1837, 0.6400 }, D155 = { 0.2079, 0.7086 },
                D156 = { 0.1625, 0.7005 }, D157 = { 0.1362, 0.6060 }, D158 = { 0.2038, 0.7717 }, D159 = { 0.2037, 0.7624 }, D160 = { 0.1544, 0.6474 },
                D161 = { 0.1034, 0.6864 }, D162 = { 0.1569, 0.5442 }, D163 = { 0.2318, 0.6789 }, D164 = { 0.2374, 0.6842 }, D165 = { 0.1866, 0.7263 },
                D166 = { 0.1950, 0.7176 }, D167 = { 0.1230, 0.6640 }, DG = { 0.2167, 0.8271 }, D169 = { 0.1516, 0.5846 }, D170 = { 0.2030, 0.6363 },
                D171 = { 0.1128, 0.5595 }, D172 = { 0.2031, 0.6708 }, D173 = { 0.2028, 0.6785 },
                -- dalout (2.1.1, M 20 Nov 2026 on the road east of the city, the arrow
                -- to Ranath Nightstride straight through the walls: "instead of
                -- telling me to take the road and then the stairs"): the roads
                -- outside, round the plaza with the pond at the foot of the great
                -- stairs: from the north-east (where M stood), the east and the
                -- south (the walking map's walks from each into the inn, by way of
                -- the plaza and the stairs, cut down to their corners).
                DP = { 0.2373, 0.8225 }, DJ = { 0.2641, 0.7801 }, DN = { 0.2680, 0.7000 },
                DE1 = { 0.2493, 0.8047 }, DE2 = { 0.2760, 0.8114 }, DE3 = { 0.2954, 0.7846 }, DE4 = { 0.3000, 0.7700 },
                DS1 = { 0.2180, 0.8426 }, DS2 = { 0.2299, 0.8605 }, DS3 = { 0.2400, 0.8600 },
            },
            edges = {
                { "D1", "D2" }, { "D1", "D3" }, { "D1", "D31" }, { "D1", "D39" }, { "D2", "D3" }, { "D2", "D63" }, { "D3", "D31" }, { "D3", "D63" },
                { "D4", "D5" }, { "D4", "D6" }, { "D4", "D7" }, { "D4", "D32" }, { "D5", "D32" }, { "D5", "D56" }, { "D6", "D7" }, { "D6", "D8" },
                { "D7", "D32" }, { "D7", "D33" }, { "D7", "D96" }, { "D8", "D9" }, { "D8", "D10" }, { "D8", "D11" }, { "D9", "D11" }, { "D9", "D126" },
                { "D9", "D154" }, { "D10", "D11" }, { "D10", "D144" }, { "D11", "D142" }, { "D11", "D144" }, { "D12", "D36" }, { "D12", "D77" }, { "D13", "D14" },
                { "D13", "D15" }, { "D14", "D15" }, { "D14", "D145" }, { "D14", "D146" }, { "D15", "D48" }, { "D16", "D17" }, { "D16", "D44" }, { "D16", "D89" },
                { "D16", "D149" }, { "D16", "D159" }, { "D17", "D88" }, { "D17", "D89" }, { "D18", "D125" }, { "D18", "D150" }, { "D19", "D20" }, { "D19", "D21" },
                { "D19", "D120" }, { "D20", "D21" }, { "D20", "D68" }, { "D21", "D169" }, { "D22", "D23" }, { "D22", "D24" }, { "D22", "D151" }, { "D22", "D156" },
                { "D23", "D24" }, { "D23", "D59" }, { "D23", "D78" }, { "D23", "D103" }, { "D23", "D123" }, { "D24", "D103" }, { "D24", "D104" }, { "D24", "D156" },
                { "D25", "D26" }, { "D25", "D85" }, { "D25", "D100" }, { "D26", "D44" }, { "D26", "D85" }, { "D27", "D28" }, { "D27", "D29" }, { "D27", "D71" },
                { "D28", "D38" }, { "D29", "D49" }, { "D29", "D56" }, { "D29", "D83" }, { "D29", "D107" }, { "D29", "D122" }, { "D30", "D58" }, { "D30", "D124" },
                { "D30", "D143" }, { "D31", "D39" }, { "D31", "D67" }, { "D31", "D95" }, { "D32", "D33" }, { "D32", "D156" }, { "D33", "D96" }, { "D34", "D35" },
                { "D34", "D36" }, { "D34", "D37" }, { "D35", "D37" }, { "D35", "D55" }, { "D35", "D94" }, { "D36", "D171" }, { "D37", "D54" }, { "D37", "D127" },
                { "D38", "D71" }, { "D38", "D167" }, { "D39", "D40" }, { "D39", "D41" }, { "D39", "D95" }, { "D40", "D41" }, { "D40", "D105" }, { "D40", "D172" },
                { "D41", "D105" }, { "D41", "D147" }, { "D42", "D43" }, { "D42", "D101" }, { "D43", "D92" }, { "D43", "D104" }, { "D43", "D156" }, { "D44", "D85" },
                { "D44", "D158" }, { "D45", "D46" }, { "D45", "D47" }, { "D45", "D84" }, { "D46", "D55" }, { "D46", "D62" }, { "D46", "D94" }, { "D47", "D84" },
                { "D47", "D102" }, { "D48", "D49" }, { "D48", "D50" }, { "D48", "D51" }, { "D48", "D75" }, { "D48", "D160" }, { "D49", "D50" }, { "D49", "D56" },
                { "D49", "D107" }, { "D49", "D160" }, { "D50", "D107" }, { "D51", "D75" }, { "D51", "D87" }, { "D51", "D115" }, { "D51", "D160" }, { "D52", "D53" },
                { "D52", "D127" }, { "D53", "D117" }, { "D54", "D55" }, { "D54", "D121" }, { "D55", "D62" }, { "D55", "D94" }, { "D56", "D83" }, { "D57", "D126" },
                { "D57", "D147" }, { "D58", "D72" }, { "D58", "D143" }, { "D59", "D60" }, { "D59", "D61" }, { "D59", "D78" }, { "D59", "D123" }, { "D59", "D139" },
                { "D60", "D61" }, { "D60", "D112" }, { "D60", "D139" }, { "D61", "D111" }, { "D61", "D112" }, { "D62", "D119" }, { "D63", "D64" }, { "D64", "D152" },
                { "D64", "D155" }, { "D65", "D66" }, { "D65", "D67" }, { "D65", "D101" }, { "D66", "D101" }, { "D66", "D165" }, { "D66", "D166" }, { "D67", "D95" },
                { "D68", "D69" }, { "D68", "D87" }, { "D68", "D91" }, { "D69", "D150" }, { "D69", "D157" }, { "D70", "D71" }, { "D70", "D86" }, { "D71", "D167" },
                { "D72", "D73" }, { "D72", "D74" }, { "D72", "D126" }, { "D72", "D154" }, { "D73", "D106" }, { "D73", "D148" }, { "D74", "D105" }, { "D74", "D106" },
                { "D74", "D126" }, { "D75", "D87" }, { "D76", "D77" }, { "D76", "D162" }, { "D77", "D94" }, { "D78", "D122" }, { "D79", "D80" }, { "D80", "D97" },
                { "D80", "D99" }, { "D80", "D134" }, { "D80", "D148" }, { "D81", "D82" }, { "D81", "D141" }, { "D82", "D140" }, { "D82", "D146" }, { "D83", "D122" },
                { "D83", "D123" }, { "D84", "D102" }, { "D84", "D119" }, { "D85", "D158" }, { "D86", "D145" }, { "D87", "D115" }, { "D88", "D89" }, { "D88", "D165" },
                { "D88", "D166" }, { "D89", "D149" }, { "D90", "D91" }, { "D90", "D129" }, { "D92", "D93" }, { "D92", "D104" }, { "D93", "D109" }, { "D95", "D96" },
                { "D97", "D98" }, { "D97", "D99" }, { "D97", "D134" }, { "D97", "D153" }, { "D98", "D110" }, { "D99", "D110" }, { "D100", "DG" }, { "D102", "D169" },
                { "D103", "D139" }, { "D104", "D156" }, { "D105", "D106" }, { "D105", "D110" }, { "D106", "D110" }, { "D106", "D148" }, { "D108", "D129" }, { "D108", "D162" },
                { "D109", "D128" }, { "D109", "D136" }, { "D110", "D148" }, { "D111", "D112" }, { "D111", "D113" }, { "D111", "D122" }, { "D112", "D114" }, { "D113", "D114" },
                { "D114", "D161" }, { "D115", "D116" }, { "D115", "D160" }, { "D116", "D135" }, { "D116", "D144" }, { "D117", "D118" }, { "D117", "D120" }, { "D117", "D121" },
                { "D118", "D119" }, { "D119", "D169" }, { "D121", "D127" }, { "D122", "D123" }, { "D124", "D142" }, { "D125", "D171" }, { "D126", "D154" }, { "D130", "D155" },
                { "D131", "D132" }, { "D131", "D133" }, { "D132", "D153" }, { "D133", "D134" }, { "D134", "D153" }, { "D135", "D137" }, { "D137", "D160" }, { "D138", "D139" },
                { "D140", "D141" }, { "D140", "D146" }, { "D142", "D144" }, { "D143", "D148" }, { "D143", "D170" }, { "D149", "D159" }, { "D150", "D157" }, { "D152", "D163" },
                { "D158", "D159" }, { "D163", "D164" }, { "D172", "D173" },
                { "DG", "DP" }, { "DP", "DJ" }, { "DJ", "DN" }, { "DP", "DE1" }, { "DE1", "DE2" }, { "DE2", "DE3" }, { "DE3", "DE4" }, -- dalout
                { "DG", "DS1" }, { "DS1", "DS2" }, { "DS2", "DS3" },
            },
        },
        -- tbroads (2.0.11, M 18 Nov 2026 on the bridge from Hunter Rise, the
        -- arrow to Auld Stonespire: "i think the arrow has no idea about
        -- thunder bluff, its sending me nowhere"): Thunder Bluff's rises and
        -- the bridges between them. The walking net lies flat, so it mixed
        -- the city up on the mesas with the plains under them (noNet: it is
        -- left out here). The rises, bridge ends and the two elevators read
        -- off M's map screenshot (rough: one corner per rise and bridge end).
        [1456] = {
            near = 200, targetNear = 200, noNet = true,
            gates = { "ES", "EN" },
            nodes = {
                HRC = { 0.589, 0.801 }, HB1 = { 0.546, 0.760 }, HB2 = { 0.476, 0.679 },
                L1 = { 0.449, 0.640 }, L2 = { 0.400, 0.615 }, L3 = { 0.362, 0.598 }, ES = { 0.355, 0.630 }, L4 = { 0.373, 0.492 },
                SB1 = { 0.362, 0.451 }, SB2 = { 0.308, 0.305 }, SRC = { 0.254, 0.199 },
                M1 = { 0.465, 0.500 }, H1 = { 0.546, 0.492 }, NR = { 0.492, 0.394 }, EN = { 0.511, 0.313 },
                EB1 = { 0.605, 0.370 }, EB2 = { 0.700, 0.310 }, ERC = { 0.768, 0.280 },
            },
            edges = {
                { "HRC", "HB1" }, { "HB1", "HB2" }, { "HB2", "L1" }, { "L1", "L2" }, { "L2", "L3" }, { "L3", "ES" }, { "L3", "L4" },
                { "L4", "SB1" }, { "SB1", "SB2" }, { "SB2", "SRC" }, { "L1", "M1" }, { "L4", "M1" }, { "M1", "H1" }, { "M1", "NR" },
                { "NR", "EN" }, { "NR", "H1" }, { "H1", "EB1" }, { "EB1", "EB2" }, { "EB2", "ERC" },
            },
            -- tbopen (2.0.12, M 18 Nov 2026 on the main rise at 39.9, 57.0,
            -- "Fly to Ratchet", the arrow sending him right round the road:
            -- "it does not understand that I can just walk straight to the
            -- big tower"): the rises are open ground. Standing on one, the
            -- arrow goes straight to a spot on the same rise, and straight to
            -- whichever of its corners (bridge ends, elevators) starts the
            -- shortest way off it. The outlines read off M's map screenshot,
            -- kept a little inside the edges.
            areas = {
                { -- the main rise (the wind rider tower)
                    poly = { { 0.340, 0.440 }, { 0.375, 0.400 }, { 0.420, 0.345 }, { 0.470, 0.315 }, { 0.530, 0.305 }, { 0.575, 0.330 },
                        { 0.610, 0.365 }, { 0.645, 0.405 }, { 0.660, 0.470 }, { 0.660, 0.560 }, { 0.635, 0.620 }, { 0.585, 0.645 },
                        { 0.530, 0.660 }, { 0.490, 0.690 }, { 0.450, 0.685 }, { 0.400, 0.665 }, { 0.360, 0.640 }, { 0.340, 0.600 }, { 0.335, 0.520 } },
                    nodes = { "L1", "L2", "L3", "ES", "L4", "SB1", "M1", "H1", "NR", "EN", "EB1", "HB2" },
                },
                { -- the Spirit Rise
                    poly = { { 0.180, 0.150 }, { 0.240, 0.120 }, { 0.300, 0.140 }, { 0.320, 0.210 }, { 0.315, 0.290 }, { 0.270, 0.315 }, { 0.205, 0.290 }, { 0.175, 0.220 } },
                    nodes = { "SRC", "SB2" },
                },
                { -- the Elder Rise
                    poly = { { 0.700, 0.230 }, { 0.770, 0.215 }, { 0.835, 0.240 }, { 0.840, 0.310 }, { 0.790, 0.340 }, { 0.720, 0.335 }, { 0.695, 0.290 } },
                    nodes = { "ERC", "EB2" },
                },
                { -- the Hunter Rise
                    poly = { { 0.515, 0.745 }, { 0.570, 0.715 }, { 0.640, 0.725 }, { 0.665, 0.800 }, { 0.650, 0.900 }, { 0.580, 0.935 }, { 0.520, 0.890 }, { 0.505, 0.810 } },
                    nodes = { "HRC", "HB1" },
                },
            },
        },
        -- ucroyal (2.0.12, M 18 Nov 2026 in the Apothecarium at 53.1, 64.0,
        -- An Unholy Alliance to Varimathras, the arrow pointing straight at
        -- him: "arrow needs to understand that to reach this npc i need to
        -- enter this door"): the Royal Quarter is only reached through the
        -- door at the top of the Apothecarium's stairs (the Royal Dreadguards)
        -- and the long hall behind it, which bends west before it reaches the
        -- throne room; Varimathras and Sylvanas stand up on its dais, its
        -- steps on the west side. The corners: the shortest walks on the
        -- Eastern Kingdoms walking maps (the Forever client's
        -- navigation grid with its floors, a walking router run offline) to
        -- Varimathras from the Apothecarium, the Rogues' Quarter, the War
        -- Quarter and the elevator, merged. Only for a spot in the Royal
        -- Quarter (onlyNear) and only down in the city (ucDown: up in the
        -- ruins the elevator comes first, as before).
        [1458] = {
            near = 140, targetNear = 30, onlyNear = true, ucDown = true, close = 12, pass = 5,
            gates = { "S" },
            -- the spot's nearest stretch must touch the throne room: the
            -- Apothecarium's lab lies under the hall (Master Apothecary
            -- Faranell, 28 yards lower) and is not reached through it
            targetNodes = { VT = true, R4 = true, R3b = true, R3 = true, R1 = true },
            -- uclab (2.0.13, M 18 Nov 2026 at Doctor Martin Felben, "Fly to
            -- The Sepulcher", the arrow pointing straight at the bat handler:
            -- "it doesn't understand that I have to go back up here through
            -- this passage"): the Apothecarium's lab lies under the hall, and
            -- its way out is the ramp on its south-east side, up to the canal
            -- ring (L1 ... L8; LW the passage on its west side). From there
            -- round the ring, in through the south-east passage and up over
            -- the middle of the Trade Quarter to the bat handler on the upper
            -- ring (T1 ... FM). The same source as the corners above, run
            -- from Felben to Michael Garrett. The game does not tell floors
            -- apart, so which of the two the player is on (the hall or the
            -- lab under it) is the last of these passed: the hall's door and
            -- far end, or the lab's ramp.
            hallNodes = { VT = true, R4 = true, R3b = true, R3 = true, R1 = true, H8 = true, H7 = true, H6 = true, H5 = true, H4 = true, H3 = true, H2 = true },
            labNodes = { L1 = true, L2 = true, L3 = true, L4 = true, L5 = true, L6 = true, L7 = true, LW = true,
                P7 = true }, -- (labwest: the passage's foot; labjoin: the rest of it on no floor, the way down from the ring)
            -- labjoin (2.0.13, M 19 Nov 2026 at the Royal Quarter's door,
            -- "not the big entrance with the royal guards"): into the lab
            -- only by the west passage, never up the south-east ramp's way
            -- (L8 to L9); the ways out of it stay as they were
            labNotIn = { L8 = "L9" },
            tradeNodes = { T5 = true, T6 = true, T8 = true, T9 = true, FM = true, F11 = true }, -- (ucring: the ramp and the Trade Quarter's upper ring only)
            -- ucring: the stairs up to the Royal Quarter's door and the War
            -- Quarter's way there (Varimathras's ways), kept apart from the
            -- bat handler's ways (F...): each place uses its own
            royalNodes = { D = true, S = true, N1 = true, N2 = true, N3 = true, N4 = true, N5 = true, N6 = true, N7 = true },
            -- ucring (2.0.13, M 18 Nov 2026 on the canal ring at 52.1, 51.3,
            -- "Fly to The Sepulcher": "it's not following the circle of
            -- Undercity ... it's sending me back"): the ways from anywhere
            -- in the lower city (the canal ring, the four quarters, the
            -- bridges into the Trade Quarter) to the bat handler, up the ramp
            -- to the Trade Quarter's upper ring: the shortest walks to
            -- Michael Garrett from 245 places of the lower city (every 24
            -- yards; a walking router on the Forever client's walking maps,
            -- run offline), cut to their corners and merged (F1 ... and the
            -- corners above). The upper ring is right over the lower floor:
            -- come from out in the city, the arrow stays on the lower floor's
            -- ways until the top of the ramp is passed (tradeUp), and back
            -- there once a lower corner of the Trade Quarter is (tradeDown).
            tradeUp = { T5 = 5, T6 = 4 }, -- (the ramp and its top; the lower floor runs right under the ring and the platform)
            tradeDown = { T1 = 6, F10 = 6, F74 = 6, F114 = 6, F115 = 6, F123 = 6, F165 = 6, F166 = 6, F189 = 6, F203 = 6 },
            farNodes = { FM = true, T9 = true },
            floorMarks = { hall = { D = 5, H5 = 10, H6 = 10, H7 = 10, H8 = 10, R1 = 10 }, lab = { L5 = 10, L6 = 10, L7 = 10, L9 = 8, P7 = 8 } },
            labSpots = { { 0.4661, 0.7412 } }, -- Doctor Martin Felben
            nodes = {
                VT = { 0.5624, 0.9248 }, R4 = { 0.5606, 0.9518 }, R3b = { 0.5606, 0.9582 }, R3 = { 0.5562, 0.9582 }, R1 = { 0.5475, 0.9257 },
                H8 = { 0.5258, 0.8932 }, H7 = { 0.4910, 0.8801 }, H6 = { 0.4824, 0.8737 }, H5 = { 0.4607, 0.8346 }, H4 = { 0.4563, 0.7890 },
                H3 = { 0.4630, 0.7304 }, H2 = { 0.4807, 0.6979 }, D = { 0.5215, 0.6426 }, S = { 0.5301, 0.6457 }, A1 = { 0.5649, 0.6718 },
                B1 = { 0.5822, 0.6328 }, B2 = { 0.5866, 0.6262 }, B3 = { 0.5910, 0.6328 }, B4 = { 0.6083, 0.6457 }, B5 = { 0.6474, 0.6457 },
                B6 = { 0.6648, 0.5612 }, B7 = { 0.7039, 0.5156 }, B8 = { 0.7082, 0.4961 }, C1 = { 0.5779, 0.6848 }, C2 = { 0.5997, 0.7109 },
                C3 = { 0.7082, 0.7109 }, N1 = { 0.5041, 0.6003 }, N2 = { 0.5041, 0.5808 }, N3 = { 0.4954, 0.5676 }, N4 = { 0.4954, 0.5417 },
                N5 = { 0.4824, 0.5156 }, N6 = { 0.4824, 0.3594 }, N7 = { 0.4868, 0.3138 },
                -- uclab
                L1 = { 0.4868, 0.7304 }, L2 = { 0.4780, 0.7499 }, L3 = { 0.4780, 0.7629 }, L4 = { 0.4868, 0.7824 }, L5 = { 0.5084, 0.8020 },
                L6 = { 0.5258, 0.7956 }, L7 = { 0.5258, 0.7824 }, L8 = { 0.5518, 0.6718 }, LW = { 0.4563, 0.7304 },
                L9 = { 0.5431, 0.7087 }, -- (ucring: 25 yards down the ramp, past the stairs to the hall: in the lab from here)
                -- labwest (2.0.13, M 19 Nov 2026 on the canal ring by the
                -- Apothecarium at 46.9, 59.7, the arrow to Doctor Martin
                -- Felben leading back east round to the south-east ramp:
                -- "Source of Power is actually below through this little
                -- passage"): the passage from the ring down to the lab's west
                -- side (a walking router on the Forever client's walking
                -- maps, to Felben's own spot, z -80: 145 yards, was 278). Only
                -- a way in: its top is not joined to the ring's ways, so the
                -- ways out of the lab (to the bat handler) stay as they were.
                -- (labjoin, M 19 Nov 2026 at 48.6, 56.5, "this little passage after
                -- the two abominations is where you have to go ... not the big
                -- entrance with the royal guards": its top joined to the ring's
                -- way, P0, so the arrow comes to it from anywhere on the ring)
                P0 = { 0.4690, 0.5872 },
                P1 = { 0.4520, 0.5872 }, P2 = { 0.4433, 0.6002 }, P3 = { 0.4476, 0.6653 }, P4 = { 0.4433, 0.6718 },
                P5 = { 0.4346, 0.6913 }, P6 = { 0.4389, 0.7044 }, P7 = { 0.4476, 0.7109 },
                T1 = { 0.6995, 0.5026 }, T2 = { 0.6735, 0.4570 }, T4 = { 0.6778, 0.4309 }, T5 = { 0.6821, 0.4375 }, T6 = { 0.6648, 0.4375 },
                T8 = { 0.6604, 0.4570 }, T9 = { 0.6518, 0.4895 }, FM = { 0.6324, 0.4858 },
                -- ucring (2.0.13): the lower city's ways to the bat handler
                F1 = { 0.4607, 0.1315 }, F2 = { 0.5302, 0.1315 }, F3 = { 0.5779, 0.1771 }, F4 = { 0.6387, 0.1706 }, F5 = { 0.6431, 0.1771 }, F6 = { 0.6431, 0.2227 },
                F7 = { 0.6561, 0.2552 }, F8 = { 0.6648, 0.3203 }, F9 = { 0.6995, 0.3659 }, F10 = { 0.6995, 0.3789 }, F11 = { 0.6604, 0.4440 }, F12 = { 0.5432, 0.1380 },
                F13 = { 0.5692, 0.1771 }, F14 = { 0.5084, 0.1380 }, F15 = { 0.5562, 0.1445 }, F16 = { 0.6561, 0.2357 }, F17 = { 0.7516, 0.1706 }, F18 = { 0.7430, 0.1836 },
                F19 = { 0.7082, 0.1706 }, F20 = { 0.6822, 0.1771 }, F21 = { 0.6648, 0.2552 }, F22 = { 0.8211, 0.1380 }, F23 = { 0.8211, 0.1511 }, F24 = { 0.8124, 0.1576 },
                F25 = { 0.8515, 0.1576 }, F26 = { 0.8385, 0.1771 }, F27 = { 0.8298, 0.1771 }, F28 = { 0.7169, 0.1836 }, F29 = { 0.4476, 0.1641 }, F30 = { 0.4650, 0.1771 },
                F31 = { 0.4867, 0.1380 }, F32 = { 0.5562, 0.1771 }, F33 = { 0.4824, 0.1445 }, F34 = { 0.4997, 0.1511 }, F35 = { 0.5171, 0.1380 }, F36 = { 0.6518, 0.2292 },
                F37 = { 0.6040, 0.1836 }, F38 = { 0.6127, 0.1706 }, F39 = { 0.6214, 0.1706 }, F40 = { 0.6561, 0.3073 }, F41 = { 0.6431, 0.2031 }, F42 = { 0.6735, 0.2096 },
                F43 = { 0.6648, 0.2227 }, F44 = { 0.6995, 0.1706 }, F45 = { 0.7212, 0.1706 }, F46 = { 0.8429, 0.1706 }, F47 = { 0.8342, 0.1576 }, F48 = { 0.7343, 0.1836 },
                F49 = { 0.4693, 0.2552 }, F50 = { 0.5041, 0.2747 }, F51 = { 0.5605, 0.1966 }, F52 = { 0.4693, 0.1966 }, F53 = { 0.4954, 0.1836 }, F54 = { 0.5388, 0.2227 },
                F55 = { 0.5692, 0.1966 }, F56 = { 0.5823, 0.1901 }, F57 = { 0.5302, 0.2227 }, F58 = { 0.5649, 0.2031 }, F59 = { 0.6214, 0.2096 }, F60 = { 0.6257, 0.2031 },
                F61 = { 0.6778, 0.2031 }, F62 = { 0.7473, 0.2096 }, F63 = { 0.7473, 0.1966 }, F64 = { 0.7516, 0.2031 }, F65 = { 0.7951, 0.2227 }, F66 = { 0.7690, 0.2227 },
                F67 = { 0.8472, 0.2162 }, F68 = { 0.5475, 0.2162 }, F69 = { 0.5519, 0.2422 }, F70 = { 0.5692, 0.2617 }, F71 = { 0.5779, 0.2617 }, F72 = { 0.5823, 0.2552 },
                F73 = { 0.6214, 0.2357 }, F74 = { 0.6952, 0.3854 }, F75 = { 0.6952, 0.2357 }, F76 = { 0.6735, 0.2357 }, F77 = { 0.7343, 0.2552 }, F78 = { 0.7256, 0.2422 },
                F79 = { 0.6995, 0.2422 }, F80 = { 0.7647, 0.2162 }, F81 = { 0.7864, 0.2292 }, F82 = { 0.8168, 0.2357 }, F83 = { 0.4997, 0.2812 }, F84 = { 0.5258, 0.2422 },
                F85 = { 0.5692, 0.2812 }, F86 = { 0.5996, 0.2617 }, F87 = { 0.6040, 0.2682 }, F88 = { 0.6040, 0.2552 }, F89 = { 0.6691, 0.3268 }, F90 = { 0.7169, 0.2682 },
                F91 = { 0.7169, 0.2552 }, F92 = { 0.7212, 0.2617 }, F93 = { 0.7864, 0.3203 }, F94 = { 0.7907, 0.3268 }, F95 = { 0.7951, 0.4245 }, F96 = { 0.7864, 0.4310 },
                F97 = { 0.7386, 0.4310 }, F98 = { 0.7126, 0.3789 }, F99 = { 0.6822, 0.4114 }, F100 = { 0.7994, 0.2682 }, F101 = { 0.7907, 0.2487 }, F102 = { 0.8211, 0.2812 },
                F103 = { 0.4954, 0.3138 }, F104 = { 0.5041, 0.3073 }, F105 = { 0.5084, 0.3008 }, F106 = { 0.5084, 0.2812 }, F107 = { 0.5345, 0.3268 }, F108 = { 0.5345, 0.3659 },
                F109 = { 0.5258, 0.3789 }, F110 = { 0.5258, 0.4245 }, F111 = { 0.5302, 0.4310 }, F112 = { 0.5823, 0.4310 }, F113 = { 0.6083, 0.3789 }, F114 = { 0.6170, 0.3789 },
                F115 = { 0.6431, 0.4179 }, F116 = { 0.6735, 0.4245 }, F117 = { 0.5475, 0.3203 }, F118 = { 0.5388, 0.3203 }, F119 = { 0.5953, 0.2747 }, F120 = { 0.5866, 0.3073 },
                F121 = { 0.6083, 0.2487 }, F122 = { 0.6214, 0.3659 }, F123 = { 0.6214, 0.3854 }, F124 = { 0.6952, 0.3594 }, F125 = { 0.7343, 0.3203 }, F126 = { 0.7343, 0.3073 },
                F127 = { 0.7647, 0.3138 }, F128 = { 0.7951, 0.3789 }, F129 = { 0.8168, 0.3008 }, F130 = { 0.8168, 0.2747 }, F131 = { 0.8429, 0.3138 }, F132 = { 0.4780, 0.3529 },
                F133 = { 0.5736, 0.1901 }, F134 = { 0.4911, 0.3203 }, F135 = { 0.5388, 0.3529 }, F136 = { 0.5692, 0.3659 }, F137 = { 0.5736, 0.3789 }, F138 = { 0.5649, 0.3854 },
                F139 = { 0.5605, 0.3789 }, F140 = { 0.5475, 0.3529 }, F141 = { 0.7864, 0.3594 }, F142 = { 0.8255, 0.3138 }, F143 = { 0.8429, 0.3594 }, F144 = { 0.8429, 0.3398 },
                F145 = { 0.4563, 0.4375 }, F146 = { 0.4693, 0.4375 }, F147 = { 0.4693, 0.4896 }, F148 = { 0.4954, 0.5546 }, F149 = { 0.4954, 0.5677 }, F150 = { 0.5562, 0.6653 },
                F151 = { 0.6214, 0.6458 }, F152 = { 0.6518, 0.6327 }, F153 = { 0.6518, 0.5807 }, F154 = { 0.4737, 0.4179 }, F155 = { 0.4693, 0.3984 }, F156 = { 0.4780, 0.3789 },
                F157 = { 0.7734, 0.3594 }, F158 = { 0.8429, 0.3789 }, F159 = { 0.8385, 0.3333 }, F160 = { 0.4737, 0.3854 }, F161 = { 0.4693, 0.4635 }, F162 = { 0.5302, 0.4505 },
                F163 = { 0.5779, 0.4505 }, F164 = { 0.6083, 0.5026 }, F165 = { 0.6170, 0.5026 }, F166 = { 0.6431, 0.4635 }, F167 = { 0.7386, 0.4505 }, F168 = { 0.7126, 0.5026 },
                F169 = { 0.8385, 0.3659 }, F170 = { 0.7386, 0.1901 }, F171 = { 0.4824, 0.5091 }, F172 = { 0.5258, 0.4570 }, F173 = { 0.5432, 0.5221 }, F174 = { 0.5345, 0.5221 },
                F175 = { 0.5258, 0.5026 }, F176 = { 0.7473, 0.4961 }, F177 = { 0.7430, 0.5026 }, F178 = { 0.7430, 0.5156 }, F179 = { 0.7647, 0.5156 }, F180 = { 0.7734, 0.5286 },
                F181 = { 0.7820, 0.5286 }, F182 = { 0.7951, 0.5026 }, F183 = { 0.7951, 0.4570 }, F184 = { 0.7864, 0.4505 }, F185 = { 0.7734, 0.5091 }, F186 = { 0.5128, 0.5612 },
                F187 = { 0.5041, 0.5742 }, F188 = { 0.5041, 0.5872 }, F189 = { 0.6952, 0.4961 }, F190 = { 0.7777, 0.5351 }, F191 = { 0.8385, 0.5221 }, F192 = { 0.4650, 0.5872 },
                F193 = { 0.4737, 0.5872 }, F194 = { 0.4997, 0.6002 }, F195 = { 0.5432, 0.6653 }, F196 = { 0.4693, 0.5612 }, F197 = { 0.4911, 0.5872 }, F198 = { 0.5345, 0.5612 },
                F199 = { 0.5475, 0.5546 }, F200 = { 0.5692, 0.6002 }, F201 = { 0.5910, 0.6132 }, F202 = { 0.6214, 0.5156 }, F203 = { 0.6214, 0.4961 }, F204 = { 0.7169, 0.6197 },
                F205 = { 0.6995, 0.6458 }, F206 = { 0.6691, 0.6458 }, F207 = { 0.6648, 0.6327 }, F208 = { 0.7343, 0.5612 }, F209 = { 0.7212, 0.6132 }, F210 = { 0.7603, 0.5481 },
                F211 = { 0.7864, 0.5221 }, F212 = { 0.7907, 0.5416 }, F213 = { 0.7951, 0.5286 }, F214 = { 0.7994, 0.5351 }, F215 = { 0.8255, 0.5742 }, F216 = { 0.8124, 0.5872 },
                F217 = { 0.8124, 0.6132 }, F218 = { 0.8038, 0.6197 }, F219 = { 0.7864, 0.6393 }, F220 = { 0.7734, 0.6523 }, F221 = { 0.7734, 0.6653 }, F222 = { 0.7560, 0.6718 },
                F223 = { 0.7299, 0.7044 }, F224 = { 0.5692, 0.6783 }, F225 = { 0.7777, 0.6458 }, F226 = { 0.7343, 0.6913 }, F227 = { 0.4520, 0.5872 }, F228 = { 0.4954, 0.5937 },
                F229 = { 0.5996, 0.6327 }, F230 = { 0.5823, 0.6002 }, F231 = { 0.6648, 0.6132 }, F232 = { 0.5996, 0.6197 }, F233 = { 0.6127, 0.6002 }, F234 = { 0.6040, 0.6132 },
                F235 = { 0.6040, 0.6262 }, F236 = { 0.6691, 0.5546 }, F237 = { 0.7473, 0.6002 }, F238 = { 0.7256, 0.6262 }, F239 = { 0.7690, 0.6067 }, F240 = { 0.7603, 0.6002 },
                F241 = { 0.7516, 0.6067 }, F242 = { 0.7256, 0.6327 }, F243 = { 0.7082, 0.6327 }, F244 = { 0.7169, 0.7109 }, F245 = { 0.8168, 0.6067 }, F246 = { 0.4389, 0.6067 },
                F247 = { 0.4476, 0.6262 }, F248 = { 0.4433, 0.6002 }, F249 = { 0.5128, 0.6197 }, F250 = { 0.5519, 0.6523 }, F251 = { 0.6604, 0.6197 }, F252 = { 0.7430, 0.6262 },
                F253 = { 0.7169, 0.6327 }, F254 = { 0.7951, 0.6393 }, F255 = { 0.8168, 0.6458 }, F256 = { 0.4389, 0.6783 }, F257 = { 0.4476, 0.6653 }, F258 = { 0.5215, 0.6458 },
                F259 = { 0.5171, 0.6653 }, F260 = { 0.5171, 0.6523 }, F261 = { 0.5302, 0.6458 }, F262 = { 0.6561, 0.6262 }, F263 = { 0.5996, 0.6523 }, F264 = { 0.7039, 0.6523 },
                F265 = { 0.6735, 0.6523 }, F266 = { 0.7603, 0.6653 }, F267 = { 0.7907, 0.6588 }, F268 = { 0.7647, 0.6718 }, F269 = { 0.7864, 0.6978 }, F270 = { 0.5041, 0.6067 },
                F271 = { 0.6083, 0.7109 }, F272 = { 0.6952, 0.7044 }, F273 = { 0.7430, 0.6913 }, F274 = { 0.7126, 0.7044 }, F275 = { 0.8472, 0.7109 }, F276 = { 0.8298, 0.7044 },
                F277 = { 0.5692, 0.7044 }, F278 = { 0.6257, 0.7239 }, F279 = { 0.7430, 0.7044 }, F280 = { 0.7647, 0.7369 }, F281 = { 0.7560, 0.7564 }, F282 = { 0.7734, 0.7499 },
            },
            edges = {
                { "N3", "P0" }, { "P0", "P1" }, { "P1", "P2" }, { "P2", "P3" }, { "P3", "P4" }, { "P4", "P5" }, { "P5", "P6" }, { "P6", "P7" }, { "P7", "LW" }, -- labwest
                { "VT", "R4" }, { "R4", "R3b" }, { "R3b", "R3" }, { "R3", "R1" }, { "R1", "H8" }, { "H8", "H7" }, { "H7", "H6" }, { "H6", "H5" },
                { "H5", "H4" }, { "H4", "H3" }, { "H3", "H2" }, { "H2", "D" }, { "D", "S" }, { "D", "N1" }, { "N1", "N2" }, { "N2", "N3" },
                { "N3", "N4" }, { "N4", "N5" }, { "S", "A1" }, { "A1", "B1" }, { "B1", "B2" }, { "B2", "B3" }, { "B3", "B4" }, { "B4", "B5" },
                { "B5", "B6" }, { "B6", "B7" }, { "B7", "B8" }, { "A1", "C1" }, { "C1", "C2" }, { "C2", "C3" }, { "N5", "N6" }, { "N6", "N7" },
                -- uclab
                { "L1", "L2" }, { "L2", "L3" }, { "L3", "L4" }, { "LW", "L4" }, { "L4", "L5" }, { "L5", "L6" }, { "L6", "L7" }, { "L7", "L9" }, { "L9", "L8" },
                { "L8", "A1" }, { "B7", "T1" }, { "T1", "T2" }, { "T2", "T4" }, { "T4", "T5" }, { "T5", "T6" }, { "T6", "T8" }, { "T8", "T9" },
                { "T9", "FM" },
                -- ucring
                { "A1", "B2" }, { "A1", "F150" }, { "A1", "F195" }, { "A1", "L8" }, { "B1", "B2" }, { "B1", "F224" }, { "B2", "B3" }, { "B2", "B4" }, { "B2", "F151" },
                { "B2", "F224" }, { "B3", "F229" }, { "B4", "B5" }, { "B5", "B6" }, { "B5", "F151" }, { "B5", "F152" }, { "B5", "F231" }, { "B5", "F251" }, { "B5", "F262" },
                { "B5", "F263" }, { "B6", "B7" }, { "B6", "F152" }, { "B6", "F207" }, { "B6", "F231" }, { "B6", "F251" }, { "B6", "F262" }, { "B7", "F153" }, { "B7", "F189" },
                { "B7", "F236" }, { "B7", "T1" }, { "C1", "C2" }, { "C1", "F224" }, { "C1", "F271" }, { "C1", "F277" }, { "C1", "F278" }, { "C2", "C3" }, { "C2", "F223" },
                { "C2", "F244" }, { "C2", "F272" }, { "C2", "F276" }, { "C3", "F223" }, { "C3", "F226" }, { "C3", "F266" }, { "C3", "F269" }, { "C3", "F271" }, { "C3", "F274" },
                { "C3", "F279" }, { "F1", "F12" }, { "F1", "F2" }, { "F1", "F29" }, { "F10", "F9" }, { "F10", "F98" }, { "F10", "F99" }, { "F10", "T4" }, { "F100", "F101" },
                { "F101", "F80" }, { "F102", "F81" }, { "F103", "F104" }, { "F103", "F132" }, { "F103", "F156" }, { "F103", "F160" }, { "F104", "F105" }, { "F104", "F134" }, { "F105", "F106" },
                { "F106", "F51" }, { "F106", "F68" }, { "F107", "F108" }, { "F108", "F109" }, { "F108", "F118" }, { "F108", "F140" }, { "F109", "F110" }, { "F109", "F135" }, { "F11", "T6" },
                { "F11", "T8" }, { "F110", "F111" }, { "F111", "F112" }, { "F112", "F113" }, { "F113", "F114" }, { "F113", "F115" }, { "F114", "F115" }, { "F115", "F116" }, { "F115", "F123" },
                { "F116", "T4" }, { "F117", "F118" }, { "F119", "F73" }, { "F12", "F13" }, { "F12", "F3" }, { "F12", "F31" }, { "F120", "F121" }, { "F121", "F73" }, { "F122", "F123" },
                { "F124", "F9" }, { "F125", "F126" }, { "F126", "F91" }, { "F127", "F128" }, { "F128", "F141" }, { "F128", "F95" }, { "F129", "F130" }, { "F129", "F142" }, { "F13", "F4" },
                { "F130", "F81" }, { "F131", "F81" }, { "F133", "F51" }, { "F133", "F56" }, { "F135", "F140" }, { "F136", "F137" }, { "F137", "F138" }, { "F138", "F139" }, { "F139", "F140" },
                { "F14", "F15" }, { "F141", "F157" }, { "F142", "F144" }, { "F142", "F159" }, { "F142", "F169" }, { "F143", "F144" }, { "F145", "F146" }, { "F146", "F147" }, { "F147", "F148" },
                { "F147", "F161" }, { "F147", "F171" }, { "F148", "F149" }, { "F148", "F171" }, { "F149", "F150" }, { "F15", "F3" }, { "F15", "F35" }, { "F150", "F188" }, { "F150", "F249" },
                { "F150", "F250" }, { "F150", "F258" }, { "F150", "F261" }, { "F151", "F201" }, { "F151", "F229" }, { "F151", "F230" }, { "F151", "F232" }, { "F151", "F235" }, { "F152", "F153" },
                { "F154", "F155" }, { "F155", "F156" }, { "F158", "F159" }, { "F16", "F41" }, { "F16", "F6" }, { "F16", "F7" }, { "F16", "F73" }, { "F16", "F8" }, { "F162", "F163" },
                { "F162", "F172" }, { "F163", "F164" }, { "F164", "F165" }, { "F165", "F166" }, { "F166", "F203" }, { "F166", "T2" }, { "F167", "F168" }, { "F167", "F184" }, { "F168", "T1" },
                { "F169", "F191" }, { "F17", "F18" }, { "F170", "F44" }, { "F170", "F80" }, { "F172", "F175" }, { "F173", "F174" }, { "F174", "F175" }, { "F175", "F198" }, { "F175", "F199" },
                { "F176", "F177" }, { "F177", "F178" }, { "F178", "F179" }, { "F179", "F180" }, { "F18", "F19" }, { "F18", "F24" }, { "F180", "F181" }, { "F180", "F185" }, { "F181", "F182" },
                { "F182", "F183" }, { "F182", "F190" }, { "F182", "F211" }, { "F183", "F184" }, { "F183", "F213" }, { "F183", "F214" }, { "F186", "F187" }, { "F187", "F188" }, { "F189", "T2" },
                { "F19", "F20" }, { "F19", "F28" }, { "F19", "F48" }, { "F19", "F63" }, { "F19", "F64" }, { "F19", "F80" }, { "F192", "F193" }, { "F193", "F194" }, { "F193", "F227" },
                { "F193", "F270" }, { "F194", "F195" }, { "F195", "F197" }, { "F195", "F228" }, { "F195", "F270" }, { "F196", "F197" }, { "F197", "F227" }, { "F2", "F3" }, { "F2", "F31" },
                { "F2", "F32" }, { "F2", "F35" }, { "F20", "F21" }, { "F20", "F44" }, { "F20", "F45" }, { "F200", "F201" }, { "F200", "F230" }, { "F202", "F203" }, { "F204", "F205" },
                { "F205", "F206" }, { "F205", "F209" }, { "F205", "F238" }, { "F205", "F243" }, { "F205", "F253" }, { "F206", "F207" }, { "F207", "F265" }, { "F208", "F209" }, { "F21", "F6" },
                { "F21", "F61" }, { "F21", "F76" }, { "F21", "F8" }, { "F210", "F211" }, { "F212", "F213" }, { "F215", "F216" }, { "F216", "F217" }, { "F217", "F218" }, { "F218", "F219" },
                { "F218", "F245" }, { "F219", "F220" }, { "F219", "F225" }, { "F219", "F254" }, { "F22", "F23" }, { "F220", "F221" }, { "F221", "F222" }, { "F221", "F225" }, { "F222", "F223" },
                { "F222", "F226" }, { "F222", "F268" }, { "F225", "F254" }, { "F226", "F244" }, { "F227", "F228" }, { "F227", "F246" }, { "F227", "F248" }, { "F228", "L8" }, { "F23", "F24" },
                { "F23", "F47" }, { "F233", "F234" }, { "F234", "F235" }, { "F237", "F238" }, { "F239", "F240" }, { "F24", "F48" }, { "F240", "F241" }, { "F241", "F242" }, { "F242", "F243" },
                { "F242", "F252" }, { "F242", "F253" }, { "F244", "F273" }, { "F247", "F248" }, { "F248", "F257" }, { "F25", "F26" }, { "F254", "F255" }, { "F256", "F257" }, { "F259", "F260" },
                { "F26", "F27" }, { "F260", "F261" }, { "F264", "F265" }, { "F267", "F268" }, { "F27", "F28" }, { "F275", "F276" }, { "F279", "F280" }, { "F279", "F281" }, { "F279", "F282" },
                { "F3", "F4" }, { "F30", "F31" }, { "F31", "F33" }, { "F32", "F4" }, { "F34", "F35" }, { "F34", "F53" }, { "F36", "F6" }, { "F36", "F8" }, { "F37", "F38" },
                { "F38", "F5" }, { "F38", "F51" }, { "F38", "F56" }, { "F39", "F5" }, { "F4", "F5" }, { "F40", "F7" }, { "F40", "F9" }, { "F41", "F60" }, { "F41", "F7" },
                { "F42", "F43" }, { "F43", "F8" }, { "F44", "F63" }, { "F45", "F66" }, { "F45", "F80" }, { "F46", "F47" }, { "F48", "F80" }, { "F49", "F50" }, { "F5", "F6" },
                { "F50", "F51" }, { "F51", "F68" }, { "F51", "F83" }, { "F51", "F84" }, { "F52", "F53" }, { "F54", "F55" }, { "F55", "F56" }, { "F55", "F57" }, { "F55", "F58" },
                { "F55", "F68" }, { "F59", "F60" }, { "F6", "F7" }, { "F62", "F63" }, { "F63", "F66" }, { "F63", "F80" }, { "F65", "F66" }, { "F66", "F67" }, { "F69", "F70" },
                { "F7", "F8" }, { "F70", "F71" }, { "F71", "F72" }, { "F72", "F73" }, { "F72", "F85" }, { "F73", "F86" }, { "F73", "F88" }, { "F74", "F9" }, { "F74", "T4" },
                { "F75", "F76" }, { "F75", "F79" }, { "F75", "F91" }, { "F75", "F92" }, { "F77", "F78" }, { "F78", "F79" }, { "F8", "F9" }, { "F80", "F81" }, { "F80", "F82" },
                { "F87", "F88" }, { "F89", "F9" }, { "F90", "F91" }, { "F93", "F94" }, { "F94", "F95" }, { "F95", "F96" }, { "F96", "F97" }, { "F97", "F98" }, { "F98", "F99" },
                { "F99", "T4" }, { "FM", "T9" }, { "T1", "T2" }, { "T2", "T4" }, { "T4", "T5" }, { "T5", "T6" }, { "T8", "T9" },
            },
        },
        -- menethildocks (2.0.13, M 18 Nov 2026 on Menethil Harbor's quay,
        -- "Take the boat to Theramore", the arrow pointing straight over the
        -- water at the far pier: "it's not really understanding that I'm on
        -- the dock where I have to go ... the one for Theramore is the one
        -- on the left"): the quay and the two piers (the boat to Theramore
        -- leaves from the southern one, TH; the boat from Auberdine lands at
        -- the northern one, AU): the walk between them on the Forever
        -- client's walking map (the navigation grid, a walking router run
        -- offline), cut down to its corners. Only for a place on the piers.
        [1437] = {
            near = 70, targetNear = 25, onlyNear = true, docks = true, close = 12, pass = 6,
            gates = { "Q1" },
            nodes = {
                TH = { 0.0521, 0.6371 }, S2 = { 0.0574, 0.6364 }, S1 = { 0.0645, 0.6289 }, SR = { 0.0887, 0.6062 }, Q1 = { 0.0887, 0.5956 },
                NR = { 0.0776, 0.5790 }, N2 = { 0.0615, 0.5850 }, AU = { 0.0483, 0.5704 },
            },
            edges = { { "TH", "S2" }, { "S2", "S1" }, { "S1", "SR" }, { "SR", "Q1" }, { "Q1", "NR" }, { "NR", "N2" }, { "N2", "AU" } },
        },
        -- orggate (2.0.8, M 15 Nov 2026: off the zeppelin in Durotar the
        -- arrow pointed at Orgrimmar through the cliff): the walk between
        -- the zeppelin tower's two feet and Orgrimmar's gate, the shortest
        -- one on the Kalimdor walking maps (the Forever
        -- client's navigation grid, read as data), cut down to its corners.
        -- toCity: only for a way into that city (its gate OG is the city
        -- roads' G2) or to a place right by these roads (reach yards: the
        -- zeppelin docks, coming out of the gate); anything else in Durotar
        -- is left alone.
        [1411] = {
            near = 150, reach = 40, toCity = 1454,
            gates = { "OG" },
            nodes = {
                A1 = { 0.5079, 0.1401 }, A2 = { 0.5055, 0.1413 }, A3 = { 0.4913, 0.1389 }, B1 = { 0.5047, 0.1247 }, K1 = { 0.4882, 0.1401 },
                K2 = { 0.4874, 0.1413 }, K3 = { 0.4850, 0.1413 }, K4 = { 0.4842, 0.1401 }, K5 = { 0.4756, 0.1271 }, K6 = { 0.4669, 0.1271 },
                M = { 0.4653, 0.1188 }, OG = { 0.4638, 0.0924 },
            },
            edges = {
                { "A1", "A2" }, { "A2", "A3" }, { "A3", "K2" }, { "B1", "K1" }, { "K1", "K2" }, { "K2", "K3" }, { "K3", "K4" }, { "K4", "K5" },
                { "K5", "K6" }, { "K6", "M" }, { "M", "OG" },
            },
        },
    }
    function Way.RoadAim(entry, plan, px, py, here)
        local map = PlayerMap()
        local net = map and Way.ROADS[map]
        if not net or not plan.x or not plan.y then
            entry.road = nil
            if not net then Way.ucFloor, entry.ucOuter, entry.ucTradeUp = nil, nil, nil end -- uclab, ucring: out of the city
            return nil
        end
        local tx, ty = plan.x, plan.y
        local memo = entry.road
        if memo and memo.map == map and memo.tx == tx and memo.ty == ty and memo.ride == (plan.ride and true or false)
            and Yards(px, py, memo.px, memo.py) < 3 then
            return memo.aim, memo.rest
        end
        local function Build(net, map)
            if net.w ~= nil then return end
            local w, adj = {}, {}
            for name, n in pairs(net.nodes) do
                local s = SpotWorld({ mapID = map, x = n[1], y = n[2] })
                if not s then w = false break end
                w[name] = s
            end
            if w then
                for _, e in ipairs(net.edges) do
                    local a, b = w[e[1]], w[e[2]]
                    local d = Yards(a[1], a[2], b[1], b[2])
                    adj[e[1]] = adj[e[1]] or {}
                    adj[e[2]] = adj[e[2]] or {}
                    adj[e[1]][e[2]], adj[e[2]][e[1]] = d, d
                    -- uclab: the stretches of the hall, of the lab under it, of the Trade Quarter
                    -- (ucring: and the Royal Quarter's ways apart from the bat handler's)
                    local function In(set) return set and (set[e[1]] or set[e[2]]) end
                    local function Tree(n) return n:sub(1, 1) == "F" and n ~= "FM" end
                    if In(net.tradeNodes) then e.group = "trade"
                    elseif In(net.hallNodes) then e.group = "hall"
                    elseif In(net.labNodes) then e.group = "lab"
                    elseif In(net.royalNodes) then e.group = "royal"
                    elseif net.royalNodes and (Tree(e[1]) or Tree(e[2])) then e.group = "fm" end
                end
                net.adj = adj
                for _, area in ipairs(net.areas or {}) do -- tbopen: the open rises' outlines in world yards
                    area.wpoly = {}
                    for i, p in ipairs(area.poly) do
                        local s = SpotWorld({ mapID = map, x = p[1], y = p[2] })
                        if not s then area.wpoly = nil break end
                        area.wpoly[i] = s
                    end
                end
            end
            net.w = w
        end
        Build(net, map)
        local w = net.w
        if not w then return nil end
        if w[net.gates[1]][3] ~= here then entry.road = nil return nil end
        -- The road nearest a place: its two ends, the point on it, how far.
        local function Nearest(x, y, net, w, skip, skip2, skip3, only) -- (orggate: another map's roads too; uclab: not the stretches of the other floor; ucring: nor the Trade Quarter's upper ring, nor the other place's ways; or only one group's)
            local best
            for _, e in ipairs(net.edges) do if not ((e.group and (e.group == skip or e.group == skip2 or e.group == skip3)) or (only and e.group ~= only)) then
                local a, b = w[e[1]], w[e[2]]
                local dx, dy = b[1] - a[1], b[2] - a[2]
                local len2 = dx * dx + dy * dy
                local t = 0
                if len2 > 0 then t = math.max(0, math.min(1, ((x - a[1]) * dx + (y - a[2]) * dy) / len2)) end
                local qx, qy = a[1] + t * dx, a[2] + t * dy
                local d = Yards(x, y, qx, qy)
                if not best or d < best.d then best = { d = d, a = e[1], b = e[2], qx = qx, qy = qy, group = e.group } end
            end end
            return best
        end
        local function Keep(aim, rest)
            entry.road = { map = map, tx = tx, ty = ty, px = px, py = py, ride = plan.ride and true or false, aim = aim, rest = rest }
            return aim, rest
        end
        -- uclab: the floor the player is on (the last of its marks passed),
        -- and whether the spot is down in the lab
        local skipP, skipT, skipNet, noIn
        if net.floorMarks then
            for floor, marks in pairs(net.floorMarks) do
                for name, r in pairs(marks) do
                    if Yards(px, py, w[name][1], w[name][2]) <= r then Way.ucFloor = floor end
                end
            end
            local labSpot = false
            for _, spot in ipairs(net.labSpots or {}) do
                local s = SpotWorld({ mapID = map, x = spot[1], y = spot[2] })
                if s and Yards(tx, ty, s[1], s[2]) <= 20 then labSpot = true end
            end
            skipT = labSpot and "hall" or "lab"
            if labSpot and Way.ucFloor ~= "lab" then noIn = net.labNotIn end -- labjoin
            local T0 = Nearest(tx, ty, net, w, skipT)
            local royal = T0 and net.targetNodes and (net.targetNodes[T0.a] or net.targetNodes[T0.b]) and true or false
            -- ucring: the bat handler's ways, or the Royal Quarter's
            if net.royalNodes then
                -- (ucfar: the bat handler by his own stretch up on the
                -- ring; the lower floor's ways run right under him and
                -- were the nearer ones for the game's own flight point)
                local F = net.farNodes and Nearest(tx, ty, net, w, nil, nil, nil, "trade")
                skipNet = (F and F.d <= 30 and (net.farNodes[F.a] or net.farNodes[F.b])) and "royal" or "fm"
            end
            -- not known (the arrow started here): the hall for a spot in the
            -- Royal Quarter, as before; the lab for any other
            if Way.ucFloor == "lab" then skipP = "hall" elseif Way.ucFloor == "hall" then skipP = "lab" else skipP = royal and "lab" or "hall" end
        end
        -- ucring: up on the Trade Quarter's ring or down under it (the last mark passed)
        local skipTrade
        if net.tradeUp then
            for name, r in pairs(net.tradeDown or {}) do
                if w[name] and Yards(px, py, w[name][1], w[name][2]) <= r then entry.ucTradeUp = nil end
            end
            for name, r in pairs(net.tradeUp) do
                if w[name] and Yards(px, py, w[name][1], w[name][2]) <= r then entry.ucTradeUp = true end
            end
            -- the arrow started right on the upper ring (by the bat handler)
            if not entry.ucTradeUp and not entry.ucOuter then
                local A = Nearest(px, py, net, w, skipP)
                if A and A.group == "trade" and A.d <= 4 then entry.ucTradeUp = true end
            end
            if not entry.ucTradeUp and skipNet == "royal" then skipTrade = "trade" end -- (the bat handler's way only)
        end
        local P = Nearest(px, py, net, w, skipP, skipTrade, skipNet)
        -- ucring: up on the ring, its own ways first (the lower floor's are under them)
        if net.tradeUp and entry.ucTradeUp and skipNet == "royal" then
            local up = Nearest(px, py, net, w, nil, nil, nil, "trade")
            if up and up.d <= 12 then P = up end
        end
        if not P or P.d > net.near then return Keep(nil) end -- not by the roads
        if net.ucDown and Way.UCUp and Way.UCUp(entry, px, py) then return Keep(nil) end -- ucroyal: up in the ruins
        if Yards(px, py, tx, ty) < (net.close or 40) -- (ucroyal: the dais's steps are 14 yards from Varimathras)
            and not (skipTrade and skipNet == "royal") then return Keep(nil) end -- (ucring: under the bat handler's platform, not by him)
        local T = Nearest(tx, ty, net, w, skipT, nil, skipNet, skipNet == "royal" and "trade" or nil) -- (ucring: the bat handler stands up on the ring)
        if net.onlyNear and (T.d > (net.targetNear or net.near) -- ucroyal: only for a spot by these ways
            or (net.targetNodes and not (net.targetNodes[T.a] or net.targetNodes[T.b]
                or (skipT == "hall" and T.group == "lab") -- uclab: a spot in the lab
                or (net.farNodes and (net.farNodes[T.a] or net.farNodes[T.b]))))) then return Keep(nil) end -- uclab: the bat handler
        if P.group == "lab" and T.group == "lab" and Yards(px, py, tx, ty) < 40 then return Keep(nil) end -- uclab: across the lab, straight
        -- uclab: to the bat handler from out in the city. (ucring: off an
        -- elevator too: they come down beside the Trade Quarter, its lower
        -- floor, and the bat handler is up its ramp.)
        if net.farNodes and (net.farNodes[T.a] or net.farNodes[T.b]) and P.group ~= "trade" then entry.ucOuter = true end
        -- tbopen (2.0.12): the open rise a place stands on
        local function Area(x, y)
            for _, area in ipairs(net.areas or {}) do
                local poly = area.wpoly
                if poly then
                    local inside, j = false, #poly
                    for i = 1, #poly do
                        local xi, yi, xj, yj = poly[i][1], poly[i][2], poly[j][1], poly[j][2]
                        if ((yi > y) ~= (yj > y)) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then inside = not inside end
                        j = i
                    end
                    if inside then return area end
                end
            end
        end
        local PA, TA = Area(px, py), (T.d <= (net.targetNear or net.near)) and Area(tx, ty) or nil
        if PA and PA == TA then return Keep(nil) end -- tbopen: across the same rise, straight
        -- flyride (2.0.9, M 16 Nov 2026 in the Valley of Strength, "Fly to
        -- Ratchet" to Scooty in Booty Bay, the arrow sending him back to
        -- the gate): a boat later on (plan.ride) is no way out of the city
        -- when a flight comes first: the flight master is the place to go.
        local outside = (plan.ride and not plan.fly and not net.docks) or T.d > (net.targetNear or net.near) -- (bbroads: Booty Bay's boat leaves from inside)
        if net.toCity then -- orggate
            outside = T.d > (net.reach or 0)
            if outside then
                -- only a way into the city itself
                local city = Way.ROADS[net.toCity]
                if (plan.ride and not plan.fly) or not city then return Keep(nil) end -- flyride (2.0.9)
                Build(city, net.toCity)
                local C = city.w and city.w[city.gates[1]][3] == here and Nearest(tx, ty, city, city.w)
                if not C or C.d > city.near then return Keep(nil) end
            end
        end
        if not outside and ((P.a == T.a and P.b == T.b) or (P.a == T.b and P.b == T.a)) then return Keep(nil) end -- the same stretch
        -- the shortest way along the roads, from where the player joins them
        local dist, prev, done = {}, {}, {}
        dist[P.a] = P.d + Yards(P.qx, P.qy, w[P.a][1], w[P.a][2])
        dist[P.b] = P.d + Yards(P.qx, P.qy, w[P.b][1], w[P.b][2])
        if PA then -- tbopen: on an open rise each of its corners is a straight walk away
            for _, name in ipairs(PA.nodes) do
                local d = w[name] and Yards(px, py, w[name][1], w[name][2])
                if d and (not dist[name] or d < dist[name]) then dist[name], prev[name] = d, nil end
            end
        end
        while true do
            local at, best
            for name, d in pairs(dist) do
                if not done[name] and (not best or d < best) then at, best = name, d end
            end
            if not at then break end
            done[at] = true
            for other, len in pairs(net.adj[at] or {}) do
                if not done[other] and not (noIn and noIn[at] == other) and (dist[other] == nil or best + len < dist[other]) then
                    dist[other], prev[other] = best + len, at
                end
            end
        end
        local goal, total
        if outside then
            for _, g in ipairs(net.gates) do
                if dist[g] then
                    local c = dist[g] + Yards(w[g][1], w[g][2], tx, ty)
                    if not total or c < total then goal, total = g, c end
                end
            end
        else
            local ends = { T.a, T.b }
            for _, name in ipairs(TA and TA.nodes or {}) do ends[#ends + 1] = name end -- tbopen
            for i, name in ipairs(ends) do
                if dist[name] and w[name] then
                    local c
                    if i > 2 then c = dist[name] + Yards(w[name][1], w[name][2], tx, ty) -- tbopen: straight across the target's rise
                    else c = dist[name] + Yards(w[name][1], w[name][2], T.qx, T.qy) + T.d end
                    if not total or c < total then goal, total = name, c end
                end
            end
        end
        if not goal then return Keep(nil) end
        -- bbroads (2.0.9): out past the gate (Booty Bay's tunnel, on the road
        -- north): not led back to it
        if outside and Yards(px, py, tx, ty) <= Yards(w[goal][1], w[goal][2], tx, ty) + 15 then return Keep(nil) end
        local way = {}
        local at = goal
        while at do
            table.insert(way, 1, at)
            at = prev[at]
        end
        -- the corners already reached are behind
        local i = 1
        while way[i] and Yards(px, py, w[way[i]][1], w[way[i]][2]) <= (net.pass or 10) do i = i + 1 end -- (ucroyal: the door 9 yards up the stairs is not passed)
        if not way[i] then return Keep(nil) end
        return Keep(w[way[i]], total - dist[way[i]])
    end
    -- forward (2.0.12, a route with forward = true: the ways round Dalaran):
    -- a point is also passed once the player is nearer the route's next
    -- point (the spot, after the last) than the point itself is, so a
    -- player who joins the route anywhere along it is not sent back.
    -- nearest (2.0.29, a route with nearest = true: a long way walked corner
    -- by corner, Razorfen Kraul's): the route is joined at the stretch
    -- nearest the player and followed from there, each point passed in turn;
    -- a point with maps = { [map] = true } only counts while the player
    -- stands on one of those maps (the points above the Great Lift and
    -- those below it lie over each other). Its points are passed closer by
    -- (route.reach, route.leg yards), so no corner is cut.
    local function RouteNext(route, done, px, py, here, faction, jumped, spotWorld)
        local worlds = route.nearest and route.fdjWorlds or nil
        if not worlds then
            worlds = {}
            local all = true
            for i, via in ipairs(route) do
                if type(via) == "table" and (not via.faction or via.faction == faction) then worlds[i] = SpotWorld(via) end
                if not worlds[i] then all = false end
            end
            if route.nearest and all then
                route.fdjWorlds = worlds
                -- What is left of the way from each point on (yards), for
                -- choosing between a spot's routes by the whole way.
                local rest, n = {}, #route
                rest[n] = (spotWorld and worlds[n] and spotWorld[3] == worlds[n][3]) and Yards(worlds[n][1], worlds[n][2], spotWorld[1], spotWorld[2]) or 0
                for i = n - 1, 1, -1 do
                    rest[i] = rest[i + 1] + Yards(worlds[i][1], worlds[i][2], worlds[i + 1][1], worlds[i + 1][2])
                end
                route.fdjRest = rest
            end
        end
        local map = nil
        if route.nearest then
            map = PlayerMap() or 0
            -- A point counts while the player stands on its level's maps.
            local function On(i)
                local w, via = worlds[i], route[i]
                return w ~= nil and w[3] == here and (not via.maps or via.maps[map] == true)
            end
            -- The stretch of the way the player is on: the nearest one, but
            -- the one walked last (or the next two) while still by it, so
            -- another part of the way coming close does not take over.
            local best, bestD, near, nearD
            for i = 1, #route do
                if On(i) then
                    local d = Yards(px, py, worlds[i][1], worlds[i][2])
                    if not nearD or d < nearD then near, nearD = i, d end
                    if On(i + 1) then
                        local ds = LegYards(px, py, worlds[i][1], worlds[i][2], worlds[i + 1][1], worlds[i + 1][2])
                        if not bestD or ds < bestD then best, bestD = i, ds end
                    end
                end
            end
            local at = (not jumped) and done.at or nil
            if at then
                local keep, keepD
                for i = at, math.min(at + 2, #route - 1) do
                    if On(i) and On(i + 1) then
                        local ds = LegYards(px, py, worlds[i][1], worlds[i][2], worlds[i + 1][1], worlds[i + 1][2])
                        if ds <= 25 and (not keepD or ds < keepD) then keep, keepD = i, ds end
                    end
                end
                if keep then best = keep end
            end
            done.at = best
            -- The points ahead, passed one after the other: by standing at
            -- one, or (on its own level) once past it.
            local k = (best or (near and near - 1) or 0) + 1
            while k <= #route do
                local w = worlds[k]
                if not (w and w[3] == here) then break end
                local passed = Yards(px, py, w[1], w[2]) <= (route.reach or VIA_REACHED)
                if not passed and On(k) then
                    local n = worlds[k + 1] or spotWorld
                    if n and n[3] == here then
                        passed = (worlds[k + 1] ~= nil and LegYards(px, py, w[1], w[2], n[1], n[2]) <= (route.leg or VIA_LEG))
                            or Yards(px, py, n[1], n[2]) < Yards(w[1], w[2], n[1], n[2])
                    end
                end
                if not passed then break end
                k = k + 1
            end
            if k > #route then return nil end
            -- smoothturn (2.0.37): the arrow does not aim at the next corner
            -- itself (passing beside it, it swung sideways for a moment) but
            -- at the way a little ahead: the place 12 yards further along it
            -- from where the player is on it, so it turns into each bend
            -- gently. Up to the end of the level (the lift) or of the way.
            if best and k <= best + 1 then
                local a, b = worlds[best], worlds[best + 1]
                local dx, dy = b[1] - a[1], b[2] - a[2]
                local len2 = dx * dx + dy * dy
                local t = len2 > 0 and math.max(0, math.min(1, ((px - a[1]) * dx + (py - a[2]) * dy) / len2)) or 0
                local cx, cy = a[1] + t * dx, a[2] + t * dy
                -- farahead (2.0.39): 12 yards only for a player on the way.
                -- Standing beside it (round a mob, along the other side of
                -- the road) those 12 yards lay almost straight across, and
                -- the arrow pointed sideways at the way instead of along it:
                -- from 4 yards off the way on, the place aimed at lies 2
                -- more yards ahead for each yard further off (40 at most:
                -- further ahead the straight line there left the walkable
                -- ground by the lift), so near the way the arrow leads along
                -- it and back onto it at a slant, and far off it, back to
                -- it. On the way itself nothing changes.
                local need, i = math.min(40, 12 + 2 * math.max(0, Yards(px, py, cx, cy) - 4)), best
                while true do
                    local n = worlds[i + 1]
                    local seg = Yards(cx, cy, n[1], n[2])
                    if seg >= need then
                        local aim = { cx + (n[1] - cx) * need / seg, cy + (n[2] - cy) * need / seg, n[3], map = n.map, region = n.region, ahead = seg - need }
                        return aim, route[i + 1]
                    end
                    need = need - seg
                    if not On(i + 2) then return n, route[i + 1] end
                    cx, cy, i = n[1], n[2], i + 1
                end
            end
            return worlds[k], route[k]
        end
        for i, via in ipairs(route) do
            if worlds[i] and via.climb and (jumped or ClimbCell(via.climb, px, py, here) == ".") then done[i] = nil end
        end
        local reached
        for i = #route, 1, -1 do
            local w, via = worlds[i], route[i]
            if w and w[3] == here then
                if via.climb then
                    if ClimbCell(via.climb, px, py, here) == "#"
                        or (tonumber(via.reach) and Yards(px, py, w[1], w[2]) <= tonumber(via.reach)) then
                        reached = i
                        break
                    end
                else
                    if Yards(px, py, w[1], w[2]) <= (route.reach or VIA_REACHED) then reached = i break end
                    local n
                    for j = i + 1, #route do if worlds[j] then n = worlds[j] break end end
                    -- nearest: the other level's points only by standing at them.
                    local level = not map or not via.maps or via.maps[map]
                    if level and n and n[3] == here and LegYards(px, py, w[1], w[2], n[1], n[2]) <= (route.leg or VIA_LEG) then reached = i break end
                    if route.forward and level then
                        local ahead = n or spotWorld
                        if ahead and ahead[3] == here and Yards(px, py, ahead[1], ahead[2]) < Yards(w[1], w[2], ahead[1], ahead[2]) then
                            reached = i
                            break
                        end
                    end
                end
            end
        end
        if reached then
            for i = 1, reached do done[i] = true end
        end
        for i, via in ipairs(route) do
            if not done[i] and worlds[i] then return worlds[i], via end
        end
        return nil
    end
    -- direct (2.0.12): a part of the map from where the straight line is
    -- the way ({ mapID, x0, y0, x1, y1 }: Lordamere Lake north-west of
    -- Dalaran): no point on the way for a player standing in it.
    -- gate (2.0.28): one place the way has to pass through, from certain
    -- zones only ({ gate = { mapID, x, y, label, fromMaps = { [map] = true } } }:
    -- the Great Lift between the Barrens and Thousand Needles). Standing on
    -- one of those maps the arrow leads to the gate, until the player is at
    -- it; on any other map (through it, or never behind it) straight on.
    local function NextVia(entry, px, py, here)
        -- buildingexit (2.0.13, M 19 Nov 2026 in the temple of Shen'dralas
        -- after Meeting the Magister, the arrow to Mithera through its walls:
        -- "it should point me to the exit, because the NPC is outside"): a
        -- building with one way out (FDJ.ARROW_EXITS: its middle, radius in
        -- yards, door): indoors in it, with the place to go outside it, the
        -- arrow leads to the door first.
        for _, exit in ipairs(FDJ.ARROW_EXITS or {}) do
            if type(exit) == "table" and PlayerMap() == exit.mapID and Indoors() then
                local c, door = SpotWorld(exit), SpotWorld(exit.door)
                local t = SpotWorld(FDJ.ArrowSpawn(entry) or entry.spot)
                local r = tonumber(exit.radius) or 60
                -- (to the door all the time indoors, up to the doorway: the
                -- arrow turns to the place only once outside, M 19 Nov 2026)
                if c and door and c[3] == here and door[3] == here and Yards(px, py, c[1], c[2]) <= r
                    and not (t and t[3] == here and Yards(t[1], t[2], c[1], c[2]) <= r)
                    and Yards(px, py, door[1], door[2]) > 5 then
                    return door, exit.door
                end
            end
        end
        local routes = ViaRoutes(entry)
        if not routes then return nil end
        -- (Inline: this file's main chunk is at Lua's limit of 200 locals.)
        local vias = FDJ.ARROW_VIAS and entry.spot and FDJ.ARROW_VIAS[SpotKey(entry.spot)]
        if type(vias) == "table" and type(vias.gate) == "table" then
            local gate = vias.gate
            if not (type(gate.fromMaps) == "table" and gate.fromMaps[PlayerMap() or 0]) then return nil end
            local w = SpotWorld(gate)
            if not w or w[3] ~= here or Yards(px, py, w[1], w[2]) <= VIA_REACHED then return nil end
            return w, gate
        end
        local box = type(vias) == "table" and vias.direct
        if type(box) == "table" then
            local a = SpotWorld({ mapID = box.mapID, x = box.x0, y = box.y0 })
            local b = SpotWorld({ mapID = box.mapID, x = box.x1, y = box.y1 })
            if a and b and a[3] == here and b[3] == here
                and px >= math.min(a[1], b[1]) and px <= math.max(a[1], b[1])
                and py >= math.min(a[2], b[2]) and py <= math.max(a[2], b[2]) then
                entry.viaRoute = nil
                return nil
            end
        end
        local target = SpotWorld(FDJ.ArrowSpawn(entry) or entry.spot) -- spawns: the place being tried
        local nearSpot = target and target[3] == here and Yards(px, py, target[1], target[2]) <= VIA_AT_SPOT
        local faction = Faction()
        entry.viaDone = entry.viaDone or {}
        local jumped = entry.viaX and Yards(px, py, entry.viaX, entry.viaY) > VIA_JUMP or false
        if jumped then entry.viaRoute = nil end
        -- A flight point newly found: the route is chosen afresh (flying
        -- there may now be the quicker way).
        if entry.viaLearned ~= flightsLearned then entry.viaRoute, entry.viaLearned = nil, flightsLearned end
        entry.viaX, entry.viaY = px, py
        local best, bestW, bestVia, bestD
        local playerMap = PlayerMap()
        for r, route in ipairs(routes) do
            -- zones (2.0.16): a route with zones = { [map] = true } (the
            -- Monastery's) is only for a player standing in one of them.
            if type(route) == "table" and not (type(route.zones) == "table" and not route.zones[playerMap or 0]) then
                if type(entry.viaDone[r]) ~= "table" then entry.viaDone[r] = {} end
                local w, via = RouteNext(route, entry.viaDone[r], px, py, here, faction, jumped, target)
                -- bynet (2.0.9, M 16 Nov 2026, on Stranglethorn's road 1,900
                -- yards south of the Rebel Camp: the arrow led back, to the
                -- nearest corner of a hand-made way far off to the side:
                -- "not only rely on these points that you made"): such a
                -- way (byNet) only leads a player who is by it; from
                -- further off the walking net leads to the place itself.
                if w and route.byNet and FDJ.WalkNetAim and w[3] == here
                    and Yards(px, py, w[1], w[2]) > ((r == entry.viaRoute) and 250 or 150) then
                    w, via = nil, nil
                end
                if not w and r == entry.viaRoute then return nil end -- the route followed is walked: the spot itself
                if w then
                    -- the way there on foot or by flight (Travel): from
                    -- Orgrimmar the Sun Rock Retreat route, by wind rider
                    local d = w[3] == here and Travel(here, px, py, w[1], w[2], playerMap, w.map) or Yards(px, py, w[1], w[2]) + FAR_ZONE * 10
                    -- nearest (2.0.29): a long way is chosen by all of it (to
                    -- its next point, then along it to the spot), not by how
                    -- near its next point is.
                    -- The stretch to its next point is off the way (a straight
                    -- line, over whatever lies between): counted two and a
                    -- half times; a next point on the other level (above or
                    -- below the Great Lift) is no way at all.
                    if route.nearest and route.fdjRest then
                        d = d * (route.off or 2.5) -- off (2.0.8): more where the straight line is a hillside (the Wetlands' ways)
                        for i = 1, #route do
                            if route[i] == via then d = d + (route.fdjRest[i] or 0) break end
                        end
                        if via.maps and not via.maps[playerMap or 0] then d = d + FAR_ZONE * 10 end
                    end
                    if r == entry.viaRoute then d = d * (route.nearest and 0.9 or VIA_SWITCH) end -- the route being followed keeps the arrow
                    if not bestD or d < bestD then best, bestW, bestVia, bestD = r, w, via, d end
                end
            end
        end
        entry.viaRoute = best
        -- Near the spot: straight to it, unless a climb comes first (the
        -- Messenger Bag is up on the wall, over the heads of those below).
        -- (dorncave, 2.0.13: nor a point with keep = true, the way up into a
        -- cave whose mouth is within those yards: Dorn Plainstalker's)
        if nearSpot and not (bestVia and (bestVia.climb or bestVia.keep)) then return nil end
        -- wholeway (2.0.34): what is left of the way after its next point
        -- (yards along its points to the spot), so the arrow can tell the
        -- distance to the spot itself, not to the next corner.
        if bestVia then
            local route, rest = routes[best], nil
            if route.fdjRest then
                for i = 1, #route do
                    if route[i] == bestVia then rest = route.fdjRest[i] + (bestW.ahead or 0) break end
                end
            else
                local prev, on = bestW, false
                rest = 0
                for _, v in ipairs(route) do
                    if v == bestVia then
                        on = true
                    elseif on and type(v) == "table" and (not v.faction or v.faction == faction) then
                        local w = SpotWorld(v)
                        if w and w[3] == prev[3] then
                            rest = rest + Yards(prev[1], prev[2], w[1], w[2])
                            prev = w
                        end
                    end
                end
                if target and target[3] == prev[3] then rest = rest + Yards(prev[1], prev[2], target[1], target[2]) end
            end
            entry.viaRest = rest
        end
        return bestW, bestVia
    end

    -- Distance (yards) and the turn from where the player faces to where the
    -- arrow points, and the plan (Plan above). nil: no position, or no way.
    -- spawns (2.0.36): a spot with several places it can be found
    -- (spot.spawns = { { x, y }, ... }, on the spot's map: Lonebrow's
    -- Journal): the arrow leads to the nearest not tried yet, kept once the
    -- player is within 150 yards of it; at it, "Not found? Next spot" sends
    -- it to the next (after the last, the first again).
    FDJ.ArrowSpawn = function(entry)
        local spot = entry and entry.spot
        local list = spot and spot.spawns
        if type(list) ~= "table" or #list < 2 then return nil end
        entry.spawnTried = entry.spawnTried or {}
        if not entry.spawnLocked or not entry.spawnAt then
            local px, py, here = PlayerWorld()
            local best, bestD
            for i, s in ipairs(list) do
                if not entry.spawnTried[i] then
                    local w = SpotWorld({ mapID = s.mapID or spot.mapID, x = s.x, y = s.y })
                    local d = (w and px and w[3] == here) and Yards(px, py, w[1], w[2]) or (1e9 + i)
                    if not bestD or d < bestD then best, bestD = i, d end
                end
            end
            if not best then entry.spawnTried, best, bestD = {}, 1, nil end
            entry.spawnAt = best
            if bestD and bestD < 150 then entry.spawnLocked = true end
        end
        entry.spawnSpots = entry.spawnSpots or {}
        local t = entry.spawnSpots[entry.spawnAt]
        if not t then
            local s = list[entry.spawnAt]
            t = { mapID = s.mapID or spot.mapID, x = s.x, y = s.y, label = spot.label, detail = spot.detail }
            entry.spawnSpots[entry.spawnAt] = t
        end
        return t
    end
    local function Measure(entry)
        local target = SpotWorld(FDJ.ArrowSpawn(entry) or entry.spot)
        if not target then return nil end
        local px, py, here = PlayerWorld()
        if not px then return nil end
        entry.viaRest = nil
        local viaWorld, via = NextVia(entry, px, py, here) -- arrowvia
        if viaWorld then target = viaWorld end
        -- Worked out again every half second, or sooner after a jump (a
        -- hearthstone, a landing).
        local now = (GetTime and GetTime()) or 0
        local plan = entry.plan
        local moved = entry.plannedX and Yards(px, py, entry.plannedX, entry.plannedY) or math.huge
        local region = Way.Region(here, PlayerMap(), px, py) -- way
        if plan == nil or now - (entry.plannedAt or 0) >= PLAN_EVERY or moved > 25 or (plan and plan.here ~= region) then
            -- flyfirst (2.0.33): a walked way (Razorfen Kraul's) is for
            -- walking. When a flight, boat or portal is the quicker way to
            -- the spot itself, that is taken first (from Theramore's dock
            -- the gryphon to Ratchet, not the long walk); the walked way
            -- is picked up again wherever the ride lands.
            local direct = (via and via.maps) and Plan(entry, px, py, here, SpotWorld(entry.spot)) or nil
            -- walkfirst (2.0.16, a route with walkfirst = true: the
            -- Monastery's): the flight master or dock to leave from lies
            -- further along the walked way (Chillwind Camp's gryphon, coming
            -- from the Monastery): the way is walked while it leads nearer
            -- to him (100 yards or more), not the straight line over the
            -- mountains; the flight is offered once he is near.
            if direct and (direct.fly or direct.ride) and not direct.atMaster and not direct.aboard and direct.x then
                local routes = ViaRoutes(entry)
                local route = routes and routes[entry.viaRoute or 0]
                local worlds = route and route.walkfirst and route.fdjWorlds
                local mine = Yards(px, py, direct.x, direct.y)
                if worlds and mine > 60 then
                    local at = 1
                    for i = 1, #route do
                        if route[i] == via then at = i break end
                    end
                    for i = at, #route do
                        local w = worlds[i]
                        if w and Yards(w[1], w[2], direct.x, direct.y) < mine - 100 then direct = nil break end
                    end
                end
            end
            -- flyahead (2.0.16, walkfirst routes): a flight that lands on
            -- the walked way ahead (Southshore to Chillwind Camp, on the
            -- way to the Monastery) is weighed by the way really left to
            -- walk, not the straight line: taken when it leaves less than
            -- FLY_WORTH of it.
            if via and via.maps and not (direct and (direct.fly or direct.ride or direct.aboard or direct.atMaster)) then
                local routes = ViaRoutes(entry)
                local route = routes and routes[entry.viaRoute or 0]
                local worlds = route and route.walkfirst and route.fdjWorlds
                local goal = worlds and SpotWorld(entry.spot)
                if goal and route.fdjRest and target then
                    local a, b = FlyCost(here, px, py, goal[1], goal[2], PlayerMap(), goal.map, region,
                        Way.Region(goal[3], goal.map, goal[1], goal[2]))
                    if a and b then
                        local at = 1
                        for i = 1, #route do
                            if route[i] == via then at = i break end
                        end
                        local walk = Yards(px, py, target[1], target[2]) + (entry.viaRest or route.fdjRest[at] or 0)
                        for i = at, #route do
                            local w = worlds[i]
                            if w and Yards(w[1], w[2], b[1], b[2]) <= 60 then
                                local flown = Yards(px, py, a[1], a[2]) + Yards(a[1], a[2], b[1], b[2]) / FLY_SPEED + FLY_EXTRA + route.fdjRest[i]
                                if flown < walk * FLY_WORTH then
                                    direct = { here = region, fly = b, flyFrom = a } -- flyfrom (2.1.3)
                                    if Yards(px, py, a[1], a[2]) <= AT_MASTER then
                                        direct.atMaster = true
                                    else
                                        direct.x, direct.y = a[1], a[2]
                                    end
                                    entry.fly = { a, b }
                                end
                                break
                            end
                        end
                    end
                end
            end
            if direct and (direct.fly or direct.ride or direct.aboard or direct.atMaster) then
                plan = direct
            else
                plan = Plan(entry, px, py, here, target) or false
                if plan and via then plan.via, plan.final = via, nil end -- arrowvia: not the spot itself yet
            end
            -- wholeway (2.0.34): walking to a point on the way (no ride or
            -- flight first): the rest of the way from it counts too.
            if plan then
                plan.rest = (plan.via and not plan.fly and not plan.ride) and entry.viaRest or nil
            end
            entry.plan, entry.plannedAt, entry.plannedX, entry.plannedY = plan, now, px, py
        end
        if not plan then return nil end
        if plan.aboard or plan.atMaster then
            plan.elevator = nil
            -- dockaim (2.0.11): at the tower, the turn to this ride's own dock
            if plan.aboard and plan.dockX and type(GetPlayerFacing) == "function" then
                local ok, facing = pcall(GetPlayerFacing)
                facing = ok and Number(facing) or nil
                if facing then return nil, math.atan2(plan.dockY - py, plan.dockX - px) - facing, plan end
            end
            return nil, nil, plan
        end
        local ax, ay = plan.x, plan.y
        local lift = Way.UndercityLift and Way.UndercityLift(entry, plan, px, py, here, SpotWorld(FDJ.ArrowSpawn(entry) or entry.spot)) -- ucelevator (2.0.7)
        plan.elevator = lift and true or nil
        if lift then ax, ay = lift[1], lift[2] end
        -- orgroads (2.0.8): in a city with its roads known, the next corner
        local road, roadRest
        if not lift and Way.RoadAim then road, roadRest = Way.RoadAim(entry, plan, px, py, here) end
        -- walknet (2.0.9, M 16 Nov 2026 in Westfall, the arrow to a tablet in
        -- Stranglethorn "wants me to go through the mountain"): a walk into
        -- another zone follows the continent's walking net, corner by corner
        -- (Systems/WalkNet.lua). A hand-made way (a via) keeps its own corners
        -- while the player is on it; a corner of it far off in another zone
        -- (M in Westfall again, "legit nothing changed": the tablet's own way
        -- starts in Stranglethorn, its nearest corner lay over the mountain)
        -- is walked to along the net like any place.
        -- walkgrid (2.0.9, M in the Ruins of Zul'Kunda: "It's just sending me
        -- through walls"): where a place's ground is known cell by cell, the
        -- arrow walks round its walls, to a hand-made way's near corner too
        -- (the last argument: only the cells may lead there, not the net).
        -- ucway (2.0.11): down into Undercity by the front door (no new
        -- local: this scope is at Lua's limit)
        plan.ucIn, plan.ucNet = nil, nil
        if not lift and not road and Way.UndercityIn then
            plan.ucIn, plan.ucNet = Way.UndercityIn(entry, plan, px, py, here, SpotWorld(FDJ.ArrowSpawn(entry) or entry.spot))
        end
        if plan.ucIn then
            if plan.ucNet and FDJ.WalkNetAim then road, roadRest = FDJ.WalkNetAim(entry, plan.ucIn[1], plan.ucIn[2], px, py, here, false) end
            if road then
                roadRest = (roadRest or 0) + Yards(plan.ucIn[1], plan.ucIn[2], plan.x, plan.y)
            else
                road, roadRest = plan.ucIn, Yards(plan.ucIn[1], plan.ucIn[2], plan.x, plan.y)
            end
        end
        if not lift and not road and FDJ.WalkNetAim and plan.x and plan.y
            and not (Way.ROADS[PlayerMap() or 0] or {}).noNet -- tbroads
            and not Way.SwimStraight(entry, plan, px, py) then -- swimstraight (2.1.3)
            road, roadRest = FDJ.WalkNetAim(entry, plan.x, plan.y, px, py, here, plan.via and Yards(px, py, plan.x, plan.y) <= 150 or false)
        end
        plan.road = road and true or nil
        if road then ax, ay = road[1], road[2] end
        plan.aimX, plan.aimY = ax, ay
        local distance = Yards(ax, ay, px, py) + (road and roadRest or 0)
        local turn
        if type(GetPlayerFacing) == "function" then
            local ok, facing = pcall(GetPlayerFacing)
            facing = ok and Number(facing) or nil
            if facing then turn = math.atan2(ay - py, ax - px) - facing end
        end
        return distance, turn, plan
    end

    local function FreeText(text)
        if type(text) ~= "string" then return nil end
        return FDJ.LocalizeFreeText and FDJ.LocalizeFreeText(text) or text
    end
    -- "Burned-Out Remains — Westfall" -> "Burned-Out Remains"
    local function SpotName(spot)
        local label = FreeText(spot.label) or ""
        return label:match("^(.-)%s+\226\128\148") or label
    end
    local function ZoneName(mapID)
        if not (C_Map and type(C_Map.GetMapInfo) == "function") then return "" end
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        local name = ok and type(info) == "table" and info.name or nil
        if type(issecretvalue) == "function" and issecretvalue(name) then name = nil end
        return type(name) == "string" and name or ""
    end
    local function QuestName(spot)
        local title = spot.questTitle
        if spot.markerType ~= "dungeon" and type(title) == "string" and title ~= "" then return title end
        return nil
    end
    -- What the NPC is called for /targetexact (nil: not an NPC).
    local function NPC(spot)
        -- (npclocation, 2.0.13, M 19 Nov 2026 targeting Rok'Alim, no picture on
        -- the arrow: a place on the map, not a quest giver's pin - no raid mark,
        -- no click macro - can still name the NPC met there: Grenka
        -- Bloodscreech in her cave, Rok'Alim on his path. Their picture and
        -- "Kill <name>" go by that name.)
        if spot and spot.markerType == "location" and type(spot.targetName) == "string" and spot.targetName ~= "" then return spot.targetName end
        if not spot or not IsTargetableNPCMarker(spot) then return nil end
        return QuestGiverName(spot)
    end
    -- How far below (-) or above (+) the ground around it the spot's NPC
    -- stands, in yards (nil: at ground level, or not known): FDJ.NPC_FLOORS
    -- (Data/QuestUpdates.lua), and all of Undercity, under the ruins.
    local FLOOR_MAPS = { [1458] = -100 }
    local function Floor(entry)
        if entry.floor ~= nil then return entry.floor or nil end
        local spot = entry.spot
        local found = FLOOR_MAPS[tonumber(spot.mapID) or 0] or false
        local here = SpotWorld(spot)
        if not found and here and type(FDJ.NPC_FLOORS) == "table" then
            local name, best = NPC(spot), nil
            for npc, list in pairs(FDJ.NPC_FLOORS) do
                for _, e in ipairs(list) do
                    if e[1] == here[3] then
                        local d = Yards(e[2], e[3], here[1], here[2])
                        if d <= (npc == name and 20 or 5) and (not best or d < best) then best, found = d, e[4] end
                    end
                end
            end
        end
        entry.floor = found
        return found or nil
    end

    -- getto (2.0.22): "Get to Dalaran" under the yards, while the spot is in a
    -- city or a named town and the player is not there yet. A spot out in
    -- the open says nothing: its zone alone would be too broad. The place:
    -- the city whose map the spot is on; else a town named in the spot's own
    -- label ("Magus Olvek — Dalaran") or detail; else the flight point
    -- right by it (the game's own name). Gone once inside: the city's map,
    -- the place's name as the game calls where one stands, or close by.
    Way.GET_TO_CITY = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }
    Way.GET_TO_PLACES = {
        "Dalaran", "Southshore", "Tarren Mill", "Hammerfall", "Refuge Pointe", "Kargath", "Ratchet",
        "The Crossroads", "Camp Taurajo", "Sen'jin Village", "Razor Hill", "Bloodhoof Village", "Brill",
        "The Sepulcher", "Pyrewood Village", "Kharanos", "Thelsamar", "Goldshire", "Darkshire", "Lakeshire",
        "Booty Bay", "Grom'gol Base Camp", "Rebel Camp", "Sentinel Hill", "Moonbrook", "Menethil Harbor",
        "Dun Modr", "Freewind Post", "Sun Rock Retreat", "Thalanaar", "Theramore", "Brackenwall Village",
        "Valormok", "Farholde Keep", "Rog'mar", "Bandarion Keep", "Chillwind Camp", "Light's Hope Chapel",
        "Aerie Peak", "Revantusk Village", "Nethergarde Keep", "Stonard", "Morgan's Vigil", "Flame Crest",
        "Thorium Point", "Gadgetzan", "Everlook", "Marshal's Refuge", "Nijel's Point", "Shadowprey Village",
        "Ghost Walker Post", "Camp Mojache", "Feathermoon Stronghold", "Astranaar", "Splintertree Post",
        "Auberdine", "Stonetalon Peak", "Talonbranch Glade", "Bloodvenom Post", "Nighthaven", "Cenarion Hold",
        "Dolanaar", "Stonewatch", "Raven Hill", "Westbrook Garrison", "Steamwheedle Port", "Mudsprocket",
    }
    Way.GET_TO_NODE = 200 -- yards: a flight point this close to the spot names its place
    Way.GET_TO_IN = 150   -- yards: this close to the spot counts as there
    Way.GET_TO_OUT = 220  -- yards: and this far, as gone again
    function Way.GetTo(entry)
        local spot = entry and entry.spot
        if type(spot) ~= "table" then return "" end
        -- (nogetto, 2.0.13, M 19 Nov 2026 on Rok'Alim's path: "Why does it
        -- say get to Thalanaar?": his path's far end is near that flight
        -- point, but the place to go is the path itself: spot.noGetTo)
        if spot.noGetTo then return "" end
        if entry.getTo == nil then
            local found = false
            local city = tonumber(spot.mapID)
            if city and Way.GET_TO_CITY[city] then
                local name = ZoneName(city)
                if name ~= "" then found = { name = name, city = city } end
            else
                local best
                local label = type(spot.label) == "string" and spot.label:match("\226\128\148%s*(.+)$") or nil
                for _, text in ipairs({ label or "", type(spot.detail) == "string" and spot.detail or "" }) do
                    local lower = string.lower(text)
                    for _, place in ipairs(Way.GET_TO_PLACES) do
                        if (not best or #place > #best) and string.find(lower, string.lower(place), 1, true) then best = place end
                    end
                    if best then break end
                end
                if best then
                    found = { name = FreeText(best) or best, english = best }
                else
                    local w = SpotWorld(spot)
                    local near
                    if w then
                        for _, node in ipairs(Way.AllNodes()) do
                            if node[3] == w[3] and type(node.name) == "string" and node.name ~= "" then
                                local d = Yards(node[1], node[2], w[1], w[2])
                                if d <= Way.GET_TO_NODE and (not near or d < near) then near, found = d, { name = node.name } end
                            end
                        end
                    end
                end
            end
            entry.getTo = found
        end
        local place = entry.getTo
        if not place then return "" end
        if place.city then
            local okMap, mapID = false, nil
            if C_Map and type(C_Map.GetBestMapForUnit) == "function" then okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player") end
            if okMap and Number(mapID) == place.city then return "" end
        else
            for _, fn in ipairs({ GetSubZoneText, GetMinimapZoneText, GetRealZoneText, GetZoneText }) do
                if type(fn) == "function" then
                    local okT, text = pcall(fn)
                    if okT and type(text) == "string" and text ~= "" and not (type(issecretvalue) == "function" and issecretvalue(text)) then
                        local lower = string.lower(text)
                        if string.find(lower, string.lower(place.name), 1, true)
                            or (place.english and string.find(lower, string.lower(place.english), 1, true)) then
                            return ""
                        end
                    end
                end
            end
            local w = SpotWorld(spot)
            local px, py, here = PlayerWorld()
            if w and px and here == w[3] then
                local d = Yards(px, py, w[1], w[2])
                if d <= Way.GET_TO_IN then entry.getToThere = true elseif d >= Way.GET_TO_OUT then entry.getToThere = nil end
            else
                entry.getToThere = nil
            end
            if entry.getToThere then return "" end
        end
        return FDJ.L("ARROW_GET_TO", place.name)
    end

    -- The plan's next thing to do, in words ("" when it is just walking).
    -- flyicon (2.0.8, M): "Fly to ..." starts with the cursor the game shows
    -- over a flight master (Interface\Cursor\Taxi). No new local here: this
    -- file is at Lua's limit of 200 locals in one scope.
    local function Doing(plan)
        if not plan then return "" end
        -- flyfrom (2.1.3, M 21 Nov 2026 at Aerie Peak, "Fly to Menethil
        -- Harbor": "I don't know which flight path it wants me to take"):
        -- on the way to the flight master, where the flight leaves from too.
        if plan.fly and plan.flyFrom and not plan.atMaster and type(plan.flyFrom.name) == "string" and plan.flyFrom.name ~= "" then
            return "|TInterface\\Cursor\\Taxi:0|t " .. FDJ.L("ARROW_FLY_FROM", plan.flyFrom.name, plan.fly.name or "")
        end
        if plan.fly then return "|TInterface\\Cursor\\Taxi:0|t " .. FDJ.L("ARROW_FLY", plan.fly.name or "") end
        local ride = plan.ride
        if not ride then -- arrowvia: the point on the way
            -- labelnear (2.1.1, the Dor'Danil Barrow Den's "Into the barrow
            -- den" not shown from Stonetalon): a point's label only within
            -- via.labelNear yards of it
            local via = plan.via
            if via and tonumber(via.labelNear) then
                local w = SpotWorld(via)
                local px, py, here = PlayerWorld()
                if not (w and px and w[3] == here and Yards(px, py, w[1], w[2]) <= tonumber(via.labelNear)) then return "" end
            end
            return via and FreeText(via.label) or ""
        end
        -- way: the place it lands at ("Rut'theran Village", "Auberdine").
        if not ride.toName or ride.toName == "" then ride.toName = Way.PlaceAt(ride.to[1], ride.to[2], ride.to[3]) end
        if ride.kind == "portal" then return FDJ.L("ARROW_PORTAL", ride.toName) end
        return FDJ.L(ride.kind == "zeppelin" and "ARROW_ZEPPELIN" or "ARROW_BOAT", ride.toName)
    end

    local manual          -- the spot last shown on the map
    local follows = {}    -- [source] = the spot a tracked chain page is at
    local shown           -- what the arrow points at now
    local frame
    -- spawns (2.0.36): "Not found? Next spot" (FDJ.ArrowSpawn, above).
    FDJ.NextArrowSpawn = function()
        local entry = shown
        local list = entry and entry.spot and entry.spot.spawns
        if type(list) ~= "table" then return end
        entry.spawnTried = entry.spawnTried or {}
        if entry.spawnAt then entry.spawnTried[entry.spawnAt] = true end
        local left = false
        for i = 1, #list do if not entry.spawnTried[i] then left = true end end
        if not left then entry.spawnTried = { [entry.spawnAt or 1] = true } end
        entry.spawnLocked, entry.spawnAt = nil, nil
        entry.plan, entry.plannedAt, entry.viaRoute = nil, nil, nil
        local f = _G.ForeverDungeonJournalArrow
        if f then f.fdjWait = 0 end -- redrawn on the next frame
    end
    local Choose

    local function Reached(entry)
        if not entry then return end
        if entry.source == "manual" then
            if manual == entry then manual = nil end
        else
            Done()[entry.source] = entry.key
        end
        Choose()
    end

    -- Right-click: a chain followed since Show on Map (1.9.9, not tracked)
    -- stops, its spot shown on the map and all; else as when reached (a
    -- tracked chain's spot steps aside until its next step).
    local function Dismiss(entry)
        if not entry then return end
        if entry.source == "corpse" then -- corpserun: hidden until alive again
            Way.corpseOff = true
            Choose()
            return
        end
        local chain = entry.chain or (entry.source ~= "manual" and entry.source) or nil
        if chain and FDJ.StopChainArrow and FDJ.StopChainArrow(chain) then
            if manual and (manual == entry or manual.chain == chain) then manual = nil end
            follows[chain] = nil
            Choose()
            return
        end
        Reached(entry)
    end

    -- A click targets and marks the NPC (the map pins' own macro), set up
    -- out of combat only (the click does nothing in combat).
    local NOTHING = { markerType = "location" }
    local function ClickTargets(f, spot)
        if not f._fdjCanTarget then return end
        local name = NPC(spot)
        local key = name and (name .. "|" .. tostring(spot.raidMarkIndex)) or ""
        if key == f.fdjClickKey then return end
        if InCombatLockdown and InCombatLockdown() then return end
        ConfigureTargetAndMarkAction(f, name and spot or NOTHING, false)
        f.fdjClickKey = key
        f.fdjTargets = name ~= nil -- a left-click targets the NPC (and does not open the map)
    end

    -- flybar (2.1.1): the flight's bar (and icon, unless keepIcon) away, the
    -- way line back under the yards.
    function Way.FlyBarOff(f, keepIcon)
        if f.taxiBar and f.taxiBar:IsShown() then f.taxiBar:Hide() end
        if f.taxiIcon and not keepIcon and f.taxiIcon:IsShown() then f.taxiIcon:Hide() end
        if f.fdjRouteOnBar then
            f.route:ClearAllPoints()
            f.route:SetPoint("TOP", f.distance, "BOTTOM", 0, -2)
            f.fdjRouteOnBar = nil
        end
    end
    local function Redraw(f)
        local entry = shown
        if not entry then
            f:Hide()
            return
        end
        local inside = InInstance()
        if not inside and OnTaxi() then
            -- In the air: how long the flight still takes (as long as it took
            -- last time; a guess the first time; else the time so far).
            ClickTargets(f, nil)
            f.arrow:Hide()
            if f.swords then f.swords:Hide() end -- killswords
            if f.fdjHidden then
                f.fdjHidden = false
                f:SetAlpha(1)
                f:EnableMouse(true)
            end
            local now = (GetTime and GetTime()) or 0
            if not flight then Watch({ at = now }) end
            flight.up = flight.up or now
            local gone = now - flight.up
            local took = flight.from and flight.to and FlightTimes()[flight.from .. ">" .. flight.to]
            -- Past the count-down's end (a slower flight than thought):
            -- nothing, not 0:00 for the rest of the way.
            -- flybar (2.1.1): the time left as the yellow bar emptying (and on
            -- it), the flight master icon where the arrow was. No time to go
            -- by (a flight never timed nor guessed): the time so far, as before.
            local total = (type(took) == "number" and took) or (type(flight.guess) == "number" and flight.guess) or nil
            if f.taxiIcon then f.taxiIcon:Show() end
            if f.taxiBar and total and total > 0 then
                local left = total - gone
                f.taxiBar.bar:SetValue(math.max(0, math.min(1, left / total)))
                f.taxiBar.text:SetText(left >= 0 and ((type(took) == "number" and "" or "~") .. Clock(left)) or "")
                f.taxiBar:Show()
                f.distance:SetText("")
                if not f.fdjRouteOnBar then
                    f.route:ClearAllPoints()
                    f.route:SetPoint("TOP", f.taxiBar, "BOTTOM", 0, -3)
                    f.fdjRouteOnBar = true
                end
            else
                Way.FlyBarOff(f, true)
                if type(took) == "number" then
                    f.distance:SetText(took - gone >= 0 and Clock(took - gone) or "")
                elseif flight.guess then
                    f.distance:SetText(flight.guess - gone >= 0 and ("~" .. Clock(flight.guess - gone)) or "")
                else
                    f.distance:SetText(Clock(gone))
                end
            end
            f.route:SetText(flight.to and FDJ.L("ARROW_FLYING", PlaceName(flight.to)) or "")
            f.hearth:SetText("")
            if f.skipNow then f.skipNow:Hide() end -- skipnow
            return
        end
        Way.FlyBarOff(f) -- flybar: landed
        local distance, turn, plan
        if not inside then distance, turn, plan = Measure(entry) end
        local final = plan and plan.final and not plan.elevator and not plan.road -- ucelevator, orgroads: at the elevator / a corner is not at the spot
        -- An NPC under the ground (or up a tower): standing over them outside
        -- is not there yet.
        local floor = final and distance and distance <= FLOOR_NEAR and Floor(entry) or nil
        local below = floor ~= nil and floor < 0 and not Indoors()
        local above = floor ~= nil and floor > 0
        -- spawns (2.0.36): standing at one of a spot's places: the arrow stays,
        -- with "Not found? Next spot" under it.
        local spawnHere = type(entry.spot.spawns) == "table" and #entry.spot.spawns > 1
            and distance ~= nil and final and not below and distance <= ARRIVED + 4 or false
        if distance and final and not below and distance <= ARRIVED and entry.source == "manual" and not spawnHere then
            Reached(entry)
            return
        end
        -- A chain's spot steps out of the way while the player stands at it,
        -- and comes back if they walk off before the step moves on.
        local near = distance ~= nil and final and not below and (distance <= ARRIVED or (f.fdjNear and distance <= ARRIVED + 4)) or false
        f.fdjNear = near
        -- questrp (2.0.8): while the NPC's scene runs, the arrow stays at him
        local hide = inside or (near and not spawnHere and not (FDJ.ArrowRPWait and FDJ.ArrowRPWait(NPC(entry.spot))))
        if f.skipNow then f.skipNow:SetShown(entry.spot.skipQuest ~= nil and not inside) end -- skipnow (2.0.13)
        if f.nextSpawn then
            f.nextSpawn:SetShown(spawnHere and not inside)
            if spawnHere then
                f.nextSpawn:SetText(FDJ.L("ARROW_NEXT_SPAWN", (entry.spawnAt or 1) + 1 > #entry.spot.spawns and 1 or (entry.spawnAt or 1) + 1, #entry.spot.spawns))
            end
        end
        -- goalhere (2.0.9, M 16 Nov 2026): at the place to kill / collect the
        -- arrow stays, standing right at its spot too.
        if type(entry.spot.goalLines) == "table" then hide = inside end
        -- pickup (2.0.9, M 16 Nov 2026 at the tablets: "I don't like how the
        -- arrow disappears when reaching a pick up item, it should just
        -- switch to text: Pick it up"): at a thing to pick up the arrow stays.
        if entry.spot.pickUp then hide = inside end
        -- talkto (2.0.9, M 16 Nov 2026 at Nogg and Sovik in Orgrimmar, two
        -- quest givers side by side: "Let's just stop making the arrow
        -- disappear ... once we are close, just have the explanation of
        -- what we have to do ... talk to X NPC"): the arrow no longer goes
        -- away at its spot; there it says who to talk to.
        hide = inside
        if hide ~= f.fdjHidden then
            f.fdjHidden = hide
            f:SetAlpha(hide and 0 or 1)
            f:EnableMouse(not hide)
        end
        ClickTargets(f, (not hide and final and distance and distance <= NEAR_NPC) and entry.spot or nil)
        if FDJ.ArrowItemButton then FDJ.ArrowItemButton(f, (not hide) and entry.spot or nil) end -- arrowitem (2.0.13)
        -- npcicon (2.0.13)
        if f.npc then
            -- (seenportrait, 2.0.13: a spot with seenPortrait = true - Rok'Alim on
            -- his patrol - shows the NPC's picture as soon as the game shows him
            -- (target, mouseover, nameplate), wherever the arrow's spot is)
            local on = ((f.fdjTargets or (entry.spot.seenPortrait and FDJ.ArrowNpcSeen and FDJ.ArrowNpcSeen(f, NPC(entry.spot)))) and not hide) and true or false
            if on ~= (f.fdjNpcOn or false) then
                f.fdjNpcOn, f.fdjNpcUnit, f.fdjNpcAt = on, nil, nil
                f.npc:SetShown(on)
                f.title:SetText((on and "" or (f.fdjMark or "")) .. (f.fdjName or ""))
                -- npcbig (2.0.16): the picture is bigger (32, was 22), left of the
                -- name and level with it; a short name moves it out past the
                -- line under it (FDJ.ArrowPlacePicture), so the two never overlap.
                f.fdjPicKey = nil
                FDJ.ArrowPlacePicture(f, on)
                -- npchover (2.0.16, picture only 2.0.17): the mouse already on the
                -- arrow when the NPC comes in reach (or goes): the next frame's
                -- check picks the glow (on the picture) or the tooltip again,
                -- the tooltip rebuilt for the new click.
                if f.npcHl and not on then f.npcHl:Hide() end
                f.fdjHoverState = nil
            end
            -- portraitfirst (2.0.14): the NPC's portrait before any click, as the
            -- journal's boss portraits are made: a hidden model of the NPC
            -- (FDJ.ARROW_NPC_IDS, by name) tells its display, whose portrait
            -- the game draws. Looked up as soon as the arrow leads to the NPC,
            -- so it is there by the time the NPC is in reach.
            do
                local npcID = FDJ.ARROW_NPC_IDS and FDJ.ARROW_NPC_IDS[NPC(entry.spot) or ""]
                FDJ.arrowDisplayIDs = FDJ.arrowDisplayIDs or {}
                -- loadpause (2.0.7): not during a loading screen or the first
                -- seconds after it (FDJ.PauseArrowLookup puts the model away).
                -- portraitretry (2.0.18): a look another page already learned
                -- (saved) is used at once; a lookup that gave up is tried again
                -- half a minute later instead of never.
                if npcID and FDJ.arrowDisplayIDs[npcID] == nil and type(ForeverDungeonJournalDB) == "table"
                    and type(ForeverDungeonJournalDB.displayIDs) == "table"
                    and tonumber(ForeverDungeonJournalDB.displayIDs[npcID]) then
                    FDJ.arrowDisplayIDs[npcID] = tonumber(ForeverDungeonJournalDB.displayIDs[npcID])
                    f.fdjNpcUnit, f.fdjNpcAt = nil, nil
                end
                if npcID and FDJ.arrowDisplayIDs[npcID] == false and FDJ.arrowDisplayRetry
                    and ((GetTime and GetTime()) or 0) >= (FDJ.arrowDisplayRetry[npcID] or math.huge) then
                    FDJ.arrowDisplayIDs[npcID], FDJ.arrowDisplayRetry[npcID] = nil, nil
                end
                if npcID and FDJ.arrowDisplayIDs[npcID] == nil and type(SetPortraitTextureFromCreatureDisplayID) == "function"
                    and not (FDJ.LookupsPaused and FDJ.LookupsPaused()) then
                    local now = (GetTime and GetTime()) or 0
                    if f.fdjResolving ~= npcID then
                        f.fdjResolving, f.fdjResolveAt, f.fdjResolveTries = npcID, now, 1
                        -- ownmodel (2.0.13, M 19 Nov 2026: Mithera's arrow with
                        -- Magister Kirandis's face): each lookup its own hidden
                        -- model (FDJ.ArrowTakeModel), so the last NPC's model
                        -- still loading can no longer be read as this one's.
                        FDJ.ArrowFreeModel(f)
                        f.model = FDJ.ArrowTakeModel()
                        FDJ.arrowLookupFrame = f
                        if f.model then
                            f.model:Show()
                            if f.model.ClearModel then pcall(f.model.ClearModel, f.model) end
                            FDJ.ArrowModelAsk(f.model) -- arrowsafe
                            if not pcall(f.model.SetCreature, f.model, npcID) then FDJ.arrowDisplayIDs[npcID] = false end
                        else
                            FDJ.arrowDisplayIDs[npcID] = false
                        end
                    elseif f.model then
                        local okD, display = pcall(f.model.GetDisplayInfo, f.model)
                        if okD and type(display) == "number" and display > 0 and FDJ.ArrowModelGood(f.model, display) then -- arrowsafe
                            FDJ.arrowDisplayIDs[npcID] = display
                            f.fdjResolving, f.fdjNpcUnit, f.fdjNpcAt = nil, nil, nil
                            if type(ForeverDungeonJournalDB) == "table" then -- portraitretry: kept for next time
                                ForeverDungeonJournalDB.displayIDs = ForeverDungeonJournalDB.displayIDs or {}
                                ForeverDungeonJournalDB.displayIDs[npcID] = display
                            end
                            FDJ.ArrowFreeModel(f) -- ownmodel
                        elseif now - (f.fdjResolveAt or now) >= 2.5 then
                            -- portraitretry (2.0.18): ask again, as the trash mob
                            -- portraits do: an NPC this client has not met comes
                            -- in a moment after the server answers, and one ask
                            -- was never answered. 12 asks, then the mark for
                            -- half a minute and the asking starts over.
                            f.fdjResolveTries = (f.fdjResolveTries or 1) + 1
                            f.fdjResolveAt = now
                            local asked = false
                            if f.fdjResolveTries <= 12 then
                                if f.model.ClearModel then pcall(f.model.ClearModel, f.model) end
                                FDJ.ArrowModelAsk(f.model) -- arrowsafe
                                asked = pcall(f.model.SetCreature, f.model, npcID)
                            end
                            if not asked then
                                FDJ.arrowDisplayIDs[npcID] = false -- the mark meanwhile
                                FDJ.arrowDisplayRetry = FDJ.arrowDisplayRetry or {}
                                FDJ.arrowDisplayRetry[npcID] = now + 30
                                f.fdjResolving = nil
                                FDJ.ArrowFreeModel(f) -- ownmodel
                            end
                        end
                    end
                end
            end
            if on then
                local now = (GetTime and GetTime()) or 0
                if not f.fdjNpcAt or now - f.fdjNpcAt >= 0.5 then
                    f.fdjNpcAt = now
                    local name = NPC(entry.spot)
                    local unit
                    local function Is(token)
                        if type(token) ~= "string" or type(UnitExists) ~= "function" then return false end
                        local okE, exists = pcall(UnitExists, token)
                        if not okE or not exists then return false end
                        local okN, unitName = pcall(UnitName, token)
                        if not okN or type(unitName) ~= "string" then return false end
                        if type(issecretvalue) == "function" and issecretvalue(unitName) then return false end
                        return unitName == name
                    end
                    if name then
                        if Is("target") then unit = "target" elseif Is("mouseover") then unit = "mouseover" end
                        if not unit and C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" then
                            local okP, plates = pcall(C_NamePlate.GetNamePlates)
                            for _, plate in ipairs(okP and type(plates) == "table" and plates or {}) do
                                local token = plate and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)) -- (arrowsafe: either)
                                if Is(token) then unit = token break end
                            end
                        end
                    end
                    local npcID = name and FDJ.ARROW_NPC_IDS and FDJ.ARROW_NPC_IDS[name]
                    if unit and npcID and FDJ.ArrowLearnFromUnit then FDJ.ArrowLearnFromUnit(npcID, unit) end -- arrowsafe
                    local display = npcID and FDJ.arrowDisplayIDs and FDJ.arrowDisplayIDs[npcID] or nil
                    local key = unit or (display and ("display" .. display)) or "none"
                    if key ~= f.fdjNpcUnit or unit then
                        f.fdjNpcUnit = key
                        local drawn = false
                        if unit and type(SetPortraitTexture) == "function" then
                            f.npc:SetTexCoord(0, 1, 0, 1)
                            drawn = pcall(SetPortraitTexture, f.npc, unit)
                        end
                        if not drawn and display then -- portraitfirst
                            f.npc:SetTexCoord(0, 1, 0, 1)
                            drawn = pcall(SetPortraitTextureFromCreatureDisplayID, f.npc, display)
                        end
                        -- objectmark (2.1.3, M 21 Nov 2026 at the Battered Dwarven
                        -- Skeleton: "when I get close to items on the floor that I have
                        -- to click to complete the quest ... I get the raid mark. I don't
                        -- like it. The raid mark should just be the yellow question mark
                        -- to turn in the quest itself"): a thing to click, no NPC (none
                        -- of that name in FDJ.ARROW_NPC_IDS; a raid mark can't go on
                        -- it): the quest's own mark, big, in place of the picture - the
                        -- yellow ? where it is handed in, the ! where it starts, the
                        -- blue ? of a repeatable - and nothing where it is only clicked.
                        if not drawn and not npcID then
                            local art = type(f.fdjMark) == "string" and f.fdjMark:match("^|T(.-):") or nil
                            if art then
                                f.npc:SetTexture(art)
                                f.npc:SetTexCoord(0, 1, 0, 1)
                                f.npc:Show()
                            else
                                f.npc:Hide()
                            end
                        elseif not drawn then
                            local index = entry.spot.raidMarkIndex or RaidMarkIndexForTarget(entry.spot)
                            if tonumber(index) then
                                f.npc:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. tonumber(index))
                            else
                                f.npc:SetTexture("Interface\\CharacterFrame\\TempPortrait")
                            end
                            f.npc:SetTexCoord(0, 1, 0, 1)
                        end
                    end
                end
            end
        end
        if hide then return end
        local doing = Doing(plan)
        -- routeauto (2.0.8): the flight the arrow says to take, for
        -- Systems/RouteAuto.lua (no new local: this scope is at Lua's limit).
        FDJ.arrowFly, FDJ.arrowFlyAt = plan and plan.fly or nil, (GetTime and GetTime()) or 0
        -- lootitem (2.0.36): the item that starts the quest is in the bags
        -- but the quest is not taken yet: say to use it.
        local use = entry.spot.useItem
        if type(use) == "table" and (doing == nil or doing == "") then
            doing = "|cff59ff59" .. FDJ.L("ARROW_USE_ITEM", FreeText(use[2]) or use[2]) .. "|r"
        end
        -- way: the hearthstone, when it is the quicker way: a line of its
        -- own under the next step (or in its place when there is none).
        local hearth = plan and plan.hearth and FDJ.L("ARROW_HEARTH", plan.hearth) or ""
        if plan and (plan.aboard or plan.atMaster) then
            f.distance:SetText(doing)
            f.route:SetText("")
            f.hearth:SetText("")
        elseif distance then
            -- wholeway (2.0.34): on a way walked point by point, the yards
            -- to the spot itself along it, not to the next corner (to the
            -- flight master or the dock when a ride comes first, as before).
            f.distance:SetText(FDJ.L("ARROW_DISTANCE", math.floor(distance + ((plan and plan.rest) or 0) + 0.5)))
            -- upstairs (2.0.8): an NPC up the stairs (FDJ.NPC_UPSTAIRS), once
            -- its portrait shows: "Go upstairs" (no new local: at Lua's limit)
            local step = (below and FDJ.L("ARROW_BELOW")) or (above and FDJ.L("ARROW_ABOVE"))
                or (FDJ.ArrowRPWait and FDJ.ArrowRPWait(NPC(entry.spot))) -- questrp (2.0.8)
                or (f.fdjNpcOn and FDJ.NPC_UPSTAIRS and FDJ.NPC_UPSTAIRS[NPC(entry.spot) or ""] and FDJ.L("ARROW_GO_UP")) or doing
            -- hearthfirst (2.0.13, M 19 Nov 2026 in Dalaran, "Fly to Undercity"
            -- over "Hearth to Freewind Post": "one might get confused ... let's
            -- just always use the option that's faster first"): the hearthstone
            -- the quicker way: that line alone, in place of the way's own (the
            -- flight, the boat, where to get to); the way shows when it is on
            -- cooldown or no quicker.
            if hearth ~= "" then step, hearth = "|cff8fd0ff" .. hearth .. "|r", "" end
            -- getto (2.0.22): the place to get to, on its own line under the
            -- yards, the next step (if any) under it.
            local getTo = Way.GetTo(entry)
            -- onedest (2.0.7): "Take the zeppelin to Orgrimmar" / "Fly to
            -- Undercity" already names where to: no "Get to Orgrimmar" over
            -- it. It shows again once the ride or flight is behind.
            if plan and (plan.fly or plan.ride or plan.hearth) then getTo = "" end -- (hearthfirst: nor over the hearthstone)
            if plan and plan.elevator and not plan.hearth then
                -- ucelevator (2.0.7): the ride first, how to get out under it
                local lift = FDJ.L("ARROW_ELEVATOR")
                step = (step ~= "" and (step .. "\n" .. lift)) or lift
            elseif getTo ~= "" then
                step = (step ~= "" and (getTo .. "\n" .. step)) or getTo
            end
            f.route:SetText(step)
            f.hearth:SetText(hearth)
        else
            f.distance:SetText(entry.zone)
            f.route:SetText(Way.GetTo(entry)) -- getto (2.0.22)
            f.hearth:SetText("")
        end
        -- goalhere (2.0.9): there: what to kill / collect in place of the
        -- yards (as the tracker shows it), nothing about the way; the arrow
        -- keeps pointing into the area (not while standing on its spot).
        if type(entry.spot.goalLines) == "table" then
            f.distance:SetText(#entry.spot.goalLines > 0 and table.concat(entry.spot.goalLines, "\n") or (FreeText(entry.spot.detail) or ""))
            f.route:SetText("")
            f.hearth:SetText("")
            FDJ.arrowFly = nil
            -- nopointhere (2.0.9, M 16 Nov 2026 at the Balia'mah Ruins, Troll
            -- Witchery's trolls in front of him: "my character is literally
            -- facing where he has to go, but the arrow points to go back"):
            -- the place is an area (its spot is only the middle of where the
            -- mobs stand, here 200 yards behind him), so inside it nothing
            -- points anywhere: the name and what to kill / collect only.
            turn = nil
        end
        -- pickup (2.0.9): standing at a thing to pick up: "Pick it up" in
        -- place of the yards, no pointer. swimunder (2.0.9, M at The Second
        -- Troll Legend, on the bottom of the Vile Reef: "here it should say
        -- Swim underwater, once water has been reached"): a thing lying under
        -- water, the player in the water and near it: "Swim underwater" under
        -- the yards, and over "Pick it up" right above it.
        if entry.spot.pickUp and not inside and not (type(entry.spot.goalLines) == "table") then
            if entry.spot.underwater and distance and distance <= 150
                and type(IsSwimming) == "function" and select(2, pcall(IsSwimming)) == true then
                if near then
                    -- divedown (M over the tablet, "it's telling me to pick it up
                    -- now but I'm still so far up in the water"): the game tells
                    -- an addon no height, so over the thing it says to dive, and
                    -- where to pick it up, not that it is in reach.
                    f.distance:SetText("|cff8fd0ff" .. FDJ.L("ARROW_DIVE_DOWN") .. "|r\n|cff59ff59" .. FDJ.L("ARROW_PICK_UP_BOTTOM") .. "|r")
                    f.route:SetText("")
                    f.hearth:SetText("")
                    turn = nil
                else
                    f.route:SetText("|cff8fd0ff" .. FDJ.L("ARROW_SWIM_UNDER") .. "|r")
                end
            elseif near then
                f.distance:SetText("|cff59ff59" .. FDJ.L("ARROW_PICK_UP") .. "|r")
                f.route:SetText("")
                f.hearth:SetText("")
                turn = nil
            end
        end
        -- talkto (2.0.9): at the spot of an NPC: "Talk to <NPC>" in place
        -- of the yards, no pointer (not while the NPC's scene runs, at a
        -- place to kill / collect, a thing to pick up or one of several
        -- places to look).
        if near and not inside and not spawnHere and not entry.spot.pickUp and type(entry.spot.goalLines) ~= "table"
            and NPC(entry.spot) and not (FDJ.ArrowRPWait and FDJ.ArrowRPWait(NPC(entry.spot))) then
            -- arrowkill (2.0.13, M 18 Nov 2026 at Ricter: "these NPCs need to be killed, so the text should not be talk to"): a spot with kill = true
            f.distance:SetText("|cff59ff59" .. FDJ.L(entry.spot.kill and "ARROW_KILL" or "ARROW_TALK_TO", FreeText(NPC(entry.spot)) or NPC(entry.spot)) .. "|r")
            f.route:SetText("")
            f.hearth:SetText("")
            turn = nil
        end
        -- swimplace (2.1.3, M 21 Nov 2026 swimming to the Drowned City's
        -- cavern for Locating the Lost City: "It should say swim underwater,
        -- by the way"): a place under water that is no thing to pick up
        -- (spot.underwater): swimming within 150 yards of it, "Swim
        -- underwater" under the yards.
        if entry.spot.underwater and not entry.spot.pickUp and not inside
            and not (type(entry.spot.goalLines) == "table") and distance and distance <= 150
            and type(IsSwimming) == "function" and select(2, pcall(IsSwimming)) == true then
            f.route:SetText("|cff8fd0ff" .. FDJ.L("ARROW_SWIM_UNDER") .. "|r")
        end
        -- upstairs (2.0.13, M 18 Nov 2026 at Kegan Darkmar, on the upper floor
        -- of the camp's big house: "if the arrow could understand that we
        -- need to get upstairs"): the game tells an addon no height, so a
        -- spot with upstairs = true says so near it: "Go upstairs" under the
        -- yards, and over "Kill <name>" at the spot itself.
        -- upnpc (2.1.1, M 20 Nov 2026 in Farholde Keep under Ashe Amberhall:
        -- "here it should say to go upstairs"): an NPC of FDJ.NPC_UPSTAIRS
        -- gets it too, whichever of the NPC's spots the arrow leads to.
        if (entry.spot.upstairs or (FDJ.NPC_UPSTAIRS and FDJ.NPC_UPSTAIRS[NPC(entry.spot) or ""]))
            and not inside and distance and distance <= 60 then
            if near then
                f.distance:SetText("|cff8fd0ff" .. FDJ.L("ARROW_UPSTAIRS") .. "|r\n" .. (f.distance:GetText() or ""))
            else
                f.route:SetText("|cff8fd0ff" .. FDJ.L("ARROW_UPSTAIRS") .. "|r")
            end
        end
        -- spothint (2.0.13, M 18 Nov 2026 at the Warden's Footlocker: "it
        -- should say open the box in the house for the key"): a spot's own
        -- line (spot.hint), near it: under the yards, and over "Pick it up"
        -- at the spot itself.
        -- grouphint (2.0.13): a line shown at any distance (spot.hintAlways), over the yards
        -- (plankjump, 2.0.13: spot.hintKey, the line in the player's language)
        if (type(entry.spot.hint) == "string" or entry.spot.hintKey) and not inside and distance and (distance <= 60 or entry.spot.hintAlways) then
            if near or entry.spot.hintAlways then
                f.distance:SetText("|cff8fd0ff" .. FDJ.WrapHint(entry.spot.hintKey and FDJ.L(entry.spot.hintKey) or entry.spot.hint) .. "|r\n" .. (f.distance:GetText() or ""))
            else
                f.route:SetText("|cff8fd0ff" .. FDJ.WrapHint(entry.spot.hintKey and FDJ.L(entry.spot.hintKey) or entry.spot.hint) .. "|r")
            end
        end
        -- elitenote (2.1.1, M 20 Nov 2026, Bring Me His Head: "under the usual
        -- yards stuff, you should put level 46 elite quest, find the group"): a
        -- spot's noteKey (Systems/QuestText.lua: FDJ.RouteNoted), a line of its
        -- own under the yards (or under what to kill there), at any distance.
        if entry.spot.noteKey and not (f.distance:GetText() or ""):find(FDJ.L(entry.spot.noteKey, entry.spot.noteArg), 1, true) then
            f.distance:SetText(((f.distance:GetText() or "") ~= "" and ((f.distance:GetText() or "") .. "\n") or "")
                .. "|cffff8040" .. FDJ.L(entry.spot.noteKey, entry.spot.noteArg) .. "|r")
        end
        if f.fdjNpcOn then FDJ.ArrowPlacePicture(f, true) end -- picgap (2.1.3)
        if turn then
            if f.arrow.SetRotation then f.arrow:SetRotation(turn) end
            f.arrow:Show()
        else
            f.arrow:Hide()
        end
        -- killswords (2.1.1, M 20 Nov 2026 in Sunnyglade, the arrow gone among
        -- the cultists to kill): in a place to kill / collect, the game's own
        -- crossed combat swords (the player portrait's) stand where the arrow was.
        -- lootbag (2.1.1, M 20 Nov 2026 at the Legacy of the Aspects: "once
        -- we have to pick up an item and not kill a mob, make the arrow become
        -- the loot ... the one that we use for trash mobs ... if there is both
        -- killing and pickup, just the sword. And if we are done killing
        -- before picking up, switch the sword to pick up"): the Trash Drops
        -- bag at a thing to pick up, and in a place where only things to
        -- pick up are left to do (goalLines.pickUpOnly, Systems/QuestText.lua).
        if f.swords then
            local goal = type(entry.spot.goalLines) == "table" and entry.spot.goalLines or nil
            local loot = (goal and goal.pickUpOnly) or (not goal and entry.spot.pickUp and near and not inside)
            if not turn and (goal or loot) then
                if loot then
                    if f.swords.fdjArt ~= "loot" then
                        f.swords:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\TrashDropsIcon")
                        f.swords:SetTexCoord(0, 1, 0, 1)
                        f.swords:SetSize(40, 40)
                        f.swords.fdjArt = "loot"
                    end
                elseif f.swords.fdjArt ~= true and FDJ.ArrowCombatArt then
                    f.swords:SetTexCoord(0, 1, 0, 1)
                    pcall(FDJ.ArrowCombatArt, f.swords)
                end
                f.swords:Show()
            else
                f.swords:Hide()
            end
        end
    end

    -- A left-click on the arrow: its spot (the objective, not a point on
    -- the way) on the world map, as Show on Map does. The arrow keeps where
    -- it was on the way (the points passed).
    -- killswords (2.1.1): the crossed swords the player portrait shows in
    -- combat, taken from the game's own frame (the classic portrait's
    -- PlayerAttackIcon, or the newer frame's atlas), else its texture file.
    -- swordsharp (2.1.1, M 20 Nov 2026: "it's very pixelated"): the art is
    -- small (32 pixels in the portrait's file); drawn at 40 it was stretched.
    -- Now at the size the game draws it, without snapping to the screen's
    -- pixel grid, so it stays smooth.
    -- warswords (2.1.1, M 20 Nov 2026: "way too small ... try with the War
    -- Mode ones"): the game's War Mode crossed swords first, drawn 44 high
    -- (their own shape kept); the portrait's swords only when this client
    -- has none of them.
    FDJ.ArrowCombatArt = function(tex)
        local info = C_Texture and C_Texture.GetAtlasInfo
        for _, atlas in ipairs({ "pvptalents-warmode-swords", "worldquest-icon-pvp-ffa" }) do
            local a = info and info(atlas)
            if a then
                tex:SetAtlas(atlas)
                local aw, ah = tonumber(a.width) or 0, tonumber(a.height) or 0
                if aw > 0 and ah > 0 then tex:SetSize(44 * aw / ah, 44) else tex:SetSize(44, 44) end
                if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
                if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
                tex.fdjArt = true
                return
            end
        end
        local icon = _G.PlayerAttackIcon
        local w, h = 32, 32
        if icon and icon.GetTexture and icon:GetTexture() then
            local atlas = icon.GetAtlas and icon:GetAtlas()
            if atlas then
                tex:SetAtlas(atlas)
            else
                tex:SetTexture(icon:GetTexture())
                tex:SetTexCoord(icon:GetTexCoord())
            end
            local iw, ih = icon:GetSize()
            if (tonumber(iw) or 0) >= 12 and (tonumber(ih) or 0) >= 12 then w, h = iw, ih end
        elseif C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-UnitFrame-Player-CombatIcon") then
            tex:SetAtlas("UI-HUD-UnitFrame-Player-CombatIcon")
            local info = C_Texture.GetAtlasInfo("UI-HUD-UnitFrame-Player-CombatIcon")
            if info and (tonumber(info.width) or 0) >= 12 then w, h = info.width, info.height end
        else
            tex:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
            tex:SetTexCoord(0.5, 1.0, 0.0, 0.484375)
        end
        tex:SetSize(w, h)
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
        if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
        tex.fdjArt = true
    end

    local function ShowOnMap(entry)
        local show = FDJ.MapMarkers and FDJ.MapMarkers.ShowRecordedLocationOnMap
        if not entry or type(entry.spot) ~= "table" or not show then return end
        -- (patrolnopin, 2.0.13, M 19 Nov 2026: "remove the X mark when clicking
        -- on the map for this quest ... it's just a patrol"): a patrol's spot
        -- is only the end of its line: the line alone, no pin.
        if type(entry.spot.patrol) == "table" and FDJ.MapMarkers.ShowRouteOnMap then
            FDJ.MapMarkers.ShowRouteOnMap(entry.spot.patrol)
            return
        end
        local spot = {}
        for k, v in pairs(entry.spot) do spot[k] = v end
        FDJ.pendingMarkerQuestTitle = QuestName(entry.spot)
        FDJ.pendingMarkerTurnIn = (entry.spot.turnIn and not entry.spot.goTo) and true or nil
        show(spot, spot.label)
        local now = shown
        if now and now ~= entry and SpotKey(now.spot) == SpotKey(entry.spot) then
            now.viaDone, now.viaRoute, now.viaX, now.viaY = entry.viaDone, entry.viaRoute, entry.viaX, entry.viaY
        end
    end

    local function Build()
        if frame then return frame end
        -- The insecure action template lets a click run the target-and-mark
        -- macro out of combat without making the arrow a protected frame.
        local ok, made = pcall(CreateFrame, "Button", "ForeverDungeonJournalArrow", UIParent, "InsecureActionButtonTemplate")
        local f = ok and made or CreateFrame("Button", "ForeverDungeonJournalArrow", UIParent)
        frame = f
        f._fdjCanTarget = (ok and made) and true or false
        if f._fdjCanTarget then f:SetAttribute("useOnKeyDown", false) end
        f:SetSize(150, 84)
        -- Only the arrow itself (52 x 52 at the top) takes the mouse: not the
        -- text under it nor the space round it.
        if f.SetHitRectInsets then f:SetHitRectInsets(49, 49, 0, 32) end
        f:SetFrameStrata("MEDIUM")
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local point = Saved().point
        if type(point) == "table" and type(point[1]) == "string" and tonumber(point[3]) and tonumber(point[4]) then
            f:SetPoint(point[1], UIParent, point[2] or point[1], tonumber(point[3]), tonumber(point[4]))
        else
            f:SetPoint("TOP", UIParent, "TOP", 0, -150)
        end
        f.arrow = f:CreateTexture(nil, "ARTWORK")
        f.arrow:SetSize(52, 52)
        f.arrow:SetPoint("TOP", f, "TOP", 0, 0)
        if f.arrow:SetTexture(ART) == false then f.arrow:SetTexture(FALLBACK_ART) end
        f.swords = f:CreateTexture(nil, "ARTWORK") -- killswords (2.1.1)
        f.swords:SetSize(40, 40)
        f.swords:SetPoint("CENTER", f.arrow, "CENTER", 0, 0)
        f.swords:Hide()
        f.title = f:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
        f.title:SetPoint("TOP", f.arrow, "BOTTOM", 0, -1)
        f.distance = f:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
        f.distance:SetPoint("TOP", f.title, "BOTTOM", 0, -2)
        -- flybar (2.1.1, M 20 Nov 2026 on a flight: "I would like to see the
        -- flight icon ... on top of the quest and then have the timer of the
        -- flight in a bar ... from filled to empty ... The bar should be
        -- yellow"): in the air, the game's flight master icon where the arrow
        -- was, and under the quest's name a yellow bar that empties as the
        -- flight goes on, the time left on it.
        f.taxiIcon = f:CreateTexture(nil, "ARTWORK")
        f.taxiIcon:SetSize(34, 34)
        f.taxiIcon:SetPoint("CENTER", f.arrow, "CENTER", 0, 0)
        f.taxiIcon:SetTexture("Interface\\Minimap\\Tracking\\FlightMaster")
        f.taxiIcon:Hide()
        do
            local okH, holder = pcall(CreateFrame, "Frame", nil, f, "BackdropTemplate")
            local okB, bar = pcall(CreateFrame, "StatusBar", nil, okH and holder or f)
            if okH and holder and okB and bar then
                holder:SetSize(140, 12)
                holder:SetPoint("TOP", f.title, "BOTTOM", 0, -4)
                holder:EnableMouse(false)
                if holder.SetBackdrop then
                    holder:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
                    holder:SetBackdropColor(0, 0, 0, 0.55)
                    holder:SetBackdropBorderColor(0, 0, 0, 0.9)
                end
                bar:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
                bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
                bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
                bar:SetStatusBarColor(1.00, 0.82, 0.00)
                bar:SetMinMaxValues(0, 1)
                bar:SetValue(1)
                bar:EnableMouse(false)
                holder.bar = bar
                holder.text = bar:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
                holder.text:SetPoint("CENTER", holder, "CENTER", 0, 0)
                local font, size = holder.text:GetFont()
                if font then pcall(holder.text.SetFont, holder.text, font, size or 10, "OUTLINE") end
                holder:Hide()
                f.taxiBar = holder
            end
        end
        -- npcicon (2.0.13): the NPC in reach of a click: in place of the !
        -- or ?, the NPC's own picture (once the game shows the unit: target,
        -- mouseover or nameplate), else the mark the click puts on it.
        f.npc = f:CreateTexture(nil, "OVERLAY")
        f.npc:SetSize(32, 32) -- npcbig (2.0.16): was 22
        f.npc:SetPoint("RIGHT", f.title, "LEFT", -3, 0)
        f.npc:Hide()
        -- npchover (2.0.16): the soft glow the journal's round icons get under
        -- the mouse (the Onyxia and Sleeping Bag icons), over the NPC's picture.
        f.npcHl = f:CreateTexture(nil, "OVERLAY", nil, 7)
        f.npcHl:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        f.npcHl:SetBlendMode("ADD")
        f.npcHl:SetAlpha(0.25)
        f.npcHl:SetAllPoints(f.npc)
        f.npcHl:Hide()
        f.route = f:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
        f.route:SetPoint("TOP", f.distance, "BOTTOM", 0, -2)
        -- way: "Hearth to Auberdine", in the hearthstone's blue.
        f.hearth = f:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
        f.hearth:SetPoint("TOP", f.route, "BOTTOM", 0, -2)
        f.hearth:SetTextColor(0.56, 0.82, 1.00)
        -- spawns (2.0.36): "Not found? Next spot", at one of a spot's places.
        do
            local okB, b = pcall(CreateFrame, "Button", nil, f, "UIPanelButtonTemplate")
            if okB and b then
                b:SetSize(190, 22)
                b:SetPoint("TOP", f.hearth, "BOTTOM", 0, -4)
                b:SetScript("OnClick", function() if FDJ.NextArrowSpawn then FDJ.NextArrowSpawn() end end)
                b:Hide()
                f.nextSpawn = b
            end
        end
        -- skipnow (2.0.13): "Skip for now" under the arrow, at a Route's step
        -- inside another dungeon (Rot and Regret, in Maraudon): leaves its
        -- quest off the Route (FDJ.RouteSkipNow).
        do
            local okS, b = pcall(CreateFrame, "Button", nil, f, "UIPanelButtonTemplate")
            if okS and b then
                b:SetSize(130, 22)
                b:SetPoint("TOP", f.hearth, "BOTTOM", 0, -4)
                b:SetText(FDJ.L("ARROW_SKIP_NOW"))
                b:SetScript("OnClick", function()
                    local e = shown
                    if GameTooltip then GameTooltip:Hide() end
                    if e and e.spot and e.spot.skipQuest and FDJ.RouteSkipNow then FDJ.RouteSkipNow(e.source, e.spot.skipQuest) end
                end)
                b:SetScript("OnEnter", function(self)
                    if not GameTooltip then return end
                    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                    GameTooltip:SetText(FDJ.L("ARROW_SKIP_NOW_TIP"), 1, 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
                b:Hide()
                f.skipNow = b
            end
        end
        f:SetScript("OnDragStart", function(self)
            self.fdjDragging = true
            self:StartMoving()
        end)
        f:SetScript("OnDragStop", function(self)
            self.fdjDragging = nil
            self.fdjDragEnd = (GetTime and GetTime()) or 0
            self:StopMovingOrSizing()
            local p, _, rp, x, y = self:GetPoint(1)
            if p then Saved().point = { p, rp, x, y } end
        end)
        -- PostClick keeps the template's own click (the target macro).
        f:SetScript(f._fdjCanTarget and "PostClick" or "OnClick", function(self, button)
            -- shiftdismiss (2.0.10, M 17 Nov 2026: "so many times I right
            -- click it by mistake"): only Shift + right-click hides it; a
            -- plain right-click does nothing.
            if button == "RightButton" then
                if IsShiftKeyDown and IsShiftKeyDown() then
                    GameTooltip:Hide()
                    Dismiss(shown)
                end
            elseif button == "LeftButton" and not self.fdjTargets and not self.fdjDragging
                and ((GetTime and GetTime()) or 0) - (self.fdjDragEnd or -10) > 0.3 then
                GameTooltip:Hide()
                ShowOnMap(shown)
            end
        end)
        -- The arrow's tooltip (its spot, the quest, what a click does, move,
        -- right-click to hide).
        local function ShowTip(self)
            local entry = shown
            if not entry then return end
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(FreeText(entry.spot.label) or SpotName(entry.spot), 1, 0.82, 0.27)
            local quest = QuestName(entry.spot)
            if quest then GameTooltip:AddLine(quest, 1, 1, 1) end
            local detail = FreeText(entry.spot.detail)
            if detail and detail ~= "" then GameTooltip:AddLine(detail, 0.85, 0.85, 0.85, true) end
            if self.fdjTargets then
                GameTooltip:AddLine(FDJ.L("MAP_LEFT_TARGET"), 0.35, 1.00, 0.35)
            else
                GameTooltip:AddLine(FDJ.L("ARROW_TIP_MAP"), 0.55, 0.55, 0.55)
            end
            GameTooltip:AddLine(FDJ.L("ARROW_TIP_MOVE"), 0.55, 0.55, 0.55)
            GameTooltip:AddLine(FDJ.L("ARROW_TIP_HIDE"), 0.55, 0.55, 0.55)
            GameTooltip:Show()
        end
        -- npchover (2.0.17): is the mouse on the NPC's picture itself (not the
        -- arrow, not the name)?
        local function OnPicture(self)
            local pic = self.npc
            if not (self.fdjNpcOn and pic and pic:IsShown()) or type(GetCursorPosition) ~= "function" then return false end
            local l, r, t, b = pic:GetLeft(), pic:GetRight(), pic:GetTop(), pic:GetBottom()
            if not (l and r and t and b) then return false end
            local x, y = GetCursorPosition()
            local scale = (self.GetEffectiveScale and self:GetEffectiveScale()) or 1
            if not (x and y) or scale <= 0 then return false end
            x, y = x / scale, y / scale
            return x >= l - 1 and x <= r + 1 and y >= b - 1 and y <= t + 1
        end
        -- npchover (2.0.17): the glow only on the NPC's picture (no tooltip
        -- there: a click targets and marks); the arrow and the name keep the
        -- arrow's tooltip (right-click to hide, ...). Checked every frame
        -- while the mouse is on the arrow.
        local function Hover(self)
            local want
            if not self.fdjMouseIn or self.fdjHidden or not shown then
                want = "none"
            elseif OnPicture(self) then
                want = "picture"
            else
                want = "tip"
            end
            if want == self.fdjHoverState then return end
            self.fdjHoverState = want
            if self.npcHl then self.npcHl:SetShown(want == "picture") end
            if want == "tip" then
                ShowTip(self)
            elseif GameTooltip:GetOwner() == self then
                GameTooltip:Hide()
            end
        end
        f:SetScript("OnEnter", function(self)
            self.fdjMouseIn = true
            self.fdjHoverState = nil
            Hover(self)
        end)
        f:SetScript("OnLeave", function(self)
            self.fdjMouseIn = nil
            self.fdjHoverState = nil
            if self.npcHl then self.npcHl:Hide() end
            GameTooltip:Hide()
        end)
        f:SetScript("OnUpdate", function(self, elapsed)
            if self.fdjMouseIn then Hover(self) end
            self.fdjWait = (self.fdjWait or 0) - (elapsed or 0)
            if self.fdjWait > 0 then return end
            self.fdjWait = STEP
            Redraw(self)
        end)
        f:Hide()
        return f
    end

    -- corpserun (2.0.13, M 18 Nov 2026, a ghost at the graveyard with the
    -- arrow to the Grimy Key: "when I'm dead, the arrow prioritizes pointing
    -- me to my body"): while the character is a ghost the arrow leads to the
    -- corpse (where the game shows it on the map), in front of anything
    -- else; alive again, back to what it was at. (Way fields: this scope
    -- has no locals to spare.)
    ;(function()
        local strings = { enUS = "Your corpse", deDE = "Dein Leichnam", frFR = "Votre cadavre", esES = "Tu cadáver", itIT = "Il tuo cadavere",
            ptBR = "Seu cadáver", ruRU = "Ваше тело", koKR = "내 시체", zhCN = "你的尸体", zhTW = "你的屍體" }
        strings.esMX = strings.esES
        for locale, text in pairs(strings) do
            local t = FDJ.Locales and FDJ.Locales[locale]
            if t and t.ARROW_CORPSE == nil then t.ARROW_CORPSE = text end
        end
    end)()
    function Way.Corpse()
        if type(UnitIsGhost) ~= "function" then return nil end
        local ok, ghost = pcall(UnitIsGhost, "player")
        if not ok or (type(issecretvalue) == "function" and issecretvalue(ghost)) or ghost ~= true then
            Way.corpse, Way.corpseOff = nil, nil
            return nil
        end
        if Way.corpseOff then return nil end
        if Way.corpse then return Way.corpse end
        local map, guard = PlayerMap(), 0
        while map and guard < 4 and C_DeathInfo and type(C_DeathInfo.GetCorpseMapPosition) == "function" do
            local okPos, pos, posY = pcall(C_DeathInfo.GetCorpseMapPosition, map)
            local x, y
            if okPos and type(pos) == "table" then
                x, y = pos.x, pos.y
                if (x == nil or y == nil) and pos.GetXY then x, y = pos:GetXY() end
            elseif okPos and type(pos) == "number" then
                x, y = pos, posY -- (x and y as two numbers)
            end
            if Way.Spot(x, y) then
                Way.corpse = { spot = { mapID = map, x = x, y = y, label = FDJ.L("ARROW_CORPSE"), corpse = true, markerType = "location" }, source = "corpse", key = "corpse" }
                return Way.corpse
            end
            local okInfo, info = pcall(C_Map.GetMapInfo, map)
            map = okInfo and type(info) == "table" and Number(info.parentMapID) or nil
            if map == 0 then map = nil end
            guard = guard + 1
        end
        -- corpsefallback (2.1.1, M 20 Nov 2026, a ghost at Farholde Keep's
        -- graveyard with the arrow on A Small Favor's hand-in: "it's telling me
        -- to turn in the quest when I'm dead instead of getting to the body"):
        -- the game gave no place for the corpse: where the character died.
        if type(Way.diedAt) == "table" then
            Way.corpse = { spot = { mapID = Way.diedAt.mapID, x = Way.diedAt.x, y = Way.diedAt.y, label = FDJ.L("ARROW_CORPSE"), corpse = true, markerType = "location" }, source = "corpse", key = "corpse" }
            return Way.corpse
        end
        return nil
    end
    -- A place on a map: two plain numbers inside it.
    function Way.Spot(x, y)
        if type(issecretvalue) == "function" and (issecretvalue(x) or issecretvalue(y)) then return false end
        return Number(x) ~= nil and Number(y) ~= nil and x > 0 and y > 0 and x < 1 and y < 1
    end
    Way.corpseWatch = CreateFrame("Frame")
    ;(function()
        for _, event in ipairs({ "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_ENTERING_WORLD" }) do
            pcall(Way.corpseWatch.RegisterEvent, Way.corpseWatch, event)
        end
    end)()
    Way.corpseWatch:SetScript("OnEvent", function(_, event)
        Way.corpse = nil
        -- corpsefallback: where the character died is kept until alive again
        if event == "PLAYER_DEAD" then
            Way.diedAt = nil
            local map = PlayerMap()
            if map and C_Map and type(C_Map.GetPlayerMapPosition) == "function" then
                local okP, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
                local x, y
                if okP and type(pos) == "table" then
                    x, y = pos.x, pos.y
                    if (x == nil or y == nil) and pos.GetXY then x, y = pos:GetXY() end
                end
                if Way.Spot(x, y) then Way.diedAt = { mapID = map, x = x, y = y } end
            end
        elseif event == "PLAYER_UNGHOST" then
            Way.diedAt = nil
        end
        local function again() if Choose then pcall(Choose) end end
        again()
        if C_Timer and C_Timer.After then C_Timer.After(1, again) end -- (the ghost and the corpse's place come a moment after)
    end)
    -- corpsefallback: a ghost whose corpse was not known yet when the arrow
    -- was chosen: asked again every second until it is.
    Way.corpseWatch:SetScript("OnUpdate", function(self, elapsed)
        self.fdjWait = (self.fdjWait or 0) - (elapsed or 0)
        if self.fdjWait > 0 then return end
        self.fdjWait = 1
        if Way.corpse or Way.corpseOff or not shown or shown.source == "corpse" then return end
        if Way.Corpse() and Choose then pcall(Choose) end
    end)

    -- The spot shown on the map first, else the one a tracked chain is at.
    Choose = function()
        local pick = manual
        if not pick then
            local done = Done()
            for source, entry in pairs(follows) do
                if done[source] ~= entry.key then pick = entry break end
            end
        end
        if pick then pick = Way.Corpse() or pick end -- corpserun (only while the arrow is in use)
        shown = pick
        if not pick then
            if frame then frame:Hide() end
            return
        end
        local f = Build()
        -- A quest's spot says whether it is picked up (!) or handed in (?)
        -- there: the same object can be both, in two places (the Burned-Out
        -- Remains). The arrow carries the quest's name; the spot's own name is
        -- in its tooltip.
        local quest = QuestName(pick.spot)
        local mark = ""
        -- repeaticon (2.0.44): the arrow to a repeatable quest: the blue ?
        local repeatOnly = FDJ.IsRepeatableQuest ~= nil and pick.spot.fdjAutoQuest ~= nil
            and FDJ.IsRepeatableQuest(pick.spot.fdjAutoQuest)
        -- sharpmark (2.1.3, M 21 Nov 2026 at the Battered Dwarven Skeleton:
        -- "the question mark is so low quality though"): the arrow's ? and !
        -- are the journal's own drawings (Media/ArrowTurnIn, ArrowPickUp,
        -- ArrowRepeatable, 128 x 128), sharp at the picture's size too
        -- (objectmark), in place of the game's 16 x 16 gossip marks.
        if repeatOnly and (pick.spot.turnIn or quest) then
            mark = "|TInterface\\AddOns\\ForeverDungeonJournal\\Media\\ArrowRepeatable:0|t "
        elseif pick.spot.goTo then
            mark = "" -- gotomark
        elseif pick.spot.turnIn then
            mark = "|TInterface\\AddOns\\ForeverDungeonJournal\\Media\\ArrowTurnIn:0|t "
        elseif quest then
            mark = "|TInterface\\AddOns\\ForeverDungeonJournal\\Media\\ArrowPickUp:0|t "
        end
        f.fdjMark, f.fdjName = mark, (quest or SpotName(pick.spot))
        f.fdjNpcOn, f.fdjNpcUnit, f.fdjNpcAt = nil, nil, nil
        if f.npc then f.npc:Hide() end
        f.title:SetText(mark .. f.fdjName)
        pick.zone = pick.zone or ZoneName(pick.spot.mapID)
        pick.plan, pick.plannedAt, pick.plannedX, pick.plannedY = nil, nil, nil, nil
        f.fdjWait, f.fdjNear = 0, nil
        f:Show()
        Redraw(f)
    end

    local function Copy(spot)
        local copy = {}
        for k, v in pairs(spot) do copy[k] = v end
        return copy
    end

    -- Show on Map and the rest (Systems/MapMarkers.lua above). Off for now
    -- (1.9.0) but for the Cozy Sleeping Bag: Show on Map on one of its spots
    -- (1.9.7, FDJ.IsSleepingBagSpot) and its tracked chain page
    -- (FDJ.FollowWaypoint). FDJ.ARROW_MANUAL = true turns it on everywhere.
    -- 1.9.9: after the spot shown, the arrow goes on with the chain (picked
    -- up, handed in, the next step...) as for a tracked chain, until it is
    -- right-clicked away (Systems/QuestText.lua: FDJ.FollowChainArrow).
    function FDJ.SetWaypointArrow(spot)
        local chain = FDJ.IsSleepingBagSpot and FDJ.IsSleepingBagSpot(spot) and FDJ.SLEEPING_BAG_PAGE or nil
        if not FDJ.ARROW_MANUAL and not chain then return end
        if type(spot) ~= "table" or not spot.mapID or not tonumber(spot.x) or not tonumber(spot.y) then return end
        if chain and FDJ.FollowChainArrow then
            Done()[chain] = nil
            FDJ.FollowChainArrow(chain)
        end
        manual = { spot = Copy(spot), source = "manual", key = SpotKey(spot), chain = chain }
        Choose()
    end
    -- Its map pin removed: the arrow goes too (a chain followed since Show
    -- on Map with it, unless tracked).
    function FDJ.ClearWaypointArrow(spot)
        if type(spot) ~= "table" or not manual or manual.key ~= SpotKey(spot) then return end
        local chain = manual.chain
        manual = nil
        if chain and FDJ.StopChainArrow and FDJ.StopChainArrow(chain) then follows[chain] = nil end
        Choose()
    end
    -- A followed chain page's next spot (nil: nothing more, or not followed).
    -- The chain moving on or ending takes its spot shown on the map along.
    -- goalhere (2.0.9): goalLines, at the place to kill / collect (a route's
    -- stop, Systems/QuestText.lua): the lines shown in place of the yards.
    function FDJ.FollowWaypoint(source, spot, questTitle, turnIn, goalLines, goTo, skipQuest)
        if source == nil then return end
        if type(spot) ~= "table" or not spot.mapID then
            if follows[source] then
                follows[source] = nil
                if manual and manual.chain == source then manual = nil end
                Choose()
            end
            return
        end
        local key = SpotKey(spot) .. (turnIn and "|in" or "|up") .. (spot.useItem and "|use" or "") -- lootitem: the reminder comes and goes
        local old = follows[source]
        -- goalhere (2.0.9): the same spot, there or not (yet): the lines kept
        -- up to date as kills and loot come in; the arrow stays as it is
        -- (right-clicked away: still away). The next quest at the same place
        -- (The Second Rebellion done, Bad Medicine left): its name on it.
        if old and old.key == key then
            old.spot.goTo = goTo and true or nil -- gotomark
            old.spot.goalLines = type(goalLines) == "table" and goalLines or nil
            old.spot.noteKey, old.spot.noteArg = spot.noteKey, spot.noteArg -- elitenote (2.1.1)
            if type(questTitle) == "string" and old.spot.questTitle ~= questTitle then
                old.spot.questTitle = questTitle
                if shown == old then Choose() end
            end
            return
        end
        if old and old.key == key then return end
        if old and manual and manual.chain == source then manual = nil end
        local copy = Copy(spot)
        copy.questTitle = questTitle
        copy.turnIn = turnIn and true or nil
        -- gotomark (2.0.13, M 18 Nov 2026, the arrow to where Dalaran
        -- Patrols' mobs are, with the yellow ?: "why is it telling me to go
        -- turn in the quest when I haven't completed the quest yet?"): a
        -- place to kill or collect at is no hand-in: no ? on the arrow, and
        -- no "Turn in here" on its map pin.
        copy.goTo = goTo and true or nil
        copy.goalLines = type(goalLines) == "table" and goalLines or nil
        copy.skipQuest = skipQuest -- skipnow (2.0.13): the Route's quest the arrow's "Skip for now" leaves off
        follows[source] = { spot = copy, source = source, key = key }
        Choose()
    end
    -- picgap (2.1.3, M 21 Nov 2026 at the Battered Dwarven Skeleton, "Talk to
    -- Battered Dwarven Skeleton" running under the ?: "the little green text
    -- should never overlap with portraits or question mark icons"): the
    -- picture (32 high, level with the name) reaches down into the first line
    -- under the name; it stands left of that line, measured every frame (the
    -- yards become "Talk to <name>" once there, after the picture came).
    -- The picture and the name take the click too, not only the arrow (the
    -- picture sits left of the name, past the frame's own edge when the name
    -- is long: the hit area reaches out to it; not in combat).
    function FDJ.ArrowPlacePicture(f, on)
        if not (f and f.npc and f.title and f.distance) then return end
        local half = (tonumber(f.title:GetStringWidth()) or 110) / 2
        local wide = 0
        if on then
            if not f.fdjMeasure then
                f.fdjMeasure = f:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
                f.fdjMeasure:Hide()
            end
            local first = (f.distance:GetText() or ""):match("^([^\n]*)") or ""
            if first ~= f.fdjMeasureText then
                f.fdjMeasure:SetText(first)
                f.fdjMeasureText, f.fdjMeasureWide = first, tonumber(f.fdjMeasure:GetStringWidth()) or 0
            end
            wide = f.fdjMeasureWide or 0
        end
        local out = math.max(0, math.floor(wide / 2 - half + 3.5))
        local key = (on and "on" or "off") .. ":" .. math.floor(half + 0.5) .. ":" .. out
        if key == f.fdjPicKey then return end
        f.npc:ClearAllPoints()
        f.npc:SetPoint("RIGHT", f.title, "LEFT", -3 - out, 0)
        if f.SetHitRectInsets then
            if InCombatLockdown and InCombatLockdown() then return end -- (tried again next frame)
            if on then
                local tall = tonumber(f.title:GetStringHeight()) or 14
                f:SetHitRectInsets(75 - (half + out + 39), 75 - (half + 2), 0,
                    math.max(0, math.floor(84 - (53 + tall / 2 + 18))))
            else
                f:SetHitRectInsets(49, 49, 0, 32)
            end
        end
        f.fdjPicKey = key
    end
    function FDJ.WaypointArrowTarget()
        return shown and shown.spot or nil, shown and shown.source or nil
    end

    -- dungeonroute (2.0.5): what the way from one spot to another costs, in
    -- yards on foot, counted as the arrow counts it (flight points found,
    -- boats, zeppelins, portals). from = nil: from where the player stands,
    -- and then with the hearthstone when it is ready and the quicker way.
    -- nil: no way known.
    function FDJ.WayCost(from, to)
        if type(to) ~= "table" or not to.mapID then return nil end
        local t = Way.Point(to.mapID, tonumber(to.x) or 0, tonumber(to.y) or 0)
        if not t then return nil end
        local p
        if from then
            p = Way.Point(from.mapID, tonumber(from.x) or 0, tonumber(from.y) or 0)
        else
            local px, py, here = PlayerWorld()
            if px and here then
                local map = PlayerMap()
                p = { px, py, here, region = Way.Region(here, map, px, py), map = map }
            end
        end
        if not p then return nil end
        local cost = p.region == t.region and Way.Leg(p, t) or nil
        if not cost or cost > Way.RIDE_WORTH then
            local _, found = Way.Search(p, t)
            cost = found or cost
        end
        if not from and Way.HearthReady() then
            local bindName, bind = Way.BindSpot()
            if bind and not (bind[3] == p[3] and Yards(p[1], p[2], bind[1], bind[2]) < Way.HEARTH_NEAR) and not Way.AtBind(bindName) then
                local _, after = Way.Search(bind, t)
                local need = bind[3] == p[3] and Way.HEARTH_SAVES_SAME or Way.HEARTH_SAVES -- hearthfar
                if after and (not cost or Way.HEARTH_CAST + after + need <= cost) then
                    cost = Way.HEARTH_CAST + after
                end
            end
        end
        return cost
    end
    -- Where the arrow leads right now (world yards) and, on the way round
    -- something, that point's label (2.0.12; for tests and /dj debugging).
    function FDJ.WaypointArrowAim()
        local plan = shown and shown.plan
        if not plan then return nil end
        if plan.elevator and plan.aimX then return plan.aimX, plan.aimY, "elevator" end -- ucelevator (2.0.7)
        if plan.road and plan.aimX then return plan.aimX, plan.aimY, "road" end -- orgroads (2.0.8)
        return plan.x, plan.y, plan.via and plan.via.label or nil
    end
    -- A route switched on again: its arrow comes back if it was hidden.
    function FDJ.ResetWaypointDone(source)
        if source ~= nil then Done()[source] = nil end
    end
end
-- END arrow

-- loadpause (2.0.7): a loading screen starts: the arrow's hidden NPC model
-- is put away; the lookup starts over a few seconds after arriving.
function FDJ.PauseArrowLookup()
    local f = FDJ.arrowLookupFrame
    if not (f and f.model) then return end
    FDJ.ArrowFreeModel(f) -- ownmodel
    f.fdjResolving = nil
end

-- ownmodel (2.0.13): the hidden models the arrow learns NPC portraits with.
-- A model put away is only taken again 10 seconds later: anything it was
-- still loading has come in by then.
do
    local pool = {}
    function FDJ.ArrowTakeModel()
        local now = (GetTime and GetTime()) or 0
        for _, m in ipairs(pool) do
            if not m.fdjBusy and now - (m.fdjFreedAt or 0) >= 10 then
                m.fdjBusy = true
                m:Show()
                return m
            end
        end
        local ok, m = pcall(CreateFrame, "PlayerModel", nil, UIParent)
        if not ok or not m then return nil end
        m:SetSize(1, 1)
        m:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        m:SetAlpha(0)
        m.fdjBusy = true
        pool[#pool + 1] = m
        return m
    end
    -- arrowsafe (2.0.13, M 19 Nov 2026, Dorn Plainstalker's arrow with an
    -- undead face: "a lot of quests have been doing this"): a model asked
    -- for an NPC it has not loaded yet still shows what it showed before
    -- (the last NPC, or the player's own look), and that was being saved as
    -- the NPC's face. Now a look only counts once the model has loaded the
    -- new one, or it differs from what the model showed before asking - and
    -- never the player's own. And once the NPC itself is seen (target,
    -- mouseover, nameplate), its real look is learned from it, mending a
    -- wrong one saved before.
    local function Display(m)
        local ok, d = pcall(m.GetDisplayInfo, m)
        return ok and type(d) == "number" and d or nil
    end
    local mine, mineAt, mineModel
    local function PlayerDisplay()
        local now = (GetTime and GetTime()) or 0
        if mine and mineAt and now - mineAt < 30 then return mine end
        if not mineModel then
            local ok, made = pcall(CreateFrame, "PlayerModel", nil, UIParent)
            if not ok or not made then return nil end
            mineModel = made
            mineModel:SetSize(1, 1)
            mineModel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            mineModel:SetAlpha(0)
        end
        local m = mineModel
        m:Show()
        pcall(m.SetUnit, m, "player")
        mine, mineAt = Display(m), now
        pcall(m.ClearModel, m)
        m:Hide()
        return mine
    end
    function FDJ.ArrowModelAsk(m)
        if not m then return end
        m.fdjBefore, m.fdjLoaded = Display(m), nil
        if not m.fdjHooked and m.HookScript then
            m.fdjHooked = true
            pcall(m.HookScript, m, "OnModelLoaded", function(self) self.fdjLoaded = true end)
        end
    end
    function FDJ.ArrowModelGood(m, display)
        if not (m and display and display > 0) then return false end
        if display == PlayerDisplay() then return false end
        return m.fdjLoaded == true or display ~= m.fdjBefore
    end
    -- seenportrait (2.0.13, M 19 Nov 2026, on Rok'Alim's path: "make his
    -- portrait appear once the game loads him ... so I don't have to spam
    -- target macro him"): is the NPC shown by the game right now (target,
    -- mouseover, a nameplate)? Looked at twice a second.
    function FDJ.ArrowNpcSeen(f, name)
        if not (f and type(name) == "string") then return false end
        local now = (GetTime and GetTime()) or 0
        if f.fdjSeenName == name and f.fdjSeenAt and now - f.fdjSeenAt < 0.5 then return f.fdjSeen end
        f.fdjSeenName, f.fdjSeenAt, f.fdjSeen = name, now, false
        local function Is(token)
            if type(token) ~= "string" or type(UnitExists) ~= "function" then return false end
            local okE, exists = pcall(UnitExists, token)
            if not okE or not exists then return false end
            local okN, unitName = pcall(UnitName, token)
            if not okN or type(unitName) ~= "string" then return false end
            if type(issecretvalue) == "function" and issecretvalue(unitName) then return false end
            return unitName == name
        end
        if Is("target") or Is("mouseover") then f.fdjSeen = true return true end
        if C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" then
            local okP, plates = pcall(C_NamePlate.GetNamePlates)
            for _, plate in ipairs(okP and type(plates) == "table" and plates or {}) do
                if Is(plate and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))) then
                    f.fdjSeen = true
                    return true
                end
            end
        end
        return false
    end
    local seer
    function FDJ.ArrowLearnFromUnit(npcID, unit)
        if not (npcID and unit) then return end
        local now = (GetTime and GetTime()) or 0
        FDJ.arrowUnitLearned = FDJ.arrowUnitLearned or {}
        if FDJ.arrowUnitLearned[npcID] and now - FDJ.arrowUnitLearned[npcID] < 5 then return end
        FDJ.arrowUnitLearned[npcID] = now
        if not seer then
            local ok, m = pcall(CreateFrame, "PlayerModel", nil, UIParent)
            if not ok or not m then return end
            seer = m
            seer:SetSize(1, 1)
            seer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            seer:SetAlpha(0)
        end
        seer:Show()
        if not pcall(seer.SetUnit, seer, unit) then seer:Hide() return end
        local display = Display(seer)
        pcall(seer.ClearModel, seer)
        seer:Hide()
        if not display or display <= 0 or display == PlayerDisplay() then return end
        FDJ.arrowDisplayIDs = FDJ.arrowDisplayIDs or {}
        if FDJ.arrowDisplayIDs[npcID] ~= display then
            FDJ.arrowDisplayIDs[npcID] = display
            if type(ForeverDungeonJournalDB) == "table" then
                ForeverDungeonJournalDB.displayIDs = ForeverDungeonJournalDB.displayIDs or {}
                ForeverDungeonJournalDB.displayIDs[npcID] = display
            end
        end
    end
    function FDJ.ArrowFreeModel(f)
        local m = f and f.model
        if not m then return end
        f.model = nil
        if m.ClearModel then pcall(m.ClearModel, m) end
        m:Hide()
        m.fdjBusy, m.fdjFreedAt = nil, (GetTime and GetTime()) or 0
    end
end

-- questrp (2.0.8, M 15 Nov 2026): a hand-in that starts a scene before the
-- next quest (FDJ.QUEST_RP, Data/QuestUpdates.lua): from the hand-in until the
-- NPC's last scene line, FDJ.ArrowRPWait(name) gives the arrow's line for
-- that NPC ("Wait for the RP", with the seconds left once the scene has been
-- timed once: ForeverDungeonJournalDB.rpTimes, account-wide). The NPC is
-- known by the NPC ID in the chat line's sender (any client language), or by
-- its name. Given up after 60 seconds (or 15 past the time it took before).
do
    local wait
    local frame = CreateFrame("Frame")
    for _, event in ipairs({ "QUEST_TURNED_IN", "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_WHISPER" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    local function Now() return (GetTime and GetTime()) or 0 end
    local function Times()
        if type(ForeverDungeonJournalDB) ~= "table" then return {} end
        if type(ForeverDungeonJournalDB.rpTimes) ~= "table" then ForeverDungeonJournalDB.rpTimes = {} end
        return ForeverDungeonJournalDB.rpTimes
    end
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "QUEST_TURNED_IN" then
            local id = tonumber((...))
            local rp = id and FDJ.QUEST_RP and FDJ.QUEST_RP[id]
            if type(rp) == "table" then
                wait = { quest = id, npc = tonumber(rp.npc), name = rp.name, lines = tonumber(rp.lines) or 1, seen = 0, at = Now() }
            end
            return
        end
        if not wait then return end
        local sender, guid = select(2, ...), select(12, ...)
        if type(issecretvalue) == "function" and (issecretvalue(sender) or issecretvalue(guid)) then return end
        local npcID = type(guid) == "string" and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")) or nil
        if (npcID and npcID == wait.npc) or (not npcID and sender == wait.name) then
            wait.seen = wait.seen + 1
            if wait.seen >= wait.lines then
                Times()[wait.quest] = math.floor(Now() - wait.at + 0.5)
                wait = nil
            end
        end
    end)
    function FDJ.ArrowRPWait(name)
        if not wait or name ~= wait.name then return nil end
        local took = tonumber(Times()[wait.quest])
        local gone = Now() - wait.at
        if gone > ((took and took + 15) or 60) then wait = nil return nil end
        if took and took > 0 then
            return FDJ.L("ARROW_RP_WAIT_TIME", math.max(0, math.ceil(took - gone)))
        end
        return FDJ.L("ARROW_RP_WAIT")
    end
end

-- arrowitem (2.0.13, M 19 Nov 2026 at the western pylon with the Pile of
-- Pylon Parts in the bags: "the pylon parts item that's clickable should
-- appear at the arrow ... instead of the raid mark, and you can just click
-- on it, and it's gonna use the item"): a spot with an item to use there
-- (spot.clickItem = { itemID, name }) shows the item's icon left of the
-- arrow's name while the item is in the bags; a click uses it (out of
-- combat: the game's action button template, as the tracker's start items).
;(function()
    local SIZE = 32
    local function Count(itemID)
        local get = (C_Item and C_Item.GetItemCount) or GetItemCount
        if type(get) ~= "function" then return 0 end
        local ok, n = pcall(get, itemID)
        return ok and tonumber(n) or 0
    end
    local function Icon(itemID)
        local get = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
        if type(get) ~= "function" then return nil end
        local ok, icon = pcall(get, itemID)
        return ok and icon or nil
    end
    local function Build(f)
        local ok, b = pcall(CreateFrame, "Button", nil, f, "InsecureActionButtonTemplate")
        if not ok or not b then return nil end
        b:SetSize(SIZE, SIZE)
        b:SetFrameLevel((f:GetFrameLevel() or 1) + 5)
        b:RegisterForClicks("LeftButtonUp")
        b:SetAttribute("useOnKeyDown", false)
        b:SetAttribute("type", "item")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        local lit = b:CreateTexture(nil, "HIGHLIGHT")
        lit:SetAllPoints()
        lit:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        lit:SetBlendMode("ADD")
        b:SetScript("PreClick", function(self)
            if InCombatLockdown and InCombatLockdown() then
                self:SetAttribute("type", nil) -- (no use in combat: the game would block it)
                if UIErrorsFrame and ERR_NOT_IN_COMBAT then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
            end
        end)
        b:SetScript("PostClick", function(self) self:SetAttribute("type", "item") end)
        b:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            if self.itemID and GameTooltip.SetItemByID then
                GameTooltip:SetItemByID(self.itemID)
            else
                GameTooltip:SetText(self.itemName or "", 1, 0.82, 0)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        b:Hide()
        return b
    end
    function FDJ.ArrowItemButton(f, spot)
        local use = type(spot) == "table" and type(spot.clickItem) == "table" and spot.clickItem or nil
        local itemID = use and tonumber(use[1])
        local on = itemID and Count(itemID) > 0
        if not on then
            if f.fdjItem then f.fdjItem:Hide() end
            return
        end
        f.fdjItem = f.fdjItem or Build(f)
        local b = f.fdjItem
        if not b then return end
        if b.itemID ~= itemID then
            b.itemID, b.itemName = itemID, use[2]
            b:SetAttribute("item", "item:" .. itemID)
            b.icon:SetTexture(Icon(itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
        end
        b:ClearAllPoints()
        b:SetPoint("RIGHT", f.title, "LEFT", -3, 0)
        b:Show()
    end
end)()

-- hintwrap (2.0.13, M 19 Nov 2026, the pylon line under the arrow: "can we
-- have this blue text on two lines? It's way too long like this on one
-- line"): a spot's line longer than 45 letters is split in two at the
-- space nearest its middle (a comma there first).
function FDJ.WrapHint(text)
    if type(text) ~= "string" or #text <= 45 or text:find("\n", 1, true) then return text end
    local mid, best = #text / 2, nil
    for i = 2, #text - 1 do
        if text:sub(i, i) == " " and (not best or math.abs(i - mid) < math.abs(best - mid)) then best = i end
    end
    -- a comma within 20 letters of the middle: the break after it
    for i = math.floor(mid) - 20, math.floor(mid) + 20 do
        if i > 1 and i < #text and text:sub(i, i + 1) == ", " then best = i + 1 break end
    end
    if not best then return text end
    return text:sub(1, best - 1) .. "\n" .. text:sub(best + 1)
end
