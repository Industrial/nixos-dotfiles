--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

---@class CliqueAddon: AddonCore
local addon = select(2, ...)

-- Click-attribute records and the Plan that batches them; see docs/attributes.md.
addon.BindingAttr = {}

function addon.BindingAttr.Set(attrName, value)
    return { kind = "set", attr = attrName, value = value }
end

function addon.BindingAttr.Lookup(attrName, sourceAttr, whenTrue, whenFalse)
    return { kind = "lookup", attr = attrName, sourceAttr = sourceAttr, whenTrue = whenTrue, whenFalse = whenFalse }
end

function addon.BindingAttr.Clear(attrName)
    return { kind = "clear", attr = attrName }
end

-- checkselfcast/checkfocuscast are the only records with a non-string value
-- (a real boolean); %q can't render those, so fall back to a plain literal.
local function renderValue(value)
    if type(value) == "boolean" then
        return tostring(value)
    end
    return ("%q"):format(value)
end

local function renderRec(rec)
    if rec.kind == "lookup" then
        return ([[button:SetAttribute("%s", button:GetAttribute(%q) and %q or %q)]]):format(
            rec.attr, rec.sourceAttr, rec.whenTrue, rec.whenFalse)
    elseif rec.kind == "clear" then
        return ([[button:SetAttribute("%s", nil)]]):format(rec.attr)
    else
        return ([[button:SetAttribute("%s", %s)]]):format(rec.attr, renderValue(rec.value))
    end
end

local function renderBlock(out, recs, indent)
    for _, rec in ipairs(recs) do
        out[#out + 1] = indent .. renderRec(rec)
    end
end

local Plan = {}
Plan.__index = Plan

-- Six buckets matching GetClickAttributes' combat-phase bucketing; see docs/attributes.md.
function addon.BindingAttr.NewPlan()
    return setmetatable({
        stableSet = {}, combatSet = {}, oocSet = {},
        stableRem = {}, combatRem = {}, oocRem = {},
        -- Per-binding bookkeeping for conflict detection (core/binding_status.lua).
        entries = {}, order = {},
        -- phase -> slot type attribute -> the binding that uses the slot in that phase.
        winners = { ooc = {}, combat = {} },
    }, Plan)
end

-- bucket is one of "stableSet"/"stableRem"/"combatSet"/"combatRem"/"oocSet"/"oocRem".
-- owner is the binding a "set" record is emitted for, if any.
function Plan:Add(bucket, rec, owner)
    local list = self[bucket]
    list[#list + 1] = rec
    if owner and rec.kind ~= "clear" then
        rec.owner = owner
        rec.phase = bucket:match("^%l+")
        local sets = self.entries[owner].sets
        sets[#sets + 1] = rec
    end
end

-- slots are the binding's remapped suffixes, each { typeAttr, phase }: typeAttr
-- selects the action, phase is "stable"/"ooc"/"combat", or false when masked in both.
function Plan:Track(entry, slots)
    self.entries[entry] = { slots = slots, sets = {} }
    self.order[#self.order + 1] = entry
end

-- Render* build the snippet text that Execute()/RunFor() runs on the header.

function Plan:RenderSetup()
    local lines = {}
    renderBlock(lines, self.stableSet, "")
    -- ooc before combat: a masked binding and its ooc/combat partner share keys, so
    -- the ooc clear must run before the combat set or it wipes what we just set.
    if #self.oocSet > 0 then
        lines[#lines + 1] = "if not inCombat then"
        renderBlock(lines, self.oocSet, "  ")
        lines[#lines + 1] = "else"
        renderBlock(lines, self.oocRem, "  ")
        lines[#lines + 1] = "end"
    end
    if #self.combatSet > 0 then
        lines[#lines + 1] = "if inCombat then"
        renderBlock(lines, self.combatSet, "  ")
        lines[#lines + 1] = "end"
    end
    return lines
end

function Plan:RenderRemove()
    local lines = {}
    renderBlock(lines, self.stableRem, "")
    renderBlock(lines, self.combatRem, "")
    renderBlock(lines, self.oocRem, "")
    return lines
end

-- Replays the snippets on an empty proxy; returns attr -> the record that last set it.
-- viaTransition reaches the phase through the delta from the other phase, not a fresh setup.
function Plan:Simulate(inCombat, viaTransition)
    local attrs = {}
    local function run(recs)
        for _, rec in ipairs(recs) do
            attrs[rec.attr] = rec.kind ~= "clear" and rec or nil
        end
    end

    local setupInCombat = inCombat
    if viaTransition then
        setupInCombat = not inCombat
    end

    run(self.stableSet)
    run(setupInCombat and self.oocRem or self.oocSet)
    if setupInCombat then
        run(self.combatSet)
    end

    if viaTransition then
        if inCombat then
            run(self.oocRem)
            run(self.combatSet)
        else
            run(self.combatRem)
            run(self.oocSet)
        end
    end
    return attrs
end

-- entering=true is the ooc->combat delta, entering=false is combat->ooc.
function Plan:RenderApplyDelta(entering)
    local lines = {}
    if entering then
        renderBlock(lines, self.oocRem, "")
        renderBlock(lines, self.combatSet, "")
    else
        renderBlock(lines, self.combatRem, "")
        renderBlock(lines, self.oocSet, "")
    end
    return lines
end
