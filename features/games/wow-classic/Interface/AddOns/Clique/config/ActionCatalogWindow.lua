--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II

This file contains an abstraction of the spellbook APIs, ensuring that
Clique has a common interface between different versions of WoW.
-------------------------------------------------------------------]] ---

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

local libCatalog = addon.catalog
local libActions = addon.actionCatalog
local libSpellbook = addon.spellbookCatalog
local libPet = addon.petCatalog
local libMacros = addon.macroCatalog

---@class BindingConfig
local config = addon:GetBindingConfig()

-- Globals used in this file
local GameFontHighlight = GameFontHighlight
local SearchBoxTemplate_OnTextChanged = SearchBoxTemplate_OnTextChanged

local window = {}

function config:GetActionCatalogWindow()
    return window
end

function window:Initialize()
    if window.initialized then
        return
    end

    window.initialized = true

    window.frame = CreateFrame("Frame", "CliqueConfigUIActionCatalogFrame", config.ui, "DefaultPanelTemplate")
    local cf = window.frame

    cf:SetHeight(450)
    cf:SetWidth(465)
    cf:SetFrameStrata("MEDIUM")

    cf:ClearAllPoints()
    cf:SetPoint("LEFT", config.ui, "RIGHT", -5, 0)

    cf.next = CreateFrame("Button", nil, cf)
    cf.next:SetHeight(32)
    cf.next:SetWidth(32)

    cf.next.bg = cf.next:CreateTexture(nil, "BACKGROUND")
    cf.next.bg:ClearAllPoints()
    cf.next.bg:SetAllPoints()
    cf.next.bg:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    cf.next:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    cf.next:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    cf.next:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    cf.next:ClearAllPoints()
    cf.next:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -5, 10)

    cf.prev = CreateFrame("Button", nil, cf)
    cf.prev:SetHeight(32)
    cf.prev:SetWidth(32)

    cf.prev.bg = cf.prev:CreateTexture(nil, "BACKGROUND")
    cf.prev.bg:ClearAllPoints()
    cf.prev.bg:SetAllPoints()
    cf.prev.bg:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    cf.prev:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    cf.prev:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    cf.prev:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    cf.prev:ClearAllPoints()
    cf.prev:SetPoint("RIGHT", cf.next, "LEFT", 0, 0)

    cf.pageSize = 16
    cf.buttons = {}

    for i = 1, cf.pageSize do
        local name = "CliqueUICatalogFrameButton" .. i
        local button = CreateFrame("Button", name, cf)
        button:SetHeight(32)
        button:SetWidth(32)

        button:EnableKeyboard(false)
        button:EnableMouseWheel(true)
        button:RegisterForClicks("AnyDown")

        -- Attach all behaviour scripts
        window:ActionCatalogButton_Initialize(button)

        button.background = button:CreateTexture(nil, "BACKGROUND")
        button.background:ClearAllPoints()
        button.background:SetAllPoints()
        button.background:SetAtlas("common-button-square-gray-up", false)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

        button.name = cf:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        local fontFile, height, flags = GameFontHighlight:GetFont()
        button.name:SetFont(fontFile, height, flags)
        button.name:SetText("Lorem Ipsum")
        button.name:SetJustifyH("LEFT")
        button.name:SetJustifyV("TOP")

        button.name:ClearAllPoints()
        button.name:SetPoint("LEFT", button, "RIGHT", 5, 0)
        button.name:SetWidth(175)

        table.insert(cf.buttons, button)
    end

    -- Disable keyboard until the right time
    for idx, button in ipairs(cf.buttons) do
        button:EnableKeyboard(false)
    end

    -- Layout the buttons
    for idx, button in ipairs(cf.buttons) do
        button:ClearAllPoints()
        if idx == 1 then
            button:SetPoint("TOPLEFT", cf, "TOPLEFT", 15, -75)
        else
            if idx % 2 == 0 then
                button:SetPoint("LEFT", cf.buttons[idx - 1], "RIGHT", 190, 0)
            else
                button:SetPoint("TOPLEFT", cf.buttons[idx - 2], "BOTTOMLEFT", 0, -10)
            end
        end
    end

    cf.searchBox = CreateFrame("EditBox", "CliqueConfigUISpellbookSearch", cf, "SearchBoxTemplate")

    cf.filterButton = CreateFrame("DropdownButton", "CliqueConfigUISpellbookFilterButton", cf, "WowStyle1FilterDropdownTemplate")
    cf.filterButton.ResetButton = CreateFrame("Button", "CliqueConfigUISpellbookFilterButtonReset", cf.filterButton)

    cf.searchBox:SetHeight(22)
    cf.searchBox:SetWidth(325)
    cf.searchBox:SetFrameStrata("DIALOG")
    cf.searchBox:ClearAllPoints()
    cf.searchBox:SetPoint("TOPLEFT", cf, "TOPLEFT", 20, -30)

    window.activeCatalogType = nil

    window:EnableCatalogTooltipsAndSetupQuickbind()
    window:EnableSearch()
    window:EnablePaging()
    window:ResetFilter()

    if TabSystemMixin then
        cf.tabSystem = CreateFrame("Frame", nil, cf, "TabSystemTemplate")
        cf.tabSystem.minTabWidth = 80
        cf.tabSystem:SetPoint("BOTTOMLEFT", cf, "BOTTOMLEFT", 15, -30)

        window.tabIDToCatalogType = {}
        cf.tabSystem:SetTabSelectedCallback(function(tabID)
            window:SetActiveTab(window.tabIDToCatalogType[tabID])
        end)

        local function addTab(catalogType, text)
            local tabID = cf.tabSystem:AddTab(text)
            window.tabIDToCatalogType[tabID] = catalogType
            return tabID
        end

        window.allTabID = addTab(nil, L["All"])
        addTab(libCatalog.catalogType.Spell, L["Spells"])
        window.petTabID = addTab(libCatalog.catalogType.Pet, L["Pet"])
        addTab(libCatalog.catalogType.Macro, L["Macros"])
        cf.tabSystem:SetTab(window.allTabID)
    end

    window:EnableCatalogFilter()

    window:UPDATE_CATALOG_WINDOW()

    local function triggerCatalogUpdate(self, elapsed)
        if not self.delay then
            self.delay = 0.1
        end

        self.delay = self.delay - elapsed
        if self.delay <= 0 then
            self:SetScript("OnUpdate", nil)
            self.delay = nil
            window:REFRESH_CATALOG_WINDOW()
        end
    end

    window.frame:SetScript("OnShow", function(self)
        local cf = window.frame

        if window.catalogDirty then
            window.catalogDirty = false
            window:REFRESH_CATALOG_WINDOW()
        end

        if not cf.tabSystem then
            return
        end

        local hasPet = libPet:GetNumPetSpells() > 0
        cf.tabSystem:SetTabShown(window.petTabID, hasPet)

        if not hasPet and window.activeCatalogType == libCatalog.catalogType.Pet then
            cf.tabSystem:SetTab(window.allTabID)
        end
    end)

    window.frame:RegisterEvent("SPELLS_CHANGED")
    window.frame:RegisterEvent("UPDATE_MACROS")

    -- Spec swaps and talent edits update the spellbook asynchronously, so a
    -- short debounce isn't enough; refresh on a longer delayed dirty flag.
    window.frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    if addon:ProjectIsRetail() then
        window.frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    end

    window.frame:SetScript("OnEvent", function(self, event, ...)
        if event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
            window.catalogDirty = true
            if self:IsVisible() then
                window:ScheduleDelayedRefresh()
            end
        elseif self:IsVisible() then
            self:SetScript("OnUpdate", triggerCatalogUpdate)
        end
    end)
