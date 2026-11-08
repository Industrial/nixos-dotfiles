QuestieTraceCore = QuestieTraceCore or {}

---@class QuestieTraceCore
local Core = QuestieTraceCore

---@type string
local ADDON_NAME = "QuestieTrace"
---@type number
local SCHEMA_VERSION = 17
---@type number Safety cap on QuestieTraceCharacter.sessions -- a pure size
--- backstop for players who never open the export window, not a substitute
--- for reporting. Oldest sessions are dropped first; there is no
--- "already-exported" concept to prefer evicting, since reported sessions
--- are deleted immediately by Core.DeleteReportedSessions().
local MAX_SESSIONS = 10

---------------------------------------------------------------------------
-- Capture state
---------------------------------------------------------------------------

---@type CaptureState
local capture = {
  active = false,
  token = 0,
  startedAt = nil,        -- GetTime() baseline
  startedAtPrecise = nil, -- GetTimePreciseSec() baseline
  session = nil,          -- the session record being built
}

---------------------------------------------------------------------------
-- All events the addon registers for (union of all tracker events + extras)
---------------------------------------------------------------------------

---@type EventCategory[]
local TRACKED_EVENT_CATEGORIES = {
  {
    name = "quest_state",
    events = {
      "QUEST_LOG_UPDATE",
      "QUEST_ACCEPTED",
      "QUEST_REMOVED",
      "QUEST_TURNED_IN",
      "QUEST_WATCH_UPDATE",
      "UNIT_QUEST_LOG_CHANGED",
      "QUEST_AUTOCOMPLETE",
      "QUEST_POI_UPDATE",
      "QUEST_ITEM_UPDATE",
      "QUEST_LOG_CRITERIA_UPDATE",
      "QUEST_DATA_LOAD_RESULT",
      "QUEST_WATCH_LIST_CHANGED",
      "QUESTLINE_UPDATE",
      "TASK_PROGRESS_UPDATE",
    },
  },
  {
    name = "quest_dialog",
    events = {
      "QUEST_DETAIL",
      "QUEST_PROGRESS",
      "QUEST_COMPLETE",
      "QUEST_FINISHED",
      "QUEST_GREETING",
      "QUEST_ACCEPT_CONFIRM",
      "GOSSIP_SHOW",
      "GOSSIP_CLOSED",
    },
  },
  {
    name = "npc_interaction",
    events = {
      "MERCHANT_SHOW",
      "MERCHANT_CLOSED",
      "TRAINER_SHOW",
      "TRAINER_CLOSED",
      "MAIL_SHOW",
      "MAIL_CLOSED",
      "AUCTION_HOUSE_SHOW",
      "AUCTION_HOUSE_CLOSED",
      "BANKFRAME_OPENED",
      "BANKFRAME_CLOSED",
      "TAXIMAP_OPENED",
      "TAXIMAP_CLOSED",
      "GUILD_REGISTRAR_SHOW",
      "GUILD_REGISTRAR_CLOSED",
      "PET_STABLE_SHOW",
      "PET_STABLE_CLOSED",
      "BATTLEFIELDS_SHOW",
      "BATTLEFIELDS_CLOSED",
      "PETITION_SHOW",
      "PETITION_CLOSED",
      "GUILDBANKFRAME_OPENED",
      "GUILDBANKFRAME_CLOSED",
    },
  },
  {
    name = "initialization",
    events = {
      "ADDON_LOADED",
      "SPELLS_CHANGED",
      "PLAYER_LOGOUT",
      "PLAYER_LEAVING_WORLD",
      "LOADING_SCREEN_ENABLED",
      "LOADING_SCREEN_DISABLED",
    },
  },
  {
    name = "player_state",
    events = {
      "PLAYER_LOGIN",
      "PLAYER_ENTERING_WORLD",
      "PLAYER_ALIVE",
      "PLAYER_LEVEL_UP",
      "PLAYER_XP_UPDATE",
      "UPDATE_EXHAUSTION",
      "PLAYER_MONEY",
      -- DUEL_REQUESTED is left out: its argument is the challenger's name.
      "DUEL_FINISHED",
      "MODIFIER_STATE_CHANGED",
      "PLAYER_REGEN_DISABLED",
      "PLAYER_REGEN_ENABLED",
      "PLAYER_TARGET_CHANGED",
      "PLAYER_EQUIPMENT_CHANGED",
      "SKILL_LINES_CHANGED",
      "LOOT_OPENED",
      "LOOT_READY",
      "LOOT_CLOSED",
      "NEW_RECIPE_LEARNED",
      "UI_INFO_MESSAGE",
      "CURRENCY_DISPLAY_UPDATE",
    },
  },
  {
    name = "map_zone",
    events = {
      "ZONE_CHANGED",
      "ZONE_CHANGED_NEW_AREA",
      "ZONE_CHANGED_INDOORS",
      "MAP_EXPLORATION_UPDATED",
      "PLAYER_MAP_CHANGED",
      "WORLD_MAP_OPEN",
      "AREA_POIS_UPDATED",
      "NEW_WMO_CHUNK",
      "UPDATE_ALL_UI_WIDGETS",
    },
  },
  {
    name = "chat_system",
    events = {
      "CHAT_MSG_SYSTEM",
      "CHAT_MSG_LOOT",
      "CHAT_MSG_MONEY",
      "CHAT_MSG_SKILL",
      "CHAT_MSG_TRADESKILLS",
      "CHAT_MSG_COMBAT_FACTION_CHANGE",
      "CHAT_MSG_COMBAT_XP_GAIN",
    },
  },
  {
    name = "group_world",
    events = {
      "GROUP_JOINED",
      "GROUP_LEFT",
      "GROUP_ROSTER_UPDATE",
      "NAME_PLATE_UNIT_ADDED",
      "NAME_PLATE_UNIT_REMOVED",
      "ACHIEVEMENT_EARNED",
      "TRACKED_ACHIEVEMENT_LIST_CHANGED",
      "TRACKED_ACHIEVEMENT_UPDATE",
      "CRITERIA_UPDATE",
      "UPDATE_FACTION",
    },
  },
  {
    name = "inventory",
    events = {
      -- "BAG_UPDATE",
      -- "BAG_UPDATE_DELAYED",
      "ITEM_PUSH",
      "ITEM_LOCK_CHANGED",
      "ITEM_COUNT_CHANGED",
    },
  },
  {
    name = "display",
    events = {
      "UI_SCALE_CHANGED",
      "DISPLAY_SIZE_CHANGED",
    },
  },
}

