--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

---@class CliqueAddon: AddonCore
local addon = select(2, ...)

-- Finds bindings that another binding on the same key is preferred over, from
-- the same Plan the live snippets are rendered from. See docs/attributes.md.

---@alias BindingContext "frames"|"global"
---@alias BindingPhase "ooc"|"combat"
---@alias BindingUnit "friend"|"enemy"
---@alias BindingOverrideReason "same"|"spec"|"rank"|"unit"

---@class BindingOverride
---@field context BindingContext
---@field phase BindingPhase
---@field unit BindingUnit? set when only clicks on friendly or hostile units are affected
---@field by table the binding that is used instead
---@field reason BindingOverrideReason "same" is a conflict: equal priority, decided by list position

---@class BindingConflict
---@field disabled boolean true when the binding is never used
---@field multipleContexts boolean true when it applies on unit frames and to hovercast/global
---@field overrides BindingOverride[]

local PHASES = {
    { name = "ooc", inCombat = false },
    { name = "combat", inCombat = true },
}

local CONTEXTS = {
    { name = "frames", global = false },
    { name = "global", global = true },
}

local UNITS = { "friend", "enemy" }

-- A binding's own 'ooc'/'combat' bind-set limiting it to one phase isn't a conflict.
local function optsOutOf(entry, phase)
    local ooc, combat = entry.sets.ooc, entry.sets.combat
    if phase == "ooc" then
        return combat and not ooc
    end
    return ooc and not combat
end

local function overrideReason(self, global, entry, by)
    local entryPriority, byPriority = self:GetBindingPriority(global, entry), self:GetBindingPriority(global, by)
    if entryPriority == byPriority then
        return "same"
    elseif math.floor(entryPriority / 2) == math.floor(byPriority / 2) then
        return "spec"
    end
    return "rank"
end

-- Returns binding -> BindingConflict for every binding that another binding is
-- preferred over in some phase, given the current spec and settings. `bindings`
-- defaults to the saved list; the edit page passes a copy with its draft.
---@param bindings table[]?
---@return table<table, BindingConflict>
function addon:GetBindingConflicts(bindings)
    bindings = bindings or self.bindings
    local conflicts, usedSomewhere, contextCount = {}, {}, {}
    local function add(entry, override)
        local conflict = conflicts[entry] or { overrides = {} }
        conflicts[entry] = conflict
        table.insert(conflict.overrides, override)
    end

    for _, context in ipairs(CONTEXTS) do
        local plan = self:BuildClickPlan(context.global, bindings)
        for _, entry in ipairs(plan.order) do
            contextCount[entry] = (contextCount[entry] or 0) + 1
            for _, phase in ipairs(PHASES) do
                if not optsOutOf(entry, phase.name) then
                    local winners = plan.winners[phase.name]
                    for _, slot in ipairs(plan.entries[entry].slots) do
                        local winner = winners[slot.typeAttr]
                        if winner ~= entry then
                            add(entry, { context = context.name, phase = phase.name, unit = slot.unit, by = winner,
                                reason = overrideReason(self, context.global, entry, winner) })
                        else
                            -- WoW sends clicks on friendly/hostile units to a remap
                            -- first. Neutral units are rare, so losing both is unused.
                            local remapped = 0
                            for _, unit in ipairs(slot.remappedTypeAttrs and UNITS or {}) do
                                local by = winners[slot.remappedTypeAttrs[unit]]
                                if by then
                                    remapped = remapped + 1
                                    add(entry, { context = context.name, phase = phase.name, unit = unit, by = by,
                                        reason = "unit" })
                                end
                            end
                            if remapped < #UNITS then
                                usedSomewhere[entry] = true
                            end
                        end
                    end
                end
            end
        end
    end

    for entry, conflict in pairs(conflicts) do
        conflict.disabled = not usedSomewhere[entry]
        conflict.multipleContexts = contextCount[entry] > 1
    end
    return conflicts
