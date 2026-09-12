local addonName, PVPSC = ...

local AchievementFrame = CreateFrame("Frame", "PVPSCAchievementFrame", UIParent, "BasicFrameTemplateWithInset")
AchievementFrame:SetSize(1140, 603)
AchievementFrame:SetPoint("CENTER")
AchievementFrame:SetMovable(true)
AchievementFrame:EnableMouse(true)
AchievementFrame:RegisterForDrag("LeftButton")
AchievementFrame:SetScript("OnDragStart", AchievementFrame.StartMoving)
AchievementFrame:SetScript("OnDragStop", AchievementFrame.StopMovingOrSizing)
AchievementFrame:Hide()

-- Override close button to work in combat
if AchievementFrame.CloseButton then
    AchievementFrame.CloseButton:SetScript("OnClick", function()
        PSC_FrameManager:HideFrame("Achievements")
    end)
end

tinsert(UISpecialFrames, "PVPSCAchievementFrame")

AchievementFrame.TitleText = AchievementFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
AchievementFrame.TitleText:SetPoint("TOP", AchievementFrame, "TOP", 0, -5)
AchievementFrame.TitleText:SetText("PvP Achievements (this character)")

local contentFrame = CreateFrame("Frame", nil, AchievementFrame)
contentFrame:SetPoint("TOPLEFT", AchievementFrame, "TOPLEFT", 10, -30)
contentFrame:SetPoint("BOTTOMRIGHT", AchievementFrame, "BOTTOMRIGHT", -10, 15)

local scrollFrame = CreateFrame("ScrollFrame", "PVPSCAchievementScrollFrame", contentFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 0, 0)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 0)

local AlmostCompletedLabel = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
AlmostCompletedLabel:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 15)
AlmostCompletedLabel:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, 15)
AlmostCompletedLabel:SetJustifyH("CENTER")
AlmostCompletedLabel:SetText("Your 16 almost completed achievements")
AlmostCompletedLabel:Hide()

local LastCompletedLabel = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
LastCompletedLabel:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 15)
LastCompletedLabel:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, 15)
LastCompletedLabel:SetJustifyH("CENTER")
LastCompletedLabel:SetText("Shows you your last unlocked achievements sorted by unlock date")
LastCompletedLabel:Hide()

local scrollContent = CreateFrame("Frame", "PVPSCAchievementContent", scrollFrame)
scrollContent:SetSize(scrollFrame:GetWidth(), 1)
scrollFrame:SetScrollChild(scrollContent)


local ACHIEVEMENT_WIDTH = 260
local ACHIEVEMENT_HEIGHT = 80
local ACHIEVEMENT_SPACING_H = 15
local ACHIEVEMENT_SPACING_V = 15
local ACHIEVEMENTS_PER_ROW = 4


local currentCategory = "Class"


