local _, ns = ...

local Utils = ns.Utils
local unpack = unpack
local mpi = Utils.mpi or math.pi

local STAR_GLOW_TEXTURE = "Interface\\Cooldown\\star4"
ns.MAP_SEARCH_STAR_GLOW_TEXTURE = STAR_GLOW_TEXTURE
local CHEVRON_TEXTURE = "Interface\\AddOns\\EasyFind\\textures\\chevron"
local CHEVRON_GLOW_TEXTURE = "Interface\\AddOns\\EasyFind\\textures\\chevron-glow"
local INDICATOR_STYLES = {

    ["Chevrons"] = {
        texture = CHEVRON_TEXTURE,
        texCoord = nil,
        preRotated = true,
        chevrons = true,
    },
    ["Classic Quest Arrow"] = {
        texture = "Interface\\MINIMAP\\MiniMap-QuestArrow",
        texCoord = nil,
        preRotated = false,
    },
    ["EasyFind Arrow"] = {
        texture = "Interface\\AddOns\\EasyFind\\MapSearch\\Images\\arrow-hq",
        texCoord = nil,
        preRotated = true,
    },
    ["Minimap Player Arrow"] = {
        texture = "Interface\\Minimap\\MinimapArrow",
        texCoord = nil,
        preRotated = false,
    },
    ["Low-res Gauntlet"] = {
        texture = "Interface\\CURSOR\\Point",
        texCoord = nil,
        preRotated = true,
        rotation = 2.356,
        offsetX = 0,
        offsetY = 0,
    },
    ["HD Gauntlet"] = {
        texture = 6116532,
        texCoord = {0.000, 0.240, 0.000, 0.420},
        preRotated = true,
        rotation = 2.356,
        offsetX = 0,
        offsetY = 0,
    },
}

if ns.Caps.classic then INDICATOR_STYLES["HD Gauntlet"] = nil end

local INDICATOR_COLORS = {
    ["Yellow"]  = {1.0, 1.0, 0.0},
    ["Gold"]    = {1.0, 0.82, 0.0},
    ["Orange"]  = {1.0, 0.5, 0.0},
    ["Red"]     = {1.0, 0.2, 0.2},
    ["Green"]   = {0.2, 1.0, 0.2},
    ["Blue"]    = {0.3, 0.6, 1.0},
    ["Purple"]  = {0.7, 0.3, 1.0},
    ["White"]   = {1.0, 1.0, 1.0},
}

ns.INDICATOR_COLORS = INDICATOR_COLORS

function ns.GetIndicatorStyleInfo(name)
    return INDICATOR_STYLES[name] or INDICATOR_STYLES["EasyFind Arrow"]
end

local function GetIndicatorColor()
    local colorName = EasyFind.db.indicatorColor or "Yellow"
    return INDICATOR_COLORS[colorName] or INDICATOR_COLORS["Yellow"]
end

ns.GetIndicatorTexture = function()
    local style = EasyFind.db.indicatorStyle or "EasyFind Arrow"
    return INDICATOR_STYLES[style] or INDICATOR_STYLES["EasyFind Arrow"]
end
ns.GetIndicatorColor = GetIndicatorColor


ns.ICON_SIZE = 48
ns.ICON_GLOW_SIZE = 68
ns.PIN_SIZE = 28
ns.PIN_GLOW_SIZE = 40
ns.HIGHLIGHT_SIZE = 30

ns.MULTI_SCALE = 1.0

ns.ZONE_ICON_SIZE = 48
ns.ZONE_ICON_GLOW_SIZE = 68

ns.BREADCRUMB_SIZE = 48



function ns.UIToCanvas(uiSize)
    local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
    if not sc or not sc.Child then return uiSize end
    local canvasW = sc.Child:GetWidth()
    local viewportW = sc:GetWidth()
    if not canvasW or canvasW == 0 or not viewportW or viewportW == 0 then
        return uiSize
    end
    return uiSize * (canvasW / viewportW)
end



local CHEVRON = { travel = 36 / 48, start = -10 / 48, back = 0.6, duration = 1.25, easing = 0.5,
    fadeStart = 0.75, glow = 0.7, size = 64 / 48 }

local CHEVRON_WAYS = {
    down  = { rot = 0,        x = 0,  y = -1 },
    up    = { rot = mpi,      x = 0,  y = 1 },
    right = { rot = mpi / 2,  x = 1,  y = 0 },
    left  = { rot = -mpi / 2, x = -1, y = 0 },
}

