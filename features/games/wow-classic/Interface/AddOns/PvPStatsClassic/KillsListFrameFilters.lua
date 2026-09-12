PSC_SearchText = ""
local levelSearchText = ""
local classSearchText = ""
local raceSearchText = ""
local genderSearchText = ""
local zoneSearchText = ""
local rankSearchText = ""
local minLevelSearch = nil
local maxLevelSearch = nil
local minRankSearch = nil
local maxRankSearch = nil
local filterOnlyWithNotes = false
local filterMinDeaths = 0


local function CreateBoxBorder(box)
    local border = {}

    border.top = box:CreateTexture(nil, "BACKGROUND")
    border.top:SetHeight(1)
    border.top:SetPoint("TOPLEFT", box, "TOPLEFT", -1, 1)
    border.top:SetPoint("TOPRIGHT", box, "TOPRIGHT", 1, 1)
    border.top:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    border.bottom = box:CreateTexture(nil, "BACKGROUND")
    border.bottom:SetHeight(1)
    border.bottom:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", -1, -1)
    border.bottom:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 1, -1)
    border.bottom:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    border.left = box:CreateTexture(nil, "BACKGROUND")
    border.left:SetWidth(1)
    border.left:SetPoint("TOPLEFT", border.top, "TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", border.bottom, "BOTTOMLEFT", 0, 0)
    border.left:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    border.right = box:CreateTexture(nil, "BACKGROUND")
    border.right:SetWidth(1)
    border.right:SetPoint("TOPRIGHT", border.top, "TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", border.bottom, "BOTTOMRIGHT", 0, 0)
    border.right:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    return border
end

local function ParseLevelSearch(text)
    minLevelSearch = nil
    maxLevelSearch = nil

    if text == "" then
        return true
    end

    if text == "??" then
        minLevelSearch = -1
        maxLevelSearch = -1
        return true
    end

    local min, max = text:match("^(%d+)-(%d+)$")
    if min and max then
        min = tonumber(min)
        max = tonumber(max)
        if min and max and min <= max and min >= 1 and max <= 70 then
            minLevelSearch = min
            maxLevelSearch = max
            return true
        end
        return false
    end

    local level = tonumber(text)
    if level and level >= 1 and level <= 70 then
        minLevelSearch = level
        maxLevelSearch = level
        return true
    end

    return false
end

local function ParseRankSearch(text)
    minRankSearch = nil
    maxRankSearch = nil

    if text == "" then
        return true
    end

    local min, max = text:match("^(%d+)-(%d+)$")
    if min and max then
        min = tonumber(min)
        max = tonumber(max)
        if min and max and min <= max and min >= 0 and max <= 14 then
            minRankSearch = min
            maxRankSearch = max
            return true
        end
        return false
    end

    local rank = tonumber(text)
    if rank and rank >= 0 and rank <= 14 then
        minRankSearch = rank
        maxRankSearch = rank
        return true
    end

    return false
end

local function CreateLevelSearchBox(parent, anchorTo)
    local levelSearchBox = CreateFrame("EditBox", nil, parent)
    levelSearchBox:SetSize(60, 20)
    levelSearchBox:SetPoint("LEFT", anchorTo, "RIGHT", 20, 0)
    levelSearchBox:SetAutoFocus(false)
    levelSearchBox:SetMaxLetters(5)
    levelSearchBox:SetFontObject("ChatFontNormal")

    local searchBoxBg = levelSearchBox:CreateTexture(nil, "BACKGROUND")
    ---@diagnostic disable-next-line: param-type-mismatch
    searchBoxBg:SetAllPoints(true)
    searchBoxBg:SetColorTexture(0, 0, 0, 0.5)

    CreateBoxBorder(levelSearchBox)
    levelSearchBox:SetTextInsets(5, 5, 2, 2)

    return levelSearchBox
end

