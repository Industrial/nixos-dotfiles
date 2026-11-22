local _, ns = ...












































local Database = ns.Database
local SearchIndex = {}
ns.SearchIndex = SearchIndex

local sbyte, ssub, sfind = string.byte, string.sub, string.find
local band, bor, bnot, lshift, rshift = bit.band, bit.bor, bit.bnot, bit.lshift, bit.rshift
local wipe = wipe
local pairs = pairs
local tsort = table.sort
local getmetatable, rawget = getmetatable, rawget
local SliceCheckpoint = ns.Utils.SliceCheckpoint
local Unquoted, QuotedOnly = ns.SearchText.Unquoted, ns.SearchText.QuotedOnly


local FUZZY_EDIT1_LEN, FUZZY_EDIT2_LEN = 5, 8
local ALL_CHARS_MASK = lshift(1, 26) - 1

local dirty = true
local builtCount = 0























local K_GRAM, K_WORD, K_INIT, K_DICT = 1, 2, 3, 4
local function NewSegment(key, saved)
    return {
        key = key, saved = saved, base = 0, n = 0, cap = 0,
        maps = { {}, {}, {}, {} }, tails = { {}, {}, {}, {} },
        dictId = {}, dictWord = {}, dictMask = {}, dictByFirst = {}, dictOne = {}, dictCount = 0,
        memo = {}, memoMulti = {}, memoCount = -1,
    }
end
local live = NewSegment("live", false)
local segments = { live }
local segByKey = { live = live }
local savedRanges = {}
local cur = live

local gramStr, gramTail = live.maps[K_GRAM], live.tails[K_GRAM]
local wordStr, wordTail = live.maps[K_WORD], live.tails[K_WORD]
local initStr, initTail = live.maps[K_INIT], live.tails[K_INIT]
local entryMask = {}
local lootIdx = {}
local slotEntry = {}
local serials = {}


local dead = {}


local special = {}
local nextSerial = 0
local deadCount = 0
local compactScheduled = false

local FREEZE_AT = 64
local schar = string.char
local tconcat = table.concat
local postScratch = {}
local freezeBuf = {}


local P0 = 35 + 35 * 92 + 35 * 8464
local MASK0 = P0 + 35 * 778688
local Unprintable3, Unprintable4
local function Printable3(v)
    local a = v % 92
    local r = (v - a) / 92
    local b = r % 92
    return schar(35 + a, 35 + b, 35 + (r - b) / 92)
end

local P2 = 35 + 35 * 92
local WIDTH2_ROWS = 8464
local function Printable2(v)
    local a = v % 92
    return schar(35 + a, 35 + (v - a) / 92)
end


