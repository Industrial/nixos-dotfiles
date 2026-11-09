--[[-------------------------------------------------------------------------
-- AddonCore.lua
--
-- This is a very simple, bare-minimum core for addon development. It provide
-- methods to register events, call initialization functions, and sets up the
-- localization table so it can be used elsewhere. This file is designed to be
-- loaded first, as it has no further dependencies.
--
-- Events registered:
--   * ADDON_LOADED - Watch for saved variables to be loaded, and call the
--       'Initialize' function in response.
--   * PLAYER_LOGIN - Call the 'Enable' method once the major UI elements
--       have been loaded and initialized.
--
-- Version:
--   ADDONCORE_VERSION is an integer and is exposed via .addonCoreVersion.
--   It should be incremented with any changes, and used to track which
--   version of AddonCore is embedded within a given addon.
-------------------------------------------------------------------------]]--

local ADDONCORE_VERSION = 1

local addonName = select(1, ...)

---@alias EventHandler
---| string
---| fun(...: any)

---@class AddonCore
---@field RegisterEvent fun(self: AddonCore, event: string, handler: EventHandler?)
---@field RegisterUnitEvent fun(self: AddonCore, event: string, handler: EventHandler?, ...: string)
---@field UnregisterEvent fun(self: AddonCore, event: string, handler: EventHandler?)
---@field APIIsTrue fun(self:AddonCore, val: any): boolean
---@field ProjectIsRetail fun(self: AddonCore): boolean
---@field ProjectIsForever fun(self: AddonCore): boolean
---@field ProjectIsClassic fun(self: AddonCore): boolean
---@field ProjectIsBCC fun(self: AddonCore): boolean
---@field ProjectIsWrath fun(self: AddonCore): boolean
---@field ProjectIsCataclysm fun(self: AddonCore): boolean
---@field ProjectIsMists fun(self: AddonCore): boolean
---@field ProjectIsDragonflight fun(self: AddonCore): boolean
---@field ProjectIsWarWithin fun(self: AddonCore): boolean
---@field ProjectIsMidnight fun(self: AddonCore): boolean
---@field Printf fun(self: AddonCore, msg: string, ...: any)
---@field version string
---@field addonCoreVersion integer
---@field IsInitialized fun(self: AddonCore): boolean
---@field RegisterModule fun(self: AddonCore, module: table, name: string)
---@field RegisterMessage fun(self: AddonCore, name: string, handler: EventHandler?)
---@field UnregisterMessage fun(self: AddonCore, name: string)
---@field FireMessage fun(self: AddonCore, name: string, ...: any)
---@field Defer fun(self: AddonCore, thing: string|fun())
---@field L table<string,string>
---@field RegisterLocale fun(self: AddonCore, locale: string, tbl: table<string,string>)

local addon = select(2, ...)

-- Set global name of addon
_G[addonName] = addon

addon.addonCoreVersion = ADDONCORE_VERSION

-- Globals used in this library
local CreateFrame = CreateFrame
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local GetBuildInfo = GetBuildInfo
local geterrorhandler = geterrorhandler
local GetLocale = GetLocale
local InCombatLockdown = InCombatLockdown
local IsLoggedIn = IsLoggedIn
local Mixin = Mixin
local twipe = table.wipe
local unpack = unpack or table.unpack
local UIParent = UIParent

-- Extract version information from TOC file
addon.version = GetAddOnMetadata(addonName, "Version")
if addon.version == "v5.1.5-release" or addon.version == "wowi:version" then
    addon.version = "SCM"
end

local errorHandler = geterrorhandler()

--[[-------------------------------------------------------------------------
--  Debug support
-------------------------------------------------------------------------]]--

local EMERGENCY_DEBUG = false
if EMERGENCY_DEBUG then
    local private = {}
    for k,v in pairs(addon) do
        rawset(private, k, v)
        rawset(addon, k, nil)
    end

    setmetatable(addon, {
        __index = function(t, k)
            local value = rawget(private, k)
            if type(value) == "function" then
                print("CALL", addonName .. "." .. tostring(k))
            end
            return value
        end,
        __newindex = function(t, k, v)
            print(addonName, "NEWINDEX", k, v)
            rawset(private, k, v)
        end,
    })
end

--[[-------------------------------------------------------------------------
--  API compatibility support
-------------------------------------------------------------------------]]--

