local _, ns = ...

local Frames = {}
ns.MapSearchFrames = Frames

local Utils = ns.Utils
local CreateFrame = CreateFrame
local STAR_GLOW_TEXTURE = ns.MAP_SEARCH_STAR_GLOW_TEXTURE or "Interface\\Cooldown\\star4"
local PIN_RING_TEXTURE = "Interface\\AddOns\\EasyFind\\textures\\map-pin-glow"
local ANIM_DURATION = 0.5

function Frames.AttachBounceAnimation(frame, opts)
    opts = opts or {}
    local animGroup = frame:CreateAnimationGroup()
    animGroup:SetLooping("BOUNCE")

    local move
    if opts.offsetX or opts.offsetY then
        move = animGroup:CreateAnimation("Translation")
        move:SetOffset(opts.offsetX or 0, opts.offsetY or 0)
        move:SetDuration(opts.duration or ANIM_DURATION)
        if opts.moveKey then frame[opts.moveKey] = move end
    end

    local alpha
    if opts.fromAlpha or opts.toAlpha then
        alpha = animGroup:CreateAnimation("Alpha")
        alpha:SetFromAlpha(opts.fromAlpha or 1)
        alpha:SetToAlpha(opts.toAlpha or 0.4)
        alpha:SetDuration(opts.alphaDuration or opts.duration or ANIM_DURATION)
        if opts.smoothing then alpha:SetSmoothing(opts.smoothing) end
        if opts.alphaKey then frame[opts.alphaKey] = alpha end
    end

    frame[opts.groupKey or "animGroup"] = animGroup
    return animGroup, move, alpha
end

function Frames.AddHighlightBorderTextures(frame, color, alpha)
    color = color or ns.YELLOW_HIGHLIGHT
    alpha = alpha or 1

    local top = frame:CreateTexture(nil, "OVERLAY")
    top:SetColorTexture(Utils.RGB(color, alpha))
    frame.top = top

    local bottom = frame:CreateTexture(nil, "OVERLAY")
    bottom:SetColorTexture(Utils.RGB(color, alpha))
    frame.bottom = bottom

    local left = frame:CreateTexture(nil, "OVERLAY")
    left:SetColorTexture(Utils.RGB(color, alpha))
    frame.left = left

    local right = frame:CreateTexture(nil, "OVERLAY")
    right:SetColorTexture(Utils.RGB(color, alpha))
    frame.right = right
end

function Frames.CreateHighlightBox(globalName, parent, opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", globalName, parent)
    frame:SetFrameStrata(opts.strata or "HIGH")
    frame:SetFrameLevel(opts.level or 0)
    if opts.size then frame:SetSize(opts.size, opts.size) end
    if opts.mouse ~= nil then frame:EnableMouse(opts.mouse) end
    if opts.hidden then frame:Hide() end
    Frames.AddHighlightBorderTextures(frame, opts.color, opts.borderAlpha)

    local ring = frame:CreateTexture(nil, "OVERLAY")
    ring:SetPoint("CENTER")
    ring:SetTexture(PIN_RING_TEXTURE)
    ring:SetBlendMode("ADD")
    ring:SetVertexColor(Utils.RGB(opts.color or ns.YELLOW_HIGHLIGHT, 1))
    ring:Hide()
    frame.ring = ring
    if opts.anim ~= false then
        Frames.AttachBounceAnimation(frame, opts.anim or { fromAlpha = 1, toAlpha = 0.4 })
    end
    return frame
end



local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
function Frames.SquareIcon(icon)
    if type(icon) ~= "string" then return false end
    return icon:lower():find("^interface\\icons\\") ~= nil or icon:find("^atlas:classicon%-") ~= nil
end



local WELL_RING = { ns.GOLD_COLOR[1], ns.GOLD_COLOR[2], ns.GOLD_COLOR[3], 0.8 }
local WELL_FILL = { 0.05, 0.04, 0.03, 0.92 }
function Frames.SetPinIcon(pin, icon, face, category)
    ns.SetIconWell(pin.icon, nil)
    Utils.SetIconTexture(pin.icon, icon)
    local round = not face and Frames.SquareIcon(icon)
    if round and not pin.iconMask then
        local mask = pin:CreateMaskTexture()
        mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(pin.icon)
        pin.iconMask = mask
    end
    if round and not pin.iconRound then
        pin.icon:AddMaskTexture(pin.iconMask)
        pin.iconRound = true
    elseif not round and pin.iconRound then
        pin.icon:RemoveMaskTexture(pin.iconMask)
        pin.iconRound = nil
    end
    local provider = category and not face and ns.Extensions.Providers.byCategory[category]
    if provider and provider.iconWell then ns.SetIconWell(pin.icon, WELL_RING, WELL_FILL) end
end

function Frames.AddWaypointPinVisuals(pin, opts)
    opts = opts or {}
    local color = opts.color or ns.YELLOW_HIGHLIGHT

    local icon = pin:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    pin.icon = icon

    local glow = pin:CreateTexture(nil, "BACKGROUND")
    if opts.glowSize then glow:SetSize(opts.glowSize, opts.glowSize) end
    glow:SetPoint("CENTER")
    glow:SetTexture(opts.glowTexture or STAR_GLOW_TEXTURE)
    glow:SetVertexColor(Utils.RGB(color, opts.glowAlpha or 0.8))
    glow:SetBlendMode("ADD")
    pin.glow = glow

    if opts.anim ~= false then
        Frames.AttachBounceAnimation(pin, opts.anim or { fromAlpha = 1, toAlpha = 0.3 })
    end
end

function Frames.CreateIndicatorFrame(globalName, parent, opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", globalName, parent)
    frame:SetSize(opts.size or ns.ICON_SIZE, opts.size or ns.ICON_SIZE)
    frame:SetFrameStrata(opts.strata or "HIGH")
    frame:SetFrameLevel(opts.level or 0)
    frame:EnableMouse(false)
    ns.CreateIndicatorTextures(frame, opts.iconSize or opts.size, opts.glowSize)
    if opts.anim ~= false then
        local anim = opts.anim or { offsetX = 0, offsetY = -10, fromAlpha = 1, toAlpha = 0.4 }
        if opts.moveKey and anim.moveKey == nil then anim.moveKey = opts.moveKey end
        Frames.AttachBounceAnimation(frame, anim)
    end
    return frame
end
