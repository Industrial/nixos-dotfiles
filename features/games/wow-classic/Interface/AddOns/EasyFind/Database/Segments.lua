local _, ns = ...
local Database = ns.Database
local Utils = ns.Utils





local Segments = {}
ns.SearchSegments = Segments

local VERSION = 1
local RETRIES = 5
local tconcat = table.concat
local getmetatable, rawget = getmetatable, rawget



local CHAR_SCOPED = {
    bags = true, bank = true, talents = true, abilities = true, macros = true, professions = true,
    titles = true, gearSets = true, outfits = true, statistics = true, reputations = true, currencies = true,
}


local textBuf = {}
local function RowText(data)
    if data.lootEntry then return "\2L" end
    local nameLower, kws
    local mt = getmetatable(data)
    local pc = mt and rawget(mt, "__pcCorpus")
    if pc then
        local ri = rawget(data, "_ri")
        nameLower, kws = pc:NameLowerOf(ri), pc:KeywordsOf(ri)
    else
        nameLower = data.nameLower
    end
    kws = kws or data.keywordsLower or data.keywords
    local n = 1
    textBuf[1] = nameLower or ""
    if kws then
        for k = 1, #kws do
            n = n + 1
            textBuf[n] = kws[k] or ""
        end
    end
    if not pc and (rawget(data, "snippetKeywordLower") or rawget(data, "teleportNameLower")
                   or rawget(data, "scoreBonus")) then
        n = n + 1
        textBuf[n] = "\2S"
    end
    local s = tconcat(textBuf, "\3", 1, n)
    for i = 1, n do textBuf[i] = nil end
    return s
end
Segments.RowText = RowText

local function Store(key)
    local db = EasyFind and EasyFind.db
    if not db then return nil end
    if not CHAR_SCOPED[key] then
        db.searchIndexCache = db.searchIndexCache or {}
        return db.searchIndexCache
    end
    local char = ns.CurrentCharacterKey and ns.CurrentCharacterKey()
    if not char then return nil end
    db.searchIndexCharCache = db.searchIndexCharCache or {}
    local store = db.searchIndexCharCache[char]
    if not store then
        store = {}
        db.searchIndexCharCache[char] = store
    end
    return store
end

local function StillLive(rows)
    local want = {}
    for i = 1, #rows do want[rows[i]] = true end
    local data, found = Database.uiSearchData, 0
    for i = 1, #data do
        if want[data[i]] then found = found + 1 end
    end
    return found == #rows
end

local attachGen, attachRun = {}, {}






local MATCH_SHARE = 0.9
local function SavedAlign(savedText, rows, parts)
    local first, more = {}, {}
    for i = 1, #parts do
        if i % 256 == 0 then Utils.SliceCheckpoint() end
        local part = parts[i]
        if first[part] == nil then
            first[part] = i
        else
            local list = more[part]
            if not list then
                list = {}
                more[part] = list
            end
            list[#list + 1] = i
        end
    end
    local aligned, ghosts, n, matched, from, len = {}, {}, 0, 0, 1, #savedText
    while from <= len + 1 do
        local at = savedText:find("\1", from, true) or (len + 1)
        local part = savedText:sub(from, at - 1)
        local i = first[part]
        if i then
            first[part] = false
        else
            local list = more[part]
            i = list and list[#list]
            if list then list[#list] = nil end
        end
        n = n + 1
        if i then
            aligned[n] = rows[i]
            matched = matched + 1
        else
            local stop = part:find("\3", 1, true)
            local ghost = { nameLower = stop and part:sub(1, stop - 1) or part }
            aligned[n] = ghost
            ghosts[#ghosts + 1] = ghost
        end
        from = at + 1
        if n % 256 == 0 then Utils.SliceCheckpoint() end
    end
    if matched < MATCH_SHARE * n or matched < MATCH_SHARE * #rows then return nil end
    return aligned, ghosts
end






function Segments.Attach(key, rows, settled)
    settled = settled or function() end
    local SearchIndex = ns.SearchIndex
    if not (SearchIndex and SearchIndex.RestoreSegment) or #rows == 0 then return settled() end
    local store = Store(key)
    if not store then return settled() end
    local gen = (attachGen[key] or 0) + 1
    attachGen[key] = gen
    if attachRun[key] then attachRun[key]:Cancel() end
    local function Current() return attachGen[key] == gen and StillLive(rows) end
    attachRun[key] = Utils.RunSliced(function()
        local parts = {}
        for i = 1, #rows do
            if i % 64 == 0 then Utils.SliceCheckpoint() end
            parts[i] = RowText(rows[i])
        end
        local text = tconcat(parts, "\1")
        local saved = store[key]

        if saved and saved.v == VERSION and saved.text ~= text then
            return text, SavedAlign(saved.text, rows, parts)
        end
        return text
    end, function(ok, text, aligned, ghosts)
        if attachGen[key] == gen then attachRun[key] = nil end
        if not ok then
            settled()
            return Utils.ErrorHandler(text)
        end
        if not Current() then return settled() end
        local saved = store[key]
        local function Build()
            SearchIndex:BuildSegment(key, rows, function(built)
                settled()
                if not built then return end
                local snap = SearchIndex:SegmentSnapshot(key)
                store[key] = snap and { v = VERSION, text = text, snap = snap } or nil
            end)
        end
        if not (saved and saved.v == VERSION and (saved.text == text or aligned)) then
            Build()
            return
        end

        local tries = 0
        local function Restore()
            if tries > 0 and not Current() then return settled() end
            if SearchIndex:RestoreSegment(key, saved.snap, aligned or rows) then
                for g = 1, ghosts and #ghosts or 0 do SearchIndex:NoteRemoved(ghosts[g]) end
                return settled()
            end
            tries = tries + 1
            if tries < RETRIES then Utils.SafeAfter(0, Restore) else Build() end
        end
        Restore()
    end, 1.5, "segmentText " .. key)
end


local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    local rows = Database.staticRows
    Database.staticRows = nil
    if rows then Segments.Attach("static", rows) end
end)
