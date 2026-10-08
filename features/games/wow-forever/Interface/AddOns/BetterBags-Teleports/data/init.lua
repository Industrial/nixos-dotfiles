-- Shared setup for the per-expansion data files. Must load before any of them.
-- Not used on WoW: Forever; data/forever.lua is standalone there.
---@type string, AddonNS
local _, addon = ...

addon.data = {}

-- Item condition: classic-only items that must stay hidden on retail.
function addon.isNotRetail()
    return not addon.data.isRetail
end

addon.data.enablePortalReagents = {
    {17031}, -- Rune of Teleportation
    {17032}, -- Rune of Portals
}
