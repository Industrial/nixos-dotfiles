-- Run Log page: the icon left of Favourites on the main dungeon page opens a
-- window with every recorded run (Systems/RunLog.lua records them).
-- Left: the runs, newest first. Right: the chosen run - time, deaths, trash
-- killed, XP, the bosses and trash killed with their XP, Need rolls won or
-- lost, and the time spent outside (corpse runs, vendor trips).
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local function L(key, ...)
    if FDJ.L then return FDJ.L(key, ...) end
    return key
end

do
    local strings = {
        enUS = {
            RUNLOG = "Character Logs",
            RUNLOG_TIP = "Every dungeon run of this character: time, kills and XP, deaths and Need rolls.",
            RUNLOG_EMPTY = "No runs yet.\n\nGo into a dungeon: each run is logged on its own.",
            RUNLOG_IN_PROGRESS = "In progress", RUNLOG_COMPLETED = "Completed", RUNLOG_UNFINISHED = "Not finished",
            RUNLOG_TIME = "Time", RUNLOG_TIME_TIP = "From the first trash kill to the last boss kill.",
            RUNLOG_RUNNING = "running",
            RUNLOG_DEATHS = "Deaths", RUNLOG_DIED_AT = "Died at %s",
            RUNLOG_TRASH = "Trash killed", RUNLOG_TRASH_OF = "%d of %d",
            RUNLOG_TRASH_TIP = "Trash mobs killed this run (bosses and rares not counted).",
            RUNLOG_XP = "XP from mobs",
            RUNLOG_BOSSES = "Bosses", RUNLOG_TRASH_MOBS = "Trash", RUNLOG_NEED = "Need rolls",
            RUNLOG_NO_NEED = "You didn't \"Need\" on anything this run.", RUNLOG_NO_TRASH = "No trash killed.",
            RUNLOG_NOT_KILLED = "not killed", RUNLOG_RARE = "Rare",
            RUNLOG_WON = "Won", RUNLOG_LOST = "Lost", RUNLOG_ROLLS = "Rolls", RUNLOG_ROLLING = "Rolling...",
            RUNLOG_OUTSIDE = "Time outside", RUNLOG_RELEASED = "Death Walk", RUNLOG_STEPPED = "Stepped out",
            RUNLOG_STILL_OUT = "still outside",
            RUNLOG_ROW_HINT = "Right click: delete this run", RUNLOG_DELETE = "Delete this run of %s?",
            RUNLOG_DONE = "%s done in %s - deaths: %d - trash: %s - %s XP  (/dj log)",
        },
        deDE = {
            RUNLOG = "Charakter-Logs",
            RUNLOG_TIP = "Jeder Dungeon-Run dieses Charakters: Zeit, Kills und EP, Tode und Bedarfswürfe.",
            RUNLOG_EMPTY = "Noch keine Runs.\n\nGeh in einen Dungeon: Jeder Run wird von selbst aufgezeichnet.",
            RUNLOG_IN_PROGRESS = "Läuft", RUNLOG_COMPLETED = "Abgeschlossen", RUNLOG_UNFINISHED = "Nicht beendet",
            RUNLOG_TIME = "Zeit", RUNLOG_TIME_TIP = "Vom ersten Trash-Kill bis zum letzten Boss-Kill.",
            RUNLOG_RUNNING = "läuft",
            RUNLOG_DEATHS = "Tode", RUNLOG_DIED_AT = "Gestorben bei %s",
            RUNLOG_TRASH = "Trash getötet", RUNLOG_TRASH_OF = "%d von %d",
            RUNLOG_TRASH_TIP = "In diesem Run getöteter Trash (ohne Bosse und Rares).",
            RUNLOG_XP = "EP von Gegnern",
            RUNLOG_BOSSES = "Bosse", RUNLOG_TRASH_MOBS = "Trash", RUNLOG_NEED = "Bedarfswürfe",
            RUNLOG_NO_NEED = "In diesem Run hast du auf nichts Bedarf gewürfelt.", RUNLOG_NO_TRASH = "Kein Trash getötet.",
            RUNLOG_NOT_KILLED = "nicht getötet", RUNLOG_RARE = "Rare",
            RUNLOG_WON = "Gewonnen", RUNLOG_LOST = "Verloren", RUNLOG_ROLLS = "Würfe", RUNLOG_ROLLING = "Wird gewürfelt...",
            RUNLOG_OUTSIDE = "Zeit draußen", RUNLOG_RELEASED = "Geisterlauf", RUNLOG_STEPPED = "Rausgegangen",
            RUNLOG_STILL_OUT = "noch draußen",
            RUNLOG_ROW_HINT = "Rechtsklick: diesen Run löschen", RUNLOG_DELETE = "Diesen Run von %s löschen?",
            RUNLOG_DONE = "%s geschafft in %s - Tode: %d - Trash: %s - %s EP  (/dj log)",
        },
        frFR = {
            RUNLOG = "Journaux du personnage",
            RUNLOG_TIP = "Chaque run de donjon de ce personnage : temps, ennemis tués et XP, morts et jets de Besoin.",
            RUNLOG_EMPTY = "Aucun run pour l'instant.\n\nEntrez dans un donjon : chaque run est enregistré tout seul.",
            RUNLOG_IN_PROGRESS = "En cours", RUNLOG_COMPLETED = "Terminé", RUNLOG_UNFINISHED = "Pas fini",
            RUNLOG_TIME = "Temps", RUNLOG_TIME_TIP = "Du premier monstre tué au dernier boss tué.",
            RUNLOG_RUNNING = "en cours",
            RUNLOG_DEATHS = "Morts", RUNLOG_DIED_AT = "Mort à %s",
            RUNLOG_TRASH = "Monstres tués", RUNLOG_TRASH_OF = "%d sur %d",
            RUNLOG_TRASH_TIP = "Monstres tués pendant ce run (hors boss et rares).",
            RUNLOG_XP = "XP des monstres",
            RUNLOG_BOSSES = "Boss", RUNLOG_TRASH_MOBS = "Monstres", RUNLOG_NEED = "Jets de Besoin",
            RUNLOG_NO_NEED = "Aucun jet de Besoin dans ce run.", RUNLOG_NO_TRASH = "Aucun monstre tué.",
            RUNLOG_NOT_KILLED = "pas tué", RUNLOG_RARE = "Rare",
            RUNLOG_WON = "Gagné", RUNLOG_LOST = "Perdu", RUNLOG_ROLLS = "Jets", RUNLOG_ROLLING = "Jet en cours...",
            RUNLOG_OUTSIDE = "Temps dehors", RUNLOG_RELEASED = "Marche du fantôme", RUNLOG_STEPPED = "Sorti",
            RUNLOG_STILL_OUT = "encore dehors",
            RUNLOG_ROW_HINT = "Clic droit : supprimer ce run", RUNLOG_DELETE = "Supprimer ce run de %s ?",
            RUNLOG_DONE = "%s fini en %s - morts : %d - monstres : %s - %s XP  (/dj log)",
        },
        esES = {
            RUNLOG = "Registros del personaje",
            RUNLOG_TIP = "Cada run de mazmorra de este personaje: tiempo, muertes de enemigos y PX, muertes y tiradas de Necesidad.",
            RUNLOG_EMPTY = "Aún no hay runs.\n\nEntra en una mazmorra: cada run se registra solo.",
            RUNLOG_IN_PROGRESS = "En curso", RUNLOG_COMPLETED = "Completado", RUNLOG_UNFINISHED = "Sin terminar",
            RUNLOG_TIME = "Tiempo", RUNLOG_TIME_TIP = "Desde el primer enemigo matado hasta el último jefe.",
            RUNLOG_RUNNING = "en curso",
            RUNLOG_DEATHS = "Muertes", RUNLOG_DIED_AT = "Muerto en %s",
            RUNLOG_TRASH = "Enemigos matados", RUNLOG_TRASH_OF = "%d de %d",
            RUNLOG_TRASH_TIP = "Enemigos matados en este run (sin contar jefes ni raros).",
            RUNLOG_XP = "PX de enemigos",
            RUNLOG_BOSSES = "Jefes", RUNLOG_TRASH_MOBS = "Enemigos", RUNLOG_NEED = "Tiradas de Necesidad",
            RUNLOG_NO_NEED = "No tiraste Necesidad en este run.", RUNLOG_NO_TRASH = "Ningún enemigo matado.",
            RUNLOG_NOT_KILLED = "sin matar", RUNLOG_RARE = "Raro",
            RUNLOG_WON = "Ganado", RUNLOG_LOST = "Perdido", RUNLOG_ROLLS = "Tiradas", RUNLOG_ROLLING = "Tirando...",
            RUNLOG_OUTSIDE = "Tiempo fuera", RUNLOG_RELEASED = "Paseo fantasmal", RUNLOG_STEPPED = "Salió",
            RUNLOG_STILL_OUT = "aún fuera",
            RUNLOG_ROW_HINT = "Clic derecho: borrar este run", RUNLOG_DELETE = "¿Borrar este run de %s?",
            RUNLOG_DONE = "%s hecho en %s - muertes: %d - enemigos: %s - %s PX  (/dj log)",
        },
        itIT = {
            RUNLOG = "Registri del personaggio",
            RUNLOG_TIP = "Ogni run nei dungeon di questo personaggio: tempo, uccisioni e PE, morti e tiri Necessità.",
            RUNLOG_EMPTY = "Ancora nessuna run.\n\nEntra in un dungeon: ogni run viene registrata da sola.",
            RUNLOG_IN_PROGRESS = "In corso", RUNLOG_COMPLETED = "Completata", RUNLOG_UNFINISHED = "Non finita",
            RUNLOG_TIME = "Tempo", RUNLOG_TIME_TIP = "Dalla prima uccisione di trash all'ultima uccisione di un boss.",
            RUNLOG_RUNNING = "in corso",
            RUNLOG_DEATHS = "Morti", RUNLOG_DIED_AT = "Morto a %s",
            RUNLOG_TRASH = "Trash ucciso", RUNLOG_TRASH_OF = "%d su %d",
            RUNLOG_TRASH_TIP = "Trash ucciso in questa run (boss e rari esclusi).",
            RUNLOG_XP = "PE dai mob",
            RUNLOG_BOSSES = "Boss", RUNLOG_TRASH_MOBS = "Trash", RUNLOG_NEED = "Tiri Necessità",
            RUNLOG_NO_NEED = "In questa run non hai tirato Necessità su nulla.", RUNLOG_NO_TRASH = "Nessun trash ucciso.",
            RUNLOG_NOT_KILLED = "non ucciso", RUNLOG_RARE = "Raro",
            RUNLOG_WON = "Vinto", RUNLOG_LOST = "Perso", RUNLOG_ROLLS = "Tiri", RUNLOG_ROLLING = "Si tira...",
            RUNLOG_OUTSIDE = "Tempo fuori", RUNLOG_RELEASED = "Corsa del fantasma", RUNLOG_STEPPED = "Uscito",
            RUNLOG_STILL_OUT = "ancora fuori",
            RUNLOG_ROW_HINT = "Clic destro: elimina questa run", RUNLOG_DELETE = "Eliminare questa run di %s?",
            RUNLOG_DONE = "%s finito in %s - morti: %d - trash: %s - %s PE  (/dj log)",
        },
        ptBR = {
            RUNLOG = "Registros do personagem",
            RUNLOG_TIP = "Cada run de masmorra deste personagem: tempo, abates e XP, mortes e rolagens de Necessidade.",
            RUNLOG_EMPTY = "Nenhuma run ainda.\n\nEntre numa masmorra: cada run é registrada sozinha.",
            RUNLOG_IN_PROGRESS = "Em andamento", RUNLOG_COMPLETED = "Concluída", RUNLOG_UNFINISHED = "Não terminada",
            RUNLOG_TIME = "Tempo", RUNLOG_TIME_TIP = "Do primeiro inimigo abatido ao último chefe.",
            RUNLOG_RUNNING = "em andamento",
            RUNLOG_DEATHS = "Mortes", RUNLOG_DIED_AT = "Morreu em %s",
            RUNLOG_TRASH = "Inimigos abatidos", RUNLOG_TRASH_OF = "%d de %d",
            RUNLOG_TRASH_TIP = "Inimigos abatidos nesta run (sem contar chefes e raros).",
            RUNLOG_XP = "XP de inimigos",
            RUNLOG_BOSSES = "Chefes", RUNLOG_TRASH_MOBS = "Inimigos", RUNLOG_NEED = "Rolagens de Necessidade",
            RUNLOG_NO_NEED = "Você não rolou Necessidade nesta run.", RUNLOG_NO_TRASH = "Nenhum inimigo abatido.",
            RUNLOG_NOT_KILLED = "não abatido", RUNLOG_RARE = "Raro",
            RUNLOG_WON = "Ganhou", RUNLOG_LOST = "Perdeu", RUNLOG_ROLLS = "Rolagens", RUNLOG_ROLLING = "Rolando...",
            RUNLOG_OUTSIDE = "Tempo fora", RUNLOG_RELEASED = "Caminhada fantasma", RUNLOG_STEPPED = "Saiu",
            RUNLOG_STILL_OUT = "ainda fora",
            RUNLOG_ROW_HINT = "Clique direito: apagar esta run", RUNLOG_DELETE = "Apagar esta run de %s?",
            RUNLOG_DONE = "%s feita em %s - mortes: %d - inimigos: %s - %s XP  (/dj log)",
        },
        ruRU = {
            RUNLOG = "Журналы персонажа",
            RUNLOG_TIP = "Каждый забег этого персонажа в подземелье: время, убийства и опыт, смерти и броски «Мне это нужно».",
            RUNLOG_EMPTY = "Забегов пока нет.\n\nЗайдите в подземелье: каждый забег записывается сам.",
            RUNLOG_IN_PROGRESS = "Идёт", RUNLOG_COMPLETED = "Пройдено", RUNLOG_UNFINISHED = "Не закончено",
            RUNLOG_TIME = "Время", RUNLOG_TIME_TIP = "От первого убитого монстра до последнего убитого босса.",
            RUNLOG_RUNNING = "идёт",
            RUNLOG_DEATHS = "Смерти", RUNLOG_DIED_AT = "Смерть на %s",
            RUNLOG_TRASH = "Монстров убито", RUNLOG_TRASH_OF = "%d из %d",
            RUNLOG_TRASH_TIP = "Монстры, убитые за этот забег (без боссов и редких).",
            RUNLOG_XP = "Опыт за монстров",
            RUNLOG_BOSSES = "Боссы", RUNLOG_TRASH_MOBS = "Монстры", RUNLOG_NEED = "Броски «Нужно»",
            RUNLOG_NO_NEED = "В этом забеге вы не бросали «Нужно».", RUNLOG_NO_TRASH = "Монстры не убиты.",
            RUNLOG_NOT_KILLED = "не убит", RUNLOG_RARE = "Редкий",
            RUNLOG_WON = "Выиграно", RUNLOG_LOST = "Проиграно", RUNLOG_ROLLS = "Броски", RUNLOG_ROLLING = "Бросок...",
            RUNLOG_OUTSIDE = "Время снаружи", RUNLOG_RELEASED = "Путь призрака", RUNLOG_STEPPED = "Вышел",
            RUNLOG_STILL_OUT = "ещё снаружи",
            RUNLOG_ROW_HINT = "Правый клик: удалить забег", RUNLOG_DELETE = "Удалить этот забег (%s)?",
            RUNLOG_DONE = "%s пройдено за %s - смерти: %d - монстры: %s - %s опыта  (/dj log)",
        },
        koKR = {
            RUNLOG = "캐릭터 기록",
            RUNLOG_TIP = "이 캐릭터의 모든 던전 기록: 시간, 처치와 경험치, 죽음, 입찰 주사위.",
            RUNLOG_EMPTY = "아직 기록이 없습니다.\n\n던전에 들어가면 자동으로 기록됩니다.",
            RUNLOG_IN_PROGRESS = "진행 중", RUNLOG_COMPLETED = "완료", RUNLOG_UNFINISHED = "미완료",
            RUNLOG_TIME = "시간", RUNLOG_TIME_TIP = "첫 일반 몹 처치부터 마지막 우두머리 처치까지.",
            RUNLOG_RUNNING = "진행 중",
            RUNLOG_DEATHS = "죽음", RUNLOG_DIED_AT = "%s에 죽음",
            RUNLOG_TRASH = "일반 몹 처치", RUNLOG_TRASH_OF = "%d / %d",
            RUNLOG_TRASH_TIP = "이번 런에서 처치한 일반 몹 수 (우두머리와 희귀 몹 제외).",
            RUNLOG_XP = "몹 경험치",
            RUNLOG_BOSSES = "우두머리", RUNLOG_TRASH_MOBS = "일반 몹", RUNLOG_NEED = "입찰 주사위",
            RUNLOG_NO_NEED = "이 기록에서 입찰한 아이템이 없습니다.", RUNLOG_NO_TRASH = "처치한 일반 몹이 없습니다.",
            RUNLOG_NOT_KILLED = "처치 안 함", RUNLOG_RARE = "희귀",
            RUNLOG_WON = "획득", RUNLOG_LOST = "실패", RUNLOG_ROLLS = "주사위", RUNLOG_ROLLING = "주사위 중...",
            RUNLOG_OUTSIDE = "밖에 있던 시간", RUNLOG_RELEASED = "유령 걷기", RUNLOG_STEPPED = "나감",
            RUNLOG_STILL_OUT = "아직 밖",
            RUNLOG_ROW_HINT = "우클릭: 이 기록 삭제", RUNLOG_DELETE = "%s 기록을 삭제할까요?",
            RUNLOG_DONE = "%s 완료: %s - 죽음: %d - 일반 몹: %s - 경험치 %s  (/dj log)",
        },
        zhCN = {
            RUNLOG = "角色记录",
            RUNLOG_TIP = "该角色的每次副本记录：用时、击杀与经验、死亡次数和需求掷骰。",
            RUNLOG_EMPTY = "还没有记录。\n\n进入副本后，每次都会自动记录。",
            RUNLOG_IN_PROGRESS = "进行中", RUNLOG_COMPLETED = "已完成", RUNLOG_UNFINISHED = "未完成",
            RUNLOG_TIME = "用时", RUNLOG_TIME_TIP = "从第一次击杀小怪到最后一次击杀首领。",
            RUNLOG_RUNNING = "进行中",
            RUNLOG_DEATHS = "死亡", RUNLOG_DIED_AT = "死于 %s",
            RUNLOG_TRASH = "小怪击杀", RUNLOG_TRASH_OF = "%d / %d",
            RUNLOG_TRASH_TIP = "本次击杀的小怪数量（不含首领和稀有怪）。",
            RUNLOG_XP = "怪物经验",
            RUNLOG_BOSSES = "首领", RUNLOG_TRASH_MOBS = "小怪", RUNLOG_NEED = "需求掷骰",
            RUNLOG_NO_NEED = "本次没有点需求。", RUNLOG_NO_TRASH = "没有击杀小怪。",
            RUNLOG_NOT_KILLED = "未击杀", RUNLOG_RARE = "稀有",
            RUNLOG_WON = "赢得", RUNLOG_LOST = "未得", RUNLOG_ROLLS = "掷骰", RUNLOG_ROLLING = "掷骰中...",
            RUNLOG_OUTSIDE = "在外时间", RUNLOG_RELEASED = "跑尸", RUNLOG_STEPPED = "离开副本",
            RUNLOG_STILL_OUT = "仍在外面",
            RUNLOG_ROW_HINT = "右键：删除此记录", RUNLOG_DELETE = "删除这条 %s 的记录？",
            RUNLOG_DONE = "%s 完成，用时 %s - 死亡：%d - 小怪：%s - 经验 %s  (/dj log)",
        },
        zhTW = {
            RUNLOG = "角色紀錄",
            RUNLOG_TIP = "此角色的每次副本紀錄：用時、擊殺與經驗、死亡次數和需求擲骰。",
            RUNLOG_EMPTY = "還沒有紀錄。\n\n進入副本後，每次都會自動記錄。",
            RUNLOG_IN_PROGRESS = "進行中", RUNLOG_COMPLETED = "已完成", RUNLOG_UNFINISHED = "未完成",
            RUNLOG_TIME = "用時", RUNLOG_TIME_TIP = "從第一次擊殺小怪到最後一次擊殺首領。",
            RUNLOG_RUNNING = "進行中",
            RUNLOG_DEATHS = "死亡", RUNLOG_DIED_AT = "死於 %s",
            RUNLOG_TRASH = "小怪擊殺", RUNLOG_TRASH_OF = "%d / %d",
            RUNLOG_TRASH_TIP = "本次擊殺的小怪數量（不含首領和稀有怪）。",
            RUNLOG_XP = "怪物經驗",
            RUNLOG_BOSSES = "首領", RUNLOG_TRASH_MOBS = "小怪", RUNLOG_NEED = "需求擲骰",
            RUNLOG_NO_NEED = "本次沒有點需求。", RUNLOG_NO_TRASH = "沒有擊殺小怪。",
            RUNLOG_NOT_KILLED = "未擊殺", RUNLOG_RARE = "稀有",
            RUNLOG_WON = "贏得", RUNLOG_LOST = "未得", RUNLOG_ROLLS = "擲骰", RUNLOG_ROLLING = "擲骰中...",
            RUNLOG_OUTSIDE = "在外時間", RUNLOG_RELEASED = "跑屍", RUNLOG_STEPPED = "離開副本",
            RUNLOG_STILL_OUT = "仍在外面",
            RUNLOG_ROW_HINT = "右鍵：刪除此紀錄", RUNLOG_DELETE = "刪除這筆 %s 的紀錄？",
            RUNLOG_DONE = "%s 完成，用時 %s - 死亡：%d - 小怪：%s - 經驗 %s  (/dj log)",
        },
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

local LOG_ICON = "Interface\\Icons\\INV_Scroll_03"
-- The Run Log's icons show the character playing (its portrait); the scroll
-- is only a fallback. square: the full picture, not cut to a circle.
local function PlayerPortrait(tex, square)
    if not tex then return end
    local ok = SetPortraitTexture and pcall(SetPortraitTexture, tex, "player", square and true or nil)
    if not ok then tex:SetTexture(LOG_ICON) end
end
local LOG_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_Note_01"
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local GOLD = { 1.00, 0.82, 0.27 }
local MUTED = { 0.68, 0.62, 0.52 }

local function Now() return (GetServerTime and GetServerTime()) or time() end

-- An item's quality colour: from the game's item data, else from the link
-- (old "|cffRRGGBB" or Forever's "|cnIQ3:" form).
function FDJ.RunLogItemQuality(id, link)
    local q
    if id and C_Item and C_Item.GetItemQualityByID then
        local ok, v = pcall(C_Item.GetItemQualityByID, id)
        if ok and type(v) == "number" then q = v end
    end
    if not q and id and GetItemInfo then
        local ok, _, _, v = pcall(GetItemInfo, id)
        if ok and type(v) == "number" then q = v end
    end
    if not q and type(link) == "string" then
        q = tonumber(link:match("|cnIQ(%d)"))
        if not q then
            local hex = link:match("|c(%x%x%x%x%x%x%x%x)")
            local map = { ff9d9d9d = 0, ffffffff = 1, ff1eff00 = 2, ff0070dd = 3, ffa335ee = 4, ffff8000 = 5 }
            q = hex and map[hex:lower()]
        end
    end
    return q
end
function FDJ.RunLogItemColor(id, link)
    local q = FDJ.RunLogItemQuality(id, link)
    if q and C_Item and C_Item.GetItemQualityColor then
        local ok, r, g, b = pcall(C_Item.GetItemQualityColor, q)
        if ok and type(r) == "number" then return r, g, b end
    end
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    local fixed = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 } }
    local f = q and fixed[q]
    if f then return f[1], f[2], f[3] end
    return 1, 1, 1
end

