













local _, ns = ...
local Profiles = {}
ns.Profiles = Profiles

local L = ns.L

local pairs, ipairs, type, tonumber = pairs, ipairs, type, tonumber
local tsort, tconcat, tinsert = table.sort, table.concat, table.insert
local mfloor, mabs, mhuge = math.floor, math.abs, math.huge
local sformat = string.format

Profiles.DEFAULT = "Default"
Profiles.CODE_PREFIX = "EFP1!"





Profiles.SECTIONS = {
    { id = "settings",   exportDefault = true },
    { id = "aliases",    keys = { "aliases" }, exportDefault = true },
    { id = "shortkeys",  keys = { "shortkeys", "shortkeysPerChar" },
                         perChar = { shortkeysPerChar = true }, exportDefault = true },
    { id = "blacklist",  keys = { "blacklist" }, exportDefault = true },
    { id = "snippets",   keys = { "snippets" }, exportDefault = false },
    { id = "quicklists", keys = { "quicklists", "quicklistNextID" }, exportDefault = true },
    { id = "extbuttons", keys = { "extensionButtons", "extensionButtonBorders" }, exportDefault = true },
    { id = "pins",       keys = { "pinnedUIItems", "pinnedUIItemsPerChar", "pinnedMapItems" },
                         perChar = { pinnedUIItemsPerChar = true }, exportDefault = true },
    { id = "learned",    keys = { "queryLearn" }, exportDefault = false },
    { id = "keybinds",   keys = { "accountKeybinds" }, exportDefault = true },
}

local SECTION_BY_ID, SECTION_OF_KEY = {}, {}
for _, sec in ipairs(Profiles.SECTIONS) do
    SECTION_BY_ID[sec.id] = sec
    for _, key in ipairs(sec.keys or {}) do SECTION_OF_KEY[key] = sec end
end




local STATE_KEYS = {
    dbVersion = true, firstInstall = true, devMode = true,
    profiles = true, profileActive = true, profileKeys = true, profileSpecs = true,
    profileExportIncl = true, profileScope = true, profileAssign = true,
    visible = true, tutorialDone = true, spotlightsDone = true, learnedStepLocks = true,
    lastSeenVersion = true, revampedTutorialVersion = true, setupComplete = true,
    uiSearchHistory = true, mapTabRecentSearches = true,
    clipboard = true, charGold = true,
    nativeKeybindsImported = true, suggestedKeybindsSeeded = true, suggestedKeybindsApplied = true,
    achievementIndex = true, classicRecipes = true, recipeLevels = true, gpsChar = true, gpsHearth = true,
    gpsBoats = true, gpsFlown = true, macroButtons = true, minimapIcon = true,
    chatFramesHidden = true, objectiveTrackerHidden = true, customThemes = true, themeStudioDraft = true,
    notesInUse = true, chatInUse = true, extensionsNoticeFrom = true, updateHeard = true,
}

local function IsStateKey(key)
    if STATE_KEYS[key] then return true end
    return key:find("Cache$") ~= nil or key:find("CacheVer$") ~= nil or key:find("PendingPush$") ~= nil
end

local function IsSettingKey(key)
    return type(key) == "string" and not SECTION_OF_KEY[key] and not IsStateKey(key)
end
Profiles.IsSettingKey = IsSettingKey

local function Copy(v, depth)
    if type(v) ~= "table" then return v end
    depth = (depth or 0) + 1
    if depth > 64 then return nil end
    local out = {}
    for k, kv in pairs(v) do out[k] = Copy(kv, depth) end
    return out
end



function Profiles:DB()
    return EasyFind and EasyFind.db
end

local function Ready(self)
    local db = self:DB()
    return (db and type(db.profiles) == "table") and db or nil
end

function Profiles:Active()
    local db = self:DB()
    return (db and type(db.profileActive) == "string") and db.profileActive or self.DEFAULT
end

function Profiles:Exists(name)
    local db = Ready(self)
    return db ~= nil and name ~= nil and db.profiles[name] ~= nil
end


