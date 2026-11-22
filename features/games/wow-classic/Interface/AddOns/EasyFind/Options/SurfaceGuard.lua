local _, ns = ...

local OptionsSurface = ns.OptionsSurface
local Utils = ns.Utils

local function HasMouseFocus(frame)
    if not frame or not frame:IsShown() then return false end
    return Utils.MouseFocusOwnedBy(frame)
end

local function IsInside(frame)
    return Utils.IsFrameOrChildMouseOver(frame) or HasMouseFocus(frame)
end

function OptionsSurface:IsOptionsSurfaceMouseOver()
    local frame = ns.optionsFrame
    if IsInside(frame) then return true end
    if not frame then return false end

    local guards = {
        frame.indicatorFlyout,
        frame.colorFlyout,
        frame.fontFlyout,
        frame.mapTabGroup and frame.mapTabGroup.flyout,
        frame.mapPinGroup and frame.mapPinGroup.flyout,
        frame.automationGroup and frame.automationGroup.flyout,
    }
    for i = 1, #guards do
        if IsInside(guards[i]) then return true end
    end
    return false
end
