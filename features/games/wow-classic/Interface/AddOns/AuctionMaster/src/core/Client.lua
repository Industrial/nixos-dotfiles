local addonName, AM = ...

-- Which game client the addon runs on, by the interface number. Prefer checking for a capability where that can tell the
-- difference on its own; this is for what nothing short of the client can decide.
AM.Client = {}
local Client = AM.Client

local interface = select(4, GetBuildInfo())
local isForever = interface >= 16000 and interface < 17000
local isRetail = interface >= 100000
-- Classic is the current Classic progression client, whatever expansion that is: when the next one comes, the interface
-- number changes but this stays true.
local isClassic = not isRetail and not isForever

-- The quality of green items: the Classic clients call it Good, there is no Enum.ItemQuality.Uncommon.
Client.UNCOMMON = Enum.ItemQuality.Uncommon or Enum.ItemQuality.Good

function Client.IsForever()
  return isForever
end

function Client.IsClassic()
  return isClassic
end

function Client.IsRetail()
  return isRetail
end

-- The flavor and version of the client as text, like "forever, client 1.60.1 (build 12345)".
function Client.GetName()
  local version, build = GetBuildInfo()
  local flavor = isRetail and "retail" or isForever and "forever" or isClassic and "classic" or "unknown flavor"
  return ("%s, client %s (build %s)"):format(flavor, version, build)
end
