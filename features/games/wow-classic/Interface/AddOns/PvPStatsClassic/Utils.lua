local addonName, PVPSC = ...

local TimeStatsCache = nil
local streakStatsCache = nil
local nameStatsCache = nil

local SPECIAL_CHARS = {"ä", "ö", "ü", "ø", "æ", "ß", "Ä", "Ö", "Ü", "Ø", "Æ"}
local ACCENT_CHARS = {
    -- acute (é á í ó ú ý ć ń ś ź)
    "é","É","á","Á","í","Í","ó","Ó","ú","Ú","ý","Ý","ć","Ć","ń","Ń","ś","Ś","ź","Ź",
    -- grave (è à ì ò ù)
    "è","È","à","À","ì","Ì","ò","Ò","ù","Ù",
    -- circumflex (ê â î ô û)
    "ê","Ê","â","Â","î","Î","ô","Ô","û","Û",
}


-- Helper function for task queue - returns a task that delays N frames.
-- numberOfFrames=1 preserves the previous behavior (one frame delay before the next task).
local function TaskQueueDelayFrame(numberOfFrames)
    -- Each completed task schedules the next task on the next frame already.
    -- To wait N frames total, we need to "hold" for N-1 additional frames.
    local remaining = numberOfFrames - 1

    return function()
        if remaining > 0 then
            remaining = remaining - 1
            return false
        end
        return true
    end
end

local function PSC_RunTaskQueue(taskQueue, onDone)
    local currentTask = 1

    local function runNextTask()
        if currentTask > #taskQueue then
            if onDone then
                onDone()
            end
            return
        end

        local success, result = pcall(taskQueue[currentTask])
        if not success then
            print("[PvPStats] Error in incremental calculation task " .. currentTask .. ": " .. tostring(result))
            result = true
        end

        if result == nil or result == true then
            currentTask = currentTask + 1
        end

        if currentTask <= #taskQueue then
            C_Timer.After(0, runNextTask)
        else
            if onDone then
                onDone()
            end
        end
    end

    runNextTask()
end