end

-- Coalesce a burst of talent change events into a single refresh, giving the
-- spellbook API time to settle before we re-read the catalog. If the window is
-- closed before the timer fires, catalogDirty stays set so OnShow refreshes.
function window:ScheduleDelayedRefresh()
    if window.refreshPending then
        return
    end

    window.refreshPending = true
    C_Timer.After(1.0, function()
        window.refreshPending = false
        if window.frame:IsVisible() then
            window.catalogDirty = false
            window:REFRESH_CATALOG_WINDOW()
        end
    end)
end

local function ActionCatalogButton_OnClick(self, button)
    -- If we're quickbinding then do quickbindy things
    if config:InQuickbindMode() then
        local captured = addon:GetCapturedKey(button)
        window:AddNewBindingFromButton(self, captured)
    elseif config:EditPageShown() then
        local entryType = self.type
        local entryId = self.id
        config:SendActionToEditPage(entryType, entryId)
    elseif config:BrowsePageShown() then
        local entryType = self.type
        local entryId = self.id
        config:SendActionToNewEditPage(entryType, entryId)
    end
end

local function ActionCatalogButton_OnKeyDown(button, key)
    -- If we're quickbinding then do quickbindy things
    if config:InQuickbindMode() then
        local captured = addon:GetCapturedKey(key)
        window:AddNewBindingFromButton(button, captured)
    end
