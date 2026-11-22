local _, ns = ...

local Search = ns.Search
local Tooltips = ns.ResultTooltips
local L = ns.L
local sformat, mfloor = string.format, math.floor

local CreateFrame = CreateFrame
local BattlePetTooltip = BattlePetTooltip
local GameTooltip = GameTooltip
local UIParent = UIParent
local IsModifiedClick = IsModifiedClick
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local unearnedTooltip




local function ApplySearchTooltipScale(tooltip)
    if not tooltip._efScaleHooked then
        tooltip._efScaleHooked = true
        tooltip:HookScript("OnHide", function(self)
            if self._efBaseScale then
                self:SetScale(self._efBaseScale)
                self._efBaseScale = nil
            end
        end)
    end




    local s = (EasyFind.db and EasyFind.db.uiSearchScale) or 1.0
    if not tooltip._efBaseScale then
        tooltip._efBaseScale = tooltip:GetScale() or 1.0
    end
    tooltip:SetScale(tooltip._efBaseScale * s)
end
Tooltips.ApplySearchTooltipScale = ApplySearchTooltipScale






local EDGE_GAP = 8
local EDGE_FIT_MIN_SCALE = 0.55



function Tooltips:PlaceAtPanelEdge(frame, fallbackOwner)
    frame:ClearAllPoints()
    frame._efEdgePanel = nil

    local panel = (Search:GetResultsFrame() and Search:GetResultsFrame():IsShown()) and Search:GetResultsFrame()
                  or (Search:GetSearchFrame() and Search:GetSearchFrame():IsShown()) and Search:GetSearchFrame()
                  or fallbackOwner

    local left = panel and panel:GetLeft()
    local right = panel and panel:GetRight()
    local top = panel and panel:GetTop()
    local screenW = UIParent:GetWidth() or 0

    if left and right and top and screenW > 0 then





        local uiScale = UIParent:GetEffectiveScale() or 1
        local ratio = uiScale > 0 and (panel:GetEffectiveScale() / uiScale) or 1
        local roomRight = screenW - right * ratio
        local roomLeft = left * ratio
        if roomRight >= roomLeft then
            frame:SetPoint("TOPLEFT", panel, "TOPRIGHT", EDGE_GAP, 0)
            frame._efEdgeSide = "right"
        else
            frame:SetPoint("TOPRIGHT", panel, "TOPLEFT", -EDGE_GAP, 0)
            frame._efEdgeSide = "left"
        end
        frame._efEdgePanel = panel
        return true
    end
    return false
end

local function EdgeRoomFor(tooltip)
    local panel = tooltip._efEdgePanel
    if not panel then return end


    local uiScale = UIParent:GetEffectiveScale() or 1
    local ratio = uiScale > 0 and (panel:GetEffectiveScale() / uiScale) or 1
    if tooltip._efEdgeSide == "right" then
        local right = panel:GetRight()
        if not right then return end
        return (UIParent:GetWidth() or 0) - right * ratio - EDGE_GAP
    end
    local left = panel:GetLeft()
    if not left then return end
    return left * ratio - EDGE_GAP
end






local function AnchorOneCompareOutward(compare, tooltip, side, scale, xOffset)
    if not (compare and compare:IsShown()) then return xOffset end
    if compare._efBaseScale == nil then
        compare._efBaseScale = compare:GetScale() or 1.0
    end
    compare:SetScale(scale)
    compare:ClearAllPoints()




    if side == "right" then
        compare:SetPoint("TOPLEFT", tooltip, "TOPRIGHT", 4 + xOffset, 0)
    else
        compare:SetPoint("TOPRIGHT", tooltip, "TOPLEFT", -(4 + xOffset), 0)
    end
    return xOffset + (compare:GetWidth() or 0) + 4
end

local function AnchorComparesOutward(tooltip)
    local side = tooltip._efEdgePanel and tooltip._efEdgeSide
    if not side then return end
    local scale = tooltip:GetScale() or 1.0
    local xOffset = AnchorOneCompareOutward(_G["ShoppingTooltip1"], tooltip, side, scale, 0)
    AnchorOneCompareOutward(_G["ShoppingTooltip2"], tooltip, side, scale, xOffset)
end








