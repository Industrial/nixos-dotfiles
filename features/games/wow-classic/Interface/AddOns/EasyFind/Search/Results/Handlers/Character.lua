local _, ns = ...

local Search = ns.Search
local Handlers = ns.ResultHandlers
local Openers = ns.SearchOpeners
local Utils = ns.Utils

local ClickButton = Utils.ClickButton
local select = Utils.select
local slower = Utils.slower
local CreateFrame = CreateFrame
local C_Reputation = C_Reputation
local C_CurrencyInfo = C_CurrencyInfo
local MAX_WATCHED_TOKENS_CAP = _G["MAX_WATCHED_TOKENS"] or 3

function Handlers:ClickCharacterSidebar(sidebarIndex)



    if not CharacterFrame or not CharacterFrame:IsShown() then
        return false
    end


    if PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(CharacterFrame) ~= 1 then
        Openers:OpenCharacterFrame(1)
    end


    if ns.Caps and ns.Caps.CharacterSidebarSlot then
        sidebarIndex = ns.Caps.CharacterSidebarSlot(sidebarIndex)
        if not sidebarIndex then return false end
    end


    local sidebarTab = _G["PaperDollSidebarTab" .. sidebarIndex]
    if sidebarTab then
        if sidebarTab:IsShown() then
            return ClickButton(sidebarTab)
        else

            Utils.SafeAfter(0.2, function()
                if sidebarTab:IsShown() then ClickButton(sidebarTab) end
            end)
            return true
        end
    end


    local sidebarTabs = _G["PaperDollSidebarTabs"]
    if not sidebarTabs and PaperDollFrame then
        sidebarTabs = PaperDollFrame.SidebarTabs
    end
    if sidebarTabs then
        local nTabs = select("#", sidebarTabs:GetChildren())
        if sidebarIndex <= nTabs then
            return ClickButton(select(sidebarIndex, sidebarTabs:GetChildren()))
        end
    end


    if PaperDollFrame and PaperDollFrame.ToggleSidebarTab then
        PaperDollFrame:ToggleSidebarTab(sidebarIndex)
        return true
    end

    return false
end

function Handlers:IsCurrencyOnBackpack(currencyID)
    if not currencyID or currencyID == 0 or not C_CurrencyInfo then return false end





    local getInfo = C_CurrencyInfo.GetBackpackCurrencyInfo
    if getInfo then
        local cap = MAX_WATCHED_TOKENS_CAP
        for i = 1, cap do
            local bok, bi = pcall(getInfo, i)
            if not bok or type(bi) ~= "table" then break end
            local id = bi.currencyTypesID or bi.currencyID







            if id and id ~= 0 and id == currencyID then return true end
        end
        return false
    end


    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
    if not ok or type(info) ~= "table" then return false end
    return info.isShowInBackpack and true or false
end




local function RefreshDropdownLabel(dropdown)
    if not dropdown then return end
    if dropdown.GenerateMenu then pcall(dropdown.GenerateMenu, dropdown)
    elseif dropdown.RefreshMenu then pcall(dropdown.RefreshMenu, dropdown)
    elseif dropdown.SignalUpdate then pcall(dropdown.SignalUpdate, dropdown) end
end



function Handlers:ApplyTokenFrameFilter(mode)
    if not mode or not C_CurrencyInfo or not C_CurrencyInfo.SetCurrencyFilter then return end
    if not Enum or not Enum.CurrencyFilterType then return end
    local target = (mode == "warband")
        and Enum.CurrencyFilterType.DiscoveredAndAllAccountTransferable
        or  Enum.CurrencyFilterType.DiscoveredOnly
    local current = C_CurrencyInfo.GetCurrencyFilter and C_CurrencyInfo.GetCurrencyFilter()
    if current == target then return end


    if TokenFrame then
        TokenFrame.selectedToken = nil
        TokenFrame.selectedID = nil
    end
    if TokenFramePopup and TokenFramePopup.Hide then TokenFramePopup:Hide() end
    pcall(C_CurrencyInfo.SetCurrencyFilter, target)
    if TokenFrame and TokenFrame:IsShown() then
        if TokenFrame.Update then pcall(TokenFrame.Update, TokenFrame) end
        RefreshDropdownLabel(TokenFrame.filterDropdown)
    end
end



