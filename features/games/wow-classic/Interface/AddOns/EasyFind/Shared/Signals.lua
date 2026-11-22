local _, ns = ...




local Signals = {}
ns.Signals = Signals

local L = ns.L
local CreateFrame, UIParent = CreateFrame, UIParent
local PlaySound, FlashClientIcon = PlaySound, FlashClientIcon


local SOUNDKIT = SOUNDKIT or {}
Signals.SOUNDS = {
    { key = "alarm", kit = SOUNDKIT.ALARM_CLOCK_WARNING_3, label = L["SIGNAL_SOUND_ALARM"] },
    { key = "alarm2", kit = SOUNDKIT.ALARM_CLOCK_WARNING_2, label = L["SIGNAL_SOUND_ALARM2"] },
    { key = "raidwarning", kit = SOUNDKIT.RAID_WARNING, label = _G["RAID_WARNING"] or L["SIGNAL_SOUND_RAIDWARNING"] },
    { key = "readycheck", kit = SOUNDKIT.READY_CHECK, label = _G["READY_CHECK"] or L["SIGNAL_SOUND_READYCHECK"] },
    { key = "whisper", kit = SOUNDKIT.TELL_MESSAGE, label = _G["WHISPER"] or L["SIGNAL_SOUND_WHISPER"] },
    { key = "invite", kit = SOUNDKIT.IG_PLAYER_INVITE, label = L["SIGNAL_SOUND_INVITE"] },
    { key = "ping", kit = SOUNDKIT.MAP_PING, label = L["SIGNAL_SOUND_PING"] },
    { key = "quest", kit = SOUNDKIT.IG_QUEST_LIST_COMPLETE, label = L["SIGNAL_SOUND_QUEST"] },
}
local SOUND_BY_KEY = {}
for _, s in ipairs(Signals.SOUNDS) do SOUND_BY_KEY[s.key] = s end

function Signals.SoundLabel(key)
    local s = SOUND_BY_KEY[key]
    return s and s.label or (_G["NONE"] or L["SIGNAL_SOUND_NONE"])
end

function Signals.PlaySound(key)
    local s = SOUND_BY_KEY[key]
    if s and s.kit then PlaySound(s.kit, "Master") end
end


Signals.COLORS = {
    { key = "red", rgb = { 1, 0.15, 0.1 }, label = L["SIGNAL_COLOR_RED"] },
    { key = "gold", rgb = { 1, 0.78, 0.1 }, label = L["SIGNAL_COLOR_GOLD"] },
    { key = "green", rgb = { 0.2, 1, 0.3 }, label = L["SIGNAL_COLOR_GREEN"] },
    { key = "blue", rgb = { 0.25, 0.55, 1 }, label = L["SIGNAL_COLOR_BLUE"] },
    { key = "purple", rgb = { 0.7, 0.3, 1 }, label = L["SIGNAL_COLOR_PURPLE"] },
}
local COLOR_BY_KEY = {}
for _, c in ipairs(Signals.COLORS) do COLOR_BY_KEY[c.key] = c end

function Signals.ColorLabel(key)
    local c = COLOR_BY_KEY[key]
    return c and c.label or ""
end

local UI = {}

local function FadeGroup(frame, hold, out)
    local group = frame:CreateAnimationGroup()
    local a = group:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(1)
    a:SetDuration(hold)
    a:SetOrder(1)
    local b = group:CreateAnimation("Alpha")
    b:SetFromAlpha(1)
    b:SetToAlpha(0)
    b:SetDuration(out)
    b:SetOrder(2)
    group:SetScript("OnFinished", function() frame:Hide() end)
    return group
end



function Signals.ShowText(text, rgb)
    local big = UI.big
    if not big then
        big = CreateFrame("Frame", nil, UIParent)
        big:SetSize(900, 60)
        big:SetPoint("CENTER", UIParent, "CENTER", 0, 170)
        big:SetFrameStrata("DIALOG")
        big:EnableMouse(false)
        big.text = big:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        local font = big.text:GetFont()
        if font then big.text:SetFont(font, 30, "OUTLINE") end
        big.text:SetAllPoints()
        big.fade = FadeGroup(big, 4, 1.5)
        UI.big = big
    end
    local c = rgb or ns.GOLD_COLOR
    big.text:SetTextColor(c[1], c[2], c[3], 1)
    big.text:SetText(text)
    big.fade:Stop()
    big:SetAlpha(1)
    big:Show()
    big.fade:Play()
end




local EDGE_DEPTH = 0.18
local function SizeEdge(edge, w, h)
    for _, tex in ipairs(edge.strips) do
        if tex.side == "TOP" or tex.side == "BOTTOM" then tex:SetHeight(h * EDGE_DEPTH) else tex:SetWidth(w * EDGE_DEPTH) end
    end
end
function Signals.FlashScreen(colorKey)
    local edge = UI.edge
    if not edge then
        edge = CreateFrame("Frame", nil, UIParent)
        edge:SetAllPoints(UIParent)
        edge:SetFrameStrata("FULLSCREEN_DIALOG")
        edge:EnableMouse(false)
        edge.strips = {}
        for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            local tex = edge:CreateTexture(nil, "BACKGROUND")
            tex:SetColorTexture(1, 1, 1, 1)
            tex:SetBlendMode("ADD")
            tex.side = side
            if side == "TOP" or side == "BOTTOM" then
                tex:SetPoint(side .. "LEFT", edge, side .. "LEFT", 0, 0)
                tex:SetPoint(side .. "RIGHT", edge, side .. "RIGHT", 0, 0)
            else
                tex:SetPoint("TOP" .. side, edge, "TOP" .. side, 0, 0)
                tex:SetPoint("BOTTOM" .. side, edge, "BOTTOM" .. side, 0, 0)
            end
            edge.strips[#edge.strips + 1] = tex
        end
        edge:SetScript("OnSizeChanged", SizeEdge)
        SizeEdge(edge, edge:GetWidth() or 0, edge:GetHeight() or 0)
        edge.fade = FadeGroup(edge, 0.35, 0.9)
        UI.edge = edge
    end
    local c = (COLOR_BY_KEY[colorKey] or Signals.COLORS[1]).rgb
    local on, off = CreateColor(c[1], c[2], c[3], 0.85), CreateColor(c[1], c[2], c[3], 0)
    for _, tex in ipairs(edge.strips) do

        if tex.side == "TOP" then tex:SetGradient("VERTICAL", off, on)
        elseif tex.side == "BOTTOM" then tex:SetGradient("VERTICAL", on, off)
        elseif tex.side == "LEFT" then tex:SetGradient("HORIZONTAL", on, off)
        else tex:SetGradient("HORIZONTAL", off, on) end
    end
    edge.fade:Stop()
    edge:SetAlpha(1)
    edge:Show()
    edge.fade:Play()
end



function Signals.Fire(spec, text, quiet)
    if spec.chat then EasyFind:Print(text) end
    if spec.big then Signals.ShowText(text) end
    if quiet then return end
    if spec.sound then Signals.PlaySound(spec.sound) end
    if spec.screen then Signals.FlashScreen(spec.screen) end
    if spec.taskbar then FlashClientIcon() end
end
