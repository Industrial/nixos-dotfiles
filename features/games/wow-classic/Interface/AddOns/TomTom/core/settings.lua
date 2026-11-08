--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- Saved variables: the defaults, the AceDB databases and their migrations.

local addonName, addon = ...
local TomTom = addon
local L = addon.L
addon.private = addon.private or {}
local private = addon.private

-- Defaults that modules give for their own settings namespace. They are
-- merged into the options defaults before the database is created, so a
-- module that is off still has its defaults.
local moduleDefaults = {}

function private.RegisterDefaults(namespace, defaults)
    assert(type(namespace) == "string" and type(defaults) == "table", "RegisterDefaults(namespace, defaults)")
    assert(not moduleDefaults[namespace], "Defaults already registered for " .. namespace)
    moduleDefaults[namespace] = defaults
end

local function MergeModuleDefaults(profileDefaults)
    for namespace, defaults in pairs(moduleDefaults) do
        local target = profileDefaults[namespace]
        if not target then
            target = {}
            profileDefaults[namespace] = target
        end
        for key, value in pairs(defaults) do
            assert(target[key] == nil, "Two defaults for " .. namespace .. "." .. key)
            target[key] = value
        end
    end
end

-- The one writer for option settings. Code outside the settings panel uses
-- it too, so the panel and the modules always see each change.
function private.SetSetting(namespace, key, value)
    TomTom.db.profile[namespace][key] = value
    if private.RefreshSettingsRow then
        private.RefreshSettingsRow(namespace, key)
    end
    TomTom:FireMessage("TOMTOM_SETTING_CHANGED", namespace, key, value)
end

-- Called from TomTom:Initialize, when the saved variables are loaded.
function private.InitializeDatabases(self)
    self.defaults = {
        profile = {
            general = {
                confirmremoveall = true,
                announce = false,
                corpse_arrow = true,
            },
            arrow = {
                enable = true,
                goodcolor = {0, 1, 0},
                badcolor = {1, 0, 0},
                middlecolor = {1, 1, 0},
				exactcolor = {0, 1, 0},
                arrival = 15,
                lock = false,
                noclick = false,
                showtta = true,
				showdistance = true,
				stickycorpse = false,
				highstrata = false,
                autoqueue = true,
                menu = true,
                scale = 1.0,
                alpha = 1.0,
                title_width = 0,
                title_height = 0,
                title_scale = 1,
                title_alpha = 1,
                setclosest = true,
				closestusecontinent = false,
                enablePing = false,
                pingChannel = "SFX",
                hideDuringPetBattles = true,
                distanceUnits = "auto",
                theme = "modern",
            },
            -- The pin keys are in modules/worldmap_pins.lua.
            worldmap = {
                clickcreate = true,
                create_modifier = "A",
            },
            comm = {
                enable = true,
                prompt = false,
            },
            persistence = {
                cleardistance = 10,
                savewaypoints = true,
            },
        },
    }

    self.waydefaults = {
        profile = {
            ["*"] = {},
        },
    }

    MergeModuleDefaults(self.defaults.profile)

    self.db = LibStub("AceDB-3.0"):New("TomTomDB", self.defaults, "Default")
    self.waydb = LibStub("AceDB-3.0"):New("TomTomWaypointsM", self.waydefaults)

    self:MigratePasteProfile(self.db.profile)
    private.MigrateWaypointPinFlags(self.waydb)

    self.db.RegisterCallback(self, "OnProfileChanged", "ReloadOptions")
    self.db.RegisterCallback(self, "OnProfileCopied", "ReloadOptions")
    self.db.RegisterCallback(self, "OnProfileReset", "ReloadOptions")
    self.waydb.RegisterCallback(self, "OnProfileChanged", "ReloadWaypoints")
    self.waydb.RegisterCallback(self, "OnProfileCopied", "ReloadWaypoints")
    self.waydb.RegisterCallback(self, "OnProfileReset", "ReloadWaypoints")

    -- Both the waypoints and waypointprofile tables are going to contain subtables for each
    -- of the mapids that might exist. Under these will be a hash of key/waypoint pairs consisting
    -- of the waypoints for the given map file.
    self.waypointprofile = self.waydb.profile
end

-- Before D14, AddWaypoint saved the minimap and world map "enable" settings
-- in each waypoint. Now these settings apply live, so a saved false would
-- keep the pin away for good. Runs once, for all waypoint profiles.
function private.MigrateWaypointPinFlags(waydb)
    if waydb.global.pinFlagsLive then return end
    local sv = rawget(waydb, "sv")
    for _, profile in pairs(sv and sv.profiles or {}) do
        for _, entries in pairs(profile) do
            if type(entries) == "table" then
                for _, waypoint in pairs(entries) do
                    if type(waypoint) == "table" then
                        waypoint.minimap = true
                        waypoint.world = true
                    end
                end
            end
        end
    end
    waydb.global.pinFlagsLive = true
end

-- Migrate from the old style of minimap button and addon compartment buttons,
-- so there's no conflict between TomTom and LibDBIcon and database defaults
-- are more sane.
function TomTom:MigratePasteProfile(profile)
    local paste = profile.paste
    if not paste then return end

    local hasOldMinimap = paste.minimap_button ~= nil
    local hasOldCompartment = paste.addon_compartment_button ~= nil
    if not hasOldMinimap and not hasOldCompartment then return end

    if hasOldMinimap then
        if not paste.button then
            paste.button = {}
        end
        paste.button.hide = not paste.minimap_button
        paste.minimap_button = nil
    end

    if hasOldCompartment then
        paste.addon_compartment = paste.addon_compartment_button
        paste.addon_compartment_button = nil
    end
end
