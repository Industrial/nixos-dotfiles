-- Spoken's map button on Classic Era and Anniversary: against the map
-- window's edge, a side tab's place, instead of floating beside it. The
-- window's close button marks the true corner there, with EasyFind's side
-- panel open too, so the button hangs under it. Forever's button is the
-- client's side tab template, placed by Spoken, and stays its own.
local _, ns = ...
if not ns.KEY then return end

local TUCK, TOP_GAP = 4, 4
local placing

local function Place(toggle)
    if placing or toggle.fillToInterior then return end
    local wmf = _G.WorldMapFrame
    local mini = wmf and wmf.MiniBorderFrame
    local close = _G.WorldMapFrameCloseButton
    if not (mini and mini:IsShown() and close and close:IsShown() and toggle:GetParent() == wmf) then return end
    placing = true
    toggle:ClearAllPoints()
    toggle:SetPoint("TOPLEFT", close, "BOTTOMRIGHT", -TUCK, -TOP_GAP)
    placing = false
end
ns.PlaceMapButton = Place

-- Spoken places the button on every map layout: ours follows each time.
local function Watch()
    local toggle = _G.SpokenPlacesPanelToggle
    if not toggle or toggle._efPlaced then return end
    toggle._efPlaced = true
    hooksecurefunc(toggle, "SetPoint", Place)
    Place(toggle)
end
ns.WatchMapButton = Watch

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    Watch()
    local wmf = _G.WorldMapFrame
    if wmf and wmf.HookScript then wmf:HookScript("OnShow", Watch) end
end)
