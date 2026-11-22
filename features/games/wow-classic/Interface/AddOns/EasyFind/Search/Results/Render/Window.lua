local _, ns = ...

local Render = ns.ResultRender



local Window = {}
Render.Window = Window



function Window.Tops(tops, heights, entries, n, lastPinIndex, hasResultsAfterPins, pinGap, pinSepHeight)
    local y, pinEnd = 0, 0
    for i = 1, n do
        if hasResultsAfterPins and i == lastPinIndex + 1 then
            pinEnd = y
            y = y + pinSepHeight
        end
        local e = entries[i]
        if e.isPinned and i > 1 and not entries[i - 1].isPinHeader then y = y + pinGap end
        tops[i] = y
        y = y + heights[i]
    end
    return y, pinEnd
end



function Window.Range(tops, heights, n, scrollTop, viewH, hint)
    if n < 1 then return 0, -1 end
    local first = hint or 1
    if first < 1 then first = 1 elseif first > n then first = n end
    while first > 1 and tops[first] > scrollTop do first = first - 1 end
    while first < n and tops[first] + heights[first] <= scrollTop do first = first + 1 end
    local last, bottom = first, scrollTop + viewH
    while last < n and tops[last + 1] < bottom do last = last + 1 end
    return first, last
end


function Window.Bounds(first, last, n, viewRows)
    local a = first - math.ceil(viewRows / 2)
    local b = last + viewRows
    if a < 1 then a = 1 end
    if b > n then b = n end
    return a, b
end
