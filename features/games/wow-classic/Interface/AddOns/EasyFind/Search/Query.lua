local _, ns = ...

local Search = ns.Search
local Results = ns.Results
local Tooltips = ns.ResultTooltips
local Filters = ns.Filters
local Utils = ns.Utils
local UIPins = ns.UIPins
local SearchText = ns.SearchText

local pairs = Utils.pairs
local InCombatLockdown = InCombatLockdown
local GetTime = GetTime
local slower = SearchText.Normalize
local tinsert = Utils.tinsert
local tsort = table.sort
local wipe = wipe
local Steer = ns.SearchSteer

local IsUIItemPinned = UIPins.IsPinned
local collapsedNodes = Results._collapsedNodes
local flatEntries = Results._flatEntries
local flatCombined = Results._flatCombined
local SCRATCH = Results._SCRATCH
local SearchEngine = ns.SearchEngine






local function KindRank(d)
    if d.catalogItem or d.category == "Loot" or d.category == "npc" then return 1 end
    return 0
end

local function FlatNameLess(ra, rb)
    local sa, sb = ra.score or 0, rb.score or 0
    if sa ~= sb then return sa > sb end



    local oa, ob = ra.data.clipOrder, rb.data.clipOrder
    if oa and ob and oa ~= ob then return oa < ob end

    local ma, mb = ra.data.mapRank, rb.data.mapRank
    if ma and mb and ma ~= mb then return ma < mb end


    local ka, kb = KindRank(ra.data), KindRank(rb.data)
    if ka ~= kb then return ka < kb end
    local na, nb = ra.data.name or "", rb.data.name or ""
    if #na ~= #nb then return #na < #nb end
    if na ~= nb then return na < nb end


    local tie = ns.Database and ns.Database.TieCategoryLess
    return tie and tie(ra.data, rb.data) or false
end






local ALIAS_SCORE_BASE = 1e9


local LEARNED_SCORE = 1e8






local CATEGORY_ROW_SCORE = 450



local LAUNCHER_NAME_SCORE = 2e6
local LAUNCHER_WORD_SCORE = 900

local ITEM_ROW_CATEGORY = { Bag = true, Bank = true, Warband = true, Loot = true }





local MapRow = {}
function MapRow.Key(d)
    return (d.nameLower or d.name or "") .. "\1" .. tostring(d.mapID or "")
end



function MapRow.SamePlace(learned, mapResults)
    local name = learned.nameLower or slower(learned.name or "")
    for ri = 1, mapResults and #mapResults or 0 do
        local d = mapResults[ri].data
        if d and d.nameLower == name and d.category == learned.category and d.npcID == learned.npcID then
            return d
        end
    end
    return nil
end






function Search:RefreshActiveSearch(rowsOnly)
    local frame = Search:GetSearchFrame()
    if not (frame and frame:IsShown()) then return end
    local typed = Search:GetTypedQuery()
    if typed ~= "" or Search:GetQuickFilter() then
        Search:OnSearchTextChanged(typed, true, rowsOnly)
    end
end




local MAP_REUSE_S = 1
local mapMemo = { valid = false }
local function MapPass(text, rowsOnly)
    local count = ns.MapSearchSearch and ns.MapSearchSearch.uiSearchCount
    local zone = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local m = mapMemo
    if rowsOnly and m.valid and m.text == text and m.count == count and m.zone == zone
       and GetTime() - m.at < MAP_REUSE_S then
        return m.rows
    end
    local rows = ns.MapSearch:SearchForUI(text)
    m.valid, m.text, m.rows, m.zone, m.at = true, text, rows, zone, GetTime()
    m.count = ns.MapSearchSearch and ns.MapSearchSearch.uiSearchCount
    return rows
end

local function MapPassRedone(rows)
    mapMemo.rows, mapMemo.count = rows, ns.MapSearchSearch and ns.MapSearchSearch.uiSearchCount
end
local function MapPassStale() mapMemo.valid = false end

local runRowsOnly = false
local tipText

local searchRefreshQueued = false



local PAINT_HOLD_MAX = 0.25



local ACH_HOLD_MAX = 0.035
local paintHoldText, paintHoldForcedFor, paintHoldTimerFor







local lastProviderRefreshAt = 0
local function RefreshSearchAfterProviderLoad(anyChanged)
    if not anyChanged then return end
    if searchRefreshQueued then return end
    searchRefreshQueued = true





    local delay = (GetTime() - lastProviderRefreshAt) > 0.5 and 0 or 0.3
    Utils.SafeAfter(delay, function()
        searchRefreshQueued = false
        lastProviderRefreshAt = GetTime()
        Search:RefreshActiveSearch(true)



        if ns.Shortkeys and ns.Shortkeys.ReapplyIfPending then
            ns.Shortkeys:ReapplyIfPending()
        end
    end)
end












local itemInfoFrame = CreateFrame("Frame")
local pendingItemRefresh = false
local function RefreshSearchAfterItemInfo()
    pendingItemRefresh = false
    RefreshSearchAfterProviderLoad(true)
end


function ns.OnStatEnrichmentQueued()
    itemInfoFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
