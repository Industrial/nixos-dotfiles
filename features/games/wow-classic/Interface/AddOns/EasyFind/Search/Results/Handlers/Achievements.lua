local _, ns = ...

local Handlers = ns.ResultHandlers
local Openers = ns.SearchOpeners
local Utils = ns.Utils

local ClickButton = Utils.ClickButton
local slower = Utils.slower

function Handlers:ClickAchievementCategory(categoryName, categoryID)
    if not AchievementFrame or not AchievementFrame:IsShown() then
        return false
    end

    local numericCategoryID = tonumber(categoryID)
    local categoryNameLower = categoryName and slower(categoryName) or nil
    local function MatchesCategory(data)
        if not data then return false end
        local catID = data.id
        local numericCatID = tonumber(catID)
        if not numericCatID then return false end
        if numericCategoryID then return numericCatID == numericCategoryID end
        if categoryNameLower and GetCategoryInfo then
            local title = GetCategoryInfo(catID)
            if title and slower(title) == categoryNameLower then return true end
        end
        return false
    end

    local function UpdateCategories()
        if AchievementFrameCategories_UpdateDataProvider then
            AchievementFrameCategories_UpdateDataProvider()
        end
    end


    local categoriesFrame = _G["AchievementFrameCategories"]
    if categoriesFrame and categoriesFrame.ScrollBox then
        local scrollBox = categoriesFrame.ScrollBox
        if numericCategoryID and AchievementFrameCategories_ExpandToCategory then
            AchievementFrameCategories_ExpandToCategory(numericCategoryID)
            UpdateCategories()
        end
        local dataProvider = scrollBox.GetDataProvider and scrollBox:GetDataProvider()
        if dataProvider then
            local finder = dataProvider.FindElementDataByPredicate or dataProvider.FindByPredicate
            if finder then
                local elementData = finder(dataProvider, MatchesCategory)
                if elementData then
                    if elementData.hidden and elementData.id and AchievementFrameCategories_ExpandToCategory then
                        AchievementFrameCategories_ExpandToCategory(tonumber(elementData.id) or elementData.id)
                        UpdateCategories()
                        dataProvider = scrollBox.GetDataProvider and scrollBox:GetDataProvider() or dataProvider
                        finder = dataProvider and (dataProvider.FindElementDataByPredicate or dataProvider.FindByPredicate)
                        elementData = finder and finder(dataProvider, MatchesCategory)
                        if not elementData then return false end
                    end

                    if AchievementFrameCategories_SelectElementData then
                        if scrollBox.ScrollToElementData then
                            local alignCenter = ScrollBoxConstants and ScrollBoxConstants.AlignCenter
                            pcall(scrollBox.ScrollToElementData, scrollBox, elementData, alignCenter)
                        end
                        local ok = pcall(AchievementFrameCategories_SelectElementData, elementData)
                        if ok then
                            UpdateCategories()
                            return true
                        end
                    end

                    if scrollBox.ScrollToElementData then
                        pcall(scrollBox.ScrollToElementData, scrollBox, elementData)
                    end
                    local frame = scrollBox.FindFrame and scrollBox:FindFrame(elementData)
                    if frame and ClickButton(frame.Button or frame) then return true end
                end
            end
        end

        local frame = Utils.ScrollBoxFindButton(scrollBox, function(btn)
            local data = btn.GetElementData and btn:GetElementData()
            return MatchesCategory(data)
        end)
        if frame and ClickButton(frame.Button or frame) then return true end

    end

    return false
end






local function GetAchievementContentType()
    if Enum and Enum.ContentTrackingType
       and Enum.ContentTrackingType.Achievement ~= nil then
        return Enum.ContentTrackingType.Achievement
    end
    return nil
end

function Handlers:IsAchievementTracked(achievementID)
    if not achievementID then return false end
    local ct = GetAchievementContentType()
    if ct ~= nil and C_ContentTracking and C_ContentTracking.IsTracking then
        local ok, tracked = pcall(C_ContentTracking.IsTracking, ct, achievementID)
        if ok then return tracked and true or false end
    end
    local fn = _G["IsTrackedAchievement"]
    if fn then
        local ok, tracked = pcall(fn, achievementID)
        if ok then return tracked and true or false end
    end
    return false
end

function Handlers:ToggleAchievementTracked(achievementID)
    if not achievementID then return end
    local tracked = self:IsAchievementTracked(achievementID)
    local ct = GetAchievementContentType()
    if ct ~= nil and C_ContentTracking and C_ContentTracking.StartTracking then
        if tracked then



            local stopType = (Enum and Enum.ContentTrackingStopType
                              and Enum.ContentTrackingStopType.User) or 0
            pcall(C_ContentTracking.StopTracking, ct, achievementID, stopType)
        else
            pcall(C_ContentTracking.StartTracking, ct, achievementID)
        end
        return
    end
    if tracked then
        local stop = _G["RemoveTrackedAchievement"]
        if stop then pcall(stop, achievementID) end
    else
        local start = _G["AddTrackedAchievement"]
        if start then pcall(start, achievementID) end
    end
end







local scrollTargetAchievementID
local function MatchesScrollTargetAchievement(elementData)
    return type(elementData) == "table" and elementData.id == scrollTargetAchievementID
end







function Handlers:ScrollAchievementListTo(achievementID)
    local list = _G["AchievementFrameAchievements"]
    local box = list and list.ScrollBox
    if not (box and box.ScrollToElementDataByPredicate) then return false end
    scrollTargetAchievementID = achievementID
    local align = ScrollBoxConstants and ScrollBoxConstants.AlignCenter or 0.5
    local ok = pcall(box.ScrollToElementDataByPredicate, box,
        MatchesScrollTargetAchievement, align)
    return ok
end

function Handlers:OpenAchievementByID(achievementID)
    if not achievementID then return end
    if _G["AchievementFrame_LoadUI"] then
        pcall(_G["AchievementFrame_LoadUI"])
    end
    local frame = _G["AchievementFrame"]
    if frame and not frame:IsShown() and ShowUIPanel then
        Openers:SecureShowUIPanel(frame)
    end
    local opener = _G["OpenAchievementFrameToAchievement"]
    if opener then
        pcall(opener, achievementID)
        return
    end
    local selector = _G["AchievementFrame_SelectAchievement"]
    if selector then
        pcall(selector, achievementID)
        return
    end
    self:ScrollAchievementListTo(achievementID)
end






