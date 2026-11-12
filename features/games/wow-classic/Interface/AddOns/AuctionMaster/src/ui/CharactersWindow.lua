local addonName, AM = ...

local L = AM.L

-- The window to manage the characters AuctionMaster knows (the button next to the character filter of the
-- recipes list): every character with its professions. A box unticked ignores that profession (or, on the
-- character, the whole character): the recipes stay recorded but count for nothing, see
-- AM.ProfessionScanner.GetActiveCrafters. Unticking the character ignores all of its recipes, also those without a
-- stored profession. The x deletes a character (never the current one), which asks first.
AM.CharactersWindow = {}
local CharactersWindow = AM.CharactersWindow
local Widgets = AM.Widgets
local ProfessionScanner = AM.ProfessionScanner
local UI = AM.Theme.ui

local WIDTH, HEIGHT = 340, 420
local CHARACTER_HEIGHT, PROFESSION_HEIGHT = 30, 24
local PENCIL_ICON = "Interface\\AddOns\\" .. addonName .. "\\assets\\pencil"

local frame, list, empty

local function BuildItems()
  local items = {}
  for _, character in ipairs(ProfessionScanner.GetKnownProfessions()) do
    items[#items + 1] = { kind = "character", height = CHARACTER_HEIGHT, guid = character.guid, name = character.name,
      class = character.class, ignored = character.ignored, professions = character.professions }
    for _, profession in ipairs(character.professions) do
      items[#items + 1] = { kind = "profession", height = PROFESSION_HEIGHT, guid = character.guid,
        skillLine = profession.skillLine, name = profession.name, icon = profession.icon, ignored = profession.ignored,
        characterIgnored = character.ignored }
    end
  end
  return items
end

local function CreateRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  row.check:SetSize(24, 24)
  row.check:SetScript("OnClick", function(self)
    local item = row.item
    local ignore = not self:GetChecked()
    if item.kind == "character" then
      ProfessionScanner.SetCharacterIgnored(item.guid, ignore)
    else
      ProfessionScanner.SetProfessionIgnored(item.guid, item.skillLine, ignore)
    end
  end)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(16, 16)
  row.name = Widgets.CreateText(row, "GameFontHighlightSmall")
  row.name:SetWordWrap(false)
  row.remove = Widgets.CreateRemoveButton(row, L["SHOPPING_CRAFTER_REMOVE_TOOLTIP"], function()
    AM.ShoppingList.ConfirmRemoveCrafter(row.item.guid)
  end)
  row.remove:SetPoint("RIGHT", -8, 0)
  return row
end

local function SetupRow(row, item)
  row.item = item
  row.check:ClearAllPoints()
  row.icon:ClearAllPoints()
  row.name:ClearAllPoints()
  if item.kind == "character" then
    row.check:SetPoint("LEFT", 6, 0)
    row.check:SetEnabled(true)
    row.check:SetChecked(not item.ignored)
    AM.ShoppingRows.SetClassIcon(row.icon, item.class)
    row.name:SetFontObject("GameFontNormal")
    row.name:SetText(Widgets.Color(UI.crafter, item.name))
    row.remove:SetShown(item.guid ~= UnitGUID("player"))
  else
    row.check:SetPoint("LEFT", 28, 0)
    -- the professions of an ignored character are shown as they are set, but cannot be changed
    row.check:SetEnabled(not item.characterIgnored)
    row.check:SetChecked(not item.ignored)
    row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.name:SetFontObject(item.characterIgnored and "GameFontDisableSmall" or "GameFontHighlightSmall")
    row.name:SetText(item.name)
    row.remove:Hide()
  end
  row.icon:SetPoint("LEFT", row.check, "RIGHT", 2, 0)
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
end

local function CreateWindow()
  local inner
  frame, inner = Widgets.CreatePortraitFrame(L["CHARACTERS_TITLE"], function() end, true)
  frame:SetSize(WIDTH, HEIGHT)
  frame:SetFrameStrata("DIALOG")
  frame:SetPoint("CENTER")

  local hint = Widgets.CreateText(inner, "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", 16, -14)
  hint:SetPoint("TOPRIGHT", -16, -14)
  hint:SetWordWrap(true)
  hint:SetJustifyV("TOP")
  hint:SetText(L["CHARACTERS_HINT"])

  local box = Widgets.CreatePanel(inner)
  box:SetPoint("TOPLEFT", 16, -52)
  box:SetPoint("BOTTOMRIGHT", -16, 16)
  list = Widgets.CreateList(box, CreateRow, SetupRow)
  list:SetPoint("TOPLEFT", 1, -4)
  list:SetPoint("BOTTOMRIGHT", -1, 4)
  empty = Widgets.CreateText(box, "GameFontDisable", "CENTER")
  empty:SetPoint("TOPLEFT", 12, -24)
  empty:SetPoint("TOPRIGHT", -12, -24)
  empty:SetText(L["CHARACTERS_EMPTY"])

  frame:SetScript("OnShow", CharactersWindow.Refresh)

  -- Escape closes it, like the windows of the game
  _G[addonName .. "CharactersWindow"] = frame
  table.insert(UISpecialFrames, addonName .. "CharactersWindow")
  frame:Hide()
end

-- Redraws it (if it has been opened).
function CharactersWindow.Refresh()
  if not (frame and frame:IsShown()) then
    return
  end
  local items = BuildItems()
  list.SetItems(items)
  empty:SetShown(#items == 0)
end

AM.Events.Register("CRAFTERS_CHANGED", CharactersWindow.Refresh)

function CharactersWindow.Toggle()
  if not frame then
    CreateWindow()
  end
  frame:SetShown(not frame:IsShown())
  if frame:IsShown() then
    frame:Raise()
  end
end

-- The button that opens it, for the filter bar of the recipes list: the game's square icon button (dark with a
-- golden border in every client skin) with a pencil in the gold of its icons.
function CharactersWindow.CreateButton(parent)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(32, 32)
  button:SetNormalTexture("Interface\\Buttons\\UI-SquareButton-Up")
  button:SetPushedTexture("Interface\\Buttons\\UI-SquareButton-Down")
  button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  local icon = button:CreateTexture(nil, "OVERLAY")
  icon:SetSize(18, 18)
  icon:SetPoint("CENTER")
  icon:SetTexture(PENCIL_ICON)
  icon:SetVertexColor(1, 0.82, 0)
  button:SetScript("OnMouseDown", function()
    icon:SetPoint("CENTER", 1, -1)
  end)
  button:SetScript("OnMouseUp", function()
    icon:SetPoint("CENTER", 0, 0)
  end)
  button:SetScript("OnClick", CharactersWindow.Toggle)
  Widgets.SetTooltip(button, L["CHARACTERS_TOOLTIP"])
  return button
end
