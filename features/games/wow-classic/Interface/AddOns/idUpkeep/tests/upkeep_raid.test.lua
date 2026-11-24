-- Raid buffing: the player first, then the party, then the rest of the raid by
-- subgroup; players only; dead/offline/out-of-range members skipped; Thorns on
-- tanks.
local PATHS = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.classes.DRUID",
  "src.modules.automation.upkeep.classes.PRIEST",
  "src.modules.automation.upkeep.Engine",
  "src.modules.automation.upkeep.Snapshot"
}
local load = function()
  for _, p in ipairs(PATHS) do
    package.loaded[p] = nil
    require(p)
  end
  return _G.idUpkeep_UpkeepRules, _G.idUpkeep_UpkeepEngine, _G.idUpkeep_UpkeepSnapshot
end
local known = function(name)
  return { name = name, known = true, usable = true, noMana = false, icon = "icon:" .. name }
end
local member = function(class, extra)
  local ud = { exists = true, class = class, usesMana = class ~= "WARRIOR" and class ~= "ROGUE", auras = { } }
  for k, v in pairs(extra or { }) do ud[k] = v end
  return ud
end
local druidSnap = function()
  return {
    class = "DRUID", level = 60, now = 1000, inInstance = false,
    player = { healthPct = 100, manaPct = 100, usesMana = true },
    spells = {
      [1126] = known("Mark of the Wild"),
      [21849] = { name = "Gift of the Wild", known = false },
      [467] = known("Thorns"),
      [16864] = { name = "Omen of Clarity", known = false }
    },
    items = { }, itemInfo = { },
    units = { player = member("DRUID", { auras = { { name = "Mark of the Wild" }, { name = "Thorns" } } }) },
    pet = { exists = false },
    weapon = { mh = { isWeapon = false }, oh = { isWeapon = false } },
    consumables = { }, foodBuffs = { }, food = { }, water = { }, weaponItems = { },
    wellFed = { ids = { }, names = { } }
  }
end
local doSteps = function(Engine, snap, rules)
  local out = { }
  for _, e in ipairs(Engine.explain(snap, rules)) do
    if e.status == "do" then
      out[#out + 1] = tostring(e.step.spell) .. "@" .. tostring(e.step.unit)
    end
  end
  return out
end

describe("Upkeep raid buffing", function()
  local Rules, Engine, Snapshot
  before_each(function()
    Rules, Engine, Snapshot = load()
  end)

  describe("Snapshot.groupUnits", function()
    local saved = { }
    local stub = function(name, fn)
      saved[name] = saved[name] == nil and (_G[name] or false) or saved[name]
      _G[name] = fn
    end
    after_each(function()
      for name, fn in pairs(saved) do
        _G[name] = fn or nil
      end
      saved = { }
    end)
    it("lists only the party outside a raid", function()
      stub("IsInRaid", function() return false end)
      return assert.are.same({ "party1", "party2", "party3", "party4" }, Snapshot.groupUnits())
    end)
    it("puts the party first, then the raid by subgroup, never listing the player or party twice", function()
      -- raid1 = player (group 2), raid2 = party1 (group 2), raid3 group 5, raid4 group 1
      local self = { raid1 = "player", raid2 = "party1" }
      local groups = { 2, 2, 5, 1 }
      stub("IsInRaid", function() return true end)
      stub("GetNumGroupMembers", function() return 4 end)
      stub("UnitIsUnit", function(a, b) return self[a] == b end)
      stub("GetRaidRosterInfo", function(i) return "Name" .. i, 0, groups[i] end)
      return assert.are.same({ "party1", "party2", "party3", "party4", "raid4", "raid3" }, Snapshot.groupUnits())
    end)
  end)

  describe("Engine order", function()
    it("buffs the player, then the party, then the raid in snapshot order", function()
      local snap = druidSnap()
      snap.units.player.auras = { }
      snap.groupOrder = { "party1", "raid9", "raid3" }
      snap.units.party1 = member("MAGE")
      snap.units.raid9 = member("PRIEST")
      snap.units.raid3 = member("WARRIOR")
      local steps = doSteps(Engine, snap, Rules.forClass("DRUID"))
      assert.are.equal("Mark of the Wild@player", steps[1])
      local at = { }
      for i, s in ipairs(steps) do at[s] = i end
      assert.is_true(at["Mark of the Wild@party1"] < at["Mark of the Wild@raid9"])
      return assert.is_true(at["Mark of the Wild@raid9"] < at["Mark of the Wild@raid3"])
    end)
    it("skips dead, offline and out-of-range members and moves on", function()
      local snap = druidSnap()
      snap.groupOrder = { "raid1", "raid2", "raid3", "raid4" }
      snap.units.raid1 = member("MAGE", { dead = true })
      snap.units.raid2 = member("MAGE", { connected = false })
      snap.units.raid3 = member("MAGE", { inRange = false })
      snap.units.raid4 = member("MAGE")
      local step = Engine.nextStep(snap, Rules.forClass("DRUID"))
      assert.are.equal("raid4", step.unit)
      return assert.are.equal("Mark of the Wild", step.spell)
    end)
    it("never buffs pets", function()
      local snap = druidSnap()
      snap.groupOrder = { }
      snap.units.pet = member("HUNTER")
      return assert.is_nil(Engine.nextStep(snap, Rules.forClass("DRUID")))
    end)
  end)

  describe("Thorns", function()
    return it("goes on tanks, not on the rest of the raid", function()
      local snap = druidSnap()
      snap.groupOrder = { "raid1", "raid2" }
      snap.units.raid1 = member("WARRIOR", { tank = true, auras = { { name = "Mark of the Wild" } } })
      snap.units.raid2 = member("ROGUE", { auras = { { name = "Mark of the Wild" } } })
      return assert.are.same({ "Thorns@raid1" }, doSteps(Engine, snap, Rules.forClass("DRUID")))
    end)
  end)
end)
