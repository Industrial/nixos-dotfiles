QuestieTraceCore = QuestieTraceCore or {}

---@class QuestieTraceCore
local Core = QuestieTraceCore

---------------------------------------------------------------------------
-- Privacy: GUID classification, text sanitization, chat message scrubbing
---------------------------------------------------------------------------
-- See the "Privacy" sections in AGENTS.md / CLAUDE.md for the rules this
-- code implements. No player names, guild names, or player GUIDs may ever
-- be persisted to a session. Classification here is manual and
-- deterministic (GUID prefix matching, known-name substitution) rather
-- than relying on client flags like `issecretvalue()`, which are not a
-- reliable privacy guard on their own.

---@type table<number, {[1]: string, [2]: "player"|"npc"|"object"|"item"}>
local GUID_KIND_PATTERNS = {
  { "^Player%-", "player" },
  { "^Creature%-", "npc" },
  { "^Pet%-", "npc" },
  { "^Vehicle%-", "npc" },
  { "^GameObject%-", "object" },
  { "^Item%-", "item" },
}

--- Classify a WoW GUID by its prefix.
---@param guid any
---@return "player"|"npc"|"object"|"item"|nil kind
function Core.ParseGUIDKind(guid)
  -- Restricted identity cannot be classified. Readable values still require the explicit prefix allowlist below.
  if (issecretvalue and issecretvalue(guid)) or type(guid) ~= "string" then return nil end
  for i = 1, #GUID_KIND_PATTERNS do
    ---@type string, "player"|"npc"|"object"|"item"
    local pattern, kind = GUID_KIND_PATTERNS[i][1], GUID_KIND_PATTERNS[i][2]
    if guid:match(pattern) then return kind end
  end
  return nil
end

--- Whether a GUID belongs to a player character. Used to discard any
--- observation (UnitGUID, GetLootSourceInfo, chat message guid args, ...)
--- before it is ever stored.
---@param guid any
---@return boolean
function Core.IsPlayerGUID(guid)
  return Core.ParseGUIDKind(guid) == "player"
end