local function SetupLevelSearchBoxScripts(levelSearchBox)
    levelSearchBox:SetScript("OnTextChanged", function(self)
        levelSearchText = self:GetText()
        if ParseLevelSearch(levelSearchText) then
            self:SetTextColor(1, 1, 1)
            RefreshKillsListFrame()
        else
            self:SetTextColor(1, 0.3, 0.3)
        end
    end)

    levelSearchBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    levelSearchBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
    end)

    levelSearchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText("")
        levelSearchText = ""
        minLevelSearch = nil
        maxLevelSearch = nil
        RefreshKillsListFrame()
    end)

    levelSearchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    levelSearchBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Level filter")
        GameTooltip:AddLine("Enter a single level (e.g. 70)", 1, 1, 1, true)
        GameTooltip:AddLine("Or a range (e.g. 30-40)", 1, 1, 1, true)
        GameTooltip:AddLine("Or ?? for unknown levels", 1, 1, 1, true)
        GameTooltip:AddLine("Press ESC to clear filter", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    levelSearchBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function PSC_CreateEditBox(parent, anchorTo)
    local searchBox = CreateFrame("EditBox", nil, parent)
    searchBox:SetSize(200, 20)
    searchBox:SetPoint("LEFT", anchorTo, "RIGHT", 8, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    searchBox:SetFontObject("ChatFontNormal")

    local searchBoxBg = searchBox:CreateTexture(nil, "BACKGROUND")
    ---@diagnostic disable-next-line: param-type-mismatch
    searchBoxBg:SetAllPoints(true)
    searchBoxBg:SetColorTexture(0, 0, 0, 0.5)

    CreateBoxBorder(searchBox)

    searchBox:SetTextInsets(5, 5, 2, 2)

    return searchBox
end

local function PSC_SetupSearchBoxScripts(searchBox)
    searchBox:SetScript("OnTextChanged", function(self)
        PSC_SearchText = self:GetText():lower()
        RefreshKillsListFrame()
    end)

    searchBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    searchBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
    end)

    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText("")
        PSC_SearchText = ""
        RefreshKillsListFrame()
    end)

    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    searchBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Player/Guild filter")
        GameTooltip:AddLine("Type to filter by player name or guild", 1, 1, 1, true)
        GameTooltip:AddLine("Press ESC to clear filter", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    searchBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function PSC_CreateClassSearchBox(parent, anchorTo)
    local classSearchBox = CreateFrame("EditBox", nil, parent)
    classSearchBox:SetSize(60, 20)
    classSearchBox:SetPoint("LEFT", anchorTo, "RIGHT", 10, 0)
    classSearchBox:SetAutoFocus(false)
    classSearchBox:SetMaxLetters(10)
    classSearchBox:SetFontObject("ChatFontNormal")

    local searchBoxBg = classSearchBox:CreateTexture(nil, "BACKGROUND")
    ---@diagnostic disable-next-line: param-type-mismatch
    searchBoxBg:SetAllPoints(true)
    searchBoxBg:SetColorTexture(0, 0, 0, 0.5)

    CreateBoxBorder(classSearchBox)
    classSearchBox:SetTextInsets(5, 5, 2, 2)

    return classSearchBox
end

local function PSC_SetupClassSearchBoxScripts(classSearchBox)
    classSearchBox:SetScript("OnTextChanged", function(self)
        classSearchText = self:GetText()
        RefreshKillsListFrame()
    end)

    classSearchBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    classSearchBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
    end)

    classSearchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText("")
        classSearchText = ""
        RefreshKillsListFrame()
    end)

    classSearchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    classSearchBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Class filter")
        GameTooltip:AddLine("Type to filter by class name", 1, 1, 1, true)
        GameTooltip:AddLine("Press ESC to clear filter", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    classSearchBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function PSC_CreateRaceSearchBox(parent, anchorTo)
    local raceSearchBox = CreateFrame("EditBox", nil, parent)
    raceSearchBox:SetSize(60, 20)
    raceSearchBox:SetPoint("LEFT", anchorTo, "RIGHT", 10, 0)
    raceSearchBox:SetAutoFocus(false)
    raceSearchBox:SetMaxLetters(10)
    raceSearchBox:SetFontObject("ChatFontNormal")

    local searchBoxBg = raceSearchBox:CreateTexture(nil, "BACKGROUND")
    ---@diagnostic disable-next-line: param-type-mismatch
    searchBoxBg:SetAllPoints(true)
    searchBoxBg:SetColorTexture(0, 0, 0, 0.5)

    CreateBoxBorder(raceSearchBox)
    raceSearchBox:SetTextInsets(5, 5, 2, 2)

    return raceSearchBox
end

local function PSC_SetupRaceSearchBoxScripts(raceSearchBox)
    raceSearchBox:SetScript("OnTextChanged", function(self)
        raceSearchText = self:GetText()
        RefreshKillsListFrame()
    end)

    raceSearchBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    raceSearchBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
    end)

    raceSearchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText("")
        raceSearchText = ""
        RefreshKillsListFrame()
    end)

    raceSearchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    raceSearchBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Race filter")
        GameTooltip:AddLine("Type to filter by race name", 1, 1, 1, true)
        GameTooltip:AddLine("Press ESC to clear filter", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    raceSearchBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function PSC_CreateGenderSearchBox(parent, anchorTo)
    local genderSearchBox = CreateFrame("EditBox", nil, parent)
    genderSearchBox:SetSize(20, 20)
    genderSearchBox:SetPoint("LEFT", anchorTo, "RIGHT", 10, 0)
    genderSearchBox:SetAutoFocus(false)
    genderSearchBox:SetMaxLetters(1)  -- Limit to a single character
    genderSearchBox:SetFontObject("ChatFontNormal")

    local searchBoxBg = genderSearchBox:CreateTexture(nil, "BACKGROUND")
    ---@diagnostic disable-next-line: param-type-mismatch
    searchBoxBg:SetAllPoints(true)
    searchBoxBg:SetColorTexture(0, 0, 0, 0.5)

    CreateBoxBorder(genderSearchBox)
    genderSearchBox:SetTextInsets(5, 5, 2, 2)

    return genderSearchBox
end

local function PSC_SetupGenderSearchBoxScripts(genderSearchBox)
    genderSearchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText():lower()

        -- Only accept "m" or "f" as input
        if text ~= "" and text ~= "m" and text ~= "f" then
            self:SetText("")
            self:SetTextColor(1, 0.3, 0.3)  -- Red text to indicate invalid input
            return
        else
            self:SetTextColor(1, 1, 1)  -- Reset to white text for valid input
        end

        -- Set the search text based on input
        if text == "m" then
            genderSearchText = "male"
        elseif text == "f" then
            genderSearchText = "female"
        else
            genderSearchText = ""
        end

        RefreshKillsListFrame()
    end)

    genderSearchBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    genderSearchBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)

        -- Format display for better user feedback
        local text = self:GetText():lower()
        if text == "m" then
            self:SetText("M")
        elseif text == "f" then
            self:SetText("F")
        end
    end)

    genderSearchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText("")
        genderSearchText = ""
        RefreshKillsListFrame()
    end)

    genderSearchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    genderSearchBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Gender filter")
        GameTooltip:AddLine("Enter 'm' for male characters", 1, 1, 1, true)
        GameTooltip:AddLine("Enter 'f' for female characters", 1, 1, 1, true)
        GameTooltip:AddLine("Leave empty to show all genders", 1, 1, 1, true)
        GameTooltip:AddLine("Press ESC to clear filter", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    genderSearchBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function PSC_CreateZoneSearchBox(parent, anchorTo)
    local zoneSearchBox = CreateFrame("EditBox", nil, parent)
    zoneSearchBox:SetSize(140, 20)
    zoneSearchBox:SetPoint("LEFT", anchorTo, "RIGHT", 5, 0)
    zoneSearchBox:SetAutoFocus(false)
    zoneSearchBox:SetMaxLetters(25)
    zoneSearchBox:SetFontObject("ChatFontNormal")

    local searchBoxBg = zoneSearchBox:CreateTexture(nil, "BACKGROUND")
    ---@diagnostic disable-next-line: param-type-mismatch
    searchBoxBg:SetAllPoints(true)
    searchBoxBg:SetColorTexture(0, 0, 0, 0.5)

    CreateBoxBorder(zoneSearchBox)
    zoneSearchBox:SetTextInsets(5, 5, 2, 2)

    return zoneSearchBox
end

local function PSC_SetupZoneSearchBoxScripts(zoneSearchBox)
    zoneSearchBox:SetScript("OnTextChanged", function(self)
        zoneSearchText = self:GetText()
        RefreshKillsListFrame()
    end)

    zoneSearchBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    zoneSearchBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
    end)

    zoneSearchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText("")
        zoneSearchText = ""
        RefreshKillsListFrame()
    end)

    zoneSearchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    zoneSearchBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Zone filter")
        GameTooltip:AddLine("Type to filter by zone name", 1, 1, 1, true)
        GameTooltip:AddLine("Press ESC to clear filter", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    zoneSearchBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function PSC_CreateRankSearchBox(parent, anchorTo)
    local rankSearchBox = CreateFrame("EditBox", nil, parent)
    rankSearchBox:SetSize(50, 20)
    rankSearchBox:SetPoint("LEFT", anchorTo, "RIGHT", 10, 0)
    rankSearchBox:SetAutoFocus(false)
    rankSearchBox:SetMaxLetters(5)
    rankSearchBox:SetFontObject("ChatFontNormal")

    local searchBoxBg = rankSearchBox:CreateTexture(nil, "BACKGROUND")
    ---@diagnostic disable-next-line: param-type-mismatch
    searchBoxBg:SetAllPoints(true)
    searchBoxBg:SetColorTexture(0, 0, 0, 0.5)

    CreateBoxBorder(rankSearchBox)
    rankSearchBox:SetTextInsets(5, 5, 2, 2)

    return rankSearchBox
end

local function PSC_SetupRankSearchBoxScripts(rankSearchBox)
    rankSearchBox:SetScript("OnTextChanged", function(self)
        rankSearchText = self:GetText()
        if ParseRankSearch(rankSearchText) then
            self:SetTextColor(1, 1, 1)
            RefreshKillsListFrame()
        else
            self:SetTextColor(1, 0.3, 0.3)
        end
    end)

    rankSearchBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    rankSearchBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
    end)

    rankSearchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText("")
        rankSearchText = ""
        minRankSearch = nil
        maxRankSearch = nil
        RefreshKillsListFrame()
    end)

    rankSearchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    rankSearchBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Rank filter")
        GameTooltip:AddLine("Enter a single rank (e.g. 8)", 1, 1, 1, true)
        GameTooltip:AddLine("Or a range (e.g. 5-10)", 1, 1, 1, true)
        GameTooltip:AddLine("Press ESC to clear filter", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    rankSearchBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function PSC_CreateSearchBackground(parent)
    local searchBg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    searchBg:SetPoint("BOTTOMLEFT", 1, 1)
    searchBg:SetPoint("BOTTOMRIGHT", -1, 1)
    searchBg:SetHeight(40)

    if searchBg.SetBackdrop then
        searchBg:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = {
                left = 4,
                right = 4,
                top = 4,
                bottom = 4
            }
        })
        searchBg:SetBackdropColor(0, 0, 0, 0.4)
    else
        local bg = searchBg:CreateTexture(nil, "BACKGROUND")
        ---@diagnostic disable-next-line: param-type-mismatch
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.4)
    end

    return searchBg
