local addonName, PVPSC = ...

local pvpStatsClassicFrame = CreateFrame("Frame", "PvpStatsClassicFrame", UIParent)

PSC_Debug = false
PSC_PlayerGUID = ""
PSC_CharacterName = ""
PSC_RealmName = ""

PSC_GAME_VERSIONS = {
    CLASSIC = 1,
    TBC = 2,
    WOTLK = 3,
}
PSC_GameVersion = nil

RecentPetDamage = {}
local PET_DAMAGE_WINDOW = 0.05

PSC_InCombat = false

PSC_LastDeathTime = 0
PSC_DEATH_EVENT_COOLDOWN = 2 -- seconds to ignore duplicate death events

PSC_CurrentlyInBattleground = false
PSC_lastInBattlegroundValue = false

PSC_PendingHunterKills = {}
local HUNTER_FEIGN_DEATH_CHECK_WINDOW = 3.0 -- Seconds to wait before confirming kill
local HUNTER_FEIGN_DEATH_MIN_LEVEL = 30

PSC_RecentlyCountedPriestKills = {}
local PRIEST_SPIRIT_OF_REDEMPTION_MIN_LEVEL = 30
local PRIEST_KILL_DEDUP_WINDOW = 20.0 -- 15s Spirit of Redemption + lag margin

-- Eyes of the Beast lets a hunter's pet fight beyond combat log range, so those kills
-- never generate PARTY_KILL/UNIT_DIED events. While the aura is active we instead watch
-- "pettarget"'s health directly, which keeps syncing even at extreme range.
local EYES_OF_THE_BEAST_SPELL_ID = 1002
local eyesOfTheBeastWatcherActive = false
local eyesOfTheBeastPetTargetGUID, eyesOfTheBeastPetTargetName
local eyesOfTheBeastPetTargetWasAlive, eyesOfTheBeastPetTargetDeathHandled

-- Backstop for /psc register_kill_for_current_corpse_target, in case the enemy auto-untargets
-- on death before the watcher above can credit the kill. Keyed per-GUID so recovering one missed
-- kill doesn't block recovering a different one moments later.
local PET_CORPSE_KILL_COMMAND_COOLDOWN = 10.0
local lastPetCorpseKillCommandTimeByGUID = {}

local function OnPlayerTargetChanged()
    PSC_GetAndStorePlayerInfoFromUnit("target")
    PSC_GetAndStorePlayerInfoFromUnit("targettarget")
    PSC_UpdatePetOwnerFromUnit("target")
    PSC_UpdatePetOwnerFromUnit("targettarget")
end

local function OnUpdateMouseoverUnit()
    PSC_GetAndStorePlayerInfoFromUnit("mouseover")
    PSC_UpdatePetOwnerFromUnit("mouseover")
end

local function HandleCombatState(inCombatNow)
    if PSC_InCombat and not inCombatNow then
        PSC_FinalizeMultiKillTally()
        PSC_MultiKillCount = 0
        PSC_InCombat = false
    elseif not PSC_InCombat and inCombatNow then
        PSC_MultiKillCount = 0
        PSC_InCombat = true
    end
end

local function SendWarningIfKilledByHighLevelPlayer(killerInfo)
    local killerName = killerInfo.killer.name

    local infoKey = PSC_GetInfoKeyFromName(killerName)

    if not PSC_DB.PlayerInfoCache[infoKey] then
        if PSC_Debug then
            print("Warning: Killer " .. killerName .. " not found in player info cache")
        end
        return
    end

    local killerLevel = PSC_DB.PlayerInfoCache[infoKey].level
    local killerClass = PSC_DB.PlayerInfoCache[infoKey].class

    if killerLevel ~= -1 then
        return
    end

    if not PSC_DB.EnableHighLevelDeathWarning then
        return
    end

    if not IsInGroup() then
        return
    end

    local playerX, playerY = PSC_GetPlayerCoordinates()
    local playerCoords = string.format("%.1f, %.1f", playerX, playerY)
    local subZoneText = GetSubZoneText()
    local playerPosition = ""
    if subZoneText ~= "" then
        playerPosition = subZoneText .. " (" .. playerCoords .. ")"
    else
        playerPosition = playerCoords
    end
    local warningMsg = "I got killed by " .. killerName .. " (Level ?? " .. killerClass .. ") at " .. playerPosition .. "!"
    SendChatMessage(warningMsg, "PARTY")
end

