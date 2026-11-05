-- Forever Leveling Guide: MODO APRENDIZAJE de la rotacion (13-oct, estilo Hekili; 2.0 el 15-oct).
-- Una ventanita que, en combate, dice que golpe toca AHORA (icono grande, nombre, tecla y POR QUE) y los 2 siguientes.
-- Sigue el modo de WowFExportarDB.modoRotacion (PvE o PvP) y la lista de la rotacion de wowF_Rotacion.lua
-- (WowF.datosVistaCombate: mismas guias de WoW Forever; nada de Classic, nada inventado).
--
-- 2.0 (15-oct): en Forever el cliente esconde en combate cooldowns, auras, poder y vida del objetivo (diagnostico de Andy).
-- Lo que SI deja leer: C_Spell.IsSpellUsable, el spellID de UNIT_SPELLCAST_SUCCEEDED y los eventos de brillo
-- (SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE). Por eso el motor "prioridad" lleva la CUENTA PROPIA de cada golpe con los
-- datos reales de la beta (wowF_Duraciones_Datos.lua: duracion, cooldown, categoria, a quien afecta) y, si algun dia el juego
-- deja leer cooldowns o auras, usa la lectura real. Cada golpe se clasifica por el texto de la guia (A.clasificar):
--   INTERR (interrumpir) > brillo/reaccion (procs) > AOE (varios enemigos) > BUFF que falta > DEBUFF que falta > CD listo > RELLENO.
-- Sin wowF_Duraciones_Datos.lua vuelve al motor viejo (secuencia / simple).
-- Diagnostico automatico de lo que el cliente deja leer en WowFExportarDB.diagCombate (ultimos 20).
-- SOLO MUESTRA: nunca lanza hechizos ni toca botones de accion seguros (nada de CastSpell, SetRaidTarget, ActionButton_ShowOverlayGlow...).
WowF = WowF or {}

local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local PREFIJO = "|cff33ccffForever Guide|r: "
local GCD = 1.5
local TICK = 0.15
local INFINITO = math.huge

local A = {
  cola = {}, seq = {}, pos = 1, sucio = true, enCombate = false, modoMotor = nil, elegidos = {}, porque = {}, n = 0,
  -- cuenta propia (claves = nombre del golpe, sobreviven a A.rehacer)
  cdHasta = {}, catHasta = {}, buffHasta = {}, debuff = {}, brillo = {}, placas = {}, sim = {},
}
WowF.aprendizaje = A -- estado (lo leen las pruebas)

local function db() WowFExportarDB = WowFExportarDB or {}; return WowFExportarDB end
function WowF.aprendizajeActivo() return db().modoAprendizaje == true end
local function ocultarFuera() return db().aprendizajeOcultar == true end
local function modoObjetivos() local m = db().aprendizajeObjetivos; return (m == "uno" or m == "varios") and m or "auto" end

-- ===================== Lectura segura (valores secretos) =====================
local function secreto(v)
  if v == nil or not issecretvalue then return false end
  local ok, s = pcall(issecretvalue, v)
  return (not ok) or (s and true or false)
end
local function num(v) -- numero legible o nil (WowF.numero devuelve TEXTO)
  if WowF.numero then return tonumber(WowF.numero(v)) end
  if secreto(v) then return nil end
  return tonumber(v)
end
local function txt(v) -- texto legible o nil
  if WowF.numero then return WowF.numero(v) end
  if secreto(v) or v == nil then return nil end
  return tostring(v)
end
local function ahora() return num(GetTime and GetTime()) or 0 end
-- true / false / nil (no se puede leer)
local function bool(f, ...)
  if type(f) ~= "function" then return nil end
  local ok, r = pcall(f, ...)
  if not ok or secreto(r) then return nil end
  if r == nil or r == false or r == 0 then return false end
  return true
end

-- ===================== Clasificacion (texto de la guia + datos reales de la beta) =====================
local function conjunto(t) local s = {}; for _, k in ipairs(t) do s[k] = true end; return s end
local function hay(t, lista) for _, p in ipairs(lista) do if t:find(p, 1, true) then return true end end return false end
local function sinAcentos(t)
  return (t:gsub("á", "a"):gsub("é", "e"):gsub("í", "i"):gsub("ó", "o"):gsub("ú", "u"):gsub("ñ", "n"):gsub("Á", "a"):gsub("É", "e"))
end
-- Golpes de "segun la situacion": siguen en la pestana Rotacion con su explicacion, no en la recomendacion automatica
local SIT_NOMBRE = conjunto({ "Hammer of Justice", "Lay on Hands", "Gouge", "Disengage", "Mend Pet", "Frost Nova", "Entangling Roots",
  "Drain Life", "Drain Soul", "Life Tap", "Searing Pain", "Expose Armor", "Prayer of Healing", "Call of the Elements", "Holy Shock" })
local SIT_FRASE = { "emergencia", "emergency", "si te pegan", "para huir", "to escape", "poca vida", "low health", "si vas mal",
  "in trouble", "contra jugadores", "si se escapa", "kiting", "if you worry", "si te preocupa", "cuando haga falta", "when needed" }
local INTERR_NOMBRE = conjunto({ "Kick", "Shield Bash", "Pummel", "Counterspell" })
local PROC_FRASE = { "as soon as it lights up", "whenever it lights up", "en cuanto se encienda", "cuando se encienda", "after a kill",
  "tras matar", "when it turns instant", "cuando sale instantaneo", "while the enemy is frozen", "mientras el enemigo esta congelado" }
-- Golpes que el juego solo deja usar cuando se cumple su condicion (esquiva, poca vida...): IsSpellUsable = true = toca ya
local REACT = conjunto({ "Overpower", "Revenge", "Execute", "Riposte", "Counterattack", "Mongoose Bite", "Victory Rush", "Hammer of Wrath" })
local RELLENO_NOMBRE = conjunto({ "Mind Flay", "Arcane Missiles" })
local AOE_FRASE = { "varios enemigos", "several enemies", "2 o mas", "3 o mas", "2+", "3+", "packs", "grupos de", "muchos enemigos",
  "many enemies", "several targets", "varios objetivos" }
local AOE_NOMBRE = conjunto({ "Hellfire", "Cleave", "Sweeping Strikes", "Consecration", "Multi-Shot", "Fire Nova",
  "Blizzard", "Arcane Explosion", "Flamestrike", "Blast Wave", "Cone of Cold", "Swipe" })
local ANTES_FRASE = { "antes de pelear", "entre peleas", "fuera de combate", "to open", "para entrar", "to pull", "para atraer",
  "before the pull", "between pulls", "out of combat", "before the fight" }
local SIGILO = conjunto({ "Stealth", "Prowl" })
local CURAS = conjunto({ "Holy Light", "Flash of Light", "Heal", "Flash Heal", "Renew", "Healing Wave", "Healing Touch", "Regrowth", "Rejuvenation" })
local MANTENER = { "mantenlo", "mantenla", "keep it up", "keep it on", "renuevalo", "renuevala", "refresh", "dano con el tiempo",
  "damage over time", "siempre puesto", "always on", "sangrado", "bleed" }
local CURA_PROPIA = { "mantenlo", "mantenla", "keep it up", "keep it on", "while fighting", "mientras pelea" }
local FORMA_DRUIDA = conjunto({ "Cat Form", "Bear Form", "Dire Bear Form", "Moonkin Form" })
local POSTURA = conjunto({ "Battle Stance", "Defensive Stance", "Berserker Stance" })
local function grupoDe(nombre)
  if nombre:find("^Seal of ") then return "sello" end
  if nombre:find("^Aspect of ") then return "aspecto" end
  if nombre:find("^Blessing of ") then return "bendicion" end
  if nombre:find(" Aura$") then return "aura" end
  if nombre:find(" Armor$") and nombre ~= "Sunder Armor" and nombre ~= "Expose Armor" then return "armadura" end
  if FORMA_DRUIDA[nombre] then return "forma" end
  if POSTURA[nombre] then return "postura" end
  return nil
end
-- Datos reales de la beta: por el id del golpe o por cualquiera de sus rangos (el mas alto primero)
local function durDe(nombre, id, cl)
  local D = WowFDuraciones
  if type(D) ~= "table" then return nil end
  if id and D[id] then return D[id] end
  local h = WowFHechizos and WowFHechizos[cl or ""] and WowFHechizos[cl or ""][nombre]
  if type(h) == "table" then for i = #h, 2, -1 do if D[h[i]] then return D[h[i]] end end end
  return nil
end