local function Duration(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    local h, m, s = math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

local function Thousands(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

-- A run's date and time the way the game's own clock shows it: 12-hour
-- (9:01 PM) or 24-hour (21:01) as set on the clock (24-hour clock option;
-- English clients default to 12-hour), and realm time instead of the
-- computer's when the clock is set to realm time. English puts the month
-- first (Nov 9).
function FDJ.RunLogDate(t, withYear)
    t = t or Now()
    local function CV(name)
        if C_CVar and C_CVar.GetCVar then
            local ok, v = pcall(C_CVar.GetCVar, name)
            if ok and v ~= nil then return v end
        end
        if GetCVar then
            local ok, v = pcall(GetCVar, name)
            if ok then return v end
        end
    end
    local lang = (FDJ.GetLanguage and FDJ.GetLanguage()) or (GetLocale and GetLocale()) or "enUS"
    local military = CV("timeMgrUseMilitaryTime")
    local h24
    if military == nil or military == "" then
        h24 = lang ~= "enUS"
    else
        h24 = military == "1"
    end
    -- realm time: move the stamp by the realm clock's offset from this
    -- computer's (to the nearest quarter hour)
    if CV("timeMgrUseLocalTime") == "0" and GetGameTime then
        local rh, rm = GetGameTime()
        local now = date("*t")
        if rh and now then
            local diff = (rh * 60 + rm) - (now.hour * 60 + now.min)
            if diff > 720 then diff = diff - 1440 elseif diff < -720 then diff = diff + 1440 end
            diff = math.floor(diff / 15 + 0.5) * 15
            t = t + diff * 60
        end
    end
    local d = date("*t", t)
    local clock
    if h24 then
        clock = string.format("%02d:%02d", d.hour, d.min)
    else
        local h = d.hour % 12
        if h == 0 then h = 12 end
        clock = string.format("%d:%02d %s", h, d.min, d.hour < 12 and "AM" or "PM")
    end
    local day
    if lang == "enUS" then
        day = date("%b ", t) .. d.day .. (withYear and (", " .. d.year) or "")
    else
        day = string.format("%02d", d.day) .. date(" %b", t) .. (withYear and (" " .. d.year) or "")
    end
    return day .. (withYear and "  " or " ") .. clock
end

local function DungeonLabel(run)
    if run.dungeon and FDJ.LocalizeDungeonName then
        local ok, loc = pcall(FDJ.LocalizeDungeonName, run.dungeon)
        if ok and type(loc) == "string" and loc ~= "" then return loc end
    end
    return run.dungeon or run.instanceName or "?"
end

local function BossLabel(name)
    if FDJ.LocalizeBossName then
        local ok, loc = pcall(FDJ.LocalizeBossName, name)
        if ok and type(loc) == "string" and loc ~= "" then return loc end
    end
    return name
end

local function RunStart(run)
    return run.startedAt or run.firstTrash or run.firstKill
end

-- Speed: first trash kill (or Pusillin conversation) to the final boss.
-- Returns seconds and whether the clock is still running.
local function Speed(run)
    local start = RunStart(run)
    if not start then return nil end
    local stop = run.finalKill or run.lastBoss
    if stop and stop < start then start = run.firstKill or start end
    if run.completed and stop then return stop - start, false end
    -- In progress, inside or stepped out (corpse run, vendor): the clock
    -- keeps going (2.0.4: outside it showed 0:00).
    if not run.closed and not run.completed then return math.max(0, Now() - start), true end
    -- 2.0.4: not finished (reset, left, ended by hand): until it ended.
    -- Runs saved before 2.0.4: until the last time inside, or the last kill.
    local ended = run.endedAt or run.lastSeen
    if not ended then
        for _, k in ipairs(run.kills or {}) do
            if type(k.t) == "number" and (not ended or k.t > ended) then ended = k.t end
        end
    end
    if ended and ended >= start then return ended - start, false end
    if stop then return stop - start, false end
    return nil
end

local function Status(run)
    if run.test then
        return (run.completed and L("RUNLOG_COMPLETED") or L("RUNLOG_IN_PROGRESS")) .. " (test)", 0.45, 0.75, 1.0
    end
    if run.completed then return L("RUNLOG_COMPLETED"), 0.25, 1.0, 0.35 end
    if not run.closed then return L("RUNLOG_IN_PROGRESS"), 1.0, 0.82, 0.27 end
    return L("RUNLOG_UNFINISHED"), 0.75, 0.42, 0.36
end

-- At the level cap (no XP to earn) the run shows the gold and silver it
-- earned instead, with the game's coin icons (copper left out).
local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
-- Which one the tracker and the run page show: gold at the level cap, XP
-- below it; a click on the tracker's XP/Gold flips it (both are always
-- counted, so nothing is lost either way).
local function MoneyView()
    ForeverDungeonJournalCharacterDB = ForeverDungeonJournalCharacterDB or {}
    local db = ForeverDungeonJournalCharacterDB
    if type(db.runTracker) ~= "table" then db.runTracker = {} end
    return db.runTracker
end
local function ShowsGold(run)
    if not run then return false end
    return run.capped and true or false
end
-- Gold and silver once there is a gold; below that, silver and copper.
local function GoldText(copper)
    copper = math.floor(tonumber(copper) or 0)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then return g .. GOLD_ICON .. " " .. s .. SILVER_ICON end
    if s > 0 then return s .. SILVER_ICON .. " " .. c .. COPPER_ICON end
    return c .. COPPER_ICON
end
FDJ.RunLogGoldText = GoldText

local function MobXP(run)
    local xp = 0
    for _, k in ipairs(run.kills or {}) do xp = xp + (k.x or 0) end
    return xp
end

local function TrashText(run)
    local api = FDJ.RunLog
    if not api then return "-" end
    -- a plain count: how much trash a dungeon holds isn't known yet, so
    -- no percentage
    return tostring(api.TrashKilled(run) or 0)
end

-- The chat line when the final boss dies.
function FDJ.RunLogSummary(run)
    local secs = Speed(run)
    local trash = TrashText(run)
    if not ShowsGold(run) then
        return L("RUNLOG_DONE", DungeonLabel(run), secs and Duration(secs) or "-", run.deaths or 0, trash or "-", Thousands(MobXP(run)))
    end
    -- at the level cap: the gold earned in place of "<n> XP"
    local text = L("RUNLOG_DONE", DungeonLabel(run), secs and Duration(secs) or "-", run.deaths or 0, trash or "-", "\001")
    local gold = GoldText(run.money)
    for _, word in ipairs({ "\001 XP", "\001 EP", "\001 PX", "\001 PE", "\001 опыта", "경험치 \001", "经验 \001", "經驗 \001" }) do
        local i, j = text:find(word, 1, true)
        if i then text = text:sub(1, i - 1) .. gold .. text:sub(j + 1) break end
    end
    local i = text:find("\001", 1, true)
    if i then text = text:sub(1, i - 1) .. gold .. text:sub(i + 1) end
    return text
end

-- ------------------------------------------------------------ widgets
local function Divider(parent)
    local d = CreateFrame("Frame", nil, parent)
    d:SetHeight(26)
    d.title = d:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    d.title:SetPoint("CENTER")
    d.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    d.left = d:CreateTexture(nil, "ARTWORK")
    d.left:SetColorTexture(0.54, 0.39, 0.17, 0.72)
    d.left:SetHeight(1)
    d.left:SetPoint("LEFT", 2, 0)
    d.left:SetPoint("RIGHT", d.title, "LEFT", -8, 0)
    d.right = d:CreateTexture(nil, "ARTWORK")
    d.right:SetColorTexture(0.54, 0.39, 0.17, 0.72)
    d.right:SetHeight(1)
    d.right:SetPoint("RIGHT", -2, 0)
    d.right:SetPoint("LEFT", d.title, "RIGHT", 8, 0)
    return d
end

local function Tile(parent)
    local t = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    t:SetHeight(50)
    t:SetBackdrop(BACKDROP)
    t:SetBackdropColor(0.12, 0.10, 0.07, 0.95)
    t:SetBackdropBorderColor(0.40, 0.32, 0.20, 1)
    t.label = t:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    t.label:SetPoint("TOPLEFT", 10, -8)
    t.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    t.value = t:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightLarge")
    t.value:SetPoint("BOTTOMLEFT", 10, 8)
    t.extra = t:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    t.extra:SetPoint("BOTTOMRIGHT", -10, 10)
    t.extra:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    t:EnableMouse(true)
    t:SetScript("OnEnter", function(self)
        if not self.tipTitle then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tipTitle, GOLD[1], GOLD[2], GOLD[3])
        for _, line in ipairs(self.tipLines or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return t
end

local function Line(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(22)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, 0.035)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16)
    r.icon:SetPoint("LEFT", 6, 0)
    r.left = r:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    r.left:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.left:SetJustifyH("LEFT")
    r.right = r:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    r.right:SetPoint("RIGHT", -8, 0)
    r.right:SetJustifyH("RIGHT")
    r.mid = r:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    r.mid:SetPoint("RIGHT", -96, 0)
    r.mid:SetJustifyH("RIGHT")
    r.mid:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    r.left:SetPoint("RIGHT", r.mid, "LEFT", -8, 0)
    return r
end

local function ItemCard(parent)
    local c = CreateFrame("Button", nil, parent, "BackdropTemplate")
    c:SetHeight(44)
    c:SetBackdrop(BACKDROP)
    c:SetBackdropColor(0.12, 0.10, 0.07, 0.95)
    c:SetBackdropBorderColor(0.40, 0.32, 0.20, 1)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(30, 30)
    c.icon:SetPoint("LEFT", 7, 0)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.name = c:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 7, -1)
    c.name:SetPoint("RIGHT", -6, 0)
    c.name:SetJustifyH("LEFT")
    c.name:SetWordWrap(false)
    c.result = c:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    c.result:SetPoint("BOTTOMLEFT", c.icon, "BOTTOMRIGHT", 7, 1)
    c:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    c:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
        if FDJ.RunLogAddRolls then FDJ.RunLogAddRolls(self.rolls, self.winner) end -- rollhistory (2.0.9)
        GameTooltip:Show()
        self.fdjShift = nil
        -- No automatic "Equipped" comparison here (even with the game's
        -- Always Compare Items on): it shows only while Shift is held, or
        -- always with Options > Auto Item Comparison (autocompare, 2.0.6).
        self:SetScript("OnUpdate", function(card)
            if GameTooltip:GetOwner() ~= card then return end
            local shift = (IsShiftKeyDown and IsShiftKeyDown())
                or (ForeverDungeonJournalDB and ForeverDungeonJournalDB.autoCompare == true) or false
            if shift then
                if not card.fdjShift and GameTooltip_ShowCompareItem then
                    pcall(GameTooltip_ShowCompareItem, GameTooltip)
                end
            else
                if ShoppingTooltip1 and ShoppingTooltip1:IsShown() then ShoppingTooltip1:Hide() end
                if ShoppingTooltip2 and ShoppingTooltip2:IsShown() then ShoppingTooltip2:Hide() end
            end
            card.fdjShift = shift
        end)
    end)
    c:SetScript("OnLeave", function(self)
        self:SetScript("OnUpdate", nil)
        GameTooltip:Hide()
    end)
    c:SetScript("OnClick", function(self)
        if self.link and HandleModifiedItemClick then pcall(HandleModifiedItemClick, self.link) end
    end)
    return c
end

local function Pool(win, kind, maker, parent)
    win.pools = win.pools or {}
    local p = win.pools[kind]
    if not p then p = { used = 0, items = {} } win.pools[kind] = p end
    p.used = p.used + 1
    local w = p.items[p.used]
    if not w then
        w = maker(parent)
        p.items[p.used] = w
    end
    w:ClearAllPoints()
    w:Show()
    return w
end

local function ResetPools(win)
    for _, p in pairs(win.pools or {}) do
        for i = 1, #p.items do p.items[i]:Hide() end
        p.used = 0
    end
end

-- The run's bosses in the journal's order (killed or not, rares only once
-- killed), then any other boss that died. { boss = <journal record>, kill = k }
-- Runs recorded while the dungeon wasn't recognised (e.g. The Drowned City
-- before 2.0.18) only have the game's instance name: find the dungeon now.
function FDJ.RunLogFixDungeon(run)
    -- Older Shaper's Terrace runs can carry the raw instance name
    -- "The Shaper's Terrace", which isn't the journal's canonical DB key.
    -- Recover both missing and unrecognized dungeon keys without changing
    -- runs that already have valid boss data.
    -- 2.0.3: by the instance ID first, the same on every client language
    -- (a German Drowned City run only has "Die Versunkene Stadt").
    if run and (not run.dungeon or not (FDJ.DB and FDJ.DB[run.dungeon])) and run.map
        and FDJ.INSTANCE_ID_TO_DUNGEON then
        local key = FDJ.INSTANCE_ID_TO_DUNGEON[tonumber(run.map) or -1]
        if key and key ~= "Scarlet Monastery" and FDJ.DB and FDJ.DB[key] then run.dungeon = key end
    end
    if run and (not run.dungeon or not (FDJ.DB and FDJ.DB[run.dungeon]))
        and FDJ.DungeonFromInstanceName then
        local name = run.instanceName or run.dungeon
        if type(name) == "string" then
            local ok, key = pcall(FDJ.DungeonFromInstanceName, name)
            if ok and key then run.dungeon = key end
        end
    end
    return run and run.dungeon
end

