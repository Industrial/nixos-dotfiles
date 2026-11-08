---@class QuestieTraceCore
local Core = QuestieTraceCore

---@class l10n
---@field translations table<string, table<string, string|boolean>>
Core.l10n = Core.l10n or {}
local l10n = Core.l10n
local _l10n = {}
l10n.translations = {}

---@type string
local locale = "enUS"
---@type table<string, boolean>
local supportedLocales = {
  ["enUS"] = true,
  ["deDE"] = true,
  ["esES"] = true,
  ["esMX"] = true,
  ["frFR"] = true,
  ["koKR"] = true,
  ["ptBR"] = true,
  ["ruRU"] = true,
  ["zhCN"] = true,
  ["zhTW"] = true,
}

local format, unpack, tostring = string.format, unpack, tostring

--- Translate `key` into the current UI locale, formatting it with `...`.
--- Falls back to the enUS key itself (used as a format string) if no
--- translation exists for the current locale.
---@param key string
---@vararg any
---@return string
function _l10n.translate(key, ...)
  local args = { ... }
  for i, v in ipairs(args) do
    args[i] = tostring(v)
  end

  local translationEntry = l10n.translations[key]
  if (not translationEntry) then
    return format(key, unpack(args))
  end

  local translationValue = translationEntry[locale]
  if (not translationValue) then
    return format(key, unpack(args))
  end

  if translationValue == true then
    -- Fallback to enUS which is the key
    return format(key, unpack(args))
  end

  return format(translationValue, unpack(args))
end

setmetatable(l10n, { __call = function(_, ...) return _l10n.translate(...) end })

--- Return `lang` if it is a supported locale, otherwise "enUS".
---@param lang string?
---@return string locale
function l10n.GetFallbackLocale(lang)
  if (not lang) then
    return "enUS"
  end

  if supportedLocales[lang] then
    return lang
  end

  return "enUS"
end

---@param lang string?
---@return nil
function l10n.SetUILocale(lang)
  locale = l10n.GetFallbackLocale(lang or GetLocale())
end

---@return string locale
function l10n.GetUILocale()
  return locale
end

l10n.SetUILocale(GetLocale())
