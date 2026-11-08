--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- The Profiles settings page (docs/archive/settings-proposal.md, section 3, design
-- C). It shows the two AceDB databases: the options and the saved
-- waypoints. The profile behavior is AceDB's; this file only shows it.

local _, addon = ...
local TomTom = addon
local L = addon.L
addon.private = addon.private or {}
local private = addon.private

local MAX_PROFILE_NAME = 50

local profileSettings = {}

local function RefreshProfileRows()
    for _, setting in ipairs(profileSettings) do
        setting:NotifyUpdate()
    end
end

-- The databases are made at ADDON_LOADED, so each entry gets its db late.
local databases = {
    {
        id = "options",
        db = function() return TomTom.db end,
        title = L["Options profile"],
        help = L["The settings of TomTom. All characters use the shared profile until you choose another one."],
        sharedFirst = true,
    },
    {
        id = "waypoints",
        db = function() return TomTom.waydb end,
        title = L["Waypoints profile"],
        help = L["The saved waypoints. Each character has its own waypoints until you choose another profile. Characters on the same profile share their saved waypoints."],
        sharedFirst = false,
    },
}

-- The suggested profiles, with clear names. AceDB uses "Default" as the
-- shared profile name, and the character and class keys as their names.
local function ProfileLabels(entry)
    local db = entry.db()
    local labels = {}
    local order = {}

    local function add(name, label)
        if not labels[name] then
            labels[name] = label
            table.insert(order, name)
        end
    end

    local shared = {"Default", L["Shared by all characters"]}
    local character = {db.keys.char, L["This character only"] .. " (" .. db.keys.char .. ")"}
    local class = {db.keys.class, L["This class"] .. " (" .. (UnitClass("player") or db.keys.class) .. ")"}

    if entry.sharedFirst then
        add(shared[1], shared[2])
        add(character[1], character[2])
    else
        add(character[1], character[2])
        add(shared[1], shared[2])
    end
    if entry.id == "options" then
        add(class[1], class[2])
    end

    local existing = {}
    for _, name in ipairs(db:GetProfiles()) do
        table.insert(existing, name)
    end
    table.sort(existing)
    for _, name in ipairs(existing) do
        add(name, name)
    end
    return labels, order
end

local function CharactersOnProfile(db)
    local names = {}
    local sv = rawget(db, "sv")
    local current = db:GetCurrentProfile()
    for character, profile in pairs(sv and sv.profileKeys or {}) do
        if profile == current then
            table.insert(names, character)
        end
    end
    table.sort(names)
    return names
end

--[[--------------------------------------------------------------------------
--  Dialogs
----------------------------------------------------------------------------]]

local function GetEditBox(dialog)
    return dialog.GetEditBox and dialog:GetEditBox() or dialog.EditBox or dialog.editBox
end

