local _, ns = ...

local Filters = ns.Filters
local Utils = ns.Utils

local CreateFrame = CreateFrame
local UIParent = UIParent
local GetProfessions = GetProfessions
local GetProfessionInfo = GetProfessionInfo
local C_TradeSkillUI = C_TradeSkillUI
local tsort = table.sort
local wipe = wipe




local function ClassicProfessions(out)
    local seen = {}
    local texture = C_Spell and C_Spell.GetSpellTexture


    local noWindow = {}
    local spellInfo = C_Spell and C_Spell.GetSpellInfo
    for _, id in ipairs({ 9134, 353982, 8613, 7620 }) do
        local spell = spellInfo and spellInfo(id)
        local name = type(spell) == "table" and spell.name or (GetSpellInfo and GetSpellInfo(id))
        if name then noWindow[name] = true end
    end
    local function add(name, icon)
        if not name or name == "" or seen[name] or noWindow[name] then return end
        seen[name] = true
        out[#out + 1] = { skillLine = name, name = name, icon = icon or (texture and texture(name)) }
    end
    if GetProfessions and GetProfessionInfo then
        local indexes = { GetProfessions() }
        for i = 1, 6 do
            if indexes[i] then
                local profName, profIcon = GetProfessionInfo(indexes[i])
                add(profName, profIcon)
            end
        end
    end
    local numLines, lineInfo = _G["GetNumSkillLines"], _G["GetSkillLineInfo"]
    if numLines and lineInfo then
        local wanted = { [_G["TRADE_SKILLS"] or "Professions"] = true, [_G["SECONDARY_SKILLS"] or "Secondary Skills"] = true }
        local header
        for i = 1, numLines() or 0 do
            local name, isHeader = lineInfo(i)
            if isHeader then header = name elseif wanted[header] then add(name) end
        end
    end
    local book = ns.Database and ns.Database.ClassicRecipeBook and ns.Database.ClassicRecipeBook()
    for name, prof in pairs(book or {}) do
        add(name, prof.spellID and texture and texture(prof.spellID))
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end



local function KnownProfessions()
    local out = {}
    if ns.Caps and ns.Caps.classic then return ClassicProfessions(out) end
    if not (GetProfessions and GetProfessionInfo) then return out end
    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
    local profIndexes = { prof1, prof2, archaeology, fishing, cooking }
    for i = 1, 5 do
        local profIndex = profIndexes[i]
        if profIndex then
            local profName, profIcon, _, _, _, _, skillLine = GetProfessionInfo(profIndex)
            if profName and profName ~= "" and skillLine then
                out[#out + 1] = { skillLine = skillLine, name = profName, icon = profIcon }
            end
        end
    end
    return out
end










local expansionCache = {}
local function KnownExpansionPages(parentSkillLine)
    if not parentSkillLine then return nil end
    if expansionCache[parentSkillLine] then return expansionCache[parentSkillLine] end
    local ts = C_TradeSkillUI
    if not (ts and ts.GetAllProfessionTradeSkillLines and ts.GetProfessionInfoBySkillLineID) then
        return nil
    end
    local okParent, parentInfo = pcall(ts.GetProfessionInfoBySkillLineID, parentSkillLine)
    local profEnum = okParent and type(parentInfo) == "table" and parentInfo.profession
    local okAll, allLines = pcall(ts.GetAllProfessionTradeSkillLines)
    if not (profEnum and okAll and type(allLines) == "table") then return nil end







    local pageUniverse, seen = {}, {}
    for i = 1, #allLines do
        local line = allLines[i]
        if not seen[line] then
            seen[line] = true
            pageUniverse[#pageUniverse + 1] = line
        end
    end
    local shipped = ns.PROFESSION_RECIPES and ns.PROFESSION_RECIPES[parentSkillLine]
    if shipped and shipped.recipesByPage then
        for pageID in pairs(shipped.recipesByPage) do
            if not seen[pageID] then
                seen[pageID] = true
                pageUniverse[#pageUniverse + 1] = pageID
            end
        end
    end

    local out = {}
    for i = 1, #pageUniverse do
        local line = pageUniverse[i]
        if line ~= parentSkillLine then
            local okI, info = pcall(ts.GetProfessionInfoBySkillLineID, line)
            if okI and type(info) == "table" and info.profession == profEnum
               and (info.skillLevel or 0) > 0 then
                out[#out + 1] = { professionID = line, name = info.expansionName or tostring(line) }
            end
        end
    end
    tsort(out, function(a, b) return a.professionID > b.professionID end)










    if #out > 0 then
        expansionCache[parentSkillLine] = out
    end
    return out
end

local expansionCacheFrame = CreateFrame("Frame")
expansionCacheFrame:RegisterEvent("SKILL_LINES_CHANGED")
expansionCacheFrame:SetScript("OnEvent", function() wipe(expansionCache) end)




ns.KnownExpansionPages = KnownExpansionPages
ns.KnownProfessions = KnownProfessions











local STATE_VER = 3
local function RecipeFilterState()
    local db = EasyFind.db
    local state = db.professionRecipeFilters
    if not state or state.ver ~= STATE_VER then
        state = {
            ver = STATE_VER,
            learned = true, unlearned = true,
            skillUp = false, materials = false,
            firstCraftOnly = false,
            sourceMask = 65535,
            expansion = {},
            slotFilters = {},
        }
        db.professionRecipeFilters = state
    end
    return state
end





local function SettersExist()
    return C_TradeSkillUI ~= nil and C_TradeSkillUI.SetShowLearned ~= nil
end

local function ProfessionWindowLive()
    local pf = _G["ProfessionsFrame"]
    local live = pf and pf:IsShown() and pf.professionInfo
    if not (type(live) == "table" and live.professionID ~= nil and live.professionID ~= 0) then
        return false
    end





    local list = pf.CraftingPage and pf.CraftingPage.RecipeList
    local scrollBox = list and list.ScrollBox
    if not (scrollBox and scrollBox.GetDataProvider) then return false end
    local ok, provider = pcall(scrollBox.GetDataProvider, scrollBox)
    return ok and provider ~= nil
end


local ScanAndClickMenuRow, ClickWindowMenuRow



local function ApplySlotFilter(position, enabled)
    local ts = C_TradeSkillUI
    if not (ts and ts.SetInventorySlotFilter) then return end
    local arg = position
    if ts.GetFilterableInventorySlots then
        local ok, ids = pcall(ts.GetFilterableInventorySlots)
        if ok and type(ids) == "table" and type(ids[position]) == "number" then
            arg = ids[position]
        end
    end
    pcall(ts.SetInventorySlotFilter, arg, enabled)
end

local function PushBody(state)
    local ts = C_TradeSkillUI
    pcall(ts.SetShowLearned, state.learned ~= false)
    if ts.SetShowUnlearned then pcall(ts.SetShowUnlearned, state.unlearned ~= false) end
    if ts.SetOnlyShowSkillUpRecipes then pcall(ts.SetOnlyShowSkillUpRecipes, state.skillUp == true) end
    if ts.SetOnlyShowMakeableRecipes then pcall(ts.SetOnlyShowMakeableRecipes, state.materials == true) end
    if ts.SetSourceTypeFilter then pcall(ts.SetSourceTypeFilter, state.sourceMask or 65535) end
    if ts.SetOnlyShowFirstCraftRecipes then
        pcall(ts.SetOnlyShowFirstCraftRecipes, state.firstCraftOnly == true)
    end
end

local function PullBody(state)
    local ts = C_TradeSkillUI
    local getters = {
        { fn = ts.GetShowLearned, key = "learned" },
        { fn = ts.GetShowUnlearned, key = "unlearned" },
        { fn = ts.GetOnlyShowSkillUpRecipes, key = "skillUp" },
        { fn = ts.GetOnlyShowMakeableRecipes, key = "materials" },
        { fn = ts.GetOnlyShowFirstCraftRecipes, key = "firstCraftOnly" },
    }
    for i = 1, #getters do
        local getter = getters[i]
        if getter.fn then
            local ok, v = pcall(getter.fn)
            if ok and v ~= nil then state[getter.key] = v and true or false end
        end
    end
    if ts.GetSourceTypeFilter then
        local ok, v = pcall(ts.GetSourceTypeFilter)
        if ok and type(v) == "number" then state.sourceMask = v end
    end
end


local function LiveApplyBody(state)
    local pf = _G["ProfessionsFrame"]
    local live = pf and pf:IsShown() and pf.professionInfo
    if type(live) ~= "table" or not live.parentProfessionID then return end
    local slotState = state.slotFilters and state.slotFilters[live.parentProfessionID]
    if slotState then
        for position, enabled in pairs(slotState) do
            ApplySlotFilter(position, enabled ~= false)
        end
    end
    local wanted = state.expansion and state.expansion[live.parentProfessionID]
    if not wanted or wanted == live.professionID then return end
    local children = KnownExpansionPages(live.parentProfessionID)
    if not children then return end
    for i = 1, #children do
        if children[i].professionID == wanted then
            local page = pf.CraftingPage
            local expBtn = page and page.RankBar and page.RankBar.ExpansionDropdownButton
            if expBtn then ClickWindowMenuRow(expBtn, children[i].name) end
            return
        end
    end
end

ns.ControlSync.Register{
    key = "professions",
    pendingKey = "professionFiltersPendingPush",
    reconcile = true,
    state = RecipeFilterState,
    available = SettersExist,
    live = ProfessionWindowLive,
    push = PushBody,
    pull = PullBody,
    liveApply = LiveApplyBody,
    isDirty = function(state) return state.expansionDirty == true or state.slotsDirty == true end,
    clearDirty = function(state)
        state.expansionDirty = nil
        state.slotsDirty = nil
    end,
}

local function PushRecipeFilters(state)
    return ns.ControlSync.Push("professions")
end

local function PullRecipeFilters(state)
    return ns.ControlSync.Sync("professions")
end

function Filters:ArmProfessionPendingPushIfNeeded()
    ns.ControlSync.ArmAtLoginIfNeeded("professions")
end

ScanAndClickMenuRow = function(wantText)
    local clicked = false
    local frame = EnumerateFrames()
    while frame and not clicked do
        local okV, vis = pcall(frame.IsVisible, frame)
        if okV and vis then
            local okS, strata = pcall(frame.GetFrameStrata, frame)
            if okS and strata == "FULLSCREEN_DIALOG" then
                local okK, kids = pcall(function() return { frame:GetChildren() } end)
                if okK then
                    for i = 1, #kids do
                        local kid = kids[i]
                        local okB, isBtn = pcall(function() return kid:GetObjectType() == "Button" end)
                        if okB and isBtn then
                            local okR, regs = pcall(function() return { kid:GetRegions() } end)
                            if okR then
                                for r = 1, #regs do
                                    local reg = regs[r]
                                    local okT, txt = pcall(function()
                                        return reg:GetObjectType() == "FontString" and reg:GetText()
                                    end)
                                    if okT and txt == wantText then
                                        pcall(kid.Click, kid)
                                        clicked = true
                                        break
                                    end
                                end
                            end
                        end
                        if clicked then break end
                    end
                end
            end
        end
        frame = EnumerateFrames(frame)
    end
    return clicked
end




ClickWindowMenuRow = function(dropdownBtn, wantText)
    if not (dropdownBtn and type(dropdownBtn.OpenMenu) == "function") then return end
    pcall(dropdownBtn.OpenMenu, dropdownBtn)
    Utils.SafeAfter(0.05, function()
        if ScanAndClickMenuRow(wantText) then return end
        Utils.SafeAfter(0.15, function()
            if not ScanAndClickMenuRow(wantText)
               and type(dropdownBtn.CloseMenu) == "function" then
                pcall(dropdownBtn.CloseMenu, dropdownBtn)
            end
        end)
    end)
end

local attachCtx
local childPopups = {}
local function HideAllSubmenus()
    for i = 1, #childPopups do childPopups[i]:Hide() end
end



local function HideSiblingSubmenus(popupFrame)
    for i = 1, #childPopups do
        local child = childPopups[i]
        if child ~= popupFrame and child._efParentPopup == popupFrame._efParentPopup then
            child:Hide()
        end
    end
end
local function AttachRecipeFilterFlyout(row)
    local ctx = attachCtx
    if not ctx then return end
    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel(row:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
    ctx.StylePopup(popup)
    popup:EnableMouse(true)
    popup:Hide()
    ctx.dropdownGuardFrames[#ctx.dropdownGuardFrames + 1] = popup
    childPopups[#childPopups + 1] = popup
    Filters.AttachOutsideClickClose(popup)
    row._submenuPopup = popup

    local ROW_H = ctx.rowHeight
    local CHECK = ctx.checkSize
    local PAD = 8
    local defs = {
        { key = "learned" },
        { key = "unlearned" },
        { key = "skillUp" },
        { key = "firstCraftOnly", craftingOnly = true },
        { key = "materials" },
    }
    local checkRows = {}
    local y = -PAD
    for i = 1, #defs do
        local cr = CreateFrame("CheckButton", nil, popup)
        cr:SetSize(150, ROW_H)
        cr:SetHitRectInsets(0, 0, 0, 0)
        Utils.SetCheckboxTextures(cr, CHECK)
        local fs = cr:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetPoint("LEFT", cr:GetNormalTexture(), "RIGHT", 4, 0)
        cr._label = fs
        cr:SetPoint("TOPLEFT", PAD, y)
        Utils.InstallMenuRowHighlight(cr)
        cr._key = defs[i].key
        cr:SetScript("OnClick", function(self)
            local state = RecipeFilterState()
            state[self._key] = self:GetChecked() and true or false
            PushRecipeFilters(state)


            if self._key == "learned" or self._key == "unlearned" then
                if ns.Database and ns.Database.RefreshDynamicCategory then
                    ns.Database:RefreshDynamicCategory("professions")
                end
                Filters:ApplyFilterSelection("professions")
            end
        end)
        checkRows[i] = cr
        y = y - ROW_H
    end

    local sep = popup:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1, 1, 1, 0.12)
    sep:SetHeight(1)



    local sourcesPopup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    sourcesPopup:SetFrameStrata("TOOLTIP")
    sourcesPopup:SetFrameLevel(popup:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
    ctx.StylePopup(sourcesPopup)
    sourcesPopup:EnableMouse(true)
    sourcesPopup:Hide()
    ctx.dropdownGuardFrames[#ctx.dropdownGuardFrames + 1] = sourcesPopup
    childPopups[#childPopups + 1] = sourcesPopup
    Filters.AttachOutsideClickClose(sourcesPopup)
    sourcesPopup._efParentPopup = popup
    popup:HookScript("OnHide", function() sourcesPopup:Hide() end)

    local sourcesOpener = CreateFrame("Button", nil, popup)
    sourcesOpener:SetSize(150, ROW_H)
    sourcesOpener:SetHitRectInsets(0, 0, 0, 0)
    local soLabel = sourcesOpener:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    soLabel:SetPoint("LEFT", 6, 0)
    sourcesOpener._label = soLabel
    local soChev = sourcesOpener:CreateTexture(nil, "OVERLAY")
    soChev:SetAtlas("common-icon-forwardarrow")
    soChev:SetSize(CHECK - 2, CHECK - 2)
    soChev:SetPoint("RIGHT", -4, 0)
    soChev:SetVertexColor(0.85, 0.85, 0.85, 1)
    soLabel:SetPoint("RIGHT", soChev, "LEFT", -4, 0)
    soLabel:SetJustifyH("LEFT")
    soLabel:SetWordWrap(false)
    Utils.InstallMenuRowHighlight(sourcesOpener)










    local lshift = bit.lshift
    local band = bit.band
    local bor = bit.bor
    local function SourceRowsFor(skillLine)
        local profData = ns.PROFESSION_RECIPES and ns.PROFESSION_RECIPES[skillLine]
        local types = profData and profData.sources
        local rows = {}
        if types then
            for i = 1, #types do
                local sourceType = types[i]
                local labelFn = ns.PROFESSION_SOURCE_LABELS and ns.PROFESSION_SOURCE_LABELS[sourceType]
                rows[#rows + 1] = {
                    bit = lshift(1, sourceType),
                    label = labelFn and labelFn() or ("Source " .. sourceType),
                }
            end
        end
        return rows
    end
    local function VisibleSourceMask(rows)
        local mask = 0
        for i = 1, #rows do mask = mask + rows[i].bit end
        return mask
    end
    local function GetSourceMask()
        local state = RecipeFilterState()
        if SettersExist() and not EasyFind.db.professionFiltersPendingPush then
            local ok, v = pcall(C_TradeSkillUI.GetSourceTypeFilter)
            if ok and type(v) == "number" then
                state.sourceMask = v
                return v
            end
        end
        return state.sourceMask or 65535
    end
    local function SetSourceMask(mask)
        local state = RecipeFilterState()
        state.sourceMask = mask
        PushRecipeFilters(state)
    end

    local sourceChecks = {}
    local sourceActions = {}
    local function GetSourceAction(i)
        local r = sourceActions[i]
        if not r then
            r = CreateFrame("Button", nil, sourcesPopup)
            r:SetSize(150, ROW_H)
            r:SetHitRectInsets(0, 0, 0, 0)
            local fs = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            fs:SetPoint("LEFT", 6, 0)
            r._label = fs
            Utils.InstallMenuRowHighlight(r)
            sourceActions[i] = r
        end
        return r
    end
    local function GetSourceCheck(i)
        local r = sourceChecks[i]
        if not r then
            r = CreateFrame("CheckButton", nil, sourcesPopup)
            r:SetSize(150, ROW_H)
            r:SetHitRectInsets(0, 0, 0, 0)
            Utils.SetCheckboxTextures(r, CHECK)
            local fs = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            fs:SetPoint("LEFT", r:GetNormalTexture(), "RIGHT", 4, 0)
            r._label = fs
            Utils.InstallMenuRowHighlight(r)
            r:SetScript("OnClick", function(self)
                local mask = GetSourceMask()
                if self:GetChecked() then
                    mask = bor(mask, self._bit)
                else
                    mask = mask - band(mask, self._bit)
                end
                SetSourceMask(mask)
            end)
            sourceChecks[i] = r
        end
        return r
    end

    local function LayoutSources()
        local y, contentW = -PAD, 0
        local rowsDef = SourceRowsFor(row._skillLine)
        local visibleMask = VisibleSourceMask(rowsDef)
        local actions = {
            { label = _G["CHECK_ALL"] or "Check All",
              run = function() SetSourceMask(bor(GetSourceMask(), visibleMask)) end },
            { label = _G["UNCHECK_ALL"] or "Uncheck All",
              run = function()
                  local mask = GetSourceMask()
                  SetSourceMask(mask - band(mask, visibleMask))
              end },
        }
        for i = 1, #actions do
            local r = GetSourceAction(i)
            r._label:SetText(actions[i].label)
            r:SetScript("OnClick", function()
                actions[i].run()
                local mask = GetSourceMask()
                for ci = 1, #rowsDef do
                    if sourceChecks[ci] then
                        sourceChecks[ci]:SetChecked(band(mask, rowsDef[ci].bit) ~= 0)
                    end
                end
            end)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", PAD, y)
            r:Show()
            y = y - ROW_H
            local w = Utils.FlyoutRowContentWidth(r, 8)
            if w > contentW then contentW = w end
        end
        local mask = GetSourceMask()
        for i = 1, #rowsDef do
            local def = rowsDef[i]
            local r = GetSourceCheck(i)
            r._bit = def.bit
            r._label:SetText(def.label)
            r:SetChecked(band(mask, def.bit) ~= 0)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", PAD, y)
            r:Show()
            y = y - ROW_H
            local w = Utils.FlyoutRowContentWidth(r, CHECK + 4)
            if w > contentW then contentW = w end
        end
        for i = #rowsDef + 1, #sourceChecks do sourceChecks[i]:Hide() end
        local w = Utils.FlyoutWidthFor(contentW, PAD)
        for i = 1, #sourceActions do sourceActions[i]:SetWidth(w - PAD * 2) end
        for i = 1, #rowsDef do sourceChecks[i]:SetWidth(w - PAD * 2) end
        sourcesPopup:SetSize(w, -y + PAD)
    end

    local sourcesHover = Utils.AttachHoverPopup(sourcesOpener, sourcesPopup, {
        onShow = function()
            HideSiblingSubmenus(sourcesPopup)
            LayoutSources()
            sourcesPopup:SetScale(EasyFind.db.uiSearchScale or 1.0)
            Utils.OpenFlyoutBeside(sourcesPopup, sourcesOpener, 4)
            sourcesPopup:Show()
        end,
    })
    sourcesOpener.ShowFlyoutPopup = sourcesHover.Show



    local slotsPopup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    slotsPopup:SetFrameStrata("TOOLTIP")
    slotsPopup:SetFrameLevel(popup:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
    ctx.StylePopup(slotsPopup)
    slotsPopup:EnableMouse(true)
    slotsPopup:Hide()
    ctx.dropdownGuardFrames[#ctx.dropdownGuardFrames + 1] = slotsPopup
    childPopups[#childPopups + 1] = slotsPopup
    Filters.AttachOutsideClickClose(slotsPopup)
    slotsPopup._efParentPopup = popup
    popup:HookScript("OnHide", function() slotsPopup:Hide() end)

    local slotsOpener = CreateFrame("Button", nil, popup)
    slotsOpener:SetSize(150, ROW_H)
    slotsOpener:SetHitRectInsets(0, 0, 0, 0)
    local slLabel = slotsOpener:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    slLabel:SetPoint("LEFT", 6, 0)
    slotsOpener._label = slLabel
    local slChev = slotsOpener:CreateTexture(nil, "OVERLAY")
    slChev:SetAtlas("common-icon-forwardarrow")
    slChev:SetSize(CHECK - 2, CHECK - 2)
    slChev:SetPoint("RIGHT", -4, 0)
    slChev:SetVertexColor(0.85, 0.85, 0.85, 1)
    slLabel:SetPoint("RIGHT", slChev, "LEFT", -4, 0)
    slLabel:SetJustifyH("LEFT")
    slLabel:SetWordWrap(false)
    Utils.InstallMenuRowHighlight(slotsOpener)

    local slotChecks = {}
    local slotActions = {}
    local function SlotState()
        local state = RecipeFilterState()
        local bySkill = state.slotFilters[row._skillLine]
        if not bySkill then bySkill = {}; state.slotFilters[row._skillLine] = bySkill end
        return bySkill
    end
    local function ApplySlot(position, enabled)
        if ProfessionWindowLive() then
            ApplySlotFilter(position, enabled)
        else


            RecipeFilterState().slotsDirty = true
            ns.ControlSync.MarkPending("professions")
        end
    end
    local function GetSlotAction(i)
        local r = slotActions[i]
        if not r then
            r = CreateFrame("Button", nil, slotsPopup)
            r:SetSize(150, ROW_H)
            r:SetHitRectInsets(0, 0, 0, 0)
            local fs = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            fs:SetPoint("LEFT", 6, 0)
            r._label = fs
            Utils.InstallMenuRowHighlight(r)
            slotActions[i] = r
        end
        return r
    end
    local function GetSlotCheck(i)
        local r = slotChecks[i]
        if not r then
            r = CreateFrame("CheckButton", nil, slotsPopup)
            r:SetSize(150, ROW_H)
            r:SetHitRectInsets(0, 0, 0, 0)
            Utils.SetCheckboxTextures(r, CHECK)
            local fs = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            fs:SetPoint("LEFT", r:GetNormalTexture(), "RIGHT", 4, 0)
            r._label = fs
            Utils.InstallMenuRowHighlight(r)
            r:SetScript("OnClick", function(self)
                local on = self:GetChecked() and true or false


                SlotState()[self._slotIndex] = Utils.OffOrNil(on)
                ApplySlot(self._slotIndex, on)
            end)
            slotChecks[i] = r
        end
        return r
    end
    local function LayoutSlots()
        local profData = ns.PROFESSION_RECIPES and ns.PROFESSION_RECIPES[row._skillLine]
        local slots = profData and profData.slots or {}
        local slotState = SlotState()



        local ts = C_TradeSkillUI
        if ts and ts.AreAnyInventorySlotsFiltered then
            local ok, anyFiltered = pcall(ts.AreAnyInventorySlotsFiltered)
            if ok and anyFiltered == false then
                for k in pairs(slotState) do slotState[k] = nil end
            end
        end
        local y, contentW = -PAD, 0
        local actions = {
            { label = _G["CHECK_ALL"] or "Check All", value = true },
            { label = _G["UNCHECK_ALL"] or "Uncheck All", value = false },
        }
        for i = 1, #actions do
            local r = GetSlotAction(i)
            r._label:SetText(actions[i].label)
            local val = actions[i].value
            r:SetScript("OnClick", function()
                for si = 1, #slots do
                    slotState[si] = Utils.OffOrNil(val)
                    ApplySlot(si, val)
                    if slotChecks[si] then slotChecks[si]:SetChecked(val) end
                end
            end)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", PAD, y)
            r:Show()
            y = y - ROW_H
            local w = Utils.FlyoutRowContentWidth(r, 8)
            if w > contentW then contentW = w end
        end
        for i = 1, #slots do
            local r = GetSlotCheck(i)
            r._slotIndex = i
            r._label:SetText(slots[i])
            r:SetChecked(slotState[i] ~= false)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", PAD, y)
            r:Show()
            y = y - ROW_H
            local w = Utils.FlyoutRowContentWidth(r, CHECK + 4)
            if w > contentW then contentW = w end
        end
        for i = #slots + 1, #slotChecks do slotChecks[i]:Hide() end
        local w = Utils.FlyoutWidthFor(contentW, PAD)
        for i = 1, #slotActions do slotActions[i]:SetWidth(w - PAD * 2) end
        for i = 1, #slots do slotChecks[i]:SetWidth(w - PAD * 2) end
        slotsPopup:SetSize(w, -y + PAD)
    end
    local slotsHover = Utils.AttachHoverPopup(slotsOpener, slotsPopup, {
        onShow = function()
            HideSiblingSubmenus(slotsPopup)
            LayoutSlots()
            slotsPopup:SetScale(EasyFind.db.uiSearchScale or 1.0)
            Utils.OpenFlyoutBeside(slotsPopup, slotsOpener, 4)
            slotsPopup:Show()
        end,
    })
    slotsOpener.ShowFlyoutPopup = slotsHover.Show
    ctx.AddPopupKeyboardNav(slotsPopup, function()
        local rows = {}
        for i = 1, #slotActions do if slotActions[i]:IsShown() then rows[#rows + 1] = slotActions[i] end end
        for i = 1, #slotChecks do if slotChecks[i]:IsShown() then rows[#rows + 1] = slotChecks[i] end end
        return rows
    end, popup)
    ctx.AddPopupKeyboardNav(sourcesPopup, function()
        local rows = {}
        for i = 1, #sourceActions do if sourceActions[i]:IsShown() then rows[#rows + 1] = sourceActions[i] end end
        for i = 1, #sourceChecks do if sourceChecks[i]:IsShown() then rows[#rows + 1] = sourceChecks[i] end end
        return rows
    end, popup)

    local radioRows = {}
    local function GetRadioRow(i)
        local rr = radioRows[i]
        if not rr then
            rr = CreateFrame("Button", nil, popup)
            rr:SetSize(150, ROW_H)
            rr:SetHitRectInsets(0, 0, 0, 0)
            local tex, setChecked = ctx.CreateRadioTexture(rr)
            tex:SetPoint("LEFT", 2, 0)
            rr._setChecked = setChecked
            local fs = rr:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            fs:SetPoint("LEFT", tex, "RIGHT", 6, 0)
            rr._label = fs
            Utils.InstallMenuRowHighlight(rr)
            rr:SetScript("OnClick", function(self)
                local state = RecipeFilterState()
                state.expansion[row._skillLine] = self._professionID
                local pf = _G["ProfessionsFrame"]
                local page = pf and pf.CraftingPage
                local expBtn = page and page.RankBar and page.RankBar.ExpansionDropdownButton
                if pf and pf:IsShown() and expBtn then
                    ClickWindowMenuRow(expBtn, self._label:GetText())
                else
                    state.expansionDirty = true
                    ns.ControlSync.MarkPending("professions")
                end
                for ri = 1, #radioRows do
                    radioRows[ri]._setChecked(radioRows[ri]._professionID == self._professionID)
                end
            end)
            radioRows[i] = rr
        end
        return rr
    end

    local SEP_H = 8
    local function Layout()

        checkRows[1]._label:SetText(_G["PROFESSION_RECIPES_SHOW_LEARNED"] or "Show Learned")
        checkRows[2]._label:SetText(_G["PROFESSION_RECIPES_SHOW_UNLEARNED"] or "Show Unlearned")
        checkRows[3]._label:SetText(_G["TRADESKILL_FILTER_HAS_SKILL_UP"] or "Has skill up")
        checkRows[4]._label:SetText(_G["PROFESSION_RECIPES_IS_FIRST_CRAFT"] or "First Craft Bonus")
        checkRows[5]._label:SetText(_G["CRAFT_IS_MAKEABLE"] or "Have Materials")
        local profData = ns.PROFESSION_RECIPES and ns.PROFESSION_RECIPES[row._skillLine]
        local state = RecipeFilterState()
        PullRecipeFilters(state)
        checkRows[1]:SetChecked(state.learned ~= false)
        checkRows[2]:SetChecked(state.unlearned ~= false)
        checkRows[3]:SetChecked(state.skillUp == true)
        checkRows[4]:SetChecked(state.firstCraftOnly == true)
        checkRows[5]:SetChecked(state.materials == true)
        local showFirstCraft = profData and profData.firstCraft == true
        local contentW = 0
        local y = -PAD
        for i = 1, #checkRows do
            local cr = checkRows[i]
            if i == 4 and not showFirstCraft then
                cr:Hide()
            else
                cr:ClearAllPoints()
                cr:SetPoint("TOPLEFT", PAD, y)
                cr:Show()
                y = y - ROW_H
                local w = Utils.FlyoutRowContentWidth(cr, CHECK + 4)
                if w > contentW then contentW = w end
            end
        end
        local ownedPages = KnownExpansionPages(row._skillLine)
        local hasChildren = ownedPages and #ownedPages > 0
        local hasSlots = profData and profData.slots and #profData.slots > 0
        if hasChildren then
            sep:ClearAllPoints()
            sep:SetPoint("LEFT", popup, "LEFT", PAD, 0)
            sep:SetPoint("RIGHT", popup, "RIGHT", -PAD, 0)
            sep:SetPoint("TOP", popup, "TOP", 0, y - SEP_H * 0.5)
            sep:Show()
            y = y - SEP_H
            soLabel:SetText(_G["SOURCES"] or "Sources")
            sourcesOpener:ClearAllPoints()
            sourcesOpener:SetPoint("TOPLEFT", PAD, y)
            sourcesOpener:Show()
            y = y - ROW_H
            local w2 = Utils.FlyoutRowContentWidth(sourcesOpener, 8, nil, CHECK - 2)
            if w2 > contentW then contentW = w2 end
            if hasSlots then
                slLabel:SetText(_G["TRADESKILL_FILTER_SLOTS"] or "Slots")
                slotsOpener:ClearAllPoints()
                slotsOpener:SetPoint("TOPLEFT", PAD, y)
                slotsOpener:Show()
                y = y - ROW_H
                local w3 = Utils.FlyoutRowContentWidth(slotsOpener, 8, nil, CHECK - 2)
                if w3 > contentW then contentW = w3 end
            else
                slotsOpener:Hide()
            end


            local children = ownedPages
            local state2 = RecipeFilterState()
            local current = state2.expansion[row._skillLine]



            local pf = _G["ProfessionsFrame"]
            local live = pf and pf.professionInfo
            if type(live) == "table" and live.professionID and live.professionID ~= 0
               and live.parentProfessionID == row._skillLine then
                current = live.professionID
            end



            local valid = false
            for i = 1, #children do
                if children[i].professionID == current then valid = true break end
            end
            if not valid then
                current = children[1] and children[1].professionID
                state2.expansion[row._skillLine] = nil
            end
            for i = 1, #children do
                local child = children[i]
                local rr = GetRadioRow(i)
                rr._professionID = child.professionID
                rr._label:SetText(child.name)
                rr._setChecked(child.professionID == current)
                rr:ClearAllPoints()
                rr:SetPoint("TOPLEFT", PAD, y)
                rr:Show()
                y = y - ROW_H
                local w3 = Utils.FlyoutRowContentWidth(rr, 22)
                if w3 > contentW then contentW = w3 end
            end
            for i = #children + 1, #radioRows do radioRows[i]:Hide() end
        else
            sep:Hide()
            sourcesOpener:Hide()
            slotsOpener:Hide()
            for i = 1, #radioRows do radioRows[i]:Hide() end
        end
        local w = Utils.FlyoutWidthFor(contentW, PAD)
        for i = 1, #checkRows do checkRows[i]:SetWidth(w - PAD * 2) end
        if hasSlots then slotsOpener:SetWidth(w - PAD * 2) end
        if hasChildren then
            sourcesOpener:SetWidth(w - PAD * 2)
            for i = 1, #radioRows do
                if radioRows[i]:IsShown() then radioRows[i]:SetWidth(w - PAD * 2) end
            end
        end
        popup:SetSize(w, -y + PAD)
    end

    local hover = Utils.AttachHoverPopup(row, popup, {
        extraGuards = { sourcesPopup, slotsPopup },
        onShow = function()
            HideSiblingSubmenus(popup)
            Layout()
            popup:SetScale(EasyFind.db.uiSearchScale or 1.0)
            Utils.OpenFlyoutBeside(popup, row, 4)
            popup:Show()
        end,
    })
    row.ShowFlyoutPopup = hover.Show
    row:HookScript("OnEnter", function(self) HideSiblingSubmenus(self._submenuPopup) end)
    ctx.AddPopupKeyboardNav(popup, function()
        local rows = {}
        for i = 1, #checkRows do rows[#rows + 1] = checkRows[i] end
        if sourcesOpener:IsShown() then rows[#rows + 1] = sourcesOpener end
        if slotsOpener:IsShown() then rows[#rows + 1] = slotsOpener end
        for i = 1, #radioRows do if radioRows[i]:IsShown() then rows[#rows + 1] = radioRows[i] end end
        return rows
    end, row:GetParent())
end




function Filters:AttachProfessionOptionsFlyout(row, dropdown, ctx)
    attachCtx = ctx
    local ROW_H = ctx.rowHeight
    local CHECK = ctx.checkSize
    local PAD = 8

    local root = CreateFrame("Frame", "EasyFindProfessionOptionsPopup", UIParent, "BackdropTemplate")
    root:SetFrameStrata("TOOLTIP")
    ctx.StylePopup(root)
    root:EnableMouse(true)
    root:Hide()
    ctx.dropdownGuardFrames[#ctx.dropdownGuardFrames + 1] = root

    local pool = {}
    local function GetRow(i)
        local r = pool[i]
        if not r then
            r = CreateFrame("CheckButton", nil, root)
            r:SetSize(150, ROW_H)
            r:SetHitRectInsets(0, 0, 0, 0)
            Utils.SetCheckboxTextures(r, CHECK)
            local icon = r:CreateTexture(nil, "ARTWORK")
            icon:SetSize(CHECK, CHECK)
            icon:SetPoint("LEFT", r:GetNormalTexture(), "RIGHT", 4, 0)
            r._icon = icon
            local fs = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            fs:SetPoint("LEFT", icon, "RIGHT", 4, 0)
            r._label = fs
            local chev = r:CreateTexture(nil, "OVERLAY")
            chev:SetAtlas("common-icon-forwardarrow")
            chev:SetSize(CHECK - 2, CHECK - 2)
            chev:SetPoint("RIGHT", -4, 0)
            chev:SetVertexColor(0.85, 0.85, 0.85, 1)
            r._chev = chev

            fs:SetPoint("RIGHT", chev, "LEFT", -4, 0)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(false)
            Utils.InstallMenuRowHighlight(r)
            r:SetScript("OnClick", function(self)
                local t = EasyFind.db.professionFilters
                if not t then t = {}; EasyFind.db.professionFilters = t end
                t[self._skillLine] = Utils.OffOrNil(self:GetChecked())
                if ns.Database and ns.Database.RefreshDynamicCategory then
                    ns.Database:RefreshDynamicCategory("professions")
                end
                Filters:ApplyFilterSelection("professions")
            end)

            if not (ns.Caps and ns.Caps.classic) then AttachRecipeFilterFlyout(r) end
            pool[i] = r
        end
        return r
    end

    local function Layout()
        local profs = KnownProfessions()
        local y, contentW = -PAD, 0
        for i = 1, #profs do
            local prof = profs[i]
            local r = GetRow(i)
            r._skillLine = prof.skillLine
            r._label:SetText(prof.name)
            r._chev:SetShown(ns.PROFESSION_RECIPES and ns.PROFESSION_RECIPES[prof.skillLine] ~= nil)
            r._icon:SetTexture(prof.icon)
            local t = EasyFind.db.professionFilters
            r:SetChecked(not (t and t[prof.skillLine] == false))
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", PAD, y)
            r:Show()
            y = y - ROW_H
            local w = Utils.FlyoutRowContentWidth(r, CHECK + 4, CHECK, CHECK - 2)
            if w > contentW then contentW = w end
        end
        for i = #profs + 1, #pool do pool[i]:Hide() end
        local w = Utils.FlyoutWidthFor(contentW, PAD)
        for i = 1, #profs do pool[i]:SetWidth(w - PAD * 2) end
        root:SetSize(w, -y + PAD)
    end
    root._efSync = Layout

    local hover = Utils.AttachHoverPopup(row, root, {
        extraGuards = childPopups,
        onShow = function()
            ctx.SetActiveFlyout(root)
            Layout()
            root:SetScale(EasyFind.db.uiSearchScale or 1.0)
            Utils.OpenFlyoutBeside(root, row, 4)
            root:Show()
        end,
    })
    row.ShowFlyoutPopup = hover.Show

    ctx.AddPopupKeyboardNav(root, function()
        local rows = {}
        for i = 1, #pool do if pool[i]:IsShown() then rows[#rows + 1] = pool[i] end end
        return rows
    end)
    root:HookScript("OnHide", function() HideAllSubmenus() end)
    Filters.AttachOutsideClickClose(root, {
        onHide = function(self)
            HideAllSubmenus()
            ctx.ClearActiveFlyout(self)
        end,
    })
    dropdown:HookScript("OnHide", function() root:Hide() end)
end
