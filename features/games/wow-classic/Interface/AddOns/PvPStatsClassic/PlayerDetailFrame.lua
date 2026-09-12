PSC_PlayerDetailFrame = nil
local DETAIL_FRAME_WIDTH = 500
local DETAIL_FRAME_HEIGHT = 600
local MAX_VISIBLE_ROWS = 5
local ROW_HEIGHT = 20

-- Layout constants for column positioning
PSC_COLUMN_POSITIONS = {
    LEVEL = 25,     -- Level column
    ZONE = 70,      -- Zone column
    KILLS = 225,    -- Kills/Assisters column
    TIME = 300      -- Time column
}

PSC_COLUMN_WIDTHS = {
    LEVEL = 40,     -- Level column width
    ZONE = 135,     -- Zone column width
    KILLS = 100      -- Kills/Assisters column width
}

local PVP_RANK_ICONS = {
    [1] = "Interface\\PvPRankBadges\\PvPRank01",
    [2] = "Interface\\PvPRankBadges\\PvPRank02",
    [3] = "Interface\\PvPRankBadges\\PvPRank03",
    [4] = "Interface\\PvPRankBadges\\PvPRank04",
    [5] = "Interface\\PvPRankBadges\\PvPRank05",
    [6] = "Interface\\PvPRankBadges\\PvPRank06",
    [7] = "Interface\\PvPRankBadges\\PvPRank07",
    [8] = "Interface\\PvPRankBadges\\PvPRank08",
    [9] = "Interface\\PvPRankBadges\\PvPRank09",
    [10] = "Interface\\PvPRankBadges\\PvPRank10",
    [11] = "Interface\\PvPRankBadges\\PvPRank11",
    [12] = "Interface\\PvPRankBadges\\PvPRank12",
    [13] = "Interface\\PvPRankBadges\\PvPRank13",
    [14] = "Interface\\PvPRankBadges\\PvPRank14"
}

