local addonName, PVPSC = ...

-- Create LibDataBroker data object
local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("PvPStatsClassic", {
    type = "data source",
    text = "PvP Stats",
    icon = "Interface\\AddOns\\PvPStatsClassic\\img\\minimap",
    OnClick = function(self, button)
        if button == "LeftButton" then
            if IsControlKeyDown() then
                PSC_CreateConfigFrame()
            elseif IsShiftKeyDown() then
                PSC_CreateLeaderboardFrame()
            else
                PSC_CreateStatisticsFrame()
            end
        elseif button == "RightButton" then
            if IsControlKeyDown() then
                PSC_ToggleAchievementFrame()
            else
                PSC_CreateKillsListFrame()
            end
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddDoubleLine("PvP Stats (Classic)", "v" .. PSC_GetAddonVersion())
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff87ceebLeft-Click:|r Statistics", 1, 1, 1)
        tooltip:AddLine("|cff87ceebRight-Click:|r History", 1, 1, 1)
        tooltip:AddLine("|cff87ceebShift+Left-Click:|r Leaderboard", 1, 1, 1)
        tooltip:AddLine("|cff87ceebCtrl+Left-Click:|r Settings", 1, 1, 1)
        tooltip:AddLine("|cff87ceebCtrl+Right-Click:|r Achievements", 1, 1, 1)
    end,
})

local icon = LibStub("LibDBIcon-1.0")
local isRegistered = false

function PSC_UpdateMinimapButtonPosition()
    -- Initialize the minimap button if it hasn't been initialized yet
    if not PSC_DB.minimapButton then
        PSC_DB.minimapButton = {
            hide = false,
        }
    end

    -- If we have an old position setting, convert it
    if PSC_DB.MinimapButtonPosition and not PSC_DB.minimapButton.minimapPos then
        PSC_DB.minimapButton.minimapPos = PSC_DB.MinimapButtonPosition
    end

    -- Only register once
    if not isRegistered then
        icon:Register("PvPStatsClassic", LDB, PSC_DB.minimapButton)
        isRegistered = true
    end

    -- Show or hide based on settings
    if PSC_DB.minimapButton.hide then
        icon:Hide("PvPStatsClassic")
    else
        icon:Show("PvPStatsClassic")
    end
end