end


local function ActionCatalogButton_OnMouseWheel(activeButton, delta)
    -- If we're quickbinding then do quickbindy things
    if config:InQuickbindMode() then
        local button = (delta > 0) and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"
        local captured = addon:GetCapturedKey(button)
        window:AddNewBindingFromButton(activeButton, captured)
    end
end

local function ActionCatalogButton_OnGamePadButtonDown(button, key)
    if config:InQuickbindMode() then
        local captured = addon:GetCapturedKey(key)
        window:AddNewBindingFromButton(button, captured)
    end
end

function window:ActionCatalogButton_Initialize(button)
    button:SetScript("OnClick", ActionCatalogButton_OnClick)
    button:SetScript("OnKeyDown", ActionCatalogButton_OnKeyDown)
    button:SetScript("OnMouseWheel", ActionCatalogButton_OnMouseWheel)
    button:SetScript("OnGamePadButtonDown", ActionCatalogButton_OnGamePadButtonDown)
    button:EnableGamePadButton(false)
end

function window:AddNewBindingFromButton(button, key)
    local actionAttributes = config:GetActionAttributes(button.type, button.id)

    if not actionAttributes.type then
        return
    end

    if not key then
        return
    end

    -- Add the binding, using the config object
    local draft = config:GetDefaultBindTable()
    config:CopyActionFromTo(actionAttributes, draft)
    draft.key = key

    local keyText = addon:GetBindingKeyComboText(draft)
    local actionText = addon:GetBindingActionText(draft.type, draft)
    addon:Printf(L["Added '%s' to '%s'"]:format(actionText, keyText))

    config:AddBinding(draft)
end

local function ActionCatalogButton_OnEnter(button, motion)
    -- Check if we're quickbinding, we need to do some extra things there
    if config:InQuickbindMode() then
        button:EnableKeyboard(true)
        if addon:IsGamePadEnabled() then
            button:EnableGamePadButton(true)
        end
    end

    config:ShowTooltip(button, button.type, button.id)
end

local function ActionCatalogButton_OnLeave(self, motion)
    self:EnableKeyboard(false)
    self:EnableGamePadButton(false)
    config:HideTooltip()
end

function window:EnableCatalogTooltipsAndSetupQuickbind(u)
    local cf = window.frame

    for idx, button in ipairs(cf.buttons) do
        button:SetScript("OnEnter", ActionCatalogButton_OnEnter)
        button:SetScript("OnLeave", ActionCatalogButton_OnLeave)
    end
end

function window:EnableSearch()
    local cf = window.frame

    cf.searchBox:SetScript("OnTextChanged", function(me)
        SearchBoxTemplate_OnTextChanged(me)
        window:SetFilterSearchText(me:GetText())
    end)
end

function window:EnablePaging()
    local cf = window.frame

    cf.page = 0
    cf.prev:SetScript("OnClick", function(button)
        local newPage = cf.page - 1
        if newPage < 0 then
            newPage = 0
        end

        cf.page = newPage

        if cf.page == 0 then
            cf.prev:Disable()
        elseif cf.page >= 1 then
            cf.prev:Enable()
        end

        window:CATALOG_FILTER_CHANGED()
    end)

    cf.next:SetScript("OnClick", function(button)
        cf.page = cf.page + 1
        cf.prev:Enable()
        window:CATALOG_FILTER_CHANGED()
    end)

    cf:SetScript("OnMouseWheel", function(frame, delta)
        if delta > 0 and cf.next:IsEnabled() then
            cf.next:Click()
        elseif delta < 0 and cf.prev:IsEnabled() then
            cf.prev:Click()
        end
    end)
end

function window:GetDefaultFilterSettings()
    return {
        settings = {
            includePassives = false,
            includeOffspec = false,
            includeGlobalMacros = true,
            includeCharacterMacros = true,
            includeGeneralTab = false,
            name = "",
        }
    }
end

function window:GetDefaultFilter()
    if not window.defaultFilter then
        local defaultSettings = window:GetDefaultFilterSettings()
        window.defaultFilter = window:GetFilterFromSettings(defaultSettings)
    end

    return window.defaultFilter
