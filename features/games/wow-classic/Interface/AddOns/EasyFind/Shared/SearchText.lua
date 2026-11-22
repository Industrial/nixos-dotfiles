local _, ns = ...















local SearchText = {}

local sbyte, schar = string.byte, string.char
local sfind = string.find
local sslower = string.lower



local function utf8At(s, i)
    local b = sbyte(s, i)
    if not b then return nil, i end
    if b < 0x80 then return b, i + 1 end
    if b < 0xC0 then return b, i + 1 end
    local cp, len
    if b < 0xE0 then
        cp = b - 0xC0
        len = 2
    elseif b < 0xF0 then
        cp = b - 0xE0
        len = 3
    else
        cp = b - 0xF0
        len = 4
    end
    for j = 1, len - 1 do
        local cb = sbyte(s, i + j)
        if not cb or cb < 0x80 or cb >= 0xC0 then
            return b, i + 1
        end
        cp = cp * 64 + (cb - 0x80)
    end
    return cp, i + len
end

local mfloor = math.floor
local function utf8Encode(cp)
    if cp < 0x80 then return schar(cp) end
    if cp < 0x800 then
        return schar(0xC0 + mfloor(cp / 64), 0x80 + (cp % 64))
    end
    if cp < 0x10000 then
        return schar(
            0xE0 + mfloor(cp / 4096),
            0x80 + mfloor(cp / 64) % 64,
            0x80 + (cp % 64)
        )
    end
    return schar(
        0xF0 + mfloor(cp / 262144),
        0x80 + mfloor(cp / 4096) % 64,
        0x80 + mfloor(cp / 64) % 64,
        0x80 + (cp % 64)
    )
end




local function lowerCP(cp)
    if cp < 0x80 then
        if cp >= 0x41 and cp <= 0x5A then return cp + 32 end
        return cp
    end

    if cp >= 0xC0 and cp <= 0xDE and cp ~= 0xD7 then
        return cp + 32
    end


    if cp >= 0x0100 and cp <= 0x0137 then
        if cp % 2 == 0 then return cp + 1 end
        return cp
    end
    if cp >= 0x0139 and cp <= 0x0148 then
        if cp % 2 == 1 then return cp + 1 end
        return cp
    end
    if cp >= 0x014A and cp <= 0x0177 then
        if cp % 2 == 0 then return cp + 1 end
        return cp
    end


    if cp == 0x0178 then return 0x00FF end
    if cp >= 0x0179 and cp <= 0x017E then
        if cp % 2 == 1 then return cp + 1 end
        return cp
    end
    return cp
end






