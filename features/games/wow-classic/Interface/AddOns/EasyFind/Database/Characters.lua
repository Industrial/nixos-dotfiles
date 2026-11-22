local _, ns = ...





local Data = {}
ns.CharacterData = Data

local Utils = ns.Utils
local Stored = ns.Stored
local pairs, ipairs = Utils.pairs, Utils.ipairs
local tsort = Utils.tsort
local sfind, slower = Utils.sfind, Utils.slower
local wipe = wipe
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemQualityByID = C_Item and C_Item.GetItemQualityByID
local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture

ns.CHAR_PROFILE_CACHE_VER = 1

local GEAR_SLOTS = 19

local function DB() return EasyFind and EasyFind.db end

local function Profiles()
    local db = DB()
    if not db then return nil end
    if type(db.charProfileCache) ~= "table" or db.charProfileCacheVer ~= ns.CHAR_PROFILE_CACHE_VER then
        db.charProfileCache = {}
        db.charProfileCacheVer = ns.CHAR_PROFILE_CACHE_VER
    end
    return db.charProfileCache
end

local function StoredChars(cacheField, verField, ver)
    local db = DB()
    local store = db and type(db[cacheField]) == "table" and db[verField] == ver and db[cacheField]
    return store and type(store.chars) == "table" and store.chars or nil
end

local function BagRecords() return StoredChars("bagCache", "bagCacheVer", ns.BAG_CACHE_VER) end
local function BankRecords() return StoredChars("bankCache", "bankCacheVer", ns.BANK_CACHE_VER) end






local FOLD = {}
do
    local function Encode(cp)
        return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
    end
    local LATIN = {
        { 0xC0, 0xC5, "a" }, { 0xC6, 0xC6, "ae" }, { 0xC7, 0xC7, "c" }, { 0xC8, 0xCB, "e" },
        { 0xCC, 0xCF, "i" }, { 0xD0, 0xD0, "d" }, { 0xD1, 0xD1, "n" }, { 0xD2, 0xD6, "o" },
        { 0xD8, 0xD8, "o" }, { 0xD9, 0xDC, "u" }, { 0xDD, 0xDD, "y" }, { 0xDE, 0xDE, "th" },
        { 0xDF, 0xDF, "ss" }, { 0xE0, 0xE5, "a" }, { 0xE6, 0xE6, "ae" }, { 0xE7, 0xE7, "c" },
        { 0xE8, 0xEB, "e" }, { 0xEC, 0xEF, "i" }, { 0xF0, 0xF0, "d" }, { 0xF1, 0xF1, "n" },
        { 0xF2, 0xF6, "o" }, { 0xF8, 0xF8, "o" }, { 0xF9, 0xFC, "u" }, { 0xFD, 0xFD, "y" },
        { 0xFE, 0xFE, "th" }, { 0xFF, 0xFF, "y" },
        { 0x100, 0x105, "a" }, { 0x106, 0x10D, "c" }, { 0x10E, 0x111, "d" }, { 0x112, 0x11B, "e" },
        { 0x11C, 0x123, "g" }, { 0x124, 0x127, "h" }, { 0x128, 0x131, "i" }, { 0x132, 0x133, "ij" },
        { 0x134, 0x135, "j" }, { 0x136, 0x138, "k" }, { 0x139, 0x142, "l" }, { 0x143, 0x14B, "n" },
        { 0x14C, 0x151, "o" }, { 0x152, 0x153, "oe" }, { 0x154, 0x159, "r" }, { 0x15A, 0x161, "s" },
        { 0x162, 0x167, "t" }, { 0x168, 0x173, "u" }, { 0x174, 0x175, "w" }, { 0x176, 0x178, "y" },
        { 0x179, 0x17E, "z" }, { 0x17F, 0x17F, "s" },
    }
    for _, range in ipairs(LATIN) do
        for cp = range[1], range[2] do FOLD[Encode(cp)] = range[3] end
    end
    for cp = 0x400, 0x40F do FOLD[Encode(cp)] = Encode(cp + 0x50) end
    for cp = 0x410, 0x42F do FOLD[Encode(cp)] = Encode(cp + 0x20) end
end

function Data.Fold(s)
    if not s or s == "" then return "" end
    return (slower((s:gsub("[\195-\197\208\209][\128-\191]", FOLD))))
