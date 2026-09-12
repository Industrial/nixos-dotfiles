local addonName, PVPSC = ...

PVPSC.AchievementSystem = PVPSC.AchievementSystem or {}
local AchievementSystem = PVPSC.AchievementSystem

local statisticsFrame = nil

local UI = {
    FRAME = {
        WIDTH = 850,
        HEIGHT = 700
    },
    CHART = {
        WIDTH = 360,
        PADDING = 1
    },
    BAR = {
        HEIGHT = 16,
        SPACING = 3,
        TEXT_OFFSET = 5
    },
    GUILD_LIST = {
        WIDTH = 400,
        HEIGHT = 300
    },
    TITLE_SPACING = 3,
    TOP_PADDING = 40,
    LEFT_SCROLL_PADDING = 20,
    ZONE_NAME_WIDTH = 160,
    NPC_NAME_WIDTH = 130,
    STANDARD_NAME_WIDTH = 80
}

local raceColors = {
    ["Human"] = {
        r = 0.93,
        g = 0.84,
        b = 0.62
    },
    ["Dwarf"] = {
        r = 0.57,
        g = 0.85,
        b = 0.20
    },
    ["Night Elf"] = {
        r = 0.47,
        g = 0.36,
        b = 0.86
    },
    ["Gnome"] = {
        r = 0.986,
        g = 0.67,
        b = 0.22
    },
    ["Orc"] = {
        r = 0.30,
        g = 0.58,
        b = 0.26
    },
    ["Troll"] = {
        r = 0.20,
        g = 0.83,
        b = 0.76
    },
    ["Tauren"] = {
        r = 0.71,
        g = 0.49,
        b = 0.26
    },
    ["Blood Elf"] = {
        r = 0.86,
        g = 0.30,
        b = 0.36
    },
    ["Draenei"] = {
        r = 0.11,
        g = 0.57,
        b = 0.94
    },
    ["Undead"] = {
        r = 0.50,
        g = 0.45,
        b = 0.60
    }
}

local genderColors = {
    ["Male"] = {
        r = 0.40,
        g = 0.60,
        b = 1.00
    },
    ["Female"] = {
        r = 1.00,
        g = 0.41,
        b = 0.71
    }
}

local ALL_CLASSES = {"Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid"}

local DEFAULT_CHART_ORDER = {
    "kills_by_class",
    "deaths_by_class",
    "kd_by_class",
    "monthly_class_percentage",
    "kills_by_race",
    "npc_kills",
    "kills_by_gender",
    "kills_by_guild_status",
    "kills_by_hour",
    "kills_by_weekday",
    "kills_by_month",
    "kills_by_year",
    "kills_by_level",
    "kills_by_zone",
    "kills_by_guild",
}

local function copyArray(arr)
    local copy = {}
    for i = 1, #arr do
        copy[i] = arr[i]
    end
    return copy
end

local function getChartOrder()
    if not PSC_DB or not PSC_DB.StatisticsChartOrder then
        return copyArray(DEFAULT_CHART_ORDER)
    end
    local present = {}
    for _, id in ipairs(PSC_DB.StatisticsChartOrder) do
        present[id] = true
    end
    local order = copyArray(PSC_DB.StatisticsChartOrder)
    for _, id in ipairs(DEFAULT_CHART_ORDER) do
        if not present[id] then
            table.insert(order, id)
        end
    end
    return order
end

local function saveChartOrder(order)
    PSC_DB.StatisticsChartOrder = order
end

local reorderButtonCleanups = {}

local function clearReorderButtonScripts()
    GameTooltip:Hide()
    for _, btn in ipairs(reorderButtonCleanups) do
        btn:SetScript("OnClick", nil)
        btn:SetScript("OnEnter", nil)
        btn:SetScript("OnLeave", nil)
    end
    reorderButtonCleanups = {}
end

local reorderChartContainers

local function makeChartSwapCallback(idA, idB)
    return function()
        local order = copyArray(getChartOrder())
        local posA, posB
        for j, id in ipairs(order) do
            if id == idA then posA = j
            elseif id == idB then posB = j end
        end
        if posA and posB then
            order[posA], order[posB] = order[posB], order[posA]
        end
        saveChartOrder(order)
        reorderChartContainers(statisticsFrame)
    end
end

local function createScrollArrowButton(parent, isUp)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(16, 16)
    if isUp then
        btn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
        btn:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down")
        btn:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Highlight", "ADD")
    else
        btn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
        btn:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
        btn:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight", "ADD")
    end
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(isUp and "Move chart up" or "Move chart down", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(reorderButtonCleanups, btn)
    return btn
end

local function addChartReorderButtonsOnce(container)
    local downBtn = createScrollArrowButton(container, false)
    downBtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -1)
    downBtn:Hide()
    container.moveDownBtn = downBtn

    local upBtn = createScrollArrowButton(container, true)
    upBtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", -18, -1)
    upBtn:Hide()
    container.moveUpBtn = upBtn
end

local function updateChartReorderButtons(orderedCharts)
    for i, rendered in ipairs(orderedCharts) do
        local container = rendered.container
        if i > 1 then
            container.moveUpBtn:SetScript("OnClick", makeChartSwapCallback(rendered.id, orderedCharts[i - 1].id))
            container.moveUpBtn:Show()
        else
            container.moveUpBtn:SetScript("OnClick", nil)
            container.moveUpBtn:Hide()
        end
        if i < #orderedCharts then
            container.moveDownBtn:SetScript("OnClick", makeChartSwapCallback(rendered.id, orderedCharts[i + 1].id))
            container.moveDownBtn:Show()
        else
            container.moveDownBtn:SetScript("OnClick", nil)
            container.moveDownBtn:Hide()
        end
    end
end

reorderChartContainers = function(frame)
    local chartOrder = getChartOrder()
    local yOffset = 0
    local orderedCharts = {}
    for _, chartId in ipairs(chartOrder) do
        local entry = frame.chartContainers and frame.chartContainers[chartId]
        if entry then
            entry.container:ClearAllPoints()
            entry.container:SetPoint("TOPLEFT", 0, yOffset)
            table.insert(orderedCharts, { id = chartId, container = entry.container })
            yOffset = yOffset - entry.height - UI.CHART.PADDING
        end
    end
    if frame.resetOrderBtn then
        frame.resetOrderBtn:ClearAllPoints()
        frame.resetOrderBtn:SetPoint("TOPLEFT", 0, yOffset - 10)
        frame.leftScrollContent:SetHeight(-yOffset + 57)
    else
        frame.leftScrollContent:SetHeight(-yOffset + 25)
    end
    updateChartReorderButtons(orderedCharts)
end

local LINE_CHART_UI = {
    HEIGHT = 235,
    LEFT_PADDING = 42,
    RIGHT_PADDING = 8,
    TOP_PADDING = 28,
    BOTTOM_PADDING = 36,
    GRID_LINES = 5,
    POINT_SIZE = 4,
    LINE_THICKNESS = 2,
    LEGEND_COLUMNS = 3,
    LEGEND_ROW_HEIGHT = 14,
    LEGEND_ITEM_WIDTH = 78,
    LEGEND_COLUMN_SPACING = 4
}

local function sortByValue(tbl, descending)
    if not tbl then
        return {}
    end

    local sorted = {}
    for k, v in pairs(tbl) do
        local safeKey = k or "Unknown"
        local safeValue = v or 0
        table.insert(sorted, {
            key = safeKey,
            value = safeValue
        })
    end

    if #sorted == 0 then
        return {}
    end

    if descending then
        table.sort(sorted, function(a, b)
            if not a.value then
                return false
            end
            if not b.value then
                return true
            end
            return a.value > b.value
        end)
    else
        table.sort(sorted, function(a, b)
            if not a.value then
                return true
            end
            if not b.value then
                return false
            end
            return a.value < b.value
        end)
    end

    return sorted
end

local function properCase(str)
    if not str or str == "" then
        return "Unknown"
    end
    if str:len() <= 1 then
        return str:upper()
    end
    return str:sub(1, 1):upper() .. str:sub(2):lower()
end

local function getClassColor(class)
    if not class or class == "Unknown" then
        return {
            r = 0.8,
            g = 0.8,
            b = 0.8
        }
    end

    local classUpper = string.upper(class)

    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classUpper] then
        return {
            r = RAID_CLASS_COLORS[classUpper].r,
            g = RAID_CLASS_COLORS[classUpper].g,
            b = RAID_CLASS_COLORS[classUpper].b
        }
    else
        local fallbackColors = {
            ["WARRIOR"] = {
                r = 0.78,
                g = 0.61,
                b = 0.43
            },
            ["PALADIN"] = {
                r = 0.96,
                g = 0.55,
                b = 0.73
            },
            ["HUNTER"] = {
                r = 0.67,
                g = 0.83,
                b = 0.45
            },
            ["ROGUE"] = {
                r = 1.00,
                g = 0.96,
                b = 0.41
            },
            ["PRIEST"] = {
                r = 1.00,
                g = 1.00,
                b = 1.00
            },
            ["SHAMAN"] = {
                r = 0.00,
                g = 0.44,
                b = 0.87
            },
            ["MAGE"] = {
                r = 0.25,
                g = 0.78,
                b = 0.92
            },
            ["WARLOCK"] = {
                r = 0.53,
                g = 0.53,
                b = 0.93
            },
            ["DRUID"] = {
                r = 1.00,
                g = 0.49,
                b = 0.04
            }
        }

        return fallbackColors[classUpper] or {
            r = 0.8,
            g = 0.8,
            b = 0.8
        }
    end
end

local function calculateChartHeight(data, includeZeroKeys)
    if not data then return 30 + 15 end -- Minimum height for title + padding

    local entries = 0
    for key, numKills in pairs(data) do
        if numKills > 0 then
            entries = entries + 1
        elseif includeZeroKeys and includeZeroKeys[key] then
            entries = entries + 1
        end
    end
    return 30 + (entries * (UI.BAR.HEIGHT + UI.BAR.SPACING)) + 15
end

local function createContainerWithTitle(parent, title, x, y, width, height, lineWidth)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, height)
    container:SetPoint("TOPLEFT", x, y)

    local titleText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", 0, 0)
    titleText:SetText(title)
    container.titleText = titleText

    local line = container:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 0, -15)
    line:SetSize(lineWidth or width, 1)
    line:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    return container
end

local function AddSummaryStatsTitleMeta(container, info)
    if not container or not container.titleText then
        return
    end

    local titleText = container.titleText
    local lastAnchor = titleText
    local titleInfo = info or {}
    local allowLocalFallback = titleInfo.allowLocalFallback ~= false

    if allowLocalFallback and not titleInfo.class and not titleInfo.race and not titleInfo.guild then
        local playerInfo = PSC_GetPlayerInfo(UnitName("player"))
        titleInfo.class = playerInfo and playerInfo.class or nil
        titleInfo.race = playerInfo and playerInfo.race or nil
        titleInfo.gender = playerInfo and playerInfo.gender or nil
        titleInfo.guild = playerInfo and playerInfo.guild or GetGuildInfo("player") or nil
    end

    if allowLocalFallback and titleInfo.guild == nil then
        titleInfo.guild = GetGuildInfo("player") or nil
    end

    if titleInfo.race and titleInfo.race ~= "Unknown" and titleInfo.gender and titleInfo.gender ~= "Unknown" then
        local raceIcon = container:CreateTexture(nil, "ARTWORK")
        raceIcon:SetSize(15, 15)
        raceIcon:SetPoint("LEFT", lastAnchor, "RIGHT", 6, 0)

        local raceKey = titleInfo.race:gsub(" ", ""):upper() .. "_" .. titleInfo.gender:upper()
        local raceIconID = RACE_ICON_IDS[raceKey]
        if raceIconID then
            raceIcon:SetTexture(raceIconID)
            raceIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            raceIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            raceIcon:SetTexCoord(0, 1, 0, 1)
        end

        if raceIconID and type(raceIconID) == "string" then
            local raceBorder = container:CreateTexture(nil, "OVERLAY")
            raceBorder:SetSize(26, 26)
            raceBorder:SetPoint("CENTER", raceIcon, "CENTER")
            raceBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        end

        lastAnchor = raceIcon
    end

    if titleInfo.class and titleInfo.class ~= "Unknown" then
        local classIcon = container:CreateTexture(nil, "ARTWORK")
        classIcon:SetSize(16, 16)
        classIcon:SetPoint("LEFT", lastAnchor, "RIGHT", 4, 0)

        local classTexture = "Interface\\TargetingFrame\\UI-Classes-Circles"
        local coords = CLASS_ICON_TCOORDS[titleInfo.class:upper()]
        if coords then
            classIcon:SetTexture(classTexture)
            classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else
            classIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        local classBorder = container:CreateTexture(nil, "BORDER")
        classBorder:SetSize(16, 16)
        classBorder:SetPoint("CENTER", classIcon, "CENTER")
        classBorder:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        classBorder:SetColorTexture(0.83, 0.69, 0.22)

        local maskTexture = container:CreateMaskTexture()
        maskTexture:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        maskTexture:SetSize(16, 16)
        maskTexture:SetPoint("CENTER", classIcon, "CENTER")
        classBorder:AddMaskTexture(maskTexture)

        lastAnchor = classIcon
    end

    if titleInfo.guild and titleInfo.guild ~= "" then
        local guildText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        guildText:SetPoint("LEFT", lastAnchor, "RIGHT", 6, 0)
        guildText:SetText("(" .. titleInfo.guild .. ")")
        guildText:SetTextColor(0.7, 0.7, 0.7)
    end
end

local function NormalizeMonthKey(key)
    local num = tonumber(key)
    if num and num >= 1 and num <= 12 then return num end

    local keyLower = string.lower(tostring(key))
    local months = {
        january = 1, february = 2, march = 3, april = 4, may = 5, june = 6,
        july = 7, august = 8, september = 9, october = 10, november = 11, december = 12,
        jan = 1, feb = 2, mar = 3, apr = 4, jun = 6, jul = 7, aug = 8, sep = 9, oct = 10, nov = 11, dec = 12
    }
    if months[keyLower] then return months[keyLower] end
    return nil
end

local function NormalizeWeekdayKey(key)
    local num = tonumber(key)
    if num and num >= 1 and num <= 7 then return num end

    local keyLower = string.lower(tostring(key))
    local days = {
        sunday = 1, monday = 2, tuesday = 3, wednesday = 4, thursday = 5, friday = 6, saturday = 7,
        sun = 1, mon = 2, tue = 3, wed = 4, thu = 5, fri = 6, sat = 7
    }
    if days[keyLower] then return days[keyLower] end
    return nil
end