local function FitEdgeTooltip(tooltip)
    local base = tooltip._efEdgeBaseScale
    local room = base and EdgeRoomFor(tooltip)
    if not room or room <= 0 then return end
    local uiScale = UIParent:GetEffectiveScale()
    if not uiScale or uiScale == 0 then return end
    local total = (tooltip:GetWidth() or 0) * (tooltip:GetEffectiveScale() or 1)
    local compare1, compare2 = _G["ShoppingTooltip1"], _G["ShoppingTooltip2"]
    if compare1 and compare1:IsShown() then
        total = total + (compare1:GetWidth() or 0) * (compare1:GetEffectiveScale() or 1)
    end
    if compare2 and compare2:IsShown() then
        total = total + (compare2:GetWidth() or 0) * (compare2:GetEffectiveScale() or 1)
    end
    total = total / uiScale
    if total <= 0 then return end
    local fit = room / total
    if fit >= 1 then return end
    local target = base * fit
    if target < base * EDGE_FIT_MIN_SCALE then target = base * EDGE_FIT_MIN_SCALE end
    local current = tooltip:GetScale() or base
    if target < current - 0.01 then
        tooltip:SetScale(target)
        AnchorComparesOutward(tooltip)
    end
end







local comparesReanchoring = false
local function ReassertCompareAnchors()
    if comparesReanchoring then return end
    local tooltip = GameTooltip
    if not (tooltip and tooltip._efEdgePanel and tooltip._efEdgeBaseScale) then return end
    comparesReanchoring = true
    AnchorComparesOutward(tooltip)
    FitEdgeTooltip(tooltip)
    comparesReanchoring = false
end

local compareGuardsInstalled = false
local function InstallCompareGuards()
    if compareGuardsInstalled then return end
    compareGuardsInstalled = true
    local manager = _G["TooltipComparisonManager"]
    if manager and type(manager.AnchorShoppingTooltips) == "function" then
        hooksecurefunc(manager, "AnchorShoppingTooltips", ReassertCompareAnchors)
    end
    local compare1, compare2 = _G["ShoppingTooltip1"], _G["ShoppingTooltip2"]
    if compare1 then hooksecurefunc(compare1, "SetPoint", ReassertCompareAnchors) end
    if compare2 then hooksecurefunc(compare2, "SetPoint", ReassertCompareAnchors) end
end

local function HookCompareTooltip(compare, tooltip)
    if not compare or compare._efEdgeHooked then return end
    compare._efEdgeHooked = true






    compare:HookScript("OnShow", function(self)
        if not tooltip._efEdgeBaseScale then return end
        if not IsModifiedClick("COMPAREITEMS") then
            tooltip._efCompareHeld = tooltip._efCompareHeld or {}
            tooltip._efCompareHeld[self] = true
            self:Hide()
            return
        end
        ReassertCompareAnchors()
    end)
    compare:HookScript("OnHide", function(self)
        if self._efBaseScale then
            self:SetScale(self._efBaseScale)
            self._efBaseScale = nil
        end
    end)
end

function Tooltips:AnchorRowTooltip(tooltip, ownerFrame)







    tooltip:SetOwner(ownerFrame, "ANCHOR_PRESERVE")
    ApplySearchTooltipScale(tooltip)
    if not self:PlaceAtPanelEdge(tooltip, ownerFrame) then

        tooltip:SetOwner(ownerFrame, "ANCHOR_RIGHT")
        return
    end



    if not tooltip._efBaseScale then
        tooltip._efBaseScale = tooltip:GetScale() or 1.0
    end
    tooltip._efEdgeBaseScale = tooltip:GetScale()
    if not tooltip._efEdgeFitHooked then
        tooltip._efEdgeFitHooked = true
        tooltip:HookScript("OnSizeChanged", FitEdgeTooltip)
        tooltip:HookScript("OnShow", FitEdgeTooltip)
        tooltip:HookScript("OnHide", function(self)
            self._efEdgePanel = nil
            self._efEdgeBaseScale = nil
            self._efCompareHeld = nil
        end)



        tooltip:HookScript("OnUpdate", function(self)
            local held = self._efCompareHeld
            if not (held and self._efEdgePanel) then return end
            local want = IsModifiedClick("COMPAREITEMS")
            for compare in pairs(held) do
                if want ~= compare:IsShown() then compare:SetShown(want) end
            end
        end)
        HookCompareTooltip(_G["ShoppingTooltip1"], tooltip)
        HookCompareTooltip(_G["ShoppingTooltip2"], tooltip)
        InstallCompareGuards()
    end
    FitEdgeTooltip(tooltip)
