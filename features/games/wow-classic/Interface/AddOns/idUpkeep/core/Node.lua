local Database = _G.idUpkeep_Database
local EventManager = _G.idUpkeep_EventManager
local HookManager = _G.idUpkeep_HookManager
local Logger = _G.idUpkeep_Logger
local Node
do
  local _class_0
  local _parent_0 = _G.idUpkeep_Graph
  local _base_0 = {
    db = nil,
    defaults = {
      enable = true
    },
    options = { },
    bindCharacterDb = function(self)
      if self.database.ensureCharacterContext then
        self.database:ensureCharacterContext()
      end
      local path
      if self:isRoot() then
        path = "character"
      else
        path = "character." .. tostring(self.key)
      end
      self.db = self.database:Get(path)
      if not (self.db) then
        self.database:Set(path, { })
        self.db = self.database:Get(path)
      end
      if self.defaults and self.db then
        self.logger:debug("Node:bindCharacterDb:merging-defaults")
        self.database:mergeDefaults(self.db, self.defaults)
        return self.database:Set(path, self.db)
      end
    end,
    initialize = function(self)
      self.logger:debug("Node:initialize")
      self:bindCharacterDb()
      if not (self.db and self.db.enable) then
        return 
      end
      for _, child in pairs(self.children) do
        child:initialize()
      end
    end,
    onEnable = function(self) end,
    onDisable = function(self) end,
    active = false,
    dependsOn = nil,
    combatSensitive = false,
    wantsActive = function(self)
      if not (self.db and self.db.enable) then
        return false
      end
      if self.dependsOn then
        local modules = self.addon and self.addon.modules
        local _list_0 = self.dependsOn
        for _index_0 = 1, #_list_0 do
          local key = _list_0[_index_0]
          local dep = modules and modules[key]
          if not (dep and dep.active and dep:wantsActive()) then
            return false
          end
        end
      end
      return true
    end,
    enable = function(self)
      self.logger:debug("Node:enable")
      if self.active then
        return 
      end
      if not (self:wantsActive()) then
        return 
      end
      self.active = true
      self:syncChildren()
      return self:onEnable()
    end,
    disable = function(self)
      self.logger:debug("Node:disable")
      if not (self.active) then
        return 
      end
      self.active = false
      self.eventManager:unsubscribeAll(self)
      self.hookManager:unhookAllForOwner(self)
      local _list_0 = self:orderedChildren(true)
      for _index_0 = 1, #_list_0 do
        local child = _list_0[_index_0]
        child:disable()
      end
      return self:onDisable()
    end,
    safeDisable = function(self)
      local ok, err = pcall(function()
        return self:disable()
      end)
      if not (ok) then
        self.logger:error("Node:safeDisable " .. tostring(self.key) .. " failed: " .. tostring(tostring(err)))
        local handler = _G.geterrorhandler and _G.geterrorhandler()
        if handler then
          handler(err)
        end
      end
      return ok
    end,
    syncEnabled = function(self)
      local want = self:wantsActive()
      if want == self.active then
        return 
      end
      local InCombatLockdown = _G.InCombatLockdown
      if self.combatSensitive and InCombatLockdown and InCombatLockdown() then
        self.logger:debug("Node:syncEnabled " .. tostring(self.key) .. " deferred (combat)")
        if self.addon and self.addon.deferSync then
          self.addon:deferSync()
        end
        return 
      end
      local ok, err = pcall(function()
        if want then
          return self:enable()
        else
          return self:disable()
        end
      end)
      if not (ok) then
        self.logger:error("Node:syncEnabled " .. tostring(self.key) .. " failed: " .. tostring(tostring(err)))
        pcall(function()
          if want and self.active then
            return self:disable()
          end
        end)
        local handler = _G.geterrorhandler and _G.geterrorhandler()
        if handler then
          return handler(err)
        end
      end
    end,
    orderedChildren = function(self, reverse)
      local list
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _, child in pairs(self.children) do
          _accum_0[_len_0] = child
          _len_0 = _len_0 + 1
        end
        list = _accum_0
      end
      table.sort(list, function(a, b)
        local da = a.dependsOn and 1 or 0
        local db = b.dependsOn and 1 or 0
        if da ~= db then
          return da < db
        end
        return tostring(a.key) < tostring(b.key)
      end)
      if reverse then
        do
          local _accum_0 = { }
          local _len_0 = 1
          for i = #list, 1, -1 do
            _accum_0[_len_0] = list[i]
            _len_0 = _len_0 + 1
          end
          list = _accum_0
        end
      end
      return list
    end,
    syncChildren = function(self)
      if not (self.active) then
        return 
      end
      local _list_0 = self:orderedChildren(true)
      for _index_0 = 1, #_list_0 do
        local child = _list_0[_index_0]
        if child.active and not child:wantsActive() then
          child:syncEnabled()
        end
      end
      local _list_1 = self:orderedChildren()
      for _index_0 = 1, #_list_1 do
        local child = _list_1[_index_0]
        if not child.active and child:wantsActive() then
          child:syncEnabled()
        elseif child.active and child.syncChildren then
          child:syncChildren()
        end
      end
    end,
    setEnabled = function(self, value)
      value = value == true
      if self.db then
        self.db.enable = value
      end
      if not self:isRoot() and self.database and self.database.set then
        self.database:set("character." .. tostring(self.key) .. ".enable", value)
      end
      local root = self.addon or self
      if root ~= self and root.active and root.syncChildren then
        return root:syncChildren()
      else
        return self:syncEnabled()
      end
    end,
    savedCVarStore = function(self)
      local account = self.database and self.database:get("account")
      if not (account) then
        return nil
      end
      account.savedCVars = account.savedCVars or { }
      return account.savedCVars
    end,
    saveCVar = function(self, name)
      local store = self:savedCVarStore()
      if not (store and _G.GetCVar) then
        return 
      end
      if store[name] ~= nil then
        return 
      end
      local value = _G.GetCVar(name)
      if value ~= nil then
        store[name] = value
      end
    end,
    restoreCVar = function(self, name)
      local store = self:savedCVarStore()
      if not (store and store[name] ~= nil) then
        return 
      end
      local original = store[name]
      store[name] = nil
      if not (_G.SetCVar) then
        return 
      end
      local current = _G.GetCVar and _G.GetCVar(name)
      if current ~= original then
        return _G.SetCVar(name, original)
      end
    end,
    deferSync = function(self)
      if self.pendingSync then
        return 
      end
      self.pendingSync = true
      return self.eventManager:subscribe(self, "PLAYER_REGEN_ENABLED", function()
        self.eventManager:unsubscribe(self, "PLAYER_REGEN_ENABLED")
        self.pendingSync = false
        return self:syncChildren()
      end)
    end,
    getOptions = function(self)
      self.logger:debug("Node:getOptions")
      return self.options or { }
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, parent, key)
      self.parent, self.key = parent, key
      _class_0.__parent.__init(self, self.parent, self.key)
      self.addon = self:getRoot()
      self.logger = Logger:getInstance()
      self.logger:debug("Node:new")
      if self:isRoot() then
        self.logger:debug("Node:new:Root")
        local default_structure = {
          debug = true,
          account = { },
          character = { }
        }
        self.database = Database(tostring(self.key) .. "DB", default_structure, 1)
        self.eventManager = EventManager()
        self.hookManager = HookManager()
        if self.database.db and self.database.db.debug ~= nil then
          self.logger:setDebugEnabled(self.database.db.debug)
        else
          self.logger:setDebugEnabled(true)
        end
      else
        self.logger:debug("Node:new:Child")
        self.database = self.addon.database
        self.eventManager = self.addon.eventManager
        self.hookManager = self.addon.hookManager
      end
      self:bindCharacterDb()
      if self:isRoot() then
        self.logger:debug("Node:new:subscribing-events")
        self.eventManager:subscribe(self, "PLAYER_LOGIN", function(...)
          return self:initialize(...)
        end)
        return self.eventManager:subscribe(self, "PLAYER_ENTERING_WORLD", function(...)
          return self:enable(...)
        end)
      end
    end,
    __base = _base_0,
    __name = "Node",
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
  Node = _class_0
end
_G.idUpkeep_Node = Node
return Node