local function createBar(container, entry, index, maxValue, total, titleType, disableClicks, extraData)
    local barWidth
    local nameWidth
    local barX
    local maxBarWidth

    if titleType == "zone" then
        nameWidth = UI.ZONE_NAME_WIDTH
        barX = nameWidth + 10
        maxBarWidth = UI.CHART.WIDTH - nameWidth - 110
    elseif titleType == "npc" then
        nameWidth = UI.NPC_NAME_WIDTH
        barX = nameWidth + 10
        maxBarWidth = UI.CHART.WIDTH - nameWidth - 110
    else
        nameWidth = UI.STANDARD_NAME_WIDTH
        barX = 90
        maxBarWidth = UI.CHART.WIDTH - 190
    end

    if maxValue > 0 then
        barWidth = (entry.value / maxValue) * maxBarWidth
    else
        barWidth = 0.5 -- Very thin line if no kills at all (shouldn't really happen with filter, but for safety)
    end

    if titleType == "npc" and barWidth < 1 then
         barWidth = 1 -- Minimum visibility
    end

    local barY = -(index * (UI.BAR.HEIGHT + UI.BAR.SPACING) + UI.TITLE_SPACING)

    local displayName = entry.key
    if titleType == "class" then
        displayName = properCase(entry.key)
    elseif titleType == "hour" then
        local hour = tonumber(entry.key)
        if hour then
            local endHour = (hour + 1) % 24
            displayName = string.format("%02d - %02d", hour, endHour)
        end
    elseif titleType == "weekday" then
        local weekdayNames = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
        local weekday = tonumber(entry.key)
        if weekday and weekdayNames[weekday] then
            displayName = weekdayNames[weekday]
        end
    elseif titleType == "month" then
        local monthNames = {"January", "February", "March", "April", "May", "June",
                           "July", "August", "September", "October", "November", "December"}
        local month = tonumber(entry.key)
        if month and monthNames[month] then
            displayName = monthNames[month]
        end
    elseif titleType == "year" then
        displayName = tostring(entry.key)
    end

    local barButton = CreateFrame("Button", nil, container)
    barButton:SetSize(UI.CHART.WIDTH, UI.BAR.HEIGHT)
    barButton:SetPoint("TOPLEFT", 0, barY)

    -- Only add highlight and click functionality for clickable chart types
    local isClickable = titleType ~= "hour" and titleType ~= "weekday" and titleType ~= "month" and titleType ~= "year" and titleType ~= "npc"

    if disableClicks then
        isClickable = false
    end

    if isClickable then
        local highlightTexture = PSC_CreateGoldHighlight(barButton, UI.BAR.HEIGHT)
    end

    barButton:SetScript("OnEnter", function(self)
        if disableClicks then return end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(displayName)

        if titleType == "class" or titleType == "unknownLevelClass" then
            if isClickable then
                GameTooltip:AddLine("Click to show all kills for this class", 1, 1, 1, true)
            end
        elseif titleType == "deathsClass" then
            if isClickable then
                GameTooltip:AddLine("Click to show all deaths from this class", 1, 1, 1, true)
            end
        elseif titleType == "zone" then
            if isClickable then
                GameTooltip:AddLine("Click to show all kills for this zone", 1, 1, 1, true)
            end
        elseif titleType == "level" then
            if isClickable then
                if entry.key == "??" then
                    GameTooltip:AddLine("Click to show all kill for level ??", 1, 1, 1, true)
                else
                    GameTooltip:AddLine("Click to show all kills for this level", 1, 1, 1, true)
                end
            end
        elseif titleType == "hour" then
            local hour = tonumber(entry.key)
            if hour then
                local startTime = string.format("%02d:00", hour)
                local endTime = string.format("%02d:00", (hour + 1) % 24)
                GameTooltip:AddLine("Kills between " .. startTime .. " and " .. endTime, 1, 1, 1, true)
            end
        elseif titleType == "weekday" then
            GameTooltip:AddLine("Kills on " .. displayName, 1, 1, 1, true)
        elseif titleType == "month" then
            if extraData then
                local yearData = extraData[entry.key]
                if yearData then
                    local years = {}
                    for year in pairs(yearData) do table.insert(years, year) end
                    table.sort(years)
                    for _, year in ipairs(years) do
                        GameTooltip:AddLine(tostring(year) .. ": " .. yearData[year], 0.8, 0.8, 0.8)
                    end
                end
            end
        elseif titleType == "year" then
            GameTooltip:AddLine("Kills in " .. displayName, 1, 1, 1, true)
        elseif titleType == raceColors then
            if isClickable then
                GameTooltip:AddLine("Click to show all kills for this race", 1, 1, 1, true)
            end
        elseif titleType == genderColors then
            if isClickable then
                GameTooltip:AddLine("Click to show all kills for this gender", 1, 1, 1, true)
            end
        end

        GameTooltip:Show()
    end)

    barButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Only add click functionality for clickable chart types
    if isClickable then
        barButton:SetScript("OnClick", function()
            PSC_CreateKillsListFrame()
            C_Timer.After(0.05, function()
                if titleType == "class" or titleType == "unknownLevelClass" then
                    PSC_SetKillListSearch("", nil, entry.key, nil, nil, nil, true)
                elseif titleType == "deathsClass" then
                    PSC_SetKillListSearch("", nil, entry.key, nil, nil, nil, true)
                    PSC_SetKillListMinDeaths(1)
                elseif titleType == "zone" then
                    PSC_SetKillListSearch("", nil, nil, nil, nil, entry.key, true)
                elseif titleType == "level" then
                    if entry.key == "??" then
                        PSC_SetKillListLevelRange(-1, -1, true)
                    else
                        local level = tonumber(entry.key)
                        if level then
                            PSC_SetKillListLevelRange(level, level, true)
                        end
                    end
                elseif titleType == raceColors then
                    PSC_SetKillListSearch("", nil, nil, entry.key, nil, nil, true)
                elseif titleType == genderColors then
                    PSC_SetKillListSearch("", nil, nil, nil, entry.key, nil, true)
                end

                PSC_FrameManager:BringToFront("KillsList")
            end)
        end)
    end

    local itemLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemLabel:SetPoint("TOPLEFT", 0, barY)
    itemLabel:SetText(displayName)
    itemLabel:SetWidth(nameWidth)
    itemLabel:SetJustifyH("LEFT")

    local color
    if titleType == "level" and entry.key ~= "??" then
        local level = tonumber(entry.key) or 0

        if level <= 60 then
            -- Levels 1-60: existing blue-to-red gradient (ratio based on /70 for continuity)
            local ratio = level / 70
            color = {
                r = math.min(1.0, ratio * 2),
                g = 0.1 + math.max(0, 0.7 - ratio * 0.7),
                b = math.max(0, 1.0 - ratio * 1.5)
            }
        else
            -- Levels 61-70: red of level 60 fading into purple at level 70
            local subRatio = (level - 60) / 10
            color = {
                r = 1.0 - 0.4 * subRatio,
                g = 0.2 - 0.1 * subRatio,
                b = 0.9 * subRatio
            }
        end
    elseif titleType == "level" and entry.key == "??" then
        color = {
            r = 0.4,
            g = 0.0,
            b = 1.0
        }
    elseif titleType == "class" or titleType == "unknownLevelClass" or titleType == "deathsClass" then
        color = getClassColor(entry.key)
    elseif titleType == "hour" then
        -- Light red for hour charts
        color = {
            r = 1.0,
            g = 0.6,
            b = 0.6
        }
    elseif titleType == "weekday" then
        -- Light blue for weekday charts
        color = {
            r = 0.6,
            g = 0.8,
            b = 1.0
        }
    elseif titleType == "month" then
        -- Light yellow for month charts
        color = {
            r = 1.0,
            g = 1.0,
            b = 0.6
        }
    elseif titleType == "year" then
        -- Medium green for year charts
        color = {
            r = 0.4,
            g = 0.8,
            b = 0.4
        }
    elseif titleType == "npc" then
        if entry.key == "Corporal Keeshan" then
            -- Redridge Mountains orange
            color = {
                r = 0.85,
                g = 0.35,
                b = 0.10
            }
        elseif entry.key == "The Defias Traitor" then
            -- Westfall yellowish/tan
            color = {
                r = 0.90,
                g = 0.75,
                b = 0.40
            }
        elseif entry.key == "Defias Messenger" then
            -- Defias Red
            color = {
                r = 0.80,
                g = 0.20,
                b = 0.20
            }
        else
            color = {
                r = 0.8,
                g = 0.8,
                b = 0.8
            }
        end
    else
        color = titleType and titleType[entry.key] or {
            r = 0.8,
            g = 0.8,
            b = 0.8
        }
    end

    local bar = container:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", barX, barY)
    bar:SetSize(barWidth, UI.BAR.HEIGHT)
    bar:SetColorTexture(color.r, color.g, color.b, 0.9)

    local valueLabel = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueLabel:SetPoint("LEFT", bar, "RIGHT", UI.BAR.TEXT_OFFSET, 0)

    local percentage = (total > 0) and (entry.value / total * 100) or 0
    local valueText = entry.value .. " (" .. PSC_FormatPercent(percentage, 1) .. ")"
    valueLabel:SetText(valueText)

    local estimatedTextWidth = string.len(valueText) * 6

    if barX + barWidth + estimatedTextWidth > (UI.CHART.WIDTH - 25) then
        valueLabel:SetText(entry.value)
    end
end

local function createBarChart(parent, title, data, colorTable, x, y, width, height, disableClicks, extraData)
    local container = createContainerWithTitle(parent, title, x, y, width, height)

    -- Pre-process data to handle numeric/string key duplication and normalization
    local processedData = {}
    if data then
        for k, v in pairs(data) do
            local finalKey = k

            if title == "Kills by Month" then
                local norm = NormalizeMonthKey(k)
                if norm then finalKey = norm end
            elseif title == "Kills by Weekday" then
                local norm = NormalizeWeekdayKey(k)
                if norm then finalKey = norm end
            elseif title == "Kills by Hour of Day" or title == "Kills by Year" then
                local num = tonumber(k)
                if num then finalKey = num end
            elseif title == "Kills by Level" then
                if k ~= "??" then
                    local num = tonumber(k)
                    if num then finalKey = num end
                end
            end

            -- Ensure we don't valid keys
            if finalKey then
                 processedData[finalKey] = (processedData[finalKey] or 0) + v
            end
        end
    end

    local sortedData = sortByValue(processedData, true)
    local filteredData = {}
    for _, entry in ipairs(sortedData) do
        if entry.value > 0 or title == "NPC Kills" then
            table.insert(filteredData, entry)
        end
    end

    local maxValue = filteredData[1] and filteredData[1].value or 0

    local total = 0
    for _, entry in ipairs(filteredData) do
        total = total + entry.value
    end

    if (title == "Kills by Level") then
        local sortedLevelData = {}
        local unknownLevelEntry
        for i, entry in ipairs(filteredData) do
            if entry.key == "??" then
                unknownLevelEntry = entry
                table.remove(filteredData, i)
                break
            end
        end

        table.sort(filteredData, function(a, b)
            local aNum = tonumber(a.key) or 0
            local bNum = tonumber(b.key) or 0
            return aNum < bNum
        end)

        if unknownLevelEntry then
            table.insert(filteredData, unknownLevelEntry)
        end
    elseif (title == "Kills by Hour of Day") then
        -- Sort hours numerically from 0 to 23
        table.sort(filteredData, function(a, b)
            local aNum = tonumber(a.key) or 0
            local bNum = tonumber(b.key) or 0
            return aNum < bNum
        end)
    elseif (title == "Kills by Weekday") then
        -- Sort weekdays from Sunday (1) to Saturday (7)
        table.sort(filteredData, function(a, b)
            local aNum = tonumber(a.key) or 0
            local bNum = tonumber(b.key) or 0
            return aNum < bNum
        end)
    elseif (title == "Kills by Month") then
        -- Sort months from January (1) to December (12)
        table.sort(filteredData, function(a, b)
            local aNum = tonumber(a.key) or 0
            local bNum = tonumber(b.key) or 0
            return aNum < bNum
        end)
    elseif (title == "Kills by Year") then
        -- Sort years chronologically
        table.sort(filteredData, function(a, b)
            local aNum = tonumber(a.key) or 0
            local bNum = tonumber(b.key) or 0
            return aNum < bNum
        end)
    end

    local titleType
    if title == "Kills by Class" then
        titleType = "class"
    elseif title == "Deaths by Class" then
        titleType = "deathsClass"
    elseif title == "Level ?? Kills by Class" then
        titleType = "unknownLevelClass"
    elseif title == "Kills by Zone" then
        titleType = "zone"
    elseif title == "NPC Kills" then
        titleType = "npc"
    elseif title == "Kills by Level" then
        titleType = "level"
    elseif title == "Kills by Hour of Day" then
        titleType = "hour"
    elseif title == "Kills by Weekday" then
        titleType = "weekday"
    elseif title == "Kills by Month" then
        titleType = "month"
    elseif title == "Kills by Year" then
        titleType = "year"
    else
        titleType = colorTable
    end

    for i, entry in ipairs(filteredData) do
        createBar(container, entry, i, maxValue, total, titleType, disableClicks, extraData)
    end

    return container
end

function PSC_GetWinPercentageColor(pct)
    if pct == 100 then
        return { r = 1.0, g = 0.82, b = 0.0 }
    elseif pct >= 70 then
        return { r = 0.0, g = 1.0, b = 0.0 }
    elseif pct >= 51 then
        return { r = 0.56, g = 1.0, b = 0.56 }
    elseif pct >= 40 then
        return { r = 1.0, g = 1.0, b = 0.0 }
    elseif pct >= 30 then
        return { r = 1.0, g = 0.5, b = 0.0 }
    else
        return { r = 1.0, g = 0.0, b = 0.0 }
    end
end

function PSC_FormatPercent(pct, decimals)
    decimals = decimals or 2
    if math.abs(pct - 100) < 1e-6 then
        return "100%"
    end
    local fmt = "%." .. tostring(decimals) .. "f%%"
    return string.format(fmt, pct)
end

local function createKDByClassBarChart(parent, x, y, width, kdData, rawData)
    if not kdData then
        local container = createContainerWithTitle(parent, "Win Rate by Class", x, y, width, 45)
        return container, 45
    end

    local entries = {}
    for class, ratio in pairs(kdData) do
        table.insert(entries, {key = class, value = ratio})
    end
    table.sort(entries, function(a, b) return a.value > b.value end)

    if #entries == 0 then
        local container = createContainerWithTitle(parent, "Win Rate by Class", x, y, width, 45)
        return container, 45
    end

    local height = 30 + (#entries * (UI.BAR.HEIGHT + UI.BAR.SPACING)) + 15
    local container = createContainerWithTitle(parent, "Win Rate by Class", x, y, width, height)

    local maxValue = 1.0
    local nameWidth = UI.STANDARD_NAME_WIDTH
    local barX = 90
    local maxBarWidth = width - 190

    for i, entry in ipairs(entries) do
        local barWidth = maxValue > 0 and ((entry.value / maxValue) * maxBarWidth) or 0.5
        local barY = -(i * (UI.BAR.HEIGHT + UI.BAR.SPACING) + UI.TITLE_SPACING)
        local displayName = properCase(entry.key)
        local color = getClassColor(entry.key)
        local raw = rawData[entry.key] or {kills = 0, deaths = 0}

        local barButton = CreateFrame("Button", nil, container)
        barButton:SetSize(width, UI.BAR.HEIGHT)
        barButton:SetPoint("TOPLEFT", 0, barY)
        PSC_CreateGoldHighlight(barButton, UI.BAR.HEIGHT)

        barButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(displayName, color.r, color.g, color.b)
            GameTooltip:AddLine("Kills: " .. raw.kills, 1, 1, 1)
            GameTooltip:AddLine("Deaths: " .. raw.deaths, 1, 1, 1)
            if raw.deaths > 0 then
                GameTooltip:AddLine(string.format("K/D: %.2f", raw.kills / raw.deaths), 1, 1, 0.5)
            else
                GameTooltip:AddLine("K/D: -", 1, 1, 0.5)
            end
            GameTooltip:Show()
        end)
        barButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        local itemLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        itemLabel:SetPoint("TOPLEFT", 0, barY)
        itemLabel:SetText(displayName)
        itemLabel:SetWidth(nameWidth)
        itemLabel:SetJustifyH("LEFT")

        local bar = container:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("TOPLEFT", barX, barY)
        bar:SetSize(barWidth, UI.BAR.HEIGHT)
        bar:SetColorTexture(color.r, color.g, color.b, 0.9)

        local valueLabel = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        valueLabel:SetPoint("LEFT", bar, "RIGHT", UI.BAR.TEXT_OFFSET, 0)
        valueLabel:SetText(PSC_FormatPercent(entry.value * 100, 2))
    end

    return container, height
end

local function PSC_ExtractNameAndLevelKey(nameWithLevel)
    local colonIndex = string.find(nameWithLevel, ":", 1, true)
    if colonIndex then
        return string.sub(nameWithLevel, 1, colonIndex - 1), string.sub(nameWithLevel, colonIndex + 1)
    end

    return nameWithLevel, nil
end

local function PSC_GetMonthBucketFromTimestamp(timestamp)
    if not timestamp then
        return nil, nil
    end

    local dateInfo = date("*t", timestamp)
    if not dateInfo or not dateInfo.year or not dateInfo.month then
        return nil, nil
    end

    return (dateInfo.year * 100) + dateInfo.month, dateInfo
end

local function PSC_FormatMonthBucketLabel(bucket)
    local year = math.floor(bucket / 100)
    local month = bucket % 100
    local monthShort = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
    local monthName = monthShort[month] or tostring(month)
    return string.format("%s %02d", monthName, year % 100)
end

function PSC_CalculateMonthlyClassPercentageStatistics(charactersToProcess)
    local monthlyTotals = {}
    local monthlyClassKills = {}
    local monthKeys = {}

    for _, className in ipairs(ALL_CLASSES) do
        monthlyClassKills[className] = {}
    end

    if not PSC_DB.PlayerKillCounts.Characters then
        return monthKeys, monthlyClassKills, monthlyTotals
    end

    for _, characterData in pairs(charactersToProcess) do
        if characterData.Kills then
            for nameWithLevel, killData in pairs(characterData.Kills) do
                if killData.killLocations and #killData.killLocations > 0 then
                    local enemyName = PSC_ExtractNameAndLevelKey(nameWithLevel)
                    local infoKey = PSC_NormalizePlayerName(enemyName)
                    local info = PSC_DB.PlayerInfoCache[infoKey]
                    local className = info and info.class or nil

                    for _, location in ipairs(killData.killLocations) do
                        local bucket = PSC_GetMonthBucketFromTimestamp(location.timestamp)
                        if bucket then
                            if monthlyTotals[bucket] == nil then
                                monthlyTotals[bucket] = 0
                                table.insert(monthKeys, bucket)
                            end

                            monthlyTotals[bucket] = monthlyTotals[bucket] + 1

                            if className and monthlyClassKills[className] then
                                monthlyClassKills[className][bucket] = (monthlyClassKills[className][bucket] or 0) + 1
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(monthKeys)

    local monthlyClassPercentages = {}
    for _, className in ipairs(ALL_CLASSES) do
        monthlyClassPercentages[className] = {}
        for _, bucket in ipairs(monthKeys) do
            local total = monthlyTotals[bucket] or 0
            local classKills = monthlyClassKills[className][bucket] or 0
            if classKills > 0 and total > 0 then
                monthlyClassPercentages[className][bucket] = (classKills / total) * 100
            end
        end
    end

    return monthKeys, monthlyClassPercentages, monthlyTotals
end

local function createLineTexture(parent, x1, y1, x2, y2, color)
    local dx = x2 - x1
    local dy = y2 - y1
    local length = math.sqrt((dx * dx) + (dy * dy))
    if length <= 0 then
        return
    end

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(color.r, color.g, color.b, 0.95)
    line:SetSize(length, LINE_CHART_UI.LINE_THICKNESS)
    line:SetPoint("CENTER", parent, "TOPLEFT", x1 + (dx / 2), y1 + (dy / 2))

    local angle
    if math.atan2 then
        angle = math.atan2(dy, dx)
    elseif dx == 0 then
        angle = (dy >= 0) and (math.pi / 2) or (-math.pi / 2)
    else
        angle = math.atan(dy / dx)
        if dx < 0 then
            angle = angle + math.pi
        end
    end

    line:SetRotation(angle)
    return line
end

local function createPointTexture(parent, x, y, color)
    local point = parent:CreateTexture(nil, "OVERLAY")
    point:SetColorTexture(color.r, color.g, color.b, 1)
    point:SetSize(LINE_CHART_UI.POINT_SIZE, LINE_CHART_UI.POINT_SIZE)
    point:SetPoint("CENTER", parent, "TOPLEFT", x, y)
    return point
end

local function createMonthlyClassPercentageChart(parent, x, y, width, disableClicks, monthKeys, monthlyClassPercentages, monthlyTotals)
    local TBC_RELEASE_BUCKET = 202602
    local legendRows = math.ceil(#ALL_CLASSES / LINE_CHART_UI.LEGEND_COLUMNS)
    local legendHeight = legendRows * LINE_CHART_UI.LEGEND_ROW_HEIGHT
    local height = LINE_CHART_UI.HEIGHT + legendHeight
    local container = createContainerWithTitle(parent, "Monthly Class Kill Share (%)", x, y, width, height)

    local chartWidth = width - LINE_CHART_UI.LEFT_PADDING - LINE_CHART_UI.RIGHT_PADDING
    local chartHeight = LINE_CHART_UI.HEIGHT - LINE_CHART_UI.TOP_PADDING - LINE_CHART_UI.BOTTOM_PADDING
    local chartLeft = LINE_CHART_UI.LEFT_PADDING
    local chartTop = -LINE_CHART_UI.TOP_PADDING
    local chartBottom = chartTop - chartHeight
    local showHideAllButton = nil

    local monthCount = #monthKeys
    local classVisuals = {}

    local function ensureClassVisual(className)
        if not classVisuals[className] then
            classVisuals[className] = {
                visible = true,
                textures = {},
                buttons = {},
                legendSwatch = nil,
                legendText = nil
            }
        end
        return classVisuals[className]
    end

    local function registerClassTexture(className, texture)
        if not texture then
            return
        end
        local visuals = ensureClassVisual(className)
        table.insert(visuals.textures, texture)
    end

    local function registerClassButton(className, button)
        if not button then
            return
        end
        local visuals = ensureClassVisual(className)
        table.insert(visuals.buttons, button)
    end

    local function applyClassVisibility(className)
        local visuals = ensureClassVisual(className)
        local color = getClassColor(className)

        for _, texture in ipairs(visuals.textures) do
            if visuals.visible then
                texture:Show()
            else
                texture:Hide()
            end
        end

        for _, button in ipairs(visuals.buttons) do
            if visuals.visible then
                button:Show()
            else
                button:Hide()
            end
        end

        if visuals.legendSwatch then
            visuals.legendSwatch:SetAlpha(visuals.visible and 1 or 0.25)
        end

        if visuals.legendText then
            if visuals.visible then
                visuals.legendText:SetTextColor(color.r, color.g, color.b)
            else
                visuals.legendText:SetTextColor(0.55, 0.55, 0.55)
            end
        end
    end

    local function areAllClassesVisible()
        for _, className in ipairs(ALL_CLASSES) do
            if not ensureClassVisual(className).visible then
                return false
            end
        end
        return true
    end

    local function updateShowHideAllButtonText()
        if showHideAllButton then
            if areAllClassesVisible() then
                showHideAllButton:SetText("Hide all")
            else
                showHideAllButton:SetText("Show all")
            end
        end
    end

    local function setAllClassVisibility(visible)
        for _, className in ipairs(ALL_CLASSES) do
            local visuals = ensureClassVisual(className)
            visuals.visible = visible
            applyClassVisibility(className)
        end
        updateShowHideAllButtonText()
    end

    if monthCount == 0 then
        local emptyText = container:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        emptyText:SetPoint("TOPLEFT", 0, -40)
        emptyText:SetText("No timestamped kill data available for monthly class percentages.")
        return container, height
    end

    local maxPercent = 0
    for _, className in ipairs(ALL_CLASSES) do
        local classSeries = monthlyClassPercentages[className] or {}
        for _, monthBucket in ipairs(monthKeys) do
            local value = classSeries[monthBucket]
            if value and value > maxPercent then
                maxPercent = value
            end
        end
    end

    maxPercent = math.min(100, math.max(10, math.ceil(maxPercent / 10) * 10))

    local axisColor = {r = 0.6, g = 0.6, b = 0.6}
    local xAxis = container:CreateTexture(nil, "ARTWORK")
    xAxis:SetColorTexture(axisColor.r, axisColor.g, axisColor.b, 0.8)
    xAxis:SetPoint("TOPLEFT", chartLeft, chartBottom)
    xAxis:SetSize(chartWidth, 1)

    local yAxis = container:CreateTexture(nil, "ARTWORK")
    yAxis:SetColorTexture(axisColor.r, axisColor.g, axisColor.b, 0.8)
    yAxis:SetPoint("TOPLEFT", chartLeft, chartTop)
    yAxis:SetSize(1, chartHeight)

    for i = 0, LINE_CHART_UI.GRID_LINES do
        local ratio = i / LINE_CHART_UI.GRID_LINES
        local percent = maxPercent * ratio
        local yPos = chartBottom + (chartHeight * ratio)

        local gridLine = container:CreateTexture(nil, "BACKGROUND")
        gridLine:SetColorTexture(0.35, 0.35, 0.35, 0.35)
        gridLine:SetPoint("TOPLEFT", chartLeft, yPos)
        gridLine:SetSize(chartWidth, 1)

        local yLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        yLabel:SetPoint("RIGHT", container, "TOPLEFT", chartLeft - 8, yPos)
        yLabel:SetText(PSC_FormatPercent(percent, 1))
    end

    local xStep = (monthCount > 1) and (chartWidth / (monthCount - 1)) or 0
    local labelStep = 1
    if monthCount > 8 then
        labelStep = math.ceil(monthCount / 8)
    end

    local function getPointPosition(monthIndex, percent)
        local xPos = chartLeft + ((monthIndex - 1) * xStep)
        local yPos = chartBottom + ((percent / maxPercent) * chartHeight)
        return xPos, yPos
    end

    for i, monthBucket in ipairs(monthKeys) do
        local xPos = chartLeft + ((i - 1) * xStep)

        if i == 1 or i == monthCount or (i - 1) % labelStep == 0 then
            local xLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            xLabel:SetPoint("TOP", container, "TOPLEFT", xPos, chartBottom - 6)
            xLabel:SetText(PSC_FormatMonthBucketLabel(monthBucket))
        end
    end

    if TBC_RELEASE_BUCKET >= monthKeys[1] and TBC_RELEASE_BUCKET <= monthKeys[monthCount] then
        local releaseX = nil
        for idx, bucket in ipairs(monthKeys) do
            if bucket == TBC_RELEASE_BUCKET then
                releaseX = chartLeft + ((idx - 1) * xStep)
                break
            elseif bucket > TBC_RELEASE_BUCKET then
                if idx > 1 then
                    releaseX = chartLeft + (((idx - 2) + 0.5) * xStep)
                else
                    releaseX = chartLeft
                end
                break
            end
        end

        if not releaseX then
            releaseX = chartLeft + ((monthCount - 1) * xStep)
        end

        local releaseLine = container:CreateTexture(nil, "OVERLAY")
        releaseLine:SetColorTexture(1.0, 0.82, 0.0, 0.95)
        releaseLine:SetPoint("TOPLEFT", releaseX, chartTop)
        releaseLine:SetSize(1, chartHeight)

        local releaseLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        releaseLabel:SetPoint("BOTTOM", container, "TOPLEFT", releaseX, chartTop + 2)
        releaseLabel:SetText("TBC")
        releaseLabel:SetTextColor(1.0, 0.82, 0.0)

        local releaseButton = CreateFrame("Button", nil, container)
        releaseButton:SetPoint("TOPLEFT", releaseX - 3, chartTop)
        releaseButton:SetSize(7, chartHeight)
        releaseButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Burning Crusade Release", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("February 6, 2026", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        releaseButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    for _, className in ipairs(ALL_CLASSES) do
        local series = monthlyClassPercentages[className] or {}
        local color = getClassColor(className)
        local previousX = nil
        local previousY = nil

        for i, monthBucket in ipairs(monthKeys) do
            local value = series[monthBucket]
            if value and value > 0 then
                local pointX, pointY = getPointPosition(i, value)
                local point = createPointTexture(container, pointX, pointY, color)
                registerClassTexture(className, point)

                if previousX and previousY then
                    local line = createLineTexture(container, previousX, previousY, pointX, pointY, color)
                    registerClassTexture(className, line)
                end

                if not disableClicks then
                    local pointButton = CreateFrame("Button", nil, container)
                    pointButton:SetSize(10, 10)
                    pointButton:SetPoint("CENTER", container, "TOPLEFT", pointX, pointY)
                    pointButton:SetScript("OnEnter", function(self)
                        local totalMonthKills = monthlyTotals[monthBucket] or 0
                        local classMonthKills = math.floor((value / 100) * totalMonthKills + 0.5)
                        local previousMonthBucket = monthKeys[i - 1]
                        local previousValue = previousMonthBucket and (series[previousMonthBucket] or 0) or nil
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(className, color.r, color.g, color.b)
                        GameTooltip:AddLine(PSC_FormatMonthBucketLabel(monthBucket), 1, 1, 1)
                        GameTooltip:AddLine("Share: " .. PSC_FormatPercent(value, 2), 1, 1, 1)
                        GameTooltip:AddLine("Kills: " .. classMonthKills .. " / " .. totalMonthKills, 1, 1, 1)

                        if previousValue ~= nil then
                            local delta = value - previousValue
                            local deltaAbs = math.abs(delta)
                            local deltaText = PSC_FormatPercent(deltaAbs, 2)
                            if delta > 0 then
                                GameTooltip:AddLine(string.format("Delta vs %s: %s increase", PSC_FormatMonthBucketLabel(previousMonthBucket), deltaText), 0.3, 1, 0.3, true)
                            elseif delta < 0 then
                                GameTooltip:AddLine(string.format("Delta vs %s: %s decrease", PSC_FormatMonthBucketLabel(previousMonthBucket), deltaText), 1, 0.3, 0.3, true)
                            else
                                GameTooltip:AddLine(string.format("Delta vs %s: no change", PSC_FormatMonthBucketLabel(previousMonthBucket)), 0.85, 0.85, 0.85, true)
                            end
                        else
                            GameTooltip:AddLine("Delta vs previous month: n/a", 0.85, 0.85, 0.85, true)
                        end

                        GameTooltip:Show()
                    end)
                    pointButton:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)
                    registerClassButton(className, pointButton)
                end

                previousX = pointX
                previousY = pointY
            end
        end
    end

    local legendStartY = -(LINE_CHART_UI.HEIGHT - 8)
    local legendLeft = 6
    local legendItemWidth = LINE_CHART_UI.LEGEND_ITEM_WIDTH
    local legendColumnSpacing = LINE_CHART_UI.LEGEND_COLUMN_SPACING

    for classIndex, className in ipairs(ALL_CLASSES) do
        local zeroBased = classIndex - 1
        local legendColumn = zeroBased % LINE_CHART_UI.LEGEND_COLUMNS
        local legendRow = math.floor(zeroBased / LINE_CHART_UI.LEGEND_COLUMNS)
        local itemX = legendLeft + (legendColumn * (legendItemWidth + legendColumnSpacing))
        local itemY = legendStartY - (legendRow * LINE_CHART_UI.LEGEND_ROW_HEIGHT)
        local color = getClassColor(className)

        local swatch = container:CreateTexture(nil, "ARTWORK")
        swatch:SetColorTexture(color.r, color.g, color.b, 1)
        swatch:SetSize(10, 10)
        swatch:SetPoint("TOPLEFT", itemX, itemY)

        local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", swatch, "RIGHT", 4, 0)
        text:SetText(className)

        local legendButton = CreateFrame("Button", nil, container)
        legendButton:SetPoint("TOPLEFT", swatch, "TOPLEFT", -2, 1)
        legendButton:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", 2, -1)
        PSC_CreateGoldHighlight(legendButton, 12)

        legendButton:SetScript("OnClick", function()
            local visuals = ensureClassVisual(className)
            visuals.visible = not visuals.visible
            applyClassVisibility(className)
            updateShowHideAllButtonText()
        end)

        legendButton:SetScript("OnEnter", function(self)
            local visuals = ensureClassVisual(className)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(className, color.r, color.g, color.b)
            if visuals.visible then
                GameTooltip:AddLine("Click to hide this class graph", 1, 1, 1, true)
            else
                GameTooltip:AddLine("Click to show this class graph", 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)

        legendButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        local visuals = ensureClassVisual(className)
        visuals.legendSwatch = swatch
        visuals.legendText = text
        applyClassVisibility(className)
    end

    showHideAllButton = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    showHideAllButton:SetSize(78, 14)
    showHideAllButton:SetPoint(
        "TOPLEFT",
        legendLeft + (LINE_CHART_UI.LEGEND_COLUMNS * (legendItemWidth + legendColumnSpacing)) + 2,
        legendStartY
    )
    showHideAllButton:SetScript("OnClick", function()
        setAllClassVisibility(not areAllClassesVisible())
    end)
    showHideAllButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if areAllClassesVisible() then
            GameTooltip:AddLine("Hide all class graphs", 1, 1, 1, true)
        else
            GameTooltip:AddLine("Show all class graphs", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    showHideAllButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    updateShowHideAllButtonText()

    return container, height
end

local function createGuildTableRow(content, entry, index, firstRowSpacing)
    if not entry then
        return
    end

    local rowY = index == 1 and -firstRowSpacing or -(firstRowSpacing + ((index - 1) * 20))

    local guildName = entry.key or "Unknown"
    local killCount = entry.value or 0

    local guildText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    guildText:SetPoint("TOPLEFT", 0, rowY)
    guildText:SetText(tostring(guildName))
    guildText:SetWidth(200)
    guildText:SetJustifyH("LEFT")

    local killsText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    killsText:SetPoint("TOPLEFT", 200 + 10, rowY)
    killsText:SetText(tostring(killCount))
    killsText:SetJustifyH("LEFT")

    -- Create the button with proper height to not overlap the next row
    local rowButton = CreateFrame("Button", nil, content)
    rowButton:SetPoint("TOPLEFT", guildText, "TOPLEFT", 0, 0)
    rowButton:SetPoint("BOTTOMRIGHT", killsText, "BOTTOMRIGHT", 10, 0) -- Remove the -15 offset

    -- Use a smaller height value for the highlight (16 matches the font height better)
    local highlightTexture = PSC_CreateGoldHighlight(rowButton, 16)

    rowButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(guildName)
        GameTooltip:AddLine("Click to show all kills for this guild", 1, 1, 1, true)
        GameTooltip:Show()
    end)

    rowButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    rowButton:SetScript("OnClick", function()
        PSC_CreateKillsListFrame()

        if PSC_KillsListFrame then
            ---@diagnostic disable-next-line: need-check-nil, undefined-field
            PSC_KillsListFrame:SetFrameLevel(statisticsFrame:GetFrameLevel() + 10)
        end

        PSC_SetKillListSearch(guildName, nil, nil, nil, nil, nil, true)
    end)
end

local function createScrollFrame(container, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -20)
    scrollFrame:SetSize(width + 5, height - 21)

    local scrollBarName = scrollFrame:GetName() and scrollFrame:GetName() .. "ScrollBar" or nil
    local scrollBar = scrollBarName and _G[scrollBarName] or nil

    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, -16)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, 16)
    end

    return scrollFrame
