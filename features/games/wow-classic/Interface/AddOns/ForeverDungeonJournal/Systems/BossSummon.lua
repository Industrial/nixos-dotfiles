-- Bosses that have to be summoned with an item (boss.summonItem = itemID).
-- The boss page shows "Summon with: [item]" under the boss name, in the
-- quest list's font; hovering it shows the item and how to get it.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local LABEL = {
    enUS = "Summon with:", deDE = "Beschwören mit:", frFR = "Invoquer avec :",
    esES = "Invocar con:", itIT = "Evoca con:", ptBR = "Invocar com:",
    ruRU = "Призвать с помощью:", koKR = "소환 아이템:", zhCN = "召唤物品：", zhTW = "召喚物品：",
}
-- Bosses that come during a quest (boss.spawnQuest = { quest = id, page =
-- dungeon }): "Spawns at the end of ? <quest>", the quest clickable.
local SPAWN_LABEL = {
    enUS = "Spawns at the end of", deDE = "Erscheint am Ende von", frFR = "Apparaît à la fin de",
    esES = "Aparece al final de", itIT = "Compare alla fine di", ptBR = "Aparece no fim de",
    ruRU = "Появляется в конце задания", koKR = "등장 시점: 퀘스트 끝", zhCN = "出现于任务结尾：", zhTW = "出現於任務結尾：",
}
local QUEST_ICON = "Interface\\GossipFrame\\ActiveQuestIcon"
-- An item whose quest chain the journal has (boss.summonChain): the extra
-- line under its tooltip.
local CLICK_QUEST = {
    enUS = "Click to show quest", deDE = "Klicken, um die Quest anzuzeigen", frFR = "Cliquez pour afficher la quête",
    esES = "Haz clic para ver la misión", itIT = "Clicca per mostrare la missione", ptBR = "Clique para ver a missão",
    ruRU = "Нажмите, чтобы показать задание", koKR = "클릭하여 퀘스트 보기", zhCN = "点击查看任务", zhTW = "點擊查看任務",
}
local HOWTO_TITLE = {
    enUS = "How to get it", deDE = "So bekommt ihr es", frFR = "Comment l'obtenir",
    esES = "Cómo conseguirlo", itIT = "Come ottenerlo", ptBR = "Como obter",
    ruRU = "Как получить", koKR = "획득 방법", zhCN = "获取方法", zhTW = "取得方法",
}

