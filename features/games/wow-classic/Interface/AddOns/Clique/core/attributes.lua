--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

---@class CliqueAddon: AddonCore
local addon = select(2, ...)

function addon:ShouldRemoveSelfCast()
    return false
end

-- Records built via addon.BindingAttr (core/binding_attributes.lua); a Plan
-- renders them into the snippet text. See docs/attributes.md.
local BindingAttr = addon.BindingAttr

local B_SET = [[self:SetBindingClick(true, %q, clickableButton, %q);]]
local B_CLR = [[self:ClearBinding(%q);]]

local SPEC_SETS = { "spec1", "spec2", "spec3", "spec4", "spec5" }

local function hasSpecSet(entry)
    for _, set in ipairs(SPEC_SETS) do
        if entry.sets[set] then
            return true
        end
    end
    return false
end

-- A new 'Run custom macro' binding has no text until the player writes some
---@return boolean
function addon:BindingHasAction(entry)
    if entry.type == "macro" then
        return entry.macro ~= nil or (type(entry.macrotext) == "string" and entry.macrotext:match("%S") ~= nil)
    end
    return entry.type ~= nil
end

local function shouldApply(global, entry)
    if not addon:BindingHasAction(entry) then
        return false
    end

    -- Filter out gamepad bindings when the gamepad option is disabled
    if addon:IsGamePadBinding(entry) and not addon:IsGamePadEnabled() then
        return false
    end

    -- If this is the global button and this is a 'global' binding
    if global and (entry.sets.hovercast or entry.sets.global) then
        return true
    elseif not global then
        for k in pairs(entry.sets) do
            if k ~= "global" and k ~= "hovercast" then
                return true
            end
        end
        -- The frame takes every click, so 'hovercast'/'global' clicks would never reach
        -- globutton; apply them here at the lowest priority. See docs/bindings.md.
        local isClick = addon:GetMouseButtonNumber(entry) ~= nil
        local isPlainLeftRight = entry.key == "BUTTON1" or entry.key == "BUTTON2"
        local appliesOnFrames = entry.sets.hovercast or (entry.sets.global and isClick)
        return appliesOnFrames == true and not isPlainLeftRight
    end
end

-- The type/clickbutton attribute pairs that route each click combo we bind to the
-- proxy. A frame's own specific attribute (e.g. shift-type2="togglemenu") outranks
-- our *type* wildcard, so we stamp the specific attributes too. Keyboard bindings
-- route via SetBindingClick and are excluded.
function addon:GetClickRoutingCombos()
    local combos, seen = {}, {}
    for _, entry in ipairs(self.bindings) do
        if entry.key and shouldApply(false, entry) and self:IsBindingCorrectSpec(entry)
                and self:GetMouseButtonNumber(entry) then
            local typeName = self:AttributeFromEntry(entry, "type")
            if not seen[typeName] then
                seen[typeName] = true
                combos[#combos + 1] = {
                    type = typeName,
                    click = self:AttributeFromEntry(entry, "clickbutton"),
                    -- Macrotext-dispatch fields (unused by click mode):
                    macro = self:AttributeFromEntry(entry, "macrotext"),
                    button = self:GetMouseButtonName(self:GetMouseButtonNumber(entry)),
                }
            end
        end
    end
    return combos
end

