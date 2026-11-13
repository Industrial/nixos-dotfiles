local addonName, AM = ...
local L = AM.L

-- The Bargains tab of the panel beside the Buy tab (see ShoppingPanel.lua): the rules (specific items, filters) with
-- what was found for them, and the editor of a rule. The data is in bargains/Bargains.lua.
AM.BargainsPanel = {}
local BargainsPanel = AM.BargainsPanel
local Bargains = AM.Bargains
local Widgets = AM.Widgets
local UI = AM.Theme.ui

local PADDING = 8
local GAP = 6
local FOOTER_HEIGHT = 22
local FOOTER_PAD = 0 -- below the footer: as in the auction house, the buttons fill the narrow strip below the list
local BUTTON_PADDING = 10
local HEIGHT = { header = 24, rule = 38, hit = 24, message = 40 }
local FILTER_ICON = "Interface\\Icons\\INV_Misc_Spyglass_02"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local CLASSES = { "Consumable", "Container", "Weapon", "Gem", "Armor", "Reagent", "Tradegoods", "ItemEnhancement",
  "Recipe", "Miscellaneous", "Glyph", "Profession" }
local QUALITIES = { 1, 2, 3, 4 }

-- A well known item of a category, whose icon stands for it in the list of filters (the game's categories have no
-- icons of their own). Categories without one, or without a category, get FILTER_ICON.
local CLASS_ICON_ITEMS = { Consumable = 118, Container = 4240, Weapon = 25, Gem = 774, Armor = 6096, Tradegoods = 2589,
  Recipe = 2553, Miscellaneous = 6948 }
local CLASS_ICONS = {}
for name, itemId in pairs(CLASS_ICON_ITEMS) do
  local classId = Enum.ItemClass and Enum.ItemClass[name]
  if classId then
    CLASS_ICONS[classId] = itemId
  end
end

local function FilterIcon(rule)
  local itemId = rule.classId and CLASS_ICONS[rule.classId]
  return itemId and C_Item.GetItemIconByID(itemId) or FILTER_ICON
end

local view

-- How long ago: "just now", else in minutes (and hours, days), e.g. "2 min ago".
local function FormatAge(timestamp)
  local age = time() - timestamp
  if age < 60 then
    return L["BARGAINS_AGO_NOW"]
  end
  return L["MAIN_AGO"]:format(SecondsToTime(age, true))
end

local function QualityColor(quality)
  local color = ITEM_QUALITY_COLORS[quality or 1]
  return color.r, color.g, color.b
end

-- Searches the item in the buy view: commodities are selected by their id, gear (whose results are keyed by item
-- level) is searched by its name and selected by the player, whose click is then seen as a search too.
local function Search(itemId)
  local info = C_AuctionHouse.GetItemKeyInfo(C_AuctionHouse.MakeItemKey(itemId))
  if info and not info.isCommodity and C_Item.GetItemInfo(itemId) then
    AM.ShoppingList.SearchItemName(itemId)
  else
    AM.ShoppingList.SearchItem(itemId)
  end
end

-- "Scanning 6,849 / 11,046" while the auctions are read, "Scanning..." until the server has answered.
local function ScanText()
  local read, total = AM.Scan.GetProgress()
  if not total then
    return L["BARGAINS_SCANNING"]
  end
  return L["BARGAINS_SCANNING_COUNT"]:format(AM.FormatCount(read), AM.FormatCount(total))
end

-- The footer text: the search or scan that runs, else nothing.
local function UpdateAge()
  if AM.BargainScan.IsRunning() then
    view.age:SetText(Widgets.Color(UI.gold, L["BARGAINS_SEARCHING"]:format(AM.BargainScan.GetProgress())))
  elseif AM.Scan.IsRunning() then
    view.age:SetText(Widgets.Color(UI.gold, ScanText())) -- the count
  else
    view.age:SetText("")
  end
end

-- Rows ---------------------------------------------------------------------------------------------

-- The filters whose items are shown, by rule id. Not saved: after a reload every filter is folded again.
local unfolded = {}

local function IsFolded(ruleId)
  return not unfolded[ruleId]
end

local function CreateRow(parent)
  local row = CreateFrame("Button", nil, parent)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.background = row:CreateTexture(nil, "BACKGROUND")
  row.background:SetAllPoints()
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  -- the fold icon of a filter; its additive copy in the highlight layer brightens it under the mouse, as in the
  -- profession window's recipe list
  row.fold = row:CreateTexture(nil, "ARTWORK")
  row.foldGlow = row:CreateTexture(nil, "HIGHLIGHT")
  row.foldGlow:SetBlendMode("ADD")
  row.foldGlow:SetPoint("CENTER", row.fold)
  row.name = Widgets.CreateText(row, "GameFontHighlightSmall")
  row.name:SetWordWrap(false)
  row.sub = Widgets.CreateText(row, "GameFontHighlightSmall")
  row.sub:SetWordWrap(false)
  row.price = Widgets.CreateText(row, "GameFontHighlightSmall", "RIGHT")
  row.maxLine = Widgets.CreateText(row, "GameFontHighlightSmall", "RIGHT")
  row:SetScript("OnClick", function(self, button)
    if self.rule and button == "RightButton" then
      BargainsPanel.Edit(self.rule)
    elseif self.rule and self.rule.type == "filter" then
      -- folds the items it found away, or shows them again
      unfolded[self.rule.id] = IsFolded(self.rule.id) or nil
      BargainsPanel.Update()
    elseif self.itemId then
      Search(self.itemId)
    end
  end)
  row:SetScript("OnEnter", function(self)
    if self.tooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.tooltip, 1, 1, 1)
      GameTooltip:Show()
    elseif self.showItem and self.itemId then
      -- an item a filter found or left out: the item's own tooltip
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink("item:" .. self.itemId)
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", GameTooltip_Hide)
  return row
end

local function ResetRow(row)
  row.rule, row.itemId, row.tooltip, row.showItem = nil, nil, nil, nil
  row.icon:Hide()
  row.icon:ClearAllPoints()
  row.fold:Hide()
  row.foldGlow:Hide()
  row.name:ClearAllPoints()
  row.sub:Hide()
  row.sub:ClearAllPoints()
  row.price:Hide()
  row.price:ClearAllPoints()
  row.maxLine:Hide()
  row.maxLine:ClearAllPoints()
  if row.search then
    row.search:Hide()
  end
  row:SetAlpha(1)
  row:EnableMouse(false)
end

