--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II
-------------------------------------------------------------------]] ---

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

---@class BindingConfig
local config = addon:GetBindingConfig()

local page = {}
page.importValidated = false
page.importBindingData = nil
page.importAddMode = false

function config:GetProfilePage()
    return page
end

local CONFIRM_DELETE_DIALOG = "CLIQUE_CONFIRM_PROFILE_DELETE"
local NEW_PROFILE_DIALOG    = "CLIQUE_PROFILE_NEW_PROFILE"
local CONFIRM_IMPORT_DIALOG = "CLIQUE_PROFILE_CONFIRM_IMPORT"

local function messageAndSwitchProfile(profileName)
    addon.db:SetProfile(profileName)
    addon:Printf(L["Created and switched to new profile: %s"], profileName)
    page:Refresh()
end

local function registerDialogs()
    StaticPopupDialogs[CONFIRM_DELETE_DIALOG] = {
        preferredIndex = STATICPOPUPS_NUMDIALOGS,
        button1        = L["Yes"],
        button2        = L["No"],
        hideOnEscape   = 1,
        timeout        = 0,
        whileDead      = 1,
    }

    StaticPopupDialogs[NEW_PROFILE_DIALOG] = {
        preferredIndex         = STATICPOPUPS_NUMDIALOGS,
        text                   = L["Enter the name of a new profile you'd like to create"],
        button1                = L["Okay"],
        button2                = L["Cancel"],
        OnAccept               = function(self)
            messageAndSwitchProfile(_G[self:GetName() .. "EditBox"]:GetText())
        end,
        timeout                = 0,
        whileDead              = 1,
        exclusive              = 1,
        showAlert              = 1,
        hideOnEscape           = 1,
        hasEditBox             = 1,
        maxLetters             = 32,
        OnShow                 = function(self)
            _G[self:GetName() .. "Button1"]:Disable()
            _G[self:GetName() .. "EditBox"]:SetFocus()
        end,
        EditBoxOnEnterPressed  = function(self)
            local btn = _G[self:GetParent():GetName() .. "Button1"]
            if addon:APIIsTrue(btn:IsEnabled()) then
                messageAndSwitchProfile(_G[self:GetParent():GetName() .. "EditBox"]:GetText())
            end
            self:GetParent():Hide()
        end,
        EditBoxOnTextChanged   = function(self)
            local txt = _G[self:GetParent():GetName() .. "EditBox"]:GetText()
            if #txt > 0 then
                _G[self:GetParent():GetName() .. "Button1"]:Enable()
            else
                _G[self:GetParent():GetName() .. "Button1"]:Disable()
            end
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
            ClearCursor()
        end,
    }

    StaticPopupDialogs[CONFIRM_IMPORT_DIALOG] = {
        preferredIndex = STATICPOPUPS_NUMDIALOGS,
        button1        = L["Yes"],
        button2        = L["No"],
        hideOnEscape   = 1,
        timeout        = 0,
        whileDead      = 1,
    }
end

local PROFILE_PAGE_SIZE = 20

local function addProfileEntry(desc, profileName, isCurrent)
    local entry = desc:CreateButton(profileName)
    entry:CreateTitle(L["Profile: %s"]:format(profileName))
    entry:CreateButton(L["Select profile: %s"]:format(profileName), function()
        addon.db:SetProfile(profileName)
        addon:Printf(L["Switching to profile: %s"], profileName)
        page:Refresh()
    end)
    if not isCurrent then
        entry:CreateButton(L["Delete profile: %s"]:format(profileName), function()
            local dialog = StaticPopupDialogs[CONFIRM_DELETE_DIALOG]
            dialog.text = L["Delete profile '%s'"]:format(profileName)
            dialog.OnAccept = function()
                addon.db:DeleteProfile(profileName)
                addon:Printf(L["Deleted profile: %s"], profileName)
                page:Refresh()
            end
            StaticPopup_Show(CONFIRM_DELETE_DIALOG)
        end)
    end
end

local PROFILE_NAME_LABEL_LIMIT = 12
local function splitOrTruncateProfileName(name)
    local first = strsplit("-", name)
    return first:sub(1, PROFILE_NAME_LABEL_LIMIT):trim()
end

