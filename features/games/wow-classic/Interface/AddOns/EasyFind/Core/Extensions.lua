local _, ns = ...

local L = ns.L
local API = EasyFind.API




API.RegisterExtension({
    id = "icons", addon = "EasyFind_Icons",
    name = L["ICON_SEARCH_APP"], description = L["APP_DESC_ICONS"],
    icon = ns.ICON_SEARCH_ICON_TEX,
    keywords = { "icons", "icon search" },
})


local function BuildNotesSettings(page, kit)
    local anchor = kit.Title(page, L["APP_NOTES"], L["NOTES_OPT_HINT"])
    local options = { { "notesHereFilter", "NOTES_OPT_HERE" }, { "notesTooltips", "NOTES_OPT_TOOLTIPS" },
                      { "notesChatNames", "NOTES_OPT_CHAT_NAMES" }, { "notesPlayerMenu", "NOTES_OPT_PLAYER_MENU" },
                      { "notesClickHint", "NOTES_OPT_CLICK_HINT" }, { "notesShopOffer", "NOTES_OPT_SHOP_OFFER" },
                      { "notesPriceLines", "NOTES_OPT_PRICE_LINES" }, { "notesPriceTotal", "NOTES_OPT_PRICE_TOTAL" } }
    local function Changed()
        if API.HasAction("notes", "refresh") then API.CallAction("notes", "refresh") end
        if ns.Notes and ns.Notes.PricesChanged then ns.Notes.PricesChanged() end
    end
    for i, o in ipairs(options) do
        local key = o[1]
        local box = kit.Checkbox(page, L[o[2]], function() return EasyFind.db[key] ~= false end,
            function(on)
                EasyFind.db[key] = on
                Changed()
            end, L[o[2] .. "_TT"])
        box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, i == 1 and -8 or -2)
        anchor = box
    end

    local offered = ns.PriceChoices and ns.PriceChoices() or {}
    if #offered > 0 then
        local any = ns.PRICE_ANY
        local choices = { { value = any, label = L["NOTES_PRICES_ANY"] } }
        for _, c in ipairs(offered) do choices[#choices + 1] = c end
        local row = kit.Choice(page, L["NOTES_OPT_PRICE_SOURCE"], choices,
            function() return EasyFind.db.notesPriceSource or any end,
            function(v)
                if v == any then EasyFind.db.notesPriceSource = nil else EasyFind.db.notesPriceSource = v end
                Changed()
            end, nil, any)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
        anchor = row
    end
    local open = kit.Button(page, L["NOTES_OPT_OPEN"], 140, 22)
    open:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 8, -12)
    open:SetScript("OnClick", function() API.OpenExtension("notes") end)
end

API.RegisterExtension({
    id = "notes", addon = "EasyFind_Notes", loadInCombat = true,
    name = L["APP_NOTES"], description = L["APP_DESC_NOTES"],
    icon = ns.NOTES_ICON_TEX, iconCoords = ns.NOTES_ICON_COORDS, experimental = L["NOTES_EXP_TT"],
    keywords = { "notes" }, settings = BuildNotesSettings,
})


API.RegisterSearchProvider({
    key = "notes", category = "Notes", extension = "notes",
    label = L["APP_NOTES"], icon = ns.NOTES_ICON_TEX, iconCoords = ns.NOTES_ICON_COORDS,
    words = { "note", "notes" }, lowResults = true, eager = true, aliases = { "note", "notes" },

    link = {
        key = function(row) return row.noteID and API.CallAction("notes", "linkKey", row.noteID) or nil end,
        resolve = function(tail) return API.CallAction("notes", "linkRow", tail) end,
    },
    options = {
        ns.Extensions.DbOption("notesHereFilter", L["NOTES_OPT_HERE"], L["NOTES_OPT_HERE_TT"]),
        ns.Extensions.DbOption("notesTooltips", L["NOTES_OPT_TOOLTIPS"], L["NOTES_OPT_TOOLTIPS_TT"]),
        ns.Extensions.DbOption("notesChatNames", L["NOTES_OPT_CHAT_NAMES"], L["NOTES_OPT_CHAT_NAMES_TT"]),
        ns.Extensions.DbOption("notesPlayerMenu", L["NOTES_OPT_PLAYER_MENU"], L["NOTES_OPT_PLAYER_MENU_TT"]),
        ns.Extensions.DbOption("notesClickHint", L["NOTES_OPT_CLICK_HINT"], L["NOTES_OPT_CLICK_HINT_TT"]),
        ns.Extensions.DbOption("notesShopOffer", L["NOTES_OPT_SHOP_OFFER"], L["NOTES_OPT_SHOP_OFFER_TT"]),
        ns.Extensions.DbOption("notesPriceLines", L["NOTES_OPT_PRICE_LINES"], L["NOTES_OPT_PRICE_LINES_TT"],
            function() if ns.Notes and ns.Notes.PricesChanged then ns.Notes.PricesChanged() end end),
        ns.Extensions.DbOption("notesPriceTotal", L["NOTES_OPT_PRICE_TOTAL"], L["NOTES_OPT_PRICE_TOTAL_TT"],
            function() if ns.Notes and ns.Notes.PricesChanged then ns.Notes.PricesChanged() end end),
        ns.Extensions.DbOption("notesSurfaceHere", L["NOTES_OPT_SURFACE"], L["NOTES_OPT_SURFACE_TT"]),
    },
})


