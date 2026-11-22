local _, ns = ...








local ThemeShare = {}
ns.ThemeShare = ThemeShare


local Utils = ns.Utils
local L = ns.L

local pairs, type, tonumber = pairs, type, tonumber
local tinsert = Utils.tinsert
local tremove = Utils.tremove
local tsort = Utils.tsort
local tconcat = Utils.tconcat
local sformat = Utils.sformat

local CODE_PREFIX = "EFT1!"
local PAYLOAD_MARKER = "EFTHEME1"
local NAME_MAX = 24


local SHIPPED_TEXTURE_PREFIX = "Interface\\AddOns\\EasyFind\\textures\\"





local COLOR_SLOTS = {
    { key = "windowFill",       required = true },
    { key = "windowFillBottom" },
    { key = "windowFillTop" },
    { key = "pathColor",        required = true },
    { key = "pathColorHover",   required = true },
    { key = "leafColor",        required = true },
    { key = "chromeGlyph",      required = true },
    { key = "mutedGlyph",       required = true },
    { key = "textFaint",        required = true },
    { key = "accent",           required = true },
    { key = "controlAccent" },
    { key = "rowHover" },
    { key = "borderColor" },
    { key = "selection",        required = true },
    { key = "separator",        required = true },
    { key = "backdropColor",    required = true },
    { key = "backdropBorder",   required = true },
}
ThemeShare.COLOR_SLOTS = COLOR_SLOTS



local BUILTIN_THEMES = {}
do
    local order = ns.UI_THEME_ORDER or {}
    for i = 1, #order do BUILTIN_THEMES[order[i]] = true end
end

local BUILTIN_THEMES_LOWER = {}
for builtinName in pairs(BUILTIN_THEMES) do
    BUILTIN_THEMES_LOWER[builtinName:lower()] = true
end

local function IsBuiltinTheme(name)
    return BUILTIN_THEMES[name] == true
end



function ThemeShare:IsBuiltinName(name)
    if type(name) ~= "string" then return false end
    local trimmed = name:match("^%s*(.-)%s*$") or name
    return BUILTIN_THEMES_LOWER[trimmed:lower()] == true
end

local function CustomStore()
    if not (EasyFind and EasyFind.db) then return nil end
    EasyFind.db.customThemes = EasyFind.db.customThemes or {}
    return EasyFind.db.customThemes
end




