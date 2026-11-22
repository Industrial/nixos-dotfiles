local _, ns = ...






local Upgrades = {}
ns.Upgrades = Upgrades

local Utils = ns.Utils
local L = ns.L
local sformat, tconcat = Utils.sformat, Utils.tconcat
local pairs, ipairs = Utils.pairs, Utils.ipairs
local tsort = Utils.tsort
local mfloor = math.floor
local bband = bit.band
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemNameByID = C_Item and C_Item.GetItemNameByID
local GetItemIconByID = C_Item and C_Item.GetItemIconByID


local STR, AGI, INT, SPI, SPELL, PHYS, TANK = 1, 2, 4, 8, 16, 32, 64
local WANTS = {
    WARRIOR = STR + AGI + PHYS + TANK,
    PALADIN = STR + INT + SPI + SPELL + PHYS + TANK,
    HUNTER = AGI + INT + PHYS,
    ROGUE = STR + AGI + PHYS,
    PRIEST = INT + SPI + SPELL,
    SHAMAN = STR + AGI + INT + SPI + SPELL + PHYS,
    MAGE = INT + SPI + SPELL,
    WARLOCK = INT + SPI + SPELL,
    DRUID = STR + AGI + INT + SPI + SPELL + PHYS + TANK,
}

local ARMOR, ARMOR_LEVEL = 4, 40
local BEST_ARMOR = {
    WARRIOR = { 3, 4 }, PALADIN = { 3, 4 }, HUNTER = { 2, 3 }, SHAMAN = { 2, 3 },
    ROGUE = { 2, 2 }, DRUID = { 2, 2 }, PRIEST = { 1, 1 }, MAGE = { 1, 1 }, WARLOCK = { 1, 1 },
}

local DUAL_WIELD = { WARRIOR = 20, HUNTER = 20, ROGUE = 1 }
local WEAPON, WAND, RELIC_INV = 2, 19, 28
local ARMOR_INV = { [1] = true, [3] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true,
                    [20] = true }
local ONE_HAND = { [13] = true, [21] = true }
local OFF_HAND_WEAPON = { [13] = true, [22] = true }
local TWO_HAND = 17
local SHIELD, HOLDABLE, CLOAK = 14, 23, 16



local SLOTS = {
    { slots = { 1 }, inv = { [1] = true }, label = "HEADSLOT" },
    { slots = { 2 }, inv = { [2] = true }, label = "NECKSLOT" },
    { slots = { 3 }, inv = { [3] = true }, label = "SHOULDERSLOT" },
    { slots = { 15 }, inv = { [16] = true }, label = "BACKSLOT" },
    { slots = { 5 }, inv = { [5] = true, [20] = true }, label = "CHESTSLOT" },
    { slots = { 9 }, inv = { [9] = true }, label = "WRISTSLOT" },
    { slots = { 10 }, inv = { [10] = true }, label = "HANDSSLOT" },
    { slots = { 6 }, inv = { [6] = true }, label = "WAISTSLOT" },
    { slots = { 7 }, inv = { [7] = true }, label = "LEGSSLOT" },
    { slots = { 8 }, inv = { [8] = true }, label = "FEETSLOT" },
    { slots = { 11, 12 }, inv = { [11] = true }, label = "INVTYPE_FINGER" },
    { slots = { 13, 14 }, inv = { [12] = true }, label = "INVTYPE_TRINKET" },
    { slots = { 16 }, inv = { [13] = true, [17] = true, [21] = true }, label = "MAINHANDSLOT", hand = "main" },
    { slots = { 17 }, inv = { [13] = true, [14] = true, [22] = true, [23] = true }, label = "SECONDARYHANDSLOT", hand = "off" },
    { slots = { 18 }, inv = { [15] = true, [25] = true, [26] = true, [28] = true }, label = "RANGEDSLOT", hand = "ranged" },
}
local INV_TOKEN = {
    [1] = "INVTYPE_HEAD", [2] = "INVTYPE_NECK", [3] = "INVTYPE_SHOULDER", [5] = "INVTYPE_CHEST",
    [6] = "INVTYPE_WAIST", [7] = "INVTYPE_LEGS", [8] = "INVTYPE_FEET", [9] = "INVTYPE_WRIST", [10] = "INVTYPE_HAND",
    [11] = "INVTYPE_FINGER", [12] = "INVTYPE_TRINKET", [13] = "INVTYPE_WEAPON", [14] = "INVTYPE_SHIELD",
    [15] = "INVTYPE_RANGED", [16] = "INVTYPE_CLOAK", [17] = "INVTYPE_2HWEAPON", [20] = "INVTYPE_ROBE",
    [21] = "INVTYPE_WEAPONMAINHAND", [22] = "INVTYPE_WEAPONOFFHAND", [23] = "INVTYPE_HOLDABLE",
    [25] = "INVTYPE_THROWN", [26] = "INVTYPE_RANGEDRIGHT", [28] = "INVTYPE_RELIC",
}
local INV_OF = {}
for id, name in pairs(INV_TOKEN) do INV_OF[name] = id end

