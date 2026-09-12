local addonName, PVPSC = ...

-- Load AceComm library
local AceComm = LibStub("AceComm-3.0")

PVPSC.Network = PVPSC.Network or {}
local Network = PVPSC.Network

-- Embed AceComm into Network object
AceComm:Embed(Network)

-- Network configuration
local PREFIX = "PVPSC"  -- Single prefix for all messages

-- Shared data cache: stores other players' stats
Network.sharedData = Network.sharedData or {}
Network.ownAltData = Network.ownAltData or {}
Network.lastPlayerStats = nil -- Cache for own stats to avoid recalculation
Network.MIN_BROADCAST_INTERVAL = 15

-- Deduplication cache to prevent processing the same message multiple times
local recentMessages = {}
local RECENT_TTL = 300  -- 5 minutes

local debugNetworkHandler = false


local function DebugPrint(...)
    if PSC_Debug and debugNetworkHandler then
        print("|cFFFFD700[PVPSC Network]|r ", ...)
    end
end

function Network:NormalizeTargetName(targetName)
    if not targetName then
        return nil
    end

    local trimmed = targetName:gsub("^%s+", ""):gsub("%s+$", "")
    trimmed = trimmed:gsub("%s*%-%s*", "-")
    return trimmed
end

-- Generate a unique key for deduplication
local function GetMessageKey(playerName, timestamp)
    return playerName .. "@" .. tostring(timestamp)
end

-- Check if we've recently processed this message
local function IsDuplicate(playerName, timestamp)
    local now = GetServerTime()
    local key = GetMessageKey(playerName, timestamp)

    if recentMessages[key] and recentMessages[key] > now then
        return true
    end

    recentMessages[key] = now + RECENT_TTL
    return false
end

-- Key mapping for compression
local KEY_MAP = {
    summary = "S",
    classData = "CD",
    raceData = "RD",
    genderData = "GD",
    zoneData = "ZD",
    levelData = "LD",
    hourlyData = "H",
    weekdayData = "W",
    monthlyData = "M",
    yearlyData = "Y",
    unknownLevelClassData = "UL",
    deathsByClassData = "DC",
    guildStatusData = "GS",
    npcKillsData = "NK",
    playerName = "pn",
    level = "l",
    class = "c",
    race = "r",
    gender = "ge",
    guild = "g",
    faction = "f",
    timestamp = "t",
    addonVersion = "av",
    achievementsUnlocked = "au",
    totalAchievements = "ta",
    achievementPoints = "ap",
    realm = "re"
}

-- Shared sub-key mappings
local CLASS_KEY_MAP = {
    Warrior = "W", Paladin = "Pa", Hunter = "H", Rogue = "R", Priest = "Pr",
    Shaman = "S", Mage = "M", Warlock = "Wl", Druid = "D"
}

local RACE_KEY_MAP = {
    Human = "Hu", Dwarf = "Dw", ["Night Elf"] = "NE", Gnome = "Gn",
    Orc = "Or", Undead = "Un", Troll = "Tr", Tauren = "Ta"
}

local FACTION_KEY_MAP = {
    Alliance = "A", Horde = "H"
}

local NPC_KEY_MAP = {
    ["Corporal Keeshan"] = "CK",
    ["The Defias Traitor"] = "DT",
    ["Defias Messenger"] = "DM"
}

local ZONE_KEY_MAP = {
    -- Classic Zones (Kalimdor)
    ["Ashenvale"] = "As", ["Azshara"] = "Az", ["Darkshore"] = "DS", ["Darnassus"] = "Da",
    ["Desolace"] = "De", ["Durotar"] = "Du", ["Dustwallow Marsh"] = "DM", ["Felwood"] = "FW",
    ["Feralas"] = "Fe", ["Moonglade"] = "Mg", ["Mulgore"] = "Mu", ["Orgrimmar"] = "Org",
    ["Silithus"] = "Si", ["Stonetalon Mountains"] = "STM", ["Tanaris"] = "Tn", ["Teldrassil"] = "Tel",
    ["The Barrens"] = "Bar", ["Thousand Needles"] = "ThN", ["Thunder Bluff"] = "TB",
    ["Un'Goro Crater"] = "UG", ["Winterspring"] = "Wi",

    -- Classic Zones (Eastern Kingdoms)
    ["Alterac Mountains"] = "AM", ["Arathi Highlands"] = "AH", ["Badlands"] = "Bd",
    ["Blasted Lands"] = "BL", ["Burning Steppes"] = "BS", ["Deadwind Pass"] = "DP",
    ["Dun Morogh"] = "DMo", ["Duskwood"] = "Dk", ["Eastern Plaguelands"] = "EPL",
    ["Elwynn Forest"] = "EF", ["Hillsbrad Foothills"] = "HF", ["Ironforge"] = "IF",
    ["Loch Modan"] = "LM", ["Redridge Mountains"] = "RM", ["Searing Gorge"] = "SG",
    ["Silverpine Forest"] = "SPF", ["Stormwind City"] = "SW", ["Stranglethorn Vale"] = "STV",
    ["Swamp of Sorrows"] = "SoS", ["The Hinterlands"] = "Hi", ["Tirisfal Glades"] = "TG",
    ["Undercity"] = "UC", ["Western Plaguelands"] = "WPL", ["Westfall"] = "Wf", ["Wetlands"] = "Wt",
    ["Blackrock Mountain"] = "BRM",

    -- TBC Zones (Outland)
    ["Blade's Edge Mountains"] = "BEM", ["Hellfire Peninsula"] = "HFP", ["Nagrand"] = "Na",
    ["Netherstorm"] = "NS", ["Shadowmoon Valley"] = "SMV", ["Shattrath City"] = "Sha",
    ["Terokkar Forest"] = "Te", ["Zangarmarsh"] = "Za",

    -- TBC Zones (Azeroth)
    ["Azuremyst Isle"] = "AI", ["Bloodmyst Isle"] = "BI", ["The Exodar"] = "Ex",
    ["Eversong Woods"] = "EW", ["Ghostlands"] = "Gl", ["Silvermoon City"] = "SMC",
    ["Isle of Quel'Danas"] = "IQD",

    -- Battlegrounds
    ["Alterac Valley"] = "AV", ["Arathi Basin"] = "AB", ["Warsong Gulch"] = "WSG",
    ["Eye of the Storm"] = "EotS"
}

