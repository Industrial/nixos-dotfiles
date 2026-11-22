-- The oldest EasyFind these files run on; CI runs the tests against it. On
-- an older one a chat line asks for an update and each code file stops at
-- its first lines (own.tooOld).
local ADDON, own = ...
local MIN_EASYFIND = "4.0.0"

local Meta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata

-- "3.4.4" is older than "4.0.0"; a version it cannot read never is.
local function Older(have, want)
    local h = { tostring(have):match("^(%d+)%.(%d+)%.(%d+)") }
    local w = { want:match("^(%d+)%.(%d+)%.(%d+)") }
    if not h[1] then return false end
    for i = 1, 3 do
        local a, b = tonumber(h[i]), tonumber(w[i])
        if a ~= b then return a < b end
    end
    return false
end

if not (Meta and Older(Meta("EasyFind", "Version"), MIN_EASYFIND)) then return end
own.tooOld = true
local ns = EasyFind and EasyFind._ns
local fmt = ns and ns.L and ns.L["EXT_NEEDS_EASYFIND_FMT"] or "Needs EasyFind %s or later: update EasyFind."
local text = "|cff66ccff" .. (Meta(ADDON, "Title") or ADDON) .. ":|r " .. fmt:format(MIN_EASYFIND)
if IsLoggedIn() then
    print(text)
    return
end
local login = CreateFrame("Frame")
login:Hide()
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    print(text)
end)
