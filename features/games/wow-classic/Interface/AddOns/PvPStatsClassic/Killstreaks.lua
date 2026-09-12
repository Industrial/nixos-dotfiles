local killStreakMilestoneFrame = nil

function UpdateKillStreak(playerName, level, class)
    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]

    characterData.CurrentKillStreak = characterData.CurrentKillStreak + 1

    -- Add player to current kill streak list
    if not characterData.CurrentKillStreakPlayers then
        characterData.CurrentKillStreakPlayers = {}
    end

    table.insert(characterData.CurrentKillStreakPlayers, {
        name = playerName,
        level = level,
        class = class or "UNKNOWN",
        timestamp = time()
    })

    -- Update kill streak popup if it's open, or auto-open if setting is enabled
    if PSC_UpdateKillStreakPopup then
        PSC_UpdateKillStreakPopup()
    end

    -- Auto-open kill streak popup if setting is enabled
    if PSC_DB.AutoOpenKillStreakPopup and PSC_CreateKillStreakPopup then
        PSC_CreateKillStreakPopup(true) -- Pass true to indicate this is an auto-open call
    end

    if characterData.CurrentKillStreak > characterData.HighestKillStreak then
        characterData.HighestKillStreak = characterData.CurrentKillStreak

        if characterData.HighestKillStreak > 10 and PSC_DB.EnableRecordAnnounceMessages and characterData.CurrentKillStreak % 10 == 0 then
            if not PSC_CurrentlyInBattleground then
                local recordMsg = string.gsub(PSC_DB.NewKillStreakRecordMessage, "STREAKCOUNT", characterData.HighestKillStreak)
                PSC_SendAnnounceMessage(recordMsg)
            end
        end
    end
end

local function IsKillStreakMilestone(count)
    local killstreakMilestones = {25, 50, 75, 100, 150, 200, 250, 300, 400, 500}

    for _, milestone in ipairs(killstreakMilestones) do
        if count == milestone then
            return true
        end
    end
    return false
end

function SetupKillstreakMilestoneAnimation(frame, duration)
    if frame.animGroup then
        frame.animGroup:Stop()
        frame.animGroup:SetScript("OnPlay", nil)
        frame.animGroup:SetScript("OnFinished", nil)
        frame.animGroup:SetScript("OnStop", nil)
    end

    local animGroup = frame:CreateAnimationGroup()
    animGroup:SetLooping("NONE")

    local fadeIn = animGroup:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.01)
    fadeIn:SetOrder(1)

    local hold = animGroup:CreateAnimation("Alpha")
    hold:SetFromAlpha(1)
    hold:SetToAlpha(1)
    hold:SetDuration(duration)
    hold:SetOrder(2)

    local fadeOut = animGroup:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.5)
    fadeOut:SetOrder(3)

    animGroup:SetScript("OnFinished", function()
        frame:Hide()
    end)

    frame.animGroup = animGroup
    return animGroup
end

local function CreateKillstreakMilestoneFrameIfNeeded()
    if killStreakMilestoneFrame then return killStreakMilestoneFrame end

    local frame = CreateFrame("Frame", "PSC_MilestoneFrame", UIParent)
    local sizeX, sizeY = 140, 140
    frame:SetSize(sizeX, sizeY)

    -- Use saved position if available, otherwise use default
    if PSC_DB and PSC_DB.KillStreakMilestoneFramePosition then
        frame:SetPoint(
            PSC_DB.KillStreakMilestoneFramePosition.point,
            UIParent,
            PSC_DB.KillStreakMilestoneFramePosition.relativePoint,
            PSC_DB.KillStreakMilestoneFramePosition.xOfs,
            PSC_DB.KillStreakMilestoneFramePosition.yOfs
        )
    else
        frame:SetPoint("TOP", 0, -10)
    end

    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)  -- Allow the frame to receive mouse input

    -- Set up the drag functionality
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        -- Save position to the database with new variable
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        if PSC_DB then
            PSC_DB.KillStreakMilestoneFramePosition = {
                point = point,
                relativePoint = relativePoint,
                xOfs = xOfs,
                yOfs = yOfs
            }
        end
    end)

    local icon = frame:CreateTexture("PSC_MilestoneIcon", "ARTWORK")
    icon:SetSize(sizeX, sizeY)
    icon:SetPoint("TOP", 0, 0)
    icon:SetTexture("Interface\\AddOns\\PvPStatsClassic\\img\\RedridgePoliceLogo.blp")
    frame.icon = icon

    local text = frame:CreateFontString("PSC_MilestoneText", "OVERLAY", "SystemFont_Huge1")
    text:SetPoint("TOP", icon, "BOTTOM", 0, -5)
    text:SetTextColor(1, 0, 0)
    text:SetTextHeight(25)
    frame.text = text

    frame:Hide()
    killStreakMilestoneFrame = frame
    return frame
end

local function PlayKillstreakMilestoneSound()
    PlaySound(8454) -- Warsong horde win sound
    PlaySound(8574) -- Cheer sound
end

function ShowKillStreakMilestone(killCount)
    if not PSC_DB.EnableKillStreakSoundsAndEmotes then
        return
    end

    if not IsKillStreakMilestone(killCount) then
        return
    end

    local frame = CreateKillstreakMilestoneFrameIfNeeded()

    frame.text:SetText(killCount .. " KILL STREAK")

    frame:Show()
    frame:SetAlpha(0)

    local animGroup = SetupKillstreakMilestoneAnimation(frame, 8.0)
    PlayKillstreakMilestoneSound()
    DoEmote("CHEER")
    animGroup:Play()
end
