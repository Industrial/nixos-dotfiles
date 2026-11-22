local _, ns = ...

local Data = {}
ns.MapSearchData = Data

local Utils = ns.Utils
local sfind = Utils.sfind
local ipairs = Utils.ipairs



local playerFaction = UnitFactionGroup and UnitFactionGroup("player")
Data.CATEGORY_ICONS = {
    flightmaster = "atlas:FlightMaster",
    zeppelin = "atlas:Vehicle-Air-Horde",
    skyship = "atlas:Vehicle-Air-Alliance",
    boat = "atlas:Ships_CargoShip-Map",
    portal = playerFaction == "Horde" and "atlas:MagePortalHorde" or "atlas:MagePortalAlliance",
    tram = "atlas:Vehicle-AllianceCart",
    subzone = 237382,


    dungeon = "atlas:Dungeon",
    raid    = "atlas:Raid",
    delve   = { file = ns.ART.delve.tex, coords = ns.ART.delve.coords },
    bank = 136453,
    guildbank = 136453,
    personalbank = 136453,
    auctionhouse = 136452,
    innkeeper = 136458,
    trainer = 136463,
    proftrainer = 136463,
    classtrainer = { file = 131016, coords = { 0.000, 0.250, 0.375, 0.500 } },
    classtrainer_deathknight = "atlas:classicon-deathknight",
    classtrainer_demonhunter = "atlas:classicon-demonhunter",
    classtrainer_druid       = "atlas:classicon-druid",
    classtrainer_evoker      = "atlas:classicon-evoker",
    classtrainer_hunter      = "atlas:classicon-hunter",
    classtrainer_mage        = "atlas:classicon-mage",
    classtrainer_monk        = "atlas:classicon-monk",
    classtrainer_paladin     = "atlas:classicon-paladin",
    classtrainer_priest      = "atlas:classicon-priest",
    classtrainer_rogue       = "atlas:classicon-rogue",
    classtrainer_shaman      = "atlas:classicon-shaman",
    classtrainer_warlock     = "atlas:classicon-warlock",
    classtrainer_warrior     = "atlas:classicon-warrior",
    prof_alchemy = "Interface\\Icons\\Trade_Alchemy",
    prof_blacksmithing = "Interface\\Icons\\Trade_BlackSmithing",
    prof_cooking = "Interface\\Icons\\INV_Misc_Food_15",
    prof_enchanting = "Interface\\Icons\\Trade_Engraving",
    prof_engineering = "Interface\\Icons\\Trade_Engineering",
    prof_fishing = "Interface\\Icons\\Trade_Fishing",
    prof_herbalism = "Interface\\Icons\\Trade_Herbalism",
    prof_inscription = "Interface\\Icons\\INV_Inscription_Tradeskill01",
    prof_jewelcrafting = "Interface\\Icons\\INV_Misc_Gem_01",
    prof_leatherworking = "Interface\\Icons\\Trade_LeatherWorking",
    prof_mining = "Interface\\Icons\\Trade_Mining",
    prof_skinning = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
    prof_tailoring = "Interface\\Icons\\Trade_Tailoring",
    prof_firstaid = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    prof_archaeology = "Interface\\Icons\\Trade_Archaeology",
    trainingdummy = "Interface\\Icons\\Ability_Warrior_Charge",
    vendor = "Interface\\Icons\\INV_Misc_Bag_07",
    pvpvendor = 236396,
    pvpquest = 236396,
    battlemasters = 236396,
    quartermaster = { file = ns.ART.quartermaster.tex, coords = ns.ART.quartermaster.coords },
    mailbox = 136459,
    stablemaster = 136466,
    repairvendor = 136465,
    barber = 3852099,
    transmogrifier = 1598183,
    rare = { file = ns.ART.rare.tex, coords = ns.ART.rare.coords },
    treasure = "Interface\\Icons\\INV_Misc_Bag_10",
    catalyst = { file = ns.ART.catalyst.tex, coords = ns.ART.catalyst.coords },
    greatvault = "Interface\\Icons\\INV_Misc_Lockbox_1",
    upgradevendor = 4025144,
    guildservices = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
    voidstorage = "Interface\\Icons\\INV_Enchant_VoidCrystal",
    tradingpost = "Interface\\Icons\\tradingpostcurrency",
    decor = { file = ns.ART.decor.tex, coords = ns.ART.decor.coords },
    chromie = "atlas:ChromieTime-32x32",
    lorewalker = { file = ns.ART.lorewalker.tex, coords = ns.ART.lorewalker.coords },
    craftingorders = { file = ns.ART.crafting_orders.tex, coords = ns.ART.crafting_orders.coords },
    rostrum = { file = ns.ART.rostrum.tex, coords = ns.ART.rostrum.coords },
    pettrainer = "atlas:WildBattlePetCapturable",
    ridingtrainer = "atlas:StableMaster",
    npc = 134148,
    areapoi = "Interface\\Icons\\INV_Misc_QuestionMark",
    unknown = "Interface\\Icons\\INV_Misc_QuestionMark",
}


