local L, _, ns = {}, ...;

ns.L = setmetatable(L,{__index=function(t,k)
    local v = tostring(k);
    rawset(t,k,v);
    return v;
end});

L["CATEGORY_NAME"] = "Tabards";