end

function PSC_CalculateGuildKills(charactersToProcess)
    local guildKills = {}
    local scope = charactersToProcess or PSC_GetCharactersToProcessForStatistics()

    for _, characterData in pairs(scope) do
        if characterData.Kills then
            for nameWithLevel, killData in pairs(characterData.Kills) do
                local playerNameWithoutLevel = nameWithLevel:match("([^:]+)")
                local kills = killData.kills or 0
                local infoKey = PSC_NormalizePlayerName(playerNameWithoutLevel)
                if PSC_DB.PlayerInfoCache[infoKey] then
                    local guild = PSC_DB.PlayerInfoCache[infoKey].guild
                    if guild ~= "" then
                        guildKills[guild] = (guildKills[guild] or 0) + kills
                    end
                end
            end
        end
    end

    return guildKills
end

local function PSC_SummaryStats_CreateState(charactersToProcess)
    local PSC_DB = PSC_DB
---@diagnostic disable-next-line: undefined-global
    local PSC_CalculateTimePeriodBoundaries = PSC_CalculateTimePeriodBoundaries

    local state = {
        totalKills = 0,
        uniqueKills = 0,
        totalLevels = 0,
        totalPlayerLevelSum = 0,
        killsWithLevelData = 0,
        levelDiffSum = 0,
        unknownLevelKills = 0,
        uniquePlayerLevels = {},
        killsPerPlayer = {},
        mostKilledPlayer = nil,
        mostKilledCount = 0,
        highestKillStreak = 0,
        highestKillStreakCharacter = "",
        currentKillStreak = 0,
        highestMultiKill = 0,
        highestMultiKillCharacter = "",
        doubleKills = 0,
        tripleKills = 0,
        quadraKills = 0,
        pentaKills = 0,
        hexaPlusKills = 0,
        weekdayKills = {0, 0, 0, 0, 0, 0, 0},
        hourlyKills = {},
        monthlyKills = {},
        firstKillTimestamp = nil,
        lastKillTimestamp = nil,
        timeBoundaries = nil,
        killsToday = 0,
        killsThisWeek = 0,
        killsThisMonth = 0,
        killsThisYear = 0,
        busiestWeekday = "None",
        busiestWeekdayKills = 0,
        busiestHour = "None",
        busiestHourKills = 0,
        busiestMonth = "None",
        busiestMonthKills = 0,
        mostKillsInDay = 0,
        mostKillsInWeek = 0,
        mostKillsInDayDate = nil,
        mostKillsInWeekDate = nil,
        dailyKills = {},
        weeklyKills = {},
        weeklyKillDates = {},
        avgKillsPerDay = 0,
        nemesisName = "None",
        nemesisScore = 0,
        totalDeaths = 0,
        kdRatio = 0,
        charactersToProcess = charactersToProcess
    }

    for i = 0, 23 do
        state.hourlyKills[i] = 0
    end
    for i = 1, 12 do
        state.monthlyKills[i] = 0
    end

    state.timeBoundaries = PSC_CalculateTimePeriodBoundaries()

    return state