-- Returns true if the API value is true-ish (handles old 1/nil returns)
function addon:APIIsTrue(val)
    if type(val) == "boolean" then
        return val
    elseif type(val) == "number" then
        return val == 1
    else
        return false
    end
end

local projects = {
    retail = "WOW_PROJECT_MAINLINE",
    classic = "WOW_PROJECT_CLASSIC",
    bcc = "WOW_PROJECT_BURNING_CRUSADE_CLASSIC",
    wrath = "WOW_PROJECT_WRATH_CLASSIC",
    cataclysm = "WOW_PROJECT_CATACLYSM_CLASSIC",
    mists = "WOW_PROJECT_MISTS_CLASSIC",
}

local project_id = _G["WOW_PROJECT_ID"]
local interfaceVersion = select(4, GetBuildInfo())

function addon:ProjectIsRetail()
    return project_id == _G[projects.retail] and not addon:ProjectIsForever()
end

function addon:ProjectIsForever()
    return interfaceVersion >= 16001 and interfaceVersion <= 19999
end

function addon:ProjectIsClassic()
    return project_id == _G[projects.classic]
end

function addon:ProjectIsBCC()
    return project_id == _G[projects.bcc]
end

function addon:ProjectIsWrath()
    return project_id == _G[projects.wrath]
end

function addon:ProjectIsCataclysm()
    return project_id == _G[projects.cataclysm]
end

function addon:ProjectIsMists()
    return project_id == _G[projects.mists]
end

function addon:ProjectIsDragonflight()
    local toc = select(4, GetBuildInfo())
    return toc >= 100000 and toc < 110000
end

function addon:ProjectIsWarWithin()
    local toc = select(4, GetBuildInfo())
    return toc >= 110000 and toc < 120000
end

function addon:ProjectIsMidnight()
    local toc = select(4, GetBuildInfo())
    return toc >= 120000 and toc < 130000
end

--[[-------------------------------------------------------------------------
--  Print/Printf support
-------------------------------------------------------------------------]]--

local printHeader = "|cFF33FF99%s|r: "

function addon:Printf(msg, ...)
    msg = printHeader .. msg
    local success, txt = pcall(string.format, msg, addonName, ...)
    if success then
        print(txt)
    else
        error(string.gsub(txt, "'%?'", string.format("'%s'", "Printf")), 3)
    end
end

--[[-------------------------------------------------------------------------
--  Event registration and dispatch
-------------------------------------------------------------------------]]--

local eventFrame = CreateFrame("Frame", addonName .. "EventFrame", UIParent)
local eventMap = {}
local EventedMixin = {}

local function createHandlerObject(self, handler, units)
    local obj = {}
    if type(handler) == "function" then
        obj.type = "func"
        obj.func = handler
    elseif type(handler) == "string" then
        obj.type = "method"
        obj.key = handler
        obj.obj = self
    end

    if units then
        obj.units = {}
        for _, unit in ipairs(units) do
            obj.units[unit] = true
        end
    end

    return obj
end

-- Find all existing registered units and add any new ones from newUnits
local function getUnitArgTable(eventHandlers, newUnits)
    local units = {}
    for _, value in ipairs(eventHandlers) do
        if value.units then
            for unit in pairs(value.units) do
                units[unit] = true
            end
        end
    end

    if newUnits then
        for _, unit in ipairs(newUnits) do
            units[unit] = true
        end
    end

    local result = {}
    for unit in pairs(units) do
        table.insert(result, unit)
    end

    return result
end

local function findHandlerIdx(self, eventHandlers, handler)
    for idx, value in ipairs(eventHandlers) do
        if type(handler) == "function" and value.func == handler then
            return idx
        elseif type(handler) == "string" and value.obj == self and value.key == handler then
            return idx
        end
    end
    return nil
end

local function hasUnitHandlers(event)
    if not eventMap[event] then
        return false
    end
    for _, handler in ipairs(eventMap[event]) do
        if handler.units then
            return true
        end
    end
    return false
end