local function FilterAchievements(achievements, category)
    local filtered = {}

    local playerFaction = UnitFactionGroup("player")

    for _, achievement in ipairs(achievements) do
        local prefix = string.match(achievement.id, "^([^_]+)")

        if prefix == category:lower() or (category:lower() == "cities" and prefix == "city") then
            if prefix == "class" then
                if string.find(achievement.id, "class_mixed_") then
                    table.insert(filtered, achievement)
                elseif PSC_GameVersion == PSC_GAME_VERSIONS.CLASSIC then
                    -- In Classic, Paladins are Alliance-only, Shamans are Horde-only
                    if string.find(achievement.id, "_paladin_") and playerFaction == "Horde" then
                        table.insert(filtered, achievement)
                    elseif string.find(achievement.id, "_shaman_") and playerFaction == "Alliance" then
                        table.insert(filtered, achievement)
                    elseif not string.find(achievement.id, "_paladin_") and
                           not string.find(achievement.id, "_shaman_") then
                        table.insert(filtered, achievement)
                    end
                else
                    -- In TBC+, both factions have access to all classes
                    table.insert(filtered, achievement)
                end

            elseif prefix == "race" then
                if playerFaction == "Horde" then
                    if string.find(achievement.id, "_human_") or
                       string.find(achievement.id, "_nightelf_") or
                       string.find(achievement.id, "_dwarf_") or
                       string.find(achievement.id, "_gnome_") or
                       string.find(achievement.id, "_draenei_") or
                       string.find(achievement.id, "race_alliance_mixed") then
                        table.insert(filtered, achievement)
                    end
                elseif playerFaction == "Alliance" then
                    if string.find(achievement.id, "_orc_") or
                       string.find(achievement.id, "_undead_") or
                       string.find(achievement.id, "_troll_") or
                       string.find(achievement.id, "_tauren_") or
                       string.find(achievement.id, "_bloodelf_") or
                       string.find(achievement.id, "race_horde_mixed") then
                        table.insert(filtered, achievement)
                    end
                end

            elseif prefix == "gender" then
                table.insert(filtered, achievement)

            elseif prefix == "bg" then
                table.insert(filtered, achievement)

            elseif prefix == "arena" then
                table.insert(filtered, achievement)

            elseif prefix == "zone" then
                -- Show faction-specific zones and contested zones
                if string.find(achievement.id, string.lower(playerFaction)) or
                   -- Contested zones (no faction prefix)
                   string.find(achievement.id, "zone_ashenvale") or
                   string.find(achievement.id, "zone_hillsbrad") or
                   string.find(achievement.id, "zone_alterac") or
                   string.find(achievement.id, "zone_arathi") or
                   string.find(achievement.id, "zone_desolace") or
                   string.find(achievement.id, "zone_stranglethorn") or
                   string.find(achievement.id, "zone_hinterlands") or
                   string.find(achievement.id, "zone_tanaris") or
                   string.find(achievement.id, "zone_ungoro") or
                   string.find(achievement.id, "zone_felwood") or
                   string.find(achievement.id, "zone_thousand") or
                   string.find(achievement.id, "zone_dustwallow") or
                   string.find(achievement.id, "zone_azshara") or
                   string.find(achievement.id, "zone_redridge") or
                   string.find(achievement.id, "zone_duskwood") or
                   string.find(achievement.id, "zone_wetlands") or
                   string.find(achievement.id, "zone_badlands") or
                   string.find(achievement.id, "zone_feralas") or
                   string.find(achievement.id, "zone_searinggorge") or
                   string.find(achievement.id, "zone_burningsteppes") or
                   string.find(achievement.id, "zone_westernplaguelands") or
                   string.find(achievement.id, "zone_easternplaguelands") or
                   string.find(achievement.id, "zone_deadwindpass") or
                   string.find(achievement.id, "zone_winterspring") or
                   string.find(achievement.id, "zone_silithus") or
                   -- TBC zones (all contested)
                   string.find(achievement.id, "zone_hellfire") or
                   string.find(achievement.id, "zone_zangarmarsh") or
                   string.find(achievement.id, "zone_terokkar") or
                   string.find(achievement.id, "zone_nagrand") or
                   string.find(achievement.id, "zone_bladesedge") or
                   string.find(achievement.id, "zone_netherstorm") or
                   string.find(achievement.id, "zone_shadowmoon") or
                   string.find(achievement.id, "zone_eversong") or
                   string.find(achievement.id, "zone_ghostlands") or
                   string.find(achievement.id, "zone_azuremyst") or
                   string.find(achievement.id, "zone_bloodmyst") then
                    table.insert(filtered, achievement)
                end

            elseif prefix == "city" then
                if playerFaction == "Horde" and
                   (string.find(achievement.id, "city_stormwind") or
                    string.find(achievement.id, "city_ironforge") or
                    string.find(achievement.id, "city_darnassus") or
                    string.find(achievement.id, "city_exodar")) then
                    table.insert(filtered, achievement)
                elseif playerFaction == "Alliance" and
                       (string.find(achievement.id, "city_orgrimmar") or
                        string.find(achievement.id, "city_thunderbluff") or
                        string.find(achievement.id, "city_undercity") or
                        string.find(achievement.id, "city_silvermoon")) then
                    table.insert(filtered, achievement)
                end

            elseif prefix == "kills" then
                table.insert(filtered, achievement)

            elseif prefix == "npc" then
                if string.find(achievement.id, "_horde_") then
                    if playerFaction == "Horde" then
                        table.insert(filtered, achievement)
                    end
                elseif string.find(achievement.id, "_alliance_") then
                    if playerFaction == "Alliance" then
                        table.insert(filtered, achievement)
                    end
                else
                    table.insert(filtered, achievement)
                end

            elseif prefix == "time" then
                table.insert(filtered, achievement)

            elseif prefix == "seasonal" then
                table.insert(filtered, achievement)

            elseif prefix == "name" then
                table.insert(filtered, achievement)

            elseif prefix == "bonus" then
                if achievement.id == "bonus_horde" and playerFaction ~= "Horde" then
                    -- Skip Horde specific bonus for Alliance players
                else
                    table.insert(filtered, achievement)
                end

            elseif prefix == "streaks" then
                table.insert(filtered, achievement)
            end
        end
    end

    return filtered