end

-- Helper function to add or update a player entry in the entries table
local function AddOrUpdatePlayerEntry(playerNameMap, entries, name, entry)
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

-- Get the list of characters to process based on account-wide setting
local function GetCharactersToProcessForStatistics()
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

-- Get death data from all relevant characters
local function GetDeathDataFromAllCharacters()
    local deathDataByPlayer = {}

    -- Get characters to process based on account-wide setting
    local charactersToProcess = {}
    if PSC_DB.ShowAccountWideStats then
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

-- Process and collect all players you have killed
local function ProcessKilledPlayers(searchText, playerNameMap, entries, resolveName, canonicalizeName, getLatestLocation)
    local charactersToProcess = GetCharactersToProcessForStatistics()

    for charKey, charData in pairs(charactersToProcess) do
        for nameWithLevel, killData in pairs(charData.Kills or {}) do
            local name = string.match(nameWithLevel, "(.-)%:")
            if name then
                local level = tonumber(string.match(nameWithLevel, ":(%d+)") or "-1") or -1

                -- Get player info from cache if available (supports cross-realm fallback)
                local playerInfo, infoKey = resolveName(name)

                -- Always canonicalize to Name-Realm for consistent keys
                local canonicalName = canonicalizeName(name, infoKey)

                local playerClass = playerInfo.class or "Unknown"
                local playerRace = playerInfo.race or "Unknown"
                local playerGender = playerInfo.gender or "Unknown"
                local playerGuild = playerInfo.guild or ""
                local playerRank = playerInfo.rank or 0

                -- Only add if matches search criteria - only search name and guild for the player/guild filter
                     if searchText == "" or
                         canonicalName:lower():find(searchText, 1, true) or
                         playerGuild:lower():find(searchText, 1, true) then

                    -- Convert lastKill to number to ensure it's properly handled
                    local lastKillTimestamp = tonumber(killData.lastKill) or 0

                    -- Make sure we get the zone data properly
                    local killZone = killData.zone

                    -- Check all possible location storage formats without sorting
                    if killZone == nil then
                        killZone = getLatestLocation(killData)
                    end

                    local entry = {
                        name = canonicalName,
                        class = playerClass,
                        race = playerRace,
                        gender = playerGender,
                        levelDisplay = playerInfo.level or level,
                        rank = playerRank,
                        guild = playerGuild,
                        zone = killZone or "Unknown",
                        kills = killData.kills or 0,
                        lastKill = lastKillTimestamp, -- Make sure it's a number
                        levelAtKill = level,
                        originalKillData = killData
                    }

                    AddOrUpdatePlayerEntry(playerNameMap, entries, canonicalName, entry)
                end
            end
        end
    end
