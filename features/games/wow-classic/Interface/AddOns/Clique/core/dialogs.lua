--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]]--

---@class CliqueAddon: AddonCore
local addon = select(2, ...)

local L = addon.L

-- Shared StaticPopup dialogs. Pages and option panels reference these by key
-- rather than defining their own, so a single prompt can be reused anywhere.
addon.dialogs = {
    SETTING_RELOAD = "CLIQUE_SETTING_RELOAD",
}

-- Some settings (e.g. the frame denylist) can't be safely reversed at runtime,
-- so they take effect on reload. The setting is saved immediately; this just
-- confirms the reload.
StaticPopupDialogs[addon.dialogs.SETTING_RELOAD] = {
    text = L["Clique: This change requires a UI reload to take effect."],
    button1 = L["Reload Now"],
    button2 = L["Later"],
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function addon:ConfirmSettingReload()
    StaticPopup_Show(self.dialogs.SETTING_RELOAD)
end
