local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns then return end
local Store = ns.ClipboardStore
if not Store then return end






local Clipboard = {}
ns.Clipboard = Clipboard

local Utils = ns.Utils
local L = ns.L
local slower = Utils.slower
local sformat = Utils.sformat
local smatch = Utils.smatch
local sfind = Utils.sfind
local sgmatch = string.gmatch
local sgsub = string.gsub
local type = Utils.type
local time = time
local date = date
local CreateFrame = CreateFrame
local SecondsToTime = SecondsToTime
local C_Item = C_Item
local C_Spell = C_Spell
local C_CurrencyInfo = C_CurrencyInfo
local C_PetJournal = C_PetJournal
local GetAchievementInfo = GetAchievementInfo

local GENERIC_ICON = "Interface\\Icons\\INV_Misc_Note_01"

local function CharKey() return ns.CurrentCharacterKey() end

local function SourceOn(source)
    return Store:Settings()[source] ~= false
end




local function ListShowing()
    local Filters = ns.Filters
    local qf = Filters and Filters.GetQuickFilter and Filters:GetQuickFilter()
    if not (qf and qf.key == "clipboard") then return false end
    local Search = ns.Search
    local resultsFrame = Search and Search.GetResultsFrame and Search:GetResultsFrame()
    return resultsFrame ~= nil and resultsFrame:IsShown()
end





function Clipboard:Refresh(now)
    if not self._populated then return end
    if not ListShowing() then
        self._stale = true
        return
    end
    if now then
        self._refreshQueued = nil
        self._stale = nil
        EasyFind.API.RefreshSearchProvider("clipboard")
        return
    end
    if self._refreshQueued then return end
    self._refreshQueued = true
    Utils.SafeAfter(0.5, function() Clipboard:Refresh(true) end)
end


function Clipboard:RefreshIfStale()
    if self._stale and ListShowing() then self:Refresh(true) end
end





local LinkIcon





local function LinkInText(text)
    if type(text) ~= "string" or not sfind(text, "|H", 1, true) then return nil end
    local color, data, bracket = smatch(text, "(|c[^|]-)|H([^|]+)|h(%[[^%]]*%])|h")
    if not data then
        data, bracket = smatch(text, "|H([^|]+)|h(%[[^%]]*%])|h")
        color = "|cffffffff"
    end
    if not data then return nil end
    return color .. "|H" .. data .. "|h" .. bracket .. "|h|r", bracket
end

function Clipboard:RecordCopied(text, link, icon)
    if not SourceOn("copied") then return end
    if not link then
        local found, bracket = LinkInText(text)
        if found then link, text, icon = found, bracket, icon or LinkIcon(found) end
    end
    if Store:Record(Store.SOURCE.COPIED, text, link, { char = CharKey(), icon = icon }) then
        self:Refresh()
    end
end



local function PasteWorthKeeping(chunk)
    if type(chunk) ~= "string" or #chunk < 5 then return false end
    local _, chars = sgsub(chunk, "[^\128-\191]", "")
    return chars >= 3
end





local WOWHEAD_KIND = { item = "item", spell = "spell", achievement = "achievement", currency = "currency" }
local ICON_BY_KIND = {
    item = function(id) return C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id) end,
    spell = function(id) return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) end,
    achievement = function(id) return GetAchievementInfo and select(10, GetAchievementInfo(id)) end,
    currency = function(id)
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
        return info and info.iconFileID
    end,
}
local function IconByName(name)
    if not name or name == "" then return nil end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, tex = pcall(C_Spell.GetSpellTexture, name)
        if ok and tex then return tex end
    end
    if C_Item and C_Item.GetItemIDForItemInfo and C_Item.GetItemIconByID then
        local ok, id = pcall(C_Item.GetItemIDForItemInfo, name)
        if ok and id then return C_Item.GetItemIconByID(id) end
    end
    return nil
end






