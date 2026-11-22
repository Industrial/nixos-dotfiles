local _, ns = ...

local Search = ns.Search
local Filters = ns.Filters
local Utils = ns.Utils
local L = ns.L

local ipairs, pairs = Utils.ipairs, Utils.pairs
local select = Utils.select
local CreateFrame = CreateFrame
local UIParent = UIParent
local wipe = wipe
local UI_FILTER_OPTIONS = Filters.UI_FILTER_OPTIONS

local SetFlyoutRowEnabled = Utils.SetFlyoutRowEnabled

function Filters:RerunActiveSearch()





    if ns.RequestItemCatalog and not ns.ItemSearch and ns.CategoryMap then
        local uiFilters = EasyFind.db and EasyFind.db.uiSearchFilters
        if not (uiFilters and ns.CategoryMap.IsProviderFilterOff(uiFilters, "catalog")) then
            ns.RequestItemCatalog(false)
        end
    end


    if ns.RequestSettingsSearch and not ns.BlizzOptionsSearch and ns.CategoryMap then
        local uiFilters = EasyFind.db and EasyFind.db.uiSearchFilters
        local bothOff = uiFilters
            and ns.CategoryMap.IsProviderFilterOff(uiFilters, "gameOptions")
            and ns.CategoryMap.IsProviderFilterOff(uiFilters, "addonOptions")
        if not bothOff then
            ns.RequestSettingsSearch(false)
        end
    end
    local typed = Search.GetTypedQuery and Search:GetTypedQuery() or ""
    if typed ~= "" then
        Search:OnSearchTextChanged(typed)
    end
end


function Filters:ApplyFilterSelection(...)
    if ns.Database and ns.Database.RefreshDynamicCategory then
        for i = 1, select("#", ...) do
            ns.Database:RefreshDynamicCategory((select(i, ...)))
        end
    end
    self:RerunActiveSearch()
end