-- Emits the action attributes for one binding on one (remapped) suffix.
local function emitBindingAction(self, entry, prefix, suffix, emitSet, emitRem)
    if entry.type == "target" then
        emitSet(BindingAttr.Set(addon:AttributeName(prefix, "type", suffix), "target"))
        emitRem(BindingAttr.Clear(addon:AttributeName(prefix, "type", suffix)))
    elseif entry.type == "menu" then
        if self:ProjectIsClassic() then
            -- Classic Era resolves "menu" via SecureActionButton_OnClick's
            -- rawget(self, "menu") fallback; use it when forwarded, else togglemenu.
            emitSet(BindingAttr.Lookup(addon:AttributeName(prefix, "type", suffix), "clique-has-menu-attribute", "menu", "togglemenu"))
        else
            emitSet(BindingAttr.Set(addon:AttributeName(prefix, "type", suffix), "togglemenu"))
        end
        emitRem(BindingAttr.Clear(addon:AttributeName(prefix, "type", suffix)))
    elseif entry.type == "spell" and self.settings.stopcastingfix then
        -- Implement the 'stop casting' fix
        local macrotext
        local spellText = self:SpellTextWithSubName(entry)
        if entry.sets.global then
            -- Do not include @mouseover
            macrotext = string.format("/click %s\n/cast %s", self.stopbutton.name, spellText)
        else
            macrotext = string.format("/click %s\n/cast [@mouseover] %s", self.stopbutton.name, spellText)
        end
        emitSet(BindingAttr.Set(addon:AttributeName(prefix, "type", suffix), "macro"))
        emitSet(BindingAttr.Set(addon:AttributeName(prefix, "macrotext", suffix), macrotext))
        emitRem(BindingAttr.Clear(addon:AttributeName(prefix, "type", suffix)))
        emitRem(BindingAttr.Clear(addon:AttributeName(prefix, "macrotext", suffix)))
    elseif entry.type == "spell" then
        local spellText = self:SpellTextWithSubName(entry)
        emitSet(BindingAttr.Set(addon:AttributeName(prefix, "type", suffix), entry.type))
        emitSet(BindingAttr.Set(addon:AttributeName(prefix, "spell", suffix), spellText))
        emitRem(BindingAttr.Clear(addon:AttributeName(prefix, "type", suffix)))
        emitRem(BindingAttr.Clear(addon:AttributeName(prefix, "spell", suffix)))
    -- Macros aren't available on The War Within and above
    elseif entry.type == "macro" and self.settings.stopcastingfix and entry.macrotext then
        local macrotext = string.format("/click %s\n%s", self.stopbutton.name, entry.macrotext)
        emitSet(BindingAttr.Set(addon:AttributeName(prefix, "type", suffix), entry.type))
        emitSet(BindingAttr.Set(addon:AttributeName(prefix, "macrotext", suffix), macrotext))
        emitRem(BindingAttr.Clear(addon:AttributeName(prefix, "type", suffix)))
        emitRem(BindingAttr.Clear(addon:AttributeName(prefix, "macrotext", suffix)))
    -- Macros aren't available on The War Within and above
    elseif entry.type == "macro" and entry.macrotext then
        emitSet(BindingAttr.Set(addon:AttributeName(prefix, "type", suffix), entry.type))
        emitSet(BindingAttr.Set(addon:AttributeName(prefix, "macrotext", suffix), entry.macrotext))
        emitRem(BindingAttr.Clear(addon:AttributeName(prefix, "type", suffix)))
        emitRem(BindingAttr.Clear(addon:AttributeName(prefix, "macrotext", suffix)))
    elseif entry.type == "macro" and entry.macro then
        emitSet(BindingAttr.Set(addon:AttributeName(prefix, "type", suffix), entry.type))
        emitSet(BindingAttr.Set(addon:AttributeName(prefix, "macro", suffix), entry.macro))
        emitRem(BindingAttr.Clear(addon:AttributeName(prefix, "type", suffix)))
        emitRem(BindingAttr.Clear(addon:AttributeName(prefix, "macro", suffix)))
    elseif entry.type == "item" then
        emitSet(BindingAttr.Set(addon:AttributeName(prefix, "type", suffix), entry.type))
        emitSet(BindingAttr.Set(addon:AttributeName(prefix, "item", suffix), entry.item))
        emitRem(BindingAttr.Clear(addon:AttributeName(prefix, "type", suffix)))
        emitRem(BindingAttr.Clear(addon:AttributeName(prefix, "item", suffix)))
    else
        error(string.format("Invalid action type: '%s'", tostring(entry.type)))
    end
end

