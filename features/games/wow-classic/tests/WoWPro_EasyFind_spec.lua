-- busted spec for Interface/AddOns/WoWPro/WoWPro_EasyFind.lua
--
-- Runs outside the game against stubs of the WoW client, WoWPro's guide tables
-- and EasyFind's documented API (EasyFind/API/README.md: navigateTrip, clear,
-- routeStarted, routeCleared). Run from features/games/wow-classic:
--   busted tests/WoWPro_EasyFind_spec.lua

local ADDON_FILE = "Interface/AddOns/WoWPro/WoWPro_EasyFind.lua"

local timers, calls, listeners, completed, mapPoints

local function fireTimers(upTo)
    -- runs every queued C_Timer.After whose delay is <= upTo seconds
    local keep = {}
    local run = {}
    for _, t in ipairs(timers) do
        if t.delay <= upTo then run[#run + 1] = t else keep[#keep + 1] = t end
    end
    timers = keep
    for _, t in ipairs(run) do t.fn() end
end

local function fire(event, ...)
    for _, fn in ipairs(listeners[event] or {}) do fn(...) end
end

local function sent(name)
    local out = {}
    for _, c in ipairs(calls) do
        if c.name == name then out[#out + 1] = c end
    end
    return out
end

-- A small guide. Zone "Elwynn Forest" is map 1429 for every step.
local function loadGuide(steps)
    WoWPro.action, WoWPro.step, WoWPro.map, WoWPro.zone = {}, {}, {}, {}
    WoWPro.QID, WoWPro.sticky, WoWPro.optional, WoWPro.rare, WoWPro.waypcomplete = {}, {}, {}, {}, {}
    for i, s in ipairs(steps) do
        WoWPro.action[i] = s.a
        WoWPro.step[i] = s.name
        WoWPro.map[i] = s.map
        WoWPro.QID[i] = s.qid
        WoWPro.sticky[i] = s.sticky
        WoWPro.optional[i] = s.optional
        WoWPro.waypcomplete[i] = s.wc
    end
    WoWPro.stepcount = #steps
end

local function guideState()
    return WoWProCharDB.Guide.TestGuide
end

before_each(function()
    timers, calls, listeners, completed, mapPoints = {}, {}, {}, {}, 0
    _G.C_Timer = {
        After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end,
        NewTicker = function(_, fn)
            local t = { fn = fn, cancelled = false }
            function t:Cancel() self.cancelled = true end
            _G.__ticker = t
            return t
        end,
    }
    _G.UnitOnTaxi = function() return false end
    _G.EasyFind = {
        API = {
            CallAction = function(id, name, ...)
                calls[#calls + 1] = { id = id, name = name, args = { ... } }
                if name == "navigateTrip" then return true end
            end,
            HasAction = function(id, name) return id == "gps" and name == "navigateTrip" end,
            On = function(id, event, fn)
                assert(id == "gps")
                listeners[event] = listeners[event] or {}
                table.insert(listeners[event], fn)
            end,
        },
    }
    _G.WoWProDB = { char = { currentguide = "TestGuide" } }
    _G.WoWProCharDB = { Guide = { TestGuide = { completion = {}, skipped = {} } }, skippedQIDs = {} }
    _G.WoWPro = {
        Guides = { TestGuide = { zone = "Elwynn Forest" } },
        ValidZone = function(_, zone) return zone, 1429 end,
        QIDsInTable = function() return false end,
        GetPlayerZonePosition = function() return 0.5, 0.5, 1429 end,
        HBD = { GetZoneDistance = function() return 1000 end },
        CompleteStep = function(i, why) completed[#completed + 1] = { i = i, why = why } end,
        MapPoint = function() mapPoints = mapPoints + 1 end,
        RemoveMapPoint = function() end,
        dbp = function() end,
        Print = function() end,
    }
    dofile(ADDON_FILE)
end)

describe("WoWPro_EasyFind", function()

    describe("ParseCoords", function()
        it("reads every coordinate of a step", function()
            local c = WoWPro.EasyFind.ParseCoords("30.5,40.2;31,41")
            assert.are.same({ { x = 30.5, y = 40.2 }, { x = 31, y = 41 } }, c)
        end)
        it("refuses PLAYER and malformed strings", function()
            assert.is_nil(WoWPro.EasyFind.ParseCoords("PLAYER"))
            assert.is_nil(WoWPro.EasyFind.ParseCoords("abc"))
            assert.is_nil(WoWPro.EasyFind.ParseCoords("150,20"))
        end)
    end)

    describe("BuildStops: the whole remaining guide, not just the next step", function()
        before_each(function()
            loadGuide({
                { a = "A", name = "Wolves", map = "40,60", qid = "11" },          -- 1
                { a = "C", name = "Kill wolves", map = "45,65;46,66", qid = "11" }, -- 2
                { a = "N", name = "A note", sticky = true, map = "1,1" },          -- 3 sticky
                { a = "A", name = "Optional", optional = true, map = "2,2" },      -- 4 optional
                { a = "T", name = "Wolves", map = "40,60", qid = "11" },          -- 5
                { a = "A", name = "Follow-up", map = "40,60", qid = "12" },       -- 6 same spot as 5
                { a = "R", name = "Goldshire", map = "42,65" },                    -- 7
                { a = "C", name = "No coords" },                                   -- 8
            })
        end)

        it("leads through every later step that has a spot", function()
            local stops = WoWPro.EasyFind.BuildStops(1)
            local steps = {}
            for n, s in ipairs(stops) do steps[n] = table.concat(s.steps, "+") end
            assert.are.same({ "1", "2", "5+6", "7" }, steps)
        end)

        it("holds every stop, so arriving clears nothing", function()
            for _, s in ipairs(WoWPro.EasyFind.BuildStops(1)) do
                assert.is_true(s.hold)
            end
        end)

        it("leads to a step's final coordinate", function()
            local stops = WoWPro.EasyFind.BuildStops(2)
            assert.are.equal(1429, stops[1].mapID)
            assert.is_true(math.abs(stops[1].x - 0.46) < 1e-9)
            assert.is_true(math.abs(stops[1].y - 0.66) < 1e-9)
        end)

        it("merges steps at the same spot into one stop", function()
            local stops = WoWPro.EasyFind.BuildStops(5)
            assert.are.same({ 5, 6 }, stops[1].steps)
            assert.is_truthy(stops[1].step:find("Turn in: Wolves", 1, true))
            assert.is_truthy(stops[1].step:find("Accept: Follow%-up"))
        end)

        it("leaves completed and skipped steps off the path", function()
            guideState().completion[2] = "done"
            guideState().skipped[7] = true
            local steps = {}
            for n, s in ipairs(WoWPro.EasyFind.BuildStops(1)) do steps[n] = table.concat(s.steps, "+") end
            -- With 2 done and 7 skipped, 1, 5 and 6 are consecutive at the same
            -- NPC (40,60), so they share one stop.
            assert.are.same({ "1+5+6" }, steps)
        end)

        it("caps the trip at max stops when one is set", function()
            assert.are.equal(2, #WoWPro.EasyFind.BuildStops(1, 2))
            assert.are.equal(4, #WoWPro.EasyFind.BuildStops(1, 0))
        end)

        it("marks quest givers and turn-ins for EasyFind's quest icons", function()
            local stops = WoWPro.EasyFind.BuildStops(1)
            assert.are.equal("offer", stops[1].questMark)
            assert.are.equal(11, stops[1].questID)
            assert.are.equal("turnin", stops[3].questMark)
        end)
    end)

    describe("Sync", function()
        before_each(function()
            loadGuide({
                { a = "A", name = "One", map = "10,10", qid = "1" },
                { a = "C", name = "Two", map = "20,20", qid = "1" },
                { a = "T", name = "Three", map = "30,30", qid = "1" },
            })
        end)

        it("sends the whole guide as one trip", function()
            WoWPro.EasyFind.Sync(1)
            local trips = sent("navigateTrip")
            assert.are.equal(1, #trips)
            assert.are.equal(3, #trips[1].args[1])
            assert.is_true(trips[1].args[2].quiet)
        end)

        it("sends nothing when the guide has not changed", function()
            WoWPro.EasyFind.Sync(1)
            WoWPro.EasyFind.Sync(1)
            assert.are.equal(1, #sent("navigateTrip"))
        end)

        it("drops a stop only when its step is completed", function()
            WoWPro.EasyFind.Sync(1)
            fire("routeStarted")
            -- WoWPro completes step 1; its refresh calls MapPoint -> Sync(2)
            guideState().completion[1] = "Quest accepted"
            WoWPro.EasyFind.Sync(2)
            local trips = sent("navigateTrip")
            assert.are.equal(2, #trips)
            assert.are.equal(2, #trips[2].args[1])
            assert.are.same({ 2 }, trips[2].args[1][1].steps)
        end)

        it("clears the route when nothing is left", function()
            WoWPro.EasyFind.Sync(1)
            for i = 1, 3 do guideState().completion[i] = true end
            WoWPro.EasyFind.Sync(4)
            assert.are.equal(1, #sent("clear"))
        end)
    end)

    describe("RemoveMapPoint then MapPoint", function()
        before_each(function()
            loadGuide({ { a = "A", name = "One", map = "10,10" } })
        end)

        it("does not clear a route that is mapped again straight away", function()
            WoWPro.EasyFind.Sync(1)
            WoWPro.EasyFind.RequestClear()
            WoWPro.EasyFind.Sync(1)
            fireTimers(1)
            assert.are.equal(0, #sent("clear"))
        end)

        it("clears when the guide really goes away", function()
            WoWPro.EasyFind.Sync(1)
            WoWPro.EasyFind.RequestClear()
            fireTimers(1)
            assert.are.equal(1, #sent("clear"))
        end)
    end)

    describe("the player's own route wins", function()
        before_each(function()
            loadGuide({
                { a = "A", name = "One", map = "10,10" },
                { a = "A", name = "Two", map = "20,20" },
            })
            WoWPro.EasyFind.Sync(1)
            fire("routeStarted")   -- ours
        end)

        it("pauses when someone else's route starts", function()
            fire("routeStarted")   -- the player's own directions
            guideState().completion[1] = true
            WoWPro.EasyFind.Sync(2)
            assert.are.equal(1, #sent("navigateTrip"))
        end)

        it("takes the arrow back when the player clicks a guide step", function()
            fire("routeStarted")
            WoWPro.EasyFind.Sync(2, true)
            assert.are.equal(2, #sent("navigateTrip"))
        end)

        it("resumes when the player's route is cleared", function()
            fire("routeStarted")
            fire("routeCleared")
            assert.are.equal(1, mapPoints)
        end)
    end)

    describe("a trip EasyFind cannot plan", function()
        it("is sent again with half the stops", function()
            local steps = {}
            for i = 1, 8 do steps[i] = { a = "C", name = "S" .. i, map = (i * 5) .. ",50" } end
            loadGuide(steps)
            WoWPro.EasyFind.Sync(1)
            fireTimers(60)          -- no routeStarted: the plan failed
            local trips = sent("navigateTrip")
            assert.are.equal(2, #trips)
            assert.are.equal(8, #trips[1].args[1])
            assert.are.equal(4, #trips[2].args[1])
        end)

        it("is not resent once it started", function()
            loadGuide({ { a = "A", name = "One", map = "10,10" }, { a = "A", name = "Two", map = "20,20" } })
            WoWPro.EasyFind.Sync(1)
            fire("routeStarted")
            fireTimers(60)
            assert.are.equal(1, #sent("navigateTrip"))
        end)
    end)

    describe("arrival-completed steps (what TomTom's callback did)", function()
        it("completes a CC run-to step within 10 yards", function()
            loadGuide({ { a = "R", name = "Goldshire", map = "42,65", wc = 1 } })
            WoWPro.EasyFind.Sync(1)
            WoWPro.HBD.GetZoneDistance = function() return 8 end
            _G.__ticker.fn()
            assert.are.same({ { i = 1, why = "EasyFind arrival" } }, completed)
        end)

        it("does not complete a quest objective by arriving", function()
            loadGuide({ { a = "C", name = "Kill", map = "42,65", wc = 1 } })
            _G.__ticker = nil
            WoWPro.EasyFind.Sync(1)
            assert.is_nil(_G.__ticker)
            assert.are.same({}, completed)
        end)

        it("waits while the player is further away", function()
            loadGuide({ { a = "R", name = "Goldshire", map = "42,65", wc = 2 } })
            WoWPro.EasyFind.Sync(1)
            WoWPro.HBD.GetZoneDistance = function() return 50 end
            _G.__ticker.fn()
            assert.are.same({}, completed)
        end)
    end)

    describe("switching", function()
        it("is inactive after /wp easyfind off and active after on", function()
            WoWPro.EasyFind.Slash({ "easyfind", "off" })
            assert.is_false(WoWPro.EasyFind.Active())
            WoWPro.EasyFind.Slash({ "easyfind", "on" })
            assert.is_true(WoWPro.EasyFind.Active())
        end)

        it("is inactive without EasyFind installed", function()
            _G.EasyFind = nil
            assert.is_false(WoWPro.EasyFind.Active())
        end)
    end)
end)
