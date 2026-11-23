-- luacheck: globals EasyFind WoWPro WoWProDB WoWProCharDB EasyFind_WoWProCharDB SlashCmdList StaticPopupDialogs
-- luacheck: globals tostring tonumber type ipairs select pairs math string table

--------------------------------------------------------------------------------
-- EasyFind_WoWPro
--
-- Follow WoW-Pro guides with EasyFind's GPS instead of TomTom: the WHOLE
-- remaining guide as one EasyFind trip, not just the next step.
--
-- A separate addon on purpose: it changes no WoW-Pro file. It wraps WoW-Pro's
-- WoWPro:MapPoint / WoWPro:RemoveMapPoint and its /wp command from outside,
-- and falls through to WoW-Pro's own code (TomTom) whenever EasyFind is
-- missing or switched off. (WoW-Pro's licence, CC BY-NC-ND, does not allow
-- shipping a modified WoW-Pro.)
--
-- EasyFind is used through its public cross-addon API only
-- (EasyFind/API/README.md):
--   CallAction("gps", "navigateTrip", stops, opts)  one route through every stop
--   CallAction("gps", "clear")                      ends the route
--   On("gps", "routeStarted" / "routeCleared")     whose route is showing
--
-- STOPS ARE HELD. Every stop carries `hold = true`, which EasyFind documents as
-- "a trip's stop the route never moves past on its own when reached, for a guide
-- that sends the next trip itself". Reaching a stop therefore clears nothing.
-- A stop leaves the route only when WoW-Pro completes its step: completion
-- runs WoWPro:MapPoint, which calls Sync, which sends the trip again without it.
--
-- Arrival-completed steps. With TomTom, WoW-Pro completed r/R/N steps tagged CC
-- or CS from TomTom's distance callback. That callback does not exist here, so
-- a ticker does the same check against the step's final coordinate. For those
-- steps reaching the spot IS finishing the step.
--
-- The player's own routes win. If a route that is not ours starts (the player
-- asked EasyFind for directions somewhere), syncing pauses until that route is
-- cleared or the player clicks a guide step.
--------------------------------------------------------------------------------

local EF = {}
_G.EasyFind_WoWPro = EF

local ARRIVAL_YARDS = 10      -- TomTom's default arrival distance, as WoW-Pro used it
local TICK_SECONDS = 1
local WATCHDOG_SECONDS = 45   -- a whole-guide trip can take a while to plan

local lastSignature = nil     -- what was last sent, so an unchanged guide sends nothing
local suspended = false       -- a route the player started themselves is showing
local syncToken = 0           -- bumped on every Sync; a pending clear checks it
local ticker = nil
local headStep = nil          -- the step the route currently leads to
local headCoord = nil         -- { mapID, x, y } of that step's final coordinate (0-1)
local lastHead = nil          -- the head step of the last Sync
local listening = false
-- The trip we sent and are waiting to see start. EasyFind plans in slices
-- over several frames and fires routeStarted when done, with a destination
-- it may have adjusted, so "ours" is recognised by this flag rather than by
-- comparing coordinates. A new route never fires routeCleared first, so the
-- next routeStarted after a send is ours.
local pending = nil
local shrinkTo = nil          -- a smaller stop count after a trip failed to plan

local function api()
    local ef = _G.EasyFind
    return ef and ef.API
end

local function db()
    _G.EasyFind_WoWProCharDB = _G.EasyFind_WoWProCharDB or {}
    return _G.EasyFind_WoWProCharDB
end

local function say(fmt, ...)
    WoWPro:Print("|cff33ccffEasyFind|r: " .. fmt, ...)
end

--- EasyFind is installed and its GPS answers.
function EF.Available()
    local API = api()
    if not (API and API.CallAction) then return false end
    if API.HasAction and API.HasAction("gps", "navigateTrip") then return true end
    if API.IsExtensionRegistered and API.IsExtensionRegistered("gps") then return true end
    return false
