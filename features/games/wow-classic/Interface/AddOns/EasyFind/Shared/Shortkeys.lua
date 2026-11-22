local _, ns = ...












local Shortkeys = {}
ns.Shortkeys = Shortkeys

local Utils = ns.Utils
local InCombatLockdown = InCombatLockdown
local SetOverrideBindingClick = SetOverrideBindingClick
local ClearOverrideBindings = ClearOverrideBindings
local GetBindingAction = GetBindingAction
local pairs = pairs
local wipe = wipe

local function CharKey()
    return ns.CurrentCharacterKey()
end



function Shortkeys:IsCharacterSpecific(data)
    if not data then return false end
    local cat = data.category
    if cat == "Ability" or cat == "Talent" then return true end
    if data.macroIndex and data.macroIsChar then return true end
    return false
end

local function AccountStore()
    if not (EasyFind and EasyFind.db) then return nil end
    EasyFind.db.shortkeys = EasyFind.db.shortkeys or {}
    return EasyFind.db.shortkeys
end

local function CharStore()
    if not (EasyFind and EasyFind.db) then return nil end
    EasyFind.db.shortkeysPerChar = EasyFind.db.shortkeysPerChar or {}
    local ck = CharKey()
    EasyFind.db.shortkeysPerChar[ck] = EasyFind.db.shortkeysPerChar[ck] or {}
    return EasyFind.db.shortkeysPerChar[ck]
end

function Shortkeys:GetEntryKey(data)
    return ns.Aliases and ns.Aliases:GetEntryKey(data) or nil
end


function Shortkeys:Get(rowKey)
    if not rowKey then return nil end
    local acct = AccountStore()
    if acct and acct[rowKey] then return acct[rowKey], false end
    local perChar = CharStore()
    if perChar and perChar[rowKey] then return perChar[rowKey], true end
    return nil
end



function Shortkeys:ForEach(cb)
    local acct = AccountStore()
    if acct then for k, info in pairs(acct) do cb(k, info, false) end end
    local perChar = CharStore()
    if perChar then for k, info in pairs(perChar) do cb(k, info, true) end end
end



function Shortkeys:RemoveBind(bindKey)
    if not bindKey then return end
    local acct = AccountStore()
    if acct then
        for k, info in pairs(acct) do
            if info.key == bindKey then acct[k] = nil end
        end
    end
    local perChar = CharStore()
    if perChar then
        for k, info in pairs(perChar) do
            if info.key == bindKey then perChar[k] = nil end
        end
    end
end

function Shortkeys:Remove(rowKey)
    if not rowKey then return false end
    local removed = false
    local acct = AccountStore()
    if acct and acct[rowKey] then acct[rowKey] = nil; removed = true end
    local perChar = CharStore()
    if perChar and perChar[rowKey] then perChar[rowKey] = nil; removed = true end
    if removed then self:ApplyAll() end
    return removed
end




function Shortkeys:ClearAll()
    if not (EasyFind and EasyFind.db) then return end
    local acct = AccountStore()
    if acct then wipe(acct) end
    local pc = CharStore()
    if pc then wipe(pc) end
    self:ApplyAll()
end





















local SNAPSHOT_VER = 3
local function SnapshotData(data)
    local clean = ns.UIPins and ns.UIPins.CleanForStorage
    if data and clean then return clean(data) end
    return nil
end





function Shortkeys:SetByKey(rowKey, name, charSpecific, bindKey, data)
    if not (EasyFind and EasyFind.db and rowKey) then return false end
    if not bindKey or bindKey == "" then return false end
    local prev = self:Get(rowKey)
    self:RemoveBind(bindKey)
    local acct = AccountStore()
    if acct then acct[rowKey] = nil end
    local pc = CharStore()
    if pc then pc[rowKey] = nil end
    local store = charSpecific and CharStore() or AccountStore()
    if not store then return false end
    local snap = SnapshotData(data)
    store[rowKey] = {
        key = bindKey, name = name, charSpecific = charSpecific or nil,
        data = snap or (prev and prev.data) or nil,
        dataVer = snap and SNAPSHOT_VER or (prev and prev.dataVer) or nil,
    }
    self:ApplyAll()
    return true
end


local owner
local pool = {}




local shortkeysArmed = false
local POOL_PREFIX = "EasyFindShortkeyButton"

local function ResolveData(rowKey)
    return ns.Aliases and ns.Aliases:FindEntryByKey(rowKey) or nil
end



local KEY_PREFIX_PROVIDER = {
    ["mount:"]         = "mounts",
    ["toy:"]           = "toys",
    ["pet:"]           = "pets",
    ["outfit:"]        = "outfits",
    ["appearanceSet:"] = "transmogSets",
    ["macro:"]         = "macros",
    ["reputation:"]    = "reputations",
    ["currency:"]      = "currencies",
    ["loot:"]          = "loot",
    ["catalogitem:"]   = "appearanceItems",
    ["item:"]          = "bags",
}

local function RebindAfterPopulate()
    if Shortkeys.ReapplyIfPending then Shortkeys:ReapplyIfPending() end
end