end

-- Process players who have killed you but you haven't killed
local function ProcessEnemyKillers(searchText, playerNameMap, entries, deathDataByPlayer, resolveName, canonicalizeName)
    for killerName, deathData in pairs(deathDataByPlayer) do
        -- Get player info from cache (supports cross-realm fallback)
        local playerInfo, infoKey = resolveName(killerName)

        -- Always canonicalize to Name-Realm for consistent keys
        local entryName = canonicalizeName(killerName, infoKey)

        if not playerNameMap[entryName] then

            local playerClass = playerInfo.class or "Unknown"
            local playerRace = playerInfo.race or "Unknown"
            local playerGender = playerInfo.gender or "Unknown"
            local playerGuild = playerInfo.guild or ""
            local playerLevel = tonumber(playerInfo.level) or -1  -- Ensure it's a number
            local playerRank = playerInfo.rank or 0

            -- Find the most recent zone from death locations
            local zone = "Unknown"
            local lastKill = 0

            if deathData.deathLocations and #deathData.deathLocations > 0 then
                local latestTimestamp = 0
                for _, location in ipairs(deathData.deathLocations) do
                    local ts = location.timestamp or 0
                    if ts > latestTimestamp then
                        latestTimestamp = ts
                        zone = location.zone or zone
                        lastKill = ts
                    end
                end
            end

            -- Fallback to top-level fields when deathLocations is empty
            if lastKill == 0 and (deathData.lastDeath or 0) > 0 then
                lastKill = deathData.lastDeath
            end
            if zone == "Unknown" and deathData.zone and deathData.zone ~= "" and deathData.zone ~= "Unknown" then
                zone = deathData.zone
            end

            -- Only add if matches search criteria - only search name and guild
                if searchText == "" or
                    entryName:lower():find(searchText, 1, true) or
                    playerGuild:lower():find(searchText, 1, true) then

                local entry = {
                    name = entryName,
                    class = playerClass,
                    race = playerRace,
                    gender = playerGender,
                    levelDisplay = playerLevel,  -- Store as number for consistent sorting
                    rank = playerRank,
                    guild = playerGuild,
                    zone = zone,
                    kills = 0,
                    lastKill = lastKill,
                    deaths = deathData.deaths or 0,
                    deathHistory = deathData.deathLocations or {}
                }

                playerNameMap[entryName] = entry
                table.insert(entries, entry)
            end
        end
    end
end

-- Process players who have only assisted in kills but never directly killed you
local function ProcessAssistOnlyPlayers(searchText, playerNameMap, entries, assistCounts, lastAssistTimestamp, lastAssistZone, resolveName, canonicalizeName)
    -- Create entries for players who assisted but never killed you directly
    for assisterName, assistCount in pairs(assistCounts) do
        -- Get player info from cache (supports cross-realm fallback)
        local playerInfo, infoKey = resolveName(assisterName)

        -- Always canonicalize to Name-Realm for consistent keys
        local entryName = canonicalizeName(assisterName, infoKey)

        -- Skip if already added from kills or deaths
        if not playerNameMap[entryName] then

            local playerClass = playerInfo.class or "Unknown"
            local playerRace = playerInfo.race or "Unknown"
            local playerGender = playerInfo.gender or "Unknown"
            local playerGuild = playerInfo.guild or ""
            local playerLevel = tonumber(playerInfo.level) or -1
            local playerRank = playerInfo.rank or 0

            -- Only add if matches search criteria - only search name and guild
                if searchText == "" or
                    entryName:lower():find(searchText, 1, true) or
                    playerGuild:lower():find(searchText, 1, true) then

                local entry = {
                    name = entryName,
                    class = playerClass,
                    race = playerRace,
                    gender = playerGender,
                    levelDisplay = playerLevel,
                    rank = playerRank,
                    guild = playerGuild,
                    zone = lastAssistZone[assisterName] or "Unknown",
                    kills = 0,
                    deaths = 0,
                    assists = assistCount,
                    lastKill = lastAssistTimestamp[assisterName] or 0
                }

                playerNameMap[entryName] = entry
                table.insert(entries, entry)
            end
        end
    end
end