local pendingItems, pendingCount = {}, 0
local loadWatcher
local function RequestItem(id)
    if not id or pendingItems[id] then return end
    if not (C_Item and C_Item.RequestLoadItemDataByID) then return end
    pendingItems[id] = true
    pendingCount = pendingCount + 1
    if not loadWatcher then
        loadWatcher = CreateFrame("Frame")
        loadWatcher:SetScript("OnEvent", function(self, _, itemID, success)
            if not pendingItems[itemID] then return end
            pendingItems[itemID] = nil
            pendingCount = pendingCount - 1
            if pendingCount <= 0 then
                pendingCount = 0
                self:UnregisterEvent("ITEM_DATA_LOAD_RESULT")
            end
            if success then Clipboard:Refresh() end
        end)
    end
    if pendingCount == 1 then loadWatcher:RegisterEvent("ITEM_DATA_LOAD_RESULT") end
    C_Item.RequestLoadItemDataByID(id)
end





local function LinkNameHex(link)
    if not link then return nil end
    local own = smatch(link, "^(|c%x%x%x%x%x%x%x%x)|H") or smatch(link, "^(|cn[^:]+:)|H")
    local itemID = smatch(link, "|Hitem:(%d+)")
    if itemID then
        itemID = tonumber(itemID)
        local q = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID)
        local qc = q and _G["ITEM_QUALITY_COLORS"] and _G["ITEM_QUALITY_COLORS"][q]
        if qc and qc.hex then return qc.hex end
        RequestItem(itemID)
        return own ~= "|cffffffff" and own or nil
    end


    return own ~= "|cffffffff" and own or nil
end



local function ResolvePasted(text, cheap)
    local s = Utils.StripMarkup and Utils.StripMarkup(text) or text
    if not s or s == "" or #s > 200 then return nil end
    local kind, id = smatch(s, "wowhead%.com/[%w%-/]-(%a+)=(%d+)")
    if kind and WOWHEAD_KIND[kind] then
        local icon = ICON_BY_KIND[kind](tonumber(id))
        if icon then return icon end
    end
    local verb, target = smatch(s, "^/(%a+)%s+(.-)$")
    if verb and (verb == "cast" or verb == "use" or verb == "castsequence") then
        target = sgsub(sgsub(target, "%[.-%]", ""), "^%s+", "")
        target = smatch(target, "^([^;,]+)") or target
        local icon = IconByName(target)
        if icon then return icon end
    end
    if sfind(s, "\n", 1, true) then return nil end
    local name = sgsub(s, "^%[(.-)%]$", "%1")
    if cheap then return IconByName(name) end
    local data = ns.Aliases and ns.Aliases.FindEntryByKey and ns.Aliases:FindEntryByKey("ui:" .. name)
    if data then
        local icon = data.icon
            or (data.spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(data.spellID))
            or (data.itemID and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(data.itemID))
        local link = ns.GetResultLink and ns.GetResultLink(data)
        return icon, (link and link ~= "" and link or nil)
    end
    return IconByName(name)
end

function Clipboard:RecordPasted(text)
    if not SourceOn("pasted") or not PasteWorthKeeping(text) then return end
    local icon, link
    local found, bracket = LinkInText(text)
    if found then
        link, text, icon = found, bracket, LinkIcon(found)
    else
        icon, link = ResolvePasted(text)
    end
    if Store:Record(Store.SOURCE.PASTED, text, link, { char = CharKey(), icon = icon }) then
        self:Refresh()
    end
end



function Clipboard:BackfillIcons()
    local list = Store:Entries()
    local budget = 40
    local changed = false
    for i = 1, #list do
        local entry = list[i]
        if not entry.icon and not entry.link and entry.source == Store.SOURCE.PASTED then
            budget = budget - 1
            if budget < 0 then break end
            local icon, link = ResolvePasted(entry.text, true)
            if icon then entry.icon = icon; changed = true end
            if link then entry.link = link; entry.kind = Store.Classify(entry.text, link); changed = true end
        end
    end
    if changed then self:Refresh() end
