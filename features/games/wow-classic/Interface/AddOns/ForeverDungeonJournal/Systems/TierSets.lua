-- tierpage (2.0.10, M 17 Nov 2026: "add a tier set page: an icon next to
-- Onyxia in the same glowing style, showing the tier dungeon chest piece of
-- the player's class; once clicked, a page with a horizontal row of all the
-- pieces of their set, and an option at the top called Show all classes").
-- Tier Sets (M 17 Nov 2026: "the tier icon should just be called Tier Sets,
-- cause we are gonna put raid gear there too"): for now the Tier 0 sets
-- (Dungeon Set 1). The home page gets a round icon, the character's class's
-- Tier 0 chest piece, right of the Onyxia icon (of the Sleeping Bag's, or the
-- Raids medallion, when those are hidden), the same size and with the same
-- soft golden glow. Its page is the home page's own, in place of the dungeon
-- list, under the row of icons: Tier 0, the set's eight pieces in a row
-- (Head ... Feet), each with its icon, name and the boss and dungeon it
-- drops from (the loot data's). Show Classes (top right, a drop-down: All,
-- then every class with its icon; per character): the ticked classes' sets,
-- one row each, the character's own first.
-- A piece: hover for its tooltip, click to open the boss page it drops on
-- (shift-click: link it).
--
-- hometabs (M 17 Nov 2026: "I want them to toggle their own pages: if I
-- click on tier or onyxia, I want to keep seeing the icons at the top with
-- the icon highlighted like the highlight from the WoW Forever icon, and we
-- are also gonna change that icon to just show the dungeon page"): the row
-- of icons at the top of the home page works as tabs. The WoW Forever emblem
-- is the dungeon list (its "Forever dungeons only" switch stays in Options),
-- the Tier Sets icon the Tier Sets page, the Onyxia icon the Onyxia
-- Attunement page. The page shown has its icon lit (the emblem's gold ring
-- and brighter glow); clicking a lit Tier Sets or Onyxia icon goes back to
-- the dungeon list. On the Onyxia Attunement page the row of icons stays at
-- the top, where the Dungeons button was (the page sits a little lower).
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

-- The sets: the class's eight pieces, Head, Shoulder, Chest, Wrist, Hands,
-- Waist, Legs, Feet (item IDs as in Data/Dungeons.lua). The set's name is
-- read from the game's tooltip (the client's language); these are the
-- English ones, until it is.
local SETS = {
    WARRIOR = { 16731, 16733, 16730, 16735, 16737, 16736, 16732, 16734, name = "Battlegear of Valor" },
    PALADIN = { 16727, 16729, 16726, 16722, 16724, 16723, 16728, 16725, name = "Lightforge Armor" },
    HUNTER = { 16677, 16679, 16674, 16681, 16676, 16680, 16678, 16675, name = "Beaststalker Armor" },
    ROGUE = { 16707, 16708, 16721, 16710, 16712, 16713, 16709, 16711, name = "Shadowcraft Armor" },
    PRIEST = { 16693, 16695, 16690, 16697, 16692, 16696, 16694, 16691, name = "Vestments of the Devout" },
    SHAMAN = { 16667, 16669, 16666, 16671, 16672, 16673, 16668, 16670, name = "The Elements" },
    MAGE = { 16686, 16689, 16688, 16683, 16684, 16685, 16687, 16682, name = "Magister's Regalia" },
    WARLOCK = { 16698, 16701, 16700, 16703, 16705, 16702, 16699, 16704, name = "Dreadmist Raiment" },
    DRUID = { 16720, 16718, 16706, 16714, 16717, 16716, 16719, 16715, name = "Wildheart Raiment" },
}
-- tier05row (2.0.10): Dungeon Set 2 (Tier 0.5), Head to Feet as above, and
-- which of the four armor exchanges of the Tier 0.5 chain gives each piece
-- (1 An Earnest Proposition: Wrist; 2 Just Compensation: Hands, Waist; 3
-- Anthion's Parting Words: Shoulder, Legs, Feet; 4 Saving the Best for
-- Last: Head, Chest). From the Forever client's quest rewards
-- (quests 8905-9022, every class's).
-- t05forever (2.1.1, M 20 Nov 2026, his Soulforge Gauntlets on: "the items in
-- the tier 0.5 set don't have the right ID because I cannot link them, and
-- also they have the wrong bonus"): Forever's own Dungeon Set 2, new items
-- with new stats and set bonuses, one version per role for some classes
-- (the quests give a box to pick one from). One Tier 0.5 row per version
-- (M: "one row per version"), its spec icon under "Tier 0.5". Each version:
-- Head ... Feet as above (SOURCES.txt).
local SETS2 = {
    WARRIOR = { name = "Battlegear of Heroism",
        { role = "MELEE", 226860, 226858, 226862, 226863, 226861, 226864, 226859, 226857 },
        { role = "TANK", 226869, 226867, 226872, 226865, 226870, 226866, 226868, 226871 } },
    PALADIN = { name = "Soulforge Armor",
        { role = "MELEE", 226976, 226969, 226973, 226970, 226975, 226971, 226972, 226974 },
        { role = "HEALER", 226981, 226979, 226984, 226977, 226982, 226978, 226980, 226983 },
        { role = "TANK", 226989, 226987, 226992, 226985, 226990, 226986, 226988, 226991 } },
    HUNTER = { name = "Beastmaster Armor",
        { 226887, 226884, 226886, 226885, 226883, 226888, 226882, 226881 } },
    ROGUE = { name = "Darkmantle Armor",
        { 226829, 226826, 226825, 226830, 226828, 226832, 226827, 226831 } },
    PRIEST = { name = "Vestments of the Virtuous",
        { role = "HEALER", 226947, 226951, 226945, 226949, 226950, 226948, 226946, 226952 },
        { role = "CASTER", 226957, 226955, 226960, 226953, 226958, 226954, 226956, 226959 } },
    SHAMAN = { name = "The Five Thunders",
        { role = "CASTER", 227002, 227003, 227004, 227001, 227006, 227008, 227005, 227007 },
        { role = "HEALER", 227013, 227011, 227016, 227009, 227014, 227010, 227012, 227015 },
        { role = "MELEE", 227021, 227019, 227024, 227017, 227022, 227018, 227020, 227023 } },
    MAGE = { name = "Sorcerer's Regalia",
        { 226935, 226936, 226932, 226929, 226930, 226934, 226933, 226931 } },
    WARLOCK = { name = "Deathmist Raiment",
        { 226909, 226912, 226906, 226907, 226911, 226905, 226910, 226908 } },
    DRUID = { name = "Feralheart Raiment",
        { role = "CASTER", 226773, 226778, 226776, 226775, 226777, 226772, 226779, 226774 },
        { role = "HEALER", 226786, 226785, 226783, 226782, 226784, 226780, 226787, 226781 },
        { role = "MELEE", 226792, 226790, 226795, 226788, 226793, 226789, 226791, 226794 },
        { role = "TANK", 226801, 226798, 226804, 226796, 226802, 226797, 226799, 226803 } },
}
-- (the first version's pieces, for the set's name from its chest's tooltip)
local SETS2_NAME = {}
for token, set in pairs(SETS2) do
    local first = { name = set.name }
    for i = 1, 8 do first[i] = set[1][i] end
    SETS2_NAME[token] = first
end
local PIECE_QUEST = { 4, 3, 4, 1, 2, 2, 3, 3 }
local QUEST05 = { 8909, 8934, 8955, 9003 } -- (the names are the same for every class)
local QUEST05_EN = { "An Earnest Proposition", "Just Compensation", "Anthion's Parting Words", "Saving the Best for Last" }
local QuestTitle -- (set further down; the pieces' tooltips use it)
local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local CHEST = 3

local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local GLOW = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\TickGlow"
-- roundtab (2.0.10, M 17 Nov 2026: "I don't like the square highlight ... round it
-- around the icon so it's a bit cleaner"): a thin gold ring with a soft glow,
-- just outside the round icon (Media/TabRing.tga, made for it).
local RING = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\TabRing"
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes"

do
    local strings = {
        enUS = { TIER_TITLE = "Tier Sets", TIER_0 = "Tier 0", TIER_ICON_TIP = "Your class's tier sets: every piece and where it drops.",
            TIER_ALL_CLASSES = "Show all classes", TIER_SHOW_CLASSES = "Show Classes", TIER_ALL = "All", TIER_PIECE_TIP = "Click to open where it drops." },
        deDE = { TIER_TITLE = "Tier-Sets", TIER_0 = "Tier 0", TIER_ICON_TIP = "Die Tier-Sets deiner Klasse: jedes Teil und wo es droppt.",
            TIER_ALL_CLASSES = "Alle Klassen zeigen", TIER_SHOW_CLASSES = "Klassen zeigen", TIER_ALL = "Alle", TIER_PIECE_TIP = "Klicken, um zu öffnen, wo es droppt." },
        frFR = { TIER_TITLE = "Ensembles de tier", TIER_0 = "Tier 0", TIER_ICON_TIP = "Les ensembles de tier de votre classe : chaque pièce et où elle tombe.",
            TIER_ALL_CLASSES = "Afficher toutes les classes", TIER_SHOW_CLASSES = "Afficher les classes", TIER_ALL = "Toutes", TIER_PIECE_TIP = "Cliquez pour ouvrir l'endroit où elle tombe." },
        esES = { TIER_TITLE = "Conjuntos de tier", TIER_0 = "Tier 0", TIER_ICON_TIP = "Los conjuntos de tier de tu clase: cada pieza y dónde cae.",
            TIER_ALL_CLASSES = "Mostrar todas las clases", TIER_SHOW_CLASSES = "Mostrar clases", TIER_ALL = "Todas", TIER_PIECE_TIP = "Haz clic para abrir dónde cae." },
        itIT = { TIER_TITLE = "Set tier", TIER_0 = "Tier 0", TIER_ICON_TIP = "I set tier della tua classe: ogni pezzo e dove si trova.",
            TIER_ALL_CLASSES = "Mostra tutte le classi", TIER_SHOW_CLASSES = "Mostra classi", TIER_ALL = "Tutte", TIER_PIECE_TIP = "Clicca per aprire dove si trova." },
        ptBR = { TIER_TITLE = "Conjuntos de tier", TIER_0 = "Tier 0", TIER_ICON_TIP = "Os conjuntos de tier da sua classe: cada peça e onde cai.",
            TIER_ALL_CLASSES = "Mostrar todas as classes", TIER_SHOW_CLASSES = "Mostrar classes", TIER_ALL = "Todas", TIER_PIECE_TIP = "Clique para abrir onde cai." },
        ruRU = { TIER_TITLE = "Комплекты тиров", TIER_0 = "Tier 0", TIER_ICON_TIP = "Комплекты тиров вашего класса: каждая часть и где она выпадает.",
            TIER_ALL_CLASSES = "Показать все классы", TIER_SHOW_CLASSES = "Показать классы", TIER_ALL = "Все", TIER_PIECE_TIP = "Нажмите, чтобы открыть, где выпадает." },
        koKR = { TIER_TITLE = "티어 세트", TIER_0 = "티어 0", TIER_ICON_TIP = "직업의 티어 세트: 모든 부위와 획득처.",
            TIER_ALL_CLASSES = "모든 직업 표시", TIER_SHOW_CLASSES = "직업 표시", TIER_ALL = "전체", TIER_PIECE_TIP = "클릭하여 획득처 열기" },
        zhCN = { TIER_TITLE = "套装", TIER_0 = "T0", TIER_ICON_TIP = "你职业的套装：每个部件及其掉落位置。",
            TIER_ALL_CLASSES = "显示所有职业", TIER_SHOW_CLASSES = "显示职业", TIER_ALL = "全部", TIER_PIECE_TIP = "点击打开掉落位置" },
        zhTW = { TIER_TITLE = "套裝", TIER_0 = "T0", TIER_ICON_TIP = "你職業的套裝：每個部位及其掉落位置。",
            TIER_ALL_CLASSES = "顯示所有職業", TIER_SHOW_CLASSES = "顯示職業", TIER_ALL = "全部", TIER_PIECE_TIP = "點擊打開掉落位置" },
    }
    strings.esMX = strings.esES
    for locale, entries in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for key, value in pairs(entries) do
                if t[key] == nil then t[key] = value end
            end
        end
    end
end
do -- tierback (2.0.10)
    local strings = {
        enUS = { BACK_TO_TIERS = "Back to Tiers" },
        deDE = { BACK_TO_TIERS = "Zurück zu Tier-Sets" },
        frFR = { BACK_TO_TIERS = "Retour aux tiers" },
        esES = { BACK_TO_TIERS = "Volver a los tiers" },
        itIT = { BACK_TO_TIERS = "Torna ai tier" },
        ptBR = { BACK_TO_TIERS = "Voltar aos tiers" },
        ruRU = { BACK_TO_TIERS = "Назад к тирам" },
        koKR = { BACK_TO_TIERS = "티어로 돌아가기" },
        zhCN = { BACK_TO_TIERS = "返回套装" },
        zhTW = { BACK_TO_TIERS = "返回套裝" },
    }
    strings.esMX = strings.esES
    for locale, entries in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for key, value in pairs(entries) do
                if t[key] == nil then t[key] = value end
            end
        end
    end
end
do -- tier05row, tierhide (2.0.10)
    local strings = {
        enUS = { TIER_05 = "Tier 0.5", TIER05_LABEL = "Tier 0.5: %s", TIER05_FROM = "Tier 0.5 quest: %s", TIER_HIDE = "Hide", TIER_HIDE_TIP = "Right-click to hide",
            OPT_HIDE_TIER = "Hide Tier Sets", OPT_HIDE_TIER_TIP = "Hides the Tier Sets icon on the journal's home page. It stays hidden until level 50; untick this to show it sooner. You can also right-click the icon and pick Hide." },
        deDE = { TIER_05 = "Tier 0.5", TIER05_LABEL = "Tier 0.5: %s", TIER05_FROM = "Tier-0.5-Quest: %s", TIER_HIDE = "Ausblenden", TIER_HIDE_TIP = "Rechtsklick zum Ausblenden",
            OPT_HIDE_TIER = "Tier-Sets ausblenden", OPT_HIDE_TIER_TIP = "Blendet das Tier-Sets-Symbol auf der Startseite des Journals aus. Bis Stufe 50 bleibt es ausgeblendet; entferne den Haken, um es früher zu zeigen. Geht auch per Rechtsklick auf das Symbol → Ausblenden." },
        frFR = { TIER_05 = "Tier 0.5", TIER05_LABEL = "Tier 0.5 : %s", TIER05_FROM = "Quête du Tier 0.5 : %s", TIER_HIDE = "Masquer", TIER_HIDE_TIP = "Clic droit pour masquer",
            OPT_HIDE_TIER = "Masquer les ensembles de tier", OPT_HIDE_TIER_TIP = "Masque l'icône des ensembles de tier sur la page d'accueil du journal. Elle reste masquée jusqu'au niveau 50 ; décochez pour l'afficher plus tôt. Clic droit sur l'icône → Masquer fonctionne aussi." },
        esES = { TIER_05 = "Tier 0.5", TIER05_LABEL = "Tier 0.5: %s", TIER05_FROM = "Misión de Tier 0.5: %s", TIER_HIDE = "Ocultar", TIER_HIDE_TIP = "Clic derecho para ocultar",
            OPT_HIDE_TIER = "Ocultar conjuntos de tier", OPT_HIDE_TIER_TIP = "Oculta el icono de conjuntos de tier en la página de inicio del diario. Sigue oculto hasta el nivel 50; desmárcalo para mostrarlo antes. También puedes hacer clic derecho en el icono y elegir Ocultar." },
        itIT = { TIER_05 = "Tier 0.5", TIER05_LABEL = "Tier 0.5: %s", TIER05_FROM = "Missione Tier 0.5: %s", TIER_HIDE = "Nascondi", TIER_HIDE_TIP = "Clic destro per nascondere",
            OPT_HIDE_TIER = "Nascondi set tier", OPT_HIDE_TIER_TIP = "Nasconde l'icona dei set tier nella pagina iniziale del diario. Resta nascosta fino al livello 50; togli la spunta per mostrarla prima. Puoi anche fare clic destro sull'icona e scegliere Nascondi." },
        ptBR = { TIER_05 = "Tier 0.5", TIER05_LABEL = "Tier 0.5: %s", TIER05_FROM = "Missão do Tier 0.5: %s", TIER_HIDE = "Ocultar", TIER_HIDE_TIP = "Clique com o botão direito para ocultar",
            OPT_HIDE_TIER = "Ocultar conjuntos de tier", OPT_HIDE_TIER_TIP = "Oculta o ícone de conjuntos de tier na página inicial do diário. Fica oculto até o nível 50; desmarque para mostrá-lo antes. Você também pode clicar com o botão direito no ícone e escolher Ocultar." },
        ruRU = { TIER_05 = "Тир 0.5", TIER05_LABEL = "Тир 0.5: %s", TIER05_FROM = "Задание Тир 0.5: %s", TIER_HIDE = "Скрыть", TIER_HIDE_TIP = "Правый клик — скрыть",
            OPT_HIDE_TIER = "Скрыть комплекты тиров", OPT_HIDE_TIER_TIP = "Скрывает значок комплектов тиров на главной странице журнала. До 50-го уровня он скрыт; снимите галочку, чтобы показать его раньше. Также можно щелкнуть по значку правой кнопкой и выбрать «Скрыть»." },
        koKR = { TIER_05 = "티어 0.5", TIER05_LABEL = "티어 0.5: %s", TIER05_FROM = "티어 0.5 퀘스트: %s", TIER_HIDE = "숨기기", TIER_HIDE_TIP = "우클릭하여 숨기기",
            OPT_HIDE_TIER = "티어 세트 숨기기", OPT_HIDE_TIER_TIP = "도감 첫 페이지의 티어 세트 아이콘을 숨깁니다. 50레벨까지는 숨겨져 있으며, 체크를 해제하면 더 일찍 표시됩니다. 아이콘을 우클릭하고 숨기기를 선택해도 됩니다." },
        zhCN = { TIER_05 = "T0.5", TIER05_LABEL = "T0.5：%s", TIER05_FROM = "T0.5任务：%s", TIER_HIDE = "隐藏", TIER_HIDE_TIP = "右键点击隐藏",
            OPT_HIDE_TIER = "隐藏套装", OPT_HIDE_TIER_TIP = "隐藏日志首页上的套装图标。50级之前保持隐藏；取消勾选可提前显示。也可以右键点击图标并选择隐藏。" },
        zhTW = { TIER_05 = "T0.5", TIER05_LABEL = "T0.5：%s", TIER05_FROM = "T0.5任務：%s", TIER_HIDE = "隱藏", TIER_HIDE_TIP = "右鍵點擊隱藏",
            OPT_HIDE_TIER = "隱藏套裝", OPT_HIDE_TIER_TIP = "隱藏日誌首頁上的套裝圖示。50級之前保持隱藏；取消勾選可提前顯示。也可以右鍵點擊圖示並選擇隱藏。" },
    }
    strings.esMX = strings.esES
    for locale, entries in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for key, value in pairs(entries) do
                if t[key] == nil then t[key] = value end
            end
        end
    end
end

local function L(key, ...)
    if FDJ.L then return FDJ.L(key, ...) end
    return key
end
local function Plain(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
    return v
end

local function PlayerClass()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    token = ok and Plain(token) or nil
    return type(token) == "string" and token or nil
end
-- The character's class's set (a class with none: the warrior's, for the icon).
local function OwnClass()
    local token = PlayerClass()
    if token and SETS[token] then return token, true end
    return "WARRIOR", false
end

local function ItemIcon(id)
    local icon
    if C_Item and type(C_Item.GetItemIconByID) == "function" then
        local ok, v = pcall(C_Item.GetItemIconByID, id)
        if ok then icon = v end
    end
    if not icon and type(GetItemIcon) == "function" then
        local ok, v = pcall(GetItemIcon, id)
        if ok then icon = v end
    end
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ItemInfo(id)
    if type(GetItemInfo) ~= "function" then return nil end
    local ok, name, link, quality = pcall(GetItemInfo, id)
    if not ok then return nil end
    return name, link, quality
end

-- tierlink (2.1.2, M 20 Nov 2026: "why can't I shift click on tier 0.5"):
-- an item's chat link from the game's C_Item.GetItemInfo (WoW Forever's
-- client has no global GetItemInfo, so ItemInfo above gave no link and a
-- Shift-click did nothing, on every Tier row). Not cached yet: asked for, and
-- the next click has it (hovering the piece loads it too).
local function ItemLink(id)
    id = tonumber(id)
    if not id then return nil end
    local get = C_Item and C_Item.GetItemInfo
    if type(get) == "function" then
        local ok, _, link = pcall(get, id)
        if ok and link then return link end
    end
    local _, link = ItemInfo(id)
    if link then return link end
    if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then pcall(C_Item.RequestLoadItemDataByID, id) end
    return nil
end

-- The set's name in the client's language: the "Lightforge Armor (0/8)"
-- line of its chest piece's tooltip.
local setNames, scanTip = {}, nil
local function SetName(token, sets) -- (tier05row: SETS2 too)
    sets = sets or SETS
    local cache = setNames[sets] or {}
    setNames[sets] = cache
    if cache[token] then return cache[token] end
    local set = sets[token]
    if not set then return "" end
    if CreateFrame and not scanTip then
        local ok, tip = pcall(CreateFrame, "GameTooltip", "ForeverDungeonJournalTierScanTip", nil, "GameTooltipTemplate")
        if ok then scanTip = tip end
    end
    if scanTip then
        pcall(function()
            scanTip:SetOwner(UIParent or WorldFrame, "ANCHOR_NONE")
            scanTip:ClearLines()
            scanTip:SetHyperlink("item:" .. set[CHEST])
        end)
        for i = 1, (scanTip.NumLines and scanTip:NumLines()) or 0 do
            local line = _G["ForeverDungeonJournalTierScanTipTextLeft" .. i]
            local text = line and line.GetText and Plain(line:GetText())
            local name = type(text) == "string" and text:match("^(.-)%s*%(%d+/%d+%)%s*$")
            if name and name ~= "" then
                cache[token] = name
                return name
            end
        end
    end
    return set.name
end

-- Where a piece drops: every boss (and Trash Drops) whose loot lists it, in
-- the journal's dungeon order; not the RPG Mode's hidden bosses or locked
-- dungeons.
local function Sources(id)
    local list = {}
    for _, dungeonName in ipairs(FDJ.ORDER or {}) do
        local dungeon = FDJ.DB and FDJ.DB[dungeonName]
        if dungeon and not (FDJ.IsDungeonLocked and FDJ.IsDungeonLocked(dungeonName)) then
            for bossIndex, boss in ipairs(dungeon.bosses or {}) do
                if type(boss) == "table" and not boss.recipeTab
                    and not (FDJ.RPGBossHidden and FDJ.RPGBossHidden(dungeonName, boss)) then
                    for _, item in ipairs(boss.loot or {}) do
                        if type(item) == "table" and tonumber(item[1]) == id then
                            list[#list + 1] = { dungeon = dungeonName, index = bossIndex, boss = boss.name, item = item }
                            break
                        end
                    end
                end
            end
        end
    end
    return list
end

local function BossText(source)
    local boss = (FDJ.LocalizeBossName and FDJ.LocalizeBossName(source.boss)) or source.boss or ""
    local dungeon = (FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(source.dungeon)) or source.dungeon or ""
    return boss, dungeon
end

local function Hex(r, g, b)
    return string.format("%02x%02x%02x", math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5))
end
local function ClassLabel(token)
    local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    local color = c and Hex(c.r, c.g, c.b) or "ffffff"
    return "|cff" .. color .. name .. "|r  |cffffd100" .. SetName(token) .. "|r"
end

-- ------------------------------------------------------------- the page
local panel
local Refresh, PaintTabs, ApplyLayout
local ICON_SIZE, GAP, ROW_GAP = 44, 8, 18
-- tiercompact (M 17 Nov 2026: "a compact view option before Show all classes,
-- so if we tick Show all classes we can compact and it's cleaner on one
-- page"): one slim line per class, its name and set on the left, the eight
-- pieces as small icons; names and where they drop are in the tooltip.
local ICON_C, GAP_C, ROW_H_C, ROW_GAP_C, LABEL_W = 30, 10, 36, 4, 230
local TIER_LABEL_W = 64 -- tierlabels: the "Tier 0" / "Tier 0.5" column

local function Journal() return _G.ForeverDungeonJournalFrame end

-- The home page's dungeon list (and what goes with it), hidden while the
-- Tier Sets page is shown in its place.
local function ListParts(f)
    return { f.homeScroll, f.homeEmptyText, f.homeShowAllButton, f.hideDungeonsButton }
end
local function HideList(f)
    local parts = ListParts(f)
    for i = 1, 4 do
        if parts[i] then parts[i]:Hide() end
    end
end

-- Which of the top icons' pages is shown: "dungeons" (the home page's list),
-- "tier", "onyxia", or nil (any other page).
function FDJ.ActiveHomeTab()
    local f = Journal()
    if not f then return "dungeons" end
    if f.currentView == "home" then
        return (panel and panel:IsShown()) and "tier" or "dungeons"
    end
    local page = FDJ.GetSelectedDungeon and FDJ.GetSelectedDungeon()
    if FDJ.ONYXIA_PAGE and page == FDJ.ONYXIA_PAGE then return "onyxia" end
    -- bagtab (2.0.10, M 17 Nov 2026: "the sleeping bag is not showing its
    -- own page ... I do not see the other option at the top"): the Cozy
    -- Sleeping Bag's page is a tab like the Onyxia one.
    if FDJ.SLEEPING_BAG_PAGE and page == FDJ.SLEEPING_BAG_PAGE then return "sleepingbag" end
    return nil
end

-- tierback (2.0.10, M 17 Nov 2026: "when I click on a tier set or on a boss
-- and it sends me to the page, I want a button at the top left, just like
-- where dungeon usually is, that says back to tiers"): a piece's boss page
-- opened from here has "Back to Tiers" in the Dungeons button's place; it
-- leads back to this page, scrolled where it was. Another dungeon or the
-- home page opened: the Dungeons button again.
local tierReturn -- { dungeon = name, scroll = offset, armed = true once the page is open }
local function OpenSource(cell)
    local source = cell.sources and cell.sources[1]
    if not source then return end
    local scroll = panel and panel.scroll and panel.scroll.GetVerticalScroll and panel.scroll:GetVerticalScroll() or 0
    tierReturn = { dungeon = source.dungeon, scroll = scroll }
    if FDJ.OpenBossPage then FDJ.OpenBossPage(source.dungeon, source.index) end
    if tierReturn then
        tierReturn.armed = true
        if FDJ.UpdateDungeonArrows then pcall(FDJ.UpdateDungeonArrows) end
    end
    local id = cell.itemID
    if FDJ.FocusBossLootItem then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.05, function() FDJ.FocusBossLootItem(id) end)
        else
            FDJ.FocusBossLootItem(id)
        end
    end
end

-- tiertick (2.0.10, M 17 Nov 2026: "the check mark to be bold and slightly
-- bigger"): a bold green tick (Media\TierTick), 23 (M: "23 is fine"; the
-- size bar he tried it with is gone); Compact view's is smaller.
local TICK_TEX = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\TierTick.tga"
local TICK_SIZE = 23
local function TickSize(compact)
    if compact then return math.floor(TICK_SIZE * 0.72 + 0.5) end
    return TICK_SIZE
end

local function MakeCell(parent)
    local cell = CreateFrame("Button", nil, parent)
    cell:RegisterForClicks("LeftButtonUp")
    cell.border = cell:CreateTexture(nil, "BORDER")
    cell.border:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
    cell.border:SetPoint("TOP", 0, 0)
    cell.border:SetColorTexture(0, 0.44, 0.87, 1)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetSize(ICON_SIZE, ICON_SIZE)
    cell.icon:SetPoint("CENTER", cell.border, "CENTER")
    cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    cell.hl = cell:CreateTexture(nil, "HIGHLIGHT")
    cell.hl:SetAllPoints(cell.icon)
    cell.hl:SetColorTexture(1, 1, 1, 0.18)
    -- tiersource (2.0.10, M 17 Nov 2026: "when I hover who drops it, I want
    -- to see the boss portrait with the dungeon name"): the text under the
    -- name has its own hover: the boss's portrait and where (the quest, for
    -- a Tier 0.5 piece); the icon and the name keep the item's tooltip.
    cell.sourceHit = CreateFrame("Button", nil, cell)
    cell.sourceHit:RegisterForClicks("LeftButtonUp")
    cell.sourceHit:SetScript("OnEnter", function(self) if FDJ.ShowTierSourceTip then FDJ.ShowTierSourceTip(self, cell) end end)
    cell.sourceHit:SetScript("OnLeave", function() if FDJ.HideTierSourceTip then FDJ.HideTierSourceTip() end end)
    cell.sourceHit:SetScript("OnClick", function() if FDJ.HideTierSourceTip then FDJ.HideTierSourceTip() end OpenSource(cell) end)
    cell.check = cell:CreateTexture(nil, "OVERLAY", nil, 7) -- tiercheck
    cell.check:SetTexture(TICK_TEX)
    cell.check:SetPoint("CENTER", cell.border, "TOPRIGHT", -3, -3)
    cell.check:Hide()
    cell.name = cell:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    cell.name:SetPoint("TOP", cell.border, "BOTTOM", 0, -4)
    cell.name:SetJustifyH("CENTER")
    cell.name:SetJustifyV("TOP")
    cell.name:SetWordWrap(true)
    if cell.name.SetMaxLines then cell.name:SetMaxLines(2) end
    cell.source = cell:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontDisableSmall")
    cell.source:SetPoint("TOP", cell.name, "BOTTOM", 0, -3)
    cell.source:SetJustifyH("CENTER")
    cell.source:SetJustifyV("TOP")
    cell.source:SetWordWrap(true)
    if cell.source.SetMaxLines then cell.source:SetMaxLines(4) end
    cell:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. self.itemID)
        if self.compact and self.sources and #self.sources > 0 then -- tiercompact: no source under it
            GameTooltip:AddLine(" ")
            for j = 1, math.min(#self.sources, 5) do
                local boss, dungeon = BossText(self.sources[j])
                GameTooltip:AddLine(L("DROPS_FROM", boss .. " (" .. dungeon .. ")"), 1, 0.82, 0, true)
            end
        end
        if self.questIndex then -- tier05row
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L("TIER05_FROM", QuestTitle(self.questIndex)), 1, 0.82, 0, true)
        end
        if self.sources and #self.sources > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L("TIER_PIECE_TIP"), 0.35, 1.00, 0.35)
        end
        GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    cell:SetScript("OnClick", function(self)
        if IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
            local link = ItemLink(self.itemID) -- tierlink (2.1.2)
            if link then HandleModifiedItemClick(link) end
            return
        end
        OpenSource(self)
    end)
    return cell
end

local function MakeRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row.classIcon:SetSize(20, 20)
    row.classIcon:SetPoint("TOPLEFT", 2, 0)
    row.classIcon:SetTexture(CLASS_ICONS)
    row.label = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    row.label:SetPoint("LEFT", row.classIcon, "RIGHT", 6, 0)
    row.label:SetJustifyH("LEFT")
    row.sub = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    row.sub:SetJustifyH("LEFT")
    row.sub:SetTextColor(1.00, 0.82, 0.00)
    row.sub:Hide()
    row.line = row:CreateTexture(nil, "BACKGROUND")
    row.line:SetColorTexture(0.57, 0.43, 0.20, 0.45)
    row.line:SetHeight(1)
    row.line:SetPoint("TOPLEFT", row.classIcon, "BOTTOMLEFT", 0, -5)
    row.line:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.cells = {}
    for i = 1, 8 do row.cells[i] = MakeCell(row) end
    -- tier05row: the Tier 0.5 pieces, the arrows down to them, its set's name
    row.cells2, row.arrows = {}, {}
    for i = 1, 8 do
        row.cells2[i] = MakeCell(row)
        local arrow = row:CreateTexture(nil, "ARTWORK")
        arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
        arrow:SetSize(14, 14)
        arrow:SetVertexColor(1, 0.82, 0.3)
        arrow:Hide()
        row.arrows[i] = arrow
    end
    row.arrowC = row:CreateTexture(nil, "ARTWORK")
    row.arrowC:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    row.arrowC:SetSize(16, 16)
    row.arrowC:SetVertexColor(1, 0.82, 0.3)
    row.arrowC:Hide()
    row.lab0 = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal") -- tierlabels
    row.lab0:SetJustifyH("LEFT")
    row.lab0:SetTextColor(1.00, 0.82, 0.27)
    row.lab05 = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    row.lab05:SetJustifyH("LEFT")
    row.lab05:SetTextColor(1.00, 0.82, 0.27)
    row.t05 = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    row.t05:SetJustifyH("RIGHT")
    row.t05:SetTextColor(1.00, 0.82, 0.00)
    return row
end

local function ClassName(token)
    local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    return "|cff" .. (c and Hex(c.r, c.g, c.b) or "ffffff") .. name .. "|r"
end

-- tier05row (2.0.10, M 17 Nov 2026: "build the tier 0.5 right below the
-- tier set ... a little arrow that points below at the tier 0.5 piece"):
-- under each class's Tier 0 pieces, a small arrow down to the piece it
-- becomes (Dungeon Set 2), with the quest that gives it. In Compact view the
-- Tier 0.5 pieces follow the Tier 0 ones on the same line, after an arrow.
-- tiercheck (M: "if I have the chest I want a little green check mark on the
-- top right ... not for other classes"): the character's own class's pieces
-- it has (worn, in the bags or in the bank) get a green tick.
local function Owned(id)
    if type(IsEquippedItem) == "function" then
        local ok, worn = pcall(IsEquippedItem, id)
        if ok and worn == true then return true end
    end
    local n = 0
    if C_Item and type(C_Item.GetItemCount) == "function" then
        local ok, v = pcall(C_Item.GetItemCount, id, true)
        n = ok and tonumber(Plain(v)) or 0
    elseif type(GetItemCount) == "function" then
        local ok, v = pcall(GetItemCount, id, true)
        n = ok and tonumber(Plain(v)) or 0
    end
    return (n or 0) > 0
end

-- The quest that gives a Tier 0.5 piece, in the client's language once the
-- game has it (the English name until then).
QuestTitle = function(i)
    local id = QUEST05[i]
    if not id then return "" end
    if C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
        local ok, t = pcall(C_QuestLog.GetTitleForQuestID, id)
        t = ok and Plain(t) or nil
        if type(t) == "string" and t ~= "" then return t end
    end
    if C_QuestLog and type(C_QuestLog.RequestLoadQuestByID) == "function" then pcall(C_QuestLog.RequestLoadQuestByID, id) end
    return QUEST05_EN[i]
end

local function FillCell(cell, id, size, cellW, compact, sources, questIndex, own)
    cell.itemID = id
    cell.sources = sources or {}
    cell.questIndex = questIndex
    local name, link, quality = ItemInfo(id)
    local first = cell.sources[1]
    if not name then
        name = first and first.item and first.item[2] or ""
        if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    local fallback = (first and first.item and tonumber(first.item[4])) or 3
    local r, g, b = 0, 0.44, 0.87
    -- tierepic (2.0.10, M 17 Nov 2026: "the epic items to have the epic
    -- portrait color, not the blue one"): the colour the game's own tooltip
    -- gives the item (the journal's loot lists do the same), not the item
    -- data's quality, which can be the old one (Forever made many Tier 0.5
    -- pieces epic).
    local okQ, qr, qg, qb = false, nil, nil, nil
    if FDJ.GetAuthoritativeItemQuality then okQ, qr, qg, qb = pcall(FDJ.GetAuthoritativeItemQuality, id, link, quality, fallback) end
    if okQ and qr then
        r, g, b = qr, qg, qb
    elseif type(GetItemQualityColor) == "function" then
        local ok, cr, cg, cb = pcall(GetItemQualityColor, quality or fallback)
        if ok and cr then r, g, b = cr, cg, cb end
    end
    cell.icon:SetTexture(ItemIcon(id))
    cell.border:SetColorTexture(r, g, b, 1)
    cell.border:SetSize(size + 4, size + 4)
    cell.icon:SetSize(size, size)
    cell.compact = compact
    local tick = TickSize(compact)
    cell.check:SetSize(tick, tick)
    -- (dev, not in a release: /dj tiercheck ticks every piece to preview it)
    cell.check:SetShown((own == true and Owned(id)) or FDJ.tierCheckTest == true)
    if compact then
        cell.name:Hide()
        cell.source:Hide()
        cell.sourceHit:Hide()
        cell:SetSize(size + 4, size + 4)
        return size + 4
    end
    cell.name:SetWidth(cellW)
    cell.name:SetText(name)
    cell.name:SetTextColor(r, g, b)
    cell.source:SetWidth(cellW)
    if questIndex then
        cell.source:SetText("|TInterface\\GossipFrame\\AvailableQuestIcon:0|t" .. QuestTitle(questIndex))
    elseif first then
        local boss, dungeon = BossText(first)
        if #cell.sources > 1 then boss = boss .. " (+" .. (#cell.sources - 1) .. ")" end
        cell.source:SetText(boss .. "\n" .. dungeon)
    else
        cell.source:SetText("???")
    end
    cell.name:Show()
    cell.source:Show()
    cell.sourceHit:ClearAllPoints()
    cell.sourceHit:SetPoint("TOPLEFT", cell.source, "TOPLEFT", 0, 2)
    cell.sourceHit:SetPoint("BOTTOMRIGHT", cell.source, "BOTTOMRIGHT", 0, -2)
    cell.sourceHit:SetFrameLevel((cell:GetFrameLevel() or 1) + 2)
    cell.sourceHit:Show()
    local h = size + 4 + 4 + (cell.name:GetStringHeight() or 24) + 3 + (cell.source:GetStringHeight() or 24)
    cell:SetSize(cellW, h)
    return h
end

-- t05forever: a version's label ("Tier 0.5" over its spec icon, or the icon
-- alone in Compact view), and the cells, label and arrow of the versions
-- after the first (made the first time a class with that many is shown; the
-- rows are reused).
-- t05icon (2.1.1, M 20 Nov 2026: "rather have the spec icon instead of
-- melee ... show the spec icon, that's enough"): each version's spec icon
-- (the class's talent tree icon) in place of its role's name.
local SPEC_ICONS = {
    WARRIOR = { MELEE = "Ability_Warrior_SavageBlow", TANK = "Ability_Warrior_DefensiveStance" },
    PALADIN = { MELEE = "Spell_Holy_AuraOfLight", HEALER = "Spell_Holy_HolyBolt", TANK = "Spell_Holy_DevotionAura" },
    PRIEST = { HEALER = "Spell_Holy_HolyBolt", CASTER = "Spell_Shadow_ShadowWordPain" },
    SHAMAN = { CASTER = "Spell_Nature_Lightning", HEALER = "Spell_Nature_MagicImmunity", MELEE = "Spell_Nature_LightningShield" },
    DRUID = { CASTER = "Spell_Nature_StarFall", HEALER = "Spell_Nature_HealingTouch", MELEE = "Ability_Druid_CatForm", TANK = "Ability_Racial_BearForm" },
}
-- t05tip (2.1.1, M 20 Nov 2026: "when hovering over the icon of the spec
-- ... the little tooltip to say the spec name ... cat, bear ... both in
-- compact and detail view"): the spec's name in the game's words.
do
    local strings = {
        enUS = { TIER05_SPEC_WARRIOR_MELEE = "Arms / Fury", TIER05_SPEC_WARRIOR_TANK = "Protection", TIER05_SPEC_PALADIN_MELEE = "Retribution", TIER05_SPEC_PALADIN_HEALER = "Holy", TIER05_SPEC_PALADIN_TANK = "Protection", TIER05_SPEC_PRIEST_HEALER = "Holy", TIER05_SPEC_PRIEST_CASTER = "Shadow", TIER05_SPEC_SHAMAN_CASTER = "Elemental", TIER05_SPEC_SHAMAN_HEALER = "Restoration", TIER05_SPEC_SHAMAN_MELEE = "Enhancement", TIER05_SPEC_DRUID_CASTER = "Balance", TIER05_SPEC_DRUID_HEALER = "Restoration", TIER05_SPEC_DRUID_MELEE = "Cat", TIER05_SPEC_DRUID_TANK = "Bear" },
        deDE = { TIER05_SPEC_WARRIOR_MELEE = "Waffen / Furor", TIER05_SPEC_WARRIOR_TANK = "Schutz", TIER05_SPEC_PALADIN_MELEE = "Vergeltung", TIER05_SPEC_PALADIN_HEALER = "Heilig", TIER05_SPEC_PALADIN_TANK = "Schutz", TIER05_SPEC_PRIEST_HEALER = "Heilig", TIER05_SPEC_PRIEST_CASTER = "Schatten", TIER05_SPEC_SHAMAN_CASTER = "Elementar", TIER05_SPEC_SHAMAN_HEALER = "Wiederherstellung", TIER05_SPEC_SHAMAN_MELEE = "Verstärkung", TIER05_SPEC_DRUID_CASTER = "Gleichgewicht", TIER05_SPEC_DRUID_HEALER = "Wiederherstellung", TIER05_SPEC_DRUID_MELEE = "Katze", TIER05_SPEC_DRUID_TANK = "Bär" },
        frFR = { TIER05_SPEC_WARRIOR_MELEE = "Armes / Fureur", TIER05_SPEC_WARRIOR_TANK = "Protection", TIER05_SPEC_PALADIN_MELEE = "Vindicte", TIER05_SPEC_PALADIN_HEALER = "Sacré", TIER05_SPEC_PALADIN_TANK = "Protection", TIER05_SPEC_PRIEST_HEALER = "Sacré", TIER05_SPEC_PRIEST_CASTER = "Ombre", TIER05_SPEC_SHAMAN_CASTER = "Élémentaire", TIER05_SPEC_SHAMAN_HEALER = "Restauration", TIER05_SPEC_SHAMAN_MELEE = "Amélioration", TIER05_SPEC_DRUID_CASTER = "Équilibre", TIER05_SPEC_DRUID_HEALER = "Restauration", TIER05_SPEC_DRUID_MELEE = "Chat", TIER05_SPEC_DRUID_TANK = "Ours" },
        esES = { TIER05_SPEC_WARRIOR_MELEE = "Armas / Furia", TIER05_SPEC_WARRIOR_TANK = "Protección", TIER05_SPEC_PALADIN_MELEE = "Reprensión", TIER05_SPEC_PALADIN_HEALER = "Sagrado", TIER05_SPEC_PALADIN_TANK = "Protección", TIER05_SPEC_PRIEST_HEALER = "Sagrado", TIER05_SPEC_PRIEST_CASTER = "Sombra", TIER05_SPEC_SHAMAN_CASTER = "Elemental", TIER05_SPEC_SHAMAN_HEALER = "Restauración", TIER05_SPEC_SHAMAN_MELEE = "Mejora", TIER05_SPEC_DRUID_CASTER = "Equilibrio", TIER05_SPEC_DRUID_HEALER = "Restauración", TIER05_SPEC_DRUID_MELEE = "Felino", TIER05_SPEC_DRUID_TANK = "Oso" },
        itIT = { TIER05_SPEC_WARRIOR_MELEE = "Armi / Furia", TIER05_SPEC_WARRIOR_TANK = "Protezione", TIER05_SPEC_PALADIN_MELEE = "Castigo", TIER05_SPEC_PALADIN_HEALER = "Sacro", TIER05_SPEC_PALADIN_TANK = "Protezione", TIER05_SPEC_PRIEST_HEALER = "Sacro", TIER05_SPEC_PRIEST_CASTER = "Ombra", TIER05_SPEC_SHAMAN_CASTER = "Elementale", TIER05_SPEC_SHAMAN_HEALER = "Rigenerazione", TIER05_SPEC_SHAMAN_MELEE = "Potenziamento", TIER05_SPEC_DRUID_CASTER = "Equilibrio", TIER05_SPEC_DRUID_HEALER = "Rigenerazione", TIER05_SPEC_DRUID_MELEE = "Felino", TIER05_SPEC_DRUID_TANK = "Orso" },
        ptBR = { TIER05_SPEC_WARRIOR_MELEE = "Armas / Fúria", TIER05_SPEC_WARRIOR_TANK = "Proteção", TIER05_SPEC_PALADIN_MELEE = "Retribuição", TIER05_SPEC_PALADIN_HEALER = "Sagrado", TIER05_SPEC_PALADIN_TANK = "Proteção", TIER05_SPEC_PRIEST_HEALER = "Sagrado", TIER05_SPEC_PRIEST_CASTER = "Sombra", TIER05_SPEC_SHAMAN_CASTER = "Elemental", TIER05_SPEC_SHAMAN_HEALER = "Restauração", TIER05_SPEC_SHAMAN_MELEE = "Aperfeiçoamento", TIER05_SPEC_DRUID_CASTER = "Equilíbrio", TIER05_SPEC_DRUID_HEALER = "Restauração", TIER05_SPEC_DRUID_MELEE = "Felino", TIER05_SPEC_DRUID_TANK = "Urso" },
        ruRU = { TIER05_SPEC_WARRIOR_MELEE = "Оружие / Неистовство", TIER05_SPEC_WARRIOR_TANK = "Защита", TIER05_SPEC_PALADIN_MELEE = "Воздаяние", TIER05_SPEC_PALADIN_HEALER = "Свет", TIER05_SPEC_PALADIN_TANK = "Защита", TIER05_SPEC_PRIEST_HEALER = "Свет", TIER05_SPEC_PRIEST_CASTER = "Тьма", TIER05_SPEC_SHAMAN_CASTER = "Стихии", TIER05_SPEC_SHAMAN_HEALER = "Исцеление", TIER05_SPEC_SHAMAN_MELEE = "Совершенствование", TIER05_SPEC_DRUID_CASTER = "Баланс", TIER05_SPEC_DRUID_HEALER = "Исцеление", TIER05_SPEC_DRUID_MELEE = "Кошка", TIER05_SPEC_DRUID_TANK = "Медведь" },
        koKR = { TIER05_SPEC_WARRIOR_MELEE = "무기 / 분노", TIER05_SPEC_WARRIOR_TANK = "방어", TIER05_SPEC_PALADIN_MELEE = "징벌", TIER05_SPEC_PALADIN_HEALER = "신성", TIER05_SPEC_PALADIN_TANK = "보호", TIER05_SPEC_PRIEST_HEALER = "신성", TIER05_SPEC_PRIEST_CASTER = "암흑", TIER05_SPEC_SHAMAN_CASTER = "정기", TIER05_SPEC_SHAMAN_HEALER = "복원", TIER05_SPEC_SHAMAN_MELEE = "고양", TIER05_SPEC_DRUID_CASTER = "조화", TIER05_SPEC_DRUID_HEALER = "회복", TIER05_SPEC_DRUID_MELEE = "표범", TIER05_SPEC_DRUID_TANK = "곰" },
        zhCN = { TIER05_SPEC_WARRIOR_MELEE = "武器 / 狂怒", TIER05_SPEC_WARRIOR_TANK = "防护", TIER05_SPEC_PALADIN_MELEE = "惩戒", TIER05_SPEC_PALADIN_HEALER = "神圣", TIER05_SPEC_PALADIN_TANK = "防护", TIER05_SPEC_PRIEST_HEALER = "神圣", TIER05_SPEC_PRIEST_CASTER = "暗影", TIER05_SPEC_SHAMAN_CASTER = "元素", TIER05_SPEC_SHAMAN_HEALER = "恢复", TIER05_SPEC_SHAMAN_MELEE = "增强", TIER05_SPEC_DRUID_CASTER = "平衡", TIER05_SPEC_DRUID_HEALER = "恢复", TIER05_SPEC_DRUID_MELEE = "猎豹", TIER05_SPEC_DRUID_TANK = "熊" },
        zhTW = { TIER05_SPEC_WARRIOR_MELEE = "武器 / 狂怒", TIER05_SPEC_WARRIOR_TANK = "防護", TIER05_SPEC_PALADIN_MELEE = "懲戒", TIER05_SPEC_PALADIN_HEALER = "神聖", TIER05_SPEC_PALADIN_TANK = "防護", TIER05_SPEC_PRIEST_HEALER = "神聖", TIER05_SPEC_PRIEST_CASTER = "暗影", TIER05_SPEC_SHAMAN_CASTER = "元素", TIER05_SPEC_SHAMAN_HEALER = "恢復", TIER05_SPEC_SHAMAN_MELEE = "增強", TIER05_SPEC_DRUID_CASTER = "平衡", TIER05_SPEC_DRUID_HEALER = "恢復", TIER05_SPEC_DRUID_MELEE = "獵豹", TIER05_SPEC_DRUID_TANK = "熊" },
    }
    strings.esMX = strings.esES
    for locale, entries in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for key, value in pairs(entries) do
                if t[key] == nil then t[key] = value end
            end
        end
    end
end
local function Version(row, v)
    if v == 1 then return row.cells2, row.lab05, row.arrowC end
    row.extra = row.extra or {}
    local extra = row.extra[v]
    if not extra then
        extra = { cells = {} }
        for i = 1, 8 do extra.cells[i] = MakeCell(row) end
        extra.lab = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
        extra.lab:SetTextColor(1.00, 0.82, 0.27)
        extra.arrow = row:CreateTexture(nil, "ARTWORK")
        extra.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
        extra.arrow:SetSize(16, 16)
        extra.arrow:SetVertexColor(1, 0.82, 0.3)
        row.extra[v] = extra
    end
    return extra.cells, extra.lab, extra.arrow
end
-- t05bigicon (2.1.1, M 20 Nov 2026: "make the icon a bit bigger and more
-- centered below tier 0.5"): the spec icon is a small frame of its own
-- (centered under "Tier 0.5" in the detailed view, left of the arrow in
-- Compact view), made the first time; t05tip: hovered, the spec's name.
local function SpecIcon(row, v, token, role)
    local holder = v == 1 and row or row.extra[v]
    local f = holder.specIcon
    if not f then
        f = CreateFrame("Frame", nil, row)
        f.tex = f:CreateTexture(nil, "ARTWORK")
        f.tex:SetAllPoints()
        f.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        f:EnableMouse(true)
        f:SetScript("OnEnter", function(self)
            if not (GameTooltip and self.specKey) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L(self.specKey), 1, 1, 1)
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        holder.specIcon = f
    end
    f.tex:SetTexture("Interface\\Icons\\" .. SPEC_ICONS[token][role])
    f.specKey = "TIER05_SPEC_" .. token .. "_" .. role
    return f
end
local function HideVersions(row, from)
    if from <= 1 and row.specIcon then row.specIcon:Hide() end
    for v, extra in pairs(row.extra or {}) do
        if v >= from then
            for i = 1, 8 do extra.cells[i]:Hide() end
            extra.lab:Hide()
            extra.arrow:Hide()
            if extra.specIcon then extra.specIcon:Hide() end
        end
    end
end

-- One class's row: its label, then the eight pieces side by side, and the
-- Tier 0.5 pieces under them (tier05row).
local function FillRow(row, token, width, compact)
    local set, set2 = SETS[token], SETS2[token]
    local own = token == PlayerClass()
    local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[token]
    if c then
        row.classIcon:SetTexCoord(c[1], c[2], c[3], c[4])
        row.classIcon:Show()
    else
        row.classIcon:Hide()
    end
    row.classIcon:ClearAllPoints()
    row.label:ClearAllPoints()
    row.sub:ClearAllPoints()
    row.t05:ClearAllPoints()
    if compact then
        -- tiercompact: class over set name, left of the pieces
        row.classIcon:SetSize(24, 24)
        row.classIcon:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.label:SetPoint("BOTTOMLEFT", row.classIcon, "RIGHT", 6, 1)
        row.label:SetText(ClassName(token))
        row.sub:SetPoint("TOPLEFT", row.classIcon, "RIGHT", 6, -1)
        row.sub:SetWidth(LABEL_W - 36)
        row.sub:SetText(SetName(token))
        row.sub:Show()
        row.line:Hide()
        row.t05:Hide()
        row.lab0:Hide()
        row.lab05:Hide()
    else
        row.classIcon:SetSize(20, 20)
        row.classIcon:SetPoint("TOPLEFT", 2, 0)
        row.label:SetPoint("LEFT", row.classIcon, "RIGHT", 6, 0)
        row.label:SetText(ClassLabel(token))
        row.sub:Hide()
        row.line:Show()
        row.t05:SetPoint("RIGHT", row, "TOPRIGHT", -4, -10)
        row.t05:SetText(set2 and L("TIER05_LABEL", SetName(token, SETS2_NAME)) or "")
        row.t05:Show()
    end
    if compact then
        -- the Tier 0 pieces, an arrow, the Tier 0.5 pieces: all on one line
        local step = math.max(20, math.min(ICON_C + 4 + GAP_C, math.floor((width - LABEL_W - 26) / 16)))
        local gap = math.max(3, math.floor(step * 0.2))
        local size = step - 4 - gap
        local y = -math.floor((ROW_H_C - size - 4) / 2)
        -- t05forever: one version, on the same line; more, each on a line
        -- of its own under the Tier 0 pieces, its role left of the arrow
        local count = set2 and #set2 or 0
        for i = 1, 8 do
            local cell = row.cells[i]
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", row, "TOPLEFT", LABEL_W + (i - 1) * step, y)
            FillCell(cell, set[i], size, nil, true, Sources(set[i]), nil, own)
            cell:Show()
            row.arrows[i]:Hide()
            if count == 0 then row.cells2[i]:Hide() end
        end
        row.arrowC:Hide()
        -- t05left (2.1.1, M 20 Nov 2026: "way too much dead space ... move
        -- all the tier 0.5 to the left, so that it's close to the paladin
        -- icon"): several versions: each on a line of its own under the Tier
        -- 0 pieces, lined up with them, its spec icon and the arrow just left
        -- of it; the class's name beside the Tier 0 line.
        if count > 1 then
            row.classIcon:ClearAllPoints()
            row.classIcon:SetPoint("LEFT", row, "TOPLEFT", 2, y - math.floor((size + 4) / 2))
        end
        for v = 1, count do
            local cells, lab, arrow = Version(row, v)
            local yv = count > 1 and (y - v * ROW_H_C) or y
            local x0 = count > 1 and LABEL_W or (LABEL_W + 8 * step + 26)
            for i = 1, 8 do
                local cell2 = cells[i]
                cell2:ClearAllPoints()
                cell2:SetPoint("TOPLEFT", row, "TOPLEFT", x0 + (i - 1) * step, yv)
                FillCell(cell2, set2[v][i], size, nil, true, nil, PIECE_QUEST[i], own)
                cell2:Show()
            end
            arrow:ClearAllPoints()
            arrow:SetPoint("LEFT", row, "TOPLEFT", x0 - 24, yv - math.floor((size + 4) / 2))
            arrow:Show()
            lab:Hide()
            local role = set2[v].role
            if count > 1 and role and SPEC_ICONS[token] and SPEC_ICONS[token][role] then
                local spec = SpecIcon(row, v, token, role)
                local s = math.max(16, size - 6)
                spec:SetSize(s, s)
                spec:ClearAllPoints()
                spec:SetPoint("RIGHT", row, "TOPLEFT", x0 - 26, yv - math.floor((size + 4) / 2))
                spec:Show()
            elseif v == 1 and row.specIcon then
                row.specIcon:Hide()
            end
        end
        HideVersions(row, count + 1)
        if count == 0 and row.specIcon then row.specIcon:Hide() end
        local height = ROW_H_C * (count > 1 and (count + 1) or 1)
        row:SetSize(width, height)
        return height
    end
    row.arrowC:Hide()
    -- tierlabels (2.0.10, M 17 Nov 2026: "I want 0 and 0.5 to the left of the
    -- first item"): "Tier 0" and "Tier 0.5" in a column left of the pieces,
    -- level with their icons.
    local left = TIER_LABEL_W
    local cellW = math.max(56, math.floor((width - left - GAP * 7) / 8))
    row.lab0:ClearAllPoints()
    row.lab0:SetPoint("LEFT", row, "TOPLEFT", 2, -(32 + math.floor((ICON_SIZE + 4) / 2)))
    row.lab0:SetWidth(left - 6)
    row.lab0:SetText(L("TIER_0"))
    row.lab0:Show()
    local tallest = 0
    for i = 1, 8 do
        local cell = row.cells[i]
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", row, "TOPLEFT", left + (i - 1) * (cellW + GAP), -32)
        local h = FillCell(cell, set[i], ICON_SIZE, cellW, false, Sources(set[i]), nil, own)
        cell:Show()
        if h > tallest then tallest = h end
    end
    if not set2 then
        row.lab05:Hide()
        for i = 1, 8 do row.arrows[i]:Hide() row.cells2[i]:Hide() end
        HideVersions(row, 1)
        local height = 32 + tallest
        row:SetSize(width, height)
        return height
    end
    local arrowY = 32 + tallest + 2
    local y2 = arrowY + 18
    for i = 1, 8 do
        local arrow = row.arrows[i]
        arrow:ClearAllPoints()
        arrow:SetPoint("TOP", row, "TOPLEFT", left + (i - 1) * (cellW + GAP) + math.floor(cellW / 2), -arrowY)
        arrow:Show()
    end
    -- t05forever: each version's row under the one before, its role under
    -- "Tier 0.5" on the left
    for v, version in ipairs(set2) do
        local cells, lab = Version(row, v)
        local tallest2 = 0
        for i = 1, 8 do
            local cell2 = cells[i]
            cell2:ClearAllPoints()
            cell2:SetPoint("TOPLEFT", row, "TOPLEFT", left + (i - 1) * (cellW + GAP), -y2)
            local h = FillCell(cell2, version[i], ICON_SIZE, cellW, false, nil, PIECE_QUEST[i], own)
            cell2:Show()
            if h > tallest2 then tallest2 = h end
        end
        lab:ClearAllPoints()
        lab:SetJustifyH("LEFT")
        lab:SetText(L("TIER_05"))
        lab:Show()
        local icon = version.role and SPEC_ICONS[token] and SPEC_ICONS[token][version.role]
        if icon then
            -- t05bigicon: "Tier 0.5" level with the pieces' top, the icon
            -- centered under it
            lab:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -(y2 + 1))
            lab:SetWidth(0)
            local spec = SpecIcon(row, v, token, version.role)
            spec:SetSize(30, 30)
            spec:ClearAllPoints()
            spec:SetPoint("TOP", lab, "BOTTOM", 0, -3)
            spec:Show()
        else
            lab:SetPoint("LEFT", row, "TOPLEFT", 2, -(y2 + math.floor((ICON_SIZE + 4) / 2)))
            lab:SetWidth(left - 6)
            if v == 1 and row.specIcon then row.specIcon:Hide() end
        end
        y2 = y2 + tallest2 + (v < #set2 and ROW_GAP or 0)
    end
    HideVersions(row, #set2 + 1)
    row:SetSize(width, y2)
    return y2
end

-- tierclasses: the classes ticked in Show Classes, for this character (its
-- own class until changed; a class with no set: every class). The old "Show
-- all classes" tick carries over as every class.
local function SelectedClasses()
    ForeverDungeonJournalCharacterDB = ForeverDungeonJournalCharacterDB or {}
    local char = ForeverDungeonJournalCharacterDB
    if type(char.tierClasses) ~= "table" then
        char.tierClasses = {}
        local own, hasSet = OwnClass()
        local wasAll = ForeverDungeonJournalDB and ForeverDungeonJournalDB.tierAllClasses == true
        if wasAll or not hasSet then
            for _, token in ipairs(CLASS_ORDER) do char.tierClasses[token] = true end
        else
            char.tierClasses[own] = true
        end
    end
    for token in pairs(char.tierClasses) do
        if not SETS[token] then char.tierClasses[token] = nil end
    end
    if not next(char.tierClasses) then char.tierClasses[(OwnClass())] = true end
    return char.tierClasses
end
local function AllSelected(sel)
    for _, token in ipairs(CLASS_ORDER) do
        if not sel[token] then return false end
    end
    return true
end

local function Build(journal)
    local home = journal.homePanel
    -- The home page's own page, where the dungeon list is (under the row of
    -- icons and the line beneath them).
    panel = CreateFrame("Frame", "ForeverDungeonJournalTierPanel", home)
    panel:SetPoint("TOPLEFT", home, "TOPLEFT", 14, -62)
    panel:SetPoint("BOTTOMRIGHT", home, "BOTTOMRIGHT", -14, 12)
    panel:SetFrameLevel((home:GetFrameLevel() or 1) + 6)
    panel:EnableMouse(true)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 6, -4)
    panel.title:SetTextColor(1.00, 0.82, 0.27)

    -- tiercompact: Compact view, left of Show Classes (kept between sessions).
    -- tiercompactbutton (2.0.10, M 17 Nov 2026: "the compact view of the
    -- tier sets, the button I mean, to be the same button as the ones that
    -- we have for dungeons"): the boss and loot lists' Compact view /
    -- Detailed view button, not a tick box.
    panel.compact = CreateFrame("Button", nil, panel, "BackdropTemplate")
    panel.compact:SetSize(104, 20)
    panel.compact:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 9,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    panel.compact:SetBackdropColor(0.12, 0.10, 0.08, 0.95)
    panel.compact:SetBackdropBorderColor(0.52, 0.33, 0.11, 1)
    panel.compact.text = panel.compact:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    panel.compact.text:SetPoint("CENTER")
    panel.compact:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    panel.compact:SetScript("OnClick", function()
        ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
        ForeverDungeonJournalDB.tierCompact = not (ForeverDungeonJournalDB.tierCompact == true) or nil
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
        if panel.scroll.SetVerticalScroll then panel.scroll:SetVerticalScroll(0) end
        Refresh()
    end)

    -- tierclasses (M 17 Nov 2026: "Show Classes as a drop down menu, All at
    -- the top marking every class, then the classes with their class icon
    -- at the start"): which classes' sets are shown, per character (the
    -- character's own class until it is changed).
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    if FDJ.OwnFonts then FDJ.OwnFonts(b) end
    panel.classes = b
    b:SetSize(150, 22)
    b:SetText("")
    local caret = b:CreateTexture(nil, "OVERLAY")
    caret:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    caret:SetSize(12, 12)
    caret:SetPoint("RIGHT", b, "RIGHT", -7, -3)
    b.text = b:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    b.text:SetPoint("LEFT", b, "LEFT", 8, 0)
    b.text:SetPoint("RIGHT", caret, "LEFT", -2, 3)
    b.text:SetJustifyH("CENTER")
    b.text:SetWordWrap(false)

    local menu = CreateFrame("Frame", nil, b, "BackdropTemplate")
    b.menu = menu
    local MENU_GAP = 7
    local function RowY(i) return -5 - (i - 1) * 22 - ((i > 1) and MENU_GAP or 0) end
    menu:SetSize(180, (1 + #CLASS_ORDER) * 22 + 10 + MENU_GAP)
    menu:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 4, -4)
    menu:SetFrameStrata("TOOLTIP")
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    menu:SetBackdropColor(0.055, 0.05, 0.043, 0.99)
    menu:SetBackdropBorderColor(0.57, 0.43, 0.20, 1)
    do -- a thin line under All
        local line = menu:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(0.57, 0.43, 0.20, 0.6)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", 10, RowY(1) - 22 - math.floor(MENU_GAP / 2))
        line:SetPoint("TOPRIGHT", -10, RowY(1) - 22 - math.floor(MENU_GAP / 2))
    end
    menu:Hide()
    menu.options = {}
    local choices = { false }
    for _, token in ipairs(CLASS_ORDER) do choices[#choices + 1] = token end
    for i, token in ipairs(choices) do
        local option = CreateFrame("Button", nil, menu)
        option:SetPoint("TOPLEFT", 6, RowY(i))
        option:SetPoint("TOPRIGHT", -6, RowY(i))
        option:SetHeight(21)
        option:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        option.token = token or nil
        option.box = option:CreateTexture(nil, "ARTWORK")
        option.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
        option.box:SetSize(18, 18)
        option.box:SetPoint("LEFT", 4, 0)
        option.check = option:CreateTexture(nil, "OVERLAY")
        option.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        option.check:SetAllPoints(option.box)
        option.check:Hide()
        option.text = option:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
        if token then
            option.icon = option:CreateTexture(nil, "ARTWORK")
            option.icon:SetSize(16, 16)
            option.icon:SetPoint("LEFT", option.box, "RIGHT", 4, 0)
            option.icon:SetTexture(CLASS_ICONS)
            local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[token]
            if c then option.icon:SetTexCoord(c[1], c[2], c[3], c[4]) end
            option.text:SetPoint("LEFT", option.icon, "RIGHT", 5, 0)
        else
            option.text:SetPoint("LEFT", option.box, "RIGHT", 4, 0)
            option.text:SetTextColor(0.95, 0.83, 0.53)
        end
        option:SetScript("OnClick", function(self)
            local sel = SelectedClasses()
            if not self.token then
                -- All: every class; clicked again, back to the character's own
                if AllSelected(sel) then
                    for _, t in ipairs(CLASS_ORDER) do sel[t] = nil end
                    sel[(OwnClass())] = true
                else
                    for _, t in ipairs(CLASS_ORDER) do sel[t] = true end
                end
            elseif sel[self.token] then
                sel[self.token] = nil
                if not next(sel) then sel[self.token] = true end -- never none
            else
                sel[self.token] = true
            end
            if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
                pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end
            if panel.scroll.SetVerticalScroll then panel.scroll:SetVerticalScroll(0) end
            Refresh()
        end)
        menu.options[#menu.options + 1] = option
    end
    b:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
    b:SetScript("OnHide", function() menu:Hide() end)

    panel.scroll = CreateFrame("ScrollFrame", "ForeverDungeonJournalTierScroll", panel, "UIPanelScrollFrameTemplate")
    panel.scroll:SetPoint("TOPLEFT", 4, -34)
    panel.scroll:SetPoint("BOTTOMRIGHT", -22, 2)
    panel.content = CreateFrame("Frame", nil, panel.scroll)
    panel.content:SetSize(700, 1)
    panel.scroll:SetScrollChild(panel.content)
    panel.section = panel.content:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    panel.section:SetPoint("TOPLEFT", 2, -2)
    panel.section:SetTextColor(1.00, 0.82, 0.27)
    panel.rows = {}

    panel:SetScript("OnSizeChanged", function(self)
        if self:IsShown() then Refresh() end
    end)
    panel:SetScript("OnShow", function()
        HideList(journal)
        if PaintTabs then PaintTabs() end
    end)
    -- Back to the dungeon list: the list as it was.
    panel:SetScript("OnHide", function()
        if journal.homeScroll then journal.homeScroll:Show() end
        if journal.hideDungeonsButton then journal.hideDungeonsButton:Show() end
        if journal.homePanel:IsShown() and FDJ.RefreshHomeCards then pcall(FDJ.RefreshHomeCards) end
        if PaintTabs then PaintTabs() end
    end)
    -- Leaving the home page (a piece's boss page, a search...) closes it.
    home:HookScript("OnHide", function() panel:Hide() end)
    -- tierback: back on the home page: the boss page's way back is done
    home:HookScript("OnShow", function()
        tierReturn = nil
        if journal.fdjTierBack then journal.fdjTierBack:Hide() end
    end)

    -- Item names and the set's name arrive with the item data.
    local pending
    panel:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "BANKFRAME_OPENED", "QUEST_DATA_LOAD_RESULT" }) do
        pcall(panel.RegisterEvent, panel, event) -- tiercheck, tier05row
    end
    panel:SetScript("OnEvent", function(self)
        if pending or not self:IsVisible() then return end
        pending = true
        local function redraw()
            pending = nil
            if self:IsVisible() then Refresh() end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.3, redraw) else redraw() end
    end)
    panel:Hide()
    return panel
end

Refresh = function()
    if not panel then return end
    panel.title:SetText(L("TIER_TITLE"))
    panel.classes.text:SetText(L("TIER_SHOW_CLASSES"))
    panel.classes:ClearAllPoints()
    panel.classes:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -2)
    local compact = ForeverDungeonJournalDB and ForeverDungeonJournalDB.tierCompact == true or false
    panel.compact.text:SetText(L(compact and "LOOT_DETAILED" or "LOOT_COMPACT")) -- tiercompactbutton
    panel.compact:SetWidth(math.max(104, math.ceil((panel.compact.text:GetStringWidth() or 80) + 20)))
    panel.compact:ClearAllPoints()
    panel.compact:SetPoint("RIGHT", panel.classes, "LEFT", -12, 0)
    -- tierclasses: the ticked classes, the character's own first
    local own = OwnClass()
    local sel = SelectedClasses()
    local classes = {}
    if sel[own] then classes[1] = own end
    for _, token in ipairs(CLASS_ORDER) do
        if token ~= own and sel[token] then classes[#classes + 1] = token end
    end
    local all = AllSelected(sel)
    for _, option in ipairs(panel.classes.menu.options) do
        if option.token then
            option.text:SetText(ClassName(option.token))
            option.check:SetShown(sel[option.token] == true)
        else
            option.text:SetText(L("TIER_ALL"))
            option.check:SetShown(all)
        end
    end
    local width = math.max(500, math.floor((panel.scroll:GetWidth() or 760) - 4))
    panel.content:SetWidth(width)
    -- Tier 0 (the raid tiers will come under it).
    -- tierlabels (2.0.10): no "Tier 0" heading; the page says Tier Sets and
    -- each class's rows have Tier 0 / Tier 0.5 beside them.
    panel.section:SetText("")
    panel.section:Hide()
    local y = 4
    for i, token in ipairs(classes) do
        local row = panel.rows[i] or MakeRow(panel.content)
        panel.rows[i] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -y)
        y = y + FillRow(row, token, width, compact) + (compact and ROW_GAP_C or ROW_GAP)
        row:Show()
    end
    for i = #classes + 1, #panel.rows do panel.rows[i]:Hide() end
    panel.content:SetHeight(math.max(1, y))
    local bar = rawget(panel.scroll, "ScrollBar") or _G["ForeverDungeonJournalTierScrollScrollBar"]
    if type(bar) == "table" and bar.SetShown then bar:SetShown(y > (panel.scroll:GetHeight() or 0) + 1) end
end

local function ClickBack(f)
    if f and f.currentView ~= "home" and f.backButton then
        local back = f.backButton:GetScript("OnClick")
        if back then pcall(back, f.backButton) end
    end
end

function FDJ.OpenTierPage()
    local f = Journal()
    if FDJ.ToggleJournal and not (f and f:IsShown()) then pcall(FDJ.ToggleJournal) end
    f = Journal()
    if not (f and f.homePanel) then return end
    ClickBack(f)
    if not panel then Build(f) end
    if panel.scroll.SetVerticalScroll then panel.scroll:SetVerticalScroll(0) end
    panel:Show()
    Refresh()
    PaintTabs()
end

-- The WoW Forever emblem: the dungeon list.
function FDJ.ShowDungeonsTab()
    local f = Journal()
    if not f then return end
    if panel and panel:IsShown() then panel:Hide() end
    ClickBack(f)
    ApplyLayout()
end

-- --------------------------------------------------------------- the tabs
-- The page shown has its icon lit, as the WoW Forever emblem used to be
-- while it filtered the list: a gold ring and a brighter, larger glow.
local function Light(b, on)
    if not (b and b.halo) then return end
    local w = b:GetWidth() or 36
    if w < 1 then w = 36 end
    if not b.fdjTabRing then
        b.fdjTabRing = b:CreateTexture(nil, "BACKGROUND")
        b.fdjTabRing:SetTexture(RING)
        b.fdjTabRing:SetBlendMode("ADD")
        b.fdjTabRing:SetVertexColor(1, 0.82, 0.3, 0.95)
        b.fdjTabRing:SetPoint("CENTER")
    end
    local ring = math.floor(w * 1.92 + 0.5)
    b.fdjTabRing:SetSize(ring, ring)
    b.fdjTabRing:SetShown(on)
    if b.fdjPulseUntil then return end -- the Onyxia icon pulsing: left as it is
    local halo = math.floor(w * (on and 2.15 or 1.92) + 0.5)
    b.halo:SetSize(halo, halo)
    b.halo:SetAlpha(on and 1 or 0.75)
end

PaintTabs = function()
    local f = Journal()
    if not f then return end
    local tab = FDJ.ActiveHomeTab()
    Light(f.tierButton, tab == "tier")
    Light(f.onyxiaButton, tab == "onyxia")
    Light(f.sleepingBagButton, tab == "sleepingbag") -- bagtab
    if FDJ.PaintForeverEmblem then pcall(FDJ.PaintForeverEmblem) end
end
FDJ.PaintHomeTabs = function() PaintTabs() end

-- The row of icons: on the home page, and at the top of the Onyxia
-- Attunement page (in place of the Dungeons button, the page a little lower
-- to make room). They stay where they are anchored (the home page's top);
-- only their parent changes, so they show with the page.
local function Icons(f)
    return { f.foreverFilterButton, f.foreverRaidButton, f.sleepingBagButton, f.onyxiaButton, f.tierButton }
end
local function MoveIcons(f, parent)
    local icons = Icons(f)
    for i = 1, 5 do
        local b = icons[i]
        if b and b:GetParent() ~= parent then
            b:SetParent(parent)
            b:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)
        end
    end
end
local CONTENT_TOP, CONTENT_TOP_TABS = -90, -110
local function SetContentTop(f, y)
    if f.fdjContentTop == y then return end
    f.fdjContentTop = y
    f.contentPanel:ClearAllPoints()
    f.contentPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 18, y)
    f.contentPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 18)
end

-- tierback: the button (in the Dungeons button's place, as wide as its text)
local function TierBackButton(f)
    local b = f.fdjTierBack
    if b then return b end
    b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    if FDJ.OwnFonts then FDJ.OwnFonts(b) end
    f.fdjTierBack = b
    b:SetHeight(24)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 54, -54)
    if f.backButton then b:SetFrameLevel(f.backButton:GetFrameLevel() or 1) end
    b:SetScript("OnClick", function()
        local back = tierReturn
        tierReturn = nil
        b:Hide()
        FDJ.OpenTierPage()
        local offset = back and back.scroll or 0
        if offset > 0 and panel and panel.scroll and C_Timer and C_Timer.After then
            C_Timer.After(0.05, function()
                if panel:IsShown() and panel.scroll.SetVerticalScroll then pcall(panel.scroll.SetVerticalScroll, panel.scroll, offset) end
            end)
        end
    end)
    b:Hide()
    return b
end
local function UpdateTierBack(f, tabPage)
    local page = FDJ.GetSelectedDungeon and FDJ.GetSelectedDungeon()
    if tierReturn and tierReturn.armed and page ~= tierReturn.dungeon then tierReturn = nil end
    local active = tierReturn and tierReturn.armed and not tabPage and f.currentView ~= "home"
    if active then
        local b = TierBackButton(f)
        b:SetText(L("BACK_TO_TIERS"))
        local fs = b.GetFontString and b:GetFontString()
        if fs then fs:SetTextColor(1.00, 0.82, 0.27) end
        b:SetWidth(math.max(120, math.ceil(((fs and fs:GetStringWidth()) or 90) + 30)))
        b:Show()
        if f.backButton then f.backButton:Hide() end
        return
    end
    if f.fdjTierBack then f.fdjTierBack:Hide() end
    -- (a dungeon page always has its Dungeons button: it stayed hidden when
    -- the Onyxia or Sleeping Bag page had been the one open before)
    if not tabPage and f.currentView ~= "home" and f.backButton then f.backButton:Show() end
end

ApplyLayout = function()
    local f = Journal()
    if not (f and f.homePanel and f.contentPanel) then return end
    local tab = FDJ.ActiveHomeTab()
    if f.currentView ~= "home" and (tab == "onyxia" or tab == "sleepingbag") then -- (bagtab)
        local bar = f.fdjTabBar
        if not bar then
            bar = CreateFrame("Frame", nil, f)
            f.fdjTabBar = bar
            bar:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -52)
            bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -52)
            bar:SetHeight(60)
        end
        bar:SetFrameLevel((f.contentPanel:GetFrameLevel() or 1) + 40)
        bar:Show()
        MoveIcons(f, bar)
        if f.backButton then f.backButton:Hide() end
        SetContentTop(f, CONTENT_TOP_TABS)
        pcall(UpdateTierBack, f, true)
    else
        if f.currentView == "home" or f.fdjTabBar then MoveIcons(f, f.homePanel) end
        if f.fdjTabBar then f.fdjTabBar:Hide() end
        SetContentTop(f, CONTENT_TOP)
        pcall(UpdateTierBack, f, false)
    end
    if f.currentView == "home" and panel and panel:IsShown() then HideList(f) end
    PaintTabs()
end

-- Every dungeon page shown (Journal.lua calls this each time): the Onyxia
-- Attunement page gets the row of icons, any other the Dungeons button back.
local arrowsBefore = FDJ.UpdateDungeonArrows
FDJ.UpdateDungeonArrows = function(...)
    if arrowsBefore then arrowsBefore(...) end
    pcall(ApplyLayout)
end

-- The Onyxia icon: its page, or (lit) back to the dungeon list.
local onyxiaBefore = FDJ.OpenOnyxiaChain
if onyxiaBefore then
    FDJ.OpenOnyxiaChain = function(...)
        if FDJ.ActiveHomeTab() == "onyxia" then return end -- tabstay (2.0.13, M 18 Nov 2026: "if I double click it it auto jumps to the dungeon tab"): a lit tab clicked again stays; the WoW Forever emblem is the way back
        if panel and panel:IsShown() then panel:Hide() end
        return onyxiaBefore(...)
    end
end

-- bagtab: the Sleeping Bag icon the same: its page, or (lit) back to the
-- dungeon list.
local bagBefore = FDJ.OpenSleepingBagChain
if bagBefore then
    FDJ.OpenSleepingBagChain = function(...)
        if FDJ.ActiveHomeTab() == "sleepingbag" then return end -- tabstay
        if panel and panel:IsShown() then panel:Hide() end
        return bagBefore(...)
    end
end

-- -------------------------------------------------------------- the icon
local function Round(owner)
    local halo = owner:CreateTexture(nil, "BACKGROUND", nil, -1)
    halo:SetTexture(GLOW)
    halo:SetBlendMode("ADD")
    halo:SetVertexColor(1, 0.82, 0.35)
    halo:SetAlpha(0.75)
    local icon = owner:CreateTexture(nil, "ARTWORK")
    -- tiericonedge (2.0.10, M 17 Nov 2026: "this little white line at the
    -- top ... make it black, just like the rest of the circle"): the item
    -- icon's own light border is cut off, so only the picture is in the circle.
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if owner.CreateMaskTexture then
        local mask = owner:CreateMaskTexture()
        mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end
    return halo, icon
end

-- tierhide (2.0.10, M 17 Nov 2026: "We should always have a hide command ...
-- I want people to build their UI exactly how they want"): Options > Hide
-- Tier Sets (account-wide), and Hide on the icon's right-click, as the
-- Sleeping Bag and Onyxia icons.
-- tierlevel (2.0.10, M 17 Nov 2026: "I want the tier button to appear at
-- level 50 ... leave it hidden until then. And if people want to see it,
-- they can just go into options ... I don't want to overwhelm new players"):
-- below level 50 the icon is hidden (Options > Hide Tier Sets shows ticked);
-- unticking it there shows it at any level. Once ticked or unticked by the
-- player, that choice stays (account-wide).
local TIER_LEVEL = 50
function FDJ.IsTierIconHidden()
    local choice = ForeverDungeonJournalDB and ForeverDungeonJournalDB.hideTierSets
    if choice == true then return true end
    if choice == false then return false end
    local level = UnitLevel and tonumber(UnitLevel("player")) or 0
    return (level or 0) < TIER_LEVEL
end
function FDJ.SetTierIconHidden(hidden)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    ForeverDungeonJournalDB.hideTierSets = hidden and true or false
    if hidden and FDJ.ActiveHomeTab() == "tier" then FDJ.ShowDungeonsTab() end
    local f = Journal()
    if f and f.tierButton then f.tierButton:SetShown(not hidden) end
    if FDJ.RefreshSettingsChecks then pcall(FDJ.RefreshSettingsChecks) end
end
local hideMenu
local function ShowHideMenu(anchor)
    if not hideMenu then
        hideMenu = CreateFrame("Frame", "ForeverDungeonJournalTierMenu", UIParent, "BackdropTemplate")
        hideMenu:SetFrameStrata("FULLSCREEN_DIALOG")
        hideMenu:EnableMouse(true)
        hideMenu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        hideMenu:SetBackdropColor(0.055, 0.05, 0.043, 0.98)
        hideMenu:SetBackdropBorderColor(0.57, 0.43, 0.20, 1)
        local item = CreateFrame("Button", nil, hideMenu)
        item:SetPoint("TOPLEFT", 5, -5)
        item:SetPoint("RIGHT", -5, 0)
        item:SetHeight(20)
        item:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        item.text = item:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
        item.text:SetPoint("LEFT", 6, 0)
        item:SetScript("OnClick", function()
            hideMenu:Hide()
            FDJ.SetTierIconHidden(true)
            if FDJ.OpenSettingsAt then FDJ.OpenSettingsAt("OPT_HIDE_TIER") end
        end)
        hideMenu.hide = item
        hideMenu:SetScript("OnUpdate", function(self, elapsed)
            if self:IsMouseOver() or (self.fdjAnchor and self.fdjAnchor:IsMouseOver()) then
                self.fdjAway = 0
            else
                self.fdjAway = (self.fdjAway or 0) + elapsed
                if self.fdjAway > 0.6 then self:Hide() end
            end
        end)
    end
    hideMenu.hide.text:SetText(L("TIER_HIDE"))
    hideMenu:SetSize(math.max(110, (hideMenu.hide.text:GetStringWidth() or 0) + 24), 30)
    hideMenu.fdjAnchor = anchor
    hideMenu.fdjAway = 0
    hideMenu:ClearAllPoints()
    hideMenu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -2)
    hideMenu:Show()
    if GameTooltip then GameTooltip:Hide() end
end

local function BuildButton(frame)
    local home = frame.homePanel
    local b = CreateFrame("Button", nil, home)
    frame.tierButton = b
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp") -- tierhide
    b:SetSize(36, 36)
    b:SetFrameLevel(home:GetFrameLevel() + 5)
    b.halo, b.icon = Round(b)
    b.halo:SetPoint("CENTER")
    b.icon:SetPoint("CENTER")
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetTexture(MASK)
    b.hl:SetBlendMode("ADD")
    b.hl:SetAlpha(0.25)
    b.hl:SetPoint("CENTER")
    b:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.icon:ClearAllPoints()
        self.icon:SetPoint("CENTER", 1, -1)
    end)
    b:SetScript("OnMouseUp", function(self)
        self.icon:ClearAllPoints()
        self.icon:SetPoint("CENTER")
    end)
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then ShowHideMenu(self) return end -- tierhide
        if GameTooltip then GameTooltip:Hide() end
        if PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN) or 836) end -- tabsound (2.0.11): the journal's opening page sound
        if FDJ.ActiveHomeTab() ~= "tier" then FDJ.OpenTierPage() end -- tabstay: lit already: stays
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L("TIER_TITLE"), 1, 0.82, 0)
        GameTooltip:AddLine(L("TIER_ICON_TIP"), 1, 1, 1, true)
        GameTooltip:AddLine(L("TIER_HIDE_TIP"), 0.6, 0.6, 0.6) -- tierhide
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- Right of the Onyxia icon when it shows, else of the Sleeping Bag's, else
-- of the Raids medallion; the same size as theirs.
local placed
local function Place(frame, raid, size)
    if not frame or not frame.homePanel or not raid then return end
    placed = { frame, raid, size }
    local b = frame.tierButton or BuildButton(frame)
    size = size or 40
    local inner = math.floor(size * 0.9 + 0.5)
    b:SetSize(inner, inner)
    b.icon:SetSize(inner, inner)
    b.hl:SetSize(inner, inner)
    local glow = math.floor(inner * 1.92 + 0.5)
    b.halo:SetSize(glow, glow)
    local own = OwnClass()
    b.icon:SetTexture(ItemIcon(SETS[own][CHEST]))
    local onyxia, bag = frame.onyxiaButton, frame.sleepingBagButton
    local anchor = (onyxia and onyxia:IsShown()) and onyxia or ((bag and bag:IsShown()) and bag or raid)
    b:ClearAllPoints()
    b:SetPoint("LEFT", anchor, "RIGHT", size >= 40 and 12 or (size >= 30 and 10 or 8), 0)
    b:SetShown(not FDJ.IsTierIconHidden()) -- tierhide
    -- The Onyxia or Sleeping Bag icon shown or hidden later: move along.
    for _, other in pairs({ onyxia or false, bag or false }) do
        if other and not other.fdjTierHooked then
            other.fdjTierHooked = true
            local function Again() if placed then pcall(Place, placed[1], placed[2], placed[3]) end end
            other:HookScript("OnShow", Again)
            other:HookScript("OnHide", Again)
        end
    end
end

-- Systems/ForeverFilter.lua places the Sleeping Bag's icon (and, through
-- Systems/OnyxiaAttunement.lua, the Onyxia icon) after the Raids medallion
-- on every refresh of the home page; the Tier Sets icon follows them, and
-- the tabs are set again.
local PlaceBefore = FDJ.PlaceSleepingBagButton
FDJ.PlaceSleepingBagButton = function(frame, raid, size, ...)
    if PlaceBefore then pcall(PlaceBefore, frame, raid, size, ...) end
    pcall(Place, frame, raid, size)
    pcall(ApplyLayout)
end

-- tiersource (2.0.10): the "who drops it" hover: each boss that drops the
-- piece with its portrait (the journal's own), its name and its dungeon (the
-- first four; more: "+N more"); a Tier 0.5 piece: the quest that gives it.
do
    local tip
    local ROWS, PORTRAIT = 4, 46
    local function Build()
        tip = CreateFrame("Frame", "ForeverDungeonJournalTierSourceTip", UIParent, "BackdropTemplate")
        tip:SetFrameStrata("TOOLTIP")
        tip:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        tip:SetBackdropColor(0.03, 0.03, 0.04, 0.97)
        tip:SetBackdropBorderColor(0.57, 0.43, 0.20, 1)
        tip.rows = {}
        for i = 1, ROWS do
            local r = {}
            r.portrait = tip:CreateTexture(nil, "ARTWORK")
            r.portrait:SetSize(PORTRAIT, PORTRAIT)
            r.boss = tip:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
            r.boss:SetJustifyH("LEFT")
            r.dungeon = tip:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
            r.dungeon:SetJustifyH("LEFT")
            tip.rows[i] = r
        end
        tip.more = tip:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontDisableSmall")
        tip.more:SetJustifyH("LEFT")
        tip:Hide()
    end
    local function Clear()
        for _, r in ipairs(tip.rows) do
            if FDJ.ReleasePortrait then pcall(FDJ.ReleasePortrait, r.portrait) end
            r.portrait:SetTexture(nil)
            r.portrait:Hide()
            r.boss:Hide()
            r.dungeon:Hide()
        end
        tip.more:Hide()
    end
    function FDJ.HideTierSourceTip()
        if not tip then return end
        Clear()
        tip:Hide()
    end
    function FDJ.ShowTierSourceTip(owner, cell)
        if GameTooltip then GameTooltip:Hide() end
        if cell.questIndex then
            if not GameTooltip then return end
            GameTooltip:SetOwner(owner, "ANCHOR_TOP")
            GameTooltip:SetText("|TInterface\\GossipFrame\\AvailableQuestIcon:0|t " .. QuestTitle(cell.questIndex), 1, 0.82, 0)
            GameTooltip:AddLine(L("TIER_05"), 1, 1, 1)
            GameTooltip:Show()
            return
        end
        local sources = cell.sources or {}
        if #sources == 0 then return end
        if not tip then Build() end
        Clear()
        local y, widest = -10, 0
        for i = 1, math.min(ROWS, #sources) do
            local source, r = sources[i], tip.rows[i]
            local dungeon = FDJ.DB and FDJ.DB[source.dungeon]
            local boss = dungeon and dungeon.bosses and dungeon.bosses[source.index]
            r.portrait:ClearAllPoints()
            r.portrait:SetPoint("TOPLEFT", tip, "TOPLEFT", 10, y)
            local ok, shown = false, false
            if FDJ.SetBossPortrait and boss then ok, shown = pcall(FDJ.SetBossPortrait, r.portrait, source.dungeon, boss) end
            if not (ok and shown) then
                r.portrait:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
                r.portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            r.portrait:Show()
            local bossName, dungeonName = BossText(source)
            r.boss:SetText(bossName)
            r.boss:ClearAllPoints()
            r.boss:SetPoint("BOTTOMLEFT", r.portrait, "RIGHT", 10, 1)
            r.boss:Show()
            r.dungeon:SetText(dungeonName)
            r.dungeon:ClearAllPoints()
            r.dungeon:SetPoint("TOPLEFT", r.portrait, "RIGHT", 10, -2)
            r.dungeon:Show()
            widest = math.max(widest, r.boss:GetStringWidth() or 0, r.dungeon:GetStringWidth() or 0)
            y = y - PORTRAIT - 8
        end
        if #sources > ROWS then
            tip.more:SetText("+" .. (#sources - ROWS))
            tip.more:ClearAllPoints()
            tip.more:SetPoint("TOPLEFT", tip, "TOPLEFT", 12, y)
            tip.more:Show()
            y = y - 16
        end
        tip:SetSize(10 + PORTRAIT + 10 + math.ceil(widest) + 14, -y + 2)
        local scale = (owner.GetEffectiveScale and owner:GetEffectiveScale() or 1) / ((UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1)
        tip:SetScale(scale > 0 and scale or 1)
        tip:ClearAllPoints()
        tip:SetPoint("BOTTOM", owner, "TOP", 0, 4)
        tip:SetClampedToScreen(true)
        tip:Show()
    end
end

-- tierlevel: reaching level 50 shows the icon (when the player never chose)
do
    local watch = CreateFrame("Frame")
    watch:RegisterEvent("PLAYER_LEVEL_UP")
    watch:SetScript("OnEvent", function()
        local function again() if placed then pcall(Place, placed[1], placed[2], placed[3]) end end
        if C_Timer and C_Timer.After then C_Timer.After(1, again) else again() end
    end)
end
