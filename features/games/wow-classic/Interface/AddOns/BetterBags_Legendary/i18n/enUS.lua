local L, _, ns = {}, ...;

ns.L = setmetatable(L,{__index=function(t,k)
    local v = tostring(k);
    rawset(t,k,v);
    return v;
end});

L["CATEGORY_NAME"] = "Legendary+";
L["OPTIONS_DESC"] = "Create independent categories for qualities above legendary (artifact, heirloom, WoW token)"
L["OPTIONS_INDE_CAT"] = "Independent categories"
L["OPTIONS_CAT_LEGENDARY"] = "Legendary"
L["OPTIONS_CAT_ARTIFACT"] = "Artifact"
L["OPTIONS_CAT_HEIRLOOM"] = "Heirloom"
L["OPTIONS_CAT_TOKEN"] = "WoW Token"
L["OPTIONS_REFRESH"] = "Reload UI";
