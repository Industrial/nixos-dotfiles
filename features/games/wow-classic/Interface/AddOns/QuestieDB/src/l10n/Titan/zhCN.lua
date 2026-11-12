-- QuestieDB-owned Titan Reforged zhCN translations.
-- Titan changes English entity text, but translation selection belongs entirely to l10n.
-- Keep this declaration separate from byte-identical entity correction copies.
--
-- Titan Reforged adds entities the Baked Localization blocks cannot address: their IDs are
-- absent from the base backend, so Generation never assigns them a column position. Those rows
-- are registered here as Dynamic Translation Corrections, sourced from l10n/wotlk/lookup*/zhCN.lua.
-- Base entities Titan re-authors in place keep authored rows, because l10n still carries the
-- original WotLK text for them.
local _, LibQuestieDB = ...
local flavor = LibQuestieDB.flavor
local seasons = rawget(_G, "C_Seasons")
if not flavor or flavor.expansion ~= "Wotlk" or not seasons or
    type(seasons.GetActiveSeason) ~= "function" or seasons.GetActiveSeason() ~= 109 then
  return
end

local questKeys = LibQuestieDB.Meta.Quest.keys
local npcKeys = LibQuestieDB.Meta.Npc.keys
local itemKeys = LibQuestieDB.Meta.Item.keys
local objectKeys = LibQuestieDB.Meta.Object.keys
-- Register even on an English client: locale selection is l10n's job, and reserving the
-- built-in owner's rank at load keeps later consumer translation corrections authoritative.
LibQuestieDB.l10n.SetCorrection("QuestieDB", "zhCN", "Quest", "Titan:zhCN", {
  -- Authored overrides for base quests Titan re-authors in place.
  [6805] = { [questKeys.name] = "大雷暴和巨磐石", [questKeys.objectivesText] = { "消灭15个大型灰尘风暴和15个大型沙漠奔行者，然后回到艾萨拉的海达克西斯公爵那儿。" } },
  [7787] = { [questKeys.name] = "昔日的传奇", [questKeys.objectivesText] = { "寻找对休眠之刃有所了解的人。" } },
  [8184] = { [questKeys.name] = "愤怒预言" },
  [8185] = { [questKeys.name] = "调和预言" },
  [8186] = { [questKeys.name] = "死亡预言" },
  [8187] = { [questKeys.name] = "猎鹰化身" },
  [8188] = { [questKeys.name] = "巫毒预言" },
  [8189] = { [questKeys.name] = "奥术师预言" },
  [8190] = { [questKeys.name] = "妖术预言" },
  [8191] = { [questKeys.name] = "光晕预言" },
  [8192] = { [questKeys.name] = "万灵预言" },
  [13816] = { [questKeys.name] = "天文台"},
  [13817] = { [questKeys.name] = "档案馆数据圆盘"},
  [13818] = { [questKeys.name] = "奥尔加隆" },
  [13821] = { [questKeys.name] = "弗蕾亚的徽记"},
  [13822] = { [questKeys.name] = "霍迪尔的徽记" },
  [13823] = { [questKeys.name] = "托里姆的徽记" },
  [13824] = { [questKeys.name] = "米米尔隆的徽记"},
  -- Derived from l10n/wotlk/lookupQuests/zhCN.lua: quests Titan adds.
  [93950] = { [questKeys.name] = "来自群星的消息", [questKeys.objectivesText] = { "接受奥尔加隆的礼物。" } },
  [93975] = { [questKeys.name] = "拉格纳罗斯必须死！", [questKeys.objectivesText] = { "团队消灭拉格纳罗斯。" } },
  [94376] = { [questKeys.name] = "泰坦能量", [questKeys.objectivesText] = { "与奥尔加隆交谈，了解泰坦余烬。" } },
  [94576] = { [questKeys.name] = "另辟蹊径", [questKeys.objectivesText] = { "想办法为风吻之刃供能，随后回到达拉然下水道的高阶督军乌洛处。" } },
  [94577] = { [questKeys.name] = "凯尔萨斯必须死！", [questKeys.objectivesText] = { "消灭风暴要塞的凯尔萨斯逐日者。" } },
  [94579] = { [questKeys.name] = "消灭帕奇维克！", [questKeys.objectivesText] = { "消灭纳克萨玛斯的帕奇维克。" } },
  [95037] = { [questKeys.name] = "消灭加拉克苏斯大王！", [questKeys.objectivesText] = { "消灭加拉克苏斯大王。" } },
  [95072] = { [questKeys.name] = "妖术化身" },
  [95074] = { [questKeys.name] = "猎鹰预言" },
  [95075] = { [questKeys.name] = "毁灭预言" },
  [95076] = { [questKeys.name] = "神圣预言" },
  [95077] = { [questKeys.name] = "救赎者预言" },
  [95078] = { [questKeys.name] = "防护预言" },
  [95079] = { [questKeys.name] = "风暴召唤者预言" },
  [95080] = { [questKeys.name] = "巫医预言" },
  [95081] = { [questKeys.name] = "守护预言" },
  [95082] = { [questKeys.name] = "银月预言" },
  [95083] = { [questKeys.name] = "拜灵者预言" },
  [95084] = { [questKeys.name] = "恐惧预言" },
  [95085] = { [questKeys.name] = "亵渎者预言" },
  [95088] = { [questKeys.name] = "死亡化身" },
  [95089] = { [questKeys.name] = "奥术师化身" },
  [95090] = { [questKeys.name] = "亵渎化身" },
  [95092] = { [questKeys.name] = "恐惧化身" },
  [95093] = { [questKeys.name] = "防护化身" },
  [95094] = { [questKeys.name] = "愤怒化身" },
  [95095] = { [questKeys.name] = "光环化身" },
  [95096] = { [questKeys.name] = "毁灭化身" },
  [95097] = { [questKeys.name] = "调和化身" },
  [95098] = { [questKeys.name] = "神圣化身" },
  [95099] = { [questKeys.name] = "救赎者化身" },
  [95100] = { [questKeys.name] = "巫医化身" },
  [95101] = { [questKeys.name] = "巫毒化身" },
  [95102] = { [questKeys.name] = "风暴召唤者化身" },
  [95103] = { [questKeys.name] = "守护化身" },
  [95104] = { [questKeys.name] = "万灵化身" },
  [95105] = { [questKeys.name] = "银月化身" },
  [95106] = { [questKeys.name] = "拜灵者化身" },
  [95205] = { [questKeys.name] = "强效赞达拉铭文" },
  [95705] = { [questKeys.name] = "“哥布”的黑市盛大开业！", [questKeys.objectivesText] = { "老板“哥布”金痕想让你从他的黑市库存里买一个贪婪宝箱，证明你是一个值得坑——呃。值得服务的付费客户。" } },
  [95706] = { [questKeys.name] = "“哥布”的每周贪婪交易", [questKeys.objectivesText] = { "从老板“哥布”金痕的限量库存中购买每周贪婪宝箱。货源每周重置。如果错过了，那就自认倒霉吧！" } },
  [95844] = { [questKeys.name] = "“哥布”的至尊坦克诱惑", [questKeys.objectivesText] = { "从老板“哥布”金痕的限量库存中购买每周黑色其拉宝箱。货源每周重置。如果错过了，那就自认倒霉吧！" } },
  [95845] = { [questKeys.name] = "再次博一把甲虫", [questKeys.objectivesText] = { "从老板“哥布”金痕的限量库存中购买每周黑色其拉宝箱。货源每周重置。如果错过了，那就自认倒霉吧！" } },
  [96211] = { [questKeys.name] = "艾瑞达之心", [questKeys.objectivesText] = { "为艾瑞达之心寻找合适的用途。" } },
  [96312] = { [questKeys.name] = "消灭布鲁塔卢斯！", [questKeys.objectivesText] = { "消灭布鲁塔卢斯。" } },
  [96315] = { [questKeys.name] = "消灭XT-002拆解者！", [questKeys.objectivesText] = { "消灭XT-002拆解者。" } },
  [96318] = { [questKeys.name] = "消灭埃兰之影！", [questKeys.objectivesText] = { "消灭埃兰之影。" } },
  [98183] = { [questKeys.name] = "重启仪式", [questKeys.objectivesText] = { "接受强化赞达拉宝石。" } },
})

