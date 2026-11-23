local f=CreateFrame("Frame")f:RegisterEvent("PLAYER_LEVEL_UP")f:SetScript("OnEvent",function()C_Timer.After(1,Screenshot)end)
