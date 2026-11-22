-- Options > RPG Mode > Export Progress / Import Progress: moving RPG Mode
-- progress to another computer. Addon data is saved on the computer only
-- (the WTF folder), so the player copies a code on the old one and pastes it
-- on the new one.
--
-- The code holds this character's unlocks (journal pages, bosses found,
-- quests, dungeon maps, trash counted toward a map), the account-wide
-- record (Options > RPG Mode > Account-Wide Unlocks), the journal mode and
-- that option. Importing only ever adds: nothing already unlocked is lost,
-- and an old code can't take anything away. A code is imported only on the
-- character it was made on (name and realm), so it can't unlock a friend's
-- progress.
--
-- Format: "FDJP1:" .. LibDeflate's printable encoding of the deflated text
-- .. ":" .. Adler-32 of the text in base 36. The text: a header line
-- "FDJP <tab> 1 <tab> name <tab> realm <tab> rpg|gamer <tab> 1|0", then
-- one line per entry, tab-separated:
--   K scope dungeon            page unlocked
--   B scope dungeon key        boss found (npc ID, or the boss name in lower case)
--   Q scope questID            quest unlocked
--   M scope dungeon            dungeon map opened
--   T dungeon count            trash counted toward that map (this character)
-- scope: c = this character, a = the account's record.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

