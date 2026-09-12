--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

---@class CliqueAddon: AddonCore
local addon = select(2, ...)

function addon:RegisterUnitFrame(frame)
    -- We need a frame
    --
    if not frame then return end
    -- Make sure its not already registered
    if self.ccframes[frame] then return end
    -- Make sure the frame is button-ish
    if not frame.RegisterForClicks then return end

    if InCombatLockdown() or not self:IsInitialized() then
        table.insert(self.regqueue, frame)
        return
    end

    self.ccframes[frame] = true
    self:UpdateRegisteredClicks(frame)

    -- Denylisted frames get no proxy and no routing -- we leave them untouched.
    local proxy
    if not self:IsFrameBlacklisted(frame) then
        proxy = self:GetOrCreateProxy(frame)
        self:SetupFrameClickRouting(frame, proxy)
    end

    -- Wrap the OnEnter and OnLeave scripts, calling the snippets stored
    -- in the control header. That script gets updated with new attributes
    -- so no need to update the dispatch.
    --
    -- NOTE that these will be nuked if the unit frame sets these scripts,
    -- as this is just hooking.
    self:WrapOnEnterOnLeave(frame)
    self:HookBindingTooltipFrame(frame)

    -- Apply the binding set via the secure header. For blacklisted frames the
    -- target is the frame itself; the snippet's blacklist guard no-ops it.
    local target = proxy or frame
    self:StampProxySetup(frame, target)
end

function addon:UnregisterUnitFrame(frame)
    if InCombatLockdown() then
        table.insert(self.unregqueue, frame)
        return
    end

    -- Always clear key bindings on the original frame via the secure header
    self.header:SetFrameRef("cliquesetup_button", frame)
    self.header:Execute([[
        local button = self:GetFrameRef("cliquesetup_button")
        self:RunFor(button, self:GetAttribute("setup_onleave"))
    ]])

    -- Blacklisted frames never got a proxy or routing, so there's nothing to clear.
    local proxy = self.proxies[frame]
    if proxy then
        self:RemoveProxySetup(frame, proxy)
        self:TeardownFrameClickRouting(frame)
    end

    self.ccframes[frame] = nil

    -- Unwrap the OnEnter/OnLeave scripts, if they were set
    self:UnwrapOnEnterOnLeave(frame)
end

-- Dumps the live click-routing state of a single frame, registered or not, so
-- the same diagnostic works on a third-party frame that never registered.
function addon:InspectFrame(frame)
    local name = frame.GetName and frame:GetName() or tostring(frame)
    local proxy = self.proxies[frame]
    local clickbutton = frame:GetAttribute("clickbutton")
    local cbName = type(clickbutton) == "table" and clickbutton.GetName and clickbutton:GetName() or tostring(clickbutton)

    self:Printf("%s: registered=%s proxy=%s clickbutton=%s routed=%s",
        name,
        tostring(self.ccframes[frame] ~= nil),
        proxy and proxy:GetName() or "none",
        cbName,
        tostring(proxy ~= nil and clickbutton == proxy))
    self:Printf("  type=%s *type*=%s type1=%s *type1=%s type2=%s *type2=%s",
        tostring(frame:GetAttribute("type")),
        tostring(frame:GetAttribute("*type*")),
        tostring(frame:GetAttribute("type1")),
        tostring(frame:GetAttribute("*type1")),
        tostring(frame:GetAttribute("type2")),
        tostring(frame:GetAttribute("*type2")))
end

-- The frame currently under the mouse, version-safe. GetMouseFoci (modern)
-- returns topmost-first; GetMouseFocus (legacy) returns a single frame.
local function getMouseFrame()
    if GetMouseFoci then
        return GetMouseFoci()[1]
    end
    return GetMouseFocus and GetMouseFocus()
end

-- Read-only diagnostic for confirming whether routing attributes survived on a
-- frame. With a `pattern`, dumps every registered frame whose name matches;
-- with none, dumps the frame under the mouse (which may not be registered).
function addon:InspectRegisteredFrames(pattern)
    if not pattern then
        local frame = getMouseFrame()
        if not frame or not frame.GetAttribute then
            self:Printf("No frame under the mouse to inspect.")
            return
        end
        self:InspectFrame(frame)
        return
    end

    local found = 0
    for frame in pairs(self.ccframes) do
        local name = frame.GetName and frame:GetName() or nil
        if name and name:match(pattern) then
            found = found + 1
            self:InspectFrame(frame)
        end
    end
    self:Printf("Inspected %d registered frame(s) matching %s", found, pattern)
end

-- This function returns whether or not a frame is blacklisted in the current
-- users settings
function addon:IsFrameBlacklisted(frame)
    local name = frame
    if type(frame) == "table" then
        name = frame.GetName and frame:GetName()
    end

    return self.settings.blacklist[name]
end

