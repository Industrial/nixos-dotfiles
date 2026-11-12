local addonName, AM = ...
local L = AM.L

-- The shopping list below the game's objective tracker (the clients that have ObjectiveTrackerManager: Retail,
-- WoW Forever): a header and one line per item needed, filled from our own lists (see ShoppingTracker.lua); the recipes
-- the player tracks are not touched. It is a frame of our own, deliberately not a module of the tracker: a module of
-- ours would sit in the tracker's own tables, and every update of the tracker (which reads them) would run tainted,
-- breaking the other modules (e.g. the scenario module). The tracker is only read and hooked. Without the tracker or
-- if the game changed it, nothing is added. Classic has the older WatchFrame, see WatchFrameTracker.lua.
-- EllesmereUI can redraw the tracker (its own colors, font, divider lines and background). Where it does, our list
-- is drawn the same way from its settings, which are only read.
local ShoppingTracker = AM.ShoppingTracker
local ShoppingList = AM.ShoppingList

local HEADER_ATLAS = "UI-QuestTracker-Secondary-Objective-Header"
local HEADER_HEIGHT = 26
local INDENT = 7 -- of the header text and the lines, like the game's modules
local LINE_SPACING = 3
local FIRST_LINE_GAP = 8 -- between the header and the first line, the quests sit about as far below theirs
local GAP = 4 -- below the tracker
local FALLBACK_COLOR = { r = 0.8, g = 0.8, b = 0.8 }

local holder
local button -- collapses the list, like the minus of the game's modules
local title
local headerArt -- the header bar of the game
local divider -- below the header, EllesmereUI look only
local background -- EllesmereUI look only
local lines = {}
local eui -- the quest tracker of EllesmereUI while it draws the tracker its own way (fixed until /reload)

local function GetEui()
  local tracker = _G.EllesmereUIQuestTracker
  if not (EllesmereUI and tracker and tracker.Blizz and tracker.Cfg and tracker.DB) then
    return nil
  end
  local ok, stock = pcall(tracker.Blizz)
  return ok and stock == false and tracker or nil
end

-- The color a group of its settings stands for: "header" (header text and button) or "line" (divider).
local function GetEuiColor(group)
  local settings = eui.DB()
  if settings[group .. "ShowClassColor"] then
    local class = EllesmereUI._playerClass
    local color = class and EllesmereUI.GetClassColor and EllesmereUI.GetClassColor(class)
    if color then
      return color.r, color.g, color.b
    end
  elseif settings[group .. "UseAccent"] ~= false then
    local accent = EllesmereUI.ELLESMERE_GREEN
    if accent then
      return accent.r, accent.g, accent.b
    end
    return 0.047, 0.824, 0.624
  end
  return settings[group .. "R"] or 1, settings[group .. "G"] or 1, settings[group .. "B"] or 1
end

local function SetEuiFont(fontString, size)
  local path = "Fonts/FRIZQT__.TTF"
  local key = eui.Cfg("font")
  if key and key ~= "__global" and EllesmereUI.ResolveFontName then
    path = EllesmereUI.ResolveFontName(key) or path
  elseif EllesmereUI.GetFontPath then
    path = EllesmereUI.GetFontPath("questTracker") or path
  end
  local outline = EllesmereUI.GetFontOutlineFlag and EllesmereUI.GetFontOutlineFlag("questTracker") or ""
  if not pcall(fontString.SetFont, fontString, path, size, outline) then
    fontString:SetFont("Fonts/FRIZQT__.TTF", size, outline)
  end
  -- the shadow rides on a font object, which takes the font face back to the one it has
  if EllesmereUI.PrimeFontShadow and EllesmereUI.GetFontUseShadow then
    local face, faceSize, flags = fontString:GetFont()
    EllesmereUI.PrimeFontShadow(fontString, EllesmereUI.GetFontUseShadow("questTracker") and true or false)
    if face then
      fontString:SetFont(face, faceSize, flags)
    end
  end
end

local function SetLineFont(fontString)
  if eui then
    SetEuiFont(fontString, eui.Cfg("titleFontSize") or 12)
  end
end

-- Folded or not, kept for the account (global object trackerList).
local function IsFolded()
  return AM.Database.GetGlobalObject("trackerList").folded == true
end

