local addonName, PVPSC = ...

PVPSC.AchievementSystem = PVPSC.AchievementSystem or {}
local AchievementSystem = PVPSC.AchievementSystem

-- Helper function to get zone kills across all language variants
-- This needs to be defined early since achievement definitions use it
function PSC_GetZoneKills(stats, zoneTranslations, zoneNameEnglish)
    if not stats.zoneData then return 0 end

    local translations = zoneTranslations[zoneNameEnglish]
    if not translations then
        return stats.zoneData[zoneNameEnglish] or 0
    end

    for _, zoneName in ipairs(translations) do
        local kills = stats.zoneData[zoneName]
        if kills and kills > 0 then
            return kills
        end
    end

    return 0
end

function PSC_GetProgressForAchievementWithAllClasses(stats, gameVersionForCheck)
    -- Available for both factions
    local warrior = stats.classData["Warrior"] or 0
    local hunter = stats.classData["Hunter"] or 0
    local rogue = stats.classData["Rogue"] or 0
    local priest = stats.classData["Priest"] or 0
    local mage = stats.classData["Mage"] or 0
    local warlock = stats.classData["Warlock"] or 0
    local druid = stats.classData["Druid"] or 0
    -- Faction specific in Classic
    local paladin = stats.classData["Paladin"] or 0
    local shaman = stats.classData["Shaman"] or 0

    local playerFaction = UnitFactionGroup("player")
    if gameVersionForCheck == PSC_GAME_VERSIONS.CLASSIC then
        if playerFaction == "Horde" then
            return math.min(warrior, paladin, hunter, rogue, priest, mage, warlock, druid)
        else
            return math.min(warrior, shaman, hunter, rogue, priest, mage, warlock, druid)
        end
    else
        return math.min(warrior, paladin, shaman, hunter, rogue, priest, mage, warlock, druid)
    end
end

-- Helper function to get progress for Alliance race achievements (all 4 Classic races)
function PSC_GetProgressForAllianceRacesClassic(stats)
    local humans = stats.raceData["Human"] or 0
    local gnomes = stats.raceData["Gnome"] or 0
    local dwarves = stats.raceData["Dwarf"] or 0
    local nightElves = stats.raceData["Night Elf"] or 0
    return math.min(humans, gnomes, dwarves, nightElves)
end

-- Helper function to get progress for Horde race achievements (all 4 Classic races)
function PSC_GetProgressForHordeRacesClassic(stats)
    local orcs = stats.raceData["Orc"] or 0
    local undead = stats.raceData["Undead"] or 0
    local trolls = stats.raceData["Troll"] or 0
    local tauren = stats.raceData["Tauren"] or 0
    return math.min(orcs, undead, trolls, tauren)
end

-- Helper function to get progress for Alliance race achievements (all 5 TBC races)
function PSC_GetProgressForAllianceRacesTBC(stats)
    local humans = stats.raceData["Human"] or 0
    local gnomes = stats.raceData["Gnome"] or 0
    local dwarves = stats.raceData["Dwarf"] or 0
    local nightElves = stats.raceData["Night Elf"] or 0
    local draenei = stats.raceData["Draenei"] or 0
    return math.min(humans, gnomes, dwarves, nightElves, draenei)
end

-- Helper function to get progress for Horde race achievements (all 5 TBC races)
function PSC_GetProgressForHordeRacesTBC(stats)
    local orcs = stats.raceData["Orc"] or 0
    local undead = stats.raceData["Undead"] or 0
    local trolls = stats.raceData["Troll"] or 0
    local tauren = stats.raceData["Tauren"] or 0
    local bloodElves = stats.raceData["Blood Elf"] or 0
    return math.min(orcs, undead, trolls, tauren, bloodElves)
end

-- Helper function to check if specific achievements are unlocked
function PSC_IsAchievementUnlocked(achievementId)
    local characterKey = PSC_GetCharacterKey()

    if not PSC_DB or not PSC_DB.CharacterAchievements then
        return false
    end

    if not PSC_DB.CharacterAchievements[characterKey] then
        return false
    end

    local achievementData = PSC_DB.CharacterAchievements[characterKey][achievementId]
    return achievementData and achievementData.unlocked or false
