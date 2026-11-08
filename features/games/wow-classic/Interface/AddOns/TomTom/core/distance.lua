--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- The distance service: the vector from the player to an active waypoint,
-- and the `callbacks.distance` functions. It does not use the pins, so a
-- waypoint with no minimap or world map pin still gets its distance
-- callbacks (docs/integrations.md 3.4 item 4).

local _, addon = ...
local TomTom = addon
local hbd = addon.hbd
addon.private = addon.private or {}
local private = addon.private
local errorHandler = geterrorhandler()

-- One record per active uid. A record is never reused for a different uid,
-- so a callback that removes its waypoint and adds the next one cannot give
-- its old state to the new waypoint (B25).
local active = {}

local THROTTLE = 0.1

local ticker = CreateFrame("Frame")
ticker:Hide()

local function SortedRanges(callbacks)
    if not (callbacks and callbacks.distance) then return nil end
    local ranges = {}
    for range in pairs(callbacks.distance) do
        table.insert(ranges, range)
    end
    if #ranges == 0 then return nil end
    table.sort(ranges)
    return ranges
end

-- The index of the smallest range that contains the distance, or -1.
local function RangeIndex(ranges, dist)
    for index = 1, #ranges do
        if dist <= ranges[index] then
            return index
        end
    end
    return -1
end

-- The number of active records with ranges. The ticker runs only while
-- it is above zero.
local withRanges = 0

local function SetRecord(uid, record)
    local old = active[uid]
    if old and old.ranges then withRanges = withRanges - 1 end
    if record and record.ranges then withRanges = withRanges + 1 end
    active[uid] = record
    ticker:SetShown(withRanges > 0)
end

local function WorldPosition(uid)
    return hbd:GetWorldCoordinatesFromZone(uid[2], uid[3], uid[1])
end

local function RunCallbacks(uid, record, px, py, pInstance)
    local pointX, pointY, pointInstance = WorldPosition(uid)
    if not pointX or pointInstance ~= pInstance then return end

    local _, dist = hbd:GetWorldVector(pInstance, px, py, pointX, pointY)
    if not dist then return end

    local ranges = record.ranges
    local index = RangeIndex(ranges, dist)

    -- On the first tick the state is nil, so the callback for the current
    -- range fires once, with lastdist nil.
    if record.state ~= index then
        local range = ranges[index]
        local callback = range and record.callbacks.distance[range]
        record.state = index
        if callback then
            xpcall(callback, errorHandler, "distance", uid, range, dist, record.lastdist)
        end
    end

    record.lastdist = dist
end

local elapsedSinceTick = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceTick = elapsedSinceTick + elapsed
    if elapsedSinceTick < THROTTLE then return end
    elapsedSinceTick = 0

    local px, py, pInstance = hbd:GetPlayerWorldPosition()
    if not px or not py then return end

    -- A callback can remove waypoints and add new ones (Routes does this),
    -- so walk a copy. A waypoint added during the tick runs on the next one.
    local snapshot = {}
    for uid, record in pairs(active) do
        if record.ranges then
            snapshot[uid] = record
        end
    end

    for uid, record in pairs(snapshot) do
        if active[uid] == record then
            RunCallbacks(uid, record, px, py, pInstance)
        end
    end
end)

-- Adds a waypoint to the active set, with a new record. Calling it again
-- for the same uid starts its distance state again.
function private.TrackDistance(uid, callbacks)
    SetRecord(uid, {
        callbacks = callbacks,
        ranges = SortedRanges(callbacks),
    })
end

function private.UntrackDistance(uid)
    if active[uid] then
        SetRecord(uid, nil)
    end
end

function TomTom:GetVectorToWaypoint(uid)
    if not active[uid] then return end

    local x, y, instance = hbd:GetPlayerWorldPosition()
    if not x or not y then return end

    local pointX, pointY, pointInstance = WorldPosition(uid)
    if instance ~= pointInstance then return end

    return hbd:GetWorldVector(instance, x, y, pointX, pointY)
end

function TomTom:GetDistanceToWaypoint(uid)
    local _, distance = self:GetVectorToWaypoint(uid)
    return distance
end

function TomTom:GetDirectionToWaypoint(uid)
    local angle = self:GetVectorToWaypoint(uid)
    return angle
end