-- Pre-calculate assist counts for all players in a single pass (O(n) instead of O(n²))
local function PreCalculateAssistCounts(deathDataByPlayer)
    local assistCounts = {}
    local lastAssistTimestamp = {}
    local lastAssistZone = {}

    for _, deathInfo in pairs(deathDataByPlayer) do
        if deathInfo.deathLocations then
            for _, location in ipairs(deathInfo.deathLocations) do
                if location.assisters then
                    for _, assister in ipairs(location.assisters) do
                        local assisterName = assister.name

                        -- Count assists
                        assistCounts[assisterName] = (assistCounts[assisterName] or 0) + 1

                        -- Track most recent assist
                        local timestamp = location.timestamp or 0
                        if not lastAssistTimestamp[assisterName] or timestamp > lastAssistTimestamp[assisterName] then
                            lastAssistTimestamp[assisterName] = timestamp
                            lastAssistZone[assisterName] = location.zone
                        end
                    end
                end
            end
        end
    end

    return assistCounts, lastAssistTimestamp, lastAssistZone
end

-- Add assist and death data to all player entries
local function AddAssistAndDeathData(entries, deathDataByCanonical, assistCountsByCanonical, lastAssistTimestampByCanonical, lastAssistZoneByCanonical)
    for _, entry in ipairs(entries) do
        local playerName = entry.name

        -- Add death data
        local deathData = deathDataByCanonical and deathDataByCanonical[playerName] or nil
        entry.deaths = deathData and deathData.deaths or 0
        entry.deathHistory = deathData and deathData.deathLocations or {}

        -- Find most recent death timestamp
        local mostRecentDeathTimestamp = 0
        local mostRecentDeathZone = nil

        if deathData and deathData.deathLocations and #deathData.deathLocations > 0 then
            -- Get most recent death (assuming already sorted or just iterate once)
            local mostRecentDeath = deathData.deathLocations[1]
            for _, location in ipairs(deathData.deathLocations) do
                if (location.timestamp or 0) > mostRecentDeathTimestamp then
                    mostRecentDeathTimestamp = location.timestamp or 0
                    mostRecentDeath = location
                end
            end

            mostRecentDeathZone = mostRecentDeath.zone

            -- Update lastKill if the most recent death is more recent
            if mostRecentDeathTimestamp > (entry.lastKill or 0) then
                entry.lastKill = mostRecentDeathTimestamp
                entry.zone = mostRecentDeathZone or entry.zone
            end
        end

        -- Fallback to top-level death fields when deathLocations is empty
        if deathData then
            if (entry.lastKill or 0) == 0 and (deathData.lastDeath or 0) > 0 then
                entry.lastKill = deathData.lastDeath
            end
            if (entry.zone == nil or entry.zone == "Unknown") and deathData.zone and deathData.zone ~= "" and deathData.zone ~= "Unknown" then
                entry.zone = deathData.zone
            end
        end

        -- Add assists data using pre-calculated counts (O(1) lookup instead of O(n) scan)
        -- Only update if not already set (assist-only players have it set already)
        local assistCount = assistCountsByCanonical and assistCountsByCanonical[playerName] or 0
        local assistTimestamp = lastAssistTimestampByCanonical and lastAssistTimestampByCanonical[playerName] or nil
        local assistZone = lastAssistZoneByCanonical and lastAssistZoneByCanonical[playerName] or nil
        if not entry.assists then
            entry.assists = assistCount
        end

        -- Update lastKill if the most recent assist is more recent
        if assistTimestamp and assistTimestamp > (entry.lastKill or 0) then
            entry.lastKill = assistTimestamp
            entry.zone = assistZone or entry.zone
        end
    end

    return entries
end

-- Sort entries based on current sort settings
local function SortPlayerEntries(entries)
    if PSC_SortKillsListBy then
        table.sort(entries, function(a, b)
            local aValue = a[PSC_SortKillsListBy]
            local bValue = b[PSC_SortKillsListBy]

            -- Special handling for level sorting - convert to numbers for proper comparison
            if PSC_SortKillsListBy == "levelDisplay" then
                local aLevel = tonumber(aValue) or -1
                local bLevel = tonumber(bValue) or -1

                if PSC_SortKillsListAscending then
                    return aLevel < bLevel
                else
                    return aLevel > bLevel
                end
            end

            -- Special case for numeric values vs nil
            if type(aValue) == "number" and type(bValue) == "number" then
                if PSC_SortKillsListAscending then
                    return aValue < bValue
                else
                    return aValue > bValue
                end
            end

            -- Handle string comparison
            if PSC_SortKillsListAscending then
                return tostring(aValue or "") < tostring(bValue or "")
            else
                return tostring(aValue or "") > tostring(bValue or "")
            end
        end)
    end

    return entries
end

