QuestieTraceCore = QuestieTraceCore or {}

---@class QuestieTraceCore
local Core = QuestieTraceCore

---@type l10n
local l10n = Core.l10n

---------------------------------------------------------------------------
-- Export reminder (inn-based, no login/interval spam)
---------------------------------------------------------------------------
-- Reminds the player to export when they have been playing for at least
-- one hour AND are in a resting area (Inn).
--
-- Behavior:
--   * On inn entry (or login in inn): if played ≥ 1h since session start
--     (or since last reminder), fires immediately. Otherwise schedules a
--     timer for the remaining time until the 1h mark.
--   * Timer callback fires only if still in an inn (IsResting()).
--   * Leaving the inn cancels any pending timer (token invalidation).
--   * After a reminder fires, the 1h timer restarts from that moment.
--   * Opening the export window (MarkExportOpened) updates lastReminderAt,
--     so the next inn entry after another hour will trigger again.
---------------------------------------------------------------------------

local C_After = C_Timer.After

---@type string
local ADDON_NAME = "QuestieTrace"
---@type number Minimum play time in seconds before a reminder can fire (1 hour).
local MIN_PLAY_TIME = 3600
---@type string Custom chat hyperlink type owned by this addon.
local LINK_TYPE = "questietrace"
---@type string Hyperlink option identifying the export action.
local LINK_ACTION = "export"

---@class ReminderState
---@field sessionStart number GetTime() when the current play session began (capture started).
---@field lastReminderAt number GetTime() when the last reminder was shown (0 = never).

---@type boolean Set once the event frame has been registered for this load.
local frameRegistered = false

---------------------------------------------------------------------------
-- Per-character state
---------------------------------------------------------------------------

--- Read the per-character reminder state, initializing missing fields.
---@return ReminderState
local function GetReminderState()
  ---@type table?
  local characterDb = QuestieTraceCharacter
  if type(characterDb) ~= "table" then
    return { sessionStart = 0, lastReminderAt = 0 }
  end

  if type(characterDb.reminder) ~= "table" then
    characterDb.reminder = {}
  end

  ---@type ReminderState
  local reminder = characterDb.reminder
  if type(reminder.sessionStart) ~= "number" or reminder.sessionStart > GetTime() then
    reminder.sessionStart = 0
  end
  if type(reminder.lastReminderAt) ~= "number" or reminder.lastReminderAt > GetTime() then
    reminder.lastReminderAt = 0
  end

  return reminder
end

---------------------------------------------------------------------------
-- Eligibility
---------------------------------------------------------------------------

--- Check if the player has been playing long enough for a reminder.
---@param sessionStart number
---@return boolean
local function HasPlayedLongEnough(sessionStart)
  return GetTime() - sessionStart >= MIN_PLAY_TIME
end

--- Check if there is shareable data (saved sessions or live session with events).
---@return boolean
local function HasShareableData()
  ---@type table?
  local characterDb = QuestieTraceCharacter
  if type(characterDb) ~= "table" then return false end

  -- Check saved sessions (any saved session is shareable)
  if type(characterDb.sessions) == "table" and #characterDb.sessions > 0 then
    return true
  end

  -- Check live session for any events
  ---@type SessionRecord?
  local currentSession = characterDb.currentSession
  if type(currentSession) == "table"
      and type(currentSession.events) == "table"
      and #currentSession.events > 0
      and type(currentSession.startedAt) == "number" then
    return true
  end

  return false
end

--- Is a reminder due right now?
---@return boolean due
function Core.IsShareDue()
  local reminder = GetReminderState()

  -- Must have played long enough since last reminder (or session start)
  local sinceLast = reminder.lastReminderAt == 0 and reminder.sessionStart or reminder.lastReminderAt
  if not HasPlayedLongEnough(sinceLast) then
    return false
  end

  -- Must have shareable data
  if not HasShareableData() then
    return false
  end

  return true
end

--- Record that the player opened the export window, pausing reminders until
--- another session with meaningful data is saved.
function Core.MarkExportOpened()
  GetReminderState().lastReminderAt = GetTime()
end

---------------------------------------------------------------------------
-- Chat message
---------------------------------------------------------------------------

--- Build the clickable chat hyperlink that opens the export window.
---@return string link
local function BuildExportLink()
  return string.format(
    "|cFF33FF99|H%s:%s|h[%s]|h|r",
    LINK_TYPE,
    LINK_ACTION,
    l10n("Click here to open the export window")
  )
end

--- Print the reminder to the default chat frame.
local function ShowReminder()
  ---@type table?
  local chatFrame = DEFAULT_CHAT_FRAME
  if type(chatFrame) ~= "table" then return end

  chatFrame:AddMessage(string.format(
    "|cFFFFD100%s|r: %s",
    ADDON_NAME,
    l10n("It is time to share your trace data again. Each submission only covers what happened so far, so please keep submitting regularly. %s", BuildExportLink())
  ))
