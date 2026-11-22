local _, ns = ...

local UIPins = {}
ns.UIPins = UIPins

local Utils = ns.Utils
local ipairs, pairs, type = Utils.ipairs, Utils.pairs, Utils.type
local tconcat, tinsert, tremove, ssub = Utils.tconcat, Utils.tinsert, Utils.tremove, Utils.ssub

local charKey

local SIMPLE_FIELDS = {
    "name", "nameLower", "category", "buttonFrame", "icon",
    "specificIcon", "specificIconFrame",
    "mountID", "spellID", "isSpellbookOnly", "toyItemID", "petID", "speciesID", "outfitID", "heirloomItemID",



    "isCollected", "isUsable", "shouldHideOnChar", "isToyboxOnly",
    "macroIndex", "macroIsChar", "bagID", "bagSlot", "bagItemLink",
    "itemID", "encounterID", "instanceID", "lootSlotName", "lootSourceName", "lootInstanceName", "lootSourceType",




    "catalogItem", "lookupRow", "quality",


    "extensionID",
    "calculatorLauncher", "iconSearchLauncher", "snippetsLauncher", "clipboardLauncher", "notesLauncher",
    "quicklistsLauncher", "gpsLauncher", "chatLauncher",
    "noteID", "quicklistID",
    "transmogSetID",


    "titleID", "gearSetID", "talentNodeID", "skillLine",

    "talentTab", "talentIndex", "talentID", "talentGroup", "talentTier", "talentColumn",
    "appearanceItemID", "appearanceVisualID", "appearanceSlot",
    "factionID", "hasRepBar", "canQueue", "isPvP", "isPvE",


    "mapSearchResult", "isZone", "mapID", "zoneName", "pathPrefix",
    "zoneMapType", "zoneParentMapID",


    "x", "y", "zoneMapID", "coordMapID", "parentMapID",
    "entranceMapID", "entranceX", "entranceY", "entranceIcon",
    "entranceCategory", "isDungeonEntrance",
    "achievementID",



    "housingRecordID",


    "searchCommand", "searchCommandDesc", "slashCommand", "isNativeCommand",




    "settingVariable", "settingType", "cbVariable", "sliderVariable",
    "dropdownVariable", "settingMin", "settingMax", "quickKeybindActivate",


    "bindingAction", "customToggle",

    "specSetIndex", "loadoutConfigID",




    "spellName", "professionSkillLine", "professionName", "professionOpenID", "professionRecipeID",
}

local TABLE_FIELDS = {
    "path", "steps", "keywords", "keywordsLower", "lootItemLinks",
}

function UIPins.GetKey(data)
    if not data or not data.name then return "" end






    if data.catalogItem and data.itemID and ns.Aliases and ns.Aliases.GetEntryKey then
        local entryKey = ns.Aliases:GetEntryKey(data)
        if entryKey then return entryKey end
    end
    return data.name .. "|" .. tconcat(data.path or {}, ">")
end

local function CleanForStorage(data)
    local clean = {}
    for i = 1, #SIMPLE_FIELDS do
        local key = SIMPLE_FIELDS[i]
        local value = data[key]
        if value ~= nil then clean[key] = value end
    end
    for i = 1, #TABLE_FIELDS do
        local key = TABLE_FIELDS[i]
        local value = data[key]
        if value then
            local copy = {}
            for k, v in pairs(value) do
                if type(v) == "table" then
                    local sub = {}
                    for sk, sv in pairs(v) do sub[sk] = sv end
                    copy[k] = sub
                else
                    copy[k] = v
                end
            end
            clean[key] = copy
        end
    end

    local Extensions = ns.Extensions
    if Extensions and Extensions.ProviderOf and Extensions.ProviderOf(data) then
        for key, value in pairs(data) do
            local kind = type(value)
            if clean[key] == nil and (kind == "string" or kind == "number" or kind == "boolean")
                and not (type(key) == "string" and ssub(key, 1, 1) == "_") then
                clean[key] = value
            end
        end
    end
    return clean
end


UIPins.CleanForStorage = CleanForStorage

function UIPins.IsCollection(data)
    return data and (data.mountID or data.toyItemID or data.petID or data.outfitID
        or data.heirloomItemID
        or (data.itemID and data.category == "Loot"))
end