function SearchText.Normalize(s)
    if not s or s == "" then return "" end

    if not sfind(s, "[\128-\255]") then return sslower(s) end


    if not sfind(s, "[\195-\197]") then return sslower(s) end

    local out = {}
    local i = 1
    local n = #s
    while i <= n do
        local cp, ni = utf8At(s, i)
        out[#out + 1] = utf8Encode(lowerCP(cp))
        i = ni
    end
    return table.concat(out)
end



local unquoted, unquotedCount = {}, 0
function SearchText.Unquoted(s)
    local v = unquoted[s]
    if v then return v end
    v = (s:gsub("'", ""))
    if unquotedCount >= 4096 then
        wipe(unquoted)
        unquotedCount = 0
    end
    unquotedCount = unquotedCount + 1
    unquoted[s] = v
    return v
end



function SearchText.QuotedOnly(text, query)
    return sfind(text, "'", 1, true) ~= nil and not sfind(query, "'", 1, true)
        and not sfind(text, query, 1, true)
end






local function isWordCP(cp)
    if cp < 0x80 then
        return (cp >= 0x30 and cp <= 0x39)
            or (cp >= 0x41 and cp <= 0x5A)
            or (cp >= 0x61 and cp <= 0x7A)
            or cp == 0x27
            or cp == 0x5F
    end

    if cp == 0xD7 or cp == 0xF7 then return false end
    if cp >= 0x2000 and cp <= 0x206F then return false end
    if cp >= 0x3000 and cp <= 0x303F then return false end
    return true
end






function SearchText.Tokenize(s)
    local tokens = {}
    if not s or s == "" then return tokens end
    local n = #s
    local i = 1
    while i <= n do
        local cp, ni = utf8At(s, i)
        if cp and isWordCP(cp) then
            local start = i
            i = ni
            while i <= n do
                local cp2, ni2 = utf8At(s, i)
                if not cp2 or not isWordCP(cp2) then break end
                i = ni2
            end
            tokens[#tokens + 1] = s:sub(start, i - 1)
        else
            i = ni
        end
    end
    return tokens
end




function SearchText.NormalizeAndTokenize(s)
    return SearchText.Tokenize(SearchText.Normalize(s))
end




function SearchText.IsAscii(s)
    if not s then return true end
    return sfind(s, "[\128-\255]") == nil
end





local function rangeLen(r) return r.to - r.from + 1 end

local function bytesEqual(text, aStart, bStart, len)
    for i = 0, len - 1 do
        if text:byte(aStart + i) ~= text:byte(bStart + i) then
            return false
        end
    end
    return true
end













function SearchText.CondenseMatchRanges(text, matchRanges)
    if not matchRanges or #matchRanges < 2 then return matchRanges or {} end
    local stack = {}
    for i = #matchRanges, 1, -1 do
        stack[#stack + 1] = matchRanges[i]
    end
    local out = {}
    while #stack > 1 do
        local current = stack[#stack]
        stack[#stack] = nil
        local nextRange = stack[#stack]
        local currentLen = rangeLen(current)
        local slideStart = nextRange.from - currentLen
        local slideEnd = nextRange.from - 1
        local canSlide = slideStart >= 1 and slideEnd >= slideStart
        if canSlide and currentLen == (slideEnd - slideStart + 1) then
            if bytesEqual(text, current.from, slideStart, currentLen) then
                stack[#stack] = { from = slideStart, to = nextRange.to }
            else
                out[#out + 1] = current
            end
        else
            out[#out + 1] = current
        end
    end
    out[#out + 1] = stack[1]
    return out
end














function SearchText.FindContiguous(text, query)
    if not text or not query or query == "" then return nil end
    local normText = SearchText.Normalize(text)
    local normQuery = SearchText.Normalize(query)
    local pos = normText:find(normQuery, 1, true)
    if not pos then return nil end
    return { from = pos, to = pos + #normQuery - 1 }
end

if ns then
    ns.SearchText = SearchText


    ns.BOSS_QUERY_WORDS = {
        boss = true, bosses = true, dungeon = true, dungeons = true,
        encounter = true, encounters = true, raid = true, raids = true,
    }
    ns.STAT_QUERY_WORDS = {
        stat = true, stats = true, statistic = true, statistics = true,
    }








    local byCategory, categoriesOf = {}, {}


    local Steer = { byCategory = byCategory, categoriesOf = categoriesOf }
    ns.SearchSteer = Steer
    local NEVER = { of = true, to = true, ["in"] = true, on = true, at = true, by = true,
        ["or"] = true, an = true, the = true, ["and"] = true, ["for"] = true }
    local tconcat = table.concat
    local tokens = {}

    function Steer.Add(category, word)
        word = sslower(word)
        if #word < 2 or NEVER[word] or sfind(word, " ", 1, true) then return end
        local set = byCategory[category]
        if not set then
            set = {}
            byCategory[category] = set
        end
        if set[word] then return end
        set[word] = true
        local cats = categoriesOf[word]
        if not cats then
            cats = {}
            categoriesOf[word] = cats
        end
        cats[#cats + 1] = category
    end

    local function Without(query, set)
        local n, dropped = 0, false
        for token in query:gmatch("%S+") do
            if set[token:match("^%p*(.-)%p*$")] then
                dropped = true
            else
                n = n + 1
                tokens[n] = token
            end
        end
        if not dropped or n == 0 then return nil end
        return tconcat(tokens, " ", 1, n)
    end


    function Steer.Strip(query, category)
        local set = byCategory[category]
        return set and Without(query, set) or nil
    end





    function Steer.Scope(holder, query, queryWords)
        local out, pool, rest = holder.byCategory, holder.pool, holder.rest
        if not out then
            out, pool, rest = {}, {}, {}
            holder.byCategory, holder.pool, holder.rest = out, pool, rest
        end
        for cat in pairs(out) do out[cat] = nil end
        if not queryWords then
            queryWords = holder.tokens or {}
            holder.tokens = queryWords
            local n = 0
            for token in query:gmatch("%S+") do
                n = n + 1
                queryWords[n] = token:match("^%p*(.-)%p*$")
            end
            for i = #queryWords, n + 1, -1 do queryWords[i] = nil end
        end
        local used, restN, any = 0, 0, false
        for i = 1, #queryWords do
            local w = queryWords[i]
            local cats = categoriesOf[w]
            if cats then
                for c = 1, #cats do
                    local cat = cats[c]
                    if not out[cat] then
                        local scoped = Without(query, byCategory[cat])
                        if scoped then
                            used = used + 1
                            local rec = pool[used]
                            if not rec then
                                rec = { words = {} }
                                pool[used] = rec
                            end
                            rec.query, rec.len = scoped, #scoped
                            local set, words, wn = byCategory[cat], rec.words, 0
                            for k = 1, #queryWords do
                                if not set[queryWords[k]] then
                                    wn = wn + 1
                                    words[wn] = queryWords[k]
                                end
                            end
                            for k = #words, wn + 1, -1 do words[k] = nil end
                            out[cat] = rec
                            any = true
                        end
                    end
                end
            else
                restN = restN + 1
                rest[restN] = w
            end
        end
        for i = #rest, restN + 1, -1 do rest[i] = nil end
        return any
    end

    for w in pairs(ns.BOSS_QUERY_WORDS) do Steer.Add("Boss", w) end
    for w in pairs(ns.STAT_QUERY_WORDS) do
        Steer.Add("Statistic", w)
        Steer.Add("Statistics", w)
    end
end
return SearchText
