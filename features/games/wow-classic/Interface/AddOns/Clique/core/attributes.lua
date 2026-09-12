--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

---@class CliqueAddon: AddonCore
local addon = select(2, ...)

function addon:ShouldRemoveSelfCast()
    return false
end

local function ATTR(indent, prefix, attr, suffix, value)
    return ([[%sbutton:SetAttribute("%s", %q)]]):format(indent, addon:AttributeName(prefix, attr, suffix), value)
end

local function REMATTR(prefix, attr, suffix)
    return ([[button:SetAttribute("%s", nil)]]):format(addon:AttributeName(prefix, attr, suffix))
end

-- Like ATTR, but the value is a raw Lua expression evaluated in the restricted
-- environment when the snippet runs, rather than a baked-in literal.
local function ATTREXPR(prefix, attr, suffix, expr)
    return ([[button:SetAttribute("%s", %s)]]):format(addon:AttributeName(prefix, attr, suffix), expr)
end

local B_SET = [[self:SetBindingClick(true, %q, clickableButton, %q);]]
local B_CLR = [[self:ClearBinding(%q);]]

-- A sort function that determines in what order bindings should be applied.
-- This function should be treated with care, it can drastically change behavior
local function ApplicationOrder(a, b)
    local acnt, bcnt = 0, 0
    for k,v in pairs(a.sets) do acnt = acnt + 1 end
    for k,v in pairs(b.sets) do bcnt = bcnt + 1 end

    -- Force out-of-combat clicks to take the HIGHEST priority
    if a.sets.ooc and not b.sets.ooc then
        return true
    elseif b.sets.ooc and not a.sets.ooc then
        return false
    elseif a.sets.ooc and b.sets.ooc then
        return acnt < bcnt
    end

    -- Try to give any 'default' clicks LOWEST priority
    if a.sets.default and not b.sets.default then
        return true
    elseif a.sets.default and b.sets.default then
        return acnt < bcnt
    end
end

