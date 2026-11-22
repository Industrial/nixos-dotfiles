

local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).stale then return end





















local Spotlight = {}
ns.FeatureSpotlight = Spotlight

local Utils = ns.Utils
local CreateFrame = CreateFrame
local wipe = wipe

local registered = {}
local pulseFrames = {}

local function IsDone(id)
    local done = EasyFind and EasyFind.db and EasyFind.db.spotlightsDone
    return done and done[id] or false
end




local function GetPulse(id)
    local pulse = pulseFrames[id]
    if pulse then return pulse end
    pulse = CreateFrame("Frame", nil, UIParent)
    pulse:SetFrameStrata("DIALOG")
    local glow = pulse:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints()
    glow:SetAtlas("collections-newglow")
    glow:SetVertexColor(0.3, 0.85, 1.0, 0.6)
    glow:SetBlendMode("ADD")
    local anim = glow:CreateAnimationGroup()
    anim:SetLooping("BOUNCE")
    local alpha = anim:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.9)
    alpha:SetToAlpha(0.15)
    alpha:SetDuration(0.9)
    pulse.anim = anim
    pulse:Hide()
    pulseFrames[id] = pulse
    return pulse
end





local tagFrames = {}

local function GetTag(id)
    local tag = tagFrames[id]
    if tag then return tag end
    tag = CreateFrame("Frame", nil, UIParent)
    tag:SetFrameStrata("TOOLTIP")
    tag:EnableMouse(false)
    local text = tag:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER")
    text:SetText(_G["NEW"] or "New")
    text:SetTextColor(1, 1, 1)
    text:SetShadowColor(0.3, 0.9, 1.0, 1)
    text:SetShadowOffset(1, -1)
    tag:SetSize(text:GetStringWidth() + 4, 14)
    local glow = tag:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("CENTER")
    glow:SetSize(text:GetStringWidth() + 28, 24)
    glow:SetAtlas("collections-newglow")
    glow:SetVertexColor(0.3, 0.85, 1.0, 0.5)
    glow:SetBlendMode("ADD")
    local anim = glow:CreateAnimationGroup()
    anim:SetLooping("BOUNCE")
    local alpha = anim:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.8)
    alpha:SetToAlpha(0.1)
    alpha:SetDuration(1.5)
    tag.anim = anim
    tag:Hide()
    tagFrames[id] = tag
    return tag
end

local function HideTag(id)
    local tag = tagFrames[id]
    if tag then
        tag.anim:Stop()
        tag:Hide()
        tag:SetParent(UIParent)
        tag:ClearAllPoints()
    end
end

local function ShowPulseOn(id, target)
    local pulse = GetPulse(id)
    pulse:SetParent(target)
    pulse:SetFrameLevel((target:GetFrameLevel() or 1) + 5)
    pulse:ClearAllPoints()


    pulse:SetPoint("TOPLEFT", target, "TOPLEFT", -14, 10)
    pulse:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 14, -10)
    pulse:Show()
    pulse.anim:Play()
end

local function ShowTagOn(id, target, place)
    if not place then HideTag(id) return end
    local tag = GetTag(id)
    tag:SetParent(target)
    tag:SetFrameLevel((target:GetFrameLevel() or 1) + 6)
    tag:ClearAllPoints()
    place(tag, target)
    tag:Show()
    tag.anim:Play()
end

local function HidePulse(id)
    local pulse = pulseFrames[id]
    if pulse then
        pulse.anim:Stop()
        pulse:Hide()
        pulse:SetParent(UIParent)
        pulse:ClearAllPoints()
    end
    HideTag(id)
end

function Spotlight:Register(def)
    if not (def and def.id and def.steps) then return end
    registered[def.id] = def
end








local claimedTargets = {}

function Spotlight:Refresh()
    wipe(claimedTargets)
    for id, def in pairs(registered) do
        if IsDone(id) then
            HidePulse(id)
        else
            local target, place
            for i = 1, #def.steps do
                local ok, frame = pcall(def.steps[i])
                if ok and frame and frame.IsVisible and frame:IsVisible() then
                    target = frame
                    place = def.tagPlace and def.tagPlace[i] or nil
                end
            end
            if target and not claimedTargets[target] then
                claimedTargets[target] = true
                ShowPulseOn(id, target)
                ShowTagOn(id, target, place)
            else
                HidePulse(id)
            end
        end
    end
end

function Spotlight:Complete(id)
    if not registered[id] or IsDone(id) then return end
    if EasyFind and EasyFind.db then
        EasyFind.db.spotlightsDone = EasyFind.db.spotlightsDone or {}
        EasyFind.db.spotlightsDone[id] = true
    end
    HidePulse(id)
end

function Spotlight:Initialize()




    if EasyFind and EasyFind.db and not EasyFind.db.tutorialDone then
        EasyFind.db.spotlightsDone = EasyFind.db.spotlightsDone or {}
        EasyFind.db.spotlightsDone.snippets31 = true
    end









    self:Register{
        id = "snippets31",
        steps = {
            function()


                if ns.IsCompanionLoadable and (not ns.IsCompanionLoadable("EasyFind_Options")
                   or not ns.IsCompanionLoadable("EasyFind_Snippets")) then
                    return nil
                end
                local sf = ns.Search and ns.Search.GetSearchFrame and ns.Search:GetSearchFrame()
                return sf and sf.appsBtn
            end,
            function()
                local sf = ns.Search and ns.Search.GetSearchFrame and ns.Search:GetSearchFrame()
                local dropdown = sf and sf.appsDropdown
                if not (dropdown and dropdown:IsShown() and dropdown.rows) then return nil end
                for i = 1, #dropdown.rows do
                    local row = dropdown.rows[i]
                    if row:IsShown() and row.app and row.app.extensionID == "snippets" then
                        return row
                    end
                end
            end,
        },
        tagPlace = {
            function(tag, target)
                tag:SetPoint("BOTTOM", target, "TOP", 0, -3)
            end,
            function(tag, target)
                local label = target.label
                if label then
                    tag:SetPoint("LEFT", label, "LEFT", label:GetStringWidth() + 4, 0)
                else
                    tag:SetPoint("RIGHT", target, "RIGHT", -4, 0)
                end
            end,
        },
    }



    Utils.SafeAfter(0, function()
        local sf = ns.Search and ns.Search.GetSearchFrame and ns.Search:GetSearchFrame()
        if not sf then return end
        sf:HookScript("OnShow", function() Spotlight:Refresh() end)
        sf:HookScript("OnHide", function() Spotlight:Refresh() end)
        if sf.appsDropdown then
            sf.appsDropdown:HookScript("OnShow", function() Spotlight:Refresh() end)
            sf.appsDropdown:HookScript("OnHide", function() Spotlight:Refresh() end)
        end
        Spotlight:Refresh()
    end)
end




local initOk, initErr = pcall(function() Spotlight:Initialize() end)
if not initOk then
    ns.Utils.DebugPrint("FeatureSpotlight init failed: " .. tostring(initErr))
end

return Spotlight
