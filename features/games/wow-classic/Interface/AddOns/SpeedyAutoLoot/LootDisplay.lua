local addonName = ...; ---@type string
local ns = select(2, ...); ---@type AutoLoot

local LootDisplay = {};
local internal = {
  _frame = CreateFrame("frame", nil, UIParent),
  ICON_SIZE = 28,
  MESSAGE_HEIGHT = 28,
  MIN_WIDTH = 200,
  ITEM_LIFESPAN = 3,
  BUTTON_SPACING = 4,
  MAX_SLOTS = 20,
  isMovable = false,
  lastMoney = 0,
  lastPostTime = 0.0,
  currentLoots = {},
  activeMessages = {},
  frameReserve = {},
  lastNumLoot = 0,
  poolHead = {},
  activeCount = 0,
  eventTimer = nil,
  isClassic = (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE),
  pendingQueue = {},
  ANIMATION_DELAY = 0.15,
  lastDequeueTime = 0,
  currentItems = {},
}

local LootAnchor = CreateFrame("Frame", "SpeedyAutoLoot_LootDisplayAnchor", UIParent)
LootAnchor:SetSize(internal.MIN_WIDTH, 20)
LootAnchor:SetPoint("CENTER")
LootAnchor:SetMovable(true)
LootAnchor:RegisterForDrag("LeftButton")
LootAnchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
LootAnchor:SetClampedToScreen(true)
LootAnchor:SetUserPlaced(false)

local LootScrollFrame = CreateFrame("Frame", nil, UIParent)
LootScrollFrame:SetPoint("TOPLEFT", LootAnchor, "TOPLEFT", 0, -20)
LootScrollFrame:SetPoint("TOPRIGHT", LootAnchor, "TOPRIGHT", 0, -20)
LootScrollFrame:SetSize(internal.MIN_WIDTH, 1)
LootScrollFrame:SetFrameStrata("MEDIUM")
LootScrollFrame:SetFrameLevel(10)
LootScrollFrame:EnableMouse(false)

local abg = LootAnchor:CreateTexture(nil, "BACKGROUND")
abg:SetAllPoints()
abg:SetColorTexture(0, 0.8, 1, 0.4)
LootAnchor.text = LootAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
LootAnchor.text:SetPoint("CENTER")
LootAnchor.text:SetText("Loot Display")
LootAnchor:Hide()

LootAnchor:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local point, _, _, x, y = self:GetPoint()
  if SpeedyAutoLootDB and SpeedyAutoLootDB["global"] then
    SpeedyAutoLootDB["global"].uiPoint = { point = point, x = x, y = y }
  end
end)

local function ResetLootFrame(frame)
  frame:Hide()
  frame:SetAlpha(0)
  frame.itemName = nil
  frame.itemLink = nil
  frame.count = 0
  frame.startTime = 0
  frame.updateTime = 0
  frame.flashTime = 0
  frame.readyToRelease = false
  frame.isPermanent = false
  frame.inUse = false
  frame.skipAnimation = false
  if frame.Flash then
    frame.Flash:SetAlpha(0)
    frame.Flash:SetVertexColor(1, 1, 1)
  end
  frame:ClearAllPoints()
end

local function GetAvailableFrame()
  for i = 1, internal.MAX_SLOTS do
    if not internal.frameReserve[i].inUse then
      internal.frameReserve[i].inUse = true
      return internal.frameReserve[i]
    end
  end
  return nil
end

local function ToggleTrackingEvents(enable)
  if enable then
    internal._frame:RegisterEvent("CHAT_MSG_LOOT")
    internal._frame:RegisterEvent("CHAT_MSG_CURRENCY")
    internal._frame:RegisterEvent("PLAYER_MONEY")
  else
    internal._frame:UnregisterEvent("CHAT_MSG_LOOT")
    internal._frame:UnregisterEvent("CHAT_MSG_CURRENCY")
    internal._frame:UnregisterEvent("PLAYER_MONEY")
  end
