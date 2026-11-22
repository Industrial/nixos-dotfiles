local _, ns = ...

local Search = ns.Search
local Results = ns.Results
local Utils = ns.Utils
local Render = ns.ResultRender
local Icons = ns.ResultIcons




function ns.ResultRender.NameText(entry)
    if not entry then return nil end


    local hex = entry.nameHex or (entry.data and entry.data.nameHex)

    if not hex and entry.data and ns.SkillUps then hex = ns.SkillUps.Hex(entry.data) end
    if hex and entry.name and entry.name ~= "" then return hex .. entry.name .. "|r" end
    return entry.name
end

local select, ipairs = Utils.select, Utils.ipairs
local sfind = Utils.sfind
local SetPortraitTextureFromCreatureDisplayID = _G.SetPortraitTextureFromCreatureDisplayID




local function ForgetFace(icon) icon._efFace = nil end
local function DrawFace(row, face)
    local icon = row.icon
    SetPortraitTextureFromCreatureDisplayID(icon, face)
    if not icon._efFaceWatched and hooksecurefunc then
        icon._efFaceWatched = true
        hooksecurefunc(icon, "SetTexture", ForgetFace)
        hooksecurefunc(icon, "SetAtlas", ForgetFace)
        hooksecurefunc(icon, "SetColorTexture", ForgetFace)
    end
    icon._efFace = face
end


function Render.DrawPendingFaces(scrollFrame)
    local buttons = Search:GetResultButtons()
    local top, bottom = scrollFrame and scrollFrame:GetTop(), scrollFrame and scrollFrame:GetBottom()
    if not (buttons and top and bottom) then return end
    for i = 1, #buttons do
        local row = buttons[i]
        local face = row._efFacePending
        if face and row:IsShown() then
            local rowTop, rowBottom = row:GetTop(), row:GetBottom()
            if rowTop and rowBottom and rowBottom < top and rowTop > bottom then
                row._efFacePending = nil
                DrawFace(row, face)
            end
        end
    end
end
local InCombatLockdown = InCombatLockdown
local GetItemCooldown = (C_Item and C_Item.GetItemCooldown) or GetItemCooldown
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local sgsub, supper = string.gsub, string.upper







local TITLE_SMALL_WORDS = {
    ["of"] = true, ["the"] = true, ["a"] = true, ["an"] = true,
    ["and"] = true, ["or"] = true, ["in"] = true, ["on"] = true,
    ["to"] = true, ["for"] = true, ["with"] = true, ["from"] = true,
    ["at"] = true, ["by"] = true,
}
local titleCaseFirst
local function TitleCaseWord(word)
    if not titleCaseFirst and TITLE_SMALL_WORDS[word] then return word end
    titleCaseFirst = false
    return (sgsub(word, "^%l", supper))
end
local function TitleCaseName(lower)
    titleCaseFirst = true
    return (sgsub(lower, "%S+", TitleCaseWord))
end
local collapsedNodes = Results._collapsedNodes




local function PaintAmountText(amountText, inert)
    local theme = Results.GetActiveTheme and Results:GetActiveTheme()
    if theme and theme.lightTheme then
        local c = inert and theme.textFaint or theme.mutedGlyph
        amountText:SetTextColor(c[1], c[2], c[3], 1)
    elseif inert then
        amountText:SetTextColor(0.5, 0.5, 0.5, 1.0)
    else
        amountText:SetTextColor(0.9, 0.82, 0.65, 1.0)
    end
end
local GetCoinTextureString = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString or GetCoinTextureString
local DECOR_WARN, DECOR_WARN_LIGHT, DECOR_GOOD_LIGHT = { 1.0, 0.58, 0.22 }, { 0.72, 0.36, 0.05 }, { 0.12, 0.50, 0.18 }





function Render.DecorateRow(resultRow, entry, state)
    local slot = resultRow.decorText
    if not slot then return end
    local data, Ext = entry.data, ns.Extensions
    if not (data and entry.isFlat and Ext and Ext.DecoratorText) or entry.isPathNode or entry.isSectionHeader
       or entry.isPinHeader or data.calculatorResult then
        slot:Hide()
        return
    end
    local gen = Ext.Decorators.generation
    if resultRow._decorData ~= data or resultRow._decorGen ~= gen then
        local value, word = Ext.DecoratorText("price", data)
        if type(value) == "number" then value = GetCoinTextureString and GetCoinTextureString(value) or tostring(value) end
        resultRow._decorData, resultRow._decorGen, resultRow._decorValue, resultRow._decorWord = data, gen, value, word
    end
    local value = resultRow._decorValue
    if not value then
        slot:Hide()
        return
    end
    slot:SetText(value)
    local word, light = resultRow._decorWord, state.theme and state.theme.lightTheme
    if word == "good" then
        local c = light and DECOR_GOOD_LIGHT or ns.COPIED_COLOR
        slot:SetTextColor(c[1], c[2], c[3], 1)
    elseif word == "warn" then
        local c = light and DECOR_WARN_LIGHT or DECOR_WARN
        slot:SetTextColor(c[1], c[2], c[3], 1)
    else
        PaintAmountText(slot, false)
    end
    slot:ClearAllPoints()
    if resultRow.amountText:IsShown() then
        slot:SetPoint("RIGHT", resultRow.amountText, "LEFT", -6, 0)
    elseif resultRow.icon:IsShown() and resultRow.icon:GetPoint(1) == "RIGHT" then
        slot:SetPoint("RIGHT", resultRow.icon, "LEFT", -3, 0)
    else
        slot:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
    end
    slot:Show()
