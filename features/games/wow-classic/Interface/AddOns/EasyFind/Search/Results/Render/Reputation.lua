local _, ns = ...

local Utils = ns.Utils
local Render = ns.ResultRender
local Icons = ns.ResultIcons

local mmax, mmin = Utils.mmax, Utils.mmin
local REP_BAR_WIDTH = Render.REP_BAR_WIDTH

function Render.GetReputationBarInfo(factionID)
    local fill, standingText, barR, barG, barB

    if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
        local ok, md = pcall(C_MajorFactions.GetMajorFactionData, factionID)
        if ok and md and md.renownLevel then
            standingText = (_G["LANDING_PAGE_RENOWN_LABEL"] or _G["COVENANT_SANCTUM_TAB_RENOWN"] or "Renown") .. " " .. (md.renownLevel or 0)
            local atMax = C_MajorFactions.HasMaximumRenown
                and C_MajorFactions.HasMaximumRenown(factionID)
            if atMax then
                fill = 1.0
            else
                local earned = md.renownReputationEarned or 0
                local threshold = md.renownLevelThreshold or 1
                fill = (threshold > 0) and (earned / threshold) or 1.0
            end
            barR, barG, barB = 0.0, 0.55, 0.78
        end
    end

    if not standingText and C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
        local ok, fd = pcall(C_GossipInfo.GetFriendshipReputation, factionID)
        if ok and fd and fd.friendshipFactionID and fd.friendshipFactionID > 0 then
            standingText = fd.reaction or ""
            local cur = fd.standing or 0
            local minR = fd.reactionThreshold or 0
            local maxR = fd.nextThreshold or 0
            if maxR > minR then
                fill = (cur - minR) / (maxR - minR)
            elseif cur > 0 then
                fill = 1.0
            else
                fill = 0.0
            end
            barR, barG, barB = 0.0, 0.60, 0.0
        end
    end

    if not standingText and ns.Caps and ns.Caps.FactionByID then
        local ok, rd = pcall(ns.Caps.FactionByID, factionID)
        if ok and rd and rd.reaction then
            local standing = rd.reaction
            standingText = _G["FACTION_STANDING_LABEL" .. standing] or ""
            local cur  = rd.currentStanding or 0
            local minR = rd.currentReactionThreshold or 0
            local maxR = rd.nextReactionThreshold or 0
            if maxR > minR then
                fill = (cur - minR) / (maxR - minR)
            else
                fill = 1.0
            end
            local barColor = FACTION_BAR_COLORS and FACTION_BAR_COLORS[standing]
            if barColor then
                barR, barG, barB = barColor.r, barColor.g, barColor.b
            else
                barR, barG, barB = 0.5, 0.5, 0.5
            end
        end
    end

    if fill and fill < 0 then fill = 0 end
    if fill and fill > 1 then fill = 1 end
    return fill, standingText, barR, barG, barB
end



function Render.GetRankBarInfo(data)
    local rank, maxRank = data.skillRank, data.skillMaxRank
    if rank and not (maxRank and maxRank > 1) then return nil end
    if not rank then rank, maxRank = data.talentRank, data.talentMaxRank end
    if not (rank and maxRank and maxRank > 0) then return nil end
    local text = rank .. "/" .. maxRank
    local modifier = data.skillModifier
    if modifier and modifier ~= 0 then
        local color = modifier > 0 and ((_G["GREEN_FONT_COLOR_CODE"] or "|cff20ff20") .. "+")
            or (_G["RED_FONT_COLOR_CODE"] or "|cffff2020")
        text = rank .. " (" .. color .. modifier .. "|r)/" .. maxRank
    end
    return mmin(mmax(rank / maxRank, 0), 1), text, 0.0, 0.0, 0.78
end