local function registerEvent(self, event, handler, units)
    handler = handler or event
    assert(type(handler) == "string" or type(handler) == "function", "Handler must be a string or function")
    if eventMap[event] then
        local foundIdx = findHandlerIdx(self, eventMap[event], handler)
        assert(not foundIdx, string.format("Attempt to re-register event '%s' with handler '%s'", tostring(event), tostring(handler)))

        local eventHasUnits = hasUnitHandlers(event)
        if eventHasUnits and not units then
            error(string.format("Event '%s' registered as UnitEvent, cannot mix unit and non-unit for the same event", event))
        elseif not eventHasUnits and units then
            error(string.format("Event '%s' registered as Event, cannot mix unit and non-unit for the same event", event))
        end
    end

    eventMap[event] = eventMap[event] or {}

    -- Convert handler to a table
    local handlerObj = createHandlerObject(self, handler, units)
    table.insert(eventMap[event], handlerObj)

    if units then
        local unitArgs = getUnitArgTable(eventMap[event], units)
        eventFrame:RegisterUnitEvent(event, unpack(unitArgs))
    elseif #eventMap[event] == 1 then
        eventFrame:RegisterEvent(event)
    end
end

-- Allow multiple handlers to be registered, called in registration order
function EventedMixin:RegisterEvent(event, handler)
    return registerEvent(self, event, handler)
end

-- The same as above, but UnitEvents specifically, and handle registration correctly
function EventedMixin:RegisterUnitEvent(event, handler, ...)
    return registerEvent(self, event, handler, {...})
end

-- Remove event registration for a specific handler
function EventedMixin:UnregisterEvent(event, handler)
    assert(type(event) == "string", "Invalid argument to 'UnregisterEvent'")

    handler = handler or event
    if not eventMap[event] then
        return
    end

    local foundIdx = findHandlerIdx(self, eventMap[event], handler)
    if not foundIdx then
        return
    end

    local removedHandler = eventMap[event][foundIdx]
    table.remove(eventMap[event], foundIdx)

    if #eventMap[event] == 0 then
        eventMap[event] = nil
        eventFrame:UnregisterEvent(event)
    elseif removedHandler.units then
        local unitArgs = getUnitArgTable(eventMap[event])
        if #unitArgs > 0 then
            eventFrame:RegisterUnitEvent(event, unpack(unitArgs))
        else
            eventFrame:UnregisterEvent(event)
        end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = eventMap[event]
    if not handlers then return end

    local unit = ...
    for _, handler in ipairs(handlers) do
        if not handler.units or handler.units[unit] then
            if handler.type == "func" then
                xpcall(handler.func, errorHandler, event, ...)
            elseif handler.type == "method" then
                local obj = handler.obj
                local key = handler.key
                if obj[key] then
                    xpcall(obj[key], errorHandler, obj, event, ...)
                end
            end
        end
    end
end)

Mixin(addon, EventedMixin)

--[[-------------------------------------------------------------------------
--  Message registration and dispatch
-------------------------------------------------------------------------]]--

local messageMap = {}
local MessagedMixin = {}

local function findMessageHandlerIdx(self, messageHandlers, handler)
    for idx, value in ipairs(messageHandlers) do
        if type(handler) == "function" and value.func == handler then
            return idx
        elseif type(handler) == "string" and value.obj == self and value.key == handler then
            return idx
        end
    end
    return nil
end

-- Allow multiple handlers to be registered, called in registration order
function MessagedMixin:RegisterMessage(message, handler)
    handler = handler or message
    if messageMap[message] then
        local foundIdx = findMessageHandlerIdx(self, messageMap[message], handler)
        assert(not foundIdx, string.format("Attempt to re-register message '%s' with handler '%s'", tostring(message), tostring(handler)))
    end

    messageMap[message] = messageMap[message] or {}

    local handlerObj = createHandlerObject(self, handler)
    table.insert(messageMap[message], handlerObj)
end

-- Remove message registration for a specific handler, idempotent
function MessagedMixin:UnregisterMessage(message, handler)
    assert(type(message) == "string", "Invalid argument to 'UnregisterMessage'")

    handler = handler or message
    if not messageMap[message] then
        return
    end

    local foundIdx = findMessageHandlerIdx(self, messageMap[message], handler)
    if foundIdx then
        table.remove(messageMap[message], foundIdx)
    end

    if #messageMap[message] == 0 then
        messageMap[message] = nil
    end
end

function MessagedMixin:FireMessage(message, ...)
    local handlers = messageMap[message]
    if not handlers then return end

    for _, handler in ipairs(handlers) do
        if handler.type == "func" then
            xpcall(handler.func, errorHandler, message, ...)
        elseif handler.type == "method" then
            local obj = handler.obj
            local key = handler.key
            if obj[key] then
                xpcall(obj[key], errorHandler, obj, message, ...)
            end
        end
    end
end

Mixin(addon, MessagedMixin)


