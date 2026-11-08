--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

---@class CliqueAddon: AddonCore
local addon = select(2, ...)

-- Maps a binding's saved bind-sets onto the edit page's controls (Where,
-- Units, When, Specialization) and back. The saved format does not change;
-- combinations the controls can't express are converted, see docs/bindings.md.

---@alias BindSetWhere "frames"|"anyunit"|"anywhere"|"disabled"
---@alias BindSetUnits "all"|"friend"|"enemy"
---@alias BindSetWhen "always"|"ooc"|"combat"

---@class BindSetChoices
---@field where BindSetWhere
---@field units BindSetUnits
---@field when BindSetWhen
---@field specs table<number, boolean> selected specs; empty means every spec
---@field extra table<string, boolean> spec bind-sets this class doesn't have, kept as-is

local MAX_SPEC_SETS = 5

---@param sets table<string, boolean>
---@param numSpecs number
---@return BindSetChoices
function addon:GetBindSetChoices(sets, numSpecs)
    local choices = { where = "frames", units = "all", when = "always", specs = {}, extra = {} }

    if not next(sets) then
        choices.where = "disabled"
        return choices
    end

    if sets.hovercast then
        choices.where = "anyunit"
    elseif sets.global then
        choices.where = "anywhere"
    end

    -- 'friend'+'enemy' is almost the same as neither, so it becomes "All"
    if choices.where ~= "anywhere" then
        if sets.friend and not sets.enemy then
            choices.units = "friend"
        elseif sets.enemy and not sets.friend then
            choices.units = "enemy"
        end
    end

    if sets.ooc and not sets.combat then
        choices.when = "ooc"
    elseif sets.combat and not sets.ooc then
        choices.when = "combat"
    end

    -- Without more than one spec there is no spec control; keep spec sets untouched
    local selected = 0
    for idx = 1, MAX_SPEC_SETS do
        local key = "spec" .. idx
        if sets[key] then
            if numSpecs > 1 and idx <= numSpecs then
                choices.specs[idx] = true
                selected = selected + 1
            else
                choices.extra[key] = true
            end
        end
    end

    -- Every spec of the class works like "All", but with a higher priority
    if numSpecs > 1 and selected == numSpecs then
        choices.specs = {}
    end

    return choices
end

---@param choices BindSetChoices
---@return table<string, boolean>
function addon:GetBindSetsFromChoices(choices)
    local sets = {}
    if choices.where == "disabled" then
        return sets
    end

    if choices.where == "frames" then
        sets.default = true
    elseif choices.where == "anyunit" then
        sets.hovercast = true
    elseif choices.where == "anywhere" then
        sets.global = true
    end

    if choices.where ~= "anywhere" and (choices.units == "friend" or choices.units == "enemy") then
        sets[choices.units] = true
    end

    if choices.when == "ooc" or choices.when == "combat" then
        sets[choices.when] = true
    end

    for idx in pairs(choices.specs) do
        sets["spec" .. idx] = true
    end
    for key in pairs(choices.extra) do
        sets[key] = true
    end

    return sets
end

---@param a table<string, boolean>
---@param b table<string, boolean>
function addon:BindSetsEqual(a, b)
    for k, v in pairs(a) do
        if b[k] ~= v then return false end
    end
    for k, v in pairs(b) do
        if a[k] ~= v then return false end
    end
    return true
end

local L = addon.L

local WHERE_TEXT = {
    frames = L["Unit frames"],
    anyunit = L["Any unit under the mouse"],
    anywhere = L["Anywhere"],
    disabled = L["Disabled"],
}
local UNITS_TEXT = { all = L["All"], friend = L["Friendly"], enemy = L["Hostile"] }
local WHEN_TEXT = { always = L["Always"], ooc = L["Out of combat"], combat = L["In combat"] }

addon.BindSetChoiceText = { where = WHERE_TEXT, units = UNITS_TEXT, when = WHEN_TEXT }

---@param choices BindSetChoices
---@param numSpecs number
---@return string text e.g. "Unit frames · Friendly · In combat"
function addon:DescribeBindSetChoices(choices, numSpecs)
    if choices.where == "disabled" then
        return WHERE_TEXT.disabled
    end

    local parts = { WHERE_TEXT[choices.where] }
    if choices.where ~= "anywhere" and choices.units ~= "all" then
        parts[#parts + 1] = UNITS_TEXT[choices.units]
    end
    if choices.when ~= "always" then
        parts[#parts + 1] = WHEN_TEXT[choices.when]
    end

    local specs = {}
    for idx = 1, numSpecs do
        if choices.specs[idx] then
            specs[#specs + 1] = self:GetTalentSpecName(idx) or L["Spec %d"]:format(idx)
        end
    end
    for key in pairs(choices.extra) do
        specs[#specs + 1] = key
    end
    if #specs > 0 then
        table.sort(specs)
        parts[#parts + 1] = table.concat(specs, "/")
    end

    return table.concat(parts, " · ")
end

-- Whether the edit page's controls show these bind-sets exactly. A missing
-- 'default' is not a difference: such bindings already apply on unit frames,
-- at the same priority.
---@param sets table<string, boolean>
---@param numSpecs number
---@return boolean
function addon:BindSetsFitChoices(sets, numSpecs)
    if not (sets.default or sets.hovercast or sets.global) and next(sets) then
        local withDefault = { default = true }
        for key, value in pairs(sets) do
            withDefault[key] = value
        end
        sets = withDefault
    end
    return self:BindSetsEqual(sets, self:GetBindSetsFromChoices(self:GetBindSetChoices(sets, numSpecs)))
end

-- The summary of a binding's bind-sets. Bind-sets the controls can't show
-- keep their raw names, so the player can see which bindings to fix.
---@return string
function addon:GetBindSetsDisplayText(binding)
    if not (type(binding) == "table" and type(binding.sets) == "table" and next(binding.sets)) then
        return self:GetBindingInfoText(binding)
    end

    local numSpecs = self:GetNumTalentSpecs()
    if not self:BindSetsFitChoices(binding.sets, numSpecs) then
        return self:GetBindingInfoText(binding)
    end
    return self:DescribeBindSetChoices(self:GetBindSetChoices(binding.sets, numSpecs), numSpecs)
end