local function ApplyFolded()
  local folded = IsFolded()
  local kind = folded and "expand" or "collapse"
  button:GetNormalTexture():SetAtlas("ui-questtrackerbutton-secondary-" .. kind, true)
  button:GetPushedTexture():SetAtlas("ui-questtrackerbutton-secondary-" .. kind .. "-pressed", true)
end

local function GetColor(name)
  return OBJECTIVE_TRACKER_COLOR and OBJECTIVE_TRACKER_COLOR[name] or FALLBACK_COLOR
end

local function ApplyColor(line, highlight)
  if eui and not highlight then
    local settings = eui.DB()
    if line.done then
      line.text:SetTextColor(settings.completedR or 0.251, settings.completedG or 1, settings.completedB or 0.349)
    else
      line.text:SetTextColor(settings.titleR or 1, settings.titleG or 0.91, settings.titleB or 0.471)
    end
    return
  end
  local color = GetColor(line.done and "Complete" or (highlight and "HeaderHighlight" or "Header"))
  line.text:SetTextColor(color.r, color.g, color.b)
end

-- Header, divider, button and background the way EllesmereUI draws the headers of the tracker.
local function ApplyEui()
  if headerArt then
    headerArt:Hide()
  end
  SetEuiFont(title, eui.Cfg("headerFontSize") or 13)
  local r, g, b = GetEuiColor("header")
  title:SetTextColor(r, g, b)
  for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture() }) do
    texture:SetDesaturated(true)
    texture:SetVertexColor(r, g, b)
  end

  if not divider then
    divider = holder:CreateTexture(nil, "OVERLAY")
    divider:SetPoint("TOPLEFT", holder, "TOPLEFT", INDENT, -HEADER_HEIGHT)
    divider:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -1, -HEADER_HEIGHT)
    background = holder:CreateTexture(nil, "BACKGROUND")
  end
  local perfect = EllesmereUI.PP and EllesmereUI.PP.perfect or 1
  local scale = holder:GetEffectiveScale()
  divider:SetHeight(scale > 0 and perfect / scale or 1)
  divider:SetColorTexture(GetEuiColor("line"))
  divider:Show()

  -- like the background of the quests, which it continues below when it is there
  local settings = eui.DB()
  background:SetColorTexture(settings.bgR or 0, settings.bgG or 0, settings.bgB or 0, settings.bgAlpha or 0.5)
  local quests = _G.EllesmereUIQTBackground
  background:ClearAllPoints()
  if quests and quests:IsShown() then
    background:SetPoint("TOPLEFT", quests, "BOTTOMLEFT")
    background:SetPoint("TOPRIGHT", quests, "BOTTOMRIGHT")
  else
    background:SetPoint("TOPLEFT", holder, "TOPLEFT")
    background:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 11, 0)
  end
  background:SetPoint("BOTTOM", holder, "BOTTOM", 0, -GAP * 2)
  background:Show()
end

local function CreateLine()
  local line = CreateFrame("Button", nil, holder)
  line.text = line:CreateFontString(nil, "ARTWORK", "ObjectiveTrackerLineFont")
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

-- The tracker's frame is as tall as the screen allows, not as its contents, so the list goes below the last module
-- that shows something (the tracker lays its modules out one below the other).
local function Place()
  local tracker = ObjectiveTrackerFrame
  local last
  for _, module in ipairs(tracker.modules or {}) do
    if module:IsShown() and module.GetContentsHeight and module:GetContentsHeight() > 0 then
      last = module
    end
  end
  holder:ClearAllPoints()
  if last then
    holder:SetPoint("TOP", last, "BOTTOM", 0, -GAP)
  else
    holder:SetPoint("TOP", tracker, "TOP", 0, -GAP)
  end
  holder:SetPoint("LEFT", tracker, "LEFT", 0, 0)
  holder:SetPoint("RIGHT", tracker, "RIGHT", 0, 0)
end

