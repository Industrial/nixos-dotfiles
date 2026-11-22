local _, ns = ...

local Utils = ns.Utils
local L = ns.L
local slower, sfind = Utils.slower, Utils.sfind
local GetMapInfo = C_Map and C_Map.GetMapInfo
local ZONE_TYPE = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3




local API = { VERSION = 1, MINOR = 13 }
EasyFind.API = API

local Extensions = { byID = {}, order = {} }
ns.Extensions = Extensions



local RESERVED = { menu = true }



local LEGACY_FLAGS = {
    calculatorLauncher = "calculator", iconSearchLauncher = "icons", snippetsLauncher = "snippets",
    clipboardLauncher = "clipboard", notesLauncher = "notes", gpsLauncher = "gps",
    quicklistsLauncher = "quicklists", chatLauncher = "chat",
}
Extensions.LEGACY_FLAGS = LEGACY_FLAGS

local FIELDS = {
    id = "string", name = "string", description = "string", icon = "texture", iconCoords = "table",
    addon = "string", loadInCombat = "boolean", loadAtLogin = "boolean", open = "function", close = "function",
    isOpen = "function", menu = "function", settings = "function", settingsRows = "function",
    resetSettings = "function", keywords = "table",
    hideFromSearch = "boolean", experimental = "string", scope = "string",
}

local function Fail(fn, msg) error("EasyFind.API." .. fn .. ": " .. msg, 3) end

local function Report(err) return geterrorhandler()(err) end



