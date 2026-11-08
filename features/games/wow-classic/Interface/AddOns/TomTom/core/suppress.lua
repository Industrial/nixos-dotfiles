--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- The feature-suppress API (decision D13, docs/integrations.md section 5).
-- Another addon can tell TomTom to stand down for one session. The saved
-- settings do not change, and nothing is saved: the owner calls
-- SuppressFeature again in each session.

local _, addon = ...
local TomTom = addon
addon.private = addon.private or {}
local private = addon.private

-- apply runs when the state of the feature changes. Methods go through the
-- addon table, because other addons replace them (integrations.md 3.4).
local FEATURES = {
    poi = {
        module = "QuestObjectives",
        apply = function() TomTom:EnableDisablePOIIntegration() end,
    },
    ["arrow.setclosest"] = {},
}

local owners = {}  -- feature -> {[owner] = true}

local function CheckFeature(feature)
    if not FEATURES[feature] then
        error(("TomTom: unknown feature %q"):format(tostring(feature)), 3)
    end
end

local function CheckOwner(owner)
    if type(owner) ~= "string" or owner == "" then
        error("TomTom: the owner must be a non-empty string", 3)
    end
end

local function IsSuppressed(feature)
    return owners[feature] ~= nil and next(owners[feature]) ~= nil
end

-- Before ADDON_LOADED there is no profile, and a replaced method (Kaliel's
-- Tracker) can write to it. The modules read the suppression when they
-- start at login, so the apply can wait.
local function Changed(feature)
    local apply = FEATURES[feature].apply
    if apply and TomTom.db then
        xpcall(apply, geterrorhandler())
    end
    TomTom:FireMessage("TOMTOM_FEATURE_SUPPRESSION_CHANGED", feature)
end

function TomTom:SuppressFeature(owner, feature)
    CheckOwner(owner)
    CheckFeature(feature)
    local set = owners[feature] or {}
    owners[feature] = set
    if set[owner] then return end
    local wasSuppressed = IsSuppressed(feature)
    set[owner] = true
    if not wasSuppressed then
        Changed(feature)
    end
end

function TomTom:ReleaseFeature(owner, feature)
    CheckOwner(owner)
    CheckFeature(feature)
    local set = owners[feature]
    if not (set and set[owner]) then return end
    set[owner] = nil
    if not IsSuppressed(feature) then
        Changed(feature)
    end
end

-- Returns true and a sorted list of the owners, or false and an empty list.
function TomTom:IsFeatureSuppressed(feature)
    CheckFeature(feature)
    local list = {}
    for owner in pairs(owners[feature] or {}) do
        table.insert(list, owner)
    end
    table.sort(list)
    return #list > 0, list
end

-- For core/modules.lua: a suppressed module does not run.
function private.IsModuleSuppressed(module)
    for feature, info in pairs(FEATURES) do
        if info.module == module.name and IsSuppressed(feature) then
            return true
        end
    end
    return false
end

function private.IsFeatureSuppressed(feature)
    return IsSuppressed(feature)
end

-- The owners as one line of text, for the settings rows.
function private.FeatureOwnersText(feature)
    local _, list = TomTom:IsFeatureSuppressed(feature)
    return table.concat(list, ", ")
end

-- The arrow moves to the closest waypoint when its target clears.
function private.ShouldSetClosest()
    return TomTom.profile.arrow.setclosest and not IsSuppressed("arrow.setclosest")
end
