-- Says in group chat which spell you or your pet interrupted. Solo, it stays quiet.
-- The combat log is protected on this client, so this reads UNIT_SPELLCAST_INTERRUPTED, whose 4th argument is the interrupter's GUID.
-- It fires once per unit token showing the caster (target, focus, nameplateN), hence the castGUID check. Where the game hides the values (secret), it stays quiet.
local secret,last=issecretvalue or function()end
local f=CreateFrame("Frame")
f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
f:SetScript("OnEvent",function(_,_,unit,cast,spell,by)
  if not by or secret(by)or secret(cast)or secret(spell)or cast==last then return end
  if by~=UnitGUID("player")and by~=UnitGUID("pet")then return end
  last=cast
  local name,spellName=UnitName(unit),(C_Spell and C_Spell.GetSpellName or GetSpellInfo)(spell)
  if secret(name)or secret(spellName)then return end
  local channel=IsInGroup(LE_PARTY_CATEGORY_INSTANCE)and"INSTANCE_CHAT"or IsInRaid()and"RAID"or IsInGroup()and"PARTY"
  if channel then SendChatMessage("Interrupted "..(name or"?").."'s "..(spellName or"?"),channel)end
end)