-- Apply all active filters to the entry list
local function ApplyFiltersToEntries(entries, resolveName)
    local filteredEntries = {}

    for _, entry in ipairs(entries) do
        local match = true

        -- Level filter
        if match and (minLevelSearch or maxLevelSearch) then
            local entryLevel = tonumber(entry.levelDisplay) or -1

            if minLevelSearch == -1 and maxLevelSearch == -1 then
                -- Filter for unknown levels (-1)
                match = (entryLevel == -1)
            elseif minLevelSearch and maxLevelSearch then
                -- Filter for level range
                match = (entryLevel >= minLevelSearch and entryLevel <= maxLevelSearch)
            end
        end

        -- Class filter
        if match and classSearchText ~= "" then
            match = (entry.class:lower():find(classSearchText:lower(), 1, true) ~= nil)
        end

        -- Race filter
        if match and raceSearchText ~= "" then
            match = (entry.race:lower():find(raceSearchText:lower(), 1, true) ~= nil)
        end

        -- Gender filter
        if match and genderSearchText ~= "" then
            local normalizedGender = entry.gender:lower()
            local normalizedSearch = genderSearchText:lower()

            -- Exact matching for gender - handle common abbreviations
            if normalizedSearch == "m" or normalizedSearch == "male" then
                match = (normalizedGender == "male")
            elseif normalizedSearch == "f" or normalizedSearch == "female" then
                match = (normalizedGender == "female")
            elseif normalizedSearch == "u" or normalizedSearch == "unknown" or normalizedSearch == "?" then
                match = (normalizedGender == "unknown")
            else
                -- For anything else, require exact match
                match = (normalizedGender == normalizedSearch)
            end
        end

        -- Zone filter
        if match and zoneSearchText ~= "" then
            match = (entry.zone:lower():find(zoneSearchText:lower(), 1, true) ~= nil)
        end

        -- Rank filter
        if match and (minRankSearch or maxRankSearch) then
            local entryRank = tonumber(entry.rank) or 0

            if minRankSearch and maxRankSearch then
                match = (entryRank >= minRankSearch and entryRank <= maxRankSearch)
            end
        end

        -- Note filter
        if match and filterOnlyWithNotes then
            local playerInfo = resolveName(entry.name)
            local hasNote = playerInfo.note and playerInfo.note ~= ""
            match = (hasNote == true)
        end

        -- Min deaths filter
        if match and filterMinDeaths > 0 then
            match = (entry.deaths or 0) >= filterMinDeaths
        end

        if match then
            table.insert(filteredEntries, entry)
        end
    end

    return filteredEntries
end

-- Main function to filter and sort entries - now more modular
function PSC_FilterAndSortEntries()
    local entries = {}
    local playerNameMap = {}
    local searchText = PSC_SearchText or ""
    searchText = searchText:lower()

    local infoCache = {}
    local canonicalCache = {}

    local function ResolveName(name)
        if not name or name == "" then
            return {}, nil
        end

        local cached = infoCache[name]
        if cached then
            return cached.info, cached.key
        end

        local info, infoKey = PSC_GetPlayerInfo(name)
        infoCache[name] = { info = info or {}, key = infoKey }
        return info or {}, infoKey
    end

    local function CanonicalizeName(name, infoKey)
        if not name or name == "" then
            return name
        end

        local cached = canonicalCache[name]
        if cached then
            return cached
        end

        local canonical = infoKey or PSC_GetInfoKeyFromName(name)
        canonicalCache[name] = canonical
        return canonical
    end

    local function GetLatestLocation(killData)
        if not killData then
            return nil
        end

        local latestZone = nil
        local latestTimestamp = 0

        if killData.locations and #killData.locations > 0 then
            for _, location in ipairs(killData.locations) do
                local ts = tonumber(location.timestamp) or 0
                if ts > latestTimestamp then
                    latestTimestamp = ts
                    latestZone = location.zone
                end
            end
        end

        if killData.killLocations and #killData.killLocations > 0 then
            for _, location in ipairs(killData.killLocations) do
                local ts = tonumber(location.timestamp) or 0
                if ts > latestTimestamp then
                    latestTimestamp = ts
                    latestZone = location.zone
                end
            end
        end

        return latestZone
    end

    -- Step 1: Get death data from all relevant characters based on account-wide setting
    local deathDataByPlayer = GetDeathDataFromAllCharacters()

    -- Step 2: Pre-calculate ALL assist counts in one pass (O(n) instead of O(n²))
    local assistCounts, lastAssistTimestamp, lastAssistZone = PreCalculateAssistCounts(deathDataByPlayer)

    -- Step 3: Process players you've killed
    ProcessKilledPlayers(searchText, playerNameMap, entries, ResolveName, CanonicalizeName, GetLatestLocation)

    -- Step 4: Process players who killed you but you haven't killed
    ProcessEnemyKillers(searchText, playerNameMap, entries, deathDataByPlayer, ResolveName, CanonicalizeName)

    -- Step 5: Process players who have only assisted in kills but never directly killed you
    ProcessAssistOnlyPlayers(searchText, playerNameMap, entries, assistCounts, lastAssistTimestamp, lastAssistZone, ResolveName, CanonicalizeName)

    local function BuildCanonicalDeathData(source)
        local aggregated = {}
        for name, deathData in pairs(source or {}) do
            local _, infoKey = ResolveName(name)
            local canonical = CanonicalizeName(name, infoKey)
            local target = aggregated[canonical]
            if not target then
                target = { deaths = 0, deathLocations = {} }
                aggregated[canonical] = target
            end
            target.deaths = target.deaths + (deathData.deaths or 0)
            if deathData.deathLocations then
                for _, location in ipairs(deathData.deathLocations) do
                    table.insert(target.deathLocations, location)
                end
            end
        end
        return aggregated
    end

    local function BuildCanonicalAssistData(counts, timestamps, zones)
        local aggregatedCounts = {}
        local aggregatedTimestamps = {}
        local aggregatedZones = {}

        for name, count in pairs(counts or {}) do
            local _, infoKey = ResolveName(name)
            local canonical = CanonicalizeName(name, infoKey)
            aggregatedCounts[canonical] = (aggregatedCounts[canonical] or 0) + (count or 0)

            local ts = timestamps and timestamps[name] or nil
            if ts and (not aggregatedTimestamps[canonical] or ts > aggregatedTimestamps[canonical]) then
                aggregatedTimestamps[canonical] = ts
                if zones then
                    aggregatedZones[canonical] = zones[name]
                end
            end
        end

        return aggregatedCounts, aggregatedTimestamps, aggregatedZones
    end

    local deathDataByCanonical = BuildCanonicalDeathData(deathDataByPlayer)
    local assistCountsByCanonical, lastAssistTimestampByCanonical, lastAssistZoneByCanonical =
        BuildCanonicalAssistData(assistCounts, lastAssistTimestamp, lastAssistZone)

    -- Step 6: Add death counts and assists counts to all entries (using pre-calculated data)
    entries = AddAssistAndDeathData(entries, deathDataByCanonical, assistCountsByCanonical, lastAssistTimestampByCanonical, lastAssistZoneByCanonical)

    -- Step 7: Apply additional filters
    local filteredEntries = ApplyFiltersToEntries(entries, ResolveName)

    -- Step 8: Sort entries
    return SortPlayerEntries(filteredEntries)
