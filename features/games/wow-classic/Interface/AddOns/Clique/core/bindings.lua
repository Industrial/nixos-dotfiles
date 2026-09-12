--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

---@class CliqueAddon: AddonCore
local addon = select(2, ...)

local function bindingeq(a, b)
    assert(type(a) == "table", "Error during comparison")
    assert(type(b) == "table", "Error during comparison")

    if a.type ~= b.type then
        return false
    elseif a.type == "target" then
        return a.key == b.key
    elseif a.type == "menu" then
        return a.key == b.key
    elseif a.type == "spell" then
        return a.spell == b.spell and a.key == b.key and a.spellSubName == b.spellSubName
    elseif a.type == "macro" then
        return a.macrotext == b.macrotext and a.key == b.key
    elseif a.type == "item" then
        return a.item == b.item and a.key == b.key
    end

    return false
end

local allSpecSets = {"spec1", "spec2", "spec3", "spec4", "spec5"}

function addon:IsBindingCorrectSpec(entry)
    -- Check to ensure we're on the right spec for this binding
    local currentSpec = self:GetActiveTalentSpec()
    if currentSpec and entry.sets["spec" .. tostring(currentSpec)] then
        return true
    end

    -- If there are any spec sets at all, then fail this
    for _, specKey in ipairs(allSpecSets) do
        if entry.sets[specKey] then
            return false
        end
    end

    return true
end

-- This function adds a binding to the player's current profile. The
-- following options can be included in the click-cast entry:
--
-- entry = {
--     -- The full prefix and suffix of the key being bound
--     key = "ALT-CTRL-SHIFT-BUTTON1",
--     -- The icon to be used for displaying this entry
--     icon = "Interface\\Icons\\Spell_Nature_HealingTouch",
--
--     -- Any restricted sets that this click should be applied to
--     sets = {"ooc", "harm", "help", "frames_blizzard"},
--
--     -- The type of the click-binding
--     type = "spell",
--     type = "macro",
--     type = "target",
--     type = "menu",
--
--     -- Any arguments for given click type
--     spell = "Healing Touch",
--     macrotext = "/run Nature's Swiftness\n/cast [target=mouseover] Healing Touch",
--     unit = "mouseover",
-- }
function addon:AddBinding(entry)
    -- TODO: Check to see if the new binding conflicts with an existing binding
    -- TODO: Validate the entry to ensure it has the correct arguments, etc.

    if not entry.sets then
        entry.sets = {default = true}
    end

    table.insert(self.bindings, entry)
    self:FireMessage("BINDINGS_CHANGED")
end

function addon:DeleteBinding(entry)
    -- Look for an entry that matches the given binding and remove it
    for idx, bind in ipairs(self.bindings) do
        if bindingeq(entry, bind) then
            -- Found the entry that matches, so remove it
            table.remove(self.bindings, idx)
            break
        end
    end

    self:FireMessage("BINDINGS_CHANGED")
end

-- Handler function for message indicating that a change as occurred
-- with the configured bindings. This is the only place that the
-- bindings should be re-computed. If this handler is called during
-- combat than execution should be deferred until the user exits
-- combat.
function addon:BINDINGS_CHANGED()
    if InCombatLockdown() then
        self:Defer("BINDINGS_CHANGED")
        return
    end

    -- Clear any existing attributes
    self:ClearAttributes()

    -- Very simple optimisation. If the player has no 'ooc' bindings
    -- set, then attributes can be applied once and then only updated
    -- when the bindings list is changed.
    local has_ooc = false
    for idx, entry in ipairs(self.bindings) do
        if entry.sets.ooc then
             has_ooc = true
            break
        end
    end

    self.has_ooc = has_ooc

    -- Update all click/binding attributes
    self:UpdateAttributes()

    -- Update the actual attributes on all frames
    self:ApplyAttributes()
end


