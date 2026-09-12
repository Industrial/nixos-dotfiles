local addonName, PVPSC = ...

-- Data Migration Module
-- Handles importing data from older addons or manual file copies (PSC_DB_IMPORT)

local function ResolveImportInfoKey(unitName)
    if not unitName or unitName == "" then
        return nil
    end

    if string.find(unitName, "%-") then
        return unitName
    end

    if PSC_DB_IMPORT and PSC_DB_IMPORT.PlayerInfoCache then
        local searchPrefix = unitName .. "-"
        for key, _ in pairs(PSC_DB_IMPORT.PlayerInfoCache) do
            if string.sub(key, 1, #searchPrefix) == searchPrefix then
                return key
            end
        end
    end

    local _, foundInfoKey = PSC_GetPlayerInfo(unitName)
    if foundInfoKey then
        return foundInfoKey
    end

    return nil
end

local function NormalizeImportedName(unitName)
    return ResolveImportInfoKey(unitName)
end

local function NormalizeImportedAssisters(deathLocations)
    if not deathLocations then return 0 end
    local normalizedCount = 0
    for _, loc in ipairs(deathLocations) do
        if loc.assisters then
            for _, assister in ipairs(loc.assisters) do
                if assister.name then
                    local normalizedName = NormalizeImportedName(assister.name) or assister.name
                    if normalizedName ~= assister.name then
                        normalizedCount = normalizedCount + 1
                    end
                    assister.name = normalizedName
                end
            end
        end
    end
    return normalizedCount
end

local function NormalizeImportedLocationZones(locations)
    if not locations then return 0 end
    local normalizedCount = 0
    for _, loc in ipairs(locations) do
        if loc.zone then
            local normalized = PSC_ConvertZoneToEnglish(loc.zone)
            if normalized and normalized ~= loc.zone then
                loc.zone = normalized
                normalizedCount = normalizedCount + 1
            end
        end
    end
    return normalizedCount
end

local function MergeKillEntry(destKills, unitKey, sourceEntry, counters)
    if not unitKey or not sourceEntry then
        return 0
    end

    local unitName = string.match(unitKey, "(.-)%:")
    local unitLevel = string.match(unitKey, ":(%-?%d+)")

    local destKey = unitKey
    if unitName and unitLevel then
        local importInfoKey = ResolveImportInfoKey(unitName)
        if importInfoKey then
            destKey = importInfoKey .. ":" .. unitLevel
        end
    end

    if destKey ~= unitKey then
        counters.normalizedKeys = counters.normalizedKeys + 1
    end

    if not destKills[destKey] then
        destKills[destKey] = CopyTable(sourceEntry)
        NormalizeImportedLocationZones(destKills[destKey].killLocations)
        local added = 0
        if sourceEntry.killLocations then
            added = #sourceEntry.killLocations
        else
            added = sourceEntry.kills or 0
        end
        counters.importedKills = counters.importedKills + added
        return added
    else
        local destEntry = destKills[destKey]
        local existingTimestamps = {}

        local beforeCount = destEntry.killLocations and #destEntry.killLocations or 0

        if destEntry.killLocations then
            for _, loc in ipairs(destEntry.killLocations) do
                if loc.timestamp then
                    existingTimestamps[loc.timestamp] = true
                end
            end
        else
            destEntry.killLocations = {}
        end

        if sourceEntry.killLocations then
            NormalizeImportedLocationZones(sourceEntry.killLocations)
            for _, sourceLoc in ipairs(sourceEntry.killLocations) do
                if sourceLoc.timestamp and not existingTimestamps[sourceLoc.timestamp] then
                    table.insert(destEntry.killLocations, CopyTable(sourceLoc))
                    existingTimestamps[sourceLoc.timestamp] = true
                end
            end
        end

        destEntry.kills = #destEntry.killLocations

        table.sort(destEntry.killLocations, function(a, b)
            return (a.timestamp or 0) < (b.timestamp or 0)
        end)

        local maxProp = 0
        for _, loc in ipairs(destEntry.killLocations) do
            if loc.timestamp and loc.timestamp > maxProp then
                maxProp = loc.timestamp
            end
        end
        destEntry.lastKill = maxProp
        local afterCount = #destEntry.killLocations
        local added = math.max(0, afterCount - beforeCount)
        counters.importedKills = counters.importedKills + added
        return added
    end
end

local function MergeLossEntry(destLosses, unitName, sourceEntry, counters)
    if not unitName or not sourceEntry then
        return
    end

    local destKey = NormalizeImportedName(unitName) or unitName
    if destKey ~= unitName then
        counters.normalizedKeys = counters.normalizedKeys + 1
    end

    if not destLosses[destKey] then
        local copyEntry = CopyTable(sourceEntry)
        counters.normalizedAssisters = counters.normalizedAssisters + NormalizeImportedAssisters(copyEntry.deathLocations)
        NormalizeImportedLocationZones(copyEntry.deathLocations)
        destLosses[destKey] = copyEntry
        counters.importedDeaths = counters.importedDeaths + (copyEntry.deaths or 0)
    else
        local destEntry = destLosses[destKey]
        local existingTimestamps = {}

        if destEntry.deathLocations then
            for _, loc in ipairs(destEntry.deathLocations) do
                if loc.timestamp then
                    existingTimestamps[loc.timestamp] = true
                end
            end
        else
            destEntry.deathLocations = {}
        end

        if sourceEntry.deathLocations then
            counters.normalizedAssisters = counters.normalizedAssisters + NormalizeImportedAssisters(sourceEntry.deathLocations)
            NormalizeImportedLocationZones(sourceEntry.deathLocations)
            for _, sourceLoc in ipairs(sourceEntry.deathLocations) do
                if sourceLoc.timestamp and not existingTimestamps[sourceLoc.timestamp] then
                    table.insert(destEntry.deathLocations, CopyTable(sourceLoc))
                    existingTimestamps[sourceLoc.timestamp] = true
                end
            end
        end

        destEntry.deaths = #destEntry.deathLocations

        table.sort(destEntry.deathLocations, function(a, b)
            return (a.timestamp or 0) < (b.timestamp or 0)
        end)
    end
end

local function PSC_RunMigrationTaskQueue(taskQueue, onDone)
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
            print("[PvPStats] Error in migration task " .. currentTask .. ": " .. tostring(result))
            result = true
        end

        if result == nil or result == true then
            currentTask = currentTask + 1
        end

        C_Timer.After(0, runNextTask)
    end

    runNextTask()
end

local function BuildImportSummaryText(summary)
    if not summary then
        return nil
    end

    local lines = {}
    table.insert(lines, "Import complete!")
    table.insert(lines, "")
    table.insert(lines, "Imported kills (total): " .. tostring(summary.totalKills or 0))

    if summary.perCharacter then
        table.insert(lines, "")
        table.insert(lines, "Per character:")
        for _, entry in ipairs(summary.perCharacter) do
            local name = entry.name or "Unknown"
            local kills = entry.kills or 0
            table.insert(lines, string.format("- %s: %d", name, kills))
        end
    end

    table.insert(lines, "")
    table.insert(lines, "Please review your statistics and check if the values are correct.")

    return table.concat(lines, "\n")
end

function PSC_ShowImportSummaryPopup()
    if not PSC_DB or not PSC_DB.ImportSummaryPending then
        return
    end

    local summary = PSC_DB.ImportSummaryPending
    local text = BuildImportSummaryText(summary)
    if not text then
        PSC_DB.ImportSummaryPending = nil
        return
    end

    StaticPopupDialogs["PSC_IMPORT_SUMMARY"] = {
        text = text,
        button1 = "Show Statistics",
        OnAccept = function()
            PSC_DB.ImportSummaryPending = nil
            PSC_CreateStatisticsFrame()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }

    StaticPopup_Show("PSC_IMPORT_SUMMARY")
end

local function MergeAchievements(destItems, sourceItems)
    local count = 0
    for id, data in pairs(sourceItems) do
        if data.unlocked then
            if not destItems[id] or not destItems[id].unlocked then
                destItems[id] = CopyTable(data)
                count = count + 1
            end
        end
    end
    return count
end

local function MergePlayerInfoCache(destCache, sourceCache)
    if not sourceCache then return 0 end

    local count = 0
    for key, info in pairs(sourceCache) do
        if not destCache[key] then
            destCache[key] = CopyTable(info)
            count = count + 1
        else
            -- Check if we should copy the note (if exists in source but not in dest)
            if info.note and not destCache[key].note then
                destCache[key].note = info.note
                -- We don't increment count here as it's not a full entry import, but an enhancement
            end
        end
    end
    return count
end

function PSC_PerformDataMigration(runSync)
    if not PSC_DB_IMPORT then return end

    print("[PvPStats]: Starting data migration...")

    -- 1. Merge Player Info Cache (Global)
    local infoImported = MergePlayerInfoCache(PSC_DB.PlayerInfoCache, PSC_DB_IMPORT.PlayerInfoCache)
    print(string.format("[PvPStats]: Imported %d player info cache entries.", infoImported))

    -- Ensure localized class/race names from imported data are normalized
    PSC_DB.PlayerInfoEnglishMigrated = nil
    if PSC_MigratePlayerInfoToEnglish then
        PSC_MigratePlayerInfoToEnglish()
    end

    local taskQueue = {}
    local killState = nil
    local lossState = nil
    local killBudget = runSync and math.huge or 250
    local lossBudget = runSync and math.huge or 250

    local function initKillState()
        if not PSC_DB.PlayerKillCounts then PSC_DB.PlayerKillCounts = {} end
        if not PSC_DB.PlayerKillCounts.Characters then PSC_DB.PlayerKillCounts.Characters = {} end

        killState = {
            charKeys = {},
            charIndex = 1,
            killKeys = nil,
            killIndex = 1,
            counters = { importedKills = 0, normalizedKeys = 0 },
            perCharacterImported = {},
            totalImportedKills = 0
        }

        if PSC_DB_IMPORT.PlayerKillCounts and PSC_DB_IMPORT.PlayerKillCounts.Characters then
            for charKey, _ in pairs(PSC_DB_IMPORT.PlayerKillCounts.Characters) do
                table.insert(killState.charKeys, charKey)
            end
        end
    end

    local function processKillSlice()
        if not PSC_DB_IMPORT.PlayerKillCounts or not PSC_DB_IMPORT.PlayerKillCounts.Characters then
            return true
        end

        if not killState then
            initKillState()
        end

        local processed = 0
        while processed < killBudget do
            if killState.charIndex > #killState.charKeys then
                return true
            end

            local charKey = killState.charKeys[killState.charIndex]
            local charData = PSC_DB_IMPORT.PlayerKillCounts.Characters[charKey]

            if not PSC_DB.PlayerKillCounts.Characters[charKey] then
                PSC_DB.PlayerKillCounts.Characters[charKey] = {
                    Kills = {},
                    Level1KillTimestamps = {},
                    SpawnCamperMaxKills = 0
                }
            end

            if not charData or not charData.Kills then
                killState.charIndex = killState.charIndex + 1
                killState.killKeys = nil
                killState.killIndex = 1
            else
                if not killState.killKeys then
                    killState.killKeys = {}
                    for unitKey in pairs(charData.Kills) do
                        table.insert(killState.killKeys, unitKey)
                    end
                    killState.killIndex = 1
                end

                if killState.killIndex > #killState.killKeys then
                    PSC_DB.PlayerKillCounts.Characters[charKey].Level1KillTimestamps = nil

                    local destChar = PSC_DB.PlayerKillCounts.Characters[charKey]
                    if charData.HighestKillStreak and (charData.HighestKillStreak > (destChar.HighestKillStreak or 0)) then
                        destChar.HighestKillStreak = charData.HighestKillStreak
                    end
                    if charData.HighestMultiKill and (charData.HighestMultiKill > (destChar.HighestMultiKill or 0)) then
                        destChar.HighestMultiKill = charData.HighestMultiKill
                    end
                    if charData.SpawnCamperMaxKills and (charData.SpawnCamperMaxKills > (destChar.SpawnCamperMaxKills or 0)) then
                        destChar.SpawnCamperMaxKills = charData.SpawnCamperMaxKills
                    end
                    if charData.GrayKillsCount and (charData.GrayKillsCount > (destChar.GrayKillsCount or 0)) then
                        destChar.GrayKillsCount = charData.GrayKillsCount
                    end

                    killState.charIndex = killState.charIndex + 1
                    killState.killKeys = nil
                    killState.killIndex = 1
                else
                    local unitKey = killState.killKeys[killState.killIndex]
                    killState.killIndex = killState.killIndex + 1

                    local sourceEntry = charData.Kills[unitKey]
                    if sourceEntry then
                        local added = MergeKillEntry(PSC_DB.PlayerKillCounts.Characters[charKey].Kills, unitKey, sourceEntry, killState.counters)
                        if added and added > 0 then
                            killState.perCharacterImported[charKey] = (killState.perCharacterImported[charKey] or 0) + added
                            killState.totalImportedKills = killState.totalImportedKills + added
                        end
                    end
                    processed = processed + 1
                end
            end
        end

        return false
    end

    local function initLossState()
        if not PSC_DB.PvPLossCounts then PSC_DB.PvPLossCounts = {} end

        lossState = {
            charKeys = {},
            charIndex = 1,
            deathKeys = nil,
            deathIndex = 1,
            counters = { importedDeaths = 0, normalizedKeys = 0, normalizedAssisters = 0 }
        }

        if PSC_DB_IMPORT.PvPLossCounts then
            for charKey, _ in pairs(PSC_DB_IMPORT.PvPLossCounts) do
                table.insert(lossState.charKeys, charKey)
            end
        end
    end

    local function processLossSlice()
        if not PSC_DB_IMPORT.PvPLossCounts then
            return true
        end

        if not lossState then
            initLossState()
        end

        local processed = 0
        while processed < lossBudget do
            if lossState.charIndex > #lossState.charKeys then
                return true
            end

            local charKey = lossState.charKeys[lossState.charIndex]
            local charData = PSC_DB_IMPORT.PvPLossCounts[charKey]

            if not PSC_DB.PvPLossCounts[charKey] then
                PSC_DB.PvPLossCounts[charKey] = { Deaths = {} }
            end

            if not charData or not charData.Deaths then
                lossState.charIndex = lossState.charIndex + 1
                lossState.deathKeys = nil
                lossState.deathIndex = 1
            else
                if not lossState.deathKeys then
                    lossState.deathKeys = {}
                    for unitName in pairs(charData.Deaths) do
                        table.insert(lossState.deathKeys, unitName)
                    end
                    lossState.deathIndex = 1
                end

                if lossState.deathIndex > #lossState.deathKeys then
                    lossState.charIndex = lossState.charIndex + 1
                    lossState.deathKeys = nil
                    lossState.deathIndex = 1
                else
                    local unitName = lossState.deathKeys[lossState.deathIndex]
                    lossState.deathIndex = lossState.deathIndex + 1

                    local sourceEntry = charData.Deaths[unitName]
                    if sourceEntry then
                        MergeLossEntry(PSC_DB.PvPLossCounts[charKey].Deaths, unitName, sourceEntry, lossState.counters)
                    end
                    processed = processed + 1
                end
            end
        end

        return false
    end

    local function mergeAchievements()
        if PSC_DB_IMPORT.CharacterAchievements then
            if not PSC_DB.CharacterAchievements then PSC_DB.CharacterAchievements = {} end

            for charKey, achievements in pairs(PSC_DB_IMPORT.CharacterAchievements) do
                if not PSC_DB.CharacterAchievements[charKey] then
                    PSC_DB.CharacterAchievements[charKey] = {}
                end
                MergeAchievements(PSC_DB.CharacterAchievements[charKey], achievements)

                if PSC_UpdateTotalAchievementPoints then
                    -- Recalculation happens on load anyway.
                end
            end
        end
        return true
    end

    local function finalizeMigration()
        if PSC_Debug and killState then
            print(string.format("[PvPStats]: Imported %d kills (%d kill keys normalized).", killState.totalImportedKills or 0, killState.counters.normalizedKeys or 0))
        end
        if PSC_Debug and lossState then
            print(string.format("[PvPStats]: Imported %d deaths (%d loss keys normalized, %d assister names normalized).", lossState.counters.importedDeaths or 0, lossState.counters.normalizedKeys or 0, lossState.counters.normalizedAssisters or 0))
        end

        local perCharacterSummary = {}
        if killState and killState.perCharacterImported then
            for charKey, kills in pairs(killState.perCharacterImported) do
                table.insert(perCharacterSummary, { name = charKey, kills = kills })
            end
            table.sort(perCharacterSummary, function(a, b)
                return tostring(a.name) < tostring(b.name)
            end)
        end

        PSC_DB.ImportSummaryPending = {
            totalKills = killState and killState.totalImportedKills or 0,
            perCharacter = perCharacterSummary
        }

        print("[PvPStats]: Data migration complete!")
        print("[PvPStats]: Reloading UI to finalize changes...")

        PSC_DB_IMPORT = nil

        StaticPopupDialogs["PSC_IMPORT_RELOAD"] = {
            text = "PvPStatsClassic: Please reload the UI to complete the import.",
            button1 = "Reload UI",
            OnAccept = function()
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = false,
            preferredIndex = 3,
        }

        StaticPopup_Show("PSC_IMPORT_RELOAD")
    end

    taskQueue = {
        processKillSlice,
        processLossSlice,
        mergeAchievements,
        function()
            finalizeMigration()
            return true
        end
    }

    if runSync then
        local done = false
        while not done do
            done = taskQueue[1]()
        end
        done = false
        while not done do
            done = taskQueue[2]()
        end
        taskQueue[3]()
        taskQueue[4]()
    else
        PSC_RunMigrationTaskQueue(taskQueue)
    end
end

function PSC_CheckForDataMigration()
    if not PSC_DB_IMPORT then return end

    -- Analyze import data for the popup summary
    local charSummaries = {}
    local totalChars = 0

    if PSC_DB_IMPORT.PlayerKillCounts and PSC_DB_IMPORT.PlayerKillCounts.Characters then
        for charKey, charData in pairs(PSC_DB_IMPORT.PlayerKillCounts.Characters) do
            totalChars = totalChars + 1
            local killCount = 0
            if charData.Kills then
                for _, kData in pairs(charData.Kills) do
                    killCount = killCount + (kData.kills or 0)
                end
            end

            local achCount = 0
            if PSC_DB_IMPORT.CharacterAchievements and PSC_DB_IMPORT.CharacterAchievements[charKey] then
                for _, aData in pairs(PSC_DB_IMPORT.CharacterAchievements[charKey]) do
                    if aData.unlocked then achCount = achCount + 1 end
                end
            end

            table.insert(charSummaries, {
                name = charKey,
                kills = killCount,
                achievements = achCount
            })
        end
    end

    if totalChars == 0 then
        -- No valid character data found
        PSC_DB_IMPORT = nil
        return
    end

    -- Build the summary text
    local text = "PvPStatsClassic: Data ready for import!\n\n"
    text = text .. "Data from a previous installation found. Do you want to merge it with your current data?\n\n"
    text = text .. "Found " .. totalChars .. " character(s):\n"

    for _, summary in ipairs(charSummaries) do
        text = text .. string.format("- %s: %d Kills, %d Achievements\n", summary.name, summary.kills, summary.achievements)
    end

    text = text .. "\n\nDuring the import, your game will stutter and it might take up to a minute, depending on the amount of data. Please be patient and don't do anything until it is done."

    StaticPopupDialogs["PSC_IMPORT_CONFIRM"] = {
        text = text,
        button1 = "Yes, Import",
        button2 = "No, Discard data",
        OnAccept = function()
            PSC_PerformDataMigration(false)
        end,
        OnCancel = function()
            PSC_DB_IMPORT = nil
            print("[PvPStats]: Import cancelled. Data discarded.")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show("PSC_IMPORT_CONFIRM")
end

-- Test suite for Data Migration
function PSC_RunMigrationTests()
    if not PSC_Debug then
        print("[PvPStats - Test] Debug mode required.")
        return
    end
    print("[PvPStats - Test] Starting Data Migration Tests...")

    -- Mocks
    local mock_DB = {
        PlayerInfoCache = {},
        PlayerKillCounts = { Characters = {} },
        PvPLossCounts = {},
        CharacterAchievements = {}
    }

    local mock_Import = {
        PlayerInfoCache = {},
        PlayerKillCounts = { Characters = {} },
        PvPLossCounts = {},
        CharacterAchievements = {}
    }

    -- 1. Setup Data
    local charKey = "TestChar-TestRealm"

    -- PlayerInfoCache: Test overriding
    -- Case A: Entry only in Import -> Should Import
    mock_Import.PlayerInfoCache["Old-Realm"] = { class = "Warrior", level = 10 }
    -- Case B: Entry only in DB -> Should Keep
    mock_DB.PlayerInfoCache["Current-Realm"] = { class = "Priest", level = 60 }
    -- Case C: Entry in Both -> Should Keep DB (simulating newer data in DB)
    mock_Import.PlayerInfoCache["Twink-Realm"] = { class = "Mage", level = 19 }
    mock_DB.PlayerInfoCache["Twink-Realm"] = { class = "Mage", level = 29 }

    -- Case D: Entry in Both, but Import has note and DB does not -> Should Copy Note
    mock_Import.PlayerInfoCache["Note-Target"] = { class = "Rogue", level = 60, note = "Imported Note" }
    mock_DB.PlayerInfoCache["Note-Target"] = { class = "Rogue", level = 60 } -- No note

    -- Case E: Cross-Realm Cache (for resolution tests)
    mock_Import.PlayerInfoCache["Ambiguous-RemoteRealm"] = { class = "Druid", level = 60 }
    mock_Import.PlayerInfoCache["LocalHero-TestRealm"] = { class = "Paladin", level = 60 } -- Matches CharKey realm? No, CharKey is "TestChar-TestRealm"
    -- Note: DataStorage.lua uses PSC_GetInfoKeyFromName which defaults to PSC_RealmName if logic fails.
    -- In unit tests, we don't control PSC_RealmName easily unless we mock it or rely on caching.

    -- Kills: Test dupes and merging
    -- Setup: DB has VictimA with 1 kill
    mock_DB.PlayerKillCounts.Characters[charKey] = {
        Kills = {
            ["VictimA"] = { kills = 1, lastKill = 100, killLocations = { { timestamp=100, zone="ZoneA" } }},
            -- Setup for Collision Test: DB has CommonName from Local Realm
            ["CommonName-Local:60"] = { kills = 1, lastKill = 100, killLocations = { { timestamp=100 } } }
        },
        Level1KillTimestamps = { 100 }, -- Sould be cleared on import
        -- Stat merging tests (DB has lower values)
        HighestKillStreak = 5,
        HighestMultiKill = 2,
        SpawnCamperMaxKills = 10,
        GrayKillsCount = 50,
        -- Excluded fields tests
        CurrentKillStreak = 3
    }

    -- Setup: Import has VictimA (duplicate timestamp), VictimA (new timestamp), and VictimB (new victim)
    mock_Import.PlayerKillCounts.Characters[charKey] = {
        Kills = {
            ["VictimA"] = {
                kills = 2,
                lastKill = 150,
                killLocations = {
                    { timestamp=100, zone="ZoneA" }, -- Duplicate
                    { timestamp=150, zone="ZoneA" }  -- New Kill
                }
            },
            ["VictimB"] = {
                kills = 1,
                lastKill = 200,
                killLocations = { { timestamp=200, zone="ZoneB" } }  -- New Victim
            },
            -- Cross-Realm Test 1: Ambiguous Key "Ambiguous:60" should become "Ambiguous-RemoteRealm:60"
            -- because of mock_Import.PlayerInfoCache["Ambiguous-RemoteRealm"]
            ["Ambiguous:60"] = {
                kills = 1, lastKill = 300, killLocations = { { timestamp=300 } }
            },
            -- Cross-Realm Test 2: Collision Test. Import has "CommonName:60".
            -- We pretend Import Cache says it's from "Remote".
            -- Should NOT merge with "CommonName-Local:60".
            ["CommonName:60"] = {
                kills = 1, lastKill = 400, killLocations = { { timestamp=400 } }
            }
        },
        -- Stat merging tests (Import has higher values)
        HighestKillStreak = 10,
        HighestMultiKill = 4,
        SpawnCamperMaxKills = 20,
        GrayKillsCount = 100,
        -- Excluded fields tests
        CurrentKillStreak = 50 -- Should be ignored
    }

    -- Cache entry for Collision Test 2
    mock_Import.PlayerInfoCache["CommonName-Remote"] = { class = "Hunter", level = 60 }


    -- Leaderboard Cache Test (Should be ignored)
    mock_Import.LeaderboardCache = { ["SomeEntry"] = true }
    mock_DB.LeaderboardCache = {}


    -- Loss: Test merging
    -- Setup: DB has KillerA (Time 100)
    mock_DB.PvPLossCounts[charKey] = {
        Deaths = {
            ["KillerA"] = { deaths = 1, deathLocations = { { timestamp = 100 } } }
        }
    }

    mock_Import.PvPLossCounts[charKey] = {
        Deaths = {
            -- Case: New Killer
            ["KillerB"] = { deaths = 1, deathLocations = { { timestamp = 200 } } },
            -- Case: Merge existing killer (Start with duplicate timestamp 100, add new timestamp 300)
            ["KillerA"] = { deaths = 2, deathLocations = {
                { timestamp = 100 }, -- Duplicate
                { timestamp = 300 }  -- New
            }}
        }
    }

    -- Achievements: Test merging
    mock_DB.CharacterAchievements[charKey] = {
        [1] = { unlocked = true, completedDate = "CurrentDate" }, -- Case: Both Unlocked (Keep Current)
        [3] = { unlocked = false } -- Case: DB Locked, Import Unlocked
    }

    mock_Import.CharacterAchievements[charKey] = {
        [1] = { unlocked = true, completedDate = "OldDate" },
        [2] = { unlocked = true },  -- Case: New Achievement
        [3] = { unlocked = true }   -- Case: Upgrade to Unlocked
    }

    -- 2. Swap Globals
    local real_DB = PSC_DB
    local real_Import = PSC_DB_IMPORT
    local real_ReloadUI = ReloadUI

    PSC_DB = mock_DB
    PSC_DB_IMPORT = mock_Import

    local reloadCalled = false
    ReloadUI = function() reloadCalled = true end

    -- 3. Run Migration
    -- Note: We do NOT use PSC_CheckForDataMigration because that creates a popup.
    -- We call PSC_PerformDataMigration directly.
    PSC_PerformDataMigration(true)

    -- 4. Verify Results
    local failed = false
    local function Assert(condition, msg)
        if not condition then
            print("[PvPStats - Test] FAIL: " .. msg)
            failed = true
        end
    end

    -- InfoCache
    Assert(PSC_DB.PlayerInfoCache["Old-Realm"], "Case A: Imported InfoCache missing")
    Assert(PSC_DB.PlayerInfoCache["Current-Realm"], "Case B: Existing InfoCache missing")
    Assert(PSC_DB.PlayerInfoCache["Twink-Realm"].level == 29, "Case C: Existing InfoCache overwritten (level mismatch)")
    Assert(PSC_DB.PlayerInfoCache["Note-Target"].note == "Imported Note", "Case D: Note not merged")

    -- Kills
    local charStats = PSC_DB.PlayerKillCounts.Characters[charKey]
    local kills = charStats.Kills
    -- VictimA: 1 existing + 1 new - 1 duplicate = 2 total
    local vA = kills["VictimA"]
    Assert(vA and vA.kills == 2, "VictimA count wrong (Expected 2, got " .. (vA and vA.kills or "nil") .. ")")
    Assert(vA and #vA.killLocations == 2, "VictimA location count wrong")
    -- Verify sorting (timestamp 100 < 150)
    Assert(vA.killLocations[1].timestamp == 100, "VictimA history not sorted (1)")
    Assert(vA.killLocations[2].timestamp == 150, "VictimA history not sorted (2)")

    -- VictimB: 1 new
    local vB = kills["VictimB"]
    Assert(vB and vB.kills == 1, "VictimB count wrong")

    -- Cross-Realm Test 1: Ambiguous Resolution
    -- Check if "Ambiguous:60" was converted to "Ambiguous-RemoteRealm:60"
    local vAmbig = kills["Ambiguous-RemoteRealm:60"]
    Assert(vAmbig, "Cross-Realm 1: Ambiguous name not resolved to cache realm key")
    Assert(kills["Ambiguous:60"] == nil, "Cross-Realm 1: Old ambiguous key not removed (or still present)")

    -- Cross-Realm Test 2: Collision Avoidance
    -- "CommonName-Local:60" should remain 1 kill. "CommonName-Remote:60" should be new with 1 kill.
    local vLocal = kills["CommonName-Local:60"]
    local vRemote = kills["CommonName-Remote:60"]

    Assert(vLocal and vLocal.kills == 1, "Cross-Realm 2: Local entry modified incorrectly")
    Assert(vRemote and vRemote.kills == 1, "Cross-Realm 2: Remote entry not imported correctly")
    Assert(vLocal ~= vRemote, "Cross-Realm 2: Entries are the same object!")

    -- Summary Stats
    Assert(charStats.HighestKillStreak == 10, "HighestKillStreak not upgraded")
    Assert(charStats.HighestMultiKill == 4, "HighestMultiKill not upgraded")
    Assert(charStats.SpawnCamperMaxKills == 20, "SpawnCamperMaxKills not upgraded")
    Assert(charStats.GrayKillsCount == 100, "GrayKillsCount not upgraded")

    -- Excluded Fields (Should NOT change)
    Assert(charStats.CurrentKillStreak == 3, "CurrentKillStreak was overwritten (should be ignored)")
    Assert(next(PSC_DB.LeaderboardCache) == nil, "LeaderboardCache was imported (should be ignored)")
    Assert(charStats.Level1KillTimestamps == nil, "Level1KillTimestamps should be cleared for rebuild")

    -- Assertions: Losses
    print("[PvPStats - Test] Checking Losses...")
    Assert(PSC_DB.PvPLossCounts[charKey].Deaths["KillerA"], "Existing killer should persist")
    Assert(PSC_DB.PvPLossCounts[charKey].Deaths["KillerA"].deaths == 2, "Merged killer should have 2 deaths (1 existing + 1 new - 1 duplicate)")
    Assert(PSC_DB.PvPLossCounts[charKey].Deaths["KillerB"], "New killer should be added")

    -- Assertions: Achievements
    print("[PvPStats - Test] Checking Achievements...")
    Assert(PSC_DB.CharacterAchievements[charKey][2], "New achievement should be added")
    Assert(PSC_DB.CharacterAchievements[charKey][1].completedDate == "CurrentDate", "Existing achievement should not be overwritten by older import")
    Assert(PSC_DB.CharacterAchievements[charKey][3].unlocked == true, "Achievement should upgrade from Locked to Unlocked")

    -- Reload & Cleanup
    Assert(reloadCalled, "ReloadUI not triggered")
    Assert(PSC_DB_IMPORT == nil, "PSC_DB_IMPORT not cleared")

    -- 5. Restore Globals
    PSC_DB = real_DB
    PSC_DB_IMPORT = real_Import
    ReloadUI = real_ReloadUI

    if not failed then
        print("[PvPStats - Test] ALL TESTS PASSED.")
    end
end