end

local function PSC_SummaryStats_GetDayNumber(year, month, day)
    if month <= 2 then
        year = year - 1
        month = month + 12
    end

    local era = math.floor(year / 400)
    local yearOfEra = year - era * 400
    local dayOfYear = math.floor((153 * (month - 3) + 2) / 5) + day - 1
    local dayOfEra = yearOfEra * 365 + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100) + dayOfYear
    return era * 146097 + dayOfEra
end

local function PSC_SummaryStats_ProcessCharacterHeader(state, characterKey, characterData)
    local PSC_GetCharacterKey = PSC_GetCharacterKey
    local PSC_DB = PSC_DB
    local multiKillCounts = characterData.MultiKillCounts or {}

    state.doubleKills = state.doubleKills + (multiKillCounts[2] or 0)
    state.tripleKills = state.tripleKills + (multiKillCounts[3] or 0)
    state.quadraKills = state.quadraKills + (multiKillCounts[4] or 0)
    state.pentaKills = state.pentaKills + (multiKillCounts[5] or 0)
    state.hexaPlusKills = state.hexaPlusKills + (multiKillCounts[6] or 0)

    if characterKey == PSC_GetCharacterKey() then
        state.currentKillStreak = characterData.CurrentKillStreak
    end

    if PSC_DB.ShowAccountWideStats then
        if (characterData.HighestKillStreak or 0) > state.highestKillStreak then
            state.highestKillStreak = characterData.HighestKillStreak or 0
            state.highestKillStreakCharacter = characterKey
        end

        if (characterData.HighestMultiKill or 0) > state.highestMultiKill then
            state.highestMultiKill = characterData.HighestMultiKill or 0
            state.highestMultiKillCharacter = characterKey
        end
    else
        state.highestMultiKill = characterData.HighestMultiKill or 0
        state.highestKillStreak = characterData.HighestKillStreak or 0
    end
end

local function PSC_SummaryStats_ProcessKillEntryBase(state, nameWithLevel, killData)
    local tonumber = tonumber
    local strfind = string.find
    local strsub = string.sub

    local kills = killData.kills or 0

    local colonIndex = strfind(nameWithLevel, ":", 1, true)
    local playerName
    local levelPart
    if colonIndex then
        playerName = strsub(nameWithLevel, 1, colonIndex - 1)
        levelPart = strsub(nameWithLevel, colonIndex + 1)
    else
        playerName = nameWithLevel
        levelPart = nil
    end

    playerName = PSC_NormalizePlayerName(playerName)

    if not state.killsPerPlayer[playerName] then
        state.uniqueKills = state.uniqueKills + 1
        state.killsPerPlayer[playerName] = kills
    else
        state.killsPerPlayer[playerName] = state.killsPerPlayer[playerName] + kills
    end

    state.totalKills = state.totalKills + kills

    local levelNum = tonumber(levelPart or "0") or 0

    if levelNum > 0 then
        if not state.uniquePlayerLevels[playerName] then
            state.uniquePlayerLevels[playerName] = {
                sum = 0,
                count = 0
            }
        end

        state.uniquePlayerLevels[playerName].sum = state.uniquePlayerLevels[playerName].sum + levelNum
        state.uniquePlayerLevels[playerName].count = state.uniquePlayerLevels[playerName].count + 1
    end

    if levelNum == -1 then
        state.unknownLevelKills = state.unknownLevelKills + kills
    end

    if levelNum > 0 then
        state.totalLevels = state.totalLevels + levelNum * kills
    end

    return kills, playerName, levelNum
end

local function PSC_SummaryStats_ProcessKillLocation(state, location, levelNum)
    local tonumber = tonumber
    local date = date

    local targetLevel = levelNum
    local playerLevel = location.playerLevel or 0
    local timestamp = location.timestamp

    if timestamp then
        if not state.firstKillTimestamp or timestamp < state.firstKillTimestamp then
            state.firstKillTimestamp = timestamp
        end
        if not state.lastKillTimestamp or timestamp > state.lastKillTimestamp then
            state.lastKillTimestamp = timestamp
        end

        if state.timeBoundaries then
            if timestamp >= state.timeBoundaries.todayStart then
                state.killsToday = state.killsToday + 1
            end
            if timestamp >= state.timeBoundaries.weekStart then
                state.killsThisWeek = state.killsThisWeek + 1
            end
            if timestamp >= state.timeBoundaries.monthStart then
                state.killsThisMonth = state.killsThisMonth + 1
            end
            if timestamp >= state.timeBoundaries.yearStart then
                state.killsThisYear = state.killsThisYear + 1
            end
        end

        local wday0 = tonumber(date("%w", timestamp))
        if wday0 then
            state.weekdayKills[wday0 + 1] = state.weekdayKills[wday0 + 1] + 1
        end

        local hour = tonumber(date("%H", timestamp))
        if hour then
            state.hourlyKills[hour] = state.hourlyKills[hour] + 1
        end

        local month = tonumber(date("%m", timestamp))
        if month then
            state.monthlyKills[month] = state.monthlyKills[month] + 1
        end

        local dateInfo = date("*t", timestamp)
        if dateInfo then
            local dayKey = date("%d/%m/%y", timestamp)
            state.dailyKills[dayKey] = (state.dailyKills[dayKey] or 0) + 1

            -- Wednesday is the start of the WoW statistics week.
            local dayNumber = PSC_SummaryStats_GetDayNumber(dateInfo.year, dateInfo.month, dateInfo.day)
            local daysFromWednesday = (dateInfo.wday + 3) % 7
            local weekKey = dayNumber - daysFromWednesday
            state.weeklyKills[weekKey] = (state.weeklyKills[weekKey] or 0) + 1
            if not state.weeklyKillDates[weekKey] then
                state.weeklyKillDates[weekKey] = date("%d/%m/%y", timestamp - (daysFromWednesday * 86400))
            end
        end
    end

    if targetLevel > 0 and playerLevel > 0 then
        state.levelDiffSum = state.levelDiffSum + (playerLevel - targetLevel)
        state.killsWithLevelData = state.killsWithLevelData + 1
    end

    if playerLevel > 0 then
        state.totalPlayerLevelSum = state.totalPlayerLevelSum + playerLevel
    end
end

local function PSC_SummaryStats_ProcessKillEntryFallback(state, killData, kills, levelNum)
    if levelNum > 0 and killData.playerLevel and killData.playerLevel > 0 then
        state.levelDiffSum = state.levelDiffSum + (killData.playerLevel - levelNum) * kills
        state.killsWithLevelData = state.killsWithLevelData + kills
    end

    if killData.playerLevel and killData.playerLevel > 0 then
        state.totalPlayerLevelSum = state.totalPlayerLevelSum + killData.playerLevel * kills
    end
end

local function PSC_SummaryStats_FinalizeKillDerivedFields(state)
    local pairs = pairs
    local ipairs = ipairs
    local math_floor = math.floor
    local string_format = string.format

    for playerName, kills in pairs(state.killsPerPlayer) do
        if kills > state.mostKilledCount then
            state.mostKilledPlayer = playerName
            state.mostKilledCount = kills
        end
    end

    local uniqueLevelSum = 0
    local uniquePlayersWithLevel = 0

    for _, playerLevelData in pairs(state.uniquePlayerLevels) do
        if playerLevelData.count > 0 then
            uniqueLevelSum = uniqueLevelSum + (playerLevelData.sum / playerLevelData.count)
            uniquePlayersWithLevel = uniquePlayersWithLevel + 1
        end
    end

    local weekdayNames = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
    state.busiestWeekday = "None"
    state.busiestWeekdayKills = 0
    for i, kills in ipairs(state.weekdayKills) do
        if kills > state.busiestWeekdayKills then
            state.busiestWeekdayKills = kills
            state.busiestWeekday = weekdayNames[i]
        end
    end

    state.busiestHour = "None"
    state.busiestHourKills = 0
    for hour, kills in pairs(state.hourlyKills) do
        if kills > state.busiestHourKills then
            state.busiestHourKills = kills
            state.busiestHour = string_format("%02d:00 - %02d:00", hour, (hour + 1) % 24)
        end
    end

    local monthNames = {"January", "February", "March", "April", "May", "June",
                       "July", "August", "September", "October", "November", "December"}
    state.busiestMonth = "None"
    state.busiestMonthKills = 0
    for i, kills in ipairs(state.monthlyKills) do
        if kills > state.busiestMonthKills then
            state.busiestMonthKills = kills
            state.busiestMonth = monthNames[i]
        end
    end

    state.mostKillsInDay = 0
    for _, kills in pairs(state.dailyKills) do
        if kills > state.mostKillsInDay then
            state.mostKillsInDay = kills
        end
    end

    for day, kills in pairs(state.dailyKills) do
        if kills == state.mostKillsInDay then
            state.mostKillsInDayDate = day
            break
        end
    end

    state.mostKillsInWeek = 0
    for weekKey, kills in pairs(state.weeklyKills) do
        if kills > state.mostKillsInWeek then
            state.mostKillsInWeek = kills
            state.mostKillsInWeekDate = state.weeklyKillDates[weekKey]
        end
    end

    state.avgKillsPerDay = 0
    if state.firstKillTimestamp and state.lastKillTimestamp then
        local activitySpanDays = math_floor((state.lastKillTimestamp - state.firstKillTimestamp) / 86400) + 1
        if activitySpanDays > 0 then
            state.avgKillsPerDay = state.totalKills / activitySpanDays
        end
    end

    local knownLevelKills = state.totalKills - state.unknownLevelKills
    local avgUniqueLevel = uniquePlayersWithLevel > 0 and (uniqueLevelSum / uniquePlayersWithLevel) or 0
    state.avgLevel = avgUniqueLevel
    state.avgPlayerLevel = state.totalKills > 0 and (state.totalPlayerLevelSum / state.totalKills) or 0
    state.avgLevelDiff = state.killsWithLevelData > 0 and (state.levelDiffSum / state.killsWithLevelData) or 0
    state.avgKillsPerPlayer = state.uniqueKills > 0 and (state.totalKills / state.uniqueKills) or 0

    if knownLevelKills <= 0 then
        state._unusedAvgLevel = 0
    else
        state._unusedAvgLevel = state.totalLevels / knownLevelKills
    end
end

