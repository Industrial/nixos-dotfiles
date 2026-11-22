local _, ns = ...

local Database = ns.Database
local Utils = ns.Utils
local L = ns.L







local URGENT_STEP_BUDGET = 0.008
local GetTime = GetTime
local dps = rawget(_G, "debugprofilestop")
local urgentFrameStamp, urgentSpentThisFrame = -1, 0

local function UrgentBudgetLeft()
    local now = GetTime and GetTime() or 0
    if now ~= urgentFrameStamp then
        urgentFrameStamp = now
        urgentSpentThisFrame = 0
    end
    return URGENT_STEP_BUDGET - urgentSpentThisFrame
end

local function AddUrgentSpend(seconds)
    urgentSpentThisFrame = urgentSpentThisFrame + (seconds or 0)
end

if not Database then return end





local function getScheduler()
    return ns.Scheduler
end









local providerCategory = ns.CategoryMap.ProviderCategory
local dynamicProviders = {
    { key = "currencies", category = providerCategory["currencies"],             fn = "PopulateDynamicCurrencies", eager = true },
    { key = "reputations", category = providerCategory["reputations"],           fn = "PopulateDynamicReputations", eager = true },
    { key = "achievements", category = providerCategory["achievements"], fn = "PopulateDynamicAchievements" },
    { key = "statistics", category = providerCategory["statistics"],            fn = "PopulateDynamicStatistics", asyncFn = "PopulateDynamicStatisticsAsync" },
    { key = "charRows", category = providerCategory["charRows"],     fn = "PopulateDynamicCharRows", eager = true },
    { key = "charPlayed", category = providerCategory["charPlayed"], fn = "PopulateDynamicCharPlayed", eager = true },
    { key = "charSeen", category = providerCategory["charSeen"],     fn = "PopulateDynamicCharSeen", eager = true },
    { key = "charGold", category = providerCategory["charGold"],     fn = "PopulateDynamicCharGold", eager = true },
    { key = "charLevel", category = providerCategory["charLevel"],   fn = "PopulateDynamicCharLevel", eager = true },
    { key = "mounts", category = providerCategory["mounts"],          fn = "PopulateDynamicMounts", asyncFn = "PopulateDynamicMountsAsync", keepOnTrim = true },
    { key = "toys", category = providerCategory["toys"],            fn = "PopulateDynamicToys" },
    { key = "housing", category = providerCategory["housing"],      asyncFn = "PopulateDynamicHousingAsync" },
    { key = "pets", category = providerCategory["pets"],            fn = "PopulateDynamicPets" },
    { key = "outfits", category = providerCategory["outfits"],         fn = "PopulateDynamicOutfits" },
    { key = "heirlooms", category = providerCategory["heirlooms"],       fn = "PopulateDynamicHeirlooms" },
    { key = "titles", category = providerCategory["titles"],          fn = "PopulateDynamicTitles", eager = true },
    { key = "gearSets", category = providerCategory["gearSets"],       fn = "PopulateDynamicGearSets", eager = true },
    { key = "skills", category = providerCategory["skills"],          fn = "PopulateDynamicSkills", eager = true },
    { key = "holidays", category = providerCategory["holidays"],      fn = "PopulateDynamicHolidays", eager = true },
    { key = "addons", category = providerCategory["addons"],          fn = "PopulateDynamicAddOns", eager = true },
    { key = "friends", category = providerCategory["friends"],        fn = "PopulateDynamicFriends" },
    { key = "guildMembers", category = providerCategory["guildMembers"], fn = "PopulateDynamicGuildMembers" },
    { key = "macros", category = providerCategory["macros"],          fn = "PopulateDynamicMacros", eager = true },
    { key = "abilities", category = providerCategory["abilities"],        fn = "PopulateDynamicAbilities", post = "AddSpellWords" },
    { key = "talents", category = providerCategory["talents"],         fn = "PopulateDynamicTalents", post = "AddSpellWords" },
    { key = "bags", category = providerCategory["bags"],            fn = "PopulateDynamicBags" },
    { key = "bank", category = providerCategory["bank"],            fn = "PopulateDynamicBank" },
    { key = "mail", category = providerCategory["mail"],            fn = "PopulateDynamicMail" },
    { key = "guildBank", category = providerCategory["guildBank"],  fn = "PopulateDynamicGuildBank" },
    { key = "transmogSets", category = providerCategory["transmogSets"], fn = "PopulateDynamicTransmogSets", asyncFn = "PopulateDynamicTransmogSetsAsync", pre = "SyncTransmogSetFiltersFromUI", keepOnTrim = true },
    { key = "appearanceItems", category = providerCategory["appearanceItems"], fn = "PopulateDynamicAppearanceItems", asyncFn = "PopulateDynamicAppearanceItemsAsync", pre = "SyncAppearanceItemFiltersFromUI" },
    { key = "loot", category = providerCategory["loot"],           fn = "PopulateDynamicLoot", asyncFn = "PopulateDynamicLootAsync" },
    { key = "bosses", category = providerCategory["bosses"],           fn = "PopulateDynamicBosses", asyncFn = "PopulateDynamicBossesAsync" },
    { key = "commands", category = providerCategory["commands"],        fn = "PopulateDynamicCommands", eager = true },
    { key = "professions", category = providerCategory["professions"],  fn = "PopulateDynamicProfessions", eager = true },
}




