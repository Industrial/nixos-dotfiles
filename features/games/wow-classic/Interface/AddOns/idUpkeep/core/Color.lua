local tonumber
tonumber = function(v)
  return _G.tonumber(v)
end
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local ITEM_QUALITY_COLORS = _G.ITEM_QUALITY_COLORS
local Color
do
  local _class_0
  local _base_0 = {
    toHex = function(self)
      local r = string.format("%02x", self.r * 255)
      local g = string.format("%02x", self.g * 255)
      local b = string.format("%02x", self.b * 255)
      return "#" .. tostring(r) .. tostring(g) .. tostring(b)
    end,
    toMarkupString = function(self, text)
      local r = string.format("%02x", self.r * 255)
      local g = string.format("%02x", self.g * 255)
      local b = string.format("%02x", self.b * 255)
      return "|cff" .. tostring(r) .. tostring(g) .. tostring(b) .. tostring(text) .. "|r"
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, r, g, b, a)
      if a == nil then
        a = 1
      end
      self.r, self.g, self.b, self.a = r, g, b, a
    end,
    __base = _base_0,
    __name = "Color"
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
  self.fromHex = function(hex)
    local r = (tonumber("0x" .. tostring(hex:sub(2, 3)))) / 255
    local g = (tonumber("0x" .. tostring(hex:sub(4, 5)))) / 255
    local b = (tonumber("0x" .. tostring(hex:sub(6, 7)))) / 255
    return Color(r, g, b)
  end
  self.fromClass = function(className)
    local colorInfo = RAID_CLASS_COLORS[className:upper()]
    if colorInfo then
      return Color(colorInfo.r, colorInfo.g, colorInfo.b)
    else
      return Color(1, 1, 1)
    end
  end
  self.fromQuality = function(quality)
    local colorInfo = ITEM_QUALITY_COLORS[quality]
    if colorInfo then
      return Color(colorInfo.r, colorInfo.g, colorInfo.b)
    else
      return Color(0.5, 0.5, 0.5)
    end
  end
  Color = _class_0
end
_G.idUpkeep_Color = Color
return Color
