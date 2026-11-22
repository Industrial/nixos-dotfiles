local _, ns = ...

local Utils = ns.Utils
local Results = ns.Results
local Render = ns.ResultRender
local Icons = ns.ResultIcons
local Text = ns.ResultText

local ipairs = Utils.ipairs
local GOLD_COLOR = Render.GOLD_COLOR
local GetButtonIcon = Icons.GetButtonIcon
local GetCachedCurrencyInfo = Render.GetCachedCurrencyInfo
local SetClippedText = Render.SetClippedText

function Render.IsUnearnedCurrencyEntry(entry, state)
    local data = entry.data
    if not data or data.category ~= "Currency" then return false end

    if entry.isPathNode then
        local depth = entry.depth or 0
        local hasAnyEarnedChild = false
        local hasAnyChild = false
        for j = state.rowIndex + 1, state.count do
            local childEntry = state.visible[j]
            local childDepth = childEntry.depth or 0
            if childDepth <= depth then break end
            if childDepth == depth + 1 and childEntry.data and childEntry.data.steps then
                hasAnyChild = true
                for _, step in ipairs(childEntry.data.steps) do
                    if step.currencyID then
                        local currencyInfo = GetCachedCurrencyInfo(step.currencyID)
                        if currencyInfo and (currencyInfo.quantity > 0
                            or (currencyInfo.totalEarned and currencyInfo.totalEarned > 0)
                            or currencyInfo.useTotalEarnedForMaxQty
                            or currencyInfo.discovered == true) then
                            hasAnyEarnedChild = true
                            break
                        end
                    end
                end
                if hasAnyEarnedChild then break end
            end
        end
        return hasAnyChild and not hasAnyEarnedChild
    end

    if data.steps then
        for _, step in ipairs(data.steps) do
            if step.currencyID then
                local currencyInfo = GetCachedCurrencyInfo(step.currencyID)
                if currencyInfo and currencyInfo.quantity == 0 then
                    local isDiscovered = (currencyInfo.totalEarned and currencyInfo.totalEarned > 0)
                        or currencyInfo.useTotalEarnedForMaxQty
                        or currencyInfo.discovered == true
                    return not isDiscovered
                end
                break
            end
        end
    end
    return false
end



