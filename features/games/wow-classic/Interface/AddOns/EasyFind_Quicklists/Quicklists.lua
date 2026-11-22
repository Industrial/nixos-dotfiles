local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns then return end
local Store = ns.QuicklistStore
if not Store then return end





local Quicklists = {}
ns.Quicklists = Quicklists

local Utils = ns.Utils
local L = ns.L
local slower = Utils.slower or string.lower
local sfind = Utils.sfind or string.find
local sformat = Utils.sformat or string.format
local CreateFrame = CreateFrame
local UIParent = UIParent
local InCombatLockdown = InCombatLockdown
local SetOverrideBindingClick = SetOverrideBindingClick
local ClearOverrideBindings = ClearOverrideBindings
local GetTime = GetTime

local CHECK_TEX = "Interface\\Buttons\\UI-CheckBox-Check"
local KEYWORDS = { "quicklist", "list" }
local HOLD_TICK = 0.05

local function Print(msg)
    if EasyFind.Print then EasyFind:Print(msg) end
end





local function RowData(item)
    local live = ns.Aliases and ns.Aliases:FindEntryByKey(item.k)
    if live then return live end
    if item.d then return item.d end
    return { name = item.n or item.k, category = "Quicklist", quicklistMissing = true, noPin = true }
end

function Quicklists:BuildSearchData()
    local out = {}
    local path = { L["FILTER_QUICKLISTS"] }
    local lists = Store.All()
    for i = 1, #lists do
        local list = lists[i]
        out[#out + 1] = {
            name = list.name, nameLower = slower(list.name), category = "Quicklist",
            path = path, keywords = KEYWORDS, quicklistID = list.id,
            searchCommandDesc = L["QUICKLIST_SUBTEXT"],
        }
    end
    return out
end



local pills = {}

local function Pill(list)
    local def = pills[list.id]
    if not def then
        def = { key = "quicklist", canonical = "quicklist", categories = { "Quicklist" },
                quicklistID = list.id, aliases = {} }
        pills[list.id] = def
    end
    def.label, def.token, def.displayToken, def.aliasText = list.name, list.name, list.name, list.name
    return def
end

local openedBar = {}

local function BarShown()
    local sf = ns.Search and ns.Search:GetSearchFrame()
    return sf ~= nil and sf:IsShown() and (sf:GetAlpha() or 1) > 0.01
end



function Quicklists:ResolveToken(token)
    local found, matches = nil, 0
    for _, list in ipairs(Store.All()) do
        if list.name and list.name:lower():find(token, 1, true) == 1 then
            found, matches = list, matches + 1
        end
    end
    if matches == 1 then return Pill(found) end
    return nil
end

function Quicklists:IsOpen(id)
    local qf = ns.Filters and ns.Filters:GetQuickFilter()
    if not (qf and qf.quicklistID == id) then return false end
    local rf = ns.Search and ns.Search:GetResultsFrame()
    return rf ~= nil and rf:IsShown()
end

function Quicklists:Open(id)
    local list = Store.Get(id)
    if not list or InCombatLockdown() then return false end
    local Search = ns.Search
    local wasShown = BarShown()
    Search:Show(false)
    local sf = Search:GetSearchFrame()
    if not (sf and sf:IsShown()) then return false end
    openedBar[id] = not wasShown
    ns.Filters:ApplyQuickFilter(Pill(list), "")


    local base = list.key and list.key:match("([^%-]+)$")
    if base and #base == 1 and sf.editBox then Utils.SwallowNextCharInsert(sf.editBox, base, list.hold and 30 or true) end
    return true
end



function Quicklists:OpenSoon(id)
    Utils.SafeAfter(0, function() Quicklists:Open(id) end)
end

function Quicklists:Close(id)
    ns.Filters:ClearQuickFilter(false)
    ns.Results:HideResults()
    if id and openedBar[id] then
        openedBar[id] = nil
        if BarShown() then ns.Search:Hide() end
    end
end

function Quicklists:Toggle(id)
    if self:IsOpen(id) then self:Close(id) else self:Open(id) end
