local VersionInfo
do
  local _class_0
  local _base_0 = {
    GetVersionString = function(self)
      return tostring(self.addonName) .. " v" .. tostring(self.version) .. " (Build: " .. tostring(self.build) .. ", Date: " .. tostring(self.buildDate) .. ")"
    end,
    IsDebugBuild = function(self)
      if (self.build ~= "release" and self.build ~= "retail") then
        return true
      end
      if _G.idUpkeep_db and _G.idUpkeep_db.debug ~= nil then
        return not not _G.idUpkeep_db.debug
      end
      return false
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, addonName)
      if addonName == nil then
        addonName = "idUpkeep"
      end
      self.addonName = addonName
      self.version = (self.__class:getAddOnMetadata(self.addonName, "Version")) or "development"
      self.build = (self.__class:getAddOnMetadata(self.addonName, "X-Build")) or "dev"
      local fmtDate = _G.date or os.date
      self.buildDate = (self.__class:getAddOnMetadata(self.addonName, "X-BuildDate")) or fmtDate("%Y-%m-%d")
    end,
    __base = _base_0,
    __name = "VersionInfo"
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
  self.instance = nil
  self.getAddOnMetadata = function(self, addonName, field)
    local f = _G.GetAddOnMetadata
    if not (f) then
      local ca = _G.C_AddOns
      f = ca and ca.GetAddOnMetadata
    end
    if not (f) then
      return nil
    end
    local ok, value = pcall(function()
      return f(addonName, field)
    end)
    if ok then
      return value
    end
    return nil
  end
  self.getInstance = function(_self)
    if not (self.__class.instance) then
      self.__class.instance = VersionInfo("idUpkeep")
    end
    return self.__class.instance
  end
  VersionInfo = _class_0
end
_G.idUpkeep_VersionInfo = VersionInfo
