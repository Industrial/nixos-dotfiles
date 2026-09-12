local addonName, PVPSC = ...

PSC_RecentPlayerDamage = {}
PSC_ASSIST_DAMAGE_WINDOW = 60.0  -- 45 second window for kill assist credit

-- An enemy can die and be resurrected (e.g. Soulstone) within the same assist window; without this,
-- a leftover/incidental action recorded against their GUID could credit a second assist for a kill
-- the player did nothing for. Requires a fresh qualifying action after each assist is credited.
PSC_LastAssistCreditTime = {}

PSC_RecentlyCountedKills = {}
PSC_KILL_TRACKING_WINDOW = 2.0

PSC_MultiKillCount = 0

-- Shared guard so the same kill can't be registered twice by different detection paths
-- (combat log PARTY_KILL/UNIT_DIED vs. the Eyes of the Beast out-of-range watcher)
function PSC_WasKillRecentlyCounted(destGUID)
    local countedAt = PSC_RecentlyCountedKills[destGUID]
    return countedAt ~= nil and (GetTime() - countedAt) < PSC_KILL_TRACKING_WINDOW
end

function PSC_CleanupLastAssistCreditTimes()
    local cutoff = GetTime() - PSC_ASSIST_DAMAGE_WINDOW
    for guid, timestamp in pairs(PSC_LastAssistCreditTime) do
        if timestamp < cutoff then
            PSC_LastAssistCreditTime[guid] = nil
        end
    end
end

-- Helper function to update spawn camper max kills after a new level 1 kill
local function UpdateSpawnCamperCounter(newKillTimestamp)
    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]

    -- Add the new timestamp to the cached list
    table.insert(characterData.Level1KillTimestamps, newKillTimestamp)

    -- Get the timestamp list (already sorted by insertion order since timestamps are chronological)
    local timestamps = characterData.Level1KillTimestamps
    local numTimestamps = #timestamps

    if numTimestamps == 0 then return end

    -- Optimization: Only check the sliding window around recent timestamps
    -- Start from the end and work backwards since the new kill is most likely to create a new max
    local maxKillsInWindow = characterData.SpawnCamperMaxKills or 0
    local windowStart = math.max(1, numTimestamps - 100) -- Only check last 100 kills for efficiency

    local left = windowStart
    for right = windowStart, numTimestamps do
        -- Move left pointer forward while window exceeds 60 seconds
        while left < right and timestamps[right] - timestamps[left] > 60 do
            left = left + 1
        end
        local count = right - left + 1
        if count > maxKillsInWindow then
            maxKillsInWindow = count
        end
    end

    characterData.SpawnCamperMaxKills = maxKillsInWindow

    -- Cleanup: Remove very old timestamps (older than 1 hour) to prevent unbounded growth
    local cutoffTime = newKillTimestamp - 3600
    local firstValidIndex = 1
    for i = 1, numTimestamps do
        if timestamps[i] >= cutoffTime then
            firstValidIndex = i
            break
        end
    end

    -- If we found old timestamps to remove, create a new array without them
    if firstValidIndex > 1 then
        local newTimestamps = {}
        for i = firstValidIndex, numTimestamps do
            table.insert(newTimestamps, timestamps[i])
        end
        characterData.Level1KillTimestamps = newTimestamps
    end
end

local function InitializeKillCountEntryForPlayer(nameWithLevel, playerLevel)
    local characterKey = PSC_GetCharacterKey()

    if not PSC_DB.PlayerKillCounts.Characters[characterKey].Kills[nameWithLevel] then
        PSC_DB.PlayerKillCounts.Characters[characterKey].Kills[nameWithLevel] = {
            kills = 0,
            lastKill = 0,
            killLocations = {},
            rank = 0
            -- Removed playerLevel and zone, will be stored only in killLocations
        }
    end
end

local function UpdateKillCountEntry(nameWithLevel, playerLevel)
    local characterKey = PSC_GetCharacterKey()
    local killData = PSC_DB.PlayerKillCounts.Characters[characterKey].Kills[nameWithLevel]

    killData.kills = killData.kills + 1
    killData.lastKill = time()

    local currentZone = PSC_GetCurrentZoneName()

    local newKillLocation = {
        zone = currentZone,
        timestamp = killData.lastKill,
        killNumber = killData.kills,
        playerLevel = playerLevel
    }

    newKillLocation.x, newKillLocation.y = PSC_GetPlayerCoordinates()

    table.insert(killData.killLocations, newKillLocation)