local function RequestProviderForRowKey(rowKey)
    if not (rowKey and ns.Database and ns.Database.RequestDynamicProviderLoaded) then return end
    if rowKey:sub(1, 3) == "ui:" then


        pcall(ns.Database.RequestDynamicProviderLoaded, ns.Database, "abilities", nil)
        pcall(ns.Database.RequestDynamicProviderLoaded, ns.Database, "talents", nil)
        pcall(ns.Database.RequestDynamicProviderLoaded, ns.Database, "appearanceItems", nil)
        local options = ns.BlizzOptionsSearch
        if options and options.EnsurePopulatedAsync then
            options:EnsurePopulatedAsync(RebindAfterPopulate)
        end
        if options and options.EnsureLivePopulatedAsync then
            options:EnsureLivePopulatedAsync(RebindAfterPopulate)
        end
        return
    end
    for prefix, provider in pairs(KEY_PREFIX_PROVIDER) do
        if rowKey:sub(1, #prefix) == prefix then
            pcall(ns.Database.RequestDynamicProviderLoaded, ns.Database, provider, nil)
            return
        end
    end
end


Shortkeys.RequestProviderForRowKey = RequestProviderForRowKey

local function ShortkeyButtonData(self)
    local rowKey = self._rowKey
    local data = rowKey and ResolveData(rowKey)
    if not data and rowKey then
        local info = self._macroInfo or Shortkeys:Get(rowKey)
        data = info and info.data
    end
    return data
end






local function OnShortkeyButtonPreClick(self, _, down)
    if not down then return end
    if InCombatLockdown() then return end
    local data = ShortkeyButtonData(self)
    if data and ns.ResultSecureAttributes then
        ns.ResultSecureAttributes.ApplyAtClick(self, data)
        ns.ResultSecureAttributes.FlipBarAtPress(data)
    end
end

local function OnShortkeyButtonClick(self, _, down)





    if InCombatLockdown() then return end







    local data = ShortkeyButtonData(self)
    if not data then return end
    local opensPanel = ns.ResultSecureAttributes
        and ns.ResultSecureAttributes.ActsOnRelease(self, data)
    if opensPanel then
        if down then return end
    elseif not down then
        return
    end
    if not opensPanel and ns.ResultIcons
       and ns.ResultIcons:IsSecureActionResult(data) then return end


    if ns.ResultHandlers and ns.ResultHandlers.SelectResult then





        local shortcuts = ns.ResultShortcuts
        if shortcuts then shortcuts._resultShortcutActivation = true end









        if data.category == "Snippet" and not data.createRow and EasyFind.API.HasAction("snippets", "run") then
            EasyFind.API.CallAction("snippets", "run", data.name)
        elseif not (ns.ResultRows and ns.ResultRows.ActivateSettingResult
                and ns.ResultRows:ActivateSettingResult(data)) then
            ns.ResultHandlers:SelectResult(data)
        end
        if shortcuts then shortcuts._resultShortcutActivation = nil end
    end
end

local function EnsureOwner()
    if owner then return owner end
    owner = CreateFrame("Frame", "EasyFindShortkeyOwner", UIParent)
    owner:SetSize(1, 1)
    owner:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    owner:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then





            if shortkeysArmed then
                ClearOverrideBindings(self)
                shortkeysArmed = false
            end
            return
        end
        if event == "UPDATE_MACROS" then Shortkeys:PruneMacros() end
        Shortkeys:ApplyAll()
    end)





    owner:RegisterEvent("PLAYER_REGEN_DISABLED")
    owner:RegisterEvent("PLAYER_REGEN_ENABLED")
    owner:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    owner:RegisterEvent("PLAYER_ENTERING_WORLD")
    owner:RegisterEvent("TRANSMOG_OUTFITS_CHANGED")
    owner:RegisterEvent("UPDATE_MACROS")
    return owner
end

local function GetButton(i)
    if pool[i] then return pool[i] end
    EnsureOwner()
    local b = CreateFrame("Button", POOL_PREFIX .. i, owner, "SecureActionButtonTemplate")


    b:SetSize(1, 1)
    b:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", 0, 0)





    b:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    b:SetScript("PreClick", OnShortkeyButtonPreClick)
    b:SetScript("PostClick", OnShortkeyButtonClick)
    pool[i] = b
    return b
end

