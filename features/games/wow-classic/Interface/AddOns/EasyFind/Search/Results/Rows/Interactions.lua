local _, ns = ...

local Search = ns.Search
local Results = ns.Results
local Rows = ns.ResultRows
local Render = ns.ResultRender
local Icons = ns.ResultIcons
local Handlers = ns.ResultHandlers
local Utils = ns.Utils

local GetCursorPosition = GetCursorPosition
local InCombatLockdown = InCombatLockdown
local IsShiftKeyDown = IsShiftKeyDown






local hoveredChatLink, hoveredChatText, hoveredChatFrame
local chatTrackingInstalled = false
local function EnsureChatHyperlinkTracking()
    if chatTrackingInstalled then return end
    chatTrackingInstalled = true
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame and chatFrame.HookScript then
            chatFrame:HookScript("OnHyperlinkEnter", function(self, link, text)
                hoveredChatLink, hoveredChatText, hoveredChatFrame = link, text, self
            end)
            chatFrame:HookScript("OnHyperlinkLeave", function()
                hoveredChatLink, hoveredChatText, hoveredChatFrame = nil, nil, nil
            end)
        end
    end
end







local function InsertLinkIntoChatEditBox(targetBox, link)
    if targetBox and targetBox.IsShown and targetBox:IsShown() then
        targetBox:Insert(link)
        return
    end
    local active = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if active and active:IsShown() then
        active:Insert(link)
        return
    end
    if ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
end















local function RouteLinkToHoveredChat(link, hoverLink, hoverText, hoverFrame)
    hoverLink = hoverLink or hoveredChatLink
    hoverText = hoverText or hoveredChatText
    hoverFrame = hoverFrame or hoveredChatFrame
    if not (link and link ~= "" and hoverLink and hoverFrame) then return false end
    local isChannel = hoverLink:match("^channel:") ~= nil
    local whisperTarget = hoverLink:match("^player:([^:]+)")




    local isBNPlayer = hoverLink:match("^BNplayer:") ~= nil
    if not (isChannel or whisperTarget or isBNPlayer) then return false end
    local frame, chatLink, chatText = hoverFrame, hoverLink, hoverText
    return pcall(function()
        local targetBox
        if isChannel or isBNPlayer then





            local onHyperlinkClick = frame:GetScript("OnHyperlinkClick")
            if onHyperlinkClick then
                onHyperlinkClick(frame, chatLink, chatText, "LeftButton")
            end
            if isChannel then targetBox = frame.editBox end
        else
            local editBox = (ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend())
                or (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow())
                or _G["ChatFrame1EditBox"]
            if editBox then
                Utils.SafeCallMethod(editBox, "SetAttribute", "chatType", "WHISPER")
                Utils.SafeCallMethod(editBox, "SetAttribute", "tellTarget", whisperTarget)
                if ChatEdit_UpdateHeader then ChatEdit_UpdateHeader(editBox) end
                if ChatEdit_ActivateChat then ChatEdit_ActivateChat(editBox) end
            end
            targetBox = editBox
        end



        Utils.SafeAfter(0, function()
            InsertLinkIntoChatEditBox(targetBox, link)
        end)
    end)
end










local carriedItemLink







local carriedLinkCursorBacked = false
local ArmDropWatcher







function ns.HasCarriedItemLink()
    return carriedItemLink ~= nil
end

function ns.ClearCarriedItemLink()
    if not carriedItemLink then return false end
    carriedItemLink = nil
    carriedLinkCursorBacked = false
    if ClearCursor then ClearCursor() end
    if Utils.RefreshEscArm then Utils.RefreshEscArm() end
    return true
end




local function DropLinkToSay(link)
    if not link or link == "" then return false end
    return pcall(function()
        local chatFrame = DEFAULT_CHAT_FRAME or _G["ChatFrame1"]
        if ChatFrame_OpenChat then ChatFrame_OpenChat("", chatFrame) end
        local editBox = (chatFrame and chatFrame.editBox)
            or (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow())
            or _G["ChatFrame1EditBox"]
        if not editBox then return end
        Utils.SafeCallMethod(editBox, "SetAttribute", "chatType", "SAY")
        if ChatEdit_UpdateHeader then ChatEdit_UpdateHeader(editBox) end




        Utils.SafeAfter(0, function()
            InsertLinkIntoChatEditBox(editBox, link)
        end)
    end)
