local _, ns = ...




local Stores = {}
ns.Stores = Stores

local Database, Utils, Stored = ns.Database, ns.Utils, ns.Stored
local ipairs, pairs = Utils.ipairs, Utils.pairs
local sformat, tconcat = Utils.sformat, Utils.tconcat

ns.MAIL_CACHE_VER = 1
ns.GUILD_BANK_CACHE_VER = 1
local DAY = 86400
local MAIL_KEYWORDS = { "mail", "mailbox" }
local GUILD_BANK_KEYWORDS = { "guild bank", "gbank" }

local function MailStore() return Stored.StoredCacheStore("mailCache", "mailCacheVer", ns.MAIL_CACHE_VER) end
local function GuildBankStore()
    return Stored.StoredCacheStore("guildBankCache", "guildBankCacheVer", ns.GUILD_BANK_CACHE_VER)
end

local function Dirty(key)
    if Database.MarkDynamicCategoryDirty then Database:MarkDynamicCategoryDirty(key) end
    if ns.CharacterData and ns.CharacterData.Invalidate then ns.CharacterData.Invalidate() end
end







function Stores.ScanMail()
    if not (GetInboxNumItems and GetInboxHeaderInfo and GetInboxItem) then return false end
    local store = MailStore()
    if not store then return false end
    local now, rows, byID, money = time(), {}, {}, 0
    for index = 1, GetInboxNumItems() or 0 do
        local _, _, _, _, coins, cod, daysLeft, attachments = GetInboxHeaderInfo(index)
        if (cod or 0) == 0 then
            money = money + (coins or 0)
            local expires = now + math.floor((daysLeft or 0) * DAY)
            for slot = 1, attachments and (ATTACHMENTS_MAX_RECEIVE or 16) or 0 do
                local name, itemID, texture, count, quality = GetInboxItem(index, slot)
                if itemID then
                    local id = itemID .. ":" .. index
                    local row = byID[id]
                    if not row then
                        row = { itemID = itemID, count = 0, tab = expires, name = name, icon = texture, quality = quality }
                        byID[id] = row
                        rows[#rows + 1] = row
                    end
                    row.count = row.count + (count or 1)
                end
            end
        end
    end
    local record = Stored.StoredCharRecord(Utils.PackRows(rows, Stored.STORED_ITEM_ROW_SPEC))
    record.money = money
    store.chars[ns.CurrentCharacterKey()] = record
    return true
end





function Stores.Mail(charKey)
    local db = EasyFind and EasyFind.db
    local store = db and db.mailCacheVer == ns.MAIL_CACHE_VER and type(db.mailCache) == "table" and db.mailCache.chars
    local record = type(store) == "table" and store[charKey]
    if type(record) ~= "table" then return nil end
    local now, items, byID = time(), {}, {}
    for _, row in ipairs(Utils.UnpackRows(record.packed or "", Stored.STORED_ITEM_ROW_SPEC)) do
        if row.itemID and (row.tab or 0) > now then
            local item = byID[row.itemID]
            if not item then
                item = { itemID = row.itemID, name = row.name, icon = row.icon, quality = row.quality, count = 0,
                         expires = row.tab }
                byID[row.itemID] = item
                items[#items + 1] = item
            end
            item.count = item.count + (row.count or 1)
            if row.tab < item.expires then item.expires = row.tab end
        end
    end
    return { items = items, money = record.money or 0, name = record.name, class = record.class }
end

function Stores.DaysLeft(expires)
    local days = math.max(1, math.ceil((expires - time()) / DAY))
    return sformat(_G["D_DAYS"] or "%d Days", days)
end


local function MailSubtext(holders)
    local parts = {}
    for i, holder in ipairs(holders) do
        parts[i] = sformat("%s (%d, %s)", holder.name or "?", holder.count or 1, Stores.DaysLeft(holder.tab))
    end
    return ns.StoredCategoryLabel("Mail") .. ": " .. tconcat(parts, ", ")
end

function Database:PopulateDynamicMail()
    Database.RemoveEntriesByCategory("Mail")
    if self.ResetSearchCache then self:ResetSearchCache() end
    local db = EasyFind and EasyFind.db
    local chars = db and db.mailCacheVer == ns.MAIL_CACHE_VER and type(db.mailCache) == "table" and db.mailCache.chars
    if type(chars) ~= "table" then return true end
    local byID, order = {}, {}
    for charKey in pairs(chars) do
        local mail = Stores.Mail(charKey)
        for _, item in ipairs(mail and mail.items or {}) do
            local entry = byID[item.itemID]
            if not entry then
                entry = { row = item, total = 0, holders = {} }
                byID[item.itemID] = entry
                order[#order + 1] = entry
            end
            entry.total = entry.total + item.count
            entry.holders[#entry.holders + 1] = { charKey = charKey, name = mail.name, class = mail.class,
                                                  count = item.count, tab = item.expires }
        end
    end
    local rows = self.uiSearchData
    for _, entry in ipairs(order) do
        local row = Stored.EmitStoredRow(entry, "Mail", MAIL_KEYWORDS, true)
        row.storedSubtext = MailSubtext(entry.holders)
        rows[#rows + 1] = row
    end
    return true
end



local function GuildKey()
    local guild = GetGuildInfo and GetGuildInfo("player")
    if not guild or guild == "" then return nil end
    return "guild:" .. guild .. "-" .. (GetRealmName and GetRealmName() or ""), guild
end



function Stores.ScanGuildBank()
    if not (GetNumGuildBankTabs and GetGuildBankTabInfo and GetGuildBankItemInfo and GetGuildBankItemLink) then
        return false
    end
    local key, guild = GuildKey()
    local store = key and GuildBankStore()
    if not store then return false end
    local record = store.chars[key] or {}
    record.name, record.scannedAt = guild, time()
    record.tabs, record.tabRows = record.tabs or {}, record.tabRows or {}
    local shown = GetCurrentGuildBankTab and GetCurrentGuildBankTab()
    for tab = 1, GetNumGuildBankTabs() or 0 do
        local tabName, _, viewable = GetGuildBankTabInfo(tab)
        if viewable then
            local rows, byID = {}, {}
            for slot = 1, MAX_GUILDBANK_SLOTS_PER_TAB or 98 do
                local texture, count = GetGuildBankItemInfo(tab, slot)
                local link = texture and GetGuildBankItemLink(tab, slot)
                local itemID = link and tonumber(link:match("item:(%d+)"))
                if itemID then
                    local row = byID[itemID]
                    if not row then
                        row = { itemID = itemID, count = 0, tab = tab, slot = slot, name = link:match("%[(.-)%]"), icon = texture }
                        byID[itemID] = row
                        rows[#rows + 1] = row
                    end
                    row.count = row.count + (count or 1)
                end
            end
            if #rows > 0 or tab == shown then
                record.tabs[tab] = tabName
                record.tabRows[tab] = Utils.PackRows(rows, Stored.STORED_ITEM_ROW_SPEC)
            end
        end
    end

    local all = {}
    for _, packed in pairs(record.tabRows) do
        for _, row in ipairs(Utils.UnpackRows(packed, Stored.STORED_ITEM_ROW_SPEC)) do all[#all + 1] = row end
    end
    record.packed = Utils.PackRows(all, Stored.STORED_ITEM_ROW_SPEC)
    store.chars[key] = record
    return true
end

function Database:PopulateDynamicGuildBank()
    Database.RemoveEntriesByCategory("Guild Bank")
    if self.ResetSearchCache then self:ResetSearchCache() end
    local db = EasyFind and EasyFind.db
    local guilds = db and db.guildBankCacheVer == ns.GUILD_BANK_CACHE_VER and type(db.guildBankCache) == "table"
        and db.guildBankCache.chars
    if type(guilds) ~= "table" then return true end
    local itemMap, order = {}, {}
    for key, record in pairs(guilds) do Stored.AbsorbStoredRows(record, record.name, key, itemMap, order) end
    local rows = self.uiSearchData
    for _, entry in ipairs(order) do
        rows[#rows + 1] = Stored.EmitStoredRow(entry, "Guild Bank", GUILD_BANK_KEYWORDS, true)
    end
    return true
end



local GUILD_BANKER = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.GuildBanker
local pending = {}

local function Soon(what, scan, providerKey)
    if pending[what] then return end
    pending[what] = true
    Utils.SafeAfter(0.4, function()
        pending[what] = nil
        if scan() then Dirty(providerKey) end
    end)
end


local function AskForTabs()
    if not (QueryGuildBankTab and GetNumGuildBankTabs and GetGuildBankTabInfo) then return end
    for tab = 1, GetNumGuildBankTabs() or 0 do
        local _, _, viewable = GetGuildBankTabInfo(tab)
        if viewable then QueryGuildBankTab(tab) end
    end
end

local watcher = CreateFrame("Frame")
for _, event in ipairs({ "MAIL_INBOX_UPDATE", "GUILDBANKFRAME_OPENED", "GUILDBANKBAGSLOTS_CHANGED",
                         "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" }) do
    Utils.RegisterEventIfValid(watcher, event)
end
watcher:SetScript("OnEvent", function(_, event, kind)
    if event == "MAIL_INBOX_UPDATE" then
        Soon("mail", Stores.ScanMail, "mail")
    elseif event == "GUILDBANKBAGSLOTS_CHANGED" then
        Soon("guildBank", Stores.ScanGuildBank, "guildBank")
    elseif event == "GUILDBANKFRAME_OPENED" or (GUILD_BANKER and kind == GUILD_BANKER) then
        AskForTabs()
    end
end)