end

function Tooltips:GetUnearnedTooltip()
    return unearnedTooltip
end

function Tooltips:CreateUnearnedTooltip()
    unearnedTooltip = CreateFrame("Frame", "EasyFindUnearnedTooltip", UIParent)
    unearnedTooltip:SetFrameStrata("TOOLTIP")
    unearnedTooltip:SetFrameLevel(9999)
    unearnedTooltip:SetClampedToScreen(true)


    ns.StyleMenuPanel(unearnedTooltip)

    local text = unearnedTooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER", 0, 0)
    text:SetText(L["CURRENCY_NOT_EARNED"])

    text._efOwnColor = true
    unearnedTooltip.text = text


    unearnedTooltip._efOnThemeRestyle = function(self)
        local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()

        local r, g, b = ns.TooltipTextColor()
        self.text:SetTextColor(r, g, b, 1)
        self.text:SetShadowColor(0, 0, 0, (theme and theme.lightTheme) and 0 or 1)
    end
    unearnedTooltip:HookScript("OnShow", unearnedTooltip._efOnThemeRestyle)
    unearnedTooltip._efOnThemeRestyle(unearnedTooltip)

    local textWidth = text:GetStringWidth()
    local textHeight = text:GetStringHeight()
    unearnedTooltip:SetSize(textWidth + 20, textHeight + 16)

    unearnedTooltip:Hide()
end

function Tooltips:ClearResultTooltips()
    if unearnedTooltip then unearnedTooltip:Hide() end
    if BattlePetTooltip then BattlePetTooltip:Hide() end
    if GameTooltip then
        local resultButtons = Search:GetResultButtons()
        for i = 1, #resultButtons do
            local row = resultButtons[i]
            if row then
                if row.toyTooltipTicker then
                    row.toyTooltipTicker:Cancel()
                    row.toyTooltipTicker = nil
                end
                if GameTooltip:IsOwned(row) then
                    GameTooltip:Hide()
                end
            end
        end
    end
    if ns.MapSearch and ns.MapSearch.ClearUIPreview then
        ns.MapSearch:ClearUIPreview()
    end
end



local CLIP_TIP_MAX = 600
function Tooltips.ClipTooltipText(text)
    if type(text) ~= "string" then return "" end
    local out = ns.Utils.ClipboardSafeText(text) or text
    if #out > CLIP_TIP_MAX then
        local cut = CLIP_TIP_MAX
        while cut > 0 do
            local b = out:byte(cut + 1)
            if not b or b < 0x80 or b > 0xBF then break end
            cut = cut - 1
        end
        out = out:sub(1, cut) .. "..."
    end
    return out
end











function Tooltips:SetClassicTalent(tooltip, data)
    if not (data and data.talentTab and data.talentID and tooltip.SetTalent) then return false end
    if data.talentTier then
        tooltip:SetTalent(data.talentID, false, data.talentGroup)
    else
        tooltip:SetTalent(data.talentID, false, false, data.talentGroup)
    end
    return true
end





function Tooltips:SetMapRowTooltip(tooltip, data)
    tooltip:SetText(data.name or "", 1, 1, 1)
    local x, y = data.x, data.y
    if x and y then
        local spot = sformat("%.1f, %.1f", x * 100, y * 100)
        tooltip:AddLine(data.zoneName and sformat(L["TT_PLACE_AT_FMT"], data.zoneName, spot) or spot, 1, 0.82, 0)
    end
    if data.teachesText and data.teachesText ~= "" then
        tooltip:AddLine(sformat(L["TT_TEACHES_FMT"], data.teachesText), 1, 1, 1, true)
    end
    local near = data.mapNear
    if near and near < math.huge then
        local yd = mfloor(near ^ 0.5 + 0.5)
        local far = ns.GPS and ns.GPS.DistanceText and ns.GPS.DistanceText(yd) or sformat(L["GPS_UNIT_YD"], yd)
        tooltip:AddLine(sformat(L["TT_PLACE_AWAY_FMT"], far), 0.8, 0.8, 0.8)
    end
    if data.spotCount and data.spotCount > 1 then
        tooltip:AddLine(sformat(L["TT_PLACE_SPOTS_FMT"], data.spotCount), 0.8, 0.8, 0.8)
    end
    local wares = ns.ItemSources and ns.ItemSources.WareCount(data)
    if wares then tooltip:AddLine(sformat(L["TT_VENDOR_SELLS_FMT"], wares), 1, 0.82, 0) end
    return true