local function buildProfileMenu(_, rootDescription)
    local current  = addon.db:GetCurrentProfile()
    local profiles = addon.db:GetProfiles()
    table.sort(profiles)

    if #profiles < PROFILE_PAGE_SIZE then
        for _, name in ipairs(profiles) do
            addProfileEntry(rootDescription, name, name == current)
        end
    else
        for i = 1, #profiles, PROFILE_PAGE_SIZE do
            local endIdx = math.min(i + PROFILE_PAGE_SIZE - 1, #profiles)
            local label  = string.format("%s ... %s",
                splitOrTruncateProfileName(profiles[i]),
                splitOrTruncateProfileName(profiles[endIdx]))
            local groupBtn = rootDescription:CreateButton(label)
            for j = i, endIdx do
                addProfileEntry(groupBtn, profiles[j], profiles[j] == current)
            end
        end
    end

    rootDescription:CreateDivider()
    rootDescription:CreateButton(L["Add new profile"], function()
        StaticPopup_Show(NEW_PROFILE_DIALOG)
    end)
end

local function buildSpecMenu(specKey)
    return function(_, rootDescription)
        local profiles = addon.db:GetProfiles()
        table.sort(profiles)

        local function addSpecRadio(desc, name)
            desc:CreateRadio(name,
                function() return addon.settings[specKey] == name end,
                function()
                    addon.settings[specKey] = name
                    addon:TalentGroupChanged()
                    page:Refresh()
                end)
        end

        if #profiles < PROFILE_PAGE_SIZE then
            for _, name in ipairs(profiles) do
                addSpecRadio(rootDescription, name)
            end
        else
            for i = 1, #profiles, PROFILE_PAGE_SIZE do
                local endIdx = math.min(i + PROFILE_PAGE_SIZE - 1, #profiles)
                local label  = string.format("%s ... %s",
                    splitOrTruncateProfileName(profiles[i]),
                    splitOrTruncateProfileName(profiles[endIdx]))
                local groupBtn = rootDescription:CreateButton(label)
                for j = i, endIdx do
                    addSpecRadio(groupBtn, profiles[j])
                end
            end
        end
    end
end

function page:Show()
    page.frame:ClearAllPoints()
    page.frame:SetAllPoints(config.ui)
    page.frame:Show()
    page:Refresh()
end

function page:Hide()
    page.frame:Hide()
    page.frame:ClearAllPoints()
    page.frame:SetPoint("RIGHT", UIParent, "LEFT", 0, 0)
end

function page:IsShown()
    return page.frame:IsShown()
end

function page:Initialize()
    if page.initialized then return end
    page.initialized = true
    registerDialogs()

    page.frame = CreateFrame("Frame", "CliqueConfigUIBindingFrameProfilePage", config.ui)
    local frame = page.frame
    frame:SetAllPoints()
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -60)
    frame.title:SetText(L["Profile Management"])

    frame.backButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.backButton:SetText(L["Back"])
    frame.backButton:SetHeight(23)
    frame.backButton:SetWidth(120)
    frame.backButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 5)
    frame.backButton:SetScript("OnClick", function()
        config:SwitchToBrowsePage()
    end)

    frame.dataProvider, frame.listContainer = config:CreateSettingsList(frame,
        { frame, "TOPLEFT", 10, -90 },
        { frame, "BOTTOMRIGHT", -30, 40 },
        { backdrop = false })

    addon:RegisterMessage("BINDINGS_CHANGED", page.OnBindingsChanged)
end

function page.OnBindingsChanged()
    if page:IsShown() then
        page:Refresh()
    end
end

function page:Refresh()
    page.importValidated   = false
    page.importBindingData = nil

    local dataProvider = page.frame.dataProvider
    dataProvider:Flush()

    local settings       = addon.settings
    local currentProfile = addon.db:GetCurrentProfile()

    dataProvider:Insert({
        rowType     = "dropdown",
        label       = L["Profile Management:"],
        buttonText  = currentProfile,
        menuBuilder = buildProfileMenu,
    })

    if addon:PlayerHasMultiTalentSpecs() then
        dataProvider:Insert({
            label    = L["Swap profiles based on talent spec"],
            checked  = settings.specswap,
            onToggle = function(_, checked)
                settings.specswap = checked
                if checked then addon:TalentGroupChanged() end
                C_Timer.After(0, function() page:Refresh() end)
            end,
        })

        for i = 1, addon:GetNumTalentSpecs() do
            local specKey = "spec" .. i .. "_profileKey"
            dataProvider:Insert({
                rowType     = "dropdown",
                label       = L["Talent profile: %s"]:format(addon:GetTalentSpecName(i)),
                buttonText  = settings[specKey] or currentProfile,
                enabled     = settings.specswap,
                menuBuilder = buildSpecMenu(specKey),
            })
        end
    end

    dataProvider:Insert({
        rowType          = "editbox",
        label            = L["Export bindings:"],
        text             = "",
        buttonText       = L["Generate"],
        highlightOnFocus = true,
        onInit           = function(editbox, _)
            page.exportEditbox = editbox
        end,
        onButton = function(editbox, _)
            editbox:SetText(addon:GetExportString())
            editbox:SetFocus()
        end,
    })

    dataProvider:Insert({
        rowType       = "editbox",
        label         = L["Import bindings:"],
        text          = "",
        buttonText    = L["Validate"],
        onInit        = function(editbox, button)
            page.importEditbox = editbox
            page.importButton  = button
        end,
        onTextChanged = function(_)
            page.importValidated   = false
            page.importBindingData = nil
            if page.importButton then
                page.importButton:SetText(L["Validate"])
                page.importButton:Enable()
            end
        end,
        onButton = function(editbox, button)
            if page.importValidated then
                local addMode     = page.importAddMode
                local bindingData = page.importBindingData
                local dialog      = StaticPopupDialogs[CONFIRM_IMPORT_DIALOG]
                if addMode then
                    dialog.text = L["This will add the imported bindings to your current profile. Are you sure?"]
                else
                    dialog.text = L["This will replace all bindings in your current profile with the imported bindings. Are you sure?"]
                end
                dialog.OnAccept = function()
                    if addMode then
                        addon:MergeBindings(bindingData)
                    else
                        addon:ImportBindings(bindingData)
                    end
                end
                StaticPopup_Show(CONFIRM_IMPORT_DIALOG)
            else
                local bindingData = addon:DecodeExportString(editbox:GetText())
                if bindingData then
                    page.importValidated   = true
                    page.importBindingData = bindingData
                    button:SetText(L["Import"])
                else
                    button:SetText(L["Invalid!"])
                end
            end
        end,
    })

    dataProvider:Insert({
        label    = L["Add to existing bindings"],
        checked  = page.importAddMode,
        onToggle = function(_, checked)
            page.importAddMode = checked
        end,
    })
end