end


local function ClickedFreeSpace()
    local foci = Utils.MouseFoci()
    if #foci == 0 then return true end
    for i = 1, #foci do
        if foci[i] ~= WorldFrame then return false end
    end
    return true
end





local function CursorInsideFrame(frame)
    if not (frame and frame.IsVisible and frame:IsVisible() and frame.GetLeft) then
        return false
    end
    local left, right = frame:GetLeft(), frame:GetRight()
    local bottom, top = frame:GetBottom(), frame:GetTop()
    if not (left and right and bottom and top) then return false end
    local scale = frame:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return x >= left * scale and x <= right * scale
       and y >= bottom * scale and y <= top * scale
end




local function ClickedChatBox()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local chatFrame = _G["ChatFrame" .. i]
        if CursorInsideFrame(chatFrame) then return true end
        if chatFrame and CursorInsideFrame(chatFrame.editBox) then return true end
    end
    return false
end




local worldDropInstalled = false
local function EnsureItemDropRouting()
    if worldDropInstalled then return end
    worldDropInstalled = true






    local pendingDrop
    local watcher = CreateFrame("Frame")
    ArmDropWatcher = function()
        watcher:RegisterEvent("GLOBAL_MOUSE_DOWN")
        watcher:RegisterEvent("GLOBAL_MOUSE_UP")
        watcher:RegisterEvent("CURSOR_CHANGED")
    end
    watcher:SetScript("OnEvent", function(_, event, button)

        if not carriedItemLink and not pendingDrop then
            watcher:UnregisterAllEvents()
            return
        end
        if event == "CURSOR_CHANGED" then
            if carriedLinkCursorBacked and carriedItemLink
               and not (GetCursorInfo and GetCursorInfo()) then
                carriedItemLink = nil
                carriedLinkCursorBacked = false
                if Utils.RefreshEscArm then Utils.RefreshEscArm() end
            end
            return
        end
        if button ~= "LeftButton" or InCombatLockdown() then return end

        if event == "GLOBAL_MOUSE_UP" then
            local drop = pendingDrop
            pendingDrop = nil
            if not drop then return end




            local routed = RouteLinkToHoveredChat(drop.link, drop.hoveredLink,
                drop.hoveredText, drop.hoveredFrame)


            if not routed and drop.chatBox then
                DropLinkToSay(drop.link)
            end
            if Utils.RefreshEscArm then Utils.RefreshEscArm() end
            return
        end

        if not carriedItemLink then return end





        if carriedLinkCursorBacked and not (GetCursorInfo and GetCursorInfo()) then
            carriedItemLink = nil
            carriedLinkCursorBacked = false
            return
        end
        local overChat = hoveredChatLink and hoveredChatFrame
        local chatBox = not overChat and ClickedChatBox()



        if not overChat and not chatBox and ClickedFreeSpace() then




            carriedItemLink = nil
            carriedLinkCursorBacked = false
            ClearCursor()
            if Utils.RefreshEscArm then Utils.RefreshEscArm() end
            return
        end


        if not (overChat or chatBox) then return end
        pendingDrop = {
            link = carriedItemLink,
            hoveredLink = hoveredChatLink,
            hoveredText = hoveredChatText,
            hoveredFrame = hoveredChatFrame,
            chatBox = chatBox,
        }
        carriedItemLink = nil
        carriedLinkCursorBacked = false
        ClearCursor()
        if Utils.RefreshEscArm then Utils.RefreshEscArm() end
    end)
end

local function CollapsedNodes()
    return Results._collapsedNodes
end




function Rows.CanPickUp(d)
    if not d then return false end
    if d.mountID then return Icons:IsMountSummonable(d) end
    if d.toyItemID then return not d.isToyboxOnly end
    if d.petID then return true end
    if d.outfitID or d.macroIndex then return true end
    if d.spellID then
        if d.category == "Profession" then return not d.classicRecipe end
        return d.category == "Ability" and not Icons:IsSpellbookOnlyAbility(d)
    end
    return (d.bagID and d.bagSlot) or d.itemID
end

