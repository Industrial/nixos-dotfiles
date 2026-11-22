local _, ns = ...

local Search = ns.Search
local Handlers = ns.ResultHandlers
local Icons = ns.ResultIcons
local Openers = ns.SearchOpeners
local Utils = ns.Utils

local ipairs = Utils.ipairs
local InCombatLockdown = InCombatLockdown
local C_Item = C_Item
local C_MountJournal = C_MountJournal
local C_PetJournal = C_PetJournal
local C_TransmogSets = C_TransmogSets

function Handlers:FinishResultSelection()
    Search:SetSelectingResult(true)
    Search:GetSearchFrame().editBox:SetText("")
    Search:GetSearchFrame().editBox:ClearFocus()
    Search:GetSearchFrame().editBox.placeholder:Show()



    Search:ClearQuickFilter(false)
    Search:HideQuickFilterSuggestions()
    Search:SetSelectingResult(false)
    if EasyFind.db.autoHide then
        self:Hide()
    else
        self:HideResults()
        if EasyFind.db.smartShow then
            Search:GetSearchFrame().smartShowFadeOut()
        end
    end
end














local function ResolveChildSkillLine(parentSkillLine)
    local ts = C_TradeSkillUI
    if not (parentSkillLine and ts and ts.GetAllProfessionTradeSkillLines
            and ts.GetProfessionInfoBySkillLineID) then
        return nil
    end
    local okParent, parentInfo = pcall(ts.GetProfessionInfoBySkillLineID, parentSkillLine)
    if not (okParent and type(parentInfo) == "table" and parentInfo.profession) then
        return nil
    end
    local okAll, allLines = pcall(ts.GetAllProfessionTradeSkillLines)
    if not (okAll and type(allLines) == "table") then return nil end






    local firstMatch
    for i = 1, #allLines do
        local lineID = allLines[i]
        if lineID and lineID ~= parentSkillLine then
            local okInfo, info = pcall(ts.GetProfessionInfoBySkillLineID, lineID)
            if okInfo and type(info) == "table" and info.profession == parentInfo.profession then
                firstMatch = firstMatch or lineID
                if (info.skillLevel or 0) > 0 then return lineID end
            end
        end
    end
    return firstMatch
end











local function ProfessionListHasData()
    local frame = _G["ProfessionsFrame"]
    local list = frame and frame.CraftingPage and frame.CraftingPage.RecipeList
    local scrollBox = list and list.ScrollBox
    if not (scrollBox and scrollBox.GetDataProvider) then return nil end
    local ok, provider = pcall(scrollBox.GetDataProvider, scrollBox)
    if not ok then return nil end
    return provider ~= nil
end



local function EnsureProfessionsLoaded()
    if C_AddOns and C_AddOns.LoadAddOn and C_AddOns.IsAddOnLoaded
       and not C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_Professions")
    end
end

local function OpenProfessionPage(openID)
    local openProf = _G["OpenProfessionUIToSkillLine"]
    if not openProf then return false end
    EnsureProfessionsLoaded()
    pcall(openProf, openID)






    Utils.SafeAfter(0.35, function()
        local frame = _G["ProfessionsFrame"]
        if frame and frame:IsShown() and ProfessionListHasData() == false then
            pcall(openProf, openID)
        end
    end)
    return true
end




local function DisplayedRecipeID()
    local profFrame = _G["ProfessionsFrame"]
    local form = profFrame and profFrame.CraftingPage
        and profFrame.CraftingPage.SchematicForm
    if not (form and form.GetRecipeInfo) then return nil end
    local ok, info = pcall(form.GetRecipeInfo, form)
    return ok and type(info) == "table" and info.recipeID or nil
end


local function Replaced(name)
    local R = ns.SearchOpeners and ns.SearchOpeners.Replacement
    return R and R(name)
end

local function ReplacedShown(api, name)
    local ok, frame = pcall(api.GetFrame, name)
    return ok and frame ~= nil and frame:IsVisible()
end

local function OpenPageOrBook(openID)

    local book = Replaced("professionsBook")
    if book or Replaced("tradeSkill") then
        if book then pcall(book.Open, "professionsBook") end
        return
    end
    if openID and OpenProfessionPage(openID) then return end
    if _G["ToggleProfessionsBook"] then
        pcall(_G["ToggleProfessionsBook"])
    end
