-- Journal modes (chosen per character in a window shown once at login):
--   * Gamer Mode: the usual journal, everything visible.
--   * RPG Mode:   a progression journal. Every dungeon starts locked (dark
--                 cover, padlock, nothing to read) and unlocks once this
--                 character has defeated its final boss. A progress bar on
--                 the home page fills to 100% as the character finishes every
--                 quest it can take (own faction and class) in every dungeon.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local function L(key, ...)
    if FDJ.L then return FDJ.L(key, ...) end
    return key
end

local function CharDB()
    ForeverDungeonJournalCharacterDB = ForeverDungeonJournalCharacterDB or {}
    local db = ForeverDungeonJournalCharacterDB
    if type(db.rpgKills) ~= "table" then db.rpgKills = {} end
    return db
end

local function Plain(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
    return v
end

-- ------------------------------------------------------------ RPG options
-- Options > RPG Mode (account-wide): hide the quest or the boss (page)
-- achievement popups, mute their fanfare, and its volume (85% by default).
-- WoW plays a sound at its channel's volume only, so a quieter fanfare is
-- played on the Dialog channel with that channel's volume set to the
-- chosen share for a few seconds, then put back (also at the next login,
-- should the game close in between).
local RPG_DEFAULT_VOLUME = 85
function FDJ.RPGOption(key)
    local db = ForeverDungeonJournalDB
    local o = db and type(db.rpgOptions) == "table" and db.rpgOptions or {}
    if key == "volume" then
        local v = tonumber(o.volume)
        return v and math.max(0, math.min(100, v)) or RPG_DEFAULT_VOLUME
    end
    -- rpglegacy (2.0.8, M): Account-Wide Unlocks is on unless switched off
    -- (saved as false from now on; before, off was simply not saved).
    if key == "accountWide" and o.accountWide == nil then return true end
    return o[key] == true
end
function FDJ.SetRPGOption(key, value)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    if type(ForeverDungeonJournalDB.rpgOptions) ~= "table" then ForeverDungeonJournalDB.rpgOptions = {} end
    local o = ForeverDungeonJournalDB.rpgOptions
    if key == "volume" then
        o.volume = math.floor((tonumber(value) or RPG_DEFAULT_VOLUME) + 0.5)
    elseif key == "accountWide" then
        o.accountWide = value and true or false -- rpglegacy: on by default, so off is kept
    else
        o[key] = value and true or nil
    end
    if key == "accountWide" then
        if FDJ.RPGLegacyRefresh then pcall(FDJ.RPGLegacyRefresh) end -- rpglegacy: read (or stop reading) the Legacy Challenges
        if FDJ.RPGShareProgress then pcall(FDJ.RPGShareProgress) end
        if FDJ.RPGStateChanged then pcall(FDJ.RPGStateChanged) end
        if FDJ.RefreshHomeCards then pcall(FDJ.RefreshHomeCards) end
    end
    -- showquests (2.0.16): every page's quests come and go at once.
    if key == "showQuests" then
        if FDJ.ResetSearchCache then pcall(FDJ.ResetSearchCache) end
        if FDJ.RPGStateChanged then pcall(FDJ.RPGStateChanged) end
        if FDJ.RefreshHomeCards then pcall(FDJ.RefreshHomeCards) end
        if FDJ.ScheduleQuestRefresh then pcall(FDJ.ScheduleQuestRefresh) end
    end
end

-- BEGIN showquests (2.0.16)
-- Options > RPG Mode > Show dungeon quests (off by default, for the whole
-- account). Many players found RPG Mode's quests too hard to find. On:
-- every dungeon's quests show, as in Gamer Mode; a locked card keeps its
-- sketch and gets the usual quest count, and clicking it opens the page on
-- its quests (bosses, loot and the map still unlock as before); no quest
-- achievement popups while it is on.
do
    local strings = {
        enUS = { OPT_RPG_SHOW_QUESTS = "Show dungeon quests", OPT_RPG_SHOW_QUESTS_TIP = "Every dungeon's quests are shown in RPG Mode, and the dungeon cards show their quest count. Bosses, loot and maps still unlock as you play. No quest achievement popups while this is on." },
        deDE = { OPT_RPG_SHOW_QUESTS = "Dungeon-Quests anzeigen", OPT_RPG_SHOW_QUESTS_TIP = "Im RPG-Modus werden alle Dungeon-Quests angezeigt, und die Dungeon-Karten zeigen ihre Questanzahl. Bosse, Beute und Karten werden weiterhin beim Spielen freigeschaltet. Solange das an ist, gibt es keine Quest-Erfolgs-Popups." },
        frFR = { OPT_RPG_SHOW_QUESTS = "Afficher les quêtes de donjon", OPT_RPG_SHOW_QUESTS_TIP = "En mode RPG, toutes les quêtes de donjon sont affichées et les cartes de donjon indiquent leur nombre de quêtes. Les boss, le butin et les cartes se débloquent toujours en jouant. Pas de fenêtre de haut fait de quête tant que c'est activé." },
        esES = { OPT_RPG_SHOW_QUESTS = "Mostrar misiones de mazmorra", OPT_RPG_SHOW_QUESTS_TIP = "En el modo RPG se muestran todas las misiones de mazmorra y las tarjetas de mazmorra indican su número de misiones. Los jefes, el botín y los mapas se siguen desbloqueando al jugar. Sin ventanas de logro de misión mientras esté activado." },
        itIT = { OPT_RPG_SHOW_QUESTS = "Mostra missioni dei dungeon", OPT_RPG_SHOW_QUESTS_TIP = "In modalità RPG vengono mostrate tutte le missioni dei dungeon e le schede dei dungeon indicano il numero di missioni. Boss, bottino e mappe si sbloccano sempre giocando. Nessun riquadro di impresa delle missioni finché è attivo." },
        ptBR = { OPT_RPG_SHOW_QUESTS = "Mostrar missões de masmorra", OPT_RPG_SHOW_QUESTS_TIP = "No modo RPG, todas as missões de masmorra aparecem e os cartões das masmorras mostram o número de missões. Chefes, saque e mapas continuam sendo desbloqueados ao jogar. Sem janelas de conquista de missão enquanto estiver ativado." },
        ruRU = { OPT_RPG_SHOW_QUESTS = "Показывать задания подземелий", OPT_RPG_SHOW_QUESTS_TIP = "В режиме RPG показываются все задания подземелий, а на карточках подземелий видно число заданий. Боссы, добыча и карты по-прежнему открываются по ходу игры. Пока это включено, окна достижений за задания не появляются." },
        koKR = { OPT_RPG_SHOW_QUESTS = "던전 퀘스트 보기", OPT_RPG_SHOW_QUESTS_TIP = "RPG 모드에서 모든 던전 퀘스트를 보여 주고, 던전 카드에 퀘스트 수를 표시합니다. 우두머리, 전리품, 지도는 계속 플레이하며 열립니다. 켜져 있는 동안 퀘스트 업적 팝업은 뜨지 않습니다." },
        zhCN = { OPT_RPG_SHOW_QUESTS = "显示副本任务", OPT_RPG_SHOW_QUESTS_TIP = "RPG模式下显示所有副本任务，副本卡片显示任务数量。首领、战利品和地图仍随游戏进程解锁。开启时不弹出任务成就窗口。" },
        zhTW = { OPT_RPG_SHOW_QUESTS = "顯示副本任務", OPT_RPG_SHOW_QUESTS_TIP = "RPG模式下顯示所有副本任務，副本卡片顯示任務數量。首領、戰利品和地圖仍隨遊戲進程解鎖。開啟時不彈出任務成就視窗。" },
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
function FDJ.RPGShowQuests()
    return FDJ.IsRPGMode and FDJ.IsRPGMode() and FDJ.RPGOption("showQuests") or false
end
-- END showquests

-- ------------------------------------------------- account-wide unlocks
-- Options > RPG Mode > Account-Wide Unlocks (off by default; on by default
-- since 2.0.8, when it also reads the account's Legacy Challenges). Every
-- character keeps its own unlocks (pages, bosses found, quests, maps) in its
-- own saved data, as before, and each is also copied into one record for
-- the whole account (ForeverDungeonJournalDB.rpgAccount): at login and as it
-- happens. With the option on, the journal shows the account's record, so
-- what one character unlocked is unlocked for all of them; turned off, each
-- character is back to its own unlocks. Nothing is lost either way.
-- A character counts for the account once it has logged in with this version.
local SHARED_KEYS = { "rpgKills", "rpgBosses", "rpgQuests", "rpgMaps" }
local function AccountProgress()
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    local acc = ForeverDungeonJournalDB.rpgAccount
    if type(acc) ~= "table" then
        acc = {}
        ForeverDungeonJournalDB.rpgAccount = acc
    end
    for _, key in ipairs(SHARED_KEYS) do
        if type(acc[key]) ~= "table" then acc[key] = {} end
    end
    return acc
end
FDJ.RPGAccountProgress = AccountProgress -- Systems/ProgressTransfer.lua
local shareStamp
-- This character's unlocks into the account's record (it only ever adds).
local function ShareProgress()
    shareStamp = GetTime and GetTime() or nil
    local db, acc = CharDB(), AccountProgress()
    for _, key in ipairs(SHARED_KEYS) do
        local mine, all = db[key], acc[key]
        if type(mine) == "table" then
            for k, v in pairs(mine) do
                if key == "rpgBosses" then
                    if type(v) == "table" then
                        if type(all[k]) ~= "table" then all[k] = {} end
                        for id, seen in pairs(v) do
                            if seen then all[k][id] = true end
                        end
                    end
                elseif v then
                    all[k] = true
                end
            end
        end
    end
end
FDJ.RPGShareProgress = ShareProgress
local function AccountWide()
    return FDJ.RPGOption("accountWide")
end
FDJ.RPGAccountWide = AccountWide
-- What the journal shows: this character's unlocks, or the whole account's.
local function View()
    if not AccountWide() then return CharDB() end
    local now = GetTime and GetTime() or nil
    if now == nil or now ~= shareStamp then ShareProgress() end
    return AccountProgress()
end
local ViewTable
-- rpgexport (2.1.1, M 20 Nov 2026: an RPG Mode character on the website
-- showed every dungeon): the pages the journal shows unlocked (with
-- Account-Wide Unlocks, the account's), for the character code.
FDJ.RPGKillsView = function() return ViewTable("rpgKills") end
function ViewTable(key)
    local t = View()[key]
    t = type(t) == "table" and t or {}
    -- rpglegacy (2.0.8): with Account-Wide Unlocks on, the pages the
    -- account's Legacy Challenges show as done are open too (a copy: the
    -- saved records stay as they are, so switching off loses nothing).
    if key == "rpgKills" and AccountWide() and FDJ.RPGLegacyPages then
        local legacy = FDJ.RPGLegacyPages()
        if type(legacy) == "table" and next(legacy) then
            local merged = {}
            for k, v in pairs(t) do merged[k] = v end
            for k, v in pairs(legacy) do if v then merged[k] = true end end
            return merged
        end
    end
    return t
end
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function() pcall(ShareProgress) end)
end
local function GetCV(name)
    if C_CVar and C_CVar.GetCVar then local ok, v = pcall(C_CVar.GetCVar, name) if ok then return v end end
    if GetCVar then local ok, v = pcall(GetCVar, name) if ok then return v end end
end
local function SetCV(name, value)
    if C_CVar and C_CVar.SetCVar then if pcall(C_CVar.SetCVar, name, value) then return end end
    if SetCVar then pcall(SetCVar, name, value) end
end
local function RestoreDialog()
    local db = ForeverDungeonJournalDB
    local saved = db and db.rpgDialogRestore
    if type(saved) ~= "table" then return end
    if saved.volume ~= nil then SetCV("Sound_DialogVolume", saved.volume) end
    if saved.enable ~= nil then SetCV("Sound_EnableDialog", saved.enable) end
    db.rpgDialogRestore = nil
end
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", RestoreDialog)
end
-- Plays a fanfare: play(id, channel) is PlaySound or PlaySoundFile.
-- Returns whether it will play.
local function PlayAtVolume(play, id)
    if FDJ.RPGOption("mute") then return true end -- muted: counts as handled
    local share = FDJ.RPGOption("volume") / 100
    if share >= 0.995 then
        local ok, will = pcall(play, id, "Master")
        return ok and will
    end
    if share <= 0 then return true end
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    if type(ForeverDungeonJournalDB.rpgDialogRestore) ~= "table" then
        ForeverDungeonJournalDB.rpgDialogRestore = { volume = GetCV("Sound_DialogVolume"), enable = GetCV("Sound_EnableDialog") }
    end
    SetCV("Sound_EnableDialog", "1")
    SetCV("Sound_DialogVolume", tostring(share))
    local ok, will = pcall(play, id, "Dialog")
    FDJ.rpgSoundToken = (FDJ.rpgSoundToken or 0) + 1
    local token = FDJ.rpgSoundToken
    if C_Timer and C_Timer.After then
        C_Timer.After(6, function() if FDJ.rpgSoundToken == token then RestoreDialog() end end)
    else
        RestoreDialog()
    end
    return ok and will
end

do
    local strings = {
        enUS = { OPT_RPG_ENABLE = "Enable", OPT_RPG_PAGE = "RPG Mode",
            OPT_RPG_HIDE_QUEST = "Hide Quest Achievement Popups", OPT_RPG_HIDE_QUEST_TIP = "No popup when a dungeon quest unlocks in RPG Mode (the line in chat stays).",
            OPT_RPG_HIDE_BOSS = "Hide Boss Achievement Popups", OPT_RPG_HIDE_BOSS_TIP = "No popup when a final boss unlocks a journal page in RPG Mode (the line in chat stays).",
            OPT_RPG_MUTE = "Mute Achievements", OPT_RPG_MUTE_TIP = "The achievement popups make no sound.",
            OPT_RPG_VOLUME = "Achievement Popup sound", OPT_RPG_VOLUME_TIP = "How loud the achievement fanfare plays (100% = as loud as the game's own).",
            OPT_RPG_ACCOUNT = "Account-Wide Unlocks", OPT_RPG_ACCOUNT_TIP = "On: what any of your characters unlocks in RPG Mode (pages, bosses, quests, maps) is unlocked for all of them. Off: each character unlocks its own. Switching loses nothing. Dungeons your account's Legacy Challenges show as done open too (not Ragefire Chasm, Hall of Thanes or The Stockade: Legacy can't tell them apart or doesn't list them)." },
        deDE = { OPT_RPG_ENABLE = "Aktivieren", OPT_RPG_PAGE = "RPG-Modus",
            OPT_RPG_HIDE_QUEST = "Quest-Erfolgs-Popups ausblenden", OPT_RPG_HIDE_QUEST_TIP = "Kein Popup, wenn im RPG-Modus eine Dungeon-Quest freigeschaltet wird (die Chatzeile bleibt).",
            OPT_RPG_HIDE_BOSS = "Boss-Erfolgs-Popups ausblenden", OPT_RPG_HIDE_BOSS_TIP = "Kein Popup, wenn im RPG-Modus ein Endboss eine Journalseite freischaltet (die Chatzeile bleibt).",
            OPT_RPG_MUTE = "Erfolge stummschalten", OPT_RPG_MUTE_TIP = "Die Erfolgs-Popups spielen keinen Ton.",
            OPT_RPG_VOLUME = "Lautstärke der Erfolgs-Popups", OPT_RPG_VOLUME_TIP = "Wie laut die Erfolgsfanfare spielt (100% = so laut wie die des Spiels).",
            OPT_RPG_ACCOUNT = "Accountweite Freischaltungen", OPT_RPG_ACCOUNT_TIP = "An: Was einer deiner Charaktere im RPG-Modus freischaltet (Seiten, Bosse, Quests, Karten), ist für alle freigeschaltet. Aus: Jeder Charakter schaltet seine eigenen frei. Beim Umschalten geht nichts verloren. Dungeons, die die Legacy-Herausforderungen deines Accounts als abgeschlossen zeigen, werden ebenfalls freigeschaltet (nicht Der Flammenschlund, Die Halle der Thanen oder Das Verlies: Legacy unterscheidet sie nicht oder führt sie nicht)." },
        frFR = { OPT_RPG_ENABLE = "Activer", OPT_RPG_PAGE = "Mode RPG",
            OPT_RPG_HIDE_QUEST = "Masquer les hauts faits de quête", OPT_RPG_HIDE_QUEST_TIP = "Pas de fenêtre quand une quête de donjon se débloque en mode RPG (la ligne dans le chat reste).",
            OPT_RPG_HIDE_BOSS = "Masquer les hauts faits de boss", OPT_RPG_HIDE_BOSS_TIP = "Pas de fenêtre quand un boss final débloque une page du journal en mode RPG (la ligne dans le chat reste).",
            OPT_RPG_MUTE = "Couper le son des hauts faits", OPT_RPG_MUTE_TIP = "Les fenêtres de haut fait ne font aucun son.",
            OPT_RPG_VOLUME = "Volume des hauts faits", OPT_RPG_VOLUME_TIP = "Le volume de la fanfare (100% = aussi fort que celle du jeu).",
            OPT_RPG_ACCOUNT = "Déblocages pour tout le compte", OPT_RPG_ACCOUNT_TIP = "Activé : ce qu'un de vos personnages débloque en mode RPG (pages, boss, quêtes, cartes) est débloqué pour tous. Désactivé : chaque personnage débloque les siens. Rien n'est perdu en changeant. Les donjons que les défis Legacy de votre compte indiquent comme terminés se débloquent aussi (pas le Gouffre de Ragefeu, La salle des Thanes ni La Prison : Legacy ne les distingue pas ou ne les liste pas)." },
        esES = { OPT_RPG_ENABLE = "Activar", OPT_RPG_PAGE = "Modo RPG",
            OPT_RPG_HIDE_QUEST = "Ocultar logros de misiones", OPT_RPG_HIDE_QUEST_TIP = "Sin ventana cuando se desbloquea una misión de mazmorra en el modo RPG (la línea del chat se mantiene).",
            OPT_RPG_HIDE_BOSS = "Ocultar logros de jefes", OPT_RPG_HIDE_BOSS_TIP = "Sin ventana cuando un jefe final desbloquea una página del diario en el modo RPG (la línea del chat se mantiene).",
            OPT_RPG_MUTE = "Silenciar logros", OPT_RPG_MUTE_TIP = "Las ventanas de logro no suenan.",
            OPT_RPG_VOLUME = "Volumen de los logros", OPT_RPG_VOLUME_TIP = "El volumen de la fanfarria (100% = tan alto como la del juego).",
            OPT_RPG_ACCOUNT = "Desbloqueos para toda la cuenta", OPT_RPG_ACCOUNT_TIP = "Activado: lo que desbloquee cualquiera de tus personajes en el modo RPG (páginas, jefes, misiones, mapas) queda desbloqueado para todos. Desactivado: cada personaje desbloquea lo suyo. No se pierde nada al cambiar. Las mazmorras que los desafíos Legacy de tu cuenta muestran como completadas también se desbloquean (no Sima Ígnea, El Salón de los Feudales ni Las Mazmorras: Legacy no las distingue o no las incluye)." },
        itIT = { OPT_RPG_ENABLE = "Attiva", OPT_RPG_PAGE = "Modalità RPG",
            OPT_RPG_HIDE_QUEST = "Nascondi imprese delle missioni", OPT_RPG_HIDE_QUEST_TIP = "Nessun riquadro quando si sblocca una missione di dungeon in modalità RPG (la riga in chat resta).",
            OPT_RPG_HIDE_BOSS = "Nascondi imprese dei boss", OPT_RPG_HIDE_BOSS_TIP = "Nessun riquadro quando un boss finale sblocca una pagina del diario in modalità RPG (la riga in chat resta).",
            OPT_RPG_MUTE = "Silenzia imprese", OPT_RPG_MUTE_TIP = "I riquadri delle imprese non fanno suoni.",
            OPT_RPG_VOLUME = "Volume delle imprese", OPT_RPG_VOLUME_TIP = "Quanto forte suona la fanfara (100% = forte come quella del gioco).",
            OPT_RPG_ACCOUNT = "Sblocchi per tutto l'account", OPT_RPG_ACCOUNT_TIP = "Attivo: ciò che un tuo personaggio sblocca in modalità RPG (pagine, boss, missioni, mappe) è sbloccato per tutti. Disattivo: ogni personaggio sblocca i propri. Cambiando non si perde nulla. Si sbloccano anche i dungeon che le sfide Legacy del tuo account segnano come completati (non il Baratro di Fiamma Furente, Hall of Thanes né Le Segrete: Legacy non li distingue o non li elenca)." },
        ptBR = { OPT_RPG_ENABLE = "Ativar", OPT_RPG_PAGE = "Modo RPG",
            OPT_RPG_HIDE_QUEST = "Ocultar conquistas de missões", OPT_RPG_HIDE_QUEST_TIP = "Sem janela quando uma missão de masmorra é desbloqueada no modo RPG (a linha no chat continua).",
            OPT_RPG_HIDE_BOSS = "Ocultar conquistas de chefes", OPT_RPG_HIDE_BOSS_TIP = "Sem janela quando um chefe final desbloqueia uma página do diário no modo RPG (a linha no chat continua).",
            OPT_RPG_MUTE = "Silenciar conquistas", OPT_RPG_MUTE_TIP = "As janelas de conquista não tocam som.",
            OPT_RPG_VOLUME = "Volume das conquistas", OPT_RPG_VOLUME_TIP = "O volume da fanfarra (100% = tão alto quanto a do jogo).",
            OPT_RPG_ACCOUNT = "Desbloqueios para toda a conta", OPT_RPG_ACCOUNT_TIP = "Ativado: o que qualquer personagem seu desbloquear no modo RPG (páginas, chefes, missões, mapas) fica desbloqueado para todos. Desativado: cada personagem desbloqueia os seus. Nada se perde ao trocar. As masmorras que os desafios Legacy da sua conta mostram como concluídas também são desbloqueadas (não as Cavernas Ígneas, o Salão dos Thanes nem O Cárcere: o Legacy não as diferencia ou não as lista)." },
        ruRU = { OPT_RPG_ENABLE = "Включить", OPT_RPG_PAGE = "Режим RPG",
            OPT_RPG_HIDE_QUEST = "Скрыть достижения заданий", OPT_RPG_HIDE_QUEST_TIP = "Без окна, когда в режиме RPG открывается задание подземелья (строка в чате остаётся).",
            OPT_RPG_HIDE_BOSS = "Скрыть достижения боссов", OPT_RPG_HIDE_BOSS_TIP = "Без окна, когда в режиме RPG последний босс открывает страницу журнала (строка в чате остаётся).",
            OPT_RPG_MUTE = "Без звука достижений", OPT_RPG_MUTE_TIP = "Окна достижений не издают звука.",
            OPT_RPG_VOLUME = "Громкость достижений", OPT_RPG_VOLUME_TIP = "Громкость фанфар (100% = как у самой игры).",
            OPT_RPG_ACCOUNT = "Открытия на всю учётную запись", OPT_RPG_ACCOUNT_TIP = "Вкл.: всё, что открыл любой ваш персонаж в режиме RPG (страницы, боссы, задания, карты), открыто для всех. Выкл.: каждый персонаж открывает своё. При переключении ничего не теряется. Подземелья, которые испытания Legacy вашей учётной записи отмечают как пройденные, тоже открываются (кроме Огненной Пропасти, Чертогов танов и Тюрьмы: Legacy их не различает или не учитывает)." },
        koKR = { OPT_RPG_ENABLE = "사용", OPT_RPG_PAGE = "RPG 모드",
            OPT_RPG_HIDE_QUEST = "퀘스트 업적 팝업 숨기기", OPT_RPG_HIDE_QUEST_TIP = "RPG 모드에서 던전 퀘스트가 열려도 팝업을 띄우지 않습니다 (채팅 메시지는 유지).",
            OPT_RPG_HIDE_BOSS = "우두머리 업적 팝업 숨기기", OPT_RPG_HIDE_BOSS_TIP = "RPG 모드에서 마지막 우두머리가 도감 페이지를 열어도 팝업을 띄우지 않습니다 (채팅 메시지는 유지).",
            OPT_RPG_MUTE = "업적 소리 끄기", OPT_RPG_MUTE_TIP = "업적 팝업에서 소리가 나지 않습니다.",
            OPT_RPG_VOLUME = "업적 팝업 소리", OPT_RPG_VOLUME_TIP = "업적 팡파르의 음량 (100% = 게임 기본과 같음).",
            OPT_RPG_ACCOUNT = "계정 공유 잠금 해제", OPT_RPG_ACCOUNT_TIP = "켜기: 한 캐릭터가 RPG 모드에서 연 것(페이지, 우두머리, 퀘스트, 지도)은 모든 캐릭터에게 열립니다. 끄기: 캐릭터마다 따로 엽니다. 전환해도 잃는 것은 없습니다. 계정의 Legacy 도전 과제에 완료로 표시된 던전도 열립니다 (성난불길 협곡, 영주의 전당, 스톰윈드 지하감옥 제외: Legacy가 구분하지 못하거나 목록에 없습니다)." },
        zhCN = { OPT_RPG_ENABLE = "启用", OPT_RPG_PAGE = "RPG模式",
            OPT_RPG_HIDE_QUEST = "隐藏任务成就弹窗", OPT_RPG_HIDE_QUEST_TIP = "RPG模式下副本任务解锁时不弹窗（聊天提示保留）。",
            OPT_RPG_HIDE_BOSS = "隐藏首领成就弹窗", OPT_RPG_HIDE_BOSS_TIP = "RPG模式下最终首领解锁日志页面时不弹窗（聊天提示保留）。",
            OPT_RPG_MUTE = "成就静音", OPT_RPG_MUTE_TIP = "成就弹窗不播放声音。",
            OPT_RPG_VOLUME = "成就弹窗音量", OPT_RPG_VOLUME_TIP = "成就号角的音量（100% = 与游戏自带相同）。",
            OPT_RPG_ACCOUNT = "账号通用解锁", OPT_RPG_ACCOUNT_TIP = "开启：你的任一角色在RPG模式中解锁的内容（页面、首领、任务、地图）对所有角色解锁。关闭：每个角色各自解锁。切换不会丢失任何进度。你账号的Legacy挑战中显示已完成的地下城也会解锁（怒焰裂谷、领主大厅和监狱除外：Legacy无法区分或未列出）。" },
        zhTW = { OPT_RPG_ENABLE = "啟用", OPT_RPG_PAGE = "RPG模式",
            OPT_RPG_HIDE_QUEST = "隱藏任務成就彈窗", OPT_RPG_HIDE_QUEST_TIP = "RPG模式下副本任務解鎖時不彈窗（聊天提示保留）。",
            OPT_RPG_HIDE_BOSS = "隱藏首領成就彈窗", OPT_RPG_HIDE_BOSS_TIP = "RPG模式下最終首領解鎖日誌頁面時不彈窗（聊天提示保留）。",
            OPT_RPG_MUTE = "成就靜音", OPT_RPG_MUTE_TIP = "成就彈窗不播放聲音。",
            OPT_RPG_VOLUME = "成就彈窗音量", OPT_RPG_VOLUME_TIP = "成就號角的音量（100% = 與遊戲內建相同）。",
            OPT_RPG_ACCOUNT = "帳號通用解鎖", OPT_RPG_ACCOUNT_TIP = "開啟：你的任一角色在RPG模式中解鎖的內容（頁面、首領、任務、地圖）對所有角色解鎖。關閉：每個角色各自解鎖。切換不會遺失任何進度。你帳號的Legacy挑戰中顯示已完成的地城也會解鎖（怒焰裂谷、族長之廳和監獄除外：Legacy無法區分或未列出）。" },
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

-- ------------------------------------------------------------ final bosses
-- The boss that unlocks each dungeon (NPC IDs). Where the journal lists a
-- side boss after the real end boss, the end boss is named here.
local FINAL = {
    ["The Deadmines"] = { 639 },               -- Edwin VanCleef
    ["Ruins of Lordaeron"] = { 250657 },       -- Rath'mael
    ["Ragefire Chasm"] = { 11519 },            -- Bazzalan
}

local finalByNpc, finalNames -- npcID -> dungeon, lower-case boss name -> dungeon
local finalNpcOf = {}         -- dungeon -> the final boss shown on its locked card
local finalBossOf = {}        -- dungeon -> that boss's (localized) name
local nameFinal = {}          -- kroldok: dungeon -> its final boss, known by name only
local function Build()
    if finalByNpc then return end
    finalByNpc, finalNames = {}, {}
    for _, name in ipairs(FDJ.ORDER or {}) do
        local d = FDJ.DB and FDJ.DB[name]
        if d and not d.previewOnly then
            local ids = FINAL[name]
            if not ids then
                local last
                for _, b in ipairs(d.bosses or {}) do
                    if not b.trash and not b.rare and b.npcID then last = b end
                end
                ids = last and { last.npcID } or {}
            end
            finalNpcOf[name] = ids[1]
            for _, b in ipairs(d.bosses or {}) do
                if b.npcID == ids[1] and b.name then
                    local loc = FDJ.LocalizeBossName and FDJ.LocalizeBossName(b.name)
                    finalBossOf[name] = type(loc) == "string" and loc or b.name
                end
            end
            for _, id in ipairs(ids) do
                finalByNpc[id] = name
                for _, b in ipairs(d.bosses or {}) do
                    if b.npcID == id and b.name then
                        finalNames[string.lower(b.name)] = name
                        local loc = FDJ.LocalizeBossName and FDJ.LocalizeBossName(b.name)
                        if type(loc) == "string" then finalNames[string.lower(loc)] = name end
                        for _, alias in ipairs(b.aliases or {}) do -- kroldok: the game's other name (Overseer Mugg)
                            if type(alias) == "string" then finalNames[string.lower(alias)] = name end
                        end
                    end
                end
            end
            -- kroldok: no boss of the dungeon has an NPC ID yet: its last
            -- boss counts by name (inside the dungeon only, see CheckDead).
            if not ids[1] then
                local last
                for _, b in ipairs(d.bosses or {}) do
                    if type(b) == "table" and not b.trash and not b.rare and not b.recipeTab and type(b.name) == "string" then last = b end
                end
                if last then
                    finalNpcOf[name] = false -- a page like any other, sketched as a ?
                    nameFinal[name] = last
                    local loc = FDJ.LocalizeBossName and FDJ.LocalizeBossName(last.name)
                    finalBossOf[name] = type(loc) == "string" and loc or last.name
                    finalNames[string.lower(last.name)] = name
                    if type(loc) == "string" then finalNames[string.lower(loc)] = name end
                    for _, alias in ipairs(last.aliases or {}) do
                        if type(alias) == "string" then finalNames[string.lower(alias)] = name end
                    end
                end
            end
        end
    end
end

-- The run log (Systems/RunLog.lua) ends a run's timer on the same final boss
-- that unlocks the dungeon here: its NPC ID (or nil) and its names (lower case).
function FDJ.FinalBossOf(dungeon)
    Build()
    local id = finalNpcOf[dungeon]
    local names = {}
    for lower, d in pairs(finalNames) do
        if d == dungeon then names[lower] = true end
    end
    return id or nil, names
end

-- ------------------------------------------------------------------- mode
function FDJ.IsRPGMode()
    return CharDB().journalMode == "rpg"
end

function FDJ.SetJournalMode(mode)
    CharDB().journalMode = (mode == "rpg") and "rpg" or "gamer"
    if FDJ.RPGLegacyRefresh then pcall(FDJ.RPGLegacyRefresh) end -- rpglegacy
    if FDJ.RefreshHomeCards then pcall(FDJ.RefreshHomeCards) end
    if FDJ.UpdateMinimapIcon then pcall(FDJ.UpdateMinimapIcon) end
end

local function InOrder(name)
    for _, n in ipairs(FDJ.ORDER or {}) do if n == name then return true end end
    return false
end

function FDJ.IsDungeonLocked(name)
    if not FDJ.IsRPGMode() then return false end
    if not InOrder(name) then return false end
    if FDJ.DB and FDJ.DB[name] and FDJ.DB[name].previewOnly then return false end -- "coming soon" cards
    return not ViewTable("rpgKills")[name]
end

function FDJ.RPGLockedNotice(name)
    -- No dungeon name: the page is meant to stay a mystery until unlocked.
    print("|cffd8a83cDungeon Journal:|r " .. L("RPG_LOCKED_MSG"))
end

local ShowUnlockToast -- defined further down, with the sketches
local function Unlock(name)
    local db = CharDB()
    if db.rpgKills[name] then return end
    -- Account-wide: already open from another character, so no popup.
    local open = ViewTable("rpgKills")[name] and true or false
    db.rpgKills[name] = true
    ShareProgress()
    if FDJ.IsRPGMode() and not open then
        local shown = FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(name) or name
        print("|cffd8a83cDungeon Journal:|r |cff40ff40" .. L("RPG_UNLOCKED_MSG", shown) .. "|r")
        if ShowUnlockToast then pcall(ShowUnlockToast, name) end
    end
    if FDJ.RefreshHomeCards then pcall(FDJ.RefreshHomeCards) end
end

-- ---------------------------------------------------------------- progress
-- Journey points: every quest this character can do is worth 5, every
-- journal page unlocked (final boss killed) is worth 10, like a small
-- achievement. A dungeon's quests and its page end up worth about the same
-- (most have 2-3 quests per character), so killing the boss is a real step.
local QUEST_POINTS, PAGE_POINTS = 5, 10
FDJ.RPG_PAGE_POINTS = PAGE_POINTS

local function Progress()
    local faction = UnitFactionGroup and Plain(UnitFactionGroup("player"))
    local _, class = UnitClass("player")
    class = Plain(class)
    local total, done = 0, 0
    local seen = {} -- a quest listed under several dungeons counts once
    for _, name in ipairs(FDJ.ORDER or {}) do
        local d = FDJ.DB and FDJ.DB[name]
        for _, q in ipairs((d and not d.previewOnly and d.quests) or {}) do
            local forFaction = q.faction == nil or q.faction == "Both" or q.faction == "Neutral" or q.faction == faction
            local forClass = not q.classOnly or (class and FDJ.QuestClassMatches(q.classOnly, class)) -- (twoclasses)
            local forProfession = not q.profession or not FDJ.PlayerHasProfession or FDJ.PlayerHasProfession(q.profession)
            if q.id and forFaction and forClass and forProfession and not q.hideFromMainList and not q.repeatable and not seen[q.id]
                and not (FDJ.IsQuestLost and FDJ.IsQuestLost(q)) then -- a lost quest doesn't count
                seen[q.id] = true
                total = total + 1
                if FDJ.QuestTurnedIn and FDJ.QuestTurnedIn(q.id) then done = done + 1 end -- questdone: handed in
            end
        end
    end
    Build()
    local pages, pagesDone = 0, 0
    for name in pairs(finalNpcOf) do
        pages = pages + 1
        if ViewTable("rpgKills")[name] then pagesDone = pagesDone + 1 end
    end
    local points = done * QUEST_POINTS + pagesDone * PAGE_POINTS
    local maxPoints = total * QUEST_POINTS + pages * PAGE_POINTS
    return points, maxPoints, done, total, pagesDone, pages
end
FDJ.RPGJourney = Progress -- rpgexport (2.1.1): the Journey bar's numbers, for the character code

-- ------------------------------------------------------------- home page
-- Locked dungeons show nothing: an empty card with one line of text.
local COVER_PARTS = { "art", "topShade", "previewIcon", "innerGlow", "title", "meta", "counts",
    "doneRing", "doneTick", "doneGlow", "fdjBand", "fdjBandFade", "favStar", "comingSoon" }

-- Locked cards are a blank journal page with a pencil sketch of the
-- dungeon's final boss (drawn from its model, keyed by display ID). Custom
-- bosses without a drawing get a sketched question mark.
local MEDIA = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\RPG\\"
local SKETCHES = {
    [1621] = true, [2029] = true, [2353] = true, [2837] = true, [4088] = true,
    [4642] = true, [5266] = true, [6980] = true, [7970] = true, [11396] = true,
    [2007] = true, [142837] = true, [144224] = true, [130061] = true, [144175] = true,
    [2041] = true, [2043] = true, [7971] = true, [5988] = true, [6439] = true, [12292] = true,
    [7806] = true, [8807] = true, [8711] = true, [10115] = true, [14416] = true, [11256] = true,
    [11583] = true, [10691] = true, [10729] = true, [11070] = true,
    -- 2.0.3: Min'loth the Serpent, Overlord Mugg, Blazeroar, Avatar of Hakkar
    -- (drawn from Hakkar the Soulflayer's model, the same creature: the
    -- Avatar's own render only shows it from above), Varrox Bleakhoof, Nanaya.
    [142322] = true, [141218] = true, [6374] = true, [8053] = true, [130447] = true, [143832] = true,
}
local function SketchFor(name)
    Build()
    local npcID = finalNpcOf[name]
    local displayID = npcID and FDJ.STATIC_DISPLAY_IDS and FDJ.STATIC_DISPLAY_IDS[npcID]
    if displayID and SKETCHES[displayID] then return MEDIA .. "Sketch_" .. displayID end
    return MEDIA .. "Sketch_Unknown"
end
-- rpgexport (2.1.1): which sketch a locked card shows (Media\RPG\Sketch_<id>;
-- nil: Sketch_Unknown), for the character code.
FDJ.RPGSketchArt = function(name)
    Build()
    local npcID = finalNpcOf[name]
    local displayID = npcID and FDJ.STATIC_DISPLAY_IDS and FDJ.STATIC_DISPLAY_IDS[npcID]
    return (displayID and SKETCHES[displayID]) and displayID or nil
end

local function JournalPage(card)
    if card.rpgPage then return card.rpgPage end
    local page = CreateFrame("Frame", nil, card)
    page:SetPoint("TOPLEFT", 4, -4)
    page:SetPoint("BOTTOMRIGHT", -4, 4)
    page:SetFrameLevel(card:GetFrameLevel() + 1)
    page:EnableMouse(false)
    page.paper = page:CreateTexture(nil, "BACKGROUND")
    page.paper:SetAllPoints()
    page.paper:SetTexture(MEDIA .. "Parchment")
    page.paper:SetTexCoord(0, 1, 0, 176 / 256)
    page.sketch = page:CreateTexture(nil, "ARTWORK")
    page.sketch:SetPoint("TOP", 0, -4)
    page.sketch:SetPoint("BOTTOM", 0, 4)
    page:SetScript("OnSizeChanged", function(self, _, h)
        self.sketch:SetWidth(math.max(1, (h or 110) - 8) * 2)
    end)
    page.sketch:SetWidth(220)
    card.rpgPage = page
    return page
end

function FDJ.ApplyRPGCard(card, name)
    local locked = FDJ.IsDungeonLocked(name)
    -- showquests (2.0.16): with Show dungeon quests the page opens, but its
    -- card keeps the sketch, with the usual quest count on it.
    local questsOnly = not locked and FDJ.RPGSketchLocked and FDJ.RPGSketchLocked(name) or false
    if questsOnly then locked = true end
    -- "Coming soon" dungeons stay a blank page with the sketched question mark.
    local preview = FDJ.IsRPGMode() and FDJ.DB and FDJ.DB[name] and FDJ.DB[name].previewOnly and true or false
    if locked or preview then
        local page = JournalPage(card)
        page.sketch:SetTexture(preview and (MEDIA .. "Sketch_Unknown") or SketchFor(name))
        page:Show()
        if questsOnly and not preview then
            if not page.questCount then
                page.questCount = page:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
                page.questCount:SetPoint("TOPRIGHT", -10, -7)
                page.questCount:SetJustifyH("RIGHT")
                page.questCount:SetTextColor(0.97, 0.89, 0.54)
                page.questCount:SetShadowColor(0, 0, 0, 1)
                page.questCount:SetShadowOffset(1, -1)
                page.questBack = page:CreateTexture(nil, "ARTWORK", nil, 1)
                page.questBack:SetTexture("Interface\\Buttons\\WHITE8X8")
                page.questBack:SetVertexColor(0, 0, 0, 0.55)
                page.questBack:SetPoint("TOPLEFT", page.questCount, "TOPLEFT", -6, 3)
                page.questBack:SetPoint("BOTTOMRIGHT", page.questCount, "BOTTOMRIGHT", 6, -3)
            end
            page.questCount:SetText(card.counts and card.counts:GetText() or "")
            page.questCount:Show()
            page.questBack:Show()
        elseif page.questCount then
            page.questCount:Hide()
            page.questBack:Hide()
        end
    elseif card.rpgPage then
        card.rpgPage:Hide()
    end
    if card.rpgText then card.rpgText:Hide() end
    for _, key in ipairs(COVER_PARTS) do
        local part = card[key]
        if part and part.SetAlpha then part:SetAlpha((locked or preview) and 0 or 1) end
    end
end

-- ------------------------------------------------------------ unlock toast
-- Achievement-style popup in the middle of the screen when a page unlocks:
-- the boss sketch on a scrap of parchment, the dungeon name, a light sweep
-- and a fanfare. Clicking it opens that dungeon in the journal.
local toast
-- The fanfare the game plays when an achievement is earned. Different
-- clients know it under different names, so try each until one plays.
local function FanfareCandidates()
    local list = {}
    for key, id in pairs(SOUNDKIT or {}) do
        local k = tostring(key)
        if k:find("ACHIEVEMENT") and (k:find("GAIN") or k:find("EARN") or k:find("ALERT") or k:find("TOAST")) then
            list[#list + 1] = { "SOUNDKIT." .. k, PlaySound, id }
        end
    end
    list[#list + 1] = { "kit 12891 (UI Alert AchievementGained)", PlaySound, 12891 }
    list[#list + 1] = { "Sound\\Spells\\AchievmentSound1.ogg", PlaySoundFile, "Sound\\Spells\\AchievmentSound1.ogg" }
    list[#list + 1] = { "file 569143", PlaySoundFile, 569143 }
    if SOUNDKIT and SOUNDKIT.LFG_REWARDS then list[#list + 1] = { "SOUNDKIT.LFG_REWARDS", PlaySound, SOUNDKIT.LFG_REWARDS } end
    if SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE then list[#list + 1] = { "SOUNDKIT.IG_QUEST_LIST_COMPLETE", PlaySound, SOUNDKIT.IG_QUEST_LIST_COMPLETE } end
    return list
end

local function PlayFanfare()
    if FDJ.RPGOption("mute") then return end -- Options > RPG Mode > Mute Achievements
    for _, c in ipairs(FanfareCandidates()) do
        if c[2] and PlayAtVolume(c[2], c[3]) then return c[1] end
    end
end
FDJ.PlayRPGFanfare = PlayFanfare -- the volume slider plays a sample

local function BuildPlainToast()
    local t = CreateFrame("Button", "ForeverDungeonJournalUnlockToast", UIParent, "BackdropTemplate")
    t:SetSize(440, 112)
    t:SetPoint("CENTER", 0, 170)
    t:SetFrameStrata("FULLSCREEN_DIALOG")
    t:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    t:SetBackdropColor(0.05, 0.04, 0.03, 0.96)
    t:Hide()

    local glow = t:CreateTexture(nil, "BACKGROUND", nil, 1)
    glow:SetPoint("TOPLEFT", 6, -6)
    glow:SetPoint("BOTTOMRIGHT", -6, 6)
    glow:SetColorTexture(1, 0.78, 0.25, 0.10)

    local page = t:CreateTexture(nil, "ARTWORK", nil, 1)
    page:SetSize(132, 88)
    page:SetPoint("LEFT", 14, 0)
    page:SetTexture(MEDIA .. "Parchment")
    page:SetTexCoord(0.12, 0.88, 0.02, 0.66)
    t.sketch = t:CreateTexture(nil, "ARTWORK", nil, 2)
    t.sketch:SetSize(160, 80)
    t.sketch:SetPoint("CENTER", page, "CENTER", 0, 0)
    local frameEdge = CreateFrame("Frame", nil, t, "BackdropTemplate")
    frameEdge:SetPoint("TOPLEFT", page, -3, 3)
    frameEdge:SetPoint("BOTTOMRIGHT", page, 3, -3)
    frameEdge:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
    frameEdge:SetBackdropBorderColor(0.85, 0.68, 0.32, 1)

    t.header = t:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    t.header:SetPoint("TOPLEFT", page, "TOPRIGHT", 16, -6)
    t.header:SetPoint("RIGHT", -18, 0)
    t.header:SetJustifyH("CENTER")
    t.header:SetTextColor(1, 0.82, 0)
    t.name = t:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightLarge")
    t.name:SetPoint("TOP", t.header, "BOTTOM", 0, -8)
    t.name:SetPoint("LEFT", t.header, "LEFT")
    t.name:SetPoint("RIGHT", t.header, "RIGHT")
    t.name:SetJustifyH("CENTER")
    do
        local font, _, flags = t.name:GetFont()
        if font then t.name:SetFont(font, 20, flags) end
    end
    t.hint = t:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontDisableSmall")
    t.hint:SetPoint("TOP", t.name, "BOTTOM", 0, -10)
    t.hint:SetPoint("LEFT", t.header, "LEFT")
    t.hint:SetPoint("RIGHT", t.header, "RIGHT")
    t.hint:SetJustifyH("CENTER")

    -- Light sweeping across once as it appears.
    local clip = CreateFrame("Frame", nil, t)
    clip:SetPoint("TOPLEFT", 6, -6)
    clip:SetPoint("BOTTOMRIGHT", -6, 6)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    clip:SetFrameLevel(t:GetFrameLevel() + 4)
    local shine = clip:CreateTexture(nil, "OVERLAY")
    shine:SetTexture("Interface\\Cooldown\\star4")
    shine:SetBlendMode("ADD")
    shine:SetSize(110, 170)
    shine:SetPoint("CENTER", clip, "LEFT", -60, 0)
    shine:SetAlpha(0)
    t.shine = shine

    local intro = t:CreateAnimationGroup()
    local fade = intro:CreateAnimation("Alpha")
    fade:SetFromAlpha(0); fade:SetToAlpha(1); fade:SetDuration(0.25); fade:SetOrder(1)
    local grow = intro:CreateAnimation("Scale")
    if grow.SetScaleFrom then grow:SetScaleFrom(0.6, 0.6); grow:SetScaleTo(1, 1) else grow:SetFromScale(0.6, 0.6); grow:SetToScale(1, 1) end
    grow:SetDuration(0.25); grow:SetOrder(1)
    t.intro = intro

    local sweep = shine:CreateAnimationGroup()
    local sIn = sweep:CreateAnimation("Alpha")
    sIn:SetFromAlpha(0); sIn:SetToAlpha(0.9); sIn:SetDuration(0.15); sIn:SetStartDelay(0.25); sIn:SetOrder(1)
    local move = sweep:CreateAnimation("Translation")
    move:SetOffset(560, 0); move:SetDuration(0.9); move:SetStartDelay(0.25); move:SetOrder(1)
    local sOut = sweep:CreateAnimation("Alpha")
    sOut:SetFromAlpha(0.9); sOut:SetToAlpha(0); sOut:SetDuration(0.3); sOut:SetStartDelay(0.85); sOut:SetOrder(1)
    t.sweep = sweep

    local outro = t:CreateAnimationGroup()
    local fadeOut = outro:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(0); fadeOut:SetDuration(0.6)
    outro:SetScript("OnFinished", function() t:Hide() end)
    t.outro = outro

    t:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver() then return end -- stays while hovered
        self.left = (self.left or 0) - elapsed
        if self.left <= 0 and not self.outro:IsPlaying() then self.outro:Play() end
    end)
    t:SetScript("OnEnter", function(self) self.outro:Stop(); self:SetAlpha(1) end)
    t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    t:SetScript("OnClick", function(self, button)
        self.outro:Stop()
        self:Hide()
        if button ~= "LeftButton" or not self.dungeon then return end
        local journal = _G.ForeverDungeonJournalFrame
        if FDJ.ToggleJournal and not (journal and journal:IsShown()) then pcall(FDJ.ToggleJournal) end
        if FDJ.OpenBossPage and not FDJ.IsDungeonLocked(self.dungeon) then pcall(FDJ.OpenBossPage, self.dungeon) end
    end)
    return t
end

-- The real thing: a copy of the game's guild achievement alert (same
-- atlases, layout and animations as AchievementAlertFrameTemplate), with
-- our own text: "Dungeon Journal" on the banner, "Journal Page Unlocked",
-- the dungeon name, the boss sketch as the icon and the number of pages
-- unlocked on the shield.
local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function Atlas(tex, name)
    if tex.SetAtlas then pcall(tex.SetAtlas, tex, name, true) end
end

local function AnimAlpha(group, from, to, duration, order, delay)
    local a = group:CreateAnimation("Alpha")
    a:SetFromAlpha(from); a:SetToAlpha(to); a:SetDuration(duration); a:SetOrder(order or 1)
    if delay then a:SetStartDelay(delay) end
    return a
end

local function BuildAchievementToast()
    local t = CreateFrame("Button", "ForeverDungeonJournalUnlockToast", UIParent)
    t:SetSize(300, 101)
    t:SetPoint("CENTER", 0, 170)
    t:SetFrameStrata("FULLSCREEN_DIALOG")
    t:Hide()

    t.bg = t:CreateTexture(nil, "BACKGROUND")
    Atlas(t.bg, "ui-achievement-guild-background")
    t.bg:SetPoint("CENTER")

    t.guild = t:CreateFontString(nil, "BACKGROUND", "ForeverDJ_GameFontNormal")
    t.guild:SetPoint("TOPLEFT", 50, -13)
    t.guild:SetPoint("TOPRIGHT", -50, -13)
    t.unlocked = t:CreateFontString(nil, "BACKGROUND", "ForeverDJ_GameFontBlackTiny")
    t.unlocked:SetSize(200, 12)
    t.unlocked:SetPoint("TOP", 0, -38)
    t.name = t:CreateFontString(nil, "BACKGROUND", "ForeverDJ_GameFontHighlight")
    t.name:SetSize(155, 36)
    t.name:SetPoint("TOP", t.unlocked, "BOTTOM")
    t.name:SetJustifyH("CENTER")
    t.name:SetJustifyV("MIDDLE")
    if t.name.SetMaxLines then t.name:SetMaxLines(2) end

    -- Banner behind the shield (the guild flag), tinted like a journal cover.
    local banner = t:CreateTexture(nil, "BACKGROUND", nil, 1)
    Atlas(banner, "ui-achievement-guild-flag-short")
    banner:SetPoint("TOPRIGHT", -13, -32)
    banner:SetVertexColor(0.55, 0.12, 0.08)
    local bannerEdge = t:CreateTexture(nil, "BORDER")
    Atlas(bannerEdge, "ui-achievement-guild-flag-short-outline")
    bannerEdge:SetPoint("TOPRIGHT", -13, -34)

    -- Icon: the boss sketch on parchment inside the achievement icon frame.
    local icon = CreateFrame("Frame", nil, t)
    icon:SetSize(78, 75)
    icon:SetPoint("TOPLEFT", 0, -25)
    local paper = icon:CreateTexture(nil, "ARTWORK", nil, 1)
    paper:SetSize(52, 52)
    paper:SetPoint("CENTER", -1, -2)
    paper:SetTexture(MEDIA .. "Parchment")
    paper:SetTexCoord(0.36, 0.64, 0.12, 0.56)
    t.sketch = icon:CreateTexture(nil, "ARTWORK", nil, 2)
    t.sketch:SetSize(52, 52)
    t.sketch:SetPoint("CENTER", -1, -2)
    t.sketch:SetTexCoord(0.25, 0.75, 0, 1)
    local iconFrame = icon:CreateTexture(nil, "OVERLAY")
    Atlas(iconFrame, "ui-achievement-guild-iconframe")
    iconFrame:SetPoint("CENTER", 0, 0)

    -- Shield with the number of pages unlocked, in green like guild points.
    local shield = CreateFrame("Frame", nil, t)
    shield:SetSize(64, 64)
    shield:SetPoint("TOPRIGHT", -12, -25)
    local shieldIcon = shield:CreateTexture(nil, "BACKGROUND")
    Atlas(shieldIcon, "ui-achievement-shield-1")
    shieldIcon:SetPoint("TOPRIGHT", 1, -6)
    t.points = shield:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    t.points:SetPoint("CENTER", 2, -2)
    t.points:SetVertexColor(0, 1, 0)

    -- Glow flash and the light sweep, exactly as the game plays them.
    local glow = t:CreateTexture(nil, "OVERLAY")
    Atlas(glow, "ui-achievement-guild-glow")
    glow:SetBlendMode("ADD")
    glow:SetPoint("CENTER")
    glow:Hide()
    local glowAnim = glow:CreateAnimationGroup()
    AnimAlpha(glowAnim, 0, 1, 0.2, 1)
    AnimAlpha(glowAnim, 1, 0, 0.5, 2)
    glowAnim:SetScript("OnFinished", function() glow:Hide() end)

    local shine = t:CreateTexture(nil, "OVERLAY")
    Atlas(shine, "ui-achievement-guild-shine")
    shine:SetBlendMode("ADD")
    shine:SetPoint("BOTTOMLEFT", 0, 16)
    shine:Hide()
    local shineAnim = shine:CreateAnimationGroup()
    AnimAlpha(shineAnim, 0, 1, 0.2, 1)
    local move = shineAnim:CreateAnimation("Translation")
    move:SetOffset(240, 0); move:SetDuration(0.85); move:SetOrder(2)
    AnimAlpha(shineAnim, 1, 0, 0.5, 2, 0.35)
    shineAnim:SetScript("OnFinished", function() shine:Hide() end)

    local intro = t:CreateAnimationGroup()
    AnimAlpha(intro, 0, 1, 0.2, 1)
    t.intro = intro
    t.sweep = {
        Stop = function() glowAnim:Stop(); shineAnim:Stop() end,
        Play = function() glow:Show(); shine:Show(); glowAnim:Play(); shineAnim:Play() end,
    }
    local outro = t:CreateAnimationGroup()
    AnimAlpha(outro, 1, 0, 1.5, 1)
    outro:SetScript("OnFinished", function() t:Hide() end)
    t.outro = outro

    t:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver() then return end
        self.left = (self.left or 0) - elapsed
        if self.left <= 0 and not self.outro:IsPlaying() then self.outro:Play() end
    end)
    t:SetScript("OnEnter", function(self)
        self.outro:Stop(); self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L("RPG_TOAST_HINT"), 1, 1, 1)
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    t:SetScript("OnClick", function(self, button)
        GameTooltip:Hide()
        self.outro:Stop()
        self:Hide()
        if button ~= "LeftButton" or not self.dungeon then return end
        local journal = _G.ForeverDungeonJournalFrame
        if FDJ.ToggleJournal and not (journal and journal:IsShown()) then pcall(FDJ.ToggleJournal) end
        if FDJ.OpenBossPage and not FDJ.IsDungeonLocked(self.dungeon) then pcall(FDJ.OpenBossPage, self.dungeon) end
    end)
    return t
end

ShowUnlockToast = function(name)
    if FDJ.RPGOption("hideBossPopups") then return end -- Options > RPG Mode
    if not toast then
        toast = HasAtlas("ui-achievement-guild-background") and BuildAchievementToast() or BuildPlainToast()
    end
    toast.dungeon = name
    toast.sketch:SetTexture(SketchFor(name))
    local shown = FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(name) or name
    toast.name:SetText(shown)
    if toast.unlocked then
        toast.guild:SetText("Dungeon Journal")
        toast.unlocked:SetText(L("RPG_TOAST_TITLE"))
        toast.points:SetText(PAGE_POINTS)
        toast.left = 4.05
    else
        toast.header:SetText(L("RPG_TOAST_TITLE"))
        toast.hint:SetText(L("RPG_TOAST_HINT"))
        toast.left = 6
    end
    toast.outro:Stop()
    toast:SetAlpha(1)
    toast:Show()
    toast.intro:Stop(); toast.intro:Play()
    toast.sweep:Stop(); toast.sweep:Play()
    PlayFanfare()
end

-- Tooltip for a locked page on the home page.
function FDJ.RPGLockedTooltip(owner, name)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(L("RPG_LOCKED_TIP_TITLE"), 1, 0.82, 0)
    GameTooltip:AddLine(L("RPG_LOCKED_TIP2"), 1, 1, 1, true)
    GameTooltip:Show()
end

-- Progress bar built from the exact art of the game's profession bars
-- (ProfessionStatusBarTemplate: Interface\Spellbook\ProfessionsBook frame
-- pieces and the Professions-Progress-Fill bar), scaled up.
local PB = "Interface\\Spellbook\\ProfessionsBook"
-- The game's own profession skill bar (ProfessionsRankBarTemplate): the
-- same background, masked flipbook fill, flare at the edge and thin gold
-- frame as the bars on the Professions window.
local SKILLBAR_KITS = { "FirstAid", "Herbalism", "Alchemy", "Engineering", "DefaultBlue" }
local function AtlasInfo(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)
end

local function BuildSkillBar(home)
    local kit, fillInfo
    for _, k in ipairs(SKILLBAR_KITS) do
        fillInfo = AtlasInfo("Skillbar_Fill_Flipbook_" .. k)
        if fillInfo then kit = k break end
    end
    if not kit or not AtlasInfo("Professions-skillbar-frame") or not AtlasInfo("Professions-skillbar-mask") then return nil end

    local bar = CreateFrame("Frame", nil, home)
    bar:SetSize(453, 18)
    bar:SetScale(0.86)
    bar:SetPoint("TOPLEFT", 26, -30)

    local bg = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    bg:SetAtlas("Professions-skillbar-bg", true)
    bg:SetPoint("TOPLEFT")

    -- Everything past the filled part is cut away by this clipping frame
    -- (the mask alone lets the art bleed into the empty part).
    local clip = CreateFrame("Frame", nil, bar)
    clip:SetPoint("TOPLEFT", 5, -3)
    clip:SetSize(441, 18)
    clip:SetClipsChildren(true)
    bar.clip = clip

    local fill = clip:CreateTexture(nil, "ARTWORK", nil, 2)
    fill:SetSize(441, 18)
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 5, -3)
    fill:SetAtlas("Skillbar_Fill_Flipbook_" .. kit, false)

    local flare = clip:CreateTexture(nil, "ARTWORK", nil, 2)
    flare:SetSize(53, 16)
    flare:SetBlendMode("ADD")
    local flareName = "Skillbar_Flare_" .. kit
    if AtlasInfo(flareName) then flare:SetAtlas(flareName, false) else flare:Hide() end

    local mask = clip:CreateMaskTexture()
    mask:SetAtlas("Professions-skillbar-mask", true)
    pcall(mask.SetTextureWrapMode, mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetPoint("LEFT", fill, "LEFT", 1, 0)
    fill:AddMaskTexture(mask)
    flare:AddMaskTexture(mask)
    flare:SetPoint("RIGHT", mask, "RIGHT", 0, 0)

    local over = CreateFrame("Frame", nil, bar)
    over:SetAllPoints()
    over:SetFrameLevel(clip:GetFrameLevel() + 1)
    local border = over:CreateTexture(nil, "ARTWORK", nil, 3)
    border:SetAtlas("Professions-skillbar-frame", true)
    border:SetPoint("TOPLEFT")

    -- The fill art is a flipbook (2 columns of 34px frames). Keep it
    -- rippling gently; if flipbooks aren't supported, show its first frame.
    local rows = math.max(1, math.floor((fillInfo.height or 34) / 34))
    local animOK = pcall(function()
        local anim = bar:CreateAnimationGroup()
        local flip = anim:CreateAnimation("FlipBook")
        flip:SetTarget(fill)
        flip:SetFlipBookRows(rows)
        flip:SetFlipBookColumns(2)
        flip:SetFlipBookFrames(rows * 2)
        flip:SetFlipBookFrameWidth(0)
        flip:SetFlipBookFrameHeight(0)
        flip:SetDuration(4)
        anim:SetLooping("REPEAT")
        anim:Play()
        bar.flipAnim = anim
    end)
    if not animOK and fillInfo.leftTexCoord then
        local l, r = fillInfo.leftTexCoord, fillInfo.rightTexCoord
        local t, b = fillInfo.topTexCoord, fillInfo.bottomTexCoord
        fill:SetTexCoord(l, l + (r - l) / 2, t, t + (b - t) / rows)
    end

    local holder = CreateFrame("Frame", nil, bar)
    holder:SetSize(300, 18)
    holder:SetPoint("CENTER", 0, -2)
    holder:SetFrameLevel(bar:GetFrameLevel() + 5)
    bar.text = holder:CreateFontString(nil, "OVERLAY", "ForeverDJ_Number12FontOutline")
    if not bar.text:GetFont() then bar.text:SetFontObject("ForeverDJ_GameFontHighlight") end
    bar.text:SetPoint("CENTER")

    function bar:SetProgress(frac)
        frac = math.max(0, math.min(1, frac or 0))
        mask:SetWidth(math.max(0.01, 441 * frac))
        clip:SetWidth(math.max(0.01, 441 * frac + 1))
        flare:SetAlpha((frac > 0 and frac < 1) and 1 or 0)
    end
    bar:SetScript("OnShow", function(self) if self.flipAnim and not self.flipAnim:IsPlaying() then self.flipAnim:Play() end end)

    bar:EnableMouse(true)
    bar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText(L("RPG_PROGRESS_TITLE"), 1, 0.82, 0)
        GameTooltip:AddLine(L("RPG_PROGRESS_TIP", self.quests or 0, self.questTotal or 0), 1, 1, 1, true)
        GameTooltip:AddLine(L("RPG_PROGRESS_PAGES", self.pages or 0, self.pageTotal or 0), 1, 1, 1, true)
        GameTooltip:AddLine(L("RPG_PROGRESS_POINTS", QUEST_POINTS, PAGE_POINTS), 0.6, 0.85, 0.6, true)
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return bar
end

local function BuildBar(home)
    local ok, bar = pcall(BuildSkillBar, home)
    if ok and bar then return bar end
    return BuildOldBar(home)
end

local function BuildOldBar(home)
    local W, H = 360, 22
    local k = H / 16
    local bar = CreateFrame("StatusBar", nil, home)
    bar:SetSize(W, H)
    bar:SetPoint("TOPLEFT", 20 + 16 * k, -24)
    bar:SetMinMaxValues(0, 1)
    bar:SetStatusBarTexture("Interface\\Spellbook\\Professions-Progress-Fill")
    bar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)

    local function Piece(layer, w, h, l, r, t, btm)
        local tex = bar:CreateTexture(nil, layer)
        tex:SetTexture(PB)
        tex:SetSize(w * k, h * k)
        tex:SetTexCoord(l, r, t, btm)
        return tex
    end
    -- The rounded ends overlap the fill so the green reaches right into
    -- them (the end caps hide the square corners of the fill).
    local bgL = Piece("BACKGROUND", 16, 16, 0.00390625, 0.06640625, 0.484375, 0.609375)
    bgL:SetPoint("LEFT", bar, "LEFT", -4 * k, 2 * k)
    local bgR = Piece("BACKGROUND", 16, 16, 0.00390625, 0.06640625, 0.625, 0.75)
    bgR:SetPoint("RIGHT", bar, "RIGHT", 4 * k, 2 * k)
    local bgM = bar:CreateTexture(nil, "BACKGROUND")
    bgM:SetTexture(PB)
    bgM:SetTexCoord(0, 1, 0.0078125, 0.1328125)
    bgM:SetPoint("TOPLEFT", bgL, "TOPRIGHT")
    bgM:SetPoint("BOTTOMRIGHT", bgR, "BOTTOMLEFT")
    bar.capL = Piece("OVERLAY", 12, 12, 0.00390625, 0.05078125, 0.875, 0.96875)
    bar.capL:SetPoint("LEFT", bar, "LEFT", -4 * k, 2 * k)
    bar.capR = Piece("OVERLAY", 12, 12, 0.00390625, 0.05078125, 0.765625, 0.859375)
    bar.capR:SetPoint("RIGHT", bar, "RIGHT", 4 * k, 2 * k)
    bar.capR:Hide()

    -- Bright fade towards the end of the fill and a bright edge, like the
    -- profession bars. Both reuse the fill texture itself (added on top), so
    -- they follow its exact shape and never spill outside the groove.
    local FILL = "Interface\\Spellbook\\Professions-Progress-Fill"
    local fill = bar:GetStatusBarTexture()
    bar.fade = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    bar.fade:SetTexture(FILL)
    bar.fade:SetBlendMode("ADD")
    bar.fade:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
    bar.fade:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    bar.fade:SetWidth(60)
    if CreateColor and bar.fade.SetGradient and pcall(bar.fade.SetGradient, bar.fade, "HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.9)) then
    elseif bar.fade.SetGradientAlpha then
        pcall(bar.fade.SetGradientAlpha, bar.fade, "HORIZONTAL", 1, 1, 1, 0, 1, 1, 1, 0.9)
    else
        bar.fade:SetAlpha(0.4)
    end
    bar.edge = bar:CreateTexture(nil, "ARTWORK", nil, 4)
    bar.edge:SetTexture(FILL)
    bar.edge:SetBlendMode("ADD")
    bar.edge:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
    bar.edge:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    bar.edge:SetWidth(3)
    bar.edge:SetVertexColor(1, 1, 1, 1)
    bar.spark = bar.edge

    local textHolder = CreateFrame("Frame", nil, bar)
    textHolder:SetAllPoints()
    textHolder:SetFrameLevel(bar:GetFrameLevel() + 5)
    bar.text = textHolder:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    if not bar.text:GetFont() then bar.text:SetFontObject("ForeverDJ_GameFontHighlight") end
    do
        local font, _, flags = bar.text:GetFont()
        if font then bar.text:SetFont(font, 13, flags) end
    end
    bar.text:SetPoint("CENTER", 0, 2 * k)
    bar.text:SetTextColor(1, 1, 1)
    bar.text:SetShadowColor(0, 0, 0, 1)
    bar.text:SetShadowOffset(1, -1)
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText(L("RPG_PROGRESS_TITLE"), 1, 0.82, 0)
        GameTooltip:AddLine(L("RPG_PROGRESS_TIP", self.quests or 0, self.questTotal or 0), 1, 1, 1, true)
        GameTooltip:AddLine(L("RPG_PROGRESS_PAGES", self.pages or 0, self.pageTotal or 0), 1, 1, 1, true)
        GameTooltip:AddLine(L("RPG_PROGRESS_POINTS", QUEST_POINTS, PAGE_POINTS), 0.6, 0.85, 0.6, true)
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return bar
end

function FDJ.UpdateRPGHeader(frame)
    local home = frame and frame.homePanel
    if not home then return end
    local rpg = FDJ.IsRPGMode()
    if frame.homeTitle then frame.homeTitle:SetShown(not rpg) end
    if frame.homeSubtitle then frame.homeSubtitle:SetShown(not rpg) end
    if not frame.rpgBar then
        if not rpg then return end
        frame.rpgBar = BuildBar(home)
    end
    local bar = frame.rpgBar
    bar:SetShown(rpg)
    if not rpg then return end
    local done, total, quests, questTotal, pages, pageTotal = Progress()
    bar.done, bar.total = done, total
    bar.quests, bar.questTotal, bar.pages, bar.pageTotal = quests, questTotal, pages, pageTotal
    local frac = total > 0 and done / total or 0
    bar.text:SetText(L("RPG_PROGRESS_BAR", done, total, total > 0 and math.floor(done / total * 100) or 0))
    if bar.SetProgress then bar:SetProgress(frac) return end
    bar:SetValue(frac)
    local barWidth = bar:GetWidth() or 360
    local fillWidth = barWidth * frac
    local fadeWidth = math.max(1, math.min(70, fillWidth))
    bar.fade:SetShown(fillWidth > 2)
    bar.fade:SetWidth(fadeWidth)
    -- Same slice of the fill art as sits underneath, so it lines up exactly.
    bar.fade:SetTexCoord((fillWidth - fadeWidth) / barWidth, frac, 0, 1)
    bar.edge:SetTexCoord(math.max(0, (fillWidth - 3) / barWidth), frac, 0, 1)
    bar.edge:SetShown(frac > 0 and frac < 1)
    bar.text:SetText(L("RPG_PROGRESS_BAR", done, total, total > 0 and math.floor(done / total * 100) or 0))
    bar.capR:SetShown(total > 0 and done >= total)
end

-- ------------------------------------------------------------ boss kills
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
events:RegisterEvent("LOOT_OPENED")
events:RegisterUnitEvent("UNIT_HEALTH", "target", "focus", "boss1", "boss2", "boss3", "boss4")
events:RegisterEvent("ENCOUNTER_END")
events:RegisterEvent("BOSS_KILL")
events:RegisterEvent("QUEST_TURNED_IN")
pcall(events.RegisterEvent, events, "NAME_PLATE_UNIT_REMOVED")
pcall(events.RegisterEvent, events, "UNIT_DIED")
pcall(events.RegisterEvent, events, "PARTY_KILL")

local function NpcFromGUID(guid)
    guid = Plain(guid)
    if type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

-- A final boss by its name (localized, or an alias): for one known by name
-- only (kroldok), and for one whose live NPC ID differs from the journal's
-- (Rath'Mael). Counts inside its own dungeon only.
local function NameFinalHere(who)
    who = Plain(who)
    if type(who) ~= "string" or who == "" then return nil end
    local lower = string.lower(who)
    local name = finalNames[lower] or finalNames[(lower:gsub("\226\128\153", "'"))]
    if not name then return nil end
    local okH, here = pcall(function() return FDJ.CurrentDungeon and FDJ.CurrentDungeon() end)
    if okH and here == name then return name end
end

-- A final boss lying dead in front of you (targeted, hovered, looted, or
-- dying as your target/boss frame) unlocks its dungeon.
local function CheckDead(unit)
    if type(unit) ~= "string" or not UnitExists or not UnitExists(unit) then return end
    local ok, dead = pcall(UnitIsDead, unit)
    if not ok or not Plain(dead) then return end
    Build()
    local okG, guid = pcall(UnitGUID, unit)
    local id = okG and NpcFromGUID(guid)
    local name = id and finalByNpc[id]
    if not name and id then
        local okN, who = pcall(UnitName, unit)
        name = okN and NameFinalHere(who) or nil
    end
    if name then Unlock(name) end
end

-- A final boss dying near the character (no need to target it): the game's
-- UNIT_DIED and PARTY_KILL events, which carry the GUID only. Not the combat
-- log: WoW Forever closes COMBAT_LOG_EVENT_* to addons (registering for it
-- gets the addon blocked).
local function DiedGUID(guid)
    local id = NpcFromGUID(guid)
    if not id then return end
    Build()
    local name = finalByNpc[id]
    if name then Unlock(name) end
end

local chooserPending = false
events:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_DIED" then
        DiedGUID((...))
    elseif event == "PARTY_KILL" then
        local _, target = ...
        DiedGUID(target)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        if type(unit) == "string" then pcall(CheckDead, unit) end
    elseif event == "UNIT_HEALTH" or event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" or event == "LOOT_OPENED" then
        local unit = (event == "UNIT_HEALTH" and ...) or (event == "UPDATE_MOUSEOVER_UNIT" and "mouseover") or "target"
        CheckDead(unit)
    elseif event == "ENCOUNTER_END" or event == "BOSS_KILL" then
        local bossName, success
        if event == "ENCOUNTER_END" then
            local _, n, _, _, s = ...
            bossName, success = n, s
        else
            local _, n = ...
            bossName, success = n, 1
        end
        bossName = Plain(bossName)
        if success ~= 1 and success ~= true then return end
        if type(bossName) ~= "string" then return end
        Build()
        local name = finalNames[string.lower(bossName)]
        if name then Unlock(name) end
    elseif event == "QUEST_TURNED_IN" then
        if C_Timer and C_Timer.After then
            C_Timer.After(1, function() if FDJ.RefreshHomeCards then pcall(FDJ.RefreshHomeCards) end end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if FDJ.UpdateMinimapIcon then pcall(FDJ.UpdateMinimapIcon) end
        if chooserPending then return end
        chooserPending = true
        if CharDB().journalMode == nil and C_Timer and C_Timer.After then
            C_Timer.After(3, function() FDJ.ShowModeChooser(false) end)
        end
    end
end)

-- ---------------------------------------------------------- mode chooser
local chooser
local function OptionCard(parent, icon, titleKey, descKey, mode)
    local c = CreateFrame("Button", nil, parent, "BackdropTemplate")
    c:SetSize(250, 230)
    c:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    c:SetBackdropColor(0.09, 0.07, 0.05, 0.96)
    c:SetBackdropBorderColor(0.55, 0.43, 0.24, 1)
    local ic = c:CreateTexture(nil, "ARTWORK")
    ic:SetSize(52, 52)
    ic:SetPoint("TOP", 0, -18)
    ic:SetTexture(icon)
    ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    c.title = c:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
    c.title:SetPoint("TOP", ic, "BOTTOM", 0, -10)
    c.desc = c:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    c.desc:SetPoint("TOP", c.title, "BOTTOM", 0, -10)
    c.desc:SetWidth(222)
    c.desc:SetJustifyH("CENTER")
    c.titleKey, c.descKey = titleKey, descKey
    local pick = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    FDJ.OwnFonts(pick) -- ownfonts (2.0.8)
    pick:SetSize(150, 24)
    pick:SetPoint("BOTTOM", 0, 14)
    c.pick = pick
    local function Apply()
        FDJ.SetJournalMode(mode)
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
        parent:Hide()
    end
    local function Choose()
        -- RPG Mode hides content, so make sure the player knows what they picked.
        if mode == "rpg" and FDJ.ShowRPGConfirm then
            FDJ.ShowRPGConfirm(parent, Apply)
        else
            Apply()
        end
    end
    pick:SetScript("OnClick", Choose)
    c:SetScript("OnClick", Choose)
    c:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1.00, 0.82, 0.30, 1) end)
    c:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.55, 0.43, 0.24, 1) end)
    return c
end

-- "Are you sure?" box shown over the chooser when RPG Mode is picked.
local confirm
function FDJ.ShowRPGConfirm(parent, onOk)
    if not confirm then
        confirm = CreateFrame("Frame", "ForeverDungeonJournalRPGConfirm", UIParent, "BackdropTemplate")
        confirm:SetSize(400, 150)
        confirm:SetFrameStrata("FULLSCREEN_DIALOG")
        confirm:SetToplevel(true)
        confirm:EnableMouse(true)
        confirm:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            edgeSize = 26,
            insets = { left = 7, right = 7, top = 7, bottom = 7 },
        })
        confirm:SetBackdropColor(0.04, 0.035, 0.03, 0.98)
        confirm.text = confirm:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
        confirm.text:SetPoint("TOP", 0, -26)
        confirm.text:SetWidth(352)
        confirm.text:SetJustifyH("CENTER")
        confirm.text:SetJustifyV("TOP")
        if confirm.text.SetWordWrap then confirm.text:SetWordWrap(true) end
        if confirm.text.SetNonSpaceWrap then confirm.text:SetNonSpaceWrap(true) end
        if confirm.text.SetMaxLines then confirm.text:SetMaxLines(0) end
        confirm.ok = CreateFrame("Button", nil, confirm, "UIPanelButtonTemplate")
        FDJ.OwnFonts(confirm.ok) -- ownfonts (2.0.8)
        confirm.ok:SetSize(130, 24)
        confirm.ok:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -6, 20)
        confirm.back = CreateFrame("Button", nil, confirm, "UIPanelButtonTemplate")
        FDJ.OwnFonts(confirm.back) -- ownfonts (2.0.8)
        confirm.back:SetSize(130, 24)
        confirm.back:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 6, 20)
        confirm.back:SetScript("OnClick", function() confirm:Hide() end)
    end
    confirm.text:SetText(L("RPG_CONFIRM_TEXT"))
    confirm.ok:SetText(L("RPG_CONFIRM_OK"))
    confirm.back:SetText(L("RPG_CONFIRM_BACK"))
    -- Size the box to the wrapped text (CJK and German run long).
    confirm.text:SetHeight(0)
    local textHeight = math.max(confirm.text:GetStringHeight() or 0, 40)
    confirm.text:SetHeight(textHeight + 4)
    confirm:SetHeight(textHeight + 100)
    confirm.ok:SetScript("OnClick", function() confirm:Hide() onOk() end)
    confirm:ClearAllPoints()
    confirm:SetPoint("CENTER", parent or UIParent, "CENTER", 0, 0)
    confirm:SetFrameLevel(((parent and parent:GetFrameLevel()) or 1) + 20)
    confirm:Show()
