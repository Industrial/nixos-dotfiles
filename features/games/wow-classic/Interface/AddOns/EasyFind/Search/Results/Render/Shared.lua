local _, ns = ...

local Results = ns.Results
local Render = ns.ResultRender
local Icons = ns.ResultIcons
local Text = ns.ResultText
local Shortcuts = ns.ResultShortcuts

local C_CurrencyInfo = C_CurrencyInfo
local SCRATCH = Results._SCRATCH

Render.GOLD_COLOR = ns.GOLD_COLOR
Render.REP_BAR_WIDTH = 100
Render.MAX_BUTTON_POOL = 100
Render.BOSS_PORTRAIT_TEXCOORD = Icons:GetBossPortraitTexCoord()
Render.INDENT_COLORS = {
    {0.40, 0.85, 1.00, 0.80},
    {1.00, 0.55, 0.10, 0.80},
    {0.55, 1.00, 0.35, 0.80},
    {1.00, 0.40, 0.70, 0.80},
    {0.70, 0.55, 1.00, 0.80},
    {1.00, 0.90, 0.20, 0.80},
}
Render.INDENT_PX = 20
Render.LINE_X_OFF = 10
Render.MAX_DEPTH = 0

function Render.ShouldShowShortcutHints()
    return Shortcuts:ShouldShowResultShortcutHints()
end

function Render.IsBossResultData(data)
    return Icons:IsBossResultData(data)
end

function Render.AbbrevBinding(binding)
    return Text:AbbrevBinding(binding)
end

function Render.SetClippedText(fontString, text)
    return Text:SetClippedText(fontString, text)
end

function Render.SetUnclippedText(fontString, text)
    return Text:SetUnclippedText(fontString, text)
end

function Render.GetCachedCurrencyInfo(currencyID)
    if not currencyID or not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return nil end
    local cache = SCRATCH.currencyInfoCache
    local cached = cache[currencyID]
    if cached ~= nil then return cached end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
    local result = (ok and info) or false
    cache[currencyID] = result
    return result or nil
end