end

function ns:ToggleLootDisplay(forceState)
  internal.isMovable = (forceState ~= nil) and forceState or not internal.isMovable
  if internal.isMovable then
    LootAnchor:Show()
    LootAnchor:EnableMouse(true)
    if not LootScrollFrame:GetScript("OnUpdate") then
      LootScrollFrame:SetScript("OnUpdate", function(s, e) LootDisplay:UpdateAnimations(e) end)
    end
    LootDisplay:PostLoot("Epic Test", 132331, 4, 1, nil, false, nil, nil, false, true)
    LootDisplay:PostLoot("Common Test", 134400, 1, 5, nil, false, nil, nil, false, true)
    LootDisplay:PostLoot("Gold", 133784, 1, 12345, nil, false, nil, nil, true, true)
  else
    LootAnchor:Hide()
    LootAnchor:EnableMouse(false)
    for i = #internal.activeMessages, 1, -1 do
      if internal.activeMessages[i].isPermanent then
        local f = table.remove(internal.activeMessages, i)
        ResetLootFrame(f)
      end
    end
  end
end

local function InitializeFrames()
  for i = 1, internal.MAX_SLOTS do
    local f = CreateFrame("Button", nil, LootScrollFrame)
    f:SetSize(internal.MIN_WIDTH, internal.MESSAGE_HEIGHT)
    f:SetPropagateMouseClicks(true)

    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.Icon:SetSize(internal.ICON_SIZE, internal.ICON_SIZE)
    f.Icon:SetPoint("LEFT", 0, 0)
    f.Icon:SetCollapsesLayout(true)

    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.Text:SetPoint("LEFT", f.Icon, "RIGHT", 10, 0)

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0)
    f.bg:SetGradient("HORIZONTAL", CreateColor(0,0,0,0.8), CreateColor(0,0,0,0))

    f.Flash = f:CreateTexture(nil, "OVERLAY", nil, 1)
    f.Flash:SetAllPoints()
    f.Flash:SetColorTexture(1, 1, 1, 0.5)
    f.Flash:SetAlpha(0)

    f.IconBorder = f:CreateTexture(nil, "OVERLAY")
    f.IconBorder:SetAllPoints(f.Icon)
    f.IconBorder:SetTextureSliceMargins(6, 6, 6, 6)
    f.IconBorder:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    f.IconBorder:SetTexture("Interface\\AddOns\\SpeedyAutoLoot\\Art\\LootIconBorder.tga")

    f.IconQuestTexture = f:CreateTexture(nil, "OVERLAY")
    f.IconQuestTexture:SetAllPoints(f.Icon)
    f.IconQuestTexture:SetTexture("Interface\\AddOns\\SpeedyAutoLoot\\Art\\LootQuestIcon.tga")
    f.IconQuestTexture:Hide()

    f.ProfessionQualityOverlay = f:CreateTexture(nil, "OVERLAY");
    f.ProfessionQualityOverlay:SetPoint("TOPLEFT", -5, 3);
    f.ProfessionQualityOverlay:SetDrawLayer("OVERLAY", 7);

    f:SetScript("OnEnter", function(self)
      if self.itemLink then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.itemLink)
        GameTooltip:Show()
        internal.isHovering = true
      end
    end)

    f:SetScript("OnLeave", function()
      GameTooltip:Hide()
      internal.isHovering = false
    end)

    ResetLootFrame(f)
    internal.frameReserve[i] = f
  end
end

local function SetCreaftingQuality(frame, link)
  if internal.isClassic then return end

  if not link then
    frame.ProfessionQualityOverlay:Hide()
    return
  end

  local qualityInfo = C_TradeSkillUI.GetItemReagentQualityInfo(link);
  if not qualityInfo then
    ---@flavor-narrows retail
    qualityInfo = C_TradeSkillUI.GetItemCraftedQualityInfo(link);
  end

  if not qualityInfo then
    frame.ProfessionQualityOverlay:Hide()
    return
  end

  local atlas = qualityInfo.iconInventory;
  frame.ProfessionQualityOverlay:SetAtlas(atlas, TextureKitConstants);
  frame.ProfessionQualityOverlay:Show()