ns.AddThemeSurface("notes", L["APP_NOTES"], { addon = "EasyFind_Notes" })








local PAGE = "https://www.curseforge.com/wow/addons/"
local PAGE_LINK = "easyfind:page:"
local EXTENSIONS_LINK = "easyfind:extensions"
local MENU_CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
local FIRST_EXTENSIONS = "4.0.0"
local TEX = "Interface\\AddOns\\EasyFind\\textures\\"
local CLASSICS_AND_FOREVER = { "era", "tbc", "mists", "forever" }
local FIRST_PARTY = {
    { addon = "EasyFind_GPS", project = "EasyFind: GPS Navigation Extension", slug = "easyfind-gps-navigation-extension",
      name = L["APP_GPS"], bundled = { "4.0.0", "4.0.2" }, min = "1.6.0",
      title = L["APP_GPS"], icon = TEX .. "gps-icon", blurb = L["EXT_CARD_GPS"] },
    { addon = "EasyFind_Notes", project = "EasyFind: Notes Extension", slug = "easyfind-notes-extension",
      name = L["APP_NOTES"], bundled = { "4.0.0", "5.0.0" },
      title = L["APP_NOTES"], icon = TEX .. "notes-icon", blurb = L["EXT_CARD_NOTES"] },
    { addon = "EasyFind_Chat", project = "EasyFind: Chat Extension", slug = "easyfind-chat-extension",
      name = L["APP_CHAT"], bundled = { "4.0.0", "4.0.2" },
      title = L["APP_CHAT"], icon = TEX .. "ext-chat", blurb = L["EXT_CARD_CHAT"] },
    { addon = "EasyFind_Questie", project = "EasyFind: Questie Extension", slug = "easyfind-questie-extension",
      title = "Questie", icon = TEX .. "ext-questie", blurb = L["EXT_CARD_QUESTIE"], games = CLASSICS_AND_FOREVER },
    { addon = "EasyFind_HandyNotes", project = "EasyFind: HandyNotes Extension", slug = "easyfind-handynotes-extension",
      title = "HandyNotes", icon = TEX .. "ext-handynotes", blurb = L["EXT_CARD_HANDYNOTES"], games = { "retail", "forever" } },
    { addon = "EasyFind_Auctionator", project = "EasyFind: Auctionator Extension", slug = "easyfind-auctionator-extension",
      title = "Auctionator", icon = TEX .. "ext-auctionator", blurb = L["EXT_CARD_AUCTIONATOR"] },
    { addon = "EasyFind_DungeonJournal", project = "EasyFind: DungeonJournal Extension", slug = "easyfind-dungeonjournal-extension",
      title = "DungeonJournal", icon = TEX .. "ext-dungeonjournal", blurb = L["EXT_CARD_DUNGEONJOURNAL"], games = { "era", "forever" } },
    { addon = "EasyFind_ClassicBestiary", project = "EasyFind: Classic Bestiary Extension", slug = "easyfind-classic-bestiary-extension",
      title = "Classic Bestiary", icon = TEX .. "ext-bestiary", blurb = L["EXT_CARD_BESTIARY"], games = { "era", "forever" } },
    { addon = "EasyFind_Spoken", project = "EasyFind: Spoken Extension", slug = "easyfind-spoken-extension",
      title = "Spoken", icon = TEX .. "ext-spoken", blurb = L["EXT_CARD_SPOKEN"], games = { "era", "tbc", "forever" } },
    { addon = "EasyFind_ATT", project = "EasyFind: ALL THE THINGS Extension", slug = "easyfind-all-the-things-extension",
      title = "ALL THE THINGS", icon = TEX .. "ext-att", blurb = L["EXT_CARD_ATT"] },
}
ns.FirstPartyExtensions = FIRST_PARTY


function ns.ExtensionRunsHere(e)
    if not e.games then return true end
    local Caps = ns.Caps
    for _, g in ipairs(e.games) do
        if Caps and Caps[g] then return true end
    end
    return false
end



local function OldCopy(addon)
    if not C_AddOns.DoesAddOnExist(addon) then return false end
    for _, e in ipairs(FIRST_PARTY) do
        local b = e.bundled
        if e.addon == addon and b then
            local v = C_AddOns.GetAddOnMetadata(addon, "Version")
            return v ~= nil and ns.CompareVersion(v, b[1]) >= 0 and ns.CompareVersion(v, b[2]) < 0
        end
    end
    return false
end
ns.OldExtensionCopy = OldCopy

local function Installed(addon) return C_AddOns.DoesAddOnExist(addon) and not OldCopy(addon) end
ns.ExtensionInstalled = Installed