end
itemInfoFrame:SetScript("OnEvent", function(self, _, itemID, success)
    if not ns.Database or not ns.Database.ResolvePendingStatEnrichment then return end
    local enriched = ns.Database:ResolvePendingStatEnrichment(itemID, success)
    if enriched and not pendingItemRefresh then
        pendingItemRefresh = true
        Utils.SafeAfter(0.75, RefreshSearchAfterItemInfo)
    end
    local pending = ns.Database._pendingStatEnrichment
    if not (pending and next(pending)) then self:UnregisterEvent("GET_ITEM_INFO_RECEIVED") end
end)






function Search:GetTypedQuery()
    local sf = self:GetSearchFrame()
    local eb = sf and sf.editBox
    if not eb then return "" end
    if eb.HasAutocomplete and eb.HasAutocomplete() and eb.GetTypedText then
        return eb.GetTypedText() or ""
    end
    return eb:GetText() or ""
end





local function FloatPinnedFirst(list, n)
    if n <= 1 then return end
    local pinnedBuf = SCRATCH.pinnedFlat or {}
    SCRATCH.pinnedFlat = pinnedBuf
    local otherBuf = SCRATCH.otherFlat or {}
    SCRATCH.otherFlat = otherBuf
    wipe(pinnedBuf)
    wipe(otherBuf)
    for i = 1, n do
        local e = list[i]
        if e.isPinned then
            pinnedBuf[#pinnedBuf + 1] = e
        else
            otherBuf[#otherBuf + 1] = e
        end
    end
    if #pinnedBuf > 0 and #pinnedBuf < n then
        local out = 0
        for i = 1, #pinnedBuf do
            out = out + 1
            list[out] = pinnedBuf[i]
        end
        for i = 1, #otherBuf do
            out = out + 1
            list[out] = otherBuf[i]
        end
    end
end



local sliceHandle, sliceCo, runEnded
local pendingSliceText, pendingSliceForce, pendingSliceRowsOnly
local function RunPendingSearch()
    sliceCo = coroutine.running()
    runRowsOnly = pendingSliceRowsOnly
    Search:OnSearchTextChangedNow(pendingSliceText, pendingSliceForce)
end

local function CancelSearchRun()
    if not sliceHandle then return end
    sliceHandle:Cancel()
    sliceHandle = nil
    if ns.SearchIndex then ns.SearchIndex:ReadCanceled() end
end



local function SearchRunEnded(ok, err)
    runEnded = true
    sliceHandle = nil
    if ok then return end
    if ns.SearchIndex then ns.SearchIndex:ReadCanceled() end
    Utils.ErrorHandler(err)
end

function Search:OnSearchTextChanged(text, force, rowsOnly)
    CancelSearchRun()

    if not rowsOnly then MapPassStale() end
    pendingSliceText, pendingSliceForce, pendingSliceRowsOnly = text, force, rowsOnly

    runEnded = false
    local handle = Utils.RunSliced(RunPendingSearch, SearchRunEnded, 6, "search")
    if not runEnded then sliceHandle = handle end
end


function Search:IsSearchRunning()
    return sliceHandle ~= nil
end

local topBuf = {}



local timings = {}
Search.lastTimings = timings
local markAt = 0
local function WorkClock()
    local dps = debugprofilestop
    if not dps then return 0 end
    return dps() - (Utils.SlicePausedMs and Utils.SlicePausedMs() or 0)
end
local function Mark(phase)
    if not debugprofilestop then return end
    local now = WorkClock()
    timings[phase] = (timings[phase] or 0) + now - markAt
    markAt = now
end


local function ScoreCatalogName(nameLower, ql, qLen)
    return ns.Database:ScoreTransientName(nameLower, ql, qLen)
end






local flatSpare = {}
local function FlatEntry(n)
    local e = flatEntries[n]
    if not e then
        local m = #flatSpare
        if m > 0 then
            e = flatSpare[m]
            flatSpare[m] = nil
        else
            e = {}
        end
        flatEntries[n] = e
    end
    return e
end

local function TrimFlatEntries(n)
    for i = #flatEntries, n + 1, -1 do
        flatSpare[#flatSpare + 1] = flatEntries[i]
        flatEntries[i] = nil
    end
end

local function AppendFlat(d, n, lastGroup, mapSplit, pinned)

    local group = (SCRATCH.clipGroups and d.clipGroup) or (mapSplit and d.sectionLabel)
    if group and group ~= lastGroup then
        lastGroup = group
        n = n + 1
        local h = FlatEntry(n)
        h.name = group
        h.depth = 0
        h.isPathNode = false
        h.isSectionHeader = true
        h.isMatch = false
        h.isFlat = true
        h.flatCatKey = nil
        h.isPinned = false
        h.data = nil
    end


    if not d.clipDividerOnly then
        n = n + 1
        local e = FlatEntry(n)
        e.name = d.name
        e.depth = 0
        e.isPathNode = false
        e.isSectionHeader = false
        e.isMatch = true
        e.isFlat = true
        e.flatCatKey = nil
        e.isPinned = pinned
        e.data = d
    end
    return n, lastGroup
end




local searchGen, tailGen, tailLastGroup, tailMapSplit = 0, 0, nil, nil
local tailFrame = CreateFrame("Frame")
tailFrame:Hide()





local function AppendTailRows(n, lastGroup, mapSplit)
    local tail = SCRATCH.tail
    pcall(tsort, tail, FlatNameLess)
    local blacklist = ns.Blacklist and ns.Blacklist:HasAny() and ns.Blacklist
    for i = 1, #tail do
        local d = tail[i].data
        if d and not (d.catalogItem and ns.ItemSearch and not ns.ItemSearch:IsResolvable(d.itemID))
           and not (blacklist and blacklist:Contains(d)) then
            n, lastGroup = AppendFlat(d, n, lastGroup, mapSplit, nil)
        end
    end
    wipe(tail)
    return n, lastGroup
end

local function AppendTail()
    local tail = SCRATCH.tail
    if tailGen ~= searchGen or #tail == 0 then return end
    local t0 = WorkClock()
    local from = #flatEntries + 1
    AppendTailRows(#flatEntries, tailLastGroup, tailMapSplit)
    timings.tail = WorkClock() - t0
    ns.ResultRender:ExtendResults(flatEntries, from)
end



local ITEM_CATEGORIES = { Item = true, Bag = true, Bank = true, Warband = true }
local catalogOffRow
local function CatalogOffRow()
    if not catalogOffRow then
        catalogOffRow = {
            name = ns.L["CATALOG_OFF_ROW"], category = "Item", searchCommandDesc = ns.L["CATALOG_OFF_ROW_SUB"],
            glyph = { tex = ns.ITEMS_CATEGORY_ICON_TEX, coords = ns.ITEMS_CATEGORY_ICON_COORDS,
                      aspect = ns.ITEMS_CATEGORY_ICON_ASPECT },
            noPin = true, noLearn = true, noMenu = true, turnOnFilter = "catalog",
        }
    end
    return catalogOffRow
end




local lastPaintText, lastPaintFilter
Utils.SafeOnUpdate(tailFrame, function(self)
    self:Hide()
    AppendTail()
end)

function Search:OnSearchTextChangedNow(text, force)




    if InCombatLockdown() then return end


    if sliceHandle and coroutine.running() ~= sliceCo then CancelSearchRun() end

    local rowsOnly = runRowsOnly
    runRowsOnly = false
    searchGen = searchGen + 1
    wipe(SCRATCH.tail)
    wipe(timings)
    timings.text = text
    markAt = WorkClock()






    if text and text ~= "" then
        local guardFrame = Search:GetSearchFrame()
        local guardBox = guardFrame and guardFrame.editBox
        if guardBox and guardBox.HasAutocomplete and guardBox.HasAutocomplete()
           and guardBox.GetTypedText and text == (guardBox:GetText() or "") then
            text = guardBox.GetTypedText() or text
        end
    end



    if text and not Search:GetQuickFilter() and Search:IsQuickFilterSuggestionsActive()
       and text:match("^%s*@" .. Filters.TAG_CHARS .. "*$") then
        Search:UpdateQuickFilterSuggestions()
        return
    end

    if Search:IsSelectingResult() then return end











    if not force and Search:GetSearchFrame() and Search:GetSearchFrame().editBox
        and not Search:GetSearchFrame().editBox:HasFocus() then
        return
    end

    if text then text = strtrim(text) end




    if not rowsOnly and text ~= tipText then Tooltips:ClearResultTooltips() end
    tipText = text
    local quickFilter = self:GetQuickFilter()



    if quickFilter and quickFilter.key == "icons" then
        if ns.RequestIconSearch and ns.RequestIconSearch() then
            Results:ShowIconGrid(text or "")
        end
        return
    end

    if quickFilter and quickFilter.quicklistID then
        if ns.Quicklists then ns.Quicklists:ShowView(quickFilter.quicklistID, text) end
        return
    end

    if quickFilter and quickFilter.charView then
        if ns.Characters then ns.Characters:ShowView(quickFilter, text) end
        return
    end

    if quickFilter and quickFilter.skillUpsView then
        if ns.SkillUps then ns.SkillUps:ShowView(quickFilter, text) end
        return
    end

    if quickFilter and quickFilter.sourcesItem then
        if ns.ItemSources then ns.ItemSources:ShowView(quickFilter, text) end
        return
    end

    if quickFilter and quickFilter.vendorWares then
        if ns.ItemSources then ns.ItemSources:ShowWaresView(quickFilter, text) end
        return
    end


    local sourcesOf = not quickFilter and ns.ItemSources and ns.ItemSources.SourcesQuery(text)
    if sourcesOf then text = sourcesOf end

    local placesLevel = not quickFilter and ns.LevelPlaces and ns.LevelPlaces.Query(text)
    if placesLevel then
        ns.LevelPlaces:Show(placesLevel)
        return
    end
    if (not text or text == "") and not quickFilter then
        if ns.Database and ns.Database.CancelDynamicWarmup then
            ns.Database:CancelDynamicWarmup()
        end





        local hasFocus = Search:GetSearchFrame() and Search:GetSearchFrame().editBox
            and Search:GetSearchFrame().editBox:HasFocus()
        local hasPins = Results.HasPinnedItems and Results:HasPinnedItems()
        if force or hasFocus or hasPins then
            self:ShowPinnedItems()
        else
            self:HideResults()
        end
        return
    end

    local activeFilters = EasyFind.db.uiSearchFilters



    local providerFilters = not quickFilter and activeFilters or nil
    local providerContext = SearchEngine and SearchEngine:BuildContext(text, quickFilter, providerFilters)
    local explicitStatistics = providerContext and SearchEngine
        and SearchEngine.LooksLikeStatistics and SearchEngine:LooksLikeStatistics(providerContext)
    local explicitBosses = providerContext and SearchEngine
        and SearchEngine.LooksLikeBosses and SearchEngine:LooksLikeBosses(providerContext)

    local commandsOff = activeFilters and activeFilters.commands == false
    local commandEntries = (not quickFilter) and (not commandsOff)
        and self:GetSearchBarCommandSuggestionEntries(text)
    if commandEntries then
        FloatPinnedFirst(commandEntries, #commandEntries)
        self:ShowHierarchicalResults(commandEntries)
        return
    end

    wipe(collapsedNodes)
    local calculatorData = (not quickFilter) and self:EvaluateCalculatorExpression(text) or nil
    local calculatorLauncher = (not quickFilter and not calculatorData)
        and self:GetCalculatorLauncherMatch(text) or nil


    local answerEntry = (not quickFilter and not calculatorData) and ns.Answers
        and ns.Answers.GetAnswerEntry
        and ns.Answers:GetAnswerEntry(text) or nil





    local filters = providerFilters
    local optionsOff = filters and filters.options == false
    local statisticsOff = filters and filters.statistics == false and not explicitStatistics
    local achHits, achPending
    local skipCategories
    if filters then


        if ns.CategoryMap.BuildSkipCategories(filters, SCRATCH.skipCategories,
                explicitStatistics, explicitBosses) then
            skipCategories = SCRATCH.skipCategories
        end
    end
    local results
    if calculatorData or calculatorLauncher then
        results = SCRATCH.calculatorResults
        wipe(results)
    elseif quickFilter and (not text or text == "") then



        SCRATCH.browseResults = SCRATCH.browseResults or {}
        results = SCRATCH.browseResults
        wipe(results)
        local data = ns.Database.uiSearchData
        local ProviderOf = ns.Extensions and ns.Extensions.ProviderOf
        local decorator = quickFilter.decorator
        for i = 1, #data do
            local d = data[i]
            if self:QuickFilterAllowsData(d, quickFilter) then



                local listed
                if decorator and not (quickFilter.joined and quickFilter.categoryLookup[d.category]) then
                    listed = ns.Extensions.DecoratorBrowses(decorator, d)
                else
                    local provider = ProviderOf and ProviderOf(d)
                    local browse = provider and provider.browse
                    listed = not browse or browse(d)
                end
                if listed then
                    results[#results + 1] = { data = d, score = 0 }
                end
            end
        end
    else
        results = ns.Database:SearchUI(text, skipCategories, quickFilter and quickFilter.categories)





        if text ~= "" and ((quickFilter and quickFilter.key == "achievements")
            or (not quickFilter and (not filters or filters.achievements ~= false))) then
            achHits = self:RequestAchievementSearch(text)
            achPending = achHits == nil and self.IsAchievementSearchPending
                and self:IsAchievementSearchPending(text) or false
        end
    end
    Mark("searchUI")
    if providerContext and not calculatorData and not calculatorLauncher then










        local syncPhase, syncChanged = true, false
        SearchEngine:RequestProviders(providerContext, function(changed)
            if syncPhase then
                if changed then syncChanged = true end
            else
                RefreshSearchAfterProviderLoad(changed)
            end
        end, #results)
        syncPhase = false
        if syncChanged then
            results = ns.Database:SearchUI(text, skipCategories, quickFilter and quickFilter.categories)
            timings.searchedAgain = true
        end
        Mark("providers")






        local pendingLoad = SearchEngine.HasPendingProviders and SearchEngine:HasPendingProviders()
        if (pendingLoad or achPending) and paintHoldForcedFor ~= text then
            paintHoldText = text
            if paintHoldTimerFor ~= text then
                paintHoldTimerFor = text
                local held = text
                Utils.SafeAfter(pendingLoad and PAINT_HOLD_MAX or ACH_HOLD_MAX, function()
                    if paintHoldText == held then
                        paintHoldForcedFor = held
                        Search:RefreshActiveSearch()
                    end
                end)
            end
            return
        end
        paintHoldText = nil
    end









    wipe(SCRATCH.aliasSeen)
    SCRATCH.aliasSeenKeys = SCRATCH.aliasSeenKeys or {}
    wipe(SCRATCH.aliasSeenKeys)





    local function MarkPromoted(promoted, data)
        promoted[data] = true
        local key = ns.Aliases and ns.Aliases.GetEntryKey and ns.Aliases:GetEntryKey(data)
        if key then SCRATCH.aliasSeenKeys[key] = true end
    end
    local function IsPromoted(promoted, data)
        if promoted[data] then return true end
        if next(SCRATCH.aliasSeenKeys) == nil then return false end
        local key = ns.Aliases and ns.Aliases.GetEntryKey and ns.Aliases:GetEntryKey(data)
        return key and SCRATCH.aliasSeenKeys[key] or false
    end



    local mapResults
    if not calculatorData and not calculatorLauncher and ns.MapSearch and ns.MapSearch.SearchForUI
       and ((quickFilter and (quickFilter.key == "map" or quickFilter.decorator))
            or (not quickFilter and filters and filters.map ~= false)) then
        mapResults = MapPass(text, rowsOnly)
    end
    Mark("map")
    local mapPass = ns.MapSearchSearch and ns.MapSearchSearch.uiSearchCount
    wipe(SCRATCH.mapBoostSeen)
    wipe(SCRATCH.catalogBoostSeen)
    local seenMapRows = SCRATCH.mapBoostSeen



    local seenCatalogItems = SCRATCH.catalogBoostSeen
    if ns.Aliases then
        local aliasMatches = ns.Aliases:GetMatches(slower(text))
        if aliasMatches then
            local promoted = SCRATCH.aliasSeen
            for i = #aliasMatches, 1, -1 do
                local hit = aliasMatches[i]
                local data = hit.data



                local aliasScore = ALIAS_SCORE_BASE - i * 10
                if data and data.mapCategoryAlias then


                    local catRows = ns.MapSearch and ns.MapSearch.GetCategoryResultsForUI
                        and ns.MapSearch:GetCategoryResultsForUI(data.mapCategoryAlias, 3, nil, nil, text)
                    if catRows then
                        for j = #catRows, 1, -1 do
                            local wrapped = {}
                            for k, v in pairs(catRows[j]) do wrapped[k] = v end
                            wrapped.query = (hit.alias and hit.alias.text) or text
                            seenMapRows[MapRow.Key(wrapped)] = true
                            tinsert(results, 1, { data = wrapped, score = aliasScore - j, isAlias = true })
                        end
                    end
                elseif data and data.mapSearchResult then
                    local wrapped = {}
                    for k, v in pairs(data) do wrapped[k] = v end
                    wrapped.query = (hit.alias and hit.alias.text) or text
                    seenMapRows[MapRow.Key(wrapped)] = true
                    tinsert(results, 1, { data = wrapped, score = aliasScore, isAlias = true })
                elseif data and not IsPromoted(promoted, data) then
                    MarkPromoted(promoted, data)
                    if data.catalogItem and data.itemID then
                        seenCatalogItems[data.itemID] = true
                    end
                    tinsert(results, 1, { data = data, score = aliasScore, isAlias = true })
                end
            end
        end
    end











    local suppressMapCategory
    if not quickFilter
       and (not filters or filters.map ~= false)
       and not calculatorData and not calculatorLauncher then
        local boostCat = ns.MapSearchData and ns.MapSearchData.KEYWORD_TO_CATEGORY
            and ns.MapSearchData.KEYWORD_TO_CATEGORY[slower(text)]
        local localScope = boostCat and ns.MapSearch and ns.MapSearch.ZoneOnlyForCategory(boostCat) or false
        local catRows = boostCat and ns.MapSearch and ns.MapSearch.GetCategoryResultsForUI
            and ns.MapSearch:GetCategoryResultsForUI(boostCat, localScope and 8 or 3, true, localScope, text)
        if localScope then
            suppressMapCategory = boostCat
        end
        if catRows then



            local natural = wipe(SCRATCH.mapNaturalScore)
            for ri = 1, mapResults and #mapResults or 0 do
                local r = mapResults[ri]
                if r.data then natural[MapRow.Key(r.data)] = r.score or 0 end
            end
            for j = #catRows, 1, -1 do
                local src = catRows[j]
                local rowKey = MapRow.Key(src)
                if not seenMapRows[rowKey] then
                    seenMapRows[rowKey] = true
                    local wrapped = {}
                    for k, v in pairs(src) do wrapped[k] = v end
                    local score = CATEGORY_ROW_SCORE - j
                    local own = natural[rowKey]
                    if own and own > score then score = own end
                    tinsert(results, 1, { data = wrapped, score = score, isAlias = true })
                end
            end
        end
    end







    if ns.Learned then
        local learned, olderPicks = ns.Learned:GetBoost(slower(text))




        local function LearnedAllowed(e)
            if not e then return false end
            if quickFilter and not self:QuickFilterAllowsData(e, quickFilter) then return false end
            if skipCategories and e.category and skipCategories[e.category] then return false end
            if e.catalogItem and filters
               and ns.CategoryMap.IsProviderFilterOff(filters, "catalog") then
                return false
            end
            return true
        end
        if learned then
            local promoted = SCRATCH.aliasSeen




            if olderPicks and not learned.mapSearchResult then
                for i = #olderPicks, 1, -1 do
                    local e = olderPicks[i]
                    if not e.mapSearchResult and LearnedAllowed(e) and not IsPromoted(promoted, e) then
                        MarkPromoted(promoted, e)
                        if e.catalogItem and e.itemID then seenCatalogItems[e.itemID] = true end
                        tinsert(results, 1, { data = e, score = LEARNED_SCORE - i, isAlias = true })
                    end
                end
            end
            if learned.mapSearchResult then



                local src
                if ns.MapSearch.IsKindQuery and ns.MapSearch:IsKindQuery(text) then
                    local best = math.huge
                    for ri = 1, mapResults and #mapResults or 0 do
                        local d = mapResults[ri].data
                        if d and d.category == learned.category then
                            local near = d.mapNear or math.huge
                            if not src or near < best then src, best = d, near end
                        end
                    end
                else
                    src = MapRow.SamePlace(learned, mapResults) or learned
                end
                if src then
                    local wrapped = {}
                    for k, v in pairs(src) do wrapped[k] = v end
                    wrapped.query = text

                    wrapped.learnedFrom = learned
                    seenMapRows[MapRow.Key(wrapped)] = true
                    tinsert(results, 1, { data = wrapped, score = LEARNED_SCORE, isAlias = true })
                end
            elseif LearnedAllowed(learned) and not IsPromoted(promoted, learned) then
                MarkPromoted(promoted, learned)
                if learned.catalogItem and learned.itemID then
                    seenCatalogItems[learned.itemID] = true
                end
                tinsert(results, 1, { data = learned, score = LEARNED_SCORE, isAlias = true })
            end
        end
    end








    do
        local q = slower(text)
        local featureName = slower(ns.L and ns.L["FILTER_SNIPPETS"] or "snippets")
        if #q >= 3 and (featureName:sub(1, #q) == q or ("snippets"):sub(1, #q) == q) then
            for ri = 1, #results do
                local d = results[ri].data
                if d and d.snippetsLauncher then
                    results[ri].score = LEARNED_SCORE + 2
                elseif d and d.createRow and d.category == "Snippet" then
                    results[ri].score = LEARNED_SCORE + 1
                end
            end
        end
    end

    if quickFilter then
        wipe(SCRATCH.quickFilterResults)
        local filtered = SCRATCH.quickFilterResults
        local fi = 0
        for ri = 1, #results do
            local r = results[ri]
            if r and self:QuickFilterAllowsData(r.data, quickFilter) then
                fi = fi + 1
                filtered[fi] = r
            end
        end
        for i = fi + 1, #filtered do filtered[i] = nil end
        results = filtered
    end








    local hidePassives = EasyFind.db.abilityHidePassives
    local hideAchievementHeaders = EasyFind.db.hideAchievementHeaders
    local hideGuildAchievements = EasyFind.db.hideGuildAchievements
    local macroGeneralOff = EasyFind.db.macroFilterGeneral == false
    local macroCharOff = EasyFind.db.macroFilterChar == false
    local bossDungeonOff = EasyFind.db.bossFilterDungeon == false
    local bossRaidOff = EasyFind.db.bossFilterRaid == false
    local hideJunk = EasyFind.db.bagHideJunk == true





    local statMode = EasyFind.db.statisticFilterMode
    if statMode == "all" then statMode = nil end
    local specRowsOff = EasyFind.db.talentShowSpecs == false
    local loadoutRowsOff = EasyFind.db.talentShowLoadouts == false
    local commandNativeOff = EasyFind.db.commandShowNative == false
    local commandCustomOff = EasyFind.db.commandShowCustom == false

    local addonFilters = EasyFind.db.addonOptionsFilters
    local anyAddonOff = addonFilters ~= nil and next(addonFilters) ~= nil

    local skillSwitches = EasyFind.db.skillFilters
    local anySkillOff = type(skillSwitches) == "table" and next(skillSwitches) ~= nil
    local bossesFilterOff = filters and filters.bosses == false and not explicitBosses
    local statisticsFilterOff = filters and filters.statistics == false and not explicitStatistics
    if filters and (filters.abilities == false or bossesFilterOff
                    or filters.achievements == false or statisticsFilterOff
                    or filters.currencies == false or filters.reputations == false
                    or filters.bags == false or filters.bank == false
                    or filters.macros == false
                    or filters.options == false
                    or filters.gameOptions == false or filters.addonOptions == false
                    or filters.titles == false or filters.gearSets == false
                    or filters.skills == false
                    or filters.talents == false or filters.commands == false
                    or hidePassives or hideAchievementHeaders or hideGuildAchievements
                    or macroGeneralOff or macroCharOff or bossDungeonOff or bossRaidOff
                    or hideJunk or commandNativeOff or commandCustomOff
                    or statMode or specRowsOff or loadoutRowsOff or anyAddonOff or anySkillOff) then
        wipe(SCRATCH.filteredResults)
        local filtered = SCRATCH.filteredResults
        local fi = 0
        for ri = 1, #results do
            local r = results[ri]
            if r.isAlias then
                fi = fi + 1
                filtered[fi] = r
            else
                local d = r.data

                local cat = d and d.category
                local bucket = Filters.GetUIBucket(d)
                local bucketOff = bucket and filters[bucket] == false
                if (explicitStatistics and bucket == "statistics")
                   or (explicitBosses and bucket == "bosses") then
                    bucketOff = false
                end
                local parentOff = optionsOff
                    and (bucket == "gameOptions" or bucket == "addonOptions")
                local passiveOff = hidePassives and cat == "Ability" and d.isPassive
                local headerOff = hideAchievementHeaders and cat == "Achievement Category"
                local guildAchievementOff = hideGuildAchievements and self:IsGuildAchievementData(d)
                local macroTypeOff = cat == "Macro"
                    and ((d.macroIsChar and macroCharOff) or (not d.macroIsChar and macroGeneralOff))
                local bossTypeOff = cat == "Boss"
                    and ((d.isRaidBoss and bossRaidOff) or (not d.isRaidBoss and bossDungeonOff))
                local junkOff = hideJunk and cat == "Bag" and d.quality == 0
                local statOff = false
                if statMode and d and d.statisticID then
                    local _, hasValue = ns.GetStatisticValue(d.statisticID)
                    statOff = (statMode == "recorded") ~= hasValue
                end
                local talentSwapOff = d and ((specRowsOff and d.specSetIndex)
                    or (loadoutRowsOff and d.loadoutConfigID))
                local commandTypeOff = cat == "Command"
                    and ((d.isNativeCommand and commandNativeOff) or (not d.isNativeCommand and commandCustomOff))
                local addonOff = anyAddonOff and d and d.addon ~= nil and addonFilters["addon:" .. d.addon] == false
                local skillOff = anySkillOff and d and d.skillHeader ~= nil and skillSwitches[d.skillHeader] == false
                if not passiveOff and not headerOff and not guildAchievementOff
                   and not macroTypeOff and not bossTypeOff and not junkOff
                   and not commandTypeOff and not statOff and not talentSwapOff and not addonOff and not skillOff
                   and (not bucket or (not bucketOff and not parentOff)) then
                    fi = fi + 1
                    filtered[fi] = r
                end
            end
        end
        for i = fi + 1, #filtered do filtered[i] = nil end
        results = filtered
    end




    local anyFact = false
    for ri = 1, #results do
        local d = results[ri].data
        if d and d.factWords then
            anyFact = true
            break
        end
    end
    if anyFact then
        local asked = SCRATCH.factAsked
        wipe(asked)
        for _, word in ipairs(SearchText.NormalizeAndTokenize(text)) do asked[word] = true end
        wipe(SCRATCH.factResults)
        local kept, fi = SCRATCH.factResults, 0
        for ri = 1, #results do
            local r = results[ri]
            local words = r.data and r.data.factWords
            local show = not words
            for wi = 1, words and #words or 0 do
                if asked[words[wi]] then
                    show = true
                    break
                end
            end
            if show then
                fi = fi + 1
                kept[fi] = r
            end
        end
        results = kept
    end












    if mapResults and ns.MapSearchSearch.uiSearchCount ~= mapPass then
        Mark("rows")
        mapResults = ns.MapSearch:SearchForUI(text)
        MapPassRedone(mapResults)
        Mark("mapAgain")
    end

    wipe(flatCombined)
    local combined = flatCombined
    if calculatorData then




        combined[#combined + 1] = { data = calculatorData, score = math.huge }
        combined[#combined + 1] = { data = ns.Calculator._calculator.LAUNCHER, score = 1e308 }
    elseif calculatorLauncher then
        combined[#combined + 1] = { data = calculatorLauncher, score = math.huge }
    end
    if answerEntry then
        combined[#combined + 1] = { data = answerEntry, score = math.huge }
    end


    local promoted = SCRATCH.aliasSeen
    for ri = 1, #results do
        local r = results[ri]
        local d = r.data
        if r.isAlias or not IsPromoted(promoted, d) then
            combined[#combined + 1] = r
            local itemID = d and d.itemID
            if itemID and ITEM_ROW_CATEGORY[d.category] then seenCatalogItems[itemID] = r end
        end
    end
    if mapResults then





        local boostedMapRows = SCRATCH.mapBoostSeen
        local anyBoosted = next(boostedMapRows) ~= nil
        local decorated = quickFilter and quickFilter.decorator and quickFilter
        for ri = 1, #mapResults do
            local r = mapResults[ri]
            if not (r.data and ((anyBoosted and boostedMapRows[MapRow.Key(r.data)])
                    or (suppressMapCategory and r.data.category == suppressMapCategory)
                    or (decorated and not self:QuickFilterAllowsData(r.data, decorated)))) then
                combined[#combined + 1] = r
            end
        end
    end







    if not calculatorData and not calculatorLauncher and text ~= "" and ns.ItemSearch
       and ns.Database and ns.Database.ScoreTransientName
       and ((quickFilter and (quickFilter.key == "items" or quickFilter.key == "catalog"))
            or (not quickFilter and (not filters
                 or not ns.CategoryMap.IsProviderFilterOff(filters, "catalog")))) then
        Mark("rows")


        local cut = Steer and Steer.Strip(text, "Item")
        local itemHits = ns.ItemSearch:Search(cut or text, ScoreCatalogName)
        Mark("catalog")
        if itemHits then
            for ii = 1, #itemHits do
                local hit = itemHits[ii]
                local hitData = hit.data
                if cut then hit.score = hit.score - 1 end
                local twin = hitData and hitData.itemID and seenCatalogItems[hitData.itemID]
                if not twin then
                    combined[#combined + 1] = hit
                elseif twin ~= true and (twin.score or 0) < hit.score then

                    twin.score = hit.score
                end
            end
        end
    end




    if not quickFilter and not calculatorData and not calculatorLauncher and ns.Extensions then
        local launchers = ns.Extensions.LauncherMatches(text, wipe(SCRATCH.launchers))
        local lowerText = slower(text)
        for li = 1, #launchers do
            local launcher = launchers[li]
            local byName = launcher.nameLower and ns.Extensions.StartsWord(launcher.nameLower, lowerText)
            combined[#combined + 1] = { data = launcher, score = byName and LAUNCHER_NAME_SCORE or LAUNCHER_WORD_SCORE }
        end
    end


    if quickFilter and quickFilter.key == "notes" and text ~= "" and ns.Notes and ns.Notes.NewFromSearch then
        local lower = slower(text)
        local titled = false
        for ri = 1, #combined do
            local d = combined[ri].data
            if d and d.noteID and d.nameLower == lower then titled = true break end
        end
        if not titled then
            local title = text
            combined[#combined + 1] = { score = 1, data = {
                name = Utils.sformat(ns.L["NOTES_ROW_NEW_FMT"], title), category = "Notes",
                searchCommandDesc = ns.L["NOTES_ROW_NEW_SUB"], icon = ns.NOTES_ICON_TEX,
                createRow = true, noPin = true, noLearn = true,
                nativeRun = function() ns.Notes.NewFromSearch(title) end,
            } }
        end
    end

    if achHits then
        if ns.Database and ns.Database.ScoreName then
            local lowerQ = slower(text)
            local qLen = #lowerQ


            for ai = 1, #achHits do
                local entry = achHits[ai]
                local score = ns.Database:ScoreName(entry.nameLower, lowerQ, qLen)
                if score and score > 0
                   and not IsPromoted(SCRATCH.aliasSeen, entry)
                   and not (hideGuildAchievements and self:IsGuildAchievementData(entry))
                   and not (statisticsOff and entry.achievementID
                            and ns.Database:IsStatisticAchievement(entry.achievementID)) then
                    combined[#combined + 1] = { data = entry, score = score }
                end
            end
        end
    end


    if not quickFilter and not calculatorData and not calculatorLauncher and #text >= 3
       and ns.Caps.itemCatalog and filters and ns.CategoryMap.IsProviderFilterOff(filters, "catalog") then
        local itemRows = 0
        for ri = 1, #combined do
            local d = combined[ri].data
            if d and ITEM_CATEGORIES[d.category] then itemRows = itemRows + 1 end
        end
        if itemRows < 3 then combined[#combined + 1] = { score = 1, data = CatalogOffRow() } end
    end

    Mark("joins")








    local mapSplit = quickFilter and quickFilter.key == "map" and ns.MapSearch and ns.MapSearch.SplitUIRowsByZone
    SCRATCH.clipGroups = quickFilter ~= nil and quickFilter.key == "clipboard"



    local resultsFrame = Search:GetResultsFrame()
    local repaint = text == lastPaintText and quickFilter == lastPaintFilter
        and resultsFrame ~= nil and resultsFrame:IsShown()
    local TOP_N = mapSplit and #combined or 15
    local kept = 0
    local blacklist = ns.Blacklist and ns.Blacklist:HasAny() and ns.Blacklist

    local tail = SCRATCH.tail
    for ri = 1, #combined do
        local entry = combined[ri]
        local d = entry.data
        if kept < TOP_N or FlatNameLess(entry, topBuf[kept]) then
            if not (d and d.catalogItem and ns.ItemSearch
                    and not ns.ItemSearch:IsResolvable(d.itemID))
               and not (blacklist and blacklist:Contains(d)) then
                local displaced = kept == TOP_N and topBuf[kept] or nil
                local at = kept < TOP_N and kept + 1 or kept
                while at > 1 and FlatNameLess(entry, topBuf[at - 1]) do
                    topBuf[at] = topBuf[at - 1]
                    at = at - 1
                end
                topBuf[at] = entry
                if kept < TOP_N then kept = kept + 1 end
                if displaced then tail[#tail + 1] = displaced end
            end
        else
            tail[#tail + 1] = entry
        end
    end
    for ri = 1, kept do combined[ri] = topBuf[ri] end
    for ri = #combined, kept + 1, -1 do combined[ri] = nil end
    wipe(topBuf)

    local sourcesItem = sourcesOf and ns.ItemSources.PickItem(combined, sourcesOf)
    if sourcesItem then
        ns.ItemSources:ShowTyped(sourcesItem)
        lastPaintText, lastPaintFilter = nil, nil
        Mark("render")
        return
    end

    if mapSplit then ns.MapSearch:SplitUIRowsByZone(combined) end

    local n, lastGroup = 0, nil
    for ri = 1, #combined do
        local d = combined[ri] and combined[ri].data
        if d then
            n, lastGroup = AppendFlat(d, n, lastGroup, mapSplit, (not d.noPin and IsUIItemPinned(d)) and true or false)
        end
    end
    if repaint and #tail > 0 then n, lastGroup = AppendTailRows(n, lastGroup, mapSplit) end
    TrimFlatEntries(n)

    FloatPinnedFirst(flatEntries, n)
    Mark("combine")

    self:ShowHierarchicalResults(flatEntries, repaint)
    lastPaintText, lastPaintFilter = text, quickFilter
    Mark("render")
    if #tail > 0 then
        tailGen, tailLastGroup, tailMapSplit = searchGen, lastGroup, mapSplit
        if Utils.SliceYield() then AppendTail() else tailFrame:Show() end
    end
end
