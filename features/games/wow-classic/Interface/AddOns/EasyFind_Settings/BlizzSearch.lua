


local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns then return end


if ns.BUILD ~= "5.5.0" then select(2, ...).stale = true return end

local BlizzOptionsSearch = {}
ns.BlizzOptionsSearch = BlizzOptionsSearch

local Utils = ns.Utils
local Loc = ns.L
local SearchFocus = ns.SearchFocus
local tinsert = Utils.tinsert
local slower = Utils.slower
local SafeAfter = Utils.SafeAfter






local function SearchLower(s)
    if type(s) ~= "string" then return s end
    local clean = Utils.StripMarkup and Utils.StripMarkup(s) or s
    return slower(clean ~= "" and clean or s)
end
BlizzOptionsSearch.SearchLower = SearchLower
local pcall = pcall
local coroutine = coroutine
local setmetatable = setmetatable
local tconcat = table.concat



local ownRuns = setmetatable({}, { __mode = "k" })

local optionsPopulateUrgent = false
local function MaybeYieldLiveSettings()
    local co = coroutine.running()
    if co and ownRuns[co] then Utils.SliceCheckpoint() end
end

local SecureCall = Utils.SecureCall







local settingsCatMTCache = {}
local function GetSettingsCatMT(category, catName, catID, pathArr)
    local pathKey = pathArr and tconcat(pathArr, "\31") or ""
    local key = category .. "\31" .. (catName or "") .. "\31" .. pathKey
    local cached = settingsCatMTCache[key]
    if cached then return cached end
    local proto = {
        category          = category,
        path              = pathArr,
        settingsCategory  = catName,
        settingCategoryID = catID,
    }
    local mt = { __index = proto }
    settingsCatMTCache[key] = mt
    return mt
end




local function GetSettingsCategoryList()
    if SettingsPanel and SettingsPanel.GetAllCategories then
        local ok, list = pcall(SettingsPanel.GetAllCategories, SettingsPanel)
        if ok and type(list) == "table" then return list end
    end
    if Settings and Settings.GetCategoryList then
        local ok, list = pcall(Settings.GetCategoryList)
        if ok and type(list) == "table" then return list end
    end
    return nil
end
local function HasSettingsCategoryAccess()
    return (SettingsPanel and SettingsPanel.GetAllCategories) ~= nil
        or (Settings and Settings.GetCategoryList) ~= nil
end










local function PlusOneFormatter(v) return tostring((tonumber(v) or 0) + 1) end
local QUALITY_SLIDER_OVERRIDES = {
    PROXY_GRAPHICS_QUALITY        = { min = 0, max = 9, step = 1, formatter = PlusOneFormatter },
    PROXY_RAID_GRAPHICS_QUALITY   = { min = 0, max = 9, step = 1, formatter = PlusOneFormatter },
    PROXY_VIEW_DISTANCE           = { min = 0, max = 9, step = 1, formatter = PlusOneFormatter },
    PROXY_RAID_VIEW_DISTANCE      = { min = 0, max = 9, step = 1, formatter = PlusOneFormatter },
    PROXY_ENVIRONMENT_DETAIL      = { min = 0, max = 9, step = 1, formatter = PlusOneFormatter },
    PROXY_RAID_ENVIRONMENT_DETAIL = { min = 0, max = 9, step = 1, formatter = PlusOneFormatter },
    PROXY_GROUND_CLUTTER          = { min = 0, max = 9, step = 1, formatter = PlusOneFormatter },
    PROXY_RAID_GROUND_CLUTTER     = { min = 0, max = 9, step = 1, formatter = PlusOneFormatter },
}
local BASE_QUALITY_SETTINGS = {
    PROXY_SHADOW_QUALITY          = true,
    PROXY_RAID_SHADOW_QUALITY     = true,
    PROXY_LIQUID_DETAIL           = true,
    PROXY_RAID_LIQUID_DETAIL      = true,
    PROXY_PARTICLE_DENSITY        = true,
    PROXY_RAID_PARTICLE_DENSITY   = true,
    PROXY_SSAO                    = true,
    PROXY_RAID_SSAO               = true,
    PROXY_DEPTH_EFFECTS           = true,
    PROXY_RAID_DEPTH_EFFECTS      = true,
    PROXY_COMPUTE_EFFECTS         = true,
    PROXY_RAID_COMPUTE_EFFECTS    = true,
    PROXY_OUTLINE_MODE            = true,
    PROXY_RAID_OUTLINE_MODE       = true,
    PROXY_TEXTURE_RESOLUTION      = true,
    PROXY_RAID_TEXTURE_RESOLUTION = true,
    PROXY_SPELL_DENSITY           = true,
    PROXY_RAID_SPELL_DENSITY      = true,
    PROXY_PROJECTED_TEXTURES      = true,
    PROXY_RAID_PROJECTED_TEXTURES = true,
}
for variable in pairs(QUALITY_SLIDER_OVERRIDES) do
    BASE_QUALITY_SETTINGS[variable] = true
end







local SETTINGS_DATA = {

    {"deselectOnClick","Controls","c"},
    {"autoDismountFlying","Controls","c"},
    {"autoClearAFK","Controls","c"},
    {"interactOnLeftClick","Controls","c"},
    {"lootUnderMouse","Controls","c"},
    {"autoLootDefault","Controls","c"},
    {"AUTOLOOTTOGGLE","Controls","d"},
    {"PROXY_ENABLE_INTERACT","Controls","c"},
    {"softTargettingInteractKeySound","Controls","c"},
    {"ClipCursor","Controls","c"},
    {"mouseInvertPitch","Controls","c"},
    {"PROXY_MOUSE_LOOK_SPEED","Controls","s",90,270,18},
    {"cameraWaterCollision","Controls","c"},
    {"PROXY_CAMERA_SPEED","Controls","s",90,270,18},
    {"cameraSmoothStyle","Controls","d"},
    {"cameraDistanceMaxZoomFactor","Controls","s",1,2,0.1},
    {"cameraTerrainTilt","Controls","c"},
    {"cameraBobbing","Controls","c"},
    {"cameraPivot","Controls","c"},

    {"UnitNameOwn","Interface","c"},
    {"PROXY_NPC_NAMES","Interface","d"},
    {"UnitNameNonCombatCreatureName","Interface","c"},
    {"UnitNameFriendlyPlayerName","Interface","c"},
    {"UnitNameFriendlyMinionName","Interface","c"},
    {"UnitNameEnemyPlayerName","Interface","c"},
    {"UnitNameEnemyMinionName","Interface","c"},
    {"nameplateShowAll","Interface","c"},
    {"nameplateShowEnemies","Interface","c"},
    {"nameplateShowEnemyMinions","Interface","c"},
    {"nameplateShowEnemyMinus","Interface","c"},
    {"nameplateShowFriends","Interface","c"},
    {"nameplateShowFriendlyMinions","Interface","c"},
    {"nameplateMotion","Interface","d"},
    {"nameplateMaxDistance","Interface","s",20,41,1},
    {"nameplateShowCastBars","Interface","c"},
    {"showTutorials","Interface","c"},
    {"PROXY_STATUS_TEXT","Interface","d"},
    {"PROXY_CHAT_BUBBLES","Interface","d"},
    {"PROXY_SHOW_HELM","Interface","c"},
    {"PROXY_SHOW_CLOAK","Interface","c"},
    {"instantQuestText","Interface","c"},
    {"autoQuestWatch","Interface","c"},
    {"displayFreeBagSlots","Interface","c"},
    {"consolidateBuffs","Interface","c"},
    {"hideOutdoorWorldState","Interface","c"},
    {"showMinimapClock","Interface","c"},
    {"showNewbieTips","Interface","c"},
    {"showLoadingScreenTips","Interface","c"},
    {"showTargetCastbar","Interface","c"},
    {"showDynamicBuffSize","Interface","c"},
    {"unitFramesDisplayIncomingHeals","Interface","c"},
    {"useClassicGuildUI","Interface","c"},
    {"raidFramesDisplayPowerBars","Interface","c"},
    {"raidFramesDisplayOnlyHealerPowerBars","Interface","c"},
    {"raidFramesDisplayClassColor","Interface","c"},
    {"raidOptionDisplayPets","Interface","c"},
    {"raidOptionDisplayMainTankAndAssist","Interface","c"},
    {"raidFramesDisplayDebuffs","Interface","c"},
    {"raidFramesDisplayOnlyDispellableDebuffs","Interface","c"},
    {"raidFramesHealthText","Interface","d"},

    {"PROXY_SHOW_ACTIONBAR_2","Action Bars","c"},
    {"PROXY_SHOW_ACTIONBAR_3","Action Bars","c"},
    {"PROXY_SHOW_ACTIONBAR_4","Action Bars","c"},
    {"PROXY_SHOW_ACTIONBAR_5","Action Bars","c"},
    {"PROXY_SHOW_ACTIONBAR_6","Action Bars","c"},
    {"PROXY_SHOW_ACTIONBAR_7","Action Bars","c"},
    {"PROXY_SHOW_ACTIONBAR_8","Action Bars","c"},
    {"countdownForCooldowns","Action Bars","c"},

    {"PROXY_SELF_HIGHLIGHT","Combat","d"},
    {"showTargetOfTarget","Combat","c"},
    {"doNotFlashLowHealthWarning","Combat","c"},
    {"lossOfControl","Combat","c"},
    {"enableFloatingCombatText","Combat","c"},
    {"floatingCombatTextFloatMode","Combat","d"},
    {"floatingCombatTextLowManaHealth","Combat","c"},
    {"floatingCombatTextAuras","Combat","c"},
    {"floatingCombatTextAuraFade","Combat","c"},
    {"floatingCombatTextCombatState","Combat","c"},
    {"floatingCombatTextDodgeParryMiss","Combat","c"},
    {"floatingCombatTextDamageReduction","Combat","c"},
    {"floatingCombatTextRepChanges","Combat","c"},
    {"floatingCombatTextReactives","Combat","c"},
    {"floatingCombatTextFriendlyHealers","Combat","c"},
    {"floatingCombatTextComboPoints","Combat","c"},
    {"floatingCombatTextEnergyGains","Combat","c"},
    {"floatingCombatTextHonorGains","Combat","c"},
    {"PROXY_SELF_CAST","Combat","d"},
    {"SELFCAST","Combat","d"},
    {"FOCUSCAST","Combat","d"},
    {"PROXY_ACTION_TARGETING","Combat","c"},
    {"floatingCombatTextCombatDamage","Combat","c"},
    {"floatingCombatTextCombatLogPeriodicSpells","Combat","c"},
    {"floatingCombatTextPetMeleeDamage","Combat","c"},
    {"floatingCombatTextCombatHealing","Combat","c"},
    {"autoRangedCombat","Combat","c"},

    {"PROXY_DISABLE_CHAT","Social","c"},
    {"profanityFilter","Social","c"},
    {"guildMemberNotify","Social","c"},
    {"blockTrades","Social","c"},
    {"PROXY_BLOCK_GUILD_INVITES","Social","c"},
    {"restrictCalendarInvites","Social","c"},
    {"blockChannelInvites","Social","c"},
    {"showToastOnline","Social","c"},
    {"showToastOffline","Social","c"},
    {"showToastBroadcast","Social","c"},
    {"showToastFriendRequest","Social","c"},
    {"showToastWindow","Social","c"},
    {"chatStyle","Social","d"},
    {"whisperMode","Social","d"},
    {"showTimestamps","Social","d"},

    {"PROXY_CHARACTER_SPECIFIC_BINDINGS","Keybindings","c"},

    {"enableMovePad","General","c"},
    {"PROXY_MINIMUM_CHARACTER_NAME_SIZE","General","s",0,64,2},
    {"PROXY_SICKNESS","General","c"},
    {"PROXY_SICKNESS_SHAKE","General","d"},
    {"cursorSizePreferred","General","d"},
    {"PROXY_TARGET_TOOLTIP","General","c"},
    {"PROXY_INTERACT_ICONS","General","d"},

    {"colorblindMode","Colorblind Mode","c"},
    {"colorblindSimulator","Colorblind Mode","d"},
    {"colorblindWeaknessFactor","Colorblind Mode","s",0,1,0.05},

    {"movieSubtitle","Subtitles","c"},
    {"PROXY_MOVIE_SUBTITLE_BACKGROUND","Subtitles","d"},

    {"PROXY_PRIMARY_MONITOR","Graphics","d"},
    {"PROXY_DISPLAY_MODE","Graphics","d"},
    {"PROXY_RESOLUTION","Graphics","d"},
    {"PROXY_RESOLUTION_RENDER_SCALE","Graphics","s",0.333,2,0.05},
    {"PROXY_GRAPHICS_QUALITY","Graphics","s",0,9,1},
    {"PROXY_RAID_GRAPHICS_QUALITY","Graphics","s",0,9,1," (" .. (_G["RAID"] or "Raid") .. ")"},
    {"PROXY_VIEW_DISTANCE","Graphics","s",0,9,1},
    {"PROXY_RAID_VIEW_DISTANCE","Graphics","s",0,9,1," (" .. (_G["RAID"] or "Raid") .. ")"},
    {"PROXY_ENVIRONMENT_DETAIL","Graphics","s",0,9,1},
    {"PROXY_RAID_ENVIRONMENT_DETAIL","Graphics","s",0,9,1," (" .. (_G["RAID"] or "Raid") .. ")"},
    {"PROXY_GROUND_CLUTTER","Graphics","s",0,9,1},
    {"PROXY_RAID_GROUND_CLUTTER","Graphics","s",0,9,1," (" .. (_G["RAID"] or "Raid") .. ")"},
    {"PROXY_SHADOW_QUALITY","Graphics","o"},
    {"PROXY_RAID_SHADOW_QUALITY","Graphics","o",nil,nil,nil," (" .. (_G["RAID"] or "Raid") .. ")"},
    {"PROXY_LIQUID_DETAIL","Graphics","o"},
    {"PROXY_RAID_LIQUID_DETAIL","Graphics","o",nil,nil,nil," (" .. (_G["RAID"] or "Raid") .. ")"},
    {"PROXY_PARTICLE_DENSITY","Graphics","o"},
    {"PROXY_RAID_PARTICLE_DENSITY","Graphics","o",nil,nil,nil," (" .. (_G["RAID"] or "Raid") .. ")"},
    {"PROXY_SSAO","Graphics","o"},
    {"PROXY_RAID_SSAO","Graphics","o",nil,nil,nil," (" .. (_G["RAID"] or "Raid") .. ")"},
    {"PROXY_DEPTH_EFFECTS","Graphics","o"},
    {"PROXY_RAID_DEPTH_EFFECTS","Graphics","o",nil,nil,nil," (" .. (_G["RAID"] or "Raid") .. ")"},
    {"PROXY_COMPUTE_EFFECTS","Graphics","o"},
    {"PROXY_RAID_COMPUTE_EFFECTS","Graphics","o",nil,nil,nil," (" .. (_G["RAID"] or "Raid") .. ")"},
    {"PROXY_OUTLINE_MODE","Graphics","o"},
    {"PROXY_RAID_OUTLINE_MODE","Graphics","o",nil,nil,nil," (" .. (_G["RAID"] or "Raid") .. ")"},
    {"PROXY_TEXTURE_RESOLUTION","Graphics","o"},
    {"PROXY_RAID_TEXTURE_RESOLUTION","Graphics","o",nil,nil,nil," (" .. (_G["RAID"] or "Raid") .. ")"},
    {"PROXY_SPELL_DENSITY","Graphics","o"},
    {"PROXY_RAID_SPELL_DENSITY","Graphics","o",nil,nil,nil," (" .. (_G["RAID"] or "Raid") .. ")"},
    {"PROXY_PROJECTED_TEXTURES","Graphics","o"},
    {"PROXY_RAID_PROJECTED_TEXTURES","Graphics","o",nil,nil,nil," (" .. (_G["RAID"] or "Raid") .. ")"},
    {"PROXY_VERTICAL_SYNC","Graphics","d"},
    {"LowLatencyMode","Graphics","d"},
    {"PROXY_ANTIALIASING","Graphics","d"},
    {"PROXY_FXAA","Graphics","d"},
    {"PROXY_MSAA","Graphics","d"},
    {"PROXY_MSAA_ALPHA","Graphics","c"},
    {"PROXY_CAMERA_FOV","Graphics","s"},
    {"PROXY_TRIPLE_BUFFERING","Graphics","c"},
    {"textureFilteringMode","Graphics","d"},
    {"shadowrt","Graphics","d"},
    {"ResampleQuality","Graphics","d"},
    {"vrsValar","Graphics","d"},
    {"PROXY_GRAPHICS_API","Graphics","d"},
    {"PROXY_RESAMPLE_SHARPNESS","Graphics","s"},
    {"Contrast","Graphics","s"},
    {"Brightness","Graphics","s"},
    {"Gamma","Graphics","s"},
    {"PROXY_OPT_GPU_FEATURES","Graphics","c"},
    {"PROXY_DEVICE_MT","Graphics","c"},
    {"PROXY_CMDLIST_MT","Graphics","c"},
    {"PROXY_ADV_WORK_SUBMIT","Graphics","c"},

    {"Sound_EnableAllSound","Audio","c"},
    {"Sound_MasterVolume","Audio","s"},
    {"Sound_MusicVolume","Audio","s"},
    {"Sound_SFXVolume","Audio","s"},
    {"Sound_AmbienceVolume","Audio","s"},
    {"Sound_DialogVolume","Audio","s"},
    {"Sound_EnableMusic","Audio","c"},
    {"Sound_ZoneMusicNoDelay","Audio","c"},
    {"Sound_EnablePetBattleMusic","Audio","c"},
    {"Sound_EnableSFX","Audio","c"},
    {"Sound_EnablePetSounds","Audio","c"},
    {"Sound_EnableEmoteSounds","Audio","c"},
    {"Sound_EnableDialog","Audio","c"},
    {"Sound_EnableErrorSpeech","Audio","c"},
    {"Sound_EnableAmbience","Audio","c"},
    {"Sound_EnableSoundWhenGameIsInBG","Audio","c"},
    {"Sound_EnableReverb","Audio","c"},
    {"Sound_EnablePositionalLowPassFilter","Audio","c"},

    {"disableServerNagle","Network","c"},
    {"useIPv6","Network","c"},
    {"advancedCombatLogging","Network","c"},
}

local TYPE_MAP = { c = "checkbox", d = "dropdown", s = "slider" }