end

local entries = {}

local function SetEntry(n, name, data)
    local e = entries[n] or {}
    entries[n] = e
    e.name, e.depth, e.isPathNode, e.isMatch, e.isPinned, e.isFlat, e.data = name, 0, false, true, false, true, data
end

function Quicklists:ShowView(id, text)
    local list = Store.Get(id)
    local Results = ns.Results
    if not list then
        Results:HideResults()
        return
    end
    local q = text and text ~= "" and slower(text) or nil
    local n = 0
    for i = 1, #list.items do
        local item = list.items[i]
        local data = RowData(item)
        local name = data.name or item.n or ""
        if not q or sfind(slower(name), q, 1, true) then
            n = n + 1
            SetEntry(n, name, data)
        end
    end
    if n == 0 then
        n = 1
        local hint = #list.items == 0 and L["QUICKLIST_EMPTY"] or L["QUICKLIST_NO_MATCH"]
        SetEntry(1, hint, { name = hint, category = "Quicklist", quicklistHint = true, noPin = true })
    end
    for i = n + 1, #entries do entries[i] = nil end
    Results:ShowHierarchicalResults(entries)
end



local owner
local buttons = {}
local armed = false
local hold

local function HoveredData()
    local rows = ns.Search:GetResultButtons()
    for i = 1, #rows do
        local row = rows[i]
        if row:IsShown() and row.data and not row.isSectionHeader and row:IsMouseOver() then
            return row.data
        end
    end
    return nil
end

local function Actionable(data)
    return data ~= nil and not data.quicklistMissing and not data.quicklistHint
end

local function Disarm(b)
    ns.ResultSecureAttributes.Clear(b)
    b:SetAttribute("typerelease", nil)
    b:SetAttribute("pressAndHoldAction", nil)
    b._quicklistSecure = nil
end





local function Arm(b, data)
    local secure = ns.ResultIcons:IsSecureActionResult(data)
        and not (ns.SecureOpeners and ns.SecureOpeners.OpenKeyForData(data))
        and not (data.settingVariable and ns.ResultRows.IsBarToggle(data.settingVariable))
    if not secure then
        Disarm(b)
        return
    end
    ns.ResultSecureAttributes.ApplyAtClick(b, data)
    b:SetAttribute("pressAndHoldAction", true)
    b:SetAttribute("typerelease", b:GetAttribute("type"))
    b._quicklistSecure = true
end

local function HoldTick(self)
    if not hold then
        Utils.SafeOnUpdate(self, nil)
        return
    end
    local now = GetTime()
    if now - hold.lastTick < HOLD_TICK then return end
    hold.lastTick = now
    local data = HoveredData()
    if data == hold.hovered then return end
    hold.hovered = data
    if InCombatLockdown() then return end
    if Actionable(data) then Arm(hold.button, data) else Disarm(hold.button) end
end

local function EndHold()
    local h = hold
    hold = nil
    if owner then Utils.SafeOnUpdate(owner, nil) end

    local sf = h and ns.Search and ns.Search:GetSearchFrame()
    if sf and sf.editBox then sf.editBox._efSwallowChar = nil end
    return h
end


local function Fire(data)
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

local function OnPreClick(b, _, down)
    if not down or InCombatLockdown() then return end
    local id = b._quicklistID
    local list = id and Store.Get(id)
    if not list then return end
    if list.hold then
        EndHold()
        Disarm(b)
        if Quicklists:Open(id) then
            hold = { id = id, button = b, lastTick = 0 }
            Utils.SafeOnUpdate(owner, HoldTick)
        end
        return
    end
    Quicklists:Toggle(id)
end

local function OnPostClick(b, _, down)
    if down then return end
    local h = EndHold()
    if not (h and h.button == b) or InCombatLockdown() then return end
    local data = h.hovered
    if Actionable(data) then
        if b._quicklistSecure then
            ns.ResultHandlers:FinishResultSelection()
        else
            Fire(data)
        end
    end
    Disarm(b)
end

