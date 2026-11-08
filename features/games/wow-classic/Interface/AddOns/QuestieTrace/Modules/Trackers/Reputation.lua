---@type QuestieTraceCore
local Core = QuestieTraceCore
---@type fun(...): PackedArgs
local PackArgs = Core.PackArgs
---@type fun(t1: any, t2: any, ignore_mt: boolean?, visited: table?): boolean
local DeepCompare = Core.DeepCompare

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- Faction detail is recorded from whichever real API the client exposes;
-- there is no synthesized/normalized composite value.
--
-- C_Reputation.GetFactionDataByID(factionID) -> table data (raw, as returned)
--
-- GetFactionInfoByID(factionID) -> string  name,     -- legacy global, only
--                                  string  description,  -- recorded when it
--                                  number  standingID,   -- exists
--                                  number  barMin,
--                                  number  barMax,
--                                  number  barValue,
--                                  boolean atWarWith,
--                                  boolean canToggleAtWar,
--                                  boolean isHeader,
--                                  boolean isCollapsed,
--                                  boolean hasRep,
--                                  boolean isWatched,
--                                  boolean isChild,
--                                  number  factionID,
--                                  boolean hasBonusRepGain,
--                                  boolean canSetInactive
--
-- GetNumFactions()/C_Reputation.GetNumFactions() and
-- GetFactionInfo(index)/C_Reputation.GetFactionDataByIndex(index) are used
-- only to drive faction-ID discovery (CollectFactionIDs) below; they are not
-- themselves recorded to the trace.
--
-- FactionOrder (custom stream) -> number[] factionIDs  -- ordered known faction IDs
---------------------------------------------------------------------------

-- Only the player's own reputation panel is recorded. A faction outside it has
-- never had a reputation change, so it still holds its starting value; replay
-- answers those from a static per-faction-group table instead of every
-- player's client being asked for hundreds of factions at login.

---Privacy: the guild reputation faction (Cataclysm and later clients) is
---named after the player's guild, so its detail is never sampled. It stays
---in FactionOrder, which only holds IDs.
---@type number
local GUILD_FACTION_ID = 1168

---@type table<string, FunctionStreamEntry[]|table<string|number, FunctionStreamEntry[]>>
local functions       -- capture.session.functions
---@type number[]
local factionOrder    -- ordered array of known factionIDs
---@type boolean
local collecting      -- recursion guard for ExpandFactionHeader

--- Number of factions visible in the reputation panel, from whichever real
--- API exists. Used only to bound CollectFactionIDs' iteration; not recorded.
---@return number
local function GetNumFactionsRaw()
  if C_Reputation and C_Reputation.GetNumFactions then
    return C_Reputation.GetNumFactions() or 0
  elseif GetNumFactions then
    return GetNumFactions() or 0
  end
  return 0
end

--- Header/collapsed/factionID for a reputation-panel row, from whichever
--- real API exists. Used only to drive CollectFactionIDs' iteration; not
--- recorded.
---@param index number
---@return boolean? isHeader
---@return boolean? isCollapsed
---@return number? factionID
local function GetFactionRowRaw(index)
  if C_Reputation and C_Reputation.GetFactionDataByIndex then
    local d = C_Reputation.GetFactionDataByIndex(index)
    if not d then return nil end
    return d.isHeader, d.isCollapsed, d.factionID
  elseif GetFactionInfo then
    local _, _, _, _, _, _, _, _, isHeader, isCollapsed, _, _, _, factionID = GetFactionInfo(index)
    return isHeader, isCollapsed, factionID
  end
  return nil
end

