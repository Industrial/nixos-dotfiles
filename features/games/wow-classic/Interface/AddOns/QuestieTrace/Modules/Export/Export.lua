---@class QuestieTraceCore
local Core = QuestieTraceCore

---@type l10n
local l10n = Core.l10n

---------------------------------------------------------------------------
-- Export payload building (data only -- no UI here)
---------------------------------------------------------------------------
-- This file is strictly about turning saved sessions into a shareable,
-- privacy-scrubbed payload/string. Encoding lives in Encoding.lua, and
-- window/frame code lives in ExportUI.lua.
---------------------------------------------------------------------------

---@type number
local EXPORT_VERSION = 1

--- Human-readable marker prepended to every exported string.
--- Lets anyone glance at an export (in a chat window, a bug report, a text
--- file, ...) and immediately identify it as QuestieTrace data and which
--- export version produced it, without decoding the payload. Mirrors the
--- common WoW-addon convention of tagging exports with a short prefix
--- (e.g. WeakAuras' "!WA:2!").
---@type string
local EXPORT_PREFIX = "!QuestieTrace:" .. EXPORT_VERSION .. "!"

--- Human-readable marker appended to every exported string.
--- Lets users quickly detect if the string got cut off during export or
--- transmission without having to decode the entire payload.
---@type string
local EXPORT_SUFFIX = "!End:QuestieTrace:" .. EXPORT_VERSION .. "!"

--- Recursively copy a value (tables only; scalars are returned as-is).
---@param value any
---@return any
local function DeepCopy(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for k, v in pairs(value) do
    out[k] = DeepCopy(v)
  end
  return out
end

--- Read the local player's GUID as observed on the "player" token of a session's UnitGUID stream.
---@param guidStream table<string, FunctionStreamEntry[]> UnitGUID function stream
---@return string? playerGuid
local function GetPlayerGuid(guidStream)
  local playerEntries = guidStream["player"]
  if type(playerEntries) ~= "table" or #playerEntries == 0 then
    return nil
  end
  return playerEntries[1].v
end

--- Remove entries whose value equals playerGuid from every token in the UnitGUID stream, in place.
---@param guidStream table<string, FunctionStreamEntry[]> UnitGUID function stream
---@param playerGuid string
---@return table<string, table<number, boolean>> scrubbedTimes Sample times (`t`) removed per token
local function RemovePlayerGuidObservations(guidStream, playerGuid)
  ---@type table<string, table<number, boolean>>
  local scrubbedTimes = {}

  for token, entries in pairs(guidStream) do
    if type(entries) == "table" then
      for i = #entries, 1, -1 do
        local entry = entries[i]
        if entry and entry.v == playerGuid then
          scrubbedTimes[token] = scrubbedTimes[token] or {}
          scrubbedTimes[token][entry.t] = true
          table.remove(entries, i)
        end
      end
    end
  end

  return scrubbedTimes
end

--- Remove UnitName entries matching the (token, sample time) pairs scrubbed from the UnitGUID stream, in place.
---@param nameStream table<string, FunctionStreamEntry[]> UnitName function stream
---@param scrubbedTimes table<string, table<number, boolean>> Result of RemovePlayerGuidObservations
local function RemoveMatchingNameObservations(nameStream, scrubbedTimes)
  for token, times in pairs(scrubbedTimes) do
    local entries = nameStream[token]
    if type(entries) == "table" then
      for i = #entries, 1, -1 do
        local entry = entries[i]
        if entry and times[entry.t] then
          table.remove(entries, i)
        end
      end
    end
  end
end

--- Drop token keys whose entry list has become empty, so an empty stream looks the same as one that was never recorded.
---@param stream table<string, FunctionStreamEntry[]>
local function PruneEmptyTokens(stream)
  for token, entries in pairs(stream) do
    if type(entries) == "table" and #entries == 0 then
      stream[token] = nil
    end
  end
end

--- Remove captured data that could reveal player identity from a copied
--- session's function streams, in place.
---
--- Any UnitGUID observation matching the local player's GUID is removed,
--- regardless of which token recorded it (e.g. "target" when the player
--- targets themselves), along with the UnitName observation for the same
--- token and sample time. Unrelated observations are left untouched.
---@param functions table<string, FunctionStream>?
local function ScrubFunctions(functions)
  if type(functions) ~= "table" then
    return
  end

  local guidStream = functions.UnitGUID
  local nameStream = functions.UnitName
  if type(guidStream) ~= "table" or type(nameStream) ~= "table" then
    return
  end

  local playerGuid = GetPlayerGuid(guidStream)
  if not playerGuid then return end

  local scrubbedTimes = RemovePlayerGuidObservations(guidStream, playerGuid)
  RemoveMatchingNameObservations(nameStream, scrubbedTimes)

  PruneEmptyTokens(guidStream)
  PruneEmptyTokens(nameStream)
end

--- Build a scrubbed, exportable copy of sessions for this character, plus the
--- current unsaved session (if any), so users don't have to Save before
--- exporting. If there is nothing to export, the payload will have an empty
--- sessions array and hasExportableData = false, letting the UI display an
--- appropriate warning.
---
--- Every saved session is included: reported sessions are deleted by
--- Core.DeleteReportedSessions() rather than kept around with a marker, so
--- anything still in QuestieTraceCharacter.sessions is guaranteed unreported.
---
--- The payload itself only ever contains scrubbed, deep-copied data safe to
--- serialize and send off-device. The real (non-copied) session tables
--- included in this payload are returned separately as `sourceSessions`,
--- parallel to `payload.sessions` -- NOT as a field of the payload, so it can
--- never accidentally end up inside the string handed to the encoder. Callers
--- that actually hand the payload off (e.g. by showing it in the export
--- window) should pass `sourceSessions` to Core.DeleteReportedSessions()
--- afterwards so that data is not offered again next time.
---@return table payload
---@return (EncodedSessionRecord|SessionRecord)[] sourceSessions Stored records backing `payload.sessions`, in the same order.
function Core.BuildExportPayload()
  ---@type SessionRecord[]
  local sessions = {}
  ---@type SessionRecord[]
  local sourceSessions = {}

  ---@type table?
  local characterDb = QuestieTraceCharacter
  ---@type EncodedSessionRecord[]
  local savedSessions = (type(characterDb) == "table" and type(characterDb.sessions) == "table") and characterDb.sessions or {}

  for i = 1, #savedSessions do
    local source = savedSessions[i]
    -- Decoding yields a fresh table, so no copy is needed.
    ---@type SessionRecord?
    local session = Core.DecodeExportPayload(source.encoded)
    if session then
      ScrubFunctions(session.functions)
      sessions[#sessions + 1] = session
      sourceSessions[#sourceSessions + 1] = source
    end
  end

  ---@type SessionRecord?
  local currentSession = type(characterDb) == "table" and characterDb.currentSession or nil
  if type(currentSession) == "table" and type(currentSession.events) == "table" and #currentSession.events > 0 then
    local session = DeepCopy(currentSession)
    ScrubFunctions(session.functions)
    sessions[#sessions + 1] = session
    sourceSessions[#sourceSessions + 1] = currentSession
  end

  return {
    exportVersion = EXPORT_VERSION,
    generatedAt = (type(date) == "function") and date("%Y-%m-%d %H:%M:%S") or nil,
    hasExportableData = #sessions > 0,
    sessions = sessions,
  }, sourceSessions
end

--- Permanently delete every session in `sourceSessions` (the second return
--- value of Core.BuildExportPayload()) now that its data has actually been
--- reported. Call this only once the payload has actually been handed to the
--- user AND they confirmed submitting it -- not merely on showing it.
---
--- Saved sessions are removed from QuestieTraceCharacter.sessions[]. If a live
--- (running or stopped-unsaved) session was included in the payload, it is
--- discarded (never saved) and a fresh capture is started immediately (since
--- consent is required for export), so future events land in a new, distinct
--- session rather than one that no longer exists.
---
--- Note: Core.ShowExportWindow() already rotates the live session when encoding
--- succeeds: it saves the live session and replaces it in `sourceSessions` with
--- the saved record, so that record is deleted here like any other saved
--- session. The live session at deletion time is then a fresh one started
--- after the payload snapshot, and DiscardCapture() is usually not called. The
--- live-session check still exists for safety, in case rotation was skipped or failed.
---@param sourceSessions SessionRecord[] Second return value of Core.BuildExportPayload()
function Core.DeleteReportedSessions(sourceSessions)
  if type(sourceSessions) ~= "table" then return end

  ---@type table?
  local characterDb = QuestieTraceCharacter
  ---@type SessionRecord[]?
  local savedSessions = type(characterDb) == "table" and characterDb.sessions or nil
  ---@type SessionRecord?
  local liveSession = type(characterDb) == "table" and characterDb.currentSession or nil

  for i = 1, #sourceSessions do
    ---@type SessionRecord
    local session = sourceSessions[i]
    if session == liveSession then
      Core.DiscardCapture()
      Core.StartCapture()
    elseif savedSessions then
      for j = #savedSessions, 1, -1 do
        if savedSessions[j] == session then
          table.remove(savedSessions, j)
          break
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Statistics
---------------------------------------------------------------------------

---@class ExportStats
---@field eventCount integer Total events across every session in the payload.
---@field timeRecorded number Total seconds recorded across every session in the payload.
---@field questsAccepted integer QUEST_ACCEPTED events across every session in the payload.
---@field questsTurnedIn integer QUEST_TURNED_IN events across every session in the payload.

--- Seconds a session covers. The live session is copied into the payload
--- before it is stopped, so it has no `duration` yet; its last event's
--- session-relative time is the best lower bound the payload itself holds.
---@param session SessionRecord
---@return number
local function _SessionDuration(session)
  if type(session.duration) == "number" then
    return session.duration
  end
  local events = session.events
  local lastEvent = type(events) == "table" and events[#events] or nil
  if type(lastEvent) == "table" and type(lastEvent.t) == "number" then
    return lastEvent.t
  end
  return 0
end

--- Derive player-facing statistics from a payload previously built by
--- Core.BuildExportPayload(), to show alongside the export string.
---
--- Returned separately rather than stored on the payload, so stats never end
--- up inside the encoded string and the export format stays unchanged. The
--- payload is only read, never modified.
---@param payload table Result of Core.BuildExportPayload().
---@return ExportStats
function Core.BuildExportStats(payload)
  local eventCount = 0
  local timeRecorded = 0
  local questsAccepted = 0
  local questsTurnedIn = 0

  local sessions = type(payload) == "table" and payload.sessions or nil
  if type(sessions) == "table" then
    for i = 1, #sessions do
      local session = sessions[i]
      if type(session) == "table" then
        timeRecorded = timeRecorded + _SessionDuration(session)

        local events = session.events
        if type(events) == "table" then
          eventCount = eventCount + #events
          -- One pass over the events shared by every per-event stat.
          for j = 1, #events do
            local eventName = type(events[j]) == "table" and events[j].e or nil
            if eventName == "QUEST_ACCEPTED" then
              questsAccepted = questsAccepted + 1
            elseif eventName == "QUEST_TURNED_IN" then
              questsTurnedIn = questsTurnedIn + 1
            end
          end
        end
      end
    end
  end

  return {
    eventCount = eventCount,
    timeRecorded = timeRecorded,
    questsAccepted = questsAccepted,
    questsTurnedIn = questsTurnedIn,
  }
end

---------------------------------------------------------------------------
-- Serialization
---------------------------------------------------------------------------

--- Build the full exportable string for a payload previously built by
--- Core.BuildExportPayload(). The result is always prefixed with
--- EXPORT_PREFIX so the export version is visible without decoding the
--- payload, and suffixed with EXPORT_SUFFIX so users can detect if the
--- string was cut off.
---
--- Accepting the payload as a parameter (rather than building one
--- internally) lets callers build it once, inspect hasExportableData, encode
--- it, and mark it exported, all from the same payload/sourceSessions.
---@param payload table? Result of Core.BuildExportPayload(). Built fresh (with defaults) if omitted.
---@return boolean ok Whether `text` contains real encoded data (false = error message).
---@return string text
function Core.BuildExportString(payload)
  payload = payload or Core.BuildExportPayload()
  local encoded, err = Core.EncodeExportPayload(payload)
  if encoded then
    return  true, EXPORT_PREFIX .. encoded .. EXPORT_SUFFIX
  end
  -- Encoding was attempted and failed; surface the real reason.
  if err then
    return false, l10n("ERROR: Encoding failed: %s", err)
  end
  -- Fallback: if codec is missing, return an error message instead of crashing.
  return false, l10n("ERROR: Client does not have required codec support (C_EncodingUtil, Enum.CompressionMethod, LibDeflate)")
end
