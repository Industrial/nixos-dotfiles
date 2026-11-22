local _, ns = ...









local Utils = ns.Utils

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    Utils.SafeAfter(0, function()
        for i = 1, (NUM_CHAT_WINDOWS or 10) do
            local editBox = _G["ChatFrame" .. i .. "EditBox"]
            if editBox then Utils.AttachPasteLinkSwap(editBox) end
        end




        for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
            local editBox = _G["StaticPopup" .. i .. "EditBox"]
            if editBox then Utils.AttachCopyWatch(editBox) end
        end
    end)






    local lastFocus
    C_Timer.NewTicker(0.1, function()
        local focus = Utils.KeyboardFocus()
        if focus == lastFocus then return end
        lastFocus = focus
        if not focus or focus._efCopyWatch or focus._efPasteSwap then return end
        if focus.GetObjectType and focus:GetObjectType() ~= "EditBox" then return end
        local name = focus.GetName and focus:GetName()
        if name and name:sub(1, 8) == "EasyFind" then return end
        Utils.AttachCopyWatch(focus)
    end)
end)
