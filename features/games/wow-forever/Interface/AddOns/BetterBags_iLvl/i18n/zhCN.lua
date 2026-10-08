-- Thanks to wyeen on Curse

if(GetLocale() ~= 'zhCN') then
    return
end

local _, ns = ...
local L = ns.L

L["CATEGORY_NAME"] = "低等级";
L["OPTIONS_DESC"] = "选择此类别的 iLvl 阈值（所有 iLvl 严格低于此值的项目都将归入此类别）。一旦更改值，可能需要重新加载 UI。"
L["OPTIONS_INCLUDE_JUNK"] = "将质量较差的物品归入此类别";
L["OPTIONS_REFRESH"] = "重载UI";
L["OPTIONS_RESET_DEFAULT"] = "恢复默认值";
L["OPTIONS_THRESHOLD"] = "iLvl 阈值（默认值：_default_）";
L["OPTIONS_THRESHOLD_ERROR"] = "请输入有效的 iLvl 阈值";
L["OPTIONS_DYNAMIC_TOGGLE"] = "使用基于平均装备 iLvl 的动态阈值";
L["OPTIONS_DYNAMIC_TOGGLE_ACTIVE"] = "使用基于平均装备 iLvl 的动态阈值（当前：_value_）";
L["OPTIONS_DYNAMIC_TOGGLE_DESC"] = "启用后，iLvl 阈值将根据你的平均装备物品等级自动计算。每次修改此处设置时都会重新计算，登录或重载 UI 时也会重新计算；游戏过程中不会自动变化。";
L["OPTIONS_DYNAMIC_OFFSET"] = "低于平均值的 iLvl 差值（默认值：_default_）";
L["OPTIONS_DYNAMIC_OFFSET_DESC"] = "iLvl 低于你平均装备物品等级此数值以上的物品将被归入此类别。";
L["OPTIONS_USE_MAX_ILVL"] = "使用物品可达到的最大 iLvl（若可升级）而非当前 iLvl";
L["OPTIONS_USE_MAX_ILVL_DESC"] = "启用后，仍可升级的物品将按其升级到最高等级后可达到的 iLvl 进行比较，而非当前 iLvl。不可升级的物品不受影响。";
