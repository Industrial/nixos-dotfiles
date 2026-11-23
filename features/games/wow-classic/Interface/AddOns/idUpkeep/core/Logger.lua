local Color = _G.idUpkeep_Color
local Logger
do
  local _class_0
  local _base_0 = {
    logLevels = {
      DEBUG = 1,
      INFO = 2,
      WARN = 3,
      ERROR = 4
    },
    logLevelNames = {
      [1] = "DEBUG",
      [2] = "INFO",
      [3] = "WARN",
      [4] = "ERROR"
    },
    colors = {
      DEBUG = Color.fromHex("#999999"),
      INFO = Color.fromHex("#00BFFF"),
      WARN = Color.fromHex("#FFD700"),
      ERROR = Color.fromHex("#FF4500")
    },
    setDebugEnabled = function(self, flag)
      self.debugEnabled = not not flag
    end,
    setLogLevel = function(self, level)
      self.logLevel = level
    end,
    log = function(self, level, ...)
      if level < self.logLevel then
        return 
      end
      local levelName = self.logLevelNames[level] or tostring(level)
      local levelColor = self.colors[levelName]
      local messageParts = { }
      for i = 1, select('#', ...) do
        messageParts[i] = tostring(select(i, ...))
      end
      local messageStr = table.concat(messageParts, " ")
      local addonTag = "[" .. tostring(self.name) .. "]"
      local levelTag
      if levelColor then
        levelTag = levelColor:toMarkupString("[" .. tostring(levelName) .. "]")
      else
        levelTag = "[" .. tostring(levelName) .. "]"
      end
      local blizzardTimestamps
      if _G.GetCVarBool then
        blizzardTimestamps = _G.GetCVarBool("showTimestamps")
      elseif _G.GetCVar then
        blizzardTimestamps = _G.GetCVar("showTimestamps") == "1"
      else
        blizzardTimestamps = false
      end
      local timestamp
      if _G.date and not blizzardTimestamps then
        timestamp = tostring(_G.date('%H:%M:%S')) .. " "
      else
        timestamp = ""
      end
      return print(tostring(timestamp) .. tostring(levelTag) .. " " .. tostring(addonTag) .. " " .. tostring(messageStr))
    end,
    debug = function(self, ...)
      if not (self.debugEnabled) then
        return 
      end
      return self:log(Logger.logLevels.DEBUG, ...)
    end,
    info = function(self, ...)
      return self:log(Logger.logLevels.INFO, ...)
    end,
    warn = function(self, ...)
      return self:log(Logger.logLevels.WARN, ...)
    end,
    error = function(self, ...)
      return self:log(Logger.logLevels.ERROR, ...)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, name)
      self.name = name
      self.logLevel = Logger.logLevels.DEBUG
      self.debugEnabled = false
    end,
    __base = _base_0,
    __name = "Logger"
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
  self.getInstance = function(_self)
    if not (self.__class.instance) then
      self.__class.instance = Logger("idUpkeep")
    end
    return self.__class.instance
  end
  Logger = _class_0
end
_G.idUpkeep_Logger = Logger
return Logger