function Shortkeys:ApplyAll()
    if not (EasyFind and EasyFind.db) then return end
    EnsureOwner()
    if InCombatLockdown() then
        owner:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if shortkeysArmed then
        ClearOverrideBindings(owner)
        shortkeysArmed = false
    end

    local list = {}
    self:ForEach(function(rowKey, info)
        list[#list + 1] = { rowKey = rowKey, key = info.key, info = info }
    end)

    local hadUnresolved = false
    for i = 1, #list do
        local rowKey = list[i].rowKey
        local bindKey = list[i].key
        local info = list[i].info
        local data = ResolveData(rowKey)
        if data then



            info.data = SnapshotData(data)
            info.dataVer = info.data and SNAPSHOT_VER or nil
        else







            data = info.data
            if data and info.dataVer ~= SNAPSHOT_VER then
                hadUnresolved = true
            end
        end
        if data and bindKey and bindKey ~= "" then
            local b = GetButton(i)
            b._rowKey = rowKey
            if ns.ResultIcons and ns.ResultIcons:IsSecureActionResult(data) then
                if ns.ResultSecureAttributes and ns.ResultSecureAttributes.Apply then
                    ns.ResultSecureAttributes.Apply(b, data)
                end
            elseif ns.ResultSecureAttributes then



                ns.ResultSecureAttributes.Clear(b)
            end
            local btnName = b:GetName()
            if btnName then
                SetOverrideBindingClick(owner, true, bindKey, btnName, "LeftButton")
                shortkeysArmed = true
            end
        elseif bindKey and bindKey ~= "" then




            hadUnresolved = true
            RequestProviderForRowKey(rowKey)
        end
    end
    self._hasUnresolved = hadUnresolved
    self:ApplyMacros()
end




function Shortkeys:ReapplyIfPending()
    if self._hasUnresolved then self:ApplyAll() end
end





local MACRO_PREFIX = "EasyFindMacro"
local MACRO_NAME_MAX = 16
local MACRO_FALLBACK_ICON = "Interface\\Icons\\INV_Misc_Spyglass_03"
local macroPool = {}

local function MacroStore()
    if not (EasyFind and EasyFind.db) then return nil end
    local store = EasyFind.db.macroButtons
    if not store then
        store = { nextID = 1, byID = {} }
        EasyFind.db.macroButtons = store
    end
    return store
end



local function OnMacroButtonClick(self, button, down)
    local info = self._macroInfo
    if not info or InCombatLockdown() then return end
    if info.quicklist then
        if down and ns.Quicklists then ns.Quicklists:Toggle(info.quicklist) end
        return
    end
    if not ShortkeyButtonData(self) then
        if down and ns.ResultLinks and ns.ResultLinks.OpenKey then ns.ResultLinks:OpenKey(info.rowKey) end
        return
    end
    OnShortkeyButtonClick(self, button, down)
end

local function MacroButton(id)
    local b = macroPool[id]
    if b then return b end
    EnsureOwner()
    b = CreateFrame("Button", MACRO_PREFIX .. id, owner, "SecureActionButtonTemplate")
    b:SetSize(1, 1)
    b:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", 0, 0)
    b:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    b:SetScript("PreClick", OnShortkeyButtonPreClick)
    b:SetScript("PostClick", OnMacroButtonClick)
    macroPool[id] = b
    return b
end



function Shortkeys:ApplyMacros()
    local store = MacroStore()
    if not store or InCombatLockdown() then return end
    local Secure = ns.ResultSecureAttributes
    for id, info in pairs(store.byID) do
        local b = MacroButton(id)
        b._macroInfo = info
        b._rowKey = not info.quicklist and info.rowKey or nil
        local data = b._rowKey and ResolveData(info.rowKey)
        if data then
            info.data = SnapshotData(data)
            info.dataVer = info.data and SNAPSHOT_VER or nil
        else
            data = b._rowKey and info.data
        end
        if Secure and data and ns.ResultIcons and ns.ResultIcons:IsSecureActionResult(data) then
            Secure.Apply(b, data)
        elseif Secure then
            Secure.Clear(b)
        end
    end
end


local function MacroIndexFor(id)
    local tag = MACRO_PREFIX .. id .. " "
    local numAccount, numChar = GetNumMacros()
    local consts = _G["Constants"] and _G["Constants"].MacroConsts
    local base = consts and consts.MAX_ACCOUNT_MACROS or 120
    for i = 1, (numAccount or 0) do
        local _, _, body = GetMacroInfo(i)
        if body and body:find(tag, 1, true) then return i end
    end
    for i = base + 1, base + (numChar or 0) do
        local _, _, body = GetMacroInfo(i)
        if body and body:find(tag, 1, true) then return i end
    end
    return nil
end



function Shortkeys:PruneMacros()
    local store = EasyFind and EasyFind.db and EasyFind.db.macroButtons
    if not store or InCombatLockdown() then return end
    local numAccount, numChar = GetNumMacros()
    if (numAccount or 0) + (numChar or 0) == 0 then return end
    local here = CharKey()
    for id, info in pairs(store.byID) do
        if (not info.char or info.char == here) and not MacroIndexFor(id) then
            store.byID[id] = nil
            local b = macroPool[id]
            if b then
                b._macroInfo, b._rowKey = nil, nil
                if ns.ResultSecureAttributes then ns.ResultSecureAttributes.Clear(b) end
            end
        end
    end
end


local function MacroName(name)
    name = tostring(name or "")
    local chars = 0
    for pos = 1, #name do
        local c = name:byte(pos)
        if c < 128 or c >= 192 then
            chars = chars + 1
            if chars > MACRO_NAME_MAX then
                name = name:sub(1, pos - 1)
                break
            end
        end
    end
    return name ~= "" and name or (_G["MACRO"] or "Macro")
end

local function MacroIcon(icon)
    if type(icon) == "number" then return icon end
    local GetFileIDFromPath = _G["GetFileIDFromPath"]
    if not GetFileIDFromPath then return 134400 end
    local fileID = type(icon) == "string" and GetFileIDFromPath(icon)
    if fileID and fileID > 0 then return fileID end
    return GetFileIDFromPath(MACRO_FALLBACK_ICON) or 134400
end




function Shortkeys:CreateMacro(rowKey, name, data, quicklistID)
    local store = rowKey and MacroStore()
    if not store then return false end
    if InCombatLockdown() then
        if EasyFind.Print then EasyFind:Print(ns.L["MACRO_IN_COMBAT"]) end
        return false
    end
    local id
    for eid, info in pairs(store.byID) do
        if info.rowKey == rowKey then
            id = eid
            break
        end
    end
    if not id then
        id = store.nextID
        store.nextID = id + 1
        store.byID[id] = { rowKey = rowKey }
    end
    local info = store.byID[id]
    info.name, info.quicklist = name, quicklistID
    local snap = data and SnapshotData(data)
    if snap then info.data, info.dataVer = snap, SNAPSHOT_VER end
    self:ApplyMacros()
    local index = MacroIndexFor(id)
    if not index then
        local button = MACRO_PREFIX .. id
        local body = ("/click %s LeftButton 1\n/click %s LeftButton 0"):format(button, button)
        local macroName, icon = MacroName(name), MacroIcon(data and data.icon)
        local ok, made = pcall(CreateMacro, macroName, icon, body, nil)
        info.char = nil
        if not (ok and made) then
            ok, made = pcall(CreateMacro, macroName, icon, body, true)
            info.char = ok and made and CharKey() or nil
        end
        index = ok and made or nil
    end
    if not index then
        if EasyFind.Print then EasyFind:Print(ns.L["MACRO_NO_ROOM"]) end
        return false
    end
    PickupMacro(index)
    return true
end


local L = ns.L
local capturePopup





local function DetectBindConflict(rowKey, combo, excludeListID)
    local otherName
    Shortkeys:ForEach(function(k, info)
        if not otherName and k ~= rowKey and info.key == combo then
            otherName = info.name or "?"
        end
    end)
    if not otherName and ns.Quicklists then
        otherName = ns.Quicklists:KeyOwnerName(combo, excludeListID)
    end
    if otherName then return "shortkey", otherName end
    local action = GetBindingAction and GetBindingAction(combo)
    if action and action ~= "" then return "bind", combo end
    return nil
end

local function CommitShortkey(rowKey, name, charSpecific, combo, data)
    if not Shortkeys:SetByKey(rowKey, name, charSpecific, combo, data) then return end
    local sf = ns.Search and ns.Search:GetSearchFrame()
    local eb = sf and sf.editBox
    local typedQuery = ns.Search.GetTypedQuery and ns.Search:GetTypedQuery() or (eb and eb:GetText()) or ""
    if typedQuery ~= "" then ns.Search:OnSearchTextChanged(typedQuery) end
    if ns.RefreshBindTables then ns.RefreshBindTables() end
end




local conflictPopup
local function BuildConflictPopup()
    local f = CreateFrame("Frame", "EasyFindShortkeyConflict", UIParent, "BackdropTemplate")
    f:SetSize(340, 150)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    ns.StyleMenuPanel(f)

    f.message = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.message:SetPoint("TOPLEFT", 16, -18)
    f.message:SetPoint("TOPRIGHT", -16, -18)
    f.message:SetJustifyH("CENTER")
    f.message:SetWordWrap(true)

    local cb = CreateFrame("CheckButton", nil, f)
    cb:SetSize(20, 20)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    f.dontAsk = cb
    local cbLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cbLabel:SetText(L["SHORTKEY_CONFLICT_DONT_ASK"])



    local groupHalf = math.floor((20 + 4 + cbLabel:GetStringWidth()) / 2)
    cb:SetPoint("BOTTOMLEFT", f, "BOTTOM", -groupHalf, 46)

    local continueBtn = ns.CreateModernButton(f, _G["CONTINUE"] or "Continue", 110, 24)
    continueBtn:SetPoint("BOTTOM", f, "BOTTOM", -58, 14)
    continueBtn:SetScript("OnClick", function()
        if f.dontAsk:GetChecked() then EasyFind.db.shortkeyConflictPrompt = false end
        local onAccept = f.onAccept
        f:Hide()
        if onAccept then onAccept() end
    end)

    local cancelBtn = ns.CreateModernButton(f, _G["CANCEL"] or "Cancel", 110, 24)
    cancelBtn:SetPoint("BOTTOM", f, "BOTTOM", 58, 14)
    cancelBtn:SetScript("OnClick", function()
        if f.dontAsk:GetChecked() then EasyFind.db.shortkeyConflictPrompt = false end
        f:Hide()
    end)

    local close = ns.CreateCloseX(f, 14)
    close:SetPoint("TOPRIGHT", -8, -8)
    close:SetScript("OnClick", function() f:Hide() end)

    f:SetScript("OnHide", function(self) self.onAccept = nil end)
    f:Hide()
    return f
end

local function ShowConflictPopup(message, onAccept)
    if not conflictPopup then conflictPopup = BuildConflictPopup() end
    conflictPopup.onAccept = onAccept
    conflictPopup.dontAsk:SetChecked(false)
    conflictPopup.message:SetText(message)
    conflictPopup:SetHeight(conflictPopup.message:GetStringHeight() + 98)
    conflictPopup:Show()
end

local function StopCapture(popup)
    popup.capturing = false
    Utils.DisarmBindingCapture(popup)
    if popup.bindBtn then
        local current = popup.currentCombo
        if not popup.onCombo then
            local existing = popup.rowKey and Shortkeys:Get(popup.rowKey)
            current = existing and existing.key
        end
        popup.bindBtn:SetText(current or L["SHORTKEY_CLICK_TO_BIND"])
    end
end

local function StartCapture(popup)
    popup.capturing = true
    popup.bindBtn:SetText(L["OPT_KB_PRESS_KEY"])
    Utils.ArmBindingCapture(popup, function(self, combo)
        if combo == "stop" then StopCapture(self); return end


        if self.onCombo then
            local onCombo, exclude = self.onCombo, self.excludeListID
            StopCapture(self)
            self:Hide()
            local kind, label = DetectBindConflict(nil, combo, exclude)
            if kind and EasyFind and EasyFind.db and EasyFind.db.shortkeyConflictPrompt ~= false then
                local msg = (kind == "shortkey"
                    and L["SHORTKEY_CONFLICT_SHORTKEY"]
                    or L["SHORTKEY_CONFLICT_BIND"]):format(label)
                ShowConflictPopup(msg, function() onCombo(combo) end)
            else
                onCombo(combo)
            end
            return
        end
        local rowKey, name, cs, skData = self.rowKey, self.skName, self.charSpecific, self.skData
        StopCapture(self)
        self:Hide()
        if not rowKey then return end
        local kind, label = DetectBindConflict(rowKey, combo)
        if kind and EasyFind and EasyFind.db and EasyFind.db.shortkeyConflictPrompt ~= false then
            local msg = (kind == "shortkey"
                and L["SHORTKEY_CONFLICT_SHORTKEY"]
                or L["SHORTKEY_CONFLICT_BIND"]):format(label)
            ShowConflictPopup(msg, function() CommitShortkey(rowKey, name, cs, combo, skData) end)
        else
            CommitShortkey(rowKey, name, cs, combo, skData)
        end
    end)
end




function Shortkeys:AttachComboCapture(btn, get, onCombo, onClear, excludeListID)
    local function Label() btn:SetText(get() or L["SHORTKEY_CLICK_TO_BIND"]) end
    local function Stop()
        if not btn.capturing then return end
        btn.capturing = false
        Utils.DisarmBindingCapture(btn)
        Label()
    end
    btn._efStopCapture = Stop
    if not btn._efCaptureHideHooked then
        btn._efCaptureHideHooked = true
        btn:HookScript("OnHide", function(self) if self._efStopCapture then self._efStopCapture() end end)
    end
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            Stop()
            onClear()
            Label()
            return
        end
        if self.capturing then Stop() return end

        local focus = Utils.KeyboardFocus()
        if focus then focus:ClearFocus() end
        self.capturing = true
        self:SetText(L["OPT_KB_PRESS_KEY"])
        Utils.ArmBindingCapture(self, function(_, combo)
            Stop()
            if combo == "stop" then return end
            local function Take()
                onCombo(combo)
                Label()
            end
            local kind, label = DetectBindConflict(nil, combo, excludeListID)
            if kind and EasyFind and EasyFind.db and EasyFind.db.shortkeyConflictPrompt ~= false then
                ShowConflictPopup((kind == "shortkey" and L["SHORTKEY_CONFLICT_SHORTKEY"]
                    or L["SHORTKEY_CONFLICT_BIND"]):format(label), Take)
            else
                Take()
            end
        end)
    end)
    Label()
