local _, ns = ...

local MapSearch = {}
ns.MapSearch = MapSearch

local Utils     = ns.Utils
local pairs, ipairs, type = Utils.pairs, Utils.ipairs, Utils.type
local tinsert, tremove = Utils.tinsert, Utils.tremove
local sfind = Utils.sfind
local MapSearchData = ns.MapSearchData
local CATEGORY_ICONS = MapSearchData.CATEGORY_ICONS
local CATEGORIES = MapSearchData.CATEGORIES



local function GetMapPinKey(data)
    if data.isZone and data.zoneMapID then
        return "zone:" .. data.zoneMapID
    end
    return (data.category or "unknown") .. ":" .. (data.name or "") .. ":" .. (data.mapID or "")
end

local function CleanForStorage(data)
    local clean = {}
    for k, v in pairs(data) do
        local t = type(v)
        if t == "string" or t == "number" or t == "boolean" then
            clean[k] = v
        end
    end
    return clean
end

local function IsMapItemPinned(data)
    local key = GetMapPinKey(data)
    for _, pin in ipairs(EasyFind.db.pinnedMapItems) do
        if GetMapPinKey(pin) == key then return true end
    end
    return false
end

local function PinMapItem(data)
    if IsMapItemPinned(data) then return end
    local clean = CleanForStorage(data)
    clean.isPinned = true


    if data.isZone and data.zoneMapID and clean.collapsed == nil then
        clean.collapsed = true
    end
    tinsert(EasyFind.db.pinnedMapItems, clean)
end

local function UnpinMapItem(data)
    local key = GetMapPinKey(data)
    local items = EasyFind.db.pinnedMapItems
    for i = #items, 1, -1 do
        if GetMapPinKey(items[i]) == key then
            tremove(items, i)
            return
        end
    end
end

MapSearch.GetMapPinKey  = function(_, data) return GetMapPinKey(data) end
MapSearch.IsMapItemPinned = function(_, data) return IsMapItemPinned(data) end
MapSearch.PinMapItem   = function(_, data) return PinMapItem(data) end
MapSearch.UnpinMapItem = function(_, data) return UnpinMapItem(data) end

local function GetCategoryIcon(category)
    local icon = CATEGORY_ICONS[category]
    if icon then return icon end

    local p = ns.Extensions and ns.Extensions.Providers and ns.Extensions.Providers.byCategory[category]
    return p and p.icon or CATEGORY_ICONS.unknown
end



local function GuideAllowed(data)
    return not (data.providerRow or data.placeOf or data.npcID or data.category == "npc")
end

ns.MapSearch = ns.MapSearch or MapSearch
ns.MapSearch.GetCategoryIcon = GetCategoryIcon
ns.MapSearch.GuideAllowed = GuideAllowed

local function GetFilterBucket(data)
    if not data then return "other" end

    local cat = data.category
    if cat == "dungeon" or cat == "raid" or cat == "delve" then return "instances" end
    if data.isZone then return "zones" end
    if not cat then return "other" end
    if cat == "rare" then return "rares" end
    if cat == "npc" then return "npcs" end
    local parent = CATEGORIES[cat] and CATEGORIES[cat].parent
    if parent == "instance" then return "instances" end
    if parent == "travel" then return "travel" end
    if parent == "service" or cat == "service" then return "services" end

    if sfind(cat, "^classtrainer_") or sfind(cat, "^prof_") then return "services" end
    if cat == "guildbank" or cat == "guildservices" or cat == "trainingdummy" then return "services" end

    local ext = ns.Extensions
    if ext and ext.Providers and ext.Providers.byCategory[cat] then return cat end
    return "other"
end
ns.MapSearch.GetFilterBucket = GetFilterBucket





local SUBBUCKET = {
    raid = "raid", dungeon = "dungeon", delve = "delve",
    flightmaster = "flights", boat = "boats", zeppelin = "boats",
    portal = "portals", tram = "portals",
    bank = "banks", guildbank = "banks",
    auctionhouse = "auction",
    innkeeper = "inns",
    mailbox = "mail",
    trainer = "trainers",
    vendor = "vendors", pvpvendor = "vendors", quartermaster = "vendors",
    repairvendor = "vendors", upgradevendor = "vendors",
    tradingpost = "vendors", decor = "vendors",
    transmogrifier = "appearance", barber = "appearance",
}
ns.MapSearch.SUBBUCKET = SUBBUCKET



local function GetSubBucket(data, bucket)
    local cat = data and data.category
    if not cat then return nil end
    local sub = SUBBUCKET[cat]
    if sub then return sub end
    if not bucket then bucket = GetFilterBucket(data) end
    if bucket == "services" then
        if sfind(cat, "^classtrainer_") or sfind(cat, "^prof_") then return "trainers" end
        return "otherservices"
    end
    return nil
end
ns.MapSearch.GetSubBucket = GetSubBucket



local function PassesFilter(data, filters)
    if not filters then return true end
    local bucket = GetFilterBucket(data)
    if filters[bucket] == false then return false end
    local sub = GetSubBucket(data, bucket)
    if sub and filters[sub] == false then return false end
    return true
end
ns.MapSearch.PassesFilter = PassesFilter




local function ZoneOnly(data)
    local only = EasyFind.db and EasyFind.db.mapZoneOnly
    if not only then return false end
    local bucket = GetFilterBucket(data)
    if bucket == "zones" then return false end
    if only.all == true or only[bucket] == true then return true end
    local sub = GetSubBucket(data, bucket)
    return sub ~= nil and only[sub] == true
end
ns.MapSearch.ZoneOnly = ZoneOnly

local scopeProbe = {}
function ns.MapSearch.ZoneOnlyForCategory(category)
    scopeProbe.category = category
    return ZoneOnly(scopeProbe)
end

function MapSearch:Initialize()
    self:CreateHighlightFrame()
    self:CreateZoneHighlightFrame()
    self:HookWorldMap()
    if Utils.SafeAfter then
        Utils.SafeAfter(0.8, function()
            if MapSearch.WarmUISearchCaches then MapSearch:WarmUISearchCaches() end
        end)
    end
end