end

PSC_GrayLevelThreshods = {
    [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0,
    [7] = 1, [8] = 2, [9] = 3, [10] = 4, [11] = 5, [12] = 6,
    [13] = 7, [14] = 8, [15] = 9, [16] = 10, [17] = 11, [18] = 12,
    [19] = 13, [20] = 13, [21] = 14, [22] = 15, [23] = 16, [24] = 17,
    [25] = 18, [26] = 19, [27] = 20, [28] = 21, [29] = 22, [30] = 22,
    [31] = 23, [32] = 24, [33] = 25, [34] = 26, [35] = 27, [36] = 28,
    [37] = 29, [38] = 30, [39] = 31, [40] = 31, [41] = 32, [42] = 33,
    [43] = 34, [44] = 35, [45] = 35, [46] = 36, [47] = 37, [48] = 38,
    [49] = 39, [50] = 39, [51] = 40, [52] = 41, [53] = 42, [54] = 43,
    [55] = 43, [56] = 44, [57] = 45, [58] = 46, [59] = 47
}
if PSC_GameVersion == PSC_GAME_VERSIONS.CLASSIC then
    PSC_GrayLevelThreshods[60] = 47
elseif PSC_GameVersion == PSC_GAME_VERSIONS.TBC then
    PSC_GrayLevelThreshods[60] = 51
    PSC_GrayLevelThreshods[61] = 52
    PSC_GrayLevelThreshods[62] = 53
    PSC_GrayLevelThreshods[63] = 54
    PSC_GrayLevelThreshods[64] = 55
    PSC_GrayLevelThreshods[65] = 56
    PSC_GrayLevelThreshods[66] = 57
    PSC_GrayLevelThreshods[67] = 58
    PSC_GrayLevelThreshods[68] = 59
    PSC_GrayLevelThreshods[69] = 60
    PSC_GrayLevelThreshods[70] = 61
end

function PSC_InitializeGrayKillsCounter()
    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]

    -- Calculate once using the existing function
    characterData.GrayKillsCount = PSC_CalculateGrayKills() or 0

    if PSC_Debug then
        print("[PvPStats]: Initialized gray kills counter with " .. characterData.GrayKillsCount .. " kills")
    end
end

function PSC_InitializeSpawnCamperCounter()
    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]

    -- Calculate once using the spawn camper logic
    characterData.SpawnCamperMaxKills = PSC_CalculateSpawnCamperMaxKills() or 0

    if PSC_Debug then
        print("[PvPStats]: Initialized spawn camper counter with " .. characterData.SpawnCamperMaxKills .. " max kills in 60s window")
    end
end

function PSC_CalculateSpawnCamperMaxKills()
    local characterKey = PSC_GetCharacterKey()
    if not characterKey or not PSC_DB.PlayerKillCounts.Characters[characterKey] then return 0 end

    local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]

    -- Only build the timestamp list if it hasn't been initialized yet (first-time setup)
    if not characterData.Level1KillTimestamps or #characterData.Level1KillTimestamps == 0 then
        local timestamps = {}

        -- One-time historical data collection
        for nameWithLevel, data in pairs(characterData.Kills) do
            if string.match(nameWithLevel, ":1$") then
                for _, loc in ipairs(data.killLocations) do
                    table.insert(timestamps, loc.timestamp)
                end
            end
        end

        if #timestamps == 0 then
            characterData.Level1KillTimestamps = {}
            return 0
        end

        table.sort(timestamps)
        characterData.Level1KillTimestamps = timestamps
    end

    -- Calculate max from the cached list
    local timestamps = characterData.Level1KillTimestamps
    local maxKillsInWindow = 0
    local left = 1

    for right = 1, #timestamps do
        while timestamps[right] - timestamps[left] > 60 do
            left = left + 1
        end
        local count = right - left + 1
        if count > maxKillsInWindow then
            maxKillsInWindow = count
        end
    end

    return maxKillsInWindow
end