local function PSC_SummaryStats_FinalizeNemesisAndDeaths(state, characterScope)
    local pairs = pairs
    local ipairs = ipairs
    local math_huge = math.huge
    local PSC_GetDeathDataFromAllCharacters = PSC_GetDeathDataFromAllCharacters

    local nemesisName = "None"
    local nemesisScore = 0
    local nemesisAssists = 0
    local deathDataByPlayer = PSC_GetDeathDataFromAllCharacters(characterScope)

    local assistsByPlayer = {}
    local deathsByPlayer = {}

    for killerName, deathData in pairs(deathDataByPlayer) do
        local normalizedKiller = PSC_NormalizePlayerName(killerName)
        deathsByPlayer[normalizedKiller] = (deathsByPlayer[normalizedKiller] or 0) + (deathData.deaths or 0)

        if deathData.deathLocations then
            for _, location in ipairs(deathData.deathLocations) do
                if location.assisters then
                    for _, assister in ipairs(location.assisters) do
                        if assister and assister.name then
                            local normalizedAssister = PSC_NormalizePlayerName(assister.name)
                            assistsByPlayer[normalizedAssister] = (assistsByPlayer[normalizedAssister] or 0) + 1
                        end
                    end
                end
            end
        end
    end

    local totalDeaths = 0
    for _, deaths in pairs(deathsByPlayer) do
        totalDeaths = totalDeaths + (deaths or 0)
    end

    for killerName, deaths in pairs(deathsByPlayer) do
        local assists = assistsByPlayer[killerName] or 0

        if deaths > nemesisScore or (deaths == nemesisScore and assists > nemesisAssists) then
            nemesisScore = deaths
            nemesisAssists = assists
            nemesisName = killerName
        end
    end

    state.nemesisName = nemesisName
    state.nemesisScore = nemesisScore
    state.totalDeaths = totalDeaths

    if totalDeaths > 0 then
        state.kdRatio = state.totalKills / totalDeaths
    elseif state.totalKills > 0 then
        state.kdRatio = math_huge
    else
        state.kdRatio = 0
    end
end

local function PSC_SummaryStats_BuildResult(state)
    return {
        totalKills = state.totalKills,
        uniqueKills = state.uniqueKills,
        unknownLevelKills = state.unknownLevelKills,
        totalDeaths = state.totalDeaths,
        kdRatio = state.kdRatio,
        avgLevel = state.avgLevel,
        avgLevelDiff = state.avgLevelDiff,
        avgKillsPerPlayer = state.avgKillsPerPlayer,
        mostKilledPlayer = state.mostKilledPlayer or "None",
        mostKilledCount = state.mostKilledCount,
        currentKillStreak = state.currentKillStreak,
        highestKillStreak = state.highestKillStreak,
        highestMultiKill = state.highestMultiKill,
        highestKillStreakCharacter = state.highestKillStreakCharacter,
        highestMultiKillCharacter = state.highestMultiKillCharacter,
        doubleKills = state.doubleKills,
        tripleKills = state.tripleKills,
        quadraKills = state.quadraKills,
        pentaKills = state.pentaKills,
        hexaPlusKills = state.hexaPlusKills,
        busiestWeekday = state.busiestWeekday,
        busiestWeekdayKills = state.busiestWeekdayKills,
        busiestHour = state.busiestHour,
        busiestHourKills = state.busiestHourKills,
        busiestMonth = state.busiestMonth,
        busiestMonthKills = state.busiestMonthKills,
        mostKillsInDay = state.mostKillsInDay,
        mostKillsInWeek = state.mostKillsInWeek,
        mostKillsInDayDate = state.mostKillsInDayDate,
        mostKillsInWeekDate = state.mostKillsInWeekDate,
        avgKillsPerDay = state.avgKillsPerDay,
        killsToday = state.killsToday,
        killsThisWeek = state.killsThisWeek,
        killsThisMonth = state.killsThisMonth,
        killsThisYear = state.killsThisYear,
        nemesisName = state.nemesisName,
        nemesisScore = state.nemesisScore
    }
end

function PSC_CalculateDeathsByClass(characterScope)
    local deathsByClass = {}

    for _, class in ipairs(ALL_CLASSES) do
        deathsByClass[class] = 0
    end

    local deathDataByPlayer = PSC_GetDeathDataFromAllCharacters(characterScope)

    for killerName, deathData in pairs(deathDataByPlayer) do
        local infoKey = PSC_NormalizePlayerName(killerName)
        local info = PSC_DB.PlayerInfoCache[infoKey]
        if info and info.class then
            deathsByClass[info.class] = (deathsByClass[info.class] or 0) + (deathData.deaths or 0)
        end
    end

    return deathsByClass
end

local function PSC_CalculateWinRateByClass(killsByClass, deathsByClass)
    local winRateData = {}
    local rawData = {}

    for _, class in ipairs(ALL_CLASSES) do
        local kills = killsByClass[class] or 0
        local deaths = deathsByClass[class] or 0
        local total = kills + deaths
        if total > 0 then
            winRateData[class] = kills / total
            rawData[class] = {kills = kills, deaths = deaths}
        end
    end

    return winRateData, rawData
end

local function createGuildTable(parent, x, y, width, height, precomputedGuildData)
    local container = createContainerWithTitle(parent, "Kills by Guild", x, y, width, height)

    local guildKills = precomputedGuildData or PSC_CalculateGuildKills()
    local sortedGuilds = sortByValue(guildKills, true)
    if #sortedGuilds > 50 then
        local trimmed = {}
        for i = 1, 50 do trimmed[i] = sortedGuilds[i] end
        sortedGuilds = trimmed
    end

    local totalContentWidth = 240
    local scrollFrame = createScrollFrame(container, totalContentWidth, height)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(totalContentWidth, math.max(#sortedGuilds * 20 + 10, 10))
    scrollFrame:SetScrollChild(content)

    local firstRowSpacing = 0

    for i, entry in ipairs(sortedGuilds) do
        createGuildTableRow(content, entry, i, firstRowSpacing)
    end

    return container
end

local function addSummaryStatLine(container, label, value, yPosition, tooltipText, isKillStreak, isLocalPlayer, valueColor)
    local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 0, yPosition)
    labelText:SetText(label)

    local valueText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("TOPLEFT", 150, yPosition)
    valueText:SetText(tostring(value))

    if isKillStreak then
        valueText:SetTextColor(1.0, 0.82, 0.0)
    elseif valueColor then
        valueText:SetTextColor(valueColor.r, valueColor.g, valueColor.b)
    end

    if tooltipText then
        local tooltipFrame = CreateFrame("Frame", nil, container)
        tooltipFrame:SetPoint("TOPLEFT", labelText, "TOPLEFT", 0, 0)
        tooltipFrame:SetPoint("BOTTOMRIGHT", valueText, "BOTTOMRIGHT", 0, 0)

        tooltipFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            local text = tooltipText
            local r, g, b = 1, 1, 1

            if type(tooltipText) == "table" then
                text = tooltipText.text or ""
                if tooltipText.color then
                    r = tooltipText.color.r or r
                    g = tooltipText.color.g or g
                    b = tooltipText.color.b or b
                end
            end

            GameTooltip:AddLine(text, r, g, b, true)
            GameTooltip:Show()
        end)

        tooltipFrame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        if label == "Most killed player:" and isLocalPlayer then
            local button = CreateFrame("Button", nil, tooltipFrame)
            ---@diagnostic disable-next-line: param-type-mismatch
            button:SetAllPoints(true)

            PSC_CreateGoldHighlight(button, 20)

            button:SetScript("OnMouseUp", function()
                if value ~= "None (0)" then
                    local playerName = value:match("([^%(]+)"):trim()
                    PSC_CreateKillsListFrame()
                    C_Timer.After(0.05, function()
                        PSC_SetKillListSearch(playerName, nil, nil, nil, nil, nil, true)
                        PSC_FrameManager:BringToFront("KillsList")
                    end)
                end
            end)
        elseif label == "Nemesis:" and isLocalPlayer then
            local button = CreateFrame("Button", nil, tooltipFrame)
            ---@diagnostic disable-next-line: param-type-mismatch
            button:SetAllPoints(true)

            PSC_CreateGoldHighlight(button, 20)

            button:SetScript("OnMouseUp", function()
                if value ~= "None (0)" then
                    local playerName = value:match("([^%(]+)"):trim()
                    PSC_CreateKillsListFrame()
                    C_Timer.After(0.05, function()
                        PSC_SetKillListSearch(playerName, nil, nil, nil, nil, nil, true)
                        PSC_FrameManager:BringToFront("KillsList")
                    end)
                end
            end)
        elseif isKillStreak and isLocalPlayer then
            local button = CreateFrame("Button", nil, tooltipFrame)
            ---@diagnostic disable-next-line: param-type-mismatch
            button:SetAllPoints(true)

            PSC_CreateGoldHighlight(button, 20)

            button:SetScript("OnMouseUp", function()
                PSC_CreateKillStreakPopup()
            end)

            -- Add tooltip to the button itself
            button:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
                GameTooltip:Show()
            end)

            button:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
        end
    end

    return yPosition - 20
end

function PSC_CalculateSummaryStatistics(charactersToProcess)
    local state = PSC_SummaryStats_CreateState(charactersToProcess)

    for characterKey, characterData in pairs(charactersToProcess) do
        PSC_SummaryStats_ProcessCharacterHeader(state, characterKey, characterData)

        if characterData.Kills then
            for nameWithLevel, killData in pairs(characterData.Kills) do
                local kills, _, levelNum = PSC_SummaryStats_ProcessKillEntryBase(state, nameWithLevel, killData)

                if killData.killLocations and #killData.killLocations > 0 then
                    for _, location in ipairs(killData.killLocations) do
                        PSC_SummaryStats_ProcessKillLocation(state, location, levelNum)
                    end
                else
                    PSC_SummaryStats_ProcessKillEntryFallback(state, killData, kills, levelNum)
                end
            end
        end
    end

    PSC_SummaryStats_FinalizeKillDerivedFields(state)
    PSC_SummaryStats_FinalizeNemesisAndDeaths(state, charactersToProcess)
    return PSC_SummaryStats_BuildResult(state)
end

function PSC_CreateIncrementalSummaryStatisticsTask(charactersToProcess, maxKillLocationsPerFrame, onComplete)
    if type(onComplete) ~= "function" then
        return function()
            return true
        end
    end

    local sliceBudget = tonumber(maxKillLocationsPerFrame) or 0
    sliceBudget = math.floor(sliceBudget)
    if sliceBudget < 50 then
        sliceBudget = 50
    end

    local state = PSC_SummaryStats_CreateState(charactersToProcess)

    local characterKeys = {}
    for characterKey in pairs(charactersToProcess) do
        table.insert(characterKeys, characterKey)
    end

    local characterIndex = 1
    local killKeys = nil
    local killIndex = 1
    local locationIndex = 1
    local currentKillData = nil
    local currentKillLevelNum = 0
    local currentKillKills = 0
    local characterHeaderDone = false
    local finished = false

    local function advanceToNextKill()
        currentKillData = nil
        locationIndex = 1
        killIndex = killIndex + 1
    end

    return function()
        if finished then
            return true
        end

        local processed = 0
        while processed < sliceBudget do
            if characterIndex > #characterKeys then
                PSC_SummaryStats_FinalizeKillDerivedFields(state)
                PSC_SummaryStats_FinalizeNemesisAndDeaths(state, charactersToProcess)
                finished = true
                onComplete(PSC_SummaryStats_BuildResult(state))
                return true
            end

            local characterKey = characterKeys[characterIndex]
            local characterData = charactersToProcess[characterKey]
            if not characterData then
                characterIndex = characterIndex + 1
                killKeys = nil
                killIndex = 1
                locationIndex = 1
                currentKillData = nil
                characterHeaderDone = false
            else
                if not characterHeaderDone then
                    PSC_SummaryStats_ProcessCharacterHeader(state, characterKey, characterData)
                    characterHeaderDone = true
                end

                if not characterData.Kills then
                    characterIndex = characterIndex + 1
                    killKeys = nil
                    killIndex = 1
                    locationIndex = 1
                    currentKillData = nil
                    characterHeaderDone = false
                else
                    if not killKeys then
                        killKeys = {}
                        for nameWithLevel in pairs(characterData.Kills) do
                            table.insert(killKeys, nameWithLevel)
                        end
                        killIndex = 1
                        locationIndex = 1
                        currentKillData = nil
                    end

                    if killIndex > #killKeys then
                        characterIndex = characterIndex + 1
                        killKeys = nil
                        killIndex = 1
                        locationIndex = 1
                        currentKillData = nil
                        characterHeaderDone = false
                    else
                        local nameWithLevel = killKeys[killIndex]
                        local killData = characterData.Kills[nameWithLevel]
                        if not killData then
                            advanceToNextKill()
                        else
                            if not currentKillData then
                                currentKillData = killData
                                local kills, _, levelNum = PSC_SummaryStats_ProcessKillEntryBase(state, nameWithLevel, killData)
                                currentKillLevelNum = levelNum
                                currentKillKills = kills
                                locationIndex = 1
                            end

                            if currentKillData.killLocations and #currentKillData.killLocations > 0 then
                                local locations = currentKillData.killLocations
                                if locationIndex > #locations then
                                    advanceToNextKill()
                                else
                                    local location = locations[locationIndex]
                                    if location then
                                        PSC_SummaryStats_ProcessKillLocation(state, location, currentKillLevelNum)
                                    end
                                    locationIndex = locationIndex + 1
                                    processed = processed + 1
                                end
                            else
                                PSC_SummaryStats_ProcessKillEntryFallback(state, currentKillData, currentKillKills, currentKillLevelNum)
                                advanceToNextKill()
                                processed = processed + 1
                            end
                        end
                    end
                end
            end
        end

        return false
    end
end

