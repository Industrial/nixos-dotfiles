local _, ns = ...




local Social = {}
ns.Social = Social

local Database, Utils, L = ns.Database, ns.Utils, ns.L
local ipairs, pairs = Utils.ipairs, Utils.pairs
local sformat, slower = Utils.sformat, Utils.slower

local CLASS_SHEET = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local GLYPH = { friend = { tex = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon" },
                guild = { tex = "Interface\\GossipFrame\\TabardGossipIcon" } }
local FRIEND_WORDS, GUILD_WORDS = { "friend", "friends" }, { "guild", "guildie", "member" }


local classOf
local function ClassToken(className)
    if not className then return nil end
    if not classOf then
        classOf = {}
        for _, names in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
            for token, name in pairs(names) do classOf[name] = token end
        end
    end
    return classOf[className]
end

local classGlyphs = {}
local function Glyph(class, kind)
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if not coords then return GLYPH[kind] end
    classGlyphs[class] = classGlyphs[class] or { tex = CLASS_SHEET, coords = coords }
    return classGlyphs[class]
end

local function ClassHex(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local floor = math.floor
    return c and sformat("|cff%02x%02x%02x", floor(c.r * 255), floor(c.g * 255), floor(c.b * 255)) or nil
end


local function Line(online, level, className, area)
    if not online then return _G["FRIENDS_LIST_OFFLINE"] or "Offline" end
    local text = level and level > 0 and sformat(_G["UNIT_LEVEL_TEMPLATE"] or L["CHAR_LEVEL_FMT"], level) or nil
    if className and className ~= "" then text = text and (text .. " " .. className) or className end
    if area and area ~= "" then text = text and (text .. ", " .. area) or area end
    return text or (_G["FRIENDS_LIST_ONLINE"] or "Online")
end



local function Row(category, kind, words, name, class, line, who, bnet)
    local lower = slower(name)
    local kw = { lower }
    for i = 1, #words do kw[#kw + 1] = words[i] end
    return {
        name = name, nameLower = lower, category = category, keywords = kw, keywordsLower = kw,
        nameHex = ClassHex(class), glyph = Glyph(class, kind), searchCommandDesc = line,
        socialName = who, socialBNet = bnet, noPin = true, noLearn = true,
    }
end

local function Short(fullName)
    return Ambiguate and Ambiguate(fullName, "short") or (fullName:gsub("%-.*$", ""))
end

local asked = {}
local function AskOnce(key, request)
    local now = GetTime()
    if request and (not asked[key] or now - asked[key] > 30) then
        asked[key] = now
        request()
    end
end

function Database:PopulateDynamicFriends()
    Database.RemoveEntriesByCategory("Friend")
    if self.ResetSearchCache then self:ResetSearchCache() end
    local rows, seen = self.uiSearchData, {}
    local Friends = C_FriendList
    if Friends and Friends.GetNumFriends and Friends.GetFriendInfoByIndex then
        AskOnce("friends", Friends.ShowFriends)
        for index = 1, Friends.GetNumFriends() or 0 do
            local info = Friends.GetFriendInfoByIndex(index)
            if info and info.name and info.name ~= "" then
                local class = ClassToken(info.className)
                seen[info.name] = true
                rows[#rows + 1] = Row("Friend", "friend", FRIEND_WORDS, Short(info.name), class,
                    Line(info.connected, info.level, info.className, info.area), info.name)
            end
        end
    end
    local BNet = C_BattleNet
    if BNet and BNet.GetFriendAccountInfo and BNGetNumFriends then
        for index = 1, BNGetNumFriends() or 0 do
            local account = BNet.GetFriendAccountInfo(index)
            local game = account and account.gameAccountInfo
            local playing = game and game.isOnline and game.clientProgram == (_G["BNET_CLIENT_WOW"] or "WoW")
                and game.characterName and game.characterName ~= ""
            if playing then

                local who = game.realmName and game.realmName ~= "" and (game.characterName .. "-" .. game.realmName)
                    or game.characterName
                if not seen[who] and not seen[game.characterName] then
                    rows[#rows + 1] = Row("Friend", "friend", FRIEND_WORDS, game.characterName, ClassToken(game.className),
                        Line(true, game.characterLevel, game.className, game.areaName), who)
                end
            elseif account and account.battleTag and account.battleTag ~= "" then
                local tag = account.battleTag:gsub("#.*$", "")
                rows[#rows + 1] = Row("Friend", "friend", FRIEND_WORDS, tag, nil,
                    Line(game and game.isOnline, nil, nil, game and game.richPresence), nil, account.accountName)
            end
        end
    end
    return true
end

function Database:PopulateDynamicGuildMembers()
    Database.RemoveEntriesByCategory("Guild Member")
    if self.ResetSearchCache then self:ResetSearchCache() end
    if not (IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo) then return true end
    AskOnce("guild", C_GuildInfo and C_GuildInfo.GuildRoster or _G["GuildRoster"])
    local rows, own = self.uiSearchData, UnitGUID and UnitGUID("player")
    for index = 1, GetNumGuildMembers() or 0 do
        Utils.SliceCheckpoint()
        local name, rank, _, level, className, zone, _, _, online, _, class, _, _, _, _, _, guid = GetGuildRosterInfo(index)
        if name and name ~= "" and guid ~= own then
            local line = Line(online, level, className, zone)
            if rank and rank ~= "" then line = line .. ", " .. rank end
            rows[#rows + 1] = Row("Guild Member", "guild", GUILD_WORDS, Short(name), class, line, name)
        end
    end
    return true
end


local waiting = {}
local function Later(key)
    if waiting[key] then return end
    waiting[key] = true
    Utils.SafeAfter(2, function()
        waiting[key] = nil
        if Database.MarkDynamicCategoryDirty then Database:MarkDynamicCategoryDirty(key) end
    end)
end

local watcher = CreateFrame("Frame")
local NEWS = { FRIENDLIST_UPDATE = "friends", BN_FRIEND_INFO_CHANGED = "friends", BN_FRIEND_ACCOUNT_ONLINE = "friends",
               BN_FRIEND_ACCOUNT_OFFLINE = "friends", GUILD_ROSTER_UPDATE = "guildMembers" }
for event in pairs(NEWS) do Utils.RegisterEventIfValid(watcher, event) end
watcher:SetScript("OnEvent", function(_, event) Later(NEWS[event]) end)



function Social.Whisper(row)
    if row.socialName then
        local tell = ChatFrameUtil and ChatFrameUtil.SendTell or _G["ChatFrame_SendTell"]
        if tell then tell(row.socialName) end
    elseif row.socialBNet then
        local tell = ChatFrameUtil and ChatFrameUtil.SendBNetTell or _G["ChatFrame_SendBNetTell"]
        if tell then tell(row.socialBNet) end
    end
end


function Social.Invite(row)
    local invite = C_PartyInfo and C_PartyInfo.InviteUnit or _G["InviteUnit"]
    if row.socialName and invite then invite(row.socialName) end
end

function Social.Select(row, shift)
    if shift and row.socialName then return Social.Invite(row) end
    Social.Whisper(row)
end
