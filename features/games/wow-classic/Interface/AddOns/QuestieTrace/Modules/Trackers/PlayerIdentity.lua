---@type QuestieTraceCore
local Core = QuestieTraceCore

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- UnitRace(unit)  -> string localizedRaceName,
--                    string englishRaceName,
--                    number raceID
--
-- UnitClass(unit) -> string className,
--                    string classFilename,
--                    number classID
--
-- UnitClassBase(unit) -> string classFilename,
--                        number classID
--
-- UnitSex(unit)   -> number sex  -- 1=unknown, 2=male, 3=female
--
-- UnitFactionGroup(unit) -> string englishFaction,  -- "Alliance"|"Horde"|"Neutral"
--                           string localizedFaction
--
-- GetLocale() -> string locale
--
-- GetBuildInfo() -> select(4, ...) returns number interfaceVersion
---------------------------------------------------------------------------

Core.RegisterTracker({
  -- No events -- sampled once at t=0 only

  ---@param capture CaptureState
  Init = function(capture)
    ---@type table<string, FunctionStream>
    local functions = capture.session.functions
    ---@type string, string, number
    local raceL, raceE, raceID = UnitRace("player")
    ---@type string, string, number
    local classL, classE, classID = UnitClass("player")
    ---@type number?
    local sex = UnitSex("player")
    ---@type string, string
    local factionE, factionL = UnitFactionGroup("player")
    ---@type string
    local locale = GetLocale()
    ---@type number
    local interfaceVersion = select(4, GetBuildInfo())

    functions["UnitRace"] = {
      ["player"] = { { t = 0, tp = 0, v = { raceL, raceE, raceID, n = 3 } } },
    }
    functions["UnitClass"] = {
      ["player"] = { { t = 0, tp = 0, v = { classL, classE, classID, n = 3 } } },
    }
    -- UnitClassBase is absent on some clients. Capture it only when the API is
    -- available so replay can prefer the exact base-class tuple without forcing
    -- older traces/clients to synthesize it from UnitClass.
    if type(UnitClassBase) == "function" then
      local ok, classFilename, classBaseID = pcall(UnitClassBase, "player")
      if ok then
        functions["UnitClassBase"] = {
          ["player"] = { { t = 0, tp = 0, v = { classFilename, classBaseID, n = 2 } } },
        }
      end
    end
    functions["UnitSex"] = {
      ["player"] = { { t = 0, tp = 0, v = sex } },
    }
    functions["UnitFactionGroup"] = {
      ["player"] = { { t = 0, tp = 0, v = { factionE, factionL, n = 2 } } },
    }
    functions["GetLocale"] = {
      ["player"] = { { t = 0, tp = 0, v = locale } },
    }
    functions["GetBuildInfo"] = {
      ["player"] = { { t = 0, tp = 0, v = interfaceVersion } },
    }
  end,
})
