local PATHS = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.classes.SHAMAN",
  "src.modules.automation.upkeep.Engine"
}
local load
load = function()
  for _index_0 = 1, #PATHS do
    local p = PATHS[_index_0]
    package.loaded[p] = nil
    require(p)
  end
  return _G.idUpkeep_UpkeepRules, _G.idUpkeep_UpkeepEngine, _G.idUpkeep_UpkeepClassSHAMAN
end
local merge
merge = function(base, over)
  for k, v in pairs(over or { }) do
    base[k] = v
  end
  return base
end
local known
known = function(name, extra)
  return merge({
    name = name,
    known = true,
    usable = true,
    noMana = false,
    icon = "icon:" .. tostring(name)
  }, extra)
end
return describe("Upkeep rules: SHAMAN", function()
  local Rules, Engine, SPELL, rules
  local shamanSnap
  shamanSnap = function(over)
    return merge({
      class = "SHAMAN",
      level = 60,
      now = 1000,
      player = {
        healthPct = 100,
        manaPct = 100,
        usesMana = true
      },
      spells = {
        [SPELL.LIGHTNING_SHIELD] = known("Lightning Shield"),
        [SPELL.ROCKBITER_WEAPON] = known("Rockbiter Weapon"),
        [SPELL.FLAMETONGUE_WEAPON] = known("Flametongue Weapon"),
        [SPELL.FROSTBRAND_WEAPON] = known("Frostbrand Weapon"),
        [SPELL.WINDFURY_WEAPON] = known("Windfury Weapon")
      },
      items = { },
      itemInfo = { },
      units = {
        player = {
          exists = true,
          class = "SHAMAN",
          usesMana = true,
          auras = {
            {
              name = "Lightning Shield",
              expires = 1500
            }
          }
        }
      },
      pet = {
        exists = false
      },
      weapon = {
        mh = {
          itemId = 1,
          isWeapon = true,
          hasEnchant = false
        },
        oh = {
          isWeapon = false
        }
      },
      consumables = { },
      foodBuffs = { },
      food = { },
      water = { },
      weaponItems = { },
      wellFed = {
        ids = { },
        names = {
          "Well Fed"
        }
      }
    }, over)
  end
  local weaponEntry
  weaponEntry = function(snap)
    local _list_0 = Engine.explain(snap, rules)
    for _index_0 = 1, #_list_0 do
      local e = _list_0[_index_0]
      if e.phase == "weapon" then
        return e
      end
    end
  end
  before_each(function()
    Rules, Engine, SPELL = load()
    rules = Rules.forClass("SHAMAN")
  end)
  it("registers as hybrid with an imbue and Lightning Shield", function()
    assert.are.equal("hybrid", rules.role)
    local kinds = { }
    local _list_0 = rules.rules
    for _index_0 = 1, #_list_0 do
      local r = _list_0[_index_0]
      kinds[r.kind] = true
    end
    assert.is_true(kinds.weaponImbue)
    return assert.is_true(kinds.selfBuff)
  end)
  describe("weapon imbue", function()
    it("picks Windfury when known", function()
      local step = Engine.nextStep(shamanSnap(), rules)
      assert.are.equal("Windfury Weapon", step.spell)
      assert.are.equal("player", step.unit)
      return assert.are.equal("weapon", step.phase)
    end)
    it("falls back to Rockbiter, then Flametongue", function()
      local snap = shamanSnap()
      snap.spells[SPELL.WINDFURY_WEAPON].known = false
      assert.are.equal("Rockbiter Weapon", (Engine.nextStep(snap, rules)).spell)
      snap.spells[SPELL.ROCKBITER_WEAPON].known = false
      return assert.are.equal("Flametongue Weapon", (Engine.nextStep(snap, rules)).spell)
    end)
    it("never picks Frostbrand", function()
      local snap = shamanSnap()
      local _list_0 = {
        SPELL.WINDFURY_WEAPON,
        SPELL.ROCKBITER_WEAPON,
        SPELL.FLAMETONGUE_WEAPON
      }
      for _index_0 = 1, #_list_0 do
        local id = _list_0[_index_0]
        snap.spells[id].known = false
      end
      assert.is_nil((Engine.nextStep(snap, rules)))
      return assert.are.equal("spell not known", (weaponEntry(snap)).reason)
    end)
    it("is not recast while active", function()
      local snap = shamanSnap({
        weapon = {
          mh = {
            isWeapon = true,
            hasEnchant = true,
            remaining = 250
          },
          oh = {
            isWeapon = false
          }
        }
      })
      assert.are.equal("done", (weaponEntry(snap)).status)
      local step, reason = Engine.nextStep(snap, rules)
      assert.is_nil(step)
      return assert.are.equal("nothing to do", reason)
    end)
    it("is recast below the refresh threshold", function()
      local snap = shamanSnap({
        weapon = {
          mh = {
            isWeapon = true,
            hasEnchant = true,
            remaining = 45
          },
          oh = {
            isWeapon = false
          }
        }
      })
      local step = Engine.nextStep(snap, rules)
      assert.are.equal("Windfury Weapon", step.spell)
      return assert.matches("expiring", step.reason)
    end)
    return it("is skipped without a main-hand weapon", function()
      local snap = shamanSnap({
        weapon = {
          mh = {
            isWeapon = false
          },
          oh = {
            isWeapon = false
          }
        }
      })
      local e = weaponEntry(snap)
      assert.are.equal("skip", e.status)
      assert.matches("no weapon", e.reason)
      return assert.is_nil((Engine.nextStep(snap, rules)))
    end)
  end)
  return describe("Lightning Shield", function()
    it("is cast first when missing", function()
      local snap = shamanSnap()
      snap.units.player.auras = { }
      local step = Engine.nextStep(snap, rules)
      assert.are.equal("Lightning Shield", step.spell)
      assert.are.equal("selfLong", step.phase)
      return assert.are.equal("missing", step.reason)
    end)
    return it("is not recast while present, even close to expiry", function()
      local snap = shamanSnap({
        weapon = {
          mh = {
            isWeapon = true,
            hasEnchant = true,
            remaining = 250
          },
          oh = {
            isWeapon = false
          }
        }
      })
      snap.units.player.auras = {
        {
          name = "Lightning Shield",
          expires = snap.now + 5
        }
      }
      local step = Engine.nextStep(snap, rules)
      return assert.is_nil(step)
    end)
  end)
end)