-- A.clasificar(g, clase) -> clase de golpe, info { d, grupo, antes, sigilo, cura }
-- g = { nombre, texto (guia ES | EN en minusculas), rolK (PvP), id }
function A.clasificar(g, cl)
  local n = g.nombre or ""
  local t = sinAcentos(g.texto or "")
  local d = durDe(n, g.id, cl)
  local dur, cd, tipo = d and d[1], d and d[2], d and d[4]
  local info = { d = d, grupo = grupoDe(n) }
  if cl == "WARLOCK" and n:find("^Summon ") then return "MASCOTA", info end
  local pvpDanio = false
  if g.rolK then
    if g.rolK == "interrupcion" then return "INTERR", info end
    -- curas de un sanador en PvP: siguen siendo curas (si no, la rama de curas se queda vacia)
    if g.rolK ~= "dano" and CURAS[n] and not hay(t, SIT_FRASE) then info.cura = true; return "CURA", info end
    if g.rolK ~= "dano" then return "SIT", info end
    pvpDanio = true
  end
  if SIT_NOMBRE[n] or hay(t, SIT_FRASE) then return "SIT", info end
  if not pvpDanio and (t:find("^interrump") or t:find("| interrupt", 1, true) or INTERR_NOMBRE[n]) then return "INTERR", info end
  if hay(t, PROC_FRASE) or t:find("when [%w%s']-procs") then return "PROC", info end
  if REACT[n] then return "REACT", info end
  if RELLENO_NOMBRE[n] then return "RELLENO", info end
  if AOE_NOMBRE[n] or hay(t, AOE_FRASE) then return "AOE", info end
  if SIGILO[n] then info.antes, info.sigilo = true, true; return "ANTES", info end
  if n == "Holy Fire" or hay(t, ANTES_FRASE) then
    if t:find("relleno", 1, true) or t:find("filler", 1, true) then return "RELLENO", info end
    if hay(t, { "rematar", "to finish", "cada vez que este listo", "on cooldown", "alternalo", "alternate" }) then
      if tipo == "d" and dur and d[7] then return "DEBUFF", info end
      if cd and cd > GCD then return "CD", info end
    end
    info.antes = true
    if (tipo == "b" or tipo == "t") and dur then return "BUFF", info end
    if tipo == "d" and dur and not d[6] then return "DEBUFF", info end
    return "ANTES", info
  end
  if CURAS[n] then
    if tipo == "b" and dur and hay(t, CURA_PROPIA) then return "BUFF", info end
    info.cura = true
    return "CURA", info
  end
  if t:find("^%s*relleno") or t:find("| filler", 1, true) then return "RELLENO", info end
  if tipo == "b" and cd and cd >= 60 and (dur == -1 or (dur and dur < cd)) then return "CD", info end
  if tipo == "t" and dur then return "BUFF", info end
  if tipo == "b" and dur then return "BUFF", info end
  if tipo == "d" and dur and (not d[6] or d[7] or hay(t, MANTENER)) then return "DEBUFF", info end
  if cd and cd > GCD then return "CD", info end
  return "RELLENO", info
end

-- 15-oct: "cuando usarlo" para la pestana Rotacion (misma clasificacion que el modo, con la duracion/recarga real de la beta).
-- WowF.aprendizajeCuando(golpes, clase) pone en cada golpe g.cuando = { corto, largo, color ("brasa|oro|verde|neutro|gris"), k }
local function tiempo(s)
  if not s or s <= 0 then return nil end
  if s >= 60 then local m = s / 60; return (m == math.floor(m) and tostring(math.floor(m)) or string.format("%.1f", m)) .. " min" end
  return tostring(math.floor(s + 0.5)) .. " s"
end
local CUANDO = { -- corto | largo (por que va en ese lugar)
  INTERR = { "Si lanza: interrumpe", "If it casts: interrupt", "brasa",
    "Va primero: si tu objetivo lanza un hechizo, cortarlo vale más que cualquier golpe.", "Comes first: if your target casts, stopping it beats any attack." },
  PROC = { "Cuando se encienda", "When it lights up", "brasa",
    "Solo a veces se puede usar y dura poco: en cuanto brille en tu barra, úsalo antes que lo demás.", "Only usable sometimes and briefly: as soon as it glows on your bar, use it before anything else." },
  REACT = { "Cuando se pueda usar", "When usable", "brasa",
    "El juego lo deja usar solo tras algo (esquiva, poca vida del enemigo...): cuando se ilumine, va antes que el resto.", "The game only allows it after something (dodge, low enemy health...): when it lights up, it goes before the rest." },
  AOE = { "Con 3+ enemigos", "On 3+ enemies", "oro",
    "Golpe en área: con varios enemigos rinde más que el golpe de uno; con uno solo, sáltalo.", "Area attack: with several enemies it beats single-target; with one enemy, skip it." },
  BUFF = { "Mantenlo puesto", "Keep it up", "verde",
    "Es un efecto sobre ti: si falta, ponlo antes de seguir con los golpes.", "It is an effect on you: if it's missing, put it on before attacking." },
  DEBUFF = { "Mantenlo en el enemigo", "Keep it on the enemy", "verde",
    "Efecto sobre tu enemigo: si no lo tiene, ponlo; mientras dure, sigue con lo demás.", "Effect on your enemy: if it's missing, apply it; while it lasts, keep going with the rest." },
  CD = { "Cada vez que esté listo", "Whenever it's ready", "oro",
    "Golpe fuerte con recarga: úsalo en cuanto vuelva a estar listo, después de los efectos.", "Strong ability with a cooldown: use it as soon as it's ready, after your effects." },
  RELLENO = { "Relleno", "Filler", "neutro",
    "Lo que pulsas cuando todo lo de arriba está puesto o en recarga.", "What you press when everything above is up or on cooldown." },
  ANTES = { "Antes de pelear", "Before the fight", "oro",
    "Se usa para empezar la pelea, no a mitad de ella.", "Used to open the fight, not in the middle of it." },
  CURA = { "Para curar", "To heal", "verde",
    "Con un aliado como objetivo, el modo te pide curas primero.", "With an ally targeted, the mode asks for heals first." },
  SIT = { "Según la situación", "Situational", "gris",
    "Depende de lo que pase (huir, aturdir, emergencia): el modo no lo pide solo, lo decides tú.", "Depends on what happens (escape, stun, emergency): the mode won't ask for it, you decide." },
  MASCOTA = { "Invoca tu mascota", "Summon your pet", "oro",
    "Sin mascota, el modo te lo pide antes de pelear.", "Without a pet, the mode asks for it before the fight." },
}
function WowF.aprendizajeCuando(golpes, cl)
  local grupoTomado = {}
  for _, g in ipairs(golpes or {}) do
    local ok, k, info = pcall(A.clasificar, g, cl)
    if not ok then k, info = "SIT", {} end
    info = info or {}
    local extra
    if info.grupo and (k == "BUFF" or k == "CD" or k == "RELLENO" or k == "ANTES") then
      -- de un grupo (sello, aspecto, aura, forma, postura...) se mantiene uno: el primero de la guia
      if grupoTomado[info.grupo] then k = "SIT"; extra = L("solo uno a la vez", "only one at a time")
      else grupoTomado[info.grupo] = true; k = "BUFF" end
    end
    local c = CUANDO[k] or CUANDO.RELLENO
    local corto, largo = L(c[1], c[2]), L(c[4], c[5])
    local d = info.d
    local dur, cd = d and d[1], d and d[2]
    if info.sigilo then corto = L("Antes de pelear: sigilo", "Before the fight: stealth")
    elseif k == "BUFF" then
      if info.antes then corto = L("Antes de pelear", "Before the fight")
      elseif dur == -1 or not dur then corto = L("Ponlo una vez", "Put it on once")
      elseif tiempo(dur) then corto = L("Mantenlo · dura ", "Keep it up · lasts ") .. tiempo(dur) end
      if info.grupo then largo = largo .. " " .. L("De este tipo, solo uno a la vez.", "Only one of this kind at a time.") end
    elseif k == "DEBUFF" and dur and dur > 0 and tiempo(dur) then corto = L("En el enemigo · dura ", "On the enemy · lasts ") .. tiempo(dur)
    elseif k == "CD" and tiempo(cd) then corto = L("Cuando esté listo · ", "When ready · ") .. tiempo(cd)
    elseif k == "AOE" and tiempo(cd) and cd > GCD then largo = largo .. " " .. L("Recarga: ", "Cooldown: ") .. tiempo(cd) .. "." end
    if extra then corto = L(c[1], c[2]) .. " · " .. extra end
    g.cuando = { corto = corto, largo = largo, color = c[3], k = k }
  end
  return golpes
end

-- ===================== Lecturas del juego =====================
-- true = en espera (mas que el GCD), false = listo, nil = no se puede leer
local function enEspera(sp)
  if C_Spell and C_Spell.GetSpellCooldown then
    local ok, info = pcall(C_Spell.GetSpellCooldown, sp)
    if ok and type(info) == "table" then
      local ini, dur = num(info.startTime), num(info.duration)
      if ini and dur then return dur > GCD and (ini + dur - ahora()) > 0 end
      return nil
    end
  end
  if GetSpellCooldown then
    local ok, ini, dur = pcall(GetSpellCooldown, sp)
    if ok then
      ini, dur = num(ini), num(dur)
      if ini and dur then return dur > GCD and (ini + dur - ahora()) > 0 end
    end
  end
  return nil
