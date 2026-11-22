

local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).stale then return end













local IconSearch = {}
ns.IconSearch = IconSearch

local Utils = ns.Utils
local sfind, ssub = Utils.sfind, Utils.ssub
local slower = Utils.slower or string.lower
local mfloor = Utils.mfloor
local tconcat = Utils.tconcat or table.concat
local tonumber = tonumber
local wipe = wipe



local function NewCorpus()
    return { offsets = {}, tabs = {}, total = 0, mark = {}, hit = {}, matched = {} }
end



local icons, spells = NewCorpus(), NewCorpus()

local function IndexCorpus(c)
    local blob = c.blob
    if c.total > 0 or not blob then return c.total end
    local len, offsets, tabs = #blob, c.offsets, c.tabs
    local pos, n = 1, 0
    while pos <= len do
        local nl = sfind(blob, "\n", pos, true) or (len + 1)
        local tab = sfind(blob, "\t", pos, true)
        if tab and tab < nl then
            n = n + 1
            offsets[n] = pos
            tabs[n] = tab
        end
        pos = nl + 1
    end
    c.total = n
    return n
end



local function OwnIcons(blob)
    local Caps = ns.Caps
    local client = Caps.forever and "forever" or Caps.era and "era" or Caps.tbc and "tbc"
        or Caps.mists and "mists" or "retail"
    local runs = ns.ICON_CLIENT_RUNS[client]
    ns.ICON_CLIENT_RUNS = nil
    local kept, n, pos, keep = {}, 0, 1, true
    for count in runs:gmatch("%d+") do
        local stop = pos
        for _ = 1, tonumber(count) do
            stop = sfind(blob, "\n", stop, true) + 1
        end
        if keep and stop > pos then
            n = n + 1
            kept[n] = ssub(blob, pos, stop - 1)
        end
        pos, keep = stop, not keep
    end
    return tconcat(kept)
end

local function EnsureIndex()
    if not icons.blob then
        local b = ns.ICON_SEARCH_BLOB
        if type(b) ~= "string" then return 0 end

        icons.blob = OwnIcons(b)
        ns.ICON_SEARCH_BLOB = nil
    end
    return IndexCorpus(icons)
end