end

-- One status per binding that isn't fully active, so every "disabled" or
-- "inactive" message in the binding list is computed and worded the same way.

local L = addon.L

---@alias BindingStatusLevel "disabled"|"warning"|"inactive"

---@class BindingStatus
---@field level BindingStatusLevel
---@field label string
---@field lines string[]
---@field footer string?

---@type table<BindingStatusLevel, string>
addon.BindingStatusColors = {
    disabled = "ffFF4800",
    warning = "ffFFD100",
    inactive = "ffA0A0A0",
}

local PREFERRED_LINES = {
    same = L["%s has the same priority and is used."],
    [""] = L["%s is preferred."],
    spec = L["In this specialization, %s is preferred."],
    ooc = L["Out of combat, %s is preferred."],
    combat = L["In combat, %s is preferred."],
    friend = L["On friendly units, %s is preferred."],
    enemy = L["On hostile units, %s is preferred."],
    ooc_friend = L["Out of combat, on friendly units, %s is preferred."],
    ooc_enemy = L["Out of combat, on hostile units, %s is preferred."],
    combat_friend = L["In combat, on friendly units, %s is preferred."],
    combat_enemy = L["In combat, on hostile units, %s is preferred."],
}

-- The same conditions, worded for the binding that is preferred.
local PREFERRED_OVER_LINES = {
    same = L["%s has the same priority, and this binding is used."],
    [""] = L["This binding is preferred over %s."],
    spec = L["In this specialization, this binding is preferred over %s."],
    ooc = L["Out of combat, this binding is preferred over %s."],
    combat = L["In combat, this binding is preferred over %s."],
    friend = L["On friendly units, this binding is preferred over %s."],
    enemy = L["On hostile units, this binding is preferred over %s."],
    ooc_friend = L["Out of combat, on friendly units, this binding is preferred over %s."],
    ooc_enemy = L["Out of combat, on hostile units, this binding is preferred over %s."],
    combat_friend = L["In combat, on friendly units, this binding is preferred over %s."],
    combat_enemy = L["In combat, on hostile units, this binding is preferred over %s."],
}

local function describeBinding(bind)
    return ("%s (%s)"):format(addon:GetBindingActionText(bind.type, bind), addon:GetBindSetsDisplayText(bind))
end

local function activePhaseCount(entry)
    local count = 0
    for _, phase in ipairs(PHASES) do
        if not optsOutOf(entry, phase.name) then
            count = count + 1
        end
    end
    return count
end

