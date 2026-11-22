-- Loot Filter: a small options window opened from the home page that decides
-- which items the boss loot lists show.
--   * Show recipes            (off by default: recipe drops are a big shared pool)
--   * Only loot my class can use
--   * Only items with the ticked stats (an item passes if it has any of them)
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local function L(key, ...)
    if FDJ.L then return FDJ.L(key, ...) end
    return key
end

local function Settings()
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    local db = ForeverDungeonJournalDB.lootFilter
    if type(db) ~= "table" then
        db = {}
        ForeverDungeonJournalDB.lootFilter = db
    end
    -- The "show recipes" option was removed: recipes live on the recipe tab
    -- (or under the boss-page divider), never inline in the loot list.
    db.recipes = false
    if db.classOnly == nil then db.classOnly = false end
    if type(db.stats) ~= "table" then db.stats = {} end
    -- Spell Crit / Spell Hit were folded into Critical Strike / Hit.
    if db.stats.SPELLCRIT then db.stats.CRIT = true end
    if db.stats.SPELLHIT then db.stats.HIT = true end
    db.stats.SPELLCRIT, db.stats.SPELLHIT, db.stats.BLOCK = nil, nil, nil
    if db.matchAll == nil then db.matchAll = true end
    if db.enabled == nil then db.enabled = false end
    if type(db.minLevel) ~= "number" or db.minLevel <= 0 then db.minLevel = nil end
    if type(db.maxLevel) ~= "number" or db.maxLevel <= 0 then db.maxLevel = nil end -- levelrange
    -- Armor types ticked in the Armor Filter (none ticked = all types).
    -- Older builds stored a single type in db.armor: carry it over once.
    if type(db.armorTypes) ~= "table" then db.armorTypes = {} end
    if type(db.armor) == "string" then db.armorTypes[db.armor] = true end
    db.armor = nil
    for key in pairs(db.armorTypes) do
        if key ~= "Cloth" and key ~= "Leather" and key ~= "Mail" and key ~= "Plate"
            and key ~= "Cloak" and key ~= "Ring" and key ~= "Neck" and key ~= "Trinket"
            and key ~= "Head" and key ~= "Shoulder" and key ~= "Chest" and key ~= "Wrist" -- armorslots
            and key ~= "Hands" and key ~= "Waist" and key ~= "Legs" and key ~= "Feet" then db.armorTypes[key] = nil end
    end
    -- Weapon types ticked in the Weapon Filter (none ticked = no filter).
    if type(db.weaponTypes) ~= "table" then db.weaponTypes = {} end
    for _, kind in ipairs({ "Sword", "Axe", "Mace" }) do
        if db.weaponTypes[kind] then
            db.weaponTypes["1H " .. kind], db.weaponTypes["2H " .. kind] = true, true
        end
    end
    for key in pairs(db.weaponTypes) do
        if FDJ.LOOT_FILTER_WEAPON_SET and not FDJ.LOOT_FILTER_WEAPON_SET[key] then db.weaponTypes[key] = nil end
    end
    -- Spell schools ticked under Spell Damage (none ticked = any spell damage).
    if type(db.schools) ~= "table" then db.schools = {} end
    for key in pairs(db.schools) do
        if key ~= "FIRE" and key ~= "FROST" and key ~= "NATURE" and key ~= "SHADOW" and key ~= "ARCANE" and key ~= "HOLY" then db.schools[key] = nil end
    end
    -- Resistances ticked in the Resistance Filter (none ticked = no filter).
    if type(db.resists) ~= "table" then db.resists = {} end
    for key in pairs(db.resists) do
        if key ~= "FIRE" and key ~= "FROST" and key ~= "NATURE" and key ~= "SHADOW" and key ~= "ARCANE" then db.resists[key] = nil end
    end
    return db
end

-- The resistance filter is switched off for now (set to true to bring back
-- the drop-down next to Defense).
local RESIST_FILTER = true

local function AnyResistTicked(db)
    if not RESIST_FILTER then return false end
    return next(db.resists or {}) ~= nil
end

local function AnyArmorTicked(db)
    return next(db.armorTypes or {}) ~= nil
end

-- ------------------------------------------------------------ armor type
-- Armor filter: "Cloth" / "Leather" / "Mail" / "Plate", or nil for all.
-- Only armor pieces of another type are filtered out; weapons, shields,
-- rings, necks, trinkets and cloaks have no armor type and stay (unless
-- Cloak / Ring / Neck / Trinket is ticked too, see below).
local ARMOR_TYPES = { "Cloth", "Leather", "Mail", "Plate" }
-- Cloaks are stored as "Back, Cloth" but every armor type wears them.
local function IsCloak(item)
    local slot = type(item) == "table" and item[3]
    if type(slot) ~= "string" then return false end
    local first = slot:match("^%s*([^,]+)")
    return first ~= nil and first:gsub("%s+$", "") == "Back"
