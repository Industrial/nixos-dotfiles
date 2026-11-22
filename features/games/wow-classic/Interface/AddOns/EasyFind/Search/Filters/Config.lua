local _, ns = ...

local Search = ns.Search
local Filters = ns.Filters
local Utils = ns.Utils
local L = ns.L

local ipairs = Utils.ipairs
local tremove = Utils.tremove

local ACHIEVEMENT_FILTER_LABELS = {
    all = _G["ALL"] or "All",


    earned = ns.ACH_LABEL_EARNED,
    incomplete = ns.ACH_LABEL_INCOMPLETE,
}



local function AddonSubFilters()
    local names, seen = {}, {}
    local addonSet = Settings and Settings.CategorySet and Settings.CategorySet.AddOns
    local ok, list = pcall(function() return SettingsPanel and SettingsPanel:GetAllCategories() end)
    for _, cat in ipairs(ok and type(list) == "table" and list or {}) do
        local set = cat.categorySet
        if set == nil and cat.GetCategorySet then set = cat:GetCategorySet() end
        local name = addonSet ~= nil and set == addonSet and cat.GetName and cat:GetName()
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    for name in pairs(ns.settingsFeeds or {}) do
        if not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    table.sort(names)
    local out = {}
    for i = 1, #names do
        out[i] = { key = "addon:" .. names[i], label = names[i], dbTable = "addonOptionsFilters" }
    end
    return out
end

