local _, ns = ...

local Search = ns.Search
local Results = ns.Results
local Rows = ns.ResultRows
local Tooltips = ns.ResultTooltips
local Handlers = ns.ResultHandlers
local Utils = ns.Utils
local L = ns.L

local select = Utils.select
local sformat = Utils.sformat
local mfloor = Utils.mfloor

local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local UIParent = UIParent
local GetCursorPosition = GetCursorPosition
local IsControlKeyDown, IsShiftKeyDown, IsAltKeyDown = IsControlKeyDown, IsShiftKeyDown, IsAltKeyDown

local function AnchorRowTooltip(tooltip, ownerFrame)
    return Tooltips:AnchorRowTooltip(tooltip, ownerFrame)
end

local function GetUnearnedTooltip()
    return Tooltips:GetUnearnedTooltip()
end




local function HeldKeys()
    return (IsControlKeyDown() and 1 or 0) + (IsShiftKeyDown() and 2 or 0) + (IsAltKeyDown() and 4 or 0)
end
local keyWatch = CreateFrame("Frame")
keyWatch:Hide()
keyWatch:SetScript("OnUpdate", function(self, elapsed)
    self.wait = (self.wait or 0) - elapsed
    if self.wait > 0 then return end
    self.wait = 0.03
    local row = self.row
    if not (row and GameTooltip:IsShown() and GameTooltip:IsOwned(row)) then
        self.row = nil
        self:Hide()
        return
    end
    local keys = HeldKeys()
    if keys ~= self.keys then
        self.keys = keys
        row:_efRedrawTooltip()
    end
end)

local function WatchHeldKeys(row)
    keyWatch.row, keyWatch.keys, keyWatch.wait = row, HeldKeys(), 0
    keyWatch:Show()
end


function Rows.RedrawHoveredTooltip()
    local row = Results._hoverRow
    if row and row._efRedrawTooltip and GameTooltip:IsShown() and GameTooltip:IsOwned(row) then
        row:_efRedrawTooltip()
    end
end

