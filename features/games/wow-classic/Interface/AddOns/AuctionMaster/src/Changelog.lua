local addonName, AM = ...

-- The changelog (shown by the changelog tab of the main window) and the one-time "new update"
-- message in the chat. The text is changelog.src.md, turned into src/core/ChangelogData.lua by tools/changelog.js.
local Changelog = {}
AM.Changelog = Changelog

local WHITE = "Interface\\Buttons\\WHITE8X8"
local LINK = "addon:" .. addonName .. ":changelog"
local DISCORD_LINK = "addon:" .. addonName .. ":discord"
local CODE_COLOR = "|cff9ad1ff"

-- Splits the markdown into blocks: "heading" (## ...), "bullet" (- ..., continuation lines
-- indented) and "paragraph". The "# " title is skipped, the tab has its own.
local function Parse(markdown)
  local blocks = {}
  for line in (markdown .. "\n"):gmatch("(.-)\n") do
    local heading = line:match("^##%s+(.-)%s*$")
    local bullet = line:match("^%s*[-*]%s+(.-)%s*$")
    local last = blocks[#blocks]
    if line:match("^#%s") then
      -- Document title.
    elseif heading then
      blocks[#blocks + 1] = { kind = "heading", text = heading }
    elseif bullet then
      blocks[#blocks + 1] = { kind = "bullet", text = bullet }
    elseif line:match("^%s+%S") and last and last.kind == "bullet" then
      last.text = last.text .. " " .. strtrim(line)
    elseif line:match("%S") then
      blocks[#blocks + 1] = { kind = "paragraph", text = strtrim(line) }
    end
  end
  return blocks
end

local blocks

function Changelog.GetBlocks()
  blocks = blocks or Parse(AM.ChangelogMarkdown or "")
  return blocks
end

-- Escapes the text for a font string and colors `code`.
function Changelog.Inline(text)
  text = text:gsub("|", "||")
  return (text:gsub("`([^`]+)`", CODE_COLOR .. "%1|r"))
end

-- The chat line of the given version: its announce line in the client's language (enUS as
-- fallback), else the first sentence of its first entry, without markup. Nil if there is none.
local function Summary(version)
  local announce = (AM.ChangelogAnnounce or {})[version]
  local text = announce and (announce[AM.Locale.GetOverride() or GetLocale()] or announce.enUS)
  if text then
    return (text:gsub("`", ""):gsub("|", "||"))
  end
  local inVersion = false
  for _, block in ipairs(Changelog.GetBlocks()) do
    if block.kind == "heading" then
      inVersion = block.text == version
    elseif inVersion and block.kind == "bullet" then
      local text = block.text:gsub("`", "")
      text = text:match("^(.-)%.%s") or text:gsub("%.$", "")
      return (text:gsub("|", "||"))
    end
  end
end

function Changelog.Show()
  AM.ChangelogWindow.Show()
end

function Changelog.Toggle()
  AM.ChangelogWindow.Toggle()
end

-- Tells once per version in the chat what is new, with a link that opens the changelog. A
-- development copy (version not filled in by the packager) never announces.
local function Announce(preview)
  local version = AM.version
  if preview then
    -- Developer preview: uses the newest section, "Unreleased" included, so an announce line can
    -- be tried before the release. Saves nothing, so it can be repeated.
    for _, block in ipairs(Changelog.GetBlocks()) do
      if block.kind == "heading" then
        version = block.text
        break
      end
    end
  elseif not version or version:find("@", 1, true) then
    return
  else
    local state = AM.Database.GetGlobalObject("changelog")
    if state.announced == version then
      return
    end
    state.announced = version
  end
  -- "<!-- announce: none -->" marks a minor update that gets no chat message
  if (AM.ChangelogAnnounce or {})[version] and AM.ChangelogAnnounce[version].silent then
    return
  end
  local L = AM.L
  local summary = Summary(version)
  local link = "|cff33ff99|H" .. LINK .. "|h[" .. L["CHANGELOG_MORE"] .. "]|h|r"
  AM.Print(L["CHANGELOG_ANNOUNCE"]:format("|cffffd100" .. version .. "|r") .. (summary and (" \226\128\147 " .. summary) or "") .. " " .. link)
  -- a message of its own, so it does not run into the wrapped announce line
  AM.Print(L["DISCORD_TEASER"]:format("|cff33ff99|H" .. DISCORD_LINK .. "|h[" .. L["DISCORD_LINK"] .. "]|h|r"))
end

-- Hidden developer command "/am announce": prints the message for the newest section.
function Changelog.Preview()
  Announce(true)
end

-- Clicking a link of type "addon" ends up in SetItemRef.
hooksecurefunc("SetItemRef", function(link)
  if link == LINK then
    Changelog.Show()
  elseif link == DISCORD_LINK then
    AM.DiscordPopup.Show()
  end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  -- Later than the login messages of other addons, which would push it out of sight.
  C_Timer.After(3, function()
    Announce()
  end)
end)