end
-- true/false = se puede usar o no (sin recurso, no toca...), nil = no se puede leer
local function usable(sp)
  local f = (C_Spell and C_Spell.IsSpellUsable) or IsUsableSpell
  if not f then return nil end
  local ok, u = pcall(f, sp)
  if not ok or secreto(u) then return nil end
  return u and true or false
end
-- true/false = el aura esta o no, nil = no se puede leer
local function tieneAura(unidad, nombre, filtro)
  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
    local ok, a = pcall(C_UnitAuras.GetAuraDataBySpellName, unidad, nombre, filtro)
    if ok then
      if a == nil then return false end
      if secreto(a) then return nil end
      return true
    end
  end
  if AuraUtil and AuraUtil.FindAuraByName then
    local ok, a = pcall(AuraUtil.FindAuraByName, nombre, unidad, filtro)
    if ok then
      if secreto(a) then return nil end
      return a ~= nil
    end
  end
  return nil
end
local function hayObjetivo() return bool(UnitExists, "target") end
local function objetivoAmistoso()
  if hayObjetivo() ~= true then return false end
  local c = bool(UnitCanAttack, "player", "target")
  return c == false
end
local function objetivoLanza() -- UnitCastingInfo distinto de nil = lanza algo (aunque el nombre llegue secreto)
  if hayObjetivo() ~= true or objetivoAmistoso() then return false end
  for _, f in ipairs({ UnitCastingInfo or false, UnitChannelInfo or false }) do
    if f then local ok, r = pcall(f, "target"); if ok and r ~= nil then return true end end
  end
  return false
end
local function guidObjetivo()
  local ok, g = pcall(UnitGUID or function() end, "target")
  g = ok and txt(g)
  return g or "?"
end
local function hayMascota() return bool(UnitExists, "pet") == true end
local function enSigilo() return bool(IsStealthed) end
local function formaLeida(e) -- true/false = esa forma/postura puesta; nil = no se puede leer
  if e.grupo == "forma" then
    if not GetShapeshiftForm then return nil end
    local ok, f = pcall(GetShapeshiftForm)
    f = ok and num(f)
    if f == nil then return nil end
    if f == 0 then return false end
  end
  if not (GetNumShapeshiftForms and GetShapeshiftFormInfo) then return nil end
  local okN, total = pcall(GetNumShapeshiftForms)
  total = okN and num(total)
  if not total then return nil end
  local leido = false
  for i = 1, total do
    local ok, _, activa, _, sid = pcall(GetShapeshiftFormInfo, i)
    if ok and not secreto(activa) then
      leido = true
      sid = num(sid)
      if activa and sid and e.ids[sid] then return true end
    end
  end
  if leido then return false end
  return nil
end
local function totemLeido(e) -- true/false/nil
  if not GetTotemInfo then return nil end
  local leido = false
  for slot = 1, 4 do
    local ok, tiene, nombre = pcall(GetTotemInfo, slot)
    if ok and not secreto(tiene) then
      leido = true
      nombre = txt(nombre)
      if tiene and nombre and nombre:find(e.cliente, 1, true) then return true end
    end
  end
  if leido then return false end
  return nil
end
local function enemigosCerca() -- placas de enemigos atacables (que no esten fuera de combate)
  local c = 0
  for unidad in pairs(A.placas) do
    if bool(UnitExists, unidad) == false then A.placas[unidad] = nil
    elseif bool(UnitAffectingCombat, unidad) ~= false then c = c + 1 end
  end
  return c
end
function A.varios()
  local m = modoObjetivos()
  if m == "varios" then return true end
  if m == "uno" then return false end
  return enemigosCerca() >= 3
end
local function fueraDeAlcance(e) -- true solo si el juego dice claramente que no llega
  if hayObjetivo() ~= true then return false end
  local sp = e.id or e.cliente
  for _, f in ipairs({ (C_Spell and C_Spell.IsSpellInRange) or false, IsSpellInRange or false }) do
    if f then
      local ok, r = pcall(f, f == IsSpellInRange and e.cliente or sp, "target")
      if ok and not secreto(r) and r ~= nil then return r == false or r == 0 end
    end
  end
  return false
end

-- ===================== Lista (se rehace solo con eventos, nunca en cada tick) =====================
local function nombreCliente(id, porDefecto)
  if id and C_Spell and C_Spell.GetSpellName then local ok, n = pcall(C_Spell.GetSpellName, id); n = ok and txt(n); if n and n ~= "" then return n end end
  if id and GetSpellInfo then local ok, n = pcall(GetSpellInfo, id); n = ok and txt(n); if n and n ~= "" then return n end end
  return porDefecto
end
local BARRAS = { { 1, "ACTIONBUTTON" }, { 25, "MULTIACTIONBAR3BUTTON" }, { 37, "MULTIACTIONBAR4BUTTON" }, { 49, "MULTIACTIONBAR2BUTTON" }, { 61, "MULTIACTIONBAR1BUTTON" } }
local function coincide(e, id)
  if not id then return false end
  if e.ids[id] then return true end
  local n = nombreCliente(id, nil)
  return n ~= nil and (n == e.cliente or n == e.nombre)