RACE_ICON_IDS = RACE_ICON_IDS or {
    ["HUMAN_MALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236448",
    ["HUMAN_FEMALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236447",
    ["DWARF_MALE"] = 236444,
    ["DWARF_FEMALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236443",
    ["GNOME_MALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236446",
    ["GNOME_FEMALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236445",
    ["NIGHTELF_MALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236450",
    ["NIGHTELF_FEMALE"] = 236449,
    ["ORC_MALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236452",
    ["ORC_FEMALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236451",
    ["TAUREN_MALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236454",
    ["TAUREN_FEMALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236453",
    ["TROLL_MALE"] = 236456,
    ["TROLL_FEMALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236455",
    ["UNDEAD_MALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236458",
    ["UNDEAD_FEMALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236457",
    ["SCOURGE_MALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236458",
    ["SCOURGE_FEMALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236457",
    ["BLOODELF_MALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236440",
    ["BLOODELF_FEMALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236439",
    ["DRAENEI_MALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236442",
    ["DRAENEI_FEMALE"] = "Interface\\AddOns\\PvPStatsClassic\\img\\icons\\236441"
}

function PSC_FormatTimestamp(timestamp)
    if not timestamp then return "Unknown" end

    -- If timestamp is already a string, try to return it as-is
    if type(timestamp) == "string" then
        return timestamp
    end

    -- If timestamp is 0 or invalid
    if timestamp == 0 or type(timestamp) ~= "number" then
        return "Unknown"
    end

    -- Process numeric timestamp
    local dateInfo = date("*t", timestamp)
    if not dateInfo or not dateInfo.day then
        return "Invalid date"
    end

    return string.format("%02d/%02d/%02d %02d:%02d:%02d",
        dateInfo.day, dateInfo.month, dateInfo.year % 100,
        dateInfo.hour, dateInfo.min, dateInfo.sec)
end

local function SortDeathHistoryByTimestamp(deathHistory)
    table.sort(deathHistory, function(a, b)
        return a.timestamp > b.timestamp
    end)

    return deathHistory
end

local function CreateSection(parent, title, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 15, yOffset)
    header:SetText(title)
    header:SetTextColor(1, 0.82, 0)

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -15, 0)
    line:SetColorTexture(1, 0.82, 0, 0.5)

    return yOffset - 25
end

-- Helper function to create a scrollable container for tables
local function CreateScrollableTableContainer(parent, numEntries, yOffset)
    local needsScrolling = numEntries > MAX_VISIBLE_ROWS
    local containerHeight = needsScrolling and (MAX_VISIBLE_ROWS * ROW_HEIGHT) or (numEntries * ROW_HEIGHT)
    
    if needsScrolling then
        -- Create a scrollable frame
        local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
        scrollFrame:SetPoint("TOPLEFT", 0, yOffset)
        scrollFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, 0)
        scrollFrame:SetHeight(containerHeight)
        
        -- Create the scroll child content frame
        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(DETAIL_FRAME_WIDTH - 60)
        scrollChild:SetHeight(numEntries * ROW_HEIGHT)
        scrollFrame:SetScrollChild(scrollChild)
        
        -- Add scroll bar
        local scrollBar = CreateFrame("Slider", nil, scrollFrame, "UIPanelScrollBarTemplate")
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, -16)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, 16)
        scrollBar:SetMinMaxValues(0, math.max(0, (numEntries * ROW_HEIGHT) - containerHeight))
        scrollBar:SetValueStep(ROW_HEIGHT)
        scrollBar:SetValue(0)
        scrollBar:SetWidth(16)
        scrollBar:Show()
        
        scrollBar:SetScript("OnValueChanged", function(self, value)
            scrollFrame:SetVerticalScroll(value)
        end)
        
        -- Enable mouse wheel scrolling
        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(self, delta)
            local current = scrollBar:GetValue()
            local minVal, maxVal = scrollBar:GetMinMaxValues()
            local newValue = current - (delta * ROW_HEIGHT)
            newValue = math.max(minVal, math.min(maxVal, newValue))
            scrollBar:SetValue(newValue)
        end)
        
        return scrollChild, yOffset - containerHeight - 5
    else
        -- No scrolling needed, create a simple container frame
        local container = CreateFrame("Frame", nil, parent)
        container:SetPoint("TOPLEFT", 0, yOffset)
        container:SetWidth(DETAIL_FRAME_WIDTH - 30)
        container:SetHeight(containerHeight)
        
        return container, yOffset - containerHeight - 5
    end
end

local function CreateDetailRow(parent, leftText, rightText, yOffset)
    local leftLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftLabel:SetPoint("TOPLEFT", 25, yOffset)
    leftLabel:SetText(leftText)
    leftLabel:SetTextColor(1, 1, 1)

    local rightLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rightLabel:SetPoint("TOPLEFT", 120, yOffset)
    rightLabel:SetText(rightText)
    rightLabel:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")

    return yOffset - 20
end

local function CreateKillHistoryEntry(parent, killData, index, yOffset)
    local bgColor = index % 2 == 0 and {0.1, 0.1, 0.1, 0.3} or {0.15, 0.15, 0.15, 0.3}

    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 15, yOffset)
    bg:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -15, 0)
    bg:SetHeight(20)
    bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])

    local levelText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    levelText:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.LEVEL, yOffset - 3)
    levelText:SetText(killData.level == -1 and "??" or tostring(killData.level))
    levelText:SetWidth(PSC_COLUMN_WIDTHS.LEVEL)

    local zoneText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    zoneText:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.ZONE, yOffset - 3)
    zoneText:SetText(killData.zone or "Unknown")
    zoneText:SetWidth(PSC_COLUMN_WIDTHS.ZONE)
    zoneText:SetJustifyH("LEFT")

    -- Fix: Use playerLevel for the "Your Level" column instead of kills
    local yourLevelText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    yourLevelText:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.KILLS, yOffset - 3)
    -- Use playerLevel from kill data if available, otherwise fall back to default
    yourLevelText:SetText(tostring(killData.playerLevel))
    yourLevelText:SetWidth(PSC_COLUMN_WIDTHS.KILLS)
    yourLevelText:SetJustifyH("LEFT")

    local timeText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timeText:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.TIME, yOffset - 3)
    timeText:SetText(PSC_FormatTimestamp(killData.timestamp))

    return yOffset - 20
end

-- Fix the CreateDeathHistoryEntry function
local function CreateDeathHistoryEntry(parent, deathData, index, yOffset)
    local bgColor = index % 2 == 0 and {0.1, 0.1, 0.1, 0.3} or {0.15, 0.15, 0.15, 0.3}

    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 15, yOffset)
    bg:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -15, 0)
    bg:SetHeight(20)
    bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])

    local levelText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    levelText:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.LEVEL, yOffset - 3)
    levelText:SetText(deathData.killerLevel == -1 and "??" or tostring(deathData.killerLevel))
    levelText:SetWidth(PSC_COLUMN_WIDTHS.LEVEL)

    local zoneText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    zoneText:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.ZONE, yOffset - 3)
    zoneText:SetText(deathData.zone or "Unknown")
    zoneText:SetWidth(PSC_COLUMN_WIDTHS.ZONE)
    zoneText:SetJustifyH("LEFT")

    -- Create a frame for the assisters column to handle tooltip
    local assistFrame = CreateFrame("Frame", nil, parent)
    -- Fix: Properly align with other columns by using the same y-offset
    assistFrame:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.KILLS, yOffset - 3)
    assistFrame:SetSize(100, 20)

    local assistText = assistFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    -- Fix: Align text to top of frame so it matches other columns' vertical position
    assistText:SetPoint("TOPLEFT", 0, 0)

    local assistCount = deathData.assisters and #deathData.assisters or 0
    local assistDisplay
    if assistCount == 0 then
        assistDisplay = "Solo kill"
    elseif assistCount == 1 then
        assistDisplay = "1 player"
    else
        assistDisplay = tostring(assistCount) .. " players"
    end
    assistText:SetText(assistDisplay)
    assistText:SetWidth(PSC_COLUMN_WIDTHS.KILLS)
    assistText:SetJustifyH("LEFT")

    -- Add tooltip functionality if there are assisters
    if assistCount > 0 then
        -- Create tooltip when hovering
        assistFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Kill Assisters:", 1, 0.82, 0, 1)

            -- Sort assisters by level (highest first)
            local sortedAssisters = {}
            for i, assister in ipairs(deathData.assisters) do
                table.insert(sortedAssisters, assister)
            end

            table.sort(sortedAssisters, function(a, b)
                local levelA = tonumber(a.level) or -1
                local levelB = tonumber(b.level) or -1

                -- Treat unknown level (-1) as highest
                if levelA == -1 and levelB ~= -1 then
                    return true
                elseif levelA ~= -1 and levelB == -1 then
                    return false
                else
                    return levelA > levelB
                end
            end)

            -- Add assisters to tooltip using historical data rather than current info cache
            for _, assister in ipairs(sortedAssisters) do
                local displayText
                local color = {r = 1, g = 1, b = 1} -- Default to white

                -- Use the level and class stored at time of kill
                local levelDisplay = assister.level == -1 and "??" or tostring(assister.level)
                local classDisplay = assister.class or "Unknown"

                if classDisplay ~= "Unknown" and RAID_CLASS_COLORS[classDisplay:upper()] then
                    color = RAID_CLASS_COLORS[classDisplay:upper()]
                end

                displayText = assister.name .. " (" .. levelDisplay .. " " .. classDisplay .. ")"
                GameTooltip:AddLine(displayText, color.r, color.g, color.b)
            end

            GameTooltip:Show()
        end)

        assistFrame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end

    local timeText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timeText:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.TIME, yOffset - 3)
    timeText:SetText(PSC_FormatTimestamp(deathData.timestamp))

    return yOffset - 20
end

local function CleanupPlayerDetailFrame(content)
    local children = {content:GetChildren()}
    for _, child in pairs(children) do
        child:Hide()
        child:SetParent(nil)
    end

    local regions = {content:GetRegions()}
    for _, region in pairs(regions) do
        region:Hide()
        region:ClearAllPoints()
        region:SetParent(nil)
    end

    collectgarbage("collect")
