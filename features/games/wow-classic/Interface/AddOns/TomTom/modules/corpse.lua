--[[-------------------------------------------------------------------------
--  Simple module for TomTom that creates a waypoint for your corpse
--  if you happen to die.  No humor, no frills, just straightforward
--  corpse arrow.  Based on code written and adapted by Yssarill.
-------------------------------------------------------------------------]]--

local addonName, addon = ...
local TomTom = addon
local L = addon.L
addon.private = addon.private or {}
local private = addon.private
local module = {enableSetting = {"general", "corpse_arrow"}}
private.AddModule(module, "Corpse")

local pollFrame

-- Local variables to store map, x, y and uid or corpse waypoint
local m,x,y,uid

private.AddSettingsSection{
    page = "main", order = 20, settingsKey = "general",
    feature = {
        name = L["Automatically set a waypoint when I die"],
        tooltip = L["TomTom can automatically set a waypoint when you die, guiding you back to your corpse"],
        path = "general.corpse_arrow",
    },
    rows = {},
}

local function StartCorpseSearch()
    if not IsInInstance() then
        pollFrame:Show()
    end
end

local function ClearCorpseArrow()
    if uid then
        TomTom:RemoveWaypoint(uid)
        m,x,y,uid = nil, nil, nil, nil
    end
end

local function GetCorpseLocation()
    -- If the player isn't dead or a ghost, drop out
    if not UnitIsDeadOrGhost("player") then
        if m or x or y then
            ClearCorpseArrow()
        end
    end

    -- Cache the result so we don't scan the maps multiple times
    if m and x and y then
        return m, x, y
    end

    --  See if the player corpse is on the current map
    local om = C_Map.GetBestMapForUnit("player")
    if not om then return nil; end
    local corpse = C_DeathInfo.GetCorpseMapPosition(om)
    if not corpse then return nil; end
    local cx, cy = corpse:GetXY()
    if cx ~= 0 and cy ~= 0 then
        m = om
        x = cx
        y = cy
    end
    return m, x, y
end

local function SetCorpseArrow()
    if m and x and y then
        uid = TomTom:AddWaypoint(m, x, y, {
            title = L["My Corpse"],
            persistent = false,
			corpse = true,
        })
        return uid
    end
end

local counter, throttle = 0, 0.5
local function OnUpdate(self, elapsed)
    counter = counter + elapsed
    if counter < throttle then
        return
    end
    counter = 0
    if GetCorpseLocation() and SetCorpseArrow() then
        self:Hide()
    end
end

function module:OnInitialize()
    pollFrame = CreateFrame("Frame")
    pollFrame:Hide()
    pollFrame:SetScript("OnUpdate", OnUpdate)
end

function module:OnEnable()
    self:RegisterEvent("PLAYER_ALIVE")
    self:RegisterEvent("PLAYER_DEAD")
    self:RegisterEvent("PLAYER_UNGHOST")
    if UnitIsDeadOrGhost("player") then
        StartCorpseSearch()
    end
end

function module:OnDisable()
    pollFrame:Hide()
    self:UnregisterEvent("PLAYER_ALIVE")
    self:UnregisterEvent("PLAYER_DEAD")
    self:UnregisterEvent("PLAYER_UNGHOST")
    ClearCorpseArrow()
    m, x, y = nil, nil, nil
end

function module:PLAYER_ALIVE()
    if UnitIsDeadOrGhost("player") then
        StartCorpseSearch()
    else
        ClearCorpseArrow()
    end
end

function module:PLAYER_DEAD()
    m = C_Map.GetBestMapForUnit("player")
    if not IsInInstance() then
        x = nil
        y = nil
        local player = C_Map.GetPlayerMapPosition(m, "player")
        if player then
            x,y = player:GetXY()
        end
    end
    StartCorpseSearch()
end

function module:PLAYER_UNGHOST()
    ClearCorpseArrow()
end