local function SetIcon(row, texture, size, left)
  row.icon:SetSize(size, size)
  row.icon:SetPoint("LEFT", left, 0)
  row.icon:SetTexture(texture or UNKNOWN_ICON)
  row.icon:Show()
end

-- Two lines: the name and below it the state on the left; on the right "Found:" and below it "Max:", each with its
-- value. found and max are the texts after the labels (with money in them); without found nothing is searched yet and
-- the line stays empty.
local function SetTexts(row, left, name, sub, found, max)
  row.name:SetText(name)
  row.maxLine:SetPoint("TOPRIGHT", -8, -20)
  row.maxLine:SetText(Widgets.Color(UI.gold, L["BARGAINS_MAX_LABEL"]) .. " " .. max)
  row.maxLine:Show()
  row.price:SetPoint("TOPRIGHT", -8, -5)
  row.price:SetText(found and (Widgets.Color(UI.gold, L["BARGAINS_FOUND_LABEL"]) .. " " .. found) or "")
  row.price:Show()
  row.name:SetPoint("TOPLEFT", left, -5)
  row.name:SetPoint("TOPRIGHT", row.price, "TOPLEFT", -4, 0)
  row.sub:SetText(sub)
  row.sub:SetPoint("TOPLEFT", left, -20)
  row.sub:SetPoint("TOPRIGHT", row.maxLine, "TOPLEFT", -4, 0)
  row.sub:Show()
end

local GREY = "a0a0a0"
local INACTIVE_ALPHA = 0.45 -- rows of rules that are switched off

local function SetupItemRule(row, item)
  local rule = item.rule
  row.rule, row.itemId = rule, rule.itemId
  row.tooltip = L["BARGAINS_ROW_TOOLTIP_ITEM"]
  row:SetAlpha(rule.active and 1 or INACTIVE_ALPHA)
  row:EnableMouse(true)
  row.background:SetColorTexture(1, 1, 1, item.stripe and 0.025 or 0)
  local name, _, quality = C_Item.GetItemInfo(rule.itemId)
  SetIcon(row, C_Item.GetItemIconByID(rule.itemId), 22, 6)
  row.name:SetTextColor(QualityColor(quality))
  local low, searchedAt, hit, max = Bargains.GetItemResult(rule)
  local sub, found
  if not searchedAt then
    sub = Widgets.Color(GREY, L["BARGAINS_NOT_SEARCHED"])
  elseif not low then
    sub = Widgets.Color(GREY, L["BARGAINS_NOTHING_LISTED"])
    found = Widgets.Color(GREY, L["BARGAINS_NONE"])
  elseif hit then
    -- a share of the market value tells the saving against the market, a fixed price the one against the limit
    local text = rule.percent and L["BARGAINS_UNDER_MARKET"] or L["BARGAINS_UNDER_MAX"]
    local reference = rule.percent and max * 100 / rule.percent or max
    sub = Widgets.Color(UI.gain, text:format(math.floor((1 - low / reference) * 100 + 0.5)))
    found = AM.FormatMoney(low, true)
  else
    sub = Widgets.Color(GREY, max and L["BARGAINS_NOTHING_UNDER_MAX"] or L["BARGAINS_NO_MARKET"])
    found = Widgets.Color(GREY, L["BARGAINS_NONE"])
  end
  -- a share of the market value shows the rule while that value is not known
  SetTexts(row, 34, name or "...", sub, found,
    max and AM.FormatMoney(max, true) or L["BARGAINS_MAX_SHARE"]:format(rule.percent))
end

-- Shows the plus/minus in front of a filter's name, as the profession window draws it on its recipe categories (the
-- older button art where the client has no such atlas). Returns the width it takes up.
local function ShowFoldIcon(row, folded)
  local atlas = folded and "Professions-recipe-header-expand" or "Professions-recipe-header-collapse"
  local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
  local width, height = 20, 20
  for _, texture in ipairs({ row.fold, row.foldGlow }) do
    if info then
      texture:SetAtlas(atlas)
      width, height = info.width, info.height
    else
      texture:SetTexture(folded and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    end
    texture:SetSize(width, height)
    texture:Show()
  end
  row.fold:SetPoint("TOPLEFT", 34, -(11 - height / 2)) -- centered on the line of the name
  return width
end

local function SetupFilterRule(row, item)
  local rule = item.rule
  row.rule = rule
  row.tooltip = L["BARGAINS_ROW_TOOLTIP_FILTER"]
  row:SetAlpha(rule.active and 1 or INACTIVE_ALPHA)
  row:EnableMouse(true)
  row.background:SetColorTexture(1, 1, 1, item.stripe and 0.025 or 0)
  SetIcon(row, rule.icon or FilterIcon(rule), 22, 6)
  row.name:SetTextColor(1, 1, 1)
  local hits = Bargains.GetFilterHits(rule.id)
  -- a filter with a name of its own tells what it selects below the name
  local description = rule.name and Bargains.Describe(rule)
  local sub, found = description and Widgets.Color(GREY, description) or "", nil
  if hits then
    found = #hits > 0 and Widgets.Color(UI.gain, tostring(#hits)) or Widgets.Color(GREY, L["BARGAINS_NONE"])
  end
  -- the fold toggle only where there is something to fold
  local nameLeft = 34
  if hits and #hits + #(Bargains.GetLeftOut(rule.id) or {}) > 0 then
    nameLeft = nameLeft + ShowFoldIcon(row, IsFolded(rule.id)) + 4
  end
  SetTexts(row, 34, rule.name or Bargains.Describe(rule), sub, found, AM.FormatMoney(rule.maxPrice or 0, true))
  row.name:SetPoint("TOPLEFT", nameLeft, -5) -- after the fold icon, which sits on the line of the name
end

-- One item a filter found: a click searches it.
local function SetupHit(row, item)
  local hit = item.hit
  row.itemId, row.showItem = hit[1], true
  row:EnableMouse(true)
  row.background:SetColorTexture(1, 1, 1, item.stripe and 0.025 or 0)
  SetIcon(row, C_Item.GetItemIconByID(hit[1]), 18, 36)
  local name, _, quality = C_Item.GetItemInfo(hit[1])
  row.name:SetFontObject(GameFontHighlightSmall)
  row.name:SetTextColor(QualityColor(quality))
  row.name:SetText((name or "...") .. (hit[3] > 1 and (" |cffe2dcd6" .. hit[3] .. "x|r") or ""))
  row.price:SetPoint("RIGHT", -8, 0)
  row.price:SetText(Widgets.Color(UI.gain, AM.FormatMoney(hit[2], true)))
  row.price:Show()
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row.price, "LEFT", -4, 0)
end