local NONE_LABEL = _G["NONE"] or "None"
local ALT_KEY_LABEL = _G["ALT_KEY"] or "ALT key"
local CTRL_KEY_LABEL = _G["CTRL_KEY"] or "CTRL key"
local SHIFT_KEY_LABEL = _G["SHIFT_KEY"] or "SHIFT key"
local ALL_LABEL = _G["ALL"] or "All"
local CVAR_DROPDOWN_OPTIONS = {
    AUTOLOOTTOGGLE = {
        { value = "NONE",  label = NONE_LABEL },
        { value = "ALT",   label = ALT_KEY_LABEL },
        { value = "CTRL",  label = CTRL_KEY_LABEL },
        { value = "SHIFT", label = SHIFT_KEY_LABEL },
    },
    PROXY_NPC_NAMES = {
        { value = "1", label = _G["NPC_NAMES_DROPDOWN_TRACKED"] or "Quest NPCs" },
        { value = "2", label = _G["NPC_NAMES_DROPDOWN_HOSTILE"] or "Hostile and Quest NPCs" },
        { value = "3", label = _G["NPC_NAMES_DROPDOWN_INTERACTIVE"] or "Hostile, Quest, and Interactive NPCs" },
        { value = "4", label = _G["NPC_NAMES_DROPDOWN_ALL"] or "All NPCs" },
        { value = "5", label = _G["NPC_NAMES_DROPDOWN_NONE"] or NONE_LABEL },
    },
    nameplateMotion = {
        { value = "0", label = _G["UNIT_NAMEPLATES_TYPE_1"] or "Overlapping Nameplates" },
        { value = "1", label = _G["UNIT_NAMEPLATES_TYPE_2"] or "Stacking Nameplates" },
    },
    PROXY_STATUS_TEXT = {
        { value = "1", label = _G["STATUS_TEXT_VALUE"] or "Numeric Value" },
        { value = "2", label = _G["STATUS_TEXT_PERCENT"] or "Percentage" },
        { value = "3", label = _G["STATUS_TEXT_BOTH"] or "Both" },
        { value = "4", label = NONE_LABEL },
    },
    PROXY_CHAT_BUBBLES = {
        { value = "1", label = ALL_LABEL },
        { value = "2", label = NONE_LABEL },
        { value = "3", label = _G["CHAT_BUBBLES_EXCLUDE_PARTY_CHAT"] or "Exclude party chat" },
    },
    raidFramesHealthText = {
        { value = "none",       label = NONE_LABEL },
        { value = "health",     label = _G["RAID_HEALTH_TEXT_HEALTH"] or "Health Remaining" },
        { value = "losthealth", label = _G["RAID_HEALTH_TEXT_LOSTHEALTH"] or "Health Lost" },
        { value = "perc",       label = _G["RAID_HEALTH_TEXT_PERC"] or "Health Percentage" },
    },
    PROXY_SELF_HIGHLIGHT = {
        { value = "0", label = _G["OFF"] or "Off" },
        { value = "1", label = _G["SELF_HIGHLIGHT_MODE_CIRCLE"] or "Circle" },
        { value = "2", label = _G["SELF_HIGHLIGHT_MODE_ICON"] or "Icon" },
        { value = "3", label = _G["SELF_HIGHLIGHT_MODE_CIRCLE_AND_ICON"] or "Circle and Icon" },
    },
    floatingCombatTextFloatMode = {
        { value = "1", label = _G["COMBAT_TEXT_SCROLL_UP"] or "Scroll Up" },
        { value = "2", label = _G["COMBAT_TEXT_SCROLL_DOWN"] or "Scroll Down" },
        { value = "3", label = _G["COMBAT_TEXT_SCROLL_ARC"] or "Arc" },
    },
    PROXY_SELF_CAST = {
        { value = "1", label = NONE_LABEL },
        { value = "2", label = _G["SELF_CAST_AUTO"] or "Auto" },
        { value = "3", label = _G["SELF_CAST_KEY_PRESS"] or "Key Press" },
        { value = "4", label = _G["SELF_CAST_AUTO_AND_KEY_PRESS"] or "Auto and Key Press" },
    },
    SELFCAST = {
        { value = "ALT",   label = ALT_KEY_LABEL },
        { value = "CTRL",  label = CTRL_KEY_LABEL },
        { value = "SHIFT", label = SHIFT_KEY_LABEL },
    },
    FOCUSCAST = {
        { value = "NONE",  label = NONE_LABEL },
        { value = "ALT",   label = ALT_KEY_LABEL },
        { value = "CTRL",  label = CTRL_KEY_LABEL },
        { value = "SHIFT", label = SHIFT_KEY_LABEL },
    },
    chatStyle = {
        { value = "classic", label = _G["CLASSIC_STYLE"] or "Classic Style" },
        { value = "im",      label = _G["IM_STYLE"] or "IM Style" },
    },
    whisperMode = {
        { value = "inline",            label = _G["CONVERSATION_MODE_INLINE"] or "In-line" },
        { value = "popout",            label = _G["CONVERSATION_MODE_POPOUT"] or "New Tab" },
        { value = "popout_and_inline", label = _G["CONVERSATION_MODE_POPOUT_AND_INLINE"] or "Both" },
    },
    showTimestamps = {
        { value = "none",          label = NONE_LABEL },
        { value = "%H:%M ",        label = "15:27" },
        { value = "%I:%M ",        label = "03:27" },
        { value = "%H:%M:%S ",     label = "15:27:32" },
        { value = "%I:%M %p ",     label = "03:27 PM" },
        { value = "%I:%M:%S ",     label = "03:27:32" },
        { value = "%I:%M:%S %p ",  label = "03:27:32 PM" },
    },
    PROXY_SICKNESS_SHAKE = {
        { value = "1", label = NONE_LABEL },
        { value = "2", label = _G["SHAKE_INTENSITY_FULL"] or "Full" },
        { value = "3", label = _G["SHAKE_INTENSITY_REDUCED"] or "Reduced" },
    },
    cursorSizePreferred = {
        { value = "-1", label = _G["CURSOR_SIZE_DEFAULT"] or "Default" },
        { value = "0",  label = "32x32" },
        { value = "1",  label = "48x48" },
        { value = "2",  label = "64x64" },
        { value = "3",  label = "96x96" },
        { value = "4",  label = "128x128" },
    },
    PROXY_INTERACT_ICONS = {
        { value = "1", label = _G["INTERACT_ICONS_DEFAULT"] or "NPCs Only (Default)" },
        { value = "2", label = _G["INTERACT_ICONS_SHOW_ALL"] or "Show All" },
        { value = "3", label = _G["INTERACT_ICONS_SHOW_NONE"] or "Show None" },
    },
    colorblindSimulator = {
        { value = "0", label = NONE_LABEL },
        { value = "1", label = _G["COLORBLIND_OPTION_PROTANOPIA"] or "Protanopia" },
        { value = "2", label = _G["COLORBLIND_OPTION_DEUTERANOPIA"] or "Deuteranopia" },
        { value = "3", label = _G["COLORBLIND_OPTION_TRITANOPIA"] or "Tritanopia" },
    },
    PROXY_MOVIE_SUBTITLE_BACKGROUND = {
        { value = "1", label = NONE_LABEL },
        { value = "2", label = _G["CINEMATIC_SUBTITLES_BACKGROUND_OPTION_DARK"] or "Dark" },
        { value = "3", label = _G["CINEMATIC_SUBTITLES_BACKGROUND_OPTION_LIGHT"] or "Light" },
    },
    LowLatencyMode = {
        { value = "0", label = _G["VIDEO_OPTIONS_DISABLED"] or "Disabled" },
        { value = "1", label = _G["VIDEO_OPTIONS_BUILTIN"] or "Built-in" },
        { value = "2", label = _G["VIDEO_OPTIONS_NVIDIA_REFLEX"] or "NVIDIA Reflex" },
        { value = "3", label = _G["VIDEO_OPTIONS_NVIDIA_REFLEX_BOOST"] or "NVIDIA Reflex + Boost" },
        { value = "4", label = _G["VIDEO_OPTIONS_INTEL_XELL"] or "Intel XeLL" },
    },
    PROXY_ANTIALIASING = {
        { value = "0", label = NONE_LABEL },
        { value = "1", label = Loc["OPT_AA_IMAGE_BASED"] },
        { value = "2", label = Loc["OPT_AA_MULTISAMPLE"] },
        { value = "3", label = _G["ADVANCED_LABEL"] or "Advanced" },
    },
    PROXY_FXAA = {
        { value = "0", label = NONE_LABEL },
        { value = "1", label = _G["ANTIALIASING_FXAA_LOW"] or "FXAA Low" },
        { value = "2", label = _G["ANTIALIASING_FXAA_HIGH"] or "FXAA High" },
        { value = "3", label = _G["ANTIALIASING_CMAA"] or "CMAA" },
    },
    PROXY_MSAA = {
        { value = "0", label = NONE_LABEL },
        { value = "1", label = "2x" },
        { value = "2", label = "4x" },
        { value = "3", label = "8x" },
    },
    textureFilteringMode = {
        { value = "0", label = _G["VIDEO_OPTIONS_BILINEAR"] or "Bilinear" },
        { value = "1", label = _G["VIDEO_OPTIONS_TRILINEAR"] or "Trilinear" },
        { value = "2", label = "2x " .. Loc["OPT_ANISOTROPIC"] },
        { value = "3", label = "4x " .. Loc["OPT_ANISOTROPIC"] },
        { value = "4", label = "8x " .. Loc["OPT_ANISOTROPIC"] },
        { value = "5", label = "16x " .. Loc["OPT_ANISOTROPIC"] },
    },
    shadowrt = {
        { value = "0", label = _G["VIDEO_OPTIONS_DISABLED"] or "Disabled" },
        { value = "1", label = _G["VIDEO_QUALITY_LABEL2"] or "Fair" },
        { value = "2", label = _G["VIDEO_QUALITY_LABEL3"] or "Good" },
        { value = "3", label = _G["VIDEO_QUALITY_LABEL4"] or "High" },
    },
    ResampleQuality = {
        { value = "0", label = _G["RESAMPLE_QUALITY_POINT"] or "Point" },
        { value = "1", label = _G["RESAMPLE_QUALITY_BILINEAR"] or "Bilinear" },
        { value = "2", label = _G["RESAMPLE_QUALITY_BICUBIC"] or "Bicubic" },
        { value = "3", label = _G["RESAMPLE_QUALITY_FSR"] or "FidelityFX Super Resolution" },
    },
    vrsValar = {
        { value = "0", label = _G["VIDEO_OPTIONS_DISABLED"] or "Disabled" },
        { value = "1", label = _G["VIDEO_OPTIONS_STANDARD"] or "Standard" },
        { value = "2", label = _G["VIDEO_OPTIONS_AGGRESSIVE"] or "Aggressive" },
    },
    cameraSmoothStyle = {
        { value = "0", label = _G["CAMERA_NEVER"] or "Never adjust camera" },
        { value = "1", label = _G["CAMERA_SMART"] or "Only horizontal when moving" },
        { value = "2", label = _G["CAMERA_ALWAYS"] or "Always adjust camera" },
        { value = "4", label = _G["CAMERA_SMARTER"] or "Only when moving" },
    },
    PROXY_GRAPHICS_API = {
        { value = "d3d11", label = _G["GXAPI_D3D11"] or "DirectX 11" },
        { value = "d3d12", label = _G["GXAPI_D3D12"] or "DirectX 12" },
    },
}

local categoryIDByName = {}
local categoryIDByVariable = {}


local localizedNameByCategoryID = {}

local settingTooltips = {}



local function ResolveTooltipGlobal(displayName, cvar)
    if displayName then
        local fromName = "OPTION_TOOLTIP_" .. displayName:upper():gsub("[%s%-]+", "_"):gsub("[^A-Z0-9_]", "")
        local tip = _G[fromName]
        if type(tip) == "string" and tip ~= "" then return tip end
    end
    if cvar and not cvar:find("^PROXY_") then
        local fromCVar = "OPTION_TOOLTIP_" .. cvar:gsub("(%l)(%u)", "%1_%2"):upper()
        local tip = _G[fromCVar]
        if type(tip) == "string" and tip ~= "" then return tip end
    end
end

local function GetTooltipForVariable(variable, displayName)
    if not variable then return nil end
    local cached = settingTooltips[variable]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    do
        local settObj = Utils.FindSetting(variable)
        if settObj and settObj.GetTooltip then
            local tok, t = pcall(settObj.GetTooltip, settObj)
            if tok and type(t) == "string" and t ~= "" then
                settingTooltips[variable] = t
                return t
            end
        end
    end

    local fromGlobal = ResolveTooltipGlobal(displayName, variable)
    if fromGlobal then
        settingTooltips[variable] = fromGlobal
        return fromGlobal
    end

    settingTooltips[variable] = false
    return nil
end
BlizzOptionsSearch.GetTooltipForVariable = GetTooltipForVariable