function Handlers:ApplyReputationFilter(mode)
    if not mode or not C_Reputation or not C_Reputation.SetReputationSortType then return end
    if not Enum or not Enum.ReputationSortType then return end
    local sortType
    if mode == "warband" then
        sortType = Enum.ReputationSortType.Account
    elseif mode == "char" then
        sortType = Enum.ReputationSortType.Character
    else
        sortType = Enum.ReputationSortType.None
    end
    local current = C_Reputation.GetReputationSortType and C_Reputation.GetReputationSortType()
    if current == sortType then return end
    pcall(C_Reputation.SetReputationSortType, sortType)
    if ReputationFrame and ReputationFrame:IsShown() then
        if ReputationFrame.Update then pcall(ReputationFrame.Update, ReputationFrame) end
        RefreshDropdownLabel(ReputationFrame.filterDropdown)
    end
end


function Handlers:ApplyReputationShowLegacy(show)
    if not C_Reputation or not C_Reputation.SetLegacyReputationsShown then return end
    show = show and true or false
    local current = C_Reputation.AreLegacyReputationsShown and C_Reputation.AreLegacyReputationsShown()
    if current == show then return end
    pcall(C_Reputation.SetLegacyReputationsShown, show)
    if ReputationFrame and ReputationFrame:IsShown() then
        if ReputationFrame.Update then pcall(ReputationFrame.Update, ReputationFrame) end
        RefreshDropdownLabel(ReputationFrame.filterDropdown)
    end
end

local function GetReputationFactionIndexByID(factionID)
    if not factionID then return nil end
    return Utils.FindFactionByPredicate(function(d) return d.factionID == factionID end)
end

function Handlers:IsReputationWatched(factionID)
    if not factionID then return false end
    if C_Reputation then
        if C_Reputation.GetFactionDataByID then
            local ok, factionData = pcall(C_Reputation.GetFactionDataByID, factionID)
            if ok and factionData and factionData.isWatched then return true end
        end
        if C_Reputation.GetWatchedFactionData then
            local ok, watchedData = pcall(C_Reputation.GetWatchedFactionData)
            if ok and watchedData and watchedData.factionID == factionID then return true end
        end
    end

    local getWatched = _G["GetWatchedFactionInfo"]
    if getWatched then
        local ok, _, _, _, _, _, watchedFactionID = pcall(getWatched)
        if ok and watchedFactionID == factionID then return true end
    end
    return false
end

local function RefreshReputationSurfaces()
    if ReputationFrame and ReputationFrame:IsShown() then
        if ReputationFrame.Update then pcall(ReputationFrame.Update, ReputationFrame) end
        RefreshDropdownLabel(ReputationFrame.filterDropdown)
    end
    if Search and Search.RefreshResults then Search:RefreshResults() end
end

function Handlers:ToggleReputationWatched(factionID)
    if not factionID then return false end

    local clearWatch = Handlers:IsReputationWatched(factionID)
    if C_Reputation and C_Reputation.SetWatchedFactionByID then
        local ok = pcall(C_Reputation.SetWatchedFactionByID, clearWatch and 0 or factionID)
        if ok then
            RefreshReputationSurfaces()
            return true
        end
    end

    local setWatchedIndex = _G["SetWatchedFactionIndex"]
    if setWatchedIndex then
        local factionIndex = clearWatch and 0 or GetReputationFactionIndexByID(factionID)
        if factionIndex then
            local ok = pcall(setWatchedIndex, factionIndex)
            if ok then
                RefreshReputationSurfaces()
                return true
            end
        end
    end
    return false
end



function Handlers:HookBlizzardFilterChanges()
    if C_CurrencyInfo and C_CurrencyInfo.SetCurrencyFilter and Enum and Enum.CurrencyFilterType then
        hooksecurefunc(C_CurrencyInfo, "SetCurrencyFilter", function(filterType)
            if not EasyFind.db then return end
            EasyFind.db.currencyFilterMode = (filterType == Enum.CurrencyFilterType.DiscoveredAndAllAccountTransferable)
                and "warband" or "all"
        end)
    end
    if C_Reputation and C_Reputation.SetReputationSortType and Enum and Enum.ReputationSortType then
        hooksecurefunc(C_Reputation, "SetReputationSortType", function(sortType)
            if not EasyFind.db then return end
            if sortType == Enum.ReputationSortType.Account then
                EasyFind.db.reputationFilterMode = "warband"
            elseif sortType == Enum.ReputationSortType.Character then
                EasyFind.db.reputationFilterMode = "char"
            else
                EasyFind.db.reputationFilterMode = "all"
            end
        end)
    end
    if C_Reputation and C_Reputation.SetLegacyReputationsShown then
        hooksecurefunc(C_Reputation, "SetLegacyReputationsShown", function(show)
            if not EasyFind.db then return end
            EasyFind.db.showLegacyReputations = show and true or false
        end)
    end

    local cvarFrame = CreateFrame("Frame")
    cvarFrame:RegisterEvent("CVAR_UPDATE")
    cvarFrame:SetScript("OnEvent", function(_, _, name, value)
        if not name or not EasyFind.db then return end
        if slower(name) == "spellbookhidepassives" then
            EasyFind.db.abilityHidePassives = value == "1" or value == 1 or value == true
        end
    end)