-- Build flat deduplicated event list
---@type string[]
local TRACKED_EVENTS = {}
do
  ---@type table<string, boolean>
  local seen = {}
  for _, category in ipairs(TRACKED_EVENT_CATEGORIES) do
    for _, event in ipairs(category.events) do
      if not seen[event] then
        seen[event] = true
        TRACKED_EVENTS[#TRACKED_EVENTS + 1] = event
      end
    end
  end
end
Core.TRACKED_EVENT_CATEGORIES = TRACKED_EVENT_CATEGORIES

---------------------------------------------------------------------------
-- Event filters (skip events that don't match criteria)
---------------------------------------------------------------------------

local EVENT_FILTERS = {
  ---@param addonName string
  ---@return boolean
  ADDON_LOADED = function(addonName)
    return addonName == ADDON_NAME
  end,
  -- Privacy: CHAT_MSG_SYSTEM carries many message kinds that embed player
  -- or guild names with no reliable structural way to strip them (guild
  -- join/leave/invite/promote, online/offline notices, ...). Only allow
  -- through the reviewed, name-free allowlist; see Core.IsAllowedSystemMessage
  -- in Modules/Privacy.lua.
  ---@param text string
  ---@return boolean
  CHAT_MSG_SYSTEM = function(text)
    return Core.IsAllowedSystemMessage(text)
  end,
}

---------------------------------------------------------------------------
-- Event argument sanitizers (privacy: see AGENTS.md / CLAUDE.md)
---------------------------------------------------------------------------
-- Every CHAT_MSG_* event QuestieTrace tracks shares the same argument
-- shape, so a single shared sanitizer (Core.SanitizeChatMsgArgs) covers all
-- of them. Applied in ProcessTrackedEvent before args are recorded to
-- session.events or dispatched to tracker callbacks.

---@type table<string, fun(args: PackedArgs): PackedArgs>
local EVENT_ARG_SANITIZERS = {
  CHAT_MSG_SYSTEM = Core.SanitizeChatMsgArgs,
  CHAT_MSG_LOOT = Core.SanitizeChatMsgArgs,
  CHAT_MSG_MONEY = Core.SanitizeChatMsgArgs,
  CHAT_MSG_SKILL = Core.SanitizeChatMsgArgs,
  CHAT_MSG_TRADESKILLS = Core.SanitizeChatMsgArgs,
  CHAT_MSG_COMBAT_FACTION_CHANGE = Core.SanitizeChatMsgArgs,
  CHAT_MSG_COMBAT_XP_GAIN = Core.SanitizeChatMsgArgs,
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Trim whitespace from both ends of a string.
---@param s any The value to trim (returns empty string for non-strings)
---@return string trimmed
local function Trim(s)
  if type(s) ~= "string" then return "" end
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Create a session name from an override or generate one from the current date.
---@param override any The optional name override
---@return string name
local function CreateSessionName(override)
  local candidate = Trim(override)
  if candidate ~= "" then return candidate end
  ---@diagnostic disable-next-line: return-type-mismatch
  return date("%Y-%m-%d_%H-%M-%S")
end

---------------------------------------------------------------------------
-- SavedVariables
---------------------------------------------------------------------------

--- Encode a session for QuestieTraceCharacter.sessions: as a plain table it is
--- several times larger in SavedVariables, which the client reads at login and
--- writes at logout.
---@param session SessionRecord
---@return EncodedSessionRecord? record Nil if encoding fails.
local function EncodeSessionRecord(session)
  local encoded = Core.EncodeExportPayload(session)
  if (not encoded) then
    return nil
  end
  return {
    name = session.name,
    schemaVersion = session.schemaVersion,
    duration = session.duration,
    eventCount = type(session.events) == "table" and #session.events or 0,
    encoded = encoded,
  }
end

--- Encode sessions saved as plain tables by older versions, once. Sessions
--- that cannot be encoded are dropped on purpose: encoding is not expected to
--- fail, and keeping them would need a plain-session path in every reader.
local function EncodePlainSessions()
  if (not Core.HasCodecSupport()) then
    return
  end
  local sessions = QuestieTraceCharacter.sessions
  for i = #sessions, 1, -1 do
    local session = sessions[i]
    if type(session) ~= "table" or type(session.encoded) ~= "string" then
      local record = type(session) == "table" and EncodeSessionRecord(session) or nil
      if record then
        sessions[i] = record
      else
        table.remove(sessions, i)
      end
    end
  end
end

--- Ensure SavedVariables tables exist and match the current schema version.
local function EnsureSavedVariables()
  ---@type table?
  local globalDb = QuestieTrace
  local preservedConsent = nil
  if type(globalDb) == "table" and type(globalDb.settings) == "table" then
    preservedConsent = globalDb.settings.dataCollectionConsent
  end

  if type(globalDb) ~= "table" or globalDb.schemaVersion ~= SCHEMA_VERSION then
    QuestieTrace = {
      schemaVersion = SCHEMA_VERSION,
      settings = {},
    }
  end

  QuestieTrace.settings = type(QuestieTrace.settings) == "table" and QuestieTrace.settings or {}

  if QuestieTrace.settings.debug == nil then
    QuestieTrace.settings.debug = false
  end

  if preservedConsent ~= nil then
    QuestieTrace.settings.dataCollectionConsent = preservedConsent
  end

  if type(QuestieTraceDumps) ~= "table" then
    QuestieTraceDumps = {
      schemaVersion = 1,
      dumps = {},
    }
  end
  if type(QuestieTraceDumps.dumps) ~= "table" then
    QuestieTraceDumps.dumps = {}
  end

  QuestieTraceCharacter = type(QuestieTraceCharacter) == "table" and QuestieTraceCharacter or {}
  QuestieTraceCharacter.sessions = type(QuestieTraceCharacter.sessions) == "table" and QuestieTraceCharacter.sessions or {}
  EncodePlainSessions()

  -- Share-reminder state (sessionStart, lastReminderAt). Shape-checked, no SCHEMA_VERSION bump.
  QuestieTraceCharacter.reminder = type(QuestieTraceCharacter.reminder) == "table" and QuestieTraceCharacter.reminder or {}

  -- Recover an unsaved session left over from a previous load (e.g. /reload
  -- or logout without explicit Save). Auto-finalize it into sessions[]
  -- immediately so the normal PLAYER_LOGIN flow starts fresh.
  if QuestieTraceCharacter.currentSession then
    local settings = QuestieTrace and QuestieTrace.settings
    local consent = settings and settings.dataCollectionConsent
    if consent == true then
      capture.session = QuestieTraceCharacter.currentSession
      if (not capture.session.stoppedAt) then
        capture.session.stoppedAt = GetTime()
        capture.session.stoppedAtPrecise = GetTimePreciseSec()
        capture.session.duration = capture.session.stoppedAt - capture.session.startedAt
        capture.session.durationPrecise = capture.session.stoppedAtPrecise - capture.session.startedAtPrecise
      end
      -- Finalize it into sessions[] right away
      Core.SaveCapture()
    else
      -- Consent not granted (declined or undecided): discard the recovered session
      QuestieTraceCharacter.currentSession = nil
    end
  end
end

---------------------------------------------------------------------------
-- Status data (consumed by UI)
---------------------------------------------------------------------------

--- Get the current capture state as a string label.
---@return "running"|"stopped_unsaved"|"idle"
function Core.GetCaptureState()
  if capture.active then
    return "running"
  elseif capture.session then
    return "stopped_unsaved"
  else
    return "idle"
  end
end

--- Get status data for UI consumption.
---@return StatusData
function Core.GetStatusData()
  local duration = nil
  if capture.active and capture.startedAt then
    duration = GetTime() - capture.startedAt
  end
  return {
    captureState = Core.GetCaptureState(),
    isRunning = capture.active,
    sessionName = capture.session and (capture.session.name or "(unnamed)") or "None",
    eventCount = capture.session and #capture.session.events or 0,
    canSave = capture.session ~= nil and not capture.active,
    sessionDuration = duration,
  }
end

--- Return the live or newest saved session for external diagnostics.
---
--- This is intended for read-only bridge/testing inspection. The returned
--- session table is the actual live table (or a decoded copy of an encoded
--- saved session), not a defensive copy; callers MUST treat it as read-only.
---@return SessionRecord? session The active/stopped unsaved session, newest saved session, or nil.
---@return "active"|"stopped_unsaved"|"saved"|"none" source Where the session came from.
function Core.GetDiagnosticSession()
  if capture.session then
    return capture.session, capture.active and "active" or "stopped_unsaved"
  end

  local characterDb = QuestieTraceCharacter
  if type(characterDb) == "table" and type(characterDb.sessions) == "table" then
    local record = characterDb.sessions[#characterDb.sessions]
    local session = type(record) == "table" and Core.DecodeExportPayload(record.encoded) or nil
    if session then
      return session, "saved"
    end
  end

  return nil, "none"
end

---------------------------------------------------------------------------
-- Session lifecycle
---------------------------------------------------------------------------

--- Start a new capture session.
---@param sessionName string? Optional name for the session
function Core.StartCapture(sessionName)
  if capture.active then
    return
  end

  local settings = QuestieTrace and QuestieTrace.settings
  if not (settings and settings.dataCollectionConsent == true) then
    Core.Print(Core.l10n("Data collection is disabled. Use \"/qlt consent\" to change this."))
    return
  end

  capture.token = capture.token + 1
  capture.startedAt = GetTime()
  capture.startedAtPrecise = GetTimePreciseSec()

  capture.session = {
    schemaVersion = SCHEMA_VERSION,
    -- Mark new captures only; existing v9 sessions may contain synthetic resets.
    recordingContractVersion = 1,
    -- The client build that produced the trace, so replay can pick the matching
    -- flavor and UI source (e.g. "1.15.9", "70003" vs "1.60.1", "70425").
    buildInfo = type(GetBuildInfo) == "function" and Core.PackArgs(GetBuildInfo()) or nil,
    name = Trim(sessionName) ~= "" and Trim(sessionName) or nil,
    startedAt        = capture.startedAt,
    startedAtPrecise = capture.startedAtPrecise,
    events = {},
    functions = {},
    functionsDelta = {},
  }

  -- Link the in-memory session into SavedVariables so it survives /reload
  -- and logout without an explicit Save. Since trackers mutate the table
  -- in place, a single reference assignment is sufficient.
  QuestieTraceCharacter.currentSession = capture.session

  capture.active = true

  -- Initialize all registered trackers
  for i = 1, #Core._trackers do
    local tracker = Core._trackers[i]
    if tracker.Init then
      tracker.Init(capture)
    end
  end
end

--- Stop the active capture session.
function Core.StopCapture()
  if not capture.active or not capture.session then
    return
  end

  capture.session.stoppedAt        = GetTime()
  capture.session.stoppedAtPrecise = GetTimePreciseSec()
  capture.session.duration         = capture.session.stoppedAt - capture.session.startedAt
  capture.session.durationPrecise  = capture.session.stoppedAtPrecise - capture.session.startedAtPrecise

  capture.active = false

  -- Notify trackers that capture has stopped
  for i = 1, #Core._trackers do
    local tracker = Core._trackers[i]
    if tracker.OnCaptureStopped then
      tracker.OnCaptureStopped(capture)
    end
  end
end

--- Stop and discard the current capture without saving it to sessions[].
--- Used only when consent is revoked mid-capture (see Modules/Consent.lua),
--- since data collected up to that point must not be persisted once declined.
function Core.DiscardCapture()
  if capture.active then
    Core.StopCapture()
  end
  capture.session = nil
  QuestieTraceCharacter.currentSession = nil
end

--- Drop the oldest saved sessions once the count exceeds MAX_SESSIONS.
--- A pure size backstop for players who never report/export -- reported
--- sessions are already deleted immediately by Core.DeleteReportedSessions(),
--- so there is no "prefer evicting already-exported sessions" tie-break here.
local function PruneSessionsIfNeeded()
  local sessions = QuestieTraceCharacter.sessions
  while #sessions > MAX_SESSIONS do
    table.remove(sessions, 1)
  end
end

--- Save the current capture session to SavedVariables.
---@param nameOverride string? Optional name override for the session
function Core.SaveCapture(nameOverride)
  if capture.active then
    Core.StopCapture()
  end

  if not capture.session then
    return
  end

  ---@type SessionRecord
  local session = capture.session
  session.name = CreateSessionName(nameOverride or session.name)

  -- Ensure stop timestamps exist
  if not session.stoppedAt then
    session.stoppedAt        = GetTime()
    session.stoppedAtPrecise = GetTimePreciseSec()
    session.duration         = session.stoppedAt - session.startedAt
    session.durationPrecise  = session.stoppedAtPrecise - session.startedAtPrecise
  end

  -- A session that cannot be encoded is dropped on purpose: encoding is not
  -- expected to fail, and retrying is not worth the extra code.
  local record = EncodeSessionRecord(session)
  if record then
    QuestieTraceCharacter.sessions[#QuestieTraceCharacter.sessions + 1] = record
    QuestieTraceCharacter.lastSavedSession = session.name
  end

  PruneSessionsIfNeeded()

  capture.session = nil
  QuestieTraceCharacter.currentSession = nil
end

---------------------------------------------------------------------------
-- Event processing
---------------------------------------------------------------------------

--- Process a tracked event: record it and dispatch to registered tracker callbacks.
---@param event string The event name
---@param ... any Event arguments
local function ProcessTrackedEvent(event, ...)
  if not capture.active or not capture.session then return end

  -- Record raw event
  ---@type number
  local t  = GetTime() - capture.startedAt
  ---@type number
  local tp = GetTimePreciseSec() - capture.startedAtPrecise
  ---@type PackedArgs
  local packedArgs = Core.CopyPacked(Core.PackArgs(...))

  -- Privacy: sanitize args (e.g. strip player names/GUIDs from CHAT_MSG_*
  -- events) before they are ever stored or handed to trackers.
  local sanitizer = EVENT_ARG_SANITIZERS[event]
  if sanitizer then
    packedArgs = sanitizer(packedArgs)
  end

  capture.session.events[#capture.session.events + 1] = {
    t = t,
    tp = tp,
    e = event,
    a = packedArgs,
  }

  -- Dispatch to registered tracker callbacks
  ---@type fun(capture: CaptureState, event: string, ...)[]?
  local callbacks = Core._trackerCallbacks[event]
  if callbacks then
    for i = 1, #callbacks do
      callbacks[i](capture, event, unpack(packedArgs, 1, packedArgs.n))
    end
  end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

--- Print the current capture status to chat.
local function PrintStatus()
  ---@type StatusData
  local state = Core.GetStatusData()
  ---@type string
  local running = state.isRunning and "running" or "stopped"
  local settings = QuestieTrace and QuestieTrace.settings
  local consent = settings and settings.dataCollectionConsent
  local consentStr = consent == true and "granted" or consent == false and "declined" or "pending"
  local parts = { "status:", running, "session:", state.sessionName, "events:", state.eventCount, "consent:", consentStr }
  if state.sessionDuration then
    table.insert(parts, "duration:")
    local mins = math.floor(state.sessionDuration / 60)
    local secs = math.floor(state.sessionDuration % 60)
    table.insert(parts, string.format("%dm %02ds", mins, secs))
  end
  Core.Print(unpack(parts))
end

--- Print the available slash commands to chat.
local function PrintHelp()
  print("/qlt status - Show capture status")
  print("/qlt consent - Show the data collection consent prompt")
  print("/qlt debug - Toggle debug prints")
  print("/qlt export - Show the export window")
  if Core.GetDumpHelpLines then
    local dumpHelpLines = Core.GetDumpHelpLines()
    for i = 1, #dumpHelpLines do
      print(dumpHelpLines[i])
    end
  end
end

---@param msg string? The slash command arguments
SlashCmdList["QUESTIETRACE"] = function(msg)
  ---@type string, string?
  local action, argument = strsplit(" ", msg or "", 2)
  action = string.lower(action or "")

  if action == "" or action == "help" then
    PrintHelp()
  elseif action == "status" then
    PrintStatus()
  elseif action == "consent" then
    Core.ShowConsentPrompt()
  elseif action == "debug" then
    QuestieTrace.settings.debug = not QuestieTrace.settings.debug
    Core.Print("Debug prints:", QuestieTrace.settings.debug and "enabled" or "disabled")
  elseif action == "export" then
    Core.ShowExportWindow()
  elseif Core.RunDumpBySlash(action, argument) then
    -- handled by dump provider
  else
    Core.Print("Unknown command:", action)
    PrintHelp()
  end
end

SLASH_QUESTIETRACE1 = "/questietrace"
SLASH_QUESTIETRACE2 = "/qlt"

---------------------------------------------------------------------------
-- Bootstrap
---------------------------------------------------------------------------

--- Main event handler for the addon's event frame.
---@param _ Frame
---@param event string
---@param ... any
local function OnEvent(_, event, ...)
  -- 1. Initialize before login dumps and auto-start on PLAYER_LOGIN.
  if event == "PLAYER_LOGIN" then
    EnsureSavedVariables()
  end

  -- 2. Event filtering
  local filter = EVENT_FILTERS[event]
  if filter and not filter(...) then return end

  -- 3. Dump providers + auto-start on PLAYER_LOGIN
  --    StartCapture BEFORE ProcessTrackedEvent so PLAYER_LOGIN
  --    is recorded as the first event in the session.
  if Core.RunDumpsForEvent then
    Core.RunDumpsForEvent(event, ...)
  end
  if event == "PLAYER_LOGIN" then
    Core.HandleConsentOnLogin()
  end

  -- 4. Process the event (record + dispatch to trackers)
  ProcessTrackedEvent(event, ...)

  -- 5. Auto-save on PLAYER_LOGOUT
  --    ProcessTrackedEvent runs first so the event is recorded
  --    in the session before saving.
  if event == "PLAYER_LOGOUT" and capture.active then
    Core.SaveCapture()
  end
end

---@type Frame
local eventFrame = CreateFrame("Frame")
for i = 1, #TRACKED_EVENTS do
  ---@type boolean
  local ok = pcall(eventFrame.RegisterEvent, eventFrame, TRACKED_EVENTS[i])
  if not ok then
    Core.Debug("Skipping unsupported event:", TRACKED_EVENTS[i])
  end
end
eventFrame:SetScript("OnEvent", OnEvent)
