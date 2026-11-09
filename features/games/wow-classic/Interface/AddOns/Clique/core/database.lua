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
        -- Removed in 5.1.0 (the beta editor became the edit page); kept reserved.
        -- betaBindingEditor = false,
    },
    profile = {
        bindings = {
        },
    },
    global = {
        changelogDoNotShow       = false,
        lastSeenChangelogVersion = nil,
        -- profileBackups has no default: BackupCurrentProfile creates it.
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
    -- Other profiles are untouched until they become active, so back them up now
    self:BackupCurrentProfile()
    self.bindings = db.profile.bindings
    self:FireMessage("BINDINGS_CHANGED")
end

function addon:ImportBindings(importBindings)
    self.db.profile.bindings = importBindings
    self.bindings = self.db.profile.bindings
    self:Printf(L["Importing new bindings into current profile"])
    self:FireMessage("BINDINGS_CHANGED")
end

local BACKUP_VERSION = "5.1"

-- Kept here, not in the dialog's data, so the standard UI never holds the bindings
local pendingRestore

-- 5.1 changes which binding wins on a shared key, so keep a copy of each
-- profile's bindings from before it. See docs/options.md.
function addon:BackupCurrentProfile()
    local profile = self.db:GetCurrentProfile()
    local backups = self.db.global.profileBackups or {}
    self.db.global.profileBackups = backups
    local existing = backups[profile]
    if existing and existing.version == BACKUP_VERSION then
        return
    end

    -- A failed export must never stop the addon from loading
    local ok, exported = pcall(self.GetExportString, self)
    if not ok or not exported then
        return
    end

    backups[profile] = {
        version = BACKUP_VERSION,
        created = time(),
        bindings = exported,
    }
end

function addon:RestoreCurrentProfileBackup()
    local profile = self.db:GetCurrentProfile()
    local backup = self.db.global.profileBackups and self.db.global.profileBackups[profile]
    if not backup then
        self:Printf(L["There is no backup of the bindings in profile '%s'."], profile)
        return
    end
    if InCombatLockdown() then
        self:Printf(L["Cannot restore bindings while in combat lockdown"])
        return
    end

    local ok, bindings = pcall(self.DecodeExportString, self, backup.bindings)
    if not ok or type(bindings) ~= "table" then
        self:Printf(L["The backup of profile '%s' cannot be read."], profile)
        return
    end

    pendingRestore = { profile = profile, bindings = bindings }
    StaticPopup_Show(self.dialogs.RESTORE_BACKUP, profile, date("%Y-%m-%d %H:%M", backup.created))
end

-- The profile can change (e.g. a spec swap) while the dialog is open
function addon:ConfirmProfileBackupRestore()
    local restore = pendingRestore
    pendingRestore = nil
    if not restore then
        return
    end

    local profile = self.db:GetCurrentProfile()
    if profile ~= restore.profile then
        self:Printf(L["The active profile is now '%s', so the backup of profile '%s' was not restored."], profile, restore.profile)
        return
    end
    self:ImportBindings(restore.bindings)
end

function addon:MergeBindings(importBindings)
    for _, binding in ipairs(importBindings) do
        table.insert(self.db.profile.bindings, binding)
    end
    self.bindings = self.db.profile.bindings
    self:Printf(L["Added %d bindings to current profile"], #importBindings)
    self:FireMessage("BINDINGS_CHANGED")
end
