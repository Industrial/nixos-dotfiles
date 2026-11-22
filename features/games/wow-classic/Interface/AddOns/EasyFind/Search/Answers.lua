local _, ns = ...





local Answers = {}
ns.Answers = Answers

local Utils = ns.Utils
local L = ns.L

local slower = Utils.slower
local sformat = Utils.sformat
local mfloor = Utils.mfloor
local strtrim = strtrim
local GetMoney = GetMoney
local GetCoinTextureString = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
local GetAverageItemLevel = GetAverageItemLevel
local GetInventoryItemDurability = GetInventoryItemDurability
local GetUnitSpeed = GetUnitSpeed
local C_Container = C_Container
local C_MythicPlus = C_MythicPlus
local C_ChallengeMode = C_ChallengeMode
local C_DateAndTime = C_DateAndTime
local SecondsToTime = SecondsToTime
local Caps = ns.Caps or {}
local issecret = _G.issecretvalue or function() return false end

local BASE_RUN_SPEED = 7




local function GoldLedger()
    if type(EasyFindDB) ~= "table" then return nil end
    if type(EasyFindDB.charGold) ~= "table" then EasyFindDB.charGold = {} end
    return EasyFindDB.charGold
end



local function CharKey()
    local name = ns.PlayerName()
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if not (name and realm and realm ~= "") then return nil end
    return name .. "-" .. realm
end

local function RecordGold()
    local ledger = GoldLedger()
    local key = CharKey()
    if ledger and key and GetMoney then
        ledger[key] = GetMoney()
    end
end

local goldWatcher = CreateFrame("Frame")
goldWatcher:RegisterEvent("PLAYER_LOGIN")
goldWatcher:RegisterEvent("PLAYER_MONEY")
goldWatcher:SetScript("OnEvent", RecordGold)

local function CoinText(amount)
    if GetCoinTextureString then return GetCoinTextureString(amount) end
    return tostring(amount)
end






local COIN_SYMBOLS = {
    _G["GOLD_AMOUNT_SYMBOL"] or "g",
    _G["SILVER_AMOUNT_SYMBOL"] or "s",
    _G["COPPER_AMOUNT_SYMBOL"] or "c",
}

local function PlainCoinText(amount)
    amount = amount or 0
    local perSilver = COPPER_PER_SILVER or 100
    local perGold = COPPER_PER_GOLD or 10000
    local parts = {
        mfloor(amount / perGold),
        mfloor((amount % perGold) / perSilver),
        amount % perSilver,
    }
    local text = ""
    for i = 1, 3 do



        if parts[i] > 0 or text ~= "" then
            if text ~= "" then text = text .. " " end
            text = text .. parts[i] .. COIN_SYMBOLS[i]
        end
    end
    if text == "" then text = 0 .. COIN_SYMBOLS[3] end
    return text
end


Answers.CoinText, Answers.PlainCoinText = CoinText, PlainCoinText

local function GoldText(FormatCoin)
    local money = GetMoney and GetMoney()
    if not money then return nil end
    local total = money
    local ledger = GoldLedger()
    local key = CharKey()
    if ledger then
        for charKey, amount in pairs(ledger) do
            if charKey ~= key and type(amount) == "number" then
                total = total + amount
            end
        end
    end
    if total == money then return FormatCoin(money) end
    return sformat(L["ANSWER_GOLD_FMT"], FormatCoin(money), FormatCoin(total))
end

local function GoldValue()
    return GoldText(CoinText)
end

local function GoldCopyValue()
    return GoldText(PlainCoinText)
end

local function ItemLevelValue()
    if not GetAverageItemLevel then return nil end
    local ok, overall, equipped, pvp = pcall(GetAverageItemLevel)
    if not ok or not overall then return nil end
    return sformat("%s %.1f / %s %.1f", _G["PVE"] or "PvE", equipped or overall,
        _G["PVP"] or "PvP", pvp or overall)
end

