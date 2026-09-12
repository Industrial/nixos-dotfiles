local addonName, PVPSC = ...

local function PSC_RegisterSlashCommands()
    SLASH_PVPSTATSCLASSIC1 = "/pvpstatsclassic"
    SLASH_PVPSTATSCLASSIC2 = "/psc"
    SlashCmdList["PVPSTATSCLASSIC"] = PSC_SlashCommandHandler
end

local function PSC_InitializeNetwork()
    -- Initialize network handler after a short delay to ensure everything is loaded
    C_Timer.After(2, function()
        if PVPSC.Network and PVPSC.Network.Initialize then
            PVPSC.Network:Initialize()
        end
    end)
end

local function Main()
    PSC_RegisterEvents()
    PSC_RegisterSlashCommands()
    PSC_InitializeNetwork()
end

Main()