end

function window:GetFilterFromSettings(filterSettings)
    local activeType = window.activeCatalogType
    local catalogs = {
        [libCatalog.catalogType.Action] = not activeType,
        [libCatalog.catalogType.Spell]  = not activeType or activeType == libCatalog.catalogType.Spell,
        [libCatalog.catalogType.Pet]    = not activeType or activeType == libCatalog.catalogType.Pet,
        [libCatalog.catalogType.Macro]  = not activeType or activeType == libCatalog.catalogType.Macro,
    }
    return libCatalog:CreateFilter(catalogs, filterSettings.settings)
end

function window:SetActiveTab(catalogType)
    window.activeCatalogType = catalogType
    window.defaultFilter = nil
    window.frame.page = 0
    window:CATALOG_FILTER_CHANGED()
end


function window:ResetFilter()
    window.filterSettings = window:GetDefaultFilterSettings()

    -- Also reset the search box
    local cf = window.frame
    cf.searchBox:SetText("")

    window:CATALOG_FILTER_CHANGED()
end

function window:FilterIncludesSetting(key)
    local filter = window.filterSettings
    return filter.settings[key]
end

function window:FilterSearchText()
    local filter = window.filterSettings
    return filter.settings.name
end

function window:SetFilterSearchText(text)
    local filter = window.filterSettings

    if filter and filter.settings then
        filter.settings.name = text
        window:CATALOG_FILTER_CHANGED()
    end
end

function window:SetFilterSetting(key, enabled)
    window.filterSettings.settings[key] = not not enabled
    window:CATALOG_FILTER_CHANGED()
end

function window:EnableCatalogFilter()
    local cf = window.frame

    cf.filterButton:ClearAllPoints()
    cf.filterButton:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -10, -30)
    cf.filterButton:SetWidth(93)
    cf.filterButton:SetHeight(22)
    cf.filterButton:SetText(L["Filter"])

    cf.filterButton.ResetButton:SetHeight(23)
    cf.filterButton.ResetButton:SetWidth(23)
    cf.filterButton.ResetButton:ClearAllPoints()
    cf.filterButton.ResetButton:SetPoint("CENTER", cf.filterButton, "TOPRIGHT", -3, 0)
    cf.filterButton.ResetButton:SetNormalAtlas("auctionhouse-ui-filter-redx")
    cf.filterButton.ResetButton:SetHighlightAtlas("auctionhouse-ui-filter-redx", "ADD", 0.4)

    cf.filterButton.ResetButton:SetScript("OnClick", function()
        window:ResetFilter()
    end)

    local function filterMenuGenerator(_, rootDescription)
        rootDescription:CreateCheckbox(L["Include spells from 'General' tab"],
            function() return window:FilterIncludesSetting("includeGeneralTab") end,
            function() window:SetFilterSetting("includeGeneralTab", not window:FilterIncludesSetting("includeGeneralTab")) end)
        rootDescription:CreateCheckbox(L["Include passive spells"],
            function() return window:FilterIncludesSetting("includePassives") end,
            function() window:SetFilterSetting("includePassives", not window:FilterIncludesSetting("includePassives")) end)
        rootDescription:CreateCheckbox(L["Include off-spec spells"],
            function() return window:FilterIncludesSetting("includeOffspec") end,
            function() window:SetFilterSetting("includeOffspec", not window:FilterIncludesSetting("includeOffspec")) end)
        rootDescription:CreateDivider()
        rootDescription:CreateCheckbox(L["Include global macros"],
            function() return window:FilterIncludesSetting("includeGlobalMacros") end,
            function() window:SetFilterSetting("includeGlobalMacros", not window:FilterIncludesSetting("includeGlobalMacros")) end)
        rootDescription:CreateCheckbox(L["Include character macros"],
            function() return window:FilterIncludesSetting("includeCharacterMacros") end,
            function() window:SetFilterSetting("includeCharacterMacros", not window:FilterIncludesSetting("includeCharacterMacros")) end)
    end

    cf.filterButton:SetupMenu(filterMenuGenerator)
end

function window:ClearCatalogResults()
    window.allResults = nil
end