function addon:PopulateDenylistFromSettings()
    local bits = {
        "blacklist = table.wipe(blacklist)",
    }

    -- Denylisted frames get no proxy, so the secure blacklist only needs their
    -- name for the in-snippet guard to consult.
    for frame, value in pairs(self.settings.blacklist) do
        if value then
            bits[#bits + 1] = string.format("blacklist[%q] = true", frame)
        end
    end

    self.header:Execute(table.concat(bits, ";\n"))
end

function addon:UpdateGlobalButtonClicks()
    -- Unlike the proxies, the global button gets input directly with a real down
    -- state, so it honors the direction knob on both axes.
    self.globutton:SetAttribute("useOnKeyDown", self:UseActionOnKeyDown())
    self.globutton:RegisterForClicks(self:GetButtonDirections())
    if self:IsGamePadEnabled() then
        self.globutton:EnableGamePadButton(true)
    end
end

-- Direction the saved `clickDirection` setting selects: fire on press ("down"),
-- release ("up"), or both edges. Drives RegisterForClicks on the source frames
-- and global button; proxies are pinned to up regardless. See docs/architecture.md.
function addon:GetActionDirection()
    return self.settings.clickDirection
end

function addon:UseActionOnKeyDown()
    return self:GetActionDirection() ~= "up"
end

function addon:GetButtonDirections()
    local direction = self:GetActionDirection()
    if direction == "both" then
        return "AnyUp", "AnyDown"
    elseif direction == "up" then
        return "AnyUp"
    else
        return "AnyDown"
    end
end

-- useOnKeyDown is what selects press vs. release for key binds on the key proxy.
function addon:RefreshKeyProxyClicks(keyProxy, directions, enableGamePad)
    keyProxy:SetAttribute("useOnKeyDown", self:UseActionOnKeyDown())
    keyProxy:RegisterForClicks(unpack(directions))
    if enableGamePad then keyProxy:EnableGamePadButton(true) end
end

-- Update both registered clicks, and ensure that mousewheel events are enabled
-- on the frame.
function addon:UpdateRegisteredClicks(button)
    if InCombatLockdown() then
        table.insert(self.regclickqueue, button)
        return
    end

    local enableGamePad = self:IsGamePadEnabled()

    -- Note: We intentionally only enable GamePadButton, never disable it.
    -- WoW frames come with EnableGamePadButton on by default, so we don't
    -- want to forcibly disable it when the Clique option is off.

    local directions = { self:GetButtonDirections() }

    -- Short version that only updates clicks for one frame
    if button and not self:IsFrameBlacklisted(button) then
        local proxy = self.proxies[button]
        if proxy then
            -- Source picks the firing edge; the proxy stays pinned to up.
            button:RegisterForClicks(unpack(directions))
            proxy:RegisterForClicks("AnyUp")
            if enableGamePad then proxy:EnableGamePadButton(true) end
            local keyProxy = self.keyProxies[button]
            if keyProxy then self:RefreshKeyProxyClicks(keyProxy, directions, enableGamePad) end
        else
            button:RegisterForClicks(unpack(directions))
        end
        button:EnableMouseWheel(true)
        if enableGamePad then
            button:EnableGamePadButton(true)
        end
        return
    end

    for frame in pairs(self.ccframes) do
        if not self:IsFrameBlacklisted(frame) then
            local proxy = self.proxies[frame]
            if proxy then
                frame:RegisterForClicks(unpack(directions))
                proxy:RegisterForClicks("AnyUp")
                if enableGamePad then proxy:EnableGamePadButton(true) end
                local keyProxy = self.keyProxies[frame]
                if keyProxy then self:RefreshKeyProxyClicks(keyProxy, directions, enableGamePad) end
            else
                frame:RegisterForClicks(unpack(directions))
            end
            frame:EnableMouseWheel(true)
            if enableGamePad then
                frame:EnableGamePadButton(true)
            end
        end
    end

    for _, hframe in pairs(self.hccframes) do
        if not self:IsFrameBlacklisted(hframe) then
            hframe:RegisterForClicks(unpack(directions))
            hframe:EnableMouseWheel(true)
            if enableGamePad then
                hframe:EnableGamePadButton(true)
            end
        end
    end

    -- Update the global button in case settings have changed
    self:UpdateGlobalButtonClicks()
end

-- Bring each registered frame's proxy state in line with its current denylist
-- status. A frame denylisted at registration never gets a proxy, but one toggled
-- afterwards isn't reconciled by Clear/ApplyAttributes (those only touch existing
-- proxies), so without this a newly denylisted frame keeps stale routing and a
-- newly un-denylisted one never gets routed until the next /reload.
function addon:ReconcileFrameDenylist()
    for frame in pairs(self.ccframes) do
        local denylisted = self:IsFrameBlacklisted(frame)
        local proxy = self.proxies[frame]

        if denylisted and proxy then
            -- Clear the proxy's dispatch here rather than trusting a prior
            -- ClearAttributes, then restore the frame's original attributes and
            -- drop the proxy so the frame is left untouched.
            self:RemoveProxySetup(frame, proxy)
            self:TeardownFrameClickRouting(frame)
        elseif not denylisted and not proxy then
            proxy = self:GetOrCreateProxy(frame)
            self:SetupFrameClickRouting(frame, proxy)
        end
    end
end

function addon:BLACKLIST_CHANGED()
    if InCombatLockdown() then
        self:Defer("BLACKLIST_CHANGED")
        return
    end

    -- Clear attributes on all frames
    self:ClearAttributes()

    -- Sync the secure blacklist with Lua-side settings
    self:PopulateDenylistFromSettings()

    -- Create/tear down proxies for frames whose denylist status just changed
    self:ReconcileFrameDenylist()

    -- Update the registered clicks, to catch any unblacklisted frames
    self:UpdateRegisteredClicks()

    -- Update the options panel
    if self.UpdateOptionsPanel then
        self:UpdateOptionsPanel()
    end

    -- Update the actual attributes on all frames
    self:ApplyAttributes()
end