local function ChevronsOnUpdate(driver, dt)
    local host = driver:GetParent()

    local bounce = host.animGroup
    if bounce and bounce:IsPlaying() then bounce:Stop() end
    driver.elapsed = driver.elapsed + dt
    local w = host:GetWidth() or 0
    local way = CHEVRON_WAYS[host.indicatorDirection or "down"] or CHEVRON_WAYS.down
    if driver.way ~= way or driver.w ~= w then
        driver.way, driver.w = way, w
        for _, pair in ipairs(driver.pairs) do
            for _, tex in ipairs(pair) do
                tex:SetSize(w * CHEVRON.size, w * CHEVRON.size)
                tex:SetRotation(way.rot)
            end
        end
    end
    local travel, start = w * CHEVRON.travel, w * CHEVRON.start
    local base = (driver.elapsed / CHEVRON.duration) % 1
    for i, pair in ipairs(driver.pairs) do
        local phase = (base + (i - 1) / #driver.pairs) % 1
        local off = start + (travel - start) * phase ^ CHEVRON.easing - travel * CHEVRON.back
        local alpha = phase > CHEVRON.fadeStart and (1 - phase) / (1 - CHEVRON.fadeStart) or 1
        local core, glow = pair[1], pair[2]
        core:SetPoint("CENTER", host, "CENTER", way.x * off, way.y * off)
        glow:SetPoint("CENTER", host, "CENTER", way.x * off, way.y * off)
        core:SetAlpha(alpha)
        glow:SetAlpha(alpha * CHEVRON.glow)
    end
end


local function ShowChevrons(host, color)
    local driver = host.chevrons
    if not driver then
        driver = CreateFrame("Frame", nil, host)
        driver:SetAllPoints()
        driver.elapsed, driver.pairs = 0, {}
        for i = 1, 2 do
            local core = driver:CreateTexture(nil, "OVERLAY", nil, 1)
            core:SetTexture(CHEVRON_TEXTURE)
            core:SetBlendMode("ADD")
            local glow = driver:CreateTexture(nil, "OVERLAY", nil, 0)
            glow:SetTexture(CHEVRON_GLOW_TEXTURE)
            glow:SetBlendMode("ADD")
            driver.pairs[i] = { core, glow }
        end
        driver:SetScript("OnUpdate", ChevronsOnUpdate)
        host.chevrons = driver
    end
    for _, pair in ipairs(driver.pairs) do
        pair[1]:SetVertexColor(color[1], color[2], color[3])
        pair[2]:SetVertexColor(color[1], color[2] * 0.73, color[3])
    end
    driver.w = nil
    driver:Show()
end



function ns.CreateIndicatorTextures(parentFrame, iconSize, glowSize)
    iconSize = iconSize or ns.ICON_SIZE
    glowSize = glowSize or ns.ICON_GLOW_SIZE
    local style = ns.GetIndicatorTexture()
    local color = GetIndicatorColor()
    local ox, oy = style.offsetX or 0, style.offsetY or 0

    local ind = parentFrame:CreateTexture(nil, "ARTWORK")
    ind:SetSize(iconSize, iconSize)
    ind:SetPoint("CENTER", parentFrame, "CENTER", ox, oy)
    ind:SetTexture(style.texture)
    if style.texCoord then
        ind:SetTexCoord(unpack(style.texCoord))
    end
    ind:SetVertexColor(Utils.RGB(color, 1))
    local indicatorRotation = 0
    if style.rotation then
        indicatorRotation = style.rotation
    elseif not style.preRotated then
        indicatorRotation = mpi
    end
    ind:SetRotation(indicatorRotation)
    parentFrame.indicator = ind

    if glowSize and glowSize > 0 then
        local glow = parentFrame:CreateTexture(nil, "BACKGROUND")
        glow:SetSize(glowSize, glowSize)
        glow:SetPoint("CENTER")
        glow:SetTexture(STAR_GLOW_TEXTURE)
        glow:SetVertexColor(Utils.RGB(color, 0.35))
        glow:SetBlendMode("ADD")
        parentFrame.glow = glow
    end

    parentFrame:HookScript("OnShow", function(self)
        ns.UpdateIndicator(self)
    end)
end

function ns.UpdateIndicator(parentFrame)
    if not parentFrame or not parentFrame.indicator then return end
    local style = ns.GetIndicatorTexture()
    local color = GetIndicatorColor()
    local tex = parentFrame.indicator
    local ox, oy = style.offsetX or 0, style.offsetY or 0

    tex:SetTexture(style.texture)
    if style.texCoord then
        tex:SetTexCoord(unpack(style.texCoord))
    else
        tex:SetTexCoord(0, 1, 0, 1)
    end
    local indicatorRotation
    if parentFrame.indicatorDirection then
        indicatorRotation = ns.GetDirectionalRotation(parentFrame.indicatorDirection)
    elseif style.rotation then
        indicatorRotation = style.rotation
    elseif style.preRotated then
        indicatorRotation = 0
    else
        indicatorRotation = mpi
    end
    tex:SetRotation(indicatorRotation)
    tex:SetVertexColor(Utils.RGB(color, 1))
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", parentFrame, "CENTER", ox, oy)


    local fw, fh = parentFrame:GetSize()
    if fw and fw > 0 then
        tex:SetSize(fw, fh)
    end

    if parentFrame.glow then
        parentFrame.glow:SetVertexColor(Utils.RGB(color, 0.35))
    end


    if style.chevrons then
        tex:Hide()
        if parentFrame.glow then parentFrame.glow:Hide() end
        parentFrame.chevronsUp = true
        ShowChevrons(parentFrame, color)
    elseif parentFrame.chevronsUp then
        parentFrame.chevronsUp = nil
        tex:Show()
        if parentFrame.glow then parentFrame.glow:Show() end
        parentFrame.chevrons:Hide()
    end


    if parentFrame.isUIIndicator then
        parentFrame:SetScale(EasyFind.db.iconScale or 0.8)
    end
end

function ns.GetDirectionalRotation(direction)
    local style = ns.GetIndicatorTexture()

    local baseDown = style.rotation or (style.preRotated and 0 or mpi)


    if direction == "down" then
        return baseDown
    elseif direction == "up" then
        return baseDown + mpi
    elseif direction == "right" then
        return baseDown + mpi / 2
    elseif direction == "left" then
        return baseDown - mpi / 2
    end
    return baseDown
end
