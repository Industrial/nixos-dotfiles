local addonName, AM = ...
local L = AM.L

-- The shopping list below the older WatchFrame of the game (the clients without modules: Classic): a header and one
-- "have/need name" line per item needed, filled from our own lists (see ShoppingTracker.lua); the quests and
-- achievements the player tracks are not touched. Like on the newer tracker (ObjectiveTracker.lua) it is a frame of
-- our own, deliberately not an objective handler of the WatchFrame: a handler runs inside WatchFrame_Update and
-- everything it does there (lines taken from the game's pool, anchors) would be tainted. The WatchFrame is only read
-- and hooked. Without it, or if the game changed it, nothing is added.
local ShoppingTracker = AM.ShoppingTracker
local ShoppingList = AM.ShoppingList

local HEADER_HEIGHT = 20
local LINE_SPACING = 2
local GAP = 10 -- below the last line of the WatchFrame
local TITLE_COLOR = { 1, 0.82, 0 }
local NORMAL_COLOR = { 0.8, 0.8, 0.8 }
local HIGHLIGHT_COLOR = { 1, 1, 1 }
local COMPLETE_COLOR = { 0.6, 0.6, 0.6 }

local holder
local title
local button -- collapses the list, like the button of the WatchFrame's own header
local lines = {}

-- Folded or not, kept for the account (global object trackerList, shared with the newer tracker).
local function IsFolded()
  return AM.Database.GetGlobalObject("trackerList").folded == true
end

local function ApplyFolded()
  local top = IsFolded() and 0 or 0.5
  button:GetNormalTexture():SetTexCoord(0, 0.5, top, top + 0.5)
  button:GetPushedTexture():SetTexCoord(0.5, 1, top, top + 0.5)
end

local function ApplyColor(line, highlight)
  local color = line.done and COMPLETE_COLOR or (highlight and HIGHLIGHT_COLOR or NORMAL_COLOR)
  line.text:SetTextColor(color[1], color[2], color[3])
end

local function CreateLine()
  local line = CreateFrame("Button", nil, holder)
  line.text = line:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  line.text:SetJustifyH("LEFT")
  line.text:SetPoint("TOPLEFT")
  line.text:SetPoint("TOPRIGHT")
  line.text:SetWordWrap(true)
  line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  line:SetScript("OnClick", function(self, mouseButton)
    if mouseButton == "RightButton" then
      ShoppingTracker.OpenMenu(self)
    elseif self.entry then
      ShoppingList.ClickItem(self.entry.itemId, self.entry.missing)
    end
  end)
  line:SetScript("OnEnter", function(self)
    ApplyColor(self, true)
    if self.entry then
      ShoppingTracker.ShowTooltip(self, self.entry)
    end
  end)
  line:SetScript("OnLeave", function(self)
    ApplyColor(self, false)
    GameTooltip:Hide()
  end)
  return line
end

-- The lowest line the game shows (its lines are kept in these tables, readable but not ours to change).
local function FindLastLine()
  local last, lastBottom
  for _, source in ipairs({ WATCHFRAME_TIMERLINES, WATCHFRAME_ACHIEVEMENTLINES, WATCHFRAME_QUESTLINES }) do
    for _, line in pairs(source) do
      local bottom = line.IsVisible and line:IsVisible() and line:GetBottom()
      if bottom and (not lastBottom or bottom < lastBottom) then
        last, lastBottom = line, bottom
      end
    end
  end
  return last
end

local function Place()
  local last = FindLastLine()
  holder:ClearAllPoints()
  if last then
    holder:SetPoint("TOP", last, "BOTTOM", 0, -GAP)
  elseif WatchFrameHeader and WatchFrameHeader:IsShown() then
    holder:SetPoint("TOP", WatchFrameHeader, "BOTTOM", 0, -GAP)
  else
    holder:SetPoint("TOP", WatchFrame, "TOP", 0, 0)
  end
  -- the right edge stays where it is when the WatchFrame collapses and gets narrower, the list keeps its width
  holder:SetPoint("RIGHT", WatchFrame, "RIGHT", 0, 0)
  -- folded it is as narrow as the collapsed WatchFrame (the game's own formula: title width plus room for the button)
  holder:SetWidth(IsFolded() and title:GetStringWidth() + 70 or WATCHFRAME_EXPANDEDWIDTH)
end

local function Layout()
  local entries = ShoppingTracker.GetEntries()
  if #entries == 0 then
    holder:Hide()
    return
  end
  local folded = IsFolded()
  if folded then
    entries = {}
  end
  local width = WATCHFRAME_MAXLINEWIDTH
  local y = HEADER_HEIGHT + LINE_SPACING
  for index, entry in ipairs(entries) do
    local line = lines[index] or CreateLine()
    lines[index] = line
    line.entry = entry
    line.done = entry.done
    line.text:SetWidth(width)
    line.text:SetText(entry.text)
    ApplyColor(line, false)
    local height = math.max(line.text:GetStringHeight(), 1)
    line:SetSize(width, height)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
    line:Show()
    y = y + height + LINE_SPACING
  end
  for index = #entries + 1, #lines do
    lines[index]:Hide()
    lines[index].entry = nil
  end
  holder:SetHeight(folded and HEADER_HEIGHT or y)
  Place()
  holder:Show()
end

local function Create()
  holder = CreateFrame("Frame", nil, UIParent)
  holder:SetFrameStrata(WatchFrame:GetFrameStrata())
  holder:SetHeight(HEADER_HEIGHT)
  holder:Hide()

  title = holder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT")
  title:SetText(L["SHOPPING_TITLE"])
  title:SetTextColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3])

  local header = CreateFrame("Button", nil, holder)
  header:SetPoint("TOPLEFT")
  header:SetPoint("TOPRIGHT")
  header:SetHeight(HEADER_HEIGHT)
  header:RegisterForClicks("RightButtonUp")
  header:SetScript("OnClick", function(self)
    ShoppingTracker.OpenMenu(self)
  end)

  button = CreateFrame("Button", nil, holder)
  button:SetSize(16, 16)
  button:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -12, -2)
  button:SetNormalTexture("Interface/Buttons/UI-Panel-QuestHideButton")
  button:SetPushedTexture("Interface/Buttons/UI-Panel-QuestHideButton")
  button:SetHighlightTexture("Interface/Buttons/UI-Panel-MinimizeButton-Highlight")
  button:GetHighlightTexture():SetBlendMode("ADD")
  button:SetScript("OnClick", function()
    local state = AM.Database.GetGlobalObject("trackerList")
    state.folded = not state.folded or nil
    ApplyFolded()
    Layout()
  end)
  ApplyFolded()

  -- The WatchFrame lays its lines out in WatchFrame_Update and moves with the other frames of the right side; the
  -- list follows what it left. It has its own collapse button and does not follow the one of the WatchFrame.
  hooksecurefunc("WatchFrame_Update", Layout)
  hooksecurefunc("WatchFrame_Collapse", Layout) -- only places the list again; it does not follow the collapse
  WatchFrame:HookScript("OnShow", Layout)
  WatchFrame:HookScript("OnHide", Layout)
  ShoppingTracker.RegisterView(Layout)
  ShoppingTracker.Update()
end

local function Setup()
  if not (WatchFrame and WatchFrame.HookScript and WatchFrame_Update and WatchFrame_Collapse
    and WATCHFRAME_EXPANDEDWIDTH and WATCHFRAME_MAXLINEWIDTH and WATCHFRAME_TIMERLINES and WATCHFRAME_ACHIEVEMENTLINES
    and WATCHFRAME_QUESTLINES) then
    return
  end
  Create()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  -- the language is known by now (PLAYER_ENTERING_WORLD comes after ADDON_LOADED)
  C_Timer.After(0, function()
    pcall(Setup)
  end)
end)