local DUNGEON_ROWS, RAID_ROWS, NARROWED_ROWS = 4, 2, 10

local MIN_ITEM_LEVEL = 5
local EMPTY = {}

local REQ_GAP = 5


local function JudgeOf(entry)
    local judge = entry.isCurrent and ns.Extensions and ns.Extensions.Judge
    return judge and judge.def and judge.Rate or nil
end



local function Gear(itemID)
    local v = ns.STATIC_LOOT_GEAR and ns.STATIC_LOOT_GEAR[itemID]
    if not v then return nil end
    return v % 256, mfloor(v / 256) % 128, mfloor(v / 32768) % 128, mfloor(v / 4194304) % 32,
        mfloor(v / 4294967296) % 8, mfloor(v / 134217728) % 32, mfloor(v / 34359738368) % 8
end
Upgrades.Gear = Gear


local function Worn(entry, slot)
    local link, level
    if entry.isCurrent and GetInventoryItemLink then
        link = GetInventoryItemLink("player", slot)
        level = link and ns.CharacterData.ItemLevel(link)
    else
        link = entry.gear and entry.gear[slot]
        level = link and (ns.CharacterData.ItemLevel(link) or (entry.gearLevel and entry.gearLevel[slot]))
    end
    if not link then return nil end
    local itemID = tonumber(link:match("item:(%d+)"))
    local ilvl, _, _, inv, cls, sub = Gear(itemID)
    local _, _, _, equipLoc, _, classID, subclassID = GetItemInfoInstant(link)
    return { link = link, itemID = itemID, level = level or ilvl or 0,
             inv = INV_OF[equipLoc] or inv, cls = classID or cls, sub = subclassID or sub,
             name = (link:match("%[(.-)%]")) or (GetItemNameByID and GetItemNameByID(itemID)) or "?" }
end


local function Fits(entry, slotDef, worn, inv, cls, sub, itemID, mainHand)
    local class, level = entry.class, entry.level
    local mask = ns.STATIC_LOOT_CLASSES and ns.STATIC_LOOT_CLASSES[itemID]
    local classID = ns.Database.CLASS_ID and ns.Database.CLASS_ID[class]
    if mask and classID and bband(mask, 2 ^ (classID - 1)) == 0 then return false end

    if inv ~= CLOAK and not ns.Database.ClassUsesSubclass(class, cls, sub) then return false end
    if cls == ARMOR and ARMOR_INV[inv] then
        local best = BEST_ARMOR[class]
        if best and sub >= 1 and sub <= 4 and sub ~= best[level >= ARMOR_LEVEL and 2 or 1] then return false end
    end
    local hand = slotDef.hand
    if hand == "main" then

        if worn and worn.inv == TWO_HAND then return inv == TWO_HAND end
        if worn and ONE_HAND[worn.inv] then return ONE_HAND[inv] or false end
        return inv ~= 22
    elseif hand == "off" then

        if mainHand and mainHand.inv == TWO_HAND then return false end
        if OFF_HAND_WEAPON[inv] then
            local from = DUAL_WIELD[class]
            if not (from and level >= from) then return false end
        end
        if worn then
            if worn.inv == SHIELD or worn.inv == HOLDABLE then return inv == worn.inv end
            if OFF_HAND_WEAPON[worn.inv] then return OFF_HAND_WEAPON[inv] or false end
        end
        return true
    elseif hand == "ranged" then
        if worn then
            local wornRelic, relic = worn.inv == RELIC_INV, inv == RELIC_INV
            local wornWand, wand = worn.cls == WEAPON and worn.sub == WAND, cls == WEAPON and sub == WAND
            return wornRelic == relic and wornWand == wand
        end
        return true
    end
    return true
