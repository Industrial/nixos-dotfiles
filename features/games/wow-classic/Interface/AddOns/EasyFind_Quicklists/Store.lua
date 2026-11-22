local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns then return end





local Store = {}
ns.QuicklistStore = Store

local Utils = ns.Utils or {}
local slower = Utils.slower or string.lower
local tremove = Utils.tremove or table.remove
local tinsert = Utils.tinsert or table.insert
local type = type

Store.NAME_MAX = 40
Store.ITEMS_MAX = 60
Store.SNAPSHOT_VER = 3

local function Lists()
    local db = EasyFind and EasyFind.db
    if not db then return nil end
    if type(db.quicklists) ~= "table" then db.quicklists = {} end
    return db.quicklists
end

local function CleanName(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("|", ""):gsub("[%c]", "")
    name = name:match("^%s*(.-)%s*$") or ""
    if name == "" then return nil end
    if #name > Store.NAME_MAX then name = name:sub(1, Store.NAME_MAX) end
    return name
end
Store.CleanName = CleanName

function Store.All()
    return Lists() or {}
end

function Store.Get(id)
    local lists = Lists()
    if not (lists and id) then return nil end
    for i = 1, #lists do
        if lists[i].id == id then return lists[i], i end
    end
    return nil
end

function Store.FindByName(name)
    local lists = Lists()
    local want = name and slower(name)
    if not (lists and want) then return nil end
    for i = 1, #lists do
        if slower(lists[i].name) == want then return lists[i] end
    end
    return nil
end

local function NextID()
    local db = EasyFind.db
    db.quicklistNextID = (tonumber(db.quicklistNextID) or 0) + 1
    return db.quicklistNextID
end

function Store.Create(name)
    local lists = Lists()
    name = CleanName(name)
    if not (lists and name) then return nil end
    local list = { id = NextID(), name = name, items = {} }
    lists[#lists + 1] = list
    return list
end

function Store.Rename(id, name)
    local list = Store.Get(id)
    name = CleanName(name)
    if not (list and name) then return false end
    list.name = name
    return true
end

function Store.Delete(id)
    local lists = Lists()
    local _, index = Store.Get(id)
    if not (lists and index) then return false end
    tremove(lists, index)
    return true
end

function Store.Move(id, delta)
    local lists = Lists()
    local list, index = Store.Get(id)
    if not (lists and index) then return false end
    local to = index + delta
    if to < 1 or to > #lists then return false end
    tremove(lists, index)
    tinsert(lists, to, list)
    return true
end


function Store.KeyOwner(combo)
    local lists = Lists()
    if not (lists and combo and combo ~= "") then return nil end
    for i = 1, #lists do
        if lists[i].key == combo then return lists[i] end
    end
    return nil
end


function Store.SetKey(id, combo)
    local list = Store.Get(id)
    if not list then return false end
    if combo == "" then combo = nil end
    if combo then
        local other = Store.KeyOwner(combo)
        if other and other ~= list then other.key = nil end
    end
    list.key = combo
    return true
end

function Store.SetHold(id, hold)
    local list = Store.Get(id)
    if not list then return false end
    list.hold = hold and true or nil
    return true
end

function Store.ItemKey(data)
    if not (data and ns.Aliases and ns.Aliases.GetEntryKey) then return nil end
    return ns.Aliases:GetEntryKey(data)
end

function Store.IndexOf(list, rowKey)
    if not (list and rowKey) then return nil end
    for i = 1, #list.items do
        if list.items[i].k == rowKey then return i end
    end
    return nil
end

function Store.Has(id, rowKey)
    return Store.IndexOf(Store.Get(id), rowKey) ~= nil
end




function Store.Add(id, data)
    local list = Store.Get(id)
    local rowKey = Store.ItemKey(data)
    if not (list and rowKey) then return false end
    if Store.IndexOf(list, rowKey) then return false end
    if #list.items >= Store.ITEMS_MAX then return false end
    local clean = ns.UIPins and ns.UIPins.CleanForStorage
    local snap = clean and clean(data) or nil
    list.items[#list.items + 1] = {
        k = rowKey, n = data.name, d = snap, v = snap and Store.SNAPSHOT_VER or nil,
    }
    return true
end

function Store.Remove(id, rowKey)
    local list = Store.Get(id)
    local index = Store.IndexOf(list, rowKey)
    if not index then return false end
    tremove(list.items, index)
    return true
end

function Store.MoveItem(id, index, delta)
    local list = Store.Get(id)
    if not (list and list.items[index]) then return false end
    local to = index + delta
    if to < 1 or to > #list.items then return false end
    local item = tremove(list.items, index)
    tinsert(list.items, to, item)
    return true
end



function Store.ExportList()
    local out = {}
    local lists = Lists() or {}
    for i = 1, #lists do
        local list = lists[i]
        local items = {}
        for j = 1, #list.items do
            items[j] = { k = list.items[j].k, n = list.items[j].n }
        end
        out[#out + 1] = { name = list.name, key = list.key, hold = list.hold or false, items = items }
    end
    return out
end



function Store.ImportList(rows, skipExisting)
    if type(rows) ~= "table" then return 0 end
    local n = 0
    for i = 1, #rows do
        local r = rows[i]
        local name = type(r) == "table" and CleanName(r.name)
        if name then
            local existing = Store.FindByName(name)
            local list = not (existing and skipExisting) and (existing or Store.Create(name)) or nil
            if list then
                list.items = {}
                local items = type(r.items) == "table" and r.items or {}
                for j = 1, #items do
                    local it = items[j]
                    if type(it) == "table" and type(it.k) == "string" and #list.items < Store.ITEMS_MAX then
                        list.items[#list.items + 1] = { k = it.k, n = type(it.n) == "string" and it.n or it.k }
                    end
                end
                list.hold = r.hold and true or nil
                Store.SetKey(list.id, type(r.key) == "string" and r.key or nil)
                n = n + 1
            end
        end
    end
    return n
end

function Store.ClearAll()
    local lists = Lists()
    if not lists then return end
    for i = #lists, 1, -1 do lists[i] = nil end
end

return Store
