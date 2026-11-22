-- Favourites: persistent item favourites plus a home-page popup.
-- Boss-loot rows can be right-clicked to add/remove items.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local function L(key, ...)
    if FDJ.L then return FDJ.L(key, ...) end
    return key
end

-- Interface strings. Keep these local to the feature so older locale files do
-- not need to know about favourites before this module loads.
do
    local strings = {
        enUS = {
            FAVOURITES = "Favourites", FAVOURITES_EMPTY = "Right Click on items you want to see as favourites.",
            FAV_ADD_ITEM = "Add to Favourites", FAV_REMOVE_ITEM = "Remove from Favourites",
            FAV_REMOVE_HINT = "Left click to view source. Right click to remove from favourites",
        },
        deDE = {
            FAVOURITES = "Favoriten", FAVOURITES_EMPTY = "Rechtsklicke auf Gegenstände, die du als Favoriten sehen möchtest.",
            FAV_ADD_ITEM = "Zu Favoriten hinzufügen", FAV_REMOVE_ITEM = "Aus Favoriten entfernen",
            FAV_REMOVE_HINT = "Linksklick: Quelle anzeigen. Rechtsklick: aus Favoriten entfernen",
        },
        frFR = {
            FAVOURITES = "Favoris", FAVOURITES_EMPTY = "Faites un clic droit sur les objets à ajouter aux favoris.",
            FAV_ADD_ITEM = "Ajouter aux favoris", FAV_REMOVE_ITEM = "Retirer des favoris",
            FAV_REMOVE_HINT = "Clic gauche : voir la source. Clic droit : retirer des favoris",
        },
        esES = {
            FAVOURITES = "Favoritos", FAVOURITES_EMPTY = "Haz clic derecho en los objetos que quieras ver como favoritos.",
            FAV_ADD_ITEM = "Añadir a favoritos", FAV_REMOVE_ITEM = "Quitar de favoritos",
            FAV_REMOVE_HINT = "Clic izquierdo: ver fuente. Clic derecho: quitar de favoritos",
        },
        esMX = {
            FAVOURITES = "Favoritos", FAVOURITES_EMPTY = "Haz clic derecho en los objetos que quieras ver como favoritos.",
            FAV_ADD_ITEM = "Añadir a favoritos", FAV_REMOVE_ITEM = "Quitar de favoritos",
            FAV_REMOVE_HINT = "Clic izquierdo: ver fuente. Clic derecho: quitar de favoritos",
        },
        itIT = {
            FAVOURITES = "Preferiti", FAVOURITES_EMPTY = "Clicca con il tasto destro sugli oggetti che vuoi vedere tra i preferiti.",
            FAV_ADD_ITEM = "Aggiungi ai preferiti", FAV_REMOVE_ITEM = "Rimuovi dai preferiti",
            FAV_REMOVE_HINT = "Clic sinistro: mostra fonte. Clic destro: rimuovi dai preferiti",
        },
        ptBR = {
            FAVOURITES = "Favoritos", FAVOURITES_EMPTY = "Clique com o botão direito nos itens que deseja ver como favoritos.",
            FAV_ADD_ITEM = "Adicionar aos favoritos", FAV_REMOVE_ITEM = "Remover dos favoritos",
            FAV_REMOVE_HINT = "Clique esquerdo: ver origem. Clique direito: remover dos favoritos",
        },
        ruRU = {
            FAVOURITES = "Избранное", FAVOURITES_EMPTY = "Щёлкните правой кнопкой по предметам, которые хотите видеть в избранном.",
            FAV_ADD_ITEM = "Добавить в избранное", FAV_REMOVE_ITEM = "Удалить из избранного",
            FAV_REMOVE_HINT = "ЛКМ: показать источник. ПКМ: удалить из избранного",
        },
        koKR = {
            FAVOURITES = "즐겨찾기", FAVOURITES_EMPTY = "즐겨찾기에 표시할 아이템을 우클릭하세요.",
            FAV_ADD_ITEM = "즐겨찾기에 추가", FAV_REMOVE_ITEM = "즐겨찾기에서 제거",
            FAV_REMOVE_HINT = "좌클릭: 획득처 보기. 우클릭: 즐겨찾기에서 제거",
        },
        zhCN = {
            FAVOURITES = "收藏", FAVOURITES_EMPTY = "右键点击想要加入收藏的物品。",
            FAV_ADD_ITEM = "添加到收藏", FAV_REMOVE_ITEM = "从收藏中移除",
            FAV_REMOVE_HINT = "左键：查看来源。右键：从收藏中移除",
        },
        zhTW = {
            FAVOURITES = "最愛", FAVOURITES_EMPTY = "右鍵點擊想要加入最愛的物品。",
            FAV_ADD_ITEM = "加入最愛", FAV_REMOVE_ITEM = "從最愛移除",
            FAV_REMOVE_HINT = "左鍵：查看來源。右鍵：從最愛中移除",
        },
    }
    for locale, entries in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for key, value in pairs(entries) do
                if t[key] == nil then t[key] = value end
            end
        end
    end
