-- busted helper: runs idAutomation's Upkeep tests against idUpkeep's copy.
-- * Module paths the tests require resolve to idUpkeep's files.
-- * idUpkeep_<X> falls back to idAddon_<X>: the shared bootstrap defines the core
--   framework (Logger, Frame, Node...) under idAutomation's names; idUpkeep's
--   copies of those files are the same code renamed.
local here = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
local addon = here .. "../"
_G.IDUPKEEP_ADDONS = addon .. "../"   -- the AddOns folder: tests load idLib* from there
local map ={ ["src.modules.automation.Upkeep"] = addon .. "Upkeep.lua" }
for f in io.popen('ls "' .. addon .. 'upkeep"/*.lua "' .. addon .. 'upkeep/classes"/*.lua'):lines() do
  local rel = f:sub(#addon + 1):gsub("%.lua$", ""):gsub("/", ".")
  map["src.modules.automation." .. rel] = f
end
for mod, path in pairs(map) do
  package.preload[mod] = function() return dofile(path) end
end
setmetatable(_G, { __index = function(t, k)
  if type(k) == "string" and k:sub(1, 9) == "idUpkeep_" then return rawget(t, "idAddon_" .. k:sub(10)) end
end })
