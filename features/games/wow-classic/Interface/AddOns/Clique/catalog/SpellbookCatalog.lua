--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II

This file contains an abstraction of the spellbook APIs, ensuring that
Clique has a common interface between different versions of WoW.
-------------------------------------------------------------------]] ---


---@class CliqueAddon: AddonCore
local addon = select(2, ...)

addon.spellbookCatalog = {}

local lib = addon.spellbookCatalog
local catalog = addon.catalog

local Enum = Enum
local C_Spell = C_Spell
local C_SpellBook = C_SpellBook

function lib:GetSpellbookType()
    if Enum and Enum.SpellBookSpellBank then
        return Enum.SpellBookSpellBank.Player
    else
        return "spell"
    end
end

function lib:GetNumTabs()
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        return C_SpellBook.GetNumSpellBookSkillLines()
    else
        return GetNumSpellTabs()
    end
end

function lib:GetTabInfo(idx)
    if C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo then
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(idx)
        local name = skillLineInfo.name
        local texture = skillLineInfo.iconID
        local numSpells = skillLineInfo.numSpellBookItems
        local offset = skillLineInfo.itemIndexOffset
        local shouldHide = skillLineInfo.shouldHide
        local offSpecID = skillLineInfo.offSpecID
        local isOffspec = offSpecID ~= nil
        return name, texture, numSpells, offset, shouldHide, isOffspec, offSpecID
    else
        local name, texture, offset, numSpells, _isGuild, offSpecID, shouldHide = GetSpellTabInfo(idx)
        local isOffspec = (offSpecID ~= 0)
        local tabOffSpecID = isOffspec and offSpecID or nil
        return name, texture, numSpells, offset, shouldHide, isOffspec, tabOffSpecID
    end
end

function lib:IsSpell(idx, bookType)
    if C_SpellBook and C_SpellBook.GetSpellBookItemType then
        local spellType, actionId = C_SpellBook.GetSpellBookItemType(idx, bookType)
        return spellType == Enum.SpellBookItemType.Spell
    else
        local spellType, actionId = GetSpellBookItemInfo(idx, bookType)
        return spellType == "SPELL"
    end
end

function lib:IsFutureSpell(idx, bookType)
    if C_SpellBook and C_SpellBook.GetSpellBookItemType then
        local spellType, actionId = C_SpellBook.GetSpellBookItemType(idx, bookType)
        return spellType == Enum.SpellBookItemType.FutureSpell
    else
        local spellType, actionId = GetSpellBookItemInfo(idx, bookType)
        return spellType == "FUTURESPELL"
    end
end

function lib:IsFlyout(idx, bookType)
    if C_SpellBook and C_SpellBook.GetSpellBookItemType then
        local spellType, actionId = C_SpellBook.GetSpellBookItemType(idx, bookType)
        return spellType == Enum.SpellBookItemType.Flyout
    else
        local spellType, actionId = GetSpellBookItemInfo(idx, bookType)
        return spellType == "FLYOUT"
    end
end

function lib:IsPetSpell(idx, bookType)
    if C_SpellBook and C_SpellBook.GetSpellBookItemType then
        local spellType = C_SpellBook.GetSpellBookItemType(idx, bookType)
        return spellType == Enum.SpellBookItemType.PetAction
    else
        local spellType = GetSpellBookItemInfo(idx, bookType)
        return spellType == "PETACTION"
    end
end

function lib:IsOffSpec(idx, bookType)
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
        local info = C_SpellBook.GetSpellBookItemInfo(idx, bookType)
        return info.isPassive
    else
        local spellType, actionId = GetSpellBookItemInfo(idx, bookType)
        return spellType == "FLYOUT"
    end
end

function lib:GetSpellId(idx, bookType)
    if C_SpellBook and C_SpellBook.GetSpellBookItemType then
        local spellType, actionId, spellId = C_SpellBook.GetSpellBookItemType(idx, bookType)
        -- The spell might be overriden due to some talents
        if spellId and spellId ~= actionId then
            return spellId
        end

        return actionId
    else
        local spellType, actionId = GetSpellBookItemInfo(idx, bookType)
        return actionId
    end
