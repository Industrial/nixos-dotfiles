local addonName, PVPSC = ...

PSC_LeaderboardFrame = nil

PSC_SortLeaderboardBy = "totalKills"
PSC_SortLeaderboardAscending = false
local LEADERBOARD_FRAME_WIDTH = 1150
local LEADERBOARD_FRAME_HEIGHT = 550

PSC_LeaderboardFrameInitialSetup = true

local PSC_LeaderboardDataCache = nil
local PSC_LeaderboardRowDropDown = nil
local PSC_FilterRecentSyncOnly = false
local PSC_ShowOwnAlts = true
local PSC_LeaderboardShowAll = false
local LEADERBOARD_RECENT_SYNC_WINDOW_SECONDS = 1800 -- 30 minutes

local function GetLeaderboardEntryUniqueName(entry)
    if not entry then return nil end
    local name = entry.rawName or entry.playerName
    if not name or name == "" then return nil end
    if not string.find(name, "%-") then
        local realmName = entry.realm or PSC_RealmName
        if realmName and realmName ~= "" then
            name = name .. "-" .. realmName
        end
    end
    return name
end

local function IsLocalLeaderboardEntry(entry)
    local playerName = UnitName("player")
    local localRealm = PSC_RealmName
    local uniqueName = GetLeaderboardEntryUniqueName(entry)
    if not uniqueName then return false end
    if uniqueName == playerName then return true end
    if localRealm and uniqueName == (playerName .. "-" .. localRealm) then return true end
    return false
end

local function RemoveLeaderboardEntry(entryOrName)
    if not entryOrName then return end

    local candidates = {}
    local function addCandidate(name)
        if name and name ~= "" then
            candidates[name] = true
        end
    end

    if type(entryOrName) == "table" then
        local entry = entryOrName
        addCandidate(entry.rawName)
        addCandidate(entry.playerName)
        addCandidate(GetLeaderboardEntryUniqueName(entry))

        if entry.rawName and string.find(entry.rawName, "%-") then
            local baseName = strsplit("-", entry.rawName)
            addCandidate(baseName)
        end
        if entry.playerName and string.find(entry.playerName, "%-") then
            local baseName = strsplit("-", entry.playerName)
            addCandidate(baseName)
        end
    else
        addCandidate(entryOrName)
    end

    if PVPSC and PVPSC.Network and PVPSC.Network.sharedData then
        for name, _ in pairs(candidates) do
            PVPSC.Network.sharedData[name] = nil
        end
    end

    if PVPSC and PVPSC.Network and PVPSC.Network.ownAltData then
        for name, _ in pairs(candidates) do
            PVPSC.Network.ownAltData[name] = nil
        end
    end

    if PSC_DB and PSC_DB.LeaderboardCache then
        for name, _ in pairs(candidates) do
            PSC_DB.LeaderboardCache[name] = nil
        end
    end

    PSC_LeaderboardDataCache = nil
    RefreshLeaderboardFrame()
end

local function RemoveOfflineLeaderboardEntries()
    if not PSC_DB or not PSC_DB.LeaderboardCache then return end

    local localPlayerName = UnitName("player")
    local localRealm = PSC_RealmName
    local sharedData = (PVPSC and PVPSC.Network and PVPSC.Network.sharedData) or {}

    local ownCharacters = {}
    if PSC_DB.PlayerKillCounts and PSC_DB.PlayerKillCounts.Characters then
        for characterKey, _ in pairs(PSC_DB.PlayerKillCounts.Characters) do
            ownCharacters[characterKey] = true
        end
    end

    local function IsOwnCharacterEntry(cacheName)
        if not cacheName or cacheName == "" then
            return false
        end

        if ownCharacters[cacheName] then
            return true
        end

        if not string.find(cacheName, "%-") and localRealm then
            return ownCharacters[cacheName .. "-" .. localRealm] == true
        end

        return false
    end

    for cacheName, _ in pairs(PSC_DB.LeaderboardCache) do
        local isLocal = cacheName == localPlayerName or (localRealm and cacheName == (localPlayerName .. "-" .. localRealm))
        local isLive = sharedData[cacheName] ~= nil
        local isOwnCharacter = IsOwnCharacterEntry(cacheName)
        if not isLocal and not isLive and not isOwnCharacter then
            PSC_DB.LeaderboardCache[cacheName] = nil
        end
    end

    PSC_LeaderboardDataCache = nil
    RefreshLeaderboardFrame()
end

local function IsEntryRecentlySynced(entry)
    if not entry then return false end

    if IsLocalLeaderboardEntry(entry) then
        return true
    end

    local lastSeen = tonumber(entry.lastSeen) or 0
    if lastSeen <= 0 then
        return false
    end

    local now = GetServerTime and GetServerTime() or time()
    return (now - lastSeen) <= LEADERBOARD_RECENT_SYNC_WINDOW_SECONDS
end

local function ApplyLeaderboardFilters(entries)
    if not PSC_FilterRecentSyncOnly then
        return entries
    end

    local filtered = {}
    for _, entry in ipairs(entries) do
        if IsEntryRecentlySynced(entry) then
            table.insert(filtered, entry)
        end
    end

    return filtered
end

if not StaticPopupDialogs["PSC_REMOVE_OFFLINE_LEADERBOARD"] then
    StaticPopupDialogs["PSC_REMOVE_OFFLINE_LEADERBOARD"] = {
        text = "Do you really want to remove all saved entries for offline players from your leaderboard? This cannot be undone.",
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            RemoveOfflineLeaderboardEntries()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }
end

