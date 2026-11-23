local Logger = _G.idUpkeep_Logger
local Frame = _G.idUpkeep_Frame
local lua_type = _G.type
local EventManager
do
  local _class_0
  local _base_0 = {
    onEvent = function(self, event, ...)
      local called = { }
      while true do
        local subscribers = self.registry[event]
        if not (subscribers) then
          return 
        end
        local pending
        do
          local _accum_0 = { }
          local _len_0 = 1
          for node, handler in pairs(subscribers) do
            if not called[node] then
              _accum_0[_len_0] = {
                node,
                handler
              }
              _len_0 = _len_0 + 1
            end
          end
          pending = _accum_0
        end
        if #pending == 0 then
          return 
        end
        for _index_0 = 1, #pending do
          local _continue_0 = false
          repeat
            local entry = pending[_index_0]
            local node, handler = entry[1], entry[2]
            local current = self.registry[event]
            if not (current and current[node] == handler) then
              _continue_0 = true
              break
            end
            called[node] = true
            handler(node, ...)
            _continue_0 = true
          until true
          if not _continue_0 then
            break
          end
        end
      end
    end,
    eventExists = function(self, event, globals)
      if globals == nil then
        globals = _G
      end
      local utils = globals.C_EventUtils
      if not (lua_type(utils) == "table") then
        return nil
      end
      if not (lua_type(utils.IsEventValid) == "function") then
        return nil
      end
      local ok, valid = pcall(utils.IsEventValid, event)
      if not (ok) then
        return nil
      end
      return valid == true
    end,
    subscribe = function(self, node, event, handler)
      self.logger:debug("EventManager:subscribe " .. tostring(tostring(node)) .. " to " .. tostring(event))
      if not (self.registeredEvents[event]) then
        if self:eventExists(event) == false then
          self.logger:debug("EventManager: " .. tostring(event) .. " is not an event on this client")
          return false
        end
        local ok, err = pcall(function()
          return self.frame:registerEvent(event)
        end)
        if not (ok) then
          self.logger:warn("EventManager: RegisterEvent(" .. tostring(event) .. ") failed: " .. tostring(tostring(err)))
          return false
        end
        self.registeredEvents[event] = true
      end
      local _update_0 = event
      self.registry[_update_0] = self.registry[_update_0] or { }
      self.registry[event][node] = handler
      return true
    end,
    unsubscribe = function(self, node, event)
      self.logger:debug("EventManager:unsubscribe " .. tostring(tostring(node)) .. " from " .. tostring(event))
      if self.registry[event] and self.registry[event][node] then
        self.registry[event][node] = nil
        if next(self.registry[event]) == nil then
          if self.registeredEvents[event] then
            self.frame:unregisterEvent(event)
            self.registeredEvents[event] = nil
          end
          self.registry[event] = nil
        end
      end
    end,
    subscribeDomain = function(self, node, event, handler)
      self.logger:debug("EventManager:subscribeDomain " .. tostring(tostring(node)) .. " to " .. tostring(event))
      local _update_0 = event
      self.registry[_update_0] = self.registry[_update_0] or { }
      self.registry[event][node] = handler
      return true
    end,
    publish = function(self, event, ...)
      self.logger:debug("EventManager:publish " .. tostring(event))
      return self:onEvent(event, ...)
    end,
    unsubscribeAll = function(self, node)
      self.logger:debug("EventManager:unsubscribeAll " .. tostring(tostring(node)))
      for event, nodes in pairs(self.registry) do
        if nodes[node] then
          self:unsubscribe(node, event)
        end
      end
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      self.logger = Logger:getInstance()
      self.logger:debug("EventManager:new")
      self.registry = { }
      self.registeredEvents = { }
      self.frame = Frame.create("Frame")
      return self.frame:on("OnEvent", function(_, event, ...)
        return self:onEvent(event, ...)
      end)
    end,
    __base = _base_0,
    __name = "EventManager"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  EventManager = _class_0
end
_G.idUpkeep_EventManager = EventManager
return EventManager