end

function Clipboard:RecordChatLink(link, bracket, sender, channel)
    if not SourceOn("chat") then return end
    local meta = { sender = sender, channel = channel, char = CharKey() }
    if Store:Record(Store.SOURCE.CHAT, bracket, link, meta) then
        self:Refresh()
    end
end



function Clipboard:RecordSent(msg, chatType, target)
    if not SourceOn("sent") or type(msg) ~= "string" then return end
    local channel = chatType and (_G[chatType] or chatType) or ""
    if chatType == "WHISPER" and type(target) == "string" and target ~= "" then
        channel = channel .. ": " .. (smatch(target, "^([^%-]+)") or target)
    end
    local text, link = msg, nil
    local found, bracket = LinkInText(msg)
    if found and smatch(msg, "^%s*|c?.-|H.-|h%[.-%]|h|?r?%s*$") then link, text = found, bracket end
    if Store:Record(Store.SOURCE.SENT, text, link, { channel = channel, char = CharKey(), icon = link and LinkIcon(link) or nil }) then
        self:Refresh()
    end
end


local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_LOOT",
}
local CHANNEL_KEY = {
    CHAT_MSG_SAY = "SAY", CHAT_MSG_YELL = "YELL",
    CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID", CHAT_MSG_RAID_WARNING = "RAID_WARNING",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT", CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    CHAT_MSG_GUILD = "GUILD", CHAT_MSG_OFFICER = "OFFICER",
    CHAT_MSG_WHISPER = "WHISPER", CHAT_MSG_WHISPER_INFORM = "WHISPER",
    CHAT_MSG_BN_WHISPER = "WHISPER", CHAT_MSG_BN_WHISPER_INFORM = "WHISPER",
    CHAT_MSG_LOOT = "LOOT",
}
local WHISPER_EVENT = {
    CHAT_MSG_WHISPER = true, CHAT_MSG_WHISPER_INFORM = true,
    CHAT_MSG_BN_WHISPER = true, CHAT_MSG_BN_WHISPER_INFORM = true,
}

local function ChatLinkFilter(_, event, msg, author, _, _, _, _, _, _, channelBaseName)
    if type(msg) ~= "string" or not sfind(msg, "|H", 1, true) then return false end
    if WHISPER_EVENT[event] and not Store:Settings().whispers then return false end
    local channel
    if event == "CHAT_MSG_CHANNEL" then
        channel = channelBaseName or ""
    else
        local key = CHANNEL_KEY[event]
        channel = key and (_G[key] or key) or ""
    end
    local sender = type(author) == "string" and (smatch(author, "^([^%-]+)") or author) or nil




    local seen
    for color, data, bracket in sgmatch(msg, "(|c[^|]-)|H([^|]+)|h(%[[^%]]*%])|h") do
        seen = seen or {}
        if not seen[data] then
            seen[data] = true
            Clipboard:RecordChatLink(color .. "|H" .. data .. "|h" .. bracket .. "|h|r",
                bracket, sender, channel)
        end
    end
    for data, bracket in sgmatch(msg, "|H([^|]+)|h(%[[^%]]*%])|h") do
        seen = seen or {}
        if not seen[data] then
            seen[data] = true
            Clipboard:RecordChatLink("|cffffffff|H" .. data .. "|h" .. bracket .. "|h|r",
                bracket, sender, channel)
        end
    end
    return false
end



LinkIcon = function(link)
    local kind, id = smatch(link, "|H(%a+):(%d+)")
    id = tonumber(id)
    if not (kind and id) then return nil end
    if kind == "item" and C_Item and C_Item.GetItemIconByID then
        local icon = C_Item.GetItemIconByID(id)
        if not icon then RequestItem(id) end
        return icon
    elseif (kind == "spell" or kind == "enchant") and C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(id)
    elseif kind == "achievement" and GetAchievementInfo then
        return select(10, GetAchievementInfo(id))
    elseif kind == "currency" and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(id)
        return info and info.iconFileID
    elseif kind == "battlepet" and C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
        return select(2, C_PetJournal.GetPetInfoBySpeciesID(id))
    end
    return nil
