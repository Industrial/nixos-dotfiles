-- busted spec for EasyFind_WoWPro/Core.lua
--
-- Runs outside the game against stubs of the WoW client, WoW-Pro's guide
-- tables and EasyFind's documented API (EasyFind/API/README.md: navigateTrip,
-- clear, routeStarted, routeCleared). Run from the addon folder:
--   busted tests/Core_spec.lua

local CORE = "Core.lua"

local EF, timers, calls, listeners, completed, origMapped, origRemoved, origSlashed, popupShown

local function fireTimers(upTo)
    local keep, run = {}, {}
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

-- A small guide. Every step's zone maps to 1429.
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

-- WoW-Pro's next step, as its own NextStepNotSticky would answer: the first
-- step not completed.
local function nextOpenStep()
    for i = 1, WoWPro.stepcount do
        if not guideState().completion[i] then return i end
    end
    return WoWPro.stepcount + 1
end

before_each(function()
    timers, calls, listeners, completed = {}, {}, {}, {}
    origMapped, origRemoved, origSlashed, popupShown = 0, 0, {}, 0
    _G.C_Timer = {
        After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end,
        NewTicker = function(_, fn)
            local t = { fn = fn }
            function t:Cancel() self.cancelled = true end
            _G.__ticker = t
            return t
        end,
    }
    _G.__ticker = nil
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
    _G.EasyFind_WoWProCharDB = nil
    _G.WoWProDB = { char = { currentguide = "TestGuide" } }
    _G.WoWProCharDB = { Guide = { TestGuide = { completion = {}, skipped = {} } }, skippedQIDs = {} }
    _G.SlashCmdList = { WOWPRO = function(msg) origSlashed[#origSlashed + 1] = msg end }
    _G.StaticPopupDialogs = { WOWPRO_MISSING_ARROW = { OnShow = function() popupShown = popupShown + 1 end } }
    _G.WoWPro = {
        Guides = { TestGuide = { zone = "Elwynn Forest" } },
        GuideLoaded = true,
        ActiveStep = 1,
        rows = {},
        NextStepNotSticky = function() return nextOpenStep() end,
        ValidZone = function(_, zone) return zone, 1429 end,
        QIDsInTable = function() return false end,
        GetPlayerZonePosition = function() return 0.5, 0.5, 1429 end,
        HBD = { GetZoneDistance = function() return 1000 end },
        CompleteStep = function(i, why) completed[#completed + 1] = { i = i, why = why } end,
        -- WoW-Pro's own (TomTom) mapping, which the addon wraps
        MapPoint = function() origMapped = origMapped + 1 end,
        RemoveMapPoint = function() origRemoved = origRemoved + 1 end,
        dbp = function() end,
        Print = function() end,
    }
    dofile(CORE)
    EF = _G.EasyFind_WoWPro
end)

describe("EasyFind_WoWPro", function()

    describe("ParseCoords", function()
        it("reads every coordinate of a step", function()
            assert.are.same({ { x = 30.5, y = 40.2 }, { x = 31, y = 41 } }, EF.ParseCoords("30.5,40.2;31,41"))
        end)
        it("refuses PLAYER and malformed strings", function()
            assert.is_nil(EF.ParseCoords("PLAYER"))
            assert.is_nil(EF.ParseCoords("abc"))
            assert.is_nil(EF.ParseCoords("150,20"))
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

        local function stepLists(stops)
            local out = {}
            for n, s in ipairs(stops) do out[n] = table.concat(s.steps, "+") end
            return out
        end

        it("leads through every later step that has a spot", function()
            assert.are.same({ "1", "2", "5+6", "7" }, stepLists(EF.BuildStops(1)))
        end)

        it("holds every stop, so arriving clears nothing", function()
            for _, s in ipairs(EF.BuildStops(1)) do assert.is_true(s.hold) end
        end)

        it("leads to a step's final coordinate", function()
            local s = EF.BuildStops(2)[1]
            assert.are.equal(1429, s.mapID)
            assert.is_true(math.abs(s.x - 0.46) < 1e-9 and math.abs(s.y - 0.66) < 1e-9)
        end)

        it("merges steps at the same spot into one stop", function()
            local s = EF.BuildStops(5)[1]
            assert.are.same({ 5, 6 }, s.steps)
            assert.is_truthy(s.step:find("Turn in: Wolves", 1, true))
            assert.is_truthy(s.step:find("Accept: Follow-up", 1, true))
        end)

        it("leaves completed and skipped steps off the path", function()
            guideState().completion[2] = "done"
            guideState().skipped[7] = true
            -- 1, 5 and 6 are now consecutive at the same NPC: one stop.
            assert.are.same({ "1+5+6" }, stepLists(EF.BuildStops(1)))
        end)

        it("caps the trip at max stops when one is set", function()
            assert.are.equal(2, #EF.BuildStops(1, 2))
            assert.are.equal(4, #EF.BuildStops(1, 0))
        end)

        it("marks quest givers and turn-ins for EasyFind's quest icons", function()
            local stops = EF.BuildStops(1)
            assert.are.equal("offer", stops[1].questMark)
            assert.are.equal(11, stops[1].questID)
            assert.are.equal("turnin", stops[3].questMark)
        end)
    end)

    describe("WoW-Pro's MapPoint, wrapped", function()
        before_each(function()
            loadGuide({
                { a = "A", name = "One", map = "10,10", qid = "1" },
                { a = "C", name = "Two", map = "20,20", qid = "1" },
                { a = "T", name = "Three", map = "30,30", qid = "1" },
            })
        end)

        it("sends the whole guide as one quiet EasyFind trip", function()
            WoWPro:MapPoint()
            local trips = sent("navigateTrip")
            assert.are.equal(1, #trips)
            assert.are.equal(3, #trips[1].args[1])
            assert.is_true(trips[1].args[2].quiet)
        end)

        it("does not run WoW-Pro's TomTom mapping while EasyFind is the arrow", function()
            WoWPro:MapPoint()
            assert.are.equal(0, origMapped)
            assert.are.equal(1, origRemoved)   -- old TomTom points go
        end)

        it("sends nothing when the guide has not changed", function()
            WoWPro:MapPoint()
            WoWPro:RemoveMapPoint()
            WoWPro:MapPoint()
            assert.are.equal(1, #sent("navigateTrip"))
        end)

        it("drops a stop only when its step is completed", function()
            WoWPro:MapPoint()
            fire("routeStarted")
            guideState().completion[1] = "Quest accepted"   -- WoW-Pro's refresh maps again
            WoWPro:MapPoint()
            local trips = sent("navigateTrip")
            assert.are.equal(2, #trips)
            assert.are.equal(2, #trips[2].args[1])
            assert.are.same({ 2 }, trips[2].args[1][1].steps)
        end)

        it("clears the route when the guide is finished", function()
            WoWPro:MapPoint()
            for i = 1, 3 do guideState().completion[i] = true end
            WoWPro:MapPoint()
            assert.are.equal(1, #sent("clear"))
        end)

        it("maps a clicked row from that step", function()
            WoWPro.rows[1] = { index = 3 }
            WoWPro:MapPoint(1)
            assert.are.same({ 3 }, sent("navigateTrip")[1].args[1][1].steps)
        end)

        it("does not map a sticky row the player did not click", function()
            WoWPro.sticky[3] = true
            WoWPro.rows[1] = { index = 3 }
            WoWPro:MapPoint(1)
            assert.are.equal(0, #sent("navigateTrip"))
        end)

        it("maps nothing before WoW-Pro has a guide loaded", function()
            WoWPro.GuideLoaded = false
            WoWPro:MapPoint()
            assert.are.equal(0, #sent("navigateTrip"))
        end)
    end)

    describe("WoW-Pro's RemoveMapPoint, wrapped", function()
        before_each(function()
            loadGuide({ { a = "A", name = "One", map = "10,10" } })
        end)

        it("does not clear a route that is mapped again straight away", function()
            WoWPro:MapPoint()
            WoWPro:RemoveMapPoint()
            WoWPro:MapPoint()
            fireTimers(1)
            assert.are.equal(0, #sent("clear"))
        end)

        it("clears when the guide really goes away", function()
            WoWPro:MapPoint()
            WoWPro:RemoveMapPoint()
            fireTimers(1)
            assert.are.equal(1, #sent("clear"))
        end)

        it("still lets WoW-Pro remove its TomTom points", function()
            WoWPro:RemoveMapPoint()
            assert.are.equal(1, origRemoved)
        end)
    end)

    describe("the player's own route wins", function()
        before_each(function()
            loadGuide({
                { a = "A", name = "One", map = "10,10" },
                { a = "A", name = "Two", map = "20,20" },
            })
            WoWPro:MapPoint()
            fire("routeStarted")   -- ours
        end)

        it("pauses when someone else's route starts", function()
            fire("routeStarted")   -- the player's own directions
            guideState().completion[1] = true
            WoWPro:MapPoint()
            assert.are.equal(1, #sent("navigateTrip"))
        end)

        it("takes the arrow back when the player clicks a guide step", function()
            fire("routeStarted")
            WoWPro.rows[1] = { index = 2 }
            WoWPro:MapPoint(1)
            assert.are.equal(2, #sent("navigateTrip"))
        end)

        it("shows the guide again when the player's route is cleared", function()
            fire("routeStarted")
            fire("routeCleared")
            assert.are.equal(2, #sent("navigateTrip"))
        end)
    end)

    describe("a trip EasyFind cannot plan", function()
        it("is sent again with half the stops", function()
            local steps = {}
            for i = 1, 8 do steps[i] = { a = "C", name = "S" .. i, map = (i * 5) .. ",50" } end
            loadGuide(steps)
            WoWPro:MapPoint()
            fireTimers(60)          -- no routeStarted: the plan failed
            local trips = sent("navigateTrip")
            assert.are.equal(2, #trips)
            assert.are.equal(8, #trips[1].args[1])
            assert.are.equal(4, #trips[2].args[1])
        end)

        it("is not resent once it started", function()
            loadGuide({ { a = "A", name = "One", map = "10,10" }, { a = "A", name = "Two", map = "20,20" } })
            WoWPro:MapPoint()
            fire("routeStarted")
            fireTimers(60)
            assert.are.equal(1, #sent("navigateTrip"))
        end)
    end)

    describe("arrival-completed steps (what TomTom's callback did)", function()
        it("completes a CC run-to step within 10 yards", function()
            loadGuide({ { a = "R", name = "Goldshire", map = "42,65", wc = 1 } })
            WoWPro:MapPoint()
            WoWPro.HBD.GetZoneDistance = function() return 8 end
            _G.__ticker.fn()
            assert.are.same({ { i = 1, why = "EasyFind arrival" } }, completed)
        end)

        it("does not complete a quest objective by arriving", function()
            loadGuide({ { a = "C", name = "Kill", map = "42,65", wc = 1 } })
            WoWPro:MapPoint()
            assert.is_nil(_G.__ticker)
            assert.are.same({}, completed)
        end)

        it("waits while the player is further away", function()
            loadGuide({ { a = "R", name = "Goldshire", map = "42,65", wc = 2 } })
            WoWPro:MapPoint()
            WoWPro.HBD.GetZoneDistance = function() return 50 end
            _G.__ticker.fn()
            assert.are.same({}, completed)
        end)
    end)

    describe("switching and falling back to TomTom", function()
        before_each(function()
            loadGuide({ { a = "A", name = "One", map = "10,10" } })
        end)

        it("hands mapping back to WoW-Pro (TomTom) after /wp easyfind off", function()
            SlashCmdList.WOWPRO("easyfind off")
            assert.is_false(EF.Active())
            assert.are.equal(1, origMapped)
            assert.is_true(_G.EasyFind_WoWProCharDB.disabled)
        end)

        it("takes mapping back after /wp easyfind on", function()
            SlashCmdList.WOWPRO("easyfind off")
            SlashCmdList.WOWPRO("easyfind on")
            assert.is_true(EF.Active())
            assert.are.equal(1, #sent("navigateTrip"))
        end)

        it("leaves WoW-Pro's mapping alone without EasyFind installed", function()
            _G.EasyFind = nil
            WoWPro:MapPoint()
            assert.are.equal(1, origMapped)
        end)

        it("passes every other /wp command to WoW-Pro", function()
            SlashCmdList.WOWPRO("where")
            assert.are.same({ "where" }, origSlashed)
        end)

        it("answers /efwp too", function()
            SlashCmdList.EASYFINDWOWPRO("max 12")
            assert.are.equal(12, _G.EasyFind_WoWProCharDB.maxStops)
        end)
    end)

    describe("WoW-Pro's missing-TomTom popup", function()
        local frame
        before_each(function()
            frame = { hidden = false }
            function frame:Hide() self.hidden = true end
        end)

        it("is hidden while EasyFind is the arrow", function()
            StaticPopupDialogs.WOWPRO_MISSING_ARROW.OnShow(frame)
            assert.is_true(frame.hidden)
            assert.are.equal(0, popupShown)
        end)

        it("shows as before when EasyFind is off", function()
            SlashCmdList.WOWPRO("easyfind off")
            StaticPopupDialogs.WOWPRO_MISSING_ARROW.OnShow(frame)
            assert.is_false(frame.hidden)
            assert.are.equal(1, popupShown)
        end)
    end)
end)