local function AddKeyword(kw, text)
    if type(text) == "string" and text ~= "" then
        kw[#kw + 1] = slower(text)
    end
end



local OPTION_LABELS_MAX = 24
local function AddOptionLabelKeywords(kw, options)
    if type(options) ~= "table" or #options > OPTION_LABELS_MAX then return end
    for i = 1, #options do
        local opt = options[i]
        if type(opt) == "table" then
            AddKeyword(kw, opt.label or opt.text or opt.name)
        end
    end
end



local optionsByVariable = {}
local function NormalizeOptionTable(opts, setting)
    if type(opts) == "function" then
        local ok, o = pcall(opts, setting)
        if not ok then
            ok, o = pcall(opts)
        end
        if not ok then return nil end
        opts = o
    end
    if type(opts) ~= "table" then return nil end
    local norm = {}
    for _, o in ipairs(opts) do
        if type(o) == "table" then
            local value = o.value
            if value == nil then value = o.cvarValue end
            if value == nil and type(o.data) == "table" then
                value = o.data.value
                if value == nil then value = o.data.cvarValue end
                if value == nil then value = o.data.id end
            elseif value == nil then
                value = o.data
            end
            if value == nil and o.GetValue then
                local ok, v = pcall(o.GetValue, o)
                if ok then value = v end
            end
            if value ~= nil then
                local label = o.label or o.text or o.name
                if not label and type(o.data) == "table" then
                    label = o.data.label or o.data.text or o.data.name
                end
                if not label and o.GetText then
                    local ok, text = pcall(o.GetText, o)
                    if ok then label = text end
                end
                if not label and o.GetName then
                    local ok, name = pcall(o.GetName, o)
                    if ok then label = name end
                end
                tinsert(norm, { value = value, label = label or tostring(value) })
            end
        elseif o ~= nil then
            tinsert(norm, { value = o, label = tostring(o) })
        end
    end
    if #norm == 0 then
        for value, label in pairs(opts) do
            if type(label) ~= "table" then
                tinsert(norm, { value = value, label = tostring(label) })
            end
        end
    end
    if #norm == 0 then return nil end
    return norm
end

local function GetInitializerOptions(init, setting)
    local d = init and init.data
    local found
    if type(d) == "table" then
        found = NormalizeOptionTable(d.options, setting)
            or NormalizeOptionTable(d.dropdownOptions, setting)
            or NormalizeOptionTable(d.values, setting)
            or NormalizeOptionTable(d.valueOptions, setting)
    end
    if not found and init and init.GetOptions then
        local ok, opts = pcall(init.GetOptions, init)
        if ok then found = NormalizeOptionTable(opts, setting) end
    end
    if not found and setting and setting.GetOptions then
        local ok, opts = pcall(setting.GetOptions, setting)
        if ok then found = NormalizeOptionTable(opts, setting) end
    end
    return found
end





local initByVariable, settingByVariable
local indexGen = 0

local function CollectSettings(value, depth, seen, init, inits, settings)
    if type(value) ~= "table" or depth > 4 or seen[value] then return end
    seen[value] = true
    if value.GetVariable then
        local ok, v = pcall(value.GetVariable, value)
        if ok and v ~= nil and inits[v] == nil then inits[v], settings[v] = init, value end
    end
    for _, child in pairs(value) do
        if type(child) == "table" then CollectSettings(child, depth + 1, seen, init, inits, settings) end
    end
end



local function IndexSettings(sliced)
    if not (SettingsPanel and SettingsPanel.GetLayout and HasSettingsCategoryAccess()) then return false end
    local gen = indexGen
    local inits, settings = {}, {}
    local function scan(cat)
        if not cat then return end
        local lok, layout = pcall(SettingsPanel.GetLayout, SettingsPanel, cat)
        if lok and layout and layout.GetInitializers then
            local iok, list = pcall(layout.GetInitializers, layout)
            if iok and list then
                for i, init in ipairs(list) do
                    if sliced and i % 16 == 0 then Utils.SliceCheckpoint() end
                    local seen = {}
                    if init.GetSetting then
                        local sok, setting = pcall(init.GetSetting, init)
                        if sok then CollectSettings(setting, 0, seen, init, inits, settings) end
                    end
                    CollectSettings(init.data, 0, seen, init, inits, settings)
                    if init.GetData then
                        local dok, dd = pcall(init.GetData, init)
                        if dok then CollectSettings(dd, 0, seen, init, inits, settings) end
                    end
                end
            end
        end
        if cat.GetSubcategories then
            local sok, subs = pcall(cat.GetSubcategories, cat)
            if sok and type(subs) == "table" then
                for _, sub in ipairs(subs) do scan(sub) end
            end
        end
    end
    local list = GetSettingsCategoryList()
    if type(list) == "table" then
        for _, cat in ipairs(list) do scan(cat) end
    end
    if gen == indexGen then initByVariable, settingByVariable = inits, settings end
    return true
end

local function IndexedInitializer(variable)
    if not initByVariable and not IndexSettings(false) then return nil end
    return initByVariable[variable], settingByVariable[variable]
end

local function GetOptionsForVariable(variable)
    if not variable then return nil end
    local cached = optionsByVariable[variable]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end


    local hardcoded = CVAR_DROPDOWN_OPTIONS[variable]
    if hardcoded then
        optionsByVariable[variable] = hardcoded
        return hardcoded
    end
    if not (SettingsPanel and SettingsPanel.GetLayout and HasSettingsCategoryAccess()) then
        return nil
    end
    local init, setting = IndexedInitializer(variable)
    local found = init and GetInitializerOptions(init, setting) or nil
    optionsByVariable[variable] = found or false
    return found
end
BlizzOptionsSearch.GetOptionsForVariable = GetOptionsForVariable




local sliderOptionsByVariable = {}
local function PickFormatter(formatters)
    if type(formatters) ~= "table" then return nil end


    local f = formatters[2] or formatters[1] or formatters[0]
        or formatters.Top or formatters.Right
    if type(f) == "function" then return f end
    for _, fn in pairs(formatters) do
        if type(fn) == "function" then return fn end
    end
    return nil
end
local function GetSliderOptionsForVariable(variable)
    if not variable then return nil end
    local cached = sliderOptionsByVariable[variable]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end
    if not (SettingsPanel and SettingsPanel.GetLayout and HasSettingsCategoryAccess()) then
        return nil
    end
    local found
    local init, setting = IndexedInitializer(variable)
    local d = init and init.data
    local opts = (type(d) == "table") and (d.options or d.sliderOptions) or nil
    if type(opts) == "function" then
        local ook, o = pcall(opts, setting)
        if not ook then ook, o = pcall(opts) end
        if ook then opts = o end
    end
    if type(opts) == "table" then
        local fmt = PickFormatter(opts.formatters)
        local minV, maxV = opts.minValue, opts.maxValue
        local step
        if minV ~= nil and maxV ~= nil then

            if opts.stepSize then
                step = opts.stepSize
            elseif opts.steps and opts.steps > 0 and maxV > minV then
                step = (maxV - minV) / opts.steps
            else
                step = 1
            end
        end
        if fmt or (minV ~= nil and maxV ~= nil) then
            found = { min = minV, max = maxV, step = step, formatter = fmt }
        end
    end
    sliderOptionsByVariable[variable] = found or false
    return found
end
BlizzOptionsSearch.GetSliderOptionsForVariable = GetSliderOptionsForVariable

local function GetFormatterForVariable(variable)
    local info = GetSliderOptionsForVariable(variable)
    return info and info.formatter or nil
end
BlizzOptionsSearch.GetFormatterForVariable = GetFormatterForVariable



function BlizzOptionsSearch.ReindexSettings()
    wipe(optionsByVariable)
    wipe(sliderOptionsByVariable)
    initByVariable, settingByVariable = nil, nil
    indexGen = indexGen + 1
    local gen = indexGen
    SafeAfter(0, function()
        if initByVariable or gen ~= indexGen then return end
        Utils.RunSliced(function() IndexSettings(true) end, function(ok, err)
            if not ok then Utils.ErrorHandler(err) end
        end, function() return optionsPopulateUrgent and 4 or 2 end, "settingsIndex")
    end)
end



local pendingApplySettings = {}

local function PendingCount()




    local n = 0
    for setting in pairs(pendingApplySettings) do
        if setting.pendingValue == nil then
            pendingApplySettings[setting] = nil
        else
            n = n + 1
        end
    end
    return n
end

function BlizzOptionsSearch:GetPendingApplyCount()
    return PendingCount()
end



local Apply = { revertable = {}, KEEP = "EASYFIND_SETTINGS_TIMED_CONFIRMATION", KEEP_SECONDS = 8 }




function Apply.Redraw()
    if Apply.redrawQueued or IsMouseButtonDown("LeftButton") then return end
    Apply.redrawQueued = true
    SafeAfter(0, function()
        Apply.redrawQueued = nil
        if ns.Search and ns.Search.RefreshResults then ns.Search:RefreshResults() end
    end)
end

function BlizzOptionsSearch:NotePendingApply(variable)
    local settObj = Utils.FindSetting(variable)
    if not settObj then return end
    local hasApply
    if settObj.HasCommitFlag and Settings.CommitFlag and Settings.CommitFlag.Apply then
        local hok, has = pcall(settObj.HasCommitFlag, settObj, Settings.CommitFlag.Apply)
        hasApply = hok and has
    end
    local was = pendingApplySettings[settObj] ~= nil
    if hasApply and settObj.pendingValue ~= nil then
        pendingApplySettings[settObj] = settObj
    elseif was then
        pendingApplySettings[settObj] = nil
    end
    if was ~= (pendingApplySettings[settObj] ~= nil) then Apply.Redraw() end
end




function Apply.NoteFlags(settObj)
    local flags = Settings.CommitFlag
    if not (flags and settObj.HasCommitFlag) then return end
    if flags.GxRestart and settObj:HasCommitFlag(flags.GxRestart) then Apply.gx = true end
    if flags.UpdateWindow and settObj:HasCommitFlag(flags.UpdateWindow) then Apply.window = true end
end
function Apply.Finalize()
    if Apply.gx and RestartGx then RestartGx() end
    if Apply.window and UpdateWindow then UpdateWindow() end
    Apply.gx, Apply.window = nil, nil
    if #Apply.revertable > 0 then Apply.AskToKeep() end
end



function Apply.AskToKeep()
    if Apply.timer then Apply.timer:Cancel() end
    StaticPopup_Hide(Apply.KEEP)
    StaticPopup_Show(Apply.KEEP, nil, nil, Apply.KEEP_SECONDS)
    local Results = ns.Results
    if Results and Results.LiftPopupStrata and Results.FindPopupSlot then
        Results:LiftPopupStrata(Results:FindPopupSlot(Apply.KEEP))
    end
    Apply.timer = C_Timer.NewTimer(Apply.KEEP_SECONDS, function()
        Apply.RevertKept()
        StaticPopup_Hide(Apply.KEEP)
    end)
end

function Apply.Keep()
    if Apply.timer then Apply.timer:Cancel() end
    Apply.timer = nil
    wipe(Apply.revertable)
end

function Apply.RevertKept()
    if Apply.timer then Apply.timer:Cancel() end
    Apply.timer = nil
    local list = Apply.revertable
    Apply.revertable = {}
    for i = 1, #list do
        local setting, before = list[i][1], list[i][2]
        pcall(setting.SetValue, setting, before, true)
        Apply.NoteFlags(setting)
    end
    Apply.Finalize()
    if ns.Search and ns.Search.RefreshResults then ns.Search:RefreshResults() end
end



function Apply.NoteRevertable(settObj)
    local flags = Settings.CommitFlag
    if not (flags and flags.Revertable and settObj.GetValueDerived and settObj:HasCommitFlag(flags.Revertable)) then
        return
    end
    for i = 1, #Apply.revertable do
        if Apply.revertable[i][1] == settObj then return end
    end
    Apply.revertable[#Apply.revertable + 1] = { settObj, settObj:GetValueDerived() }
end

function Apply.ByOrder(a, b)
    return (a.GetCommitOrder and a:GetCommitOrder() or 0) < (b.GetCommitOrder and b:GetCommitOrder() or 0)
end

function BlizzOptionsSearch:ApplyPendingChanges()
    if not next(pendingApplySettings) then return end


    local settings = {}
    for setting in pairs(pendingApplySettings) do settings[#settings + 1] = setting end
    table.sort(settings, Apply.ByOrder)
    for i = 1, #settings do
        local setting = settings[i]
        if setting.GetVariable then
            local ok, v = pcall(setting.GetVariable, setting)
            if ok and v then Apply.Commit(v) end
        end
    end
    wipe(pendingApplySettings)
    Apply.Finalize()
end

function BlizzOptionsSearch:RevertPendingChanges()
    if not next(pendingApplySettings) then return end
    for setting in pairs(pendingApplySettings) do
        if setting.Revert then pcall(setting.Revert, setting) end
    end
    wipe(pendingApplySettings)
end

function BlizzOptionsSearch:HasPendingChange(variable)
    local settObj = Utils.FindSetting(variable)
    if not settObj then return false end




    return settObj.pendingValue ~= nil
end





local PROXY_DEPENDENT_DEFAULTS = {
    PROXY_ANTIALIASING = function(value)
        if value == 1 and GetCVar and tonumber(GetCVar("ffxAntiAliasingMode")) == 0 then
            if SetCVar then pcall(SetCVar, "ffxAntiAliasingMode", "1") end
        elseif value == 2 and GetCVar and tonumber(GetCVar("MSAAQuality")) == 0 then
            if SetCVar then pcall(SetCVar, "MSAAQuality", "2") end
        elseif value == 3 then
            if GetCVar and tonumber(GetCVar("ffxAntiAliasingMode")) == 0
               and SetCVar then pcall(SetCVar, "ffxAntiAliasingMode", "1") end
            if GetCVar and tonumber(GetCVar("MSAAQuality")) == 0
               and SetCVar then pcall(SetCVar, "MSAAQuality", "2") end
        end
    end,
}



local PROXY_DEPENDENTS = {
    PROXY_ANTIALIASING = { "PROXY_FXAA", "PROXY_MSAA", "PROXY_MSAA_ALPHA" },
}

local function CommitStagedDependents(parentVar)
    local deps = PROXY_DEPENDENTS[parentVar]
    if not deps then return end
    for i = 1, #deps do
        local depObj = Utils.FindSetting(deps[i])
        if depObj and depObj.pendingValue ~= nil and depObj.SetValue then
            pcall(depObj.SetValue, depObj, depObj.pendingValue, true)
            pendingApplySettings[depObj] = nil
            Apply.NoteFlags(depObj)
        end
    end
end

function Apply.Commit(variable)
    local settObj = Utils.FindSetting(variable)
    if not settObj or settObj.pendingValue == nil then return end
    local pending = settObj.pendingValue
    local depsFn = PROXY_DEPENDENT_DEFAULTS[variable]
    if depsFn then pcall(depsFn, pending) end





    Apply.NoteRevertable(settObj)
    if settObj.SetValue then
        pcall(settObj.SetValue, settObj, pending, true)
    end
    Apply.NoteFlags(settObj)
    CommitStagedDependents(variable)
    pendingApplySettings[settObj] = nil
end


function BlizzOptionsSearch:ApplyVariable(...)
    for i = 1, select("#", ...) do Apply.Commit((select(i, ...))) end
    Apply.Finalize()
end








if StaticPopupDialogs and not StaticPopupDialogs[Apply.KEEP] then
    StaticPopupDialogs[Apply.KEEP] = {
        text = "",
        button1 = SETTINGS_CONFIRM_TIMEOUT_BUTTON,
        button2 = SETTINGS_CANCEL_TIMEOUT_BUTTON,
        OnAccept = function() Apply.Keep() end,
        OnCancel = function() Apply.RevertKept() end,
        OnShow = function(dialog, duration) dialog.duration = duration end,
        OnHide = function(dialog) dialog.duration = nil end,
        OnUpdate = function(dialog, elapsed)
            dialog.duration = dialog.duration - elapsed
            local time = math.max(dialog.duration + 1, 1)
            dialog:SetText(SETTINGS_TIMED_CONFIRMATION:format(time))
            dialog:Resize(Apply.KEEP)
        end,
        whileDead = 1,
        fullScreenCover = true,
    }
end

if StaticPopupDialogs and not StaticPopupDialogs["EASYFIND_UNAPPLIED_SETTINGS"] then
    StaticPopupDialogs["EASYFIND_UNAPPLIED_SETTINGS"] = {
        text = SETTINGS_CONFIRM_DISCARD or ns.L["POPUP_UNAPPLIED_SETTINGS"],
        button1 = SETTINGS_UNAPPLIED_EXIT or ns.L["POPUP_UNAPPLIED_EXIT"],
        button2 = SETTINGS_UNAPPLIED_APPLY_AND_EXIT or ns.L["POPUP_UNAPPLIED_APPLY"],
        button3 = SETTINGS_UNAPPLIED_CANCEL or ns.L["POPUP_UNAPPLIED_CANCEL"],
        OnButton1 = function()
            if BlizzOptionsSearch.RevertPendingChanges then
                BlizzOptionsSearch:RevertPendingChanges()
            end
            if ns.Search and ns.Search.Hide then ns.Search:Hide() end
        end,
        OnButton2 = function()
            if BlizzOptionsSearch.ApplyPendingChanges then
                BlizzOptionsSearch:ApplyPendingChanges()
            end
            if ns.Search and ns.Search.Hide then ns.Search:Hide() end
        end,
        OnButton3 = function() end,
        OnHide = function()
            if ns.Search and ns.Search.RefocusSearchEditBox then
                SearchFocus:RefocusSearchEditBox()
            end
        end,
        selectCallbackByIndex = true,
        hideOnEscape = 1,
        whileDead = 1,
        fullScreenCover = true,
    }
end

function BlizzOptionsSearch:RevertVariable(variable)
    local settObj = Utils.FindSetting(variable)
    if not settObj or settObj.pendingValue == nil then return end
    if settObj.Revert then pcall(settObj.Revert, settObj) end
    pendingApplySettings[settObj] = nil
    local deps = PROXY_DEPENDENTS[variable]
    if deps then
        for i = 1, #deps do
            local depObj = Utils.FindSetting(deps[i])
            if depObj and depObj.pendingValue ~= nil and depObj.Revert then
                pcall(depObj.Revert, depObj)
                pendingApplySettings[depObj] = nil
            end
        end
    end
end

local function CrawlCategory(cat)
    if not cat or not cat.GetID or not cat.GetName then return end
    local catID = cat:GetID()
    local catName = cat:GetName()
    if catName and catName ~= "" then
        categoryIDByName[slower(catName)] = catID
        localizedNameByCategoryID[catID] = catName
    end

    if SettingsPanel and SettingsPanel.GetLayout then
        local lok, layout = pcall(SettingsPanel.GetLayout, SettingsPanel, cat)
        if lok and layout and layout.GetInitializers then
            local iok, inits = pcall(layout.GetInitializers, layout)
            if iok and inits then
                for _, init in ipairs(inits) do
                    local setting
                    if init.GetSetting then
                        local sok, s = pcall(init.GetSetting, init)
                        if sok then setting = s end
                    end
                    if not setting and init.data then
                        setting = init.data.setting
                    end
                    if not setting and init.GetData then
                        local dok, d = pcall(init.GetData, init)
                        if dok and d then setting = d.setting end
                    end
                    if setting and setting.GetVariable then
                        local vok, v = pcall(setting.GetVariable, setting)
                        if vok and v then
                            if not categoryIDByVariable[v] then
                                categoryIDByVariable[v] = catID
                            end


                            if settingTooltips[v] == nil then
                                local tip
                                pcall(function()
                                    local d = init.data
                                    if type(d) ~= "table" then return end
                                    if type(d.tooltip) == "string" then
                                        tip = d.tooltip
                                        return
                                    end
                                    if type(d.tooltip) == "function" then
                                        local tt = d.tooltip()
                                        if type(tt) == "string" then tip = tt end
                                        return
                                    end
                                    local opts = d.options
                                    if type(opts) == "table" and type(opts.tooltip) == "string" then
                                        tip = opts.tooltip
                                    end
                                end)
                                if not tip and setting.GetTooltip then
                                    local tok, t = pcall(setting.GetTooltip, setting)
                                    if tok and type(t) == "string" and t ~= "" then
                                        tip = t
                                    end
                                end
                                if tip and tip ~= "" then
                                    settingTooltips[v] = tip
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if cat.GetSubcategories then
        local sok, subs = pcall(cat.GetSubcategories, cat)
        if sok and type(subs) == "table" then
            for _, sub in ipairs(subs) do
                CrawlCategory(sub)
            end
        end
    end
end





local lastCrawlAt, lastCrawlCount = -100, -1
local function CategoryListCount()
    local list = GetSettingsCategoryList()
    return type(list) == "table" and #list or 0
end


local function ResolveCategoryIDs()
    local crawled = {}
    local function Crawl(list)
        for _, cat in ipairs(type(list) == "table" and list or {}) do
            if not crawled[cat] then
                crawled[cat] = true
                pcall(CrawlCategory, cat)
                MaybeYieldLiveSettings()
            end
        end
    end
    Crawl(GetSettingsCategoryList())
    if SettingsPanel and SettingsPanel.GetAllCategories then
        local ok, all = pcall(SettingsPanel.GetAllCategories, SettingsPanel)
        if ok then Crawl(all) end
    end
    lastCrawlAt, lastCrawlCount = GetTime and GetTime() or 0, CategoryListCount()
end

local function CrawlOnMiss()
    if CategoryListCount() == lastCrawlCount and (GetTime and GetTime() or 0) - lastCrawlAt < 5 then return end
    ResolveCategoryIDs()
end



local function ShowSettings()
    if not SettingsPanel then return end
    if SettingsPanel:IsShown() then return end
    if SettingsPanel.Open then
        SecureCall(SettingsPanel.Open, SettingsPanel)
    elseif ShowUIPanel then
        SecureCall(ShowUIPanel, SettingsPanel)
    end
end

local function GetCategoryID(name)
    if not name or name == "" then return nil end
    local cached = categoryIDByName[slower(name)]
    if cached then return cached end
    CrawlOnMiss()
    return categoryIDByName[slower(name)]
end

local function GetCategoryIDForVariable(variable)
    if not variable then return nil end
    local cached = categoryIDByVariable[variable]
    if cached then return cached end
    CrawlOnMiss()
    return categoryIDByVariable[variable]
end
BlizzOptionsSearch.GetCategoryIDForVariable = GetCategoryIDForVariable

local function OpenSettingsByName(name)
    local id = GetCategoryID(name)
    if not id then return false end
    ShowSettings()
    if Settings and Settings.OpenToCategory then
        pcall(Settings.OpenToCategory, id)
        return true
    end
    return false
end
BlizzOptionsSearch.OpenSettingsByName = OpenSettingsByName

local function GetSettingsScrollBox()
    if not SettingsPanel then return nil end
    return SettingsPanel.Container
        and SettingsPanel.Container.SettingsList
        and SettingsPanel.Container.SettingsList.ScrollBox
end

local function HighlightFoundElement(scrollBox, elementData)
    if not scrollBox or not elementData then return end
    if not ns.Highlight or not ns.Highlight.HighlightFrame then return end
    SafeAfter(0.05, function()
        local frame = scrollBox.FindFrame and scrollBox:FindFrame(elementData)
        if frame then
            ns.Highlight:HighlightFrame(frame, nil, function(target)
                if not target or not target:IsVisible() then return false end
                if not scrollBox.FindFrame then return true end
                return scrollBox:FindFrame(elementData) == target
            end)
        end
    end)
end

local function SettingMatches(setting, variable)
    if not setting or not setting.GetVariable then return false end
    local ok, v = pcall(setting.GetVariable, setting)
    return ok and v == variable
end







local function FindSettingElement(dp, variable)
    if not dp then return nil end
    local function classify(elementData)
        local inner = elementData and (elementData.data or elementData)
        if not inner then return false end
        if SettingMatches(inner.setting, variable) then return "direct" end
        if SettingMatches(inner.cbSetting, variable) then return "direct" end
        if SettingMatches(inner.sliderSetting, variable) then return "direct" end
        if type(inner.settings) == "table" then
            for _, child in pairs(inner.settings) do
                if SettingMatches(child, variable) then return "container" end
            end
        end
        if type(inner.raidSettings) == "table" then
            for _, child in pairs(inner.raidSettings) do
                if SettingMatches(child, variable) then return "container" end
            end
        end
        return false
    end



    local containerHit, containerKind
    if dp.FindElementDataByPredicate then
        local direct = dp:FindElementDataByPredicate(function(ed)
            return classify(ed) == "direct"
        end)
        if direct then return direct, "direct" end
        containerHit = dp:FindElementDataByPredicate(function(ed)
            return classify(ed) == "container"
        end)
        if containerHit then return containerHit, "container" end
    end
    if dp.GetSize and dp.Find then
        for si = 1, dp:GetSize() do
            local ed = dp:Find(si)
            local kind = classify(ed)
            if kind == "direct" then return ed, "direct" end
            if kind == "container" and not containerHit then
                containerHit, containerKind = ed, "container"
            end
        end
        if containerHit then return containerHit, containerKind end
    end
    return nil
end













local CONTAINER_CHILD_FRAME_SUFFIX = {
    PROXY_GRAPHICS_QUALITY        = "GraphicsQuality",
    PROXY_RAID_GRAPHICS_QUALITY   = "GraphicsQuality",
    PROXY_VIEW_DISTANCE           = "ViewDistance",
    PROXY_RAID_VIEW_DISTANCE      = "ViewDistance",
    PROXY_ENVIRONMENT_DETAIL      = "EnvironmentDetail",
    PROXY_RAID_ENVIRONMENT_DETAIL = "EnvironmentDetail",
    PROXY_GROUND_CLUTTER          = "GroundClutter",
    PROXY_RAID_GROUND_CLUTTER     = "GroundClutter",
    PROXY_SHADOW_QUALITY          = "ShadowQuality",
    PROXY_RAID_SHADOW_QUALITY     = "ShadowQuality",
    PROXY_LIQUID_DETAIL           = "LiquidDetail",
    PROXY_RAID_LIQUID_DETAIL      = "LiquidDetail",
    PROXY_PARTICLE_DENSITY        = "ParticleDensity",
    PROXY_RAID_PARTICLE_DENSITY   = "ParticleDensity",
    PROXY_SSAO                    = "SSAO",
    PROXY_RAID_SSAO               = "SSAO",
    PROXY_DEPTH_EFFECTS           = "DepthEffects",
    PROXY_RAID_DEPTH_EFFECTS      = "DepthEffects",
    PROXY_COMPUTE_EFFECTS         = "ComputeEffects",
    PROXY_RAID_COMPUTE_EFFECTS    = "ComputeEffects",
    PROXY_OUTLINE_MODE            = "OutlineMode",
    PROXY_RAID_OUTLINE_MODE       = "OutlineMode",
    PROXY_TEXTURE_RESOLUTION      = "TextureResolution",
    PROXY_RAID_TEXTURE_RESOLUTION = "TextureResolution",
    PROXY_SPELL_DENSITY           = "SpellDensity",
    PROXY_RAID_SPELL_DENSITY      = "SpellDensity",
    PROXY_PROJECTED_TEXTURES      = "ProjectedTextures",
    PROXY_RAID_PROJECTED_TEXTURES = "ProjectedTextures",
}

local function FindChildFrameForVariable(containerFrame, variable)
    if not containerFrame or not containerFrame.GetChildren then return nil end


    local function check(frame, depth)
        if not frame or depth > 6 then return nil end
        local init = frame.initializer or frame.Initializer
        local data = (init and init.data) or frame.data
        if data then
            if SettingMatches(data.setting, variable) then return frame end
            if SettingMatches(data.cbSetting, variable) then return frame end
            if SettingMatches(data.sliderSetting, variable) then return frame end
        end
        if frame.GetChildren then
            local kids = { frame:GetChildren() }
            for i = 1, #kids do
                local hit = check(kids[i], depth + 1)
                if hit then return hit end
            end
        end
        return nil
    end
    local hit = check(containerFrame, 0)
    if hit then return hit end





    local suffix = CONTAINER_CHILD_FRAME_SUFFIX[variable]
    if suffix then
        local visibleHit, hiddenHit
        local function findByName(frame, depth)
            if not frame or depth > 6 then return end
            if frame.GetDebugName then
                local ok, name = pcall(frame.GetDebugName, frame)
                if ok and name and name:sub(-(#suffix + 1)) == "." .. suffix then
                    if frame.IsVisible and frame:IsVisible() then
                        visibleHit = frame
                    elseif not hiddenHit then
                        hiddenHit = frame
                    end
                end
            end
            if visibleHit then return end
            if frame.GetChildren then
                local kids = { frame:GetChildren() }
                for i = 1, #kids do
                    findByName(kids[i], depth + 1)
                    if visibleHit then return end
                end
            end
        end
        findByName(containerFrame, 0)
        return visibleHit or hiddenHit
    end
    return nil
end




local function IsRaidQualityVariable(variable)
    return type(variable) == "string" and variable:find("^PROXY_RAID_") ~= nil
end




local function ClickTabBySuffix(containerFrame, suffix)
    if not containerFrame or not containerFrame.GetChildren then return false end
    local function find(frame, depth)
        if not frame or depth > 4 then return nil end
        if frame.GetDebugName then
            local ok, name = pcall(frame.GetDebugName, frame)
            if ok and name and name:sub(-(#suffix + 1)) == "." .. suffix then
                return frame
            end
        end
        if frame.GetChildren then
            local kids = { frame:GetChildren() }
            for i = 1, #kids do
                local h = find(kids[i], depth + 1)
                if h then return h end
            end
        end
        return nil
    end
    local tab = find(containerFrame, 0)
    if tab and tab.Click then
        pcall(tab.Click, tab)
        return true
    end
    return false
end




local function ChildTopOffset(container, child)
    if not container or not child or not child.GetTop or not container.GetTop then
        return 0
    end
    local cTop = container:GetTop()
    local childTop = child:GetTop()
    if not cTop or not childTop then return 0 end
    return cTop - childTop
end

local function ScrollToSettingVariable(variable)
    local scrollBox = GetSettingsScrollBox()
    if not scrollBox then return false end
    local dp = scrollBox.GetDataProvider and scrollBox:GetDataProvider()
    local found, kind = FindSettingElement(dp, variable)
    if not found then return false end

    local alignBegin = ScrollBoxConstants and ScrollBoxConstants.AlignBegin
    local alignCenter = ScrollBoxConstants and ScrollBoxConstants.AlignCenter




    if kind == "container" then
        scrollBox:ScrollToElementData(found, alignBegin or alignCenter)
        SafeAfter(0, function()
            local outer = scrollBox.FindFrame and scrollBox:FindFrame(found)
            if not outer then return end









            local tabSwapped
            if IsRaidQualityVariable(variable) then
                tabSwapped = ClickTabBySuffix(outer, "RaidTab")
            else
                tabSwapped = ClickTabBySuffix(outer, "BaseTab")
            end
            local function continueAfterSwap()
                local child = FindChildFrameForVariable(outer, variable)
                if not child then


                    HighlightFoundElement(scrollBox, found)
                    return
                end
                local offset = ChildTopOffset(outer, child)
                if offset > 0
                   and scrollBox.SetScrollPercentage and scrollBox.GetScrollPercentage
                   and scrollBox.GetDerivedScrollRange and scrollBox.GetHeight then
                    local range = scrollBox:GetDerivedScrollRange()
                    if range and range > 0 then
                        local curScroll = (scrollBox:GetScrollPercentage() or 0) * range
                        local vH = scrollBox:GetHeight() or 0
                        local cH = (child.GetHeight and child:GetHeight()) or 24
                        local desiredScroll = curScroll + offset + cH / 2 - vH / 2
                        local newPercent = math.max(0, math.min(1, desiredScroll / range))
                        scrollBox:SetScrollPercentage(newPercent)
                    end
                end




                SafeAfter(0, function()
                    local refetched = FindChildFrameForVariable(
                        scrollBox.FindFrame and scrollBox:FindFrame(found), variable)
                    local target = refetched or child
                    if target and target:IsShown()
                       and ns.Highlight and ns.Highlight.HighlightFrame then
                        ns.Highlight:HighlightFrame(target, nil, function(t)
                            return t and t:IsVisible()
                        end)
                    end
                end)
            end





            if tabSwapped then
                SafeAfter(0, continueAfterSwap)
            else
                continueAfterSwap()
            end
        end)
    else
        scrollBox:ScrollToElementData(found, alignCenter or alignBegin)
        HighlightFoundElement(scrollBox, found)
    end

    return true
end
BlizzOptionsSearch.ScrollToSettingVariable = ScrollToSettingVariable

local function GetBindingIndexForAction(action)
    if not action or not GetNumBindings or not GetBinding then return nil end
    for i = 1, GetNumBindings() do
        local a = GetBinding(i)
        if a == action then return i end
    end
    return nil
end


local function FindBindingFrameInSection(sectionFrame, bindingIndex)
    if not sectionFrame or not sectionFrame.Controls then return nil end
    for _, frame in ipairs(sectionFrame.Controls) do
        local idx
        if frame.initializer and frame.initializer.data then
            idx = frame.initializer.data.bindingIndex
        end
        if not idx and frame.data and frame.data.bindingIndex then
            idx = frame.data.bindingIndex
        end
        if idx == bindingIndex then return frame end
    end
    return nil
end

local function ScrollToBindingAction(action, headerName)
    if not action then return false end
    local scrollBox = GetSettingsScrollBox()
    if not scrollBox then return false end
    local dp = scrollBox.GetDataProvider and scrollBox:GetDataProvider()
    if not dp then return false end

    local bindingIdx = GetBindingIndexForAction(action)


    local headerLower = headerName and slower(headerName) or nil
    local function matchSection(elementData)
        local inner = elementData and (elementData.data or elementData)
        if not inner then return false end
        if headerLower and inner.name and slower(inner.name) == headerLower then
            return true
        end
        if bindingIdx and inner.bindingsCategories then
            for _, entry in ipairs(inner.bindingsCategories) do
                if type(entry) == "table" and entry[1] == bindingIdx then return true end
            end
        end
        return false
    end

    local section
    if dp.FindElementDataByPredicate then
        section = dp:FindElementDataByPredicate(matchSection)
    end
    if not section and dp.GetSize and dp.Find then
        for si = 1, dp:GetSize() do
            local ed = dp:Find(si)
            if matchSection(ed) then section = ed; break end
        end
    end
    if not section then return false end

    local sectionData = section.data or section
    local alignBegin = ScrollBoxConstants and ScrollBoxConstants.AlignBegin
    scrollBox:ScrollToElementData(section, alignBegin)







    local function ScrollSectionToChild(child)
        if not child or not child.GetTop then return end
        if not (scrollBox.GetTop and scrollBox.SetScrollPercentage and scrollBox.GetScrollPercentage
                and scrollBox.GetDerivedScrollRange and scrollBox.GetHeight) then return end
        local vpTop, cTop = scrollBox:GetTop(), child:GetTop()
        if not vpTop or not cTop then return end
        local range = scrollBox:GetDerivedScrollRange()
        if not range or range <= 0 then return end






        local curScroll = (scrollBox:GetScrollPercentage() or 0) * range
        local vH = scrollBox:GetHeight() or 0
        local cH = (child.GetHeight and child:GetHeight()) or 24
        local childOffset = curScroll + (vpTop - cTop)
        local desiredScroll = childOffset - (vH - cH) / 2
        local newPercent = math.max(0, math.min(1, desiredScroll / range))
        scrollBox:SetScrollPercentage(newPercent)
    end

    local function rowInView(row)
        local vpTop, vpBottom = scrollBox:GetTop(), scrollBox:GetBottom()
        local rTop, rBottom = row:GetTop(), row:GetBottom()
        if not (vpTop and vpBottom and rTop and rBottom) then return true end
        return rTop <= vpTop + 1 and rBottom >= vpBottom - 1
    end

    local function highlightRow(row)
        if row and row.IsShown and row:IsShown()
           and ns.Highlight and ns.Highlight.HighlightFrame then
            ns.Highlight:HighlightFrame(row, nil, function(t)
                return t and t:IsVisible()
            end)
        end
    end








    local function highlightWhenReady(attemptsLeft)
        local sf = scrollBox.FindFrame and scrollBox:FindFrame(section)
        if not sf then
            if attemptsLeft > 0 then
                scrollBox:ScrollToElementData(section, alignBegin)
                SafeAfter(0.1, function() highlightWhenReady(attemptsLeft - 1) end)
            end
            return
        end
        if sectionData and not sectionData.expanded and sf.Button then
            sf.Button:Click()
        end
        local row = bindingIdx and FindBindingFrameInSection(sf, bindingIdx)
        if not row then
            if attemptsLeft > 0 then
                SafeAfter(0.1, function() highlightWhenReady(attemptsLeft - 1) end)
            end
            return
        end
        if not rowInView(row) and attemptsLeft > 0 then
            ScrollSectionToChild(row)
            SafeAfter(0.05, function() highlightWhenReady(attemptsLeft - 1) end)
            return
        end
        highlightRow(row)
    end
    SafeAfter(0.05, function() highlightWhenReady(16) end)

    return true
end
BlizzOptionsSearch.ScrollToBindingAction = ScrollToBindingAction


local SETTING_EXTRA_KEYWORDS = {
    nameplateShowEnemies = {
        "enemy nameplate", "enemy nameplates", "enemy unit nameplate",
        "enemy unit nameplates", "hostile nameplate", "hostile nameplates",
    },
    nameplateShowFriends = {
        "friendly nameplate", "friendly nameplates", "friendly unit nameplate",
        "friendly unit nameplates",
    },
    nameplateShowAll = {
        "all nameplates", "always show nameplates",
    },
    PROXY_VERTICAL_SYNC = { "vsync" },
    PROXY_SSAO = { "ambient occlusion" },
    PROXY_RAID_SSAO = { "ambient occlusion", "raid ambient occlusion" },
    PROXY_PROJECTED_TEXTURES = { "projected texture" },
    PROXY_RAID_PROJECTED_TEXTURES = { "projected texture", "raid projected texture" },
}











local SETTING_NAME_FALLBACK = {
    nameplateMotion             = _G["UNIT_NAMEPLATES_TYPES"] or "Nameplate Motion Type",
    floatingCombatTextFloatMode = _G["COMBAT_TEXT_FLOAT_MODE_LABEL"] or "Combat Text Float Mode",
    nameplateShowAll           = "Always Show Nameplates",
    nameplateShowEnemies       = "Enemy Unit Nameplate",
    nameplateShowFriends       = "Friendly Unit Nameplate",
    nameplateMaxDistance       = "Nameplate Maximum Distance",
    nameplateShowCastBars      = "Nameplate Cast Bars",
    PROXY_GRAPHICS_QUALITY      = "Graphics Quality",
    PROXY_RAID_GRAPHICS_QUALITY = "Graphics Quality",
    PROXY_VIEW_DISTANCE         = "View Distance",
    PROXY_RAID_VIEW_DISTANCE    = "View Distance",
    PROXY_ENVIRONMENT_DETAIL    = "Environment Detail",
    PROXY_RAID_ENVIRONMENT_DETAIL = "Environment Detail",
    PROXY_GROUND_CLUTTER        = "Ground Clutter",
    PROXY_RAID_GROUND_CLUTTER   = "Ground Clutter",
    PROXY_SHADOW_QUALITY        = "Shadow Quality",
    PROXY_RAID_SHADOW_QUALITY   = "Shadow Quality",
    PROXY_LIQUID_DETAIL         = "Liquid Detail",
    PROXY_RAID_LIQUID_DETAIL    = "Liquid Detail",
    PROXY_PARTICLE_DENSITY      = "Particle Density",
    PROXY_RAID_PARTICLE_DENSITY = "Particle Density",
    PROXY_SSAO                  = "SSAO",
    PROXY_RAID_SSAO             = "SSAO",
    PROXY_DEPTH_EFFECTS         = "Depth Effects",
    PROXY_RAID_DEPTH_EFFECTS    = "Depth Effects",
    PROXY_COMPUTE_EFFECTS       = "Compute Effects",
    PROXY_RAID_COMPUTE_EFFECTS  = "Compute Effects",
    PROXY_OUTLINE_MODE          = "Outline Mode",
    PROXY_RAID_OUTLINE_MODE     = "Outline Mode",
    PROXY_TEXTURE_RESOLUTION    = "Texture Resolution",
    PROXY_RAID_TEXTURE_RESOLUTION = "Texture Resolution",
    PROXY_SPELL_DENSITY         = "Spell Density",
    PROXY_RAID_SPELL_DENSITY    = "Spell Density",
    PROXY_PROJECTED_TEXTURES    = "Projected Textures",
    PROXY_RAID_PROJECTED_TEXTURES = "Projected Textures",
}

local function GetRegisteredSetting(variable) return Utils.FindSetting(variable) end

local function IsLiveCVar(variable)
    if not (variable and GetCVar) then return false end
    local ok, value = pcall(GetCVar, variable)
    return ok and value ~= nil
end

local function IsCuratedFallbackSupported(variable, registryReady)



    if BASE_QUALITY_SETTINGS[variable] then return not registryReady end
    return IsLiveCVar(variable)
end








local function GetSettingDisplayName(variable, fallback)
    local setting = GetRegisteredSetting(variable)
    if setting and setting.GetName then
        local nameOk, name = pcall(setting.GetName, setting)
        if nameOk and type(name) == "string" and name ~= "" then
            return name
        end
    end
    return fallback
end

local function CollectCuratedGameEntries(resolveCategoryIDs, useApiNames)
    local entries = {}
    if resolveCategoryIDs then ResolveCategoryIDs() end





    local registryReady = false
    if resolveCategoryIDs then
        for var in pairs(categoryIDByVariable) do
            if var then registryReady = true break end
        end
    end

    for si = 1, #SETTINGS_DATA do
        local row = SETTINGS_DATA[si]
        local var, catName, typeCode = row[1], row[2], row[3]
        local sMin, sMax, sStep = row[4], row[5], row[6]
        local nameSuffix = row[7]






        local apiName = useApiNames ~= false and GetSettingDisplayName(var, nil) or nil
        local fallbackName = SETTING_NAME_FALLBACK[var]
        local fallbackSupported = fallbackName and (apiName or IsCuratedFallbackSupported(var, registryReady))
        local name = apiName or (fallbackSupported and fallbackName)
        if name and name ~= "" then
        if nameSuffix and nameSuffix ~= "" and name:sub(-#nameSuffix) ~= nameSuffix then
            name = name .. nameSuffix
        end
        local nameLower = SearchLower(name)
        local catLower = SearchLower(catName)
        local resolved = TYPE_MAP[typeCode] or "other"
        local sliderInfo = resolved == "slider" and QUALITY_SLIDER_OVERRIDES[var] or nil
        local settingFormatter
        if sliderInfo then
            sMin = sliderInfo.min or sMin
            sMax = sliderInfo.max or sMax
            sStep = sliderInfo.step or sStep
            settingFormatter = sliderInfo.formatter
        end
        if resolved == "slider" and not (sMin and sMax) then



            local live = GetSliderOptionsForVariable(var)
            if live and live.min and live.max then
                sMin = live.min
                sMax = live.max
                sStep = live.step or sStep
                settingFormatter = settingFormatter or live.formatter
            end
        end
        local settingOptions = resolved == "dropdown" and CVAR_DROPDOWN_OPTIONS[var] or nil
        local kw = { "setting", "option", "config", catLower, nameLower }
        local extraKw = SETTING_EXTRA_KEYWORDS[var]
        if extraKw then
            for ei = 1, #extraKw do kw[#kw + 1] = extraKw[ei] end
        end
        AddOptionLabelKeywords(kw, settingOptions)
        local resolvedCatID = resolveCategoryIDs and GetCategoryIDForVariable(var) or nil
        if not (registryReady and not resolvedCatID and not BASE_QUALITY_SETTINGS[var]) then
            local catID = resolvedCatID or (resolveCategoryIDs and GetCategoryID(catName)) or nil



            local displayCat = (catID and localizedNameByCategoryID[catID]) or catName
            if displayCat ~= catName then kw[#kw + 1] = SearchLower(displayCat) end
            local mt = GetSettingsCatMT("Game Settings", catName, catID,
                { "Game Settings", displayCat })
            tinsert(entries, setmetatable({
                name = name,
                nameLower = nameLower,
                keywords = kw,
                settingVariable = var,
                settingType = resolved,
                settingMin = sMin,
                settingMax = sMax,
                settingStep = sStep,
                settingFormatter = settingFormatter,
                settingOptions = settingOptions,
                steps = {
                    {
                        settingsCategory = catName,
                        settingCategoryID = catID,
                        settingVariable = var,
                    },
                },
            }, mt))
        end
        end
        MaybeYieldLiveSettings()
    end

    return entries
end

local function AppendEntries(dst, src)
    for i = 1, #src do dst[#dst + 1] = src[i] end
end

local function CollectEntries(includeCurated)
    local entries = {}

    if includeCurated ~= false then
        AppendEntries(entries, CollectCuratedGameEntries(true))
    end

    local list = GetSettingsCategoryList()
    if type(list) ~= "table" then return entries end

    local function addCategoryEntry(cat, parentName)
        if not cat or not cat.GetName then return end
        local catName = cat:GetName()
        local catID = cat.GetID and cat:GetID()
        if not catName or catName == "" then return end
        local catNameLower = SearchLower(catName)
        local kw = { "settings", "options", catNameLower }
        AddKeyword(kw, parentName)
        local pathArr = parentName and { "Game Settings", parentName } or nil
        local mt = GetSettingsCatMT("Game Settings", catName, catID, pathArr)
        tinsert(entries, setmetatable({
            name = catName,
            nameLower = catNameLower,
            keywords = kw,
            steps = { { settingsCategory = catName, settingCategoryID = catID } },
        }, mt))
    end

    for _, cat in ipairs(list) do
        addCategoryEntry(cat)
        MaybeYieldLiveSettings()
        if cat.GetSubcategories then
            local sok, subs = pcall(cat.GetSubcategories, cat)
            if sok and type(subs) == "table" then
                local parentName = cat.GetName and cat:GetName()
                for _, sub in ipairs(subs) do
                    addCategoryEntry(sub, parentName)
                    MaybeYieldLiveSettings()
                end
            end
        end
    end

    return entries
end




local function IsActionBarButtonBinding(action)
    return action:find("^ACTIONBUTTON%d+$") ~= nil
        or action:find("^MULTIACTIONBAR%d+BUTTON%d+$") ~= nil
        or action:find("^BONUSACTIONBUTTON%d+$") ~= nil
end






local function ResolveBindingHeader(category, action)
    if type(category) == "string" and category ~= "" then
        local v = _G[category]
        if type(v) == "string" and v ~= "" then return v end
        v = _G["BINDING_HEADER_" .. category]
        if type(v) == "string" and v ~= "" then return v end
    end
    if type(action) == "string" and action:find("^HEADER_") then
        local v = _G["BINDING_HEADER_" .. action:sub(8)]
        if type(v) == "string" and v ~= "" then return v end
    end
    return nil
end
















local CVarSwitch = {}
function CVarSwitch.Getter(cvar)
    return function() return GetCVar and GetCVar(cvar) == "1" end
end




function CVarSwitch.Toggler(cvar)
    return function()
        local setting = Utils.FindSetting(cvar)
        if setting then
            setting:SetValue(not setting:GetValue())
        elseif SetCVar and GetCVar then
            SetCVar(cvar, GetCVar(cvar) == "1" and "0" or "1")
        else
            return false
        end
        return true
    end
end




function CVarSwitch.SoundGetter(cvar)
    return function()
        return GetCVar and GetCVar("Sound_EnableAllSound") == "1" and GetCVar(cvar) == "1"
    end
end

function CVarSwitch.SoundToggler(cvar, toggleName)
    return function()
        local toggle = _G[toggleName]
        if not (toggle and GetCVar and SetCVar) then return end
        if GetCVar("Sound_EnableAllSound") == "0" then
            SetCVar("Sound_EnableAllSound", 1)
            if GetCVar(cvar) == "1" then return true end
        end
        toggle()
        return true
    end
end

local TOGGLE_BINDING_STATE = {
    TOGGLEMINIMAP = {

        get = function() return Minimap and Minimap:IsShown() end,
        run = function()
            if ToggleMinimap then
                ToggleMinimap()
                return true
            end
        end,
    },
    TOGGLEMUSIC = {
        get = CVarSwitch.SoundGetter("Sound_EnableMusic"),
        run = CVarSwitch.SoundToggler("Sound_EnableMusic", "Sound_ToggleMusic"),
    },

    TOGGLESOUND = {
        get = CVarSwitch.SoundGetter("Sound_EnableSFX"),
        run = CVarSwitch.SoundToggler("Sound_EnableSFX", "Sound_ToggleSound"),
    },
    TOGGLEACTIONBARLOCK = {
        get = CVarSwitch.Getter("lockActionBars"),
        run = CVarSwitch.Toggler("lockActionBars"),
    },


    TOGGLEAUTOSELFCAST = {
        get = CVarSwitch.Getter("autoSelfCast"),
        run = CVarSwitch.Toggler("autoSelfCast"),
    },
    TOGGLE_VOICE_SELF_MUTE = {
        get = function() return C_VoiceChat and C_VoiceChat.IsMuted and C_VoiceChat.IsMuted() end,
        run = function()
            if VoiceChat_ToggleMutedFromUserAction then
                VoiceChat_ToggleMutedFromUserAction()
                return true
            end
            if C_VoiceChat and C_VoiceChat.ToggleMuted then
                C_VoiceChat.ToggleMuted()
                return true
            end
        end,
    },
    TOGGLE_VOICE_SELF_DEAFEN = {
        get = function() return C_VoiceChat and C_VoiceChat.IsDeafened and C_VoiceChat.IsDeafened() end,
        run = function()
            if VoiceChat_ToggleDeafenedFromUserAction then
                VoiceChat_ToggleDeafenedFromUserAction()
                return true
            end
            if C_VoiceChat and C_VoiceChat.ToggleDeafened then
                C_VoiceChat.ToggleDeafened()
                return true
            end
        end,
    },



    EASYFIND_TOGGLECHATFRAME = {
        get = function()
            local chatFrame = _G["ChatFrame1"]
            return chatFrame and chatFrame:IsShown()
        end,
        run = function()
            if EasyFind and EasyFind.ToggleChatFrames then
                EasyFind:ToggleChatFrames()
                return true
            end
        end,
    },


    EASYFIND_TOGGLEOBJECTIVETRACKER = {
        get = function()
            return not (EasyFind and EasyFind.db and EasyFind.db.objectiveTrackerHidden)
        end,
        run = function()
            if EasyFind and EasyFind.ToggleObjectiveTracker then
                EasyFind:ToggleObjectiveTracker()
                return true
            end
        end,
    },
    TOGGLEWORLDMAP = {
        get = function() return WorldMapFrame and WorldMapFrame:IsShown() end,
        run = function()
            if WorldMapFrame and WorldMapFrame:IsShown() and ToggleWorldMap then
                ToggleWorldMap()
                return true
            end
            if ns.MapSearch and ns.MapSearch.OpenMap and ns.MapSearch.OpenMap() then return true end

            local button = _G["WorldMapMicroButton"]
            if button then return Utils.ClickButton(button) and true or false end
        end,
    },


    TOGGLEFPS = {
        get = function()
            local framerateFrame = _G["FramerateFrame"]
            if framerateFrame and framerateFrame.Toggle then return framerateFrame:IsShown() end
            local text = _G["FramerateText"]
            return text and text:IsShown()
        end,
        run = function()
            local framerateFrame = _G["FramerateFrame"]
            if framerateFrame and framerateFrame.Toggle then
                framerateFrame:Toggle()
                return true
            end
            local toggle = _G["ToggleFramerate"]
            if toggle then
                toggle()
                return true
            end
        end,
    },
    TOGGLEBATTLEFIELDMINIMAP = {
        get = function() return BattlefieldMapFrame and BattlefieldMapFrame:IsShown() end,
        run = function()
            if ToggleBattlefieldMap then
                ToggleBattlefieldMap()
                return true
            end
        end,
    },
}

local function BagToggler(bagSlot)
    return function()
        if ToggleBag then
            ToggleBag(bagSlot)
            return true
        end
    end
end

local function CharPaneToggler(paneName)
    return function()
        if ToggleCharacter then
            ToggleCharacter(paneName)
            return true
        end
    end
end

local function CollectionsToggler(tabConstName, fallbackTab)
    return function()
        if ToggleCollectionsJournal then
            ToggleCollectionsJournal(_G[tabConstName] or fallbackTab)
            return true
        end
    end
end






local function FriendsToggler(tabConstName)
    local friendsTab = _G[tabConstName]
    if not friendsTab then return nil end
    return function()
        if ToggleFriendsFrame then
            ToggleFriendsFrame(friendsTab)
            return true
        end
    end
end



local function OrReplaced(name, perform)
    if not perform then return nil end
    return function()
        local openers = ns.SearchOpeners
        local api = openers and openers.Replacement and openers.Replacement(name)
        if not api then return perform() end
        local ok, opened = pcall(api.Open, name)
        return (ok and opened) and true or false
    end
end

local PERFORM_ONLY_BINDINGS = {
    TOGGLEBACKPACK = function()
        if ToggleBackpack then
            ToggleBackpack()
            return true
        end
    end,
    TOGGLEBAG1 = BagToggler(1),
    TOGGLEBAG2 = BagToggler(2),
    TOGGLEBAG3 = BagToggler(3),
    TOGGLEBAG4 = BagToggler(4),
    TOGGLEREAGENTBAG1 = BagToggler(Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or 5),
    OPENALLBAGS = function()
        if ToggleAllBags then
            ToggleAllBags()
            return true
        end
    end,
    TOGGLESHEATH = function()
        if ToggleSheath then
            ToggleSheath()
            return true
        end
    end,
    TOGGLECHARACTER0 = CharPaneToggler("PaperDollFrame"),
    TOGGLECHARACTER2 = CharPaneToggler("ReputationFrame"),
    TOGGLECURRENCY = function()
        local charFrame = _G["CharacterFrame"]
        if charFrame and charFrame.ToggleTokenFrame then
            charFrame:ToggleTokenFrame()
            return true
        end
    end,
    TOGGLECHARACTER4 = function()
        if TogglePVPUI then
            TogglePVPUI()
            return true
        end
    end,
    TOGGLEACHIEVEMENT = function()
        if ToggleAchievementFrame then
            ToggleAchievementFrame()
            return true
        end
    end,
    TOGGLESTATISTICS = function()
        if ToggleAchievementFrame then
            ToggleAchievementFrame(1)
            return true
        end
    end,
    TOGGLEQUESTLOG = OrReplaced("questLog", function()
        if ToggleQuestLog then
            ToggleQuestLog()
            return true
        end
    end),
    TOGGLESOCIAL = function()
        if ToggleFriendsFrame then
            ToggleFriendsFrame()
            return true
        end
    end,
    TOGGLEFRIENDSTAB = FriendsToggler("FRIEND_TAB_FRIENDS"),
    TOGGLEWHOTAB = OrReplaced("whoList", FriendsToggler("FRIEND_TAB_WHO")),
    TOGGLECHATTAB = function()
        if ToggleChannelFrame then
            ToggleChannelFrame()
            return true
        end
    end,
    TOGGLEQUICKJOINTAB = function()
        if ToggleQuickJoinPanel then
            ToggleQuickJoinPanel()
            return true
        end
    end,
    TOGGLERAIDTAB = function()
        if ToggleRaidFrame then
            ToggleRaidFrame()
            return true
        end
    end,
    TOGGLEGUILDTAB = OrReplaced("guildRoster", function()
        if ToggleGuildFrame then
            ToggleGuildFrame()
            return true
        end
    end),
    TOGGLEGROUPFINDER = function()
        if PVEFrame_ToggleFrame then
            PVEFrame_ToggleFrame()
            return true
        end
    end,
    TOGGLEDUNGEONSANDRAIDS = function()
        if PVEFrame_ToggleFrame then
            PVEFrame_ToggleFrame("GroupFinderFrame")
            return true
        end
    end,
    TOGGLECOLLECTIONS = function()
        if ToggleCollectionsJournal then
            ToggleCollectionsJournal()
            return true
        end
    end,
    TOGGLECOLLECTIONSMOUNTJOURNAL = CollectionsToggler("COLLECTIONS_JOURNAL_TAB_INDEX_MOUNTS", 1),
    TOGGLECOLLECTIONSPETJOURNAL = CollectionsToggler("COLLECTIONS_JOURNAL_TAB_INDEX_PETS", 2),
    TOGGLECOLLECTIONSTOYBOX = CollectionsToggler("COLLECTIONS_JOURNAL_TAB_INDEX_TOYS", 3),
    TOGGLECOLLECTIONSHEIRLOOM = CollectionsToggler("COLLECTIONS_JOURNAL_TAB_INDEX_HEIRLOOMS", 4),
    TOGGLECOLLECTIONSWARDROBE = CollectionsToggler("COLLECTIONS_JOURNAL_TAB_INDEX_APPEARANCES", 5),
    TOGGLEENCOUNTERJOURNAL = function()
        if ToggleEncounterJournal then
            ToggleEncounterJournal()
            return true
        end
    end,
    TOGGLEGARRISONLANDINGPAGE = function()
        local landingBtn = _G["ExpansionLandingPageMinimapButton"]
        if landingBtn and landingBtn.IsShown and landingBtn:IsShown() and landingBtn.ToggleLandingPage then
            landingBtn:ToggleLandingPage()
            return true
        end
    end,
    TOGGLEHOUSINGDASHBOARD = function()
        if HousingFramesUtil and HousingFramesUtil.ToggleHousingDashboard then
            HousingFramesUtil.ToggleHousingDashboard()
            return true
        end
    end,
}




for action, button in pairs({ TOGGLESPELLBOOK = "SpellbookMicroButton", TOGGLETALENTS = "TalentMicroButton" }) do
    if ns.Caps and ns.Caps.classic and _G[button] then
        PERFORM_ONLY_BINDINGS[action] = function()
            local openers = ns.SearchOpeners
            return openers and openers.OpenButtonFrame and openers:OpenButtonFrame(button) and true or false
        end
    end
end



local TOGGLE_BINDING_KEYWORDS = {
    TOGGLEMINIMAP = { "minimap", "mini map", "tracking", "navigation" },
    TOGGLEWORLDMAP = { "map", "world map", "navigation" },
    TOGGLEBATTLEFIELDMINIMAP = { "zone map", "battlefield map", "floating map", "area map", "navigation" },
    TOGGLEMUSIC = { "music", "audio" },
    TOGGLESOUND = { "sound", "audio", "mute" },
    TOGGLESOCIAL = { "friends", "friends list", "social", "bnet", "battlenet", "contacts", "whisper", "online" },
}





function BlizzOptionsSearch:GetToggleBindingState(action)
    local entry = action and TOGGLE_BINDING_STATE[action]
    if not entry then return nil end
    local ok, isOn = pcall(entry.get)
    if not ok then return nil end
    return isOn and true or false
end

function BlizzOptionsSearch:IsPerformableBinding(action)
    if not action then return false end
    return TOGGLE_BINDING_STATE[action] ~= nil or PERFORM_ONLY_BINDINGS[action] ~= nil
end

function BlizzOptionsSearch:PerformBinding(action)
    if not action then return false end
    local entry = TOGGLE_BINDING_STATE[action]
    local run = entry and entry.run or PERFORM_ONLY_BINDINGS[action]
    if not run then return false end
    local ok, ran = xpcall(run, Utils.ErrorHandler)
    return ok and ran == true
end

local function CollectKeybindings()
    local entries = {}




    do
        local qkbName = Loc["KEYBIND_TOGGLE_FMT"]:format(_G["QUICK_KEYBIND_MODE"] or "Quick Keybind Mode")
        tinsert(entries, setmetatable({
            name = qkbName,
            nameLower = SearchLower(qkbName),
            keywords = { "quick keybind mode", "quick", "keybind", "binding", "hover bind" },
            quickKeybindActivate = true,
            steps = { { settingsCategory = "Keybindings" } },
        }, GetSettingsCatMT("Game Settings", "Keybindings", nil, { "Game Settings", "Keybindings" })))
    end






    do
        local chatToggleName = Loc["KEYBIND_TOGGLE_FMT"]:format(_G["HUD_EDIT_MODE_CHAT_FRAME_LABEL"] or "Chat Frame")
        tinsert(entries, setmetatable({
            name = chatToggleName,
            nameLower = SearchLower(chatToggleName),
            keywords = { "chat", "chat frame", "chat window", "hide chat", "show chat", "toggle" },
            settingType = "keybind",
            bindingAction = "EASYFIND_TOGGLECHATFRAME",
            customToggle = true,
        }, GetSettingsCatMT("Game Settings", "Keybindings", nil, { "Game Settings", "Keybindings" })))
    end



    do
        local trackerToggleName = Loc["KEYBIND_TOGGLE_FMT"]:format(_G["HUD_EDIT_MODE_OBJECTIVE_TRACKER_LABEL"] or Loc["GPS_STYLE_TRACKER"])
        tinsert(entries, setmetatable({
            name = trackerToggleName,
            nameLower = SearchLower(trackerToggleName),
            keywords = { "objective", "objectives", "tracker", "quest tracker", "quest watch", "hide quests", "toggle" },
            settingType = "keybind",
            bindingAction = "EASYFIND_TOGGLEOBJECTIVETRACKER",
            customToggle = true,
        }, GetSettingsCatMT("Game Settings", "Keybindings", nil, { "Game Settings", "Keybindings" })))
    end

    if not GetNumBindings or not GetBinding then return entries end
    local n = GetNumBindings()
    if not n or n == 0 then return entries end

    local currentHeader = "Other"
    for i = 1, n do
        MaybeYieldLiveSettings()
        local action, category = GetBinding(i)
        if action and (action == "HEADER_BLANK" or action:find("^HEADER_")) then
            local resolved = ResolveBindingHeader(category, action)
            if resolved then
                currentHeader = resolved
            elseif type(category) == "string" and category ~= "" then
                currentHeader = category
            end
        elseif action and action ~= "" and not IsActionBarButtonBinding(action) then





            local header = ResolveBindingHeader(category, action) or currentHeader
            local nameKey = "BINDING_NAME_" .. action
            local displayName = _G[nameKey]
            if type(displayName) ~= "string" or displayName == "" then
                displayName = action
            end
            local nameLower = SearchLower(displayName)




            local kw = { "keybind", "binding", nameLower, SearchLower(header) }
            local extraKw = TOGGLE_BINDING_KEYWORDS[action]
            if extraKw then
                for j = 1, #extraKw do
                    tinsert(kw, extraKw[j])
                end
            end
            local mt = GetSettingsCatMT("Game Settings", "Keybindings", nil,
                { "Game Settings", "Keybindings", header })
            tinsert(entries, setmetatable({
                name = displayName,
                nameLower = nameLower,
                keywords = kw,
                settingType = "keybind",
                bindingAction = action,
                steps = {
                    {
                        settingsCategory = "Keybindings",
                        bindingAction = action,
                        bindingHeader = header,
                    },
                },
            }, mt))
        end
    end
    return entries
end
BlizzOptionsSearch.CollectKeybindings = CollectKeybindings

local function WalkCategorySettings(cat, catName, catID, pathPrefix, entryCategory)
    entryCategory = entryCategory or "AddOn Settings"
    local catMT = GetSettingsCatMT(entryCategory, catName, catID, pathPrefix)
    local out = {}
    if not (cat and SettingsPanel and SettingsPanel.GetLayout) then
        return out
    end
    local lok, layout = pcall(SettingsPanel.GetLayout, SettingsPanel, cat)
    if not lok or not layout or not layout.GetInitializers then return out end
    local iok, inits = pcall(layout.GetInitializers, layout)
    if not iok or not inits then return out end








    local function inspectInit(init)
        local d = init.data
        if type(d) == "table" and d.cbSetting and d.sliderSetting then
            return { combined = true, init = init }
        end
        if type(d) == "table" and d.cbSetting and d.dropdownSetting then
            return { combinedDropdown = true, init = init }
        end
        if type(d) == "table" and (d.settings or d.raidSettings) then
            return { container = true, init = init }
        end
        local setting
        if init.GetSetting then
            local sok, s = pcall(init.GetSetting, init)
            if sok then setting = s end
        end
        if not setting and d then setting = d.setting end
        if not setting and init.GetData then
            local dok, dd = pcall(init.GetData, init)
            if dok and dd then setting = dd.setting end
        end
        return { setting = setting, init = init }
    end

    for _, init in ipairs(inits) do
      MaybeYieldLiveSettings()
      local info = inspectInit(init)
      if info.combined then
        local d = init.data
        local cb, sl = d.cbSetting, d.sliderSetting
        local cvok, cvar = pcall(cb.GetVariable, cb)
        local svok, svar = pcall(sl.GetVariable, sl)
        local label = d.cbLabel or d.sliderLabel
        if cvok and svok and cvar and svar and label and label ~= "" then
            local opts = d.sliderOptions
            if type(opts) == "function" then
                local ook, o = pcall(opts, sl)
                if ook then opts = o end
            end
            local sMin, sMax, sStep, sFmt
            if type(opts) == "table" then
                sMin = opts.minValue
                sMax = opts.maxValue

                if opts.stepSize then
                    sStep = opts.stepSize
                elseif opts.steps and opts.steps > 0 and sMax > sMin then
                    sStep = (sMax - sMin) / opts.steps
                else
                    sStep = 1
                end
                if type(opts.formatters) == "table" then
                    sFmt = opts.formatters[2] or opts.formatters[1]
                        or opts.formatters[0] or opts.formatters.Top
                        or opts.formatters.Right
                    if type(sFmt) ~= "function" then
                        sFmt = nil
                        for _, fn in pairs(opts.formatters) do
                            if type(fn) == "function" then sFmt = fn; break end
                        end
                    end
                end
            end
            local nameLower = SearchLower(label)
            local kw = { "addon", "setting", "option", nameLower, SearchLower(catName or "") }
            tinsert(out, setmetatable({
                name = label,
                nameLower = nameLower,
                keywords = kw,
                settingVariable = cvar,
                cbVariable = cvar,
                sliderVariable = svar,
                settingType = "checkboxSlider",
                settingMin = sMin,
                settingMax = sMax,
                settingStep = sStep,
                settingFormatter = sFmt,
                steps = {
                    { settingsCategory = catName, settingCategoryID = catID,
                      settingVariable = cvar },
                },
            }, catMT))
        end
      elseif info.combinedDropdown then



        local d = init.data
        local cb, dd = d.cbSetting, d.dropdownSetting
        local cvok, cvar = pcall(cb.GetVariable, cb)
        local dvok, dvar = pcall(dd.GetVariable, dd)
        local label = d.cbLabel or d.name
        if cvok and dvok and cvar and dvar and label and label ~= "" then
            local settingOptions = GetInitializerOptions(init, dd)
            local nameLower = SearchLower(label)
            local kw = { "setting", "option", "config", nameLower, SearchLower(catName or "") }
            AddOptionLabelKeywords(kw, settingOptions)
            tinsert(out, setmetatable({
                name = label,
                nameLower = nameLower,
                keywords = kw,
                settingVariable = cvar,
                cbVariable = cvar,
                dropdownVariable = dvar,
                settingType = "checkboxDropdown",
                settingOptions = settingOptions,
                steps = {
                    { settingsCategory = catName, settingCategoryID = catID,
                      settingVariable = cvar },
                },
            }, catMT))
        end
      elseif info.container then








        local d = init.data
        local function emitContainerSlider(setting, isRaid)
            if not (setting and setting.GetVariable and setting.GetName) then return end
            local vok, variable = pcall(setting.GetVariable, setting)
            if not (vok and variable) then return end
            local sliderInfo = QUALITY_SLIDER_OVERRIDES[variable]
            if not sliderInfo then return end
            local nok, settingName = pcall(setting.GetName, setting)
            if not (nok and settingName and settingName ~= "") then return end
            local displayName = settingName
            if isRaid then displayName = settingName .. " (" .. (_G["RAID"] or "Raid") .. ")" end
            local nameLower = SearchLower(displayName)
            local kw = { "setting", "option", "config", nameLower, SearchLower(catName or "") }
            tinsert(out, setmetatable({
                name = displayName,
                nameLower = nameLower,
                keywords = kw,
                settingVariable = variable,
                settingType = "slider",
                settingMin = sliderInfo.min,
                settingMax = sliderInfo.max,
                settingStep = sliderInfo.step,
                settingFormatter = sliderInfo.formatter,
                steps = {
                    { settingsCategory = catName, settingCategoryID = catID,
                      settingVariable = variable },
                },
            }, catMT))
        end
        if d.settings then
            for _, setting in pairs(d.settings) do
                emitContainerSlider(setting, false)
                MaybeYieldLiveSettings()
            end
        end
        if d.raidSettings then
            for _, setting in pairs(d.raidSettings) do
                emitContainerSlider(setting, true)
                MaybeYieldLiveSettings()
            end
        end
      else
        local setting = info.setting
        if setting and setting.GetVariable then
            local vok, variable = pcall(setting.GetVariable, setting)
            local nok, settingName = pcall(setting.GetName, setting)
            if vok and variable and nok and settingName and settingName ~= "" then
                local resolvedType, sMin, sMax, sStep, sFmt
                local d = init.data
                local opts = (type(d) == "table") and d.options or nil
                if type(opts) == "function" then
                    local ook, o = pcall(opts, setting)
                    if not ook then
                        ook, o = pcall(opts)
                    end
                    if ook then opts = o end
                end
                if type(opts) == "table" and opts.minValue and opts.maxValue then
                    resolvedType = "slider"
                    sMin = opts.minValue
                    sMax = opts.maxValue

                if opts.stepSize then
                    sStep = opts.stepSize
                elseif opts.steps and opts.steps > 0 and sMax > sMin then
                    sStep = (sMax - sMin) / opts.steps
                else
                    sStep = 1
                end


                    if type(opts.formatters) == "table" then
                        sFmt = opts.formatters[2] or opts.formatters[1]
                            or opts.formatters[0] or opts.formatters.Top
                            or opts.formatters.Right
                        if type(sFmt) ~= "function" then
                            sFmt = nil
                            for _, fn in pairs(opts.formatters) do
                                if type(fn) == "function" then sFmt = fn; break end
                            end
                        end
                    end
                elseif setting.GetVariableType then
                    local tok, vtype = pcall(setting.GetVariableType, setting)
                    if tok and vtype == "boolean" then
                        resolvedType = "checkbox"
                    end
                end
                if not resolvedType then resolvedType = "dropdown" end

                local settingOptions
                if resolvedType == "dropdown" then
                    settingOptions = GetInitializerOptions(init, setting)
                end

                local nameLower = SearchLower(settingName)
                local kw = {
                    "addon", "setting", "option",
                    nameLower, SearchLower(catName or ""),
                }
                AddOptionLabelKeywords(kw, settingOptions)
                tinsert(out, setmetatable({
                    name = settingName,
                    nameLower = nameLower,
                    keywords = kw,
                    settingVariable = variable,
                    settingType = resolvedType,
                    settingMin = sMin,
                    settingMax = sMax,
                    settingStep = sStep,
                    settingFormatter = sFmt,
                    settingOptions = settingOptions,
                    steps = {
                        {
                            settingsCategory = catName,
                            settingCategoryID = catID,
                            settingVariable = variable,
                        },
                    },
                }, catMT))
            end
        end
      end
    end
    return out
end

local function IsAddonCategory(cat)
    if not cat then return false end
    local addonSet = Settings and Settings.CategorySet and Settings.CategorySet.AddOns
    local set
    if cat.GetCategorySet then
        local ok, s = pcall(cat.GetCategorySet, cat)
        if ok then set = s end
    end
    if set == nil then set = cat.categorySet end
    if set == nil then return false end
    if addonSet ~= nil then return set == addonSet end
    return set == "AddOns" or set == 2
end

local function CollectAddonCategories()
    local entries = {}
    if not Settings then return entries end

    local seenCatIDs = {}
    local function emit(cat, parentName)
        if not cat or not cat.GetName then return end
        if not IsAddonCategory(cat) then return end
        local catID = cat.GetID and cat:GetID()
        if not catID or seenCatIDs[catID] then return end
        seenCatIDs[catID] = true
        local catName = cat:GetName()
        if not catName or catName == "" then return end
        local catNameLower = SearchLower(catName)
        local rootName = (parentName or catName) .. " " .. (_G["SETTINGS"] or "Settings")
        local pathPrefix = parentName and { rootName, catName } or { rootName }

        local kw = { "addon", "settings", "options", catNameLower }
        AddKeyword(kw, parentName)
        local mt = GetSettingsCatMT("AddOn Settings", catName, catID,
            parentName and { rootName } or nil)

        local addon = parentName or catName
        tinsert(entries, setmetatable({
            name = catName,
            nameLower = catNameLower,
            keywords = kw,
            steps = { { settingsCategory = catName, settingCategoryID = catID } },
            addon = addon,
        }, mt))

        local inline = WalkCategorySettings(cat, catName, catID, pathPrefix, "AddOn Settings")
        for _, e in ipairs(inline) do
            e.addon = addon
            tinsert(entries, e)
        end
    end

    local gotTyped = false
    if Settings.CategorySet and Settings.GetCategoryList then
        local ok, list = pcall(Settings.GetCategoryList, Settings.CategorySet.AddOns)
        if ok and type(list) == "table" then
            gotTyped = true
            for _, cat in ipairs(list) do
                emit(cat, nil)
                MaybeYieldLiveSettings()
                if cat.GetSubcategories then
                    local sok, subs = pcall(cat.GetSubcategories, cat)
                    if sok and type(subs) == "table" then
                        local parentName = cat.GetName and cat:GetName()
                        for _, sub in ipairs(subs) do
                            emit(sub, parentName)
                            MaybeYieldLiveSettings()
                        end
                    end
                end
            end
        end
    end

    if not gotTyped and SettingsPanel and SettingsPanel.GetAllCategories then
        local ok, all = pcall(SettingsPanel.GetAllCategories, SettingsPanel)
        if ok and type(all) == "table" then
            for _, cat in ipairs(all) do
                emit(cat, nil)
                MaybeYieldLiveSettings()
                if cat.GetSubcategories then
                    local sok, subs = pcall(cat.GetSubcategories, cat)
                    if sok and type(subs) == "table" then
                        local parentName = cat.GetName and cat:GetName()
                        for _, sub in ipairs(subs) do
                            emit(sub, parentName)
                            MaybeYieldLiveSettings()
                        end
                    end
                end
            end
        end
    end

    return entries
end
BlizzOptionsSearch.CollectAddonCategories = CollectAddonCategories




local function MakeQualityOpts(cvar, raid, optionDefs)
    return { cvar = cvar, raid = raid, optionDefs = optionDefs }
end
local function L(name, fallback)
    local v = _G[name]
    if type(v) == "string" and v ~= "" then return v end
    return fallback
end
local QUALITY_LIKE_5 = {
    { 0, "VIDEO_OPTIONS_LOW", "Low" },
    { 1, "VIDEO_OPTIONS_FAIR", "Fair" },
    { 2, "VIDEO_OPTIONS_MEDIUM", "Medium" },
    { 3, "VIDEO_OPTIONS_HIGH", "High" },
    { 4, "VIDEO_OPTIONS_ULTRA", "Ultra" },
    { 5, "VIDEO_OPTIONS_ULTRA_HIGH", "Ultra High" },
}
local QUALITY_LIKE_4 = {
    { 0, "VIDEO_OPTIONS_LOW", "Low" },
    { 1, "VIDEO_OPTIONS_FAIR", "Fair" },
    { 2, "VIDEO_OPTIONS_MEDIUM", "Medium" },
    { 3, "VIDEO_OPTIONS_HIGH", "High" },
}
local HARDCODED_OPTIONS = {
    PROXY_SHADOW_QUALITY        = MakeQualityOpts("graphicsShadowQuality", false, QUALITY_LIKE_5),
    PROXY_RAID_SHADOW_QUALITY   = MakeQualityOpts("raidGraphicsShadowQuality", true, QUALITY_LIKE_5),
    PROXY_LIQUID_DETAIL         = MakeQualityOpts("graphicsLiquidDetail", false, QUALITY_LIKE_4),
    PROXY_RAID_LIQUID_DETAIL    = MakeQualityOpts("raidGraphicsLiquidDetail", true, QUALITY_LIKE_4),
    PROXY_PARTICLE_DENSITY      = MakeQualityOpts("graphicsParticleDensity", false, QUALITY_LIKE_5),
    PROXY_RAID_PARTICLE_DENSITY = MakeQualityOpts("raidGraphicsParticleDensity", true, QUALITY_LIKE_5),
}

local function BuildQualityOptions(spec)
    if not spec then return nil end
    local out = {}
    for _, def in ipairs(spec.optionDefs) do
        local value, labelGlobal, fallback = def[1], def[2], def[3]
        local supported = true
        if IsGraphicsSettingValueSupported and spec.cvar then
            local ok, err = pcall(IsGraphicsSettingValueSupported, spec.cvar, value, spec.raid)
            if ok then supported = (err == nil or err == 0) end
        end
        if supported then
            tinsert(out, { value = value, label = L(labelGlobal, fallback) })
        end
    end
    if #out == 0 then return nil end
    return out
end

local function CollectGameSettings()
    local entries = {}
    if not Settings then return entries end
    local emittedVars = {}
    if ns.Database and ns.Database.uiSearchData then
        for i = 1, #ns.Database.uiSearchData do
            local e = ns.Database.uiSearchData[i]
            if e and e.settingVariable then
                emittedVars[e.settingVariable] = true
            end
        end
    end
    local seenCatIDs = {}



    local emittedNameKeys = {}
    local function nameKey(catName, displayName)
        return (catName or "") .. "\31" .. (displayName or "")
    end






    for i = 1, #SETTINGS_DATA do
        local row = SETTINGS_DATA[i]
        local var, catName = row[1], row[2]
        if var and catName then
            local apiName = GetSettingDisplayName(var, nil)
                or SETTING_NAME_FALLBACK[var]
            if apiName then
                emittedNameKeys[nameKey(catName, apiName)] = true
            end
        end
        MaybeYieldLiveSettings()
    end
    local function emit(cat, parentName)
        if not cat or not cat.GetName then return end
        if IsAddonCategory(cat) then return end
        local catID = cat.GetID and cat:GetID()
        if not catID or seenCatIDs[catID] then return end
        seenCatIDs[catID] = true
        local catName = cat:GetName()
        if not catName or catName == "" then return end
        local pathPrefix = { "Game Settings", catName }
        local inline = WalkCategorySettings(cat, catName, catID, pathPrefix, "Game Settings")
        for _, e in ipairs(inline) do
            if not emittedVars[e.settingVariable]
               and not emittedNameKeys[nameKey(catName, e.name)] then
                tinsert(entries, e)
                emittedVars[e.settingVariable] = true


                if e.sliderVariable then emittedVars[e.sliderVariable] = true end
                if e.dropdownVariable then emittedVars[e.dropdownVariable] = true end
                emittedNameKeys[nameKey(catName, e.name)] = true
            end
        end
    end
    local list = GetSettingsCategoryList()
    if type(list) == "table" then
        for _, cat in ipairs(list) do
            emit(cat, nil)
            MaybeYieldLiveSettings()
            if cat.GetSubcategories then
                local sok, subs = pcall(cat.GetSubcategories, cat)
                if sok and type(subs) == "table" then
                    local parentName = cat.GetName and cat:GetName()
                    for _, sub in ipairs(subs) do
                        emit(sub, parentName)
                        MaybeYieldLiveSettings()
                    end
                end
            end
        end
    end



    if SettingsPanel and SettingsPanel.settings then
        for setting, cat in pairs(SettingsPanel.settings) do
            MaybeYieldLiveSettings()
            if cat and not IsAddonCategory(cat) and setting.GetVariable then
                local vok, variable = pcall(setting.GetVariable, setting)
                if vok and variable and not emittedVars[variable] then
                    local nok, settingName = pcall(setting.GetName, setting)
                    if nok and settingName and settingName ~= "" then


                        local displayName = settingName
                        local lowerVar = slower(variable)
                        if lowerVar:find("raid", 1, true) then
                            displayName = settingName .. " (" .. (_G["RAID"] or "Raid") .. ")"
                        end
                        local catName = cat.GetName and cat:GetName() or "Game Settings"



                        if emittedNameKeys[nameKey(catName, displayName)] then
                            emittedVars[variable] = true
                        else
                        local catID = cat.GetID and cat:GetID()
                        local nameLower = SearchLower(displayName)
                        local kw = { "setting", "option", "config", nameLower, SearchLower(catName) }




                        local resolvedType, settingOptions
                        local sMin, sMax, sStep, sFmt
                        local slider = QUALITY_SLIDER_OVERRIDES[variable]
                        if slider then
                            resolvedType = "slider"
                            sMin, sMax, sStep = slider.min, slider.max, slider.step
                            sFmt = slider.formatter
                        else
                            local qspec = HARDCODED_OPTIONS[variable]
                            if qspec then
                                settingOptions = BuildQualityOptions(qspec)
                                if settingOptions then resolvedType = "dropdown" end
                            elseif setting.GetVariableType then
                                local tok, vt = pcall(setting.GetVariableType, setting)
                                if tok and vt == "boolean" then resolvedType = "checkbox" end
                            end
                        end
                        if resolvedType == "dropdown" and not settingOptions then
                            settingOptions = GetOptionsForVariable(variable)
                        end
                        AddOptionLabelKeywords(kw, settingOptions)
                        local mt = GetSettingsCatMT("Game Settings", catName, catID,
                            { "Game Settings", catName })
                        tinsert(entries, setmetatable({
                            name = displayName,
                            nameLower = nameLower,
                            keywords = kw,
                            settingVariable = variable,
                            settingType = resolvedType,
                            settingOptions = settingOptions,
                            settingMin = sMin,
                            settingMax = sMax,
                            settingStep = sStep,
                            settingFormatter = sFmt,
                            steps = {
                                { settingsCategory = catName, settingCategoryID = catID,
                                  settingVariable = variable },
                            },
                        }, mt))
                        emittedVars[variable] = true
                        emittedNameKeys[nameKey(catName, displayName)] = true
                        end
                    end
                end
            end
        end
    end
    return entries
end
BlizzOptionsSearch.CollectGameSettings = CollectGameSettings

local OPTIONS_POPULATE_BUDGET_MS = 1.5


local OPTIONS_POPULATE_URGENT_BUDGET_MS = 8
local function OptionsBudget()
    return optionsPopulateUrgent and OPTIONS_POPULATE_URGENT_BUDGET_MS or OPTIONS_POPULATE_BUDGET_MS
end



local function RunBudgetedOptionsWork(worker, done)
    Utils.RunSliced(function()
        local co = coroutine.running()
        if co then ownRuns[co] = true end
        return worker()
    end, function(ok, resultOrErr)
        if ok then return done(resultOrErr) end
        Utils.ErrorHandler(resultOrErr)
        done(nil, resultOrErr)
    end, OptionsBudget, "settingsPopulate")
end

local function CollectGameSettingsAsync(done)
    RunBudgetedOptionsWork(CollectGameSettings, done)
end
BlizzOptionsSearch.CollectGameSettingsAsync = CollectGameSettingsAsync

local registered = false
local fastGameRegistered = false
local coreGameRegistered = false
local liveRegistered = false
local populatePending = false
local livePopulatePending = false
local populateWaiters = {}
local livePopulateWaiters = {}

local function DedupeKey(e)
    return (e.name or "") .. "\31" .. (e.settingsCategory or "")
end

local function NotifyWaiters(waiters, changed)
    for i = 1, #waiters do
        waiters[i](changed)
        waiters[i] = nil
    end
end

local function AddWaiter(waiters, fn)
    if fn then waiters[#waiters + 1] = fn end
end



local pushSink
local RememberCategories
local function Sink(e)
    if pushSink then pushSink[#pushSink + 1] = e end
end

local function PushOptionEntries(data, entries, kb, addonEntries, gameEntries)


    local addonKeys = {}
    local existingVars = {}


    local owners, byButton = {}, ns.Caps and ns.Caps.BUTTON_BINDING or {}
    for i = 1, #data do
        local e = data[i]
        if e then
            if e.settingVariable then existingVars[e.settingVariable] = i end
            local category = e.category
            if category == "AddOn Settings" then
                addonKeys[DedupeKey(e)] = true
            elseif category == "Menu Bar" then
                local action = e.buttonFrame and byButton[e.buttonFrame]
                if action and e.available then owners[action] = e end
            end
        end
    end
    for i = 1, #addonEntries do
        local e = addonEntries[i]
        if e.category == "AddOn Settings" then
            addonKeys[DedupeKey(e)] = true
        end
    end
    local changed = false
    local function pushOne(e)
        if e.category == "Game Settings" and addonKeys[DedupeKey(e)] then return end
        local variable = e.settingVariable
        if variable then
            local existingIndex = existingVars[variable]
            if existingIndex then




                if ns.SearchIndex and ns.SearchIndex.NoteReplaced then
                    ns.SearchIndex:NoteReplaced(data[existingIndex], e)
                end
                data[existingIndex] = e
                Sink(e)
                changed = true
                return
            end
            existingVars[variable] = #data + 1
        end
        tinsert(data, e)
        Sink(e)
        changed = true
    end
    local function pushFiltered(src)
        for i = 1, #src do
            pushOne(src[i])
        end
    end

    for i = 1, #kb do
        local owner = owners[kb[i].bindingAction]
        if owner then kb[i].available = function() return not owner.available() end end
    end



    pushFiltered(entries)
    pushFiltered(kb)
    for i = 1, #addonEntries do
        tinsert(data, addonEntries[i])
        Sink(addonEntries[i])
        changed = true
    end
    if gameEntries then pushFiltered(gameEntries) end
    return changed
end

local function PushLiveGameEntries(data, gameEntries)
    local addonKeys = {}
    local seenVars = {}
    local seenNames = {}
    for i = 1, #data do
        local e = data[i]
        if e.category == "AddOn Settings" then
            addonKeys[DedupeKey(e)] = true
        elseif e.category == "Game Settings" then
            if e.settingVariable then seenVars[e.settingVariable] = true end
            seenNames[DedupeKey(e)] = true
        end
    end

    local changed = false
    for i = 1, #gameEntries do
        local e = gameEntries[i]
        local duplicate = (e.settingVariable and seenVars[e.settingVariable])
            or seenNames[DedupeKey(e)]
            or addonKeys[DedupeKey(e)]
        if not duplicate then
            tinsert(data, e)
            if e.settingVariable then seenVars[e.settingVariable] = true end
            seenNames[DedupeKey(e)] = true
            changed = true
        end
    end
    return changed
end























local OPTIONS_CACHE_SCHEMA = 5



local function AddonSetFingerprint()
    local C = C_AddOns
    if not (C and C.GetNumAddOns and C.GetAddOnInfo) then return "na" end
    local okNum, count = pcall(C.GetNumAddOns)
    if not okNum or type(count) ~= "number" then return "na" end
    local getState = C.GetAddOnEnableState
    local names, enabledCount = {}, 0
    for i = 1, count do
        local enabled = true
        if getState then
            local ok, state = pcall(getState, i)
            if not (ok and type(state) == "number") then
                ok, state = pcall(getState, nil, i)
            end
            if ok and type(state) == "number" then enabled = state ~= 0 end
        end
        if enabled then
            local okInfo, addonName = pcall(C.GetAddOnInfo, i)
            if okInfo and type(addonName) == "string" then
                enabledCount = enabledCount + 1
                names[enabledCount] = addonName
            end
        end
    end
    return enabledCount .. ":" .. tconcat(names, "\31")
end



local function AddonCategoryCount()
    local list = GetSettingsCategoryList()
    local n = 0
    for _, cat in ipairs(type(list) == "table" and list or {}) do
        if IsAddonCategory(cat) then n = n + 1 end
    end
    return n
end

local function BuildOptionsCacheSignature()
    local _, build = GetBuildInfo()
    return tconcat({
        OPTIONS_CACHE_SCHEMA,
        tostring(build or "?"),
        (GetLocale and GetLocale()) or "?",
        AddonSetFingerprint(),
        tostring(AddonCategoryCount()),
    }, "\30")
end
BlizzOptionsSearch.BuildOptionsCacheSignature = BuildOptionsCacheSignature



local STEP_FIELDS = { "settingsCategory", "settingCategoryID", "settingVariable",
    "bindingAction", "bindingHeader" }






local OPTIONS_ROW_SPEC = {
    { "name" }, { "nameLower" },
    { "keywords", "list" },
    { "steps", "records", STEP_FIELDS },
    { "settingVariable" }, { "cbVariable" }, { "sliderVariable" }, { "dropdownVariable" },
    { "settingType" }, { "settingMin" }, { "settingMax" }, { "settingStep" },
    { "bindingAction" }, { "customToggle" }, { "quickKeybindActivate" },
    { "category" }, { "path", "list" }, { "settingsCategory" }, { "settingCategoryID" },
    { "addon" },
}

local function SerializeList(src)
    return Utils.PackRows(src, OPTIONS_ROW_SPEC)
end








local OPTIONS_CORPUS_PROTO = {}

local OPTIONS_COMPUTED = {
    category = function() return "Game Settings" end,
    keywords = function() return {} end,
    settingFormatter = function(stub)
        local var = stub.settingVariable
        local override = var and QUALITY_SLIDER_OVERRIDES[var]
        return override and override.formatter or nil
    end,
    settingOptions = function(stub)
        local var = stub.settingVariable
        return var and CVAR_DROPDOWN_OPTIONS[var] or nil
    end,
}

local function OptionsRowKeywords(row)
    return row.keywords
end

local function DeserializeList(blob, corpusName)
    local corpus = Utils.GetCorpus(corpusName)
    if not (corpus and corpus.packed == blob) then


        corpus = Utils.NewPackedCorpus(blob, OPTIONS_ROW_SPEC, OPTIONS_CORPUS_PROTO, {
            computed = OPTIONS_COMPUTED,
            keywordsFor = OptionsRowKeywords,
            keywordFields = { keywords = true },
            liteFields = { "category" },
            ungated = true,
        })
        Utils.RegisterCorpus(corpusName, corpus)
    end
    local out = {}
    for ri = 1, corpus.count do out[ri] = corpus:StubAt(ri) end
    return out
end



function BlizzOptionsSearch.DeserializeOptionsCache(cache)
    if type(cache) ~= "table" then return nil end
    if type(cache.entries) ~= "string" or type(cache.kb) ~= "string"
       or type(cache.addon) ~= "string" then
        return nil
    end
    return {
        entries = DeserializeList(cache.entries, "optionsGame"),
        kb = DeserializeList(cache.kb, "optionsKb"),
        addon = DeserializeList(cache.addon, "optionsAddon"),
    }
end

local function SaveOptionsCache(entries, kb, addonEntries)
    local db = EasyFind and EasyFind.db
    if not db then return end
    local ok, blob = xpcall(function()
        return {
            sig = BuildOptionsCacheSignature(),
            entries = SerializeList(entries),
            kb = SerializeList(kb),
            addon = SerializeList(addonEntries),
        }
    end, Utils.ErrorHandler)
    if ok and type(blob) == "table" then
        db.optionsSearchCache = blob
    end
end






local function SpotCheckRestored(entries)
    if type(entries) ~= "table" then return false end
    local candidates = {}
    for i = 1, #entries do
        local entry = entries[i]
        local var = entry.settingVariable
        if var and entry.category == "Game Settings"
           and entry.settingsCategory ~= "Keybindings"
           and not var:find("^PROXY_RAID_") then
            candidates[#candidates + 1] = entry
        end
    end
    local n = #candidates
    if n == 0 then return true end
    local sampleIdx
    if n <= 6 then
        sampleIdx = {}
        for i = 1, n do sampleIdx[i] = i end
    else
        sampleIdx = { 1, 2, 3, (n - (n % 2)) / 2, n - 1, n }
    end
    for si = 1, #sampleIdx do
        local entry = candidates[sampleIdx[si]]
        if entry then
            local fresh = GetSettingDisplayName(entry.settingVariable, nil)





            if fresh ~= nil and fresh ~= "" and entry.name
               and entry.name:sub(1, #fresh) ~= fresh then
                return false
            end
        end
    end
    return true
end


local function StepClock()
    return debugprofilestop and debugprofilestop() or 0
end
local function Step(rec, key, t0)
    local t1 = StepClock()
    rec[key] = t1 - t0
    return t1
end




local function RestoreOptionsFromCache(data, rec)
    local db = EasyFind and EasyFind.db
    if not db then return false end
    local cache = db.optionsSearchCache
    if type(cache) ~= "table" or cache.sig == nil then rec.miss = "noCache" return false end
    local t = StepClock()
    local sig = BuildOptionsCacheSignature()
    Step(rec, "sigMs", t)
    if cache.sig ~= sig then
        rec.miss, rec.savedSig, rec.liveSig = "signature", cache.sig, sig
        return false
    end

    MaybeYieldLiveSettings()
    t = StepClock()
    local ok, restored = xpcall(function()
        return BlizzOptionsSearch.DeserializeOptionsCache(cache)
    end, Utils.ErrorHandler)
    Step(rec, "decodeMs", t)
    if not ok or type(restored) ~= "table" then rec.miss = "decode" return false end

    MaybeYieldLiveSettings()
    t = StepClock()
    local fresh = SpotCheckRestored(restored.entries)
    Step(rec, "spotMs", t)
    if not fresh then rec.miss = "spotCheck" return false end

    MaybeYieldLiveSettings()
    t = StepClock()
    local pushOk, changed = xpcall(function()
        return PushOptionEntries(data, restored.entries, restored.kb, restored.addon, nil)
    end, Utils.ErrorHandler)
    Step(rec, "pushMs", t)
    if not pushOk then rec.miss = "push" return false end
    if changed and ns.Database.ResetSearchCache then ns.Database:ResetSearchCache() end
    return true
end






local CANVAS_MAX = 600
local CANVAS_KINDS = { CheckButton = true, Slider = true, DropdownButton = true }
local function CanvasLabel(w)
    local fs = w.Text or w.text or w.Label or w.label
    if type(fs) == "table" and fs.GetText then
        local t = fs:GetText()
        if type(t) == "string" and t ~= "" then return t end
    end
    local name = w.GetName and w:GetName()
    local g = name and _G[name .. "Text"]
    if g and g.GetText then
        local t = g:GetText()
        if type(t) == "string" and t ~= "" then return t end
    end
    return nil
end
local function CanvasControls(root)
    local out, seen, stack, n = {}, {}, { root }, 0
    while #stack > 0 and n < CANVAS_MAX do
        local f = table.remove(stack)
        n = n + 1
        local kind = f.GetObjectType and f:GetObjectType()
        if CANVAS_KINDS[kind] or (kind == "Button" and f.SetupMenu) then
            local label = CanvasLabel(f)
            label = label and Utils.StripMarkup(label)


            if label and label:find("[%w\128-\255]") and not seen[label] then
                seen[label] = true
                out[#out + 1] = { widget = f, label = label }
            end
        end
        if f.GetChildren then
            for _, kid in ipairs({ f:GetChildren() }) do stack[#stack + 1] = kid end
        end
    end
    return out
end
local function CanvasRows(cat, addon)
    if not (cat and cat.GetName and SettingsPanel and SettingsPanel.GetLayout) then return nil end
    local lok, layout = pcall(SettingsPanel.GetLayout, SettingsPanel, cat)
    if not (lok and layout and layout.GetFrame) then return nil end
    local frame = layout:GetFrame()
    if not frame then return nil end

    if type(frame.obj) == "table" and frame.obj.type == "BlizOptionsGroup" then return nil end
    local catName, catID = cat:GetName(), cat.GetID and cat:GetID()
    if not (catName and catName ~= "" and catID) then return nil end
    local rootName = addon .. " " .. (_G["SETTINGS"] or "Settings")
    local pathPrefix = addon ~= catName and { rootName, catName } or { rootName }
    local catMT = GetSettingsCatMT("AddOn Settings", catName, catID, pathPrefix)
    local rows = {}
    for _, c in ipairs(CanvasControls(frame)) do
        local nameLower = SearchLower(c.label)
        rows[#rows + 1] = setmetatable({
            name = c.label, nameLower = nameLower,
            keywords = { "addon", "setting", "option", nameLower, SearchLower(catName), SearchLower(addon) },
            steps = { { settingsCategory = catName, settingCategoryID = catID, canvasTarget = c.widget } },
            addon = addon,
        }, catMT)
    end
    return rows, frame
end
BlizzOptionsSearch.CanvasRows = CanvasRows
local canvasPushed = {}
local function PushCanvasRows(data, cat, addon)
    if ns.settingsFeeds and ns.settingsFeeds[addon] then return false end
    local rows, frame = CanvasRows(cat, addon)
    if not rows then return false end
    local added = false
    for _, e in ipairs(rows) do
        local key = DedupeKey(e)
        if not canvasPushed[key] then
            canvasPushed[key] = true
            tinsert(data, e)
            Sink(e)
            added = true
        end
    end

    if #rows == 0 and frame and not frame._efCanvasWatched then
        frame._efCanvasWatched = true
        frame:HookScript("OnShow", function()
            SafeAfter(0.5, function()
                if PushCanvasRows(ns.Database.uiSearchData, cat, addon) and ns.Database.ResetSearchCache then
                    ns.Database:ResetSearchCache()
                end
            end)
        end)
    end
    return added
end

local function PushCanvasEntries(data)
    local list = GetSettingsCategoryList()
    local added = false
    for _, cat in ipairs(type(list) == "table" and list or {}) do


        if IsAddonCategory(cat) and cat ~= ns.OptionsCategory and cat:GetName() ~= "EasyFind" then
            local addon = cat:GetName()
            if PushCanvasRows(data, cat, addon) then added = true end
            if cat.GetSubcategories then
                local sok, subs = pcall(cat.GetSubcategories, cat)
                for _, sub in ipairs(sok and type(subs) == "table" and subs or {}) do
                    if PushCanvasRows(data, sub, addon) then added = true end
                end
            end
        end
    end
    return added
end



local feedRows = {}
local function FeedPath(addon, path)
    local out = { addon .. " " .. (_G["SETTINGS"] or "Settings") }
    if type(path) == "string" and path ~= "" then
        out[2] = path
    elseif type(path) == "table" then
        for i = 1, #path do out[#out + 1] = tostring(path[i]) end
    end
    return out
end



local FEED_KINDS = { check = "checkbox", radio = "checkbox", slider = "slider", choice = "dropdown", button = "button",
                     keybind = "keybind" }
local feedSerial = 0
local function FeedControl(e, control, addon)
    local Rows = ns.ResultRows
    if type(control) ~= "table" or not FEED_KINDS[control.kind] or not (Rows and Rows.RegisterCustomSetting) then return end
    if type(control.tooltip) == "string" and control.tooltip ~= "" then e.settingTooltip = control.tooltip end
    local kind = control.kind
    if kind == "button" then
        if type(control.press) == "function" then e.settingPress = control.press end
        return
    end


    if kind == "keybind" then
        if type(control.action) == "string" then
            e.settingType, e.bindingAction, e.accountKeybind = "keybind", control.action, true
        end
        return
    end
    if type(control.get) ~= "function" or type(control.set) ~= "function" then return end
    local set = control.set
    if kind == "radio" then
        set = function(on) if on then control.set(true) end end
    elseif kind == "slider" then
        if type(control.min) ~= "number" or type(control.max) ~= "number" then return end
        e.settingMin, e.settingMax, e.settingStep = control.min, control.max, control.step or 1
        if type(control.format) == "function" then e.settingFormatter = control.format end
    elseif kind == "choice" then
        local choices = control.choices
        if type(choices) == "function" then
            local ok, list = pcall(choices)
            choices = ok and list or nil
        end
        local opts = {}
        for _, c in ipairs(type(choices) == "table" and choices or {}) do
            if type(c) == "table" and c.value ~= nil then opts[#opts + 1] = { value = c.value, label = tostring(c.label or c.value) } end
        end
        if #opts == 0 then return end
        e.settingOptions = opts
        AddOptionLabelKeywords(e.keywords, opts)
    end
    feedSerial = feedSerial + 1
    local variable = "feed\31" .. addon .. "\31" .. feedSerial
    Rows:RegisterCustomSetting(variable, { get = control.get, set = set })
    e.settingVariable, e.settingType, e.feedVariable = variable, FEED_KINDS[kind], variable
end

local function PullFeed(data, addon, rows)


    local ok, list
    local outer = coroutine.running()
    if outer and ownRuns[outer] then
        local co = coroutine.create(rows)
        ownRuns[co] = true
        ok, list = coroutine.resume(co)
        while ok and coroutine.status(co) == "suspended" do
            Utils.SliceYield()
            ok, list = coroutine.resume(co)
        end
        if not ok then Utils.ErrorHandler(list) end
    else
        ok, list = xpcall(rows, Utils.ErrorHandler)
    end

    if not ok then BlizzOptionsSearch.failedFeeds[addon] = true end
    if not ok or type(list) ~= "table" then return false end
    local made = {}
    for _, r in ipairs(list) do

        local step = type(r.step) == "table" and r.step or type(r.open) == "function" and { open = r.open }
        if type(r) == "table" and type(r.name) == "string" and r.name ~= "" and step then
            local nameLower = SearchLower(r.name)
            local keywords = { "addon", "setting", "option", nameLower, SearchLower(addon) }
            for _, w in ipairs(type(r.keywords) == "table" and r.keywords or {}) do
                keywords[#keywords + 1] = SearchLower(tostring(w))
            end
            local e = setmetatable({
                name = r.name, nameLower = nameLower, keywords = keywords,
                steps = { step }, addon = addon,
            }, GetSettingsCatMT("AddOn Settings", step.settingsCategory, step.settingCategoryID, FeedPath(addon, r.path)))
            FeedControl(e, r.control, addon)
            made[#made + 1] = e
        end
        MaybeYieldLiveSettings()
    end

    local old = feedRows[addon]
    if old then
        local kept = 0
        for i = 1, #data do
            if not old[data[i]] then
                kept = kept + 1
                data[kept] = data[i]
            end
        end
        for i = #data, kept + 1, -1 do data[i] = nil end
        local index = ns.SearchIndex
        for e in pairs(old) do
            if e.feedVariable then ns.ResultRows:RegisterCustomSetting(e.feedVariable, nil) end
            if index then index:NoteRemoved(e) end
        end
        if index then index:NoteCompacted(kept) end
    end
    local mine = {}
    for i = 1, #made do
        local e = made[i]
        mine[e] = true
        tinsert(data, e)
        Sink(e)
    end
    feedRows[addon] = mine
    return true
end



BlizzOptionsSearch.failedFeeds = {}
local function PushFeedEntries(data, only)
    if only then
        local rows = ns.settingsFeeds and ns.settingsFeeds[only]
        return rows and PullFeed(data, only, rows) or false
    end
    local changed, tried = false, {}
    while true do
        local addon
        for name in pairs(ns.settingsFeeds or {}) do
            if not feedRows[name] and not tried[name] and not BlizzOptionsSearch.failedFeeds[name] then
                addon = name
                break
            end
        end
        if not addon then return changed end
        tried[addon] = true
        if PullFeed(data, addon, ns.settingsFeeds[addon]) then changed = true end
        MaybeYieldLiveSettings()
    end
end


local populated = false
function BlizzOptionsSearch:PullSettingsFeed(addon)
    if not (populated and ns.Database and ns.Database.uiSearchData) then return end
    if PushFeedEntries(ns.Database.uiSearchData, addon) and ns.Database.ResetSearchCache then
        ns.Database:ResetSearchCache()
    end
end






local AceDialogOf
local CollectAceFeeds
local unpack = Utils.unpack
do
    local ACE_TYPES = { toggle = true, range = true, select = true, multiselect = true, input = true,
                        color = true, keybinding = true, execute = true }
    local ACE_MAX = 4000
    local REGISTRY, DIALOG = "AceConfigRegistry-3.0", "AceConfigDialog-3.0"
    local aceFeeds = {}
    local hooked = {}








    local Save = { schema = 1, liveNow = {}, coldAfter = 20, coldRetry = 5 }


    local function AceLibs()
        local libs = type(LibStub) == "table" and LibStub.libs
        if type(libs) ~= "table" then return {} end
        local out = {}
        for name, lib in pairs(libs) do
            if name == REGISTRY or name:sub(1, #REGISTRY + 1) == REGISTRY .. "-" then
                local suffix = name:sub(#REGISTRY + 1)
                out[suffix] = { registry = lib, dialog = libs[DIALOG .. suffix] }
            end
        end
        return out
    end
    AceDialogOf = function(suffix)
        local libs = type(LibStub) == "table" and LibStub.libs
        return type(libs) == "table" and libs[DIALOG .. (suffix or "")] or nil
    end




    local function Member(key, option, options, path, appName, handler, ...)
        local member = option[key]
        local literal = key == "name" or key == "desc"
        if type(member) == "function" or (type(member) == "string" and not literal) then
            local info = { options = options, appName = appName, arg = option.arg, handler = handler,
                           option = option, type = option.type, uiType = "dialog", uiName = DIALOG }
            info[0] = appName
            for i = 1, #path do info[i] = path[i] end
            local ok, v
            if type(member) == "function" then
                ok, v = pcall(member, info, ...)
            elseif handler and type(handler[member]) == "function" then
                ok, v = pcall(handler[member], handler, info, ...)
            end
            if ok then return v end
            return nil
        end
        return member
    end
    local function Label(v)
        if type(v) ~= "string" then return nil end
        local clean = Utils.StripMarkup and Utils.StripMarkup(v) or v
        clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
        return clean ~= "" and clean or nil
    end


    local function Walk(group, options, path, groupPath, names, handler, appName, out)
        local args = type(group.args) == "table" and group.args or {}
        local keys = {}
        for key in pairs(args) do keys[#keys + 1] = key end
        for k = 1, #keys do
            if #out >= ACE_MAX then return end
            local key = keys[k]
            local option = args[key]
            if type(option) == "table" and option.type then
                path[#path + 1] = key
                local h = option.handler or handler
                local hidden = option.dialogHidden
                if hidden == nil then hidden = option.guiHidden end
                if hidden == nil then hidden = Member("hidden", option, options, path, appName, h) end
                if not hidden then
                    local name = Label(Member("name", option, options, path, appName, h))
                    if option.type == "group" then
                        local inline = option.inline or option.dialogInline or option.guiInline
                        local subNames = {}
                        for i = 1, #names do subNames[i] = names[i] end
                        if name then subNames[#subNames + 1] = name end
                        local subGroups = groupPath
                        if not inline then
                            subGroups = {}
                            for i = 1, #groupPath do subGroups[i] = groupPath[i] end
                            subGroups[#subGroups + 1] = key
                        end
                        Walk(option, options, path, subGroups, subNames, h, appName, out)
                    elseif ACE_TYPES[option.type] and name then
                        local keyPath = {}
                        for i = 1, #path do keyPath[i] = path[i] end
                        out[#out + 1] = { name = name, groupPath = groupPath, names = names, option = option,
                                          keyPath = keyPath, handler = h }
                    end
                end
                path[#path] = nil
            end
            MaybeYieldLiveSettings()
        end
    end


    function Save.Signature()
        local build = GetBuildInfo and select(2, GetBuildInfo())
        local versions = {}
        local C = C_AddOns
        if C and C.GetNumAddOns and C.GetAddOnMetadata then
            for i = 1, C.GetNumAddOns() do
                local ok, v = pcall(C.GetAddOnMetadata, i, "Version")
                versions[i] = ok and type(v) == "string" and v or ""
            end
        end
        return tconcat({ Save.schema, tostring(build or "?"), (GetLocale and GetLocale()) or "?",
            AddonSetFingerprint(), tconcat(versions, "\31") }, "\30")
    end



    function Save.Get()
        if Save.cache then return Save.cache end
        local db = EasyFind and EasyFind.db
        if not db then return nil end
        local sig = Save.Signature()
        local saved = db.aceSettingsCache
        if type(saved) == "table" and saved.sig == sig and saved.whole and type(saved.names) == "table"
           and type(saved.rows) == "table" then
            Save.cache, Save.restored = saved, true
        else
            Save.cache, Save.restored = { sig = sig, names = {}, rows = {} }, false
            db.aceSettingsCache = Save.cache
        end
        return Save.cache
    end



    function Save.Clean(v) return (tostring(v or ""):gsub("[\28-\31]", "")) end
    function Save.Split(str, sep)
        local out = {}
        if str == "" then return out end
        local from = 1
        while true do
            local at = str:find(sep, from, true)
            if not at then
                out[#out + 1] = str:sub(from)
                return out
            end
            out[#out + 1] = str:sub(from, at - 1)
            from = at + 1
        end
    end
    function Save.KeyList(keys)
        local out = {}
        for i = 1, #keys do out[i] = (type(keys[i]) == "number" and "n" or "s") .. Save.Clean(keys[i]) end
        return tconcat(out, "\31")
    end
    function Save.Keys(str)
        local out = Save.Split(str, "\31")
        for i = 1, #out do
            local tag, key = out[i]:sub(1, 1), out[i]:sub(2)
            out[i] = tag == "n" and tonumber(key) or key
        end
        return out
    end
    function Save.Names(list)
        local out = {}
        for i = 1, #list do out[i] = Save.Clean(list[i]) end
        return tconcat(out, "\31")
    end
    function Save.EncodeChoices(choices)
        local out = {}
        for _, c in ipairs(type(choices) == "table" and choices or {}) do
            local v = c.value
            local tag = type(v) == "number" and "n" or type(v) == "boolean" and "b" or "s"
            out[#out + 1] = tag .. Save.Clean(v) .. "\28" .. Save.Clean(c.label)
        end
        return tconcat(out, "\31")
    end
    function Save.DecodeChoices(str)
        local out = {}
        for _, item in ipairs(Save.Split(str, "\31")) do
            local at = item:find("\28", 1, true)
            if at then
                local tag, raw = item:sub(1, 1), item:sub(2, at - 1)
                local value = raw
                if tag == "n" then value = tonumber(raw) elseif tag == "b" then value = raw == "true" end
                out[#out + 1] = { value = value, label = item:sub(at + 1) }
            end
        end
        return out
    end



    function Save.LiveOption(appName, suffix, keyPath)
        local libs = AceLibs()[suffix]
        if not libs then return nil end
        local ok, options = pcall(libs.registry.GetOptionsTable, libs.registry, appName, "dialog", "EasyFind-4.0")
        if not (ok and type(options) == "table") then return nil end
        local option, handler = options, options.handler
        for i = 1, #keyPath do
            option = type(option.args) == "table" and option.args[keyPath[i]] or nil
            if type(option) ~= "table" then return nil end
            handler = option.handler or handler
        end
        return option, options, handler
    end
    function Save.Control(kind, appName, suffix, keyPath, f)
        local function Call(key, ...)
            local option, options, handler = Save.LiveOption(appName, suffix, keyPath)
            if option then return Member(key, option, options, keyPath, appName, handler, ...) end
        end
        local control
        if kind == "toggle" then
            control = { kind = "check", get = function() return Call("get") end, set = function(v) Call("set", v) end }
        elseif kind == "range" and tonumber(f[10]) and tonumber(f[11]) then
            control = { kind = "slider", get = function() return Call("get") end, set = function(v) Call("set", v) end,
                        min = tonumber(f[10]), max = tonumber(f[11]), step = tonumber(f[12]) or 1 }
            if f[13] == "1" then
                control.format = function(n) return string.format("%d%%", math.floor(n * 100 + 0.5)) end
            end
        elseif kind == "select" then
            control = { kind = "choice", get = function() return Call("get") end, set = function(v) Call("set", v) end,
                        choices = Save.DecodeChoices(f[14] or "") }
        elseif kind == "execute" then
            control = { kind = "button", press = function() Call("func") end }
        end
        if control and f[9] ~= "" then control.tooltip = f[9] end
        return control
    end


    function Save.Rows(display)
        local blob, names = Save.cache.rows[display], Save.cache.names[display]
        local rows = {}
        for n, line in ipairs(Save.Split(blob, "\29")) do

            if n % 64 == 0 then MaybeYieldLiveSettings() end
            local f = Save.Split(line, "\30")
            local i = tonumber(f[1])
            local appName, suffix = names.order[i], names.libs[i]
            if appName and f[3] and f[3] ~= "" then
                local keyPath, groupPath = Save.Keys(f[5] or ""), Save.Keys(f[6] or "")
                rows[#rows + 1] = {
                    name = f[3], path = Save.Split(f[4] or "", "\31"),
                    control = Save.Control(f[2], appName, suffix, keyPath, f),
                    step = { settingsCategory = f[7] ~= "" and f[7] or nil, settingCategoryID = tonumber(f[8]),
                             aceApp = appName, aceLib = suffix, aceGroup = groupPath, canvasLabel = f[3] },
                }
            end
        end
        return rows
    end



    local function HostCategory(blizz, appName, groupPath)
        if type(blizz) ~= "table" then return nil end
        for n = #groupPath, 0, -1 do
            local key = appName
            for i = 1, n do key = key .. "\001" .. groupPath[i] end
            local group = blizz[key]
            local id = group and group.frame and group.frame.name
            if id ~= nil then
                local cat = type(id) == "number" and Settings and Settings.GetCategory and Settings.GetCategory(id)
                local catName = cat and cat.GetName and cat:GetName() or (type(id) == "string" and id) or nil
                if catName then return catName, type(id) == "number" and id or nil end
            end
        end
        return nil
    end

    local function AppOptions(registry, appName)
        local ok, options = pcall(registry.GetOptionsTable, registry, appName, "dialog", "EasyFind-4.0")
        return ok and type(options) == "table" and options or nil
    end



    local function Apps()
        local byName = {}
        for suffix, libs in pairs(AceLibs()) do
            local registry = libs.registry
            if type(registry.IterateOptionsTables) == "function" then

                local appNames = {}
                for appName in registry:IterateOptionsTables() do appNames[#appNames + 1] = appName end
                for _, appName in ipairs(appNames) do
                    local options = AppOptions(registry, appName)
                    if options then
                        local blizz = libs.dialog and libs.dialog.BlizOptions and libs.dialog.BlizOptions[appName]
                        local display = HostCategory(blizz, appName, {})
                            or Label(Member("name", options, options, {}, appName, options.handler)) or appName
                        byName[display] = byName[display] or {}
                        tinsert(byName[display], { appName = appName, suffix = suffix, options = options, blizz = blizz })
                    end
                    MaybeYieldLiveSettings()
                end
            end
        end
        return byName
    end




    local function AceControl(f, app)
        local option, options, path, handler, appName = f.option, app.options, f.keyPath, f.handler, app.appName
        local function Get() return Member("get", option, options, path, appName, handler) end
        local function Set(v) Member("set", option, options, path, appName, handler, v) end
        local control
        local t = option.type
        if t == "toggle" then
            control = { kind = "check", get = Get, set = Set }
        elseif t == "range" and type(option.min) == "number" and type(option.max) == "number" then
            control = { kind = "slider", get = Get, set = Set, min = option.min, max = option.max,
                        step = option.step or option.bigStep or 1 }
            if option.isPercent then
                control.format = function(n) return string.format("%d%%", math.floor(n * 100 + 0.5)) end
            end
        elseif t == "select" then
            local list
            local values = Member("values", option, options, path, appName, handler)
            if type(values) == "table" then
                list = {}
                for value, label in pairs(values) do list[#list + 1] = { value = value, label = tostring(label) } end
                table.sort(list, function(a, b) return a.label < b.label end)
            end
            control = { kind = "choice", get = Get, set = Set, choices = list }
        elseif t == "execute" then
            control = { kind = "button", press = function() Member("func", option, options, path, appName, handler) end }
        end
        if control then control.tooltip = Label(Member("desc", option, options, path, appName, handler)) end
        return control
    end



    local function Rows(display)
        local cache = Save.Get()
        if cache and Save.restored and not Save.liveNow[display] and cache.rows[display] and cache.names[display] then
            return Save.Rows(display)
        end
        local rows, saved = {}, {}
        local feed = aceFeeds[display]
        local libsBy = AceLibs()
        local index = {}
        for i, appName in ipairs(feed and feed.order or {}) do index[appName] = i end
        for _, appName in ipairs(feed and feed.order or {}) do
            local libs = libsBy[feed.apps[appName]]
            local options = libs and AppOptions(libs.registry, appName)
            local app = options and { appName = appName, suffix = feed.apps[appName], options = options,
                blizz = libs.dialog and libs.dialog.BlizOptions and libs.dialog.BlizOptions[appName] }
            if app then
                local found = {}
                Walk(app.options, app.options, {}, {}, {}, app.options.handler, app.appName, found)
                for _, f in ipairs(found) do
                    local catName, catID = HostCategory(app.blizz, app.appName, f.groupPath)
                    local control = AceControl(f, app)
                    rows[#rows + 1] = {
                        name = f.name, path = f.names, control = control,
                        step = { settingsCategory = catName, settingCategoryID = catID, aceApp = app.appName,
                                 aceLib = app.suffix, aceGroup = f.groupPath, canvasLabel = f.name },
                    }
                    local o = f.option
                    saved[#saved + 1] = tconcat({ index[appName], Save.Clean(o.type), Save.Clean(f.name), Save.Names(f.names),
                        Save.KeyList(f.keyPath), Save.KeyList(f.groupPath), Save.Clean(catName), Save.Clean(catID),
                        Save.Clean(control and control.tooltip), Save.Clean(control and control.min), Save.Clean(control and control.max),
                        Save.Clean(control and control.step), o.isPercent and "1" or "",
                        Save.EncodeChoices(control and control.choices) }, "\30")
                end
            end
        end
        if cache and feed then
            local libs = {}
            for i, appName in ipairs(feed.order) do libs[i] = feed.apps[appName] end
            cache.names[display] = { order = { unpack(feed.order) }, libs = libs }
            cache.rows[display] = tconcat(saved, "\29")

            local whole = true
            for name in pairs(aceFeeds) do
                if not cache.rows[name] then whole = false break end
            end
            cache.whole = whole or nil
        end
        return rows
    end

    local function Refresh(display)
        CollectAceFeeds(true)
        if not display then return end
        Save.liveNow[display] = true
        BlizzOptionsSearch:PullSettingsFeed(display)
        Save.liveNow[display] = nil
    end
    function Save.DisplayOf(appName)
        for display, feed in pairs(aceFeeds) do
            if feed.apps[appName] ~= nil then return display end
        end
    end
    local function HookRegistry(registry)
        if hooked[registry] or type(registry.RegisterOptionsTable) ~= "function" or not hooksecurefunc then return end
        hooked[registry] = true
        hooksecurefunc(registry, "RegisterOptionsTable", function(_, appName)
            SafeAfter(0, function()
                if Save.restored then
                    local display = Save.DisplayOf(appName)

                    if not display then Save.restored = false end
                    return Refresh(display)
                end
                if not Save.coldDone then return end
                for display, apps in pairs(Apps()) do
                    for _, app in ipairs(apps) do
                        if not aceFeeds[display] or aceFeeds[display].apps[app.appName] == nil then Refresh(display) return end
                    end
                end
            end)
        end)
    end





    function Save.HookDialog(dialog)
        if not dialog or hooked[dialog] or type(dialog.Open) ~= "function" or not hooksecurefunc then return end
        hooked[dialog] = true
        hooksecurefunc(dialog, "Open", function(_, appName)
            if not Save.restored then return end
            local display = Save.DisplayOf(appName)
            if display then SafeAfter(1, function() Refresh(display) end) end
        end)
    end



    function Save.ReadColdLater()
        if Save.coldScheduled then return end
        Save.coldScheduled = true
        local function Try()
            if InCombatLockdown() then return SafeAfter(Save.coldRetry, Try) end
            RunBudgetedOptionsWork(function()
                CollectAceFeeds(true)
                local data = ns.Database and ns.Database.uiSearchData
                return data and PushFeedEntries(data) or false
            end, function(changed)
                if changed and ns.Database.ResetSearchCache then ns.Database:ResetSearchCache() end
            end)
        end
        SafeAfter(Save.coldAfter, Try)
    end

    CollectAceFeeds = function(now)
        ns.settingsFeeds = ns.settingsFeeds or {}
        for _, libs in pairs(AceLibs()) do
            HookRegistry(libs.registry)
            Save.HookDialog(libs.dialog)
        end
        if type(LibStub) == "table" and not hooked[LibStub] and hooksecurefunc then
            hooked[LibStub] = true
            hooksecurefunc(LibStub, "NewLibrary", function(_, major)
                if type(major) == "string" and major:sub(1, #REGISTRY) == REGISTRY then SafeAfter(0, CollectAceFeeds) end
            end)
        end
        local cache = Save.Get()
        if cache and Save.restored then
            for display, names in pairs(cache.names) do
                local feed = aceFeeds[display]
                if not feed then
                    feed = { rows = function() return Rows(display) end }
                    aceFeeds[display] = feed
                end
                feed.apps, feed.order = {}, {}
                for i, appName in ipairs(names.order or {}) do
                    feed.order[i] = appName
                    feed.apps[appName] = names.libs[i]
                end
                if ns.settingsFeeds[display] == nil then ns.settingsFeeds[display] = feed.rows end
            end
            Save.coldDone = true
            return
        end
        if not now and not Save.coldDone and not optionsPopulateUrgent then return Save.ReadColdLater() end
        Save.coldDone = true

        for _, feed in pairs(aceFeeds) do feed.apps, feed.order = {}, {} end
        for display, apps in pairs(Apps()) do
            local feed = aceFeeds[display]
            if not feed then
                feed = { apps = {}, order = {}, rows = function() return Rows(display) end }
                aceFeeds[display] = feed
            end
            for _, app in ipairs(apps) do
                if feed.apps[app.appName] == nil then feed.order[#feed.order + 1] = app.appName end
                feed.apps[app.appName] = app.suffix
            end
            if ns.settingsFeeds[display] == nil then ns.settingsFeeds[display] = feed.rows end
        end
    end
    BlizzOptionsSearch.AceApps = Apps

    function BlizzOptionsSearch._DebugPeekAce() return { save = Save, feeds = aceFeeds } end
    BlizzOptionsSearch._AceRows = Rows
end

function BlizzOptionsSearch:Populate(includeLiveGameSettings)
    if not ns.Database or not ns.Database.uiSearchData then return end
    local data = ns.Database.uiSearchData
    local rec = { live = includeLiveGameSettings or nil, startedAt = GetTime and GetTime() or 0 }
    BlizzOptionsSearch.lastPopulate = rec
    local t = StepClock()
    pushSink = not includeLiveGameSettings and {} or nil

    local index = ns.SearchIndex
    local function Settled()
        if index then
            index:Unhold("Game Settings")
            index:Unhold("AddOn Settings")
        end
    end
    if pushSink and index then
        index:Hold("Game Settings")
        index:Hold("AddOn Settings")
    end
    if not includeLiveGameSettings then RememberCategories() end
    t = Step(rec, "rememberMs", t)
    local function AttachRows()
        local rows = pushSink
        pushSink = nil
        if rows and #rows > 0 and ns.SearchSegments and ns.SearchSegments.Attach then
            ns.SearchSegments.Attach("settings", rows, Settled)
        else
            Settled()
        end
        t = Step(rec, "attachMs", t)
    end





    if not includeLiveGameSettings and RestoreOptionsFromCache(data, rec) then
        rec.path = "cache"
        MaybeYieldLiveSettings()
        t = StepClock()
        CollectAceFeeds()
        t = Step(rec, "aceMs", t)
        local changed = PushCanvasEntries(data)
        t = Step(rec, "canvasMs", t)
        MaybeYieldLiveSettings()
        t = StepClock()
        if PushFeedEntries(data) then changed = true end
        t = Step(rec, "feedMs", t)
        MaybeYieldLiveSettings()
        t = StepClock()
        AttachRows()
        if changed and ns.Database.ResetSearchCache then ns.Database:ResetSearchCache() end
        populated = true
        rec.endedAt = GetTime and GetTime() or 0
        return
    end
    rec.path = "walk"
    t = StepClock()

    local entries = CollectEntries(not coreGameRegistered)
    t = Step(rec, "entriesMs", t)
    local kb = CollectKeybindings()
    t = Step(rec, "keybindsMs", t)
    local addonEntries = CollectAddonCategories()
    t = Step(rec, "addonsMs", t)
    local gameEntries = includeLiveGameSettings and CollectGameSettings() or nil
    t = Step(rec, "gameMs", t)

    local changed = PushOptionEntries(data, entries, kb, addonEntries, gameEntries)
    t = Step(rec, "pushMs", t)
    CollectAceFeeds()
    t = Step(rec, "aceMs", t)
    if PushCanvasEntries(data) then changed = true end
    t = Step(rec, "canvasMs", t)
    if PushFeedEntries(data) then changed = true end
    t = Step(rec, "feedMs", t)
    AttachRows()
    populated = true

    if changed and ns.Database.ResetSearchCache then ns.Database:ResetSearchCache() end


    if not includeLiveGameSettings then
        SaveOptionsCache(entries, kb, addonEntries)
        Step(rec, "saveMs", t)
    end
    rec.endedAt = GetTime and GetTime() or 0
end

function BlizzOptionsSearch:PopulateLight()
    self:Populate(false)
end

function BlizzOptionsSearch:EnsureFastGameOptions()
    if fastGameRegistered then return false end
    if registered then return false end
    if not (ns.Database and ns.Database.uiSearchData) then return false end
    local ok, entries = xpcall(CollectCuratedGameEntries, Utils.ErrorHandler, false, true)
    if not ok or type(entries) ~= "table" or #entries == 0 then return false end
    fastGameRegistered = true
    local changed = PushOptionEntries(ns.Database.uiSearchData, entries, {}, {}, nil)
    if changed and ns.Database.ResetSearchCache then ns.Database:ResetSearchCache() end
    return changed
end


local LABEL_WALK_MAX = 3000
local function FindLabeled(root, text)
    if not (root and text) then return nil end
    local stack, n = { root }, 0
    while #stack > 0 and n < LABEL_WALK_MAX do
        local f = table.remove(stack)
        n = n + 1
        if f.GetRegions then
            for _, r in ipairs({ f:GetRegions() }) do
                if r.IsObjectType and r:IsObjectType("FontString") and r:IsVisible() then
                    local t = r:GetText()
                    if type(t) == "string" and (Utils.StripMarkup and Utils.StripMarkup(t) or t) == text then return f end
                end
            end
        end
        if f.GetChildren then
            for _, kid in ipairs({ f:GetChildren() }) do stack[#stack + 1] = kid end
        end
    end
    return nil
end
local function HighlightLabeledLater(root, text, delay)
    SafeAfter(delay, function()
        local target = FindLabeled(root, text)
        if target and ns.RequestGuide and ns.RequestGuide() and ns.Highlight and ns.Highlight.HighlightFrame then
            ns.Highlight:HighlightFrame(target, nil, function(t) return t and t:IsVisible() or false end)
        end
    end)
end

function BlizzOptionsSearch:HandleStep(step)
    if not step then return false end

    if step.open then return (xpcall(step.open, Utils.ErrorHandler)) end


    local aceDialog = step.aceApp and AceDialogOf(step.aceLib)
    if aceDialog and step.aceGroup and #step.aceGroup > 0 and aceDialog.SelectGroup then
        pcall(aceDialog.SelectGroup, aceDialog, step.aceApp, unpack(step.aceGroup))
    end
    if step.aceApp and not step.settingsCategory then
        if not (aceDialog and aceDialog.Open) then return false end
        local ok = pcall(aceDialog.Open, aceDialog, step.aceApp)
        local open = ok and aceDialog.OpenFrames and aceDialog.OpenFrames[step.aceApp]
        if open and open.frame then HighlightLabeledLater(open.frame, step.canvasLabel, 0.3) end
        return ok
    end


    if InCombatLockdown() and not (SettingsPanel and SettingsPanel:IsShown()) then
        return false
    end


    local catID = step.settingCategoryID
    if not catID and step.settingVariable then
        catID = GetCategoryIDForVariable(step.settingVariable)
    end

    if not catID and step.settingsCategory == "Keybindings" and Settings then
        catID = Settings.KEYBINDINGS_CATEGORY_ID
    end
    if not catID and step.settingsCategory then
        catID = GetCategoryID(step.settingsCategory)
    end

    ShowSettings()

    if catID and Settings and Settings.OpenToCategory then
        if step.settingVariable then
            pcall(Settings.OpenToCategory, catID, step.settingVariable)
        else
            pcall(Settings.OpenToCategory, catID)
        end
    end

    local target = step.canvasTarget
    if target then
        SafeAfter(0.3, function()
            if ns.RequestGuide and ns.RequestGuide() and ns.Highlight and ns.Highlight.HighlightFrame and target:IsVisible() then
                ns.Highlight:HighlightFrame(target, nil, function(t) return t and t:IsVisible() or false end)
            end
        end)
    elseif step.canvasLabel then
        HighlightLabeledLater(SettingsPanel, step.canvasLabel, 0.5)
    end














    if step.settingVariable then
        local variable = step.settingVariable
        local done = false
        local function tryScroll()
            if done then return end
            if ScrollToSettingVariable(variable) then done = true end
        end
        for _, delay in ipairs({ 0, 0.05, 0.15, 0.3, 0.6 }) do
            SafeAfter(delay, tryScroll)
        end
    elseif step.bindingAction then
        local action, header = step.bindingAction, step.bindingHeader
        local done = false
        local function tryBinding()
            if done then return end
            if ScrollToBindingAction(action, header) then done = true end
        end
        for _, delay in ipairs({ 0, 0.05, 0.15, 0.3, 0.6 }) do
            SafeAfter(delay, tryBinding)
        end
    end

    return catID ~= nil
end

local lateRefreshScheduled = false


local knownCategories = {}
local function CategoryKey(parentName, name) return (parentName or "") .. "\31" .. name end
local function EachCategory(fn)
    local list = GetSettingsCategoryList()
    for _, cat in ipairs(type(list) == "table" and list or {}) do
        local name = cat.GetName and cat:GetName()
        if name and name ~= "" then
            fn(CategoryKey(nil, name))
            if cat.GetSubcategories then
                local sok, subs = pcall(cat.GetSubcategories, cat)
                for _, sub in ipairs(sok and type(subs) == "table" and subs or {}) do
                    local subName = sub.GetName and sub:GetName()
                    if subName and subName ~= "" then fn(CategoryKey(name, subName)) end
                end
            end
        end
    end
end
RememberCategories = function()
    wipe(knownCategories)
    EachCategory(function(key) knownCategories[key] = true end)
end

local function RefreshLateAddonCategories()
    if not (ns.Database and ns.Database.uiSearchData) then return end

    local fresh
    EachCategory(function(key)
        if not knownCategories[key] then
            fresh = fresh or {}
            fresh[key] = true
        end
    end)
    if not fresh then return end
    ResolveCategoryIDs()
    local added = false
    for _, e in ipairs(CollectEntries(false)) do
        local key = CategoryKey(e.path and e.path[2], e.settingsCategory)
        if not e.settingVariable and fresh[key] then
            tinsert(ns.Database.uiSearchData, e)
            added = true
        end
    end
    for key in pairs(fresh) do knownCategories[key] = true end
    if added and ns.Database.ResetSearchCache then ns.Database:ResetSearchCache() end
end

local function ScheduleLateRefresh()
    if lateRefreshScheduled then return end
    lateRefreshScheduled = true
    SafeAfter(3.0, RefreshLateAddonCategories)
end

local function Register()
    if registered then return end
    if not (ns.Database and ns.Database.uiSearchData) then return end
    BlizzOptionsSearch:PopulateLight()
    registered = true
    ScheduleLateRefresh()
end

function BlizzOptionsSearch:EnsureCoreGameOptions()
    if coreGameRegistered or registered then return false end
    if not (ns.Database and ns.Database.uiSearchData) then return false end
    local changed = self:EnsureFastGameOptions()
    coreGameRegistered = true
    return changed
end

function BlizzOptionsSearch:EnsurePopulated()
    Register()
end



function BlizzOptionsSearch:EnsurePopulatedAsync(onDone, idle)
    if registered then
        if onDone then onDone(false) end
        return false
    end
    AddWaiter(populateWaiters, onDone)
    if onDone and not idle then optionsPopulateUrgent = true end
    if populatePending then return true end
    populatePending = true

    local function finish(ok)
        populatePending = false
        if not livePopulatePending then optionsPopulateUrgent = false end
        if ok then
            registered = true
            ScheduleLateRefresh()
        end
        NotifyWaiters(populateWaiters, ok and registered)
    end

    local function run()
        if not (ns.Database and ns.Database.uiSearchData) then
            finish(false)
            return
        end
        RunBudgetedOptionsWork(function()
            BlizzOptionsSearch:PopulateLight()
            return true
        end, finish)
    end

    if SafeAfter then
        SafeAfter(0, run)
    else
        run()
    end
    return true
end

function BlizzOptionsSearch:EnsureLivePopulatedAsync(onDone, idle)
    if liveRegistered then
        if onDone then onDone(false) end
        return false
    end
    AddWaiter(livePopulateWaiters, onDone)
    if onDone and not idle then optionsPopulateUrgent = true end
    if livePopulatePending then return true end
    livePopulatePending = true

    local function finish(ok, changed)
        livePopulatePending = false
        if not populatePending then optionsPopulateUrgent = false end
        if ok then BlizzOptionsSearch.ReindexSettings() end
        NotifyWaiters(livePopulateWaiters, ok and changed)
    end

    local function startLivePopulate()
        local ok = xpcall(function()
            if not registered then Register() end
        end, Utils.ErrorHandler)
        if not ok then
            finish(false, false)
            return
        end
        if not (ns.Database and ns.Database.uiSearchData) then
            finish(false, false)
            return
        end

        CollectGameSettingsAsync(function(gameEntries)
            if not gameEntries then
                finish(false, false)
                return
            end
            local okPush, changed = xpcall(function()
                return PushLiveGameEntries(ns.Database.uiSearchData, gameEntries)
            end, Utils.ErrorHandler)
            if not okPush then
                finish(false, false)
                return
            end
            liveRegistered = true
            if changed and ns.Database.ResetSearchCache then ns.Database:ResetSearchCache() end
            finish(true, changed)
        end)
    end

    local function run()
        if populatePending and not registered then
            AddWaiter(populateWaiters, function()
                if registered then
                    startLivePopulate()
                else
                    finish(false, false)
                end
            end)
            return
        end
        startLivePopulate()
    end

    if SafeAfter then
        SafeAfter(0, run)
    else
        run()
    end
    return true
end