-- Helper function to check if a kill is a gray level kill
function PSC_IsGrayLevelKill(playerLevel, targetLevel)
    if not playerLevel or not targetLevel or targetLevel == -1 then
        return false
    end

    -- Get the threshold from our table
    local threshold = PSC_GrayLevelThreshods[playerLevel] or 0

    -- If player's level minus threshold is higher than target's level, it's a gray kill
    local isGrayKill = targetLevel <= threshold
    return isGrayKill
end

function PSC_ReplacePlayerNamePlaceholder(text, playerName, achievement)
    if not text then return "" end

    if type(text) == "function" then
        text = text(achievement)
    end

    local name = playerName or UnitName("player")
    text = text:gsub("%[YOUR NAME%]", name)
    return text
end

-- Helper function to calculate guild achievement stats
function PSC_CalculateGuildStats(guildData)
    local maxSameGuildKills = 0
    local uniqueGuildsKilled = 0

    if guildData then
        for guildName, count in pairs(guildData) do
            if count > maxSameGuildKills then
                maxSameGuildKills = count
            end
            uniqueGuildsKilled = uniqueGuildsKilled + 1
        end
    end

    return maxSameGuildKills, uniqueGuildsKilled
end


function PSC_GetStatsForAchievements()
    local charactersToProcess = {}
    local currentCharacterKey = PSC_GetCharacterKey()
    charactersToProcess[currentCharacterKey] = PSC_DB.PlayerKillCounts.Characters[currentCharacterKey]
    local classData, raceData, genderData, unknownLevelClassData, zoneData, levelData, guildStatusData, guildData, npcKillsData, hourlyData, redridgeLevel15To25Kills, redridgeLevel60To70Kills = PSC_CalculateBarChartStatistics(charactersToProcess)
    local summaryStats = PSC_CalculateSummaryStatistics(charactersToProcess)

    -- Calculate guild achievement stats
    local maxSameGuildKills, uniqueGuildsKilled = PSC_CalculateGuildStats(guildData)

    local stats = {
        classData = classData,
        raceData = raceData,
        genderData = genderData,
        unknownLevelClassData = unknownLevelClassData,
        zoneData = zoneData,
        levelData = levelData,
        guildStatusData = guildStatusData,
        guildData = guildData,
        maxSameGuildKills = maxSameGuildKills,
        uniqueGuildsKilled = uniqueGuildsKilled,
        hourlyData = hourlyData,
        redridgeLevel15To25Kills = redridgeLevel15To25Kills,
        redridgeLevel60To70Kills = redridgeLevel60To70Kills,
        totalKills = summaryStats.totalKills,
        uniqueKills = summaryStats.uniqueKills,
        highestKillStreak = summaryStats.highestKillStreak,
        highestMultiKill = summaryStats.highestMultiKill,
        mostKilledPlayer = summaryStats.mostKilledPlayer,
        mostKilledCount = summaryStats.mostKilledCount,
        npcKills = charactersToProcess[currentCharacterKey].NPCKills or {},
        totalAchievementPoints = PSC_GetCurrentAchievementPoints(),
        unlockedAchievements = PSC_GetUnlockedAchievementCount()
    }

    return stats
end

local function PSC_ShowUnlockedAchievements(achievementsUnlocked, unlockedList)
    if achievementsUnlocked <= 0 then
        return
    end

    if achievementsUnlocked > 3 then
        print("|cffffffff[PvPStats]|r You have unlocked |cffffff00" .. achievementsUnlocked .. "|r new achievements:")
        for _, achievement in ipairs(unlockedList) do
            print("|cffffff00" .. achievement.title .. "|r: |cffffffff" .. achievement.description .. "|r")
        end

        PVPSC.AchievementPopup:ShowMultipleAchievementsPopup(achievementsUnlocked)
    else
        for _, popupData in ipairs(unlockedList) do
            PVPSC.AchievementPopup:ShowPopup(popupData)
        end
    end
end

