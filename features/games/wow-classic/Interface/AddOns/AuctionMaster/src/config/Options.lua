local addonName, AM = ...

local L = AM.L

local COGWHEEL = "Interface/Buttons/UI-OptionsButton"

-- Switches the options panel and the cogwheel button off while there are no settings to show.
local HAS_OPTIONS = true

AM.Options = {}
local Options = AM.Options

-- Both pages are canvases we draw ourselves. The game's vertical layout is deliberately not used: it adds
-- a native "Defaults" button that can reset settings outside of AuctionMaster (see CLAUDE.md).
local HAS_LAYOUT = Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterCanvasLayoutSubcategory and true
  or false

local ASSETS = "Interface\\AddOns\\" .. addonName .. "\\assets\\"

local category

-- A section header with a thin line below it.
local function CreateHeader(panel, text, anchor, x, y)
  local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
  header:SetText(text)
  local line = panel:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 1, 1, 0.2)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
  line:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  return header, line
end

-- The game's settings panel has one "Defaults" button for all pages. Its "All settings" choice resets the
-- whole game, so it is hidden while one of our pages is shown and put back as soon as none is (see CLAUDE.md).
local pages = {}

local function DefaultsButton()
  local list = SettingsPanel and SettingsPanel.GetSettingsList and SettingsPanel:GetSettingsList()
  return list and list.Header and list.Header.DefaultsButton
end

local function HideDefaultsWhileShown(panel)
  pages[#pages + 1] = panel
  panel:HookScript("OnShow", function()
    local button = DefaultsButton()
    if button then
      button:Hide()
    end
  end)
  panel:HookScript("OnHide", function()
    -- Switching between two of our pages shows the new one before the old one is hidden.
    C_Timer.After(0, function()
      for _, page in ipairs(pages) do
        if page:IsVisible() then
          return
        end
      end
      local button = DefaultsButton()
      if button then
        button:Show()
      end
    end)
  end)
end

-- The main page: logo with name, a subtitle, the button of the changelog and the link to the Discord.
local function CreateMainPanel()
  local panel = CreateFrame("Frame", nil, SettingsPanel)
  panel.name = addonName

  local logo = panel:CreateTexture(nil, "ARTWORK")
  logo:SetSize(36, 36)
  logo:SetPoint("TOPLEFT", 16, -16)
  logo:SetTexture(ASSETS .. "logo")

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
  title:SetText(addonName)

  local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  subtitle:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -12)
  subtitle:SetText(L["OPTIONS_SUBTITLE"])

  local changelogButton = AM.Widgets.CreateButton(panel, L["OPTIONS_SHOW_CHANGELOG"], false, function()
    AM.ChangelogWindow.Show()
  end)
  changelogButton:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 4, -24)

  -- Footer: the game cannot write to the clipboard, so the link is selected for Ctrl+C. Typing is undone.
  local discordLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  discordLabel:SetPoint("BOTTOMLEFT", 16, 40)
  discordLabel:SetText(L["OPTIONS_DISCORD"])
  local discordBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  discordBox:SetSize(260, 20)
  discordBox:SetPoint("TOPLEFT", discordLabel, "BOTTOMLEFT", 6, -4)
  discordBox:SetAutoFocus(false)
  discordBox:SetText(AM.DiscordPopup.URL)
  discordBox:SetCursorPosition(0)
  discordBox:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
  end)
  discordBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      self:SetText(AM.DiscordPopup.URL)
      self:HighlightText()
    end
  end)
  discordBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  discordBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  local discordHint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  discordHint:SetPoint("LEFT", discordBox, "RIGHT", 8, 0)
  discordHint:SetText(L["OPTIONS_DISCORD_HINT"])

  panel:Hide()
  HideDefaultsWhileShown(panel)
  return panel
end

