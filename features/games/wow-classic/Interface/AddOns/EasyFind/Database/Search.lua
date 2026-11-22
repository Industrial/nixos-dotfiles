local _, ns = ...






local Database = ns.Database
local Utils = ns.Utils
local SearchText = ns.SearchText

if not Database then return end

local tsort = Utils.tsort
local sfind, ssub = Utils.sfind, Utils.ssub
local sgsub = string.gsub
local sbyte = string.byte
local band, bor, bnot, lshift = bit.band, bit.bor, bit.bnot, bit.lshift
local tconcat = table.concat
local tremove = table.remove





local slower = SearchText.Normalize
local stokenize = SearchText.Tokenize
local isAscii = SearchText.IsAscii
local Unquoted, QuotedOnly = SearchText.Unquoted, SearchText.QuotedOnly
local mmin, mmax, mabs, mfloor = Utils.mmin, Utils.mmax, Utils.mabs, Utils.mfloor
local wipe = wipe
local rawget = rawget
local SliceCheckpoint = Utils.SliceCheckpoint
local uiSearchData = Database.uiSearchData

local function IsLootStatSearchWord(word)
    return Database:IsLootStatSearchWord(word)
end

local function IsLootSlotSearchWord(word)
    return Database:IsLootSlotSearchWord(word)
end

local BOSS_QUERY_WORDS = ns.BOSS_QUERY_WORDS
local STAT_QUERY_WORDS = ns.STAT_QUERY_WORDS
local Steer = ns.SearchSteer

local tagWords = Steer and Steer.categoriesOf




local wordCache = {}
Database._wordCache = wordCache
local EMPTY_WORDS = {}

local transientName
local transientWords, transientFilled = {}, false




