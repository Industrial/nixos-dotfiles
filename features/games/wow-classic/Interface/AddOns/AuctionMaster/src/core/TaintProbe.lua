local addonName, AM = ...

-- TEMPORARY (doc/taint-issue.md): while the debug log is on, logs (category "taint") every field of the game's auction
-- house, bank, bag and profession frames the moment it is found tainted by AuctionMaster, plus the events around it,
-- so the log shows which value became tainted after which of our steps. Remove once the cause is found.

local ROOTS = { "AuctionHouseFrame", "BankFrame", "ContainerFrameContainer", "ContainerFrameSettingsManager",
  "ProfessionsFrame", "TradeSkillFrame" }
local MAX_DEPTH = 4
local MAX_NODES = 30000 -- tables visited per scan
local INTERVAL = 1

local reported = {} -- path -> true, each tainted field is logged once
local started = GetTime()

local function Since()
  return GetTime() - started
end

local function Walk(tbl, path, depth, seen, budget)
  if seen[tbl] or budget.left <= 0 then
    return
  end
  seen[tbl] = true
  budget.left = budget.left - 1
  for key, value in next, tbl do
    local name = type(key) == "string" and key or ("[" .. tostring(key) .. "]")
    local child = path .. "." .. name
    -- the game only checks string keys
    local secure, taint = true, nil
    if type(key) == "string" then
      secure, taint = issecurevariable(tbl, key)
    end
    if not secure and taint == addonName and not reported[child] then
      reported[child] = true
      AM.DebugLog.Log("taint", "%.1f %s tainted (%s)", Since(), child, type(value))
    end
    if type(value) == "table" and depth < MAX_DEPTH then
      Walk(value, child, depth + 1, seen, budget)
    end
  end
end

local function Scan()
  if not AM.DebugLog.IsEnabled() then
    return
  end
  local seen, budget = {}, { left = MAX_NODES }
  for _, root in ipairs(ROOTS) do
    local frame = _G[root]
    if type(frame) == "table" then
      Walk(frame, root, 1, seen, budget)
    end
  end
end

local EVENTS = { "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "COMMODITY_PURCHASE_SUCCEEDED",
  "COMMODITY_PURCHASE_FAILED", "AUCTION_HOUSE_PURCHASE_COMPLETED", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE",
  "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
  "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" }

local events = CreateFrame("Frame")
for _, event in ipairs(EVENTS) do
  pcall(events.RegisterEvent, events, event)
end
pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player")
events:SetScript("OnEvent", function(_, event, ...)
  if not AM.DebugLog.IsEnabled() then
    return
  end
  AM.DebugLog.Log("taint", "%.1f event %s %s", Since(), event, tostring((select(event == "UNIT_SPELLCAST_SUCCEEDED" and 3 or 1, ...))))
  Scan()
end)

C_Timer.NewTicker(INTERVAL, Scan)

-- our own steps that reach the game's auction house, as markers in the log
local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
  for _, name in ipairs({ "SearchItem", "SearchItemName", "ClickItem", "RecordCraft" }) do
    if AM.ShoppingList and AM.ShoppingList[name] then
      hooksecurefunc(AM.ShoppingList, name, function()
        if AM.DebugLog.IsEnabled() then
          AM.DebugLog.Log("taint", "%.1f our ShoppingList.%s", Since(), name)
          Scan()
        end
      end)
    end
  end
end)