end
-- untypedarmor (2.0.12): an armor piece the data gives no armor type
-- ("Head" for Blindwatcher's Sight) counts as every type: whichever armor
-- type is ticked, it shows. (Before, with Cloak / Ring / Neck / Trinket
-- ticked too, it was left out; reported on Discord by oviar.)
local ARMOR_SLOTS = { Head = true, Shoulder = true, Chest = true, Wrist = true, Hands = true, Waist = true, Legs = true, Feet = true }
local function UntypedArmor(item)
    local slot = type(item) == "table" and item[3]
    if type(slot) ~= "string" then return false end
    local first, kind = slot:match("^%s*([^,]+),?%s*(.*)$")
    first = first and first:gsub("%s+$", "")
    return first ~= nil and ARMOR_SLOTS[first] == true and (kind == nil or kind:match("^%s*$") ~= nil)
end
local function AnyArmorTypeTicked(t)
    for _, key in ipairs(ARMOR_TYPES) do if t[key] then return true end end
    return false
end
local function ArmorType(item)
    local slot = type(item) == "table" and item[3]
    if type(slot) ~= "string" then return nil end
    if IsCloak(item) then return nil end
    for token in slot:gmatch("([^,]+)") do
        token = token:gsub("^%s+", ""):gsub("%s+$", "")
        for _, armor in ipairs(ARMOR_TYPES) do
            if token == armor then return armor end
        end
    end
    return nil
end
-- Cloak / Ring / Neck / Trinket sit in the same drop-down, under the armor
-- types. They have no armor type, so they are matched on the item's slot.
-- Ticking any of them turns the drop-down into "show only these": ticked
-- slots and armor of ticked types stay, the rest goes; weapons are left to
-- the Weapon filter.
local JEWELRY_TYPES = { "Cloak", "Ring", "Neck", "Trinket" }
local JEWELRY_SLOT = { Back = "Cloak", Finger = "Ring", Neck = "Neck", Trinket = "Trinket" }
local ARMOR_CHOICES = { "Cloth", "Leather", "Mail", "Plate", "Cloak", "Ring", "Neck", "Trinket" }
local ARMOR_LABEL_KEY = { Cloak = "LF_CLOAK", Ring = "LF_RING", Neck = "LF_NECK", Trinket = "LF_TRINKET" }
local function JewelryType(item)
    local slot = type(item) == "table" and item[3]
    if type(slot) ~= "string" then return nil end
    local first = slot:match("^%s*([^,]+)")
    if not first then return nil end
    return JEWELRY_SLOT[(first:gsub("%s+$", ""))]
end
local function AnyJewelryTicked(t)
    for _, key in ipairs(JEWELRY_TYPES) do if t[key] then return true end end
    return false
end
-- armorslots (2.0.10, M 17 Nov 2026: "a window that covers all the pieces
-- we are missing, helm shoulders etc"): Head ... Feet, in a second box right
-- of the Armor drop-down. Like Cloak / Ring / Neck / Trinket, ticking any
-- of them shows only the ticked slots (of the ticked armor types, if any).
local ARMOR_SLOT_CHOICES = { "Head", "Shoulder", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet" }
local function ArmorSlot(item)
    local slot = type(item) == "table" and item[3]
    if type(slot) ~= "string" then return nil end
    local first = slot:match("^%s*([^,]+)")
    first = first and first:gsub("%s+$", "")
    if first and ARMOR_SLOTS[first] then return first end
    return nil
end
local function AnyArmorSlotTicked(t)
    for _, key in ipairs(ARMOR_SLOT_CHOICES) do if t[key] then return true end end
    return false
end
local function ArmorLabel(key)
    if ARMOR_LABEL_KEY[key] then return L(ARMOR_LABEL_KEY[key]) end
    return (FDJ.LocalizeItemSlot and FDJ.LocalizeItemSlot(key)) or key
end
FDJ.LootFilterSettings = Settings

-- ------------------------------------------------------------ weapon type
-- Weapon filter: ticked weapon types (shields included). While any is ticked,
-- weapons of other types are hidden, and so is everything that is not a
-- weapon unless the Armor filter is also set and the item is armor of a
-- ticked type (e.g. Leather + Dagger for a rogue).
-- Swords, axes and maces come one- and two-handed; the other types only one way.
-- heldoffhand (2.0.11, M 18 Nov 2026: "we forgot to add held in off hands in
-- the loot filter"): "Held In Off-hand" items, last, after Shield.
local WEAPON_TYPES = { "1H Sword", "2H Sword", "1H Axe", "2H Axe", "1H Mace", "2H Mace", "Dagger", "Fist Weapon", "Polearm", "Staff", "Bow", "Gun", "Crossbow", "Wand", "Thrown", "Shield", "Held In Off-hand" }
local HANDED = { Sword = true, Axe = true, Mace = true }
local WEAPON_SET = {}
for _, w in ipairs(WEAPON_TYPES) do WEAPON_SET[w] = true end
FDJ.LOOT_FILTER_WEAPON_SET = WEAPON_SET
local function WeaponType(item)
    local slot = type(item) == "table" and item[3]
    if type(slot) ~= "string" then return nil end
    local first, kind = slot:match("^([^,]+),%s*(.+)$")
    if not first then first = slot end
    first = first:gsub("%s+$", "")
    if first == "Thrown" then return "Thrown" end
    if first:lower() == "held in off-hand" then return "Held In Off-hand" end -- heldoffhand
    if kind and first ~= "Projectile" then
        kind = kind:gsub("%s+$", "")
        if HANDED[kind] then return (first == "Two-Hand" and "2H " or "1H ") .. kind end
        if WEAPON_SET[kind] then return kind end
    end
    return nil
end
-- Menu label: "One-Hand Sword", "Dagger"... in the journal language.
local function WeaponLabel(key)
    local loc = FDJ.LocalizeItemSlot or function(t) return t end
    local hand, kind = key:match("^(%d)H (.+)$")
    if hand then return loc(hand == "2" and "Two-Hand" or "One-Hand") .. " " .. loc(kind) end
    return loc(key)
end
local function AnyWeaponTicked(db)
    return next(db.weaponTypes or {}) ~= nil
end

-- ---------------------------------------------------------------- recipes
-- Blueprints are few and distinctive: on boss pages they stay in the main
-- loot list instead of going under the "Recipes & Patterns" divider.
local function IsBlueprint(item)
    if type(item) ~= "table" then return false end
    local slot, name = item[3], item[2]
    return (type(slot) == "string" and slot:lower():find("blueprint", 1, true) ~= nil)
        or (type(name) == "string" and name:lower():find("^blueprint:") ~= nil)
end

FDJ.IsBlueprint = IsBlueprint

-- Loot offered by the search bar: whatever the Loot Filter keeps, plus every
-- blueprint (blueprints are always listed on boss pages, so always findable).
function FDJ.SearchableBossLoot(boss)
    if type(boss) ~= "table" or type(boss.loot) ~= "table" then return {} end
    if boss.recipeTab then return boss.loot end -- recipes are found on their tab
    local kept = FDJ.FilterBossLoot(boss).loot or {}
    local seen, out = {}, {}
    for _, item in ipairs(kept) do seen[item] = true; out[#out + 1] = item end
    for _, item in ipairs(boss.loot) do
        if IsBlueprint(item) and not seen[item] then out[#out + 1] = item end
    end
    return out
end

local function IsRecipe(item)
    if type(item) ~= "table" then return false end

    -- Most profession drops use slot strings such as "Recipe, Leatherworking",
    -- but some Forever entries use variants like "Leatherworking Recipe".
    -- Detect both the stored slot text and the item-name prefix so patterns,
    -- plans, recipes and blueprints always obey the recipe visibility toggle.
    local slot = item[3]
    if type(slot) == "string" then
        local lowerSlot = slot:lower()
        if lowerSlot:find("recipe", 1, true) or lowerSlot:find("blueprint", 1, true) then
            return true
        end
    end

    local name = item[2]
    if type(name) == "string" then
        local lowerName = name:lower()
        if lowerName:find("^pattern:") or lowerName:find("^plans:")
            or lowerName:find("^recipe:") or lowerName:find("^blueprint:") then
            return true
        end
    end

    return false
end

-- ---------------------------------------------------------- class usability
-- Decided from the slot text stored with every item ("Hands, Leather",
-- "Two-Hand, Sword"), so it works before the item is cached.
local ARMOR = {
    Cloth = { ALL = true },
    Leather = { DRUID = 1, ROGUE = 1, HUNTER = 1, SHAMAN = 1, WARRIOR = 1, PALADIN = 1 },
    Mail = { WARRIOR = 1, PALADIN = 1, HUNTER = 40, SHAMAN = 40 },
    Plate = { WARRIOR = 40, PALADIN = 40 },
    Shield = { WARRIOR = 1, PALADIN = 1, SHAMAN = 1 },
}
local ONE_HAND = {
    -- rogueaxe (2.1.3): WoW Forever lets Rogues use one-handed axes; without
    -- them here, "Only show loot my class can use" greyed out every one-hand
    -- axe for a Rogue (Glutton's Cleaver; reported on Discord by Dom).
    Axe = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, ROGUE = 1, SHAMAN = 1 },
    Sword = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, ROGUE = 1, MAGE = 1, WARLOCK = 1 },
    Mace = { WARRIOR = 1, PALADIN = 1, ROGUE = 1, PRIEST = 1, SHAMAN = 1, DRUID = 1 },
    Dagger = { WARRIOR = 1, HUNTER = 1, ROGUE = 1, PRIEST = 1, SHAMAN = 1, MAGE = 1, WARLOCK = 1, DRUID = 1 },
    ["Fist Weapon"] = { WARRIOR = 1, HUNTER = 1, ROGUE = 1, SHAMAN = 1, DRUID = 1 },
}
local TWO_HAND = {
    Axe = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, SHAMAN = 1 },
    Sword = { WARRIOR = 1, PALADIN = 1, HUNTER = 1 },
    Mace = { WARRIOR = 1, PALADIN = 1, SHAMAN = 1, DRUID = 1 },
    Staff = { WARRIOR = 1, HUNTER = 1, PRIEST = 1, SHAMAN = 1, MAGE = 1, WARLOCK = 1, DRUID = 1 },
    -- druidpolearm (2.0.8): WoW Forever lets Druids train Polearms (their
    -- skill window lists it); without them here, "Only show loot my class can
    -- use" greyed out every polearm for a Druid (Felbough Arm; reported on
    -- Discord by swisp).
    Polearm = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, DRUID = 1 },
}
local RANGED = {
    Bow = { WARRIOR = 1, HUNTER = 1, ROGUE = 1 },
    Gun = { WARRIOR = 1, HUNTER = 1, ROGUE = 1 },
    Crossbow = { WARRIOR = 1, HUNTER = 1, ROGUE = 1 },
    Wand = { PRIEST = 1, MAGE = 1, WARLOCK = 1 },
    Thrown = { WARRIOR = 1, HUNTER = 1, ROGUE = 1 },
}

-- futurearmor (2.0.10, M 17 Nov 2026: "if a level 30 paladin ticks show my
-- class loot, level 40+ plate should be valid for him, same for warrior;
-- hunters and shamans should see mail pieces that are level 40+"; the
-- Discord report by Krylo): gear the class learns to wear at a later level
-- (plate and mail at 40) counts as usable when the item itself needs that
-- level or more, since by the time the character can equip it, the class
-- can wear it. itemLevel: the item's required level (nil when not known yet:
-- then the character's own level decides, as before).
local function Allowed(rule, class, level, itemLevel)
    if not rule then return true end
    if rule.ALL then return true end
    local need = rule[class]
    if not need then return false end
    if level >= need then return true end
    return type(itemLevel) == "number" and itemLevel >= need
end

-- The level an item needs: from the game's item data, or for an item whose
-- ID is not known yet, the "Requires Level" line the game showed (item.tip).
local function ItemRequiredLevel(item)
    local id = item and item[1]
    if type(id) == "number" and id > 0 then
        if type(GetItemInfo) ~= "function" then return nil end
        local ok, _, _, _, _, itemMinLevel = pcall(GetItemInfo, id)
        if ok and type(itemMinLevel) == "number" and itemMinLevel > 0 then return itemMinLevel end
        return nil
    end
    for _, line in ipairs(type(item) == "table" and type(item.tip) == "table" and item.tip or {}) do
        local n = type(line) == "string" and tonumber(line:lower():match("^requires level (%d+)"))
        if n then return n end
    end
    return nil
end

local function ClassCanUse(item)
    local slotText = item and item[3]
    if type(slotText) ~= "string" or slotText == "" then return true end
    if IsRecipe(item) then return true end
    local _, class = UnitClass("player")
    if not class then return true end
    local level = (UnitLevel and UnitLevel("player")) or 60
    local slot, kind = slotText:match("^([^,]+),%s*(.+)$")
    if not slot then slot = slotText end
    if slot == "Thrown" then return Allowed(RANGED.Thrown, class, level) end
    if not kind then return true end -- Finger, Neck, Trinket, Bag, Held In Off-hand...
    if slot == "Back" then return true end
    if slot == "Ranged" then return Allowed(RANGED[kind], class, level) end
    if slot == "Two-Hand" then return Allowed(TWO_HAND[kind], class, level) end
    if slot == "One-Hand" or slot == "Main Hand" then return Allowed(ONE_HAND[kind], class, level) end
    if slot == "Off Hand" then
        if kind == "Shield" then return Allowed(ARMOR.Shield, class, level) end
        return Allowed(ONE_HAND[kind], class, level)
    end
    return Allowed(ARMOR[kind], class, level, level < 60 and ItemRequiredLevel(item) or nil)
end
FDJ.LootFilterClassCanUse = ClassCanUse

-- ------------------------------------------------------------------ stats
-- Read from the item tooltip. Primary stats use the client's own stat names,
-- so they work in every language; the rest match the English tooltip wording.
local function Has(line, text) return line:find(text, 1, true) ~= nil end
-- Schools ticked under Spell Damage while a filter runs (nil = any school).
local schoolsWanted
local SCHOOL_WORDS = { FIRE = "fire", FROST = "frost", NATURE = "nature", SHADOW = "shadow", ARCANE = "arcane", HOLY = "holy" }
local SCHOOL_ORDER = { "FIRE", "FROST", "NATURE", "SHADOW", "ARCANE", "HOLY" }
local function SpellDamageLine(l)
    if Has(l, "increases healing done") then return false end
    local generic = Has(l, "increases damage and healing done") or (Has(l, "increases damage done") and Has(l, "spell")) or Has(l, "spell damage") or Has(l, "spell power")
    if not generic then return false end
    -- "Increases damage done by Fire spells and effects": one school only.
    local lineSchool
    for key, word in pairs(SCHOOL_WORDS) do
        if Has(l, word .. " spell") or Has(l, word .. " damage") then lineSchool = key break end
    end
    if not schoolsWanted then return true end
    -- With schools ticked, only "+X <school> damage" lines of those schools count.
    return lineSchool ~= nil and schoolsWanted[lineSchool] == true
end
local STATS = {
    { key = "STR", global = "SPELL_STAT1_NAME", label = "Strength" },
    { key = "AGI", global = "SPELL_STAT2_NAME", label = "Agility" },
    { key = "STA", global = "SPELL_STAT3_NAME", label = "Stamina" },
    { key = "INT", global = "SPELL_STAT4_NAME", label = "Intellect" },
    { key = "SPI", global = "SPELL_STAT5_NAME", label = "Spirit" },
    -- Healing only counts lines that lead with healing; spell damage lines
    -- ("Increases damage and healing done by magical spells") are Spell Damage.
    { key = "HEAL", test = function(l) return Has(l, "increases healing done") end },
    { key = "SPELL", test = SpellDamageLine },
    { key = "AP", test = function(l) return Has(l, "attack power") end },
    -- WoW Forever merged spell and melee hit/crit into one stat each.
    { key = "CRIT", test = function(l) return Has(l, "critical strike") end },
    { key = "HIT", test = function(l) return Has(l, "chance to hit") or Has(l, "hit rating") end },
    { key = "DEF", test = function(l) return Has(l, "defense") end },
    -- "Restores 5 mana per 5 sec." (some items say "every 5 sec").
    { key = "MP5", tip = "LF_STAT_MP5_TIP", test = function(l) return Has(l, "mana per 5") or Has(l, "mana every 5") end },
    -- "Restores 6 health per 5 sec." / "health every 5 sec."
    { key = "HP5", tip = "LF_STAT_HP5_TIP", test = function(l) return Has(l, "health per 5") or Has(l, "health every 5") end },
}
FDJ.LOOT_FILTER_STATS = STATS

local function StatLabel(stat)
    -- Use the journal language (it can differ from the client language).
    local text = L("LF_STAT_" .. stat.key)
    if stat.key == "SPELL" then
        local n = 0
        for _ in pairs(Settings().schools or {}) do n = n + 1 end
        if n > 0 then text = text .. " (" .. n .. ")" end
    end
    return text
end

local scanTip
local textCache = {}
-- equipdim (2.0.8): a tooltip read before the server has sent the item says
-- only "Retrieving item information", but other addons still add their own
-- lines to it (Vendor price, Item Level, "New in Forever"...), so it passed
-- the two-line check below and was kept for the whole session: the item
-- stayed greyed out even after its stats came in (Slitherwrap Girdle, +9
-- Agility; reported on Discord by swisp). Such a read is never kept now, and
-- whatever was read about an item is read again once its data arrives.
local function PendingLine(text)
    if text == RETRIEVING_ITEM_INFO or text == RETRIEVING_DATA then return true end
    return string.lower(text):find("retrieving item information", 1, true) ~= nil
end
local function TooltipText(itemID, cacheOnly)
    if textCache[itemID] then return textCache[itemID] end
    if cacheOnly then return nil end
    if not CreateFrame then return nil end
    if not scanTip then
        local ok, tip = pcall(CreateFrame, "GameTooltip", "ForeverDungeonJournalScanTooltip", nil, "GameTooltipTemplate")
        if not ok or not tip then return nil end
        scanTip = tip
    end
    local ok = pcall(function()
        scanTip:SetOwner(UIParent or WorldFrame, "ANCHOR_NONE")
        scanTip:ClearLines()
        scanTip:SetHyperlink("item:" .. itemID)
    end)
    if not ok then return nil end
    local parts = {}
    local count = (scanTip.NumLines and scanTip:NumLines()) or 0
    for i = 1, count do
        local line = _G["ForeverDungeonJournalScanTooltipTextLeft" .. i]
        local text = line and line.GetText and line:GetText()
        if type(text) == "string" and text ~= "" then
            if PendingLine(text) then return nil end -- equipdim: not loaded yet
            -- Stop at the item-set block ("Rotmender's Raiment (0/5)"): set
            -- bonuses are not stats of this item.
            if text:find("%(%d+/%d+%)%s*$") then break end
            if not text:find("^%(%d+%)") then parts[#parts + 1] = text end
        end
    end
    if #parts < 2 then return nil end -- item not loaded yet
    for i = 1, #parts do parts[i] = string.lower(parts[i]) end
    textCache[itemID] = parts
    return parts
end

local function StatInText(stat, lines)
    local name = stat.global and string.lower(_G[stat.global] or stat.label)
    for _, line in ipairs(lines) do
        if name then
            if line:find(name, 1, true) then return true end
        elseif stat.test(line) then
            return true
        end
    end
    return false
end

-- statsapi (2.0.11): the stats past the five primary ones are matched on the
-- English tooltip wording above, which only an English game client shows: on
-- a Chinese, German, French... client Healing, Spell Damage, Attack Power,
-- Critical Strike, Hit, Defense, MP5 and HP5 found nothing (reported on
-- Discord by Sunday, zhTW). There they are read from the game's own item
-- stats instead (C_Item.GetItemStats: names like
-- ITEM_MOD_SPELL_HEALING_DONE_SHORT, the same in every language; checked on
-- the Forever client with Deep Ritual Girdle: healing 16, spell damage 6).
-- English clients: unchanged, the tooltip wording only.
local function EnglishClient()
    local locale = GetLocale and GetLocale() or "enUS"
    return locale == "enUS" or locale == "enGB"
end
local statCache = {}
local function ClientStats(itemID)
    if statCache[itemID] then return statCache[itemID] end
    local fn = (C_Item and C_Item.GetItemStats) or GetItemStats
    if type(fn) ~= "function" then return nil end
    local ok, stats = pcall(fn, "item:" .. itemID)
    if not ok or type(stats) ~= "table" or next(stats) == nil then return nil end -- not loaded yet
    local plain = {}
    for key, value in pairs(stats) do
        if type(key) == "string" and type(value) == "number" then plain[key] = value end
    end
    statCache[itemID] = plain
    return plain
end
-- The total of every stat whose name holds one of the words.
local function StatSum(stats, ...)
    local total = 0
    for key, value in pairs(stats) do
        for i = 1, select("#", ...) do
            if key:find((select(i, ...)), 1, true) then total = total + value break end
        end
    end
    return total
end
-- As the English wording counts them: Healing only when healing leads ("Increases
-- healing done by up to 16 and damage done by up to 6"); "damage and healing
-- done" (both the same) is Spell Damage.
-- schoolstats (2.0.13): one school's damage is a stat of its own
-- (ITEM_MOD_FIRE_DAMAGE_DONE_SHORT=9 on Flamestarter's Signet, HOLY_ on
-- Heartflame Gauntlets, ARCANE_ on Sparklance Wand; checked on the Forever
-- client): it counts as Spell Damage, and the schools picked under Spell
-- Damage's arrow are matched on it.
local SCHOOL_STAT = {
    FIRE = "FIRE_DAMAGE_DONE", FROST = "FROST_DAMAGE_DONE", NATURE = "NATURE_DAMAGE_DONE",
    SHADOW = "SHADOW_DAMAGE_DONE", ARCANE = "ARCANE_DAMAGE_DONE", HOLY = "HOLY_DAMAGE_DONE",
}
local function SpellFromGame(s)
    -- Schools picked: only "+X <school> damage" of those schools (as in English).
    if schoolsWanted then
        for school, on in pairs(schoolsWanted) do
            if on and SCHOOL_STAT[school] and StatSum(s, SCHOOL_STAT[school]) > 0 then return true end
        end
        return false
    end
    local dmg = StatSum(s, "SPELL_DAMAGE", "SPELL_POWER")
    if dmg > 0 and dmg >= StatSum(s, "HEALING") then return true end
    for _, key in pairs(SCHOOL_STAT) do
        if StatSum(s, key) > 0 then return true end
    end
    return false
end
local STAT_FROM_GAME = {
    HEAL = function(s) local heal = StatSum(s, "HEALING") return heal > 0 and heal > StatSum(s, "SPELL_DAMAGE", "SPELL_POWER") end,
    SPELL = SpellFromGame,
    AP = function(s) return StatSum(s, "ATTACK_POWER") > 0 end,
    CRIT = function(s) return StatSum(s, "_CRIT") > 0 end,
    HIT = function(s) return StatSum(s, "_HIT_") > 0 end,
    DEF = function(s) return StatSum(s, "DEFENSE") > 0 end,
    MP5 = function(s) return StatSum(s, "MANA_REGEN", "POWER_REGEN0") > 0 end,
    HP5 = function(s) return StatSum(s, "HEALTH_REGEN") > 0 end,
}
-- equipdim (2.0.8): the five primary stats are also checked against the
-- game's own item stats, on every client (English too), so an item whose
-- tooltip came back without its stat lines is not greyed out for that alone.
local function GameStat(key) return function(s) return (s[key] or 0) > 0 end end
local PRIMARY_FROM_GAME = {
    STR = GameStat("ITEM_MOD_STRENGTH_SHORT"),
    AGI = GameStat("ITEM_MOD_AGILITY_SHORT"),
    STA = GameStat("ITEM_MOD_STAMINA_SHORT"),
    INT = GameStat("ITEM_MOD_INTELLECT_SHORT"),
    SPI = GameStat("ITEM_MOD_SPIRIT_SHORT"),
}
-- equipdim: drop what was read about an item before its data came in.
local arrivalWatcher = CreateFrame and CreateFrame("Frame")
if arrivalWatcher then
    for _, event in ipairs({ "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT" }) do
        pcall(arrivalWatcher.RegisterEvent, arrivalWatcher, event)
    end
    arrivalWatcher:SetScript("OnEvent", function(_, _, itemID)
        itemID = tonumber(itemID)
        if itemID then
            textCache[itemID] = nil
            statCache[itemID] = nil
        end
    end)
end

-- kroldok: an item whose ID is not known yet is matched on the stats the
-- game showed for it (its tip lines in the data).
local function TipText(item)
    local tip = type(item) == "table" and item.tip
    if type(tip) ~= "table" then return nil end
    local parts = {}
    for _, line in ipairs(tip) do
        if type(line) == "table" then line = tostring(line[1] or "") .. " " .. tostring(line[2] or "") end
        if type(line) == "string" and line ~= "" then
            line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            parts[#parts + 1] = string.lower(line)
        end
    end
    return #parts > 0 and parts or nil
end

-- levelrange (2.1.2, M 21 Nov 2026: "instead of minimum required level ...
-- two boxes ... with a dash in between"): the level an item needs. Forever
-- has no global GetItemInfo (the old Minimum required level box read it, so
-- it let almost everything through): C_Item.GetItemInfo first; else the
-- "Requires Level" line the game showed (item.tip) or of the item's tooltip
-- (in the client's language). No requirement counts as level 1; nil:
-- not known yet.
local LEVEL_PATTERN
local ItemLevelNeeded
local function RequiredLevelOf(item)
    -- questlevel: a quest reward needs its quest's level at least.
    local questLevel = type(item) == "table" and tonumber(item.fdjQuestLevel) or nil
    local need = ItemLevelNeeded(item)
    if questLevel and questLevel > 0 then return math.max(need or 1, questLevel) end
    return need
end
function ItemLevelNeeded(item)
    local id = type(item) == "table" and item[1]
    if type(id) == "number" and id > 0 then
        local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        if type(get) == "function" then
            local ok, _, _, _, _, req = pcall(get, id)
            if ok and type(req) == "number" then return math.max(req, 1) end
        end
        if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    for _, line in ipairs(TipText(item) or {}) do
        local n = tonumber(line:match("^requires level (%d+)"))
        if n then return n end
    end
    if type(id) == "number" and id > 0 then
        if not LEVEL_PATTERN then
            local fmt = type(ITEM_MIN_LEVEL) == "string" and ITEM_MIN_LEVEL or "Requires Level %d"
            LEVEL_PATTERN = "^" .. string.lower(fmt):gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%d", "(%%d+)")
        end
        local text = TooltipText(id, FDJ.lootFilterStrict)
        if text then
            for _, line in ipairs(text) do
                local n = tonumber(line:match(LEVEL_PATTERN))
                if n then return n end
            end
            return 1 -- read, and no level needed
        end
    end
    return nil
end

-- matchAll: the item must have every ticked stat; otherwise any one is enough.
local function HasAnyStat(item, wanted, matchAll)
    local id = item and item[1]
    local text
    if not id or id <= 0 then
        text = TipText(item) -- kroldok
        if not text then return false end
    else
        -- The all-dungeon page never scans here: its tooltips are read a few per
        -- frame beforehand (WarmTooltips), so one click cannot run too long.
        text = TooltipText(id, FDJ.lootFilterStrict)
        if not text then return not FDJ.lootFilterStrict end -- unknown yet: keep on boss pages, wait in the results list
    end
    local schools = Settings().schools
    schoolsWanted = (schools and next(schools)) and schools or nil
    -- statsapi: the game's own stats, on a client in another language.
    -- equipdim: the primary stats on every client (read only when needed).
    local english = EnglishClient()
    local gameStats, askedGame
    local found = false
    for _, stat in ipairs(STATS) do
        if wanted[stat.key] then
            local has = StatInText(stat, text)
            local fromGame = PRIMARY_FROM_GAME[stat.key] or (not english and STAT_FROM_GAME[stat.key]) or nil
            if not has and fromGame and id and id > 0 then
                if not askedGame then
                    askedGame = true
                    gameStats = ClientStats(id)
                end
                if gameStats then has = fromGame(gameStats) end
            end
            if has then
                if not matchAll then return true end
                found = true
            elseif matchAll then
                return false
            end
        end
    end
    return found
end

local function AnyStatWanted(db)
    for _, on in pairs(db.stats) do if on then return true end end
    return false
end

-- ------------------------------------------------------------ resistances
-- Matched on the tooltip with the client's own resistance names (so every
-- client language works) plus the English wording. "+X All Resistances"
-- counts for every school.
local RESISTS = {
    { key = "FIRE",   global = "RESISTANCE2_NAME", label = "fire resistance" },
    { key = "NATURE", global = "RESISTANCE3_NAME", label = "nature resistance" },
    { key = "FROST",  global = "RESISTANCE4_NAME", label = "frost resistance" },
    { key = "SHADOW", global = "RESISTANCE5_NAME", label = "shadow resistance" },
    { key = "ARCANE", global = "RESISTANCE6_NAME", label = "arcane resistance" },
}
local RESIST_ORDER = { "FIRE", "FROST", "NATURE", "SHADOW", "ARCANE" }

local function HasResist(item, wanted)
    local id = item and item[1]
    local text
    if not id or id <= 0 then
        text = TipText(item) -- kroldok
        if not text then return false end
    else
        text = TooltipText(id, FDJ.lootFilterStrict)
        if not text then return not FDJ.lootFilterStrict end
    end
    -- The item must have every ticked school. Only real resistance lines
    -- ("+10 Fire Resistance") count; proc text such as "deals 50 Fire
    -- damage" does not. "+X All Resistances" covers every school.
    local found = {}
    for _, line in ipairs(text) do
        if line:find("^%+%s*%d") then
            if line:find("all resistances", 1, true) then return true end
            for _, res in ipairs(RESISTS) do
                local name = type(_G[res.global]) == "string" and string.lower(_G[res.global]) or nil
                if (name and line:find(name, 1, true)) or line:find(res.label, 1, true) then found[res.key] = true end
            end
        end
    end
    for key in pairs(wanted) do
        if not found[key] then return false end
    end
    return true
end

-- ----------------------------------------------------------------- filter
-- Returns the boss itself when nothing is hidden, otherwise a stand-in whose
-- loot list holds only the visible items (every other field reads through).
-- ------------------------------------------------------------ recipe tab
-- Instead of repeating the same recipes on every boss, each dungeon whose
-- bosses drop recipes gets one extra entry at the end of its boss list that
-- holds each recipe once, with the portraits of the bosses that drop it.
-- uniquefirst (2.0.29): a recipe that drops in its own dungeon, not one of
-- the Forever sets found everywhere: the old game's recipes (item IDs below
-- 250000), and Forever's own one-offs listed here.
FDJ.UNIQUE_RECIPES = FDJ.UNIQUE_RECIPES or {
    [252893] = true, -- Pattern: Timbermaw Tunic (Blackmaw Hold)
    [251453] = true, -- Plans: Breastplate of Salvation (Blackmaw Hold)
    [274049] = true, -- Schematic: 9-60 Battery Pack (Gnomeregan, 2.0.35)
    [251451] = true, -- Plans: Stalwart Helm (Lower Blackrock Spire, Bloodaxe Veteran; 2.0.7)
    [252940] = true, -- Pattern: Pristine Scorpid Leggings (Scholomance, Spectral Researcher; 2.0.7)
}
function FDJ.IsUniqueRecipe(itemID)
    itemID = tonumber(itemID)
    if not itemID then return false end
    return itemID < 250000 or FDJ.UNIQUE_RECIPES[itemID] == true
end

-- crowdedrecipes (2.0.7): a Recipes & Patterns page holding many of the
-- Forever recipe sets that drop all over (10 or more: the gloves, boots,
-- cords, helms...) draws no portraits: the same faces on every row, up to
-- 180 of them on one page, and each drawn live. Like Dire Maul: North, it
-- goes to two columns when long, with the bosses on the row and in its
-- tooltip ("Drops from"). Epic recipes keep their bosses' portraits.
-- Pages of a dungeon's own recipes (Blackrock Depths...) are unchanged.
FDJ.CROWDED_RECIPE_PAGE = 10
function FDJ.IsCrowdedRecipePage(boss)
    if type(boss) ~= "table" or not boss.recipeTab or type(boss.loot) ~= "table" then return false end
    if boss.fdjCrowded == nil then
        local shared = 0
        for _, item in ipairs(boss.loot) do
            if type(item) == "table" and not FDJ.IsUniqueRecipe(item[1]) then shared = shared + 1 end
        end
        boss.fdjCrowded = shared >= FDJ.CROWDED_RECIPE_PAGE
    end
    return boss.fdjCrowded
end
function FDJ.RecipeRowKeepsPortrait(item)
    return type(item) == "table" and (tonumber(item[4]) or 0) >= 4
end

-- recipeprof (2.0.7): the professions a Recipes & Patterns page holds, for
-- the row of profession icons on its "N items" line (the game's own
-- profession icons; a click shows that profession's recipes only). Only
-- the professions the page has recipes of, and only when it has two or more.
FDJ.RECIPE_PROF_ORDER = { "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Tailoring", "Cooking", "First Aid", "Fishing", "Mining", "Herbalism", "Skinning" }
FDJ.RECIPE_PROF_ICONS = {
    ["Alchemy"] = "Interface\\Icons\\Trade_Alchemy",
    ["Blacksmithing"] = "Interface\\Icons\\Trade_BlackSmithing",
    ["Enchanting"] = "Interface\\Icons\\Trade_Engraving",
    ["Engineering"] = "Interface\\Icons\\Trade_Engineering",
    ["Leatherworking"] = "Interface\\Icons\\Trade_LeatherWorking",
    ["Tailoring"] = "Interface\\Icons\\Trade_Tailoring",
    ["Cooking"] = "Interface\\Icons\\INV_Misc_Food_15",
    ["First Aid"] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    ["Fishing"] = "Interface\\Icons\\Trade_Fishing",
    ["Mining"] = "Interface\\Icons\\Trade_Mining",
    ["Herbalism"] = "Interface\\Icons\\Trade_Herbalism",
    ["Skinning"] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
}
function FDJ.RecipeProfession(item)
    local kind = type(item) == "table" and item[3]
    return type(kind) == "string" and kind:match("^Recipe,%s*(.+)$") or nil
end
function FDJ.RecipeTabProfessions(tab)
    if type(tab) ~= "table" or not tab.recipeTab or type(tab.loot) ~= "table" then return nil end
    if not tab.fdjProfs then
        local has, list = {}, {}
        for _, item in ipairs(tab.loot) do
            local prof = FDJ.RecipeProfession(item)
            if prof and FDJ.RECIPE_PROF_ICONS[prof] then has[prof] = true end
        end
        for _, prof in ipairs(FDJ.RECIPE_PROF_ORDER) do
            if has[prof] then list[#list + 1] = prof end
        end
        tab.fdjProfs = { has = has, list = list }
    end
    return tab.fdjProfs
end

FDJ.RECIPE_TAB_NAME = "Recipes & Patterns"
do
    for dungeonName, dungeon in pairs(FDJ.DB or {}) do
        if type(dungeon) == "table" and type(dungeon.bosses) == "table" and not dungeon.fdjRecipeTabBuilt then
            dungeon.fdjRecipeTabBuilt = true
            local order, byID = {}, {}
            for _, boss in ipairs(dungeon.bosses) do
                -- Include dungeon-specific trash recipes as well as boss recipes.
                -- Exclude only the synthetic Recipes & Patterns page itself.
                if not boss.recipeTab and type(boss.loot) == "table" then
                    -- Let the row portraits (shared with Trash Drops) draw named
                    -- sources. " / " separates sources on a row, so a boss
                    -- whose name contains it uses "&" instead.
                    local sourceName = boss.name:gsub(" / ", " & ")
                    local displayID = boss.npcID and FDJ.STATIC_DISPLAY_IDS and FDJ.STATIC_DISPLAY_IDS[boss.npcID]
                    if displayID and FDJ.TRASH_MOB_DISPLAY_IDS and not FDJ.TRASH_MOB_DISPLAY_IDS[sourceName] then
                        FDJ.TRASH_MOB_DISPLAY_IDS[sourceName] = displayID
                    end
                    for _, item in ipairs(boss.loot) do
                        if IsRecipe(item) and not IsBlueprint(item) then
                            boss.fdjHasRecipeTab = true
                            -- Use a known trash mob when available, otherwise
                            -- clearly attribute the plans to the Trash Drops page.
                            local source = sourceName
                            if boss.trash and type(item[5]) == "string" and item[5] ~= "" then
                                if not item[5]:lower():find(" trash", 1, true)
                                    and item[5]:lower() ~= "trash" then
                                    source = item[5]
                                end
                            end
                            local entry = byID[item[1]]
                            if entry then
                                if not entry[5]:find(source, 1, true) then
                                    entry[5] = entry[5] .. " / " .. source
                                end
                            else
                                entry = { item[1], item[2], item[3], item[4], source, tip = item.tip }
                                byID[item[1]] = entry
                                order[#order + 1] = entry
                            end
                        end
                    end
                end
            end
            -- uniquefirst (2.0.29): the dungeon's own recipes (Green Dragonscale
            -- Leggings, Dark Iron Plate...) at the top, above the usual Forever
            -- sets that drop all over (the Filigreed, Silvered, Leather ...
            -- patterns): each group keeps its order.
            if #order > 1 then
                local mine, shared = {}, {}
                for _, entry in ipairs(order) do
                    if FDJ.IsUniqueRecipe(entry[1]) then mine[#mine + 1] = entry else shared[#shared + 1] = entry end
                end
                if #mine > 0 and #shared > 0 then
                    for _, entry in ipairs(shared) do mine[#mine + 1] = entry end
                    order = mine
                end
            end
            if #order > 0 then
                dungeon.bosses[#dungeon.bosses + 1] = { name = FDJ.RECIPE_TAB_NAME, trash = true, recipeTab = true, loot = order }
            end
        end
    end
end

function FDJ.FilterBossLoot(boss)
    FDJ.lootFilterHidden = 0
    if type(boss) ~= "table" or type(boss.loot) ~= "table" then return boss end
    -- The recipe tab is a view of other bosses' drops: never list it twice.
    if boss.recipeTab then return setmetatable({ loot = {} }, { __index = boss }) end
    local db = Settings()
    -- Switched off: default view (recipe drops hidden, nothing else filtered).
    local on = db.enabled
    local showRecipes = on and db.recipes
    local classOnly = on and db.classOnly
    local wantStats = on and AnyStatWanted(db) and not FDJ.lootFilterSkipStats -- fastshow
    local minLevel = on and db.minLevel or nil
    local maxLevel = on and db.maxLevel or nil -- levelrange
    if minLevel and maxLevel and minLevel > maxLevel then minLevel, maxLevel = maxLevel, minLevel end
    local armor = on and AnyArmorTicked(db) and db.armorTypes or nil
    local resists = on and AnyResistTicked(db) and not FDJ.lootFilterSkipStats and db.resists or nil -- fastshow
    local weapons = on and AnyWeaponTicked(db) and db.weaponTypes or nil
    if showRecipes and not classOnly and not wantStats and not minLevel and not maxLevel and not armor and not resists and not weapons then return boss end
    local shown = {}
    for _, item in ipairs(boss.loot) do
        local keep = true
        if IsRecipe(item) then
            keep = showRecipes
        else
            if classOnly and not ClassCanUse(item) then keep = false end
            if keep and armor then
                local itemArmor = ArmorType(item)
                local slotsOn = AnyArmorSlotTicked(armor) -- armorslots
                -- armorslots: slots ticked with no armor type = any type
                if itemArmor and not armor[itemArmor]
                    and not (slotsOn and not AnyArmorTypeTicked(armor)) then keep = false end
                if keep and (AnyJewelryTicked(armor) or slotsOn) then
                    local jewel = JewelryType(item)
                    local piece = slotsOn and ArmorSlot(item) or nil -- armorslots
                    if jewel then
                        if not armor[jewel] then keep = false end
                    elseif piece then
                        if not armor[piece] then keep = false end
                    elseif not itemArmor
                        and not (UntypedArmor(item) and AnyArmorTypeTicked(armor)) -- untypedarmor
                        and not (weapons and WeaponType(item)) then
                        keep = false
                    end
                end
            end
            if keep and weapons then
                local itemWeapon = WeaponType(item)
                if itemWeapon then
                    if not weapons[itemWeapon] then keep = false end
                elseif not (armor and (ArmorType(item) or IsCloak(item) or armor[JewelryType(item) or ""]
                    or armor[ArmorSlot(item) or ""] -- armorslots
                    or (UntypedArmor(item) and AnyArmorTypeTicked(armor)))) then -- untypedarmor
                    keep = false
                end
            end
            if keep and (minLevel or maxLevel) then -- levelrange: from - to (10 - 10: level 10 only)
                local required = RequiredLevelOf(item)
                if required == nil then
                    if FDJ.lootFilterStrict then keep = false end -- not loaded yet
                elseif (minLevel and required < minLevel) or (maxLevel and required > maxLevel) then
                    keep = false
                end
            end
            if keep and wantStats and not HasAnyStat(item, db.stats, db.matchAll) then keep = false end
            if keep and resists and not HasResist(item, resists) then keep = false end
        end
        if keep then shown[#shown + 1] = item end
    end
    FDJ.lootFilterHidden = #boss.loot - #shown
    if FDJ.lootFilterHidden == 0 then return boss end
    return setmetatable({ loot = shown }, { __index = boss })
end

-- Boss pages: recipe drops are still removed when switched off, but gear the
-- filter rules out stays in the list and is marked to be drawn blacked out.
function FDJ.FilterBossLootForPage(boss)
    FDJ.lootFilterDimmed = {}
    FDJ.lootFilterHidden = 0
    -- Recipe section on boss pages: recipe drops are never silently hidden.
    -- They sit under a "Recipes & Patterns (N)" divider at the end of the
    -- list, folded by default; lootRecipeSplit is the number of rows above it.
    FDJ.lootRecipeCount = 0
    FDJ.lootRecipeSplit = nil
    if type(boss) ~= "table" or type(boss.loot) ~= "table" then return boss end
    if boss.fdjDungeon then return boss end -- the Show page already holds matches only
    if boss.recipeTab then return boss end  -- the recipe tab always lists everything
    local db = Settings()
    local showRecipes = db.enabled and db.recipes
    local keep = {}
    for _, item in ipairs(FDJ.FilterBossLoot(boss).loot) do keep[item] = true end
    local shown, recipes = {}, {}
    for _, item in ipairs(boss.loot) do
        if IsBlueprint(item) then
            shown[#shown + 1] = item
        elseif IsRecipe(item) then
            if showRecipes then
                shown[#shown + 1] = item
            elseif not boss.fdjHasRecipeTab then
                -- (with a recipe tab in the dungeon, recipes live there instead)
                recipes[#recipes + 1] = item
            end
        else
            shown[#shown + 1] = item
            if not keep[item] then FDJ.lootFilterDimmed[item] = true end
        end
        if boss.lootRemoved then FDJ.lootFilterDimmed[item] = true end -- lootremoved: all of it greyed out
    end
    FDJ.lootFilterHidden = 0
    if #recipes > 0 then
        FDJ.lootRecipeCount = #recipes
        FDJ.lootRecipeSplit = #shown
        if FDJ.lootRecipesExpanded then
            for _, item in ipairs(recipes) do shown[#shown + 1] = item end
        end
    end
    if #shown == #boss.loot and not FDJ.lootRecipeSplit then return boss end
    return setmetatable({ loot = shown }, { __index = boss })
end

-- lootchildren (2.0.8): would the filter rule this item out? (an item shown
-- under the half that makes it: Sul'thraze the Lasher). Leaves the page's
-- hidden count as it was.
function FDJ.LootFilterRulesOut(item)
    if type(item) ~= "table" or IsRecipe(item) then return false end
    local hidden = FDJ.lootFilterHidden
    local ok, out = pcall(FDJ.FilterBossLoot, { loot = { item } })
    FDJ.lootFilterHidden = hidden
    return (ok and type(out) == "table" and type(out.loot) == "table" and #out.loot == 0) and true or false
end

function FDJ.UpdateLootFilterNote(frame)
    if not frame then return end
    local note = frame.lootFilterNote
    if not note and frame.lootScroll and frame.lootScroll.GetParent then
        note = frame.lootScroll:GetParent():CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
        frame.lootFilterNote = note
        note:SetPoint("BOTTOMRIGHT", frame.lootScroll, "TOPRIGHT", 0, 3)
        note:SetTextColor(0.72, 0.67, 0.58)
    end
    if not note then return end
    local hidden = FDJ.lootFilterHidden or 0
    if hidden > 0 then
        note:SetText(L("LF_HIDDEN_NOTE", hidden))
        note:Show()
    else
        note:Hide()
    end
end

-- --------------------------------------------------------------------- UI
local function IsActive()
    local db = Settings()
    return db.enabled and (db.recipes or db.classOnly or db.minLevel ~= nil or db.maxLevel ~= nil or AnyArmorTicked(db) or AnyWeaponTicked(db) or AnyResistTicked(db) or AnyStatWanted(db))
end

local function UpdateButton(frame)
    if not frame or not frame.lootFilterButtonText then return end
    local text = L("LOOT_FILTER")
    if IsActive() then text = text .. " |cff40ff40*|r" end
    frame.lootFilterButtonText:SetText(text)
    local width = math.max(110, math.min(180, math.ceil((frame.lootFilterButtonText:GetStringWidth() or 90) + 26)))
    frame.lootFilterButton:SetWidth(width)
end

local function Changed(frame)
    UpdateButton(frame)
    if frame and frame.lootFilterResults and frame.lootFilterResults:IsShown() then FDJ.ShowLootFilterResults(frame) end
    if FDJ.RebuildLootFilterPage then FDJ.RebuildLootFilterPage(frame) end
    if FDJ.RefreshLootNow then FDJ.RefreshLootNow() end
end

local function MakeCheck(parent, frame, getter, setter)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    FDJ.OwnFonts(check) -- ownfonts (2.0.8)
    check:SetSize(24, 24)
    local text = check:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    text:SetPoint("LEFT", check, "RIGHT", 4, 0)
    text:SetJustifyH("LEFT")
    check.fdjLabel = text
    check.fdjGet = getter
    check:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
        Changed(frame)
    end)
    return check
end

local function RefreshWindow(frame)
    local win = frame.lootFilterWindow
    if not win then return end
    win.title:SetText(L("LOOT_FILTER"))
    win.statsHeader:SetText(L("LF_STATS_HEADER"))
    win.statsHint:SetText(L("LF_STATS_HINT"))
    -- Small inline icons in front of the two option labels: a recipe scroll,
    -- and the icon of the class this character is playing.
    local recipeIcon = "|TInterface\\Icons\\INV_Scroll_03:16:16:0:0:64:64:5:59:5:59|t "
    local classIcon = ""
    do
        local _, classFile = UnitClass("player")
        local c = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
        if c then
            classIcon = string.format(
                "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes:16:16:0:0:256:256:%d:%d:%d:%d|t ",
                c[1] * 256 + 4, c[2] * 256 - 4, c[3] * 256 + 4, c[4] * 256 - 4)
        end
    end
    win.classOnly.fdjLabel:SetText(classIcon .. L("LF_CLASS_ONLY"))
    win.clear:SetText(L("LF_CLEAR"))
    win.ok:SetText(L("LF_OK"))
    win.show:SetText(L("LF_SHOW"))
    local showText = win.show.GetFontString and win.show:GetFontString()
    if showText and showText.SetPoint then
        -- Icon and label are centred together as one group.
        showText:ClearAllPoints()
        showText:SetPoint("CENTER", win.show, "CENTER", 9, 0)
        win.show.icon:ClearAllPoints()
        win.show.icon:SetPoint("RIGHT", showText, "LEFT", -2, -3)
    end
    win.matchAll.fdjLabel:SetText(L("LF_MATCH_ALL"))
    if win.questRewards then
        win.questRewards.fdjLabel:SetText("|TInterface\\GossipFrame\\AvailableQuestIcon:16:16:0:0|t " .. L("LF_QUEST_REWARDS"))
    end
    win.minLabel:SetText(L("LF_LEVEL_RANGE")) -- levelrange
    local on = Settings().enabled and true or false
    win.toggle:SetText(on and L("LF_DISABLE") or L("LF_ENABLE"))
    if not win.minBox:HasFocus() then win.minBox:SetText(Settings().minLevel and tostring(Settings().minLevel) or "") end
    if win.maxBox and not win.maxBox:HasFocus() then win.maxBox:SetText(Settings().maxLevel and tostring(Settings().maxLevel) or "") end
    local grey = on and 1 or 0.45
    for _, check in ipairs(win.checks) do
        check:SetChecked(check.fdjGet() and true or false)
        if check.SetEnabled then check:SetEnabled(on) end
        check:SetAlpha(on and 1 or 0.45)
        check.fdjLabel:SetTextColor(grey, grey, grey)
    end
    if win.armor then
        local ticked = Settings().armorTypes or {}
        local names = {}
        for _, list in ipairs({ ARMOR_CHOICES, ARMOR_SLOT_CHOICES }) do -- armorslots
            for _, armor in ipairs(list) do
                if ticked[armor] then
                    names[#names + 1] = ArmorLabel(armor)
                end
            end
        end
        -- Like Resistances: "Armor", or "Armor (2)" with ticks (nothing ticked = all).
        win.armor.text:SetText(#names > 0 and (L("LF_ARMOR_BTN") .. " (" .. #names .. ")") or L("LF_ARMOR_BTN"))
        for _, option in ipairs(win.armor.options or {}) do
            local value = option.fdjArmor
            option.text:SetText(value and ArmorLabel(value) or L("LF_ARMOR_ALL"))
            local checked
            if value then checked = ticked[value] and true or false else checked = #names == 0 end
            option.check:SetShown(checked)
        end
        if not on and win.armor.menu then win.armor.menu:Hide() end
    end
    if win.weapon then
        local ticked = Settings().weaponTypes or {}
        local names = {}
        for _, w in ipairs(WEAPON_TYPES) do
            if ticked[w] then names[#names + 1] = w end
        end
        win.weapon.text:SetText(#names > 0 and (L("LF_WEAPON_BTN") .. " (" .. #names .. ")") or L("LF_WEAPON_BTN"))
        for _, option in ipairs(win.weapon.options or {}) do
            local value = option.fdjWeapon
            option.text:SetText(value and WeaponLabel(value) or L("LF_WEAPON_ALL"))
            local checked
            if value then checked = ticked[value] and true or false else checked = #names == 0 end
            option.check:SetShown(checked)
        end
        if not on and win.weapon.menu then win.weapon.menu:Hide() end
    end
    if win.schoolArrow then
        local ticked = Settings().schools or {}
        for _, option in ipairs(win.schoolArrow.options) do
            option.text:SetText(L("LF_RES_" .. option.fdjSchool))
            option.check:SetShown(ticked[option.fdjSchool] and true or false)
        end
        win.schoolArrow:SetEnabled(on)
        win.schoolArrow:SetAlpha(on and 1 or 0.45)
        if not on then win.schoolArrow.menu:Hide() end
    end
    if win.resist then
        local ticked = Settings().resists or {}
        local names = {}
        for _, key in ipairs(RESIST_ORDER) do
            if ticked[key] then names[#names + 1] = L("LF_RES_" .. key) end
        end
        win.resist.text:SetText(#names > 0 and (L("LF_RESISTANCES") .. " (" .. #names .. ")") or L("LF_RESISTANCES"))
        for _, option in ipairs(win.resist.options or {}) do
            local value = option.fdjResist
            option.text:SetText(L("LF_RES_" .. value))
            option.check:SetShown(ticked[value] and true or false)
        end
        if not on and win.resist.menu then win.resist.menu:Hide() end
    end
    for _, control in ipairs({ win.minBox, win.show, win.clear, win.armor, win.weapon, win.resist }) do
        if control.SetEnabled then control:SetEnabled(on) end
        control:SetAlpha(on and 1 or 0.45)
    end
    if not on and win.minBox.ClearFocus then win.minBox:ClearFocus() end
    win.minLabel:SetTextColor(grey, grey, grey)
    win.statsHeader:SetAlpha(on and 1 or 0.45)
    win.statsHint:SetAlpha(on and 1 or 0.45)
    for _, check in ipairs(win.statChecks) do check.fdjLabel:SetText(StatLabel(check.fdjStat)) end
end

local function CreateWindow(frame)
    local win = CreateFrame("Frame", "ForeverDungeonJournalLootFilter", frame, "BackdropTemplate")
    frame.lootFilterWindow = win
    win:SetSize(390, RESIST_FILTER and 490 or 462)
    win:SetPoint("CENTER", frame, "CENTER", 0, 0)
    win:SetFrameStrata("TOOLTIP")
    win:SetFrameLevel(200)
    if win.SetToplevel then win:SetToplevel(true) end
    win:EnableMouse(true)
    win:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    win:SetBackdropColor(0.09, 0.08, 0.07, 0.98)
    win:SetBackdropBorderColor(0.62, 0.50, 0.30, 1)

    win.title = win:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
    win.title:SetPoint("TOPLEFT", 16, -14)
    win.title:SetTextColor(1.00, 0.82, 0.27)

    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() win:Hide() end)

    local db = Settings()
    win.checks = {}
    win.statChecks = {}


    win.classOnly = MakeCheck(win, frame, function() return Settings().classOnly end, function(v) Settings().classOnly = v end)
    win.classOnly:SetPoint("TOPLEFT", 14, -44)
    win.checks[#win.checks + 1] = win.classOnly

    win.statsHeader = win:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    win.statsHeader:SetPoint("TOPLEFT", win.classOnly, "BOTTOMLEFT", 2, -14)
    win.statsHeader:SetTextColor(1.00, 0.82, 0.27)

    win.statsHint = win:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    win.statsHint:SetPoint("TOPLEFT", win.statsHeader, "BOTTOMLEFT", 0, -3)
    win.statsHint:SetWidth(356)
    win.statsHint:SetJustifyH("LEFT")
    win.statsHint:SetTextColor(0.72, 0.67, 0.58)

    -- levelrange (2.1.2): Level range, from [  ] - to [  ] (the level the
    -- item needs); an empty box sets no limit on its side, both empty shows
    -- everything. 10 - 10: the items for level 10.
    win.minLabel = win:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    win.minLabel:SetPoint("TOPLEFT", win.statsHint, "BOTTOMLEFT", 0, -10)
    local function LevelBox(name, key)
        local box = CreateFrame("EditBox", name, win, "InputBoxTemplate")
        box:SetSize(36, 20)
        box:SetAutoFocus(false)
        if box.SetNumeric then box:SetNumeric(true) end
        if box.SetMaxLetters then box:SetMaxLetters(2) end
        if box.SetJustifyH then box:SetJustifyH("CENTER") end
        box:SetScript("OnTextChanged", function(self, userInput)
            if not userInput then return end
            local value = tonumber(self:GetText() or "")
            Settings()[key] = (value and value > 0) and value or nil
            Changed(frame)
        end)
        box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        box:SetScript("OnTabPressed", function(self) -- from one box to the other
            local other = (self == win.minBox) and win.maxBox or win.minBox
            if other then other:SetFocus() end
        end)
        return box
    end
    win.minBox = LevelBox("ForeverDungeonJournalLootFilterMinLevel", "minLevel")
    win.minBox:SetPoint("LEFT", win.minLabel, "RIGHT", 12, 0)
    win.levelDash = win:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    win.levelDash:SetPoint("LEFT", win.minBox, "RIGHT", 6, 0)
    win.levelDash:SetText("-")
    win.maxBox = LevelBox("ForeverDungeonJournalLootFilterMaxLevel", "maxLevel")
    win.maxBox:SetPoint("LEFT", win.levelDash, "RIGHT", 10, 0)

    -- Armor type drop-down: a red WoW button like the others in this window,
    -- with a mail-armor icon on the left and a down arrow on the right.
    win.armor = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    FDJ.OwnFonts(win.armor) -- ownfonts (2.0.8)
    -- Armor / Weapon / Resistance drop-downs side by side under the level box.
    win.armor:SetSize(116, 22)
    win.armor:SetPoint("TOPLEFT", win.minLabel, "BOTTOMLEFT", -2, -10)
    win.armor:SetText("")
    win.armor.icon = win.armor:CreateTexture(nil, "OVERLAY")
    win.armor.icon:SetSize(16, 16)
    win.armor.icon:SetPoint("LEFT", win.armor, "LEFT", 7, 0)
    win.armor.icon:SetTexture("Interface\\Icons\\INV_Chest_Chain")
    win.armor.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local caret = win.armor:CreateTexture(nil, "OVERLAY")
    caret:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    caret:SetSize(12, 12)
    caret:SetPoint("RIGHT", win.armor, "RIGHT", -7, -3)
    win.armor.text = win.armor:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    win.armor.text:SetPoint("LEFT", win.armor.icon, "RIGHT", 4, 0)
    win.armor.text:SetPoint("RIGHT", caret, "LEFT", -2, 3)
    win.armor.text:SetJustifyH("CENTER")
    win.armor.text:SetWordWrap(false)

    local menu = CreateFrame("Frame", nil, win.armor, "BackdropTemplate")
    win.armor.menu = menu
    local choices = ARMOR_CHOICES
    -- A thin divider separates the armor types from Cloak / Ring / Neck / Trinket.
    local GAP = 7
    local function RowY(i) return -5 - (i - 1) * 22 - ((i > #ARMOR_TYPES) and GAP or 0) end
    menu:SetSize(130, #choices * 22 + 10 + GAP)
    do
        local line = menu:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(0.57, 0.43, 0.20, 0.6)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", 10, RowY(#ARMOR_TYPES) - 22 - math.floor(GAP / 2))
        line:SetPoint("TOPRIGHT", -10, RowY(#ARMOR_TYPES) - 22 - math.floor(GAP / 2))
    end
    menu:SetPoint("TOPLEFT", win.armor, "BOTTOMLEFT", -4, -4)
    menu:SetFrameStrata("TOOLTIP")
    menu:SetFrameLevel(win:GetFrameLevel() + 30)
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    menu:SetBackdropColor(0.055, 0.05, 0.043, 0.99)
    menu:SetBackdropBorderColor(0.57, 0.43, 0.20, 1)
    menu:Hide()
    -- armorslots: Head ... Feet in a box of their own right of the list, as
    -- tall as it; Head..Wrist line up with Cloth..Plate, Hands..Feet with
    -- Cloak..Trinket. Part of the list: opens and closes with it.
    local slotMenu = CreateFrame("Frame", nil, menu, "BackdropTemplate")
    win.armor.slotMenu = slotMenu
    slotMenu:SetSize(130, menu:GetHeight())
    slotMenu:SetPoint("TOPLEFT", menu, "TOPRIGHT", 2, 0)
    slotMenu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    slotMenu:SetBackdropColor(0.055, 0.05, 0.043, 0.99)
    slotMenu:SetBackdropBorderColor(0.57, 0.43, 0.20, 1)
    win.armor.options = {}
    for _, list in ipairs({ { menu, choices }, { slotMenu, ARMOR_SLOT_CHOICES } }) do
    for i, value in ipairs(list[2]) do
        local option = CreateFrame("Button", nil, list[1])
        option:SetPoint("TOPLEFT", 6, RowY(i))
        option:SetPoint("TOPRIGHT", -6, RowY(i))
        option:SetHeight(21)
        option:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        option.fdjArmor = value or nil
        -- Tick box: armor types can be combined (e.g. Cloth + Leather);
        -- "All" clears the ticks. The list stays open while ticking.
        option.box = option:CreateTexture(nil, "ARTWORK")
        option.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
        option.box:SetSize(18, 18)
        option.box:SetPoint("LEFT", 4, 0)
        option.check = option:CreateTexture(nil, "OVERLAY")
        option.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        option.check:SetAllPoints(option.box)
        option.check:Hide()
        option.text = option:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
        option.text:SetPoint("LEFT", option.box, "RIGHT", 4, 0)
        option.text:SetTextColor(0.95, 0.83, 0.53)
        option:SetScript("OnClick", function(self)
            local db = Settings()
            if self.fdjArmor then
                db.armorTypes[self.fdjArmor] = not db.armorTypes[self.fdjArmor] or nil
            else
                db.armorTypes = {}
            end
            RefreshWindow(frame)
            Changed(frame)
        end)
        win.armor.options[#win.armor.options + 1] = option
    end
    end
    win.armor:SetScript("OnClick", function()
        if win.resist and win.resist.menu then win.resist.menu:Hide() end
        if win.weapon and win.weapon.menu then win.weapon.menu:Hide() end
        menu:SetShown(not menu:IsShown())
    end)
    win.armor:SetScript("OnHide", function() menu:Hide() end)
    win.armor:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L("LF_ARMOR"), 1, 0.82, 0.27)
        GameTooltip:Show()
        GameTooltip:SetFrameLevel(win:GetFrameLevel() + 40)
    end)
    win.armor:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Weapon type drop-down (shields included), under the armor one.
    do
        local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
        FDJ.OwnFonts(b) -- ownfonts (2.0.8)
        win.weapon = b
        b:SetSize(116, 22)
        b:SetPoint("LEFT", win.armor, "RIGHT", 4, 0)
        b:SetText("")
        b.icon = b:CreateTexture(nil, "OVERLAY")
        b.icon:SetSize(18, 18)
        b.icon:SetPoint("LEFT", b, "LEFT", 6, 0)
        b.icon:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\WeaponFilterIcon")
        local arrow = b:CreateTexture(nil, "OVERLAY")
        arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
        arrow:SetSize(12, 12)
        arrow:SetPoint("RIGHT", b, "RIGHT", -7, -3)
        b.text = b:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 3, 0)
        b.text:SetPoint("RIGHT", arrow, "LEFT", -2, 3)
        b.text:SetJustifyH("CENTER")
        b.text:SetWordWrap(false)

        local wmenu = CreateFrame("Frame", nil, b, "BackdropTemplate")
        b.menu = wmenu
        local wchoices = {}
        for _, w in ipairs(WEAPON_TYPES) do wchoices[#wchoices + 1] = w end
        -- Two columns so the list stays short.
        local rows = math.ceil(#wchoices / 2)
        wmenu:SetSize(330, rows * 22 + 10)
        wmenu:SetPoint("TOPLEFT", b, "BOTTOMLEFT", -4, -4)
        wmenu:SetFrameStrata("TOOLTIP")
        wmenu:SetFrameLevel(win:GetFrameLevel() + 30)
        wmenu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        wmenu:SetBackdropColor(0.055, 0.05, 0.043, 0.99)
        wmenu:SetBackdropBorderColor(0.57, 0.43, 0.20, 1)
        wmenu:Hide()
        b.options = {}
        for i, value in ipairs(wchoices) do
            local option = CreateFrame("Button", nil, wmenu)
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            option:SetPoint("TOPLEFT", 6 + col * 160, -5 - row * 22)
            option:SetSize(156, 21)
            option:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            option.fdjWeapon = value or nil
            option.box = option:CreateTexture(nil, "ARTWORK")
            option.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
            option.box:SetSize(18, 18)
            option.box:SetPoint("LEFT", 4, 0)
            option.check = option:CreateTexture(nil, "OVERLAY")
            option.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            option.check:SetAllPoints(option.box)
            option.check:Hide()
            option.text = option:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
            option.text:SetPoint("LEFT", option.box, "RIGHT", 4, 0)
            option.text:SetTextColor(0.95, 0.83, 0.53)
            option:SetScript("OnClick", function(self)
                local s = Settings()
                if self.fdjWeapon then
                    s.weaponTypes[self.fdjWeapon] = not s.weaponTypes[self.fdjWeapon] or nil
                else
                    s.weaponTypes = {}
                end
                RefreshWindow(frame)
                Changed(frame)
            end)
            b.options[#b.options + 1] = option
        end
        b:SetScript("OnClick", function()
            if win.armor and win.armor.menu then win.armor.menu:Hide() end
            if win.resist and win.resist.menu then win.resist.menu:Hide() end
            wmenu:SetShown(not wmenu:IsShown())
        end)
        b:SetScript("OnHide", function() wmenu:Hide() end)
        b:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L("LF_WEAPON"), 1, 0.82, 0.27)
            GameTooltip:Show()
            GameTooltip:SetFrameLevel(win:GetFrameLevel() + 40)
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end

    -- Master switch: while off, the journal shows its default loot view.
    win.toggle = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    FDJ.OwnFonts(win.toggle) -- ownfonts (2.0.8)
    win.toggle:SetSize(96, 22)
    win.toggle:SetPoint("TOPRIGHT", -34, -12)
    win.toggle:SetScript("OnClick", function()
        local db = Settings()
        db.enabled = not db.enabled
        RefreshWindow(frame)
        Changed(frame)
    end)

    for i, stat in ipairs(STATS) do
        local key = stat.key
        local check = MakeCheck(win, frame, function() return Settings().stats[key] end, function(v) Settings().stats[key] = v or nil end)
        check.fdjStat = stat
        local column = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        check:SetPoint("TOPLEFT", win.minLabel, "BOTTOMLEFT", -6 + column * 182, -16 - 34 - row * 28)
        if stat.tip then
            -- The label is outside the 24px box; widen the hover/click area over it.
            check:SetHitRectInsets(0, -130, 0, 0)
            check:SetScript("OnEnter", function(self)
                local tip = win.fdjTip
                if not tip then
                    tip = CreateFrame("Frame", nil, win, "BackdropTemplate")
                    win.fdjTip = tip
                    tip:SetFrameLevel(win:GetFrameLevel() + 60)
                    tip:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                        edgeSize = 12,
                        insets = { left = 3, right = 3, top = 3, bottom = 3 },
                    })
                    tip:SetBackdropColor(0.04, 0.04, 0.05, 0.96)
                    tip:SetBackdropBorderColor(0.60, 0.60, 0.60, 1)
                    tip.text = tip:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
                    tip.text:SetPoint("CENTER")
                end
                tip.text:SetText(L(stat.tip))
                tip:SetSize((tip.text:GetStringWidth() or 100) + 20, 26)
                tip:ClearAllPoints()
                tip:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 4)
                tip:Show()
            end)
            check:SetScript("OnLeave", function() if win.fdjTip then win.fdjTip:Hide() end end)
        end
        win.checks[#win.checks + 1] = check
        if key == "SPELL" then win.spellCheck = check end
        win.statChecks[#win.statChecks + 1] = check
    end

    -- Small down arrow next to "Spell Damage" (like the language selector):
    -- narrow spell damage down to schools. Ticking a school ticks Spell Damage.
    if win.spellCheck then
        local check = win.spellCheck
        local arrow = CreateFrame("Button", nil, win)
        win.schoolArrow = arrow
        arrow:SetSize(18, 18)
        arrow:SetPoint("LEFT", check.fdjLabel, "RIGHT", 3, -1)
        local tex = arrow:CreateTexture(nil, "ARTWORK")
        tex:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
        tex:SetSize(13, 13)
        tex:SetPoint("CENTER", 0, -2)
        arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        local smenu = CreateFrame("Frame", nil, arrow, "BackdropTemplate")
        arrow.menu = smenu
        smenu:SetSize(150, #SCHOOL_ORDER * 22 + 10)
        smenu:SetPoint("TOPLEFT", arrow, "BOTTOMLEFT", -4, -2)
        smenu:SetFrameStrata("TOOLTIP")
        smenu:SetFrameLevel(win:GetFrameLevel() + 30)
        smenu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        smenu:SetBackdropColor(0.055, 0.05, 0.043, 0.99)
        smenu:SetBackdropBorderColor(0.57, 0.43, 0.20, 1)
        smenu:Hide()
        arrow.options = {}
        for i, value in ipairs(SCHOOL_ORDER) do
            local option = CreateFrame("Button", nil, smenu)
            option:SetPoint("TOPLEFT", 6, -5 - (i - 1) * 22)
            option:SetPoint("TOPRIGHT", -6, -5 - (i - 1) * 22)
            option:SetHeight(21)
            option:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            option.fdjSchool = value
            option.box = option:CreateTexture(nil, "ARTWORK")
            option.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
            option.box:SetSize(18, 18)
            option.box:SetPoint("LEFT", 4, 0)
            option.check = option:CreateTexture(nil, "OVERLAY")
            option.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            option.check:SetAllPoints(option.box)
            option.check:Hide()
            option.text = option:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
            option.text:SetPoint("LEFT", option.box, "RIGHT", 4, 0)
            option.text:SetTextColor(0.95, 0.83, 0.53)
            option:SetScript("OnClick", function(self)
                local db = Settings()
                db.schools[self.fdjSchool] = not db.schools[self.fdjSchool] or nil
                if next(db.schools) then db.stats.SPELL = true end
                RefreshWindow(frame)
                Changed(frame)
            end)
            arrow.options[#arrow.options + 1] = option
        end
        arrow:SetScript("OnClick", function()
            if win.armor and win.armor.menu then win.armor.menu:Hide() end
            if win.resist and win.resist.menu then win.resist.menu:Hide() end
            if win.weapon and win.weapon.menu then win.weapon.menu:Hide() end
            smenu:SetShown(not smenu:IsShown())
        end)
        arrow:SetScript("OnHide", function() smenu:Hide() end)
        arrow:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L("LF_SCHOOLS"), 1, 0.82, 0.27)
            GameTooltip:Show()
            GameTooltip:SetFrameLevel(win:GetFrameLevel() + 40)
        end)
        arrow:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end

    win.matchAll = MakeCheck(win, frame, function() return Settings().matchAll end, function(v) Settings().matchAll = v end)
    win.matchAll:SetPoint("TOPLEFT", win.minLabel, "BOTTOMLEFT", -6, -16 - 34 - math.ceil(#STATS / 2) * 28 - 6)
    win.checks[#win.checks + 1] = win.matchAll
    -- questrewards (2.0.10): Show results lists matching quest rewards too
    win.questRewards = MakeCheck(win, frame, function() return Settings().questRewards end, function(v) Settings().questRewards = v or nil end)
    win.questRewards:SetPoint("TOPLEFT", win.matchAll, "BOTTOMLEFT", 0, -4)
    win.checks[#win.checks + 1] = win.questRewards

    -- Resistance drop-down, built like the armor one, right under it.
    -- Ticked schools: the item needs at least one of them.
    if RESIST_FILTER then
        local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
        FDJ.OwnFonts(b) -- ownfonts (2.0.8)
        win.resist = b
        b:SetSize(116, 22)
        b:SetPoint("LEFT", win.weapon or win.armor, "RIGHT", 4, 0)
        b:SetText("")
        b.icon = b:CreateTexture(nil, "OVERLAY")
        b.icon:SetSize(16, 16)
        b.icon:SetPoint("LEFT", b, "LEFT", 7, 0)
        b.icon:SetTexture("Interface\\Icons\\Spell_FireResistanceTotem_01")
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local arrow = b:CreateTexture(nil, "OVERLAY")
        arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
        arrow:SetSize(12, 12)
        arrow:SetPoint("RIGHT", b, "RIGHT", -7, -3)
        b.text = b:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
        b.text:SetPoint("RIGHT", arrow, "LEFT", -2, 3)
        b.text:SetJustifyH("CENTER")
        b.text:SetWordWrap(false)

        local rmenu = CreateFrame("Frame", nil, b, "BackdropTemplate")
        b.menu = rmenu
        local rchoices = { "FIRE", "FROST", "NATURE", "SHADOW", "ARCANE" }
        rmenu:SetSize(150, #rchoices * 22 + 10)
        rmenu:SetPoint("TOPLEFT", b, "BOTTOMLEFT", -4, -4)
        rmenu:SetFrameStrata("TOOLTIP")
        rmenu:SetFrameLevel(win:GetFrameLevel() + 30)
        rmenu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        rmenu:SetBackdropColor(0.055, 0.05, 0.043, 0.99)
        rmenu:SetBackdropBorderColor(0.57, 0.43, 0.20, 1)
        rmenu:Hide()
        b.options = {}
        for i, value in ipairs(rchoices) do
            local option = CreateFrame("Button", nil, rmenu)
            option:SetPoint("TOPLEFT", 6, -5 - (i - 1) * 22)
            option:SetPoint("TOPRIGHT", -6, -5 - (i - 1) * 22)
            option:SetHeight(21)
            option:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            option.fdjResist = value or nil
            option.box = option:CreateTexture(nil, "ARTWORK")
            option.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
            option.box:SetSize(18, 18)
            option.box:SetPoint("LEFT", 4, 0)
            option.check = option:CreateTexture(nil, "OVERLAY")
            option.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            option.check:SetAllPoints(option.box)
            option.check:Hide()
            option.text = option:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
            option.text:SetPoint("LEFT", option.box, "RIGHT", 4, 0)
            option.text:SetTextColor(0.95, 0.83, 0.53)
            option:SetScript("OnClick", function(self)
                local s = Settings()
                s.resists[self.fdjResist] = not s.resists[self.fdjResist] or nil
                RefreshWindow(frame)
                Changed(frame)
            end)
            b.options[#b.options + 1] = option
        end
        b:SetScript("OnClick", function()
            if win.armor and win.armor.menu then win.armor.menu:Hide() end
            if win.weapon and win.weapon.menu then win.weapon.menu:Hide() end
            rmenu:SetShown(not rmenu:IsShown())
        end)
        b:SetScript("OnHide", function() rmenu:Hide() end)
        b:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L("LF_RESIST"), 1, 0.82, 0.27)
            GameTooltip:Show()
            GameTooltip:SetFrameLevel(win:GetFrameLevel() + 40)
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end

    -- Fit the window to its content: the bottom buttons sit a fixed gap
    -- under "Item must have all ticked stats" ("Show quest rewards too").
    win:SetScript("OnShow", function(self)
        local last = self.questRewards or self.matchAll
        local top, bottom = self:GetTop(), last and last:GetBottom()
        if top and bottom then self:SetHeight(math.floor(top - bottom + 0.5) + 70) end
    end)

    win.clear = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    FDJ.OwnFonts(win.clear) -- ownfonts (2.0.8)
    win.clear:SetSize(110, 22)
    win.clear:SetPoint("BOTTOMRIGHT", -16, 14)

    win.ok = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    FDJ.OwnFonts(win.ok) -- ownfonts (2.0.8)
    win.ok:SetSize(90, 22)
    win.ok:SetPoint("BOTTOM", 14, 14)
    win.ok:SetScript("OnClick", function() win:Hide() end)

    win.show = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    FDJ.OwnFonts(win.show) -- ownfonts (2.0.8)
    win.show:SetSize(130, 22)
    win.show:SetPoint("BOTTOMLEFT", 16, 14)
    -- The game's loot-pouch cursor icon.
    win.show.icon = win.show:CreateTexture(nil, "OVERLAY")
    win.show.icon:SetSize(22, 22)
    win.show.icon:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\LootBags")
    win.show:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L("LF_SHOW"), 1, 0.82, 0.27)
        GameTooltip:AddLine(L("LF_SHOW_TIP"), 1, 1, 1, true)
        GameTooltip:Show()
        GameTooltip:SetFrameLevel(win:GetFrameLevel() + 40)
    end)
    win.show:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    win.show:SetScript("OnClick", function()
        win:Hide()
        FDJ.ShowLootFilterResults(frame)
    end)
    win.clear:SetScript("OnClick", function()
        local s = Settings()
        s.classOnly = false
        s.stats = {}
        s.minLevel = nil
        s.maxLevel = nil -- levelrange
        s.armorTypes = {}
        s.weaponTypes = {}
        s.resists = {}
        s.schools = {}
        if frame.lootFilterWindow and frame.lootFilterWindow.minBox then frame.lootFilterWindow.minBox:SetText("") end
        if frame.lootFilterWindow and frame.lootFilterWindow.maxBox then frame.lootFilterWindow.maxBox:SetText("") end
        RefreshWindow(frame)
        Changed(frame)
    end)

    win:Hide()
    return win
end

function FDJ.ToggleLootFilterWindow(frame)
    local win = frame.lootFilterWindow or CreateWindow(frame)
    if win:IsShown() then
        win:Hide()
    else
        RefreshWindow(frame)
        win:Show()
        win:SetFrameStrata("TOOLTIP")
        win:SetFrameLevel(200)
        if win.Raise then win:Raise() end
    end
end

-- Called by the journal when it builds the home page.
function FDJ.CreateLootFilterButton(frame, home, anchorButton)
    local button = CreateFrame("Button", nil, home, "BackdropTemplate")
    frame.lootFilterButton = button
    button:SetSize(118, 28)
    button:SetPoint("RIGHT", anchorButton, "LEFT", -8, 0)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    button:SetBackdropColor(0.12, 0.115, 0.105, 0.98)
    button:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    local text = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    frame.lootFilterButtonText = text
    text:SetPoint("CENTER", 0, 0)
    text:SetTextColor(1.00, 0.82, 0.27)
    button:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
        FDJ.ToggleLootFilterWindow(frame)
    end)

    UpdateButton(frame)
end

function FDJ.RelocalizeLootFilter(frame)
    UpdateButton(frame)
    if frame and frame.lootFilterWindow and frame.lootFilterWindow:IsShown() then RefreshWindow(frame) end
end

-- ---------------------------------------------------------------- results
-- "Show": one scrolling list of every boss, across all dungeons, that drops
-- something matching the current filter.
local ROW_HEIGHT = { dungeon = 30, boss = 24, item = 36 }

local function QualityColor(quality)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function ItemIconTexture(itemID)
    if C_Item and type(C_Item.GetItemIconByID) == "function" then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok and icon then return icon end
    end
    if type(GetItemIcon) == "function" then
        local ok, icon = pcall(GetItemIcon, itemID)
        if ok and icon then return icon end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function InsertTooltipLineBeforeRequiredLevel(tooltip, text, r, g, b)
    if not tooltip or not text or text == "" or not tooltip.GetName or not tooltip.NumLines then return false end
    local tipName = tooltip:GetName()
    if not tipName or tipName == "" then return false end

    local requiredNeedle = tostring(_G.ITEM_MIN_LEVEL or "Requires Level %d")
    requiredNeedle = requiredNeedle:gsub("%%d", ""):gsub("%%s", "")
    requiredNeedle = requiredNeedle:gsub("^%s+", ""):gsub("%s+$", "")

    local lineCount = tooltip:NumLines() or 0
    local requiredIndex
    for i = 1, lineCount do
        local left = _G[tipName .. "TextLeft" .. i]
        local lineText = left and left:GetText()
        if type(lineText) == "string" and requiredNeedle ~= "" and lineText:find(requiredNeedle, 1, true) then
            requiredIndex = i
            break
        end
    end
    if not requiredIndex then return false end

    tooltip:AddLine(" ")
    for i = lineCount, requiredIndex, -1 do
        local srcL = _G[tipName .. "TextLeft" .. i]
        local srcR = _G[tipName .. "TextRight" .. i]
        local dstL = _G[tipName .. "TextLeft" .. (i + 1)]
        local dstR = _G[tipName .. "TextRight" .. (i + 1)]
        if srcL and dstL then
            dstL:SetText(srcL:GetText() or "")
            local cr, cg, cb, ca = srcL:GetTextColor()
            dstL:SetTextColor(cr or 1, cg or 1, cb or 1, ca or 1)
        end
        if srcR and dstR then
            dstR:SetText(srcR:GetText() or "")
            local cr, cg, cb, ca = srcR:GetTextColor()
            dstR:SetTextColor(cr or 1, cg or 1, cb or 1, ca or 1)
        end
    end

    local targetL = _G[tipName .. "TextLeft" .. requiredIndex]
    local targetR = _G[tipName .. "TextRight" .. requiredIndex]
    if targetL then
        targetL:SetText(text)
        targetL:SetTextColor(r or 0.10, g or 1.00, b or 0.10, 1)
    end
    if targetR then targetR:SetText("") end
    return true
end

local function MakeResultRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 26, 0)
    row.text = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    row.text:SetJustifyH("LEFT")
    row.sub = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    row.sub:SetPoint("RIGHT", -10, 0)
    row.sub:SetJustifyH("RIGHT")
    row.sub:SetTextColor(0.72, 0.67, 0.58)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetScript("OnEnter", function(self)
        if self.kind ~= "item" or not self.item or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.item[1] and self.item[1] > 0 then
            GameTooltip:SetHyperlink("item:" .. self.item[1])
            if FDJ.AddUnseenItemHint then FDJ.AddUnseenItemHint(GameTooltip) end
        else
            GameTooltip:SetText(self.item[2] or "", QualityColor(self.item[4]))
            if FDJ.AddItemTipLines then FDJ.AddItemTipLines(GameTooltip, self.item) end -- kroldok
        end
        if type(self.item[6]) == "string" and self.item[6] ~= "" then
            local statText = L(self.item[6])
            if not InsertTooltipLineBeforeRequiredLevel(GameTooltip, statText, 0.10, 1.00, 0.10) then
                GameTooltip:AddLine(statText, 0.10, 1.00, 0.10, true)
            end
        end
        if type(self.item[5]) == "string" and self.item[5] ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(self.item[5], 1.00, 0.82, 0.10, true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    row:SetScript("OnClick", function(self)
        if self.kind == "dungeon" or not self.dungeonName then return end
        local panel = self.fdjPanel
        if panel then panel:Hide() end
        if FDJ.OpenBossPage then FDJ.OpenBossPage(self.dungeonName, self.bossIndex) end
    end)
    return row
end

local function CollectResults()
    local list, itemCount = {}, 0
    FDJ.lootFilterStrict = true
    for _, dungeonName in ipairs(FDJ.ORDER or {}) do
        local dungeon = FDJ.DB and FDJ.DB[dungeonName]
        if FDJ.IsDungeonLocked and FDJ.IsDungeonLocked(dungeonName) then dungeon = nil end
        local dungeonAdded = false
        for bossIndex, boss in ipairs((dungeon and dungeon.bosses) or {}) do
            local shown = FDJ.FilterBossLoot(boss).loot or {}
            if #shown > 0 then
                if not dungeonAdded then
                    list[#list + 1] = { kind = "dungeon", dungeonName = dungeonName }
                    dungeonAdded = true
                end
                list[#list + 1] = { kind = "boss", dungeonName = dungeonName, bossIndex = bossIndex, boss = boss }
                for _, item in ipairs(shown) do
                    list[#list + 1] = { kind = "item", dungeonName = dungeonName, bossIndex = bossIndex, item = item }
                    itemCount = itemCount + 1
                end
            end
        end
    end
    FDJ.lootFilterStrict = nil
    FDJ.lootFilterHidden = 0
    return list, itemCount
end

function FDJ.RefreshLootFilterResults(frame)
    local panel = frame and frame.lootFilterResults
    if not panel then return end
    -- Only used for the empty state now: when items match, the Show page
    -- (boss list + loot) opens instead of this flat list.
    local list, itemCount = {}, 0
    panel.title:SetText(L("LF_RESULTS"))
    local bar = rawget(panel.scroll, "ScrollBar") or _G["ForeverDungeonJournalLootFilterResultsScrollScrollBar"]
    if type(bar) == "table" and bar.Hide then bar:Hide() end
    panel.back:SetText(L("LF_BACK"))
    panel.filter:SetText(L("LOOT_FILTER"))
    panel.empty:SetText(L("LF_NO_RESULTS"))
    panel.empty:SetShown(itemCount == 0)
    local width = math.max(200, (panel.scroll:GetWidth() or 700) - 4)
    panel.content:SetWidth(width)
    local y = 0
    for i, entry in ipairs(list) do
        local row = panel.rows[i]
        if not row then
            row = MakeResultRow(panel.content)
            row.fdjPanel = panel
            panel.rows[i] = row
        end
        row.kind, row.item, row.dungeonName, row.bossIndex = entry.kind, entry.item, entry.dungeonName, entry.bossIndex
        local height = ROW_HEIGHT[entry.kind]
        row:SetSize(width, height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -y)
        row.text:ClearAllPoints()
        row.sub:SetText("")
        if entry.kind == "dungeon" then
            y = y + 8
            row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -y)
            row.icon:Hide()
            row.bg:SetColorTexture(0.30, 0.22, 0.10, 0.85)
            row.text:SetFontObject("ForeverDJ_GameFontNormalLarge")
            row.text:SetPoint("LEFT", 8, 0)
            row.text:SetText(FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(entry.dungeonName) or entry.dungeonName)
            row.text:SetTextColor(1.00, 0.82, 0.27)
        elseif entry.kind == "boss" then
            row.icon:Hide()
            row.bg:SetColorTexture(0.16, 0.14, 0.11, 0.85)
            row.text:SetFontObject("ForeverDJ_GameFontNormal")
            row.text:SetPoint("LEFT", 16, 0)
            row.text:SetText(FDJ.LocalizeBossName and FDJ.LocalizeBossName(entry.boss.name) or entry.boss.name)
            row.text:SetTextColor(0.95, 0.90, 0.78)
        else
            local item = entry.item
            row.icon:SetTexture(ItemIconTexture(item[1]))
            row.icon:Show()
            row.bg:SetColorTexture(0.08, 0.07, 0.06, 0.60)
            row.text:SetFontObject("ForeverDJ_GameFontHighlight")
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
            local name
            if type(GetItemInfo) == "function" and item[1] and item[1] > 0 then
                local ok, liveName = pcall(GetItemInfo, item[1])
                if ok and type(liveName) == "string" then name = liveName end
            end
            row.text:SetText(name or item[2] or "")
            row.text:SetTextColor(QualityColor(item[4]))
            row.sub:SetText(FDJ.LocalizeItemSlot and FDJ.LocalizeItemSlot(item[3]) or (item[3] or ""))
        end
        row:Show()
        y = y + height + 2
    end
    for i = #list + 1, #panel.rows do panel.rows[i]:Hide() end
    panel.content:SetHeight(math.max(1, y))
end

FDJ.ShowLootFilterList = function(frame)
    local panel = frame.lootFilterResults
    if not panel then
        panel = CreateFrame("Frame", "ForeverDungeonJournalLootFilterResults", frame, "BackdropTemplate")
        frame.lootFilterResults = panel
        panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -44)
        panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
        panel:SetFrameStrata("FULLSCREEN_DIALOG")
        panel:SetFrameLevel(50)
        panel:EnableMouse(true)
        panel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        panel:SetBackdropColor(0.10, 0.08, 0.06, 1)
        panel:SetBackdropBorderColor(0.62, 0.50, 0.30, 1)

        panel.title = panel:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
        panel.title:SetPoint("TOPLEFT", 16, -16)
        panel.title:SetTextColor(1.00, 0.82, 0.27)

        panel.back = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        FDJ.OwnFonts(panel.back) -- ownfonts (2.0.8)
        panel.back:SetSize(100, 22)
        panel.back:SetPoint("TOPRIGHT", -14, -12)
        panel.back:SetScript("OnClick", function() panel:Hide() end)

        panel.filter = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        FDJ.OwnFonts(panel.filter) -- ownfonts (2.0.8)
        panel.filter:SetSize(120, 22)
        panel.filter:SetPoint("RIGHT", panel.back, "LEFT", -8, 0)
        panel.filter:SetScript("OnClick", function() FDJ.ToggleLootFilterWindow(frame) end)

        panel.scroll = CreateFrame("ScrollFrame", "ForeverDungeonJournalLootFilterResultsScroll", panel, "UIPanelScrollFrameTemplate")
        panel.scroll:SetPoint("TOPLEFT", 12, -46)
        panel.scroll:SetPoint("BOTTOMRIGHT", -32, 12)
        panel.content = CreateFrame("Frame", nil, panel.scroll)
        panel.content:SetSize(700, 1)
        panel.scroll:SetScrollChild(panel.content)

        panel.empty = panel:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightLarge")
        panel.empty:SetPoint("CENTER", 0, 0)
        panel.empty:SetTextColor(0.72, 0.67, 0.58)
        panel.rows = {}

        -- Item data arrives asynchronously: redraw shortly after it does.
        local watcher = CreateFrame("Frame")
        watcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        watcher:SetScript("OnEvent", function()
            if not panel:IsShown() or panel.fdjPending then return end
            panel.fdjPending = true
            local function redraw()
                panel.fdjPending = nil
                if panel:IsShown() then FDJ.ShowLootFilterResults(frame) end
            end
            if C_Timer and C_Timer.After then C_Timer.After(0.5, redraw) else redraw() end
        end)
        frame:HookScript("OnHide", function() panel:Hide() end)
    end
    panel:Show()
    if panel.scroll.SetVerticalScroll then panel.scroll:SetVerticalScroll(0) end
    FDJ.RefreshLootFilterResults(frame)
end

-- The Show page reuses the normal dungeon page: a temporary "dungeon" whose
-- boss list is every boss, from every dungeon, with loot matching the filter.
local PAGE_KEY = "Loot Filter Results"
FDJ.LOOT_FILTER_PAGE = PAGE_KEY

local baseLocalizeDungeonName = FDJ.LocalizeDungeonName
FDJ.LocalizeDungeonName = function(internalName)
    if internalName == PAGE_KEY then return L("LF_RESULTS") end
    return baseLocalizeDungeonName(internalName)
end

-- questrewards (2.0.10, M 17 Nov 2026: "under Item must have all stats, an
-- option to toggle that says: Show quest rewards too"): with it ticked, Show
-- results also lists the dungeons' quests whose rewards match the filter,
-- each after its dungeon's bosses: the quest's name with a note icon, its
-- matching rewards as the loot. The quests are the dungeon's quest list's
-- (this character's faction; class and profession quests as the Quests
-- options say; RPG Mode: only quests it shows). The quest data has no slot
-- for its rewards, so it is read from the game's item data.
local REWARD_EQUIP = {
    INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulder", INVTYPE_BODY = "Shirt",
    INVTYPE_CHEST = "Chest", INVTYPE_ROBE = "Chest", INVTYPE_WAIST = "Waist", INVTYPE_LEGS = "Legs",
    INVTYPE_FEET = "Feet", INVTYPE_WRIST = "Wrist", INVTYPE_HAND = "Hands", INVTYPE_FINGER = "Finger",
    INVTYPE_TRINKET = "Trinket", INVTYPE_CLOAK = "Back", INVTYPE_WEAPON = "One-Hand", INVTYPE_SHIELD = "Off Hand",
    INVTYPE_2HWEAPON = "Two-Hand", INVTYPE_WEAPONMAINHAND = "Main Hand", INVTYPE_WEAPONOFFHAND = "Off Hand",
    INVTYPE_HOLDABLE = "Held In Off-hand", INVTYPE_RANGED = "Ranged", INVTYPE_RANGEDRIGHT = "Ranged",
    INVTYPE_THROWN = "Thrown", INVTYPE_TABARD = "Tabard", INVTYPE_RELIC = "Relic",
}
local REWARD_KIND = {
    [4] = { [1] = "Cloth", [2] = "Leather", [3] = "Mail", [4] = "Plate", [6] = "Shield" },
    [2] = { [0] = "Axe", [1] = "Axe", [2] = "Bow", [3] = "Gun", [4] = "Mace", [5] = "Mace", [6] = "Polearm",
        [7] = "Sword", [8] = "Sword", [10] = "Staff", [13] = "Fist Weapon", [15] = "Dagger", [18] = "Crossbow", [19] = "Wand" },
}
local QUEST_REWARD_ICON = "Interface\\GossipFrame\\AvailableQuestIcon" -- resultquest: the quest pages' "!"
-- "Head, Plate", "Two-Hand, Sword", "Finger"... as in the loot data; "" when
-- not gear or not known yet.
local function RewardSlot(id)
    local equipLoc, classID, subID
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(instant) == "function" then
        local ok, _, _, _, loc, _, cid, sid = pcall(instant, id)
        if ok then equipLoc, classID, subID = loc, cid, sid end
    end
    if not equipLoc and type(GetItemInfo) == "function" then
        local ok, _, _, _, _, _, _, _, _, loc, _, _, cid, sid = pcall(GetItemInfo, id)
        if ok then equipLoc, classID, subID = loc, cid, sid end
    end
    local first = REWARD_EQUIP[equipLoc or ""]
    if not first then return "" end
    local kind
    if first == "Back" then
        kind = "Cloth"
    elseif first ~= "Thrown" and REWARD_KIND[classID] then
        kind = REWARD_KIND[classID][subID]
    end
    return kind and (first .. ", " .. kind) or first
end
local function QuestRewardIDs(quest, add)
    local lists = { quest.rewardItems, quest.additionalRewardItems, quest.noteRewardItems }
    for i = 1, 3 do
        local list = lists[i]
        for _, reward in ipairs(type(list) == "table" and list or {}) do
            local id = type(reward) == "table" and tonumber(reward[1])
            if id and id > 0 then add(id, reward) end
        end
    end
end
local function QuestRewardsShown(dungeonName, quest)
    if type(quest) ~= "table" or quest.hideFromMainList then return false end
    if FDJ.QuestMatchesFaction and not FDJ.QuestMatchesFaction(quest, FDJ.PlayerFaction and FDJ.PlayerFaction() or nil) then return false end
    if FDJ.RPGQuestHidden and FDJ.RPGQuestHidden(dungeonName, quest) then return false end
    return true
end
local function QuestRewardBosses(dungeonName, dungeon)
    local out = {}
    for _, quest in ipairs(dungeon.quests or {}) do
        if QuestRewardsShown(dungeonName, quest) then
            local loot, seen = {}, {}
            QuestRewardIDs(quest, function(id, reward)
                if seen[id] then return end
                seen[id] = true
                -- questlevel (2.1.2, M 21 Nov 2026): a reward counts at its
                -- quest's level too ("Available from Level 40"), not only at
                -- the item's (most rewards need no level of their own).
                loot[#loot + 1] = { id, reward[2], RewardSlot(id), tonumber(reward[3]) or 1, fdjQuestLevel = tonumber(quest.requires) }
            end)
            if #loot > 0 then
                local title = quest.name or ""
                if FDJ.LocalizeQuestField and quest.id then title = FDJ.LocalizeQuestField(quest.id, "name", title) or title end
                local icon = QUEST_REWARD_ICON
                if quest.id and FDJ.IsRepeatableQuest and FDJ.IsRepeatableQuest(quest.id) and FDJ.REPEATABLE_QUEST_TEXTURE then
                    icon = FDJ.REPEATABLE_QUEST_TEXTURE -- the blue ? of a repeatable quest, as in the quest list
                end
                out[#out + 1] = { name = title, loot = loot, customIcon = icon, fdjQuestRewards = quest.id or true, fdjQuest = quest }
            end
        end
    end
    return out
end

-- resultquest (2.0.10, M 17 Nov 2026: "clicking on the exclamation mark
-- should redirect to the official quest page in the dungeon"): the "!" of a
-- quest entry in the page's list opens the quest on its dungeon's Quests
-- tab; a click on the rest of the row shows the quest on the right.
function FDJ.ApplyResultQuestMark(button, entry)
    local quest = type(entry) == "table" and rawget(entry, "fdjQuest") or nil
    local mark = button and button.fdjQuestMark
    if not (quest and button.portrait) then
        if mark then mark:Hide() end
        return
    end
    if not mark then
        mark = CreateFrame("Button", nil, button)
        button.fdjQuestMark = mark
        mark.hl = mark:CreateTexture(nil, "HIGHLIGHT")
        mark.hl:SetAllPoints()
        mark.hl:SetBlendMode("ADD")
        mark:SetScript("OnClick", function(self)
            if self.dungeonName and self.questID and FDJ.OpenQuestPage then
                FDJ.OpenQuestPage(self.dungeonName, self.questID)
            end
        end)
        mark:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.title or "", 1.00, 0.82, 0.00)
            GameTooltip:AddLine(L("BOSS_QUEST_TIP"), 0.35, 1.00, 0.35)
            GameTooltip:Show()
        end)
        mark:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    mark:ClearAllPoints()
    mark:SetAllPoints(button.portrait)
    mark:SetFrameLevel((button:GetFrameLevel() or 1) + 5)
    mark.hl:SetTexture(rawget(entry, "customIcon") or QUEST_REWARD_ICON)
    mark.dungeonName = rawget(entry, "fdjDungeon")
    mark.questID = quest.id
    mark.title = rawget(entry, "name")
    mark:Show()
end

local function BuildPage()
    local bosses, itemCount = {}, 0
    local db = Settings()
    local recipesOnly = db.enabled and db.recipes and not db.classOnly and not db.minLevel and not db.maxLevel and not AnyArmorTicked(db) and not AnyWeaponTicked(db) and not AnyResistTicked(db) and not AnyStatWanted(db)
    FDJ.lootFilterStrict = true
    for _, dungeonName in ipairs(FDJ.ORDER or {}) do
        local dungeon = FDJ.DB and FDJ.DB[dungeonName]
        if FDJ.IsDungeonLocked and FDJ.IsDungeonLocked(dungeonName) then dungeon = nil end
        for _, boss in ipairs((dungeon and dungeon.bosses) or {}) do
            -- altarbosses (2.0.24): a group's children drop what the group
            -- lists; the group is listed once, not each child again.
            local shown = (not boss.childOf) and (FDJ.FilterBossLoot(boss).loot or {}) or {}
            if recipesOnly then
                -- Only "Show recipe drops" is ticked: list the recipes alone.
                local recipes = {}
                for _, item in ipairs(shown) do
                    if IsRecipe(item) then recipes[#recipes + 1] = item end
                end
                shown = recipes
            end
            if #shown > 0 then
                bosses[#bosses + 1] = setmetatable({ loot = shown, fdjDungeon = dungeonName }, { __index = boss })
                itemCount = itemCount + #shown
            end
        end
        if dungeon and db.enabled and db.questRewards then -- questrewards
            for _, quest in ipairs(QuestRewardBosses(dungeonName, dungeon)) do
                local shown = FDJ.FilterBossLoot(quest).loot or {}
                if recipesOnly then
                    local recipes = {}
                    for _, item in ipairs(shown) do
                        if IsRecipe(item) then recipes[#recipes + 1] = item end
                    end
                    shown = recipes
                end
                if #shown > 0 then
                    quest.loot, quest.fdjDungeon = shown, dungeonName
                    bosses[#bosses + 1] = quest
                    itemCount = itemCount + #shown
                end
            end
        end
    end
    FDJ.lootFilterStrict = nil
    FDJ.lootFilterHidden = 0
    return bosses, itemCount
end

-- Read the tooltips of every loot item a few per frame, then call onDone.
local warmWorker, warmQueue, warmDone, requestedData
local warmLeft = 0 -- settle: items whose tooltip was still empty at the last read
local WARM_PER_FRAME = 8
-- fastshow (2.0.10, M 17 Nov 2026: "fix the lag when we click Show results:
-- it lasts quite a few seconds and people might think it's not working and
-- close it before it loads"). Show results first reads the tooltip of the
-- items it checks for stats, 8 a frame: every loot item of every dungeon,
-- a few seconds. Now: only the items the other filters (class, armor,
-- weapon, level) keep are read, each once; each frame reads for up to 12 ms
-- (at least 8 items); and a box on the journal says "Searching the loot...
-- 42%" with a bar, until the results open.
local WARM_BUDGET_MS = 12
local warmTotal, warmProgress = 0, nil
local function HideLoading(frame)
    if frame and frame.lootFilterLoading then frame.lootFilterLoading:Hide() end
end
local function ShowLoading(frame, done, total)
    if not (frame and CreateFrame) then return end
    local box = frame.lootFilterLoading
    if not box then
        box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.lootFilterLoading = box
        box:SetSize(300, 64)
        box:SetPoint("CENTER", frame, "CENTER", 0, 0)
        box:SetFrameStrata("FULLSCREEN_DIALOG")
        box:SetFrameLevel(90)
        box:EnableMouse(true)
        box:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        box:SetBackdropColor(0.055, 0.05, 0.043, 0.97)
        box:SetBackdropBorderColor(0.62, 0.50, 0.30, 1)
        box.text = box:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
        box.text:SetPoint("TOP", 0, -12)
        box.text:SetTextColor(1.00, 0.82, 0.27)
        box.bar = CreateFrame("StatusBar", nil, box)
        box.bar:SetPoint("BOTTOMLEFT", 16, 13)
        box.bar:SetPoint("BOTTOMRIGHT", -16, 13)
        box.bar:SetHeight(10)
        box.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        box.bar:SetStatusBarColor(0.95, 0.72, 0.20)
        box.bar.bg = box.bar:CreateTexture(nil, "BACKGROUND")
        box.bar.bg:SetAllPoints()
        box.bar.bg:SetColorTexture(0, 0, 0, 0.6)
        frame:HookScript("OnHide", function() box:Hide() end)
    end
    total = math.max(1, total or 1)
    local pct = math.floor(100 * math.min(done or 0, total) / total)
    box.text:SetText(L("LF_SEARCHING", pct))
    box.bar:SetMinMaxValues(0, total)
    box.bar:SetValue(math.min(done or 0, total))
    box:Show()
end
local function WarmTooltips(onDone, progress)
    -- a read the player is watching is never cut short by a quiet one
    -- (an item's data arriving); it builds the results itself when done
    if warmQueue and warmProgress and not progress then return end
    if warmProgress and warmProgress ~= progress then HideLoading(warmProgress) end
    warmProgress = progress
    local queue, seen = {}, {}
    local function Add(id)
        if id and id > 0 and not seen[id] and not textCache[id] then
            seen[id] = true
            queue[#queue + 1] = id
        end
    end
    local hidden, dimmed = FDJ.lootFilterHidden, FDJ.lootFilterDimmed
    local filterOn = Settings().enabled
    FDJ.lootFilterSkipStats = true
    for _, dungeonName in ipairs(FDJ.ORDER or {}) do
        local dungeon = FDJ.DB and FDJ.DB[dungeonName]
        if FDJ.IsDungeonLocked and FDJ.IsDungeonLocked(dungeonName) then dungeon = nil end
        for _, boss in ipairs((dungeon and dungeon.bosses) or {}) do
            local list = boss.loot or {}
            if filterOn and not boss.childOf then
                local ok, kept = pcall(FDJ.FilterBossLoot, boss)
                if ok and type(kept) == "table" and type(kept.loot) == "table" then list = kept.loot end
            end
            if not boss.childOf then
                for _, item in ipairs(list) do
                    if not IsRecipe(item) then Add(item[1]) end
                end
            end
        end
        if dungeon and filterOn and Settings().questRewards then -- questrewards
            for _, quest in ipairs(QuestRewardBosses(dungeonName, dungeon)) do
                local ok, kept = pcall(FDJ.FilterBossLoot, quest)
                for _, item in ipairs((ok and type(kept) == "table" and kept.loot) or quest.loot) do
                    if not IsRecipe(item) then Add(item[1]) end
                end
            end
        end
    end
    FDJ.lootFilterSkipStats = nil
    FDJ.lootFilterHidden, FDJ.lootFilterDimmed = hidden, dimmed
    warmDone = onDone
    warmLeft = 0
    warmTotal = #queue
    if #queue == 0 or not CreateFrame then
        warmQueue = nil
        if warmProgress then HideLoading(warmProgress) warmProgress = nil end
        if onDone then onDone() end
        return
    end
    warmQueue = queue
    if warmProgress then ShowLoading(warmProgress, 0, warmTotal) end
    if not warmWorker then
        warmWorker = CreateFrame("Frame")
        warmWorker:SetScript("OnUpdate", function(self)
            local q = warmQueue
            if not q then self:Hide() return end
            local clock = type(debugprofilestop) == "function" and debugprofilestop or nil
            local start = clock and clock() or 0
            local n = 0
            while true do
                local id = table.remove(q)
                if not id then break end
                if not requestedData and C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
                    pcall(C_Item.RequestLoadItemDataByID, id)
                end
                if not TooltipText(id) then warmLeft = warmLeft + 1 end -- settle
                n = n + 1
                if n >= WARM_PER_FRAME and (not clock or clock() - start >= WARM_BUDGET_MS) then break end
            end
            if warmProgress then ShowLoading(warmProgress, warmTotal - #q, warmTotal) end
            if #q == 0 then
                warmQueue = nil
                requestedData = true
                self:Hide()
                if warmProgress then HideLoading(warmProgress) warmProgress = nil end
                local done = warmDone
                warmDone = nil
                if done then done() end
            end
        end)
    end
    warmWorker:Show()
end

local OpenLootFilterPage
function FDJ.ShowLootFilterResults(frame, keepBoss)
    if Settings().enabled and (AnyStatWanted(Settings()) or AnyResistTicked(Settings())) then
        WarmTooltips(function() OpenLootFilterPage(frame, keepBoss) end, frame) -- fastshow: with the box
    else
        OpenLootFilterPage(frame, keepBoss)
    end
end

OpenLootFilterPage = function(frame, keepBoss)
    if not (frame and frame:IsShown()) then return end
    local bosses, itemCount = BuildPage()
    if #bosses == 0 then
        FDJ.ShowLootFilterList(frame) -- shows the "no items match" message
        if FDJ.SettleLootFilterResults then FDJ.SettleLootFilterResults(frame) end -- settle
        return
    end
    if frame.lootFilterResults then frame.lootFilterResults:Hide() end
    local previous = ForeverDungeonJournalDB and ForeverDungeonJournalDB.lastDungeon
    FDJ.DB[PAGE_KEY] = {
        level = "",
        location = "",
        description = "",
        quests = {},
        bosses = bosses,
        fdjItemCount = itemCount,
        lootFilterPage = true, -- no Quests/Map tabs, larger centred title
    }
    if FDJ.OpenBossPage then
        local index = 1
        if keepBoss and keepBoss.name then
            for i, b in ipairs(bosses) do
                if b.name == keepBoss.name and b.fdjDungeon == keepBoss.fdjDungeon then index = i end
            end
        end
        FDJ.OpenBossPage(PAGE_KEY, index)
    end
    -- Never remember the temporary page as the last real dungeon.
    if ForeverDungeonJournalDB then
        if previous == PAGE_KEY then previous = nil end
        ForeverDungeonJournalDB.lastDungeon = previous or (FDJ.ORDER and FDJ.ORDER[1])
        ForeverDungeonJournalDB.lastBoss = 1
    end
    if FDJ.SettleLootFilterResults then FDJ.SettleLootFilterResults(frame) end -- settle
end

local function PageIsOpen(frame)
    if not (frame and frame:IsShown() and FDJ.GetSelectedDungeon) then return false end
    return FDJ.GetSelectedDungeon() == PAGE_KEY and frame.currentView ~= "home"
end

local function RebuildOpenPage(frame)
    if not PageIsOpen(frame) then return end
    local page = FDJ.DB[PAGE_KEY]
    local _, bossIndex = FDJ.GetSelectedDungeon()
    FDJ.ShowLootFilterResults(frame, page and page.bosses and page.bosses[bossIndex])
end
FDJ.RebuildLootFilterPage = RebuildOpenPage

-- settle (1.9.3): an item the game had not loaded yet when the results were
-- built (its tooltip still empty) cannot be checked, so it is left out. Its
-- data usually came in while the other tooltips were still being read, and
-- the page, not open yet, missed the news: the item only showed at the next
-- Show results (Old Serra'kis' Glowing Thresher Cape). Now such items are
-- read again a second later, up to 5 times, and the results are built again
-- when the count of matching items changes.
local settleToken, SETTLE_TRIES = 0, 5
function FDJ.SettleLootFilterResults(frame, tries)
    if not (C_Timer and type(C_Timer.After) == "function") then return end
    if not tries then
        settleToken = settleToken + 1
        tries = 0
    end
    if warmLeft == 0 or tries >= SETTLE_TRIES then return end
    local token = settleToken
    local panel = frame and frame.lootFilterResults
    local function Showing()
        return PageIsOpen(frame) or (panel ~= nil and panel:IsShown())
    end
    C_Timer.After(1, function()
        if token ~= settleToken or not Showing() then return end
        WarmTooltips(function()
            if token ~= settleToken or not Showing() then return end
            local open = PageIsOpen(frame)
            local _, count = BuildPage()
            local page = FDJ.DB[PAGE_KEY]
            local before = (open and page and page.fdjItemCount) or 0
            if count ~= before then
                if open then RebuildOpenPage(frame) else FDJ.ShowLootFilterResults(frame) end
            else
                FDJ.SettleLootFilterResults(frame, tries + 1)
            end
        end)
    end)
end

-- Item data arrives asynchronously; pick up items that could not be checked yet.
local pageWatcher = CreateFrame and CreateFrame("Frame")
if pageWatcher then
    pageWatcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    pageWatcher:SetScript("OnEvent", function(self)
        local frame = _G.ForeverDungeonJournalFrame
        if self.pending or not PageIsOpen(frame) then return end
        self.pending = true
        local function check()
            self.pending = nil
            if not PageIsOpen(frame) or not (AnyStatWanted(Settings()) or AnyResistTicked(Settings())) then return end
            WarmTooltips(function()
                if not PageIsOpen(frame) then return end
                local _, count = BuildPage()
                local page = FDJ.DB[PAGE_KEY]
                if page and count ~= page.fdjItemCount then RebuildOpenPage(frame) end
            end)
        end
        if C_Timer and C_Timer.After then C_Timer.After(1, check) else check() end
    end)
end

-- ------------------------------------------------- trash mob portraits
-- On a Trash Drops row, the mobs that drop the item are drawn as small
-- portraits on the right; hovering one shows its name. Returns true when the
-- portraits replace the source text (every named mob has a known portrait).
-- The mobs a row's source names, when every one of them has a portrait
-- (else none: the row keeps the names as text).
function FDJ.RowMobNames(sourceText)
    local names = {}
    if type(sourceText) == "string" and FDJ.TRASH_MOB_DISPLAY_IDS and type(SetPortraitTextureFromCreatureDisplayID) == "function" then
        for name in (sourceText .. " / "):gmatch("(.-) / ") do
            name = name:gsub("^%s+", ""):gsub("%s+$", "")
            if name ~= "" then
                if not FDJ.TRASH_MOB_DISPLAY_IDS[name]
                    and not (FDJ.TRASH_MOB_NPC_IDS and FDJ.TRASH_MOB_NPC_IDS[name]) then return {} end
                names[#names + 1] = name
            end
        end
    end
    return names
end

-- moborder (2.0.25; 2.0.24 gave each mob a fixed column, which left gaps):
-- rows stay packed to the right, but the mobs keep one order across the
-- page: the mob on the most rows rightmost, then the next, and so on (ties:
-- the one met first). (The 2.0.25 hover glow across rows went in 2.0.26.)
function FDJ.PlanMobSlots(loot)
    FDJ.mobSlots = nil
    if type(loot) ~= "table" then return end
    local count, first, order = {}, {}, {}
    for index, item in ipairs(loot) do
        for at, name in ipairs(FDJ.RowMobNames(type(item) == "table" and item[5] or nil)) do
            if not count[name] then
                count[name], first[name] = 0, index * 100 + at -- ties: met first, then as written
                order[#order + 1] = name
            end
            count[name] = count[name] + 1
        end
    end
    if #order == 0 then return end
    table.sort(order, function(x, y)
        if count[x] ~= count[y] then return count[x] > count[y] end
        return first[x] < first[y]
    end)
    local rank = {}
    for i, name in ipairs(order) do rank[name] = i end
    FDJ.mobSlots = { rank = rank }
end

-- mobfast (2.0.31): the looks of trash mobs known by NPC ID only, found
-- all at once instead of one after another behind the bosses: a hidden
-- model of each NPC tells its display, which is saved with the journal's
-- other portraits (ForeverDungeonJournalDB.displayIDs), so after the first
-- time they are drawn at once. Started a few seconds after logging in and
-- again when a page shows them; a portrait waiting for one is drawn the
-- moment it is found.
FDJ.mobLooks = FDJ.mobLooks or { pending = {}, waiting = {}, models = {} }
-- loadpause (2.0.7): a few looked up at a time, not all of them at once, and
-- none during a loading screen (FDJ.LookupsPaused, Core/Journal.lua).
local LOOKS_AT_ONCE = 4
-- mobmiss (2.0.7): mobs whose look the game didn't give after every try
-- are remembered (ForeverDungeonJournalDB.displayMiss, NPC ID -> when), so
-- the lookups after logging in skip them for a week instead of trying them
-- again at every login (hidden models for minutes after each login and
-- zoning). Opening a page that shows one still tries it, and a mob found
-- later is taken off the list.
local MISS_DAYS = 7
local function MissStore()
    if type(ForeverDungeonJournalDB) ~= "table" then return nil end
    if type(ForeverDungeonJournalDB.displayMiss) ~= "table" then ForeverDungeonJournalDB.displayMiss = {} end
    return ForeverDungeonJournalDB.displayMiss
end
local function NowSeconds()
    return (GetServerTime and GetServerTime()) or (time and time()) or 0
end
function FDJ.MobRecentlyMissed(npcID)
    local store = MissStore()
    local at = store and tonumber(store[npcID])
    return at ~= nil and NowSeconds() - at < MISS_DAYS * 86400
end
function FDJ.MobDisplay(npcID)
    -- staleface (2.0.9): the looks saved before the fix may be another mob's:
    -- forgotten once, found again as the pages ask for them.
    if type(ForeverDungeonJournalDB) == "table" and not ForeverDungeonJournalDB.displayIDsFixed then
        if type(ForeverDungeonJournalDB.displayIDs) == "table" then
            for k in pairs(ForeverDungeonJournalDB.displayIDs) do ForeverDungeonJournalDB.displayIDs[k] = nil end -- in place: Core/Journal.lua holds the same table
        end
        ForeverDungeonJournalDB.displayIDsFixed = 1
    end
    local saved = type(ForeverDungeonJournalDB) == "table" and type(ForeverDungeonJournalDB.displayIDs) == "table"
        and ForeverDungeonJournalDB.displayIDs[npcID]
    return type(saved) == "number" and saved > 0 and saved or nil
end
function FDJ.DrawMobPortrait(texture, displayID)
    local okPortrait, shown = false, false
    if FDJ.AcquirePortrait then okPortrait, shown = pcall(FDJ.AcquirePortrait, texture, displayID) end
    if not (okPortrait and shown) then
        if FDJ.AcquirePortrait then
            -- rtvcap (2.0.9): the portrait pool had no room (every portrait
            -- it may draw is on screen), or the game has none for this look.
            -- It is no longer drawn straight on the row (one more render
            -- target, outside the cap, black while it loads): a plain dark
            -- disc, as for a mob not found yet; the pool puts the portrait
            -- over it once there is room (softhost).
            texture:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
            texture:SetTexCoord(0, 1, 0, 1)
            texture:SetVertexColor(0.08, 0.07, 0.06, 0.85)
            return
        elseif type(SetPortraitTextureFromCreatureDisplayID) == "function" then
            pcall(SetPortraitTextureFromCreatureDisplayID, texture, displayID)
        end
    end
    texture:SetVertexColor(1, 1, 1, 1)
end
function FDJ.ResolveMobDisplays(npcIDs)
    local looks = FDJ.mobLooks
    if type(CreateFrame) ~= "function" then return end
    local now = (GetTime and GetTime()) or 0
    for _, npcID in ipairs(npcIDs or {}) do
        if type(npcID) == "number" and not FDJ.MobDisplay(npcID) and not looks.pending[npcID] then
            looks.pending[npcID] = { tries = 0, at = now - 10 }
        end
    end
    if not next(looks.pending) then return end
    if not looks.driver then
        looks.driver = CreateFrame("Frame")
        looks.driver:SetScript("OnUpdate", function(self)
            if FDJ.portraitZoning then return end
            if FDJ.LookupsPaused and FDJ.LookupsPaused() then return end -- loadpause (2.0.7)
            -- journalopen (2.0.7): only while the journal window is open (the
            -- page that asked is on screen); closed, the hidden models are put
            -- away and the mobs not found yet are asked again when it opens.
            local journal = _G.ForeverDungeonJournalFrame
            if not (journal and journal.IsShown and journal:IsShown()) then
                if not looks.closedPause then looks.closedPause = true if FDJ.PauseMobLooks then FDJ.PauseMobLooks() end end
                return
            end
            looks.closedPause = nil
            local t = (GetTime and GetTime()) or 0
            local busy, asking = false, 0
            for _, job in pairs(looks.pending) do
                if job.tries > 0 then asking = asking + 1 end
            end
            for npcID, job in pairs(looks.pending) do
                busy = true
                -- Not asked yet, and LOOKS_AT_ONCE already asking: its turn later.
                if job.tries == 0 and asking >= LOOKS_AT_ONCE then
                    -- waits
                else
                    if job.tries == 0 then asking = asking + 1 end
                    local model = looks.models[npcID]
                    -- rtvcap (2.0.9): a hidden model whose look-up is over is
                    -- reused, not one more made for each mob.
                    if not model then
                        for otherID, other in pairs(looks.models) do
                            if not looks.pending[otherID] then
                                looks.models[otherID] = nil
                                model = other
                                break
                            end
                        end
                        if model then looks.models[npcID] = model end
                        -- staleface (2.0.9, M 16 Nov 2026: the Phase Lasher, a
                        -- flower, drawn as a tree; trees as satyrs): a reused
                        -- model tells the mob it showed last until the new one
                        -- is in, so that look is not taken at once (only if it
                        -- still says so after a few asks: two mobs may share one).
                        if model then model.fdjStale = model.fdjLastDisplay end
                    end
                    if not model then
                        local ok, made = pcall(CreateFrame, "PlayerModel", nil, UIParent)
                        if ok and made then
                            made:SetSize(1, 1)
                            made:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                            made:SetAlpha(0)
                            looks.models[npcID] = made
                            model = made
                        end
                    end
                    if not model then
                        looks.pending[npcID] = nil
                    elseif t - job.at >= 2.5 then
                        -- Ask (again): an NPC this client has not met comes in a
                        -- moment after the server answers.
                        job.tries, job.at = job.tries + 1, t
                        if job.tries > 12 then
                            looks.pending[npcID] = nil
                            model:Hide()
                            local store = MissStore() -- mobmiss (2.0.7)
                            if store then store[npcID] = NowSeconds() end
                        else
                            model:Show()
                            if model.ClearModel then pcall(model.ClearModel, model) end
                            if not pcall(model.SetCreature, model, npcID) then looks.pending[npcID] = nil end
                        end
                    else
                        local ok, display = pcall(model.GetDisplayInfo, model)
                        if ok and type(display) == "number" and display > 0
                            and not (display == model.fdjStale and job.tries < 4) then
                            model.fdjLastDisplay, model.fdjStale = display, nil
                            looks.pending[npcID] = nil
                            if type(ForeverDungeonJournalDB) == "table" then
                                ForeverDungeonJournalDB.displayIDs = ForeverDungeonJournalDB.displayIDs or {}
                                ForeverDungeonJournalDB.displayIDs[npcID] = display
                            end
                            local store = MissStore() -- mobmiss (2.0.7): found after all
                            if store then store[npcID] = nil end
                            if model.ClearModel then pcall(model.ClearModel, model) end
                            model:Hide()
                            for button in pairs(looks.waiting) do
                                if button.fdjMobNpc == npcID then
                                    looks.waiting[button] = nil
                                    FDJ.DrawMobPortrait(button.portrait, display)
                                end
                            end
                        end
                    end
                end
            end
            if not busy then self:Hide() end
        end)
    end
    looks.driver:Show()
end
-- loadpause (2.0.7): a loading screen starts: the hidden models put away;
-- the mobs not found yet are asked again a few seconds after arriving.
function FDJ.PauseMobLooks()
    local looks = FDJ.mobLooks
    for npcID, model in pairs(looks.models) do
        local job = looks.pending[npcID]
        if job then job.at = 0 end
        if model.ClearModel then pcall(model.ClearModel, model) end
        model:Hide()
    end
end
-- All of them, a few seconds after logging in (once a session).
function FDJ.WarmMobDisplays()
    if FDJ.mobLooks.warmed then return end
    FDJ.mobLooks.warmed = true
    local ids = {}
    for name, npcID in pairs(FDJ.TRASH_MOB_NPC_IDS or {}) do
        -- mobmiss (2.0.7): not the ones the game didn't give in the last week.
        -- bakelooks (2.0.9): nor the ones whose look is known now.
        if not (FDJ.TRASH_MOB_DISPLAY_IDS and FDJ.TRASH_MOB_DISPLAY_IDS[name]) and not FDJ.MobRecentlyMissed(npcID) then
            ids[#ids + 1] = npcID
        end
    end
    FDJ.ResolveMobDisplays(ids)
end
-- noinstance (2.0.7): no longer started by itself after logging in. With the
-- 38 mobs 2.0.6 added (most never met by most characters) it kept hidden
-- models busy for minutes after each login, and a loading screen in or out
-- of a dungeon could then flicker for ever. A mob is now looked up when a
-- page shows it (FDJ.SetRowMobs), outside dungeons only.

function FDJ.SetRowMobs(row, sourceText)
    row.fdjMobButtons = row.fdjMobButtons or {}
    local names = FDJ.RowMobNames(sourceText)
    local plan = FDJ.mobSlots
    -- moborder: the page's order, its first mob rightmost.
    if plan and plan.rank and #names > 1 then
        table.sort(names, function(x, y) return (plan.rank[x] or 999) < (plan.rank[y] or 999) end)
    end
    row.fdjMobSpan = 0
    for i, name in ipairs(names) do
        local button = row.fdjMobButtons[i]
        if not button then
            button = CreateFrame("Button", nil, row)
            button:SetSize(34, 34)
            button.portrait = button:CreateTexture(nil, "ARTWORK")
            button.portrait:SetAllPoints()
            button:SetScript("OnEnter", function(self)
                if not GameTooltip or not self.fdjMobName then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                -- sourcetip (2.0.9, M 16 Nov 2026): on a family's row ("All
                -- satyrs", "All trees") the portrait stands for the whole family
                local family = self:GetParent() and self:GetParent().fdjMobTip
                GameTooltip:SetText(family or (FDJ.LocalizeBossName and FDJ.LocalizeBossName(self.fdjMobName)) or self.fdjMobName, 1, 0.82, 0.27)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            row.fdjMobButtons[i] = button
        end
        button.fdjMobName = name
        button.fdjMobNpc = nil
        FDJ.mobLooks.waiting[button] = nil
        button:ClearAllPoints()
        -- moborder: packed to the right, in the page's order (no gaps); with
        -- no page order, in the source's order as before.
        local column = (plan and plan.rank) and (i - 1) or (#names - i)
        button:SetPoint("RIGHT", row, "RIGHT", -10 - column * 38, 0)
        if column + 1 > row.fdjMobSpan then row.fdjMobSpan = column + 1 end
        local mobDisplayID = FDJ.TRASH_MOB_DISPLAY_IDS[name]
        if mobDisplayID then
            -- Bundled picture, else the off-screen portrait pool like the bosses
            -- (no black square while it loads). rtvcap (2.0.9): through
            -- DrawMobPortrait, which no longer draws straight on the row
            -- when the pool has no room.
            FDJ.DrawMobPortrait(button.portrait, mobDisplayID)
        else
            -- trashnpc (2.0.22): known by NPC ID only. mobfast (2.0.31): its
            -- look saved from an earlier lookup is drawn at once; else it is
            -- looked up now (all of the page's together) and drawn the moment
            -- it is found, a plain dark disc until then (no "?").
            local npcID = FDJ.TRASH_MOB_NPC_IDS[name]
            local display = FDJ.MobDisplay(npcID)
            if display then
                FDJ.DrawMobPortrait(button.portrait, display)
            else
                if FDJ.ReleasePortrait then pcall(FDJ.ReleasePortrait, button.portrait) end
                button.portrait:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
                button.portrait:SetTexCoord(0, 1, 0, 1)
                button.portrait:SetVertexColor(0.08, 0.07, 0.06, 0.85)
                button.fdjMobNpc = npcID
                FDJ.mobLooks.waiting[button] = true
                FDJ.ResolveMobDisplays({ npcID })
            end
        end
        button:Show()
    end
    for i = #names + 1, #row.fdjMobButtons do row.fdjMobButtons[i]:Hide() end
    -- Keep the item name clear of the portraits.
    if row.name and row.name.SetPoint then
        row.name:SetPoint("RIGHT", row, "RIGHT", -10 - row.fdjMobSpan * 38, 0)
    end
    return #names > 0
end

-- lootoptions (2.0.11, M 18 Nov 2026: Options > Loot > "Hide quest item
-- drops"): boss loot pages leave out the quest items ("Quest Item" in the
-- loot tables). The boss handed to the page is a copy of the boss without
-- them (the same copy every time, so the page sees one boss); the search's
-- Matching loot page and the recipe tab are left as they are.
do
    local plain = FDJ.FilterBossLootForPage
    local copies = setmetatable({}, { __mode = "k" })
    FDJ.FilterBossLootForPage = function(boss, ...)
        if ForeverDungeonJournalDB and ForeverDungeonJournalDB.hideQuestDrops
            and type(boss) == "table" and type(boss.loot) == "table" and not boss.fdjDungeon and not boss.recipeTab then
            local copy = copies[boss]
            if copy == nil then
                local loot, cut = {}, false
                for _, item in ipairs(boss.loot) do
                    if type(item) == "table" and item[3] == "Quest Item" then cut = true else loot[#loot + 1] = item end
                end
                copy = cut and setmetatable({ loot = loot }, { __index = boss }) or false
                copies[boss] = copy
            end
            if copy then boss = copy end
        end
        return plain(boss, ...)
    end
end

-- BEGIN lootremoved
-- lootremoved (2.1.3, M 21 Nov 2026, the Obsidian Sentinel: "Due to players
-- finding an efficient gold farm with this boss, blizzard has for now
-- removed its loot"): the line under the boss's name (boss.lootNote).
do
    local strings = {
        enUS = "Due to players finding an efficient gold farm with this boss, Blizzard has for now removed its loot.",
        deDE = "Weil Spieler mit diesem Boss eine effiziente Goldfarm gefunden haben, hat Blizzard seine Beute vorerst entfernt.",
        frFR = "Des joueurs ayant trouvé une ferme d'or efficace avec ce boss, Blizzard a retiré son butin pour l'instant.",
        esES = "Como los jugadores encontraron una forma eficaz de farmear oro con este jefe, Blizzard ha retirado su botín por ahora.",
        itIT = "Poiché i giocatori hanno trovato un modo efficace di farmare oro con questo boss, Blizzard ha rimosso il suo bottino per ora.",
        ptBR = "Como os jogadores encontraram um farm de ouro eficiente com este chefe, a Blizzard removeu o saque dele por enquanto.",
        ruRU = "Игроки нашли на этом боссе эффективный фарм золота, поэтому Blizzard пока убрала его добычу.",
        koKR = "플레이어들이 이 우두머리로 효율적인 골드 파밍 방법을 찾아내서 블리자드가 당분간 전리품을 제거했습니다.",
        zhCN = "由于玩家发现利用这个首领能高效刷金，暴雪暂时移除了它的掉落。",
        zhTW = "由於玩家發現利用這個首領能高效刷金，暴雪暫時移除了它的掉落。",
    }
    strings.esMX = strings.esES
    for locale, text in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t and t.LOOT_NOTE_LOOT_REMOVED == nil then t.LOOT_NOTE_LOOT_REMOVED = text end
    end
end
-- END lootremoved
