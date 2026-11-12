local addonName, AM = ...
local L = AM.L

-- Classic: the recipes to craft as a group pinned on top of the recipe list of the profession window, the recipes of the
-- shopping list of the current character that belong to the open profession, the intermediate products first. The
-- game's list has a fixed set of buttons and cannot take a category, so the group sits above them and the game's list
-- gets that many rows less (laid out again after each of its updates, see Relayout). A click selects the recipe in the
-- window. Below it sits a second group with the cheap ways to level the profession (Leveling.lua), with the cost of the
-- reagents at the right and an icon after it for what to do with the result. Retail and Forever pin them as
-- categories of their list instead (see CraftList.lua).
AM.CraftPanel = {}
local CraftPanel = AM.CraftPanel
local ShoppingList = AM.ShoppingList

local ROW_HEIGHT = 16 -- TRADE_SKILL_HEIGHT
local LIST_X, LIST_Y, LIST_WIDTH = 22, -96, 293 -- where the game places its list (Blizzard_TradeSkillUI.xml)
local SCROLL_RIGHT = -67
local MIN_GAME_ROWS = 3 -- rows of the game's list that stay, however many recipes there are
local READY_COLOR = { 0.1, 1, 0.1 }
local TIP_SIZE = 12
local CHECK_ICON = "|TInterface\\Buttons\\UI-CheckBox-Check:12:12:0:0|t "

local group -- the frame of the group, created with the first recipe
local state -- global object `craftPanel`: { collapsed, levelingCollapsed }
local shownRows = 0 -- rows of the group, 0 while it is hidden
local installed = false
local refreshPending = false
local scrollHeight -- height of the game's scroll frame as the game has it

local function GetHost()
  return not ShoppingList.IsRetail() and TradeSkillFrame or nil
end

-- The recipes of the open profession as { has = function(recipe), select = function(recipe), selected = function()
-- returning the id of the recipe selected or nil }. The window lists a recipe only below an expanded header; its id is
-- the one ReadClassicRecipe makes (the name where the game gives no link).
local function ReadClassicProfession()
  local byId = {}
  for index = 1, GetNumTradeSkills() do
    local name, skillType = GetTradeSkillInfo(index)
    if name and skillType ~= "header" and skillType ~= "subheader" then
      local link = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(index)
      byId[link and tonumber(link:match("enchant:(%d+)")) or name] = index
    end
  end
  return {
    has = function(recipe)
      return byId[recipe.id] ~= nil
    end,
    select = function(recipe)
      local index = byId[recipe.id]
      if index then
        TradeSkillFrame_SetSelection(index)
        TradeSkillFrame_Update(TradeSkillFrame)
      end
    end,
    selected = function()
      local selected = GetTradeSkillSelectionIndex()
      for id, index in pairs(byId) do
        if index == selected then
          return id
        end
      end
    end,
  }
end

