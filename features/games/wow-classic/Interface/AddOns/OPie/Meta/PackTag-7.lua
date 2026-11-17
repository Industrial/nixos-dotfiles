local _, T = ...
local LT, LL = T.LT or {}, newproxy(true)
T.L, getmetatable(LL).__call, T.LT = LL, function(_,k,t) return LT[k] or t and type(t) == "string" and t or k end, nil
T[string.char(80,75,84)] = 0xa21f4342 + 0x177b9752