local function PSC_ProcessSingleAchievement(achievement, stats, playerName, unlockedList)
    if achievement.unlocked then
        return false
    end

    if not achievement.condition(achievement, stats) then
        return false
    end

    achievement.unlocked = true
    achievement.completedDate = date("%d/%m/%Y %H:%M")

    PSC_SaveAchievement(achievement.id, achievement.completedDate, achievement.achievementPoints)

    local personalizedDescription = PSC_ReplacePlayerNamePlaceholder(achievement.description, playerName, achievement)
    local personalizedTitle = PSC_ReplacePlayerNamePlaceholder(achievement.title, playerName, achievement)
    local personalizedSubText = PSC_ReplacePlayerNamePlaceholder(achievement.subText, playerName, achievement)

    table.insert(unlockedList, {
        icon = achievement.iconID,
        title = personalizedTitle,
        description = personalizedDescription,
        subText = personalizedSubText,
        rarity = achievement.rarity
    })

    return true
end

local function PSC_SaveAchievementProgressValue(achievementID, progressValue)
    if not achievementID then
        return
    end

    if not PSC_DB or not PSC_DB.CharacterAchievements then
        if PSC_InitializeAchievementDataStructure then
            PSC_InitializeAchievementDataStructure()
        end
    end

    local characterKey = PSC_GetCharacterKey()
    PSC_DB.CharacterAchievements = PSC_DB.CharacterAchievements or {}
    PSC_DB.CharacterAchievements[characterKey] = PSC_DB.CharacterAchievements[characterKey] or {}
    PSC_DB.CharacterAchievements[characterKey][achievementID] = PSC_DB.CharacterAchievements[characterKey][achievementID] or {}

    PSC_DB.CharacterAchievements[characterKey][achievementID].progress = progressValue
end

function AchievementSystem:CreateIncrementalAchievementCheckTask(stats)
    local achievements = self.achievements or {}
    local playerName = UnitName("player")
    local unlockedList = {}
    local achievementsUnlocked = 0
    local startIndex = 1

    local achievementsPerSlice = 500

    return function()
        local i = startIndex
        local processed = 0

        while i <= #achievements do
            local achievement = achievements[i]
            if achievement and type(achievement.progress) == "function" then
                local ok, value = pcall(achievement.progress, achievement, stats)
                if ok then
                    PSC_SaveAchievementProgressValue(achievement.id, value)
                end
            end
            if achievement and PSC_ProcessSingleAchievement(achievement, stats, playerName, unlockedList) then
                achievementsUnlocked = achievementsUnlocked + 1
            end

            i = i + 1
            processed = processed + 1

            if processed >= achievementsPerSlice then
                break
            end
        end

        startIndex = i

        if startIndex <= #achievements then
            return false
        end

        self:SaveAchievementPoints()
        PSC_ShowUnlockedAchievements(achievementsUnlocked, unlockedList)
        return true
    end
end

local function GetRarityFromPoints(points)
    if points >= 250 then
        return "legendary"
    elseif points >= 100 then
        return "epic"
    elseif points >= 50 then
        return "rare"
    elseif points >= 25 then
        return "uncommon"
    else
        return "common"
    end
end

-- Helper function to assign rarity to achievements
function AchievementSystem:AssignRarityToAchievements()
    if not self.achievements then return end

    for _, achievement in ipairs(self.achievements) do
        if not achievement.rarity then
            achievement.rarity = GetRarityFromPoints(achievement.achievementPoints)
        end
    end
end

function AchievementSystem:SaveAchievementPoints()
    local characterKey = PSC_GetCharacterKey()
    local totalPoints = 0

    if not PSC_DB.CharacterAchievements then
        PSC_InitializeAchievementDataStructure()
    end

    if not PSC_DB.CharacterAchievements[characterKey] then
        PSC_DB.CharacterAchievements[characterKey] = {}
    end

    for _, achievement in ipairs(self.achievements) do
        local achievementID = achievement.id

        if PSC_DB.CharacterAchievements[characterKey][achievementID] and
           PSC_DB.CharacterAchievements[characterKey][achievementID].unlocked then
            totalPoints = totalPoints + achievement.achievementPoints
            PSC_DB.CharacterAchievements[characterKey][achievementID].points = achievement.achievementPoints
        end
    end

    PSC_DB.CharacterAchievementPoints[characterKey] = totalPoints

    return totalPoints
end

