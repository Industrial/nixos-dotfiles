---@type string, AddonNS
local _, addon = ...

addon.data.tbc = {
    {28585}, -- Ruby Slippers
    {29796}, -- Socrethar's Teleportation Stone
    {30542}, -- Dimensional Ripper - Area 52
    {30544}, -- Ultrasafe Transporter - Toshley's Station
    {32757}, -- Blessed Medallion of Karabor
    {35230}, -- Darnarian's Scroll of Teleportation
    {37118}, -- Scroll of Recall
    {37863}, -- Direbrew's Remote
    {184871, condition = addon.isNotRetail}, -- Dark Portal (TBC)
}