function HandlePlayerDeath()
    if not PSC_CharacterName or PSC_CharacterName == "" then
        return
    end

    local now = GetTime()
    if (now - PSC_LastDeathTime) < PSC_DEATH_EVENT_COOLDOWN then
        if PSC_Debug then
            print("Ignoring duplicate PLAYER_DEAD event")
        end
        return
    end

    PSC_LastDeathTime = now

    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]

    if characterData.CurrentKillStreak >= 10 and PSC_DB.EnableRecordAnnounceMessages and not PSC_CurrentlyInBattleground then
        local streakEndedMsg = string.gsub(PSC_DB.KillStreakEndedMessage, "STREAKCOUNT", characterData.CurrentKillStreak)
        PSC_SendAnnounceMessage(streakEndedMsg)
    end

    characterData.CurrentKillStreak = 0
    characterData.CurrentKillStreakPlayers = {} -- Clear kill streak players list
    PSC_FinalizeMultiKillTally()
    PSC_MultiKillCount = 0
    PSC_InCombat = false

    -- Update kill streak popup if it's open
    if PSC_UpdateKillStreakPopup then
        PSC_UpdateKillStreakPopup()
    end

    -- Play death sound if enabled
    if PSC_DB.EnableDeathSounds then
        local soundPack = PSC_DB.SoundPack or "LoL"
        local soundFile
        if soundPack == "LoL" then
            local lolDeathSounds = {"you_have_been_slain.mp3", "defeat.mp3"}
            local randomIndex = math.random(1, #lolDeathSounds)
            soundFile = "Interface\\AddOns\\PvPStatsClassic\\sounds\\LoL\\" .. lolDeathSounds[randomIndex]
        else
            soundFile = "Interface\\AddOns\\PvPStatsClassic\\sounds\\UT\\you-have-failed-to-proceed.mp3"
        end
        PlaySoundFile(soundFile, "Master")
    end

    print("[PvPStats]: You died, kill streak reset.")

    if PSC_CurrentlyInBattleground and not PSC_DB.CountDeathsInBattlegrounds then
        if PSC_Debug then print("BG Mode: Death tracking disabled in battlegrounds") end
        return
    end

    local killerInfo = PSC_GetKillerInfoOnDeath()
    if killerInfo then
        if not PSC_CurrentlyInBattleground then
            SendWarningIfKilledByHighLevelPlayer(killerInfo)
        end
        PSC_RegisterPlayerDeath(killerInfo)
    end
end

local function CleanupRecentPetDamage()
    local now = GetTime()
    local cutoff = now - PET_DAMAGE_WINDOW

    for guid, info in pairs(RecentPetDamage) do
        if info.timestamp < cutoff then
            RecentPetDamage[guid] = nil
        end
    end
end

PSC_TrackedNPCs = {
    [349] = "Corporal Keeshan",
    [467] = "The Defias Traitor",
    [550] = "Defias Messenger",
    [442] = "Tarantula",
    [116] = "Defias Bandit",
    [732] = "Murloc Lurker",
    [43] = "Murloc Forager"
}

function PSC_IsValidTarget(destFlags, destGUID)
    if bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 and
       bit.band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0 then
        return true
    end

    if destGUID then
        local npcID = PSC_GetNPCIDFromGUID(destGUID)
        if npcID and PSC_TrackedNPCs[npcID] then
            return true
        end
    end

    return false
end

local function HandlePlayerDamageEvent(sourceGUID, sourceName, destGUID, destName, param1, param4)
    if sourceGUID ~= PSC_PlayerGUID then return end

    local damageAmount = param1 or param4 or 0
    if damageAmount <= 0 then return end

    PSC_RecordPlayerDamage(sourceGUID, sourceName, destGUID, destName, damageAmount)
end

local function HandleCombatLogPlayerDamage(combatEvent, sourceGUID, sourceName, destGUID, destName, destFlags, param1, param4)
    if sourceGUID ~= PSC_PlayerGUID then return end

    local damageAmount = 0
    local isUtilitySpell = false

    if combatEvent == "SWING_DAMAGE" then
        damageAmount = param1 or 0
    elseif combatEvent == "SPELL_DAMAGE" or combatEvent == "SPELL_PERIODIC_DAMAGE" then
        damageAmount = param4 or 0
    elseif combatEvent == "RANGE_DAMAGE" then
        damageAmount = param4 or 0
    elseif combatEvent == "SPELL_DISPEL" or
        combatEvent == "SPELL_INTERRUPT" or
        combatEvent == "SPELL_AURA_APPLIED" or
        combatEvent == "SPELL_AURA_APPLIED_DOSE" or
        combatEvent == "SPELL_AURA_REFRESH" or
        combatEvent == "SPELL_AURA_REMOVED" then
        isUtilitySpell = true
        damageAmount = 1
    end

    if damageAmount > 0 or isUtilitySpell then
        HandlePlayerDamageEvent(sourceGUID, sourceName, destGUID, destName, damageAmount, nil)
    end
end

function IsHunterAndCanFeignDeath(destName)
    local infoKey = PSC_GetInfoKeyFromName(destName)
    if not PSC_DB.PlayerInfoCache[infoKey] then
        return false
    end

    local isHunter = PSC_DB.PlayerInfoCache[infoKey].class == "Hunter"
    local level = PSC_DB.PlayerInfoCache[infoKey].level

    if not isHunter then
        return false
    end

    if level == -1 then
        return true
    end

    if level < HUNTER_FEIGN_DEATH_MIN_LEVEL then
        return false
    end

    return true
end

local function ShouldSuppressPriestKillForSpiritOfRedemption(destName)
    if not destName or destName == "" then
        return false
    end

    local infoKey = PSC_GetInfoKeyFromName(destName)
    local playerInfo = PSC_DB.PlayerInfoCache[infoKey]
    if not playerInfo or playerInfo.class ~= "Priest" then
        return false
    end

    local level = playerInfo.level
    if level ~= -1 and level < PRIEST_SPIRIT_OF_REDEMPTION_MIN_LEVEL then
        return false
    end

    local now = GetTime()
    local lastKillTimestamp = PSC_RecentlyCountedPriestKills[infoKey]
    if lastKillTimestamp and (now - lastKillTimestamp) < PRIEST_KILL_DEDUP_WINDOW then
        if PSC_Debug then
            print("Suppressing duplicate priest kill during Spirit of Redemption window for " .. destName)
        end
        return true
    end

    PSC_RecentlyCountedPriestKills[infoKey] = now
    return false
end

local function IsEyesOfTheBeastActive()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitAura("player", i, "HELPFUL")
        if PSC_Debug then
            print("Aura: " .. (name or "nil") .. " spellId: " .. (spellId or "nil"))
        end
        if not name then
            return false
        end
        if spellId == EYES_OF_THE_BEAST_SPELL_ID then
            return true
        end
    end
    return false
end

local function IsValidEyesOfTheBeastPetTarget(unit)
    if not UnitExists(unit) or not UnitCanAttack("player", unit) then
        return false
    end

    if UnitIsPlayer(unit) then
        return true
    end

    local npcID = PSC_GetNPCIDFromGUID(UnitGUID(unit))
    return npcID ~= nil and PSC_TrackedNPCs[npcID] ~= nil
end

local function ClearEyesOfTheBeastPetTargetState()
    eyesOfTheBeastPetTargetGUID, eyesOfTheBeastPetTargetName = nil, nil
    eyesOfTheBeastPetTargetWasAlive, eyesOfTheBeastPetTargetDeathHandled = nil, nil
end

local function CreditEyesOfTheBeastKill(destGUID, destName)
    if not destGUID or not destName then
        return
    end

    if PSC_WasKillRecentlyCounted(destGUID) then
        if PSC_Debug then print("[EOTB] Kill for " .. destName .. " already counted, skipping") end
        return
    end

    if PSC_CurrentlyInBattleground and not PSC_DB.CountKillsInBattlegrounds then
        if PSC_Debug then print("BG Mode: Eyes of the Beast pet kill ignored (kill tracking disabled in battlegrounds)") end
        return
    end

    local npcID = PSC_GetNPCIDFromGUID(destGUID)
    if npcID and PSC_TrackedNPCs[npcID] then
        if PSC_Debug then print("[EOTB] Crediting NPC kill: " .. PSC_TrackedNPCs[npcID]) end
        PSC_RecentlyCountedKills[destGUID] = GetTime()
        PSC_RegisterNPCKill(PSC_TrackedNPCs[npcID], npcID)
        return
    end

    if strsplit("-", destGUID) ~= "Player" then
        if PSC_Debug then print("[EOTB] Target " .. destName .. " is not a player or tracked NPC, ignoring") end
        return
    end

    if ShouldSuppressPriestKillForSpiritOfRedemption(destName) then
        if PSC_Debug then print("[EOTB] Kill for " .. destName .. " suppressed (Spirit of Redemption)") end
        return
    end

    if PSC_Debug then print("[EOTB] Crediting player kill: " .. destName) end
    PSC_RecentlyCountedKills[destGUID] = GetTime()
    PSC_RegisterPlayerKill(destName, "Eyes of the Beast", nil)
end

-- The pettarget's corpse can keep existing (still "valid") for a while after death, so we can't
-- use its HP alone to decide whether to (re-)credit a kill once it vanishes or swaps - that flag
-- alone would re-fire on every later vanish/swap. eyesOfTheBeastPetTargetDeathHandled remembers
-- that this specific GUID's death was already dealt with, independent of any time window.
local function HandleEyesOfTheBeastPetTargetDeath()
    if eyesOfTheBeastPetTargetDeathHandled then return end
    eyesOfTheBeastPetTargetDeathHandled = true
    CreditEyesOfTheBeastKill(eyesOfTheBeastPetTargetGUID, eyesOfTheBeastPetTargetName)
end

-- Called on UNIT_HEALTH("pettarget")/UNIT_TARGET("pet"). Credits a kill the moment the
-- pet's target goes from alive to dead; the vanish/swap fallback covers cases where we
-- never see the target at 0 HP directly (e.g. its corpse is released before our next update).
local function UpdateEyesOfTheBeastPetTarget()
    if not IsValidEyesOfTheBeastPetTarget("pettarget") then
        if eyesOfTheBeastPetTargetGUID and eyesOfTheBeastPetTargetWasAlive == false then
            if PSC_Debug then print("[EOTB] pettarget vanished after dying: " .. (eyesOfTheBeastPetTargetName or "Unknown")) end
            HandleEyesOfTheBeastPetTargetDeath()
        elseif eyesOfTheBeastPetTargetGUID and PSC_Debug then
            print("[EOTB] pettarget no longer valid: " .. (eyesOfTheBeastPetTargetName or "Unknown"))
        end
        ClearEyesOfTheBeastPetTargetState()
        return
    end

    PSC_GetAndStorePlayerInfoFromUnit("pettarget")

    local guid = UnitGUID("pettarget")
    local hp = UnitHealth("pettarget") or 0
    local isDead = UnitIsDead("pettarget") or hp == 0

    if guid ~= eyesOfTheBeastPetTargetGUID then
        if eyesOfTheBeastPetTargetGUID and eyesOfTheBeastPetTargetWasAlive == false then
            if PSC_Debug then print("[EOTB] pettarget swapped after dying: " .. (eyesOfTheBeastPetTargetName or "Unknown")) end
            HandleEyesOfTheBeastPetTargetDeath()
        end
        eyesOfTheBeastPetTargetGUID = guid
        -- UnitName returns name and realm separately; cross-realm players need the "-Realm" suffix
        -- to match the key PSC_GetAndStorePlayerInfoFromUnit just cached them under above.
        local petTargetName, petTargetRealm = UnitName("pettarget")
        eyesOfTheBeastPetTargetName = petTargetRealm and (petTargetName .. "-" .. petTargetRealm) or petTargetName
        eyesOfTheBeastPetTargetWasAlive = not isDead
        -- Found already dead (e.g. a pre-existing corpse) -> we never witnessed the kill, so mark it
        -- handled up front; otherwise a later vanish/swap would wrongly credit it as a fresh kill.
        eyesOfTheBeastPetTargetDeathHandled = isDead
        if PSC_Debug then
            print("[EOTB] pettarget acquired: " .. (eyesOfTheBeastPetTargetName or "Unknown") .. " HP: " .. hp ..
                (isDead and " (already dead, not crediting)" or ""))
        end
        return
    end

    if eyesOfTheBeastPetTargetWasAlive and isDead then
        if PSC_Debug then print("[EOTB] pettarget died: " .. (eyesOfTheBeastPetTargetName or "Unknown")) end
        eyesOfTheBeastPetTargetWasAlive = false
        HandleEyesOfTheBeastPetTargetDeath()
    end
end

local function SetEyesOfTheBeastWatcherActive(active)
    if active == eyesOfTheBeastWatcherActive then return end
    eyesOfTheBeastWatcherActive = active

    if PSC_Debug then
        print("[EOTB] Pet target tracking " .. (active and "activated" or "deactivated"))
    end

    if active then
        pvpStatsClassicFrame:RegisterUnitEvent("UNIT_HEALTH", "pettarget")
        pvpStatsClassicFrame:RegisterUnitEvent("UNIT_TARGET", "pet")
        UpdateEyesOfTheBeastPetTarget()
    else
        pvpStatsClassicFrame:UnregisterEvent("UNIT_HEALTH")
        pvpStatsClassicFrame:UnregisterEvent("UNIT_TARGET")
        ClearEyesOfTheBeastPetTargetState()
    end
end

local function OnPlayerAuraChanged()
    SetEyesOfTheBeastWatcherActive(IsEyesOfTheBeastActive())
end

-- Undocumented recovery command for /psc register_kill_for_current_corpse_target: some enemies
-- auto-untarget the instant they die, which can clear pettarget before the watcher above ever
-- observes the alive->dead transition. Bypasses the watcher's own state machine entirely and
-- credits directly, relying on the shared PSC_WasKillRecentlyCounted guard against double-counting
-- kills the watcher already caught on its own.
function PSC_RegisterEyesOfTheBeastCorpseKill()
    if not eyesOfTheBeastWatcherActive then
        if PSC_Debug then print("[EOTB] register_kill_for_current_corpse_target: Eyes of the Beast is not active") end
        return
    end

    if not UnitExists("pettarget") or not UnitIsPlayer("pettarget")
        or not UnitCanAttack("player", "pettarget") or not UnitIsDead("pettarget") then
        if PSC_Debug then print("[EOTB] register_kill_for_current_corpse_target: pet target is not a hostile player corpse") end
        return
    end

    local guid = UnitGUID("pettarget")
    local lastUse = lastPetCorpseKillCommandTimeByGUID[guid]
    if lastUse and (GetTime() - lastUse) < PET_CORPSE_KILL_COMMAND_COOLDOWN then
        if PSC_Debug then print("[EOTB] register_kill_for_current_corpse_target: on cooldown for this target") end
        return
    end
    lastPetCorpseKillCommandTimeByGUID[guid] = GetTime()

    PSC_GetAndStorePlayerInfoFromUnit("pettarget")
    local name, realm = UnitName("pettarget")
    local destName = realm and (name .. "-" .. realm) or name

    if PSC_Debug then print("[EOTB] Manually registering kill for pet target corpse: " .. destName) end
    CreditEyesOfTheBeastKill(guid, destName)
end

function PSC_CleanupPetCorpseKillCommandCooldowns()
    local cutoff = GetTime() - (PET_CORPSE_KILL_COMMAND_COOLDOWN * 2)
    for guid, timestamp in pairs(lastPetCorpseKillCommandTimeByGUID) do
        if timestamp < cutoff then
            lastPetCorpseKillCommandTimeByGUID[guid] = nil
        end
    end
end

function PSC_ScheduleHunterKillValidation(destGUID, destName, eventType, validationData)
    if not IsHunterAndCanFeignDeath(destName) then
        return false
    end

    if PSC_Debug then
        print("Hunter " .. destName .. " might be using feign death- validating...")
    end

    PSC_PendingHunterKills[destGUID] = {
        name = destName,
        timestamp = GetTime(),
        eventType = eventType,
        gotDamagedAfter = false,
        validationData = validationData
    }

    C_Timer.After(HUNTER_FEIGN_DEATH_CHECK_WINDOW, function()
        PSC_ValidateHunterKill(destGUID)
    end)

    return true
end

local function HandlePartyKillEvent(sourceGUID, sourceName, destGUID, destName)
    if PSC_WasKillRecentlyCounted(destGUID) then
        return
    end

    if PSC_CurrentlyInBattleground and not PSC_DB.CountKillsInBattlegrounds then
        if PSC_Debug then print("BG Mode: Kill tracking disabled in battlegrounds") end
        return
    end

    local countKill = false

    if PSC_CurrentlyInBattleground then
        if sourceGUID == PSC_PlayerGUID then
            countKill = true
            if PSC_Debug then print("BG Mode: Player killing blow") end
        else
            if PSC_Debug then print("BG Mode: Party/Raid member killing blow ignored") end
        end
    else
        if sourceGUID == PSC_PlayerGUID then
            countKill = true
            if PSC_Debug then print("Normal Mode: Player killing blow") end
        elseif UnitInParty(sourceName) or UnitInRaid(sourceName) then
            countKill = true
            if PSC_Debug then print("Normal Mode: Party/Raid member killing blow") end
        end
    end

    if countKill then
        local npcID = PSC_GetNPCIDFromGUID(destGUID)
        if npcID and PSC_TrackedNPCs[npcID] then
             -- Mobs tracked by ID are handled exclusively in UnitDied to ensure player participation
        else
            local unitType = strsplit("-", destGUID)
            if unitType == "Player" then
                if ShouldSuppressPriestKillForSpiritOfRedemption(destName) then
                    return
                end
                PSC_RecentlyCountedKills[destGUID] = GetTime()
                PSC_RegisterPlayerKill(destName, sourceName, sourceGUID)
            end
        end
    end
end

local function HandleUnitDiedEvent(destGUID, destName)
    if PSC_WasKillRecentlyCounted(destGUID) then
        return
    end

    if PSC_CurrentlyInBattleground and not PSC_DB.CountKillsInBattlegrounds then
        return
    end

    local countKill = false
    local petDamage = RecentPetDamage[destGUID]

    if petDamage and (GetTime() - petDamage.timestamp) <= PET_DAMAGE_WINDOW then
        if PSC_CurrentlyInBattleground then
            if petDamage.ownerGUID == PSC_PlayerGUID then
                countKill = true
                if PSC_Debug then
                    print("BG Mode: Pet killing blow detected (via recent damage)")
                    print("Pet: " .. (petDamage.petName or "Unknown"))
                end
            else
                if PSC_Debug then print("BG Mode: Pet killing blow ignored (not your pet)") end
            end
        else
            if petDamage.ownerGUID == PSC_PlayerGUID then
                countKill = true
                if PSC_Debug then
                    print("Normal Mode: Your pet killing blow detected")
                end
            else
                local ownerName = GetNameFromGUID(petDamage.ownerGUID)
                if ownerName and (UnitInParty(ownerName) or UnitInRaid(ownerName)) then
                    countKill = true
                    if PSC_Debug then
                        print("Normal Mode: Party/raid member's pet kill detected")
                    end
                end
            end
        end

        if countKill then
            local npcID = PSC_GetNPCIDFromGUID(destGUID)
            if npcID and PSC_TrackedNPCs[npcID] then
                -- For tracked NPCs, only player's own pet counts as a Killing Blow here.
                -- Party pet kills are ignored here and fall through to the assist check to verify participation.
                if petDamage.ownerGUID == PSC_PlayerGUID then
                    PSC_RecentlyCountedKills[destGUID] = GetTime()
                    PSC_RegisterNPCKill(PSC_TrackedNPCs[npcID], npcID)
                end
            else
                local unitType = strsplit("-", destGUID)
                if unitType == "Player" then
                    if ShouldSuppressPriestKillForSpiritOfRedemption(destName) then
                        return
                    end
                    PSC_RecentlyCountedKills[destGUID] = GetTime()
                    PSC_RegisterPlayerKill(destName, petDamage.petName, petDamage.petGUID)
                end
            end

            -- If we registered a kill (NPC or Player), we return.
            -- If we skipped (Party Pet NPC KB), we continue to allow assist check.
            if (npcID and PSC_TrackedNPCs[npcID] and petDamage.ownerGUID == PSC_PlayerGUID) or
               (npcID == nil and strsplit("-", destGUID) == "Player") then
                RecentPetDamage[destGUID] = nil
                return
            end
        end
    end

    local playerDamage = PSC_RecentPlayerDamage[destGUID]
    if playerDamage and (GetTime() - playerDamage.timestamp) <= PSC_ASSIST_DAMAGE_WINDOW then
        local lastAssistTime = PSC_LastAssistCreditTime[destGUID]
        if lastAssistTime and playerDamage.timestamp <= lastAssistTime then
            if PSC_Debug then
                print("Assist kill ignored for " .. destName .. ": no new action against them since the last assist")
            end
            return
        end

        if playerDamage.totalDamage > 0 then
            if PSC_CurrentlyInBattleground and not PSC_DB.CountAssistsInBattlegrounds then
                if PSC_Debug then
                    print("BG Mode: Assist kill ignored (assists disabled in BGs)")
                end
                return
            end

            if PSC_Debug then
                print("Assist kill detected for: " .. destName)
            end

            PSC_RecentlyCountedKills[destGUID] = GetTime()
            PSC_LastAssistCreditTime[destGUID] = GetTime()
            local npcID = PSC_GetNPCIDFromGUID(destGUID)
            if npcID and PSC_TrackedNPCs[npcID] then
                PSC_RegisterNPCKill(PSC_TrackedNPCs[npcID], npcID)
            else
                local unitType = strsplit("-", destGUID)
                if unitType == "Player" then
                    if ShouldSuppressPriestKillForSpiritOfRedemption(destName) then
                        return
                    end
                    PSC_RegisterPlayerKill(destName, "Assist", nil)
                end
            end
            PSC_RecentPlayerDamage[destGUID] = nil
        end
    end
end

local function HandleCombatLogEventPetDamage(combatEvent, sourceGUID, sourceName, destGUID, destName, param1, param4)
    if IsPetGUID(sourceGUID) and destGUID then
        local damageAmount = 0

        if combatEvent == "SWING_DAMAGE" then
            damageAmount = param1 or 0
        elseif combatEvent == "SPELL_DAMAGE" or combatEvent == "SPELL_PERIODIC_DAMAGE" then
            damageAmount = param4 or 0
        elseif combatEvent == "RANGE_DAMAGE" then
            damageAmount = param4 or 0
        end

        if damageAmount > 0 then
            PSC_RecordPetDamage(sourceGUID, sourceName, destGUID, damageAmount)
        end
    end
end

function PSC_ValidateHunterKill(destGUID)
    local eventData = PSC_PendingHunterKills[destGUID]
    if not eventData then return end

    if eventData.gotDamagedAfter then
        if PSC_Debug then
            print("Validation: Hunter " .. eventData.name ..
                  " received damage after event - ignoring as likely feign death")
        end

        PSC_PendingHunterKills[destGUID] = nil
        return
    end

    -- No damage received during validation window, process as a real event
    if PSC_Debug then
        print("Validation: Hunter " .. eventData.name ..
              " received no damage after death - processing as normal kill")
    end

    -- Simply call the appropriate handler based on event type
    if eventData.eventType == "PARTY_KILL" then
        local sourceGUID = eventData.validationData.sourceGUID
        local sourceName = eventData.validationData.sourceName

        -- Call the existing party kill handler
        HandlePartyKillEvent(sourceGUID, sourceName, destGUID, eventData.name)
    elseif eventData.eventType == "UNIT_EVENT" then
        -- Call the existing unit died handler
        HandleUnitDiedEvent(destGUID, eventData.name)
    end

    -- Clean up the pending event
    PSC_PendingHunterKills[destGUID] = nil
end

local function HandleCombatLogEvent()
    local timestamp, combatEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags, param1, param2, param3, param4, param5, param6, param7, param8 = CombatLogGetCurrentEventInfo()

    if destGUID and PSC_PendingHunterKills[destGUID] and
       (combatEvent == "SWING_DAMAGE" or
        combatEvent == "SPELL_DAMAGE" or
        combatEvent == "SPELL_PERIODIC_DAMAGE" or
        combatEvent == "RANGE_DAMAGE") then
        PSC_PendingHunterKills[destGUID].gotDamagedAfter = true

        if PSC_Debug then
            print("Hunter " .. destName .. " received damage after event - likely using feign death")
        end
    end

    local isValidTarget = PSC_IsValidTarget(destFlags, destGUID)

    if isValidTarget then
        HandleCombatLogEventPetDamage(combatEvent, sourceGUID, sourceName, destGUID, destName, param1, param4)
        HandleCombatLogPlayerDamage(combatEvent, sourceGUID, sourceName, destGUID, destName, destFlags, param1, param4)
    end

    if destGUID == PSC_PlayerGUID then
        if sourceGUID == PSC_PlayerGUID then
            -- Ignore self-damage events
            return
        end

        if bit.band(sourceFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 then
            local spellId, spellName
            if combatEvent == "SWING_DAMAGE" then
                spellId = 0
                spellName = "Melee"
            else
                spellId = param1
                spellName = param2
            end

            PSC_HandleReceivedPlayerDamage(combatEvent, sourceGUID, sourceName, spellId, spellName, param1, param4)
        elseif IsPetGUID(sourceGUID) then
            PSC_HandleReceivedPlayerDamageByEnemyPets(combatEvent, sourceGUID, sourceName, param1, param4)
        end
    end

    if combatEvent == "PARTY_KILL" and isValidTarget then
        local isScheduled = PSC_ScheduleHunterKillValidation(destGUID, destName, "PARTY_KILL", {
            sourceGUID = sourceGUID,
            sourceName = sourceName
        })

        if not isScheduled then
            HandlePartyKillEvent(sourceGUID, sourceName, destGUID, destName)
        end
    end

    if combatEvent == "UNIT_DIED" and isValidTarget then
        local isScheduled = PSC_ScheduleHunterKillValidation(destGUID, destName, "UNIT_EVENT", {})

        if not isScheduled then
            HandleUnitDiedEvent(destGUID, destName)
        end
    end
end

function PSC_CleanupPendingHunterKills()
    local now = GetTime()
    local cutoff = now - (HUNTER_FEIGN_DEATH_CHECK_WINDOW * 2)

    for guid, data in pairs(PSC_PendingHunterKills) do
        if data.timestamp < cutoff then
            PSC_PendingHunterKills[guid] = nil
        end
    end
end

function PSC_CleanupRecentlyCountedPriestKills()
    local now = GetTime()
    local cutoff = now - (PRIEST_KILL_DEDUP_WINDOW * 2)

    for infoKey, timestamp in pairs(PSC_RecentlyCountedPriestKills) do
        if timestamp < cutoff then
            PSC_RecentlyCountedPriestKills[infoKey] = nil
        end
    end
end

local function DetermineGameVersion()
    -- Example output of GetBuildInfo()
    -- 1.15.8 64858 Dec  9 2025 11508  Release  11508
    local versionString = GetBuildInfo()
    local major, minor, patch = versionString:match("^(%d+)%.(%d+)%.(%d+)")

    major = tonumber(major)
    minor = tonumber(minor)
    patch = tonumber(patch)
    local game_version = nil

    if major == 1 then
        game_version = PSC_GAME_VERSIONS.CLASSIC
    elseif major == 2 then
        game_version =  PSC_GAME_VERSIONS.TBC
    elseif major == 3 then
        game_version =  PSC_GAME_VERSIONS.WOTLK
    end

    if PSC_Debug then
        print("Detected game version: " .. tostring(game_version))
    end

    return game_version
end

local addonWelcomeMessageShown = false

local function HandlePlayerEnteringWorld()
    PSC_PlayerGUID = UnitGUID("player")
    PSC_CharacterName = UnitName("player")
    PSC_RealmName = GetRealmName()
    PSC_GameVersion = DetermineGameVersion()

    PVPSC.AchievementSystem:InitializeAchievements()

    if not PSC_DB then
        PSC_DB = {}
        PSC_LoadDefaultSettings()
        ResetAllStatsToDefault()
    end

    PVPSC.AchievementSystem:LoadAchievementCompletedData()

    -- Initialize minimap button settings if not present
    if not PSC_DB.minimapButton then
        PSC_DB.minimapButton = {
            hide = false,
        }
        -- Migrate old position if it exists
        if PSC_DB.MinimapButtonPosition then
            PSC_DB.minimapButton.minimapPos = PSC_DB.MinimapButtonPosition
        end
    end

    -- Initialize announce channel setting if not present (migration for existing users)
    if not PSC_DB.AnnounceChannel then
        PSC_DB.AnnounceChannel = "GROUP"
    end

    if PSC_DB.EnableHighLevelDeathWarning == nil then
        PSC_DB.EnableHighLevelDeathWarning = true
    end

    -- Initialize what's-new popup tracking
    if PSC_DB.WhatsNewPopupShown == nil then
        PSC_DB.WhatsNewPopupShown = false
    end

    if PSC_DB.WhatsNewPopupVersion == nil then
        PSC_DB.WhatsNewPopupVersion = "v1.0"
    end

    if PSC_DB.PlayerInfoCache == nil then
        PSC_DB.PlayerInfoCache = {}
    end
    PSC_GetAndStorePlayerInfoFromUnit("player", true)

    PSC_MigratePlayerInfoCache()
    PSC_MigratePlayerInfoToEnglish()
    PSC_MigrateKillKeys()
    PSC_MigrateLossKeys()
    PSC_MigrateArenaZones()
    PSC_InitializePlayerKillCounts()
    PSC_InitializeLeaderboardCache()
    PSC_InitializePlayerLossCounts()

    PSC_UpdateMinimapButtonPosition()
    PSC_SetupMouseoverTooltip()
    PSC_InCombat = UnitAffectingCombat("player")
    PSC_CheckBattlegroundStatus()
    PSC_InitializeGrayKillsCounter()
    PSC_InitializeSpawnCamperCounter()
    OnPlayerAuraChanged() -- Resync the Eyes of the Beast watcher in case of a login/reload mid-buff

    if UnitIsDeadOrGhost("player") then
        HandlePlayerDeath()
    end

    if PSC_Debug then
        print("[PvPStats]: Debug mode enabled.")
    end

    if not addonWelcomeMessageShown then
        addonWelcomeMessageShown = true
        print("[PvPStats]: Click the minimap button or type /psc to use the addon.")
    end

    local currentVersion = PSC_GetAddonVersion()
    if PSC_DB.WhatsNewPopupVersion ~= currentVersion then
        local title = "PvP Stats v" .. currentVersion .. " - What's new:"
        local message = "- Pet kills using Eyes of the Beast are now tracked correctly when the pet is far\n   away from the hunter.\n\n- New achievements\n\n- Cleaned up the settings menu\n\n- Added new stats to the statistics window\n\n- All popups, sounds and emotes can now be turned off or on in the settings\n\nEnjoy!"
        local discordUrl = "https://discord.gg/ZBaN2xk5h3"
        PSC_ShowWhatsNewPopup(title, message, function()
            PSC_DB.WhatsNewPopupShown = true
            PSC_DB.WhatsNewPopupVersion = currentVersion
        end, discordUrl)
        PSC_MigratePlayerInfoToEnglish(true)
    end

    PSC_StartIncrementalAchievementsCalculation()

    -- Check for data import from legacy clients
    if PSC_CheckForDataMigration then
        C_Timer.After(2, function() PSC_CheckForDataMigration() end)
    end

    if PSC_ShowImportSummaryPopup then
        C_Timer.After(1.0, function() PSC_ShowImportSummaryPopup() end)
    end
end

local function HandlePlayerRegenEnabled()
    HandleCombatState(false)
    CleanupRecentPetDamage()
    PSC_CleanupRecentlyCountedKillsDict()
    PSC_CleanupRecentPlayerDamage()
    PSC_CleanupRecentDamageFromPlayers()
    PSC_CleanupPendingHunterKills()
    PSC_CleanupRecentlyCountedPriestKills()
    PSC_CleanupPetCorpseKillCommandCooldowns()
    PSC_CleanupLastAssistCreditTimes()
    PSC_ClearGUIDCache()

    if PVPSC.Network and PVPSC.Network.pendingCombatBroadcast then
        PVPSC.Network:BroadcastStats()
    end
end

local function HandleNamePlateEvent(unit)
    PSC_GetAndStorePlayerInfoFromUnit(unit)
    PSC_UpdatePetOwnerFromUnit(unit)
end

function PSC_RegisterEvents()
    pvpStatsClassicFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    pvpStatsClassicFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    pvpStatsClassicFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    pvpStatsClassicFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    pvpStatsClassicFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    pvpStatsClassicFrame:RegisterEvent("PLAYER_DEAD")
    pvpStatsClassicFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    pvpStatsClassicFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    pvpStatsClassicFrame:RegisterEvent("PLAYER_LOGOUT")
    pvpStatsClassicFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    pvpStatsClassicFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    pvpStatsClassicFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
    pvpStatsClassicFrame:RegisterUnitEvent("UNIT_AURA", "player")

    pvpStatsClassicFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            HandlePlayerEnteringWorld()
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            HandleCombatLogEvent()
        elseif event == "PLAYER_TARGET_CHANGED" then
            OnPlayerTargetChanged()
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            OnUpdateMouseoverUnit()
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            local unit = ...
            if unit then
                HandleNamePlateEvent(unit)
            end
        elseif event == "PLAYER_DEAD" then
            HandlePlayerDeath()
        elseif event == "UNIT_AURA" then
            OnPlayerAuraChanged()
        elseif event == "UNIT_HEALTH" or event == "UNIT_TARGET" then
            UpdateEyesOfTheBeastPetTarget()
        elseif event == "PLAYER_REGEN_DISABLED" then
            HandleCombatState(true)
        elseif event == "PLAYER_REGEN_ENABLED" then
            HandlePlayerRegenEnabled()
        elseif event == "PLAYER_LOGOUT" then
            PSC_GetAndStorePlayerInfoFromUnit("player", true)
            PSC_CleanupPlayerInfoCache()
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            PSC_CheckBattlegroundStatus()
        elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
            -- Refresh the current character's guild info immediately so cached title data does not stay stale
            if event == "PLAYER_GUILD_UPDATE" then
                PSC_GetAndStorePlayerInfoFromUnit("player", true)
            end

            -- Only broadcast stats on group/guild change if Network is initialized
            if PVPSC.Network and PVPSC.Network.initialized then
                PVPSC.Network:BroadcastStats()
            end
        end
    end)
end

function PSC_CheckBattlegroundStatus()
    if PSC_DB.ForceBattlegroundMode then
        if not PSC_lastInBattlegroundValue then
            print("[PvPStats]: Forced battleground mode enabled.")
        end
        PSC_CurrentlyInBattleground = true
        PSC_lastInBattlegroundValue = true
        return
    end

    local currentMapId = C_Map.GetBestMapForUnit("player")

    local battlegroundZoneIds = {
        -- Correct IDs from here (all marked with patch 1.13.2:
        -- https://wowpedia.fandom.com/wiki/UiMapID
        -- "Alterac Valley"
        91,
        1537,
        2162,
        1459,

        -- "Warsong Gulch"
        1460,

        -- "Arathi Basin"
        1461,

        -- Eye of the Storm
        1956,

        -- 1433 -- Redridge Mountains
    }

    for _, bgMapId in ipairs(battlegroundZoneIds) do
        if (currentMapId == bgMapId) then
            if not PSC_lastInBattlegroundValue then
                local msg = "[PvPStats]: Entered battleground. "
                if PSC_DB.CountKillsInBattlegrounds then
                    msg = msg .. "Only your own killing blows "
                    if PSC_DB.CountAssistsInBattlegrounds then
                        msg = msg .. "and assists "
                    end
                    msg = msg .. "will be counted, "
                else
                    msg = msg .. "No kills will be counted, "
                end
                if PSC_DB.CountDeathsInBattlegrounds then
                    msg = msg .. "deaths will be counted."
                else
                    msg = msg .. "no deaths will be counted."
                end
                print(msg)
            end
            PSC_CurrentlyInBattleground = true
            PSC_lastInBattlegroundValue = true
            return
        end
    end

    if PSC_lastInBattlegroundValue then
        print("[PvPStats]: Left battleground.")
    end
    PSC_lastInBattlegroundValue = false
    PSC_CurrentlyInBattleground = false
end

function PSC_GetTotalsKillsForPlayer(playerName)
    if not playerName or playerName == "" then
        return 0
    end

    local normalizedName = PSC_GetInfoKeyFromName(playerName)
    local total_kills = 0
    for nameWithLevel, data in pairs(PSC_DB.PlayerKillCounts.Characters[PSC_GetCharacterKey()].Kills) do
        local storedName = nameWithLevel:match("^(.+):")
        if storedName == normalizedName then
            total_kills = total_kills + data.kills
        end
    end

    if total_kills == 0 and not string.find(playerName, "%-") then
        local prefix = playerName .. "-"
        for nameWithLevel, data in pairs(PSC_DB.PlayerKillCounts.Characters[PSC_GetCharacterKey()].Kills) do
            local storedName = nameWithLevel:match("^(.+):")
            if storedName and string.sub(storedName, 1, #prefix) == prefix then
                total_kills = total_kills + data.kills
            end
        end
    end
    return total_kills
end

local tooltipHooksRegistered = false

function PSC_SetupMouseoverTooltip()
    if tooltipHooksRegistered then return end
    tooltipHooksRegistered = true

    local function GetLastKillTimestamp(playerName)
        local characterKey = PSC_GetCharacterKey()
        local lastKill = 0

        local normalizedName = PSC_GetInfoKeyFromName(playerName)
        local allowPrefixSearch = not string.find(playerName, "%-")
        local prefix = allowPrefixSearch and (playerName .. "-") or nil

        for nameWithLevel, data in pairs(PSC_DB.PlayerKillCounts.Characters[characterKey].Kills) do
            local storedName = nameWithLevel:match("^(.+):")
            if storedName then
                if storedName == normalizedName then
                    if data.lastKill and data.lastKill > lastKill then
                        lastKill = data.lastKill
                    end
                elseif allowPrefixSearch and string.sub(storedName, 1, #prefix) == prefix then
                    if data.lastKill and data.lastKill > lastKill then
                        lastKill = data.lastKill
                    end
                end
            end
        end

        return lastKill > 0 and lastKill or nil
    end

    local function GetDeathsByPlayerName(playerName)
        local characterKey = PSC_GetCharacterKey()
        if not PSC_DB.PvPLossCounts or not PSC_DB.PvPLossCounts[characterKey] or
           not PSC_DB.PvPLossCounts[characterKey].Deaths then
            return 0
        end

        local deathsTable = PSC_DB.PvPLossCounts[characterKey].Deaths
        local normalizedName = PSC_GetInfoKeyFromName(playerName)
        local totalDeaths = 0
        local found = false

        if deathsTable[normalizedName] then
            totalDeaths = totalDeaths + (deathsTable[normalizedName].deaths or 0)
            found = true
        end

        -- Check the raw name as well (for same realm players where realm is omitted in storage)
        -- Only add if it's different from normalized name (e.g. "Bob" vs "Bob-MyRealm")
        if playerName ~= normalizedName and deathsTable[playerName] then
            totalDeaths = totalDeaths + (deathsTable[playerName].deaths or 0)
            found = true
        end

        if found then
            return totalDeaths
        end

        if not string.find(playerName, "%-") then
            local prefix = playerName .. "-"
            local totalDeaths = 0
            for storedName, deathData in pairs(deathsTable) do
                if storedName and string.sub(storedName, 1, #prefix) == prefix then
                    totalDeaths = totalDeaths + (deathData.deaths or 0)
                end
            end
            return totalDeaths
        end

        return 0
    end

    local function AddPvPInfoToTooltip(tooltip, playerName, kills, deaths)
        if tooltip.pvpStatsAdded then return end

        local lastKill = GetLastKillTimestamp(playerName)
        local scoreText = ""

        if not PSC_DB.ShowExtendedTooltipInfo then
            scoreText = "Kills: " .. kills
        else
            scoreText = "Score " .. kills .. ":" .. deaths

            if kills > 0 then
                local lastKillTimespan = PSC_FormatLastKillTimespan(lastKill)
                if lastKillTimespan then
                    scoreText = scoreText .. " - Last kill " .. lastKillTimespan .. " ago"
                end
            end
        end

        tooltip:AddLine(scoreText, 1, 1, 1)
        tooltip.pvpStatsAdded = true
        tooltip:Show()
    end

    local function OnTooltipSetUnit(tooltip)
        if not PSC_DB.ShowScoreInPlayerTooltip then return end

        local _, unit = tooltip:GetUnit()
        if not unit then return end

        if not UnitIsPlayer(unit) or UnitIsFriend("player", unit) then return end

        local name, realm = UnitName(unit)
        local playerName = name
        if realm then
            playerName = name .. "-" .. realm
        end

        local kills = PSC_GetTotalsKillsForPlayer(playerName)
        local deaths = GetDeathsByPlayerName(playerName)
        AddPvPInfoToTooltip(tooltip, playerName, kills, deaths)
    end

    local function OnTooltipShow(tooltip)
        if not PSC_DB.ShowScoreInPlayerTooltip then return end
        if not tooltip:IsShown() then return end

        local line1 = _G[tooltip:GetName() .. "TextLeft1"]
        if not line1 then return end

        local text = line1:GetText()
        if not text or not text:find("^Corpse of ") then return end

        local playerName = text:match("^Corpse of (.+)$")
        if not playerName then return end

        local kills = PSC_GetTotalsKillsForPlayer(playerName)
        local deaths = GetDeathsByPlayerName(playerName)
        if kills == nil or deaths == nil then return end
        if kills == 0 and deaths == 0 then return end
        AddPvPInfoToTooltip(tooltip, playerName, kills, deaths)
    end

    GameTooltip:HookScript("OnTooltipSetUnit", OnTooltipSetUnit)
    GameTooltip:HookScript("OnShow", OnTooltipShow)

    GameTooltip:HookScript("OnTooltipCleared", function(tooltip)
        tooltip.pvpStatsAdded = nil
        C_Timer.After(0.01, function()
            if tooltip:IsShown() then
                OnTooltipShow(tooltip)
            end
        end)
    end)
end