end



















Handlers.CLASSIC_RECIPE_WINDOWS = {
    { frame = "TradeSkillFrame", line = "GetTradeSkillLine", count = "GetNumTradeSkills", info = "GetTradeSkillInfo",
      expand = "ExpandTradeSkillSubClass", select = "TradeSkillFrame_SetSelection", update = "TradeSkillFrame_Update",
      scroll = "TradeSkillListScrollFrame", rows = "TradeSkillSkill", shown = "TRADE_SKILLS_DISPLAYED",
      height = "TRADE_SKILL_HEIGHT" },
    { frame = "CraftFrame", line = "GetCraftDisplaySkillLine", name = "GetCraftName", count = "GetNumCrafts",
      info = "GetCraftInfo", expand = "ExpandCraftSkillLine", select = "CraftFrame_SetSelection",
      update = "CraftFrame_Update", scroll = "CraftListScrollFrame", rows = "Craft", shown = "CRAFTS_DISPLAYED",
      height = "CRAFT_SKILL_HEIGHT" },
}

function Handlers.FindClassicRecipe(win, profName, recipe)
    local frame = _G[win.frame]
    if not (frame and frame:IsShown() and _G[win.count] and _G[win.info]) then return nil end
    local line = _G[win.line] and _G[win.line]()
    if (not line or line == "" or line == "UNKNOWN") and win.name and _G[win.name] then line = _G[win.name]() end
    if line ~= profName then return nil end
    if _G[win.expand] then _G[win.expand](0) end
    for i = 1, _G[win.count]() or 0 do
        if _G[win.info](i) == recipe then return i end
    end
    return nil
end

function Handlers:SelectClassicRecipe(data)
    local tries = 0
    local function aim()
        tries = tries + 1
        for _, win in ipairs(Handlers.CLASSIC_RECIPE_WINDOWS) do
            local index = Handlers.FindClassicRecipe(win, data.classicProfession, data.name)
            if index then
                if _G[win.select] then _G[win.select](index) end
                local scroll = _G[win.scroll]
                local bar = scroll and _G[win.scroll .. "ScrollBar"]
                local shown, height = _G[win.shown] or 8, _G[win.height] or 16
                if bar then bar:SetValue(math.max(0, index - math.ceil(shown / 2)) * height) end
                if _G[win.update] then _G[win.update]() end
                local highlight = ns.RequestGuide()
                for n = 1, shown do
                    local row = _G[win.rows .. n]
                    if row and row:IsShown() and row:GetID() == index then
                        if highlight and highlight.HighlightFrame then highlight:HighlightFrame(row, nil, nil, true) end
                        break
                    end
                end
                return
            end
        end
        if tries < 15 then Utils.SafeAfter(0.2, aim) end
    end
    aim()
end

local function OpenProfessionTarget(data)
    local recipeID = data.professionRecipeID
    local openRecipe = C_TradeSkillUI and C_TradeSkillUI.OpenRecipe
    local tradeSkill = Replaced("tradeSkill")


    if recipeID and tradeSkill then
        pcall(tradeSkill.Open, "tradeSkill", "recipe:" .. recipeID)
        return
    end
    if recipeID and openRecipe then
        EnsureProfessionsLoaded()
        pcall(openRecipe, recipeID)





        local tries, reAimed = 0, false
        local function verify()
            local profFrame = _G["ProfessionsFrame"]
            if profFrame and profFrame:IsShown() then
                if DisplayedRecipeID() == recipeID then return end
                if not reAimed and ProfessionListHasData() then
                    reAimed = true
                    pcall(openRecipe, recipeID)
                end
            end
            tries = tries + 1
            if tries < 15 then Utils.SafeAfter(0.1, verify) end
        end
        Utils.SafeAfter(0.1, verify)
        return
    end




    local openID = ResolveChildSkillLine(data.professionSkillLine) or data.professionOpenID
    if data.spellID then
        Utils.SafeAfter(0.8, function()
            local profFrame = _G["ProfessionsFrame"]
            if profFrame and profFrame:IsShown() then return end
            if tradeSkill and ReplacedShown(tradeSkill, "tradeSkill") then return end

            local archFrame = _G["ArchaeologyFrame"]
            if archFrame and archFrame:IsShown() then return end
            OpenPageOrBook(openID)
        end)
        return
    end
    OpenPageOrBook(openID)