function Render.ReputationBar(resultRow, entry, state, isReputationLeaf, iconSet)
    local data = entry.data
    local showRepBar = data and data.factionID
        and (isReputationLeaf or (entry.isPathNode and data.category == "Reputation" and data.hasRepBar ~= false))
    local fill, standingText, barR, barG, barB

    local keepIcon = false
    if showRepBar then
        fill, standingText, barR, barG, barB = Render.GetReputationBarInfo(data.factionID)
        if not standingText then
            resultRow.repBar:Hide()
            return (not entry.isPathNode) or iconSet, false
        end
    elseif data and not entry.isPathNode then
        fill, standingText, barR, barG, barB = Render.GetRankBarInfo(data)
        keepIcon = data.talentTab ~= nil
    end
    if not standingText then
        resultRow.repBar:Hide()
        return iconSet, false
    end

    resultRow.repBarTex:SetVertexColor(barR, barG, barB, 1.0)
    if resultRow.repFill.SetBackdropColor then
        resultRow.repFill:SetBackdropColor(barR, barG, barB, 1.0)
    end
    resultRow.repClip:SetWidth(mmax(fill * REP_BAR_WIDTH, 0.1))
    resultRow.repBarText:SetText(standingText)

    local hasSideBySideRepBar = false
    local depth = entry.depth or 0
    if entry.isPathNode and state.theme.showHeaderTab then
        resultRow.repBar:ClearAllPoints()
        resultRow.repBar:SetPoint("RIGHT", resultRow.toggleBtn, "LEFT", -4, 0)
        resultRow.tabText:ClearAllPoints()
        resultRow.tabText:SetPoint("LEFT", resultRow.headerTab, "LEFT", 10, 0)
        resultRow.tabText:SetPoint("RIGHT", resultRow.repBar, "LEFT", -4, 0)
    elseif entry.isPathNode then
        local indentPixels = depth * state.indPx + 4
        resultRow.repBar:ClearAllPoints()
        resultRow.repBar:SetPoint("RIGHT", resultRow, "RIGHT", -6, 0)
        resultRow.text:ClearAllPoints()
        resultRow.text:SetPoint("LEFT", resultRow.icon, "RIGHT", 4, 0)
        resultRow.text:SetPoint("RIGHT", resultRow.repBar, "LEFT", -4, 0)
        if resultRow.text:IsTruncated() then
            resultRow.text:ClearAllPoints()
            resultRow.text:SetPoint("TOPLEFT", resultRow, "TOPLEFT", indentPixels, -3)
            resultRow.text:SetPoint("TOPRIGHT", resultRow, "TOPRIGHT", -6, -3)
            resultRow.repBar:ClearAllPoints()
            resultRow.repBar:SetPoint("BOTTOM", resultRow, "BOTTOM", 0, 5)
            resultRow:SetHeight(state.rowH + 25)
        else
            hasSideBySideRepBar = true
        end
    else
        if not keepIcon then Icons:SetRowIcon(resultRow, "hidden", nil, state.rowIconSize) end
        local indentPixels = depth * state.indPx + 4
        resultRow.repBar:ClearAllPoints()
        resultRow.repBar:SetPoint("RIGHT", resultRow, "RIGHT", -6, 0)
        resultRow.text:ClearAllPoints()
        if keepIcon then
            resultRow.text:SetPoint("LEFT", resultRow.icon, "RIGHT", 4, 0)
        else
            resultRow.text:SetPoint("LEFT", resultRow, "LEFT", indentPixels, 0)
        end
        resultRow.text:SetPoint("RIGHT", resultRow.repBar, "LEFT", -4, 0)
        if resultRow.text:IsTruncated() then
            resultRow.text:ClearAllPoints()
            if keepIcon then
                resultRow.text:SetPoint("TOPLEFT", resultRow.icon, "TOPRIGHT", 4, 0)
            else
                resultRow.text:SetPoint("TOPLEFT", resultRow, "TOPLEFT", indentPixels, -3)
            end
            resultRow.text:SetPoint("TOPRIGHT", resultRow, "TOPRIGHT", -6, -3)
            resultRow.repBar:ClearAllPoints()
            resultRow.repBar:SetPoint("BOTTOM", resultRow, "BOTTOM", 0, 5)
            resultRow:SetHeight(state.rowH + 25)
        else
            hasSideBySideRepBar = true
        end
        iconSet = true
    end

    resultRow.repBar:Show()
    if not entry.isPathNode then iconSet = true end
    return iconSet, hasSideBySideRepBar
end
