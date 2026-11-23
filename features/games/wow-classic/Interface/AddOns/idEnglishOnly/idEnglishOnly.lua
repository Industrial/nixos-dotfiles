-- Hides non-English lines in chat channels (General, Trade, LFG, custom); say, guild, party, whispers untouched.
local W={}for w in("und ich nicht der das ist mit noch auch wer kann bitte hallo jemand sind haben eine oder suche gruppe je est les pas une des qui avec cherche bonjour merci oui vous mais que los las para por una hola alguien busco gracias esta tengo pero che sono ciao cerco grazie della het een ik niet zoek ook maar nie jest szukam kto"):gmatch("%S+")do W[w]=true end
local function f(_,_,m)
  local t=m:gsub("|H.-|h.-|h",""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|T.-|t","")
  if t:find("[\128-\255]")then return true end
  local n=0 for w in t:lower():gmatch("%a+")do if W[w]then n=n+1 if n>1 then return true end end end
end
(ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter)("CHAT_MSG_CHANNEL",f)
