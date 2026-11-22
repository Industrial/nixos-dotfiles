-- The Onyxia Attunement page (data: Data/QuestUpdates.lua, BEGIN
-- onyxiaattunement): a round Onyxia icon on the journal's home page, right
-- of the Cozy Sleeping Bag's (or of the Raids medallion when the bag's icon
-- is hidden), the same size and with the same soft golden glow, once the
-- character is level enough to start its faction's chain. Click: the
-- character's faction's attunement chain, unfolded at the step the
-- character is on (the whole chain done: its last quest); right-click: Hide
-- (Options > Show Onyxia Attunement brings it back, at any level). Reaching
-- that level pops the icon up on the screen, once per account. The page's title
-- is "Onyxia Attunement" in the journal's language (ATTUNE_ONYXIA, the
-- attunement tag's own string).
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local PAGE = FDJ.ONYXIA_PAGE
if not (PAGE and FDJ.DB and FDJ.DB[PAGE]) then return end

local ICON = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\OnyxiaAttuneIcon"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local GLOW = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\TickGlow"

do
    -- ATTUNE_ONYXIA already exists in English, German, French, Spanish,
    -- Italian and Portuguese (the attunement tag); the other languages and
    -- the icon's tooltip line.
    local strings = {
        enUS = { ATTUNE_ONYXIA = "Onyxia Attunement", ONYXIA_ICON_TIP = "The quest chain for the Drakefire Amulet, the key to Onyxia's Lair.",
            ONYXIA_POPUP = "You can now start Onyxia Attunement", ONYXIA_POPUP_CLICK = "Click to open it in the journal.",
            ONYXIA_HIDE = "Hide", ONYXIA_HIDE_TIP = "Right-click to hide",
            OPT_HIDE_ONYXIA = "Hide Onyxia Attunement", OPT_HIDE_ONYXIA_TIP = "Hides the Onyxia icon on the journal's home page (next to the Sleeping Bag's). It stays ticked until you can start the chain (level 48 Alliance, 55 Horde), then it unticks by itself and the icon shows. Untick it to see the icon sooner. You can also right-click the icon and pick Hide." },
        deDE = { ATTUNE_ONYXIA = "Onyxia-Einstimmung", ONYXIA_ICON_TIP = "Die Questreihe, um Onyxias Hort betreten zu dürfen.",
            ONYXIA_POPUP = "Du kannst jetzt die Onyxia-Einstimmung beginnen", ONYXIA_POPUP_CLICK = "Klicken, um sie im Journal zu öffnen.",
            ONYXIA_HIDE = "Ausblenden", ONYXIA_HIDE_TIP = "Rechtsklick zum Ausblenden",
            OPT_HIDE_ONYXIA = "Onyxia-Einstimmung ausblenden", OPT_HIDE_ONYXIA_TIP = "Blendet das Onyxia-Symbol auf der Startseite des Journals aus (neben dem des Schlafsacks). Es bleibt angehakt, bis du die Questreihe beginnen kannst (Stufe 48 Allianz, 55 Horde), dann hakt es sich von selbst ab und das Symbol erscheint. Abhaken, um es früher zu sehen. Geht auch per Rechtsklick auf das Symbol → Ausblenden." },
        frFR = { ATTUNE_ONYXIA = "Accès à Onyxia", ONYXIA_ICON_TIP = "La suite de quêtes pour entrer dans le repaire d'Onyxia.",
            ONYXIA_POPUP = "Vous pouvez maintenant commencer l'accès à Onyxia", ONYXIA_POPUP_CLICK = "Cliquez pour l'ouvrir dans le journal.",
            ONYXIA_HIDE = "Masquer", ONYXIA_HIDE_TIP = "Clic droit pour masquer",
            OPT_HIDE_ONYXIA = "Masquer l'accès à Onyxia", OPT_HIDE_ONYXIA_TIP = "Masque l'icône d'Onyxia sur la page d'accueil du journal (à côté de celle du sac de couchage). L'option reste cochée jusqu'à ce que vous puissiez commencer la suite (niveau 48 Alliance, 55 Horde), puis se décoche d'elle-même et l'icône apparaît. Décochez-la pour la voir plus tôt. Clic droit sur l'icône → Masquer fonctionne aussi." },
        esES = { ATTUNE_ONYXIA = "Sintonización de Onyxia", ONYXIA_ICON_TIP = "La cadena de misiones para entrar en la Guarida de Onyxia.",
            ONYXIA_POPUP = "Ya puedes empezar la sintonización de Onyxia", ONYXIA_POPUP_CLICK = "Haz clic para abrirla en el diario.",
            ONYXIA_HIDE = "Ocultar", ONYXIA_HIDE_TIP = "Clic derecho para ocultar",
            OPT_HIDE_ONYXIA = "Ocultar sintonización de Onyxia", OPT_HIDE_ONYXIA_TIP = "Oculta el icono de Onyxia en la página de inicio del diario (junto al del saco de dormir). Sigue marcada hasta que puedas empezar la cadena (nivel 48 Alianza, 55 Horda); entonces se desmarca sola y aparece el icono. Desmárcala para verlo antes. También puedes hacer clic derecho en el icono y elegir Ocultar." },
        itIT = { ATTUNE_ONYXIA = "Sintonia di Onyxia", ONYXIA_ICON_TIP = "La catena di missioni per entrare nella Tana di Onyxia.",
            ONYXIA_POPUP = "Ora puoi iniziare la sintonia di Onyxia", ONYXIA_POPUP_CLICK = "Clicca per aprirla nel diario.",
            ONYXIA_HIDE = "Nascondi", ONYXIA_HIDE_TIP = "Clic destro per nascondere",
            OPT_HIDE_ONYXIA = "Nascondi sintonia di Onyxia", OPT_HIDE_ONYXIA_TIP = "Nasconde l'icona di Onyxia nella pagina iniziale del diario (accanto a quella del sacco a pelo). Resta spuntata finché non puoi iniziare la catena (livello 48 Alleanza, 55 Orda), poi si toglie da sola e l'icona compare. Togli la spunta per vederla prima. Funziona anche il clic destro sull'icona → Nascondi." },
        ptBR = { ATTUNE_ONYXIA = "Sintonização de Onyxia", ONYXIA_ICON_TIP = "A sequência de missões para entrar no Covil da Onyxia.",
            ONYXIA_POPUP = "Agora você pode começar a sintonização de Onyxia", ONYXIA_POPUP_CLICK = "Clique para abri-la no diário.",
            ONYXIA_HIDE = "Ocultar", ONYXIA_HIDE_TIP = "Clique com o botão direito para ocultar",
            OPT_HIDE_ONYXIA = "Ocultar sintonização de Onyxia", OPT_HIDE_ONYXIA_TIP = "Oculta o ícone de Onyxia na página inicial do diário (ao lado do saco de dormir). Fica marcada até você poder começar a sequência (nível 48 Aliança, 55 Horda); aí se desmarca sozinha e o ícone aparece. Desmarque para vê-lo antes. Também dá para clicar com o botão direito no ícone e escolher Ocultar." },
        ruRU = { ATTUNE_ONYXIA = "Доступ к Ониксии", ONYXIA_ICON_TIP = "Цепочка заданий, чтобы войти в логово Ониксии.",
            ONYXIA_POPUP = "Теперь вы можете начать доступ к Ониксии", ONYXIA_POPUP_CLICK = "Нажмите, чтобы открыть в журнале.",
            ONYXIA_HIDE = "Скрыть", ONYXIA_HIDE_TIP = "Правый клик — скрыть",
            OPT_HIDE_ONYXIA = "Скрыть доступ к Ониксии", OPT_HIDE_ONYXIA_TIP = "Скрывает значок Ониксии на главной странице журнала (рядом со значком спального мешка). Отметка стоит, пока вы не сможете начать цепочку (48 уровень у Альянса, 55 у Орды), затем снимается сама и значок появляется. Снимите отметку, чтобы видеть его раньше. Можно также щёлкнуть по значку правой кнопкой и выбрать «Скрыть»." },
        koKR = { ATTUNE_ONYXIA = "오닉시아 입장 퀘스트", ONYXIA_ICON_TIP = "오닉시아의 둥지에 입장하기 위한 연계 퀘스트입니다.",
            ONYXIA_POPUP = "이제 오닉시아 입장 퀘스트를 시작할 수 있습니다", ONYXIA_POPUP_CLICK = "클릭하면 도감에서 열립니다.",
            ONYXIA_HIDE = "숨기기", ONYXIA_HIDE_TIP = "우클릭하여 숨기기",
            OPT_HIDE_ONYXIA = "오닉시아 입장 퀘스트 숨기기", OPT_HIDE_ONYXIA_TIP = "도감 첫 페이지의 오닉시아 아이콘을 숨깁니다(침낭 아이콘 옆). 연계 퀘스트를 시작할 수 있을 때까지(얼라이언스 48레벨, 호드 55레벨) 체크되어 있다가, 그 후 저절로 해제되고 아이콘이 나타납니다. 더 일찍 보려면 체크를 해제하세요. 아이콘을 우클릭하고 숨기기를 선택해도 됩니다." },
        zhCN = { ATTUNE_ONYXIA = "奥妮克希亚钥匙任务", ONYXIA_ICON_TIP = "进入奥妮克希亚的巢穴所需的系列任务。",
            ONYXIA_POPUP = "你现在可以开始奥妮克希亚钥匙任务了", ONYXIA_POPUP_CLICK = "点击在日志中打开。",
            ONYXIA_HIDE = "隐藏", ONYXIA_HIDE_TIP = "右键点击隐藏",
            OPT_HIDE_ONYXIA = "隐藏奥妮克希亚钥匙任务", OPT_HIDE_ONYXIA_TIP = "隐藏日志首页上的奥妮克希亚图标（位于睡袋图标旁）。在你可以开始系列任务之前（联盟48级，部落55级）会保持勾选，之后自动取消勾选并显示图标。取消勾选可提前显示。也可以右键点击图标并选择隐藏。" },
        zhTW = { ATTUNE_ONYXIA = "奧妮克希亞鑰匙任務", ONYXIA_ICON_TIP = "進入奧妮克希亞的巢穴所需的系列任務。",
            ONYXIA_POPUP = "你現在可以開始奧妮克希亞鑰匙任務了", ONYXIA_POPUP_CLICK = "點擊在日誌中開啟。",
            ONYXIA_HIDE = "隱藏", ONYXIA_HIDE_TIP = "右鍵點擊隱藏",
            OPT_HIDE_ONYXIA = "隱藏奧妮克希亞鑰匙任務", OPT_HIDE_ONYXIA_TIP = "隱藏日誌首頁上的奧妮克希亞圖示（位於睡袋圖示旁）。在你可以開始系列任務之前（聯盟48級，部落55級）會保持勾選，之後自動取消勾選並顯示圖示。取消勾選可提前顯示。也可以右鍵點擊圖示並選擇隱藏。" },
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

local function L(key)
    return FDJ.L and FDJ.L(key) or key
end
local function Plain(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
    return v
end

local baseName = FDJ.LocalizeDungeonName
FDJ.LocalizeDungeonName = function(name, ...)
    if name == PAGE then return L("ATTUNE_ONYXIA") end
    if baseName then return baseName(name, ...) end
    return name
end

local function Faction()
    if type(UnitFactionGroup) ~= "function" then return "Alliance" end
    local ok, faction = pcall(UnitFactionGroup, "player")
    faction = ok and Plain(faction) or nil
    return faction == "Horde" and "Horde" or "Alliance"
end

-- The page's level: where the character's faction's chain starts.
local function Resolve()
    FDJ.DB[PAGE].level = Faction() == "Horde" and "55+" or "48+"
end
Resolve()
do
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", Resolve)
end

-- The chain at the step the character is on (the first one not handed in).
function FDJ.OpenOnyxiaChain()
    if not FDJ.OpenQuestChain then return end
    local quest = FDJ.ONYXIA_QUESTS and FDJ.ONYXIA_QUESTS[Faction()]
    if not quest then return end
    local stepID
    for _, step in ipairs((FDJ.QUEST_PREREQ_CHAINS and FDJ.QUEST_PREREQ_CHAINS[quest]) or {}) do
        if type(step) == "table" and type(step.id) == "number"
            and not (FDJ.QuestTurnedIn and FDJ.QuestTurnedIn(step.id)) then
            stepID = step.id
            break
        end
    end
    FDJ.OpenQuestChain(PAGE, quest, stepID)
end

-- ---------------------------------------------------------- shown or not
-- 2.0.5: the icon comes with the level that starts the faction's chain (the
-- first step's required level: Dragonkin Menace 48, Blood and Thunder 55).
-- 2.0.6: Options > Show Onyxia Attunement (account-wide), and Hide on the
-- icon's right-click. showOnyxiaIcon: true = shown (ticked, at any level),
-- false = hidden (unticked, or Hide, at or above the level), nil = shown
-- once the level is reached (also what unticking below the level gives, 2.0.12).
local levelNow -- PLAYER_LEVEL_UP's new level (UnitLevel can still say the old one)
local function StartLevel()
    local quest = FDJ.ONYXIA_QUESTS and FDJ.ONYXIA_QUESTS[Faction()]
    local chain = quest and FDJ.QUEST_PREREQ_CHAINS and FDJ.QUEST_PREREQ_CHAINS[quest]
    local first = type(chain) == "table" and chain[1]
    local details = first and FDJ.QUEST_PREREQ_DETAILS and FDJ.QUEST_PREREQ_DETAILS[first.id]
    return tonumber(details and details.requires) or (Faction() == "Horde" and 55 or 48)
end
local function CanStart()
    local level = levelNow
    if not level and type(UnitLevel) == "function" then
        local ok, v = pcall(UnitLevel, "player")
        level = ok and tonumber(Plain(v)) or nil
    end
    return level ~= nil and level >= StartLevel()
end
FDJ.OnyxiaCanStart = CanStart

-- onyxiadone (2.0.13, M 18 Nov 2026: "just auto toggle hide once somebody is
-- attuned to Onyxia"): once the chain's last quest is handed in (the
-- Drakefire Amulet), the icon is hidden on that character (Options > Hide
-- Onyxia Attunement shows ticked). Unticking it there shows it again, on
-- that character.
local function Attuned()
    local quest = FDJ.ONYXIA_QUESTS and FDJ.ONYXIA_QUESTS[Faction()]
    if not (quest and FDJ.QuestTurnedIn) then return false end
    local ok, done = pcall(FDJ.QuestTurnedIn, quest)
    return ok and done and true or false
end
function FDJ.IsOnyxiaIconShown()
    if Attuned() then
        return ForeverDungeonJournalCharacterDB and ForeverDungeonJournalCharacterDB.showOnyxiaAttuned == true or false
    end
    local v = ForeverDungeonJournalDB and ForeverDungeonJournalDB.showOnyxiaIcon
    if v == true then return true end
    if v == false then return false end
    return CanStart()
end
FDJ.OnyxiaIconShown = FDJ.IsOnyxiaIconShown

-- -------------------------------------------------------------- the icon
local menu
local placed -- frame, raids medallion, size: the last placement
local Place

local function Replace()
    if placed then pcall(Place, placed[1], placed[2], placed[3]) end
end

function FDJ.SetOnyxiaIconShown(on)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    if Attuned() then -- onyxiadone: this character's own choice
        ForeverDungeonJournalCharacterDB = ForeverDungeonJournalCharacterDB or {}
        ForeverDungeonJournalCharacterDB.showOnyxiaAttuned = on and true or nil
        if menu then menu:Hide() end
        if not on and FDJ.StopOnyxiaPulse then FDJ.StopOnyxiaPulse() end
        Replace()
        return
    end
    -- untickbelow (2.0.12): unticking (or Hide) below the chain's level goes
    -- back to the default (nil: the icon comes, with its popup, on the ding)
    -- instead of hiding it for good, so a player who ticked it early just to
    -- look still gets it at the level. Only unticking at or above the level
    -- saves "hidden" (false).
    if on then
        ForeverDungeonJournalDB.showOnyxiaIcon = true
    elseif CanStart() then
        ForeverDungeonJournalDB.showOnyxiaIcon = false
    else
        ForeverDungeonJournalDB.showOnyxiaIcon = nil
    end
    if menu then menu:Hide() end
    if not on and FDJ.StopOnyxiaPulse then FDJ.StopOnyxiaPulse() end -- hidden at once
    Replace()
end

-- onyxiadone: the last quest handed in: the icon goes at once.
do
    local watch = CreateFrame("Frame")
    watch:RegisterEvent("QUEST_TURNED_IN")
    watch:SetScript("OnEvent", function(_, _, questID)
        local quest = FDJ.ONYXIA_QUESTS and FDJ.ONYXIA_QUESTS[Faction()]
        if not quest or tonumber(questID) ~= quest then return end
        if FDJ.StopOnyxiaPulse then pcall(FDJ.StopOnyxiaPulse) end
        if C_Timer and C_Timer.After then
            C_Timer.After(1, function()
                Replace()
                if FDJ.RefreshSettingsChecks then pcall(FDJ.RefreshSettingsChecks) end
            end)
        end
    end)
end

-- Right-click: a small menu with Hide (the same as the Sleeping Bag's).
-- Hide hides it and opens Options at Hide Onyxia Attunement (flashing),
-- so the player sees where it comes back from. (hideonyxia 2.0.15: the
-- option was "Show Onyxia Attunement"; it is now a Hide option like the
-- others, ticked by default until the chain's level.)
local function ShowMenu(anchor)
    if not menu then
        menu = CreateFrame("Frame", "ForeverDungeonJournalOnyxiaMenu", UIParent, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:EnableMouse(true)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        menu:SetBackdropColor(0.055, 0.05, 0.043, 0.98)
        menu:SetBackdropBorderColor(0.57, 0.43, 0.20, 1)
        local item = CreateFrame("Button", nil, menu)
        item:SetPoint("TOPLEFT", 5, -5)
        item:SetPoint("RIGHT", -5, 0)
        item:SetHeight(20)
        item:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        item.text = item:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
        item.text:SetPoint("LEFT", 6, 0)
        item:SetScript("OnClick", function()
            menu:Hide()
            FDJ.SetOnyxiaIconShown(false)
            if FDJ.OpenSettingsAt then FDJ.OpenSettingsAt("OPT_HIDE_ONYXIA") end
        end)
        menu.hide = item
        -- Closes on its own once the mouse has been away for a moment.
        menu:SetScript("OnUpdate", function(self, elapsed)
            if self:IsMouseOver() or (self.fdjAnchor and self.fdjAnchor:IsMouseOver()) then
                self.fdjAway = 0
            else
                self.fdjAway = (self.fdjAway or 0) + elapsed
                if self.fdjAway > 0.6 then self:Hide() end
            end
        end)
    end
    menu.hide.text:SetText(L("ONYXIA_HIDE"))
    menu:SetSize(math.max(110, (menu.hide.text:GetStringWidth() or 0) + 24), 30)
    menu.fdjAnchor = anchor
    menu.fdjAway = 0
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -2)
    menu:Show()
    if GameTooltip then GameTooltip:Hide() end
end

local function Round(owner, size)
    local halo = owner:CreateTexture(nil, "BACKGROUND", nil, -1)
    halo:SetTexture(GLOW)
    halo:SetBlendMode("ADD")
    halo:SetVertexColor(1, 0.82, 0.35)
    halo:SetAlpha(0.75)
    local icon = owner:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    if owner.CreateMaskTexture then
        local mask = owner:CreateMaskTexture()
        mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end
    return halo, icon
end

local function Build(frame)
    local home = frame.homePanel
    local b = CreateFrame("Button", nil, home)
    frame.onyxiaButton = b
    b:SetSize(36, 36)
    b:SetFrameLevel(home:GetFrameLevel() + 5)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
        if button == "RightButton" then
            ShowMenu(self)
            return
        end
        if GameTooltip then GameTooltip:Hide() end
        if PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN) or 836) end -- tabsound (2.0.11): the journal's opening page sound
        FDJ.OpenOnyxiaChain()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L("ATTUNE_ONYXIA"), 1, 0.82, 0)
        GameTooltip:AddLine(L("ONYXIA_ICON_TIP"), 1, 1, 1, true)
        GameTooltip:AddLine(L("ONYXIA_HIDE_TIP"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- Right of the Sleeping Bag's icon when it shows, else of the Raids medallion.
Place = function(frame, raid, size)
    if not frame or not frame.homePanel or not raid then return end
    placed = { frame, raid, size }
    local b = frame.onyxiaButton or Build(frame)
    size = size or 40
    local inner = math.floor(size * 0.9 + 0.5) -- as the Sleeping Bag's
    b:SetSize(inner, inner)
    b.icon:SetSize(inner, inner)
    b.hl:SetSize(inner, inner)
    local glow = math.floor(inner * 1.92 + 0.5)
    b.halo:SetSize(glow, glow)
    b.fdjInner, b.fdjGlow = inner, glow
    local bag = frame.sleepingBagButton
    local anchor = (bag and bag:IsShown()) and bag or raid
    b:ClearAllPoints()
    b:SetPoint("LEFT", anchor, "RIGHT", size >= 40 and 12 or (size >= 30 and 10 or 8), 0)
    b:SetShown(FDJ.IsOnyxiaIconShown() or (b.fdjPulseUntil ~= nil))
    -- The bag's icon hidden or shown later (Hide, the bag looted): move along.
    if bag and not bag.fdjOnyxiaHooked then
        bag.fdjOnyxiaHooked = true
        bag:HookScript("OnShow", Replace)
        bag:HookScript("OnHide", Replace)
    end
end

-- Systems/ForeverFilter.lua places the Sleeping Bag's icon after the Raids
-- medallion on every refresh of the home page; the Onyxia icon follows.
local PlaceBag = FDJ.PlaceSleepingBagButton
FDJ.PlaceSleepingBagButton = function(frame, raid, size, ...)
    if PlaceBag then pcall(PlaceBag, frame, raid, size, ...) end
    pcall(Place, frame, raid, size)
end

-- ------------------------------------------------- the icon, pointed out
-- The home page's icon glows and pulses for a few seconds, then goes back
-- to normal (the popup's click: "here it is").
local PULSE_TIME = 6
local pulser = CreateFrame("Frame")
pulser:Hide()
pulser:SetScript("OnUpdate", function(self, elapsed)
    local b = self.button
    if not b then self:Hide() return end
    self.t = (self.t or 0) + elapsed
    local inner, glow = b.fdjInner or 36, b.fdjGlow or 69
    if self.t >= PULSE_TIME then
        b.fdjPulseUntil = nil
        b.halo:SetAlpha(0.75)
        b.halo:SetSize(glow, glow)
        b.icon:SetSize(inner, inner)
        self:Hide()
        Replace() -- shown or not as usual again
        return
    end
    local wave = 0.5 + 0.5 * math.sin(self.t * 5)
    b.halo:SetAlpha(0.6 + 0.4 * wave)
    local g = glow * (1.05 + 0.3 * wave)
    b.halo:SetSize(g, g)
    local i = inner * (1 + 0.1 * wave)
    b.icon:SetSize(i, i)
end)
function FDJ.StopOnyxiaPulse()
    local b = pulser.button
    if b then
        b.fdjPulseUntil = nil
        b.halo:SetAlpha(0.75)
        b.halo:SetSize(b.fdjGlow or 69, b.fdjGlow or 69)
        b.icon:SetSize(b.fdjInner or 36, b.fdjInner or 36)
    end
    pulser:Hide()
end
function FDJ.PulseOnyxiaIcon()
    local journal = _G.ForeverDungeonJournalFrame
    local b = journal and journal.onyxiaButton
    if not b then return end
    -- Not hidden by the player: shown while it pulses even before the level
    -- (only the dev test gets there that early).
    local hidden = ForeverDungeonJournalDB and ForeverDungeonJournalDB.showOnyxiaIcon == false
    if hidden then return end
    b.fdjPulseUntil = PULSE_TIME
    b:Show()
    pulser.button = b
    pulser.t = 0
    pulser:Show()
end

-- ----------------------------------------------------- the level-up popup
-- 2.0.6: reaching the level that starts the chain pops up the Onyxia icon
-- with "You can now start Onyxia Attunement", above the game's "You've
-- Reached Level" banner. 2.0.7: the message stays still (easier to read)
-- for 10 seconds; only the red arrow pointing at the icon comes and goes,
-- as on the journal's other popups; the icon has its golden glow, as on the
-- home page. Clicking it opens the journal on its home page, where the
-- Onyxia icon glows and pulses for 6 seconds. Right-click closes it.
-- Not when the player hid the icon (Options, or Hide).
local POPUP_TIME = 10
local ARROW = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\QuestPrevArrow"
local popup

local function OpenHome()
    local journal = _G.ForeverDungeonJournalFrame
    if FDJ.ToggleJournal and not (journal and journal:IsShown()) then pcall(FDJ.ToggleJournal) end
    journal = _G.ForeverDungeonJournalFrame
    if not journal then return end
    -- Back to the dungeon list (the journal's own Dungeons button).
    if journal.currentView ~= "home" and journal.backButton then
        local back = journal.backButton:GetScript("OnClick")
        if back then pcall(back, journal.backButton) end
    end
    pcall(FDJ.PulseOnyxiaIcon)
end

local function BuildPopup()
    local p = CreateFrame("Button", "ForeverDungeonJournalOnyxiaPopup", UIParent, "BackdropTemplate")
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetClampedToScreen(true)
    p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    p:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    p:SetBackdropColor(0, 0, 0, 0.92)
    p:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    -- The icon: its own button, with the home page icon's golden glow.
    local icon = CreateFrame("Button", nil, p)
    icon:SetSize(40, 40)
    icon:SetPoint("LEFT", 12, 0)
    icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    icon.halo, icon.icon = Round(icon)
    icon.icon:SetSize(40, 40)
    icon.icon:SetPoint("CENTER")
    icon.halo:SetSize(77, 77)
    icon.halo:SetPoint("CENTER")
    icon.hl = icon:CreateTexture(nil, "HIGHLIGHT")
    icon.hl:SetTexture(MASK)
    icon.hl:SetBlendMode("ADD")
    icon.hl:SetAlpha(0.25)
    icon.hl:SetSize(40, 40)
    icon.hl:SetPoint("CENTER")
    p.iconButton = icon
    -- The red arrow pointing at the icon: comes and goes, nudging toward it.
    p.arrow = p:CreateTexture(nil, "OVERLAY")
    p.arrow:SetTexture(ARROW)
    p.arrow:SetVertexColor(1, 0.12, 0.08)
    p.arrow:SetSize(24, 24)
    p.arrow:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    p.text = p:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightLarge")
    p.text:SetPoint("TOPLEFT", icon, "TOPRIGHT", 36, -3)
    p.text:SetTextColor(1, 1, 1)
    p.text:SetShadowColor(0, 0, 0, 1)
    p.text:SetShadowOffset(1, -1)
    p.hint = p:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontDisableSmall")
    p.hint:SetPoint("TOPLEFT", p.text, "BOTTOMLEFT", 0, -4)
    p:SetScript("OnUpdate", function(self, elapsed)
        self.t = (self.t or 0) + elapsed
        if self.t >= POPUP_TIME then
            self:Hide()
            return
        end
        -- The message itself stays still: in over 0.3 s, out over the last 0.6 s.
        self:SetAlpha(math.min(1, self.t / 0.3, (POPUP_TIME - self.t) / 0.6))
        local wave = math.sin(self.t * 4)
        self.arrow:SetAlpha(0.55 + 0.45 * wave)
        self.arrow:SetPoint("LEFT", self.iconButton, "RIGHT", 4 - 3 * math.abs(wave), 0)
    end)
    local function Click(_, button)
        p:Hide()
        if button ~= "LeftButton" then return end
        OpenHome()
    end
    p:SetScript("OnClick", Click)
    icon:SetScript("OnClick", Click)
    p:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.82, 0.35, 1) end)
    p:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) end)
    icon:SetScript("OnEnter", function() p:SetBackdropBorderColor(1, 0.82, 0.35, 1) end)
    icon:SetScript("OnLeave", function() p:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) end)
    p:Hide()
    return p