StaticPopupDialogs["TOMTOM_NEW_PROFILE"] = {
    preferredIndex = STATICPOPUPS_NUMDIALOGS,
    text = L["Name of the new profile:"],
    button1 = ACCEPT or L["Yes"],
    button2 = CANCEL or L["No"],
    hasEditBox = 1,
    maxLetters = MAX_PROFILE_NAME,
    OnAccept = function(dialog, data)
        local name = strtrim(GetEditBox(dialog):GetText() or "")
        if name ~= "" then
            data.db():SetProfile(name)
            RefreshProfileRows()
        end
    end,
    EditBoxOnEnterPressed = function(editBox)
        local dialog = editBox:GetParent()
        StaticPopupDialogs["TOMTOM_NEW_PROFILE"].OnAccept(dialog, dialog.data)
        dialog:Hide()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

local function ConfirmDialog(name, text)
    StaticPopupDialogs[name] = {
        preferredIndex = STATICPOPUPS_NUMDIALOGS,
        text = text,
        button1 = L["Yes"],
        button2 = L["No"],
        OnAccept = function(_, data)
            data()
            RefreshProfileRows()
        end,
        timeout = 30,
        whileDead = 1,
        hideOnEscape = 1,
    }
end

ConfirmDialog("TOMTOM_COPY_PROFILE", L["Copy all settings from the profile '%s' into the current profile?"])
ConfirmDialog("TOMTOM_DELETE_PROFILE", L["Delete the profile '%s'?"])
ConfirmDialog("TOMTOM_RESET_PROFILE", L["Reset the profile '%s' to the defaults?"])

local function ShowManageMenu(entry)
    local db = entry.db()
    local current = db:GetCurrentProfile()
    local others = {}
    for _, name in ipairs(db:GetProfiles()) do
        if name ~= current then
            table.insert(others, name)
        end
    end
    table.sort(others)

    MenuUtil.CreateContextMenu(UIParent, function(_, root)
        root:CreateTitle(entry.title)
        root:CreateButton(L["New profile..."], function()
            StaticPopup_Show("TOMTOM_NEW_PROFILE", nil, nil, entry)
        end)

        local copy = root:CreateButton(L["Copy from"])
        local delete = root:CreateButton(L["Delete a profile"])
        for _, name in ipairs(others) do
            copy:CreateButton(name, function()
                StaticPopup_Show("TOMTOM_COPY_PROFILE", name, nil, function() db:CopyProfile(name) end)
            end)
            delete:CreateButton(name, function()
                StaticPopup_Show("TOMTOM_DELETE_PROFILE", name, nil, function() db:DeleteProfile(name) end)
            end)
        end

        root:CreateButton(L["Reset profile"], function()
            StaticPopup_Show("TOMTOM_RESET_PROFILE", current, nil, function() db:ResetProfile() end)
        end)
    end)
end

--[[--------------------------------------------------------------------------
--  Page
----------------------------------------------------------------------------]]

local function AddDatabaseSection(page, entry)
    page:AddInitializer(CreateSettingsListSectionHeaderInitializer(entry.title))
    page:AddInitializer(private.CreateTextInitializer({text = entry.help}))

    local variable = "TOMTOM_PROFILE_" .. entry.id:upper()
    local db = entry.db()
    local setting = private.CreateUnregisteredSetting(page.category, variable, Settings.VarType.String,
        L["Profile in use"], db:GetCurrentProfile(),
        function() return entry.db():GetCurrentProfile() end,
        function(value)
            entry.db():SetProfile(value)
            RefreshProfileRows()
        end)
    table.insert(profileSettings, setting)

    local function GetOptions()
        local labels, order = ProfileLabels(entry)
        local container = Settings.CreateControlTextContainer()
        for _, name in ipairs(order) do
            container:Add(name, labels[name])
        end
        return container:GetData()
    end
    page:AddInitializer(Settings.CreateDropdownInitializer(setting, GetOptions,
        L["The profile that this character uses."]))

    page:AddInitializer(private.CreateTextInitializer({
        watchVariables = {variable},
        textFunc = function()
            local names = CharactersOnProfile(entry.db())
            return L["Characters on this profile:"] .. " " .. (#names > 0 and table.concat(names, ", ") or "-")
        end,
    }))

    page:AddInitializer(CreateSettingsButtonInitializer(L["Manage profiles..."],
        L["Manage profiles..."], function() ShowManageMenu(entry) end,
        L["Make, copy, delete or reset a profile."], true))
end

-- Called by BuildSettings, after the other pages.
function private.BuildProfilesPage(parentCategory)
    local page = private.CreateSettingsPage(L["Profiles"], parentCategory)
    for _, entry in ipairs(databases) do
        AddDatabaseSection(page, entry)
    end
    return page.category
end

-- The waypoints database has no TOMTOM_PROFILE_CHANGED message, so the
-- profile rows refresh on both kinds of change.
TomTom:RegisterMessage("TOMTOM_PROFILE_CHANGED", RefreshProfileRows)