end

-- Helper functions for creating and manipulating the player detail frame
function PSC_CreatePlayerDetailInfo(playerName)
    -- Create a basic entry even if we don't have complete info
    local killHistory = {
        name = playerName,
        class = "Unknown",
        race = "Unknown",
        gender = "Unknown",
        levelDisplay = -1,
        guild = "",
        rank = 0,
        kills = 0,
        deaths = 0,
        assists = 0,
        lastKill = 0,
        zone = "Unknown", -- Default zone
        killHistory = {},
        deathHistory = {},
        assistHistory = {}
    }

    -- Try to get player info from the database cache (supports cross-realm fallback)
    local playerInfo = PSC_GetPlayerInfo(playerName)

    if playerInfo and next(playerInfo) then
        -- Update with available information
        killHistory.class = playerInfo.class or "Unknown"
        killHistory.race = playerInfo.race or "Unknown"
        killHistory.gender = playerInfo.gender or "Unknown"
        killHistory.levelDisplay = playerInfo.level or -1
        killHistory.guild = playerInfo.guild or ""
        killHistory.guildRank = playerInfo.guildRank or ""
        killHistory.rank = playerInfo.rank or 0
    end

    -- Collect kill history across all characters
    local charactersToProcess = PSC_GetCharactersToProcessForStatistics()
    for charKey, charData in pairs(charactersToProcess) do
        for nameWithLevel, killData in pairs(charData.Kills or {}) do
            local name = string.match(nameWithLevel, "(.-)%:")
            if name and PSC_IsSamePlayerName(name, playerName) then
                local level = tonumber(string.match(nameWithLevel, ":(%d+)") or "-1") or -1

                -- Update total kills
                killHistory.kills = killHistory.kills + (killData.kills or 0)

                -- Get latest kill info from kill locations
                local latestKillTimestamp = 0
                local latestZone = "Unknown"

                if killData.killLocations and #killData.killLocations > 0 then
                    -- Find the most recent kill location
                    for _, location in ipairs(killData.killLocations) do
                        if (location.timestamp or 0) > latestKillTimestamp then
                            latestKillTimestamp = location.timestamp
                            latestZone = location.zone or "Unknown"
                        end
                    end
                end

                -- Keep track of the most recent kill timestamp
                if latestKillTimestamp > killHistory.lastKill then
                    killHistory.lastKill = latestKillTimestamp
                    killHistory.zone = latestZone
                end

                -- Extract kill history for each location entry
                if killData.killLocations and #killData.killLocations > 0 then
                    for _, location in ipairs(killData.killLocations) do
                        table.insert(killHistory.killHistory, {
                            level = level,
                            zone = location.zone or "Unknown",
                            timestamp = location.timestamp or 0,
                            rank = killData.rank or 0,
                            playerLevel = location.playerLevel or UnitLevel("player"),
                            characterKey = charKey
                        })
                    end
                else
                    -- Fallback if no killLocations available
                    table.insert(killHistory.killHistory, {
                        level = level,
                        zone = killData.zone or "Unknown", -- Legacy data might still have top-level zone
                        timestamp = killData.lastKill or 0,
                        rank = killData.rank or 0,
                        playerLevel = killData.playerLevel or UnitLevel("player"), -- Legacy data might have top-level playerLevel
                        characterKey = charKey
                    })
                end
            end
        end
    end

    -- Get death data from all characters
    local deathDataByPlayer = PSC_GetDeathDataFromAllCharacters()
    local function CollectDeathDataForPlayer(targetName)
        local aggregated = {
            deaths = 0,
            deathLocations = {}
        }
        local found = false

        for killerName, deathData in pairs(deathDataByPlayer) do
            if PSC_IsSamePlayerName(killerName, targetName) then
                found = true
                aggregated.deaths = aggregated.deaths + (deathData.deaths or 0)
                if deathData.deathLocations then
                    for _, location in ipairs(deathData.deathLocations) do
                        table.insert(aggregated.deathLocations, location)
                    end
                end
            end
        end

        if found then
            return aggregated
        end
        return nil
    end

    local deathData = CollectDeathDataForPlayer(playerName)
    if deathData then
        killHistory.deaths = deathData.deaths or 0
        killHistory.deathHistory = deathData.deathLocations or {}
    end

    -- Count assists and build assist history
    local assistCount, _ = PSC_CountPlayerAssists(playerName, deathDataByPlayer)
    killHistory.assists = assistCount

    for killerName, deathData in pairs(deathDataByPlayer) do
        if deathData.deathLocations then
            for _, location in ipairs(deathData.deathLocations) do
                if location.assisters then
                    for _, assister in ipairs(location.assisters) do
                        if PSC_IsSamePlayerName(assister.name, playerName) then
                            -- Create assist history entry
                            local assistData = {
                                assisterName = playerName,           -- The player whose history we're viewing
                                assisterLevel = assister.level,      -- Level of this player when they assisted
                                killerName = killerName,             -- The main killer
                                killerLevel = location.killerLevel or -1,
                                killerClass = PSC_GetPlayerInfo(killerName).class or "Unknown",
                                victimLevel = location.victimLevel or -1, -- Your level when you died
                                zone = location.zone or "Unknown",
                                timestamp = location.timestamp or 0,
                                otherAssisters = {}
                            }

                            -- Add other assisters (excluding the current player)
                            for _, otherAssister in ipairs(location.assisters) do
                                if not PSC_IsSamePlayerName(otherAssister.name, playerName) then
                                    table.insert(assistData.otherAssisters, otherAssister)
                                end
                            end

                            table.insert(killHistory.assistHistory, assistData)
                        end
                    end
                end
            end
        end
    end

    return killHistory
end

