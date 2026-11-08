-- luacheck: globals C_Texture BACKDROP_DIALOG_32_32 GameFontDisable issecretvalue QuestieTraceDialogMixin
-- luacheck: globals UserScaledFontGameHighlight UserScaledFontGameNormal UserScaledFontGameDisable

-- Namespaced for XML, but independent of addon-core state and consent behavior.
---@class QuestieTraceDialog : Frame
---@field Background Texture
---@field Border Texture
---@field Text FontString
---@field AcceptButton Button
---@field DeclineButton Button
---@field popupCheckElapsed number?
---@field popupAnchorX number?
---@field popupAnchorY number?
QuestieTraceDialogMixin = {}
local Dialog = QuestieTraceDialogMixin

local POPUP_CHECK_INTERVAL = 0.1
local POPUP_GAP = 10
local SCREEN_MARGIN = 8

---@param value any
---@return boolean
local function IsReadableNumber(value)
  return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
end

--- Measure with native getters, not helpers that reposition or register dialogs.
--- Returns all five values together, or no values when measurement is unavailable.
---@param frame Frame
---@return number? left
---@return number? bottom
---@return number? width
---@return number? height
---@return number? scale Effective scale used by the returned coordinates.
local function GetReadableRect(frame)
  if frame.IsForbidden and frame:IsForbidden() then return end
  local left, bottom, width, height = frame:GetRect()
  local scale = frame:GetEffectiveScale()
  if not (IsReadableNumber(left) and IsReadableNumber(bottom)
      and IsReadableNumber(width) and IsReadableNumber(height) and IsReadableNumber(scale)) then return end
  if width <= 0 or height <= 0 or scale <= 0 then return end
  return left, bottom, width, height, scale
end

--- Avoid overlapping Blizzard dialogs without joining their popup manager.
--- Registering our dialog in the shared popup lists can carry addon taint into
--- Edit Mode. Staying outside those lists loses automatic stacking, so we read
--- the shown dialogs' bounds and move only our frame, anchored to UIParent.
--- Unreadable bounds leave our position unchanged rather than guess at free space.
---@param frame QuestieTraceDialog
local function UpdateDialogPosition(frame)
  local parentLeft, parentBottom, parentWidth, parentHeight, parentScale = GetReadableRect(UIParent)
  if not parentLeft then return end
  local scale, width, height = frame:GetEffectiveScale(), frame:GetWidth(), frame:GetHeight()
  if not (IsReadableNumber(scale) and IsReadableNumber(width) and IsReadableNumber(height)) then return end
  if scale <= 0 or width <= 0 or height <= 0 then return end

  -- GetRect uses each frame's effective scale. SetPoint offsets use ours.
  local parentRatio = parentScale / scale
  parentLeft, parentBottom = parentLeft * parentRatio, parentBottom * parentRatio
  parentWidth, parentHeight = parentWidth * parentRatio, parentHeight * parentRatio
  local left, bottom, right, top
  local unreadable = false
  ---@param popup Frame? Missing globals are skipped on the older-client path.
  local function IncludePopup(popup)
    if unreadable or not popup or popup == frame then return end
    if popup.IsForbidden and popup:IsForbidden() then
      unreadable = true
      return
    end
    local visible = popup:IsVisible()
    if issecretvalue and issecretvalue(visible) then
      unreadable = true
      return
    end
    if not visible then return end
    local px, py, pw, ph, popupScale = GetReadableRect(popup)
    if not px then
      unreadable = true
      return
    end
    local ratio = popupScale / scale
    px, py, pw, ph = px * ratio - parentLeft, py * ratio - parentBottom, pw * ratio, ph * ratio
    left = math.min(left or px, px)
    bottom = math.min(bottom or py, py)
    right = math.max(right or (px + pw), px + pw)
    top = math.max(top or (py + ph), py + ph)
  end

  -- This API only enumerates the shared list, including special dialogs such
  -- as Edit Mode's new-layout prompt. The callback changes local bounds only;
  -- our frame is moved after enumeration, never registered with their manager.
  if type(StaticPopup_ForEachShownDialog) == "function" then
    StaticPopup_ForEachShownDialog(IncludePopup)
  else
    for i = 1, 4 do IncludePopup(_G["StaticPopup" .. i]) end
  end
  -- A callback cannot abort the iterator. Do not use partial measurements.
  if unreadable then return end

  -- Prefer below the stack, then above or beside it. With no popups (or no
  -- available space), use the normal top-center position and keep choices visible.
  local x, y = parentWidth / 2, parentHeight - 135
  if left and width + SCREEN_MARGIN * 2 <= parentWidth and height + SCREEN_MARGIN * 2 <= parentHeight then
    local centeredX = math.max(width / 2 + SCREEN_MARGIN,
      math.min((left + right) / 2, parentWidth - width / 2 - SCREEN_MARGIN))
    local below = math.min(bottom - POPUP_GAP, parentHeight - SCREEN_MARGIN)
    local above = math.max(top + POPUP_GAP + height, height + SCREEN_MARGIN)
    if below - height >= SCREEN_MARGIN then
      x, y = centeredX, below
    elseif above <= parentHeight - SCREEN_MARGIN then
      x, y = centeredX, above
    else
      -- A tall popup stack may leave room beside it instead of underneath it.
      local sideY = math.max(height + SCREEN_MARGIN, math.min(y, parentHeight - SCREEN_MARGIN))
      if right + POPUP_GAP + width <= parentWidth - SCREEN_MARGIN then
        x, y = math.max(width / 2 + SCREEN_MARGIN, right + POPUP_GAP + width / 2), sideY
      elseif left - POPUP_GAP - width >= SCREEN_MARGIN then
        x, y = math.min(parentWidth - width / 2 - SCREEN_MARGIN, left - POPUP_GAP - width / 2), sideY
      end
    end
    -- If no side fits, retain the normal position rather than hide the choices.
  end

  -- Polling unchanged popups must not repeatedly invalidate our frame's layout.
  if frame.popupAnchorX == x and frame.popupAnchorY == y then return end
  frame:ClearAllPoints()
  frame:SetPoint("TOP", UIParent, "BOTTOMLEFT", x, y)
  frame.popupAnchorX, frame.popupAnchorY = x, y
