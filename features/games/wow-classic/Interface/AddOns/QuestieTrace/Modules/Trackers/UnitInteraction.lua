---@type QuestieTraceCore
local Core = QuestieTraceCore
---@type fun(...): PackedArgs
local PackArgs = Core.PackArgs
---@type fun(t1: any, t2: any, ignore_mt: boolean?, visited: table?): boolean
local DeepCompare = Core.DeepCompare

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- UnitGUID(unit)  -> string guid (or nil)
-- UnitName(unit)  -> string name, string realm
--                    (packed actual returns; nil positions omitted by SavedVariables)
--
-- Nameplate tokens ("nameplate1", ...): UnitGUID only, sampled on
-- NAME_PLATE_UNIT_ADDED; see SampleNameplate.
--
-- C_GossipInfo.GetAvailableQuests() -> GossipQuestUIInfo[] (table)
-- C_GossipInfo.GetActiveQuests()    -> GossipQuestUIInfo[] (table)
---------------------------------------------------------------------------

---@type string[]
local TOKENS = { "target", "npc", "questnpc", "mouseover" }

---@type string The only unit tokens NAME_PLATE_UNIT_ADDED may add to the streams.
local NAMEPLATE_TOKEN_PATTERN = "^nameplate%d+$"

-- Stream references (set during Init): the session's UnitGUID and UnitName
-- parameter maps, keyed by unit token.
---@type table<string, FunctionStreamEntry[]>?
local guidStreams
---@type table<string, FunctionStreamEntry[]>?
local nameStreams
---@type FunctionStreamEntry[]?
local gossipAvailableStream
---@type FunctionStreamEntry[]?
local gossipActiveStream

---Safely call a function and return the first result.
---@param fn function?
---@param ... any
---@return boolean ok
---@return any value
local function SafeScalarCall(fn, ...)
  if type(fn) ~= "function" then return false, nil end
  local ok, value = pcall(fn, ...)
  if not ok then return false, nil end
  return true, value
end

---Safely call a function and pack all returned values.
---@param fn function?
---@param ... any
---@return boolean ok
---@return PackedArgs? value
local function SafePackedCall(fn, ...)
  if type(fn) ~= "function" then return false, nil end
  local packed = PackArgs(pcall(fn, ...))
  if not packed[1] then return false, nil end

  local out = { n = packed.n - 1 }
  for i = 2, packed.n do
    out[i - 1] = packed[i]
  end
  return true, out
end

---@param token string
---@param guid string
---@return boolean
local function IsPlayerControlled(token, guid)
  if guid:sub(1, 4) == "Pet-" then
    return true
  end
  local ok, controlled = SafeScalarCall(UnitPlayerControlled, token)
  -- A restricted (secret) answer cannot be compared; treat the unit as player-controlled.
  if ok and issecretvalue and issecretvalue(controlled) then
    return true
  end
  return ok and controlled == true
end