end

function PSC_CreateSearchBar(frame)
    local searchBg = PSC_CreateSearchBackground(frame)

    searchBg:SetHeight(40)

    local row1 = CreateFrame("Frame", nil, searchBg)
    row1:SetSize(searchBg:GetWidth(), 20)
    row1:SetPoint("TOP", searchBg, "TOP", 0, -10)

    local searchLabel = searchBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("LEFT", row1, "LEFT", 10, 0)
    searchLabel:SetText("Player/Guild:")
    searchLabel:SetTextColor(1, 0.82, 0)

    local searchBox = PSC_CreateEditBox(searchBg, searchLabel)
    searchBox:SetSize(120, 20)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 5, 0)
    PSC_SetupSearchBoxScripts(searchBox)
    searchBox:SetText("")
    PSC_SearchText = ""

    local classLabel = searchBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classLabel:SetPoint("LEFT", searchBox, "RIGHT", 15, 0)
    classLabel:SetText("Class:")
    classLabel:SetTextColor(1, 0.82, 0)

    local classSearchBox = PSC_CreateClassSearchBox(searchBg, classLabel)
    classSearchBox:SetSize(80, 20)
    classSearchBox:SetPoint("LEFT", classLabel, "RIGHT", 5, 0)
    PSC_SetupClassSearchBoxScripts(classSearchBox)
    classSearchBox:SetText("")
    classSearchText = ""

    local raceLabel = searchBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    raceLabel:SetPoint("LEFT", classSearchBox, "RIGHT", 15, 0)
    raceLabel:SetText("Race:")
    raceLabel:SetTextColor(1, 0.82, 0)

    local raceSearchBox = PSC_CreateRaceSearchBox(searchBg, raceLabel)
    raceSearchBox:SetSize(80, 20)
    raceSearchBox:SetPoint("LEFT", raceLabel, "RIGHT", 5, 0)
    PSC_SetupRaceSearchBoxScripts(raceSearchBox)
    raceSearchBox:SetText("")
    raceSearchText = ""

    local genderLabel = searchBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    genderLabel:SetPoint("LEFT", raceSearchBox, "RIGHT", 15, 0)
    genderLabel:SetText("Gender:")
    genderLabel:SetTextColor(1, 0.82, 0)

    local genderSearchBox = PSC_CreateGenderSearchBox(searchBg, genderLabel)
    genderSearchBox:SetSize(25, 20)
    genderSearchBox:SetPoint("LEFT", genderLabel, "RIGHT", 5, 0)
    PSC_SetupGenderSearchBoxScripts(genderSearchBox)
    genderSearchBox:SetText("")
    genderSearchText = ""

    local levelLabel = searchBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelLabel:SetPoint("LEFT", genderSearchBox, "RIGHT", 15, 0)
    levelLabel:SetText("Level:")
    levelLabel:SetTextColor(1, 0.82, 0)

    local levelSearchBox = CreateLevelSearchBox(searchBg, levelLabel)
    levelSearchBox:SetSize(50, 20)
    levelSearchBox:SetPoint("LEFT", levelLabel, "RIGHT", 5, 0)
    SetupLevelSearchBoxScripts(levelSearchBox)
    levelSearchBox:SetText("")
    levelSearchText = ""

    local rankLabel = searchBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rankLabel:SetPoint("LEFT", levelSearchBox, "RIGHT", 15, 0)
    rankLabel:SetText("Rank:")
    rankLabel:SetTextColor(1, 0.82, 0)

    local rankSearchBox = PSC_CreateRankSearchBox(searchBg, rankLabel)
    rankSearchBox:SetSize(50, 20)
    rankSearchBox:SetPoint("LEFT", rankLabel, "RIGHT", 5, 0)
    PSC_SetupRankSearchBoxScripts(rankSearchBox)
    rankSearchBox:SetText("")
    rankSearchText = ""

    local zoneLabel = searchBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoneLabel:SetPoint("LEFT", rankSearchBox, "RIGHT", 15, 0)
    zoneLabel:SetText("Zone:")
    zoneLabel:SetTextColor(1, 0.82, 0)

    local zoneSearchBox = PSC_CreateZoneSearchBox(searchBg, zoneLabel)
    zoneSearchBox:SetSize(130, 20)
    zoneSearchBox:SetPoint("LEFT", zoneLabel, "RIGHT", 5, 0)
    PSC_SetupZoneSearchBoxScripts(zoneSearchBox)
    zoneSearchBox:SetText("")
    zoneSearchText = ""

    -- Note filter checkbox
    local noteCheckbox = CreateFrame("CheckButton", nil, searchBg, "UICheckButtonTemplate")
    noteCheckbox:SetSize(20, 20)
    noteCheckbox:SetPoint("LEFT", zoneSearchBox, "RIGHT", 15, 0)
    noteCheckbox:SetChecked(false)
    filterOnlyWithNotes = false

    local noteLabel = searchBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noteLabel:SetPoint("LEFT", noteCheckbox, "RIGHT", 5, 0)
    noteLabel:SetText("Has Note")
    noteLabel:SetTextColor(1, 0.82, 0)

    noteCheckbox:SetScript("OnClick", function(self)
        filterOnlyWithNotes = self:GetChecked()
        RefreshKillsListFrame()
    end)

    noteCheckbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Note filter")
        GameTooltip:AddLine("Only show players with notes", 1, 1, 1, true)
        GameTooltip:Show()
    end)

    noteCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    frame.searchBox = searchBox
    frame.levelSearchBox = levelSearchBox
    frame.classSearchBox = classSearchBox
    frame.raceSearchBox = raceSearchBox
    frame.genderSearchBox = genderSearchBox
    frame.zoneSearchBox = zoneSearchBox
    frame.rankSearchBox = rankSearchBox
    frame.noteCheckbox = noteCheckbox

    return searchBox
