---@type QuestieTraceCore
local Core = QuestieTraceCore
---@type fun(...): PackedArgs
local PackArgs = Core.PackArgs
---@type fun(t1: any, t2: any, ignore_mt: boolean?, visited: table?): boolean
local DeepCompare = Core.DeepCompare

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- GetSpellBookItemName(slot, "spell") -> string spellName,
--                                        string spellSubName,
--                                        number spellID
--
-- GetSpellBookItemInfo(slot, "spell") -> string spellType,
--                                        number id
--
-- IsPassiveSpell(slot, "spell") -> 1|nil isPassive
--
-- SpellBook (custom stream) -> number[] spellIDs  -- ordered known spell IDs
--
-- PlayerKnownSpells (delta stream) -> set<number> spellIDs
---------------------------------------------------------------------------

---@type string
local BOOK_TYPE = "spell"

---@type table<string, FunctionStreamEntry[]|table<string|number, FunctionStreamEntry[]>>
local functions
---@type table<string, DeltaStream>
local functionsDelta
---@type table<number, PackedArgs?>
local prevName
---@type table<number, PackedArgs?>
local prevInfo
---@type table<number, number?>
local prevPassive
---@type table<number, boolean>
local knownSlots
---@type table<number, boolean>
local currentKnownSpells

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

