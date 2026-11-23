local tonumber
tonumber = function(v)
  return _G.tonumber(v)
end
local Logger = _G.idUpkeep_Logger
local Frame = _G.idUpkeep_Frame
local CombatLockdownCommand = _G.idUpkeep_CombatLockdownCommand
local tostring = _G.tostring
local BUTTONS = {
  {
    job = "buffs",
    name = "idUpkeepBuffsButton",
    label = "Upkeep: next buff"
  },
  {
    job = "health",
    name = "idUpkeepHealthButton",
    label = "Upkeep: health"
  },
  {
    job = "mana",
    name = "idUpkeepManaButton",
    label = "Upkeep: mana"
  }
}
local CLEARED_IN_COMBAT = {
  buffs = true
}
local UPDATE_DELAY = 0.25
local RECENT_WINDOW = 1.5
local WATCHED_UNITS = {
  player = true,
  pet = true,
  party1 = true,
  party2 = true,
  party3 = true,
  party4 = true
}
local MIGRATED_SETTINGS = {
  enable = "enable",
  rest_threshold = "rest_threshold",
  include_party = "include_party",
  use_consumables = "use_consumables",
  petDead = "petDead"
}
local MIGRATION_MARKER = "migrated_from_prepare"
local PLAIN_EVENTS = {
  "BAG_UPDATE_DELAYED",
  "GROUP_ROSTER_UPDATE",
  "SPELLS_CHANGED",
  "LEARNED_SPELL_IN_TAB",
  "PLAYER_LEVEL_UP",
  "ZONE_CHANGED_NEW_AREA",
  "PLAYER_ENTERING_WORLD"
}
local PLAYER_UNIT_EVENTS = {
  "UNIT_POWER_UPDATE",
  "UNIT_HEALTH",
  "UNIT_INVENTORY_CHANGED",
  "UNIT_PET",
  "UNIT_SPELLCAST_START",
  "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_SUCCEEDED",
  "UNIT_SPELLCAST_FAILED",
  "UNIT_SPELLCAST_CHANNEL_START",
  "UNIT_SPELLCAST_CHANNEL_STOP"
}
_G.BINDING_HEADER_IDUPKEEP = _G.BINDING_HEADER_IDUPKEEP or "idUpkeep"
for _index_0 = 1, #BUTTONS do
  local spec = BUTTONS[_index_0]
  _G["BINDING_NAME_CLICK " .. tostring(spec.name) .. ":LeftButton"] = spec.label