local function KeystoneValue()
    if not (C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID) then return nil end
    local ok, mapID = pcall(C_MythicPlus.GetOwnedKeystoneChallengeMapID)
    if not ok or not mapID then return _G["NONE"] or "None" end
    local level
    if C_MythicPlus.GetOwnedKeystoneLevel then
        local okL, lvl = pcall(C_MythicPlus.GetOwnedKeystoneLevel)
        if okL then level = lvl end
    end
    local mapName
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local okM, name = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
        if okM then mapName = name end
    end
    if mapName and level then return sformat("%s +%d", mapName, level) end
    return mapName or (_G["NONE"] or "None")
end

local function RatingValue()
    if not (C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore) then return nil end
    local ok, score = pcall(C_ChallengeMode.GetOverallDungeonScore)
    if not ok or not score then return nil end
    return tostring(score)
end

local function DurabilityValue()
    if not GetInventoryItemDurability then return nil end
    local worst
    for slot = 1, 17 do
        local current, maximum = GetInventoryItemDurability(slot)
        if current and maximum and maximum > 0 then
            local pct = current / maximum
            if not worst or pct < worst then worst = pct end
        end
    end
    if not worst then return nil end
    return sformat("%d%%", mfloor(worst * 100 + 0.5))
end

local function BagSpaceValue()
    if not (C_Container and C_Container.GetContainerNumFreeSlots
            and C_Container.GetContainerNumSlots) then
        return nil
    end
    local free, total = 0, 0
    for bag = 0, ns.MaxCarriedBagIndex() do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        if slots > 0 then
            total = total + slots
            free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
        end
    end
    if total == 0 then return nil end
    return sformat("%d / %d", free, total)
end

local function SpeedValue()
    if not GetUnitSpeed then return nil end
    local speed = GetUnitSpeed("player")
    if not speed then return nil end
    return sformat("%d%%", mfloor(speed / BASE_RUN_SPEED * 100 + 0.5))
end

local function Countdown(seconds)
    return SecondsToTime(seconds < 60 and 60 or seconds, true, false, 2)
end


local function ResetValue()
    if not SecondsToTime then return nil end
    local daily = C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset and C_DateAndTime.GetSecondsUntilDailyReset()
    if not daily and GetQuestResetTime then daily = GetQuestResetTime() end
    local weekly = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
        and C_DateAndTime.GetSecondsUntilWeeklyReset()
    local text
    if daily and daily > 0 then text = (_G["DAILY"] or "Daily") .. ": " .. Countdown(daily) end
    if weekly and weekly > 0 then
        local week = (_G["WEEKLY"] or "Weekly") .. ": " .. Countdown(weekly)
        text = text and (text .. ", " .. week) or week
    end
    return text
end
Answers.ResetValue = ResetValue






local MELEE, RANGED = _G["MELEE"] or "Melee", _G["RANGED"] or "Ranged"
local SPELL = _G["STAT_CATEGORY_SPELL"] or "Spell"
local PCT, PCT_MELEE_RANGED_SPELL = "%.2f%%", MELEE .. " %.2f%%, " .. RANGED .. " %.2f%%, " .. SPELL .. " %.2f%%"
local PCT_MELEE_SPELL = MELEE .. " %.2f%%, " .. SPELL .. " %.2f%%"
local NUM, NUM_MELEE_RANGED = "%d", MELEE .. " %d, " .. RANGED .. " %d"
local NUM_DAMAGE_HEALING = (_G["DAMAGE"] or "Damage") .. " %d, " .. (_G["BONUS_HEALING"] or "Bonus Healing") .. " %d"

local function Sum(a, b, c)
    if issecret(a) or issecret(b) or issecret(c) then return a end
    return (a or 0) + (b or 0) + (c or 0)
end


local function BestSchool(read)
    local best = read(2)
    if issecret(best) then return best end
    for school = 3, 7 do
        local v = read(school)
        if v and not issecret(v) and (not best or v > best) then best = v end
    end
    return best or 0
end

local function Rating(id)
    return GetCombatRatingBonus and id and GetCombatRatingBonus(id) or 0
end