-- One group per binding and unit, with the phases it is preferred in.
local function groupOverrides(conflict, contextName, by)
    local groups, order = {}, {}
    for _, override in ipairs(conflict.overrides) do
        if override.context == contextName and (not by or override.by == by) then
            local unit = override.unit or ""
            groups[override.by] = groups[override.by] or {}
            local group = groups[override.by][unit]
            if not group then
                group = { override = override, phases = {}, count = 0 }
                groups[override.by][unit] = group
                order[#order + 1] = group
            end
            if not group.phases[override.phase] then
                group.phases[override.phase] = true
                group.count = group.count + 1
            end
        end
    end
    return order
end

-- `phase` is nil when the override covers every phase the binding is active in.
local function overrideLine(texts, override, phase, other)
    if override.reason == "same" then
        return texts.same:format(describeBinding(other))
    end
    local condition
    if phase and override.unit then
        condition = phase .. "_" .. override.unit
    else
        condition = phase or override.unit or (override.reason == "spec" and "spec") or ""
    end
    return texts[condition]:format(describeBinding(other))
end

-- With `by`, only its overrides are described, and the lines name `entry`.
local function addOverrideLines(lines, seen, texts, entry, conflict, by)
    local activePhases = activePhaseCount(entry)
    for _, context in ipairs(CONTEXTS) do
        for _, group in ipairs(groupOverrides(conflict, context.name, by)) do
            local phase = group.count < activePhases and group.override.phase or nil
            local line = overrideLine(texts, group.override, phase, by and entry or group.override.by)
            if conflict.multipleContexts then
                line = context.global and L["Game world: %s"]:format(line) or L["Unit frames: %s"]:format(line)
            end
            if not seen[line] then
                seen[line] = true
                lines[#lines + 1] = line
            end
        end
    end
end

---@param conflict BindingConflict
---@return BindingStatus
local function conflictStatus(entry, conflict)
    local lines = {}
    addOverrideLines(lines, {}, PREFERRED_LINES, entry, conflict)
    local tied = false
    for _, override in ipairs(conflict.overrides) do
        if override.reason == "same" then
            tied = true
        end
    end

    local footer = L["On the same key, the binding with more specific bind-sets is preferred."]
    if tied then
        footer = L["Change the key or the bind-sets of one of these bindings."]
        -- A binding that still works somewhere is only partly masked, tie or not.
        if conflict.disabled then
            return { level = "disabled", label = L["Conflict - another binding has the same key and bind-sets"],
                lines = lines, footer = footer }
        end
    elseif conflict.disabled then
        return { level = "warning", label = L["Not used - a more specific binding is preferred"], lines = lines, footer = footer }
    end
    return { level = "warning", label = L["Partly used - a more specific binding is preferred"], lines = lines, footer = footer }
end

---@param status BindingStatus
---@return string
function addon:GetBindingStatusLabel(status)
    return ("|c%s%s|r"):format(self.BindingStatusColors[status.level], status.label)
end

-- Returns binding -> BindingStatus for every binding that isn't fully active.
---@param bindings table[]? defaults to the saved list
---@return table<table, BindingStatus>
function addon:GetBindingStatuses(bindings)
    bindings = bindings or self.bindings
    local statuses = {}
    local conflicts
    for _, entry in ipairs(bindings) do
        if type(entry.sets) ~= "table" then
            statuses[entry] = { level = "disabled", label = L["Disabled - invalid binding"],
                lines = { L["This binding is invalid. Delete it."] } }
        elseif not next(entry.sets) then
            statuses[entry] = { level = "disabled", label = L["Disabled - not in any bind-set"],
                lines = { L["A binding is only active when it is in at least one bind-set. Edit the binding and select a bind-set."] } }
        elseif entry.type == "macro" and not self:BindingHasAction(entry) then
            statuses[entry] = { level = "disabled", label = L["Disabled - the macro is empty"],
                lines = { L["A custom macro is only active when it has text. Edit the binding and write the macro."] } }
        elseif self:IsGamePadBinding(entry) and not self:IsGamePadEnabled() then
            statuses[entry] = { level = "disabled", label = L["Disabled - gamepad not enabled"],
                lines = { L["Gamepad bindings are only active when 'Enable GamePad binding support' is selected in the General Options."] } }
        elseif not self:IsBindingCorrectSpec(entry) then
            statuses[entry] = { level = "inactive", label = L["Inactive - not for this specialization"],
                lines = { L["This binding is only active in a different specialization."] } }
        else
            conflicts = conflicts or self:GetBindingConflicts(bindings)
            if conflicts[entry] then
                statuses[entry] = conflictStatus(entry, conflicts[entry])
            end
        end
    end
    return statuses
end

-- The lines for the bindings in `bindings` that `winner` is preferred over.
---@param bindings table[]
---@param winner table
---@return string[]
function addon:GetPreferredOverLines(bindings, winner)
    local conflicts = self:GetBindingConflicts(bindings)
    local lines, seen = {}, {}
    for _, entry in ipairs(bindings) do
        if entry ~= winner and conflicts[entry] then
            addOverrideLines(lines, seen, PREFERRED_OVER_LINES, entry, conflicts[entry], winner)
        end
    end
    return lines
end
