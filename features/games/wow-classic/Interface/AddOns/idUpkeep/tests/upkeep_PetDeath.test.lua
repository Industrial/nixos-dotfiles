local PetDeath = require("src.modules.automation.upkeep.PetDeath")
local store
store = function()
  return { }
end
return describe("Upkeep.PetDeath", function()
  local savedGlobals
  before_each(function()
    savedGlobals = {
      PETTAME_DEAD = _G.PETTAME_DEAD,
      PETTAME_NOTDEAD = _G.PETTAME_NOTDEAD,
      UnitExists = _G.UnitExists,
      UnitIsDead = _G.UnitIsDead,
      GetSpellInfo = _G.GetSpellInfo,
      C_Spell = _G.C_Spell
    }
    _G.PETTAME_DEAD = "Your pet is dead."
    _G.PETTAME_NOTDEAD = "Your pet is not dead."
  end)
  after_each(function()
    for k, v in pairs(savedGlobals) do
      _G[k] = v
    end
    _G.PETTAME_DEAD = savedGlobals.PETTAME_DEAD
    _G.PETTAME_NOTDEAD = savedGlobals.PETTAME_NOTDEAD
  end)
  describe("remembering", function()
    it("starts out not dead", function()
      return assert.is_false(PetDeath.isDead(store()))
    end)
    it("records a death and reports the change", function()
      local s = store()
      assert.is_true(PetDeath.set(s, true))
      return assert.is_true(PetDeath.isDead(s))
    end)
    it("reports no change when told the same thing twice", function()
      local s = store()
      PetDeath.set(s, true)
      return assert.is_false(PetDeath.set(s, true))
    end)
    it("clears by removing the key, not by storing false", function()
      local s = store()
      PetDeath.set(s, true)
      PetDeath.set(s, false)
      return assert.is_nil(s.petDead)
    end)
    return it("ignores a missing store rather than erroring", function()
      return assert.is_false(PetDeath.set(nil, true))
    end)
  end)
  describe("matching the game's error messages", function()
    it("matches the client's own global string", function()
      return assert.is_true(PetDeath.messageIn("Your pet is dead.", PetDeath.DEAD_GLOBALS, PetDeath.DEAD_LITERALS))
    end)
    it("matches regardless of trailing punctuation", function()
      return assert.is_true(PetDeath.messageIn("your pet is dead", PetDeath.DEAD_GLOBALS, PetDeath.DEAD_LITERALS))
    end)
    it("falls back to the English literal when the global is missing", function()
      _G.PETTAME_DEAD = nil
      return assert.is_true(PetDeath.messageIn("Your pet is dead", PetDeath.DEAD_GLOBALS, PetDeath.DEAD_LITERALS))
    end)
    it("does NOT confuse `not dead` with `dead`", function()
      assert.is_false(PetDeath.messageIn("Your pet is not dead.", PetDeath.DEAD_GLOBALS, PetDeath.DEAD_LITERALS))
      return assert.is_true(PetDeath.messageIn("Your pet is not dead.", PetDeath.ALIVE_GLOBALS, PetDeath.ALIVE_LITERALS))
    end)
    it("ignores unrelated errors", function()
      return assert.is_false(PetDeath.messageIn("Out of range.", PetDeath.DEAD_GLOBALS, PetDeath.DEAD_LITERALS))
    end)
    return it("ignores junk input", function()
      local _list_0 = {
        nil,
        "",
        42,
        { }
      }
      for _index_0 = 1, #_list_0 do
        local junk = _list_0[_index_0]
        assert.is_false(PetDeath.messageIn(junk, PetDeath.DEAD_GLOBALS, PetDeath.DEAD_LITERALS))
      end
    end)
  end)
  describe("reading the event arguments", function()
    it("takes the message from a two-argument client", function()
      return assert.are.equal("Your pet is dead.", PetDeath.errorText(50, "Your pet is dead."))
    end)
    it("takes it from a one-argument client too", function()
      return assert.are.equal("Your pet is dead.", PetDeath.errorText("Your pet is dead."))
    end)
    return it("is nil when no string was passed", function()
      return assert.is_nil(PetDeath.errorText(50, nil))
    end)
  end)
  describe("onError", function()
    it("sets the flag on a death message", function()
      local s = store()
      assert.is_true(PetDeath.onError(s, 50, "Your pet is dead."))
      return assert.is_true(PetDeath.isDead(s))
    end)
    it("clears a stale flag on a not-dead message", function()
      local s = store()
      PetDeath.set(s, true)
      assert.is_true(PetDeath.onError(s, 50, "Your pet is not dead."))
      return assert.is_false(PetDeath.isDead(s))
    end)
    return it("leaves the flag alone for anything else", function()
      local s = store()
      PetDeath.set(s, true)
      assert.is_false(PetDeath.onError(s, 50, "Not enough mana."))
      return assert.is_true(PetDeath.isDead(s))
    end)
  end)
  describe("watching the pet unit", function()
    it("records a visible corpse", function()
      _G.UnitExists = function()
        return true
      end
      _G.UnitIsDead = function()
        return true
      end
      local s = store()
      assert.is_true(PetDeath.track(s))
      return assert.is_true(PetDeath.isDead(s))
    end)
    it("clears the flag for a live pet", function()
      _G.UnitExists = function()
        return true
      end
      _G.UnitIsDead = function()
        return false
      end
      local s = store()
      PetDeath.set(s, true)
      assert.is_true(PetDeath.track(s))
      return assert.is_false(PetDeath.isDead(s))
    end)
    it("LEAVES the flag alone when there is no pet unit", function()
      _G.UnitExists = function()
        return false
      end
      _G.UnitIsDead = function()
        return nil
      end
      local s = store()
      PetDeath.set(s, true)
      assert.is_false(PetDeath.track(s))
      return assert.is_true(PetDeath.isDead(s))
    end)
    it("refuses to read a secret value", function()
      _G.UnitExists = function()
        return true
      end
      _G.UnitIsDead = function()
        return "secret"
      end
      local s = store()
      assert.is_false(PetDeath.track(s, function(v)
        return v == "secret"
      end))
      return assert.is_false(PetDeath.isDead(s))
    end)
    it("survives an API that errors", function()
      _G.UnitExists = function()
        return error("boom")
      end
      return assert.is_false(PetDeath.track(store()))
    end)
    return it("survives an API that is simply absent", function()
      _G.UnitExists = nil
      _G.UnitIsDead = nil
      return assert.is_false(PetDeath.track(store()))
    end)
  end)
  return describe("Revive Pet", function()
    before_each(function()
      _G.C_Spell = nil
      _G.GetSpellInfo = function(id)
        if id == PetDeath.REVIVE_PET_ID then
          return "Revive Pet"
        else
          return "Other Spell"
        end
      end
    end)
    it("clears the flag when Revive Pet resolves by id", function()
      local s = store()
      PetDeath.set(s, true)
      assert.is_true(PetDeath.onReviveResult(s, PetDeath.REVIVE_PET_ID))
      return assert.is_false(PetDeath.isDead(s))
    end)
    it("clears it for a higher rank, matched by name", function()
      _G.GetSpellInfo = function()
        return "Revive Pet"
      end
      local s = store()
      PetDeath.set(s, true)
      assert.is_true(PetDeath.onReviveResult(s, 982000))
      return assert.is_false(PetDeath.isDead(s))
    end)
    it("ignores an unrelated spell", function()
      local s = store()
      PetDeath.set(s, true)
      assert.is_false(PetDeath.onReviveResult(s, 1234))
      return assert.is_true(PetDeath.isDead(s))
    end)
    it("does nothing when no death is remembered", function()
      return assert.is_false(PetDeath.onReviveResult(store(), PetDeath.REVIVE_PET_ID))
    end)
    it("reads the name through C_Spell when the client has it", function()
      _G.C_Spell = {
        GetSpellInfo = function(id)
          return {
            name = "Revive Pet"
          }
        end
      }
      _G.GetSpellInfo = nil
      local s = store()
      PetDeath.set(s, true)
      return assert.is_true(PetDeath.onReviveResult(s, 4321))
    end)
    return it("survives having no spell API at all", function()
      _G.C_Spell = nil
      _G.GetSpellInfo = nil
      local s = store()
      PetDeath.set(s, true)
      assert.is_false(PetDeath.onReviveResult(s, 4321))
      return assert.is_true(PetDeath.isDead(s))
    end)
  end)
end)