end

-- Records the highest multi-kill reached in the current combat; call right before PSC_MultiKillCount resets to 0
function PSC_FinalizeMultiKillTally()
    if PSC_MultiKillCount < 2 then return end

    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]
    if not characterData then return end

    characterData.MultiKillCounts = characterData.MultiKillCounts or {}
    -- Bucket 6 represents "Hexa or higher" (multi-kills of 6+ are not split further)
    local finalMultiKillCount = math.min(PSC_MultiKillCount, 6)
    characterData.MultiKillCounts[finalMultiKillCount] = (characterData.MultiKillCounts[finalMultiKillCount] or 0) + 1
end

local function UpdateMultiKill()
    if not PSC_InCombat then
        PSC_FinalizeMultiKillTally()
        PSC_MultiKillCount = 0
        return
    end

    PSC_MultiKillCount = PSC_MultiKillCount + 1

    -- Play single kill sound for first kill if enabled and not playing multi-kill sounds
    if PSC_MultiKillCount == 1 and PSC_DB.EnableSingleKillSounds then
        local soundFile
        local soundPack = PSC_DB.SoundPack or "LoL"

        if soundPack == "LoL" then
            local lolSounds = {"an_enemy_has_been_slain.mp3", "first_blood.mp3", "shut-down.mp3", "dominating.mp3"}
            local randomIndex = math.random(1, #lolSounds)
            soundFile = "Interface\\AddOns\\PvPStatsClassic\\sounds\\LoL\\" .. lolSounds[randomIndex]
        else
            local utSounds = {"first-blood.mp3", "head-hunter.mp3", "dominating.mp3"}
            local randomIndex = math.random(1, #utSounds)
            soundFile = "Interface\\AddOns\\PvPStatsClassic\\sounds\\UT\\" .. utSounds[randomIndex]
        end

        if soundFile then
            PlaySoundFile(soundFile, "Master")
        end
    elseif PSC_MultiKillCount > 1 and PSC_DB.EnableMultiKillSounds then
        -- Play multi-kill sounds for 2+ kills
        local soundFile
        local soundPack = PSC_DB.SoundPack or "LoL"

        if soundPack == "LoL" then
            if PSC_MultiKillCount == 2 then
                soundFile = "Interface\\AddOns\\PvPStatsClassic\\sounds\\LoL\\double_kill.mp3"
            elseif PSC_MultiKillCount == 3 then
                soundFile = "Interface\\AddOns\\PvPStatsClassic\\sounds\\LoL\\triple_kill.mp3"
            elseif PSC_MultiKillCount == 4 then
                soundFile = "Interface\\AddOns\\PvPStatsClassic\\sounds\\LoL\\quadra_kill.mp3"
            elseif PSC_MultiKillCount == 5 then
                soundFile = "Interface\\AddOns\\PvPStatsClassic\\sounds\\LoL\\penta_kill.mp3"
            elseif PSC_MultiKillCount == 6 then
                soundFile = "Interface\\AddOns\\PvPStatsClassic\\sounds\\LoL\\hexa-kill.mp3"
            elseif PSC_MultiKillCount == 7 then
                soundFile = "Interface\\AddOns\\PvPStatsClassic\\sounds\\LoL\\legendary-kill.mp3"
            end
        else -- UT sounds
            local utSounds = {}
            if PSC_MultiKillCount == 2 then
                utSounds = {"double-kill.mp3", "multi-kill.mp3", "killing-spree.mp3", "combowhore.mp3", "head-hunter.mp3"}
            elseif PSC_MultiKillCount == 3 then
                utSounds = {"triple-kill.mp3", "multi-kill.mp3", "killing-spree.mp3", "unstoppable.mp3", "holy-shit.mp3", "unreal.mp3"}
            elseif PSC_MultiKillCount == 4 then
                utSounds = {"ultra-kill.mp3", "mega-kill.mp3", "god-like.mp3"}
            elseif PSC_MultiKillCount >= 5 then
                utSounds = {"ludicrous-kill.mp3", "monster-kill.mp3"}
            end

            if #utSounds > 0 then
                local randomIndex = math.random(1, #utSounds)
                soundFile = "Interface\\AddOns\\PvPStatsClassic\\sounds\\UT\\" .. utSounds[randomIndex]
            end
        end

        if soundFile then
            PlaySoundFile(soundFile, "Master")
        end
    end

    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]
    local highestMultiKillAlias = characterData.HighestMultiKill

    if PSC_MultiKillCount > highestMultiKillAlias then
        PSC_DB.PlayerKillCounts.Characters[characterKey].HighestMultiKill = PSC_MultiKillCount

        if highestMultiKillAlias >= 3 and PSC_DB.EnableRecordAnnounceMessages and not PSC_CurrentlyInBattleground then
            local newMultiKillRecordMsg = string.gsub(PSC_DB.NewMultiKillRecordMessage, "MULTIKILLTEXT", GetMultiKillText(PSC_MultiKillCount))
            PSC_SendAnnounceMessage(newMultiKillRecordMsg)
        end
    end
end

local function AnnounceKill(killedPlayer, level, nameWithLevel, playerLevel)
    if PSC_CurrentlyInBattleground or not PSC_DB.EnableKillAnnounceMessages then return end

    local characterKey = PSC_GetCharacterKey()
    local killMessage = string.gsub(PSC_DB.KillAnnounceMessage, "Enemyplayername", killedPlayer)

    if string.find(killMessage, "x#") then
        local totalKills = PSC_GetTotalsKillsForPlayer(killedPlayer)
        killMessage = string.gsub(killMessage, "x#", "x" .. totalKills)
    end

    local levelDifference = level - playerLevel
    local levelDisplay = level == -1 and "??" or tostring(level)

    -- Build details string to include player and/or guild information
    local detailsString = ""
    local infoKey = PSC_GetInfoKeyFromName(killedPlayer)
    local playerInfo = PSC_DB.PlayerInfoCache[infoKey]

    -- Include player details if option is enabled
    if PSC_DB.IncludePlayerDetailsInAnnounce then
        if playerInfo then
            local classDisplay = playerInfo.class or "Unknown"
            local raceDisplay = playerInfo.race or "Unknown"
            detailsString = "Level " .. levelDisplay .. " " .. raceDisplay .. " " .. classDisplay
        else
            detailsString = "Level " .. levelDisplay
        end
    elseif level == -1 or (level > 0 and levelDifference >= 6) then
        detailsString = "Level " .. levelDisplay
    end

    -- Include guild details if option is enabled
    if PSC_DB.IncludeGuildDetailsInAnnounce then
        if playerInfo and playerInfo.guild and playerInfo.guild ~= "" then
            local guildRankDisplay = playerInfo.guildRank or "Member"
            local guildString = guildRankDisplay .. " of <" .. playerInfo.guild .. ">"
            if detailsString ~= "" then
                detailsString = detailsString .. ", " .. guildString
            else
                detailsString = guildString
            end
        end
    end

    -- Add details to message if any details were included
    if detailsString ~= "" then
        killMessage = killMessage .. " (" .. detailsString .. ")"
    end

    local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]
    if characterData.CurrentKillStreak >= 10 and characterData.CurrentKillStreak % 5 == 0 then
        killMessage = killMessage .. " - Kill Streak: " .. characterData.CurrentKillStreak
    end

    PSC_SendAnnounceMessage(killMessage)

    if PSC_MultiKillCount >= PSC_DB.MultiKillThreshold then
        local multiKillText = GetMultiKillText(PSC_MultiKillCount)
        if PSC_DB.EnableMultiKillAnnounceMessages then
            PSC_SendAnnounceMessage(multiKillText)
        end
    end
end

function PSC_RegisterPlayerKill(playerName, killerName, killerGUID)
    local playerLevel = UnitLevel("player")
    local infoKey = PSC_GetInfoKeyFromName(playerName)

    if not PSC_DB.PlayerInfoCache[infoKey] then
        if PSC_Debug then
            print("Player not found in cache: " .. playerName .. ", ignoring kill.")
        end
        return
    end

    local level = PSC_DB.PlayerInfoCache[infoKey].level
    -- infoKey already includes the realm (Name-Realm)
    -- This ensures distinct keys for same-named players on different realms
    local nameWithLevel = infoKey .. ":" .. level
    local characterKey = PSC_GetCharacterKey()

    if not PSC_DB.PlayerKillCounts.Characters[characterKey] then
        PSC_DB.PlayerKillCounts.Characters[characterKey] = {
            Kills = {},
            CurrentKillStreak = 0,
            HighestKillStreak = 0,
            HighestMultiKill = 0,
            MultiKillCounts = {},
            GrayKillsCount = 0
        }
    end

    -- Check if this is a gray level kill and increment counter if it is
    if PSC_IsGrayLevelKill(playerLevel, level) then
        PSC_DB.PlayerKillCounts.Characters[characterKey].GrayKillsCount =
            PSC_DB.PlayerKillCounts.Characters[characterKey].GrayKillsCount + 1

        if PSC_Debug then
            print("[PvPStats]: Gray kill registered against " .. playerName .. " (Level " .. level .. ")")
        end
    end

    -- Update spawn camper counter if this is a level 1 kill
    if level == 1 then
        UpdateSpawnCamperCounter(time())
    end

    UpdateKillStreak(playerName, level, PSC_DB.PlayerInfoCache[infoKey].class)
    ShowKillStreakMilestone(PSC_DB.PlayerKillCounts.Characters[characterKey].CurrentKillStreak)
    InitializeKillCountEntryForPlayer(nameWithLevel, playerLevel)
    UpdateKillCountEntry(nameWithLevel, playerLevel)
    UpdateMultiKill()
    AnnounceKill(playerName, level, nameWithLevel, playerLevel)

    local totalKills = PSC_GetTotalsKillsForPlayer(playerName)
    local playerRank = PSC_DB.PlayerInfoCache[infoKey].rank or 0
    if (totalKills == 1 and PSC_DB.ShowMilestoneForFirstKill) or totalKills >= 2 then
        PSC_ShowKillMilestone(playerName, level, PSC_DB.PlayerInfoCache[infoKey].class, playerRank, totalKills)
    end

    PSC_StartIncrementalAchievementsCalculation()
end

function PSC_RecordPetDamage(petGUID, petName, targetGUID, amount)
    if not petGUID or not targetGUID then return end

    local ownerGUID = GetPetOwnerGUID(petGUID)
    if not ownerGUID then return end

    RecentPetDamage[targetGUID] = {
        timestamp = GetTime(),
        petGUID = petGUID,
        petName = petName,
        ownerGUID = ownerGUID,
        amount = amount or 0
    }
    if ownerGUID == PSC_PlayerGUID then
        PSC_RecordPlayerDamage(ownerGUID, PSC_CharacterName, targetGUID, "Unknown", amount)
        if PSC_Debug then
            print("Recorded damage from your pet to: " .. targetGUID .. " Amount: " .. amount)
        end
    end
end

function PSC_CleanupRecentlyCountedKillsDict()
    local now = GetTime()
    local cutoff = now - PSC_KILL_TRACKING_WINDOW
    for guid, timestamp in pairs(PSC_RecentlyCountedKills) do
        if timestamp < cutoff then
            PSC_RecentlyCountedKills[guid] = nil
        end
    end
end

function PSC_RecordPlayerDamage(sourceGUID, sourceName, targetGUID, targetName, amount)
    if not sourceGUID or not targetGUID then return end

    if sourceGUID ~= PSC_PlayerGUID then return end

    local existingRecord = PSC_RecentPlayerDamage[targetGUID] or {
        timestamp = 0,
        totalDamage = 0
    }

    existingRecord.timestamp = GetTime()
    existingRecord.totalDamage = existingRecord.totalDamage + amount

    PSC_RecentPlayerDamage[targetGUID] = existingRecord

    -- if PSC_Debug then
    --     print(string.format("You dealt %d damage to %s", amount, targetName))
    -- end
end

function PSC_CleanupRecentPlayerDamage()
    PSC_RecentPlayerDamage = {}
end

function PSC_RegisterNPCKill(npcName, npcID)
    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]

    if not characterData.NPCKills then
        characterData.NPCKills = {}
    end

    characterData.NPCKills[npcName] = (characterData.NPCKills[npcName] or 0) + 1

    if PSC_Debug then
        print("[PvPStats]: Recorded kill for NPC: " .. npcName .. " (ID: " .. npcID .. ")")
    end

    PSC_StartIncrementalAchievementsCalculation()
end

