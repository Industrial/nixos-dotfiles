local addonName, AM = ...

-- Texts are looked up by a fixed key, e.g. L["TOOLTIP_NO_AUCTIONS"], so wording and
-- punctuation can change without touching the other languages. enUS.lua holds every text
-- and is always used as the base, the file of the active language (e.g. deDE.lua) overrides
-- what it translates. Texts a language does not translate stay English.
-- An unknown key is returned as is, which makes a typo easy to spot in game.
--
-- Every locale file fills its own table (Locale.Texts("deDE")); Locale.Apply copies the
-- active language into AM.L. That is the client's language, unless a developer override
-- is set with "/am locale" (see Locale.SetOverride).
local Locale = {}
AM.Locale = Locale

AM.L = setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local BASE = "enUS"
local texts = {}

-- Returns the table the locale file of the given language fills with its texts.
function Locale.Texts(code)
  texts[code] = texts[code] or {}
  return texts[code]
end

-- Makes AM.L hold the English base plus the texts of the given language.
function Locale.Apply(code)
  local L = AM.L
  wipe(L)
  for key, text in pairs(texts[BASE] or {}) do
    L[key] = text
  end
  for key, text in pairs(texts[code] or {}) do
    L[key] = text
  end
end

-- Developer override, saved in the global object "debug". Not offered in the options.
local function GetSettings()
  return AM.Database.GetGlobalObject("debug")
end

function Locale.GetOverride()
  return GetSettings().locale
end

-- nil resets to the client's language. Takes effect after /reload.
function Locale.SetOverride(code)
  GetSettings().locale = code
end

local callbacks = {}

-- Runs callback once the language is known (right after the saved variables are loaded). Texts
-- shown by frames or dialogs created while the files load would still be in the client's
-- language, so such code creates or fills them here. Texts read when something is shown are fine.
function Locale.OnReady(callback)
  callbacks[#callbacks + 1] = callback
end

-- Applies the override and runs the OnReady callbacks. Called once the saved variables are
-- loaded; until then the client's language is active.
function Locale.Ready()
  local code = Locale.GetOverride()
  if code then
    Locale.Apply(code)
  end
  for _, callback in ipairs(callbacks) do
    callback()
  end
end