local function CreatePlayerDetailFrame()
    local frame = CreateFrame("Frame", "PSC_PlayerDetailFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(DETAIL_FRAME_WIDTH, DETAIL_FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Override close button to work in combat
    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            PSC_FrameManager:HideFrame("PlayerDetail")
        end)
    end

    frame:SetScript("OnMouseDown", function(self)
        if self.activeNoteEditBox and self.activeNoteEditBox:IsVisible() and self.activeNoteEditBox:HasFocus() then
            local mouseFocus = GetMouseFocus()
            if mouseFocus ~= self.activeNoteEditBox and mouseFocus ~= self.activeNoteEditBox.editBox then
                self.activeNoteEditBox:ClearFocus()
            end
        end
    end)

    local bgTexture = frame:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetAllPoints()
    bgTexture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(DETAIL_FRAME_WIDTH - 40, DETAIL_FRAME_HEIGHT * 3)
    scrollFrame:SetScrollChild(content)

    frame.content = content

    return frame
end

local function DisplayPlayerSummarySection(content, playerDetail, yOffset)
    yOffset = CreateSection(content, "Player Information", yOffset)

    local isFromDifferentRealm, cleanPlayerName, playerRealm = PSC_IsPlayerFromDifferentRealm(playerDetail.name)
    local displayPlayerName = cleanPlayerName -- Show name without realm

    local playerClass = playerDetail.class
    local playerRace = playerDetail.race
    local playerGender = playerDetail.gender
    local playerLevel = playerDetail.levelDisplay == -1 and "??" or tostring(playerDetail.levelDisplay)
    local playerGuild = playerDetail.guild
    local guildInfo = playerGuild ~= "" and " <" .. playerGuild .. ">" or ""

    local playerLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playerLabel:SetPoint("TOPLEFT", 25, yOffset)
    playerLabel:SetText("Player:")
    playerLabel:SetTextColor(1, 1, 1)

    local infoText = string.format("%s - Level %s %s %s%s",
        displayPlayerName, playerLevel, playerRace, playerGender ~= "Unknown" and (playerGender == "Male" and "Male" or "Female") .. " " or "", playerClass)

    local playerInfoLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    playerInfoLabel:SetPoint("TOPLEFT", 120, yOffset)
    playerInfoLabel:SetText(infoText)

    if playerClass ~= "Unknown" then
        local classIconSize = 32
        local iconContainer = CreateFrame("Frame", nil, content)
        iconContainer:SetSize(classIconSize + 10, classIconSize + 10)
        iconContainer:SetPoint("LEFT", 320, 0)
        local initialYOffset = yOffset
        local rowsToKills = 2
        local killsYPosition = initialYOffset - (20 * rowsToKills)
        iconContainer:SetPoint("TOP", 0, killsYPosition)
        local classIcon = iconContainer:CreateTexture(nil, "ARTWORK")
        classIcon:SetSize(classIconSize, classIconSize)
        classIcon:SetPoint("CENTER")
        local classTexture = "Interface\\TargetingFrame\\UI-Classes-Circles"
        local coords = CLASS_ICON_TCOORDS[playerClass:upper()]
        if coords then
            classIcon:SetTexture(classTexture)
            classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else
            classIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        local borderSize = classIconSize + 1
        local borderTexture = iconContainer:CreateTexture(nil, "BORDER")
        borderTexture:SetSize(borderSize, borderSize)
        borderTexture:SetPoint("CENTER")
        borderTexture:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        borderTexture:SetColorTexture(0.83, 0.69, 0.22)
        local maskTexture = iconContainer:CreateMaskTexture()
        maskTexture:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        maskTexture:SetSize(borderSize, borderSize)
        maskTexture:SetPoint("CENTER")
        borderTexture:AddMaskTexture(maskTexture)

        -- Add race icon to the left of class icon
        if playerRace and playerRace ~= "Unknown" and playerGender and playerGender ~= "Unknown" then
            local raceIcon = iconContainer:CreateTexture(nil, "ARTWORK")
            raceIcon:SetSize(32, 32)
            raceIcon:SetPoint("RIGHT", classIcon, "LEFT", -5, 0)

            local raceKey = playerRace:gsub(" ", ""):upper() .. "_" .. playerGender:upper()
            local raceIconID = RACE_ICON_IDS[raceKey]

            if raceIconID then
                raceIcon:SetTexture(raceIconID)
            else
                raceIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end

            -- Add Blizzard's icon border overlay only for custom img icons (not native Blizzard icons)
            if raceIconID and type(raceIconID) == "string" then
                local raceIconBorder = iconContainer:CreateTexture(nil, "OVERLAY")
                raceIconBorder:SetSize(54, 54)
                raceIconBorder:SetPoint("CENTER", raceIcon, "CENTER")
                raceIconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
            end
        end

        if playerDetail.rank and playerDetail.rank > 0 then
            local rankIcon = iconContainer:CreateTexture(nil, "OVERLAY")
            rankIcon:SetSize(32, 32)
            rankIcon:SetPoint("LEFT", classIcon, "RIGHT", 10, 0)
            rankIcon:SetTexture(PVP_RANK_ICONS[playerDetail.rank])

            local rankName = PSC_GetRankName(playerDetail.rank)
            rankIcon:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(rankName or ("Rank " .. playerDetail.rank), 1, 0.82, 0)
                GameTooltip:AddLine("Rank " .. tostring(playerDetail.rank), 1, 1, 1, true)
                GameTooltip:Show()
            end)
            rankIcon:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
    end

    if playerClass ~= "Unknown" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[playerClass:upper()] then
        local color = RAID_CLASS_COLORS[playerClass:upper()]
        playerInfoLabel:SetTextColor(color.r, color.g, color.b)
    else
        playerInfoLabel:SetTextColor(0.7, 0.7, 0.7)
    end

    yOffset = yOffset - 20

    -- Add guild row if player has a guild
    if playerGuild and playerGuild ~= "" then
        yOffset = CreateDetailRow(content, "Guild:", playerGuild, yOffset)
        -- Add guild rank if available
        if playerDetail.guildRank and playerDetail.guildRank ~= "" then
            yOffset = CreateDetailRow(content, "Guild Rank:", playerDetail.guildRank, yOffset)
        end
    end

    -- Add realm row if player is from a different realm
    if isFromDifferentRealm then
        yOffset = CreateDetailRow(content, "Realm:", playerRealm, yOffset)
    end

    local rankLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankLabel:SetPoint("TOPLEFT", 25, yOffset)
    rankLabel:SetText("PvP Rank:")
    rankLabel:SetTextColor(1, 1, 1)

    local rankValue = playerDetail.rank and playerDetail.rank > 0 and tostring(playerDetail.rank) or "0"
    local rankValueText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rankValueText:SetPoint("TOPLEFT", 120, yOffset)
    rankValueText:SetText(rankValue)
    rankValueText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")

    local rankTooltipFrame = CreateFrame("Frame", nil, content)
    rankTooltipFrame:SetPoint("TOPLEFT", rankLabel, "TOPLEFT", 0, 0)
    rankTooltipFrame:SetPoint("BOTTOMRIGHT", rankValueText, "BOTTOMRIGHT", 0, 0)
    rankTooltipFrame:SetScript("OnEnter", function(self)
        local rankNumber = playerDetail.rank or 0
        local rankName = PSC_GetRankName(rankNumber)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if rankNumber > 0 and rankName then
            GameTooltip:SetText(rankName, 1, 0.82, 0)
            GameTooltip:AddLine("Rank " .. tostring(rankNumber), 1, 1, 1, true)
        else
            GameTooltip:SetText("Rank 0", 1, 0.82, 0)
            GameTooltip:AddLine("No PvP rank earned yet", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    rankTooltipFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    yOffset = yOffset - 20

    local killsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    killsLabel:SetPoint("TOPLEFT", 25, yOffset)
    killsLabel:SetText("Total kills:")
    killsLabel:SetTextColor(1, 1, 1)
    local killsValue = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    killsValue:SetPoint("TOPLEFT", 120, yOffset)
    killsValue:SetText(tostring(playerDetail.kills))
    killsValue:SetTextColor(1, 1, 1)
    yOffset = yOffset - 20

    yOffset = CreateDetailRow(content, "Total deaths:", tostring(playerDetail.deaths), yOffset)
    yOffset = CreateDetailRow(content, "Total assists:", tostring(playerDetail.assists), yOffset)

    local kdLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    kdLabel:SetPoint("TOPLEFT", 25, yOffset)
    kdLabel:SetText("K/D Ratio:")
    kdLabel:SetTextColor(1, 1, 1)
    local kdValue = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    kdValue:SetPoint("TOPLEFT", 120, yOffset)
    local kdRatio = playerDetail.deaths > 0 and playerDetail.kills / playerDetail.deaths or playerDetail.kills
    kdValue:SetText(string.format("%.1f", kdRatio))
    kdValue:SetTextColor(1, 1, 1)
    yOffset = yOffset - 20

    local totalEncounters = playerDetail.kills + playerDetail.deaths
    if totalEncounters > 0 then
        local winPct = (playerDetail.kills / totalEncounters) * 100
        local winLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        winLabel:SetPoint("TOPLEFT", 25, yOffset)
        winLabel:SetText("Win %:")
        winLabel:SetTextColor(1, 1, 1)
        local winValue = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        winValue:SetPoint("TOPLEFT", 120, yOffset)
        winValue:SetText(PSC_FormatPercent(winPct, 2))
        local winPercentageColor = PSC_GetWinPercentageColor(winPct)
        winValue:SetTextColor(winPercentageColor.r, winPercentageColor.g, winPercentageColor.b)
        -- Also set K/D ratio to the same color
        kdValue:SetTextColor(winPercentageColor.r, winPercentageColor.g, winPercentageColor.b)
        yOffset = yOffset - 20
    end

    local noteLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noteLabel:SetPoint("TOPLEFT", 25, yOffset - 7)
    noteLabel:SetText("Note:")
    noteLabel:SetTextColor(1, 1, 1)

    local tooltipOnEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Player Note", 1, 0.82, 0, 1)
        GameTooltip:AddLine("You can link this note to multiple other players by typing @PlayerName.", 1, 1, 1, true)
        GameTooltip:AddLine("Example: 'Alt/Friend of @OtherPlayer'", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("This will create a corresponding note for 'OtherPlayer'.", 1, 1, 1, true)
        GameTooltip:Show()
    end
    local tooltipOnLeave = function(self)
        GameTooltip:Hide()
    end

    noteLabel:SetScript("OnEnter", tooltipOnEnter)
    noteLabel:SetScript("OnLeave", tooltipOnLeave)

    local noteEditBoxHeight = 25
    local noteEditBoxWidth = (content:GetWidth()) - 120 - 25 - 5
    local noteEditBox = CreateFrame("EditBox", displayPlayerName .. "NoteEditBox", content, "InputBoxTemplate")
    noteEditBox:SetPoint("TOPLEFT", 123, yOffset)
    noteEditBox:SetSize(noteEditBoxWidth, noteEditBoxHeight)
    noteEditBox:SetMultiLine(false)
    noteEditBox:SetMaxLetters(100)
    noteEditBox:SetAutoFocus(false)
    noteEditBox:SetFontObject(ChatFontNormal)
    noteEditBox:SetTextInsets(5, 5, 5, 5)

    noteEditBox:SetScript("OnEnter", tooltipOnEnter)
    noteEditBox:SetScript("OnLeave", tooltipOnLeave)

    if PSC_PlayerDetailFrame then
        PSC_PlayerDetailFrame.activeNoteEditBox = noteEditBox
    end

    if not PSC_DB then PSC_DB = {} end
    if not PSC_DB.PlayerInfoCache then PSC_DB.PlayerInfoCache = {} end

    -- Try to find existing entry (possibly from another realm)
    local playerCacheEntry, entryKey = PSC_GetPlayerInfo(playerDetail.name)

    -- If no entry found, create one for current realm
    if not entryKey then
        entryKey = PSC_GetInfoKeyFromName(playerDetail.name)
        PSC_DB.PlayerInfoCache[entryKey] = {}
        playerCacheEntry = PSC_DB.PlayerInfoCache[entryKey]
    end

    noteEditBox:SetText(playerCacheEntry.note or "")

    local function saveNoteFunction(self)
        local newText = self:GetText()
        if newText ~= (playerCacheEntry.note or "") then
            playerCacheEntry.note = newText

            local currentCharacterName = playerDetail.name
            for targetPlayerName in string.gmatch(newText, "@([^@%s]+)") do
                if targetPlayerName and targetPlayerName ~= currentCharacterName then
                    local linkedNoteText = string.gsub(newText, "@" .. targetPlayerName, "@" .. currentCharacterName)

                    local targetInfoKey = PSC_GetInfoKeyFromName(targetPlayerName)
                    if targetInfoKey then
                        if not PSC_DB.PlayerInfoCache[targetInfoKey] then
                            PSC_DB.PlayerInfoCache[targetInfoKey] = {}
                        end
                        PSC_DB.PlayerInfoCache[targetInfoKey].note = linkedNoteText
                    end
                end
            end
        end
    end

    noteEditBox:SetScript("OnEnterPressed", function(self)
        saveNoteFunction(self)
        self:ClearFocus()
    end)
    noteEditBox:SetScript("OnEscapePressed", function(self)
        saveNoteFunction(self)
        self:ClearFocus()
    end)
    noteEditBox:SetScript("OnEditFocusLost", function(self)
        saveNoteFunction(self)
    end)

    yOffset = yOffset - noteEditBoxHeight

    return yOffset - 20
end

-- Function to display the kill history section with individual entries
local function DisplayKillHistorySection(content, playerDetail, yOffset)
    yOffset = CreateSection(content, "Kill History", yOffset)

    -- Create header for individual kill entries
    local headerBg = content:CreateTexture(nil, "BACKGROUND")
    headerBg:SetPoint("TOPLEFT", 15, yOffset)
    headerBg:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, 0)
    headerBg:SetHeight(20)
    headerBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

    -- Column headers
    local levelHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    levelHeader:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.LEVEL, yOffset - 3)
    levelHeader:SetText("Level")
    levelHeader:SetTextColor(1, 0.82, 0)

    local zoneHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    zoneHeader:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.ZONE, yOffset - 3)
    zoneHeader:SetText("Zone")
    zoneHeader:SetTextColor(1, 0.82, 0)
    zoneHeader:SetWidth(PSC_COLUMN_WIDTHS.ZONE)
    zoneHeader:SetJustifyH("LEFT")

    local yourLevelHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    yourLevelHeader:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.KILLS, yOffset - 3)
    yourLevelHeader:SetText("Your Level")
    yourLevelHeader:SetTextColor(1, 0.82, 0)
    yourLevelHeader:SetWidth(PSC_COLUMN_WIDTHS.KILLS)
    yourLevelHeader:SetJustifyH("LEFT")

    local timeHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeHeader:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.TIME, yOffset - 3)
    timeHeader:SetText("Time")
    timeHeader:SetTextColor(1, 0.82, 0)

    yOffset = yOffset - 20

    -- Process kill history entries
    if playerDetail and playerDetail.killHistory and #playerDetail.killHistory > 0 then
        -- Sort by timestamp descending (most recent first)
        table.sort(playerDetail.killHistory, function(a, b)
            return (a.timestamp or 0) > (b.timestamp or 0)
        end)

        -- Create scrollable container if needed
        local tableParent, newYOffset = CreateScrollableTableContainer(content, #playerDetail.killHistory, yOffset)
        local entryYOffset = 0  -- Start from top of the container
        
        -- Display each kill history entry
        for i, killData in ipairs(playerDetail.killHistory) do
            entryYOffset = CreateKillHistoryEntry(tableParent, killData, i, entryYOffset)
        end
        
        yOffset = newYOffset
    else
        local noDataText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noDataText:SetPoint("TOPLEFT", 25, yOffset - 10)
        noDataText:SetText("No kill history available for this player.")
        noDataText:SetTextColor(0.7, 0.7, 0.7)
        yOffset = yOffset - 30
    end

    return yOffset - 20
end

local function CreateDeathHistoryHeaderRow(content, yOffset)
    local deathHeaderBg = content:CreateTexture(nil, "BACKGROUND")
    deathHeaderBg:SetPoint("TOPLEFT", 15, yOffset)
    deathHeaderBg:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, 0)
    deathHeaderBg:SetHeight(20)
    deathHeaderBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

    local killerLevelHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    killerLevelHeader:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.LEVEL, yOffset - 3)
    killerLevelHeader:SetText("Level")
    killerLevelHeader:SetTextColor(1, 0.82, 0)

    local deathZoneHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    deathZoneHeader:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.ZONE, yOffset - 3)
    deathZoneHeader:SetText("Zone")
    deathZoneHeader:SetTextColor(1, 0.82, 0)
    deathZoneHeader:SetWidth(PSC_COLUMN_WIDTHS.ZONE)
    deathZoneHeader:SetJustifyH("LEFT")

    local assistHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    assistHeader:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.KILLS, yOffset - 3)
    assistHeader:SetText("Assisters")
    assistHeader:SetTextColor(1, 0.82, 0)
    assistHeader:SetWidth(PSC_COLUMN_WIDTHS.KILLS)
    assistHeader:SetJustifyH("LEFT")

    local deathTimeHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    deathTimeHeader:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.TIME, yOffset - 3)
    deathTimeHeader:SetText("Time")
    deathTimeHeader:SetTextColor(1, 0.82, 0)

    return yOffset - 20
