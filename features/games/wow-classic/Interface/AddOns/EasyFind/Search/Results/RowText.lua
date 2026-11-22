local _, ns = ...

local Text = ns.ResultText
local L = ns.L
local sformat = ns.Utils.sformat
local mfloor = math.floor

local KEY_ABBREV = {
    SHIFT = "S", CTRL = "C", ALT = "A", META = "M",
    PAGEDOWN = "PgDn", PAGEUP = "PgUp",
    HOME = "Home", END = "End",
    DELETE = "Del", INSERT = "Ins",
    BACKSPACE = "BkSp", SPACE = "Spc",
    ESCAPE = "Esc", ENTER = "Ent",
    PRINTSCREEN = "PrtSc",
    MOUSEWHEELUP = "MWU", MOUSEWHEELDOWN = "MWD",
    BUTTON3 = "MB3", BUTTON4 = "MB4", BUTTON5 = "MB5",
}
function Text:AbbrevBinding(binding)
    if not binding or binding == "" then return _G["NOT_BOUND"] or "Not Bound" end
    local out = {}
    for part in binding:gmatch("[^%-]+") do
        local up = part:upper()
        local short = KEY_ABBREV[up]
        if not short then

            local n = up:match("^NUMPAD(%d)$")
            if n then short = "Num" .. n end
        end
        out[#out + 1] = short or part
    end
    return table.concat(out, "-")
end






local function applyClip(fs)
    local text = fs._unclippedText
    if not text or text == "" then
        fs:SetText("")
        return
    end
    fs:SetText(text)



    local left, right = fs:GetLeft(), fs:GetRight()
    local maxW
    if left and right and right > left then
        maxW = right - left
    else
        maxW = fs:GetWidth() or 0
    end
    if not maxW or maxW <= 0 then return end
    local getW = fs.GetUnboundedStringWidth
    local strW = getW and fs:GetUnboundedStringWidth() or fs:GetStringWidth() or 0
    if strW <= maxW then return end


    local open, inner = text:match("^(|c%x%x%x%x%x%x%x%x)(.-)|r$")
    if not open then open, inner = text:match("^(|cn[^:|]+:)(.-)|r$") end
    local body = open and inner or text

    local lo, hi, best = 1, #body - 1, 1
    while lo <= hi do
        local cut = mfloor((lo + hi) / 2)
        fs:SetText(open and (open .. body:sub(1, cut) .. "...|r") or (body:sub(1, cut) .. "..."))
        local w = getW and fs:GetUnboundedStringWidth() or fs:GetStringWidth() or 0
        if w <= maxW then best, lo = cut, cut + 1 else hi = cut - 1 end
    end
    fs:SetText(open and (open .. body:sub(1, best) .. "...|r") or (body:sub(1, best) .. "..."))
end




local reclip, reclipQueued = {}, false
local function FlushReclip()
    reclipQueued = false
    for i = 1, #reclip do
        local fs = reclip[i]
        reclip[i] = nil
        if fs._unclippedText then applyClip(fs) end
    end
end



function Text:SetUnclippedText(fs, text)
    if not fs then return end
    fs._unclippedText = nil
    fs:SetText(text or "")
end

function Text:SetClippedText(fs, text)
    if not fs then return end
    fs._unclippedText = text or ""
    applyClip(fs)
    if C_Timer and C_Timer.After then
        reclip[#reclip + 1] = fs
        if not reclipQueued then
            reclipQueued = true
            C_Timer.After(0, FlushReclip)
        end
    end





    if not fs._sizeHookInstalled then
        fs._sizeHookInstalled = true
        local parent = fs:GetParent()
        if parent and parent.HookScript then
            parent:HookScript("OnSizeChanged", function()
                if fs._unclippedText then applyClip(fs) end
            end)
        end
    end
end



local MAP_KIND_GLOBALS = {
    zone = "ZONE", dungeon = "LFG_TYPE_DUNGEON", raid = "RAID", delve = "DELVE_LABEL",
    flightmaster = "MINIMAP_TRACKING_FLIGHTMASTER", mailbox = "MINIMAP_TRACKING_MAILBOX",
    innkeeper = "MINIMAP_TRACKING_INNKEEPER", auctionhouse = "MINIMAP_TRACKING_AUCTIONEER",
    repairvendor = "MINIMAP_TRACKING_REPAIR", stablemaster = "MINIMAP_TRACKING_STABLEMASTER",
    trainer = "MINIMAP_TRACKING_TRAINER_CLASS", barber = "MINIMAP_TRACKING_BARBER",
    transmogrifier = "MINIMAP_TRACKING_TRANSMOGRIFIER", battlemasters = "MINIMAP_TRACKING_BATTLEMASTER",
    pvpquest = "MINIMAP_TRACKING_BATTLEMASTER", upgradevendor = "ITEM_UPGRADE", bank = "BANK",
    vendor = "MERCHANT", voidstorage = "VOID_STORAGE", rare = "ITEM_QUALITY3_DESC",
    craftingorders = "PROFESSIONS_CRAFTING_ORDERS_TAB_NAME",
}
local MAP_KIND_STRINGS = {
    npc = "MAP_KIND_NPC", boat = "MAP_KIND_BOAT", zeppelin = "MAP_KIND_ZEPPELIN",
    portal = "MAP_KIND_PORTAL", tram = "MAP_KIND_TRAM", treasure = "MAP_KIND_TREASURE",
}

local function MapKind(data)
    local cat = data.category
    if cat == "zone" and Enum and Enum.UIMapType and data.zoneMapType == Enum.UIMapType.Continent then
        return _G["CONTINENT"]
    end

    if cat == "npc" and data.npcTitle then return data.npcTitle end
    local g = MAP_KIND_GLOBALS[cat]
    if g and _G[g] then return _G[g] end
    local key = MAP_KIND_STRINGS[cat] or (cat and cat:find("^prof_") and "MAP_KIND_PROF_TRAINER")
    return key and L[key] or nil
end


local function MapSubtext(data)
    local typeLabel = MapKind(data)


    local zone = data.zoneName or data.pathPrefix
    if zone then
        local lastSep = zone:find(">[^>]*$")
        if lastSep then
            zone = zone:sub(lastSep + 1):match("^%s*(.-)%s*$")
        end
    end

    if data.soldName and typeLabel and zone and zone ~= "" then
        return sformat(L["NPC_SUBTEXT_SELLS_FMT"], typeLabel, zone, data.soldName)
    end

    if data.teachesText and data.teachesText ~= "" then
        if zone and zone ~= "" then return sformat(L["NPC_SUBTEXT_TEACHES_FMT"], zone, data.teachesText) end
        return data.teachesText
    end
    if data.matchNote then
        return (zone and zone ~= "") and (data.matchNote .. ", " .. zone) or data.matchNote
    end
    local text = zone or _G["WORLD_MAP"] or "Map"
    if typeLabel and zone and zone ~= "" then
        text = typeLabel .. ": " .. zone
    elseif typeLabel then
        text = typeLabel
    end

    if (data.category == "dungeon" or data.category == "raid") and ns.Characters and ns.Characters.SavedSubtext then
        local saved = ns.Characters.SavedSubtext(data.name, data.instanceID)
        if saved then return text .. ", " .. saved end
    end
    return text
end

function Text:GetFlatSubtext(data)
    if not data then return "" end
    if data.calculatorResult then return L["SUBTEXT_EXPRESSION"] end
    if ns.IsApplicationLauncher and ns.IsApplicationLauncher(data) then
        return L["SUBTEXT_APP"]
    end
    if data.snippetsLauncher then return L["SUBTEXT_SNIPPETS_MENU"] end

    if data.secretFormat then return "" end
    if data.searchCommandDesc then return data.searchCommandDesc end
    if data.holidayStart then return ns.Holidays.Line(data) end
    if data.addonName then return ns.AddOns.Line(data) end
    if data.quickFilterAliasText then return data.quickFilterAliasText end
    if data.quickFilterDef then return data.quickFilterDef.label or L["QUICK_FILTER"] end

    if data.addon then
        local path = data.path
        local last = path and path[#path]
        if last and #path > 1 and last ~= data.addon then return data.addon .. ": " .. last end
        return data.addon
    end

    if data.category == "Boss" and data.instanceName then
        return sformat(L[data.isRaidBoss and "SUBTEXT_RAID_BOSS" or "SUBTEXT_DUNGEON_BOSS"], data.instanceName)
    end
    if data.path and #data.path > 0 then
        return data.path[#data.path]
    end
    if data.mapSearchResult then
        local text = MapSubtext(data)


        if data.nearYards then

            local yd = math.floor(data.nearYards + 0.5)
            local far = ns.GPS and ns.GPS.DistanceText and ns.GPS.DistanceText(yd) or sformat(L["GPS_UNIT_YD"], yd)
            return far .. ", " .. text
        end
        return text
    end
    if data.mountID then return _G["MOUNT"] or "Mount" end
    if data.toyItemID then return _G["TOY"] or "Toy" end
    if data.petID then return _G["PET"] or "Pet" end
    if data.outfitID then return _G["TRANSMOG_OUTFIT_NAME_DEFAULT"] or "Outfit" end
    if data.heirloomItemID then return _G["ITEM_QUALITY7_DESC"] or "Heirloom" end
    if data.transmogSetID then return L["SUBTEXT_APPEARANCE_SET"] end
    if data.appearanceItemID then return L["SUBTEXT_APPEARANCE_ITEM"] end
    if data.itemID and data.category == "Loot" then
        if not data.lootInstanceName then return _G["LOOT"] or "Loot" end
        return sformat(L[data.lootSourceType == "Raid" and "SUBTEXT_RAID_LOOT" or "SUBTEXT_DUNGEON_LOOT"],
            data.lootInstanceName)
    end


    if data.storedSubtext then return data.storedSubtext end

    if data.sourceNote then return data.sourceNote end
    if data.category == "Ability" and data.treeName and data.treeName ~= "" then
        return sformat(L["SUBTEXT_TREE_ABILITY"], data.treeName)
    end




    if data.professionRecipeID or data.classicRecipe then
        return data.professionName or data.category or ""
    end

    local provider = ns.Extensions and ns.Extensions.ProviderOf and ns.Extensions.ProviderOf(data)
    if provider and provider.category == provider.key then return provider.label or "" end
    return data.category or ""
end


local HOLDER_ROWS = { Bag = true, Bank = true, Warband = true, Gear = true, ["Guild Bank"] = true, Mail = true }
local altsOwned, ownedStamp = {}, nil
local GetItemCount = C_Item and C_Item.GetItemCount or _G["GetItemCount"]
local function OwnerLess(a, b) return a.name < b.name end





function Text:OwnedText(data)
    local itemID = data.itemID
    if not itemID or HOLDER_ROWS[data.category] or data.storedHolders or not ns.StoredItemCounts then return nil end
    local byChar, stamp = ns.StoredItemCounts(itemID)
    if stamp ~= ownedStamp then
        wipe(altsOwned)
        ownedStamp = stamp
    end
    local alts = altsOwned[itemID]
    if alts == nil then
        local currentKey, owners = ns.CurrentCharacterKey(), {}
        for charKey, c in pairs(byChar or {}) do
            local count = (c.bags or 0) + (c.bank or 0) + (c.mail or 0) + (c.guild or 0)
            if charKey ~= currentKey and count > 0 and c.name then owners[#owners + 1] = { name = c.name, count = count } end
        end
        table.sort(owners, OwnerLess)
        for i, owner in ipairs(owners) do owners[i] = owner.name .. " " .. owner.count end
        alts = #owners > 0 and table.concat(owners, ", ") or false
        altsOwned[itemID] = alts
    end

    local me = byChar and byChar[ns.CurrentCharacterKey()]
    local mine = (GetItemCount and GetItemCount(itemID, true) or 0) + (me and me.mail or 0)
    if mine > 0 then
        local own = (ns.PlayerName() or "?") .. " " .. mine
        return sformat(L["SUBTEXT_OWNED_FMT"], alts and (own .. ", " .. alts) or own)
    end
    return alts and sformat(L["SUBTEXT_OWNED_FMT"], alts) or nil
end



function Text:GetShownSubtext(data)
    local subtext = self:GetFlatSubtext(data)
    local owned = data and self:OwnedText(data)
    if owned then subtext = subtext ~= "" and (subtext .. ", " .. owned) or owned end

    if data and data.professionRecipeID and ns.SkillUps and ns.SkillUps.OnPage() and ns.ResultHandlers.CanCraft(data) then
        local count = ns.ResultHandlers.CraftableCount(data.professionRecipeID)
        if count and count > 0 then subtext = subtext .. ", " .. sformat(L["SUBTEXT_MAKES_FMT"], count) end
    end

    if data and data.category == "Ability" and data.spellID and ns.Keys then
        local key = ns.Keys.SpellKey(data.spellID, data.spellName)
        if key then
            local text = sformat(L["SUBTEXT_KEY_FMT"], key)
            subtext = subtext ~= "" and (subtext .. ", " .. text) or text
        end
    end
    local part = data and ns.Extensions and ns.Extensions.DecoratorSubtext and ns.Extensions.DecoratorSubtext(data)
    if not part then return subtext end
    return subtext ~= "" and (subtext .. ", " .. part) or part
end
