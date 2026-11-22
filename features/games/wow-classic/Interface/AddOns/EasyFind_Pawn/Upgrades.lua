-- Pawn's verdicts on EasyFind's rows: a drop EasyFind lists (its loot
-- rows, @upgrades, a bag item) says how much better Pawn rates it and for
-- which scale, with Pawn's compare on its menu; @upgrades is judged by
-- Pawn. Pawn is only read: its functions are called at runtime, its
-- scales and settings never written or copied.
local _, ns = ...
local API = EasyFind and EasyFind.API
if not (API and API.VERSION == 1) then return end
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
if not (IsAddOnLoaded and IsAddOnLoaded("Pawn")) then return end

local L = ns.L
local KEY = "pawn"
local ICON = "Interface\\AddOns\\EasyFind_Pawn\\upgrade"
local RATE_BUDGET_MS = 4     -- rating time per frame
local REFRESH_DELAY = 1      -- seconds after a gear or scale change
local FIRST_LOAD_DELAY = 10  -- seconds after entering the world
local BIG_UPGRADE = 100      -- Pawn's "no number" percent (an empty slot)

local C_Item = C_Item
local sformat, floor, debugprofilestop = string.format, math.floor, debugprofilestop

-- Module state in one table (upvalue limit). A drop is rated when a shown
-- row or @upgrades asks for it, again after the gear, spec or scales change.
local S = {
    ready = false,
    byItem = {},    -- itemID -> loot entry from EasyFind
    verdict = {},   -- itemID -> upgrade table, false when rated no upgrade
    ratedGen = {},  -- itemID -> gen its verdict was rated in
    gen = 1,        -- bumped when the gear, spec, scales or loot change
    queue = {}, head = 1,
    queued = {},
    pending = {},   -- itemID -> "gear" or "drop", item data asked of the server
    judged = {},    -- itemID -> true, asked for by @upgrades
    settled = false,
    upgradesDirty = false,
    inPawn = false, -- inside a Pawn call: its hooks are not our signal
}

local function Print(text)
    print(sformat("|cff66ccff%s:|r %s", L["EXT_NAME"], text))
end

-- ==== Pawn ==================================================================

-- The functions of Pawn's own API section that the rating needs.
local function BindPawn()
    local need = { "PawnIsReady", "PawnGetItemData", "PawnIsItemAnUpgrade" }
    for i = 1, #need do
        if type(_G[need[i]]) ~= "function" then return false end
    end
    return true
end

local function BindLoot()
    return API.HasAction("loot", "ensure") and API.HasAction("loot", "entries") and API.HasAction("loot", "link")
end

