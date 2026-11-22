local _, ns = ...

local Search = ns.Search
local Focus = ns.SearchFocus

function Focus:RefocusSearchEditBox()
    local searchFrame = Search:GetSearchFrame()
    local editBox = searchFrame and searchFrame.editBox
    if not editBox then return end
    local navFrame = Search:GetNavFrame()
    if navFrame and navFrame:IsKeyboardEnabled() then return end
    editBox.blockFocus = nil
    editBox:SetFocus()
end
