local _, ns = ...

local Search = ns.Search
local Results = ns.Results

local collapsedNodes = {}
local flatEntries = {}
local flatCombined = {}

local SCRATCH = {
    visible = {},
    isLastChild = {},
    catSepYPositions = {},
    aliasSeen = {},
    mapBoostSeen = {},
    mapNaturalScore = {},
    catalogBoostSeen = {},
    calculatorResults = {},
    filteredResults = {},
    quickFilterResults = {},

    factAsked = {},
    factResults = {},
    skipCategories = {},
    currencyInfoCache = {},
    renderState = {},
    launchers = {},

    rowTops = {},
    rowHeights = {},
    frameOfRow = {},

    tail = {},
}

Results._cachedHierarchical = nil
Results._flatEntries = flatEntries
Results._flatCombined = flatCombined
Results._collapsedNodes = collapsedNodes
Results._SCRATCH = SCRATCH
Results._resultButtons = Search:GetResultButtons()
