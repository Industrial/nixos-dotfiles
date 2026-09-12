--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

--- @class CliqueAddon
local addon = select(2, ...)

-- Stored in proxyBackup when the clobbered attribute was originally nil, so we can
-- distinguish "captured, was nil" from "not captured yet" and clear our value on
-- teardown rather than leaving stale routing behind.
local NO_VALUE = {}

-- Write a routing attribute, snapshotting the frame's original value the first time
-- we clobber it so TeardownFrameClickRouting can restore it. Backup is keyed by
-- attribute name and shared by the static set and the per-binding combos.
local function setRouting(frame, attr, value)
    local backup = addon.proxyBackup[frame]
    if backup[attr] == nil then
        local original = frame:GetAttribute(attr)
        backup[attr] = original == nil and NO_VALUE or original
    end
    frame:SetAttribute(attr, value)
end

-- Restore an attribute Clique clobbered to its pre-clobber value and forget the
-- backup, so a later re-bind captures a fresh original. NO_VALUE means it was unset
-- before we touched it, so clear our value back to nil.
local function clearRouting(frame, attr)
    local backup = addon.proxyBackup[frame]
    local original = backup[attr]
    if original == nil then return end
    frame:SetAttribute(attr, original ~= NO_VALUE and original or nil)
    backup[attr] = nil
end

