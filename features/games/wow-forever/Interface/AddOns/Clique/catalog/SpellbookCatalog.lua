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
        local isOffspec = skillLineInfo.offSpecID ~= nil
        return name, texture, numSpells, offset, shouldHide, isOffspec
    else
        local name, texture, offset, numSpells, isGuild, offSpecID, shouldHide = GetSpellTabInfo(idx)
        local isOffspec = (offSpecID ~= 0)
        return name, texture, numSpells, offset, shouldHide, isOffspec
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
    local flyoutSpellID, overrideSpellID, isKnown, spellName, slotSpecID = GetFlyoutSlotInfo(actionId, flyoutIdx)
    return flyoutSpellID
end

function lib:GetSpellCatalogEntries(orderIndex)
    local results = {}
    local bookType = self:GetSpellbookType()

    local spellbookIdx = orderIndex + 1

    for tabIdx = 1, self:GetNumTabs() do
        local tabName, tabTexture, numSpells, offset, shouldHide, isOffspec = self:GetTabInfo(tabIdx)

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
                    local numFlyoutSlots = self:GetNumFlyoutSlots(spellId)

                    for flyoutIdx = 1, numFlyoutSlots do
                        local flyoutSpellId = self:GetFlyoutSpellId(spellId, flyoutIdx)
                        local name, icon = self:GetSpellNameTexture(flyoutSpellId)
                        local passive = self:GetSpellPassive(flyoutSpellId)
                        local offspec = isOffspec

                        spellbookIdx = spellbookIdx + 1
                        table.insert(results, catalog:CreateEntry(
                            catalog.entryType.Spell,
                            spellbookIdx,
                            name,
                            icon,
                            flyoutSpellId,
                            passive,
                            offspec,
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