--[[-------------------------------------------------------------------------
--  Module support
-------------------------------------------------------------------------]]--

local modules = {}

-- Declared here, but defined below in initialize/init
local initializeModule

function addon:RegisterModule(module, name)
    assert(type(name) == "string", "Invalid argument to 'RegisterModule'")

    module.name = name
    for _, value in ipairs(modules) do
        if value == module then
            error(string.format("Attempt to re-register module: %s (%s)", name, tostring(module)))
        end
    end

    table.insert(modules, module)

    Mixin(module, EventedMixin)
    Mixin(module, MessagedMixin)
    Mixin(module, {
        Printf = addon.Printf,
    })

    -- See if we need to initialize due to late registration
    initializeModule(module)
end

--[[-------------------------------------------------------------------------
--  Setup Initialize/Enable support
--
--  These lifecycle events are handled on a dedicated frame, separate from
--  the addon's event system to prevent potential overlap or issues.
-------------------------------------------------------------------------]]--

local initializeFrame = CreateFrame("Frame")

local enableCalled = false
local initializeCalled = false

function addon:IsInitialized()
    return initializeCalled
end

local enableHandler = function()
    enableCalled = true
    local handler = "Enable"

    if type(addon[handler]) == "function" then
        xpcall(addon[handler], errorHandler, addon)
    end

    for _, module in ipairs(modules) do
        if type(module[handler]) == "function" then
            xpcall(module[handler], errorHandler, module)
        end
    end
end

local initializeHandler = function()
    initializeCalled = true
    local handler = "Initialize"

    if type(addon[handler]) == "function" then
        xpcall(addon[handler], errorHandler, addon)
    end

    for _, module in ipairs(modules) do
        if type(module[handler]) == "function" then
            xpcall(module[handler], errorHandler, module)
        end
    end

    -- If this addon was loaded-on-demand, trigger 'Enable' as well
    if IsLoggedIn() then
        enableHandler()
    end
end

initializeModule = function(module)
    if initializeCalled and type(module["Initialize"]) == "function" then
        xpcall(module["Initialize"], errorHandler, module)
    end

    if enableCalled and type(module["Enable"]) == "function" then
        xpcall(module["Enable"], errorHandler, module)
    end
end

initializeFrame:RegisterEvent("PLAYER_LOGIN")
initializeFrame:RegisterEvent("ADDON_LOADED")
initializeFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" and not enableCalled then
        enableHandler()
    elseif event == "ADDON_LOADED" and arg1 == addonName and not initializeCalled then
        initializeFrame:UnregisterEvent("ADDON_LOADED")
        initializeHandler()
    end
end)

--[[-------------------------------------------------------------------------
--  Support for deferred execution (when in-combat)
-------------------------------------------------------------------------]]--

local deferframe = CreateFrame("Frame")
deferframe.queue = {}

local function runDeferred(thing)
    local thing_t = type(thing)
    if thing_t == "string" and addon[thing] then
        addon[thing](addon)
    elseif thing_t == "function" then
        thing(addon)
    end
end

-- This method will defer the execution of a method or function until the
-- player has exited combat. If they are already out of combat, it will
-- execute the function immediately.
function addon:Defer(thing)
    local thing_t = type(thing)
    if thing_t == "string" or thing_t == "function" then
        if InCombatLockdown() then
            deferframe.queue[#deferframe.queue + 1] = thing
        else
            runDeferred(thing)
        end
    else
        error("Invalid object passed to 'Defer'")
    end
end

deferframe:RegisterEvent("PLAYER_REGEN_ENABLED")
deferframe:SetScript("OnEvent", function()
    for _, thing in ipairs(deferframe.queue) do
        runDeferred(thing)
    end
    twipe(deferframe.queue)
end)

--[[-------------------------------------------------------------------------
--  Localization
-------------------------------------------------------------------------]]--

addon.L = addon.L or setmetatable({}, {
    __index = function(t, k)
        rawset(t, k, k)
        return k
    end,
    __newindex = function(t, k, v)
        if v == true then
            rawset(t, k, k)
        else
            rawset(t, k, v)
        end
    end,
})

function addon:RegisterLocale(locale, tbl)
    if locale == "enUS" or locale == GetLocale() then
        for k,v in pairs(tbl) do
            if v == true then
                self.L[k] = k
            elseif type(v) == "string" then
                self.L[k] = v
            else
                self.L[k] = k
            end
        end
    end
end