end

function PSC_ResetAllFilters()
    PSC_SearchText = ""
    levelSearchText = ""
    classSearchText = ""
    raceSearchText = ""
    genderSearchText = ""
    zoneSearchText = ""
    rankSearchText = ""
    minLevelSearch = nil
    maxLevelSearch = nil
    minRankSearch = nil
    maxRankSearch = nil
    filterOnlyWithNotes = false
    filterMinDeaths = 0

    if not PSC_KillsListFrame then return end

    PSC_KillsListFrame.searchBox:SetText("")
    PSC_KillsListFrame.levelSearchBox:SetText("")
    PSC_KillsListFrame.classSearchBox:SetText("")
    PSC_KillsListFrame.raceSearchBox:SetText("")
    PSC_KillsListFrame.genderSearchBox:SetText("")
    PSC_KillsListFrame.zoneSearchBox:SetText("")
    PSC_KillsListFrame.rankSearchBox:SetText("")
    PSC_KillsListFrame.noteCheckbox:SetChecked(false)
end

function PSC_SetKillListSearch(text, levelText, classText, raceText, genderText, zoneText, resetOtherFilters)
    if PSC_KillsListFrame then
        if resetOtherFilters then
            PSC_ResetAllFilters()
        end

        if PSC_KillsListFrame.searchBox and text then
            PSC_KillsListFrame.searchBox:SetText(text)
            PSC_SearchText = text:lower()
        end

        if PSC_KillsListFrame.levelSearchBox and levelText then
            PSC_KillsListFrame.levelSearchBox:SetText(levelText)
            levelSearchText = levelText
            ParseLevelSearch(levelText)
        end

        if PSC_KillsListFrame.classSearchBox and classText then
            PSC_KillsListFrame.classSearchBox:SetText(classText)
            classSearchText = classText
        end

        if PSC_KillsListFrame.raceSearchBox and raceText then
            PSC_KillsListFrame.raceSearchBox:SetText(raceText)
            raceSearchText = raceText
        end

        if PSC_KillsListFrame.genderSearchBox and genderText then
            PSC_KillsListFrame.genderSearchBox:SetText(genderText)
            genderSearchText = genderText
        end

        if PSC_KillsListFrame.zoneSearchBox and zoneText then
            PSC_KillsListFrame.zoneSearchBox:SetText(zoneText)
            zoneSearchText = zoneText
        end

        RefreshKillsListFrame()
    end
end

function PSC_SetKillListLevelRange(minLevel, maxLevel, resetOtherFilters)
    if PSC_KillsListFrame then
        if resetOtherFilters then
            PSC_ResetAllFilters()
        end

        minLevelSearch = minLevel
        maxLevelSearch = maxLevel

        if PSC_KillsListFrame.levelSearchBox then
            if minLevel == -1 and maxLevel == -1 then
                PSC_KillsListFrame.levelSearchBox:SetText("??")
                levelSearchText = "??"
            elseif minLevel and maxLevel and minLevel == maxLevel then
                PSC_KillsListFrame.levelSearchBox:SetText(tostring(minLevel))
                levelSearchText = tostring(minLevel)
            elseif minLevel and maxLevel then
                local rangeText = minLevel .. "-" .. maxLevel
                PSC_KillsListFrame.levelSearchBox:SetText(rangeText)
                levelSearchText = rangeText
            else
                PSC_KillsListFrame.levelSearchBox:SetText("")
                levelSearchText = ""
                minLevelSearch = nil
                maxLevelSearch = nil
            end
        end

        if PSC_KillsListFrame.levelSearchBox then
            PSC_KillsListFrame.levelSearchBox:SetTextColor(1, 1, 1)
        end

        RefreshKillsListFrame()

        PSC_FrameManager:BringToFront("KillsList")
    end
end

function PSC_SetKillListMinDeaths(min)
    filterMinDeaths = min or 0
    RefreshKillsListFrame()
end

function PSC_SetKillListRankRange(minRank, maxRank, resetOtherFilters)
    if PSC_KillsListFrame then
        if resetOtherFilters then
            PSC_ResetAllFilters()
        end

        minRankSearch = minRank
        maxRankSearch = maxRank

        if PSC_KillsListFrame.rankSearchBox then
            if minRank and maxRank and minRank == maxRank then
                PSC_KillsListFrame.rankSearchBox:SetText(tostring(minRank))
                rankSearchText = tostring(minRank)
            elseif minRank and maxRank then
                local rangeText = minRank .. "-" .. maxRank
                PSC_KillsListFrame.rankSearchBox:SetText(rangeText)
                rankSearchText = rangeText
            else
                PSC_KillsListFrame.rankSearchBox:SetText("")
                rankSearchText = ""
                minRankSearch = nil
                maxRankSearch = nil
            end
        end

        if PSC_KillsListFrame.rankSearchBox then
            PSC_KillsListFrame.rankSearchBox:SetTextColor(1, 1, 1)
        end

        RefreshKillsListFrame()

        PSC_FrameManager:BringToFront("KillsList")
    end
end