end



function Tooltips:SetBossTooltip(tooltip, data)
    local caps = ns.Caps
    if data.encounterID and caps and caps.journal and not caps.instanceTable then
        tooltip:SetHyperlink(sformat("journal:1:%d:%d", data.encounterID, data.difficultyID or 14))
        return true
    end
    tooltip:SetText(data.name or "", 1, 1, 1)
    if data.lootCount and data.lootCount > 0 then
        tooltip:AddLine(sformat(L["TT_BOSS_DROPS_FMT"], data.lootCount), 1, 0.82, 0)
    end
    return true
end

function Tooltips:SetGameTooltipForResult(tooltip, data)
    if not (tooltip and data) then return false end
    if data.category == "Boss" then return self:SetBossTooltip(tooltip, data) end
    if data.mapSearchResult then return self:SetMapRowTooltip(tooltip, data) end

    local provider = ns.Extensions and ns.Extensions.ProviderOf and ns.Extensions.ProviderOf(data)
    if provider and provider.tooltip then
        local ok, filled = ns.Extensions.Run(provider.tooltip, data, tooltip)
        return ok and filled == true
    end
    if data.mountID and data.spellID and tooltip.SetMountBySpellID then
        tooltip:SetMountBySpellID(data.spellID)
        return true
    end
    if data.toyItemID and tooltip.SetToyByItemID then
        tooltip:SetToyByItemID(data.toyItemID)
        return true
    end
    if data.petID then
        if tooltip.SetCompanionPet then
            tooltip:SetCompanionPet(data.petID)
            return true
        end
        local link = C_PetJournal and C_PetJournal.GetBattlePetLink
            and C_PetJournal.GetBattlePetLink(data.petID)
        if link then
            tooltip:SetHyperlink(link)
            return true
        end
        return false
    end
    if data.itemID then
        local isItemRow = data.catalogItem or data.category == "Bag" or data.category == "Bank"
            or data.category == "Warband" or data.category == "Loot"
            or (data.storedHolders and #data.storedHolders > 0)
        if isItemRow then
            local link = data.bagItemLink
            if not link and data.category == "Loot" and ns.Database and ns.Database.GetLootItemLink then
                link = ns.Database:GetLootItemLink(data)
            end
            if link then
                tooltip:SetHyperlink(link)
            else
                tooltip:SetItemByID(data.itemID)
            end
            return true
        end
    end
    if data.heirloomItemID then
        tooltip:SetItemByID(data.heirloomItemID)
        return true
    end
    if data.appearanceItemID then
        local srcInfo = C_TransmogCollection and C_TransmogCollection.GetSourceInfo
            and C_TransmogCollection.GetSourceInfo(data.appearanceItemID)
        if srcInfo and srcInfo.itemID then
            tooltip:SetItemByID(srcInfo.itemID)
            return true
        end
        return false
    end
    if data.macroIndex and data.category == "Macro" then
        local spellID
        if GetMacroSpell then
            local _, _, sid = GetMacroSpell(data.macroIndex)
            spellID = sid
        end
        if spellID and tooltip.SetSpellByID then
            tooltip:SetSpellByID(spellID)
            return true
        end
        local itemName, itemLink
        if GetMacroItem then itemName, itemLink = GetMacroItem(data.macroIndex) end
        if not itemLink and itemName and GetItemInfo then
            itemLink = select(2, GetItemInfo(itemName))
        end
        if itemLink then
            tooltip:SetHyperlink(itemLink)
            return true
        end
        return false
    end
    if Tooltips:SetClassicTalent(tooltip, data) then return true end
    local spellID = data.spellID or data.professionRecipeID
    if spellID then
        if tooltip.SetSpellByID then
            tooltip:SetSpellByID(spellID)
        else
            tooltip:SetHyperlink("spell:" .. spellID)
        end
        return true
    end
    if data.category == "Currency" and data.currencyID and tooltip.SetCurrencyByID then
        tooltip:SetCurrencyByID(data.currencyID)
        return true
    end
    local achID = data.achievementID
    if not achID and data.titleID and ns.Database and ns.Database.GetTitleSourceAchievement then
        achID = ns.Database:GetTitleSourceAchievement(data.titleID)
    end
    if achID and tooltip.SetAchievementByID then
        tooltip:SetAchievementByID(achID)
        return true
    end
    return false
end
