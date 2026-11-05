-- wowF Lineas de misiones (5-oct, Andy: "Allegiance to the Old Gods es una linea de misiones: que diga que lo es, donde empieza
-- y que te lleve paso a paso hasta el NPC"). Datos: c de cada mision en wowF_Mazmorras.lua (bloque "Series" de Wowhead /forever,
-- herramientas/descargar-cadenas.mjs): los pasos ANTES de la mision de mazmorra, con quien da cada uno (o el objeto que lo empieza,
-- quien lo suelta y con que %), a quien se entrega y donde; c.tras = los pasos DESPUES. Sin c = "mision de recoger".
-- 5-oct (Andy: "en Equipo, si la pieza sale de una linea de misiones, que diga que es una linea y como empezarla"): tambien
-- las misiones que dan equipo (WowFDatos.misionesEquipo, campo 14 = la linea). Esas no llevan q.mazmorra sino q.equipo (la pieza).
-- 5-oct (Andy: "parte 6 de 6 es demasiado confuso"; "todo el panorama de la linea, desde el primer NPC, marcado en el mapa con
-- una ruta"; "una ventana aparte con la linea que estas haciendo, una a la vez, que se vaya marcando hasta la mision final";
-- "si cambia de NPC, que diga exactamente que cambia, que quest es y como"):
--   * numeracion de la linea ENTERA: "mision 3 de 6" (antes, la importante y las de despues);
--   * ventana propia (wowFLinea, una sola linea a la vez): cada mision con quien la da, donde, a quien se entrega, aviso cuando
--     cambia de NPC, la importante resaltada, "AHORA" en verde y "QUE HACER AHORA" con la orden completa; se actualiza sola;
--   * mapa: un circulo por sitio con los numeros de las misiones de ese sitio ("1-4"), unidos por una raya en el orden en que
--     se hacen (verde = lo de ahora, naranja = lo que falta, morado = la importante, azul = despues, gris = hecho).
-- 5-oct (Andy, PROTOCOLO: "segun donde estes, la ruta hasta la primera quest que enciende la linea, explicado todo, para
-- cualquier clase, raza y faccion"; su Shaman Tauren veia la linea del Honorbound Cloak, que empieza en Zephras Isle):
--   * lineas imposibles para tu raza (zonas de una sola raza, ZONA_SOLO) = no se recomiendan y, si se piden, se explica por que;
--   * bloque "COMO LLEGAR" en la ventana y en el chat: desde la zona donde estas hasta el NPC que toca (ruta paso a paso,
--     "ya estas en la zona", "estas dentro de una mazmorra", "no hay camino conocido"...); la ruta se arma sola al cambiar de zona;
--   * mapa: el circulo lleva el numero de la mision que RECOGES alli ("E3" = alli solo se entrega la 3).
-- 5-oct (Andy: "minimizarla", "cuando hagas una quest que la tache y diga la proxima es esta", "un icono encima del NPC"):
--   * boton "-" / "+" en la ventana: modo pequeno (solo AHORA y la siguiente), se guarda en WowFExportarDB.lineaMini;
--   * cada mision cumplida sale con la marca verde y "CUMPLIDA: X. La proxima es: Y"; "ya esta completa: entregala" al acabar los objetivos;
--   * sobre el NPC que toca: estrella (marca de banda, solo si vas sin grupo) al pasarle el raton o seleccionarlo, e icono con
--     "LINEA k/T" en su placa de nombre (las placas de NPC amistosos se encienden al seguir una linea y vuelven como estaban al quitarla).

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local AZUL = "|cff33ccffForever Guide|r: "
local ORO, VERDE, GRIS, BLANCO, NARANJA, MORADO, CELESTE = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933", "|cffc77dff", "|cff66ccff"
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function seguro(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end
-- La mision del diario ya tiene los objetivos hechos (lista para entregar)
local function completa(id)
  local ok, r = false, nil
  if C_QuestLog and type(C_QuestLog.IsComplete) == "function" then ok, r = pcall(C_QuestLog.IsComplete, id)
  elseif type(IsQuestComplete) == "function" then ok, r = pcall(IsQuestComplete, id) end
  r = ok and seguro(r)
  return r == true or r == 1
end
local function nivelActual()
  local ok, n = pcall(UnitLevel, "player")
  n = ok and seguro(n)
  return tonumber(n) or 1
end
-- Lo que acaba de pasar en esta sesion (el juego tarda un instante en marcarlo): entregadas y aceptadas
local entregadas, aceptadas = {}, {}
local function hecha(id)
  if entregadas[id] then return true end
  local ok, r = false, nil
  if C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompleted) == "function" then ok, r = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
  elseif type(IsQuestFlaggedCompleted) == "function" then ok, r = pcall(IsQuestFlaggedCompleted, id) end
  return ok and seguro(r) == true
end
local function enElDiario(id)
  if aceptadas[id] then return true end
  local ok, r
  if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then ok, r = pcall(C_QuestLog.GetLogIndexForQuestID, id)
  elseif type(GetQuestLogIndexByID) == "function" then ok, r = pcall(GetQuestLogIndexByID, id) end
  r = ok and seguro(r)
  return type(r) == "number" and r > 0
end
local function zonaDe(mapa)
  if WowF.nombreZona and mapa and mapa > 0 then local ok, n = pcall(WowF.nombreZona, mapa); if ok and type(n) == "string" and not tonumber(n) then return n end end
  local info = mapa and mapa > 0 and C_Map and C_Map.GetMapInfo and select(2, pcall(C_Map.GetMapInfo, mapa))
  return (type(info) == "table" and info.name) or ""
end
local function pct(p)
  if not p or p <= 0 then return "" end
  local s = string.format("%.1f", p):gsub("%.0$", "")
  if not (WowF.enIngles and WowF.enIngles()) then s = s:gsub("%.", ",") end
  return s .. " %"
end
local function donde(m, dentro, mazmorra)
  if dentro then return L(" (DENTRO de " .. (mazmorra or "la mazmorra") .. ")", " (INSIDE " .. (mazmorra or "the dungeon") .. ")") end
  local z = zonaDe(m)
  if z ~= "" then return L(" en ", " in ") .. z end
  return ""
end

-- Aviso cuando falta un dato (Andy 5-oct: disclaimer claro; se completa en proximas actualizaciones)
local function aviso() return NARANJA .. L("Dato aun no confirmado en Wowhead /forever (el juego esta en beta). Se completara en proximas actualizaciones.",
  "Not confirmed yet on Wowhead /forever (the game is in beta). It will be filled in future updates.") .. "|r" end
-- Un paso sin datos: no se sabe quien lo da, o no hay sitio en el mapa (y no es dentro de una mazmorra)
local function sinDatos(p)
  if p.falta then return true end
  if not p.q and not p.o then return true end
  if p.s then return not p.sd and not (p.sm and p.sm > 0) end
  if p.o and not p.q then return true end
  return not p.d and not (p.m and p.m > 0)
end
WowF.lineaPasoSinDatos = sinDatos

-- Zonas a las que solo puede ir una raza. Zephras Isle (uiMapID 2521) es la zona de inicio de los Skyborne (niveles 1-12, Wowhead
-- /forever; razas 95 High Order Skyborne y 96 Windshaper Skyborne, datos/razas.js): no se une al resto del mundo a pie, en barco
-- ni en zepelin, y las otras razas no pueden ir.
local ZONA_SOLO = { [2521] = { razas = { [95] = true, [96] = true }, nombre = "Zephras Isle", raza = "Skyborne" } }
local function miRaza()
  local ok, _, _, id = pcall(UnitRace, "player")
  id = ok and seguro(id)
  return tonumber(id)
end
-- La zona m es de otra raza (y no de la tuya): devuelve la zona; si no se sabe tu raza, tampoco se puede
local function zonaVedada(m)
  local z = m and ZONA_SOLO[m]
  if not z then return nil end
  local r = miRaza()
  if r and z.razas[r] then return nil end
  return z
end
WowF.zonaVedada = zonaVedada
local function textoVedada(z)
  return NARANJA .. L("Esta linea pasa por " .. z.nombre .. ", la zona donde empiezan los " .. z.raza .. ": solo un personaje " .. z.raza .. " puede ir alli. Tu personaje no puede hacerla (por eso la guia no te la propone).",
    "This questline goes through " .. z.nombre .. ", the " .. z.raza .. " starting zone: only a " .. z.raza .. " character can go there. Your character cannot do it (that is why the guide does not suggest it).") .. "|r"
end
WowF.lineaTextoVedada = textoVedada
-- La linea (pasos de antes que faltan y la importante) pasa por una zona de otra raza: devuelve esa zona, o nil
function WowF.lineaImposible(c, claveM)
  if type(c) ~= "table" then return zonaVedada(claveM) end
  for _, p in ipairs(c) do
    if not hecha(p.i) then
      for _, m in pairs({ p.m or 0, p.sm or 0, p.em or 0 }) do local z = zonaVedada(m); if z then return z end end
    end
  end
  return zonaVedada(claveM)
end
-- Para que es la linea: la mazmorra, o la pieza de equipo que da la mision
local function mazDe(q) return q.mazmorra and q.mazmorra.n or nil end
local function para(q)
  if q.mazmorra then return q.mazmorra.n end
  return L("te da ", "gives ") .. (q.equipo or L("la pieza", "the item"))
end
-- La mision de equipo como linea (Libro > Equipo): nil si no hay datos de esa mision
function WowF.lineaDeEquipo(qid, pieza)
  local d = WowFDatos and WowFDatos.misionesEquipo and WowFDatos.misionesEquipo[qid]
  if not d then return nil end
  return { id = qid, n = d[1], quien = d[7], m = d[8], x = d[9], y = d[10], dentro = false, cadena = d[14], equipo = pieza, objeto = d[13] == 1 }
end

local rutaAlPasoRef, comoLlegarDe, actualizarVentanaRef, placasLinea -- se llenan mas abajo (las usan funciones de antes)
-- ----- Estado de la linea -----
-- nil = mision de recoger. Si es linea: { c = pasos de antes, i = paso que toca (nil = ya hiciste los de antes), estado = "coger" | "entregar" }
local function estadoLinea(q)
  local c = type(q) == "table" and q.cadena
  if type(c) ~= "table" or #c == 0 then return nil end
  for i, p in ipairs(c) do
    if not hecha(p.i) then return { c = c, i = i, estado = enElDiario(p.i) and "entregar" or "coger" } end
  end
  return { c = c }
end
WowF.estadoLinea = estadoLinea

-- Toda la linea en orden: las de antes, la importante (la de la mazmorra o la que da la pieza) y las de despues (c.tras)
local function todas(q)
  local c, r = q.cadena, {}
  for _, p in ipairs(c) do table.insert(r, { p = p, tipo = "antes" }) end
  table.insert(r, { p = { i = q.id, n = q.n, q = q.quien, m = q.m or 0, x = q.x or 0, y = q.y or 0, d = q.dentro }, tipo = "clave" })
  for _, p in ipairs(c.tras or {}) do table.insert(r, { p = p, tipo = "despues" }) end
  return r
end
-- hecho | actual | luego (falta, antes de la importante) | despues (tras la importante)
local function estadoDe(k, tipo, st)
  if tipo == "despues" then return "despues" end
  if tipo == "clave" then return st.i and "luego" or "actual" end
  if not st.i or k < st.i then return "hecho" end
  if k == st.i then return "actual" end
  return "luego"
end
-- La mision que toca ahora: numero, entrada de todas() y "coger" | "entregar"
local function ahora(q, st, lista)
  if st.i then return st.i, lista[st.i], st.estado end
  return #q.cadena + 1, lista[#q.cadena + 1], "coger"
end

local function nombreDe(p) return (p.n and p.n ~= "") and p.n or ("#" .. p.i) end
local function nombrePaso(p) return BLANCO .. nombreDe(p) .. "|r" end
-- Como empieza un paso: quien lo da, o el objeto que lo empieza y quien lo suelta
local function comoEmpieza(p, mazmorra)
  if p.s then
    return L("la empieza " .. ORO .. (p.o or "un objeto") .. "|r, que suelta " .. BLANCO .. p.s .. "|r" .. donde(p.sm, p.sd, mazmorra) .. (p.sp and p.sp > 0 and (GRIS .. " (" .. pct(p.sp) .. ")|r") or ""),
      "starts from " .. ORO .. (p.o or "an item") .. "|r, dropped by " .. BLANCO .. p.s .. "|r" .. donde(p.sm, p.sd, mazmorra) .. (p.sp and p.sp > 0 and (GRIS .. " (" .. pct(p.sp) .. ")|r") or ""))
  elseif p.o then
    return L("la empieza el objeto " .. ORO .. p.o .. "|r", "starts from the item " .. ORO .. p.o .. "|r")
  elseif p.q and p.t == "object" then
    return L("la empieza " .. ORO .. p.q .. "|r" .. GRIS .. " (un objeto)|r" .. donde(p.m, p.d, mazmorra), "starts at " .. ORO .. p.q .. "|r" .. GRIS .. " (an object)|r" .. donde(p.m, p.d, mazmorra))
  elseif p.q then
    return L("te la da " .. ORO .. p.q .. "|r" .. donde(p.m, p.d, mazmorra), "given by " .. ORO .. p.q .. "|r" .. donde(p.m, p.d, mazmorra))
  end
  return NARANJA .. L("aun no se sabe quien la da", "who gives it is not known yet") .. "|r"
end
local function aQuien(p, mazmorra)
  if not p.e then return "" end
  if p.q and p.e == p.q and p.em == p.m then return L("; se entrega al mismo " .. ORO .. p.e .. "|r", "; turn it in to the same " .. ORO .. p.e .. "|r") end
  return L("; se entrega a " .. ORO .. p.e .. "|r" .. donde(p.em, p.ed, mazmorra), "; turn in to " .. ORO .. p.e .. "|r" .. donde(p.em, p.ed, mazmorra))
end

-- La orden completa de una mision: que hacer para cogerla (o entregarla) y a quien llevarla
local function queHacer(p, sub, mazmorra)
  local nombre = nombrePaso(p)
  if sub == "entregar" then
    if completa(p.i) then
      if p.e then return VERDE .. L("Ya esta completa: entregala a ", "It is complete: turn it in to ") .. "|r" .. ORO .. p.e .. "|r" .. donde(p.em, p.ed, mazmorra) .. "." end
      return VERDE .. L("Ya esta completa: entregala.", "It is complete: turn it in.") .. "|r"
    end
    if p.e then return L("Ya la tienes: haz lo que pide (mira tu diario, L) y entregala a ", "You have it: do what it asks (see your quest log, L) and turn it in to ") .. ORO .. p.e .. "|r" .. donde(p.em, p.ed, mazmorra) .. "." end
    return L("Ya la tienes: haz lo que pide (mira tu diario, L) y entregala.", "You have it: do what it asks (see your quest log, L) and turn it in.")
  end
  local t
  if p.s then
    t = L("Mata a ", "Kill ") .. BLANCO .. p.s .. "|r" .. donde(p.sm, p.sd, mazmorra) .. L(" hasta que suelte ", " until it drops ") .. ORO .. (p.o or "?") .. "|r"
      .. (p.sp and p.sp > 0 and (GRIS .. " (" .. pct(p.sp) .. ")|r") or "") .. L("; clic derecho en el objeto para empezar ", "; right-click the item to start ") .. nombre
  elseif p.o then
    t = L("Usa el objeto ", "Use the item ") .. ORO .. p.o .. "|r" .. L(" para empezar ", " to start ") .. nombre
  elseif p.q and p.t == "object" then
    t = L("Busca ", "Find ") .. ORO .. p.q .. "|r" .. GRIS .. L(" (un objeto)", " (an object)") .. "|r" .. donde(p.m, p.d, mazmorra) .. L(" y haz clic para empezar ", " and click it to start ") .. nombre
  elseif p.q then
    t = L("Habla con ", "Talk to ") .. ORO .. p.q .. "|r" .. donde(p.m, p.d, mazmorra) .. L(" y acepta ", " and accept ") .. nombre
  else
    return NARANJA .. L("Aun no se sabe quien da ", "It is not known yet who gives ") .. "|r" .. nombre .. "."
  end
  if p.e then
    if p.q and p.e == p.q and p.em == p.m then t = t .. L(". Haz lo que pide (mira tu diario, L) y entregala al mismo ", ". Do what it asks (see your quest log, L) and turn it in to the same ") .. ORO .. p.e .. "|r"
    else t = t .. L(". Haz lo que pide (mira tu diario, L) y entregala a ", ". Do what it asks (see your quest log, L) and turn it in to ") .. ORO .. p.e .. "|r" .. donde(p.em, p.ed, mazmorra) end
  end
  return t .. "."
end
WowF.lineaQueHacer = queHacer
-- Lo que te dan con la importante
local function premio(q, mazmorra)
  if q.mazmorra then return L("te da la mision de " .. mazmorra, "gives you the " .. mazmorra .. " quest") end
  return L("al entregarla te dan " .. (q.equipo or "la pieza"), "turning it in gives you " .. (q.equipo or "the item"))
end
-- Quien te espera al terminar un paso (a quien se entrega, o quien lo dio) y quien da el siguiente
local function conQuienTermina(p) return p.e or p.q, p.e and p.em or p.m end
local function cambioDeNPC(p, sig, mazmorra)
  if not sig then return nil end
  local antes, mAntes = conQuienTermina(p)
  if sig.s then return NARANJA .. L(">> la siguiente la empieza un objeto: ", ">> the next one starts from an item: ") .. "|r" .. comoEmpieza(sig, mazmorra) end
  if not sig.q then return nil end
  if antes and antes == sig.q and mAntes == sig.m then return GRIS .. L(">> la siguiente te la da el mismo NPC (" .. sig.q .. ")", ">> the next one is from the same NPC (" .. sig.q .. ")") .. "|r" end
  return NARANJA .. L(">> CAMBIA DE NPC: la siguiente ", ">> NPC CHANGES: the next one is ") .. "|r" .. comoEmpieza(sig, mazmorra)
end

-- Una fila por mision para la ventana y el chat (con su detalle y el aviso de cambio de NPC)
local HECHA = "|TInterface\\RaidFrame\\ReadyCheck-Ready:13|t "
local function filas(q, st)
  local lista, maz = todas(q), mazDe(q)
  local total, r, huecos = #lista, {}, false
  local kAhora, _, sub = ahora(q, st, lista)
  local nivel = nivelActual()
  for k, e in ipairs(lista) do
    local p, est = e.p, estadoDe(k, e.tipo, st)
    local nombre = nombreDe(p)
    local cab
    if est == "hecho" then cab = HECHA .. GRIS .. k .. ". " .. nombre .. L("  (cumplida)", "  (done)") .. "|r"
    elseif est == "actual" then cab = VERDE .. L("AHORA > ", "NOW > ") .. k .. ". |r" .. BLANCO .. nombre .. "|r" .. (sub == "entregar" and (VERDE .. L(" (entregarla)", " (turn it in)") .. "|r") or "")
    elseif e.tipo == "clave" then cab = MORADO .. k .. ". " .. nombre .. "|r"
    elseif est == "despues" then cab = GRIS .. k .. ". " .. nombre .. "|r"
    else cab = BLANCO .. k .. ". " .. nombre .. "|r" end
    if e.tipo == "clave" then cab = cab .. MORADO .. L("  << LA IMPORTANTE: ", "  << THE KEY ONE: ") .. premio(q, maz) .. "|r"
    elseif est == "despues" then cab = cab .. GRIS .. (q.mazmorra and L("  (despues; no hace falta para la mazmorra)", "  (after; not needed for the dungeon)") or L("  (despues; no hace falta para la pieza)", "  (after; not needed for the item)")) .. "|r" end
    if (p.l or 0) > nivel and est ~= "hecho" then cab = cab .. NARANJA .. L(" - nivel " .. p.l, " - level " .. p.l) .. "|r" end
    table.insert(r, cab)
    if est ~= "hecho" then
      table.insert(r, "      " .. comoEmpieza(p, maz) .. aQuien(p, maz))
      local sig = lista[k + 1]
      local cambio = sig and est ~= "despues" and cambioDeNPC(p, sig.p, maz)
      if cambio then table.insert(r, "      " .. cambio) end
    end
    if sinDatos(p) then huecos = true end
  end
  return r, huecos, total, kAhora, sub
end

-- Resumen de una linea: "son N misiones seguidas; la K es la importante"
local function resumen(q, st)
  local total, kc = #q.cadena + 1 + #(q.cadena.tras or {}), #q.cadena + 1
  local hechas = st.i and (st.i - 1) or #q.cadena
  return L("Son " .. total .. " misiones seguidas: cada una abre la siguiente. La " .. kc .. " (" .. q.n .. ") es la importante: " .. premio(q, mazDe(q)) .. "."
      .. (hechas > 0 and (" Ya hiciste " .. hechas .. ".") or ""),
    total .. " quests in a row: each one unlocks the next. Number " .. kc .. " (" .. q.n .. ") is the key one: it " .. premio(q, mazDe(q)) .. "."
      .. (hechas > 0 and (" You did " .. hechas .. " already.") or ""))
end

-- Lineas para el tooltip de la mision (mapa, Libro, panel): { texto, r, g, b }
local function lineasTooltip(q)
  local st = estadoLinea(q)
  if not st then
    if q and q.cadena == false then return { { GRIS .. L("Mision de recoger: se coge directamente.", "Pick-up quest: you can take it directly.") .. "|r", 1, 1, 1 } } end
    return {}
  end
  local c, maz = st.c, mazDe(q)
  local lista = todas(q)
  local total = #lista
  local t = {}
  table.insert(t, { NARANJA .. L("LINEA DE MISIONES: ", "QUESTLINE: ") .. "|r" .. BLANCO .. L(total .. " misiones seguidas (cada una abre la siguiente)", total .. " quests in a row (each one unlocks the next)") .. "|r", 1, 1, 1 })
  if st.i then
    table.insert(t, { L("Esta no se coge directamente: es la " .. (#c + 1) .. " de " .. total .. ". Antes hay que hacer " .. #c .. (#c == 1 and " mision." or " misiones."),
      "You cannot take it directly: it is number " .. (#c + 1) .. " of " .. total .. ". First you must do " .. #c .. (#c == 1 and " quest." or " quests.")), 1, 1, 1 })
    table.insert(t, { L("Empieza con 1. ", "It starts with 1. ") .. nombrePaso(c[1]) .. ": " .. comoEmpieza(c[1], maz), 1, 1, 1 })
    local cl = comoLlegarDe and comoLlegarDe(q, st)
    if cl and cl.corto then table.insert(t, { CELESTE .. L("Desde donde estas: ", "From where you are: ") .. "|r" .. cl.corto, 1, 1, 1 }) end
    if st.i > 1 then table.insert(t, { GRIS .. L("Ya hiciste " .. (st.i - 1) .. " de " .. #c, "You did " .. (st.i - 1) .. " of " .. #c) .. "|r", 1, 1, 1 }) end
    table.insert(t, { VERDE .. L("Ahora (mision " .. st.i .. " de " .. total .. "): ", "Now (quest " .. st.i .. " of " .. total .. "): ") .. "|r" .. queHacer(c[st.i], st.estado, maz), 1, 1, 1 })
    table.insert(t, { MORADO .. L("Al final, la " .. (#c + 1) .. ": ", "In the end, number " .. (#c + 1) .. ": ") .. "|r" .. ORO .. (q.quien or "?") .. "|r" .. L(" te da " .. q.n .. "; ", " gives you " .. q.n .. "; ") .. premio(q, maz) .. ".", 1, 1, 1 })
    for _, p in ipairs(c) do if sinDatos(p) then table.insert(t, { aviso(), 1, 1, 1 }); break end end
    table.insert(t, { VERDE .. L("Clic: te guio paso a paso (ventana con la linea, ruta y numeros en el mapa)", "Click: step-by-step guide (questline window, route and numbers on the map)") .. "|r", 1, 1, 1 })
  else
    table.insert(t, { VERDE .. L("Ya hiciste las de antes: ya te la dan.", "You already did the earlier ones: you can take it now.") .. "|r", 1, 1, 1 })
  end
  return t
end
WowF.lineaMisionTooltip = lineasTooltip
-- Una linea corta (tooltip del NPC, listas): "" si no hace falta nada antes
function WowF.lineaMisionCorta(q)
  local st = estadoLinea(q)
  if not st or not st.i then return "" end
  local n = #st.c - st.i + 1
  return WowF.yaTraducido(NARANJA .. L("línea de misiones: antes haz " .. n .. (n == 1 and " misión" or " misiones seguidas"), "questline: first do " .. n .. (n == 1 and " quest" or " quests in a row")) .. "|r")
end
-- Para la fila de Equipo: "LINEA DE MISIONES: antes haz N misiones seguidas" ("" si ya no hace falta)
function WowF.lineaResumen(q)
  local st = q and estadoLinea(q)
  if not st or not st.i then return "" end
  local n = #st.c - st.i + 1
  local p = st.c[st.i]
  local quien = st.estado == "entregar" and p.e or (p.s or p.q)
  local zona = zonaDe(st.estado == "entregar" and p.em or (p.s and p.sm or p.m))
  local inicio = ""
  if quien then
    inicio = GRIS .. (st.i == 1 and L(" (empieza: ", " (starts: ") or L(" (sigue: ", " (next: ")) .. quien .. (zona ~= "" and (", " .. zona) or "") .. ")|r"
  end
  return NARANJA .. L("LINEA DE MISIONES: antes haz " .. n .. (n == 1 and " mision" or " misiones seguidas"), "QUESTLINE: first do " .. n .. (n == 1 and " quest" or " quests in a row")) .. "|r" .. inicio
end

-- ----- La linea en curso: ventana, chat, mapa y ruta -----
local linea -- { q = mision importante, g = grupo del NPC (para la ruta final), fin = ya hiciste las de antes }
local function buscar(id)
  if WowFExportarDB.lineaEquipo then return WowF.lineaDeEquipo(id, WowFExportarDB.lineaEquipo ~= "" and WowFExportarDB.lineaEquipo or nil) end
  for _, m in ipairs(WowFMazmorras or {}) do
    if WowF.misionesDe then for _, q in ipairs((WowF.misionesDe(m))) do if q.id == id then return q end end end
  end
end
local function estadoActual()
  if not linea then return nil end
  return estadoLinea(linea.q) or { c = linea.q.cadena }
end

-- Adonde tienes que ir AHORA en la linea q: quien (n), sitio (m, x, y), si es dentro de una mazmorra y que haces alli
local function destinoDe(q, st)
  st = st or estadoLinea(q) or { c = q.cadena }
  local k, e, sub = ahora(q, st, todas(q))
  local p = e and e.p
  if not p then return nil end
  local d = { k = k, sub = sub, p = p, clave = e.tipo == "clave" }
  if sub == "entregar" then d.n, d.m, d.x, d.y, d.dentro, d.que = p.e, p.em, p.ex, p.ey, p.ed, "entregar"
  elseif p.s then d.n, d.m, d.x, d.y, d.dentro, d.que = p.s, p.sm, p.sx, p.sy, p.sd, "matar"
  else d.n, d.m, d.x, d.y, d.dentro, d.que = p.q, p.m, p.x, p.y, p.d, (e.tipo == "clave") and "mision" or "coger" end
  return d
end
-- Los mapas donde esta el jugador (el suyo y los de arriba: subzona, zona, continente)
local function mapasJugador()
  local r = {}
  if not (C_Map and C_Map.GetBestMapForUnit) then return r end
  local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
  m = ok and seguro(m) or nil
  local v = 0
  while m and v < 6 do
    table.insert(r, m)
    local ok2, info = pcall(C_Map.GetMapInfo, m)
    m = ok2 and type(info) == "table" and info.parentMapID or nil
    v = v + 1
  end
  return r
end
-- La ruta de wowF_Viaje que esta puesta va a este destino
local function rutaActivaA(d)
  if not WowF.viajePasos then return nil end
  local pasos, i, n = WowF.viajePasos()
  if pasos and d and n == d.n then return pasos, i end
  return nil
end
local function coords(x, y) return string.format("%.0f, %.0f", x or 0, y or 0) end
-- COMO LLEGAR desde donde estas hasta lo que toca en la linea: { tipo, texto (largo), corto (tooltip) }
-- tipo: ruta | aqui | dentro | sinDatos | vedada | isla | sinZona | sinCamino
local function comoLlegar(q, st)
  local d = destinoDe(q, st)
  if not d then return nil end
  local quien = (d.que == "matar" and BLANCO or ORO) .. (d.n or "?") .. "|r"
  local zona = zonaDe(d.m)
  if d.dentro then
    local maz = mazDe(q) or L("la mazmorra", "the dungeon")
    return { tipo = "dentro", texto = L(quien .. " esta DENTRO de " .. maz .. ": entra en la mazmorra; esta alli dentro.", quien .. " is INSIDE " .. maz .. ": go into the dungeon; it is in there."),
      corto = L("esta DENTRO de " .. maz, "it is INSIDE " .. maz) }
  end
  if not d.n or not (d.m and d.m > 0) then
    return { tipo = "sinDatos", texto = L("Aun no se sabe donde esta. ", "Where it is is not known yet. ") .. aviso(), corto = L("sitio aun sin confirmar", "place not confirmed yet") }
  end
  local z = zonaVedada(d.m)
  if z then return { tipo = "vedada", texto = textoVedada(z), corto = textoVedada(z) } end
  local donde = quien .. GRIS .. " (" .. zona .. ", " .. coords(d.x, d.y) .. ")|r"
  local mios = mapasJugador()
  local aqui = WowF.zonaActual and WowF.zonaActual() or nil
  local enZona = aqui == d.m
  for _, m in ipairs(mios) do if m == d.m then enZona = true end end
  if enZona then
    return { tipo = "aqui", texto = L("Ya estas en " .. zona .. ": ", "You are already in " .. zona .. ": ") .. donde .. L(". Sigue el alfiler del mapa (o la flecha).", ". Follow the map pin (or the arrow)."),
      corto = L("esta en tu zona (" .. zona .. ")", "it is in your zone (" .. zona .. ")") }
  end
  if not aqui then
    for _, m in ipairs(mios) do
      local zs = ZONA_SOLO[m]
      if zs then
        return { tipo = "isla", texto = L("Estas en " .. zs.nombre .. ": desde aqui no hay camino a pie, en barco ni en zepelin hasta " .. zona .. ". Wowhead /forever no dice como se sale: lee el texto de la mision o preguntale a quien te la dio. Cuando llegues a " .. zona .. ", la ruta hasta ",
            "You are in " .. zs.nombre .. ": there is no way on foot, by boat or by zeppelin from here to " .. zona .. ". Wowhead /forever does not say how to leave: read the quest text or ask who gave it to you. When you reach " .. zona .. ", the route to ")
            .. donde .. L(" se arma sola.", " is built by itself."),
          corto = L("desde " .. zs.nombre .. " no hay camino conocido", "no known way from " .. zs.nombre) }
      end
    end
    return { tipo = "sinZona", texto = L("No se en que zona estas (dentro de una mazmorra, una cueva o una zona nueva). Sal al mundo abierto: al cambiar de zona, la ruta hasta ",
        "I cannot tell which zone you are in (inside a dungeon, a cave or a new zone). Go out to the open world: when you change zone, the route to ") .. donde .. L(" se arma sola.", " is built by itself."),
      corto = L("sal al mundo abierto y se arma la ruta", "go to the open world and the route is built") }
  end
  local nombreAqui = zonaDe(aqui)
  if not (WowF.costoViaje and WowF.costoViaje(aqui, d.m)) then
    return { tipo = "sinCamino", texto = L("No hay camino conocido a pie, en barco ni en zepelin desde " .. nombreAqui .. " hasta " .. zona .. ". Te deje el alfiler en ",
        "There is no known way on foot, by boat or by zeppelin from " .. nombreAqui .. " to " .. zona .. ". The map pin is on ") .. donde .. ". " .. aviso(),
      corto = L("no hay camino conocido desde " .. nombreAqui, "no known way from " .. nombreAqui) }
  end
  local t = L("Estas en " .. nombreAqui .. ". Para llegar a ", "You are in " .. nombreAqui .. ". To reach ") .. donde .. ":"
  local pasos, i = rutaActivaA(d)
  if pasos then
    for j, p in ipairs(pasos) do
      t = t .. "\n   " .. (j == i and (VERDE .. "> " .. j .. ". |r" .. p.texto) or (j < i and (GRIS .. j .. ". " .. p.texto:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r") or (j .. ". " .. p.texto)))
    end
    t = t .. "\n" .. GRIS .. L("Sigue el recuadro de la RUTA y el alfiler del mapa: pasa solo al siguiente paso al llegar. Si ya tienes la ruta de vuelo, vuela.",
      "Follow the ROUTE box and the map pin: it moves to the next step by itself. If you already have the flight path, fly.") .. "|r"
  else
    t = t .. " " .. GRIS .. L("hay camino; escribe /wowf linea y te pongo la ruta paso a paso.", "there is a way; type /wowf questline and I will set the route step by step.") .. "|r"
  end
  return { tipo = "ruta", texto = t, corto = L("desde " .. nombreAqui .. " hay ruta (clic: te llevo)", "there is a route from " .. nombreAqui .. " (click: take me)") }
end
WowF.lineaComoLlegar = comoLlegar
comoLlegarDe = comoLlegar

-- Puntos del mapa (12-oct, queja de un amigo de Andy: "en un sitio dice 1, 2 y en el otro 2, 3, 4, o 1, 4, 3... hay reguero").
-- Antes: un circulo por SITIO con los numeros de las misiones que se recogen alli; si la linea iba y volvia al mismo NPC, el circulo
-- llevaba "1,3,8,9,15" (126 de 264 lineas con numeros saltados; trabajo-lineas/COMPARACION.md). Ahora la linea se parte en PARADAS
-- (acciones seguidas en el mismo sitio: "entrega X y acepta Y" = una parada) y el mapa ensena SOLO dos circulos:
-- 1 = adonde vas AHORA (verde) y 2 = la siguiente parada en OTRO sitio (naranja; morado si alli te dan la importante),
-- unidos por una raya. El resto de la linea esta en la ventana, en orden. Lo de despues de la importante no va al mapa.
local function mismoSitio(a, b)
  return a and b and a.m and a.m > 0 and a.m == b.m and math.abs((a.x or 0) - (b.x or 0)) < 1.2 and math.abs((a.y or 0) - (b.y or 0)) < 1.2
end
-- Acciones de la linea en orden: coger (o matar para el objeto que la empieza) y entregar; termina al aceptar la importante
local function acciones(q)
  local r = {}
  for k, e in ipairs(todas(q)) do
    local p = e.p
    if p.s then table.insert(r, { k = k, e = e, que = "matar", m = p.sm, x = p.sx, y = p.sy, n = p.s })
    else table.insert(r, { k = k, e = e, que = e.tipo == "clave" and "mision" or "coger", m = p.m, x = p.x, y = p.y, n = p.q }) end
    if e.tipo == "clave" then break end
    if p.e then table.insert(r, { k = k, e = e, que = "entregar", m = p.em, x = p.ex, y = p.ey, n = p.e }) end
  end
  return r
end
-- Paradas desde lo que toca ahora. Entre coger una mision y entregarla hay que hacer lo que pide: eso abre parada nueva aunque sea el mismo NPC.
local function paradas(q, st)
  local acc = acciones(q)
  local k, _, sub = ahora(q, st, todas(q))
  local desde = 1
  for j, a in ipairs(acc) do
    if a.k == k and ((sub == "entregar") == (a.que == "entregar")) then desde = j; break end
  end
  local r = {}
  for j = desde, #acc do
    local a, ult = acc[j], r[#r]
    local trabajo = ult and a.que == "entregar" and ult.acc[#ult.acc].k == a.k
    if ult and not trabajo and mismoSitio(ult, a) then table.insert(ult.acc, a)
    else table.insert(r, { m = a.m, x = a.x, y = a.y, n = a.n, acc = { a } }) end
  end
  return r
end
WowF.lineaParadas = function() if not linea then return {} end return paradas(linea.q, estadoActual()) end -- para las pruebas
-- La siguiente parada en OTRO sitio (la vuelta al mismo NPC tras hacer lo que pide ya la dice el circulo 1)
local function siguienteParada(ps)
  for j = 2, #ps do if not mismoSitio(ps[j], ps[1]) then return ps[j], j end end
  return nil
end
local function puntos()
  if not linea then return {}, {} end
  local q = linea.q
  local ps = paradas(q, estadoActual())
  local lista = {}
  local function punto(pa, texto, estado, hasta)
    if not (pa and pa.m and pa.m > 0 and pa.x and pa.x > 0) then return end
    local d = { m = pa.m, x = pa.x, y = pa.y, texto = texto, estado = estado, entradas = {}, final = false, parada = pa }
    -- el circulo 1 junta lo que haces en ese sitio hasta que toca irse a otro (cogerla y, a la vuelta, entregarla)
    for j = 1, hasta do
      for ai, a in ipairs(ps[j].acc) do
        table.insert(d.entradas, { k = a.k, e = a.e, que = a.que, estado = (j == 1 and ai == 1 and estado == "actual") and "actual" or "luego" })
        if a.e.tipo == "clave" then d.final = true end
      end
    end
    if hasta == 0 then
      for _, a in ipairs(pa.acc) do
        table.insert(d.entradas, { k = a.k, e = a.e, que = a.que, estado = "luego" })
        if a.e.tipo == "clave" then d.final = true end
      end
    end
    local en = d.entradas[1]
    if en then d.k, d.p, d.que = en.k, en.e.p, en.que end
    table.insert(lista, d)
  end
  if ps[1] then
    local sig, j = siguienteParada(ps)
    punto(ps[1], "1", "actual", (j or (#ps + 1)) - 1)
    if sig then punto(sig, "2", "luego", 0) end
  end
  local ruta = {}
  for _, d in ipairs(lista) do table.insert(ruta, { d = d, estado = d.estado, clave = d.final }) end
  return lista, ruta
end
WowF.lineaPuntos = puntos -- para las pruebas
-- Texto de una parada para la ventana: "Thrall (Orgrimmar): entrega Hidden Enemies y acepta Hidden Enemies"
local function textoParada(pa)
  if not pa then return nil end
  local partes = {}
  for _, a in ipairs(pa.acc) do
    local nombre = nombreDe(a.e.p)
    if a.que == "entregar" then table.insert(partes, L("entrega ", "turn in ") .. nombre)
    elseif a.que == "matar" then table.insert(partes, L("mata a " .. (a.n or "?") .. " (suelta lo que empieza ", "kill " .. (a.n or "?") .. " (drops what starts ") .. nombre .. ")")
    elseif a.que == "mision" then table.insert(partes, L("acepta ", "accept ") .. nombre .. MORADO .. L(" (la importante)", " (the key one)") .. "|r" .. BLANCO)
    else table.insert(partes, L("acepta ", "accept ") .. nombre) end
  end
  local z = zonaDe(pa.m)
  return ORO .. (pa.n or "?") .. "|r" .. GRIS .. (z ~= "" and (" (" .. z .. ")") or "") .. "|r" .. BLANCO .. ": " .. table.concat(partes, L(" y ", " and ")) .. "|r"
end

local pines, rayas, sombras = {}, {}, {}
local capaLineas
local function lienzo()
  if not WorldMapFrame or WowF.interfazMando() then return nil end -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
  if WorldMapFrame.GetCanvas then return WorldMapFrame:GetCanvas() end
  return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end
local function enVista(m, x, y, visto)
  if m == visto then return x, y end
  if WowF.proyectar then
    local vx, vy = WowF.proyectar(m, x, y, visto)
    if vx and vx >= -0.5 and vx <= 100.5 and vy >= -0.5 and vy <= 100.5 then return vx, vy end
  end
  return nil
end
-- Raton sobre un circulo: que misiones son de este sitio y que hacer aqui
local function tooltipPunto(self)
  if not GameTooltip or not linea then return end
  local d, q = self.datos, linea.q
  local st, maz = estadoActual(), mazDe(q)
  local total = #todas(q)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(L("LINEA DE MISIONES", "QUESTLINE"), 1, 0.6, 0.2)
  GameTooltip:AddLine(L("Para: ", "For: ") .. (q.mazmorra and (L("la mision de ", "the quest of ") .. maz) or (L("conseguir ", "getting ") .. (q.equipo or "?"))), 1, 1, 1, true)
  if d.texto == "1" then GameTooltip:AddLine(VERDE .. L("1 = AHORA. Aqui:", "1 = NOW. Here:") .. "|r", 1, 1, 1)
  else GameTooltip:AddLine(NARANJA .. L("2 = DESPUES (la siguiente parada). Aqui:", "2 = NEXT (the next stop). Here:") .. "|r", 1, 1, 1) end
  local ahoraAqui
  for _, en in ipairs(d.entradas or {}) do
    local p = en.e.p
    local verbo
    if en.que == "entregar" then verbo = L("se entrega aqui a ", "turn it in here to ") .. ORO .. (p.e or "?") .. "|r"
    elseif en.que == "matar" then verbo = L("mata a ", "kill ") .. BLANCO .. (p.s or "?") .. "|r" .. L(": suelta ", ": it drops ") .. ORO .. (p.o or "?") .. "|r"
    elseif en.que == "mision" then verbo = ORO .. (p.q or "?") .. "|r" .. L(" te la da (LA IMPORTANTE: ", " gives it (THE KEY ONE: ") .. premio(q, maz) .. ")"
    else verbo = comoEmpieza(p, maz) end
    local marca = en.estado == "hecho" and (GRIS .. L(" - hecha", " - done") .. "|r") or (en.estado == "actual" and (VERDE .. L("  << AHORA", "  << NOW") .. "|r") or "")
    GameTooltip:AddLine(en.k .. L(" de ", " of ") .. total .. ". " .. nombrePaso(p) .. ": " .. verbo .. marca, 1, 1, 1, true)
    if en.estado == "actual" then ahoraAqui = en end
    if sinDatos(p) then GameTooltip:AddLine(aviso(), 1, 1, 1, true) end
  end
  if ahoraAqui then
    local _, _, sub = ahora(q, st, todas(q))
    GameTooltip:AddLine(VERDE .. L("Que hacer aqui: ", "What to do here: ") .. "|r" .. queHacer(ahoraAqui.e.p, sub, maz), 1, 1, 1, true)
    local p = ahoraAqui.e.p
    if (p.l or 0) > nivelActual() then GameTooltip:AddLine(NARANJA .. L("Necesitas nivel " .. p.l, "Requires level " .. p.l) .. "|r", 1, 1, 1) end
  end
  GameTooltip:AddLine(L("La raya va de lo de AHORA (1) a la siguiente parada (2). Al aceptar y entregar, el mapa pasa solo a la siguiente; la linea entera esta en la ventana.",
    "The line goes from NOW (1) to the next stop (2). As you accept and turn in, the map moves on by itself; the whole questline is in the window."), 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end
local COLOR = { actual = { 0.2, 1, 0.4 }, hecho = { 0.5, 0.5, 0.5 }, luego = { 1, 0.6, 0.2 }, despues = { 0.3, 0.7, 1 }, final = { 0.78, 0.49, 1 } }
local function dibujar()
  for _, p in pairs(pines) do p:Hide() end
  for _, l in pairs(rayas) do l:Hide() end
  for _, l in pairs(sombras) do l:Hide() end
  if capaLineas then capaLineas:Hide() end
  if not linea then return end
  local c = lienzo()
  if not c or not WorldMapFrame:IsShown() then return end
  local visto = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  local ancho, alto = c:GetWidth(), c:GetHeight()
  if not visto or not ancho or ancho == 0 then return end
  local escala = 1
  pcall(function() escala = c:GetEffectiveScale() / UIParent:GetEffectiveScale() end)
  if not escala or escala <= 0 then escala = 1 end
  local px = 1 / escala
  local lista, ruta = puntos()
  local n = 0
  for _, d in ipairs(lista) do
    local vx, vy = enVista(d.m, d.x, d.y, visto)
    d.vx, d.vy = vx, vy
    if vx then
      n = n + 1
      local pin = pines[n]
      if not pin then
        pin = CreateFrame("Button", nil, c)
        pin:SetFrameStrata("HIGH")
        pin.aro = pin:CreateTexture(nil, "BACKGROUND")
        pin.aro:SetAllPoints()
        pin.fondo = pin:CreateTexture(nil, "BORDER")
        pcall(function()
          for _, tx in ipairs({ pin.aro, pin.fondo }) do
            local mk = pin:CreateMaskTexture()
            mk:SetAllPoints(tx)
            mk:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            tx:AddMaskTexture(mk)
          end
        end)
        pin.numero = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        pin.numero:SetPoint("CENTER", 0, 0)
        pin:SetScript("OnEnter", tooltipPunto)
        pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        pin:SetScript("OnClick", function() if WowF.abrirLinea then WowF.abrirLinea() end end)
        pines[n] = pin
      end
      pin.datos = d
      pcall(function() pin:SetFrameLevel(c:GetFrameLevel() + 10) end)
      local tam = (d.texto == "1" and 19 or 15) * px -- el de AHORA, mas grande
      pin:SetSize(math.max(tam, (#d.texto * 5.5 + 8) * px), tam)
      pin.fondo:ClearAllPoints(); pin.fondo:SetPoint("TOPLEFT", 1.5 * px, -1.5 * px); pin.fondo:SetPoint("BOTTOMRIGHT", -1.5 * px, 1.5 * px)
      pin.fondo:SetColorTexture(0, 0, 0, 0.9)
      -- Verde = lo de ahora; morado = la importante; naranja = lo que falta; azul = despues; gris = hecho
      local col = (d.estado ~= "actual" and d.final) and COLOR.final or COLOR[d.estado]
      pin.aro:SetColorTexture(col[1], col[2], col[3], 1)
      pcall(pin.numero.SetFont, pin.numero, (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"), (d.texto == "1" and 11 or 9) * px, "OUTLINE")
      pin.numero:SetText(d.texto)
      pin.numero:SetTextColor(1, 1, 1)
      pin:ClearAllPoints()
      pin:SetPoint("CENTER", c, "TOPLEFT", ancho * vx / 100, -alto * vy / 100)
      pin:Show()
    end
  end
  -- La ruta: una raya de cada sitio al siguiente, en el orden en que se hacen las misiones (capa propia: si no, las tapa el mapa)
  local nl, antes = 0, nil
  for _, r in ipairs(ruta) do
    local d = r.d
    if antes and antes.vx and d.vx then
      if not capaLineas then
        capaLineas = CreateFrame("Frame", nil, c)
        capaLineas:SetAllPoints(c)
        capaLineas:SetFrameStrata("HIGH")
      end
      pcall(function() capaLineas:SetFrameLevel(c:GetFrameLevel() + 1) end)
      capaLineas:Show()
      if capaLineas.CreateLine then
        nl = nl + 1
        if not rayas[nl] then
          local ok1, s1 = pcall(capaLineas.CreateLine, capaLineas, nil, "ARTWORK")
          local ok2, l2 = pcall(capaLineas.CreateLine, capaLineas, nil, "OVERLAY")
          if ok1 and s1 then sombras[nl] = s1 end
          if ok2 and l2 then rayas[nl] = l2 end
        end
        local col = (r.clave and r.estado ~= "hecho" and r.estado ~= "actual") and COLOR.final or COLOR[r.estado]
        for _, par in ipairs({ { sombras[nl], 5, 0, 0, 0, 0.75 }, { rayas[nl], 2.5, col[1], col[2], col[3], 1 } }) do
          local ln = par[1]
          if ln then
            ln:SetThickness(par[2] * px)
            ln:SetColorTexture(par[3], par[4], par[5], par[6])
            ln:SetStartPoint("TOPLEFT", c, ancho * antes.vx / 100, -alto * antes.vy / 100)
            ln:SetEndPoint("TOPLEFT", c, ancho * d.vx / 100, -alto * d.vy / 100)
            ln:Show()
          end
        end
      end
    end
    antes = d
  end
end
WowF.dibujarLineaMisiones = dibujar
WowF.pinesLineaMisiones = function() local k = 0; for _, p in pairs(pines) do if p:IsShown() then k = k + 1 end end; return k end -- para las pruebas
WowF.marcadoresLinea = function() return pines end -- para las pruebas
WowF.rayasLinea = function() local k = 0; for _, l in pairs(rayas) do if l:IsShown() then k = k + 1 end end; return k end -- para las pruebas

-- ===================== Ventana de la linea (una a la vez) =====================
local ventana, vTitulo, vResumen, vAhora, vComo, vLista, vPie, vMapa, vQuitar, vMini
local vCab, vEtiqueta, vNombre, vTramos, vTarjeta, vEtAhora, vEtLista, vFilas, vRetrato
-- 13-oct (Andy: una sola ventana, de tamano normal, con la rueda del raton): rumbo de la ruta arriba y el resto con scroll
local vRumbo, vRumboEt, vFlecha, vYardas, vPaso, vScroll, vHijo, vUltK
local ALTO_MAX = 420 -- alto maximo de la parte con scroll (lo demas, con la rueda)
local ANCHO_MINI = 290
local ANCHO = 400
local IZQ = 16 -- margen del contenido (ventana = ANCHO + 2 x 12)
local function fuente(padre, plantilla, otra)
  local ok, f = pcall(padre.CreateFontString, padre, nil, "OVERLAY", plantilla)
  if not ok or not f then f = padre:CreateFontString(nil, "OVERLAY", otra) end
  f:SetJustifyH("LEFT")
  return f
end
local function altoDe(f, lineas)
  local h = f.GetStringHeight and f:GetStringHeight()
  if type(h) ~= "number" or h <= 0 then h = (lineas or 1) * 14 end
  return h
end
local function lugarAhora()
  if not linea then return nil end
  local q, st = linea.q, estadoActual()
  local _, e, sub = ahora(q, st, todas(q))
  local p = e and e.p
  if not p then return nil end
  if sub == "entregar" and p.em and p.em > 0 then return p.em end
  if p.s and p.sm and p.sm > 0 then return p.sm end
  if p.m and p.m > 0 then return p.m end
  return nil
end
local quitarLinea
local function crearVentana()
  if ventana then return end
  ventana = CreateFrame("Frame", "wowFLinea", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  ventana:SetSize(ANCHO + 24, 260)
  ventana:SetFrameStrata("DIALOG")
  ventana:SetClampedToScreen(true)
  ventana:SetMovable(true)
  ventana:EnableMouse(true)
  ventana:RegisterForDrag("LeftButton")
  ventana:SetScript("OnDragStart", function(self) self:StartMoving() end)
  ventana:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local a, _, b, x, y = self:GetPoint()
    WowFExportarDB.lineaPos = { a, b, x, y }
  end)
  ventana:ClearAllPoints()
  local g = WowFExportarDB.lineaPos
  if type(g) == "table" and g[1] then ventana:SetPoint(g[1], UIParent, g[2], g[3], g[4]) else ventana:SetPoint("LEFT", UIParent, "LEFT", 40, 60) end
  -- 11-oct (rediseno "hibrido", como la tarjeta de la ruta): cabecera "LINEA DE MISIONES · X  k/T", etiqueta brasa
  -- "MISION k DE T", el nombre de la mision en serif, rayas de avance, tarjeta "QUE HACER AHORA" y la linea en filas con divisores.
  local E = WowF.estilo
  E.marco(ventana, "panel")
  ventana:Hide()
  vCab = E.cabecera(ventana, 22)
  vTitulo = vCab.titulo
  vCab.derecha:ClearAllPoints()
  vCab.derecha:SetPoint("RIGHT", vCab.fondo, "RIGHT", -50, 0)
  -- Rumbo de la ruta (lo que antes era el recuadro aparte): flecha hacia el alfiler, yardas, rumbo y PASO i DE N
  vRumbo = CreateFrame("Frame", nil, ventana, BackdropTemplateMixin and "BackdropTemplate" or nil)
  vRumbo:SetPoint("TOPLEFT", IZQ, -34)
  vRumbo:SetSize(ANCHO, 52)
  E.marco(vRumbo, "losa")
  -- 13-oct (Andy: "un desastre"): el aro iba centrado y, al crecer el recuadro, bajaba el texto y se salia. Ahora todo arriba.
  vRumboEt = E.etiqueta(vRumbo)
  vRumboEt:SetPoint("TOPLEFT", 10, -9)
  local aro = vRumbo:CreateTexture(nil, "ARTWORK")
  aro:SetTexture(E.texturas.aro)
  aro:SetSize(32, 32)
  aro:SetPoint("TOPLEFT", 8, -26)
  vFlecha = vRumbo:CreateTexture(nil, "OVERLAY")
  vFlecha:SetTexture("Interface\\Minimap\\MinimapArrow")
  vFlecha:SetSize(24, 24)
  vFlecha:SetPoint("CENTER", aro, "CENTER", 0, 0)
  vYardas = E.cuerpo(vRumbo, nil, 12)
  vYardas:SetPoint("TOPLEFT", aro, "TOPRIGHT", 10, -1)
  vPaso = E.sub(vRumbo, nil, 10)
  vPaso:SetPoint("TOPLEFT", vYardas, "BOTTOMLEFT", 0, -3)
  if vPaso.SetSpacing then vPaso:SetSpacing(2) end
  vRumbo:Hide()
  -- Todo lo demas va en un marco con scroll (rueda del raton), para que la ventana no pase de un tamano normal
  vScroll = CreateFrame("ScrollFrame", "wowFLineaScroll", ventana, "UIPanelScrollFrameTemplate")
  vHijo = CreateFrame("Frame", nil, vScroll)
  vHijo:SetSize(ANCHO, 200)
  vScroll:SetScrollChild(vHijo)
  vEtiqueta = E.etiqueta(vHijo)
  vEtiqueta:SetPoint("TOPLEFT", 0, 0)
  vNombre = E.titulo(vHijo, nil, 16)
  vNombre:SetPoint("TOPLEFT", vEtiqueta, "BOTTOMLEFT", 0, -5)
  vTramos = E.tramos(vHijo, ANCHO)
  vResumen = E.sub(vHijo, nil, 10)
  if vResumen.SetSpacing then vResumen:SetSpacing(2) end
  -- Tarjeta de lo que toca ahora (raya brasa arriba)
  vTarjeta = E.tarjeta(vHijo, { acento = true })
  vEtAhora = E.etiqueta(vTarjeta)
  vEtAhora:SetPoint("TOPLEFT", 12, -11)
  vAhora = E.cuerpo(vTarjeta, nil, 11)
  vAhora:SetPoint("TOPLEFT", vEtAhora, "BOTTOMLEFT", 0, -5)
  if vAhora.SetSpacing then vAhora:SetSpacing(2) end
  vComo = E.cuerpo(vTarjeta, nil, 10)
  vComo:SetPoint("TOPLEFT", vAhora, "BOTTOMLEFT", 0, -7)
  if vComo.SetSpacing then vComo:SetSpacing(2) end
  -- Retrato redondo del NPC de lo que toca ahora (wowF_Retratos.lua), arriba a la derecha de la tarjeta
  if WowF.marcoRetrato then
    vRetrato = WowF.marcoRetrato(vTarjeta, 34)
    vRetrato:SetPoint("TOPRIGHT", -10, -10)
    vRetrato:Hide()
  end
  -- La linea entera: una fila por mision (nombre + detalle gris) con divisor fino
  vEtLista = E.etiqueta(vHijo)
  vLista = vEtLista
  vFilas = {}
  vPie = E.sub(vHijo, nil, 9)
  if vPie.SetSpacing then vPie:SetSpacing(2) end
  local cerrar = CreateFrame("Button", nil, ventana, "UIPanelButtonTemplate")
  E.boton(cerrar, "cuero", 11)
  cerrar:SetSize(18, 18)
  cerrar:SetText("X")
  cerrar:SetPoint("TOPRIGHT", -8, -6)
  cerrar:SetScript("OnClick", function()
    ventana:Hide()
    if linea then print(AZUL .. L("ventana cerrada; la linea sigue (vuelve a salir al avanzar). Para verla: /wowf linea.", "window closed; the questline goes on (it shows again when you advance). To see it: /wowf questline.")) end
  end)
  vMini = CreateFrame("Button", nil, ventana, "UIPanelButtonTemplate")
  WowF.estilo.boton(vMini, "cuero", 11)
  vMini:SetSize(18, 18)
  vMini:SetPoint("RIGHT", cerrar, "LEFT", -4, 0)
  vMini:SetScript("OnClick", function()
    WowFExportarDB.lineaMini = not WowFExportarDB.lineaMini or nil
    actualizarVentanaRef(true)
  end)
  vMini:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(WowF.yaTraducido and WowF.yaTraducido(WowFExportarDB.lineaMini and L("Ver la linea entera", "Show the whole questline") or L("Hacerla pequena (solo lo de ahora)", "Make it small (only what is next)")) or "", 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  vMini:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  vMapa = CreateFrame("Button", nil, ventana, "UIPanelButtonTemplate")
  WowF.estilo.boton(vMapa, "brasa")
  vMapa:SetSize(130, 22)
  vMapa:SetPoint("BOTTOMLEFT", IZQ, 14)
  vMapa:SetScript("OnClick", function()
    if not linea or not WorldMapFrame or WowF.interfazMando() then return end -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
    if not WorldMapFrame:IsShown() then
      if ShowUIPanel then pcall(ShowUIPanel, WorldMapFrame) elseif ToggleWorldMap then pcall(ToggleWorldMap) else pcall(WorldMapFrame.Show, WorldMapFrame) end
    end
    local m = lugarAhora()
    if m and WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, m) end
    pcall(dibujar)
  end)
  vQuitar = CreateFrame("Button", nil, ventana, "UIPanelButtonTemplate")
  WowF.estilo.boton(vQuitar, "cuero")
  vQuitar:SetSize(130, 22)
  vQuitar:SetPoint("LEFT", vMapa, "RIGHT", 6, 0)
  vQuitar:SetScript("OnClick", function()
    quitarLinea()
    if WowF.limpiarRutas then pcall(WowF.limpiarRutas, true) end
    print(AZUL .. L("linea de misiones quitada.", "questline removed."))
  end)
end

-- Textos de la ventana (tambien para las pruebas): titulo, resumen, ahora, lista, pie
local function textosVentana()
  if not linea then return nil end
  local q, st = linea.q, estadoActual()
  local maz = mazDe(q)
  local r, huecos, total, k, sub = filas(q, st)
  local e = todas(q)[k]
  local titulo = NARANJA .. L("LINEA DE MISIONES", "QUESTLINE") .. "|r" .. GRIS .. " - |r" .. BLANCO
    .. (q.mazmorra and (L("para la mision de ", "for the quest of ") .. maz) or (L("para conseguir ", "to get ") .. (q.equipo or "?"))) .. "|r"
  local ya = VERDE .. L("AHORA (mision " .. k .. " de " .. total .. "): ", "NOW (quest " .. k .. " of " .. total .. "): ") .. "|r" .. (e and queHacer(e.p, sub, maz) or "")
  if linea.ultima then ya = HECHA .. VERDE .. linea.ultima .. "|r" .. BLANCO .. L(" La proxima es esta:", " The next one is this:") .. "|r\n" .. ya end
  if e and (e.p.l or 0) > nivelActual() then ya = ya .. NARANJA .. L(" Necesitas nivel " .. e.p.l .. ".", " Requires level " .. e.p.l .. ".") .. "|r" end
  if e and e.tipo == "clave" then ya = ya .. MORADO .. L(" Es la ultima antes de " .. (maz or "la pieza") .. ".", " It is the last one before " .. (maz or "the item") .. ".") .. "|r" end
  -- 12-oct: una sola orden (AHORA) y adonde vas DESPUES (la siguiente parada en otro sitio), igual que los circulos 1 y 2 del mapa
  local sigP = siguienteParada(paradas(q, st))
  local despues = sigP and (NARANJA .. L("DESPUES (2 en el mapa): ", "NEXT (2 on the map): ") .. "|r" .. textoParada(sigP)) or nil
  if despues then ya = ya .. "\n" .. despues end
  local pie = GRIS .. L("Mapa (M): solo dos circulos. 1 (verde) = adonde vas AHORA; 2 = la siguiente parada (morado si alli te dan la importante). Al aceptar y entregar pasan solos a la siguiente. La lista de abajo es la linea entera, en orden.",
    "Map (M): only two circles. 1 (green) = where you go NOW; 2 = the next stop (purple if the key one is there). As you accept and turn in they move on by themselves. The list below is the whole questline, in order.") .. "|r"
  if huecos then pie = pie .. "\n" .. aviso() end
  local cl = comoLlegar(q, st)
  local como = cl and (ORO .. L("COMO LLEGAR: ", "HOW TO GET THERE: ") .. "|r" .. cl.texto) or ""
  local nComo = 1
  for _ in como:gmatch("\n") do nComo = nComo + 1 end
  if WowFExportarDB.lineaMini then
    -- Pequena: lo de ahora y la siguiente (las cumplidas no salen)
    local sig = todas(q)[k + 1]
    local s = (sig and not despues) and (GRIS .. L("Despues: ", "Then: ") .. k + 1 .. ". " .. nombreDe(sig.p) .. (sig.tipo == "clave" and L(" (la importante)", " (the key one)") or "") .. "|r") or ""
    local cl2 = cl and cl.tipo ~= "aqui" and cl.corto and (CELESTE .. L("Como llegar: ", "How to get there: ") .. "|r" .. cl.corto) or nil
    if cl2 then s = cl2 .. (s ~= "" and ("\n" .. s) or "") end
    local t2 = NARANJA .. L("LINEA ", "QUESTLINE ") .. k .. "/" .. total .. "|r" .. GRIS .. " - " .. (q.mazmorra and maz or (q.equipo or "?")) .. "|r"
    return t2, "", ya, s, "", "", 0, 2
  end
  return titulo, resumen(q, st), ya, como, table.concat(r, "\n"), pie, #r, nComo
end
WowF.lineaTextos = function() local a, b, c, d, e, f = textosVentana(); return a and table.concat({ a, b, c, d, e, f }, "\n") or nil end -- para las pruebas
-- Bloque de rumbo (ruta de wowF_Viaje hacia el paso de la linea). Devuelve su alto (0 = no hay ruta de la linea)
local function pintarRumbo(cw)
  local s = WowF.viajeEstado and WowF.viajeEstado()
  if not (vRumbo and s and s.fusion) then if vRumbo then vRumbo:Hide() end return 0 end
  local E = WowF.estilo
  local C = E.color
  if cw then vRumbo:SetWidth(cw); vYardas:SetWidth(cw - 64); vPaso:SetWidth(cw - 64) end
  if s.yardas then
    vYardas:SetText(E.cod.brasa .. string.format("%d", math.floor(s.yardas / 10 + 0.5) * 10) .. " yd|r" .. E.cod.texto .. L("  hacia el ", "  to the ") .. string.upper(s.rumbo or "") .. "|r"
      .. (s.borde and (E.cod.tenue .. L(" · alfiler en el borde de la zona", " · pin on the zone edge") .. "|r") or ""))
  else
    vYardas:SetText(s.frase or "")
  end
  vRumboEt:SetText(E.mayus(L("Camino · paso ", "Route · step ") .. s.i .. L(" de ", " of ") .. s.n))
  vPaso:SetText(E.cod.texto .. (s.texto or "") .. "|r"
    .. (s.detalle and ("\n" .. E.cod.tenue .. s.detalle .. "|r") or ""))
  if s.grados and vFlecha.SetRotation then
    pcall(vFlecha.SetRotation, vFlecha, -math.rad(s.grados))
    vFlecha:Show()
  else
    vFlecha:Hide()
  end
  vRumbo:Show()
  local h = math.max(26 + 32 + 10, 26 + altoDe(vYardas) + 3 + altoDe(vPaso, s.detalle and 4 or 2) + 12)
  vRumbo:SetHeight(h)
  return h
end
local vRumboAlto = 0
local function actualizarVentana(mostrar)
  if not linea then if ventana then ventana:Hide() end return end
  crearVentana()
  local titulo, res, ya, como, lista, pie, nFilas, nComo = textosVentana()
  local E = WowF.estilo
  -- 13-oct: con la ruta arriba (fusion), el "Como llegar" de la tarjeta sobra
  local est = WowF.viajeEstado and WowF.viajeEstado()
  if type(est) == "table" and est.fusion then como = "" end
  local mini = WowFExportarDB.lineaMini and true or false
  local ancho = mini and ANCHO_MINI or ANCHO
  local cw = ancho + 24 - IZQ - 30 -- ancho del contenido (a la derecha queda la barra del scroll)
  ventana:SetWidth(ancho + 24)
  -- Datos de la cabecera y del titulo (los textos completos siguen en textosVentana para el chat y las pruebas)
  local q, st = linea.q, estadoActual()
  local lst = todas(q)
  local _, _, total, k = filas(q, st)
  local e = lst[k]
  local destino = q.mazmorra and mazDe(q) or (q.equipo or "?")
  vTitulo:SetText((mini and L("LÍNEA · ", "QUESTLINE · ") or L("LÍNEA DE MISIONES · ", "QUESTLINE · ")) .. E.mayus(destino or ""))
  vCab.derecha:SetText(k .. "/" .. total)
  vEtiqueta:SetText(E.mayus(L("Misión " .. k .. " de " .. total, "Quest " .. k .. " of " .. total))
    .. ((e and e.tipo == "clave") and ("  |cffc77dff" .. E.mayus(L("la importante", "the key one")) .. "|r") or ""))
  vNombre:SetWidth(cw)
  vNombre:SetText(e and nombreDe(e.p) or "")
  vTramos:SetWidth(cw)
  vTramos:ClearAllPoints()
  vTramos:SetPoint("TOPLEFT", vNombre, "BOTTOMLEFT", 0, -8)
  vTramos:poner(k, total)
  -- Colores del estilo viejo -> paleta del rediseno (solo al mostrar; verde, morado y naranja siguen como detalle con significado)
  local function pinta(s)
    s = (s or ""):gsub("|cffffd100", E.cod.oro):gsub("|cffffffff", E.cod.texto):gsub("|cff999999", E.cod.tenue):gsub("|cffcccccc", E.cod.tenue):gsub("|cff66ccff", E.cod.oro)
    return s
  end
  vResumen:SetWidth(cw)
  vResumen:SetText(pinta(res))
  vResumen:ClearAllPoints()
  vResumen:SetPoint("TOPLEFT", vTramos, "BOTTOMLEFT", 0, -9)
  -- Tarjeta QUE HACER AHORA
  vEtAhora:SetText(E.mayus(L("Qué hacer ahora", "What to do now")))
  vAhora:SetWidth(cw - 24)
  vComo:SetWidth(cw - 24)
  if vRetrato then
    local d = destinoDe(q, st)
    if d and d.n and d.n ~= "" then
      pcall(vRetrato.poner, vRetrato, { nombre = d.n, unidad = "target", icono = d.que == "matar" and "Interface\\Icons\\Ability_Warrior_Sunder" or "Interface\\GossipFrame\\AvailableQuestIcon" })
      vRetrato:Show()
      vAhora:SetWidth(cw - 24 - 42) -- el texto no pasa por debajo del retrato
    else
      vRetrato:Hide()
    end
  end
  vAhora:SetText(pinta(ya))
  vComo:SetText(pinta(como))
  vTarjeta:ClearAllPoints()
  vTarjeta:SetPoint("TOPLEFT", mini and vTramos or vResumen, "BOTTOMLEFT", 0, mini and -10 or -10)
  vTarjeta:SetWidth(cw)
  local altoT = 12 + 12 + 5 + altoDe(vAhora, 4) + (como ~= "" and (7 + altoDe(vComo, nComo)) or 0) + 12
  vTarjeta:SetHeight(altoT)
  -- La linea en filas: cada cabecera (sin sangria) con sus detalles (con sangria) debajo, y un divisor
  local grupos = {}
  if not mini then
    for t in ((lista or "") .. "\n"):gmatch("([^\n]*)\n") do
      if t ~= "" then
        if t:find("^%s%s%s") and grupos[#grupos] then
          local g = grupos[#grupos]
          g.det = (g.det and (g.det .. "\n") or "") .. t:gsub("^%s+", "")
        else
          table.insert(grupos, { cab = t })
        end
      end
    end
  end
  vEtLista:ClearAllPoints()
  vEtLista:SetPoint("TOPLEFT", vTarjeta, "BOTTOMLEFT", 0, -14)
  vEtLista:SetText(E.mayus(L("La línea entera", "The whole questline")))
  local altoLista = 14 + 12
  local ancla = vEtLista
  for i = 1, math.max(#grupos, #vFilas) do
    local f = vFilas[i]
    local g = grupos[i]
    if g then
      if not f then
        f = { nombre = E.cuerpo(vHijo, nil, 11), detalle = E.sub(vHijo, nil, 10), div = E.textura(vHijo, "ARTWORK", 1, E.color.borde, 1) }
        if f.detalle.SetSpacing then f.detalle:SetSpacing(2) end
        f.div:SetHeight(1)
        vFilas[i] = f
      end
      f.nombre:ClearAllPoints()
      f.nombre:SetPoint("TOPLEFT", ancla, "BOTTOMLEFT", 0, i == 1 and -7 or -6)
      f.nombre:SetWidth(cw)
      f.nombre:SetText(pinta(g.cab))
      local h = altoDe(f.nombre) + (i == 1 and 7 or 6)
      local ultimo = f.nombre
      if g.det then
        f.detalle:ClearAllPoints()
        f.detalle:SetPoint("TOPLEFT", f.nombre, "BOTTOMLEFT", 0, -3)
        f.detalle:SetWidth(cw)
        f.detalle:SetText(pinta(g.det))
        f.detalle:Show()
        local n = 1
        for _ in g.det:gmatch("\n") do n = n + 1 end
        h = h + 3 + altoDe(f.detalle, n * 2)
        ultimo = f.detalle
      else
        f.detalle:SetText("")
        f.detalle:Hide()
      end
      f.div:ClearAllPoints()
      f.div:SetPoint("TOPLEFT", ultimo, "BOTTOMLEFT", 0, -6)
      f.div:SetWidth(cw)
      f.div:Show()
      f.nombre:Show()
      altoLista = altoLista + h + 7
      ancla = f.div
    elseif f then
      f.nombre:SetText(""); f.nombre:Hide(); f.detalle:SetText(""); f.detalle:Hide(); f.div:Hide()
    end
  end
  vPie:ClearAllPoints()
  vPie:SetPoint("TOPLEFT", ancla, "BOTTOMLEFT", 0, -8)
  vPie:SetWidth(cw)
  vPie:SetText(pinta(pie))
  for _, f in ipairs({ vResumen, vEtLista, vPie, vQuitar }) do if mini then f:Hide() else f:Show() end end
  vMini:SetText(mini and "+" or "-")
  vMapa:SetText(L("Ver el mapa", "Open the map"))
  vQuitar:SetText(L("Quitar la linea", "Remove questline"))
  -- Alto: cabecera (28) + etiqueta + titulo + rayas + resumen + tarjeta + lista + pie + botones
  local alto = 40 + 12 + 5 + altoDe(vNombre) + 8 + 3
  if mini then
    alto = alto + 10 + altoT
  else
    alto = alto + 9 + altoDe(vResumen, 2) + 10 + altoT + altoLista + 8 + altoDe(vPie, 3)
  end
  -- 13-oct: el contenido va en el scroll; la ventana crece solo hasta ALTO_MAX (o lo que quepa en pantalla) y lo demas se ve con la rueda
  local contenido = alto - 40 + 10
  local hR = pintarRumbo(ancho + 24 - 2 * IZQ)
  vRumboAlto = hR
  local arriba = hR > 0 and (34 + hR + 8) or 36
  local maxV = ALTO_MAX
  local pantalla = UIParent and UIParent.GetHeight and tonumber(UIParent:GetHeight())
  local esc = ventana.GetScale and tonumber(ventana:GetScale()) or 1
  if pantalla and pantalla > 200 and esc and esc > 0 then maxV = math.min(maxV, pantalla / esc * 0.8 - arriba - 50) end
  local visible = math.max(80, math.min(contenido, maxV))
  vHijo:SetSize(cw, contenido)
  vScroll:ClearAllPoints()
  vScroll:SetPoint("TOPLEFT", IZQ, -arriba)
  vScroll:SetPoint("TOPRIGHT", -30, -arriba)
  vScroll:SetHeight(visible)
  vScroll.scrollBarHideable = true
  local hayMas = contenido > visible + 1
  local barra = vScroll.ScrollBar or _G.wowFLineaScrollScrollBar
  if type(barra) == "table" then pcall(function() if hayMas then barra:Show() else barra:Hide() end end) end
  pcall(function()
    if vScroll.UpdateScrollChildRect then vScroll:UpdateScrollChildRect() end
    local maxS = math.max(0, contenido - visible)
    if vUltK ~= k then vScroll:SetVerticalScroll(0) -- mision nueva: arriba, donde esta QUE HACER AHORA
    elseif (tonumber(vScroll:GetVerticalScroll()) or 0) > maxS then vScroll:SetVerticalScroll(maxS) end
  end)
  vUltK = k
  ventana:SetHeight(arriba + visible + 50)
  if mostrar then ventana:Show() end
end
actualizarVentanaRef = actualizarVentana
-- Cada segundo (vigia de wowF_Viaje): yardas y flecha al dia; si el bloque cambia de alto, se rehace la ventana
WowF.lineaRumbo = function()
  if not (linea and ventana and ventana:IsShown()) then return end
  local h = pintarRumbo()
  if math.abs(h - vRumboAlto) > 1 then pcall(actualizarVentana, false) end
end
WowF.lineaMostrar = function() if linea then pcall(actualizarVentana, true) end end
WowF.lineaScroll = function() crearVentana(); return vScroll, vHijo, vRumbo end -- para las pruebas
WowF.lineaRumboTexto = function() return vRumbo and vRumbo:IsShown() and ((vRumboEt:GetText() or "") .. "\n" .. (vYardas:GetText() or "") .. "\n" .. (vPaso:GetText() or "")) or nil end -- para las pruebas
WowF.lineaMinimizar = function(si) WowFExportarDB.lineaMini = si and true or nil; if linea then actualizarVentana(true) end end -- para las pruebas
WowF.lineaVentana = function() crearVentana(); return ventana end -- para las pruebas
function WowF.abrirLinea()
  if not linea then print(AZUL .. L("no estas siguiendo ninguna linea de misiones. Haz clic en una mision con linea (Libro, mapa o panel).", "you are not following any questline. Click a quest that has one (Book, map or panel).")); return false end
  local d = destinoDe(linea.q, estadoActual())
  if d and not rutaActivaA(d) and rutaAlPasoRef then pcall(rutaAlPasoRef, linea.q) end
  actualizarVentana(true)
  return true
end

quitarLinea = function()
  linea = nil
  if placasLinea then pcall(placasLinea, false) end
  WowFExportarDB.linea = nil
  WowFExportarDB.lineaEquipo = nil
  if ventana then ventana:Hide() end
  pcall(dibujar)
end
WowF.quitarLineaMisiones = quitarLinea
WowF.lineaActiva = function() return linea end

-- La linea entera en el chat
local function contar(q, st)
  local r, huecos, total, k, sub = filas(q, st)
  local e = todas(q)[k]
  print(AZUL .. NARANJA .. L("LINEA DE MISIONES", "QUESTLINE") .. "|r" .. L(" para ", " for ") .. BLANCO .. (q.mazmorra and mazDe(q) or (q.equipo or q.n)) .. "|r: " .. resumen(q, st))
  for _, t in ipairs(r) do print("   " .. t) end
  print("   " .. VERDE .. L("QUE HACER AHORA (mision " .. k .. " de " .. total .. "): ", "WHAT TO DO NOW (quest " .. k .. " of " .. total .. "): ") .. "|r" .. (e and queHacer(e.p, sub, mazDe(q)) or ""))
  print("   " .. GRIS .. L("Datos: Wowhead /forever (Series). La linea sale en su ventana y en el mapa (M), numerada y unida por una raya.",
    "Data: Wowhead /forever (Series). The questline shows in its window and on the map (M), numbered and joined by a line.") .. "|r")
  if huecos then print("   " .. aviso()) end
end

-- Ruta (wowF_Viaje) hasta el paso que toca
local function rutaAlPaso(q, st)
  st = st or estadoLinea(q) or { c = q.cadena }
  local d = destinoDe(q, st)
  if not d or d.dentro or not (d.m and d.m > 0) or zonaVedada(d.m) then return false end
  local p = d.p
  local total = #todas(q)
  local destino
  local titulo = L("Linea: mision " .. d.k .. " de " .. total, "Questline: quest " .. d.k .. " of " .. total)
  local ventanaRuta = NARANJA .. titulo .. "|r" .. GRIS .. " (" .. para(q) .. ")|r"
  if d.que == "entregar" then
    if p.ed or not (p.em and p.em > 0) then return false end
    destino = { n = p.e, m = p.em, x = p.ex, y = p.ey, lugar = true, final = { titulo = p.e, ventana = ventanaRuta,
      texto = L("Entrega ", "Turn in ") .. nombrePaso(p) .. L(" a ", " to ") .. ORO .. p.e .. "|r",
      llegada = L("entrega ", "turn in ") .. nombrePaso(p) .. L(" a ", " to ") .. ORO .. p.e .. "|r" .. VERDE .. L(". Luego te llevo a la siguiente mision.", ". Then I will take you to the next quest.") .. "|r" } }
  elseif d.que == "matar" then
    if p.sd or not (p.sm and p.sm > 0) then return false end
    destino = { n = p.s, m = p.sm, x = p.sx, y = p.sy, lugar = true, final = { titulo = p.s, ventana = ventanaRuta,
      texto = L("Mata a ", "Kill ") .. BLANCO .. p.s .. "|r" .. L(" hasta que suelte ", " until it drops ") .. ORO .. (p.o or "?") .. "|r" .. (p.sp and p.sp > 0 and (GRIS .. " (" .. pct(p.sp) .. ")|r") or ""),
      detalle = L("Clic derecho en " .. (p.o or "el objeto") .. " para aceptar " .. (p.n or "la mision") .. ".", "Right-click " .. (p.o or "the item") .. " to accept " .. (p.n or "the quest") .. "."),
      llegada = L("mata a ", "kill ") .. BLANCO .. p.s .. "|r" .. L(" hasta que suelte ", " until it drops ") .. ORO .. (p.o or "?") .. "|r" .. L("; clic derecho en el para aceptar la mision.", "; right-click it to accept the quest.") } }
  else
    if p.d or not (p.m and p.m > 0) then return false end
    destino = { n = p.q or "?", m = p.m, x = p.x, y = p.y, lugar = true, final = { titulo = p.q, ventana = ventanaRuta,
      texto = L("Habla con ", "Talk to ") .. ORO .. (p.q or "?") .. "|r" .. L(" y acepta ", " and accept ") .. nombrePaso(p),
      llegada = L("habla con ", "talk to ") .. ORO .. (p.q or "?") .. "|r" .. L(" y acepta ", " and accept ") .. nombrePaso(p) .. "." } }
  end
  destino.z = zonaDe(destino.m)
  destino.final.linea = true -- 13-oct: la ruta va DENTRO de la ventana de la linea (sin el recuadro aparte de wowF_Viaje)
  if destino.n and destino.n ~= "?" then -- retrato del NPC en la ventana de la ruta (wowF_Viaje.lua)
    destino.retrato = { nombre = destino.n, unidad = "target", icono = d.que == "matar" and "Interface\\Icons\\Ability_Warrior_Sunder" or "Interface\\GossipFrame\\AvailableQuestIcon" }
  end
  local ok, hecho = false, false
  if WowF.viajeA then ok, hecho = pcall(WowF.viajeA, destino, { dibujar = true, callado = WowF.lineaCallada }) end
  if not (ok and hecho) and WowF.marcar then WowF.marcandoLinea = true; pcall(WowF.marcar, destino); WowF.marcandoLinea = nil end
  if linea and linea.q == q then linea.conRuta = (ok and hecho) and true or false end
  return true
end
rutaAlPasoRef = rutaAlPaso
-- Al cambiar de zona (o al avanzar la ruta): si la linea no tenia camino y ahora si, se arma sola; la ventana se rehace
local function alCambiarZona()
  if not linea then return end
  local cl = comoLlegar(linea.q, estadoActual())
  if cl and cl.tipo == "ruta" and not rutaActivaA(destinoDe(linea.q, estadoActual())) and linea.conRuta ~= true
    and not (WowF.alfilerManualVivo and WowF.alfilerManualVivo()) then -- 17-oct: tu alfiler a mano no se pisa
    print(AZUL .. VERDE .. L("linea de misiones: ya hay camino desde aqui. Te pongo la ruta.", "questline: there is a way from here now. Setting the route.") .. "|r")
    pcall(rutaAlPaso, linea.q)
  end
  if ventana and ventana:IsShown() then pcall(actualizarVentana, false) end
end
WowF.lineaRefrescar = function() if linea and ventana and ventana:IsShown() then pcall(actualizarVentana, false) end end
WowF._lineaCambioZona = alCambiarZona -- para las pruebas

-- Clic en una mision con linea: la cuenta, abre su ventana, la marca en el mapa y arma la ruta al paso que toca.
-- Devuelve false si no es una linea pendiente (el que llama sigue con la ruta normal al NPC).
function WowF.irALinea(q, g, callado)
  local st = estadoLinea(q)
  if not st or not st.i then return false end
  local zv = WowF.lineaImposible(q.cadena, q.m)
  if zv then
    print(AZUL .. NARANJA .. L("LINEA DE MISIONES", "QUESTLINE") .. "|r " .. BLANCO .. (q.n or "") .. "|r: " .. textoVedada(zv))
    return true
  end
  linea = { q = q, g = g }
  if placasLinea then pcall(placasLinea, true) end
  WowFExportarDB.linea = q.id
  WowFExportarDB.lineaEquipo = (not q.mazmorra) and (q.equipo or "") or nil
  if not callado then contar(q, st) end
  pcall(rutaAlPaso, q, st)
  -- COMO LLEGAR en el chat (la ruta paso a paso ya la escribe wowF_Viaje; los demas casos se explican aqui)
  local cl = comoLlegar(q, st)
  if cl and not callado and cl.tipo ~= "ruta" then print("   " .. ORO .. L("COMO LLEGAR: ", "HOW TO GET THERE: ") .. "|r" .. cl.texto) end
  pcall(actualizarVentana, true)
  pcall(dibujar)
  if WowF.panelActualizar then pcall(WowF.panelActualizar) end
  return true
end

-- Avanzar sola: al aceptar o entregar un paso de la linea en curso
local function avanzar(evento, id)
  if not linea or not id then return end
  local q = linea.q
  local esPaso = false
  for _, p in ipairs(q.cadena) do if p.i == id then esPaso = true end end
  if id == q.id and evento == "QUEST_ACCEPTED" then
    print(AZUL .. VERDE .. L("linea completa: ya tienes ", "questline done: you now have ") .. "|r" .. BLANCO .. q.n .. "|r" .. VERDE .. (q.mazmorra and (L(". Terminala dentro de ", ". Finish it inside ") .. q.mazmorra.n .. ".|r")
      or (L(". Completala y al entregarla te dan ", ". Complete it; when you turn it in you get ") .. (q.equipo or "?") .. ".|r")))
    quitarLinea()
    if WowF.limpiarRutas then pcall(WowF.limpiarRutas, true) end
    return
  end
  if not esPaso then return end
  if evento == "QUEST_TURNED_IN" then entregadas[id] = true; aceptadas[id] = nil else aceptadas[id] = true end
  local nombreHecha
  for _, p in ipairs(q.cadena) do if p.i == id then nombreHecha = nombreDe(p) end end
  linea.ultima = evento == "QUEST_TURNED_IN" and L("CUMPLIDA: " .. (nombreHecha or "") .. ".", "DONE: " .. (nombreHecha or "") .. ".")
    or L("ACEPTADA: " .. (nombreHecha or "") .. ".", "ACCEPTED: " .. (nombreHecha or "") .. ".")
  if PlaySound then pcall(PlaySound, 878) end
  local st = estadoLinea(q)
  local total = #todas(q)
  if st and st.i then
    local p = st.c[st.i]
    print(AZUL .. VERDE .. (evento == "QUEST_TURNED_IN" and L("mision entregada. ", "quest turned in. ") or L("mision aceptada. ", "quest accepted. ")) .. "|r"
      .. ORO .. L("Ahora, mision " .. st.i .. " de " .. total, "Now, quest " .. st.i .. " of " .. total) .. ":|r " .. queHacer(p, st.estado, mazDe(q)))
    -- 17-oct (CurseForge, SilentCipherX): si pusiste un alfiler a mano (entrenador...), la siguiente mision no lo pisa
    if WowF.alfilerManualVivo and WowF.alfilerManualVivo() then
      print(AZUL .. GRIS .. L("dejo tu alfiler; para ir a la siguiente mision, escribe /wowf linea o haz clic en su marca del mapa.", "your pin stays; to go to the next quest, type /wowf questline or click its map marker.") .. "|r")
      linea.conRuta = false
    else
      WowF.lineaCallada = true
      pcall(rutaAlPaso, q, st)
      WowF.lineaCallada = nil
    end
  else
    -- Las de antes hechas: a por la importante
    print(AZUL .. VERDE .. L("ya hiciste las de antes: ahora ", "earlier quests done: now ") .. "|r" .. L("habla con ", "talk to ") .. ORO .. (q.quien or "?") .. "|r" .. L(" y acepta ", " and accept ") .. BLANCO .. q.n .. "|r"
      .. GRIS .. L(" (mision " .. (#q.cadena + 1) .. " de " .. total .. ", la importante: ", " (quest " .. (#q.cadena + 1) .. " of " .. total .. ", the key one: ") .. premio(q, mazDe(q)) .. ")|r.")
    linea.fin = true
    if WowF.alfilerManualVivo and WowF.alfilerManualVivo() then
      print(AZUL .. GRIS .. L("dejo tu alfiler; para ir a la siguiente mision, escribe /wowf linea o haz clic en su marca del mapa.", "your pin stays; to go to the next quest, type /wowf questline or click its map marker.") .. "|r")
    elseif q.mazmorra then
      local g = linea.g or { quien = q.quien, m = q.m, x = q.x, y = q.y, q = { q } }
      if WowF.irAMision then pcall(WowF.irAMision, g) end
    elseif q.m and q.m > 0 then
      -- Mision de equipo: ruta al NPC (o al objeto) que la da
      WowF.lineaCallada = true
      pcall(rutaAlPaso, q)
      WowF.lineaCallada = nil
    end
  end
  pcall(actualizarVentana, true)
  pcall(dibujar)
end
WowF._avanzarLinea = avanzar -- para las pruebas
WowF._olvidarLinea = function() entregadas, aceptadas = {}, {} end -- para las pruebas

local vigia = CreateFrame("Frame")
-- ----- Sobre el NPC que toca: estrella (sin grupo) e icono en su placa de nombre -----
local function npcAhora()
  if not linea then return nil end
  local d = destinoDe(linea.q, estadoActual())
  if not d or not d.n then return nil end
  return d.n, d.k, #todas(linea.q)
end
local function nombreUnidad(u)
  local ok, n = pcall(UnitName, u)
  n = ok and seguro(n)
  return type(n) == "string" and n or nil
end
local function enGrupo()
  local ok, r = pcall(IsInGroup)
  return ok and seguro(r) == true
end
-- 6-oct: SetRaidTarget esta reservado a Blizzard en este cliente (sale "blocked from an action only available to the Blizzard UI"): no se usa
local function estrella(u) end
local marcasPlaca = {}
-- 11-oct (FLG-ERR SetPreferredGamepadInteractTarget, jugador con mando): con el mando activo el juego elige el objetivo
-- con las placas de nombre; no se cambian sus CVars ni se cuelga nada de ellas (marcos propios, solo anclados)
local function conMando() return WowF.interfazMando() end -- 22-oct: mando conectado de verdad (wowF_Estilo.lua)
local function revisarPlaca(u)
  if WowF.mandoActivo and WowF.mandoActivo() then for _, mm in pairs(marcasPlaca) do mm:Hide() end; return end -- 14-oct: con mando, nada sobre las placas
  local placa = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(u)
  if not placa then return end
  -- 6-oct: la marca la pone wowF_MarcaNPC (la misma para mazmorra, linea y equipo, con brillo que late)
  if WowF.marcaNPCRefrescar then if marcasPlaca[placa] then marcasPlaca[placa]:Hide() end; return end
  local n, k, total = npcAhora()
  local m = marcasPlaca[placa]
  if not n or nombreUnidad(u) ~= n then if m then m:Hide() end; return end
  if not m then
    if placa.IsForbidden and placa:IsForbidden() == true then return end
    m = CreateFrame("Frame", nil, UIParent)
    m:SetSize(22, 22)
    m:SetPoint("BOTTOM", placa, "TOP", 0, 34)
    m:SetFrameStrata("HIGH")
    m.icono = m:CreateTexture(nil, "ARTWORK")
    m.icono:SetAllPoints()
    m.icono:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
    m.texto = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    m.texto:SetPoint("BOTTOM", m, "TOP", 0, 1)
    marcasPlaca[placa] = m
  end
  m.texto:SetText(ORO .. L("LINEA " .. k .. "/" .. total, "QUESTLINE " .. k .. "/" .. total) .. "|r")
  m:Show()
end
local function revisarPlacas()
  for _, m in pairs(marcasPlaca) do m:Hide() end
  if not linea or not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
  for _, placa in pairs(C_NamePlate.GetNamePlates() or {}) do
    if placa.namePlateUnitToken then pcall(revisarPlaca, placa.namePlateUnitToken) end
  end
end
-- Placas de NPC amistosos: se encienden al seguir una linea (guardando como estaban) y vuelven igual al quitarla
local function cvar(n) local ok, v = pcall(GetCVar, n); return ok and v or nil end
placasLinea = function(encender)
  if WowF.marcaNPCRefrescar then pcall(WowF.marcaNPCRefrescar); return end -- 6-oct: las lleva wowF_MarcaNPC
  if not SetCVar then return end
  if InCombatLockdown and InCombatLockdown() then return end -- en combate el juego lo bloquea
  if encender then
    if conMando() then return end
    if WowFExportarDB.placasLinea or cvar("nameplateShowFriendlyNPCs") == "1" then return end
    WowFExportarDB.placasLinea = { amigos = cvar("nameplateShowFriends") or "0", npc = cvar("nameplateShowFriendlyNPCs") or "0" }
    pcall(SetCVar, "nameplateShowFriends", "1")
    pcall(SetCVar, "nameplateShowFriendlyNPCs", "1")
    print(AZUL .. L("encendi los nombres de los NPC amistosos para marcar con un icono al que te toca en la linea. Vuelven como estaban al quitar la linea.",
      "I turned on friendly NPC nameplates to mark the questline NPC with an icon. They go back as they were when you remove the questline."))
  else
    local a = WowFExportarDB.placasLinea
    if not a then return end
    pcall(SetCVar, "nameplateShowFriendlyNPCs", a.npc or "0")
    pcall(SetCVar, "nameplateShowFriends", a.amigos or "0")
    WowFExportarDB.placasLinea = nil
  end
  pcall(revisarPlacas)
end
WowF._lineaNPC = npcAhora -- para las pruebas
local ultimoLog = 0
for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "PLAYER_LOGIN", "ZONE_CHANGED_NEW_AREA", "QUEST_LOG_UPDATE", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED" }) do pcall(vigia.RegisterEvent, vigia, e) end
vigia:SetScript("OnEvent", function(_, evento, a, b)
  if evento == "ZONE_CHANGED_NEW_AREA" then pcall(alCambiarZona); return end
  if not linea and evento ~= "PLAYER_LOGIN" then return end
  if evento == "NAME_PLATE_UNIT_ADDED" then pcall(revisarPlaca, a); return end
  if evento == "NAME_PLATE_UNIT_REMOVED" then
    local placa = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(a)
    if placa and marcasPlaca[placa] then marcasPlaca[placa]:Hide() end
    return
  end
  if evento == "UPDATE_MOUSEOVER_UNIT" then pcall(estrella, "mouseover"); return end
  if evento == "PLAYER_TARGET_CHANGED" then pcall(estrella, "target"); return end
  if evento == "QUEST_LOG_UPDATE" then
    -- objetivos hechos = "ya esta completa: entregala" (como mucho una vez por segundo)
    local t = GetTime and GetTime() or 0
    if t - ultimoLog >= 1 then ultimoLog = t; WowF.lineaRefrescar() end
    return
  end
  if evento == "PLAYER_LOGIN" then
    -- Tras /reload: la linea que quedo guardada vuelve (ventana y mapa; la ruta la retoma wowF_Viaje)
    if WowFExportarDB.linea then
      local q = buscar(WowFExportarDB.linea)
      local st = q and estadoLinea(q)
      if st and st.i then linea = { q = q }
      elseif st and not hecha(q.id) and not enElDiario(q.id) then linea = { q = q, fin = true }
      else WowFExportarDB.linea = nil; WowFExportarDB.lineaEquipo = nil end
      if linea then pcall(actualizarVentana, true) end
    end
    return
  end
  -- QUEST_ACCEPTED: (indice, id) en el cliente clasico, (id) en el moderno; QUEST_TURNED_IN: (id, xp, dinero)
  local id = a
  if evento == "QUEST_ACCEPTED" and b and type(b) == "number" and b > 0 then id = b end
  id = tonumber(seguro(id))
  pcall(avanzar, evento, id)
  pcall(revisarPlacas)
end)

-- Limpiar el mapa tambien quita la linea
local limpiarAntes = WowF.limpiarRutas
if limpiarAntes then
  WowF.limpiarRutas = function(...)
    if linea then quitarLinea() end
    return limpiarAntes(...)
  end
end
if WorldMapFrame then
  if WorldMapFrame.OnMapChanged then pcall(hooksecurefunc, WorldMapFrame, "OnMapChanged", function() pcall(dibujar) end) end
  WorldMapFrame:HookScript("OnShow", function() pcall(dibujar) end)
end

-- /wowf linea (o questline): vuelve a abrir la ventana de la linea en curso
local ordenAnterior = SlashCmdList and SlashCmdList["WOWF"]
if SlashCmdList then
  SlashCmdList["WOWF"] = function(msg, ...)
    local c = ((msg or ""):lower()):match("^%s*(.-)%s*$")
    if c == "linea" or c == "questline" then WowF.abrirLinea(); return end
    if ordenAnterior then return ordenAnterior(msg, ...) end
  end
end