local UI_FILTER_OPTIONS = {


    { key = "abilities",   label = _G["ABILITIES"] or "Abilities",   iconTex = ns.ART.ability.tex,
      iconCoords = ns.ART.ability.coords,
      flyoutRadio = {
          checkboxes = {
              { dbKey = "abilityHidePassives", label = L["FILTER_HIDE_PASSIVES"],
                onChange = function(v) if Search.ApplySpellBookHidePassives then Search:ApplySpellBookHidePassives(v) end end },
              { dbKey = "hideTooltips.abilities", label = L["FILTER_HIDE_TOOLTIPS"] },
          },
      } },
    { key = "achievements", label = _G["ACHIEVEMENTS"] or "Achievements", iconAtlas = "UI-HUD-MicroMenu-Achievements-Up",
      flyoutRadio = {
          dbKey = "achievementFilterMode",
          options = {
              { value = "all",        label = ACHIEVEMENT_FILTER_LABELS.all },
              { value = "earned",     label = ACHIEVEMENT_FILTER_LABELS.earned },
              { value = "incomplete", label = ACHIEVEMENT_FILTER_LABELS.incomplete },
          },
          checkboxes = {
              { dbKey = "hideAchievementHeaders", label = L["FILTER_HIDE_ACHIEVEMENT_HEADERS"] },
              { dbKey = "hideGuildAchievements", label = L["FILTER_HIDE_GUILD_ACHIEVEMENTS"] },
          },
      } },


    { key = "characterInfo", label = _G["CHARACTER_BUTTON"] or L["FILTER_CHARACTER_INFO"],
      iconTex = ns.STAT_CATEGORY_ICON_TEX, iconCoords = ns.STAT_CATEGORY_ICON_COORDS,
      flyoutSubFilters = {
          { key = "statistics", label = _G["STATISTICS"] or "Statistics", iconTex = ns.STAT_CATEGORY_ICON_TEX,
            iconCoords = ns.STAT_CATEGORY_ICON_COORDS, hasOptions = true,


            checkboxOptions = { {
                choice = {
                    { value = "all",        label = _G["ALL"] or "All" },
                    { value = "recorded",   label = L["FILTER_STAT_RECORDED"] },
                    { value = "unrecorded", label = L["FILTER_STAT_UNRECORDED"] },
                },
                get = function() return EasyFind.db.statisticFilterMode or "all" end,


                set = function(value)
                    EasyFind.db.statisticFilterMode = value
                    Filters:RerunActiveSearch()
                end,
            } } },
          { key = "charPlayed", label = L["CHAR_PLAYED"], iconTex = "Interface\\Icons\\INV_Misc_PocketWatch_01" },
          { key = "charSeen",   label = L["CHAR_LAST_PLAYED"], iconTex = "Interface\\Icons\\INV_Misc_Book_09" },
          { key = "charGold",   label = _G["MONEY"] or "Money", iconTex = "Interface\\Icons\\INV_Misc_Coin_01" },
          { key = "charLevel",  label = _G["LEVEL"] or "Level", iconTex = ns.STAT_CATEGORY_ICON_TEX,
            iconCoords = ns.STAT_CATEGORY_ICON_COORDS },
      } },




    { key = "items",       label = _G["ITEMS"] or "Items",
      iconTex = ns.ITEMS_CATEGORY_ICON_TEX, iconCoords = ns.ITEMS_CATEGORY_ICON_COORDS,
      iconAspect = ns.ITEMS_CATEGORY_ICON_ASPECT,
      flyoutSubFilters = {
          { key = "catalog", label = L["FILTER_GENERAL_CATALOG"], iconTex = ns.ITEMS_CATEGORY_ICON_TEX, iconCoords = ns.ITEMS_CATEGORY_ICON_COORDS, iconAspect = ns.ITEMS_CATEGORY_ICON_ASPECT, hasOptions = true, companion = "EasyFind_Items" },
          { key = "bags", label = _G["BAGSLOT"] or "Bags", iconAtlas = ns.BAG_ICON_ATLAS, iconTex = ns.BAG_ICON_TEX, hasOptions = true },
          { key = "bank", label = _G["BANK"] or "Bank", iconTex = ns.BANK_CATEGORY_ICON_TEX, iconCoords = ns.BANK_CATEGORY_ICON_COORDS, hasOptions = true },
          { key = "mail", label = _G["MAIL_LABEL"] or "Mail", iconTex = "Interface\\Icons\\INV_Letter_15" },
          { key = "guildBank", label = _G["GUILD_BANK"] or "Guild Bank", iconTex = ns.BANK_CATEGORY_ICON_TEX, iconCoords = ns.BANK_CATEGORY_ICON_COORDS },
      } },

    { key = "bosses",      label = _G["RAID_BOSSES"] or "Bosses",      iconTex = ns.ART.boss.tex,
      iconCoords = ns.ART.boss.coords,
      flyoutRadio = {
          checkboxes = {
              { dbKey = "bossFilterDungeon", label = _G["LFG_TYPE_DUNGEON"] or "Dungeon" },
              { dbKey = "bossFilterRaid", label = _G["RAID"] or "Raid" },
          },
      } },
    { key = "macros",      label = _G["MACROS"] or "Macros",      iconTex = "Interface\\MacroFrame\\MacroFrame-Icon",
      flyoutRadio = {
          checkboxes = {
              { dbKey = "macroFilterGeneral", label = _G["GENERAL"] or "General" },
              { dbKey = "macroFilterChar", label = _G["CHARACTER"] or "Character" },
              { dbKey = "hideTooltips.macros", label = L["FILTER_HIDE_TOOLTIPS"] },
          },
      } },
    { key = "collections",  label = _G["COLLECTIONS"] or "Collections",  iconAtlas = "UI-HUD-MicroMenu-Collections-Up",
      flyoutSubFilters = {
          { key = "appearances", label = _G["WARDROBE"] or "Appearances", iconTex = "Interface\\Icons\\INV_Helmet_03", hasOptions = true },
          { key = "heirlooms",      label = _G["HEIRLOOMS"] or "Heirlooms",       iconTex = 133877, hasOptions = true },
          { key = "mounts",         label = _G["MOUNTS"] or "Mounts",          iconTex = 132261, hasOptions = true },
          { key = "outfits",        label = L["FILTER_OUTFITS"],         iconTex = 132649 },
          { key = "pets",           label = _G["PETS"] or "Pets",            iconTex = 631719, hasOptions = true },
          { key = "toys",           label = _G["TOYS"] or _G["TOY_BOX"] or "Toys",            iconTex = 454046, hasOptions = true },
      } },





    { key = "gearSets",    label = _G["EQUIPMENT_MANAGER"] or "Gear Sets",   iconTex = ns.ART.gear_set.tex,
      iconCoords = ns.ART.gear_set.coords,
      flyoutRadio = {
          dbKey = "gearSetSpecFilter",
          options = function()
              local opts = { { value = "all", label = _G["ALL_SPECS"] or "All Specializations" } }

              local numSpecs = (GetNumSpecializations and GetSpecializationInfo) and GetNumSpecializations() or 0
              for i = 1, numSpecs do
                  local _, specName = GetSpecializationInfo(i)
                  if specName then
                      opts[#opts + 1] = { value = i, label = specName }
                  end
              end
              return opts
          end,


          onChange = function() Filters:ApplyFilterSelection("gearSets") end,
      } },
    { key = "currencies",  label = _G["CURRENCY"] or "Currencies",  iconTex = 136452,
      flyoutRadio = {
          dbKey = "currencyFilterMode",
          options = {
              { value = "warband", label = CURRENCY_FILTER_TYPE_TRANSFERABLE or "All Warband Transferable" },
              { value = "all",     label = (CURRENCY_FILTER_TYPE_CHARACTER and ns.PlayerName()
                                           and CURRENCY_FILTER_TYPE_CHARACTER:format(ns.PlayerName()))
                                          or ((ns.PlayerName() or "This Character") .. " Only") },
          },
          onChange = function(v) if Search.ApplyTokenFrameFilter then Search:ApplyTokenFrameFilter(v) end end,
          checkboxes = {
              { dbKey = "hideTooltips.currencies", label = L["FILTER_HIDE_TOOLTIPS"] },
          },
      } },





    { key = "loot",        label = _G["LOOT"] or "Loot",        iconTex = ns.ART.loot.tex,
      iconCoords = ns.ART.loot.coords, hasFlyout = true },
    { key = "map",         label = L["FILTER_MAP_SEARCH"],  iconTex = ns.MAP_CATEGORY_ICON_TEX,
      iconCoords = ns.MAP_CATEGORY_ICON_COORDS,
      flyoutSubFilters = {
          { key = "zones",      label = _G["ZONES"] or "Zones",        dbTable = "uiMapFilters" },
          { key = "instances",  label = L["FILTER_INSTANCES"],    dbTable = "uiMapFilters",
            subFilters = {
                { key = "raid",    label = _G["RAIDS"] or "Raids",         dbTable = "uiMapFilters" },
                { key = "dungeon", label = _G["DUNGEONS"] or "Dungeons",   dbTable = "uiMapFilters" },
                { key = "delve",   label = _G["DELVES_LABEL"] or "Delves", dbTable = "uiMapFilters" },
            } },
          { key = "travel",     label = L["FILTER_TRAVEL"],       dbTable = "uiMapFilters",
            subFilters = {
                { key = "flights", label = L["MAP_FILTER_FLIGHTS"], dbTable = "uiMapFilters" },
                { key = "boats",   label = L["MAP_FILTER_BOATS"],   dbTable = "uiMapFilters" },
                { key = "portals", label = L["MAP_FILTER_PORTALS"], dbTable = "uiMapFilters" },
            } },
          { key = "services",   label = L["FILTER_SERVICES"],     dbTable = "uiMapFilters",
            subFilters = {
                { key = "banks",      label = L["MAP_FILTER_BANKS"],      dbTable = "uiMapFilters" },
                { key = "auction",    label = L["MAP_FILTER_AUCTION"],    dbTable = "uiMapFilters" },
                { key = "inns",       label = L["MAP_FILTER_INNS"],       dbTable = "uiMapFilters" },
                { key = "mail",       label = L["MAP_FILTER_MAIL"],       dbTable = "uiMapFilters" },
                { key = "trainers",   label = L["MAP_FILTER_TRAINERS"],   dbTable = "uiMapFilters" },
                { key = "vendors",    label = L["MAP_FILTER_VENDORS"],    dbTable = "uiMapFilters" },
                { key = "appearance", label = L["MAP_FILTER_APPEARANCE"], dbTable = "uiMapFilters" },
                { key = "otherservices", label = L["MAP_FILTER_OTHER_SERVICES"], dbTable = "uiMapFilters" },
            } },
          { key = "rares",      label = L["FILTER_RARES"],        dbTable = "uiMapFilters" },
          { key = "npcs",       label = L["FILTER_NPCS"],         dbTable = "uiMapFilters", hasOptions = true },
      } },
    { key = "holidays",    label = _G["CALENDAR_FILTER_HOLIDAYS"] or L["FILTER_HOLIDAYS"], iconTex = 134939 },
    { key = "housing",     label = _G["HOUSING_SETTINGS_LABEL"] or _G["BINDING_HEADER_HOUSING_SYSTEM"] or "Housing",
      iconAtlas = "UI-HUD-MicroMenu-Housing-Up", hasFlyout = true },

    { key = "options",     label = _G["OPTIONS"] or "Options",     iconTex = ns.OPTIONS_CATEGORY_ICON_TEX,
      flyoutSubFilters = {
          { key = "gameOptions",  label = L["FILTER_GAME_OPTIONS"],  iconAtlas = ns.SETTING_ICON.atlas, iconTex = ns.SETTING_ICON.tex,
            iconDesaturate = ns.SETTING_ICON.desaturate, companion = "EasyFind_Settings" },
          { key = "addonOptions", label = L["FILTER_ADDON_OPTIONS"], iconAtlas = ns.SETTING_ICON.atlas, iconTex = ns.SETTING_ICON.tex,
            iconColor = { 1.0, 0.78, 0.35 }, companion = "EasyFind_Settings", subFilters = AddonSubFilters },

          { key = "addons", label = _G["ADDONS"] or "AddOns", iconTex = ns.EXTENSIONS_ICON_TEX },
      } },
    { key = "professions", label = _G["TRADE_SKILLS"] or "Professions",
      iconAtlas = "UI-HUD-MicroMenu-Professions-Up", hasFlyout = true,
      available = function()

          if ns.Caps and ns.Caps.classic then
              local known = ns.KnownProfessions
              return known ~= nil and #known() > 0
          end
          if not GetProfessions then return false end
          local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
          return (prof1 or prof2 or archaeology or fishing or cooking) ~= nil
      end },


    { key = "skills",      label = _G["SKILLS"] or "Skills",       iconTex = 133741, hasFlyout = true,
      flyoutDbTable = "skillFilters",
      flyoutList = function() return ns.Database and ns.Database.SkillHeadings and ns.Database.SkillHeadings() end },
    { key = "reputations", label = _G["REPUTATION"] or "Reputations", iconTex = ns.PlayerRepCategoryIcon().tex,
      iconCoords = ns.PlayerRepCategoryIcon().coords,
      flyoutRadio = {
          dbKey = "reputationFilterMode",
          options = {
              { value = "all",     label = _G["ALL"] or "All" },
              { value = "warband", label = _G["REPUTATION_SORT_TYPE_ACCOUNT"] or "Warband", caps = "warbandRep" },
              { value = "char",    label = ns.PlayerName() or "This Character" },
          },
          onChange = function(v) if Search.ApplyReputationFilter then Search:ApplyReputationFilter(v) end end,
          checkboxes = {
              { dbKey = "showLegacyReputations", label = L["FILTER_SHOW_LEGACY_REPUTATIONS"], caps = "warbandRep",
                onChange = function(v) if Search.ApplyReputationShowLegacy then Search:ApplyReputationShowLegacy(v) end end },
          },
      } },

    { key = "social",      label = _G["SOCIAL_LABEL"] or "Social", iconTex = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon",
      flyoutSubFilters = {
          { key = "friends",      label = _G["FRIENDS"] or "Friends", iconTex = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon" },
          { key = "guildMembers", label = _G["GUILD"] or "Guild",     iconTex = "Interface\\GossipFrame\\TabardGossipIcon" },
      } },


    { key = "talents",     label = _G["TALENTS"] or "Talents",     iconAtlas = "UI-HUD-MicroMenu-SpecTalents-Up",
      flyoutRadio = {
          checkboxes = {
              { dbKey = "talentShowSpecs", label = _G["SPECIALIZATION"] or "Specialization", caps = "specs" },
              { dbKey = "talentShowLoadouts", label = L["FILTER_LOADOUTS"], caps = "specs" },
              { dbKey = "hideTooltips.talents", label = L["FILTER_HIDE_TOOLTIPS"] },
          },
      } },


    { key = "extensions",  label = L["FILTER_EXTENSIONS"], iconTex = ns.EXTENSIONS_ICON_TEX,
      flyoutSubFilters = {} },





    { key = "titles",      label = _G["PAPERDOLL_SIDEBAR_TITLES"] or "Titles",      iconTex = ns.ART.title.tex,
      iconCoords = ns.ART.title.coords,
      flyoutRadio = {
          dbKey = "titleFilterMode",
          options = {
              { value = "earned",     label = ACHIEVEMENT_FILTER_LABELS.earned },

              { value = "incomplete", label = ACHIEVEMENT_FILTER_LABELS.incomplete, caps = "achievements" },
              { value = "all",        label = ACHIEVEMENT_FILTER_LABELS.all, caps = "achievements" },
          },
          onChange = function() Filters:ApplyFilterSelection("titles") end,
      } },
    { key = "commands",    label = L["FILTER_COMMANDS"], iconTex = ns.COMMANDS_ICON_TEX,
      flyoutRadio = {
          checkboxes = {
              { dbKey = "commandShowNative", label = _G["DEFAULT"] or "Default" },
              { dbKey = "commandShowCustom", label = L["FILTER_EXTRA"] },
          },
      } },
}



table.sort(UI_FILTER_OPTIONS, function(a, b)
    return (a.label or ""):lower() < (b.label or ""):lower()
end)



local function ForEachFilterKey(callback)
    for _, opt in ipairs(UI_FILTER_OPTIONS) do
        callback(opt.key, opt)
        if opt.flyoutSubFilters then
            for _, sub in ipairs(opt.flyoutSubFilters) do
                callback(sub.key, sub)
                if type(sub.subFilters) == "table" then
                    for _, child in ipairs(sub.subFilters) do
                        callback(child.key, child)
                    end
                end
            end
        end
    end
end






local UI_BUCKET_BY_CATEGORY = ns.CategoryMap.BucketByCategory

local function GetUIBucket(d)



    if not d then return nil end

    local category = d.category
    local bucket = UI_BUCKET_BY_CATEGORY[category]
    if not bucket then return nil end
    if d.mountID or d.toyItemID or d.petID or d.outfitID or d.heirloomItemID
       or d.transmogSetID
       or (d.itemID and category == "Loot") or d.mapSearchResult then
        return nil
    end
    return bucket
end

function Filters:IsGuildAchievementData(data)
    return data and data.isGuildAchievement == true
end








function Filters.IsMouseInFilterChain()
    local searchFrame = Search.GetSearchFrame and Search:GetSearchFrame()
    local dropdown = searchFrame and searchFrame.filterDropdown
    if not dropdown then return false end
    if Utils.IsFrameVisiblyMouseOver(dropdown) then return true end
    if Utils.IsFrameVisiblyMouseOver(searchFrame.filterBtn) then return true end
    local guards = dropdown.guardFrames
    if guards then
        for i = 1, #guards do
            if Utils.IsFrameVisiblyMouseOver(guards[i]) then return true end
        end
    end
    return false
end









local openPopupStack = {}

local function RemoveFromPopupStack(popup)
    for i = #openPopupStack, 1, -1 do
        if openPopupStack[i] == popup then
            tremove(openPopupStack, i)
            return
        end
    end
end

function Filters.AttachOutsideClickClose(popup, opts)
    local onHide = opts and opts.onHide
    popup:HookScript("OnShow", function(self)
        self:RegisterEvent("GLOBAL_MOUSE_DOWN")
        RemoveFromPopupStack(self)
        openPopupStack[#openPopupStack + 1] = self
    end)
    popup:HookScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        RemoveFromPopupStack(self)
        if onHide then onHide(self) end
    end)
    popup:HookScript("OnEvent", function(self, event)
        if event ~= "GLOBAL_MOUSE_DOWN" then return end
        if not Filters.IsMouseInFilterChain() then self:Hide() end
    end)
end






function Filters.CloseTopFilterLayer()
    if Utils.HideCursorMenus and Utils.HideCursorMenus() then return true end
    for i = #openPopupStack, 1, -1 do
        local popup = openPopupStack[i]
        if popup and popup:IsShown() then
            popup:Hide()
            return true
        end
        tremove(openPopupStack, i)
    end
    local searchFrame = Search.GetSearchFrame and Search:GetSearchFrame()
    local dropdown = searchFrame and searchFrame.filterDropdown
    if dropdown and dropdown:IsShown() then
        if ns.Results and ns.Results.CloseFilterDropdownIfOpen then
            ns.Results:CloseFilterDropdownIfOpen()
        else
            dropdown:Hide()
        end
        return true
    end
    return false
end





function Filters.ResyncShownOptionPopups()
    local searchFrame = Search.GetSearchFrame and Search:GetSearchFrame()
    local dropdown = searchFrame and searchFrame.filterDropdown
    local guards = dropdown and dropdown.guardFrames
    if not guards then return end
    for i = 1, #guards do
        local guard = guards[i]
        if guard._efSync and guard:IsShown() then guard._efSync() end
    end
end






local mapFilterLabels
function Filters.MapCategoryFilterLabel(category)
    if not category then return nil end
    if not mapFilterLabels then
        mapFilterLabels = {}
        for _, opt in ipairs(UI_FILTER_OPTIONS) do
            if opt.key == "map" and opt.flyoutSubFilters then
                for _, sub in ipairs(opt.flyoutSubFilters) do
                    mapFilterLabels[sub.key] = sub.label
                    if type(sub.subFilters) == "table" then
                        for _, nested in ipairs(sub.subFilters) do
                            mapFilterLabels[nested.key] = nested.label
                        end
                    end
                end
            end
        end
    end
    local probe = { category = category }
    local bucket = ns.MapSearch and ns.MapSearch.GetFilterBucket
        and ns.MapSearch.GetFilterBucket(probe)
    local sub = ns.MapSearch and ns.MapSearch.GetSubBucket
        and ns.MapSearch.GetSubBucket(probe, bucket)
    return (sub and mapFilterLabels[sub]) or (bucket and mapFilterLabels[bucket]) or nil
end






for i = #UI_FILTER_OPTIONS, 1, -1 do
    local opt = UI_FILTER_OPTIONS[i]
    if opt.companion and ns.IsCompanionLoadable
       and not ns.IsCompanionLoadable(opt.companion) then

        tremove(UI_FILTER_OPTIONS, i)
    else
        local subs = opt.flyoutSubFilters
        if subs then
            for si = #subs, 1, -1 do
                if subs[si].companion and ns.IsCompanionLoadable
                   and not ns.IsCompanionLoadable(subs[si].companion) then
                    tremove(subs, si)
                end
            end
        end
    end
end


if ns.Caps and ns.Caps.PruneRows then ns.Caps.PruneRows(UI_FILTER_OPTIONS) end





for _, opt in ipairs(UI_FILTER_OPTIONS) do
    if opt.key == "map" and opt.flyoutSubFilters then
        local leaves = {}
        for _, sub in ipairs(opt.flyoutSubFilters) do
            if sub.key ~= "zones" then
                for _, leaf in ipairs(type(sub.subFilters) == "table" and sub.subFilters or { sub }) do
                    leaves[#leaves + 1] = { key = leaf.key, label = leaf.label, dbTable = "mapZoneOnly", scope = true }
                end
            end
        end
        opt.flyoutSubFilters[#opt.flyoutSubFilters + 1] = {
            key = "all", label = L["FILTER_MAP_SCOPE_LOCAL"], dbTable = "mapZoneOnly", scope = true,
            tooltip = L["FILTER_MAP_SCOPE_LOCAL_TT"], subFilters = leaves,
        }
    end
end

Filters.UI_FILTER_OPTIONS = UI_FILTER_OPTIONS



function Filters.AddExtensionFilter(sub)
    for _, opt in ipairs(UI_FILTER_OPTIONS) do
        if opt.key == "extensions" then
            for _, s in ipairs(opt.flyoutSubFilters) do
                if s.key == sub.key then return end
            end
            opt.flyoutSubFilters[#opt.flyoutSubFilters + 1] = sub
            return
        end
    end
end
Filters.ForEachFilterKey = ForEachFilterKey
Filters.GetUIBucket = GetUIBucket
