local addonName, AM = ...

-- A developer log in the saved variables, so a problem that only shows in game can be read from the file after a
-- /reload instead of being described or pasted. Off by default and switched with the hidden command "/am log on|off".
-- While it is off, Log returns at once and nothing is stored or registered.
--
-- It lives in the global object "debugLog": { enabled, sessions = { session, ... } }. Every Lua session (a login or a
-- reload) that logs something gets its own entry { startedAt (time), addon, client, count, lines }, created with the
-- first line. At most MAX_SESSIONS are kept (the oldest goes first), none older than MAX_AGE, and all of them together
-- hold at most MAX_TOTAL_LINES: a new session drops the oldest ones until the others leave room for a full one, so the
-- file stays small even when several sessions are long. A session keeps its
-- last MAX_LINES lines as a ring: line number n (1-based, n <= count) is lines[(n - 1) % MAX_LINES + 1], so once
-- count > MAX_LINES the oldest line is lines[count % MAX_LINES + 1]. A line is "<seconds since the session start>
-- <category> <text>". A line repeated at once (the game fires some events thousands of times in a row) is written
-- only once, with " (xN)" appended to it as it repeats.
--
-- Besides what the modules log themselves, the log listens to the game's auction house events and hooks the
-- C_AuctionHouse functions we use (hooksecurefunc, after the call, nothing is changed). Both only read.
AM.DebugLog = {}
local DebugLog = AM.DebugLog

local MAX_SESSIONS = 10
local MAX_LINES = 5000
local MAX_TOTAL_LINES = 20000
local MAX_LINE_LENGTH = 1000
local MAX_AGE = 7 * 24 * 60 * 60

-- The game's events logged while the log is on. Registering an event a client does not know fails, so each one is tried.
-- Not REPLICATE_ITEM_LIST_UPDATE: a full scan fires it over a hundred thousand times, Scan.lua logs its first one.
local GAME_EVENTS = {
  "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_DISABLED",
  "AUCTION_HOUSE_BROWSE_FAILURE",
  "COMMODITY_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_ADDED", "COMMODITY_SEARCH_RESULTS_RECEIVED",
  "ITEM_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_ADDED",
  "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT", "AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED",
  "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
  "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_CANCELED", "AUCTION_MULTISELL_START", "AUCTION_MULTISELL_FAILURE",
  "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED",
}

-- The C_AuctionHouse calls logged while the log is on.
local GAME_CALLS = {
  "ReplicateItems", "SendBrowseQuery", "SendSearchQuery", "SendSellSearchQuery", "PostItem", "PostCommodity",
  "RefreshCommoditySearchResults", "RefreshItemSearchResults", "RequestMoreCommoditySearchResults",
  "RequestMoreItemSearchResults",
  "ConfirmCommoditiesPurchase", "PlaceBid", "CancelAuction",
}

local enabled = false
local session, sessionStart
local lastKey, lastLine, lastIndex, repeats -- the line written last, and how often it came in a row
local listener
local hooked = {}

local function State()
  return AM.Database.GetGlobalObject("debugLog")
end

local function Sessions()
  local state = State()
  state.sessions = state.sessions or {}
  return state.sessions
end

-- A value as short text for a line: tables are reduced to what identifies them (item keys, locations).
local function Describe(value)
  local kind = type(value)
  if kind == "number" or kind == "string" then
    return value
  elseif kind == "table" then
    local itemId = value.itemID or (value.itemKey and value.itemKey.itemID)
    if itemId then
      local level = value.itemLevel
      return "item:" .. itemId .. (level and level > 0 and "@" .. level or "")
    end
    return "table"
  end
  return tostring(value)
end
DebugLog.Describe = Describe

local function DescribeAll(...)
  local count = select("#", ...)
  local parts = { ... }
  for index = 1, count do
    parts[index] = tostring(Describe(parts[index]))
  end
  return table.concat(parts, " ")
end
DebugLog.DescribeAll = DescribeAll