do
    local strings = {
        enUS = { OPT_RPG_EXPORT = "Export Progress", OPT_RPG_EXPORT_TIP = "A code with this character's RPG Mode progress, to take it to another computer.",
            OPT_RPG_IMPORT = "Import Progress", OPT_RPG_IMPORT_TIP = "Paste the code from Export Progress on your other computer.",
            RPG_EXPORT_TITLE = "Export Progress", RPG_EXPORT_TEXT = "Switching Computers? Copy this code and paste it once logged in on the other device.",
            RPG_EXPORT_COPY = "Ctrl+A, then Ctrl+C to copy.",
            RPG_IMPORT_TITLE = "Import Progress", RPG_IMPORT_TEXT = "Paste the code from your other computer (Ctrl+V), then press Import.",
            RPG_IMPORT_BUTTON = "Import",
            RPG_IMPORT_DONE = "Progress imported: %d pages, %d bosses, %d quests, %d maps.",
            RPG_IMPORT_NOTHING = "Nothing new to import: this character has all of it already.",
            RPG_IMPORT_BAD = "That code doesn't work. Copy it again, all of it, and paste it here.",
            RPG_IMPORT_OTHER = "This code is from %s. Log in with that character to import it.",
            RPG_EXPORT_ERROR = "Could not build the code." },
        deDE = { OPT_RPG_EXPORT = "Fortschritt exportieren", OPT_RPG_EXPORT_TIP = "Ein Code mit dem RPG-Modus-Fortschritt dieses Charakters, um ihn auf einen anderen Computer mitzunehmen.",
            OPT_RPG_IMPORT = "Fortschritt importieren", OPT_RPG_IMPORT_TIP = "Füge den Code aus „Fortschritt exportieren“ von deinem anderen Computer ein.",
            RPG_EXPORT_TITLE = "Fortschritt exportieren", RPG_EXPORT_TEXT = "Computer wechseln? Kopiere diesen Code und füge ihn ein, sobald du auf dem anderen Gerät eingeloggt bist.",
            RPG_EXPORT_COPY = "Strg+A, dann Strg+C zum Kopieren.",
            RPG_IMPORT_TITLE = "Fortschritt importieren", RPG_IMPORT_TEXT = "Füge den Code von deinem anderen Computer ein (Strg+V) und drücke auf Importieren.",
            RPG_IMPORT_BUTTON = "Importieren",
            RPG_IMPORT_DONE = "Fortschritt importiert: %d Seiten, %d Bosse, %d Quests, %d Karten.",
            RPG_IMPORT_NOTHING = "Nichts Neues zu importieren: Dieser Charakter hat schon alles davon.",
            RPG_IMPORT_BAD = "Dieser Code funktioniert nicht. Kopiere ihn noch einmal vollständig und füge ihn hier ein.",
            RPG_IMPORT_OTHER = "Dieser Code ist von %s. Logge dich mit diesem Charakter ein, um ihn zu importieren.",
            RPG_EXPORT_ERROR = "Der Code konnte nicht erstellt werden." },
        frFR = { OPT_RPG_EXPORT = "Exporter la progression", OPT_RPG_EXPORT_TIP = "Un code avec la progression du mode RPG de ce personnage, pour l'emporter sur un autre ordinateur.",
            OPT_RPG_IMPORT = "Importer la progression", OPT_RPG_IMPORT_TIP = "Collez le code d'Exporter la progression de votre autre ordinateur.",
            RPG_EXPORT_TITLE = "Exporter la progression", RPG_EXPORT_TEXT = "Vous changez d'ordinateur ? Copiez ce code et collez-le une fois connecté sur l'autre appareil.",
            RPG_EXPORT_COPY = "Ctrl+A, puis Ctrl+C pour copier.",
            RPG_IMPORT_TITLE = "Importer la progression", RPG_IMPORT_TEXT = "Collez le code de votre autre ordinateur (Ctrl+V), puis appuyez sur Importer.",
            RPG_IMPORT_BUTTON = "Importer",
            RPG_IMPORT_DONE = "Progression importée : %d pages, %d boss, %d quêtes, %d cartes.",
            RPG_IMPORT_NOTHING = "Rien de nouveau à importer : ce personnage a déjà tout.",
            RPG_IMPORT_BAD = "Ce code ne fonctionne pas. Copiez-le à nouveau en entier et collez-le ici.",
            RPG_IMPORT_OTHER = "Ce code vient de %s. Connectez-vous avec ce personnage pour l'importer.",
            RPG_EXPORT_ERROR = "Impossible de créer le code." },
        esES = { OPT_RPG_EXPORT = "Exportar progreso", OPT_RPG_EXPORT_TIP = "Un código con el progreso del modo RPG de este personaje, para llevarlo a otro ordenador.",
            OPT_RPG_IMPORT = "Importar progreso", OPT_RPG_IMPORT_TIP = "Pega el código de Exportar progreso de tu otro ordenador.",
            RPG_EXPORT_TITLE = "Exportar progreso", RPG_EXPORT_TEXT = "¿Cambias de ordenador? Copia este código y pégalo cuando hayas iniciado sesión en el otro dispositivo.",
            RPG_EXPORT_COPY = "Ctrl+A y luego Ctrl+C para copiar.",
            RPG_IMPORT_TITLE = "Importar progreso", RPG_IMPORT_TEXT = "Pega el código de tu otro ordenador (Ctrl+V) y pulsa Importar.",
            RPG_IMPORT_BUTTON = "Importar",
            RPG_IMPORT_DONE = "Progreso importado: %d páginas, %d jefes, %d misiones, %d mapas.",
            RPG_IMPORT_NOTHING = "Nada nuevo que importar: este personaje ya lo tiene todo.",
            RPG_IMPORT_BAD = "Ese código no funciona. Cópialo de nuevo entero y pégalo aquí.",
            RPG_IMPORT_OTHER = "Este código es de %s. Inicia sesión con ese personaje para importarlo.",
            RPG_EXPORT_ERROR = "No se pudo crear el código." },
        itIT = { OPT_RPG_EXPORT = "Esporta progressi", OPT_RPG_EXPORT_TIP = "Un codice con i progressi della modalità RPG di questo personaggio, per portarli su un altro computer.",
            OPT_RPG_IMPORT = "Importa progressi", OPT_RPG_IMPORT_TIP = "Incolla il codice di Esporta progressi dal tuo altro computer.",
            RPG_EXPORT_TITLE = "Esporta progressi", RPG_EXPORT_TEXT = "Cambi computer? Copia questo codice e incollalo dopo aver effettuato l'accesso sull'altro dispositivo.",
            RPG_EXPORT_COPY = "Ctrl+A, poi Ctrl+C per copiare.",
            RPG_IMPORT_TITLE = "Importa progressi", RPG_IMPORT_TEXT = "Incolla il codice dal tuo altro computer (Ctrl+V), poi premi Importa.",
            RPG_IMPORT_BUTTON = "Importa",
            RPG_IMPORT_DONE = "Progressi importati: %d pagine, %d boss, %d missioni, %d mappe.",
            RPG_IMPORT_NOTHING = "Niente di nuovo da importare: questo personaggio ha già tutto.",
            RPG_IMPORT_BAD = "Questo codice non funziona. Copialo di nuovo per intero e incollalo qui.",
            RPG_IMPORT_OTHER = "Questo codice è di %s. Accedi con quel personaggio per importarlo.",
            RPG_EXPORT_ERROR = "Impossibile creare il codice." },
        ptBR = { OPT_RPG_EXPORT = "Exportar progresso", OPT_RPG_EXPORT_TIP = "Um código com o progresso do modo RPG deste personagem, para levá-lo a outro computador.",
            OPT_RPG_IMPORT = "Importar progresso", OPT_RPG_IMPORT_TIP = "Cole o código de Exportar progresso do seu outro computador.",
            RPG_EXPORT_TITLE = "Exportar progresso", RPG_EXPORT_TEXT = "Trocando de computador? Copie este código e cole-o quando entrar no outro dispositivo.",
            RPG_EXPORT_COPY = "Ctrl+A e depois Ctrl+C para copiar.",
            RPG_IMPORT_TITLE = "Importar progresso", RPG_IMPORT_TEXT = "Cole o código do seu outro computador (Ctrl+V) e clique em Importar.",
            RPG_IMPORT_BUTTON = "Importar",
            RPG_IMPORT_DONE = "Progresso importado: %d páginas, %d chefes, %d missões, %d mapas.",
            RPG_IMPORT_NOTHING = "Nada novo para importar: este personagem já tem tudo.",
            RPG_IMPORT_BAD = "Esse código não funciona. Copie-o de novo por inteiro e cole aqui.",
            RPG_IMPORT_OTHER = "Este código é de %s. Entre com esse personagem para importá-lo.",
            RPG_EXPORT_ERROR = "Não foi possível criar o código." },
        ruRU = { OPT_RPG_EXPORT = "Экспорт прогресса", OPT_RPG_EXPORT_TIP = "Код с прогрессом режима RPG этого персонажа, чтобы перенести его на другой компьютер.",
            OPT_RPG_IMPORT = "Импорт прогресса", OPT_RPG_IMPORT_TIP = "Вставьте код из «Экспорт прогресса» с другого компьютера.",
            RPG_EXPORT_TITLE = "Экспорт прогресса", RPG_EXPORT_TEXT = "Меняете компьютер? Скопируйте этот код и вставьте его, когда войдёте в игру на другом устройстве.",
            RPG_EXPORT_COPY = "Ctrl+A, затем Ctrl+C, чтобы скопировать.",
            RPG_IMPORT_TITLE = "Импорт прогресса", RPG_IMPORT_TEXT = "Вставьте код с другого компьютера (Ctrl+V) и нажмите «Импорт».",
            RPG_IMPORT_BUTTON = "Импорт",
            RPG_IMPORT_DONE = "Прогресс импортирован: страниц %d, боссов %d, заданий %d, карт %d.",
            RPG_IMPORT_NOTHING = "Нечего импортировать: у этого персонажа всё это уже есть.",
            RPG_IMPORT_BAD = "Этот код не работает. Скопируйте его ещё раз целиком и вставьте сюда.",
            RPG_IMPORT_OTHER = "Этот код от персонажа %s. Войдите этим персонажем, чтобы импортировать его.",
            RPG_EXPORT_ERROR = "Не удалось создать код." },
        koKR = { OPT_RPG_EXPORT = "진행 상황 내보내기", OPT_RPG_EXPORT_TIP = "이 캐릭터의 RPG 모드 진행 상황 코드입니다. 다른 컴퓨터로 옮길 때 사용합니다.",
            OPT_RPG_IMPORT = "진행 상황 가져오기", OPT_RPG_IMPORT_TIP = "다른 컴퓨터의 진행 상황 내보내기 코드를 붙여넣으세요.",
            RPG_EXPORT_TITLE = "진행 상황 내보내기", RPG_EXPORT_TEXT = "컴퓨터를 바꾸시나요? 이 코드를 복사해 다른 기기에서 접속한 뒤 붙여넣으세요.",
            RPG_EXPORT_COPY = "Ctrl+A, Ctrl+C로 복사하세요.",
            RPG_IMPORT_TITLE = "진행 상황 가져오기", RPG_IMPORT_TEXT = "다른 컴퓨터의 코드를 붙여넣고(Ctrl+V) 가져오기를 누르세요.",
            RPG_IMPORT_BUTTON = "가져오기",
            RPG_IMPORT_DONE = "진행 상황을 가져왔습니다: 페이지 %d, 우두머리 %d, 퀘스트 %d, 지도 %d.",
            RPG_IMPORT_NOTHING = "가져올 새 내용이 없습니다: 이 캐릭터는 이미 모두 가지고 있습니다.",
            RPG_IMPORT_BAD = "이 코드는 작동하지 않습니다. 코드 전체를 다시 복사해 여기에 붙여넣으세요.",
            RPG_IMPORT_OTHER = "이 코드는 %s의 코드입니다. 그 캐릭터로 접속해서 가져오세요.",
            RPG_EXPORT_ERROR = "코드를 만들 수 없습니다." },
        zhCN = { OPT_RPG_EXPORT = "导出进度", OPT_RPG_EXPORT_TIP = "包含此角色RPG模式进度的代码，用于转移到另一台电脑。",
            OPT_RPG_IMPORT = "导入进度", OPT_RPG_IMPORT_TIP = "粘贴另一台电脑上“导出进度”生成的代码。",
            RPG_EXPORT_TITLE = "导出进度", RPG_EXPORT_TEXT = "要换电脑吗？复制此代码，在另一台设备上登录后粘贴。",
            RPG_EXPORT_COPY = "按 Ctrl+A，再按 Ctrl+C 复制。",
            RPG_IMPORT_TITLE = "导入进度", RPG_IMPORT_TEXT = "粘贴另一台电脑上的代码（Ctrl+V），然后点击导入。",
            RPG_IMPORT_BUTTON = "导入",
            RPG_IMPORT_DONE = "进度已导入：%d 个页面，%d 个首领，%d 个任务，%d 张地图。",
            RPG_IMPORT_NOTHING = "没有可导入的新内容：此角色已经全部拥有。",
            RPG_IMPORT_BAD = "此代码无效。请重新完整复制并粘贴到这里。",
            RPG_IMPORT_OTHER = "此代码来自 %s。请用该角色登录后导入。",
            RPG_EXPORT_ERROR = "无法生成代码。" },
        zhTW = { OPT_RPG_EXPORT = "匯出進度", OPT_RPG_EXPORT_TIP = "包含此角色RPG模式進度的代碼，用於轉移到另一台電腦。",
            OPT_RPG_IMPORT = "匯入進度", OPT_RPG_IMPORT_TIP = "貼上另一台電腦上「匯出進度」產生的代碼。",
            RPG_EXPORT_TITLE = "匯出進度", RPG_EXPORT_TEXT = "要換電腦嗎？複製此代碼，在另一台裝置上登入後貼上。",
            RPG_EXPORT_COPY = "按 Ctrl+A，再按 Ctrl+C 複製。",
            RPG_IMPORT_TITLE = "匯入進度", RPG_IMPORT_TEXT = "貼上另一台電腦上的代碼（Ctrl+V），然後點擊匯入。",
            RPG_IMPORT_BUTTON = "匯入",
            RPG_IMPORT_DONE = "進度已匯入：%d 個頁面，%d 個首領，%d 個任務，%d 張地圖。",
            RPG_IMPORT_NOTHING = "沒有可匯入的新內容：此角色已經全部擁有。",
            RPG_IMPORT_BAD = "此代碼無效。請重新完整複製並貼到這裡。",
            RPG_IMPORT_OTHER = "此代碼來自 %s。請用該角色登入後匯入。",
            RPG_EXPORT_ERROR = "無法產生代碼。" },
    }
    strings.esMX = strings.esES
    for locale, entries in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for key, value in pairs(entries) do
                if t[key] == nil then t[key] = value end
            end
        end
    end