if ns.Caps and ns.Caps.PruneRows then ns.Caps.PruneRows(dynamicProviders) end

local dynamicProviderByKey = {}

local providerByCategory = {}
for i = 1, #dynamicProviders do
    local provider = dynamicProviders[i]
    provider.loaded = false
    provider.dirty = true
    dynamicProviderByKey[provider.key] = provider
    if provider.category then providerByCategory[provider.category] = provider end
end



Database.populateMarks = Database.populateMarks or {}
function Database:NotePopulateStart(category, removed)
    local data = self.uiSearchData
    self.populateMarks[category] = { removed = removed, after = data[#data] or false }

    if providerByCategory[category] and ns.SearchIndex then ns.SearchIndex:Hold(category) end
end


local function Unhold(category)
    if category and Database.populateMarks[category] then return end
    if ns.SearchIndex then ns.SearchIndex:Unhold(category) end
end
function Database:UnholdPopulated(category) Unhold(category) end




function Database:TakePopulatedRows(category)
    local mark = category and self.populateMarks[category]
    if not mark then return nil, nil end
    self.populateMarks[category] = nil
    local data, rows, n = self.uiSearchData, {}, 0
    local after = mark.after
    for i = #data, 1, -1 do
        local entry = data[i]
        if entry == after then break end
        if entry.category == category then
            n = n + 1
            rows[n] = entry
        end
    end
    for i = 1, math.floor(n / 2) do rows[i], rows[n + 1 - i] = rows[n + 1 - i], rows[i] end
    return mark.removed, rows
end



local function ConsumePopulateBookkeeping(database, provider, wantRows)
    local category = provider.category
    if wantRows then return database:TakePopulatedRows(category) end
    local mark = category and database.populateMarks[category]
    if mark then database.populateMarks[category] = nil end
    Unhold(category)
    return mark and mark.removed
end

local function FinishDynamicProvider(database, provider, ok, err, changed, onDone)
    if err == "cancelled" then
        provider.loaded = false
        provider.dirty = true
        local removed = ConsumePopulateBookkeeping(database, provider)
        if removed ~= nil and database.ResetSearchCache then
            database:ResetSearchCache()
        end
        onDone(false)
        return
    end
    if not ok then
        provider.loaded = false
        provider.dirty = false
        if EasyFind and EasyFind.Print then
            EasyFind:Print("|cffff4444" .. (L["ERR_SEARCH_DATA_FAILED"]):format(provider.key, tostring(err)) .. "|r")
        end



        local removed = ConsumePopulateBookkeeping(database, provider)
        if removed ~= nil and database.ResetSearchCache then
            database:ResetSearchCache()
        end
        onDone(false)
        return
    end

    provider.loaded = true
    provider.dirty = false
    local removed, rows = ConsumePopulateBookkeeping(database, provider, true)
    local category = provider.category
    if rows and ns.SearchSegments then
        ns.SearchSegments.Attach(provider.key, rows, function() Unhold(category) end)
    else
        Unhold(category)
    end
    local appendOnly = removed == false
    if changed ~= false then
        if appendOnly and rows and database.NoteAppendedEntries then
            database:NoteAppendedEntries(rows)
        elseif database.ResetSearchCache then
            if database._dynamicBatchLoading then
                database._dynamicBatchChanged = true
            else
                database:ResetSearchCache()
            end
        end
    end
    onDone(changed ~= false)
end

local function NotifyProviderWaiters(provider, changed)
    provider.urgent = nil
    local waiters = provider.waiting
    provider.waiting = nil
    if waiters then
        for i = 1, #waiters do
            waiters[i](changed)
        end
    end
end



local function jobIdForProvider(provider)
    return "dynamic:" .. provider.key
end





local BACKGROUND_SLICE_MS, URGENT_SLICE_MS = 1.5, 4

local function runProviderJob(database, provider, schedDone)
    local function finishWaiters(changed)
        NotifyProviderWaiters(provider, changed)
        schedDone()
    end
    local function Pace() return provider.urgent and URGENT_SLICE_MS or BACKGROUND_SLICE_MS end



    provider.lastRunAt = GetTime()

    local pre = provider.pre and database[provider.pre]
    if pre then pre(database) end



    local asyncFn = provider.asyncFn and database[provider.asyncFn]
    if asyncFn then
        Utils.RunSliced(function()
            asyncFn(database, function(changed, asyncErr)
                FinishDynamicProvider(database, provider, not asyncErr, asyncErr, changed, finishWaiters)
            end)
        end, function(ok, err)
            if not ok then
                FinishDynamicProvider(database, provider, false, err, false, finishWaiters)
            end
        end, Pace, "provider " .. provider.key)
        return
    end

    local fn = type(provider.fn) == "function" and provider.fn or database[provider.fn]
    if not fn then
        NotifyProviderWaiters(provider, false)
        schedDone()
        return
    end







    Utils.RunSliced(function()
        local ready = fn(database)
        local post = provider.post and database[provider.post]
        if post and ready ~= false then post(database, provider.category, provider.key) end
        return ready
    end, function(ok, readyOrErr)
        if ok and readyOrErr == false then
            provider.loaded = false
            provider.dirty = true




            provider.notReadyAt = GetTime()
            local removed = ConsumePopulateBookkeeping(database, provider)
            if removed ~= nil and database.ResetSearchCache then
                database:ResetSearchCache()
            end
            NotifyProviderWaiters(provider, false)
            schedDone()
            return
        end
        provider.notReadyAt = nil
        FinishDynamicProvider(database, provider, ok, readyOrErr, true, finishWaiters)
    end, Pace, "provider " .. provider.key)
end




local function ensureJobsRegistered(database)
    local sched = getScheduler()
    if not sched then return nil end
    if database._dynamicJobsRegistered == sched then return sched end
    database._dynamicJobsRegistered = sched
    for i = 1, #dynamicProviders do
        local provider = dynamicProviders[i]
        sched:Register(jobIdForProvider(provider), {
            cancelGroup = "dynamic",
            run = function(_, done)
                runProviderJob(database, provider, done)
            end,
        })
    end
    return sched
end



function Database:AddDynamicProvider(provider)
    if dynamicProviderByKey[provider.key] then return end
    provider.loaded, provider.dirty = false, true
    dynamicProviders[#dynamicProviders + 1] = provider
    dynamicProviderByKey[provider.key] = provider
    if provider.category then providerByCategory[provider.category] = provider end
    local sched = getScheduler()
    if sched and self._dynamicJobsRegistered == sched then
        sched:Register(jobIdForProvider(provider), {
            cancelGroup = "dynamic",
            run = function(_, done) runProviderJob(self, provider, done) end,
        })
    end
end







local function IsProviderLoadDisabled(provider)
    local db = EasyFind and EasyFind.db
    local filters = db and db.uiSearchFilters
    if not filters then return false end
    local map = ns.CategoryMap
    if not (map and map.IsProviderFilterOff) then return false end
    return map.IsProviderFilterOff(filters, provider.key)
end

local function RunDynamicProvider(database, provider, onDone, runNow, bypassGate)
    if provider.loaded and not provider.dirty then onDone(false); return end
    if provider.notReadyAt and (GetTime() - provider.notReadyAt) < 3.0 then


        onDone(false)
        return
    end
    if not bypassGate and IsProviderLoadDisabled(provider) then



        onDone(false)
        return
    end



    provider.waiting = provider.waiting or {}
    provider.waiting[#provider.waiting + 1] = onDone

    local sched = ensureJobsRegistered(database)
    if not sched then


        runProviderJob(database, provider, function() end)
        return
    end
    local jobId = jobIdForProvider(provider)


    if sched:Status(jobId) == "complete" then
        sched:Reset(jobId)
    end
    sched:Enqueue(jobId)
    if runNow ~= false then




        local left = UrgentBudgetLeft()
        if left > 0 then
            local t0 = dps and dps() or 0
            sched:Step(0, left)
            if dps then AddUrgentSpend((dps() - t0) / 1000) end
        end
    end
end

function Database:CancelDynamicWarmup()
    if self.CancelDynamicScans then self:CancelDynamicScans(false) end
end

function Database:MarkDynamicProviderLoaded(key)
    local provider = dynamicProviderByKey[key]
    if not provider then return end
    provider.loading = false
    provider.loaded = true
    provider.dirty = false

    NotifyProviderWaiters(provider, true)
end

function Database:MarkDynamicCategoryDirty(key)
    local provider = dynamicProviderByKey[key]
    if not provider then return end
    provider.dirty = true
    provider.notReadyAt = nil
    if provider.loaded and self.ResetSearchCache then self:ResetSearchCache() end
end

function Database:IsDynamicProviderLoaded(key)
    local provider = dynamicProviderByKey[key]
    return provider and provider.loaded and not provider.dirty or false
end



function Database:IsDynamicProviderStale(key)
    local provider = dynamicProviderByKey[key]
    return provider and provider.loaded and provider.dirty and not provider.asyncFn or false
end








function Database:WasProviderRecentlyRun(key, windowSec)
    local provider = dynamicProviderByKey[key]
    if not (provider and provider.lastRunAt) then return false end
    return (GetTime() - provider.lastRunAt) < (windowSec or 2.0)
end



function Database:EnsureDynamicProviderLoaded(key, onDone)
    local provider = dynamicProviderByKey[key]
    if not provider then return false end
    if onDone then provider.urgent = true end
    RunDynamicProvider(self, provider, onDone or function() end, onDone ~= nil)
    return true
end

function Database:RequestDynamicProviderLoaded(key, onDone)
    local provider = dynamicProviderByKey[key]
    if not provider then return false end


    provider.urgent = true
    RunDynamicProvider(self, provider, onDone or function() end, false, true)
    return true
end




local function RefreshActiveSearch()
    local search = ns.Search
    if search and search.RefreshActiveSearch then
        search:RefreshActiveSearch(true)
    end
end

function Database:RefreshDynamicCategory(key, onDone)
    local provider = dynamicProviderByKey[key]
    if not provider then return false end
    provider.dirty = true
    local changed = false
    local returned = false
    RunDynamicProvider(self, provider, function(providerChanged)
        changed = providerChanged
        if onDone then onDone(providerChanged) end
        if returned and providerChanged then RefreshActiveSearch() end
    end)
    returned = true
    return changed
end



function Database:RefreshStaleProvider(key)
    local provider = dynamicProviderByKey[key]
    if not provider then return false end
    local queue = self._staleQueue or {}
    self._staleQueue = queue
    if queue[key] then return true end
    queue[key] = true
    queue[#queue + 1] = provider
    if self:IsRefreshingStale() then return true end

    local run = {}
    self._staleRun = run
    local function step()
        if self._staleRun ~= run then return end
        self._staleStepAt = GetTime()
        local search = ns.Search
        if search and search.IsSearchRunning and search:IsSearchRunning() then
            Utils.SafeAfter(0, step)
            return
        end
        local nextUp = table.remove(queue, 1)
        while nextUp and not (nextUp.loaded and nextUp.dirty and not nextUp.asyncFn) do
            queue[nextUp.key] = nil
            nextUp = table.remove(queue, 1)
        end
        if nextUp then
            queue[nextUp.key] = nil
            RunDynamicProvider(self, nextUp, function() Utils.SafeAfter(0, step) end, false)
            return
        end
        self._staleRun = nil
        if self._staleChanged then
            self._staleChanged = nil
            RefreshActiveSearch()
        end
    end
    self._staleStepAt = GetTime()
    Utils.SafeAfter(0, step)
    return true
end


function Database:IsRefreshingStale()
    return self._staleRun ~= nil and GetTime() - (self._staleStepAt or 0) < 2
end






function Database:LoadEagerDynamicProviders()
    if self._loadingEagerProviders then return end
    self._loadingEagerProviders = true
    local index = 1
    local function step()
        while index <= #dynamicProviders do
            local provider = dynamicProviders[index]
            index = index + 1
            if provider.eager and not (provider.loaded and not provider.dirty) then
                RunDynamicProvider(self, provider, function()


                    local function indexSlice()
                        if ns.SearchIndex and ns.SearchIndex.EnsureBudget
                           and not ns.SearchIndex:EnsureBudget(3) then
                            Utils.SafeAfter(0, indexSlice)
                            return
                        end
                        Utils.SafeAfter(0, step)
                    end
                    indexSlice()
                end, false)
                return
            end
        end
        self._loadingEagerProviders = false


        RefreshActiveSearch()
        if ns.SearchIndex and ns.SearchIndex.EnsureBudget then
            ns.SearchIndex:EnsureBudget(3)
        end
    end


    Utils.SafeAfter(0, step)
end





function Database:IsWarmingProviders()
    return (self._dynamicBatchLoading or self._loadingEagerProviders) and true or false
end

function Database:LoadDeferredSyncProvidersStaggered()


    self._dynamicBatchLoading = true
    self._dynamicBatchChanged = false
    local index = 1
    local function step()
        while index <= #dynamicProviders do
            local provider = dynamicProviders[index]
            index = index + 1

            if not provider.asyncFn and not provider.lazy
               and not (provider.loaded and not provider.dirty) then
                RunDynamicProvider(self, provider, function()


                    local function indexSlice()
                        if ns.SearchIndex and ns.SearchIndex.EnsureBudget
                           and not ns.SearchIndex:EnsureBudget(3) then
                            Utils.SafeAfter(0, indexSlice)
                            return
                        end
                        Utils.SafeAfter(0, step)
                    end
                    indexSlice()
                end, false)
                return
            end
        end
        local changed = self._dynamicBatchChanged
        self._dynamicBatchLoading = false
        self._dynamicBatchChanged = false
        if changed and self.ResetSearchCache then self:ResetSearchCache() end
        if self.WarmSearchHotPath then self:WarmSearchHotPath() end

        self:EnsureDynamicProviderLoaded("mounts")
        self:EnsureDynamicProviderLoaded("housing")

        if ns.Shortkeys and ns.Shortkeys.ApplyAll then ns.Shortkeys:ApplyAll() end
    end
    step()
end


function Database:LoadHeavyDynamicSearchData(onDone)
    if self._loadingHeavyDynamic then return false end
    self._loadingHeavyDynamic = true

    local index = 1
    local anyChanged = false
    local function step()
        while index <= #dynamicProviders do
            local provider = dynamicProviders[index]
            index = index + 1
            if provider.asyncFn then
                RunDynamicProvider(self, provider, function(changed)
                    if changed then anyChanged = true end
                    Utils.SafeAfter(0.05, step)
                end)
                return
            end
        end
        self._loadingHeavyDynamic = false
        if onDone then onDone(anyChanged) end
    end

    step()
    return true
end

function Database:UnloadDynamicSearchData(includeCore)
    if self.CancelDynamicScans then self:CancelDynamicScans(true) end
    for i = 1, #dynamicProviders do
        local provider = dynamicProviders[i]





        if includeCore or (provider.asyncFn and not provider.keepOnTrim) then
            if provider.category then self:_RemoveEntriesByCategory(provider.category) end
            provider.loaded = false
            provider.dirty = true
        end
    end
    if includeCore then
        self:_ResetDynamicProviderCaches()
    elseif self._ResetHeavyProviderCaches then
        self:_ResetHeavyProviderCaches()
    end
    if self.ResetSearchCache then self:ResetSearchCache() end
end




function Database:_DebugPeekProviders()
    return dynamicProviders
end
