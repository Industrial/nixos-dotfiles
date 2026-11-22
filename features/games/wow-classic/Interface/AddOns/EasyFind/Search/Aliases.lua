local _, ns = ...

local Search = ns.Search
local Handlers = ns.ResultHandlers
local L = ns.L
local sformat = ns.Utils.sformat





function Handlers:PromptForAlias(data)
    if not data then return end
    local label = data.name or L["ALIAS_THIS_ENTRY"]
    local canCategory = data.mapSearchResult and data.category
        and ns.MapSearchData and ns.MapSearchData.CATEGORIES
        and ns.MapSearchData.CATEGORIES[data.category] and true or false


    local catLabel = canCategory and ns.Filters and ns.Filters.MapCategoryFilterLabel
        and ns.Filters.MapCategoryFilterLabel(data.category)
    local checkText
    if canCategory then
        checkText = catLabel and sformat(L["ALIAS_WHOLE_CATEGORY_CHECK"], catLabel)
            or L["ALIAS_WHOLE_CATEGORY_GENERIC"]
    end
    ns.ShowThemedDialog({
        text = (L["PROMPT_ALIAS_FOR"]):format(label),



        textChecked = canCategory
            and (L["PROMPT_ALIAS_FOR_CATEGORY"]):format(catLabel or data.category) or nil,
        messageColor = ns.GOLD_COLOR,
        hasEditBox = true,
        maxLetters = 64,
        checkText = checkText,
        onAccept = function(txt, wholeCategory)
            txt = strtrim(txt or "")
            if txt == "" then return end
            local added
            if canCategory and wholeCategory then
                local targetName = sformat(L["ALIAS_CATEGORY_LABEL"], catLabel or data.name or data.category)
                added = ns.Aliases and ns.Aliases:AddCategory(txt, data.category, targetName)
            else
                added = ns.Aliases and ns.Aliases:Add(txt, data)
            end
            if added then
                local searchFrame = Search:GetSearchFrame()
                local searchEditBox = searchFrame and searchFrame.editBox
                local current = searchEditBox and searchEditBox:GetText() or ""
                if current ~= "" then Search:OnSearchTextChanged(current) end
                if ns.RefreshBindTables then ns.RefreshBindTables() end
            end
        end,
    })
end
