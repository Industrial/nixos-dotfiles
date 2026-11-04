-- Only parse if matching locale
if( GetLocale() ~= "deDE" ) then return end

local SmoothBar = select(2, ...)
local L = {}

L["Enable SmoothBar"] = "SmoothBar aktivieren"
L["Enables smooth health and power bar animation"] = "Aktiviert gleichmäßige Lebensleiste und Energieleiste Animation"

SmoothBar.L = L