local function EnsureOwner()
    if owner then return owner end
    owner = CreateFrame("Frame", "EasyFindQuicklistOwner", UIParent)
    owner:SetSize(1, 1)
    owner:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    owner:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then

            EndHold()
            if armed then
                ClearOverrideBindings(self)
                armed = false
            end
            return
        end
        Quicklists:ApplyBindings()
    end)
    owner:RegisterEvent("PLAYER_REGEN_DISABLED")
    owner:RegisterEvent("PLAYER_REGEN_ENABLED")
    owner:RegisterEvent("PLAYER_ENTERING_WORLD")
    return owner
end

local function GetButton(i)
    if buttons[i] then return buttons[i] end

    local b = CreateFrame("Button", "EasyFindQuicklistButton" .. i, owner, "SecureActionButtonTemplate")
    b:SetSize(1, 1)
    b:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", 0, 0)
    b:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    b:SetScript("PreClick", OnPreClick)
    b:SetScript("PostClick", OnPostClick)
    buttons[i] = b
    return b
end

function Quicklists:ApplyBindings()
    if not (EasyFind and EasyFind.db) then return end
    EnsureOwner()
    if InCombatLockdown() then return end
    if armed then
        ClearOverrideBindings(owner)
        armed = false
    end
    local lists = Store.All()
    local n = 0
    for i = 1, #lists do
        local list = lists[i]
        if list.key and list.key ~= "" then
            n = n + 1
            local b = GetButton(n)
            b._quicklistID = list.id
            Disarm(b)
            SetOverrideBindingClick(owner, true, list.key, b:GetName(), "LeftButton")
            armed = true
        end
    end
    for i = n + 1, #buttons do buttons[i]._quicklistID = nil end
end

function Quicklists:KeyOf(id)
    local list = Store.Get(id)
    return list and list.key or nil
end


function Quicklists:KeyOwnerName(combo, excludeID)
    local list = Store.KeyOwner(combo)
    if list and list.id ~= excludeID then return list.name end
    return nil
end

function Quicklists:PromptForKey(id, onDone)
    local list = Store.Get(id)
    if not (list and ns.Shortkeys and ns.Shortkeys.PromptForCombo) then return end
    ns.Shortkeys:PromptForCombo(sformat(L["QUICKLIST_KEY_FOR"], list.name), list.key,
        function(combo)
            Store.SetKey(id, combo)
            Quicklists:Changed()
            if onDone then onDone() end
        end,
        function()
            Store.SetKey(id, nil)
            Quicklists:Changed()
            if onDone then onDone() end
        end, id, function() Quicklists:CreateMacro(id) end)
end


function Quicklists:CreateMacro(id)
    local list = Store.Get(id)
    if list and ns.Shortkeys then ns.Shortkeys:CreateMacro("quicklist:" .. tostring(id), list.name, nil, id) end
end




function Quicklists:Changed()
    EasyFind.API.RefreshSearchProvider("quicklists")
    self:ApplyBindings()
    if ns.Options and ns.Options.RefreshQuicklistsPage then ns.Options:RefreshQuicklistsPage() end
    local qf = ns.Filters and ns.Filters:GetQuickFilter()
    if not (qf and qf.quicklistID) then return end
    local list = Store.Get(qf.quicklistID)
    if not list then
        self:Close(qf.quicklistID)
        return
    end
    Pill(list)
    ns.Filters:UpdateQuickFilterPill()
    ns.Search:OnSearchTextChanged(ns.Search:GetTypedQuery(), true)
end



