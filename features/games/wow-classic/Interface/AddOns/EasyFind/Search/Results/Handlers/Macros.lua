local _, ns = ...

local Handlers = ns.ResultHandlers
local Utils = ns.Utils

function Handlers:OpenMacroFrameAt(macroIdx, isChar)
    if C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_MacroUI")
    elseif LoadAddOn then
        LoadAddOn("Blizzard_MacroUI")
    end
    if ShowMacroFrame then ShowMacroFrame() end
    local tabIdx = isChar and 2 or 1
    local slotInTab = isChar
        and (macroIdx - (MAX_ACCOUNT_MACROS or 120))
        or macroIdx
    local function clickSlot()
        local mf = MacroFrame
        if not mf or not mf:IsShown() then return false end
        local tabBtn = _G["MacroFrameTab" .. tabIdx]
        if tabBtn and tabBtn.Click and (mf.selectedTab or 1) ~= tabIdx then
            tabBtn:Click()
        end
        local sb = mf.MacroSelector and mf.MacroSelector.ScrollBox
        if not sb or not sb.ForEachFrame then return false end
        if sb.ScrollToElementDataIndex then
            sb:ScrollToElementDataIndex(slotInTab)
        end
        local clicked = false
        sb:ForEachFrame(function(btn)
            if clicked then return true end
            local ed = btn.GetElementData and btn:GetElementData()
            if ed == slotInTab then
                if btn.Click then btn:Click() end
                clicked = true
                return true
            end
        end)
        return clicked
    end
    if not clickSlot() then
        Utils.SafeAfter(0, function()
            if not clickSlot() then
                Utils.SafeAfter(0.1, function()
                    if not clickSlot() then
                        Utils.SafeAfter(0.3, clickSlot)
                    end
                end)
            end
        end)
    end
end
