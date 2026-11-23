local PATHS = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.classes.DRUID",
  "src.modules.automation.upkeep.Snapshot"
}
local STUBBED = {
  "UnitClass",
  "UnitExists",
  "UnitIsDead",
  "GetShapeshiftForm",
  "C_Spell",
  "IsPlayerSpell",
  "C_UnitAuras"
}
return describe("Upkeep Snapshot", function()
  local Snapshot, Rules, saved, classToken, form, petExists, petDead
  before_each(function()
    saved = { }
    for _index_0 = 1, #STUBBED do
      local k = STUBBED[_index_0]
      saved[k] = {
        _G[k]
      }
    end
    classToken, form = "DRUID", 0
    petExists, petDead = false, false
    _G.UnitClass = function()
      return classToken, classToken
    end
    _G.UnitExists = function(unit)
      return unit == "player" or (unit == "pet" and petExists)
    end
    _G.UnitIsDead = function(unit)
      return unit == "pet" and petDead
    end
    _G.GetShapeshiftForm = function()
      return form
    end
    _G.IsPlayerSpell = function()
      return true
    end
    _G.C_UnitAuras = {
      GetAuraDataByIndex = function()
        return nil
      end
    }
    _G.C_Spell = {
      GetSpellInfo = function(id)
        return {
          name = "Spell" .. tostring(id),
          iconID = id
        }
      end,
      IsSpellUsable = function()
        return false, true
      end
    }
    for _index_0 = 1, #PATHS do
      local p = PATHS[_index_0]
      package.loaded[p] = nil
      require(p)
    end
    Snapshot, Rules = _G.idUpkeep_UpkeepSnapshot, _G.idUpkeep_UpkeepRules
  end)
  after_each(function()
    for _index_0 = 1, #STUBBED do
      local k = STUBBED[_index_0]
      _G[k] = saved[k][1]
    end
  end)
  local build
  build = function(opts)
    if opts == nil then
      opts = { }
    end
    opts.consumables = false
    return Snapshot.build(Rules.forClass(classToken) or {
      rules = { }
    }, opts)
  end
  describe("shapeshiftForm", function()
    it("reads GetShapeshiftForm", function()
      form = 1
      return assert.are.equal(1, build().shapeshiftForm)
    end)
    it("is 0 when the API is missing or returns nil", function()
      _G.GetShapeshiftForm = nil
      assert.are.equal(0, build().shapeshiftForm)
      _G.GetShapeshiftForm = function()
        return nil
      end
      return assert.are.equal(0, build().shapeshiftForm)
    end)
    it("treats spell usability / mana as unknown for a druid in a form", function()
      form = 2
      local s = build().spells[1126]
      assert.is_true(s.known)
      assert.is_nil(s.usable)
      return assert.is_nil(s.noMana)
    end)
    return it("keeps the API's usability in caster form", function()
      local s = build().spells[1126]
      assert.is_false(s.usable)
      return assert.is_true(s.noMana)
    end)
  end)
  return describe("pet.dead (HUNTER memory)", function()
    it("marks a missing pet dead when the module remembers its death", function()
      classToken = "HUNTER"
      local snap = build({
        petDead = true
      })
      assert.is_false(snap.pet.exists)
      return assert.is_true(snap.pet.dead)
    end)
    it("reports no pet without the flag", function()
      classToken = "HUNTER"
      return assert.is_false(build().pet.dead)
    end)
    it("a live pet unit wins over a stale flag", function()
      classToken = "HUNTER"
      petExists = true
      local snap = build({
        petDead = true
      })
      assert.is_true(snap.pet.exists)
      return assert.is_false(snap.pet.dead)
    end)
    return it("ignores the flag for other classes", function()
      classToken = "WARLOCK"
      return assert.is_false(build({
        petDead = true
      }).pet.dead)
    end)
  end)
end)