end

local function Suits(class, kinds)
    if kinds == 0 then return true end
    local wants = WANTS[class]
    return not wants or bband(kinds, wants) ~= 0
end

local function DropLess(a, b)
    if a.raid ~= b.raid then return not a.raid end

    if a.judged ~= b.judged then return a.judged end
    if a.judged and (a.gain or 0) ~= (b.gain or 0) then return (a.gain or 0) > (b.gain or 0) end
    if a.ilvl ~= b.ilvl then

        if a.raid then return a.ilvl < b.ilvl end
        return a.ilvl > b.ilvl
    end
    if a.req ~= b.req then return a.req > b.req end
    return a.name < b.name
end

local function InstanceNames()
    local out = {}
    for _, e in ipairs(ns.FOREVER_INSTANCES or {}) do
        if not out[e.id] then
            local zone = GetRealZoneText and GetRealZoneText(e.id)
            out[e.id] = { name = (zone and zone ~= "") and zone or e.n, raid = e.raid }
        end
    end
    return out
end

local function BossName(boss)
    local names = ns.STATIC_LOOT_BOSS_NAMES
    return names and names[boss.enc] or boss.boss
end

local function ItemName(itemID)
    local name = GetItemNameByID and GetItemNameByID(itemID)
    if not name or name == "" then name = ns.STATIC_LOOT_NAMES and ns.STATIC_LOOT_NAMES[itemID] end
    return name or ("Item #" .. itemID)
end

local function QualityHex(quality)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    return c and c.hex or nil
end

local function WornText(worn)
    if not worn then return L["UPGRADES_EMPTY"] end
    if worn.level == 0 then return worn.name end
    return sformat("%s (%d)", worn.name, worn.level)
end