end

local FAVOURITE_STAR = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\FavouriteStar"
local trackedLootRows = setmetatable({}, { __mode = "k" })

local function SetStar(texture)
    texture:SetTexture(FAVOURITE_STAR)
    texture:SetTexCoord(0, 1, 0, 1)
end

local function GetDB()
    -- Favourites are intentionally per-character. Do not read or migrate the
    -- old account-wide favouriteItems table: each character starts and keeps
    -- its own independent list.
    ForeverDungeonJournalCharacterDB = ForeverDungeonJournalCharacterDB or {}
    ForeverDungeonJournalCharacterDB.favouriteItems = ForeverDungeonJournalCharacterDB.favouriteItems or {}
    return ForeverDungeonJournalCharacterDB.favouriteItems
end

local function ItemKey(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end
    return tostring(itemID)
end

function FDJ.IsFavouriteItem(itemID)
    local key = ItemKey(itemID)
    return key and GetDB()[key] ~= nil or false
end

local function RefreshTrackedRows()
    for row in pairs(trackedLootRows) do
        if row and row.fdjFavouriteItemID and row.fdjFavouriteStar then
            if FDJ.IsFavouriteItem(row.fdjFavouriteItemID) then row.fdjFavouriteStar:Show() else row.fdjFavouriteStar:Hide() end
        end
    end
end

function FDJ.UpdateFavouriteIndicator(row, itemID)
    if not row then return end
    trackedLootRows[row] = true
    row.fdjFavouriteItemID = tonumber(itemID)
    if not row.fdjFavouriteStar then
        local star = row:CreateTexture(nil, "OVERLAY", nil, 6)
        row.fdjFavouriteStar = star
        star:SetSize(15, 15)
        star:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        SetStar(star)
    end
    if FDJ.IsFavouriteItem(itemID) then row.fdjFavouriteStar:Show() else row.fdjFavouriteStar:Hide() end
end

local function AddFavourite(item, dungeonName, bossName, quest)
    if type(item) ~= "table" then return end
    local key = ItemKey(item[1])
    if not key then return end
    GetDB()[key] = {
        id = tonumber(item[1]),
        name = item[2],
        slot = item[3],
        quality = item[4],
        dungeon = dungeonName,
        boss = bossName,
        -- Quest items: the quest they come from (no boss).
        questID = type(quest) == "table" and tonumber(quest.id) or nil,
        questName = type(quest) == "table" and quest.name or nil,
        added = time and time() or nil,
    }
    RefreshTrackedRows()
end

local function RemoveFavourite(itemID)
    local key = ItemKey(itemID)
    if not key then return end
    GetDB()[key] = nil
    RefreshTrackedRows()
end

local function SortedFavourites()
    local list = {}
    for _, fav in pairs(GetDB()) do
        if type(fav) == "table" and tonumber(fav.id) then list[#list + 1] = fav end
    end

    local dungeonOrder = {}
    for index, dungeonName in ipairs(FDJ.ORDER or {}) do
        dungeonOrder[dungeonName] = index
    end

    table.sort(list, function(a, b)
        local ad, bd = tostring(a.dungeon or ""), tostring(b.dungeon or "")
        if ad ~= bd then
            local ai = dungeonOrder[ad] or 100000
            local bi = dungeonOrder[bd] or 100000
            if ai ~= bi then return ai < bi end
            return ad < bd
        end
        local an, bn = tostring(a.name or ""), tostring(b.name or "")
        if an == bn then return (a.id or 0) < (b.id or 0) end
        return an < bn
    end)
    return list
end

local function ItemIcon(itemID)
    if C_Item and C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok and icon then return icon end
    end
    if GetItemIcon then
        local ok, icon = pcall(GetItemIcon, itemID)
        if ok and icon then return icon end
    end
    return 134400
end

local function ItemName(fav)
    if GetItemInfo then
        local ok, name = pcall(GetItemInfo, fav.id)
        if ok and name then return name end
    end
    return fav.name or ("Item " .. tostring(fav.id))
end

local requestedItemData = {}

local function ItemColor(fav)
    local quality = tonumber(fav.quality)
    local link

    if GetItemInfo then
        local ok, _, itemLink, q = pcall(GetItemInfo, fav.id)
        if ok then
            link = itemLink
            if q ~= nil then quality = q end
        end
    end

    -- Boss loot rows already use the rendered in-game tooltip as the source
    -- of truth because Forever can return stale Classic-era quality metadata.
    -- Use that exact resolver here too so colours always match.
    if FDJ.GetAuthoritativeItemQuality then
        return FDJ.GetAuthoritativeItemQuality(fav.id, link, quality, fav.quality)
    end

    if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        local c = ITEM_QUALITY_COLORS[quality]
        return c.r or 1, c.g or 1, c.b or 1
    end
    return 1, 0.82, 0
end

local function ShowItemTooltip(owner, itemID, hint)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then
        pcall(GameTooltip.SetItemByID, GameTooltip, itemID)
    elseif GetItemInfo then
        local _, link = GetItemInfo(itemID)
        if link then GameTooltip:SetHyperlink(link) end
    end
    if FDJ.AddUnseenItemHint then FDJ.AddUnseenItemHint(GameTooltip) end
    if hint then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(hint, 0.75, 0.75, 0.75, true)
    end
    GameTooltip:Show()
end

local function EnsureFallbackMenu()
    if FDJ.favouriteContextMenu then return FDJ.favouriteContextMenu end
    local menu = CreateFrame("Frame", "ForeverDungeonJournalFavouriteContextMenu", UIParent, "BackdropTemplate")
    FDJ.favouriteContextMenu = menu
    menu:SetSize(190, 30)
    menu:SetFrameStrata("TOOLTIP")
    menu:SetClampedToScreen(true)
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    menu:SetBackdropColor(0.055, 0.045, 0.035, 0.98)
    menu:SetBackdropBorderColor(0.52, 0.42, 0.24, 1)
    local button = CreateFrame("Button", nil, menu)
    menu.button = button
    button:SetPoint("TOPLEFT", 4, -4)
    button:SetPoint("BOTTOMRIGHT", -4, 4)
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    button.text = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    button.text:SetPoint("LEFT", 9, 0)
    button.text:SetPoint("RIGHT", -8, 0)
    button.text:SetJustifyH("LEFT")
    menu:Hide()
    return menu
end

local function RefreshOpenWindow()
    local frame = FDJ.frame or _G.ForeverDungeonJournalFrame
    if frame and frame.favouritesWindow and frame.favouritesWindow:IsShown() and FDJ.RefreshFavouritesWindow then
        FDJ.RefreshFavouritesWindow(frame.favouritesWindow)
    end
end


local function IsMouseOverFavouriteMenu()
    if MouseIsOver then
        local fallback = FDJ.favouriteContextMenu
        if fallback and fallback:IsShown() then
            -- Check both the container and the actual action button. Some WoW
            -- clients do not report MouseIsOver(parent) reliably when only a
            -- child button has mouse input enabled.
            if MouseIsOver(fallback) then return true end
            if fallback.button and fallback.button:IsShown() and MouseIsOver(fallback.button) then return true end
        end

        -- Kept for compatibility if Blizzard dropdowns are ever used again.
        for level = 1, 4 do
            local list = _G["DropDownList" .. level]
            if list and list:IsShown() and MouseIsOver(list) then return true end
        end
    end
    return false
end

function FDJ.HideItemFavouriteMenu()
    if CloseDropDownMenus then CloseDropDownMenus() end
    if FDJ.favouriteContextMenu then FDJ.favouriteContextMenu:Hide() end
    if FDJ.favouriteMenuDismissWatcher then FDJ.favouriteMenuDismissWatcher:Hide() end
end

local function ArmFavouriteMenuDismiss()
    local watcher = FDJ.favouriteMenuDismissWatcher
    if not watcher then
        watcher = CreateFrame("Frame", nil, UIParent)
        FDJ.favouriteMenuDismissWatcher = watcher
        watcher:Hide()
        watcher:SetScript("OnUpdate", function(self)
            local left = IsMouseButtonDown and IsMouseButtonDown("LeftButton")
            local right = IsMouseButtonDown and IsMouseButtonDown("RightButton")
            local middle = IsMouseButtonDown and IsMouseButtonDown("MiddleButton")
            local anyDown = left or right or middle

            -- The menu is opened on RightButtonUp. Wait for that opening click
            -- to be fully released before listening for the next click.
            if not self.fdjArmed then
                if not anyDown then
                    self.fdjArmed = true
                    self.fdjSawDown = false
                end
                return
            end

            -- IMPORTANT: never hide the menu on mouse-down. Hiding a Button
            -- between OnMouseDown and OnMouseUp prevents its OnClick callback,
            -- which is why Add/Remove previously looked clickable but did
            -- nothing. Let the click finish first, then dismiss on release if
            -- it happened outside the menu.
            if anyDown then
                self.fdjSawDown = true
                return
            end

            if self.fdjSawDown then
                self.fdjSawDown = false
                if not IsMouseOverFavouriteMenu() then
                    FDJ.HideItemFavouriteMenu()
                end
            end
        end)
    end
    watcher.fdjArmed = false
    watcher.fdjSawDown = false
    watcher:Show()
end

function FDJ.ShowItemFavouriteMenu(owner, item, dungeonName, bossName, quest)
    if not owner or type(item) ~= "table" or not item[1] then return end
    FDJ.HideItemFavouriteMenu()
    local itemID = tonumber(item[1])
    local isFav = FDJ.IsFavouriteItem(itemID)
    local label = L(isFav and "FAV_REMOVE_ITEM" or "FAV_ADD_ITEM")

    -- Use our own compact context menu instead of EasyMenu. Blizzard's
    -- dropdown frames can close on mouse-down before their button callback
    -- fires when our click-away watcher is active, which made "Remove from
    -- Favourites" appear clickable but do nothing. The custom menu lets the
    -- click land on the action first, while still dismissing on clicks away.
    local menu = EnsureFallbackMenu()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 4, -2)
    if owner.GetFrameLevel then
        menu:SetFrameLevel(math.max(menu:GetFrameLevel() or 1, (owner:GetFrameLevel() or 1) + 20))
    end
    menu.button.text:SetText(label)
    menu.button:SetScript("OnClick", function()
        if isFav then
            RemoveFavourite(itemID)
        else
            AddFavourite(item, dungeonName, bossName, quest)
        end
        FDJ.HideItemFavouriteMenu()
        RefreshOpenWindow()
    end)
    menu:Show()
    ArmFavouriteMenuDismiss()
end

local function OpenFavouriteSource(fav)
    if type(fav) ~= "table" or not fav.dungeon or not fav.id then return end
    local dungeon = FDJ.DB and FDJ.DB[fav.dungeon]
    if not dungeon then return end

    -- Quest item: jump to its quest instead of a boss page.
    if fav.questID then
        FDJ.HideItemFavouriteMenu()
        if FDJ.OpenQuestPage then FDJ.OpenQuestPage(fav.dungeon, fav.questID) end
        return
    end

    local bossIndex
    for i, boss in ipairs(dungeon.bosses or {}) do
        if boss and boss.name == fav.boss then
            bossIndex = i
            break
        end
    end
    if not bossIndex then return end

    local frame = FDJ.frame or _G.ForeverDungeonJournalFrame
    -- Keep the Favourites window open while jumping to the item's source.
    -- This lets players click through several favourites without reopening it.
    FDJ.HideItemFavouriteMenu()

    if FDJ.OpenBossPage then
        FDJ.OpenBossPage(fav.dungeon, bossIndex)
    end
    if FDJ.FocusBossLootItem then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.05, function() FDJ.FocusBossLootItem(fav.id) end)
        else
            FDJ.FocusBossLootItem(fav.id)
        end
    end
