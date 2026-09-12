local addonName, root = ...;
local L = root.L;

---@class BetterBags_Legendary: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

--- BetterBags dependencies
-----------------------------
---@class BetterBags: AceAddon
local BetterBags = LibStub('AceAddon-3.0'):GetAddon("BetterBags")
---@class Config: AceModule
local config = BetterBags:GetModule('Config')
---@class Context: AceModule
local context = BetterBags:GetModule('Context')
-----------------------------

addon.frame = {}

local function initContainer()
    local parent = config.configFrame.layout.nextFrame
    local container = CreateFrame("Frame", nil, parent)
    config.configFrame.layout:alignFrame(parent, container)
    return container
end

local function finalizeContainer(container)
    config.configFrame.layout.nextFrame = container
    config.configFrame.layout.height = config.configFrame.layout.height + container:GetHeight()
end

--- @param title string
--- @param opts FrameLayoutOptions
function addon.frame:CreateTitle(title, opts)
    opts = opts or {}
    local container = initContainer()
    container.title = config.configFrame.layout:createTitle(container, title, addon.config.textColor)
    container.title:SetPoint("TOPLEFT", container, "TOPLEFT", 37, (opts.top or 0))
    container.title:SetPoint("RIGHT", container, "RIGHT", -5, 0)
    container:SetHeight(container.title:GetHeight() - (opts.top or 0))
    finalizeContainer(container)
end

--- @param description string
--- @param opts FrameLayoutOptions
function addon.frame:CreateDescription(description, opts)
    opts = opts or {}
    local container = initContainer()
    container.description = config.configFrame.layout:createDescription(container, description, addon.config.textColor)
    container.description:SetPoint("TOPLEFT", container, "TOPLEFT", 37, (opts.top or 0))
    container.description:SetPoint("RIGHT", container, "RIGHT", -5, 0)
    container:SetHeight(container.description:GetHeight() - (opts.top or 0))
    finalizeContainer(container)
end

--- @param opts FormCheckboxOptions
function addon.frame:CreateCheckbox(opts)
    opts = opts or {}
    local container = initContainer()

    container.checkbox = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate") --[[@as CheckButton]]
    container.checkbox:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)
    BetterBags.SetScript(container.checkbox, "OnClick", function(ctx)
        opts.setValue(ctx, container.checkbox:GetChecked())
        config.configFrame.layout:ReloadAllFormElements()
    end)
    container.checkbox:SetChecked(opts.getValue(context:New('Checkbox_Load')))

    container.title = config.configFrame.layout:createTitle(container, opts.title, addon.config.textColor)
    container.title:SetMaxLines(1)
    container.title:SetPoint("LEFT", container.checkbox, "RIGHT", 5, 0)
    container.title:SetPoint("RIGHT", container, "RIGHT", 0, 0)

    container.description = config.configFrame.layout:createDescription(container, opts.description, addon.config.textColor)
    container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)
    container.description:SetPoint("RIGHT", container, "RIGHT", 0, 0)

    container:SetHeight(container.title:GetLineHeight() + container.description:GetHeight() + 10)
    finalizeContainer(container)
    config.configFrame.layout.checkboxes[container] = opts
end

--- @param opts FrameButtonOptions
function addon.frame:CreateButton(opts)
    local container = initContainer()
    local button = CreateFrame("Button", nil, container, "UIPanelButtonTemplate") --[[@as Button]]
    button:SetText(opts.title)
    button:SetSize((opts.width or (button:GetFontString():GetStringWidth() + 28)), (opts.height or 28))
    BetterBags.SetScript(button, "OnClick", function(ctx)
        opts.onClick(ctx)
    end)
    if opts.align == "RIGHT" then
        button:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, 0)
    elseif opts.align == "CENTER" then
        button:SetPoint("CENTER", container, "CENTER", 0, 0)
    else
        button:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)
    end
    if opts.disabled then
        button:Disable()
    end
    container:SetHeight(button:GetHeight() + 10)
    finalizeContainer(container)
    return button
end
