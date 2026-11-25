-- Says in group chat who broke your crowd control. The combat log only reports "broken" for auras that break on damage, so no spell list is needed: any such aura of yours counts.
local mine,f={},CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent",function()
  local _,event,_,source,breaker,_,_,dest,target,_,_,_,aura,_,_,with=CombatLogGetCurrentEventInfo()
  if not aura or event:sub(1,11)~="SPELL_AURA_"then return end
  local key=dest..aura
  if event=="SPELL_AURA_APPLIED"and source==UnitGUID("player")then mine[key]=true
  elseif event=="SPELL_AURA_REMOVED"then mine[key]=nil
  elseif(event=="SPELL_AURA_BROKEN"or event=="SPELL_AURA_BROKEN_SPELL")and mine[key]then
    mine[key]=nil
    local channel=IsInGroup(LE_PARTY_CATEGORY_INSTANCE)and"INSTANCE_CHAT"or IsInRaid()and"RAID"or IsInGroup()and"PARTY"
    if channel then SendChatMessage((breaker or"Something").." broke my "..aura.." on "..(target or"?")..(with and" with "..with or""),channel)end
  end
end)
