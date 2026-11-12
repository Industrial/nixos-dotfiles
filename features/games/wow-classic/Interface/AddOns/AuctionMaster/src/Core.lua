local addonName, AM = ...

AM.name = addonName
AM.version = C_AddOns.GetAddOnMetadata(addonName, "Version")

local Print = AM.Print

AM.Locale.Apply(GetLocale())

-- The global objects that hold only the state of AuctionMaster's windows (positions, sizes, views, filters),
-- nothing gathered or entered by the user. New window state goes into one of them.
local WINDOW_OBJECTS = { "mainWindow", "shoppingPanel", "changelogWindow" }

AM.Locale.OnReady(function()
  StaticPopupDialogs["AUCTIONMASTER_SOFT_RESET"] = {
    text = AM.L["SOFT_RESET_CONFIRM"],
    button1 = YES,
    button2 = NO,
    OnAccept = function()
      for _, name in ipairs(WINDOW_OBJECTS) do
        AM.Database.ResetGlobalObject(name)
      end
      ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }
end)

-- Reports what this client offers so we know which auction house API to target.
local function PrintInfo()
  local version, build = GetBuildInfo()
  Print("client", version, "build", build, "project id", tostring(WOW_PROJECT_ID))
  Print("C_AuctionHouse.ReplicateItems:",
    tostring(C_AuctionHouse ~= nil and C_AuctionHouse.ReplicateItems ~= nil))
  Print("AuctionHouseFrame:", tostring(AuctionHouseFrame ~= nil))
  Print("Theme titleBar:", AM.Theme and table.concat(AM.Theme.titleBar, ", ") or "nil")
  Print("ShoppingList mode:", tostring(AM.ShoppingList and AM.ShoppingList.mode))
end

-- Hidden developer command: "/am log on|off|clear", or alone for the state of the debug log (see core/DebugLog.lua).
local function HandleLog(arg)
  local DebugLog = AM.DebugLog
  if arg == "on" or arg == "off" then
    DebugLog.SetEnabled(arg == "on")
  elseif arg == "clear" then
    DebugLog.Clear()
  end
  local sessions, lines = DebugLog.GetStatus()
  Print("Debug log", DebugLog.IsEnabled() and "on" or "off", "-", sessions, "sessions stored,", lines,
    "lines in this one. Usage: /am log on|off|clear")
end

-- Hidden developer command to test the translations: "/am locale deDE" shows the texts of
-- that language after /reload, "/am locale" goes back to the client's language.
local LOCALES = { "enUS", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }

local function SetLanguage(input)
  local Locale = AM.Locale
  if input == "" then
    Locale.SetOverride(nil)
    Print("Language override removed, /reload to apply")
    return
  end
  -- The command line is lower case, locale codes are not (deDE).
  local code
  for _, known in ipairs(LOCALES) do
    if known:lower() == input then
      code = known
    end
  end
  if not code then
    Print("Unknown language", input, "- use one of " .. table.concat(LOCALES, ", ") .. ", or /am locale alone to reset")
    return
  end
  if code == GetLocale() then
    Locale.SetOverride(nil)
    Print("That is the client's language, override removed, /reload to apply")
    return
  end
  Locale.SetOverride(code)
  Print("Language set to", code, "- /reload to apply")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
  if name ~= addonName then
    return
  end
  self:UnregisterEvent("ADDON_LOADED")
  AM.Database.Init()
  AM.DebugLog.Init()
  AM.Locale.Ready()
  local override = AM.Locale.GetOverride()
  if override then
    Print("Language override active:", override, "- type /am locale without a language to remove it")
  end
  AM.ItemStore.PruneStaleMarketPrices()
end)

SLASH_AUCTIONMASTER1 = "/am"
SLASH_AUCTIONMASTER2 = "/auctionmaster"
SlashCmdList["AUCTIONMASTER"] = function(msg)
  local cmd = strlower(strtrim(msg or ""))
  if cmd == "" then
    AM.MainWindow.Toggle()
  elseif cmd == "info" then
    PrintInfo()
  elseif cmd == "locale" or cmd:match("^locale%s") then
    SetLanguage(strtrim(cmd:sub(7)))
  elseif cmd == "log" or cmd:match("^log%s") then
    HandleLog(strtrim(cmd:sub(4)))
  elseif cmd == "softreset" then
    -- Hidden developer command: resets the state of the windows only, after asking.
    StaticPopup_Show("AUCTIONMASTER_SOFT_RESET")
  elseif cmd == "recipes" then
    AM.MainWindow.Toggle("recipes")
  elseif cmd == "announce" then
    -- Hidden developer command: shows the "new update" chat message of the newest changelog section.
    AM.Changelog.Preview()
  elseif cmd == "options" or cmd == "config" then
    AM.Options.Open()
  elseif cmd == "changelog" then
    AM.Changelog.Toggle()
  else
    Print(AM.L["HELP_COMMANDS"])
  end
end