local function GetWords(str)
    if not str or str == "" then return EMPTY_WORDS end
    local cached = wordCache[str]
    if cached then return cached end
    if str == transientName then
        if not transientFilled then
            transientFilled = true
            wipe(transientWords)
            if isAscii(str) then
                for w in str:gmatch("[%w']+") do transientWords[#transientWords + 1] = w end
            else
                local t = stokenize(str)
                for i = 1, #t do transientWords[i] = t[i] end
            end
        end
        return transientWords
    end
    local words
    if isAscii(str) then
        words = {}
        for w in str:gmatch("[%w']+") do
            words[#words + 1] = w
        end
    else
        words = stokenize(str)
    end
    wordCache[str] = words
    return words
end

local SEARCH_WORD_SYNONYMS = {
    tmog = "transmog",
    xmog = "transmog",
}





function Database:NormalizeSearchQuery(query)
    if not query or query == "" then return query end
    return (sgsub(query, "%f[%w](%w+)%f[%W]", SEARCH_WORD_SYNONYMS))
end

local dlPrev2, dlPrev, dlCurr = {}, {}, {}

local scoreNameUsedWords = {}









local TIE_CATEGORY_RANK = { Talent = 1, Talents = 1, Bag = 2, Bank = 2, Warband = 2,
    ["Game Settings"] = 3, Item = 5, Loot = 5, Profession = 6, ["AddOn Settings"] = 8 }
local function TieRank(d, category)
    local rank = TIE_CATEGORY_RANK[category]
    if rank then return rank end
    local ext = ns.Extensions
    if ext and ext.ProviderOf and ext.ProviderOf(d) then return 9 end
    return 4
end
local function TieCategoryLess(a, b)
    local ac, bc = a.category or "", b.category or ""
    if ac == bc then return false end
    local ar, br = TieRank(a, ac), TieRank(b, bc)
    if ar ~= br then return ar < br end
    return ac < bc
end
Database.TieCategoryLess = TieCategoryLess

local function scoreDescending(a, b)
    if a.score ~= b.score then return a.score > b.score end
    local an, bn = a.data.nameLower or "", b.data.nameLower or ""
    if #an ~= #bn then return #an < #bn end
    if an ~= bn then return an < bn end
    return TieCategoryLess(a.data, b.data)
end



local RESULT_CAP = 250
local heapProbe = {}


local REST_MAX_SCORE = 30

local function HeapUp(heap, i)
    local item = heap[i]
    while i > 1 do
        local p = (i - i % 2) / 2
        local parent = heap[p]
        if not scoreDescending(parent, item) then break end
        heap[i] = parent
        i = p
    end
    heap[i] = item
end

local function HeapDown(heap, n)
    local i, item = 1, heap[1]
    while true do
        local c = i * 2
        if c > n then break end
        if c < n and scoreDescending(heap[c], heap[c + 1]) then c = c + 1 end
        local child = heap[c]
        if not scoreDescending(item, child) then break end
        heap[i] = child
        i = c
    end
    heap[i] = item
end



local FUZZY_BLOCKLIST = {
    ["pvp"] = { ["pve"] = true },
    ["pve"] = { ["pvp"] = true },


    ["agility"]   = { ["ability"] = true, ["abilities"] = true },
    ["ability"]   = { ["agility"] = true },
    ["abilities"] = { ["agility"] = true },
}







local STOPWORDS = {
    ["of"] = true, ["the"] = true, ["a"] = true, ["an"] = true,
    ["and"] = true, ["or"] = true, ["in"] = true, ["on"] = true,
    ["at"] = true, ["by"] = true, ["for"] = true, ["to"] = true,
    ["with"] = true, ["from"] = true,
}






local EXACT_MATCH_SCORE = 1000




local NAME_PREFIX_SCORE = 500




local NAME_REORDERED_SCORE = 495



local SHORT_KEYWORD_SCORE = 600





local function StopwordExtension(text, query, queryLen)
    local words = GetWords(text)
    local best = 0
    for wi = 1, #words do
        local w = words[wi]
        if #w > queryLen then
            if sfind(w, query, 1, true) == 1 then
                if wi == 1 then return 3 end
                if best < 2 then best = 2 end
            elseif best < 1 and sfind(w, query, 1, true) then
                best = 1
            end
        end
    end
    return best
end






function Database:FindAtWordBoundary(text, query)
    local found = sfind(text, query, 1, true)
    if not found then return false end
    if found == 1 then return true end

    while found do
        local prev = sbyte(text, found - 1)
        if prev == 32 or prev == 45 or prev == 40
           or prev == 58 or prev == 47 or prev == 46 then
            return true
        end
        found = sfind(text, query, found + 1, true)
    end
    return false
end

function Database:ScoreInitials(text, query)
    local words = GetWords(text)
    if #words < 2 then return 0 end

    local blocked = FUZZY_BLOCKLIST[query]
    if blocked then
        for wi = 1, #words do
            if blocked[words[wi]] then return 0 end
        end
    end

    local queryLen = #query
    local numWords = #words


    if queryLen <= numWords then
        local allMatch = true
        for i = 1, queryLen do
            if sbyte(query, i) ~= sbyte(words[i], 1) then
                allMatch = false
                break
            end
        end
        if allMatch then
            local bonus = (queryLen == numWords) and 135 or 130
            return bonus
        end
    end



    local qi = 1
    local wordsMatched = 0
    for wi = 1, numWords do
        if qi > queryLen then break end
        local w = words[wi]
        local matchLen = 0
        while qi + matchLen <= queryLen and matchLen < #w do
            if sbyte(query, qi + matchLen) == sbyte(w, matchLen + 1) then
                matchLen = matchLen + 1
            else
                break
            end
        end





        if matchLen >= 2 then
            qi = qi + matchLen
            wordsMatched = wordsMatched + 1
        elseif wordsMatched > 0 and not STOPWORDS[w] then
            break
        end
    end
    if qi > queryLen and wordsMatched >= 2 then
        return 110 + mmin(wordsMatched * 3, 20)
    end

    return 0
end





local FUZZY_EDIT1_LEN, FUZZY_EDIT2_LEN, ABBREV_MIN_LEN = 5, 8, 3


local ABBREV_MAX_LEN = 5

function Database:ScoreFuzzy(text, query, queryLen)

    if Database._disableFuzzy then return 0 end


    local maxEdits
    if queryLen >= FUZZY_EDIT2_LEN then maxEdits = 2
    elseif queryLen >= FUZZY_EDIT1_LEN then maxEdits = 1
    else return 0
    end

    local queryFirst, querySecond = sbyte(query, 1, 2)
    local bestScore = 0
    local blocked = FUZZY_BLOCKLIST[query]
    local textWords = GetWords(text)
    for wi = 1, #textWords do
        local word = textWords[wi]



        local w1 = sbyte(word, 1)
        if (w1 == queryFirst or (w1 == querySecond and sbyte(word, 2) == queryFirst))
           and not (blocked and blocked[word]) then
            local wordLen = #word
            local lenDiff = wordLen - queryLen
            if lenDiff < 0 then lenDiff = -lenDiff end
            if lenDiff <= maxEdits then
                local dist = Database:DamerauLevenshtein(query, word, queryLen, wordLen)
                if dist == 1 and maxEdits >= 1 then
                    bestScore = mmax(bestScore, 85)
                elseif dist == 2 and maxEdits >= 2 then
                    bestScore = mmax(bestScore, 45)
                end
            end
        end
    end
    return bestScore
end


function Database:IsSubsequence(word, query, queryLen)
    if sbyte(word, 1) ~= sbyte(query, 1) then return false end
    local wi = 1
    local wordLen = #word
    local firstPos
    for qi = 1, queryLen do
        local qc = sbyte(query, qi)
        local found = false
        while wi <= wordLen do
            if sbyte(word, wi) == qc then
                if not firstPos then firstPos = wi end
                wi = wi + 1
                found = true
                break
            end
            wi = wi + 1
        end
        if not found then return false end
    end

    return (wi - 1) - firstPos + 1 <= queryLen * 2 - 1
end

local function DistanceCapped2(s1, s2, len1, len2)
    local prev2, prev, curr = dlPrev2, dlPrev, dlCurr

    for j = 0, len2 do prev[j] = j end

    for i = 1, len1 do
        curr[0] = i
        local minInRow = i
        local c1 = sbyte(s1, i)
        local c1Prev = i > 1 and sbyte(s1, i - 1) or nil
        for j = 1, len2 do
            local c2 = sbyte(s2, j)
            local cost = (c1 == c2) and 0 or 1
            curr[j] = mmin(
                prev[j] + 1,
                curr[j - 1] + 1,
                prev[j - 1] + cost
            )
            if i > 1 and j > 1
                and c1 == sbyte(s2, j - 1)
                and c1Prev == c2 then
                curr[j] = mmin(curr[j], prev2[j - 2] + cost)
            end
            if curr[j] < minInRow then minInRow = curr[j] end
        end
        if minInRow > 2 then return 3 end
        prev2, prev, curr = prev, curr, prev2
    end
    return prev[len2]
end




local dlMemo, dlMemoRows = {}, 0
function Database:DamerauLevenshtein(s1, s2, len1, len2)
    if Database._disableFuzzy then return 3 end
    if mabs(len1 - len2) > 2 then return 3 end
    local row = dlMemo[s1]
    if row then
        local d = row[s2]
        if d then return d end
    else
        if dlMemoRows >= 64 then
            wipe(dlMemo)
            dlMemoRows = 0
        end
        row = {}
        dlMemo[s1] = row
        dlMemoRows = dlMemoRows + 1
    end
    local d = DistanceCapped2(s1, s2, len1, len2)
    row[s2] = d
    return d
end





local nameMaskCache = {}
local lastCMQuery, lastCMMask
local lastCMExtra, lastCMExtraN = {}, 0

local function ComputeCharMask(s)
    local m = 0
    for i = 1, #s do
        local b = sbyte(s, i)
        if b >= 97 and b <= 122 then m = bor(m, lshift(1, b - 97)) end
    end
    return m
end

local function ComputeQueryMask(query)
    lastCMExtraN = 0
    local m = 0
    for i = 1, #query do
        local b = sbyte(query, i)
        if b >= 97 and b <= 122 then
            m = bor(m, lshift(1, b - 97))
        elseif b ~= 32 then
            local c = ssub(query, i, i)
            local dup = false
            for e = 1, lastCMExtraN do
                if lastCMExtra[e] == c then dup = true; break end
            end
            if not dup then
                lastCMExtraN = lastCMExtraN + 1
                lastCMExtra[lastCMExtraN] = c
            end
        end
    end
    return m
end

function Database:CouldMatch(text, query)
    if query ~= lastCMQuery then
        lastCMQuery = query
        lastCMMask = ComputeQueryMask(query)
    end
    local tm = nameMaskCache[text]
    if not tm then
        tm = ComputeCharMask(text)
        if text ~= transientName then nameMaskCache[text] = tm end
    end
    if band(lastCMMask, tm) ~= lastCMMask then return false end
    for i = 1, lastCMExtraN do
        if not sfind(text, lastCMExtra[i], 1, true) then return false end
    end
    return true
end







local wordInitCache = {}
local function WordInitMask(text)
    local m = wordInitCache[text]
    if m then return m end
    m = 0
    local words = GetWords(text)
    for i = 1, #words do
        local b = sbyte(words[i], 1)
        if b and b >= 97 and b <= 122 then m = bor(m, lshift(1, b - 97)) end
    end
    if text ~= transientName then wordInitCache[text] = m end
    return m
end







local function KeywordCouldMatch(kw, queryWord, queryWordLen)
    if queryWord ~= lastCMQuery then
        lastCMQuery = queryWord
        lastCMMask = ComputeQueryMask(queryWord)
    end
    local tm = nameMaskCache[kw]
    if not tm then tm = ComputeCharMask(kw); nameMaskCache[kw] = tm end
    local present = band(lastCMMask, tm)
    if present == lastCMMask then return true end
    local missing = lastCMMask - present
    local allowed = 0
    if queryWordLen >= FUZZY_EDIT2_LEN then
        allowed = 2
    elseif queryWordLen >= FUZZY_EDIT1_LEN then
        allowed = 1
    end
    if allowed == 0 then return false end
    local n = 0
    while missing ~= 0 do
        missing = band(missing, missing - 1)
        n = n + 1
        if n > allowed then return false end
    end
    return true
end















local GATE = {
    masks = {}, allows = {}, firstBits = {}, count = 0,
    sawNil = false, gatedN = 0, scoped = false, fillPending = false,
}




local AccumulateGateMasks = Utils.AccumulateGateMasks

local function FillEntryGateMask(e)
    if e.lootEntry then
        e._efGateMask = false
        return
    end
    local cm, im = 0, 0
    if e.nameLower then cm, im = AccumulateGateMasks(e.nameLower, cm, im) end



    local inst = e.instanceNameLower or (e.instanceName and slower(e.instanceName))
    if inst then cm, im = AccumulateGateMasks(inst, cm, im) end
    if e.teleportNameLower then cm, im = AccumulateGateMasks(e.teleportNameLower, cm, im) end
    if e.teleportNameEnLower then cm, im = AccumulateGateMasks(e.teleportNameEnLower, cm, im) end
    if e.snippetKeywordLower then cm, im = AccumulateGateMasks(e.snippetKeywordLower, cm, im) end
    local kws = e.keywordsLower or e.keywords
    if kws then
        for k = 1, #kws do
            local kw = kws[k]
            if type(kw) == "string" then cm, im = AccumulateGateMasks(kw, cm, im) end
        end
    end
    e._efGateMask = cm
    e._efGateInit = im
end

local GATE_FILL_STEP = 400
local FillGateMasksStep
local function ScheduleGateMaskFill()
    if GATE.fillPending then return end
    GATE.fillPending = true
    GATE.fillIdx = 1
    Utils.SafeAfter(0, FillGateMasksStep)
end


local GATE_FILL_MS = 1.5
FillGateMasksStep = function()
    local data = Database.uiSearchData
    local i = GATE.fillIdx or 1
    local n = #data
    local filled = 0
    local clock = debugprofilestop
    local stop = clock and clock() + GATE_FILL_MS
    while i <= n and filled < GATE_FILL_STEP and not (stop and band(filled, 15) == 15 and clock() > stop) do
        local e = data[i]
        if e._efGateMask == nil then
            FillEntryGateMask(e)
            filled = filled + 1
        end
        i = i + 1
    end
    if i <= n then
        GATE.fillIdx = i
        Utils.SafeAfter(0, FillGateMasksStep)
    else
        GATE.fillPending = false
        GATE.fillIdx = nil
    end
end

function Database:PrimeSearchGate()
    local data = self.uiSearchData
    for i = 1, #data do
        if data[i]._efGateMask == nil then FillEntryGateMask(data[i]) end
    end
    GATE.fillPending = false
    GATE.fillIdx = nil
end

local function GateSkipsEntry(data)
    local gm = data._efGateMask
    if gm == nil then
        GATE.sawNil = true
        return false
    end
    if not gm then return false end
    local masks, allows, firstBits, count, scoped =
        GATE.masks, GATE.allows, GATE.firstBits, GATE.count, GATE.scoped
    if scoped and scoped[data.category] then return false end
    for w = 1, count do
        local missing = band(masks[w], bnot(gm))
        if missing ~= 0 then
            local skip = true
            local budget = allows[w]
            if budget > 0 then
                local fb = firstBits[w]
                if fb == 0 or band(data._efGateInit or 0, fb) ~= 0 then
                    local c = 0
                    repeat
                        c = c + 1
                        missing = band(missing, missing - 1)
                    until missing == 0 or c > budget
                    skip = missing ~= 0
                end
            end
            if skip then
                GATE.gatedN = GATE.gatedN + 1
                return true
            end
        end
    end
    return false
end





local function QueryAsksFor(queryWords, askWords)
    if not (queryWords and askWords) then return false end
    for i = 1, #queryWords do
        local w = queryWords[i]
        for j = 1, #askWords do
            local ask = askWords[j]
            if w == ask or (#w >= 3 and #ask > #w and ssub(ask, 1, #w) == w) then
                return true
            end
        end
    end
    return false
end
Database.QueryAsksFor = QueryAsksFor



local function ScoreNameAs(nameLower, query, queryLen, optQueryWords, plain)
    if ssub(query, queryLen, queryLen) == " " then
        query = query:match("^(.-)%s+$") or query
        queryLen = #query
        if queryLen == 0 then return 0 end
    end


    local found = sfind(nameLower, query, 1, true)
    if not found and not Database:CouldMatch(nameLower, query) then return 0 end

    if STOPWORDS[query] then
        if nameLower == query then return EXACT_MATCH_SCORE end
        local ext = StopwordExtension(nameLower, query, queryLen)
        if ext == 3 then return NAME_PREFIX_SCORE end
        if ext == 2 then return 120 end
        return ext == 1 and 30 or 0
    end

    local score = 0

    if nameLower == query then
        score = EXACT_MATCH_SCORE
    elseif found == 1 then
        score = NAME_PREFIX_SCORE
    elseif found and Database:FindAtWordBoundary(nameLower, query) then
        score = 120
    elseif found then
        score = 30
    end

    if score >= 130 then return score end






    local qInitBit = 0
    local qFirst = sbyte(query, 1)
    if qFirst >= 97 and qFirst <= 122 then qInitBit = lshift(1, qFirst - 97) end
    local nameHasQueryInitial = qInitBit == 0
        or band(WordInitMask(nameLower), qInitBit) ~= 0

    if nameHasQueryInitial and score < 130 and not plain then
        local initScore = Database:ScoreInitials(nameLower, query)
        if initScore > score then score = initScore end
    end



    local fuzzyInitialOk = nameHasQueryInitial
    if not fuzzyInitialOk and queryLen >= FUZZY_EDIT1_LEN then
        local qSecond = sbyte(query, 2)
        if qSecond and qSecond >= 97 and qSecond <= 122 then
            fuzzyInitialOk = band(WordInitMask(nameLower), lshift(1, qSecond - 97)) ~= 0
        end
    end
    if fuzzyInitialOk and score < 100 and queryLen >= FUZZY_EDIT1_LEN then
        local fuzzyScore = Database:ScoreFuzzy(nameLower, query, queryLen)
        if fuzzyScore > score then score = fuzzyScore end
    end


    if nameHasQueryInitial and score < 50 and queryLen >= ABBREV_MIN_LEN and not plain and not sfind(query, " ", 1, true) then
        local nameWords = GetWords(nameLower)
        for wi = 1, #nameWords do
            local word = nameWords[wi]
            local wordLen = #word
            if queryLen <= 4 then
                if wordLen >= queryLen * 2 and Database:IsSubsequence(word, query, queryLen) then
                    score = mmax(score, 55)
                    break
                end
            elseif queryLen <= ABBREV_MAX_LEN and wordLen > queryLen and queryLen / wordLen >= 0.6 then
                if Database:IsSubsequence(word, query, queryLen) then
                    score = mmax(score, 60)
                    break
                end
            end
        end
    end



    if score < 100 and sfind(query, " ", 1, true) then


        local queryWords = optQueryWords or GetWords(query)
        if #queryWords >= 2 then
            local nameWords = GetWords(nameLower)
            local allMatched = true
            local totalWordScore = 0
            wipe(scoreNameUsedWords)
            local usedNameWords = scoreNameUsedWords
            for qwi = 1, #queryWords do
                local qw = queryWords[qwi]
                local qwLen = #qw
                local bestWordScore = 0
                local bestIdx = 0
                for ni = 1, #nameWords do
                    if not usedNameWords[ni] then
                        local nw = nameWords[ni]
                        local ws = 0
                        if nw == qw then
                            ws = 100
                        elseif sfind(nw, qw, 1, true) == 1 then
                            ws = 90
                        elseif sfind(nw, qw, 1, true) then
                            ws = 50
                        elseif qwLen >= FUZZY_EDIT1_LEN
                           and (sbyte(nw, 1) == sbyte(qw, 1)
                                or (sbyte(nw, 1) == sbyte(qw, 2) and sbyte(nw, 2) == sbyte(qw, 1))) then
                            local nwLen = #nw
                            local maxEdits = qwLen >= FUZZY_EDIT2_LEN and 2 or 1
                            if nwLen >= qwLen - maxEdits and nwLen <= qwLen + maxEdits then
                                local dist = Database:DamerauLevenshtein(qw, nw, qwLen, nwLen)
                                if dist == 1 then
                                    ws = 75
                                elseif dist == 2 and maxEdits >= 2 then
                                    ws = 40
                                end
                            end
                            if ws == 0 and qwLen <= ABBREV_MAX_LEN and nwLen > qwLen and qwLen / nwLen >= 0.6 then
                                if Database:IsSubsequence(nw, qw, qwLen) then
                                    ws = 45
                                end
                            end
                        elseif qwLen == 3 then
                            local nwLen = #nw
                            if nwLen >= qwLen * 2 and Database:IsSubsequence(nw, qw, qwLen) then
                                ws = 45
                            end
                        end
                        if ws > bestWordScore then
                            bestWordScore = ws
                            bestIdx = ni
                        end
                    end
                end
                if bestWordScore > 0 then
                    usedNameWords[bestIdx] = true
                    totalWordScore = totalWordScore + bestWordScore
                else
                    allMatched = false
                    break
                end
            end
            if allMatched then
                local avgScore = totalWordScore / #queryWords
                local wordScore = mmin(110, avgScore)
                if avgScore == 100 and #nameWords == #queryWords then wordScore = NAME_REORDERED_SCORE end
                if wordScore > score then score = wordScore end
            end
        end
    end

    return score
end



function Database:ScoreName(nameLower, query, queryLen, optQueryWords, plain)
    local score = ScoreNameAs(nameLower, query, queryLen, optQueryWords, plain)
    if score < EXACT_MATCH_SCORE and QuotedOnly(nameLower, query) then
        local bare = ScoreNameAs(Unquoted(nameLower), query, queryLen, optQueryWords, plain)
        if bare > score then score = bare end
    end
    return score
end



function Database:ScoreTransientName(nameLower, query, queryLen)
    transientName, transientFilled = nameLower, false
    local score = ScoreNameAs(nameLower, query, queryLen)
    if score < EXACT_MATCH_SCORE and QuotedOnly(nameLower, query) then
        local bareName = Unquoted(nameLower)
        transientName, transientFilled = bareName, false
        local bare = ScoreNameAs(bareName, query, queryLen)
        if bare > score then score = bare end
    end
    transientName = nil
    return score
end







local strongNameUsedWords = {}
local function StrongMultiWordNameScore(nameLower, queryWords)
    local nameWords = GetWords(nameLower)
    local numQueryWords = #queryWords
    if #nameWords < numQueryWords then return 0 end
    wipe(strongNameUsedWords)
    local total = 0
    for qwi = 1, numQueryWords do
        local qw = queryWords[qwi]
        local best = 0
        local bestIdx = 0
        for ni = 1, #nameWords do
            if not strongNameUsedWords[ni] then
                local nw = nameWords[ni]
                if nw == qw then
                    best = 100
                    bestIdx = ni
                    break
                elseif best < 90 and sfind(nw, qw, 1, true) == 1 then
                    best = 90
                    bestIdx = ni
                end
            end
        end
        if bestIdx == 0 then return 0 end
        strongNameUsedWords[bestIdx] = true
        total = total + best
    end
    return total / numQueryWords
end



local function ScoreKeywordsAs(keywordsLower, query, queryLen, optQueryWords, plain)
    if not keywordsLower then return 0 end

    if ssub(query, queryLen, queryLen) == " " then
        query = query:match("^(.-)%s+$") or query
        queryLen = #query
        if queryLen == 0 then return 0 end
    end



    local queryWords = optQueryWords or GetWords(query)




    local numKeywords = #keywordsLower
    if #queryWords == 1 then
        if STOPWORDS[query] then
            local best = 0
            for ki = 1, numKeywords do
                local kw = keywordsLower[ki]
                if kw ~= query
                   and (Database._disableSearchGate or KeywordCouldMatch(kw, query, queryLen)) then
                    local ext = StopwordExtension(kw, query, queryLen)
                    local kwScore = (ext == 3 and 70) or (ext == 2 and 55) or 0
                    if kwScore > best then best = kwScore end
                end
            end
            return best
        end
        local best = 0
        for ki = 1, numKeywords do
            local kw = keywordsLower[ki]
            if Database._disableSearchGate or KeywordCouldMatch(kw, query, queryLen) then
            local kwScore = 0
            if kw == query then



                kwScore = (queryLen <= 3 and not plain) and SHORT_KEYWORD_SCORE or 100
            elseif sfind(kw, query, 1, true) == 1 then



                kwScore = queryLen >= FUZZY_EDIT1_LEN and 90 or 70
            elseif Database:FindAtWordBoundary(kw, query) then
                kwScore = 55
            end



            local tag = tagWords and tagWords[kw]
            if kwScore < 60 and queryLen >= 3 and not tag then
                local initScore = Database:ScoreInitials(kw, query)
                if initScore > 0 then
                    local penalty = queryLen == 3 and 70 or 20
                    kwScore = mmax(kwScore, initScore - penalty)
                end
            end
            if kwScore < 40 and queryLen >= FUZZY_EDIT1_LEN and not tag then
                local kf = Database:ScoreFuzzy(kw, query, queryLen)
                if kf > 0 then kwScore = mmax(kwScore, kf) end
            end
            if kwScore < 50 and queryLen >= 3 and not tag then
                local kwWords = GetWords(kw)
                for kwi = 1, #kwWords do
                    local kwWord = kwWords[kwi]
                    local kwWordLen = #kwWord
                    if queryLen <= 4 and kwWordLen >= queryLen * 2 then
                        if Database:IsSubsequence(kwWord, query, queryLen) then
                            kwScore = mmax(kwScore, 60)
                            break
                        end
                    elseif queryLen <= ABBREV_MAX_LEN and kwWordLen > queryLen and queryLen / kwWordLen >= 0.6 then
                        if Database:IsSubsequence(kwWord, query, queryLen) then
                            kwScore = mmax(kwScore, 55)
                            break
                        end
                    end
                end
            end
            if kwScore > best then best = kwScore end
            end
        end
        return best
    end




    local total = 0
    for qwi = 1, #queryWords do
        local queryWord = queryWords[qwi]
        local queryWordLen = #queryWord
        local bestScore = 0

        if queryWordLen >= 2 then
            for ki = 1, numKeywords do
                local kw = keywordsLower[ki]
                if Database._disableSearchGate or KeywordCouldMatch(kw, queryWord, queryWordLen) then
                local kwScore = 0
                if kw == queryWord then
                    kwScore = 80
                elseif sfind(kw, queryWord, 1, true) == 1 then
                    kwScore = 70
                elseif Database:FindAtWordBoundary(kw, queryWord) then
                    kwScore = 55
                end
                local tag = tagWords and tagWords[kw]
                if kwScore < 60 and queryWordLen >= 3 and not tag then
                    local initScore = Database:ScoreInitials(kw, queryWord)
                    if initScore > 0 then
                        local penalty = queryWordLen == 3 and 70 or 20
                        kwScore = mmax(kwScore, initScore - penalty)
                    end
                end
                if kwScore < 40 and queryWordLen >= FUZZY_EDIT1_LEN and not tag then
                    local kf = Database:ScoreFuzzy(kw, queryWord, queryWordLen)
                    if kf > 0 then kwScore = mmax(kwScore, kf) end
                end

                if kwScore > bestScore then
                    bestScore = kwScore
                end
                end
            end
            if bestScore == 0 then
                return 0
            end
            total = total + bestScore
        end
    end

    return total
end


local unquotedKeywords = {}
function Database:ScoreKeywords(keywordsLower, query, queryLen, optQueryWords, plain)
    local score = ScoreKeywordsAs(keywordsLower, query, queryLen, optQueryWords, plain)
    if score >= 100 or not keywordsLower then return score end
    local quoted = false
    for ki = 1, #keywordsLower do
        local kw = keywordsLower[ki]
        if QuotedOnly(kw, query) then quoted = true kw = Unquoted(kw) end
        unquotedKeywords[ki] = kw
    end
    for ki = #keywordsLower + 1, #unquotedKeywords do unquotedKeywords[ki] = nil end
    if not quoted then return score end
    local bare = ScoreKeywordsAs(unquotedKeywords, query, queryLen, optQueryWords, plain)
    return bare > score and bare or score
end



local function ScoreFieldWordAs(fieldWord, queryWord, queryWordLen)
    if fieldWord == queryWord then return 100 end
    if sfind(fieldWord, queryWord, 1, true) == 1 then return 90 end

    local fieldLen = #fieldWord
    if (queryWordLen == fieldLen + 1 and sbyte(queryWord, queryWordLen) == 115
            and sfind(queryWord, fieldWord, 1, true) == 1)
       or (fieldLen == queryWordLen + 1 and sbyte(fieldWord, fieldLen) == 115
            and sfind(fieldWord, queryWord, 1, true) == 1) then
        return 82
    end
    if sfind(fieldWord, queryWord, 1, true) then return 50 end
    if queryWordLen >= 3 then
        if fieldLen > queryWordLen and queryWordLen <= 8
           and queryWordLen / fieldLen >= 0.45
           and Database:IsSubsequence(fieldWord, queryWord, queryWordLen) then
            return 55
        end
    end
    if queryWordLen >= FUZZY_EDIT1_LEN and sbyte(fieldWord, 1) == sbyte(queryWord, 1) then
        local maxEdits = queryWordLen >= FUZZY_EDIT2_LEN and 2 or 1
        if fieldLen >= queryWordLen - maxEdits and fieldLen <= queryWordLen + maxEdits then
            local dist = Database:DamerauLevenshtein(queryWord, fieldWord, queryWordLen, fieldLen)
            if dist <= maxEdits then return mmax(45, 85 - dist * 20) end
        end
    end
    return 0
end


local function ScoreSingleFieldWord(fieldWord, queryWord, queryWordLen)
    local score = ScoreFieldWordAs(fieldWord, queryWord, queryWordLen)
    if score < 100 and QuotedOnly(fieldWord, queryWord) then
        local bare = ScoreFieldWordAs(Unquoted(fieldWord), queryWord, queryWordLen)
        if bare > score then score = bare end
    end
    return score
end

local function ScoreFieldWords(words, queryWord, queryWordLen)
    local best = 0
    for i = 1, #words do
        local score = ScoreSingleFieldWord(words[i], queryWord, queryWordLen)
        if score > best then best = score end
    end
    return best
end

local keywordWordListsScratch = {}
function Database:ScoreEntryFields(data, queryWords, nameLower)
    if not queryWords or #queryWords < 2 then return 0 end
    local total = 0
    local matched = 0
    local nameMatches = 0
    local nameWords = GetWords(nameLower or data.nameLower or "")


    local keywordsLower = data.keywordsLower or data.keywords

    local keywordWordLists = keywordWordListsScratch
    local kwCount = keywordsLower and #keywordsLower or 0
    for ki = 1, kwCount do
        keywordWordLists[ki] = GetWords(keywordsLower[ki])
    end

    for qi = 1, #queryWords do
        local qw = queryWords[qi]
        local qwLen = #qw
        if qwLen >= 2 or (qwLen == 1 and qi == #queryWords and matched > 0) then
            local nameBest = ScoreFieldWords(nameWords, qw, qwLen)
            local kwBest = 0
            for ki = 1, kwCount do
                local kw = keywordsLower[ki]
                local kwScore = ScoreSingleFieldWord(kw, qw, qwLen)
                if kwScore < 90 then
                    kwScore = mmax(kwScore, ScoreFieldWords(keywordWordLists[ki], qw, qwLen))
                end
                if kwScore > kwBest then kwBest = kwScore end
            end
            local best
            if nameBest > 0 then
                best = nameBest
                nameMatches = nameMatches + 1
            else





                best = mfloor(kwBest * 0.75)
            end
            if best == 0 then return 0 end
            total = total + best
            matched = matched + 1
        end
    end

    if matched < 2 then return 0 end



    if nameMatches == 0 then
        total = mfloor(total * 0.6)
    end
    return total + matched * 5
end

local prevQuery = ""
local prevSkipKey = ""
local prevCandidates = {}


local searchEpoch = 0

local function DropCandidates()
    searchEpoch = searchEpoch + 1
    prevQuery = ""
    prevCandidates = {}
end


local skipKeyBuf = {}

Database.nameScopedCategories = Database.nameScopedCategories or {}
local nameOpenBuf = {}







local RESULT_CACHE_MAX = 16
local resultCache = {}
local resultCacheLRU = {}
Database._resultCache = resultCache

local function ClearResultCache()
    wipe(resultCache)
    wipe(resultCacheLRU)
end

local function StoreResultCache(key, candidates, n)
    local slot = resultCache[key]
    if slot then
        for i = 1, #resultCacheLRU do
            if resultCacheLRU[i] == key then tremove(resultCacheLRU, i); break end
        end
    elseif #resultCacheLRU >= RESULT_CACHE_MAX then
        local evict = tremove(resultCacheLRU, 1)
        slot = resultCache[evict]
        resultCache[evict] = nil
    else
        slot = {}
    end
    resultCache[key] = slot
    resultCacheLRU[#resultCacheLRU + 1] = key
    for i = 1, n do slot[i] = candidates[i] end
    for i = n + 1, #slot do slot[i] = nil end
end

function Database:WarmSearchHotPath()




    if self.EnsureDynamicProviderLoaded then
        self:EnsureDynamicProviderLoaded("loot")
        self:EnsureDynamicProviderLoaded("statistics")
        self:EnsureDynamicProviderLoaded("bosses")
    end


    if self.LoadEagerDynamicProviders then self:LoadEagerDynamicProviders() end





    local filters = EasyFind and EasyFind.db and EasyFind.db.uiSearchFilters
    local map = ns.CategoryMap
    local settingsOff = filters and map and map.IsProviderFilterOff
        and map.IsProviderFilterOff(filters, "gameOptions")
        and map.IsProviderFilterOff(filters, "addonOptions")
    local options = ns.BlizzOptionsSearch
    if not options and not settingsOff and ns.RequestSettingsSearch
       and ns.RequestSettingsSearch() then
        options = ns.BlizzOptionsSearch
    end
    if options and not settingsOff then



        local rebindShortkeys = function()
            if ns.Shortkeys and ns.Shortkeys.ReapplyIfPending then ns.Shortkeys:ReapplyIfPending() end
        end

        if options.EnsurePopulatedAsync then options:EnsurePopulatedAsync(rebindShortkeys, true) end
        if options.EnsureLivePopulatedAsync then options:EnsureLivePopulatedAsync(rebindShortkeys, true) end
    end
end







local searchRefreshPending = false
local function RunActiveSearchRefresh()
    searchRefreshPending = false

    local search = ns.Search
    if search and search.RefreshActiveSearch then
        search:RefreshActiveSearch(true)
    end
end



local function QueueActiveSearchRefresh(database)
    if database._dynamicBatchLoading then
        database._dynamicBatchChanged = true
        return
    end
    if database.IsRefreshingStale and database:IsRefreshingStale() then
        local search = ns.Search
        if not (search and search.IsSearchRunning and search:IsSearchRunning()) then
            database._staleChanged = true
            return
        end
    end
    if not searchRefreshPending and Utils.SafeAfter then
        searchRefreshPending = true
        Utils.SafeAfter(0, RunActiveSearchRefresh)
    end
end











function Database:NoteAppendedEntries(rows)
    if ns.Aliases and ns.Aliases.InvalidateKeyIndex then ns.Aliases:InvalidateKeyIndex() end
    ClearResultCache()
    searchEpoch = searchEpoch + 1
    if prevQuery ~= "" and rows then
        local count = #prevCandidates
        for i = 1, #rows do prevCandidates[count + i] = rows[i] end
    end
    QueueActiveSearchRefresh(self)
end

function Database:ResetSearchCache()
    if ns.Aliases and ns.Aliases.InvalidateKeyIndex then ns.Aliases:InvalidateKeyIndex() end





    DropCandidates()
    prevSkipKey = ""
    ClearResultCache()

    QueueActiveSearchRefresh(self)
end

local resultsBuf = {}




local sharedKwScores = {}
local resultsQueryWords = {}

local steerHolder = {}
local resultEntryPool = {}
Database._resultEntryPool = resultEntryPool

function Database:TrimSearchMemory()
    self:UnloadDynamicSearchData()


    resultsBuf, sharedKwScores, resultEntryPool = {}, {}, {}
    Database._resultEntryPool = resultEntryPool
    wipe(resultsQueryWords)
    steerHolder = {}
    wordCache, nameMaskCache, wordInitCache = {}, {}, {}
    Database._wordCache = wordCache
    DropCandidates()
    prevSkipKey = ""
    resultCache, resultCacheLRU = {}, {}
    Database._resultCache = resultCache
    if ns.SearchIndex and ns.SearchIndex.TrimScratch then ns.SearchIndex:TrimScratch() end
    Utils.ShedCorpora()
end






local categoryMinLen






local DEFAULT_CATEGORY_MINLEN = {
    ["Statistic"] = 3,
    ["Boss"] = 3,
    ["Achievement"] = 3,
    ["Achievement Category"] = 3,
    ["Game Settings"] = 3,
    ["AddOn Settings"] = 3,
}
Database.DEFAULT_CATEGORY_MINLEN = DEFAULT_CATEGORY_MINLEN
function Database:SetCategoryMinLen(map)
    categoryMinLen = map



    self.categoryMinLenActive = map
    self:ResetSearchCache()
end




local function KeywordScore(data, kws, q, qLen, words, memo)
    if rawget(data, "keywordsLower") ~= nil or rawget(data, "keywords") ~= nil then
        return Database:ScoreKeywords(kws, q, qLen, words, data.plainKeywords)
    end
    local s = memo[kws]
    if s == nil then
        s = Database:ScoreKeywords(kws, q, qLen, words)
        memo[kws] = s
    end
    return s
end






local function OtherNameScores(data, score, q, qLen, words, nameLower)
    if #words >= 2 then
        score = mmax(score, Database:ScoreEntryFields(data, words, nameLower))
    end
    local snippetKw = data.snippetKeywordLower
    if snippetKw then
        score = mmax(score, Database:ScoreName(snippetKw, q, qLen, words))
    end
    local tpName = data.teleportNameLower
    if tpName then
        score = mmax(score, Database:ScoreName(tpName, q, qLen, words))
        local tpEn = data.teleportNameEnLower
        if tpEn and tpEn ~= tpName then
            score = mmax(score, Database:ScoreName(tpEn, q, qLen, words))
        end
    end
    return score
end






local function LootScore(data, nameLower, queryWords, lootStatActive)
    local totalScore = 0
    local nameWords = GetWords(nameLower)
    for qi = 1, #queryWords do
        local qw = queryWords[qi]
        if not STOPWORDS[qw] then
            local qwLen = #qw

            local qwStem = qwLen > 3 and ssub(qw, qwLen, qwLen) == "s" and ssub(qw, 1, qwLen - 1) or nil
            local qwPlural = qw .. "s"
            local bestWord = 0

            local gearScore = Database.LootWordScore and Database.LootWordScore(data, qw)
            if gearScore then bestWord = gearScore end




            for ni = 1, #nameWords do
                local nw = nameWords[ni]
                if nw == qw then
                    bestWord = mmax(bestWord, qi == 1 and 130 or 120)
                elseif ssub(nw, 1, qwLen) == qw then
                    bestWord = mmax(bestWord, qi == 1 and 115 or 105)
                end
            end






            if data.lootSlotKw then
                for ki = 1, #data.lootSlotKw do
                    local kw = data.lootSlotKw[ki]
                    if kw == qw then
                        bestWord = mmax(bestWord, 115)
                    elseif sfind(kw, qw, 1, true) == 1 then
                        bestWord = mmax(bestWord, 70)
                    end
                end
            end

            if lootStatActive and data.lootStatKw then
                for ki = 1, #data.lootStatKw do
                    local kw = data.lootStatKw[ki]
                    if kw == qw then
                        bestWord = mmax(bestWord, 115)
                    elseif sfind(kw, qw, 1, true) == 1 then
                        bestWord = mmax(bestWord, 70)
                    end
                end
            end




            if data.lootSourceKw then
                for ki = 1, #data.lootSourceKw do
                    local kw = data.lootSourceKw[ki]
                    if kw == qw or kw == qwStem or kw == qwPlural then
                        bestWord = mmax(bestWord, 110)
                    elseif sfind(kw, qw, 1, true) == 1 then
                        bestWord = mmax(bestWord, 100)
                    end
                end
            end

            if bestWord == 0 then return 0 end
            totalScore = totalScore + bestWord
        end
    end
    return totalScore
end

function Database:SearchUI(query, skipCategories, nameScope)
    if not query or query == "" or #query < 2 then
        DropCandidates()
        wipe(resultsBuf)
        return resultsBuf
    end

    query = Database:NormalizeSearchQuery(slower(query))
    local queryLen = #query


    if ssub(query, queryLen, queryLen) == " " then
        query = query:match("^(.-)%s+$") or query
        query = Database:NormalizeSearchQuery(query)
        queryLen = #query
        if queryLen == 0 then DropCandidates(); wipe(resultsBuf); return resultsBuf end
    end

    wipe(sharedKwScores)
    wipe(resultsQueryWords)
    local queryWords = resultsQueryWords








    local cut = GetWords(query)
    for i = 1, #cut do queryWords[i] = cut[i] end
    if #queryWords == 0 then
        for w in query:gmatch("%S+") do
            queryWords[#queryWords + 1] = w
        end
    end





    local queryNorm = tconcat(queryWords, " ")
    local queryNormLen = #queryNorm
    if queryNorm == query or queryNormLen < 2 then queryNorm = nil end




    local bossQueryWord = false
    local instanceQueryWord = false
    local achQueryWord = false
    local statQueryWord = false
    local lootStatWordCount = 0
    local lootGearContext = false
    for qi = 1, #queryWords do
        local qw = queryWords[qi]
        if Database.IsInstanceSearchWord and Database:IsInstanceSearchWord(qw) then
            instanceQueryWord = true
        end
        if BOSS_QUERY_WORDS[qw] then
            bossQueryWord = true
        end
        local isStatQueryWord = STAT_QUERY_WORDS[qw]
        if isStatQueryWord then
            statQueryWord = true
        end
        if IsLootStatSearchWord(qw) then
            lootStatWordCount = lootStatWordCount + 1
        end
        if IsLootSlotSearchWord(qw) then
            lootGearContext = true
        end
        if ssub(qw, 1, 3) == "ach" or isStatQueryWord then
            achQueryWord = true
        end
    end







    local lootStatActive = lootStatWordCount > 0
        and (lootGearContext or lootStatWordCount >= 2
            or Database._disableLootStatContext == true)



    local scopedByCat = Steer.Scope(steerHolder, query, queryWords) and steerHolder.byCategory or nil
    if scopedByCat then
        for _, rec in pairs(scopedByCat) do
            if rec.kwMemo then wipe(rec.kwMemo) else rec.kwMemo = {} end
        end
    end

    GATE.count = 0
    GATE.sawNil = false
    GATE.gatedN = 0
    GATE.scoped = scopedByCat
    if not Database._disableSearchGate then
        for qi = 1, #queryWords do
            local qw = queryWords[qi]
            local qwLen = #qw
            if qwLen >= 2 then
                local m = ComputeCharMask(qw)
                if m ~= 0 then
                    local gc = GATE.count + 1
                    GATE.count = gc
                    GATE.masks[gc] = m
                    local allow = qwLen >= FUZZY_EDIT2_LEN and 2 or qwLen >= FUZZY_EDIT1_LEN and 1 or 0
                    if allow == 0 and sbyte(qw, qwLen) == 115 then allow = 1 end
                    GATE.allows[gc] = allow


                    local fb, sb2 = sbyte(qw, 1, 2)
                    local bits = fb >= 97 and fb <= 122 and lshift(1, fb - 97) or 0
                    if allow > 0 and sb2 and sb2 >= 97 and sb2 <= 122 then
                        bits = bor(bits, lshift(1, sb2 - 97))
                    end
                    GATE.firstBits[gc] = bits
                end
            end
        end
    end










    local skipKey = ""
    if skipCategories then
        local order = ns.CategoryMap.SkipKeyOrder
        local n = 0
        for i = 1, #order do
            local cat = order[i]
            if skipCategories[cat] then n = n + 1; skipKeyBuf[n] = cat end
        end
        if n > 0 then skipKey = tconcat(skipKeyBuf, ",", 1, n) end
    end



    local nameShut = next(self.nameScopedCategories) and self.nameScopedCategories or nil
    local nameOpen = nameOpenBuf
    wipe(nameOpen)
    if nameShut then
        for i = 1, nameScope and #nameScope or 0 do nameOpen[nameScope[i]] = true end
        skipKey = skipKey .. "\2" .. (nameScope and tconcat(nameScope, ",") or "")
    end



    local cacheKey = query .. "\1" .. skipKey

    local searchSet, restAt, stopwordRest
    local epoch, cands = searchEpoch, prevCandidates
    local cachedSet = resultCache[cacheKey]
    if cachedSet then


        searchSet = cachedSet
    elseif query == prevQuery and skipKey == prevSkipKey then




        searchSet = prevCandidates
    else
        searchSet = uiSearchData




        if not Database._disableSearchGate and ns.SearchIndex then


            local split = #queryWords == 1 and queryWords[1] == query and not queryNorm
                and not sfind(query, "[^%w]")
                and not lootStatActive and not bossQueryWord and not achQueryWord and not statQueryWord

            local cutWords = scopedByCat and #steerHolder.rest > 0 and steerHolder.rest or nil
            local cand, _, restFrom = ns.SearchIndex:Candidates(queryWords, split, cutWords, scopedByCat)
            if cand then
                searchSet = cand
                restAt = restFrom
                stopwordRest = restFrom and STOPWORDS[query]
            end
        end
    end




    local efStats = Database._efSearchStats
    if efStats then
        if cachedSet then
            efStats.cache = efStats.cache + 1
            efStats.lastPath = "cache"
        elseif searchSet == prevCandidates then
            efStats.narrow = efStats.narrow + 1
            efStats.lastPath = "narrow"
        elseif searchSet ~= uiSearchData then
            efStats.indexed = (efStats.indexed or 0) + 1
            efStats.lastPath = "indexed"
        else
            efStats.full = efStats.full + 1
            efStats.lastPath = "full"
            local why
            if prevQuery == "" then why = "noPrev"
            elseif skipKey ~= prevSkipKey then why = "skipKey"
            else why = "newQuery" end
            efStats.whys[why] = (efStats.whys[why] or 0) + 1
        end
        efStats.setSize = #searchSet
        efStats.dataSize = #uiSearchData
    end


    prevQuery = ""
    wipe(resultsBuf)
    local results = resultsBuf
    local resultsN, matchesN = 0, 0
    local candidateIdx = 0

    local gateActive = GATE.count > 0



    local hideRooms = not (EasyFind and EasyFind.db and EasyFind.db.housingShowRooms == true)
    local searchCount = #searchSet

    local checkRest = Database._checkRestBound and restAt
    local stoppedEarly = false
    for i = 1, searchCount do



        if band(i, 63) == 0 then SliceCheckpoint() end

        if i == restAt and not checkRest and resultsN >= RESULT_CAP
           and results[1].score > REST_MAX_SCORE then
            stoppedEarly = true
            break
        end
        local data = searchSet[i]

        local cat = data.category
        if not (skipCategories and skipCategories[cat])
           and not (hideRooms and cat == "Housing" and data.isRoom)
           and not (data.available and not data.available())
           and (not categoryMinLen or queryLen >= (categoryMinLen[cat] or 0))
           and (not gateActive or not GateSkipsEntry(data)) then
            local nameLower = data.nameLower
            if nameShut and nameShut[cat] and not nameOpen[cat] and data.scopedName then nameLower = "" end
            local sq = scopedByCat and scopedByCat[cat]
            local score
            if stopwordRest and i >= restAt then


                score = (cat ~= "Achievement Category" and cat ~= "Statistic"
                    and sfind(nameLower, query, 1, true)) and 30 or 0
            elseif data.lootEntry then
                if lootStatActive and not data._statsEnriched then
                    Database:EnrichLootStats(data)
                end



                score = mmax(Database:ScoreName(nameLower, query, queryLen, queryWords, true),
                    LootScore(data, nameLower, queryWords, lootStatActive))
                if sq then
                    score = mmax(score, Database:ScoreName(nameLower, sq.query, sq.len, sq.words, true) - 1,
                        LootScore(data, nameLower, sq.words, lootStatActive) - 1)
                end
            elseif cat == "Boss" and not bossQueryWord and not instanceQueryWord then
                score = Database:ScoreName(nameLower, query, queryLen, queryWords)
            else
                local isAchEntry = cat == "Achievement Category" or cat == "Statistic"
                if isAchEntry and not achQueryWord then


                    if nameLower == query then
                        score = EXACT_MATCH_SCORE
                    elseif STOPWORDS[query] then
                        local ext = StopwordExtension(nameLower, query, queryLen)
                        score = (ext == 3 and NAME_PREFIX_SCORE) or (ext == 2 and 120) or 0
                    elseif sfind(nameLower, query, 1, true) == 1 then
                        score = NAME_PREFIX_SCORE
                    elseif Database:FindAtWordBoundary(nameLower, query) then
                        score = 120
                    elseif #queryWords >= 2 then
                        score = StrongMultiWordNameScore(nameLower, queryWords)
                    else
                        score = 0
                    end
                else


                    local kws = data.keywordsLower or data.keywords
                    local kwScore = kws and KeywordScore(data, kws, query, queryLen, queryWords, sharedKwScores) or 0








                    if cat == "Boss" then
                        if kwScore > 0 then kwScore = kwScore - 1 end
                        local inst = data.instanceNameLower
                        if inst then
                            kwScore = mmax(kwScore, mmin(Database:ScoreName(inst, query, queryLen, queryWords), 100) - 1)
                        end
                    end
                    score = mmax(Database:ScoreName(nameLower, query, queryLen, queryWords), kwScore)
                    if queryNorm and score < 100 then





                        local alt = mmax(
                            Database:ScoreName(nameLower, queryNorm, queryNormLen, queryWords),
                            kws and Database:ScoreKeywords(kws, queryNorm, queryNormLen, queryWords) or 0)
                        if alt > 0 then score = mmax(score, 30 + mmin(alt, 1000) * 0.069) end
                    end
                    score = OtherNameScores(data, score, query, queryLen, queryWords, nameLower)
                    if sq then


                        local cutKw = kws and KeywordScore(data, kws, sq.query, sq.len, sq.words, sq.kwMemo) or 0
                        if cat == "Boss" and cutKw > 0 then cutKw = cutKw - 1 end
                        local cutScore = mmax(Database:ScoreName(nameLower, sq.query, sq.len, sq.words), cutKw)
                        score = mmax(score, OtherNameScores(data, cutScore, sq.query, sq.len, sq.words, nameLower) - 1)
                    end
                end
            end

            if checkRest and i >= restAt and score > (Database._restMaxSeen or 0) then
                Database._restMaxSeen = score
                Database._restMaxRow = data.name
            end
            if score >= 30 then
                matchesN = matchesN + 1





                local bonus = data.scoreBonus
                if bonus and data.scoreBonusWords
                   and not QueryAsksFor(queryWords, data.scoreBonusWords) then
                    bonus = nil
                end
                local total = score + (bonus or 0)
                if resultsN < RESULT_CAP then
                    resultsN = resultsN + 1
                    local r = resultEntryPool[resultsN]
                    if not r then
                        r = {}
                        resultEntryPool[resultsN] = r
                    end
                    r.data, r.score, r.isAlias = data, total, nil
                    results[resultsN] = r
                    HeapUp(results, resultsN)
                else

                    heapProbe.data, heapProbe.score = data, total
                    if scoreDescending(heapProbe, results[1]) then
                        local r = results[1]
                        r.data, r.score, r.isAlias = data, total, nil
                        HeapDown(results, resultsN)
                    end
                end
                candidateIdx = candidateIdx + 1
                cands[candidateIdx] = data
            end
        end
    end
    for i = candidateIdx + 1, #cands do
        cands[i] = nil
    end
    prevSkipKey = skipKey

    if stoppedEarly or epoch ~= searchEpoch then
        prevQuery = ""
    else
        prevQuery = query
        StoreResultCache(cacheKey, cands, candidateIdx)
    end
    if GATE.sawNil and not GATE.fillPending then ScheduleGateMaskFill() end
    if efStats then efStats.lastResults = matchesN; efStats.gated = GATE.gatedN end
    heapProbe.data = nil

    tsort(results, scoreDescending)


    for i = resultsN + 1, #resultEntryPool do
        local r = resultEntryPool[i]
        if r and r.data then
            r.data = nil
            r.score = nil
            r.isAlias = nil
        end
    end
    return results
end





if Database.SetCategoryMinLen then
    pcall(Database.SetCategoryMinLen, Database, DEFAULT_CATEGORY_MINLEN)
end



function Database:_DebugPeekSearchCaches()
    return { wordCache = wordCache, nameMaskCache = nameMaskCache, wordInitCache = wordInitCache }
end

return Database
