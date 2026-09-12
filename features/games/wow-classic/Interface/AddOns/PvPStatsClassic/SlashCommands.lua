local addonName, PVPSC = ...

local function PrintSlashCommandUsage()
    PSC_Print("Usage: /psc stats - Show PvP statistics")
    PSC_Print("Usage: /psc history - Show PvP history")
    PSC_Print("Usage: /psc achievements - Show PvP achievements")
    PSC_Print("Usage: /psc leaderboard - Show PvP leaderboard")
    PSC_Print("Usage: /psc sendstats <player name> - Send your stats to a player")
    PSC_Print("Usage: /psc settings - Open addon settings")

    if PSC_Debug then
        PSC_Print("Debug Commands:")
        PSC_Print("Usage: /psc registerstreakkill [days] [killsPerDay] [daysAgo] - Generate test streak data")
        PSC_Print("Usage: /psc timezonetest - Test timezone detection")
        PSC_Print("Usage: /psc status - Show current settings")
        PSC_Print("Usage: /psc debug - Show current streak values")
        PSC_Print("Usage: /psc registerkill [number] - Register test kill(s) for testing")
        PSC_Print("Usage: /psc registerlevel1kill [number] - Register test level 1 kill(s) for testing")
        PSC_Print("Usage: /psc registernpckill <NPC name> - Register NPC kill for testing")
        PSC_Print("Usage: /psc simulatedeath [killers] [assists] - Simulate being killed")
        PSC_Print("Usage: /psc bgmode - Toggle battleground mode manually")
        PSC_Print("Usage: /psc toggledebug - Toggle debug messages")
        PSC_Print("Usage: /psc debugevents - Enhanced combat log debugging for 30 seconds")
        PSC_Print("Usage: /psc debugpet - Track all pet damage and kills for 60 seconds")
        PSC_Print("Usage: /psc simulatedeath [killers] [assists] - Simulate being killed")
        PSC_Print("Usage: /psc simcombatlog [killers] [assists] [damage] - Simulate combat log entries for death")
        PSC_Print("Usage: /psc deathstats - Show death statistics")
        PSC_Print("Usage: /psc snapshot [label] - Save stats + achievement progress snapshot to SavedVariables")
    end


end

local function PSC_RegisterNPCKillCommand(arguments)
    if arguments and arguments ~= "" then
        local npcName = strtrim(arguments)
        -- Find matching NPC by name
        local npcID = nil
        for id, name in pairs(PSC_TrackedNPCs) do
            if name == npcName then
                npcID = id
                break
            end
        end

        if npcID then
            PSC_RegisterNPCKill(npcName, npcID)
        else
            PSC_Print("Error: NPC '" .. npcName .. "' not found in tracked NPCs list.")
            PSC_Print("Available NPCs:")
            for id, name in pairs(PSC_TrackedNPCs) do
                PSC_Print("  - " .. name .. " (ID: " .. id .. ")")
            end
        end
    else
        PSC_Print("Usage: /psc registernpckill <NPC name>")
        PSC_Print("Available NPCs:")
        for id, name in pairs(PSC_TrackedNPCs) do
            PSC_Print("  - " .. name .. " (ID: " .. id .. ")")
        end
    end
end

local function PrintStatus()
    local statusMessage = "Kill announce messages are " .. (PSC_DB.EnableKillAnnounceMessages and "ENABLED" or "DISABLED") .. "."
    PSC_Print(statusMessage)
    PSC_Print("Current kill announce message: " .. PSC_DB.KillAnnounceMessage)
    PSC_Print("Streak ended message: " .. PSC_DB.KillStreakEndedMessage)
    PSC_Print("New streak record message: " .. PSC_DB.NewKillStreakRecordMessage)
    PSC_Print("New multi-kill record message: " .. PSC_DB.NewMultiKillRecordMessage)
    PSC_Print("Multi-kill announcement threshold: " .. PSC_DB.MultiKillThreshold)
    PSC_Print("Record announcements: " .. (PSC_DB.EnableRecordAnnounceMessages and "ENABLED" or "DISABLED"))
    PSC_Print("Battleground Mode: " .. (PSC_CurrentlyInBattleground and "ACTIVE" or "INACTIVE"))
    PSC_Print("Auto BG Detection: " .. (PSC_DB.AutoBattlegroundMode and "ENABLED" or "DISABLED"))
    PSC_Print("Manual BG Mode: " .. (PSC_DB.ForceBattlegroundMode and "ENABLED" or "DISABLED"))
end