if ns.Caps and ns.Caps.classic then
    local icons = Data.CATEGORY_ICONS
    icons.rare = "atlas:VignetteKill"
    icons.subzone = "Interface\\Icons\\INV_Misc_Map_01"
    icons.classtrainer = "atlas:Class"
    icons.pvpvendor = "atlas:BattleMaster"
    icons.pvpquest = "atlas:BattleMaster"
    icons.battlemasters = "atlas:BattleMaster"
end

Data.CATEGORIES = {
    travel = { keywords = {"travel", "transport", "transportation", "getting around"} },
    instance = { keywords = {"instance", "instances", "group content"} },
    service = { keywords = {"service", "services", "npc"} },
    subzone = { keywords = {"subzone", "subzones", "area"} },

    flightmaster = { keywords = {"flight", "fly", "flight master", "flight point", "fp", "fm", "taxi"}, parent = "travel" },
    zeppelin = { keywords = {"zeppelin", "zep", "airship", "blimp"}, parent = "travel" },
    boat = { keywords = {"boat", "ship", "ferry"}, parent = "travel" },
    portal = { keywords = {"portal", "portals", "teleport", "tp", "mage"}, parent = "travel" },
    tram = { keywords = {"tram", "deeprun"}, parent = "travel" },

    dungeon = { keywords = {"dungeon", "dungeons", "5 man", "5man", "mythic", "heroic"}, parent = "instance" },
    raid = { keywords = {"raid", "raids", "raiding"}, parent = "instance" },
    delve = { keywords = {"delve", "delves"}, parent = "instance" },

    bank = { keywords = {"bank", "vault", "storage", "guild bank", "personal bank"}, parent = "service" },
    auctionhouse = { keywords = {"auction", "ah", "auction house"}, parent = "service" },
    innkeeper = { keywords = {"inn", "innkeeper", "rest", "hearthstone"}, parent = "service" },
    trainer = { keywords = {"trainer", "training", "class trainer"}, parent = "service" },
    vendor = { keywords = {"vendor", "merchant", "shop", "buy", "sell"}, parent = "service" },
    pvpvendor = { keywords = {"pvp vendor", "honor vendor", "conquest vendor", "arena vendor", "battleground vendor", "pvp gear"}, parent = "service" },
    quartermaster = { keywords = {"quartermaster", "qtr", "gear vendor", "currency vendor"}, parent = "service" },
    mailbox = { keywords = {"mail", "mailbox"}, parent = "service" },
    stablemaster = { keywords = {"stable", "stable master", "pet"}, parent = "service" },
    repairvendor = { keywords = {"repair", "repairs", "anvil"}, parent = "service" },
    barber = { keywords = {"barber", "barbershop", "appearance", "haircut"}, parent = "service" },
    transmogrifier = { keywords = {"transmog", "tmog", "xmog", "transmogrifier", "appearance"}, parent = "service" },

    prof_blacksmithing = { keywords = {"blacksmithing", "bs"}, parent = "service" },
    prof_jewelcrafting = { keywords = {"jewelcrafting", "jc"}, parent = "service" },
    prof_leatherworking = { keywords = {"leatherworking", "lw"}, parent = "service" },

    rare = { keywords = {"rare", "rares", "silver dragon", "elite"} },
    treasure = { keywords = {"treasure", "chest", "loot"} },
    catalyst = { keywords = {"catalyst", "tier", "tier set", "revival catalyst", "upgrade"}, parent = "service" },
    greatvault = { keywords = {"great vault", "vault", "weekly rewards", "weekly chest"}, parent = "service" },
    upgradevendor = { keywords = {"upgrade", "upgrade vendor", "flightstone", "crest"}, parent = "service" },
    tradingpost = { keywords = {"trading post", "trader's tender", "tender"}, parent = "service" },
    decor = { keywords = {"decor", "decoration", "decorations", "decorator", "housing", "furniture"}, parent = "service" },
    lorewalker = { keywords = {"lorewalker", "cho", "lore walker", "pandaria lore", "flashback", "replay cinematic"}, parent = "service" },
}



