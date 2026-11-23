local Macros = require("src.modules.automation.upkeep.Macros")
local fakeApi
fakeApi = function(existing, overrides)
  if existing == nil then
    existing = { }
  end
  if overrides == nil then
    overrides = { }
  end
  local macros
  do
    local _accum_0 = { }
    local _len_0 = 1
    for k, v in pairs(existing) do
      _accum_0[_len_0] = {
        name = k,
        body = v
      }
      _len_0 = _len_0 + 1
    end
    macros = _accum_0
  end
  local api = {
    created = { },
    edited = { },
    maxAccountMacros = 120,
    getNumMacros = function()
      return #macros
    end,
    getMacroIndexByName = function(name)
      for i, m in ipairs(macros) do
        if m.name == name then
          return i
        end
      end
      return 0
    end,
    getMacroInfo = function(index)
      local m = macros[index]
      if not (m) then
        return nil
      end
      return m.name, "icon", m.body
    end
  }
  api.createMacro = function(name, icon, body)
    macros[#macros + 1] = {
      name = name,
      body = body
    }
    api.created[name] = body
    return #macros
  end
  api.editMacro = function(index, name, icon, body)
    macros[index] = {
      name = name,
      body = body
    }
    api.edited[name] = body
    return index
  end
  for k, v in pairs(overrides) do
    api[k] = v
  end
  return api
end
local specFor
specFor = function(job)
  local _list_0 = Macros.SPECS
  for _index_0 = 1, #_list_0 do
    local spec = _list_0[_index_0]
    if spec.job == job then
      return spec
    end
  end
  return nil
end
local bodyOf
bodyOf = function(job, hint, use)
  return Macros.bodyFor(specFor(job), hint, use)
end
local clickOf
clickOf = function(job)
  return Macros.clickLine(specFor(job))