end


local function ClearAchievementTiles()
    for _, child in pairs({scrollContent:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
end

-- Debug function to verify gray kill calculation
local function DiagnoseGrayKillCalculation(charData)
    local grayKillCount = 0
    local missingPlayerLevel = 0
    local totalKillLocations = 0

    print("=== Gray Kill Diagnosis ===")

    for nameWithLevel, killData in pairs(charData.Kills or {}) do
        local enemyLevel = tonumber(string.match(nameWithLevel, ":(%d+)")) or -1

        if enemyLevel >= 1 and killData.killLocations then
            for _, location in ipairs(killData.killLocations) do
                totalKillLocations = totalKillLocations + 1
                local playerLevel = location.playerLevel

                if playerLevel then
                    local grayThreshold = PSC_GrayLevelThreshods[playerLevel]
                    if grayThreshold and enemyLevel <= grayThreshold then
                        grayKillCount = grayKillCount + 1
                    end
                else
                    missingPlayerLevel = missingPlayerLevel + 1
                end
            end
        end
    end

    print("Total kill locations processed: " .. totalKillLocations)
    print("Gray kills found: " .. grayKillCount)
    print("Missing playerLevel in killLocations: " .. missingPlayerLevel)
    print("======================")

    return grayKillCount
end

local function CalculateGrayKillsForCharacter(charData)
    local grayKills = 0

    -- Iterate through kills once, checking each kill location
    for nameWithLevel, killData in pairs(charData.Kills or {}) do
        local enemyLevel = tonumber(string.match(nameWithLevel, ":(%d+)")) or -1

        if enemyLevel >= 1 and killData.killLocations then
            for _, location in ipairs(killData.killLocations) do
                local playerLevel = location.playerLevel

                if playerLevel then
                    local grayThreshold = PSC_GrayLevelThreshods[playerLevel]
                    if grayThreshold and enemyLevel <= grayThreshold then
                        grayKills = grayKills + 1
                    end
                end
            end
        end
    end

    return grayKills
end

function PSC_CalculateGrayKills()
    local currentCharacterKey = PSC_GetCharacterKey()
    local charData = PSC_DB.PlayerKillCounts.Characters[currentCharacterKey]

    -- Run diagnostics if debug is enabled
    -- if PSC_Debug then
    --     print("=== Gray Kill Calculation Debug ===")
    --     print("Current character: " .. currentCharacterKey)
    --     DiagnoseGrayKillCalculation(charData)
    -- end

    local grayKills = CalculateGrayKillsForCharacter(charData)

    -- if PSC_Debug then
    --     print("Final gray kills: " .. grayKills)
    -- end

    return grayKills
end


local function SetTileBorderColor(tile, rarity, achievement)
    if achievement and string.match(achievement.id, "^bonus") and (achievement.achievementPoints or 0) == 0 then
        tile:SetBackdropBorderColor(1.0, 0.1, 0.1)
        return
    end

    if rarity == "uncommon" then
        tile:SetBackdropBorderColor(0.1, 1.0, 0.1)
    elseif rarity == "rare" then
        tile:SetBackdropBorderColor(0.0, 0.4, 1.0)
    elseif rarity == "epic" then
        tile:SetBackdropBorderColor(0.8, 0.3, 0.9)
    elseif rarity == "legendary" then
        tile:SetBackdropBorderColor(1.0, 0.5, 0.0)
    else
        tile:SetBackdropBorderColor(0.7, 0.7, 0.7)
    end
end

local function GetRarityTooltipColor(rarity, achievement)
    -- Check if it's a bonus achievement with 0 points
    if achievement and (achievement.achievementPoints or 0) == 0 then
        return 1.0, 0.2, 0.2  -- Red for bonus achievements
    end

    if rarity == "uncommon" then
        return 0.1, 1.0, 0.1  -- Bright green
    elseif rarity == "rare" then
        return 0.2, 0.6, 1.0  -- Brighter blue for better readability
    elseif rarity == "epic" then
        return 0.8, 0.3, 0.9  -- Purple
    elseif rarity == "legendary" then
        return 1.0, 0.6, 0.0  -- Brighter orange/gold for legendary
    else
        return 1.0, 1.0, 1.0  -- White for common
    end
end


local function CreateAchievementIcon(tile, achievement)
    local iconContainer = CreateFrame("Frame", nil, tile)
    iconContainer:SetSize(40, 40)
    iconContainer:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -10)

    local background = iconContainer:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("CENTER", iconContainer, "CENTER", 0, 0)
    background:SetSize(36, 36)
    background:SetTexture("Interface\\Buttons\\UI-EmptySlot")
    background:SetVertexColor(0.3, 0.3, 0.3, 0.8)

    local icon = iconContainer:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("CENTER", iconContainer, "CENTER", 0, 0)
    icon:SetTexture(achievement.iconID or "Interface\\Icons\\INV_Misc_QuestionMark")
    if not achievement.unlocked then
        icon:SetDesaturated(true)
    end

    -- Add icon border overlay for all achievement icons
    local iconBorder = iconContainer:CreateTexture(nil, "OVERLAY")
    iconBorder:SetSize(60, 61)
    iconBorder:SetPoint("CENTER", icon, "CENTER")
    iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")

    return icon
end


local function CreatePointsImage(tile, pointsValue)
    local function GetPointsImagePath(points)
        local basePath = "Interface\\AddOns\\PvPStatsClassic\\achievement_img\\Achievement_icon"
        if points == 10 then
            return basePath .. "10"
        elseif points == 25 then
            return basePath .. "25"
        elseif points == 50 then
            return basePath .. "50"
        elseif points == 75 then
            return basePath .. "75"
        elseif points == 100 then
            return basePath .. "100"
        elseif points == 125 then
            return basePath .. "125"
        elseif points == 250 then
            return basePath .. "250"
        elseif points == 500 then
            return basePath .. "500"
        else
            return basePath
        end
    end

    local pointsImage = tile:CreateTexture(nil, "ARTWORK")
    pointsImage:SetSize(38, 32)
    pointsImage:SetPoint("RIGHT", tile, "RIGHT", -15, 5)
    local imagePath = GetPointsImagePath(pointsValue)

    if imagePath then
        pointsImage:SetTexture(imagePath)
    else
        pointsImage:Hide()
    end

    return pointsImage
end


local function CreateTitleAndDescription(tile, icon, pointsImage, achievement)
    local title = tile:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
    title:SetPoint("RIGHT", pointsImage, "LEFT", -10, 0)

    local titleText = type(achievement.title) == "function" and achievement.title(achievement) or achievement.title
    title:SetText(PSC_ReplacePlayerNamePlaceholder(titleText, nil, achievement))
    if achievement.unlocked then
        title:SetTextColor(1, 0.82, 0)
    else
        title:SetTextColor(0.5, 0.5, 0.5)
    end

    local desc = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    desc:SetPoint("RIGHT", pointsImage, "LEFT", -10, 0)
    desc:SetJustifyH("LEFT")

    local descText = type(achievement.description) == "function" and achievement.description(achievement) or achievement.description
    desc:SetText(descText)
    if achievement.unlocked then
        desc:SetTextColor(0.9, 0.9, 0.9)
    else
        desc:SetTextColor(0.4, 0.4, 0.4)
    end

    return title, desc
end


local function CreateProgressBar(tile, targetValue, currentProgress, achievement, icon, title)
    local progressBar = CreateFrame("StatusBar", nil, tile, BackdropTemplateMixin and "BackdropTemplate")
    progressBar:SetSize(ACHIEVEMENT_WIDTH - 60, 10)
    progressBar:SetPoint("TOPLEFT", tile, "TOPLEFT", (ACHIEVEMENT_WIDTH - (ACHIEVEMENT_WIDTH - 60)) / 2, -65)
    progressBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    progressBar:SetStatusBarColor(0.0, 0.65, 0.0)

    local progressText = progressBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    progressText:SetPoint("CENTER", progressBar, "CENTER", 0, 0)

    if achievement.unlocked then
        local displayProgress = PSC_DB.CapAchievementProgress and targetValue or currentProgress
        progressBar:SetMinMaxValues(0, math.max(targetValue, currentProgress))
        progressBar:SetValue(currentProgress)
        progressText:SetText(displayProgress.."/"..targetValue)
    else
        progressBar:SetMinMaxValues(0, targetValue)
        progressBar:SetValue(currentProgress)
        if currentCategory == "Almost" and achievement.completion then
            progressText:SetText(string.format("%d/%d (%d%%)", currentProgress, targetValue, achievement.completion))
        else
            progressText:SetText(currentProgress.."/"..targetValue)
        end
    end

    return progressBar, progressText
end


local function AddLockedOverlay(tile, achievement)
    if not achievement.unlocked then
        local overlay = tile:CreateTexture(nil, "OVERLAY")
        overlay:SetAllPoints()
        overlay:SetColorTexture(0, 0, 0, 0.5)
    end
end


local function CreateAchievementTile(i, achievement, savedAchievements)
    local column = (i - 1) % ACHIEVEMENTS_PER_ROW
    local row = math.floor((i - 1) / ACHIEVEMENTS_PER_ROW)
    local xPos = column * (ACHIEVEMENT_WIDTH + ACHIEVEMENT_SPACING_H)
    local yPos = -row * (ACHIEVEMENT_HEIGHT + ACHIEVEMENT_SPACING_V)

    local tile = CreateFrame("Button", nil, scrollContent, BackdropTemplateMixin and "BackdropTemplate")
    tile:SetSize(ACHIEVEMENT_WIDTH, ACHIEVEMENT_HEIGHT + 5)
    tile:SetPoint("TOPLEFT", xPos, yPos)
    tile:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tile:SetBackdrop({
        bgFile = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        tileSize = 22,
        edgeSize = 22,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })

    SetTileBorderColor(tile, achievement.rarity or "common", achievement)
    AddLockedOverlay(tile, achievement)

    local icon = CreateAchievementIcon(tile, achievement)
    local pointsValue = achievement.achievementPoints or 10
    local pointsImage = CreatePointsImage(tile, pointsValue)
    local title, desc = CreateTitleAndDescription(tile, icon, pointsImage, achievement)

    local targetValue = achievement.targetValue
    local savedData = savedAchievements and savedAchievements[achievement.id]
    local currentProgress = (savedData and savedData.progress) or 0
    CreateProgressBar(tile, targetValue, currentProgress, achievement, icon, title)

    tile:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()

        local titleText = type(achievement.title) == "function" and achievement.title(achievement) or achievement.title
        local rarity = achievement.rarity or "common"
        local r, g, b = GetRarityTooltipColor(rarity, achievement)
        GameTooltip:AddLine(PSC_ReplacePlayerNamePlaceholder(titleText, nil, achievement), r, g, b) -- Rarity-colored title

        local descText = type(achievement.description) == "function" and achievement.description(achievement) or achievement.description
        GameTooltip:AddLine(descText, 1, 1, 1, true)

        GameTooltip:AddLine(" ")

        local subTextValue = achievement.subText
        local personalizedSubText = PSC_ReplacePlayerNamePlaceholder(subTextValue, nil, achievement)
        GameTooltip:AddLine(personalizedSubText, 0.7, 0.7, 0.7, true) -- Grey subtext, wrap text

        if achievement.unlocked then
            GameTooltip:AddLine(" ") -- Spacer
            GameTooltip:AddLine("Completed: " .. achievement.completedDate, 0.6, 0.8, 1.0) -- Light blue date
            GameTooltip:AddLine("Ctrl+Click to share in chat", 0.5, 0.5, 0.5) -- Grey instruction text
            GameTooltip:AddLine("Right-Click to show achievement popup", 0.5, 0.5, 0.5) -- Grey instruction text
        end

        GameTooltip:Show()
    end)

    tile:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    tile:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and IsControlKeyDown() and achievement.unlocked then
            PSC_ShareAchievementInChat(achievement)
        elseif button == "RightButton" and achievement.unlocked then
            -- Trigger achievement popup
            local achievementData = {
                icon = achievement.iconID or "Interface\\Icons\\INV_Misc_QuestionMark",
                title = type(achievement.title) == "function" and achievement.title(achievement) or achievement.title,
                description = type(achievement.description) == "function" and achievement.description(achievement) or achievement.description,
                rarity = achievement.rarity or "common",
                id = achievement.id,
                achievementPoints = achievement.achievementPoints
            }
            PVPSC.AchievementPopup:ShowPopup(achievementData)
        end
    end)