end




function Render.SecretValue(resultRow, entry, state)
    local data = entry.data
    local slot = resultRow.secretText
    if not (data and data.secretFormat and entry.isFlat) then
        if slot then slot:Hide() end
        return
    end
    if not slot then
        slot = resultRow:CreateFontString(nil, "OVERLAY", ns.LEAF_FONT)
        slot:SetJustifyH("LEFT")
        slot:SetWordWrap(false)
        slot:SetMaxLines(1)
        resultRow.secretText = slot
    end
    slot:ClearAllPoints()
    slot:SetPoint("TOPLEFT", resultRow.pathSubtext, "TOPLEFT", 0, 0)
    slot:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
    Results:SetScaledFont(slot, state.theme.leafFont)
    slot:SetTextColor(unpack(state.theme.pathColor))
    local args = data.secretArgs
    slot:SetFormattedText(data.secretFormat, args[1], args[2], args[3])
    slot:Show()
end

local GetButtonIcon = Icons.GetButtonIcon
local GetFrameArtworkIcon = Icons.GetFrameArtworkIcon
local IsMenuBarSpecificIconData = Icons.IsMenuBarSpecificIconData
local SetButtonFrameIcon = Icons.SetButtonFrameIcon
local BOSS_PORTRAIT_TEXCOORD = Render.BOSS_PORTRAIT_TEXCOORD

