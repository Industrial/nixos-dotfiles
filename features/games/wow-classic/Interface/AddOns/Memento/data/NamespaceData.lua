local addonName, MEM = ...

MEM.Settings = MEM.Settings or {}
MEM.Data = MEM.Data or {}
MEM.State = MEM.State or {}
MEM.Modules = MEM.Modules or {}

MEM.Modules.Capture = MEM.Modules.Capture or {}
MEM.Modules.Options = MEM.Modules.Options or {}
MEM.Modules.Utils = MEM.Modules.Utils or {}

MEM.State.totalTimePlayed = 0
MEM.State.timePlayedThisLevel = 0
MEM.State.timePlayedInitialized = false

local AWL = ArcaneWizardLibrary

AWL:NewAddon(addonName)