end
return describe("Upkeep.Macros", function()
  describe("what the macros are", function()
    it("has one per button", function()
      local jobs = { }
      local _list_0 = Macros.SPECS
      for _index_0 = 1, #_list_0 do
        local spec = _list_0[_index_0]
        jobs[spec.job] = spec.button
      end
      assert.are.equal("idUpkeepBuffsButton", jobs.buffs)
      assert.are.equal("idUpkeepHealthButton", jobs.health)
      return assert.are.equal("idUpkeepManaButton", jobs.mana)
    end)
    it("clicks the button for buffs, and uses the item itself for sustain", function()
      local buffs = specFor("buffs")
      assert.are.equal("click", buffs.action)
      assert.are.equal("#showtooltip\n/click " .. tostring(buffs.button), Macros.bodyFor(buffs))
      local _list_0 = {
        "health",
        "mana"
      }
      for _index_0 = 1, #_list_0 do
        local job = _list_0[_index_0]
        local spec = specFor(job)
        assert.are.equal("use", spec.action)
        assert.are.equal("#showtooltip x\n/use y", Macros.bodyFor(spec, "x", "y"))
        assert.are.equal("#showtooltip", Macros.bodyFor(spec))
      end
    end)
    it("never puts a /click in a sustain macro", function()
      local _list_0 = {
        "health",
        "mana"
      }
      for _index_0 = 1, #_list_0 do
        local job = _list_0[_index_0]
        local body = Macros.bodyFor(specFor(job), "item:1", "Conjured Water")
        assert.is_nil(body:find("/click", 1, true))
      end
    end)
    it("fits inside the game's own limits", function()
      local _list_0 = Macros.SPECS
      for _index_0 = 1, #_list_0 do
        local spec = _list_0[_index_0]
        assert.is_true(#spec.name <= Macros.MAX_NAME, ("%q is %d characters"):format(spec.name, #spec.name))
        local longest = Macros.bodyFor(spec, "[combat] item:123456; item:123456", "[combat] Super Mana Potion; Conjured Crystal Water")
        assert.is_true(#longest <= Macros.MAX_BODY, ("%d characters"):format(#longest))
      end
    end)
    return it("gives every macro a distinct name", function()
      local seen = { }
      local _list_0 = Macros.SPECS
      for _index_0 = 1, #_list_0 do
        local spec = _list_0[_index_0]
        assert.is_nil(seen[spec.name], spec.name)
        seen[spec.name] = true
      end
    end)
  end)
  describe("the icon it shows", function()
    it("shows a buff spell by name", function()
      return assert.are.equal("Arcane Intellect", Macros.hintForStep({
        kind = "spell",
        spell = "Arcane Intellect"
      }))
    end)
    it("shows a buff item by id", function()
      return assert.are.equal("item:8928", Macros.hintForStep({
        kind = "item",
        item = 8928
      }))
    end)
    it("shows a sustain step's OWN conditional, not a second guess at it", function()
      local step = {
        kind = "macro",
        showHint = "[combat] item:13446; item:8950"
      }
      return assert.are.equal("[combat] item:13446; item:8950", Macros.hintForStep(step))
    end)
    it("shows nothing rather than guessing", function()
      assert.is_nil(Macros.hintForStep(nil))
      assert.is_nil(Macros.hintForStep({
        kind = "spell"
      }))
      return assert.is_nil(Macros.hintForStep({
        kind = "nonsense",
        item = 1
      }))
    end)
    it("writes a bare #showtooltip when there is nothing to show", function()
      assert.are.equal("#showtooltip\n" .. tostring(clickOf('buffs')), bodyOf("buffs", nil))
      return assert.are.equal("#showtooltip\n" .. tostring(clickOf('buffs')), bodyOf("buffs", ""))
    end)
    return it("agrees with Sustain about what a press will consume", function()
      local Sustain = require("src.modules.automation.upkeep.Sustain")
      local chosen = {
        combat = {
          itemId = 13446
        },
        safe = {
          itemId = 8950
        }
      }
      local conditional = Sustain.conditional(chosen)
      return assert.are.equal(("/use %s"):format(conditional), ("/use %s"):format(Macros.hintForStep({
        kind = "macro",
        showHint = conditional
      })))
    end)
  end)
  describe("deciding what to do", function()
    it("creates one that does not exist", function()
      return assert.are.equal("create", Macros.planFor(fakeApi(), Macros.SPECS[1]))
    end)
    it("keeps one whose body already shows and uses the right thing", function()
      local api = fakeApi({
        ["Upkeep Health"] = bodyOf("health", "item:8950", "Bread")
      })
      return assert.are.equal("keep", Macros.planFor(api, specFor("health"), "item:8950", "Bread"))
    end)
    it("retunes one of ours whose choice moved", function()
      local api = fakeApi({
        ["Upkeep Health"] = bodyOf("health", "item:8950", "Bread")
      })
      return assert.are.equal("retune", Macros.planFor(api, specFor("health"), "item:13446", "Healing Potion"))
    end)
    it("retunes the BROKEN /click body earlier versions wrote for sustain", function()
      local api = fakeApi({
        ["Upkeep Health"] = clickOf("health")
      })
      assert.is_true(Macros.isOurs(clickOf("health"), specFor("health")))
      assert.are.equal("retune", Macros.planFor(api, specFor("health"), "item:8950", "Bread"))
      Macros.ensure(api, {
        health = "item:8950"
      }, {
        health = "Bread"
      })
      assert.are.equal(bodyOf("health", "item:8950", "Bread"), api.edited["Upkeep Health"])
      return assert.is_nil(api.edited["Upkeep Health"]:find("/click", 1, true))
    end)
    it("keeps one the player EXTENDED, icon and all", function()
      local body = "#showtooltip item:1234\n/use Bread\n/say drinking"
      local api = fakeApi({
        ["Upkeep Mana"] = body
      })
      assert.is_false(Macros.isOurs(body, specFor("mana")))
      return assert.are.equal("keep", Macros.planFor(api, specFor("mana"), "item:9999", "Water"))
    end)
    it("recognises its own lines, and only its own", function()
      local buffs, health = specFor("buffs"), specFor("health")
      assert.is_true(Macros.isOurs(clickOf("buffs"), buffs))
      assert.is_true(Macros.isOurs(bodyOf("buffs", "item:1"), buffs))
      assert.is_true(Macros.isOurs("  " .. tostring(bodyOf('buffs', 'item:1')) .. "  ", buffs))
      assert.is_false(Macros.isOurs(tostring(clickOf('buffs')) .. "\n/say hi", buffs))
      assert.is_false(Macros.isOurs(clickOf("health"), buffs))
      assert.is_false(Macros.isOurs(nil, buffs))
      assert.is_false(Macros.isOurs("", buffs))
      assert.is_true(Macros.isOurs(bodyOf("health", "item:1", "Bread"), health))
      return assert.is_false(Macros.isOurs("#showtooltip\n/use Bread", buffs))
    end)
    it("repairs one that points somewhere else", function()
      local api = fakeApi({
        ["Upkeep Buffs"] = "/click SomeOtherButton"
      })
      return assert.are.equal("repair", Macros.planFor(api, Macros.SPECS[1]))
    end)
    it("retunes a buff macro without touching its click line", function()
      local api = fakeApi({
        ["Upkeep Buffs"] = bodyOf("buffs", "Old Spell")
      })
      Macros.ensure(api, {
        buffs = "New Spell"
      })
      assert.are.equal(bodyOf("buffs", "New Spell"), api.edited["Upkeep Buffs"])
      return assert.is_truthy(api.edited["Upkeep Buffs"]:find(clickOf("buffs"), 1, true))
    end)
    it("repairs an empty body", function()
      local api = fakeApi({
        ["Upkeep Buffs"] = ""
      })
      return assert.are.equal("repair", Macros.planFor(api, Macros.SPECS[1]))
    end)
    it("skips when the client offers no macro API", function()
      local action, why = Macros.planFor({ }, Macros.SPECS[1])
      assert.are.equal("skip", action)
      return assert.is_string(why)
    end)
    return it("skips rather than guessing when the macro list cannot be read", function()
      local api = fakeApi({ }, {
        getMacroIndexByName = function()
          return error("boom")
        end
      })
      return assert.are.equal("skip", Macros.planFor(api, Macros.SPECS[1]))
    end)
  end)
  describe("ensure", function()
    it("creates all three on a fresh account", function()
      local api = fakeApi()
      local results = Macros.ensure(api)
      local _list_0 = {
        "buffs",
        "health",
        "mana"
      }
      for _index_0 = 1, #_list_0 do
        local job = _list_0[_index_0]
        assert.are.equal("created", results[job])
      end
      return assert.are.equal(bodyOf("buffs"), api.created["Upkeep Buffs"])
    end)
    it("creates them already showing and using the right thing", function()
      local api = fakeApi()
      Macros.ensure(api, {
        health = "item:8950",
        mana = "[combat] item:1; item:2"
      }, {
        health = "Bread",
        mana = "[combat] Mana Potion; Water"
      })
      assert.are.equal(bodyOf("health", "item:8950", "Bread"), api.created["Upkeep Health"])
      return assert.are.equal(bodyOf("mana", "[combat] item:1; item:2", "[combat] Mana Potion; Water"), api.created["Upkeep Mana"])
    end)
    it("uses item NAMES in the line that runs, ids only in the icon line", function()
      local api = fakeApi()
      Macros.ensure(api, {
        health = "item:8950"
      }, {
        health = "[nocombat] Bread"
      })
      local body = api.created["Upkeep Health"]
      assert.is_truthy(body:find("#showtooltip item:8950", 1, true))
      assert.is_truthy(body:find("/use [nocombat] Bread", 1, true))
      return assert.is_nil(body:find("/use item:", 1, true))
    end)
    it("rewrites nothing when the choice has not changed", function()
      local api = fakeApi()
      local hints, uses = {
        buffs = "Fortitude",
        health = "item:8950"
      }, {
        health = "Bread"
      }
      Macros.ensure(api, hints, uses)
      api.created, api.edited = { }, { }
      local results = Macros.ensure(api, hints, uses)
      assert.are.same({ }, api.edited)
      return assert.are.equal("kept", results.health)
    end)
    it("retunes only the macro whose choice moved", function()
      local api = fakeApi()
      Macros.ensure(api, {
        buffs = "Fortitude",
        health = "item:8950"
      }, {
        health = "Bread"
      })
      api.edited = { }
      local results = Macros.ensure(api, {
        buffs = "Fortitude",
        health = "item:13446"
      }, {
        health = "Healing Potion"
      })
      assert.are.equal("kept", results.buffs)
      assert.are.equal("retuned", results.health)
      assert.is_nil(api.edited["Upkeep Buffs"])
      return assert.are.equal(bodyOf("health", "item:13446", "Healing Potion"), api.edited["Upkeep Health"])
    end)
    it("empties the macro when there is nothing left to use", function()
      local api = fakeApi()
      Macros.ensure(api, {
        health = "item:8950"
      }, {
        health = "Bread"
      })
      api.edited = { }
      Macros.ensure(api, { }, { })
      assert.are.equal("#showtooltip", api.edited["Upkeep Health"])
      return assert.is_nil(api.edited["Upkeep Health"]:find("/use", 1, true))
    end)
    it("is idempotent: a second run changes nothing", function()
      local api = fakeApi()
      Macros.ensure(api)
      api.created, api.edited = { }, { }
      local results = Macros.ensure(api)
      assert.are.same({ }, api.created)
      assert.are.same({ }, api.edited)
      return assert.are.equal("kept", results.buffs)
    end)
    it("repairs only the broken one, leaving the others untouched", function()
      local api = fakeApi({
        ["Upkeep Buffs"] = bodyOf("buffs"),
        ["Upkeep Health"] = "/click Wrong",
        ["Upkeep Mana"] = bodyOf("mana")
      })
      local results = Macros.ensure(api)
      assert.are.equal("kept", results.buffs)
      assert.are.equal("repaired", results.health)
      assert.are.equal("kept", results.mana)
      assert.are.equal(bodyOf("health"), api.edited["Upkeep Health"])
      return assert.is_nil(api.edited["Upkeep Mana"])
    end)
    it("refuses to delete anything when the macro list is FULL", function()
      local api = fakeApi({ }, {
        getNumMacros = function()
          return 120
        end
      })
      local results, problems = Macros.ensure(api)
      assert.are.equal("skipped", results.buffs)
      assert.are.same({ }, api.created)
      return assert.is_truthy((table.concat(problems, " ")):find("full", 1, true))
    end)
    it("still keeps an existing macro when the list is full", function()
      local api = fakeApi({
        ["Upkeep Buffs"] = bodyOf("buffs")
      }, {
        getNumMacros = function()
          return 120
        end
      })
      return assert.are.equal("kept", (Macros.ensure(api)).buffs)
    end)
    it("reports a CreateMacro that fails instead of erroring", function()
      local api = fakeApi({ }, {
        createMacro = function()
          return error("cannot create macros right now")
        end
      })
      local results, problems = Macros.ensure(api)
      assert.are.equal("skipped", results.buffs)
      return assert.is_truthy((table.concat(problems, " ")):find("cannot create", 1, true))
    end)
    it("reports an EditMacro that fails instead of erroring", function()
      local api = fakeApi({
        ["Upkeep Buffs"] = "/click Wrong"
      }, {
        editMacro = function()
          return error("nope")
        end
      })
      local results, problems = Macros.ensure(api)
      assert.are.equal("skipped", results.buffs)
      return assert.is_truthy(#problems > 0)
    end)
    it("skips a repair when the client cannot edit macros at all", function()
      local api = fakeApi({
        ["Upkeep Buffs"] = "/click Wrong"
      })
      api.editMacro = nil
      return assert.are.equal("skipped", (Macros.ensure(api)).buffs)
    end)
    it("survives no API at all, reporting every macro as skipped", function()
      local results, problems = Macros.ensure({ })
      local _list_0 = {
        "buffs",
        "health",
        "mana"
      }
      for _index_0 = 1, #_list_0 do
        local job = _list_0[_index_0]
        assert.are.equal("skipped", results[job])
      end
      return assert.are.equal(3, #problems)
    end)
    return it("treats an unreadable macro count as `do not know`, not as full", function()
      local api = fakeApi({ }, {
        getNumMacros = function()
          return error("boom")
        end
      })
      assert.is_nil(Macros.freeSlots(api))
      return assert.are.equal("created", (Macros.ensure(api)).buffs)
    end)
  end)
  describe("describe", function()
    it("names each macro, its body and its state", function()
      local api = fakeApi({
        ["Upkeep Buffs"] = bodyOf("buffs")
      })
      local text = table.concat(Macros.describe(api, {
        buffs = "Fortitude"
      }), "\n")
      assert.is_truthy(text:find("Upkeep Buffs", 1, true))
      return assert.is_truthy(text:find("missing", 1, true))
    end)
    it("names the icon each macro shows", function()
      local api = fakeApi({
        ["Upkeep Health"] = bodyOf("health", "item:8950", "Bread")
      })
      local text = table.concat(Macros.describe(api, {
        health = "item:8950"
      }, {
        health = "Bread"
      }), "\n")
      assert.is_truthy(text:find("item:8950", 1, true))
      return assert.is_truthy(text:find("ready", 1, true))
    end)
    it("prints the exact line that will run", function()
      local api = fakeApi()
      local text = table.concat(Macros.describe(api, { }, {
        health = "[nocombat] Bread"
      }), "\n")
      return assert.is_truthy(text:find("/use [nocombat] Bread", 1, true))
    end)
    it("says when a macro is out of date", function()
      local api = fakeApi({
        ["Upkeep Health"] = bodyOf("health", "item:8950", "Bread")
      })
      local text = table.concat(Macros.describe(api, {
        health = "item:13446"
      }, {
        health = "Potion"
      }), "\n")
      return assert.is_truthy(text:find("out of date", 1, true))
    end)
    return it("says so when the client has no macro API", function()
      local text = table.concat(Macros.describe({ }), "\n")
      return assert.is_truthy(text:find("unavailable", 1, true))
    end)
  end)
  return describe("liveApi", function()
    return it("collects the globals in one place, tolerating missing ones", function()
      local saved = {
        _G.CreateMacro,
        _G.GetMacroInfo,
        _G.MAX_ACCOUNT_MACROS
      }
      _G.CreateMacro, _G.GetMacroInfo, _G.MAX_ACCOUNT_MACROS = nil, nil, nil
      local api = Macros.liveApi()
      assert.is_nil(api.createMacro)
      assert.are.equal(120, api.maxAccountMacros)
      _G.CreateMacro, _G.GetMacroInfo, _G.MAX_ACCOUNT_MACROS = saved[1], saved[2], saved[3]
    end)
  end)
end)