function Profiles:Names()
    local db, out = Ready(self), {}
    if not db then return out end
    for name in pairs(db.profiles) do
        if name ~= self.DEFAULT then out[#out + 1] = name end
    end
    tsort(out, function(a, b) return a:lower() < b:lower() end)
    tinsert(out, 1, self.DEFAULT)
    return out
end

function Profiles:DisplayName(name)
    if name == self.DEFAULT then return (_G and _G.DEFAULT) or "Default" end
    return name
end



function Profiles:CharKey()
    return ns.PlayerName() and ns.CurrentCharacterKey() or nil
end




function Profiles:Suggestions()
    local out = {}
    local db = Ready(self)
    if not db then return out end
    local name = ns.PlayerName()
    local realm = GetRealmName and GetRealmName()
    local char = (name and realm) and (name .. " - " .. realm) or nil
    if char and not db.profiles[char] then out[#out + 1] = char end
    local class = UnitClass and UnitClass("player")
    if class and not db.profiles[class] then out[#out + 1] = class end
    return out
end



local function Snapshot(db)
    local slot = { settings = {} }
    for key, value in pairs(db) do
        if SECTION_OF_KEY[key] then
            slot[key] = value
        elseif IsSettingKey(key) then
            slot.settings[key] = value
        end
    end
    return slot
end



local function Load(db, slot)
    for key in pairs(db) do
        if SECTION_OF_KEY[key] or IsSettingKey(key) then db[key] = nil end
    end
    slot = slot or {}
    for key in pairs(SECTION_OF_KEY) do
        if slot[key] ~= nil then db[key] = slot[key] end
    end
    if type(slot.settings) == "table" then
        for key, value in pairs(slot.settings) do
            if IsSettingKey(key) then db[key] = value end
        end
    end
    if ns.ApplyDBDefaults then ns.ApplyDBDefaults(db) end
end




function Profiles:Switch(name, mode)
    local db = Ready(self)
    if not db or not db.profiles[name] then return false end
    local charKey = self:CharKey()
    if charKey then db.profileKeys[charKey] = name end
    local active = self:Active()
    if name == active then return false end
    local incoming = db.profiles[name]



    if type(incoming) == "table" and incoming.live then
        db.profiles[active] = nil
        db.profileActive = name
        return false
    end
    db.profiles[active] = Snapshot(db)
    db.profiles[name] = { live = true }
    db.profileActive = name
    Load(db, incoming)
    if mode ~= "silent" then self:RefreshModules() end
    return true
end



function Profiles:Create(name, copyFrom)
    local db = Ready(self)
    if not db or type(name) ~= "string" or name == "" or db.profiles[name] then return false end
    local slot = {}
    if copyFrom == self:Active() then
        slot = Copy(Snapshot(db))
    elseif copyFrom and db.profiles[copyFrom] then
        slot = Copy(db.profiles[copyFrom])
    end
    slot.live = nil
    db.profiles[name] = slot
    return true
end



local function ForEachRecord(db, fn)
    local keys = db.profileKeys
    if type(keys) == "table" then
        for charKey, value in pairs(keys) do
            local new = fn(value)
            if new ~= value then keys[charKey] = new end
        end
    end
    local specs = db.profileSpecs
    if type(specs) == "table" then
        for _, map in pairs(specs) do
            if type(map) == "table" then
                for specID, value in pairs(map) do
                    if type(specID) == "number" then
                        local new = fn(value)
                        if new ~= value then map[specID] = new end
                    end
                end
            end
        end
    end
end

function Profiles:CanDelete(name)
    return name ~= self.DEFAULT and name ~= self:Active() and self:Exists(name)
end

function Profiles:Deletable()
    local out = {}
    for _, name in ipairs(self:Names()) do
        if self:CanDelete(name) then out[#out + 1] = name end
    end
    return out
end


function Profiles:Delete(name)
    local db = Ready(self)
    if not db or not self:CanDelete(name) then return false end
    db.profiles[name] = nil
    ForEachRecord(db, function(value) if value == name then return nil end return value end)
    return true
end

function Profiles:Rename(old, new)
    local db = Ready(self)
    if not db or old == self.DEFAULT or not db.profiles[old] then return false end
    if type(new) ~= "string" or new == "" or db.profiles[new] then return false end
    db.profiles[new], db.profiles[old] = db.profiles[old], nil
    if db.profileActive == old then db.profileActive = new end
    ForEachRecord(db, function(value) if value == old then return new end return value end)
    return true
end


function Profiles:CopyFrom(name)
    local db = Ready(self)
    if not db or name == self:Active() or not db.profiles[name] then return false end
    Load(db, Copy(db.profiles[name]))
    self:RefreshModules()
    return true
end


function Profiles:ResetActive()
    local db = Ready(self)
    if not db then return false end
    Load(db, {})
    self:RefreshModules()
    return true
end



function Profiles:CurrentSpecID()
    local index = GetSpecialization and GetSpecialization()
    local specID = index and GetSpecializationInfo and GetSpecializationInfo(index)
    return (specID and specID ~= 0) and specID or nil
end


function Profiles:ClassSpecs()
    local out = {}
    local n = (GetNumSpecializations and GetSpecializationInfo) and GetNumSpecializations() or 0
    for i = 1, n do
        local id, name = GetSpecializationInfo(i)
        if id and id ~= 0 then out[#out + 1] = { id = id, name = name } end
    end
    return out
end

local function SpecRecord(db, charKey, create)
    local specs = db.profileSpecs[charKey]
    if type(specs) ~= "table" and create then
        specs = {}
        db.profileSpecs[charKey] = specs
    end
    return type(specs) == "table" and specs or nil
end

function Profiles:SpecProfilesEnabled()
    local db = Ready(self)
    local charKey = db and self:CharKey()
    local specs = charKey and SpecRecord(db, charKey)
    return specs ~= nil and specs.enabled == true
end



function Profiles:SetSpecProfilesEnabled(on)
    local db = Ready(self)
    local charKey = db and self:CharKey()
    if not charKey then return false end
    local specs = SpecRecord(db, charKey, true)
    specs.enabled = on and true or nil
    if on then self:ApplyResolved() end
    return true
end


function Profiles:SpecProfile(specID)
    local db = Ready(self)
    local charKey = db and self:CharKey()
    local specs = charKey and SpecRecord(db, charKey)
    local name = specs and specID and specs[specID]
    if name and db.profiles[name] then return name end
    local pick = charKey and db and db.profileKeys[charKey]
    return (pick and db.profiles[pick]) and pick or self:Active()
end



function Profiles:SetSpecProfile(specID, name)
    local db = Ready(self)
    local charKey = db and self:CharKey()
    if not charKey or not specID or not db.profiles[name] then return false end
    SpecRecord(db, charKey, true)[specID] = name
    if self:SpecProfilesEnabled() and specID == self:CurrentSpecID() then self:Switch(name) end
    return true
end




function Profiles:Resolve()
    local db = Ready(self)
    if not db then return nil end
    local charKey = self:CharKey()
    if not charKey then return nil end
    local specs = SpecRecord(db, charKey)
    if specs and specs.enabled then
        local specID = self:CurrentSpecID()
        local name = specID and specs[specID]
        if name and db.profiles[name] then return name end
    end
    local pick = db.profileKeys[charKey]
    if pick and db.profiles[pick] then return pick end
    return self.DEFAULT
end




function Profiles:Pick(name)
    local db = Ready(self)
    if not db or type(name) ~= "string" or name == "" then return false end
    if not db.profiles[name] then self:Create(name, self:Active()) end
    local charKey = self:CharKey()
    if charKey then
        db.profileKeys[charKey] = name
        local specs = SpecRecord(db, charKey)
        local specID = specs and specs.enabled and self:CurrentSpecID()
        if specID then specs[specID] = name end
    end
    self:Switch(name)
    return true
end

function Profiles:ApplyResolved(mode, announce)
    local target = self:Resolve()
    if target and self:Switch(target, mode) and announce and EasyFind and EasyFind.Print then
        EasyFind:Print((L["PROFILE_SWITCHED_FMT"]):format(self:DisplayName(target)))
    end
end





function Profiles:OnInitialize()
    local db = self:DB()
    if not db then return end
    if type(db.profiles) ~= "table" then db.profiles = {} end
    if type(db.profileKeys) ~= "table" then db.profileKeys = {} end
    if type(db.profileSpecs) ~= "table" then db.profileSpecs = {} end
    ns.MigrateCharacterKeys(db)
    if type(db.profileActive) ~= "string" then db.profileActive = self.DEFAULT end



    local liveName
    for name, slot in pairs(db.profiles) do
        if type(slot) == "table" and slot.live then
            if liveName then slot.live = nil else liveName = name end
        end
    end
    if liveName and liveName ~= db.profileActive then db.profileActive = liveName end
    if type(db.profiles[db.profileActive]) ~= "table" then db.profiles[db.profileActive] = { live = true } end
    if type(db.profiles[self.DEFAULT]) ~= "table" then db.profiles[self.DEFAULT] = {} end
    db.profileScope, db.profileAssign = nil, nil
    self:ApplyResolved("silent")
end




function Profiles:OnLogin()
    if not Ready(self) then return end
    self:ApplyResolved("silent")
    if ns.Aliases and ns.Aliases.InvalidateKeyIndex then ns.Aliases:InvalidateKeyIndex() end
    if ns.Snippets and ns.Snippets.RebuildKeywordLookup then ns.Snippets.RebuildKeywordLookup() end
    if not self.eventFrame and CreateFrame then
        local f = CreateFrame("Frame")
        self.eventFrame = f
        f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:SetScript("OnEvent", function(_, event, unit)
            if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
            if Profiles:SpecProfilesEnabled() then Profiles:ApplyResolved(nil, true) end
        end)
    end
end



function Profiles:RefreshModules()
    local db = self:DB()
    if not db then return end
    if ns.Aliases and ns.Aliases.InvalidateKeyIndex then ns.Aliases:InvalidateKeyIndex() end
    if ns.Snippets and ns.Snippets.RebuildKeywordLookup then ns.Snippets.RebuildKeywordLookup() end
    if ns.Shortkeys and ns.Shortkeys.ApplyAll then ns.Shortkeys:ApplyAll() end
    if ns.Quicklists and ns.Quicklists.Changed then ns.Quicklists:Changed() end
    if EasyFind and EasyFind.ApplyAccountKeybinds then EasyFind:ApplyAccountKeybinds() end
    if ns.RefreshAddonFont then ns.RefreshAddonFont() end
    if ns.ApplyUITheme then ns.ApplyUITheme(db.uiTheme) end
    if ns.ApplyUISettings then ns.ApplyUISettings(false) end
    if ns.ApplyMapSettings then ns.ApplyMapSettings() end
    if EasyFind and EasyFind.UpdateMinimapButton then EasyFind:UpdateMinimapButton() end
    if ns.ExtensionButtons and ns.ExtensionButtons.Reload then ns.ExtensionButtons:Reload() end
    if ns.Filters and ns.Filters.ResyncShownOptionPopups then ns.Filters.ResyncShownOptionPopups() end
    if ns.Options and ns.Options.OnProfileSwitched then ns.Options:OnProfileSwitched() end
    if ns.RefreshBindTables then ns.RefreshBindTables() end
end



function Profiles:ExportIncluded(id)
    local sec = SECTION_BY_ID[id]
    if not sec then return false end
    local db = self:DB()
    local incl = db and db.profileExportIncl
    local v = incl and incl[id]
    if v == nil then return sec.exportDefault end
    return v and true or false
end

function Profiles:SetExportIncluded(id, on)
    local db = self:DB()
    if not db or not SECTION_BY_ID[id] then return end
    if type(db.profileExportIncl) ~= "table" then db.profileExportIncl = {} end
    db.profileExportIncl[id] = on and true or false
end

function Profiles:ExportSet()
    local set = {}
    for _, sec in ipairs(self.SECTIONS) do
        if self:ExportIncluded(sec.id) then set[sec.id] = true end
    end
    return set
end




local function NumStr(v)
    if v ~= v or v == mhuge or v == -mhuge then return "0" end
    if v == mfloor(v) and mabs(v) < 9007199254740992 then return sformat("%d", v) end
    return sformat("%.17g", v)
end

local SER_TYPES = { boolean = true, number = true, string = true, table = true }

local function Ser(v, out, depth)
    local tv = type(v)
    if tv == "boolean" then
        out[#out + 1] = v and "t" or "f"
    elseif tv == "number" then
        out[#out + 1] = "n" .. NumStr(v) .. ";"
    elseif tv == "string" then
        out[#out + 1] = "s" .. #v .. ":" .. v
    elseif tv == "table" then
        depth = depth + 1
        if depth > 64 then
            out[#out + 1] = "{}"
            return
        end
        out[#out + 1] = "{"
        for k, kv in pairs(v) do
            local tk = type(k)
            if (tk == "string" or tk == "number") and SER_TYPES[type(kv)] then
                Ser(k, out, depth)
                Ser(kv, out, depth)
            end
        end
        out[#out + 1] = "}"
    end
end

local function Serialize(v)
    local out = {}
    Ser(v, out, 0)
    return tconcat(out)
end

local function Des(s, pos, depth)
    local c = s:sub(pos, pos)
    if c == "t" then return true, pos + 1 end
    if c == "f" then return false, pos + 1 end
    if c == "n" then
        local e = s:find(";", pos + 1, true)
        local v = e and tonumber(s:sub(pos + 1, e - 1))
        if not v then error("number") end
        return v, e + 1
    end
    if c == "s" then
        local e = s:find(":", pos + 1, true)
        local len = e and tonumber(s:sub(pos + 1, e - 1))
        if not len or len < 0 or len ~= mfloor(len) then error("string") end
        local str = s:sub(e + 1, e + len)
        if #str ~= len then error("string") end
        return str, e + 1 + len
    end
    if c == "{" then
        depth = depth + 1
        if depth > 64 then error("depth") end
        local t = {}
        pos = pos + 1
        while true do
            local ch = s:sub(pos, pos)
            if ch == "}" then return t, pos + 1 end
            if ch == "" then error("table") end
            local k, v
            k, pos = Des(s, pos, depth)
            if type(k) ~= "string" and type(k) ~= "number" then error("key") end
            v, pos = Des(s, pos, depth)
            t[k] = v
        end
    end
    error("value")
end

local function Deserialize(s)
    local v, pos = Des(s, 1, 0)
    if pos ~= #s + 1 then error("trailing") end
    return v
end

Profiles.Serialize, Profiles.Deserialize = Serialize, Deserialize



function Profiles:Export(include)
    local db = Ready(self)
    if not db then return nil end
    include = include or self:ExportSet()
    local live = Snapshot(db)
    local sections, any = {}, false
    for _, sec in ipairs(self.SECTIONS) do
        if include[sec.id] then
            any = true
            local out
            if sec.keys then
                out = {}
                for _, key in ipairs(sec.keys) do
                    if not (sec.perChar and sec.perChar[key]) and live[key] ~= nil then
                        out[key] = live[key]
                    end
                end
            else
                out = live.settings
            end
            sections[sec.id] = out
        end
    end
    if not any then return nil end
    local payload = { v = 1, name = self:Active(), addon = ns.version, sections = sections }
    return self.CODE_PREFIX .. ns.Utils.Base64Encode(Serialize(payload))
end

function Profiles:Decode(str)
    if type(str) ~= "string" then return nil end
    local b64 = strtrim(str):match("^" .. self.CODE_PREFIX .. "(.+)$")
    if not b64 then return nil end
    local ok, blob = pcall(ns.Utils.Base64Decode, b64)
    if not ok or type(blob) ~= "string" or blob == "" then return nil end
    local ok2, payload = pcall(Deserialize, blob)
    if not ok2 or type(payload) ~= "table" or payload.v ~= 1 or type(payload.sections) ~= "table" then
        return nil
    end
    return payload
end

function Profiles:UniqueName(base)
    local db = Ready(self)
    if not db or not db.profiles[base] then return base end
    local n = 2
    while db.profiles[base .. " (" .. n .. ")"] do n = n + 1 end
    return base .. " (" .. n .. ")"
end




local function SlotFromPayload(payload)
    local defaults = ns.DB_DEFAULTS or {}
    local slot = {}
    for _, sec in ipairs(Profiles.SECTIONS) do
        local data = payload.sections[sec.id]
        if type(data) == "table" then
            if sec.keys then
                for _, key in ipairs(sec.keys) do
                    if not (sec.perChar and sec.perChar[key]) and type(data[key]) == "table" then
                        slot[key] = Copy(data[key])
                    end
                end
            else
                local settings = {}
                local live = EasyFind and EasyFind.db or {}
                for key, value in pairs(data) do

                    local want = defaults[key]
                    if want == nil then want = live[key] end
                    if IsSettingKey(key) and (want == nil or type(want) == type(value)) then
                        settings[key] = Copy(value)
                    end
                end
                slot.settings = settings
            end
        end
    end
    return slot
end


local SNAPSHOT_CHAR_FIELDS = {
    "macroIndex", "macroIsChar", "bagID", "bagSlot", "bagItemLink",
    "specSetIndex", "loadoutConfigID", "isCollected", "isUsable",
}

local function StripCharFields(snap)
    if type(snap) ~= "table" then return end
    for i = 1, #SNAPSHOT_CHAR_FIELDS do snap[SNAPSHOT_CHAR_FIELDS[i]] = nil end
end


local function CommandRule(S, snap)
    local cmd = type(snap) == "table" and snap.slashCommand or nil
    if cmd == nil then return nil, false end
    local row = { b = "", n = cmd }
    return S.ShareRefusal("shortkeys", row), S.RunsCommands("shortkeys", row)
end

local function RefusedCombo(S, combo)
    if type(combo) ~= "string" or combo == "" then return false end
    local last = combo:match("([^%-]+)$") or combo
    return S.REFUSED_KEYS[last:upper()] == true
end




local function ApplyShareRules(slot)
    local S = ns.Shortkeys
    local leftOut, risky = 0, 0
    if not (S and S.ShareRefusal) then return leftOut, risky end

    local function Drop(why, runs)
        if why then
            leftOut = leftOut + 1
            return true
        end
        if runs then risky = risky + 1 end
        return false
    end
    for rowKey, info in pairs(type(slot.shortkeys) == "table" and slot.shortkeys or {}) do
        local row = type(info) == "table" and { k = rowKey, b = info.key, n = info.name } or nil
        StripCharFields(row and info.data)
        local snapWhy, snapRuns = CommandRule(S, row and info.data)
        if Drop(not row or S.ShareRefusal("shortkeys", row) or snapWhy,
                row and (S.RunsCommands("shortkeys", row) or snapRuns)) then
            slot.shortkeys[rowKey] = nil
        end
    end
    local snippets = type(slot.snippets) == "table" and slot.snippets or {}
    for i = #snippets, 1, -1 do
        local s = snippets[i]
        local row = type(s) == "table" and { name = s.name, keyword = s.keyword, body = s.flat or s.body } or nil
        if Drop(not row or S.ShareRefusal("snippets", row), row and S.RunsCommands("snippets", row)) then
            table.remove(snippets, i)
        end
    end
    for key, info in pairs(type(slot.aliases) == "table" and slot.aliases or {}) do
        local row = type(info) == "table" and { text = info.text, key = info.key, name = info.name } or nil
        if Drop(not row or S.ShareRefusal("aliases", row), false) then slot.aliases[key] = nil end
    end
    for key, info in pairs(type(slot.blacklist) == "table" and slot.blacklist or {}) do
        local row = type(info) == "table" and { key = key, name = info.name, category = info.category } or nil
        if Drop(not row or S.ShareRefusal("blacklist", row), false) then slot.blacklist[key] = nil end
    end
    local lists = type(slot.quicklists) == "table" and slot.quicklists or {}
    for i = #lists, 1, -1 do
        local list = lists[i]
        local items = type(list) == "table" and type(list.items) == "table" and list.items or nil
        local why = not items or S.ShareRefusal("quicklists", { name = list.name, key = list.key, items = items })
        local runs = false
        for j = 1, items and #items or 0 do
            local snap = type(items[j]) == "table" and items[j].d or nil
            StripCharFields(snap)
            local itemWhy, itemRuns = CommandRule(S, snap)
            why, runs = why or itemWhy, runs or itemRuns
        end
        if Drop(why, runs) then table.remove(lists, i) end
    end

    local pins = type(slot.pinnedUIItems) == "table" and slot.pinnedUIItems or {}
    for i = #pins, 1, -1 do
        if Drop(CommandRule(S, pins[i])) then table.remove(pins, i) end
    end
    for action, combo in pairs(type(slot.accountKeybinds) == "table" and slot.accountKeybinds or {}) do
        if Drop(RefusedCombo(S, combo), false) then slot.accountKeybinds[action] = nil end
    end
    return leftOut, risky
end

local function CountEntries(slot, sec)
    local n = 0
    if sec.keys then
        for _, key in ipairs(sec.keys) do
            if type(slot[key]) == "table" then
                for _ in pairs(slot[key]) do n = n + 1 end
            end
        end
    elseif type(slot.settings) == "table" then
        for _ in pairs(slot.settings) do n = n + 1 end
    end
    return n
end




function Profiles:InspectImport(payload)
    local slot = SlotFromPayload(payload)
    local leftOut, risky = ApplyShareRules(slot)
    local sections = {}
    for _, sec in ipairs(self.SECTIONS) do
        local carried = type(payload.sections[sec.id]) == "table"
        if carried then sections[#sections + 1] = { id = sec.id, count = CountEntries(slot, sec) } end
    end
    return { sections = sections, leftOut = leftOut, risky = risky }
end




function Profiles:Import(str)
    local db = Ready(self)
    if not db then return nil end
    local payload = self:Decode(str)
    if not payload then return nil end
    local slot = SlotFromPayload(payload)
    local leftOut = ApplyShareRules(slot)
    local base = type(payload.name) == "string" and strtrim(payload.name) or ""
    if base == "" then base = "Imported" end
    local name = self:UniqueName(base)
    db.profiles[name] = slot
    return name, leftOut
end
