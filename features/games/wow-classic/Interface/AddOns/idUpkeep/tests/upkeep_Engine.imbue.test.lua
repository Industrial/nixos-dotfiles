local PATHS = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.Engine"
}
local load
load = function()
  for _index_0 = 1, #PATHS do
    local p = PATHS[_index_0]
    package.loaded[p] = nil
    require(p)
  end
  return _G.idUpkeep_UpkeepRules, _G.idUpkeep_UpkeepEngine
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
local ID = {
  BEST = 1001,
  MID = 1002,
  LOW = 1003
}
local snapWith
snapWith = function(over)
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
      [ID.BEST] = {
        name = "Best Imbue",
        known = false
      },
      [ID.MID] = known("Mid Imbue"),
      [ID.LOW] = known("Low Imbue")
    },
    items = { },
    itemInfo = { },
    units = {
      player = {
        exists = true,
        class = "SHAMAN",
        usesMana = true,
        auras = { }
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
return describe("Upkeep Engine: weaponImbue", function()
  local R, Engine
  before_each(function()
    R, Engine = load()
  end)
  local rulesWith
  rulesWith = function(opts)
    return R.classRules({
      role = "hybrid",
      rules = {
        R.weaponImbue(merge({
          slot = "mh",
          spells = {
            ID.BEST,
            ID.MID,
            ID.LOW
          }
        }, opts))
      }
    })
  end
  local imbueEntry
  imbueEntry = function(snap, rules)
    local _list_0 = Engine.explain(snap, rules)
    for _index_0 = 1, #_list_0 do
      local e = _list_0[_index_0]
      if e.phase == "weapon" then
        return e
      end
    end
  end
  it("builds a weapon-phase rule with defaults", function()
    local rule = R.weaponImbue({
      spells = 8017
    })
    assert.are.equal("weaponImbue", rule.kind)
    assert.is_true(rule.phases.weapon)
    assert.are.equal("mh", rule.slot)
    assert.are.same({
      8017
    }, rule.spells)
    return assert.are.equal(60, rule.refresh)
  end)
  it("collects its spell ids for the snapshot", function()
    local ids = R.collectSpellIds(rulesWith())
    local seen = { }
    for _index_0 = 1, #ids do
      local id = ids[_index_0]
      seen[id] = true
    end
    return assert.is_true(seen[ID.BEST] and seen[ID.MID] and seen[ID.LOW])
  end)
  it("casts the best KNOWN imbue on self when the main hand has no enchant", function()
    local step = Engine.nextStep(snapWith(), rulesWith())
    assert.are.equal("spell", step.kind)
    assert.are.equal("Mid Imbue", step.spell)
    assert.are.equal(ID.MID, step.spellId)
    assert.are.equal("player", step.unit)
    assert.is_nil(step.targetSlot)
    assert.are.equal("weapon", step.phase)
    return assert.are.equal("no enchant", step.reason)
  end)
  it("is done while an enchant has more than refresh seconds left", function()
    local snap = snapWith({
      weapon = {
        mh = {
          isWeapon = true,
          hasEnchant = true,
          remaining = 200
        },
        oh = {
          isWeapon = false
        }
      }
    })
    local e = imbueEntry(snap, rulesWith())
    assert.are.equal("done", e.status)
    assert.matches("enchanted", e.reason)
    return assert.is_nil((Engine.nextStep(snap, rulesWith())))
  end)
  it("recasts when the enchant is below refresh", function()
    local snap = snapWith({
      weapon = {
        mh = {
          isWeapon = true,
          hasEnchant = true,
          remaining = 30
        },
        oh = {
          isWeapon = false
        }
      }
    })
    local step = Engine.nextStep(snap, rulesWith())
    assert.are.equal("Mid Imbue", step.spell)
    return assert.matches("expiring", step.reason)
  end)
  it("honours a custom refresh", function()
    local snap = snapWith({
      weapon = {
        mh = {
          isWeapon = true,
          hasEnchant = true,
          remaining = 100
        },
        oh = {
          isWeapon = false
        }
      }
    })
    assert.are.equal("done", (imbueEntry(snap, rulesWith())).status)
    return assert.are.equal("do", (imbueEntry(snap, rulesWith({
      refresh = 120
    }))).status)
  end)
  it("skips without a main-hand weapon", function()
    local snap = snapWith({
      weapon = {
        mh = {
          isWeapon = false
        },
        oh = {
          isWeapon = false
        }
      }
    })
    local e = imbueEntry(snap, rulesWith())
    assert.are.equal("skip", e.status)
    return assert.matches("no weapon", e.reason)
  end)
  it("skips when no imbue is known", function()
    local snap = snapWith()
    snap.spells[ID.MID].known = false
    snap.spells[ID.LOW].known = false
    local e = imbueEntry(snap, rulesWith())
    assert.are.equal("skip", e.status)
    return assert.are.equal("spell not known", e.reason)
  end)
  it("skips without mana", function()
    local snap = snapWith()
    snap.spells[ID.MID].noMana = true
    local e = imbueEntry(snap, rulesWith())
    assert.are.equal("skip", e.status)
    return assert.matches("mana", e.reason)
  end)
  it("skips an off-hand rule (imbue spells only hit the main hand)", function()
    local e = imbueEntry(snapWith(), rulesWith({
      slot = "oh"
    }))
    assert.are.equal("skip", e.status)
    return assert.matches("main hand", e.reason)
  end)
  return it("suppresses a just-pressed imbue", function()
    local step = Engine.nextStep(snapWith(), rulesWith())
    local e = nil
    local _list_0 = Engine.explain(snapWith(), rulesWith(), {
      recent = {
        [step.key] = true
      }
    })
    for _index_0 = 1, #_list_0 do
      local x = _list_0[_index_0]
      if x.phase == "weapon" then
        e = x
      end
    end
    assert.are.equal("skip", e.status)
    return assert.matches("just used", e.reason)
  end)
end)