-- How to get each summoning item, per language.
local HOWTO = {
    [275989] = { -- Tome of Dalaran
        enUS = {
            "1. Loot the Black Tome from the table behind Archmage Arugal at the end of Shadowfang Keep.",
            "2. Use the Black Tome next to the Ambermill Leyline Focus (the floating blue crystal in the Ambermill town hall, Silverpine Forest 63.4, 64.3). It turns into the Tome of Dalaran.",
            "3. Bring the Tome of Dalaran into the City of Dalaran to summon Lyn the Ignored.",
        },
        deDE = {
            "1. Nehmt den Schwarzen Foliant vom Tisch hinter Erzmagier Arugal am Ende der Burg Schattenfang.",
            "2. Benutzt ihn neben dem Leylinienfokus von Ambermühle (der schwebende blaue Kristall im Rathaus von Ambermühle, Silberwald 63.4, 64.3). Er wird zum Foliant von Dalaran.",
            "3. Bringt den Foliant von Dalaran in die Stadt Dalaran, um Lyn the Ignored zu beschwören.",
        },
        frFR = {
            "1. Récupérez le Tome noir sur la table derrière l'archimage Arugal, au fond du donjon d'Ombrecroc.",
            "2. Utilisez-le près du focalisateur tellurique d'Amberdine (le cristal bleu flottant dans l'hôtel de ville d'Amberdine, forêt des Pins-Argentés 63.4, 64.3). Il devient le Tome de Dalaran.",
            "3. Apportez le Tome de Dalaran dans la Cité de Dalaran pour invoquer Lyn the Ignored.",
        },
        esES = {
            "1. Coge el Tomo negro de la mesa detrás del archimago Arugal, al final del Castillo de Colmillo Oscuro.",
            "2. Úsalo junto al foco de línea ley de Molino Ámbar (el cristal azul flotante en el ayuntamiento de Molino Ámbar, Bosque de Argénteos 63.4, 64.3). Se convierte en el Tomo de Dalaran.",
            "3. Lleva el Tomo de Dalaran a la Ciudad de Dalaran para invocar a Lyn the Ignored.",
        },
        itIT = {
            "1. Prendi il Tomo Nero dal tavolo dietro l'Arcimago Arugal, alla fine della Rocca di Zannascura.",
            "2. Usalo vicino al Focus di Linea Magica di Mulino d'Ambra (il cristallo blu fluttuante nel municipio di Mulino d'Ambra, Selva Pinargento 63.4, 64.3). Diventa il Tomo di Dalaran.",
            "3. Porta il Tomo di Dalaran nella Città di Dalaran per evocare Lyn the Ignored.",
        },
        ptBR = {
            "1. Pegue o Tomo Negro na mesa atrás do Arquimago Arugal, no fim da Bastilha da Presa Negra.",
            "2. Use-o perto do Foco da Linha Ley de Moinho Âmbar (o cristal azul flutuante na prefeitura de Moinho Âmbar, Floresta de Pinhaprata 63.4, 64.3). Ele vira o Tomo de Dalaran.",
            "3. Leve o Tomo de Dalaran para a Cidade de Dalaran para invocar Lyn the Ignored.",
        },
        ruRU = {
            "1. Заберите Чёрный фолиант со стола за верховным магом Аругалом в конце Крепости Темного Клыка.",
            "2. Используйте его рядом с фокусом лей-линии Янтарной мельницы (парящий синий кристалл в ратуше Янтарной мельницы, Серебряный бор 63.4, 64.3). Он превратится в Фолиант Даларана.",
            "3. Принесите Фолиант Даларана в город Даларан, чтобы призвать Lyn the Ignored.",
        },
        koKR = {
            "1. 그림자송곳니 성채 끝, 대마법사 아루갈 뒤의 탁자에서 검은 고서를 획득하세요.",
            "2. 호박색 방앗간 마을회관의 떠 있는 파란 수정(은빛소나무 숲 63.4, 64.3) 옆에서 사용하면 달라란의 고서가 됩니다.",
            "3. 달라란의 고서를 달라란 도시로 가져가 Lyn the Ignored를 소환하세요.",
        },
        zhCN = {
            "1. 在影牙城堡尽头、大法师阿鲁高身后的桌子上拾取黑色典籍。",
            "2. 在安伯米尔镇公所的漂浮蓝色水晶（银松森林 63.4, 64.3）旁使用它，它会变成达拉然典籍。",
            "3. 把达拉然典籍带进达拉然城来召唤 Lyn the Ignored。",
        },
        zhTW = {
            "1. 在影牙城堡盡頭、大法師阿魯高身後的桌上拾取黑色典籍。",
            "2. 在安伯米爾鎮公所的漂浮藍色水晶（銀松森林 63.4, 64.3）旁使用它，它會變成達拉然典籍。",
            "3. 把達拉然典籍帶進達拉然城來召喚 Lyn the Ignored。",
        },
    },
}
local FALLBACK_NAMES = { [275989] = "Tome of Dalaran", [9240] = "Mallet of Zul'Farrak" }

local function Lang()
    local lang = FDJ.GetLanguage and FDJ.GetLanguage() or "enUS"
    return lang
end

local function Pick(t)
    if type(t) ~= "table" then return nil end
    return t[Lang()] or t.enUS
end

local function ItemData(id)
    local name, link, quality, icon
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if getInfo then
        local ok, n, l, q, _, _, _, _, _, _, tex = pcall(getInfo, id)
        if ok then name, link, quality, icon = n, l, q, tex end
    end
    if not icon and C_Item and C_Item.GetItemIconByID then
        local ok, tex = pcall(C_Item.GetItemIconByID, id)
        if ok then icon = tex end
    end
    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, id)
    end
    return name or FALLBACK_NAMES[id] or ("Item " .. id), link, quality, icon or "Interface\\Icons\\INV_Misc_Book_04"
end

local button

-- The quest list's look: QuestFont, the font of a quest's name in the list
-- (and of its "Available from Level" line), in the dungeon theme's colours.
local function QuestListStyle(fs, color)
    local font = _G.ForeverDJ_QuestFont or _G.ForeverDJ_GameFontNormal
    if font and fs.SetFontObject then fs:SetFontObject(font) end
    if type(color) == "table" and color[1] then
        fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
