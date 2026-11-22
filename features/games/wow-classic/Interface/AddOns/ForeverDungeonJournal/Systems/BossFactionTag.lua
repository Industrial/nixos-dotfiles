-- "HORDE ONLY" / "ALLIANCE ONLY" tag with the faction crest on the right of a
-- boss row, for bosses that only one faction can fight (boss.factionOnly).
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local ICONS = {
    Horde = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\Horde.tga",
    Alliance = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\Alliance.tga",
}

local function Label(faction)
    local name = (faction == "Horde" and _G.FACTION_HORDE) or (faction == "Alliance" and _G.FACTION_ALLIANCE) or faction
    local text = FDJ.L and FDJ.L("CLASS_ONLY", tostring(name):upper())
    if type(text) ~= "string" or text == "CLASS_ONLY" then text = tostring(name):upper() .. " ONLY" end
    return text
end

function FDJ.ApplyBossFactionTag(button, boss, isRare)
    local faction = boss and boss.factionOnly
    if not faction or not ICONS[faction] then
        if button.fdjFactionTag then button.fdjFactionTag:Hide(); button.fdjFactionIcon:Hide() end
        return
    end
    if not button.fdjFactionTag then
        button.fdjFactionTag = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
        button.fdjFactionIcon = button:CreateTexture(nil, "OVERLAY")
        button.fdjFactionIcon:SetSize(16, 16)
    end
    local tag, icon = button.fdjFactionTag, button.fdjFactionIcon
    tag:SetText(Label(faction))
    if faction == "Horde" then tag:SetTextColor(1.00, 0.30, 0.25) else tag:SetTextColor(0.45, 0.65, 1.00) end
    icon:SetTexture(ICONS[faction])
    tag:ClearAllPoints()
    if isRare and button.rare then
        tag:SetPoint("RIGHT", button.rare, "LEFT", -8, 0)
    else
        tag:SetPoint("RIGHT", button, "RIGHT", -20, 1)
    end
    icon:ClearAllPoints()
    icon:SetPoint("RIGHT", tag, "LEFT", -3, 0)
    tag:Show(); icon:Show()
    button.name:SetPoint("RIGHT", icon, "LEFT", -6, 0)
end