-- Mappings for keys inside specific tables (e.g. summary)
local SUB_KEY_MAPS = {
    summary = {
        totalKills = "tk",
        uniqueKills = "uk",
        unknownLevelKills = "ulk",
        totalDeaths = "td",
        kdRatio = "kdr",
        avgLevel = "al",
        avgLevelDiff = "ald",
        avgKillsPerPlayer = "akp",
        mostKilledPlayer = "mkp",
        mostKilledCount = "mkc",
        currentKillStreak = "cks",
        highestKillStreak = "hks",
        highestMultiKill = "hmk",
        highestKillStreakCharacter = "hksc",
        highestMultiKillCharacter = "hmkc",
        doubleKills = "dk",
        tripleKills = "trk",
        quadraKills = "qk",
        pentaKills = "pk",
        hexaPlusKills = "hpk",
        uniqueGuildsKilled = "ugk",
        busiestWeekday = "bw",
        busiestWeekdayKills = "bwk",
        busiestHour = "bh",
        busiestHourKills = "bhk",
        busiestMonth = "bm",
        busiestMonthKills = "bmk",
        avgKillsPerDay = "akpd",
        killsToday = "kt",
        killsThisWeek = "ktw",
        killsThisMonth = "ktm",
        killsThisYear = "kty",
        mostKillsInDay = "mkd",
        mostKillsInWeek = "mkw",
        mostKillsInDayDate = "mkdd",
        mostKillsInWeekDate = "mkwd",
        nemesisName = "nn",
        nemesisScore = "ns",
        mostKilledRace = "mkr",
        mostKilledGender = "mkg",
        mostKilledClass = "mkcl",
        nemesisRace = "nr",
        nemesisGender = "ng",
        nemesisClass = "ncl"
    },
    classData = CLASS_KEY_MAP,
    unknownLevelClassData = CLASS_KEY_MAP,
    deathsByClassData = CLASS_KEY_MAP,
    raceData = RACE_KEY_MAP,
    genderData = {
        MALE = "M", FEMALE = "F"
    },
    guildStatusData = {
        ["In Guild"] = "Y",
        ["No Guild"] = "N"
    },
    npcKillsData = NPC_KEY_MAP,
    zoneData = ZONE_KEY_MAP
}

local REVERSE_KEY_MAP = {}
for k, v in pairs(KEY_MAP) do REVERSE_KEY_MAP[v] = k end

local REVERSE_SUB_KEY_MAPS = {}
for parentKey, subMap in pairs(SUB_KEY_MAPS) do
    REVERSE_SUB_KEY_MAPS[parentKey] = {}
    for k, v in pairs(subMap) do
        REVERSE_SUB_KEY_MAPS[parentKey][v] = k
    end
end

local REVERSE_CLASS_KEY_MAP = {}
for k, v in pairs(CLASS_KEY_MAP) do REVERSE_CLASS_KEY_MAP[v] = k end

local REVERSE_RACE_KEY_MAP = {}
for k, v in pairs(RACE_KEY_MAP) do REVERSE_RACE_KEY_MAP[v] = k end

local REVERSE_FACTION_KEY_MAP = {}
for k, v in pairs(FACTION_KEY_MAP) do REVERSE_FACTION_KEY_MAP[v] = k end

local REVERSE_NPC_KEY_MAP = {}
for k, v in pairs(NPC_KEY_MAP) do REVERSE_NPC_KEY_MAP[v] = k end

local REVERSE_ZONE_KEY_MAP = {}
for k, v in pairs(ZONE_KEY_MAP) do REVERSE_ZONE_KEY_MAP[v] = k end

-- Helper to round numbers for compression (max 2 decimal places)
local function RoundForCompression(num)
    if type(num) ~= "number" then return num end
    -- If it's an integer, return as is
    if num % 1 == 0 then return num end
    -- Round to 2 decimal places
    return math.floor(num * 100 + 0.5) / 100
end