end



local craft = { events = CreateFrame("Frame"), run = CreateFrame("Frame"), open = false }


function Handlers.RecipeProfessionOpen(data)
    local ts = C_TradeSkillUI
    if not (craft.open and data and ts.GetBaseProfessionInfo) then return false end
    local base, child = ts.GetBaseProfessionInfo(), ts.GetChildProfessionInfo and ts.GetChildProfessionInfo()
    local want, page = data.professionSkillLine, data.professionOpenID or false
    local function Is(id) return id ~= nil and (id == want or id == page) end
    return Is(base and base.professionID) or Is(base and base.parentProfessionID) or Is(child and child.professionID)
end

craft.events:SetScript("OnEvent", function(_, event)
    craft.open = event == "TRADE_SKILL_SHOW"
end)
craft.events:RegisterEvent("TRADE_SKILL_SHOW")
craft.events:RegisterEvent("TRADE_SKILL_CLOSE")


local function EndUnseen()
    local u = craft.unseen
    if not u then return end
    craft.unseen = nil
    craft.run:UnregisterAllEvents()
    if craft.open then C_TradeSkillUI.CloseTradeSkill() end
    local f = u.frame
    if not f then return end
    f:SetAlpha(u.alpha)
    f:ClearAllPoints()
    for _, p in ipairs(u.points) do f:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
end


local function AwaitStart(u)
    u.wait = u.wait + 1
    local token = u.wait
    Utils.SafeAfter(3, function()
        if craft.unseen == u and u.wait == token then EndUnseen() end
    end)
end



craft.run:SetScript("OnEvent", function(_, event, _, _, spellID)
    local u = craft.unseen
    if not u then return end
    if event ~= "TRADE_SKILL_CLOSE" then
        if issecretvalue and issecretvalue(spellID) or spellID ~= u.recipeID then return end
        if event == "UNIT_SPELLCAST_START" then
            u.left, u.wait = u.left - 1, u.wait + 1
            if u.left > 0 then return end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            return AwaitStart(u)
        end
    end
    EndUnseen()
end)



local function OpenUnseen(data)
    EndUnseen()

    local inSight = craft.open
    C_TradeSkillUI.OpenTradeSkill(data.professionSkillLine)
    if not Handlers.RecipeProfessionOpen(data) then return false end
    if inSight then return true end
    local f = _G["ProfessionsFrame"]
    local u = { frame = f, left = 0, wait = 0 }
    if f then
        u.alpha, u.points = f:GetAlpha(), {}
        for i = 1, f:GetNumPoints() do u.points[i] = { f:GetPoint(i) } end
        f:SetAlpha(0)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "TOPRIGHT", 6000, 0)
    end
    craft.unseen = u
    local run = craft.run
    run:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    run:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    run:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
    run:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    run:RegisterEvent("TRADE_SKILL_CLOSE")
    return true
end




function Handlers.CraftableCount(recipeID)
    local ts = C_TradeSkillUI
    local ok, schematic = pcall(ts.GetRecipeSchematic, recipeID, false)
    local most
    if ok and type(schematic) == "table" and schematic.reagentSlotSchematics then
        for _, slot in ipairs(schematic.reagentSlotSchematics) do
            if slot.required and slot.reagentType == Enum.CraftingReagentType.Basic then
                if #slot.reagents > 1 then return nil end
                local reagent = slot.reagents[1]
                local have = reagent and reagent.itemID and C_Item.GetItemCount(reagent.itemID, false, false, true) or 0
                local lots = math.floor(have / math.max(1, slot.quantityRequired or 1))
                most = most and math.min(most, lots) or lots
            end
        end
    end
    if most then return most end
    local okCount, count = pcall(ts.GetCraftableCount, recipeID)
    return okCount and tonumber(count) or 0
end


function Handlers.CanCraft(data)
    local recipeID = data and data.professionRecipeID
    return recipeID ~= nil and C_TradeSkillUI ~= nil and C_TradeSkillUI.CraftRecipe ~= nil
        and not InCombatLockdown() and C_SpellBook.IsSpellKnown(recipeID) == true
end