if not StaticPopupDialogs["PSC_SEND_STATS_TO_PLAYER"] then
    StaticPopupDialogs["PSC_SEND_STATS_TO_PLAYER"] = {
        text = "Enter the player name to send your stats to:",
        button1 = "Send",
        button2 = "Cancel",
        hasEditBox = true,
        maxLetters = 50,
        OnAccept = function(self)
            local editBox = self.editBox or _G[self:GetName().."EditBox"]
            if not editBox then return end

            local playerName = editBox:GetText()
            if playerName and playerName ~= "" then
                local normalized = PVPSC.Network:NormalizeTargetName(playerName)
                if not normalized or normalized == "" then
                    PSC_Print("Invalid player name.")
                    return
                end

                local sent, _, reason = PVPSC.Network:SendStatsToPlayer(normalized)
                if not sent then
                    PSC_Print("Failed to send stats: " .. (reason or "Unknown error"))
                else
                    PSC_Print("Stats sent to " .. normalized .. ". They will only receive them if they have addon version 4.2 or higher.")
                end
            end
        end,
        OnShow = function(self)
            -- Bring popup to foreground
            self:SetFrameStrata("FULLSCREEN_DIALOG")
            self:SetFrameLevel(1000)
            self:Raise()

            local editBox = self.editBox or _G[self:GetName().."EditBox"]
            if editBox then
                editBox:SetFocus()
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            if parent and parent.button1 and parent.button1:IsEnabled() then
                parent.button1:Click()
            end
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 1,
        exclusive = false,
    }
end

local colWidths = {
    position = 32,
    playerName = 202,
    level = 30,
    class = 65,
    race = 75,
    totalKills = 55,
    uniqueKills = 55,
    kdRatio = 50,
    currentStreak = 55,
    bestStreak = 55,
    mostKilled = 115,
    avgPerDay = 50,
    achievements = 70,
    achievementPoints = 55,
    addonVersion = 60,
    lastSeen = 130
}

local function CleanupFrameElements(content)
    local children = {content:GetChildren()}
    for _, child in pairs(children) do
        child:Hide()
        child:SetParent(nil)
        child = nil
    end

    local regions = {content:GetRegions()}
    for _, region in pairs(regions) do
        region:Hide()
        region:ClearAllPoints()
        region:SetParent(nil)
        region = nil
    end
end

local function SetHeaderButtonHighlight(button, enter)
    local fontString = button:GetFontString()
    if (fontString) then
        fontString:SetTextColor(enter and 1 or 1, enter and 1 or 0.82, enter and 0.5 or 0)
    end
end