-- Serialize detailed stats with compression
local function SerializeDetailedStats(data)
    -- Simple JSON-like serialization with short keys
    local str = ""
    for k, v in pairs(data) do
        -- Optimization: Skip empty tables
        if type(v) == "table" and next(v) == nil then
            -- skip
        else
            -- Use short key if available, otherwise original
            local key = KEY_MAP[k] or k

            if type(v) == "table" then
                local tableContent = ""
                local subMap = SUB_KEY_MAPS[k] -- using original key k

                for k2, v2 in pairs(v) do
                    -- Optimization: Skip zero values
                    if v2 == 0 then
                        -- continue
                    else
                        local subKey = (subMap and subMap[k2]) or k2
                        local subVal = RoundForCompression(v2)

                        tableContent = tableContent .. tostring(subKey) .. "=" .. tostring(subVal) .. ","
                    end
                end

                -- Only append if the table has content
                if tableContent ~= "" then
                     -- Optimization: Remove trailing comma to save space
                    if string.sub(tableContent, -1) == "," then
                        tableContent = string.sub(tableContent, 1, -2)
                    end
                    str = str .. key .. ":" .. tableContent .. ";"
                end
            else
                local val = v
                -- Apply top-level value compression
                if k == "class" and CLASS_KEY_MAP[v] then val = CLASS_KEY_MAP[v] end
                if k == "race" and RACE_KEY_MAP[v] then val = RACE_KEY_MAP[v] end
                if k == "faction" and FACTION_KEY_MAP[v] then val = FACTION_KEY_MAP[v] end

                -- Round top-level numbers (like timestamp)
                val = RoundForCompression(val)

                str = str .. key .. ":" .. tostring(val) .. ";"
            end
        end
    end
    -- Append EOM marker
    str = str .. "EOM:1;"
    return str
end

-- Deserialize detailed stats
local function DeserializeDetailedStats(payload)
    -- Check for EOM marker to ensure message is complete
    if not string.find(payload, "EOM:1") then
        if PSC_Debug then
            DebugPrint("Incomplete payload received (EOM missing). Discarding.")
        end
        return nil
    end

    -- Parse the serialized format back into a table
    local data = {
        monthlyData = {},
        weekdayData = {},
        hourlyData = {},
        yearlyData = {},
        classData = {},
        raceData = {},
        genderData = {},
        zoneData = {},
        levelData = {},
        npcKillsData = {},
        guildStatusData = {},
        unknownLevelClassData = {},
        deathsByClassData = {}
    }

    -- Initialize class charts with 0 to prevent missing chart data
    for class, _ in pairs(CLASS_KEY_MAP) do
        data.classData[class] = 0
        data.unknownLevelClassData[class] = 0
        data.deathsByClassData[class] = 0
    end

    for field in string.gmatch(payload, "([^;]+)") do
        local keyStr, values = string.match(field, "([^:]+):(.*)")
        if keyStr and values then
            -- Restore original long key if it was compressed
            local originalKey = REVERSE_KEY_MAP[keyStr] or keyStr

            if string.find(values, "=") then
                -- It's a table
                -- If we haven't initialized this key yet (e.g. unexpected key), create it
                if not data[originalKey] then data[originalKey] = {} end

                local subMapReverse = REVERSE_SUB_KEY_MAPS[originalKey]

                for pair in string.gmatch(values, "([^,]+)") do
                    local k, v = string.match(pair, "([^=]+)=([^=]+)")
                    if k and v then
                         -- Restore sub key if compressed
                        local originalSubKey = (subMapReverse and subMapReverse[k]) or k

                        -- Enforce numeric keys for time-based statistics and level
                        if originalKey == "monthlyData" or originalKey == "weekdayData" or originalKey == "hourlyData" or originalKey == "yearlyData" then
                            local nKey = tonumber(originalSubKey)
                            if nKey then originalSubKey = nKey end
                        elseif originalKey == "levelData" and originalSubKey ~= "??" then
                            local nKey = tonumber(originalSubKey)
                            if nKey then originalSubKey = nKey end
                        end

                        -- Try to convert to number
                        local num = tonumber(v)
                        data[originalKey][originalSubKey] = num or v
                    end
                end
            else
                -- Simple value
                local val = values
                -- Restore top-level value compression
                if originalKey == "class" and REVERSE_CLASS_KEY_MAP[val] then val = REVERSE_CLASS_KEY_MAP[val] end
                if originalKey == "race" and REVERSE_RACE_KEY_MAP[val] then val = REVERSE_RACE_KEY_MAP[val] end
                if originalKey == "faction" and REVERSE_FACTION_KEY_MAP[val] then val = REVERSE_FACTION_KEY_MAP[val] end

                local num = tonumber(val)
                -- If it's a number, it's a number. If it looked like a number but was actually a compressed string (unlikely for top level except values), we keep string
                -- For top level fields like "class", it is a string. "W" -> "Warrior". tonumber will fail.
                data[originalKey] = num or val
            end
        end
    end
    return data
end

-- Check if the network is currently throttled (BULK queue has pending messages)
function Network:IsThrottled()
    -- ChatThrottleLib is used by AceComm
    if ChatThrottleLib and ChatThrottleLib.Prio and ChatThrottleLib.Prio["BULK"] and ChatThrottleLib.Prio["BULK"].Ring then
        -- If Ring.pos is not nil, there are items in the ring (queue not empty)
        if ChatThrottleLib.Prio["BULK"].Ring.pos then
            return true
        end
    end
    return false
end