function Rows.InstallTooltips(resultRow)


    local function ShowTooltip(self, again)





        local provider = self.data and ns.Extensions and ns.Extensions.ProviderOf(self.data)
        if provider and provider.tooltip then
            local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
            if owner and owner._efEmbedsTooltip then return end
            AnchorRowTooltip(GameTooltip, self)
            local ok, filled = ns.Extensions.Run(provider.tooltip, self.data, GameTooltip)
            if ok and filled then GameTooltip:Show() else GameTooltip:Hide() end
            return
        end


        if self.data and self.data.housingEntryID and self.data.category == "Housing" then
            AnchorRowTooltip(GameTooltip, self)
            local quality = self.data.housingQuality
            local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
            GameTooltip:SetText(self.data.name or "", qc and qc.r or 1, qc and qc.g or 1, qc and qc.b or 1)
            local ownedFormat = _G["HOUSING_DECOR_OWNED_COUNT_FORMAT"]
            local stored = self.data.housingNumStored or 0
            local placed = self.data.housingNumPlaced or 0
            if ownedFormat then
                GameTooltip:AddLine(sformat(ownedFormat, stored + placed, placed, stored), 1, 1, 1, true)
            end
            if self.data.housingSourceText and self.data.housingSourceText ~= "" then
                GameTooltip:AddLine(self.data.housingSourceText, 0.7, 0.7, 0.7, true)
            end
            GameTooltip:Show()
            return
        end



        local storedHolders = self.data and self.data.storedHolders
        if storedHolders and #storedHolders > 0 then
            local cat = self.data.category
            local isBank = cat == "Bank" or cat == "Warband"
            local ht = EasyFind.db.hideTooltips
            if ht and ht[isBank and "bank" or "bags"] then return end
            AnchorRowTooltip(GameTooltip, self)
            if GameTooltip.SetItemByID then
                GameTooltip:SetItemByID(self.data.itemID)
            else
                GameTooltip:SetText(self.data.name or "", 1, 1, 1)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(ns.StoredCategoryLabel(cat), 1, 0.82, 0)
            for i = 1, #storedHolders do
                local holder = storedHolders[i]
                local where = holder.name or "?"
                if holder.tabName and holder.tabName ~= "" then
                    where = where .. " - " .. holder.tabName
                end
                GameTooltip:AddDoubleLine(where, holder.count or 1,
                    1, 1, 1, 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
            return
        end

        if self.data and self.data.catalogItem then
            local ht = EasyFind.db.hideTooltips
            if ht and ht.items then return end
            AnchorRowTooltip(GameTooltip, self)
            if GameTooltip.SetItemByID then
                GameTooltip:SetItemByID(self.data.itemID)
            end
            GameTooltip:Show()
            return
        end



        if self.data and self.data.macroIndex and self.data.category == "Macro" then
            local ht = EasyFind.db.hideTooltips
            if ht and ht.macros then return end
            local idx = self.data.macroIndex
            local spellID
            if GetMacroSpell then
                local _, _, sid = GetMacroSpell(idx)
                spellID = sid
            end
            local itemName, itemLink
            if not spellID and GetMacroItem then
                itemName, itemLink = GetMacroItem(idx)
            end
            AnchorRowTooltip(GameTooltip, self)
            if spellID and GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(spellID)
            elseif itemLink and GameTooltip.SetHyperlink then
                GameTooltip:SetHyperlink(itemLink)
            elseif itemName and GameTooltip.SetItemByID and C_Item and C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(itemName)) then
                GameTooltip:SetHyperlink(select(2, C_Item.GetItemInfo(itemName)))
            else
                GameTooltip:SetText(self.data.name or (_G["MACRO"] or "Macro"), 1, 1, 1)
                if self.data.macroBody and self.data.macroBody ~= "" then
                    GameTooltip:AddLine(self.data.macroBody, 0.7, 0.7, 0.7, true)
                end
            end
            GameTooltip:Show()
            return
        end



        if self.data and self.data.spellID
           and (self.data.category == "Talent" or self.data.category == "Ability") then
            local ht = EasyFind.db.hideTooltips
            if ht and ((self.data.category == "Ability" and ht.abilities)
                       or (self.data.category == "Talent" and ht.talents)) then
                return
            end
            AnchorRowTooltip(GameTooltip, self)
            if not Tooltips:SetClassicTalent(GameTooltip, self.data) then
                if GameTooltip.SetSpellByID then
                    GameTooltip:SetSpellByID(self.data.spellID)
                else
                    GameTooltip:SetHyperlink("spell:" .. self.data.spellID)
                end
            end
            GameTooltip:Show()
            return
        end


        if self.data and self.data.professionRecipeID then
            AnchorRowTooltip(GameTooltip, self)
            if GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(self.data.professionRecipeID)
            else
                GameTooltip:SetHyperlink("spell:" .. self.data.professionRecipeID)
            end
            GameTooltip:Show()
            return
        end




        if self.data and self.data.category == "Currency" and self.data.currencyID then
            local ht = EasyFind.db.hideTooltips
            if ht and ht.currencies then return end
            local cid = self.data.currencyID
            AnchorRowTooltip(GameTooltip, self)
            if GameTooltip.SetCurrencyByID then
                GameTooltip:SetCurrencyByID(cid)
            elseif C_CurrencyInfo and C_CurrencyInfo.GetCurrencyLink then
                local lok, link = pcall(C_CurrencyInfo.GetCurrencyLink, cid)
                if lok and link and GameTooltip.SetHyperlink then
                    GameTooltip:SetHyperlink(link)
                end
            end
            GameTooltip:Show()
            return
        end










        local achFromTitle
        if self.data and not self.data.achievementID and self.data.titleID
           and ns.Database and ns.Database.GetTitleSourceAchievement then
            achFromTitle = ns.Database:GetTitleSourceAchievement(self.data.titleID)
        end
        if self.data and (self.data.achievementID or achFromTitle) then
            local ht = EasyFind.db.hideTooltips
            if ht and ht.achievements then return end
            local achID = self.data.achievementID or achFromTitle
            local _, name, _, completed, _, _, _, description, _, _, rewardText =
                GetAchievementInfo(achID)
            if name then
                AnchorRowTooltip(GameTooltip, self)
                GameTooltip:SetText(name, 1, 0.82, 0)


                if completed then
                    GameTooltip:AddLine(ns.ACH_LABEL_EARNED, 0.25, 0.9, 0.25)
                else
                    GameTooltip:AddLine(ns.ACH_LABEL_INCOMPLETE, 0.6, 0.6, 0.6)
                end
                if description and description ~= "" then
                    GameTooltip:AddLine(description, 1, 1, 1, true)
                end
                local numCriteria = GetAchievementNumCriteria and GetAchievementNumCriteria(achID) or 0
                if numCriteria > 0 then
                    GameTooltip:AddLine(" ")
                    for i = 1, numCriteria do
                        local critString, _, critDone, quantity, reqQuantity, _, _, _, quantityString =
                            GetAchievementCriteriaInfo(achID, i)
                        local label = (critString and critString ~= "") and critString or nil
                        local progress
                        if reqQuantity and reqQuantity > 1 then
                            progress = (quantityString and quantityString ~= "") and quantityString
                                or ((quantity or 0) .. "/" .. reqQuantity)
                        end
                        if not label then
                            label = progress
                        elseif progress then
                            label = label .. "  (" .. progress .. ")"
                        end
                        if label and label ~= "" then
                            if critDone then
                                GameTooltip:AddLine(label, 0.25, 0.9, 0.25)
                            else
                                GameTooltip:AddLine(label, 0.6, 0.6, 0.6)
                            end
                        end
                    end
                end


                if GetPreviousAchievement then
                    local ancestors = {}
                    local pid = achID
                    for _ = 1, 20 do
                        local cid = GetPreviousAchievement(pid)
                        if not cid then break end
                        local _, cname, _, cdone = GetAchievementInfo(cid)
                        ancestors[#ancestors + 1] = { name = cname, done = cdone }
                        pid = cid
                    end
                    if #ancestors > 0 then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(L["ACHIEVEMENT_SERIES"], 1, 0.82, 0)
                        local step = 0
                        for i = #ancestors, 1, -1 do
                            step = step + 1
                            local node = ancestors[i]
                            if node.done then
                                GameTooltip:AddLine(step .. ". " .. (node.name or ""), 0.25, 0.9, 0.25)
                            else
                                GameTooltip:AddLine(step .. ". " .. (node.name or ""), 1, 1, 1)
                            end
                        end
                        step = step + 1
                        if completed then
                            GameTooltip:AddLine(step .. ". " .. name, 0.25, 0.9, 0.25)
                        else
                            GameTooltip:AddLine(step .. ". " .. name, 1, 1, 1)
                        end
                    end
                end
                if rewardText and rewardText ~= "" then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(rewardText, 1, 0.82, 0, true)
                end
                GameTooltip:Show()
            end
            return
        end

        if self.data and self.data.settingType == "keybind" and self.data.bindingAction then
            local action = self.data.bindingAction
            AnchorRowTooltip(GameTooltip, self)
            GameTooltip:SetText(self.data.name or action, 1, 1, 1)
            local k1, k2 = GetBindingKey(action)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(sformat(L["KB_PRIMARY"], k1 or (_G["NOT_BOUND"] or "Not Bound")), 0.7, 0.7, 0.7)
            GameTooltip:AddLine(sformat(L["KB_ALTERNATE"], k2 or (_G["NOT_BOUND"] or "Not Bound")), 0.7, 0.7, 0.7)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["KB_CAPTURE_HINT"], 0.5, 0.5, 0.5, true)
            GameTooltip:Show()
            return
        end




        if self.data and self.data.settingPress and self.data.settingTooltip then
            AnchorRowTooltip(GameTooltip, self)
            GameTooltip:SetText(self.data.name, 1, 1, 1)
            GameTooltip:AddLine(self.data.settingTooltip, 1, 0.82, 0, true)
            GameTooltip:Show()
            return
        end
        if self.data and self.data.settingVariable then
            local var = self.data.settingVariable
            local tipText = self.data.settingTooltip
            if not tipText and ns.BlizzOptionsSearch and ns.BlizzOptionsSearch.GetTooltipForVariable then
                tipText = ns.BlizzOptionsSearch.GetTooltipForVariable(var, self.data.name)
            end
            AnchorRowTooltip(GameTooltip, self)
            GameTooltip:SetText(self.data.name or var, 1, 1, 1)
            if tipText then
                GameTooltip:AddLine(tipText, 1, 0.82, 0, true)
            end

            if self.data.settingType == "slider" and self.data.settingMin and self.data.settingMax then
                local n = tonumber(ns.ResultRows:ReadSettingVariable(var))
                if n then
                    GameTooltip:AddLine(" ")
                    if not self.data.settingFormatter
                       and ns.BlizzOptionsSearch and ns.BlizzOptionsSearch.GetFormatterForVariable then
                        local fmt = ns.BlizzOptionsSearch.GetFormatterForVariable(var)
                        if fmt then self.data.settingFormatter = fmt end
                    end
                    local valStr
                    if self.data.settingFormatter then
                        local fok, f = pcall(self.data.settingFormatter, n)
                        if fok and f ~= nil then
                            local ft = type(f)
                            if ft == "string" and f ~= "" then
                                valStr = f
                            elseif ft == "number" then
                                valStr = (f == mfloor(f)) and tostring(mfloor(f)) or sformat("%.2f", f)
                            end
                        end
                    end
                    if not valStr then
                        valStr = (n == mfloor(n)) and tostring(mfloor(n)) or sformat("%.2f", n)
                    end
                    GameTooltip:AddLine(sformat(L["SETTING_CURRENT_RANGE"],
                        valStr,
                        tostring(self.data.settingMin),
                        tostring(self.data.settingMax)), 0.7, 0.7, 0.7)
                end
            end
            GameTooltip:Show()
            return
        end

        if self.isUnearnedCurrency or self.lockedReason then
            if GetUnearnedTooltip() then
                local tooltipText = self.lockedReason
                    or (self.isPathNode and L["TAB_NOT_ON_CHARACTER"] or L["CURRENCY_NOT_EARNED"])
                local unearned = GetUnearnedTooltip()
                unearned.text:SetText(tooltipText)
                unearned:SetSize(unearned.text:GetStringWidth() + 20, unearned.text:GetStringHeight() + 16)


                Tooltips.ApplySearchTooltipScale(unearned)
                if not Tooltips:PlaceAtPanelEdge(unearned, self) then
                    local scale = UIParent:GetEffectiveScale()
                    local x, y = GetCursorPosition()
                    unearned:ClearAllPoints()
                    unearned:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + 10, y / scale + 10)
                end
                unearned:Show()
            end
        elseif self.data and self.data.mapSearchResult then

            if not again and ns.MapSearch and ns.MapSearch.PreviewUIResult then
                ns.MapSearch:PreviewUIResult(self.data)
            end
            AnchorRowTooltip(GameTooltip, self)
            Tooltips:SetMapRowTooltip(GameTooltip, self.data)
            GameTooltip:Show()
        elseif self.data and self.icon and self.icon:IsShown() then







            local ht = EasyFind.db.hideTooltips
            local ic = self.icon
            if ht and ht.collections and (ic.mountID or ic.toyItemID or ic.petID or ic.speciesID
                or ic.outfitID or ic.heirloomItemID or ic.transmogSetID or ic.appearanceItemID) then
                return
            end
            if ht and ht.loot then
                if ic.lootItemID then return end
                if ic.bagItemID and self.data and self.data.equipLoc then
                    local slot = self.data.equipLoc
                    if slot ~= "" and slot ~= "INVTYPE_NON_EQUIP"
                       and slot ~= "INVTYPE_AMMO" and slot ~= "INVTYPE_QUIVER" then
                        return
                    end
                end
            end

            if ht and ht.bags and self.data.category == "Bag" then return end

            if self.data.category == "Boss" then
                AnchorRowTooltip(GameTooltip, self)
                Tooltips:SetBossTooltip(GameTooltip, self.data)
                GameTooltip:Show()

            elseif self.icon.mountID and self.icon.spellID then
                AnchorRowTooltip(GameTooltip, self)
                GameTooltip:SetMountBySpellID(self.icon.spellID)
                GameTooltip:Show()
            elseif self.icon.toyItemID then
                local toyItemID = self.icon.toyItemID
                AnchorRowTooltip(GameTooltip, self)
                GameTooltip:SetToyByItemID(toyItemID)
                GameTooltip:Show()
                if self.toyTooltipTicker then self.toyTooltipTicker:Cancel() end
                self.toyTooltipTicker = C_Timer.NewTicker(1, function(ticker)
                    local ok = Utils.xpcall(function()
                        if GameTooltip:IsOwned(self) then
                            GameTooltip:SetToyByItemID(toyItemID)
                        end
                    end, Utils.ErrorHandler)
                    if not ok then
                        ticker:Cancel()
                        if self.toyTooltipTicker == ticker then
                            self.toyTooltipTicker = nil
                        end
                    end
                end)


            elseif self.icon.petID then
                local link = C_PetJournal and C_PetJournal.GetBattlePetLink
                    and C_PetJournal.GetBattlePetLink(self.icon.petID)
                if link and BattlePetToolTip_ShowLink and BattlePetTooltip and BattlePetTooltip.Owned then
                    AnchorRowTooltip(GameTooltip, self)
                    BattlePetToolTip_ShowLink(link)
                elseif GameTooltip.SetCompanionPet then
                    AnchorRowTooltip(GameTooltip, self)
                    GameTooltip:SetCompanionPet(self.icon.petID)
                    GameTooltip:Show()
                end
            elseif self.icon.outfitID then
                AnchorRowTooltip(GameTooltip, self)
                GameTooltip:SetText(self.data and self.data.name or _G["TRANSMOG_OUTFIT_NAME_DEFAULT"] or "Outfit")
                GameTooltip:AddLine(_G["SPELL_CAST_TIME_INSTANT"] or "Instant", 1, 1, 1)
                GameTooltip:AddLine(L["TMOG_DESC"], 0, 1, 0)
                local activeID = Rows.lastEquippedOutfitID
                    or (C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID
                        and C_TransmogOutfitInfo.GetActiveOutfitID())
                if activeID and activeID == self.icon.outfitID then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(_G["CURRENTLY_EQUIPPED"] or "Currently equipped", 0.3, 1, 0.3)
                else
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(L["TMOG_CLICK_EQUIP"], 1, 0.82, 0)
                end
                if C_TransmogOutfitInfo and C_TransmogOutfitInfo.IsLockedOutfit then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(L["TMOG_LOCK_LABEL"], 1, 1, 1)
                    GameTooltip:AddLine(L["TMOG_LOCK_DESC"], 1, 0.82, 0)
                    if C_TransmogOutfitInfo.IsLockedOutfit(self.icon.outfitID) then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(L["TMOG_LOCKED"], 0.3, 1, 0.3)
                    end
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(L["TMOG_LOCK_TOGGLE_HINT"], 0.5, 0.5, 0.5)
                end
                GameTooltip:Show()
            elseif self.icon.lootItemID then
                AnchorRowTooltip(GameTooltip, self)
                local itemLink = self.data and ns.Database and ns.Database:GetLootItemLink(self.data)
                if itemLink then
                    GameTooltip:SetHyperlink(itemLink)
                else
                    GameTooltip:SetItemByID(self.icon.lootItemID)
                end
                GameTooltip:Show()
            elseif self.icon.heirloomItemID then
                AnchorRowTooltip(GameTooltip, self)
                GameTooltip:SetItemByID(self.icon.heirloomItemID)
                GameTooltip:Show()
            elseif self.icon.appearanceItemID then
                AnchorRowTooltip(GameTooltip, self)
                local srcInfo = C_TransmogCollection and C_TransmogCollection.GetSourceInfo
                    and C_TransmogCollection.GetSourceInfo(self.icon.appearanceItemID)
                if srcInfo and srcInfo.itemID then
                    GameTooltip:SetItemByID(srcInfo.itemID)
                else
                    GameTooltip:SetText(self.data and self.data.name or "")
                end
                GameTooltip:Show()




            elseif self.icon.spellID then
                AnchorRowTooltip(GameTooltip, self)
                if not Tooltips:SetClassicTalent(GameTooltip, self.data) then
                    if GameTooltip.SetSpellByID then
                        GameTooltip:SetSpellByID(self.icon.spellID)
                    else
                        GameTooltip:SetHyperlink("spell:" .. self.icon.spellID)
                    end
                end
                GameTooltip:Show()




            elseif self.icon.bagItemID then
                local slot = self.data and self.data.equipLoc
                local isGear = slot and slot ~= "" and slot ~= "INVTYPE_NON_EQUIP"
                              and slot ~= "INVTYPE_AMMO" and slot ~= "INVTYPE_QUIVER"
                if isGear then
                    AnchorRowTooltip(GameTooltip, self)
                else
                    AnchorRowTooltip(GameTooltip, self)
                end
                local link = self.data and self.data.bagItemLink
                if link then
                    GameTooltip:SetHyperlink(link)
                else
                    GameTooltip:SetItemByID(self.icon.bagItemID)
                end
                GameTooltip:Show()
            end
        end
    end



    local function Decorate(self)
        if not self.data then return end
        local own = GameTooltip:IsShown() and GameTooltip:GetOwner() == self
        if not own then
            if not ns.Extensions.HasTooltipDecorator(self.data) then return end
            AnchorRowTooltip(GameTooltip, self)
            GameTooltip:SetText(self.data.name or "", 1, 1, 1)
        end
        local any, byKeys = ns.Extensions.DecorateTooltip(self.data, GameTooltip)
        if any then
            GameTooltip:Show()
            if byKeys then WatchHeldKeys(self) end
        elseif not own then
            GameTooltip:Hide()
        end
    end




    resultRow:SetScript("OnEnter", function(self)


        local held = Results._contextHeldRow
        if held and held ~= self and held._efContextMenuHeld then return end





        local prevHover = Results._hoverRow
        if prevHover and prevHover ~= self then
            prevHover._efHlHover = nil
            Results:UpdateRowWash(prevHover)
        end
        Results._hoverRow = self
        self._efHlHover = true
        Results:UpdateRowWash(self)
        if ns.RowCopy then ns.RowCopy:OnRowHover(self) end





        if Results.IsResultsScrollBusy and Results:IsResultsScrollBusy() then return end

        Handlers:ApplyActionHint(self)
        ShowTooltip(self)
    end)
    resultRow:HookScript("OnEnter", Decorate)

    resultRow._efRedrawTooltip = function(self)
        GameTooltip:Hide()
        ShowTooltip(self, true)
        Decorate(self)
    end

    resultRow:SetScript("OnLeave", function(self)
        self._efHlHover = nil
        if Results._hoverRow == self then
            Results._hoverRow = nil
            if ns.RowCopy then ns.RowCopy:OnRowHover(nil) end
        end
        Results:UpdateRowWash(self)
        if GetUnearnedTooltip() then
            GetUnearnedTooltip():Hide()
        end
        if self.toyTooltipTicker then
            self.toyTooltipTicker:Cancel()
            self.toyTooltipTicker = nil
        end
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
        local provider = self.data and ns.Extensions and ns.Extensions.ProviderOf(self.data)
        if provider and provider.leave then
            if ns.HideHintTooltip then ns.HideHintTooltip(self) end
            ns.Extensions.Run(provider.leave, self.data)
        end


        if self.data and self.data.petID and BattlePetTooltip then
            BattlePetTooltip:Hide()
        end
        if self.data and self.data.mapSearchResult and ns.MapSearch and ns.MapSearch.ClearUIPreview then
            ns.MapSearch:ClearUIPreview()
        end
        if Handlers:IsActionHintRow(self) then
            Handlers:ClearActionHint()
            local selRow = Search:GetSelectedIndex() > 0 and ns.Results:RowFrame(Search:GetSelectedIndex()) or nil
            if selRow and selRow ~= self and not Search:GetToggleFocused() then
                Handlers:ApplyActionHint(selRow)
            end
        end
    end)
end