end

-- The lines under the item tooltip. An item the client has not cached yet
-- (the Tome of Dalaran on the first hover) shows "Retrieving item
-- information" and is rebuilt once its data arrives, which wiped the lines
-- added after SetHyperlink. They are now put back every time the tooltip
-- is built while the summon button owns it.
local function Marker(self)
    if HOWTO[self.itemID] then return Pick(HOWTO_TITLE) end
    if self.chain then return Pick(CLICK_QUEST) end
end

local function HasLine(tooltip, text)
    local name = tooltip.GetName and tooltip:GetName()
    if not name or not text then return false end
    for i = 1, (tooltip:NumLines() or 0) do
        local fs = _G[name .. "TextLeft" .. i]
        local t = fs and fs:GetText()
        if t ~= nil and not (type(issecretvalue) == "function" and issecretvalue(t)) and t == text then
            return true
        end
    end
    return false
end

local function AddSummonLines(tooltip, self)
    local marker = Marker(self)
    if not marker or HasLine(tooltip, marker) then return false end
    if FDJ.AddUnseenItemHint then pcall(FDJ.AddUnseenItemHint, tooltip) end
    local steps = Pick(HOWTO[self.itemID])
    if steps then
        tooltip:AddLine(" ")
        tooltip:AddLine(Pick(HOWTO_TITLE), 1, 0.82, 0)
        for _, line in ipairs(steps) do tooltip:AddLine(line, 1, 1, 1, true) end
    end
    if self.chain then
        tooltip:AddLine(" ")
        tooltip:AddLine(Pick(CLICK_QUEST), 0.35, 1.00, 0.35)
    end
    return true
end

local function OwnsTooltip(tooltip)
    return button and button.itemID and button:IsShown() and tooltip == GameTooltip
        and tooltip.GetOwner and tooltip:GetOwner() == button
end

local function ResizeSoon()
    if not (C_Timer and C_Timer.After) then return end
    C_Timer.After(0, function()
        if OwnsTooltip(GameTooltip) and GameTooltip:IsShown() then GameTooltip:Show() end
    end)
end

local function OnItemTooltip(tooltip)
    if not OwnsTooltip(tooltip) then return end
    if AddSummonLines(tooltip, button) then ResizeSoon() end
end

local hooked = false
local function InstallHooks()
    if hooked or not GameTooltip then return end
    hooked = true
    local viaProcessor = false
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        viaProcessor = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item,
            function(tooltip) pcall(OnItemTooltip, tooltip) end)
    end
    if not viaProcessor and GameTooltip.HookScript then
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", function(tooltip) pcall(OnItemTooltip, tooltip) end)
    end
    -- And once the item's data has arrived, show the whole tooltip again.
    local watcher = CreateFrame("Frame")
    for _, event in ipairs({ "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT" }) do
        pcall(watcher.RegisterEvent, watcher, event)
    end
    watcher:SetScript("OnEvent", function(_, _, itemID)
        if not button or tonumber(itemID) ~= button.itemID or not OwnsTooltip(GameTooltip) then return end
        if not (C_Timer and C_Timer.After) then return end
        C_Timer.After(0, function()
            if OwnsTooltip(GameTooltip) and button:IsMouseOver() then
                local onEnter = button:GetScript("OnEnter")
                if onEnter then pcall(onEnter, button) end
            end
        end)
    end)
end

