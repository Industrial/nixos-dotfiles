-- src/ui/modeIndicator.lua
--
-- Mode must be unmistakable in-game. Source mode gets a permanent visible indicator, not just
-- a login message — because a contributor running an unbaked database and not realising it
-- will misread every symptom that follows.
--
-- `DESIGN.md` puts the indicator "on the map or in Questie's settings", which is the
-- consumer's surface, not this addon's. So QuestieDB does two things: publishes the state for
-- a consumer to render properly, and draws its own small always-on frame as a fallback so the
-- guarantee does not depend on a consumer existing.

local _, LibQuestieDB = ...

local indicator = {}

LibQuestieDB.ModeIndicator = indicator

--- What a consumer should show. Returns nil in Baked mode — nothing to warn about.
function indicator.GetText()
  if LibQuestieDB.readMode ~= "source" then return nil end
  local expansion = LibQuestieDB.read.source and LibQuestieDB.read.source.expansion or "?"
  return "QuestieDB: SOURCE MODE (" .. expansion .. ")"
end

--- Short form, for a settings line or a tooltip.
function indicator.GetStatus()
  return {
    mode = LibQuestieDB.readMode,
    expansion = LibQuestieDB.read.source and LibQuestieDB.read.source.expansion or nil,
    contractVersion = LibQuestieDB.contractVersion,
  }
end

--------------------------------------------------------------------------------------------
-- Fallback frame
--------------------------------------------------------------------------------------------

local frame

local function build()
  if frame or LibQuestieDB.readMode ~= "source" then return end
  if type(rawget(_G, "CreateFrame")) ~= "function" then return end

  frame = CreateFrame("Frame", "QuestieDBSourceModeIndicator", UIParent)
  frame:SetSize(220, 20)
  frame:SetPoint("TOP", UIParent, "TOP", 0, -4)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetClampedToScreen(true)

  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  text:SetAllPoints()
  text:SetText("|cFFFFD100" .. (indicator.GetText() or "") .. "|r")
  frame.text = text

  indicator.frame = frame
end

function indicator.Show()
  build()
  if frame then frame:Show() end
end

function indicator.Hide()
  if frame then frame:Hide() end
end

--- Called by src/api.lua once the read mode is settled.
function indicator.Initialize()
  if LibQuestieDB.readMode == "source" then
    indicator.Show()
  end
end

return indicator