end

function lib:GetSpellNameTexture(spellId)
    if C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellTexture then
        local name = C_Spell.GetSpellName(spellId)
        local icon = C_Spell.GetSpellTexture(spellId)
        return name, icon
    else
        local name, _, icon = GetSpellInfo(spellId)
        return name, icon
    end
end

function lib:GetSpellSubName(spellId)
    if C_Spell and C_Spell.GetSpellSubtext then
        local subText = C_Spell.GetSpellSubtext(spellId)
        return subText
    else
        local subText = GetSpellSubtext(spellId)
        return subText
    end
end

function lib:GetSpellPassive(spellId)
    if C_Spell and C_Spell.IsSpellPassive then
        local passive = C_Spell.IsSpellPassive(spellId)
        return passive
    else
        local passive = IsPassiveSpell(spellId)
        return passive
    end
end

function lib:GetNumFlyoutSlots(idx)
    local _, _, numFlyoutSlots = GetFlyoutInfo(idx)
    return numFlyoutSlots
end

function lib:GetFlyoutSpellId(actionId, flyoutIdx)
    local flyoutSpellID, _overrideSpellID, isKnown, _spellName, slotSpecID = GetFlyoutSlotInfo(actionId, flyoutIdx)
    return flyoutSpellID, isKnown, slotSpecID
end

---@class FlyoutSlot
---@field spellId number
---@field name string
---@field icon number
---@field passive boolean

-- Only known slots, plus off-spec slots when offSpecID is given
---@param actionId number
---@param offSpecID number?
---@return FlyoutSlot[]
function lib:GetVisibleFlyoutSlots(actionId, offSpecID)
    local slots = {}

    for flyoutIdx = 1, self:GetNumFlyoutSlots(actionId) do
        local spellId, isKnown, slotSpecID = self:GetFlyoutSpellId(actionId, flyoutIdx)
        local isOffspecSlot = offSpecID ~= nil and slotSpecID == offSpecID
        local name, icon = self:GetSpellNameTexture(spellId)

        if (isKnown or isOffspecSlot) and name then
            table.insert(slots, {
                spellId = spellId,
                name = name,
                icon = icon,
                passive = self:GetSpellPassive(spellId),
            })
        end
    end

    return slots
end

function lib:GetSpellCatalogEntries(orderIndex)
    local results = {}
    local bookType = self:GetSpellbookType()

    local spellbookIdx = orderIndex + 1

    for tabIdx = 1, self:GetNumTabs() do
        local _tabName, _tabTexture, numSpells, offset, shouldHide, isOffspec, offSpecID = self:GetTabInfo(tabIdx)

        if not shouldHide then
            for idx = 1, numSpells do
                -- We unfold the flyout spells, so need to do some mapping here
                local realIdx = offset + idx
                local spellId = self:GetSpellId(realIdx, bookType)
                if self:IsSpell(realIdx, bookType) then
                    local name, icon = self:GetSpellNameTexture(spellId)
                    local passive = self:GetSpellPassive(spellId)
                    local offspec = isOffspec

                    spellbookIdx = spellbookIdx + 1
                    table.insert(results, catalog:CreateEntry(
                        catalog.entryType.Spell,
                        spellbookIdx,
                        name,
                        icon,
                        spellId,
                        passive,
                        offspec,
                        false,
                        false,
                        tabIdx
                    ))
                elseif self:IsFlyout(realIdx, bookType) then
                    for _, slot in ipairs(self:GetVisibleFlyoutSlots(spellId, offSpecID)) do
                        spellbookIdx = spellbookIdx + 1
                        table.insert(results, catalog:CreateEntry(
                            catalog.entryType.Spell,
                            spellbookIdx,
                            slot.name,
                            slot.icon,
                            slot.spellId,
                            slot.passive,
                            isOffspec,
                            false,
                            false,
                            tabIdx
                        ))
                    end
                end
            end
        end
    end

    return results
end