local function CritStat()
    if not GetCritChance then return nil end
    return PCT_MELEE_RANGED_SPELL, GetCritChance() or 0, GetRangedCritChance and GetRangedCritChance() or 0,
        GetSpellCritChance and BestSchool(GetSpellCritChance) or 0
end


local function HitStat()
    if Caps.retail or not GetHitModifier then return nil end
    return PCT_MELEE_SPELL, Sum(GetHitModifier(), Rating(_G["CR_HIT_MELEE"])),
        Sum(GetSpellHitModifier and GetSpellHitModifier(), Rating(_G["CR_HIT_SPELL"]))
end

local function SpellPowerStat()
    if not GetSpellBonusDamage then return nil end
    local damage = BestSchool(GetSpellBonusDamage)
    if Caps.retail or not GetSpellBonusHealing then return NUM, damage end
    return NUM_DAMAGE_HEALING, damage, GetSpellBonusHealing() or 0
end

local function ArmorStat()
    if not UnitArmor then return nil end
    local base, effective = UnitArmor("player")
    return NUM, effective or base or 0
end

local function AttackPowerStat()
    if not UnitAttackPower then return nil end
    local melee = Sum(UnitAttackPower("player"))
    if not UnitRangedAttackPower then return NUM, melee end
    return NUM_MELEE_RANGED, melee, Sum(UnitRangedAttackPower("player"))
end

local function Chance(name)
    return function()
        local read = _G[name]
        if not read then return nil end
        return PCT, read() or 0
    end
end


local function HasteStat()
    if Caps.era or not GetHaste then return nil end
    return PCT, GetHaste() or 0
end

local function MasteryStat()
    if not (GetMasteryEffect and (Caps.retail or Caps.mists)) then return nil end
    return PCT, (GetMasteryEffect()) or 0
end

local function VersatilityStat()
    local id = _G["CR_VERSATILITY_DAMAGE_DONE"]
    if not (Caps.retail and id and GetVersatilityBonus) then return nil end
    return PCT, Sum(Rating(id), GetVersatilityBonus(id))
end


local function DefenseStat()
    if not (UnitDefense and (Caps.era or Caps.tbc)) then return nil end
    return NUM, Sum(UnitDefense("player"))
end

local function Attribute(index)
    return function()
        if not UnitStat then return nil end
        local base, effective = UnitStat("player", index)
        return NUM, effective or base or 0
    end
end




