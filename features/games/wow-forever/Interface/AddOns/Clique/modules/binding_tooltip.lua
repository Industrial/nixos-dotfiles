--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

local activeFrame = nil
local lastPrefix = nil
local bindingTooltip = nil

local MAX_ACTION_TEXT_LEN = 25

local module = {}

function module:GetBindingTooltip()
    if not bindingTooltip then
        bindingTooltip = CreateFrame("GameTooltip", "CliqueBindingSummaryTooltip", UIParent, "GameTooltipTemplate")
        bindingTooltip:SetToplevel(true)

        bindingTooltip.throttle = 0.1
        bindingTooltip.elapsed = 0
        bindingTooltip:SetScript("OnUpdate", function(frame, elapsed)
            bindingTooltip.elapsed = bindingTooltip.elapsed + elapsed
            if bindingTooltip.elapsed < bindingTooltip.throttle then
                return
            end

            -- execute and reset elapsed timer
            bindingTooltip.elapsed = 0

            if not activeFrame then
                return
            end

            local prefix = addon:GetPrefixString(false)
            if prefix ~= lastPrefix then
                module:PopulateTooltip()
            end
        end)
    end
    return bindingTooltip
end

function module:PopulateTooltip()
    local tip = self:GetBindingTooltip()
    local prefix = addon:GetPrefixString(false)
    lastPrefix = prefix

    tip:ClearLines()
    tip:AddLine(L["Clique Bindings"], 1, 1, 0)

    local sorted = {unpack(addon.bindings)}
    addon:SortBindingsByKey(sorted)

    local found = false
    for _, binding in ipairs(sorted) do
        if binding.key and addon:IsBindingCorrectSpec(binding) then
            local keyPrefix = addon:GetPrefixStringFromBinding(binding)
            if keyPrefix == prefix then
                local keyText = addon:GetBindingKeyComboText(binding)
                local actionText = addon:GetBindingActionText(binding.type, binding)
                if #actionText > MAX_ACTION_TEXT_LEN then
                    actionText = actionText:sub(1, MAX_ACTION_TEXT_LEN - 3) .. "..."
                end
                self:AddDoubleLineLeftAligned(tip, keyText, actionText, 1, 1, 1, 0.8, 0.8, 0.8)
                found = true
            end
        end
    end

    if not found then
        tip:AddLine(L["No bindings for current modifier"], 0.6, 0.6, 0.6)
    end

    tip:Show()
end

function module:AddDoubleLineLeftAligned(tip, leftText, rightText, lr, lg, lb, rr, rg, rb)
    tip:AddDoubleLine(leftText, rightText, lr, lg, lb, rr, rg, rb)
    -- Get the rightmost string so we can change the justification
    local rightStr = _G[tip:GetName() .. "TextRight" .. tip:NumLines()]
    if rightStr then
        rightStr:SetJustifyH("LEFT")
    end
end

function addon:HookBindingTooltipFrame(frame)
    -- Skip touching the frame at all if we're not enabled; be safe!
    if not addon.settings.showBindingTooltip then return end

    frame:HookScript("OnEnter", function(f)
        if not addon.settings.showBindingTooltip then return end
        if addon:IsFrameBlacklisted(f) then return end
        activeFrame = f
        lastPrefix = nil
        local tip = module:GetBindingTooltip()
        tip:SetOwner(f, addon.settings.tooltipAnchor)
        module:PopulateTooltip()
    end)

    frame:HookScript("OnLeave", function(f)
        if activeFrame == f then
            activeFrame = nil
            lastPrefix = nil
            local tip = module:GetBindingTooltip()
            if tip:IsShown() then
                tip:Hide()
            end
        end
    end)
end
