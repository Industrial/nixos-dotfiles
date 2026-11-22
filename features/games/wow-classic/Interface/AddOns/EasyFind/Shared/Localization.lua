local _, ns = ...




















local L = {}
ns.L = L

setmetatable(L, { __index = function(_, k)
    if type(k) == "string" then return k end
    return ""
end })
