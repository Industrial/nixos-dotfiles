--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

local activeFrame = nil
local lastPrefix = nil
local lastPhase = nil
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
            local phase = InCombatLockdown() and "combat" or "ooc"
            if prefix ~= lastPrefix or phase ~= lastPhase then
                module:PopulateTooltip()
            end
        end)
    end
    return bindingTooltip
end

-- Adds the plan's winners for this phase. A binding in neither 'friend' nor
-- 'enemy' doesn't count where a 'friend'/'enemy' binding takes the unit.
local function addWinners(active, plan, phase, reaction, skipKeys)
    local winners = plan.winners[phase]
    for _, entry in ipairs(plan.order) do
        if not (skipKeys and skipKeys[entry.key]) then
            for _, slot in ipairs(plan.entries[entry].slots) do
                local remapped = reaction and slot.remappedTypeAttrs and winners[slot.remappedTypeAttrs[reaction]]
                if winners[slot.typeAttr] == entry and (slot.unit == nil or slot.unit == reaction) and not remapped then
                    active[entry] = true
                end
            end
        end
    end
end

-- The bindings that act on `frame` now. A frame takes every click, and binds
-- its keys while hovered, so 'hovercast'/'global' only add the keys it leaves free.
local function getActiveBindings(frame, phase)
    local unit = frame:GetAttribute("unit")
    local reaction = unit and (UnitCanAttack("player", unit) and "enemy" or UnitCanAssist("player", unit) and "friend") or nil

    local active = {}
    local framePlan = addon:BuildClickPlan(false, addon.bindings)
    addWinners(active, framePlan, phase, reaction)

    local frameKeys = {}
    for _, entry in ipairs(framePlan.order) do
        frameKeys[entry.key] = true
    end
    for _, entry in ipairs(addon.bindings) do
        if entry.key and entry.key:match("BUTTON%d+$") then
            frameKeys[entry.key] = true
        end
    end
    addWinners(active, addon:BuildClickPlan(true, addon.bindings), phase, reaction, frameKeys)
    return active
end

function module:PopulateTooltip()
    local tip = self:GetBindingTooltip()
    local prefix = addon:GetPrefixString(false)
    local phase = InCombatLockdown() and "combat" or "ooc"
    lastPrefix = prefix
    lastPhase = phase

    tip:ClearLines()
    tip:AddLine(L["Clique Bindings"], 1, 1, 0)

    local sorted = {unpack(addon.bindings)}
    addon:SortBindingsByKey(sorted)
    local active = getActiveBindings(activeFrame, phase)

    local found = false
    for _, binding in ipairs(sorted) do
        if active[binding] then
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