end

local function DisplayDeathHistorySection(content, playerDetail, yOffset)
    yOffset = CreateSection(content, "Death History", yOffset)
    yOffset = CreateDeathHistoryHeaderRow(content, yOffset)

    -- Death history entries
    if playerDetail.deathHistory and #playerDetail.deathHistory > 0 then
        -- Sort by timestamp descending (most recent first)
        local sortedDeathHistory = SortDeathHistoryByTimestamp(playerDetail.deathHistory)

        -- Create scrollable container if needed
        local tableParent, newYOffset = CreateScrollableTableContainer(content, #sortedDeathHistory, yOffset)
        local entryYOffset = 0  -- Start from top of the container
        
        for i, deathData in ipairs(sortedDeathHistory) do
            entryYOffset = CreateDeathHistoryEntry(tableParent, deathData, i, entryYOffset)
        end
        
        yOffset = newYOffset
    else
        local noDeathDataText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noDeathDataText:SetPoint("TOPLEFT", 25, yOffset - 10)
        noDeathDataText:SetText("No deaths by this player have been recorded.")
        noDeathDataText:SetTextColor(0.7, 0.7, 0.7)
        yOffset = yOffset - 30
    end

    return yOffset - 20
end

-- Create a header row for assist history
local function CreateAssistHistoryHeaderRow(content, yOffset)
    local assistHeaderBg = content:CreateTexture(nil, "BACKGROUND")
    assistHeaderBg:SetPoint("TOPLEFT", 15, yOffset)
    assistHeaderBg:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, 0)
    assistHeaderBg:SetHeight(20)
    assistHeaderBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

    local victimLevelHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    victimLevelHeader:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.LEVEL, yOffset - 3)
    victimLevelHeader:SetText("Level")
    victimLevelHeader:SetTextColor(1, 0.82, 0)

    local assistZoneHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    assistZoneHeader:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.ZONE, yOffset - 3)
    assistZoneHeader:SetText("Zone")
    assistZoneHeader:SetTextColor(1, 0.82, 0)
    assistZoneHeader:SetWidth(PSC_COLUMN_WIDTHS.ZONE)
    assistZoneHeader:SetJustifyH("LEFT")

    local killerHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    killerHeader:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.KILLS, yOffset - 3)
    killerHeader:SetText("Killer")
    killerHeader:SetTextColor(1, 0.82, 0)
    killerHeader:SetWidth(PSC_COLUMN_WIDTHS.KILLS)
    killerHeader:SetJustifyH("LEFT")

    local assistTimeHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    assistTimeHeader:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.TIME, yOffset - 3)
    assistTimeHeader:SetText("Time")
    assistTimeHeader:SetTextColor(1, 0.82, 0)

    return yOffset - 20