end

internal._frame:RegisterEvent("PLAYER_LOGIN")
internal._frame:RegisterEvent("ADDON_LOADED")
internal._frame:RegisterEvent("LOOT_READY")
internal._frame:RegisterEvent("LOOT_CLOSED")

local function AcquireData()
  local object = internal.poolHead
  if object then
    internal.poolHead = object.next
    object.next = nil
  else
    object = {
      name = "", texture = 0, quality = 0, quantity = 0,
      locked = false, isQuestItem = false, questID = nil,
      questActive = false, itemLink = nil, next = nil
    }
  end
  return object
end

local function ReleaseData(object)
  object.name, object.texture, object.quality, object.quantity = "", 0, 0, 0
  object.locked, object.isQuestItem, object.questID, object.questActive = false, false, nil, false
  object.itemLink = nil
  object.next = internal.poolHead
  internal.poolHead = object
end

internal._frame:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    local loadedName = ...
    if loadedName ~= addonName then return end
    if SpeedyAutoLootDB and SpeedyAutoLootDB["global"] then
      SpeedyAutoLootDB["global"].uiPoint = SpeedyAutoLootDB["global"].uiPoint or { point = "CENTER", x = 400, y = 260 }
      local pos = SpeedyAutoLootDB["global"].uiPoint
      LootAnchor:ClearAllPoints()
      LootAnchor:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    end

    InitializeFrames()
    return
  end

  if not SpeedyAutoLootDB.global.lootDisplayEnabled then return end

  if event == "LOOT_READY" then
    local numItems = GetNumLootItems()
    if numItems == 0 or internal.lastNumLoot == numItems then return end

    if internal.eventTimer then
      internal.eventTimer:Cancel()
    end

    ToggleTrackingEvents(true)
    internal.lastMoney = GetMoney()

    for _, data in pairs(internal.currentItems) do ReleaseData(data) end
    wipe(internal.currentItems)

    for i = 1, numItems do
      local texture, name, quantity, currencyID, quality, locked, isQuestItem, questID, questActive = GetLootSlotInfo(i)
      local lootLink = GetLootSlotLink(i)
      local isCoin = GetLootSlotType(i) == 2;

      if currencyID then
        name, texture, quantity, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(currencyID, quantity, name, texture, quality)
      end

      if not isCoin and not internal.currentItems[i] then
        local data = AcquireData()
        data.name = name
        data.texture = texture
        data.quality = quality or 1
        data.quantity = quantity
        data.locked = locked
        data.isQuestItem = isQuestItem
        data.questID = questID
        data.questActive = questActive
        data.itemLink = lootLink

        internal.currentItems[i] = data
      end
    end

  internal.lastNumLoot = numItems
  elseif event == "CHAT_MSG_LOOT" then
    local msg = ...
    if issecurevalue and issecurevalue(msg) then return end
    if not LootDisplay:IsMessagePlayer(...) then return end
    local link = msg:match("(|c.-|h|r)")
    if not link then return end

    local targetID = C_Item.GetItemInfoInstant(link)
    if not targetID then return end

    for i, data in pairs(internal.currentItems) do
      if data.itemLink == link then
        local stripped = msg:gsub("|c.-|h|r", "")
        local count = tonumber(stripped:match("(%d+)")) or 1
          LootDisplay:PostLoot(
            data.name,
            data.texture,
            data.quality,
            count,
            data.itemLink,
            data.isQuestItem,
            data.questID,
            data.questActive
          )
          ReleaseData(data)
          internal.currentItems[i] = nil
        break
      end
    end
  elseif event == "CHAT_MSG_CURRENCY" then
    local msg = ...
    if issecurevalue and issecurevalue(msg) then return end
    local link = msg:match("(|c.-|h|r)")
    if not link then return end
    local currencyID = tonumber(link:match("currency:(%d+)"))
    for i, data in pairs(internal.currentItems) do
      local cachedCurrencyID = data.itemLink and tonumber(data.itemLink:match("currency:(%d+)"))
      if cachedCurrencyID and cachedCurrencyID == currencyID then
        local stripped = msg:gsub("|c.-|h|r", "")
        local count = tonumber(stripped:match("(%d+)")) or 1
        LootDisplay:PostLoot(
          data.name,
          data.texture,
          data.quality,
          count,
          data.itemLink,
          data.isQuestItem,
          data.questID,
          data.questActive
        )
        ReleaseData(data)
        internal.currentItems[i] = nil
        break
      end
    end
  elseif event == "PLAYER_MONEY" then
    local cur = GetMoney()
    local diff = cur - (internal.lastMoney or cur)
    internal.lastMoney = cur
    if diff > 0 then
      LootDisplay:PostLoot(nil, nil, 1, diff, nil, false, false, false, true, false)
    end
  elseif event == "LOOT_CLOSED" then
    internal.lastNumLoot = 0
    if internal.eventTimer then internal.eventTimer:Cancel() end
    internal.eventTimer = C_Timer.NewTimer(3, function()
      ToggleTrackingEvents(false)
    end)
  end
