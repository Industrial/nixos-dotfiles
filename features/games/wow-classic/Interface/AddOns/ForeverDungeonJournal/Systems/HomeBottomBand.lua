-- Some loading-screen art (City of Dalaran) ends in a dark strip at the bottom
-- of its home card. Cover it with a band tinted like the art, fading upward
-- into the picture so it doesn't look like a hard bar.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local WHITE = "Interface\\Buttons\\WHITE8X8"

local function SetFade(tex, r, g, b)
    -- Solid at the bottom, transparent at the top. Newer clients use
    -- SetGradient with colour objects, older ones SetGradientAlpha.
    if CreateColor and pcall(tex.SetGradient, tex, "VERTICAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, 0)) then
        return
    end
    if tex.SetGradientAlpha and pcall(tex.SetGradientAlpha, tex, "VERTICAL", r, g, b, 1, r, g, b, 0) then
        return
    end
    tex:SetVertexColor(r, g, b, 0.5)
end

function FDJ.ApplyHomeBottomBand(card, dungeonName)
    local spec = FDJ.DUNGEON_HOME_BOTTOM_BAND and FDJ.DUNGEON_HOME_BOTTOM_BAND[dungeonName]
    if not spec then
        if card.fdjBand then card.fdjBand:Hide(); card.fdjBandFade:Hide() end
        return
    end
    local r, g, b, h = spec[1], spec[2], spec[3], spec[4] or 12
    if not card.fdjBand then
        card.fdjBand = card:CreateTexture(nil, "ARTWORK", nil, 2)
        card.fdjBand:SetTexture(WHITE)
        card.fdjBandFade = card:CreateTexture(nil, "ARTWORK", nil, 2)
        card.fdjBandFade:SetTexture(WHITE)
    end
    local band, fade = card.fdjBand, card.fdjBandFade
    band:ClearAllPoints()
    band:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 4, 4)
    band:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -4, 4)
    band:SetHeight(h)
    band:SetVertexColor(r, g, b, 1)
    fade:ClearAllPoints()
    fade:SetPoint("BOTTOMLEFT", band, "TOPLEFT", 0, 0)
    fade:SetPoint("BOTTOMRIGHT", band, "TOPRIGHT", 0, 0)
    fade:SetHeight(3)
    fade:SetVertexColor(1, 1, 1, 1)
    SetFade(fade, r, g, b)
    band:Show()
    fade:Show()
end