-- An item a filter left out although its price and category matched, in grey with the limit it missed; a click
-- searches it like a hit, to look at the auctions.
local function SetupLeftOut(row, item)
  local entry = item.entry
  row.itemId, row.showItem = entry[1], true
  row:EnableMouse(true)
  row.background:SetColorTexture(1, 1, 1, item.stripe and 0.025 or 0)
  SetIcon(row, C_Item.GetItemIconByID(entry[1]), 18, 36)
  row.icon:SetDesaturated(true)
  row.name:SetFontObject(GameFontDisableSmall)
  local why, value = Bargains.WhyLeftOut(item.rule, entry)
  local reason = why == "quality" and (_G["ITEM_QUALITY" .. value .. "_DESC"] or tostring(value))
    or why and L["BARGAINS_LEFT_" .. why:upper()]:format(value) or ""
  row.name:SetText((C_Item.GetItemInfo(entry[1]) or "...") .. " - " .. reason)
  row.price:SetPoint("RIGHT", -8, 0)
  row.price:SetText(Widgets.Color(GREY, AM.FormatMoney(entry[2], true)))
  row.price:Show()
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row.price, "LEFT", -4, 0)
end

-- The search of the items, on the right of their header: only items are searched, filters wait for a full scan, so
-- the button sits with the items and nowhere near the filters. It searches all items of the active rules, or stops
-- the search that runs. Made the first time a row shows the header.
local function SetupSearchButton(row)
  if not row.search then
    row.search = Widgets.CreateButton(row, L["BARGAINS_SEARCH"], true, function()
      if AM.BargainScan.IsRunning() then
        AM.BargainScan.Stop()
      else
        AM.BargainScan.Start()
      end
    end)
    row.search:SetHeight(HEIGHT.header - 4)
    row.search:SetPoint("RIGHT", -4, 0)
    -- all items are searched in one go, so the time is the same for all of them: it is told here instead of in the rows
    Widgets.SetTooltip(row.search, function()
      local searched = Bargains.GetLastSearched()
      return searched and L["BARGAINS_SEARCHED_AT"]:format(FormatAge(searched)) or L["BARGAINS_SEARCH_ITEMS"]
    end)
  end
  local any = false
  for _, rule in ipairs(Bargains.GetRules("item")) do
    any = any or rule.active
  end
  local searching = AM.BargainScan.IsRunning()
  row.search:SetLabel(searching and L["BARGAINS_SEARCH_STOP"] or L["BARGAINS_SEARCH"], BUTTON_PADDING)
  row.search:SetEnabled(any and (searching or not AM.Scan.IsRunning()))
  row.search:Show()
end

local function SetupRow(row, item)
  ResetRow(row)
  row.name:SetFontObject(GameFontHighlightSmall)
  if item.type == "header" then
    row.background:SetColorTexture(unpack(UI.sectionHeader))
    row.name:SetFontObject(GameFontNormalSmall)
    row.name:SetTextColor(1, 0.82, 0)
    row.name:SetText(item.text)
    row.name:SetPoint("LEFT", 12, 0)
    if item.search then
      SetupSearchButton(row)
    elseif item.scan then
      -- filters are only checked by a full scan: how old the one they show is, or that they need one
      local scannedAt = Bargains.GetScannedAt()
      row.price:SetPoint("RIGHT", -8, 0)
      row.price:SetText(scannedAt and Widgets.Color(UI.text, L["BARGAINS_FULL_SCAN_AGO"]:format(FormatAge(scannedAt)))
        or Widgets.Color(GREY, L["BARGAINS_NEEDS_SCAN"]))
      row.price:Show()
    end
  elseif item.type == "item" then
    SetupItemRule(row, item)
  elseif item.type == "filter" then
    SetupFilterRule(row, item)
  elseif item.type == "hit" then
    SetupHit(row, item)
  elseif item.type == "leftout" then
    SetupLeftOut(row, item)
  else
    row.background:SetColorTexture(0, 0, 0, 0)
    row.name:SetTextColor(0.56, 0.56, 0.56)
    row.name:SetText(item.text)
    row.name:SetPoint("LEFT", 12, 0)
    row.name:SetPoint("RIGHT", -12, 0)
  end
end

-- The rules sorted by what they found: bargains first, then those without, then those not searched yet (the
-- inactive ones last), each group in the order they were made. state(rule) gives 1, 2 or 3.
local function SortRules(rules, state)
  local ranked = {}
  for index, rule in ipairs(rules) do
    ranked[index] = { rule = rule, rank = rule.active and state(rule) or 4, index = index }
  end
  table.sort(ranked, function(a, b)
    if a.rank ~= b.rank then
      return a.rank < b.rank
    end
    return a.index < b.index
  end)
  local sorted = {}
  for index, entry in ipairs(ranked) do
    sorted[index] = entry.rule
  end
  return sorted
end

local function ItemState(rule)
  local _, searchedAt, hit = Bargains.GetItemResult(rule)
  return hit and 1 or (searchedAt and 2 or 3)
end