function Rows.InstallInteractions(resultRow, index)
    EnsureChatHyperlinkTracking()
    EnsureItemDropRouting()









    resultRow:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonUp")













    local function PickupSpellCompat(spellID)
        if C_Spell and C_Spell.PickupSpell then
            C_Spell.PickupSpell(spellID)
        elseif PickupSpell then
            PickupSpell(spellID)
        end
    end

    local pickupItem = (C_Item and C_Item.PickupItem) or PickupItem
    local function PickupItemCompat(itemID)
        if pickupItem then pickupItem(itemID) end
    end
    local CanPickupRowAction = Rows.CanPickUp




    local function PickupRowAction(d)
        if not CanPickupRowAction(d) then return end
        if InCombatLockdown() then return end
        ClearCursor()
        if d.mountID and C_MountJournal and C_MountJournal.GetMountInfoByID then
            local _, spellID = C_MountJournal.GetMountInfoByID(d.mountID)
            if spellID then PickupSpellCompat(spellID) end
        elseif d.petID and C_PetJournal and C_PetJournal.PickupPet then
            C_PetJournal.PickupPet(d.petID)
        elseif d.toyItemID and C_ToyBox and C_ToyBox.PickupToyBoxItem then
            C_ToyBox.PickupToyBoxItem(d.toyItemID)
        elseif d.outfitID and C_TransmogOutfitInfo and C_TransmogOutfitInfo.PickupOutfit then
            C_TransmogOutfitInfo.PickupOutfit(d.outfitID)
        elseif d.macroIndex and PickupMacro then
            PickupMacro(d.macroIndex)
        elseif d.spellID then
            PickupSpellCompat(d.spellID)
        elseif d.bagID and d.bagSlot then
            local pickup = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
            if pickup then
                pickup(d.bagID, d.bagSlot)
            elseif d.itemID then
                PickupItemCompat(d.itemID)
            end
        elseif d.itemID then
            PickupItemCompat(d.itemID)
        end



        carriedItemLink = nil
        carriedLinkCursorBacked = false
        local onCursor = GetCursorInfo and GetCursorInfo() ~= nil




        if ns.GetResultLink and (onCursor or Handlers:IsLookupRow(d)) then
            carriedItemLink = ns.GetResultLink(d)
            carriedLinkCursorBacked = onCursor and carriedItemLink ~= nil
            if carriedItemLink and ArmDropWatcher then ArmDropWatcher() end
        end


        if Utils.RefreshEscArm then Utils.RefreshEscArm() end
    end
    local function SetSecureOutfit(row, outfitIndex)
        if row._lastAttrKey and row._lastAttrKey ~= "outfit-index" then
            Utils.SafeCallMethod(row, "SetAttribute", row._lastAttrKey, nil)
        end
        Utils.SafeCallMethod(row, "SetAttribute", "type", "outfit")
        Utils.SafeCallMethod(row, "SetAttribute", "outfit-index", outfitIndex)
        Utils.SafeCallMethod(row, "SetAttribute", "action", nil)
        row._lastAttrType = "outfit"
        row._lastAttrKey = "outfit-index"
        row._lastAttrVal = outfitIndex
    end
    local DRAG_PX = 5



    resultRow:HookScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self._pickedUp = nil
        local d = self.data




        if Handlers:IsLookupRow(d) then



            if not ns.ResultGestures.Does(d, "sendLink") then
                return
            end
            local x, y = GetCursorPosition()
            self._dragOriginX, self._dragOriginY = x, y
            return
        end



        if not IsShiftKeyDown() or ns.ResultGestures.ShiftChosen(d) then return end
        if not CanPickupRowAction(d) then return end
        local x, y = GetCursorPosition()
        self._dragOriginX, self._dragOriginY = x, y
    end)
    resultRow:HookScript("OnUpdate", function(self)
        if not self._dragOriginX then return end
        local x, y = GetCursorPosition()
        local dx, dy = x - self._dragOriginX, y - self._dragOriginY
        if dx * dx + dy * dy < DRAG_PX * DRAG_PX then return end
        self._dragOriginX, self._dragOriginY = nil, nil
        self._pickedUp = true
        if self.data then PickupRowAction(self.data) end
    end)
    resultRow:HookScript("OnMouseUp", function(self, button)
        if not InCombatLockdown() and ns.ResultSecureAttributes then
            ns.ResultSecureAttributes.ArmSteerLate(self)
        end
        self._dragOriginX, self._dragOriginY = nil, nil
        if self._rowActionPress then
            self._rowActionPress = nil
            return
        end


        if self._selectPress then
            self._selectPress = nil
            if not self._pickedUp then return end
        end






        local clicked = self.data
        if button == "LeftButton" and Handlers:IsLookupRow(clicked)
           and not self._pickedUp
           and not InCombatLockdown()
           and ns.ResultGestures.Does(clicked, "sendLink") then
            PickupRowAction(clicked)





            Handlers:FinishResultSelection()
            return
        end

        if not self._pickedUp then return end
        if InCombatLockdown() then return end


        local draggedLink = ns.GetResultLink and ns.GetResultLink(self.data)




        Handlers:FinishResultSelection()

        if RouteLinkToHoveredChat(draggedLink) then
            ClearCursor()
            return
        end
        local cursorType = GetCursorInfo and GetCursorInfo()
        if cursorType then
            local foci = Utils.MouseFoci()
            for i = 1, #foci do
                local f = foci[i]
                local slot = f.action or (f.GetAttribute and f:GetAttribute("action"))
                if slot then
                    if PlaceAction then PlaceAction(slot) end
                    ClearCursor()
                    return
                end
            end
        end
    end)
    resultRow:SetScript("PreClick", function(self, mouseButton, down)
        if mouseButton ~= "LeftButton" then return end


        if not down then return end
        self._outfitSecureClicked = nil
        if InCombatLockdown() then return end

        local d = self.data



        ns.ResultSecureAttributes.ApplyAtClick(self, d)



        local rowAction = d and ns.ResultRowActions and ns.ResultRowActions.ActionForClick()
        if rowAction then
            ns.ResultSecureAttributes.Clear(self)
            self._rowActionClick, self._rowActionPress = rowAction, true
            return
        end





        if d and ns.TryInsertResultChatLink and ns.TryInsertResultChatLink(d) then
            ns.ResultSecureAttributes.Clear(self)
            self._dragOriginX, self._dragOriginY = nil, nil
            self._chatLinkInserted = true
            return
        end









        if d and IsShiftKeyDown() and CanPickupRowAction(d) and not ns.ResultGestures.ShiftChosen(d)
           and not Handlers:IsLookupRow(d) then
            ns.ResultSecureAttributes.Clear(self)
            self._pickedUp = true
            return
        end


        if d and ns.ResultGestures.Blocked(d) then
            ns.ResultSecureAttributes.Clear(self)
            self._gestureBlocked = true
            return
        end





        if d and EasyFind.db.clickSelectsRow and IsMouseButtonDown("LeftButton")
           and ns.ResultGestures.Held() == "click" and not d.pageAction
           and not (self.isPathNode or self.isPinHeader or self.isSectionHeader) then
            local now = GetTime()
            if self._selectClickAt and now - self._selectClickAt < 0.4 and self._selectClickData == d then
                self._selectClickAt = nil
            else
                self._selectClickAt, self._selectClickData = now, d
                ns.ResultSecureAttributes.Clear(self)
                self._clickSelected, self._selectPress = true, true
                Search:SetSelectedIndex(self.rowIndex or 0)
                Search:SetToggleFocused(false)
                Results:UpdateSelectionHighlight()
                return
            end
        end



        local sourceModifierHeld = Handlers:IsSourceModifierHeld(d)
        local ctrlHeld = Handlers:IsSourceCtrlHeld(d)
        local bagItemKind = (d and d.itemID and d.category == "Bag")
            and Handlers:GetBagItemActionKind(d)








        if sourceModifierHeld and d and d.spellID and d.category == "Ability" then
            if not Icons:IsSpellbookOnlyAbility(d) then
                ns.ResultSecureAttributes.SwapToPanelOpen(self)
            end
            return
        end

        local suppressSecureClick = d and (
            (sourceModifierHeld and (d.macroIndex or d.mountID or d.toyItemID
                or d.outfitID or (d.itemID and d.category == "Bag")
                or (d.settingVariable and Rows.IsBarToggle(d.settingVariable))))
            or (d.mountID and (ctrlHeld or not Icons:IsMountSummonable(d)))
            or (ctrlHeld and bagItemKind == "equip")
        )
        if suppressSecureClick then
            ns.ResultSecureAttributes.Clear(self)
            return
        end

        local barState = ns.ResultSecureAttributes.FlipBarAtPress(d)
        if barState ~= nil then
            self._barFlipped, self._barState = true, barState
            return
        end

        if not (d and d.outfitID) then return end
        if Rows:IsOutfitCooldownActive() then
            ns.ResultSecureAttributes.Clear(self)
            return
        end

        local outfitIndex = Handlers:GetOutfitSecureIndex(d)
        if not outfitIndex then
            ns.ResultSecureAttributes.Clear(self)
            return
        end
        SetSecureOutfit(self, outfitIndex)
        self._outfitSecureClicked = d.outfitID
    end)
    resultRow:SetScript("PostClick", function(self, mouseButton, down)





        if mouseButton == "LeftButton" then
            if ns.ResultSecureAttributes.ActsOnRelease(self, self.data) then
                if down then return end
            elseif not down then
                return
            end
        end

        if self._rowActionClick then
            local id = self._rowActionClick
            self._rowActionClick = nil
            ns.ResultRowActions.Run(id, self)
            return
        end


        if self._chatLinkInserted then
            self._chatLinkInserted = nil
            return
        end


        if self._pickedUp then
            self._pickedUp = nil
            return
        end
        if self._gestureBlocked then
            self._gestureBlocked = nil
            return
        end
        if self._clickSelected then
            self._clickSelected = nil
            return
        end









        if self.data and mouseButton == "LeftButton" and self.data.outfitID
           and not Handlers:IsSourceModifierHeld(self.data)
           and Rows.outfitCdStart > 0
           and Rows.outfitCdDuration - (GetTime() - Rows.outfitCdStart) > 0 then
            if Search:GetSearchFrame() and Search:GetSearchFrame().editBox and not Search:GetNavFrame():IsKeyboardEnabled() then
                Search:GetSearchFrame().editBox.blockFocus = nil
                Search:GetSearchFrame().editBox:SetFocus()
            end
            return
        end

        if self._outfitSecureClicked then
            Rows.lastEquippedOutfitID = self._outfitSecureClicked
            Rows.outfitCdStart = GetTime()
            Rows.outfitCdDuration = 4
            self._outfitSecureClicked = nil
        end

        if mouseButton == "RightButton" and self.data then
            Rows:ShowResultContextMenu(self, false)
            return
        end


        if self.isUnearnedCurrency or self.lockedReason then
            return
        end







        if self._barFlipped then
            self._barFlipped = nil
            Results:ShowBarToggle(self.data.settingVariable, self._barState)
            return
        end
        if Rows:ActivateSettingResult(self.data, Handlers:IsSourceModifierHeld(self.data)) then return end

        if self.isPinHeader then
            return
        end


        if self.isSectionHeader then
            local entry = Results:RowEntry(self.rowIndex or 0)
            if entry and entry.toggle then entry.toggle(entry) end
            return
        end

        if self.isPathNode then

            local isRetailHeader = self.headerTab and self.headerTab:IsShown()
            if isRetailHeader then
                if self.data then
                    Handlers:SelectResult(self.data)
                end
            else
                local cursorX = GetCursorPosition()
                local scale = self:GetEffectiveScale()
                local btnLeft = self:GetLeft() * scale
                local depth = self.pathNodeDepth or 0
                local iconLeft = btnLeft + depth * 20 * scale
                local isToggleClick = cursorX <= (iconLeft + 35 * scale)

                if isToggleClick then
                    local key = (self.pathNodeName or "") .. "_" .. (self.pathNodeDepth or 0)
                    CollapsedNodes()[key] = not CollapsedNodes()[key]
                    if Results._cachedHierarchical then
                        Render:ShowHierarchicalResults(Results._cachedHierarchical, true)
                    end
                elseif self.data then
                    Handlers:SelectResult(self.data)
                end
            end
        elseif self.data then
            Handlers:SelectResult(self.data)
        end
    end)
end