end


local function CreateAssistHistoryEntry(parent, assistData, index, yOffset)
    local bgColor = index % 2 == 0 and {0.1, 0.1, 0.1, 0.3} or {0.15, 0.15, 0.15, 0.3}

    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 15, yOffset)
    bg:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -15, 0)
    bg:SetHeight(20)
    bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])

    local levelText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    levelText:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.LEVEL, yOffset - 3)
    levelText:SetText(assistData.assisterLevel == -1 and "??" or tostring(assistData.assisterLevel))

    -- Find the specific level of the assister at the time of the kill, if available
    for _, otherAssister in ipairs(assistData.otherAssisters) do
        if PSC_IsSamePlayerName(otherAssister.name, assistData.assisterName) then
            levelText:SetText(otherAssister.level == -1 and "??" or tostring(otherAssister.level))
            break
        end
    end

    -- If we couldn't find level specifically for this event, fall back to the player's base level
    if not levelText:GetText() then
        levelText:SetText(assistData.assisterLevel == -1 and "??" or tostring(assistData.assisterLevel))
    end

    levelText:SetWidth(PSC_COLUMN_WIDTHS.LEVEL)

    -- Zone where the assist occurred
    local zoneText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    zoneText:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.ZONE, yOffset - 3)
    zoneText:SetText(assistData.zone or "Unknown")
    zoneText:SetWidth(PSC_COLUMN_WIDTHS.ZONE)
    zoneText:SetJustifyH("LEFT")

    -- Create a frame for the killer info with tooltip
    local killerFrame = CreateFrame("Frame", nil, parent)
    killerFrame:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.KILLS, yOffset - 3)
    killerFrame:SetSize(100, 20)

    local killerText = killerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    killerText:SetPoint("TOPLEFT", 0, 0)

    -- Format killer name for display (show asterisk if from different realm)
    local displayKillerName = assistData.killerName or "Unknown"
    local isDifferentRealm, cleanName = PSC_IsPlayerFromDifferentRealm(displayKillerName)
    if cleanName then
        displayKillerName = cleanName .. (isDifferentRealm and "*" or "")
    end

    killerText:SetText(displayKillerName)
    killerText:SetWidth(PSC_COLUMN_WIDTHS.KILLS)
    killerText:SetJustifyH("LEFT")

    -- Color the killer name based on class if known
    local killerInfo = PSC_GetPlayerInfo(assistData.killerName)
    if killerInfo.class and RAID_CLASS_COLORS[killerInfo.class:upper()] then
        local color = RAID_CLASS_COLORS[killerInfo.class:upper()]
        killerText:SetTextColor(color.r, color.g, color.b)
    else
        -- Use default white color for unknown players
        killerText:SetTextColor(1, 1, 1)
    end

    -- Add tooltip with killer info
    killerFrame:SetScript("OnEnter", function(self)
        if not assistData.killerName then return end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Main Killer:", 1, 0.82, 0, 1)

        -- Format killer info with class color if available
        local killerInfo = PSC_GetPlayerInfo(assistData.killerName)
        if killerInfo.class then
            local killerLevel = killerInfo.level == -1 and "??" or tostring(killerInfo.level)
            local killerClass = killerInfo.class or "Unknown"
            local color = RAID_CLASS_COLORS[killerClass:upper()] or {r=1, g=1, b=1}
            local displayText = string.format("%s (Level %s %s)", assistData.killerName, killerLevel, killerClass)
            GameTooltip:AddLine(displayText, color.r, color.g, color.b)
        else
            -- Use white color for unknown players
            GameTooltip:AddLine(assistData.killerName, 1, 1, 1)
        end

        -- Add other assisters if any
        if assistData.otherAssisters and #assistData.otherAssisters > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Other Assisters:", 1, 0.82, 0)

            for _, assister in ipairs(assistData.otherAssisters) do
                local assisterInfo = PSC_GetPlayerInfo(assister.name)
                if assisterInfo.class then
                    local assisterLevel = assisterInfo.level == -1 and "??" or tostring(assisterInfo.level)
                    local assisterClass = assisterInfo.class or "Unknown"
                    local color = RAID_CLASS_COLORS[assisterClass:upper()] or {r=1, g=1, b=1}
                    local displayText = string.format("%s (Level %s %s)", assister.name, assisterLevel, assisterClass)
                    GameTooltip:AddLine(displayText, color.r, color.g, color.b)
                else
                    -- Use white color for unknown players
                    GameTooltip:AddLine(assister.name, 1, 1, 1)
                end
            end
        end

        GameTooltip:Show()
    end)

    killerFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Timestamp
    local timeText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timeText:SetPoint("TOPLEFT", PSC_COLUMN_POSITIONS.TIME, yOffset - 3)
    timeText:SetText(PSC_FormatTimestamp(assistData.timestamp))

    return yOffset - 20
