local killMilestoneFrame = nil
local killMilestoneAutoHideTimer = nil

local PVP_RANK_ICONS = {
    [1] = "Interface\\PvPRankBadges\\PvPRank01",
    [2] = "Interface\\PvPRankBadges\\PvPRank02",
    [3] = "Interface\\PvPRankBadges\\PvPRank03",
    [4] = "Interface\\PvPRankBadges\\PvPRank04",
    [5] = "Interface\\PvPRankBadges\\PvPRank05",
    [6] = "Interface\\PvPRankBadges\\PvPRank06",
    [7] = "Interface\\PvPRankBadges\\PvPRank07",
    [8] = "Interface\\PvPRankBadges\\PvPRank08",
    [9] = "Interface\\PvPRankBadges\\PvPRank09",
    [10] = "Interface\\PvPRankBadges\\PvPRank10",
    [11] = "Interface\\PvPRankBadges\\PvPRank11",
    [12] = "Interface\\PvPRankBadges\\PvPRank12",
    [13] = "Interface\\PvPRankBadges\\PvPRank13",
    [14] = "Interface\\PvPRankBadges\\PvPRank14"
}

local function PSC_CreateKillMilestoneFrame()
    if killMilestoneFrame then return killMilestoneFrame end

    local milestoneFrame = CreateFrame("Frame", "PSC_KillMilestoneFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    milestoneFrame:SetSize(200, 82)  -- Base size - will be adjusted dynamically
    milestoneFrame:SetPoint("TOP", UIParent, "TOP", 0, -100)  -- Initial position
    milestoneFrame:SetFrameStrata("MEDIUM")
    milestoneFrame:SetMovable(true)
    milestoneFrame:EnableMouse(true)
    milestoneFrame:SetClampedToScreen(true)

    local backdrop = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    }

    if milestoneFrame.SetBackdrop then
        milestoneFrame:SetBackdrop(backdrop)
    else
        local bg = milestoneFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(backdrop.bgFile)