local function IconID(rec)
    local blob = icons.blob
    return tonumber(ssub(blob, icons.tabs[rec] + 1, (icons.offsets[rec + 1] or (#blob + 2)) - 2))
end

function IconSearch:GetIcon(index)
    if not icons.offsets[index] then return nil end
    return ssub(icons.blob, icons.offsets[index], icons.tabs[index] - 1), IconID(index)
end

function IconSearch:GetTotal()
    return EnsureIndex()
end


local function IndexOfFileID(fdid)
    if type(fdid) ~= "number" or EnsureIndex() == 0 then return nil end
    local lo, hi = 1, icons.total
    while lo <= hi do
        local mid = mfloor((lo + hi) / 2)
        local id = IconID(mid)
        if id == fdid then return mid end
        if id < fdid then lo = mid + 1 else hi = mid - 1 end
    end
    return nil
end



local namesStarted, namesReady = false, false
local namesListeners = {}

local function BuildSpellNames()
    local list = ns.ICON_SPELL_IDS
    local getName = C_Spell and C_Spell.GetSpellName
    local getIcon = C_Spell and C_Spell.GetSpellTexture
    if type(list) ~= "string" or not (getName and getIcon) then return end
    ns.ICON_SPELL_IDS = nil
    local lines, iconOf, spellOf, seen = {}, {}, {}, {}
    local n, id, step = 0, 0, 0
    for gap in list:gmatch("%d+") do
        id = id + tonumber(gap)
        step = step + 1
        if step % 64 == 0 then Utils.SliceCheckpoint() end
        local name = getName(id)
        local rec
        if name and name ~= "" then

            local shown, original = getIcon(id)
            rec = IndexOfFileID(original or shown)
        end
        if rec then
            name = slower(name)
            local key = name .. "\t" .. rec
            if not seen[key] then
                seen[key] = true
                n = n + 1
                lines[n] = name
                iconOf[n] = rec
                spellOf[n] = id
            end
        end
    end
    if n == 0 then return end
    lines[n + 1] = ""
    spells.blob = tconcat(lines, "\t\n")
    spells.iconOf, spells.spellOf = iconOf, spellOf
end



local function StartSpellNames()
    if namesStarted then return end
    namesStarted = true
    local starting = true
    Utils.RunSliced(BuildSpellNames, function(ok, err)
        if not ok then Utils.ErrorHandler(err) end
        namesReady = true
        if starting then return end
        for i = 1, #namesListeners do namesListeners[i]() end
    end, nil, "iconSpellNames")
    starting = false
end


function IconSearch:OnNamesReady(fn)
    namesListeners[#namesListeners + 1] = fn
end

function IconSearch:NamesReady()
    return namesReady
end






local function ResolveRefID(kind, refID)
    if kind == "spell" then
        local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo
        local info = GetSpellInfo and GetSpellInfo(refID)
        return info and info.iconID
    end
    if kind == "item" then
        local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant
        if not GetItemInfoInstant then return nil end
        local _, _, _, _, iconID = GetItemInfoInstant(refID)
        return iconID
    end
    if kind == "achievement" then
        local GetAchievementInfo = _G.GetAchievementInfo
        if not GetAchievementInfo then return nil end
        local ok, _, _, _, _, _, _, _, _, _, iconID = pcall(GetAchievementInfo, refID)
        return ok and iconID or nil
    end
    return nil
end




local function GlobToBlobPattern(word)
    local body = word:gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%0")
    body = body:gsub("%*", "[^\t\n]*"):gsub("%?", "[^\t\n]")
    return "\n" .. body .. "\t", "^" .. body .. "\t"
end



local numericSeen = {}






local function CollectIDPrefix(digits, out, seen)
    if EnsureIndex() == 0 then return 0 end
    local blob, offsets, total = icons.blob, icons.offsets, icons.total
    local m = 0
    local exactIdx = IndexOfFileID(tonumber(digits))
    if exactIdx then
        m = 1
        out[1] = exactIdx
        if seen then seen[exactIdx] = true end
    end
    local needle = "\t" .. digits
    local rec = 1
    local p = sfind(blob, needle, 1, true)
    while p do
        while rec < total and offsets[rec + 1] <= p do rec = rec + 1 end
        if rec ~= exactIdx then
            m = m + 1
            out[m] = rec
            if seen then seen[rec] = true end
        end
        p = sfind(blob, needle, p + 1, true)
    end
    return m
end






local altText, altPlural, altPat1 = {}, {}, {}
local altIsPat = {}
local termEnd, termNeg = {}, {}
local branchEnd = {}

local function AddTerm(termN, altN, word)
    local neg = false
    while ssub(word, 1, 1) == "-" do
        neg = not neg
        word = ssub(word, 2)
    end
    local before = altN
    for alt in word:gmatch("[^/]+") do
        altN = altN + 1
        if sfind(alt, "[%*%?]") then
            local pat, pat1 = GlobToBlobPattern(alt)
            altText[altN] = pat
            altPat1[altN] = pat1
            altIsPat[altN] = true
            altPlural[altN] = nil
        else
            altText[altN] = alt
            altPat1[altN] = nil
            altIsPat[altN] = false


            if not neg and #alt > 3
               and ssub(alt, -1) == "s" and ssub(alt, -2) ~= "ss" then
                altPlural[altN] = ssub(alt, 1, -2)
            else
                altPlural[altN] = nil
            end
        end
    end
    if altN == before then return termN, altN end
    termN = termN + 1
    termEnd[termN] = altN
    termNeg[termN] = neg
    return termN, altN
end

local function PrepareQuery(query)
    wipe(termEnd)
    wipe(branchEnd)
    local termN, altN, branchN = 0, 0, 0
    for branch in query:gmatch("[^,]+") do
        local before = termN
        for word in branch:gmatch("[^%s]+") do
            termN, altN = AddTerm(termN, altN, word)
        end
        if termN > before then
            branchN = branchN + 1
            branchEnd[branchN] = termN
        end
    end
    return branchN
end






local markBase, markTop, hitGen, matchGen = 0, 0, 0, 0

local negated = {}


local function Shed(c)
    c.offsets, c.tabs, c.total = {}, {}, 0
    c.mark, c.hit, c.matched = {}, {}, {}
end



function IconSearch:ReleaseMemory()
    Shed(icons)
    Shed(spells)
    negated = {}
    markBase, markTop, hitGen, matchGen = 0, 0, 0, 0
end






local function StampWord(c, word, t, firstTerm, presenceOnly)
    local blob, offsets, tabs, total = c.blob, c.offsets, c.tabs, c.total
    local mark, hit = c.mark, c.hit
    local blobLen, wl = #blob, #word
    local rec = 1
    local p = sfind(blob, word, 1, true)
    while p do
        while rec < total and offsets[rec + 1] <= p do rec = rec + 1 end
        local nextInit = p + 1
        if p + wl - 1 < tabs[rec] then
            if presenceOnly then
                hit[rec] = hitGen
            elseif hit[rec] ~= hitGen
               and (firstTerm or mark[rec] == markBase + (t - 1)) then
                hit[rec] = hitGen
                mark[rec] = markBase + t
            end
            nextInit = (offsets[rec + 1] or (blobLen + 1))
        end
        if nextInit > blobLen then break end
        p = sfind(blob, word, nextInit, true)
    end
end



local function StampPattern(c, pat, pat1, t, firstTerm, presenceOnly)
    local blob, offsets, total = c.blob, c.offsets, c.total
    local mark, hit = c.mark, c.hit
    local blobLen = #blob
    if blob:find(pat1) then
        if presenceOnly then
            hit[1] = hitGen
        elseif hit[1] ~= hitGen and (firstTerm or mark[1] == markBase + (t - 1)) then
            hit[1] = hitGen
            mark[1] = markBase + t
        end
    end
    local rec = 1
    local p = blob:find(pat)
    while p do

        while rec < total and offsets[rec + 1] <= p + 1 do rec = rec + 1 end
        if presenceOnly then
            hit[rec] = hitGen
        elseif hit[rec] ~= hitGen and (firstTerm or mark[rec] == markBase + (t - 1)) then
            hit[rec] = hitGen
            mark[rec] = markBase + t
        end
        local nextInit = (offsets[rec + 1] or (blobLen + 2)) - 1
        if nextInit <= p then nextInit = p + 1 end
        p = blob:find(pat, nextInit)
    end
end



local function MarkBranch(c, termStart, nTerms, altStart)
    local count, mark, hit = c.total, c.mark, c.hit
    local neg = c == icons and negated
    for t = 1, nTerms do
        local termIdx = termStart + t - 1
        hitGen = hitGen + 1
        if termNeg[termIdx] then

            for a = altStart, termEnd[termIdx] do
                if altIsPat[a] then
                    StampPattern(c, altText[a], altPat1[a], t, false, true)
                else
                    StampWord(c, altText[a], t, false, true)
                end
            end
            for rec = 1, count do
                if hit[rec] == hitGen then
                    if neg then neg[rec] = markBase end
                elseif t == 1 or mark[rec] == markBase + (t - 1) then
                    mark[rec] = markBase + t
                end
            end
        else
            for a = altStart, termEnd[termIdx] do
                if altIsPat[a] then
                    StampPattern(c, altText[a], altPat1[a], t, t == 1, false)
                else
                    StampWord(c, altText[a], t, t == 1, false)
                    if altPlural[a] then
                        StampWord(c, altPlural[a], t, t == 1, false)
                    end
                end
            end
        end
        altStart = termEnd[termIdx] + 1
    end
end



function IconSearch:Filter(query, out)
    wipe(out)
    local count = EnsureIndex()
    if count == 0 then return 0 end
    StartSpellNames()
    query = slower(query or ""):gsub("^%s+", ""):gsub("%s+$", "")


    local kind, refID = query:match("^(%a+):(%d+)$")
    if kind then
        local fdid = ResolveRefID(kind, tonumber(refID))
        local idx = fdid and IndexOfFileID(fdid)
        if idx then
            out[1] = idx
            return 1
        end
        return 0
    end


    local hashID = query:match("^#(%d+)$")
    if hashID then
        return CollectIDPrefix(hashID, out, nil)
    end

    local branchN = PrepareQuery(query)
    local m = 0




    wipe(numericSeen)
    if query:match("^%d+$") then
        m = CollectIDPrefix(query, out, numericSeen)
    end

    if branchN == 0 then
        if m > 0 then return m end
        for i = 1, count do out[i] = i end
        return count
    end



    matchGen = matchGen + 1
    local spellCount = namesReady and IndexCorpus(spells) or 0
    local iconMark, iconMatched = icons.mark, icons.matched
    local termStart = 1
    for b = 1, branchN do
        local nTerms = branchEnd[b] - termStart + 1
        markBase = markTop
        markTop = markBase + nTerms
        local altStart = termStart > 1 and (termEnd[termStart - 1] + 1) or 1
        MarkBranch(icons, termStart, nTerms, altStart)
        for rec = 1, count do
            if iconMark[rec] == markTop then
                iconMatched[rec] = matchGen
            end
        end
        if spellCount > 0 then
            MarkBranch(spells, termStart, nTerms, altStart)
            local spellMark, spellMatched, iconOf = spells.mark, spells.matched, spells.iconOf
            for line = 1, spellCount do
                if spellMark[line] == markTop and negated[iconOf[line]] ~= markBase then
                    spellMatched[line] = matchGen
                    iconMatched[iconOf[line]] = matchGen
                end
            end
        end
        termStart = branchEnd[b] + 1
    end

    for rec = 1, count do
        if iconMatched[rec] == matchGen and not numericSeen[rec] then
            m = m + 1
            out[m] = rec
        end
    end
    return m
end



local nameScratch = {}
function IconSearch:GetSpellNames(index, max)
    local iconOf, spellOf = spells.iconOf, spells.spellOf
    local getName = C_Spell and C_Spell.GetSpellName
    if not (iconOf and getName) then return nil end
    wipe(nameScratch)
    local matched = spells.matched
    local n = 0
    for pass = 1, 2 do
        for line = 1, #iconOf do
            if iconOf[line] == index and (matched[line] == matchGen) == (pass == 1) then
                n = n + 1
                if n > max then
                    nameScratch[n] = "..."
                    return tconcat(nameScratch, ", ")
                end
                nameScratch[n] = getName(spellOf[line]) or ""
            end
        end
    end
    return n > 0 and tconcat(nameScratch, ", ") or nil
end



function IconSearch:_DebugPeek()
    return { blob = icons.blob, offsets = icons.offsets, tabs = icons.tabs,
        spellBlob = spells.blob, spellOffsets = spells.offsets, iconOf = spells.iconOf }
end

return IconSearch
