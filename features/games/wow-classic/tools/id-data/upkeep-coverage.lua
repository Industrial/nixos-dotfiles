-- Every class buff the generated data knows must be one idUpkeep keeps up, or
-- be named here with the reason it is not. Run by bin/generate-id-data after
-- emitting, so a new build's new buff (or a buff a class table forgot, as
-- Righteous Fury once was) fails the run instead of silently never being cast.
--
--   lua upkeep-coverage.lua <csv dir> <AddOns dir>
--
-- Coverage is by spell NAME: class rules name one rank, the data lists every
-- rank, and the client casts the highest rank of a name.
local csvDir, addons = arg[1], arg[2]
if not (csvDir and addons) then
  io.stderr:write("usage: lua upkeep-coverage.lua <csv dir> <AddOns dir>\n")
  os.exit(2)
end

-- Buffs idUpkeep deliberately leaves to the player, by class and name.
local SKIP = {
  DRUID = {
    ["Moonkin Aura"] = "comes with Moonkin Form; the form is the choice",
  },
  MAGE = {
    ["Amplify Magic"] = "situational: raises magic damage taken as well as healing",
    ["Dampen Magic"] = "situational: lowers healing received as well as magic damage",
    ["Combustion"] = "a cooldown, not upkeep",
    ["Ice Barrier"] = "a cooldown shield for combat",
    ["Mana Shield"] = "spends mana to absorb; a combat choice",
  },
  PALADIN = {
    ["Divine Favor"] = "a cooldown, not upkeep",
    ["Inspiration Exemplar"] = "a rune's proc, not something to cast",
    ["Oath of Light"] = "only dummy auras in the client data; add once its effect is known",
    ["Sacred Shield"] = "a short absorb placed in combat",
  },
  PRIEST = {
    ["Levitate"] = "utility",
  },
  SHAMAN = {
    ["Earth Shield"] = "placed on the tank; a healer's choice",
    ["Spirit of the Alpha"] = "placed on another player; a choice",
    ["Sentry Totem"] = "utility totem",
    ["Water Breathing"] = "utility",
    ["Water Walking"] = "utility",
  },
  WARLOCK = {
    ["Detect Invisibility"] = "utility",
    ["Unending Breath"] = "utility",
  },
}

local function chunk(path)
  local f, err = loadfile(path)
  if not f then
    io.stderr:write(err .. "\n")
    os.exit(2)
  end
  return f("upkeep-coverage", {})
end

-- The emitted spell data, through the same LibStub path the client uses.
chunk(addons .. "/idLibSetTable/LibStub.lua")
for _, f in ipairs({ "idLibSetTable/idLibSetTable.lua", "idLibSpellTable/idLibSpellTable.lua",
  "idLibSpellTable/data/manifest.lua", "idLibSpellTable/data/Spell.lua" }) do
  chunk(addons .. "/" .. f)
end
local lib = LibStub("idLibSpellTable-1.0")

local names = {}
for line in io.lines(csvDir .. "/Spell.csv") do
  local id, name = line:match("^(%d+),(.*)$")
  if id then
    names[tonumber(id)] = (name:gsub('^"(.*)"$', "%1"):gsub('""', '"'))
  end
end

chunk(addons .. "/idUpkeep/upkeep/Rules.lua")
local R = _G.idUpkeep_UpkeepRules
local CLASSES = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }

local gaps, stale = {}, {}
for _, cls in ipairs(CLASSES) do
  chunk(addons .. "/idUpkeep/upkeep/classes/" .. cls .. ".lua")
  local covered = {}
  for _, rule in ipairs((R.forClass(cls) or {}).rules or {}) do
    for _, key in ipairs({ "spells", "satisfiedBy", "summon" }) do
      for _, id in ipairs(rule[key] or {}) do
        if names[id] then covered[names[id]] = true end
      end
    end
  end
  local inData = {}
  for _, set in ipairs(lib:Sets()) do
    local c = set:match("^Spell%.Spec%.(%u+)%.[^.]+%.Buff%.%a+$")
    if c == cls then
      for id in lib:IterateSet(set) do
        local n = names[id]
        if n then
          inData[n] = true
          if not covered[n] and not (SKIP[cls] or {})[n] then
            gaps[#gaps + 1] = ("%s: %s (spell %d, %s)"):format(cls, n, id, set)
          end
        end
      end
    end
  end
  for n in pairs(SKIP[cls] or {}) do
    if not inData[n] then stale[#stale + 1] = cls .. ": " .. n end
  end
end

local function unique(list)
  table.sort(list)
  local out, last = {}, nil
  for _, s in ipairs(list) do
    local key = s:match("^[^(]+")
    if key ~= last then out[#out + 1] = s end
    last = key
  end
  return out
end
gaps, stale = unique(gaps), unique(stale)

for _, s in ipairs(stale) do
  print("note: skip entry no longer in the data: " .. s)
end
if #gaps > 0 then
  print(("upkeep coverage FAILED: %d class buff(s) no idUpkeep rule keeps up and SKIP does not name:"):format(#gaps))
  for _, s in ipairs(gaps) do print("  " .. s) end
  print("Add each to its idUpkeep/upkeep/classes/<CLASS>.lua rule, or to SKIP in tools/id-data/upkeep-coverage.lua with the reason.")
  os.exit(1)
end
print("upkeep coverage PASSED: every class buff is kept up or skipped for a stated reason")
