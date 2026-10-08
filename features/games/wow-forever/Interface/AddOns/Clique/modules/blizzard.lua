--[[-------------------------------------------------------------------------
-- Blizzard.lua
--
-- Blizzard frame integration for all WoW versions.
-------------------------------------------------------------------------]]--

---@class CliqueAddon: AddonCore
local addon = select(2, ...)

---------------------------------------------------------------------------------
-- Called by the main addon during initialization
-------------------------------------------------------------------------------

function addon:RegisterFrameByName(name, parentKey)
    local frame = _G[name]
    if not frame then
        --self:Printf("Tried to register frame '%s' but it doesn't exist", tostring(name))
        return
    elseif frame and parentKey and frame[parentKey] then
        self:RegisterUnitFrame(frame[parentKey])
    else
        self:RegisterUnitFrame(frame)
    end
end

-- Some frames in 12.0.5 no longer allow SetPropagateMouseMotion
local debugPropagation = false

local function isFrameForbidden(frame)
    local ok, result = pcall(function() return frame.IsForbidden and frame:IsForbidden() end)
    return not ok or result
end

local function trySetPropagateMouseMotion(frame, label)
    if not frame then return end

    if isFrameForbidden(frame) then
        if debugPropagation then addon:Printf("SetPropagateMouseMotion skipped for %s: forbidden", label) end
        return
    end

    local ok, err = pcall(frame.SetPropagateMouseMotion, frame, true)
    if not ok and debugPropagation then
        addon:Printf("SetPropagateMouseMotion failed for %s: %s", label, err)
    end
end

local mouseMotionQueue = {}
local mouseMotionSet = {}
local function combatSafeSetPropagateMotion(frame, label)
    if not frame or mouseMotionSet[frame] then return end

    if InCombatLockdown() then
        mouseMotionQueue[frame] = mouseMotionQueue[frame] or label
    else
        mouseMotionSet[frame] = true
        trySetPropagateMouseMotion(frame, label)
    end
end

local function leavingCombat()
    local pending = mouseMotionQueue
    mouseMotionQueue = {}
    for frame, label in pairs(pending) do
        trySetPropagateMouseMotion(frame, label)
        mouseMotionSet[frame] = true
    end
end

addon:RegisterEvent("PLAYER_REGEN_ENABLED", leavingCombat)

function addon:SetPropagateMouseMotionByName(name, parentKey)
    local frame = _G[name]
    if not frame then
        --self:Printf("Tried to set propagate motion for '%s' but it doesn't exist", tostring(name))
        return
    elseif frame and parentKey and frame[parentKey] then
        combatSafeSetPropagateMotion(frame[parentKey], name .. "." .. parentKey)
    else
        combatSafeSetPropagateMotion(frame, name)
    end
end

local frameElementsConfig = {
    -- PlayerFrame variants
    ["PlayerFrame-Classic"] = {
        {configType = "global", name = "PlayerFrameHealthBar"},
        {configType = "global", name = "PlayerFrameManaBar"},
    },
    ["PlayerFrame-Retail"] = {
        {configType = "parentkey", "PlayerFrameContent", "PlayerFrameContentMain", "HealthBarsContainer", "HealthBar"},
        {configType = "parentkey", "PlayerFrameContent", "PlayerFrameContentMain", "ManaBarArea", "ManaBar"},
    },

    -- Target Frame variants
    ["TargetFrame-Classic"] = {
        -- Just a note, these don't actually seem to do anything, unfortunately
        {configType = "global", name = "TargetFrameHealthBar"},
        {configType = "global", name = "TargetFrameManaBar"},
    },
    ["TargetFrame-Retail"] = {
        {configType = "parentkey", "TargetFrameContent", "TargetFrameContentMain", "HealthBarsContainer", "HealthBar"},
        {configType = "parentkey", "TargetFrameContent", "TargetFrameContentMain", "ManaBar"},
    },

    -- PetFrame doesn't have anything, but config it here anyway
    ["PetFrame"] = {},

   -- Focus Frame
    ["FocusFrame-Retail"] = {
        {configType = "parentkey", "TargetFrameContent", "TargetFrameContentMain", "HealthBarsContainer", "HealthBar"},
        {configType = "parentkey", "TargetFrameContent", "TargetFrameContentMain", "ManaBar"},
    },

    -- Focus Frame variants
    ["FocusFrame-Classic"] = {
        {configType = "global", name = "FocusFrameHealthBar"},
        {configType = "global", name = "FocusFrameManaBar"},
    },

    -- Target of Target
    ["TargetFrameToT-Retail"] = {
        {configType = "parentkey", "HealthBar"},
        {configType = "parentkey", "ManaBar"},
    },

    ["TargetFrameToT-Classic"] = {
        -- Again these don't seem to do anything
        {configType = "global", name = "TargetFrameToTHealthBar"},
        {configType = "global", name = "TargetFrameToTManaBar"},
    },

    -- Focus Frame Target of Target
    ["FocusFrameToT-Retail"] = {
        {configType = "parentkey", "HealthBar"},
        {configType = "parentkey", "ManaBar"},
    },
    ["FocusFrameToT-Classic"] = {
        -- These don't seem to do anything, but just in case
        {configType = "global", name = "TargetFrameToTHealthBar"},
        {configType = "global", name = "TargetFrameToTManaBar"},
    },
}

