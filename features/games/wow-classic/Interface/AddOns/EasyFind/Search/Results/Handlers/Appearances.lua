local _, ns = ...

local Handlers = ns.ResultHandlers
local L = ns.L
local C_TransmogSets = C_TransmogSets

local function ResolveTransmogBaseSetID(setID)
    if not setID or not C_TransmogSets then return setID end
    if C_TransmogSets.GetBaseSetID then
        local ok, baseID = pcall(C_TransmogSets.GetBaseSetID, setID)
        if ok and baseID and baseID ~= 0 then return baseID end
    end
    return setID
end

function Handlers:DressUpAppearanceSet(setID)
    if not setID or not C_TransmogSets then return end

    local allIDs = C_TransmogSets.GetAllSourceIDs
        and C_TransmogSets.GetAllSourceIDs(setID)
    if not allIDs or #allIDs == 0 then
        EasyFind:Print(L["ERR_APPEARANCE_SET_LOAD"])
        return
    end

    if DressUpTransmogSet then
        DressUpTransmogSet(allIDs)
    end
end

function Handlers:IsTransmogSetFavorite(setID)
    if not setID or not C_TransmogSets then return false end
    local baseID = ResolveTransmogBaseSetID(setID)
    if C_TransmogSets.GetIsFavorite then
        local ok, fav = pcall(C_TransmogSets.GetIsFavorite, baseID)
        if ok and fav then return true end
    end
    if C_TransmogSets.GetSetInfo then
        local ok, info = pcall(C_TransmogSets.GetSetInfo, baseID)
        if ok and type(info) == "table" and info.favoriteSetID then return true end
        if ok and type(info) == "table" and info.favorite then return true end
    end
    return false
end

function Handlers:ToggleTransmogSetFavorite(setID)
    if not setID or not C_TransmogSets then return end
    local baseID = ResolveTransmogBaseSetID(setID)
    local fav = self:IsTransmogSetFavorite(baseID)
    if C_TransmogSets.SetIsFavorite then
        pcall(C_TransmogSets.SetIsFavorite, baseID, not fav)
    elseif C_TransmogSets.MarkSetFavorite then
        pcall(C_TransmogSets.MarkSetFavorite, baseID, not fav)
    end
end