end

function FDJ.ShowOnyxiaPopup()
    popup = popup or BuildPopup()
    popup.text:SetText(L("ONYXIA_POPUP"))
    popup.hint:SetText(L("ONYXIA_POPUP_CLICK"))
    local w = math.max(popup.text:GetStringWidth() or 0, popup.hint:GetStringWidth() or 0)
    popup:SetSize(math.max(280, w + 110), 64)
    popup:ClearAllPoints()
    -- Above the game's "You've Reached Level" banner.
    popup:SetPoint("TOP", UIParent, "TOP", 0, -100)
    popup.t = 0
    popup:SetAlpha(0)
    popup:Show()
end

-- A level gained: the icon comes up at once on the home page, and reaching
-- the chain's level pops it up on the screen.
-- popuponce (2.0.11): the popup comes only on the ding itself (never at login,
-- so a character already past that level when the addon is installed or
-- updated never gets it), and only once per account: the first character to
-- ding the level shows it, then onyxiaPopupSeen (account-wide) stops it for
-- every other character.
do
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:SetScript("OnEvent", function(_, _, level)
        levelNow = tonumber(Plain(level))
        Replace()
        if FDJ.RefreshSettingsChecks then pcall(FDJ.RefreshSettingsChecks) end
        local db = ForeverDungeonJournalDB
        local hidden = db and db.showOnyxiaIcon == false
        local seen = db and db.onyxiaPopupSeen == true
        if levelNow and levelNow == StartLevel() and not hidden and not seen then
            ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
            ForeverDungeonJournalDB.onyxiaPopupSeen = true
            pcall(FDJ.ShowOnyxiaPopup)
        end
    end)
end