local function Run(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, result = xpcall(fn, Report, ...)
    return ok, result
end
Extensions.Run = Run




local function RunRows(fn)
    if type(fn) ~= "function" then return false end
    local co = coroutine.create(fn)
    while true do
        local ok, result = coroutine.resume(co)
        if not ok then

            local hasStack, stack = pcall(debugstack, co)
            Report(tostring(result) .. (hasStack and type(stack) == "string" and ("\n" .. stack) or ""))
            return false
        end
        if coroutine.status(co) == "dead" then return true, result end
        Utils.SliceYield()
    end
end


function API.SliceCheckpoint()
    Utils.SliceCheckpoint()
end

local function CheckFields(fn, def)
    for k, v in pairs(def) do
        local want = FIELDS[k]
        if want == "texture" then
            if type(v) ~= "string" and type(v) ~= "number" then Fail(fn, "icon must be a texture path or file id") end
        elseif want and type(v) ~= want then
            Fail(fn, k .. " must be a " .. want)
        end
    end
end

local function RefreshSurfaces()
    if ns.AppsMenu and ns.AppsMenu.Rebuild then ns.AppsMenu:Rebuild() end
    if ns.ExtensionButtons and ns.ExtensionButtons.RefreshAll then ns.ExtensionButtons:RefreshAll() end
end

function Extensions.Get(id) return id and Extensions.byID[id] or nil end


function Extensions.Available(def)
    if not def or not def.name then return false end
    return not def.addon or not ns.IsCompanionLoadable or ns.IsCompanionLoadable(def.addon) or false
end



function Extensions.Entry(id)
    local def = Extensions.byID[id]
    if not def then return nil end
    local entry = def._entry
    if not entry then
        entry = {
            extensionID = id, noPin = true, noLearn = true,
            nativeRun = function() Extensions.Launch(id) end,
        }
        def._entry = entry
    end
    entry.name, entry.nameLower = def.name, def.name and slower(def.name)
    entry.icon, entry.iconCoords = def.icon, def.iconCoords
    entry.experimental = def.experimental


    entry.path = def._path
    return entry
end

function Extensions.Entries()
    local out = {}
    for _, id in ipairs(Extensions.order) do
        local def = Extensions.byID[id]
        if Extensions.Available(def) then out[#out + 1] = Extensions.Entry(id) end
    end
    return out
end





local function StartsWord(hay, q)
    return hay:sub(1, #q) == q or sfind(hay, " " .. q, 1, true) ~= nil
end
Extensions.StartsWord = StartsWord

function Extensions.LauncherMatches(text, out)
    if not text or #text < 3 then return out end
    local q = slower(text)
    for _, id in ipairs(Extensions.order) do
        local def = Extensions.byID[id]
        if not def.hideFromSearch and Extensions.Available(def) then
            local hit = def.name and StartsWord(slower(def.name), q)
            for i = 1, def.keywords and #def.keywords or 0 do
                hit = hit or StartsWord(slower(def.keywords[i]), q)
            end
            if hit then out[#out + 1] = Extensions.Entry(id) end
        end
    end
    return out
end

local function QuickFilterKey()
    local Filters = ns.Filters
    local qf = Filters and Filters.GetQuickFilter and Filters:GetQuickFilter()
    local rf = ns.Search and ns.Search.GetResultsFrame and ns.Search:GetResultsFrame()
    return qf and rf and rf:IsShown() and qf.key or nil
end

function Extensions.IsOpen(id)
    local def = Extensions.byID[id]
    if not def then return false end
    if def.isOpen then
        local ok, open = Run(def.isOpen)
        return ok and open and true or false
    end
    if def.scope then return QuickFilterKey() == def.scope end
    if def.settings then return API.IsSettingsOpen(id) end
    return false
end

function Extensions.Close(id)
    local def = Extensions.byID[id]
    if not def then return end
    if def.close then Run(def.close) return end
    if def.scope then
        if ns.Filters and ns.Filters.ClearQuickFilter then ns.Filters:ClearQuickFilter(false) end
        if ns.Results and ns.Results.HideResults then ns.Results:HideResults() end
        return
    end
    if def.settings then API.CloseSettings() end
end



function Extensions.ScopeShowing()
    local key = QuickFilterKey()
    if not key then return nil end
    for _, id in ipairs(Extensions.order) do
        if Extensions.byID[id].scope == key then return id end
    end
    return nil
end


local function LoadAddon(def)
    if not (def and def.addon and C_AddOns and C_AddOns.LoadAddOn) then return end
    if C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(def.addon) then return end
    if InCombatLockdown() and not def.loadInCombat then return end
    xpcall(C_AddOns.LoadAddOn, Report, def.addon)
end



function Extensions.Load(id)
    local def = Extensions.byID[id]
    if not def then return false end


    if not (def.open or def.scope) and def.addon and not (InCombatLockdown() and not def.loadInCombat) then
        LoadAddon(def)
        def = Extensions.byID[id]
    end
    if def.open or def.settings or def.scope then return true end
    if not def.addon or (InCombatLockdown() and not def.loadInCombat) then return false end
    local title = C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(def.addon, "Title") or def.addon
    EasyFind:Print(L["COMPANION_INCOMPLETE_FMT"]:format(title))
    return false
end



function Extensions.LoadAtLogin()
    for _, id in ipairs(Extensions.order) do
        local def = Extensions.byID[id]
        if def.loadAtLogin and Extensions.Available(def) then LoadAddon(def) end
    end
end

function Extensions.Launch(id)
    local def = Extensions.byID[id]

    if def and InCombatLockdown() and not def.loadInCombat then
        EasyFind:Print(_G["ERR_NOT_IN_COMBAT"] or "")
        return false
    end
    if not Extensions.Load(id) then return false end
    def = Extensions.byID[id]
    if def.open then return (Run(def.open)) end

    if def.scope then return API.ShowScope(def.scope) end
    if def.settings then return API.OpenSettings(id) end
    return false
end



local kitNames = 0
local function Kit(ctx)
    local kit = { ROW_WIDTH = ctx.SELECTOR_ROW_W, BUTTON_WIDTH = ctx.SELECTOR_BTN_W }

    local fonts = ctx.Fonts or {}
    local function Font(name) return fonts[name] or name end
    kit.Font = Font

    function kit.Title(parent, title, hint)
        local head = parent:CreateFontString(nil, "OVERLAY", Font("GameFontNormal"))
        head:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
        head:SetText(title)
        if not hint then return head end
        local line = parent:CreateFontString(nil, "OVERLAY", Font("GameFontHighlightSmall"))
        line:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
        line:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
        line:SetJustifyH("LEFT")
        line:SetText(hint)
        return line
    end

    local function Read(get)
        return function()
            local _, value = Run(get)
            return value
        end
    end


    function kit.Checkbox(parent, label, get, set, tooltip, width)
        local box = ctx.CreateCheckbox(parent, nil, label, tooltip, true, width or ctx.SELECTOR_ROW_W,
            not width and (ctx.SELECTOR_ROW_W - 8 - ctx.SELECTOR_BTN_W) or nil)
        box:SetChecked(Read(get)() and true or false)
        if box.RefreshVisual then box:RefreshVisual() end
        box:SetScript("OnClick", function(self)
            if self.RefreshVisual then self:RefreshVisual() end
            Run(set, self:GetChecked() and true or false)
        end)
        return box
    end
    function kit.Choice(parent, label, choices, get, set, tooltip, default)
        kitNames = kitNames + 1

        local list = {}
        for i, c in ipairs(choices) do
            list[i] = c.disabled and { label = c.label, value = c.value, disabled = Read(c.disabled) } or c
        end
        return ctx.CreateFlyoutPresetRow(parent, label, list, Read(get), function(v) Run(set, v) end,
            "EasyFindExtChoice" .. kitNames, default, tooltip)
    end
    function kit.Stepper(parent, label, min, max, step, get, set, tooltip, width)
        return ctx.CreateStepperRow(parent, label, min, max, Read(get), function(v) Run(set, v) end, tooltip, width, step)
    end




    function kit.Keybind(parent, label, action, tooltip)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(ctx.SELECTOR_ROW_W, 24)
        local text = row:CreateFontString(nil, "OVERLAY", Font("GameFontHighlightSmall"))
        text:SetPoint("LEFT", row, "LEFT", 8, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -ctx.SELECTOR_BTN_W - 18, 0)
        text:SetJustifyH("LEFT")
        text:SetText(label)
        local btn = ns.CreateModernButton(row)
        btn:SetNormalFontObject(Font("GameFontHighlightSmall"))
        btn:SetHighlightFontObject(Font("GameFontHighlightSmall"))
        btn:SetSize(ctx.SELECTOR_BTN_W, 22)
        btn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        btn:SetText(ctx.GetCurrentKeybindText(action))
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetScript("OnClick", function(self, button)

            if ns._efFlyoutClosedAt and GetTime() - ns._efFlyoutClosedAt < 0.30 then return end
            if button == "RightButton" then
                EasyFind:SetAccountKeybind(action, nil)
                self:SetText(_G["NOT_BOUND"] or "Not Bound")
            else
                ctx.StartCapture(self, action)
            end
        end)
        if tooltip then ctx.MakeKeybindTooltip(btn, label, tooltip) end
        row.button = btn
        return row
    end

    function kit.Button(parent, text, width, height)
        local make = ctx.CreateButton or ns.CreateModernButton
        return make(parent, text, width or 120, height or 22)
    end
    return kit
end














function API.RegisterExtension(def)
    if type(def) ~= "table" then Fail("RegisterExtension", "expects a table") end
    local id = def.id
    if type(id) ~= "string" or not id:match("^[%w_%-]+$") then
        Fail("RegisterExtension", "id must be letters, digits, - or _")
    end
    if RESERVED[id] then Fail("RegisterExtension", "id '" .. id .. "' is taken by EasyFind") end
    CheckFields("RegisterExtension", def)
    local rec = Extensions.byID[id]
    if not rec then
        if type(def.name) ~= "string" then Fail("RegisterExtension", "name is required") end
        if def.icon == nil then Fail("RegisterExtension", "icon is required") end
        rec = {}
        Extensions.byID[id] = rec
        Extensions.order[#Extensions.order + 1] = id
    end
    for k, v in pairs(def) do rec[k] = v end
    if def.settings and ns.RegisterExtensionPage then
        ns.RegisterExtensionPage({
            id = id, name = rec.name, icon = rec.icon, coords = rec.iconCoords, companion = rec.addon,
            build = function(page, ctx) Run(rec.settings, page, Kit(ctx)) end,
            reset = rec.resetSettings and function() Run(rec.resetSettings) end or nil,
        })
    end
    if def.settingsRows and ns.SettingsRows then
        ns.SettingsRows.AddExtension(id, rec.name, rec.settingsRows)
    end
    RefreshSurfaces()
    return true
end

function API.IsExtensionRegistered(id) return Extensions.byID[id] ~= nil end

function API.OpenExtension(id) return Extensions.Launch(id) end
function API.CloseExtension(id) Extensions.Close(id) end
function API.IsExtensionOpen(id) return Extensions.IsOpen(id) end

function API.ToggleExtension(id)
    if Extensions.IsOpen(id) then
        Extensions.Close(id)
        return false
    end
    return Extensions.Launch(id)
end



function API.NotifyOpenChanged(id)
    if ns.ExtensionButtons and ns.ExtensionButtons.RefreshOpenStates then ns.ExtensionButtons:RefreshOpenStates() end
end


function API.SetBadge(id, count)
    if ns.SetApplicationBadge then ns.SetApplicationBadge(id, count) end
end



local Providers = { byKey = {}, byCategory = {}, byExtension = {} }
Extensions.Providers = Providers






local function ProviderSwitch(p)
    return {
        label = p.label,
        get = function() return EasyFind.db.uiSearchFilters[p.key] ~= false end,
        set = function(on)
            EasyFind.db.uiSearchFilters[p.key] = on
            ns.Filters:RerunActiveSearch()
        end,
    }
end

local function JoinFilterRow(owner, p)
    local group = Providers.byExtension[owner.id]
    local isNew = not group
    if isNew then
        group = { providers = {}, row = { glyph = true } }
        Providers.byExtension[owner.id] = group
    end
    local list, row = group.providers, group.row
    list[#list + 1] = p
    row.label, row.iconTex, row.iconCoords = owner.name, owner.icon, owner.iconCoords
    if #list == 1 then
        row.key, row.checkboxOptions = p.key, p.options
    else

        row.key = "ext." .. owner.id
        ns.CategoryMap.AddGroup(row.key, "extensions")
        local opts = {}
        for i = 1, #list do
            list[i].categoryEntry.parent = row.key
            opts[i] = ProviderSwitch(list[i])
        end
        for i = 1, #list do
            local more = list[i].options
            if more then
                opts[#opts + 1] = { separator = true }
                opts[#opts + 1] = { header = list[i].label }
                for j = 1, #more do opts[#opts + 1] = more[j] end
            end
        end
        row.checkboxOptions = opts
    end
    row.hasOptions = row.checkboxOptions ~= nil
    if isNew then ns.Filters.AddExtensionFilter(row) end
end

local PROVIDER_FIELDS = {
    key = "string", label = "string", category = "string", icon = "texture", iconCoords = "table", iconWell = "boolean",
    words = "table", eager = "boolean", lazy = "boolean", lowResults = "boolean",
    aliases = "table", options = "table", rows = "function", select = "function", tooltip = "function",
    leave = "function", extension = "string", loadOnSearch = "any", hint = "any", browse = "function",
    place = "function", places = "function", link = "table", menu = "function",
}

function Extensions.Provider(key) return key and Providers.byKey[key] or nil end
function Extensions.ProviderOf(data) return data and data.category and Providers.byCategory[data.category] or nil end




local placedRows = setmetatable({}, { __mode = "k" })

local function Populate(key, database)
    local p = Providers.byKey[key]
    if not p.rows and p.extension then
        local load = p.loadOnSearch
        if type(load) == "function" then
            local ok, want = Run(load)
            load = ok and want
        end
        if load then Extensions.Load(p.extension) end
    end
    local rows
    if p.rows then
        local ok, got = RunRows(p.rows)
        rows = ok and type(got) == "table" and got or nil
    end


    local scopedName = false
    for i = 1, rows and #rows or 0 do

        if i % 64 == 0 then Utils.SliceCheckpoint() end
        local row = rows[i]
        row.category = p.category
        if not row.nameLower and type(row.name) == "string" then row.nameLower = slower(row.name) end
        if row.keywords and not row.keywordsLower then
            local low = {}
            for k = 1, #row.keywords do low[k] = slower(tostring(row.keywords[k])) end
            if database.AddInstanceAbbrs then database.AddInstanceAbbrs(low) end
            row.keywordsLower = low
        end


        local place = type(row.mapID) == "number" and ns.MapUtils and ns.MapUtils.ZoneWords(row.mapID)
        if place and #place > 0 then
            local was = placedRows[row]
            local own = row.keywordsLower
            if was and was.low == own then own = was.own end
            local low = {}
            for k = 1, own and #own or 0 do low[k] = own[k] end
            for k = 1, #place do low[#low + 1] = place[k] end
            row.keywordsLower = low
            placedRows[row] = { own = own, low = low }
        end
        if row.scopedName then scopedName = true end
    end
    return database:ReplaceCategoryEntries(p.category, rows, scopedName)
end


function Extensions.DbOption(key, label, tooltip, onChange)
    return {
        label = label, tooltip = tooltip,
        get = function() return EasyFind.db[key] ~= false end,
        set = function(on)
            EasyFind.db[key] = on
            if onChange then onChange(on) end
        end,
    }
end



function Extensions.SelectRow(data, finish)
    local p = Extensions.ProviderOf(data)
    if not p then return false end
    if not p.select and p.extension then Extensions.Load(p.extension) end
    if not p.select then return false end
    local row = {}
    for k, v in pairs(data) do row[k] = v end
    finish()
    Run(p.select, row)
    return true
end






























function API.RegisterSearchProvider(def)
    if type(def) ~= "table" then Fail("RegisterSearchProvider", "expects a table") end
    local key = def.key
    if type(key) ~= "string" or not key:match("^[%w_%-]+$") then
        Fail("RegisterSearchProvider", "key must be letters, digits, - or _")
    end
    for k, v in pairs(def) do
        local want = PROVIDER_FIELDS[k]
        if want == "texture" then
            if type(v) ~= "string" and type(v) ~= "number" then Fail("RegisterSearchProvider", "icon must be a texture path or file id") end
        elseif want and want ~= "any" and type(v) ~= want then
            Fail("RegisterSearchProvider", k .. " must be a " .. want)
        end
    end
    if def.link and not (type(def.link.key) == "function" and type(def.link.resolve) == "function") then
        Fail("RegisterSearchProvider", "link needs key(row) and resolve(tail) functions")
    end
    local p = Providers.byKey[key]
    if p then
        for k, v in pairs(def) do
            if k ~= "category" then p[k] = v end
        end
    else
        if type(def.label) ~= "string" then Fail("RegisterSearchProvider", "label is required") end

        if def.extension == nil then Fail("RegisterSearchProvider", "extension is required") end
        local owner = Extensions.Get(def.extension)
        if not owner then
            Fail("RegisterSearchProvider", "extension '" .. def.extension .. "' must be registered first")
        end


        if not Extensions.Available(owner) then return false end
        local category = def.category or key
        if ns.CategoryMap.ProviderCategory[key] or Providers.byCategory[category] then
            Fail("RegisterSearchProvider", "key '" .. key .. "' is taken")
        end
        p = {}
        for k, v in pairs(def) do p[k] = v end
        if p.icon == nil then p.icon, p.iconCoords = owner.icon, owner.iconCoords end
        p.category = category
        Providers.byKey[key], Providers.byCategory[category] = p, p
        p.categoryEntry = { key = key, parent = "extensions", categories = { category } }
        ns.CategoryMap.Add(p.categoryEntry)
        ns.Database:AddDynamicProvider({
            key = key, category = category, eager = p.eager, lazy = p.lazy,
            fn = function(database) return Populate(key, database) end,
        })
        ns.SearchEngine:AddProvider({ key = key, words = p.words or {}, loadOnLowResults = p.lowResults })
        JoinFilterRow(owner, p)
        if p.aliases then
            local scope = { key = key, canonical = key, label = p.label, categories = { category }, aliases = p.aliases,
                            extension = owner.id }
            if ns.Filters:AddQuickFilter(scope) then
                p.scope = scope
            else
                local held = Extensions.Decorators.scopes[key]
                if held and held.extension == owner.id then p.scope = held end
            end

            local d = p.scope and Extensions.DecoratorOf(key, owner.id)
            if d then Extensions.JoinScope(p.scope, d, { category }, p.aliases) end
        end
    end
    p.glyph = { tex = p.icon, coords = p.iconCoords, chromeTint = true }


    if p.link and ns.Aliases and ns.Aliases.RegisterKeyResolver then
        ns.Aliases:RegisterKeyResolver(key, function(full)
            local link = p.link
            if not link then return nil end
            local ok, row = Run(link.resolve, full:sub(#key + 2))
            if not (ok and type(row) == "table") then return nil end
            if row.category == nil then row.category = p.category end
            return row
        end)
    end
    return true
end



function API.ShowPlaces(key, row)
    local p = Providers.byKey[key]
    if not (p and type(row) == "table" and ns.MapSearch and ns.MapSearch.ShowProviderPlaces) then return false end
    return ns.MapSearch:ShowProviderPlaces(p, row)
end




function API.OpenMap(mapID)
    if not (ns.MapSearch and ns.MapSearch.TurnMap) then return false end
    return ns.MapSearch.TurnMap(mapID)
end











local AddTargets = {}
Extensions.AddTargets = AddTargets
local ADD_TARGET_FIELDS = {
    key = "string", extension = "string", label = "string", fullLabel = "string",
    applies = "function", rows = "function", onClick = "function", new = "function", newLabel = "string",
}
function API.RegisterAddTarget(def)
    if type(def) ~= "table" then Fail("RegisterAddTarget", "expects a table") end
    for k, v in pairs(def) do
        local want = ADD_TARGET_FIELDS[k]
        if want and type(v) ~= want then Fail("RegisterAddTarget", k .. " must be a " .. want) end
    end
    for _, k in ipairs({ "key", "extension", "label", "rows" }) do
        if def[k] == nil then Fail("RegisterAddTarget", k .. " is required") end
    end
    if def.new and not def.newLabel then Fail("RegisterAddTarget", "newLabel is required with new") end
    local owner = Extensions.Get(def.extension)
    if not (owner and owner.icon) then
        Fail("RegisterAddTarget", "extension '" .. def.extension .. "' must be registered first, with its icon")
    end
    for i = 1, #AddTargets do
        if AddTargets[i].key == def.key then
            AddTargets[i] = def
            return true
        end
    end
    AddTargets[#AddTargets + 1] = def
    return true
end



local mapAndZone = {}
local function MapAndZone(mapID)
    wipe(mapAndZone)
    mapAndZone[mapID] = true
    local info = GetMapInfo and GetMapInfo(mapID)
    for _ = 1, 6 do
        if not (info and info.mapType and info.mapType > ZONE_TYPE and info.parentMapID) then break end
        info = GetMapInfo(info.parentMapID)
        if info then mapAndZone[info.mapID] = true end
    end
    return mapAndZone
end























local Decorators = { list = {}, bySlot = {}, generation = 0, scopes = {}, candidates = {} }
Extensions.Decorators = Decorators
local DECORATOR_FIELDS = {
    id = "string", extension = "string", slot = "string", label = "string", categories = "table",
    applies = "function", text = "function", tooltip = "function", menu = "function", subtext = "function",
    select = "function", hint = "function", keep = "function", sortKey = "function", submenu = "boolean",
    aliases = "table", browse = "function", candidates = "function", words = "function",
    modifiers = "boolean",
}





local function AddWords(index, got)
    for npcID, list in pairs(type(got.npc) == "table" and got.npc or {}) do
        if type(npcID) == "number" and type(list) == "table" then
            index.npc[npcID] = index.npc[npcID] or {}
            local into = index.npc[npcID]
            for _, w in ipairs(list) do
                local low = slower(tostring(w))
                into[#into + 1] = low
                index.byWord[low] = index.byWord[low] or {}
                index.byWord[low][npcID] = true
            end
        end
    end
    for key, list in pairs(type(got.name) == "table" and got.name or {}) do
        local name, mapID = string.match(type(key) == "string" and key or "", "^%s*(.-)%s*@(%d+)$")
        if name and name ~= "" and type(list) == "table" then
            local zones, words = {}, {}
            for m in pairs(MapAndZone(tonumber(mapID))) do zones[m] = true end
            for _, w in ipairs(list) do words[#words + 1] = slower(tostring(w)) end
            local low = slower(name)
            index.place[low] = index.place[low] or {}
            local entries = index.place[low]
            entries[#entries + 1] = { zones = zones, words = words }
        end
    end
end

local function WordsIndex()
    local index = Decorators.words
    if index and index.generation == Decorators.generation then return index end
    index = { generation = Decorators.generation, npc = {}, place = {}, byWord = {} }
    Decorators.words = index
    for _, d in ipairs(Decorators.list) do
        if d.words then
            local ok, got = Run(d.words)
            if ok and type(got) == "table" then AddWords(index, got) end
        end
    end
    return index
end


function Extensions.NpcWords(npcID)
    return WordsIndex().npc[npcID]
end


function Extensions.NpcsWithWord(word, into)
    for w, ids in pairs(WordsIndex().byWord) do
        if sfind(w, word, 1, true) then
            for npcID in pairs(ids) do into[npcID] = true end
        end
    end
    return into
end



function Extensions.PlaceWords(nameLower, mapID)
    local entries = WordsIndex().place[nameLower]
    if not (entries and mapID) then return nil end
    for m in pairs(MapAndZone(mapID)) do
        for i = 1, #entries do
            if entries[i].zones[m] then return entries[i].words end
        end
    end
    return nil
end

function API.UnregisterRowDecorator(id, slot)
    local list = Decorators.list
    for i = #list, 1, -1 do
        local d = list[i]
        if d.id == id and d.slot == slot then
            table.remove(list, i)
            if Decorators.bySlot[slot] == d then
                Decorators.bySlot[slot] = nil
                for j = 1, #list do
                    if list[j].slot == slot then Decorators.bySlot[slot] = list[j] break end
                end
            end
        end
    end
    Decorators.generation = Decorators.generation + 1
end


function Extensions.DecoratorOf(id, extension)
    local list = Decorators.list
    for i = #list, 1, -1 do
        if list[i].id == id and list[i].extension == extension then return list[i] end
    end
end


function Extensions.JoinScope(scope, def, categories, aliases)
    ns.Filters:JoinQuickFilter(scope, categories, aliases)
    scope.decorator = def
    Decorators.scopes[def.id] = scope
end



function API.RefreshRowDecorations()
    Decorators.generation = Decorators.generation + 1
    wipe(Decorators.candidates)
    if ns.Results and ns.Results.RefreshShownResults then ns.Results:RefreshShownResults(true) end
end



function API.RedrawRowTooltip()
    if ns.ResultRows and ns.ResultRows.RedrawHoveredTooltip then ns.ResultRows.RedrawHoveredTooltip() end
end





local Judge = { def = nil }
Extensions.Judge = Judge


function API.RefreshUpgrades()
    if ns.Upgrades and ns.Upgrades.Changed then ns.Upgrades.Changed() end
end

function API.RegisterUpgradeJudge(def)
    if type(def) ~= "table" then Fail("RegisterUpgradeJudge", "expects a table") end
    if type(def.rate) ~= "function" then Fail("RegisterUpgradeJudge", "rate must be a function") end
    local owner = Extensions.Get(def.extension or def.id)
    if not owner then
        Fail("RegisterUpgradeJudge", "extension '" .. tostring(def.extension or def.id) .. "' must be registered first")
    end
    def.extension = owner.id
    Judge.def = def
    API.RefreshUpgrades()
    return true
end

function API.UnregisterUpgradeJudge(extension)
    if not (Judge.def and Judge.def.extension == extension) then return end
    Judge.def = nil
    API.RefreshUpgrades()
end


function Judge.Rate(itemID, link)
    local def = Judge.def
    if not def then return nil end
    local ok, verdict = Run(def.rate, itemID, link)
    if not ok or verdict == nil then return nil end
    if verdict == false or verdict == true then return verdict end
    return type(verdict) == "number" and verdict or nil
end








function API.RegisterItemSources(id, fn)
    if type(id) ~= "string" or id == "" then Fail("RegisterItemSources", "id must be a string") end
    if type(fn) ~= "function" then Fail("RegisterItemSources", "fn must be a function") end
    local owner = Extensions.Get(id)
    if not owner then Fail("RegisterItemSources", "extension '" .. tostring(id) .. "' must be registered first") end
    if not ns.ItemSources then return false end
    ns.ItemSources.Register(owner.id, owner.name, fn)
    return true
end

function API.RegisterRowDecorator(def)
    if type(def) ~= "table" then Fail("RegisterRowDecorator", "expects a table") end
    for k, v in pairs(def) do
        local want = DECORATOR_FIELDS[k]
        if want and type(v) ~= want then Fail("RegisterRowDecorator", k .. " must be a " .. want) end
    end
    if type(def.id) ~= "string" then Fail("RegisterRowDecorator", "id is required") end
    local owner = Extensions.Get(def.extension or def.id)
    if not (owner and owner.icon) then
        Fail("RegisterRowDecorator", "extension '" .. tostring(def.extension or def.id) .. "' must be registered first, with its icon")
    end
    def.extension = owner.id
    if def.categories then
        local set = {}
        for i = 1, #def.categories do set[def.categories[i]] = true end
        def.categorySet = set
    end
    API.UnregisterRowDecorator(def.id, def.slot)
    Decorators.list[#Decorators.list + 1] = def
    if def.slot and not Decorators.bySlot[def.slot] then Decorators.bySlot[def.slot] = def end



    local p = Providers.byKey[def.id]
    if p and p.scope and p.scope.extension == owner.id then
        Extensions.JoinScope(p.scope, def, { p.category })
    elseif def.aliases then
        local scope = Decorators.scopes[def.id]
        if scope then
            scope.decorator = def
        else
            scope = { key = def.id, canonical = def.id, label = def.label or owner.name, aliases = def.aliases,
                      decorator = def, extension = owner.id }
            if ns.Filters:AddQuickFilter(scope) then Decorators.scopes[def.id] = scope end
        end
    end
    API.RefreshRowDecorations()
    return true
end


local function ZonesOfNames(byName)
    local out = {}
    for name, maps in pairs(byName) do
        if type(name) == "string" and type(maps) == "table" then
            local zones = {}
            for mapID in pairs(maps) do
                if type(mapID) == "number" then
                    for m in pairs(MapAndZone(mapID)) do zones[m] = true end
                end
            end
            out[slower(name)] = zones
        end
    end
    return out
end



local function Candidates(def)
    local set = Decorators.candidates[def]
    if set == nil then
        set = false
        if def.candidates then
            local ok, got = Run(def.candidates)
            if ok and type(got) == "table" then
                set = {}
                for field, ids in pairs(got) do set[field] = ids end
                if type(got.name) == "table" then set.name = ZonesOfNames(got.name) end
            end
        end
        Decorators.candidates[def] = set
    end
    return set
end


local function NamedHere(zonesByName, row)
    local zones = type(row.name) == "string" and zonesByName[row.nameLower or slower(row.name)]
    local mapID = zones and (row.mapID or row.coordMapID)
    if not mapID then return false end
    for m in pairs(MapAndZone(mapID)) do
        if zones[m] then return true end
    end
    return false
end

local function DecoratorTakes(def, row)
    local candidates = Candidates(def)
    if candidates then
        local named = false
        for field, ids in pairs(candidates) do
            if field == "name" then
                named = NamedHere(ids, row)
            else
                local value = row[field]
                named = value ~= nil and type(ids) == "table" and ids[value] and true or false
            end
            if named then break end
        end
        if not named then return false end
        if not def.applies then return true end
    end
    if def.applies then
        local ok, yes = Run(def.applies, row)
        return ok and yes == true
    end
    if row.itemID == nil then return false end
    return not def.categorySet or def.categorySet[row.category] == true
end
Extensions.DecoratorTakes = DecoratorTakes



function Extensions.DecoratorBrowses(def, row)
    if not def.browse then return true end
    local ok, yes = Run(def.browse, row)
    return ok and yes == true
end

function Extensions.DecoratorLink(row)
    if row.bagItemLink then return row.bagItemLink end
    if row.category == "Loot" and ns.Database and ns.Database.GetLootItemLink then
        local link = ns.Database:GetLootItemLink(row)
        if link then return link end
    end
    return row.itemID and ("item:" .. row.itemID) or nil
end



function Extensions.DecoratorText(slot, row)
    local def = Decorators.bySlot[slot]
    if not (def and def.text and DecoratorTakes(def, row)) then return nil end
    local ok, value, word = xpcall(def.text, Report, row, Extensions.DecoratorLink(row))
    if not (ok and value) then return nil end
    return value, word, def
end


function Extensions.DecoratorSubtext(row)
    local out
    for i = 1, #Decorators.list do
        local d = Decorators.list[i]
        if d.subtext and DecoratorTakes(d, row) then
            local ok, part = Run(d.subtext, row)
            if ok and type(part) == "string" and part ~= "" then out = out and (out .. ", " .. part) or part end
        end
    end
    return out
end



function Extensions.DecorateTooltip(row, tooltip)
    local any, byKeys = false, false
    for i = 1, #Decorators.list do
        local d = Decorators.list[i]
        if d.tooltip and DecoratorTakes(d, row) then
            Run(d.tooltip, row, Extensions.DecoratorLink(row), tooltip)
            any = true
            byKeys = byKeys or d.modifiers == true
        end
    end
    return any, byKeys
end



function Extensions.HasTooltipDecorator(row)
    for i = 1, #Decorators.list do
        local d = Decorators.list[i]
        if d.tooltip and DecoratorTakes(d, row) then return true end
    end
    return false
end



function Extensions.DecoratorSelect(row, gesture)
    for i = 1, #Decorators.list do
        local d = Decorators.list[i]
        if d.select and DecoratorTakes(d, row) then
            local ok, took = Run(d.select, row, Extensions.DecoratorLink(row), gesture or "click")
            if ok and took == true then return true end
        end
    end
    return false
end




function Extensions.DecoratorHint(row)
    for i = 1, #Decorators.list do
        local d = Decorators.list[i]
        if d.select and DecoratorTakes(d, row) then
            local ok, words = true, nil
            if d.hint then ok, words = Run(d.hint, row) end
            if ok and type(words) == "string" and words ~= "" then return { click = words } end
            if ok and type(words) == "table" then return words end
            return {}
        end
    end
    return nil
end





function Extensions.DecoratorMenuRows(row, convert)
    local out
    for i = 1, #Decorators.list do
        local d = Decorators.list[i]
        if d.menu and DecoratorTakes(d, row) then
            local ok, defs = Run(d.menu, row, Extensions.DecoratorLink(row))
            local rows = ok and defs and convert(defs) or nil
            if rows and #rows > 0 then
                local owner = Extensions.Get(d.extension)
                out = out or {}
                if d.submenu or #rows > 4 then
                    out[#out + 1] = { text = d.label or owner.name, icon = owner.icon, iconCoords = owner.iconCoords,
                                      chromeIcon = true, submenu = rows }
                else
                    for j = 1, #rows do
                        local r = rows[j]
                        if not (r.isSeparator or r.icon) then
                            r.icon, r.iconCoords, r.chromeIcon = owner.icon, owner.iconCoords, true
                        end
                        out[#out + 1] = r
                    end
                end
            end
        end
    end
    return out
end


function API.RefreshSearchProvider(key)
    if ns.Database and ns.Database.RefreshDynamicCategory then ns.Database:RefreshDynamicCategory(key) end
end



function API.ShowScope(key, text)
    Utils.SafeAfter(0, function()
        local Search = ns.Search
        if Search and Search.Show then Search:Show(false) end
        local frame = Search and Search.GetSearchFrame and Search:GetSearchFrame()
        local defs = ns.Filters and ns.Filters.quickFilterOptions
        if not (frame and frame:IsShown() and defs) then return end
        for i = 1, #defs do
            if defs[i].key == key then
                ns.Filters:ApplyQuickFilter(defs[i], text or "")
                return
            end
        end
    end)
    return true
end


function API.OpenSearch(text)
    local Search = ns.Search
    if not (Search and Search.Show) then return false end
    Search:Show(true)
    if type(text) == "string" and text ~= "" then
        Utils.SafeAfter(0, function()
            local frame = Search:GetSearchFrame()
            local box = frame and frame:IsShown() and frame.editBox
            if not box then return end
            box:SetText(text)
            box:SetCursorPosition(#text)
        end)
    end
    return true
end





local placeMaps
local function PlaceMaps()
    if placeMaps then return placeMaps end
    placeMaps = {}
    local function Add(name, mapID)
        if type(name) ~= "string" or not mapID then return end
        local low = slower(name)
        local maps = placeMaps[low]
        if not maps then
            maps = {}
            placeMaps[low] = maps
        end
        maps[mapID] = true
    end
    for mapID, list in pairs(ns.STATIC_LOCATIONS or {}) do
        for i = 1, #list do Add(list[i].name, mapID) end
    end
    local MapSearch = ns.MapSearch
    local entrances = MapSearch and MapSearch.GetGlobalInstanceCache and MapSearch:GetGlobalInstanceCache()
    for i = 1, entrances and #entrances or 0 do Add(entrances[i].name, entrances[i].entranceMapID) end
    return placeMaps
end




function API.HasRow(name, mapID)
    if type(name) ~= "string" or name == "" or type(mapID) ~= "number" then return false end
    local maps = MapAndZone(mapID)
    local npcs = ns.Npcs
    local npcID = npcs and npcs.NamedOn and npcs.NamedOn(name, maps)
    if npcID then return npcID end
    local on = PlaceMaps()[slower(name)]
    if not on then return false end
    for m in pairs(maps) do
        if on[m] then return true end
    end
    return false
end


function API.HasCreature(npcID)
    local npcs = ns.Npcs
    return type(npcID) == "number" and npcs ~= nil and npcs.HasID ~= nil and npcs.HasID(npcID) == true
end



function API.CreatureName(npcID)
    local npcs = ns.Npcs
    if type(npcID) ~= "number" or not (npcs and npcs.NameOfID) then return nil end
    return npcs.NameOfID(npcID)
end




local THEME_SLOTS = {
    background = "windowFill", panel = "backdropColor", border = "backdropBorder", line = "separator",
    text = "leafColor", textDim = "textFaint", heading = "pathColor", accent = "accent",
    selection = "selection", glyph = "chromeGlyph",
}

function API.GetThemeColor(role)
    local slot = THEME_SLOTS[role]
    if not slot then Fail("GetThemeColor", "no color named '" .. tostring(role) .. "'") end
    local palette = ns.ACTIVE_UI_PALETTE or (ns.UI_THEME_PALETTES and ns.UI_THEME_PALETTES.Black) or {}
    local c = palette[slot] or { 1, 1, 1 }
    return c[1], c[2], c[3], c[4] or 1
end


function API.IsLightTheme()
    local palette = ns.ACTIVE_UI_PALETTE
    return palette ~= nil and palette.light == true
end


function API.OnThemeChanged(fn)
    if type(fn) ~= "function" then Fail("OnThemeChanged", "expects a function") end
    ns.RegisterThemeCallback(function() Run(fn) end)
end



function API.StylePanel(frame)
    if type(frame) ~= "table" or not frame.CreateTexture then Fail("StylePanel", "expects a frame") end
    ns.StyleMenuPanel(frame)
    return frame
end


function API.CreateButton(parent, text, width, height)
    return ns.CreateModernButton(parent, text, width or 120, height or 22)
end




function API.ShowDialog(opts)
    if type(opts) ~= "table" then Fail("ShowDialog", "expects a table") end
    local onAccept = opts.onAccept
    ns.ShowThemedDialog({
        text = opts.text, acceptText = opts.acceptText, cancelText = opts.cancelText,
        hasEditBox = opts.hasEditBox, editBoxDefault = opts.editBoxDefault, single = opts.single,
        onAccept = onAccept and function(value) Run(onAccept, value) end,
    })
end



local actions = {}
local listeners = {}
Extensions.actions, Extensions.listeners = actions, listeners

local function CheckName(fn, what, v)
    if type(v) ~= "string" or v == "" then Fail(fn, what .. " must be a string") end
end


function API.RegisterAction(id, name, fn)
    CheckName("RegisterAction", "id", id)
    CheckName("RegisterAction", "name", name)
    if type(fn) ~= "function" then Fail("RegisterAction", "fn must be a function") end
    actions[id] = actions[id] or {}
    actions[id][name] = fn
end

function API.HasAction(id, name)
    local own = actions[id]
    return own ~= nil and own[name] ~= nil
end

local function Results(ok, ...)
    if ok then return ... end
end



function API.LoadExtension(id)
    local def = Extensions.byID[id]
    if not def then return false end
    LoadAddon(def)
    return not def.addon or not (C_AddOns and C_AddOns.IsAddOnLoaded) or C_AddOns.IsAddOnLoaded(def.addon) or false
end




function API.CallAction(id, name, ...)
    local own = actions[id]
    if not (own and own[name]) then
        LoadAddon(Extensions.byID[id])
        own = actions[id]
        if not (own and own[name]) then return nil end
    end
    return Results(xpcall(own[name], Report, ...))
end


function API.On(id, event, fn)
    CheckName("On", "id", id)
    CheckName("On", "event", event)
    if type(fn) ~= "function" then Fail("On", "fn must be a function") end
    local key = id .. ":" .. event
    listeners[key] = listeners[key] or {}
    local list = listeners[key]
    list[#list + 1] = fn
end

function API.Off(id, event, fn)
    local list = listeners[tostring(id) .. ":" .. tostring(event)]
    for i = #(list or {}), 1, -1 do
        if list[i] == fn then table.remove(list, i) end
    end
end


function API.Fire(id, event, ...)
    local list = listeners[tostring(id) .. ":" .. tostring(event)]
    if not list then return end
    for i = 1, #list do Run(list[i], ...) end
end























ns.ChecklistLinks = ns.ChecklistLinks or {}
ns.NoteCategories = ns.NoteCategories or {}
function API.LinkChecklists(id, handlers)
    ns.ChecklistLinks[id] = handlers
    local cat = handlers and handlers.category
    if cat and cat.key then ns.NoteCategories[cat.key] = cat.label or cat.key end
end



function API.LinkedChecklist(id, key, title, make)
    if make and not ns.RequestNotes() then return nil end
    return ns.Notes and ns.Notes.LinkedNote and ns.Notes.LinkedNote(id, key, title, make) or nil
end

function API.SyncChecklist(noteID, entries)
    return ns.Notes and ns.Notes.SyncLinked and ns.Notes.SyncLinked(noteID, entries) or false
end


function API.SetChecklistRefs(noteID, refs)
    if ns.Notes and ns.Notes.SetLineRefs then ns.Notes.SetLineRefs(noteID, refs) end
end

function API.OpenNote(noteID)
    if ns.RequestNotes() and ns.Notes.OpenNote then ns.Notes.OpenNote(noteID) end
end










ns.PriceSources = ns.PriceSources or {}
function API.RegisterPriceSource(id, def)
    CheckName("RegisterPriceSource", "id", id)
    if type(def) ~= "table" or type(def.price) ~= "function" then Fail("RegisterPriceSource", "def.price must be a function") end
    ns.PriceSources[id] = def
    API.RefreshPrices(id)
end




ns.PRICE_ANY = "any"
function ns.PriceChoices()
    local ids, out = {}, {}
    for id in pairs(ns.PriceSources) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local def = ns.PriceSources[id]
        local list = def.sources
        if type(list) == "function" then list = Results(xpcall(list, Report)) end
        local own = Extensions.byID[id]
        local name = def.label or (own and own.name) or id
        for _, s in ipairs(type(list) == "table" and list or {}) do
            out[#out + 1] = { value = id .. ":" .. tostring(s.key), id = id, key = s.key, name = name,
                              label = #list > 1 and (name .. ": " .. tostring(s.label)) or name }
        end
    end
    return out
end


function API.RefreshPrices(id)
    if ns.Notes and ns.Notes.PricesChanged then ns.Notes.PricesChanged(id) end
end





ns.AuctionSearches = ns.AuctionSearches or {}
function API.RegisterAuctionSearch(id, fn)
    CheckName("RegisterAuctionSearch", "id", id)
    if type(fn) ~= "function" then Fail("RegisterAuctionSearch", "fn must be a function") end
    ns.AuctionSearches[id] = fn
end




function API.OpenSettings(id)
    if not (ns.RequestOptionsPanel and ns.RequestOptionsPanel()) then return false end
    if ns.Options and ns.Options.OpenAtExtension then ns.Options:OpenAtExtension(id) end
    return true
end



function API.RegisterChatPiece(frame)
    if type(frame) ~= "table" or not frame.Hide then Fail("RegisterChatPiece", "expects a frame") end
    ns.chatPieces = ns.chatPieces or {}
    ns.chatPieces[frame] = true
    if EasyFind.db and EasyFind.db.chatFramesHidden then EasyFind:RestoreChatFramesHidden() end
end




function API.RegisterTrackerPiece(frame, show)
    if type(frame) ~= "table" or not frame.Hide then Fail("RegisterTrackerPiece", "expects a frame") end
    if show ~= nil and type(show) ~= "function" then Fail("RegisterTrackerPiece", "show must be a function") end
    ns.AddTrackerPiece(frame, show)
end

function API.IsSettingsOpen(id)
    local frame = ns.optionsFrame
    return frame ~= nil and frame:IsShown() and ns.Options ~= nil and ns.Options.CurrentExtensionPage ~= nil
        and ns.Options:CurrentExtensionPage() == id
end

function API.CloseSettings()
    if ns.Options and ns.Options.Hide then ns.Options:Hide() end
end







function API.RegisterSettingsIndex(addon, rows)
    if type(addon) ~= "string" or addon == "" then Fail("RegisterSettingsIndex", "addon must be a name") end
    if type(rows) ~= "function" then Fail("RegisterSettingsIndex", "rows must be a function") end
    ns.settingsFeeds = ns.settingsFeeds or {}
    ns.settingsFeeds[addon] = rows
    if ns.BlizzOptionsSearch and ns.BlizzOptionsSearch.PullSettingsFeed then ns.BlizzOptionsSearch:PullSettingsFeed(addon) end
    return true
end


function API.RefreshSettingsIndex(addon)
    if ns.BlizzOptionsSearch and ns.BlizzOptionsSearch.PullSettingsFeed then ns.BlizzOptionsSearch:PullSettingsFeed(addon) end
end
