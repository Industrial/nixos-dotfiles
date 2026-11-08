--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- The coordinate block.

local addonName, addon = ...
local TomTom = addon
local L = addon.L
local hbd = addon.hbd
addon.private = addon.private or {}
local private = addon.private
local RoundCoords = private.RoundCoords
local HasPetBattleEvents = private.HasPetBattleEvents
local module = {
    settingsKey = "block",
    defaults = {
        enable = true,
        accuracy = 2,
        bordercolor = {1, 0.8, 0, 0.8},
        bgcolor = {0, 0, 0, 0.4},
        textcolor = {1, 0.82, 0, 1},
        lock = false,
        height = 30,
        width = 100,
        fontsize = 12,
        throttle = 0.2,
        showWayCommand = true,
    },
}
private.AddModule(module, "CoordBlock")

local Block_OnClick,Block_OnUpdate,Block_OnEnter,Block_OnLeave,Block_OnEvent
local Block_OnDragStart,Block_OnDragStop

private.AddSettingsSection{
    page = "block", pageName = L["Coordinate Block"], pageOrder = 40,
    settingsKey = "block",
    feature = {
        name = L["Enable coordinate block"],
        tooltip = L["Enables a floating block that displays your current position in the current zone"],
    },
    rows = {
        {type = "text", text = L["TomTom provides you with a floating coordinate display that can be used to determine your current position.  These options can be used to enable or disable this display, or customize the block's display."]},
        {type = "toggle", key = "lock", name = L["Lock coordinate block"],
         tooltip = L["Locks the coordinate block so it can't be accidentally dragged to another location"]},
        {type = "toggle", key = "showWayCommand", name = L["Print a /way command when right-clicking the coordinate block"],
         tooltip = L["Prints a version of the /way command that can be shared with others to your chat, when right-clicking the coordinate block"]},
        {type = "range", key = "accuracy", name = L["Coordinate Accuracy"],
         tooltip = L["Coordinates can be displayed as simple XX, YY coordinate, or as more precise XX.XX, YY.YY.  This setting allows you to control that precision"],
         min = 0, max = 2, step = 1},
        {type = "range", key = "throttle", name = L["Update throttle"],
         tooltip = L["Controls the frequency of updates for the coordinate block."],
         min = 0, max = 2.0, step = 0.05},
        {type = "header", name = L["Display Settings"]},
        {type = "text", text = L["The display of the coordinate block can be customized by changing the options below."]},
        {type = "color", key = "textcolor", name = L["Text color"], opacity = true},
        {type = "color", key = "bordercolor", name = L["Border color"], opacity = true},
        {type = "color", key = "bgcolor", name = L["Background color"], opacity = true},
        {type = "range", key = "height", name = L["Block height"], min = 5, max = 50, step = 1},
        {type = "range", key = "width", name = L["Block width"], min = 50, max = 250, step = 5},
        {type = "range", key = "fontsize", name = L["Font size"], min = 1, max = 24, step = 1},
        {type = "execute", name = L["Reset Position"],
         tooltip = L["Resets the position of the coordinate block if it has been dragged off screen"],
         func = function()
             if TomTomBlock then
                 TomTomBlock:ClearAllPoints()
                 local pos = {"CENTER", nil, "CENTER", 0, -100}
                 private.SetSetting("block", "position", pos)
                 TomTomBlock:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])
             end
         end},
    },
}

function TomTom:DebugCoordBlock()
    local msg
    msg = string.format(L["|cffffff78TomTom:|r CoordBlock %s visible"], (TomTomBlock:IsVisible() and L["is"]) or L["not"])
    ChatFrame1:AddMessage(msg)

    if TomTomBlock:IsVisible() then
        local point, relativeTo, relativePoint, xOfs, yOfs = TomTomBlock:GetPoint(1)
        relativeTo = (relativeTo and relativeTo:GetName()) or "UIParent"
        msg = string.format("|cffffff78TomTom:|r CoordBlock point=%s frame=%s rpoint=%s xo=%.2f yo=%.2f",  point, relativeTo, relativePoint, xOfs, yOfs)
        ChatFrame1:AddMessage(msg)
    end
end

