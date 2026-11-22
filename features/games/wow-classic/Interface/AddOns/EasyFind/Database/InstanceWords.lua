local _, ns = ...
local Database = ns.Database
local SearchText = ns.SearchText

local slower = SearchText.Normalize
local ssub = string.sub
local bband = bit.band
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or _G.GetItemInfoInstant



local INSTANCE_ABBRS = {
    ["ragefire chasm"]    = {"rfc"},
    ["wailing caverns"]   = {"wc"},
    ["deadmines"]         = {"dm", "vc"},
    ["shadowfang keep"]   = {"sfk"},
    ["blackfathom deeps"] = {"bfd"},
    ["stormwind stockade"] = {"stocks", "stockades", "stockade"},
    ["stockade"]          = {"stocks", "stockades"},
    ["gnomeregan"]        = {"gnomer"},
    ["razorfen kraul"]    = {"rfk"},
    ["razorfen downs"]    = {"rfd"},
    ["scarlet monastery"] = {"sm"},
    ["scarlet halls"]     = {"sm"},
    ["uldaman"]           = {"ulda"},
    ["zul'farrak"]        = {"zf"},
    ["maraudon"]          = {"mara"},
    ["sunken temple"]     = {"st"},
    ["temple of atal'hakkar"] = {"st", "sunken temple"},
    ["blackrock depths"]  = {"brd"},
    ["blackrock spire"]   = {"brs", "lbrs", "ubrs"},
    ["dire maul"]         = {"dm"},
    ["stratholme"]        = {"strat", "strath"},
    ["scholomance"]       = {"scholo"},
    ["molten core"]       = {"mc"},
    ["onyxia's lair"]     = {"ony", "onyxia"},
    ["blackwing lair"]    = {"bwl"},
    ["zul'gurub"]         = {"zg"},
    ["ruins of ahn'qiraj"] = {"aq", "aq20"},
    ["ahn'qiraj temple"]  = {"aq", "aq40"},
    ["temple of ahn'qiraj"] = {"aq", "aq40"},
    ["naxxramas"]         = {"nax", "naxx"},
    ["ramparts"]          = {"ramps", "hfr"},
    ["hellfire ramparts"] = {"ramps", "hfr", "ramparts"},
    ["blood furnace"]     = {"bf", "furnace"},
    ["shattered halls"]   = {"sh", "shh"},
    ["slave pens"]        = {"sp"},
    ["underbog"]          = {"ub"},
    ["steamvault"]        = {"sv"},
    ["mana-tombs"]        = {"mt", "tombs"},
    ["auchenai crypts"]   = {"ac", "crypts"},
    ["sethekk halls"]     = {"seth", "sethekk"},
    ["shadow labyrinth"]  = {"sl", "slabs", "slab"},
    ["mechanar"]          = {"mech"},
    ["botanica"]          = {"bot"},
    ["arcatraz"]          = {"arc"},
    ["escape from durnholde"] = {"oh", "ohf", "durnholde", "hillsbrad"},
    ["old hillsbrad foothills"] = {"oh", "ohf", "durnholde", "hillsbrad"},
    ["opening of the dark portal"] = {"bm", "morass"},
    ["black morass"]      = {"bm", "morass"},
    ["magister's terrace"] = {"mgt", "mrt", "terrace"},
    ["magisters' terrace"] = {"mgt", "mrt", "terrace"},
    ["karazhan"]          = {"kara", "kz"},
    ["gruul's lair"]      = {"gruul", "gl"},
    ["magtheridon's lair"] = {"mag", "maggy"},
    ["serpentshrine cavern"] = {"ssc"},
    ["tempest keep"]      = {"tk", "eye"},
    ["the eye"]           = {"tk", "eye"},
    ["hyjal summit"]      = {"mh", "hyjal"},
    ["battle for mount hyjal"] = {"mh", "hyjal"},
    ["black temple"]      = {"bt"},
    ["zul'aman"]          = {"za"},
    ["sunwell plateau"]   = {"swp", "sunwell"},
    ["the sunwell"]       = {"swp", "sunwell"},
    ["icecrown citadel"]  = {"icc"},
}
ns.INSTANCE_ABBRS = INSTANCE_ABBRS