end

function Handlers:ToggleCurrencyBackpack(currencyID)
    if not currencyID or not C_CurrencyInfo then return end
    local on = self:IsCurrencyOnBackpack(currencyID)
    local target = not on




    if target and C_CurrencyInfo.GetBackpackCurrencyInfo then
        local cap = MAX_WATCHED_TOKENS_CAP
        local count = 0
        for i = 1, cap + 1 do
            local bok, bi = pcall(C_CurrencyInfo.GetBackpackCurrencyInfo, i)
            if not bok or type(bi) ~= "table" then break end
            count = count + 1
        end
        if count >= cap then
            local msg = string.format(ns.L["MSG_CURRENCY_WATCH_LIMIT"], cap)
            local errFrame = _G["UIErrorsFrame"]
            if errFrame and errFrame.AddMessage then
                errFrame:AddMessage(msg, 1.0, 0.1, 0.1, 1.0)
            end
            return
        end
    end





    if C_CurrencyInfo.SetCurrencyBackpackByID then
        pcall(C_CurrencyInfo.SetCurrencyBackpackByID, currencyID, target)
    elseif C_CurrencyInfo.SetCurrencyBackpack then
        pcall(C_CurrencyInfo.SetCurrencyBackpack, currencyID, target)
    end





    local tokens = _G["BackpackTokenFrame"]
    if type(tokens) == "table" and tokens.Update then
        pcall(tokens.Update, tokens)
    elseif type(_G["BackpackTokenFrame_Update"]) == "function" then
        pcall(_G["BackpackTokenFrame_Update"])
    end
end

function Handlers:IsCurrencyTransferable(currencyID)
    return ns.Database and ns.Database.IsCurrencyAccountTransferable
       and ns.Database:IsCurrencyAccountTransferable(currencyID) or false
end





function Handlers:RouteCurrencyTransfer(pinData)
    if not pinData then return end
    local currencyID = pinData.currencyID



    local highlight = ns.RequestGuide()
    if highlight and highlight.SetPersistentCurrencyHighlight then
        highlight:SetPersistentCurrencyHighlight(true)
    end
    self:SelectResult(pinData)
    if not (currencyID and Utils and Utils.SafeAfter and highlight) then return end



    local highlightDone = false
    local function watchForPopup(remaining)
        if highlightDone then return end
        local popup = _G["TokenFramePopup"]
        local btn = popup and popup.CurrencyTransferToggleButton
        if popup and popup:IsShown() and btn and btn:IsShown() then
            highlightDone = true
            ns.Highlight:StartGuide({
                steps = { { buttonFrame = "TokenFramePopup.CurrencyTransferToggleButton" } }
            })
            return
        end
        if remaining > 0 then
            Utils.SafeAfter(0.2, function() watchForPopup(remaining - 1) end)
        end
    end
    Utils.SafeAfter(0.2, function() watchForPopup(50) end)
end






local DESTROY_TYPED_CONFIRM_QUALITY = 2
function Handlers:DestroyBagItem(data)
    if not (data and data.bagID ~= nil and data.bagSlot) then return end
    if not (C_Container and C_Container.GetContainerItemInfo
            and C_Container.PickupContainerItem and C_Container.GetContainerNumSlots) then return end
    local bag, slot = data.bagID, data.bagSlot
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if data.itemID and (not info or info.itemID ~= data.itemID) then
        bag, slot, info = nil, nil, nil
        for scanBag = 0, 5 do
            for scanSlot = 1, C_Container.GetContainerNumSlots(scanBag) or 0 do
                local scanInfo = C_Container.GetContainerItemInfo(scanBag, scanSlot)
                if scanInfo and scanInfo.itemID == data.itemID then
                    bag, slot, info = scanBag, scanSlot, scanInfo
                    break
                end
            end
            if bag then break end
        end
    end
    if not (bag and slot and info) then return end
    if CursorHasItem() then ClearCursor() end
    C_Container.PickupContainerItem(bag, slot)
    if not CursorHasItem() then return end
    local itemName = data.name
        or (info.hyperlink and info.hyperlink:match("%[(.-)%]")) or ""
    local quality = info.quality or data.quality
    if quality and quality >= DESTROY_TYPED_CONFIRM_QUALITY then
        StaticPopup_Show("DELETE_GOOD_ITEM", itemName)
    else
        StaticPopup_Show("DELETE_ITEM", itemName)
    end
end
