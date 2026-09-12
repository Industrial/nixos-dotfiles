--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II
-------------------------------------------------------------------]] ---

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

addon.actionCatalog = {}

local lib = addon.actionCatalog
local catalog = addon.catalog

local TARGET_ICON = 132331
local MENU_ICON = 132212
local CUSTOMMACRO_ICON = 134332

lib.actionId = {
    TARGET      = "target",
    MENU        = "menu",
    CUSTOMMACRO = "custommacro",
    USETRINKET1 = "usetrinket1",
    USETRINKET2 = "usetrinket2",
}

lib.orderedActions = {
    lib.actionId.TARGET,
    lib.actionId.MENU,
    lib.actionId.CUSTOMMACRO,
    lib.actionId.USETRINKET1,
    lib.actionId.USETRINKET2,
}

local function getTrinketIcon(invSlot, slotName)
    local id = GetInventoryItemID("player", invSlot)
    local icon = id and GetInventoryItemTexture("player", invSlot)
    if icon then
        return icon
    end
    local _, fallbackIcon = GetInventorySlotInfo(slotName)
    return fallbackIcon
end

function lib:GetNameIconTypeUnit(actionId)
    if actionId == lib.actionId.TARGET then
        local name = L["Target unit"]
        local icon = TARGET_ICON
        local type = "target"
        local unit = "mouseover"

        return name, icon, type, unit
    elseif actionId == lib.actionId.MENU then
        local name = L["Open unit menu"]
        local icon = MENU_ICON
        local type = "menu"

        return name, icon, type
    elseif actionId == lib.actionId.CUSTOMMACRO then
        local name = L["Run custom macro"]
        local icon = CUSTOMMACRO_ICON
        local type = "macro"

        return name, icon, type
    elseif actionId == lib.actionId.USETRINKET1 then
        -- Literal strings (not parameterized) so translators have full context for each slot
        return L["Use item: Primary Trinket"], getTrinketIcon(13, "Trinket0Slot"), "item", nil, "13"
    elseif actionId == lib.actionId.USETRINKET2 then
        return L["Use item: Secondary Trinket"], getTrinketIcon(14, "Trinket1Slot"), "item", nil, "14"
    end
end

function lib:GetActionCatalogEntries()
    local results = {}

    local orderIndex = 0

    for idx, actionId in ipairs(lib.orderedActions) do
        orderIndex = orderIndex + 1

        local name, icon, type, unit = lib:GetNameIconTypeUnit(actionId)

        table.insert(results, catalog:CreateEntry(
            catalog.entryType.Action,
            orderIndex,
            name,
            icon,
            actionId,
            false,
            false,
            false,
            false,
            nil
        ))
    end

    return results
end