-- A Clique-owned proxy button isolates our dispatch from Blizzard's
-- SecureUnitButton_OnClick. Proxies are pooled (frames can't be destroyed) and
-- named, since key bindings target them by name via SetBindingClick. See
-- docs/architecture.md.
function addon:GetOrCreateProxy(frame)
    if self.proxies[frame] then return self.proxies[frame] end

    local proxy = self.proxyPool[frame]
    if not proxy then
        self.proxyCount = self.proxyCount + 1
        local proxyName = "CliqueProxy" .. self.proxyCount
        proxy = CreateFrame("Button", proxyName, frame, "SecureActionButtonTemplate")
        proxy.parentName = frame:GetName()
        self.proxyPool[frame] = proxy
    end

    proxy:SetAttribute("useparent-unit", true)
    -- Pet frames (SecureGroupPetHeader w/ useOwnerUnit) carry unit="raid1"+unitsuffix="pet";
    -- SecureButton_GetModifiedUnit appends the suffix, so the proxy must inherit it too or
    -- it casts on the owner instead of the pet.
    proxy:SetAttribute("useparent-unitsuffix", true)
    -- Proxy is always "up": delegate:Click() sends it no down arg, so a down-mode
    -- proxy would never fire. The firing edge is chosen on the source frame instead.
    proxy:SetAttribute("useOnKeyDown", false)
    proxy:RegisterForClicks("AnyUp")

    -- Backup is populated lazily by setRouting the first time each attribute is
    -- clobbered (the first writeRouting runs immediately after this, before anything
    -- else touches these attributes), so it always holds the original un-routed value.
    self.proxyBackup[frame] = {}

    self.proxies[frame] = proxy
    self:RegisterProxySecure(proxy)
    self:GetOrCreateKeyProxy(frame)
    return proxy
end

-- Separate SetBindingClick target so key binds can honor the direction setting via
-- useOnKeyDown without disturbing the up-pinned click proxy. See docs/attributes.md.
function addon:GetOrCreateKeyProxy(frame)
    if self.keyProxies[frame] then return self.keyProxies[frame] end

    local keyProxy = self.keyProxyPool[frame]
    if not keyProxy then
        self.keyProxyCount = self.keyProxyCount + 1
        local keyProxyName = "CliqueKeyProxy" .. self.keyProxyCount
        keyProxy = CreateFrame("Button", keyProxyName, frame, "SecureActionButtonTemplate")
        keyProxy.parentName = frame:GetName()
        self.keyProxyPool[frame] = keyProxy
    end

    keyProxy:SetAttribute("useparent-unit", true)
    keyProxy:SetAttribute("useparent-unitsuffix", true)
    keyProxy:SetAttribute("useOnKeyDown", self:UseActionOnKeyDown())
    keyProxy:RegisterForClicks(self:GetButtonDirections())
    if self:IsGamePadEnabled() then
        keyProxy:EnableGamePadButton(true)
    end

    self.keyProxies[frame] = keyProxy
    self:RegisterProxySecure(keyProxy)
    return keyProxy
end

-- Tracks the proxy in the header's secure `proxies` table so setup_clicks/
-- remove_clicks can be re-run on it from the restricted environment. Combat-safe;
-- it's proxy creation in GetOrCreateProxy that forces callers out of combat.
function addon:RegisterProxySecure(proxy)
    self.header:SetFrameRef("clique_proxy", proxy)
    self.header:Execute([[
        proxies[self:GetFrameRef("clique_proxy")] = true
    ]])
end

function addon:UnregisterProxySecure(proxy)
    self.header:SetFrameRef("clique_proxy", proxy)
    self.header:Execute([[
        proxies[self:GetFrameRef("clique_proxy")] = nil
    ]])
end

-- The routing attributes Clique owns on every routed frame regardless of the
-- binding set. Written on every setup/reassert and restored only on teardown
-- (unregister or denylist) -- never on a binding change. PROXY marks the attributes
-- whose value is the frame's proxy; the rest take the literal "click".
--
-- We take over the specific type1/type2 because some frames (e.g. Dander's) set
-- them directly, beating the *type wildcards, and the whole clickbutton family
-- because a bare clickbutton loses to any *clickbutton<N> a unit frame writes
-- (e.g. EllesmereUI's *clickbutton2).
local PROXY = {}
local staticRouting = {
    ["*type1"]        = "click",
    ["*type2"]        = "click",
    ["type"]          = "click",
    ["*type*"]        = "click",
    ["type1"]         = "click",
    ["type2"]         = "click",
    ["clickbutton"]   = PROXY,
    ["*clickbutton*"] = PROXY,
    ["clickbutton1"]  = PROXY,
    ["clickbutton2"]  = PROXY,
    ["*clickbutton1"] = PROXY,
    ["*clickbutton2"] = PROXY,
}

-- The static routing pairs for the current dispatch mode, keyed by attribute name.
-- Click mode routes via the type=click action + clickbutton family. Macrotext mode
-- routes unmodified left/right-click via type=macro + a per-button "/click <proxy>
-- <button>" macrotext -- a workaround for Blizzard's broken "click" action. There is
-- no single macrotext valid for every button, so macrotext mode claims only type1/
-- type2 statically (mirroring the native actions click mode pre-empts); buttons >=3
-- and modified combos are routed per-binding in writeRouting.
local function staticRoutingPairs(proxy)
    if not addon:IsMacrotextDispatch() then
        local pairs_ = {}
        for attr, value in pairs(staticRouting) do
            pairs_[attr] = value == PROXY and proxy or value
        end
        return pairs_
    end

    local name = proxy:GetName()
    local left  = "/click " .. name .. " LeftButton"
    local right = "/click " .. name .. " RightButton"
    return {
        ["*type1"]      = "macro",
        ["*type2"]      = "macro",
        ["type1"]       = "macro",
        ["type2"]       = "macro",
        ["*macrotext1"] = left,
        ["*macrotext2"] = right,
        ["macrotext1"]  = left,
        ["macrotext2"]  = right,
    }
end

-- Centralized writer for the register-time and reassert paths, so they can't drift.
-- Stamps the static set, reconciles the per-binding modified-click combos (writing
-- the bound ones, restoring any we previously wrote that are no longer bound), and
-- leaves clique_proxyname -- which Clique owns outright -- in place.
local function writeRouting(frame, proxy)
    local macrotext = addon:IsMacrotextDispatch()

    local staticOwned = staticRoutingPairs(proxy)
    for attr, value in pairs(staticOwned) do
        setRouting(frame, attr, value)
    end
    frame:SetAttribute("clique_proxyname", proxy:GetName())

    local keyProxy = addon.keyProxies[frame]
    if keyProxy then
        frame:SetAttribute("clique_keyproxyname", keyProxy:GetName())
    end

    -- Classic Era resolves "menu" via a plain `.menu` field (rawget fallback in
    -- SecureActionButton_OnClick), not a secure attribute.
    if addon:ProjectIsClassic() then
        proxy.menu = frame.menu
        proxy:SetAttribute("clique-has-menu-attribute", frame.menu and true or nil)
        if keyProxy then
            keyProxy.menu = frame.menu
            keyProxy:SetAttribute("clique-has-menu-attribute", frame.menu and true or nil)
        end
    end

    -- A frame's own shift-type2="togglemenu" outranks our *type* wildcard, so stamp
    -- the specific attribute for every modified click we bind. In macrotext mode this
    -- is also where buttons >=3 and unmodified BUTTON1/BUTTON2 get their per-button
    -- "/click <proxy> <button>" routing.
    local desired = {}
    for _, combo in ipairs(addon:GetClickRoutingCombos()) do
        if macrotext then
            desired[combo.type] = true
            desired[combo.macro] = true
            setRouting(frame, combo.type, "macro")
            setRouting(frame, combo.macro, "/click " .. proxy:GetName() .. " " .. combo.button)
        else
            desired[combo.type] = true
            desired[combo.click] = true
            setRouting(frame, combo.type, "click")
            setRouting(frame, combo.click, proxy)
        end
    end

    -- Hand back any attribute we previously wrote but no longer own -- combos that
    -- unbound, and (on a dispatch-mode switch) the other mode's static attributes --
    -- so the frame's original action is restored.
    for attr in pairs(addon.proxyBackup[frame]) do
        if not staticOwned[attr] and not desired[attr] then
            clearRouting(frame, attr)
        end
    end

    -- The source ignores useOnKeyDown, so its RegisterForClicks is the only lever
    -- that selects press vs. release.
    frame:RegisterForClicks(addon:GetButtonDirections())
end

-- Routes the frame's clicks to the proxy. writeRouting snapshots each original
-- attribute the first time it clobbers it, so this also seeds proxyBackup.
function addon:SetupFrameClickRouting(frame, proxy)
    writeRouting(frame, proxy)
end

-- Re-stamp our routing after something else overwrote it. Unit frame addons
-- re-run their own secure setup (e.g. *type1="target") on rebuilds; Blizzard
-- does it via CompactUnitFrame_SetUnit, third-party frames via their own paths.
-- Blocked in combat, so queue and reassert on PLAYER_REGEN_ENABLED.
function addon:ReassertFrameClickRouting(frame)
    local proxy = self.proxies[frame]
    if not proxy then return end

    -- A frame denylisted after registration keeps its proxy (BLACKLIST_CHANGED
    -- doesn't tear it down), so guard here rather than trusting self.proxies.
    if self:IsFrameBlacklisted(frame) then return end

    if InCombatLockdown() then
        self.reassertqueue[frame] = true
        return
    end

    writeRouting(frame, proxy)
end

-- Reassert routing on every proxied frame. The old direct-attribute model got
-- this for free by re-running setup_clicks on each frame in ApplyAttributes; the
-- proxy model writes frame routing once at registration, so we reassert here on
-- the re-apply path (binding change, PEW) to heal clobbers. Combat exit heals
-- only the frames the SetUnit hook queued, not the full set -- see LeavingCombat.
function addon:ReassertAllFrameClickRouting()
    for frame in pairs(self.proxies) do
        self:ReassertFrameClickRouting(frame)
    end
end

-- Removes all click routing from a frame, restoring every attribute we clobbered
-- (static set and combos) to its captured original.
function addon:TeardownFrameClickRouting(frame)
    local backup = self.proxyBackup[frame]
    if backup then
        for attr in pairs(backup) do
            clearRouting(frame, attr)
        end
        self.proxyBackup[frame] = nil
    end

    local proxy = self.proxies[frame]
    if proxy then
        self:UnregisterProxySecure(proxy)
    end
    self.proxies[frame] = nil

    local keyProxy = self.keyProxies[frame]
    if keyProxy then
        self:UnregisterProxySecure(keyProxy)
    end
    self.keyProxies[frame] = nil
end
