local addonName = ...;

---@class BetterBags_Legendary: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

addon.config = {}
addon.config.textColor = {0.75, 0.75, 0.75}

-- [[ Classes descriptions ]] --
---@class (exact) FrameLayoutOptions
---@field bottom number
---@field left number
---@field right number
---@field top number

---@class (exact) FrameButtonOptions
---@field align string
---@field height number
---@field width number
---@field onClick fun(ctx: Context)
---@field disabled boolean