function Database.InstanceAbbrs(instLower)
    if not instLower then return nil end
    local hit = INSTANCE_ABBRS[instLower]
    if hit then return hit end
    local bare = (instLower:gsub("^the ", ""))
    local tail = instLower:match(":%s*(.+)$")
    local tailBare = tail and (tail:gsub("^the ", ""))
    return INSTANCE_ABBRS[bare] or (tail and INSTANCE_ABBRS[tail]) or (tailBare and INSTANCE_ABBRS[tailBare]) or nil
end



function Database.AddInstanceAbbrs(words)
    local n = #words
    for i = 1, n do
        local abbrs = Database.InstanceAbbrs(words[i])
        for a = 1, abbrs and #abbrs or 0 do
            local abbr, have = abbrs[a], false
            for k = 1, #words do
                if words[k] == abbr then have = true break end
            end
            if not have then words[#words + 1] = abbr end
        end
    end
    return words
end



local SM_GY, SM_LIB, SM_ARM, SM_CATH = {"gy", "graveyard", "smgy"}, {"lib", "library", "smlib"},
    {"arm", "armory", "smarm"}, {"cath", "cathedral", "smcath"}
local DM_E, DM_W, DM_N = {"east", "dme"}, {"west", "dmw"}, {"north", "dmn", "tribute"}
local BRS_L, BRS_U = {"lower", "lbrs"}, {"upper", "ubrs"}
local STRAT_LIVE, STRAT_DEAD = {"live", "stratlive"}, {"dead", "ud", "undead", "stratud", "stratdead"}
local BOSS_WING_WORDS = {
    ["interrogator vishas"] = SM_GY, ["bloodmage thalnos"] = SM_GY, ["ironspine"] = SM_GY,
    ["azshir the sleepless"] = SM_GY, ["fallen champion"] = SM_GY,
    ["houndmaster loksey"] = SM_LIB, ["arcanist doan"] = SM_LIB,
    ["herod"] = SM_ARM,
    ["high inquisitor fairbanks"] = SM_CATH, ["scarlet commander mograine"] = SM_CATH,
    ["high inquisitor whitemane"] = SM_CATH,
    ["pusillin"] = DM_E, ["zevrim thornhoof"] = DM_E, ["hydrospawn"] = DM_E, ["lethtendris"] = DM_E,
    ["alzzin the wildshaper"] = DM_E,
    ["tendris warpwood"] = DM_W, ["illyanna ravenoak"] = DM_W, ["magister kalendris"] = DM_W,
    ["immol'thar"] = DM_W, ["prince tortheldrin"] = DM_W, ["lord hel'nurath"] = DM_W, ["tsu'zee"] = DM_W,
    ["guard mol'dar"] = DM_N, ["stomper kreeg"] = DM_N, ["guard fengus"] = DM_N, ["guard slip'kik"] = DM_N,
    ["captain kromcrush"] = DM_N, ["cho'rush the observer"] = DM_N, ["king gordok"] = DM_N,
    ["highlord omokk"] = BRS_L, ["shadow hunter vosh'gajin"] = BRS_L, ["war master voone"] = BRS_L,
    ["mother smolderweb"] = BRS_L, ["urok doomhowl"] = BRS_L, ["quartermaster zigris"] = BRS_L,
    ["halycon"] = BRS_L, ["gizrul the slavener"] = BRS_L, ["overlord wyrmthalak"] = BRS_L,
    ["bannok grimaxe"] = BRS_L, ["crystal fang"] = BRS_L, ["ghok bashguud"] = BRS_L, ["mor grayhoof"] = BRS_L,
    ["burning felguard"] = BRS_L, ["spirestone butcher"] = BRS_L, ["spirestone battle lord"] = BRS_L,
    ["spirestone lord magus"] = BRS_L,
    ["pyroguard emberseer"] = BRS_U, ["solakar flamewreath"] = BRS_U, ["goraluk anvilcrack"] = BRS_U,
    ["warchief rend blackhand"] = BRS_U, ["gyth"] = BRS_U, ["the beast"] = BRS_U, ["general drakkisath"] = BRS_U,
    ["lord valthalak"] = BRS_U, ["jed runewatcher"] = BRS_U,
    ["the unforgiven"] = STRAT_LIVE, ["timmy the cruel"] = STRAT_LIVE, ["malor the zealous"] = STRAT_LIVE,
    ["commander malor"] = STRAT_LIVE, ["cannon master willey"] = STRAT_LIVE, ["willey hopebreaker"] = STRAT_LIVE,
    ["archivist galford"] = STRAT_LIVE, ["instructor galford"] = STRAT_LIVE, ["balnazzar"] = STRAT_LIVE,
    ["hearthsinger forresten"] = STRAT_LIVE, ["fras siabi"] = STRAT_LIVE, ["postmaster malown"] = STRAT_LIVE,
    ["nerub'enkan"] = STRAT_DEAD, ["baroness anastari"] = STRAT_DEAD, ["maleki the pallid"] = STRAT_DEAD,
    ["magistrate barthilas"] = STRAT_DEAD, ["ramstein the gorger"] = STRAT_DEAD, ["baron rivendare"] = STRAT_DEAD,
    ["lord aurius rivendare"] = STRAT_DEAD, ["black guard swordsmith"] = STRAT_DEAD, ["stonespine"] = STRAT_DEAD,
}
Database.BOSS_WING_WORDS = BOSS_WING_WORDS



local SMALL_WORDS = { ["the"] = true, ["of"] = true, ["and"] = true, ["for"] = true }
local instanceWordLookup
local function AddInstanceWords(phrase)
    if type(phrase) ~= "string" then return end
    for w in slower(phrase):gmatch("[%a']+") do
        if #w >= 2 and not SMALL_WORDS[w] then instanceWordLookup[w] = true end
    end
end
local function GetInstanceWordLookup()
    if instanceWordLookup then return instanceWordLookup end
    instanceWordLookup = {}
    for name, abbrs in pairs(INSTANCE_ABBRS) do
        AddInstanceWords(name)
        for i = 1, #abbrs do AddInstanceWords(abbrs[i]) end
    end
    for _, words in pairs(BOSS_WING_WORDS) do
        for i = 1, #words do instanceWordLookup[words[i]] = true end
    end
    for _, e in ipairs(ns.FOREVER_INSTANCES or {}) do AddInstanceWords(e.n) end
    for _, boss in ipairs(ns.STATIC_LOOT or {}) do AddInstanceWords(boss.boss) end
    return instanceWordLookup
end


function Database.AddInstanceSearchWords(instName, bossName)
    GetInstanceWordLookup()
    AddInstanceWords(instName)
    AddInstanceWords(bossName)
end

function Database:IsInstanceSearchWord(word)
    return GetInstanceWordLookup()[word] == true
end


function Database:QueryNamesAnInstance(text)
    if not text then return false end
    local lookup = GetInstanceWordLookup()
    for word in slower(text):gmatch("%S+") do
        word = word:gsub("^%p+", ""):gsub("%p+$", "")
        if lookup[word] then return true end
    end
    return false
end




local ARMOR_KEYWORDS = { [1] = {"cloth"}, [2] = {"leather"}, [3] = {"mail"}, [4] = {"plate"}, [6] = {"shield", "shields"} }



local W, PA, H, R, PR, S, M, WL, D = "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"
local DK, MO, DH, EV = "DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER"
local CLASS_ID = { [W] = 1, [PA] = 2, [H] = 3, [R] = 4, [PR] = 5, [DK] = 6, [S] = 7, [M] = 8, [WL] = 9,
                   [MO] = 10, [D] = 11, [DH] = 12, [EV] = 13 }
local oldRules = ns.Caps and (ns.Caps.era or ns.Caps.tbc or ns.Caps.forever)
local ARMOR_CLASSES = oldRules and {
    [1] = { PR, M, WL }, [2] = { R, D, H, S }, [3] = { W, PA, H, S }, [4] = { W, PA }, [6] = { W, PA, S },
    [7] = { PA }, [8] = { D }, [9] = { S },
} or {
    [1] = { PR, M, WL }, [2] = { R, D, MO, DH }, [3] = { H, S, EV }, [4] = { W, PA, DK }, [6] = { W, PA, S },
    [7] = { PA }, [8] = { D }, [9] = { S }, [10] = { DK },
}
local WEAPON_CLASSES = oldRules and {
    [0] = { W, PA, H, S }, [1] = { W, PA, H, S }, [2] = { W, H, R }, [3] = { W, H, R },
    [4] = { W, PA, R, PR, S, D }, [5] = { W, PA, S, D }, [6] = { W, PA, H },
    [7] = { W, PA, H, R, M, WL }, [8] = { W, PA, H }, [10] = { W, H, PR, S, M, WL, D },
    [13] = { W, H, R, S, D }, [15] = { W, H, R, PR, S, M, WL, D }, [16] = { W, H, R },
    [18] = { W, H, R }, [19] = { PR, M, WL },
} or {
    [0] = { W, PA, H, R, S, DK, MO, DH, EV }, [1] = { W, PA, H, S, DK }, [2] = { H }, [3] = { H },
    [4] = { W, PA, R, PR, S, D, DK, MO, EV }, [5] = { W, PA, S, D, DK }, [6] = { W, PA, H, D, DK, MO },
    [7] = { W, PA, H, R, M, WL, DK, MO, DH, EV }, [8] = { W, PA, H, DK }, [9] = { DH },
    [10] = { W, H, PR, S, M, WL, D, MO, EV }, [13] = { W, H, R, S, D, MO, DH, EV },
    [15] = { W, H, R, PR, S, M, WL, D, EV }, [18] = { H }, [19] = { PR, M, WL },
}
local ENGLISH = { [W] = "warrior", [PA] = "paladin", [H] = "hunter", [R] = "rogue", [PR] = "priest",
    [DK] = "death knight", [S] = "shaman", [M] = "mage", [WL] = "warlock", [MO] = "monk", [D] = "druid",
    [DH] = "demon hunter", [EV] = "evoker" }
local SHORT = { [DK] = "dk", [DH] = "dh" }


local gearWords
local function GearWords()
    if gearWords then return gearWords end
    gearWords = {}
    for subclass, words in pairs(ARMOR_KEYWORDS) do
        for i = 1, #words do gearWords[words[i]] = { armor = subclass } end
    end
    local male, female = LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE
    for token, id in pairs(CLASS_ID) do
        local kind = { class = token, bit = 2 ^ (id - 1), prefix = id .. "-" }
        gearWords[ENGLISH[token]] = kind
        if SHORT[token] then gearWords[SHORT[token]] = kind end
        for _, names in ipairs({ male, female }) do
            local name = names and names[token]
            if name then gearWords[slower(name)] = kind end
        end
    end
    return gearWords
end



function Database.AddGearAndInstanceSearchWords(add)
    for word in pairs(GearWords()) do add(word) end
    for word in pairs(GetInstanceWordLookup()) do add(word) end
end

local function Has(list, token)
    for i = 1, #list do
        if list[i] == token then return true end
    end
    return false
end



local function ClassUses(itemID, token, bit)
    local mask = ns.STATIC_LOOT_CLASSES and ns.STATIC_LOOT_CLASSES[itemID]
    if mask then return bband(mask, bit) ~= 0 end
    local _, _, _, equipLoc, _, classID, subclassID = GetItemInfoInstant(itemID)
    if equipLoc == "INVTYPE_CLOAK" then return true end
    local list
    if classID == 4 then list = ARMOR_CLASSES[subclassID]
    elseif classID == 2 then list = WEAPON_CLASSES[subclassID] end
    return not list or Has(list, token)
end

local CLASS_TOKEN = {}
for token, id in pairs(CLASS_ID) do CLASS_TOKEN[id] = token end


function Database.ClassUsesSubclass(token, classID, subclassID)
    local list
    if classID == 4 then list = ARMOR_CLASSES[subclassID]
    elseif classID == 2 then list = WEAPON_CLASSES[subclassID] end
    return not list or Has(list, token)
end
Database.CLASS_ID = CLASS_ID


function Database.LootForClass(itemID, classID)
    local token = CLASS_TOKEN[classID]
    if not token then return true end
    return ClassUses(itemID, token, 2 ^ (classID - 1))
end



function Database.LootWordScore(data, word)
    local kind = GearWords()[word]
    if not kind then return nil end
    local itemID = data.itemID
    local _, _, _, _, _, classID, subclassID = GetItemInfoInstant(itemID)


    if kind.armor then return (classID == 4 and subclassID == kind.armor) and 115 or 0 end
    local mask = ns.STATIC_LOOT_CLASSES and ns.STATIC_LOOT_CLASSES[itemID]
    if mask then return bband(mask, kind.bit) ~= 0 and 110 or 0 end
    local specs = data._cachedSpecs
    if specs and specs[1] and specs[1] ~= "*" then
        local n = #kind.prefix
        for i = 1, #specs do
            if ssub(specs[i], 1, n) == kind.prefix then return 110 end
        end
        return 0
    end
    return ClassUses(itemID, kind.class, kind.bit) and 110 or 0
end