local function PSC_PopulateSummaryStatsContainer(container, stats, isLocalPlayer, extraData, playerName)
    local spacing_between_sections = 10
    local statY = -22

    -- 1. Totals
    local totalKillsTooltip = isLocalPlayer and "Total number of players you have killed." or "Total number of players killed."
    statY = addSummaryStatLine(container, "Total player kills:", stats.totalKills or 0, statY, totalKillsTooltip, false, isLocalPlayer)

    local uniqueKillsTooltip = isLocalPlayer and "Total number of unique players you have killed. Multiple kills of the same player are counted only once." or "Total number of unique players killed."
    statY = addSummaryStatLine(container, "Unique players killed:", stats.uniqueKills or 0, statY, uniqueKillsTooltip, false, isLocalPlayer)

    local totalDeathsTooltip = isLocalPlayer and "Total number of times you have died to players." or "Total number of deaths to players."
    statY = addSummaryStatLine(container, "Total player deaths:", stats.totalDeaths or 0, statY, totalDeathsTooltip, false, isLocalPlayer)

    local kdRatio = PSC_FormatKDRatio(stats.totalKills, stats.totalDeaths, stats.kdRatio)
    local kdText = kdRatio .. " (" .. (stats.totalKills or 0) .. "/" .. (stats.totalDeaths or 0) .. ")"
    local kdTooltip = isLocalPlayer and "Overall kill/death ratio (total player kills divided by total PvP deaths)." or "Overall kill/death ratio."
    statY = addSummaryStatLine(container, "K/D ratio:", kdText, statY, kdTooltip, false, isLocalPlayer)

    local totalKills = stats.totalKills or 0
    local totalDeaths = stats.totalDeaths or 0
    local totalEncounters = totalKills + totalDeaths
    if totalEncounters > 0 then
        local winPct = (totalKills / totalEncounters) * 100
        local winText = PSC_FormatPercent(winPct, 2)
        local winColor = PSC_GetWinPercentageColor(winPct)
        local winTooltip = isLocalPlayer and "Win percentage: kills divided by total encounters (kills + deaths)." or "Win percentage: kills divided by total encounters (kills + deaths)."
        statY = addSummaryStatLine(container, "Win percentage:", winText, statY, winTooltip, false, isLocalPlayer, winColor)
    end

    if (stats.unknownLevelKills and stats.unknownLevelKills > 0) or isLocalPlayer then
        local unknownTooltip = "Total number of times you have killed a level ?? player."
        statY = addSummaryStatLine(container, "Level ?? kills:", stats.unknownLevelKills or 0, statY, unknownTooltip, false, isLocalPlayer)
    end

    -- 2. Most Killed & Nemesis
    if stats.mostKilledPlayer and (stats.mostKilledCount or 0) > 0 and stats.mostKilledPlayer ~= "None" then
        local mostKilledText = stats.mostKilledPlayer .. " (" .. (stats.mostKilledCount or 0) .. ")"
        local mostKilledTooltip
        if isLocalPlayer then
            mostKilledTooltip = "Click to show all kills of this player"
        else
            local mkRace = (stats.mostKilledRace and stats.mostKilledRace ~= "") and stats.mostKilledRace or nil
            local mkGender = (stats.mostKilledGender and stats.mostKilledGender ~= "") and stats.mostKilledGender or nil
            local mkClass = (stats.mostKilledClass and stats.mostKilledClass ~= "") and stats.mostKilledClass or nil

            if not mkRace or not mkGender or not mkClass then
                local mkInfo, _ = PSC_GetPlayerInfo(stats.mostKilledPlayer)
                mkRace = mkRace or ((mkInfo and mkInfo.race and mkInfo.race ~= "") and mkInfo.race or "Unknown")
                mkGender = mkGender or ((mkInfo and mkInfo.gender and mkInfo.gender ~= "") and mkInfo.gender or "Unknown")
                mkClass = mkClass or ((mkInfo and mkInfo.class and mkInfo.class ~= "") and mkInfo.class or "Unknown")
            end

            mostKilledTooltip = {
                text = mkRace .. " " .. mkGender .. " " .. mkClass,
                color = getClassColor(mkClass)
            }
        end
        statY = addSummaryStatLine(container, "Most killed player:", mostKilledText, statY - spacing_between_sections, mostKilledTooltip, false, isLocalPlayer)
    end

    if stats.nemesisName and stats.nemesisName ~= "None" and (stats.nemesisScore or 0) > 0 then
        local nemesisText = stats.nemesisName .. " (" .. (stats.nemesisScore or 0) .. ")"
        local nemesisTooltip
        if isLocalPlayer then
            nemesisTooltip = "The player who has killed you the most (kills + assists). Click to view details."
        else
            local nemesisRace = (stats.nemesisRace and stats.nemesisRace ~= "") and stats.nemesisRace or nil
            local nemesisGender = (stats.nemesisGender and stats.nemesisGender ~= "") and stats.nemesisGender or nil
            local nemesisClass = (stats.nemesisClass and stats.nemesisClass ~= "") and stats.nemesisClass or nil

            if not nemesisRace or not nemesisGender or not nemesisClass then
                local nemesisInfo, _ = PSC_GetPlayerInfo(stats.nemesisName)
                nemesisRace = nemesisRace or ((nemesisInfo and nemesisInfo.race and nemesisInfo.race ~= "") and nemesisInfo.race or "Unknown")
                nemesisGender = nemesisGender or ((nemesisInfo and nemesisInfo.gender and nemesisInfo.gender ~= "") and nemesisInfo.gender or "Unknown")
                nemesisClass = nemesisClass or ((nemesisInfo and nemesisInfo.class and nemesisInfo.class ~= "") and nemesisInfo.class or "Unknown")
            end

            nemesisTooltip = {
                text = nemesisRace .. " " .. nemesisGender .. " " .. nemesisClass,
                color = getClassColor(nemesisClass)
            }
        end
        statY = addSummaryStatLine(container, "Nemesis:", nemesisText, statY, nemesisTooltip, false, isLocalPlayer)
    end

    -- 3. Averages
    if stats.avgLevel and stats.avgLevel > 0 then
        statY = addSummaryStatLine(container, "Avg. victim level:", string.format("%.1f", stats.avgLevel), statY - spacing_between_sections,
            isLocalPlayer and "Average level of players you have killed." or "Average level of players killed.", false, isLocalPlayer)
    end

    if stats.avgKillsPerPlayer and stats.avgKillsPerPlayer > 0 then
        statY = addSummaryStatLine(container, "Avg. kills per player:", string.format("%.2f", stats.avgKillsPerPlayer), statY,
            isLocalPlayer and "Average number of kills per unique player." or "Average number of kills per unique player.", false, isLocalPlayer)
    end

    if stats.avgLevelDiff and stats.avgLevelDiff ~= 0 then
        local levelDiffText = string.format("%.1f", stats.avgLevelDiff) ..
                              (stats.avgLevelDiff > 0 and " (you're higher)" or " (you're lower)")
        statY = addSummaryStatLine(container, "Avg. level difference:", levelDiffText, statY,
            isLocalPlayer and "Average level difference between you and the players you have killed." or "Average level difference.", false, isLocalPlayer)
    end

    -- 4. Streaks
    local killStreakY = statY - spacing_between_sections
    local csTooltip = isLocalPlayer
        and "Your current kill streak on this character. Streaks persist through logouts and only end when you die or manually reset your statistics in the addon settings."
        or "Current active kill streak."

    statY = addSummaryStatLine(container, "Current kill streak:", tostring(stats.currentKillStreak or 0), killStreakY, csTooltip, true, isLocalPlayer)

    local hkTooltip = "The highest kill streak achieved."
    local mkTooltip = "The highest number of kills achieved while staying in combat."
    local hkValue = tostring(stats.highestKillStreak or 0)
    local mkValue = tostring(stats.highestMultiKill or 0)

    if isLocalPlayer then
        if PSC_DB.ShowAccountWideStats then
            hkTooltip = "The highest kill streak you ever achieved across all characters."
            if (stats.highestKillStreak or 0) > 0 then
                hkValue = hkValue .. " (" .. (stats.highestKillStreakCharacter or "") .. ")"
            end

            mkTooltip = "The highest number of kills you achieved while staying in combat across all characters."
            if (stats.highestMultiKill or 0) > 0 then
                mkValue = mkValue .. " (" .. (stats.highestMultiKillCharacter or "") .. ")"
            end
        else
            hkTooltip = "The highest kill streak you achieved on this character."
            mkTooltip = "The highest number of kills you achieved while staying in combat on this character."
        end
    end

    statY = addSummaryStatLine(container, "Highest kill streak:", hkValue, statY, hkTooltip, false, isLocalPlayer)
    statY = addSummaryStatLine(container, "Highest multi-kill:", mkValue, statY, mkTooltip, false, isLocalPlayer)

    -- 5. Time Periods
    if stats.killsToday or (isLocalPlayer and stats.killsToday ~= nil) then
        statY = addSummaryStatLine(container, "Kills today:", tostring(stats.killsToday or 0), statY, "Total player kills today.", false, isLocalPlayer)
    end
    if stats.killsThisWeek or (isLocalPlayer and stats.killsThisWeek ~= nil) then
        statY = addSummaryStatLine(container, "Kills this week:", tostring(stats.killsThisWeek or 0), statY, "Total player kills this week.", false, isLocalPlayer)
    end
    if stats.killsThisMonth or (isLocalPlayer and stats.killsThisMonth ~= nil) then
        statY = addSummaryStatLine(container, "Kills this month:", tostring(stats.killsThisMonth or 0), statY, "Total player kills this month.", false, isLocalPlayer)
    end
    if stats.killsThisYear or (isLocalPlayer and stats.killsThisYear ~= nil) then
        statY = addSummaryStatLine(container, "Kills this year:", tostring(stats.killsThisYear or 0), statY, "Total player kills this year.", false, isLocalPlayer)
    end

    if stats.mostKillsInDay or (isLocalPlayer and stats.mostKillsInDay ~= nil) then
        local dayText = tostring(stats.mostKillsInDay or 0)
        if stats.mostKillsInDayDate then
            dayText = dayText .. " (" .. stats.mostKillsInDayDate .. ")"
        end
        statY = addSummaryStatLine(container, "Most kills in one day:", dayText, statY,
            isLocalPlayer and "Your highest number of player kills recorded on a local calendar day." or "Highest number of player kills recorded on a calendar day.", false, isLocalPlayer)
    end
    if stats.mostKillsInWeek or (isLocalPlayer and stats.mostKillsInWeek ~= nil) then
        local weekText = tostring(stats.mostKillsInWeek or 0)
        if stats.mostKillsInWeekDate then
            weekText = weekText .. " (week of " .. stats.mostKillsInWeekDate .. ")"
        end
        statY = addSummaryStatLine(container, "Most kills in one week:", weekText, statY,
            isLocalPlayer and "Your highest number of player kills recorded during a Wednesday-to-Tuesday statistics week." or "Highest number of player kills recorded during a Wednesday-to-Tuesday statistics week.", false, isLocalPlayer)
    end

    statY = statY - spacing_between_sections

    -- 6. Busiest & Activity
    if stats.busiestWeekday and stats.busiestWeekday ~= "None" then
        local tip = isLocalPlayer and "Your most active day of the week for PvP kills." or "Most active day of the week."
        statY = addSummaryStatLine(container, "Busiest weekday:", stats.busiestWeekday .. " (" .. (stats.busiestWeekdayKills or 0) .. ")", statY, tip, false, isLocalPlayer)
    end

    if stats.busiestHour and stats.busiestHour ~= "None" then
        local tip = isLocalPlayer and "Your most active hour of the day for PvP kills." or "Most active hour of the day."
        statY = addSummaryStatLine(container, "Busiest hour:", stats.busiestHour .. " (" .. (stats.busiestHourKills or 0) .. ")", statY, tip, false, isLocalPlayer)
    end

    if stats.busiestMonth and stats.busiestMonth ~= "None" then
        local tip = isLocalPlayer and "Your most active month for PvP kills." or "Most active month."
        statY = addSummaryStatLine(container, "Busiest month:", stats.busiestMonth .. " (" .. (stats.busiestMonthKills or 0) .. ")", statY, tip, false, isLocalPlayer)
    end

    if stats.avgKillsPerDay and stats.avgKillsPerDay > 0 then
        local tip = isLocalPlayer and "Your average kills per day from your first recorded kill to your most recent kill. This includes all days in that time period, even days when you didn't play." or "Average kills per day."
        statY = addSummaryStatLine(container, "Average kills per day:", string.format("%.1f", stats.avgKillsPerDay), statY, tip, false, isLocalPlayer)
    end

    if stats.uniqueGuildsKilled ~= nil then
        statY = addSummaryStatLine(container, "Unique guilds killed:", stats.uniqueGuildsKilled, statY,
            "Number of guilds whose members you have killed.", false, isLocalPlayer)
    end

    -- 7. Achievements
    if extraData and extraData.achievementsUnlocked and extraData.totalAchievements then
        statY = statY - spacing_between_sections
        local percentage = 0
        if extraData.totalAchievements > 0 then
            percentage = (extraData.achievementsUnlocked / extraData.totalAchievements) * 100
        end

        local achieveText = extraData.achievementsUnlocked .. " / " .. extraData.totalAchievements .. " (" .. PSC_FormatPercent(percentage, 2) .. ")"

        if isLocalPlayer then
            local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            labelText:SetPoint("TOPLEFT", 0, statY)
            labelText:SetText("Achievements unlocked:")

            local valueText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            valueText:SetPoint("TOPLEFT", 150, statY)
            valueText:SetText(achieveText)

            local achievementButton = CreateFrame("Button", nil, container)
            achievementButton:SetPoint("TOPLEFT", labelText, "TOPLEFT", 0, 0)
            achievementButton:SetPoint("BOTTOMRIGHT", valueText, "BOTTOMRIGHT", 0, 0)
            PSC_CreateGoldHighlight(achievementButton, 20)

            achievementButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                GameTooltip:AddLine("Click to view your achievements", 1, 1, 1, true)
                GameTooltip:Show()
            end)
            achievementButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
            achievementButton:SetScript("OnClick", function() PSC_ToggleAchievementFrame() end)
        else
            addSummaryStatLine(container, "Achievements:", achieveText, statY, "Total achievements completed.", false, isLocalPlayer)
        end

        statY = statY - 20

        if extraData.achievementPoints then
             local ptText = tostring(extraData.achievementPoints)
             if extraData.totalPossiblePoints then
                 ptText = ptText .. " / " .. extraData.totalPossiblePoints
             end
             statY = addSummaryStatLine(container, "Achievement points:", ptText, statY, "Total achievement points earned.", false, isLocalPlayer)
        end
    end

    statY = statY - spacing_between_sections
    statY = addSummaryStatLine(container, "Double kills:", stats.doubleKills or 0, statY,
        "Double kills recorded since version 4.7.", false, isLocalPlayer)
    statY = addSummaryStatLine(container, "Triple kills:", stats.tripleKills or 0, statY,
        "Triple kills recorded since version 4.7.", false, isLocalPlayer)
    statY = addSummaryStatLine(container, "Quadra kills:", stats.quadraKills or 0, statY,
        "Quadra kills recorded since version 4.7.", false, isLocalPlayer)
    statY = addSummaryStatLine(container, "Penta kills:", stats.pentaKills or 0, statY,
        "Penta kills recorded since version 4.7.", false, isLocalPlayer)
    statY = addSummaryStatLine(container, ">= Hexa kills:", stats.hexaPlusKills or 0, statY,
        "Multi-kills of 6 or more, recorded since version 4.7.", false, isLocalPlayer)

    -- 8. Footer Note
    if not isLocalPlayer then
        local noteText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noteText:SetPoint("BOTTOM", container, "BOTTOM", 0, -68)
        noteText:SetText("Viewing " .. (playerName or "Unknown") .. "'s statistics")
        noteText:SetTextColor(0.7, 0.7, 0.7)
    end

    return -statY + 10
end

local function createSummaryStatsForExternalPlayer(parent, x, y, width, height, stats, playerName, extraData)
    local container = createContainerWithTitle(parent, "Summary Statistics", x, y, width, height, width - 20)
    AddSummaryStatsTitleMeta(container, {
        class = extraData and (extraData.class or extraData.playerClass),
        race = extraData and (extraData.race or extraData.playerRace),
        gender = extraData and (extraData.gender or extraData.playerGender),
        guild = extraData and extraData.guild,
        allowLocalFallback = false
    })
    local contentHeight = PSC_PopulateSummaryStatsContainer(container, stats, false, extraData, playerName)
    container:SetHeight(math.max(height, contentHeight))
    return container
end

local function createSummaryStats(parent, x, y, width, height, stats, guildData)
    local container = createContainerWithTitle(parent, "Summary Statistics", x, y, width, height, width - 20)
    AddSummaryStatsTitleMeta(container)

    if not stats then
        local charactersToProcess = GetCharactersToProcessForStatistics()
        stats = PSC_CalculateSummaryStatistics(charactersToProcess)
        guildData = PSC_CalculateGuildKills(charactersToProcess)
    end

    if guildData then
        local _, uniqueGuildsKilled = PSC_CalculateGuildStats(guildData)
        stats.uniqueGuildsKilled = uniqueGuildsKilled
    end

    local extraData = {}
    if PVPSC.AchievementSystem and PVPSC.AchievementSystem.achievements then
        local currentCharacterKey = PSC_GetCharacterKey()
        local totalCount = #PVPSC.AchievementSystem.achievements
        local completedCount = 0

        if PSC_DB.CharacterAchievements and PSC_DB.CharacterAchievements[currentCharacterKey] then
            for _, achievementData in pairs(PSC_DB.CharacterAchievements[currentCharacterKey]) do
                if achievementData.unlocked then
                    completedCount = completedCount + 1
                end
            end
        end

        extraData.achievementsUnlocked = completedCount
        extraData.totalAchievements = totalCount
        extraData.achievementPoints = PSC_DB.CharacterAchievementPoints[currentCharacterKey] or 0
        extraData.totalPossiblePoints = PVPSC.AchievementSystem:GetTotalPossiblePoints()
    end

    local contentHeight = PSC_PopulateSummaryStatsContainer(container, stats, true, extraData)
    container:SetHeight(math.max(height, contentHeight))
    return container
end

