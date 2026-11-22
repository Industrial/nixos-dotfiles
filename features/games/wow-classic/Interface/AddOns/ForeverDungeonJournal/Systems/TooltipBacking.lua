-- The journal shows item tooltips in the game's own GameTooltip (so Pawn and
-- other tooltip addons work there). The default tooltip is slightly see-through,
-- which lets journal text and portraits show through it. While a tooltip is
-- opened from the journal, give it (and its comparison tooltips) a solid
-- dark backing; everywhere else it stays exactly as the game draws it.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local function OwnedByJournal(tooltip)
    if not tooltip or not tooltip.GetOwner then return false end
    local ok, owner = pcall(tooltip.GetOwner, tooltip)
    if not ok then return false end
    local journal, favourites = _G.ForeverDungeonJournalFrame, _G.ForeverDungeonJournalFavourites
    for _ = 1, 20 do
        if not owner or type(owner) ~= "table" or not owner.GetParent then return false end
        if owner.fdjSolidTooltip or owner == journal or owner == favourites
            or owner == _G.ForeverDungeonJournalRunTracker
            or owner == _G.ForeverDungeonJournalRunLog then return true end
        owner = owner:GetParent()
    end
    return false
end

local function Backing(tip)
    if not tip.fdjJournalBacking then
        local bg = tip:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetPoint("TOPLEFT", 3, -3)
        bg:SetPoint("BOTTOMRIGHT", -3, 3)
        bg:SetColorTexture(0.03, 0.03, 0.04, 1)
        bg:Hide()
        tip.fdjJournalBacking = bg
    end
    return tip.fdjJournalBacking
end

local function Update(tip)
    if not tip or not tip.CreateTexture then return end
    local fromJournal = OwnedByJournal(tip)
    -- Comparison tooltips belong to the main tooltip: follow its state.
    if not fromJournal and tip ~= GameTooltip and GameTooltip and GameTooltip:IsShown() then
        fromJournal = GameTooltip.fdjJournalBacking and GameTooltip.fdjJournalBacking:IsShown() or false
    end
    if fromJournal then Backing(tip):Show()
    elseif tip.fdjJournalBacking then tip.fdjJournalBacking:Hide() end
end

local function Hook(tip)
    if not tip or not tip.HookScript or tip.fdjBackingHooked then return end
    tip.fdjBackingHooked = true
    pcall(tip.HookScript, tip, "OnShow", function(self) pcall(Update, self) end)
    pcall(tip.HookScript, tip, "OnSizeChanged", function(self) pcall(Update, self) end)
    pcall(tip.HookScript, tip, "OnHide", function(self)
        if self.fdjJournalBacking then self.fdjJournalBacking:Hide() end
    end)
end

-- The game's own item comparison (ShoppingTooltip1/2) can pop up on its own
-- (for example with "always compare items" on). In the journal, comparison is
-- shown only while Shift is held, by the journal's own comparison tooltips,
-- so the game's are kept hidden while the item tooltip comes from the journal.
local function JournalOwnsMain()
    return GameTooltip and GameTooltip:IsShown() and OwnedByJournal(GameTooltip)
end

local function HideGameCompare()
    for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2" }) do
        local tip = _G[name]
        if tip and tip:IsShown() then tip:Hide() end
    end
end

local function HookCompare()
    for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2" }) do
        local tip = _G[name]
        if tip and tip.HookScript and not tip.fdjCompareHooked then
            tip.fdjCompareHooked = true
            pcall(tip.HookScript, tip, "OnShow", function(self)
                if JournalOwnsMain() then self:Hide() end
            end)
        end
    end
    if GameTooltip and GameTooltip.HookScript and not GameTooltip.fdjCompareHooked then
        GameTooltip.fdjCompareHooked = true
        pcall(GameTooltip.HookScript, GameTooltip, "OnUpdate", function(self)
            if self.fdjJournalBacking and self.fdjJournalBacking:IsShown() then HideGameCompare() end
        end)
    end
end

-- novendorline (2.0.11, M 18 Nov 2026: Auctionator adds "Vendor 4s 75c"
-- under the game's own Sell Price; "disable it and force our tooltip ... it
-- has to disable only the vendor price, any other item like pawn etc must
-- work"): on item tooltips opened from the journal, Auctionator's Vendor
-- line is left out (and the game's Sell Price it would clear stays). Its
-- Auction / Disenchant lines and every other addon's lines are untouched,
-- and everywhere else Auctionator works as always.
local function SkipAuctionatorVendor()
    local A = _G.Auctionator
    local T = type(A) == "table" and A.Tooltip
    if type(T) ~= "table" or type(T.AddVendorTip) ~= "function" or T.fdjVendorWrapped then return end
    local original = T.AddVendorTip
    T.AddVendorTip = function(tooltipFrame, ...)
        if OwnedByJournal(tooltipFrame) then return end
        return original(tooltipFrame, ...)
    end
    T.fdjVendorWrapped = true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    for _, name in ipairs({ "GameTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
        Hook(_G[name])
    end
    pcall(HookCompare)
    pcall(SkipAuctionatorVendor) -- novendorline
end)

-- The journal calls this right after filling its item tooltip, in case the
-- tooltip was already visible (OnShow does not fire again).
function FDJ.RefreshTooltipBacking()
    for _, name in ipairs({ "GameTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
        local tip = _G[name]
        if tip and tip:IsShown() then pcall(Update, tip) end
    end
end