-- Incremental calculation that processes stats over multiple frames
function PSC_StartIncrementalAchievementsCalculation()
    PVPSC._activeIncrementalAchievementsJob = PVPSC._activeIncrementalAchievementsJob or nil

    if PVPSC._activeIncrementalAchievementsJob then
        PVPSC._activeIncrementalAchievementsJob.dirty = true
        return
    end

    local killLocationsPerSlice = 5000

    local job = {
        dirty = false
    }
    PVPSC._activeIncrementalAchievementsJob = job

    local currentCharacterKey = PSC_GetCharacterKey()
    local charactersToProcess = {}
    charactersToProcess[currentCharacterKey] = PSC_DB.PlayerKillCounts.Characters[currentCharacterKey]

    local classData, raceData, genderData, unknownLevelClassData, zoneData, levelData, guildStatusData, guildData, npcKillsData, deathsByClassData
    local hourlyData, weekdayData, monthlyData, yearlyData, redridgeLevel15To25Kills, redridgeLevel60To70Kills
    local summaryStats = nil
    local achievementStats = nil

    local taskQueue = {
        function()
            local characterData = charactersToProcess[currentCharacterKey]
            job._timeStatsTask = PSC_CreateIncrementalTimeBasedStatsTask(characterData, killLocationsPerSlice, function(result)
                TimeStatsCache = result
            end)
            return true
        end,
        function()
            if not job._timeStatsTask then
                return true
            end
            return job._timeStatsTask()
        end,
        TaskQueueDelayFrame(1),
        function()
            PSC_GetStreakStats(true)
        end,
        TaskQueueDelayFrame(1),
        function()
            PSC_GetNameBasedStats(true)
        end,
        TaskQueueDelayFrame(1),
        function()
            classData, raceData, genderData, unknownLevelClassData, zoneData, levelData, guildStatusData, guildData, npcKillsData, hourlyData, redridgeLevel15To25Kills, redridgeLevel60To70Kills =
                PSC_CalculateBarChartStatistics(charactersToProcess)
        end,
        TaskQueueDelayFrame(1),
        function()
            weekdayData = PSC_CalculateWeekdayStatistics(charactersToProcess)
        end,
        TaskQueueDelayFrame(1),
        function()
            monthlyData = PSC_CalculateMonthlyStatistics(charactersToProcess)
        end,
        TaskQueueDelayFrame(1),
        function()
            yearlyData = PSC_CalculateYearlyStatistics(charactersToProcess)
        end,
        TaskQueueDelayFrame(1),
        function()
            deathsByClassData = PSC_CalculateDeathsByClass(charactersToProcess)
        end,
        TaskQueueDelayFrame(1),
        function()
            local task = PSC_CreateIncrementalSummaryStatisticsTask(charactersToProcess, killLocationsPerSlice, function(result)
                summaryStats = result

                -- Apply player profiles to summary stats (Most Killed & Nemesis)
                if PVPSC.Network and PVPSC.Network.ApplyPlayerProfile then
                    PVPSC.Network:ApplyPlayerProfile(summaryStats, "mostKilledPlayer", "mostKilledRace", "mostKilledGender", "mostKilledClass", charactersToProcess)
                    PVPSC.Network:ApplyPlayerProfile(summaryStats, "nemesisName", "nemesisRace", "nemesisGender", "nemesisClass", charactersToProcess)
                elseif ApplyPlayerProfile then
                    ApplyPlayerProfile(summaryStats, "mostKilledPlayer", "mostKilledRace", "mostKilledGender", "mostKilledClass", charactersToProcess)
                    ApplyPlayerProfile(summaryStats, "nemesisName", "nemesisRace", "nemesisGender", "nemesisClass", charactersToProcess)
                end
            end)
            job._summaryTask = task
            return true
        end,
        function()
            if not job._summaryTask then
                return true
            end
            return job._summaryTask()
        end,
        function()
            if not summaryStats then
                return false
            end

            -- Calculate guild achievement stats
            local maxSameGuildKills, uniqueGuildsKilled = PSC_CalculateGuildStats(guildData)

            achievementStats = {
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

            -- Broadcast calculated stats to network
            if PVPSC.Network and PVPSC.Network.initialized then
                local statsComponents = {
                    summary = summaryStats,
                    classData = classData,
                    raceData = raceData,
                    genderData = genderData,
                    zoneData = zoneData,
                    levelData = levelData,
                    hourlyData = hourlyData,
                    weekdayData = weekdayData,
                    monthlyData = monthlyData,
                    yearlyData = yearlyData,
                    unknownLevelClassData = unknownLevelClassData,
                    deathsByClassData = deathsByClassData,
                    guildStatusData = guildStatusData,
                    npcKillsData = npcKillsData
                }

                local broadcastStats = PVPSC.Network:ConstructPayload(statsComponents)
                PVPSC.Network:BroadcastStats(broadcastStats)
            end

            return true
        end,
        function()
            if not job._achievementTask then
                job._achievementTask = PVPSC.AchievementSystem:CreateIncrementalAchievementCheckTask(achievementStats)
            end

            return job._achievementTask()
        end
    }

    PSC_RunTaskQueue(taskQueue, function()
        PVPSC._activeIncrementalAchievementsJob = nil
        if job.dirty then
            C_Timer.After(0, function()
                PSC_StartIncrementalAchievementsCalculation()
            end)
        end
    end)
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

function PSC_SendAnnounceMessage(message)
    -- Global suppression of announce messages in Battlegrounds
    if PSC_CurrentlyInBattleground then
        return
    end

    local channel = PSC_DB.AnnounceChannel or "GROUP"

    if channel == "SELF" then
        print("[PvPStats]: " .. message)
    elseif channel == "GROUP" then
        if IsInGroup() then
            SendChatMessage(message, "PARTY")
        else
            print("[PvPStats]: " .. message)
        end
    elseif channel == "RAID" then
        if IsInRaid() then
            SendChatMessage(message, "RAID")
        elseif IsInGroup() then
            SendChatMessage(message, "PARTY")
        else
            print("[PvPStats]: " .. message)
        end
    elseif channel == "GUILD" then
        if IsInGuild() then
            SendChatMessage(message, "GUILD")
        else
            print("[PvPStats]: " .. message)
        end
    end
end

function IsPetGUID(guid)
    if not guid then return false end
    -- Classic WoW Pet GUID format example: Pet-0-6428-0-30486-3225-0400AB8043
    -- Check bytes P(80), e(101), t(116). Avoids string creation (garbage) and pattern matching overhead.
    local b1, b2, b3 = string.byte(guid, 1, 3)
    return b1 == 80 and b2 == 101 and b3 == 116
end

function GetPetOwnerGUID(petGUID)
    if not petGUID or not IsPetGUID(petGUID) then return nil end

    if UnitExists("pet") and UnitGUID("pet") == petGUID then
        return PSC_PlayerGUID
    end

    local numMembers = IsInRaid() and GetNumGroupMembers() or GetNumGroupMembers()
    local prefix = IsInRaid() and "raid" or "party"

    for i = 1, numMembers do
        local unitID
        if prefix == "party" then
            unitID = (i == GetNumGroupMembers()) and "player" or (prefix..i)
        else
            unitID = prefix..i
        end

        local petID = unitID.."pet"

        if UnitExists(petID) and UnitGUID(petID) == petGUID then
            return UnitGUID(unitID)
        end
    end

    return nil
end

function GetNameFromGUID(guid)
    if not guid then return nil end

    -- Try to find the name from the GUID
    local name = select(6, GetPlayerInfoByGUID(guid))
    if name then return name end

    -- If that fails, check if it's the player
    if guid == PSC_PlayerGUID then
        return PSC_CharacterName
    end

    -- Check party/raid members
    local numMembers = IsInRaid() and GetNumGroupMembers() or GetNumGroupMembers()
    local prefix = IsInRaid() and "raid" or "party"

    for i = 1, numMembers do
        local unitID
        if prefix == "party" then
            unitID = (i == GetNumGroupMembers()) and "player" or (prefix..i)
        else
            unitID = prefix..i
        end

        if UnitGUID(unitID) == guid then
            return UnitName(unitID)
        end
    end

    return nil
end

function PSC_GetRankName(rank)
    if not rank or rank <= 0 then
        return nil
    end

    local rankNames = {
        Alliance = {
            [1] = "Private",
            [2] = "Corporal",
            [3] = "Sergeant",
            [4] = "Master Sergeant",
            [5] = "Sergeant Major",
            [6] = "Knight",
            [7] = "Knight-Lieutenant",
            [8] = "Knight-Captain",
            [9] = "Knight-Champion",
            [10] = "Lieutenant Commander",
            [11] = "Commander",
            [12] = "Marshal",
            [13] = "Field Marshal",
            [14] = "Grand Marshal"
        },
        Horde = {
            [1] = "Scout",
            [2] = "Grunt",
            [3] = "Sergeant",
            [4] = "Senior Sergeant",
            [5] = "First Sergeant",
            [6] = "Stone Guard",
            [7] = "Blood Guard",
            [8] = "Legionnaire",
            [9] = "Centurion",
            [10] = "Champion",
            [11] = "Lieutenant General",
            [12] = "General",
            [13] = "Warlord",
            [14] = "High Warlord"
        }
    }

    local player_faction = UnitFactionGroup("player")
    local factionTable = nil
    if player_faction == "Horde" then
        factionTable = rankNames["Alliance"]
    else
        factionTable = rankNames["Horde"]
    end
    return factionTable[rank] or ("Rank " .. rank)
end

function PSC_Print(message)
    local PSC_CHAT_MESSAGE_R = 1.0
    local PSC_CHAT_MESSAGE_G = 1.0
    local PSC_CHAT_MESSAGE_B = 0.74
    DEFAULT_CHAT_FRAME:AddMessage(message, PSC_CHAT_MESSAGE_R, PSC_CHAT_MESSAGE_G, PSC_CHAT_MESSAGE_B)
end

function PSC_GetCharacterKey()
    return PSC_CharacterName .. "-" .. PSC_RealmName
end

function PSC_NormalizePlayerName(playerName)
    if not playerName or playerName == "" then
        return playerName
    end

    local _, infoKey = PSC_GetPlayerInfo(playerName)
    if infoKey then
        return infoKey
    end

    return PSC_GetInfoKeyFromName(playerName)
end

function PSC_IsSamePlayerName(candidateName, targetName)
    if not candidateName or candidateName == "" or not targetName or targetName == "" then
        return false
    end

    if candidateName == targetName then
        return true
    end

    local candidateKey = PSC_GetInfoKeyFromName(candidateName)
    local targetKey = PSC_GetInfoKeyFromName(targetName)
    if candidateKey == targetKey then
        return true
    end

    if not string.find(targetName, "%-") then
        local prefix = targetName .. "-"
        if candidateKey and string.sub(candidateKey, 1, #prefix) == prefix then
            return true
        end
        if string.sub(candidateName, 1, #prefix) == prefix then
            return true
        end
    end

    return false
end

function PSC_GetAddonVersion()
    return "4.7"
end

-- Returns true if versionStr >= minVersion (both in "major.minor.patch" format)
function PSC_IsVersionAtLeast(versionStr, minVersion)
    if not versionStr or not minVersion then return false end
    local function parse(v)
        local a, b, c = v:match("^(%d+)%.(%d+)%.?(%d*)")
        return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
    end
    local ma, mi, pa = parse(versionStr)
    local mb, mj, pb = parse(minVersion)
    if ma ~= mb then return ma > mb end
    if mi ~= mj then return mi > mj end
    return pa >= pb
end

function GetMultiKillText(count)
    if count < 2 then return "" end

    local killTexts = {
        "DOUBLE KILL!",
        "TRIPLE KILL!",
        "QUADRA KILL!",
        "PENTA KILL!",
        "HEXA KILL!"
    }

    if count <= 6 then
        return killTexts[count - 1]
    end

    return "Multi-kill of " .. count
end

function PSC_GetPlayerCoordinates()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        -- Arenas (and some instanced content) return nil for the map ID.
        -- C_Map.GetPlayerMapPosition would error on a nil mapID, so bail early.
        return nil, nil
    end
    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return nil, nil
    end

    local x = position.x * 100
    local y = position.y * 100
    return x, y
end

function PSC_FormatLastKillTimespan(lastKillTimestamp, useServerTime)
    if not lastKillTimestamp then
        return nil
    end

    local currentTime
    if useServerTime then
        currentTime = GetServerTime()
    else
        currentTime = time()
    end

    local timeDiff = currentTime - lastKillTimestamp

    -- Handle negative diffs (clock skew etc)
    if timeDiff < 0 then timeDiff = 0 end

    if timeDiff < 60 then
        return format("%ds", timeDiff)
    elseif timeDiff < 3600 then
        return format("%dm", math.floor(timeDiff/60))
    elseif timeDiff < 86400 then
        return format("%dh", math.floor(timeDiff/3600))
    else
        return format("%dd", math.floor(timeDiff/86400))
    end
end

-- Formats a timestamp into a relative "time ago" string (e.g., "5m ago")
function PSC_GetTimeAgo(timestamp, useServerTime)
    if not timestamp or timestamp <= 0 then
        return "Unknown"
    end

    local timeString = PSC_FormatLastKillTimespan(timestamp, useServerTime)
    if timeString then
        return timeString .. " ago"
    end

    return "Unknown"
end

function PSC_FormatKDRatio(totalKills, totalDeaths, kdRatio)
    if totalDeaths and totalDeaths > 0 then
        if not kdRatio then
            kdRatio = (totalKills or 0) / totalDeaths
        end
        return string.format("%.1f", kdRatio)
    else
        if totalKills and totalKills > 0 then
            return "∞"
        else
            return "0.0"
        end
    end
end

function PSC_CreateGoldHighlight(parent, height)
    local highlight = parent:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(true)

    local useNewAPI = highlight.SetGradient and type(highlight.SetGradient) == "function" and pcall(function()
        highlight:SetGradient("HORIZONTAL", {
            r = 1,
            g = 1,
            b = 1,
            a = 1
        }, {
            r = 1,
            g = 1,
            b = 1,
            a = 1
        })
        return true
    end)

    if useNewAPI then
        highlight:SetColorTexture(1, 0.82, 0, 0.6)
        pcall(function()
            highlight:SetGradient("HORIZONTAL", {
                r = 1,
                g = 0.82,
                b = 0,
                a = 0.3
            }, {
                r = 1,
                g = 0.82,
                b = 0,
                a = 0.8
            })
        end)
    else
        highlight:SetColorTexture(1, 0.82, 0, 0.5)

        local leftGradient = parent:CreateTexture(nil, "HIGHLIGHT")
        leftGradient:SetTexture("Interface\\Buttons\\WHITE8x8")
        leftGradient:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        leftGradient:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
        leftGradient:SetWidth(parent:GetWidth() / 2)
        leftGradient:SetHeight(height)

        pcall(function()
            leftGradient:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0, 0.3, 1, 0.82, 0, 0.7)
        end)

        if leftGradient:GetVertexColor() == 1 and select(2, leftGradient:GetVertexColor()) == 1 then
            leftGradient:SetVertexColor(1, 0.82, 0, 0.6)
        end

        local rightGradient = parent:CreateTexture(nil, "HIGHLIGHT")
        rightGradient:SetTexture("Interface\\Buttons\\WHITE8x8")
        rightGradient:SetPoint("TOPLEFT", leftGradient, "TOPRIGHT", 0, 0)
        rightGradient:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

        pcall(function()
            rightGradient:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0, 0.7, 1, 0.82, 0, 0.3)
        end)

        if rightGradient:GetVertexColor() == 1 and select(2, rightGradient:GetVertexColor()) == 1 then
            rightGradient:SetVertexColor(1, 0.82, 0, 0.6)
        end
    end

    local topBorder = parent:CreateTexture(nil, "HIGHLIGHT")
    topBorder:SetHeight(1)
    topBorder:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    topBorder:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    topBorder:SetColorTexture(1, 0.82, 0, 0.8)

    local bottomBorder = parent:CreateTexture(nil, "HIGHLIGHT")
    bottomBorder:SetHeight(1)
    bottomBorder:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bottomBorder:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bottomBorder:SetColorTexture(1, 0.82, 0, 0.8)

    return highlight
end

function PSC_TimestampToHour(timestamp, timezoneOffsetHours)
    if not timestamp then
        return nil
    end

    -- Use local time directly (date("*t") automatically handles timezone conversion)
    local dateInfo = date("*t", timestamp)
    if not dateInfo then
        return nil
    end

    return dateInfo.hour
end

function PSC_IsTimestampInHourRange(timestamp, startHour, endHour, timezoneOffsetHours)
    local hour = PSC_TimestampToHour(timestamp, timezoneOffsetHours)
    if not hour then
        return false
    end

    -- Handle ranges that cross midnight (e.g., 22-6 means 22:00-05:59)
    if startHour > endHour then
        return hour >= startHour or hour < endHour
    else
        return hour >= startHour and hour < endHour
    end
end

-- Weekday constants (matches Lua's date("*t").wday values)
-- IMPORTANT: Lua's date system uses 1-based indexing where:
--   Sunday = 1, Monday = 2, Tuesday = 3, Wednesday = 4,
--   Thursday = 5, Friday = 6, Saturday = 7
-- This is different from many programming languages that start with Monday = 0 or 1
local WEEKDAY = {
    SUNDAY = 1,
    MONDAY = 2,
    TUESDAY = 3,
    WEDNESDAY = 4,
    THURSDAY = 5,
    FRIDAY = 6,
    SATURDAY = 7
}

-- Helper function to get weekday name from number (for debugging)
local function GetWeekdayName(weekdayNumber)
    local names = {
        [WEEKDAY.SUNDAY] = "Sunday",
        [WEEKDAY.MONDAY] = "Monday",
        [WEEKDAY.TUESDAY] = "Tuesday",
        [WEEKDAY.WEDNESDAY] = "Wednesday",
        [WEEKDAY.THURSDAY] = "Thursday",
        [WEEKDAY.FRIDAY] = "Friday",
        [WEEKDAY.SATURDAY] = "Saturday"
    }
    return names[weekdayNumber] or "Unknown"
end

--[[
    TIME-BASED ACHIEVEMENTS SYSTEM DOCUMENTATION
    ============================================

    TIMEZONE HANDLING:
    - All time-based achievements automatically use the player's local system timezone
    - Kill timestamps are stored as UTC, but converted to local time for calculations
    - This ensures achievements work correctly regardless of server location or player timezone
    - Players in different timezones will see achievements based on their local time

    WEEKDAY SYSTEM EXPLANATION:
    - Lua's date("*t").wday returns weekday numbers where Sunday = 1
    - This is DIFFERENT from ISO standard (Monday = 1) and many programming languages
    - Use the WEEKDAY constants instead of magic numbers for clarity

    EXAMPLES OF ADDING NEW TIME-BASED ACHIEVEMENTS:

    1. Simple Time Range:
       Add to timeRanges: {6, 9, "early_morning"}
       In achievement: PSC_CountKillsByTimeRangeName("early_morning")

    2. Specific Weekday:
       Add to weekdayGroups: {"tuesday_only", {WEEKDAY.TUESDAY}}
       In achievement: PSC_CountKillsByWeekdayGroup("tuesday_only")

    3. Weekend Nights:
       Add to combinations: {22, 6, {WEEKDAY.SATURDAY, WEEKDAY.SUNDAY}, "weekend_nights"}
       In achievement: PSC_CountKillsByCombination("weekend_nights")

    4. Complex Condition:
       Add to specialConditions: {
           name = "summer_evenings",
           check = function(dateInfo)
               local isSummer = dateInfo.month >= 6 and dateInfo.month <= 8
               local isEvening = dateInfo.hour >= 18 and dateInfo.hour < 22
               return isSummer and isEvening
           end
       }
       In achievement: PSC_CountKillsBySpecialCondition("summer_evenings")
--]]

-- Configuration for time-based achievements - easy to extend!
local TimeBasedAchievementConfig = {
    -- Time ranges (startHour, endHour, optional_name)
    timeRanges = {
        {22, 6, "night_shift"},        -- Night shift: 10 PM - 6 AM
        {12, 14, "lunch_hour"},        -- Lunch hour: 12 PM - 2 PM
        {17, 21, "after_work"},        -- After work: 5 PM - 9 PM
        {9, 17, "work_hours"},         -- Work hours: 9 AM - 5 PM
        {0, 6, "midnight_to_dawn"},    -- Midnight to dawn: 12 AM - 6 AM
        {6, 12, "morning"},            -- Morning: 6 AM - 12 PM
        {18, 24, "evening"},           -- Evening: 6 PM - 12 AM
        {5, 8, "early_bird"},          -- Early bird: 5 AM - 8 AM
        -- Add more time ranges here as needed
    },

    -- Individual weekdays (weekday_number, name)
    weekdays = {
        {WEEKDAY.SUNDAY, "sunday"},
        {WEEKDAY.MONDAY, "monday"},
        {WEEKDAY.TUESDAY, "tuesday"},
        {WEEKDAY.WEDNESDAY, "wednesday"},
        {WEEKDAY.THURSDAY, "thursday"},
        {WEEKDAY.FRIDAY, "friday"},
        {WEEKDAY.SATURDAY, "saturday"},
    },

    -- Weekday groups (group_name, {weekday_numbers})
    weekdayGroups = {
        {"weekend", {WEEKDAY.SUNDAY, WEEKDAY.SATURDAY}},                                -- Weekend
        {"weekdays", {WEEKDAY.MONDAY, WEEKDAY.TUESDAY, WEEKDAY.WEDNESDAY, WEEKDAY.THURSDAY, WEEKDAY.FRIDAY}}, -- Monday-Friday
        {"weekends_extended", {WEEKDAY.FRIDAY, WEEKDAY.SATURDAY, WEEKDAY.SUNDAY}},      -- Friday night through Sunday
        -- Add more weekday groups here as needed
    },

    -- Months (month_number, name)
    months = {
        {1, "january"}, {2, "february"}, {3, "march"}, {4, "april"},
        {5, "may"}, {6, "june"}, {7, "july"}, {8, "august"},
        {9, "september"}, {10, "october"}, {11, "november"}, {12, "december"},
        -- Add seasonal groups if needed
        -- {[12,1,2], "winter"}, -- Would require different structure
    },

    -- Special dates (day, month, name)
    specialDates = {
        {25, 12, "christmas"},
        {24, 12, "christmas_eve"}, -- Christmas Eve
        {31, 12, "new_years_eve"},
        {1, 1, "new_years_day"},
        {14, 2, "valentines_day"},
        {1, 4, "april_fools"}, -- April Fool's Day
        {31, 10, "halloween"},
        {4, 7, "independence_day"}, -- US
        {22, 7, "july_22_test"}, -- July 22nd Test Date
        {1, 5, "may_day"},
        {23, 11, "wow_anniversary"}, -- WoW Vanilla Release Date
        {26, 8, "severussnipe_birthday"}, -- Severussnipe's birthday
        {12, 6, "hkfarmer_birthday"}, -- Hkfarmer's birthday
        -- Add more special dates here as needed
    },

    -- Time range + weekday combinations (startHour, endHour, {weekdays}, name)
    combinations = {
        {12, 14, {WEEKDAY.MONDAY, WEEKDAY.TUESDAY, WEEKDAY.WEDNESDAY, WEEKDAY.THURSDAY, WEEKDAY.FRIDAY}, "lunch_weekdays"},      -- Lunch on weekdays
        {17, 22, {WEEKDAY.MONDAY, WEEKDAY.TUESDAY, WEEKDAY.WEDNESDAY, WEEKDAY.THURSDAY, WEEKDAY.FRIDAY}, "afterwork_weekdays"},  -- After work on weekdays
        {9, 17, {WEEKDAY.MONDAY, WEEKDAY.TUESDAY, WEEKDAY.WEDNESDAY, WEEKDAY.THURSDAY, WEEKDAY.FRIDAY}, "workhours_weekdays"},   -- Work hours on weekdays
        {22, 6, {WEEKDAY.SATURDAY, WEEKDAY.SUNDAY}, "night_shift_weekend"},           -- Night shift on weekends
        {18, 24, {WEEKDAY.FRIDAY}, "friday_evening"},                  -- Friday evening
        -- Add more combinations here as needed
    },

    -- Special complex conditions
    specialConditions = {
        {
            name = "friday13th",
            check = function(dateInfo)
                return dateInfo.day == 13 and dateInfo.wday == WEEKDAY.FRIDAY -- Friday the 13th
            end
        },
        {
            name = "weekend_nights",
            check = function(dateInfo)
                local isWeekend = dateInfo.wday == WEEKDAY.SUNDAY or dateInfo.wday == WEEKDAY.SATURDAY
                local isNight = dateInfo.hour >= 22 or dateInfo.hour < 6
                return isWeekend and isNight
            end
        },
        {
            name = "anniversary_march_25_2026plus",
            check = function(dateInfo)
                return dateInfo.month == 3 and dateInfo.day == 25 and dateInfo.year >= 2026 -- PvPStats Classic anniversary (2026 onwards)
            end
        },
        -- Add more complex conditions here as needed
    }
}

local TimeBasedAchievementLookup = (function()
    local lookup = {}

    local ipairs = ipairs
    local tinsert = table.insert

    lookup.timeRangesByHour = {}
    for hour = 0, 23 do
        lookup.timeRangesByHour[hour] = {}
    end

    lookup.weekdayNameByNumber = {}
    lookup.weekdayGroupsByNumber = {}
    lookup.combosByWeekday = {}
    for wday = 1, 7 do
        lookup.weekdayGroupsByNumber[wday] = {}
        lookup.combosByWeekday[wday] = {}
    end

    lookup.monthNameByNumber = {}
    lookup.specialDatesByMonthDay = {}
    for month = 1, 12 do
        lookup.specialDatesByMonthDay[month] = {}
    end

    lookup.initKeys = {
        timeRanges = {},
        weekdays = {},
        weekdayGroups = {},
        months = {},
        specialDates = {},
        combinations = {},
        specialConditions = {}
    }

    -- Compile time ranges into per-hour lists
    for _, range in ipairs(TimeBasedAchievementConfig.timeRanges) do
        local startHour, endHour, optionalName = range[1], range[2], range[3]
        local rangeKey = startHour .. "_" .. endHour

        tinsert(lookup.initKeys.timeRanges, rangeKey)
        if optionalName then
            tinsert(lookup.initKeys.timeRanges, optionalName)
        end

        for hour = 0, 23 do
            local inRange
            if startHour > endHour then
                inRange = hour >= startHour or hour < endHour
            else
                inRange = hour >= startHour and hour < endHour
            end
            if inRange then
                tinsert(lookup.timeRangesByHour[hour], rangeKey)
                if optionalName then
                    tinsert(lookup.timeRangesByHour[hour], optionalName)
                end
            end
        end
    end

    -- Weekdays: map number -> name
    for _, weekday in ipairs(TimeBasedAchievementConfig.weekdays) do
        lookup.weekdayNameByNumber[weekday[1]] = weekday[2]
        tinsert(lookup.initKeys.weekdays, weekday[2])
    end

    -- Weekday groups: map weekday number -> group names
    for _, group in ipairs(TimeBasedAchievementConfig.weekdayGroups) do
        local groupName, weekdayNumbers = group[1], group[2]
        tinsert(lookup.initKeys.weekdayGroups, groupName)
        for _, wday in ipairs(weekdayNumbers) do
            tinsert(lookup.weekdayGroupsByNumber[wday], groupName)
        end
    end

    -- Months: map number -> name, and prepare init keys for both
    for _, month in ipairs(TimeBasedAchievementConfig.months) do
        lookup.monthNameByNumber[month[1]] = month[2]
        tinsert(lookup.initKeys.months, month[1])
        tinsert(lookup.initKeys.months, month[2])
    end

    -- Special dates: map month/day -> keys to increment
    for _, special in ipairs(TimeBasedAchievementConfig.specialDates) do
        local day, month, name = special[1], special[2], special[3]
        local key = day .. "_" .. month

        tinsert(lookup.initKeys.specialDates, key)
        tinsert(lookup.initKeys.specialDates, name)

        local monthBucket = lookup.specialDatesByMonthDay[month]
        if not monthBucket[day] then
            monthBucket[day] = {}
        end
        tinsert(monthBucket[day], key)
        tinsert(monthBucket[day], name)
    end

    -- Combinations: map weekday -> combos to check
    for _, combo in ipairs(TimeBasedAchievementConfig.combinations) do
        local startHour, endHour, weekdays, name = combo[1], combo[2], combo[3], combo[4]
        tinsert(lookup.initKeys.combinations, name)
        for _, wday in ipairs(weekdays) do
            tinsert(lookup.combosByWeekday[wday], {startHour = startHour, endHour = endHour, name = name})
        end
    end

    -- Special conditions: preserve as-is, but precompute init keys
    lookup.specialConditions = TimeBasedAchievementConfig.specialConditions
    for _, condition in ipairs(TimeBasedAchievementConfig.specialConditions) do
        tinsert(lookup.initKeys.specialConditions, condition.name)
    end

    return lookup
end)()

-- Optimized function to calculate ALL time-based statistics in a single pass
-- Function to get the local timezone offset in hours
-- This ensures that time-based achievements always use the player's local time
function PSC_GetLocalTimezoneOffset()
    -- Use current time to properly account for daylight saving time
    local currentTime = time()

    local utc_date = date("!*t", currentTime)  -- UTC time
    local local_date = date("*t", currentTime) -- Local time

    -- Calculate hour difference (this handles DST and timezone automatically)
    local hour_diff = local_date.hour - utc_date.hour

    -- Handle day boundary crossings
    if hour_diff > 12 then
        hour_diff = hour_diff - 24
    elseif hour_diff < -12 then
        hour_diff = hour_diff + 24
    end

    return hour_diff
end

function PSC_CalculateAllTimeBasedStats()
    local PSC_DB = PSC_DB
    local PSC_GetCharacterKey = PSC_GetCharacterKey
    local pairs = pairs
    local ipairs = ipairs
    local date = date

    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts and PSC_DB.PlayerKillCounts.Characters and PSC_DB.PlayerKillCounts.Characters[characterKey]

    if not characterData or not characterData.Kills then
        return {}
    end

    local function initCounterTable(keys)
        local t = {}
        for i = 1, #keys do
            t[keys[i]] = 0
        end
        return t
    end

    local initKeys = TimeBasedAchievementLookup.initKeys
    local stats = {
        timeRanges = initCounterTable(initKeys.timeRanges),
        weekdays = initCounterTable(initKeys.weekdays),
        weekdayGroups = initCounterTable(initKeys.weekdayGroups),
        months = initCounterTable(initKeys.months),
        specialDates = initCounterTable(initKeys.specialDates),
        combinations = initCounterTable(initKeys.combinations),
        specialConditions = initCounterTable(initKeys.specialConditions)
    }

    local timeRangesByHour = TimeBasedAchievementLookup.timeRangesByHour
    local weekdayNameByNumber = TimeBasedAchievementLookup.weekdayNameByNumber
    local weekdayGroupsByNumber = TimeBasedAchievementLookup.weekdayGroupsByNumber
    local monthNameByNumber = TimeBasedAchievementLookup.monthNameByNumber
    local specialDatesByMonthDay = TimeBasedAchievementLookup.specialDatesByMonthDay
    local combosByWeekday = TimeBasedAchievementLookup.combosByWeekday
    local specialConditions = TimeBasedAchievementLookup.specialConditions

    -- Single pass through all kills
    for _, playerData in pairs(characterData.Kills) do
        if playerData.killLocations then
            for _, killLocation in ipairs(playerData.killLocations) do
                if killLocation.timestamp then
                    -- Use local time directly (date("*t") already handles timezone conversion)
                    local dateInfo = date("*t", killLocation.timestamp)

                    if dateInfo then
                        local hour = dateInfo.hour
                        local weekday = dateInfo.wday
                        local month = dateInfo.month
                        local day = dateInfo.day

                        -- Count time ranges (precompiled by hour)
                        local rangeKeys = timeRangesByHour[hour]
                        for i = 1, #rangeKeys do
                            local key = rangeKeys[i]
                            stats.timeRanges[key] = stats.timeRanges[key] + 1
                        end

                        -- Count individual weekday
                        local weekdayName = weekdayNameByNumber[weekday]
                        if weekdayName then
                            stats.weekdays[weekdayName] = stats.weekdays[weekdayName] + 1
                        end

                        -- Count weekday groups
                        local groupNames = weekdayGroupsByNumber[weekday]
                        for i = 1, #groupNames do
                            local groupName = groupNames[i]
                            stats.weekdayGroups[groupName] = stats.weekdayGroups[groupName] + 1
                        end

                        -- Count months
                        stats.months[month] = stats.months[month] + 1
                        local monthName = monthNameByNumber[month]
                        if monthName then
                            stats.months[monthName] = stats.months[monthName] + 1
                        end

                        -- Count special dates
                        local monthBucket = specialDatesByMonthDay[month]
                        local specialKeys = monthBucket and monthBucket[day]
                        if specialKeys then
                            for i = 1, #specialKeys do
                                local key = specialKeys[i]
                                stats.specialDates[key] = stats.specialDates[key] + 1
                            end
                        end

                        -- Count combinations (precompiled per weekday)
                        local combos = combosByWeekday[weekday]
                        for i = 1, #combos do
                            local combo = combos[i]
                            local startHour, endHour = combo.startHour, combo.endHour

                            local inTimeRange
                            if startHour > endHour then
                                inTimeRange = hour >= startHour or hour < endHour
                            else
                                inTimeRange = hour >= startHour and hour < endHour
                            end

                            if inTimeRange then
                                stats.combinations[combo.name] = stats.combinations[combo.name] + 1
                            end
                        end

                        -- Count special conditions
                        for i = 1, #specialConditions do
                            local condition = specialConditions[i]
                            if condition.check(dateInfo) then
                                stats.specialConditions[condition.name] = stats.specialConditions[condition.name] + 1
                            end
                        end
                    end
                end
            end
        end
    end

    return stats
end

function PSC_CreateIncrementalTimeBasedStatsTask(characterData, maxKillLocationsPerFrame, onComplete)
    if type(onComplete) ~= "function" then
        return function()
            return true
        end
    end

    if not characterData or not characterData.Kills then
        local done = false
        return function()
            if not done then
                done = true
                onComplete({})
            end
            return true
        end
    end

    local sliceBudget = tonumber(maxKillLocationsPerFrame) or 0
    sliceBudget = math.floor(sliceBudget)
    if sliceBudget < 50 then
        sliceBudget = 50
    end

    local pairs = pairs
    local date = date
    local ipairs = ipairs
    local tinsert = table.insert

    local function initCounterTable(keys)
        local t = {}
        for i = 1, #keys do
            t[keys[i]] = 0
        end
        return t
    end

    local initKeys = TimeBasedAchievementLookup.initKeys
    local stats = {
        timeRanges = initCounterTable(initKeys.timeRanges),
        weekdays = initCounterTable(initKeys.weekdays),
        weekdayGroups = initCounterTable(initKeys.weekdayGroups),
        months = initCounterTable(initKeys.months),
        specialDates = initCounterTable(initKeys.specialDates),
        combinations = initCounterTable(initKeys.combinations),
        specialConditions = initCounterTable(initKeys.specialConditions)
    }

    local timeRangesByHour = TimeBasedAchievementLookup.timeRangesByHour
    local weekdayNameByNumber = TimeBasedAchievementLookup.weekdayNameByNumber
    local weekdayGroupsByNumber = TimeBasedAchievementLookup.weekdayGroupsByNumber
    local monthNameByNumber = TimeBasedAchievementLookup.monthNameByNumber
    local specialDatesByMonthDay = TimeBasedAchievementLookup.specialDatesByMonthDay
    local combosByWeekday = TimeBasedAchievementLookup.combosByWeekday
    local specialConditions = TimeBasedAchievementLookup.specialConditions

    local players = {}
    for _, playerData in pairs(characterData.Kills) do
        tinsert(players, playerData)
    end

    local playerIndex = 1
    local locationIndex = 1
    local finished = false

    return function()
        if finished then
            return true
        end

        local processed = 0
        while processed < sliceBudget do
            if playerIndex > #players then
                finished = true
                onComplete(stats)
                return true
            end

            local playerData = players[playerIndex]
            local locations = playerData and playerData.killLocations

            if not locations or #locations == 0 then
                playerIndex = playerIndex + 1
                locationIndex = 1
            else
                if locationIndex > #locations then
                    playerIndex = playerIndex + 1
                    locationIndex = 1
                else
                    local killLocation = locations[locationIndex]
                    locationIndex = locationIndex + 1
                    processed = processed + 1

                    local timestamp = killLocation and killLocation.timestamp
                    if timestamp then
                        -- Keep the same per-kill logic as PSC_CalculateAllTimeBasedStats(),
                        -- just spread across frames.
                        local dateInfo = date("*t", timestamp)
                        if dateInfo then
                            local hour = dateInfo.hour
                            local weekday = dateInfo.wday
                            local month = dateInfo.month
                            local day = dateInfo.day

                            -- Count time ranges (precompiled by hour)
                            local rangeKeys = timeRangesByHour[hour]
                            for i = 1, #rangeKeys do
                                local key = rangeKeys[i]
                                stats.timeRanges[key] = stats.timeRanges[key] + 1
                            end

                            -- Count individual weekday
                            local weekdayName = weekdayNameByNumber[weekday]
                            if weekdayName then
                                stats.weekdays[weekdayName] = stats.weekdays[weekdayName] + 1
                            end

                            -- Count weekday groups
                            local groupNames = weekdayGroupsByNumber[weekday]
                            for i = 1, #groupNames do
                                local groupName = groupNames[i]
                                stats.weekdayGroups[groupName] = stats.weekdayGroups[groupName] + 1
                            end

                            -- Count months
                            stats.months[month] = stats.months[month] + 1
                            local monthName = monthNameByNumber[month]
                            if monthName then
                                stats.months[monthName] = stats.months[monthName] + 1
                            end

                            -- Count special dates
                            local monthBucket = specialDatesByMonthDay[month]
                            local specialKeys = monthBucket and monthBucket[day]
                            if specialKeys then
                                for i = 1, #specialKeys do
                                    local key = specialKeys[i]
                                    stats.specialDates[key] = stats.specialDates[key] + 1
                                end
                            end

                            -- Count combinations (precompiled per weekday)
                            local combos = combosByWeekday[weekday]
                            for i = 1, #combos do
                                local combo = combos[i]
                                local startHour, endHour = combo.startHour, combo.endHour

                                local inTimeRange
                                if startHour > endHour then
                                    inTimeRange = hour >= startHour or hour < endHour
                                else
                                    inTimeRange = hour >= startHour and hour < endHour
                                end

                                if inTimeRange then
                                    stats.combinations[combo.name] = stats.combinations[combo.name] + 1
                                end
                            end

                            -- Count special conditions
                            for i = 1, #specialConditions do
                                local condition = specialConditions[i]
                                if condition.check(dateInfo) then
                                    stats.specialConditions[condition.name] = stats.specialConditions[condition.name] + 1
                                end
                            end
                        end
                    end
                end
            end
        end

        return false
    end
end


function PSC_GetTimeBasedStats()
    if not TimeStatsCache then
        TimeStatsCache = PSC_CalculateAllTimeBasedStats()
    end

    return TimeStatsCache
end

function PSC_CountKillsInTimeRange(startHour, endHour, timezoneOffsetHours)
    local stats = PSC_GetTimeBasedStats()
    local key = startHour .. "_" .. endHour
    return stats.timeRanges[key] or 0
end

function PSC_CountKillsOnWeekdays(weekdays, timezoneOffsetHours)
    local stats = PSC_GetTimeBasedStats()
    local count = 0

    for _, day in ipairs(weekdays) do
        if day == WEEKDAY.SUNDAY then
            count = count + (stats.weekdays.sunday or 0)
        elseif day == WEEKDAY.MONDAY then
            count = count + (stats.weekdays.monday or 0)
        elseif day == WEEKDAY.TUESDAY then
            count = count + (stats.weekdays.tuesday or 0)
        elseif day == WEEKDAY.WEDNESDAY then
            count = count + (stats.weekdays.wednesday or 0)
        elseif day == WEEKDAY.THURSDAY then
            count = count + (stats.weekdays.thursday or 0)
        elseif day == WEEKDAY.FRIDAY then
            count = count + (stats.weekdays.friday or 0)
        elseif day == WEEKDAY.SATURDAY then
            count = count + (stats.weekdays.saturday or 0)
        end
    end

    return count
end

function PSC_CountKillsInTimeRangeOnWeekdays(startHour, endHour, weekdays, timezoneOffsetHours)
    local stats = PSC_GetTimeBasedStats()

    -- Use pre-calculated combinations for common cases
    if startHour == 12 and endHour == 14 then
        return stats.combinations.lunch_weekdays or 0
    elseif startHour == 17 and endHour == 21 then
        return stats.combinations.afterwork_weekdays or 0
    elseif startHour == 9 and endHour == 17 then
        return stats.combinations.workhours_weekdays or 0
    end

    -- Fallback to original calculation for other cases
    local count = 0
    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts and PSC_DB.PlayerKillCounts.Characters and PSC_DB.PlayerKillCounts.Characters[characterKey]

    if not characterData or not characterData.Kills then
        return 0
    end

    for playerKey, playerData in pairs(characterData.Kills) do
        if playerData.killLocations then
            for _, killLocation in ipairs(playerData.killLocations) do
                if killLocation.timestamp and
                   PSC_IsTimestampInHourRange(killLocation.timestamp, startHour, endHour, timezoneOffsetHours) and
                   PSC_IsTimestampOnWeekday(killLocation.timestamp, weekdays, timezoneOffsetHours) then
                    count = count + 1
                end
            end
        end
    end

    return count
end

-- Get kills by time range name (from config)
function PSC_CountKillsByTimeRangeName(rangeName)
    local stats = PSC_GetTimeBasedStats()
    return stats.timeRanges[rangeName] or 0
end

-- Get kills by weekday group name (from config)
function PSC_CountKillsByWeekdayGroup(groupName)
    local stats = PSC_GetTimeBasedStats()
    return stats.weekdayGroups[groupName] or 0
end

-- Get kills by special date name (from config)
function PSC_CountKillsBySpecialDate(dateName)
    local stats = PSC_GetTimeBasedStats()
    return stats.specialDates[dateName] or 0
end

-- Get kills by combination name (from config)
function PSC_CountKillsByCombination(combinationName)
    local stats = PSC_GetTimeBasedStats()
    return stats.combinations[combinationName] or 0
end

-- Get kills by special condition name (from config)
function PSC_CountKillsBySpecialCondition(conditionName)
    local stats = PSC_GetTimeBasedStats()
    return stats.specialConditions[conditionName] or 0
end

-- Get kills by month name
function PSC_CountKillsByMonthName(monthName)
    local stats = PSC_GetTimeBasedStats()
    return stats.months[monthName] or 0
end

function PSC_TestTimeZoneOffsetCalculation()
    local characterKey = PSC_GetCharacterKey()
    if not PSC_DB or not PSC_DB.PlayerKillCounts or not PSC_DB.PlayerKillCounts.Characters then
        PSC_Print("ERROR: No character data found")
        return
    end
    local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]
    if not characterData or not characterData.Kills then
        PSC_Print("ERROR: No kills data found")
        return
    end
    local totalKills = 0
    for playerKey, playerData in pairs(characterData.Kills) do
        if playerData.killLocations then
            totalKills = totalKills + #playerData.killLocations
        end
    end

    local localOffset = PSC_GetLocalTimezoneOffset()
    PSC_Print("SUCCESS: Found " .. totalKills .. " total kills")
    PSC_Print("Local timezone offset: UTC" .. (localOffset >= 0 and "+" or "") .. localOffset)

    -- Debug timezone calculation
    local currentTime = time()
    local utc_date = date("!*t", currentTime)
    local local_date = date("*t", currentTime)
    PSC_Print("DEBUG: UTC time: " .. utc_date.hour .. ":" .. string.format("%02d", utc_date.min))
    PSC_Print("DEBUG: System local time: " .. local_date.hour .. ":" .. string.format("%02d", local_date.min))
    PSC_Print("DEBUG: Raw hour difference: " .. (local_date.hour - utc_date.hour))

    -- Test work hours calculation
    local stats = PSC_GetTimeBasedStats()
    local workHoursKills = stats.combinations.workhours_weekdays or 0
    PSC_Print("Work hours weekdays kills: " .. workHoursKills)

    -- Test current time WITHOUT manual timezone adjustment (date("*t") already handles local time)
    local dateInfo = date("*t", currentTime)
    PSC_Print("Current calculated local time: " .. dateInfo.hour .. ":" .. string.format("%02d", dateInfo.min))
    PSC_Print("Current weekday: " .. dateInfo.wday .. " (1=Sunday, 2=Monday, etc.)")
    PSC_Print("Is work hours? " .. (dateInfo.hour >= 9 and dateInfo.hour < 17 and dateInfo.wday >= 2 and dateInfo.wday <= 6 and "YES" or "NO"))

    PSC_Print("=== TIMEZONE FIX APPLIED ===")
    PSC_Print("Fixed: All time functions now use date('*t') without manual timezone offset")
    PSC_Print("This prevents double-applying timezone conversion")
    PSC_Print("=== End Test ===")
end

function PSC_IsTimestampOnWeekday(timestamp, weekdays, timezoneOffsetHours)
    if not timestamp or not weekdays then
        return false
    end

    -- Use local time directly (date("*t") automatically handles timezone conversion)
    local dateInfo = date("*t", timestamp)
    if not dateInfo then
        return false
    end

    for _, day in ipairs(weekdays) do
        if dateInfo.wday == day then
            return true
        end
    end

    return false
end



function PSC_CountKillsInTimeRangeOnWeekdays(startHour, endHour, weekdays, timezoneOffsetHours)
    local count = 0
    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts and PSC_DB.PlayerKillCounts.Characters and PSC_DB.PlayerKillCounts.Characters[characterKey]

    if not characterData or not characterData.Kills then
        return 0
    end

    for playerKey, playerData in pairs(characterData.Kills) do
        if playerData.killLocations then
            for _, killLocation in ipairs(playerData.killLocations) do
                if killLocation.timestamp and
                   PSC_IsTimestampInHourRange(killLocation.timestamp, startHour, endHour, timezoneOffsetHours) and
                   PSC_IsTimestampOnWeekday(killLocation.timestamp, weekdays, timezoneOffsetHours) then
                    count = count + 1
                end
            end
        end
    end

    return count
end

function PSC_IsTimestampOnDate(timestamp, day, month, timezoneOffsetHours)
    if not timestamp or not day or not month then
        return false
    end

    -- Use local time directly (date("*t") automatically handles timezone conversion)
    local dateInfo = date("*t", timestamp)
    if not dateInfo then
        return false
    end

    return dateInfo.day == day and dateInfo.month == month
end

function PSC_CountKillsOnDate(day, month, timezoneOffsetHours)
    local count = 0
    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts and PSC_DB.PlayerKillCounts.Characters and PSC_DB.PlayerKillCounts.Characters[characterKey]

    if not characterData or not characterData.Kills then
        return 0
    end

    for playerKey, playerData in pairs(characterData.Kills) do
        if playerData.killLocations then
            for _, killLocation in ipairs(playerData.killLocations) do
                if killLocation.timestamp and PSC_IsTimestampOnDate(killLocation.timestamp, day, month, timezoneOffsetHours) then
                    count = count + 1
                end
            end
        end
    end

    return count
end

function PSC_IsTimestampOnFridayThe13th(timestamp, timezoneOffsetHours)
    if not timestamp then
        return false
    end

    -- Use local time directly (date("*t") automatically handles timezone conversion)
    local dateInfo = date("*t", timestamp)
    if not dateInfo then
        return false
    end

    return dateInfo.day == 13 and dateInfo.wday == 6
end

function PSC_CountKillsOnFridayThe13th(timezoneOffsetHours)
    local count = 0
    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts and PSC_DB.PlayerKillCounts.Characters and PSC_DB.PlayerKillCounts.Characters[characterKey]

    if not characterData or not characterData.Kills then
        return 0
    end

    for playerKey, playerData in pairs(characterData.Kills) do
        if playerData.killLocations then
            for _, killLocation in ipairs(playerData.killLocations) do
                if killLocation.timestamp and PSC_IsTimestampOnFridayThe13th(killLocation.timestamp, timezoneOffsetHours) then
                    count = count + 1
                end
            end
        end
    end

    return count
end

function PSC_IsTimestampInMonth(timestamp, month, timezoneOffsetHours)
    if not timestamp or not month then
        return false
    end

    -- Use local time directly (date("*t") automatically handles timezone conversion)
    local dateInfo = date("*t", timestamp)
    if not dateInfo then
        return false
    end

    return dateInfo.month == month
end

function PSC_CountKillsInMonth(month, timezoneOffsetHours)
    local count = 0
    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts and PSC_DB.PlayerKillCounts.Characters and PSC_DB.PlayerKillCounts.Characters[characterKey]

    if not characterData or not characterData.Kills then
        return 0
    end

    for playerKey, playerData in pairs(characterData.Kills) do
        if playerData.killLocations then
            for _, killLocation in ipairs(playerData.killLocations) do
                if killLocation.timestamp and PSC_IsTimestampInMonth(killLocation.timestamp, month, timezoneOffsetHours) then
                    count = count + 1
                end
            end
        end
    end

    return count
end

-- Calculate all name-based statistics in a single pass for performance
function PSC_CalculateAllNameBasedStats()
    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts and PSC_DB.PlayerKillCounts.Characters and PSC_DB.PlayerKillCounts.Characters[characterKey]

    if not characterData or not characterData.Kills then
        return {}
    end

    local stats = {
        byFirstLetter = {},
        byNameLength = {},
        withSpecialChars = 0,
        withAccentChars = 0
    }

    -- Single pass through all kills
    -- Dynamically build letter and length buckets to support any UTF-8 characters
    for playerKey, playerData in pairs(characterData.Kills) do
        -- Key format is "Name-Realm:Level"; strip realm and level to get just the base name
        local playerName = string.match(playerKey, "^([^%-:]+)")
        if playerName and #playerName > 0 then
            local killCount = playerData.kills or #(playerData.killLocations or {})

            -- Count by first letter (supports any UTF-8 character)
            local firstLetter = string.upper(string.sub(playerName, 1, 1))
            stats.byFirstLetter[firstLetter] = (stats.byFirstLetter[firstLetter] or 0) + killCount

            -- Count by name length (supports any length)
            local nameLen = #playerName
            stats.byNameLength[nameLen] = (stats.byNameLength[nameLen] or 0) + killCount

            -- Count kills where name contains special characters (ä,ö,ü,ø,æ)
            for _, ch in ipairs(SPECIAL_CHARS) do
                if string.find(playerName, ch, 1, true) then
                    stats.withSpecialChars = stats.withSpecialChars + killCount
                    break
                end
            end

            -- Count kills where name contains accent characters (é,è,ê,á,à,â,...)
            for _, ch in ipairs(ACCENT_CHARS) do
                if string.find(playerName, ch, 1, true) then
                    stats.withAccentChars = stats.withAccentChars + killCount
                    break
                end
            end
        end
    end

    return stats
end

-- Get cached name-based stats
function PSC_GetNameBasedStats(forceRefresh)
    if not nameStatsCache or forceRefresh then
        nameStatsCache = PSC_CalculateAllNameBasedStats()
    end
    return nameStatsCache
end

function PSC_CountKillsStartingWithLetter(letter)
    local stats = PSC_GetNameBasedStats()
    letter = string.upper(letter)
    return stats.byFirstLetter[letter] or 0
end

function PSC_CountKillsByLength(length)
    local stats = PSC_GetNameBasedStats()
    return stats.byNameLength[length] or 0
end

function PSC_CountKillsWithNameStartingWith(letter)
    local stats = PSC_GetNameBasedStats()
    letter = string.upper(letter)
    return stats.byFirstLetter[letter] or 0
end

function PSC_CountKillsWithNameLength(length)
    local stats = PSC_GetNameBasedStats()
    return stats.byNameLength[length] or 0
end

function PSC_CountKillsWithSpecialCharsInName()
    local stats = PSC_GetNameBasedStats()
    return stats.withSpecialChars or 0
end

function PSC_CountKillsWithAccentCharsInName()
    local stats = PSC_GetNameBasedStats()
    return stats.withAccentChars or 0
end

function PSC_GetCurrentAchievementPoints()
    local characterKey = PSC_GetCharacterKey()
    return PSC_DB.CharacterAchievementPoints and PSC_DB.CharacterAchievementPoints[characterKey] or 0
end

function PSC_GetUnlockedAchievementCount()
    local characterKey = PSC_GetCharacterKey()
    if not PSC_DB or not PSC_DB.CharacterAchievements or not PSC_DB.CharacterAchievements[characterKey] then
        return 0
    end

    local count = 0
    for id, data in pairs(PSC_DB.CharacterAchievements[characterKey]) do
        if data.unlocked then
            count = count + 1
        end
    end
    return count
end

function PSC_CalculateAchievementCompletion(achievement, stats)
    if not achievement or achievement.unlocked or not achievement.progress or not achievement.targetValue or achievement.targetValue == 0 then
        return 0
    end

    local currentProgress = achievement.progress(achievement, stats)
    if currentProgress >= achievement.targetValue then
        return 100
    end

    return (currentProgress / achievement.targetValue) * 100
end

-- Function to calculate all streak statistics in a single pass for improved performance
function PSC_CalculateAllStreakStats()
    local PSC_DB = PSC_DB
    local PSC_GetCharacterKey = PSC_GetCharacterKey
    local pairs = pairs
    local ipairs = ipairs
    local date = date
    local tonumber = tonumber
    local strmatch = string.match
    local tinsert = table.insert
    local tsort = table.sort
    local floor = math.floor

    -- Convert a calendar date (Y-M-D) into a monotonically increasing day number.
    -- This avoids DST issues that happen when comparing midnight timestamps.
    local function ymdToDayNumber(year, month, day)
        if month <= 2 then
            year = year - 1
            month = month + 12
        end

        local era = floor(year / 400)
        local yoe = year - era * 400
        local doy = floor((153 * (month - 3) + 2) / 5) + day - 1
        local doe = yoe * 365 + floor(yoe / 4) - floor(yoe / 100) + doy
        return era * 146097 + doe
    end

    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts and PSC_DB.PlayerKillCounts.Characters and PSC_DB.PlayerKillCounts.Characters[characterKey]

    if not characterData or not characterData.Kills then
        return {}
    end

    -- Collect all kill timestamps and group them by date
    local killsByDate = {}

    for _, playerData in pairs(characterData.Kills) do
        if playerData.killLocations then
            for _, killLocation in ipairs(playerData.killLocations) do
                if killLocation.timestamp then
                    -- Convert timestamp to date string (YYYY-MM-DD format)
                    -- Using date('%Y-%m-%d') avoids allocating a '*t' table for every killLocation.
                    local dateKey = date("%Y-%m-%d", killLocation.timestamp)
                    if dateKey and dateKey ~= "" then
                        killsByDate[dateKey] = (killsByDate[dateKey] or 0) + 1
                    end
                end
            end
        end
    end

    -- Convert to sorted array of all dates with kills
    local allDates = {}
    for dateKey, killCount in pairs(killsByDate) do
        tinsert(allDates, {date = dateKey, kills = killCount})
    end

    -- Sort dates chronologically
    tsort(allDates, function(a, b)
        return a.date < b.date
    end)

    -- Precompute a dayNumber for each unique date string once.
    for _, dateData in ipairs(allDates) do
        local year, month, day = strmatch(dateData.date, "(%d+)%-(%d+)%-(%d+)")
        year, month, day = tonumber(year), tonumber(month), tonumber(day)
        if year and month and day then
            dateData.dayNumber = ymdToDayNumber(year, month, day)
        else
            dateData.dayNumber = nil
        end
    end

    -- Calculate streaks for different kill thresholds
    local streakResults = {}
    local killThresholds = {1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 75, 100, 125, 150, 200, 250, 300, 500, 1000}

    for _, minKills in ipairs(killThresholds) do
        local totalDays = 0
        local maxStreak = 0
        local currentStreak = 0
        local prevValidDayNumber = nil

        for _, dateData in ipairs(allDates) do
            if dateData.kills >= minKills then
                totalDays = totalDays + 1

                local dayNumber = dateData.dayNumber
                if dayNumber and prevValidDayNumber and dayNumber == (prevValidDayNumber + 1) then
                    currentStreak = currentStreak + 1
                else
                    currentStreak = 1
                end

                if currentStreak > maxStreak then
                    maxStreak = currentStreak
                end

                prevValidDayNumber = dayNumber
            end
        end

        streakResults["total_" .. minKills] = totalDays
        streakResults[minKills] = maxStreak
    end

    return streakResults
end

-- Function to get cached streak stats with automatic refresh when needed
function PSC_GetStreakStats(forceRefresh)
    if not streakStatsCache or forceRefresh then
        streakStatsCache = PSC_CalculateAllStreakStats()
    end

    return streakStatsCache
end

-- Function to manually clear the streak cache (called when new kills are registered)
function PSC_CountConsecutiveDaysWithMinKills(minKills)
    local streakStats = PSC_GetStreakStats()
    return streakStats[minKills] or 0
end

-- Function to count total days with at least minKills (non-consecutive)
function PSC_CountTotalDaysWithMinKills(minKills)
    if not minKills or minKills <= 0 then
        return 0
    end

    -- Use cached streak stats for much better performance
    local streakStats = PSC_GetStreakStats()
    return streakStats["total_" .. minKills] or 0
end

-- Helper function to calculate the start timestamps for various time periods
function PSC_CalculateTimePeriodBoundaries()
    local currentTime = time()
    local today = date("*t", currentTime)

    -- Calculate seconds since midnight today
    local secondsSinceMidnight = today.hour * 3600 + today.min * 60 + today.sec
    local todayStart = currentTime - secondsSinceMidnight

    -- Calculate week start (Wednesday at midnight - WoW weekly reset)
    -- Calculate days from Wednesday (wday: 1=Sunday, 2=Monday, 3=Tuesday, 4=Wednesday, 5=Thursday, 6=Friday, 7=Saturday)
    -- Wednesday (wday=4): (4 + 3) % 7 = 0 days back → Current reset week
    -- Thursday (wday=5): (5 + 3) % 7 = 1 day back → Go back 1 day to Wednesday
    -- Friday (wday=6): (6 + 3) % 7 = 2 days back → Go back 2 days to Wednesday
    -- Saturday (wday=7): (7 + 3) % 7 = 3 days back → Go back 3 days to Wednesday
    -- Sunday (wday=1): (1 + 3) % 7 = 4 days back → Go back 4 days to Wednesday
    -- Monday (wday=2): (2 + 3) % 7 = 5 days back → Go back 5 days to Wednesday
    -- Tuesday (wday=3): (3 + 3) % 7 = 6 days back → Go back 6 days to Wednesday
    local daysFromWednesday = (today.wday + 3) % 7
    local secondsToWednesdayMidnight = daysFromWednesday * 86400 + secondsSinceMidnight
    local weekStart = currentTime - secondsToWednesdayMidnight

    -- Calculate month start (1st of current month at midnight)
    local secondsSinceMonthStart = (today.day - 1) * 86400 + secondsSinceMidnight
    local monthStart = currentTime - secondsSinceMonthStart

    -- Calculate year start (January 1st at midnight)
    -- Calculate total days elapsed this year (counting from January 1st)
    local daysThisYear = today.yday - 1  -- yday is 1-based (1 = Jan 1), so subtract 1
    local secondsSinceYearStart = daysThisYear * 86400 + secondsSinceMidnight
    local yearStart = currentTime - secondsSinceYearStart

    return {
        todayStart = todayStart,
        weekStart = weekStart,
        monthStart = monthStart,
        yearStart = yearStart
    }
end

local GUIDToNPCIDCache = {}

function PSC_ClearGUIDCache()
    GUIDToNPCIDCache = {}
end

function PSC_GetNPCIDFromGUID(guid)
    if not guid then return nil end

    -- Check cache first (O(1) lookup)
    local npcId = GUIDToNPCIDCache[guid]
    if npcId then
        return npcId
    end

    -- Fast check for Creature (C=67)
    -- Filters out Players, Pets, Items, etc. instantly without memory allocation
    local firstByte = string.byte(guid)
    if firstByte ~= 67 then return nil end

    -- GUID format: UnitType-0-Server-Instance-Zone-NPCID-Spawn
    local npcIDString = string.match(guid, "^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    local npcID = npcIDString and tonumber(npcIDString)

    if npcID then
        GUIDToNPCIDCache[guid] = npcID
    end

    return npcID
end

function PSC_ShowWhatsNewPopup(titleText, messageText, onCloseCallback, linkUrl)
    local frame = CreateFrame("Frame", "PSC_WhatsNewPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    frame:SetSize(700, 300)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 11, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.99)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(136, 136)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -20)
    icon:SetTexture("Interface\\AddOns\\PvPStatsClassic\\img\\RedridgePoliceLogo.blp")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 15, 0)
    title:SetText(titleText)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -15)
    text:SetPoint("RIGHT", frame, "RIGHT", -30, 0)
    text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 85)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetText(messageText)

    if linkUrl and linkUrl ~= "" then
        local linkLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        linkLabel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 67, 55)
        linkLabel:SetText("Join our Discord\n(CTRL+C to copy):")

        local linkBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        linkBox:SetSize(490, 22)
        linkBox:SetPoint("LEFT", linkLabel, "RIGHT", 15, 0)
        linkBox:SetAutoFocus(false)
        linkBox:SetText(linkUrl)
        linkBox:SetCursorPosition(0)
        linkBox:SetScript("OnEditFocusGained", function(self)
            self:HighlightText()
        end)
        linkBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        linkBox:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                self:SetText(linkUrl)
                self:HighlightText()
            end
        end)
    end

    local button = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    button:SetSize(120, 25)
    button:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)
    button:SetText("Got it!")
    button:SetScript("OnClick", function()
        frame:Hide()
        if onCloseCallback then
            onCloseCallback()
        end
    end)

    frame:Show()
end