local function CreateColumnHeader(parent, text, width, anchor, xOffset, yOffset, columnId)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 24)

    if anchor == nil then
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
    else
        button:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 0, 0)
    end

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()

    button:SetScript("OnClick", function()
        if PSC_SortLeaderboardBy == columnId then
            PSC_SortLeaderboardAscending = not PSC_SortLeaderboardAscending
        else
            PSC_SortLeaderboardBy = columnId
            PSC_SortLeaderboardAscending = false
        end
        RefreshLeaderboardFrame(true)
    end)

    local header = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("LEFT", 3, 0)
    header:SetTextColor(1, 0.82, 0)
    header:SetWidth(width - 6)
    header:SetJustifyH("LEFT")

    header:SetText(text)

    if PSC_SortLeaderboardBy == columnId then
        local sortIndicator = PSC_SortLeaderboardAscending and " ^" or " v"
        header:SetText(text .. sortIndicator)
    end

    button:SetFontString(header)

    button:SetScript("OnEnter", function(self)
        SetHeaderButtonHighlight(self, true)

        -- Add tooltips for specific columns
        if columnId == "totalKills" then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Total Kills", 1, 0.82, 0)
            GameTooltip:AddLine("The total number of PvP kills this player has recorded", 1, 1, 1, true)
            GameTooltip:Show()
        elseif columnId == "uniqueKills" then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Unique Players Killed", 1, 0.82, 0)
            GameTooltip:AddLine("The number of unique players killed", 1, 1, 1, true)
            GameTooltip:Show()
        elseif columnId == "kdRatio" then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Kill/Death Ratio", 1, 0.82, 0)
            GameTooltip:AddLine("Total kills divided by total deaths", 1, 1, 1, true)
            GameTooltip:Show()
        elseif columnId == "currentStreak" then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Current Streak", 1, 0.82, 0)
            GameTooltip:AddLine("The player's current active kill streak", 1, 1, 1, true)
            GameTooltip:Show()
        elseif columnId == "bestStreak" then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Best Streak", 1, 0.82, 0)
            GameTooltip:AddLine("The highest kill streak this player has achieved", 1, 1, 1, true)
            GameTooltip:Show()
        elseif columnId == "mostKilled" then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Most Killed", 1, 0.82, 0)
            GameTooltip:AddLine("The player this person has killed the most", 1, 1, 1, true)
            GameTooltip:Show()
        elseif columnId == "avgPerDay" then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Average Kills Per Day", 1, 0.82, 0)
            GameTooltip:AddLine("Average kills per day since first recorded kill", 1, 1, 1, true)
            GameTooltip:Show()
        elseif columnId == "achievements" then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Achievements Unlocked", 1, 0.82, 0)
            GameTooltip:AddLine("The number of PvP achievements this player has unlocked", 1, 1, 1, true)
            GameTooltip:Show()
        elseif columnId == "achievementPoints" then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Achievement Points", 1, 0.82, 0)
            GameTooltip:AddLine("Total achievement points earned by this player", 1, 1, 1, true)
            GameTooltip:Show()
        elseif columnId == "addonVersion" then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Addon Version", 1, 0.82, 0)
            GameTooltip:AddLine("The version of PvP Stats Classic this player is using", 1, 1, 1, true)
            GameTooltip:Show()
        elseif columnId == "lastSeen" then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Last Seen", 1, 0.82, 0)
            GameTooltip:AddLine("Time passed since this player last updated their stats.", 1, 1, 1, true)
            GameTooltip:AddLine("Note: This timestamp only updates when the player records a new kill/event, not continuously.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        elseif columnId == "realm" then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Realm", 1, 0.82, 0)
            GameTooltip:AddLine("The realm this character belongs to.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)

    button:SetScript("OnLeave", function(self)
        SetHeaderButtonHighlight(self, false)
        GameTooltip:Hide()
    end)

    return button
end

local function CreateColumnHeaders(content)
    -- Add a background texture behind all the headers to create a unified header row
    local headerRowBg = content:CreateTexture(nil, "BACKGROUND")
    headerRowBg:SetPoint("TOPLEFT", 10, 0)
    headerRowBg:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, 0)
    headerRowBg:SetHeight(24)
    headerRowBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

    local positionButton = CreateColumnHeader(content, "#", colWidths.position, nil, 10, 0, "position")
    local playerNameButton = CreateColumnHeader(content, "Name", colWidths.playerName, positionButton, 0, 0, "playerName")
    -- Realm column removed
    local levelButton = CreateColumnHeader(content, "Lvl", colWidths.level, playerNameButton, 0, 0, "level")
    local raceButton = CreateColumnHeader(content, "Race", colWidths.race, levelButton, 0, 0, "race")
    local classButton = CreateColumnHeader(content, "Class", colWidths.class, raceButton, 0, 0, "class")
    local totalKillsButton = CreateColumnHeader(content, "Kills", colWidths.totalKills, classButton, 0, 0, "totalKills")
    local uniqueKillsButton = CreateColumnHeader(content, "Unique", colWidths.uniqueKills, totalKillsButton, 0, 0, "uniqueKills")
    local kdRatioButton = CreateColumnHeader(content, "K/D", colWidths.kdRatio, uniqueKillsButton, 0, 0, "kdRatio")
    local currentStreakButton = CreateColumnHeader(content, "Streak", colWidths.currentStreak, kdRatioButton, 0, 0, "currentStreak")
    local bestStreakButton = CreateColumnHeader(content, "Best Streak", colWidths.bestStreak, currentStreakButton, 0, 0, "bestStreak")
    local mostKilledButton = CreateColumnHeader(content, "Most Killed", colWidths.mostKilled, bestStreakButton, 0, 0, "mostKilled")
    local avgPerDayButton = CreateColumnHeader(content, "Avg/Day", colWidths.avgPerDay, mostKilledButton, 0, 0, "avgPerDay")
    local achievementsButton = CreateColumnHeader(content, "Achiev.", colWidths.achievements, avgPerDayButton, 0, 0, "achievements")
    local achievementPointsButton = CreateColumnHeader(content, "Achiev. Points", colWidths.achievementPoints, achievementsButton, 0, 0, "achievementPoints")
    local addonVersionButton = CreateColumnHeader(content, "Version", colWidths.addonVersion, achievementPointsButton, 0, 0, "addonVersion")
    local lastSeenButton = CreateColumnHeader(content, "Last Seen", colWidths.lastSeen, addonVersionButton, 0, 0, "lastSeen")

    return -30
end

local function CreatePlacementCell(content, position, width)
    local positionText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    positionText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    positionText:SetText(position and tostring(position) .. "." or "?.")
    positionText:SetWidth(width)
    positionText:SetJustifyH("LEFT")
    return positionText
end

local function CreatePlayerNameCell(content, playerName, width, anchorTo, positionOffset)
    local nameText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if anchorTo and positionOffset then
        nameText:SetPoint("TOPLEFT", content, "TOPLEFT", positionOffset, 0)
    elseif anchorTo then
        nameText:SetPoint("LEFT", anchorTo, "RIGHT", 0, 0)
    else
        nameText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    end

    -- Show full name (Name-Realm)
    local displayText = playerName
    if not displayText or displayText == "" then displayText = "Unknown" end

    nameText:SetText(displayText)
    nameText:SetWidth(width)
    nameText:SetJustifyH("LEFT")
    return nameText
end

local function CreateLevelCell(content, anchorTo, level, width)
    local levelText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    levelText:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 0, 0)
    levelText:SetText(tostring(level or "??"))
    levelText:SetWidth(width)
    levelText:SetJustifyH("LEFT")
    return levelText
end

local function CreateClassCell(content, anchorTo, className, width)
    local classText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    classText:SetPoint("LEFT", anchorTo, "RIGHT", 0, 0)

    classText:SetText(className or "Unknown")
    classText:SetWidth(width)
    classText:SetJustifyH("LEFT")
    return classText
end

local function CreateRaceCell(content, anchorTo, raceName, width)
    local raceText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    raceText:SetPoint("LEFT", anchorTo, "RIGHT", 0, 0)

    raceText:SetText(raceName or "Unknown")
    raceText:SetWidth(width)
    raceText:SetJustifyH("LEFT")
    return raceText
end

local function CreateTotalKillsCell(content, anchorTo, totalKills, width)
    local killsText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    killsText:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 0, 0)
    killsText:SetText(tostring(totalKills or 0))
    killsText:SetWidth(width)
    killsText:SetJustifyH("LEFT")
    return killsText
end

local function CreateUniqueKillsCell(content, anchorTo, uniqueKills, width)
    local uniqueText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    uniqueText:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 0, 0)
    uniqueText:SetText(tostring(uniqueKills or 0))
    uniqueText:SetWidth(width)
    uniqueText:SetJustifyH("LEFT")
    return uniqueText
end

local function CreateKDRatioCell(content, anchorTo, kdRatio, width)
    local kdText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    kdText:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 0, 0)
    kdText:SetText(kdRatio or "0.00")
    kdText:SetWidth(width)
    kdText:SetJustifyH("LEFT")
    return kdText
end