end)

function LootDisplay:IsMessagePlayer(...)
  if internal.isClassic then
    local name = select(5,...)
    return UnitName("player") == name
  else
    local sourceGUID = select(12, ...)
    return UnitGUID("player") == sourceGUID
  end
end

function LootDisplay:UpdateAnimations(elapsed)
  local now = GetTime()

  if #internal.pendingQueue > 0 and (now - internal.lastDequeueTime) >= internal.ANIMATION_DELAY then
    local data = table.remove(internal.pendingQueue, 1)
    internal.lastDequeueTime = now

    local f = GetAvailableFrame()
    if f then
      f.itemName = data.lookupName
      f.count = data.count
      f.quality = data.quality or 1
      f.startTime = now
      f.updateTime = 0
      f.expiration = now + internal.ITEM_LIFESPAN
      f.itemLink = data.itemLink
      f.isPermanent = data.isTest
      f.skipAnimation = false
      f.readyToRelease = false

      local r, g, b, hex = C_Item.GetItemQualityColor(f.quality)

      if f.quality >= 4 then
        f.flashTime = now
        f.Flash:SetVertexColor(r, g, b)
        f.Flash:SetAlpha(1)
      else
        f.flashTime = 0
        f.Flash:SetAlpha(0)
      end

      if data.questID or data.isQuestItem then
        f.IconQuestTexture:Show()
      else
        f.IconQuestTexture:Hide()
      end

      SetCreaftingQuality(f, data.itemLink)

      if data.isCoin then
        f.IconBorder:Hide()
        f.Icon:Hide()
      else
        f.IconBorder:Show()
        f.Icon:Show()
        f.Icon:SetTexture(data.icon or 133784)
        f.Icon:SetTexCoord(0.0625, 0.9375, 0.0625, 0.9375)
        f.IconBorder:SetVertexColor(r, g, b, 1)
      end

      f.Text:SetText(data.isCoin and string.format("    |c%s%s|r", hex, C_CurrencyInfo.GetCoinTextureString(data.count))
        or string.format("|cffffffff+%d|r |c%s%s|r", data.count, hex, data.name))

      local spawnIndex = #internal.activeMessages
      local spawnY = -(spawnIndex * (internal.MESSAGE_HEIGHT + internal.BUTTON_SPACING))
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", LootScrollFrame, "TOPLEFT", -20, spawnY)
      f:SetAlpha(0)
      f:Show()

      table.insert(internal.activeMessages, f)
    end
  end

  for i = #internal.activeMessages, 1, -1 do
    local frame = internal.activeMessages[i]
    if frame.readyToRelease then
      table.remove(internal.activeMessages, i)
      ResetLootFrame(frame)
    end
  end

  local count = #internal.activeMessages
  if count == 0 and #internal.pendingQueue == 0 and not internal.isMovable then
    LootScrollFrame:SetAlpha(0)
    LootScrollFrame:SetScript("OnUpdate", nil)
    return
  end

  for i, frame in ipairs(internal.activeMessages) do
    local targetY = -( (i - 1) * (internal.MESSAGE_HEIGHT + internal.BUTTON_SPACING) )
    local _, _, _, _, currentY = frame:GetPoint()

    if currentY == nil then
      currentY = targetY
    end

    local newY = currentY + (targetY - currentY) * 0.15

    if frame.flashTime > 0 then
      local flashAge = now - frame.flashTime
      if flashAge < 1 then
        frame.Flash:SetAlpha(1 - flashAge)
      else
        frame.Flash:SetAlpha(0)
        frame.flashTime = 0
      end
    end

    local remaining = frame.expiration - now
    if remaining < 1.0 and not frame.isPermanent then
      if internal.isHovering then
        frame.expiration = now + internal.ITEM_LIFESPAN
        frame:SetAlpha(1)
      else
        frame:SetAlpha(math.max(0, remaining))
      end
    else
      if frame.skipAnimation then
        frame:SetAlpha(1)
        frame:SetPoint("TOPLEFT", LootScrollFrame, "TOPLEFT", 0, newY)
      else
        local slideIn = math.min(1, (now - frame.startTime) / 0.2)
        frame:SetAlpha(slideIn)
        frame:SetPoint("TOPLEFT", LootScrollFrame, "TOPLEFT", -20 + (20 * slideIn), newY)
      end
    end

    if remaining <= 0 and not frame.isPermanent then
      frame.readyToRelease = true
    end
    frame:Show()
  end

  LootScrollFrame:SetAlpha(1)
  LootScrollFrame:SetHeight(math.max(20, count * (internal.MESSAGE_HEIGHT + internal.BUTTON_SPACING)))