local function shouldApply(global, entry)
    -- Filter out gamepad bindings when the gamepad option is disabled
    if addon:IsGamePadBinding(entry) and not addon:IsGamePadEnabled() then
        return false
    end

    -- If this is the global button and this is a 'global' binding
    if global and (entry.sets.hovercast or entry.sets.global) then
        return true
    elseif not global then
        -- Check to see if there's a non-global binding to be set
        for k, v in pairs(entry.sets) do
            if k ~= "global" and k ~= "hovercast" then
                return true
            end
        end
        return false
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

    -- Bindings are bucketed by combat phase so only the keys that change across
    -- the boundary go in the delta snippets. See docs/architecture.md.
    local stableSet, stableRem = {}, {}
    local combatSet, combatRem = {}, {}
    local oocSet, oocRem = {}, {}

    local phase = "stable"
    local function emitSet(line)
        local b = (phase == "combat" and combatSet) or (phase == "ooc" and oocSet) or stableSet
        b[#b + 1] = line
    end
    local function emitRem(line)
        local b = (phase == "combat" and combatRem) or (phase == "ooc" and oocRem) or stableRem
        b[#b + 1] = line
    end

    if self:ShouldRemoveSelfCast() then
        stableSet[#stableSet + 1] = "button:SetAttribute('checkselfcast', false)"
        stableSet[#stableSet + 1] = "button:SetAttribute('checkfocuscast', false)"
    end

    -- Sort the bindings so they are applied in order. This sort ensures that
    -- any 'ooc' bindings are applied first.
    table.sort(self.bindings, ApplicationOrder)

    -- Build a small table of ooc keys that are 'taken' so we can check for
    -- masking conflicts with the friend/enemy sets.
    local oocKeys = {}
    for _, entry in ipairs(self.bindings) do
        if shouldApply(global, entry) and entry.sets.ooc and entry.key then
            oocKeys[entry.key] = true
        end
    end

    for _, entry in ipairs(self.bindings) do
        -- Global (i.e. 'hovercast' and 'global') bindings are only applied
        -- on the global frame, and not on any others. Additionally, any
        -- non-global bindings are only applied on non-global frames.
        if shouldApply(global, entry) and self:IsBindingCorrectSpec(entry) and entry.key then
            -- A non-ooc binding sharing an ooc key masks it: combat-only here,
            -- ooc-only for the partner. Everything else is stable.
            if oocKeys[entry.key] and not entry.sets.ooc then
                phase = "combat"
            elseif entry.sets.ooc then
                phase = "ooc"
            else
                phase = "stable"
            end

            local prefix, suffix = self:GetBindingPrefixSuffix(entry, global)

            -- Set up help/harm bindings. The button value will be either a number,
            -- in the case of mouse buttons, otherwise it will be a string of
            -- characters. Harmbuttons work alongside modifiers, so we need to include
            -- then in the remapping.
            if entry.sets.friend then
                if global then
                    -- A modified binding that uses friend/enemy must have the unmodified
                    -- 'unit' attribute set, in order to do the friend/enemy lookup.
                    emitSet(ATTR("", prefix, "unit", suffix, "mouseover"))
                    emitRem(REMATTR(prefix, "unit", suffix))
                end
                local newbutton = "friend" .. suffix
                emitSet(ATTR("", prefix, "helpbutton", suffix, newbutton))
                emitRem(REMATTR(prefix, "helpbutton", suffix))
                suffix = newbutton
            elseif entry.sets.enemy then
                if global then
                    emitSet(ATTR("", prefix, "unit", suffix, "mouseover"))
                    emitRem(REMATTR(prefix, "unit", suffix))
                end
                local newbutton = "enemy" .. suffix
                emitSet(ATTR("", prefix, "harmbutton", suffix, newbutton))
                emitRem(REMATTR(prefix, "harmbutton", suffix))
                suffix = newbutton
            end

            -- When we're setting up the 'global' button, and the binding is in the
            -- 'hovercast' binding set, we need to specify the unit on which to take
            -- the action. In this case, that's just mouseover.
            if global and entry.sets.hovercast then
                emitSet(ATTR("", prefix, "unit", suffix, "mouseover"))
                emitRem(REMATTR(prefix, "unit", suffix))
            end

            -- Build any needed SetAttribute() calls
            if entry.type == "target" then
                emitSet(ATTR("", prefix, "type", suffix, "target"))
                emitRem(REMATTR(prefix, "type", suffix))
            elseif entry.type == "menu" then
                if self:ProjectIsClassic() then
                    -- Classic Era resolves "menu" via SecureActionButton_OnClick's
                    -- rawget(self, "menu") fallback; use it when forwarded, else togglemenu.
                    emitSet(ATTREXPR(prefix, "type", suffix,
                        [[button:GetAttribute("clique-has-menu-attribute") and "menu" or "togglemenu"]]))
                else
                    emitSet(ATTR("", prefix, "type", suffix, "togglemenu"))
                end
                emitRem(REMATTR(prefix, "type", suffix))
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
                emitSet(ATTR("", prefix, "type", suffix, "macro"))
                emitSet(ATTR("", prefix, "macrotext", suffix, macrotext))
                emitRem(REMATTR(prefix, "type", suffix))
                emitRem(REMATTR(prefix, "macrotext", suffix))
            elseif entry.type == "spell" then
                local spellText = self:SpellTextWithSubName(entry)
                emitSet(ATTR("", prefix, "type", suffix, entry.type))
                emitSet(ATTR("", prefix, "spell", suffix, spellText))
                emitRem(REMATTR(prefix, "type", suffix))
                emitRem(REMATTR(prefix, "spell", suffix))
            -- Macros aren't available on The War Within and above
            elseif entry.type == "macro" and self.settings.stopcastingfix and entry.macrotext then
                local macrotext = string.format("/click %s\n%s", self.stopbutton.name, entry.macrotext)
                emitSet(ATTR("", prefix, "type", suffix, entry.type))
                emitSet(ATTR("", prefix, "macrotext", suffix, macrotext))
                emitRem(REMATTR(prefix, "type", suffix))
                emitRem(REMATTR(prefix, "macrotext", suffix))
            -- Macros aren't available on The War Within and above
            elseif entry.type == "macro" and entry.macrotext then
                emitSet(ATTR("", prefix, "type", suffix, entry.type))
                emitSet(ATTR("", prefix, "macrotext", suffix, entry.macrotext))
                emitRem(REMATTR(prefix, "type", suffix))
                emitRem(REMATTR(prefix, "macrotext", suffix))
            elseif entry.type == "macro" and entry.macro then
                emitSet(ATTR("", prefix, "type", suffix, entry.type))
                emitSet(ATTR("", prefix, "macro", suffix, entry.macro))
                emitRem(REMATTR(prefix, "type", suffix))
                emitRem(REMATTR(prefix, "macro", suffix))
            elseif entry.type == "item" then
                emitSet(ATTR("", prefix, "type", suffix, entry.type))
                emitSet(ATTR("", prefix, "item", suffix, entry.item))
                emitRem(REMATTR(prefix, "type", suffix))
                emitRem(REMATTR(prefix, "item", suffix))
            else
                error(string.format("Invalid action type: '%s'", tostring(entry.type)))
            end
        end
    end

    local function emitBlock(out, lines, indent)
        for _, line in ipairs(lines) do
            out[#out + 1] = indent .. line
        end
    end

    local setup = {}
    emitBlock(setup, preamble, "")
    emitBlock(setup, stableSet, "")
    -- ooc before combat: a masking binding and its ooc partner share keys, so the
    -- ooc clear must run before the masking set or it wipes what we just set.
    if #oocSet > 0 then
        setup[#setup + 1] = "if not inCombat then"
        emitBlock(setup, oocSet, "  ")
        setup[#setup + 1] = "else"
        emitBlock(setup, oocRem, "  ")
        setup[#setup + 1] = "end"
    end
    if #combatSet > 0 then
        setup[#setup + 1] = "if inCombat then"
        emitBlock(setup, combatSet, "  ")
        setup[#setup + 1] = "end"
    end

    local remove = {}
    emitBlock(remove, preamble, "")
    emitBlock(remove, stableRem, "")
    emitBlock(remove, combatRem, "")
    emitBlock(remove, oocRem, "")

    local applyCombat = {}  -- out-of-combat -> combat: clear ooc keys, then set masking
    emitBlock(applyCombat, deltaPreamble, "")
    emitBlock(applyCombat, oocRem, "")
    emitBlock(applyCombat, combatSet, "")

    local applyOoc = {}     -- combat -> out-of-combat: clear masking keys, then set ooc
    emitBlock(applyOoc, deltaPreamble, "")
    emitBlock(applyOoc, combatRem, "")
    emitBlock(applyOoc, oocSet, "")

    return table.concat(setup, "\n"), table.concat(remove, "\n"),
           table.concat(applyCombat, "\n"), table.concat(applyOoc, "\n")
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