local FIGHT_PLACEHOLDERS = {} -- ringoflaw: the fight's entry before its boss is known
-- logfaction (2.1.3, M: "can we just not have the lost dwarves show in the
-- alliance char log?"): a boss only the other faction can fight
-- (factionOnly: The Lost Dwarves, friendly to the Alliance) isn't listed
-- in a run's bosses. The log is the character's own, so its faction is
-- the character's. Still listed if the log has its kill.
local function LogFaction()
    if type(UnitFactionGroup) ~= "function" then return nil end
    local ok, faction = pcall(UnitFactionGroup, "player")
    if not ok or type(faction) ~= "string" then return nil end
    if type(issecretvalue) == "function" and issecretvalue(faction) then return nil end
    return faction
end

local function BossList(run)
    FDJ.RunLogFixDungeon(run)
    local faction = LogFaction() -- logfaction
    local killed = {}
    for _, k in ipairs(run.kills or {}) do
        if k.b and not killed[k.b] then killed[k.b] = k end
    end
    local list, shown, rares, groups = {}, {}, {}, {}
    local d = run.dungeon and FDJ.DB and FDJ.DB[run.dungeon]
    for _, b in ipairs((d and d.bosses) or {}) do
        -- altarbosses (2.0.24): a journal group and its children are not
        -- listed among a run's bosses (their kills are trash, as before).
        if type(b) == "table" and type(b.name) == "string" and type(b.factionOnly) == "string"
            and faction and b.factionOnly ~= faction and not killed[b.name] then
            shown[b.name] = true -- logfaction: the other faction's boss
        elseif type(b) == "table" and type(b.name) == "string" and b.runLogHidden then
            -- felsteedoff (2.0.7): not one of a run's bosses (the Shadowfang
            -- Keep horses); an older run's kill of it isn't listed either.
            shown[b.name] = true
        elseif type(b) == "table" and not b.trash and not b.recipeTab and type(b.name) == "string"
            and not b.childOf and not b.children then
            shown[b.name] = true
            if type(b.fightGroup) == "string" then
                -- ringoflaw (2.0.4): one entry for the fight; it shows the boss
                -- that came (killed, else targeted) once that is known.
                local g = groups[b.fightGroup]
                if not g then
                    g = { group = b.fightGroup, members = {} }
                    groups[b.fightGroup] = g
                    shown[b.fightGroup] = true
                    list[#list + 1] = g
                end
                g.members[#g.members + 1] = b
                if killed[b.name] and not g.kill then g.kill, g.boss = killed[b.name], b end
            elseif b.trackerOnlyIfKilled and not killed[b.name] then
                -- optional (Princess Moira): listed only once killed
            else
                local e = { boss = b, kill = killed[b.name], seen = run.rareSeen and run.rareSeen[b.name] }
                -- Rares come after the bosses.
                if b.rare then rares[#rares + 1] = e else list[#list + 1] = e end
            end
        end
    end
    for name, g in pairs(groups) do
        local pick = run.groupPick and run.groupPick[name]
        if not g.boss and pick then
            for _, m in ipairs(g.members) do if m.name == pick then g.boss = m end end
        end
        g.kill = g.kill or killed[name]
        if not g.boss then
            FIGHT_PLACEHOLDERS[name] = FIGHT_PLACEHOLDERS[name] or { name = name, fightPlaceholder = true }
            g.boss = FIGHT_PLACEHOLDERS[name]
        end
    end
    for _, e in ipairs(rares) do list[#list + 1] = e end
    for _, k in ipairs(run.kills or {}) do
        if k.b and not shown[k.b] then
            shown[k.b] = true
            list[#list + 1] = { boss = { name = k.b }, kill = k }
        end
    end
    return list
end

-- A boss portrait (the journal's own) with a dark veil and a red X once killed.
local DIM_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local KILLED_X = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local function Portrait(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.dim = f:CreateTexture(nil, "OVERLAY")
    f.dim:SetAllPoints()
    f.dim:SetTexture(DIM_MASK)
    f.dim:SetVertexColor(0, 0, 0, 0.55)
    f.x = f:CreateTexture(nil, "OVERLAY", nil, 2)
    f.x:SetTexture(KILLED_X)
    f.x:SetPoint("CENTER")
    f.x:SetSize(math.floor(size * 0.7), math.floor(size * 0.7))
    -- A rare's silver dragon frame: the same art as the journal's boss list.
    f.ring = f:CreateTexture(nil, "OVERLAY", nil, 1)
    f.ring:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\RarePortraitDragonFrame.tga")
    f.ring:SetPoint("CENTER")
    f.ring:SetSize(math.floor(size * 64 / 44), math.floor(size * 64 / 44))
    f.ring:Hide()
    return f
end

local function SetPortrait(f, dungeon, boss, killed)
    if f.boss ~= boss then
        local old = f.tex.fdjPooled
        if old then old:SetDesaturated(false) end
        f.boss = boss
        local ok, shown = false, false
        if FDJ.SetBossPortrait and boss then ok, shown = pcall(FDJ.SetBossPortrait, f.tex, dungeon, boss) end
        if not (ok and shown) then
            if FDJ.ReleasePortrait then pcall(FDJ.ReleasePortrait, f.tex) end
            f.tex:SetTexture(SKULL)
            f.tex:SetTexCoord(0, 1, 0, 1)
        end
    end
    killed = killed and true or false
    f.tex:SetDesaturated(killed)
    -- The journal's portraits are drawn on a pooled texture laid over ours.
    if f.tex.fdjPooled then f.tex.fdjPooled:SetDesaturated(killed) end
    f.dim:SetShown(killed)
    f.x:SetShown(killed)
end

local function BossLine(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(34)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, 0.035)
    r.portrait = Portrait(r, 30)
    r.portrait:SetPoint("LEFT", 3, 0)
    r.left = r:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    r.left:SetPoint("LEFT", r.portrait, "RIGHT", 8, 0)
    r.left:SetJustifyH("LEFT")
    r.right = r:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    r.right:SetPoint("RIGHT", -8, 0)
    r.right:SetJustifyH("RIGHT")
    r.mid = r:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    r.mid:SetPoint("RIGHT", -96, 0)
    r.mid:SetJustifyH("RIGHT")
    r.mid:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    r.left:SetPoint("RIGHT", r.mid, "LEFT", -8, 0)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self) FDJ.RunLogBossTooltip(self, self.boss, self.kill, self.runStart) end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

-- rollhistory (2.0.9, M 16 Nov 2026): everyone's rolls on an item under
-- its tooltip, highest first: the dice (Need) or the coin (Greed), the
-- name (you in green, the winner in gold) and the number.
local function IsYou(name)
    local me = UnitName and UnitName("player")
    return type(name) == "string" and type(me) == "string" and (name == me or name:lower() == me:lower()
        or name == (_G.YOU or "You") or name:lower():sub(1, #me + 1) == me:lower() .. "-")
end
function FDJ.RunLogAddRolls(rolls, winner, indent)
    if type(rolls) ~= "table" or #rolls == 0 then return end
    if not indent then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("RUNLOG_ROLLS"), GOLD[1], GOLD[2], GOLD[3])
    end
    for _, r in ipairs(rolls) do
        local mark = r.k == "need" and "|TInterface\\Buttons\\UI-GroupLoot-Dice-Up:14:14:0:0|t "
            or r.k == "greed" and "|TInterface\\Buttons\\UI-GroupLoot-Coin-Up:14:14:0:0|t " or ""
        local name = r.name or "?"
        local cr, cg, cb = 0.85, 0.85, 0.85
        if IsYou(name) then cr, cg, cb = 0.25, 1.0, 0.35 end
        if winner and type(name) == "string" and name:lower() == tostring(winner):lower() then cr, cg, cb = 1.0, 0.82, 0.0 end
        GameTooltip:AddDoubleLine((indent and "     " or "") .. mark .. name, tostring(r.n or "-"), cr, cg, cb, 1, 1, 1)
    end
end

-- Hover a boss: what it dropped (and who got it), or that it is still alive.
local function BossTooltip(owner, boss, kill, start, onTracker)
    if not boss then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(BossLabel(boss.name), GOLD[1], GOLD[2], GOLD[3])
    if not kill then
        -- 2.0.4: the tracker's boss portraits show just the name until killed
        if not onTracker then
            GameTooltip:AddLine(owner.notFound and L("RUNLOG_NOT_FOUND") or L("RUNLOG_NOT_KILLED"), 0.75, 0.72, 0.66)
        end
    else
        GameTooltip:AddLine("+" .. Duration(kill.t - (start or kill.t)), 0.25, 1.0, 0.35) -- killed: green
        local loot = kill.loot or {}
        if #loot == 0 then
            GameTooltip:AddLine(L("RUNLOG_NO_LOOT"), 0.75, 0.72, 0.66)
        end
        for _, e in ipairs(loot) do
            local icon = e.id and ((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id)) or (GetItemIcon and GetItemIcon(e.id)))
            local text = (icon and ("|T" .. icon .. ":16:16:0:0|t ") or "") .. (e.link or ("item " .. tostring(e.id)))
            if e.w then
                local roll = e.r == "need" and "|TInterface\\Buttons\\UI-GroupLoot-Dice-Up:16:16:0:0|t "
                    or e.r == "greed" and "|TInterface\\Buttons\\UI-GroupLoot-Coin-Up:16:16:0:0|t " or ""
                GameTooltip:AddDoubleLine(text, roll .. e.w .. (e.n and ("  |cffffffff" .. e.n .. "|r") or ""), 1, 1, 1, 0.75, 0.72, 0.66)
            else
                GameTooltip:AddLine(text, 1, 1, 1)
            end
            -- rollhistory (2.0.9): the others' rolls under it (when more than the winner's)
            if type(e.rolls) == "table" and #e.rolls > 1 then FDJ.RunLogAddRolls(e.rolls, e.w, true) end
        end
    end
    -- 2.0.4: the tracker's boss portraits open the boss's loot on a click
    if onTracker and FDJ.TrackerBossLoot and #FDJ.TrackerBossLoot(boss) > 0 then
        GameTooltip:AddLine(L("TRACKER_SHOW_LOOT"), 1, 0.82, 0)
    end
    GameTooltip:Show()
    if FDJ.RefreshTooltipBacking then FDJ.RefreshTooltipBacking() end
end
FDJ.RunLogBossTooltip = BossTooltip

local function RunInProgress(run)
    return run and not run.closed and not run.completed
end

-- ------------------------------------------------------------ detail page
-- The dungeon card's art (the journal's home page) behind the run, faint
-- enough to read over: the middle of the picture, cut to the pane's shape.
local ART_ALPHA = 0.22
local function SetRunArt(win, run)
    local tex = win.art
    if not tex then return end
    local art = run and run.dungeon and FDJ.DUNGEON_HOME_ART and FDJ.DUNGEON_HOME_ART[run.dungeon]
    if not art then tex:Hide() return end
    tex:SetTexture(art)
    -- The addon's own card pictures are 2:1, the game's loading screens 4:3.
    local src = (type(art) == "string" and art:find("ForeverDungeonJournal", 1, true)) and 2 or (4 / 3)
    -- Only the band the card itself shows: the loading screens have the
    -- World of Warcraft logo at the top and the loading bar at the bottom.
    local crop = FDJ.DUNGEON_HOME_TEXCOORD and FDJ.DUNGEON_HOME_TEXCOORD[run.dungeon] or { 0.03, 0.97, 0.05, 0.95 }
    local l, r, t, b = crop[1], crop[2], crop[3], crop[4]
    local w, h = tex:GetWidth() or 0, tex:GetHeight() or 0
    if w < 10 or h < 10 then w, h = 470, 400 end
    local pane = w / h
    -- the band's width (as a share of the picture) at the pane's shape
    local need = pane * (b - t) / src
    if need <= r - l then
        local mid = (l + r) / 2
        tex:SetTexCoord(mid - need / 2, mid + need / 2, t, b)
    else
        local tall = (r - l) * src / pane
        local mid = (t + b) / 2
        tex:SetTexCoord(l, r, mid - tall / 2, mid + tall / 2)
    end
    tex:SetVertexColor(1, 1, 1)
    tex:SetAlpha(ART_ALPHA)
    tex:Show()
end

-- A scroll bar only when there is something to scroll.
local function FitScrollBar(scroll)
    local bar = scroll and scroll.ScrollBar
    if not bar then return end
    local range = scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange() or 0
    local need = (range or 0) > 0.5
    bar:SetShown(need)
    if not need and scroll:GetVerticalScroll() ~= 0 then scroll:SetVerticalScroll(0) end
    if scroll.fdjOnBar and scroll.fdjBar ~= need then
        scroll.fdjBar = need
        scroll.fdjOnBar(need)
    end
end
local function AutoScrollBar(scroll)
    if not scroll then return end
    scroll.scrollBarHideable = true
    scroll:HookScript("OnScrollRangeChanged", function(self) FitScrollBar(self) end)
    scroll:HookScript("OnSizeChanged", function(self) FitScrollBar(self) end)
end

local function RefreshDetail(win)
    local content = win.detail
    ResetPools(win)
    local run = win.selected
    SetRunArt(win, run)
    local width = math.max(300, (win.detailScroll:GetWidth() or 420) - 6)
    content:SetWidth(width)
    if not run then
        win.title:SetText("")
        win.sub:SetText("")
        if win.money then win.money:Hide() end
        if win.trackButton then win.trackButton:Hide() end
        if win.partyButton then win.partyButton:Hide() end
        content:SetHeight(1)
        return
    end

    win.title:SetText(DungeonLabel(run))
    if win.trackButton then
        win.trackButton:SetShown(RunInProgress(run))
        win.trackButton:SetText(FDJ.IsRunTrackerOn and FDJ.IsRunTrackerOn() and L("RUNLOG_UNTRACK") or L("RUNLOG_TRACK"))
    end
    -- Money earned, top right (under Track on screen while that shows).
    if not win.money then
        win.money = content:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
        win.money:SetJustifyH("RIGHT")
    end
    win.money:ClearAllPoints()
    if win.trackButton and win.trackButton:IsShown() then
        win.money:SetPoint("TOPRIGHT", win.trackButton, "BOTTOMRIGHT", -2, -5)
    else
        win.money:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -12)
    end
    if run.money ~= nil then
        win.money:SetText("|cffa59b8b" .. L("RUNLOG_MONEY") .. "|r  " .. GoldText(run.money))
        win.money:Show()
    else
        win.money:Hide()
    end
    if FDJ.RunLogPartyButton then FDJ.RunLogPartyButton(win, content, run) end
    local status, sr, sg, sb = Status(run)
    win.sub:SetText(FDJ.RunLogDate(run.created, true) .. "   |cff" ..
        string.format("%02x%02x%02x", sr * 255, sg * 255, sb * 255) .. status .. "|r")

    local y = 54
    local half = math.floor((width - 8) / 2)

    -- Stat tiles, two to a row.
    local secs, running = Speed(run)
    local trashPct, trashOf = TrashText(run), nil
    local tiles = {
        { L("RUNLOG_TIME"), secs and Duration(secs) or "-", running and L("RUNLOG_RUNNING") or nil, L("RUNLOG_TIME"), { L("RUNLOG_TIME_TIP") } },
        { L("RUNLOG_DEATHS"), tostring(run.deaths or 0), nil, nil, nil },
        { L("RUNLOG_TRASH"), trashPct or "-", trashOf, L("RUNLOG_TRASH"), { L("RUNLOG_TRASH_TIP") } },
        ShowsGold(run) and { L("RUNLOG_GOLD"), GoldText(run.money), nil, nil, nil }
            or { L("RUNLOG_XP"), Thousands(MobXP(run)), nil, nil, nil },
    }
    local start = RunStart(run) or run.created
    if (run.deaths or 0) > 0 and run.deathTimes then
        local lines = {}
        for _, t in ipairs(run.deathTimes) do
            lines[#lines + 1] = L("RUNLOG_DIED_AT", (t >= start and "+" or "-") .. Duration(math.abs(t - start)))
        end
        tiles[2][4], tiles[2][5] = L("RUNLOG_DEATHS"), lines
    end
    for i, def in ipairs(tiles) do
        local t = Pool(win, "tile", Tile, content)
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        t:SetPoint("TOPLEFT", content, "TOPLEFT", col * (half + 8), -(y + row * 58))
        t:SetWidth(half)
        t.label:SetText(def[1])
        t.value:SetText(def[2])
        t.extra:SetText(def[3] or "")
        t.tipTitle, t.tipLines = def[4], def[5]
    end
    y = y + 2 * 58 + 6

    local function Section(title)
        local d = Pool(win, "divider", Divider, content)
        d:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        d:SetWidth(width)
        d.title:SetText(title)
        y = y + 28
    end
    local function Row(icon, left, mid, right, r, g, b)
        local line = Pool(win, "line", Line, content)
        line:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        line:SetWidth(width)
        line.icon:SetTexture(icon)
        line.icon:SetDesaturated(false)
        line.icon:SetShown(icon ~= nil)
        line.left:SetText(left or "")
        line.left:SetTextColor(r or 1, g or 1, b or 1)
        line.mid:SetText(mid or "")
        line.right:SetText(right or "")
        y = y + 24
        return line
    end
    local function Note(text)
        local line = Row(nil, text)
        line.left:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    end

    -- Bosses: the journal's bosses in order (killed or not), then rares
    -- killed. Killed ones: portrait greyed with an X.
    Section(L("RUNLOG_BOSSES"))
    for _, e in ipairs(BossList(run)) do
        local line = Pool(win, "boss", BossLine, content)
        line:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        line:SetWidth(width)
        local b, k = e.boss, e.kill
        SetPortrait(line.portrait, run.dungeon, b, k ~= nil)
        line.portrait.ring:SetShown(b.rare and true or false)
        line.boss, line.kill, line.runStart = b, k, start
        line.notFound = b.rare and not e.seen and not k
        -- A rare not found in this run stays see-through, like on the tracker.
        line:SetAlpha(line.notFound and 0.45 or 1)
        line.left:SetText(BossLabel(b.name) .. (b.rare and ("  |cffffd100" .. L("RUNLOG_RARE") .. "|r") or ""))
        if k then
            line.left:SetTextColor(1, 1, 1)
            line.mid:SetText("+" .. Duration(k.t - start))
            line.right:SetText(k.x and (Thousands(k.x) .. " XP") or "-")
        else
            line.left:SetTextColor(0.62, 0.58, 0.52)
            -- A rare nobody came across in this run: "not found".
            line.mid:SetText((b.rare and not e.seen) and L("RUNLOG_NOT_FOUND") or L("RUNLOG_NOT_KILLED"))
            line.right:SetText("")
        end
        y = y + 36
    end
    -- Trash, one line per kind of mob.
    Section(L("RUNLOG_TRASH_MOBS"))
    local byName, order = {}, {}
    for _, k in ipairs(run.kills or {}) do
        -- (a boss's fight partners, and a boss whose partners still live, aren't trash)
        if not k.b and not k.wb and not k.p then
            local name = k.m or (FDJ.RunLog and FDJ.RunLog.NpcName(k.n)) or (UNKNOWNOBJECT or "?")
            local e = byName[name]
            if not e then
                e = { name = name, count = 0, xp = 0 }
                byName[name] = e
                order[#order + 1] = e
            end
            e.count = e.count + 1
            e.xp = e.xp + (k.x or 0)
        end
    end
    table.sort(order, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    if #order == 0 then Note(L("RUNLOG_NO_TRASH")) end
    for _, e in ipairs(order) do
        Row(nil, e.name, "x" .. e.count, e.xp > 0 and (Thousands(e.xp) .. " XP") or "-")
    end

    -- Need rolls, two cards to a row.
    Section(L("RUNLOG_NEED"))
    local needs = run.needs or {}
    if #needs == 0 then Note(L("RUNLOG_NO_NEED")) end
    for i, need in ipairs(needs) do
        local c = Pool(win, "item", ItemCard, content)
        local col = (i - 1) % 2
        c:SetPoint("TOPLEFT", content, "TOPLEFT", col * (half + 8), -y)
        c:SetWidth(half)
        c.link = need.link
        c.rolls, c.winner = need.rolls, nil -- rollhistory (2.0.9): everyone's rolls in its tooltip
        for _, r in ipairs(need.rolls or {}) do
            if need.res == "won" and IsYou(r.name) then c.winner = r.name end
        end
        if need.res == "lost" and need.rolls and need.rolls[1] then c.winner = need.rolls[1].name end
        local icon = need.id and ((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(need.id)) or (GetItemIcon and GetItemIcon(need.id)))
        c.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local name = type(need.link) == "string" and need.link:match("%[(.-)%]") or ("item " .. tostring(need.id))
        -- The item's own quality colour (name and card border).
        local r, g, bl = FDJ.RunLogItemColor(need.id, need.link)
        c.name:SetText(name)
        c.name:SetTextColor(r, g, bl)
        c:SetBackdropBorderColor(r * 0.8, g * 0.8, bl * 0.8, 1)
        if need.res == "won" then
            -- the dice and the number rolled (runs from before 1.7.5: dice only)
            c.result:SetText("|cff40ff59" .. L("RUNLOG_WON") .. "|r  |TInterface\\Buttons\\UI-GroupLoot-Dice-Up:14:14:0:0|t"
                .. (need.n and (" |cffffffff" .. need.n .. "|r") or ""))
        elseif need.res == "lost" then
            -- rollhistory (2.0.9): what you rolled when you lost too
            c.result:SetText("|cffff5a4a" .. L("RUNLOG_LOST") .. "|r"
                .. (need.n and ("  |TInterface\\Buttons\\UI-GroupLoot-Dice-Up:14:14:0:0|t |cffffffff" .. need.n .. "|r") or ""))
        else
            c.result:SetText("|cffffd145" .. L("RUNLOG_ROLLING") .. "|r")
        end
        if col == 1 or i == #needs then y = y + 50 end
    end

    -- Time outside: corpse runs and trips out (not the walk out after the
    -- final boss: the run was over by then).
    local exits = {}
    for _, e in ipairs(run.exits or {}) do
        if not (run.finalKill and e.t >= run.finalKill) then exits[#exits + 1] = e end
    end
    if #exits > 0 then
        Section(L("RUNLOG_OUTSIDE"))
        for _, e in ipairs(exits) do
            local label = e.why == "released" and L("RUNLOG_RELEASED") or L("RUNLOG_STEPPED")
            local away
            if e.back then away = Duration(e.back - e.t)
            elseif not run.closed then
                label = label .. "  |cffffd145(" .. L("RUNLOG_STILL_OUT") .. ")|r"
                away = Duration(Now() - e.t)
            else away = "-" end
            local line = Row(e.why == "released" and "Interface\\Icons\\Spell_Holy_GuardianSpirit" or "Interface\\Icons\\Spell_Arcane_PortalDalaran",
                label, (e.t >= start and "+" or "-") .. Duration(math.abs(e.t - start)), away)
            -- Death Walk: the Spirit Healer's portrait (creature display 5233)
            if e.why == "released" and SetPortraitTextureFromCreatureDisplayID then
                -- allbaked (2.0.9): the bundled picture when there is one (no
                -- render target for every death in the list)
                if not (FDJ.SetBakedPortrait and FDJ.SetBakedPortrait(line.icon, 5233)) then
                    pcall(SetPortraitTextureFromCreatureDisplayID, line.icon, 5233)
                end
            end
        end
    end

    content:SetHeight(math.max(1, y + 8))
    FitScrollBar(win.detailScroll)
end

-- ------------------------------------------------------------ run list
-- Party: a small button next to the dungeon's name; clicking it opens a
-- list of who did the run, in class colours (runs recorded from 1.7.5 on).
function FDJ.RunLogPartyButton(win, content, run)
    local b = win.partyButton
    if not b then
        b = CreateFrame("Button", nil, win.title:GetParent() or content, "UIPanelButtonTemplate")
        FDJ.OwnFonts(b) -- ownfonts (2.0.8)
        win.partyButton = b
        b:SetSize(64, 20)
        local list = CreateFrame("Frame", nil, b, "BackdropTemplate")
        b.list = list
        list:SetFrameStrata("TOOLTIP")
        list:SetBackdrop(BACKDROP)
        list:SetBackdropColor(0.055, 0.05, 0.043, 0.98)
        list:SetBackdropBorderColor(0.57, 0.43, 0.20, 1)
        list:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -4)
        list.text = list:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
        list.text:SetPoint("TOPLEFT", 10, -9)
        list.text:SetJustifyH("LEFT")
        list.text:SetSpacing(3)
        list:EnableMouse(true)
        list:SetScript("OnMouseUp", function(self) self:Hide() end)
        list:Hide()
        b:SetScript("OnClick", function(self) self.list:SetShown(not self.list:IsShown()) end)
        b:SetScript("OnHide", function(self) self.list:Hide() end)
    end
    b.list:Hide()
    local names = {}
    for name, class in pairs(type(run.party) == "table" and run.party or {}) do
        names[#names + 1] = { name, class }
    end
    if #names == 0 then b:Hide() return end
    local me = UnitName and UnitName("player")
    table.sort(names, function(x, y)
        if x[1] == me then return true elseif y[1] == me then return false end
        return x[1] < y[1]
    end)
    local lines = {}
    for _, e in ipairs(names) do
        local c = type(e[2]) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e[2]]
        lines[#lines + 1] = c and string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, e[1]) or e[1]
    end
    b.list.text:SetText(table.concat(lines, "\n"))
    b.list:SetSize(math.max(120, (b.list.text:GetStringWidth() or 0) + 20), (b.list.text:GetStringHeight() or 0) + 18)
    b:SetText(L("RUNLOG_PARTY"))
    b:SetWidth(math.max(64, (b:GetFontString() and b:GetFontString():GetStringWidth() or 40) + 24))
    b:ClearAllPoints()
    b:SetPoint("LEFT", win.title, "RIGHT", 12, 0)
    b:Show()
end

local function ListRow(parent, win)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(42)
    r:RegisterForClicks("LeftButtonUp")
    r.sel = r:CreateTexture(nil, "BACKGROUND")
    r.sel:SetAllPoints()
    r.sel:SetColorTexture(1.0, 0.82, 0.27, 0.14)
    r.sel:Hide()
    r.name = r:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    r.name:SetPoint("TOPLEFT", 8, -6)
    r.name:SetPoint("RIGHT", -30, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.info = r:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    r.info:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
    r.info:SetPoint("RIGHT", -30, 0)
    r.info:SetWordWrap(false)
    r.info:SetJustifyH("LEFT")
    r.info:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    r.line = r:CreateTexture(nil, "ARTWORK")
    r.line:SetColorTexture(0.54, 0.39, 0.17, 0.35)
    r.line:SetHeight(1)
    r.line:SetPoint("BOTTOMLEFT", 4, 0)
    r.line:SetPoint("BOTTOMRIGHT", -4, 0)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    r:SetScript("OnClick", function(self)
        if not self.run then return end
        win.selected = self.run
        FDJ.RefreshRunLog()
    end)
    -- Red X on the right: delete the run (asks first).
    local del = CreateFrame("Button", nil, r, "BackdropTemplate")
    del:SetSize(22, 22)
    del:SetPoint("RIGHT", -6, 0)
    del:SetFrameLevel(r:GetFrameLevel() + 2)
    del:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    del:SetBackdropColor(0.10, 0.08, 0.06, 0.95)
    del:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
    -- The killed-boss X (same picture, same weight), with a thin white
    -- outline: grey copies a pixel off in every direction, added together.
    for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 } }) do
        local e = del:CreateTexture(nil, "ARTWORK", nil, 1)
        e:SetTexture(KILLED_X)
        e:SetSize(16, 16)
        e:SetPoint("CENTER", o[1], o[2])
        e:SetDesaturated(true)
        e:SetBlendMode("ADD")
        e:SetAlpha(0.55)
    end
    del.tex = del:CreateTexture(nil, "ARTWORK", nil, 2)
    del.tex:SetSize(16, 16)
    del.tex:SetPoint("CENTER")
    del.tex:SetTexture(KILLED_X)
    del.tex:SetAlpha(1)
    del:SetScript("OnEnter", function(self)
        self.tex:SetAlpha(1)
        self:SetBackdropBorderColor(0.85, 0.25, 0.20, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L("RUNLOG_DEL"), 1, 0.35, 0.3)
        GameTooltip:Show()
    end)
    del:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
        GameTooltip:Hide()
    end)
    del:SetScript("OnClick", function()
        if not r.run then return end
        local dialog = StaticPopup_Show and StaticPopup_Show("FDJ_RUNLOG_DELETE", L("RUNLOG_DELETE", DungeonLabel(r.run)))
        if dialog then dialog.data = r.run end
    end)
    r.del = del
    return r
end

local function RefreshList(win)
    local runs = FDJ.RunLogListRuns()
    -- Without a scroll bar the runs reach the line between the two sides.
    local need = #runs * 44 > (win.listScroll:GetHeight() or 0) + 1
    if win.listScroll.fdjBar ~= need then
        win.listScroll.fdjBar = need
        win.listScroll.fdjOnBar(need)
    end
    if win.listScroll.ScrollBar then win.listScroll.ScrollBar:SetShown(need) end
    local width = win.list:GetWidth()
    win.rows = win.rows or {}
    local n = 0
    for i = #runs, 1, -1 do
        local run = runs[i]
        n = n + 1
        local r = win.rows[n]
        if not r then
            r = ListRow(win.list, win)
            win.rows[n] = r
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", win.list, "TOPLEFT", 0, -(n - 1) * 44)
        r:SetWidth(width)
        r.run = run
        r.name:SetText(DungeonLabel(run))
        local status, sr, sg, sb = Status(run)
        local secs = Speed(run)
        r.info:SetText(FDJ.RunLogDate(run.created) .. (secs and ("  |cffffffff" .. Duration(secs) .. "|r") or "") .. -- the run's time in white
            "  |cff" .. string.format("%02x%02x%02x", sr * 255, sg * 255, sb * 255) .. status .. "|r")
        r.sel:SetShown(win.selected == run)
        r:Show()
    end
    for i = n + 1, #(win.rows) do win.rows[i]:Hide() end
    win.list:SetHeight(math.max(1, n * 44))
    FitScrollBar(win.listScroll)
    win.empty:SetShown(n == 0)
    win.detailScroll:SetShown(n > 0)
    win.title:SetShown(n > 0)
    win.sub:SetShown(n > 0)
end

-- ------------------------------------------------------------ window
local LIST_W, LIST_BAR = 206, 26  -- the run list, and the room for its scroll bar
local function CreateWindow()
    local win
    for _, template in ipairs({ "ButtonFrameTemplate", "PortraitFrameTemplate", "BasicFrameTemplateWithInset" }) do
        local ok, created = pcall(CreateFrame, "Frame", "ForeverDungeonJournalRunLog", UIParent, template)
        if ok and created then win = created break end
    end
    if not win then
        win = CreateFrame("Frame", "ForeverDungeonJournalRunLog", UIParent, "BackdropTemplate")
        win:SetBackdrop(BACKDROP)
        win:SetBackdropColor(0.08, 0.07, 0.06, 0.97)
        win:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
    end
    local close = win.CloseButton or win.closeButton
        or (win.TitleContainer and win.TitleContainer.CloseButton)
        or (win.BorderBox and win.BorderBox.CloseButton)
    if not close then
        close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -3, -3)
    end
    -- A plain Hide(): the stock one goes through HideUIPanel, blocked in combat.
    close:SetScript("OnClick", function() win:Hide() end)

    win:SetSize(720, 480)
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    win:SetFrameStrata("FULLSCREEN_DIALOG")
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    if UISpecialFrames then tinsert(UISpecialFrames, "ForeverDungeonJournalRunLog") end

    local title = win.TitleText or (win.TitleContainer and win.TitleContainer.TitleText)
    if not title then
        title = win:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
        title:SetPoint("TOP", 0, -6)
    end
    win.windowTitle = title
    FDJ.OwnFonts(title) -- ownfonts (2.0.8): the window template's title text

    local portrait = win.portrait or (win.PortraitContainer and win.PortraitContainer.portrait)
    if portrait then
        win.playerPortrait = portrait
        PlayerPortrait(portrait)
    end

    local inset = win.Inset or win
    -- exporttitle (2.1.1, M 20 Nov 2026): the Export button left the Character
    -- Logs for the journal's title bar, left of Report (Systems/BugReport.lua).
    -- Left: the runs.
    local listScroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
    win.listScroll = listScroll
    listScroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 6, -6)
    listScroll:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 6, 6)
    listScroll:SetWidth(LIST_W)
    local list = CreateFrame("Frame", nil, listScroll)
    list:SetSize(200, 1)
    listScroll:SetScrollChild(list)
    list:SetWidth(LIST_W)
    -- The list is as wide as the space up to the line, less the scroll bar
    -- when there is one.
    listScroll.fdjOnBar = function(bar)
        local w = bar and LIST_W or (LIST_W + LIST_BAR - 1)
        listScroll:SetWidth(w)
        list:SetWidth(w)
        for _, r in ipairs(win.rows or {}) do r:SetWidth(w) end
    end
    AutoScrollBar(listScroll)
    win.list = list

    local sep = win:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.54, 0.39, 0.17, 0.6)
    sep:SetWidth(1)
    sep:SetPoint("TOPLEFT", inset, "TOPLEFT", 6 + LIST_W + LIST_BAR, -6)
    sep:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 6 + LIST_W + LIST_BAR, 6)

    -- Behind the chosen run: its dungeon's card art, faint.
    win.art = (inset.CreateTexture and inset or win):CreateTexture(nil, "BORDER", nil, 1)
    win.art:SetPoint("TOPLEFT", sep, "TOPRIGHT", 1, 0)
    win.art:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -3, 3)
    win.art:Hide()

    -- Right: the chosen run.
    win.title = win:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalLarge")
    win.title:SetPoint("TOPLEFT", sep, "TOPRIGHT", 14, -8)
    win.title:SetTextColor(1.00, 0.78, 0.20)
    win.sub = win:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    win.sub:SetPoint("TOPLEFT", win.title, "BOTTOMLEFT", 0, -5)
    win.sub:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

    local detailScroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
    win.detailScroll = detailScroll
    detailScroll:SetPoint("TOPLEFT", sep, "TOPRIGHT", 12, 0)
    detailScroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -27, 6)
    local detail = CreateFrame("Frame", nil, detailScroll)
    detail:SetSize(420, 1)
    detailScroll:SetScrollChild(detail)
    AutoScrollBar(detailScroll)
    win.detail = detail
    -- The title sits above the scrolled part's first tiles.
    win.title:SetParent(detail)
    win.title:ClearAllPoints()
    win.title:SetPoint("TOPLEFT", detail, "TOPLEFT", 2, -6)
    win.sub:SetParent(detail)
    win.sub:ClearAllPoints()
    win.sub:SetPoint("TOPLEFT", win.title, "BOTTOMLEFT", 0, -5)

    -- Track on screen: only while the run is going.
    local track = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    FDJ.OwnFonts(track) -- ownfonts (2.0.8)
    win.trackButton = track
    track:SetSize(140, 22)
    track:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -2, -8)
    track:SetScript("OnClick", function()
        if FDJ.ToggleRunTracker then FDJ.ToggleRunTracker() end
        FDJ.RefreshRunLog()
    end)
    track:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(L("RUNLOG_TRACK"), GOLD[1], GOLD[2], GOLD[3])
        GameTooltip:AddLine(L("RUNLOG_TRACK_TIP"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    track:SetScript("OnLeave", function() GameTooltip:Hide() end)
    track:Hide()

    -- Centred in the right-hand side, between the divider line and the
    -- window's edge, so it never runs over the line.
    win.empty = win:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontDisable")
    win.empty:SetPoint("LEFT", sep, "RIGHT", 16, 0)
    win.empty:SetPoint("RIGHT", inset, "RIGHT", -16, 0)
    win.empty:SetJustifyH("CENTER")

    -- An open run's clock keeps ticking on screen.
    local acc = 0
    win:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 1 then return end
        acc = 0
        local run = win.selected
        if run and not run.closed and not run.completed then
            RefreshDetail(win)
        end
    end)
    -- Same scale as the journal (it can be resized with its corner grip).
    win:HookScript("OnShow", function()
        local journal = _G.ForeverDungeonJournalFrame
        if journal and journal.GetScale then win:SetScale(journal:GetScale() or 1) end
    end)
    win:Hide()
    return win
end

local window
function FDJ.RefreshRunLog()
    local win = window
    if not win or not win:IsShown() then return end
    win.windowTitle:SetText(L("RUNLOG"))
    win.empty:SetText(L("RUNLOG_EMPTY"))
    local runs = FDJ.RunLogListRuns()
    local found = false
    for _, run in ipairs(runs) do
        if run == win.selected then found = true break end
    end
    if not found then win.selected = (FDJ.RunLog and FDJ.RunLog.Current()) or runs[#runs] end
    RefreshList(win)
    RefreshDetail(win)
end

function FDJ.ToggleRunLog()
    window = window or CreateWindow()
    if window:IsShown() then window:Hide() return end
    window.selected = (FDJ.RunLog and FDJ.RunLog.Current()) or nil
    PlayerPortrait(window.playerPortrait)
    window:Show()
    if window.Raise then window:Raise() end
    FDJ.RefreshRunLog()
end

-- Recorder changes: redraw at most a few times a second.
local queued = false
function FDJ.RunLogChanged()
    if FDJ.UpdateRunTracker then FDJ.UpdateRunTracker() end
    if queued or not window or not window:IsShown() then return end
    queued = true
    C_Timer.After(0.25, function()
        queued = false
        FDJ.RefreshRunLog()
    end)
end

if StaticPopupDialogs then
    StaticPopupDialogs["FDJ_RUNLOG_DELETE"] = {
        text = "%s",
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function(self, data)
            local run = data or self.data
            if run and run.test then
                FDJ.RunLogTestRemove(run)
            elseif run and FDJ.RunLog then
                FDJ.RunLog.Delete(run)
            end
            if window and window.selected == run then window.selected = nil end
            FDJ.RefreshRunLog()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

-- ------------------------------------------------------------ the icon
-- Favourites adds its button left of Loot Filter; the log icon (the
-- character's portrait) goes left of Favourites (RPG Mode's button then sits
-- left of the icon). Right-click: Hide (Options: Hide Run Log icon).
do
    local strings = {
        enUS = { RUNLOG_PARTY = "Party", RUNLOG_MONEY = "Money earned", RUNLOG_SHOW_GOLD = "Click: show Gold", RUNLOG_SHOW_XP = "Click: show Mobs XP", RUNLOG_GOLD = "Gold", RUNLOG_MOBS_XP = "Mobs XP", RUNLOG_HIDE_TIP = "Right-click to hide", RUNLOG_HIDE = "Hide", RUNLOG_DEL = "Delete this run",
            OPT_HIDE_RUNLOG = "Hide Character Logs icon",
            OPT_HIDE_RUNLOG_TIP = "Hides the Character Logs icon (your character's portrait, left of Favourites) on the journal's home page. You can also right-click the icon and pick Hide. Runs are still logged; /dj log opens the Character Logs." },
        deDE = { RUNLOG_PARTY = "Gruppe", RUNLOG_MONEY = "Geld verdient", RUNLOG_SHOW_GOLD = "Klicken: Gold anzeigen", RUNLOG_SHOW_XP = "Klicken: Mob-XP anzeigen", RUNLOG_GOLD = "Gold", RUNLOG_MOBS_XP = "Mob-XP", RUNLOG_HIDE_TIP = "Rechtsklick zum Ausblenden", RUNLOG_HIDE = "Ausblenden", RUNLOG_DEL = "Diesen Run löschen",
            OPT_HIDE_RUNLOG = "Charakter-Logs-Symbol ausblenden",
            OPT_HIDE_RUNLOG_TIP = "Blendet das Symbol der Charakter-Logs (das Porträt deines Charakters, links von Favoriten) auf der Startseite des Journals aus. Geht auch per Rechtsklick auf das Symbol → Ausblenden. Runs werden weiter aufgezeichnet; /dj log öffnet die Charakter-Logs." },
        frFR = { RUNLOG_PARTY = "Groupe", RUNLOG_MONEY = "Argent gagné", RUNLOG_SHOW_GOLD = "Clic : afficher l'or", RUNLOG_SHOW_XP = "Clic : afficher l'XP des mobs", RUNLOG_GOLD = "Or", RUNLOG_MOBS_XP = "XP des mobs", RUNLOG_HIDE_TIP = "Clic droit pour masquer", RUNLOG_HIDE = "Masquer", RUNLOG_DEL = "Supprimer ce run",
            OPT_HIDE_RUNLOG = "Masquer l'icône des journaux du personnage",
            OPT_HIDE_RUNLOG_TIP = "Masque l'icône des journaux du personnage (le portrait de votre personnage, à gauche de Favoris) sur la page d'accueil du journal. Vous pouvez aussi faire un clic droit sur l'icône et choisir Masquer. Les runs sont toujours enregistrés ; /dj log ouvre les journaux." },
        esES = { RUNLOG_PARTY = "Grupo", RUNLOG_MONEY = "Dinero ganado", RUNLOG_SHOW_GOLD = "Clic: mostrar oro", RUNLOG_SHOW_XP = "Clic: mostrar XP de mobs", RUNLOG_GOLD = "Oro", RUNLOG_MOBS_XP = "XP de mobs", RUNLOG_HIDE_TIP = "Clic derecho para ocultar", RUNLOG_HIDE = "Ocultar", RUNLOG_DEL = "Borrar este run",
            OPT_HIDE_RUNLOG = "Ocultar el icono de registros del personaje",
            OPT_HIDE_RUNLOG_TIP = "Oculta el icono de los registros del personaje (el retrato de tu personaje, a la izquierda de Favoritos) en la página de inicio del diario. También puedes hacer clic derecho en el icono y elegir Ocultar. Las runs se siguen registrando; /dj log abre los registros." },
        itIT = { RUNLOG_PARTY = "Gruppo", RUNLOG_MONEY = "Soldi guadagnati", RUNLOG_SHOW_GOLD = "Clic: mostra oro", RUNLOG_SHOW_XP = "Clic: mostra XP mob", RUNLOG_GOLD = "Oro", RUNLOG_MOBS_XP = "XP mob", RUNLOG_HIDE_TIP = "Clic destro per nascondere", RUNLOG_HIDE = "Nascondi", RUNLOG_DEL = "Elimina questa run",
            OPT_HIDE_RUNLOG = "Nascondi l'icona dei registri del personaggio",
            OPT_HIDE_RUNLOG_TIP = "Nasconde l'icona dei registri del personaggio (il ritratto del tuo personaggio, a sinistra di Preferiti) nella pagina iniziale del diario. Puoi anche cliccare col tasto destro sull'icona e scegliere Nascondi. Le run vengono comunque registrate; /dj log apre i registri." },
        ptBR = { RUNLOG_PARTY = "Grupo", RUNLOG_MONEY = "Dinheiro ganho", RUNLOG_SHOW_GOLD = "Clique: mostrar ouro", RUNLOG_SHOW_XP = "Clique: mostrar XP de mobs", RUNLOG_GOLD = "Ouro", RUNLOG_MOBS_XP = "XP de mobs", RUNLOG_HIDE_TIP = "Clique com o botão direito para ocultar", RUNLOG_HIDE = "Ocultar", RUNLOG_DEL = "Apagar esta run",
            OPT_HIDE_RUNLOG = "Ocultar o ícone de registros do personagem",
            OPT_HIDE_RUNLOG_TIP = "Oculta o ícone dos registros do personagem (o retrato do seu personagem, à esquerda de Favoritos) na página inicial do diário. Você também pode clicar com o botão direito no ícone e escolher Ocultar. As runs continuam sendo registradas; /dj log abre os registros." },
        ruRU = { RUNLOG_PARTY = "Группа", RUNLOG_MONEY = "Заработано денег", RUNLOG_SHOW_GOLD = "Клик: показать золото", RUNLOG_SHOW_XP = "Клик: показать опыт с мобов", RUNLOG_GOLD = "Золото", RUNLOG_MOBS_XP = "Опыт с мобов", RUNLOG_HIDE_TIP = "Правый клик — скрыть", RUNLOG_HIDE = "Скрыть", RUNLOG_DEL = "Удалить забег",
            OPT_HIDE_RUNLOG = "Скрыть значок журналов персонажа",
            OPT_HIDE_RUNLOG_TIP = "Скрывает значок журналов персонажа (портрет вашего персонажа, слева от «Избранного») на главной странице журнала. Также можно щёлкнуть по значку правой кнопкой и выбрать «Скрыть». Забеги по-прежнему записываются; /dj log открывает журналы." },
        koKR = { RUNLOG_PARTY = "파티", RUNLOG_MONEY = "번 돈", RUNLOG_SHOW_GOLD = "클릭: 골드 보기", RUNLOG_SHOW_XP = "클릭: 몹 경험치 보기", RUNLOG_GOLD = "골드", RUNLOG_MOBS_XP = "몹 경험치", RUNLOG_HIDE_TIP = "우클릭하여 숨기기", RUNLOG_HIDE = "숨기기", RUNLOG_DEL = "이 기록 삭제",
            OPT_HIDE_RUNLOG = "캐릭터 기록 아이콘 숨기기",
            OPT_HIDE_RUNLOG_TIP = "도감 첫 페이지의 캐릭터 기록 아이콘(즐겨찾기 왼쪽의 캐릭터 초상화)을 숨깁니다. 아이콘을 우클릭하고 숨기기를 선택해도 됩니다. 기록은 계속 저장되며 /dj log 로 열 수 있습니다." },
        zhCN = { RUNLOG_PARTY = "队伍", RUNLOG_MONEY = "获得金钱", RUNLOG_SHOW_GOLD = "点击：显示金币", RUNLOG_SHOW_XP = "点击：显示怪物经验", RUNLOG_GOLD = "金币", RUNLOG_MOBS_XP = "怪物经验", RUNLOG_HIDE_TIP = "右键点击隐藏", RUNLOG_HIDE = "隐藏", RUNLOG_DEL = "删除此记录",
            OPT_HIDE_RUNLOG = "隐藏角色记录图标",
            OPT_HIDE_RUNLOG_TIP = "隐藏日志首页上的角色记录图标（收藏左边的角色头像）。也可以右键点击图标并选择隐藏。副本仍会被记录；/dj log 可打开角色记录。" },
        zhTW = { RUNLOG_PARTY = "隊伍", RUNLOG_MONEY = "獲得金錢", RUNLOG_SHOW_GOLD = "點擊：顯示金幣", RUNLOG_SHOW_XP = "點擊：顯示怪物經驗", RUNLOG_GOLD = "金幣", RUNLOG_MOBS_XP = "怪物經驗", RUNLOG_HIDE_TIP = "右鍵點擊隱藏", RUNLOG_HIDE = "隱藏", RUNLOG_DEL = "刪除此紀錄",
            OPT_HIDE_RUNLOG = "隱藏角色紀錄圖示",
            OPT_HIDE_RUNLOG_TIP = "隱藏日誌首頁上的角色紀錄圖示（最愛左邊的角色頭像）。也可以右鍵點擊圖示並選擇隱藏。副本仍會被紀錄；/dj log 可開啟角色紀錄。" },
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

-- The icon's size and its gap to Favourites (picked on screen, 1.7.5).
local ICON_SIZE, ICON_GAP, ICON_Y = 42, 11, -1
function FDJ.IsRunLogButtonHidden()
    return ForeverDungeonJournalDB and ForeverDungeonJournalDB.hideRunLogButton == true or false
end

local function RunLogFrame()
    return _G.ForeverDungeonJournalFrame
end

local iconMenu
function FDJ.SetRunLogButtonHidden(hidden)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    ForeverDungeonJournalDB.hideRunLogButton = hidden and true or nil
    if iconMenu then iconMenu:Hide() end
    local frame = RunLogFrame()
    local b = frame and frame.runLogButton
    if b then b:SetShown(not hidden) end
    -- RPG Mode's button sits left of the icon, or of Favourites without it.
    if frame and FDJ.UpdateRPGHeader then pcall(FDJ.UpdateRPGHeader, frame) end
    local settings = _G.ForeverDungeonJournalSettings
    if settings and settings:IsShown() then
        local onShow = settings:GetScript("OnShow")
        if onShow then pcall(onShow, settings) end
    end
end

-- Right-click: a small menu with Hide (as the Sleeping Bag's).
local function ShowIconMenu(anchor)
    if not iconMenu then
        local menu = CreateFrame("Frame", "ForeverDungeonJournalRunLogMenu", UIParent, "BackdropTemplate")
        iconMenu = menu
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:EnableMouse(true)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        menu:SetBackdropColor(0.055, 0.05, 0.043, 0.98)
        menu:SetBackdropBorderColor(0.57, 0.43, 0.20, 1)
        local item = CreateFrame("Button", nil, menu)
        item:SetPoint("TOPLEFT", 5, -5)
        item:SetPoint("RIGHT", -5, 0)
        item:SetHeight(20)
        item:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        item.text = item:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
        item.text:SetPoint("LEFT", 6, 0)
        item:SetScript("OnClick", function()
            menu:Hide()
            -- 2.0.4: Hide opens Options at its line (highlighted); the player
            -- ticks it there, so they know where to undo it.
            if FDJ.OpenSettingsAt then FDJ.OpenSettingsAt("OPT_HIDE_RUNLOG") else FDJ.SetRunLogButtonHidden(true) end
        end)
        menu.hide = item
        -- Closes on its own once the mouse has been away for a moment.
        menu:SetScript("OnUpdate", function(self, elapsed)
            if self:IsMouseOver() or (self.fdjAnchor and self.fdjAnchor:IsMouseOver()) then
                self.fdjAway = 0
            else
                self.fdjAway = (self.fdjAway or 0) + elapsed
                if self.fdjAway > 0.6 then self:Hide() end
            end
        end)
    end
    local menu = iconMenu
    menu.hide.text:SetText(L("RUNLOG_HIDE"))
    menu:SetSize(math.max(110, (menu.hide.text:GetStringWidth() or 0) + 24), 30)
    menu.fdjAnchor = anchor
    menu.fdjAway = 0
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -2)
    menu:Show()
    if GameTooltip then GameTooltip:Hide() end
end

-- Where the icon sits: where it is with the English buttons, so it keeps
-- its place when another language makes the buttons to its right narrower;
-- when they get wider it moves left with Favourites so it never overlaps.
local measure
local function EnglishWidth(fontString, key, extra, low, high)
    local en = FDJ.Locales and FDJ.Locales.enUS and FDJ.Locales.enUS[key]
    if not en or not fontString then return nil end
    measure = measure or UIParent:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    local ok = pcall(function()
        local font, size, flags = fontString:GetFont()
        if font then measure:SetFont(font, size, flags) end
    end)
    measure:SetText(en)
    local w = measure:GetStringWidth()
    if not ok or not w or w <= 0 then return nil end
    return math.max(low, math.min(high, math.ceil(w + extra)))
end

local function PlaceIcon(b)
    local frame = b.fdjFrame
    local fav = b.fdjRight
    if not fav then return end
    b:SetSize(ICON_SIZE, ICON_SIZE)
    b:ClearAllPoints()
    local hide = frame and frame.hideDungeonsButton
    local loot = frame and frame.lootFilterButton
    -- Same widths the buttons give themselves (Favourites.lua, LootFilter.lua,
    -- the journal's Hide Dungeons), for the English words.
    local favEn = fav.text and EnglishWidth(fav.text, "FAVOURITES", 44, 96, 170)
    local lootEn = loot and frame.lootFilterButtonText and EnglishWidth(frame.lootFilterButtonText, "LOOT_FILTER", 26, 110, 180)
    local hideEn = hide and frame.hideDungeonsButtonText and EnglishWidth(frame.hideDungeonsButtonText, "HIDE_DUNGEONS", 26, 126, 180)
    if not (favEn and lootEn and hideEn) or fav ~= frame.favouritesButton then
        b:SetPoint("RIGHT", fav, "LEFT", -ICON_GAP, ICON_Y)
        return
    end
    -- From the middle of Hide Dungeons to the left edge of Favourites:
    -- now, and with the English words (the gaps between buttons stay).
    local hideW, lootW, favW = hide:GetWidth() or 0, loot:GetWidth() or 0, fav:GetWidth() or 0
    local gaps = 16
    local hx, fl = hide:GetCenter(), fav:GetLeft()
    if hx and fl then
        gaps = (hx - fl) - hideW / 2 - lootW - favW
        if gaps < 0 or gaps > 60 then gaps = 16 end
    end
    local now = hideW / 2 + lootW + favW + gaps
    local english = hideEn / 2 + lootEn + favEn + gaps
    if now > english then
        b:SetPoint("RIGHT", fav, "LEFT", -ICON_GAP, ICON_Y)
    else
        b:SetPoint("RIGHT", hide, "CENTER", -(english + ICON_GAP), ICON_Y)
    end
end
FDJ.PlaceRunLogIcon = function()
    local frame = RunLogFrame()
    if frame and frame.runLogButton then PlaceIcon(frame.runLogButton) end
end

local baseCreate = FDJ.CreateLootFilterButton
if baseCreate then
    FDJ.CreateLootFilterButton = function(frame, home, anchorButton)
        baseCreate(frame, home, anchorButton)
        if not frame or frame.runLogButton then return end
        local right = frame.favouritesButton or frame.lootFilterButton
        if not right then return end
        local b = CreateFrame("Button", nil, home, "BackdropTemplate")
        frame.runLogButton = b
        b.fdjRight = right
        b.fdjFrame = frame
        PlaceIcon(b)
        if C_Timer and C_Timer.After then C_Timer.After(0, function() PlaceIcon(b) end) end
        if home.HookScript then home:HookScript("OnShow", function() PlaceIcon(b) end) end
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetBackdrop(BACKDROP)
        b:SetBackdropColor(0.12, 0.115, 0.105, 0.98)
        b:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 3, -3)
        b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        PlayerPortrait(b.icon, true)
        b:SetScript("OnShow", function(self) PlayerPortrait(self.icon, true) end)
        local ev = CreateFrame("Frame")
        ev:RegisterEvent("PLAYER_ENTERING_WORLD")
        ev:RegisterEvent("UNIT_PORTRAIT_UPDATE")
        ev:SetScript("OnEvent", function(_, event, unit)
            if event == "UNIT_PORTRAIT_UPDATE" and unit ~= "player" then return end
            PlayerPortrait(b.icon, true)
            if window and window.playerPortrait then PlayerPortrait(window.playerPortrait) end
        end)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
            GameTooltip:SetText(L("RUNLOG"), GOLD[1], GOLD[2], GOLD[3])
            GameTooltip:AddLine(L("RUNLOG_TIP"), 1, 1, 1, true)
            GameTooltip:AddLine(L("RUNLOG_HIDE_TIP"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                ShowIconMenu(self)
                return
            end
            if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_OPEN) end
            FDJ.ToggleRunLog()
        end)
        b:SetShown(not FDJ.IsRunLogButtonHidden())
    end
end

-- Follow language changes made in the journal.
local baseRelocalize = FDJ.RelocalizeLootFilter
if baseRelocalize then
    FDJ.RelocalizeLootFilter = function(frame, ...)
        baseRelocalize(frame, ...)
        FDJ.RefreshRunLog()
        -- the buttons to its right take their new widths after this
        if C_Timer and C_Timer.After then C_Timer.After(0, FDJ.PlaceRunLogIcon) else FDJ.PlaceRunLogIcon() end
    end
end

-- ------------------------------------------------------------ on-screen tracker
-- "Track on screen": a small window with the run's time, XP and bosses
-- (portraits greyed with an X once killed), updated live. It stays on for
-- the next runs too, until it is closed.
do
    local strings = {
        enUS = { RUNLOG_NOT_FOUND = "not found", RUNLOG_NO_LOOT = "No loot seen.", RUNLOG_TRACK = "Track on screen", RUNLOG_UNTRACK = "Stop tracking",
            RUNLOG_TRACK_TIP = "Shows this run's time, XP and bosses on your screen while the dungeon is going. Drag it to move it." },
        deDE = { RUNLOG_NOT_FOUND = "nicht gefunden", RUNLOG_NO_LOOT = "Keine Beute gesehen.", RUNLOG_TRACK = "Auf dem Bildschirm", RUNLOG_UNTRACK = "Nicht mehr anzeigen",
            RUNLOG_TRACK_TIP = "Zeigt Zeit, EP und Bosse dieses Runs auf dem Bildschirm, solange der Dungeon läuft. Zum Verschieben ziehen." },
        frFR = { RUNLOG_NOT_FOUND = "pas trouvé", RUNLOG_NO_LOOT = "Aucun butin vu.", RUNLOG_TRACK = "Suivre à l'écran", RUNLOG_UNTRACK = "Arrêter le suivi",
            RUNLOG_TRACK_TIP = "Affiche le temps, l'XP et les boss de ce run à l'écran pendant le donjon. Faites glisser pour déplacer." },
        esES = { RUNLOG_NOT_FOUND = "no encontrado", RUNLOG_NO_LOOT = "No se vio botín.", RUNLOG_TRACK = "Seguir en pantalla", RUNLOG_UNTRACK = "Dejar de seguir",
            RUNLOG_TRACK_TIP = "Muestra en pantalla el tiempo, los PX y los jefes de este run mientras dura la mazmorra. Arrástralo para moverlo." },
        itIT = { RUNLOG_NOT_FOUND = "non trovato", RUNLOG_NO_LOOT = "Nessun bottino visto.", RUNLOG_TRACK = "Mostra a schermo", RUNLOG_UNTRACK = "Smetti di mostrare",
            RUNLOG_TRACK_TIP = "Mostra a schermo tempo, PE e boss di questa run finché il dungeon è in corso. Trascinalo per spostarlo." },
        ptBR = { RUNLOG_NOT_FOUND = "não encontrado", RUNLOG_NO_LOOT = "Nenhum saque visto.", RUNLOG_TRACK = "Mostrar na tela", RUNLOG_UNTRACK = "Parar de mostrar",
            RUNLOG_TRACK_TIP = "Mostra na tela o tempo, o XP e os chefes desta run enquanto a masmorra durar. Arraste para mover." },
        ruRU = { RUNLOG_NOT_FOUND = "не найден", RUNLOG_NO_LOOT = "Добыча не замечена.", RUNLOG_TRACK = "Показывать на экране", RUNLOG_UNTRACK = "Не показывать",
            RUNLOG_TRACK_TIP = "Показывает время, опыт и боссов этого забега на экране, пока идёт подземелье. Перетащите, чтобы переместить." },
        koKR = { RUNLOG_NOT_FOUND = "발견 안 됨", RUNLOG_NO_LOOT = "본 전리품 없음.", RUNLOG_TRACK = "화면에 표시", RUNLOG_UNTRACK = "표시 끄기",
            RUNLOG_TRACK_TIP = "던전 진행 중 이 기록의 시간, 경험치, 우두머리를 화면에 표시합니다. 끌어서 옮길 수 있습니다." },
        zhCN = { RUNLOG_NOT_FOUND = "未发现", RUNLOG_NO_LOOT = "未见掉落。", RUNLOG_TRACK = "在屏幕上显示", RUNLOG_UNTRACK = "停止显示",
            RUNLOG_TRACK_TIP = "副本进行中在屏幕上显示本次的用时、经验和首领。拖动可移动。" },
        zhTW = { RUNLOG_NOT_FOUND = "未發現", RUNLOG_NO_LOOT = "未見掉落。", RUNLOG_TRACK = "在螢幕上顯示", RUNLOG_UNTRACK = "停止顯示",
            RUNLOG_TRACK_TIP = "副本進行中在螢幕上顯示本次的用時、經驗和首領。拖曳可移動。" },
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

local function TrackerDB()
    ForeverDungeonJournalCharacterDB = ForeverDungeonJournalCharacterDB or {}
    local db = ForeverDungeonJournalCharacterDB
    if type(db.runTracker) ~= "table" then db.runTracker = {} end
    return db.runTracker
end

-- resetblank (2.0.4): after the tracker's reset button, the tracker stays
-- up for the same dungeon at 0 (time, XP, gold) with every boss alive,
-- until the next kill starts the new run. Saved (per character), so a
-- /reload keeps it; gone once another dungeon is entered, or after 90
-- minutes outside. Not a run of the log.
local blankRun
local function BlankRun()
    local db = TrackerDB()
    local b = db.blankRun
    if type(b) ~= "table" then return nil end
    local api = FDJ.RunLog
    local map = api and api.InsideMap and api.InsideMap()
    if (map and b.map and map ~= b.map) or (not map and Now() - (b.created or 0) > 90 * 60) then
        db.blankRun = nil
        return nil
    end
    if not (blankRun and blankRun.id == b.id) then
        blankRun = { blank = true, id = b.id, dungeon = b.dungeon, map = b.map, instanceName = b.instanceName,
            capped = b.capped, created = b.created, kills = {} }
    end
    return blankRun
end
function FDJ.StartBlankRun(run)
    if not (run and run.dungeon) then return end
    local now = Now()
    if run.test then -- /dj testlog: a blank test run, never saved
        FDJ.testRunID = (FDJ.testRunID or 0) - 1
        FDJ.testRun = { test = true, blank = true, id = FDJ.testRunID, dungeon = run.dungeon, map = run.map,
            capped = run.capped, created = now, kills = {} }
        return
    end
    TrackerDB().blankRun = { id = -1000000 - now, dungeon = run.dungeon, map = run.map,
        instanceName = run.instanceName, capped = run.capped, created = now }
end

-- The game's "<Dungeon> has been reset." line: a tracker waiting at 0 for
-- that dungeon closes, as a running one does.
function FDJ.EndBlankRun(test)
    local db = TrackerDB()
    local b = db.blankRun
    if type(b) ~= "table" then return false end
    if test and not test({ dungeon = b.dungeon, instanceName = b.instanceName }) then return false end
    db.blankRun = nil
    blankRun = nil
    if FDJ.UpdateRunTracker then FDJ.UpdateRunTracker() end
    return true
end

-- The run to show: the one being recorded, or an unfinished one we are
-- outside of (a corpse run or a trip to a vendor).
local function TrackedRun()
    if FDJ.testRun then return FDJ.testRun end -- /dj testlog
    local api = FDJ.RunLog
    if not api then return nil end
    local cur = api.Current()
    if cur then
        -- resetblank: the next kill started the new run
        local db = TrackerDB()
        if db.blankRun then db.blankRun = nil end
        return cur
    end
    local blank = BlankRun()
    if blank then return blank end
    -- Inside a dungeon (before its first kill): only an unfinished run of
    -- THIS instance. A run left unfinished in another dungeon showed up
    -- here, with the wrong title and bosses, until the first kill.
    local map = api.InsideMap and api.InsideMap()
    local runs = api.Runs()
    for i = #runs, 1, -1 do
        if RunInProgress(runs[i]) and (not map or runs[i].map == map) then return runs[i] end
    end
end

-- Options > Dungeon Tracker (account-wide): never show it, or hide some of
-- its columns.
function FDJ.TrackerOption(key)
    local db = ForeverDungeonJournalDB
    return db and type(db.trackerOptions) == "table" and db.trackerOptions[key] == true or false
end
function FDJ.SetTrackerOption(key, on)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    if type(ForeverDungeonJournalDB.trackerOptions) ~= "table" then ForeverDungeonJournalDB.trackerOptions = {} end
    ForeverDungeonJournalDB.trackerOptions[key] = on and true or nil
    if FDJ.UpdateRunTracker then FDJ.UpdateRunTracker() end
    if FDJ.RefreshRunLog then FDJ.RefreshRunLog() end
    -- an open Options panel ticks along (Hide Tracker set by the X)
    if FDJ.RefreshSettingsChecks then pcall(FDJ.RefreshSettingsChecks) end
end
-- hidetracker (2.0.4): Options > Dungeon Tracker > Hide Tracker. The
-- tracker's X ticks it; "/dj tracker", Track on screen or unticking it
-- shows the tracker again (for players who never read "/dj tracker"). It
-- hides the run it was ticked for: a new run unticks it by itself and the
-- tracker works as usual.
-- hideleave (2.0.10, M 17 Nov 2026: "if somebody goes out of the dungeon and
-- it's not dead, I want the option to automatically untick"; Killer Kenney
-- closed it, came back with a new group and it never showed): out of the
-- dungeon alive, Hide Tracker unticks; the tracker its X closed stays closed
-- until you go into a dungeon again, then it shows as usual. Out as a ghost
-- (a corpse run) it stays ticked, as before.
function FDJ.TrackerLeftAlive()
    if not FDJ.TrackerOption("hide") then return end
    local db = TrackerDB()
    db.hideRun = nil
    if db.dismissedRun ~= nil then db.dismissedUntilEnter = true end
    FDJ.SetTrackerOption("hide", false)
end
function FDJ.TrackerEnteredDungeon()
    local db = TrackerDB()
    if not db.dismissedUntilEnter then return end
    db.dismissedUntilEnter = nil
    db.dismissedRun = nil
    if FDJ.UpdateRunTracker then pcall(FDJ.UpdateRunTracker) end
end

function FDJ.SetTrackerHidden(on)
    if on then
        if FDJ.trackerHint then FDJ.trackerHint:Hide() end
        local run = TrackedRun()
        TrackerDB().hideRun = run and run.id or nil
        FDJ.SetTrackerOption("hide", true)
    else
        TrackerDB().hideRun = nil
        FDJ.SetTrackerOption("hide", false)
        if FDJ.ReopenDungeonTracker then FDJ.ReopenDungeonTracker() end
    end
end
do
    local strings = {
        enUS = { OPT_TRACK_HIDE = "Hide Tracker", OPT_TRACK_HIDE_TIP = "Hides the tracker for this run. Closing it with its X ticks this; leaving the dungeon alive or a new run unticks it by itself. \"/dj tracker\" or unticking it shows the tracker again." },
        deDE = { OPT_TRACK_HIDE = "Tracker ausblenden", OPT_TRACK_HIDE_TIP = "Blendet den Tracker für diesen Run aus. Schließen mit dem X setzt diesen Haken; den Dungeon lebend verlassen oder ein neuer Run entfernt ihn von selbst. „/dj tracker“ oder Haken entfernen zeigt den Tracker wieder." },
        frFR = { OPT_TRACK_HIDE = "Masquer le suivi", OPT_TRACK_HIDE_TIP = "Masque le suivi pour ce run. Le fermer avec son X coche cette case ; sortir du donjon en vie ou un nouveau run la décoche tout seul. « /dj tracker » ou la décocher réaffiche le suivi." },
        esES = { OPT_TRACK_HIDE = "Ocultar el seguimiento", OPT_TRACK_HIDE_TIP = "Oculta el seguimiento en esta run. Cerrarlo con su X marca esta casilla; salir de la mazmorra con vida o una run nueva la desmarca sola. «/dj tracker» o desmarcarla vuelve a mostrar el seguimiento." },
        itIT = { OPT_TRACK_HIDE = "Nascondi tracker", OPT_TRACK_HIDE_TIP = "Nasconde il tracker per questa run. Chiuderlo con la X spunta questa casella; uscire dal dungeon da vivo o una nuova run la toglie da sola. «/dj tracker» o togliere la spunta mostra di nuovo il tracker." },
        ptBR = { OPT_TRACK_HIDE = "Ocultar rastreador", OPT_TRACK_HIDE_TIP = "Oculta o rastreador nesta run. Fechá-lo no X marca esta opção; sair da masmorra vivo ou uma nova run a desmarca sozinha. «/dj tracker» ou desmarcá-la mostra o rastreador de novo." },
        ruRU = { OPT_TRACK_HIDE = "Скрыть трекер", OPT_TRACK_HIDE_TIP = "Скрывает трекер в этом забеге. Закрытие крестиком ставит эту галочку; выход из подземелья живым или новый забег снимает её сам. «/dj tracker» или снятие галочки снова показывает трекер." },
        koKR = { OPT_TRACK_HIDE = "추적기 숨기기", OPT_TRACK_HIDE_TIP = "이번 던전 진행에서 추적기를 숨깁니다. X로 닫으면 자동으로 체크되고, 살아서 던전을 나가거나 새 진행이 시작되면 저절로 해제됩니다. \"/dj tracker\"를 입력하거나 체크를 해제하면 다시 표시됩니다." },
        zhCN = { OPT_TRACK_HIDE = "隐藏追踪器", OPT_TRACK_HIDE_TIP = "本次副本中隐藏追踪器。用 X 关闭时会自动勾选；活着离开副本或开始新的副本时会自动取消。输入“/dj tracker”或取消勾选即可再次显示。" },
        zhTW = { OPT_TRACK_HIDE = "隱藏追蹤器", OPT_TRACK_HIDE_TIP = "本次副本中隱藏追蹤器。用 X 關閉時會自動勾選；活著離開副本或開始新的副本時會自動取消。輸入「/dj tracker」或取消勾選即可再次顯示。" },
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
do
    local strings = {
        enUS = { OPT_TRACK_SOLO = "Show Tracker for solo runs too", OPT_TRACK_SOLO_TIP = "The tracker also opens by itself when you are in a dungeon without a group.", OPT_TRACK_HIDE_BOSSES = "Hide Bosses", OPT_TRACK_HIDE_BOSSES_TIP = "The tracker doesn't show the boss and rare portraits.", OPT_TRACKER = "Dungeon Tracker", OPT_TRACK_NEVER = "Never track dungeons", OPT_TRACK_NEVER_TIP = "The small tracker window (time, XP, gold and bosses) never opens by itself in dungeons. Runs are still logged, and Track on screen in the Character Logs still opens it.",
            OPT_TRACK_HIDE_TIME = "Hide Time", OPT_TRACK_HIDE_TIME_TIP = "The tracker doesn't show the run's time.",
            OPT_TRACK_HIDE_XP = "Hide Mobs XP", OPT_TRACK_HIDE_XP_TIP = "The tracker doesn't show the XP from mobs.",
            OPT_TRACK_HIDE_GOLD = "Hide Gold", OPT_TRACK_HIDE_GOLD_TIP = "The tracker doesn't show the money earned.", RUNLOG_OPTIONS = "Options" },
        deDE = { OPT_TRACK_SOLO = "Tracker auch bei Solo-Runs zeigen", OPT_TRACK_SOLO_TIP = "Der Tracker öffnet sich auch von selbst, wenn du ohne Gruppe in einem Dungeon bist.", OPT_TRACK_HIDE_BOSSES = "Bosse ausblenden", OPT_TRACK_HIDE_BOSSES_TIP = "Der Tracker zeigt keine Boss- und Rare-Porträts.", OPT_TRACKER = "Dungeon-Tracker", OPT_TRACK_NEVER = "Dungeons nie verfolgen", OPT_TRACK_NEVER_TIP = "Das kleine Tracker-Fenster (Zeit, XP, Gold und Bosse) öffnet sich in Dungeons nie von selbst. Runs werden weiter aufgezeichnet, und „Auf dem Bildschirm“ in den Charakter-Logs öffnet es weiterhin.",
            OPT_TRACK_HIDE_TIME = "Zeit ausblenden", OPT_TRACK_HIDE_TIME_TIP = "Der Tracker zeigt die Zeit des Runs nicht an.",
            OPT_TRACK_HIDE_XP = "Mob-XP ausblenden", OPT_TRACK_HIDE_XP_TIP = "Der Tracker zeigt die XP von Mobs nicht an.",
            OPT_TRACK_HIDE_GOLD = "Gold ausblenden", OPT_TRACK_HIDE_GOLD_TIP = "Der Tracker zeigt das verdiente Geld nicht an.", RUNLOG_OPTIONS = "Optionen" },
        frFR = { OPT_TRACK_SOLO = "Afficher le suivi aussi pour les runs en solo", OPT_TRACK_SOLO_TIP = "Le suivi s'ouvre aussi tout seul quand vous êtes dans un donjon sans groupe.", OPT_TRACK_HIDE_BOSSES = "Masquer les boss", OPT_TRACK_HIDE_BOSSES_TIP = "Le suivi n'affiche pas les portraits des boss et des rares.", OPT_TRACKER = "Suivi de donjon", OPT_TRACK_NEVER = "Ne jamais suivre les donjons", OPT_TRACK_NEVER_TIP = "La petite fenêtre de suivi (temps, XP, or et boss) ne s'ouvre jamais d'elle-même en donjon. Les runs sont toujours enregistrés, et « Suivre à l'écran » dans les journaux l'ouvre toujours.",
            OPT_TRACK_HIDE_TIME = "Masquer le temps", OPT_TRACK_HIDE_TIME_TIP = "Le suivi n'affiche pas le temps du run.",
            OPT_TRACK_HIDE_XP = "Masquer l'XP des mobs", OPT_TRACK_HIDE_XP_TIP = "Le suivi n'affiche pas l'XP des mobs.",
            OPT_TRACK_HIDE_GOLD = "Masquer l'or", OPT_TRACK_HIDE_GOLD_TIP = "Le suivi n'affiche pas l'argent gagné.", RUNLOG_OPTIONS = "Options" },
        esES = { OPT_TRACK_SOLO = "Mostrar el seguimiento también en runs en solitario", OPT_TRACK_SOLO_TIP = "El seguimiento también se abre solo cuando estás en una mazmorra sin grupo.", OPT_TRACK_HIDE_BOSSES = "Ocultar jefes", OPT_TRACK_HIDE_BOSSES_TIP = "El seguimiento no muestra los retratos de jefes y raros.", OPT_TRACKER = "Seguimiento de mazmorra", OPT_TRACK_NEVER = "No seguir nunca las mazmorras", OPT_TRACK_NEVER_TIP = "La pequeña ventana de seguimiento (tiempo, XP, oro y jefes) nunca se abre sola en las mazmorras. Las runs se siguen registrando y «Seguir en pantalla» en los registros la sigue abriendo.",
            OPT_TRACK_HIDE_TIME = "Ocultar tiempo", OPT_TRACK_HIDE_TIME_TIP = "El seguimiento no muestra el tiempo de la run.",
            OPT_TRACK_HIDE_XP = "Ocultar XP de mobs", OPT_TRACK_HIDE_XP_TIP = "El seguimiento no muestra la XP de los mobs.",
            OPT_TRACK_HIDE_GOLD = "Ocultar oro", OPT_TRACK_HIDE_GOLD_TIP = "El seguimiento no muestra el dinero ganado.", RUNLOG_OPTIONS = "Opciones" },
        itIT = { OPT_TRACK_SOLO = "Mostra il tracker anche nelle run in solitaria", OPT_TRACK_SOLO_TIP = "Il tracker si apre da solo anche quando sei in un dungeon senza gruppo.", OPT_TRACK_HIDE_BOSSES = "Nascondi boss", OPT_TRACK_HIDE_BOSSES_TIP = "Il tracker non mostra i ritratti di boss e rari.", OPT_TRACKER = "Tracker dungeon", OPT_TRACK_NEVER = "Non tracciare mai i dungeon", OPT_TRACK_NEVER_TIP = "La piccola finestra del tracker (tempo, XP, oro e boss) non si apre mai da sola nei dungeon. Le run vengono comunque registrate, e «Mostra a schermo» nei registri la apre ancora.",
            OPT_TRACK_HIDE_TIME = "Nascondi tempo", OPT_TRACK_HIDE_TIME_TIP = "Il tracker non mostra il tempo della run.",
            OPT_TRACK_HIDE_XP = "Nascondi XP mob", OPT_TRACK_HIDE_XP_TIP = "Il tracker non mostra l'XP dei mob.",
            OPT_TRACK_HIDE_GOLD = "Nascondi oro", OPT_TRACK_HIDE_GOLD_TIP = "Il tracker non mostra i soldi guadagnati.", RUNLOG_OPTIONS = "Opzioni" },
        ptBR = { OPT_TRACK_SOLO = "Mostrar o rastreador também em runs solo", OPT_TRACK_SOLO_TIP = "O rastreador também abre sozinho quando você está numa masmorra sem grupo.", OPT_TRACK_HIDE_BOSSES = "Ocultar chefes", OPT_TRACK_HIDE_BOSSES_TIP = "O rastreador não mostra os retratos de chefes e raros.", OPT_TRACKER = "Rastreador de masmorra", OPT_TRACK_NEVER = "Nunca rastrear masmorras", OPT_TRACK_NEVER_TIP = "A pequena janela do rastreador (tempo, XP, ouro e chefes) nunca abre sozinha nas masmorras. As runs continuam sendo registradas, e «Mostrar na tela» nos registros ainda a abre.",
            OPT_TRACK_HIDE_TIME = "Ocultar tempo", OPT_TRACK_HIDE_TIME_TIP = "O rastreador não mostra o tempo da run.",
            OPT_TRACK_HIDE_XP = "Ocultar XP de mobs", OPT_TRACK_HIDE_XP_TIP = "O rastreador não mostra a XP dos mobs.",
            OPT_TRACK_HIDE_GOLD = "Ocultar ouro", OPT_TRACK_HIDE_GOLD_TIP = "O rastreador não mostra o dinheiro ganho.", RUNLOG_OPTIONS = "Opções" },
        ruRU = { OPT_TRACK_SOLO = "Показывать трекер и в одиночных забегах", OPT_TRACK_SOLO_TIP = "Трекер открывается сам и тогда, когда вы в подземелье без группы.", OPT_TRACK_HIDE_BOSSES = "Скрыть боссов", OPT_TRACK_HIDE_BOSSES_TIP = "Трекер не показывает портреты боссов и редких.", OPT_TRACKER = "Трекер подземелья", OPT_TRACK_NEVER = "Никогда не отслеживать подземелья", OPT_TRACK_NEVER_TIP = "Маленькое окно трекера (время, опыт, золото и боссы) никогда не открывается само в подземельях. Забеги по-прежнему записываются, а «Показывать на экране» в журналах всё так же его открывает.",
            OPT_TRACK_HIDE_TIME = "Скрыть время", OPT_TRACK_HIDE_TIME_TIP = "Трекер не показывает время забега.",
            OPT_TRACK_HIDE_XP = "Скрыть опыт с мобов", OPT_TRACK_HIDE_XP_TIP = "Трекер не показывает опыт с мобов.",
            OPT_TRACK_HIDE_GOLD = "Скрыть золото", OPT_TRACK_HIDE_GOLD_TIP = "Трекер не показывает заработанные деньги.", RUNLOG_OPTIONS = "Настройки" },
        koKR = { OPT_TRACK_SOLO = "솔로 던전에서도 추적기 표시", OPT_TRACK_SOLO_TIP = "파티 없이 던전에 있을 때도 추적기가 저절로 열립니다.", OPT_TRACK_HIDE_BOSSES = "우두머리 숨기기", OPT_TRACK_HIDE_BOSSES_TIP = "추적기에 우두머리와 희귀 몹 초상화를 표시하지 않습니다.", OPT_TRACKER = "던전 추적기", OPT_TRACK_NEVER = "던전 추적 안 함", OPT_TRACK_NEVER_TIP = "작은 추적 창(시간, 경험치, 골드, 우두머리)이 던전에서 저절로 열리지 않습니다. 기록은 계속 저장되며, 캐릭터 기록의 '화면에 표시'로 여전히 열 수 있습니다.",
            OPT_TRACK_HIDE_TIME = "시간 숨기기", OPT_TRACK_HIDE_TIME_TIP = "추적기에 시간을 표시하지 않습니다.",
            OPT_TRACK_HIDE_XP = "몹 경험치 숨기기", OPT_TRACK_HIDE_XP_TIP = "추적기에 몹 경험치를 표시하지 않습니다.",
            OPT_TRACK_HIDE_GOLD = "골드 숨기기", OPT_TRACK_HIDE_GOLD_TIP = "추적기에 번 돈을 표시하지 않습니다.", RUNLOG_OPTIONS = "설정" },
        zhCN = { OPT_TRACK_SOLO = "单人副本也显示追踪器", OPT_TRACK_SOLO_TIP = "没有队伍时进入副本，追踪器也会自动打开。", OPT_TRACK_HIDE_BOSSES = "隐藏首领", OPT_TRACK_HIDE_BOSSES_TIP = "追踪器不显示首领和稀有怪头像。", OPT_TRACKER = "副本追踪器", OPT_TRACK_NEVER = "从不追踪副本", OPT_TRACK_NEVER_TIP = "小追踪窗口（时间、经验、金币和首领）在副本中不会自动打开。副本仍会被记录，角色记录中的“在屏幕上显示”仍可打开它。",
            OPT_TRACK_HIDE_TIME = "隐藏时间", OPT_TRACK_HIDE_TIME_TIP = "追踪器不显示用时。",
            OPT_TRACK_HIDE_XP = "隐藏怪物经验", OPT_TRACK_HIDE_XP_TIP = "追踪器不显示怪物经验。",
            OPT_TRACK_HIDE_GOLD = "隐藏金币", OPT_TRACK_HIDE_GOLD_TIP = "追踪器不显示获得的金钱。", RUNLOG_OPTIONS = "选项" },
        zhTW = { OPT_TRACK_SOLO = "單人副本也顯示追蹤器", OPT_TRACK_SOLO_TIP = "沒有隊伍時進入副本，追蹤器也會自動開啟。", OPT_TRACK_HIDE_BOSSES = "隱藏首領", OPT_TRACK_HIDE_BOSSES_TIP = "追蹤器不顯示首領和稀有怪頭像。", OPT_TRACKER = "副本追蹤器", OPT_TRACK_NEVER = "從不追蹤副本", OPT_TRACK_NEVER_TIP = "小追蹤視窗（時間、經驗、金幣和首領）在副本中不會自動開啟。副本仍會被紀錄，角色紀錄中的「在螢幕上顯示」仍可開啟它。",
            OPT_TRACK_HIDE_TIME = "隱藏時間", OPT_TRACK_HIDE_TIME_TIP = "追蹤器不顯示用時。",
            OPT_TRACK_HIDE_XP = "隱藏怪物經驗", OPT_TRACK_HIDE_XP_TIP = "追蹤器不顯示怪物經驗。",
            OPT_TRACK_HIDE_GOLD = "隱藏金幣", OPT_TRACK_HIDE_GOLD_TIP = "追蹤器不顯示獲得的金錢。", RUNLOG_OPTIONS = "選項" },
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

-- locktracker (2.0.11): Options > Dungeon Tracker > Lock Tracker
do
    local strings = {
        enUS = { OPT_TRACK_LOCK = "Lock Tracker", OPT_TRACK_LOCK_TIP = "The tracker can't be moved and loses its resize corner and its X. Right-click still opens Options." },
        deDE = { OPT_TRACK_LOCK = "Tracker sperren", OPT_TRACK_LOCK_TIP = "Der Tracker lässt sich nicht mehr verschieben und verliert die Größenecke und sein X. Rechtsklick öffnet weiterhin die Optionen." },
        frFR = { OPT_TRACK_LOCK = "Verrouiller le suivi", OPT_TRACK_LOCK_TIP = "Le suivi ne peut plus être déplacé et perd son coin de redimensionnement et son X. Le clic droit ouvre toujours les options." },
        esES = { OPT_TRACK_LOCK = "Bloquear el seguimiento", OPT_TRACK_LOCK_TIP = "El seguimiento no se puede mover y pierde la esquina para cambiar el tamaño y su X. El clic derecho sigue abriendo las opciones." },
        itIT = { OPT_TRACK_LOCK = "Blocca tracker", OPT_TRACK_LOCK_TIP = "Il tracker non si può spostare e perde l'angolo per ridimensionarlo e la X. Il clic destro apre ancora le opzioni." },
        ptBR = { OPT_TRACK_LOCK = "Travar rastreador", OPT_TRACK_LOCK_TIP = "O rastreador não pode ser movido e perde o canto de redimensionar e o X. O clique direito ainda abre as opções." },
        ruRU = { OPT_TRACK_LOCK = "Закрепить трекер", OPT_TRACK_LOCK_TIP = "Трекер нельзя перемещать, у него пропадают уголок изменения размера и крестик. Правый щелчок по-прежнему открывает настройки." },
        koKR = { OPT_TRACK_LOCK = "추적기 잠금", OPT_TRACK_LOCK_TIP = "추적기를 옮길 수 없고 크기 조절 모서리와 X가 사라집니다. 오른쪽 클릭으로는 여전히 설정을 열 수 있습니다." },
        zhCN = { OPT_TRACK_LOCK = "锁定追踪器", OPT_TRACK_LOCK_TIP = "追踪器无法移动，右下角的缩放角和 X 也会隐藏。右键点击仍可打开选项。" },
        zhTW = { OPT_TRACK_LOCK = "鎖定追蹤器", OPT_TRACK_LOCK_TIP = "追蹤器無法移動，右下角的縮放角和 X 也會隱藏。右鍵點擊仍可開啟選項。" },
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

-- Right-click on the tracker: a small menu with Options (opens Options >
-- Dungeon Tracker).
local trackerMenu
local function ShowTrackerMenu(anchor)
    -- while the first-time note is up, a right-click goes straight to
    -- Options > Dungeon Tracker with Never track dungeons highlighted
    if FDJ.trackerHint and FDJ.trackerHint:IsShown() then
        if trackerMenu then trackerMenu:Hide() end
        if GameTooltip then GameTooltip:Hide() end
        if FDJ.OpenSettingsAt then FDJ.OpenSettingsAt("OPT_TRACK_NEVER") end
        return
    end
    if not trackerMenu then
        local menu = CreateFrame("Frame", "ForeverDungeonJournalTrackerMenu", UIParent, "BackdropTemplate")
        trackerMenu = menu
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:EnableMouse(true)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        menu:SetBackdropColor(0.055, 0.05, 0.043, 0.98)
        menu:SetBackdropBorderColor(0.57, 0.43, 0.20, 1)
        local item = CreateFrame("Button", nil, menu)
        item:SetPoint("TOPLEFT", 5, -5)
        item:SetPoint("RIGHT", -5, 0)
        item:SetHeight(20)
        item:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        item.text = item:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
        item.text:SetPoint("LEFT", 6, 0)
        item:SetScript("OnClick", function()
            menu:Hide()
            if FDJ.OpenSettingsAt then FDJ.OpenSettingsAt("OPT_TRACK_NEVER", true) end
        end)
        menu.item = item
        -- 2.0.4: gone as soon as the mouse leaves it (it opens under the
        -- cursor; a moment's grace while it first appears).
        menu:SetScript("OnUpdate", function(self, elapsed)
            self.fdjAge = (self.fdjAge or 0) + elapsed
            if self.fdjAge < 0.1 then return end
            if not self:IsMouseOver() then self:Hide() end
        end)
    end
    local menu = trackerMenu
    menu.item.text:SetText(L("RUNLOG_OPTIONS"))
    menu:SetSize(math.max(110, (menu.item.text:GetStringWidth() or 0) + 24), 30)
    menu.fdjAnchor = anchor
    menu.fdjAge = 0
    menu:ClearAllPoints()
    local x, y = GetCursorPosition()
    local es = UIParent:GetEffectiveScale()
    -- 2.0.4: right on the cursor (the pointer on "Options")
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / es - 12, y / es + 12)
    menu:Show()
    if GameTooltip then GameTooltip:Hide() end
end
FDJ.ShowTrackerMenu = ShowTrackerMenu

-- groupreset (2.0.4): /dj reset and the tracker's reset button: the run
-- shown ends; the next kill starts a new one.
function FDJ.EndTrackedRun()
    local run = TrackedRun()
    if run and run.blank then return false end -- resetblank: nothing to end yet
    if run and run.test then -- /dj testlog: just off the tracker
        FDJ.testRun = nil
        FDJ.UpdateRunTracker()
        return true
    end
    if not (run and FDJ.RunLog and FDJ.RunLog.EndRun) then return false end
    return FDJ.RunLog.EndRun(run)
end

function FDJ.ResetTrackedRun()
    local run = TrackedRun()
    if FDJ.EndTrackedRun() then
        -- resetblank: the tracker stays up, at 0 with every boss alive,
        -- until the next kill starts the new run
        if run and FDJ.StartBlankRun then FDJ.StartBlankRun(run) end
        if FDJ.UpdateRunTracker then FDJ.UpdateRunTracker() end
        print("|cffd8a83cDungeonJournal|r " .. L("TRACKER_NEW_RUN_DONE"))
        return true
    end
    return false
end

-- padpopup (2.1.3): the reset question with the gamepad on, in a window of
-- the journal's own (the game's popup would taint gamepad input): the same
-- look, text and Yes / No as the game's.
-- A controller is turned on in the game's settings and connected.
function FDJ.ControllerConnected()
    if not (GetCVarBool and GetCVarBool("GamePadEnable")) then return false end
    if not (C_GamePad and type(C_GamePad.GetAllDeviceIDs) == "function") then return false end
    local ok, ids = pcall(C_GamePad.GetAllDeviceIDs)
    return ok and type(ids) == "table" and #ids > 0 or false
end

function FDJ.AskResetTracker()
    local f = FDJ.resetAskFrame
    if not f then
        f = CreateFrame("Frame", "ForeverDungeonJournalResetAsk", UIParent, "BackdropTemplate")
        FDJ.resetAskFrame = f
        f:SetSize(320, 104)
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        if f.SetBackdrop then
            f:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 },
            })
        end
        f.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        f.text:SetPoint("TOP", 0, -20)
        f.text:SetWidth(280)
        f.text:SetJustifyH("CENTER")
        local yes = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        yes:SetSize(110, 22)
        -- (padtight, M: "so much dead space between yes, no, and the last
        -- line": the buttons right under the text)
        yes:SetPoint("TOPRIGHT", f.text, "BOTTOM", -6, -10)
        yes:SetText(YES or "Yes")
        yes:SetScript("OnClick", function() f:Hide() FDJ.ResetTrackedRun() end)
        local no = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        no:SetSize(110, 22)
        no:SetPoint("TOPLEFT", f.text, "BOTTOM", 6, -10)
        no:SetText(NO or "No")
        no:SetScript("OnClick", function() f:Hide() end)
        f:Hide()
    end
    f.text:SetText(L("TRACKER_RESET_CONFIRM"))
    f:SetHeight(math.floor((f.text:GetStringHeight() or 14) + 0.5) + 67) -- (20 above the text, 10 to the buttons, 22 of buttons, 15 below)
    f:ClearAllPoints()
    f:SetPoint("TOP", UIParent, "TOP", 0, -135)
    f:Show()
end

if StaticPopupDialogs then
    StaticPopupDialogs["FDJ_TRACKER_RESET"] = {
        text = "%s",
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function() FDJ.ResetTrackedRun() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

do
    -- reset button, its tooltip, the confirmation, the chat line, the boss portraits' loot line,
    -- the second click that confirms with a controller on (padfocus, 2.0.12)
    local strings = {
        enUS = { "Reset Tracker", "Ends this run. The next kill starts a new run.", "Reset the tracker? This run ends and the next kill starts a new one.", "Tracker reset: the next kill starts a new run.", "Right-click to show loot", "Click again to confirm." },
        deDE = { "Tracker zurücksetzen", "Beendet diesen Run. Der nächste Kill startet einen neuen Run.", "Tracker zurücksetzen? Dieser Run endet und der nächste Kill startet einen neuen.", "Tracker zurückgesetzt: Der nächste Kill startet einen neuen Run.", "Rechtsklick, um die Beute zu zeigen", "Zum Bestätigen erneut klicken." },
        frFR = { "Réinitialiser le suivi", "Termine ce run. Le prochain kill lance un nouveau run.", "Réinitialiser le suivi ? Ce run se termine et le prochain kill en lance un nouveau.", "Suivi réinitialisé : le prochain kill lance un nouveau run.", "Clic droit pour afficher le butin", "Cliquez à nouveau pour confirmer." },
        esES = { "Reiniciar el seguimiento", "Termina esta run. La próxima muerte inicia una nueva run.", "¿Reiniciar el seguimiento? Esta run termina y la próxima muerte inicia una nueva.", "Seguimiento reiniciado: la próxima muerte inicia una nueva run.", "Clic derecho para mostrar el botín", "Haz clic otra vez para confirmar." },
        itIT = { "Resetta il tracker", "Termina questa run. La prossima uccisione avvia una nuova run.", "Resettare il tracker? Questa run finisce e la prossima uccisione ne avvia una nuova.", "Tracker resettato: la prossima uccisione avvia una nuova run.", "Clic destro per mostrare il bottino", "Clicca di nuovo per confermare." },
        ptBR = { "Reiniciar o rastreador", "Encerra esta run. A próxima morte inicia uma nova run.", "Reiniciar o rastreador? Esta run termina e a próxima morte inicia uma nova.", "Rastreador reiniciado: a próxima morte inicia uma nova run.", "Clique com o botão direito para mostrar o saque", "Clique de novo para confirmar." },
        ruRU = { "Сбросить трекер", "Завершает этот забег. Следующее убийство начнёт новый забег.", "Сбросить трекер? Этот забег завершится, а следующее убийство начнёт новый.", "Трекер сброшен: следующее убийство начнёт новый забег.", "Правый клик — показать добычу", "Нажмите ещё раз для подтверждения." },
        koKR = { "추적기 초기화", "이 런을 끝냅니다. 다음 처치로 새 런이 시작됩니다.", "추적기를 초기화할까요? 이 런이 끝나고 다음 처치로 새 런이 시작됩니다.", "추적기 초기화됨: 다음 처치로 새 런이 시작됩니다.", "우클릭하여 전리품 보기", "확인하려면 다시 클릭하세요." },
        zhCN = { "重置追踪器", "结束本轮。下一次击杀将开始新的一轮。", "重置追踪器？本轮将结束，下一次击杀将开始新的一轮。", "追踪器已重置：下一次击杀将开始新的一轮。", "右键点击显示掉落", "再次点击以确认。" },
        zhTW = { "重置追蹤器", "結束本輪。下一次擊殺將開始新的一輪。", "重置追蹤器？本輪將結束，下一次擊殺將開始新的一輪。", "追蹤器已重置：下一次擊殺將開始新的一輪。", "右鍵點擊顯示掉落", "再次點擊以確認。" },
    }
    strings.esMX = strings.esES
    local keys = { "TRACKER_RESET", "TRACKER_RESET_TIP", "TRACKER_RESET_CONFIRM", "TRACKER_NEW_RUN_DONE", "TRACKER_SHOW_LOOT", "TRACKER_RESET_AGAIN" }
    for locale, list in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for n, key in ipairs(keys) do
                if t[key] == nil then t[key] = list[n] end
            end
        end
    end
end

-- ------------------------------------------------------------ /dj testlog
-- 2.0.4: a made-up run of any dungeon, on the tracker and in the Character
-- Logs, to check its bosses, portraits and layout. Kept for this session
-- only: never saved, never in the real log (it can't push real runs out).
--   /dj testlog            the list of dungeons and their abbreviations
--   /dj testlog rfc        half the bosses down, the clock running
--   /dj testlog rfc done   all bosses down, completed
--   /dj testlog off        all test runs gone
FDJ.TESTLOG_DUNGEONS = {
    { "rfc", "Ragefire Chasm" }, { "wc", "Wailing Caverns" }, { "dm", "The Deadmines" },
    { "sfk", "Shadowfang Keep" }, { "bfd", "Blackfathom Deeps" }, { "stocks", "The Stockade" },
    { "gnomer", "Gnomeregan" }, { "rfk", "Razorfen Kraul" }, { "smgy", "Scarlet Monastery: Graveyard" },
    { "smlib", "Scarlet Monastery: Library" }, { "smarm", "Scarlet Monastery: Armory" },
    { "smcath", "Scarlet Monastery: Cathedral" }, { "rfd", "Razorfen Downs" }, { "ulda", "Uldaman" },
    { "zf", "Zul'Farrak" }, { "mara", "Maraudon" }, { "st", "Sunken Temple" }, { "brd", "Blackrock Depths" },
    { "lbrs", "Lower Blackrock Spire" }, { "ubrs", "Upper Blackrock Spire" }, { "dme", "Dire Maul: East" },
    { "dmw", "Dire Maul: West" }, { "dmn", "Dire Maul: North" }, { "scholo", "Scholomance" },
    { "stratlive", "Stratholme: Living" }, { "stratud", "Stratholme: Undead" },
    { "hot", "Hall of Thanes" }, { "rol", "Ruins of Lordaeron" }, { "dala", "City of Dalaran" },
    { "exca", "Excavation Site: Wetlands" }, { "alcaz", "Alcaz Prison" }, { "bmh", "Blackmaw Hold" },
    { "krol", "Krol'dok Stronghold" }, { "shaper", "Shaper's Terrace" }, { "dc", "The Drowned City" },
}
FDJ.testRuns = FDJ.testRuns or {}

-- the real runs, then this session's test runs (newest at the top)
function FDJ.RunLogListRuns()
    local real = FDJ.RunLog and FDJ.RunLog.Runs() or {}
    if #FDJ.testRuns == 0 then return real end
    local all = {}
    for _, r in ipairs(real) do all[#all + 1] = r end
    for _, r in ipairs(FDJ.testRuns) do all[#all + 1] = r end
    return all
end

function FDJ.RunLogTestRemove(run)
    for i = #FDJ.testRuns, 1, -1 do
        if FDJ.testRuns[i] == run then table.remove(FDJ.testRuns, i) end
    end
    if FDJ.testRun == run then FDJ.testRun = nil end
    FDJ.UpdateRunTracker()
    FDJ.RefreshRunLog()
end

-- notest (2.0.13, M 19 Nov 2026): the test command (FDJ.RunLogTest) is
-- out of the release; it stays in the vault build.

local tracker
-- Dragging the tracker: by its top part (title, time and XP).
function FDJ.RunTrackerDrag(start)
    local t = tracker
    if not t then return end
    -- locktracker (2.0.11): Options > Dungeon Tracker > Lock Tracker
    if start and FDJ.TrackerOption("lock") then return end
    if start then
        t:StartMoving()
        t.fdjMoving = true
    elseif t.fdjMoving then
        t.fdjMoving = nil
        t.fdjDragStop = GetTime()
        t:StopMovingOrSizing()
        local point, _, rel, x, y = t:GetPoint(1)
        TrackerDB().point = { point, rel, x, y }
    end
end
local function Draggable(f)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() FDJ.RunTrackerDrag(true) end)
    f:SetScript("OnDragStop", function() FDJ.RunTrackerDrag(false) end)
end

-- Shown only when the player explicitly closes the real dungeon tracker
-- with its X. Match the original "New Dungeon Tracker" notice styling,
-- but use an OK-only message so players learn the recovery command.
local trackerClosedNotice
local function ShowTrackerClosedNotice()
    -- Once per account across sessions and characters.
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    if ForeverDungeonJournalDB.trackerClosedNoticeShown then return end
    ForeverDungeonJournalDB.trackerClosedNoticeShown = true
    if not trackerClosedNotice then
        local h = CreateFrame("Frame", "ForeverDungeonJournalTrackerClosedNotice", UIParent, "BackdropTemplate")
        trackerClosedNotice = h
        h:SetSize(380, 102)
        h:SetFrameStrata("DIALOG")
        h:SetClampedToScreen(true)
        h:EnableMouse(true)
        h:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        h:SetBackdropColor(0, 0, 0, 1)
        h:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        h.title = h:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightLarge")
        h.title:SetPoint("TOP", 0, -12)
        h.title:SetWidth(350)
        h.title:SetJustifyH("CENTER")
        h.title:SetTextColor(1, 1, 1)
        h.title:SetShadowColor(0, 0, 0, 1)
        h.title:SetShadowOffset(1, -1)
        h.help = h:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightLarge")
        h.help:SetPoint("TOP", h.title, "BOTTOM", 0, -7)
        h.help:SetWidth(350)
        h.help:SetJustifyH("CENTER")
        h.help:SetTextColor(1, 0.82, 0.27)
        h.help:SetShadowColor(0, 0, 0, 1)
        h.help:SetShadowOffset(1, -1)
        h.ok = CreateFrame("Button", nil, h, "UIPanelButtonTemplate")
        FDJ.OwnFonts(h.ok) -- ownfonts (2.0.8)
        h.ok:SetSize(96, 26)
        h.ok:SetPoint("TOP", h.help, "BOTTOM", 0, -8)
        h.ok:SetNormalFontObject("ForeverDJ_GameFontNormalLarge")
        h.ok:SetHighlightFontObject("ForeverDJ_GameFontHighlightLarge")
        h.ok:SetText(OKAY or "OK")
        h.ok:SetScript("OnClick", function() h:Hide() end)
        h:Hide()
    end
    local h = trackerClosedNotice
    h.title:SetText(L("TRACKER_CLOSED_TITLE"))
    h.help:SetText(L("TRACKER_CLOSED_HELP"))
    -- Fit wrapped translations while keeping the button close to the message.
    h:SetHeight(12 + h.title:GetStringHeight() + 7 + h.help:GetStringHeight() + 8 + 26 + 10)
    h:ClearAllPoints()
    if tracker then
        -- Replaces the vanished tracker in the same part of the screen.
        h:SetPoint("CENTER", tracker, "CENTER", 0, 0)
    else
        h:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    h:Show()
end

local function BuildTracker()
    local t = CreateFrame("Frame", "ForeverDungeonJournalRunTracker", UIParent, "BackdropTemplate")
    tracker = t
    t:SetSize(236, 100)
    t:SetBackdrop(BACKDROP)
    t:SetBackdropColor(0.07, 0.065, 0.06, 0.88)
    t:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
    t:SetFrameStrata("MEDIUM")
    t:SetClampedToScreen(true)
    t:SetMovable(true)
    t:EnableMouse(true)
    -- the grab area: everything above the line
    local handle = CreateFrame("Frame", nil, t)
    handle:SetPoint("TOPLEFT", 0, 0)
    handle:SetPoint("TOPRIGHT", -26, 0)
    handle:SetHeight(70)
    handle:EnableMouse(true)
    Draggable(handle)
    handle:SetScript("OnMouseUp", function(self, button) if button == "RightButton" then ShowTrackerMenu(t) end end)
    t:SetScript("OnMouseUp", function(self, button) if button == "RightButton" then ShowTrackerMenu(t) end end)
    t.handle = handle
    local scale = tonumber(TrackerDB().scale)
    if scale and scale >= 0.5 and scale <= 2.5 then t:SetScale(scale) end
    local p = TrackerDB().point
    if type(p) == "table" and p[1] then
        t:SetPoint(p[1], UIParent, p[2] or p[1], tonumber(p[3]) or 0, tonumber(p[4]) or 0)
    else
        t:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -260, -220)
    end

    -- The Dungeon Journal's own icon (the minimap button's book) before the name.
    t.logo = t:CreateTexture(nil, "ARTWORK")
    t.logo:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    t.logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t.logo:SetSize(16, 16)
    t.logo:SetPoint("TOPLEFT", 9, -7)
    t.title = t:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormal")
    t.title:SetPoint("LEFT", t.logo, "RIGHT", 5, 0)
    t.title:SetJustifyH("LEFT")
    t.title:SetWordWrap(false)
    t.title:SetTextColor(1.00, 0.78, 0.20)

    -- 2.0.4: reset the tracker (the dungeon was reset and nothing told us):
    -- right after the dungeon's name, away from the X. The game's own
    -- refresh button, as on the Looking For Group panel.
    local reset = CreateFrame("Button", nil, t)
    reset:SetSize(27, 27) -- size picked in game with the resizer (2.0.4)
    reset:SetPoint("LEFT", t.title, "RIGHT", 4, 0)
    reset:SetFrameLevel(handle:GetFrameLevel() + 5)
    reset:SetNormalTexture("Interface\\Buttons\\UI-SquareButton-Up")
    reset:SetPushedTexture("Interface\\Buttons\\UI-SquareButton-Down")
    reset:SetDisabledTexture("Interface\\Buttons\\UI-SquareButton-Disabled")
    reset:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    reset.Icon = reset:CreateTexture(nil, "ARTWORK", nil, 5)
    reset.Icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    reset.Icon:SetSize(13, 13)
    reset.Icon:SetPoint("CENTER", -0.5, 0)
    reset:SetScript("OnMouseDown", function(self) self.Icon:SetPoint("CENTER", -1.5, -1) end)
    reset:SetScript("OnMouseUp", function(self) self.Icon:SetPoint("CENTER", -0.5, 0) end)
    reset:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L("TRACKER_RESET"), 1, 0.82, 0)
        GameTooltip:AddLine(L("TRACKER_RESET_TIP"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    reset:SetScript("OnLeave", function() GameTooltip:Hide() end)
    reset:SetScript("OnClick", function(self)
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
        GameTooltip:Hide()
        -- padfocus (2.0.12, kaanu): with the gamepad on, a StaticPopup from addon
        -- code taints gamepad input until /reload. padpopup (2.1.3, M 21 Nov
        -- 2026, his controller setting on and the second click asked for:
        -- "we had a pop-up. What happened?"): the same question in the
        -- journal's own little window instead, Yes / No, not the game's popup.
        -- padreal (2.1.3, M 21 Nov 2026 on keyboard and mouse: "I'm not
        -- using the controller, so why did it detect?"): the game's controller
        -- setting can be on with no controller there. Only with a controller
        -- connected; else the game's own popup, as always.
        if FDJ.ControllerConnected and FDJ.ControllerConnected() and FDJ.AskResetTracker then
            FDJ.AskResetTracker()
        elseif StaticPopup_Show and StaticPopupDialogs and StaticPopupDialogs.FDJ_TRACKER_RESET then
            StaticPopup_Show("FDJ_TRACKER_RESET", L("TRACKER_RESET_CONFIRM"))
        else
            FDJ.ResetTrackedRun()
        end
    end)
    reset:Hide()
    t.reset = reset

    local close = CreateFrame("Button", nil, t, "UIPanelCloseButton")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function()
        FDJ.ToggleRunTracker(false)
        if FDJ.trackerHint then FDJ.trackerHint:Hide() end
        -- hidetracker: Options > Dungeon Tracker > Hide Tracker ticks itself
        FDJ.SetTrackerHidden(true)
        if FDJ.RefreshRunLog then FDJ.RefreshRunLog() end
        ShowTrackerClosedNotice()
    end)
    t.close = close -- locktracker

    t.timeLabel = t:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    t.timeLabel:SetPoint("TOPLEFT", 10, -30)
    t.timeLabel:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    t.time = t:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightLarge")
    t.time:SetPoint("TOPLEFT", t.timeLabel, "BOTTOMLEFT", 0, -3)

    t.xpLabel = t:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    t.xpLabel:SetPoint("TOPLEFT", 82, -30)
    t.xpLabel:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    t.xp = t:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightLarge")
    t.xp:SetPoint("TOPLEFT", t.xpLabel, "BOTTOMLEFT", 0, -3)
    -- Gold column (the money the run earned), next to Mobs XP.
    t.goldLabel = t:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    t.goldLabel:SetPoint("TOPLEFT", 152, -30)
    t.goldLabel:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    t.gold = t:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightLarge")
    t.gold:SetPoint("TOPLEFT", t.goldLabel, "BOTTOMLEFT", 0, -3)

    t.line = t:CreateTexture(nil, "ARTWORK")
    t.line:SetColorTexture(0.54, 0.39, 0.17, 0.6)
    t.line:SetHeight(1)
    t.line:SetPoint("TOPLEFT", 8, -70)
    t.line:SetPoint("TOPRIGHT", -8, -70)

    t.raresLabel = t:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontNormalSmall")
    t.raresLabel:SetTextColor(1.0, 0.82, 0.0)
    t.raresLabel:Hide()

    -- Size grip (bottom right): drag to make the whole tracker bigger or
    -- smaller, right-click for 100%. The top left corner stays put.
    local grip = CreateFrame("Button", nil, t)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(t:GetFrameLevel() + 20)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:RegisterForClicks("RightButtonUp")
    t.sizeText = t:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    t.sizeText:SetPoint("BOTTOMRIGHT", grip, "TOPRIGHT", 0, 2)
    t.sizeText:Hide()
    local function Pin(newScale)
        -- keep the top left corner where it is on screen
        local es = t:GetEffectiveScale()
        local left, top = t:GetLeft() * es, t:GetTop() * es
        t:SetScale(newScale)
        es = t:GetEffectiveScale()
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / es, top / es)
    end
    local function Save()
        local db = TrackerDB()
        db.scale = math.floor(t:GetScale() * 100 + 0.5) / 100
        local point, _, rel, x, y = t:GetPoint(1)
        db.point = { point, rel, x, y }
    end
    local function Announce()
        print("|cffffd100Dungeon Journal|r tracker size: " .. math.floor(t:GetScale() * 100 + 0.5) .. "%")
    end
    grip:SetScript("OnClick", function()
        Pin(1)
        Save()
        Announce()
    end)
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local es = t:GetEffectiveScale()
        local cx = GetCursorPosition()
        self.left = t:GetLeft() * es
        self.width0 = math.max(20, cx - self.left)
        self.scale0 = t:GetScale()
        t.sizeText:Show()
        self.sizing = true
        self:SetScript("OnUpdate", function()
            local x = GetCursorPosition()
            local sc = self.scale0 * (x - self.left) / self.width0
            sc = math.max(0.6, math.min(2.0, sc))
            sc = math.floor(sc * 100 + 0.5) / 100
            if math.abs(sc - t:GetScale()) >= 0.01 then Pin(sc) end
            t.sizeText:SetText(math.floor(t:GetScale() * 100 + 0.5) .. "%")
        end)
    end)
    grip:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" or not self.sizing then return end
        self.sizing = nil
        self:SetScript("OnUpdate", nil)
        t.sizeText:Hide()
        Save()
        Announce()
    end)
    t.grip = grip

    t.portraits = {}
    local acc = 0
    t:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 1 then return end
        acc = 0
        FDJ.UpdateRunTracker()
        if FDJ.RunLogChimeTick then pcall(FDJ.RunLogChimeTick) end
    end)
    t:Hide()
    return t
end

local PER_ROW, SIZE, GAP = 5, 38, 6

-- Faction-only bosses remain visible in the Dungeon Journal, but the
-- on-screen tracker must not ask a player to kill a friendly boss (e.g.
-- The Lost Dwarves in Uldaman for Alliance players).
local function TrackerPlayerFaction()
    if type(UnitFactionGroup) ~= "function" then return nil end
    local ok, faction = pcall(UnitFactionGroup, "player")
    if not ok or type(faction) ~= "string" then return nil end
    if type(issecretvalue) == "function" and issecretvalue(faction) then return nil end
    return faction
end

local function TrackerBossAllowed(b, faction)
    if b.trackerHidden then return false end
    return not b.factionOnly or not faction or b.factionOnly == faction
end

-- altartracker (2.0.49): a journal group (the Sunken Temple's "Altar
-- Bosses") is one portrait on the tracker. Its bosses (the six troll
-- guardians) are no bosses of the run (they die as trash does), so each is
-- found among the run's kills by its NPC ID or its name.
local function GroupChildren(d, group)
    local list = {}
    for _, id in ipairs(group.children or {}) do
        for _, b in ipairs((d and d.bosses) or {}) do
            if type(b) == "table" and b.childOf == group.name and tonumber(b.npcID) == tonumber(id) then
                list[#list + 1] = b
                break
            end
        end
    end
    return list
end

local function KillOfChild(run, child)
    local names = {}
    local function add(n) if type(n) == "string" and n ~= "" then names[n:lower()] = true end end
    add(child.name)
    for _, a in ipairs(child.aliases or {}) do add(a) end
    if FDJ.LocalizeBossName then
        local ok, n = pcall(FDJ.LocalizeBossName, child.name)
        if ok then add(n) end
    end
    if child.npcID and FDJ.RunLog and FDJ.RunLog.NpcName then
        local ok, n = pcall(FDJ.RunLog.NpcName, child.npcID)
        if ok then add(n) end
    end
    local id = tonumber(child.npcID)
    for _, k in ipairs(run.kills or {}) do
        if type(k) == "table" and ((id and tonumber(k.n) == id) or (type(k.m) == "string" and names[k.m:lower()])) then
            return k
        end
    end
end

-- The group's entry: its bosses (each with its kill), how many are dead,
-- and a kill of its own once all of them are (the last one's time, all
-- their loot), so its portrait is crossed out like a boss's.
function FDJ.TrackerGroupEntry(run, d, group)
    local e = { boss = group, group = true, children = {}, dead = 0 }
    local last, loot = nil, {}
    for _, c in ipairs(GroupChildren(d, group)) do
        local k = KillOfChild(run, c)
        e.children[#e.children + 1] = { boss = c, kill = k }
        if k then
            e.dead = e.dead + 1
            if not last or (tonumber(k.t) or 0) > (tonumber(last.t) or 0) then last = k end
            for _, item in ipairs(k.loot or {}) do loot[#loot + 1] = item end
        end
    end
    if #e.children > 0 and e.dead == #e.children then
        e.kill = { t = last.t, loot = loot, group = true }
    end
    return e
end

do
    -- the group portrait's tooltip: how many are dead, and the click
    local strings = {
        enUS = { "%d of %d killed", "Left-click to show or hide the list" },
        deDE = { "%d von %d getötet", "Linksklick, um die Liste ein- oder auszublenden" },
        frFR = { "%d sur %d tués", "Clic gauche pour afficher ou masquer la liste" },
        esES = { "%d de %d muertos", "Clic izquierdo para mostrar u ocultar la lista" },
        itIT = { "%d su %d uccisi", "Clic sinistro per mostrare o nascondere la lista" },
        ptBR = { "%d de %d abatidos", "Clique com o botão esquerdo para mostrar ou ocultar a lista" },
        ruRU = { "Убито: %d из %d", "Левый клик — показать или скрыть список" },
        koKR = { "%d/%d 처치", "좌클릭하여 목록 보이기/숨기기" },
        zhCN = { "已击杀 %d/%d", "左键点击显示或隐藏列表" },
        zhTW = { "已擊殺 %d/%d", "左鍵點擊顯示或隱藏列表" },
    }
    strings.esMX = strings.esES
    for locale, pair in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            if t.TRACKER_GROUP_KILLED == nil then t.TRACKER_GROUP_KILLED = pair[1] end
            if t.TRACKER_GROUP_CLICK == nil then t.TRACKER_GROUP_CLICK = pair[2] end
        end
    end
end

-- The tracker's two rows: the bosses (journal order, killed or not) and the
-- dungeon's rares (all of them: not seen yet, found alive, or killed).
local function TrackerLists(run)
    FDJ.RunLogFixDungeon(run)
    local bosses, rares = {}, {}
    local test = FDJ.RUNLOG_TEST_RARES and FDJ.RUNLOG_TEST_RARES[run.dungeon]
    local faction = TrackerPlayerFaction()
    local d = run.dungeon and FDJ.DB and FDJ.DB[run.dungeon]
    -- Also exclude faction-only and explicitly hidden bosses from fallback
    -- kills in old runs; these can lack the original journal boss record.
    local excludedNames = {}
    for _, b in ipairs((d and d.bosses) or {}) do
        if type(b) == "table" and type(b.name) == "string" and not TrackerBossAllowed(b, faction) then
            excludedNames[b.name] = true
            for _, alias in ipairs(b.aliases or {}) do excludedNames[alias] = true end
        end
    end
    for _, e in ipairs(BossList(run)) do
        if not e.boss.rare and not test and not excludedNames[e.boss.name]
            and TrackerBossAllowed(e.boss, faction) then
            bosses[#bosses + 1] = e
        end
    end
    -- altartracker (2.0.49): a group's portrait, where the journal lists it
    if not test and d then
        local at = {}
        for i, b in ipairs(d.bosses or {}) do
            if type(b) == "table" and type(b.name) == "string" and at[b.name] == nil then at[b.name] = i end
        end
        local function Index(e)
            if e.members and e.members[1] then return at[e.members[1].name] end
            return e.boss and at[e.boss.name]
        end
        for gi, b in ipairs(d.bosses or {}) do
            if type(b) == "table" and type(b.children) == "table" and type(b.name) == "string"
                and TrackerBossAllowed(b, faction) then
                local entry = FDJ.TrackerGroupEntry(run, d, b)
                if #entry.children > 0 then
                    local pos = #bosses + 1
                    for i, e in ipairs(bosses) do
                        local ei = Index(e)
                        if ei and ei > gi then pos = i break end
                    end
                    table.insert(bosses, pos, entry)
                end
            end
        end
    end
    local killed = {}
    for _, k in ipairs(run.kills or {}) do
        if k.b and not killed[k.b] then killed[k.b] = k end
    end
    for _, b in ipairs((d and d.bosses) or {}) do
        if type(b) == "table" and (b.rare or (test and not b.trash and not b.recipeTab))
            and type(b.name) == "string" and TrackerBossAllowed(b, faction) then
            rares[#rares + 1] = { boss = b, kill = killed[b.name], seen = run.rareSeen and run.rareSeen[b.name],
                ack = run.rareAck and run.rareAck[b.name] }
        end
    end
    return bosses, rares
end

-- 2.0.4: a click on a boss's portrait opens a line of its loot (the
-- journal's) right under the portrait; a click on that boss again closes it.
-- One line at a time.

-- How many bosses (trash drops too) list each recipe, in every dungeon.
function FDJ.TrackerRecipeSources()
    if FDJ.trackerRecipeSources then return FDJ.trackerRecipeSources end
    local count = {}
    for _, d in pairs(FDJ.DB or {}) do
        for _, b in ipairs((type(d) == "table" and d.bosses) or {}) do
            local seen = {}
            for _, e in ipairs((type(b) == "table" and b.loot) or {}) do
                local id = type(e) == "table" and tonumber(e[1])
                if id and type(e[3]) == "string" and e[3]:find("^Recipe") and not seen[id] then
                    seen[id] = true
                    count[id] = (count[id] or 0) + 1
                end
            end
        end
    end
    FDJ.trackerRecipeSources = count
    return count
end

-- Repeatable quests: their item keeps showing (it's needed again). The
-- journal's own repeatable flags, plus these (classicdb.ch: Repeatable).
FDJ.TRACKER_REPEATABLE_QUESTS = FDJ.TRACKER_REPEATABLE_QUESTS or {
    [5122] = true, -- The Medallion of Faith (Aurius, Stratholme)
}

-- The quests each quest item is for (it starts them or they need it).
function FDJ.TrackerQuestItemQuests()
    if FDJ.trackerQuestItems then return FDJ.trackerQuestItems end
    local map = {}
    local function add(item, questID)
        local id = type(item) == "table" and tonumber(item[1])
        questID = tonumber(questID)
        if not (id and questID) then return end
        map[id] = map[id] or {}
        map[id][questID] = true
    end
    local function scan(q, questID)
        if type(q) ~= "table" then return end
        if q.repeatable and tonumber(questID) then FDJ.TRACKER_REPEATABLE_QUESTS[tonumber(questID)] = true end
        add(q.startItem, questID)
        add(q.requiredItem, questID)
        for _, item in ipairs(q.requiredItems or {}) do add(item, questID) end
    end
    for _, d in pairs(FDJ.DB or {}) do
        for _, q in ipairs((type(d) == "table" and d.quests) or {}) do scan(q, q.id) end
    end
    for questID, q in pairs(FDJ.QUEST_PREREQ_DETAILS or {}) do scan(q, questID) end
    for _, floors in pairs(FDJ.MAP_QUEST_PINS or {}) do
        for _, floor in ipairs(type(floors) == "table" and floors or {}) do
            for _, spot in ipairs((type(floor) == "table" and floor.spots) or {}) do
                for _, q in ipairs((type(spot) == "table" and spot.quests) or {}) do
                    if type(q) == "table" and q.item then add({ q.item }, q.id) end
                end
            end
        end
    end
    FDJ.trackerQuestItems = map
    return map
end

-- The boss's loot for the tracker's line:
--   recipes only when epic or dropped by this boss alone (not the ones
--   shared by several bosses);
--   quest items no more once you have done every quest they are for
--   (never for a repeatable quest).
function FDJ.TrackerBossLoot(boss)
    local items = {}
    local recipes = FDJ.TrackerRecipeSources()
    local quests = FDJ.TrackerQuestItemQuests()
    for _, e in ipairs((boss and boss.loot) or {}) do
        local id = type(e) == "table" and tonumber(e[1])
        local keep = id ~= nil
        if keep and type(e[3]) == "string" and e[3]:find("^Recipe") then
            keep = (tonumber(e[4]) or 0) >= 4 or (recipes[id] or 0) <= 1
        end
        if keep and quests[id] and FDJ.QuestTurnedIn then
            local allDone = true
            for questID in pairs(quests[id]) do
                if FDJ.TRACKER_REPEATABLE_QUESTS[questID] or not FDJ.QuestTurnedIn(questID) then allDone = false break end
            end
            if allDone then keep = false end
        end
        if keep then items[#items + 1] = e end
    end
    return items
end

-- A rare's tooltip on the tracker: the same loot line as the bosses'.
function FDJ.TrackerRareLootHint(boss)
    if boss and #FDJ.TrackerBossLoot(boss) > 0 then
        GameTooltip:AddLine(L("TRACKER_SHOW_LOOT"), 1, 0.82, 0)
        GameTooltip:Show()
    end
end

function FDJ.TrackerLootIcon(row)
    local b = CreateFrame("Button", nil, row, "BackdropTemplate")
    b:SetSize(24, 24)
    b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnEnter", function(self)
        if not self.item then return end
        -- the journal's own item tooltip (Forever item data, notes)
        if FDJ.ShowJournalItemTooltip and FDJ.ShowJournalItemTooltip(self, self.item) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. tostring(self.item[1]))
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        if FDJ.HideJournalItemTooltip then FDJ.HideJournalItemTooltip() end
        GameTooltip:Hide()
    end)
    -- 2.0.4: Shift-click links the item in chat, as in the journal.
    b:SetScript("OnClick", function(self)
        local id = self.item and tonumber(self.item[1])
        if not (id and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink) then return end
        local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        local link = getInfo and select(2, getInfo(id))
        if link then
            ChatEdit_InsertLink(link)
        elseif C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID, id)
        end
    end)
    return b
end

function FDJ.TrackerLootToggle(f)
    local t = tracker
    if not (t and f and f.boss) then return end
    -- bosshint: they found out: the "Right-click bosses" note is done
    if FDJ.BossHintDone and ForeverDungeonJournalDB and not ForeverDungeonJournalDB.bossHintShown then FDJ.BossHintDone() end
    local row = t.lootRow
    if row and row:IsShown() and row.portrait == f and row.boss == f.boss then
        row:Hide()
        return
    end
    local items = FDJ.TrackerBossLoot(f.boss)
    if #items == 0 then
        if row then row:Hide() end
        return
    end
    if not row then
        row = CreateFrame("Frame", nil, t, "BackdropTemplate")
        row:SetBackdrop(BACKDROP)
        row:SetBackdropColor(0.07, 0.065, 0.06, 0.96)
        row:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
        row:EnableMouse(true)
        row.icons = {}
        -- Out of the tracker and the line for 2 seconds: it closes.
        row:SetScript("OnUpdate", function(self, elapsed)
            if (tracker and tracker:IsMouseOver()) or self:IsMouseOver() then
                self.away = 0
                return
            end
            self.away = (self.away or 0) + elapsed
            if self.away >= 2 then self:Hide() end
        end)
        row:SetScript("OnHide", function() if t.lootGlow then t.lootGlow:Hide() end end)
        t.lootRow = row
    end
    row.away = 0
    -- The boss whose loot is open gets the soft golden glow of the journal's
    -- emblems (the Sleeping Bag's), behind its portrait.
    if not t.lootGlow then
        t.lootGlow = t:CreateTexture(nil, "ARTWORK", nil, -8)
        t.lootGlow:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\TickGlow")
        t.lootGlow:SetBlendMode("ADD")
        t.lootGlow:SetVertexColor(1, 0.82, 0.35)
        t.lootGlow:SetAlpha(0.75)
    end
    local glowSize = math.floor((f:GetWidth() or 36) * 1.92 + 0.5)
    t.lootGlow:SetSize(glowSize, glowSize)
    t.lootGlow:ClearAllPoints()
    t.lootGlow:SetPoint("CENTER", f, "CENTER", 0, 0)
    t.lootGlow:Show()
    row:SetFrameLevel(t:GetFrameLevel() + 30)
    for i, e in ipairs(items) do
        local b = row.icons[i] or FDJ.TrackerLootIcon(row)
        row.icons[i] = b
        b:ClearAllPoints()
        -- 2.0.4: at most 5 to a row, then the next row below
        b:SetPoint("TOPLEFT", row, "TOPLEFT", 5 + ((i - 1) % 5) * 27, -5 - math.floor((i - 1) / 5) * 27)
        b.item = e
        local id = tonumber(e[1])
        local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id))
        b.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local q = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[tonumber(e[4]) or 1]
        if q then b:SetBackdropBorderColor(q.r, q.g, q.b, 1) else b:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) end
        b:Show()
    end
    for i = #items + 1, #row.icons do row.icons[i]:Hide() row.icons[i].item = nil end
    local cols, rows = math.min(#items, 5), math.ceil(#items / 5)
    row:SetSize(10 + cols * 27 - 3, 10 + rows * 27 - 3)
    row:SetClampedToScreen(true)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -2)
    row.portrait, row.boss = f, f.boss
    row:Show()
end

-- altartracker (2.0.49): a group's portrait has a small + on its edge. It
-- (or a left-click on the portrait) opens a row of the group's bosses, each
-- crossed out once killed; with all of them dead the group's own portrait
-- is crossed out too. Open or closed is kept (per character) until clicked
-- again. altarbottom (2.0.50): the + on the portrait's bottom edge (was the
-- top), the row inside the tracker under all the bosses (was a box over
-- the portrait).
local CHILD_SIZE, CHILD_GAP = 32, 5

local function GroupOpen(name)
    local db = TrackerDB()
    return type(db.groupOpen) == "table" and db.groupOpen[name] == true
end

function FDJ.TrackerGroupPlus(f)
    if not (f and f.group) then
        if f and f.plus then f.plus:Hide() end
        return
    end
    local p = f.plus
    if not p then
        p = CreateFrame("Button", nil, f)
        p:SetSize(14, 14) -- altarbottom (2.0.50): 14, so it fits the gap to the row below
        -- altarbottom (2.0.50): on the bottom edge; 2.0.51: a little higher,
        -- clear of the portrait under it
        p:SetPoint("CENTER", f, "BOTTOM", 0, 5)
        p:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
        p:SetScript("OnClick", function() FDJ.TrackerGroupToggle(f) end)
        p:SetScript("OnEnter", function()
            local h = f:GetScript("OnEnter")
            if h then h(f) end
        end)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.plus = p
    end
    p:SetFrameLevel(f:GetFrameLevel() + 6)
    local art = GroupOpen(f.group.boss.name) and "Interface\\Buttons\\UI-MinusButton-" or "Interface\\Buttons\\UI-PlusButton-"
    if p.fdjArt ~= art then
        p.fdjArt = art
        p:SetNormalTexture(art .. "Up")
        p:SetPushedTexture(art .. "Down")
    end
    p:Show()
end

function FDJ.TrackerGroupToggle(f)
    if not (f and f.group and f.group.boss) then return end
    local db = TrackerDB()
    if type(db.groupOpen) ~= "table" then db.groupOpen = {} end
    local name = f.group.boss.name
    db.groupOpen[name] = (not db.groupOpen[name]) or nil
    if PlaySound and SOUNDKIT then
        pcall(PlaySound, db.groupOpen[name] and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end
    FDJ.UpdateRunTracker()
end

function FDJ.TrackerGroupTooltip(f)
    local g = f and f.group
    if not (g and g.children) then return end
    local all = #g.children > 0 and (g.dead or 0) == #g.children
    GameTooltip:AddLine(L("TRACKER_GROUP_KILLED", g.dead or 0, #g.children),
        all and 0.25 or 0.75, all and 1.0 or 0.72, all and 0.35 or 0.66)
    GameTooltip:AddLine(L("TRACKER_GROUP_CLICK"), 1, 0.82, 0)
    GameTooltip:Show()
    if FDJ.RefreshTooltipBacking then FDJ.RefreshTooltipBacking() end
end

-- y: where the bosses end on the tracker; returns where the row ends.
function FDJ.TrackerGroupRow(t, run, frames, y)
    local f
    for _, x in ipairs(frames or {}) do
        if x.group and type(x.group.children) == "table" and x.group.boss and x:IsShown() and GroupOpen(x.group.boss.name) then f = x break end -- (groupfix)
    end
    local row = t.groupRow
    if not f then
        if row then row:Hide() end
        return y
    end
    if not row then
        row = CreateFrame("Frame", nil, t, "BackdropTemplate")
        row:SetBackdrop(BACKDROP)
        row:SetBackdropColor(0.07, 0.065, 0.06, 0.96)
        row:SetBackdropBorderColor(0.48, 0.40, 0.27, 1)
        row:EnableMouse(true)
        row.portraits = {}
        t.groupRow = row
    end
    row:SetFrameLevel(t:GetFrameLevel() + 5)
    local list = f.group.children or {} -- (groupfix)
    local start = RunStart(run) or run.created
    for i, c in ipairs(list) do
        local p = row.portraits[i]
        if not p then
            p = Portrait(row, CHILD_SIZE)
            p:EnableMouse(true)
            p:SetScript("OnEnter", function(self) BossTooltip(self, self.boss, self.kill, self.runStart, false) end)
            p:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.portraits[i] = p
        end
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", row, "TOPLEFT", 5 + (i - 1) * (CHILD_SIZE + CHILD_GAP), -5)
        SetPortrait(p, run.dungeon, c.boss, c.kill ~= nil)
        p.kill, p.runStart = c.kill, start
        p:Show()
    end
    for i = #list + 1, #row.portraits do row.portraits[i]:Hide() end
    local w = 10 + #list * CHILD_SIZE + math.max(0, #list - 1) * CHILD_GAP
    local h = 10 + CHILD_SIZE
    row:SetSize(w, h)
    -- altarbottom (2.0.50): under the last row of bosses, centred
    local width = t:GetWidth() or 236
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", t, "TOPLEFT", math.max(4, math.floor((width - w) / 2)), -((tonumber(y) or 0) + 2))
    row:Show()
    return (tonumber(y) or 0) + 2 + h + GAP
end

local function PortraitButton(parent)
    local f = Portrait(parent, SIZE)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        BossTooltip(self, self.boss, self.kill, self.runStart, not self.isRare)
        if self.isRare then FDJ.TrackerRareLootHint(self.boss) end
        if self.group and FDJ.TrackerGroupTooltip then FDJ.TrackerGroupTooltip(self) end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            -- 2.0.4: a boss's or a rare's portrait (found or not) shows its loot
            if self.boss then FDJ.TrackerLootToggle(self) else ShowTrackerMenu(tracker) end
            return
        end
        -- a drag that ends here is not a click
        if tracker and (tracker.fdjMoving or (tracker.fdjDragStop and GetTime() - tracker.fdjDragStop < 0.2)) then return end
        -- altartracker (2.0.49): a group's portrait opens or closes its row
        if self.group and FDJ.TrackerGroupToggle then FDJ.TrackerGroupToggle(self) return end
        if self.boss and FDJ.RunLogAckRare then FDJ.RunLogAckRare(self.boss.name) end
    end)
    -- Glow for a rare found alive: the portrait itself lights up gold
    -- (a gold wash over it, pulsing), no ring around it.
    f.glow = f:CreateTexture(nil, "OVERLAY", nil, 6)
    f.glow:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    f.glow:SetBlendMode("ADD")
    f.glow:SetVertexColor(1.0, 0.72, 0.10, 1)
    f.glow:SetPoint("TOPLEFT", f.tex or f, "TOPLEFT", 0, 0)
    f.glow:SetPoint("BOTTOMRIGHT", f.tex or f, "BOTTOMRIGHT", 0, 0)
    f.glow:Hide()
    local ag = f.glow:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0.10)
    a:SetToAlpha(0.60)
    a:SetDuration(0.7)
    f.glowAnim = ag
    return f
end

-- A rare's name as this client shows it (for /targetexact).
local function RareTargetName(boss)
    if boss.npcID and FDJ.RunLog and FDJ.RunLog.NpcName then
        local n = FDJ.RunLog.NpcName(boss.npcID)
        if type(n) == "string" and n ~= "" then return n end
    end
    return BossLabel(boss.name)
end

-- Clicking a rare's portrait targets and skull-marks it. Targeting is a
-- protected action, so the click goes through a secure macro button laid
-- over the portrait (a child of UIParent, set up only out of combat).
local secureButtons = {}
local securePending = false
local function InCombat() return InCombatLockdown and InCombatLockdown() end

local function SecureButton(i)
    local b = secureButtons[i]
    if b then return b end
    b = CreateFrame("Button", "ForeverDungeonJournalRareTarget" .. i, UIParent, "SecureActionButtonTemplate")
    b.fdjSolidTooltip = true
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b:SetAttribute("type2", "fdjmenu") -- right-click: no game action, the Options menu
    b:SetFrameStrata("MEDIUM")
    b:SetScript("OnEnter", function(self)
        local f = self.portrait
        if not f or not f.boss then return end
        BossTooltip(self, f.boss, f.kill, f.runStart)
        if not f.kill then GameTooltip:AddLine(L("RUNLOG_RARE_CLICK"), 1, 0.82, 0) GameTooltip:Show() end
        FDJ.TrackerRareLootHint(f.boss)
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Clicking it stops the glow and the chime for that rare.
    b:SetScript("PostClick", function(self, button, down)
        if button == "RightButton" then
            -- 2.0.4: a rare's loot, as for bosses
            if not down and self.portrait then FDJ.TrackerLootToggle(self.portrait) end
            return
        end
        local f = self.portrait
        if f and f.boss and FDJ.RunLogAckRare then FDJ.RunLogAckRare(f.boss.name) end
    end)
    secureButtons[i] = b
    return b
end

-- Click areas sit on the screen where their portrait is (not anchored to
-- it), so the tracker can always be moved, in combat too; out of combat
-- they are put back on their portraits every second.
function FDJ.RunLogPlaceOnScreen(b, f)
    local cx, cy = f:GetCenter()
    if not cx then return end
    local fs = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    b:ClearAllPoints()
    b:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * fs, cy * fs)
    b:SetSize((f:GetWidth() or 0) * fs, (f:GetHeight() or 0) * fs)
end

local function LayoutSecure(rareFrames)
    if InCombat() then securePending = true return end
    securePending = false
    local shown = tracker and tracker:IsShown()
    for i, f in ipairs(rareFrames or {}) do
        local b = SecureButton(i)
        b.portrait = f
        FDJ.RunLogPlaceOnScreen(b, f)
        b:SetFrameLevel((tracker and tracker:GetFrameLevel() or 1) + 10)
        b:SetAttribute("macrotext", "/cleartarget\n/targetexact " .. RareTargetName(f.boss) .. "\n/tm 8")
        b:SetShown(shown and f:IsShown() and not f.kill)
    end
    -- The rest are let go of entirely (not even anchored), so the tracker
    -- can be moved in combat while no rare has been found.
    for i = #(rareFrames or {}) + 1, #secureButtons do
        secureButtons[i]:Hide()
        secureButtons[i]:ClearAllPoints()
        secureButtons[i].portrait = nil
    end
    if tracker then tracker.secureLive = shown and #(rareFrames or {}) or 0 end
end

-- Clicking a boss's portrait targets it (no mark; rares above also get the
-- skull). These click areas are not tied to the tracker: they sit on the
-- screen where the portraits are and are put back in place every second
-- out of combat, so the tracker itself can still be moved in combat (the
-- click areas then catch up once the fight is over).
local bossButtons = {}
local function BossButton(i)
    local b = bossButtons[i]
    if b then return b end
    b = CreateFrame("Button", "ForeverDungeonJournalBossTarget" .. i, UIParent, "SecureActionButtonTemplate")
    b.fdjSolidTooltip = true
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b:SetAttribute("type2", "fdjmenu") -- right-click: no game action, the Options menu
    b:SetScript("PostClick", function(self, button, down)
        -- 2.0.4: right-click shows the boss's loot (left-click targets it)
        if button == "RightButton" and not down and self.portrait then FDJ.TrackerLootToggle(self.portrait) end
    end)
    b:SetFrameStrata("MEDIUM")
    b:SetScript("OnEnter", function(self)
        local f = self.portrait
        if not f or not f.boss then return end
        BossTooltip(self, f.boss, f.kill, f.runStart, true)
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bossButtons[i] = b
    return b
end
local function LayoutBossButtons(frames)
    if InCombat() then return end
    local shown = tracker and tracker:IsShown()
    local us = UIParent:GetEffectiveScale()
    local n = 0
    for _, f in ipairs(frames or {}) do
        local cx, cy = f:GetCenter()
        if shown and cx and f:IsShown() and not f.kill and f.boss and not f.group and not f.fightGroup then
            n = n + 1
            local b = BossButton(n)
            b.portrait = f
            local fs = f:GetEffectiveScale() / us
            b:ClearAllPoints()
            b:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * fs, cy * fs)
            b:SetSize((f:GetWidth() or 0) * fs, (f:GetHeight() or 0) * fs)
            b:SetFrameLevel((tracker and tracker:GetFrameLevel() or 1) + 10)
            local macro = "/cleartarget\n/targetexact " .. RareTargetName(f.boss)
            if b.fdjMacro ~= macro then
                b.fdjMacro = macro
                b:SetAttribute("macrotext", macro)
            end
            b:Show()
        end
    end
    for i = n + 1, #bossButtons do
        bossButtons[i]:Hide()
        bossButtons[i].portrait = nil
    end
end

-- Shown when: turned on with Track on screen, or by itself in a dungeon
-- while in a group; never again for a run whose tracker was closed.
local function InGroup()
    if not IsInGroup then return false end
    local ok, g = pcall(IsInGroup)
    return ok and g and true or false
end

local function ShouldShow(run)
    if not run then return false end
    if run.test then return TrackerDB().dismissedRun ~= run.id end -- /dj testlog
    if FDJ.RunLog and FDJ.RunLog.IsAwaitingWing and FDJ.RunLog.IsAwaitingWing() then return false end
    if FDJ.TrackerOption("never") then return false end
    local db = TrackerDB()
    -- hidetracker: Options > Hide Tracker hides the run it was ticked for;
    -- a new run unticks it and the tracker works as usual
    if FDJ.TrackerOption("hide") then
        if db.hideRun ~= nil and db.hideRun == run.id then return false end
        ForeverDungeonJournalDB.trackerOptions.hide = nil
        db.hideRun = nil
        if FDJ.RefreshSettingsChecks then pcall(FDJ.RefreshSettingsChecks) end
    end
    if db.dismissedRun == run.id then return false end
    if db.on then return true end
    -- by itself only in a group, unless "Show Tracker for solo runs too"
    if not (InGroup() or FDJ.TrackerOption("solo")) or not FDJ.RunLog then return false end
    if FDJ.RunLog.Current() == run then return true end
    if run.blank then return true end -- resetblank: until the next kill
    -- Stepped out (a corpse run, a vendor trip) before the run is done: it
    -- stays up, for as long as coming back still continues the same run.
    return RunInProgress(run) and Now() - (run.lastSeen or run.created or 0) < 90 * 60
end

function FDJ.IsRunTrackerOn()
    return tracker ~= nil and tracker:IsShown()
end

function FDJ.UpdateRunTracker()
    local run = TrackedRun()
    if not ShouldShow(run) then
        if tracker and tracker.lootRow then tracker.lootRow:Hide() end
        if tracker and tracker:IsShown() then
            tracker:Hide()
            LayoutSecure({})
            LayoutBossButtons({})
        end
        return
    end
    local t = tracker or BuildTracker()
    t.run = run
    -- locktracker (2.0.11, M 18 Nov 2026: "once toggled, the tracker cant be
    -- moved, loses the bottom right re size corner, and loses the X. only
    -- right click to open option stays")
    local locked = FDJ.TrackerOption("lock")
    if t.close then t.close:SetShown(not locked) end
    if t.grip then t.grip:SetShown(not locked) end
    t.title:SetText(DungeonLabel(run))
    -- the name as wide as it is (cut short with "..." only when it has to),
    -- the reset button right after it while the run is going
    local canReset = (RunInProgress(run) and not run.blank) and true or false
    t.title:SetWidth(0)
    local full = (t.title.GetUnboundedStringWidth and t.title:GetUnboundedStringWidth()) or t.title:GetStringWidth() or 0
    t.title:SetWidth(math.max(1, math.min(full + 1, 236 - 30 - 26 - (canReset and t.reset and math.floor(t.reset:GetWidth() + 6.5) or 0))))
    if t.reset then t.reset:SetShown(canReset) end
    t.timeLabel:SetText(L("RUNLOG_TIME"))
    t.xpLabel:SetText(L("RUNLOG_MOBS_XP"))
    t.goldLabel:SetText(L("RUNLOG_GOLD"))
    local secs = Speed(run)
    t.time:SetText(secs and Duration(secs) or "0:00")
    if run.completed then t.time:SetTextColor(0.25, 1.0, 0.35) else t.time:SetTextColor(1, 1, 1) end
    t.xp:SetText(Thousands(MobXP(run)))
    t.gold:SetText(GoldText(run.money))
    -- Time | Mobs XP | Gold (no Mobs XP at the level cap), less the ones
    -- hidden in Options > Dungeon Tracker; none left: a slimmer tracker.
    local cols = {}
    if not FDJ.TrackerOption("hideTime") then cols[#cols + 1] = { t.timeLabel, t.time } end
    if not ShowsGold(run) and not FDJ.TrackerOption("hideXP") then cols[#cols + 1] = { t.xpLabel, t.xp } end
    if not FDJ.TrackerOption("hideGold") then cols[#cols + 1] = { t.goldLabel, t.gold } end
    for _, pair in ipairs({ { t.timeLabel, t.time }, { t.xpLabel, t.xp }, { t.goldLabel, t.gold } }) do
        pair[1]:Hide() pair[2]:Hide()
    end
    local xs = (#cols == 3 and { 10, 82, 152 }) or (#cols == 2 and { 10, 124 }) or { 10 }
    for i, pair in ipairs(cols) do
        pair[1]:ClearAllPoints()
        pair[1]:SetPoint("TOPLEFT", t, "TOPLEFT", xs[i], -30)
        pair[1]:Show() pair[2]:Show()
    end
    local head = #cols > 0 and 70 or 30
    t.line:ClearAllPoints()
    t.line:SetPoint("TOPLEFT", 8, -head)
    t.line:SetPoint("TOPRIGHT", -8, -head)
    if t.handle then t.handle:SetHeight(head) end

    local bosses, rares = TrackerLists(run)
    -- Options > Dungeon Tracker > Hide Bosses (rares too)
    if FDJ.TrackerOption("hideBosses") then bosses, rares = {}, {} end
    local start = RunStart(run) or run.created
    local width = 236
    local rowWidth = PER_ROW * SIZE + (PER_ROW - 1) * GAP
    local left = math.floor((width - rowWidth) / 2)
    local n, y = 0, head + 8
    local function Place(list, isRare)
        local frames = {}
        for i, e in ipairs(list) do
            n = n + 1
            local f = t.portraits[n]
            if not f then
                f = PortraitButton(t)
                t.portraits[n] = f
            end
            local col, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", t, "TOPLEFT", left + col * (SIZE + GAP), -(y + row * (SIZE + GAP)))
            SetPortrait(f, run.dungeon, e.boss, e.kill ~= nil)
            f.ring:Hide()
            f.kill, f.runStart = e.kill, start
            -- altartracker (2.0.49): a group's portrait, with its +
            -- (groupfix, 2.0.13, Malou on Discord 19 Nov 2026: "/dj tracker"
            -- did nothing, a Lua error in TrackerGroupRow every redraw): only
            -- a journal group (group = true, with its children) gets the +;
            -- a fight (Ring of Law: group = the fight's name) has no children,
            -- and its + opened a row of nothing that broke the tracker.
            f.group = (e.group == true and type(e.children) == "table") and e or nil
            f.fightGroup = type(e.group) == "string" or nil -- (groupfix: no click-to-target on it, as before)
            f.fdjX = left + col * (SIZE + GAP)
            if FDJ.TrackerGroupPlus then FDJ.TrackerGroupPlus(f) end
            f.isRare = isRare and true or nil
            f.notFound = isRare and not e.seen and not e.kill
            local glowing = isRare and e.seen and not e.kill and not e.ack
            if isRare and not e.kill and not e.seen then
                -- Not found yet: faded.
                f.tex:SetDesaturated(true)
                if f.tex.fdjPooled then f.tex.fdjPooled:SetDesaturated(true) end
                f:SetAlpha(0.45)
            else
                f:SetAlpha(1)
            end
            f.glow:SetShown(glowing and true or false)
            if glowing then
                if not f.glowAnim:IsPlaying() then f.glowAnim:Play() end
            elseif f.glowAnim:IsPlaying() then
                f.glowAnim:Stop()
            end
            f:Show()
            frames[#frames + 1] = f
        end
        if #list > 0 then y = y + math.ceil(#list / PER_ROW) * (SIZE + GAP) end
        return frames
    end
    local bossFrames = Place(bosses, false)
    -- altarbottom (2.0.50): an open group's row, under the bosses
    if FDJ.TrackerGroupRow then y = FDJ.TrackerGroupRow(t, run, bossFrames, y) or y end
    local lootRow = t.lootRow
    if lootRow and lootRow:IsShown() and not (lootRow.portrait and lootRow.portrait:IsShown()
        and lootRow.portrait.boss == lootRow.boss) then
        lootRow:Hide()
    end
    t.raresLabel:SetShown(#rares > 0)
    local rareFrames = {}
    if #rares > 0 then
        t.raresLabel:ClearAllPoints()
        t.raresLabel:SetPoint("TOPLEFT", t, "TOPLEFT", 10, -(y + 2))
        t.raresLabel:SetText(L("RUNLOG_RARE"))
        y = y + 18
        rareFrames = Place(rares, true)
    end
    for i = n + 1, #t.portraits do
        t.portraits[i]:Hide()
        if t.portraits[i].glowAnim:IsPlaying() then t.portraits[i].glowAnim:Stop() end
    end
    t:SetHeight(y + 4)
    if not t:IsShown() then t:Show() end
    if FDJ.ShowTrackerHint then FDJ.ShowTrackerHint(t, run) end
    if FDJ.ShowBossHint then FDJ.ShowBossHint(t, run, bossFrames[1], left) end
    -- Click areas only on rares found alive (no use on one not seen yet or
    -- dead), laid out again only when that list changes.
    local alive = {}
    for _, f in ipairs(rareFrames) do
        if not f.kill and not f.notFound then alive[#alive + 1] = f end
    end
    local sig = run.id .. ":"
    for _, f in ipairs(alive) do sig = sig .. (f.boss and f.boss.name or "?") .. ";" end
    if sig ~= t.secureSig or securePending then
        t.secureSig = sig
        LayoutSecure(alive)
    end
    t.rareFrames = rareFrames
    if not InCombat() then
        for _, b in ipairs(secureButtons) do
            if b.portrait and b:IsShown() then FDJ.RunLogPlaceOnScreen(b, b.portrait) end
        end
    end
    LayoutBossButtons(bossFrames)
end

-- The button on the log page: show or hide the tracker for the run.
function FDJ.ToggleRunTracker(on)
    local db = TrackerDB()
    local run = TrackedRun()
    if on == nil then on = not FDJ.IsRunTrackerOn() end
    if on then
        if trackerClosedNotice then trackerClosedNotice:Hide() end
        db.on = true
        db.dismissedRun = nil
        db.dismissedUntilEnter = nil -- hideleave
        -- asked for it with Track on screen: that overrides "Never track"
        if FDJ.TrackerOption("never") then FDJ.SetTrackerOption("never", false) end
        if FDJ.TrackerOption("hide") then db.hideRun = nil FDJ.SetTrackerOption("hide", false) end
    else
        db.on = nil
        db.dismissedRun = run and run.id or nil
        db.dismissedUntilEnter = nil -- hideleave
    end
    FDJ.UpdateRunTracker()
end

-- /dj tracker always tries to SHOW the current run (never toggles it off).
-- When there is no active/recoverable run, do not leave a sticky on flag.
function FDJ.ReopenDungeonTracker()
    -- hidetracker: /dj tracker always unticks Options > Hide Tracker
    if FDJ.TrackerOption("hide") then TrackerDB().hideRun = nil FDJ.SetTrackerOption("hide", false) end
    if not TrackedRun() then return false end
    FDJ.ToggleRunTracker(true)
    return FDJ.IsRunTrackerOn()
end

-- The close reminder uses the same localized popup system as the initial
-- tracker hint. Keep the slash command itself identical in every locale.
do
    local strings = {
        enUS = { "Tracker Closed", "type \"/dj tracker\" to show again" },
        deDE = { "Tracker geschlossen", "mit \"/dj tracker\" erneut anzeigen" },
        frFR = { "Suivi fermé", "tapez \"/dj tracker\" pour le rouvrir" },
        esES = { "Rastreador cerrado", "escribe \"/dj tracker\" para volver a abrirlo" },
        itIT = { "Tracker chiuso", "digita \"/dj tracker\" per riaprirlo" },
        ptBR = { "Rastreador fechado", "digite \"/dj tracker\" para reabri-lo" },
        ruRU = { "Трекер закрыт", "введите \"/dj tracker\", чтобы открыть снова" },
        koKR = { "추적기를 닫았습니다", "다시 열려면 \"/dj tracker\" 입력" },
        zhCN = { "追踪器已关闭", "输入 \"/dj tracker\" 可再次打开" },
        zhTW = { "追蹤器已關閉", "輸入 \"/dj tracker\" 可再次開啟" },
    }
    strings.esMX = strings.esES
    for locale, pair in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            if t.TRACKER_CLOSED_TITLE == nil then t.TRACKER_CLOSED_TITLE = pair[1] end
            if t.TRACKER_CLOSED_HELP == nil then t.TRACKER_CLOSED_HELP = pair[2] end
        end
    end
end

-- The first time ever the tracker shows up in a real run, a note with a
-- red arrow (steady, black) points at it from its left:
--   New Dungeon Tracker
--   [OK] "Right Click" to disable
-- It stays until OK is clicked (hidden while the tracker is, back with
-- it). While it's up, right-clicking the note or the tracker opens Options
-- > Dungeon Tracker at once with Never track dungeons highlighted; after
-- OK, right-click is the usual Options menu again.
do
    local strings = {
        enUS = { "New Dungeon Tracker", "\"Right Click\" to disable" },
        deDE = { "Neuer Dungeon-Tracker", "\"Rechtsklick\" zum Deaktivieren" },
        frFR = { "Nouveau suivi de donjon", "\"Clic droit\" pour désactiver" },
        esES = { "Nuevo rastreador de mazmorras", "\"Clic derecho\" para desactivar" },
        itIT = { "Nuovo tracker dei dungeon", "\"Clic destro\" per disattivare" },
        ptBR = { "Novo rastreador de masmorras", "\"Clique direito\" para desativar" },
        ruRU = { "Новый трекер подземелий", "\"Правый клик\" — отключить" },
        koKR = { "새 던전 추적기", "\"우클릭\"으로 끄기" },
        zhCN = { "新的地下城追踪器", "\"右键点击\"可关闭" },
        zhTW = { "新的地城追蹤器", "\"右鍵點擊\"可關閉" },
    }
    strings.esMX = strings.esES
    for locale, pair in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            if t.TRACKER_HINT_1 == nil then t.TRACKER_HINT_1 = pair[1] end
            if t.TRACKER_HINT_2 == nil then t.TRACKER_HINT_2 = pair[2] end
        end
    end
end

local function TrackerHintFrame()
    if FDJ.trackerHint then return FDJ.trackerHint end
    local h = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    FDJ.trackerHint = h
    h:SetFrameStrata("DIALOG") -- under the Options panel
    h:SetClampedToScreen(true)
    h:RegisterForClicks("RightButtonUp")
    h:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    h:SetBackdropColor(0, 0, 0, 1)
    h:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    h.arrow = h:CreateTexture(nil, "OVERLAY")
    h.arrow:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\QuestNextArrow")
    h.arrow:SetVertexColor(1, 0.12, 0.08)
    h.arrow:SetSize(24, 24)
    h.line1 = h:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightLarge")
    h.line1:SetTextColor(1, 1, 1)
    h.line1:SetShadowColor(0, 0, 0, 1)
    h.line1:SetShadowOffset(1, -1)
    h.ok = CreateFrame("Button", nil, h, "UIPanelButtonTemplate")
    FDJ.OwnFonts(h.ok) -- ownfonts (2.0.8)
    h.ok:SetSize(40, 20)
    h.ok:SetText(OKAY or "OK")
    h.line2 = h:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlight")
    h.line2:SetTextColor(1, 0.82, 0.27)
    h.line2:SetShadowColor(0, 0, 0, 1)
    h.line2:SetShadowOffset(1, -1)
    h.ok:SetScript("OnClick", function()
        h:Hide()
        h.fdjDone = true
        ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
        ForeverDungeonJournalDB.trackerHintShown = true
        ForeverDungeonJournalDB.trackerHintPending = nil
    end)
    h:SetScript("OnClick", function(self, button)
        if button == "RightButton" then ShowTrackerMenu(tracker) end
    end)
    h:SetScript("OnUpdate", function(self, elapsed)
        if not (tracker and tracker:IsShown()) then self:Hide() return end
        -- the box stays put; only the arrow fades in and out and nudges
        -- toward the tracker
        self.t = (self.t or 0) + elapsed
        local s = math.sin(self.t * 4)
        self.arrow:SetAlpha(0.55 + 0.45 * s)
        self.arrow:ClearAllPoints()
        if self.flipped then
            self.arrow:SetPoint("LEFT", 8 - 3 * math.abs(s), 0)
        else
            self.arrow:SetPoint("RIGHT", -8 + 3 * math.abs(s), 0)
        end
    end)
    return h
end

-- 2.0.4: the note is for new installs only, not for updates. At login: no
-- saved data yet = just installed, the note waits for the first tracker
-- (and keeps waiting until OK). Saved data from before = an update: no note.
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        local db = ForeverDungeonJournalDB
        if type(db) ~= "table" then return end
        if db == FDJ.bootDB then
            db.trackerHintPending = true
        elseif not db.trackerHintPending then
            db.trackerHintShown = true
        end
    end)
end

function FDJ.ShowTrackerHint(t, run)
    if not run then return end
    local h = FDJ.trackerHint
    if h and h:IsShown() then return end
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    if ForeverDungeonJournalDB.trackerHintShown then return end
    h = TrackerHintFrame()
    h.line1:SetText(L("TRACKER_HINT_1"))
    h.line2:SetText(L("TRACKER_HINT_2"))
    local w1 = h.line1:GetStringWidth() or 0
    local w2 = (h.line2:GetStringWidth() or 0) + 46 -- the OK button before it
    h:SetSize(math.max(w1, w2) + 58, 58)
    -- left of the tracker, arrow pointing right at it; no room on the
    -- left (tracker at the screen's edge): on its right, arrow flipped
    local left = t:GetLeft() and t:GetLeft() * t:GetEffectiveScale() / UIParent:GetEffectiveScale() or 999
    local flipped = left < h:GetWidth() + 12
    h.flipped = flipped
    h.t = 0
    local textX = flipped and 38 or 12
    h.line1:ClearAllPoints()
    h.line1:SetPoint("TOPLEFT", textX, -10)
    h.ok:ClearAllPoints()
    h.ok:SetPoint("TOPLEFT", h.line1, "BOTTOMLEFT", 0, -5)
    h.line2:ClearAllPoints()
    h.line2:SetPoint("LEFT", h.ok, "RIGHT", 6, 0)
    h.arrow:ClearAllPoints()
    h:ClearAllPoints()
    if flipped then
        h.arrow:SetTexCoord(1, 0, 0, 1)
        h.arrow:SetPoint("LEFT", 8, 0)
        h:SetPoint("LEFT", t, "RIGHT", 8, 0)
    else
        h.arrow:SetTexCoord(0, 1, 0, 1)
        h.arrow:SetPoint("RIGHT", -8, 0)
        h:SetPoint("RIGHT", t, "LEFT", -8, 0)
    end
    h:SetAlpha(1)
    h:Show()
end

-- bosshint (2.0.4): once per account, on new installs only (like the New
-- Dungeon Tracker note, after it): a note with a yellow arrow pointing at
-- the tracker's first boss portrait:
--   Right-click bosses
--   to see loot on tracker   [OK]
-- It stays until OK is clicked or a boss is right-clicked (hidden while
-- the tracker or its bosses are, back with them).
do
    -- two lines
    local strings = {
        enUS = { "Right-click bosses", "to see loot on tracker" },
        deDE = { "Rechtsklick auf Bosse", "zeigt ihre Beute im Tracker" },
        frFR = { "Clic droit sur les boss", "pour voir leur butin dans le suivi" },
        esES = { "Clic derecho en los jefes", "para ver su botín en el seguimiento" },
        itIT = { "Clic destro sui boss", "per vedere il bottino nel tracker" },
        ptBR = { "Clique direito nos chefes", "para ver o saque no rastreador" },
        ruRU = { "Правый клик по боссам:", "их добыча в трекере" },
        koKR = { "우두머리를 우클릭하면", "추적기에서 전리품을 봅니다" },
        zhCN = { "右键点击首领", "可在追踪器中查看掉落" },
        zhTW = { "右鍵點擊首領", "可在追蹤器中查看掉落" },
    }
    strings.esMX = strings.esES
    for locale, pair in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            if t.TRACKER_BOSS_HINT_1 == nil then t.TRACKER_BOSS_HINT_1 = pair[1] end
            if t.TRACKER_BOSS_HINT_2 == nil then t.TRACKER_BOSS_HINT_2 = pair[2] end
        end
    end
    -- At login: no saved data yet = just installed, the note waits for the
    -- tracker's bosses (until OK). Saved data from before = an update: none.
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        local db = ForeverDungeonJournalDB
        if type(db) ~= "table" then return end
        if db == FDJ.bootDB then
            db.bossHintPending = true
        elseif not db.bossHintPending then
            db.bossHintShown = true
        end
    end)
end

local function BossHintDone()
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    ForeverDungeonJournalDB.bossHintShown = true
    ForeverDungeonJournalDB.bossHintPending = nil
    if FDJ.bossHint then
        FDJ.bossHint.fdjDone = true
        FDJ.bossHint:Hide()
    end
end
FDJ.BossHintDone = BossHintDone

local function BossHintFrame()
    if FDJ.bossHint then return FDJ.bossHint end
    local h = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    FDJ.bossHint = h
    h:SetFrameStrata("DIALOG")
    h:SetClampedToScreen(true)
    h:EnableMouse(true)
    h:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    h:SetBackdropColor(0, 0, 0, 1)
    h:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    -- the arrow's own colour is yellow
    h.arrow = h:CreateTexture(nil, "OVERLAY")
    h.arrow:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\QuestNextArrow")
    h.arrow:SetSize(18, 18)
    h.line1 = h:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    h.line2 = h:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightSmall")
    for _, line in ipairs({ h.line1, h.line2 }) do
        line:SetTextColor(1, 1, 1)
        line:SetShadowColor(0, 0, 0, 1)
        line:SetShadowOffset(1, -1)
        line:SetJustifyH("LEFT")
    end
    h.ok = CreateFrame("Button", nil, h, "UIPanelButtonTemplate")
    FDJ.OwnFonts(h.ok) -- ownfonts (2.0.8)
    h.ok:SetSize(34, 16)
    h.ok:SetNormalFontObject("ForeverDJ_GameFontNormalSmall")
    h.ok:SetHighlightFontObject("ForeverDJ_GameFontHighlightSmall")
    h.ok:SetText(OKAY or "OK")
    h.ok:SetScript("OnClick", BossHintDone)
    h:SetScript("OnUpdate", function(self, elapsed)
        local p = self.portrait
        if not (tracker and tracker:IsShown() and p and p:IsShown() and p.boss) then self:Hide() return end
        self.t = (self.t or 0) + elapsed
        local s = math.sin(self.t * 4)
        self.arrow:SetAlpha(0.55 + 0.45 * s)
        self.arrow:ClearAllPoints()
        if self.flipped then
            self.arrow:SetPoint("LEFT", 6 - 2 * math.abs(s), 0)
        else
            self.arrow:SetPoint("RIGHT", -6 + 2 * math.abs(s), 0)
        end
    end)
    h:Hide()
    return h
end

-- first: the tracker's first boss portrait; left: its distance from the
-- tracker's left edge. force: show it now (/dj bosshint, to look at it).
function FDJ.ShowBossHint(t, run, first, left, force)
    if not (t and run and first and first:IsShown() and first.boss) then return end
    local db = ForeverDungeonJournalDB
    if not force then
        if type(db) ~= "table" or db.bossHintShown or not db.bossHintPending then return end
        -- after the New Dungeon Tracker note, not together with it
        if not db.trackerHintShown or (FDJ.trackerHint and FDJ.trackerHint:IsShown()) then return end
    end
    local h = BossHintFrame()
    if h:IsShown() and h.portrait == first then return end
    h.portrait = first
    h.line1:SetText(L("TRACKER_BOSS_HINT_1"))
    h.line2:SetText(L("TRACKER_BOSS_HINT_2"))
    -- the OK button after the second line
    local w = math.max(h.line1:GetStringWidth() or 0, (h.line2:GetStringWidth() or 0) + 4 + 34)
    local lh = math.max(h.line1:GetStringHeight() or 0, 10)
    h:SetSize(w + 42, lh * 2 + 3 + 16)
    -- left of the tracker, level with the first boss, arrow pointing right
    -- at it; no room on the left (tracker at the screen's edge): on its
    -- right, arrow flipped
    local tl = t:GetLeft() and t:GetLeft() * t:GetEffectiveScale() / UIParent:GetEffectiveScale() or 999
    local flipped = tl < h:GetWidth() + 12
    h.flipped = flipped
    h.t = 0
    local gapLeft = (left or 10) + 8
    local gapRight = ((t:GetWidth() or 236) - (left or 10) - (first:GetWidth() or 38)) + 8
    h.line1:ClearAllPoints()
    h.line1:SetPoint("TOPLEFT", flipped and 30 or 9, -8)
    h.line2:ClearAllPoints()
    h.line2:SetPoint("TOPLEFT", h.line1, "BOTTOMLEFT", 0, -3)
    h.ok:ClearAllPoints()
    h.ok:SetPoint("LEFT", h.line2, "RIGHT", 4, 0)
    h.arrow:ClearAllPoints()
    h:ClearAllPoints()
    if flipped then
        h.arrow:SetTexCoord(1, 0, 0, 1)
        h.arrow:SetPoint("LEFT", 6, 0)
        h:SetPoint("LEFT", first, "RIGHT", gapRight, 0)
    else
        h.arrow:SetTexCoord(0, 1, 0, 1)
        h.arrow:SetPoint("RIGHT", -6, 0)
        h:SetPoint("RIGHT", first, "LEFT", -gapLeft, 0)
    end
    h:SetAlpha(1)
    h:Show()
end

-- /dj bosshint: the note on the tracker now, to look at it.
function FDJ.PreviewBossHint()
    local f = tracker and tracker:IsShown() and tracker.portraits and tracker.portraits[1]
    if not (f and f:IsShown() and f.boss and not f.isRare) then return false end
    local left = math.floor((236 - (PER_ROW * SIZE + (PER_ROW - 1) * GAP)) / 2)
    if FDJ.bossHint then FDJ.bossHint:Hide() end
    FDJ.ShowBossHint(tracker, tracker.run, f, left, true)
    return FDJ.bossHint and FDJ.bossHint:IsShown() or false
end

-- A rare found: its portrait glows and a soft chime plays until its
-- portrait is clicked: at once, then 4, 8, 16, 32... seconds apart, so
-- it doesn't nag someone who hasn't found out they can click it.
local nextChime, chimeGap = 0, 4
local function Chime()
    local id = (SOUNDKIT and SOUNDKIT.MAP_PING) or 3175
    if PlaySound then pcall(PlaySound, id, "Master") end
end
function FDJ.RunLogRareSpotted(run, boss)
    local now = GetTime and GetTime() or 0
    Chime()
    chimeGap = 4
    nextChime = now + chimeGap
end
function FDJ.RunLogAckRare(name)
    local run = TrackedRun()
    if not run or not name then return end
    run.rareAck = run.rareAck or {}
    run.rareAck[name] = true
    FDJ.UpdateRunTracker()
end
-- Called by the tracker every second.
local function ChimeTick()
    if not tracker or not tracker:IsShown() then return end
    local glowing = false
    for _, f in ipairs(tracker.rareFrames or {}) do
        if f.glow:IsShown() then glowing = true break end
    end
    local now = GetTime and GetTime() or 0
    if not glowing then
        chimeGap, nextChime = 4, 0
        return
    end
    if nextChime == 0 then
        -- glowing without a fresh sighting (a reload): start the schedule
        nextChime = now + chimeGap
    elseif now >= nextChime then
        Chime()
        chimeGap = chimeGap * 2
        nextChime = now + chimeGap
    end
end
FDJ.RunLogChimeTick = ChimeTick

do
    local strings = {
        enUS = "Click: target it and mark it with a skull.", deDE = "Klicken: anvisieren und mit einem Totenkopf markieren.",
        frFR = "Clic : le cibler et le marquer d'un crâne.", esES = "Clic: seleccionarlo y marcarlo con una calavera.",
        esMX = "Clic: seleccionarlo y marcarlo con una calavera.", itIT = "Clic: selezionalo e segnalo con un teschio.",
        ptBR = "Clique: selecionar e marcar com uma caveira.", ruRU = "Клик: выбрать целью и пометить черепом.",
        koKR = "클릭: 대상으로 지정하고 해골로 표시합니다.", zhCN = "点击：选中并标记骷髅。", zhTW = "點擊：選取並標記骷髏。",
    }
    for locale, text in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t and t.RUNLOG_RARE_CLICK == nil then t.RUNLOG_RARE_CLICK = text end
    end
    local boss = {
        enUS = "Click: target it.", deDE = "Klicken: anvisieren.", frFR = "Clic : le cibler.",
        esES = "Clic: seleccionarlo.", esMX = "Clic: seleccionarlo.", itIT = "Clic: selezionalo.",
        ptBR = "Clique: selecionar.", ruRU = "Клик: выбрать целью.", koKR = "클릭: 대상으로 지정합니다.",
        zhCN = "点击：选中。", zhTW = "點擊：選取。",
    }
    for locale, text in pairs(boss) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t and t.RUNLOG_BOSS_CLICK == nil then t.RUNLOG_BOSS_CLICK = text end
    end
end

do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    pcall(ev.RegisterEvent, ev, "GROUP_ROSTER_UPDATE")
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if securePending and tracker then
                if tracker:IsShown() then LayoutSecure(tracker.rareFrames) else LayoutSecure({}) end
            end
            return
        end
        if C_Timer and C_Timer.After then C_Timer.After(3, function() FDJ.UpdateRunTracker() end) end
    end)
end

-- exporthint (2.1.1, M 20 Nov 2026: "a little pop-up that pops up ... only
-- once ... whenever somebody updates ... whenever somebody downloads it ...
-- but then not anymore ... close to the one that we have for the Onyxia
-- pop-up ... once people open the journal, it points at the character logs
-- and says you can now export your character's progress to the website"):
-- the first time the journal shows, a note under the Export button (title
-- bar, left of Report; exporttitle, M 20 Nov 2026: "move the pop-up ...
-- pointing to that button") in the Onyxia popup's look, its red arrow
-- pointing up at the button. Once per account for good (exportHintSeen); a
-- click opens the Options' Export tab; gone after 12 seconds, or with the
-- journal. Not while the button is hidden.
do
    local strings = {
        enUS = { EXPORT_NOTE = "You can now export your character's progress to the website", EXPORT_NOTE_CLICK = "Click here or on %s." },
        deDE = { EXPORT_NOTE = "Du kannst jetzt den Fortschritt deines Charakters auf die Website exportieren", EXPORT_NOTE_CLICK = "Hier oder auf %s klicken." },
        frFR = { EXPORT_NOTE = "Vous pouvez maintenant exporter la progression de votre personnage vers le site", EXPORT_NOTE_CLICK = "Cliquez ici ou sur %s." },
        esES = { EXPORT_NOTE = "Ahora puedes exportar el progreso de tu personaje al sitio web", EXPORT_NOTE_CLICK = "Haz clic aquí o en %s." },
        itIT = { EXPORT_NOTE = "Ora puoi esportare i progressi del tuo personaggio sul sito", EXPORT_NOTE_CLICK = "Clicca qui o su %s." },
        ptBR = { EXPORT_NOTE = "Agora você pode exportar o progresso do seu personagem para o site", EXPORT_NOTE_CLICK = "Clique aqui ou em %s." },
        ruRU = { EXPORT_NOTE = "Теперь вы можете экспортировать прогресс персонажа на сайт", EXPORT_NOTE_CLICK = "Нажмите здесь или на «%s»." },
        koKR = { EXPORT_NOTE = "이제 캐릭터 진행 상황을 웹사이트로 내보낼 수 있습니다", EXPORT_NOTE_CLICK = "여기 또는 %s을(를) 클릭하세요." },
        zhCN = { EXPORT_NOTE = "现在你可以将角色进度导出到网站", EXPORT_NOTE_CLICK = "点击此处或%s。" },
        zhTW = { EXPORT_NOTE = "現在你可以將角色進度匯出到網站", EXPORT_NOTE_CLICK = "點擊此處或%s。" },
    }
    strings.esMX = strings.esES
    for locale, values in pairs(strings) do
        local t = FDJ.Locales and FDJ.Locales[locale]
        if t then
            for key, value in pairs(values) do
                if t[key] == nil then t[key] = value end
            end
        end
    end

    local HINT_TIME = 12
    local ARROW = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\QuestPrevArrow"
    local hint

    local function Build(icon)
        local p = CreateFrame("Button", nil, icon, "BackdropTemplate")
        p:SetFrameStrata("FULLSCREEN_DIALOG")
        p:SetClampedToScreen(true)
        p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        p:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        p:SetBackdropColor(0, 0, 0, 0.92)
        p:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        -- The Onyxia popup's red arrow (it points left), turned to point up
        -- at the icon; it comes and goes, nudging toward it.
        p.arrow = p:CreateTexture(nil, "OVERLAY")
        p.arrow:SetTexture(ARROW)
        p.arrow:SetVertexColor(1, 0.12, 0.08)
        p.arrow:SetSize(24, 24)
        if p.arrow.SetRotation then pcall(p.arrow.SetRotation, p.arrow, -math.pi / 2) end
        -- okbutton (M 20 Nov 2026: "we need the little OK button so people
        -- can close the thing ... on the top left, at the top, above"): the
        -- tracker's boss note's small OK, over the text; it only closes.
        p.ok = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        FDJ.OwnFonts(p.ok)
        p.ok:SetSize(34, 16)
        p.ok:SetNormalFontObject("ForeverDJ_GameFontNormalSmall")
        p.ok:SetHighlightFontObject("ForeverDJ_GameFontHighlightSmall")
        p.ok:SetText(OKAY or "OK")
        p.ok:SetPoint("TOPLEFT", 10, -9)
        p.ok:SetScript("OnClick", function() p:Hide() end)
        p.text = p:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontHighlightLarge")
        p.text:SetPoint("TOPLEFT", 14, -30)
        p.text:SetWidth(300)
        p.text:SetJustifyH("LEFT")
        p.text:SetTextColor(1, 1, 1)
        p.text:SetShadowColor(0, 0, 0, 1)
        p.text:SetShadowOffset(1, -1)
        p.hint = p:CreateFontString(nil, "OVERLAY", "ForeverDJ_GameFontDisableSmall")
        p.hint:SetPoint("TOPLEFT", p.text, "BOTTOMLEFT", 0, -6)
        p.hint:SetWidth(300)
        p.hint:SetJustifyH("LEFT")
        p:SetScript("OnUpdate", function(self, elapsed)
            self.t = (self.t or 0) + elapsed
            if self.t >= HINT_TIME then
                self:Hide()
                return
            end
            -- in over 0.3 s, out over the last 0.6 s
            self:SetAlpha(math.min(1, self.t / 0.3, (HINT_TIME - self.t) / 0.6))
            local wave = math.sin(self.t * 4)
            self.arrow:SetAlpha(0.55 + 0.45 * wave)
            self.arrow:ClearAllPoints()
            self.arrow:SetPoint("TOP", self.fdjIcon, "BOTTOM", 0, -1 - 3 * math.abs(wave))
        end)
        p:SetScript("OnClick", function(self, button)
            self:Hide()
            -- exporttitle: the Options' Export tab, as the button does
            if button == "LeftButton" and FDJ.OpenExportTab then pcall(FDJ.OpenExportTab) end
        end)
        p:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.82, 0.35, 1) end)
        p:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) end)
        p:Hide()
        return p
    end

    -- force: show it even when already seen (not marked).
    function FDJ.ShowExportHint(icon, force)
        local db = ForeverDungeonJournalDB
        if type(db) ~= "table" or not icon then return end
        if db.exportHintSeen and not force then return end
        if not (icon:IsVisible() and icon:GetLeft()) then return end
        if FDJ.IsExportButtonHidden and FDJ.IsExportButtonHidden() then return end
        if not force then db.exportHintSeen = true end
        hint = hint or Build(icon)
        hint.fdjIcon = icon
        hint.text:SetText(L("EXPORT_NOTE"))
        hint.hint:SetText(string.format(L("EXPORT_NOTE_CLICK"), L("RUNLOG_EXPORT")))
        hint:SetSize(328, (hint.text:GetStringHeight() or 34) + (hint.hint:GetStringHeight() or 12) + 48)
        hint:ClearAllPoints()
        hint:SetPoint("TOP", icon, "BOTTOM", 0, -28)
        hint.arrow:ClearAllPoints()
        hint.arrow:SetPoint("TOP", icon, "BOTTOM", 0, -1)
        hint.t = 0
        hint:SetAlpha(0)
        hint:Show()
    end

    -- The Export button: shown (the journal opened), after the title bar
    -- has placed its buttons.
    function FDJ.AttachExportHint(icon)
        if not icon or icon.fdjExportHint then return end
        icon.fdjExportHint = true
        local function Try()
            if C_Timer and C_Timer.After then
                C_Timer.After(0.3, function() FDJ.ShowExportHint(icon) end)
            else
                FDJ.ShowExportHint(icon)
            end
        end
        icon:HookScript("OnShow", Try)
        if icon:IsVisible() then Try() end
    end
end