do
    local Steer = ns.SearchSteer
    if Steer then
        for key, def in pairs(Data.CATEGORIES) do
            for i = 1, #def.keywords do Steer.Add(key, def.keywords[i]) end
            local parent = def.parent and Data.CATEGORIES[def.parent]
            if parent then
                for i = 1, #parent.keywords do Steer.Add(key, parent.keywords[i]) end
            end
        end
    end
end

Data.GLOBAL_SEARCH_CATEGORIES = {
    dungeon = true,
    raid = true,
    delve = true,
}




local BOOST_EXCLUDED_KEYWORDS = {
    mage = true, pet = true, rest = true, buy = true, sell = true,
    loot = true, chest = true, tier = true, upgrade = true, elite = true,
    appearance = true, hearthstone = true, mythic = true, heroic = true,
    cho = true, housing = true, furniture = true,
}







Data.KEYWORD_TO_CATEGORY = {}
do
    local isParent = {}
    for _, def in pairs(Data.CATEGORIES) do
        if def.parent then isParent[def.parent] = true end
    end
    local orderedKeys = {}
    for categoryKey in pairs(Data.CATEGORIES) do
        orderedKeys[#orderedKeys + 1] = categoryKey
    end
    table.sort(orderedKeys)
    for i = 1, #orderedKeys do
        local categoryKey = orderedKeys[i]
        local def = Data.CATEGORIES[categoryKey]
        if not isParent[categoryKey] and def.keywords then
            for ki = 1, #def.keywords do
                local kw = def.keywords[ki]
                if not BOOST_EXCLUDED_KEYWORDS[kw] and not Data.KEYWORD_TO_CATEGORY[kw] then
                    Data.KEYWORD_TO_CATEGORY[kw] = categoryKey
                end
            end
        end
    end
end

Data.TEXT_CATEGORY_RULES = {
    { category = "zeppelin", name = {"zeppelin", "airship"}, scanDesc = {"zeppelin"} },
    { category = "boat", name = {"boat", "ship", "ferry"}, scanDesc = {"boat"} },
    { category = "portal", name = {"portal"}, scanDesc = {"teleport"}, scanExcludeName = {"dark portal"} },
    { category = "tram", name = {"tram"}, scanDesc = {"tram"} },
    { category = "greatvault", name = {"great vault"}, scanOnly = true },
    { category = "catalyst", name = {"catalyst"}, scanOnly = true },
    { category = "auctionhouse", name = {"auction"}, scanOnly = true },
    { category = "bank", name = {"bank"}, scanExcludeName = {"moat"}, scanOnly = true },
    { category = "innkeeper", name = {"innkeeper", "inn"}, scanOnly = true },
    { category = "flightmaster", name = {"flight master", "flight point"}, scanOnly = true },
    { category = "tradingpost", name = {"trading post"} },
    { category = "quartermaster", name = {"quartermaster"} },
    { category = "decor", name = {"decor"} },
    {
        category = "pvpvendor",
        name = {"conquest", "honor", "pvp"},
        pinName = {"pvp", "arena", "battleground", "conquest", "honor", "weekly"},
        pinDesc = {"pvp"},
    },
    { category = "chromie", name = {"chromie"} },
}

local function TextHasAny(text, terms)
    if not text or not terms then return false end
    for i = 1, #terms do
        if sfind(text, terms[i], 1, true) then
            return true
        end
    end
    return false
end

local function AreaRuleMatches(rule, nameLower, descLower)
    local nameMatches = TextHasAny(nameLower, rule.name)
        and not TextHasAny(nameLower, rule.scanExcludeName)
    return nameMatches or TextHasAny(descLower, rule.scanDesc)
end

function Data.ResolveAreaPOICategory(nameLower, descLower)
    for _, rule in ipairs(Data.TEXT_CATEGORY_RULES) do
        if AreaRuleMatches(rule, nameLower, descLower) then
            return rule.category
        end
    end
    return nil
end

function Data.ResolvePinAreaPOICategory(nameLower, descLower)
    for _, rule in ipairs(Data.TEXT_CATEGORY_RULES) do
        if not rule.scanOnly
           and (TextHasAny(nameLower, rule.pinName or rule.name) or TextHasAny(descLower, rule.pinDesc)) then
            return rule.category
        end
    end
    return nil
end
