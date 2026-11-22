

local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).stale then return end














local IconSearch = ns.IconSearch

local CreateFrame = CreateFrame
local C_AddOns = C_AddOns
local pcall = pcall
local wipe = wipe

local filtered = nil
local filterScratch = {}

local function ApplyPickerSearch(popup, searchBox)
    local query = (searchBox:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then
        filtered = nil
    else
        local n = IconSearch:Filter(query, filterScratch)
        filtered = searchBox.efResults or {}
        searchBox.efResults = filtered
        wipe(filtered)
        for i = 1, n do
            local _, fdid = IconSearch:GetIcon(filterScratch[i])
            filtered[i] = fdid
        end
    end

    local selectedIcon = popup.BorderBox
        and popup.BorderBox.SelectedIconArea
        and popup.BorderBox.SelectedIconArea.SelectedIconButton
        and popup.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture()
    popup.IconSelector:UpdateSelections()
    local index = selectedIcon and popup:GetIndexOfIcon(selectedIcon)
    popup.IconSelector:SetSelectedIndex(index)
    if index then
        pcall(popup.IconSelector.ScrollToSelectedIndex, popup.IconSelector)
    end
    pcall(popup.SetSelectedIconText, popup)
end


IconSearch:OnNamesReady(function()
    local popup = _G.MacroPopupFrame
    if filtered and popup and popup.efSearchBox and popup:IsShown() then
        ApplyPickerSearch(popup, popup.efSearchBox)
    end
end)

local function InstallAccessorOverlay(popup)
    local origGetByIndex = popup.GetIconByIndex
    local origGetNum = popup.GetNumIcons
    local origIndexOf = popup.GetIndexOfIcon
    function popup:GetIconByIndex(index)
        if filtered then return filtered[index] end
        return origGetByIndex(self, index)
    end
    function popup:GetNumIcons()
        if filtered then return #filtered end
        return origGetNum(self)
    end
    function popup:GetIndexOfIcon(icon)
        if not filtered then return origIndexOf(self, icon) end
        for i = 1, #filtered do
            if filtered[i] == icon then return i end
        end
        return nil
    end


    popup.efInstalledAccessors = {
        popup.GetIconByIndex, popup.GetNumIcons, popup.GetIndexOfIcon,
    }
end











local function AuditCoexistence(popup)
    local searchBox = popup.efSearchBox
    if not searchBox then return end
    if EasyFind.db and EasyFind.db.macroPickerSearch == false then
        filtered = nil
        searchBox:SetText("")
        searchBox:Hide()
        return
    end
    local mine = popup.efInstalledAccessors
    local displaced = not mine
        or popup.GetIconByIndex ~= mine[1]
        or popup.GetNumIcons ~= mine[2]
        or popup.GetIndexOfIcon ~= mine[3]
    local foreignBar = false
    if not displaced then
        for i = 1, select("#", popup:GetChildren()) do
            local child = select(i, popup:GetChildren())
            if child ~= searchBox and child.GetObjectType
               and child:GetObjectType() == "EditBox" and child:IsShown() then
                foreignBar = true
                break
            end
        end
    end
    if displaced or foreignBar then
        filtered = nil
        searchBox:SetText("")
        searchBox:Hide()
    else
        searchBox:Show()
    end
end

local function AttachPickerSearch(popup)
    if not (popup and popup.IconSelector and popup.BorderBox) then return end
    if popup.efSearchBox then return end


    if popup.SearchBox then return end
    if not (popup.GetIconByIndex and popup.GetNumIcons and popup.GetIndexOfIcon) then return end

    InstallAccessorOverlay(popup)

    local searchBox = CreateFrame("EditBox", "EasyFindPickerSearchBox", popup, "InputBoxTemplate")
    ns.Utils.ReleaseFocusOnOutsideClick(searchBox)
    searchBox:SetAutoFocus(false)
    searchBox:SetHeight(18)
    searchBox:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 68, 15)
    searchBox:SetPoint("RIGHT", popup.BorderBox.OkayButton, "LEFT", -8, 0)
    searchBox:SetFrameLevel(popup.BorderBox:GetFrameLevel() + 1)

    local label = searchBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("RIGHT", searchBox, "LEFT", -6, 0)
    label:SetText((_G["SEARCH"] or "Search") .. ":")

    searchBox:SetScript("OnTextChanged", function(self, userInput)
        if not userInput and (self:GetText() or "") ~= "" then return end
        ApplyPickerSearch(popup, self)
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then
            self:SetText("")
        else
            self:ClearFocus()
        end
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    popup:HookScript("OnHide", function()
        filtered = nil
        searchBox:SetText("")
    end)
    popup:HookScript("OnShow", function(self)
        AuditCoexistence(self)
    end)

    popup.efSearchBox = searchBox
end



local function WatchForMacroUI()


    local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
    if IsAddOnLoaded and IsAddOnLoaded("LargerMacroIconSelection") then return end

    local function OnMacroUILoaded()
        AttachPickerSearch(_G.MacroPopupFrame)
    end
    local EventUtil = _G.EventUtil
    if EventUtil and EventUtil.ContinueOnAddOnLoaded then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_MacroUI", OnMacroUILoaded)
        return
    end
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:SetScript("OnEvent", function(self, _, addonName)
        if addonName == "Blizzard_MacroUI" then
            self:UnregisterEvent("ADDON_LOADED")
            OnMacroUILoaded()
        end
    end)
end

local IconPickerSearch = {}
ns.IconPickerSearch = IconPickerSearch

function IconPickerSearch:Initialize()
    WatchForMacroUI()
end




function IconPickerSearch:Refresh()
    local popup = _G.MacroPopupFrame
    if popup and popup.efSearchBox and popup:IsShown() then
        AuditCoexistence(popup)
        popup.IconSelector:UpdateSelections()
    end
end



local initOk, initErr = pcall(function() IconPickerSearch:Initialize() end)
if not initOk then
    ns.Utils.DebugPrint("IconPickerSearch init failed: " .. tostring(initErr))
end

return IconPickerSearch