local function CreateCurrentStreakCell(content, anchorTo, currentStreak, width)
    local streakText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    streakText:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 0, 0)
    streakText:SetText(tostring(currentStreak or 0))
    streakText:SetWidth(width)
    streakText:SetJustifyH("LEFT")
    return streakText
end

local function CreateBestStreakCell(content, anchorTo, bestStreak, width)
    local streakText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    streakText:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 0, 0)
    streakText:SetText(tostring(bestStreak or 0))
    streakText:SetWidth(width)
    streakText:SetJustifyH("LEFT")
    return streakText
end

local function CreateMostKilledCell(content, anchorTo, mostKilled, width)
    local mostKilledText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mostKilledText:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 0, 0)

    -- Strip realm info for display
    local displayData = mostKilled or "None"
    local namePart, countPart = displayData:match("^(.-)%s*(%b())$")
    if not namePart then
        namePart = displayData
        countPart = ""
    end

    local cleanName = namePart
    if string.find(cleanName, "-") then
        cleanName = strsplit("-", cleanName)
    end

    if countPart ~= "" then
        cleanName = cleanName .. " " .. countPart
    end

    mostKilledText:SetText(cleanName)
    mostKilledText:SetWidth(width)
    mostKilledText:SetJustifyH("LEFT")
    return mostKilledText
end

local function CreateAvgPerDayCell(content, anchorTo, avgPerDay, width)
    local avgText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    avgText:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 0, 0)
    avgText:SetText(avgPerDay or "0.0")
    avgText:SetWidth(width)
    avgText:SetJustifyH("LEFT")
    return avgText
end

local function CreateAchievementsCell(content, anchorTo, achievements, width)
    local achievementsText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    achievementsText:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 0, 0)
    achievementsText:SetText(tostring(achievements or 0))
    achievementsText:SetWidth(width)
    achievementsText:SetJustifyH("LEFT")
    return achievementsText
end

local function CreateAchievementPointsCell(content, anchorTo, achievementPoints, width)
    local pointsText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pointsText:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 0, 0)
    pointsText:SetText(tostring(achievementPoints or 0))
    pointsText:SetWidth(width)
    pointsText:SetJustifyH("LEFT")
    return pointsText
end

local function CreateAddonVersionCell(content, anchorTo, addonVersion, width)
    local versionText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    versionText:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 0, 0)
    versionText:SetText(addonVersion or "Unknown")
    versionText:SetWidth(width)
    versionText:SetJustifyH("LEFT")
    return versionText
end

local function CreateLastSeenCell(content, anchorTo, timestamp, width)
    local lastSeenText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lastSeenText:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 0, 0)

    -- Use server time for relative comparison since the timestamp comes from the network
    local timeString = PSC_GetTimeAgo(timestamp, true)

    lastSeenText:SetText(timeString)
    lastSeenText:SetWidth(width)
    lastSeenText:SetJustifyH("LEFT")
    lastSeenText:SetTextColor(0.6, 0.8, 1.0) -- Soft blue color like KillsListFrame

    return lastSeenText
end