-- The "Display" page: what AuctionMaster shows in the game's own windows and tooltips.
local function CreateDisplayPanel()
  local panel = CreateFrame("Frame", nil, SettingsPanel)
  panel.name = L["OPTIONS_DISPLAY"]

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L["OPTIONS_DISPLAY"])

  local tooltipHeader = CreateHeader(panel, L["OPTIONS_TOOLTIP"], title, 0, -20)

  -- How much market data item tooltips show.
  local tooltipLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  tooltipLabel:SetPoint("TOPLEFT", tooltipHeader, "BOTTOMLEFT", 0, -24)
  tooltipLabel:SetText(L["OPTIONS_MARKET_TOOLTIP"])
  local tooltipDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
  tooltipDropdown:SetWidth(120)
  tooltipDropdown:SetPoint("LEFT", tooltipLabel, "RIGHT", 12, 0)
  tooltipDropdown:SetupMenu(function(_, root)
    for _, mode in ipairs(AM.Tooltip.MARKET_MODES) do
      root:CreateRadio(L["OPTIONS_MARKET_TOOLTIP_" .. strupper(mode)], function()
        return AM.Tooltip.GetMarketMode() == mode
      end, function()
        AM.Tooltip.SetMarketMode(mode)
      end)
    end
  end)
  tooltipDropdown:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["OPTIONS_MARKET_TOOLTIP"], 1, 1, 1)
    GameTooltip:AddLine(L["OPTIONS_MARKET_TOOLTIP_TOOLTIP"], nil, nil, nil, true)
    GameTooltip:Show()
  end)
  tooltipDropdown:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  -- Whether the tooltip shows stack or single item prices (Alt shows the other kind).
  local priceLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  priceLabel:SetPoint("TOPLEFT", tooltipLabel, "BOTTOMLEFT", 0, -28)
  priceLabel:SetText(L["OPTIONS_PRICE_TOOLTIP"])
  -- The dropdowns of the group start at the same distance, behind the widest label.
  local dropdownOffset = math.max(tooltipLabel:GetStringWidth(), priceLabel:GetStringWidth()) + 12
  tooltipDropdown:ClearAllPoints()
  tooltipDropdown:SetPoint("LEFT", tooltipLabel, "LEFT", dropdownOffset, 0)
  local priceDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
  priceDropdown:SetWidth(120)
  priceDropdown:SetPoint("LEFT", priceLabel, "LEFT", dropdownOffset, 0)
  priceDropdown:SetupMenu(function(_, root)
    for _, mode in ipairs(AM.Tooltip.PRICE_MODES) do
      root:CreateRadio(L["OPTIONS_PRICE_TOOLTIP_" .. strupper(mode)], function()
        return AM.Tooltip.GetPriceMode() == mode
      end, function()
        AM.Tooltip.SetPriceMode(mode)
      end)
    end
  end)
  priceDropdown:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["OPTIONS_PRICE_TOOLTIP"], 1, 1, 1)
    GameTooltip:AddLine(L["OPTIONS_PRICE_TOOLTIP_TOOLTIP"], nil, nil, nil, true)
    GameTooltip:Show()
  end)
  priceDropdown:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  -- Whether the tooltip lists what disenchanting the item yields.
  local disenchantCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  disenchantCheck:SetPoint("TOPLEFT", priceLabel, "BOTTOMLEFT", -4, -16)
  local disenchantLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  disenchantLabel:SetPoint("LEFT", disenchantCheck, "RIGHT", 4, 0)
  disenchantLabel:SetText(L["OPTIONS_DISENCHANT_TOOLTIP"])
  disenchantCheck:SetScript("OnClick", function(self)
    AM.Disenchant.SetTooltipEnabled(self:GetChecked())
  end)
  disenchantCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["OPTIONS_DISENCHANT_TOOLTIP"], 1, 1, 1)
    GameTooltip:AddLine(L["OPTIONS_DISENCHANT_TOOLTIP_TOOLTIP"], nil, nil, nil, true)
    GameTooltip:Show()
  end)
  disenchantCheck:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  -- What AuctionMaster adds to the game's profession window.
  local professionHeader = CreateHeader(panel, L["OPTIONS_PROFESSION"], disenchantCheck, 4, -16)
  local levelingCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  levelingCheck:SetPoint("TOPLEFT", professionHeader, "BOTTOMLEFT", -4, -16)
  local levelingLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  levelingLabel:SetPoint("LEFT", levelingCheck, "RIGHT", 4, 0)
  levelingLabel:SetText(L["OPTIONS_LEVELING"])
  levelingCheck:SetScript("OnClick", function(self)
    AM.Leveling.SetEnabled(self:GetChecked())
  end)
  levelingCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["OPTIONS_LEVELING"], 1, 1, 1)
    GameTooltip:AddLine(L["OPTIONS_LEVELING_TOOLTIP"], nil, nil, nil, true)
    GameTooltip:Show()
  end)
  levelingCheck:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local function Refresh()
    disenchantCheck:SetChecked(AM.Disenchant.IsTooltipEnabled())
    levelingCheck:SetChecked(AM.Leveling.IsEnabled())
    tooltipDropdown:GenerateMenu()
    priceDropdown:GenerateMenu()
  end
  panel:SetScript("OnShow", Refresh)
  panel.OnRefresh = Refresh

  panel:Hide()
  HideDefaultsWhileShown(panel)
  return panel
