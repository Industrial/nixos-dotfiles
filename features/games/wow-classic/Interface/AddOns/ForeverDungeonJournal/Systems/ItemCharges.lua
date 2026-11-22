-- charges (2.0.10, M 17 Nov 2026, a Discord report: "In Dungeon Journal there
-- is no info about Charges. After drop it says it got 3 charges"): the
-- journal's item tooltips are the game's tooltip of the item itself (as a
-- chat link shows it), and the game puts "3 Charges" (like Durability) only
-- on a copy someone owns. For the items listed here the journal adds the
-- line itself, under the green "Use:" line where the game has it. Only on the
-- journal's own tooltips (not on items in the bags, which show their own).
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

-- item ID = charges a new copy has (seen in the game)
FDJ.ITEM_CHARGES = {
    [9449] = 3, -- Manual Crowd Pummeler (Gnomeregan, Crowd Pummeler 9-60)
}

local function Plain(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
    return v
end

-- A tooltip raised by the journal or one of its windows.
local function OwnedByJournal(tooltip)
    local ok, owner = pcall(tooltip.GetOwner, tooltip)
    if not ok then return false end
    for _ = 1, 25 do
        if type(owner) ~= "table" or not owner.GetParent then return false end
        local okName, name = pcall(owner.GetName, owner)
        name = okName and Plain(name) or nil
        if type(name) == "string" and name:find("^ForeverDungeonJournal") then return true end
        owner = owner:GetParent()
    end
    return false
end

local function ItemID(tooltip, data)
    if type(data) == "table" and type(Plain(data.id)) == "number" then return data.id end
    if tooltip.GetItem then
        local ok, _, link = pcall(tooltip.GetItem, tooltip)
        link = ok and Plain(link) or nil
        local id = type(link) == "string" and link:match("item:(%d+)")
        if id then return tonumber(id) end
    end
end

local function ChargesText(n)
    local fmt = _G.ITEM_SPELL_CHARGES
    if type(fmt) == "string" then
        local ok, text = pcall(string.format, fmt, n)
        if ok and type(text) == "string" then return text end
    end
    return n .. " Charges"
end

local function AddCharges(tooltip, data)
    if not tooltip or not tooltip.GetName or not OwnedByJournal(tooltip) then return end
    local itemID = ItemID(tooltip, data)
    local charges = itemID and FDJ.ITEM_CHARGES[itemID]
    if not charges then return end
    if tooltip.fdjChargesDone == itemID then return end -- (announced twice)
    local name = tooltip:GetName()
    if not name then return end
    local text = ChargesText(charges)
    local useTag = tostring(_G.ITEM_SPELL_TRIGGER_ONUSE or "Use:")
    local useLine
    for i = 1, (tooltip:NumLines() or 0) do
        local fs = _G[name .. "TextLeft" .. i]
        local t = fs and Plain(fs:GetText())
        if type(t) == "string" then
            if t:find(text, 1, true) then return end -- already there
            if not useLine and t:sub(1, #useTag) == useTag then useLine = fs end
        end
    end
    tooltip.fdjChargesDone = itemID
    if useLine then
        -- On the "Use:" line itself, as its second line: no tooltip line moves,
        -- so the sell price and other addons' lines stay where they are.
        useLine:SetText(Plain(useLine:GetText()) .. "\n|cffffffff" .. text .. "|r")
    else
        tooltip:AddLine(text, 1, 1, 1)
    end
    -- the tooltip is sized again once it is fully built
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if tooltip:IsShown() then pcall(tooltip.Show, tooltip) end
        end)
    end
end

local function Safe(tooltip, data) pcall(AddCharges, tooltip, data) end

local viaProcessor = false
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    viaProcessor = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, Safe)
end
if not viaProcessor and GameTooltip and GameTooltip.HookScript then
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", function(self) Safe(self) end)
end
-- a new tooltip (or the same one built again) can take the line again
if GameTooltip and GameTooltip.HookScript then
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipCleared", function(self) self.fdjChargesDone = nil end)
end