--- Sample UnitGUID and UnitName for every fixed token.
---@param t number Session-relative GetTime()
---@param tp number Session-relative GetTimePreciseSec()
local function SampleAll(t, tp)
  if not guidStreams or not nameStreams then return end

  for _, token in ipairs(TOKENS) do
    -- UnitGUID (scalar string or nil). Store only successful observed returns.
    local guidOk, guid = SafeScalarCall(UnitGUID, token)
    if guidOk then
      -- Privacy: `target`/`npc`/`questnpc` tokens can resolve to another
      -- player character just as easily as an NPC (e.g. targeting a party
      -- member). Never record a player's GUID or name; players are blanked
      -- to "no unit" below. A nil guid (no unit) is still recorded, since
      -- that's a state transition, not PII.
      ---@type "player"|"npc"|"object"|"item"|nil
      local kind = Core.ParseGUIDKind(guid)
      ---@type boolean
      local allowed = guid == nil or kind == "player" or kind == "npc" or kind == "object" or kind == "item"

      -- Players (e.g. a party member sharing a quest) and their pets and
      -- minions (hunter pets, warlock demons, ...) are not world NPCs and
      -- carry player-chosen names. Record them as "no unit" so the token's
      -- previous NPC doesn't appear to linger.
      ---@type boolean
      local playerControlled = kind == "player" or (allowed and guid ~= nil and IsPlayerControlled(token, guid))
      if playerControlled then
        guid = nil
      end

      if allowed then
        ---@type FunctionStreamEntry[]
        local guidStream = guidStreams[token]
        ---@type FunctionStreamEntry?
        local prevGuid = guidStream[#guidStream]
        if not prevGuid or prevGuid.v ~= guid then
          guidStream[#guidStream + 1] = { t = t, tp = tp, v = guid }
        end

        -- UnitName (packed actual returns). Do not synthesize nil from UnitExists;
        -- the token itself is mutable, so event-synchronous observations are the trace.
        local nameOk, nameVal
        if playerControlled then
          -- Same empty result UnitName returns for a token without a unit.
          nameOk, nameVal = true, { n = 2 }
        else
          nameOk, nameVal = SafePackedCall(UnitName, token)
        end
        if nameOk and nameVal then
          ---@type FunctionStreamEntry[]
          local nameStream = nameStreams[token]
          ---@type FunctionStreamEntry?
          local prevName = nameStream[#nameStream]
          if not prevName or not DeepCompare(prevName.v, nameVal) then
            nameStream[#nameStream + 1] = { t = t, tp = tp, v = nameVal }
          end
        end
      end
    end
  end
end

---Whether a GUID is a world creature or vehicle, the only units Questie draws
---nameplate icons on. Pet- GUIDs share the "npc" kind and are excluded here.
---@param guid any
---@return boolean
local function IsCreatureOrVehicleGUID(guid)
  if Core.ParseGUIDKind(guid) ~= "npc" then return false end
  ---@cast guid string
  return guid:find("^Creature%-") ~= nil or guid:find("^Vehicle%-") ~= nil
end

---Record which creature or vehicle a nameplate that just appeared belongs to.
---Questie only reads the GUID (for the NPC ID), so UnitName is not recorded;
---replay answers it from the NPC ID. Instances are sampled too: Questie draws
---nameplate icons in dungeons on Classic clients. Forever restricts GUIDs
---there, and a restricted GUID records nil like any other withheld unit.
---
---Change-only per token, and a unit that is not recorded is written as nil:
---"no recordable unit on this token", not a nil from the client. Nameplate
---tokens are reused as plates come and go, and without the nil a token
---reused by a player would keep answering with its previous NPC.
---@param t number Session-relative GetTime()
---@param tp number Session-relative GetTimePreciseSec()
---@param token any Unit token from the event
local function SampleNameplate(t, tp, token)
  if not guidStreams then return end
  if type(token) ~= "string" or not token:match(NAMEPLATE_TOKEN_PATTERN) then return end

  -- Privacy: players, player pets and minions, game objects and unrecognized
  -- or restricted GUIDs are never stored; their adds record nil. So does a
  -- failed call (Forever refuses some tokens in battlegrounds), since the
  -- token's previous unit is gone either way.
  local guidOk, guid = SafeScalarCall(UnitGUID, token)
  local recordedGUID = nil
  if guidOk and IsCreatureOrVehicleGUID(guid) and not IsPlayerControlled(token, guid) then
    recordedGUID = guid
  end

  local stream = guidStreams[token] or {}
  guidStreams[token] = stream
  local previous = stream[#stream]
  if not previous or previous.v ~= recordedGUID then
    stream[#stream + 1] = { t = t, tp = tp, v = recordedGUID }
  end
end

Core.RegisterTracker({
  events = {
    -- group_world (already registered)
    "NAME_PLATE_UNIT_ADDED",
    -- player_state (already registered)
    "PLAYER_TARGET_CHANGED",
    "UPDATE_MOUSEOVER_UNIT",
    -- quest_dialog (already registered)
    "QUEST_DETAIL",
    "QUEST_PROGRESS",
    "QUEST_COMPLETE",
    "QUEST_GREETING",
    "QUEST_FINISHED",
    "QUEST_ACCEPT_CONFIRM",
    "GOSSIP_SHOW",
    "GOSSIP_CLOSED",
    -- quest_state (already registered)
    "QUEST_ACCEPTED",
    "QUEST_TURNED_IN",
    -- player_state (already registered)
    "LOOT_OPENED",
    -- npc_interaction (new category)
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
    "PLAYER_ENTERING_WORLD",
    "SPELLS_CHANGED",
  },

  ---@param capture CaptureState
  Init = function(capture)
    ---@type table<string, FunctionStreamEntry[]|table<string|number, FunctionStreamEntry[]>>
    local functions = capture.session.functions
    if not functions["UnitGUID"] then functions["UnitGUID"] = {} end
    if not functions["UnitName"] then functions["UnitName"] = {} end

    guidStreams = functions["UnitGUID"] --[[@as table<string, FunctionStreamEntry[]>]]
    nameStreams = functions["UnitName"] --[[@as table<string, FunctionStreamEntry[]>]]
    for _, token in ipairs(TOKENS) do
      guidStreams[token] = {}
      nameStreams[token] = {}
    end

    -- Gossip streams (parameterless)
    functions["C_GossipInfo.GetAvailableQuests"] = {}
    functions["C_GossipInfo.GetActiveQuests"]    = {}
    gossipAvailableStream = functions["C_GossipInfo.GetAvailableQuests"]
    gossipActiveStream    = functions["C_GossipInfo.GetActiveQuests"]

    -- Initial sample at t=0
    SampleAll(0, 0)
  end,

  ---@param capture CaptureState
  ---@param event string
  ---@param ... any
  OnEvent = function(capture, event, ...)
    ---@type number
    local t  = GetTime() - capture.startedAt
    ---@type number
    local tp = GetTimePreciseSec() - capture.startedAtPrecise

    if event == "NAME_PLATE_UNIT_ADDED" then
      SampleNameplate(t, tp, ...)
      return
    end

    SampleAll(t, tp)

    -- Gossip functions only return valid data when the gossip window is open.
    -- Store only successful observed API returns.
    if event == "GOSSIP_SHOW" and gossipAvailableStream and gossipActiveStream then
      local availableOk, available = SafeScalarCall(C_GossipInfo and C_GossipInfo.GetAvailableQuests)
      if availableOk then
        ---@type FunctionStreamEntry?
        local prev = gossipAvailableStream[#gossipAvailableStream]
        if not prev or not DeepCompare(prev.v, available) then
          gossipAvailableStream[#gossipAvailableStream + 1] = { t = t, tp = tp, v = available }
        end
      end

      local activeOk, active = SafeScalarCall(C_GossipInfo and C_GossipInfo.GetActiveQuests)
      if activeOk then
        ---@type FunctionStreamEntry?
        local prev = gossipActiveStream[#gossipActiveStream]
        if not prev or not DeepCompare(prev.v, active) then
          gossipActiveStream[#gossipActiveStream + 1] = { t = t, tp = tp, v = active }
        end
      end
    end
  end,
})