end

local function CreateFavouriteRow(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(48)
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    row:SetBackdropColor(0.12, 0.095, 0.065, 0.92)
    row:SetBackdropBorderColor(0.42, 0.33, 0.20, 1)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(34, 34)
    row.icon:SetPoint("LEFT", 8, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -4)
    row.name:SetPoint("RIGHT", -8, 0)
    row.name:SetJustifyH("LEFT")

    row.slot = row:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    row.slot:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.slot:SetPoint("RIGHT", -8, 0)
    row.slot:SetJustifyH("LEFT")
    row.slot:SetTextColor(0.68, 0.62, 0.52)

    -- "Obtained" look: the same green frame and tick the journal puts on a
    -- completed quest.
    row.completeGlow = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.completeGlow:SetPoint("TOPLEFT", -2, 2)
    row.completeGlow:SetPoint("BOTTOMRIGHT", 2, -2)
    row.completeGlow:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    row.completeGlow:SetBackdropColor(0.05, 0.35, 0.08, 0.16)
    row.completeGlow:SetBackdropBorderColor(0.12, 1.00, 0.25, 0.90)
    row.completeGlow:EnableMouse(false)
    row.completeGlow:Hide()

    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    row.check:SetSize(22, 22)
    row.check:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.check:Hide()

    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetScript("OnEnter", function(self)
        if self.fdjItemID then ShowItemTooltip(self, self.fdjItemID, L("FAV_REMOVE_HINT")) end
    end)
    row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    row:SetScript("OnClick", function(self, button)
        if not self.fdjItemID then return end
        if button == "RightButton" then
            local fake = { self.fdjItemID, self.fdjStoredName, self.fdjStoredSlot, self.fdjStoredQuality }
            local quest = self.fdjQuestID and { id = self.fdjQuestID, name = self.fdjQuestName } or nil
            FDJ.ShowItemFavouriteMenu(self, fake, self.fdjDungeon, self.fdjBoss, quest)
        elseif button == "LeftButton" then
            OpenFavouriteSource({
                id = self.fdjItemID,
                dungeon = self.fdjDungeon,
                boss = self.fdjBoss,
                questID = self.fdjQuestID,
            })
        end
    end)
    return row
end

local function CreateDungeonDivider(parent)
    local divider = CreateFrame("Frame", nil, parent)
    divider:SetHeight(28)

    divider.lineLeft = divider:CreateTexture(nil, "ARTWORK")
    divider.lineLeft:SetColorTexture(0.54, 0.39, 0.17, 0.72)
    divider.lineLeft:SetHeight(1)
    divider.lineLeft:SetPoint("LEFT", 2, 0)

    divider.title = divider:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    divider.title:SetPoint("CENTER", divider, "CENTER", 0, 0)
    divider.title:SetTextColor(1.00, 0.82, 0.27)
    divider.title:SetJustifyH("CENTER")

    divider.lineRight = divider:CreateTexture(nil, "ARTWORK")
    divider.lineRight:SetColorTexture(0.54, 0.39, 0.17, 0.72)
    divider.lineRight:SetHeight(1)
    divider.lineRight:SetPoint("RIGHT", -2, 0)

    divider.lineLeft:SetPoint("RIGHT", divider.title, "LEFT", -8, 0)
    divider.lineRight:SetPoint("LEFT", divider.title, "RIGHT", 8, 0)
    return divider
end

local function CreateWindow(frame)
    local win
    for _, template in ipairs({ "ButtonFrameTemplate", "PortraitFrameTemplate", "BasicFrameTemplateWithInset" }) do
        local ok, created = pcall(CreateFrame, "Frame", "ForeverDungeonJournalFavourites", UIParent, template)
        if ok and created then win = created break end
    end
    if not win then
        win = CreateFrame("Frame", "ForeverDungeonJournalFavourites", UIParent, "BackdropTemplate")
        win:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        win:SetBackdropColor(0.08, 0.07, 0.06, 0.97)
        win:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
    end

    -- Use the standard Blizzard red X. Prefer the one the frame template
    -- already provides; otherwise create a stock UIPanelCloseButton.
    local close = win.CloseButton or win.closeButton
        or (win.TitleContainer and win.TitleContainer.CloseButton)
        or (win.BorderBox and win.BorderBox.CloseButton)
    if not close then
        close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -3, -3)
    end
    win.fdjCloseButton = close
    close:EnableMouse(true)
    close:SetAlpha(1)
    close:Show()

    -- The stock handler closes through HideUIPanel, which the client blocks
    -- in combat. Replace it with a plain Hide() on our own (unprotected)
    -- window so the X works in and out of combat.
    close:SetScript("OnClick", function()
        if FDJ.HideItemFavouriteMenu then FDJ.HideItemFavouriteMenu() end
        win:Hide()
    end)

    win:HookScript("OnShow", function()
        -- Same size as the journal (it can be resized with its corner grip).
        if FDJ.SyncPopupScale then pcall(FDJ.SyncPopupScale) end
        close:EnableMouse(true)
        close:SetAlpha(1)
        close:Show()
    end)

    frame.favouritesWindow = win
    win:SetSize(338, 424)
    win:SetPoint("CENTER", UIParent, "CENTER", -260, 20)
    -- One layer above the journal (DIALOG): in the same layer the journal's
    -- deeply nested boss rows and portraits draw on top of this popup.
    win:SetFrameStrata("FULLSCREEN_DIALOG")
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    if UISpecialFrames then tinsert(UISpecialFrames, "ForeverDungeonJournalFavourites") end

    local title = win.TitleText or (win.TitleContainer and win.TitleContainer.TitleText)
    if not title then
        title = win:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
        title:SetPoint("TOP", 0, -6)
    end
    win.fdjTitle = title
    FDJ.OwnFonts(title) -- ownfonts (2.0.8): the window template's title text

    local portrait = win.portrait or (win.PortraitContainer and win.PortraitContainer.portrait)
    if portrait then
        -- The favourite star itself has transparent space around it. Put a
        -- dark circular portrait backing underneath so the world/UI does not
        -- show through the empty parts of the star icon.
        local portraitParent = portrait:GetParent() or win
        local starBackground = portraitParent:CreateTexture(nil, "BACKGROUND")
        win.fdjStarBackground = starBackground
        starBackground:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        starBackground:SetVertexColor(0.10, 0.075, 0.035, 1)
        starBackground:SetSize(58, 58)
        starBackground:SetPoint("CENTER", portrait, "CENTER", 0, 0)
        starBackground:Show()

        SetStar(portrait)
        portrait:SetTexCoord(0, 1, 0, 1)
    else
        local starHolder = CreateFrame("Frame", nil, win)
        starHolder:SetSize(38, 38)
        starHolder:SetPoint("RIGHT", title, "LEFT", -6, 0)

        local starBackground = starHolder:CreateTexture(nil, "BACKGROUND")
        win.fdjStarBackground = starBackground
        starBackground:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        starBackground:SetVertexColor(0.10, 0.075, 0.035, 1)
        starBackground:SetAllPoints(starHolder)

        local star = starHolder:CreateTexture(nil, "OVERLAY")
        star:SetSize(32, 32)
        star:SetPoint("CENTER")
        SetStar(star)
    end

    local inset = win.Inset or win
    local scroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
    win.fdjScroll = scroll
    scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -27, 8)

    -- UIPanelScrollFrameTemplate exposes this on most clients. Keep a fallback
    -- scan for Forever builds where the field name differs.
    win.fdjScrollBar = scroll.ScrollBar or scroll.scrollBar
    if not win.fdjScrollBar then
        for i = 1, select("#", scroll:GetChildren()) do
            local child = select(i, scroll:GetChildren())
            if child and (child.ScrollUpButton or child.ScrollDownButton
                or child.scrollUpButton or child.scrollDownButton) then
                win.fdjScrollBar = child
                break
            end
        end
    end

    local content = CreateFrame("Frame", nil, scroll)
    win.fdjContent = content
    content:SetSize(275, 1)
    scroll:SetScrollChild(content)

    win.fdjEmpty = win:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontDisable")
    win.fdjEmpty:SetPoint("CENTER", inset, "CENTER", 0, 0)
    win.fdjEmpty:SetWidth(250)
    win.fdjEmpty:SetJustifyH("CENTER")
    win.fdjEmpty:SetWordWrap(true)

    win.fdjRows = {}
    win.fdjDividers = {}
    win:Hide()
    return win
