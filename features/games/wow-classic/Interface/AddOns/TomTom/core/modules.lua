--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- Feature modules: registration, and turning them on and off at runtime.
--
-- A module is a table with these optional fields:
--   settingsKey          the options namespace of the module
--   enableSetting        {namespace, key} of the setting that turns the
--                        module on; default {settingsKey, "enable"}
--   defaults             defaults for the settingsKey namespace
--   IsAvailable()        false if this client cannot run the module
--   IsEnabledInSettings() override for modules with a special enable rule
--   OnInitialize()       runs once, before the first OnEnable
--   OnEnable()           the module starts: register events, show frames
--   OnDisable()          the module stops, as far as it can
--   OnSettingChanged(key, value)  a setting in settingsKey changed while on
--   OnProfileChanged()   the options profile changed while on
--
-- AddonCore runs only methods named Initialize and Enable. Modules must not
-- use those names, because this file controls when a module starts.

local _, addon = ...
local TomTom = addon
addon.private = addon.private or {}
local private = addon.private

local modules = {}
local modulesByName = {}
local started = false

local function Call(module, method, ...)
    local func = module[method]
    if func then
        xpcall(func, geterrorhandler(), module, ...)
    end
end

local function GetEnableSetting(module)
    if module.enableSetting then
        return module.enableSetting[1], module.enableSetting[2]
    end
    return module.settingsKey, "enable"
end

local function IsEnabledInSettings(module)
    if module.IsEnabledInSettings then
        return module:IsEnabledInSettings()
    end
    local namespace, key = GetEnableSetting(module)
    local settings = namespace and TomTom.db.profile[namespace]
    return settings and settings[key] and true or false
end

local function ShouldRun(module)
    if module.IsAvailable and not module:IsAvailable() then
        return false
    end
    if private.IsModuleSuppressed and private.IsModuleSuppressed(module) then
        return false
    end
    return IsEnabledInSettings(module)
end

local function EnableModule(module)
    if module.enabled then return end
    if not module.initialized then
        module.initialized = true
        Call(module, "OnInitialize")
    end
    module.enabled = true
    Call(module, "OnEnable")
end

local function DisableModule(module)
    if not module.enabled then return end
    module.enabled = false
    Call(module, "OnDisable")
end

function private.UpdateModule(module)
    if not started then return end
    if ShouldRun(module) then
        EnableModule(module)
    else
        DisableModule(module)
    end
end

local function IsEnabled(self)
    return self.enabled == true
end

function private.AddModule(module, name)
    assert(type(module) == "table" and type(name) == "string", "AddModule(module, name)")
    assert(not modulesByName[name], "Module already registered: " .. name)
    assert(module.Initialize == nil and module.Enable == nil,
        "Module " .. name .. " must use OnInitialize and OnEnable, not Initialize and Enable")

    addon:RegisterModule(module, name)
    module.IsEnabled = module.IsEnabled or IsEnabled
    table.insert(modules, module)
    modulesByName[name] = module

    if module.defaults then
        private.RegisterDefaults(module.settingsKey, module.defaults)
    end

    private.UpdateModule(module)
    return module
end

function private.GetModule(name)
    return modulesByName[name]
end

function private.IterateModules()
    return ipairs(modules)
end

-- Called from TomTom:Enable, at login.
function private.StartModules()
    started = true
    for _, module in ipairs(modules) do
        private.UpdateModule(module)
    end
end

-- A change in the module's namespace can also change IsEnabledInSettings
-- (for example a module with two enable keys), so it updates the module
-- first. OnSettingChanged runs only if the module was on and stays on.
TomTom:RegisterMessage("TOMTOM_SETTING_CHANGED", function(_, namespace, key, value)
    for _, module in ipairs(modules) do
        local enableNamespace, enableKey = GetEnableSetting(module)
        local isEnableKey = namespace == enableNamespace and key == enableKey
        if isEnableKey or namespace == module.settingsKey then
            local wasEnabled = module.enabled
            private.UpdateModule(module)
            if wasEnabled and module.enabled and not isEnableKey then
                Call(module, "OnSettingChanged", key, value)
            end
        end
    end
end)

TomTom:RegisterMessage("TOMTOM_PROFILE_CHANGED", function()
    if not started then return end
    for _, module in ipairs(modules) do
        local wasEnabled = module.enabled
        private.UpdateModule(module)
        if wasEnabled and module.enabled then
            Call(module, "OnProfileChanged")
        end
    end
end)
