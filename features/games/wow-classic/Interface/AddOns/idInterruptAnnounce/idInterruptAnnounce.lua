-- Says in group chat which spell you or your pet interrupted. Solo, it stays quiet.
local f=CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent",function()
  local _,event,_,source,_,_,_,_,target,_,_,_,_,_,_,spell=CombatLogGetCurrentEventInfo()
  if event~="SPELL_INTERRUPT"or(source~=UnitGUID("player")and source~=UnitGUID("pet"))then return end
  local channel=IsInGroup(LE_PARTY_CATEGORY_INSTANCE)and"INSTANCE_CHAT"or IsInRaid()and"RAID"or IsInGroup()and"PARTY"
  if channel then SendChatMessage("Interrupted "..(target or"?").."'s "..spell,channel)end
end)