function PSC_SlashCommandHandler(msg)
    local command, arguments = msg:match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "stats" then
        PSC_CreateStatisticsFrame()

    elseif command == "history" then
        PSC_CreateKillsListFrame()

    elseif command == "achievements" then
        PSC_ToggleAchievementFrame()

    elseif command == "leaderboard" or command == "lb" then
        PSC_CreateLeaderboardFrame()

    elseif command == "sendstats" then
        if not arguments or arguments == "" then
            PSC_Print("Usage: /psc sendstats <player name>")
            return
        end

        local normalized = PVPSC.Network.NormalizeTargetName and PVPSC.Network:NormalizeTargetName(arguments) or strtrim(arguments)
        if not normalized or normalized == "" then
            PSC_Print("Usage: /psc sendstats <player name>")
            return
        end

        local sent, _, reason = PVPSC.Network:SendStatsToPlayer(normalized)
        if not sent then
            PSC_Print("[PvPStats]: " .. (reason or "Unable to send statistics."))
            return
        end

        PSC_Print("[PvPStats]: Sent stats to " .. normalized .. ". They will only be able to receive them if they have addon version 4.2 or higher.")

    elseif command == "options" or command == "settings" then
        PSC_CreateConfigUI()

    elseif command == "migrate_international_data" then
        PSC_MigratePlayerInfoToEnglish(true)
        -- reload UI
        ReloadUI()

    elseif command == "register_kill_for_current_corpse_target" then
        PSC_RegisterEyesOfTheBeastCorpseKill()

    elseif PSC_Debug then
        if command == "simulatedeath" then
            local killerCount = 1
            local assistCount = 0
            if arguments and arguments ~= "" then
                local counts = {arguments:match("(%d+)%s*(%d*)")}
                if counts[1] then killerCount = tonumber(counts[1]) end
                if counts[2] then assistCount = tonumber(counts[2]) end
            end
            PSC_SimulatePlayerDeathByEnemy(killerCount, assistCount)

        elseif command == "simcombatlog" then
            local killerCount = 1
            local assistCount = 0
            local damageType = "direct"  -- Options: direct, dot, mixed
            if arguments and arguments ~= "" then
                local parts = {strsplit(" ", arguments)}
                if parts[1] then killerCount = tonumber(parts[1]) or 1 end
                if parts[2] then assistCount = tonumber(parts[2]) or 0 end
                if parts[3] then damageType = parts[3] end
            end
            PSC_SimulateCombatLogEvent(killerCount, assistCount, damageType)

        elseif command == "testtrackers" or command == "testdeath" then
            PSC_RunDeathTrackingTests()

        elseif command == "deathstats" then
            PSC_ShowDeathStats()

        elseif command == "status" then
            PrintStatus()

        elseif command == "debug" then
            PSC_ShowDebugInfo()

        elseif command == "registerkill" then
            local testKillCount = 1
            if arguments and arguments ~= "" then
                local count = tonumber(arguments)
                if count and count > 0 then
                    testKillCount = count
                end
            end
            PSC_SimulatePlayerKills(testKillCount)

        elseif command == "registerlevel1kill" then
            local testKillCount = 1
            if arguments and arguments ~= "" then
                local count = tonumber(arguments)
                if count and count > 0 then
                    testKillCount = count
                end
            end
            PSC_SimulateLevel1Kills(testKillCount)

        elseif command == "registernpckill" then
            PSC_RegisterNPCKillCommand(arguments)

        elseif command == "registerstreakkill" then
            local days, killsPerDay, daysAgo = arguments:match("(%d+)%s+(%d+)%s*(%d*)")
            days = tonumber(days) or 7
            killsPerDay = tonumber(killsPerDay) or 10
            daysAgo = tonumber(daysAgo) or nil
            PSC_GenerateStreakTestData(days, killsPerDay, daysAgo)

        elseif command == "bgmode" then
            PSC_DB.ForceBattlegroundMode = not PSC_DB.ForceBattlegroundMode
            PSC_CheckBattlegroundStatus()
            PSC_Print("Manual Battleground Mode " .. (PSC_DB.ForceBattlegroundMode and "ENABLED" or "DISABLED"))

        elseif command == "debugevents" then
            PSC_DebugCombatLogEvents()

        elseif command == "debugpet" then
            PSC_DebugPetKills()

        elseif command == "timezonetest" then
            PSC_TestTimeZoneOffsetCalculation()

        elseif command == "roleplayer" then
            PSC_CreateRoleplayer()

        elseif command == "snapshot" then
            PSC_CreateDebugSnapshot(arguments ~= "" and arguments or nil)

        elseif command == "testdatamigration" then
            PSC_RunMigrationTests()

        else
            PrintSlashCommandUsage()
        end
    else
        PrintSlashCommandUsage()
    end
end