--- Append a parameterized packed value only when it changed.
---@param funcName string
---@param key number
---@param prev table<number, PackedArgs?>
---@param t number
---@param tp number
---@param value PackedArgs?
local function AppendPackedIfChanged(funcName, key, prev, t, tp, value)
  local old = prev[key]
  ---@type boolean
  local changed

  if old == nil and value == nil then
    changed = functions[funcName][key] == nil or #functions[funcName][key] == 0
  elseif old == nil or value == nil then
    changed = true
  else
    changed = not DeepCompare(old, value)
  end

  if not changed then return end

  local stream = functions[funcName][key]
  if not stream then
    stream = {}
    functions[funcName][key] = stream
  end
  stream[#stream + 1] = { t = t, tp = tp, v = value }
  prev[key] = value
end

--- Append a parameterized scalar only when it changed.
---@param funcName string
---@param key number
---@param prev table<number, number?>
---@param t number
---@param tp number
---@param value number?
local function AppendScalarIfChanged(funcName, key, prev, t, tp, value)
  local old = prev[key]
  local stream = functions[funcName][key]
  local hasEntries = stream ~= nil and #stream > 0
  if old == value and hasEntries then return end

  if not stream then
    stream = {}
    functions[funcName][key] = stream
  end
  stream[#stream + 1] = { t = t, tp = tp, v = value }
  prev[key] = value
end

--- Append the ordered spell list when it changed.
---@param t number
---@param tp number
---@param ids number[]
local function AppendSpellBookIfChanged(t, tp, ids)
  local stream = functions["SpellBook"]
  local prev = stream[#stream]
  if not prev or not DeepCompare(prev.v, ids) then
    local copy = {}
    for i = 1, #ids do
      copy[i] = ids[i]
    end
    stream[#stream + 1] = { t = t, tp = tp, v = copy }
  end
end

--- Diff and append PlayerKnownSpells delta entries.
---@param capture CaptureState
---@param newSet table<number, boolean>
local function AppendKnownSpellDelta(capture, newSet)
  local added, removed = {}, {}
  for spellID in pairs(newSet) do
    if not currentKnownSpells[spellID] then
      added[#added + 1] = spellID
    end
  end
  for spellID in pairs(currentKnownSpells) do
    if not newSet[spellID] then
      removed[#removed + 1] = spellID
    end
  end

  if #added > 0 or #removed > 0 then
    table.sort(added)
    table.sort(removed)

    local delta = {
      t = GetTime() - capture.startedAt,
      tp = GetTimePreciseSec() - capture.startedAtPrecise,
    }
    if #added > 0 then delta.add = added end
    if #removed > 0 then delta.remove = removed end

    functionsDelta["PlayerKnownSpells"].delta[#functionsDelta["PlayerKnownSpells"].delta + 1] = delta
  end

  currentKnownSpells = newSet
end

--- Enumerate the entire player spellbook, including profession tabs.
---@param capture CaptureState
local function SampleSpellBook(capture)
  local t = GetTime() - capture.startedAt
  local tp = GetTimePreciseSec() - capture.startedAtPrecise

  local seenSlots = {}
  local orderedSpellIDs = {}
  local seenSpellIDs = {}
  local newKnownSpells = {}

  if type(GetSpellBookItemName) == "function" then
    local slot = 1
    while true do
      local nameValue = PackArgs(GetSpellBookItemName(slot, BOOK_TYPE))
      if nameValue[1] == nil then break end
      local spellID = nameValue[3]

      seenSlots[slot] = true
      knownSlots[slot] = true

      AppendPackedIfChanged("GetSpellBookItemName", slot, prevName, t, tp, nameValue)

      if type(GetSpellBookItemInfo) == "function" then
        local infoValue = PackArgs(GetSpellBookItemInfo(slot, BOOK_TYPE))
        AppendPackedIfChanged("GetSpellBookItemInfo", slot, prevInfo, t, tp, infoValue)
      end

      if type(IsPassiveSpell) == "function" then
        local passiveValue = IsPassiveSpell(slot, BOOK_TYPE)
        AppendScalarIfChanged("IsPassiveSpell", slot, prevPassive, t, tp, passiveValue)
      end

      if type(spellID) == "number" then
        newKnownSpells[spellID] = true
        if not seenSpellIDs[spellID] then
          seenSpellIDs[spellID] = true
          orderedSpellIDs[#orderedSpellIDs + 1] = spellID
        end
      end

      slot = slot + 1
    end
  end

  for slot in pairs(knownSlots) do
    if not seenSlots[slot] then
      local nameOk, nameValue = SafePackedCall(GetSpellBookItemName, slot, BOOK_TYPE)
      if nameOk and nameValue then
        AppendPackedIfChanged("GetSpellBookItemName", slot, prevName, t, tp, nameValue)
      end

      local infoOk, infoValue = SafePackedCall(GetSpellBookItemInfo, slot, BOOK_TYPE)
      if infoOk and infoValue then
        AppendPackedIfChanged("GetSpellBookItemInfo", slot, prevInfo, t, tp, infoValue)
      end

      local passiveOk, passiveValue = SafeScalarCall(IsPassiveSpell, slot, BOOK_TYPE)
      if passiveOk then
        AppendScalarIfChanged("IsPassiveSpell", slot, prevPassive, t, tp, passiveValue)
      end
    end
  end

  AppendSpellBookIfChanged(t, tp, orderedSpellIDs)
  AppendKnownSpellDelta(capture, newKnownSpells)
end

Core.RegisterTracker({
  events = {
    "SPELLS_CHANGED",
    "PLAYER_ENTERING_WORLD",
  },

  ---@param capture CaptureState
  Init = function(capture)
    functions = capture.session.functions
    functionsDelta = capture.session.functionsDelta

    functions["SpellBook"] = {}
    functions["GetSpellBookItemName"] = {}
    functions["GetSpellBookItemInfo"] = {}
    functions["IsPassiveSpell"] = {}

    prevName = {}
    prevInfo = {}
    prevPassive = {}
    knownSlots = {}

    ---@type table<number, boolean>
    local initialKnownSpells = {}
    currentKnownSpells = initialKnownSpells
    functionsDelta["PlayerKnownSpells"] = {
      t = 0,
      tp = 0,
      initial = {},
      delta = {},
    }

    SampleSpellBook(capture)
    functionsDelta["PlayerKnownSpells"].initial = {}
    for spellID in pairs(currentKnownSpells) do
      functionsDelta["PlayerKnownSpells"].initial[#functionsDelta["PlayerKnownSpells"].initial + 1] = spellID
    end
    table.sort(functionsDelta["PlayerKnownSpells"].initial)
    functionsDelta["PlayerKnownSpells"].delta = {}
  end,

  ---@param capture CaptureState
  OnEvent = function(capture)
    SampleSpellBook(capture)
  end,
})