-- This function takes a single argument indicating if the attributes being
-- computed are for the special 'global' button used by Clique.  It then
-- computes the set of attributes necessary for the player's bindings to be
-- active on all the appropriate frames. The logic here is quite delicate but
-- also rather well commented.
function addon:GetClickAttributes(global)
    -- In these scripts, 'self' should always be the header.
    local preamble = {
        "local inCombat = control:GetAttribute('inCombat')",
        "local setupbutton = self:GetFrameRef('cliquesetup_button')",
        "local button = setupbutton or self",
    }

    -- The delta snippets are unconditional, so they don't read inCombat.
    local deltaPreamble = {
        "local setupbutton = self:GetFrameRef('cliquesetup_button')",
        "local button = setupbutton or self",
    }

    -- Check to see if the frame being setup is blacklisted. Do not perform
    -- this check on the global frame.
    if not global then
        local guard = {"local name = button:GetName()", "if blacklist[name] then return end"}
        for _, line in ipairs(guard) do
            preamble[#preamble + 1] = line
            deltaPreamble[#deltaPreamble + 1] = line
        end
    end

    local plan = self:BuildClickPlan(global, self.bindings)

    -- preamble/deltaPreamble are fixed control-flow lines; the Plan renders the
    -- per-entry lines.
    local function emitBlock(out, lines, indent)
        for _, line in ipairs(lines) do
            out[#out + 1] = indent .. line
        end
    end

    local setup = {}
    emitBlock(setup, preamble, "")
    emitBlock(setup, plan:RenderSetup(), "")

    local remove = {}
    emitBlock(remove, preamble, "")
    emitBlock(remove, plan:RenderRemove(), "")

    local applyCombat = {}  -- out-of-combat -> combat: clear ooc keys, then set masking
    emitBlock(applyCombat, deltaPreamble, "")
    emitBlock(applyCombat, plan:RenderApplyDelta(true), "")

    local applyOoc = {}     -- combat -> out-of-combat: clear masking keys, then set ooc
    emitBlock(applyOoc, deltaPreamble, "")
    emitBlock(applyOoc, plan:RenderApplyDelta(false), "")

    return table.concat(setup, "\n"), table.concat(remove, "\n"),
           table.concat(applyCombat, "\n"), table.concat(applyOoc, "\n")
end

-- Rules 1-3 of "Bindings on the same key" (docs/bindings.md), one bit each, so
-- the first difference decides; equal priorities fall back to list position.
---@return number
function addon:GetBindingPriority(global, entry)
    local sets = entry.sets
    local worldOnly = not global and (sets.hovercast or sets.global) and not sets.default
    return (worldOnly and 0 or 4) + ((sets.ooc or sets.combat) and 2 or 0) + (hasSpecSet(entry) and 1 or 0)
end

-- Builds the attribute Plan for `bindings`; their order is the saved list order,
-- which decides between two same-key bindings of the same priority.
function addon:BuildClickPlan(global, bindings)
    -- Bindings are bucketed by combat phase so only the keys that change across
    -- the boundary go in the delta snippets. See docs/architecture.md.
    local plan = BindingAttr.NewPlan()

    ---@type "stable"|"ooc"|"combat"|false|nil
    local phase
    local owner
    local function emitSet(rec)
        plan:Add(phase == "combat" and "combatSet" or phase == "ooc" and "oocSet" or "stableSet", rec, owner)
    end
    local function emitRem(rec)
        plan:Add(phase == "combat" and "combatRem" or phase == "ooc" and "oocRem" or "stableRem", rec)
    end

    if self:ShouldRemoveSelfCast() then
        plan:Add("stableSet", BindingAttr.Set("checkselfcast", false))
        plan:Add("stableSet", BindingAttr.Set("checkfocuscast", false))
    end

    -- A 'friend' or 'enemy' binding remaps the click to its own suffix, via
    -- helpbutton/harmbutton; a binding in both bind-sets needs both remaps. Each
    -- resulting slot is named by its type attribute, which is what bindings compete for.
    local function slotsFor(entry)
        local prefix, suffix = self:GetBindingPrefixSuffix(entry, global)
        local slots = {}
        if entry.sets.friend then
            slots[#slots + 1] = { remap = "helpbutton", unit = "friend", actionSuffix = "friend" .. suffix }
        end
        if entry.sets.enemy then
            slots[#slots + 1] = { remap = "harmbutton", unit = "enemy", actionSuffix = "enemy" .. suffix }
        end
        if #slots == 0 then
            -- WoW sends a click on a friendly/hostile unit to these slots instead.
            slots[1] = { actionSuffix = suffix, remappedTypeAttrs = {
                friend = addon:AttributeName(prefix, "type", "friend" .. suffix),
                enemy = addon:AttributeName(prefix, "type", "enemy" .. suffix),
            } }
        end
        for _, slot in ipairs(slots) do
            slot.typeAttr = addon:AttributeName(prefix, "type", slot.actionSuffix)
        end
        return prefix, suffix, slots
    end

    local applicable = {}
    for _, entry in ipairs(bindings) do
        if shouldApply(global, entry) and self:IsBindingCorrectSpec(entry) and entry.key then
            local prefix, suffix, slots = slotsFor(entry)
            applicable[#applicable + 1] = { entry = entry, prefix = prefix, suffix = suffix, slots = slots }
        end
    end

    local position = {}
    for idx, entry in ipairs(bindings) do
        position[entry] = idx
    end

    -- Whether `a` is preferred over `b` on the same slot; see "Bindings on the same
    -- key" in docs/bindings.md. 'friend'/'enemy' aren't compared: they use their own slots.
    local function preferred(a, b)
        local aPriority, bPriority = self:GetBindingPriority(global, a), self:GetBindingPriority(global, b)
        if aPriority ~= bPriority then
            return aPriority > bPriority
        end
        return position[a] > position[b]
    end

    -- The binding that uses each slot in each phase. Masking is per slot, not per
    -- key, so a 'combat'+'friend' binding leaves a same-key 'enemy' binding alone.
    local winners = plan.winners
    for _, item in ipairs(applicable) do
        local entry = item.entry
        local ooc, combat = entry.sets.ooc, entry.sets.combat
        for _, slot in ipairs(item.slots) do
            for phaseName, phaseWinners in pairs(winners) do
                local excluded = (phaseName == "ooc" and combat and not ooc)
                    or (phaseName == "combat" and ooc and not combat)
                local current = phaseWinners[slot.typeAttr]
                if not excluded and (not current or preferred(entry, current)) then
                    phaseWinners[slot.typeAttr] = entry
                end
            end
        end
    end

    -- false: the binding doesn't use the slot in either phase.
    local function phaseFor(entry, typeAttr)
        local ooc = winners.ooc[typeAttr] == entry
        local combat = winners.combat[typeAttr] == entry
        if ooc and combat then
            return "stable"
        elseif ooc then
            return "ooc"
        elseif combat then
            return "combat"
        end
        return false
    end

    -- On the global button, bindings in different slots can need the same 'unit'
    -- attribute in different phases. One owner-less record per attribute, in every
    -- phase any binding needs it, so a phase change can't clear it from under another.
    local unitPhases, unitOrder = {}, {}
    local function needUnit(attr, slotPhase)
        local current = unitPhases[attr]
        if current == nil then
            unitOrder[#unitOrder + 1] = attr
            unitPhases[attr] = slotPhase
        elseif current ~= slotPhase then
            unitPhases[attr] = "stable"
        end
    end

    for _, item in ipairs(applicable) do
        local entry, prefix, suffix = item.entry, item.prefix, item.suffix
        owner = entry

        for _, slot in ipairs(item.slots) do
            slot.phase = phaseFor(entry, slot.typeAttr)
        end
        plan:Track(entry, item.slots)

        for _, slot in ipairs(item.slots) do
            phase = slot.phase
            if phase then
                if global then
                    -- A remapped binding needs the unmodified 'unit' for the
                    -- friend/enemy lookup; hovercast also targets the mouseover.
                    if slot.remap then
                        needUnit(addon:AttributeName(prefix, "unit", suffix), phase)
                    end
                    if entry.sets.hovercast then
                        needUnit(addon:AttributeName(prefix, "unit", slot.actionSuffix), phase)
                    end
                end
                if slot.remap then
                    emitSet(BindingAttr.Set(addon:AttributeName(prefix, slot.remap, suffix), slot.actionSuffix))
                    emitRem(BindingAttr.Clear(addon:AttributeName(prefix, slot.remap, suffix)))
                end
                emitBindingAction(self, entry, prefix, slot.actionSuffix, emitSet, emitRem)
            end
        end
    end

    owner = nil
    for _, attr in ipairs(unitOrder) do
        phase = unitPhases[attr]
        emitSet(BindingAttr.Set(attr, "mouseover"))
        emitRem(BindingAttr.Clear(attr))
    end

    return plan
end

-- This function takes a single argument, indicating whether the attributes
-- should be built for the special global button or not, and returns an
-- attribute that can set the appropriate attributes, and one that can clear
function addon:GetBindingAttributes(global)
    local set, clr

    -- If this is not the global button, include some logic that solves issues
    -- when the frame disappears or the frame loses focus without the OnLeave
    -- event firing.
    --
    -- TODO: In the future, this should be done via OnHide or other ways as well

    if global then
        set = {
            "local clickableButton = self",
        }
        clr = {}
    else
        set = {
            "local button = self",
            "local name = button:GetName()",
            "if blacklist[name] then return end",
            "if danglingButton then ",
            "  control:RunFor(danglingButton, control:GetAttribute('setup_onleave'))",
            "end",
            -- Keys target the key proxy by name (its useOnKeyDown carries the
            -- direction); a handle silently no-ops, nil means registered in combat.
            "local clickableButton = button:GetAttribute('clique_keyproxyname')",
            "if not clickableButton then return end",
            "danglingButton = button",
        }
        clr = {
            "local button = self",
            "local name = button:GetName()",
            "if blacklist[name] then return end",
            "danglingButton = nil",
        }
    end

    -- This function is greatly simplified in that regardless of whether or
    -- not bindings mask one another, they still need to be set as binding
    -- clicks on the frame. Simply make a list of the keys that need to be
    -- bound, and bind them.

    local unique = {}

    for idx, entry in ipairs(self.bindings) do
        if entry.key then
            if shouldApply(global, entry) and self:IsBindingCorrectSpec(entry) then
                if global then
                    -- Allow for the re-binding of clicks and keys, except for
                    -- unmodified left/right-click
                    if entry.key ~= "BUTTON1" and entry.key ~= "BUTTON2" then
                        local prefix, suffix = self:GetBindingPrefixSuffix(entry, global)
                        local key = self:ConvertSpecialKeys(entry)

                        local attr = B_SET:format(key, suffix)
                        if not unique[attr] then
                            set[#set + 1] = attr
                            clr[#clr + 1] = B_CLR:format(key)
                            unique[attr] = true
                        end
                    end
                else
                    local buttonNum = self:GetMouseButtonNumber(entry)
                    if not buttonNum then
                        -- Only apply key-based binding clicks, let the raw
                        -- attributes handle the others
                        local prefix, suffix = self:GetBindingPrefixSuffix(entry, global)
                        local key = self:ConvertSpecialKeys(entry)

                        local attr = B_SET:format(key, suffix)
                        if not unique[attr] then
                            set[#set + 1] = attr
                            clr[#clr + 1] = B_CLR:format(key)
                            unique[attr] = true
                        end
                    end
                end
            end
        end
    end

    return table.concat(set, "\n"), table.concat(clr, "\n")
end

-- Teardown counterpart to StampProxySetup: clear the binding set off both proxies
-- before they're unregistered, so a pooled key proxy retains no stale dispatch.
function addon:RemoveProxySetup(frame, target)
    self.header:SetFrameRef("cliquesetup_button", target)
    self.header:Execute(self.header:GetAttribute("remove_clicks"), target)

    local keyProxy = self.keyProxies[frame]
    if keyProxy and keyProxy ~= target then
        self.header:SetFrameRef("cliquesetup_button", keyProxy)
        self.header:Execute(self.header:GetAttribute("remove_clicks"), keyProxy)
    end
end

function addon:ClearAttributes()
    -- Done inside the restricted environment so it works during combat lockdown.
    self.header:Execute([[
        for proxy in pairs(proxies) do
            self:RunFor(proxy, self:GetAttribute("remove_clicks"))
        end
    ]])

    -- Clear global attributes
    local globutton = self.globutton
    globutton:Execute(globutton.remove)
    globutton:Execute(globutton.clearbinds)
end

-- Recompute all attributes, so they can later be applied.
function addon:UpdateAttributes()
    local setup, remove, applyCombat, applyOoc = self:GetClickAttributes()
    self.header:SetAttribute("setup_clicks", setup)
    self.header:SetAttribute("remove_clicks", remove)
    self.header:SetAttribute("apply_combat", applyCombat)
    self.header:SetAttribute("apply_ooc", applyOoc)

    local set, clr = self:GetBindingAttributes()
    self.header:SetAttribute("setup_onenter", set)
    self.header:SetAttribute("setup_onleave", clr)

    local globutton = self.globutton
    globutton.setup, globutton.remove, globutton.applyCombat, globutton.applyOoc = self:GetClickAttributes(true)
    globutton.setbinds, globutton.clearbinds = self:GetBindingAttributes(true)
end

-- Remove any OnEnter and OnLeave scripts that we're written to frames
function addon:UnwrapOnEnterOnLeave(button)
    if not (self.wrapped and self.wrapped[button]) then return end
    self.header:UnwrapScript(button, "OnEnter")
    self.header:UnwrapScript(button, "OnLeave")
    self.wrapped[button] = nil
end

-- Wrap the OnEnter and OnLeave scripts to run our secure snippet. This
-- is needed to activate the keyboard bindings on unit frames.
--
-- WrapScript stacks, so unwrap any existing wrap first to keep this idempotent.
function addon:WrapOnEnterOnLeave(button)
    self.wrapped = self.wrapped or {}
    if self.wrapped[button] then
        self:UnwrapOnEnterOnLeave(button)
    end
    self.header:WrapScript(button, "OnEnter", [[
        control:RunFor(self, control:GetAttribute('setup_onenter'))
    ]])
    self.header:WrapScript(button, "OnLeave", [[
        control:RunFor(self, control:GetAttribute('setup_onleave'))
    ]])
    self.wrapped[button] = true
end

-- Stamp setup_clicks on a freshly acquired proxy immediately, before the next
-- ApplyAttributes. The key proxy needs the same binding set as the click proxy.
function addon:StampProxySetup(frame, target)
    self.header:SetFrameRef("cliquesetup_button", target)
    self.header:Execute(self.header:GetAttribute("setup_clicks"), target)

    local keyProxy = self.keyProxies[frame]
    if keyProxy and keyProxy ~= target then
        self.header:SetFrameRef("cliquesetup_button", keyProxy)
        self.header:Execute(self.header:GetAttribute("setup_clicks"), keyProxy)
    end
end

function addon:ApplyAttributes()
    -- setup_clicks reads `inCombat` and swaps the ooc/combat set; this is the path
    -- that makes ooc bindings work across the combat boundary.
    self.header:Execute([[
        for proxy in pairs(proxies) do
            self:RunFor(proxy, self:GetAttribute("setup_clicks"))
        end
    ]])

    -- Re-wrap so key bindings survive a unit frame replacing our handlers.
    for frame in pairs(self.ccframes) do
        self:WrapOnEnterOnLeave(frame)
    end

    -- Re-stamp frame routing clobbered by unit frames since registration.
    self:ReassertAllFrameClickRouting()

    -- Update the global button attributes
    self.globutton:Execute(self.globutton.setup)
    self.globutton:Execute(self.globutton.setbinds)
end

-- Touch only the masking/ooc keys instead of re-applying the full stable set on
-- every proxy. Safe because all live proxies share one combat state. See
-- docs/architecture.md.
function addon:ApplyCombatTransition(entering)
    local snippet = entering and "apply_combat" or "apply_ooc"

    self.header:Execute(([[
        for proxy in pairs(proxies) do
            self:RunFor(proxy, self:GetAttribute("%s"))
        end
    ]]):format(snippet))

    local globutton = self.globutton
    globutton:Execute(entering and globutton.applyCombat or globutton.applyOoc)
end


