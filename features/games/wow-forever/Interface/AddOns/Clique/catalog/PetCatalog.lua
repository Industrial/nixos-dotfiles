--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II

This file abstracts the pet spellbook APIs. Pet spells are a flat list
rather than the tab-based player spellbook, so the spell resolution
helpers from addon.spellbookCatalog are reused against the pet bank.
-------------------------------------------------------------------]] ---


---@class CliqueAddon: AddonCore
local addon = select(2, ...)

addon.petCatalog = {}

local lib = addon.petCatalog
local catalog = addon.catalog
local spellbook = addon.spellbookCatalog

local C_SpellBook = C_SpellBook

-- Branch on the modern item API rather than on Enum.SpellBookSpellBank: some
-- Classic clients expose the SpellBookSpellBank enum yet still use the legacy
-- string-keyed spellbook calls, which expect "pet" and choke on the numeric bank.
function lib:GetPetSpellbookType()
    if C_SpellBook and C_SpellBook.GetSpellBookItemType then
        return Enum.SpellBookSpellBank.Pet
    else
        return "pet"
    end
end

-- Classic's GetSpellBookItemInfo returns a packed pet-action id that can't be
-- passed to GetSpellInfo; the slot form of GetSpellInfo yields the real spellId.
function lib:GetPetSpellSlotInfo(slot, bookType)
    if C_SpellBook and C_SpellBook.GetSpellBookItemType then
        local spellId = spellbook:GetSpellId(slot, bookType)
        local name, icon = spellbook:GetSpellNameTexture(spellId)
        return spellId, name, icon
    else
        local name, _, icon, _, _, _, spellId = GetSpellInfo(slot, bookType)
        return spellId, name, icon
    end
end

function lib:GetNumPetSpells()
    if C_SpellBook and C_SpellBook.HasPetSpells then
        return C_SpellBook.HasPetSpells() or 0
    else
        return HasPetSpells() or 0
    end
end

function lib:GetPetCatalogEntries(orderIndex)
    local results = {}
    local bookType = self:GetPetSpellbookType()
    local numPetSpells = self:GetNumPetSpells()

    local spellbookIdx = orderIndex + 1

    for idx = 1, numPetSpells do
        local spellId, name, icon = self:GetPetSpellSlotInfo(idx, bookType)
        -- Pet command actions (Attack/Follow/stances) are PetAction items too but
        -- don't resolve to a castable spell name; skip anything we can't bind by name.
        if name and (spellbook:IsSpell(idx, bookType) or spellbook:IsPetSpell(idx, bookType)) then
            local passive = spellId and spellbook:GetSpellPassive(spellId) or false

            spellbookIdx = spellbookIdx + 1
            table.insert(results, catalog:CreateEntry(
                catalog.entryType.Pet,
                spellbookIdx,
                name,
                icon,
                spellId,
                passive,
                false,
                false,
                false,
                nil
            ))
        elseif spellbook:IsFlyout(idx, bookType) then
            local actionId = spellbook:GetSpellId(idx, bookType)
            local numFlyoutSlots = spellbook:GetNumFlyoutSlots(actionId)

            for flyoutIdx = 1, numFlyoutSlots do
                local flyoutSpellId = spellbook:GetFlyoutSpellId(actionId, flyoutIdx)
                local flyoutName, flyoutIcon = spellbook:GetSpellNameTexture(flyoutSpellId)
                local passive = spellbook:GetSpellPassive(flyoutSpellId)

                spellbookIdx = spellbookIdx + 1
                table.insert(results, catalog:CreateEntry(
                    catalog.entryType.Pet,
                    spellbookIdx,
                    flyoutName,
                    flyoutIcon,
                    flyoutSpellId,
                    passive,
                    false,
                    false,
                    false,
                    nil
                ))
            end
        end
    end

    return results
end
