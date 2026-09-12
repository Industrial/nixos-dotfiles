--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

local addonName = select(1, ...)

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

addon.databaseDefaults = {
    char = {
        disableInHousing = true,
        blacklist = {},
        blizzframes = {
            -- Fix the health and mana bars
            statusBarFix = true,

            -- Removed in 5.0.0; kept reserved so the key is never reused.
            -- wipeMenuAction = false,

            -- Default frames enabled
            PlayerFrame = true,
            PetFrame = true,
            TargetFrame = true,
            TargetFrameToT = true,
            FocusFrame = true,
            FocusFrameToT = true,
            arena = true,
            party = true,
            compactraid = true,
            compactparty = true,
            boss = true,
        },
        stopcastingfix = false,
        -- Fires bindings on the "down", "up", or "both" edge of a click/keypress.
        clickDirection = "down",
        -- Frame->proxy transport: "click" or "macrotext". See docs/attributes.md.
        dispatchMode = "click",
        enableGamePad = false,

        -- Removed in 5.0.0; kept reserved so the keys are never reused.
        -- downClick = true,            -- superseded by clickDirection above
        -- removeWildcardActions = false, -- the wildcard-stripping feature was removed
        showBindingTooltip = false,
        tooltipAnchor = "ANCHOR_BOTTOMRIGHT",
        dismissTargetMenuWarning = false,
    },
    profile = {
        bindings = {
        },
    },
    global = {
        changelogDoNotShow       = false,
        lastSeenChangelogVersion = nil,
    },
}

-- A new profile is being created in the db, called 'profile'
function addon:OnNewProfile(event, db, profile)
    table.insert(db.profile.bindings, {
        key = "BUTTON1",
        type = "target",
        unit = "mouseover",
        sets = {
            default = true
        },
    })

    table.insert(db.profile.bindings, {
        key = "BUTTON2",
        type = "menu",
        sets = {
            default = true
        },
    })
    self.bindings = db.profile.bindings
end

function addon:OnProfileChanged(event, db, newProfile)
    self.bindings = db.profile.bindings
    self:FireMessage("BINDINGS_CHANGED")
end

function addon:ImportBindings(importBindings)
    self.db.profile.bindings = importBindings
    self.bindings = self.db.profile.bindings
    self:Printf(L["Importing new bindings into current profile"])
    self:FireMessage("BINDINGS_CHANGED")
end

function addon:MergeBindings(importBindings)
    for _, binding in ipairs(importBindings) do
        table.insert(self.db.profile.bindings, binding)
    end
    self.bindings = self.db.profile.bindings
    self:Printf(L["Added %d bindings to current profile"], #importBindings)
    self:FireMessage("BINDINGS_CHANGED")
end