function TomTom:ShowHideCoordBlock()
    -- Bail out if we're not supposed to be showing this frame
    if self.profile.block.enable then
        -- Create the frame if it doesn't exist
        if not TomTomBlock then
            -- Create the coordinate display, as of WoW 9.0, BackdropTemplate is needed.
            TomTomBlock = CreateFrame("Button", "TomTomBlock", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
            TomTomBlock:SetWidth(120)
            TomTomBlock:SetHeight(32)
            TomTomBlock:SetToplevel(1)
            TomTomBlock:SetFrameStrata("MEDIUM")
            TomTomBlock:SetMovable(true)
            TomTomBlock:EnableMouse(true)
            TomTomBlock:SetClampedToScreen(true)
            TomTomBlock:RegisterForDrag("LeftButton")
            TomTomBlock:RegisterForClicks("RightButtonUp")

            TomTomBlock.Text = TomTomBlock:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            TomTomBlock.Text:SetJustifyH("CENTER")
            TomTomBlock.Text:SetPoint("CENTER", 0, 0)
            TomTomBlock.Text:SetTextColor(1, 0.8, 0, 0.8)

            TomTomBlock:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 16,
                insets = {left = 4, right = 4, top = 4, bottom = 4},
            })
            TomTomBlock:SetBackdropColor(0, 0, 0, 0.4)
            TomTomBlock:SetBackdropBorderColor(1, 0.8, 0, 0.8)

            -- Set behavior scripts
            TomTomBlock:SetScript("OnUpdate", Block_OnUpdate)
            TomTomBlock:SetScript("OnClick", Block_OnClick)
            TomTomBlock:SetScript("OnEnter", Block_OnEnter)
            TomTomBlock:SetScript("OnLeave", Block_OnLeave)
            TomTomBlock:SetScript("OnDragStop", Block_OnDragStop)
            TomTomBlock:SetScript("OnDragStart", Block_OnDragStart)
            TomTomBlock:RegisterEvent("PLAYER_ENTERING_WORLD")
            if HasPetBattleEvents() then
                TomTomBlock:RegisterEvent("PET_BATTLE_OPENING_START")
                TomTomBlock:RegisterEvent("PET_BATTLE_CLOSE")
            end
            TomTomBlock:SetScript("OnEvent", Block_OnEvent)
        end
        if self.profile.arrow.hideDuringPetBattles and C_PetBattles and C_PetBattles.IsInBattle() then
			TomTomBlock:Hide()
			return
		end
        -- Show the frame
        TomTomBlock:Show()

        local opt = self.profile.block

        -- Update the text color
        TomTomBlock.Text:SetTextColor(unpack(opt.textcolor))

        -- Update the backdrop color, and border color
        TomTomBlock:SetBackdropColor(unpack(opt.bgcolor))
        TomTomBlock:SetBackdropBorderColor(unpack(opt.bordercolor))

        -- Update the height and width
        TomTomBlock:SetHeight(opt.height)
        TomTomBlock:SetWidth(opt.width)

        -- Set the block position
        TomTomBlock:ClearAllPoints()
        if not self.profile.block.position then
            self.profile.block.position = {"CENTER", nil, "CENTER", 0, -100}
        end
        local pos = self.profile.block.position
        TomTomBlock:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])


        -- Update the font size
        local font,height = TomTomBlock.Text:GetFont()
        TomTomBlock.Text:SetFont(font, opt.fontsize, select(3, TomTomBlock.Text:GetFont()))

    elseif TomTomBlock then
        TomTomBlock:Hide()
    end
end

function module:OnEnable()
    TomTom:ShowHideCoordBlock()
end

function module:OnDisable()
    if TomTomBlock then
        TomTomBlock:Hide()
    end
end

function module:OnSettingChanged()
    TomTom:ShowHideCoordBlock()
end

function module:OnProfileChanged()
    TomTom:ShowHideCoordBlock()
end

do
    local bcounter = 0
    function Block_OnUpdate(self, elapsed)
        bcounter = bcounter + elapsed
        if (not TomTom) or not (TomTom.profile) then return; end
        if bcounter > TomTom.profile.block.throttle then
            bcounter = bcounter - TomTom.profile.block.throttle

            local x,y = TomTom:GetCurrentCoords()

            local opt = TomTom.db.profile
            if not x or not y then
                local blank = ("-"):rep(8)
                self.Text:SetText(blank)
            else
                self.Text:SetFormattedText("%s", RoundCoords(x, y, opt.block.accuracy))
            end
        end
    end

    function Block_OnDragStart(self, button, down)
        if not TomTom.db.profile.block.lock then
            self:StartMoving()
        end
    end

    function Block_OnDragStop(self, button, down)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
        -- point, relativeTo, relativePoint, xOfs, yOfs
        TomTom.db.profile.block.position = { self:GetPoint() }
        TomTom.db.profile.block.position[2] = nil  -- Note we are relative to UIParent
    end

    function Block_OnClick(self, button, down)
        local m,x,y = TomTom:GetCurrentPlayerPosition()
        if m and x and y then
            local targetName = UnitName("target")
            if issecretvalue and issecretvalue(targetName) then
                targetName = "Unnamed NPC"
            end

            local fromText = targetName and targetName or L["TomTom/Block"]

            local zoneName = hbd:GetLocalizedMap(m) or L["Unnamed Map"]
            local desc = string.format("%s: %.2f, %.2f", zoneName, x*100, y*100)
            if targetName then
                desc = desc .. " - " .. tostring(targetName)
            end

            TomTom:AddWaypoint(m, x, y, {
                title = desc,
                from = fromText,
            })

            if TomTom.db.profile.block.showWayCommand then
                local output = string.format("/way #%d %.2f %.2f %s", m, x*100, y*100, zoneName)
                if targetName then
                    output = output .. " - " .. tostring(targetName)
                end
                print(output)
            end
        end
    end

    function Block_OnEvent(self, event, ...)
        if (event == "PLAYER_ENTERING_WORLD") or (event == "PET_BATTLE_OPENING_START") or (event == "PET_BATTLE_CLOSE") then
            TomTom:ShowHideCoordBlock()
        end
    end
end