end

local function RefreshWindow(win)
    if not win then return end
    local list = SortedFavourites()
    if win.fdjTitle then win.fdjTitle:SetText(L("FAVOURITES") .. (#list > 0 and (" (" .. #list .. ")") or "")) end
    if win.fdjEmpty then
        win.fdjEmpty:SetText(L("FAVOURITES_EMPTY"))
        if #list == 0 then win.fdjEmpty:Show() else win.fdjEmpty:Hide() end
    end
    if not win.fdjContent then return end

    local width = math.max(250, (win.fdjScroll and win.fdjScroll:GetWidth() or 285) - 4)
    local rowIndex, dividerIndex = 0, 0
    local y = 0
    local lastDungeon

    for _, fav in ipairs(list) do
        local dungeonName = tostring(fav.dungeon or "Unknown")
        if dungeonName ~= lastDungeon then
            dividerIndex = dividerIndex + 1
            local divider = win.fdjDividers[dividerIndex]
            if not divider then
                divider = CreateDungeonDivider(win.fdjContent)
                win.fdjDividers[dividerIndex] = divider
            end
            divider:ClearAllPoints()
            divider:SetPoint("TOPLEFT", win.fdjContent, "TOPLEFT", 0, -y)
            divider:SetWidth(width)
            local displayDungeon = FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(dungeonName) or dungeonName
            divider.title:SetText(displayDungeon)
            divider:Show()
            y = y + 30
            lastDungeon = dungeonName
        end

        rowIndex = rowIndex + 1
        local row = win.fdjRows[rowIndex]
        if not row then
            row = CreateFavouriteRow(win.fdjContent)
            win.fdjRows[rowIndex] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", win.fdjContent, "TOPLEFT", 0, -y)
        row:SetWidth(width)
        row.fdjItemID = fav.id
        row.fdjStoredName = fav.name
        row.fdjStoredSlot = fav.slot
        row.fdjStoredQuality = fav.quality
        row.fdjDungeon = fav.dungeon
        row.fdjBoss = fav.boss
        row.fdjQuestID = fav.questID
        row.fdjQuestName = fav.questName
        row.icon:SetTexture(ItemIcon(fav.id))
        local name = ItemName(fav)
        local r, g, b = ItemColor(fav)
        row.name:SetText(name)
        row.name:SetTextColor(r, g, b)
        if fav.questID then
            -- Quest items have no slot text stored; show the quest they come from.
            local questName = fav.questName or ""
            if FDJ.LocalizeQuestField then
                local ok, localized = pcall(FDJ.LocalizeQuestField, fav.questID, "name", questName)
                if ok and type(localized) == "string" and localized ~= "" then questName = localized end
            end
            -- Quest marker right in front of the quest name.
            -- repeaticon (2.0.44): the blue ? for a repeatable quest
            row.slot:SetText((FDJ.QuestIconMarkup and FDJ.QuestIconMarkup(fav.questID, 14) or "|TInterface\\GossipFrame\\AvailableQuestIcon:14:14:0:0|t ") .. questName)
        else
            row.slot:SetText(FDJ.LocalizeItemSlot and FDJ.LocalizeItemSlot(fav.slot) or (fav.slot or ""))
        end
        -- Obtained = the character has it in bags, bank or equipped.
        local owned = false
        local countItems = (C_Item and C_Item.GetItemCount) or GetItemCount
        if countItems then
            local ok, count = pcall(countItems, fav.id, true)
            if ok and not (type(issecretvalue) == "function" and issecretvalue(count))
                and type(count) == "number" and count > 0 then
                owned = true
            end
        end
        row.completeGlow:SetShown(owned)
        row.check:SetShown(owned)
        -- Keep the text clear of the tick.
        row.name:SetPoint("RIGHT", owned and -34 or -8, 0)
        row.slot:SetPoint("RIGHT", owned and -34 or -8, 0)
        row:Show()
        y = y + 52

        -- Request missing item data at most once per session. On some clients
        -- RequestLoadItemDataByID can fire its completion event synchronously
        -- when the item is already cached. Requesting again from RefreshWindow
        -- would recursively re-enter this function until a C stack overflow.
        if C_Item and C_Item.RequestLoadItemDataByID and not requestedItemData[fav.id] then
            local loaded = false
            if GetItemInfo then
                local ok, itemName = pcall(GetItemInfo, fav.id)
                loaded = ok and itemName ~= nil
            end
            if not loaded then
                requestedItemData[fav.id] = true
                pcall(C_Item.RequestLoadItemDataByID, fav.id)
            end
        end
    end

    for i = rowIndex + 1, #win.fdjRows do
        local row = win.fdjRows[i]
        if row then
            row.fdjItemID = nil
            row:Hide()
        end
    end
    for i = dividerIndex + 1, #win.fdjDividers do
        local divider = win.fdjDividers[i]
        if divider then divider:Hide() end
    end

    local contentHeight = math.max(1, y)
    win.fdjContent:SetHeight(contentHeight)

    -- Do not show a useless scrollbar/track when all favourites already fit.
    -- Reset vertical scroll too, otherwise reopening a shorter list can keep
    -- an old offset from a previously longer list.
    local visibleHeight = (win.fdjScroll and win.fdjScroll:GetHeight()) or 0
    local needsScroll = visibleHeight > 0 and contentHeight > (visibleHeight + 1)
    local scrollBar = win.fdjScrollBar
        or (win.fdjScroll and (win.fdjScroll.ScrollBar or win.fdjScroll.scrollBar))

    if scrollBar then
        if needsScroll then
            scrollBar:Show()
        else
            scrollBar:Hide()
        end
    end
    if not needsScroll and win.fdjScroll then
        win.fdjScroll:SetVerticalScroll(0)
    end
end
FDJ.RefreshFavouritesWindow = RefreshWindow

function FDJ.ToggleFavouritesWindow(frame)
    local win = frame.favouritesWindow or CreateWindow(frame)
    if win:IsShown() then
        win:Hide()
    else
        RefreshWindow(win)
        win:Show()
        if win.Raise then win:Raise() end
    end
end

local function UpdateButton(frame)
    local button = frame and frame.favouritesButton
    if not button then return end
    button.text:SetText(L("FAVOURITES"))
    button:SetWidth(math.max(96, math.min(170, math.ceil((button.text:GetStringWidth() or 70) + 44))))
end

-- The journal builds the Loot Filter button on its home page; add ours to its left.
local baseCreateLootFilterButton = FDJ.CreateLootFilterButton
if baseCreateLootFilterButton then
    FDJ.CreateLootFilterButton = function(frame, home, anchorButton)
        baseCreateLootFilterButton(frame, home, anchorButton)
        if not frame or not frame.lootFilterButton or frame.favouritesButton then return end
        local button = CreateFrame("Button", nil, home, "BackdropTemplate")
        frame.favouritesButton = button
        button:SetSize(110, 28)
        button:SetPoint("RIGHT", frame.lootFilterButton, "LEFT", -8, 0)
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        button:SetBackdropColor(0.12, 0.115, 0.105, 0.98)
        button:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button.star = button:CreateTexture(nil, "ARTWORK")
        button.star:SetSize(16, 16)
        button.star:SetPoint("LEFT", 10, 0)
        SetStar(button.star)
        button.text = button:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
        button.text:SetPoint("LEFT", button.star, "RIGHT", 6, 0)
        button.text:SetTextColor(1.00, 0.82, 0.27)
        button:SetScript("OnClick", function()
            if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_OPEN) end
            FDJ.ToggleFavouritesWindow(frame)
        end)
        UpdateButton(frame)
    end
end

-- Refresh names/icons once item data arrives while the window is open.
do
    local events = CreateFrame("Frame")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    -- Looting or equipping a favourite updates its "obtained" look at once.
    pcall(events.RegisterEvent, events, "BAG_UPDATE_DELAYED")
    pcall(events.RegisterEvent, events, "PLAYER_EQUIPMENT_CHANGED")
    if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("ITEM_DATA_LOAD_RESULT") then
        events:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    end
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            -- The favourites list itself may stay open in combat. Only dismiss
            -- the tiny right-click action menu so it cannot linger over combat.
            FDJ.HideItemFavouriteMenu()
            return
        end
        RefreshOpenWindow()
    end)
end

-- Follow language changes made in the journal.
local baseRelocalize = FDJ.RelocalizeLootFilter
if baseRelocalize then
    FDJ.RelocalizeLootFilter = function(frame, ...)
        baseRelocalize(frame, ...)
        UpdateButton(frame)
        if frame and frame.favouritesWindow then RefreshWindow(frame.favouritesWindow) end
    end
end
