-- Forever Leveling Guide: idioma. El addon esta escrito en espanol; si el juego no esta en espanol (esES / esMX), todo lo que
-- muestra pasa por WowF.T() y sale en ingles. El diccionario (WowFDatosEN, en wowF_DatosEN.lua) lo genera
-- herramientas/generar-plan-addon.js desde herramientas/traducciones-en.json.
-- /wowf idioma en | es  elige el idioma (se guarda). Sin elegir: ingles.

WowF = WowF or {}
local cache, ncache, trozos = {}, 0, nil
-- 4-oct (idioma): textos que ya se armaron en el idioma elegido (p. ej. el tooltip de un talento con su descripcion
-- inglesa de Wowhead): WowF.T los deja tal cual (antes los pasaba por trozos y salian mezclados)
local listos, nlistos = {}, 0
function WowF.yaTraducido(s)
  if type(s) == "string" and s ~= "" and not listos[s] then
    if nlistos > 4000 then listos, nlistos = {}, 0 end
    listos[s] = true; nlistos = nlistos + 1
  end
  return s
end

function WowF.enIngles()
  local db = _G.WowFExportarDB
  if type(db) == "table" and db.idioma == "es" then return false end
  -- Sin elegir (o "auto"): ingles, tambien con el cliente en espanol (pedido de Andy, 4-oct: la bienvenida sale en
  -- ingles y cada uno pasa a espanol si quiere)
  return true
end

-- Una letra (ASCII o parte de un caracter UTF-8 como a, e, n con acento) pegada al trozo: entonces no es una palabra suelta
local function esLetra(b) return b and (b >= 128 or (b >= 65 and b <= 90) or (b >= 97 and b <= 122)) end
-- Justo antes hay un codigo de color (|cffrrggbb) o un |r / |t: eso no es una letra pegada aunque termine en "f" o "r"
local function trasCodigo(r, a)
  if a > 10 and r:sub(a - 10, a - 1):match("^|c%x%x%x%x%x%x%x%x$") then return true end
  if a > 2 and (r:sub(a - 2, a - 1) == "|r" or r:sub(a - 2, a - 1) == "|t") then return true end
  return false
end