local function Layout()
  local tracker = ObjectiveTrackerFrame
  local entries = ShoppingTracker.GetEntries()
  local collapsed = tracker.IsCollapsed and tracker:IsCollapsed()
  -- the tracker hides itself while no module has content (no quest followed); the list stays, anchored to its position
  if #entries == 0 or collapsed then
    holder:Hide()
    return
  end
  local width = holder:GetWidth() - 2 * INDENT
  if width < 50 then
    width = 230
  end
  local y = HEADER_HEIGHT + FIRST_LINE_GAP
  local folded = IsFolded()
  if folded then
    entries = {}
  end
  for index, entry in ipairs(entries) do
    local line = lines[index] or CreateLine()
    lines[index] = line
    line.entry = entry
    line.done = entry.done
    line.text:SetWidth(width)
    SetLineFont(line.text)
    line.text:SetText(entry.text)
    ApplyColor(line, false)
    local height = math.max(line.text:GetStringHeight(), 1)
    line:SetSize(width, height)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", holder, "TOPLEFT", INDENT, -y)
    line:Show()
    y = y + height + LINE_SPACING
  end
  for index = #entries + 1, #lines do
    lines[index]:Hide()
    lines[index].entry = nil
  end
  holder:SetHeight(folded and HEADER_HEIGHT or y)
  Place()
  if eui then
    ApplyEui()
  end
  holder:Show()
end

local function Create()
  eui = GetEui()
  holder = CreateFrame("Frame", nil, UIParent)
  holder:SetFrameStrata(ObjectiveTrackerFrame:GetFrameStrata())
  -- above the frames of the tracker (and of UI addons that redraw it), which reach over our list and would take its clicks
  holder:SetFrameLevel(ObjectiveTrackerFrame:GetFrameLevel() + 20)
  holder:SetHeight(HEADER_HEIGHT)
  holder:Hide()

  if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(HEADER_ATLAS) then
    headerArt = holder:CreateTexture(nil, "BACKGROUND")
    headerArt:SetAtlas(HEADER_ATLAS, true)
    headerArt:SetPoint("LEFT", holder, "TOPLEFT", 0, -HEADER_HEIGHT / 2)
  end
  title = holder:CreateFontString(nil, "ARTWORK", "ObjectiveTrackerHeaderFont")
  title:SetPoint("LEFT", holder, "TOPLEFT", INDENT, -HEADER_HEIGHT / 2)
  title:SetText(L["SHOPPING_TITLE"])

  local header = CreateFrame("Button", nil, holder)
  header:SetPoint("TOPLEFT")
  header:SetPoint("TOPRIGHT")
  header:SetHeight(HEADER_HEIGHT)
  header:RegisterForClicks("RightButtonUp")
  header:SetScript("OnClick", function(self)
    ShoppingTracker.OpenMenu(self)
  end)

  button = CreateFrame("Button", nil, holder)
  button:SetFrameLevel(header:GetFrameLevel() + 1) -- the header strip spans the whole width and would take the clicks
  button:SetSize(16, 16)
  button:SetPoint("RIGHT", holder, "TOPRIGHT", 1, -HEADER_HEIGHT / 2)
  button:SetNormalAtlas("ui-questtrackerbutton-secondary-collapse")
  button:SetPushedAtlas("ui-questtrackerbutton-secondary-collapse-pressed")
  button:SetHighlightAtlas("ui-questtrackerbutton-yellow-highlight")
  button:GetHighlightTexture():SetBlendMode("ADD")
  button:SetScript("OnClick", function()
    local state = AM.Database.GetGlobalObject("trackerList")
    state.folded = not state.folded or nil
    ApplyFolded()
    Layout()
  end)
  ApplyFolded()

  -- The tracker lays itself out when it is shown, hidden or collapsed; its position is followed by the anchors.
  ObjectiveTrackerFrame:HookScript("OnShow", Layout)
  ObjectiveTrackerFrame:HookScript("OnHide", Layout)
  -- the modules are laid out in Update, the list follows them
  if ObjectiveTrackerFrame.Update then
    hooksecurefunc(ObjectiveTrackerFrame, "Update", Layout)
  end
  if ObjectiveTrackerFrame.SetCollapsed then
    hooksecurefunc(ObjectiveTrackerFrame, "SetCollapsed", Layout)
  end
  ShoppingTracker.RegisterView(Layout)
  ShoppingTracker.Update()
end

local function Setup()
  if not (ObjectiveTrackerManager and ObjectiveTrackerFrame and ObjectiveTrackerFrame.HookScript
    and C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("ObjectiveTrackerModuleTemplate")) then
    return -- this client has no modules (Classic), nothing to add
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