function Render.RowContent(owner, resultRow, entry, state, isInertRow)
    local data = entry.data
    local depth = entry.depth or 0
    local theme = state.theme
    local rowIconSize = state.rowIconSize
    local indPx = state.indPx
    local entryRowH = state.entryRowH
    local hasRepSideBySide = false
    local iconSet = false




    if resultRow.iconCooldown then resultRow.iconCooldown:Hide() end
    resultRow._efFacePending = nil





    if resultRow._specBadge then resultRow._specBadge:Hide() end
    if resultRow.iconLetter then resultRow.iconLetter:Hide() end
    if resultRow._lockOverlay then Search:UpdateOutfitLockOverlay(resultRow, false) end
    local isCurrencyItem = data and data.category == "Currency"
    local isCurrencyLeaf = isCurrencyItem and not entry.isPathNode
    local isReputationLeaf = data and data.category == "Reputation" and not entry.isPathNode

    if entry.isSectionHeader then


        Icons:SetRowIcon(resultRow, "hidden", nil, rowIconSize)
        resultRow.amountText:Hide()
        if resultRow.repBar then resultRow.repBar:Hide() end
        iconSet = true

    elseif entry.isPinHeader then

        Icons:SetRowIcon(resultRow, "hidden", nil, rowIconSize)
        iconSet = true

    elseif theme.showHeaderTab and entry.isPathNode then
        Icons:SetRowIcon(resultRow, "hidden", nil, rowIconSize)
        iconSet = true

    elseif entry.isPathNode then
        local key = entry.name .. "_" .. depth
        local nodeCollapsed = collapsedNodes[key]
        local iconPath = nodeCollapsed and theme.expandIcon or theme.collapseIcon
        Icons:SetRowIcon(resultRow, "path", iconPath, theme.pathIconSize)
        iconSet = true
    end


    if not iconSet and isCurrencyItem and data and not data.icon and data.steps then
        for si = #data.steps, 1, -1 do
            local cid = data.steps[si].currencyID
            if cid then
                local ci = Render.GetCachedCurrencyInfo(cid)
                if ci and ci.iconFileID and ci.iconFileID ~= 0 then
                    data.icon = ci.iconFileID
                end
                break
            end
        end
    end


    if isCurrencyLeaf and data and data.steps then
        local quantity, iconFileID
        for si = #data.steps, 1, -1 do
            local cid = data.steps[si].currencyID
            if cid then
                local ci = Render.GetCachedCurrencyInfo(cid)
                if ci then
                    quantity = ci.quantity
                    iconFileID = data.icon or (ci.iconFileID ~= 0 and ci.iconFileID) or nil
                end
                break
            end
        end

        if quantity then
            resultRow.amountText:SetText(tostring(quantity))
            PaintAmountText(resultRow.amountText, isInertRow)
            resultRow.amountText:Show()
        else
            resultRow.amountText:Hide()
        end


        if iconFileID then
            resultRow.icon:SetTexture(nil)
            resultRow.icon:SetTexCoord(0, 1, 0, 1)
            resultRow.icon:SetTexture(iconFileID)
            resultRow.icon:SetSize(rowIconSize, rowIconSize)
            resultRow.icon:ClearAllPoints()
            resultRow.icon:SetPoint("RIGHT", resultRow, "RIGHT", -5, 0)
            resultRow.icon:Show()
            resultRow.amountText:ClearAllPoints()
            resultRow.amountText:SetPoint("RIGHT", resultRow.icon, "LEFT", -3, 0)
        else
            Icons:SetRowIcon(resultRow, "hidden", nil, rowIconSize)
            resultRow.amountText:ClearAllPoints()
            resultRow.amountText:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
        end




        local indentPixels = depth * indPx
        local leftAnchor
        local catIconDef = Icons:GetFlatCategoryIcon({ category = "Currency" })
        if catIconDef and resultRow.flatCatIcon then
            local sz = entry.isFlat and (entryRowH - 16) or rowIconSize
            if catIconDef.atlas then
                resultRow.flatCatIcon:SetAtlas(catIconDef.atlas)
            else
                resultRow.flatCatIcon:SetTexture(catIconDef.tex)
                if catIconDef.coords then
                    resultRow.flatCatIcon:SetTexCoord(catIconDef.coords[1], catIconDef.coords[2],
                                                      catIconDef.coords[3], catIconDef.coords[4])
                else
                    resultRow.flatCatIcon:SetTexCoord(0, 1, 0, 1)
                end
            end
            resultRow.flatCatIcon:SetDesaturated(catIconDef.desaturate or false)
            resultRow.flatCatIcon:SetVertexColor(1, 1, 1, 1)
            ns.SizeIconAspect(resultRow.flatCatIcon, sz, catIconDef and catIconDef.aspect)
            resultRow.flatCatIcon:ClearAllPoints()
            resultRow.flatCatIcon:SetPoint("LEFT", resultRow, "LEFT", indentPixels, 0)
            resultRow.flatCatIcon:Show()
            leftAnchor = resultRow.flatCatIcon
        end

        resultRow.text:ClearAllPoints()
        if leftAnchor then
            resultRow.text:SetPoint("LEFT", leftAnchor, "RIGHT", 4, 0)
        else
            resultRow.text:SetPoint("LEFT", resultRow, "LEFT", indentPixels, 0)
        end
        resultRow.text:SetPoint("RIGHT", resultRow.amountText, "LEFT", -4, 0)




        Render.SetClippedText(resultRow.text, Render.NameText(entry))
        iconSet = true




    elseif data and data.housingEntryID and data.category == "Housing" and not entry.isPathNode then
        local owned = (data.housingNumStored or 0) + (data.housingNumPlaced or 0)
        if owned > 1 then
            resultRow.amountText:SetText(owned)
            PaintAmountText(resultRow.amountText, false)
            resultRow.amountText:Show()
        else
            resultRow.amountText:SetText("")
            resultRow.amountText:Hide()
        end

        if data.icon then
            resultRow.icon:SetTexture(nil)
            resultRow.icon:SetTexCoord(0, 1, 0, 1)
            resultRow.icon:SetTexture(data.icon)
            resultRow.icon:SetSize(rowIconSize, rowIconSize)
            resultRow.icon:ClearAllPoints()
            resultRow.icon:SetPoint("RIGHT", resultRow, "RIGHT", -5, 0)
            resultRow.icon:Show()
            resultRow.amountText:ClearAllPoints()
            resultRow.amountText:SetPoint("RIGHT", resultRow.icon, "LEFT", -3, 0)
        else
            Icons:SetRowIcon(resultRow, "hidden", nil, rowIconSize)
            resultRow.amountText:ClearAllPoints()
            resultRow.amountText:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
        end

        local indentPixels = depth * indPx
        local leftAnchor
        local catIconDef = Icons:GetFlatCategoryIcon(data)
        if catIconDef and resultRow.flatCatIcon then
            local sz = entry.isFlat and (entryRowH - 16) or rowIconSize
            if catIconDef.atlas then
                resultRow.flatCatIcon:SetAtlas(catIconDef.atlas)
            else
                resultRow.flatCatIcon:SetTexture(catIconDef.tex)
                if catIconDef.coords then
                    resultRow.flatCatIcon:SetTexCoord(catIconDef.coords[1], catIconDef.coords[2],
                                                      catIconDef.coords[3], catIconDef.coords[4])
                else
                    resultRow.flatCatIcon:SetTexCoord(0, 1, 0, 1)
                end
            end
            resultRow.flatCatIcon:SetDesaturated(catIconDef.desaturate or false)
            resultRow.flatCatIcon:SetVertexColor(1, 1, 1, 1)
            ns.SizeIconAspect(resultRow.flatCatIcon, sz, catIconDef and catIconDef.aspect)
            resultRow.flatCatIcon:ClearAllPoints()
            resultRow.flatCatIcon:SetPoint("LEFT", resultRow, "LEFT", indentPixels, 0)
            resultRow.flatCatIcon:Show()
            leftAnchor = resultRow.flatCatIcon
        end
        resultRow.text:ClearAllPoints()
        if leftAnchor then
            resultRow.text:SetPoint("LEFT", leftAnchor, "RIGHT", 4, 0)
        else
            resultRow.text:SetPoint("LEFT", resultRow, "LEFT", indentPixels, 0)
        end
        resultRow.text:SetPoint("RIGHT", resultRow.amountText, "LEFT", -4, 0)
        Render.SetClippedText(resultRow.text, Render.NameText(entry))
        iconSet = true




    elseif data and data.statisticID and not entry.isPathNode then
        local value, hasValue = ns.GetStatisticValue(data.statisticID)
        if hasValue then
            resultRow.amountText:SetText(value)
            PaintAmountText(resultRow.amountText, false)
        else
            resultRow.amountText:SetText("--")
            PaintAmountText(resultRow.amountText, true)
        end
        resultRow.amountText:ClearAllPoints()
        resultRow.amountText:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
        resultRow.amountText:Show()
        Icons:SetRowIcon(resultRow, "hidden", nil, rowIconSize)

        local indentPixels = depth * indPx
        local leftAnchor
        local catIconDef = Icons:GetFlatCategoryIcon({ category = "Statistic" })
        if catIconDef and resultRow.flatCatIcon then
            local sz = entry.isFlat and (entryRowH - 16) or rowIconSize
            resultRow.flatCatIcon:SetTexture(catIconDef.tex)
            if catIconDef.coords then
                resultRow.flatCatIcon:SetTexCoord(catIconDef.coords[1], catIconDef.coords[2],
                                                  catIconDef.coords[3], catIconDef.coords[4])
            else
                resultRow.flatCatIcon:SetTexCoord(0, 1, 0, 1)
            end
            resultRow.flatCatIcon:SetDesaturated(catIconDef.desaturate or false)
            resultRow.flatCatIcon:SetVertexColor(1, 1, 1, 1)
            ns.SizeIconAspect(resultRow.flatCatIcon, sz, catIconDef and catIconDef.aspect)
            resultRow.flatCatIcon:ClearAllPoints()
            resultRow.flatCatIcon:SetPoint("LEFT", resultRow, "LEFT", indentPixels, 0)
            resultRow.flatCatIcon:Show()
            leftAnchor = resultRow.flatCatIcon
        end
        resultRow.text:ClearAllPoints()
        if leftAnchor then
            resultRow.text:SetPoint("LEFT", leftAnchor, "RIGHT", 4, 0)
        else
            resultRow.text:SetPoint("LEFT", resultRow, "LEFT", indentPixels, 0)
        end
        resultRow.text:SetPoint("RIGHT", resultRow.amountText, "LEFT", -4, 0)
        Render.SetClippedText(resultRow.text, Render.NameText(entry))
        iconSet = true

    elseif data and data.calculatorResult and not entry.isPathNode then
        iconSet = Render.CalculatorRow(owner, resultRow, data, state)




    elseif not iconSet and data and (data.specificIcon or data.specificIconFrame) then
        local specificIcon = data.specificIcon or data._resolvedSpecificIcon
        if not specificIcon and data.specificIconFrame then
            specificIcon = GetFrameArtworkIcon(data.specificIconFrame)
            if specificIcon then data._resolvedSpecificIcon = specificIcon end
        end
        if specificIcon then
            Icons:SetRowIcon(resultRow, "file", specificIcon, rowIconSize)
            resultRow.icon:ClearAllPoints()
            resultRow.icon:SetPoint("RIGHT", resultRow, "RIGHT", -5, 0)
            resultRow.icon:SetVertexColor(1, 1, 1, 1)
        else
            Icons:SetRowIcon(resultRow, "hidden", nil, rowIconSize)
        end
        resultRow.amountText:Hide()
        resultRow.text:ClearAllPoints()
        resultRow.text:SetPoint("LEFT", resultRow, "LEFT", depth * indPx + 4, 0)
        if specificIcon then
            resultRow.text:SetPoint("RIGHT", resultRow.icon, "LEFT", -4, 0)
        else
            resultRow.text:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
        end
        Render.SetClippedText(resultRow.text, Render.NameText(entry))
        iconSet = true

    elseif not iconSet and IsMenuBarSpecificIconData(data) then
        local hasSpecificIcon = SetButtonFrameIcon(resultRow, data.buttonFrame, rowIconSize)
        if hasSpecificIcon then
            resultRow.icon:ClearAllPoints()
            resultRow.icon:SetPoint("RIGHT", resultRow, "RIGHT", -5, 0)
            resultRow.icon:SetVertexColor(1, 1, 1, 1)
        else
            Icons:SetRowIcon(resultRow, "hidden", nil, rowIconSize)
        end
        resultRow.amountText:Hide()
        resultRow.text:ClearAllPoints()
        resultRow.text:SetPoint("LEFT", resultRow, "LEFT", depth * indPx + 4, 0)
        if hasSpecificIcon then
            resultRow.text:SetPoint("RIGHT", resultRow.icon, "LEFT", -4, 0)
        else
            resultRow.text:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
        end
        Render.SetClippedText(resultRow.text, Render.NameText(entry))
        iconSet = true




    elseif not iconSet and data and (data.mountID or data.toyItemID or data.petID or data.speciesID or data.outfitID or data.heirloomItemID or data.gearSetID or data.transmogSetID or data.appearanceItemID or (data.spellID and data.category == "Ability") or (data.spellID and data.category == "Talent") or (data.encounterID and data.category == "Boss") or (data.macroIndex and data.category == "Macro") or (data.bagID and data.category == "Bag") or data.storedHolders or (data.clipID and (data.icon or data.clipAtlas or data.clipLetter)) or (data.achievementID and data.category == "Achievement") or data.professionSkillLine) then
        local iconFileID = data.icon
        local rightOffset = -5








        if data.storedHolders and data.itemID
           and C_Item and C_Item.RequestLoadItemDataByID
           and C_Item.IsItemDataCachedByID
           and not C_Item.IsItemDataCachedByID(data.itemID) then
            C_Item.RequestLoadItemDataByID(data.itemID)
        end

        if data.clipLetter and not iconFileID and not data.clipAtlas then



            Icons:SetRowIcon(resultRow, "hidden", nil, rowIconSize)
            local letter = resultRow.iconLetter
            if not letter then
                letter = resultRow:CreateFontString(nil, "OVERLAY")
                letter:SetJustifyH("CENTER")
                letter:SetJustifyV("MIDDLE")
                resultRow.iconLetter = letter
            end
            local fontPath, _, fontFlags = resultRow.text:GetFont()
            if fontPath then letter:SetFont(fontPath, rowIconSize, fontFlags) end
            letter:SetText(data.clipLetter)
            local r, g, b = resultRow.text:GetTextColor()
            letter:SetTextColor(r or 1, g or 1, b or 1, 1)
            letter:SetSize(rowIconSize + 4, rowIconSize + 4)
            letter:ClearAllPoints()
            letter:SetPoint("RIGHT", resultRow, "RIGHT", rightOffset, 0)
            letter:Show()
        elseif iconFileID or data.clipAtlas then
            resultRow.icon:SetTexture(nil)
            resultRow.icon:SetTexCoord(0, 1, 0, 1)
            if data.clipAtlas and not iconFileID then

                resultRow.icon:SetAtlas(data.clipAtlas)
            else
                resultRow.icon:SetTexture(iconFileID)
            end
            if Render.IsBossResultData(data) then
                resultRow.icon:SetTexCoord(unpack(BOSS_PORTRAIT_TEXCOORD))
            end
            resultRow.icon:SetSize(rowIconSize, rowIconSize)
            resultRow.icon:ClearAllPoints()
            resultRow.icon:SetPoint("RIGHT", resultRow, "RIGHT", rightOffset, 0)
            resultRow.icon:Show()






            resultRow.icon:SetDesaturated(false)
            resultRow.icon.mountID = data.mountID
            resultRow.icon.toyItemID = data.toyItemID
            resultRow.icon.petID = data.petID
            resultRow.icon.speciesID = data.speciesID
            resultRow.icon.spellID = data.spellID or data.professionRecipeID
            resultRow.icon.outfitID = data.outfitID
            resultRow.icon.heirloomItemID = data.heirloomItemID
            resultRow.icon.appearanceItemID = data.appearanceItemID
            resultRow.icon.gearSetID = data.gearSetID
            resultRow.icon.bagItemID = (data.category == "Bag" or data.category == "Bank")
                and data.itemID or nil
            resultRow.icon.lootItemID = nil
            resultRow.icon.achievementID = data.achievementID
            resultRow.icon.lootItemID = nil

            if data.mountID and InCombatLockdown() then
                resultRow.icon:SetVertexColor(1, 0.3, 0.3, 1)
            elseif data.outfitID then
                local activeID = select(3, Search:GetOutfitCooldownState())
                activeID = activeID or (C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID
                    and C_TransmogOutfitInfo.GetActiveOutfitID())
                if activeID and activeID == data.outfitID then
                    resultRow.icon:SetVertexColor(0.3, 1, 0.3, 1)
                else
                    resultRow.icon:SetVertexColor(1, 1, 1, 1)
                end




            elseif data.category == "Talent" then
                if data.talentIsAllocated then
                    resultRow.icon:SetVertexColor(1, 1, 1, 1)
                else
                    resultRow.icon:SetVertexColor(0.4, 0.4, 0.4, 1)
                end

            elseif data.iconDimmed then
                resultRow.icon:SetVertexColor(0.4, 0.4, 0.4, 1)
            else
                resultRow.icon:SetVertexColor(1, 1, 1, 1)
            end
        elseif Render.IsBossResultData(data) and data.displayID and SetPortraitTextureFromCreatureDisplayID then


            local face = data.displayID
            if resultRow.icon._efFace ~= face then
                resultRow.icon:SetTexture(nil)
                resultRow.icon:SetTexCoord(0, 1, 0, 1)
                if state.belowView then resultRow._efFacePending = face else DrawFace(resultRow, face) end
            end
            resultRow.icon:SetSize(rowIconSize, rowIconSize)
            resultRow.icon:ClearAllPoints()
            resultRow.icon:SetPoint("RIGHT", resultRow, "RIGHT", rightOffset, 0)
            resultRow.icon:Show()
            resultRow.icon:SetDesaturated(false)
            resultRow.icon:SetVertexColor(1, 1, 1, 1)
        else
            Icons:SetRowIcon(resultRow, "hidden", nil, rowIconSize)
        end


        if data.outfitID and C_TransmogOutfitInfo and C_TransmogOutfitInfo.IsLockedOutfit then
            Search:UpdateOutfitLockOverlay(resultRow, C_TransmogOutfitInfo.IsLockedOutfit(data.outfitID))
        elseif resultRow._lockOverlay then
            Search:UpdateOutfitLockOverlay(resultRow, false)
        end


        if data.gearSetSpecIcon or resultRow._specBadge then
            Search:UpdateGearSetSpecBadge(resultRow, data.gearSetSpecIcon)
        end


        resultRow.amountText:Hide()
        if data.toyItemID and iconFileID and GetItemCooldown then
            local startTime, duration = GetItemCooldown(data.toyItemID)
            if startTime and duration and duration > 0 then
                resultRow.iconCooldown:SetAllPoints(resultRow.icon)
                resultRow.iconCooldown:SetCooldown(startTime, duration)
                resultRow.iconCooldown:Show()
            else
                resultRow.iconCooldown:Hide()
            end
        elseif data.spellID and data.category == "Ability" and iconFileID and C_Spell and C_Spell.GetSpellCooldown then
            local cd = C_Spell.GetSpellCooldown(data.spellID)
            if cd and cd.startTime and cd.duration and cd.duration > 0 then
                resultRow.iconCooldown:SetAllPoints(resultRow.icon)
                resultRow.iconCooldown:SetCooldown(cd.startTime, cd.duration)
                resultRow.iconCooldown:Show()
            else
                resultRow.iconCooldown:Hide()
            end
        elseif data.outfitID and Search:IsOutfitCooldownActive() then
            local outfitCdStart, outfitCdDuration = Search:GetOutfitCooldownState()
            local remaining = outfitCdDuration - (GetTime() - outfitCdStart)
            if remaining > 0 then
                resultRow.iconCooldown:SetAllPoints(resultRow.icon)
                resultRow.iconCooldown:SetCooldown(outfitCdStart, outfitCdDuration)
                resultRow.iconCooldown:Show()
            else
                resultRow.iconCooldown:Hide()
            end
        else
            resultRow.iconCooldown:Hide()
        end

        local indentPixels = depth * indPx + 4
        resultRow.text:ClearAllPoints()
        resultRow.text:SetPoint("LEFT", resultRow, "LEFT", indentPixels, 0)
        resultRow.text:SetPoint("RIGHT", resultRow.icon, "LEFT", -4, 0)



        Render.SetClippedText(resultRow.text, Render.NameText(entry))



        if data.bagID and data.category == "Bag" and (data.bagCount or 1) > 1 then
            resultRow.amountText:SetText("x" .. data.bagCount)
            PaintAmountText(resultRow.amountText, false)
            resultRow.amountText:ClearAllPoints()
            resultRow.amountText:SetPoint("RIGHT", resultRow.icon, "LEFT", -6, 0)
            resultRow.amountText:Show()
            resultRow.text:SetPoint("RIGHT", resultRow.amountText, "LEFT", -4, 0)
            Render.SetClippedText(resultRow.text, Render.NameText(entry))
        end
        iconSet = true




    elseif not iconSet and data and ns.IsApplicationLauncher and ns.IsApplicationLauncher(data) then
        local appGlyph = Icons:GetAppGlyphIcon(data)
        if appGlyph then
            resultRow.icon:SetTexture(nil)
            resultRow.icon:SetTexCoord(0, 1, 0, 1)
            resultRow.icon:SetTexture(appGlyph.tex)
            if appGlyph.coords then resultRow.icon:SetTexCoord(unpack(appGlyph.coords)) end
            ns.PaintAppGlyph(resultRow.icon)
            resultRow.icon:SetSize(rowIconSize, rowIconSize)
            resultRow.icon:ClearAllPoints()
            resultRow.icon:SetPoint("RIGHT", resultRow, "RIGHT", -5, 0)
            resultRow.icon:Show()
            Icons.ClearRowIconLeafIDs(resultRow.icon)
            resultRow.amountText:ClearAllPoints()
            resultRow.amountText:SetPoint("RIGHT", resultRow.icon, "LEFT", -3, 0)
        else
            Icons:SetRowIcon(resultRow, "hidden", nil, rowIconSize)
        end
        iconSet = true




    elseif not iconSet and data and data.catalogItem then
        resultRow.amountText:Hide()
        resultRow.iconCooldown:Hide()
        local id = data.itemID


        local indentPixels = depth * indPx
        local leftAnchor
        local catIconDef = Icons:GetFlatCategoryIcon(data)
        if catIconDef and resultRow.flatCatIcon then
            local sz = entry.isFlat and (entryRowH - 16) or rowIconSize
            if catIconDef.atlas then
                resultRow.flatCatIcon:SetAtlas(catIconDef.atlas)
            else
                resultRow.flatCatIcon:SetTexture(catIconDef.tex)
                if catIconDef.coords then
                    resultRow.flatCatIcon:SetTexCoord(catIconDef.coords[1], catIconDef.coords[2],
                                                      catIconDef.coords[3], catIconDef.coords[4])
                else
                    resultRow.flatCatIcon:SetTexCoord(0, 1, 0, 1)
                end
            end
            resultRow.flatCatIcon:SetDesaturated(catIconDef.desaturate or false)
            resultRow.flatCatIcon:SetVertexColor(1, 1, 1, 1)
            ns.SizeIconAspect(resultRow.flatCatIcon, sz, catIconDef and catIconDef.aspect)
            resultRow.flatCatIcon:ClearAllPoints()
            resultRow.flatCatIcon:SetPoint("LEFT", resultRow, "LEFT", indentPixels, 0)
            resultRow.flatCatIcon:Show()
            leftAnchor = resultRow.flatCatIcon
        end


        local itemIcon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
        if itemIcon then
            resultRow.icon:SetTexture(nil)
            resultRow.icon:SetTexCoord(0, 1, 0, 1)
            resultRow.icon:SetVertexColor(1, 1, 1, 1)
            resultRow.icon:SetTexture(itemIcon)
            resultRow.icon:SetSize(rowIconSize, rowIconSize)
            resultRow.icon:ClearAllPoints()
            resultRow.icon:SetPoint("RIGHT", resultRow, "RIGHT", -5, 0)
            resultRow.icon:Show()
            Icons.ClearRowIconLeafIDs(resultRow.icon)
            resultRow.icon.catalogItemID = id
        else
            Icons:SetRowIcon(resultRow, "hidden", nil, rowIconSize)
        end






        local displayName
        if GetItemInfo then displayName = GetItemInfo(id) end
        if (not displayName or displayName == "") and C_Item and C_Item.GetItemNameByID then
            displayName = C_Item.GetItemNameByID(id)
        end
        if not displayName or displayName == "" then


            if ns.ItemSearch and ns.ItemSearch.NoteUncachedItem then
                ns.ItemSearch:NoteUncachedItem(id)
            end
            displayName = TitleCaseName(data.nameLower or entry.name or "")
        end
        if not displayName or displayName == "" then displayName = "Item #" .. tostring(id) end
        local qc = data.quality and _G["ITEM_QUALITY_COLORS"] and _G["ITEM_QUALITY_COLORS"][data.quality]
        if qc and qc.hex then displayName = qc.hex .. displayName .. "|r" end

        resultRow.text:ClearAllPoints()
        if leftAnchor then
            resultRow.text:SetPoint("LEFT", leftAnchor, "RIGHT", 4, 0)
        else
            resultRow.text:SetPoint("LEFT", resultRow, "LEFT", indentPixels + 4, 0)
        end
        resultRow.text:SetPoint("RIGHT", resultRow.icon, "LEFT", -4, 0)
        Render.SetClippedText(resultRow.text, displayName)
        iconSet = true


    elseif not iconSet and data and data.itemID and data.category == "Loot" then
        local iconFileID = data.icon
        if iconFileID then
            resultRow.icon:SetTexture(nil)
            resultRow.icon:SetTexCoord(0, 1, 0, 1)
            resultRow.icon:SetTexture(iconFileID)
            resultRow.icon:SetSize(rowIconSize, rowIconSize)
            resultRow.icon:ClearAllPoints()
            resultRow.icon:SetPoint("RIGHT", resultRow, "RIGHT", -5, 0)
            resultRow.icon:Show()
            Icons.ClearRowIconLeafIDs(resultRow.icon)
            resultRow.icon.lootItemID = data.itemID
            resultRow.icon:SetVertexColor(1, 1, 1, 1)
        else
            Icons:SetRowIcon(resultRow, "hidden", nil, rowIconSize)
        end
        resultRow.amountText:Hide()
        resultRow.iconCooldown:Hide()
        if data.lootSourceName then
            local name = data.nameHex and (data.nameHex .. data.name .. "|r") or data.name

            if data.upgradeLevel then
                local gain = data.upgradeGain
                    and (" (+" .. data.upgradeGain .. (data.upgradeJudged and "%" or "") .. ")") or ""
                name = name .. "  |cff40c040" .. data.upgradeLevel .. gain .. "|r"
            end
            Render.SetUnclippedText(resultRow.text, name .. "  |cff888888" .. data.lootSourceName .. "|r")
        end
        local indentPixels = depth * indPx + 4
        resultRow.text:ClearAllPoints()
        resultRow.text:SetPoint("LEFT", resultRow, "LEFT", indentPixels, 0)
        resultRow.text:SetPoint("RIGHT", resultRow.icon, "LEFT", -4, 0)
        iconSet = true





    elseif not iconSet and data and data.mapSearchResult then
        resultRow.amountText:Hide()
        local mapIcon = data.icon
        if mapIcon then

            local face = SetPortraitTextureFromCreatureDisplayID and data.displayID or nil
            if not (face and resultRow.icon._efFace == face) then
                resultRow.icon:SetTexture(nil)
                resultRow.icon:SetTexCoord(0, 1, 0, 1)
                if type(mapIcon) == "table" then
                    resultRow.icon:SetTexture(mapIcon.file)
                    resultRow.icon:SetTexCoord(unpack(mapIcon.coords))
                elseif type(mapIcon) == "string" and sfind(mapIcon, "^atlas:") then
                    resultRow.icon:SetAtlas(mapIcon:sub(7))
                else
                    resultRow.icon:SetTexture(mapIcon)
                end
                if face and state.belowView then
                    resultRow._efFacePending = face
                elseif face then
                    DrawFace(resultRow, face)
                end
            end
            resultRow.icon:SetVertexColor(1, 1, 1, 1)
            resultRow.icon:SetSize(rowIconSize, rowIconSize)
            resultRow.icon:ClearAllPoints()
            resultRow.icon:SetPoint("RIGHT", resultRow, "RIGHT", -5, 0)
            resultRow.icon:Show()
        else
            Icons:SetRowIcon(resultRow, "hidden", nil, rowIconSize)
        end
        resultRow.text:ClearAllPoints()
        resultRow.text:SetPoint("LEFT", resultRow, "LEFT", depth * indPx + 4, 0)
        if mapIcon then
            resultRow.text:SetPoint("RIGHT", resultRow.icon, "LEFT", -4, 0)
        else
            resultRow.text:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
        end
        Render.SetClippedText(resultRow.text, Render.NameText(entry))
        iconSet = true



    elseif not iconSet and isReputationLeaf and data and data.factionID then
        local repIcon = Icons:GetRepFactionIcon(data.factionSide or "either")
        if repIcon then
            resultRow.icon:SetTexture(nil)
            resultRow.icon:SetTexture(repIcon.tex)
            if repIcon.coords then
                resultRow.icon:SetTexCoord(unpack(repIcon.coords))
            else
                resultRow.icon:SetTexCoord(0, 1, 0, 1)
            end
            resultRow.icon:SetVertexColor(1, 1, 1, 1)
            resultRow.icon:SetSize(rowIconSize, rowIconSize)
            resultRow.icon:ClearAllPoints()
            local indentPixels = depth * indPx + 4
            resultRow.icon:SetPoint("LEFT", resultRow, "LEFT", indentPixels, 0)
            resultRow.icon:Show()
            resultRow.text:ClearAllPoints()
            resultRow.text:SetPoint("LEFT", resultRow.icon, "RIGHT", 4, 0)
        end
        resultRow.amountText:Hide()
        resultRow.amountText:ClearAllPoints()
        resultRow.amountText:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
        iconSet = true

    else
        resultRow.amountText:Hide()
        resultRow.amountText:ClearAllPoints()
        resultRow.amountText:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
    end

    do
        local repSideBySide
        iconSet, repSideBySide = Render.ReputationBar(resultRow, entry, state, isReputationLeaf, iconSet)
        if repSideBySide then hasRepSideBySide = true end
    end



    if not iconSet and data and data.category == "Game Settings" then
        local cog = ns.SETTING_ICON
        Icons:SetRowIcon(resultRow, cog.atlas and "atlas" or "file", cog.atlas or cog.tex, rowIconSize)
        resultRow.icon:SetDesaturated(cog.desaturate or false)
        iconSet = true
    end

    if not iconSet and data and data.iconAtlas then
        Icons:SetRowIcon(resultRow, "atlas", data.iconAtlas, rowIconSize)
        iconSet = true
    end

    if not iconSet and data and data.icon then
        Icons:SetRowIcon(resultRow, "file", data.icon, rowIconSize)
        iconSet = true
    end





    if iconSet and data and resultRow.icon:IsShown() and resultRow.icon:GetNumPoints() == 0
       and Icons.IsRightSideIconData(data) then
        resultRow.icon:SetPoint("RIGHT", resultRow, "RIGHT", -5, 0)
    end


    if not iconSet and data and data.steps then
        for _, step in ipairs(data.steps) do
            if step.portraitMenu or step.portraitMenuOption then
                SetPortraitTexture(resultRow.icon, "player")
                resultRow.icon:SetTexCoord(0, 1, 0, 1)
                resultRow.icon:SetSize(rowIconSize, rowIconSize)
                resultRow.icon:Show()
                iconSet = true
                break
            end
        end
    end




    if not iconSet and data and data.steps then
        for _, step in ipairs(data.steps) do
            if step.sidebarIndex then

                local slot = ns.Caps and ns.Caps.CharacterSidebarSlot
                    and ns.Caps.CharacterSidebarSlot(step.sidebarIndex) or step.sidebarIndex
                local tab = _G["PaperDollSidebarTab" .. slot]
                if tab then
                    for ri = 1, select("#", tab:GetRegions()) do
                        local region = select(ri, tab:GetRegions())
                        if region and region:GetObjectType() == "Texture"
                           and region:GetDrawLayer() == "ARTWORK" then
                            local tex = region:GetTexture()

                            if tex and type(tex) == "string" and tex:find("^RT") then
                                break
                            end
                            if tex then
                                local ulX, ulY, llX, llY, urX, urY, lrX, lrY = region:GetTexCoord()
                                resultRow.icon:SetTexture(tex)
                                resultRow.icon:SetTexCoord(ulX, ulY, llX, llY, urX, urY, lrX, lrY)
                                resultRow.icon:SetSize(rowIconSize, rowIconSize)
                                resultRow.icon:Show()
                                iconSet = true
                            end
                            break
                        end
                    end

                    if not iconSet then
                        SetPortraitTexture(resultRow.icon, "player")
                        resultRow.icon:SetTexCoord(0, 1, 0, 1)
                        resultRow.icon:SetSize(rowIconSize, rowIconSize)
                        resultRow.icon:Show()
                        iconSet = true
                    end
                end
                break
            end
        end
    end



    if not iconSet and not isCurrencyItem and data and data.buttonFrame then
        local texture, isAtlas = GetButtonIcon(data.buttonFrame)
        if texture then
            local kind = isAtlas and "atlas" or "file"
            Icons:SetRowIcon(resultRow, kind, texture, rowIconSize)
            iconSet = true
        end
    end






    if not iconSet and data and data.buttonFrame == "CharacterMicroButton"
       and SetPortraitTexture then
        SetPortraitTexture(resultRow.icon, "player")
        resultRow.icon:SetTexCoord(0, 1, 0, 1)
        resultRow.icon:SetSize(rowIconSize, rowIconSize)
        resultRow.icon:Show()
        iconSet = true
    end

    if not iconSet then
        Icons:SetRowIcon(resultRow, "file", 134400, rowIconSize)
    end

    Render.SettingsWidget(resultRow, data, entry)
    return hasRepSideBySide
end
