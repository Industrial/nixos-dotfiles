--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II

   This file contains the abstractions of "things that can be bound"
   with Clique. Initially there will be support for spells and macros,
   but ideally it should be easy to add others.
-------------------------------------------------------------------]] ---

---@class CliqueAddon: AddonCore
local addon = select(2, ...)

addon.catalog = {}
local catalog = addon.catalog

catalog.entryType = {
    Spell = "SPELL",
    Pet = "PETSPELL",
    Macro = "MACRO",
    Action = "ACTION",
}

-- A catalog entry consists of enough information to be used in the binding
-- user interface:
--   * type [catalog.entryType]: What type of entry is this
--   * name: The name of the entry
--   * icon: The icon to use for the entry
--   * id: The id used for this entry, typically spellId or macroIndex
--   * passive: true if this spell is passive
--   * offspec: true if this spell is for an offspec talent spec
--   * globalMacro: true if this macro is a global macro
--   * characterMacro: true if this macro is a character macro
function catalog:CreateEntry(entryType, orderIndex, name, icon, id, passive, offspec, globalMacro, characterMacro, spellbookTabIndex)
    return {
        entryType = entryType,
        orderIndex = orderIndex,
        name = name,
        icon = icon,
        id = id,
        passive = passive,
        offspec = offspec,
        globalMacro = globalMacro,
        characterMacro = characterMacro,
        spellbookTabIndex = spellbookTabIndex,
    }
end

catalog.catalogType = {
    Spell = "SPELL",
    Pet = "PETSPELL",
    Macro = "MACRO",
    Action = "ACTION",
}

local function copyTable(tbl)
    local result = {}
    for k,v in pairs(tbl) do
        result[k] = v
    end
    return result
end

-- Create a filter on top of the catalog, used for implementing search
-- and including or excluding different catagories of entries
function catalog:CreateFilter(catalogFilters, settings)

    local catalogs = copyTable(catalogFilters)
    local opts = copyTable(settings)

    local filter = {
        catalogFilters = catalogs
    }

    -- Filter by name
    if opts.name and opts.name ~= "" then
        -- strip out non-alpha and space chars
        local name = opts.name:gsub("[^a-zA-Z0-9%s]", ""):lower()
        filter.name = name
    end

    -- Filter by spellbook tab
    filter.spellbookTab = opts.spellbookTab

    -- Include spells from "General" tab
    filter.generalTab = not not opts.includeGeneralTab

    -- Include passive spells
    filter.passiveSpells = not not opts.includePassives

    -- Include offspec spells
    filter.offspecSpells = not not opts.includeOffspec

    -- Include global macros
    filter.globalMacros = not not opts.includeGlobalMacros

    -- Include character macros
    filter.characterMacros = not not opts.includeCharacterMacros

    return filter
end

local function shallowEquals(a, b)
    for k,v in pairs(a) do
        if b[k] ~= v then
            return false
        end
    end

    for k,v in pairs(b) do
        if a[k] ~= v then
            return false
        end
    end

    return true
end

function catalog:FiltersEqual(left, right)
    if not shallowEquals(left.catalogFilters, right.catalogFilters) then
        return false
    end

    if left.name ~= right.name then return false end

    if left.spellbookTab ~= right.spellbookTab then return false end
    if left.passiveSpells ~= right.passiveSpells then return false end
    if left.offspecSpells ~= right.offspecSpells then return false end
    if left.globalMacros ~= right.globalMacros then return false end
    if left.characterMacros ~= right.characterMacros then return false end
    if left.generalTab ~= right.generalTab then return false end
    return true
end

function catalog:UpdateNameFilter(filter, searchText)
    if type(searchText) == "string" then
        searchText = searchText:gsub("[^a-zA-Z0-9%s]", ""):lower()
    end

    if searchText == "" then
        searchText = nil
    end

    -- No change needed!
    if searchText == filter.name then
        return filter
    end

    local newFilter = {}
    for k,v in pairs(filter) do
        newFilter[k] = v
    end

    newFilter.name = searchText
    return newFilter
end


-- Apply a filter to catalog list
function catalog:ApplyFilter(catalogList, filter)
    local filteredResults = {}

    for idx, entry in ipairs(catalogList) do
        local matchesFilter = true

        if not filter.catalogFilters[entry.entryType] then
            matchesFilter = false
        end

        if filter.name and not entry.name:lower():match(filter.name) then
            matchesFilter = false
        end

        if (not filter.generalTab) and (entry.spellbookTabIndex == 1) then
            matchesFilter = false
        end

        if (not filter.passiveSpells) and entry.passive then
            matchesFilter = false
        end

        if (not filter.offspecSpells) and entry.offspec then
            matchesFilter = false
        end

        -- Macros
        if (not filter.globalMacros) and entry.globalMacro then
            matchesFilter = false
        end

        if (not filter.characterMacros) and entry.characterMacro then
            matchesFilter = false
        end

        if matchesFilter then
            table.insert(filteredResults, entry)
        end
    end

    return filteredResults
end

-- Merge two catalogs together
function catalog:MergeCatalogs(left, right)
    local mergedResults = {}

    for idx, entry in ipairs(left) do
        mergedResults[#mergedResults+1] = entry
    end

    for idx, entry in ipairs(right) do
        mergedResults[#mergedResults+1] = entry
    end

    return mergedResults
end

local defaultSortFunction = function(a, b)
    return a.orderIndex < b.orderIndex
end

function catalog:SortCatalog(entries)
    table.sort(entries, defaultSortFunction)
end
