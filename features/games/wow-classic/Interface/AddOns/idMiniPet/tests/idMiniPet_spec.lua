-- busted spec for idMiniPet.lua. Run from the addon folder: busted tests/idMiniPet_spec.lua
local tick, later, summoned, out, state

before_each(function()
  summoned, out, later = {}, nil, nil
  state = { combat = false, mounted = false, dead = false, taxi = false, stealth = false, feign = false }
  _G.C_PetJournal = {
    GetSummonedPetGUID = function() return out end,
    SummonRandomPet = function(fav) summoned[#summoned + 1] = fav end,
  }
  _G.C_Timer = {
    NewTicker = function(s, fn) assert.are.equal(5, s); tick = fn end,
    After = function(s, fn) assert.are.equal(1, s); later = fn end,
  }
  _G.InCombatLockdown = function() return state.combat end
  _G.IsMounted = function() return state.mounted end
  _G.UnitIsDeadOrGhost = function() return state.dead end
  _G.UnitOnTaxi = function() return state.taxi end
  _G.IsStealthed = function() return state.stealth end
  _G.UnitIsFeignDeath = function() return state.feign end
  dofile("idMiniPet.lua")
end)

describe("idMiniPet", function()
  it("summons a random favorite when no pet is out", function()
    tick()
    assert.are.same({ true }, summoned)
  end)

  it("falls back to any pet when the favorite summon brought none", function()
    tick()
    later()
    assert.are.same({ true, false }, summoned)
  end)

  it("does not fall back when a favorite came out", function()
    tick()
    out = "BattlePet-0-123"
    later()
    assert.are.same({ true }, summoned)
  end)

  it("does nothing while a pet is already out", function()
    out = "BattlePet-0-123"
    tick()
    assert.are.same({}, summoned)
  end)

  for _, k in ipairs({ "combat", "mounted", "dead", "taxi", "stealth", "feign" }) do
    it("waits while " .. k, function()
      state[k] = true
      tick()
      assert.are.same({}, summoned)
    end)
  end
end)