end

--- EasyFind is the arrow: available, and not switched off with /wp easyfind off.
function EF.Active()
    return db().disabled ~= true and EF.Available()
end

--------------------------------------------------------------------------------
-- Building the stops (pure apart from reading WoW-Pro's guide tables)
--------------------------------------------------------------------------------

--- Parses one WoW-Pro map string ("x,y;x,y") into its coordinates, 0-100.
-- Nil for PLAYER or anything malformed.
function EF.ParseCoords(map)
    if type(map) ~= "string" or map == "" or map == "PLAYER" then return nil end
    local out = {}
    for part in map:gmatch("[^;]+") do
        local x = tonumber(part:match("^%s*([^,|]+)"))
        local y = tonumber(part:match(",%s*([^,|]+)"))
        if not x or not y or x < 0 or x > 100 or y < 0 or y > 100 then return nil end
        out[#out + 1] = { x = x, y = y }
    end
    return #out > 0 and out or nil
end

-- The step's destination: its final coordinate. Multi-coordinate steps are
-- either a path ending at the spot (CS) or several spots for one objective;
-- EasyFind plans its own way, so the last spot is the one to lead to.
local function stepTarget(i)
    local coords = EF.ParseCoords(WoWPro.map and WoWPro.map[i])
    if not coords then return nil end
    local GID = WoWProDB.char.currentguide
    local zoneName = WoWPro.zone[i] or (WoWPro.Guides[GID] and WoWPro.Guides[GID].zone)
    if not zoneName then return nil end
    local _, mapID = WoWPro:ValidZone(zoneName)
    if not mapID then return nil end
    local c = coords[#coords]
    return { mapID = mapID, x = c.x / 100, y = c.y / 100 }
end

local ACTION_WORDS = {
    A = "Accept", T = "Turn in", C = "Complete", K = "Kill", R = "Run to", r = "Repair/restock",
    F = "Fly to", f = "Get flight path", h = "Set hearth", H = "Hearth to", N = "Note",
    b = "Take the boat to", U = "Use", L = "Level", l = "Loot", B = "Buy", P = "Take the portal",
    ["$"] = "Treasure", z = "Zone", t = "Turn in",
}

local function stepSentence(i)
    local word = ACTION_WORDS[WoWPro.action[i]] or WoWPro.action[i] or "Go"
    return ("%s: %s"):format(word, tostring(WoWPro.step[i] or "?"))
end

-- Read-only "is this later step still on the path". Deliberately NOT
-- WoWPro.NextStep: that walker completes and skips steps as it goes (and some
-- completions refresh the guide, which would re-enter MapPoint and this file).
-- The head of the trip still comes from WoW-Pro's own walk; this only decides
-- which LATER steps are drawn.
function EF.LaterStepOnPath(i)
    local GID = WoWProDB.char.currentguide
    local guide = WoWProCharDB.Guide[GID]
    if not guide then return false end
    if guide.completion and guide.completion[i] then return false end
    if guide.skipped and guide.skipped[i] then return false end
    local qid = WoWPro.QID and WoWPro.QID[i]
    if qid and WoWProCharDB.skippedQIDs and WoWPro.QIDsInTable
       and WoWPro:QIDsInTable(qid, WoWProCharDB.skippedQIDs, true) then
        return false
    end
    if WoWPro.sticky and WoWPro.sticky[i] then return false end
    -- Optional steps only show while their quest/item is in hand: not on a future path.
    if WoWPro.optional and WoWPro.optional[i] then return false end
    if WoWPro.rare and WoWPro.rare[i] and not WoWProCharDB.EnableRares then return false end
    if WoWPro.action[i] == "$" and not WoWProCharDB.EnableTreasures then return false end
    return true
end

local function questMark(i)
    local a = WoWPro.action[i]
    if a == "A" then return "offer" end
    if a == "T" then return "turnin" end
    return nil
end

local function singleQID(i)
    local q = WoWPro.QID and WoWPro.QID[i]
    return q and tonumber(q) or nil   -- "123;456" or "123&456" are not one quest
end

local function sameSpot(a, b)
    return a and b and a.mapID == b.mapID
       and math.abs(a.x - b.x) < 0.002 and math.abs(a.y - b.y) < 0.002
end

--- The trip: the head step, then every later step on the path, one held stop
-- per spot. Consecutive steps at the same spot share a stop (turn in, accept
-- the follow-up at the same NPC). `max` caps the number of stops (nil or 0 = all).
function EF.BuildStops(head, max)
    local stops = {}
    if not head or head > (WoWPro.stepcount or 0) then return stops end
    local limit = (max and max > 0) and max or math.huge
    for i = head, WoWPro.stepcount do
        if i == head or EF.LaterStepOnPath(i) then
            local target = stepTarget(i)
            if target then
                local last = stops[#stops]
                if last and sameSpot(last, target) then
                    last.step = last.step .. " / " .. stepSentence(i)
                    last.steps[#last.steps + 1] = i
                else
                    if #stops >= limit then break end
                    stops[#stops + 1] = {
                        name = tostring(WoWPro.step[i] or "WoW-Pro"),
                        mapID = target.mapID, x = target.x, y = target.y,
                        step = stepSentence(i),
                        hold = true,
                        quietArrival = true,
                        questMark = questMark(i),
                        questID = singleQID(i),
                        steps = { i },
                    }
                end
            end
        end
    end
    return stops
end

--- A string that changes whenever the stops do; equal strings mean the route
-- on screen is already this one.
function EF.Signature(stops)
    local parts = {}
    for n, s in ipairs(stops) do
        parts[n] = ("%s@%d:%.4f,%.4f"):format(table.concat(s.steps, "+"), s.mapID, s.x, s.y)
    end
    return table.concat(parts, "|")
end

--------------------------------------------------------------------------------
-- Arrival completion for r/R/N steps tagged CC/CS (TomTom did this before)
--------------------------------------------------------------------------------

local function arrivalCompletes(i)
    local a = WoWPro.action[i]
    local wc = WoWPro.waypcomplete and WoWPro.waypcomplete[i]
    return (a == "R" or a == "r" or a == "N") and (wc == 1 or wc == 2)
end

local function distanceToHead()
    if not headCoord then return nil end
    local px, py, pm = WoWPro:GetPlayerZonePosition()
    if not (px and py and pm) then return nil end
    return WoWPro.HBD:GetZoneDistance(pm, px, py, headCoord.mapID, headCoord.x, headCoord.y)
end

local function stopTicker()
    if ticker then ticker:Cancel() ticker = nil end
end

local function tick()
    if not (headStep and arrivalCompletes(headStep)) or suspended then
        stopTicker()
        return
    end
    if _G.UnitOnTaxi("player") then return end
    local d = distanceToHead()
    if d and d <= ARRIVAL_YARDS then
        local step = headStep
        stopTicker()
        WoWPro.CompleteStep(step, "EasyFind arrival", nil, "MappingAutoArrival")
    end
end

local function startTicker()
    stopTicker()
    if headStep and arrivalCompletes(headStep) then
        ticker = _G.C_Timer.NewTicker(TICK_SECONDS, tick)
    end
end

--------------------------------------------------------------------------------
-- Talking to EasyFind
--------------------------------------------------------------------------------

local function listen()
    if listening then return end
    local API = api()
    if not (API and API.On) then return end
    API.On("gps", "routeStarted", function()
        if pending then
            pending = nil      -- ours planned
            return
        end
        -- Someone else's route (the player's own directions): step aside.
        if lastSignature then
            suspended = true
            stopTicker()
        end
    end)
    API.On("gps", "routeCleared", function()
        -- Whoever's route ended, the guide's path may show again.
        local wasSuspended = suspended
        suspended = false
        lastSignature = nil
        pending = nil
        if wasSuspended and EF.Active() then
            WoWPro:MapPoint()
        end
    end)
    listening = true
end

--- Sends the guide's path, starting at `head` (WoW-Pro's own next step).
-- `userClicked`: the player clicked a guide row, which also takes the arrow
-- back from a route they started themselves.
function EF.Sync(head, userClicked)
    listen()
    syncToken = syncToken + 1
    if userClicked then suspended = false end
    if suspended then return end
    -- A new head means a step was finished: try the full length again.
    if head ~= lastHead then
        shrinkTo = nil
        lastHead = head
    end

    local max = db().maxStops
    if shrinkTo and (not max or max == 0 or shrinkTo < max) then max = shrinkTo end
    local stops = EF.BuildStops(head, max)
    headStep = stops[1] and stops[1].steps[1] or nil
    headCoord = stops[1] and { mapID = stops[1].mapID, x = stops[1].x, y = stops[1].y } or nil

    if #stops == 0 then
        if lastSignature then
            lastSignature = nil
            api().CallAction("gps", "clear")
        end
        stopTicker()
        return
    end

    local sig = EF.Signature(stops)
    if sig ~= lastSignature then
        lastSignature = sig
        -- `steps` is ours; EasyFind takes the documented fields and ignores the rest.
        local ok = api().CallAction("gps", "navigateTrip", stops, { quiet = true })
        if not ok then
            WoWPro:dbp("EasyFind_WoWPro: navigateTrip refused %d stops", #stops)
            lastSignature = nil
            pending = nil
        else
            EF.Watch(sig, #stops, head)
        end
    end
    startTicker()
end

--- EasyFind plans a trip leg by leg and gives up on the WHOLE trip, silently,
-- if any one leg has no way (an indoor spot, a dungeon interior). Over a whole
-- guide that is likely, so a trip that has not started after a while is sent
-- again with half the stops, down to one; the next step change resends it in
-- full and the halving starts over.
function EF.Watch(sig, count, head)
    pending = { sig = sig, count = count }
    _G.C_Timer.After(WATCHDOG_SECONDS, function()
        if not (pending and pending.sig == sig) or suspended then return end
        pending = nil
        if count <= 1 then
            WoWPro:dbp("EasyFind_WoWPro: could not plan even the first stop")
            return
        end
        shrinkTo = math.max(1, math.floor(count / 2))
        WoWPro:dbp("EasyFind_WoWPro: %d-stop trip did not plan; trying %d", count, shrinkTo)
        lastSignature = nil
        EF.Sync(head)
    end)
end

--- WoWPro:RemoveMapPoint in EasyFind mode. MapPoint calls RemoveMapPoint and
-- then maps again straight away; clearing EasyFind's route in between would
-- throw away a trip and plan it again. So the clear waits a moment and only
-- happens if no Sync followed (the guide really closed or unloaded).
function EF.RequestClear()
    local token = syncToken
    _G.C_Timer.After(0.25, function()
        if token ~= syncToken then return end
        stopTicker()
        headStep, headCoord = nil, nil
        if lastSignature and not suspended then
            lastSignature = nil
            local API = api()
            if API then API.CallAction("gps", "clear") end
        end
    end)
end

--------------------------------------------------------------------------------
-- Hooking WoW-Pro, from outside
--------------------------------------------------------------------------------

--- The step WoWPro:MapPoint(row) would map: the clicked row's step, or the
-- guide's next non-sticky step. Same rules and guards as WoW-Pro's own
-- MapPoint; nil when WoW-Pro would not map anything.
function EF.StepToMap(row)
    local GID = WoWProDB.char.currentguide
    if not GID or not WoWPro.Guides[GID] then return nil end
    if not WoWPro.GuideLoaded then return nil end
    if WoWPro.InitLockdown then return nil end
    if row then
        local r = WoWPro.rows and WoWPro.rows[row]
        local stepIndex = r and r.index
        if not stepIndex then return nil end
        -- WoW-Pro maps a sticky step only when the player clicked it.
        if WoWPro.sticky and WoWPro.sticky[stepIndex] and not WoWPro.UserClicked then return nil end
        return stepIndex
    end
    return WoWPro.NextStepNotSticky(WoWPro.ActiveStep)
end

function EF.Install()
    if EF.installed then return end
    local origMapPoint = WoWPro.MapPoint
    local origRemove = WoWPro.RemoveMapPoint
    if type(origMapPoint) ~= "function" or type(origRemove) ~= "function" then
        say("WoW-Pro's mapping functions were not found; leaving TomTom in charge.")
        return
    end
    EF.origMapPoint, EF.origRemove = origMapPoint, origRemove

    function WoWPro:MapPoint(row)
        if not EF.Active() then return origMapPoint(self, row) end
        local stepIndex = EF.StepToMap(row)
        if not stepIndex then return end
        -- TomTom points left from before EasyFind took over go; WoW-Pro's own
        -- removal touches TomTom only (ours would schedule a route clear).
        origRemove(self)
        EF.Sync(stepIndex, row ~= nil)
    end

    function WoWPro:RemoveMapPoint()
        if EF.Active() then EF.RequestClear() end
        return origRemove(self)
    end

    -- /wp easyfind ...  (everything else goes to WoW-Pro's own /wp)
    local origSlash = SlashCmdList and SlashCmdList["WOWPRO"]
    if origSlash then
        SlashCmdList["WOWPRO"] = function(msg, editbox)
            local tokens = {}
            for token in (msg or ""):gmatch("%S+") do tokens[#tokens + 1] = token end
            if tokens[1] and tokens[1]:lower() == "easyfind" then
                return EF.Slash(tokens)
            end
            return origSlash(msg, editbox)
        end
    end

    -- WoW-Pro nags for a missing TomTom; EasyFind is the arrow now.
    local popup = StaticPopupDialogs and StaticPopupDialogs["WOWPRO_MISSING_ARROW"]
    if popup then
        local origShow = popup.OnShow
        popup.OnShow = function(frame, ...)
            if EF.Active() then
                frame:Hide()
                return
            end
            if origShow then return origShow(frame, ...) end
        end
    end

    EF.installed = true
end

--------------------------------------------------------------------------------
-- /wp easyfind   and   /efwp
--------------------------------------------------------------------------------

function EF.Slash(tokens)
    local sub = tokens[2] and tokens[2]:lower()
    local d = db()
    if sub == "off" then
        d.disabled = true
        EF.RequestClear()
        say("off; TomTom is the arrow again.")
        WoWPro:MapPoint()
    elseif sub == "on" then
        d.disabled = nil
        lastSignature = nil
        say("on.")
        WoWPro:MapPoint()
    elseif sub == "max" then
        local n = tonumber(tokens[3])
        d.maxStops = (n and n > 0) and math.floor(n) or nil
        lastSignature = nil
        say("route length: %s.", d.maxStops and (d.maxStops .. " stops") or "the whole guide")
        WoWPro:MapPoint()
    else
        say("%s%s. Length: %s. Commands: /wp easyfind on | off | max <n> (0 = whole guide).",
            EF.Available() and (d.disabled and "off" or "on") or "EasyFind's GPS not found",
            suspended and " (paused: your own EasyFind route is showing)" or "",
            d.maxStops and (d.maxStops .. " stops") or "whole guide")
    end
end

_G.SLASH_EASYFINDWOWPRO1 = "/efwp"
if SlashCmdList then
    SlashCmdList["EASYFINDWOWPRO"] = function(msg)
        local tokens = { "easyfind" }
        for token in (msg or ""):gmatch("%S+") do tokens[#tokens + 1] = token end
        EF.Slash(tokens)
    end
end

-- WoW-Pro is a hard dependency, so it is loaded (and its functions defined)
-- before this file runs.
if WoWPro then EF.Install() end
