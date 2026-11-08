--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- Addon setup: saved variables, defaults, login and option reloads.

local addonName, addon = ...
local TomTom = addon
local L = addon.L
local hbd = LibStub("HereBeDragons-2.0")
addon.private = addon.private or {}
local private = addon.private

addon.hbd = hbd
addon.WOW_MAINLINE = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
addon.WOW_CLASSIC = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
addon.WOW_BURNING_CRUSADE_CLASSIC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)

-- RegisterEvent raises an error for an unknown event on newer clients, so ask
-- the client first. Older clients have no C_EventUtils and ignore unknown events.
local function HasPetBattleEvents()
    if C_EventUtils and C_EventUtils.IsEventValid then
        return C_EventUtils.IsEventValid("PET_BATTLE_OPENING_START")
            and C_EventUtils.IsEventValid("PET_BATTLE_CLOSE")
    end
    return C_PetBattles ~= nil
end
private.HasPetBattleEvents = HasPetBattleEvents

function TomTom:Initialize(event, addon)
    private.InitializeDatabases(self)


    -- Watch for pet battle start/end so we can hide/show the arrow
    if HasPetBattleEvents() then
        self:RegisterEvent("PET_BATTLE_OPENING_START", "ShowHideCrazyArrow")
        self:RegisterEvent("PET_BATTLE_CLOSE", "ShowHideCrazyArrow")
    end

    -- Only clients with the gamepad interface have this event.
    if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("INPUT_DEVICE_INTERFACE_TRANSITION") then
        self:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
    end

    self:ReloadOptions()
end

-- The modules that the gamepad interface turns off start or stop at once,
-- but taint from the old mode stays until a reload, so the user gets a
-- message.
function TomTom:INPUT_DEVICE_INTERFACE_TRANSITION(event, newMode, oldMode)
    if newMode == oldMode or not IsLoggedIn() then
        return
    end
    for _, name in ipairs({"WorldMapPins", "MapClick"}) do
        private.UpdateModule(private.GetModule(name))
    end
    ChatFrame1:AddMessage(L["|cffffff78TomTom:|r The interface mode has changed. Type /reload so TomTom can update its world map waypoints."])
end

function TomTom:Enable(addon)
    self:ReloadWaypoints()


    -- Kaliel's Tracker replaces this method and needs it to run at startup
    -- (integrations.md 3.4 item 7).
    self:EnableDisablePOIIntegration()

    private.StartModules()

    -- Last, and protected: a Settings API difference on one client must not
    -- stop the features above.
    xpcall(private.BuildSettings, geterrorhandler())
end

function TomTom:ReloadOptions()
    -- This handles the reloading of all options
    self.profile = self.db.profile

    addon:MigratePasteProfile(self.db.profile)
    self:ShowHideCrazyArrow()
    self:FireMessage("TOMTOM_PROFILE_CHANGED")
end