end





local KIND_ICON = {
    [Store.KIND.EFLINK] = ns.LINK_ICON_TEX,
    [Store.KIND.URL] = ns.LINK_ICON_TEX,
    [Store.KIND.COMMAND] = ns.COMMANDS_ICON_TEX,
    [Store.KIND.NUMBER] = "Interface\\AddOns\\EasyFind\\textures\\calculator-icon",
}
local MAPPIN_ATLAS = "Waypoint-MapPin-ChatIcon"


local QUESTION_MARK_ICON = 134400
local function IconFor(entry)
    if entry.icon and entry.icon ~= QUESTION_MARK_ICON then return entry.icon end

    if entry.kind == Store.KIND.MAPPIN then return nil end
    if entry.link then return LinkIcon(entry.link) or ns.LINK_ICON_TEX or GENERIC_ICON end
    if entry.kind == Store.KIND.TEXT then return nil end
    return KIND_ICON[entry.kind] or ns.CLIPBOARD_ICON_TEX or GENERIC_ICON
end



local function Midnight(now)
    local t = date("*t", now)
    t.hour, t.min, t.sec = 0, 0, 0
    return time(t)
end
local function GroupLabel(at, midnight)
    at = at or midnight
    if at >= midnight then return L["CLIP_GROUP_TODAY"] end
    if at >= midnight - 86400 then return L["CLIP_GROUP_YESTERDAY"] end
    if at >= midnight - 6 * 86400 then return L["CLIP_GROUP_WEEK"] end
    return L["CLIP_GROUP_OLDER"]
end

local function Ago(now, at)
    local delta = now - (at or now)
    if delta < 60 then return L["CLIP_JUST_NOW"] end
    local text = SecondsToTime and SecondsToTime(delta, true, false, 1) or (math.floor(delta / 60) .. "m")
    return sformat(L["CLIP_AGO"], text)
end

local function Subtext(entry, now)
    local who
    if entry.source == Store.SOURCE.CHAT then
        who = entry.sender or ""
        if entry.channel and entry.channel ~= "" then
            who = (who ~= "" and (who .. " ") or "") .. "(" .. entry.channel .. ")"
        end
    elseif entry.source == Store.SOURCE.PASTED then
        who = L["CLIP_PASTED"]
    elseif entry.source == Store.SOURCE.SENT then
        who = (entry.channel and entry.channel ~= "") and sformat(L["CLIP_SENT_FMT"], entry.channel) or L["CLIP_SENT"]
    else
        who = L["CLIP_COPIED"]
    end
    local out = who .. ", " .. Ago(now, entry.at)
    if (entry.count or 1) > 1 then out = out .. " x" .. entry.count end
    return out
end


local function RowName(entry)
    if entry.link then
        local bracket = smatch(entry.text, "^%[.-%]$")
        if bracket and bracket ~= "[]" then return bracket end
    end
    return Store.FirstLine(entry.text)
end




local KIND_DB_KEY = {
    [Store.KIND.LINK] = "clipboardKindLink", [Store.KIND.EFLINK] = "clipboardKindEflink",
    [Store.KIND.MAPPIN] = "clipboardKindMappin", [Store.KIND.URL] = "clipboardKindUrl",
    [Store.KIND.COMMAND] = "clipboardKindCommand", [Store.KIND.NUMBER] = "clipboardKindNumber",
    [Store.KIND.TEXT] = "clipboardKindText",
}
Clipboard.KIND_DB_KEY = KIND_DB_KEY