local function CreateEntryRow(content, entry, yOffset, colWidths, isAlternate)
    local rowContainer = CreateFrame("Button", nil, content)
    rowContainer:SetSize(content:GetWidth() - 20, 16)
    rowContainer:SetPoint("TOPLEFT", 10, yOffset)

    if isAlternate then
        local bgTexture = rowContainer:CreateTexture(nil, "BACKGROUND")
        bgTexture:SetAllPoints()
        bgTexture:SetColorTexture(0.05, 0.05, 0.05, 0.3)
    end

    -- Only show highlight if interaction is available
    if entry.hasDetailedStats or entry.playerName == UnitName("player") then
        local highlightTexture = PSC_CreateGoldHighlight(rowContainer, 16)
    end

    local positionCell = CreatePlacementCell(rowContainer, entry.position or 0, colWidths.position)
    local playerNameCell = CreatePlayerNameCell(rowContainer, entry.playerName, colWidths.playerName, positionCell, colWidths.position + 3)
    local levelCell = CreateLevelCell(rowContainer, playerNameCell, entry.level, colWidths.level)
    local raceCell = CreateRaceCell(rowContainer, levelCell, entry.race, colWidths.race)
    local classCell = CreateClassCell(rowContainer, raceCell, entry.class, colWidths.class)
    local totalKillsCell = CreateTotalKillsCell(rowContainer, classCell, entry.totalKills, colWidths.totalKills)
    local uniqueKillsCell = CreateUniqueKillsCell(rowContainer, totalKillsCell, entry.uniqueKills, colWidths.uniqueKills)
    local kdRatioCell = CreateKDRatioCell(rowContainer, uniqueKillsCell, entry.kdRatio, colWidths.kdRatio)
    local currentStreakCell = CreateCurrentStreakCell(rowContainer, kdRatioCell, entry.currentStreak, colWidths.currentStreak)
    local bestStreakCell = CreateBestStreakCell(rowContainer, currentStreakCell, entry.bestStreak, colWidths.bestStreak)
    local mostKilledCell = CreateMostKilledCell(rowContainer, bestStreakCell, entry.mostKilled, colWidths.mostKilled)
    local avgPerDayCell = CreateAvgPerDayCell(rowContainer, mostKilledCell, entry.avgPerDay, colWidths.avgPerDay)
    local achievementsCell = CreateAchievementsCell(rowContainer, avgPerDayCell, entry.achievements, colWidths.achievements)
    local achievementPointsCell = CreateAchievementPointsCell(rowContainer, achievementsCell, entry.achievementPoints, colWidths.achievementPoints)
    local addonVersionCell = CreateAddonVersionCell(rowContainer, achievementPointsCell, entry.addonVersion, colWidths.addonVersion)
    local lastSeenCell = CreateLastSeenCell(rowContainer, addonVersionCell, entry.lastSeen, colWidths.lastSeen)

    -- Apply class color to name like in KillsListFrame
    if entry.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class:upper()] then
        local color = RAID_CLASS_COLORS[entry.class:upper()]
        playerNameCell:SetTextColor(color.r, color.g, color.b)
    end

    -- If cross-realm, maybe add a subtle hint if not explicitly distinguishing via text?
    -- The playerName already contains "-Realm" if it was set in NetworkHandler.
    -- We can verify this and perhaps color the realm part differently if we wanted to get fancy,
    -- but for now the text modification in NetworkHandler handles the display requirement.

    -- If no detailed stats available (cached only), gray out the text
    if not entry.hasDetailedStats and entry.rawName ~= UnitName("player") then
        local gray = 0.5
        playerNameCell:SetTextColor(gray, gray, gray)
        levelCell:SetTextColor(gray, gray, gray)
        classCell:SetTextColor(gray, gray, gray)
        raceCell:SetTextColor(gray, gray, gray)
        totalKillsCell:SetTextColor(gray, gray, gray)
        uniqueKillsCell:SetTextColor(gray, gray, gray)
        kdRatioCell:SetTextColor(gray, gray, gray)
        currentStreakCell:SetTextColor(gray, gray, gray)
        bestStreakCell:SetTextColor(gray, gray, gray)
        mostKilledCell:SetTextColor(gray, gray, gray)
        avgPerDayCell:SetTextColor(gray, gray, gray)
        achievementsCell:SetTextColor(gray, gray, gray)
        achievementPointsCell:SetTextColor(gray, gray, gray)
        addonVersionCell:SetTextColor(gray, gray, gray)
        lastSeenCell:SetTextColor(gray, gray, gray)
    end

    -- Add click handler to view player's detailed stats
    rowContainer:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            local playerName = entry.rawName or entry.playerName
            if not playerName or playerName == "" then
                return
            end

            -- Check if it's the local player
            if playerName == UnitName("player") then
                -- Just open our own statistics frame
                PSC_CreateStatisticsFrame()
                return
            end

            -- Only attempt to open if we have detailed stats
            if entry.hasDetailedStats then
                -- Retrieve detailed stats from cache
                if PVPSC.Network and PVPSC.Network.GetDetailedStatsForPlayer then
                    local detailedStats = PVPSC.Network:GetDetailedStatsForPlayer(playerName)
                    if detailedStats then
                        -- Display the detailed stats
                        PSC_ShowPlayerDetailedStats(entry.playerName, detailedStats)
                    end
                end
            end
        end
    end)

    -- Register right click for context menu
    rowContainer:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    rowContainer:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            if IsLocalLeaderboardEntry(entry) then
                return
            end

            if not PSC_LeaderboardRowDropDown then
                PSC_LeaderboardRowDropDown = CreateFrame("Frame", "PSC_LeaderboardRowDropDown", UIParent, "UIDropDownMenuTemplate")
            end

            UIDropDownMenu_Initialize(PSC_LeaderboardRowDropDown, function(self, level)
                local info = UIDropDownMenu_CreateInfo()
                local displayName = entry.playerName or entry.rawName or "Player"

                -- Add "Send stats to" option
                info.text = "Send stats to " .. displayName
                info.notCheckable = true
                info.func = function()
                    local targetName = entry.rawName or entry.playerName
                    if targetName and targetName ~= "" then
                        local normalized = PVPSC.Network:NormalizeTargetName(targetName)
                        if normalized and normalized ~= "" then
                            local sent, _, reason = PVPSC.Network:SendStatsToPlayer(normalized)
                            if not sent then
                                PSC_Print("Failed to send stats: " .. (reason or "Unknown error"))
                            else
                                PSC_Print("Stats sent to " .. normalized .. ". They will only receive them if they have addon version 4.2 or higher.")
                            end
                        end
                    end
                end
                UIDropDownMenu_AddButton(info)

                -- Add separator
                info = UIDropDownMenu_CreateInfo()
                info.text = ""
                info.isTitle = true
                info.notCheckable = true
                info.disabled = true
                UIDropDownMenu_AddButton(info)

                -- Add "Remove from Leaderboard" option
                info = UIDropDownMenu_CreateInfo()
                info.text = "Remove " .. displayName .. " from Leaderboard"
                info.notCheckable = true
                info.func = function()
                    RemoveLeaderboardEntry(entry)
                end
                UIDropDownMenu_AddButton(info)
            end, "MENU")

            ToggleDropDownMenu(1, nil, PSC_LeaderboardRowDropDown, self, 0, 0)
            PSC_LeaderboardRowDropDown._justOpened = true
            C_Timer.After(0, function()
                if PSC_LeaderboardRowDropDown then
                    PSC_LeaderboardRowDropDown._justOpened = nil
                end
            end)
            return
        end
    end)

    -- Grey out row to indicate reduced functionality if no details available
    -- Actually, don't grey out the whole row as the data is still valid,
    -- just maybe don't highlight as strongly on hover or handle tooltip.
    -- But since we use Gold Highlight, maybe we just leave visual as is and rely on tooltip.

    -- Add tooltip to indicate clickability
    rowContainer:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(entry.playerName or "Unknown", 1, 0.82, 0)

        if entry.rawName == UnitName("player") then
            GameTooltip:AddLine("Click to view your detailed statistics", 1, 1, 1, true)
        elseif entry.hasDetailedStats then
            GameTooltip:AddLine("Click to view this player's detailed statistics", 1, 1, 1, true)
        else
             GameTooltip:AddLine("Detailed statistics currently unavailable.", 1, 0.5, 0.5, true)
             GameTooltip:AddLine("This player is currently not near you, or in your party/raid/guild.", 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)

    rowContainer:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    return rowContainer
