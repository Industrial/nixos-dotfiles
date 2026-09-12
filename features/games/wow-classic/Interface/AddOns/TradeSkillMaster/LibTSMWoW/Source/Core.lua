-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local ADDON_TABLE = select(2, ...)
ADDON_TABLE.LibTSMWoW = ADDON_TABLE.LibTSMCore.NewComponent("LibTSMWoW")
	:AddDependency("LibTSMUtil")

if not CASTING_BAR_ALPHA_STEP then
	CASTING_BAR_ALPHA_STEP = 0.05
end
