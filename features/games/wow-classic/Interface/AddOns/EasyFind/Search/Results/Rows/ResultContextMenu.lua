local _, ns = ...

local Search = ns.Search
local Results = ns.Results
local Rows = ns.ResultRows
local Handlers = ns.ResultHandlers
local Utils = ns.Utils
local UIPins = ns.UIPins

local IsUIItemPinned = UIPins.IsPinned
local PinUIItem = UIPins.Pin
local UnpinUIItem = UIPins.Unpin
local MENU_CHECK = "Interface\\Buttons\\UI-CheckBox-Check"




function Rows:ResultMenuModel(row)
    if not row or not row.data then return nil end
    if row.data.calculatorResult or row.data.quickFilterDef or row.data.noMenu then return nil end

    local pinData = row.data
    local isPinned = IsUIItemPinned(pinData)
    local hasGuide = pinData.steps or pinData.transmogSetID
        or (pinData.category == "Loot" and pinData.itemID)
        or pinData.petID or pinData.speciesID
        or (pinData.mapSearchResult and ns.MapSearch.GuideAllowed(pinData))
    local onGuide = hasGuide and function()
        Handlers:SelectResult(pinData, true)
    end or nil
    local canAlias = ns.Aliases and ns.Aliases:GetEntryKey(pinData) ~= nil
    local onAddAlias = canAlias and function()
        Handlers:PromptForAlias(pinData)
    end or nil
    local extra
    if pinData.achievementID and pinData.category == "Achievement" then
        local achID = pinData.achievementID
        local isTracked = Handlers:IsAchievementTracked(achID)
        extra = {
            isTracked = isTracked,
            onTrack = function()
                Results:KeepPinnedResultsOpenBriefly()
                Handlers:ToggleAchievementTracked(achID)
            end,
        }
    elseif pinData.category == "Currency" and pinData.currencyID then
        local cid = pinData.currencyID
        extra = {
            isOnBackpack = Handlers:IsCurrencyOnBackpack(cid),
            onToggleBackpack = function()
                Results:KeepPinnedResultsOpenBriefly()
                Handlers:ToggleCurrencyBackpack(cid)
            end,
        }
        if Handlers:IsCurrencyTransferable(cid) then
            extra.onTransfer = function()
                Results:KeepPinnedResultsOpenBriefly()
                Handlers:RouteCurrencyTransfer(pinData)
            end
        end
    elseif pinData.category == "Reputation" and pinData.factionID then
        local fid = pinData.factionID
        extra = {
            isWatchedFaction = Handlers:IsReputationWatched(fid),
            onToggleWatchedFaction = function()
                Results:KeepPinnedResultsOpenBriefly()
                Handlers:ToggleReputationWatched(fid)
            end,
        }
    elseif pinData.transmogSetID then
        local sid = pinData.transmogSetID
        extra = {
            isFavorite = Handlers:IsTransmogSetFavorite(sid),
            onToggleFavorite = function()
                Results:KeepPinnedResultsOpenBriefly()
                Handlers:ToggleTransmogSetFavorite(sid)
            end,
        }
    elseif pinData.petID then
        local pid = pinData.petID
        local cageable = Handlers:IsPetCageable(pid)
        extra = {
            onSummon = function()
                Results:KeepPinnedResultsOpenBriefly()
                Handlers:SummonPet(pid)
            end,
            onRename = function()
                Results:KeepPinnedResultsOpenBriefly()
                Handlers:RenamePet(pid)
            end,
            isFavorite = Handlers:IsPetFavorite(pid),
            onToggleFavorite = function()
                Results:KeepPinnedResultsOpenBriefly()
                Handlers:TogglePetFavorite(pid)
            end,
            onCageOrRelease = function()
                Results:KeepPinnedResultsOpenBriefly()
                if cageable then Handlers:CagePet(pid) else Handlers:ReleasePet(pid) end
            end,
            isCageable = cageable,
        }
    end

    extra = extra or {}
    extra.disabled = (row.isUnearnedCurrency or row.lockedReason) and true or nil
    if pinData.category == "Bag" and pinData.bagID ~= nil and pinData.bagSlot then
        extra.onDestroyItem = function()
            Handlers:DestroyBagItem(pinData)
        end
    end
    if pinData.clipID and ns.Clipboard then
        local clipID = pinData.clipID
        extra.onClipDelete = function() ns.Clipboard:Delete(clipID) end
        extra.onClipClear = function() ns.Clipboard:ClearWithConfirm() end
        local entry = ns.ClipboardStore and ns.ClipboardStore:Get(clipID)
        extra.clipPinned = entry and entry.pinned and true or false
        extra.onClipPin = function() ns.Clipboard:TogglePin(clipID) end
        if EasyFind.API.HasAction("snippets", "create") then
            extra.onClipSaveSnippet = function() ns.Clipboard:SaveAsSnippet(clipID) end
        end

        if entry and ns.BuildAddNoteRows then
            local addNoteRows = ns.BuildAddNoteRows(entry.link or entry.text, ns.ClipboardStore.FirstLine(entry.text))
            if addNoteRows then extra.addNoteRows = addNoteRows end
        end
    end
    if pinData.snippetIndex and ns.Snippets then
        local snippetIndex = pinData.snippetIndex
        extra.onSnippetEdit = function()
            ns.Snippets:OpenEditor(snippetIndex)
        end
        extra.onSnippetDelete = function()
            ns.Snippets:DeleteWithConfirm(snippetIndex)
        end


        local notesState = C_AddOns and C_AddOns.GetAddOnEnableState
            and C_AddOns.GetAddOnEnableState("EasyFind_Notes")
        if notesState and notesState > 0 then
            extra.onSnippetInsertNote = function()
                ns.Snippets:InsertIntoNote(pinData.name)
            end
        end
    end

    if EasyFind.API.CallAction("gps", "canNavigate", pinData) then



        extra.onGPS = function()
            if EasyFind.API.CallAction("gps", "navigate", pinData, { popout = true }) and Handlers.FinishResultSelection then
                Handlers:FinishResultSelection()
            end
        end
        extra.onGPSFrom = function() EasyFind.API.CallAction("gps", "setStart", pinData) end
    end

    if ns.ItemSources and ns.ItemSources.Available(pinData) then
        extra.onSources = function() ns.ItemSources:Show(pinData) end
    end



    local provider = ns.Extensions and ns.Extensions.ProviderOf and ns.Extensions.ProviderOf(pinData)
    local function MenuRowsOf(defs, depth)
        local out = {}
        if type(defs) == "function" then
            local ok, list = ns.Extensions.Run(defs)
            defs = ok and list or nil
        end
        for _, d in ipairs(type(defs) == "table" and defs or {}) do
            if d.kind == "separator" then
                out[#out + 1] = { isSeparator = true }
            elseif d.kind == "check" and d.label then
                local _, on = ns.Extensions.Run(d.get)
                on = on == true
                out[#out + 1] = { text = d.label, tooltip = d.tooltip, icon = on and MENU_CHECK or nil, picked = on,
                    onClick = function() ns.Extensions.Run(d.set, not on) end }
            elseif d.kind == "action" and d.label then



                out[#out + 1] = { text = d.label, tooltip = d.tooltip, disabled = d.disabled == true or nil,
                    onClick = function()
                        ns.Extensions.Run(d.onClick)
                        if d.closes and Handlers.FinishResultSelection then Handlers:FinishResultSelection() end
                    end }
            elseif d.kind == "menu" and d.label and depth < 3 then
                local sub = MenuRowsOf(d.rows, depth + 1)
                if #sub > 0 then out[#out + 1] = { text = d.label, tooltip = d.tooltip, submenu = sub } end
            end
        end
        return out
    end
    if provider and provider.menu then
        local ok, defs = ns.Extensions.Run(provider.menu, pinData)
        local menuRows = MenuRowsOf(ok and defs or nil, 1)
        if #menuRows > 0 then
            local owner = ns.Extensions.Get and ns.Extensions.Get(provider.extension)
            extra.extensionMenu = { label = owner and owner.name or provider.label, icon = provider.icon,
                                    iconCoords = provider.iconCoords, rows = menuRows }
        end
    end


    if ns.Extensions and ns.Extensions.DecoratorMenuRows then
        extra.decoratorRows = ns.Extensions.DecoratorMenuRows(pinData, function(defs) return MenuRowsOf(defs, 1) end)
    end

    for _, target in ipairs(ns.Extensions and ns.Extensions.AddTargets or {}) do
        local owner = ns.Extensions.Get(target.extension)
        local takes = true
        if target.applies then
            local ok, yes = ns.Extensions.Run(target.applies, pinData)
            takes = ok and yes == true
        end
        if owner and takes then
            local ok, defs = ns.Extensions.Run(target.rows, pinData)
            local sub = MenuRowsOf(ok and defs or nil, 1)
            if #sub > 0 then
                extra.addTargets = extra.addTargets or {}
                extra.addTargets[#extra.addTargets + 1] = {
                    actionId = "add:" .. target.key, text = target.label, fullText = target.fullLabel or target.label,
                    icon = owner.icon, iconCoords = owner.iconCoords, chromeIcon = true, submenu = sub,
                    onClick = target.onClick and function() ns.Extensions.Run(target.onClick, pinData) end,
                }
            end
        end
    end
    extra.wowheadUrl = ns.GetWowheadLink and ns.GetWowheadLink(pinData)
    if ns.ResultLinks then
        extra.easyFindLinkRows, extra.easyFindLinkText = ns.ResultLinks:BuildSendRows(pinData)

        extra.easyFindLinkTooltip = pinData.noteID and ns.L["EFLINK_NOTE_TT"] or nil
    end
    local chatLink = ns.GetResultLink and ns.GetResultLink(pinData)
    if chatLink then
        extra.sendLink = { link = chatLink }
        local addNoteRows = ns.BuildAddNoteRows and ns.BuildAddNoteRows(chatLink, pinData.name)
        if addNoteRows then extra.addNoteRows = addNoteRows end
    end
    local skKey = ns.Shortkeys and ns.Shortkeys:GetEntryKey(pinData)
    if skKey then
        extra.hasShortkey = ns.Shortkeys:Get(skKey) ~= nil
        extra.onAddShortkey = function() ns.Shortkeys:PromptForKey(pinData) end



        if not pinData.lookupRow then
            extra.onCreateMacro = function()
                if ns.Shortkeys:CreateMacro(skKey, pinData.name, pinData) and Handlers.FinishResultSelection then
                    Handlers:FinishResultSelection()
                end
            end
        end
    end
    if ns.Quicklists and not pinData.quicklistID then
        extra.addQuicklistRows = ns.Quicklists:BuildAddRows(pinData)
    end


    if canAlias and ns.Blacklist then
        extra.onBlacklist = function()
            if not ns.Blacklist:Add(pinData) then return end
            if ns.RefreshBindTables then ns.RefreshBindTables() end
            local editBox = Search:GetSearchFrame() and Search:GetSearchFrame().editBox
            local text = editBox and editBox:GetText() or ""
            if text == "" then
                Results:KeepPinnedResultsOpenBriefly()
                Results:ShowEmptyQueryView()
            else
                Search:OnSearchTextChanged(text, true)
            end
        end
    end





    local pickData = pinData.learnedFrom or pinData
    if ns.Learned and ns.Learned.FindPick and ns.Learned:FindPick(pickData, Search:GetTypedQuery()) then
        extra.onForgetPick = function()
            if not ns.Learned:Forget(pickData, Search:GetTypedQuery()) then return end
            local editBox = Search:GetSearchFrame() and Search:GetSearchFrame().editBox
            local text = editBox and editBox:GetText() or ""
            if text ~= "" then Search:OnSearchTextChanged(text, true) end
        end
    end
    local function onPin()
        if isPinned then
            UnpinUIItem(pinData)
        else
            PinUIItem(pinData)
        end
        local editBox = Search:GetSearchFrame() and Search:GetSearchFrame().editBox
        local text = editBox and editBox:GetText() or ""
        if text == "" then
            local pinsRemain = Results:KeepPinnedResultsOpenBriefly()
            Results:ShowEmptyQueryView()
            if pinsRemain and editBox
               and not (Search:GetNavFrame() and Search:GetNavFrame():IsKeyboardEnabled()) then
                editBox.blockFocus = nil
                editBox:SetFocus()
            end
        else
            Search:OnSearchTextChanged(text, true)
        end
    end
    return isPinned, onPin, onGuide, onAddAlias, extra
end

function Rows:ShowResultContextMenu(row, keyboardMode)
    local isPinned, onPin, onGuide, onAddAlias, extra = self:ResultMenuModel(row)
    if not extra then return false end

    local function FocusKeyboardMenu(menu)
        if not keyboardMode or not menu or not menu:IsShown() then return end
        local navFrame = Search:GetNavFrame()
        if navFrame then Utils.SafeCallMethod(navFrame, "EnableKeyboard", false) end
        if menu.FocusKeyboard then
            menu:FocusKeyboard(1)
        else
            Utils.SafeCallMethod(menu, "EnableKeyboard", true)
            Utils.SafeCallMethod(menu, "SetPropagateKeyboardInput", false)
            if menu.SetKeyboardIndex then menu.SetKeyboardIndex(menu, 1) end
        end
    end
    local kbOnHide
    if keyboardMode then
        extra.keyboardMode = true
        kbOnHide = function()
            local navFrame = Search:GetNavFrame()
            if navFrame and Search:GetSelectedIndex() > 0
               and Search:GetSearchFrame() and Search:GetSearchFrame():IsShown() then
                Utils.SafeCallMethod(navFrame, "EnableKeyboard", true)
            end
        end
        local navFrame = Search:GetNavFrame()
        if navFrame then Utils.SafeCallMethod(navFrame, "EnableKeyboard", false) end
    end




    extra.onHide = function()
        row._efContextMenuHeld = nil
        if Results._contextHeldRow == row then Results._contextHeldRow = nil end
        Results:SetRowHighlightLocked(row, false)
        Results:UpdateSelectionHighlight(true)


        for _, under in ipairs(Search:GetResultButtons()) do
            if under:IsVisible() and under:IsMouseOver() then
                local enter = under:GetScript("OnEnter")
                if enter then enter(under) end
                break
            end
        end
        if kbOnHide then kbOnHide() end
    end

    local menu = Results:ShowPinPopup(row, isPinned, onPin, onGuide, onAddAlias, extra)
    if menu then




        local searchFrame = Search:GetSearchFrame()
        local editBox = searchFrame and searchFrame.editBox
        if editBox then
            editBox._menuUnfocus = true
            editBox:ClearFocus()
            editBox._menuUnfocus = nil
        end
        row._efContextMenuHeld = true
        Results._contextHeldRow = row
        Results:SetRowHighlightLocked(row, true)
        Handlers:ApplyActionHint(row)
    end
    FocusKeyboardMenu(menu)
    Utils.SafeAfter(0, function()
        FocusKeyboardMenu(menu)
    end)
    return menu and true or false
end