end
local Upkeep
do
  local _class_0
  local _parent_0 = _G.idUpkeep_Node
  local _base_0 = {
    name = "Upkeep",
    combatSensitive = true,
    defaults = {
      enable = true,
      create_macros = true,
      include_party = true,
      use_consumables = true,
      rest_threshold = 80
    },
    options = {
      {
        variable = "enable",
        name = "Enable Upkeep",
        tooltip = "Three keys: buffs (out of combat), health and mana (any time). Bind them under Key Bindings > idUpkeep.",
        position = 1
      },
      {
        variable = "create_macros",
        name = "Create macros",
        tooltip = "Keep three macros (Upkeep Buffs / Health / Mana) that press the three buttons, so they can be dragged onto an action bar.",
        position = 2
      },
      {
        variable = "include_party",
        name = "Buff party members",
        tooltip = "Also buff party members (in range, alive, visible), one per press.",
        position = 3
      },
      {
        variable = "use_consumables",
        name = "Use consumables",
        tooltip = "Use the best elixirs, flasks, scrolls and buff food in your bags when their effect is missing.",
        position = 4
      },
      {
        type = "slider",
        variable = "rest_threshold",
        name = "Eat/drink below (%)",
        tooltip = "Offer food or water when health or mana is below this percentage.",
        position = 5,
        min = 0,
        max = 100,
        step = 5
      }
    },
    migrateFromPrepare = function(self)
      if not (self.db and self.database and self.database.Get) then
        return false
      end
      if self.db[MIGRATION_MARKER] then
        return false
      end
      self.db[MIGRATION_MARKER] = true
      local ok, old = pcall(self.database.Get, self.database, "character.Prepare")
      if not (ok and _G.type(old) == "table") then
        return false
      end
      local moved = 0
      for oldKey, newKey in pairs(MIGRATED_SETTINGS) do
        local _continue_0 = false
        repeat
          local value = old[oldKey]
          if value == nil then
            _continue_0 = true
            break
          end
          if self.db[newKey] == value then
            _continue_0 = true
            break
          end
          self.db[newKey] = value
          moved = moved + 1
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      if self.logger then
        self.logger:debug("Upkeep:migrateFromPrepare:" .. tostring(moved))
      end
      return moved > 0
    end,
    onEnable = function(self)
      self.logger:debug("Upkeep:onEnable")
      self:ensureFrames()
      self.eventManager:subscribe(self, "UNIT_AURA", function(_, unit)
        if WATCHED_UNITS[unit] then
          return self:requestUpdate()
        end
      end)
      for _index_0 = 1, #PLAIN_EVENTS do
        local event = PLAIN_EVENTS[_index_0]
        self.eventManager:subscribe(self, event, function()
          return self:requestUpdate()
        end)
      end
      for _index_0 = 1, #PLAYER_UNIT_EVENTS do
        local event = PLAYER_UNIT_EVENTS[_index_0]
        self.eventManager:subscribe(self, event, function(...)
          return self:onUnitEvent(event, select(2, ...))
        end)
      end
      self.eventManager:subscribe(self, "UI_ERROR_MESSAGE", function(_, ...)
        return self:onUIError(...)
      end)
      self.eventManager:subscribe(self, "PLAYER_REGEN_DISABLED", function()
        return self:onCombatStart()
      end)
      self.eventManager:subscribe(self, "PLAYER_REGEN_ENABLED", function()
        return self:onCombatEnd()
      end)
      self:ensureMacros()
      return self:update()
    end,
    onDisable = function(self)
      self.logger:debug("Upkeep:onDisable")
      self.updateToken = self.updateToken + 1
      self.updatePending = false
      self.steps, self.reasons = { }, { }
      self.recent = { }
      return self:clearAttributes()
    end,
    afterSettingsBool = function(self, var, _value)
      if not (self.active) then
        return 
      end
      if var == "create_macros" then
        return self:ensureMacros()
      elseif var == "include_party" or var == "use_consumables" then
        return self:requestUpdate()
      end
    end,
    afterSettingsNumber = function(self, var, _value)
      if not (self.active) then
        return 
      end
      if var == "rest_threshold" then
        return self:requestUpdate()
      end
    end,
    ensureFrames = function(self)
      for _index_0 = 1, #BUTTONS do
        local _continue_0 = false
        repeat
          local spec = BUTTONS[_index_0]
          if self.buttons[spec.job] then
            _continue_0 = true
            break
          end
          local btn = (Frame.create("Button", spec.name, _G.UIParent, "SecureActionButtonTemplate")).raw
          if btn.RegisterForClicks then
            btn:RegisterForClicks("AnyUp", "AnyDown")
          end
          btn:SetAttribute("useOnKeyDown", false)
          if btn.SetSize then
            btn:SetSize(1, 1)
          end
          if btn.Hide then
            btn:Hide()
          end
          local job = spec.job
          btn:SetScript("PostClick", function()
            return self:onPostClick(job)
          end)
          self.buttons[job] = btn
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
    end,
    targetsFor = function(self, job)
      local btn = self.buttons[job]
      if not (btn) then
        return { }
      end
      return {
        {
          btn,
          ""
        }
      }
    end,
    ensureMacros = function(self)
      local Macros = _G.idUpkeep_UpkeepMacros
      if not (Macros) then
        return 
      end
      if not (self.active and self.db and self.db.create_macros ~= false) then
        return 
      end
      self.pending_macros = false
      return CombatLockdownCommand.execute((function()
        local hints, uses = self:macroHints()
        local results, problems = Macros.ensure(Macros.liveApi(), hints, uses)
        self.macroState = results
        local _list_0 = problems
        for _index_0 = 1, #_list_0 do
          local p = _list_0[_index_0]
          self.logger:debug("Upkeep:ensureMacros:" .. tostring(p))
        end
      end), {
        owner = self,
        flag = "pending_macros"
      })
    end,
    macroHints = function(self)
      local Macros = _G.idUpkeep_UpkeepMacros
      local hints, uses = { }, { }
      if not (Macros and Macros.hintForStep) then
        return hints, uses
      end
      for _index_0 = 1, #BUTTONS do
        local spec = BUTTONS[_index_0]
        local step = self.steps[spec.job]
        hints[spec.job] = Macros.hintForStep(step)
        uses[spec.job] = Macros.useForStep(step)
      end
      return hints, uses
    end,
    retuneMacros = function(self)
      if CombatLockdownCommand.locked() then
        return 
      end
      return self:ensureMacros()
    end,
    engineOpts = function(self, phases)
      local now = (_G.GetTime and _G.GetTime()) or 0
      local recentKeys = { }
      for key, at in pairs(self.recent) do
        if now - at < RECENT_WINDOW then
          recentKeys[key] = true
        else
          self.recent[key] = nil
        end
      end
      return {
        restThreshold = tonumber(self.db.rest_threshold) or 80,
        includeParty = self.db.include_party ~= false,
        useConsumables = self.db.use_consumables ~= false,
        recent = recentKeys,
        phases = phases
      }
    end,
    buildSnapshot = function(self)
      local Snapshot = _G.idUpkeep_UpkeepSnapshot
      local Rules = _G.idUpkeep_UpkeepRules
      if not (Snapshot and Rules) then
        return nil, nil, "upkeep engine not loaded"
      end
      local classRules = Rules.forClass(Snapshot.classToken())
      local ok, snap = pcall(Snapshot.build, classRules, {
        petDead = self.db and self.db.petDead == true
      })
      if not (ok) then
        return nil, nil, "snapshot failed: " .. tostring(tostring(snap))
      end
      return snap, classRules, nil
    end,
    sustainCtx = function(self, snap)
      local Consumables = _G.idUpkeep_UpkeepConsumables
      if not (Consumables) then
        return { }
      end
      return {
        lib = Consumables.lib(),
        usable = function(id)
          return snap.itemInfo and snap.itemInfo[id] and snap.itemInfo[id].usable
        end,
        itemName = function(id)
          return self:itemName(id)
        end
      }
    end,
    itemName = function(self, id)
      if not (id) then
        return nil
      end
      local Snapshot = _G.idUpkeep_UpkeepSnapshot
      local C = _G.C_Item
      local getter = (C and C.GetItemInfo) or _G.GetItemInfo
      if not (getter) then
        return nil
      end
      local ok, name = pcall(getter, id)
      if not (ok and _G.type(name) == "string") then
        return nil
      end
      if Snapshot and Snapshot.isSecret and Snapshot.isSecret(name) then
        return nil
      end
      return name
    end,
    stepFor = function(self, job, snap, classRules)
      if job == "buffs" then
        local Engine = _G.idUpkeep_UpkeepEngine
        if not (Engine) then
          return nil, "upkeep engine not loaded"
        end
        local ok, step, reason = pcall(Engine.nextStep, snap, classRules, self:engineOpts("buffs"))
        if not (ok) then
          return nil, "engine failed: " .. tostring(tostring(step))
        end
        return step, reason
      end
      local Sustain = _G.idUpkeep_UpkeepSustain
      if not (Sustain) then
        return nil, "upkeep sustain not loaded"
      end
      local ok, step, reason = pcall(Sustain.step, job, snap.items, self:sustainCtx(snap))
      if not (ok) then
        return nil, "sustain failed: " .. tostring(tostring(step))
      end
      return step, reason
    end,
    update = function(self)
      if not (self.active) then
        return 
      end
      self.updatePending = false
      if CombatLockdownCommand.locked() then
        return 
      end
      local snap, classRules, err = self:buildSnapshot()
      if not (snap) then
        self.steps = { }
        for _index_0 = 1, #BUTTONS do
          local spec = BUTTONS[_index_0]
          self.reasons[spec.job] = err
        end
        self:clearAttributes()
        return 
      end
      self:trackPet()
      for _index_0 = 1, #BUTTONS do
        local spec = BUTTONS[_index_0]
        local step, reason = self:stepFor(spec.job, snap, classRules)
        self.steps[spec.job] = step
        self.reasons[spec.job] = reason
        self:applyStep(spec.job, step)
      end
      return self:retuneMacros()
    end,
    requestUpdate = function(self)
      if not (self.active) then
        return 
      end
      if self.updatePending then
        return 
      end
      local after = _G.C_Timer and _G.C_Timer.After
      if not (after) then
        self:update()
        return 
      end
      self.updatePending = true
      local token = self.updateToken
      return after(UPDATE_DELAY, function()
        if not (token == self.updateToken) then
          return 
        end
        return self:update()
      end)
    end,
    applyStep = function(self, job, step)
      local Button = _G.idUpkeep_UpkeepButton
      if not (Button) then
        return 
      end
      local targets = self:targetsFor(job)
      local active = self.active
      return CombatLockdownCommand.execute(function()
        return Button.writeAll(targets, (active and step or nil))
      end)
    end,
    clearAttributes = function(self, jobs)
      local Button = _G.idUpkeep_UpkeepButton
      if not (Button) then
        return 
      end
      for _index_0 = 1, #BUTTONS do
        local _continue_0 = false
        repeat
          local spec = BUTTONS[_index_0]
          if jobs and not jobs[spec.job] then
            _continue_0 = true
            break
          end
          local targets = self:targetsFor(spec.job)
          CombatLockdownCommand.execute(function()
            return Button.writeAll(targets, nil)
          end)
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
    end,
    onCombatStart = function(self)
      if not (self.active) then
        return 
      end
      self.updateToken = self.updateToken + 1
      self.updatePending = false
      for _index_0 = 1, #BUTTONS do
        local spec = BUTTONS[_index_0]
        if CLEARED_IN_COMBAT[spec.job] then
          self.steps[spec.job] = nil
          self.reasons[spec.job] = "in combat"
        end
      end
      return self:clearAttributes(CLEARED_IN_COMBAT)
    end,
    onCombatEnd = function(self)
      if not (self.active) then
        return 
      end
      if self.pending_macros then
        self:ensureMacros()
      end
      return self:update()
    end,
    onPostClick = function(self, job)
      if not (self.active) then
        return 
      end
      local step = self.steps[job]
      if step and step.key then
        self.recent[step.key] = (_G.GetTime and _G.GetTime()) or 0
      end
      self:requestUpdate()
      local after = _G.C_Timer and _G.C_Timer.After
      if after then
        local token = self.updateToken
        return after(RECENT_WINDOW + 0.05, function()
          if token == self.updateToken then
            return self:requestUpdate()
          end
        end)
      end
    end,
    onUnitEvent = function(self, event, unit, ...)
      if not (self.active) then
        return 
      end
      if unit == "player" then
        if event == "UNIT_PET" then
          self:trackPet()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_FAILED" then
          local _, spellId = ...
          local PetDeath = _G.idUpkeep_UpkeepPetDeath
          if PetDeath and self:isHunter() then
            PetDeath.onReviveResult(self.db, spellId)
          end
        end
        return self:requestUpdate()
      elseif unit == "pet" and event == "UNIT_HEALTH" then
        if self:trackPet() then
          return self:requestUpdate()
        end
      end
    end,
    isHunter = function(self)
      local Snapshot = _G.idUpkeep_UpkeepSnapshot
      return (Snapshot and Snapshot.classToken()) == "HUNTER"
    end,
    trackPet = function(self)
      local PetDeath = _G.idUpkeep_UpkeepPetDeath
      if not (PetDeath and self:isHunter()) then
        return false
      end
      local Snapshot = _G.idUpkeep_UpkeepSnapshot
      return PetDeath.track(self.db, (Snapshot and Snapshot.isSecret))
    end,
    onUIError = function(self, ...)
      if not (self.active and self:isHunter()) then
        return 
      end
      local PetDeath = _G.idUpkeep_UpkeepPetDeath
      if not (PetDeath) then
        return 
      end
      if PetDeath.onError(self.db, ...) then
        return self:requestUpdate()
      end
    end,
    spellSource = function(self, set, classToken)
      local Spells = _G.idUpkeep_UpkeepSpells
      if not (Spells) then
        return { }, "none", false
      end
      return Spells.resolve(set, classToken)
    end,
    explainLines = function(self)
      if not (self.active) then
        return {
          "Upkeep is disabled (enable it in /idautomation)."
        }
      end
      local lines = { }
      local snap, classRules, err = self:buildSnapshot()
      if not (snap) then
        return {
          "Upkeep cannot compute: " .. tostring(tostring(err))
        }
      end
      local Engine = _G.idUpkeep_UpkeepEngine
      if Engine then
        lines[#lines + 1] = "Buffs:"
        local _list_0 = Engine.explain(snap, classRules, self:engineOpts("buffs"))
        for _index_0 = 1, #_list_0 do
          local e = _list_0[_index_0]
          lines[#lines + 1] = "  " .. Engine.formatEntry(e)
        end
      end
      local buffStep = self.steps.buffs
      if buffStep then
        lines[#lines + 1] = "  Next: " .. tostring(buffStep.label) .. " (" .. tostring(buffStep.phase) .. ": " .. tostring(buffStep.reason) .. ")"
      else
        lines[#lines + 1] = "  Next: nothing (" .. tostring(tostring(self.reasons.buffs)) .. ")"
      end
      local Sustain = _G.idUpkeep_UpkeepSustain
      if Sustain then
        local ctx = self:sustainCtx(snap)
        local _list_0 = {
          "health",
          "mana"
        }
        for _index_0 = 1, #_list_0 do
          local job = _list_0[_index_0]
          lines[#lines + 1] = tostring(job:upper()) .. ":"
          local _list_1 = Sustain.explain(job, snap.items, ctx)
          for _index_1 = 1, #_list_1 do
            local line = _list_1[_index_1]
            lines[#lines + 1] = "  " .. line
          end
        end
      end
      local Macros = _G.idUpkeep_UpkeepMacros
      if Macros then
        lines[#lines + 1] = "MACROS:"
        local hints, uses = self:macroHints()
        local _list_0 = Macros.describe(Macros.liveApi(), hints, uses)
        for _index_0 = 1, #_list_0 do
          local line = _list_0[_index_0]
          lines[#lines + 1] = "  " .. line
        end
      end
      return lines
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, parent, key)
      _class_0.__parent.__init(self, parent, key)
      self.logger = Logger:getInstance()
      self.buttons = { }
      self.steps = { }
      self.reasons = { }
      self.updateToken = 0
      self.updatePending = false
      self.recent = { }
      self.macroState = { }
      self:migrateFromPrepare()
      return self.logger:debug("Upkeep:new")
    end,
    __base = _base_0,
    __name = "Upkeep",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Upkeep = _class_0
end
Upkeep.BUTTONS = BUTTONS
_G.idUpkeep_Upkeep = Upkeep
return Upkeep
