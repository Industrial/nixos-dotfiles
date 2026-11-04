local L, _, ns = {}, ...;

ns.L = setmetatable(L,{__index=function(t,k)
    local v = tostring(k);
    rawset(t,k,v);
    return v;
end});

L["CATEGORY_NAME"] = "Low iLvl";
L["OPTIONS_DESC"] = "Select the iLvl threshold for this category (all items with an iLvl strictly below this value will be placed in this category). Once the value is changed, a UI reload may be necessary.";
L["OPTIONS_INCLUDE_JUNK"] = "Include poor quality items in this category";
L["OPTIONS_REFRESH"] = "Reload UI";
L["OPTIONS_RESET_DEFAULT"] = "Reset to default";
L["OPTIONS_THRESHOLD"] = "iLvl Threshold (default: _default_)";
L["OPTIONS_THRESHOLD_ERROR"] = "Please enter a valid number for the iLvl threshold.";
L["OPTIONS_DYNAMIC_TOGGLE"] = "Use a dynamic threshold based on your average equipped iLvl";
L["OPTIONS_DYNAMIC_TOGGLE_ACTIVE"] = "Use a dynamic threshold based on your average equipped iLvl (currently: _value_)";
L["OPTIONS_DYNAMIC_TOGGLE_DESC"] = "When enabled, the iLvl threshold is calculated automatically from your average equipped item level. It is recalculated whenever you change the settings here, and again each time you log in or reload your UI; it never changes automatically while you are playing.";
L["OPTIONS_DYNAMIC_OFFSET"] = "iLvl difference below your average (default: _default_)";
L["OPTIONS_DYNAMIC_OFFSET_DESC"] = "Items whose iLvl is more than this amount below your average equipped item level will be placed in this category.";
L["OPTIONS_USE_MAX_ILVL"] = "Use each item's maximum possible iLvl (if upgradable) instead of its current iLvl";
L["OPTIONS_USE_MAX_ILVL_DESC"] = "When enabled, items that can still be upgraded are compared using the iLvl they could reach at maximum upgrade, not their current iLvl. Items that aren't upgradable are unaffected.";