---@diagnostic disable-next-line: param-type-mismatch
        bg:SetAllPoints(milestoneFrame)
        bg:SetTexCoord(0, 1, 0, 1)

        local border = milestoneFrame:CreateTexture(nil, "BORDER")
        border:SetTexture(backdrop.edgeFile)
        border:SetPoint("TOPLEFT", milestoneFrame, "TOPLEFT", -backdrop.edgeSize/2, backdrop.edgeSize/2)
        border:SetPoint("BOTTOMRIGHT", milestoneFrame, "BOTTOMRIGHT", backdrop.edgeSize/2, -backdrop.edgeSize/2)
    end

    milestoneFrame:RegisterForDrag("LeftButton")
    milestoneFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    milestoneFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        PSC_DB.MilestoneFramePosition = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs
        }
    end)

    local title = milestoneFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", milestoneFrame, "TOP", 0, -15)
    title:SetText("Kill Milestone")
    title:SetTextColor(1, 0.82, 0)
    milestoneFrame.title = title

    local leftMargin = 20

    local classIcon = milestoneFrame:CreateTexture(nil, "ARTWORK")
    classIcon:SetSize(24, 24)
    classIcon:SetPoint("TOPLEFT", milestoneFrame, "TOPLEFT", leftMargin, -30)
    milestoneFrame.classIcon = classIcon

    local nameText = milestoneFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", classIcon, "TOPRIGHT", 5, 0)
    nameText:SetJustifyH("LEFT")
    milestoneFrame.nameText = nameText

    local levelText = milestoneFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
    levelText:SetTextColor(0.8, 0.8, 0.8)
    levelText:SetJustifyH("LEFT")
    milestoneFrame.levelText = levelText

    local killText = milestoneFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    killText:SetPoint("TOPLEFT", levelText, "BOTTOMLEFT", 0, -2)
    killText:SetTextColor(1, 0.82, 0) -- Gold color
    killText:SetJustifyH("LEFT")
    milestoneFrame.killText = killText

    local close = CreateFrame("Button", nil, milestoneFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", milestoneFrame, "TOPRIGHT", -5, -5)
    close:SetSize(20, 20)
    close:SetScript("OnClick", function()
        milestoneFrame:Hide()
        if killMilestoneAutoHideTimer then
            killMilestoneAutoHideTimer:Cancel()
            killMilestoneAutoHideTimer = nil
        end
    end)

    milestoneFrame:Hide()
    killMilestoneFrame = milestoneFrame
    return milestoneFrame
end

function PSC_ShowKillMilestone(playerName, level, class, rank, killCount)
    if not PSC_DB.ShowKillMilestones then return end
    if not PSC_DB.ShowMilestoneForFirstKill and killCount == 1 then return end

    local milestoneFrame = PSC_CreateKillMilestoneFrame()
    local class_upper = class:upper()

    local pos = PSC_DB.MilestoneFramePosition
    milestoneFrame:ClearAllPoints()
    milestoneFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)

    if killCount ~= 1 and killCount % PSC_DB.KillMilestoneInterval ~= 0 then
        return
    end

    local classIconCoords = CLASS_ICON_TCOORDS[class_upper or "WARRIOR"]
    if classIconCoords then
        milestoneFrame.classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        milestoneFrame.classIcon:SetTexCoord(unpack(classIconCoords))
    else
        milestoneFrame.classIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    local classColor = RAID_CLASS_COLORS[class_upper] or RAID_CLASS_COLORS["WARRIOR"]
    milestoneFrame.nameText:SetText(playerName)
    milestoneFrame.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)

    local rankName = nil
    if rank and rank > 0 then
        rankName = PSC_GetRankName(rank)
    end

    local levelString = "Level " .. (level > 0 and level or "??")
    if rankName then
        levelString = levelString .. " - " .. rankName
    end
    milestoneFrame.levelText:SetText(levelString)

    -- Add PvP rank icon next to the rank title if rank is higher than 0
    local rankIconWidth = 0
    if rank and rank > 0 then
        if not milestoneFrame.rankIcon then
            local rankIcon = milestoneFrame:CreateTexture(nil, "OVERLAY")
            rankIcon:SetSize(16, 16) -- Smaller size for the rank icon
            rankIcon:SetPoint("LEFT", milestoneFrame.levelText, "RIGHT", 5, 0)
            milestoneFrame.rankIcon = rankIcon
        end
        milestoneFrame.rankIcon:SetTexture(PVP_RANK_ICONS[rank])
        milestoneFrame.rankIcon:Show()
        rankIconWidth = 16 + 5 -- Icon width + spacing
    elseif milestoneFrame.rankIcon then
        milestoneFrame.rankIcon:Hide()
    end

    local killMessage
    local suffix
    if killCount % 100 >= 11 and killCount % 100 <= 13 then
        suffix = "th"
    else
        local lastDigit = killCount % 10
        if lastDigit == 1 then
            suffix = "st"
        elseif lastDigit == 2 then
            suffix = "nd"
        elseif lastDigit == 3 then
            suffix = "rd"
        else
            suffix = "th"
        end
    end
    killMessage = killCount .. suffix .. " kill!"
    milestoneFrame.killText:SetText(killMessage)

    milestoneFrame.levelText:SetWidth(0)
    local levelTextWidth = milestoneFrame.levelText:GetStringWidth()

    milestoneFrame.nameText:SetWidth(0)
    local nameTextWidth = milestoneFrame.nameText:GetStringWidth()

    milestoneFrame.killText:SetWidth(0)
    local killTextWidth = milestoneFrame.killText:GetStringWidth()

    local requiredContentWidth = math.max(levelTextWidth, nameTextWidth, killTextWidth)

    local frameWidth = 20 + 24 + 5 + requiredContentWidth + 20 + rankIconWidth

    local minWidth = 140   -- Minimum width
    local maxWidth = 300   -- Maximum width cap
    frameWidth = math.min(maxWidth, math.max(minWidth, frameWidth))

    milestoneFrame:SetWidth(frameWidth)

    local textWidth = frameWidth - (20 + 24 + 5 + 20 + rankIconWidth) -- Left margin + icon + spacing + right margin + rank icon width
    milestoneFrame.nameText:SetWidth(textWidth)
    milestoneFrame.levelText:SetWidth(textWidth)
    milestoneFrame.killText:SetWidth(textWidth)

    milestoneFrame:Show()
    local animGroup = SetupKillstreakMilestoneAnimation(milestoneFrame, PSC_DB.KillMilestoneAutoHideTime)
    animGroup:Play()

    if PSC_DB.EnableKillMilestoneSound then
        PlaySound(8213) -- PVPFlagCapturedHorde
    end

    if killMilestoneAutoHideTimer then
        killMilestoneAutoHideTimer:Cancel()
    end

    killMilestoneAutoHideTimer = C_Timer.NewTimer(PSC_DB.KillMilestoneAutoHideTime + 1.0, function()
        milestoneFrame:Hide()
        killMilestoneAutoHideTimer = nil
    end)
end