end

-- Scan all death records to find times this player assisted in killing me
local function GetAssistHistoryForPlayer(playerName)
    local assistHistory = {}
    local characterKey = PSC_GetCharacterKey()

    if PSC_DB.ShowAccountWideStats then
        -- Scan all characters
        if PSC_DB.PvPLossCounts then
            for cKey, charData in pairs(PSC_DB.PvPLossCounts) do
                if charData.Deaths then
                    for killerName, deathData in pairs(charData.Deaths) do
                         if deathData.deathLocations then
                             for _, loc in ipairs(deathData.deathLocations) do
                                 if loc.assisters then
                                     for _, assister in ipairs(loc.assisters) do
                                         if PSC_IsSamePlayerName(assister.name, playerName) then
                                             -- Found an assist!
                                             table.insert(assistHistory, {
                                                 timestamp = loc.timestamp,
                                                 zone = loc.zone,
                                                 killerName = killerName, -- The main killer
                                                 killerLevel = loc.killerLevel,
                                                 assisterLevel = assister.level, -- Level of our target player
                                                 assisterClass = assister.class,
                                                 otherAssisters = loc.assisters, -- full list
                                                 assisterName = assister.name
                                             })
                                         end
                                     end
                                 end
                             end
                         end
                    end
                end
            end
        end
    else
        -- Scan current character only
        local lossData = PSC_DB.PvPLossCounts[characterKey]
        if lossData and lossData.Deaths then
            for killerName, deathData in pairs(lossData.Deaths) do
                 if deathData.deathLocations then
                     for _, loc in ipairs(deathData.deathLocations) do
                         if loc.assisters then
                             for _, assister in ipairs(loc.assisters) do
                                 if PSC_IsSamePlayerName(assister.name, playerName) then
                                     table.insert(assistHistory, {
                                         timestamp = loc.timestamp,
                                         zone = loc.zone,
                                         killerName = killerName,
                                         killerLevel = loc.killerLevel,
                                         assisterLevel = assister.level,
                                         assisterClass = assister.class,
                                         otherAssisters = loc.assisters,
                                         assisterName = assister.name
                                     })
                                 end
                             end
                         end
                     end
                 end
            end
        end
    end

    return assistHistory