-- The entries of the group: the shopping list (the intermediate products first, then the recipes, those the open
-- profession lists), then the suggestions for leveling. Each part starts with a header { header = title, key = the field
-- of `state` that folds it, total }.
local function Collect()
  if not ShoppingList.IsOwnCrafting() then
    return nil
  end
  local profession = ReadClassicProfession()
  local model = ShoppingList.BuildModel(ShoppingList.GetList(UnitGUID("player")))
  local selected = profession.selected()
  local found = {}
  for _, recipes in ipairs({ model.intermediates, model.recipes }) do
    for _, recipe in ipairs(recipes) do
      if profession.has(recipe) then
        found[#found + 1] = { recipe = recipe, active = recipe.id == selected, select = profession.select }
      end
    end
  end
  local items = {}
  if #found > 0 then
    items[1] = { header = L["CRAFT_TITLE"], key = "collapsed", total = #found }
    for _, item in ipairs(found) do
      items[#items + 1] = item
    end
  end
  local suggestions = {}
  for _, suggestion in ipairs(AM.Leveling.GetSuggestions()) do
    if profession.has(suggestion.recipe) then
      suggestions[#suggestions + 1] = { recipe = suggestion.recipe, suggestion = suggestion,
        active = suggestion.recipe.id == selected, select = profession.select }
    end
  end
  if #suggestions > 0 then
    items[#items + 1] = { header = L["LEVELING_TITLE"], key = "levelingCollapsed", total = #suggestions }
    for _, item in ipairs(suggestions) do
      items[#items + 1] = item
    end
  end
  return #items > 0 and items or nil
end

local function CreateRow()
  local row = CreateFrame("Button", nil, group)
  row:SetHeight(ROW_HEIGHT)
  row:SetPoint("RIGHT", group)
  row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
  row.selected = row:CreateTexture(nil, "BACKGROUND")
  row.selected:SetAllPoints()
  row.selected:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
  row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.count:SetPoint("RIGHT", -4, 0)
  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)
  row.tip = CreateFrame("Frame", nil, row)
  row.tip:SetSize(TIP_SIZE, TIP_SIZE)
  row.tip:EnableMouse(true)
  row.tip.icon = row.tip:CreateTexture(nil, "OVERLAY")
  row.tip.icon:SetAllPoints()
  row.tip:SetScript("OnEnter", function(self)
    AM.Leveling.ShowTooltip(self, self.suggestion)
  end)
  row.tip:SetScript("OnLeave", GameTooltip_Hide)
  row:SetScript("OnClick", function(self)
    local item = self.item
    if item and item.header then
      state[item.key] = not state[item.key]
      CraftPanel.Update()
    elseif item then
      item.select(item.recipe)
    end
  end)
  return row
end

local function Create(host)
  state = AM.Database.GetGlobalObject("craftPanel", { collapsed = false, levelingCollapsed = false })
  group = CreateFrame("Frame", nil, host)
  group:SetPoint("TOPLEFT", host, "TOPLEFT", LIST_X, LIST_Y)
  group:SetWidth(LIST_WIDTH)
  group.rows = {}
end

local function SetupHeader(row, item)
  row.item = item
  row.selected:Hide()
  row.count:Hide()
  row.tip:Hide()
  row.name:SetFontObject(GameFontNormal)
  row.name:SetTextColor(1, 0.82, 0)
  row.name:SetText(item.header .. " (" .. item.total .. ")")
  row.name:ClearAllPoints()
  row.name:SetPoint("LEFT", 23, 0)
  row.name:SetPoint("RIGHT", -4, 0)
  row:SetNormalTexture(state[item.key] and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
  local icon = row:GetNormalTexture()
  icon:ClearAllPoints()
  icon:SetPoint("LEFT", 3, 0)
  icon:SetSize(16, 16)
end

local function SetupRecipe(row, item)
  local recipe = item.recipe
  row.item = item
  row:ClearNormalTexture()
  row.selected:SetShown(item.active)
  row.selected:SetVertexColor(1, 0.82, 0, 0.6)
  row.name:SetFontObject(GameFontHighlight)
  if recipe.ready then
    row.name:SetTextColor(unpack(READY_COLOR))
  else
    row.name:SetTextColor(1, 1, 1)
  end
  row.name:SetText((recipe.ready and CHECK_ICON or "") .. recipe.name)
  row.name:ClearAllPoints()
  row.name:SetPoint("LEFT", 23, 0)
  local suggestion = item.suggestion
  if suggestion then
    -- the icon of what to do with the result sits after the cost
    row.tip.suggestion = suggestion
    AM.Leveling.SetTipIcon(row.tip.icon, suggestion.tip)
    row.tip:ClearAllPoints()
    row.tip:SetPoint("RIGHT", -4, 0)
    row.tip:Show()
    row.count:ClearAllPoints()
    row.count:SetPoint("RIGHT", row.tip, "LEFT", -4, 0)
    row.count:SetText(AM.FormatMoney(suggestion.cost, true))
  else
    row.count:ClearAllPoints()
    row.count:SetPoint("RIGHT", -4, 0)
    row.count:SetText("×" .. recipe.qty)
    row.tip:Hide()
  end
  row.name:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
  row.count:Show()
end

-- The headers and as many recipes as the window can spare, the others stay on the shopping list. The recipes of a
-- folded part are left out.
local function Draw(items)
  local shown = {}
  local folded = false
  for _, item in ipairs(items) do
    if item.header then
      folded = state[item.key]
      shown[#shown + 1] = item
    elseif not folded then
      shown[#shown + 1] = item
    end
  end
  shownRows = math.min(#shown, TRADE_SKILLS_DISPLAYED - MIN_GAME_ROWS)
  for i = 1, shownRows do
    local row = group.rows[i]
    if not row then
      row = CreateRow()
      group.rows[i] = row
      row:SetPoint("TOPLEFT", group, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    end
    row:Show()
    if shown[i].header then
      SetupHeader(row, shown[i])
    else
      SetupRecipe(row, shown[i])
    end
  end
  for i = shownRows + 1, #group.rows do
    group.rows[i]:Hide()
  end
  group:SetHeight(shownRows * ROW_HEIGHT)
end

-- The game fills its buttons from the top of the list on every update: move them below the group, hide the ones that
-- no longer fit and tell the scroll bar. With no group everything is put back as the game has it.
local function Relayout()
  local rows = group and group:IsShown() and shownRows or 0
  local displayed = TRADE_SKILLS_DISPLAYED - rows
  scrollHeight = scrollHeight or TradeSkillListScrollFrame:GetHeight()
  TradeSkillSkill1:ClearAllPoints()
  TradeSkillSkill1:SetPoint("TOPLEFT", TradeSkillFrame, "TOPLEFT", LIST_X, LIST_Y - rows * ROW_HEIGHT)
  TradeSkillListScrollFrame:SetHeight(scrollHeight - rows * ROW_HEIGHT)
  TradeSkillListScrollFrame:ClearAllPoints()
  TradeSkillListScrollFrame:SetPoint("TOPRIGHT", TradeSkillFrame, "TOPRIGHT", SCROLL_RIGHT, LIST_Y - rows * ROW_HEIGHT)
  if rows == 0 then
    return
  end
  for i = displayed + 1, TRADE_SKILLS_DISPLAYED do
    _G["TradeSkillSkill" .. i]:Hide()
  end
  FauxScrollFrame_Update(TradeSkillListScrollFrame, GetNumTradeSkills(), displayed, ROW_HEIGHT, nil, nil, nil,
    TradeSkillHighlightFrame, 293, 316, true)
  -- the selected recipe may be on a button that is hidden now
  local _, relativeTo = TradeSkillHighlightFrame:GetPoint()
  if relativeTo and not relativeTo:IsShown() then
    TradeSkillHighlightFrame:Hide()
  end
end

-- Shows, hides or redraws the group as the situation asks. Cheap enough to be called on every change that might matter.
function CraftPanel.Update()
  local host = GetHost()
  if not host then
    return
  end
  local items = host:IsShown() and Collect() or nil
  if items and not group then
    Create(host)
  end
  if not group then
    return
  end
  group:SetShown(items ~= nil)
  if items then
    Draw(items)
  end
  if host:IsShown() then
    TradeSkillFrame_Update(host)
  end
end

-- Item names, bags and the list of recipes change in bursts, so redraw once for all of them.
local function UpdateSoon()
  local host = GetHost()
  if refreshPending or not (host and host:IsShown()) then
    return
  end
  refreshPending = true
  C_Timer.After(0.2, function()
    refreshPending = false
    CraftPanel.Update()
  end)
end

-- The profession window is load on demand: hooked once it exists.
local function Install()
  local host = GetHost()
  if installed or not host or not TradeSkillFrame_Update then
    return
  end
  installed = true
  host:HookScript("OnShow", function()
    -- the window is laid out a moment later
    C_Timer.After(0, CraftPanel.Update)
  end)
  hooksecurefunc("TradeSkillFrame_Update", Relayout)
  if TradeSkillFrame_SetSelection then
    hooksecurefunc("TradeSkillFrame_SetSelection", CraftPanel.Update)
  end
end

if ShoppingList.IsSupported() and not ShoppingList.IsRetail() then
  local events = CreateFrame("Frame")
  events:RegisterEvent("ADDON_LOADED")
  events:RegisterEvent("PLAYER_LOGIN")
  events:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
  events:RegisterEvent("BAG_UPDATE_DELAYED")
  events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  events:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
      Install()
    else
      UpdateSoon()
    end
  end)

  -- A scan, a search or a setting changed the prices; a scan or a deleted character changed the crafters.
  AM.Events.Register("PRICES_CHANGED", CraftPanel.Update)
  AM.Events.Register("CRAFTERS_CHANGED", CraftPanel.Update)
end
