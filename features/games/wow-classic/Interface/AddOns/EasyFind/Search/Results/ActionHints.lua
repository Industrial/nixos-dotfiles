local _, ns = ...

local Handlers = ns.ResultHandlers
local Shortcuts = ns.ResultShortcuts
local Icons = ns.ResultIcons
local Text = ns.ResultText

local Gestures = ns.ResultGestures

local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local select = select





function Handlers:IsSourceModifierHeld(data)
    if data and Gestures.KindOf(data) then return Gestures.WantsSource(data) end
    if Handlers._openInPlace then return true end
    return IsAltKeyDown and IsAltKeyDown() and not Shortcuts._resultShortcutActivation
end

function Handlers:IsSourceCtrlHeld(data)
    if data and Gestures.KindOf(data) then return Gestures.WantsPreview(data) end
    return IsControlKeyDown and IsControlKeyDown() and not Shortcuts._resultShortcutActivation
end

local V = Gestures.V



local function Hint(lead, clickTarget, ...)
    local s = lead .. ": " .. clickTarget
    for i = 1, select("#", ...), 2 do
        local mod, target = select(i, ...)
        s = s .. " | " .. mod .. ": " .. target
    end
    return s
end


local HINTS = {
    copyResult       = Hint(V.select, V.copyResult),

    copyChord        = Hint("Ctrl+C", V.copyResult),
    filterResults    = Hint(V.select, V.filterResults),
    gearSet          = Hint(V.click, V.equipGearSet),
    openMap          = Hint(V.click, V.openMap),
    pinOnMap         = Hint(V.click, V.pinOnMap),
    pinOrWares       = Hint(V.click, V.pinOnMap, "Shift", V.wares),
    whisperOrInvite  = Hint(V.click, _G["WHISPER"] or "Whisper", "Shift", _G["INVITE"] or "Invite"),
    whisper          = Hint(V.click, _G["WHISPER"] or "Whisper"),
    encounter        = Hint(V.click, V.encounter, "Shift", V.loot),
    bossLoot         = Hint(V.click, V.loot),
    settings         = Hint(V.click, V.settings),
}






function Handlers:GetActionHint(data)
    if not data or data.secretFormat then return nil end
    if data.socialName then return HINTS.whisperOrInvite end
    if data.socialBNet then return HINTS.whisper end


    local provider = ns.Extensions and ns.Extensions.ProviderOf and ns.Extensions.ProviderOf(data)
    if provider then
        local hint = data.hint
        if hint == nil then hint = provider.hint end
        if type(hint) == "function" then
            local ok, h = pcall(hint, data)
            hint = ok and h or nil
        end
        if type(hint) == "table" then
            local s = Hint(V.click, hint.click or V.open)
            if hint.alt then s = s .. " | Alt: " .. hint.alt end
            if hint.ctrl then s = s .. " | Ctrl: " .. hint.ctrl end
            if hint.shift then s = s .. " | Shift: " .. hint.shift end
            return s
        elseif type(hint) == "string" and hint ~= "" then
            return hint
        end
    end

    local mapped = Gestures.Hint(data)
    if mapped then return mapped end
    if data.calculatorResult then return HINTS.copyResult end
    if data.copyText then return HINTS.copyChord end
    if data.quickFilterDef then return HINTS.filterResults end
    if data.gearSetID then return HINTS.gearSet end
    if data.mapSearchResult then
        if data.isZone then return HINTS.openMap end
        if ns.ItemSources and ns.ItemSources.WareCount(data) then return HINTS.pinOrWares end
        return HINTS.pinOnMap
    end
    if data.encounterID and data.category == "Boss" then
        if ns.Caps and ns.Caps.journal then return HINTS.encounter end


        local words = ns.Extensions and ns.Extensions.DecoratorHint and ns.Extensions.DecoratorHint(data)
        if not words then return HINTS.bossLoot end
        local s = Hint(V.click, words.click or V.loot, "Alt", words.alt or V.loot)
        if words.ctrl then s = s .. " | Ctrl: " .. words.ctrl end
        return s .. " | Shift: " .. V.loot
    end
    if data.settingVariable or data.bindingAction then return HINTS.settings end
    return nil
end






function Handlers:GetLinkHint(data)
    if not data then return nil end
    local click, ctrlWhere
    local opener = ns.SecureOpeners and ns.SecureOpeners.OpenKeyForData
        and ns.SecureOpeners.OpenKeyForData(data)
    if data.spellID and data.category == "Ability"
       and not Icons:IsSpellbookOnlyAbility(data) then
        click = V.cast
        if not data.professionAbility then ctrlWhere = V.spellbook end
    elseif data.mountID then
        if Icons:IsMountSummonable(data) then click, ctrlWhere = V.summon, V.journal
        else click = V.journal end
    elseif data.toyItemID then
        click, ctrlWhere = V.use, V.toybox
    elseif data.outfitID then
        click, ctrlWhere = V.wear, V.appearances
    elseif data.macroIndex then
        click = V.open
    elseif data.itemID and (data.category == "Bag" or data.catalogItem) then
        local kind = Handlers:GetBagItemActionKind(data)
        if kind == "equip" then click, ctrlWhere = V.equip, V.dressroom else click = V.use end
    elseif opener or (data.spellID and (data.category == "Talent"
           or Icons:IsSpellbookOnlyAbility(data))) then
        click = V.open
    elseif data.settingPress then
        click = V.run
    elseif data.settingVariable or data.bindingAction then
        click = V.toggle
    else
        click = V.open
    end
    local s = V.click .. ": " .. click
    if ctrlWhere then s = s .. " | Ctrl: " .. ctrlWhere end
    s = s .. " | Shift: " .. V.sendLink
    return s
end



local actionHintRow

function Handlers:ClearActionHint()

    if actionHintRow and actionHintRow._efContextMenuHeld then return end
    if actionHintRow and actionHintRow.pathSubtext then
        actionHintRow.pathSubtext:SetText(Text:GetShownSubtext(actionHintRow.data))


        local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
        if theme then
            actionHintRow.pathSubtext:SetTextColor(unpack(theme.pathColor))
        end
    end
    actionHintRow = nil
end




function Handlers:ApplyActionHint(row)

    if actionHintRow and actionHintRow._efContextMenuHeld and row ~= actionHintRow then return end
    if not row or not row.pathSubtext or not row.pathSubtext:IsShown() then return end
    local hint = Handlers:GetActionHint(row.data)
    if not hint then return end
    if actionHintRow == row then return end
    Handlers:ClearActionHint()
    row.pathSubtext:SetText(hint)


    local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
    if theme and theme.lightTheme then
        row.pathSubtext:SetTextColor(unpack(theme.pathColorHover))
    else
        row.pathSubtext:SetTextColor(0.85, 0.78, 0.55, 1.0)
    end
    actionHintRow = row
end

function Handlers:IsActionHintRow(row)
    return actionHintRow == row
end
