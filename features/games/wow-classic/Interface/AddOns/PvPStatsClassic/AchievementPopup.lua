local addonName, PVPSC = ...

PVPSC.AchievementSystem = PVPSC.AchievementSystem or {}
local AchievementSystem = PVPSC.AchievementSystem

PVPSC.AchievementPopup = {}
local AchievementPopup = PVPSC.AchievementPopup

-- Settings
local POPUP_DISPLAY_TIME = 9
local POPUP_FADE_TIME = 1 -- Fade out over 1 second


AchievementPopup.queue = {}
AchievementPopup.isDisplaying = false
AchievementPopup.currentTimer = nil


local function CreateAchievementPopupFrame()
    local frame = CreateFrame("Frame", "PVPStatsClassicAchievementPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    frame:SetSize(300, 100)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetClampedToScreen(true)

    -- Register with FrameManager as a notification popup (no keyboard handling)
    if PSC_FrameManager then
        PSC_FrameManager:RegisterFrame(frame, "AchievementPopup", true)
    end


    frame:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 11, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)


    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetText("Achievement Unlocked!")
    title:SetTextColor(1, 0.82, 0) -- Gold text
    title:SetJustifyH("CENTER")
    frame.title = title


    local iconContainer = CreateFrame("Frame", nil, frame)
    iconContainer:SetSize(40, 40)
    iconContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -40)

    local icon = iconContainer:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("CENTER", iconContainer, "CENTER")
    frame.icon = icon
    frame.iconContainer = iconContainer


    local achievementName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    achievementName:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
    achievementName:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    achievementName:SetTextColor(1, 0.82, 0) -- Gold text
    achievementName:SetJustifyH("LEFT")
    frame.achievementName = achievementName


    local description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", achievementName, "BOTTOMLEFT", 0, -5)
    description:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    description:SetTextColor(0.9, 0.9, 0.9) -- Light gray text
    description:SetJustifyH("LEFT")
    frame.description = description


    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    closeButton:SetSize(24, 24)
    closeButton:SetScript("OnClick", function()

        if AchievementPopup.currentTimer then
            AchievementPopup.currentTimer:Cancel()
            AchievementPopup.currentTimer = nil
        end


        frame:Hide()


        C_Timer.After(0.1, function()
            AchievementPopup:ProcessQueue()
        end)
    end)
    frame.closeButton = closeButton

    frame:Hide()
    return frame
end

local popupFrame = CreateAchievementPopupFrame()


function AchievementPopup:QueuePopup(achievementData)
    if not achievementData then return end

    table.insert(self.queue, achievementData)


    if not self.isDisplaying then
        self:ProcessQueue()
    end
end


function AchievementPopup:ProcessQueue()
    if #self.queue == 0 then
        self.isDisplaying = false
        return
    end

    self.isDisplaying = true
    local nextAchievement = table.remove(self.queue, 1)
    self:DisplayPopup(nextAchievement)
end