function Upgrades.Rows(entry)
    local out = {}
    local Fold = ns.CharacterData.Fold
    local function Line(text)
        out[#out + 1] = { name = text, category = "Character", noPin = true, noLearn = true, noMenu = true,
                          lookupRow = true, upgradeNote = true, folded = Fold(text) }
        return out
    end
    if not (entry and entry.class and entry.level and (entry.isCurrent or entry.gear)) then
        return Line(L["ITEM_GRID_NO_GEAR"])
    end
    local worn, wornIDs = {}, {}
    for _, def in ipairs(SLOTS) do
        for _, slot in ipairs(def.slots) do
            local w = Worn(entry, slot)
            worn[slot] = w
            if w and w.itemID then wornIDs[w.itemID] = true end
        end
    end
    local insts = InstanceNames()
    local rate = JudgeOf(entry)
    local bySlot = {}
    for i = 1, #SLOTS do bySlot[i] = {} end
    local seen = {}
    for _, boss in ipairs(ns.STATIC_LOOT or {}) do
        local inst = insts[boss.inst]

        for pass = 1, inst and 2 or 0 do
            local list = pass == 1 and boss.items or boss.heroic
            for _, itemID in ipairs(list or {}) do
                local ilvl, req, kinds, inv, cls, sub, quality = Gear(itemID)
                if ilvl and req == 0 then req = ilvl - REQ_GAP end
                if ilvl and ilvl >= MIN_ITEM_LEVEL and req <= entry.level and not wornIDs[itemID] then

                    local verdict = rate and rate(itemID, "item:" .. itemID)
                    local judged = verdict ~= nil and verdict ~= false
                    if verdict ~= false and (judged or Suits(entry.class, kinds)) then
                        for i, def in ipairs(SLOTS) do
                            local key = i .. ":" .. itemID
                            if def.inv[inv] and not seen[key] then
                                local base = worn[def.slots[1]]
                                local weakest = base and base.level or 0
                                if def.slots[2] then
                                    local other = worn[def.slots[2]]
                                    weakest = (base and other) and math.min(base.level, other.level) or 0
                                end
                                local beats = judged or ilvl > weakest
                                if beats and Fits(entry, def, base, inv, cls, sub, itemID, worn[16]) then
                                    seen[key] = true
                                    local gain = ilvl - weakest
                                    if judged then gain = type(verdict) == "number" and verdict or nil end
                                    local list2 = bySlot[i]
                                    list2[#list2 + 1] = { itemID = itemID, ilvl = ilvl, req = req, gain = gain,
                                        judged = judged, quality = quality, boss = boss, heroic = pass == 2,
                                        name = ItemName(itemID), raid = inst and inst.raid or false, inst = inst }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    local heroic = _G["PLAYER_DIFFICULTY2"] or "Heroic"
    for i, def in ipairs(SLOTS) do
        local drops = bySlot[i]
        if #drops > 0 then
            tsort(drops, DropLess)
            local parts = {}
            for _, slot in ipairs(def.slots) do parts[#parts + 1] = WornText(worn[slot]) end
            local label = _G[def.label] or def.label
            out[#out + 1] = { name = label .. ": " .. tconcat(parts, ", "), upgradeHeader = true, upgradeSlot = i,
                              folded = Fold(label) }
            for _, d in ipairs(drops) do
                local bossName = BossName(d.boss)
                if d.heroic then bossName = bossName .. " (" .. heroic .. ")" end
                local instName = d.inst and d.inst.name or ""
                out[#out + 1] = {
                    name = d.name, itemID = d.itemID, icon = GetItemIconByID and GetItemIconByID(d.itemID)
                        or select(5, GetItemInfoInstant(d.itemID)),
                    quality = d.quality, nameHex = QualityHex(d.quality),
                    category = "Loot", lootEntry = true, lookupRow = true, path = EMPTY, steps = EMPTY,
                    encounterID = d.boss.enc, instanceID = d.boss.inst,
                    lootSourceName = bossName, lootInstanceName = instName,
                    lootSourceType = d.raid and "Raid" or "Dungeon",
                    upgradeLevel = d.ilvl, upgradeGain = d.gain, upgradeSlot = i, upgradeRaid = d.raid,
                    upgradeJudged = d.judged or nil,
                    folded = Fold(d.name .. " " .. bossName .. " " .. instName .. " " .. label),
                }
            end
        end
    end
    if #out == 0 then return Line(sformat(L["UPGRADES_NONE_FMT"], entry.level)) end
    return out
end


function Upgrades.Changed()
    if ns.Characters and ns.Characters.ForgetPages then ns.Characters:ForgetPages() end
    if ns.Search and ns.Search.RefreshActiveSearch then ns.Search:RefreshActiveSearch(true) end
end




function Upgrades.Visible(rows, words, matches)
    local out = {}
    local narrowed = #words > 0
    local header, dungeons, raids, kept = nil, 0, 0, false
    for _, row in ipairs(rows) do
        if row.upgradeHeader then
            header, dungeons, raids, kept = row, 0, 0, false
        elseif row.upgradeNote then
            out[#out + 1] = row
        else
            local slotMatch = header and matches(header.folded, words)
            if not narrowed or slotMatch or matches(row.folded, words) then
                local capped
                if row.upgradeRaid then
                    raids = raids + 1
                    capped = raids > (narrowed and NARROWED_ROWS or RAID_ROWS)
                else
                    dungeons = dungeons + 1
                    capped = dungeons > (narrowed and NARROWED_ROWS or DUNGEON_ROWS)
                end
                if not capped then
                    if not kept then
                        out[#out + 1] = header
                        kept = true
                    end
                    out[#out + 1] = row
                end
            end
        end
    end
    return out
end
