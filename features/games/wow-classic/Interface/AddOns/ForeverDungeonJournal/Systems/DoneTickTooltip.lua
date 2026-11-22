-- Hovering the green tick on a home dungeon card shows "All quests completed"
-- (or, on a dungeon with no quest for the character, "Last boss killed").
-- The tick is a texture on the card button, so instead of putting a mouse
-- frame over it (which would steal the card's hover and click), the card
-- checks while hovered whether the mouse is over the tick.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local TEXT = {
    enUS = "All quests completed", deDE = "Alle Quests abgeschlossen",
    frFR = "Toutes les quêtes terminées", esES = "Todas las misiones completadas",
    itIT = "Tutte le missioni completate", ptBR = "Todas as missões concluídas",
    ruRU = "Все задания выполнены", koKR = "모든 퀘스트 완료",
    zhCN = "所有任务已完成", zhTW = "所有任務已完成",
}

-- bossdone (2.0.8): the tick of a dungeon with no quest for the character.
local BOSS_TEXT = {
    enUS = "Last boss killed", deDE = "Letzter Boss besiegt",
    frFR = "Dernier boss vaincu", esES = "Último jefe derrotado", esMX = "Último jefe derrotado",
    itIT = "Ultimo boss sconfitto", ptBR = "Último chefe derrotado",
    ruRU = "Последний босс побеждён", koKR = "마지막 우두머리 처치",
    zhCN = "最终首领已击败", zhTW = "最終首領已擊敗",
}

local function Text(card)
    local lang = FDJ.GetLanguage and FDJ.GetLanguage() or "enUS"
    if card and card.fdjTickBoss then return BOSS_TEXT[lang] or BOSS_TEXT.enUS end
    return TEXT[lang] or TEXT.enUS
end

local function OverTick(card)
    local ring = card.doneRing
    if not ring or not ring:IsShown() then return false end
    local ok, over = pcall(ring.IsMouseOver, ring, 2, -2, -2, 2)
    return ok and over
end

local function Update(card)
    if not GameTooltip then return end
    local over = OverTick(card)
    if over and not card.fdjTickTipShown then
        -- Hide Dungeons mode already owns the tooltip for this card; leave it.
        if GameTooltip:IsShown() and GameTooltip:GetOwner() == card then return end
        card.fdjTickTipShown = true
        GameTooltip:SetOwner(card, "ANCHOR_TOP")
        GameTooltip:SetText(Text(card), 0.2, 1, 0.2)
        GameTooltip:Show()
    elseif not over and card.fdjTickTipShown then
        card.fdjTickTipShown = nil
        if GameTooltip:GetOwner() == card then GameTooltip:Hide() end
    end
end

function FDJ.AttachDoneTickTooltip(card)
    if not card or card.fdjTickTipHooked or not card.HookScript then return end
    card.fdjTickTipHooked = true
    card:HookScript("OnUpdate", function(self)
        if self.fdjTickTipShown or (self.IsMouseOver and self:IsMouseOver()) then pcall(Update, self) end
    end)
    card:HookScript("OnLeave", function(self)
        if self.fdjTickTipShown then
            self.fdjTickTipShown = nil
            if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
        end
    end)
end