function PSC_CalculateBarChartStatistics(charactersToProcess)
    local db = PSC_DB
    local playerInfoCache = db.PlayerInfoCache
    local getInfoKeyFromName = PSC_GetInfoKeyFromName
    local strfind = string.find
    local strsub = string.sub
    local tonumber = tonumber
    local ipairs = ipairs
    local pairs = pairs

    local infoKeyCache = {}

    local classData = {}
    local raceData = {}
    local genderData = {}
    local unknownLevelClassData = {}
    local zoneData = {}
    local levelData = {}
    local guildStatusData = {
        ["In Guild"] = 0,
        ["No Guild"] = 0
    }
    local guildData = {}
    local npcKillsData = {
        ["Corporal Keeshan"] = 0,
        ["The Defias Traitor"] = 0,
        ["Defias Messenger"] = 0
    }
    local hourlyData = {}
    -- Initialize all hours (0-23) with 0 kills
    for hour = 0, 23 do
        hourlyData[hour] = 0
    end
    local redridgeLevel15To25Kills = 0 -- Feeds the "bonus_next_redridgeguy" achievement without a separate full-table scan
    local redridgeLevel60To70Kills = 0 -- Feeds the "bonus_redridge_revenge" achievement without a separate full-table scan

    -- Ensure all classes, races, genders are present with at least 0
    local allRaces = {"Human", "Dwarf", "Night Elf", "Gnome", "Orc", "Undead", "Troll", "Tauren"}
    local allGenders = {"MALE", "FEMALE"}

    for _, class in ipairs(ALL_CLASSES) do
        classData[class] = 0
        unknownLevelClassData[class] = 0
    end
    for _, race in ipairs(allRaces) do
        raceData[race] = 0
    end
    for _, gender in ipairs(allGenders) do
        genderData[gender] = 0
    end

    if not db.PlayerKillCounts.Characters then
        return classData, raceData, genderData, unknownLevelClassData, zoneData, levelData, guildStatusData, guildData, npcKillsData, hourlyData, redridgeLevel15To25Kills, redridgeLevel60To70Kills
    end

    for _, characterData in pairs(charactersToProcess) do
        if characterData.NPCKills then
            for npcName, kills in pairs(characterData.NPCKills) do
                npcKillsData[npcName] = (npcKillsData[npcName] or 0) + kills
            end
        end

        if characterData.Kills then
            for nameWithLevel, killData in pairs(characterData.Kills) do
                if killData.kills and killData.kills > 0 then
                    local colonIndex = strfind(nameWithLevel, ":", 1, true)
                    local nameWithoutLevel
                    local levelPart
                    if colonIndex then
                        nameWithoutLevel = strsub(nameWithLevel, 1, colonIndex - 1)
                        levelPart = strsub(nameWithLevel, colonIndex + 1)
                    else
                        nameWithoutLevel = nameWithLevel
                        levelPart = nil
                    end

                    local kills = killData.kills

                    local infoKey = infoKeyCache[nameWithoutLevel]
                    if not infoKey then
                        infoKey = PSC_NormalizePlayerName(nameWithoutLevel)
                        infoKeyCache[nameWithoutLevel] = infoKey
                    end

                    local info = infoKey and playerInfoCache[infoKey] or nil
                    if info then
                        local class = info.class
                        if class then
                            classData[class] = (classData[class] or 0) + kills
                        end

                        local levelNum = tonumber(levelPart or "0") or 0
                        if levelNum == -1 then
                            if class then
                                unknownLevelClassData[class] = (unknownLevelClassData[class] or 0) + kills
                            end
                            levelData["??"] = (levelData["??"] or 0) + kills
                        else
                            if levelNum > 0 and levelNum <= 70 then
                                local levelKey = levelPart
                                if not levelKey or levelKey == "" then
                                    levelKey = tostring(levelNum)
                                end
                                levelData[levelKey] = (levelData[levelKey] or 0) + kills
                            end
                        end

                        local race = info.race
                        if race then
                            raceData[race] = (raceData[race] or 0) + kills
                        end

                        local gender = info.gender
                        if gender then
                            genderData[gender] = (genderData[gender] or 0) + kills
                        end

                        local isVictimLevel15To25 = levelNum >= 15 and levelNum <= 25
                        local isVictimLevel60To70 = levelNum >= 60 and levelNum <= 70

                        if killData.killLocations and #killData.killLocations > 0 then
                            for _, location in ipairs(killData.killLocations) do
                                local zone = location.zone or "Unknown"
                                zoneData[zone] = (zoneData[zone] or 0) + 1

                                if zone == "Redridge Mountains" then
                                    if isVictimLevel15To25 then
                                        redridgeLevel15To25Kills = redridgeLevel15To25Kills + 1
                                    elseif isVictimLevel60To70 then
                                        redridgeLevel60To70Kills = redridgeLevel60To70Kills + 1
                                    end
                                end

                                if location.timestamp then
                                    local hourStr = date("%H", location.timestamp)
                                    if hourStr then
                                        local hour = tonumber(hourStr)
                                        if hour then
                                            hourlyData[hour] = hourlyData[hour] + 1
                                        end
                                    end
                                end
                            end
                        end

                        local guild = info.guild
                        if guild and guild ~= "" then
                            guildStatusData["In Guild"] = guildStatusData["In Guild"] + kills
                            guildData[guild] = (guildData[guild] or 0) + kills
                        else
                            guildStatusData["No Guild"] = guildStatusData["No Guild"] + kills
                        end
                    end
                end
            end
        end
    end

    return classData, raceData, genderData, unknownLevelClassData, zoneData, levelData, guildStatusData, guildData, npcKillsData, hourlyData, redridgeLevel15To25Kills, redridgeLevel60To70Kills
end

function PSC_CalculateHourlyStatistics(charactersToProcess)
    local hourlyData = {}

    -- Initialize all hours (0-23) with 0 kills
    for hour = 0, 23 do
        hourlyData[hour] = 0
    end

    if not PSC_DB.PlayerKillCounts.Characters then
        return hourlyData
    end

    for characterKey, characterData in pairs(charactersToProcess) do
        if characterData.Kills then
            for nameWithLevel, killData in pairs(characterData.Kills) do
                if killData.kills and killData.kills > 0 and killData.killLocations then
                    for _, location in ipairs(killData.killLocations) do
                        if location.timestamp then
                            local dateInfo = date("*t", location.timestamp)
                            if dateInfo and dateInfo.hour then
                                hourlyData[dateInfo.hour] = hourlyData[dateInfo.hour] + 1
                            end
                        end
                    end
                end
            end
        end
    end

    return hourlyData
end

function PSC_CalculateWeekdayStatistics(charactersToProcess)
    local weekdayData = {}

    -- Initialize all weekdays (1-7, Sunday=1) with 0 kills
    for weekday = 1, 7 do
        weekdayData[weekday] = 0
    end

    if not PSC_DB.PlayerKillCounts.Characters then
        return weekdayData
    end

    for characterKey, characterData in pairs(charactersToProcess) do
        if characterData.Kills then
            for nameWithLevel, killData in pairs(characterData.Kills) do
                if killData.kills and killData.kills > 0 and killData.killLocations then
                    for _, location in ipairs(killData.killLocations) do
                        if location.timestamp then
                            local dateInfo = date("*t", location.timestamp)
                            if dateInfo and dateInfo.wday then
                                weekdayData[dateInfo.wday] = weekdayData[dateInfo.wday] + 1
                            end
                        end
                    end
                end
            end
        end
    end

    return weekdayData
end

function PSC_CalculateMonthlyStatistics(charactersToProcess)
    local monthlyData = {}

    -- Initialize all months (1-12) with 0 kills
    for month = 1, 12 do
        monthlyData[month] = 0
    end

    if not PSC_DB.PlayerKillCounts.Characters then
        return monthlyData
    end

    for characterKey, characterData in pairs(charactersToProcess) do
        if characterData.Kills then
            for nameWithLevel, killData in pairs(characterData.Kills) do
                if killData.kills and killData.kills > 0 and killData.killLocations then
                    for _, location in ipairs(killData.killLocations) do
                        if location.timestamp then
                            local dateInfo = date("*t", location.timestamp)
                            if dateInfo and dateInfo.month then
                                monthlyData[dateInfo.month] = monthlyData[dateInfo.month] + 1
                            end
                        end
                    end
                end
            end
        end
    end

    return monthlyData
end

function PSC_CalculateMonthlyByYearStatistics(charactersToProcess)
    local monthlyByYear = {}

    if not PSC_DB.PlayerKillCounts.Characters then
        return monthlyByYear
    end

    for _, characterData in pairs(charactersToProcess) do
        if characterData.Kills then
            for _, killData in pairs(characterData.Kills) do
                if killData.kills and killData.kills > 0 and killData.killLocations then
                    for _, location in ipairs(killData.killLocations) do
                        if location.timestamp then
                            local dateInfo = date("*t", location.timestamp)
                            if dateInfo and dateInfo.month and dateInfo.year then
                                local month = dateInfo.month
                                if not monthlyByYear[month] then
                                    monthlyByYear[month] = {}
                                end
                                monthlyByYear[month][dateInfo.year] = (monthlyByYear[month][dateInfo.year] or 0) + 1
                            end
                        end
                    end
                end
            end
        end
    end

    return monthlyByYear
end

function PSC_CalculateYearlyStatistics(charactersToProcess)
    local yearlyData = {}

    if not PSC_DB.PlayerKillCounts.Characters then
        return yearlyData
    end

    for characterKey, characterData in pairs(charactersToProcess) do
        if characterData.Kills then
            for nameWithLevel, killData in pairs(characterData.Kills) do
                if killData.kills and killData.kills > 0 and killData.killLocations then
                    for _, location in ipairs(killData.killLocations) do
                        if location.timestamp then
                            local dateInfo = date("*t", location.timestamp)
                            if dateInfo and dateInfo.year then
                                yearlyData[dateInfo.year] = (yearlyData[dateInfo.year] or 0) + 1
                            end
                        end
                    end
                end
            end
        end
    end

    return yearlyData
end

local function createScrollableLeftPanel(parent)
    local leftPanel = CreateFrame("Frame", nil, parent)
    leftPanel:SetPoint("TOPLEFT", 0, 0)
    leftPanel:SetPoint("BOTTOMLEFT", 0, 0)
    leftPanel:SetWidth(430)

    local containerFrame = CreateFrame("Frame", nil, parent)
    containerFrame:SetPoint("TOPLEFT", UI.LEFT_SCROLL_PADDING, -UI.TOP_PADDING)
    containerFrame:SetPoint("BOTTOMLEFT", UI.LEFT_SCROLL_PADDING, 10)
    containerFrame:SetWidth(400 - UI.LEFT_SCROLL_PADDING)

    local scrollFrame = CreateFrame("ScrollFrame", nil, containerFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(375 - UI.LEFT_SCROLL_PADDING)

    scrollFrame:SetScrollChild(content)

    local scrollBarName = scrollFrame:GetName() and scrollFrame:GetName() .. "ScrollBar" or nil
    local scrollBar = scrollBarName and _G[scrollBarName] or nil

    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", -18, -16)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", -18, 16)
    end

    return content, scrollFrame
end

local function createScrollableRightPanel(parent, hasFixedButtons)
    local containerFrame = CreateFrame("Frame", nil, parent)
    containerFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 440, -UI.TOP_PADDING)
    containerFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, hasFixedButtons and 110 or 10)

    local scrollFrame = CreateFrame("ScrollFrame", nil, containerFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetAllPoints(containerFrame)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(380)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    local scrollBar = scrollFrame.ScrollBar or scrollFrame.scrollBar
    local scrollBarName = scrollFrame:GetName() and scrollFrame:GetName() .. "ScrollBar" or nil
    scrollBar = scrollBar or (scrollBarName and _G[scrollBarName] or nil)

    if not scrollBar then
        local children = {scrollFrame:GetChildren()}
        for _, child in ipairs(children) do
            if child:GetObjectType() == "Slider" then
                scrollBar = child
                break
            end
        end
    end

    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", -26, -16)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", -26, 16)
    end

    return content, scrollFrame
end

function GetFrameTitleTextWithCharacterText(titleText)
    if PSC_DB.ShowAccountWideStats then
        titleText = titleText .. " |cFFFFFFFF(account-wide stats)|r"
    else
        titleText = titleText .. " (" .. PSC_GetCharacterKey() .. ")"
    end
    return titleText
end

