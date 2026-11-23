local f=CreateFrame("Frame")f:RegisterEvent("PLAYER_LEVEL_UP")f:SetScript("OnEvent",function(_,_,l)if IsInGuild()then SendChatMessage("Ding "..l.."!","GUILD")end end)
