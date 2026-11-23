local f=CreateFrame("Frame")f:RegisterEvent("CINEMATIC_START")f:SetScript("OnEvent",function(_,_,c)if c then StopCinematic()end end)
