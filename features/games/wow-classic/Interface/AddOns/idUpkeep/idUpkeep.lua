-- Root of idUpkeep: a plain Node keyed "idUpkeep" (it creates idUpkeepDB and starts on
-- PLAYER_LOGIN / PLAYER_ENTERING_WORLD) with the Upkeep module as its one child.
local root=_G.idUpkeep_Node(nil,"idUpkeep")
_G.idUpkeep=root
root.Upkeep=_G.idUpkeep_Upkeep(root,"Upkeep")
SLASH_IDUPKEEP1="/idupkeep"
SlashCmdList.IDUPKEEP=function()for _,l in ipairs(root.Upkeep:explainLines())do print(l)end end