end

local function BuildCapturePopup()
    local f = CreateFrame("Frame", "EasyFindShortkeyCapture", UIParent, "BackdropTemplate")
    f:SetSize(300, 116)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    ns.StyleMenuPanel(f)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 12, -13)
    f.title:SetPoint("TOPRIGHT", -12, -13)
    f.title:SetJustifyH("CENTER")
    f.title:SetWordWrap(true)


    local bindBtn = ns.CreateModernButton(f, L["SHORTKEY_CLICK_TO_BIND"], 190, 24)
    bindBtn:SetNormalFontObject("GameFontHighlightSmall")
    bindBtn:SetHighlightFontObject("GameFontHighlightSmall")
    bindBtn:SetPoint("TOP", f.title, "BOTTOM", 0, -14)
    bindBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bindBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if f.onClear then
                f.currentCombo = nil
                StopCapture(f)
                f.onClear()
                return
            end
            if f.rowKey then Shortkeys:Remove(f.rowKey) end
            StopCapture(f)
            if ns.RefreshBindTables then ns.RefreshBindTables() end
            return
        end
        if f.capturing then StopCapture(f) else StartCapture(f) end
    end)
    f.bindBtn = bindBtn

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("TOP", bindBtn, "BOTTOM", 0, -8)
    f.hint:SetText(L["OPT_KB_CLEAR_HINT"])



    f.combatNote = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.combatNote:SetPoint("TOP", f.hint, "BOTTOM", 0, -6)
    f.combatNote:SetText(L["SHORTKEY_COMBAT_NOTE"])

    f.macroBtn = ns.CreateModernButton(f, L["SHORTKEY_MAKE_MACRO"], 190, 22)
    f.macroBtn:SetNormalFontObject("GameFontHighlightSmall")
    f.macroBtn:SetHighlightFontObject("GameFontHighlightSmall")

    local labelW = f.macroBtn._label and f.macroBtn._label:GetStringWidth() or 0
    f.macroBtn:SetSize(math.min(math.max(190, labelW + 24), f:GetWidth() - 24), 22)
    f.macroBtn:SetText(L["SHORTKEY_MAKE_MACRO"])
    f.macroBtn:SetPoint("TOP", f.combatNote, "BOTTOM", 0, -10)
    f.macroBtn:SetScript("OnClick", function()
        local onMacro = f.onMacro
        f:Hide()
        if onMacro then onMacro() end
    end)
    f.macroBtn:HookScript("OnEnter", function(self) ns.ShowHintTooltip(self, "ANCHOR_TOP", nil, L["CTX_CREATE_MACRO_TT"]) end)
    f.macroBtn:HookScript("OnLeave", function(self) ns.HideHintTooltip(self) end)

    local close = ns.CreateCloseX(f, 14)
    close:SetPoint("TOPRIGHT", -8, -8)
    close:SetScript("OnClick", function() f:Hide() end)

    f:SetScript("OnHide", function(self)
        StopCapture(self)
        self.rowKey = nil
        self.skName = nil
        self.charSpecific = nil
        self.skData = nil
        self.onCombo = nil
        self.onClear = nil
        self.currentCombo = nil
        self.excludeListID = nil
        self.onMacro = nil
    end)
    f:Hide()
    return f