end

--- Observe newly shown/hidden popups without hooking their lifecycle functions.
--- XML OnUpdate runs only while our frame is visible, including in combat;
--- throttling keeps the read-only scan out of the per-render-frame hot path.
---@param elapsed number
function Dialog:OnUpdate(elapsed)
  self.popupCheckElapsed = (self.popupCheckElapsed or 0) + elapsed
  if self.popupCheckElapsed < POPUP_CHECK_INTERVAL then return end
  self.popupCheckElapsed = 0
  UpdateDialogPosition(self)
end

--- Style only our own controls. Inheriting StaticPopupTemplate would register
--- this frame with Blizzard's popup manager and reintroduce the taint path.
function Dialog:OnLoad()
  local backgroundAtlas = "UI-DialogBox-Background-Dark"
  local borderAtlas = "UI-DiamondDialogBox-Border"
  local getAtlasInfo = C_Texture and C_Texture.GetAtlasInfo
  if getAtlasInfo and getAtlasInfo(backgroundAtlas) and getAtlasInfo(borderAtlas) then
    self:SetBackdrop(nil)
    self.Background:SetAtlas(backgroundAtlas)
    self.Border:SetAtlas(borderAtlas)
    self.Background:Show()
    self.Border:Show()
  else
    -- Classic clients may not have the modern dialog atlases.
    self.Background:Hide()
    self.Border:Hide()
    self:SetBackdrop(BACKDROP_DIALOG_32_32)
  end

  self.Text:SetFontObject(UserScaledFontGameHighlight or GameFontHighlight)
  for _, button in ipairs({ self.AcceptButton, self.DeclineButton }) do
    button:SetNormalFontObject(UserScaledFontGameNormal or GameFontNormal)
    button:SetHighlightFontObject(UserScaledFontGameHighlight or GameFontHighlight)
    button:SetDisabledFontObject(UserScaledFontGameDisable or GameFontDisable)
  end
end

--- Match GameDialog's default spacing, growing to fit translated button labels
--- and wrapped text. Font objects are shared read-only; only our widgets resize.
function Dialog:OnShow()
  local buttonWidth = math.max(120, self.AcceptButton:GetTextWidth() + 20, self.DeclineButton:GetTextWidth() + 20)
  local buttonHeight = math.max(21,
    self.AcceptButton:GetFontString():GetStringHeight() + 8,
    self.DeclineButton:GetFontString():GetStringHeight() + 8)
  self.AcceptButton:SetSize(buttonWidth, buttonHeight)
  self.DeclineButton:SetSize(buttonWidth, buttonHeight)

  -- XML uses 16 above the text, 9 before the buttons, and 16 below them.
  self:SetWidth(math.max(420, buttonWidth * 2 + 10 + 32))
  self:SetHeight(16 + self.Text:GetStringHeight() + 9 + buttonHeight + 16)

  self.popupCheckElapsed = 0
  UpdateDialogPosition(self)
end
