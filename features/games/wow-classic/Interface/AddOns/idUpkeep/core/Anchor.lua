local _byName = { }
local AnchorPoint
do
  local _class_0
  local _base_0 = {
    opposite = function(self)
      return _byName[self.oppositeName]
    end,
    __tostring = function(self)
      return self.name
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, name, oppositeName)
      self.name, self.oppositeName = name, oppositeName
    end,
    __base = _base_0,
    __name = "AnchorPoint"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  AnchorPoint = _class_0
end
local _POINTS = {
  {
    "TOPLEFT",
    "BOTTOMRIGHT"
  },
  {
    "TOP",
    "BOTTOM"
  },
  {
    "TOPRIGHT",
    "BOTTOMLEFT"
  },
  {
    "LEFT",
    "RIGHT"
  },
  {
    "CENTER",
    "CENTER"
  },
  {
    "RIGHT",
    "LEFT"
  },
  {
    "BOTTOMLEFT",
    "TOPRIGHT"
  },
  {
    "BOTTOM",
    "TOP"
  },
  {
    "BOTTOMRIGHT",
    "TOPLEFT"
  }
}
local _order = { }
for _index_0 = 1, #_POINTS do
  local def = _POINTS[_index_0]
  local name, oppositeName = def[1], def[2]
  _byName[name] = AnchorPoint(name, oppositeName)
  table.insert(_order, name)
end
local _statics = {
  fromString = function(name)
    return _byName[name]
  end,
  isValid = function(name)
    return _byName[name] ~= nil
  end,
  all = (function()
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #_order do
      local n = _order[_index_0]
      _accum_0[_len_0] = _byName[n]
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)()
}
local Anchor = setmetatable({ }, {
  __index = function(t, key)
    return _byName[key] or _statics[key] or error("Anchor: no such anchor point '" .. tostring(tostring(key)) .. "' (valid: " .. tostring(table.concat(_order, ', ')) .. ")", 2)
  end,
  __newindex = function(t, key, value)
    return error("Anchor is a frozen enum -- cannot set Anchor." .. tostring(tostring(key)), 2)
  end
})
_G.idUpkeep_Anchor = Anchor
return Anchor