local function setupMainFrame()
    local frame = CreateFrame("Frame", "PSC_StatisticsFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(UI.FRAME.WIDTH, UI.FRAME.HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    tinsert(UISpecialFrames, "PSC_StatisticsFrame")

    local titleText = GetFrameTitleTextWithCharacterText("PvP Statistics")
    frame.TitleText:SetText(titleText)

    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    frame.CloseButton:SetScript("OnClick", function()
        PSC_FrameManager:HideFrame("Statistics")
    end)

    frame.TitleText:SetText("PvP Statistics")

    local separator = frame:CreateTexture(nil, "ARTWORK")
    separator:SetPoint("TOPLEFT", 430, -5)
    separator:SetPoint("BOTTOMLEFT", 430, 5)
    separator:SetWidth(1)
    separator:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    return frame
end

local function enoughPlayerKillsRecorded()
    local totalKills = 0
    local uniqueKills = 0

    local charactersToProcess = GetCharactersToProcessForStatistics()

    for characterKey, characterData in pairs(charactersToProcess) do
        for nameWithLevel, killData in pairs(characterData.Kills) do
            if killData.kills and killData.kills > 0 then
                uniqueKills = uniqueKills + 1
                totalKills = totalKills + killData.kills
            end
        end
    end

    return totalKills >= 10 or uniqueKills >= 5
end

local function createEmptyStatsFrame()
    local frame = CreateFrame("Frame", "PSC_StatisticsFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(UI.FRAME.WIDTH, 200)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local titleText = GetFrameTitleTextWithCharacterText("Player Kill Statistics")
    frame.TitleText:SetText(titleText)

    local messageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    messageText:SetPoint("CENTER", 0, 0)
    messageText:SetText("You need at least 10 kills or 5 unique kills\nto view detailed statistics.")
    messageText:SetJustifyH("CENTER")

    return frame
end


function PSC_CreateStatisticsFrame()
    if statisticsFrame then
        statisticsFrame:Hide()
        PSC_FrameManager:HideFrame("Statistics")
        statisticsFrame = nil
    end

    for i = #UISpecialFrames, 1, -1 do
        if (UISpecialFrames[i] == "PSC_StatisticsFrame") then
            table.remove(UISpecialFrames, i)
            break
        end
    end

    if not enoughPlayerKillsRecorded() then
        statisticsFrame = createEmptyStatsFrame()
        PSC_FrameManager:RegisterFrame(statisticsFrame, "Statistics")
        return
    end

    statisticsFrame = setupMainFrame()
    statisticsFrame:SetScript("OnKeyDown", nil)
    PSC_FrameManager:RegisterFrame(statisticsFrame, "Statistics")

    PSC_UpdateStatisticsFrame(statisticsFrame)
end

function PSC_UpdateStatisticsFrame(frame, externalPlayerData)
    if not frame then
        return
    end

    -- Determine if we're viewing external player data or local data
    local isExternalPlayer = (externalPlayerData ~= nil)
    local playerDisplayName = isExternalPlayer and externalPlayerData.playerName or nil

    -- Set title based on whether it's external or local data
    local titleText
    if isExternalPlayer and playerDisplayName then
        titleText = playerDisplayName .. "'s PvP Statistics"
        if externalPlayerData.level and externalPlayerData.class then
            titleText = titleText .. " (Lvl " .. externalPlayerData.level .. " " .. externalPlayerData.class .. ")"
        end
    else
        titleText = GetFrameTitleTextWithCharacterText("PvP Statistics")
    end
    frame.TitleText:SetText(titleText)

    if frame.leftScrollContent then
        clearReorderButtonScripts()
        frame.leftScrollContent:SetParent(nil)
        frame.leftScrollContent = nil
    end

    if frame.guildTable then
        frame.guildTable:SetParent(nil)
        frame.guildTable = nil
    end

    if frame.summaryStats then
        frame.summaryStats:SetParent(nil)
        frame.summaryStats = nil
    end

    if frame.rightScrollFrame then
        frame.rightScrollFrame:SetParent(nil)
        frame.rightScrollFrame = nil
        frame.rightScrollContent = nil
    end

    if frame.buttonSeparatorLine then
        frame.buttonSeparatorLine:SetTexture(nil)
        frame.buttonSeparatorLine = nil
    end

    if frame.buttonContainer then
        frame.buttonContainer:SetParent(nil)
        frame.buttonContainer = nil
    end

    if frame:GetHeight() < 400 then
        return
    end

    -- Get data based on whether we're viewing external or local player
    local classData, raceData, genderData, zoneData, levelData, hourlyData, weekdayData, monthlyData, yearlyData, stats
    local unknownLevelClassData, guildStatusData, guildData, npcKillsData
    local deathsByClassData
    local monthlyByYearData
    local monthlyClassBuckets = {}
    local monthlyClassPercentages = {}
    local monthlyClassTotals = {}

    if isExternalPlayer then
        -- Use data from external player
        classData = externalPlayerData.classData or {}
        raceData = externalPlayerData.raceData or {}
        genderData = externalPlayerData.genderData or {}
        zoneData = externalPlayerData.zoneData or {}
        levelData = externalPlayerData.levelData or {}
        hourlyData = externalPlayerData.hourlyData or {}
        weekdayData = externalPlayerData.weekdayData or {}
        monthlyData = externalPlayerData.monthlyData or {}
        yearlyData = externalPlayerData.yearlyData or {}
        stats = externalPlayerData.summary or {}
        -- Set defaults for data not available from external players
        unknownLevelClassData = externalPlayerData.unknownLevelClassData or {}
        deathsByClassData = externalPlayerData.deathsByClassData or {}
        guildStatusData = externalPlayerData.guildStatusData or {}
        guildData = {}
        npcKillsData = externalPlayerData.npcKillsData or {}
        monthlyClassBuckets = externalPlayerData.monthlyClassBuckets or {}
        monthlyClassPercentages = externalPlayerData.monthlyClassPercentages or {}
        monthlyClassTotals = externalPlayerData.monthlyClassTotals or {}
    else
        -- Calculate local player data
        local currentCharacterKey = PSC_GetCharacterKey()
        local charactersToProcess = {}
        if PSC_DB.ShowAccountWideStats then
            charactersToProcess = PSC_DB.PlayerKillCounts.Characters
        else
            if PSC_DB.PlayerKillCounts.Characters[currentCharacterKey] then
                charactersToProcess[currentCharacterKey] = PSC_DB.PlayerKillCounts.Characters[currentCharacterKey]
            end
        end

        classData, raceData, genderData, unknownLevelClassData, zoneData, levelData, guildStatusData, guildData, npcKillsData, hourlyData =
            PSC_CalculateBarChartStatistics(charactersToProcess)

        weekdayData = PSC_CalculateWeekdayStatistics(charactersToProcess)
        monthlyData = PSC_CalculateMonthlyStatistics(charactersToProcess)
        yearlyData = PSC_CalculateYearlyStatistics(charactersToProcess)
        monthlyByYearData = PSC_CalculateMonthlyByYearStatistics(charactersToProcess)
        stats = PSC_CalculateSummaryStatistics(charactersToProcess)
        deathsByClassData = PSC_CalculateDeathsByClass()
        monthlyClassBuckets, monthlyClassPercentages, monthlyClassTotals = PSC_CalculateMonthlyClassPercentageStatistics(charactersToProcess)
    end

    local leftScrollContent, leftScrollFrame = createScrollableLeftPanel(frame)
    frame.leftScrollContent = leftScrollContent
    frame.leftScrollFrame = leftScrollFrame

    local fixedNPCs = {}
    if UnitFactionGroup("player") == "Horde" then
        fixedNPCs["Corporal Keeshan"] = true
        fixedNPCs["The Defias Traitor"] = true
        fixedNPCs["Defias Messenger"] = true
        if npcKillsData then
            npcKillsData["Corporal Keeshan"] = npcKillsData["Corporal Keeshan"] or 0
            npcKillsData["The Defias Traitor"] = npcKillsData["The Defias Traitor"] or 0
            npcKillsData["Defias Messenger"] = npcKillsData["Defias Messenger"] or 0
        end
    end

    local kdByClassData, kdRawData = PSC_CalculateWinRateByClass(classData, deathsByClassData)

    local function getKDChartHeight()
        local count = 0
        for _ in pairs(kdByClassData) do count = count + 1 end
        if count == 0 then return 45 end
        return 30 + (count * (UI.BAR.HEIGHT + UI.BAR.SPACING)) + 15
    end

    local function getMonthlyClassChartHeight()
        local legendRows = math.ceil(#ALL_CLASSES / LINE_CHART_UI.LEGEND_COLUMNS)
        return LINE_CHART_UI.HEIGHT + (legendRows * LINE_CHART_UI.LEGEND_ROW_HEIGHT)
    end

    local guildStatusColors = {
        ["In Guild"] = { r = 0.2, g = 0.8, b = 0.2 },
        ["No Guild"] = { r = 0.8, g = 0.2, b = 0.2 },
    }

    local npcChartHeight = calculateChartHeight(npcKillsData, fixedNPCs)

    local chartDefs = {
        kills_by_class = {
            height = calculateChartHeight(classData),
            localOnly = false,
            render = function(parent, y, height)
                return createBarChart(parent, "Kills by Class", classData, nil, 0, y, UI.CHART.WIDTH, height, isExternalPlayer)
            end,
        },
        deaths_by_class = {
            height = calculateChartHeight(deathsByClassData),
            localOnly = false,
            render = function(parent, y, height)
                return createBarChart(parent, "Deaths by Class", deathsByClassData, nil, 0, y, UI.CHART.WIDTH, height, isExternalPlayer)
            end,
        },
        kd_by_class = {
            height = getKDChartHeight(),
            localOnly = false,
            render = function(parent, y, height)
                return createKDByClassBarChart(parent, 0, y, UI.CHART.WIDTH, kdByClassData, kdRawData)
            end,
        },
        monthly_class_percentage = {
            height = getMonthlyClassChartHeight(),
            localOnly = true,
            render = function(parent, y, height)
                return createMonthlyClassPercentageChart(
                    parent, 0, y, UI.CHART.WIDTH, isExternalPlayer,
                    monthlyClassBuckets, monthlyClassPercentages, monthlyClassTotals
                )
            end,
        },
        kills_by_race = {
            height = calculateChartHeight(raceData),
            localOnly = false,
            render = function(parent, y, height)
                return createBarChart(parent, "Kills by Race", raceData, raceColors, 0, y, UI.CHART.WIDTH, height, isExternalPlayer)
            end,
        },
        npc_kills = {
            height = npcChartHeight,
            localOnly = false,
            render = function(parent, y, height)
                if height <= 45 then return nil end
                return createBarChart(parent, "NPC Kills", npcKillsData, nil, 0, y, UI.CHART.WIDTH, height, isExternalPlayer)
            end,
        },
        kills_by_gender = {
            height = calculateChartHeight(genderData),
            localOnly = false,
            render = function(parent, y, height)
                return createBarChart(parent, "Kills by Gender", genderData, genderColors, 0, y, UI.CHART.WIDTH, height, isExternalPlayer)
            end,
        },
        kills_by_guild_status = {
            height = calculateChartHeight(guildStatusData),
            localOnly = false,
            render = function(parent, y, height)
                return createBarChart(parent, "Kills by Guild Status", guildStatusData, guildStatusColors, 0, y, UI.CHART.WIDTH, height, isExternalPlayer)
            end,
        },
        kills_by_hour = {
            height = calculateChartHeight(hourlyData),
            localOnly = false,
            render = function(parent, y, height)
                return createBarChart(parent, "Kills by Hour of Day", hourlyData, nil, 0, y, UI.CHART.WIDTH, height, isExternalPlayer)
            end,
        },
        kills_by_weekday = {
            height = calculateChartHeight(weekdayData),
            localOnly = false,
            render = function(parent, y, height)
                return createBarChart(parent, "Kills by Weekday", weekdayData, nil, 0, y, UI.CHART.WIDTH, height, isExternalPlayer)
            end,
        },
        kills_by_month = {
            height = calculateChartHeight(monthlyData),
            localOnly = false,
            render = function(parent, y, height)
                return createBarChart(parent, "Kills by Month", monthlyData, nil, 0, y, UI.CHART.WIDTH, height, isExternalPlayer, monthlyByYearData)
            end,
        },
        kills_by_year = {
            height = calculateChartHeight(yearlyData),
            localOnly = false,
            render = function(parent, y, height)
                return createBarChart(parent, "Kills by Year", yearlyData, nil, 0, y, UI.CHART.WIDTH, height, isExternalPlayer)
            end,
        },
        kills_by_level = {
            height = calculateChartHeight(levelData),
            localOnly = false,
            render = function(parent, y, height)
                return createBarChart(parent, "Kills by Level", levelData, nil, 0, y, UI.CHART.WIDTH, height, isExternalPlayer)
            end,
        },
        kills_by_zone = {
            height = calculateChartHeight(zoneData),
            localOnly = false,
            render = function(parent, y, height)
                return createBarChart(parent, "Kills by Zone", zoneData, nil, 0, y, UI.CHART.WIDTH, height, isExternalPlayer)
            end,
        },
        kills_by_guild = {
            height = UI.GUILD_LIST.HEIGHT,
            localOnly = true,
            render = function(parent, y, height)
                return createGuildTable(parent, 0, y, UI.CHART.WIDTH, height, guildData)
            end,
        },
    }

    local chartOrder = getChartOrder()
    local yOffset = 0
    local renderedCharts = {}

    frame.chartContainers = {}
    for _, chartId in ipairs(chartOrder) do
        local def = chartDefs[chartId]
        if def and (not def.localOnly or not isExternalPlayer) then
            local container = def.render(leftScrollContent, yOffset, def.height)
            if container then
                frame.chartContainers[chartId] = { container = container, height = def.height }
                table.insert(renderedCharts, { id = chartId, container = container })
                yOffset = yOffset - def.height - UI.CHART.PADDING
            end
        end
    end

    if not isExternalPlayer then
        for _, rendered in ipairs(renderedCharts) do
            addChartReorderButtonsOnce(rendered.container)
        end
        updateChartReorderButtons(renderedCharts)

        local resetBtn = CreateFrame("Button", nil, leftScrollContent, "UIPanelButtonTemplate")
        resetBtn:SetSize(UI.CHART.WIDTH, 22)
        resetBtn:SetPoint("TOPLEFT", 0, yOffset - 10)
        resetBtn:SetText("Reset Chart Order")
        resetBtn:SetScript("OnClick", function()
            saveChartOrder(copyArray(DEFAULT_CHART_ORDER))
            reorderChartContainers(statisticsFrame)
        end)
        frame.resetOrderBtn = resetBtn
        leftScrollContent:SetHeight(-(yOffset) + 57)
    else
        leftScrollContent:SetHeight(-(yOffset) + 25)
    end

    local summaryStatsWidth = 380
    local summaryStatsHeight = 500
    local rightScrollContent, rightScrollFrame = createScrollableRightPanel(frame, not isExternalPlayer)
    frame.rightScrollContent = rightScrollContent
    frame.rightScrollFrame = rightScrollFrame

    -- Summary Statistics at top right (pass stats if external player)
    if isExternalPlayer then
        frame.summaryStats = createSummaryStatsForExternalPlayer(rightScrollContent, 0, 0, summaryStatsWidth, summaryStatsHeight, stats, playerDisplayName, externalPlayerData)
    else
        frame.summaryStats = createSummaryStats(rightScrollContent, 0, 0, summaryStatsWidth, summaryStatsHeight, stats, guildData)
    end
    rightScrollContent:SetHeight(frame.summaryStats:GetHeight() + (isExternalPlayer and 68 or 0))

    if not isExternalPlayer then
        local buttonSeparatorLine = frame:CreateTexture(nil, "ARTWORK")
        buttonSeparatorLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 430, 105)
        buttonSeparatorLine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 105)
        buttonSeparatorLine:SetHeight(1)
        buttonSeparatorLine:SetColorTexture(0.5, 0.5, 0.5, 0.5)
        frame.buttonSeparatorLine = buttonSeparatorLine

        local buttonContainer = CreateFrame("Frame", nil, frame)
        local buttonWidth = 140
        local buttonHeight = 25
        local buttonSpacing = 5
        local fullWidth = (buttonWidth * 2) + buttonSpacing
        buttonContainer:SetSize(fullWidth, (buttonHeight * 3) + (buttonSpacing * 2))
        buttonContainer:SetPoint("BOTTOM", frame, "BOTTOM", 210, 13)
        frame.buttonContainer = buttonContainer

        local settingsButton = CreateFrame("Button", nil, buttonContainer, "UIPanelButtonTemplate")
        settingsButton:SetSize(buttonWidth, buttonHeight)
        settingsButton:SetPoint("TOPLEFT", buttonContainer, "TOPLEFT", 0, 0)
        settingsButton:SetText("Show Settings")
        settingsButton:SetScript("OnClick", function()
            PSC_CreateConfigUI()
        end)

        local achievementsButton = CreateFrame("Button", nil, buttonContainer, "UIPanelButtonTemplate")
        achievementsButton:SetSize(buttonWidth, buttonHeight)
        achievementsButton:SetPoint("TOPRIGHT", buttonContainer, "TOPRIGHT", 0, 0)
        achievementsButton:SetText("Show Achievements")
        achievementsButton:SetScript("OnClick", function()
            PSC_ToggleAchievementFrame()
        end)

        local killHistoryButton = CreateFrame("Button", nil, buttonContainer, "UIPanelButtonTemplate")
        killHistoryButton:SetSize(buttonWidth, buttonHeight)
        killHistoryButton:SetPoint("TOPLEFT", settingsButton, "BOTTOMLEFT", 0, -buttonSpacing)
        killHistoryButton:SetText("Show Kill History")
        killHistoryButton:SetScript("OnClick", function()
            PSC_CreateKillsListFrame()
        end)

        local killstreakButton = CreateFrame("Button", nil, buttonContainer, "UIPanelButtonTemplate")
        killstreakButton:SetSize(buttonWidth, buttonHeight)
        killstreakButton:SetPoint("TOPRIGHT", achievementsButton, "BOTTOMRIGHT", 0, -buttonSpacing)
        killstreakButton:SetText("Show Kill Streak")
        killstreakButton:SetScript("OnClick", function()
            PSC_CreateKillStreakPopup()
        end)

        local leaderboardButton = CreateFrame("Button", nil, buttonContainer, "UIPanelButtonTemplate")
        leaderboardButton:SetSize(fullWidth, buttonHeight)
        leaderboardButton:SetPoint("TOPLEFT", killHistoryButton, "BOTTOMLEFT", 0, -buttonSpacing)
        leaderboardButton:SetText("Show Leaderboard")
        leaderboardButton:SetScript("OnClick", function()
            PSC_CreateLeaderboardFrame()
        end)
    end
end

-- Display another player's detailed statistics
function PSC_ShowPlayerDetailedStats(playerName, detailedStats)
    -- Create a separate frame for viewing other players' stats
    local viewerFrame = CreateFrame("Frame", "PSC_PlayerStatsViewer_" .. playerName, UIParent, "BasicFrameTemplateWithInset")
    viewerFrame:SetSize(UI.FRAME.WIDTH, UI.FRAME.HEIGHT)
    viewerFrame:SetPoint("CENTER")
    viewerFrame:SetMovable(true)
    viewerFrame:EnableMouse(true)
    viewerFrame:RegisterForDrag("LeftButton")
    viewerFrame:SetScript("OnDragStart", viewerFrame.StartMoving)
    viewerFrame:SetScript("OnDragStop", viewerFrame.StopMovingOrSizing)

    -- Add close button
    viewerFrame.CloseButton:SetScript("OnClick", function()
        viewerFrame:Hide()
        -- Frame manager will handle cleanup automatically when frame is hidden
    end)

    -- Register with frame manager
    if PSC_FrameManager then
        PSC_FrameManager:RegisterFrame(viewerFrame, "PlayerStatsViewer_" .. playerName)
    end

    -- Reuse the existing update function with external player data
    PSC_UpdateStatisticsFrame(viewerFrame, detailedStats)

    viewerFrame:Show()
end
