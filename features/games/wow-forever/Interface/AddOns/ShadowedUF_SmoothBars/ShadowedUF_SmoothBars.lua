local LibSmooth = LibStub("LibSmoothStatusBar-1.0")
local SmoothBar = select(2, ...)
ShadowUF:RegisterModule(SmoothBar, "smoothBar", "Smooth Bar")

-- Initialize addon
function SmoothBar:OnInitialize()	
	-- Enable on all unit frames by default
	for _, unit in pairs(ShadowUF.unitList) do
		ShadowUF.db.profile.units[unit].smoothBar = ShadowUF.db.profile.units[unit].smoothBar or { enabled = true }
	end
end

-- Enable LibSmooth on frame
function SmoothBar:OnEnable(frame)
	if frame.healthBar then LibSmooth:SmoothBar(frame.healthBar) end
	if frame.powerBar then LibSmooth:SmoothBar(frame.powerBar) end
end

-- Disable LibSmooth on frame
function SmoothBar:OnDisable(frame)
	if frame.healthBar then LibSmooth:ResetBar(frame.healthBar) end
	if frame.powerBar then LibSmooth:ResetBar(frame.powerBar) end
end

-- Initialize configuration screen
function SmoothBar:OnConfigurationLoad()
	ShadowUF.Config.unitTable.args.general.args.smoothBar = {
		type = "group",
		inline = true,
		name = "SmoothBar",
		args = {
			smoothBar = {
				order = 0,
				type = "toggle",
				name = SmoothBar.L["Enable SmoothBar"],
				desc = SmoothBar.L["Enables smooth health and power bar animation"],
				arg = "smoothBar.enabled",
			},
		}
	}
end