local function FreezeTail(strMap, tailMap, key, width)
    local tail = tailMap[key]
    local n = #tail
    if n == 0 then return end
    for i = 1, n do
        local v = tail[i]
        if width == 2 then
            freezeBuf[i] = Printable2(v)
        elseif width then
            freezeBuf[i] = Printable3(v)
        else
            freezeBuf[i] = schar(band(v, 255), band(rshift(v, 8), 255), band(rshift(v, 16), 255))
        end
    end




    local bucket = strMap[key]
    if type(bucket) ~= "table" then
        bucket = { bucket }
        strMap[key] = bucket
    end
    bucket[#bucket + 1] = tconcat(freezeBuf, "", 1, n)
    wipe(tail)
end



local function PostAppend(strMap, tailMap, key, sid, width)
    local tail = tailMap[key]
    if not tail then tail = {}; tailMap[key] = tail end
    tail[#tail + 1] = sid
    if #tail >= FREEZE_AT then FreezeTail(strMap, tailMap, key, width) end
end



local function DecodeSeg(seg, kind, key, n)
    local strMap = seg.maps[kind]
    local str = strMap[key]
    if type(str) == "table" then

        if str[1] == nil then table.remove(str, 1) end
        str = tconcat(str)
        strMap[key] = str
    end
    if str then
        local len = #str
        local p = 1



        local width = seg.width
        if width == 2 then
            local off = seg.base - P2
            while p + 17 <= len do
                local a1, a2, b1, b2, c1, c2, d1, d2, e1, e2, f1, f2, g1, g2, h1, h2, i1, i2 = sbyte(str, p, p + 17)
                postScratch[n + 1] = a1 + a2 * 92 + off
                postScratch[n + 2] = b1 + b2 * 92 + off
                postScratch[n + 3] = c1 + c2 * 92 + off
                postScratch[n + 4] = d1 + d2 * 92 + off
                postScratch[n + 5] = e1 + e2 * 92 + off
                postScratch[n + 6] = f1 + f2 * 92 + off
                postScratch[n + 7] = g1 + g2 * 92 + off
                postScratch[n + 8] = h1 + h2 * 92 + off
                postScratch[n + 9] = i1 + i2 * 92 + off
                n = n + 9
                p = p + 18
            end
            while p + 1 <= len do
                n = n + 1
                local b1, b2 = sbyte(str, p, p + 1)
                postScratch[n] = b1 + b2 * 92 + off
                p = p + 2
            end
        elseif width then
            local off = seg.base - P0
            while p + 17 <= len do
                local a1, a2, a3, b1, b2, b3, c1, c2, c3, d1, d2, d3, e1, e2, e3, f1, f2, f3 = sbyte(str, p, p + 17)
                postScratch[n + 1] = a1 + a2 * 92 + a3 * 8464 + off
                postScratch[n + 2] = b1 + b2 * 92 + b3 * 8464 + off
                postScratch[n + 3] = c1 + c2 * 92 + c3 * 8464 + off
                postScratch[n + 4] = d1 + d2 * 92 + d3 * 8464 + off
                postScratch[n + 5] = e1 + e2 * 92 + e3 * 8464 + off
                postScratch[n + 6] = f1 + f2 * 92 + f3 * 8464 + off
                n = n + 6
                p = p + 18
            end
            while p + 2 <= len do
                n = n + 1
                local b1, b2, b3 = sbyte(str, p, p + 2)
                postScratch[n] = b1 + b2 * 92 + b3 * 8464 + off
                p = p + 3
            end
        else
            while p + 17 <= len do
                local a1, a2, a3, b1, b2, b3, c1, c2, c3, d1, d2, d3, e1, e2, e3, f1, f2, f3 = sbyte(str, p, p + 17)
                postScratch[n + 1] = a1 + a2 * 256 + a3 * 65536
                postScratch[n + 2] = b1 + b2 * 256 + b3 * 65536
                postScratch[n + 3] = c1 + c2 * 256 + c3 * 65536
                postScratch[n + 4] = d1 + d2 * 256 + d3 * 65536
                postScratch[n + 5] = e1 + e2 * 256 + e3 * 65536
                postScratch[n + 6] = f1 + f2 * 256 + f3 * 65536
                n = n + 6
                p = p + 18
            end
            while p + 2 <= len do
                n = n + 1
                local b1, b2, b3 = sbyte(str, p, p + 2)
                postScratch[n] = b1 + b2 * 256 + b3 * 65536
                p = p + 3
            end
        end
    end
    local tail = seg.tails[kind][key]
    if tail then
        local base = seg.base
        for i = 1, #tail do
            n = n + 1
            postScratch[n] = base + tail[i]
        end
    end
    return n
end



local function DecodePostings(kind, key)
    local n = 0
    for s = 1, #segments do n = DecodeSeg(segments[s], kind, key, n) end
    return n
end



local maskScratch = {}
local function DecodePostingsMasked(kind, key)
    local n = 0
    for s = 1, #segments do
        local seg = segments[s]
        local from = n + 1
        n = DecodeSeg(seg, kind, key, n)
        local masks = seg.masksStr
        if masks then

            local at = -3 - seg.base * 4
            for i = from, n do
                local p = postScratch[i] * 4 + at
                local a, b, c, d = sbyte(masks, p, p + 3)
                maskScratch[i] = a + b * 92 + c * 8464 + d * 778688 - MASK0
            end
        else
            for i = from, n do maskScratch[i] = entryMask[postScratch[i]] end
        end
    end
    return n
end

local seenGrams = {}






local WORD_SEEN_BASE = 65536
local INIT_SEEN_BASE = 131072
local counts = {}
local wordSet = {}


local strongSet = {}
local resultSet = {}
local candBuf = {}

local function maskOf(s, m)
    for i = 1, #s do
        local b = sbyte(s, i)
        if b >= 97 and b <= 122 then m = bor(m, lshift(1, b - 97)) end
    end
    return m
end









local seenWords = {}
local tokenBuf = {}
local gmatch = string.gmatch

local function PostWord(e, w)
    if #w < 3 then return end
    local seg = cur
    local id = seg.dictId[w]
    if not id then
        id = seg.dictCount + 1
        seg.dictCount = id
        seg.dictId[w], seg.dictWord[id] = id, w
        seg.dictMask[id] = maskOf(w, 0)
        local b = sbyte(w, 1)
        local list = seg.dictByFirst[b]
        if not list then list = {}; seg.dictByFirst[b] = list end
        list[#list + 1] = id
    end
    if not seenWords[id] then
        seenWords[id] = true
        if seg.dictOne[id] then
            PostAppend(seg.maps[K_DICT], seg.tails[K_DICT], id, e, seg.width)
        else
            seg.dictOne[id] = e
        end
    end
end


local function Cut(text)
    if not sfind(text, "[\128-\255]") then
        local n = 0
        for w in gmatch(text, "[%w']+") do
            n = n + 1
            tokenBuf[n] = w
        end
        for i = n + 1, #tokenBuf do tokenBuf[i] = nil end
        return tokenBuf, n
    end
    local words = ns.SearchText.Tokenize(text)
    return words, #words
end






local function IndexText(e, text, isKeyword)
    local seg = cur
    local width = seg.width
    local gm, gt = seg.maps[K_GRAM], seg.tails[K_GRAM]
    local wordStart = 1
    local len = #text
    for p = 1, len + 1 do
        local b = p <= len and sbyte(text, p) or 32
        if b == 32 then
            if p - wordStart >= 2 then
                for g = wordStart, p - 2 do
                    local g1, g2 = sbyte(text, g, g + 1)
                    local gram = g1 * 256 + g2
                    if not seenGrams[gram] then
                        seenGrams[gram] = true
                        PostAppend(gm, gt, gram, e, width)
                    end
                end
            end
            wordStart = p + 1
        end
    end
    local words, n = Cut(text)
    for i = 1, n do
        local w = words[i]
        if #w >= 2 then
            local b1, b2 = sbyte(w, 1, 2)
            local lead = b1 * 256 + b2
            if not seenGrams[WORD_SEEN_BASE + lead] then
                seenGrams[WORD_SEEN_BASE + lead] = true
                PostAppend(seg.maps[K_WORD], seg.tails[K_WORD], lead, e, width)
            end
        end
        PostWord(e, w)
    end

    if isKeyword and not (n == 1 and words[1] == text) then PostWord(e, text) end


    if n >= 2 then
        local key = sbyte(words[1], 1) * 256 + sbyte(words[2], 1)
        if not seenGrams[INIT_SEEN_BASE + key] then
            seenGrams[INIT_SEEN_BASE + key] = true
            PostAppend(seg.maps[K_INIT], seg.tails[K_INIT], key, e, width)
        end
    end
end



local function IndexTexts(e, text, isKeyword)
    IndexText(e, text, isKeyword)
    if sfind(text, "'", 1, true) then IndexText(e, Unquoted(text), isKeyword) end
end

local function IndexEntry(data)



    local sid = serials[data]
    if sid then
        dead[sid] = nil
        return
    end

    local seg, e = cur
    if seg.saved then
        e = seg.n + 1
        seg.n = e
        sid = seg.base + e
    else
        nextSerial = nextSerial + 1
        sid = nextSerial
        e = sid
    end
    serials[data] = sid
    slotEntry[sid] = data
    if data.lootEntry then
        lootIdx[#lootIdx + 1] = sid

        entryMask[sid] = ALL_CHARS_MASK
        return
    end
    wipe(seenGrams)
    wipe(seenWords)
    local m = 0




    local nameLower, kws
    local mt = getmetatable(data)
    local pc = mt and rawget(mt, "__pcCorpus")
    if pc then
        local ri = rawget(data, "_ri")
        nameLower = pc:NameLowerOf(ri)
        kws = pc:KeywordsOf(ri)
    else
        nameLower = data.nameLower
    end
    if nameLower then
        m = maskOf(nameLower, m)
        IndexTexts(e, nameLower)
        if sfind(nameLower, "[\128-\255]") then special[sid] = true end
    end
    kws = kws or data.keywordsLower or data.keywords
    if kws then
        for k = 1, #kws do
            local kw = kws[k]
            if kw then
                m = maskOf(kw, m)
                IndexTexts(e, kw, true)
                if sfind(kw, "[\128-\255]") then special[sid] = true end
            end
        end
    end


    local inst = not pc and data.instanceNameLower
    if inst then
        m = maskOf(inst, m)
        IndexTexts(e, inst, true)
        if sfind(inst, "[\128-\255]") then special[sid] = true end
    end

    if not pc and (rawget(data, "snippetKeywordLower") or rawget(data, "teleportNameLower")
                   or rawget(data, "scoreBonus")) then
        special[sid] = true
    end
    entryMask[sid] = m
end

local function InSaved(sid)
    for i = 1, #savedRanges do
        local seg = savedRanges[i]
        if sid > seg.base and sid <= seg.base + seg.cap then return seg end
    end
    return nil
end

local function WipeSegment(seg)
    for k = 1, 4 do wipe(seg.maps[k]); wipe(seg.tails[k]) end
    wipe(seg.dictId); wipe(seg.dictWord); wipe(seg.dictMask); wipe(seg.dictByFirst); wipe(seg.dictOne)
    seg.dictMaskStr, seg.dictOneStr = nil, nil
    seg.wordsStr, seg.offsStr, seg.byFirstStr, seg.masksStr = nil, nil, nil, nil
    wipe(seg.memo); wipe(seg.memoMulti)
    seg.dictCount, seg.memoCount = 0, -1
end



local function Restart()
    WipeSegment(live)
    if #savedRanges == 0 then
        wipe(entryMask)
        wipe(special)
        wipe(lootIdx)
        wipe(slotEntry)
        wipe(serials)
        wipe(dead)
        nextSerial = 0
    else
        for sid, data in pairs(slotEntry) do
            if not InSaved(sid) then
                slotEntry[sid], dead[sid], entryMask[sid], special[sid] = nil, nil, nil, nil
                if serials[data] == sid then serials[data] = nil end
            end
        end
        local n = 0
        for i = 1, #lootIdx do
            if InSaved(lootIdx[i]) then
                n = n + 1
                lootIdx[n] = lootIdx[i]
            end
        end
        for i = #lootIdx, n + 1, -1 do lootIdx[i] = nil end
    end
    deadCount = 0
    builtCount = 0
    dirty = false
end



local QUERY_BUILD_MS = 2

local lastQueryAt = -10
local function GrowBudget()
    return (GetTime() - lastQueryAt) < 1 and 4 or 2
end


local reading = false
local growing = false


local HOLD_S = 15
local held, heldAny = {}, false
local function Held(data, now)
    local untilAt = held[data.category]
    return untilAt ~= nil and untilAt > now
end


local builds = {}



local function Grow(budgetMs)
    if reading then return false end
    if dirty then Restart() end
    local dataArr = Database.uiSearchData
    local n = #dataArr


    if builtCount >= n then
        builtCount = n
        return true
    end
    local dps = debugprofilestop
    local start = dps and dps() or 0
    local now = heldAny and GetTime()
    local i = builtCount + 1
    while i <= n do
        local data = dataArr[i]
        if now and Held(data, now) then
            builtCount = i - 1
            return true
        end
        IndexEntry(data)
        i = i + 1
        if dps and (dps() - start) >= budgetMs then break end
    end
    builtCount = i - 1
    return builtCount >= n
end



local function GrowSliced()
    while true do
        while reading do coroutine.yield() end
        if dirty then Restart() end
        local data = Database.uiSearchData[builtCount + 1]
        if not data then return end
        if heldAny and Held(data, GetTime()) then return "held" end
        IndexEntry(data)
        builtCount = builtCount + 1
        if band(builtCount, 3) == 0 then SliceCheckpoint() end
    end
end



local function ScheduleGrow()
    if growing then return end
    growing = true
    ns.Utils.SafeAfter(0, function()
        ns.Utils.RunSliced(GrowSliced, function(ok, result)
            growing = false
            if not ok then return ns.Utils.ErrorHandler(result) end
            if result == "held" then return end
            if dirty or builtCount < #Database.uiSearchData then ScheduleGrow() end
        end, GrowBudget, "indexGrow")
    end)
end



function SearchIndex:Hold(category)
    if not category then return end
    held[category] = GetTime() + HOLD_S
    heldAny = true
    ns.Utils.SafeAfter(HOLD_S, ScheduleGrow)
end

function SearchIndex:Unhold(category)
    if not (category and held[category]) then return end
    held[category] = nil
    heldAny = next(held) ~= nil
    ScheduleGrow()
end



function SearchIndex:EnsureBudget(budgetMs)
    if Grow(budgetMs) then return true end
    ScheduleGrow()
    return false
end

function SearchIndex:MarkDirty()
    dirty = true
end


function SearchIndex:ReadCanceled()
    reading = false
end




local function TryCompact()
    compactScheduled = false
    if deadCount == 0 then return end



    local sf = ns.Search and ns.Search.GetSearchFrame and ns.Search:GetSearchFrame()
    if sf and sf:IsShown() then
        compactScheduled = true
        ns.Utils.SafeAfter(5, TryCompact)
        return
    end
    dirty = true
    ScheduleGrow()
end















function SearchIndex:NoteCompacted(n)
    if n < builtCount then builtCount = n end
    local dataArr = Database.uiSearchData
    for i = 1, builtCount do
        if not serials[dataArr[i]] then
            builtCount = i - 1
            return
        end
    end
end



function SearchIndex:NoteReplaced(oldEntry, newEntry)
    if oldEntry then self:NoteRemoved(oldEntry) end
    if newEntry then IndexEntry(newEntry) end
end

function SearchIndex:NoteRemoved(entry)
    local sid = serials[entry]
    if not sid or dead[sid] or not slotEntry[sid] then return end
    dead[sid] = true

    if InSaved(sid) then return end
    deadCount = deadCount + 1
    if not compactScheduled and ns.Utils and ns.Utils.SafeAfter then
        compactScheduled = true
        ns.Utils.SafeAfter(2, TryCompact)
    end
end



local function Release(data)
    if serials[data] then SearchIndex:NoteRemoved(data) end
    serials[data] = nil
end








local SEGMENT_SCHEMA = 4
local tinsert = table.insert

function Unprintable3(s, p)
    local a, b, c = sbyte(s, p, p + 2)
    return a + b * 92 + c * 8464 - P0
end
local function Printable4(v)
    local low = v % 778688
    return Printable3(low) .. schar(35 + (v - low) / 778688)
end
function Unprintable4(s, p)
    return Unprintable3(s, p) + (sbyte(s, p + 3) - 35) * 778688
end





local function PackMasks(seg)
    if seg.masksStr then return end
    local base, masks = seg.base, {}
    for i = 1, seg.n do
        local sid = base + i
        masks[i] = Printable4(entryMask[sid] or 0)
        entryMask[sid] = nil
    end
    seg.masksStr = tconcat(masks)
end

local function PackDict(seg)
    if seg.dictMaskStr then return end
    local n, dictWord = seg.dictCount, seg.dictWord
    local dmask, ones, offs = {}, {}, {}
    local pos = 1
    for id = 1, n do
        dmask[id] = Printable4(seg.dictMask[id])
        ones[id] = Printable3(seg.dictOne[id])
        offs[id] = pos
        pos = pos + #dictWord[id] + 1
    end
    seg.dictMaskStr, seg.dictOneStr = tconcat(dmask), tconcat(ones)
    seg.dictId, seg.dictMask, seg.dictOne = {}, {}, {}

    if pos > 778687 then return end
    for id = 1, n do offs[id] = Printable3(offs[id]) end
    offs[n + 1] = Printable3(pos)
    local byFirst = {}
    for b, list in pairs(seg.dictByFirst) do
        local parts = {}
        for i = 1, #list do parts[i] = Printable3(list[i]) end
        byFirst[b] = tconcat(parts)
    end
    seg.wordsStr = tconcat(dictWord, "\n", 1, n)
    seg.offsStr = tconcat(offs, "", 1, n + 1)
    seg.byFirstStr = byFirst
    seg.dictWord, seg.dictByFirst = {}, {}
end


local function FreezeSegment(seg)
    for k = 1, 4 do
        local strMap, tailMap = seg.maps[k], seg.tails[k]
        for key in pairs(tailMap) do FreezeTail(strMap, tailMap, key, seg.width) end
        wipe(tailMap)
        for key, v in pairs(strMap) do
            if type(v) == "table" then
                if v[1] == nil then table.remove(v, 1) end
                strMap[key] = tconcat(v)
            end
        end
    end
end


local function RowNameLower(data)
    local mt = getmetatable(data)
    local pc = mt and rawget(mt, "__pcCorpus")
    if pc then return pc:NameLowerOf(rawget(data, "_ri")) end
    return data.nameLower
end


local CHECK_EVERY = 64

local function Unlist(list, seg)
    for i = #list, 1, -1 do
        if list[i] == seg then table.remove(list, i) end
    end
end


local function RemoveRows(seg)
    local base = seg.base
    for i = 1, seg.n do
        local sid = base + i
        local data = slotEntry[sid]
        if data and serials[data] == sid then serials[data] = nil end
        slotEntry[sid], dead[sid], entryMask[sid], special[sid] = nil, nil, nil, nil
    end
    local n = 0
    for i = 1, #lootIdx do
        local sid = lootIdx[i]
        if sid <= base or sid > base + seg.cap then
            n = n + 1
            lootIdx[n] = sid
        end
    end
    for i = #lootIdx, n + 1, -1 do lootIdx[i] = nil end
end

local function Deactivate(seg, rewalk)
    Unlist(segments, seg)
    Unlist(savedRanges, seg)
    if segByKey[seg.key] == seg then segByKey[seg.key] = nil end
    RemoveRows(seg)

    if rewalk then builtCount = 0 end
end

local function Activate(seg)
    local old = segByKey[seg.key]
    if old and old ~= seg then Deactivate(old, false) end
    segByKey[seg.key] = seg

    tinsert(segments, 1, seg)
end




function SearchIndex:BuildSegment(key, rows, onDone)
    local seg = NewSegment(key, true)
    seg.base, seg.cap = nextSerial, #rows
    seg.width = #rows < WIDTH2_ROWS and 2 or 3
    nextSerial = nextSerial + #rows
    savedRanges[#savedRanges + 1] = seg
    local build = { rows = rows, moved = 0 }
    builds[#builds + 1] = build
    local function run()
        for i = 1, #rows do
            local data = rows[i]
            Release(data)
            cur = seg
            IndexEntry(data)
            cur = live
            build.moved = i
            if band(i, 3) == 0 then SliceCheckpoint() end
        end
        if seg.n ~= #rows then error("BuildSegment: a row is listed twice in " .. tostring(key)) end
        FreezeSegment(seg)
        PackDict(seg)
        PackMasks(seg)
        while reading do coroutine.yield() end
        Activate(seg)
    end
    ns.Utils.RunSliced(run, function(ok, err)
        cur = live
        Unlist(builds, build)
        if not ok then
            Unlist(savedRanges, seg)
            RemoveRows(seg)
            ns.Utils.ErrorHandler(err)
        end
        if onDone then onDone(ok) end
    end, GrowBudget, "indexSegment")
end



function SearchIndex:SegmentSnapshot(key)
    local seg = segByKey[key]
    if not (seg and seg.saved) then return nil end
    FreezeSegment(seg)
    local base, n = seg.base, seg.n
    PackMasks(seg)
    local sp, lt = {}, {}
    for i = 1, n do
        local sid = base + i
        if dead[sid] or not slotEntry[sid] then return nil end
        if special[sid] then sp[#sp + 1] = Printable3(i) end
        local data = slotEntry[sid]
        if data and data.lootEntry then lt[#lt + 1] = Printable3(i) end
    end
    PackDict(seg)
    local check = {}
    for i = 1, n, CHECK_EVERY do check[#check + 1] = RowNameLower(slotEntry[base + i]) or "" end
    return {
        v = SEGMENT_SCHEMA, n = n, width = seg.width, dictCount = seg.dictCount, check = check,
        gram = seg.maps[K_GRAM], word = seg.maps[K_WORD], init = seg.maps[K_INIT], dict = seg.maps[K_DICT],
        words = seg.wordsStr or tconcat(seg.dictWord, "\n", 1, seg.dictCount), offs = seg.offsStr,
        byFirst = seg.byFirstStr, dictMask = seg.dictMaskStr, ones = seg.dictOneStr,
        masks = seg.masksStr, special = tconcat(sp), loot = tconcat(lt),
    }
end



function SearchIndex:RestoreSegment(key, snap, rows)
    if reading or type(snap) ~= "table" or snap.v ~= SEGMENT_SCHEMA or snap.n ~= #rows then return false end
    if snap.width ~= (#rows < WIDTH2_ROWS and 2 or 3) then return false end
    local words, dmask, ones, em = snap.words, snap.dictMask, snap.ones, snap.masks
    local dc = snap.dictCount
    if type(words) ~= "string" or type(dc) ~= "number" or #dmask ~= dc * 4 or #ones ~= dc * 3
       or #em ~= snap.n * 4 or type(snap.check) ~= "table" then
        return false
    end
    local n = snap.n
    local check = snap.check
    for c = 1, #check do
        local row = rows[(c - 1) * CHECK_EVERY + 1]
        if not row or (RowNameLower(row) or "") ~= check[c] then return false end
    end
    local seg = NewSegment(key, true)
    seg.base, seg.cap, seg.n, seg.width = nextSerial, n, n, snap.width
    seg.maps = { snap.gram or {}, snap.word or {}, snap.init or {}, snap.dict or {} }
    seg.dictMaskStr, seg.dictOneStr = dmask, ones
    local offs = snap.offs
    if type(offs) == "string" then
        if #offs ~= (dc + 1) * 3 or type(snap.byFirst) ~= "table" then return false end
        seg.wordsStr, seg.offsStr, seg.byFirstStr = words, offs, snap.byFirst
    else

        local dictWord, dictByFirst = seg.dictWord, seg.dictByFirst
        local id = 0
        for w in gmatch(words, "[^\n]+") do
            id = id + 1
            dictWord[id] = w
            local b = sbyte(w, 1)
            local list = dictByFirst[b]
            if not list then list = {}; dictByFirst[b] = list end
            list[#list + 1] = id
        end
        if id ~= dc then return false end
    end
    seg.dictCount = dc
    nextSerial = nextSerial + n
    local base = seg.base
    for i = 1, n do
        local data = rows[i]
        Release(data)
        local sid = base + i
        serials[data], slotEntry[sid], dead[sid] = sid, data, nil
    end
    seg.masksStr = em
    local sp, lt = snap.special or "", snap.loot or ""
    for q = 1, #sp, 3 do special[base + Unprintable3(sp, q)] = true end
    for q = 1, #lt, 3 do lootIdx[#lootIdx + 1] = base + Unprintable3(lt, q) end
    savedRanges[#savedRanges + 1] = seg
    Activate(seg)
    return true
end



function SearchIndex:DropSegment(key)
    local seg = segByKey[key]
    if not (seg and seg.saved) then return false end
    Deactivate(seg, true)
    return true
end



local function Subsequence(x, q, qLen, xLen, xOff)
    local xi = 1
    for qi = 1, qLen do
        local qc = sbyte(q, qi)
        while xi <= xLen and sbyte(x, xOff + xi) ~= qc do xi = xi + 1 end
        if xi > xLen then return false end
        xi = xi + 1
    end
    return xi - 1 <= qLen * 2 - 1
end


local function OverBits(m, k)
    local n = 0
    while m ~= 0 do
        m = band(m, m - 1)
        n = n + 1
        if n > k then return true end
    end
    return false
end




local osaPrev2, osaPrev, osaCurr = {}, {}, {}
local function WithinEdits(a, b, la, lb, k, am, bm, bOff)
    local d = la - lb
    if d > k or -d > k then return false end
    if OverBits(band(am, bnot(bm)), k) or OverBits(band(bm, bnot(am)), k) then return false end
    local prev2, prev, curr = osaPrev2, osaPrev, osaCurr
    for j = 0, lb do prev[j] = j end
    for i = 1, la do
        curr[0] = i
        local rowMin = i
        local ca = sbyte(a, i)
        local caPrev = i > 1 and sbyte(a, i - 1) or nil
        for j = 1, lb do
            local cb = sbyte(b, bOff + j)
            local cost = ca == cb and 0 or 1
            local v = prev[j] + 1
            local ins = curr[j - 1] + 1
            if ins < v then v = ins end
            local sub = prev[j - 1] + cost
            if sub < v then v = sub end
            if i > 1 and j > 1 and ca == sbyte(b, bOff + j - 1) and caPrev == cb then
                local t = prev2[j - 2] + cost
                if t < v then v = t end
            end
            curr[j] = v
            if v < rowMin then rowMin = v end
        end
        if rowMin > k then return false end
        prev2, prev, curr = prev, curr, prev2
    end
    return prev[lb] <= k
end






local NO_HITS = {}
local memoEntries, MEMO_CAP = 0, 4096





local function AbbrevLength(L, xl, multi)
    if xl <= L or L > 8 then return false end
    if (L <= 4 and xl >= L * 2) or L / xl >= 0.6 then return true end
    return multi and L >= 3 and L / xl >= 0.45 or false
end

local function DictMask(seg, id)
    local s = seg.dictMaskStr
    if s then return Unprintable4(s, id * 4 - 3) end
    return seg.dictMask[id]
end

local function MatchingWords(seg, qw, L, multi)
    if seg.memoCount ~= seg.dictCount then
        wipe(seg.memo)
        wipe(seg.memoMulti)
        seg.memoCount = seg.dictCount
    end
    local memo = multi and seg.memoMulti or seg.memo
    local hit = memo[qw]
    if hit then return hit end
    if memoEntries >= MEMO_CAP then
        for s = 1, #segments do wipe(segments[s].memo); wipe(segments[s].memoMulti) end
        memoEntries = 0
    end
    memoEntries = memoEntries + 1
    hit = {}
    local q1, q2 = sbyte(qw, 1, 2)
    local qm = maskOf(qw, 0)
    local k = L >= FUZZY_EDIT2_LEN and 2 or (L >= FUZZY_EDIT1_LEN and 1 or 0)
    local offs = seg.offsStr
    if offs then
        local words, byFirst = seg.wordsStr, seg.byFirstStr
        local ids = byFirst[q1]
        for p = 1, ids and #ids or 0, 3 do
            if band(p, 1535) == 1535 then SliceCheckpoint() end
            local id = Unprintable3(ids, p)
            local at = Unprintable3(offs, id * 3 - 2)
            local xl = Unprintable3(offs, id * 3 + 1) - at - 1
            if (AbbrevLength(L, xl, multi) and Subsequence(words, qw, L, xl, at - 1))
               or (k > 0 and WithinEdits(qw, words, L, xl, k, qm, DictMask(seg, id), at - 1)) then
                hit[#hit + 1] = id
            end
        end
        if k > 0 and q2 and q2 ~= q1 then
            ids = byFirst[q2]
            for p = 1, ids and #ids or 0, 3 do
                local id = Unprintable3(ids, p)
                local at = Unprintable3(offs, id * 3 - 2)
                local xl = Unprintable3(offs, id * 3 + 1) - at - 1
                if sbyte(words, at + 1) == q1 and WithinEdits(qw, words, L, xl, k, qm, DictMask(seg, id), at - 1) then
                    hit[#hit + 1] = id
                end
            end
        end
    else
        local dictWord, dictByFirst = seg.dictWord, seg.dictByFirst
        local list = dictByFirst[q1]
        for i = 1, list and #list or 0 do
            if band(i, 511) == 0 then SliceCheckpoint() end
            local id = list[i]
            local x = dictWord[id]
            local xl = #x
            if (AbbrevLength(L, xl, multi) and Subsequence(x, qw, L, xl, 0))
               or (k > 0 and WithinEdits(qw, x, L, xl, k, qm, DictMask(seg, id), 0)) then
                hit[#hit + 1] = id
            end
        end
        if k > 0 and q2 and q2 ~= q1 then
            list = dictByFirst[q2]
            for i = 1, list and #list or 0 do
                local id = list[i]
                local x = dictWord[id]
                if sbyte(x, 2) == q1 and WithinEdits(qw, x, L, #x, k, qm, DictMask(seg, id), 0) then
                    hit[#hit + 1] = id
                end
            end
        end
    end
    if #hit == 0 then hit = NO_HITS end
    memo[qw] = hit
    return hit
end


local function PostingCount(kind, key)
    local n = 0
    for s = 1, #segments do
        local seg = segments[s]
        local str = seg.maps[kind][key]
        local bytes = 0
        if type(str) == "table" then
            for i = 1, #str do bytes = bytes + #str[i] end
        elseif str then
            bytes = #str
        end
        n = n + bytes / (seg.width or 3)
        local tail = seg.tails[kind][key]
        if tail then n = n + #tail end
    end
    return n
end



local function Holds(text, w)
    return sfind(text, w, 1, true) ~= nil
        or (QuotedOnly(text, w) and sfind(Unquoted(text), w, 1, true) ~= nil)
end

local function HoldsText(sid, w)
    local data = slotEntry[sid]
    local nameLower, kws
    local mt = getmetatable(data)
    local pc = mt and rawget(mt, "__pcCorpus")
    if pc then
        local ri = rawget(data, "_ri")
        nameLower = pc:NameLowerOf(ri)
        kws = pc:KeywordsOf(ri)
    else
        nameLower = data.nameLower
    end
    if nameLower and Holds(nameLower, w) then return true end
    kws = kws or data.keywordsLower or data.keywords
    for k = 1, kws and #kws or 0 do
        local kw = kws[k]
        if kw and Holds(kw, w) then return true end
    end
    local inst = data.instanceNameLower
    return inst ~= nil and Holds(inst, w)
end




local function AddContiguous(w)
    local wl = #w
    if wl < 2 then return end
    local rare1, rare2, n1, n2
    for g = 1, wl - 1 do
        local g1, g2 = sbyte(w, g, g + 1)
        local gram = g1 * 256 + g2
        if gram ~= rare1 and gram ~= rare2 then
            local n = PostingCount(K_GRAM, gram)
            if n == 0 then return end
            if not n1 or n < n1 then
                rare2, n2, rare1, n1 = rare1, n1, gram, n
            elseif not n2 or n < n2 then
                rare2, n2 = gram, n
            end
        end
    end
    local pn = DecodePostings(K_GRAM, rare1)
    if not rare2 then
        for pi = 1, pn do wordSet[postScratch[pi]] = true end
        return
    end
    wipe(counts)
    for pi = 1, pn do counts[postScratch[pi]] = true end
    pn = DecodePostings(K_GRAM, rare2)

    for pi = 1, pn do
        local e = postScratch[pi]
        if counts[e] and not wordSet[e] and HoldsText(e, w) then wordSet[e] = true end
    end
end


local function CollectWord(qw, multi, split)
    wipe(wordSet)
    if split then wipe(strongSet) end
    local L = #qw
    AddContiguous(qw)
    if L >= 3 and sbyte(qw, L) == 115 then
        AddContiguous(ssub(qw, 1, L - 1))
    end



    local qb1, qb2 = sbyte(qw, 1, 2)
    local leadKey = qb1 * 256 + qb2
    do
        local pn = DecodePostingsMasked(K_INIT, leadKey)
        if pn > 0 then
            local qm = maskOf(qw, 0)
            for pi = 1, pn do
                local e = postScratch[pi]
                if band(qm, maskScratch[pi]) == qm then
                    wordSet[e] = true
                    if split then strongSet[e] = true end
                end
            end
        end
    end

    if split then
        local pn = DecodePostings(K_WORD, leadKey)
        for pi = 1, pn do strongSet[postScratch[pi]] = true end
    end



    if L >= 4 then
        local pn = DecodePostingsMasked(K_WORD, leadKey)
        if pn > 0 then
            local qm = maskOf(qw, 0)
            wipe(counts)
            local leads = 0
            for pi = 1, pn do
                local e = postScratch[pi]
                if not wordSet[e] and band(qm, maskScratch[pi]) == qm then
                    counts[e] = true
                    leads = leads + 1
                end
            end
            for j = 3, leads > 0 and L - 1 or 0 do
                local s1, s2 = sbyte(qw, j, j + 1)
                local key = s1 * 256 + s2
                local seenKey = false
                for k = 3, j - 1 do
                    local k1, k2 = sbyte(qw, k, k + 1)
                    if k1 * 256 + k2 == key then seenKey = true break end
                end
                if not seenKey then
                    local sn = DecodePostings(K_WORD, key)
                    for pi = 1, sn do
                        local e = postScratch[pi]
                        if counts[e] then
                            wordSet[e] = true
                            counts[e] = nil
                        end
                    end
                end
            end
        end
    end


    if L >= 3 then
        for s = 1, #segments do
            local seg = segments[s]
            local ids = MatchingWords(seg, qw, L, multi)
            local base, ones, onesStr = seg.base, seg.dictOne, seg.dictOneStr
            for i = 1, #ids do
                local id = ids[i]
                local one = base + (onesStr and Unprintable3(onesStr, id * 3 - 2) or ones[id])
                wordSet[one] = true
                if split then strongSet[one] = true end
                local pn = DecodeSeg(seg, K_DICT, id, 0)
                for pi = 1, pn do
                    local e = postScratch[pi]
                    wordSet[e] = true
                    if split then strongSet[e] = true end
                end
            end
        end
    end
    for li = 1, #lootIdx do
        wordSet[lootIdx[li]] = true
        if split then strongSet[lootIdx[li]] = true end
    end
end











local restBuf = {}
local cutSet = {}

local function Holding(words, multi, split, into)
    wipe(into)
    local first, usable = true, 0
    for qi = 1, #words do
        local qw = words[qi]
        if #qw >= 2 then
            usable = usable + 1
            CollectWord(qw, multi, split)
            if first then
                first = false
                for e in pairs(wordSet) do
                    into[e] = true
                end
            else
                for e in pairs(into) do
                    if not wordSet[e] then
                        into[e] = nil
                    end
                end
            end
        end
    end
    return usable
end

function SearchIndex:Candidates(queryWords, split, cutWords, steered)

    reading = false
    lastQueryAt = GetTime()
    local dataArr = Database.uiSearchData
    if not Grow(QUERY_BUILD_MS) then ScheduleGrow() end
    if builtCount == 0 then return nil end
    local tailFrom, readSerial = builtCount, nextSerial
    reading = true

    local multi = #queryWords >= 2
    split = split and not multi
    local usable = Holding(queryWords, multi, split, resultSet)
    if cutWords and Holding(cutWords, true, false, cutSet) > 0 then
        for sid in pairs(cutSet) do
            local data = slotEntry[sid]
            if data and steered[data.category] then resultSet[sid] = true end
        end
    end
    reading = false
    if usable == 0 then return nil end
    local n, rn = 0, 0
    for sid in pairs(resultSet) do
        if slotEntry[sid] and not dead[sid] then
            if split and not strongSet[sid] and not special[sid] then
                rn = rn + 1
                restBuf[rn] = sid
            else
                n = n + 1
                candBuf[n] = sid
            end
        end
    end
    for i = n + 1, #candBuf do
        candBuf[i] = nil
    end
    for i = rn + 1, #restBuf do
        restBuf[i] = nil
    end


    tsort(candBuf)
    for i = 1, n do
        candBuf[i] = slotEntry[candBuf[i]]
    end

    if builtCount < tailFrom then tailFrom = builtCount end
    for i = tailFrom + 1, #dataArr do
        local data = dataArr[i]
        local sid = serials[data]
        if not sid or sid > readSerial then
            n = n + 1
            candBuf[n] = data
        end
    end
    for b = 1, #builds do
        local build = builds[b]
        for i = 1, build.moved do
            local data = build.rows[i]
            local sid = serials[data]
            if sid and slotEntry[sid] and not dead[sid] then
                n = n + 1
                candBuf[n] = data
            end
        end
    end
    local restFrom
    if rn > 0 then
        restFrom = n + 1
        tsort(restBuf)
        for i = 1, rn do candBuf[n + i] = slotEntry[restBuf[i]] end
        n = n + rn
    end
    return candBuf, n, restFrom
end



function SearchIndex:TrimScratch()

    if reading then return end
    postScratch, maskScratch, counts = {}, {}, {}
    wordSet, strongSet, resultSet, candBuf, restBuf = {}, {}, {}, {}, {}
    osaPrev2, osaPrev, osaCurr = {}, {}, {}
    for s = 1, #segments do
        local seg = segments[s]
        seg.memo, seg.memoMulti = {}, {}
    end
    memoEntries = 0
end




function SearchIndex:_DebugPeek()
    return {
        gramStr = gramStr, gramTail = gramTail, wordStr = wordStr,
        wordTail = wordTail, initStr = initStr, initTail = initTail,
        entryMask = entryMask, lootIdx = lootIdx, slotEntry = slotEntry,
        serials = serials, builtCount = builtCount, dead = dead,
        alive = setmetatable({}, { __index = function(_, sid)
            return (slotEntry[sid] ~= nil and not dead[sid]) or nil
        end }),
        dictId = live.dictId, dictOne = live.dictOne, dictTail = live.tails[K_DICT], dictStr = live.maps[K_DICT],
        dictCount = live.dictCount, segments = segments, deadCount = deadCount,
    }
end
