local _, ns = ...

local Search = ns.Search
local Results = ns.Results
local Utils = ns.Utils
local UIPins = ns.UIPins

local GetAllPins = UIPins.GetAll

function Results:HasPinnedItems()
    return #GetAllPins() > 0
end

function Results:ShowPinPopup(anchorFrame, isPinned, onPinAction, onGuide, onAddAlias, extra)
    local opts = {
        strata = "TOOLTIP",
        level = 100,
        width = 96,
        rowHeight = 22,
        scale = (EasyFind and EasyFind.db and EasyFind.db.uiSearchScale) or 1.0,
    }
    if extra and extra.keyboardMode then
        opts.keyboardMode = true
        opts.anchorFrame = anchorFrame
    end
    opts.onHide = extra and extra.onHide
    return Utils.ShowPinMenu("EasyFindPinPopup", isPinned, onPinAction, onGuide, onAddAlias, opts, extra)
end



function Results:ConsumeKeepPinnedResultsOpen()
    local keepUntil = Results._keepPinnedResultsOpenUntil
    if not keepUntil then return false end
    Results._keepPinnedResultsOpenUntil = nil
    return (GetTime and GetTime() or 0) <= keepUntil
end

function Results:KeepPinnedResultsOpenBriefly()
    if not Results:HasPinnedItems() then return false end
    Results._keepPinnedResultsOpenUntil = (GetTime and GetTime() or 0) + 0.35

    local searchFrame = Search:GetSearchFrame()
    if searchFrame and searchFrame.editBox
       and strtrim(searchFrame.editBox:GetText() or "") == "" then
        Results:ShowEmptyQueryView()
    end
    return true
end