function Handlers:CraftRecipe(data, count)
    if not Handlers.CanCraft(data) then return end
    if not Handlers.RecipeProfessionOpen(data) and not OpenUnseen(data) then return end
    count = math.max(1, count or 1)
    C_TradeSkillUI.CraftRecipe(data.professionRecipeID, count)
    local u = craft.unseen
    if u then
        u.recipeID, u.left = data.professionRecipeID, count
        AwaitStart(u)
    end
end





function Handlers:OpenLootSource(data, useFast)
    if not (ns.Caps and ns.Caps.journal) then


        local held = ns.ResultGestures and ns.ResultGestures.Held and ns.ResultGestures.Held() or "click"
        if ns.Extensions and ns.Extensions.DecoratorSelect(data, held) then return end
        for _, e in ipairs(ns.FOREVER_INSTANCES or {}) do
            if e.id == data.instanceID and EasyFind.API.HasAction("gps", "navigate") then
                EasyFind.API.CallAction("gps", "navigate", { name = data.lootInstanceName or e.n, mapID = e.m,
                    x = e.x, y = e.y, isDungeonEntrance = true, category = e.raid and "raid" or "dungeon" })
                return
            end
        end
        local lootLink = ns.Database and ns.Database:GetLootItemLink(data)
        if lootLink and ChatEdit_InsertLink then ChatEdit_InsertLink(lootLink) end
        return
    end

    if ns.Database then ns.Database:SyncEJLootFilter() end
    local tabIndex = data.lootSourceType == "Raid" and 5 or 4
    local ejDiffID = ns.Database and ns.Database:GetEJDifficultyID(data.lootSourceType)
    local guideData = {
        steps = {
            { buttonFrame = "EJMicroButton" },
            { waitForFrame = "EncounterJournal", tabIndex = tabIndex },
            { waitForFrame = "EncounterJournal", ejInstance = data.lootInstanceName, ejInstanceID = data.instanceID },
            { waitForFrame = "EncounterJournal", ejBoss = data.lootSourceName, ejEncounterID = data.encounterID },
            { waitForFrame = "EncounterJournal", ejLootTab = true, ejDifficultyID = ejDiffID },
            { waitForFrame = "EncounterJournal", ejLootItem = data.itemID, ejLootItemName = data.name },
        },
    }
    if useFast then
        self:DirectOpen(guideData)
    else
        EasyFind:StartGuide(guideData)
    end
end

