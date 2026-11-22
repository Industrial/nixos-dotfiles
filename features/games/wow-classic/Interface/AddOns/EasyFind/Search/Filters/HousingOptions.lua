local _, ns = ...

local Filters = ns.Filters
local Utils = ns.Utils

local ipairs = Utils.ipairs
local CreateFrame = CreateFrame
local UIParent = UIParent
local C_HousingCatalog = C_HousingCatalog




local function SortOptions()
    local e = _G.Enum and _G.Enum.HousingCatalogSortType
    return {
        { value = (e and e.DateAdded) or 0,
          label = _G["HOUSING_CHEST_SORT_TYPE_DATE_ADDED"] or "Date Added" },
        { value = (e and e.Alphabetical) or 1,
          label = _G["HOUSING_CHEST_SORT_TYPE_ALPHABETICAL"] or "Alphabetical" },
    }
end












local liveTagGroups

local function FilterTagGroups()
    if liveTagGroups then return liveTagGroups end
    local db = EasyFind and EasyFind.db
    if C_HousingCatalog and C_HousingCatalog.GetAllFilterTagGroups then
        local ok, groups = pcall(C_HousingCatalog.GetAllFilterTagGroups)
        if ok and type(groups) == "table" and #groups > 0 then
            if db then
                local cached = {}
                for gi = 1, #groups do
                    local grp = groups[gi]
                    if grp.groupID then
                        local tags = {}
                        local grpTags = grp.tags or {}
                        for ti = 1, #grpTags do
                            local tag = grpTags[ti]
                            if tag.tagID then
                                tags[#tags + 1] = { tagID = tag.tagID, tagName = tag.tagName }
                            end
                        end
                        cached[#cached + 1] = { groupID = grp.groupID, groupName = grp.groupName, tags = tags }
                    end
                end
                db.housingTagGroupsCache = cached
            end
            liveTagGroups = groups
            return groups
        end
    end
    return (db and db.housingTagGroupsCache) or {}
end

local function ApplyHousingChange()
    if ns.Database and ns.Database.WriteHousingFiltersToBlizzard then
        ns.Database:WriteHousingFiltersToBlizzard()
    end
    Filters:ApplyFilterSelection("housing")
end

function Filters:AttachHousingOptionsFlyout(row, dropdown, ctx)
    local ROW_H = ctx.rowHeight
    local CHECK = ctx.checkSize
    local StylePopup = ctx.StylePopup
    local CreateRadioTexture = ctx.CreateRadioTexture
    local AddPopupKeyboardNav = ctx.AddPopupKeyboardNav
    local guards = ctx.dropdownGuardFrames
    local PAD = 8
    local childPopups = {}




    local function HideOtherSubmenus(except)
        for i = 1, #childPopups do
            if childPopups[i] ~= except then childPopups[i]:Hide() end
        end
    end

    local root = CreateFrame("Frame", "EasyFindHousingOptionsPopup", UIParent, "BackdropTemplate")
    root:SetFrameStrata("TOOLTIP")
    StylePopup(root)
    root:EnableMouse(true)
    root:Hide()
    guards[#guards + 1] = root


    local function NewSubPopup()
        local p = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        p:SetFrameStrata("TOOLTIP")
        p:SetFrameLevel(root:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
        StylePopup(p)
        p:EnableMouse(true)
        p:Hide()
        guards[#guards + 1] = p
        childPopups[#childPopups + 1] = p
        Filters.AttachOutsideClickClose(p)
        root:HookScript("OnHide", function() p:Hide() end)
        return p
    end


    local function CheckboxRow(dbKey, label, applyFn)
        local r = CreateFrame("CheckButton", nil, root)
        r:SetSize(100, ROW_H)
        r:SetHitRectInsets(0, 0, 0, 0)
        Utils.SetCheckboxTextures(r, CHECK)
        local fs = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetPoint("LEFT", r:GetNormalTexture(), "RIGHT", 4, 0)
        fs:SetText(label)
        r._label = fs
        Utils.InstallMenuRowHighlight(r)
        r:HookScript("OnEnter", function() HideOtherSubmenus(nil) end)
        r._dbKey = dbKey
        r:SetScript("OnClick", function(self)
            EasyFind.db[dbKey] = self:GetChecked() and true or false
            (applyFn or ApplyHousingChange)()
        end)
        r.Sync = function() r:SetChecked(EasyFind.db[dbKey] == true) end
        return r
    end


    local function OpenerRow(label)
        local r = CreateFrame("Button", nil, root)
        r:SetSize(100, ROW_H)
        r:SetHitRectInsets(0, 0, 0, 0)
        local fs = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetPoint("LEFT", 6, 0)
        r._label = fs
        local chev = r:CreateTexture(nil, "OVERLAY")
        Utils.SetChevronTexture(chev)
        chev:SetSize(CHECK - 2, CHECK - 2)
        chev:SetPoint("RIGHT", -4, 0)
        r._chev = chev
        fs:SetText(label)
        Utils.InstallMenuRowHighlight(r)
        r:HookScript("OnEnter", function(self)
            chev:SetVertexColor(1, 1, 1, 1)
            HideOtherSubmenus(self._submenuPopup)
        end)
        r:HookScript("OnLeave", function() chev:SetVertexColor(0.85, 0.85, 0.85, 1) end)
        return r
    end


    local function WireSubmenu(opener, popup, layout)
        popup._efSync = layout
        opener._submenuPopup = popup
        local hover = Utils.AttachHoverPopup(opener, popup, {
            onShow = function()
                HideOtherSubmenus(popup)
                layout()
                popup:SetScale(EasyFind.db.uiSearchScale or 1.0)
                Utils.OpenFlyoutBeside(popup, opener, 4)
                popup:Show()
            end,
        })
        opener.ShowFlyoutPopup = hover.Show
    end


    local function RadioSubmenu(title, options, getValue, setValue)
        local opener = OpenerRow(title)
        local popup = NewSubPopup()
        local rows = {}
        local y = -PAD
        for _, opt in ipairs(options) do
            local rr = CreateFrame("Button", nil, popup)
            rr:SetSize(150, ROW_H)
            rr:SetPoint("TOPLEFT", PAD, y)
            local tex, setChecked = CreateRadioTexture(rr)
            tex:SetPoint("LEFT", 2, 0)
            local fs = rr:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            fs:SetPoint("LEFT", tex, "RIGHT", 6, 0)
            fs:SetText(opt.label)
            rr._label = fs
            Utils.InstallMenuRowHighlight(rr)
            rr._value = opt.value
            rr._setChecked = setChecked
            rr:SetScript("OnClick", function()
                setValue(opt.value)
                for _, other in ipairs(rows) do other._setChecked(other._value == opt.value) end
                ApplyHousingChange()
            end)
            rows[#rows + 1] = rr
            y = y - ROW_H
        end
        local contentW = 0
        for i = 1, #rows do
            local w = Utils.FlyoutRowContentWidth(rows[i], 22)
            if w > contentW then contentW = w end
        end
        local w = Utils.FlyoutWidthFor(contentW, PAD)
        for i = 1, #rows do rows[i]:SetWidth(w - PAD * 2) end
        popup:SetSize(w, -y + PAD)
        local function layout()
            local cur = getValue()
            for i = 1, #rows do rows[i]._setChecked(rows[i]._value == cur) end
        end
        WireSubmenu(opener, popup, layout)
        AddPopupKeyboardNav(popup, function() return rows end, root)
        return opener
    end





    local function CheckSubmenu(title, defsFn, actionsFn)
        local opener = OpenerRow(title)
        local popup = NewSubPopup()
        local pool = {}
        local actionPool = {}
        local function GetActionRow(i)
            local r = actionPool[i]
            if not r then
                r = CreateFrame("Button", nil, popup)
                r:SetSize(150, ROW_H)
                r:SetHitRectInsets(0, 0, 0, 0)
                local fs = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                fs:SetPoint("LEFT", 6, 0)
                r._label = fs
                Utils.InstallMenuRowHighlight(r)
                r:SetScript("OnClick", function(self)
                    if self._action then self._action.run() end
                    ApplyHousingChange()
                    if popup._efSync then popup._efSync() end
                end)
                actionPool[i] = r
            end
            return r
        end
        local function GetRow(i)
            local r = pool[i]
            if not r then
                r = CreateFrame("CheckButton", nil, popup)
                r:SetSize(150, ROW_H)
                r:SetHitRectInsets(0, 0, 0, 0)
                Utils.SetCheckboxTextures(r, CHECK)
                local fs = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                fs:SetPoint("LEFT", r:GetNormalTexture(), "RIGHT", 4, 0)
                r._label = fs
                Utils.InstallMenuRowHighlight(r)
                r:SetScript("OnClick", function(self)
                    if self._def then self._def.set(self:GetChecked() and true or false) end
                    ApplyHousingChange()
                end)
                pool[i] = r
            end
            return r
        end
        local function layout()
            local actions = actionsFn and actionsFn() or nil
            local defs = defsFn() or {}
            local y, contentW = -PAD, 0
            local nActions = actions and #actions or 0
            for i = 1, nActions do
                local r = GetActionRow(i)
                r._action = actions[i]
                r._label:SetText(actions[i].label)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", PAD, y)
                r:Show()
                y = y - ROW_H
                local w = Utils.FlyoutRowContentWidth(r, 8)
                if w > contentW then contentW = w end
            end
            for i = nActions + 1, #actionPool do actionPool[i]:Hide() end
            for i = 1, #defs do
                local def = defs[i]
                local r = GetRow(i)
                r._def = def
                r._label:SetText(def.label)
                r:SetChecked(def.get() and true or false)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", PAD, y)
                r:Show()
                y = y - ROW_H
                local w = Utils.FlyoutRowContentWidth(r, CHECK + 4)
                if w > contentW then contentW = w end
            end
            for i = #defs + 1, #pool do pool[i]:Hide() end
            local w = Utils.FlyoutWidthFor(contentW, PAD)
            for i = 1, nActions do actionPool[i]:SetWidth(w - PAD * 2) end
            for i = 1, #defs do pool[i]:SetWidth(w - PAD * 2) end
            popup:SetSize(w, (#defs + nActions > 0) and (-y + PAD) or (ROW_H + PAD * 2))
        end
        WireSubmenu(opener, popup, layout)
        AddPopupKeyboardNav(popup, function()
            local rows = {}
            for i = 1, #actionPool do if actionPool[i]:IsShown() then rows[#rows + 1] = actionPool[i] end end
            for i = 1, #pool do if pool[i]:IsShown() then rows[#rows + 1] = pool[i] end end
            return rows
        end, root)
        return opener
    end


    local sortOpener = RadioSubmenu(
        _G["HOUSING_CATALOG_SORT_LABEL"] or "Sort By", SortOptions(),
        function() return EasyFind.db.housingSortType or 0 end,
        function(v) EasyFind.db.housingSortType = v end)

    local dyeableRow = CheckboxRow("housingDyeableOnly",
        _G["HOUSING_CATALOG_FILTERS_DYEABLE"] or "Dyeable Only")
    local bonusRow = CheckboxRow("housingCollectionBonusOnly",
        _G["HOUSING_CATALOG_FILTERS_FIRST_ACQUISITION"] or "Collection Bonus")

    local collectionOpener = RadioSubmenu(
        _G["HOUSING_CATALOG_FILTERS_COLLECTION_LABEL"] or "Collection",
        {
            { value = "all",         label = _G["HOUSING_CATALOG_FILTERS_COLLECTION_BOTH"] or _G["ALL"] or "All" },
            { value = "collected",   label = _G["HOUSING_CATALOG_FILTERS_COLLECTED"] or "Collected" },
            { value = "uncollected", label = _G["HOUSING_CATALOG_FILTERS_UNCOLLECTED"] or "Uncollected" },
        },
        function() return EasyFind.db.housingCollection or "collected" end,
        function(v) EasyFind.db.housingCollection = v end)

    local placeableOpener = CheckSubmenu(
        _G["HOUSING_CATALOG_FILTERS_LOCATION_LABEL"] or "Placeable",
        function()
            return {
                { label = _G["HOUSING_CATALOG_FILTERS_INDOORS"] or "Indoors",
                  get = function() return EasyFind.db.housingIndoors ~= false end,
                  set = function(v) EasyFind.db.housingIndoors = v end },
                { label = _G["HOUSING_CATALOG_FILTERS_OUTDOORS"] or "Outdoors",
                  get = function() return EasyFind.db.housingOutdoors ~= false end,
                  set = function(v) EasyFind.db.housingOutdoors = v end },
            }
        end)





    local roomsRow = CheckboxRow("housingShowRooms",
        _G["HOUSING_ITEM_TOAST_TYPE_ROOM"] or "Rooms",
        function()
            if ns.Database and ns.Database.ResetSearchCache then ns.Database:ResetSearchCache() end
            if ns.Search and ns.Search.RefreshResults then ns.Search:RefreshResults() end
        end)



    local tagOpenerPool = {}


    local function SetAllGroupTags(gid, active)
        local t = EasyFind.db.housingTags
        if not t then t = {}; EasyFind.db.housingTags = t end



        local grpTags = {}
        t[gid] = grpTags
        if active then
            for _, grp in ipairs(FilterTagGroups()) do
                if grp.groupID == gid and grp.tags then
                    for _, tag in ipairs(grp.tags) do grpTags[tag.tagID] = true end
                    break
                end
            end
        end
    end
    local function GetTagOpener(i, groupID, groupName)
        local o = tagOpenerPool[i]
        if not o then
            o = CheckSubmenu(groupName, function()
                local defs = {}
                local gid = o._groupID
                if not gid then return defs end
                for _, grp in ipairs(FilterTagGroups()) do
                    if grp.groupID == gid and grp.tags then
                        for _, tag in ipairs(grp.tags) do
                            local tid = tag.tagID
                            defs[#defs + 1] = {
                                label = tag.tagName or tostring(tid),
                                get = function()
                                    local t = EasyFind.db.housingTags
                                    return t and t[gid] and t[gid][tid] == true
                                end,
                                set = function(v)
                                    local t = EasyFind.db.housingTags
                                    if not t then t = {}; EasyFind.db.housingTags = t end
                                    t[gid] = t[gid] or {}
                                    t[gid][tid] = v and true or nil
                                end,
                            }
                        end
                        break
                    end
                end
                return defs
            end, function()
                local gid = o._groupID
                if not gid then return nil end
                return {
                    { label = _G["CHECK_ALL"] or "Check All",
                      run = function() SetAllGroupTags(gid, true) end },
                    { label = _G["UNCHECK_ALL"] or "Uncheck All",
                      run = function() SetAllGroupTags(gid, false) end },
                }
            end)
            tagOpenerPool[i] = o
        end
        o._groupID = groupID
        o._label:SetText(groupName)
        return o
    end


    local fixedOpeners = { sortOpener, dyeableRow, bonusRow, collectionOpener, placeableOpener, roomsRow }



    local SEP_H = 8
    local function NewSeparator()
        local sep = root:CreateTexture(nil, "ARTWORK")
        sep:SetColorTexture(1, 1, 1, 0.12)
        sep:SetHeight(1)
        root._efThemeSeps = root._efThemeSeps or {}
        root._efThemeSeps[#root._efThemeSeps + 1] = sep
        return sep
    end
    local sortSep = NewSeparator()
    local tagSep = NewSeparator()
    ns.RetintMenuSeparators(root)

    local function LayoutRoot()
        local groups = FilterTagGroups()
        local y, contentW = -PAD, 0
        local placed = {}
        local function place(r)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", root, "TOPLEFT", PAD, y)
            r:Show()
            placed[#placed + 1] = r
            y = y - ROW_H
            local w = Utils.FlyoutRowContentWidth(r, CHECK + 4, nil, CHECK - 2)
            if w > contentW then contentW = w end
        end
        local function placeSep(sep)
            sep:ClearAllPoints()
            sep:SetPoint("LEFT", root, "LEFT", PAD, 0)
            sep:SetPoint("RIGHT", root, "RIGHT", -PAD, 0)
            sep:SetPoint("TOP", root, "TOP", 0, y - SEP_H * 0.5)
            sep:Show()
            y = y - SEP_H
        end
        place(sortOpener)
        placeSep(sortSep)
        place(dyeableRow)
        place(bonusRow)
        place(collectionOpener)
        place(placeableOpener)
        place(roomsRow)
        if #groups > 0 then
            placeSep(tagSep)
        else
            tagSep:Hide()
        end
        for gi = 1, #groups do
            local grp = groups[gi]
            if grp.groupID then place(GetTagOpener(gi, grp.groupID, grp.groupName or ("Group " .. gi))) end
        end
        for gi = #groups + 1, #tagOpenerPool do tagOpenerPool[gi]:Hide() end
        local w = Utils.FlyoutWidthFor(contentW, PAD)
        for i = 1, #placed do placed[i]:SetWidth(w - PAD * 2) end
        root:SetSize(w, -y + PAD)
    end

    local function SyncAll()
        LayoutRoot()
        local chainEnabled = EasyFind.db.uiSearchFilters.housing ~= false
        dyeableRow.Sync()
        bonusRow.Sync()
        roomsRow.Sync()
        for _, r in ipairs(fixedOpeners) do Utils.SetFlyoutRowEnabled(r, chainEnabled) end
        for i = 1, #tagOpenerPool do Utils.SetFlyoutRowEnabled(tagOpenerPool[i], chainEnabled) end
    end
    root._efSync = SyncAll

    local hover = Utils.AttachHoverPopup(row, root, {
        extraGuards = childPopups,
        onShow = function()
            ctx.SetActiveFlyout(root)


            if ns.Database and ns.Database.SyncHousingFiltersFromBlizzard then
                ns.Database:SyncHousingFiltersFromBlizzard()
            end
            SyncAll()







            if #FilterTagGroups() == 0 and EasyFind.db.uiSearchFilters.housing ~= false
               and ns.Database and ns.Database.RequestDynamicProviderLoaded then
                ns.Database:RequestDynamicProviderLoaded("housing", nil)
                if not root._efGroupPoll then
                    root._efGroupPoll = true
                    local tries = 0
                    local function waitForGroups()
                        if not root:IsShown() or #FilterTagGroups() > 0 then
                            root._efGroupPoll = nil
                            if root:IsShown() then SyncAll() end
                            return
                        end
                        tries = tries + 1
                        if tries < 20 then
                            Utils.SafeAfter(0.3, waitForGroups)
                        else
                            root._efGroupPoll = nil
                        end
                    end
                    Utils.SafeAfter(0.3, waitForGroups)
                end
            end
            root:SetScale(EasyFind.db.uiSearchScale or 1.0)
            Utils.OpenFlyoutBeside(root, row, 4)
            root:Show()
        end,
    })
    row.ShowFlyoutPopup = hover.Show

    Filters.AttachOutsideClickClose(root, {
        onHide = function(self)
            for i = 1, #childPopups do childPopups[i]:Hide() end
            ctx.ClearActiveFlyout(self)
        end,
    })
    dropdown:HookScript("OnHide", function() root:Hide() end)
    AddPopupKeyboardNav(root, function()
        local rows = {}
        for _, r in ipairs(fixedOpeners) do if r:IsShown() then rows[#rows + 1] = r end end
        for i = 1, #tagOpenerPool do if tagOpenerPool[i]:IsShown() then rows[#rows + 1] = tagOpenerPool[i] end end
        return rows
    end)
end