end


function Data.Words(query, out)
    wipe(out)
    for word in Data.Fold(query):gmatch("%S+") do out[#out + 1] = word end
    return out
end



function Data.MatchesAll(folded, words, skip)
    for i = 1, #words do
        if not (skip and skip[i]) then
            local word = words[i]
            if not sfind(folded, word, 1, true) then
                if not (#word > 3 and word:sub(-1) == "s" and sfind(folded, word:sub(1, -2), 1, true)) then
                    return false
                end
            end
        end
    end
    return true
end



local function ReadGear()
    local out = {}
    for slot = 1, GEAR_SLOTS do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        if link then out[slot] = link end
    end
    return out
end

local GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo


function Data.ItemLevel(link)
    if not link then return nil end
    local level = GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(link)
    if not level and GetItemInfo then level = select(4, GetItemInfo(link)) end
    return level
end



local function ReadGearLevels(gear, old)
    local out = {}
    for slot, link in pairs(gear) do
        out[slot] = Data.ItemLevel(link) or (old and old[slot])
    end
    return out
end

local function AddProfession(out, index)
    if not index then return end
    local name, icon, rank, maxRank = GetProfessionInfo(index)
    if name then out[#out + 1] = { name = name, icon = icon, rank = rank, max = maxRank } end
end




local function ReadProfessions(previous)
    local out = {}
    if GetProfessions and GetProfessionInfo then
        local p1, p2, p3, p4, p5, p6 = GetProfessions()
        AddProfession(out, p1); AddProfession(out, p2); AddProfession(out, p3)
        AddProfession(out, p4); AddProfession(out, p5); AddProfession(out, p6)
    end
    if #out == 0 and GetNumSkillLines and GetSkillLineInfo then
        local primary, secondary = _G["TRADE_SKILLS"], _G["SECONDARY_SKILLS"]
        local under = false
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
            if isHeader then
                under = name ~= nil and (name == primary or name == secondary)
            elseif under and name and name ~= "" then
                out[#out + 1] = { name = name, rank = rank, max = maxRank, icon = GetSpellTexture and GetSpellTexture(name) or nil }
            end
        end
    end
    if #out == 0 and type(previous) == "table" then return previous end
    return out
end



local function ReadLockouts()
    if not (GetNumSavedInstances and GetSavedInstanceInfo) then return nil end
    local out, now = {}, time()
    for i = 1, GetNumSavedInstances() do
        local name, _, reset, _, locked, extended, _, isRaid, _, difficulty, bosses, down, _, id = GetSavedInstanceInfo(i)
        if name and (locked or extended) and reset and reset > 0 then
            out[#out + 1] = { n = name, u = now + reset, d = difficulty, r = isRaid or nil, id = id, k = down, of = bosses }
        end
    end
    return out
end


local function LockoutLess(a, b) return a.u < b.u end
local function LiveLockouts(lockouts)
    if type(lockouts) ~= "table" then return nil end
    local out, now = {}, time()
    for _, lock in ipairs(lockouts) do
        if type(lock) == "table" and lock.n and type(lock.u) == "number" and lock.u > now then out[#out + 1] = lock end
    end
    if #out == 0 then return nil end
    tsort(out, LockoutLess)
    return out
end


function Data.RecordLockouts()
    local profiles = Profiles()
    local p = profiles and profiles[ns.CurrentCharacterKey()]
    if not p then return end
    p.lockouts = ReadLockouts() or p.lockouts
    Data.Changed()
end





local function MadeItem(recipeID, shipped)
    if shipped then return shipped end
    local read = C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic
    if not read then return nil end
    local ok, schematic = pcall(read, recipeID, false)
    return ok and type(schematic) == "table" and schematic.outputItemID or nil
end



local function ReadCrafts()
    local Database, shipped = ns.Database, ns.PROFESSION_RECIPES
    if not (GetProfessions and GetProfessionInfo and shipped and Database and Database.IsRecipeLearned) then return nil end
    local out = {}
    local p1, p2, p3, p4, p5, p6 = GetProfessions()
    for _, index in ipairs({ p1 or false, p2 or false, p3 or false, p4 or false, p5 or false, p6 or false }) do
        local name, skillLine
        if index then
            local profName, _, _, _, _, _, line = GetProfessionInfo(index)
            name, skillLine = profName, line
        end
        local data = name and skillLine and shipped[skillLine]
        if data and data.recipesByPage then
            local items = {}
            for pageID in pairs(data.recipesByPage) do
                local ids = Database.PageRecipeIDs(data, pageID) or {}
                local made = data._makesCache and data._makesCache[pageID]
                for i = 1, #ids do
                    if Database.IsRecipeLearned(ids[i]) then
                        local item = MadeItem(ids[i], made and made[i])
                        if item and item > 0 then items[#items + 1] = item end
                    end
                end
            end
            if #items > 0 then out[name] = "," .. table.concat(items, ",") .. "," end
        end
    end
    return out
end

function Data.RecordCrafts()
    local profiles = Profiles()
    local p = profiles and profiles[ns.CurrentCharacterKey()]
    if not p then return end
    p.crafts = ReadCrafts() or p.crafts
end




function Data.Crafters(itemID, itemName)
    local out = {}
    local db = DB()
    local books = db and ns.Caps and ns.Caps.classic and db.classicRecipes
    local profiles = Profiles() or {}
    local needle = itemID and ("," .. itemID .. ",")
    for _, entry in ipairs(Data.List()) do
        local crafts = profiles[entry.key] and profiles[entry.key].crafts
        if type(crafts) == "table" and needle then
            for prof, items in pairs(crafts) do
                if type(items) == "string" and sfind(items, needle, 1, true) then out[#out + 1] = { entry = entry, prof = prof } end
            end
        end
        local book = type(books) == "table" and books[entry.key]
        if type(book) == "table" and itemName then
            for prof, kept in pairs(book) do
                if type(kept) == "table" and type(kept.recipes) == "table" and kept.recipes[itemName] then
                    out[#out + 1] = { entry = entry, prof = prof }
                end
            end
        end
    end
    return out
end


local sessionStart



function Data.Snapshot(atLogout)
    local profiles = Profiles()
    if not profiles then return end
    local key = ns.CurrentCharacterKey()
    local p = profiles[key] or {}
    profiles[key] = p
    local now = time()
    if atLogout then
        if p.played and sessionStart then p.played = p.played + (now - (p.playedAt or now)) end
        p.playedAt, p.seenAt = now, now
        return
    end
    p.name = ns.PlayerName() or p.name
    p.realm = GetRealmName and GetRealmName() or p.realm
    p.class = select(2, UnitClass("player")) or p.class
    local level = UnitLevel and UnitLevel("player")
    if level and level > 0 then p.level = level end
    p.money = GetMoney and GetMoney() or p.money
    local zone = GetRealZoneText and GetRealZoneText()
    if zone and zone ~= "" then p.zone = zone end
    local subZone = GetSubZoneText and GetSubZoneText()
    p.subZone = (subZone and subZone ~= "" and subZone ~= p.zone) and subZone or nil
    p.seenAt = now
    if GetAverageItemLevel then
        local _, equipped = GetAverageItemLevel()
        if equipped and equipped > 0 then p.ilvl = equipped end
    end
    local oldGear, oldLevels = p.gear, p.gearLevel
    p.gear = ReadGear()

    if oldGear and oldLevels then
        for slot in pairs(oldLevels) do
            if oldGear[slot] ~= p.gear[slot] then oldLevels[slot] = nil end
        end
    end
    p.gearLevel = ReadGearLevels(p.gear, oldLevels)
    p.profs = ReadProfessions(p.profs)
    p.lockouts = ReadLockouts() or p.lockouts


    if p.played then
        if sessionStart then p.played = p.played + (now - (p.playedAt or now)) end
        p.playedAt = now
    end

    if not sessionStart then Data.RecordCrafts() end
    sessionStart = sessionStart or now
    Data.Changed()
end


local FACT_PROVIDERS = { "charRows", "charPlayed", "charSeen", "charGold", "charLevel" }

function Data.Changed()
    Data.Invalidate()
    if not (ns.Database and ns.Database.MarkDynamicCategoryDirty) then return end
    for _, key in ipairs(FACT_PROVIDERS) do ns.Database:MarkDynamicCategoryDirty(key) end
end

function Data.RecordMoney()
    local profiles = Profiles()
    local p = profiles and profiles[ns.CurrentCharacterKey()]
    if p and GetMoney then p.money = GetMoney() end
end


function Data.RecordPlayed(total)
    local profiles = Profiles()
    if not (profiles and type(total) == "number") then return end
    local p = profiles[ns.CurrentCharacterKey()]
    if not p then
        Data.Snapshot()
        p = profiles[ns.CurrentCharacterKey()]
    end
    p.played = total
    p.playedAt = time()
    Data.Changed()
end




local deafened

local function HearPlayedAgain()
    if not deafened then return end
    for _, frame in ipairs(deafened) do frame:RegisterEvent("TIME_PLAYED_MSG") end
    deafened = nil
end

function Data.AskPlayedQuietly()
    if deafened or not (RequestTimePlayed and GetFramesRegisteredForEvent) then return end
    deafened = {}
    for _, frame in ipairs({ GetFramesRegisteredForEvent("TIME_PLAYED_MSG") }) do
        local name = frame.GetName and frame:GetName()
        if name and name:find("^ChatFrame%d+$") then
            frame:UnregisterEvent("TIME_PLAYED_MSG")
            deafened[#deafened + 1] = frame
        end
    end
    RequestTimePlayed()

    Utils.SafeAfter(10, HearPlayedAgain)
end

do
    local pending = false
    local asked = false
    local function Soon()
        if pending then return end
        pending = true
        Utils.SafeAfter(2, function()
            pending = false
            Data.Snapshot()
        end)
    end
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_LOGIN")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("PLAYER_LOGOUT")
    for _, event in ipairs({ "PLAYER_MONEY", "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA",
                             "PLAYER_EQUIPMENT_CHANGED", "SKILL_LINES_CHANGED", "TIME_PLAYED_MSG",
                             "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED",
                             "UPDATE_INSTANCE_INFO", "BOSS_KILL", "NEW_RECIPE_LEARNED" }) do
        Utils.RegisterEventIfValid(watcher, event)
    end
    watcher:SetScript("OnEvent", function(_, event, arg1)
        if event == "BAG_UPDATE_DELAYED" or event == "PLAYERBANKSLOTS_CHANGED" then
            Data.Invalidate()
        elseif event == "UPDATE_INSTANCE_INFO" then
            Data.RecordLockouts()
        elseif event == "BOSS_KILL" then
            if RequestRaidInfo then Utils.SafeAfter(3, RequestRaidInfo) end
        elseif event == "NEW_RECIPE_LEARNED" then
            Data.RecordCrafts()
        elseif event == "PLAYER_LOGOUT" then
            Data.Snapshot(true)
        elseif event == "TIME_PLAYED_MSG" then
            Data.RecordPlayed(arg1)
            Utils.SafeAfter(0, HearPlayedAgain)
        else

            if event == "PLAYER_MONEY" then Data.RecordMoney() end
            if event == "PLAYER_ENTERING_WORLD" and not asked then
                asked = true
                Utils.SafeAfter(5, Data.AskPlayedQuietly)
                if RequestRaidInfo then RequestRaidInfo() end
            end
            Soon()
        end
    end)
end





local gen = 0
local memo = {}

function Data.Invalidate()
    gen = gen + 1
end

local function Memo(id, build, ...)
    local hit = memo[id]
    if hit and hit.gen == gen then return hit.value end
    local value = build(...)
    memo[id] = { gen = gen, value = value }
    return value
end


local function LedgerMoney(name, realm)
    local ledger = type(EasyFindDB) == "table" and EasyFindDB.charGold
    if type(ledger) ~= "table" or not (name and realm) then return nil end
    local amount = ledger[name .. "-" .. realm:gsub("[%s%-]", "")]
    return type(amount) == "number" and amount or nil
end

local function ListLess(a, b)
    if a.isCurrent ~= b.isCurrent then return a.isCurrent end
    local sa, sb = a.seenAt or 0, b.seenAt or 0
    if sa ~= sb then return sa > sb end
    return (a.name or "") < (b.name or "")
end



local function BuildList()
    local out, byKey = {}, {}
    local currentKey = ns.CurrentCharacterKey()


    local function Add(key, rec)
        if type(rec) ~= "table" or not rec.name then return end
        local entry = byKey[key]
        if not entry then
            entry = { key = key, name = rec.name, realm = rec.realm, class = rec.class, isCurrent = key == currentKey }
            byKey[key] = entry
            out[#out + 1] = entry
        end
        local saved = type(rec.scannedAt) == "number" and rec.scannedAt > 0 and rec.scannedAt or nil
        if saved and saved > (entry.savedAt or 0) then entry.savedAt = saved end
    end
    local profiles = Profiles() or {}
    for key, p in pairs(profiles) do Add(key, p) end
    for key, r in pairs(BagRecords() or {}) do Add(key, r) end
    for key, r in pairs(BankRecords() or {}) do Add(key, r) end
    Add(currentKey, { name = ns.PlayerName(), realm = GetRealmName and GetRealmName(), class = select(2, UnitClass("player")) })
    for _, entry in ipairs(out) do
        local p = profiles[entry.key]
        if p then
            entry.level, entry.money, entry.zone, entry.subZone = p.level, p.money, p.zone, p.subZone
            entry.seenAt, entry.ilvl, entry.played, entry.profs = p.seenAt, p.ilvl, p.played, p.profs
            entry.gear, entry.gearLevel = p.gear, p.gearLevel
            entry.lockouts = LiveLockouts(p.lockouts)
        end

        local ledger = LedgerMoney(entry.name, entry.realm)
        if not entry.money or (entry.money == 0 and ledger and ledger > 0) then entry.money = ledger or entry.money end
        entry.seenAt = entry.seenAt or entry.savedAt
        if entry.isCurrent then
            entry.level = UnitLevel and UnitLevel("player") or entry.level
            entry.money = GetMoney and GetMoney() or entry.money
            entry.zone = GetRealZoneText and GetRealZoneText() or entry.zone
            entry.seenAt = time()
            entry.lockouts = LiveLockouts(ReadLockouts()) or entry.lockouts
        end
    end
    tsort(out, ListLess)
    return out
end

function Data.List()
    return Memo("list", BuildList)
end

function Data.Get(key)
    for _, entry in ipairs(Data.List()) do
        if entry.key == key then return entry end
    end
    return nil
end



function Data.SavedTo(name, instanceID)
    local folded = name and Data.Fold(name)
    local out
    for _, entry in ipairs(Data.List()) do
        for _, lock in ipairs(entry.lockouts or {}) do
            if (instanceID and lock.id == instanceID) or (folded and Data.Fold(lock.n) == folded) then
                out = out or {}
                out[#out + 1] = { entry = entry, lock = lock }
            end
        end
    end
    return out
end



local PLACE_LABEL = {
    bags = function() return _G["BAGSLOT"] or "Bags" end,
    bank = function() return _G["BANK"] or "Bank" end,
    warband = function() return ns.WarbandBankLabel() end,
    gear = function() return _G["CURRENTLY_EQUIPPED"] or "Equipped" end,
}

function Data.PlaceLabel(place)
    local label = PLACE_LABEL[place]
    return label and label() or ""
end

local function Cell(itemID, count, info, place, link)
    local name = info and info.name
    if not name and GetItemInfo then name = GetItemInfo(link or itemID) end
    local quality = info and info.quality
    if quality == nil and GetItemQualityByID then quality = GetItemQualityByID(link or itemID) end
    return {
        itemID = itemID, count = count or 1, name = name, link = link, place = place,
        icon = info and info.icon or Stored.ItemIcon(itemID), quality = quality,
        folded = Data.Fold(name),
    }
end




local function AddRecordSections(record, place, out)
    if type(record) ~= "table" then return end
    local rows = Utils.UnpackRows(record.packed or "", Stored.STORED_ITEM_ROW_SPEC)
    local layout = record.layout
    if type(layout) ~= "table" or type(layout.sizes) ~= "table" or type(layout.slots) ~= "table" then
        local section = { header = Data.PlaceLabel(place), place = place, cells = {} }
        for _, row in ipairs(rows) do
            if row.itemID then section.cells[#section.cells + 1] = Cell(row.itemID, row.count, row, place) end
        end
        if #section.cells > 0 then out[#out + 1] = section end
        return
    end
    local ids = {}
    for id in pairs(layout.sizes) do ids[#ids + 1] = id end
    tsort(ids)
    for _, id in ipairs(ids) do
        local names = layout.names
        local section = { header = names and names[id] or Data.PlaceLabel(place), place = place, cells = {} }



        local slot = 0
        for entry in ((layout.slots[id] or "") .. ","):gmatch("([^,]*),") do
            slot = slot + 1
            local index, count = entry:match("^(%d+)%*?(%d*)$")
            local row = index and rows[tonumber(index)]
            if row and row.itemID then
                local cell = Cell(row.itemID, tonumber(count) or 1, row, place)
                cell.bag, cell.slot = id, slot
                section.cells[#section.cells + 1] = cell
            end
        end
        if #section.cells > 0 then out[#out + 1] = section end
    end
end

local function GearSection(key)
    local gear
    if key == ns.CurrentCharacterKey() then
        gear = ReadGear()
    else
        local p = (Profiles() or {})[key]
        gear = p and p.gear
    end
    local section = { header = Data.PlaceLabel("gear"), place = "gear", cells = {} }
    for slot = 1, GEAR_SLOTS do
        local link = type(gear) == "table" and gear[slot]
        local itemID = link and (GetItemInfoInstant and GetItemInfoInstant(link) or tonumber(link:match("item:(%d+)")))
        if itemID then
            local name = link:match("%[(.-)%]")
            section.cells[#section.cells + 1] = Cell(itemID, 1, { name = name }, "gear", link)
        end
    end
    return section
end


local function Merged(sections, section)
    for _, s in ipairs(sections) do
        for _, cell in ipairs(s.cells) do section.cells[#section.cells + 1] = cell end
    end
    return #section.cells > 0 and section or nil
end




local function BuildSections(key, kind)
    local out = {}
    if kind == "gear" then
        out[1] = GearSection(key)
        return out
    end

    if ns.Database and ns.Database.PersistBagContents and (key == nil or key == ns.CurrentCharacterKey()) then
        ns.Database:PersistBagContents()
    end
    local bags, banks = BagRecords() or {}, BankRecords() or {}
    if key then
        AddRecordSections(bags[key], "bags", out)
        AddRecordSections(banks[key], "bank", out)
        return out
    end
    for _, entry in ipairs(Data.List()) do
        local own = {}
        if kind ~= "bank" then AddRecordSections(bags[entry.key], "bags", own) end
        if kind ~= "bags" then AddRecordSections(banks[entry.key], "bank", own) end
        out[#out + 1] = Merged(own, { header = entry.name, class = entry.class, charKey = entry.key, cells = {} })
    end
    if kind == "bags" then return out end
    local db = DB()
    local account = db and type(db.bankCache) == "table" and db.bankCacheVer == ns.BANK_CACHE_VER and db.bankCache.account
    local warband = {}
    AddRecordSections(account, "warband", warband)
    out[#out + 1] = Merged(warband, { header = Data.PlaceLabel("warband"), place = "warband", cells = {} })
    return out
end

function Data.Sections(key, kind)
    return Memo((key or "*") .. "|" .. kind, BuildSections, key, kind)
end


function Data.ItemCounts(key)
    local function Count(record)
        if type(record) ~= "table" or type(record.packed) ~= "string" then return nil end
        local n = 0
        for _, row in ipairs(Utils.UnpackRows(record.packed, Stored.STORED_ITEM_ROW_SPEC)) do n = n + (row.count or 1) end
        return n
    end
    return Count((BagRecords() or {})[key]), Count((BankRecords() or {})[key])
end



function Data.Find(key, words)
    local out, seen = {}, {}
    local lists = { Data.Sections(key, "items"), Data.Sections(key, "gear") }
    for _, list in ipairs(lists) do
      for _, section in ipairs(list) do
        for _, cell in pairs(section.cells) do
            if cell and Data.MatchesAll(cell.folded, words) then
                local id = cell.place .. ":" .. cell.itemID
                local hit = seen[id]
                if hit then
                    hit.count = hit.count + cell.count
                else
                    hit = { itemID = cell.itemID, name = cell.name, icon = cell.icon, quality = cell.quality,
                            link = cell.link, count = cell.count, place = cell.place, header = section.header }
                    seen[id] = hit
                    out[#out + 1] = hit
                end
            end
        end
      end
    end
    return out
end