end

local function L(key, ...)
    if FDJ.L then return FDJ.L(key, ...) end
    return key
end

local function Say(text)
    print("|cffd8a83cDungeon Journal:|r " .. text)
end

local function Lib()
    return (LibStub and LibStub:GetLibrary("LibDeflate", true)) or _G.FDJLibDeflate
end

local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"
local function Base36(n)
    n = math.floor(tonumber(n) or 0)
    if n <= 0 then return "0" end
    local out = ""
    while n > 0 do
        local d = n % 36
        out = B36:sub(d + 1, d + 1) .. out
        n = math.floor(n / 36)
    end
    return out
end

local KEYS = { K = "rpgKills", B = "rpgBosses", Q = "rpgQuests", M = "rpgMaps" }

local function CharDB()
    if type(ForeverDungeonJournalCharacterDB) ~= "table" then ForeverDungeonJournalCharacterDB = {} end
    return ForeverDungeonJournalCharacterDB
end

local function AccountDB()
    if FDJ.RPGAccountProgress then return FDJ.RPGAccountProgress() end
    if type(ForeverDungeonJournalDB) ~= "table" then ForeverDungeonJournalDB = {} end
    local acc = ForeverDungeonJournalDB.rpgAccount
    if type(acc) ~= "table" then
        acc = {}
        ForeverDungeonJournalDB.rpgAccount = acc
    end
    for _, key in pairs(KEYS) do
        if type(acc[key]) ~= "table" then acc[key] = {} end
    end
    return acc
