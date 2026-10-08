-- Thanks to RainbowUI on Curse

if(GetLocale() ~= 'zhTW') then
    return
end

local _, ns = ...
local L = ns.L

L["CATEGORY_NAME"] = "低等級";
L["OPTIONS_DESC"] = "選擇要放入此分類的中的物品等級界線 (所有物品等級嚴格低於此數值的物品將被放置在此分類中) 更改數值後，可能會需要重新載入介面。"
L["OPTIONS_INCLUDE_JUNK"] = "灰色品質的物品也要放入此分類";
L["OPTIONS_REFRESH"] = "重新載入介面";
L["OPTIONS_RESET_DEFAULT"] = "重置為預設值";
L["OPTIONS_THRESHOLD"] = "低等級 (預設: _default_)";
L["OPTIONS_THRESHOLD_ERROR"] = "請輸入有效的物品等級數字";
L["OPTIONS_DYNAMIC_TOGGLE"] = "使用基於平均裝備 iLvl 的動態界線";
L["OPTIONS_DYNAMIC_TOGGLE_ACTIVE"] = "使用基於平均裝備 iLvl 的動態界線（目前：_value_）";
L["OPTIONS_DYNAMIC_TOGGLE_DESC"] = "啟用後，物品等級界線將根據您的平均裝備物品等級自動計算。每次修改此處設定時都會重新計算，登入或重新載入介面時也會重新計算；遊戲過程中不會自動變動。";
L["OPTIONS_DYNAMIC_OFFSET"] = "低於平均值的物品等級差（預設: _default_）";
L["OPTIONS_DYNAMIC_OFFSET_DESC"] = "物品等級低於您平均裝備物品等級此數值以上的物品，將被放置在此分類中。";
L["OPTIONS_USE_MAX_ILVL"] = "使用物品可達到的最大 iLvl（若可升級）而非目前 iLvl";
L["OPTIONS_USE_MAX_ILVL_DESC"] = "啟用後，仍可升級的物品將依其升級到最高等級後可達到的 iLvl 進行比較，而非目前 iLvl。不可升級的物品不受影響。";
