local _, ns = ...

local Rows = ns.ResultRows


Rows.outfitCdStart = Rows.outfitCdStart or 0
Rows.outfitCdDuration = Rows.outfitCdDuration or 0

function Rows:GetOutfitCooldownState()
    return Rows.outfitCdStart, Rows.outfitCdDuration, Rows.lastEquippedOutfitID
end

function Rows:IsOutfitCooldownActive()
    return Rows.outfitCdStart > 0 and Rows.outfitCdDuration - (GetTime() - Rows.outfitCdStart) > 0
end