end


local function ParseDateString(dateStr)
    if not dateStr then return 0 end
    local day, month, year, hour, minute = dateStr:match("(%d+)/(%d+)/(%d+) (%d+):(%d+)")
    if not day then return 0 end
    return tonumber(year) * 100000000 + tonumber(month) * 1000000 + tonumber(day) * 10000 + tonumber(hour) * 100 + tonumber(minute)
end

local function UpdateAchievementLayout()
    ClearAchievementTiles()

    if currentCategory == "Almost" then
        AlmostCompletedLabel:Show()
        LastCompletedLabel:Hide()
        scrollFrame:SetPoint("TOPLEFT", 0, -20)
    elseif currentCategory == "Latest" then
        AlmostCompletedLabel:Hide()
        LastCompletedLabel:Show()
        scrollFrame:SetPoint("TOPLEFT", 0, -20)
    else
        AlmostCompletedLabel:Hide()
        LastCompletedLabel:Hide()
        scrollFrame:SetPoint("TOPLEFT", 0, 0)
    end

    local achievements
    local characterKey = PSC_GetCharacterKey()
    local savedAchievements = PSC_DB.CharacterAchievements and PSC_DB.CharacterAchievements[characterKey] or {}

    if currentCategory == "Almost" then
        achievements = {}
        local allAchievements = PVPSC.AchievementSystem.achievements
        for _, achievement in ipairs(allAchievements) do
            if not achievement.unlocked then
                local savedData = savedAchievements and savedAchievements[achievement.id]
                local progressValue = savedData and savedData.progress
                local targetValue = achievement.targetValue
                if progressValue and targetValue and targetValue > 0 then
                    local completion = (progressValue / targetValue) * 100
                    completion = math.floor(completion)
                    if completion > 0 then
                        local achievementCopy = {}
                        for k, v in pairs(achievement) do achievementCopy[k] = v end
                        achievementCopy.completion = completion
                        table.insert(achievements, achievementCopy)
                    end
                end
            end
        end

        table.sort(achievements, function(a, b)
            return a.completion > b.completion
        end)

        while #achievements > 16 do
            table.remove(achievements)
        end
    elseif currentCategory == "Latest" then
        achievements = {}
        local allAchievements = PVPSC.AchievementSystem.achievements
        for _, achievement in ipairs(allAchievements) do
            if achievement.unlocked then
                table.insert(achievements, achievement)
            end
        end

        table.sort(achievements, function(a, b)
            local timeA = ParseDateString(a.completedDate)
            local timeB = ParseDateString(b.completedDate)
            return timeA > timeB
        end)
    else
        achievements = FilterAchievements(PVPSC.AchievementSystem.achievements, currentCategory)
    end

    if #achievements == 0 then return end

    for i, achievement in ipairs(achievements) do
        CreateAchievementTile(i, achievement, savedAchievements)
    end