end


local function ShowCapturePopup(f)
    f.macroBtn:SetShown(f.onMacro ~= nil)
    f:SetHeight(f.onMacro and 150 or 116)
    f:Show()

    f:Raise()
end



function Shortkeys:PromptForCombo(title, current, onCombo, onClear, excludeListID, onMacro)
    if not capturePopup then capturePopup = BuildCapturePopup() end
    local f = capturePopup
    f:Hide()
    f.onCombo = onCombo
    f.onClear = onClear
    f.currentCombo = current
    f.excludeListID = excludeListID
    f.onMacro = onMacro
    f.title:SetText(title or "")
    f.bindBtn:SetText(current or L["SHORTKEY_CLICK_TO_BIND"])
    ShowCapturePopup(f)
end

function Shortkeys:PromptForKeyByKey(rowKey, name, charSpecific, data)
    if not rowKey then return end
    if not capturePopup then capturePopup = BuildCapturePopup() end
    capturePopup.rowKey = rowKey
    capturePopup.skName = name
    capturePopup.charSpecific = charSpecific
    capturePopup.skData = data
    capturePopup.title:SetText((L["SHORTKEY_FOR"]):format(name or "?"))
    local existing = self:Get(rowKey)
    capturePopup.bindBtn:SetText((existing and existing.key) or L["SHORTKEY_CLICK_TO_BIND"])

    capturePopup.onMacro = not (data and data.lookupRow) and function()
        if Shortkeys:CreateMacro(rowKey, name, data) and ns.ResultHandlers then
            ns.ResultHandlers:FinishResultSelection()
        end
    end or nil
    ShowCapturePopup(capturePopup)
end

function Shortkeys:PromptForKey(data)
    if not data then return end
    local rowKey = self:GetEntryKey(data)
    if not rowKey then return end
    self:PromptForKeyByKey(rowKey, data.name, self:IsCharacterSpecific(data), data)
end





local base64enc, base64dec = Utils.Base64Encode, Utils.Base64Decode







local SHARE_CAPS = { aliases = 300, shortkeys = 100, blacklist = 500, snippets = 100, quicklists = 50 }
local SHARE_FIELD_MAX = 80
local SHARE_BODY_MAX = 255
local SHARE_BODY_RAW_MAX = 1024


local REFUSED_KEYS = {
    W = true, A = true, S = true, D = true, Q = true, E = true,
    SPACE = true, ESCAPE = true, ENTER = true, TAB = true,
    UP = true, DOWN = true, LEFT = true, RIGHT = true,
    BUTTON1 = true, BUTTON2 = true, MOUSEWHEELUP = true, MOUSEWHEELDOWN = true,
}

local REFUSED_COMMANDS = {
    "/logout", "/quit", "/exit", "/camp", "/reload", "/console",
    "/run", "/script", "/dump", "/afk", "/dnd",
}
Shortkeys.SHARE_CAPS, Shortkeys.SHARE_FIELD_MAX, Shortkeys.SHARE_BODY_MAX = SHARE_CAPS, SHARE_FIELD_MAX, SHARE_BODY_MAX
Shortkeys.SHARE_BODY_RAW_MAX = SHARE_BODY_RAW_MAX
Shortkeys.REFUSED_KEYS, Shortkeys.REFUSED_COMMANDS = REFUSED_KEYS, REFUSED_COMMANDS