end

-- Collect and display assist history
local function DisplayAssistHistorySection(content, playerDetail, yOffset)
    local assistHistory = GetAssistHistoryForPlayer(playerDetail.name)

    yOffset = CreateSection(content, "Assist History (Against You)", yOffset)
    yOffset = CreateAssistHistoryHeaderRow(content, yOffset)

    if #assistHistory > 0 then
        -- Sort by timestamp descending (most recent first)
        table.sort(assistHistory, function(a, b)
            return (a.timestamp or 0) > (b.timestamp or 0)
        end)

        -- Create scrollable container if needed
        local tableParent, newYOffset = CreateScrollableTableContainer(content, #assistHistory, yOffset)
        local entryYOffset = 0  -- Start from top of the container
        
        for i, assistData in ipairs(assistHistory) do
            entryYOffset = CreateAssistHistoryEntry(tableParent, assistData, i, entryYOffset)
        end
        
        yOffset = newYOffset
    else
        local noAssistDataText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noAssistDataText:SetPoint("TOPLEFT", 25, yOffset - 10)
        noAssistDataText:SetText("No assists by this player have been recorded.")
        noAssistDataText:SetTextColor(0.7, 0.7, 0.7)
        yOffset = yOffset - 30
    end

    return yOffset - 20
end

-- Main function to display the player detail frame
function PSC_ShowPlayerDetailFrame(playerName, focusNote)
    if not playerName then return end

    local playerDetail = PSC_CreatePlayerDetailInfo(playerName)
    if not playerDetail then
        print("Could not find detailed information for player:", playerName)
        return
    end

    if not PSC_PlayerDetailFrame then
        PSC_PlayerDetailFrame = CreatePlayerDetailFrame()
        PSC_FrameManager:RegisterFrame(PSC_PlayerDetailFrame, "PlayerDetail")
    else
        CleanupPlayerDetailFrame(PSC_PlayerDetailFrame.content)
    end

    if PSC_PlayerDetailFrame then
        PSC_PlayerDetailFrame.activeNoteEditBox = nil
    end

    local content = PSC_PlayerDetailFrame.content
    local isFromDifferentRealm, cleanPlayerName, playerRealm = PSC_IsPlayerFromDifferentRealm(playerName)
    local titleName = cleanPlayerName or playerName
    if isFromDifferentRealm and playerRealm then
        titleName = titleName .. "-" .. playerRealm
    end
    local titleText = "Player History - " .. titleName
    PSC_PlayerDetailFrame.TitleText:SetText(titleText)

    PSC_FrameManager:ShowFrame("PlayerDetail")

    local yOffset = 0

    yOffset = DisplayPlayerSummarySection(content, playerDetail, yOffset)
    yOffset = DisplayKillHistorySection(content, playerDetail, yOffset)
    yOffset = DisplayDeathHistorySection(content, playerDetail, yOffset)
    yOffset = DisplayAssistHistorySection(content, playerDetail, yOffset)

    content:SetHeight(math.abs(yOffset) + 30)

    if focusNote and PSC_PlayerDetailFrame and PSC_PlayerDetailFrame.activeNoteEditBox then
        PSC_PlayerDetailFrame.activeNoteEditBox:SetFocus()
        PSC_PlayerDetailFrame.activeNoteEditBox:HighlightText(0, -1)
    end

end