-- Pawn's upgrade list, sorted by scale name; the mark shows the biggest.
local function Verdict(info, link)
    if type(info) ~= "table" or not info[1] then return false end
    local best = info[1]
    for i = 2, #info do
        if (info[i].PercentUpgrade or 0) > (best.PercentUpgrade or 0) then best = info[i] end
    end
    local others = {}
    for i = 1, #info do
        if info[i] ~= best then others[#others + 1] = info[i] end
    end
    return { pct = best.PercentUpgrade or 0, scaleName = best.LocalizedScaleName or best.ScaleName,
             existing = best.ExistingItemLink, others = others, link = link }
end

local function AskPawn(link)
    S.inPawn = true
    local item = PawnGetItemData(link)
    local info = item and PawnIsItemAnUpgrade(item)
    S.inPawn = false
    return info
end

-- ==== rating ================================================================

local loader = CreateFrame("Frame")
local rater = CreateFrame("Frame")
rater:Hide()
local Publish

local function Cached(itemID)
    return not C_Item.IsItemDataCachedByID or C_Item.IsItemDataCachedByID(itemID)
end

local function RequestItem(itemID, kind)
    S.pending[itemID] = kind
    if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    loader:RegisterEvent("ITEM_DATA_LOAD_RESULT")
end

-- Pawn compares against the worn gear, so that must be known first.
local function GearCached()
    local ok = true
    for slot = 1, 17 do
        local id = GetInventoryItemID("player", slot)
        if id and not Cached(id) then
            RequestItem(id, "gear")
            ok = false
        end
    end
    return ok
end

local function Settle(itemID, verdict)
    S.verdict[itemID] = verdict
    S.ratedGen[itemID] = S.gen
    S.settled = true
    if S.judged[itemID] then S.upgradesDirty = true end
end

-- Something worn: any item with a gear slot, read with no wait on the cache.
local function Wearable(itemID)
    local equipLoc = select(4, C_Item.GetItemInfoInstant(itemID))
    return equipLoc ~= nil and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
end

-- A boss drop by EasyFind's loot link, any other gear by its own.
local function Rate(itemID)
    if not Cached(itemID) then return RequestItem(itemID, "drop") end
    local link = S.byItem[itemID] and API.CallAction("loot", "link", itemID) or select(2, C_Item.GetItemInfo(itemID))
    if not link then return Settle(itemID, false) end
    Settle(itemID, Verdict(AskPawn(link), link))
end

-- A drop asked for: rated unless its verdict is of this gen; the old
-- verdict shows meanwhile.
local function Want(itemID)
    if S.ratedGen[itemID] == S.gen or S.pending[itemID] then return end
    if not S.queued[itemID] then
        S.queued[itemID] = true
        S.queue[#S.queue + 1] = itemID
    end
    rater:Show()
end

rater:SetScript("OnUpdate", function(self)
    if not (PawnIsReady() and GearCached()) then return self:Hide() end
    local stop = debugprofilestop() + RATE_BUDGET_MS
    while S.head <= #S.queue do
        local itemID = S.queue[S.head]
        S.head = S.head + 1
        S.queued[itemID] = nil
        Rate(itemID)
        if debugprofilestop() > stop then return end
    end
    self:Hide()
    S.queue, S.head = {}, 1
    if S.settled then
        S.settled = false
        Publish()
    end
end)

-- Items the server sent: a drop asked for again, worn gear lets the queue run.
loader:SetScript("OnEvent", function(self, _, itemID, ok)
    local kind = S.pending[itemID]
    if not kind then return end
    S.pending[itemID] = nil
    if next(S.pending) == nil then self:UnregisterEvent("ITEM_DATA_LOAD_RESULT") end
    if kind == "gear" then
        if S.head <= #S.queue then rater:Show() end
    elseif ok and (S.byItem[itemID] or Wearable(itemID)) then
        Want(itemID)
    else
        Settle(itemID, false)
    end
end)

-- Every verdict stale: shown rows and @upgrades ask again.
local function Stale()
    S.gen = S.gen + 1
    if next(S.judged) then S.upgradesDirty = true end
    Publish()
end

-- EasyFind's loot changed: new entry list, every verdict stale.
local function Reload()
    if not S.ready then return end
    local list = API.CallAction("loot", "entries")
    if type(list) ~= "table" then return end
    S.byItem = {}
    for i = 1, #list do
        local e = list[i]
        if e.itemID then S.byItem[e.itemID] = e end
    end
    for itemID in pairs(S.verdict) do
        if not (S.byItem[itemID] or Wearable(itemID)) then S.verdict[itemID], S.ratedGen[itemID] = nil, nil end
    end
    Stale()
end

local refreshPending = false
local function Refresh()
    if refreshPending or not S.ready or S.inPawn then return end
    refreshPending = true
    C_Timer.After(REFRESH_DELAY, function()
        refreshPending = false
        Stale()
    end)
end

-- Any gear on a row, a boss drop or not, rated on first sight.
local function Asked(itemID)
    if not (S.ready and itemID and (S.byItem[itemID] or Wearable(itemID))) then return false end
    Want(itemID)
    return true
end

-- ==== EasyFind's rows =======================================================

local function Percent(pct)
    return floor(pct * 100 + 0.5)
end

-- Rows paint again; @upgrades is built again only when its drops changed.
local publishPending = false
function Publish()
    if publishPending then return end
    publishPending = true
    C_Timer.After(0, function()
        publishPending = false
        local upgrades = S.upgradesDirty
        S.upgradesDirty = false
        if upgrades and API.RefreshUpgrades then API.RefreshUpgrades() end
        if API.RefreshRowDecorations then API.RefreshRowDecorations() end
    end)
end

-- After the row's subtext: the percent and the scale; on @upgrades, whose
-- rows show the percent already, the scale alone.
local function Mark(row)
    local v = S.verdict[row.itemID]
    if v.pct >= BIG_UPGRADE then return sformat(L["MARK_BIG_FMT"], v.scaleName) end
    if row.upgradeSlot then return v.scaleName end
    return sformat(L["MARK_FMT"], Percent(v.pct), v.scaleName)
end

-- Under the row's tooltip: what the drop replaces, the other scales it helps.
local function Lines(row, _, tt)
    local v = S.verdict[row.itemID]
    if v.existing then tt:AddLine(sformat(L["REPLACES_FMT"], v.existing), 1, 1, 1) end
    for i = 1, #v.others do
        local o = v.others[i]
        if (o.PercentUpgrade or 0) < BIG_UPGRADE then
            tt:AddLine(sformat(L["ALSO_FMT"], Percent(o.PercentUpgrade or 0), o.LocalizedScaleName or o.ScaleName or ""),
                0.8, 0.8, 0.8)
        end
    end
end

local function Menu(row)
    local v = S.verdict[row.itemID]
    local link = v and v.link
    if not link then return nil end
    local rows = {}
    if type(PawnUI_SetCompareItemAndShow) == "function" then
        rows[#rows + 1] = { kind = "action", label = L["MENU_COMPARE"],
                            onClick = function() PawnUI_SetCompareItemAndShow(2, link) end }
    end
    if type(PawnUIShow) == "function" then
        rows[#rows + 1] = { kind = "action", label = L["MENU_PAWN"], onClick = PawnUIShow }
    end
    return rows
end

-- Pawn's word for @upgrades: the percent, true with no number, false for
-- no upgrade, nil while unrated (EasyFind's own comparison stands).
local function Judge(itemID)
    if not Asked(itemID) then return nil end
    S.judged[itemID] = true
    local v = S.verdict[itemID]
    if v == nil then return nil end
    if v == false then return false end
    if v.pct >= BIG_UPGRADE then return true end
    return Percent(v.pct)
end

-- ==== registration ==========================================================

API.RegisterExtension({
    id = KEY,
    name = L["EXT_NAME"],
    description = L["EXT_DESC"],
    icon = ICON,
    -- The tile opens @upgrades, judged by Pawn.
    scope = "upgrades",
})

if API.RegisterRowDecorator then
    API.RegisterRowDecorator({
        id = KEY, label = L["EXT_NAME"],
        applies = function(row) return Asked(row.itemID) and S.verdict[row.itemID] and true or false end,
        subtext = Mark,
        tooltip = Lines,
        menu = Menu,
    })
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if not BindPawn() then return Print(L["NOT_READY"]) end
        if not BindLoot() then return Print(L["NEED_EASYFIND"]) end
        S.ready = true
        self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        -- Pawn has no change event: a scale edited, shown or hidden ends in
        -- one of these two calls, as does its own spec switch.
        hooksecurefunc("PawnInvalidateBestItems", Refresh)
        hooksecurefunc("PawnResetTooltips", Refresh)
        if API.RegisterUpgradeJudge then API.RegisterUpgradeJudge({ extension = KEY, rate = Judge }) end
        API.On("loot", "changed", Reload)
        -- The loot list loads after the login settles, not during it.
        C_Timer.After(FIRST_LOAD_DELAY, function() API.CallAction("loot", "ensure", Reload) end)
        return
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
    Refresh()
end)
