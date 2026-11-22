local _, ns = ...

















local ENTRIES = {
    { key = "abilities",       categories = { "Ability" } },
    { key = "talents",         categories = { "Talent", "Talents" } },
    { key = "macros",          categories = { "Macro" } },
    { key = "currencies",      categories = { "Currency" } },
    { key = "reputations",     categories = { "Reputation" } },
    { key = "achievements",    categories = { "Achievement Category", "Achievement",
                                              "Achievements", "Guild Achievements" } },


    { key = "characterInfo",   categories = {} },
    { key = "statistics",      parent = "characterInfo", categories = { "Statistic", "Statistics" },
                               explicitFlag = "statistics" },
    { key = "charRows",        parent = "characterInfo", categories = { "Character" } },
    { key = "charPlayed",      parent = "characterInfo", categories = { "Character Played" } },
    { key = "charSeen",        parent = "characterInfo", categories = { "Character Seen" } },
    { key = "charGold",        parent = "characterInfo", categories = { "Character Gold" } },
    { key = "charLevel",       parent = "characterInfo", categories = { "Character Level" } },
    { key = "bosses",          categories = { "Boss" }, explicitFlag = "bosses" },

    { key = "items",           categories = {} },
    { key = "catalog",         parent = "items", categories = { "Item" } },
    { key = "bags",            parent = "items", categories = { "Bag" } },
    { key = "bank",            parent = "items", categories = { "Bank", "Warband" } },
    { key = "mail",            parent = "items", categories = { "Mail" } },
    { key = "guildBank",       parent = "items", categories = { "Guild Bank" } },
    { key = "titles",          categories = { "Title" } },
    { key = "gearSets",        categories = { "Gear Set" } },
    { key = "skills",          categories = { "Skill" } },
    { key = "holidays",        categories = { "Holiday" } },

    { key = "social",          categories = {} },
    { key = "friends",         parent = "social", categories = { "Friend" } },
    { key = "guildMembers",    parent = "social", categories = { "Guild Member" } },
    { key = "commands",        categories = { "Command" } },


    { key = "extensions",      categories = {} },
    { key = "professions",     categories = { "Profession" } },
    { key = "gameOptions",     parent = "options", categories = { "Game Settings" } },
    { key = "addonOptions",    parent = "options", categories = { "AddOn Settings" } },
    { key = "addons",          parent = "options", categories = { "AddOn" } },
    { key = "mounts",          parent = "collections", categories = { "Mount" } },
    { key = "toys",            parent = "collections", categories = { "Toy" } },
    { key = "pets",            parent = "collections", categories = { "Pet" } },
    { key = "outfits",         parent = "collections", categories = { "Outfit" } },
    { key = "heirlooms",       parent = "collections", categories = { "Heirloom" } },
    { key = "appearanceSets",  parent = "appearances", providerKey = "transmogSets",
                               categories = { "Appearance Set" } },
    { key = "appearanceItems", parent = "appearances",
                               categories = { "Appearance" } },
    { key = "loot",            categories = { "Loot" } },
    { key = "housing",         categories = { "Housing" } },
}


local INTERMEDIATE_PARENT = { appearances = "collections" }

local CategoryMap = { entries = ENTRIES }
ns.CategoryMap = CategoryMap


local ProviderCategory = {}



local BucketByCategory = {}






local SkipKeyOrder = {}
local skipSeen = {}

for i = 1, #ENTRIES do
    local e = ENTRIES[i]
    ProviderCategory[e.providerKey or e.key] = e.categories[1]
    for j = 1, #e.categories do
        local cat = e.categories[j]
        if not skipSeen[cat] then
            skipSeen[cat] = true
            SkipKeyOrder[#SkipKeyOrder + 1] = cat
        end
    end
    if e.key ~= "loot" and (e.parent == nil or e.parent == "options") then
        for j = 1, #e.categories do
            BucketByCategory[e.categories[j]] = e.key
        end
    end
end
CategoryMap.SkipKeyOrder = SkipKeyOrder

ProviderCategory.gameOptions = nil
ProviderCategory.addonOptions = nil

CategoryMap.ProviderCategory = ProviderCategory
CategoryMap.BucketByCategory = BucketByCategory

local function EntryOff(filters, e)
    if filters[e.key] == false then return true end
    local parent = e.parent
    while parent do
        if filters[parent] == false then return true end
        parent = INTERMEDIATE_PARENT[parent]
    end
    return false
end



local ProviderEntry = {}
for i = 1, #ENTRIES do
    ProviderEntry[ENTRIES[i].providerKey or ENTRIES[i].key] = ENTRIES[i]
end


function CategoryMap.CategoriesOf(providerKey)
    local e = ProviderEntry[providerKey]
    return e and e.categories
end


function CategoryMap.Add(e)
    local key = e.providerKey or e.key
    if ProviderEntry[key] then return end
    ENTRIES[#ENTRIES + 1] = e
    ProviderEntry[key] = e
    ProviderCategory[key] = e.categories[1]
    for j = 1, #e.categories do
        local cat = e.categories[j]
        if not skipSeen[cat] then
            skipSeen[cat] = true
            SkipKeyOrder[#SkipKeyOrder + 1] = cat
        end
    end
end



function CategoryMap.AddGroup(key, parent)
    INTERMEDIATE_PARENT[key] = parent
end






function CategoryMap.IsProviderFilterOff(filters, providerKey)
    if not filters then return false end
    local e = ProviderEntry[providerKey]
    if not e then return false end
    return EntryOff(filters, e)
end


function CategoryMap.ParentOf(providerKey)
    local e = ProviderEntry[providerKey]
    if e then return e.parent end
    return INTERMEDIATE_PARENT[providerKey]
end




function CategoryMap.BuildSkipCategories(filters, out, explicitStatistics, explicitBosses)
    wipe(out)
    local any = false
    for i = 1, #ENTRIES do
        local e = ENTRIES[i]
        local explicit = (e.explicitFlag == "statistics" and explicitStatistics)
            or (e.explicitFlag == "bosses" and explicitBosses)
        if not explicit and EntryOff(filters, e) then
            local categories = e.categories
            for j = 1, #categories do
                out[categories[j]] = true
            end
            any = true
        end
    end
    return any
end