function Render.BaseRowText(resultRow, entry, state)
    if entry.isPinHeader or entry.isSectionHeader
       or (state.theme.showHeaderTab and entry.isPathNode) then
        if resultRow.pathSubtext then resultRow.pathSubtext:Hide() end
        if resultRow.flatCatIcon then resultRow.flatCatIcon:Hide() end
        return
    end

    local theme = state.theme
    local data = entry.data
    local depth = entry.depth or 0
    local indentPixels = depth * state.indPx
    resultRow.icon:ClearAllPoints()







    resultRow.amountText:ClearAllPoints()
    resultRow.amountText:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)

    if entry.isFlat then
        local catIconDef = Icons:GetFlatCategoryIcon(data)
        local leftAnchor
        local synthBtn
        if not catIconDef and data and (data.specificIcon or data.specificIconFrame)
           and data.buttonFrame then
            synthBtn = data.buttonFrame
        end
        if catIconDef or synthBtn then
            local sz = state.entryRowH - 16
            local btnFrame = synthBtn or (catIconDef and catIconDef.buttonFrame)
            if btnFrame then
                local texture, isAtlas = GetButtonIcon(btnFrame)
                if isAtlas then
                    resultRow.flatCatIcon:SetAtlas(texture)
                    resultRow.flatCatIcon:SetTexCoord(0, 1, 0, 1)
                elseif type(texture) == "table" then
                    resultRow.flatCatIcon:SetTexture(texture.file)
                    resultRow.flatCatIcon:SetTexCoord(unpack(texture.coords))
                elseif texture then
                    resultRow.flatCatIcon:SetTexture(texture)
                    resultRow.flatCatIcon:SetTexCoord(0, 1, 0, 1)
                else
                    resultRow.flatCatIcon:SetTexture(134400)
                    resultRow.flatCatIcon:SetTexCoord(0, 1, 0, 1)
                end
            elseif catIconDef.portrait then
                SetPortraitTexture(resultRow.flatCatIcon, catIconDef.portrait)
                resultRow.flatCatIcon:SetTexCoord(0, 1, 0, 1)
            elseif catIconDef.atlas then
                resultRow.flatCatIcon:SetAtlas(catIconDef.atlas)
                resultRow.flatCatIcon:SetTexCoord(0, 1, 0, 1)
            else
                resultRow.flatCatIcon:SetTexture(catIconDef.tex)
                if catIconDef.coords then
                    resultRow.flatCatIcon:SetTexCoord(unpack(catIconDef.coords))
                else
                    resultRow.flatCatIcon:SetTexCoord(0, 1, 0, 1)
                end
            end
            if catIconDef and catIconDef.chromeTint then
                local gc = ns.ChromeGlyphColor()
                resultRow.flatCatIcon:SetDesaturated(true)
                resultRow.flatCatIcon:SetVertexColor(gc[1], gc[2], gc[3], 1)
            elseif catIconDef and catIconDef.color then
                resultRow.flatCatIcon:SetDesaturated(false)
                resultRow.flatCatIcon:SetVertexColor(unpack(catIconDef.color))
            else
                resultRow.flatCatIcon:SetDesaturated(catIconDef and catIconDef.desaturate or false)
                resultRow.flatCatIcon:SetVertexColor(1, 1, 1, 1)
            end
            ns.SizeIconAspect(resultRow.flatCatIcon, sz, catIconDef and catIconDef.aspect)
            resultRow.flatCatIcon:ClearAllPoints()
            resultRow.flatCatIcon:SetPoint("LEFT", resultRow, "LEFT", indentPixels + 2, 0)
            resultRow.flatCatIcon:Show()
            leftAnchor = resultRow.flatCatIcon
        else
            resultRow.flatCatIcon:Hide()
            resultRow.icon:SetPoint("LEFT", resultRow, "LEFT", indentPixels + 2, 0)
            leftAnchor = resultRow.icon
        end

        resultRow.text:ClearAllPoints()
        resultRow.text:SetPoint("BOTTOMLEFT", leftAnchor, "RIGHT", 6, state.stackHalfGap)
        resultRow.text:SetPoint("RIGHT", resultRow.amountText, "LEFT", -4, 0)
        Results:SetScaledFont(resultRow.text, theme.pathFont)



        resultRow.text:SetTextColor(unpack(theme.leafColor))

        SetClippedText(resultRow.text, Render.NameText(entry))

        resultRow.pathSubtext:ClearAllPoints()
        resultRow.pathSubtext:SetPoint("TOPLEFT", resultRow.text, "BOTTOMLEFT", 0, -state.stackGap)
        resultRow.pathSubtext:SetPoint("RIGHT", resultRow.amountText, "LEFT", -4, 0)
        resultRow.pathSubtext:SetText(Text:GetShownSubtext(data))
        Results:SetScaledFont(resultRow.pathSubtext, theme.leafFont)
        resultRow.pathSubtext:SetTextColor(unpack(theme.pathColor))
        resultRow.pathSubtext:Show()
        return
    end

    resultRow.icon:SetPoint("LEFT", resultRow, "LEFT", indentPixels, 0)
    if resultRow.flatCatIcon then resultRow.flatCatIcon:Hide() end

    resultRow.text:ClearAllPoints()
    resultRow.text:SetPoint("LEFT", resultRow.icon, "RIGHT", 4, 0)
    resultRow.text:SetPoint("RIGHT", resultRow.amountText, "LEFT", -4, 0)
    if resultRow.pathSubtext then resultRow.pathSubtext:Hide() end

    if entry.isPathNode then
        Results:SetScaledFont(resultRow.text, theme.pathFont)
        if entry.isMatch then
            resultRow.text:SetTextColor(Utils.RGB(GOLD_COLOR, 1.0))
        else
            resultRow.text:SetTextColor(unpack(theme.pathColor))
        end
    elseif entry.isMatch then
        Results:SetScaledFont(resultRow.text, theme.leafFont)
        resultRow.text:SetTextColor(Utils.RGB(GOLD_COLOR, 1.0))
    else
        Results:SetScaledFont(resultRow.text, theme.leafFont)
        resultRow.text:SetTextColor(unpack(theme.leafColor))
    end
    SetClippedText(resultRow.text, entry.name)
end
