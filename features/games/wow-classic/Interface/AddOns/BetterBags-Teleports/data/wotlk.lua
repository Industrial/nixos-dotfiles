---@type string, AddonNS
local _, addon = ...

addon.data.wotlk = {
    {40585}, -- Signet of the Kirin Tor
    {40586}, -- Band of the Kirin Tor
    {43824}, -- The Schools of Arcane Magic - Mastery (spires atop the Violet Citadel)
    {44314}, -- Scroll of Recall II
    {44315}, -- Scroll of Recall III
    {44934}, -- Loop of the Kirin Tor
    {44935}, -- Ring of the Kirin Tor
    {45688}, -- Inscribed Band of the Kirin Tor
    {45689}, -- Inscribed Loop of the Kirin Tor
    {45690}, -- Inscribed Ring of the Kirin Tor
    {45691}, -- Inscribed Signet of the Kirin Tor
    {46874}, -- Argent Crusader's Tabard
    {48933}, -- Wormhole Generator: Northrend
    {48954}, -- Etched Band of the Kirin Tor
    {48955}, -- Etched Loop of the Kirin Tor
    {48956}, -- Etched Ring of the Kirin Tor
    {48957}, -- Etched Signet of the Kirin Tor
    {50287}, -- Boots of the Bay
    {51557}, -- Runed Signet of the Kirin Tor
    {51558}, -- Runed Loop of the Kirin Tor
    {51559}, -- Runed Ring of the Kirin Tor
    {51560}, -- Runed Band of the Kirin Tor
    {52251}, -- Jaina's Locket
    {54452}, -- Ethereal Portal
    {199335, condition = addon.isNotRetail}, -- Teleport Scroll: Menethil Harbor
    {199336, condition = addon.isNotRetail}, -- Teleport Scroll: Stormwind Harbor
    {199777, condition = addon.isNotRetail}, -- Teleport Scroll: Orgrimmar Zepplin Tower
    {199778, condition = addon.isNotRetail}, -- Teleport Scroll: Undercity Zepplin Tower
    {200068, condition = addon.isNotRetail}, -- Teleport Scroll: Shattrath City
}