end

function FDJ.ShowModeChooser(force)
    if not force and CharDB().journalMode ~= nil then return end
    if not chooser then
        chooser = CreateFrame("Frame", "ForeverDungeonJournalModeChooser", UIParent, "BackdropTemplate")
        chooser:SetSize(580, 360)
        chooser:SetPoint("CENTER", 0, 60)
        chooser:SetFrameStrata("FULLSCREEN_DIALOG")
        chooser:EnableMouse(true)
        chooser:SetMovable(true)
        chooser:RegisterForDrag("LeftButton")
        chooser:SetScript("OnDragStart", chooser.StartMoving)
        chooser:SetScript("OnDragStop", chooser.StopMovingOrSizing)
        chooser:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            edgeSize = 26,
            insets = { left = 7, right = 7, top = 7, bottom = 7 },
        })
        chooser:SetBackdropColor(0.04, 0.035, 0.03, 0.97)
        local icon = chooser:CreateTexture(nil, "ARTWORK")
        icon:SetSize(26, 26)
        icon:SetPoint("TOPLEFT", 20, -18)
        icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        chooser.title = chooser:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
        chooser.title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        chooser.sub = chooser:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
        chooser.sub:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -8)
        chooser.sub:SetTextColor(0.75, 0.72, 0.66)
        chooser.gamer = OptionCard(chooser, "Interface\\Icons\\INV_Misc_Book_09", "MODE_GAMER", "MODE_GAMER_DESC", "gamer")
        chooser.gamer:SetPoint("BOTTOMLEFT", 30, 24)
        chooser.rpg = OptionCard(chooser, "Interface\\AddOns\\ForeverDungeonJournal\\Media\\RPGJournalIcon", "MODE_RPG", "MODE_RPG_DESC", "rpg")
        chooser.rpg:SetPoint("BOTTOMRIGHT", -30, 24)
        local close = CreateFrame("Button", nil, chooser, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        -- Closing without picking keeps the usual journal.
        close:SetScript("OnClick", function()
            if CharDB().journalMode == nil then FDJ.SetJournalMode("gamer") end
            chooser:Hide()
        end)
    end
    chooser.title:SetText(L("MODE_TITLE"))
    chooser.sub:SetText(L("MODE_SUB"))
    for _, c in ipairs({ chooser.gamer, chooser.rpg }) do
        c.title:SetText(L(c.titleKey))
        c.desc:SetText(L(c.descKey))
        c.pick:SetText(L("MODE_CHOOSE"))
    end
    chooser:Show()
end

-- BEGIN rpgintro
-- ------------------------------------------------- RPG Mode note and button
-- RPG Mode is often picked at login without reading the warning, and the
-- journal then looks empty. The first time a character sees the dungeon list
-- in RPG Mode, a note over the cards says why, with a way to the option that
-- turns it off. The RPG Mode button in the header opens the same note any
-- time. Turning RPG Mode on again (options, /dj mode) shows the note once more.
local intro

-- Top of the Journey bar in its own (scaled) units. The header row of buttons
-- (RPG Mode, Favourites, Loot Filter, Hide Dungeons) sits above it, and the
-- separator line moves down to just under it. Used by ForeverFilter.lua too.
FDJ.RPG_BAR_Y = 51

-- The white journal book of the minimap button in RPG Mode: the addon's book
-- icon, desaturated, with a brightening copy on top.
local BOOK = "Interface\\Icons\\INV_Misc_Book_09"
local function WhiteBook(parent, size)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    icon:SetTexture(BOOK)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetDesaturated(true)
    local glow = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    glow:SetAllPoints(icon)
    glow:SetTexture(BOOK)
    glow:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    glow:SetDesaturated(true)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.6)
    return icon
