local _, ns = ...





local Database = ns.Database
local SearchText = ns.SearchText
local Utils = ns.Utils

local MIN_BYTES = 4

local SHARED_SHARE, SHARED_FLOOR = 0.2, 3

local GetDescription = C_Spell and C_Spell.GetSpellDescription or _G["GetSpellDescription"]
local RequestLoad = C_Spell and C_Spell.RequestLoadSpellData


local function Words(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T[^|]*|t", ""):gsub("|A[^|]*|a", "")
    local out, seen = {}, {}
    for _, word in ipairs(SearchText.NormalizeAndTokenize(text)) do
        if #word >= MIN_BYTES and not seen[word] and not word:find("%d") then
            seen[word] = true
            out[#out + 1] = word
        end
    end
    return out
end



local afterFight, retried = {}, {}
local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    for key in pairs(afterFight) do
        afterFight[key] = nil
        Database:MarkDynamicCategoryDirty(key)
    end
end)

function Database:AddSpellWords(category, providerKey)
    if not GetDescription then return end
    if InCombatLockdown() then
        afterFight[providerKey] = true
        watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local rows = self.uiSearchData
    local found, words, shared, missing = {}, {}, {}, false
    for i = 1, #rows do
        if i % 512 == 0 then Utils.SliceCheckpoint() end
        local row = rows[i]
        if row.category == category and row.spellID then
            local text = GetDescription(row.spellID)
            if type(text) == "string" and text ~= "" then
                local list = Words(text)
                found[#found + 1], words[#words + 1] = row, list
                for w = 1, #list do shared[list[w]] = (shared[list[w]] or 0) + 1 end
            else
                missing = true
                if RequestLoad then RequestLoad(row.spellID) end
            end
        end
    end
    local limit = math.max(SHARED_FLOOR, math.floor(#found * SHARED_SHARE))
    for i = 1, #found do
        local row, list = found[i], words[i]
        local old = row.keywords or {}
        local kw, has = {}, {}
        for k = 1, #old do
            kw[k] = old[k]
            has[old[k]] = true
        end
        for w = 1, #list do
            local word = list[w]
            if shared[word] <= limit and not has[word] then kw[#kw + 1] = word end
        end
        row.keywords = kw
        if rawget(row, "keywordsLower") ~= nil then row.keywordsLower = kw end
    end
    if missing and not retried[providerKey] then
        retried[providerKey] = true
        Utils.SafeAfter(3, function() Database:MarkDynamicCategoryDirty(providerKey) end)
    end
end