end

---------------------------------------------------------------------------
-- Resting state handling
---------------------------------------------------------------------------

---@type number Token that increments on each inn entry; callbacks verify their token is current.
local restingToken = 0

--- Schedule or re-schedule the inn reminder timer for the given token.
---@param currenToken number The current resting token
local function scheduleInnTimer(currenToken)
  local reminder = GetReminderState()
  local sinceLast = reminder.lastReminderAt == 0 and reminder.sessionStart or reminder.lastReminderAt
  local remaining = MIN_PLAY_TIME - (GetTime() - sinceLast)
  if remaining > 0 then
    C_After(remaining, function()
      -- Only fire if this token is still current (no re-entry since scheduling)
      -- and still in a resting area and has shareable data
      if currenToken == restingToken and IsResting() and HasShareableData() then
        if Core.IsShareDue() then
          ShowReminder()
          GetReminderState().lastReminderAt = GetTime()
          -- Do NOT reschedule; next reminder only on next inn entry/login
          -- We don't want to remind users staying at a major city for multiple hours each hour
        else
          -- Not due yet (e.g., MarkExportOpened() updated lastReminderAt while timer was pending).
          -- Re-arm the timer with the new remaining time.
          scheduleInnTimer(currenToken)
        end
      end
    end)
  end
end

--- Called when the player enters a resting area (IsResting() becomes true).
local function OnEnterResting()
  -- Increment token on every inn entry to invalidate any pending timers
  restingToken = restingToken + 1
  local currenToken = restingToken

  -- Check if reminder is due (uses lastReminderAt, not sessionStart)
  if Core.IsShareDue() then
    ShowReminder()
    GetReminderState().lastReminderAt = GetTime()
    -- Do NOT schedule next check; next reminder only on next inn entry/login
    -- We don't want to remind users staying at a major city for multiple hours each hour
    return
  end

  -- Schedule a timer on every inn entry (login or re-entry)
  scheduleInnTimer(currenToken)
end

--- Called when the player leaves a resting area (IsResting() becomes false).
local function OnLeaveResting()
  restingToken = restingToken + 1
end

--- Initialize the reminder state on first login. Preserves the timer across /reload.
local function InitReminderState()
  local reminder = GetReminderState()
  -- Only initialize if not already set (first login ever for this character).
  -- This preserves the reminder timer across /reload while the capture session still restarts.
  if reminder.sessionStart == 0 then
    reminder.sessionStart = GetTime()
    reminder.lastReminderAt = 0
  end
end

---------------------------------------------------------------------------
-- Event frame
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

---@param event string
local function OnEvent(_, event)
  if event == "PLAYER_ENTERING_WORLD" then
    -- Check immediately in case we're already in a resting area at login
    if IsResting() then
      OnEnterResting()
    end
  elseif event == "PLAYER_UPDATE_RESTING" then
    if IsResting() then
      OnEnterResting()
    else
      OnLeaveResting()
    end
  end
end

--- Start the export reminder system. Idempotent within one load.
function Core.StartShareReminders()
  if frameRegistered then return end
  frameRegistered = true

  InitReminderState()

  eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
  eventFrame:SetScript("OnEvent", OnEvent)

  -- If the player is already in a resting area (e.g., consent accepted via dialog
  -- while in an inn, long after PLAYER_ENTERING_WORLD), run the inn-entry logic now.
  if IsResting() then
    OnEnterResting()
  end
end

---------------------------------------------------------------------------
-- Hyperlink handling
---------------------------------------------------------------------------

--- Open the export window if `link` is this addon's export hyperlink.
---@param link any The hyperlink body, e.g. "questietrace:export"
---@return boolean handled
local function HandleExportLink(link)
  if type(link) ~= "string" then return false end

  ---@type string?, string?
  local linkType, action = link:match("^([^:]+):([^:|]+)")
  if linkType ~= LINK_TYPE or action ~= LINK_ACTION then
    return false
  end

  Core.ShowExportWindow()

  return true
end

--- Install the questietrace: hyperlink handler.
local linkHandlerRegistered = false

local function RegisterLinkHandler()
  if linkHandlerRegistered then return end
  linkHandlerRegistered = true

  if type(LinkUtil) == "table"
      and type(LinkUtil.RegisterLinkHandler) == "function"
      and type(LinkUtil.IsLinkHandlerRegistered) == "function"
      and (not LinkUtil.IsLinkHandlerRegistered(LINK_TYPE)) then
    LinkUtil.RegisterLinkHandler(LINK_TYPE, function(link)
      HandleExportLink(link)
    end)
    return
  end

  if type(hooksecurefunc) == "function" then
    hooksecurefunc("SetItemRef", function(link)
      if HandleExportLink(link) and type(ItemRefTooltip) == "table" then
        ItemRefTooltip:Hide()
      end
    end)
  end
end

RegisterLinkHandler()
