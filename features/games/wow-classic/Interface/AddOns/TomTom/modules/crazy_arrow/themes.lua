--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

local addonName, addon = ...

local handler = {
    themes = {},
    active = nil,
    recent = nil,
    activeKey = nil,
}

addon.CrazyArrowThemeHandler = handler

-- Matches the arrow.theme default in TomTom:Initialize. An unknown key can
-- come from an old or shared profile.
local DEFAULT_THEME_KEY = "modern"

function handler:RegisterCrazyArrowTheme(key, name, themeTbl)
    self.themes[key] = {name = name, tbl = themeTbl}
end

function handler:GetActiveTheme()
    return self.activeKey
end

function handler:SetActiveTheme(button, key, arrival)
    if not self.themes[key] then
        key = DEFAULT_THEME_KEY
    end

    if self.activeKey == key then
        -- Do nothing
        return
    end

    if self.activeKey then
        -- If there was a previous theme selected, unload the current one
        self.active.tbl:RemoveTheme(button)
    end

    self.activeKey = key
    self.active = self.themes[key]
    self.active.tbl:ApplyTheme(button)

    if arrival then
        self:SwitchToArrivalArrow(button)
    end
    addon:FireMessage("TOMTOM_ARROW_THEME_CHANGED", key)
end

function handler:CrazyArrow_RemoveTheme(button)
    self.active.tbl:RemoveTheme(button)
end

function handler:SwitchToArrivalArrow(button)
    if self.active and self.active.tbl then
        self.active.tbl:SwitchToArrivalArrow(button)
    end
end

function handler:ArrivalArrow_OnUpdate(elapsed)
    if self.active and self.active.tbl then
        self.active.tbl:ArrivalArrow_OnUpdate(elapsed)
    end
end

function handler:SwitchToNavigationArrow(button)
    if self.active and self.active.tbl then
        self.active.tbl:SwitchToNavigationArrow(button)
    end
end

function handler:NavigationArrow_OnUpdate(elapsed, angle)
    if self.active and self.active.tbl then
        self.active.tbl:NavigationArrow_OnUpdate(elapsed, angle)
    end
end

function handler:SetDirection(angle)
    if self.active and self.active.tbl then
        self.active.tbl:SetDirection(angle)
    end
end

function handler:SetColor(r, g, b, a)
    if self.active and self.active.tbl then
        self.active.tbl:SetColor(r, g, b, a)
    end
end

-- Resets every theme, not only the active one. If the user changes the theme
-- during a hijack, the old texture keeps the hijack color. The modern themes
-- never set a color themselves, so that color would stay.
function handler:ResetColor()
    for _, entry in pairs(self.themes) do
        if entry.tbl.arrowTexture then
            entry.tbl.arrowTexture:SetVertexColor(1, 1, 1, 1)
        end
    end
end