LibQuestieDB.l10n.SetCorrection("QuestieDB", "zhCN", "Npc", "Titan:zhCN", {
  [80007] = { [npcKeys.name] = "？" },
  [256887] = { [npcKeys.name] = "大型灰尘风暴" },
  [256889] = { [npcKeys.name] = "大型沙漠奔行者" },
  [257012] = { [npcKeys.name] = "观察者奥尔加隆" },
  [257403] = { [npcKeys.name] = "观察者奥尔加隆" },
  [262258] = { [npcKeys.name] = "“哥布”金痕老大" },
})

-- Titan remaps items 268145 and 274994, so align by their Titan English names rather than
-- trusting the swapped zhCN rows in the owned lookup.
LibQuestieDB.l10n.SetCorrection("QuestieDB", "zhCN", "Item", "Titan:zhCN", {
  [264272] = { [itemKeys.name] = "天界信函" },
  [268145] = { [itemKeys.name] = "打孔的巫毒人偶" },
  [272955] = { [itemKeys.name] = "艾瑞达之心" },
  [274994] = { [itemKeys.name] = "原始哈卡莱神像" },
  [279578] = { [itemKeys.name] = "强化赞达拉宝石" },
})

LibQuestieDB.l10n.SetCorrection("QuestieDB", "zhCN", "Object", "Titan:zhCN", {
  [420002] = { [objectKeys.name] = "血之祭坛" },
})