local function FilterState(rule)
  local hits = Bargains.GetFilterHits(rule.id)
  return hits and (#hits > 0 and 1 or 2) or 3
end

local function BuildItems()
  local items = {}
  local itemRules = SortRules(Bargains.GetRules("item"), ItemState)
  local filterRules = SortRules(Bargains.GetRules("filter"), FilterState)
  if #itemRules + #filterRules == 0 then
    items[1] = { type = "message", height = HEIGHT.message, text = L["BARGAINS_EMPTY"] }
    return items
  end
  if #itemRules > 0 then
    items[#items + 1] = { type = "header", height = HEIGHT.header, text = L["BARGAINS_ITEMS"] .. " (" .. #itemRules .. ")",
      search = true }
    for i, rule in ipairs(itemRules) do
      items[#items + 1] = { type = "item", height = HEIGHT.rule, rule = rule, stripe = i % 2 == 0 }
    end
  end
  if #filterRules > 0 then
    items[#items + 1] = { type = "header", height = HEIGHT.header,
      text = L["BARGAINS_FILTERS"] .. " (" .. #filterRules .. ")", scan = true }
    for i, rule in ipairs(filterRules) do
      items[#items + 1] = { type = "filter", height = HEIGHT.rule, rule = rule, stripe = i % 2 == 0 }
      for j, hit in ipairs(rule.active and not IsFolded(rule.id) and Bargains.GetFilterHits(rule.id) or {}) do
        items[#items + 1] = { type = "hit", height = HEIGHT.hit, hit = hit, stripe = j % 2 == 0 }
      end
      local leftOut = rule.active and not IsFolded(rule.id) and Bargains.GetLeftOut(rule.id) or {}
      if #leftOut > 0 then
        items[#items + 1] = { type = "message", height = HEIGHT.hit, text = L["BARGAINS_LEFT_OUT"]:format(#leftOut) }
      end
      for j, entry in ipairs(leftOut) do
        items[#items + 1] = { type = "leftout", height = HEIGHT.hit, entry = entry, rule = rule, stripe = j % 2 == 0 }
      end
    end
  end
  return items
end

-- Editor -------------------------------------------------------------------------------------------

local moneyCount = 0

-- The game's gold/silver/copper input; frame.GetCopper(), frame.SetCopper(n).
local function CreateMoneyInput(parent)
  moneyCount = moneyCount + 1
  local frame = CreateFrame("Frame", "AuctionMasterBargainMoney" .. moneyCount, parent, "MoneyInputFrameTemplate")
  function frame.GetCopper()
    return MoneyInputFrame_GetCopper(frame)
  end
  function frame.SetCopper(copper)
    MoneyInputFrame_SetCopper(frame, copper or 0)
  end
  return frame
end

local function CreateNumberBox(parent, width)
  local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  box:SetSize(width or 40, 20)
  box:SetAutoFocus(false)
  box:SetNumeric(true)
  box:SetMaxLetters(4)
  return box
end

local function Label(parent, text, point, relative, x, y)
  local label = Widgets.CreateText(parent, "GameFontNormalSmall")
  label:SetPoint(point, relative, x or 0, y or 0)
  label:SetText(text)
  return label
end

local function GetClasses()
  local list = {}
  for _, name in ipairs(CLASSES) do
    local id = Enum.ItemClass[name]
    local label = id and C_Item.GetItemClassInfo(id)
    if label then
      list[#list + 1] = { value = id, label = label }
    end
  end
  return list
end

local function GetSubClasses(classId)
  local list = {}
  for _, id in ipairs(classId and C_AuctionHouse.GetAuctionItemSubClasses
    and C_AuctionHouse.GetAuctionItemSubClasses(classId) or {}) do
    list[#list + 1] = { value = id, label = C_Item.GetItemSubClassInfo(classId, id) or "?" }
  end
  return list
end

-- A dropdown of the game with "Any" and the choices; dropdown.GetValue(), dropdown.SetValue(v). getChoices() gives
-- { value, label } entries, onChange(value) is called after the player picked one.
local function CreateChoiceDropdown(parent, width, getChoices, onChange)
  local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
  dropdown:SetWidth(width)
  local current
  local function LabelOf(value)
    for _, choice in ipairs(getChoices()) do
      if choice.value == value then
        return choice.label
      end
    end
    return L["BARGAINS_ANY"]
  end
  dropdown:SetSelectionTranslator(function()
    return LabelOf(current)
  end)
  dropdown:SetupMenu(function(_, root)
    root:CreateRadio(L["BARGAINS_ANY"], function() return current == nil end, function()
      current = nil
      if onChange then onChange(nil) end
    end)
    for _, choice in ipairs(getChoices()) do
      root:CreateRadio(choice.label, function() return current == choice.value end, function()
        current = choice.value
        if onChange then onChange(current) end
      end)
    end
  end)
  function dropdown.GetValue()
    return current
  end
  function dropdown.SetValue(value)
    current = value
    dropdown:GenerateMenu()
  end
  return dropdown
end

-- Item names offered while typing: the items of the latest scan whose name contains the text, whole words at the start
-- first. The names come from the client's cache, so an item it has not loaded yet is not offered. suggestions maps the
-- lower case name of each offered item to its id, which also resolves a name typed in full.
local MAX_SUGGESTIONS = 6
local MIN_LETTERS = 2

-- The client's item cache answers nothing for an item at times, also for one it gave a moment ago. A name is therefore
-- kept (for this session) the first time it is known: itemId -> { name, lower case name }.
local knownNames = {}

local function GetKnownName(itemId)
  local known = knownNames[itemId]
  if not known then
    local name = C_Item.GetItemInfo(itemId)
    if name then
      known = { name, name:lower() }
      knownNames[itemId] = known
    end
  end
  return known
end

-- Asks the client for the names of the items of the scan, once when the editor is opened, so they are there by the
-- time something is typed.
local function LoadNames()
  AM.ItemStore.ForEach(function(itemDbKey)
    GetKnownName(AM.ItemDbKey.GetItemId(itemDbKey))
  end)
end

local function FindItems(text)
  local starts, contains = {}, {}
  text = text:lower()
  local seen = {}
  AM.ItemStore.ForEach(function(itemDbKey)
    local itemId = AM.ItemDbKey.GetItemId(itemDbKey)
    local known = not seen[itemId] and GetKnownName(itemId)
    seen[itemId] = true
    if known then
      local found = known[2]:find(text, 1, true)
      if found == 1 then
        starts[#starts + 1] = { itemId, known[1] }
      elseif found then
        contains[#contains + 1] = { itemId, known[1] }
      end
    end
  end)
  local function ByName(a, b)
    return a[2] < b[2]
  end
  table.sort(starts, ByName)
  table.sort(contains, ByName)
  local list = {}
  for _, group in ipairs({ starts, contains }) do
    for _, entry in ipairs(group) do
      if #list < MAX_SUGGESTIONS then
        list[#list + 1] = entry
      end
    end
  end
  return list
end

local function ResolveItemId(text, suggestions)
  text = strtrim(text or "")
  if text == "" then
    return nil
  end
  if tonumber(text) then
    return tonumber(text)
  end
  return suggestions[text:lower()] or (C_Item.GetItemInfoInstant(text))
end

-- Name and icon of a filter, chosen in the game's own icon selector (the one of the macro window). Only the frame is
-- the game's template, what is picked goes to the callback of Open and nowhere else.
local iconPopup

local function GetIconPopup()
  if iconPopup then
    return iconPopup
  end
  local popup = CreateFrame("Frame", nil, UIParent, "IconSelectorPopupFrameTemplate")
  iconPopup = popup
  popup:Hide()
  -- the list of icons is HIGH by itself, the frame has to be at least as high to be seen over it
  popup:SetFrameStrata("HIGH")
  popup:SetToplevel(true)
  popup:EnableMouse(true)
  popup:ClearAllPoints()
  popup:SetPoint("CENTER")
  popup.BorderBox.EditBoxHeaderText:SetText(L["BARGAINS_NAME_LABEL"])
  popup.BorderBox.IconSelectorEditBox:SetMaxLetters(30)

  function popup:OnShow()
    IconSelectorPopupFrameTemplateMixin.OnShow(self)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
    self:Raise()
    self.iconDataProvider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.None)
    self.touched = false
    self:SetIconFilter(IconSelectorPopupFrameIconFilterTypes.All)
    self:Update()
    self.BorderBox.IconSelectorEditBox:SetFocus()
    self.BorderBox.IconSelectorEditBox:HighlightText()
    self.BorderBox.IconSelectorEditBox:OnTextChanged()
    self.IconSelector:SetSelectedCallback(function(_, icon)
      self.touched = true
      self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(icon)
      self.BorderBox.SelectedIconArea.SelectedIconText.SelectedIconDescription:SetText(ICON_SELECTION_CLICK)
      self.BorderBox.SelectedIconArea.SelectedIconText.SelectedIconDescription:SetFontObject(GameFontHighlightSmall)
    end)
  end

  function popup:OnHide()
    IconSelectorPopupFrameTemplateMixin.OnHide(self)
    if self.iconDataProvider then
      self.iconDataProvider:Release()
      self.iconDataProvider = nil
    end
  end

  -- the template binds its scripts to its own functions when the frame is made, so replacing the methods is not enough
  popup:SetScript("OnShow", popup.OnShow)
  popup:SetScript("OnHide", popup.OnHide)

  function popup:Update()
    local request = self.request
    self.BorderBox.IconSelectorEditBox:SetText(request.name)
    self.IconSelector:SetSelectedIndex(self:GetIndexOfIcon(request.icon))
    self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(request.icon)
    self.IconSelector:SetSelectionsDataProvider(GenerateClosure(self.GetIconByIndex, self),
      GenerateClosure(self.GetNumIcons, self))
    self.IconSelector:ScrollToSelectedIndex()
    self:SetSelectedIconText()
  end

  function popup:OkayButton_OnClick()
    IconSelectorPopupFrameTemplateMixin.OkayButton_OnClick(self)
    local name = strtrim((self.BorderBox.IconSelectorEditBox:GetText():gsub("\"", "")))
    -- the icon is only handed on if one was picked, else the filter keeps the one it has
    local icon = self.touched and self.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture() or nil
    self.request.onAccept(name, icon)
  end
  return popup
end

-- Opens the selector with request = { name, icon, onAccept(name, icon) }: the text and the icon to start with.
local function OpenIconPopup(request)
  local popup = GetIconPopup()
  popup:Hide()
  popup.request = request
  popup:Show()
end

local function CreateEditor(parent)
  local editor = AM.Native.CreateInset(parent, true) -- sunken like the list, the controls sit in the dark
  editor:Hide()
  local PADDING = PADDING + AM.Native.PANEL_INSET + 4 -- the controls keep their distance from the border of the inset
  local rule -- the rule being edited (a copy), without id for a new one

  -- type toggle
  local function CreateToggle(text, ruleType)
    local button = Widgets.CreateButton(editor, text, false, function()
      editor.SetType(ruleType)
    end)
    button.ruleType = ruleType
    return button
  end
  editor.itemToggle = CreateToggle(L["BARGAINS_TYPE_ITEM"], "item")
  editor.itemToggle:SetPoint("TOPLEFT", PADDING, -PADDING)
  editor.itemToggle:SetWidth(140)
  editor.filterToggle = CreateToggle(L["BARGAINS_TYPE_FILTER"], "filter")
  editor.filterToggle:SetPoint("LEFT", editor.itemToggle, "RIGHT", GAP, 0)
  editor.filterToggle:SetWidth(100)

  -- a new rule cannot be of a type that is full; a rule that exists can be edited whatever the limit is
  local function Blocked(ruleType)
    return not rule.id and Bargains.IsFull(ruleType)
  end
  local function LimitTooltip(toggle, label, limitKey, limit)
    toggle:SetMotionScriptsWhileDisabled(true) -- else a greyed out button shows no tooltip
    Widgets.SetTooltip(toggle, function()
      return Blocked(toggle.ruleType) and L[limitKey]:format(limit) or label
    end)
  end
  LimitTooltip(editor.itemToggle, L["BARGAINS_TYPE_ITEM"], "BARGAINS_LIMIT_ITEM", Bargains.MAX_ITEM_RULES)
  LimitTooltip(editor.filterToggle, L["BARGAINS_TYPE_FILTER"], "BARGAINS_LIMIT_FILTER", Bargains.MAX_FILTER_RULES)

  -- specific item -----------------------------------------------------------------------------------
  local item = CreateFrame("Frame", nil, editor)
  item:SetPoint("TOPLEFT", PADDING, -(PADDING + 34))
  item:SetPoint("RIGHT", -PADDING, 0)
  item:SetHeight(200)
  editor.item = item
  Label(item, L["BARGAINS_ITEM"], "TOPLEFT", item, 0, 0)
  item.box = CreateFrame("EditBox", nil, item, "InputBoxTemplate")
  item.box:SetPoint("TOPLEFT", 6, -18)
  item.box:SetPoint("RIGHT", -8, 0)
  item.box:SetHeight(20)
  item.box:SetAutoFocus(false)
  item.resolved = Widgets.CreateText(item, "GameFontHighlightSmall")
  item.resolved:SetPoint("TOPLEFT", item.box, "BOTTOMLEFT", -6, -6)
  item.resolved:SetPoint("RIGHT", -8, 0)
  item.resolved:SetWordWrap(false)
  local hint = Widgets.CreateText(item, "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", item.resolved, "BOTTOMLEFT", 0, -4)
  hint:SetPoint("RIGHT", -8, 0)
  hint:SetText(L["BARGAINS_ITEM_HINT"])
  hint:SetWordWrap(true)

  Label(item, L["BARGAINS_MAX_PRICE"], "TOPLEFT", item, 0, -92)
  item.fixed = CreateFrame("CheckButton", nil, item, "UIRadioButtonTemplate")
  item.fixed:SetPoint("TOPLEFT", 0, -108)
  item.fixed.text = Widgets.CreateText(item, "GameFontHighlightSmall")
  item.fixed.text:SetPoint("LEFT", item.fixed, "RIGHT", 2, 0)
  item.fixed.text:SetText(L["BARGAINS_FIXED"])
  item.money = CreateMoneyInput(item)
  item.money:SetPoint("TOPLEFT", 90, -112)
  item.share = CreateFrame("CheckButton", nil, item, "UIRadioButtonTemplate")
  item.share:SetPoint("TOPLEFT", 0, -140)
  item.share.text = Widgets.CreateText(item, "GameFontHighlightSmall")
  item.share.text:SetPoint("LEFT", item.share, "RIGHT", 2, 0)
  item.share.text:SetText(L["BARGAINS_SHARE"])
  item.percent = CreateNumberBox(item, 36)
  item.percent:SetPoint("LEFT", item.share.text, "RIGHT", 10, 0)
  item.percentSign = Widgets.CreateText(item, "GameFontHighlightSmall")
  item.percentSign:SetPoint("LEFT", item.percent, "RIGHT", 4, 0)
  item.percentSign:SetText(L["BARGAINS_SHARE_UNIT"])

  local function SetShare(share)
    item.share:SetChecked(share)
    item.fixed:SetChecked(not share)
  end
  item.fixed:SetScript("OnClick", function() SetShare(false) end)
  item.share:SetScript("OnClick", function() SetShare(true) end)

  -- the item typed or clicked in: name and icon below the box once it is known
  item.itemId = nil
  local suggestions = {}
  local function ShowItem()
    item.itemId = ResolveItemId(item.box:GetText(), suggestions)
    if item.itemId then
      local name, _, quality = C_Item.GetItemInfo(item.itemId)
      local icon = C_Item.GetItemIconByID(item.itemId)
      local r, g, b = QualityColor(quality)
      item.resolved:SetText(("|T%s:16|t |cff%02x%02x%02x%s|r"):format(icon or UNKNOWN_ICON, r * 255, g * 255, b * 255,
        name or ("item:" .. item.itemId)))
    else
      item.resolved:SetText("")
    end
  end

  -- the suggestions, a few buttons below the box
  local popup = Widgets.CreateBox(item, UI.sunken, UI.border)
  popup:SetFrameStrata("FULLSCREEN_DIALOG")
  popup:SetPoint("TOPLEFT", item.box, "BOTTOMLEFT", -2, -2)
  popup:SetPoint("RIGHT", item.box, "RIGHT", 2, 0)
  popup:Hide()
  local buttons = {}
  for index = 1, MAX_SUGGESTIONS do
    local button = CreateFrame("Button", nil, popup)
    button:SetHeight(18)
    button:SetPoint("TOPLEFT", 2, -2 - (index - 1) * 18)
    button:SetPoint("RIGHT", -2, 0)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12)
    button.text = Widgets.CreateText(button, "GameFontHighlightSmall")
    button.text:SetPoint("LEFT", 4, 0)
    button.text:SetPoint("RIGHT", -4, 0)
    button.text:SetWordWrap(false)
    button:SetScript("OnClick", function(self)
      popup:Hide()
      item.box:SetText(self.name)
      item.box:ClearFocus()
    end)
    buttons[index] = button
  end

  local function ShowSuggestions(text)
    local list = #text >= MIN_LETTERS and not tonumber(text) and FindItems(text) or {}
    wipe(suggestions)
    for index, button in ipairs(buttons) do
      local entry = list[index]
      button:SetShown(entry ~= nil)
      if entry then
        suggestions[entry[2]:lower()] = entry[1]
        local _, _, quality = C_Item.GetItemInfo(entry[1])
        local r, g, b = QualityColor(quality)
        button.name = entry[2]
        button.text:SetText(("|T%s:14|t |cff%02x%02x%02x%s|r"):format(C_Item.GetItemIconByID(entry[1]) or UNKNOWN_ICON,
          r * 255, g * 255, b * 255, entry[2]))
      end
    end
    popup:SetHeight(#list * 18 + 4)
    popup:SetShown(#list > 0)
  end

  -- only what the player types is offered suggestions, not a text set by the editor or by a pick
  item.box:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      ShowSuggestions(strtrim(self:GetText()))
    end
    ShowItem()
  end)
  item.box:SetScript("OnEscapePressed", function(self)
    popup:Hide()
    self:ClearFocus()
  end)
  item.box:SetScript("OnEnterPressed", function(self)
    popup:Hide()
    self:ClearFocus()
  end)
  item.box:SetScript("OnEditFocusLost", function()
    -- after a click on a suggestion, which comes first
    C_Timer.After(0.15, function()
      popup:Hide()
    end)
  end)
  item:SetScript("OnHide", function()
    popup:Hide()
  end)
  -- Shift-click on an item of the bags or of a list fills the box
  -- Retail's bags and auction house may take the focus away while handling the click, before this hook
  -- runs, so a focus lost a moment ago counts as well
  local focusLostAt = 0
  item.box:HookScript("OnEditFocusLost", function()
    focusLostAt = GetTime()
  end)
  local function FillFromLink(link)
    -- the box had focus (or just lost it), or nothing else wants the link: no chat line is being typed
    local getActive = ChatFrameUtil and ChatFrameUtil.GetActiveWindow or ChatEdit_GetActiveWindow
    local chatActive = getActive and getActive()
    local wanted = item.box:HasFocus() or GetTime() - focusLostAt < 0.3 or not chatActive
    if editor:IsVisible() and item:IsShown() and wanted and type(link) == "string" then
      local itemId = C_Item.GetItemInfoInstant(link)
      if itemId then
        -- the name, like a pick from the suggestions; the id while the client has not loaded the name yet
        local known = GetKnownName(itemId)
        local name = known and known[1] or C_Item.GetItemInfo(link) or link:match("%[(.-)%]")
        if name then
          suggestions[name:lower()] = itemId
        end
        item.box:SetText(name or tostring(itemId))
      end
    end
  end
  -- Retail hands the link to the auction house search box inside ChatFrameUtil.InsertLink, so that is the
  -- place to see it; Classic only has HandleModifiedItemClick
  if ChatFrameUtil and ChatFrameUtil.InsertLink then
    hooksecurefunc(ChatFrameUtil, "InsertLink", FillFromLink)
  end
  if HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", FillFromLink)
  end

  -- filter -------------------------------------------------------------------------------------------
  local filter = CreateFrame("Frame", nil, editor)
  filter:SetPoint("TOPLEFT", PADDING, -(PADDING + 34))
  filter:SetPoint("RIGHT", -PADDING, 0)
  filter:SetHeight(350)
  editor.filter = filter
  local ShowLook

  -- name and icon: the button shows both, a click opens the selector
  Label(filter, L["BARGAINS_NAME_ICON"], "TOPLEFT", filter, 0, 0)
  filter.look = CreateFrame("Button", nil, filter)
  filter.look:SetSize(28, 28)
  filter.look:SetPoint("TOPLEFT", 0, -16)
  filter.look.icon = filter.look:CreateTexture(nil, "ARTWORK")
  filter.look.icon:SetAllPoints()
  filter.look.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  filter.look:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  filter.look.text = Widgets.CreateText(filter, "GameFontHighlightSmall")
  filter.look.text:SetPoint("LEFT", filter.look, "RIGHT", 8, 0)
  filter.look.text:SetPoint("RIGHT", -8, 0)
  filter.look.text:SetJustifyH("LEFT")
  filter.look.text:SetWordWrap(false)
  Widgets.SetTooltip(filter.look, L["BARGAINS_NAME_ICON_TOOLTIP"])

  local yBelow = -50 -- the fields below the name and icon
  Label(filter, L["BARGAINS_CATEGORY"], "TOPLEFT", filter, 0, yBelow)
  filter.subLabel = Label(filter, L["BARGAINS_SUBCATEGORY"], "TOPLEFT", filter, 0, yBelow - 48)
  filter.subClass = CreateChoiceDropdown(filter, 200, function()
    -- the menu is built once at creation, when the category dropdown below does not exist yet
    return GetSubClasses(filter.class and filter.class.GetValue())
  end)
  filter.subClass:SetPoint("TOPLEFT", -2, yBelow - 64)
  filter.class = CreateChoiceDropdown(filter, 200, GetClasses, function()
    filter.subClass.SetValue(nil)
    ShowLook() -- the icon of the category, as long as none was picked
  end)
  filter.class:SetPoint("TOPLEFT", -2, yBelow - 16)

  local function LevelRow(label, y)
    Label(filter, label, "TOPLEFT", filter, 0, y)
    local from = CreateNumberBox(filter, 36)
    from:SetPoint("TOPLEFT", 120, y + 4)
    local to = Widgets.CreateText(filter, "GameFontHighlightSmall")
    to:SetPoint("LEFT", from, "RIGHT", 8, 0)
    to:SetText(L["BARGAINS_TO"])
    local upTo = CreateNumberBox(filter, 36)
    upTo:SetPoint("LEFT", to, "RIGHT", 10, 0)
    return from, upTo
  end
  filter.minLevel, filter.maxLevel = LevelRow(L["BARGAINS_LEVEL"], yBelow - 116)
  filter.minRequired, filter.maxRequired = LevelRow(L["BARGAINS_REQUIRED_LEVEL"], yBelow - 144)

  Label(filter, L["BARGAINS_QUALITY"], "TOPLEFT", filter, 0, yBelow - 176)
  filter.quality = CreateChoiceDropdown(filter, 200, function()
    local list = {}
    for _, quality in ipairs(QUALITIES) do
      local color = ITEM_QUALITY_COLORS[quality]
      list[#list + 1] = { value = quality, label = L["BARGAINS_QUALITY_MIN"]:format(
        color.hex .. _G["ITEM_QUALITY" .. quality .. "_DESC"] .. "|r") }
    end
    return list
  end)
  filter.quality:SetPoint("TOPLEFT", -2, yBelow - 192)
  Label(filter, L["BARGAINS_MAX_PRICE"], "TOPLEFT", filter, 0, yBelow - 228)
  filter.money = CreateMoneyInput(filter)
  filter.money:SetPoint("TOPLEFT", 90, yBelow - 232)
  local note = Widgets.CreateText(filter, "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", 0, yBelow - 260)
  note:SetPoint("RIGHT", -8, 0)
  note:SetText(L["BARGAINS_FILTER_HINT"])
  note:SetWordWrap(true)

  -- footer ---------------------------------------------------------------------------------------------
  editor.active = CreateFrame("CheckButton", nil, editor, "UICheckButtonTemplate")
  editor.active:SetSize(24, 24)
  editor.active:SetPoint("BOTTOMLEFT", PADDING, PADDING + FOOTER_HEIGHT + GAP)
  editor.active.text = Widgets.CreateText(editor, "GameFontHighlightSmall")
  editor.active.text:SetPoint("LEFT", editor.active, "RIGHT", 2, 0)
  editor.active.text:SetText(L["BARGAINS_ACTIVE"])

  editor.save = Widgets.CreateButton(editor, L["BARGAINS_SAVE"], true, function()
    editor.Save()
  end)
  editor.save:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
  editor.save:SetWidth(80)
  editor.cancel = Widgets.CreateButton(editor, L["BARGAINS_CANCEL"], false, function()
    BargainsPanel.CloseEditor()
  end)
  editor.cancel:SetPoint("RIGHT", editor.save, "LEFT", -GAP, 0)
  editor.cancel:SetWidth(80)
  editor.delete = Widgets.CreateButton(editor, L["BARGAINS_DELETE"], false, function()
    if rule and rule.id then
      Bargains.Remove(rule.id)
    end
    BargainsPanel.CloseEditor()
  end)
  editor.delete:SetPoint("BOTTOMLEFT", PADDING, PADDING)
  editor.delete:SetWidth(80)

  local function Number(box)
    return tonumber(box:GetText())
  end

  -- Writes what the filter fields select (category, levels, quality) into target.
  local function ReadFilter(target)
    target.classId = filter.class.GetValue()
    target.subClassId = target.classId and filter.subClass.GetValue() or nil
    target.minItemLevel, target.maxItemLevel = Number(filter.minLevel), Number(filter.maxLevel)
    target.minRequiredLevel, target.maxRequiredLevel = Number(filter.minRequired), Number(filter.maxRequired)
    target.minQuality = filter.quality.GetValue()
    return target
  end

  -- The icon and the name of the filter as they will be: the ones picked, else those of the category and what it selects
  -- (in grey).
  function ShowLook()
    local current = ReadFilter({})
    filter.look.icon:SetTexture(rule.icon or FilterIcon(current))
    filter.look.text:SetText(rule.name or Widgets.Color(GREY, Bargains.Describe(current)))
  end
  filter.look:SetScript("OnClick", function()
    local description = Bargains.Describe(ReadFilter({}))
    OpenIconPopup({
      name = rule.name or description,
      icon = rule.icon or FilterIcon(ReadFilter({})),
      onAccept = function(name, icon)
        -- the name of what the filter selects is no name of its own: it follows the fields
        rule.name = name ~= "" and name ~= description and name or nil
        rule.icon = icon or rule.icon
        ShowLook()
      end,
    })
  end)
  editor:SetScript("OnHide", function()
    if iconPopup then
      iconPopup:Hide()
    end
  end)

  function editor.SetType(ruleType)
    rule.type = ruleType
    item:SetShown(ruleType == "item")
    filter:SetShown(ruleType == "filter")
    editor.itemToggle:SetEnabled(ruleType ~= "item" and not Blocked("item"))
    editor.filterToggle:SetEnabled(ruleType ~= "filter" and not Blocked("filter"))
  end

  -- Fills the editor with a copy of the rule (a new item rule if nil).
  function editor.Load(existing)
    rule = existing and CopyTable(existing)
      or { type = Bargains.IsFull("item") and "filter" or "item", active = true }
    -- the name, as after a pick from the suggestions; the id while the client does not know the name
    local known = rule.itemId and GetKnownName(rule.itemId)
    if known then
      suggestions[known[2]] = rule.itemId
    end
    item.box:SetText(known and known[1] or rule.itemId and tostring(rule.itemId) or "")
    item.box:ClearFocus()
    item.money.SetCopper(rule.type == "item" and rule.maxPrice or 0)
    item.percent:SetText(tostring(rule.percent or 70))
    SetShare(rule.percent ~= nil)
    filter.class.SetValue(rule.classId)
    filter.subClass.SetValue(rule.subClassId)
    filter.minLevel:SetText(rule.minItemLevel and tostring(rule.minItemLevel) or "")
    filter.maxLevel:SetText(rule.maxItemLevel and tostring(rule.maxItemLevel) or "")
    filter.minRequired:SetText(rule.minRequiredLevel and tostring(rule.minRequiredLevel) or "")
    filter.maxRequired:SetText(rule.maxRequiredLevel and tostring(rule.maxRequiredLevel) or "")
    filter.quality.SetValue(rule.minQuality)
    filter.money.SetCopper(rule.type == "filter" and rule.maxPrice or 0)
    editor.active:SetChecked(rule.active)
    editor.delete:SetShown(rule.id ~= nil)
    LoadNames()
    editor.SetType(rule.type)
    ShowItem()
    ShowLook()
  end

  -- Takes the fields into the rule and saves it. Does nothing where the rule is not complete: an item that is not
  -- known, or no maximum price (a rule without one would match nothing, or everything).
  function editor.Save()
    local saved = { id = rule.id, type = rule.type, active = editor.active:GetChecked() and true or false }
    if rule.type == "item" then
      if not item.itemId then
        return
      end
      saved.itemId = item.itemId
      if item.share:GetChecked() then
        saved.percent = Number(item.percent)
        if not saved.percent or saved.percent <= 0 then
          return
        end
      else
        saved.maxPrice = item.money.GetCopper()
        if saved.maxPrice <= 0 then
          return
        end
      end
    else
      saved.maxPrice = filter.money.GetCopper()
      if saved.maxPrice <= 0 then
        return
      end
      ReadFilter(saved)
      saved.name, saved.icon = rule.name, rule.icon
    end
    Bargains.Save(saved)
    BargainsPanel.CloseEditor()
  end
  return editor
end

-- Opens the editor for the rule, a new one if nil.
function BargainsPanel.Edit(rule)
  if not view then
    return
  end
  view.editor.Load(rule)
  view.main:Hide()
  view.editor:Show()
end

function BargainsPanel.CloseEditor()
  if view then
    view.editor:Hide()
    view.main:Show()
    BargainsPanel.Update()
  end
end

-- Main view ----------------------------------------------------------------------------------------

-- Creates the content of the tab in parent (a frame the caller sizes and shows). BargainsPanel.Update() redraws it.
function BargainsPanel.Create(parent)
  view = CreateFrame("Frame", nil, parent)
  view:SetAllPoints()
  local main = CreateFrame("Frame", nil, view)
  main:SetAllPoints()
  view.main = main

  local new = Widgets.CreateSecondaryButton(main, L["BARGAINS_NEW"], function()
    BargainsPanel.Edit(nil)
  end)
  view.new = new
  new:SetHeight(FOOTER_HEIGHT - 2) -- the strip below the list is as narrow as the auction house's
  new:SetLabel(L["BARGAINS_NEW"], BUTTON_PADDING) -- as wide as its text, which is longer in some languages
  new:SetMotionScriptsWhileDisabled(true) -- else a greyed out button shows no tooltip
  Widgets.SetTooltip(new, function()
    return Bargains.IsFull("item") and Bargains.IsFull("filter")
        and L["BARGAINS_LIMIT_ALL"]:format(Bargains.MAX_ITEM_RULES, Bargains.MAX_FILTER_RULES)
      or L["BARGAINS_NEW"]
  end)
  local sinceUpdate, sinceRedraw = 0, 0
  view:SetScript("OnUpdate", function(_, elapsed)
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < 1 then
      return
    end
    sinceRedraw = sinceRedraw + sinceUpdate
    sinceUpdate = 0
    UpdateAge() -- the count of the search or scan that runs
    if sinceRedraw >= 30 then
      -- the age of the full scan on the filter header, and the results that ran out
      sinceRedraw = 0
      BargainsPanel.Update()
    end
  end)

  new:SetPoint("BOTTOMRIGHT", -PADDING, FOOTER_PAD - 1)
  view.age = Widgets.CreateText(main, "GameFontHighlightSmall")
  view.age:SetPoint("LEFT", main, "BOTTOMLEFT", PADDING, FOOTER_PAD + FOOTER_HEIGHT / 2 - 2)
  view.age:SetPoint("RIGHT", new, "LEFT", -GAP, 0)
  view.age:SetJustifyH("LEFT")
  view.age:SetWordWrap(false)

  view.list = AM.Attachment.CreateList(main, PADDING, FOOTER_PAD + FOOTER_HEIGHT, CreateRow, SetupRow)

  view.editor = CreateEditor(view)
  view.editor:SetPoint("TOPLEFT", 8, -PADDING) -- the sides of the list
  view.editor:SetPoint("BOTTOMRIGHT", -(AM.Native.ScrollGutter() + 2), PADDING)
  return view
end

-- Redraws the list while the main part is shown (the editor keeps what the player typed).
function BargainsPanel.Update()
  if not view or not view.main:IsShown() then
    return
  end
  view.list.SetItems(BuildItems())
  UpdateAge()
  view.new:SetEnabled(not (Bargains.IsFull("item") and Bargains.IsFull("filter")))
end

-- Back to the list, as the panel was left (the editor is dropped).
function BargainsPanel.Reset()
  if view and view.editor:IsShown() then
    BargainsPanel.CloseEditor()
  end
end