--- Discover all factionIDs by iterating the reputation panel.
--- Expands collapsed headers (side effect). Never re-collapses.
---@return number[] ids Ordered array of factionIDs
local function CollectFactionIDs()
  ---@type number[]
  local ids = {}
  ---@type number
  local numFactions = GetNumFactionsRaw()
  if numFactions == 0 then return ids end

  collecting = true
  ---@type number
  local index = 1

  while index <= numFactions do
    local isHeader, isCollapsed, factionID = GetFactionRowRaw(index)

    if factionID then
      ids[#ids + 1] = factionID
    end

    if isHeader and isCollapsed and type(ExpandFactionHeader) == "function" then
      ExpandFactionHeader(index)
      numFactions = GetNumFactionsRaw()
    end

    index = index + 1
  end

  collecting = false
  return ids
end

--- Append a faction detail value to its stream if it differs from the
--- stream's last entry. A nil value is recorded once, like any other value.
---@param streamKey string
---@param factionID number
---@param t number
---@param tp number
---@param value any
local function AppendFactionIfChanged(streamKey, factionID, t, tp, value)
  ---@type FunctionStreamEntry[]
  local stream = functions[streamKey][factionID]
  if not stream then
    stream = {}
    functions[streamKey][factionID] = stream
  end
  local previous = stream[#stream]
  if not previous or not DeepCompare(value, previous.v) then
    stream[#stream + 1] = { t = t, tp = tp, v = value }
  end
end

--- Sample one faction's detail from every available source, recording each
--- under its own real API name. There is no synthesized/normalized
--- composite value: a client exposing both APIs gets both streams recorded
--- independently. Failed calls are skipped.
---@param t number
---@param tp number
---@param factionID number
local function SampleFaction(t, tp, factionID)
  if C_Reputation and C_Reputation.GetFactionDataByID then
    local ok, value = pcall(C_Reputation.GetFactionDataByID, factionID)
    if ok then
      AppendFactionIfChanged("C_Reputation.GetFactionDataByID", factionID, t, tp, value)
    end
  end

  if GetFactionInfoByID then
    local packed = PackArgs(pcall(GetFactionInfoByID, factionID))
    if packed[1] then
      AppendFactionIfChanged("GetFactionInfoByID", factionID, t, tp, PackArgs(unpack(packed, 2, packed.n)))
    end
  end
end

--- Sample all known factions except the guild faction. Appends {t,tp,v} only
--- when a value changed.
---@param capture CaptureState
local function SampleReputation(capture)
  ---@type number
  local t  = GetTime() - capture.startedAt
  ---@type number
  local tp = GetTimePreciseSec() - capture.startedAtPrecise

  for i = 1, #factionOrder do
    local factionID = factionOrder[i]
    if factionID ~= GUILD_FACTION_ID then
      SampleFaction(t, tp, factionID)
    end
  end
end

--- Full collection + sample. Updates FactionOrder if the set changed.
---@param capture CaptureState
local function CollectAndSample(capture)
  ---@type number[]
  local ids = CollectFactionIDs()

  -- Update FactionOrder stream if changed
  ---@type FunctionStreamEntry[]
  local orderStream = functions["FactionOrder"]
  ---@type FunctionStreamEntry?
  local prevOrder = orderStream[#orderStream]
  if not prevOrder or not DeepCompare(prevOrder.v, ids) then
    ---@type number
    local t  = GetTime() - capture.startedAt
    ---@type number
    local tp = GetTimePreciseSec() - capture.startedAtPrecise
    ---@type number[]
    local copy = {}
    for i = 1, #ids do copy[i] = ids[i] end
    orderStream[#orderStream + 1] = { t = t, tp = tp, v = copy }
  end

  factionOrder = ids
  SampleReputation(capture)
end

Core.RegisterTracker({
  events = {
    "CHAT_MSG_COMBAT_FACTION_CHANGE",
    "UPDATE_FACTION",
    "QUEST_TURNED_IN",
    "PLAYER_ENTERING_WORLD",
    "SPELLS_CHANGED",
  },

  ---@param capture CaptureState
  Init = function(capture)
    functions = capture.session.functions
    functions["FactionOrder"] = {}
    functions["GetFactionInfoByID"] = {}
    functions["C_Reputation.GetFactionDataByID"] = {}
    factionOrder = {}
    collecting = false

    CollectAndSample(capture)
  end,

  ---@param capture CaptureState
  ---@param event string
  OnEvent = function(capture, event)
    -- Recursion guard: ExpandFactionHeader fires UPDATE_FACTION
    if collecting then return end

    if event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED" then
      -- Login-time sampling: values may still be settling, the set is the same
      SampleReputation(capture)
    else
      -- Any reputation change can reveal a new faction: a quest reward, a kill
      -- (CHAT_MSG_COMBAT_FACTION_CHANGE) or a change the client reports only
      -- through UPDATE_FACTION. Re-collecting walks the panel rows once.
      CollectAndSample(capture)
    end
  end,
})