end

local function InkText(fs, r, g, b)
    fs:SetTextColor(r, g, b)
    fs:SetShadowColor(0, 0, 0, 0)
end

local function SizeIntroButton(btn)
    local fs = btn:GetFontString()
    local w = fs and fs:GetStringWidth() or 0
    btn:SetWidth(math.max(150, math.ceil(w + 36)))
    return btn:GetWidth() or 150
end

local function ModeTooltip(btn, titleKey, descKey)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L(titleKey), 1, 0.82, 0)
        GameTooltip:AddLine(L(descKey), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function ClickSound()
    if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end

local function AnswerIntro(keepRPG)
    CharDB().rpgIntroSeen = true
    GameTooltip:Hide()
    if intro then intro:Hide() end
    ClickSound()
    -- The player turns RPG Mode off themselves, so they learn where it lives.
    if not keepRPG and FDJ.OpenSettingsAt then FDJ.OpenSettingsAt("OPT_RPG_MODE") end
end

-- Separator line under the header: lower in RPG Mode, where the Journey bar
-- sits under the row of buttons.
local function HeaderLineY(frame)
    local bar = frame.rpgBar
    if not (bar and FDJ.IsRPGMode()) then return -58 end
    local s = bar:GetScale() or 1
    return -math.floor(FDJ.RPG_BAR_Y * s + (bar:GetHeight() or 18) * s + 5 + 0.5)
end

local function BuildIntro(frame)
    local home = frame.homePanel
    -- Dark veil over the dungeon cards (the header with the Journey bar and
    -- its buttons stays usable). It takes the clicks and the mouse wheel, so
    -- the cards underneath wait until the note is answered.
    local shade = CreateFrame("Frame", "ForeverDungeonJournalRPGIntro", home)
    shade:Hide() -- so the first Show() runs OnShow below
    shade:SetFrameLevel(home:GetFrameLevel() + 40)
    shade:EnableMouse(true)
    if shade.EnableMouseWheel then shade:EnableMouseWheel(true) end
    shade:SetScript("OnMouseWheel", function() end)
    local veil = shade:CreateTexture(nil, "BACKGROUND")
    veil:SetAllPoints()
    veil:SetColorTexture(0, 0, 0, 0.6)
    -- The RPG Mode button stays lit while its note is open.
    shade:SetScript("OnShow", function()
        local b = frame.rpgModeButton
        if b then b:SetBackdropBorderColor(1.00, 0.82, 0.30, 1) end
    end)
    shade:SetScript("OnHide", function()
        local b = frame.rpgModeButton
        if b then b:SetBackdropBorderColor(0.48, 0.40, 0.27, 1) end
    end)

    -- The note: the same parchment as the locked pages, in a gold frame.
    local note = CreateFrame("Frame", nil, shade, "BackdropTemplate")
    note:SetSize(460, 170)
    note:SetPoint("CENTER", 0, 20)
    note:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    note:SetBackdropColor(0.60, 0.51, 0.36, 1)
    local paper = note:CreateTexture(nil, "BACKGROUND", nil, 1)
    paper:SetPoint("TOPLEFT", 6, -6)
    paper:SetPoint("BOTTOMRIGHT", -6, 6)
    paper:SetTexture(MEDIA .. "Parchment")
    paper:SetTexCoord(0, 1, 0, 176 / 256)
    shade.note = note

    -- "RPG Mode" with the RPG journal icon (the one from the mode chooser).
    note.title = note:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalHuge")
    note.title:SetPoint("TOP", 22, -26) -- half the icon + gap, so the pair is centred
    InkText(note.title, 0.30, 0.16, 0.04)
    local iconFrame = CreateFrame("Frame", nil, note, "BackdropTemplate")
    iconFrame:SetSize(36, 36)
    iconFrame:SetPoint("RIGHT", note.title, "LEFT", -8, 0)
    iconFrame:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
    iconFrame:SetBackdropBorderColor(0.55, 0.40, 0.18, 1)
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\RPGJournalIcon")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    note.text = note:CreateFontString(nil, "OVERLAY", _G.ForeverDJ_GameFontHighlightMedium and "ForeverDJ_GameFontHighlightMedium" or "ForeverDJ_GameFontHighlight")
    note.text:SetPoint("TOP", note, "TOP", 0, -66)
    note.text:SetWidth(400)
    note.text:SetJustifyH("CENTER")
    if note.text.SetWordWrap then note.text:SetWordWrap(true) end
    InkText(note.text, 0.17, 0.11, 0.05)

    -- The way out on the left (as Gamer Mode is in the chooser), RPG on the right.
    note.options = CreateFrame("Button", nil, note, "UIPanelButtonTemplate")
    FDJ.OwnFonts(note.options) -- ownfonts (2.0.8)
    note.options:SetHeight(26)
    note.options:SetPoint("BOTTOMRIGHT", note, "BOTTOM", -6, 22)
    note.options:SetScript("OnClick", function() AnswerIntro(false) end)
    ModeTooltip(note.options, "MODE_GAMER", "MODE_GAMER_DESC")
    note.keep = CreateFrame("Button", nil, note, "UIPanelButtonTemplate")
    FDJ.OwnFonts(note.keep) -- ownfonts (2.0.8)
    note.keep:SetHeight(26)
    note.keep:SetPoint("BOTTOMLEFT", note, "BOTTOM", 6, 22)
    note.keep:SetScript("OnClick", function() AnswerIntro(true) end)
    ModeTooltip(note.keep, "MODE_RPG", "MODE_RPG_DESC")
    return shade
end

local function ShowIntro(frame)
    local home = frame and frame.homePanel
    if not home then return end
    if not intro then intro = BuildIntro(frame) end
    -- Cover the dungeon cards, from just under the header's separator line.
    intro:ClearAllPoints()
    intro:SetPoint("TOPLEFT", home, "TOPLEFT", 5, HeaderLineY(frame) - 2)
    intro:SetPoint("BOTTOMRIGHT", home, "BOTTOMRIGHT", -5, 5)
    local note = intro.note
    note.title:SetText(L("MODE_RPG"))
    note.text:SetText(L("RPG_INTRO_TEXT"))
    note.options:SetText(L("RPG_INTRO_OPTIONS"))
    note.keep:SetText(L("RPG_INTRO_KEEP"))
    local w = SizeIntroButton(note.options) + SizeIntroButton(note.keep)
    note:SetWidth(math.max(460, math.ceil(w + 12 + 60)))
    -- Room for one or two lines of text (German and Russian wrap).
    local textHeight = math.max(note.text:GetStringHeight() or 0, 16)
    note:SetHeight(math.floor(66 + textHeight + 22 + 26 + 22 + 0.5))
    intro:Show()
end
FDJ.ShowRPGIntro = function() ShowIntro(_G.ForeverDungeonJournalFrame) end

-- "RPG Mode" button in the home header, left of Favourites, in the same dark
-- and gold style as the buttons next to it, with the white journal book.
local function RPGModeButton(frame)
    if frame.rpgModeButton then return frame.rpgModeButton end
    local b = CreateFrame("Button", nil, frame.homePanel, "BackdropTemplate")
    b:SetSize(110, 28)
    b:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    b:SetBackdropColor(0.12, 0.115, 0.105, 0.98)
    b:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.icon = WhiteBook(b, 16)
    b.icon:SetPoint("LEFT", 10, 0)
    b.text = b:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.text:SetTextColor(1.00, 0.82, 0.27)
    b:SetScript("OnClick", function()
        ClickSound()
        if intro and intro:IsShown() then intro:Hide() else ShowIntro(frame) end
    end)
    frame.rpgModeButton = b
    return b
end

local function PlaceRPGModeButton(frame)
    local b = RPGModeButton(frame)
    b.text:SetText(L("MODE_RPG"))
    b:SetWidth(math.max(96, math.min(170, math.ceil((b.text:GetStringWidth() or 60) + 44))))
    b:ClearAllPoints()
    local runLog = frame.runLogButton and frame.runLogButton:IsShown() and frame.runLogButton
    local right = runLog or frame.favouritesButton or frame.lootFilterButton or frame.hideDungeonsButton
    if right then
        b:SetPoint("RIGHT", right, "LEFT", -8, 0)
    else
        b:SetPoint("TOPRIGHT", frame.homePanel, "TOPRIGHT", -15, -13)
    end
    b:Show()
end

-- The home list calls UpdateRPGHeader after every refresh (opening the
-- journal, mode or language change), so the header and note follow the mode.
local UpdateHeaderWithoutIntro = FDJ.UpdateRPGHeader
FDJ.UpdateRPGHeader = function(frame, ...)
    local ok, err = pcall(UpdateHeaderWithoutIntro, frame, ...)
    local home = frame and frame.homePanel
    if home then
        local rpg = FDJ.IsRPGMode()
        if rpg then
            PlaceRPGModeButton(frame)
        elseif frame.rpgModeButton then
            frame.rpgModeButton:Hide()
        end
        if frame.homeLine then
            local y = HeaderLineY(frame)
            frame.homeLine:ClearAllPoints()
            frame.homeLine:SetPoint("TOPLEFT", home, "TOPLEFT", 18, y)
            frame.homeLine:SetPoint("TOPRIGHT", home, "TOPRIGHT", -31, y)
        end
        if not rpg then
            if intro then intro:Hide() end
        elseif not CharDB().rpgIntroSeen or (intro and intro:IsShown()) then
            ShowIntro(frame)
        end
    end
    if not ok then error(err, 0) end
end

-- Turning RPG Mode on (chooser, options, /dj mode) shows the note again once.
local SetJournalModeWithoutIntro = FDJ.SetJournalMode
FDJ.SetJournalMode = function(mode, ...)
    local db = CharDB()
    if mode == "rpg" and db.journalMode ~= "rpg" then db.rpgIntroSeen = nil end
    return SetJournalModeWithoutIntro(mode, ...)
end

-- Mode chooser (first login, /dj mode): RPG Mode is not switched on from
-- here. Its button reads "Enable in Options" and opens the options on the
-- RPG Mode box, which the player ticks themselves, so they know where it is.
-- Until then the journal stays in Gamer Mode (and the chooser is answered).
local ShowModeChooserWithoutOptions = FDJ.ShowModeChooser
FDJ.ShowModeChooser = function(force, ...)
    ShowModeChooserWithoutOptions(force, ...)
    local chooser = _G.ForeverDungeonJournalModeChooser
    local card = chooser and chooser.rpg
    if not (card and card.pick) then return end
    card.pick:SetText(L("MODE_RPG_ENABLE"))
    local fs = card.pick:GetFontString()
    card.pick:SetWidth(math.max(150, math.min(230, math.ceil((fs and fs:GetStringWidth() or 0) + 30))))
    if card.fdjOptions then return end
    card.fdjOptions = true
    local function EnableInOptions()
        if CharDB().journalMode == nil then FDJ.SetJournalMode("gamer") end
        ClickSound()
        chooser:Hide()
        if FDJ.OpenSettingsAt then FDJ.OpenSettingsAt("OPT_RPG_MODE") end
    end
    card.pick:SetScript("OnClick", EnableInOptions)
    card:SetScript("OnClick", EnableInOptions)
end

-- Dev: /dj devpopup puts this character back to its first login (no journal
-- mode chosen, RPG note unseen; RPG progress is kept) and opens the mode
-- chooser, to test the whole first-time flow.
local SlashWithoutDevPopup = SlashCmdList and SlashCmdList.FOREVERDUNGEONJOURNAL
if false and SlashWithoutDevPopup then -- dev command, off for release
    SlashCmdList.FOREVERDUNGEONJOURNAL = function(msg, ...)
        local cmd = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if cmd == "devpopup" then
            local db = CharDB()
            db.journalMode = nil
            db.rpgIntroSeen = nil
            if intro then intro:Hide() end
            if FDJ.RefreshHomeCards then pcall(FDJ.RefreshHomeCards) end
            if FDJ.UpdateMinimapIcon then pcall(FDJ.UpdateMinimapIcon) end
            print("|cffd8a83cDungeon Journal:|r first-login popup (dev): journal mode reset for this character, RPG progress kept.")
            FDJ.ShowModeChooser(false)
            return
        end
        return SlashWithoutDevPopup(msg, ...)
    end
end
-- END rpgintro

-- BEGIN questunlock
-- ------------------------------------------------ RPG Mode: quests unlocked
-- A dungeon's quests unlock too, one by one, as this character comes to
-- them: accepting the quest, or any step of the chain that leads to it. In
-- RPG Mode a small achievement pops up, the same as for a page: "Dungeon
-- Quest Unlocked", the dungeon, a ! on its sketch, and on the shield how many
-- of that dungeon's quests this character has unlocked out of all it can take
-- (own faction, class and professions), e.g. 2/6, with the same line in chat.
-- Quests done or in the quest log (or with a chain step done or in the log)
-- count as unlocked without a popup. Kept in Gamer Mode too, silently, like
-- the pages, so turning RPG Mode on later doesn't pop old quests.
do
    local function QuestsUnlocked()
        local db = CharDB()
        if type(db.rpgQuests) ~= "table" then db.rpgQuests = {} end
        return db.rpgQuests
    end

    -- Every quest this character can take on every journal page, in the
    -- journal's order (a quest on several pages is listed on each).
    local function Mine()
        local faction = UnitFactionGroup and Plain(UnitFactionGroup("player"))
        local _, class = UnitClass("player")
        class = Plain(class)
        local list = {}
        for _, name in ipairs(FDJ.ORDER or {}) do
            local d = FDJ.DB and FDJ.DB[name]
            local seen = {}
            for _, q in ipairs((d and not d.previewOnly and not d.questChainPage and d.quests) or {}) do
                if type(q) == "table" and type(q.id) == "number" and not seen[q.id] then
                    local forFaction = q.faction == nil or q.faction == "Both" or q.faction == "Neutral" or q.faction == faction
                    local forClass = not q.classOnly or (class and FDJ.QuestClassMatches(q.classOnly, class)) -- (twoclasses)
                    local forProfession = not q.profession or not FDJ.PlayerHasProfession or FDJ.PlayerHasProfession(q.profession)
                    if forFaction and forClass and forProfession and not q.hideFromMainList and not q.repeatable then
                        seen[q.id] = true
                        list[#list + 1] = { dungeon = name, quest = q }
                    end
                end
            end
        end
        return list
    end

    local function Steps(q)
        local chain = FDJ.QUEST_PREREQ_CHAINS and FDJ.QUEST_PREREQ_CHAINS[q.id]
        return type(chain) == "table" and chain or {}
    end

    -- Accepting this quest unlocks q: q itself or a step of its chain.
    local function Leads(q, id)
        if q.id == id then return true end
        for _, step in ipairs(Steps(q)) do
            if type(step) == "table" and step.id == id then return true end
        end
        return false
    end

    local function Started(id, skip)
        if type(id) ~= "number" or id == skip then return false end
        if FDJ.QuestTurnedIn and FDJ.QuestTurnedIn(id) then return true end
        return FDJ.IsQuestInLog and FDJ.IsQuestInLog(id) == true or false
    end

    -- Quests (or chain steps) done or in the quest log: unlocked, no popup.
    -- Once a session, a few seconds after login (or before the first quest
    -- accepted, leaving that one out).
    local seeded = false
    local function Seed(skip)
        seeded = true
        local unlocked = QuestsUnlocked()
        for _, e in ipairs(Mine()) do
            local q = e.quest
            if not unlocked[q.id] then
                local started = Started(q.id, skip)
                if not started then
                    for _, step in ipairs(Steps(q)) do
                        if type(step) == "table" and Started(step.id, skip) then started = true break end
                    end
                end
                if started then unlocked[q.id] = true end
            end
        end
        ShareProgress()
    end

    local function Count(list, name)
        local unlocked, n, total = ViewTable("rpgQuests"), 0, 0
        for _, e in ipairs(list) do
            if e.dungeon == name then
                total = total + 1
                if unlocked[e.quest.id] then n = n + 1 end
            end
        end
        return n, total
    end

    local function DungeonName(name)
        return FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(name) or name
    end

    local function QuestName(q)
        local shown = FDJ.LocalizeQuestField and FDJ.LocalizeQuestField(q.id, "name", q.name)
        return type(shown) == "string" and shown ~= "" and shown or q.name or ("#" .. tostring(q.id))
    end

    local function Hint(entry)
        if entry.kind == "map" then
            return L(FDJ.IsDungeonLocked(entry.dungeon) and "RPG_MAP_TOAST_HINT_M" or "RPG_MAP_TOAST_HINT")
        end
        if FDJ.IsDungeonLocked(entry.dungeon) then return L("RPG_LOCKED_MSG") end
        return L("RPG_QUEST_TOAST_HINT")
    end

    -- The ! of a quest; the dungeon map's icon (as on the Map tab) for a map.
    local BADGES = {
        quest = { "Interface\\GossipFrame\\AvailableQuestIcon", 0, 1, 0, 1 },
        map = { "Interface\\Icons\\Ability_Spy", 0.07, 0.93, 0.07, 0.93 },
    }

    -- --------------------------------------------------------------- popup
    -- The page unlock's toast, with a ! on the sketch. One at a time: the
    -- rest wait their turn; another quest of the dungeon on screen counts up
    -- on it instead.
    local queue = {}
    local Show

    local function ShowNext()
        if toast and toast:IsShown() then return end
        local entry = table.remove(queue, 1)
        if entry then Show(entry) end
    end

    local function Toast()
        if not toast then
            toast = HasAtlas("ui-achievement-guild-background") and BuildAchievementToast() or BuildPlainToast()
        end
        local t = toast
        if t.fdjQuestReady then return t end
        t.fdjQuestReady = true

        local owner = t.sketch.GetParent and t.sketch:GetParent() or t
        local holder = CreateFrame("Frame", nil, t)
        holder:SetAllPoints(t)
        holder:SetFrameLevel(((owner and owner.GetFrameLevel and owner:GetFrameLevel()) or t:GetFrameLevel() or 1) + 2)
        t.questBadge = holder:CreateTexture(nil, "OVERLAY")
        t.questBadge:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
        if t.unlocked then
            t.questBadge:SetSize(22, 22)
            t.questBadge:SetPoint("BOTTOMRIGHT", t.sketch, "BOTTOMRIGHT", 6, -4)
        else
            t.questBadge:SetSize(26, 26)
            t.questBadge:SetPoint("BOTTOMRIGHT", t.sketch, "BOTTOMRIGHT", -18, 0)
        end
        t.questBadge:Hide()

        local pageEnter, pageClick = t:GetScript("OnEnter"), t:GetScript("OnClick")
        t:SetScript("OnEnter", function(self, ...)
            local entry = self.questEntry
            if not entry then
                if pageEnter then return pageEnter(self, ...) end
                return
            end
            self.outro:Stop(); self:SetAlpha(1)
            if not self.unlocked then return end -- the plain one has its hint on it
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            if entry.kind == "map" then GameTooltip:SetText(DungeonName(entry.dungeon), 1, 0.82, 0) end
            for i, q in ipairs(entry.quests) do
                if i == 1 and entry.kind ~= "map" then GameTooltip:SetText(QuestName(q), 1, 0.82, 0) else GameTooltip:AddLine(QuestName(q), 1, 0.82, 0) end
            end
            GameTooltip:AddLine(Hint(entry), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        t:SetScript("OnClick", function(self, button, ...)
            local entry = self.questEntry
            if not entry then
                if pageClick then return pageClick(self, button, ...) end
                return
            end
            GameTooltip:Hide()
            self.outro:Stop()
            self:Hide()
            if button ~= "LeftButton" then return end
            local journal = _G.ForeverDungeonJournalFrame
            if FDJ.ToggleJournal and not (journal and journal:IsShown()) then pcall(FDJ.ToggleJournal) end
            if FDJ.IsDungeonLocked(entry.dungeon) then return end
            if entry.kind == "map" then
                if FDJ.OpenDungeonMap then pcall(FDJ.OpenDungeonMap, entry.dungeon) end
            elseif FDJ.OpenQuestChain then
                pcall(FDJ.OpenQuestChain, entry.dungeon, entry.questID)
            elseif FDJ.OpenQuestPage then
                pcall(FDJ.OpenQuestPage, entry.dungeon, entry.questID)
            end
        end)
        t:HookScript("OnHide", function(self)
            if self:IsShown() then return end -- the whole UI hidden (Alt+Z): still up
            self.questEntry = nil
            if #queue > 0 then
                if C_Timer and C_Timer.After then C_Timer.After(0.3, ShowNext) else ShowNext() end
            end
        end)
        return t
    end

    Show = function(entry, again)
        local t = Toast()
        t.questEntry = entry
        t.dungeon = entry.dungeon
        t.sketch:SetTexture(SketchFor(entry.dungeon))
        local badge = BADGES[entry.kind or "quest"] or BADGES.quest
        t.questBadge:SetTexture(badge[1])
        t.questBadge:SetTexCoord(badge[2], badge[3], badge[4], badge[5])
        t.questBadge:Show()
        t.name:SetText(DungeonName(entry.dungeon))
        local count = entry.count or (entry.n .. "/" .. entry.total)
        local title = entry.title or L("RPG_QUEST_TOAST_TITLE")
        if t.unlocked then
            t.guild:SetText("Dungeon Journal")
            t.unlocked:SetText(title)
            t.points:SetText(count)
            t.left = 4.05
        else
            t.header:SetText(title .. "  |cff40ff40" .. count .. "|r")
            t.hint:SetText(Hint(entry))
            t.left = 6
        end
        t.outro:Stop()
        t:SetAlpha(1)
        t:Show()
        if not again then t.intro:Stop(); t.intro:Play() end
        t.sweep:Stop(); t.sweep:Play()
        PlayFanfare()
    end

    local function Enqueue(entry)
        -- Options > RPG Mode > Hide Quest Achievement Popups
        if (entry.kind or "quest") == "quest" and FDJ.RPGOption("hideQuestPopups") then return end
        -- showquests (2.0.16): Show dungeon quests: no quest popups either.
        if (entry.kind or "quest") == "quest" and FDJ.RPGOption("showQuests") then return end
        local t = Toast()
        if not t:IsShown() then return Show(entry) end
        local current = t.questEntry
        local fading = t.outro.IsPlaying and t.outro:IsPlaying()
        local waiting
        local kind = entry.kind or "quest"
        if current and current.dungeon == entry.dungeon and (current.kind or "quest") == kind and not fading then
            waiting = current
        else
            for _, e in ipairs(queue) do
                if e.dungeon == entry.dungeon and (e.kind or "quest") == kind then waiting = e break end
            end
        end
        if waiting then
            for _, q in ipairs(entry.quests) do waiting.quests[#waiting.quests + 1] = q end
            waiting.n, waiting.total = entry.n, entry.total
            if waiting == current then Show(current, true) end
            return
        end
        if #queue < 8 then queue[#queue + 1] = entry end
    end
    -- Other RPG Mode popups (the dungeon map unlocking) use the same frame
    -- and queue: { kind, dungeon, title, count, quests }.
    FDJ.RPGToast = function(entry) pcall(Enqueue, entry) end

    -- Page toasts take the frame as they always did, without the !. A quest
    -- popup they cut short comes back after them.
    local ShowPageToast = ShowUnlockToast
    ShowUnlockToast = function(name, ...)
        if toast then
            local cut = toast.questEntry
            if cut and toast:IsShown() and (toast.left or 0) > 1 then table.insert(queue, 1, cut) end
            toast.questEntry = nil
            if toast.questBadge then toast.questBadge:Hide() end
        end
        return ShowPageToast(name, ...)
    end

    -- ------------------------------------------------------------ accepted
    local function Accepted(id)
        if type(id) ~= "number" then return end
        if not seeded then Seed(id) end
        local list = Mine()
        local unlocked = QuestsUnlocked()
        -- Account-wide: a quest another character already unlocked gets no popup.
        local shown = ViewTable("rpgQuests")
        local now, fresh, order = {}, {}, {}
        for _, e in ipairs(list) do
            local q = e.quest
            if Leads(q, id) then
                if not unlocked[q.id] then
                    local open = shown[q.id] and true or false
                    unlocked[q.id] = true
                    if not open then now[q.id] = true end
                end
                if now[q.id] then
                    if not fresh[e.dungeon] then
                        fresh[e.dungeon] = {}
                        order[#order + 1] = e.dungeon
                    end
                    table.insert(fresh[e.dungeon], q)
                end
            end
        end
        ShareProgress()
        if #order == 0 then return end
        if FDJ.RPGStateChanged then pcall(FDJ.RPGStateChanged) end
        if not FDJ.IsRPGMode() then return end
        -- One popup: the page the accepted quest is on, else the first page
        -- its chain leads to. Every page gets its line in chat.
        local pick
        for _, name in ipairs(order) do
            for _, q in ipairs(fresh[name]) do
                if q.id == id and not pick then pick = name end
            end
        end
        pick = pick or order[1]
        for _, name in ipairs(order) do
            local n, total = Count(list, name)
            print("|cffd8a83cDungeon Journal:|r |cff40ff40" .. L("RPG_QUEST_UNLOCKED_MSG", DungeonName(name), n, total) .. "|r")
            if name == pick then
                local mainID = fresh[name][1].id
                for _, q in ipairs(fresh[name]) do
                    if q.id == id then mainID = id end
                end
                local quests = {}
                for i, q in ipairs(fresh[name]) do quests[i] = q end
                local ok, err = pcall(Enqueue, { dungeon = name, quests = quests, questID = mainID, n = n, total = total })
                if not ok and FDJ.Debug then FDJ.Debug(err) end
            end
        end
    end

    local watch = CreateFrame("Frame")
    watch:RegisterEvent("PLAYER_ENTERING_WORLD")
    watch:RegisterEvent("QUEST_ACCEPTED")
    watch:SetScript("OnEvent", function(_, event, a, b)
        if event == "QUEST_ACCEPTED" then
            -- WoW Forever: (questID); Classic clients: (questLogIndex, questID).
            local id = tonumber(Plain(b)) or tonumber(Plain(a))
            pcall(Accepted, id)
        elseif not seeded then
            if C_Timer and C_Timer.After then
                C_Timer.After(3, function() if not seeded then pcall(Seed) end end)
            else
                pcall(Seed)
            end
        end
    end)

    FDJ.RPGQuestsUnlocked = function(name)
        if not seeded then Seed() end
        return Count(Mine(), name)
    end

    -- Dev: /dj devquest shows the popup (and its chat line) for the next
    -- dungeon with quests this character can take, each time another one, as
    -- if one more of its quests was just unlocked. Any mode; nothing saved.
    local devNext = 0
    local SlashWithoutDevQuest = SlashCmdList and SlashCmdList.FOREVERDUNGEONJOURNAL
    if false and SlashWithoutDevQuest then -- dev command, off for release
        SlashCmdList.FOREVERDUNGEONJOURNAL = function(msg, ...)
            local cmd = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
            if cmd ~= "devquest" then return SlashWithoutDevQuest(msg, ...) end
            if not seeded then Seed() end
            local list = Mine()
            local names, seen = {}, {}
            for _, e in ipairs(list) do
                if not seen[e.dungeon] then
                    seen[e.dungeon] = true
                    names[#names + 1] = e.dungeon
                end
            end
            if #names == 0 then
                print("|cffd8a83cDungeon Journal:|r quest unlock popup (dev): no dungeon quests for this character.")
                return
            end
            devNext = devNext % #names + 1
            local name = names[devNext]
            local n, total = Count(list, name)
            local unlocked, pick, first = QuestsUnlocked(), nil, nil
            for _, e in ipairs(list) do
                if e.dungeon == name then
                    first = first or e.quest
                    if not pick and not unlocked[e.quest.id] then pick = e.quest end
                end
            end
            if pick then n = n + 1 end
            pick = pick or first
            print("|cffd8a83cDungeon Journal:|r |cff40ff40" .. L("RPG_QUEST_UNLOCKED_MSG", DungeonName(name), n, total)
                .. "|r |cff9d9d9d(dev test, nothing saved)|r")
            Show({ dungeon = name, quests = { pick }, questID = pick.id, n = n, total = total })
        end
    end
end
-- END questunlock

-- BEGIN rpgpartial
-- ------------------------------------------ RPG Mode: pages opened by quests
-- A dungeon's page opens partly as soon as one of its quests is unlocked
-- (accepted, or a step of the chain leading to it), before its final boss:
--   * each boss stays a ? ("???") until this character kills it, then shows
--     its usual page;
--   * quests not unlocked yet are ??? rows;
--   * the Map tab is greyed out (and M in the dungeon shows the normal world
--     map), with Trash Drops / Recipes & Patterns, until about 20% of the
--     dungeon's trash has died around this character.
-- The final boss still unlocks everything, as before. Kills are seen as
-- enemies die (nameplates, target, mouseover, loot, encounter end): WoW
-- Forever keeps the combat log from addons. All of it is kept in Gamer Mode
-- too, silently, like the pages.
do
    -- Trash per dungeon: hostile spawns that are not bosses, rares, critters
    -- or friendly NPCs, counted from a classic world database (cmangos
    -- classic-db). The dungeons WoW Forever added are estimates.
    local TRASH = {
        ["Blackfathom Deeps"] = 205,
        ["Blackrock Depths"] = 998,
        ["Dire Maul: East"] = 288,
        ["Dire Maul: North"] = 155,
        ["Dire Maul: West"] = 255,
        ["Gnomeregan"] = 394,
        ["Lower Blackrock Spire"] = 398,
        ["Maraudon"] = 503,
        ["Ragefire Chasm"] = 128,
        ["Razorfen Downs"] = 200,
        ["Razorfen Kraul"] = 182,
        ["Scarlet Monastery: Armory"] = 66,
        ["Scarlet Monastery: Cathedral"] = 93,
        ["Scarlet Monastery: Graveyard"] = 80,
        ["Scarlet Monastery: Library"] = 77,
        ["Scholomance"] = 291,
        ["Shadowfang Keep"] = 117,
        ["Stratholme: Living"] = 268,
        ["Stratholme: Undead"] = 157,
        ["Sunken Temple"] = 225,
        ["The Deadmines"] = 190,
        ["The Stockade"] = 91,
        ["Uldaman"] = 314,
        ["Upper Blackrock Spire"] = 153,
        ["Wailing Caverns"] = 241,
        ["Zul'Farrak"] = 262,
        ["City of Dalaran"] = 140, -- estimate
        ["Excavation Site: Wetlands"] = 60, -- estimate
        ["Hall of Thanes"] = 80, -- estimate
        ["Ruins of Lordaeron"] = 120, -- estimate
        ["The Drowned City"] = 120, -- estimate
        ["Krol'dok Stronghold"] = 120, -- estimate
        ["Alcaz Prison"] = 120, -- estimate
        ["Blackmaw Hold"] = 140, -- estimate (seven bosses)
    }
    local SHARE = 0.20

    local function Store(key)
        local db = CharDB()
        if type(db[key]) ~= "table" then db[key] = {} end
        return db[key]
    end

    local function DungeonName(name)
        return FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(name) or name
    end

    local function BossLabel(name)
        local shown = FDJ.LocalizeBossName and FDJ.LocalizeBossName(name)
        return type(shown) == "string" and shown ~= "" and shown or name
    end

    -- Nothing hidden: Gamer Mode, pages that are not dungeons, "coming soon"
    -- pages, or a page unlocked by its final boss.
    local function FullyOpen(name)
        if not FDJ.IsRPGMode() or not InOrder(name) then return true end
        local d = FDJ.DB and FDJ.DB[name]
        if not d or d.previewOnly or d.questChainPage then return true end
        return ViewTable("rpgKills")[name] == true
    end

    local function QuestOpen(name)
        local d = FDJ.DB and FDJ.DB[name]
        local unlocked = ViewTable("rpgQuests")
        if not d or type(unlocked) ~= "table" then return false end
        for _, q in ipairs(d.quests or {}) do
            if type(q) == "table" and q.id and unlocked[q.id] then return true end
        end
        return false
    end

    local function Need(name)
        return math.max(1, math.ceil((TRASH[name] or 100) * SHARE))
    end

    local function MapOpen(name)
        return ViewTable("rpgMaps")[name] == true
    end

    -- Trash seen dying so far and how much opens the map.
    local function TrashSoFar(name)
        local need = Need(name)
        if MapOpen(name) then return need, need end
        local rec = Store("rpgTrash")[name]
        return math.min(type(rec) == "table" and rec.n or 0, need), need
    end
    FDJ.RPGTrashProgress = TrashSoFar

    -- A locked page opens (partly) once one of its quests is unlocked.
    local LockedUntilFinalBoss = FDJ.IsDungeonLocked
    -- The page's own lock (its card is a sketch): final boss not killed and
    -- none of its quests found yet.
    local function SketchLocked(name, ...)
        if not LockedUntilFinalBoss(name, ...) then return false end
        return not QuestOpen(name)
    end
    FDJ.RPGSketchLocked = SketchLocked
    FDJ.IsDungeonLocked = function(name, ...)
        if not SketchLocked(name, ...) then return false end
        -- showquests (2.0.16): Show dungeon quests opens every page on its quests.
        if FDJ.RPGOption("showQuests") then return false end
        return true
    end

    -- --------------------------------------------------- what stays hidden
    local owner = setmetatable({}, { __mode = "k" }) -- boss table -> dungeon
    local function Owner(boss)
        local found = owner[boss]
        if found == nil then
            for _, name in ipairs(FDJ.ORDER or {}) do
                local d = FDJ.DB and FDJ.DB[name]
                for _, b in ipairs((d and d.bosses) or {}) do owner[b] = name end
            end
            found = owner[boss]
            if found == nil then owner[boss] = false end
        end
        return found or nil
    end

    -- The journal's own boss behind a view of it (Loot Filter and recipe
    -- search pages, filtered loot), and its dungeon.
    local function Real(boss, name, depth)
        local via = rawget(boss, "fdjDungeon")
        local mt = getmetatable(boss)
        local base = mt and type(mt.__index) == "table" and mt.__index or nil
        if via then return base or boss, via end
        local mine = Owner(boss)
        if mine then return boss, mine end
        if base and (depth or 0) < 4 then return Real(base, name, (depth or 0) + 1) end
        return boss, name
    end

    local function Seen(name, boss)
        local list = ViewTable("rpgBosses")[name]
        if type(list) ~= "table" then return false end
        if boss.npcID and list[boss.npcID] then return true end
        -- altarbosses (2.0.24): a group entry ("Altar Bosses") is open once
        -- any one of its children has been seen.
        if type(boss.children) == "table" then
            for _, id in ipairs(boss.children) do
                if list[id] then return true end
            end
            local d = FDJ.DB and FDJ.DB[name]
            for _, b in ipairs((d and d.bosses) or {}) do
                if type(b) == "table" and b.childOf == boss.name and type(b.name) == "string" and list[b.name:lower()] == true then return true end
            end
        end
        return type(boss.name) == "string" and list[boss.name:lower()] == true
    end
    FDJ.RPGBossSeen = Seen -- rpgtorn: the torn page counts bosses the same way

    function FDJ.RPGBossHidden(name, boss)
        if type(boss) ~= "table" or not FDJ.IsRPGMode() then return false end
        local real, dungeon = Real(boss, name)
        if not dungeon or FullyOpen(dungeon) then return false end
        if real.fdjQuestRewards then return false end -- questrewards: its quest was checked already
        if real.trash or real.recipeTab then return not MapOpen(dungeon) end
        return not Seen(dungeon, real)
    end

    function FDJ.RPGQuestHidden(name, quest)
        if type(quest) ~= "table" or not name or FullyOpen(name) then return false end
        if FDJ.RPGOption("showQuests") then return false end -- showquests (2.0.16)
        local unlocked = ViewTable("rpgQuests")
        return not (type(unlocked) == "table" and quest.id and unlocked[quest.id])
    end

    function FDJ.IsDungeonMapLocked(name)
        if not name or FullyOpen(name) then return false end
        return not MapOpen(name)
    end

    -- Boss pins on the dungeon map: a pin with no boss page stays a ? too.
    function FDJ.RPGMapBossHidden(name, boss)
        if not name or FullyOpen(name) then return false end
        if not boss then return true end
        return FDJ.RPGBossHidden(name, boss)
    end

    -- A hidden boss is shown as this: "???", the ?, no level and no loot.
    local stubs = setmetatable({}, { __mode = "k" })
    local function Stub(real)
        local s = stubs[real]
        if not s then
            s = { name = "???", loot = {} }
            stubs[real] = s
        end
        s.fdjRPGHint = L((real.trash or real.recipeTab) and "RPG_TRASH_HIDDEN" or "RPG_BOSS_HIDDEN")
        return s
    end

    function FDJ.RPGBossView(name, boss)
        if FDJ.RPGBossHidden(name, boss) then return Stub((Real(boss, name))) end
        return boss
    end

    -- Hidden bosses' loot is not listed anywhere: boss pages, the Loot
    -- Filter page, search.
    local FilterPlain, ForPagePlain, SearchPlain = FDJ.FilterBossLoot, FDJ.FilterBossLootForPage, FDJ.SearchableBossLoot
    if FilterPlain then
        FDJ.FilterBossLoot = function(boss, ...)
            if FDJ.RPGBossHidden(nil, boss) then
                FDJ.lootFilterHidden = 0
                return setmetatable({ loot = {} }, { __index = boss })
            end
            return FilterPlain(boss, ...)
        end
    end
    if ForPagePlain then
        FDJ.FilterBossLootForPage = function(boss, ...)
            if FDJ.RPGBossHidden(nil, boss) then
                FDJ.lootFilterDimmed, FDJ.lootFilterHidden = {}, 0
                FDJ.lootRecipeCount, FDJ.lootRecipeSplit = 0, nil
                return Stub((Real(boss)))
            end
            return ForPagePlain(boss, ...)
        end
    end
    if SearchPlain then
        FDJ.SearchableBossLoot = function(boss, ...)
            if FDJ.RPGBossHidden(nil, boss) then return {} end
            return SearchPlain(boss, ...)
        end
    end

    -- ------------------------------------------------------- the Map tab
    function FDJ.RPGMapLockedNotice(name)
        local have, need = TrashSoFar(name)
        print("|cffd8a83cDungeon Journal:|r " .. L("RPG_MAP_LOCKED_MSG", have, need))
    end

    function FDJ.RPGStyleMapTab(tab, name)
        if not tab then return end
        local locked = tab:IsShown() and FDJ.IsDungeonMapLocked(name) or false
        tab.fdjRPGMapLocked = locked
        tab.fdjRPGDungeon = name
        if not tab.fdjRPGTip then
            tab.fdjRPGTip = true
            -- Disabled buttons only get OnEnter / OnLeave when asked to.
            if tab.SetMotionScriptsWhileDisabled then tab:SetMotionScriptsWhileDisabled(true) end
            tab:HookScript("OnEnter", function(self)
                if not self.fdjRPGMapLocked then return end
                local have, need = TrashSoFar(self.fdjRPGDungeon)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:SetText(L("RPG_MAP_LOCKED_TITLE"), 1, 0.82, 0)
                GameTooltip:AddLine(L("RPG_MAP_LOCKED_TIP", have, need), 1, 1, 1, true)
                GameTooltip:Show()
            end)
            tab:HookScript("OnLeave", function(self)
                if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            end)
        end
        if locked then
            tab:Disable()
            tab:SetAlpha(0.55)
            if tab.text then tab.text:SetTextColor(0.55, 0.55, 0.55) end
            if tab.fdjIcon and tab.fdjIcon.SetDesaturated then tab.fdjIcon:SetDesaturated(true) end
        elseif tab.fdjIcon and tab.fdjIcon.SetDesaturated then
            tab.fdjIcon:SetDesaturated(false)
        end
    end

    -- Locked pages: their tooltip says a quest opens them too.
    local LockedTooltipPlain = FDJ.RPGLockedTooltip
    FDJ.RPGLockedTooltip = function(owner, name, ...)
        LockedTooltipPlain(owner, name, ...)
        local _, total = 0, 0
        if FDJ.RPGQuestsUnlocked then _, total = FDJ.RPGQuestsUnlocked(name) end
        if (total or 0) > 0 then
            GameTooltip:AddLine(L("RPG_LOCKED_TIP_QUEST"), 1, 1, 1, true)
            GameTooltip:Show()
        end
    end

    -- ------------------------------------------------ refresh after changes
    local pending = false
    local function Changed()
        if FDJ.ResetSearchCache then pcall(FDJ.ResetSearchCache) end
        if pending then return end
        pending = true
        local function run()
            pending = false
            if FDJ.RefreshHomeCards then pcall(FDJ.RefreshHomeCards) end
            if FDJ.RefreshRPGPage then pcall(FDJ.RefreshRPGPage) end
            if FDJ.RefreshWorldMapOverlay and WorldMapFrame and WorldMapFrame:IsShown() then pcall(FDJ.RefreshWorldMapOverlay) end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.2, run) else run() end
    end
    FDJ.RPGStateChanged = Changed

    -- The final boss unlocks the whole page: show it all at once.
    local UnlockWithoutPage = Unlock
    Unlock = function(name, ...)
        UnlockWithoutPage(name, ...)
        Changed()
    end

    -- -------------------------------------------------------------- kills
    local here -- the journal dungeon the character is in (nil outside)
    local function Where()
        here = FDJ.CurrentDungeon and FDJ.CurrentDungeon() or nil
        if here and not InOrder(here) then here = nil end
    end

    local byNpc, byName, indexLang
    local function Index()
        local lang = FDJ.GetLanguage and FDJ.GetLanguage() or ""
        if byNpc and indexLang == lang then return end
        indexLang = lang
        byNpc, byName = {}, {}
        local function Add(map, key, name, b)
            map[key] = map[key] or {}
            table.insert(map[key], { name, b })
        end
        for _, name in ipairs(FDJ.ORDER or {}) do
            local d = FDJ.DB and FDJ.DB[name]
            if d and not d.previewOnly then
                for _, b in ipairs(d.bosses or {}) do
                    if type(b) == "table" and not b.trash and not b.recipeTab then
                        if b.npcID then Add(byNpc, b.npcID, name, b) end
                        if type(b.name) == "string" then
                            Add(byName, b.name:lower(), name, b)
                            -- "Fel Steed / Shadow Charger": either one.
                            for part in b.name:gmatch("[^/]+") do
                                part = part:gsub("^%s+", ""):gsub("%s+$", "")
                                if part ~= "" and part ~= b.name then Add(byName, part:lower(), name, b) end
                            end
                            local shown = FDJ.LocalizeBossName and FDJ.LocalizeBossName(b.name)
                            if type(shown) == "string" and shown ~= "" and shown ~= b.name then Add(byName, shown:lower(), name, b) end
                        end
                    end
                end
            end
        end
    end

    -- The bosses a kill points at: the ones of this dungeon, else (anywhere)
    -- every match.
    local function Pick(list, anywhere)
        if type(list) ~= "table" then return nil end
        local out = {}
        for _, e in ipairs(list) do
            if e[1] == here then out[#out + 1] = e end
        end
        if #out == 0 and anywhere then return list end
        return #out > 0 and out or nil
    end

    local function Reveal(entries)
        local any = false
        Build()
        local all = Store("rpgBosses")
        for _, e in ipairs(entries or {}) do
            local name, b = e[1], e[2]
            if type(all[name]) ~= "table" then all[name] = {} end
            local seen = all[name]
            -- This character's own record; the message only for a boss new to
            -- what the journal shows (account-wide: new to every character).
            local mine = (b.npcID and seen[b.npcID]) or (type(b.name) == "string" and seen[b.name:lower()])
            if not mine then
                local known = Seen(name, b)
                if b.npcID then seen[b.npcID] = true end
                if type(b.name) == "string" then seen[b.name:lower()] = true end
                any = true
                local final = (b.npcID and finalByNpc and finalByNpc[b.npcID] == name) or nameFinal[name] == b -- kroldok
                if FDJ.IsRPGMode() and not known and not final and not ViewTable("rpgKills")[name] and QuestOpen(name) then
                    print("|cffd8a83cDungeon Journal:|r |cff40ff40" .. L("RPG_BOSS_REVEALED_MSG", BossLabel(b.name)) .. "|r")
                end
                if final then Unlock(name) end -- the final boss found: the whole page
            end
        end
        if any then
            ShareProgress()
            Changed()
        end
    end

    local function Trash(guid)
        if not here or Store("rpgMaps")[here] or CharDB().rpgKills[here] then return end -- this character's own
        local all = Store("rpgTrash")
        local rec = all[here]
        if type(rec) ~= "table" then
            rec = { n = 0, seen = {} }
            all[here] = rec
        end
        if type(rec.seen) ~= "table" then rec.seen = {} end
        if rec.seen[guid] then return end
        rec.seen[guid] = true
        rec.n = (rec.n or 0) + 1
        if rec.n < Need(here) then return end
        local name = here
        local open = MapOpen(name) -- account-wide: another character opened it already
        Store("rpgMaps")[name] = true
        all[name] = nil
        ShareProgress()
        if FDJ.IsRPGMode() and not open then
            print("|cffd8a83cDungeon Journal:|r |cff40ff40" .. L("RPG_MAP_UNLOCKED_MSG", DungeonName(name)) .. "|r")
            if FDJ.RPGToast then
                FDJ.RPGToast({ kind = "map", dungeon = name, title = L("RPG_MAP_TOAST_TITLE"),
                    count = math.floor(SHARE * 100 + 0.5) .. "%", quests = {} })
            end
        end
        Changed()
    end

    local function Watching()
        return here and not CharDB().rpgKills[here]
    end

    local function Creature(guid)
        if type(guid) ~= "string" then return nil end
        local kind, _, _, _, _, id = strsplit("-", guid)
        if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
        return tonumber(id) or 0
    end

    -- An enemy lying dead: a boss is revealed, anything else hostile is trash.
    local function Dead(unit)
        if not Watching() then return end
        local okE, exists = pcall(UnitExists, unit)
        if not okE or not Plain(exists) then return end
        local okD, dead = pcall(UnitIsDead, unit)
        if not okD or not Plain(dead) then return end
        local okG, guid = pcall(UnitGUID, unit)
        guid = okG and Plain(guid) or nil
        local id = Creature(guid)
        if not id then return end
        Index()
        local hit = Pick(byNpc[id], true)
        if not hit then
            local okN, who = pcall(UnitName, unit)
            who = okN and Plain(who) or nil
            if type(who) == "string" then hit = Pick(byName[who:lower()], false) end
        end
        if hit then return Reveal(hit) end
        local okR, reaction = pcall(UnitReaction, unit, "player")
        reaction = okR and Plain(reaction) or nil
        if type(reaction) ~= "number" or reaction > 3 then return end -- critters, friends
        Trash(guid)
    end

    -- Corpses looted (area loot can hold several).
    local function Looted()
        if not Watching() or type(GetNumLootItems) ~= "function" or type(GetLootSourceInfo) ~= "function" then return end
        local okN, count = pcall(GetNumLootItems)
        if not okN or type(count) ~= "number" then return end
        Index()
        for slot = 1, count do
            local sources = { pcall(GetLootSourceInfo, slot) }
            if sources[1] then
                for i = 2, #sources, 2 do
                    local guid = Plain(sources[i])
                    local id = Creature(guid)
                    if id then
                        local hit = Pick(byNpc[id], true)
                        if hit then Reveal(hit) else Trash(guid) end
                    end
                end
            end
        end
    end

    local function Encounter(name)
        name = Plain(name)
        if type(name) ~= "string" or name == "" then return end
        Index()
        local hit = Pick(byName[name:lower()], true)
        if hit then Reveal(hit) end
    end

    -- runlogkills (2.0.7): a boss the Dungeon Tracker counts killed counts
    -- here too (revealed; the final boss unlocks the page). The tracker knows
    -- a boss by its encounter ID, the same number in every client language;
    -- RPG Mode only went by names and GUIDs, which Forever hides inside
    -- dungeons. Herod died in the Scarlet Monastery Armory on a Russian
    -- client, the tracker counted him and the run completed, but the page
    -- stayed locked (Matanaliz, Discord, 15 Nov 2026).
    -- quiet: no chat line for a boss (the runs already saved, at login).
    local function RunLogBoss(dungeon, bossName, npcID, quiet)
        if type(dungeon) ~= "string" or not InOrder(dungeon) then return false end
        local d = FDJ.DB and FDJ.DB[dungeon]
        if not d or d.previewOnly then return false end
        Build()
        npcID = tonumber(npcID)
        local lower = type(bossName) == "string" and bossName ~= "" and bossName:lower() or nil
        local found
        for _, b in ipairs(d.bosses or {}) do
            if type(b) == "table" and not b.trash and not b.recipeTab and type(b.name) == "string" then
                if (lower and b.name:lower() == lower) or (npcID and b.npcID == npcID) then found = b break end
            end
        end
        if not found and lower then -- the client's name for it (translation, alias)
            Index()
            for _, e in ipairs(byName[lower] or {}) do
                if e[1] == dungeon then found = e[2] break end
            end
        end
        if not found then return false end
        local changed = false
        if quiet then
            local all = Store("rpgBosses")
            if type(all[dungeon]) ~= "table" then all[dungeon] = {} end
            local seen = all[dungeon]
            if found.npcID and not seen[found.npcID] then seen[found.npcID] = true changed = true end
            if not seen[found.name:lower()] then seen[found.name:lower()] = true changed = true end
        else
            Reveal({ { dungeon, found } })
        end
        local final = (found.npcID and finalByNpc and finalByNpc[found.npcID] == dungeon) or nameFinal[dungeon] == found
        if final and not CharDB().rpgKills[dungeon] then
            Unlock(dungeon)
            changed = true
        end
        return changed
    end
    function FDJ.RPGRunLogBoss(dungeon, bossName, npcID)
        return RunLogBoss(dungeon, bossName, npcID, false)
    end

    -- runlogkills (2.0.7): the boss event's encounter ID, without the tracker.
    local function EncounterID(id)
        id = tonumber(Plain(id))
        local hit = id and FDJ.RUNLOG_ENCOUNTERS and FDJ.RUNLOG_ENCOUNTERS[id]
        if type(hit) ~= "table" then return end
        RunLogBoss(hit[1], hit[2], nil, false)
        for _, extra in ipairs(type(hit.also) == "table" and hit.also or {}) do
            RunLogBoss(hit[1], extra, nil, false) -- Gyth with Rend
        end
    end

    -- runlogkills (2.0.7): the bosses in this character's saved runs (Character
    -- Logs), once per session at login: pages missed before this version open.
    local recoveredRuns = false
    -- (latekill, 2.1.0: force = read them again, past the once a session:
    -- the "I already did this dungeon" check)
    function FDJ.RPGRecoverRunLogKills(force)
        if recoveredRuns and not force then return end
        recoveredRuns = true
        local log = CharDB().runLog
        if type(log) ~= "table" or type(log.runs) ~= "table" then return end
        local any = false
        for _, run in ipairs(log.runs) do
            if type(run) == "table" and not run.test and type(run.dungeon) == "string" and type(run.kills) == "table" then
                for _, k in ipairs(run.kills) do
                    if type(k) == "table" and type(k.b) == "string" then
                        if RunLogBoss(run.dungeon, k.b, k.n, true) then any = true end
                    end
                end
            end
        end
        if any then
            ShareProgress()
            Changed()
        end
    end

    local watch = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
        "UNIT_HEALTH", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "LOOT_OPENED",
        "ENCOUNTER_END", "BOSS_KILL" }) do
        pcall(watch.RegisterEvent, watch, event)
    end
    watch:SetScript("OnEvent", function(_, event, a, b, _, _, e)
        if event == "UNIT_HEALTH" then
            if here and type(a) == "string" and (a:find("^nameplate") or a == "target" or a == "focus" or a:find("^boss")) then
                pcall(Dead, a)
            end
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            if here and type(a) == "string" then pcall(Dead, a) end
        elseif event == "PLAYER_TARGET_CHANGED" then
            if here then pcall(Dead, "target") end
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            if here then pcall(Dead, "mouseover") end
        elseif event == "LOOT_OPENED" then
            if here then pcall(Looted) end
        elseif event == "ENCOUNTER_END" then
            if e == 1 or e == true then pcall(Encounter, b) pcall(EncounterID, a) end -- runlogkills (2.0.7)
        elseif event == "BOSS_KILL" then
            pcall(Encounter, b)
            pcall(EncounterID, a) -- runlogkills (2.0.7)
        else
            if event == "PLAYER_ENTERING_WORLD" then
                pcall(FDJ.RPGRecoverFinalKills)
                pcall(FDJ.RPGRecoverRunLogKills) -- runlogkills (2.0.7)
            end
            pcall(Where)
        end
    end)

    -- A final boss saved as seen (rpgBosses) whose dungeon did not unlock
    -- (an older version missed it: Rath'Mael): unlocked at login / reload.
    function FDJ.RPGRecoverFinalKills()
        Build()
        local db = CharDB()
        if type(db.rpgBosses) ~= "table" then return end
        for name, seen in pairs(db.rpgBosses) do
            if type(seen) == "table" and not db.rpgKills[name] and FDJ.DB and FDJ.DB[name] then
                local hit = false
                for id, dungeon in pairs(finalByNpc or {}) do
                    if dungeon == name and seen[id] then hit = true end
                end
                for lower, dungeon in pairs(finalNames or {}) do
                    if dungeon == name and seen[lower] then hit = true end
                end
                if hit then Unlock(name) end
            end
        end
    end
end
-- END rpgpartial

-- BEGIN rpgproof
-- ------------------------------------------- RPG Mode: quests as proof
-- A quest the character has handed in that can't be done without a boss
-- dying (kill him, bring back his head, an item only he drops) proves that
-- boss was killed, even before the journal was there to see it: the boss is
-- revealed, and his dungeon's final boss unlocks the whole page. A quest
-- started by an item the boss drops counts as soon as it is in the quest
-- log. Checked in RPG Mode: at login, when RPG Mode is turned on, and as
-- such a quest is picked up or handed in.
do
    -- [questID] = { { dungeon, npcID, ... }, ... }
    local PROOF = {
        -- Hall of Thanes
        [96393] = { { "Hall of Thanes", 261319 } },              -- Old Ironforge Incursion: Durgen Dirgehammer's Head
        [96395] = { { "Hall of Thanes", 261306 } },              -- An Ancient Grudge: Faldrim Anvilmar put to rest
        [96394] = { { "Hall of Thanes", 261306 } },              -- The Restless Dead: Faldrim Anvilmar put to rest
        -- Ragefire Chasm
        [5728] = { { "Ragefire Chasm", 11519, 11518 } },         -- Hidden Enemies: Bazzalan, Jergosh the Invoker
        [5761] = { { "Ragefire Chasm", 11520 } },                -- Slaying the Beast: Taragaman the Hungerer
        -- Ruins of Lordaeron
        [92422] = { { "Ruins of Lordaeron", 250657 } },          -- The Wrath of Rath'mael
        [95250] = { { "Ruins of Lordaeron", 250660 } },          -- Abominable Creatures: the Head of the Baron
        [97288] = { { "Ruins of Lordaeron", 250660 } },          -- Unending Torment: the Abominable Head, from the Baron
        [95216] = { { "Ruins of Lordaeron", 250483 } },          -- The New Plague: Witherfang's strain
        -- The Deadmines
        [166] = { { "The Deadmines", 639 } },                    -- The Defias Brotherhood: Edwin VanCleef's head
        [373] = { { "The Deadmines", 639 } },                    -- The Unsent Letter, looted from Edwin VanCleef
        [2040] = { { "The Deadmines", 642 } },                   -- Underground Assault: from Sneed's Shredder
        -- Wailing Caverns
        [6981] = { { "Wailing Caverns", 3654 } },                -- The Glowing Shard, from Mutanus the Devourer
        [914] = { { "Wailing Caverns", 3669, 3671, 3670, 3673 } }, -- Leaders of the Fang: the four gems
        -- Shadowfang Keep
        [1014] = { { "Shadowfang Keep", 4275 } },                -- Arugal Must Die
        [95036] = { { "Shadowfang Keep", 4275 } },               -- A Moon-Kissed Blade: the ingot in Arugal's room after he dies
        -- Blackfathom Deeps
        [1200] = { { "Blackfathom Deeps", 4832 } },              -- Blackfathom Villainy: the Head of Kelris
        [6561] = { { "Blackfathom Deeps", 4832 } },
        [6565] = { { "Blackfathom Deeps", 12902 } },             -- Allegiance to the Old Gods: Lorgus Jett
        -- Excavation Site: Wetlands (the Titan Relic, from the Relic Guardian)
        [95810] = { { "Excavation Site: Wetlands", 260326 } },
        [95664] = { { "Excavation Site: Wetlands", 260326 } },
        [98824] = { { "Excavation Site: Wetlands", 260326 } },
        [98823] = { { "Excavation Site: Wetlands", 260326 } },
        -- The Stockade
        [391] = { { "The Stockade", 1716 } },                    -- The Stockade Riots: Bazil Thredd
        [377] = { { "The Stockade", 1663 } },                    -- Crime and Punishment: Dextren Ward
        [378] = { { "The Stockade", 1666 } },                    -- The Fury Runs Deep: Kam Deepfury
        [386] = { { "The Stockade", 1696 } },                    -- What Comes Around...: Targorr the Dread
        -- City of Dalaran
        [92489] = { { "City of Dalaran", 246016 } },             -- Power Overwhelming: Arcanic Enigma
        [96986] = { { "City of Dalaran", 247126 } },             -- The Grave Knight: Atrexis
        -- Gnomeregan
        [2929] = { { "Gnomeregan", 7800 } },                     -- The Grand Betrayal: Mekgineer Thermaplugg
        [2841] = { { "Gnomeregan", 7800 } },                     -- Rig Wars: Thermaplugg's Safe Combination
        -- Razorfen Kraul (Charlga Razorflank)
        [6522] = { { "Razorfen Kraul", 4421 } },                 -- the Small Scroll
        [1101] = { { "Razorfen Kraul", 4421 } },                 -- The Crone of the Kraul: Razorflank's Medallion
        [1102] = { { "Razorfen Kraul", 4421 } },                 -- A Vengeful Fate: Razorflank's Heart
        -- The Drowned City
        [95776] = { { "The Drowned City", 258924 } },            -- The Only Good Brinescale...: Var'Taka
        [95791] = { { "The Drowned City", 260042 } },            -- The Saltseer Captain: Captain Dreadrise
        -- Krol'dok Stronghold
        [94968] = { { "Krol'dok Stronghold", 258968 } },        -- Eye of Mugg (Horde): Overlord Mugg
        [94982] = { { "Krol'dok Stronghold", 258968 } },        -- Eye of Mugg (Alliance): Overlord Mugg
        [94984] = { { "Krol'dok Stronghold", 258964 } },        -- Tome of Twilight (Alliance): Nar'gurk
        -- Scarlet Monastery: Whitemane, Mograine, Herod and Loksey
        [1048] = { { "Scarlet Monastery: Cathedral", 3977, 3976 }, { "Scarlet Monastery: Armory", 3975 },
            { "Scarlet Monastery: Library", 3974 } },
        [1053] = { { "Scarlet Monastery: Cathedral", 3977, 3976 }, { "Scarlet Monastery: Armory", 3975 },
            { "Scarlet Monastery: Library", 3974 } },
        -- Razorfen Downs
        [3341] = { { "Razorfen Downs", 7358 } },
        [3636] = { { "Razorfen Downs", 7358 } },
        -- Uldaman (the power source from Archaedas, the sapphire from Grimlok)
        [2204] = { { "Uldaman", 2748 } },
        [2339] = { { "Uldaman", 2748, 4854 } },
        [2201] = { { "Uldaman", 4854 } },
        -- Zul'Farrak
        [2770] = { { "Zul'Farrak", 7273 } },
        -- Maraudon
        [7064] = { { "Maraudon", 12201 } },
        [7065] = { { "Maraudon", 12201 } },
        -- Sunken Temple
        [3373] = { { "Sunken Temple", 5709 } },
        [8232] = { { "Sunken Temple", 5719 } },
        [8253] = { { "Sunken Temple", 5719 } },
        [8257] = { { "Sunken Temple", 5719 } },
        -- Blackrock Depths
        [4024] = { { "Blackrock Depths", 9016 } },
        [4003] = { { "Blackrock Depths", 9019 } },
        [4362] = { { "Blackrock Depths", 9019 } },
        [3802] = { { "Blackrock Depths", 9056 } },
        [4132] = { { "Blackrock Depths", 9033 } },
        [4282] = { { "Blackrock Depths", 8983, 9033 } },
        [4063] = { { "Blackrock Depths", 8983 } },
        [3907] = { { "Blackrock Depths", 9017 } },
        [4263] = { { "Blackrock Depths", 9017 } },
        -- Lower Blackrock Spire
        [4701] = { { "Lower Blackrock Spire", 10220 } },
        [4724] = { { "Lower Blackrock Spire", 10220 } },
        [4742] = { { "Lower Blackrock Spire", 9196, 9237, 9568 } },
        [4903] = { { "Lower Blackrock Spire", 9196, 9237, 9568 } },
        [5081] = { { "Lower Blackrock Spire", 9196, 9237, 9568 } },
        [5089] = { { "Lower Blackrock Spire", 9568 } },
        -- Upper Blackrock Spire
        [5102] = { { "Upper Blackrock Spire", 10363 } },
        [6502] = { { "Upper Blackrock Spire", 10363 } },
        [6602] = { { "Upper Blackrock Spire", 10363 } },
        [5127] = { { "Upper Blackrock Spire", 10899 } },
        [4974] = { { "Upper Blackrock Spire", 10429 } },
        -- Dire Maul
        [5526] = { { "Dire Maul: East", 11492 } },
        [7463] = { { "Dire Maul: East", 13280 } },
        [7488] = { { "Dire Maul: East", 14327 } },
        [7489] = { { "Dire Maul: East", 14327 } },
        [7461] = { { "Dire Maul: West", 11496, 11486 } },
        -- Stratholme
        [5251] = { { "Stratholme: Living", 10811 } },
        [5262] = { { "Stratholme: Living", 10813 } },
        [5263] = { { "Stratholme: Undead", 10440 } },
        [5125] = { { "Stratholme: Undead", 10440 } },
        [8945] = { { "Stratholme: Undead", 10440 } },
        [6163] = { { "Stratholme: Undead", 10439 } },
        -- Scholomance
        [5382] = { { "Scholomance", 11261 } },
        [5515] = { { "Scholomance", 10503 } },
        [5466] = { { "Scholomance", 10508 } },
        [4771] = { { "Scholomance", 10432 } },
    }
    -- Started by the boss's own drop: in the quest log is proof enough.
    local DROP = {
        [373] = true, [6981] = true, [6522] = true, [97288] = true, [95810] = true,
        [95664] = true, [3373] = true, [5089] = true, [5262] = true,
    }
    FDJ.RPG_QUEST_PROOF, FDJ.RPG_QUEST_PROOF_DROP = PROOF, DROP

    local strings = {
        enUS = { RPG_PROOF_UNLOCKED = "Unlocked by quests you have done: %s", RPG_PROOF_REVEALED = "Revealed by quests you have done: %s" },
        deDE = { RPG_PROOF_UNLOCKED = "Durch erledigte Quests freigeschaltet: %s", RPG_PROOF_REVEALED = "Durch erledigte Quests aufgedeckt: %s" },
        frFR = { RPG_PROOF_UNLOCKED = "Débloqué grâce à vos quêtes terminées : %s", RPG_PROOF_REVEALED = "Révélé grâce à vos quêtes terminées : %s" },
        esES = { RPG_PROOF_UNLOCKED = "Desbloqueado por misiones que ya completaste: %s", RPG_PROOF_REVEALED = "Revelado por misiones que ya completaste: %s" },
        itIT = { RPG_PROOF_UNLOCKED = "Sbloccato dalle missioni già completate: %s", RPG_PROOF_REVEALED = "Svelato dalle missioni già completate: %s" },
        ptBR = { RPG_PROOF_UNLOCKED = "Desbloqueado por missões que você já concluiu: %s", RPG_PROOF_REVEALED = "Revelado por missões que você já concluiu: %s" },
        ruRU = { RPG_PROOF_UNLOCKED = "Открыто по выполненным заданиям: %s", RPG_PROOF_REVEALED = "Раскрыто по выполненным заданиям: %s" },
        koKR = { RPG_PROOF_UNLOCKED = "완료한 퀘스트로 열림: %s", RPG_PROOF_REVEALED = "완료한 퀘스트로 공개됨: %s" },
        zhCN = { RPG_PROOF_UNLOCKED = "已通过完成的任务解锁：%s", RPG_PROOF_REVEALED = "已通过完成的任务揭示：%s" },
        zhTW = { RPG_PROOF_UNLOCKED = "已透過完成的任務解鎖：%s", RPG_PROOF_REVEALED = "已透過完成的任務揭示：%s" },
    }
    for locale, entries in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for key, value in pairs(entries) do
                if t[key] == nil then t[key] = value end
            end
        end
    end

    local function Shown(id)
        if FDJ.QuestTurnedIn and FDJ.QuestTurnedIn(id) then return true end
        return DROP[id] and FDJ.IsQuestInLog and FDJ.IsQuestInLog(id) and true or false
    end

    local function BossOf(name, npcID)
        local d = FDJ.DB and FDJ.DB[name]
        for _, b in ipairs((d and d.bosses) or {}) do
            if type(b) == "table" and b.npcID == npcID then return b end
        end
    end

    local function Localized(fn, name)
        local shown = fn and fn(name)
        return type(shown) == "string" and shown ~= "" and shown or name
    end

    -- Marks what these quests prove. Returns the pages it unlocked and the
    -- bosses it revealed (on pages still not fully open), both new.
    local function Prove(ids, live)
        Build()
        local db = CharDB()
        if type(db.rpgBosses) ~= "table" then db.rpgBosses = {} end
        local pages, bosses, any = {}, {}, false
        for _, id in ipairs(ids) do
            for _, entry in ipairs(PROOF[id] or {}) do
                local name = entry[1]
                if InOrder(name) then
                    for i = 2, #entry do
                        local b = BossOf(name, entry[i])
                        if b then
                            local seen = db.rpgBosses[name]
                            if type(seen) ~= "table" then
                                seen = {}
                                db.rpgBosses[name] = seen
                            end
                            -- Written to this character's record; listed in chat only
                            -- when new to what the journal shows (account-wide too).
                            if not seen[b.npcID] then
                                local shown = ViewTable("rpgBosses")[name]
                                local known = type(shown) == "table" and shown[b.npcID] and true or false
                                seen[b.npcID] = true
                                if type(b.name) == "string" then seen[b.name:lower()] = true end
                                if not known then bosses[#bosses + 1] = { name, b } end
                                any = true
                            end
                            if finalByNpc and finalByNpc[b.npcID] == name and not db.rpgKills[name] then
                                local known = ViewTable("rpgKills")[name] and true or false
                                if live then
                                    Unlock(name) -- the page's popup, as for a kill seen
                                else
                                    db.rpgKills[name] = true
                                end
                                if not known then pages[#pages + 1] = name end
                                any = true
                            end
                        end
                    end
                end
            end
        end
        if any then ShareProgress() end
        local revealed = {}
        for _, e in ipairs(bosses) do
            if not ViewTable("rpgKills")[e[1]] then revealed[#revealed + 1] = e[2] end
        end
        return pages, revealed, any
    end

    local function Say(key, list)
        if #list == 0 then return end
        print("|cffd8a83cDungeon Journal:|r |cff40ff40" .. L(key, table.concat(list, ", ")) .. "|r")
    end

    local function Refresh()
        if FDJ.RPGStateChanged then pcall(FDJ.RPGStateChanged) end
        if FDJ.RefreshHomeCards then pcall(FDJ.RefreshHomeCards) end
    end

    -- Every quest that proves something: login, RPG Mode turned on.
    local function Check()
        if not FDJ.IsRPGMode() then return end
        local ids = {}
        for id in pairs(PROOF) do
            if Shown(id) then ids[#ids + 1] = id end
        end
        table.sort(ids)
        local pages, revealed, any = Prove(ids, false)
        if not any then return end
        local names = {}
        for _, name in ipairs(pages) do names[#names + 1] = Localized(FDJ.LocalizeDungeonName, name) end
        Say("RPG_PROOF_UNLOCKED", names)
        local list = {}
        for _, b in ipairs(revealed) do list[#list + 1] = Localized(FDJ.LocalizeBossName, b.name) end
        Say("RPG_PROOF_REVEALED", list)
        Refresh()
    end
    FDJ.RPGCheckQuestProof = Check

    -- One quest just picked up or handed in: as if the kill had been seen.
    local function Now(id)
        if not FDJ.IsRPGMode() or not PROOF[id] then return end
        local _, revealed, any = Prove({ id }, true)
        if not any then return end
        for _, b in ipairs(revealed) do
            print("|cffd8a83cDungeon Journal:|r |cff40ff40" .. L("RPG_BOSS_REVEALED_MSG", Localized(FDJ.LocalizeBossName, b.name)) .. "|r")
        end
        Refresh()
    end

    local function Later(seconds, fn)
        if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) else fn() end
    end

    local proofEvents = CreateFrame("Frame")
    proofEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    proofEvents:RegisterEvent("QUEST_TURNED_IN")
    proofEvents:RegisterEvent("QUEST_ACCEPTED")
    local checked = false
    proofEvents:SetScript("OnEvent", function(_, event, a, b)
        if event == "PLAYER_ENTERING_WORLD" then
            if checked then return end
            checked = true
            -- The game knows the quests done a moment after login (and once
            -- more a little later, in case it took its time).
            Later(5, Check)
            Later(30, Check)
        elseif event == "QUEST_TURNED_IN" then
            local id = tonumber(Plain(a))
            if id and PROOF[id] then Now(id) end
        else
            -- WoW Forever: (questID); Classic clients: (questLogIndex, questID).
            local id = tonumber(Plain(b)) or tonumber(Plain(a))
            if id and DROP[id] then Now(id) end
        end
    end)

    -- RPG Mode turned on: what the quests done already prove, at once.
    local SetJournalModeWithoutProof = FDJ.SetJournalMode
    FDJ.SetJournalMode = function(mode, ...)
        local was = FDJ.IsRPGMode()
        local a, b, c = SetJournalModeWithoutProof(mode, ...)
        if mode == "rpg" and not was then Later(0.5, Check) end
        return a, b, c
    end
end
-- END rpgproof

-- BEGIN rpgdone
-- ------------------------------------- RPG Mode: "I already did this dungeon"
-- rpgdone (2.0.8): for players who installed the journal late. A kill from
-- before then is only known when a handed-in quest proves it (rpgproof) or
-- the Character Logs saw it; the game keeps no other record. Those are
-- checked first, every time: a page they prove opens for real (its popup)
-- and the box never shows. Clicking a
-- locked page opens a small box (the usual locked text) with "I already did
-- this dungeon"; that shows the dungeon's name and asks to confirm, then the
-- whole page opens as when its final boss dies (chat line, no popup). A page
-- half opened by its quests has the same button under a hidden boss ("???").
-- Kept per character (rpgKills, plus rpgManual: the pages marked by hand),
-- shared as every unlock is with Account-Wide Unlocks on. Asked by Akaria
-- (Discord, 15 Nov 2026: Horde Deadmines has no quest to prove it).
do
    local strings = {
        enUS = { RPG_DONE_BUTTON = "I already did this dungeon before installing", RPG_DONE_TIP = "Already did it before installing the journal? Click the page.",
            RPG_DONE_CONFIRM = "This page is %s.\n\nMark it as done? The whole page opens, as if you had killed its final boss. Only for dungeons you did before installing the journal.",
            RPG_DONE_OK = "Mark as done", RPG_DONE_BACK = "Back", RPG_DONE_CLOSE = "Close" },
        deDE = { RPG_DONE_BUTTON = "Diesen Dungeon schon vor der Installation gemacht", RPG_DONE_TIP = "Schon vor dem Journal erledigt? Klick auf die Seite.",
            RPG_DONE_CONFIRM = "Diese Seite ist %s.\n\nAls erledigt markieren? Die ganze Seite wird freigeschaltet, als hättest du den Endboss besiegt. Nur für Dungeons, die du vor dem Journal gemacht hast.",
            RPG_DONE_OK = "Als erledigt markieren", RPG_DONE_BACK = "Zurück", RPG_DONE_CLOSE = "Schließen" },
        frFR = { RPG_DONE_BUTTON = "J'ai déjà fait ce donjon avant l'installation", RPG_DONE_TIP = "Déjà fait avant d'installer le journal ? Cliquez sur la page.",
            RPG_DONE_CONFIRM = "Cette page est %s.\n\nLa marquer comme faite ? Toute la page se débloque, comme si vous aviez tué son boss final. Uniquement pour les donjons faits avant d'installer le journal.",
            RPG_DONE_OK = "Marquer comme fait", RPG_DONE_BACK = "Retour", RPG_DONE_CLOSE = "Fermer" },
        esES = { RPG_DONE_BUTTON = "Ya hice esta mazmorra antes de la instalación", RPG_DONE_TIP = "¿Ya la hiciste antes de instalar el diario? Haz clic en la página.",
            RPG_DONE_CONFIRM = "Esta página es %s.\n\n¿Marcarla como hecha? Se desbloquea toda la página, como si hubieras matado a su jefe final. Solo para mazmorras que hiciste antes de instalar el diario.",
            RPG_DONE_OK = "Marcar como hecha", RPG_DONE_BACK = "Volver", RPG_DONE_CLOSE = "Cerrar" },
        itIT = { RPG_DONE_BUTTON = "Ho già fatto questa spedizione prima dell'installazione", RPG_DONE_TIP = "Già fatta prima di installare il diario? Clicca sulla pagina.",
            RPG_DONE_CONFIRM = "Questa pagina è %s.\n\nSegnarla come fatta? Si sblocca tutta la pagina, come se avessi ucciso il boss finale. Solo per le spedizioni fatte prima di installare il diario.",
            RPG_DONE_OK = "Segna come fatta", RPG_DONE_BACK = "Indietro", RPG_DONE_CLOSE = "Chiudi" },
        ptBR = { RPG_DONE_BUTTON = "Já fiz esta masmorra antes da instalação", RPG_DONE_TIP = "Já fez antes de instalar o diário? Clique na página.",
            RPG_DONE_CONFIRM = "Esta página é %s.\n\nMarcar como feita? A página inteira é desbloqueada, como se você tivesse matado o chefe final. Só para masmorras que você fez antes de instalar o diário.",
            RPG_DONE_OK = "Marcar como feita", RPG_DONE_BACK = "Voltar", RPG_DONE_CLOSE = "Fechar" },
        ruRU = { RPG_DONE_BUTTON = "Я прошёл это подземелье до установки", RPG_DONE_TIP = "Уже прошли до установки журнала? Нажмите на страницу.",
            RPG_DONE_CONFIRM = "Это страница: %s.\n\nОтметить как пройденное? Откроется вся страница, как после убийства финального босса. Только для подземелий, пройденных до установки журнала.",
            RPG_DONE_OK = "Отметить", RPG_DONE_BACK = "Назад", RPG_DONE_CLOSE = "Закрыть" },
        koKR = { RPG_DONE_BUTTON = "설치 전에 이미 이 던전을 마쳤습니다", RPG_DONE_TIP = "일지를 설치하기 전에 이미 마쳤나요? 페이지를 클릭하세요.",
            RPG_DONE_CONFIRM = "이 페이지는 %s입니다.\n\n완료로 표시할까요? 최종 우두머리를 처치한 것처럼 페이지 전체가 열립니다. 일지를 설치하기 전에 마친 던전에만 사용하세요.",
            RPG_DONE_OK = "완료로 표시", RPG_DONE_BACK = "뒤로", RPG_DONE_CLOSE = "닫기" },
        zhCN = { RPG_DONE_BUTTON = "安装前我已完成过这个地下城", RPG_DONE_TIP = "安装日志前就已完成？点击此页面。",
            RPG_DONE_CONFIRM = "这一页是%s。\n\n标记为已完成？整页将会解锁，如同击杀了最终首领。仅用于安装日志之前完成的地下城。",
            RPG_DONE_OK = "标记为已完成", RPG_DONE_BACK = "返回", RPG_DONE_CLOSE = "关闭" },
        zhTW = { RPG_DONE_BUTTON = "安裝前我已完成過這個地城", RPG_DONE_TIP = "安裝日誌前就已完成？點擊此頁面。",
            RPG_DONE_CONFIRM = "這一頁是%s。\n\n標記為已完成？整頁將會解鎖，如同擊殺了最終首領。僅用於安裝日誌之前完成的地城。",
            RPG_DONE_OK = "標記為已完成", RPG_DONE_BACK = "返回", RPG_DONE_CLOSE = "關閉" },
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

    local function DungeonName(name)
        return FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(name) or name
    end

    -- The page marked done by hand: opened as by its final boss.
    function FDJ.RPGMarkDone(name)
        if type(name) ~= "string" or not InOrder(name) then return false end
        local d = FDJ.DB and FDJ.DB[name]
        if not d or d.previewOnly then return false end
        local db = CharDB()
        if db.rpgKills[name] then return false end
        if FDJ.RPGCheckQuestProof then pcall(FDJ.RPGCheckQuestProof) end -- quests first
        if db.rpgKills[name] then return false end
        if type(db.rpgManual) ~= "table" then db.rpgManual = {} end
        db.rpgManual[name] = true
        local open = ViewTable("rpgKills")[name] and true or false
        db.rpgKills[name] = true
        ShareProgress()
        if not open then
            print("|cffd8a83cDungeon Journal:|r |cff40ff40" .. L("RPG_UNLOCKED_MSG", DungeonName(name)) .. "|r")
        end
        if FDJ.RPGStateChanged then pcall(FDJ.RPGStateChanged) end
        if FDJ.RefreshHomeCards then pcall(FDJ.RefreshHomeCards) end
        return true
    end

    -- The box: step 1 the locked text (a locked card), step 2 the dungeon's
    -- name and the confirm. From a half-open page it starts at step 2.
    local box
    local function Build()
        box = CreateFrame("Frame", "ForeverDungeonJournalRPGDone", UIParent, "BackdropTemplate")
        box:SetSize(400, 170)
        box:SetFrameStrata("FULLSCREEN_DIALOG")
        box:SetToplevel(true)
        box:EnableMouse(true)
        box:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            edgeSize = 26,
            insets = { left = 7, right = 7, top = 7, bottom = 7 },
        })
        box:SetBackdropColor(0.04, 0.035, 0.03, 0.98)
        box.title = box:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
        box.title:SetPoint("TOP", 0, -22)
        box.title:SetWidth(352)
        box.text = box:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
        box.text:SetPoint("TOP", box.title, "BOTTOM", 0, -8)
        box.text:SetWidth(352)
        box.text:SetJustifyH("CENTER")
        box.text:SetJustifyV("TOP")
        if box.text.SetWordWrap then box.text:SetWordWrap(true) end
        if box.text.SetNonSpaceWrap then box.text:SetNonSpaceWrap(true) end
        if box.text.SetMaxLines then box.text:SetMaxLines(0) end
        box.ok = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
        if FDJ.OwnFonts then FDJ.OwnFonts(box.ok) end
        box.ok:SetHeight(24)
        box.back = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
        if FDJ.OwnFonts then FDJ.OwnFonts(box.back) end
        box.back:SetHeight(24)
        if UISpecialFrames then tinsert(UISpecialFrames, "ForeverDungeonJournalRPGDone") end -- Escape closes it
    end

    local function FitButton(b, text)
        b:SetText(text)
        local fs = b:GetFontString()
        b:SetWidth(math.max(130, math.min(560, math.ceil((fs and fs:GetStringWidth() or 0) + 36))))
    end

    -- The two buttons as one centred row, inside the border: the box is as
    -- wide as the row needs (a long "I already did..." in any language).
    local GAP, SIDE = 12, 34
    local function Layout(title, text)
        local okW, backW = box.ok:GetWidth() or 130, box.back:GetWidth() or 130
        local single = not box.ok:IsShown() -- rpglegacy: Close alone
        local row = single and backW or (okW + GAP + backW)
        local width = math.max(400, math.ceil(row + 2 * SIDE))
        box:SetWidth(width)
        box.ok:ClearAllPoints()
        box.ok:SetPoint("BOTTOMLEFT", box, "BOTTOM", -row / 2, 18)
        box.back:ClearAllPoints()
        if single then
            box.back:SetPoint("BOTTOM", box, "BOTTOM", 0, 18)
        else
            box.back:SetPoint("LEFT", box.ok, "RIGHT", GAP, 0)
        end
        box.title:SetWidth(width - 2 * SIDE)
        box.text:SetWidth(width - 2 * SIDE)
        box.title:SetText(title or "")
        box.text:SetText(text or "")
        -- Tight: 22 top, title, 8, text, 16, the buttons (24), 18 bottom.
        box.text:SetHeight(0)
        local textHeight = math.max(box.text:GetStringHeight() or 0, 12)
        box.text:SetHeight(textHeight)
        local titleHeight = math.max(box.title:GetStringHeight() or 0, 16)
        box:SetHeight(math.ceil(22 + titleHeight + 8 + textHeight + 16 + 24 + 18))
    end

    local Confirm
    local function Locked(name)
        local text = L("RPG_LOCKED_TIP2")
        local _, total = 0, 0
        if FDJ.RPGQuestsUnlocked then _, total = FDJ.RPGQuestsUnlocked(name) end
        if (total or 0) > 0 then text = text .. "\n" .. L("RPG_LOCKED_TIP_QUEST") end
        -- rpglegacy: a dungeon the account's Legacy Challenges list opens by
        -- itself once done there, so no "I already did" for it (only Ragefire
        -- Chasm, Hall of Thanes and The Stockade keep it, or every dungeon
        -- with Account-Wide Unlocks off).
        local legacy = FDJ.RPGLegacyCovers and FDJ.RPGLegacyCovers(name)
        if legacy then text = text .. "\n\n" .. L("RPG_LEGACY_WAIT") end
        box.ok:SetShown(not legacy)
        FitButton(box.ok, L("RPG_DONE_BUTTON"))
        FitButton(box.back, L("RPG_DONE_CLOSE"))
        box.ok:SetScript("OnClick", function() Confirm(name, true) end)
        box.back:SetScript("OnClick", function() box:Hide() end)
        Layout(L("RPG_LOCKED_TIP_TITLE"), text)
    end
    Confirm = function(name, fromLocked)
        box.ok:Show()
        FitButton(box.ok, L("RPG_DONE_OK"))
        FitButton(box.back, L("RPG_DONE_BACK"))
        box.ok:SetScript("OnClick", function()
            box:Hide()
            if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
                pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end
            FDJ.RPGMarkDone(name)
        end)
        box.back:SetScript("OnClick", function()
            if fromLocked then Locked(name) else box:Hide() end
        end)
        Layout(L("RPG_LOCKED_TIP_TITLE"), L("RPG_DONE_CONFIRM", "|cffffd100" .. DungeonName(name) .. "|r"))
    end

    -- fromPage: the half-open page's button (the name is on screen already).
    -- Quests first: a handed-in quest that proves the final boss (the
    -- Unsent Letter: VanCleef) opens the page for real, before any box.
    local function Proven(name)
        if FDJ.RPGCheckQuestProof then pcall(FDJ.RPGCheckQuestProof) end
        if FDJ.RPGRecoverRunLogKills then pcall(FDJ.RPGRecoverRunLogKills, true) end -- (latekill)
        return CharDB().rpgKills[name] == true
    end

    function FDJ.ShowRPGDoneBox(name, fromPage)
        if type(name) ~= "string" or not InOrder(name) then return end
        if CharDB().rpgKills[name] or Proven(name) then
            if box then box:Hide() end
            return
        end
        if not box then Build() end
        if fromPage then Confirm(name, false) else Locked(name) end
        local journal = _G.ForeverDungeonJournalFrame
        box:ClearAllPoints()
        box:SetPoint("CENTER", (journal and journal:IsShown()) and journal or UIParent, "CENTER", 0, 0)
        if journal and journal.GetFrameLevel then box:SetFrameLevel(journal:GetFrameLevel() + 30) end
        box:Show()
    end

    -- The locked card's tooltip says it can be clicked.
    local LockedTooltipBefore = FDJ.RPGLockedTooltip
    FDJ.RPGLockedTooltip = function(owner, name, ...)
        LockedTooltipBefore(owner, name, ...)
        if FDJ.RPGLegacyCovers and FDJ.RPGLegacyCovers(name) then -- rpglegacy
            GameTooltip:AddLine(L("RPG_LEGACY_WAIT"), 0.62, 0.60, 0.55, true)
        else
            GameTooltip:AddLine(L("RPG_DONE_TIP"), 0.62, 0.60, 0.55, true)
        end
        GameTooltip:Show()
    end

    -- The button under a hidden boss ("???") of a half-open page.
    -- Core/Journal.lua calls it on every boss page (nil: hidden).
    function FDJ.RPGDoneButton(journal, name)
        local b = journal and journal.fdjRPGDoneButton
        if not name or CharDB().rpgKills[name] or not (journal and journal.selectedBossDescription)
            or (FDJ.RPGLegacyCovers and FDJ.RPGLegacyCovers(name)) then -- rpglegacy
            if b then b:Hide() end
            return
        end
        local desc = journal.selectedBossDescription
        local panel = desc:GetParent()
        if not b then
            b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            if FDJ.OwnFonts then FDJ.OwnFonts(b) end
            b:SetHeight(22)
            journal.fdjRPGDoneButton = b
        end
        FitButton(b, L("RPG_DONE_BUTTON"))
        -- Under the hint; a long label (German, Italian) moves left so it
        -- stays inside the panel's right edge.
        local shift = 0
        local okD, dl = pcall(desc.GetLeft, desc)
        local okL, pl = pcall(panel.GetLeft, panel)
        local okR, pr = pcall(panel.GetRight, panel)
        if okD and okL and okR and type(dl) == "number" and type(pl) == "number" and type(pr) == "number" then
            local room = pr - dl - 14
            local w = b:GetWidth() or 0
            if w > room then shift = math.max(pl + 14 - dl, room - w) end
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", shift, -10)
        b:SetScript("OnClick", function() FDJ.ShowRPGDoneBox(name, true) end)
        b:Show()
    end
end
-- END rpgdone

-- BEGIN rpgtorn
-- ----------------------------- RPG Mode: the locked page torn open by bosses
-- rpgtorn (2.0.8, a test on Ragefire Chasm only, M 15 Nov 2026): a locked
-- page's parchment tears away diagonally as the dungeon's bosses die, and
-- the dungeon's picture shows through, as much of the card as bosses are
-- killed (1 of 4: a quarter, 2 of 4: half...). The final boss opens the
-- whole page as before. The tear: Media\RPG\TornMask (the picture left of a
-- ragged diagonal line) and TornEdge (the paper's pale torn fibres and its
-- shadow on the picture), one pair slid across the card. /dj torn shows the
-- steps: /dj torn 0-4 previews the card (any mode), /dj torn off goes back.
-- tornall (2.0.8, M 15 Nov 2026): every dungeon now, not Ragefire Chasm
-- alone. Each card tears by its own count (3 of 4 bosses: three quarters,
-- 3 of 8: under half); a group of bosses ("Altar Bosses") counts once, as
-- soon as one of them is seen, as on the boss list. /dj torn <n> previews
-- every card, /dj torn <dungeon> <n> one of them (the run log's
-- abbreviations, e.g. wc, or the name), /dj torn off goes back.
do
    local TEX_W, SLANT_TEX = 1024, 91 -- the textures' width, and how far the tear leans (texels)
    local previews = {}  -- one dungeon's preview: bosses dead
    local previewAll     -- /dj torn <n>: every dungeon

    -- The bosses that count: not trash, recipes, rares or folded rows.
    local function Bosses(name)
        local list = {}
        local d = FDJ.DB and FDJ.DB[name]
        for _, b in ipairs((d and d.bosses) or {}) do
            if type(b) == "table" and type(b.name) == "string" and not b.trash and not b.recipeTab
                and not b.rare and not b.listHidden and not b.childOf then
                list[#list + 1] = b
            end
        end
        return list
    end
    local function Killed(name, list)
        local seen = ViewTable("rpgBosses")[name]
        if type(seen) ~= "table" then return 0 end
        local n = 0
        for _, b in ipairs(list) do
            local dead
            if FDJ.RPGBossSeen then
                dead = FDJ.RPGBossSeen(name, b) -- tornall: groups too
            else
                dead = (b.npcID and seen[b.npcID]) or seen[b.name:lower()]
            end
            if dead then n = n + 1 end
        end
        return n
    end
    FDJ.RPGTornProgress = function(name)
        local list = Bosses(name)
        return Killed(name, list), #list
    end

    -- Where the tear's middle goes so that f of the card shows (the tear
    -- leans: s yards right at the top, s left at the bottom).
    local function Solve(w, h, s, f)
        local lo, hi = -s, w + s
        for _ = 1, 40 do
            local c = (lo + hi) / 2
            local total = 0
            for i = 1, 32 do
                local y = (i - 0.5) / 32
                total = total + math.max(0, math.min(w, c + s * (1 - 2 * y)))
            end
            if total / 32 / w < f then lo = c else hi = c end
        end
        return (lo + hi) / 2
    end

    local function Parts(page)
        if page.torn then return page.torn end
        if not page.CreateMaskTexture then return nil end
        local t = {}
        page.sketch:SetDrawLayer("ARTWORK", -2)
        t.art = page:CreateTexture(nil, "ARTWORK", nil, -1)
        t.art:SetAllPoints(page)
        t.mask = page:CreateMaskTexture()
        t.mask:SetTexture(MEDIA .. "TornMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        t.art:AddMaskTexture(t.mask)
        t.edge = page:CreateTexture(nil, "ARTWORK", nil, 0)
        t.edge:SetTexture(MEDIA .. "TornEdge")
        t.edge:SetAllPoints(page)
        page.torn = t
        page:HookScript("OnSizeChanged", function(self)
            if self.torn and self.torn.f then pcall(self.fdjTornLayout, self) end
        end)
        return t
    end

    local function Layout(page)
        local t = page.torn
        local f = t and t.f or 0
        local w, h = page:GetWidth() or 0, page:GetHeight() or 0
        if not t or f <= 0 or w < 10 or h < 10 then
            if t then t.art:Hide() t.edge:Hide() end
            return
        end
        local s = SLANT_TEX / TEX_W * 2 * w
        local off = Solve(w, h, s, math.min(f, 1)) - w
        t.mask:ClearAllPoints()
        t.mask:SetPoint("TOPLEFT", page, "TOPLEFT", off, 0)
        t.mask:SetSize(2 * w, h)
        t.edge:SetTexCoord(-off / (2 * w), (w - off) / (2 * w), 0, 1)
        t.art:Show()
        t.edge:Show()
    end

    local function Show(card, page, f)
        local t = Parts(page)
        if not t then return end
        page.fdjTornLayout = Layout
        if f > 0 and card.art then
            local okT, tex = pcall(card.art.GetTexture, card.art)
            if okT and tex then t.art:SetTexture(tex) end
            local ok, ulx, uly, _, lly, urx = pcall(card.art.GetTexCoord, card.art)
            if ok and ulx then t.art:SetTexCoord(ulx, urx, uly, lly) end
        end
        t.f = f
        Layout(page)
    end

    local ApplyBefore = FDJ.ApplyRPGCard
    FDJ.ApplyRPGCard = function(card, name, ...)
        ApplyBefore(card, name, ...)
        local page = card.rpgPage
        -- "Coming soon" pages stay blank, previews too (tornall).
        if FDJ.DB and FDJ.DB[name] and FDJ.DB[name].previewOnly then
            if page and page.torn then page.torn.f = 0 Layout(page) end
            return
        end
        local list = Bosses(name)
        local total = #list
        local k = previews[name]
        if k == nil then k = previewAll end
        if k ~= nil and total > 0 then
            k = math.max(0, math.min(total, k))
            local open = k >= total
            if open then
                if page then page:Hide() end
            else
                page = JournalPage(card)
                page.sketch:SetTexture(SketchFor(name))
                page:Show()
                if page.questCount then page.questCount:Hide() page.questBack:Hide() end
            end
            for _, key in ipairs(COVER_PARTS) do
                local part = card[key]
                if part and part.SetAlpha then part:SetAlpha(open and 1 or 0) end
            end
            if open then return end
        else
            if not (page and page:IsShown()) then -- open, or not RPG Mode
                if page and page.torn then page.torn.f = 0 Layout(page) end
                return
            end
            k = Killed(name, list)
        end
        Show(card, page, total > 0 and k / total or 0)
    end

    -- /dj torn                    every dungeon's count, and the commands
    -- /dj torn <n>                every card as if n bosses were dead
    -- /dj torn <dungeon> [<n>]    one dungeon: its count, or a preview
    -- /dj torn off                previews off
    -- (English, like the other test commands.)
    local function Key(text) return (tostring(text or ""):lower():gsub("[^%w]", "")) end
    local function Short(name)
        for _, e in ipairs(FDJ.TESTLOG_DUNGEONS or {}) do
            if e[2] == name then return e[1] end
        end
    end
    local function Dungeons()
        local out = {}
        for _, name in ipairs(FDJ.ORDER or {}) do
            local d = FDJ.DB and FDJ.DB[name]
            if d and not d.previewOnly and not d.questChainPage and #Bosses(name) > 0 then out[#out + 1] = name end
        end
        return out
    end
    -- An abbreviation (wc, smlib), the name, or a unique part of it.
    local function Find(word)
        local key = Key(word)
        if key == "" then return nil end
        local partial = {}
        for _, name in ipairs(Dungeons()) do
            local shown = FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(name) or name
            if key == Short(name) or key == Key(name) or key == Key(shown) then return name end
            if Key(name):find(key, 1, true) or Key(shown):find(key, 1, true) then partial[#partial + 1] = name end
        end
        if #partial == 1 then return partial[1] end
        return nil, partial
    end
    local function Share(k, total)
        return total > 0 and math.floor(k / total * 100 + 0.5) or 0
    end
    local function Refresh()
        local journal = _G.ForeverDungeonJournalFrame
        if FDJ.ToggleJournal and not (journal and journal:IsShown()) then pcall(FDJ.ToggleJournal) end
        journal = _G.ForeverDungeonJournalFrame
        if journal and journal.currentView ~= "home" and journal.backButton then
            local back = journal.backButton:GetScript("OnClick")
            if back then pcall(back, journal.backButton) end
        end
        if FDJ.RefreshHomeCards then pcall(FDJ.RefreshHomeCards) end
    end
end
-- END rpgtorn

-- BEGIN rpglegacy
-- ------------------------------- RPG Mode: pages opened by Legacy Challenges
-- rpglegacy (2.0.8, M 15 Nov 2026): WoW Forever's Legacy Challenges (its
-- achievements, account-wide) tick every dungeon the account has completed
-- in Novice, Experienced and Master Spelunker. With Account-Wide Unlocks on
-- (the default from now on), RPG Mode reads them and opens those pages, as
-- if their final boss had died; switched off, it stops reading them and
-- each character is back to its own unlocks (nothing saved is changed).
-- Not from Legacy: Ragefire Chasm and Hall of Thanes (one tick for both,
-- "Ragefire Chasm or Hall of Thanes") and The Stockade (not in the lists):
-- they keep the quests, the kills and "I already did this dungeon". Every
-- other page Legacy lists loses that button while this is on: it opens by
-- itself once Legacy shows it done.
-- The challenges are found by their lists, not their names, so any client
-- language works: an achievement whose ticks are mostly (and at least
-- three) journal pages (the page's name, exactly, in any of the journal's languages; a
-- tick that matches no page is left alone). Read after login (out of combat,
-- a few seconds after the loading screen), when a challenge moves on, and
-- when the option or RPG Mode is switched on. The last reading is kept
-- (ForeverDungeonJournalDB.rpgLegacy), so the pages are open at once at the
-- next login. /dj legacy shows what was read.
do
    local strings = {
        enUS = { RPG_LEGACY_OPENED = "Opened by your account's Legacy Challenges: %s.",
            RPG_LEGACY_WAIT = "This page opens by itself once your account's Legacy Challenges show this dungeon as done." },
        deDE = { RPG_LEGACY_OPENED = "Durch die Legacy-Herausforderungen deines Accounts freigeschaltet: %s.",
            RPG_LEGACY_WAIT = "Diese Seite wird von selbst freigeschaltet, sobald die Legacy-Herausforderungen deines Accounts diesen Dungeon als abgeschlossen zeigen." },
        frFR = { RPG_LEGACY_OPENED = "Débloqué par les défis Legacy de votre compte : %s.",
            RPG_LEGACY_WAIT = "Cette page se débloque d'elle-même dès que les défis Legacy de votre compte indiquent ce donjon comme terminé." },
        esES = { RPG_LEGACY_OPENED = "Desbloqueado por los desafíos Legacy de tu cuenta: %s.",
            RPG_LEGACY_WAIT = "Esta página se desbloquea sola en cuanto los desafíos Legacy de tu cuenta muestren esta mazmorra como completada." },
        itIT = { RPG_LEGACY_OPENED = "Sbloccato dalle sfide Legacy del tuo account: %s.",
            RPG_LEGACY_WAIT = "Questa pagina si sblocca da sola appena le sfide Legacy del tuo account segnano questo dungeon come completato." },
        ptBR = { RPG_LEGACY_OPENED = "Desbloqueado pelos desafios Legacy da sua conta: %s.",
            RPG_LEGACY_WAIT = "Esta página se desbloqueia sozinha assim que os desafios Legacy da sua conta mostrarem esta masmorra como concluída." },
        ruRU = { RPG_LEGACY_OPENED = "Открыто испытаниями Legacy вашей учётной записи: %s.",
            RPG_LEGACY_WAIT = "Эта страница откроется сама, как только испытания Legacy вашей учётной записи отметят это подземелье как пройденное." },
        koKR = { RPG_LEGACY_OPENED = "계정의 Legacy 도전 과제로 열림: %s.",
            RPG_LEGACY_WAIT = "계정의 Legacy 도전 과제에 이 던전이 완료로 표시되면 이 페이지가 자동으로 열립니다." },
        zhCN = { RPG_LEGACY_OPENED = "由你账号的Legacy挑战解锁：%s。",
            RPG_LEGACY_WAIT = "当你账号的Legacy挑战显示此地下城已完成时，此页面会自动解锁。" },
        zhTW = { RPG_LEGACY_OPENED = "由你帳號的Legacy挑戰解鎖：%s。",
            RPG_LEGACY_WAIT = "當你帳號的Legacy挑戰顯示此地城已完成時，此頁面會自動解鎖。" },
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

    local NEVER = { ["Ragefire Chasm"] = true, ["Hall of Thanes"] = true, ["The Stockade"] = true }
    -- Other wordings of a page's name (the Legacy list's, the wiki's).
    local ALIASES = {
        ["Stratholme Live"] = "Stratholme: Living", ["Stratholme Living"] = "Stratholme: Living",
        ["Stratholme Main Gate"] = "Stratholme: Living",
        ["Stratholme Dead"] = "Stratholme: Undead", ["Stratholme Service Gate"] = "Stratholme: Undead",
        ["The Temple of Atal'Hakkar"] = "Sunken Temple", ["Temple of Atal'Hakkar"] = "Sunken Temple",
        ["The Shaper's Terrace"] = "Shaper's Terrace",
    }

    -- Lower case, no colour codes, no leading article ("The Deadmines",
    -- "Die Höhlen des Wehklagens" = "Höhlen des Wehklagens"), no spaces or
    -- ASCII punctuation (letters of other alphabets stay).
    local ARTICLES = { the = true, der = true, die = true, das = true, le = true, la = true, les = true,
        el = true, los = true, las = true, il = true, lo = true, gli = true, i = true, o = true, os = true,
        a = true, as = true }
    local function Norm(text)
        if type(text) ~= "string" then return "" end
        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
        local first, rest = text:match("^%s*(%S+)%s+(.+)$")
        if first and ARTICLES[first] then text = rest end
        text = text:gsub("^%s*l'", "")
        return (text:gsub("[%s%p]", ""))
    end

    local function Pages()
        local out = {}
        for _, name in ipairs(FDJ.ORDER or {}) do
            local d = FDJ.DB and FDJ.DB[name]
            if d and not d.previewOnly and not d.questChainPage then out[#out + 1] = name end
        end
        return out
    end

    -- name key -> page (false: two pages share it). Only names: a tick's
    -- other number (its "asset") can be an area of the map, which may be the
    -- same number as some boss, so it is never used to pick a page.
    local byKey
    local function Index()
        if byKey then return end
        byKey = {}
        local function Put(key, name)
            if key == nil or key == "" then return end
            if byKey[key] == nil then byKey[key] = name elseif byKey[key] ~= name then byKey[key] = false end
        end
        for _, name in ipairs(Pages()) do
            Put(Norm(name), name)
            for _, loc in pairs(FDJ.ContentLocales or {}) do
                local e = type(loc) == "table" and type(loc.dungeons) == "table" and loc.dungeons[name]
                if type(e) == "table" and type(e.name) == "string" then Put(Norm(e.name), name) end
            end
        end
        for alias, name in pairs(ALIASES) do
            if FDJ.DB and FDJ.DB[name] then Put(Norm(alias), name) end
        end
    end

    -- The page one Legacy tick stands for (its name, exactly), or nil and why.
    local function Match(text)
        Index()
        local key = Norm(text)
        local hit = byKey[key]
        if hit then return hit end
        if hit == false then return nil, "two pages" end
        -- "Ragefire Chasm or Hall of Thanes": a tick that names two pages.
        local names, count = {}, 0
        if key ~= "" then
            for k, name in pairs(byKey) do
                if name and #k >= 4 and key:find(k, 1, true) and not names[name] then
                    names[name] = true
                    count = count + 1
                end
            end
        end
        if count > 1 then return nil, "two pages" end
        return nil, "not a page"
    end

    local function Store()
        ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
        local s = ForeverDungeonJournalDB.rpgLegacy
        if type(s) ~= "table" then
            s = {}
            ForeverDungeonJournalDB.rpgLegacy = s
        end
        if type(s.done) ~= "table" then s.done = {} end
        if type(s.covered) ~= "table" then s.covered = {} end
        return s
    end

    -- The challenges that list pages (found once per session).
    local found, lastRead
    local function Criteria(id)
        local out = {}
        local ok, count = pcall(GetAchievementNumCriteria, id)
        if not ok or type(count) ~= "number" then return out end
        for j = 1, count do
            local okC, text, ctype, done, _, _, _, _, asset = pcall(GetAchievementCriteriaInfo, id, j)
            if okC then out[#out + 1] = { text = text, type = ctype, done = done, asset = asset } end
        end
        return out
    end
    local missedAt
    local function Find()
        if found then return found end
        local now = GetTime and GetTime() or 0
        if missedAt and now - missedAt < 30 then return nil end -- not again right away
        local list = {}
        local okL, cats = pcall(GetCategoryList)
        if not okL or type(cats) ~= "table" then return nil end
        for _, cat in ipairs(cats) do
            local okN, n = pcall(GetCategoryNumAchievements, cat, true)
            for i = 1, (okN and tonumber(n) or 0) do
                local okA, id, title = pcall(GetAchievementInfo, cat, i)
                if okA and id then
                    -- A dungeon list: three or more pages, and most of its
                    -- ticks (an exploration challenge also names places like
                    -- Wailing Caverns or Zul'Farrak among many others).
                    local pages, ticks = 0, 0
                    for _, c in ipairs(Criteria(id)) do
                        ticks = ticks + 1
                        if Match(c.text) then pages = pages + 1 end
                    end
                    if pages >= 3 and pages >= ticks * 0.6 then list[#list + 1] = { id = id, title = title } end
                end
            end
        end
        if #list > 0 then found = list else missedAt = now end
        return found
    end

    -- Reads the challenges: the pages they list, and the ones done.
    local function Read()
        if type(GetCategoryList) ~= "function" or type(GetAchievementInfo) ~= "function"
            or type(GetAchievementNumCriteria) ~= "function" or type(GetAchievementCriteriaInfo) ~= "function" then
            return nil
        end
        local list = Find()
        if not list then return nil end
        local covered, done, rows = {}, {}, {}
        for _, a in ipairs(list) do
            local ok, _, title, _, whole = pcall(GetAchievementInfo, a.id)
            rows[#rows + 1] = { title = (ok and title) or a.title, id = a.id, whole = ok and whole or false }
            for _, c in ipairs(Criteria(a.id)) do
                local name, why = Match(c.text)
                local isDone = c.done == true or (ok and whole == true)
                if name and NEVER[name] then why, name = "kept manual", nil end
                if not name and why == "two pages" then why = "names two pages, kept manual" end
                rows[#rows + 1] = { text = c.text, page = name, done = isDone, why = why }
                if name then
                    covered[name] = true
                    if isDone then done[name] = true end
                end
            end
        end
        if not next(covered) then return nil end
        return covered, done, rows
    end
    FDJ.RPGLegacyRead = Read -- /dj legacy

    local function Active()
        return FDJ.IsRPGMode and FDJ.IsRPGMode() and AccountWide() or false
    end

    -- The pages the last reading showed done (ViewTable adds them).
    function FDJ.RPGLegacyPages()
        local s = ForeverDungeonJournalDB and ForeverDungeonJournalDB.rpgLegacy
        if type(s) ~= "table" or type(s.done) ~= "table" then return nil end
        for name in pairs(NEVER) do s.done[name] = nil end
        return s.done
    end
    -- Is this page one Legacy opens by itself (so no "I already did")?
    function FDJ.RPGLegacyCovers(name)
        if not Active() or NEVER[name] then return false end
        local s = ForeverDungeonJournalDB and ForeverDungeonJournalDB.rpgLegacy
        return type(s) == "table" and type(s.covered) == "table" and s.covered[name] == true or false
    end

    local pendingCombat, scheduled, tries = false, false, 0
    local function Refresh()
        if not Active() then return end
        if InCombatLockdown and InCombatLockdown() then pendingCombat = true return end
        local covered, done = Read()
        if not covered then return false end
        lastRead = GetTime and GetTime() or 0
        local s = Store()
        local wasOpen = {}
        local view = ViewTable("rpgKills")
        for name in pairs(done) do wasOpen[name] = view[name] and true or false end
        local changed = false
        for name in pairs(done) do if not s.done[name] then changed = true end end
        for name in pairs(s.done) do if not done[name] then changed = true end end
        s.covered, s.done = covered, done
        local opened = {}
        for _, name in ipairs(Pages()) do
            if done[name] and not wasOpen[name] then
                opened[#opened + 1] = FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(name) or name
            end
        end
        if #opened > 0 then
            print("|cffd8a83cDungeon Journal:|r |cff40ff40" .. L("RPG_LEGACY_OPENED", table.concat(opened, ", ")) .. "|r")
        end
        if changed or #opened > 0 then
            if FDJ.RPGShareProgress then pcall(FDJ.RPGShareProgress) end
            if FDJ.RPGStateChanged then pcall(FDJ.RPGStateChanged) end
            if FDJ.RefreshHomeCards then pcall(FDJ.RefreshHomeCards) end
        end
        return true
    end
    local function Schedule(delay)
        if scheduled then return end
        scheduled = true
        local function run()
            scheduled = false
            local ok, done = pcall(Refresh)
            -- The game may not have the challenges yet right after login.
            if ok and done == false and tries < 6 then
                tries = tries + 1
                Schedule(10)
            end
        end
        if C_Timer and C_Timer.After then C_Timer.After(delay, run) else run() end
    end
    function FDJ.RPGLegacyRefresh()
        if not Active() then return end
        tries = 0
        Schedule(0.5)
    end

    local watch = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "CRITERIA_UPDATE",
        "CRITERIA_EARNED", "ACHIEVEMENT_EARNED", "RECEIVED_ACHIEVEMENT_LIST" }) do
        pcall(watch.RegisterEvent, watch, event)
    end
    watch:SetScript("OnEvent", function(_, event)
        if not Active() then return end
        if event == "PLAYER_ENTERING_WORLD" then
            tries = 0
            Schedule(5) -- after the loading screen
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingCombat then pendingCombat = false Schedule(2) end
        else
            -- A challenge moved on: read again soon (many ticks come at once).
            Schedule(3)
        end
    end)

end
-- END rpglegacy
