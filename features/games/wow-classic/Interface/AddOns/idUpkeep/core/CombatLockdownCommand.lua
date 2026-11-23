local CombatLockdownCommand
do
  local _class_0
  local _base_0 = { }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "CombatLockdownCommand"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.locked = function()
    return (_G.InCombatLockdown and _G.InCombatLockdown()) == true
  end
  self.execute = function(fn, opts)
    if opts == nil then
      opts = { }
    end
    if not (self:locked()) then
      fn()
      return true
    end
    if opts.partial then
      opts.partial()
    end
    if opts.owner and opts.flag then
      opts.owner[opts.flag] = true
    end
    if opts.onBlocked then
      opts.onBlocked()
    end
    return false
  end
  CombatLockdownCommand = _class_0
end
_G.idUpkeep_CombatLockdownCommand = CombatLockdownCommand
return CombatLockdownCommand