function Quicklists:PromptNew(onCreated)
    local key
    local unbound = L["SHORTKEY_CLICK_TO_BIND"]
    ns.ShowThemedDialog({
        text = L["QUICKLIST_NEW_PROMPT"],
        hasEditBox = true,
        maxLetters = Store.NAME_MAX,
        acceptText = L["QUICKLIST_CREATE"],
        extraButton = { label = L["QUICKLIST_COL_KEY"], text = unbound, setup = function(btn)
            if not (ns.Shortkeys and ns.Shortkeys.AttachComboCapture) then return end
            ns.Shortkeys:AttachComboCapture(btn, function() return key end,
                function(combo) key = combo end, function() key = nil end)
        end },
        checkText = L["QUICKLIST_HOLD_CHECK"],
        checkTooltip = L["QUICKLIST_HOLD_CHECK_TT"],
        onAccept = function(value, hold)
            local name = Store.CleanName(value)
            if not name then return end
            if Store.FindByName(name) then
                Print(sformat(L["QUICKLIST_NAME_TAKEN_FMT"], name))
                return
            end
            local list = Store.Create(name)
            if list then
                if key then Store.SetKey(list.id, key) end
                if hold then Store.SetHold(list.id, true) end
            end
            if list and onCreated then onCreated(list) end
            Quicklists:Changed()
        end,
    })
end

function Quicklists:PromptRename(id)
    local list = Store.Get(id)
    if not list then return end
    ns.ShowThemedDialog({
        text = sformat(L["QUICKLIST_RENAME_PROMPT"], list.name),
        hasEditBox = true,
        editBoxDefault = list.name,
        maxLetters = Store.NAME_MAX,
        acceptText = _G["SAVE"] or "Save",
        onAccept = function(value)
            local name = Store.CleanName(value)
            if not name then return end
            local taken = Store.FindByName(name)
            if taken and taken ~= list then
                Print(sformat(L["QUICKLIST_NAME_TAKEN_FMT"], name))
                return
            end
            Store.Rename(id, name)
            Quicklists:Changed()
        end,
    })
end

function Quicklists:DeleteWithConfirm(id)
    local list = Store.Get(id)
    if not list then return end
    ns.ShowThemedDialog({
        text = sformat(L["QUICKLIST_DELETE_CONFIRM"], list.name),
        acceptText = _G["DELETE"] or "Delete",
        onAccept = function()
            if Quicklists:IsOpen(id) then Quicklists:Close(id) end
            Store.Delete(id)
            Quicklists:Changed()
        end,
    })
end





function Quicklists:BuildAddRows(data)
    local rowKey = Store.ItemKey(data)
    if not rowKey then return nil end
    local rows = {}
    local lists = Store.All()
    for i = 1, #lists do
        local list = lists[i]
        local id = list.id
        local member = Store.IndexOf(list, rowKey) ~= nil
        rows[#rows + 1] = {
            text = list.name,
            icon = member and CHECK_TEX or nil,
            onClick = function()
                local current = Store.Get(id)
                if not current then return end
                if Store.Has(id, rowKey) then
                    Store.Remove(id, rowKey)
                elseif not Store.Add(id, data) then
                    Print(sformat(L["QUICKLIST_FULL_FMT"], current.name))
                end
                Quicklists:Changed()
            end,
        }
    end
    if #rows > 0 then rows[#rows + 1] = { isSeparator = true } end
    rows[#rows + 1] = {
        text = L["QUICKLIST_NEW"],
        onClick = function()
            Quicklists:PromptNew(function(list)
                Store.Add(list.id, data)
            end)
        end,
    }
    return rows
end




EasyFind.API.RegisterExtension({
    id = "quicklists", name = L["FILTER_QUICKLISTS"], description = L["APP_DESC_QUICKLISTS"],
    icon = ns.QUICKLIST_ICON_TEX,
    open = function() EasyFind.API.OpenSettings("quicklists") end,
    isOpen = function() return EasyFind.API.IsSettingsOpen("quicklists") end,
    close = EasyFind.API.CloseSettings,
})


EasyFind.API.RegisterSearchProvider({
    key = "quicklists", category = "Quicklist", extension = "quicklists",
    label = L["FILTER_QUICKLISTS"], icon = ns.QUICKLIST_ICON_TEX,
    eager = true, aliases = { "ql", "quicklist", "quicklists" },
    rows = function() return Quicklists:BuildSearchData() end,
    select = function(row) if row.quicklistID then Quicklists:OpenSoon(row.quicklistID) end end,
})



local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Quicklists:ApplyBindings()
end)

return Quicklists