function window:GetCatalogResults()
    local actionResults = libActions:GetActionCatalogEntries()
    local spellResults = libSpellbook:GetSpellCatalogEntries(#actionResults)
    local petResults = libPet:GetPetCatalogEntries(#actionResults + #spellResults)
    local macroResults = libMacros:GetMacroCatalogEntries(#actionResults + #spellResults + #petResults)

    local results = libCatalog:MergeCatalogs(actionResults, spellResults)
    results = libCatalog:MergeCatalogs(results, petResults)
    results = libCatalog:MergeCatalogs(results, macroResults)
    libCatalog:SortCatalog(results)

    window.allResults = results
    return results
end

-- Called when the spells change
function window:REFRESH_CATALOG_WINDOW()
    -- Make sure the spell catalog is updated
    window:CATALOG_FILTER_CHANGED()

    -- Refresh the UI
    window:UPDATE_CATALOG_WINDOW()
end

function window:CATALOG_FILTER_CHANGED()
    local cf = window.frame

    local filterSettings = window.filterSettings
    local filter = window:GetFilterFromSettings(filterSettings)

    -- Show the reset button if the filter is different than default
    local defaultFilter = window:GetDefaultFilter()
    if not libCatalog:FiltersEqual(defaultFilter, filter) then
        cf.filterButton.ResetButton:Show()
    else
        cf.filterButton.ResetButton:Hide()
    end

    local catalog = window:GetCatalogResults()
    -- addon:Printf("Catalog has %d results", #catalog)

    local results = libCatalog:ApplyFilter(catalog, filter)
    -- addon:Printf("Applying filter has %d results", #results)

    window.results = results
    window:UPDATE_CATALOG_WINDOW()
end

function window:UPDATE_CATALOG_WINDOW()
    local cf = window.frame

    if not window.results then
        window:CATALOG_FILTER_CHANGED()
    end

    local results = window.results

    -- If a filter caused us to be beyond the last page, flip to the last page
    local maxPage = (#results / cf.pageSize)

    -- If we have than a page of results, reset to the first page
    if #results < cf.pageSize then
        cf.page = 0
    elseif cf.page >= maxPage then
        cf.page = maxPage - 1
    end

    local startId = (cf.page * cf.pageSize) + 1

    for idx = startId, startId + (cf.pageSize - 1) do
        local buttonIndex = (idx - startId) + 1
        local button = cf.buttons[buttonIndex]

        local entry = results[idx]
        if entry and (entry.entryType == libCatalog.entryType.Spell or entry.entryType == libCatalog.entryType.Pet) then
            local isPet = entry.entryType == libCatalog.entryType.Pet
            local spellId = entry.id
            local name = entry.name
            local icon = entry.icon
            local passive = entry.passive
            local offspec = entry.offspec

            button.type = entry.entryType
            button.id = spellId

            local spellSubName = libSpellbook:GetSpellSubName(spellId)
            local spellName = name

            if spellSubName and spellSubName ~= "" then
                spellName = spellName .. " (" .. spellSubName .. ")"
            end

            button.name:SetText(spellName .. (isPet and (" (" .. L["pet"] .. ")") or "") .. (passive and " (Passive)" or "") .. (offspec and " [Offspec]" or ""))
            button.background:SetTexture(icon)
            if offspec then
                button.background:SetDesaturated(true)
            else
                button.background:SetDesaturated(false)
            end
            button:Show()
            button.name:Show()
        elseif entry and entry.entryType == libCatalog.entryType.Macro then
            local name = entry.name
            local icon = entry.icon
            local char = entry.characterMacro

            button.type = libCatalog.entryType.Macro
            button.id = entry.id

            local macroType = L["global"]
            if char then
                macroType = L["character"]
            end

            local formattedName = string.format("%s %s (%s)", L["Macro:"], name, macroType)

            button.name:SetText(formattedName)
            button.background:SetTexture(icon)
            button.background:SetDesaturated(false)

            button:Show()
            button.name:Show()
        elseif entry and entry.entryType == libCatalog.entryType.Action then
            local name = entry.name
            local icon = entry.icon

            button.type = libCatalog.entryType.Action
            button.id = entry.id

            button.name:SetText(name)
            button.background:SetTexture(icon)
            button.background:SetDesaturated(false)

            button:Show()
            button.name:Show()
        else
            button:Hide()
            button.name:Hide()
            button.type = nil
            button.id = nil
        end
    end

    -- Update the previous and next buttons accordingly
    cf.prev:Enable()
    cf.next:Enable()

    if cf.page == 0 then
        cf.prev:Disable()
    end

    if cf.page >= (maxPage - 1) then
        cf.next:Disable()
    end
end