end

-- The popup texts are set in OnReady below, as the language is only known once the saved variables are loaded.
-- Resets only the market price percentages of AuctionMaster, after asking.
StaticPopupDialogs["AUCTIONMASTER_RESET_MARKET"] = {
  text = "",
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    AM.ItemStore.ResetPercents()
    if AM.Options.RefreshMarket then
      AM.Options.RefreshMarket()
    end
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

-- Deletes only the gathered market prices of the current faction, after asking.
StaticPopupDialogs["AUCTIONMASTER_RESET_MARKET_PRICES"] = {
  text = "",
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    AM.ItemStore.ResetMarketPrices()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

-- The game opens its popups near the top of the screen, far from the settings page. Ours is
-- moved to the middle of the settings window. Only this one popup frame is moved, while it is
-- showing our dialog; the game positions it again the next time it shows anything.
local function ShowConfirm(dialog)
  local popup = StaticPopup_Show(dialog)
  if popup and SettingsPanel then
    popup:ClearAllPoints()
    popup:SetPoint("CENTER", SettingsPanel, "CENTER")
  end
end

-- Number inputs on a page of ours. Returns CreateNumberRow(anchor, x, y, labelKey, maxLetters, suffixText, get, set),
-- AlignInputs() (call once all rows exist) and RefreshAll().
local function CreateNumberRows(panel)
  local refreshers, labels, inputs = {}, {}, {}
  -- A label with a numeric input right of it below anchor; get() returns the shown value and set(value)
  -- stores a typed one. The inputs are lined up in a column below.
  local function CreateNumberRow(anchor, x, y, labelKey, maxLetters, suffixText, get, set)
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
    label:SetText(L[labelKey])

    local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    input:SetSize(maxLetters > 2 and 48 or 40, 20)
    input:SetAutoFocus(false)
    input:SetNumeric(true)
    input:SetMaxLetters(maxLetters)
    input:SetJustifyH("CENTER")
    local suffix = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    suffix:SetPoint("LEFT", input, "RIGHT", 4, 0)
    suffix:SetText(suffixText)

    local function Refresh()
      input:SetText(tostring(get()))
      input:SetCursorPosition(0)
    end
    local function Commit()
      local value = tonumber(input:GetText())
      if value then
        set(value)
      end
      Refresh()
    end
    input:SetScript("OnEnterPressed", function(self)
      Commit()
      self:ClearFocus()
    end)
    input:SetScript("OnEditFocusLost", Commit)
    input:SetScript("OnEscapePressed", function(self)
      Refresh()
      self:ClearFocus()
    end)
    input:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(L[labelKey], 1, 1, 1)
      GameTooltip:AddLine(L[labelKey .. "_TOOLTIP"], nil, nil, nil, true)
      GameTooltip:Show()
    end)
    input:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    refreshers[#refreshers + 1] = Refresh
    labels[#labels + 1] = label
    inputs[#inputs + 1] = input
    return label
  end

  -- The inputs form a column right of the longest label.
  local function AlignInputs()
    local labelWidth = 0
    for _, label in ipairs(labels) do
      labelWidth = math.max(labelWidth, label:GetStringWidth())
    end
    for i, input in ipairs(inputs) do
      input:SetPoint("LEFT", labels[i], "LEFT", labelWidth + 16, 0)
    end
  end

  local function RefreshAll()
    for _, Refresh in ipairs(refreshers) do
      Refresh()
    end
  end
  return CreateNumberRow, AlignInputs, RefreshAll
end

-- The "Market price" page: one percentage input per entry of ItemStore.GROUPS, then the numbers of ItemStore.NUMBERS.
local function CreateMarketPanel()
  local panel = CreateFrame("Frame", nil, SettingsPanel)
  panel.name = L["OPTIONS_MARKET_PRICE"]

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L["OPTIONS_MARKET_PRICE"])

  local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
  hint:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  hint:SetJustifyH("LEFT")
  hint:SetText(L["OPTIONS_MARKET_HINT"])

  local CreateNumberRow, AlignInputs, RefreshAll = CreateNumberRows(panel)

  local anchor = hint
  for _, group in ipairs(AM.ItemStore.GROUPS) do
    anchor = CreateNumberRow(anchor, 0, -16, "OPTIONS_GROUP_" .. strupper(group.id), 2, "%",
      function() return AM.ItemStore.GetPercent(group) end,
      function(value) AM.ItemStore.SetPercent(group, value) end)
  end

  -- The settings that are not about the market price itself.
  local _, line = CreateHeader(panel, L["OPTIONS_PRICES_FILTERS"], anchor, 0, -24)
  anchor = CreateNumberRow(line, 0, -12, "OPTIONS_FRESH_MINUTES", 3, L["OPTIONS_MINUTES"],
    function() return AM.ItemStore.GetNumber("freshMinutes") end,
    function(value) AM.ItemStore.SetNumber("freshMinutes", value) end)
  anchor = CreateNumberRow(anchor, 0, -16, "OPTIONS_RARE_COUNT", 2, L["OPTIONS_PER_SCAN"],
    function() return AM.ItemStore.GetNumber("rareCount") end,
    function(value) AM.ItemStore.SetNumber("rareCount", value) end)

  AlignInputs()

  -- Only the settings above are reset, nothing else, and only after confirming.
  local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  resetButton:SetSize(190, 22)
  resetButton:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -24)
  resetButton:SetText(L["OPTIONS_RESET"])
  resetButton:SetScript("OnClick", function()
    ShowConfirm("AUCTIONMASTER_RESET_MARKET")
  end)

  local resetPricesButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  resetPricesButton:SetSize(160, 22)
  resetPricesButton:SetPoint("LEFT", resetButton, "RIGHT", 8, 0)
  resetPricesButton:SetText(L["OPTIONS_RESET_PRICES"])
  resetPricesButton:SetScript("OnClick", function()
    ShowConfirm("AUCTIONMASTER_RESET_MARKET_PRICES")
  end)

  Options.RefreshMarket = RefreshAll
  -- Filled again a frame later: the game's settings panel lays the page out right after showing it, which can
  -- leave the inputs blank when they were filled in OnShow only.
  panel:SetScript("OnShow", function()
    RefreshAll()
    C_Timer.After(0, RefreshAll)
  end)
  -- Called by the game's settings panel whenever it shows a canvas page, whether or not OnShow fires.
  panel.OnRefresh = RefreshAll
  -- A parentless frame counts as shown, so the game's Show() would not fire OnShow when it adopts the page.
  panel:Hide()
  HideDefaultsWhileShown(panel)
  return panel
end

-- The "Sell" page.
local function CreateSellPanel()
  local panel = CreateFrame("Frame", nil, SettingsPanel)
  panel.name = L["OPTIONS_SELL"]

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L["OPTIONS_SELL"])

  local CreateNumberRow, AlignInputs, RefreshAll = CreateNumberRows(panel)
  local anchor = CreateNumberRow(title, 0, -24, "OPTIONS_MARGIN", 3, "%",
    function() return AM.SellSettings.GetNumber("noCompetitionMargin") end,
    function(value) AM.SellSettings.SetNumber("noCompetitionMargin", value) end)

  -- How bad an undercut in the Auctions view is: fine (not marked), warning (orange), above that too much (red).
  local _, line = CreateHeader(panel, L["OPTIONS_UNDERCUT"], anchor, 0, -24)
  local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  hint:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -8)
  hint:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  hint:SetJustifyH("LEFT")
  hint:SetText(L["OPTIONS_UNDERCUT_HINT"])
  anchor = hint
  for _, row in ipairs({
    { "OPTIONS_UNDERCUT_AUCTIONS_OK", "undercutAuctionsOk", "OPTIONS_UNDERCUT_AUCTIONS" },
    { "OPTIONS_UNDERCUT_AUCTIONS_WARN", "undercutAuctionsWarn", "OPTIONS_UNDERCUT_AUCTIONS" },
    { "OPTIONS_UNDERCUT_PERCENT_OK", "undercutPercentOk", "OPTIONS_UNDERCUT_PERCENT" },
    { "OPTIONS_UNDERCUT_PERCENT_WARN", "undercutPercentWarn", "OPTIONS_UNDERCUT_PERCENT" },
  }) do
    anchor = CreateNumberRow(anchor, 0, -12, row[1], 3, L[row[3]],
      function() return AM.SellSettings.GetNumber(row[2]) end,
      function(value) AM.SellSettings.SetNumber(row[2], value) end)
  end
  AlignInputs()

  panel:SetScript("OnShow", function()
    RefreshAll()
    C_Timer.After(0, RefreshAll)
  end)
  panel.OnRefresh = RefreshAll
  panel:Hide()
  HideDefaultsWhileShown(panel)
  return panel