local function StartSession()
  local sessions = Sessions()
  local kept = 0
  for _, old in ipairs(sessions) do
    kept = kept + math.min(old.count or 0, MAX_LINES)
  end
  while #sessions > 0 and (#sessions >= MAX_SESSIONS or kept > MAX_TOTAL_LINES - MAX_LINES) do
    kept = kept - math.min(sessions[1].count or 0, MAX_LINES)
    table.remove(sessions, 1)
  end
  session = {
    startedAt = time(),
    addon = AM.version,
    client = AM.Client and AM.Client.GetName(),
    count = 0,
    lines = {},
  }
  sessions[#sessions + 1] = session
  sessionStart = GetTime()
  lastKey = nil
end

local function Write(category, text)
  if not session then
    StartSession()
  end
  local key = category .. " " .. text
  if key == lastKey then
    repeats = repeats + 1
    session.lines[lastIndex] = lastLine .. " (x" .. repeats .. ")"
    return
  end
  local line = ("%.1f %s"):format(GetTime() - sessionStart, key)
  if #line > MAX_LINE_LENGTH then
    line = line:sub(1, MAX_LINE_LENGTH - 3) .. "..."
  end
  lastKey, lastLine, lastIndex, repeats = key, line, session.count % MAX_LINES + 1, 1
  session.lines[lastIndex] = line
  session.count = session.count + 1
end

function DebugLog.IsEnabled()
  return enabled
end

-- Adds a line. message is a format string for the arguments after it (tables, booleans and nil are shortened to text
-- first, so any value may be passed); without arguments it is taken as it is. Callers that have to work something
-- out only for the log ask IsEnabled first.
function DebugLog.Log(category, message, ...)
  if not enabled then
    return
  end
  local count = select("#", ...)
  if count > 0 then
    local args = { ... }
    for index = 1, count do
      args[index] = Describe(args[index])
    end
    local ok, text = pcall(string.format, message, unpack(args, 1, count))
    message = ok and text or (message .. " " .. DescribeAll(...))
  end
  Write(category, message)
end

local function ListenToGame()
  if not listener then
    listener = CreateFrame("Frame")
    listener:SetScript("OnEvent", function(_, event, ...)
      DebugLog.Log("game", "%s %s", event, DescribeAll(...))
    end)
  end
  for _, name in ipairs(GAME_EVENTS) do
    pcall(listener.RegisterEvent, listener, name)
  end
  for _, name in ipairs(GAME_CALLS) do
    if not hooked[name] and C_AuctionHouse and type(C_AuctionHouse[name]) == "function" then
      hooked[name] = true
      pcall(hooksecurefunc, C_AuctionHouse, name, function(...)
        DebugLog.Log("call", "%s %s", name, DescribeAll(...))
      end)
    end
  end
end

function DebugLog.SetEnabled(on)
  on = on and true or false
  State().enabled = on
  if on == enabled then
    return
  end
  if on then
    enabled = true
    ListenToGame()
    DebugLog.Log("log", "on, addon %s", AM.version)
  else
    DebugLog.Log("log", "off")
    enabled = false
    if listener then
      listener:UnregisterAllEvents()
    end
  end
end

-- Removes every stored session.
function DebugLog.Clear()
  State().sessions = {}
  session, lastKey = nil, nil
end

-- Number of stored sessions, and the lines the current one holds (kept ones, not counting those pushed out).
function DebugLog.GetStatus()
  return #Sessions(), session and math.min(session.count, MAX_LINES) or 0
end

-- Must be called once the saved variables are loaded. Drops sessions that are too old and starts listening if the log was
-- left on.
function DebugLog.Init()
  local state = State()
  local sessions = Sessions()
  for index = #sessions, 1, -1 do
    if time() - (sessions[index].startedAt or 0) > MAX_AGE then
      table.remove(sessions, index)
    end
  end
  enabled = false
  session, lastKey = nil, nil
  if state.enabled == true then
    enabled = true
    ListenToGame()
    DebugLog.Log("log", "session start, addon %s", AM.version)
  end
end
