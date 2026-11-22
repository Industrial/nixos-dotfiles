local _, ns = ...

local Handlers = ns.ResultHandlers












function Handlers:HighlightRevealedFrame(frame, validator)
    local highlight = frame and ns.RequestGuide() or nil
    if not (frame and highlight and highlight.HighlightFrame) then return false end
    highlight:HighlightFrame(frame, nil, validator)
    return true
end

function Handlers:SetEditBoxTextIfPresent(editBox, text)
    if editBox and editBox.SetText then
        pcall(editBox.SetText, editBox, text or "")
    end
end
