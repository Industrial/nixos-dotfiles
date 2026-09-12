-- Common data helper functions for PvPStatsClassic
-- These functions centralize common data operations used throughout the addon

function PSC_GetCurrentZoneName()
    local function IsValidZoneName(value)
        return value and value ~= ""
    end

    local realZone = GetRealZoneText()
    if IsValidZoneName(realZone) then
        return PSC_ConvertZoneToEnglish(realZone)
    end

    local minimapZone = GetMinimapZoneText()
    if IsValidZoneName(minimapZone) then
        return PSC_ConvertZoneToEnglish(minimapZone)
    end

    local zoneText = GetZoneText()
    if IsValidZoneName(zoneText) then
        return PSC_ConvertZoneToEnglish(zoneText)
    end

    local subZone = GetSubZoneText()
    if IsValidZoneName(subZone) then
        return PSC_ConvertZoneToEnglish(subZone)
    end

    local instanceName, instanceType = GetInstanceInfo()

    if IsValidZoneName(instanceName) then
        return PSC_ConvertZoneToEnglish(instanceName)
    end

    return "Unknown"
end

-- Get the list of characters to process based on account-wide setting
function PSC_GetCharactersToProcessForStatistics()
    local charactersToProcess = {}

    if PSC_DB.ShowAccountWideStats then
        -- Process all characters
        for charKey, charData in pairs(PSC_DB.PlayerKillCounts.Characters) do
            charactersToProcess[charKey] = charData
        end
    else
        -- Process only the current character
        local characterKey = PSC_GetCharacterKey()
        if PSC_DB.PlayerKillCounts.Characters[characterKey] then
            charactersToProcess[characterKey] = PSC_DB.PlayerKillCounts.Characters[characterKey]
        end
    end

    return charactersToProcess
end

-- Get death data from all relevant characters.
-- characterScope: optional table with charKeys as keys; if provided, restricts to those characters
-- regardless of the ShowAccountWideStats setting (used for network responses scoped to one character).
function PSC_GetDeathDataFromAllCharacters(characterScope)
    local deathDataByPlayer = {}

    local charactersToProcess = {}
    if characterScope then
        for charKey in pairs(characterScope) do
            charactersToProcess[charKey] = true
        end
    elseif PSC_DB.ShowAccountWideStats then
        for charKey, _ in pairs(PSC_DB.PvPLossCounts) do
            charactersToProcess[charKey] = true
        end
    else
        local characterKey = PSC_GetCharacterKey()
        charactersToProcess[characterKey] = true
    end

    -- Collect death data from all relevant characters
    for charKey, _ in pairs(charactersToProcess) do
        local lossData = PSC_DB.PvPLossCounts[charKey]
        if lossData and lossData.Deaths then
            for killerName, deathData in pairs(lossData.Deaths) do
                if not deathDataByPlayer[killerName] then
                    deathDataByPlayer[killerName] = {
                        deaths = 0,
                        deathLocations = {}
                    }
                end

                -- Add death count
                deathDataByPlayer[killerName].deaths = deathDataByPlayer[killerName].deaths + (deathData.deaths or 0)

                -- Add death locations
                if deathData.deathLocations then
                    for _, location in ipairs(deathData.deathLocations) do
                        table.insert(deathDataByPlayer[killerName].deathLocations, location)
                    end
                end
            end
        end
    end

    return deathDataByPlayer
end

-- Find a player's most recent death location in deathData
function PSC_GetPlayerMostRecentDeathInfo(deathData)
    local zone = "Unknown"
    local lastKill = 0

    if deathData.deathLocations and #deathData.deathLocations > 0 then
        -- Sort death locations by timestamp descending (most recent first)
        table.sort(deathData.deathLocations, function(a, b)
            return (a.timestamp or 0) > (b.timestamp or 0)
        end)

        -- Get zone from most recent death location
        zone = deathData.deathLocations[1].zone or zone
        lastKill = deathData.deathLocations[1].timestamp or lastKill
    end

    -- Fallback to top-level fields when deathLocations is absent or empty
    -- (can happen for legacy records whose location list was never populated)
    if zone == "Unknown" and deathData.zone and deathData.zone ~= "" and deathData.zone ~= "Unknown" then
        zone = deathData.zone
    end
    if lastKill == 0 and (deathData.lastDeath or 0) > 0 then
        lastKill = deathData.lastDeath
    end

    return zone, lastKill
end

-- Count assists from a player
function PSC_CountPlayerAssists(playerName, deathDataByPlayer)
    local assistCount = 0
    local assistData = {
        assists = 0,
        lastAssist = 0,
        zone = "Unknown"
    }

    for _, deathData in pairs(deathDataByPlayer) do
        if deathData.deathLocations then
            for _, location in ipairs(deathData.deathLocations) do
                if location.assisters then
                    for _, assister in ipairs(location.assisters) do
                        if PSC_IsSamePlayerName(assister.name, playerName) then
                            assistCount = assistCount + 1
                            assistData.assists = assistData.assists + 1

                            -- Update latest assist timestamp and zone if more recent
                            if (location.timestamp or 0) > assistData.lastAssist then
                                assistData.lastAssist = location.timestamp or 0
                                assistData.zone = location.zone or "Unknown"
                            end
                        end
                    end
                end
            end
        end
    end

    return assistCount, assistData
end

-- Function to sort player entries by a given column/field
function PSC_SortPlayerEntries(entries, sortBy, ascending)
    if sortBy then
        table.sort(entries, function(a, b)
            local aValue = a[sortBy]
            local bValue = b[sortBy]

            -- Special handling for level sorting - convert to numbers for proper comparison
            if sortBy == "levelDisplay" then
                local aLevel = tonumber(aValue) or -1
                local bLevel = tonumber(bValue) or -1

                if ascending then
                    return aLevel < bLevel
                else
                    return aLevel > bLevel
                end
            end

            -- Special case for numeric values vs nil
            if type(aValue) == "number" and type(bValue) == "number" then
                if ascending then
                    return aValue < bValue
                else
                    return aValue > bValue
                end
            end

            -- Handle string comparison
            if ascending then
                return tostring(aValue or "") < tostring(bValue or "")
            else
                return tostring(aValue or "") > tostring(bValue or "")
            end
        end)
    end

    return entries
end

-- Function to add or update a player entry in the entries table
function PSC_AddOrUpdatePlayerEntry(playerNameMap, entries, name, entry)
    if not playerNameMap[name] then
        playerNameMap[name] = entry
        table.insert(entries, entry)
    else
        local existingEntry = playerNameMap[name]
        existingEntry.kills = existingEntry.kills + entry.kills

        -- Keep the most recent kill timestamp and data
        if entry.lastKill > (existingEntry.lastKill or 0) then
            existingEntry.lastKill = entry.lastKill
            existingEntry.zone = entry.zone
            existingEntry.levelDisplay = entry.levelDisplay
            existingEntry.rank = entry.rank
        end

        -- Store details of all kills for the detail view
        if not existingEntry.killHistory then
            existingEntry.killHistory = {}
        end

        if not entry.includedInHistory then
            table.insert(existingEntry.killHistory, {
                level = entry.levelDisplay,
                zone = entry.zone,
                timestamp = entry.lastKill,
                rank = entry.rank,
                kills = entry.kills
            })
            entry.includedInHistory = true
        end
    end
end