function Handlers:SelectResult(data, forceGuide)
    if not data then return end




    if InCombatLockdown() then return end

    if ns.ResultGestures.Blocked(data) then return end


    if data.pageAction then
        data.pageAction(data)
        return
    end
    local useFast = not forceGuide










    if ns.Learned and not data.quickFilterDef and not data.noLearn then
        ns.Learned:RecordPick(data, Search.GetTypedQuery and Search:GetTypedQuery() or "")
    end

    if data.quickFilterDef then
        self:ApplyQuickFilter(data.quickFilterDef, "")
        return
    end


    if data.turnOnFilter then
        local filterKey = data.turnOnFilter
        self:FinishResultSelection()
        ns.Filters:TurnOnFilter(filterKey)
        return
    end


    if data.mapSearchResult and data.npcID and ns.ResultGestures.Held() == "shift"
       and ns.ItemSources and ns.ItemSources.WareCount(data) then
        ns.ItemSources:ShowWares(data)
        return
    end





    if data.catalogItem then
        if ns.ResultGestures.Does(data, "sources") and ns.ItemSources then
            ns.ItemSources:Show(data)
            return
        end
        if Handlers:IsSourceCtrlHeld(data) then
            local link = C_Item and C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(data.itemID))
            if link and DressUpItemLink then DressUpItemLink(link) end
            self:FinishResultSelection()
        end


        return
    end





    if Handlers:IsLookupRow(data) and not Handlers:IsSourceModifierHeld(data) then
        if ns.ResultGestures.Does(data, "sources") and ns.ItemSources then
            ns.ItemSources:Show(data)
            return
        end
        if Handlers:IsSourceCtrlHeld(data) and data.itemID then
            local link = C_Item and C_Item.GetItemInfo
                and select(2, C_Item.GetItemInfo(data.itemID))
            if link and DressUpItemLink then DressUpItemLink(link) end
            self:FinishResultSelection()
        end
        return
    end

    if data.searchCommand then




        local cmd = data.searchCommand
        self:FinishResultSelection()
        self:RunSearchBarCommand("/" .. cmd)
        return
    end




    if not data.nativeRun and ns.FindApplicationEntry and not data.quicklistID and ns.ApplicationEntryID(data) then
        local live = ns.FindApplicationEntry(data)
        if live then data = live end
    end

    if data.nativeRun then
        local run = data.nativeRun
        self:FinishResultSelection()
        run()
        return
    end


    if (data.socialName or data.socialBNet) and ns.Social then
        local shift = ns.ResultGestures.Held() == "shift"
        self:FinishResultSelection()
        ns.Social.Select(data, shift)
        return
    end

    if data.holidayDay and ns.Holidays then
        self:FinishResultSelection()
        ns.Holidays.Open(data)
        return
    end




    if data.copyText then
        if ns.RowCopy then ns.RowCopy:ArmForData(data) end
        return
    end


    if ns.Extensions and ns.Extensions.SelectRow(data, function() self:FinishResultSelection() end) then
        return
    end


    if data.quicklistID and ns.Quicklists then
        local listID = data.quicklistID
        self:FinishResultSelection()
        ns.Quicklists:OpenSoon(listID)
        return
    end




    if data.category == "Command" and not data.slashCommand
        and ns.SearchCommands and ns.SearchCommands.ResolveNativeRun then
        local run = ns.SearchCommands:ResolveNativeRun(data.name)
        if run then
            self:FinishResultSelection()
            run()
            return
        end
    end

    if data.specSetIndex or data.loadoutConfigID then
        local specIndex, loadoutID = data.specSetIndex, data.loadoutConfigID
        self:FinishResultSelection()
        if ns.RunTalentSwap then ns.RunTalentSwap(specIndex, loadoutID) end
        return
    end

    if data.calculatorResult then
        self:ArmCalculatorResultForData(data)
        return
    end





    if data.titleID then
        local titleID = data.titleID
        local unearned = data.titleUnearned
        local altHeld = Handlers:IsSourceModifierHeld(data)
        local achID = ns.Database and ns.Database.GetTitleSourceAchievement
            and ns.Database:GetTitleSourceAchievement(titleID)
        self:FinishResultSelection()



        if achID and (altHeld or unearned) then
            self:OpenAchievementByID(achID)
        elseif not unearned and SetCurrentTitle then
            SetCurrentTitle(titleID)
        end





        return
    end




    if useFast and self.KeepOpenForRepeatUse and self:KeepOpenForRepeatUse(data) then
        self:AfterRepeatUse(data)
        return
    end
    self:FinishResultSelection()



    if data.slashCommand then return end


    if data.category == "Boss" and data.encounterID and ns.ResultGestures.Held() == "shift" then
        EasyFind.API.ShowScope("loot", data.name)
        return
    end



    if data.category == "Boss" and data.encounterID and not (ns.Caps and ns.Caps.journal) then
        local gesture = (Handlers:IsSourceModifierHeld(data) and "alt") or (Handlers:IsSourceCtrlHeld(data) and "ctrl") or "click"
        if not (ns.Extensions and ns.Extensions.DecoratorSelect(data, gesture)) then
            EasyFind.API.ShowScope("loot", data.name)
        end
        return
    end








    if data.professionSkillLine then
        OpenProfessionTarget(data)
        return
    end

    if data.classicProfession then
        if data.classicRecipe then Handlers:SelectClassicRecipe(data) end
        return
    end


    if data.steps and data.steps[1] and data.steps[1].loadTransmog then
        if not TransmogFrame then
            Transmog_LoadUI()
        end
        if TransmogFrame then
            Openers:SecureShowUIPanel(TransmogFrame)
            self:ApplyTransmogBrowseMode()
        end
        return
    end




    if data.quickKeybindActivate and not Handlers:IsSourceModifierHeld(data)
       and Openers:ActivateQuickKeybindMode() then
        return
    end





    local firstStep = data.steps and data.steps[1]
    if firstStep and (firstStep.settingsCategory or firstStep.open) then
        if forceGuide and firstStep.settingsCategory then
            local settingsStep = data.steps[1]
            EasyFind:StartGuide({
                name = data.name,
                steps = {
                    { buttonFrame = "MainMenuMicroButton" },
                    { gameMenuText = _G["GAMEMENU_OPTIONS"] or _G["OPTIONS"] or "Options" },
                    {
                        waitForFrame = "SettingsPanel",
                        settingsCategory = settingsStep.settingsCategory,
                        settingCategoryID = settingsStep.settingCategoryID,
                        settingVariable = settingsStep.settingVariable,
                    },
                },
            })
            return
        end
        if ns.BlizzOptionsSearch then
            ns.BlizzOptionsSearch:HandleStep(data.steps[1])
        end
        return
    end



    if data.outfitID then
        if forceGuide or Handlers:IsSourceModifierHeld(data) then
            self:OpenOutfitInTransmog(data)
        end
        return
    end




    if data.housingRecordID then
        local guideData = {
            name = data.name,
            steps = {
                { buttonFrame = "HousingMicroButton" },
                { waitForFrame = "HousingDashboardFrame", housingCatalogTab = true,
                  housingCatalogSearch = data.name,
                  housingCatalogRecordID = data.housingRecordID },
            },
        }
        if useFast then
            self:DirectOpen(guideData)
        else
            EasyFind:StartGuide(guideData)
        end
        return
    end


    if data.itemID and data.category == "Loot" then
        local lootLink = ns.Database and ns.Database:GetLootItemLink(data)
        if Handlers:IsSourceCtrlHeld(data) and lootLink then
            if DressUpItemLink(lootLink) then
                return
            end
        end
        self:OpenLootSource(data, useFast)
        return
    end




    if data.category == "Appearance Set" and not data.transmogSetID and data.name and ns.Database then
        data.transmogSetID = ns.Database:GetTransmogSetIDByName(data.name)
    end
    if data.transmogSetID then
        if Handlers:IsSourceCtrlHeld(data) then
            self:DressUpAppearanceSet(data.transmogSetID)
            return
        end

        local setID = data.transmogSetID
        local GetBaseSetID = C_TransmogSets.GetBaseSetID
        local baseID = GetBaseSetID and GetBaseSetID(setID) or setID
        local guideData = {
            steps = {
                { buttonFrame = "CollectionsMicroButton" },
                { waitForFrame = "CollectionsJournal", tabIndex = 5 },
                { waitForFrame = "WardrobeCollectionFrame", wardrobeSetsTab = true },
                { waitForFrame = "WardrobeCollectionFrame", transmogSetID = baseID },
            },
        }
        if baseID ~= setID then
            guideData.steps[#guideData.steps + 1] = { waitForFrame = "WardrobeCollectionFrame", transmogVariantDropdown = true }
            guideData.steps[#guideData.steps + 1] = { waitForFrame = "WardrobeCollectionFrame", transmogVariantSetID = setID }
        end
        if useFast then
            self:DirectOpen(guideData)
        else
            EasyFind:StartGuide(guideData)
        end
        return
    end



    if data.appearanceItemID then
        local guideData = {
            name = data.name,
            steps = {
                { buttonFrame = "CollectionsMicroButton" },
                { waitForFrame = "CollectionsJournal", tabIndex = 5, entry = "appearance:" .. data.appearanceItemID },
                { waitForFrame = "WardrobeCollectionFrame", wardrobeItemsTab = true },
                { waitForFrame = "WardrobeCollectionFrame",
                  appearanceSourceID = data.appearanceItemID,
                  appearanceVisualID = data.appearanceVisualID,
                  appearanceSlot = data.appearanceSlot },
            },
        }
        if useFast then
            self:DirectOpen(guideData)
        else
            EasyFind:StartGuide(guideData)
        end
        return
    end



    if data.mountID then
        if Handlers:IsSourceCtrlHeld(data) then
            if self:PreviewMountInDressUp(data) then return end
            self:OpenMountInJournal(data)
            return
        end
        if forceGuide then
            EasyFind:StartGuide(self:BuildMountJournalGuideData(data))
            return
        end
        if Handlers:IsSourceModifierHeld(data) or not Icons:IsMountSummonable(data) then
            self:OpenMountInJournal(data)
            return
        end
        if C_MountJournal and C_MountJournal.SummonByID then
            C_MountJournal.SummonByID(data.mountID)
        end
        return
    end



    if data.heirloomItemID then


        if forceGuide or Handlers:IsSourceModifierHeld(data) then
            local guideData = {
                name = data.name,
                buttonFrame = "CollectionsMicroButton",
                steps = {
                    { buttonFrame = "CollectionsMicroButton" },
                    { waitForFrame = "CollectionsJournal", tabIndex = 4, entry = "heirloom:" .. data.heirloomItemID },
                },
            }
            if forceGuide then EasyFind:StartGuide(guideData) else self:DirectOpen(guideData) end
            return
        end
        if C_Heirloom and C_Heirloom.CreateHeirloom then
            C_Heirloom.CreateHeirloom(data.heirloomItemID)
        end
        return
    end



    if data.gearSetID then
        if InCombatLockdown() then return end
        if C_EquipmentSet and C_EquipmentSet.UseEquipmentSet then
            C_EquipmentSet.UseEquipmentSet(data.gearSetID)
        end
        return
    end



    if data.toyItemID then
        if forceGuide then
            EasyFind:StartGuide(self:BuildToyBoxGuideData(data))
        elseif data.isToyboxOnly or Handlers:IsSourceModifierHeld(data) then
            self:OpenToyInToyBox(data)
        end
        return
    end




    if data.category == "Talent" and (data.talentNodeID or data.talentTab) then



        if forceGuide and data.steps then
            EasyFind:StartGuide(data)
        else
            self:OpenTalentInTalentsTab(data)
        end
        return
    end

    if data.spellID then
        if (forceGuide or Handlers:IsSourceModifierHeld(data) or Icons:IsSpellbookOnlyAbility(data))
           and not data.professionAbility then



            self:OpenAbilityInSpellbook(data, forceGuide)
        end
        return
    end




    if data.petID or data.speciesID then



        if forceGuide or Handlers:IsSourceModifierHeld(data)
           or not Icons:IsPetSummonable(data) then
            local guideData = self:BuildPetJournalGuideData(data)
            if useFast then
                self:DirectOpen(guideData)
            else
                EasyFind:StartGuide(guideData)
            end
            return
        end

        if C_PetJournal then
            local guid = self:ResolvePetGUID(data)
            if guid and C_PetJournal.SummonPetByGUID then
                C_PetJournal.SummonPetByGUID(guid)
                if guid ~= data.petID then data.petID = guid end
            end
        end
        return
    end


    if ns.ResultGestures.KindOf(data) == "instance" then
        local action = ns.ResultGestures.ActionFor(data, ns.ResultGestures.Held())
        if action == "gps" then
            EasyFind.API.CallAction("gps", "navigate", data, { popout = true })
            return
        end
        if action == "bosses" then
            EasyFind.API.ShowScope("bosses", data.name)
            return
        end
        if action == "none" then return end
    end

    if data.mapSearchResult then
        if ns.MapSearch and ns.MapSearch.HandleUISearchClick then
            ns.MapSearch:HandleUISearchClick(data, forceGuide)
        end
        return
    end




    if data.itemID and data.category == "Bag" then
        if useFast then
            local actionKind = self:GetBagItemActionKind(data)
            if Handlers:IsSourceCtrlHeld(data) and actionKind == "equip"
               and data.bagItemLink and DressUpItemLink then
                if DressUpItemLink(data.bagItemLink) then return end
            end
            local showInBags = Handlers:IsSourceModifierHeld(data)







            if not showInBags and actionKind ~= "show" then
                return
            end
            self:OpenBagItemLocation(data)
            return
        end
        if not data.steps or #data.steps == 0 then return end
    end





    if data.macroIndex then
        if useFast then
            if Handlers:IsSourceModifierHeld(data) then
                Search:OpenMacroFrameAt(data.macroIndex, data.macroIsChar)
            end
            return
        end
        if data.steps then EasyFind:StartGuide(data) end
        return
    end

    if useFast and data.steps then

        local mustGuide = false
        for _, step in ipairs(data.steps) do
            if step.portraitMenu or step.portraitMenuOption then
                mustGuide = true
                break
            end
        end

        if mustGuide then
            EasyFind:StartGuide(data)
        else
            self:DirectOpen(data)
        end
    elseif data.steps then
        EasyFind:StartGuide(data)
    end
end