end

function Options.Open()
  if category then
    Settings.OpenToCategory(category:GetID())
  end
end

-- Adds the cogwheel next to the close button of the frame (the auction house), once.
function Options.CreateButton(parent)
  if not category or not parent or parent.AuctionMasterOptionsButton then
    return
  end
  local cogwheel = AM.Native.CreateTitleButton(parent)
  parent.AuctionMasterOptionsButton = cogwheel -- also where the handles of the side panels line up
  local close = parent.CloseButton
  if close then
    cogwheel:SetPoint("RIGHT", close, "LEFT", AM.Native.TitleButtonNudge(), 0)
  else
    cogwheel:SetPoint("TOPRIGHT", -26, -4)
  end
  cogwheel.icon:SetTexture(COGWHEEL)
  cogwheel:SetScript("OnClick", Options.Open)
  cogwheel:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["TOOLTIP_OPEN_OPTIONS"])
    GameTooltip:Show()
  end)
  cogwheel:HookScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

-- Everything with texts is built once the language is known (see AM.Locale).
AM.Locale.OnReady(function()
  StaticPopupDialogs["AUCTIONMASTER_RESET_MARKET"].text = L["OPTIONS_RESET_CONFIRM"]
  StaticPopupDialogs["AUCTIONMASTER_RESET_MARKET_PRICES"].text = L["OPTIONS_RESET_PRICES_CONFIRM"]
  if HAS_OPTIONS and HAS_LAYOUT then
    category = Settings.RegisterCanvasLayoutCategory(CreateMainPanel(), addonName)
    -- The subpages are listed alphabetically in the language of the client.
    local subpages = { CreateDisplayPanel(), CreateMarketPanel(), CreateSellPanel() }
    table.sort(subpages, function(a, b)
      return strcmputf8i(a.name, b.name) < 0
    end)
    for _, subpage in ipairs(subpages) do
      Settings.RegisterCanvasLayoutSubcategory(category, subpage, subpage.name)
    end
    Settings.RegisterAddOnCategory(category)
  end
end)