end

local function GetLeaderboardData()
    -- Use network handler to get all leaderboard data (local + shared)
    -- This function was refactored to prioritize unified logic via Network:GetAllLeaderboardData()
    -- The fallback logic was merged into the main block to avoid duplication
    local leaderboardData = {}

    -- Attempt to get data from Network handler
    local netData = nil
    if PVPSC.Network and PVPSC.Network.GetAllLeaderboardData then
        netData = PVPSC.Network:GetAllLeaderboardData(PSC_ShowOwnAlts)
    end

    -- If network didn't return data (or empty), simulate a local-only result
    -- by calling the same BuildDetailedStats function the Network handler uses for local stats.
    if not netData or #netData == 0 then
        if PVPSC.Network and PVPSC.Network.BuildDetailedStats then
            local localStats = PVPSC.Network:BuildDetailedStats()
            if localStats then
                 netData = { localStats }
            end
        end
    end

    if netData and #netData > 0 then
         -- Transform network data into display format
         for _, data in ipairs(netData) do
             -- Data coming from network might have nested summary or flattened fields
             -- If keys are missing at root, check if they exist in summary table
             local statsTarget = data
             if data.summary then
                 statsTarget = data.summary
             end

             local currentStreak = data.currentKillStreak or statsTarget.currentKillStreak
             local bestStreak = data.highestKillStreak or statsTarget.highestKillStreak
             local avgPerDayVal = data.avgKillsPerDay or statsTarget.avgKillsPerDay

             local mostKilledVal = data.mostKilledPlayer or statsTarget.mostKilledPlayer or "None"
             local mostKilledCount = data.mostKilledCount or statsTarget.mostKilledCount or 0

             if mostKilledVal ~= "None" and mostKilledCount > 0 then
                 mostKilledVal = mostKilledVal .. " (" .. mostKilledCount .. ")"
             else
                 mostKilledVal = "None"
             end

             local avgPerDayStr = "0.0"
             if avgPerDayVal and tonumber(avgPerDayVal) then
                 avgPerDayStr = string.format("%.1f", tonumber(avgPerDayVal))
             end

             local kills = data.totalKills or statsTarget.totalKills or 0
             local deaths = data.totalDeaths or statsTarget.totalDeaths or 0
             local kdRatioVal = PSC_FormatKDRatio(kills, deaths)

             local acUnlocked = data.achievementsUnlocked or 0
             local acTotal = data.totalAchievements or (PVPSC.AchievementSystem and PVPSC.AchievementSystem.achievements and #PVPSC.AchievementSystem.achievements) or 0
             local achievementText = acUnlocked .. "/" .. acTotal

             -- Check if we have detailed stats for this player
             -- We can use Network handler to verify if this player is in cache/live or just summary cache
             local isDetailedAvailable = false
             if data.isOwnAlt then
                 -- Own alts are intentionally treated as offline entries in the leaderboard.
                 isDetailedAvailable = false
             elseif data.playerName == UnitName("player") then
                 isDetailedAvailable = true
             elseif PVPSC.Network and PVPSC.Network.GetDetailedStatsForPlayer then
                 -- GetDetailedStatsForPlayer should support lookup by the unique name (Name-Realm)
                 if PVPSC.Network:GetDetailedStatsForPlayer(data.playerName) then
                     isDetailedAvailable = true
                 end
             end

             -- Construct display name with realm if missing (for display purposes only)
             local displayName = data.playerName or "Unknown"
             local realmName = data.realm or PSC_RealmName
             if realmName and realmName ~= "" and not string.find(displayName, "-") then
                 displayName = displayName .. "-" .. realmName
             end

             local raceVal = data.race or "Unknown"
             if raceVal == "Scourge" then raceVal = "Undead" end

             table.insert(leaderboardData, {
                 playerName = displayName,
                 rawName = data.playerName, -- Store original name for data lookup
                 -- We now store the true realm in the data object if available, though playerName might be "Name-Realm"
                 realm = realmName,
                 level = data.level or 0,
                 class = data.class or "Unknown",
                 race = raceVal,
                 totalKills = kills,
                 uniqueKills = data.uniqueKills or statsTarget.uniqueKills or 0,
                 kdRatio = kdRatioVal,
                 currentStreak = currentStreak or 0,
                 bestStreak = bestStreak or 0,
                 mostKilled = mostKilledVal,
                 _mostKilledCount = mostKilledCount,
                 avgPerDay = avgPerDayStr,
                 achievements = achievementText,
                 achievementPoints = data.achievementPoints or 0,
                 addonVersion = data.addonVersion or "Unknown",
                 lastSeen = data.timestamp or 0,
                 hasDetailedStats = isDetailedAvailable
             })
         end
    end

    return leaderboardData
end


local function SortLeaderboardData(data)
    local sortedData = {}
    for _, entry in pairs(data) do
        table.insert(sortedData, entry)
    end

    table.sort(sortedData, function(a, b)
        -- Special handling for Most Killed column to sort by count
        if PSC_SortLeaderboardBy == "mostKilled" then
            local aCount = a._mostKilledCount or 0
            local bCount = b._mostKilledCount or 0
            if aCount ~= bCount then
                if PSC_SortLeaderboardAscending then
                    return aCount < bCount
                else
                    return aCount > bCount
                end
            end
        end

        -- Special handling for Addon Version (Semantic Versioning)
        if PSC_SortLeaderboardBy == "addonVersion" then
            local cmp = PSC_CompareAddonVersions(a.addonVersion, b.addonVersion)
            if cmp ~= 0 then
                if PSC_SortLeaderboardAscending then
                    return cmp < 0
                else
                    return cmp > 0
                end
            end
        end

        local aVal = a[PSC_SortLeaderboardBy]
        local bVal = b[PSC_SortLeaderboardBy]

        if aVal == nil then aVal = "" end
        if bVal == nil then bVal = "" end

        -- Enhanced comparison: Try to treat strings as numbers if possible (fixes "28.0" > "207.0")
        local aNum = tonumber(aVal)
        local bNum = tonumber(bVal)

        if aNum and bNum then
            aVal = aNum
            bVal = bNum
        else
            -- Fallback for non-numeric or mixed types: convert to string
            if type(aVal) ~= type(bVal) then
                aVal = tostring(aVal)
                bVal = tostring(bVal)
            end
        end

        if PSC_SortLeaderboardAscending then
            return aVal < bVal
        else
            return aVal > bVal
        end
    end)

    for index, entry in ipairs(sortedData) do
        entry.position = index
    end

    return sortedData
end

local function DisplayEntries(content, sortedEntries, yOffset)
    local count = 0
    local maxEntries = PSC_LeaderboardShowAll and math.huge or 100

    if #sortedEntries == 0 then
        local noDataText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        noDataText:SetPoint("TOPLEFT", 10, yOffset - 20)
        if PSC_FilterRecentSyncOnly then
            noDataText:SetText("No recently synced players found.")
        else
            noDataText:SetText("No leaderboard data available yet.")
        end
        noDataText:SetTextColor(1, 1, 1)
        return yOffset - 40, count
    end

    for i, entry in ipairs(sortedEntries) do
        if count >= maxEntries then
            break
        end

        local isAlternate = (i % 2 == 0)
        CreateEntryRow(content, entry, yOffset, colWidths, isAlternate)
        yOffset = yOffset - 18
        count = count + 1
    end

    if #sortedEntries > 100 then
        local moreText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        moreText:SetPoint("TOPLEFT", 10, yOffset - 10)

        if PSC_LeaderboardShowAll then
            moreText:SetText("Showing all " .. #sortedEntries .. " entries.")
        else
            moreText:SetText("Showing " .. count .. " of " .. #sortedEntries .. " entries.")
        end

        moreText:SetTextColor(1, 0.7, 0)
        yOffset = yOffset - 20

        local actionButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        actionButton:SetSize(110, 22)
        actionButton:SetPoint("TOPLEFT", moreText, "BOTTOMLEFT", 0, -6)

        if PSC_LeaderboardShowAll then
            actionButton:SetText("Show top 100")
            actionButton:SetScript("OnClick", function()
                PSC_LeaderboardShowAll = false
                RefreshLeaderboardFrame(true)
            end)
        else
            actionButton:SetText("Show all")
            actionButton:SetScript("OnClick", function()
                PSC_LeaderboardShowAll = true
                RefreshLeaderboardFrame(true)
            end)
        end

        yOffset = yOffset - 28
    end

    return yOffset, count
end

local function CreateScrollFrame(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 45)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(LEADERBOARD_FRAME_WIDTH - 40, LEADERBOARD_FRAME_HEIGHT * 2)
    scrollFrame:SetScrollChild(content)

    return content
end

local function CreateMainFrame()
    local frame = CreateFrame("Frame", "PSC_LeaderboardStatsFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(LEADERBOARD_FRAME_WIDTH, LEADERBOARD_FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    table.insert(UISpecialFrames, "PSC_LeaderboardStatsFrame")
    frame.TitleText:SetText("PvP Stats Leaderboard")

    -- Override close button to work in combat
    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            PSC_FrameManager:HideFrame("Leaderboard")
        end)
    end

    return frame
end


function RefreshLeaderboardFrame(useCache)
    if PSC_LeaderboardFrameInitialSetup then
        return
    end

    if PSC_LeaderboardFrame == nil then
        return
    end

    local content = PSC_LeaderboardFrame.content
    if not content then
        return
    end

    CleanupFrameElements(content)

    local yOffset = CreateColumnHeaders(content)

    local leaderboardData
    if useCache and PSC_LeaderboardDataCache then
        leaderboardData = PSC_LeaderboardDataCache
    else
        leaderboardData = GetLeaderboardData()
        PSC_LeaderboardDataCache = leaderboardData
    end

    local filteredEntries = ApplyLeaderboardFilters(leaderboardData)
    local sortedEntries = SortLeaderboardData(filteredEntries)
    local finalYOffset, entryCount = DisplayEntries(content, sortedEntries, yOffset)

    content:SetHeight(math.max((-finalYOffset + 20), LEADERBOARD_FRAME_HEIGHT - 50))
end

function PSC_CreateLeaderboardFrame()
    if (PSC_LeaderboardFrame) then
        PSC_FrameManager:ShowFrame("Leaderboard")
        RefreshLeaderboardFrame()
        return
    end

    PSC_LeaderboardFrame = CreateMainFrame()
    PSC_LeaderboardFrame.content = CreateScrollFrame(PSC_LeaderboardFrame)

    local function CloseLeaderboardContextMenu()
        if PSC_LeaderboardRowDropDown and PSC_LeaderboardRowDropDown:IsShown() then
            if CloseDropDownMenus then
                CloseDropDownMenus()
            elseif HideDropDownMenu then
                HideDropDownMenu(1)
            end
        end
    end

    PSC_LeaderboardFrame:SetScript("OnHide", function()
        CloseLeaderboardContextMenu()
    end)

    PSC_LeaderboardFrame:SetScript("OnMouseDown", function()
        CloseLeaderboardContextMenu()
    end)

    if PSC_LeaderboardFrame.content then
        PSC_LeaderboardFrame.content:SetScript("OnMouseDown", function()
            CloseLeaderboardContextMenu()
        end)
    end

    local removeOfflineButton = CreateFrame("Button", nil, PSC_LeaderboardFrame, "UIPanelButtonTemplate")
    removeOfflineButton:SetSize(170, 25)
    removeOfflineButton:SetPoint("BOTTOMLEFT", PSC_LeaderboardFrame, "BOTTOMRIGHT", -197, 10)
    removeOfflineButton:SetText("Remove offline players")
    removeOfflineButton:SetScript("OnClick", function()
        StaticPopup_Show("PSC_REMOVE_OFFLINE_LEADERBOARD")
    end)
    PSC_LeaderboardFrame.removeOfflineButton = removeOfflineButton

    local sendStatsButton = CreateFrame("Button", nil, PSC_LeaderboardFrame, "UIPanelButtonTemplate")
    sendStatsButton:SetSize(130, 25)
    sendStatsButton:SetPoint("BOTTOMLEFT", removeOfflineButton, "BOTTOMLEFT", -140, 0)
    sendStatsButton:SetText("Send Stats To...")
    sendStatsButton:SetScript("OnClick", function()
        StaticPopup_Show("PSC_SEND_STATS_TO_PLAYER")
    end)
    PSC_LeaderboardFrame.sendStatsButton = sendStatsButton

    local recentSyncCheckbox = CreateFrame("CheckButton", nil, PSC_LeaderboardFrame, "UICheckButtonTemplate")
    recentSyncCheckbox:SetSize(20, 20)
    recentSyncCheckbox:SetPoint("RIGHT", sendStatsButton, "LEFT", -120, 0)
    recentSyncCheckbox:SetChecked(PSC_FilterRecentSyncOnly)

    if PSC_DB.ShowOwnAltsOnLeaderboard == nil then
        PSC_DB.ShowOwnAltsOnLeaderboard = true
    end
    PSC_ShowOwnAlts = PSC_DB.ShowOwnAltsOnLeaderboard

    local showAltsCheckbox = CreateFrame("CheckButton", nil, PSC_LeaderboardFrame, "UICheckButtonTemplate")
    showAltsCheckbox:SetSize(20, 20)
    showAltsCheckbox:SetPoint("RIGHT", recentSyncCheckbox, "LEFT", -88, 0)
    showAltsCheckbox:SetChecked(PSC_ShowOwnAlts)

    local showAltsLabel = PSC_LeaderboardFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    showAltsLabel:SetPoint("LEFT", showAltsCheckbox, "RIGHT", 2, 0)
    showAltsLabel:SetText("Show your alts")
    showAltsLabel:SetTextColor(1, 0.82, 0)

    local recentSyncLabel = PSC_LeaderboardFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recentSyncLabel:SetPoint("LEFT", recentSyncCheckbox, "RIGHT", 2, 0)
    recentSyncLabel:SetText("Recently synced only")
    recentSyncLabel:SetTextColor(1, 0.82, 0)

    local infoText = PSC_LeaderboardFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("LEFT", recentSyncCheckbox, "LEFT", -655, 0)
    infoText:SetText("Leaderboard syncs with nearby players and guild/party/raid members who have this addon installed")
    infoText:SetTextColor(0.7, 0.7, 0.7)
    infoText:SetJustifyH("RIGHT")
    PSC_LeaderboardFrame.infoText = infoText

    local function ShowRecentSyncTooltip(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_TOP")
        GameTooltip:SetText("Recently synced only", 1, 0.82, 0)
        GameTooltip:AddLine("Hide players whose last sync is older than 30 minutes.", 1, 1, 1, true)
        GameTooltip:AddLine("Your own character is always shown.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end

    local function ShowOwnAltsTooltip(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_TOP")
        GameTooltip:SetText("Show your alts", 1, 0.82, 0)
        GameTooltip:AddLine("Show leaderboard entries for your own characters from this account.", 1, 1, 1, true)
        GameTooltip:AddLine("Only alts that logged in at least once with addon version v4.4 or later are shown.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end

    showAltsCheckbox:SetScript("OnClick", function(self)
        PSC_ShowOwnAlts = self:GetChecked()
        PSC_DB.ShowOwnAltsOnLeaderboard = PSC_ShowOwnAlts
        PSC_LeaderboardDataCache = nil
        RefreshLeaderboardFrame()
    end)

    showAltsCheckbox:SetScript("OnEnter", function(self)
        ShowOwnAltsTooltip(self)
    end)

    showAltsCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    showAltsLabel:SetScript("OnEnter", function(self)
        ShowOwnAltsTooltip(self)
    end)

    showAltsLabel:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    recentSyncCheckbox:SetScript("OnClick", function(self)
        PSC_FilterRecentSyncOnly = self:GetChecked()
        RefreshLeaderboardFrame(true)
    end)

    recentSyncCheckbox:SetScript("OnEnter", function(self)
        ShowRecentSyncTooltip(self)
    end)

    recentSyncCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    recentSyncLabel:SetScript("OnEnter", function(self)
        ShowRecentSyncTooltip(self)
    end)

    recentSyncLabel:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    PSC_LeaderboardFrame.recentSyncCheckbox = recentSyncCheckbox
    PSC_LeaderboardFrame.recentSyncLabel = recentSyncLabel
    PSC_LeaderboardFrame.showAltsCheckbox = showAltsCheckbox
    PSC_LeaderboardFrame.showAltsLabel = showAltsLabel

    PSC_FrameManager:RegisterFrame(PSC_LeaderboardFrame, "Leaderboard")

    for i = #UISpecialFrames, 1, -1 do
        if (UISpecialFrames[i] == "PSC_LeaderboardStatsFrame") then
            table.remove(UISpecialFrames, i)
            break
        end
    end

    C_Timer.After(0.01, function()
        PSC_LeaderboardFrameInitialSetup = false
        RefreshLeaderboardFrame()
    end)
end

