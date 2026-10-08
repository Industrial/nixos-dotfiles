local function GetRegionalRulesetName()
  if C_GameRules.IsGameRuleActive(Enum.GameRule.PvPRuleset) then
    return "PvP"
  elseif C_GameRules.IsGameRuleActive(Enum.GameRule.RPRuleset) then
    return "RP"
  elseif C_GameRules.IsGameRuleActive(Enum.GameRule.HardcoreRuleset) then
    return "HC"
  else
    return "PvE"
  end
end
function Auctionator.Variables.GetConnectedRealmRoot()
  -- Special case for regionally unique names, AHs are grouped by ruleset
  if RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
    return GetRegionalRulesetName()
  end

  -- All "realms" that are connected together use the same AH database, this
  -- determines which database is in use.

  -- We use GetRealmName() because GetNormalizedRealmName() isn't available on
  -- first load.
  local currentRealm = GetNormalizedRealmName()
  local connections = GetAutoCompleteRealms()

  -- We sort so that we always get the same first realm to use for the database
  table.sort(connections)

  if connections[1] ~= nil then
    -- Case where we are on a connected realm
    return connections[1]
  else
    -- We are not on a connected realm
    return currentRealm
  end
end
