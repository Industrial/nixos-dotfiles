local addonName, AM = ...

local L = AM.L

-- The changelog window: the parsed changelog.src.md (see AM.Changelog) as a scrolling list of headings,
-- bullets and paragraphs, in a window of its own that does not need the auction house (`/am changelog`, the
-- chat message after an update, the button in the options). The global object "changelogWindow" holds its
-- position.
AM.ChangelogWindow = {}
local ChangelogWindow = AM.ChangelogWindow
local Widgets = AM.Widgets

local WIDTH, HEIGHT = 720, 520
local TEXT_WIDTH = 630
local LEFT = 24
local BULLET_INDENT = 16

local FONTS = {
  heading = "GameFontNormal",
  bullet = "GameFontHighlightSmall",
  paragraph = "GameFontHighlightSmall",
}

local frame, list, measure
local items

-- Rows are sized to their wrapped text, which a hidden font string measures.
local function BuildItems()
  items = {}
  for index, block in ipairs(AM.Changelog.GetBlocks()) do
    local indent = block.kind == "bullet" and BULLET_INDENT or 0
    measure:SetFontObject(FONTS[block.kind])
    measure:SetWidth(TEXT_WIDTH - indent)
    measure:SetText(AM.Changelog.Inline(block.text))
    local gap = block.kind == "heading" and (index > 1 and 22 or 8) or 6
    items[#items + 1] = {
      kind = block.kind,
      text = block.text,
      indent = indent,
      height = math.ceil(measure:GetStringHeight()) + gap,
      gap = gap,
    }
  end
end

local function CreateRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row.marker = Widgets.CreateText(row, "GameFontHighlightSmall")
  row.marker:SetText("-")
  row.text = Widgets.CreateText(row, "GameFontHighlightSmall")
  row.text:SetJustifyV("TOP")
  return row
end

local function SetupRow(row, item)
  row.marker:ClearAllPoints()
  row.marker:SetPoint("TOPLEFT", LEFT, -item.gap)
  row.marker:SetShown(item.kind == "bullet")
  row.text:SetFontObject(FONTS[item.kind])
  row.text:SetWidth(TEXT_WIDTH - item.indent)
  row.text:ClearAllPoints()
  row.text:SetPoint("TOPLEFT", LEFT + item.indent, -item.gap)
  row.text:SetText(AM.Changelog.Inline(item.text))
end

local function GetState()
  return AM.Database.GetGlobalObject("changelogWindow")
end

local function SavePosition()
  local left, top = frame:GetLeft(), frame:GetTop()
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
  GetState().position = { left, top }
end

local function CreateWindow()
  local inner
  frame, inner = Widgets.CreatePortraitFrame(L["CHANGELOG_TITLE"], SavePosition, true)
  frame:SetSize(WIDTH, HEIGHT)
  -- above the settings panel, which the options open it from
  frame:SetFrameStrata("DIALOG")
  local position = GetState().position
  if position and #position == 2 then
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", position[1], position[2])
  else
    frame:SetPoint("CENTER")
  end

  local box = Widgets.CreatePanel(inner)
  box:SetPoint("TOPLEFT", 16, -16)
  box:SetPoint("BOTTOMRIGHT", -16, 16)
  measure = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  measure:SetAlpha(0)
  list = Widgets.CreateList(box, CreateRow, SetupRow)
  list:SetPoint("TOPLEFT", 1, -8)
  list:SetPoint("BOTTOMRIGHT", -1, 8)
  -- measured once it is shown, the text sizes are only known then
  frame:SetScript("OnShow", function()
    if not items then
      BuildItems()
      list.SetItems(items)
    end
  end)

  -- Escape closes it, like the windows of the game
  _G[addonName .. "ChangelogWindow"] = frame
  table.insert(UISpecialFrames, addonName .. "ChangelogWindow")
  frame:Hide()
end

function ChangelogWindow.Show()
  if not frame then
    CreateWindow()
  end
  frame:Show()
  frame:Raise()
end

function ChangelogWindow.Toggle()
  if frame and frame:IsShown() then
    frame:Hide()
  else
    ChangelogWindow.Show()
  end
end