function UIPins.GetCharKey()
    if not charKey then
        charKey = ns.PlayerName() and ns.CurrentCharacterKey() or "Unknown"
    end
    return charKey
end

local function GetPinList(data)
    local db = EasyFind and EasyFind.db
    if not db then return nil end
    if UIPins.IsCollection(data) then
        local key = UIPins.GetCharKey()
        db.pinnedUIItemsPerChar = db.pinnedUIItemsPerChar or {}
        db.pinnedUIItemsPerChar[key] = db.pinnedUIItemsPerChar[key] or {}
        return db.pinnedUIItemsPerChar[key]
    end
    db.pinnedUIItems = db.pinnedUIItems or {}
    return db.pinnedUIItems
end

function UIPins.GetAll()
    local db = EasyFind and EasyFind.db
    local all = {}
    if not db then return all end
    for _, pin in ipairs(db.pinnedUIItems or {}) do
        all[#all + 1] = pin
    end
    local charPins = db.pinnedUIItemsPerChar and db.pinnedUIItemsPerChar[UIPins.GetCharKey()]
    if charPins then
        for _, pin in ipairs(charPins) do
            all[#all + 1] = pin
        end
    end
    return all
end

function UIPins.IsPinned(data)
    local db = EasyFind and EasyFind.db
    if not db then return false end
    local key = UIPins.GetKey(data)
    for _, pin in ipairs(db.pinnedUIItems or {}) do
        if UIPins.GetKey(pin) == key then return true end
    end
    if UIPins.IsCollection(data) then
        local charPins = db.pinnedUIItemsPerChar and db.pinnedUIItemsPerChar[UIPins.GetCharKey()]
        if charPins then
            for _, pin in ipairs(charPins) do
                if UIPins.GetKey(pin) == key then return true end
            end
        end
    end
    return false
end

function UIPins.Pin(data)
    local list = GetPinList(data)
    if not list then return end
    local clean = CleanForStorage(data)
    clean.isPinned = true
    local key = UIPins.GetKey(data)
    for i, existing in ipairs(list) do
        if UIPins.GetKey(existing) == key then
            list[i] = clean
            return
        end
    end
    tinsert(list, clean)
end




local refreshedFrom = setmetatable({}, { __mode = "k" })
function UIPins.LiveRow(pin)
    local Aliases = ns.Aliases
    local live = Aliases and Aliases.LiveEntryByKey and Aliases:LiveEntryByKey(Aliases:GetEntryKey(pin))
    if not live then return pin end
    if not refreshedFrom[live] then
        refreshedFrom[live] = true
        UIPins.Pin(live)
    end
    return live
end

function UIPins.Unpin(data)
    local db = EasyFind and EasyFind.db
    if not db then return end
    local key = UIPins.GetKey(data)
    local items = db.pinnedUIItems or {}
    for i = #items, 1, -1 do
        if UIPins.GetKey(items[i]) == key then
            tremove(items, i)
            return
        end
    end
    if UIPins.IsCollection(data) then
        local charPins = db.pinnedUIItemsPerChar and db.pinnedUIItemsPerChar[UIPins.GetCharKey()]
        if charPins then
            for i = #charPins, 1, -1 do
                if UIPins.GetKey(charPins[i]) == key then
                    tremove(charPins, i)
                    return
                end
            end
        end
    end
end

function UIPins.SyncOutfits()
    local db = EasyFind and EasyFind.db
    if not db or not C_TransmogOutfitInfo or not C_TransmogOutfitInfo.GetOutfitsInfo then return end
    local outfits = C_TransmogOutfitInfo.GetOutfitsInfo()
    if not outfits then return end

    local lookup = {}
    for index, info in ipairs(outfits) do
        lookup[info.outfitID] = { info = info, index = index }
    end

    local function syncList(pins)
        if not pins then return end
        for i = #pins, 1, -1 do
            local pin = pins[i]
            if pin.outfitID then
                local outfit = lookup[pin.outfitID]
                if outfit then
                    local info = outfit.info
                    pin.name = info.name
                    pin.nameLower = info.name:lower()
                    pin.icon = info.icon
                    pin.outfitIndex = outfit.index
                else
                    tremove(pins, i)
                end
            end
        end
    end

    syncList(db.pinnedUIItems)
    local charPins = db.pinnedUIItemsPerChar and db.pinnedUIItemsPerChar[UIPins.GetCharKey()]
    syncList(charPins)
end