function AchievementPopup:DisplayPopup(achievementData)

    if self.currentTimer then
        self.currentTimer:Cancel()
        self.currentTimer = nil
    end

    popupFrame.icon:SetTexture(achievementData.icon)
    popupFrame.achievementName:SetText(achievementData.title)
    popupFrame.description:SetText(achievementData.description)

    -- Add or hide border based on icon type
    if achievementData.icon and type(achievementData.icon) == "string" and achievementData.icon:match("Interface\\AddOns") then
        if not popupFrame.iconBorder then
            popupFrame.iconBorder = popupFrame.iconContainer:CreateTexture(nil, "OVERLAY")
            popupFrame.iconBorder:SetSize(61, 61)
            popupFrame.iconBorder:SetPoint("CENTER", popupFrame.icon, "CENTER")
            popupFrame.iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        end
        popupFrame.iconBorder:Show()
    else
        if popupFrame.iconBorder then
            popupFrame.iconBorder:Hide()
        end
    end

    if achievementData.id and string.match(achievementData.id, "^bonus") and (achievementData.achievementPoints or 0) == 0 then
        popupFrame:SetBackdropBorderColor(1.0, 0.1, 0.1)
    else
        local rarity = achievementData.rarity
        if rarity == "uncommon" then
            popupFrame:SetBackdropBorderColor(0.1, 1.0, 0.1) -- Green
        elseif rarity == "rare" then
            popupFrame:SetBackdropBorderColor(0.0, 0.4, 1.0) -- Blue
        elseif rarity == "epic" then
            popupFrame:SetBackdropBorderColor(0.8, 0.3, 0.9) -- Purple
        elseif rarity == "legendary" then
            popupFrame:SetBackdropBorderColor(1.0, 0.5, 0.0) -- Orange
        else
            popupFrame:SetBackdropBorderColor(0.7, 0.7, 0.7) -- Light gray for common
        end
    end


    if rarity == "legendary" then
        popupFrame.achievementName:SetTextColor(1.0, 0.5, 0.0) -- Orange for legendary
    elseif rarity == "epic" then
        popupFrame.achievementName:SetTextColor(0.8, 0.3, 0.9) -- Purple for epic
    elseif rarity == "rare" then
        popupFrame.achievementName:SetTextColor(0.0, 0.4, 1.0) -- Blue for rare
    elseif rarity == "uncommon" then
        popupFrame.achievementName:SetTextColor(0.1, 1.0, 0.1) -- Green for uncommon
    else
        popupFrame.achievementName:SetTextColor(1.0, 0.82, 0) -- Default gold color
    end

    popupFrame:Show()
    popupFrame:SetAlpha(1)

    -- Ensure popup stays on top using FrameManager
    if PSC_FrameManager then
        PSC_FrameManager:BringToFront("AchievementPopup")
    end


    local soundID = 8473  -- Achievement gained sound
    PlaySound(soundID)


    self.currentTimer = C_Timer.NewTimer(POPUP_DISPLAY_TIME, function()
        local fadeInfo = {
            mode = "OUT",
            timeToFade = POPUP_FADE_TIME,
            finishedFunc = function()
                popupFrame:Hide()
                self.currentTimer = nil

                C_Timer.After(0.1, function()
                    self:ProcessQueue()
                end)
            end,
        }
        UIFrameFade(popupFrame, fadeInfo)
    end)
end

function PVPSC.AchievementPopup:ShowPopup(achievementData)
    self:QueuePopup(achievementData)
end

function AchievementPopup:ShowMultipleAchievementsPopup(count)
    -- Cancel any queued popups
    self.queue = {}
    self.isDisplaying = false
    if self.currentTimer then
        self.currentTimer:Cancel()
        self.currentTimer = nil
    end

    popupFrame.icon:SetTexture(255349)
    popupFrame.achievementName:SetText("Multiple Achievements Unlocked!")
    popupFrame.description:SetText("You have unlocked " .. count .. " achievements at once.\nClick to view them all.")
    popupFrame.achievementName:SetTextColor(1.0, 0.82, 0) -- Gold
    popupFrame:SetBackdropBorderColor(1.0, 0.82, 0) -- Gold border
    popupFrame:Show()
    popupFrame:SetAlpha(1)

    -- Ensure popup stays on top using FrameManager
    if PSC_FrameManager then
        PSC_FrameManager:BringToFront("AchievementPopup")
    end

    PlaySound(8473)


    popupFrame:SetScript("OnMouseDown", function()
        popupFrame:Hide()
        PSC_ToggleAchievementFrame()
    end)

    self.currentTimer = C_Timer.NewTimer(POPUP_DISPLAY_TIME + 5, function()
        popupFrame:Hide()
        popupFrame:SetScript("OnMouseDown", nil)
        self.currentTimer = nil
    end)
end

function AchievementSystem:TestAchievementPopup()

    for i = 1, 3 do

        local rarities = {"common", "uncommon", "rare", "epic", "legendary"}

        local rarityIndex = (math.floor(GetTime()) % 5) + 1
        local currentRarity = rarities[((rarityIndex + i - 1) % 5) + 1]


        local testIcons = {
            132127, -- Ability_Hunter_SniperShot
            134400, -- INV_Sword_04
            133078, -- Spell_Shadow_SoulLeech_2
            136105, -- Spell_Holy_PowerInfusion
            135770, -- Spell_Frost_FrostBolt02
            236444  -- Achievement_Character_Dwarf_Male
        }
        local iconIndex = ((math.floor(GetTime()) + i) % #testIcons) + 1
        local iconID = testIcons[iconIndex]


        PVPSC.AchievementPopup:QueuePopup({
            icon = iconID,
            title = "Test Achievement " .. i .. " (" .. currentRarity .. ")",
            description = "This is test achievement #" .. i .. " with " .. currentRarity .. " rarity!",
            rarity = currentRarity
        })
    end
end


PVPSC.AchievementSystem = AchievementSystem