local function SanitizeName(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("|", ""):gsub("[%c]", "")
    name = name:match("^%s*(.-)%s*$") or ""
    if #name == 0 then return nil end
    if #name > NAME_MAX then name = name:sub(1, NAME_MAX) end
    return name
end

local function ValidColor(c, minLen)
    if type(c) ~= "table" then return nil end
    local out = {}
    for i = 1, 4 do
        local ch = c[i]
        if ch == nil then break end
        ch = tonumber(ch)
        if not ch or ch < 0 or ch > 1.5 then return nil end
        out[i] = ch
    end
    if #out < (minLen or 3) then return nil end
    return out
end


local SURFACE_ID_MAX = 32
local function ValidSurfaceID(id)
    return type(id) == "string" and #id > 0 and #id <= SURFACE_ID_MAX and id:match("^[%w_%-]+$") ~= nil
end
ThemeShare.ValidSurfaceID = ValidSurfaceID





local function ValidatePalette(raw, nested)
    if type(raw) ~= "table" then return nil, "not a table" end
    local clean = {}
    for i = 1, #COLOR_SLOTS do
        local slot = COLOR_SLOTS[i]
        local color = raw[slot.key]
        if color ~= nil then
            local valid = ValidColor(color, 3)
            if not valid then return nil, "bad color: " .. slot.key end
            clean[slot.key] = valid
        elseif slot.required then
            return nil, "missing slot: " .. slot.key
        end
    end
    if raw.light then clean.light = true end
    if raw.borderHidden then clean.borderHidden = true end
    if type(raw.fillTexture) == "string"
       and raw.fillTexture:sub(1, #SHIPPED_TEXTURE_PREFIX) == SHIPPED_TEXTURE_PREFIX then
        clean.fillTexture = raw.fillTexture
    end
    if not nested and type(raw.surfaces) == "table" then
        for id, look in pairs(raw.surfaces) do
            local own = ValidSurfaceID(id) and ValidatePalette(look, true)
            if own then
                clean.surfaces = clean.surfaces or {}
                clean.surfaces[id] = own
            end
        end
    end
    return clean
end
ThemeShare.ValidatePalette = ValidatePalette




function ThemeShare:RegisterCustomThemes()
    local store = CustomStore()
    if not store then return end


    local names, cleaned, dropped, seen = {}, {}, {}, {}
    for name, raw in pairs(store) do
        local cleanName = SanitizeName(name)
        local palette = cleanName and select(1, ValidatePalette(raw))
        if cleanName and palette and not IsBuiltinTheme(cleanName) and not seen[cleanName] then
            seen[cleanName] = true
            names[#names + 1] = cleanName
            cleaned[cleanName] = palette
            if cleanName ~= name then dropped[#dropped + 1] = name end
        else
            dropped[#dropped + 1] = name
        end
    end
    for i = 1, #dropped do store[dropped[i]] = nil end
    for name, palette in pairs(cleaned) do
        store[name] = palette
        ns.UI_THEME_PALETTES[name] = palette
    end
    tsort(names)


    local order = ns.UI_THEME_ORDER
    for i = #order, 1, -1 do
        if not IsBuiltinTheme(order[i]) then tremove(order, i) end
    end
    for i = 1, #names do
        tinsert(order, names[i])
    end
end



function ThemeShare:SaveCustomTheme(name, rawPalette)
    local store = CustomStore()
    if not store then return nil, "no db" end
    name = SanitizeName(name)
    if not name then return nil, "bad name" end
    local palette, err = ValidatePalette(rawPalette)
    if not palette then return nil, err end
    local finalName, n = name, 2
    while IsBuiltinTheme(finalName) do
        finalName = name .. " " .. n
        n = n + 1
    end
    store[finalName] = palette
    self:RegisterCustomThemes()
    return finalName
end

function ThemeShare:DeleteCustomTheme(name)
    local store = CustomStore()
    if not (store and store[name]) then return false end
    store[name] = nil
    ns.UI_THEME_PALETTES[name] = nil
    self:RegisterCustomThemes()
    if EasyFind.db.uiTheme == name then
        local fallback = (ns.DB_DEFAULTS and ns.DB_DEFAULTS.uiTheme) or "Black"
        EasyFind.db.uiTheme = fallback
        if ns.ApplyUITheme then ns.ApplyUITheme(fallback) end
    end
    return true
end

function ThemeShare:IsCustomTheme(name)
    local store = EasyFind and EasyFind.db and EasyFind.db.customThemes
    return (store and store[name]) ~= nil
end



function ThemeShare:Export(name)
    local palette = ns.UI_THEME_PALETTES and ns.UI_THEME_PALETTES[name]
    return self:ExportPalette(name, palette)
end


local function EncodeLook(parts, encS, palette)
    parts[#parts + 1] = encS(palette.light and "1" or "0")
    parts[#parts + 1] = encS(palette.borderHidden and "1" or "0")
    parts[#parts + 1] = encS(palette.fillTexture or "")
    local colorParts = {}
    for i = 1, #COLOR_SLOTS do
        local key = COLOR_SLOTS[i].key
        local color = palette[key]
        if color then
            colorParts[#colorParts + 1] = { key = key, color = color }
        end
    end
    parts[#parts + 1] = encS(#colorParts)
    for i = 1, #colorParts do
        local entry = colorParts[i]
        parts[#parts + 1] = encS(entry.key)
        parts[#parts + 1] = encS(#entry.color)
        for c = 1, #entry.color do

            parts[#parts + 1] = encS(sformat("%.4f", entry.color[c]))
        end
    end
end




function ThemeShare:ExportPalette(name, palette)
    if not (name and palette) then return nil end
    local codec = ns.ShareCodec
    if not codec then return nil end
    local encS = codec.encS
    local parts = { PAYLOAD_MARKER, encS(name) }
    EncodeLook(parts, encS, palette)
    local ids = {}
    for id in pairs(palette.surfaces or {}) do
        if ValidSurfaceID(id) then ids[#ids + 1] = id end
    end
    if #ids > 0 then
        tsort(ids)
        parts[#parts + 1] = encS("S")
        parts[#parts + 1] = encS(#ids)
        for i = 1, #ids do
            parts[#parts + 1] = encS(ids[i])
            EncodeLook(parts, encS, palette.surfaces[ids[i]])
        end
    end
    return CODE_PREFIX .. codec.base64enc(tconcat(parts))
end


function ThemeShare:Decode(str)
    if type(str) ~= "string" then return nil end
    local codec = ns.ShareCodec
    if not codec then return nil end
    local b64 = str:match("^%s*EFT1!(.+)$")
    if not b64 then return nil end
    local ok, blob = pcall(codec.base64dec, b64)
    if not ok or type(blob) ~= "string" or blob:sub(1, #PAYLOAD_MARKER) ~= PAYLOAD_MARKER then
        return nil
    end
    local decS = codec.decS
    local name, pos = decS(blob, #PAYLOAD_MARKER + 1)
    if not name then return nil end
    local palette
    palette, pos = self.DecodeLook(decS, blob, pos)
    if not palette then return nil end
    local marker, countPos = decS(blob, pos)
    if marker == "S" then
        local countStr
        countStr, pos = decS(blob, countPos)
        local count = tonumber(countStr) or 0
        if count < 0 or count > 64 then return nil end
        for _ = 1, count do
            local id, look
            id, pos = decS(blob, pos)
            if not id then return nil end
            look, pos = self.DecodeLook(decS, blob, pos)
            if not look then return nil end
            palette.surfaces = palette.surfaces or {}
            palette.surfaces[id] = look
        end
    end
    return name, palette
end



function ThemeShare.DecodeLook(decS, blob, pos)
    local lightFlag, borderFlag, fillTexture, slotCountStr
    lightFlag, pos = decS(blob, pos)
    borderFlag, pos = decS(blob, pos)
    fillTexture, pos = decS(blob, pos)
    slotCountStr, pos = decS(blob, pos)
    local slotCount = tonumber(slotCountStr) or 0
    if slotCount <= 0 or slotCount > #COLOR_SLOTS then return nil end
    local palette = {}
    if lightFlag == "1" then palette.light = true end
    if borderFlag == "1" then palette.borderHidden = true end
    if fillTexture and #fillTexture > 0 then palette.fillTexture = fillTexture end
    for _ = 1, slotCount do
        local key, chCountStr
        key, pos = decS(blob, pos)
        if not key then return nil end
        chCountStr, pos = decS(blob, pos)
        local chCount = tonumber(chCountStr) or 0
        if chCount < 3 or chCount > 4 then return nil end
        local color = {}
        for c = 1, chCount do
            local chStr
            chStr, pos = decS(blob, pos)
            if not chStr then return nil end
            color[c] = tonumber(chStr)
        end
        palette[key] = color
    end
    return palette, pos
end



function ThemeShare:Import(str)
    local name, rawPalette = self:Decode(str)
    if not name then return nil end
    return self:SaveCustomTheme(name, rawPalette)
end



function ThemeShare:ShowImportDialog(opts)
    ns.ShowPasteDialog({
        title = L["OPT_IMPORT_THEME"],
        onAccept = function(code)
            local name = ThemeShare:Import(code)
            if not name then
                if EasyFind and EasyFind.Print then EasyFind:Print(L["SHORTKEY_IMPORT_BAD"]) end
                return
            end
            if opts and opts.onImported then
                pcall(opts.onImported, name)
            end
        end,
    })
end

function ThemeShare:ShowExportDialog(name)
    local code = self:Export(name)
    if code then Utils.CopyToClipboard(code) end
end

return ThemeShare