function addon:GetFrameConfig(name)
    local isRetail = addon:ProjectIsRetail()

    if name == "PlayerFrame" and isRetail then
        return frameElementsConfig["PlayerFrame-Retail"]
    elseif name == "PlayerFrame" then
        return frameElementsConfig["PlayerFrame-Classic"]
    elseif name == "TargetFrame" and isRetail then
        return frameElementsConfig["TargetFrame-Retail"]
    elseif name == "TargetFrame" then
        return frameElementsConfig["TargetFrame-Classic"]
    elseif name == "FocusFrame" and isRetail then
        return frameElementsConfig["FocusFrame-Retail"]
    elseif name == "FocusFrame" then
        return frameElementsConfig["FocusFrame-Classic"]
    elseif name == "TargetFrameToT" and isRetail then
        return frameElementsConfig["TargetFrameToT-Retail"]
    elseif name == "TargetFrameToT" then
        return frameElementsConfig["TargetFrameToT-Classic"]
    elseif name == "FocusFrameToT" and isRetail then
        return frameElementsConfig["FocusFrameToT-Retail"]
    elseif name == "FocusFrameToT" then
        return frameElementsConfig["FocusFrameToT-Classic"]
    else
        return frameElementsConfig[name]
    end
end

function addon:WalkChildrenAndSetPropagate(frame, name)
    local config = self:GetFrameConfig(name)

    if not config then
        self:Printf("Tried to walk children for '%s' but no config", tostring(name))
        return
    end

    for _, path in ipairs(config) do
        local current = frame
        local label

        if path.configType == "parentkey" then
            local pathBits = {name}
            for _, bit in ipairs(path) do
                if current then
                    current = current[bit]
                    table.insert(pathBits, bit)
                else
                    self:Printf("Tried to walk to key '%s' for frame '%s' but was nil", tostring(bit), tostring(name))
                end
            end
            label = table.concat(pathBits, ".")
        elseif path.configType == "global" then
            current = _G[path.name]
            label = path.name
            if not current then
                self:Printf("Tried to walk to global '%s' for frame '%s' but was nil", tostring(path.name), tostring(name))
            end
        end

        if current then
            combatSafeSetPropagateMotion(current, label)
        end
    end
end

function addon:IntegrateBlizzardFrames()
    local settings = self.settings.blizzframes

    local frameNames = {
        "PlayerFrame",
        "TargetFrame",
        "TargetFrameToT",
        "FocusFrame",
        "FocusFrameToT",
    }

    for _, name in ipairs(frameNames) do
        local frame = _G[name]

        if not frame then
            --self:Printf("Failed to find frame '%s", name)
        elseif settings[name] then
            --self:Printf("Registering '%s'", name)
            if frame then
                self:RegisterUnitFrame(frame)
                self:WalkChildrenAndSetPropagate(frame, name)
            end
        else
            --self:Printf("Skipping '%s' because its disabled", name)
        end
    end

    -- Custom handle the pet frame
    self:RegisterFrameByName("PetFrame")

    -- Boss frames (there may be up to five right now)
    if settings.boss then
        for idx = 1, 5 do
            local name = string.format("Boss%dTargetFrame", idx)
            local frame = _G[name]
            if frame then
                self:RegisterUnitFrame(frame)
            end
        end
    end

    -- Arena frames (maybe load on demand)
    local hasArenaFrames = (_G["ArenaEnemyFrame1"] ~= nil)
    if settings.arena and hasArenaFrames then
        for idx = 1, 5 do
            local name = string.format("ArenaEnemyFrame%d", idx)
            self:RegisterFrameByName(name)
        end
    elseif settings.arena then
        -- Register for load on demand

        local arenaEventHandler;
        arenaEventHandler = function(_, arg1)
            if arg1 == "Blizzard_ArenaUI" then
                self:UnregisterEvent("ADDON_LOADED", arenaEventHandler)
                for idx = 1, 5 do
                    local name = string.format("ArenaEnemyFrame%d", idx)
                    self:RegisterFrameByName(name)
                end
            end
        end

        addon:RegisterEvent("ADDON_LOADED", arenaEventHandler)
    end

    -- Standard party frames
    local PartyFrame = _G["PartyFrame"]
    if settings.party and PartyFrame and PartyFrame.PartyMemberFramePool then
        local index = 1

        for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
            addon:RegisterUnitFrame(frame)
            addon:RegisterUnitFrame(frame.PetFrame)

            index = index + 1
        end

    -- Classic style party frames
    elseif settings.party then
        for idx = 1, 4 do
            local name = string.format("PartyMemberFrame%d", idx)
            local petFrameName = name .. "PetFrame"
            self:RegisterFrameByName(name)
            self:RegisterFrameByName(petFrameName)
        end
    end

    -- Handle the compact unit frames here
    if settings.compactraid then
        hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame)
            if isFrameForbidden(frame) then return end

            local name = frame:GetName()
            if type(name) ~= "string" then return end

            if name:match("^NamePlate") then return end

            for idx = 1, 6 do
                -- Grab the buffs and debuffs
                addon:SetPropagateMouseMotionByName(name .. "Buff" .. idx)
                addon:SetPropagateMouseMotionByName(name .. "Debuff" .. idx)
                addon:SetPropagateMouseMotionByName(name .. "DispelDebuff" .. idx)
            end

            addon:SetPropagateMouseMotionByName(name .. "CenterStatusIcon")
            addon:SetPropagateMouseMotionByName(name .. "Icon")

            addon:RegisterUnitFrame(frame)
        end)

        -- CompactUnitFrame_SetUnit clobbers our routing on every unit change, so
        -- reassert it afterwards. See ReassertFrameClickRouting.
        if CompactUnitFrame_SetUnit then
            hooksecurefunc("CompactUnitFrame_SetUnit", function(frame)
                if addon.proxies[frame] then
                    addon:ReassertFrameClickRouting(frame)
                end
            end)
        end
    end
end