end

function LootDisplay:PostLoot(name, icon, quality, count, itemLink, isQuestItem, questID, questActive, isCoin, isTest)
  count = (not count or count < 1) and 1 or count
  local lookupName = isCoin and "COMBINED_GOLD" or name
  local now = GetTime()

  if not LootScrollFrame:GetScript("OnUpdate") then
    LootScrollFrame:SetScript("OnUpdate", function(s, e) self:UpdateAnimations(e) end)
  end

  for _, frame in ipairs(internal.activeMessages) do
    if not frame.isPermanent then
      frame.expiration = now + internal.ITEM_LIFESPAN
    end
  end

  for _, frame in ipairs(internal.activeMessages) do
    if frame.itemName == lookupName then
      frame.count = frame.count + count
      frame.updateTime = now
      frame.skipAnimation = true
      frame.itemLink = itemLink or frame.itemLink
      local r, g, b, hex = C_Item.GetItemQualityColor(frame.quality or 1)

      frame.Text:SetText(isCoin and string.format("   |c%s%s|r", hex, C_CurrencyInfo.GetCoinTextureString(frame.count))
        or string.format("|cffffffff+%d|r |c%s%s|r", frame.count, hex, name))

      if frame.quality >= 4 then
        frame.flashTime = now
        frame.Flash:SetVertexColor(r, g, b)
        frame.Flash:SetAlpha(1)
      end
      return
    end
  end

  for _, data in ipairs(internal.pendingQueue) do
    if data.lookupName == lookupName then
      data.count = data.count + count
      return
    end
  end

  table.insert(internal.pendingQueue, {
    name = name,
    lookupName = lookupName,
    icon = icon,
    quality = quality,
    count = count,
    itemLink = itemLink,
    isQuestItem = isQuestItem,
    questID = questID,
    questActive = questActive,
    isCoin = isCoin,
    isTest = isTest
  })
end