local ANSWERS = {
    { keys = { "gold", "money", "cash" },
      label = _G["MONEY"] or "Money", value = GoldValue, copyValue = GoldCopyValue },
    { keys = { "ilvl", "item level", "itemlevel", "gearscore" },
      label = _G["STAT_AVERAGE_ITEM_LEVEL"] or "Item Level", value = ItemLevelValue },
    { keys = { "keystone", "my key", "mythic key" },
      labelKey = "ANSWER_KEYSTONE", value = KeystoneValue },
    { keys = { "rating", "io", "mythic rating", "m+ rating" },
      label = _G["DUNGEON_SCORE"] or "Mythic+ Rating", value = RatingValue },
    { keys = { "durability", "repair" },
      label = _G["DURABILITY"] or "Durability", value = DurabilityValue },
    { keys = { "bag space", "bags free", "free slots", "bagspace" },
      labelKey = "ANSWER_BAG_SPACE", value = BagSpaceValue },
    { keys = { "speed", "movement speed", "move speed" },
      label = _G["SPEED"] or "Speed", value = SpeedValue },
    { keys = { "reset", "resets", "daily reset", "weekly reset", "reset time", "reset timer" },
      labelKey = "ANSWER_RESETS", value = ResetValue },
    { keys = { "next holiday", "next event" }, labelKey = "ANSWER_NEXT_HOLIDAY",
      value = function() return ns.Holidays and ns.Holidays.Next() end },
    { keys = { "crit", "crit chance", "critical strike" },
      label = _G["STAT_CRITICAL_STRIKE"] or "Critical Strike", stat = CritStat },
    { keys = { "hit", "hit chance" }, label = _G["STAT_HIT_CHANCE"] or "Hit Chance", stat = HitStat },
    { keys = { "spell power", "spellpower", "spell damage", "bonus healing" },
      label = _G["STAT_SPELLPOWER"] or "Spell Power", stat = SpellPowerStat },
    { keys = { "armor", "armour" }, label = _G["ARMOR"] or "Armor", stat = ArmorStat },
    { keys = { "attack power" }, label = _G["ATTACK_POWER_TOOLTIP"] or "Attack Power", stat = AttackPowerStat },
    { keys = { "dodge" }, label = _G["STAT_DODGE"] or "Dodge", stat = Chance("GetDodgeChance") },
    { keys = { "parry" }, label = _G["STAT_PARRY"] or "Parry", stat = Chance("GetParryChance") },
    { keys = { "block" }, label = _G["STAT_BLOCK"] or "Block", stat = Chance("GetBlockChance") },
    { keys = { "haste" }, label = _G["STAT_HASTE"] or "Haste", stat = HasteStat },
    { keys = { "mastery" }, label = _G["STAT_MASTERY"] or "Mastery", stat = MasteryStat },
    { keys = { "versatility", "vers" }, label = _G["STAT_VERSATILITY"] or "Versatility", stat = VersatilityStat },
    { keys = { "defense", "defence" }, label = _G["DEFENSE"] or "Defense", stat = DefenseStat },
    { keys = { "strength" }, label = _G["SPELL_STAT1_NAME"] or "Strength", stat = Attribute(1) },
    { keys = { "agility" }, label = _G["SPELL_STAT2_NAME"] or "Agility", stat = Attribute(2) },
    { keys = { "stamina", "stam" }, label = _G["SPELL_STAT3_NAME"] or "Stamina", stat = Attribute(3) },
    { keys = { "intellect" }, label = _G["SPELL_STAT4_NAME"] or "Intellect", stat = Attribute(4) },
    { keys = { "spirit" }, label = _G["SPELL_STAT5_NAME"] or "Spirit", stat = Attribute(5) },
}


local answerByKey = {}
for i = 1, #ANSWERS do
    local def = ANSWERS[i]
    for k = 1, #def.keys do
        answerByKey[def.keys[k]] = def
    end
    if def.stat and def.label then
        local own = slower(def.label)
        answerByKey[own] = answerByKey[own] or def
    end
end





local KEY_GLYPH, boundGlyph = { tex = "Interface\\Icons\\INV_Misc_Key_14" }, {}
local answerEntry = {
    category = "Statistic",
    noPin = true,


    noLearn = true,
}




function Answers:GetAnswerEntry(text)
    if not text then return nil end
    local query = slower(strtrim(text))
    local def = answerByKey[query]
    answerEntry.secretFormat, answerEntry.glyph = nil, nil
    if not def then

        local key, bound, icon = nil, nil, nil
        if ns.Keys then key, bound, icon = ns.Keys.Answer(query) end
        if not key then return nil end
        answerEntry.name, answerEntry.nameLower = key, query
        answerEntry.searchCommandDesc, answerEntry.copyText = bound, bound
        boundGlyph.tex = icon
        answerEntry.glyph = icon and boundGlyph or KEY_GLYPH
        return answerEntry
    end
    local value
    if def.stat then
        local fmt, a, b, c = def.stat()
        if not fmt then return nil end
        if issecret(a) or issecret(b) or issecret(c) then
            local args = answerEntry.secretArgs or {}
            args[1], args[2], args[3] = a, b, c
            answerEntry.secretFormat, answerEntry.secretArgs = fmt, args
        else
            value = sformat(fmt, a, b, c)
        end
    else
        value = def.value()
        if not value then return nil end
    end


    answerEntry.copyText = value and (def.copyValue and def.copyValue() or value) or nil
    answerEntry.name = def.labelKey and L[def.labelKey] or def.label
    answerEntry.nameLower = query
    answerEntry.searchCommandDesc = value
    return answerEntry
end

return Answers