end

local function CreateAchievementTabSystem(parent)
    local tabNames = {"Class", "Race", "Kills", "NPC", "Time", "Seasonal", "Name", "Gender", "BG", "Arena", "Zone", "Cities", "Streaks", "Bonus", "Almost", "Latest"}
    local tabs = {}
    local tabWidth, tabHeight = 78, 32

    local tabContainer = CreateFrame("Frame", nil, parent)
    tabContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 7, -25)
    tabContainer:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -7, 7)

    for i, name in ipairs(tabNames) do
        local tab = CreateFrame("Button", parent:GetName() .. "Tab" .. i, parent, "CharacterFrameTabButtonTemplate")
        tab:SetText(name)
        tab:SetID(i)
        tab:SetSize(tabWidth, tabHeight)

        local tabMiddle = _G[tab:GetName() .. "Middle"]
        local tabLeft = _G[tab:GetName() .. "Left"]
        local tabRight = _G[tab:GetName() .. "Right"]
        local tabSelectedMiddle = _G[tab:GetName() .. "SelectedMiddle"]
        local tabSelectedLeft = _G[tab:GetName() .. "SelectedLeft"]
        local tabSelectedRight = _G[tab:GetName() .. "SelectedRight"]
        local tabText = _G[tab:GetName() .. "Text"]

        if tabMiddle then
            tabMiddle:ClearAllPoints()
            tabMiddle:SetPoint("LEFT", tabLeft, "RIGHT", 0, 0)
            tabMiddle:SetWidth(tabWidth - 31)
        end
        if tabSelectedMiddle then
            tabSelectedMiddle:ClearAllPoints()
            tabSelectedMiddle:SetPoint("LEFT", tabSelectedLeft, "RIGHT", 0, 0)
            tabSelectedMiddle:SetWidth(tabWidth - 31)
        end

        if i == 1 then
            tab:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 5, 0)
        else
            tab:SetPoint("LEFT", tabs[i-1], "RIGHT", -8, 0)
        end

        if tabText then
            tabText:ClearAllPoints()
            tabText:SetPoint("CENTER", tab, "CENTER", 0, 2)
            tabText:SetJustifyH("CENTER")
            tabText:SetWidth(tabWidth - 40)
        end

        tab:SetScript("OnClick", function()
            currentCategory = name
            UpdateAchievementLayout()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            PanelTemplates_SetTab(parent, i)
        end)

        tabs[i] = tab
    end

    parent.tabs = tabs
    parent.numTabs = #tabs

    PanelTemplates_SetNumTabs(parent, #tabs)
    PanelTemplates_SetTab(parent, 1)

    return tabs
end

CreateAchievementTabSystem(AchievementFrame)

local function LoadAchievementCompletionStatus()
    local characterKey = PSC_GetCharacterKey()

    if not PSC_DB.CharacterAchievements or not PSC_DB.CharacterAchievements[characterKey] then
        return
    end

    local achievements = PVPSC.AchievementSystem and PVPSC.AchievementSystem.achievements or {}

    for _, achievement in ipairs(achievements) do
        achievement.unlocked = false
        achievement.completedDate = nil

        local savedData = PSC_DB.CharacterAchievements[characterKey][achievement.id]
        if savedData and savedData.unlocked then
            achievement.unlocked = true
            achievement.completedDate = savedData.completedDate
        end
    end
end

function PSC_ToggleAchievementFrame()
    if AchievementFrame:IsShown() then
        PSC_FrameManager:HideFrame("Achievements")
    else
        LoadAchievementCompletionStatus()
        UpdateAchievementLayout()

        -- Register the frame if it's not already registered
        if not PSC_FrameManager.frames["Achievements"] then
            PSC_FrameManager:RegisterFrame(AchievementFrame, "Achievements")
        end
        PSC_FrameManager:ShowFrame("Achievements")
    end
end