local function Create(frame)
    local anchor = frame.selectedBossName
    local parent = anchor and anchor:GetParent()
    if not parent then return nil end
    InstallHooks()
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(18)
    -- "Summon with:" and the item name in the quest list's font.
    b.label = b:CreateFontString(nil, "OVERLAY")
    QuestListStyle(b.label)
    b.label:SetPoint("LEFT", b, "LEFT", 0, 0)
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", b.label, "RIGHT", 5, 0)
    b.name = b:CreateFontString(nil, "OVERLAY")
    QuestListStyle(b.name)
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
    b:SetScript("OnEnter", function(self)
        if GameTooltip and self.questID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.name:GetText() or "", 1, 0.82, 0)
            GameTooltip:AddLine(Pick(CLICK_QUEST), 0.35, 1.00, 0.35)
            GameTooltip:Show()
            return
        end
        if not GameTooltip or not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local _, link = ItemData(self.itemID)
        local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link or ("item:" .. self.itemID))
        if not ok then GameTooltip:AddLine(ItemData(self.itemID), 0, 0.44, 0.87) end
        -- The item hook may already have added them (HasLine skips them then).
        AddSummonLines(GameTooltip, self)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnClick", function(self)
        if self.questID then
            if GameTooltip then GameTooltip:Hide() end
            if FDJ.OpenQuestPage then FDJ.OpenQuestPage(self.questPage, self.questID) end
            return
        end
        -- Shift-click links the item in chat, like any item button.
        if IsModifiedClick and IsModifiedClick("CHATLINK") and self.itemID then
            local _, link = ItemData(self.itemID)
            if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
            return
        end
        -- The item's quest chain (the Mallet of Zul'Farrak), at the step not
        -- done yet.
        local chain = self.chain
        if chain and FDJ.OpenQuestChain then
            local stepID
            for _, step in ipairs((FDJ.QUEST_PREREQ_CHAINS and FDJ.QUEST_PREREQ_CHAINS[chain.quest]) or {}) do
                if type(step) == "table" and step.id and not (FDJ.QuestTurnedIn and FDJ.QuestTurnedIn(step.id)) then
                    stepID = step.id
                    break
                end
            end
            if GameTooltip then GameTooltip:Hide() end
            FDJ.OpenQuestChain(chain.page, chain.quest, stepID)
        end
    end)
    return b
end

function FDJ.UpdateBossSummon(frame, boss, theme)
    local id = boss and tonumber(boss.summonItem)
    local spawn = boss and type(boss.spawnQuest) == "table" and tonumber(boss.spawnQuest.quest) and boss.spawnQuest or nil
    if not id and not spawn then
        if button then button:Hide() end
        return
    end
    button = button or Create(frame)
    if not button then return end
    if spawn then
        local qid = tonumber(spawn.quest)
        local qname
        for _, q in ipairs((FDJ.DB and FDJ.DB[spawn.page] and FDJ.DB[spawn.page].quests) or {}) do
            if q.id == qid then qname = q.name break end
        end
        if FDJ.LocalizeQuestField then
            local ok, loc = pcall(FDJ.LocalizeQuestField, qid, "name", qname)
            if ok and type(loc) == "string" and loc ~= "" then qname = loc end
        end
        button.itemID, button.chain = nil, nil
        button.questID, button.questPage = qid, spawn.page
        button.label:SetText(Pick(SPAWN_LABEL))
        button.icon:SetTexture(QUEST_ICON)
        button.name:SetText(qname or ("#" .. qid))
        theme = type(theme) == "table" and theme or {}
        QuestListStyle(button.label, theme.muted or { 0.80, 0.72, 0.56 })
        QuestListStyle(button.name, theme.title or { 1.00, 0.82, 0.00 })
        button:ClearAllPoints()
        local below = (frame.selectedBossType and frame.selectedBossType:IsShown()) and frame.selectedBossType or frame.selectedBossName
        button:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -4)
        button:SetWidth((button.label:GetStringWidth() or 60) + 25 + (button.name:GetStringWidth() or 100))
        button:Show()
        return
    end
    button.questID, button.questPage = nil, nil
    local name, _, _, icon = ItemData(id)
    button.itemID = id
    button.chain = type(boss.summonChain) == "table" and boss.summonChain or nil
    button.label:SetText(Pick(LABEL))
    button.icon:SetTexture(icon)
    button.name:SetText(name)
    -- Like a quest in the list: "Summon with:" in the colour of its
    -- "Available from Level" line, the item in the selected quest's gold.
    theme = type(theme) == "table" and theme or {}
    QuestListStyle(button.label, theme.muted or { 0.80, 0.72, 0.56 })
    QuestListStyle(button.name, theme.title or { 1.00, 0.82, 0.00 })
    button:ClearAllPoints()
    local below = (frame.selectedBossType and frame.selectedBossType:IsShown()) and frame.selectedBossType or frame.selectedBossName
    button:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -4)
    button:SetWidth((button.label:GetStringWidth() or 60) + 25 + (button.name:GetStringWidth() or 100))
    button:Show()
end