local function listaTrozos()
  if trozos then return trozos end
  trozos = {}
  for es, en in pairs(WowFDatosEN or {}) do
    if type(es) == "string" and #es >= 2 and type(en) == "string" then table.insert(trozos, { es, en }) end
  end
  table.sort(trozos, function(a, b) if #a[1] ~= #b[1] then return #a[1] > #b[1] end return a[1] < b[1] end)
  return trozos
end

-- Frases con numeros (el diccionario solo tiene textos fijos). Se aplican ANTES de los trozos; %1, %2... = los numeros.
local PATRONES = {
  { "Se abre al nivel (%d+)%. Lo ideal: ir al (%d+)%.", "Opens at level %1. Ideally go at level %2." },
  { "solo te dura 1 nivel: al (%d+) ya hay algo mejor", "only lasts you 1 level: at level %1 something better exists" },
  { "solo te dura (%d+) niveles: al (%d+) ya hay algo mejor", "only lasts you %1 levels: at level %2 something better exists" },
  { "ya puedes subirlas hasta (%d+)", "you can now level them up to %1" },
  { "Te pueden caer (%d+) piezas para ti", "%1 pieces for you can drop" },
  { "y (%d+) mas para niveles altos", "and %1 more for higher levels" },
  { "%(te faltan (%d+)%)", "(%1 to go)" },
  { "(%d+) misiones dentro", "%1 quests inside" },
  { "AHORA %(nivel (%d+)%)", "NOW (level %1)" },
  { "PROXIMO %(nivel (%d+)%)", "NEXT (level %1)" },
  { "%(de (%d+) a (%d+)", "(from %1 to %2" },
  { "De (%d+) a (%d+)", "From %1 to %2" },
  { "(%d+) de (%d+)", "%1 of %2" },
  { "Nivel (%d+)", "Level %1" },
  { "Nv (%d+)", "Lv %1" },
  { " %-> ([^\n]-) al (%d+)", " -> %1 at level %2" },
  { "¡", "" },
  { "¿", "" },
}
-- Conjunciones sueltas ("Tailoring o Mining", "Mind Flay y Mind Blast"): DESPUES de los trozos, para no partir frases del
-- diccionario. Solo entre palabras (no toca las bolitas de talento ". o .").
local CONJUNCIONES = {
  { "([%a%)\002]) o ([%a%(\001])", " or " },
  { "%(o ([%a\001])", "(or " },
  { "([%a\002]) y ([%a\001])", " and " },
}

local function marcar(hechos, en)
  table.insert(hechos, en)
  return "\001" .. #hechos .. "\002"
end

-- Cambia cada trozo conocido por su version en ingles (los mas largos primero). Lo ya cambiado se marca para que un
-- trozo mas corto no lo vuelva a tocar.
local function porTrozos(s)
  local hechos, r = {}, s
  for _, pt in ipairs(PATRONES) do
    r = r:gsub(pt[1], function(...)
      local caps = { ... }
      return marcar(hechos, (pt[2]:gsub("%%(%d)", function(i) return caps[tonumber(i)] or "" end)))
    end)
  end
  for _, p in ipairs(listaTrozos()) do
    local es = p[1]
    local ini = 1
    while true do
      local a, z = r:find(es, ini, true)
      if not a then break end
      local libre = true
      -- Si el trozo empieza o termina en letra, tiene que ser palabra completa
      if esLetra(es:byte(1)) and esLetra(r:byte(a - 1)) and not trasCodigo(r, a) then libre = false end
      if esLetra(es:byte(-1)) and esLetra(r:byte(z + 1)) then libre = false end
      if libre then
        local marca = marcar(hechos, p[2])
        r = r:sub(1, a - 1) .. marca .. r:sub(z + 1)
        ini = a + #marca
      else
        ini = a + 1
      end
    end
  end
  r = r:gsub(CONJUNCIONES[1][1], function(a, b) return a .. marcar(hechos, CONJUNCIONES[1][2]) .. b end)
  r = r:gsub(CONJUNCIONES[2][1], function(b) return marcar(hechos, CONJUNCIONES[2][2]) .. b end)
  r = r:gsub(CONJUNCIONES[3][1], function(a, b) return a .. marcar(hechos, CONJUNCIONES[3][2]) .. b end)
  if #hechos == 0 then return s end
  return (r:gsub("\001(%d+)\002", function(i) return hechos[tonumber(i)] end))
end

-- Textos fijos (botones, titulos) que se ponen una vez al cargar: se registran para reescribirlos si cambia el idioma
WowF.fijos = WowF.fijos or {}
function WowF.textoFijo(obj, es)
  if not obj then return end
  obj:SetText(WowF.T(es))
  table.insert(WowF.fijos, { obj, es })
end
function WowF.reidiomar()
  cache, ncache = {}, 0
  for _, f in ipairs(WowF.fijos) do pcall(f[1].SetText, f[1], WowF.T(f[2])) end
  if WowF.botonIdiomaActualizar then pcall(WowF.botonIdiomaActualizar) end
  if WowF.bienvenidaRedibujar then pcall(WowF.bienvenidaRedibujar) end
  -- 12-oct: ventanas ya abiertas (Ajustes, aviso de cosas nuevas, mapa sacado...) se reescriben en el idioma nuevo
  for _, fn in ipairs(WowF.alReidiomar or {}) do pcall(fn) end
  if WowF.panelActualizar then WowF.panelActualizar() end
  if WowF.libro and WowF.libro:IsShown() and WowF.abrirLibro then pcall(WowF.abrirLibro) end
end

function WowF.T(s)
  if type(s) ~= "string" or s == "" or not WowF.enIngles() or not WowFDatosEN or listos[s] then return s end
  local c = cache[s]
  if c then return c end
  local r = WowFDatosEN[s]
  if not r then
    -- "Forever Guide: <frase>" en el chat: la frase entera va antes que los trozos (si no, gana un trozo largo con el prefijo)
    local pre, resto = s:match("^(|c%x%x%x%x%x%x%x%xForever Guide|r: )(.+)$")
    if resto and WowFDatosEN[resto] then r = pre .. WowFDatosEN[resto] else r = porTrozos(s) end
  end
  if ncache > 6000 then cache, ncache = {}, 0 end
  cache[s] = r; ncache = ncache + 1
  return r
end

-- Comandos en ingles: se traducen a la orden en espanol antes de pasarla a los demas archivos
local ALIAS = { farm = "farmeo", dungeons = "mazmorras", dungeon = "mazmorras", route = "ruta", clear = "borrar",
  stop = "parar", goal = "objetivo", spec = "rama", trainers = "entrenadores", trainer = "entrenadores", export = "exportar" }
local ALIAS_PLAN = { progress = "progreso", talents = "talentos", professions = "profesiones", gear = "equipo",
  dungeons = "mazmorras", rotation = "rotacion" }
local ALIAS_OBJETIVO = { craft = "fabricar", gold = "oro" }
function WowF.ordenEnEspanol(orden, resto)
  orden = ALIAS[orden] or orden
  local r = (resto or ""):lower()
  if orden == "plan" and ALIAS_PLAN[r] then resto = ALIAS_PLAN[r] end
  if orden == "objetivo" and ALIAS_OBJETIVO[r] then resto = ALIAS_OBJETIVO[r] end
  return orden, resto
end

-- /wowf idioma: se engancha cuando ya cargo todo el addon (los demas archivos definen /wowf despues de este)
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  -- Los botones se crean al cargar el archivo, ANTES de que el juego lea WowFExportarDB (el idioma elegido): reescribirlos ya
  pcall(WowF.reidiomar)
  local anterior = SlashCmdList and SlashCmdList["WOWF"]
  if not SlashCmdList then return end
  SlashCmdList["WOWF"] = function(mensaje)
    local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
    orden = (orden or ""):lower()
    if orden == "idioma" or orden == "language" or orden == "lang" then
      resto = (resto or ""):lower()
      WowFExportarDB = WowFExportarDB or {}
      if resto == "en" or resto == "english" or resto == "ingles" then WowFExportarDB.idioma = "en"
      elseif resto == "es" or resto == "espanol" or resto == "spanish" then WowFExportarDB.idioma = "es"
      else WowFExportarDB.idioma = nil end
      WowF.reidiomar()
      if WowF.enIngles() then
        print("|cff33ccffForever Guide|r: language = English" .. ". /wowf language es = Spanish.")
      else
        print("|cff33ccffForever Guide|r: idioma = espanol" .. ". /wowf idioma en = ingles.")
      end
      return
    end
    local orden2, resto2 = WowF.ordenEnEspanol(orden, resto)
    if orden2 ~= orden or resto2 ~= resto then mensaje = orden2 .. ((resto2 or "") ~= "" and (" " .. resto2) or "") end
    if anterior then anterior(mensaje) end
  end
end)