function AchievementSystem:GetTotalPossiblePoints()
    local totalPossiblePoints = 0

    for _, achievement in ipairs(self.achievements) do
        if achievement.achievementPoints then
            totalPossiblePoints = totalPossiblePoints + achievement.achievementPoints
        end
    end

    return totalPossiblePoints
end

function AchievementSystem:LoadAchievementCompletedData()
    local characterKey = PSC_GetCharacterKey()

    self:CleanupObsoleteAchievements()

    if PSC_DB.CharacterAchievements and PSC_DB.CharacterAchievements[characterKey] then
        for achievementID, achievementData in pairs(PSC_DB.CharacterAchievements[characterKey]) do
            for i, achievement in ipairs(self.achievements) do
                if achievement.id == achievementID and achievementData.unlocked then
                    self.achievements[i].unlocked = true
                    self.achievements[i].completedDate = achievementData.completedDate
                end
            end
        end
    end

    self:SaveAchievementPoints()
end

function PSC_ShareAchievementInChat(achievement)
    if not achievement or not achievement.unlocked then
        return
    end

    local titleText = type(achievement.title) == "function" and achievement.title(achievement) or achievement.title
    local personalizedTitle = PSC_ReplacePlayerNamePlaceholder(titleText, UnitName("player"), achievement)

    local descText = type(achievement.description) == "function" and achievement.description(achievement) or achievement.description
    local personalizedDesc = PSC_ReplacePlayerNamePlaceholder(descText, UnitName("player"), achievement)

    local shareText = personalizedTitle .. " (" .. personalizedDesc .. ") Completed: " .. achievement.completedDate

    if ChatFrame1EditBox:IsShown() then
        ChatFrame1EditBox:SetText(shareText)
        ChatFrame1EditBox:SetCursorPosition(string.len(shareText))
    else
        ChatFrame1EditBox:Show()
        ChatFrame1EditBox:SetText(shareText)
        ChatFrame1EditBox:SetCursorPosition(string.len(shareText))
        ChatFrame1EditBox:SetFocus()
    end
end

-- Generic function to clean up unlocked achievements that no longer exist in current definitions
function AchievementSystem:CleanupObsoleteAchievements()
    local characterKey = PSC_GetCharacterKey()

    -- Check both possible data structures for achievement storage
    local removedCount = 0

    -- Clean up PSC_DB.CharacterAchievements (the main one being used)
    if PSC_DB.CharacterAchievements and PSC_DB.CharacterAchievements[characterKey] then
        -- Create a lookup table of all current achievement IDs for fast checking
        local currentAchievementIDs = {}
        for _, achievement in ipairs(self.achievements) do
            currentAchievementIDs[achievement.id] = true
        end

        local characterAchievements = PSC_DB.CharacterAchievements[characterKey]

        for achievementId, _ in pairs(characterAchievements) do
            if not currentAchievementIDs[achievementId] then
                -- This achievement ID no longer exists in current definitions
                characterAchievements[achievementId] = nil
                removedCount = removedCount + 1
                if PSC_Debug then
                    PSC_Print("Removed obsolete achievement from CharacterAchievements: " .. achievementId)
                end
            end
        end
    end

    -- Also clean up PSC_DB.PlayerAchievements if it exists (legacy/alternative storage)
    if PSC_DB.PlayerAchievements and PSC_DB.PlayerAchievements[characterKey] then
        -- Create a lookup table of all current achievement IDs for fast checking
        local currentAchievementIDs = {}
        for _, achievement in ipairs(self.achievements) do
            currentAchievementIDs[achievement.id] = true
        end

        local playerAchievements = PSC_DB.PlayerAchievements[characterKey]

        for achievementId, _ in pairs(playerAchievements) do
            if not currentAchievementIDs[achievementId] then
                -- This achievement ID no longer exists in current definitions
                playerAchievements[achievementId] = nil
                removedCount = removedCount + 1
                PSC_Print("Removed obsolete achievement: " .. achievementId)
            end
        end
    end

    if removedCount > 0 then
        PSC_Print("Cleaned up " .. removedCount .. " obsolete achievement(s) from your progress.")

        -- Recalculate achievement points after cleanup
        self:SaveAchievementPoints()
    end

    return removedCount
end