local function StartsWithRefusedCommand(text)
    if type(text) ~= "string" then return false end
    local lower = strtrim(text):lower()
    for i = 1, #REFUSED_COMMANDS do
        local cmd = REFUSED_COMMANDS[i]
        if lower:sub(1, #cmd) == cmd then
            local after = lower:sub(#cmd + 1, #cmd + 1)
            if after == "" or after == " " or after == "\n" then return true end
        end
    end
    return false
end


local function BodyHasRefusedCommand(body)
    if type(body) ~= "string" then return false end
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        if StartsWithRefusedCommand(line) then return true end
    end
    return false
end

local function LineIsCommand(line)
    return type(line) == "string" and strtrim(line):sub(1, 1) == "/"
end




function Shortkeys.RunsCommands(section, row)
    if type(row) ~= "table" then return false end
    if section == "shortkeys" then return LineIsCommand(row.n) end
    if section == "snippets" and type(row.body) == "string" then
        for line in (row.body .. "\n"):gmatch("([^\n]*)\n") do
            if LineIsCommand(line) then return true end
        end
    end
    return false
end



local function Chars(s)
    if strlenutf8 then return strlenutf8(s) end
    return #s
end

local function TooLong(max, ...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "string" and Chars(v) > max then return true end
    end
    return false
end




local function BodyTooLong(body)
    if type(body) ~= "string" then return false end
    if #body > SHARE_BODY_RAW_MAX then return true end
    local visible = Utils.ClipboardSafeText and Utils.ClipboardSafeText(body) or body
    return Chars(visible) > SHARE_BODY_MAX
end




local function AliasRowLabel(r)
    return '"' .. (r.text or "?") .. '"  (' .. (r.name or "?") .. ")"
end

local function ShortkeyRowLabel(r)
    return (r.b or "?") .. "  (" .. (r.n or "?") .. ")"
end

local function SnippetRowLabel(r)
    local keyword = type(r.keyword) == "string" and r.keyword ~= "" and (r.keyword .. "  ") or ""
    return keyword .. (r.name or "?")
end

local function ShareRowLabel(section, r)
    if section == "aliases" then return AliasRowLabel(r) end
    if section == "shortkeys" then return ShortkeyRowLabel(r) end
    if section == "snippets" then return SnippetRowLabel(r) end
    return r.name or "?"
end




function Shortkeys.ShareRefusal(section, row)
    if type(row) ~= "table" then return "length" end
    if section == "shortkeys" then
        local combo = type(row.b) == "string" and row.b or ""
        local last = combo:match("([^%-]+)$") or combo
        if REFUSED_KEYS[last:upper()] then return "key" end
        if StartsWithRefusedCommand(row.n) then return "command" end
        if TooLong(SHARE_FIELD_MAX, row.k, row.b, row.n) then return "length" end
    elseif section == "aliases" then
        if TooLong(SHARE_FIELD_MAX, row.text, row.key, row.name) then return "length" end
    elseif section == "blacklist" then
        if TooLong(SHARE_FIELD_MAX, row.key, row.name, row.category) then return "length" end
    elseif section == "snippets" then
        if BodyHasRefusedCommand(row.body) then return "command" end
        if TooLong(SHARE_FIELD_MAX, row.name, row.keyword) or BodyTooLong(row.body) then
            return "length"
        end
    elseif section == "quicklists" then
        local combo = type(row.key) == "string" and row.key or ""
        local last = combo:match("([^%-]+)$") or combo
        if combo ~= "" and REFUSED_KEYS[last:upper()] then return "key" end
        if TooLong(SHARE_FIELD_MAX, row.name) then return "length" end
        local items = type(row.items) == "table" and row.items or {}
        if #items > 60 then return "length" end
        for i = 1, #items do
            if type(items[i]) ~= "table" or TooLong(SHARE_FIELD_MAX, items[i].k, items[i].n) then
                return "length"
            end
        end
    end
    return nil
end


local function encS(s)
    s = tostring(s or "")
    return #s .. ":" .. s
end

local function decS(blob, pos)
    local colon = blob:find(":", pos, true)
    if not colon then return nil, pos end
    local len = tonumber(blob:sub(pos, colon - 1))
    if not len then return nil, pos end
    local val = blob:sub(colon + 1, colon + len)
    return val, colon + 1 + len
end


ns.ShareCodec = { base64enc = base64enc, base64dec = base64dec, encS = encS, decS = decS }

function Shortkeys:ExportList()
    local out = {}
    self:ForEach(function(rowKey, info, isChar)
        out[#out + 1] = { k = rowKey, b = info.key, n = info.name, c = isChar }
    end)
    return out
end



function Shortkeys:ImportWouldOverride(rowKey, combo)
    if self:Get(rowKey) then return true end
    local taken = false
    self:ForEach(function(k, info)
        if not taken and k ~= rowKey and info.key == combo then taken = true end
    end)
    return taken
end

function Shortkeys:ImportList(list, skipExisting)
    if type(list) ~= "table" then return 0 end
    local n = 0
    for i = 1, #list do
        local r = list[i]
        if r and r.k and r.b and r.b ~= "" then
            if not (skipExisting and self:ImportWouldOverride(r.k, r.b)) then
                if self:SetByKey(r.k, r.n, r.c, r.b) then n = n + 1 end
            end
        end
    end
    return n
end

function Shortkeys:BuildExportString(which)
    which = which or "both"
    local parts = { "EFSK1", encS(which) }


    local leftOut = {}
    local function Keep(section, list)
        local kept = {}
        for i = 1, #list do
            local why = Shortkeys.ShareRefusal(section, list[i])
            if why then
                leftOut[#leftOut + 1] = { section = section, label = ShareRowLabel(section, list[i]), reason = why, row = list[i] }
            else
                kept[#kept + 1] = list[i]
            end
        end
        return kept
    end

    local aliasList = {}
    if (which == "alias" or which == "both") and ns.Aliases and ns.Aliases.ExportList then
        aliasList = Keep("aliases", ns.Aliases:ExportList())
    end
    parts[#parts + 1] = encS(#aliasList)
    for i = 1, #aliasList do
        local r = aliasList[i]
        parts[#parts + 1] = encS(r.text)
        parts[#parts + 1] = encS(r.key)
        parts[#parts + 1] = encS(r.name)
    end

    local skList = {}
    if which == "shortkey" or which == "both" then
        skList = Keep("shortkeys", self:ExportList())
    end
    parts[#parts + 1] = encS(#skList)
    for i = 1, #skList do
        local r = skList[i]
        parts[#parts + 1] = encS(r.k)
        parts[#parts + 1] = encS(r.b)
        parts[#parts + 1] = encS(r.n)
        parts[#parts + 1] = encS(r.c and "1" or "0")
    end



    local blList = {}
    if which == "blacklist" and ns.Blacklist and ns.Blacklist.ExportList then
        blList = Keep("blacklist", ns.Blacklist:ExportList())
    end
    parts[#parts + 1] = encS(#blList)
    for i = 1, #blList do
        local r = blList[i]
        parts[#parts + 1] = encS(r.key)
        parts[#parts + 1] = encS(r.name)
        parts[#parts + 1] = encS(r.category or "")
    end



    local snList = {}
    if which == "snippet" and ns.Snippets and ns.Snippets.ExportList then
        snList = Keep("snippets", ns.Snippets:ExportList())
    end
    parts[#parts + 1] = encS(#snList)
    for i = 1, #snList do
        local r = snList[i]
        parts[#parts + 1] = encS(r.name)
        parts[#parts + 1] = encS(r.keyword or "")
        parts[#parts + 1] = encS(r.body or "")
    end



    local qlList = {}
    if which == "quicklist" and ns.QuicklistStore then
        qlList = Keep("quicklists", ns.QuicklistStore.ExportList())
    end
    parts[#parts + 1] = encS(#qlList)
    for i = 1, #qlList do
        local r = qlList[i]
        parts[#parts + 1] = encS(r.name)
        parts[#parts + 1] = encS(r.key or "")
        parts[#parts + 1] = encS(r.hold and "1" or "0")
        parts[#parts + 1] = encS(#r.items)
        for j = 1, #r.items do
            parts[#parts + 1] = encS(r.items[j].k)
            parts[#parts + 1] = encS(r.items[j].n or "")
        end
    end

    return "EF1!" .. base64enc(table.concat(parts)), #leftOut, leftOut
end

function Shortkeys:DecodeString(str)
    if type(str) ~= "string" then return nil end
    local b64 = strtrim(str):match("^EF1!(.+)$")
    if not b64 then return nil end
    local ok, blob = pcall(base64dec, b64)
    if not ok or type(blob) ~= "string" or blob:sub(1, 5) ~= "EFSK1" then return nil end




    local MAX_IMPORT_ROWS = 5000
    local pos = 6
    local _, aliasCountStr, skCountStr
    _, pos = decS(blob, pos)
    aliasCountStr, pos = decS(blob, pos)
    local aliasCount = tonumber(aliasCountStr) or 0
    if aliasCount > MAX_IMPORT_ROWS then aliasCount = MAX_IMPORT_ROWS end
    local aliases = {}
    for _ = 1, aliasCount do
        local text, key, name
        text, pos = decS(blob, pos)
        if not text then break end
        key, pos = decS(blob, pos)
        name, pos = decS(blob, pos)
        if key then aliases[#aliases + 1] = { text = text, key = key, name = name } end
    end

    skCountStr, pos = decS(blob, pos)
    local skCount = tonumber(skCountStr) or 0
    if skCount > MAX_IMPORT_ROWS then skCount = MAX_IMPORT_ROWS end
    local shortkeys = {}
    for _ = 1, skCount do
        local k, b, n, c
        k, pos = decS(blob, pos)
        if not k then break end
        b, pos = decS(blob, pos)
        n, pos = decS(blob, pos)
        c, pos = decS(blob, pos)
        if b then shortkeys[#shortkeys + 1] = { k = k, b = b, n = n, c = (c == "1") } end
    end

    local blCountStr
    blCountStr, pos = decS(blob, pos)
    local blCount = tonumber(blCountStr) or 0
    if blCount > MAX_IMPORT_ROWS then blCount = MAX_IMPORT_ROWS end
    local blacklist = {}
    for _ = 1, blCount do
        local key, name, category
        key, pos = decS(blob, pos)
        if not key then break end
        name, pos = decS(blob, pos)
        category, pos = decS(blob, pos)
        blacklist[#blacklist + 1] = {
            key = key, name = name,
            category = category ~= "" and category or nil,
        }
    end

    local snCountStr
    snCountStr, pos = decS(blob, pos)
    local snCount = tonumber(snCountStr) or 0
    if snCount > MAX_IMPORT_ROWS then snCount = MAX_IMPORT_ROWS end
    local snippets = {}
    for _ = 1, snCount do
        local name, keyword, body
        name, pos = decS(blob, pos)
        if not name then break end
        keyword, pos = decS(blob, pos)
        body, pos = decS(blob, pos)
        if body then snippets[#snippets + 1] = { name = name, keyword = keyword, body = body } end
    end

    local qlCountStr
    qlCountStr, pos = decS(blob, pos)
    local qlCount = tonumber(qlCountStr) or 0
    if qlCount > MAX_IMPORT_ROWS then qlCount = MAX_IMPORT_ROWS end
    local quicklists = {}
    for _ = 1, qlCount do
        local name, key, hold, itemCountStr
        name, pos = decS(blob, pos)
        if not name then break end
        key, pos = decS(blob, pos)
        hold, pos = decS(blob, pos)
        itemCountStr, pos = decS(blob, pos)
        local itemCount = tonumber(itemCountStr) or 0
        if itemCount > 200 then itemCount = 200 end
        local items = {}
        for _ = 1, itemCount do
            local k, n
            k, pos = decS(blob, pos)
            if not k then break end
            n, pos = decS(blob, pos)
            items[#items + 1] = { k = k, n = n }
        end
        quicklists[#quicklists + 1] = {
            name = name, key = key ~= "" and key or nil, hold = hold == "1", items = items,
        }
    end

    return { aliases = aliases, shortkeys = shortkeys, blacklist = blacklist, snippets = snippets,
             quicklists = quicklists }
end



function Shortkeys:CheckImportLimits(decoded, which)
    if type(decoded) ~= "table" then return nil end
    which = which or "both"
    local checks = {
        { id = "aliases", on = which == "alias" or which == "both" },
        { id = "shortkeys", on = which == "shortkey" or which == "both" },
        { id = "blacklist", on = which == "blacklist" },
        { id = "snippets", on = which == "snippet" },
        { id = "quicklists", on = which == "quicklist" },
    }
    for i = 1, #checks do
        local c = checks[i]
        local list = decoded[c.id]
        if c.on and type(list) == "table" and #list > SHARE_CAPS[c.id] then
            return { section = c.id, count = #list, cap = SHARE_CAPS[c.id] }
        end
    end
    return nil
end




local function SystemCommandLabel(name)
    if type(name) ~= "string" then return nil end
    local cmds = ns.SYSTEM_COMMANDS
    if type(cmds) ~= "table" then return nil end
    local lower = strtrim(name):lower()
    for i = 1, #cmds do
        if lower == cmds[i] then return cmds[i] end
    end
    return nil
end








function Shortkeys:AnalyzeImport(decoded, which)
    which = which or "both"
    local conflicts = {}
    local newRows = { aliases = {}, shortkeys = {}, blacklist = {}, snippets = {}, quicklists = {} }
    local skipped = {}
    local disruptive, seenCmd = {}, {}
    local result = { conflicts = conflicts, newRows = newRows, disruptive = disruptive, skipped = skipped }
    if type(decoded) ~= "table" then return result end

    local function Refused(section, row, label)
        local why = Shortkeys.ShareRefusal(section, row)
        if why then skipped[#skipped + 1] = { section = section, label = label, reason = why } end
        return why ~= nil
    end

    if (which == "alias" or which == "both") and decoded.aliases then
        for i = 1, #decoded.aliases do
            local r = decoded.aliases[i]
            if r and r.text and strtrim(r.text) ~= "" and r.key
               and not Refused("aliases", r, AliasRowLabel(r)) then
                if ns.Aliases and ns.Aliases:HasAlias(r.text) then
                    conflicts[#conflicts + 1] = { section = "aliases", row = r, label = AliasRowLabel(r) }
                else
                    newRows.aliases[#newRows.aliases + 1] = r
                end
            end
        end
    end

    if (which == "shortkey" or which == "both") and decoded.shortkeys then
        for i = 1, #decoded.shortkeys do
            local r = decoded.shortkeys[i]
            if r and r.k and r.b and r.b ~= "" and not Refused("shortkeys", r, ShortkeyRowLabel(r)) then
                if self:ImportWouldOverride(r.k, r.b) then
                    conflicts[#conflicts + 1] = { section = "shortkeys", row = r, label = ShortkeyRowLabel(r) }
                else
                    newRows.shortkeys[#newRows.shortkeys + 1] = r
                end
                local cmd = SystemCommandLabel(r.n)
                if cmd and not seenCmd[cmd] then
                    seenCmd[cmd] = true
                    disruptive[#disruptive + 1] = cmd
                end
            end
        end
    end

    if which == "blacklist" and decoded.blacklist then
        for i = 1, #decoded.blacklist do
            local r = decoded.blacklist[i]
            if r and r.key and not Refused("blacklist", r, r.name or "?") then
                if ns.Blacklist and ns.Blacklist:Has(r.key) then
                    conflicts[#conflicts + 1] = { section = "blacklist", row = r, label = r.name or "?" }
                else
                    newRows.blacklist[#newRows.blacklist + 1] = r
                end
            end
        end
    end

    if which == "snippet" and decoded.snippets then
        for i = 1, #decoded.snippets do
            local r = decoded.snippets[i]
            if r and type(r.name) == "string" and strtrim(r.name) ~= ""
               and not Refused("snippets", r, SnippetRowLabel(r)) then


                local clash = ns.Snippets and ns.Snippets.FindConflict and ns.Snippets:FindConflict(r.name, r.keyword)
                if clash then
                    conflicts[#conflicts + 1] = { section = "snippets", row = r, label = SnippetRowLabel(r) }
                else
                    newRows.snippets[#newRows.snippets + 1] = r
                end
            end
        end
    end

    if which == "quicklist" and decoded.quicklists then
        for i = 1, #decoded.quicklists do
            local r = decoded.quicklists[i]
            if r and type(r.name) == "string" and strtrim(r.name) ~= ""
               and not Refused("quicklists", r, r.name) then
                if ns.QuicklistStore and ns.QuicklistStore.FindByName(r.name) then
                    conflicts[#conflicts + 1] = { section = "quicklists", row = r, label = r.name }
                else
                    newRows.quicklists[#newRows.quicklists + 1] = r
                end
            end
        end
    end

    return result
end




function Shortkeys:ApplyDecoded(decoded, which, skipExisting)
    if type(decoded) ~= "table" then return nil end
    which = which or "both"
    local na, nk, nb = 0, 0, 0
    if (which == "alias" or which == "both") and ns.Aliases and ns.Aliases.ImportList then
        na = ns.Aliases:ImportList(decoded.aliases, skipExisting)
    end
    if which == "shortkey" or which == "both" then
        nk = self:ImportList(decoded.shortkeys, skipExisting)
    end
    if which == "blacklist" and ns.Blacklist and ns.Blacklist.ImportList then
        nb = ns.Blacklist:ImportList(decoded.blacklist, skipExisting)
    end
    local nsn = 0
    if which == "snippet" and ns.Snippets and ns.Snippets.ImportList then
        nsn = ns.Snippets:ImportList(decoded.snippets, skipExisting)
    end
    local nq = 0
    if which == "quicklist" and ns.QuicklistStore then
        nq = ns.QuicklistStore.ImportList(decoded.quicklists, skipExisting)
        if ns.Quicklists then ns.Quicklists:Changed() end
    end
    if ns.RefreshBindTables then ns.RefreshBindTables() end
    return na, nk, nb, nsn, nq
end





function Shortkeys:ApplyResolvedImport(applySet)
    if type(applySet) ~= "table" then return 0, 0, 0 end
    local na, nb = 0, 0
    if ns.Aliases and ns.Aliases.ImportList then
        na = ns.Aliases:ImportList(applySet.aliases, false)
    end
    local nk = self:ImportList(applySet.shortkeys, false)
    if ns.Blacklist and ns.Blacklist.ImportList then
        nb = ns.Blacklist:ImportList(applySet.blacklist, false)
    end
    local nsn = 0
    if ns.Snippets and ns.Snippets.ImportList then
        nsn = ns.Snippets:ImportList(applySet.snippets, false)
    end
    local nq = 0
    if ns.QuicklistStore and applySet.quicklists then
        nq = ns.QuicklistStore.ImportList(applySet.quicklists, false)
        if ns.Quicklists then ns.Quicklists:Changed() end
    end
    if ns.RefreshBindTables then ns.RefreshBindTables() end
    return na, nk, nb, nsn, nq
end



function Shortkeys:ApplyImportString(str, which, skipExisting)
    local decoded = self:DecodeString(str)
    if not decoded then return nil end
    return self:ApplyDecoded(decoded, which, skipExisting)
end