function Clipboard:IsKindShown(kind)
    local db = EasyFind and EasyFind.db
    local key = KIND_DB_KEY[kind]
    return not (db and key and db[key] == false)
end

function Clipboard:SortMode()
    local db = EasyFind and EasyFind.db
    return (db and db.clipboardOldestFirst) and "oldest" or "newest"
end

local function SortedEntries(list, mode)
    if mode == "newest" then return list end
    local out = {}
    for i = 1, #list do out[i] = list[i] end
    if mode == "oldest" then
        table.sort(out, function(a, b) return (a.at or 0) < (b.at or 0) end)
    elseif mode == "used" then
        table.sort(out, function(a, b)
            local ca, cb = a.count or 1, b.count or 1
            if ca ~= cb then return ca > cb end
            return (a.at or 0) > (b.at or 0)
        end)
    end
    return out
end

function Clipboard:BuildSearchData()
    self._populated = true
    local entries = {}
    local now = time()
    local midnight = Midnight(now)
    local sortMode = self:SortMode()
    local list = SortedEntries(Store:Entries(), sortMode)

    local pinnedLabel = L["CLIP_GROUP_PINNED"]
    do
        local pinned, rest = {}, {}
        for i = 1, #list do
            if list[i].pinned then pinned[#pinned + 1] = list[i] else rest[#rest + 1] = list[i] end
        end
        if #pinned > 0 then
            table.sort(pinned, function(a, b) return (a.pinned or 0) > (b.pinned or 0) end)
            for i = 1, #rest do pinned[#pinned + 1] = rest[i] end
            list = pinned
        end
    end

    local grouped = sortMode ~= "used"
    for i = 1, #list do
        Utils.SliceCheckpoint()
        local entry = list[i]
        local name = self:IsKindShown(entry.kind) and RowName(entry) or nil
        if name and name ~= "" then
            local icon = IconFor(entry)


            local keywords = {}
            local body = Utils.StripMarkup and Utils.StripMarkup(entry.text) or entry.text
            if body and body ~= "" then
                keywords[#keywords + 1] = slower(Store.CutBytes(body, 300))
            end
            if entry.sender then keywords[#keywords + 1] = slower(entry.sender) end
            entries[#entries + 1] = {
                name = name,
                nameHex = LinkNameHex(entry.link),
                nameLower = slower(name),
                category = "Clipboard",
                keywordsLower = keywords,
                searchCommandDesc = Subtext(entry, now),
                icon = icon,
                clipLetter = (not icon and entry.kind == Store.KIND.TEXT) and "T" or nil,
                clipID = entry.id,
                clipText = entry.text,
                clipLink = entry.link,
                clipKind = entry.kind,
                clipSource = entry.source,
                clipAtlas = entry.kind == Store.KIND.MAPPIN and MAPPIN_ATLAS or nil,
                clipGroup = entry.pinned and pinnedLabel
                    or (grouped and GroupLabel(entry.at, midnight) or nil),


                noPin = true,
            }
        end
    end


    for k = 1, #entries do entries[k].clipOrder = k end



    if #entries == 0 and #list > 0 then

        entries[1] = {
            name = L["CLIP_EMPTY_TYPES"],
            nameLower = "",
            category = "Clipboard",
            keywordsLower = {},
            clipGroup = L["CLIP_EMPTY_TYPES"],
            clipDividerOnly = true,
            noPin = true,
            noLearn = true,
        }
    end
    return entries
end



function Clipboard:LastCopiedRow()
    local db = EasyFind and EasyFind.db
    if not (db and db.clipboardLastCopiedRow) then return nil end
    local entries = Store:Entries()
    local entry
    for i = 1, #entries do
        if entries[i].source == Store.SOURCE.COPIED then entry = entries[i] break end
    end
    if not entry then return nil end
    local name = RowName(entry)
    local icon = IconFor(entry)
    return {
        name = sformat(L["CLIP_LAST_COPIED_FMT"], name), nameHex = LinkNameHex(entry.link), nameLower = slower(name),
        category = "Clipboard", searchCommandDesc = Subtext(entry, time()), icon = icon,
        clipLetter = (not icon and entry.kind == Store.KIND.TEXT) and "T" or nil,
        clipID = entry.id, clipText = entry.text, clipLink = entry.link, clipKind = entry.kind,
        clipSource = entry.source, clipAtlas = entry.kind == Store.KIND.MAPPIN and MAPPIN_ATLAS or nil,
        noPin = true, noLearn = true,
    }
end




function Clipboard:Activate(id)
    local entry = Store:Get(id)
    if not entry then return end
    local payload = entry.link or (sgsub(entry.text, "[\r\n]+", " "))

    if entry.link and not sfind(payload, "|c", 1, true) then
        payload = "|cffffffff" .. payload .. "|r"
    end
    local chooser = (ChatFrameUtil and ChatFrameUtil.ChooseBoxForSend) or ChatEdit_ChooseBoxForSend
    local editBox = chooser and chooser() or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox) or ChatFrame1EditBox
    if editBox and not editBox:IsShown() then
        local activate = (ChatFrameUtil and ChatFrameUtil.ActivateChat) or ChatEdit_ActivateChat
        if activate then activate(editBox) else editBox:Show(); editBox:SetFocus() end
    end
    local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
    if not (insert and insert(payload)) and editBox then
        editBox:Insert(payload)
    end


    if editBox then
        Utils.SafeAfter(0, function()
            if editBox:IsShown() and not editBox:HasFocus() then editBox:SetFocus() end
        end)
    end
end

function Clipboard:TogglePin(id)
    local entry = Store:Get(id)
    if not entry then return end
    if Store:SetPinned(id, not entry.pinned) then self:Refresh(true) end
end


function Clipboard:PruneNow()
    Store:Prune()
    self:Refresh(true)
end




function Clipboard:SaveAsSnippet(id)
    local entry = Store:Get(id)
    if not entry then return end
    EasyFind.API.CallAction("snippets", "create", entry.link or entry.text, Store.FirstLine(entry.text))
end

function Clipboard:Delete(id)
    if Store:Remove(id) then self:Refresh(true) end
end

function Clipboard:ClearWithConfirm()
    if not ns.ShowThemedDialog then
        Store:Clear()
        self:Refresh(true)
        return
    end
    ns.ShowThemedDialog({
        text = L["CLIP_CLEAR_CONFIRM"],
        acceptText = _G["DELETE"] or "Delete",
        onAccept = function()
            Store:Clear()
            Clipboard:Refresh(true)
        end,
    })
end




function Clipboard:OpenList()
    EasyFind.API.ShowScope("clipboard")
end



Utils.OnClipboardCopied = function(text, link, icon) Clipboard:RecordCopied(text, link, icon) end


if hooksecurefunc and SendChatMessage then
    hooksecurefunc("SendChatMessage", function(msg, chatType, _, target) Clipboard:RecordSent(msg, chatType, target) end)
end



if ns.Filters and ns.Filters.ApplyQuickFilter then
    Utils.PostHook(ns.Filters, "ApplyQuickFilter", function(_, def)
        if def and def.key == "clipboard" then
            Utils.SafeAfter(0, function() Clipboard:RefreshIfStale() end)
        end
    end)
end
Utils.OnPasteChunk = function(_, chunk) Clipboard:RecordPasted(chunk) end

local addFilter = _G["ChatFrame_AddMessageEventFilter"]
if addFilter then
    for i = 1, #CHAT_EVENTS do
        addFilter(CHAT_EVENTS[i], ChatLinkFilter)
    end
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:RegisterEvent("ADDON_LOADED")
loginFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then

        if addonName == "Blizzard_MacroUI" then
            self:UnregisterEvent("ADDON_LOADED")
            if MacroFrameText and Utils.AttachPasteLinkSwap then
                Utils.AttachPasteLinkSwap(MacroFrameText)
            end
        end
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    Store:Prune()

    Utils.SafeAfter(6, function() Clipboard:BackfillIcons() end)
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_MacroUI")
       and MacroFrameText and Utils.AttachPasteLinkSwap then
        self:UnregisterEvent("ADDON_LOADED")
        Utils.AttachPasteLinkSwap(MacroFrameText)
    end
end)



local SOURCES = {
    { "clipboardCopied", "CLIP_OPT_COPIED" }, { "clipboardPasted", "CLIP_OPT_PASTED" },
    { "clipboardChat", "CLIP_OPT_CHAT" }, { "clipboardWhispers", "CLIP_OPT_WHISPERS" },
    { "clipboardSent", "CLIP_OPT_SENT" }, { "clipboardLastCopiedRow", "CLIP_OPT_LAST_ROW" },
}

local function SettingRows()
    local rows = {}
    for _, s in ipairs(SOURCES) do
        local key = s[1]
        rows[#rows + 1] = { name = L[s[2]], control = { kind = "check", tooltip = L[s[2] .. "_TT"],
            get = function() return EasyFind.db[key] ~= false end,
            set = function(on) EasyFind.db[key] = on end } }
    end
    local counts = {}
    for _, n in ipairs({ 100, 200, 500, 1000 }) do counts[#counts + 1] = { label = tostring(n), value = n } end
    rows[#rows + 1] = { name = L["CLIP_OPT_KEEP_COUNT"], control = { kind = "choice", tooltip = L["CLIP_OPT_KEEP_COUNT_TT"],
        choices = counts, default = 200,
        get = function() return tonumber(EasyFind.db.clipboardMaxEntries) or 200 end,
        set = function(v)
            EasyFind.db.clipboardMaxEntries = v
            Clipboard:PruneNow()
        end } }
    local days = {}
    for _, d in ipairs({ 7, 30, 90 }) do days[#days + 1] = { label = Utils.sformat(L["CLIP_DAYS_FMT"], d), value = d } end
    days[#days + 1] = { label = L["CLIP_KEEP_FOREVER"], value = 0 }
    rows[#rows + 1] = { name = L["CLIP_OPT_KEEP_DAYS"], control = { kind = "choice", tooltip = L["CLIP_OPT_KEEP_DAYS_TT"],
        choices = days, default = 30,
        get = function() return tonumber(EasyFind.db.clipboardMaxDays) or 30 end,
        set = function(v)
            EasyFind.db.clipboardMaxDays = v
            Clipboard:PruneNow()
        end } }
    rows[#rows + 1] = { name = L["OPT_KEYBIND_CLIPBOARD"], control = { kind = "keybind", action = "EASYFIND_CLIPBOARD" } }
    rows[#rows + 1] = { name = L["CTX_CLIP_CLEAR"], control = { kind = "button",
        press = function() Clipboard:ClearWithConfirm() end } }
    return rows
end

local function BuildSettings(page, kit)
    local anchor = kit.Title(page, L["FILTER_CLIPBOARD"], L["OPT_CLIPBOARD_HINT"])
    local rows = SettingRows()
    for i = 1, #SOURCES do
        local c = rows[i].control
        local box = kit.Checkbox(page, rows[i].name, c.get, c.set, c.tooltip)
        box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, i == 1 and -8 or -2)
        anchor = box
    end
    local function ChoiceOf(row)
        local c = row.control
        return kit.Choice(page, row.name, c.choices, c.get, c.set, c.tooltip, c.default)
    end
    local keepCount = ChoiceOf(rows[#SOURCES + 1])
    keepCount:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -8, -8)
    local keepDays = ChoiceOf(rows[#SOURCES + 2])
    keepDays:SetPoint("TOPLEFT", keepCount, "BOTTOMLEFT", 0, -4)
    local bind = kit.Keybind(page, L["OPT_KEYBIND_CLIPBOARD"], "EASYFIND_CLIPBOARD", L["OPT_KB_CLIPBOARD_TT_DESC"])
    bind:SetPoint("TOPLEFT", keepDays, "BOTTOMLEFT", 0, -4)
    local clear = kit.Button(page, L["CTX_CLIP_CLEAR"], 140, 22)
    clear:SetPoint("TOPLEFT", bind, "BOTTOMLEFT", 8, -12)
    clear:SetScript("OnClick", function() Clipboard:ClearWithConfirm() end)
end


EasyFind.API.RegisterExtension({
    id = "clipboard", name = L["FILTER_CLIPBOARD"], description = L["APP_DESC_CLIPBOARD"],
    icon = ns.CLIPBOARD_ICON_TEX, iconCoords = ns.CLIPBOARD_ICON_COORDS,
    keywords = { "clipboard", "clipboard history", "history" },
    scope = "clipboard", settings = BuildSettings, settingsRows = SettingRows,
})




local function RefreshView() Clipboard:Refresh(true) end
local Opt = ns.Extensions.DbOption
EasyFind.API.RegisterSearchProvider({
    key = "clipboard", category = "Clipboard", extension = "clipboard",
    label = L["FILTER_CLIPBOARD"], icon = ns.CLIPBOARD_ICON_TEX, iconCoords = ns.CLIPBOARD_ICON_COORDS,
    eager = true, aliases = { "clip", "clips", "clipboard", "history" },
    options = {
        Opt("clipboardCopied", L["CLIP_OPT_COPIED"], L["CLIP_OPT_COPIED_TT"]),
        Opt("clipboardPasted", L["CLIP_OPT_PASTED"], L["CLIP_OPT_PASTED_TT"]),
        Opt("clipboardChat", L["CLIP_OPT_CHAT"], L["CLIP_OPT_CHAT_TT"]),
        Opt("clipboardWhispers", L["CLIP_OPT_WHISPERS"], L["CLIP_OPT_WHISPERS_TT"]),
        Opt("clipboardSent", L["CLIP_OPT_SENT"], L["CLIP_OPT_SENT_TT"]),
        Opt("clipboardLastCopiedRow", L["CLIP_OPT_LAST_ROW"], L["CLIP_OPT_LAST_ROW_TT"]),
        { header = L["CLIP_OPT_SHOW"] },
        Opt("clipboardKindLink", L["CLIP_KIND_LINK"], nil, RefreshView),
        Opt("clipboardKindEflink", L["CLIP_KIND_EFLINK"], nil, RefreshView),
        Opt("clipboardKindMappin", L["CLIP_KIND_MAPPIN"], nil, RefreshView),
        Opt("clipboardKindUrl", L["CLIP_KIND_URL"], nil, RefreshView),
        Opt("clipboardKindCommand", L["CLIP_KIND_COMMAND"], nil, RefreshView),
        Opt("clipboardKindNumber", L["CLIP_KIND_NUMBER"], nil, RefreshView),
        Opt("clipboardKindText", L["CLIP_KIND_TEXT"], nil, RefreshView),
        { separator = true },
        Opt("clipboardOldestFirst", L["CLIP_OPT_OLDEST_FIRST"], L["CLIP_OPT_OLDEST_FIRST_TT"], RefreshView),
    },
    rows = function() return Clipboard:BuildSearchData() end,

    select = function(row) if row.clipID then Clipboard:Activate(row.clipID) end end,


    tooltip = function(row, tip)
        local pane = Clipboard.Pane
        if not row.clipID or not row.clipLink or (pane and pane.IsActive and pane:IsActive()) then return false end
        tip:SetHyperlink(row.clipLink)
        return true
    end,
    leave = function(row)
        local pane = Clipboard.Pane
        if row.clipID and pane and pane.OnRowLeave then pane:OnRowLeave() end
    end,
})