--- Escape Lua pattern-magic characters so a literal string can be used as a gsub pattern.
---@param str string
---@return string
local function EscapePattern(str)
  return (str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"))
end

--- Pattern that matches a known name only as a whole word, so a short name such
--- as "Ann" no longer rewrites "Announce" or "Annals" in quest and objective texts.
---
--- A word is a run of the ASCII letters A-Z and a-z, an explicit byte range we own
--- (`%w` follows the C library's locale, and counts digits). A word boundary beside
--- a Cyrillic, Korean, Chinese or accented first or last letter is not possible
--- with that range, so that side of such a name still matches inside words. A
--- trailing "s" is redacted with the name: German forms the possessive without an
--- apostrophe ("Anns Schwert").
---@param name string
---@return string pattern
local function NamePattern(name)
  local pattern = EscapePattern(name)
  if name:find("^[A-Za-z]") then
    pattern = "%f[A-Za-z]" .. pattern
  end
  if name:find("[A-Za-z]$") then
    pattern = pattern .. "s?%f[^A-Za-z]"
  end
  return pattern
end

--- Replace each name in `text` with "<name>", as whole words (see NamePattern).
---
--- WoW escape sequences can end in a letter right before a name
--- ("|cff00ff00Ann|r", "|TIcon:0|tAnn"). A marker byte after each one keeps
--- that edge a word boundary while the names are matched, then is removed.
---@param text string
---@param names string[] Sorted in place, longest first, so a name is replaced before any shorter name inside it.
---@return string redacted
local function RedactNames(text, names)
  table.sort(names, function(a, b) return #a > #b end)
  local marked = text:gsub("|c%x%x%x%x%x%x%x%x", "%0\1"):gsub("|[rthna]", "%0\1")
  for i = 1, #names do
    marked = marked:gsub(NamePattern(names[i]), "<name>")
  end
  return (marked:gsub("\1", ""))
end

--- Normalize UnitName return values into a flat list of name parts.
--- Handles both patterns:
---   - UnitName("player") -> "First Last" (single return, full name)
---   - UnitName("partyX") -> "First", "Last" (two returns)
--- If Blizzard ever makes UnitName("player") return two values like party units,
--- this captures both. Also splits the first return by spaces as a fallback.
---@param token string
---@return string[] parts
local function GetUnitNameParts(token)
  if type(UnitName) ~= "function" then return {} end
  local first, second = UnitName(token)
  local parts = {}
  if type(first) == "string" and first ~= "" then
    parts[#parts + 1] = first
    for part in first:gmatch("%S+") do
      parts[#parts + 1] = part
    end
  end
  if type(second) == "string" and second ~= "" then
    parts[#parts + 1] = second
  end
  return parts
end

--- Collect the set of player and guild names currently known to the client:
--- the local player, the player's guild and, if grouped, the player's
--- raid/party members. Built fresh on every call and never persisted -- it
--- exists purely as an in-memory sanitization dictionary for Core.SanitizeText.
---@return table<string, boolean>
function Core.GetPrivacyNameSet()
  ---@type table<string, boolean>
  local names = {}

  ---@param name any
  local function AddName(name)
    if type(name) == "string" and name ~= "" then
      names[name] = true
    end
  end

  -- Local player
  for _, part in ipairs(GetUnitNameParts("player")) do
    AddName(part)
  end

  -- Guild: clients with guild reputation name it in faction texts, such as
  -- "Reputation with <guild> increased" chat messages.
  if type(GetGuildInfo) == "function" then
    local ok, guildName = pcall(GetGuildInfo, "player")
    if ok and not (issecretvalue and issecretvalue(guildName)) then
      AddName(guildName)
    end
  end

  -- Party/raid members
  if type(IsInRaid) == "function" and IsInRaid() then
    for i = 1, 40 do
      for _, part in ipairs(GetUnitNameParts("raid" .. i)) do
        AddName(part)
      end
    end
  elseif type(IsInGroup) == "function" and IsInGroup() then
    for i = 1, 4 do
      for _, part in ipairs(GetUnitNameParts("party" .. i)) do
        AddName(part)
      end
    end
  end

  return names
end

--- Redact every known player and guild name, as whole words (see RedactNames),
--- from a free-text WoW API return value.
--- Used for quest/gossip text and chat message text before storage.
---@param text any
---@return any sanitized Unchanged unless it is a non-empty string.
function Core.SanitizeText(text)
  if type(text) ~= "string" or text == "" then return text end

  local names = {}
  for name in pairs(Core.GetPrivacyNameSet()) do
    names[#names + 1] = name
  end
  return RedactNames(text, names)
end

---@type table<number, boolean>
local CHAT_MSG_NAME_ARG_INDICES = { [2] = true, [5] = true }
---@type number
local CHAT_MSG_GUID_ARG_INDEX = 12

--- Scrub the argument shape shared by every `CHAT_MSG_*` event QuestieTrace
--- records: `text, playerName, languageName, channelName, playerName2,
--- specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID,
--- lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox,
--- supressRaidIcons`.
---
--- The literal `playerName`/`playerName2` values are used to redact that
--- name from `text`, as a whole word (see RedactNames; this catches names even when the
--- subject isn't grouped with the local player, e.g. a duel/trade request),
--- then `Core.SanitizeText` is applied as a second pass for the local
--- player/roster. The name args and any player GUID are then discarded.
--- The input is never mutated; a new PackedArgs is returned.
---@param args PackedArgs
---@return PackedArgs sanitized
function Core.SanitizeChatMsgArgs(args)
  local out = Core.CopyPacked(args)

  local text = out[1]
  if issecretvalue and issecretvalue(text) then
    text = nil
  end

  if type(text) == "string" and text ~= "" then
    local senderNames = {}
    for index in pairs(CHAT_MSG_NAME_ARG_INDICES) do
      local name = out[index]
      if (not (issecretvalue and issecretvalue(name))) and type(name) == "string" and name ~= "" then
        senderNames[#senderNames + 1] = name
      end
    end
    text = Core.SanitizeText(RedactNames(text, senderNames))
  end
  out[1] = text

  for index in pairs(CHAT_MSG_NAME_ARG_INDICES) do
    out[index] = nil
  end

  local guidKind = Core.ParseGUIDKind(out[CHAT_MSG_GUID_ARG_INDEX])
  if guidKind ~= "npc" and guidKind ~= "object" and guidKind ~= "item" then
    out[CHAT_MSG_GUID_ARG_INDEX] = nil
  end

  return out
end

---------------------------------------------------------------------------
-- CHAT_MSG_SYSTEM allowlist
---------------------------------------------------------------------------
-- CHAT_MSG_SYSTEM carries many unrelated message kinds, several of which
-- embed player or guild names with no structural way to separate the name
-- from the rest of the sentence (e.g. guild join/leave/invite/promote,
-- online/offline notices). Rather than trying to detect and scrub every
-- possible name-leaking shape (a losing game of whack-a-mole), this only
-- allows CHAT_MSG_SYSTEM messages that match a reviewed allowlist of
-- Blizzard's own global format strings -- see
-- Documentation/GlobalStrings.1.60.1.69913.csv -- that are useful for
-- quest tracing and never contain player/guild names. Anything else must
-- be treated as unsafe and discarded by the caller.

---@type string[] `BaseTag` names (Documentation/GlobalStrings.1.60.1.69913.csv)
--- of allowlisted global format strings. Read from the client's own
--- (locale-correct) globals at runtime, so this works regardless of game
--- locale without hardcoding any language's wording here.
local ALLOWED_SYSTEM_MESSAGE_TAGS = {
  "ERR_QUEST_ACCEPTED_S",           -- "Quest accepted: %s"
  "ERR_QUEST_COMPLETE_S",           -- "%s completed."
  "ERR_QUEST_FAILED_S",             -- "%s failed."
  "ERR_QUEST_FAILED_BAG_FULL_S",    -- "%s failed: Inventory is full."
  "ERR_QUEST_FAILED_WRONG_RACE",    -- "That quest is not available to your race."
  "ERR_QUEST_REWARD_EXP_I",         -- "Experience gained: %d."
  "ERR_QUEST_REWARD_MONEY_S",       -- "Received %s."
  "ERR_QUEST_LOG_FULL",             -- "Your quest log is full."
  "ERR_QUEST_FORCE_REMOVED_S",      -- "The quest %s has been removed from your quest log."
  "ERR_QUEST_ALREADY_DONE",         -- "You have completed that quest."
  "ERR_QUEST_ALREADY_DONE_DAILY",   -- "You have completed that daily quest today."
  "ERR_QUEST_ALREADY_ON",           -- "You are already on that quest."
  "ERR_ZONE_EXPLORED_XP",           -- "Discovered %s: %d experience gained"
  "ERR_SKILL_GAINED_S",             -- "You have gained the %s skill."
  "ERR_SKILL_UP_SI",                -- "Your skill in %s has increased to %d."
  "ERR_LEARN_ABILITY_S",            -- "You have learned a new ability: %s."
  "ERR_LEARN_SPELL_S",              -- "You have learned a new spell: %s."
  "ERR_LEARN_RECIPE_S",             -- "You have learned how to create a new item: %s."
  "LEVEL_REQUIRED",                 -- "Req level %d"
}

--- Convert a Blizzard global format string (with `%s`/`%d`/positional
--- `%1$s` placeholders) into an anchored Lua pattern that matches any
--- value in place of each placeholder.
---@param template string
---@return string pattern
local function GlobalStringToPattern(template)
  -- Placeholders never contain pattern-magic characters worth preserving,
  -- so swap them for a sentinel byte before escaping the literal parts,
  -- then turn the sentinel into a wildcard capture-free match. Uses "\1"
  -- rather than "\0" as the sentinel: Lua 5.1's pattern matching does not
  -- reliably match a literal embedded NUL byte (that requires "%z").
  local withSentinel = template:gsub("%%%d%$[sd]", "\1"):gsub("%%[sd]", "\1")
  local escaped = EscapePattern(withSentinel)
  return "^" .. escaped:gsub("\1", ".-") .. "$"
end

---@type string[]? Lazily built from ALLOWED_SYSTEM_MESSAGE_TAGS on first use.
local allowedSystemMessagePatterns

--- Whether a `CHAT_MSG_SYSTEM` message body matches one of the allowlisted,
--- name-free Blizzard system message templates (quest accept/complete/fail,
--- reward XP/money, skill/spell/recipe learned, faction requirement).
--- Anything that does not match must be discarded rather than recorded,
--- since CHAT_MSG_SYSTEM has no reliable structural way to separate player
--- or guild names from the rest of the sentence.
---@param text any
---@return boolean
function Core.IsAllowedSystemMessage(text)
  if issecretvalue and issecretvalue(text) then return false end
  if type(text) ~= "string" or text == "" then return false end

  if not allowedSystemMessagePatterns then
    allowedSystemMessagePatterns = {}
    for i = 1, #ALLOWED_SYSTEM_MESSAGE_TAGS do
      local template = _G[ALLOWED_SYSTEM_MESSAGE_TAGS[i]]
      if type(template) == "string" and template ~= "" then
        allowedSystemMessagePatterns[#allowedSystemMessagePatterns + 1] = GlobalStringToPattern(template)
      end
    end
  end

  for i = 1, #allowedSystemMessagePatterns do
    if text:match(allowedSystemMessagePatterns[i]) then
      return true
    end
  end
  return false
end