end
local function corta(k)
  if not k then return nil end
  return (k:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-"):gsub("BUTTON", "M"))
end
-- Tecla del golpe y casilla de la barra donde esta (para el brillo)
local function teclaDe(e)
  local k
  if GetBindingKey then local ok, b = pcall(GetBindingKey, "SPELL " .. e.cliente); k = ok and txt(b) or nil end
  if not GetActionInfo then return corta(k), nil end
  for slot = 1, 120 do
    local okA, tipo, id = pcall(GetActionInfo, slot)
    if okA and txt(tipo) == "spell" and coincide(e, num(id)) then
      if not k and GetBindingKey then
        local boton
        if slot <= 12 or slot > 72 then boton = "ACTIONBUTTON" .. ((slot - 1) % 12 + 1)
        else for _, b in ipairs(BARRAS) do if slot >= b[1] and slot < b[1] + 12 then boton = b[2] .. (slot - b[1] + 1) end end end
        if boton then local okB, kb = pcall(GetBindingKey, boton); k = okB and txt(kb) or nil end
      end
      return corta(k), slot
    end
  end
  return corta(k), nil
end

local function clase()
  if not UnitClass then return nil end
  local ok, _, c = pcall(UnitClass, "player")
  return ok and txt(c) or nil
end

-- Rehace la cola desde WowF.datosVistaCombate (orden de la guia de tu rama y modo)
function A.rehacer()
  A.sucio = false
  for k in pairs(A.cola) do A.cola[k] = nil end
  for k in pairs(A.seq) do A.seq[k] = nil end
  A.sinDatos, A.aviso, A.rama, A.modoRot, A.curador = nil, nil, nil, nil, nil
  if not WowF.datosVistaCombate then A.sinDatos = true; return end
  local okP, p = pcall(WowF.armarPlan or function() return nil end)
  local ok, d = pcall(WowF.datosVistaCombate, okP and p or nil)
  if not ok or type(d) ~= "table" then A.sinDatos = true; return end
  A.rama, A.modoRot = d.rama, d.modo
  -- Rama sin datos de WoW Forever (la vista del Libro usa otra rama de la clase como relleno: aqui no)
  local ROT = WowF.datosRotacion and WowF.datosRotacion()
  local cl = d.clase or clase()
  local hayPvE = ROT and ROT[cl or ""] and d.rama and ROT[cl][d.rama]
  local listaPvP = d.modo == "pvp" and not d.aviso
  if d.sinDatos or not (hayPvE or listaPvP) then A.sinDatos = true; return end
  local hech = WowFHechizos and WowFHechizos[cl or ""] or {}
  local grupoTomado = {}
  local noCura = 0
  for _, g in ipairs(d.golpes or {}) do
    if g.ya then
      local h = hech[g.nombre]
      local e = { nombre = g.nombre, id = g.id, icono = g.icono or (WowF.iconoHechizo and WowF.iconoHechizo(g.id or g.nombre, cl)), ids = {} }
      if type(h) == "table" then for i = 2, #h do e.ids[h[i]] = true end end
      if g.id then e.ids[g.id] = true end
      e.cliente = nombreCliente(g.id, g.nombre)
      local okC, k, info = pcall(A.clasificar, g, cl)
      if not okC then k, info = "SIT", {} end
      e.k, e.d, e.grupo, e.antes, e.sigilo = k, info.d, info.grupo, info.antes, info.sigilo
      e.cura = k == "CURA"
      e.totem = g.nombre:find(" Totem$") ~= nil
      e.mascota = k == "MASCOTA"
      e.cat = e.d and e.d[2] and e.d[3] or nil
      -- de un grupo (sello, aspecto, aura, forma, postura...) solo se mantiene el primero de la guia que conoces
      if e.grupo and (k == "BUFF" or k == "CD" or k == "RELLENO" or k == "ANTES") then
        if grupoTomado[e.grupo] then e.k = "SIT" else grupoTomado[e.grupo] = true; e.k = "BUFF" end
        if e.k == "BUFF" and not (e.d and e.d[1]) then e.permanente = true end
      end
      local okT, tecla, slot = pcall(teclaDe, e)
      e.tecla, e.slot = okT and tecla or nil, okT and slot or nil
      table.insert(A.cola, e)
      if e.k ~= "SIT" and e.k ~= "CURA" and e.k ~= "MASCOTA" and e.k ~= "INTERR" then noCura = noCura + 1 end
      if e.k ~= "SIT" and not e.cura and e.k ~= "INTERR" and e.k ~= "MASCOTA" and not e.antes then table.insert(A.seq, e) end
    end
  end
  if A.pos > #A.seq then A.pos = 1 end
  A.curador = noCura == 0
  if #A.seq == 0 then -- curador puro: la secuencia son sus curas
    for _, e in ipairs(A.cola) do if e.cura then table.insert(A.seq, e) end end
  end
end

-- ===================== Cuenta propia =====================
local function brillado(e)
  for id in pairs(e.ids) do if A.brillo[id] then return true end end
  return false
end
local function listo(e, t)
  if A.sim[e] then return false end
  local cd = enEspera(e.id or e.cliente)
  if cd ~= nil then return not cd end
  if (A.cdHasta[e.nombre] or 0) > t then return false end
  if e.cat and (A.catHasta[e.cat] or 0) > t then return false end
  return true
end
local function buffFalta(e, t)
  if A.sim[e] then return false end
  if e.mascota then return not hayMascota() end
  if e.sigilo then local s = enSigilo(); if s ~= nil then return not s end end
  if e.grupo == "forma" or e.grupo == "postura" then
    local f = formaLeida(e)
    if f ~= nil then return not f end
  elseif e.totem then
    local f = totemLeido(e)
    if f ~= nil then return not f end
  elseif not e.sigilo then
    local a = tieneAura("player", e.cliente, "HELPFUL")
    if a ~= nil then
      if a == false then A.buffHasta[e.nombre] = nil end
      return not a
    end
  end
  return (A.buffHasta[e.nombre] or 0) - t < 2
end
local function debuffFalta(e, t)
  if A.sim[e] then return false end
  if hayObjetivo() == false then return false end
  local a = tieneAura("target", e.cliente, "HARMFUL|PLAYER")
  if a ~= nil then return not a end
  local d = A.debuff[e.nombre]
  return ((d and d[guidObjetivo()]) or 0) - t < 1
end
local function contar(e, t)
  local d = e.d
  if d then
    if d[2] then A.cdHasta[e.nombre] = t + d[2]; if d[3] then A.catHasta[d[3]] = t + d[2] end end
    local dur = d[1]
    if dur and (e.k == "BUFF" or d[4] == "b" or d[4] == "t") then A.buffHasta[e.nombre] = dur < 0 and INFINITO or t + dur
    elseif dur and d[4] == "d" then
      A.debuff[e.nombre] = A.debuff[e.nombre] or {}
      A.debuff[e.nombre][guidObjetivo()] = dur < 0 and INFINITO or t + dur
    end
  elseif e.k == "BUFF" or e.permanente then
    A.buffHasta[e.nombre] = INFINITO
  end
  if e.grupo then -- otro del mismo grupo deja de estar puesto
    for _, o in ipairs(A.cola) do if o ~= e and o.grupo == e.grupo then A.buffHasta[o.nombre] = nil end end
  end
end
function A.olvidar(soloDebuffs)
  for k in pairs(A.debuff) do A.debuff[k] = nil end
  if soloDebuffs then return end
  for _, t in ipairs({ A.cdHasta, A.catHasta, A.buffHasta, A.brillo }) do for k in pairs(t) do t[k] = nil end end
end

-- ===================== Motor "prioridad" =====================
local POR = { -- por que se recomienda (se muestra debajo del nombre)
  interr = { "Interrumpe: tu objetivo está lanzando un hechizo", "Interrupt: your target is casting" },
  brillo = { "Se encendió: úsalo ya", "It lit up: use it now" },
  reaccion = { "Ya se puede usar: úsalo antes de que se pase", "Usable now: use it before it fades" },
  aoe = { "Varios enemigos (%d): golpe en área", "Several enemies (%d): area attack" },
  aoeFijo = { "Modo varios enemigos: golpe en área", "Multi-target mode: area attack" },
  buff = { "Te falta este efecto", "This effect is missing" },
  debuff = { "Ponlo en tu objetivo", "Put it on your target" },
  cd = { "Listo de nuevo", "Ready again" },
  relleno = { "Relleno: úsalo mientras lo demás espera", "Filler: use it while the rest is on cooldown" },
  cura = { "Tu objetivo es amistoso: cura", "Your target is friendly: heal" },
  curaSola = { "Eres curador: elige a quien curar", "You are a healer: pick who to heal" },
  mascota = { "Sin mascota: invócala", "No pet: summon it" },
  antes = { "Antes de pelear: empieza con esto", "Before the fight: start with this" },
  sigilo = { "Antes de pelear: entra en sigilo", "Before the fight: go into stealth" },
}
local function puede(e, t) return usable(e.id or e.cliente) ~= false and listo(e, t) end
local function elegir(e, por)
  A.n = A.n + 1; A.elegidos[A.n] = e; A.porque[A.n] = por
  if not ((e.k == "RELLENO" or e.k == "CURA") and not (e.d and e.d[2])) then A.sim[e] = true end
end
-- Un hueco: devuelve el golpe y su porque
local function hueco(t, amistoso, varios, lanza)
  local cola = A.cola
  if amistoso then
    for _, e in ipairs(cola) do if e.k == "CURA" and puede(e, t) then return e, "cura" end end
    -- sin curas (o ya elegidas): al menos los efectos propios que faltan
    for _, e in ipairs(cola) do
      if e.k == "BUFF" and not e.sigilo and usable(e.id or e.cliente) ~= false and buffFalta(e, t) and listo(e, t) then return e, "buff" end
    end
    return nil
  end
  if lanza and A.n == 0 then
    for _, e in ipairs(cola) do if e.k == "INTERR" and puede(e, t) then return e, "interr" end end
  end
  for _, e in ipairs(cola) do
    if e.k ~= "SIT" and e.k ~= "INTERR" and e.k ~= "MASCOTA" and not e.cura and not A.sim[e] then
      if brillado(e) and puede(e, t) then return e, "brillo" end
      if e.k == "REACT" and usable(e.id or e.cliente) == true and listo(e, t) then return e, "reaccion" end
    end
  end
  if varios then
    for _, e in ipairs(cola) do if e.k == "AOE" and puede(e, t) then return e, "aoe" end end
  end
  for _, e in ipairs(cola) do
    if e.k == "BUFF" and not e.sigilo and usable(e.id or e.cliente) ~= false and buffFalta(e, t) and listo(e, t) then return e, "buff" end
  end
  if hayObjetivo() ~= false then
    for _, e in ipairs(cola) do
      if e.k == "DEBUFF" and not e.antes and usable(e.id or e.cliente) ~= false and debuffFalta(e, t) and listo(e, t) then return e, "debuff" end
    end
  end
  for _, e in ipairs(cola) do if e.k == "CD" and puede(e, t) then return e, "cd" end end
  for _, e in ipairs(cola) do if e.k == "RELLENO" and puede(e, t) then return e, "relleno" end end
  if A.curador then
    for _, e in ipairs(cola) do if e.k == "CURA" and puede(e, t) then return e, "curaSola" end end
  end
  return nil
end
-- Fuera de combate: lo que conviene antes de la pelea (mascota, sigilo, buffs que faltan, abridor)
local function huecoAntes(t)
  for _, e in ipairs(A.cola) do if e.k == "MASCOTA" and not hayMascota() and not A.sim[e] then return e, "mascota" end end
  for _, e in ipairs(A.cola) do
    if e.k == "BUFF" and usable(e.id or e.cliente) ~= false and buffFalta(e, t) then return e, e.sigilo and "sigilo" or "buff" end
  end
  for _, e in ipairs(A.cola) do
    if e.sigilo and e.k == "ANTES" and buffFalta(e, t) then return e, "sigilo" end
  end
  for _, e in ipairs(A.cola) do
    if (e.k == "ANTES" or (e.antes and e.k == "DEBUFF")) and not e.sigilo and not A.sim[e] and usable(e.id or e.cliente) ~= false then return e, "antes" end
  end
  return nil
end
local function motorPrioridad()
  local t = ahora()
  for k in pairs(A.sim) do A.sim[k] = nil end
  A.n = 0
  if not A.enCombate then
    for _ = 1, 3 do
      local e, por = huecoAntes(t)
      if not e then break end
      elegir(e, por); A.sim[e] = true
    end
    return
  end
  local amistoso, varios, lanza = objetivoAmistoso(), A.varios(), objetivoLanza()
  A.variosAhora = varios
  for _ = 1, 3 do
    local e, por = hueco(t, amistoso, varios, lanza)
    if not e then break end
    elegir(e, por)
  end
end

-- ===================== Motor viejo (sin datos de duraciones) =====================
-- 13-oct (diagnostico de Andy en combate: cooldown y recursos SECRETOS, C_Spell.IsSpellUsable LEGIBLE): la secuencia salta lo que el
-- juego dice que ahora no se puede usar (sin ira/mana, Execute/Overpower/Revenge sin su condicion). Si no se puede leer, se queda.
local function motorSecuencia()
  local s = #A.seq
  A.n = 0
  if s == 0 then return end
  for k = 0, s - 1 do
    local e = A.seq[(A.pos - 1 + k) % s + 1]
    if usable(e.id or e.cliente) ~= false then A.n = A.n + 1; A.elegidos[A.n] = e; A.porque[A.n] = nil; if A.n >= 3 then break end end
  end
  if A.n == 0 then for k = 0, math.min(s, 3) - 1 do A.n = A.n + 1; A.elegidos[A.n] = A.seq[(A.pos - 1 + k) % s + 1]; A.porque[A.n] = nil end end
end
local function avanzar()
  local s = #A.seq
  if s > 0 then A.pos = A.pos % s + 1 end
  A.ultimoAvance = ahora()
end
function A.calcular()
  if A.sucio then A.rehacer() end
  if A.sinDatos then A.n = 0; A.modoMotor = nil; return end
  if type(WowFDuraciones) == "table" then
    motorPrioridad()
    if A.n > 0 or not A.enCombate then A.modoMotor = "prioridad"; return end
  end
  motorSecuencia()
  if A.eventoLegible then A.modoMotor = "secuencia"
  else
    A.modoMotor = "simple"
    -- sin ningun evento de lanzamiento en este combate: avanza solo cada ~1,5 s
    if A.enCombate and not A.eventoVisto and (ahora() - (A.ultimoAvance or 0)) >= GCD then avanzar() end
  end
end

-- UNIT_SPELLCAST_SUCCEEDED: cuenta propia (cooldown, efecto puesto) y avanza la secuencia de respaldo
function A.lanzado(spellID)
  A.eventoVisto = true
  local id = num(spellID)
  local nombre = id and nombreCliente(id, nil)
  if id or nombre then
    A.eventoLegible = true
    if not A.idEvento then A.idEvento = id and "legible" or "solo nombre" end
    local t = ahora()
    for _, e in ipairs(A.cola) do
      if (id and e.ids[id]) or (nombre and (nombre == e.cliente or nombre == e.nombre)) then
        contar(e, t)
        if e.nombre == "Judgement" then for _, o in ipairs(A.cola) do if o.grupo == "sello" then A.buffHasta[o.nombre] = nil end end end
      end
    end
    if nombre == "Judgement" then for _, o in ipairs(A.cola) do if o.grupo == "sello" then A.buffHasta[o.nombre] = nil end end end
    for k, e in ipairs(A.seq) do
      if (id and e.ids[id]) or (nombre and (nombre == e.cliente or nombre == e.nombre)) then
        A.pos = k; avanzar(); return
      end
    end
    return -- otro hechizo (racial, situacional...): la secuencia no se mueve
  end
  A.idEvento = A.idEvento or "secreto"
  avanzar()
end

-- ===================== Diagnostico =====================
local function probar(f, ...)
  if type(f) ~= "function" then return "no existe" end
  local ok, a = pcall(f, ...)
  if not ok then return "error" end
  if a == nil then return "nil" end
  if secreto(a) then return "secreto" end
  if type(a) == "table" then
    local okT, hayS = pcall(function() for _, x in pairs(a) do if secreto(x) then return true end end return false end)
    if not okT then return "error" end
    if hayS then return "secreto" end
  end
  return "legible"
end
local NOMBRES_DIAG = {
  { "cdNuevo", "cooldown C_Spell" }, { "cdViejo", "GetSpellCooldown" }, { "usableNuevo", "C_Spell.IsSpellUsable" },
  { "usableViejo", "IsUsableSpell" }, { "auraNueva", "C_UnitAuras" }, { "auraVieja", "UnitAura" }, { "auraUtil", "AuraUtil" },
  { "poder", "UnitPower" }, { "vidaObjetivo", "UnitHealth(target)" }, { "casteo", "UnitCastingInfo" },
  { "idEvento", "spellID evento" }, { "asistido", "C_AssistedCombat" }, { "asistidoSiguiente", "GetNextCastSpell" },
  { "auraNombre", "C_UnitAuras por nombre" }, { "casteoObjetivo", "UnitCastingInfo(target)" }, { "rango", "IsSpellInRange" },
  { "placas", "C_NamePlate" }, { "guidObjetivo", "UnitGUID(target)" }, { "brillo", "brillo de procs" },
}
function A.diagnosticar(enCombate)
  local t = db()
  local sp = (A.cola[1] and A.cola[1].id) or 6603
  local buff = "Battle Shout"
  for _, e in ipairs(A.cola) do if e.k == "BUFF" and not e.sigilo and not e.totem then buff = e.cliente; break end end
  local okL, nivel = pcall(UnitLevel or function() end, "player")
  local r = {
    fecha = (date and date("%Y-%m-%d %H:%M")) or "?", nivel = okL and num(nivel) or nil, clase = clase(),
    combate = enCombate and "si" or "no", modo = A.modoMotor or "?",
    version = (C_AddOns and C_AddOns.GetAddOnMetadata and select(2, pcall(C_AddOns.GetAddOnMetadata, "ForeverLevelingGuide", "Version"))) or nil,
    cdNuevo = probar(C_Spell and C_Spell.GetSpellCooldown, sp),
    cdViejo = probar(GetSpellCooldown, sp),
    usableNuevo = probar(C_Spell and C_Spell.IsSpellUsable, sp),
    usableViejo = probar(IsUsableSpell, sp),
    auraNueva = probar(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex, "player", 1, "HELPFUL"),
    auraVieja = probar(UnitAura, "player", 1, "HELPFUL"),
    auraUtil = (AuraUtil and AuraUtil.FindAuraByName) and probar(AuraUtil.FindAuraByName, buff, "player", "HELPFUL") or "no existe",
    auraNombre = probar(C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName, "player", buff, "HELPFUL"),
    poder = probar(UnitPower, "player"),
    vidaObjetivo = probar(UnitHealth, "target"),
    casteo = probar(UnitCastingInfo, "player"),
    idEvento = A.idEvento or "sin ver",
    asistido = C_AssistedCombat and "existe" or "no existe",
    asistidoSiguiente = probar(C_AssistedCombat and C_AssistedCombat.GetNextCastSpell),
    casteoObjetivo = probar(UnitCastingInfo, "target"),
    rango = probar((C_Spell and C_Spell.IsSpellInRange) or IsSpellInRange, sp, "target"),
    placas = probar(C_NamePlate and C_NamePlate.GetNamePlates),
    guidObjetivo = probar(UnitGUID, "target"),
    brillo = A.brilloVisto and "visto" or "sin ver",
  }
  if type(r.version) ~= "string" then r.version = nil end
  t.diagCombate = t.diagCombate or {}
  table.insert(t.diagCombate, r)
  while #t.diagCombate > 20 do table.remove(t.diagCombate, 1) end
  if WowF.aprendizajeActivo() and not t.diagCombateAvisado then
    t.diagCombateAvisado = true
    print(PREFIJO .. L("modo aprendizaje: diagnóstico guardado (cooldowns: ", "learning mode: diagnosis saved (cooldowns: ") ..
      r.cdNuevo .. ", " .. L("auras: ", "auras: ") .. r.auraNueva .. "). /wowf " .. L("aprender diag", "learn diag"))
  end
  return r
end
function A.textoDiag()
  local t = db().diagCombate
  local r = t and t[#t]
  if not r then return L("aún no hay diagnóstico (entra en combate con el modo encendido)", "no diagnosis yet (enter combat with the mode on)") end
  local partes = {}
  for _, c in ipairs(NOMBRES_DIAG) do table.insert(partes, c[2] .. "=" .. tostring(r[c[1]])) end
  return (r.fecha or "?") .. " nv " .. tostring(r.nivel) .. " " .. tostring(r.clase) .. " " .. L("combate ", "combat ") .. r.combate ..
    " · " .. L("motor ", "engine ") .. tostring(r.modo) .. "\n" .. table.concat(partes, ", ")
end

-- 13-oct (Andy: "como copia el codigo para pasartelo"): el chat del juego no se puede copiar; el diagnostico sale en una ventana
-- con el codigo FLG-DIAG ya seleccionado (Ctrl+C) para pegarlo en los comentarios de CurseForge. Una linea, valores abreviados.
local CORTO = { legible = "L", secreto = "S", error = "E", ["no existe"] = "-", existe = "si", ["sin ver"] = "?", visto = "V" }
local CLAVE_CORTA = { cdNuevo = "cdN", cdViejo = "cdV", usableNuevo = "usN", usableViejo = "usV", auraNueva = "auN", auraVieja = "auV",
  auraUtil = "auU", poder = "pod", vidaObjetivo = "vidT", casteo = "cast", idEvento = "idEv", asistido = "asis", asistidoSiguiente = "asisSig",
  auraNombre = "auNom", casteoObjetivo = "castT", rango = "rango", placas = "placas", guidObjetivo = "guidT", brillo = "brillo" }
function A.codigoDiag()
  local t = db().diagCombate
  local r = t and t[#t]
  if not r then return nil end
  local partes = {}
  for _, c in ipairs(NOMBRES_DIAG) do
    local val = tostring(r[c[1]])
    table.insert(partes, (CLAVE_CORTA[c[1]] or c[1]) .. "=" .. (CORTO[val] or val))
  end
  return "FLG-DIAG " .. tostring(r.version or (WowF.versionAddon and WowF.versionAddon()) or "?") .. " " .. tostring(r.clase) ..
    " nv" .. tostring(r.nivel) .. " comb:" .. tostring(r.combate) .. " motor:" .. tostring(r.modo) .. " | " .. table.concat(partes, " ") ..
    " | " .. tostring(r.fecha)
end
function WowF.aprendizajeDiag()
  local codigo = A.codigoDiag()
  if not codigo or not WowF.mostrarCodigo then print(PREFIJO .. A.textoDiag()); return false end
  print(PREFIJO .. A.textoDiag())
  return WowF.mostrarCodigo(L("Modo aprendizaje: ayúdanos a mejorarlo", "Learning mode: help us improve it"),
    L("Esto dice qué deja leer el juego en combate (nada personal).\n\n1. Haz clic en el código y pulsa Ctrl+C.\n2. Pégalo (Ctrl+V) en los comentarios de Forever Leveling Guide en CurseForge.",
      "This shows what the game lets addons read in combat (nothing personal).\n\n1. Click the code and press Ctrl+C.\n2. Paste it (Ctrl+V) in the Forever Leveling Guide comments on CurseForge."),
    codigo)
end

-- ===================== Brillo en el boton de tu barra y sonido =====================
-- Marco propio encima del boton (anclado a UIParent con la posicion del boton): nunca se toca el boton seguro.
local function botonDeSlot(slot)
  if not slot then return nil end
  local i = (slot - 1) % 12 + 1
  local candidatos = { "BT4Button" .. slot, "DominosActionButton" .. slot, "ElvUI_Bar" .. math.ceil(slot / 12) .. "Button" .. i }
  if slot <= 12 or slot > 72 then candidatos[#candidatos + 1] = "ActionButton" .. i
  elseif slot <= 36 then candidatos[#candidatos + 1] = "MultiBarRightButton" .. (slot - 24)
  elseif slot <= 48 then candidatos[#candidatos + 1] = "MultiBarLeftButton" .. (slot - 36)
  elseif slot <= 60 then candidatos[#candidatos + 1] = "MultiBarBottomRightButton" .. (slot - 48)
  else candidatos[#candidatos + 1] = "MultiBarBottomLeftButton" .. (slot - 60) end
  for _, nombre in ipairs(candidatos) do
    local b = _G[nombre]
    if type(b) == "table" and b.GetCenter then
      local ok, vis = pcall(b.IsVisible, b)
      if ok and vis then return b end
    end
  end
  return nil
end
local brilloMarco
function A.brilloBarra(e)
  local quiere = e and A.enCombate and db().aprendizajeBrillo ~= false
  local b = quiere and botonDeSlot(e.slot)
  local x, y, w, s
  if b then
    local ok, cx, cy = pcall(b.GetCenter, b)
    x, y = ok and num(cx), ok and num(cy)
    local okW, ww = pcall(b.GetWidth, b)
    w = okW and num(ww) or 36
    local okS, es = pcall(b.GetEffectiveScale, b)
    local okU, eu = pcall(UIParent.GetEffectiveScale, UIParent)
    s = (okS and num(es) or 1) / ((okU and num(eu)) or 1)
  end
  if not (b and x and y) then if brilloMarco then brilloMarco:Hide() end; A.brilloEn = nil; return end
  if not brilloMarco then
    brilloMarco = CreateFrame("Frame", "wowFAprendizajeBrillo", UIParent)
    brilloMarco:SetFrameStrata("HIGH")
    if brilloMarco.EnableMouse then brilloMarco:EnableMouse(false) end
    local tex = brilloMarco:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(brilloMarco)
    tex:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    if tex.SetBlendMode then tex:SetBlendMode("ADD") end
    tex:SetVertexColor(1, 0.82, 0.25)
    brilloMarco.tex = tex
    local fase = 0
    brilloMarco:SetScript("OnUpdate", function(_, dt)
      fase = fase + (dt or 0) * 4
      tex:SetAlpha(0.55 + 0.45 * math.sin(fase))
    end)
  end
  brilloMarco:ClearAllPoints()
  brilloMarco:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * s, y * s)
  brilloMarco:SetSize(w * s + 10, w * s + 10)
  brilloMarco:Show()
  A.brilloEn = e.slot
end
local SONIDO = (SOUNDKIT and SOUNDKIT.MAP_PING) or 3175
function A.sonar(e, por)
  if not e or (por ~= "brillo" and por ~= "reaccion" and por ~= "interr") then A.sonadoCon = nil; return end
  if db().aprendizajeSonido == false or A.sonadoCon == e then return end
  local t = ahora()
  if t - (A.sonidoT or -10) < 2 then return end
  A.sonadoCon, A.sonidoT = e, t
  A.sonidos = (A.sonidos or 0) + 1
  if PlaySound then pcall(PlaySound, SONIDO, "Master") end
end

-- ===================== Ventana =====================
local v -- la ventana (se crea la primera vez que se enciende)
local TEXTO_MODO = {
  prioridad = { "prioridad", "priority" },
  secuencia = { "secuencia", "sequence" }, simple = { "modo simple", "simple mode" },
}
local TEXTO_OBJ = { auto = { "Auto", "Auto" }, uno = { "1", "1" }, varios = { "AoE", "AoE" } }
local SIGUIENTE_OBJ = { auto = "uno", uno = "varios", varios = "auto" }
local function guardarPos()
  if not v then return end
  local ok, a, _, b, x, y = pcall(v.GetPoint, v, 1)
  if ok and a and type(x) == "number" and type(y) == "number" then db().aprendizajePos = { a, b or a, x, y } end
end
function WowF.aprendizajeObjetivos(m)
  if m ~= "uno" and m ~= "varios" and m ~= "auto" then m = SIGUIENTE_OBJ[modoObjetivos()] end
  db().aprendizajeObjetivos = m
  local txtM = { auto = L("automático (varios con 3 o más enemigos cerca)", "automatic (multi-target with 3+ enemies nearby)"),
    uno = L("un objetivo", "single target"), varios = L("varios enemigos (golpes en área)", "multi-target (area attacks)") }
  print(PREFIJO .. L("modo aprendizaje: objetivos = ", "learning mode: targets = ") .. txtM[m])
  if v and v.modoBtn then v.modoBtn:SetText(L(TEXTO_OBJ[m][1], TEXTO_OBJ[m][2])) end
  if v and v:IsShown() then pcall(A.pintar) end
  return m
end
local function crearVentana()
  if v then return v end
  local E = WowF.estilo
  v = CreateFrame("Frame", "wowFAprendizaje", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  v:SetSize(272, 130)
  v:SetFrameStrata("MEDIUM")
  local g = db().aprendizajePos
  if type(g) == "table" and type(g[3]) == "number" and type(g[4]) == "number" then v:SetPoint(g[1], UIParent, g[2], g[3], g[4])
  else v:SetPoint("CENTER", UIParent, "CENTER", 0, -180) end
  if E and E.marco then pcall(E.marco, v, "panel") end
  v:SetMovable(true); v:EnableMouse(true); v:RegisterForDrag("LeftButton")
  v:SetScript("OnDragStart", function(s) s:StartMoving() end)
  v:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); guardarPos() end)
  v:SetScript("OnEnter", function(s)
    if not GameTooltip then return end
    GameTooltip:SetOwner(s, "ANCHOR_TOP")
    GameTooltip:SetText(L("Modo aprendizaje", "Learning mode"), 1, 1, 1)
    GameTooltip:AddLine(L("Grande = el golpe que toca AHORA y por qué; chicos = los 2 siguientes. Solo te lo muestra: tú lo pulsas.",
      "Big = the ability to press NOW and why; small = the next 2. It only shows it: you press it."), 0.85, 0.82, 0.76, true)
    GameTooltip:AddLine(L("Va por prioridad: interrumpir, lo que se encendió, efectos que faltan, lo que está listo y el relleno.",
      "It goes by priority: interrupts, what lit up, missing effects, what is ready and the filler."), 0.85, 0.82, 0.76, true)
    GameTooltip:AddLine(L("Arrástrala para moverla. /wowf aprender off para apagarla.", "Drag to move it. /wowf learn off to turn it off."), 0.64, 0.6, 0.55, true)
    GameTooltip:Show()
  end)
  v:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  local function fuente(tam, color)
    local fs = v:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if E and E.texto then pcall(E.texto, v, fs, tam, color) end
    return fs
  end
  local C = E and E.color or {}
  v.titulo = fuente(12, C.oro or C.acento)
  v.titulo:SetPoint("TOPLEFT", v, "TOPLEFT", 12, -9); v.titulo:SetWidth(180); v.titulo:SetJustifyH("LEFT")
  v.cerrar = CreateFrame("Button", nil, v, "UIPanelCloseButton")
  v.cerrar:SetSize(22, 22); v.cerrar:SetPoint("TOPRIGHT", v, "TOPRIGHT", -3, -3)
  v.cerrar:SetScript("OnClick", function() WowF.aprendizajeActivar(false) end)
  -- Boton de objetivos: Auto / 1 / AoE (va rotando)
  v.modoBtn = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
  v.modoBtn:SetSize(44, 18); v.modoBtn:SetPoint("RIGHT", v.cerrar, "LEFT", -2, 0)
  v.modoBtn:SetText(L(TEXTO_OBJ[modoObjetivos()][1], TEXTO_OBJ[modoObjetivos()][2]))
  if E and E.boton then pcall(E.boton, v.modoBtn, "cuero") end
  v.modoBtn:SetScript("OnClick", function() WowF.aprendizajeObjetivos() end)
  v.modoBtn:SetScript("OnEnter", function(s)
    if not GameTooltip then return end
    GameTooltip:SetOwner(s, "ANCHOR_TOP")
    GameTooltip:SetText(L("Objetivos", "Targets"), 1, 1, 1)
    GameTooltip:AddLine(L("Auto: golpes en área si hay 3 o más enemigos cerca (cuenta sus placas de nombre).\n1: siempre un objetivo.\nAoE: siempre varios enemigos.\nClic para cambiar.",
      "Auto: area attacks with 3+ enemies nearby (counts their nameplates).\n1: always single target.\nAoE: always multi-target.\nClick to change."), 0.85, 0.82, 0.76, true)
    GameTooltip:Show()
  end)
  v.modoBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  v.grande = v:CreateTexture(nil, "ARTWORK")
  v.grande:SetSize(48, 48); v.grande:SetPoint("TOPLEFT", v, "TOPLEFT", 12, -32)
  v.chico2 = v:CreateTexture(nil, "ARTWORK"); v.chico2:SetSize(26, 26); v.chico2:SetPoint("TOPRIGHT", v, "TOPRIGHT", -12, -32)
  v.chico1 = v:CreateTexture(nil, "ARTWORK"); v.chico1:SetSize(26, 26); v.chico1:SetPoint("RIGHT", v.chico2, "LEFT", -5, 0)
  v.nombre = fuente(14, C.texto)
  v.nombre:SetPoint("TOPLEFT", v.grande, "TOPRIGHT", 10, -1); v.nombre:SetWidth(132); v.nombre:SetJustifyH("LEFT")
  v.tecla = fuente(12, C.oro or C.acento)
  v.tecla:SetPoint("TOPLEFT", v.nombre, "BOTTOMLEFT", 0, -3); v.tecla:SetWidth(132); v.tecla:SetJustifyH("LEFT")
  v.porque = fuente(11, C.verde or C.texto)
  v.porque:SetPoint("TOPLEFT", v.grande, "TOPRIGHT", 10, -34); v.porque:SetWidth(190); v.porque:SetJustifyH("LEFT")
  if v.porque.SetWordWrap then v.porque:SetWordWrap(true) end
  v.motor = fuente(11, C.tenue)
  v.motor:SetPoint("BOTTOMLEFT", v, "BOTTOMLEFT", 12, 8)
  v.aviso = fuente(12, C.tenue)
  v.aviso:SetPoint("TOPLEFT", v, "TOPLEFT", 12, -32); v.aviso:SetWidth(248); v.aviso:SetJustifyH("LEFT")
  if v.aviso.SetWordWrap then v.aviso:SetWordWrap(true) end
  local acumulado = 0
  v:SetScript("OnUpdate", function(_, dt)
    acumulado = acumulado + (dt or 0)
    if acumulado < TICK then return end
    acumulado = 0
    if A.enCombate or A.sucio or not A.yaPintado then A.pintar() end
  end)
  v:Hide()
  return v
end

local pintados = {}
local function ponerIcono(tex, e, clave)
  if pintados[clave] == e then return end
  pintados[clave] = e
  if e then tex:SetTexture(e.icono or "Interface\\Icons\\INV_Misc_QuestionMark"); tex:Show() else tex:Hide() end
end
local function textoPorque(por)
  local p = POR[por]
  if not p then return "" end
  if por == "aoe" then
    local c = enemigosCerca()
    if modoObjetivos() == "varios" or c < 3 then p = POR.aoeFijo else return string.format(L(p[1], p[2]), c) end
  end
  return L(p[1], p[2])
end
function A.pintar()
  if not v then return end
  A.calcular()
  A.yaPintado = true
  local modo = A.modoRot == "pvp" and "PvP" or "PvE"
  v.titulo:SetText(L("Modo aprendizaje", "Learning mode") .. " · " .. modo .. (A.rama and (" · " .. A.rama) or ""))
  if A.sinDatos or (A.n == 0 and #A.cola == 0) then
    ponerIcono(v.grande, nil, "g"); ponerIcono(v.chico1, nil, "c1"); ponerIcono(v.chico2, nil, "c2")
    v.nombre:SetText(""); v.tecla:SetText(""); v.motor:SetText(""); v.porque:SetText("")
    v.aviso:SetText(A.sinDatos and L("Aún no hay datos de WoW Forever para esta rama; se actualizará.", "No WoW Forever data for this spec yet; it will be updated.")
      or L("Aún no conoces ningún golpe de tu rotación.", "You don't know any ability of your rotation yet."))
    v.aviso:Show(); v:SetAlpha(1)
    A.brilloBarra(nil); A.sonar(nil)
    return
  end
  v.aviso:Hide()
  local e1, e2, e3 = A.elegidos[1], A.elegidos[2], A.elegidos[3]
  if A.n < 1 then e1 = nil end
  if A.n < 2 then e2 = nil end
  if A.n < 3 then e3 = nil end
  local por = A.n >= 1 and A.porque[1] or nil
  if not A.enCombate and not e1 then -- fuera de combate sin nada que preparar: el primer golpe de la rotacion
    e1, e2, e3 = A.seq[1], A.seq[2], A.seq[3]
    por = nil
  end
  ponerIcono(v.grande, e1, "g"); ponerIcono(v.chico1, e2, "c1"); ponerIcono(v.chico2, e3, "c2")
  local lejos = A.enCombate and e1 and fueraDeAlcance(e1)
  if v.grande.SetVertexColor then if lejos then v.grande:SetVertexColor(1, 0.3, 0.3) else v.grande:SetVertexColor(1, 1, 1) end end
  A.fueraAlcance = lejos and true or false
  v.nombre:SetText(e1 and e1.nombre or L("Espera...", "Wait...")) -- en una linea: si se parte en dos, la tecla tapa el porque
  if e1 and e1.tecla then v.tecla:SetText(L("Tecla: ", "Key: ") .. e1.tecla)
  elseif e1 and e1.slot then v.tecla:SetText(L("En tu barra (sin tecla)", "On your bar (no key)"))
  elseif e1 then v.tecla:SetText("|cffff8040" .. L("No está en tu barra", "Not on your bars") .. "|r")
  else v.tecla:SetText("") end
  if lejos then v.porque:SetText("|cffff4040" .. L("Fuera de alcance: acércate", "Out of range: get closer") .. "|r")
  else v.porque:SetText(textoPorque(por)) end
  if A.enCombate then
    local t = TEXTO_MODO[A.modoMotor or "simple"] or TEXTO_MODO.simple
    local extra = ""
    if A.modoMotor == "prioridad" and A.variosAhora then extra = " · " .. L("varios enemigos", "multi-target") end
    v.motor:SetText(L("Motor: ", "Engine: ") .. L(t[1], t[2]) .. extra)
    v:SetAlpha(1)
    A.brilloBarra(e1); A.sonar(e1, por)
  else
    v.motor:SetText(L("Listo · fuera de combate", "Ready · out of combat"))
    v:SetAlpha(0.5)
    A.brilloBarra(nil); A.sonar(nil)
  end
end
WowF.aprendizajeTexto = function() -- para las pruebas: lo que dice la ventana
  if not v then return "" end
  return table.concat({ v.titulo:GetText() or "", v.nombre:GetText() or "", v.tecla:GetText() or "", v.porque:GetText() or "",
    v.motor:GetText() or "", v.aviso:GetText() or "" }, " | ")
end

function A.aplicar()
  if not WowF.aprendizajeActivo() then if v then v:Hide() end; A.brilloBarra(nil); return end
  crearVentana()
  for k in pairs(pintados) do pintados[k] = nil end
  A.sucio = true
  if ocultarFuera() and not A.enCombate then v:Hide(); A.brilloBarra(nil); return end
  v:Show(); A.pintar()
end

function WowF.aprendizajeActivar(si)
  if si == nil then si = not WowF.aprendizajeActivo() end
  db().modoAprendizaje = si and true or false
  A.aplicar()
  print(PREFIJO .. L("modo aprendizaje ", "learning mode ") .. (si and L("ENCENDIDO", "ON") or L("APAGADO", "OFF")) ..
    " · /wowf " .. L("aprender on|off", "learn on|off"))
  -- 15-oct (Andy): que se entienda que es para principiantes y puede equivocarse
  if si then print(PREFIJO .. L("pensado para principiantes: el juego no deja leer todo en combate, así que a veces se equivoca. Úsalo como guía.",
    "made for beginners: the game does not let addons read everything in combat, so it is sometimes wrong. Use it as a guide.")) end
  if WowF.libroRedibujar then pcall(WowF.libroRedibujar) end
end

-- Boton en la vista vieja de la pestana Rotacion (WowF.contenidoRotacion de wowF_Rotacion.lua)
function WowF.itemAprendizaje(item)
  local si = WowF.aprendizajeActivo()
  item({ texto = (si and "|cff7dc35a" or "|cffffffff") .. L("Modo aprendizaje", "Learning mode") .. "|r|cff9a948c  ·  " ..
      L("te dice en combate qué golpe toca y por qué", "tells you in combat which ability is next and why") .. "|r",
    icono = "Interface\\Icons\\INV_Misc_Book_09", chico = true, boton = si and "elegido" or "si",
    ayuda = L("Modo aprendizaje", "Learning mode") .. "\n" .. L("Ventanita con el golpe que toca AHORA, por qué, y los 2 siguientes. Clic para encenderlo o apagarlo.",
      "Small window with the ability to press NOW, why, and the next 2. Click to turn it on or off."),
    accion = function() WowF.aprendizajeActivar(not WowF.aprendizajeActivo()) end })
end

-- ===================== Eventos =====================
local ev = CreateFrame("Frame")
local function registrar(nombre) pcall(ev.RegisterEvent, ev, nombre) end
registrar("PLAYER_LOGIN"); registrar("PLAYER_REGEN_DISABLED"); registrar("PLAYER_REGEN_ENABLED")
registrar("SPELLS_CHANGED"); registrar("PLAYER_LEVEL_UP"); registrar("ACTIONBAR_SLOT_CHANGED"); registrar("UPDATE_BINDINGS")
registrar("PLAYER_TALENT_UPDATE"); registrar("ZONE_CHANGED_NEW_AREA"); registrar("PLAYER_FLAGS_CHANGED")
registrar("PLAYER_DEAD"); registrar("PLAYER_TARGET_CHANGED")
registrar("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW"); registrar("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
registrar("NAME_PLATE_UNIT_ADDED"); registrar("NAME_PLATE_UNIT_REMOVED")
if ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player") else registrar("UNIT_SPELLCAST_SUCCEEDED") end
local diagDentro = false
local function repintar() if v and v:IsShown() then A.pintar() end end
ev:SetScript("OnEvent", function(_, evento, a1, a2, a3)
  local ok, err = pcall(function()
    if evento == "PLAYER_LOGIN" then
      if WowF.registrarCasillaOpciones and not A.casillas then
        A.casillas = true
        WowF.registrarCasillaOpciones("modoAprendizaje", function() return L("Modo aprendizaje: ventanita con el golpe que toca en combate", "Learning mode: small window with the ability to press in combat") end, true, function() A.aplicar() end)
        WowF.registrarCasillaOpciones("aprendizajeOcultar", function() return L("Modo aprendizaje: ocultarla fuera de combate", "Learning mode: hide it out of combat") end, true, function() A.aplicar() end)
        WowF.registrarCasillaOpciones("aprendizajeBrillo", function() return L("Modo aprendizaje: brillo en el botón de tu barra", "Learning mode: glow on your action bar button") end, nil, function() A.aplicar() end)
        WowF.registrarCasillaOpciones("aprendizajeSonido", function() return L("Modo aprendizaje: sonido cuando algo se enciende", "Learning mode: sound when something lights up") end, nil, function() A.aplicar() end)
      end
      A.sucio = true
      A.aplicar()
      pcall(A.diagnosticar, false)
    elseif evento == "PLAYER_REGEN_DISABLED" then
      A.enCombate = true; A.eventoVisto = false; A.ultimoAvance = ahora(); A.pos = 1
      if WowF.aprendizajeActivo() then A.aplicar() end
      if not diagDentro then diagDentro = true; pcall(A.diagnosticar, true) end
    elseif evento == "PLAYER_REGEN_ENABLED" then
      A.enCombate = false; A.pos = 1; A.olvidar(true); A.sonadoCon = nil
      if WowF.aprendizajeActivo() then A.aplicar() end
    elseif evento == "UNIT_SPELLCAST_SUCCEEDED" then
      if WowF.aprendizajeActivo() then A.lanzado(a3) end
    elseif evento == "PLAYER_DEAD" then
      A.olvidar(false); repintar()
    elseif evento == "PLAYER_TARGET_CHANGED" then
      for _, d in pairs(A.debuff) do d["?"] = nil end
      repintar()
    elseif evento == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or evento == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
      local id = num(a1)
      A.brilloVisto = true
      if id then A.brillo[id] = evento == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or nil end
      repintar()
    elseif evento == "NAME_PLATE_UNIT_ADDED" then
      local u = txt(a1)
      if u and bool(UnitCanAttack, "player", u) == true then A.placas[u] = true end
    elseif evento == "NAME_PLATE_UNIT_REMOVED" then
      local u = txt(a1)
      if u then A.placas[u] = nil end
    else
      A.sucio = true
      if v and v:IsShown() and not A.enCombate then A.pintar() end
    end
  end)
  if not ok and WowF.debug then print(PREFIJO .. tostring(err)) end
end)
-- Cambiar PvE/PvP en el Libro rehace la lista
if WowF.modoRotacion and not A.envuelto then
  A.envuelto = true
  local original = WowF.modoRotacion
  WowF.modoRotacion = function(nuevo, ...)
    local r = original(nuevo, ...)
    if nuevo and A then A.sucio = true; if v and v:IsShown() then pcall(A.pintar) end end
    return r
  end
end

-- ===================== /wowf aprender|learn [on|off|diag|auto|uno|aoe] =====================
local ordenAnterior = SlashCmdList and SlashCmdList["WOWF"]
if SlashCmdList then
  SlashCmdList["WOWF"] = function(mensaje)
    local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
    orden = (orden or ""):lower(); resto = (resto or ""):lower()
    if orden == "aprender" or orden == "learn" or orden == "aprendizaje" then
      if resto == "on" or resto == "si" then WowF.aprendizajeActivar(true)
      elseif resto == "off" or resto == "no" then WowF.aprendizajeActivar(false)
      elseif resto == "diag" then WowF.aprendizajeDiag()
      elseif resto == "aoe" or resto == "varios" or resto == "multi" then WowF.aprendizajeObjetivos("varios")
      elseif resto == "uno" or resto == "single" or resto == "1" then WowF.aprendizajeObjetivos("uno")
      elseif resto == "auto" then WowF.aprendizajeObjetivos("auto")
      else WowF.aprendizajeActivar(not WowF.aprendizajeActivo()) end
      return
    end
    return ordenAnterior and ordenAnterior(mensaje)
  end
end