local function Went(from)
    local out = {}
    for _, e in ipairs(FIRST_PARTY) do
        local b = e.bundled
        if b and ns.CompareVersion(from, b[1]) >= 0 and ns.CompareVersion(from, b[2]) < 0 then out[#out + 1] = e end
    end
    return out
end


local function Join(list)
    if #list < 2 then return list[1] or "" end
    return L["EXT_AND_FMT"]:format(table.concat(list, ", ", 1, #list - 1), list[#list])
end


function ns.ShowExtensionPage(slug)
    for _, e in ipairs(FIRST_PARTY) do
        if e.slug == slug then
            ns.ShowThemedDialog({ text = e.project .. "\n" .. L["EXT_PAGE_COPY"], hasEditBox = true, readOnly = true,
                editBoxDefault = PAGE .. slug, single = true, acceptText = _G["OKAY"] or "Okay" })
            return
        end
    end
end




function ns.ExtensionTipLink(addon, label)
    local db = EasyFind.db
    if (db and db.hideExtensionTips) or Installed(addon) then return nil end
    for _, e in ipairs(FIRST_PARTY) do
        if e.addon == addon and e.slug then
            local c = ns.LINK_COLOR or { 0.44, 0.84, 1.0 }
            local function Hex(v) return math.floor(v * 255 + 0.5) end
            return string.format("|cff%02x%02x%02x|H%s%s|h%s|h|r", Hex(c[1]), Hex(c[2]), Hex(c[3]), PAGE_LINK, e.slug, label)
        end
    end
end


function ns.ExtensionTipClick(link)
    local slug = type(link) == "string" and link:sub(1, #PAGE_LINK) == PAGE_LINK and link:sub(#PAGE_LINK + 1)
    if not slug or slug == "" then return false end
    ns.ShowExtensionPage(slug)
    return true
end



function ns.ShowExtensionPages()
    local rows = {}
    for _, e in ipairs(FIRST_PARTY) do
        if e.slug and ns.ExtensionRunsHere(e) then
            local have = Installed(e.addon)
            rows[#rows + 1] = { text = e.project, icon = have and MENU_CHECK or nil,
                tooltip = have and L["EXT_INSTALLED"] or L["EXT_PAGE_TT"],
                onClick = function() ns.ShowExtensionPage(e.slug) end }
        end
    end
    ns.Utils.ShowCursorMenu("EasyFindExtensionPagesMenu", rows, { iconSide = "left" })
end






function ns.NoteUpgrade(from)
    if ns.CompareVersion(from, FIRST_EXTENSIONS) < 0 or #Went(from) > 0 then EasyFind.db.extensionsNoticeFrom = from end
end


local function TellExtensions(installed)
    local db = EasyFind.db
    local from = db and db.extensionsNoticeFrom
    if not from or InCombatLockdown() then return end
    db.extensionsNoticeFrom = nil
    installed = installed or Installed
    local pages = ns.BlueChatLink(EXTENSIONS_LINK, L["FILTER_EXTENSIONS"])
    local went = Went(from)
    local msg
    if ns.CompareVersion(from, FIRST_EXTENSIONS) < 0 or #went == 0 then
        msg = L["EXT_NEW_FMT"]:format(ns.version, pages)
    else
        local names, missing = {}, {}
        for _, e in ipairs(went) do
            names[#names + 1] = e.name
            if e.slug and not installed(e.addon) then missing[#missing + 1] = ns.BlueChatLink(PAGE_LINK .. e.slug, e.project) end
        end
        msg = L[#went == 1 and "EXT_WENT_ONE_FMT" or "EXT_WENT_MANY_FMT"]:format(ns.version, Join(names))
        if #missing > 0 then
            msg = msg .. " " .. L[#missing == 1 and "EXT_GET_ONE_FMT" or "EXT_SPLIT_GET_FMT"]:format(Join(missing))
        end
        msg = msg .. " " .. L["EXT_OTHERS_FMT"]:format(pages)
    end
    print(ns.CHAT_LOGO .. msg)
end
ns.TellExtensions = TellExtensions


function ns.TellExtensionGone(addon)
    for _, e in ipairs(FIRST_PARTY) do
        if e.addon == addon and e.name then
            local msg = L["EXT_WENT_ONE_FMT"]:format(ns.version, e.name)
            if e.slug then msg = msg .. " " .. L["EXT_GET_ONE_FMT"]:format(ns.BlueChatLink(PAGE_LINK .. e.slug, e.project)) end
            print(ns.CHAT_LOGO .. msg)
            return
        end
    end
end



local function TellOutdated()
    for _, e in ipairs(FIRST_PARTY) do
        local v = e.min and C_AddOns.IsAddOnLoaded(e.addon) and C_AddOns.GetAddOnMetadata(e.addon, "Version")
        if v and ns.CompareVersion(v, e.min) < 0 then
            print(ns.CHAT_LOGO .. L["EXT_OUTDATED_FMT"]:format(ns.BlueChatLink(PAGE_LINK .. e.slug, e.project), v))
        end
    end
end
ns.TellOutdatedExtensions = TellOutdated

local noticeWatch = CreateFrame("Frame")
noticeWatch:Hide()
noticeWatch:RegisterEvent("PLAYER_LOGIN")
noticeWatch:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(10, function()
        TellExtensions()
        TellOutdated()
    end)
end)
