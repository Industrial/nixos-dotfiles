--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II

This file contains an abstraction of the spellbook APIs, ensuring that
Clique has a common interface between different versions of WoW.
-------------------------------------------------------------------]] ---

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
addon.macroCatalog = {}

local lib = addon.macroCatalog
local catalog = addon.catalog

local function getMaxAccountMacros()
    if Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_ACCOUNT_MACROS then
        return Constants.MacroConsts.MAX_ACCOUNT_MACROS
    else
        return MAX_ACCOUNT_MACROS
    end
end

local nameCount = {}
local nameCountDirty = true

local function rebuildNameCount()
    nameCount = {}
    nameCountDirty = false

    local numGlobalMacros, numPlayerMacros = GetNumMacros()

    for idx = 1, numGlobalMacros do
        local name = GetMacroInfo(idx)
        if name then
            nameCount[name] = (nameCount[name] or 0) + 1
        end
    end

    local maxAccountMacros = getMaxAccountMacros()
    for idx = maxAccountMacros + 1, maxAccountMacros + numPlayerMacros do
        local name = GetMacroInfo(idx)
        if name then
            nameCount[name] = (nameCount[name] or 0) + 1
        end
    end
end

function lib:InvalidateNameCache()
    nameCountDirty = true
end

function lib:GetMacroCatalogEntries(orderIndex)
    local results = {}

    local numGlobalMacros, numPlayerMacros = GetNumMacros()

    for idx = 1, numGlobalMacros do
        orderIndex = orderIndex + 1
        local name, icon, body = GetMacroInfo(idx)
        results[#results+1] = catalog:CreateEntry(
            catalog.entryType.Macro,
            orderIndex,
            name,
            icon,
            idx,
            false,
            false,
            true,
            false
        )
    end

    local maxAccountMacros = getMaxAccountMacros()
    for idx = maxAccountMacros + 1, maxAccountMacros + numPlayerMacros do
        orderIndex = orderIndex + 1
        local name, icon, body = GetMacroInfo(idx)
        results[#results+1] = catalog:CreateEntry(
            catalog.entryType.Macro,
            orderIndex,
            name,
            icon,
            idx,
            false,
            false,
            false,
            true
        )
    end

    return results
end

function lib:GetMacroNameIconBody(idx)
    local name, icon, body = GetMacroInfo(idx)
    return name, icon, body
end

function lib:MacroExistsByName(name)
    local name, icon, body = GetMacroInfo(name)
    if name then
        return true
    end
end

function lib:MacroNameIsAmbiguous(name)
    if nameCountDirty then
        rebuildNameCount()
    end
    return (nameCount[name] or 0) > 1
end

function lib:IsAccountMacroIndex(idx)
    local maxAccountMacros = getMaxAccountMacros()
    if idx < maxAccountMacros then
        return true
    end

    return false
end