-- Wrapper for SendCommMessage with debug output
function Network:SendCommMessageWithDebug(prefix, payload, channel, target, priority)
    if PSC_Debug then
        local msgPreview = payload
        if #msgPreview > 120 then
            msgPreview = msgPreview:sub(1, 120) .. "..." -- Truncate for readability
        end
        DebugPrint("Sending message to ", channel, "(size:", #payload, "bytes):", msgPreview)
    end
    self:SendCommMessage(prefix, payload, channel, target, priority)
end

local function HasKnownProfile(info)
    return info and ((info.race and info.race ~= "") or (info.gender and info.gender ~= "") or (info.class and info.class ~= ""))
end

local function GetProfileValueOrUnknown(info, field)
    local value = info and info[field]
    if value and value ~= "" then
        return value
    end
    return "Unknown"
end

function Network:ApplyPlayerProfile(summaryTable, nameField, raceField, genderField, classField, charactersToProcess)
    local playerName = summaryTable and summaryTable[nameField]
    if not playerName or playerName == "" or playerName == "None" then
        return
    end

    local playerInfo = PSC_GetPlayerInfo(playerName)

    if not HasKnownProfile(playerInfo) and string.find(playerName, "%-") then
        local shortName = playerName:match("^([^-]+)")
        if shortName and shortName ~= "" then
            local shortInfo = PSC_GetPlayerInfo(shortName)
            if HasKnownProfile(shortInfo) then
                playerInfo = shortInfo
            end
        end
    end

    if not HasKnownProfile(playerInfo) and charactersToProcess then
        for _, characterData in pairs(charactersToProcess) do
            if characterData and characterData.Kills then
                for nameWithLevel, killData in pairs(characterData.Kills) do
                    local killName = nameWithLevel:match("([^:]+)") or nameWithLevel
                    if PSC_IsSamePlayerName(killName, playerName) then
                        playerInfo = {
                            race = killData.race,
                            gender = killData.gender,
                            class = killData.class
                        }
                        break
                    end
                end
            end
            if HasKnownProfile(playerInfo) then
                break
            end
        end
    end

    summaryTable[raceField] = GetProfileValueOrUnknown(playerInfo, "race")
    summaryTable[genderField] = GetProfileValueOrUnknown(playerInfo, "gender")
    summaryTable[classField] = GetProfileValueOrUnknown(playerInfo, "class")
end

local function FlattenSummaryForLeaderboard(statsData)
    if not statsData or not statsData.summary then
        return
    end

    statsData.totalKills = statsData.summary.totalKills
    statsData.uniqueKills = statsData.summary.uniqueKills
    statsData.totalDeaths = statsData.summary.totalDeaths
    statsData.kdRatio = statsData.summary.kdRatio
    statsData.currentKillStreak = statsData.summary.currentKillStreak
    statsData.highestKillStreak = statsData.summary.highestKillStreak
    statsData.mostKilledPlayer = statsData.summary.mostKilledPlayer
    statsData.mostKilledCount = statsData.summary.mostKilledCount
    statsData.avgKillsPerDay = statsData.summary.avgKillsPerDay
end

local function ParseCharacterKey(characterKey)
    if not characterKey then
        return nil, nil
    end

    local name, realm = characterKey:match("^(.+)%-(.+)$")
    if name and realm then
        return name, realm
    end

    return characterKey, PSC_RealmName
end

local function GetCharacterLastActivityTimestamp(characterKey, characterData)
    local lastSeen = 0

    if characterData and characterData.Kills then
        for _, killEntry in pairs(characterData.Kills) do
            local ts = tonumber(killEntry and killEntry.lastKill) or 0
            if ts > lastSeen then
                lastSeen = ts
            end
        end
    end

    if PSC_DB and PSC_DB.PvPLossCounts and PSC_DB.PvPLossCounts[characterKey] and PSC_DB.PvPLossCounts[characterKey].Deaths then
        for _, deathEntry in pairs(PSC_DB.PvPLossCounts[characterKey].Deaths) do
            local ts = tonumber(deathEntry and deathEntry.lastDeath) or 0
            if ts > lastSeen then
                lastSeen = ts
            end
        end
    end

    if lastSeen <= 0 then
        lastSeen = GetServerTime()
    end

    return lastSeen
end

local function GetCharacterAchievementStats(characterKey)
    local unlockedCount = 0
    local points = 0

    if PSC_DB and PSC_DB.CharacterAchievements and PSC_DB.CharacterAchievements[characterKey] then
        for _, achievementData in pairs(PSC_DB.CharacterAchievements[characterKey]) do
            if achievementData and achievementData.unlocked then
                unlockedCount = unlockedCount + 1
                points = points + (tonumber(achievementData.points) or 0)
            end
        end
    end

    if PSC_DB and PSC_DB.CharacterAchievementPoints and PSC_DB.CharacterAchievementPoints[characterKey] ~= nil then
        points = tonumber(PSC_DB.CharacterAchievementPoints[characterKey]) or points
    end

    return unlockedCount, points
end

local function BuildDetailedStatsFromCharacters(self, charactersToProcess, enableDebugLog)
    local stats = PSC_CalculateSummaryStatistics(charactersToProcess)
    self:ApplyPlayerProfile(stats, "mostKilledPlayer", "mostKilledRace", "mostKilledGender", "mostKilledClass", charactersToProcess)
    self:ApplyPlayerProfile(stats, "nemesisName", "nemesisRace", "nemesisGender", "nemesisClass", charactersToProcess)

    local classData, raceData, genderData, unknownLevelClassData, zoneData, levelData, guildStatusData, guildData, npcKillsData =
        PSC_CalculateBarChartStatistics(charactersToProcess)
    local _, uniqueGuildsKilled = PSC_CalculateGuildStats(guildData)
    stats.uniqueGuildsKilled = uniqueGuildsKilled
    local hourlyData = PSC_CalculateHourlyStatistics(charactersToProcess)
    local weekdayData = PSC_CalculateWeekdayStatistics(charactersToProcess)
    local monthlyData = PSC_CalculateMonthlyStatistics(charactersToProcess)
    local yearlyData = PSC_CalculateYearlyStatistics(charactersToProcess)
    local deathsByClassData = PSC_CalculateDeathsByClass(charactersToProcess)

    if enableDebugLog then
        DebugPrint("Building detailed stats - currentKillStreak:", stats.currentKillStreak, "mostKilledPlayer:", stats.mostKilledPlayer)
    end

    local result = self:ConstructPayload({
        summary = stats,
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
        -- Note: guildData intentionally excluded to reduce payload size
    })

    FlattenSummaryForLeaderboard(result)
    return result
end

function Network:BuildDetailedStatsForCharacter(characterKey, characterData)
    if not characterKey or not characterData then
        return nil
    end

    local charactersToProcess = {}
    charactersToProcess[characterKey] = characterData

    local result = BuildDetailedStatsFromCharacters(self, charactersToProcess, false)

    local charName, charRealm = ParseCharacterKey(characterKey)
    local infoKey = PSC_GetPlayerInfoKey(charName, charRealm)
    local charInfo = PSC_DB and PSC_DB.PlayerInfoCache and PSC_DB.PlayerInfoCache[infoKey]

    -- Only include alts that have logged in at least once since PlayerInfoCache tracking for own alts was added.
    if not charInfo then
        return nil
    end

    result.playerName = charName or result.playerName
    result.realm = charRealm or result.realm
    result.timestamp = GetCharacterLastActivityTimestamp(characterKey, characterData)
    result.addonVersion = PSC_GetAddonVersion()

    result.level = tonumber(charInfo.level) or result.level or 0
    result.class = charInfo.class or result.class or "Unknown"
    result.race = charInfo.race or result.race or "Unknown"
    result.gender = charInfo.gender or result.gender or "Unknown"
    result.guild = charInfo.guild or result.guild or ""

    local unlockedCount, achievementPoints = GetCharacterAchievementStats(characterKey)
    result.achievementsUnlocked = unlockedCount
    result.achievementPoints = achievementPoints

    result.isOwnAlt = true
    return result
end

function Network:BuildOwnAltStatsCache()
    self.ownAltData = {}

    if not PSC_DB or not PSC_DB.PlayerKillCounts or not PSC_DB.PlayerKillCounts.Characters then
        return
    end

    local currentCharacterKey = PSC_GetCharacterKey()

    for characterKey, characterData in pairs(PSC_DB.PlayerKillCounts.Characters) do
        if characterKey ~= currentCharacterKey and characterData then
            local altStats = self:BuildDetailedStatsForCharacter(characterKey, characterData)
            if altStats and altStats.playerName and altStats.realm then
                local uniqueName = altStats.playerName
                if not string.find(uniqueName, "%-") then
                    uniqueName = uniqueName .. "-" .. altStats.realm
                end
                altStats.playerName = uniqueName
                self.ownAltData[uniqueName] = altStats
            end
        end
    end
end

-- Build detailed statistics for a player (all kill data)
function Network:BuildDetailedStats()
    if self.lastPlayerStats then
        if PSC_Debug then
            -- D() is local, but print is fine
            DebugPrint("Using cached player stats.")
        end
        return self.lastPlayerStats
    end

    -- Explicitly only broadcast current character stats regardless of account-wide setting
    local charactersToProcess = {}
    local currentCharacterKey = PSC_GetCharacterKey()
    if PSC_DB and PSC_DB.PlayerKillCounts and PSC_DB.PlayerKillCounts.Characters then
        charactersToProcess[currentCharacterKey] = PSC_DB.PlayerKillCounts.Characters[currentCharacterKey]
    end

    local result = BuildDetailedStatsFromCharacters(self, charactersToProcess, true)

    self.lastPlayerStats = result
    return result
end

-- Build the serialized payload for full stats
function Network:BuildFullPayload()
    local detailedStats = self.lastPlayerStats or self:BuildDetailedStats()

    -- Update timestamp to avoid stale data when reusing cached stats
    detailedStats.timestamp = GetServerTime()

    local payload = SerializeDetailedStats(detailedStats)
    return "FULL|" .. payload
end

-- Constructs the standardized broadcast payload from component stats
function Network:ConstructPayload(components)
    local totalAchievements = 0
    if PVPSC.AchievementSystem and PVPSC.AchievementSystem.achievements then
        totalAchievements = #PVPSC.AchievementSystem.achievements
    end

    return {
        summary = components.summary,
        classData = components.classData,
        raceData = components.raceData,
        genderData = components.genderData,
        zoneData = components.zoneData,
        levelData = components.levelData,
        hourlyData = components.hourlyData,
        weekdayData = components.weekdayData,
        monthlyData = components.monthlyData,
        yearlyData = components.yearlyData,
        unknownLevelClassData = components.unknownLevelClassData,
        deathsByClassData = components.deathsByClassData,
        guildStatusData = components.guildStatusData,
        npcKillsData = components.npcKillsData,

        playerName = UnitName("player"),
        level = UnitLevel("player"),
        class = PSC_ConvertClassToEnglish(UnitClass("player")),
        race = PSC_ConvertRaceToEnglish(UnitRace("player")),
        gender = PSC_ConvertGenderToString(UnitSex("player")),
        guild = GetGuildInfo("player") or "",
        faction = UnitFactionGroup("player") or "",
        timestamp = GetServerTime(),
        realm = PSC_RealmName,
        -- Optimization: Send version without "v" prefix
        addonVersion = PSC_GetAddonVersion(),
        achievementsUnlocked = PSC_GetUnlockedAchievementCount(),
        totalAchievements = totalAchievements,
        achievementPoints = PSC_GetCurrentAchievementPoints()
        }
end

-- Determine the list of channels to broadcast to
function Network:GetBroadcastChannels()
    local distributionList = {}

    if PSC_CurrentlyInBattleground then
        table.insert(distributionList, "INSTANCE_CHAT")
    elseif IsInRaid() then
        table.insert(distributionList, "RAID")
    elseif IsInGroup() then
        table.insert(distributionList, "PARTY")
    end

    if IsInGuild() then
        table.insert(distributionList, "GUILD")
    end

    -- Always yell to share with others nearby
    table.insert(distributionList, "YELL")

    return distributionList
end

-- Broadcast player stats
function Network:BroadcastStats(providedStats)
    -- Cache provided stats for future use
    if providedStats then
        self.lastPlayerStats = providedStats
    end

    -- Defer broadcasts while in combat to avoid spamming message limits
    if PSC_InCombat then
        self.pendingCombatBroadcast = true
        if PSC_Debug then
            DebugPrint("In combat - deferring broadcast until out of combat.")
        end
        return
    end

    if self.pendingCombatBroadcast then
        self.pendingCombatBroadcast = nil
    end

    local now = GetTime()

    -- Check if we are broadcasting too frequently (time-based throttling)
    if self.lastBroadcastTime and (now - self.lastBroadcastTime < self.MIN_BROADCAST_INTERVAL) then
        -- We are too early. Queue a Deferred broadcast if one isn't already scheduled.
        if not self.deferredBroadcastTimer then
            local delay = self.MIN_BROADCAST_INTERVAL - (now - self.lastBroadcastTime)
            -- Ensure delay is positive and reasonable
            if delay < 0.1 then delay = 0.1 end

            if PSC_Debug then
                DebugPrint("Too many updates. Deferring broadcast by " .. string.format("%.1f", delay) .. "s")
            end

            self.deferredBroadcastTimer = C_Timer.NewTimer(delay, function()
                self.deferredBroadcastTimer = nil
                -- Execute broadcast with latest cached stats
                self:BroadcastStats(nil)
            end)
        end
        return
    end

    -- If we are throttled by the game client/library (bandwidth limit), defer this update
    if self:IsThrottled() then
        if PSC_Debug then
            DebugPrint("Network throttled (BULK queue full), deferring broadcast...")
        end

        -- Schedule a retry if not already scheduled
        if not self.retryTimer then
            self.retryTimer = C_Timer.NewTimer(2.0, function()
                self.retryTimer = nil
                self:BroadcastStats(nil)
            end)
        end
        return
    end

    self.lastBroadcastTime = now

    local payload = self:BuildFullPayload()

    -- Priority BULK for large data
    local priority = "BULK"

    -- Collect channels to send to
    local distributionList = self:GetBroadcastChannels()

    if PSC_Debug then
        local payloadSize = #payload
        local channelCount = #distributionList
        DebugPrint(string.format("Stats Size: %dB x %d chans. Interval: %.1fs",
            payloadSize, channelCount, self.MIN_BROADCAST_INTERVAL))
    end

    -- Send with slight staggering to avoid immediate throttling
    -- Increased stagger to reduce message bursts across channels
    local STAGGER_DELAY = 6.0
    for i, channel in ipairs(distributionList) do
        local delay = (i - 1) * STAGGER_DELAY
        if delay == 0 then
            self:SendCommMessageWithDebug(PREFIX, payload, channel, nil, priority)
        else
            C_Timer.After(delay, function()
                self:SendCommMessageWithDebug(PREFIX, payload, channel, nil, priority)
            end)
        end
    end

    -- Refresh local leaderboard if open (since we updated our own stats which triggered this broadcast)
    if RefreshLeaderboardFrame and PSC_LeaderboardFrame and PSC_LeaderboardFrame:IsShown() then
        RefreshLeaderboardFrame()
    end
end

function Network:SendStatsToPlayer(targetName)
    local normalized = self:NormalizeTargetName(targetName)
    if not normalized or normalized == "" then
        return false, "invalid", "Please enter a player name."
    end

    local payload = self:BuildFullPayload()
    self:SendCommMessageWithDebug(PREFIX, payload, "WHISPER", normalized, "BULK")

    return true
end

-- Validate and Clean Leaderboard Cache (Run once on startup)
function Network:ValidateLeaderboardCache()
    if not PSC_DB.LeaderboardCache then return end

    local fixedCount = 0
    for playerName, entry in pairs(PSC_DB.LeaderboardCache) do
        local changed = false

        -- Ensure structural integrity
        if not entry.hourlyData then entry.hourlyData = {}; changed = true end
        if not entry.weekdayData then entry.weekdayData = {}; changed = true end
        if not entry.monthlyData then entry.monthlyData = {}; changed = true end
        if not entry.yearlyData then entry.yearlyData = {}; changed = true end

        -- Helper to sanitize a specific table
        local function SanitizeTable(tbl)
            local sanitized = {}
            local tableChanged = false
            for k, v in pairs(tbl) do
                local nKey = tonumber(k)
                if not nKey then
                    -- Try to recover known string keys (e.g. "January" -> 1)
                    -- For now, just simplistic tonumber check as our display logic handles the hard normalization
                    -- But we want to store it as number if possible
                    tableChanged = true
                 else
                    sanitized[nKey] = v
                 end
            end
            -- If we found bad keys, replace content with sanitized version (skipping garbage)
            -- Note: This is aggressive. If keys are "January", tonumber fails, and they are dropped.
            -- Using StatisticsFrame logic to recover them would be better, but strict numeric enforcement is safer for DB.
            if tableChanged then
                return sanitized, true
            end
            return tbl, false
        end

        -- We only strictly sanitize time-based tables where we KNOW keys must be numbers
        local hData, hChanged = SanitizeTable(entry.hourlyData)
        if hChanged then entry.hourlyData = hData; changed = true end

        local yData, yChanged = SanitizeTable(entry.yearlyData)
        if yChanged then entry.yearlyData = yData; changed = true end

        if changed then fixedCount = fixedCount + 1 end
    end

    if fixedCount > 0 and PSC_Debug then
        DebugPrint("Fixed " .. fixedCount .. " corrupted cache entries.")
    end
end

-- Update the persistent leaderboard cache with new stats
function Network:UpdateLeaderboardCache(statsData)
    if not PSC_DB.LeaderboardCache then return end
    if not statsData or not statsData.playerName then return end

    -- Create a summary entry (strip detailed lists to save space)
    local entry = {
        playerName = statsData.playerName,
        realm = statsData.realm,
        class = statsData.class,
        race = statsData.race,
        level = statsData.level,
        faction = statsData.faction,
        guild = statsData.guild,
        timestamp = statsData.timestamp,
        addonVersion = statsData.addonVersion,

        -- Flattened stats
        totalKills = statsData.totalKills,
        totalDeaths = statsData.totalDeaths,
        uniqueKills = statsData.uniqueKills,
        kdRatio = statsData.kdRatio,
        currentKillStreak = statsData.currentKillStreak,
        highestKillStreak = statsData.highestKillStreak,
        mostKilledPlayer = statsData.mostKilledPlayer,
        mostKilledCount = statsData.mostKilledCount,
        mostKilledRace = statsData.mostKilledRace,
        mostKilledGender = statsData.mostKilledGender,
        mostKilledClass = statsData.mostKilledClass,
        nemesisName = statsData.nemesisName,
        nemesisScore = statsData.nemesisScore,
        nemesisRace = statsData.nemesisRace,
        nemesisGender = statsData.nemesisGender,
        nemesisClass = statsData.nemesisClass,
        avgKillsPerDay = statsData.avgKillsPerDay,

        achievementsUnlocked = statsData.achievementsUnlocked,
        totalAchievements = statsData.totalAchievements,
        achievementPoints = statsData.achievementPoints,

        -- Store detailed time-based stats for detailed view
        -- Note: We now store them in cache to persist detailed view for offline players
        hourlyData = statsData.hourlyData or {},
        weekdayData = statsData.weekdayData or {},
        monthlyData = statsData.monthlyData or {},
        yearlyData = statsData.yearlyData or {},

        -- Also store generic chart data to ensure diagrams work
        classData = statsData.classData or {},
        raceData = statsData.raceData or {},
        genderData = statsData.genderData or {},
        levelData = statsData.levelData or {},
        zoneData = statsData.zoneData or {},
        npcKillsData = statsData.npcKillsData or {},
        deathsByClassData = statsData.deathsByClassData or {}
    }

    PSC_DB.LeaderboardCache[statsData.playerName] = entry
end

-- Handle received communications
function Network:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= PREFIX then return end

    -- Parse sender to handle cross-realm names (Name-Realm)
    -- If sender is just "Name", it means they are on our realm.
    local senderName, senderRealm = strsplit("-", sender)
    if not senderRealm then
        senderName = sender
        senderRealm = PSC_RealmName -- Default to our realm
    end

    -- Ignore messages from ourselves (even if sent across channels like YELL/GUILD)
    if senderName == UnitName("player") and senderRealm == PSC_RealmName then return end

    if PSC_Debug and debugNetworkHandler then
        print("|cFFFFD700[PVPSC RX]|r From:", sender, "Len:", #message)
        print(message)
    end

    local msgType, data = message:match("^([^|]+)|(.*)$")

    -- Handle different message types
    if msgType == "FULL" then
        -- New Full Stats broadcast
        local statsData = DeserializeDetailedStats(data)

        if not statsData then
            DebugPrint("Failed to deserialize message (" .. msgType .. ") from", sender)
            return
        end

        -- Flatten summary for backward compatibility with leaderboard code
        -- The leaderboard expects fields like 'totalKills' at the root
        if statsData.summary then
            for k, v in pairs(statsData.summary) do
                statsData[k] = v
            end
        end

        -- Validate data
        if not statsData.playerName or statsData.playerName == "" then
            DebugPrint("Invalid data: missing player name")
            return
        end

        -- Ensure realm is set (backward compatibility for older clients not sending realm)
        if not statsData.realm then
            statsData.realm = senderRealm
        end

        if statsData.addonVersion and PSC_IsAddonVersionNewer(statsData.addonVersion) then
            PSC_ShowAddonUpdatePopup(statsData.addonVersion)
        end

        -- Construct unique identifier (Name-Realm)
        -- We modify the playerName in the stored data to be unique if it's from another realm
        -- This ensures the leaderboard treats "Player-Realm1" and "Player-Realm2" as different entries
        local uniqueName = statsData.playerName

        if statsData.realm and statsData.realm ~= PSC_RealmName then
             uniqueName = statsData.playerName .. "-" .. statsData.realm
             -- Update display name to show realm for clarity
             statsData.playerName = uniqueName
        end

        -- Check for duplicates (using unique key)
        if IsDuplicate(uniqueName, statsData.timestamp) then
            DebugPrint("Duplicate message from", uniqueName)
            return
        end

        -- Update caches
        self.sharedData[uniqueName] = statsData
        self:UpdateLeaderboardCache(statsData)

        if distribution == "WHISPER" then
            PSC_Print("[PvPStats]: " .. uniqueName .. " sent you their stats, open the Leaderboard to view them.")
        end

        DebugPrint("Received detailed stats from", uniqueName, "via", distribution, "- Kills:", statsData.totalKills)

        -- Refresh leaderboard if it's open
        if PSC_LeaderboardFrame and PSC_LeaderboardFrame:IsShown() then
            RefreshLeaderboardFrame()
        end

    elseif msgType == "SYNC" then
        -- Sync request - broadcast our stats immediately
        DebugPrint("Received sync request from", sender, "via", distribution)

        -- Prevent multiple responses to the same sync event (e.g. receiving via GUILD and PARTY)
        if self.syncResponsePending then
            DebugPrint("Ignoring duplicate SYNC request from", sender, "via", distribution, "- response already pending")
            return
        end

        self.syncResponsePending = true

        -- Broadcast after a short random delay to avoid network spam if many players respond at once
        C_Timer.After(math.random() * 2, function()
            self.syncResponsePending = false
            self:BroadcastStats()
        end)
    end
end

-- Get cached detailed stats for a player
function Network:GetDetailedStatsForPlayer(playerName)
    if self.sharedData and self.sharedData[playerName] then
        return self.sharedData[playerName]
    end
    if self.ownAltData and self.ownAltData[playerName] then
        return self.ownAltData[playerName]
    end
    return nil
end

-- Get all leaderboard data (local + shared + cache)
function Network:GetAllLeaderboardData(includeOwnAlts)
    local leaderboardData = {}
    local playerName = UnitName("player")
    local localRealm = PSC_RealmName
    local addedPlayers = {}

    local function MarkAdded(name)
        if name and name ~= "" then
            addedPlayers[name] = true
        end
    end

    local function IsAdded(name)
        return name and addedPlayers[name] or false
    end

    -- Add local player's data first
    local localStats = self:BuildDetailedStats()
    if localStats then
        table.insert(leaderboardData, localStats)
        MarkAdded(playerName)
        if localRealm and localRealm ~= "" then
            MarkAdded(playerName .. "-" .. localRealm)
        end
    end

    -- Add own alt data from local DB
    if includeOwnAlts and self.ownAltData then
        if next(self.ownAltData) == nil then
            self:BuildOwnAltStatsCache()
        end
        for name, data in pairs(self.ownAltData) do
            if not IsAdded(name) then
                table.insert(leaderboardData, data)
                MarkAdded(name)
            end
        end
    end

    -- Add other players' data
    for name, data in pairs(self.sharedData) do
        if not IsAdded(name) and name ~= playerName then
            table.insert(leaderboardData, data)
            MarkAdded(name)
        end
    end

    -- Add persistent cache data for offline players
    if PSC_DB.LeaderboardCache then
        for name, data in pairs(PSC_DB.LeaderboardCache) do
            if name ~= playerName and not IsAdded(name) then
                table.insert(leaderboardData, data)
                MarkAdded(name)
            end
        end
    end

    return leaderboardData
end

-- Clean up message deduplication cache periodically
function Network:CleanupDeduplicationCache()
    local now = GetServerTime()

    -- Cleanup duplicate message cache
    local removedDuplicates = 0
    for k, expireTime in pairs(recentMessages) do
        if expireTime <= now then
            recentMessages[k] = nil
            removedDuplicates = removedDuplicates + 1
        end
    end

    if removedDuplicates > 0 then
        DebugPrint("Cleaned up", removedDuplicates, "expired entries from duplicate cache")
    end
end

-- Initialize network handler
function Network:Initialize()
    -- Validate cache on startup to fix any corrupted data from previous versions
    self:ValidateLeaderboardCache()
    self:BuildOwnAltStatsCache()

    -- Register AceComm prefix and callback
    self:RegisterComm(PREFIX, "OnCommReceived")

    -- Periodic broadcast ticker removed in favor of event-based updates

    -- Set up cleanup ticker (every 5 minutes)
    C_Timer.NewTicker(300, function()
        Network:CleanupDeduplicationCache()
    end)

    -- Send sync request and immediate broadcast on login
    C_Timer.After(2, function()
        -- Request all other players to broadcast their stats
        local syncRequest = "SYNC|" .. UnitName("player")

        -- Use centralized channel list
        local distributionList = self:GetBroadcastChannels()

        -- Send with staggering to avoid immediate throttling
        local SYNC_STAGGER = 0.5
        for i, channel in ipairs(distributionList) do
            local delay = (i - 1) * SYNC_STAGGER
            if delay == 0 then
                self:SendCommMessageWithDebug(PREFIX, syncRequest, channel, nil, "NORMAL")
            else
                C_Timer.After(delay, function()
                    self:SendCommMessageWithDebug(PREFIX, syncRequest, channel, nil, "NORMAL")
                end)
            end
        end

        -- Also broadcast our own stats immediately
        -- Wait for sync requests to finish to avoid bandwidth congestion
        local initialBroadcastDelay = #distributionList * SYNC_STAGGER + 1.0
        C_Timer.After(initialBroadcastDelay, function()
            Network:BroadcastStats()
            DebugPrint("Sent initial broadcast on login")
        end)

        self.initialized = true
    end)
end