function Filters:CreateUIFilterDropdown(toggleBtn, anchorFrame, searchEditBox)
    local ROW_HEIGHT = 20
    local DROPDOWN_WIDTH = 207
    local PADDING_TOP = 8
    local PADDING_BOTTOM = 8
    local CHECK_SIZE = 16






    local activeFlyoutPopup
    local function SetActiveFlyout(popup)
        if activeFlyoutPopup and activeFlyoutPopup ~= popup and activeFlyoutPopup:IsShown() then
            activeFlyoutPopup:Hide()
        end
        activeFlyoutPopup = popup
    end
    local function ClearActiveFlyout(popup)
        if activeFlyoutPopup == popup then activeFlyoutPopup = nil end
    end

    local dropdown = CreateFrame("Frame", "EasyFindUIFilterDropdown", UIParent, "BackdropTemplate")
    dropdown:SetFrameStrata("DIALOG")




    dropdown:SetFrameLevel(9000)



    dropdown:SetScale(1.5)
    dropdown:Hide()
    dropdown:EnableMouse(true)




    local dropdownGuardFrames = {}
    dropdown.guardFrames = dropdownGuardFrames
    dropdown:SetClampedToScreen(true)

    local function KeepSearchEditBoxUnfocused()
        if searchEditBox and searchEditBox.ClearFocus then searchEditBox:ClearFocus() end
    end

    ns.StyleMenuPanel(dropdown)
    ns.SetRoundedRectRingShown(dropdown, EasyFind.db.windowBorder ~= false)




    local ChevRestColor = Utils.ChevronRestColor
    local ChevHoverColor = Utils.ChevronHoverColor

    local function RecolorFilterRowLabels(self)
        local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
        local leaf = theme and theme.leafColor
        if not leaf then return end
        local children = { self:GetChildren() }
        for i = 1, #children do
            local child = children[i]


            if child.label then
                ns.ShadeText(child.label)



                if child._efRowEnabled ~= false then
                    child.label:SetTextColor(leaf[1], leaf[2], leaf[3], 1)
                end
            end
            if child.flyoutChevron then
                child.flyoutChevron:SetVertexColor(ChevRestColor())
            end
        end
    end


    dropdown._efOnThemeRestyle = RecolorFilterRowLabels

    local ICON_SIZE = 14

    local RADIO_SIZE = 14
    local RADIO_OFF_TEX = ns.RADIO_OFF_TEX
    local RADIO_ON_TEX = ns.RADIO_ON_TEX

    local function InstallMenuRowHighlight(row)
        Utils.InstallMenuRowHighlight(row)
    end

    local function StylePopup(frame)
        ns.StyleMenuPanel(frame)


        ns.SetRoundedRectRingShown(frame, EasyFind.db.windowBorder ~= false)
    end

    local function CreateRadioTexture(parent)
        local tex = parent:CreateTexture(nil, "ARTWORK")
        tex:SetSize(RADIO_SIZE, RADIO_SIZE)
        tex:SetTexture(RADIO_OFF_TEX)
        local function SetChecked(checked)
            tex:SetTexture(checked and RADIO_ON_TEX or RADIO_OFF_TEX)
        end
        return tex, SetChecked
    end

    local uncheckRow = CreateFrame("Button", nil, dropdown)
    uncheckRow:SetSize(DROPDOWN_WIDTH - 16, ROW_HEIGHT)
    uncheckRow:SetPoint("TOPLEFT", 8, -PADDING_TOP)
    local uncheckLabel = uncheckRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    uncheckLabel:SetPoint("LEFT", 8, 0)
    uncheckLabel:SetText(L["FILTER_TOGGLE_ALL"])
    ns.ShadeText(uncheckLabel)


    uncheckRow.label = uncheckLabel
    InstallMenuRowHighlight(uncheckRow)

    local checkRows = {}
    local checkRowsByIndex = {}
    local LayoutDropdown
    local dropdownKeyboardMode = false




    local function AddPopupKeyboardNav(popup, getRows, returnTo)
        local popupFocus = 0
        local popupFocusRow

        local function SetPopupFocus(idx)
            local rows = getRows()
            if popupFocusRow and popupFocusRow.SetMenuHighlightFocused then
                popupFocusRow:SetMenuHighlightFocused(false)
            end
            popupFocus = idx
            local target = rows[idx]
            if target then
                if target.SetMenuHighlightFocused then
                    target:SetMenuHighlightFocused(true)
                end
                popupFocusRow = target
            else
                popupFocusRow = nil
            end
        end

        Utils.SafeCallMethod(popup, "EnableKeyboard", false)
        Utils.SafeCallMethod(popup, "SetPropagateKeyboardInput", false)

        popup:HookScript("OnKeyDown", function(self, key)
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            local rows = getRows()
            if key == "DOWN" then
                Search:GetSearchFrame().StartKeyRepeat(key, function()
                    local r = getRows()
                    local next = popupFocus + 1
                    if next > #r then next = 1 end
                    SetPopupFocus(next)
                end)
            elseif key == "UP" then
                Search:GetSearchFrame().StartKeyRepeat(key, function()
                    local r = getRows()
                    local prev = popupFocus - 1
                    if prev < 1 then prev = #r end
                    SetPopupFocus(prev)
                end)
            elseif key == "ENTER" then
                local target = rows[popupFocus]
                if target and target.Click then target:Click() end
            elseif key == "TAB" or key == "RIGHT" then



                local target = rows[popupFocus]
                if target and target.ShowFlyoutPopup then
                    target.ShowFlyoutPopup()
                elseif key == "TAB" then
                    self:Hide()
                end
            elseif key == "LEFT" then
                self:Hide()
            elseif key == "ESCAPE" then




                self:Hide()
            else
                Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", true)
            end
        end)
        popup:HookScript("OnKeyUp", function(_, key)
            if Search:GetSearchFrame().IsRepeatKey(key) then Search:GetSearchFrame().StopKeyRepeat() end
        end)

        popup:HookScript("OnShow", function(self)
            if dropdownKeyboardMode then
                Utils.SafeCallMethod(dropdown, "EnableKeyboard", false)
                if returnTo then Utils.SafeCallMethod(returnTo, "EnableKeyboard", false) end
                local sp = _G["EasyFindSpecPopup"]
                if sp then Utils.SafeCallMethod(sp, "EnableKeyboard", false) end
                local cf = _G["EasyFindSpecFlyout"]
                if cf then Utils.SafeCallMethod(cf, "EnableKeyboard", false) end
                local dp = _G["EasyFindDiffPopup"]
                if dp then Utils.SafeCallMethod(dp, "EnableKeyboard", false) end
                Utils.SafeCallMethod(self, "EnableKeyboard", true)
                SetPopupFocus(1)
            end
        end)

        popup:HookScript("OnHide", function(self)
            popupFocus = 0
            if popupFocusRow and popupFocusRow.SetMenuHighlightFocused then
                popupFocusRow:SetMenuHighlightFocused(false)
            end
            popupFocusRow = nil
            Utils.SafeCallMethod(self, "EnableKeyboard", false)
            if dropdownKeyboardMode then
                local ret = returnTo or dropdown
                if ret:IsShown() then
                    Utils.SafeCallMethod(ret, "EnableKeyboard", true)
                end
            end
        end)
    end

    for i, opt in ipairs(UI_FILTER_OPTIONS) do



        local rowWidth = DROPDOWN_WIDTH - 16
        if opt.parentKey then rowWidth = rowWidth - 24 end
        local row = CreateFrame("CheckButton", nil, dropdown)
        row:SetSize(rowWidth, ROW_HEIGHT)
        row:SetHitRectInsets(0, 0, 0, 0)
        row.optKey = opt.key
        row.parentKey = opt.parentKey

        Utils.SetCheckboxTextures(row, CHECK_SIZE)




        local icon
        if opt.iconAtlas or opt.iconTex then
            icon = row:CreateTexture(nil, "ARTWORK")
            ns.SizeIconAspect(icon, ICON_SIZE, opt.iconAspect)
            icon:SetPoint("LEFT", row:GetNormalTexture(), "RIGHT", 4, 0)
            if opt.iconAtlas then
                icon:SetAtlas(opt.iconAtlas)
            else
                icon:SetTexture(opt.iconTex)
                if opt.iconCoords then
                    icon:SetTexCoord(opt.iconCoords[1], opt.iconCoords[2],
                                     opt.iconCoords[3], opt.iconCoords[4])
                end
            end
            row.iconTex = icon
        end

        local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        if icon then
            label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        else
            label:SetPoint("LEFT", row:GetNormalTexture(), "RIGHT", 4, 0)
        end
        label:SetText(opt.label)
        row.label = label





        if opt.flyoutSubFilters or opt.flyoutRadio or opt.hasFlyout then
            local chev = row:CreateTexture(nil, "OVERLAY")
            Utils.SetChevronTexture(chev)
            chev:SetSize(ICON_SIZE - 2, ICON_SIZE - 2)
            chev:SetPoint("RIGHT", -4, 0)
            row.flyoutChevron = chev
            label:SetPoint("RIGHT", chev, "LEFT", -4, 0)
            label:SetWordWrap(false)
            label:SetJustifyH("LEFT")
            row:HookScript("OnEnter", function() chev:SetVertexColor(ChevHoverColor()) end)
            row:HookScript("OnLeave", function() chev:SetVertexColor(ChevRestColor()) end)
        end





        if opt.flyoutSubFilters then
            local SUB_POPUP_WIDTH = 180
            local SUB_ROW_H = 22
            local SUB_PAD = 6
            local CHK = CHECK_SIZE
            local SUB_ICON = ICON_SIZE





            local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            popup:SetFrameStrata("TOOLTIP")
            StylePopup(popup)
            popup:EnableMouse(true)
            popup:Hide()
            row.flyoutPopup = popup
            dropdownGuardFrames[#dropdownGuardFrames + 1] = popup



            dropdown.flyoutPopups = dropdown.flyoutPopups or {}
            dropdown.flyoutPopups[#dropdown.flyoutPopups + 1] = popup




            Filters.AttachOutsideClickClose(popup, { onHide = ClearActiveFlyout })

            local subRows = {}
            local nestedFlyouts = {}






            local subBranchPopups = {}
            local function RegisterSubBranchPopup(...)
                for gi = 1, select("#", ...) do
                    local guarded = select(gi, ...)
                    if guarded then subBranchPopups[#subBranchPopups + 1] = guarded end
                end
            end




            local function FilterOn(def, target)
                if def.scope then return target[def.key] == true end
                return target[def.key] ~= false
            end
            local toggleAllRow
            local toggleAllOffset = (opt.key == "collections" or opt.key == "map") and 1 or 0
            for si, sub in ipairs(opt.flyoutSubFilters) do
                local subRow = CreateFrame("CheckButton", nil, popup)
                subRow:SetSize(SUB_POPUP_WIDTH - SUB_PAD * 2, SUB_ROW_H)
                subRow:SetHitRectInsets(0, 0, 0, 0)
                subRow:SetPoint("TOPLEFT", popup, "TOPLEFT", SUB_PAD, -(SUB_PAD + (si - 1 + toggleAllOffset) * SUB_ROW_H))

                Utils.SetCheckboxTextures(subRow, CHK)

                local subIcon
                if sub.iconAtlas or sub.iconTex then
                    subIcon = subRow:CreateTexture(nil, "ARTWORK")
                    ns.SizeIconAspect(subIcon, SUB_ICON, sub.iconAspect)
                    subIcon:SetPoint("LEFT", subRow:GetNormalTexture(), "RIGHT", 4, 0)
                    if sub.iconAtlas then
                        subIcon:SetAtlas(sub.iconAtlas)
                    else
                        subIcon:SetTexture(sub.iconTex)
                        if sub.iconCoords then
                            subIcon:SetTexCoord(sub.iconCoords[1], sub.iconCoords[2],
                                                sub.iconCoords[3], sub.iconCoords[4])
                        end
                    end
                    if sub.iconColor then
                        subIcon:SetVertexColor(unpack(sub.iconColor))
                    end
                    if sub.iconDesaturate then subIcon:SetDesaturated(true) end
                end

                local subLabel = subRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                if subIcon then
                    subLabel:SetPoint("LEFT", subIcon, "RIGHT", 4, 0)
                else
                    subLabel:SetPoint("LEFT", subRow:GetNormalTexture(), "RIGHT", 4, 0)
                end
                subLabel:SetText(sub.label)
                subRow._label = subLabel
                subRow._icon = subIcon

                if sub.hasOptions or sub.subFilters then
                    local subChev = subRow:CreateTexture(nil, "OVERLAY")
                    Utils.SetChevronTexture(subChev)
                    subChev:SetSize(SUB_ICON - 2, SUB_ICON - 2)
                    subChev:SetPoint("RIGHT", -4, 0)
                    subLabel:SetPoint("RIGHT", subChev, "LEFT", -4, 0)
                    subLabel:SetWordWrap(false)
                    subLabel:SetJustifyH("LEFT")
                    subRow:HookScript("OnEnter", function() subChev:SetVertexColor(ChevHoverColor()) end)
                    subRow:HookScript("OnLeave", function() subChev:SetVertexColor(ChevRestColor()) end)
                    subRow._chev = subChev
                end

                InstallMenuRowHighlight(subRow)


                if sub.tooltip then
                    subRow:HookScript("OnEnter", function(self)
                        local token = (self._tipToken or 0) + 1
                        self._tipToken = token
                        Utils.SafeAfter(ns.TOOLTIP_HOVER_DELAY, function()
                            if self._tipToken ~= token or not self:IsMouseOver() then return end
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetText(sub.tooltip, 1, 1, 1, 1, true)
                            GameTooltip:Show()
                        end)
                    end)
                    subRow:HookScript("OnLeave", function(self)
                        self._tipToken = (self._tipToken or 0) + 1
                        GameTooltip:Hide()
                    end)
                end

                subRow:SetScript("OnClick", function(self)
                    local target = sub.dbTable and EasyFind.db[sub.dbTable]
                                   or EasyFind.db.uiSearchFilters
                    target[sub.key] = self:GetChecked()
                    Filters.ResyncShownOptionPopups()
                    Filters:RerunActiveSearch()
                    KeepSearchEditBoxUnfocused()
                end)

                subRows[si] = subRow
                subRows[sub.key] = subRow




                if sub.hasOptions and sub.key == "appearances" then
                    local optionsPopup, syncOptions, appBranchPopups = Search:BuildAppearanceOptionsPopup(
                        StylePopup, CHECK_SIZE, dropdownGuardFrames)
                    optionsPopup._efSync = syncOptions
                    optionsPopup:SetFrameLevel(popup:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
                    optionsPopup._owningRow = subRow
                    popup._appearanceSetOptionsPopup = optionsPopup
                    RegisterSubBranchPopup(optionsPopup)
                    dropdownGuardFrames[#dropdownGuardFrames + 1] = optionsPopup

                    Utils.AttachHoverPopup(subRow, optionsPopup, {
                        chainGuards = appBranchPopups,
                        onShow = function()
                            syncOptions()
                            optionsPopup:SetScale(EasyFind.db.uiSearchScale or 1.0)
                            Utils.OpenFlyoutBeside(optionsPopup, subRow, 4)
                            optionsPopup:Show()
                        end,
                    })

                    popup:HookScript("OnHide", function() optionsPopup:Hide() end)
                    dropdown:HookScript("OnHide", function() optionsPopup:Hide() end)
                end

                if sub.hasOptions and sub.key == "mounts" then
                    local optionsPopup, syncOptions, sourcePopup = Search:BuildMountOptionsPopup(
                        StylePopup, CHECK_SIZE)
                    optionsPopup._efSync = syncOptions
                    optionsPopup:SetFrameLevel(popup:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
                    optionsPopup._owningRow = subRow
                    popup._mountOptionsPopup = optionsPopup
                    popup._mountSourcePopup = sourcePopup
                    RegisterSubBranchPopup(optionsPopup, sourcePopup)
                    dropdownGuardFrames[#dropdownGuardFrames + 1] = optionsPopup
                    dropdownGuardFrames[#dropdownGuardFrames + 1] = sourcePopup

                    Utils.AttachHoverPopup(subRow, optionsPopup, {
                        extraGuards = { sourcePopup },
                        onShow = function()
                            syncOptions()
                            optionsPopup:SetScale(EasyFind.db.uiSearchScale or 1.0)
                            Utils.OpenFlyoutBeside(optionsPopup, subRow, 4)
                            optionsPopup:Show()
                        end,
                    })

                    popup:HookScript("OnHide", function() optionsPopup:Hide() end)
                    dropdown:HookScript("OnHide", function() optionsPopup:Hide() end)
                end

                if sub.hasOptions and sub.key == "heirlooms" then
                    local optionsPopup, syncOptions, sourcePopup = Search:BuildHeirloomOptionsPopup(
                        StylePopup, CHECK_SIZE, dropdownGuardFrames)
                    optionsPopup._efSync = syncOptions
                    optionsPopup:SetFrameLevel(popup:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
                    optionsPopup._owningRow = subRow
                    popup._heirloomOptionsPopup = optionsPopup
                    popup._heirloomSourcePopup = sourcePopup
                    RegisterSubBranchPopup(optionsPopup, sourcePopup)
                    dropdownGuardFrames[#dropdownGuardFrames + 1] = optionsPopup
                    dropdownGuardFrames[#dropdownGuardFrames + 1] = sourcePopup

                    Utils.AttachHoverPopup(subRow, optionsPopup, {
                        extraGuards = { sourcePopup },
                        onShow = function()
                            syncOptions()
                            optionsPopup:SetScale(EasyFind.db.uiSearchScale or 1.0)
                            Utils.OpenFlyoutBeside(optionsPopup, subRow, 4)
                            optionsPopup:Show()
                        end,
                    })

                    popup:HookScript("OnHide", function() optionsPopup:Hide() end)
                    dropdown:HookScript("OnHide", function() optionsPopup:Hide() end)
                end



                if sub.hasOptions and sub.checkboxOptions then


                    local optionsPopup, syncOptions = Filters:BuildCheckboxOptionsPopup(
                        sub, StylePopup, CHECK_SIZE)
                    optionsPopup._efSync = syncOptions
                    optionsPopup:SetFrameLevel(popup:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
                    optionsPopup._owningRow = subRow
                    popup["_" .. sub.key .. "OptionsPopup"] = optionsPopup
                    RegisterSubBranchPopup(optionsPopup)
                    dropdownGuardFrames[#dropdownGuardFrames + 1] = optionsPopup
                    Utils.AttachHoverPopup(subRow, optionsPopup, {
                        onShow = function()
                            syncOptions()
                            optionsPopup:SetScale(EasyFind.db.uiSearchScale or 1.0)
                            Utils.OpenFlyoutBeside(optionsPopup, subRow, 4)
                            optionsPopup:Show()
                        end,
                    })
                    popup:HookScript("OnHide", function() optionsPopup:Hide() end)
                    dropdown:HookScript("OnHide", function() optionsPopup:Hide() end)
                end
                if sub.hasOptions and (sub.key == "bank" or sub.key == "bags") then
                    local build = sub.key == "bank"
                        and Filters.BuildBankOptionsPopup
                        or Filters.BuildBagOptionsPopup
                    local optionsPopup, syncOptions, branchPopups =
                        build(Filters, StylePopup, CHECK_SIZE, dropdownGuardFrames)
                    optionsPopup._efSync = syncOptions
                    optionsPopup:SetFrameLevel(popup:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
                    optionsPopup._owningRow = subRow
                    popup["_" .. sub.key .. "OptionsPopup"] = optionsPopup
                    for bpi = 1, #branchPopups do
                        RegisterSubBranchPopup(branchPopups[bpi])
                    end

                    Utils.AttachHoverPopup(subRow, optionsPopup, {
                        chainGuards = branchPopups,
                        onShow = function()
                            syncOptions()
                            optionsPopup:SetScale(EasyFind.db.uiSearchScale or 1.0)
                            Utils.OpenFlyoutBeside(optionsPopup, subRow, 4)
                            optionsPopup:Show()
                        end,
                    })

                    local function HideBranch()
                        for bi = 1, #branchPopups do branchPopups[bi]:Hide() end
                    end
                    popup:HookScript("OnHide", HideBranch)
                    dropdown:HookScript("OnHide", HideBranch)
                end

                if sub.hasOptions and sub.key == "toys" then
                    local optionsPopup, syncOptions, sourcePopup, expansionPopup =
                        Search:BuildToyOptionsPopup(StylePopup, CHECK_SIZE, dropdownGuardFrames)
                    optionsPopup._efSync = syncOptions
                    optionsPopup:SetFrameLevel(popup:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
                    optionsPopup._owningRow = subRow
                    popup._toyOptionsPopup = optionsPopup
                    popup._toySourcePopup = sourcePopup
                    popup._toyExpansionPopup = expansionPopup
                    RegisterSubBranchPopup(optionsPopup, sourcePopup, expansionPopup)
                    dropdownGuardFrames[#dropdownGuardFrames + 1] = optionsPopup
                    dropdownGuardFrames[#dropdownGuardFrames + 1] = sourcePopup
                    dropdownGuardFrames[#dropdownGuardFrames + 1] = expansionPopup

                    Utils.AttachHoverPopup(subRow, optionsPopup, {
                        extraGuards = { sourcePopup, expansionPopup },
                        onShow = function()
                            syncOptions()
                            optionsPopup:SetScale(EasyFind.db.uiSearchScale or 1.0)
                            Utils.OpenFlyoutBeside(optionsPopup, subRow, 4)
                            optionsPopup:Show()
                        end,
                    })

                    popup:HookScript("OnHide", function() optionsPopup:Hide() end)
                    dropdown:HookScript("OnHide", function() optionsPopup:Hide() end)
                end


                if sub.hasOptions and sub.key == "npcs" then
                    local optionsPopup, syncOptions, flyouts =
                        Filters:BuildNpcOptionsPopup(StylePopup, CHECK_SIZE, dropdownGuardFrames)
                    optionsPopup._efSync = syncOptions
                    optionsPopup:SetFrameLevel(popup:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
                    optionsPopup._owningRow = subRow
                    popup._npcOptionsPopup = optionsPopup
                    RegisterSubBranchPopup(optionsPopup)
                    for fi = 1, #flyouts do RegisterSubBranchPopup(flyouts[fi]) end
                    dropdownGuardFrames[#dropdownGuardFrames + 1] = optionsPopup

                    Utils.AttachHoverPopup(subRow, optionsPopup, {
                        extraGuards = flyouts,
                        onShow = function()
                            syncOptions()
                            optionsPopup:SetScale(EasyFind.db.uiSearchScale or 1.0)
                            Utils.OpenFlyoutBeside(optionsPopup, subRow, 4)
                            optionsPopup:Show()
                        end,
                    })

                    popup:HookScript("OnHide", function() optionsPopup:Hide() end)
                    dropdown:HookScript("OnHide", function() optionsPopup:Hide() end)
                end

                if sub.hasOptions and sub.key == "pets" then
                    local optionsPopup, syncOptions, sourcePopup, typePopup =
                        Search:BuildPetOptionsPopup(StylePopup, CHECK_SIZE, dropdownGuardFrames)
                    optionsPopup._efSync = syncOptions
                    optionsPopup:SetFrameLevel(popup:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
                    optionsPopup._owningRow = subRow
                    popup._petOptionsPopup = optionsPopup
                    popup._petSourcePopup = sourcePopup
                    popup._petTypePopup = typePopup
                    RegisterSubBranchPopup(optionsPopup, sourcePopup, typePopup)
                    dropdownGuardFrames[#dropdownGuardFrames + 1] = optionsPopup
                    dropdownGuardFrames[#dropdownGuardFrames + 1] = sourcePopup
                    dropdownGuardFrames[#dropdownGuardFrames + 1] = typePopup

                    Utils.AttachHoverPopup(subRow, optionsPopup, {
                        extraGuards = { sourcePopup, typePopup },
                        onShow = function()
                            syncOptions()
                            optionsPopup:SetScale(EasyFind.db.uiSearchScale or 1.0)
                            Utils.OpenFlyoutBeside(optionsPopup, subRow, 4)
                            optionsPopup:Show()
                        end,
                    })

                    popup:HookScript("OnHide", function() optionsPopup:Hide() end)
                    dropdown:HookScript("OnHide", function() optionsPopup:Hide() end)
                end



                if sub.hasOptions and sub.key == "catalog" then
                    local optionsPopup, syncOptions, qualityPopup = Search:BuildCatalogOptionsPopup(
                        StylePopup, CHECK_SIZE, dropdownGuardFrames)
                    optionsPopup._efSync = syncOptions
                    optionsPopup:SetFrameLevel(popup:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
                    optionsPopup._owningRow = subRow
                    popup._catalogOptionsPopup = optionsPopup
                    popup._catalogQualityPopup = qualityPopup
                    RegisterSubBranchPopup(optionsPopup, qualityPopup)
                    dropdownGuardFrames[#dropdownGuardFrames + 1] = optionsPopup

                    Utils.AttachHoverPopup(subRow, optionsPopup, {
                        extraGuards = { qualityPopup },
                        onShow = function()
                            syncOptions()
                            optionsPopup:SetScale(EasyFind.db.uiSearchScale or 1.0)
                            Utils.OpenFlyoutBeside(optionsPopup, subRow, 4)
                            optionsPopup:Show()
                        end,
                    })

                    popup:HookScript("OnHide", function() optionsPopup:Hide() end)
                    dropdown:HookScript("OnHide", function()
                        optionsPopup:Hide()
                        qualityPopup:Hide()
                    end)
                end





                if sub.subFilters then

                    local children = type(sub.subFilters) == "function" and sub.subFilters() or sub.subFilters
                    local nested = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
                    nested:SetFrameStrata("TOOLTIP")
                    StylePopup(nested)
                    nested:EnableMouse(true)
                    nested:Hide()
                    nested:SetFrameLevel(popup:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
                    nested._owningRow = subRow
                    dropdownGuardFrames[#dropdownGuardFrames + 1] = nested
                    dropdown.flyoutPopups[#dropdown.flyoutPopups + 1] = nested
                    Filters.AttachOutsideClickClose(nested)




                    local nestedToggleAll = CreateFrame("Button", nil, nested)
                    nestedToggleAll:SetSize(SUB_POPUP_WIDTH - SUB_PAD * 2, SUB_ROW_H)
                    nestedToggleAll:SetPoint("TOPLEFT", nested, "TOPLEFT", SUB_PAD, -SUB_PAD)
                    local nestedToggleLabel = nestedToggleAll:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                    nestedToggleLabel:SetPoint("LEFT", nestedToggleAll, "LEFT", 8, 0)
                    nestedToggleLabel:SetText(L["FILTER_TOGGLE_ALL"])
                    nestedToggleAll._label = nestedToggleLabel
                    InstallMenuRowHighlight(nestedToggleAll)

                    local childRows = {}
                    for ci, child in ipairs(children) do
                        local childRow = CreateFrame("CheckButton", nil, nested)
                        childRow:SetSize(SUB_POPUP_WIDTH - SUB_PAD * 2, SUB_ROW_H)
                        childRow:SetHitRectInsets(0, 0, 0, 0)
                        childRow:SetPoint("TOPLEFT", nested, "TOPLEFT", SUB_PAD, -(SUB_PAD + SUB_ROW_H + (ci - 1) * SUB_ROW_H))
                        Utils.SetCheckboxTextures(childRow, CHK)
                        local childLabel = childRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                        childLabel:SetPoint("LEFT", childRow:GetNormalTexture(), "RIGHT", 4, 0)
                        childLabel:SetText(child.label)
                        childRow._label = childLabel
                        InstallMenuRowHighlight(childRow)
                        childRow:SetScript("OnClick", function(self)
                            local target = child.dbTable and EasyFind.db[child.dbTable]
                                           or EasyFind.db.uiSearchFilters
                            target[child.key] = self:GetChecked()
                            Filters.ResyncShownOptionPopups()
                            Filters:RerunActiveSearch()
                            KeepSearchEditBoxUnfocused()
                        end)
                        childRows[ci] = childRow
                        childRows[child.key] = childRow
                    end

                    local function SyncChildChecks()
                        local subTarget = sub.dbTable and EasyFind.db[sub.dbTable]
                                       or EasyFind.db.uiSearchFilters


                        local subOn
                        if sub.scope then
                            subOn = subTarget[sub.key] ~= true
                        else
                            subOn = subTarget[sub.key] ~= false
                        end
                        SetFlyoutRowEnabled(nestedToggleAll, subOn)
                        for _, child in ipairs(children) do
                            local cr = childRows[child.key]
                            local childTarget = child.dbTable and EasyFind.db[child.dbTable]
                                           or EasyFind.db.uiSearchFilters
                            cr:SetChecked(FilterOn(child, childTarget))
                            SetFlyoutRowEnabled(cr, subOn)
                        end
                    end
                    nested._efSync = SyncChildChecks

                    nestedToggleAll:SetScript("OnClick", function()
                        local allUnchecked = true
                        for _, child in ipairs(children) do
                            local target = child.dbTable and EasyFind.db[child.dbTable]
                                           or EasyFind.db.uiSearchFilters
                            if FilterOn(child, target) then
                                allUnchecked = false
                                break
                            end
                        end
                        for _, child in ipairs(children) do
                            local target = child.dbTable and EasyFind.db[child.dbTable]
                                           or EasyFind.db.uiSearchFilters
                            target[child.key] = allUnchecked
                        end
                        SyncChildChecks()
                        Filters.ResyncShownOptionPopups()
                        Filters:RerunActiveSearch()
                        KeepSearchEditBoxUnfocused()
                    end)

                    local childContentW = Utils.FlyoutRowContentWidth(nestedToggleAll, 8)
                    for ci = 1, #children do
                        local w = Utils.FlyoutRowContentWidth(childRows[ci], CHK + 4)
                        if w > childContentW then childContentW = w end
                    end
                    local nestedW = Utils.FlyoutWidthFor(childContentW, SUB_PAD)
                    nestedToggleAll:SetWidth(nestedW - SUB_PAD * 2)
                    for ci = 1, #children do childRows[ci]:SetWidth(nestedW - SUB_PAD * 2) end
                    nested:SetSize(nestedW, SUB_PAD * 2 + (#children + 1) * SUB_ROW_H)

                    local nestedHover = Utils.AttachHoverPopup(subRow, nested, {
                        onShow = function()
                            SyncChildChecks()
                            nested:SetScale(EasyFind.db.uiSearchScale or 1.0)
                            Utils.OpenFlyoutBeside(nested, subRow, 4)
                            nested:Show()
                        end,
                    })
                    subRow.ShowFlyoutPopup = nestedHover.Show
                    AddPopupKeyboardNav(nested, function() return childRows end, popup)

                    popup["_nestedFlyout_" .. sub.key] = nested
                    nestedFlyouts[#nestedFlyouts + 1] = nested
                    popup:HookScript("OnHide", function() nested:Hide() end)
                end
            end


            local function HookSiblingHide(popupField, ownerRow)
                local optionsPopup = popup[popupField]
                if not optionsPopup then return end
                for _, srOther in ipairs(subRows) do
                    if srOther ~= ownerRow then
                        srOther:HookScript("OnEnter", function() optionsPopup:Hide() end)
                    end
                end
            end
            HookSiblingHide("_appearanceSetOptionsPopup", subRows.appearances)
            HookSiblingHide("_mountOptionsPopup", subRows.mounts)
            HookSiblingHide("_heirloomOptionsPopup", subRows.heirlooms)
            HookSiblingHide("_toyOptionsPopup", subRows.toys)
            HookSiblingHide("_petOptionsPopup", subRows.pets)



            HookSiblingHide("_catalogOptionsPopup", subRows.catalog)
            HookSiblingHide("_bankOptionsPopup", subRows.bank)
            HookSiblingHide("_bagsOptionsPopup", subRows.bags)
            for _, sub in ipairs(opt.flyoutSubFilters) do


                if sub.checkboxOptions then
                    HookSiblingHide("_" .. sub.key .. "OptionsPopup", subRows[sub.key])
                end
                if sub.subFilters then
                    HookSiblingHide("_nestedFlyout_" .. sub.key, subRows[sub.key])
                end
            end
            row.flyoutSubRows = subRows




            local extraRows = 0
            local behaviorRow
            local function MakeBehaviorRow(labelText, slot)
                local r = CreateFrame("CheckButton", nil, popup)
                r:SetSize(SUB_POPUP_WIDTH - SUB_PAD * 2, SUB_ROW_H)
                r:SetHitRectInsets(0, 0, 0, 0)
                r:SetPoint("TOPLEFT", popup, "TOPLEFT",
                    SUB_PAD, -(SUB_PAD + (#opt.flyoutSubFilters + toggleAllOffset + slot) * SUB_ROW_H))
                Utils.SetCheckboxTextures(r, CHK)
                local lbl = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                lbl:SetPoint("LEFT", r:GetNormalTexture(), "RIGHT", 4, 0)
                lbl:SetText(labelText)
                r._label = lbl
                InstallMenuRowHighlight(r)
                return r
            end
            if opt.key == "collections" then
                behaviorRow = MakeBehaviorRow(L["FILTER_HIDE_TOOLTIPS"], 0)
                behaviorRow:SetScript("OnClick", function(self)
                    EasyFind.db.hideTooltips = EasyFind.db.hideTooltips or {}
                    EasyFind.db.hideTooltips.collections = self:GetChecked() and true or false
                end)
                row.hideTooltipsRow = behaviorRow
                extraRows = 1
            end

            local function SyncSubChecks()
                local parentEnabled = EasyFind.db.uiSearchFilters[opt.key] ~= false
                for _, sub in ipairs(opt.flyoutSubFilters) do
                    local sr = subRows[sub.key]
                    if sr then
                        local target = sub.dbTable and EasyFind.db[sub.dbTable]
                                       or EasyFind.db.uiSearchFilters
                        sr:SetChecked(FilterOn(sub, target))
                        SetFlyoutRowEnabled(sr, parentEnabled)
                    end
                end
                if behaviorRow then
                    local ht = EasyFind.db.hideTooltips
                    behaviorRow:SetChecked(ht and ht.collections == true)
                    SetFlyoutRowEnabled(behaviorRow, parentEnabled)
                end
                if toggleAllRow then
                    SetFlyoutRowEnabled(toggleAllRow, parentEnabled)
                end
            end
            row.SyncFlyoutSubChecks = SyncSubChecks
            popup._efSync = SyncSubChecks

            if toggleAllOffset == 1 then
                toggleAllRow = CreateFrame("Button", nil, popup)
                toggleAllRow:SetSize(SUB_POPUP_WIDTH - SUB_PAD * 2, SUB_ROW_H)
                toggleAllRow:SetPoint("TOPLEFT", popup, "TOPLEFT", SUB_PAD, -SUB_PAD)
                local toggleAllLabel = toggleAllRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                toggleAllLabel:SetPoint("LEFT", 8, 0)
                toggleAllLabel:SetText(L["FILTER_TOGGLE_ALL"])
                toggleAllRow._label = toggleAllLabel
                InstallMenuRowHighlight(toggleAllRow)
                toggleAllRow:SetScript("OnClick", function()
                    local allUnchecked = true
                    for _, sub in ipairs(opt.flyoutSubFilters) do
                        local target = sub.dbTable and EasyFind.db[sub.dbTable]
                                       or EasyFind.db.uiSearchFilters
                        if not sub.scope and target[sub.key] ~= false then
                            allUnchecked = false
                            break
                        end
                    end
                    for _, sub in ipairs(opt.flyoutSubFilters) do
                        local target = sub.dbTable and EasyFind.db[sub.dbTable]
                                       or EasyFind.db.uiSearchFilters
                        if not sub.scope then target[sub.key] = allUnchecked end
                    end
                    SyncSubChecks()
                    Filters.ResyncShownOptionPopups()
                    Filters:RerunActiveSearch()
                    KeepSearchEditBoxUnfocused()
                end)
            end




            local contentW = 0
            for si = 1, #opt.flyoutSubFilters do
                local w = Utils.FlyoutRowContentWidth(subRows[si], CHK + 4, SUB_ICON, SUB_ICON - 2)
                if w > contentW then contentW = w end
            end
            local behaviorW = Utils.FlyoutRowContentWidth(behaviorRow, CHK + 4)
            if behaviorW > contentW then contentW = behaviorW end
            local toggleAllW = Utils.FlyoutRowContentWidth(toggleAllRow, 8)
            if toggleAllW > contentW then contentW = toggleAllW end
            local popupW = Utils.FlyoutWidthFor(contentW, SUB_PAD)
            for si = 1, #opt.flyoutSubFilters do subRows[si]:SetWidth(popupW - SUB_PAD * 2) end
            if behaviorRow then behaviorRow:SetWidth(popupW - SUB_PAD * 2) end
            if toggleAllRow then toggleAllRow:SetWidth(popupW - SUB_PAD * 2) end
            popup:SetSize(popupW,
                SUB_PAD * 2 + (#opt.flyoutSubFilters + extraRows + toggleAllOffset) * SUB_ROW_H)

            AddPopupKeyboardNav(popup, function()
                local navRows = {}
                if toggleAllRow then navRows[#navRows + 1] = toggleAllRow end
                for si = 1, #opt.flyoutSubFilters do navRows[#navRows + 1] = subRows[si] end
                if behaviorRow then navRows[#navRows + 1] = behaviorRow end
                return navRows
            end)





            local function PositionPopup()
                Utils.OpenFlyoutBeside(popup, row, 4)
            end
            local hoverGuards = {}
            for gi = 1, #subBranchPopups do
                hoverGuards[#hoverGuards + 1] = subBranchPopups[gi]
            end
            for ni = 1, #nestedFlyouts do
                hoverGuards[#hoverGuards + 1] = nestedFlyouts[ni]
            end

            local function PaintSubGlyphs()
                for gi, sub in ipairs(opt.flyoutSubFilters) do
                    local icon = sub.glyph and subRows[gi] and subRows[gi]._icon
                    if icon then ns.PaintAppGlyph(icon) end
                end
            end
            local hover = Utils.AttachHoverPopup(row, popup, {
                extraGuards = hoverGuards,
                onShow = function()
                    SetActiveFlyout(popup)
                    SyncSubChecks()
                    PaintSubGlyphs()
                    popup:SetScale(EasyFind.db.uiSearchScale or 1.0)
                    PositionPopup()
                    popup:Show()
                end,
            })



            row.ShowFlyoutPopup = hover.Show
            row.ScheduleHideFlyoutPopup = hover.ScheduleHide


            dropdown:HookScript("OnHide", function() popup:Hide() end)
        end





        if opt.flyoutRadio and not opt.flyoutSubFilters then
            local radio = opt.flyoutRadio
            local SUB_POPUP_WIDTH = 200
            local SUB_ROW_H = 22
            local SUB_PAD = 6



            local options = radio.options
            if type(options) == "function" then options = options() end
            options = options or {}
            local checkboxes = radio.checkboxes or {}
            local hasSeparator = #options > 0 and #checkboxes > 0
            local SEPARATOR_H = hasSeparator and 8 or 0

            local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            popup:SetFrameStrata("TOOLTIP")
            StylePopup(popup)
            popup:EnableMouse(true)
            popup:Hide()
            row.flyoutPopup = popup
            dropdownGuardFrames[#dropdownGuardFrames + 1] = popup
            dropdown.flyoutPopups = dropdown.flyoutPopups or {}
            dropdown.flyoutPopups[#dropdown.flyoutPopups + 1] = popup

            Filters.AttachOutsideClickClose(popup, { onHide = ClearActiveFlyout })

            local radioRows = {}
            for ri, optionDef in ipairs(options) do
                local rRow = CreateFrame("Button", nil, popup)
                rRow:SetSize(SUB_POPUP_WIDTH - SUB_PAD * 2, SUB_ROW_H)
                rRow:SetPoint("TOPLEFT", popup, "TOPLEFT",
                    SUB_PAD, -(SUB_PAD + (ri - 1) * SUB_ROW_H))

                local bullet = rRow:CreateTexture(nil, "ARTWORK")
                bullet:SetAtlas("common-dropdown-tickradial")
                bullet:SetSize(14, 14)
                bullet:SetPoint("LEFT", 4, 0)

                local tick = rRow:CreateTexture(nil, "OVERLAY")
                tick:SetAtlas("common-dropdown-icon-radialtick-yellow")
                tick:SetSize(14, 14)
                tick:SetPoint("LEFT", 4, 0)
                tick:Hide()

                local lbl = rRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                lbl:SetPoint("LEFT", bullet, "RIGHT", 6, 0)
                lbl:SetText(optionDef.label)

                InstallMenuRowHighlight(rRow)

                rRow.tick = tick
                rRow.value = optionDef.value
                rRow._label = lbl
                rRow._dimTex = { bullet, tick }
                rRow:SetScript("OnClick", function(self)
                    EasyFind.db[radio.dbKey] = self.value
                    for _, otherRow in ipairs(radioRows) do
                        otherRow.tick:SetShown(otherRow.value == self.value)
                    end
                    if radio.onChange then radio.onChange(self.value) end
                    Filters:RerunActiveSearch()
                    KeepSearchEditBoxUnfocused()
                end)

                radioRows[ri] = rRow
            end

            local checkboxRows = {}
            local cbStartY = SUB_PAD + #options * SUB_ROW_H + SEPARATOR_H
            for ci, cbDef in ipairs(checkboxes) do
                local cRow = CreateFrame("Button", nil, popup)
                cRow:SetSize(SUB_POPUP_WIDTH - SUB_PAD * 2, SUB_ROW_H)
                cRow:SetPoint("TOPLEFT", popup, "TOPLEFT",
                    SUB_PAD, -(cbStartY + (ci - 1) * SUB_ROW_H))

                local box = cRow:CreateTexture(nil, "ARTWORK")
                box:SetAtlas("common-dropdown-ticksquare")
                box:SetSize(12, 12)
                box:SetPoint("LEFT", 5, 0)

                local tick = cRow:CreateTexture(nil, "OVERLAY")
                tick:SetAtlas("common-dropdown-icon-checkmark-yellow")
                tick:SetSize(14, 14)
                tick:SetPoint("LEFT", 4, 0)
                tick:Hide()

                local lbl = cRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                lbl:SetPoint("LEFT", box, "RIGHT", 6, 0)


                local labelText = cbDef.label
                if type(labelText) == "function" then labelText = labelText() end
                lbl:SetText(labelText)

                InstallMenuRowHighlight(cRow)

                cRow.tick = tick
                cRow.dbKey = cbDef.dbKey
                cRow.onChange = cbDef.onChange
                cRow._label = lbl
                cRow._dimTex = { box, tick }
                cRow.resolveDbPath = function()
                    return ns.ResolveDbKey(cbDef.dbKey)
                end
                cRow:SetScript("OnClick", function(self)
                    local tbl, leaf = self.resolveDbPath()
                    local next = not tbl[leaf]
                    tbl[leaf] = next
                    self.tick:SetShown(next)
                    if self.onChange then self.onChange(next) end
                    Filters:RerunActiveSearch()
                    KeepSearchEditBoxUnfocused()
                end)
                if cbDef.tooltip then


                    cRow:HookScript("OnEnter", function(self)
                        local token = (self._tipToken or 0) + 1
                        self._tipToken = token
                        Utils.SafeAfter(ns.TOOLTIP_HOVER_DELAY, function()
                            if self._tipToken ~= token or not self:IsMouseOver() then return end
                            local tip = cbDef.tooltip
                            if type(tip) == "function" then tip = tip() end
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetText(tip, 1, 1, 1, 1, true)
                            GameTooltip:Show()
                        end)
                    end)
                    cRow:HookScript("OnLeave", function(self)
                        self._tipToken = (self._tipToken or 0) + 1
                        GameTooltip:Hide()
                    end)
                end
                checkboxRows[ci] = cRow
            end




            local contentW = 0
            for ri = 1, #radioRows do
                local w = Utils.FlyoutRowContentWidth(radioRows[ri], 24)
                if w > contentW then contentW = w end
            end
            for ci = 1, #checkboxRows do
                local w = Utils.FlyoutRowContentWidth(checkboxRows[ci], 24)
                if w > contentW then contentW = w end
            end
            local popupW = Utils.FlyoutWidthFor(contentW, SUB_PAD)
            for ri = 1, #radioRows do radioRows[ri]:SetWidth(popupW - SUB_PAD * 2) end
            for ci = 1, #checkboxRows do checkboxRows[ci]:SetWidth(popupW - SUB_PAD * 2) end
            popup:SetSize(popupW,
                SUB_PAD * 2 + #options * SUB_ROW_H + SEPARATOR_H + #checkboxes * SUB_ROW_H)

            if hasSeparator then
                local sep = popup:CreateTexture(nil, "ARTWORK")
                sep:SetColorTexture(1, 1, 1, 0.12)
                popup._efThemeSeps = popup._efThemeSeps or {}
                popup._efThemeSeps[#popup._efThemeSeps + 1] = sep
                ns.RetintMenuSeparators(popup)
                sep:SetHeight(1)
                sep:SetPoint("LEFT", popup, "LEFT", SUB_PAD, 0)
                sep:SetPoint("RIGHT", popup, "RIGHT", -SUB_PAD, 0)
                sep:SetPoint("TOP", popup, "TOP", 0,
                    -(SUB_PAD + #options * SUB_ROW_H + SEPARATOR_H * 0.5))
            end

            local function SyncRadio()
                local parentEnabled = EasyFind.db.uiSearchFilters[opt.key] ~= false
                if radio.dbKey then
                    local cur = EasyFind.db[radio.dbKey]
                    for _, rRow in ipairs(radioRows) do
                        rRow.tick:SetShown(rRow.value == cur)
                    end
                end
                for _, cRow in ipairs(checkboxRows) do
                    local tbl, leaf = cRow.resolveDbPath()
                    cRow.tick:SetShown(tbl[leaf] and true or false)
                end
                for _, rRow in ipairs(radioRows) do SetFlyoutRowEnabled(rRow, parentEnabled) end
                for _, cRow in ipairs(checkboxRows) do SetFlyoutRowEnabled(cRow, parentEnabled) end
            end
            row.SyncFlyoutSubChecks = SyncRadio
            popup._efSync = SyncRadio

            AddPopupKeyboardNav(popup, function()
                local navRows = {}
                for ri = 1, #radioRows do navRows[#navRows + 1] = radioRows[ri] end
                for ci = 1, #checkboxRows do navRows[#navRows + 1] = checkboxRows[ci] end
                return navRows
            end)

            local function PositionPopup()
                Utils.OpenFlyoutBeside(popup, row, 4)
            end
            local hover = Utils.AttachHoverPopup(row, popup, {
                onShow = function()
                    SetActiveFlyout(popup)
                    SyncRadio()
                    popup:SetScale(EasyFind.db.uiSearchScale or 1.0)
                    PositionPopup()
                    popup:Show()
                end,
            })
            row.ShowFlyoutPopup = hover.Show
            row.ScheduleHideFlyoutPopup = hover.ScheduleHide
            dropdown:HookScript("OnHide", function() popup:Hide() end)
        end




        if opt.key == "loot" then
            Search:AttachLootOptionsFlyout(row, dropdown, {
                rowHeight = ROW_HEIGHT,
                checkSize = CHECK_SIZE,
                StylePopup = StylePopup,
                CreateRadioTexture = CreateRadioTexture,
                AddPopupKeyboardNav = AddPopupKeyboardNav,
                SetActiveFlyout = SetActiveFlyout,
                ClearActiveFlyout = ClearActiveFlyout,
                dropdownGuardFrames = dropdownGuardFrames,
            })
        end



        if opt.key == "professions" and opt.hasFlyout then
            Filters:AttachProfessionOptionsFlyout(row, dropdown, {
                rowHeight = ROW_HEIGHT,
                checkSize = CHECK_SIZE,
                StylePopup = StylePopup,
                CreateRadioTexture = CreateRadioTexture,
                AddPopupKeyboardNav = AddPopupKeyboardNav,
                SetActiveFlyout = SetActiveFlyout,
                ClearActiveFlyout = ClearActiveFlyout,
                dropdownGuardFrames = dropdownGuardFrames,
            })
        end


        if opt.flyoutList and opt.hasFlyout then
            Filters:AttachListFlyout(row, dropdown, opt, {
                rowHeight = ROW_HEIGHT,
                checkSize = CHECK_SIZE,
                StylePopup = StylePopup,
                AddPopupKeyboardNav = AddPopupKeyboardNav,
                SetActiveFlyout = SetActiveFlyout,
                ClearActiveFlyout = ClearActiveFlyout,
                dropdownGuardFrames = dropdownGuardFrames,
            })
        end




        if opt.key == "housing" then
            Search:AttachHousingOptionsFlyout(row, dropdown, {
                rowHeight = ROW_HEIGHT,
                checkSize = CHECK_SIZE,
                StylePopup = StylePopup,
                CreateRadioTexture = CreateRadioTexture,
                AddPopupKeyboardNav = AddPopupKeyboardNav,
                SetActiveFlyout = SetActiveFlyout,
                ClearActiveFlyout = ClearActiveFlyout,
                dropdownGuardFrames = dropdownGuardFrames,
            })
        end

        InstallMenuRowHighlight(row)

        row:SetChecked(true)

        row:SetScript("OnClick", function(self)
            local filters = EasyFind.db.uiSearchFilters
            filters[opt.key] = self:GetChecked()
            if self.SyncFlyoutSubChecks then self.SyncFlyoutSubChecks() end
            Filters.ResyncShownOptionPopups()
            if self.updateLootToggle then self.updateLootToggle() end
            LayoutDropdown()
            Filters:RerunActiveSearch()
            KeepSearchEditBoxUnfocused()
        end)

        checkRows[opt.key] = row
        checkRowsByIndex[i] = row
    end


    local SUB_INDENT = 24
    local dropdownNavRows = {}
    local dropdownFocus = 0
    local dropdownFocusRow

    local function SetDropdownFocus(idx)
        if dropdownFocusRow and dropdownFocusRow.SetMenuHighlightFocused then
            dropdownFocusRow:SetMenuHighlightFocused(false)
        end
        dropdownFocus = idx
        local target = dropdownNavRows[idx]
        if target then
            if target.SetMenuHighlightFocused then
                target:SetMenuHighlightFocused(true)
            end
            dropdownFocusRow = target
        else
            dropdownFocusRow = nil
        end
    end

    local function ClearDropdownFocus()
        dropdownFocus = 0
        if dropdownFocusRow and dropdownFocusRow.SetMenuHighlightFocused then
            dropdownFocusRow:SetMenuHighlightFocused(false)
        end
        dropdownFocusRow = nil
    end

    function LayoutDropdown()
        local savedFocus = dropdownFocus
        wipe(dropdownNavRows)
        if dropdownFocusRow and dropdownFocusRow.SetMenuHighlightFocused then
            dropdownFocusRow:SetMenuHighlightFocused(false)
        end
        dropdownFocusRow = nil
        local filters = EasyFind.db.uiSearchFilters
        local y = -PADDING_TOP
        uncheckRow:ClearAllPoints()
        uncheckRow:SetPoint("TOPLEFT", 8, y)
        dropdownNavRows[#dropdownNavRows + 1] = uncheckRow
        y = y - ROW_HEIGHT
        for i, opt in ipairs(UI_FILTER_OPTIONS) do
            local row = checkRowsByIndex[i]
            local parentVisible = (not opt.parentKey) or (filters[opt.parentKey] ~= false)



            if not parentVisible or (opt.available and not opt.available()) then
                row:Hide()
            else
                local rowIndent = opt.parentKey and SUB_INDENT or 0
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 8 + rowIndent, y)
                row:Show()
                dropdownNavRows[#dropdownNavRows + 1] = row
                y = y - ROW_HEIGHT
            end
        end
        dropdown:SetSize(DROPDOWN_WIDTH, -y + PADDING_BOTTOM)
        Utils.RefreshMenuRowHighlights(dropdown, dropdownNavRows)
        if savedFocus > 0 and dropdown:IsKeyboardEnabled() then
            if savedFocus > #dropdownNavRows then savedFocus = #dropdownNavRows end
            SetDropdownFocus(savedFocus)
        end
    end

    Utils.SafeCallMethod(dropdown, "EnableKeyboard", false)
    Utils.SafeCallMethod(dropdown, "SetPropagateKeyboardInput", false)

    dropdown:SetScript("OnKeyDown", function(self, key)
        Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
        if key == "DOWN" then
            Search:GetSearchFrame().StartKeyRepeat(key, function()
                local next = dropdownFocus + 1
                if next > #dropdownNavRows then next = 1 end
                SetDropdownFocus(next)
            end)
        elseif key == "UP" then
            if dropdownFocus <= 1 then
                self._escapedViaKeyboard = true
                self:Hide()
                return
            end
            Search:GetSearchFrame().StartKeyRepeat(key, function()
                local prev = dropdownFocus - 1
                if prev < 1 then prev = 1 end
                SetDropdownFocus(prev)
            end)
        elseif key == "ENTER" then
            local target = dropdownNavRows[dropdownFocus]
            if target and target.Click then
                target:Click()
            end
        elseif key == "TAB" or key == "RIGHT" then
            local target = dropdownNavRows[dropdownFocus]
            if target and target.ShowFlyoutPopup then
                target.ShowFlyoutPopup()
            end
        elseif key == "ESCAPE" then
            self._escapedViaKeyboard = true
            if dropdownKeyboardMode then



                self:Hide()
            else


                Search:HandleEscape()
            end
        else
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", true)
        end
    end)
    dropdown:SetScript("OnKeyUp", function(_, key)
        if Search:GetSearchFrame().IsRepeatKey(key) then Search:GetSearchFrame().StopKeyRepeat() end
    end)




    uncheckRow:SetScript("OnClick", function()




        local filters = EasyFind.db.uiSearchFilters
        local allUnchecked = true
        for _, opt in ipairs(UI_FILTER_OPTIONS) do
            local target = opt.dbTable and EasyFind.db[opt.dbTable] or filters
            if target[opt.key] ~= false then
                allUnchecked = false
                break
            end
        end
        local newState = allUnchecked
        for _, opt in ipairs(UI_FILTER_OPTIONS) do
            local target = opt.dbTable and EasyFind.db[opt.dbTable] or filters
            target[opt.key] = newState
        end
        for _, opt in ipairs(UI_FILTER_OPTIONS) do
            local row = checkRows[opt.key]
            if row then
                row:SetChecked(newState)
                if row.SyncFlyoutSubChecks then row.SyncFlyoutSubChecks() end
            end
        end
        local lootRow = checkRows["loot"]
        if lootRow and lootRow.updateLootToggle then lootRow.updateLootToggle() end
        Filters.ResyncShownOptionPopups()
        LayoutDropdown()
        Filters:RerunActiveSearch()
        KeepSearchEditBoxUnfocused()
    end)

    LayoutDropdown()

    dropdown:HookScript("OnShow", function(self)
        if ns.RegisterAddonFontsIn then
            ns.RegisterAddonFontsIn(self)
            for i = 1, #dropdownGuardFrames do
                ns.RegisterAddonFontsIn(dropdownGuardFrames[i])
            end
        end
    end)
    dropdown:SetScript("OnShow", function(self)





        pcall(ns.ApplyMenuOpacity, self)
        if Utils.RefreshMenuRowHighlights then
            pcall(Utils.RefreshMenuRowHighlights, self)
        end
        pcall(RecolorFilterRowLabels, self)
        local filters = EasyFind.db.uiSearchFilters
        for key, row in pairs(checkRows) do
            row:SetChecked(filters[key] ~= false)
            if row.updateLootToggle then row.updateLootToggle() end
            if row.SyncFlyoutSubChecks then row.SyncFlyoutSubChecks() end
        end
        LayoutDropdown()
    end)

    dropdown:SetScript("OnHide", function() end)


    dropdown:HookScript("OnShow", function(self)


        if ns.Database and ns.Database.SyncTransmogSetFiltersFromUI then
            local db = EasyFind.db
            local beforeClassID = type(db.appearanceSetClass) == "table"
                and db.appearanceSetClass.classID or db.appearanceSetClass
            local beforeCollected = db.appearanceSetCollected
            local beforeNotCollected = db.appearanceSetNotCollected
            local beforePvE = db.appearanceSetPvE
            local beforePvP = db.appearanceSetPvP

            ns.Database:SyncTransmogSetFiltersFromUI()

            local afterClassID = type(db.appearanceSetClass) == "table"
                and db.appearanceSetClass.classID or db.appearanceSetClass
            local changed = beforeClassID ~= afterClassID
                or beforeCollected ~= db.appearanceSetCollected
                or beforeNotCollected ~= db.appearanceSetNotCollected
                or beforePvE ~= db.appearanceSetPvE
                or beforePvP ~= db.appearanceSetPvP
            if changed and ns.Database.RefreshDynamicCategory then
                ns.Database:RefreshDynamicCategory("transmogSets")
                Filters:RerunActiveSearch()
            end

        end
        local filterBtn = Search:GetSearchFrame().filterBtn
        dropdownKeyboardMode = filterBtn and filterBtn.keyboardFocused or false
        Utils.SafeCallMethod(Search:GetNavFrame(), "EnableKeyboard", false)
        Utils.SafeCallMethod(self, "EnableKeyboard", true)
        if dropdownKeyboardMode then
            SetDropdownFocus(1)
        else
            ClearDropdownFocus()
        end
    end)


    dropdown:HookScript("OnHide", function(self)
        ClearDropdownFocus()
        Utils.SafeCallMethod(self, "EnableKeyboard", false)
        local escapedViaKeyboard = self._escapedViaKeyboard
        self._escapedViaKeyboard = nil
        if escapedViaKeyboard and not Search:IsEscClosingMenus() then
            dropdownKeyboardMode = false




            local fb = Search:GetSearchFrame().filterBtn
            Utils.SafeCallMethod(Search:GetNavFrame(), "EnableKeyboard",
                Search:GetSelectedIndex() > 0 or (fb and fb.keyboardFocused) or false)
        else
            dropdownKeyboardMode = false
            if Search:GetSearchFrame().ClearToolbarFocus then Search:GetSearchFrame().ClearToolbarFocus() end
            Utils.SafeCallMethod(Search:GetNavFrame(), "EnableKeyboard", false)
            if Search:GetSearchFrame().filterBtn then
                local fb = Search:GetSearchFrame().filterBtn
                fb.keyboardFocused = nil





                if not fb:IsMouseOver() then
                    if fb.btnBg then fb.btnBg:Hide() end
                    if fb.UnlockHighlight then fb:UnlockHighlight() end
                end
            end




            if Search:GetSearchFrame().editBox and not Search:GetSearchFrame().editBox:IsMouseOver()
               and not Search:IsEscClosingMenus() then
                Search:GetSearchFrame().editBox:ClearFocus()
            end
        end
    end)











    dropdown:HookScript("OnShow", function(self)
        self:RegisterEvent("GLOBAL_MOUSE_DOWN")
    end)
    dropdown:HookScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    end)
    dropdown:SetScript("OnEvent", function(self, event)
        if event ~= "GLOBAL_MOUSE_DOWN" then return end
        if not Filters.IsMouseInFilterChain() then self:Hide() end
    end)

    toggleBtn:SetScript("OnClick", function()
        if dropdown:IsShown() then
            dropdown:Hide()
        else
            local barScale = EasyFind.db.uiSearchScale or 1.0
            dropdown:SetScale(barScale)
            local scale = anchorFrame:GetEffectiveScale() / (UIParent:GetEffectiveScale() * barScale)
            local right = anchorFrame:GetRight() * scale
            dropdown:ClearAllPoints()
            if EasyFind.db.uiResultsAbove then


                local top = anchorFrame:GetTop() * scale
                dropdown:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", right, top)
            else
                local bottom = anchorFrame:GetBottom() * scale
                dropdown:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, bottom)
            end
            dropdown:Show()
            KeepSearchEditBoxUnfocused()
        end
    end)

    local searchFrame = Search:GetSearchFrame()
    searchFrame.filterDropdown = dropdown


    dropdown:HookScript("OnShow", function()
        local btn = searchFrame.filterBtn
        if btn and btn.SetMenuEngaged then btn:SetMenuEngaged(true) end





        if searchFrame.appsDropdown and searchFrame.appsDropdown:IsShown() then
            searchFrame.appsDropdown:Hide()
        end
    end)
    dropdown:HookScript("OnHide", function()
        local btn = searchFrame.filterBtn
        if btn and btn.SetMenuEngaged then btn:SetMenuEngaged(false) end
    end)
end
