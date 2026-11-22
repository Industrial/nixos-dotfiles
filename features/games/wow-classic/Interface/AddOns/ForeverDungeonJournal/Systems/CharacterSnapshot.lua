-- FDJ3 wire snapshot. No changes or new locals in Core/Journal.lua.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end
local function Array() return setmetatable({}, {__fdjArray = true}) end
local function JSON(v)
    local kind = type(v)
    if kind == "nil" then return "null" end
    if kind == "boolean" then return v and "true" or "false" end
    if kind == "number" then assert(v == v and math.abs(v) < math.huge); return tostring(v) end
    if kind == "string" then
        return '"' .. v:gsub('[%z\1-\31\\"]', function(c)
            return string.format('\\u%04x', string.byte(c))
        end) .. '"'
    end
    assert(kind == "table", "Unsupported export value")
    local out = {}
    if getmetatable(v) and getmetatable(v).__fdjArray then
        for i, value in ipairs(v) do out[i] = JSON(value) end
        return '[' .. table.concat(out, ',') .. ']'
    end
    local keys = {}
    for k in pairs(v) do keys[#keys+1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do out[#out+1] = JSON(k) .. ':' .. JSON(v[k]) end
    return '{' .. table.concat(out, ',') .. '}'
end
FDJ.ExportJSON = JSON
local function Slug(s)
    return (s:lower():gsub("\226\128\153", ""):gsub("'", ""):gsub('[^a-z0-9]+','-'):gsub('^%-+',''):gsub('%-+$',''))
end
local function Label(fn, value)
    if fn then local ok, s = pcall(fn, value); if ok and type(s) == 'string' then return s end end
    return value
end
local function SnapshotRun(r, now)
    local start = r.firstTrash or r.firstKill
    local stop = r.finalKill or r.lastBoss
    if stop and start and stop < start then start = r.firstKill or start end
    local duration
    if start then
        if r.completed and stop then duration = stop-start
        elseif not r.closed and FDJ.RunLog.Current() == r then duration = now-start
        elseif stop then duration = stop-start end
    end
    local out = {dungeon=r.dungeon or r.instanceName or '?', created=r.created or now,
        start=start, ended=r.finalKill or r.closed, completed=not not r.completed, closed=not not r.closed,
        duration=duration, capped=not not r.capped, money=r.money or 0, deaths=r.deaths or 0,
        xp=0, bosses=Array(), trash=Array(), needs=Array(), exits=Array(), deathTimes=Array(),
        trashKilled=FDJ.RunLog.TrashKilled(r), trashTotal=FDJ.RunLog.TrashTotal(r)}
    -- closed is a boolean in older saves; ended is always a timestamp or absent.
    if type(out.ended) ~= 'number' then out.ended = nil end
    local killed, shown, trash = {}, {}, {}
    for _, k in ipairs(r.kills or {}) do
        out.xp = out.xp + (k.x or 0)
        if k.b and not killed[k.b] then killed[k.b] = k end
        if not k.b and not k.wb and not k.p then
            local n = k.m or FDJ.RunLog.NpcName(k.n) or '?'
            local e = trash[n] or {name=n,count=0,xp=0}; trash[n]=e
            e.count=e.count+1; e.xp=e.xp+(k.x or 0)
        end
    end
    local function Boss(b)
        shown[b.name]=true
        local k=killed[b.name]
        out.bosses[#out.bosses+1]={name=b.name,label=Label(FDJ.LocalizeBossName,b.name),npcID=b.npcID,
            rare=not not b.rare, state=k and 'killed' or (b.rare and not (r.rareSeen and r.rareSeen[b.name]) and 'not found' or 'not killed'),
            at=k and k.t, xp=k and k.x}
    end
    local d=FDJ.DB and FDJ.DB[r.dungeon]
    for _, b in ipairs(d and d.bosses or {}) do if not b.trash and not b.recipeTab and b.name then Boss(b) end end
    for _, k in ipairs(r.kills or {}) do if k.b and not shown[k.b] then Boss({name=k.b}) end end
    for _, e in pairs(trash) do out.trash[#out.trash+1]=e end
    table.sort(out.trash,function(a,b) if a.count~=b.count then return a.count>b.count end return a.name<b.name end)
    for _, n in ipairs(r.needs or {}) do
        out.needs[#out.needs+1]={id=n.id, name=type(n.link)=='string' and n.link:match('%[(.-)%]') or nil,
            quality=FDJ.RunLogItemQuality and FDJ.RunLogItemQuality(n.id,n.link), result=n.res or 'rolling',roll=n.n,at=n.at}
    end
    for _, e in ipairs(r.exits or {}) do
        if not (r.finalKill and e.t>=r.finalKill) then
            out.exits[#out.exits+1]={at=e.t,why=e.why=='released' and 'released' or 'stepped',
                duration=e.back and e.back-e.t or (not r.closed and now-e.t or nil), open=not e.back and not r.closed}
        end
    end
    for _, t in ipairs(r.deathTimes or {}) do out.deathTimes[#out.deathTimes+1]=t end
    return out
end
-- charportrait (2.1.1, M 20 Nov 2026: "add two fields to the character
-- export ... so the website can show the character's portrait and talents"):
-- sex (2 male, 3 female) and talents, one entry per talent tree in the
-- game's tab order: n (the tree's name), p (the points spent, summed from
-- the ranks below) and t (the talents with points, { tier, column, rank } as
-- GetTalentInfo gives them). A call that fails, or a talent API that is
-- missing: talents left out, the export goes on without them.
local function Secret(v) return type(issecretvalue) == "function" and issecretvalue(v) end
local function Sex()
    if type(UnitSex) ~= "function" then return nil end
    local ok, sex = pcall(UnitSex, "player")
    if ok and not Secret(sex) and (sex == 2 or sex == 3) then return sex end
    return nil
end
-- The old talent functions (GetNumTalentTabs, GetTalentTabInfo,
-- GetTalentInfo): not in WoW Forever (M's /dump, 20 Nov 2026: "attempt to
-- call a nil value"), kept for a client that has them.
local function LegacyTalents()
    if type(GetNumTalentTabs) ~= "function" or type(GetTalentTabInfo) ~= "function"
        or type(GetNumTalents) ~= "function" or type(GetTalentInfo) ~= "function" then return nil end
    local ok, tabs = pcall(GetNumTalentTabs)
    if not ok or Secret(tabs) or type(tabs) ~= "number" or tabs < 1 then return nil end
    local trees = Array()
    for tab = 1, tabs do
        -- The tree's name is the first return in Classic Era and TBC (name,
        -- icon, pointsSpent, background) and the second from Wrath on (id,
        -- name, description, icon, pointsSpent, ...): the first string.
        local okInfo, a, b = pcall(GetTalentTabInfo, tab)
        if not okInfo then return nil end
        local name
        if type(a) == "string" and not Secret(a) then name = a
        elseif type(b) == "string" and not Secret(b) then name = b end
        if not name then return nil end
        local okNum, count = pcall(GetNumTalents, tab)
        if not okNum or Secret(count) or type(count) ~= "number" then return nil end
        local tree = { n = name, p = 0, t = Array() }
        for i = 1, count do
            -- name, icon, tier, column, rank, maxRank, ...
            local okTalent, _, _, tier, column, rank = pcall(GetTalentInfo, tab, i)
            if not okTalent or Secret(tier) or Secret(column) or Secret(rank) then return nil end
            if type(rank) == "number" and rank > 0 then
                if type(tier) ~= "number" or type(column) ~= "number" then return nil end
                local talent = Array()
                talent[1], talent[2], talent[3] = tier, column, rank
                tree.t[#tree.t + 1] = talent
                tree.p = tree.p + rank
            end
        end
        trees[#trees + 1] = tree
    end
    return trees
end

-- traittalents (2.1.1, M 20 Nov 2026: "the dump talent didn't work ... can
-- you check and maybe redo the code"): WoW Forever's talent window is the
-- game's trait tree (C_Traits; its UI: Blizzard_PlayerSpells, Camelot): one
-- tree per class, the three talent trees as its groups, side by side. Each
-- group: its name, and every node with points, { tier, column, rank, spellID,
-- nodeID } (nodeID, M 20 Nov 2026: the website builds Forever's own trees
-- from the game's trait tables, where the node is the key; spellID 0 when
-- the game gives none, so the node ID always keeps its place).
-- Tier and column come from the node's place in its group (the smallest gap
-- between two rows or columns is one step; 1 = the top row / the left
-- column); spellID is the talent's spell, for the website to check the place.
local function Num(v) return type(v) == "number" and not Secret(v) and v or nil end
local function TraitTalents()
    local T = C_Traits
    if type(T) ~= "table" or type(T.GetConfigInfo) ~= "function" or type(T.GetTreeNodes) ~= "function"
        or type(T.GetNodeInfo) ~= "function" or type(T.GetGroupDisplayInfoByTreeID) ~= "function" then return nil end
    local configID
    if type(C_ClassTalents) == "table" and type(C_ClassTalents.GetActiveConfigID) == "function" then
        local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
        if ok then configID = Num(id) end
    end
    local S = C_SpecializationInfo
    if not configID and type(S) == "table" and type(S.GetActiveSpecGroup) == "function"
        and type(S.GetCombatConfigIDForSpecGroup) == "function" then
        local ok, group = pcall(S.GetActiveSpecGroup)
        if ok and Num(group) then
            local ok2, id = pcall(S.GetCombatConfigIDForSpecGroup, group)
            if ok2 then configID = Num(id) end
        end
    end
    if not configID then return nil end
    local okC, config = pcall(T.GetConfigInfo, configID)
    local treeID = okC and type(config) == "table" and type(config.treeIDs) == "table" and Num(config.treeIDs[1])
    if not treeID then return nil end
    local okD, displays = pcall(T.GetGroupDisplayInfoByTreeID, treeID)
    if not okD or type(displays) ~= "table" then return nil end
    local groups, index, nodeOf = {}, {}, {}
    for _, d in ipairs(displays) do
        if type(d) == "table" and Num(d.groupID) then
            groups[#groups + 1] = { id = d.groupID, order = Num(d.orderIndex) or #groups,
                name = type(d.displayName) == "string" and not Secret(d.displayName) and d.displayName or "", nodes = {} }
        end
    end
    if #groups == 0 then return nil end
    table.sort(groups, function(x, y) return x.order < y.order end)
    for i, g in ipairs(groups) do index[g.id] = i end
    local okN, nodeIDs = pcall(T.GetTreeNodes, treeID)
    if not okN or type(nodeIDs) ~= "table" then return nil end
    for _, nodeID in ipairs(nodeIDs) do
        local okI, info = pcall(T.GetNodeInfo, configID, nodeID)
        if okI and type(info) == "table" and info.isVisible ~= false and Num(info.posX) and Num(info.posY) then
            for _, groupID in ipairs(type(info.groupIDs) == "table" and info.groupIDs or {}) do
                local g = index[groupID]
                if g then
                    local nodes = groups[g].nodes
                    nodes[#nodes + 1] = info
                    nodeOf[info] = nodeID
                    break
                end
            end
        end
    end
    local function Grid(nodes, key)
        local list, seen = {}, {}
        for _, info in ipairs(nodes) do
            local v = info[key]
            if not seen[v] then seen[v] = true list[#list + 1] = v end
        end
        table.sort(list)
        local step
        for i = 2, #list do
            local gap = list[i] - list[i - 1]
            if gap > 0.5 and (not step or gap < step) then step = gap end
        end
        return list[1] or 0, step or 1
    end
    local function SpellOf(info)
        if type(T.GetEntryInfo) ~= "function" or type(T.GetDefinitionInfo) ~= "function" then return nil end
        local entryID = type(info.activeEntry) == "table" and Num(info.activeEntry.entryID)
            or type(info.entryIDs) == "table" and Num(info.entryIDs[1])
        if not entryID then return nil end
        local okE, entry = pcall(T.GetEntryInfo, configID, entryID)
        local definitionID = okE and type(entry) == "table" and Num(entry.definitionID)
        if not definitionID then return nil end
        local okF, definition = pcall(T.GetDefinitionInfo, definitionID)
        if not okF or type(definition) ~= "table" then return nil end
        return Num(definition.spellID) or Num(definition.overriddenSpellID)
    end
    local trees = Array()
    for _, g in ipairs(groups) do
        local tree = { n = g.name, p = 0, t = Array() }
        local minX, stepX = Grid(g.nodes, "posX")
        local minY, stepY = Grid(g.nodes, "posY")
        local rows = {}
        for _, info in ipairs(g.nodes) do
            local rank = Num(info.ranksPurchased) or 0
            if rank <= 0 then rank = Num(info.activeRank) or 0 end
            if rank > 0 then
                local talent = Array()
                talent[1] = math.floor((info.posY - minY) / stepY + 0.5) + 1
                talent[2] = math.floor((info.posX - minX) / stepX + 0.5) + 1
                talent[3] = rank
                talent[4] = SpellOf(info) or 0
                talent[5] = Num(info.ID) or Num(nodeOf[info]) or 0
                rows[#rows + 1] = talent
                tree.p = tree.p + rank
            end
        end
        table.sort(rows, function(x, y) if x[1] ~= y[1] then return x[1] < y[1] end return x[2] < y[2] end)
        for _, talent in ipairs(rows) do tree.t[#tree.t + 1] = talent end
        trees[#trees + 1] = tree
    end
    return trees
end

local function Talents()
    local ok, trees = pcall(LegacyTalents)
    if ok and trees then return trees end
    ok, trees = pcall(TraitTalents)
    if ok and trees then return trees end
    return nil
end
function FDJ.BuildCharacterSnapshot()
    ForeverDungeonJournalCharacterDB = ForeverDungeonJournalCharacterDB or {}
    local db=ForeverDungeonJournalCharacterDB
    if type(db.exportKey)~='string' or #db.exportKey<16 then
        -- WoW exposes no cryptographic RNG. Persist 48 draws; never reseed the shared RNG.
        local chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
        local key={}
        for i=1,48 do local n=math.random(1,#chars); key[i]=chars:sub(n,n) end
        db.exportKey=table.concat(key)
    end
    local _, race=UnitRace('player'); local _, class=UnitClass('player')
    local now=(GetServerTime and GetServerTime()) or time()
    local faction=UnitFactionGroup('player') or 'Unknown'
    local metadata=(C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local out={v=3,name=UnitName('player'),realm=GetRealmName(),raceToken=race or '',classToken=class or '',
        level=UnitLevel('player'),faction=faction,version=metadata and metadata('ForeverDungeonJournal','Version') or '2.0.4',
        exportedAt=now,exportKey=db.exportKey,rpg=FDJ.IsRPGMode and FDJ.IsRPGMode() or false,
        completed=Array(),lost=Array(),inLog=Array(),dungeons=Array(),runs=Array()}
    out.sex=Sex() -- charportrait
    local okTalents, talents=pcall(Talents)
    if okTalents then out.talents=talents end
    -- favexport (2.1.1, M 20 Nov 2026: "the items you favoured, transfer over
    -- with the code to the website"): this character's Favourites
    -- (Systems/Favourites.lua), in the Favourites window's order (dungeon,
    -- then name): id, name, dungeon (the journal's page, English), its slug,
    -- boss (English), quest (the quest an item comes from), added (time).
    out.favourites=Array()
    local favs={}
    for _, fav in pairs(type(db.favouriteItems)=='table' and db.favouriteItems or {}) do
        if type(fav)=='table' and tonumber(fav.id) then favs[#favs+1]=fav end
    end
    local order={}
    for i, name in ipairs(FDJ.ORDER or {}) do order[name]=i end
    table.sort(favs,function(a,b)
        local ad, bd=tostring(a.dungeon or ''), tostring(b.dungeon or '')
        if ad~=bd then
            local ai, bi=order[ad] or 100000, order[bd] or 100000
            if ai~=bi then return ai<bi end
            return ad<bd
        end
        local an, bn=tostring(a.name or ''), tostring(b.name or '')
        if an==bn then return tonumber(a.id)<tonumber(b.id) end
        return an<bn
    end)
    for _, fav in ipairs(favs) do
        local dungeon=type(fav.dungeon)=='string' and fav.dungeon or nil
        out.favourites[#out.favourites+1]={id=tonumber(fav.id),name=type(fav.name)=='string' and fav.name or nil,
            dungeon=dungeon,slug=dungeon and Slug(dungeon) or nil,boss=type(fav.boss)=='string' and fav.boss or nil,
            quest=tonumber(fav.questID),added=tonumber(fav.added)}
    end
    -- rpgexport (2.1.1, M 20 Nov 2026: an RPG Mode character on the website
    -- showed every dungeon): in RPG Mode the code carries what the journal
    -- shows. journey: the Journey bar (points, max, quests, questTotal,
    -- pages, pageTotal). Per dungeon: cleared = its page unlocked as the
    -- journal shows it (with Account-Wide Unlocks, the account's, and the
    -- Legacy Challenges); locked = the page can't be opened; sketch = its card
    -- is the pencil sketch (also with Show dungeon quests, where the page
    -- opens on its quests: locked false, sketch true, the quest count on the
    -- card); sketchArt = the sketch drawn on it (Media\RPG\Sketch_<id>, 0:
    -- Sketch_Unknown).
    local rpg=out.rpg
    local kills=rpg and FDJ.RPGKillsView and FDJ.RPGKillsView() or nil
    if rpg and FDJ.RPGJourney then
        local ok, points, maxPoints, quests, questTotal, pages, pageTotal=pcall(FDJ.RPGJourney)
        if ok then out.journey={points=points,max=maxPoints,quests=quests,questTotal=questTotal,pages=pages,pageTotal=pageTotal} end
    end
    local seen={}
    for _, name in ipairs(FDJ.ORDER or {}) do
        local d=FDJ.DB[name]
        local locked=FDJ.IsDungeonLocked and FDJ.IsDungeonLocked(name) or false
        local row={name=name,label=Label(FDJ.LocalizeDungeonName,name),slug=Slug(name),level=tostring(d.level or ''),
            cleared=not not ((kills and kills[name]) or (db.rpgKills and db.rpgKills[name])),locked=locked,
            previewOnly=not not d.previewOnly,quests=Array(),bosses=Array(),done=0,total=0}
        if rpg then
            row.sketch=not d.previewOnly and (locked or (FDJ.RPGSketchLocked and FDJ.RPGSketchLocked(name) or false)) or false
            row.sketchArt=FDJ.RPGSketchArt and FDJ.RPGSketchArt(name) or 0
        end
        for _, q in ipairs(d.quests or {}) do
            if q.id then
                local done=FDJ.QuestTurnedIn and FDJ.QuestTurnedIn(q.id) or false
                local lost=FDJ.IsQuestLost and FDJ.IsQuestLost(q) or false
                local inLog=FDJ.IsQuestInLog and FDJ.IsQuestInLog(q.id) or false
                if not seen[q.id] then
                    seen[q.id]=true
                    if done then out.completed[#out.completed+1]=q.id end
                    if lost then out.lost[#out.lost+1]=q.id end
                    if inLog then out.inLog[#out.inLog+1]=q.id end
                end
                if (not FDJ.QuestMatchesFaction or FDJ.QuestMatchesFaction(q,faction)) and not q.hideFromMainList and not q.repeatable
                    and (not FDJ.QuestCountsForCharacter or FDJ.QuestCountsForCharacter(q)) then -- otherclass (2.0.8)
                    row.quests[#row.quests+1]={id=q.id,name=q.name or '?',done=not not done,lost=not not lost,inLog=not not inLog,
                        locked=out.rpg and FDJ.RPGQuestHidden and FDJ.RPGQuestHidden(name,q) or false}
                    if not lost then row.total=row.total+1; if done then row.done=row.done+1 end end
                end
            end
        end
        for _, b in ipairs(d.bosses or {}) do
            if b.name and not b.trash and not b.recipeTab then
                row.bosses[#row.bosses+1]={name=b.name,label=Label(FDJ.LocalizeBossName,b.name),npcID=b.npcID,
                    locked=FDJ.RPGBossHidden and FDJ.RPGBossHidden(name,b) or false,rare=not not b.rare}
            end
        end
        out.dungeons[#out.dungeons+1]=row
    end
    table.sort(out.completed); table.sort(out.lost); table.sort(out.inLog)
    local runs={}
    for _, r in ipairs(FDJ.RunLog and FDJ.RunLog.Runs() or {}) do runs[#runs+1]=r end
    table.sort(runs,function(a,b) if (a.created or 0)==(b.created or 0) then return (a.id or 0)>(b.id or 0) end return (a.created or 0)>(b.created or 0) end)
    for i=1,math.min(100,#runs) do out.runs[#out.runs+1]=SnapshotRun(runs[i],now) end
    return out
end
