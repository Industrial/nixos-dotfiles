local addonName, PVPSC = ...

local killStreakPopupFrame = nil

-- Class colors from WoW
local CLASS_COLORS = {
    WARRIOR = {0.78, 0.61, 0.43},
    PALADIN = {0.96, 0.55, 0.73},
    HUNTER = {0.67, 0.83, 0.45},
    ROGUE = {1.00, 0.96, 0.41},
    PRIEST = {1.00, 1.00, 1.00},
    SHAMAN = {0.00, 0.44, 0.87},
    MAGE = {0.25, 0.78, 0.92},
    WARLOCK = {0.53, 0.53, 0.93},
    DRUID = {1.00, 0.49, 0.04},
    UNKNOWN = {0.5, 0.5, 0.5}
}

local function CreatePopupFrame()
    local frame = CreateFrame("Frame", "PSC_KillStreakPopupFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(220, 140)

    -- Set position from saved settings or default to bottom right
    local pos = PSC_DB.KillStreakPopupPosition or {point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", xOfs = -50, yOfs = 150}
    frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position when dragging stops
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        PSC_DB.KillStreakPopupPosition = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs
        }
    end)

    -- Override close button to work in combat
    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            PSC_FrameManager:HideFrame("PSC_KillStreakPopupFrame")
        end)
    end

    frame.TitleText:SetText("Current Kill Streak")

    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            frame:Hide()
        end)
    end

    frame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            self:Hide()
        end
    end)

    -- Create kill streak count text above everything
    local streakCountText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    streakCountText:SetPoint("TOP", 0, -30)
    streakCountText:SetTextColor(1.0, 0.82, 0.0) -- WoW gold color
    frame.streakCountText = streakCountText

    -- Create scroll frame with reduced space for the streak count text
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -45) -- Reduced from -55 to -45
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 12)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(170, 300)
    scrollFrame:SetScrollChild(content)

    frame.scrollFrame = scrollFrame
    frame.content = content

    return frame
end

local function CreateGoldHighlight(button, height)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 0.82, 0, 0.3)
    highlight:SetHeight(height)
    return highlight
end

local function CreatePlayerRow(parent, playerData, yOffset, isAlternate)
    local rowHeight = 16

    local rowButton = CreateFrame("Button", nil, parent)
    rowButton:SetSize(parent:GetWidth() - 10, rowHeight)
    rowButton:SetPoint("TOPLEFT", 0, yOffset)

    if isAlternate then
        local bg = rowButton:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
    end

    local highlight = CreateGoldHighlight(rowButton, rowHeight)

    local nameText = rowButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOPLEFT", 5, -2)
    nameText:SetText(playerData.name:match("^([^-]+)") or playerData.name)
    nameText:SetWidth(80)
    nameText:SetJustifyH("LEFT")

    local classColor = CLASS_COLORS[playerData.class:upper()] or CLASS_COLORS.UNKNOWN
    nameText:SetTextColor(classColor[1], classColor[2], classColor[3])


    local levelText = rowButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelText:SetPoint("TOPLEFT", 90, -2)
    levelText:SetText(playerData.level == -1 and "??" or tostring(playerData.level))
    levelText:SetWidth(25) -- Keep width at 25
    levelText:SetJustifyH("CENTER")
    levelText:SetTextColor(1, 1, 1)

    local classText = rowButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classText:SetPoint("TOPLEFT", 120, -2) -- Moved right from 105 to 120
    classText:SetText(playerData.class ~= "UNKNOWN" and playerData.class or "Unknown")
    classText:SetWidth(45) -- Increased from 40 to 45
    classText:SetJustifyH("LEFT")
    classText:SetTextColor(classColor[1], classColor[2], classColor[3])


    rowButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            PSC_ShowPlayerDetailFrame(playerData.name)
        end
    end)

    -- Register for left clicks
    rowButton:RegisterForClicks("LeftButtonUp")

    return yOffset - rowHeight
end

local function PopulateKillStreakList()
    if not killStreakPopupFrame then return end

    local content = killStreakPopupFrame.content

    -- Clear existing content
    local children = {content:GetChildren()}
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end

    local regions = {content:GetRegions()}
    for _, region in ipairs(regions) do
        if region:GetObjectType() == "Texture" or region:GetObjectType() == "FontString" then
            region:Hide()
            region:SetParent(nil)
        end
    end

    local characterKey = PSC_GetCharacterKey()
    local characterData = PSC_DB.PlayerKillCounts.Characters[characterKey]

    -- Update the kill streak count text in the main frame
    if killStreakPopupFrame.streakCountText then
        if not characterData or not characterData.CurrentKillStreakPlayers or #characterData.CurrentKillStreakPlayers == 0 then
            killStreakPopupFrame.streakCountText:SetText("Kill Streak: 0")
        else
            killStreakPopupFrame.streakCountText:SetText("Kill Streak: " .. characterData.CurrentKillStreak)
        end
    end

    if not characterData or not characterData.CurrentKillStreakPlayers or #characterData.CurrentKillStreakPlayers == 0 then
        local noDataText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noDataText:SetPoint("TOP", 0, -10)
        noDataText:SetText("No players in current kill streak")
        noDataText:SetTextColor(0.7, 0.7, 0.7)
        content:SetHeight(50)
        return
    end

    -- Create header (adjusted positions for narrower window)
    local headerBg = content:CreateTexture(nil, "BACKGROUND")
    headerBg:SetPoint("TOPLEFT", 0, -5)
    headerBg:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -5)
    headerBg:SetHeight(18) -- Reduced from 22 to 18 to match smaller header text
    headerBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

    local nameHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameHeader:SetPoint("TOPLEFT", 5, -7)
    nameHeader:SetText("Name")
    nameHeader:SetTextColor(1, 1, 1)

    local levelHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    levelHeader:SetPoint("TOPLEFT", 90, -7) -- Updated to match new row position
    levelHeader:SetText("Lvl")
    levelHeader:SetTextColor(1, 1, 1)

    local classHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classHeader:SetPoint("TOPLEFT", 120, -7) -- Updated to match new row position
    classHeader:SetText("Class")
    classHeader:SetTextColor(1, 1, 1)

    local yOffset = -25 -- Reduced from -30 to -25

    -- Create rows for each player (reversed order - newest first)
    local players = characterData.CurrentKillStreakPlayers
    for i = #players, 1, -1 do
        local playerData = players[i]
        local rowIndex = #players - i + 1 -- For alternating row colors
        yOffset = CreatePlayerRow(content, playerData, yOffset, rowIndex % 2 == 0)
    end

    -- Set content height
    local contentHeight = math.max(math.abs(yOffset) + 40, 100)
    content:SetHeight(contentHeight)
end

function PSC_CreateKillStreakPopup(isAutoOpen)
    if killStreakPopupFrame then
        if killStreakPopupFrame:IsVisible() then
            if isAutoOpen then
                PopulateKillStreakList()
                return
            else
                -- Manual call - toggle visibility
                killStreakPopupFrame:Hide()
                return
            end
        else
            killStreakPopupFrame:Show()
            PopulateKillStreakList()
            return
        end
    end

    killStreakPopupFrame = CreatePopupFrame()
    PopulateKillStreakList()
    killStreakPopupFrame:Show()

end

function PSC_UpdateKillStreakPopup()
    if killStreakPopupFrame and killStreakPopupFrame:IsVisible() then
        PopulateKillStreakList()
    end
end