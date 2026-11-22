-- Older dungeon maps use artwork from the game client. Some localized clients
-- (for example ruRU) do not have it; the journal then shows its own copy of
-- the map. A map without a copy shows a plain parchment with the boss pins,
-- and this note explains why.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

-- Note under the dungeon map when this game client has no artwork for it
-- (some localized clients lack the old dungeon maps). Pins still work.
local MISSING = {
    enUS = "Your game client has no artwork for this map. Boss pins and the entrance are still shown.",
    deDE = "Dein Spielclient hat keine Grafik für diese Karte. Bosse und Eingang werden trotzdem angezeigt.",
    frFR = "Votre client de jeu n'a pas l'illustration de cette carte. Les boss et l'entrée restent affichés.",
    esES = "Tu cliente del juego no tiene la imagen de este mapa. Los jefes y la entrada se siguen mostrando.",
    itIT = "Il tuo client di gioco non ha l'immagine di questa mappa. Boss e ingresso restano visibili.",
    ptBR = "Seu cliente do jogo não tem a imagem deste mapa. Os chefes e a entrada continuam visíveis.",
    ruRU = "В вашем клиенте игры нет изображения этой карты. Боссы и вход всё равно отмечены.",
    koKR = "게임 클라이언트에 이 지도의 그림이 없습니다. 우두머리와 입구는 계속 표시됩니다.",
    zhCN = "你的游戏客户端缺少这张地图的图片。首领和入口仍会显示。",
    zhTW = "你的遊戲用戶端缺少這張地圖的圖片。首領和入口仍會顯示。",
}

-- BEGIN mapcopies
-- The journal's own copies of the old dungeon maps (Media\Maps\<Name><floor>,
-- the journal's parchment patches already on them), for game clients without
-- the game's map files.
local COPIES = {}
for name in ([[
    BlackFathomDeeps1 BlackFathomDeeps2 BlackFathomDeeps3 BlackrockDepths1
    BlackrockDepths2 DireMaul1 DireMaul2 DireMaul3 DireMaul4 DireMaul5
    DireMaul6 Gnomeregan1 Gnomeregan2 Gnomeregan3 Gnomeregan4 Maraudon1
    Maraudon2 Ragefire1 RazorfenDowns1 RazorfenKraul1 ScarletMonastery1
    ScarletMonastery2 ScarletMonastery3 ScarletMonastery4 ShadowfangKeep1
    ShadowfangKeep6 ShadowfangKeep7 Stratholme1 Stratholme2 TheDeadmines1
    TheDeadmines2 TheStockade1 Uldaman1 Uldaman2
    WailingCaverns1
]]):gmatch("%S+") do COPIES[name] = true end

function FDJ.MapArtCopy(floor)
    local tiles = type(floor) == "table" and floor.tiles
    local name = type(tiles) == "string" and tiles:match("([^\\]+)_$")
    if name and COPIES[name] then
        return "Interface\\AddOns\\ForeverDungeonJournal\\Media\\Maps\\" .. name
    end
    return nil
end
-- END mapcopies

function FDJ.CheckMapTiles(panel, tiles, count, floor, apiTextures, apiLayer, artMissing)
    if not panel then return end
    local note = panel.fdjMapNote
    if not artMissing then
        if note then note:Hide() end
        return
    end
    if not note then
        note = panel:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
        note:SetPoint("BOTTOM", panel, "BOTTOM", 0, 22)
        note:SetWidth(560)
        note:SetJustifyH("CENTER")
        note:SetTextColor(1, 0.85, 0.5)
        note:SetShadowColor(0, 0, 0, 1)
        note:SetShadowOffset(1, -1)
        panel.fdjMapNote = note
    end
    local lang = FDJ.GetLanguage and FDJ.GetLanguage() or "enUS"
    note:SetText(MISSING[lang] or MISSING.enUS)
    note:Show()
end
