-- QuestieDB-owned translations imported from pinned Questie's lookupOverrides.lua.
-- Titan changes English entity text, but translation selection belongs entirely to l10n.
-- Keep this declaration separate from byte-identical entity correction copies.
local _, LibQuestieDB = ...
local flavor = LibQuestieDB.flavor
local seasons = rawget(_G, "C_Seasons")
if not flavor or flavor.expansion ~= "Wotlk" or not seasons or
    type(seasons.GetActiveSeason) ~= "function" or seasons.GetActiveSeason() ~= 109 then
  return
end

local keys = LibQuestieDB.Meta.Quest.keys
-- Register even on an English client: locale selection is l10n's job, and reserving the
-- built-in owner's rank at load keeps later consumer translation corrections authoritative.
LibQuestieDB.l10n.SetCorrection("QuestieDB", "zhCN", "Quest", "Titan:zhCN", {
  [6805] = {
    [keys.name] = "大雷暴和巨磐石",
    [keys.objectivesText] = { "消灭15个大型灰尘风暴和15个大型沙漠奔行者，然后回到艾萨拉的海达克西斯公爵那儿。" },
  },
  [7787] = {
    [keys.name] = "昔日的传奇",
    [keys.objectivesText] = { "寻找对休眠之刃有所了解的人。" },
  },
  [8184] = { [keys.name] = "愤怒预言" },
  [8185] = { [keys.name] = "调和预言" },
  [8186] = { [keys.name] = "死亡预言" },
  [8187] = { [keys.name] = "猎鹰化身" },
  [8188] = { [keys.name] = "巫毒预言" },
  [8189] = { [keys.name] = "奥术师预言" },
  [8190] = { [keys.name] = "妖术预言" },
  [8191] = { [keys.name] = "光晕预言" },
  [8192] = { [keys.name] = "万灵预言" },
  -- These ordinary authored overrides target Titan-added entities. Base Localization blocks
  -- cannot encode their IDs; the same seasonal translation set owns their effective rows.
  [93975] = { [keys.name] = "拉格纳罗斯必须死！", [keys.objectivesText] = { "团队消灭拉格纳罗斯。" } },
  [94577] = { [keys.name] = "凯尔萨斯必须死！", [keys.objectivesText] = { "消灭风暴要塞的凯尔萨斯逐日者。" } },
  [94579] = { [keys.name] = "消灭帕奇维克！", [keys.objectivesText] = { "消灭纳克萨玛斯的帕奇维克。" } },
})
