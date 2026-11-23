local unpack = _G.unpack or table.unpack
local HookManager
do
  local _class_0
  local _base_0 = {
    guard = function(self, handler, opts)
      if opts == nil then
        opts = { }
      end
      local reentering = false
      return function(...)
        if opts.nilArgs then
          local _list_0 = opts.nilArgs
          for _index_0 = 1, #_list_0 do
            local idx = _list_0[_index_0]
            if select(idx, ...) == nil then
              return 
            end
          end
        end
        if not (opts.selfRecursion) then
          return handler(...)
        end
        if reentering then
          return 
        end
        reentering = true
        local results = {
          pcall(handler, ...)
        }
        reentering = false
        local ok = table.remove(results, 1)
        if not (ok) then
          error(results[1], 0)
        end
        return unpack(results)
      end
    end,
    _track = function(self, owner, kind, target, method)
      if not (owner) then
        return 
      end
      local _update_0 = owner
      self.byOwner[_update_0] = self.byOwner[_update_0] or { }
      return table.insert(self.byOwner[owner], {
        kind = kind,
        target = target,
        method = method
      })
    end,
    hook = function(self, target, method, handler)
      if type(target) == "table" then
        if not method or type(method) ~= "string" then
          error("Cannot hook non-function table method", 2)
        end
        local orig = target[method]
        if type(orig) ~= "function" then
          error("Cannot hook non-function table method", 2)
        end
        local _update_0 = target
        self.hooks[_update_0] = self.hooks[_update_0] or { }
        if not self.hooks[target][method] then
          self.hooks[target][method] = orig
        end
        target[method] = function(...)
          return handler(...)
        end
      elseif type(target) == "string" then
        local orig = _G[target]
        if type(orig) ~= "function" then
          error("Cannot hook non-function global", 2)
        end
        local _update_0 = _G
        self.hooks[_update_0] = self.hooks[_update_0] or { }
        if not self.hooks[_G][target] then
          self.hooks[_G][target] = orig
        end
        _G[target] = handler
      else
        return error("Invalid target for hook", 2)
      end
    end,
    hookFor = function(self, owner, target, method, handler)
      self:hook(target, method, handler)
      return self:_track(owner, "hook", target, method)
    end,
    getOriginal = function(self, target, method)
      if type(target) == "table" then
        return self.hooks[target] and self.hooks[target][method]
      elseif type(target) == "string" then
        return self.hooks[_G] and self.hooks[_G][target]
      end
    end,
    callOriginal = function(self, target, method, ...)
      local orig = self:getOriginal(target, method)
      if not (orig) then
        return 
      end
      return orig(...)
    end,
    hookSecure = function(self, owner, target, method, handler)
      if type(target) == "string" and type(method) == "function" and handler == nil then
        method, handler = nil, method
      end
      if type(target) == "table" then
        if not method or type(method) ~= "string" then
          error("Cannot hookSecure non-function table method", 2)
        end
        if type(target[method]) ~= "function" then
          error("Cannot hookSecure non-function table method", 2)
        end
        _G.hooksecurefunc(target, method, handler)
      elseif type(target) == "string" then
        if type(_G[target]) ~= "function" then
          error("Cannot hookSecure non-function global", 2)
        end
        _G.hooksecurefunc(target, handler)
      else
        error("Invalid target for hookSecure", 2)
      end
      return self:_track(owner, "secure", target, method)
    end,
    unhook = function(self, target, method)
      if type(target) == "table" then
        if not method or type(method) ~= "string" then
          return 
        end
        if self.hooks[target] and self.hooks[target][method] then
          target[method] = self.hooks[target][method]
          self.hooks[target][method] = nil
        end
      elseif type(target) == "string" then
        if self.hooks[_G] and self.hooks[_G][target] then
          _G[target] = self.hooks[_G][target]
          self.hooks[_G][target] = nil
        end
      end
    end,
    unhookAll = function(self, target)
      if self.hooks[target] then
        for method, original in pairs(self.hooks[target]) do
          if type(target) == "table" then
            target[method] = original
          elseif type(target) == "string" then
            _G[target] = original
          end
        end
        self.hooks[target] = nil
      end
    end,
    unhookAllForOwner = function(self, owner)
      local entries = self.byOwner[owner]
      if not (entries) then
        return 
      end
      for _index_0 = 1, #entries do
        local entry = entries[_index_0]
        local _exp_0 = entry.kind
        if "hook" == _exp_0 then
          self:unhook(entry.target, entry.method)
        elseif "script" == _exp_0 then
          self:unhookScript(entry.target, entry.method)
        end
      end
      self.byOwner[owner] = nil
    end,
    hookScript = function(self, frame, script, handler)
      local orig
      if frame.GetScript then
        orig = frame.GetScript(frame, script)
      else
        orig = nil
      end
      if not (orig and type(orig) == "function") then
        error("Cannot hook non-function script", 2)
      end
      self.scripts[frame] = self.scripts[frame] or { }
      if not (self.scripts[frame][script]) then
        self.scripts[frame][script] = orig
      end
      return frame.SetScript(frame, script, handler)
    end,
    hookScriptFor = function(self, owner, frame, script, handler)
      self:hookScript(frame, script, handler)
      return self:_track(owner, "script", frame, script)
    end,
    unhookScript = function(self, frame, script)
      if self.scripts[frame] and self.scripts[frame][script] then
        frame.SetScript(frame, script, self.scripts[frame][script])
        self.scripts[frame][script] = nil
      end
    end,
    hookScriptSecure = function(self, owner, frame, script, handler)
      if not (frame and frame.HookScript) then
        error("Cannot hookScriptSecure a frame without a native HookScript method", 2)
      end
      frame:HookScript(script, handler)
      return self:_track(owner, "scriptSecure", frame, script)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      self.hooks = { }
      self.scripts = { }
      self.byOwner = { }
    end,
    __base = _base_0,
    __name = "HookManager"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  HookManager = _class_0
end
_G.idUpkeep_HookManager = HookManager
return HookManager