end

local function Clean(s)
    return (tostring(s or ""):gsub("[\t\n\r]", " "))
end

local function Me()
    local name = UnitName and UnitName("player") or nil
    local realm = GetRealmName and GetRealmName() or nil
    if type(issecretvalue) == "function" and (issecretvalue(name) or issecretvalue(realm)) then return nil, nil end
    return name, realm
end

local function SameRealm(a, b)
    local function N(s) return (tostring(s or ""):lower():gsub("[%s%-']", "")) end
    return N(a) == N(b)
end

-- ------------------------------------------------------------------ export
local function Lines(out, scope, db)
    local function Sorted(t)
        local keys = {}
        for k, v in pairs(t) do if v then keys[#keys + 1] = k end end
        table.sort(keys, function(x, y) return tostring(x) < tostring(y) end)
        return keys
    end
    if type(db.rpgKills) == "table" then
        for _, name in ipairs(Sorted(db.rpgKills)) do out[#out + 1] = "K\t" .. scope .. "\t" .. Clean(name) end
    end
    if type(db.rpgMaps) == "table" then
        for _, name in ipairs(Sorted(db.rpgMaps)) do out[#out + 1] = "M\t" .. scope .. "\t" .. Clean(name) end
    end
    if type(db.rpgQuests) == "table" then
        for _, id in ipairs(Sorted(db.rpgQuests)) do
            if tonumber(id) then out[#out + 1] = "Q\t" .. scope .. "\t" .. tostring(id) end
        end
    end
    if type(db.rpgBosses) == "table" then
        for _, name in ipairs(Sorted(db.rpgBosses)) do
            local seen = db.rpgBosses[name]
            if type(seen) == "table" then
                for _, key in ipairs(Sorted(seen)) do
                    out[#out + 1] = "B\t" .. scope .. "\t" .. Clean(name) .. "\t" .. Clean(key)
                end
            end
        end
    end
end

function FDJ.BuildProgressCode()
    local lib = Lib()
    assert(lib, "LibDeflate unavailable")
    if FDJ.RPGShareProgress then pcall(FDJ.RPGShareProgress) end
    local name, realm = Me()
    assert(name and realm, "character unknown")
    local db = CharDB()
    local rpg = FDJ.IsRPGMode and FDJ.IsRPGMode() or false
    local wide = FDJ.RPGOption and FDJ.RPGOption("accountWide") or false
    local out = { table.concat({ "FDJP", "1", Clean(name), Clean(realm), rpg and "rpg" or "gamer", wide and "1" or "0" }, "\t") }
    Lines(out, "c", db)
    if type(db.rpgTrash) == "table" then
        local names = {}
        for dungeon, rec in pairs(db.rpgTrash) do
            if type(rec) == "table" and tonumber(rec.n) and rec.n > 0 then names[#names + 1] = dungeon end
        end
        table.sort(names)
        for _, dungeon in ipairs(names) do
            out[#out + 1] = "T\t" .. Clean(dungeon) .. "\t" .. tostring(math.floor(db.rpgTrash[dungeon].n))
        end
    end
    Lines(out, "a", AccountDB())
    local text = table.concat(out, "\n")
    local packed = lib:EncodeForPrint(lib:CompressDeflate(text, { level = 9 }))
    return "FDJP1:" .. packed .. ":" .. Base36(lib:Adler32(text))
end

-- ------------------------------------------------------------------ import
-- Returns the decoded text, or nil if the code is broken.
local function Decode(code)
    local lib = Lib()
    if not lib or type(code) ~= "string" then return nil end
    code = code:gsub("%s+", "")
    local packed, sum = code:match("^FDJP1:([%w%(%)]+):(%w+)$")
    if not packed then return nil end
    local raw = lib:DecodeForPrint(packed)
    if not raw then return nil end
    local text = lib:DecompressDeflate(raw)
    if type(text) ~= "string" then return nil end
    if Base36(lib:Adler32(text)) ~= sum then return nil end
    return text
end

local function Parse(text)
    local data = { entries = {} }
    local first = true
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if line ~= "" then
            local f = {}
            for field in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = field end
            if first then
                if f[1] ~= "FDJP" or f[2] ~= "1" then return nil end
                data.name, data.realm, data.mode, data.wide = f[3], f[4], f[5], f[6] == "1"
                first = false
            else
                data.entries[#data.entries + 1] = f
            end
        end
    end
    if first or not data.name or data.name == "" then return nil end
    return data
end

-- Adds the code's unlocks; counts what is new (to this character or the
-- account's record).
local function Merge(data)
    local char, acc = CharDB(), AccountDB()
    local function Target(scope, key)
        local db = scope == "a" and acc or char
        if type(db[key]) ~= "table" then db[key] = {} end
        return db[key]
    end
    local newPages, newBosses, newQuests, newMaps = {}, {}, {}, {}
    local any = false
    for _, f in ipairs(data.entries) do
        local kind, scope = f[1], f[2]
        if kind == "K" and f[3] and f[3] ~= "" then
            local t = Target(scope, "rpgKills")
            if not t[f[3]] then t[f[3]] = true newPages[f[3]] = true any = true end
        elseif kind == "M" and f[3] and f[3] ~= "" then
            local t = Target(scope, "rpgMaps")
            if not t[f[3]] then t[f[3]] = true newMaps[f[3]] = true any = true end
        elseif kind == "Q" then
            local id = tonumber(f[3])
            if id then
                local t = Target(scope, "rpgQuests")
                if not t[id] then t[id] = true newQuests[id] = true any = true end
            end
        elseif kind == "B" and f[3] and f[3] ~= "" and f[4] and f[4] ~= "" then
            local t = Target(scope, "rpgBosses")
            if type(t[f[3]] ) ~= "table" then t[f[3]] = {} end
            local key = tonumber(f[4]) or f[4]
            if not t[f[3]][key] then
                t[f[3]][key] = true
                any = true
                -- a boss is saved under its NPC ID and its name: count names
                if type(key) == "string" then newBosses[f[3] .. "\t" .. key] = true end
            end
        elseif kind == "T" and f[2] and f[2] ~= "" then
            -- T dungeon count: this character's trash counted toward the map
            local n = tonumber(f[3])
            if n and n > 0 then
                if type(char.rpgTrash) ~= "table" then char.rpgTrash = {} end
                local rec = char.rpgTrash[f[2]]
                if type(rec) ~= "table" then
                    rec = { n = 0, seen = {} }
                    char.rpgTrash[f[2]] = rec
                end
                if type(rec.seen) ~= "table" then rec.seen = {} end
                if (tonumber(rec.n) or 0) < n then rec.n = n any = true end
            end
        end
    end
    local function Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
    local changed = any
    if data.mode == "rpg" and FDJ.IsRPGMode and not FDJ.IsRPGMode() and FDJ.SetJournalMode then
        FDJ.SetJournalMode("rpg")
        changed = true
    end
    if data.wide and FDJ.RPGOption and not FDJ.RPGOption("accountWide") and FDJ.SetRPGOption then
        FDJ.SetRPGOption("accountWide", true)
        changed = true
    end
    if FDJ.RPGShareProgress then pcall(FDJ.RPGShareProgress) end
    if changed then
        if FDJ.RPGStateChanged then pcall(FDJ.RPGStateChanged) end
        if FDJ.RefreshHomeCards then pcall(FDJ.RefreshHomeCards) end
        if FDJ.RefreshSettingsChecks then pcall(FDJ.RefreshSettingsChecks) end
    end
    return any, Count(newPages), Count(newBosses), Count(newQuests), Count(newMaps)
end

-- Returns true and the message on success, or false and the message.
function FDJ.ImportProgressCode(code)
    local text = Decode(code)
    local data = text and Parse(text)
    if not data then return false, L("RPG_IMPORT_BAD") end
    local name, realm = Me()
    if not name or tostring(data.name):lower() ~= tostring(name):lower() or not SameRealm(data.realm, realm) then
        return false, L("RPG_IMPORT_OTHER", tostring(data.name) .. " - " .. tostring(data.realm))
    end
    local any, pages, bosses, quests, maps = Merge(data)
    if not any then return true, L("RPG_IMPORT_NOTHING") end
    return true, L("RPG_IMPORT_DONE", pages, bosses, quests, maps)
end

-- ---------------------------------------------------------------------- UI
local function Window(name, height)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(520, height)
    f:SetPoint("CENTER")
    -- Opened from the Options panel (FULLSCREEN_DIALOG): same layer, on top of it.
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0.02, 0.02, 0.02, 0.95)
        f:SetBackdropBorderColor(0.34, 0.34, 0.34, 1)
    end
    f.title = f:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -14)
    f.text = f:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    f.text:SetPoint("TOP", f.title, "BOTTOM", 0, -8)
    f.text:SetWidth(470)
    f.text:SetJustifyH("CENTER")

    -- The box sits under the message, however many lines it wraps to.
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOP", f.text, "BOTTOM", 0, -12)
    scroll:SetPoint("LEFT", f, "LEFT", 22, 0)
    scroll:SetPoint("RIGHT", f, "RIGHT", -40, 0)
    scroll:SetPoint("BOTTOM", f, "BOTTOM", 0, 50)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetMaxLetters(0)
    box:SetFontObject("ForeverDJ_GameFontHighlightSmall")
    box:SetWidth(450)
    box:SetAutoFocus(false)
    box:SetTextInsets(4, 4, 4, 4)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    scroll:SetScrollChild(box)
    f.box = box
    f.scroll = scroll

    local bg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", scroll, -6, 6)
    bg:SetPoint("BOTTOMRIGHT", scroll, 26, -6)
    bg:SetFrameLevel(math.max(0, scroll:GetFrameLevel() - 1))
    f.bg = bg
    if bg.SetBackdrop then
        bg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        bg:SetBackdropColor(0, 0, 0, 0.6)
        bg:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
    end
    -- Clicking anywhere in the box puts the cursor in it.
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function() box:SetFocus() end)

    f.foot = f:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontDisableSmall")
    f.foot:SetPoint("BOTTOMLEFT", 22, 22)
    f.foot:SetPoint("RIGHT", f, "RIGHT", -200, 0)
    f.foot:SetJustifyH("LEFT")

    f.close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    FDJ.OwnFonts(f.close) -- ownfonts (2.0.8)
    f.close:SetSize(90, 22)
    f.close:SetPoint("BOTTOMRIGHT", -16, 14)
    f.close:SetText(CLOSE or "Close")
    f.close:SetScript("OnClick", function() f:Hide() end)

    tinsert(UISpecialFrames, name) -- Escape closes it
    return f
end

local exportWindow, importWindow

-- Shown above the Options panel (and anything else in its layer).
local function OnTop(f)
    local options = _G.ForeverDungeonJournalSettings
    local level = options and options.GetFrameLevel and options:GetFrameLevel() or 0
    f:SetFrameLevel(math.max(f:GetFrameLevel(), level + 30))
    if f.Raise then f:Raise() end
    -- Its own parts in order: the box's backdrop, the box, its scroll bar, the buttons.
    local base = f:GetFrameLevel()
    if f.bg then f.bg:SetFrameLevel(base + 1) end
    if f.scroll then
        f.scroll:SetFrameLevel(base + 2)
        local bar = f.scroll.ScrollBar
        if type(bar) == "table" and bar.SetFrameLevel then bar:SetFrameLevel(base + 4) end
    end
    if f.box then f.box:SetFrameLevel(base + 3) end
    if f.close then f.close:SetFrameLevel(base + 2) end
    if f.import then f.import:SetFrameLevel(base + 2) end
end

function FDJ.ShowProgressExport()
    local ok, code = pcall(FDJ.BuildProgressCode)
    if not ok or type(code) ~= "string" then
        Say(L("RPG_EXPORT_ERROR"))
        return
    end
    if importWindow then importWindow:Hide() end
    if not exportWindow then
        exportWindow = Window("FDJProgressExportFrame", 250)
        -- Typing into it would only break the code, so put it straight back.
        exportWindow.box:SetScript("OnTextChanged", function(self, byUser)
            if byUser then
                self:SetText(exportWindow.code or "")
                self:HighlightText()
            end
        end)
    end
    local f = exportWindow
    f.title:SetText(L("RPG_EXPORT_TITLE"))
    f.text:SetText(L("RPG_EXPORT_TEXT"))
    f.foot:SetText(L("RPG_EXPORT_COPY"))
    f.code = code
    f.box:SetText(code)
    f:Show()
    OnTop(f)
    f.box:SetFocus()
    f.box:HighlightText()
end

function FDJ.ShowProgressImport()
    if exportWindow then exportWindow:Hide() end
    if not importWindow then
        importWindow = Window("FDJProgressImportFrame", 250)
        local f = importWindow
        f.import = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        FDJ.OwnFonts(f.import) -- ownfonts (2.0.8)
        f.import:SetSize(110, 22)
        f.import:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
        f.import:SetScript("OnClick", function()
            local done, message = FDJ.ImportProgressCode(f.box:GetText())
            Say(message)
            if done then
                f:Hide()
            else
                f.foot:SetText("|cffff5555" .. message .. "|r")
            end
        end)
        f.box:SetScript("OnTextChanged", function()
            f.foot:SetText("")
        end)
    end
    local f = importWindow
    f.title:SetText(L("RPG_IMPORT_TITLE"))
    f.text:SetText(L("RPG_IMPORT_TEXT"))
    f.import:SetText(L("RPG_IMPORT_BUTTON"))
    f.foot:SetText("")
    f.box:SetText("")
    f:Show()
    OnTop(f)
    f.box:SetFocus()
end
