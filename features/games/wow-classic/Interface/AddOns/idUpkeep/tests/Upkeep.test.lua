local Boot = require("src.test_bootstrap")
local PATHS = {
  "src.modules.automation.upkeep.Rules",
  "src.modules.automation.upkeep.classes.WARRIOR",
  "src.modules.automation.upkeep.classes.MAGE",
  "src.modules.automation.upkeep.Engine",
  "src.modules.automation.upkeep.Consumables",
  "src.modules.automation.upkeep.Snapshot",
  "src.modules.automation.upkeep.Spells",
  "src.modules.automation.upkeep.Button",
  "src.modules.automation.upkeep.Sustain",
  "src.modules.automation.upkeep.PetDeath",
  "src.modules.automation.upkeep.Macros",
  "src.modules.automation.Upkeep"
}
local BUTTON_NAMES = {
  buffs = "idUpkeepBuffsButton",
  health = "idUpkeepHealthButton",
  mana = "idUpkeepManaButton"
}
return describe("Upkeep module (BDD)", function()
  local Node, Upkeep, inCombat, now, savedCreateFrame, created, attrWrites
  local newModule
  newModule = function()
    local m = Upkeep(Node(nil, Boot.next_key()), "Upkeep")
    m.db.enable = true
    return m
  end
  local enabled
  enabled = function()
    local m = newModule()
    m:enable()
    return m
  end
  local attrsOf
  attrsOf = function(m, job)
    local btn = m.buttons[job]
    return btn and btn._attrs or { }
  end
  before_each(function()
    Node = Boot.ensure()
    Boot.reset_logger(Boot.Logger)
    inCombat = false
    now = 100
    attrWrites = { }
    _G.InCombatLockdown = function()
      return inCombat
    end
    _G.GetTime = function()
      return now
    end
    _G.C_Timer = nil
    _G.SlashCmdList = { }
    _G.SLASH_IDUPKEEPUPKEEP1 = nil
    _G.C_UnitAuras = {
      GetAuraDataByIndex = function()
        return nil
      end
    }
    savedCreateFrame = _G.CreateFrame
    created = { }
    _G.CreateFrame = function(frameType, name, parent, template)
      local f = savedCreateFrame(frameType, name, parent, template)
      table.insert(created, name or frameType)
      local inner = f.SetAttribute
      f.SetAttribute = function(self, attr, value)
        table.insert(attrWrites, {
          name = name,
          attr = attr,
          inCombat = inCombat
        })
        if inner then
          return inner(self, attr, value)
        end
      end
      return f
    end
    for _index_0 = 1, #PATHS do
      local p = PATHS[_index_0]
      package.loaded[p] = nil
      require(p)
    end
    Upkeep = _G.idUpkeep_Upkeep
  end)
  after_each(function()
    _G.CreateFrame = savedCreateFrame
    _G.C_UnitAuras = nil
  end)
  describe("registration", function()
    it("is ON by default, now that it is the only module for the job", function()
      local m = Upkeep(Node(nil, Boot.next_key()), "Upkeep")
      assert.is_true(m.db.enable)
      return assert.is_true(m.db.create_macros)
    end)
    it("is combat sensitive, because it owns secure buttons", function()
      return assert.is_true(newModule().combatSensitive)
    end)
    return it("offers the options that change what it does", function()
      local vars = { }
      local _list_0 = newModule().options
      for _index_0 = 1, #_list_0 do
        local o = _list_0[_index_0]
        vars[o.variable] = true
      end
      assert.is_true(vars.enable)
      assert.is_true(vars.create_macros)
      assert.is_true(vars.include_party)
      assert.is_true(vars.use_consumables)
      return assert.is_true(vars.rest_threshold)
    end)
  end)
  describe("taking over from Prepare", function()
    local migrated
    migrated = function(prepareDb)
      local m = Upkeep(Node(nil, Boot.next_key()), "Upkeep")
      local _list_0 = {
        "migrated_from_prepare"
      }
      for _index_0 = 1, #_list_0 do
        local k = _list_0[_index_0]
        m.db[k] = nil
      end
      m.database.Get = function(_self, path)
        if path == "character.Prepare" then
          return prepareDb
        end
        return nil
      end
      m:migrateFromPrepare()
      return m
    end
    it("carries over settings the player changed", function()
      local m = migrated({
        enable = false,
        rest_threshold = 35,
        include_party = false
      })
      assert.is_false(m.db.enable)
      assert.are.equal(35, m.db.rest_threshold)
      return assert.is_false(m.db.include_party)
    end)
    it("does NOT carry over the icon settings, which no longer mean anything", function()
      local m = migrated({
        icon_point = {
          point = "TOPLEFT"
        },
        show_icon = false
      })
      assert.is_nil(m.db.icon_point)
      return assert.is_nil(m.db.show_icon)
    end)
    it("carries over a hunter's remembered pet death", function()
      return assert.is_true((migrated({
        petDead = true
      })).db.petDead)
    end)
    it("migrates only once, so later changes here are not overwritten", function()
      local m = migrated({
        rest_threshold = 35
      })
      m.db.rest_threshold = 50
      assert.is_false(m:migrateFromPrepare())
      return assert.are.equal(50, m.db.rest_threshold)
    end)
    it("does nothing when there was no Prepare", function()
      local m = Upkeep(Node(nil, Boot.next_key()), "Upkeep")
      m.db.migrated_from_prepare = nil
      m.database.Get = function()
        return nil
      end
      assert.is_false(m:migrateFromPrepare())
      return assert.is_true(m.db.enable)
    end)
    it("survives a database that errors rather than failing to load", function()
      local m = Upkeep(Node(nil, Boot.next_key()), "Upkeep")
      m.db.migrated_from_prepare = nil
      m.database.Get = function()
        return error("boom")
      end
      return assert.has_no.errors(function()
        return m:migrateFromPrepare()
      end)
    end)
    return it("leaves the old table alone, so a downgrade still finds it", function()
      local old = {
        enable = false,
        rest_threshold = 35
      }
      migrated(old)
      return assert.are.same({
        enable = false,
        rest_threshold = 35
      }, old)
    end)
  end)
  describe("the three buttons", function()
    it("creates one secure button per job, named for binding", function()
      local m = enabled()
      for job, name in pairs(BUTTON_NAMES) do
        assert.is_not_nil(m.buttons[job], job)
        assert.are.equal(name, m.buttons[job]:GetName())
        assert.are.equal("SecureActionButtonTemplate", m.buttons[job]._template)
      end
    end)
    it("acts on the release, so a plain /click fires it", function()
      local m = enabled()
      return assert.is_false(m.buttons.buffs._attrs.useOnKeyDown)
    end)
    it("names every button in the Key Bindings UI", function()
      enabled()
      for _, name in pairs(BUTTON_NAMES) do
        assert.is_string(_G["BINDING_NAME_CLICK " .. tostring(name) .. ":LeftButton"])
      end
    end)
    return it("reuses its frames across disable and enable", function()
      local m = enabled()
      local first = m.buttons.buffs
      m:disable()
      m:enable()
      return assert.are.equal(first, m.buttons.buffs)
    end)
  end)
  describe("the three macros", function()
    local macroApi, created, edited
    local fakeApi
    fakeApi = function(existing)
      if existing == nil then
        existing = { }
      end
      created, edited = { }, { }
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
      macroApi = {
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
        end,
        createMacro = function(name, icon, body)
          macros[#macros + 1] = {
            name = name,
            body = body
          }
          created[name] = body
          return #macros
        end,
        editMacro = function(index, name, icon, body)
          macros[index] = {
            name = name,
            body = body
          }
          edited[name] = body
          return index
        end
      }
      return macroApi
    end
    before_each(function()
      local Macros = _G.idUpkeep_UpkeepMacros
      Macros.liveApi = function()
        return macroApi
      end
    end)
    it("creates one macro per button", function()
      fakeApi()
      enabled()
      assert.is_truthy(created["Upkeep Buffs"]:find("/click idUpkeepBuffsButton", 1, true))
      local _list_0 = {
        "Upkeep Health",
        "Upkeep Mana"
      }
      for _index_0 = 1, #_list_0 do
        local name = _list_0[_index_0]
        assert.is_truthy(created[name], name)
        assert.is_nil(created[name]:find("/click", 1, true))
      end
    end)
    it("does not duplicate them on a second enable", function()
      fakeApi()
      local m = enabled()
      created = { }
      m:disable()
      m:enable()
      return assert.are.same({ }, created)
    end)
    it("leaves a macro the player extended alone", function()
      fakeApi({
        ["Upkeep Health"] = "#showtooltip\n/use Bread\n/say yum"
      })
      enabled()
      assert.is_nil(created["Upkeep Health"])
      return assert.is_nil(edited["Upkeep Health"])
    end)
    it("repairs the broken /click body an earlier version wrote", function()
      fakeApi({
        ["Upkeep Health"] = "#showtooltip\n/click idUpkeepHealthButton"
      })
      enabled()
      assert.is_truthy(edited["Upkeep Health"])
      return assert.is_nil(edited["Upkeep Health"]:find("/click", 1, true))
    end)
    it("repairs a macro that points somewhere else entirely", function()
      fakeApi({
        ["Upkeep Health"] = "/click somethingElse"
      })
      enabled()
      assert.is_truthy(edited["Upkeep Health"])
      return assert.is_nil(edited["Upkeep Health"]:find("somethingElse", 1, true))
    end)
    it("does not create macros when the player turns that off", function()
      fakeApi()
      local m = newModule()
      m.db.create_macros = false
      m:enable()
      return assert.are.same({ }, created)
    end)
    it("creates them when the player turns it back on", function()
      fakeApi()
      local m = newModule()
      m.db.create_macros = false
      m:enable()
      m.db.create_macros = true
      m:afterSettingsBool("create_macros", true)
      return assert.is_truthy(created["Upkeep Mana"])
    end)
    it("writes NO macro while in combat, and catches up afterwards", function()
      fakeApi()
      inCombat = true
      local m = newModule()
      m:enable()
      assert.are.same({ }, created)
      inCombat = false
      m:onCombatEnd()
      return assert.is_truthy(created["Upkeep Buffs"]:find("/click idUpkeepBuffsButton", 1, true))
    end)
    it("records what happened to each one, for /upkeep", function()
      fakeApi()
      local m = enabled()
      assert.is_true(m.macroState.health == "kept" or m.macroState.health == "created")
      return assert.is_truthy(created["Upkeep Health"])
    end)
    it("shows AND uses the item a press would consume", function()
      fakeApi()
      local m = enabled()
      edited = { }
      m.steps.health = {
        kind = "macro",
        showHint = "[combat] item:13446; item:8950",
        useHint = "[combat] Healing Potion; Bread"
      }
      m:retuneMacros()
      local expected = "#showtooltip [combat] item:13446; item:8950\n" .. "/use [combat] Healing Potion; Bread"
      assert.are.equal(expected, edited["Upkeep Health"])
      return assert.are.equal("retuned", m.macroState.health)
    end)
    it("does not rewrite macros in combat, where the API is blocked", function()
      fakeApi()
      local m = enabled()
      edited = { }
      inCombat = true
      m.steps.buffs = {
        kind = "spell",
        spell = "Fortitude"
      }
      m:retuneMacros()
      return assert.are.same({ }, edited)
    end)
    return it("survives a client with no macro API at all", function()
      macroApi = { }
      return assert.has_no.errors(function()
        return enabled()
      end)
    end)
  end)
  describe("combat discipline", function()
    it("writes NO attribute while in combat", function()
      local m = enabled()
      inCombat = true
      attrWrites = { }
      m:update()
      m:applyStep("buffs", {
        kind = "spell",
        spell = "Fortitude"
      })
      m:clearAttributes()
      m:onCombatStart()
      for _index_0 = 1, #attrWrites do
        local w = attrWrites[_index_0]
        assert.is_false(w.inCombat, ("wrote %s on %s during combat"):format(w.attr, tostring(w.name)))
      end
      assert.are.equal(0, #attrWrites)
      inCombat = false
      m:applyStep("buffs", {
        kind = "spell",
        spell = "Fortitude"
      })
      return assert.is_true(#attrWrites > 0)
    end)
    it("clears the buffs button when combat starts", function()
      local m = enabled()
      m:applyStep("buffs", {
        kind = "spell",
        spell = "Fortitude"
      })
      assert.are.equal("spell", (attrsOf(m, "buffs")).type)
      m:onCombatStart()
      assert.is_nil((attrsOf(m, "buffs")).type)
      return assert.are.equal("in combat", m.reasons.buffs)
    end)
    it("LEAVES health and mana armed when combat starts", function()
      local m = enabled()
      local macro = {
        kind = "macro",
        macrotext = "/use [combat] item:7007; item:7003"
      }
      m:applyStep("health", macro)
      m:applyStep("mana", macro)
      m:onCombatStart()
      assert.are.equal("macro", (attrsOf(m, "health")).type)
      assert.are.equal("macro", (attrsOf(m, "mana")).type)
      return assert.are.equal(macro.macrotext, (attrsOf(m, "health")).macrotext)
    end)
    it("recomputes when combat ends", function()
      local m = enabled()
      local calls = 0
      m.update = function()
        calls = calls + 1
      end
      m:onCombatEnd()
      return assert.are.equal(1, calls)
    end)
    return it("does nothing on combat events while disabled", function()
      local m = enabled()
      m:disable()
      local calls = 0
      m.update = function()
        calls = calls + 1
      end
      m:onCombatEnd()
      return assert.are.equal(0, calls)
    end)
  end)
  describe("applying steps", function()
    it("writes a buff step onto the buffs button only", function()
      local m = enabled()
      m:applyStep("buffs", {
        kind = "spell",
        spell = "Fortitude",
        unit = "party1"
      })
      assert.are.equal("Fortitude", (attrsOf(m, "buffs")).spell)
      assert.are.equal("party1", (attrsOf(m, "buffs")).unit)
      return assert.is_nil((attrsOf(m, "health")).spell)
    end)
    it("clears a button when its step is nil", function()
      local m = enabled()
      m:applyStep("buffs", {
        kind = "spell",
        spell = "Fortitude"
      })
      m:applyStep("buffs", nil)
      return assert.is_nil((attrsOf(m, "buffs")).type)
    end)
    return it("writes nothing once disabled, even if asked", function()
      local m = enabled()
      m:disable()
      m:applyStep("buffs", {
        kind = "spell",
        spell = "Fortitude"
      })
      return assert.is_nil((attrsOf(m, "buffs")).type)
    end)
  end)
  describe("presses", function()
    it("remembers what was pressed, so a double press cannot repeat it", function()
      local m = enabled()
      m.steps.health = {
        key = "sustain:health:x"
      }
      m:onPostClick("health")
      return assert.are.equal(now, m.recent["sustain:health:x"])
    end)
    it("survives a press with no step computed", function()
      local m = enabled()
      m.steps.health = nil
      return assert.has_no.errors(function()
        return m:onPostClick("health")
      end)
    end)
    it("passes the suppressed keys to the engine", function()
      local m = enabled()
      m.recent = {
        ["spell:123"] = now
      }
      return assert.is_true(m:engineOpts("buffs").recent["spell:123"])
    end)
    return it("forgets a suppression once its window has passed", function()
      local m = enabled()
      m.recent = {
        ["spell:123"] = now
      }
      now = now + 5
      return assert.is_nil(m:engineOpts("buffs").recent["spell:123"])
    end)
  end)
  describe("engine options", function()
    it("asks the engine only for buff phases", function()
      return assert.are.equal("buffs", enabled():engineOpts("buffs").phases)
    end)
    it("passes the player's settings through", function()
      local m = enabled()
      m.db.include_party = false
      m.db.use_consumables = false
      m.db.rest_threshold = 35
      local opts = m:engineOpts("buffs")
      assert.is_false(opts.includeParty)
      assert.is_false(opts.useConsumables)
      return assert.are.equal(35, opts.restThreshold)
    end)
    return it("defaults a missing threshold rather than passing nil", function()
      local m = enabled()
      m.db.rest_threshold = nil
      return assert.are.equal(80, m:engineOpts("buffs").restThreshold)
    end)
  end)
  describe("degrading", function()
    it("reports a reason per button when the engine is not loaded", function()
      local m = enabled()
      local saved = _G.idUpkeep_UpkeepSnapshot
      _G.idUpkeep_UpkeepSnapshot = nil
      m:update()
      _G.idUpkeep_UpkeepSnapshot = saved
      assert.is_truthy(m.reasons.buffs)
      return assert.is_truthy(m.reasons.health)
    end)
    return it("clears the buttons rather than leaving a stale action", function()
      local m = enabled()
      m:applyStep("buffs", {
        kind = "spell",
        spell = "Fortitude"
      })
      local saved = _G.idUpkeep_UpkeepSnapshot
      _G.idUpkeep_UpkeepSnapshot = nil
      m:update()
      _G.idUpkeep_UpkeepSnapshot = saved
      return assert.is_nil((attrsOf(m, "buffs")).type)
    end)
  end)
  describe("explaining itself", function()
    it("registers NO slash command of its own", function()
      local m = enabled()
      assert.is_nil(_G.SLASH_IDUPKEEPUPKEEP1)
      return assert.is_nil((_G.SlashCmdList or { }).IDUPKEEPUPKEEP)
    end)
    it("explains all three buttons", function()
      local m = enabled()
      local text = table.concat(m:explainLines(), "\n")
      assert.is_truthy(text:find("Buffs:", 1, true))
      assert.is_truthy(text:find("HEALTH:", 1, true))
      assert.is_truthy(text:find("MANA:", 1, true))
      return assert.is_truthy(text:find("MACROS:", 1, true))
    end)
    return it("says it is disabled rather than explaining nothing", function()
      local m = newModule()
      return assert.is_truthy((table.concat(m:explainLines(), "\n")):find("disabled", 1, true))
    end)
  end)
  return describe("spell source reporting", function()
    it("reports the class-table source when no generated data is loaded", function()
      local m = enabled()
      local saved = _G.LibStub
      _G.LibStub = nil
      local list, source = m:spellSource("Spell.Buff.Self", "MAGE")
      _G.LibStub = saved
      assert.are.equal("class-table", source)
      return assert.is_true(#list > 0)
    end)
    return it("degrades to `none` when the resolver itself is missing", function()
      local m = enabled()
      local saved = _G.idUpkeep_UpkeepSpells
      _G.idUpkeep_UpkeepSpells = nil
      local list, source, canFallBack = m:spellSource("Spell.Buff.Self", "MAGE")
      _G.idUpkeep_UpkeepSpells = saved
      assert.are.same({ }, list)
      assert.are.equal("none", source)
      return assert.is_false(canFallBack)
    end)
  end)
end)
