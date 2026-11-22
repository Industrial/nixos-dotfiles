local _, ns = ...

local Handlers = ns.ResultHandlers
local Openers = ns.SearchOpeners
local Utils = ns.Utils

local GetButtonText = Utils.GetButtonText
local SearchFrameTreeFuzzy = Utils.SearchFrameTreeFuzzy
local ipairs = Utils.ipairs
local slower = Utils.slower
local C_TransmogOutfitInfo = C_TransmogOutfitInfo

function Handlers:GetOutfitPlayerFacingIndex(outfitID)
    if not outfitID or not C_TransmogOutfitInfo
       or not C_TransmogOutfitInfo.GetOutfitsInfo then
        return nil
    end

    local outfits = C_TransmogOutfitInfo.GetOutfitsInfo()
    if not outfits then return nil end

    if C_TransmogOutfitInfo.GetOutfitInfoByPlayerFacingIndex then
        local maxIndex = #outfits + 20
        for index = 1, maxIndex do
            local ok, info = pcall(C_TransmogOutfitInfo.GetOutfitInfoByPlayerFacingIndex, index)
            if ok and info and info.outfitID == outfitID then
                return index
            end
        end
    end

    for index, info in ipairs(outfits) do
        if info and info.outfitID == outfitID then
            return index
        end
    end
end

function Handlers:GetOutfitSecureIndex(data)
    local outfitID = data and data.outfitID
    if not outfitID then return nil end

    local outfitIndex = self:GetOutfitPlayerFacingIndex(outfitID)
        or data.outfitIndex
    if not outfitIndex then return nil end

    data.outfitIndex = outfitIndex
    return outfitIndex
end

function Handlers:GetOutfitScrollBox()
    local outfitCollection = TransmogFrame and TransmogFrame.OutfitCollection
    local outfitList = outfitCollection and outfitCollection.OutfitList
    if outfitList and outfitList.ScrollBox then return outfitList.ScrollBox end
    if outfitCollection and outfitCollection.ScrollBox then return outfitCollection.ScrollBox end
    if outfitList and outfitList.ListScrollFrame and outfitList.ListScrollFrame.ScrollBox then
        return outfitList.ListScrollFrame.ScrollBox
    end
    local oldScroll = _G["TransmogOutfitListScrollFrame"]
    if oldScroll and oldScroll.ScrollBox then return oldScroll.ScrollBox end
    return nil
end

function Handlers:OutfitElementMatches(edata, outfitID, outfitName)
    if not edata then return false end
    if type(edata) == "number" then return outfitID and edata == outfitID end
    if type(edata) ~= "table" then return false end
    local info = edata.info or edata.outfitInfo or edata.outfit
    local edataOutfitID = edata.outfitID or edata.outfitId or edata.id
        or (info and (info.outfitID or info.outfitId or info.id))
    if outfitID and edataOutfitID == outfitID then return true end
    local name = edata.name or edata.outfitName or edata.displayName
        or (info and (info.name or info.outfitName or info.displayName))
    return outfitName and name and slower(name) == outfitName
end

function Handlers:OutfitButtonMatches(button, outfitID, outfitName)
    if not button then return false end
    if outfitID and (button.outfitID == outfitID or button.outfitId == outfitID or button.id == outfitID) then
        return true
    end
    local text = GetButtonText(button)
    return outfitName and text and slower(text) == outfitName
end

function Handlers:OutfitFrameMatches(frame, outfitID, outfitName)
    if not frame then return false end
    local ok, edata = pcall(function()
        return frame.GetElementData and frame:GetElementData()
    end)
    if ok and self:OutfitElementMatches(edata, outfitID, outfitName) then return true end
    if self:OutfitButtonMatches(frame, outfitID, outfitName) then return true end
    return self:OutfitButtonMatches(frame.OutfitButton, outfitID, outfitName)
end

function Handlers:RevealOutfitInTransmog(data)
    if not (data and data.outfitID and TransmogFrame) then return nil end

    local outfitName = data.name and slower(data.name)
    local scrollBox = self:GetOutfitScrollBox()
    if scrollBox then
        Utils.ScrollBoxScrollTo(scrollBox, function(edata)
            return self:OutfitElementMatches(edata, data.outfitID, outfitName)
        end)
        local row = Utils.ScrollBoxFindButton(scrollBox, function(frame)
            return self:OutfitFrameMatches(frame, data.outfitID, outfitName)
        end)
        if row then return row.OutfitButton or row end
    end

    local outfitCollection = TransmogFrame.OutfitCollection
    if outfitCollection and outfitName then
        return SearchFrameTreeFuzzy(outfitCollection, outfitName)
    end
    return nil
end

function Handlers:OpenOutfitInTransmog(data)
    if not (data and data.outfitID) then return end

    local function showTransmogFrame()
        if not TransmogFrame and Transmog_LoadUI then
            Transmog_LoadUI()
        end
        if TransmogFrame then
            Openers:SecureShowUIPanel(TransmogFrame)
            self:ApplyTransmogBrowseMode()
        end
    end

    local function step(attempt)
        if not (TransmogFrame and TransmogFrame:IsShown()) then
            showTransmogFrame()
            if attempt < 30 then
                Utils.SafeAfter(0.05, function() step(attempt + 1) end)
            end
            return
        end
        if not TransmogFrame._efBrowseMode then
            self:ApplyTransmogBrowseMode()
        end

        local row = self:RevealOutfitInTransmog(data)
        if row and self:HighlightRevealedFrame(row) then return end
        if attempt < 30 then
            Utils.SafeAfter(0.05, function() step(attempt + 1) end)
        end
    end

    step(1)
end
