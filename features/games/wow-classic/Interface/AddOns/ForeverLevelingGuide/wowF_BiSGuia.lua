-- wowF BiS 30 (7-oct-2026): lo mejor de tu clase y rama a nivel 30 (BiS) y lo que llevar antes (pre-BiS), de TU faccion.
-- Datos: wowF_BiS.lua (generado por herramientas/generar-bis.js desde foreverchanges.pro, lista temprana de la beta).
-- Por hueco: la BiS, si ya la llevas, como se consigue y el pre-BiS. Clic = ruta (wowF_Viaje) o alfiler al sitio:
-- mision -> el NPC que la da; jefe / mazmorra -> la entrada; raro / vendedor -> su sitio; profesion -> el entrenador.
-- Lo no confirmado sale en naranja. Nada de la otra faccion. 10-oct (4.22): seccion Mascota para Hunter y Warlock (seccionMascota). Se abre con /wowf bis y con el boton "BiS 30" del Libro.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function Y(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end
local ORO, VERDE, GRIS, BLANCO, NARANJA, CELESTE = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933", "|cff66ccff"
local AZUL = "|cff33ccffForever Guide|r: "
local CALIDAD = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }
local FUENTE = "foreverchanges.pro"
local NIVEL_BIS = 30

-- Ranuras del personaje por hueco (GetInventoryItemID)
local RANURAS = {
  ["Head"] = { 1 }, ["Neck"] = { 2 }, ["Shoulder"] = { 3 }, ["Back"] = { 15 }, ["Chest"] = { 5 }, ["Wrist"] = { 9 }, ["Hands"] = { 10 },
  ["Waist"] = { 6 }, ["Legs"] = { 7 }, ["Feet"] = { 8 }, ["Finger 1"] = { 11, 12 }, ["Finger 2"] = { 11, 12 }, ["Trinket 1"] = { 13, 14 },
  ["Trinket 2"] = { 13, 14 }, ["Two-Hand"] = { 16 }, ["Main Hand"] = { 16 }, ["Off Hand"] = { 17 }, ["Shield"] = { 17 },
  ["Held In Off-hand"] = { 17 }, ["Ranged"] = { 18 }, ["Relic"] = { 18 },
}
WowF.BIS_RANURAS = RANURAS

local function miFac()
  local f = WowF.llamar and WowF.llamar(UnitFactionGroup, "player") or (UnitFactionGroup and UnitFactionGroup("player"))
  return f == "Horde" and "H" or "A"
end
local function otraFac(f) return f == "H" and "A" or "H" end
local function nombreFac(f) return f == "H" and "Horde" or "Alliance" end
local function nivelPj() return tonumber(WowF.llamar and WowF.llamar(UnitLevel, "player") or (UnitLevel and UnitLevel("player"))) or 1 end

-- Mazmorra de WowFMazmorras por nombre (la de tu faccion; 0 = las dos)
local function buscarMazmorra(nombre)
  if not nombre then return nil end
  local fac = miFac() == "H" and 1 or 2
  for _, m in ipairs(WowFMazmorras or {}) do if m.n == nombre and (m.f == 0 or m.f == fac) then return m end end
  return nil
end
local function mazmorraDeOtraFaccion(nombre)
  if not nombre then return false end
  local hay, mia = false, false
  local fac = miFac() == "H" and 1 or 2
  for _, m in ipairs(WowFMazmorras or {}) do
    if m.n == nombre then hay = true; if m.f == 0 or m.f == fac then mia = true end end
  end
  return hay and not mia
end

-- Pieza que te sirve: nunca de la otra faccion (ni por la pieza ni por su mazmorra)
local function esMia(pz)
  if type(pz) ~= "table" then return false end
  local fac = miFac()
  if pz.f and pz.f ~= fac then return false end
  if pz.mz and mazmorraDeOtraFaccion(pz.mz) then return false end
  return true
end
WowF.bisEsMia = esMia

-- La rama que tendras a nivel 30: en las mixtas, si cambias despues del 30, la de subir
function WowF.bisRama(p)
  -- 11-oct: "Ver como" (wowF_Caza.lua) = la lista de otra clase y rama, sin tocar tu personaje
  local vc = WowF.verComoActivo and WowF.verComoActivo()
  if vc then return vc.clase .. "|" .. vc.rama, vc.rama, false, vc.rama, 0 end
  p = p or (WowF.armarPlan and WowF.armarPlan())
  if type(p) ~= "table" then return nil end
  local clase = select(2, UnitClass("player"))
  if not clase then return nil end
  local final, subir, cambio = p.ramaNombre or p.rama, p.ramaSubir or "", tonumber(p.ramaCambio) or 0
  local rama, porSubir = final, false
  if subir ~= "" and cambio > NIVEL_BIS then rama, porSubir = subir, true end
  local clave = clase .. "|" .. tostring(rama)
  if not (WowFBiS and WowFBiS[clave]) and porSubir then -- sin lista para la de subir: la final
    local otra = clase .. "|" .. tostring(final)
    if WowFBiS and WowFBiS[otra] then clave, rama, porSubir = otra, final, false end
  end
  return clave, rama, porSubir, final, cambio
end

local function llevaPuesto(hueco, id)
  if not id or not GetInventoryItemID then return false end
  for _, s in ipairs(RANURAS[hueco] or {}) do
    local ok, v = pcall(GetInventoryItemID, "player", s)
    if ok and v and (not issecretvalue or not issecretvalue(v)) and tonumber(v) == id then return true end
  end
  return false
end

-- Lista de tu rama: { clave, rama, meta, huecos = { { hueco, bis, sinBis, prebis = {...}, prop, llevas } } }
function WowF.bisDe(p)
  local clave, rama, porSubir, final, cambio = WowF.bisRama(p)
  if not clave then return nil end
  local datos = WowFBiS and WowFBiS[clave]
  local res = { clave = clave, rama = rama, porSubir = porSubir, final = final, cambio = cambio, faccion = miFac(), huecos = {} }
  if not datos then return res end
  res.meta = datos._meta or {}
  local fac = res.faccion
  for _, h in ipairs(WowFBiSOrden or {}) do
    local e = datos[h]
    if e then
      local bis = (fac == "H" and e.bisHorde) or e.bis
      local sinBis = false
      if bis and not esMia(bis) then bis, sinBis = nil, true end
      local pre, vistos = {}, {}
      if bis then vistos[bis.id] = true end
      for _, pz in ipairs(e.prebis or {}) do
        if esMia(pz) and not vistos[pz.id] then vistos[pz.id] = true; table.insert(pre, pz) end
      end
      local fila = { hueco = h, bis = bis, sinBis = sinBis, prebis = pre, prop = e.prop, llevas = bis and llevaPuesto(h, bis.id) or false }
      -- 7-oct: tienes = la BiS ya es tuya en otra ranura, en las bolsas o en el banco ({ donde, texto }; nil = no la tienes)
      -- llevas = tambien puesta en OTRA ranura (la One-Hand en la otra mano, el otro anillo): "(la llevas)"
      if bis and not fila.llevas and WowF.yaLaTienes then
        local ya = WowF.yaLaTienes(bis.id)
        if ya and ya.donde == "puesta" then fila.llevas = true else fila.tienes = ya end
      end
      for _, pz in ipairs(pre) do if llevaPuesto(h, pz.id) then fila.llevasPre = pz end end
      table.insert(res.huecos, fila)
    end
  end
  return res
end

-- ----- Textos de una pieza -----
local function sinConfirmar(pz) return pz.ok == false or pz.bs == true end
local function textoSinConfirmar()
  return L("sin confirmar: se actualizará en próximas actualizaciones", "not confirmed: it will be updated in future updates")
end
-- Como se consigue, en el idioma del juego
local function como(pz)
  if not WowF.enIngles or not WowF.enIngles() then return pz.c or "" end
  local ce = pz.ce or ""
  if pz.t == "profesion" then return "Crafted with " .. ce end
  if pz.t == "jefe" then return "Dropped by " .. ce end
  return ce
end
local function notas(pz) return L(pz.no, pz.ne) end
local function porque(pz) return L(pz.por, pz.pe) end
local function nombreColor(pz) return (CALIDAD[pz.q or 1] or BLANCO) .. (pz.n or "?") .. "|r" end
local function icono(id) -- 12-oct: cliente primero, luego WowFDatos.obj del mismo id
  return (WowF.iconoObjeto and WowF.iconoObjeto(id)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
WowF.bisComo = como

-- 8-oct (Andy: "decirle al level que puedes ir a hacerla. Esto es muy importante"): nivel minimo para aceptar la mision de la pieza
-- (ds = "Requires level" de Wowhead /forever). Sin dato: aviso + se actualizara. AUN NO si todavia no llegas (como las de mazmorra de la 4.8).
function WowF.bisTextoNivel(ds)
  if not ds then return NARANJA .. L("nivel mínimo aún sin confirmar: se actualizará en próximas actualizaciones", "minimum level not confirmed yet: it will be updated in future updates") .. "|r" end
  local nv = nivelPj()
  if nv < ds then return NARANJA .. L("AÚN NO: desde nivel " .. ds .. " (eres nivel " .. nv .. ")", "NOT YET: from level " .. ds .. " (you are level " .. nv .. ")") .. "|r" end
  return VERDE .. L("desde nivel " .. ds .. ": ya puedes hacerla", "from level " .. ds .. ": you can do it now") .. "|r"
end
-- La mision de la pieza para tu faccion { mn, ds, li }: la de la guia (con su version de Wowhead) o la primera de Wowhead de tu faccion
local function misionPieza(pz)
  local mia
  for _, q in ipairs(pz.qs or {}) do
    if not q.f or q.f == miFac() then
      if pz.mi and q.mi == pz.mi then return { mn = q.mn or pz.mn, ds = q.ds or pz.ds, li = pz.li or q.li } end
      mia = mia or q
    end
  end
  if pz.mi then return { mn = pz.mn, ds = pz.ds, li = pz.li } end
  if mia then return { mn = mia.mn, ds = mia.ds, li = mia.li } end
  return nil
end
WowF.bisMisionPieza = misionPieza
-- Linea para la fila (Libro y Equipo): 'Mision "X": desde nivel N' (+ cuantas misiones tiene la linea)
function WowF.bisNivelMision(pz)
  local q = type(pz) == "table" and misionPieza(pz)
  if not q then return nil end
  local t = GRIS .. L("Misión \"", "Quest \"") .. (q.mn or "?") .. "\":|r " .. WowF.bisTextoNivel(q.ds)
  if type(q.li) == "table" and #q.li > 0 then t = t .. GRIS .. L(" · línea de " .. (#q.li + 1) .. " misiones", " · questline of " .. (#q.li + 1) .. " quests") .. "|r" end
  return t
end

-- Linea de estado: ya la llevas / desde nivel N / sin confirmar
local function lineasPieza(pz, llevas, nivel)
  local t = {}
  table.insert(t, GRIS .. como(pz) .. "|r")
  local n = notas(pz)
  if n and n ~= "" then table.insert(t, GRIS .. n .. "|r") end
  local nm = (not llevas) and WowF.bisNivelMision(pz)
  if nm then table.insert(t, nm) end
  local tienes = (not llevas) and WowF.yaLaTienes and WowF.yaLaTienes(pz.id) or nil
  if llevas then table.insert(t, VERDE .. L("Ya la llevas puesta.", "You already wear it.") .. "|r")
  elseif tienes and tienes.donde == "puesta" then
    table.insert(t, VERDE .. WowF.yaTraducido((tienes.texto:gsub("^%l", string.upper)) .. ".") .. "|r")
  elseif tienes and tienes.donde == "bolsas" then table.insert(t, VERDE .. L("Ya la tienes en las bolsas: póntela.", "You already have it in your bags: equip it.") .. "|r")
  elseif tienes and tienes.donde == "banco" then table.insert(t, VERDE .. L("Ya la tienes en el banco: sácala y póntela.", "You already have it in your bank: take it out and equip it.") .. "|r")
  elseif pz.nv and pz.nv > nivel then table.insert(t, GRIS .. L("Se puede llevar desde el nivel " .. pz.nv .. ".", "Can be worn from level " .. pz.nv .. ".") .. "|r") end
  if sinConfirmar(pz) then table.insert(t, NARANJA .. textoSinConfirmar() .. "|r") end
  if pz.sdat then table.insert(t, NARANJA .. L("Nivel, tipo y estadísticas: aún no hay datos de WoW Forever; pendiente de actualizar.", "Level, type and stats: no WoW Forever data yet; pending update.") .. "|r") end
  local yaDicho = n and (n:lower():find("quien la fabrica", 1, true) or n:lower():find("only its maker", 1, true))
  if pz.sf and not yaDicho then table.insert(t, NARANJA .. L("Solo la puede llevar quien la fabrica.", "Only its maker can wear it.") .. "|r") end
  return table.concat(t, "\n")
end
WowF.bisLineasPieza = lineasPieza

-- ----- Clic: ruta o alfiler -----
local function alfiler(m, x, y)
  if not (m and x and y) then return false end
  local puesto = false
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    puesto = pcall(function()
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(m, x / 100, y / 100))
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end)
  end
  return puesto
end
local function decir(es, en) print(Y(AZUL .. L(es, en))) end

-- Entrenador de la profesion de tu faccion que ensena el rango que pide (el de tu mapa primero)
local function entrenadorDe(prof, rango)
  local D = WowFDatos
  if not (D and D.entrenadores and D.prof and prof) then return nil end
  local id
  for k, v in pairs(D.prof) do if v == prof then id = k end end
  if not id then return nil end
  local fac = miFac()
  local mapa = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local primero, aqui
  for _, e in ipairs(D.entrenadores[id] or {}) do
    if (e[5] == fac or e[5] == "N") and (tonumber(e[6]) or 0) >= (tonumber(rango) or 1) and not (WowF.esAproximado and WowF.esAproximado(e)) then -- 9-oct: sin posiciones de Classic
      primero = primero or e
      if e[2] == mapa then aqui = aqui or e end
    end
  end
  return aqui or primero, id
end

-- 8-oct (Andy: "cada pieza, con un clic, que abra el mapa y explique como conseguirla"): sitios de herramientas/fuente/bis-sitios.json
-- (completar-bis-sitios.mjs, Wowhead /forever). Nada inventado: sin dato, aviso + "se actualizara en proximas actualizaciones".
local SE_ACTUALIZARA_ES, SE_ACTUALIZARA_EN = "se actualizará en próximas actualizaciones", "it will be updated in future updates"
local function facNum() return miFac() == "H" and 2 or 1 end
-- Reaccion del bicho / vendedor con tu faccion (-1 hostil, 0 neutral, 1 amistoso; nil = Wowhead no lo dice)
local function reaccion(e) if miFac() == "H" then return e.rh end return e.ra end
local function zonaOk(m) return not (WowF._zonaPermitidaMobs and m and not WowF._zonaPermitidaMobs(m, facNum())) end
-- El sitio mas cercano de una lista ({ m, x, y }): por el costo de viaje desde tu zona; si no se sabe, el primero
local function masCerca(lista)
  local aqui = WowF.zonaActual and WowF.zonaActual()
  local mejor, mejorC
  for i, e in ipairs(lista) do
    local c = (aqui and WowF.costoViaje and WowF.costoViaje(aqui, e.m)) or (100 + i)
    if not mejorC or c < mejorC then mejor, mejorC = e, c end
  end
  return mejor
end
local function ruta(destino)
  if WowF.viajeA then
    local ok, hecho = pcall(WowF.viajeA, destino, { dibujar = true })
    if ok and hecho then return true end
  end
  return alfiler(destino.m, destino.x, destino.y)
end
WowF._bisMasCerca = masCerca -- para las pruebas

-- Misiones que dan la pieza y te sirven (tu faccion): la de la guia (m, x, y) y las de Wowhead (qs)
local function misionesDe(pz)
  local r = {}
  if pz.t == "mision" and pz.m and pz.x and pz.y and not pz.d then
    table.insert(r, { mi = pz.mi, mn = pz.mn, npc = pz.npc, m = pz.m, x = pz.x, y = pz.y, z = pz.z, li = pz.li, ds = pz.ds })
  end
  for _, q in ipairs(pz.qs or {}) do
    local repe = false
    for _, o in ipairs(r) do if o.mi == q.mi then repe = true end end
    if not repe and (not q.f or q.f == miFac()) then table.insert(r, q) end
  end
  return r
end
WowF._bisMisiones = misionesDe -- para las pruebas
local function otraFaccionSolo(pz)
  if not pz.qs or #pz.qs == 0 then return false end
  for _, q in ipairs(pz.qs) do if not q.f or q.f == miFac() then return false end end
  return true
end

-- Linea de misiones (wowF_LineaMisiones, la misma ventana que usa Equipo): true si quedan pasos de antes y se arranco la guia
local function irLinea(q, item)
  if type(q.li) ~= "table" or not (WowF.estadoLinea and WowF.irALinea) then return false end
  local lq = { id = q.mi, n = q.mn or "?", quien = q.npc, m = q.m or 0, x = q.x or 0, y = q.y or 0, dentro = false, cadena = q.li, equipo = item }
  local st = WowF.estadoLinea(lq)
  if not st or not st.i then return false end
  local n = #st.c - st.i + 1
  decir(ORO .. "LÍNEA DE MISIONES|r: para conseguir " .. item .. ", antes haz " .. n .. (n == 1 and " misión" or " misiones seguidas") .. " (cada una abre la siguiente; \"" .. (q.mn or "?") .. "\" es la parte " .. (q.li.pa or "?") .. " de " .. (q.li.de or "?") .. "). Te guío paso a paso: ventana de la línea y ruta en el mapa.",
    ORO .. "QUESTLINE|r: to get " .. item .. ", first do " .. n .. (n == 1 and " quest" or " quests in a row") .. " (each one unlocks the next; \"" .. (q.mn or "?") .. "\" is part " .. (q.li.pa or "?") .. " of " .. (q.li.de or "?") .. "). I will guide you step by step: questline window and route on the map.")
  -- 8-oct (Andy: "decirle al level que puedes ir a hacerla"): cada paso con su nivel minimo; AUN NO si todavia no llegas
  local nv = nivelPj()
  local function nivelPaso(p, ds, sinConf)
    if not ds or ds == 0 or sinConf then return NARANJA .. L("nivel sin confirmar", "level not confirmed") .. "|r" end
    if nv < ds then return NARANJA .. L("AÚN NO: desde nivel " .. ds, "NOT YET: from level " .. ds) .. "|r" end
    return VERDE .. L("desde nivel " .. ds, "from level " .. ds) .. "|r"
  end
  local total = #st.c + 1
  for k = st.i, #st.c do
    local p = st.c[k]
    if k - st.i < 8 then
      print(Y("   " .. ORO .. k .. "/" .. total .. "|r " .. (p.n ~= "" and p.n or "?") .. (p.q and p.q ~= "" and (GRIS .. L(" (te la da ", " (from ") .. p.q .. ")|r") or "") .. " - " .. nivelPaso(p, p.l, p.lx)))
    end
  end
  print(Y("   " .. ORO .. total .. "/" .. total .. "|r " .. (q.mn or "?") .. GRIS .. L(" (te da ", " (gives ") .. item .. ")|r - " .. nivelPaso(nil, q.ds)))
  local ok, hecho = pcall(WowF.irALinea, lq)
  return ok and hecho
end

-- Ruta a quien da la mision (o a quien se entrega, si Wowhead no dice quien la da)
local function irMision(q, item)
  if irLinea(q, item) then return true end
  local quien, mision = q.npc or "?", q.mn or "?"
  local donde = q.z and (" (" .. q.z .. ")") or ""
  local nivel = ""
  if q.en then
    decir("para conseguir " .. item .. ": misión \"" .. mision .. "\"" .. nivel .. ". Wowhead no dice quién la da (suele empezar con un objeto que te cae); se ENTREGA a " .. quien .. donde .. ". Te llevo allí. Quién la da: " .. SE_ACTUALIZARA_ES .. ".",
      "to get " .. item .. ": quest \"" .. mision .. "\"" .. nivel .. ". Wowhead does not say who gives it (it usually starts from an item that drops); you TURN IT IN to " .. quien .. donde .. ". Taking you there. Who gives it: " .. SE_ACTUALIZARA_EN .. ".")
  else
    decir("para conseguir " .. item .. ", acepta la misión \"" .. mision .. "\" de " .. quien .. donde .. nivel .. " y complétala" .. (q.fn and (" (se entrega a " .. q.fn .. ")") or "") .. ".",
      "to get " .. item .. ", accept the quest \"" .. mision .. "\" from " .. quien .. donde .. nivel .. " and complete it" .. (q.fn and (" (turn it in to " .. q.fn .. ")") or "") .. ".")
  end
  decir(L("Misión \"", "Quest \"") .. mision .. "\": " .. WowF.bisTextoNivel(q.ds), L("Misión \"", "Quest \"") .. mision .. "\": " .. WowF.bisTextoNivel(q.ds))
  local hablar = q.en and L("Habla con " .. quien .. ": a él se entrega \"" .. mision .. "\"", "Talk to " .. quien .. ": you turn in \"" .. mision .. "\" here")
    or L("Habla con " .. quien .. " y acepta \"" .. mision .. "\"", "Talk to " .. quien .. " and accept \"" .. mision .. "\"")
  local destino = { m = q.m, x = q.x, y = q.y, n = Y(quien .. " (" .. L("misión: ", "quest: ") .. mision .. ")") }
  destino.final = { texto = Y(hablar), titulo = quien, corto = quien, detalle = Y(L("Te da " .. item .. ".", "It gives you " .. item .. ".")),
    llegada = Y(hablar .. "."), npc = q.npc, qid = q.mi }
  if q.npc and WowF.marcarNPC then pcall(WowF.marcarNPC, { n = q.npc, qid = q.mi, sub = "|cffffd100" .. Y("BiS 30: " .. item) .. "|r" }) end
  if ruta(destino) then return true end
  return false
end

-- Botin generico del mundo: el area (WowFMobs, la misma de wowF_AreaMobs) con mas bichos de nivel a-b que tu faccion puede atacar, la mas cercana
local function areaDeNivel(a, b)
  local d = WowFMobs
  if not (d and d.areas and d.npc) then return nil end
  local aqui = WowF.zonaActual and WowF.zonaActual()
  local mejor, mejorP
  for _, ar in ipairs(d.areas) do
    if zonaOk(ar[1]) then
      local peso, bichos = 0, {}
      for _, c in ipairs(ar[6] or {}) do
        local n = d.npc[c[1]]
        if n and n[2] <= b and n[3] >= a then
          local reac = (facNum() == 2) and n[5] or n[4]
          if reac <= 0 then peso = peso + c[2]; table.insert(bichos, n[1] .. " (" .. L("nv ", "lvl ") .. (n[2] == n[3] and n[2] or (n[2] .. "-" .. n[3])) .. ")") end
        end
      end
      if peso >= 10 then
        local costo = (aqui and WowF.costoViaje and WowF.costoViaje(aqui, ar[1])) or 20
        local p = peso / (1 + costo)
        if not mejorP or p > mejorP then mejor, mejorP = { m = ar[1], x = ar[2], y = ar[3], radio = ar[4], zona = ar[5], bichos = bichos }, p end
      end
    end
  end
  return mejor
end
WowF._bisAreaDeNivel = areaDeNivel -- para las pruebas
local function sufijo(n) return n and n:match(" (of .+)$") end

local function irMundoGenerico(pz, item)
  local g = pz.gen
  local ar = areaDeNivel(g.a, g.b)
  local suf = sufijo(item)
  local base = "botín del mundo" .. (suf and " con sufijo aleatorio" or "") .. ": sale de bichos de nivel " .. g.a .. "-" .. g.b .. " (cualquier tipo, con poca probabilidad)"
    .. (suf and ("; busca la versión \"" .. suf .. "\"") or "") .. ". También en la casa de subastas."
  local baseEn = "world drop" .. (suf and " with a random suffix" or "") .. ": it drops from level " .. g.a .. "-" .. g.b .. " mobs (any type, low chance)"
    .. (suf and ("; look for the \"" .. suf .. "\" version") or "") .. ". Also at the auction house."
  if not ar then
    decir(item .. ": " .. base .. " Aún no tenemos un área de bichos de ese nivel para tu facción: " .. SE_ACTUALIZARA_ES .. ".",
      item .. ": " .. baseEn .. " We do not have a mob area of that level for your faction yet: " .. SE_ACTUALIZARA_EN .. ".")
    return false
  end
  local mata = table.concat(ar.bichos, ", ", 1, math.min(4, #ar.bichos))
  decir(item .. ": " .. base .. " Te llevo al área más cercana con bichos de ese nivel: " .. ar.zona .. " (" .. ar.x .. ", " .. ar.y .. "). Mata: " .. mata .. ".",
    item .. ": " .. baseEn .. " Taking you to the closest area with mobs of that level: " .. ar.zona .. " (" .. ar.x .. ", " .. ar.y .. "). Kill: " .. mata .. ".")
  if g.a > nivelPj() + 2 then
    decir(NARANJA .. "Ojo: son bichos de nivel " .. g.a .. "-" .. g.b .. ", más altos que tú; en grupo o en la casa de subastas es más fácil.|r",
      NARANJA .. "Note: they are level " .. g.a .. "-" .. g.b .. " mobs, higher than you; it is easier in a group or at the auction house.|r")
  end
  local destino = { m = ar.m, x = ar.x, y = ar.y, n = Y(L("Bichos de nivel ", "Level ") .. g.a .. "-" .. g.b .. L("", " mobs") .. " (" .. item .. ")") }
  destino.final = { texto = Y(L("Mata bichos de nivel " .. g.a .. "-" .. g.b .. " por aquí", "Kill level " .. g.a .. "-" .. g.b .. " mobs around here")), titulo = ar.zona, corto = ar.zona,
    detalle = Y(L("Mata: ", "Kill: ") .. mata), llegada = Y(L("Mata bichos de nivel " .. g.a .. "-" .. g.b .. " por aquí: " .. item .. " cae con poca probabilidad.", "Kill level " .. g.a .. "-" .. g.b .. " mobs around here: " .. item .. " drops with a low chance.")) }
  return ruta(destino)
end

-- Bichos concretos (botin del mundo o raro): el sitio mas cercano de tu faccion
local function irBichos(pz, item)
  local sirven, dentro = {}, {}
  for _, b in ipairs(pz.ms or {}) do
    local r = reaccion(b)
    if r ~= 1 then
      if b.m and b.x and b.y and zonaOk(b.m) then table.insert(sirven, b) elseif b.d then table.insert(dentro, b) end
    end
  end
  if #sirven == 0 then return false, dentro end
  local b = masCerca(sirven)
  local otros = {}
  for _, o in ipairs(sirven) do if o ~= b and #otros < 2 then table.insert(otros, o.mob .. " (" .. (o.z or "?") .. ", " .. o.pc .. "%)") end end
  local raro = b.cl == 4 and L(" (bicho RARO: no siempre está)", " (RARE mob: not always there)") or (b.cl == 1 and L(" (élite: mejor en grupo)", " (elite: better in a group)") or "")
  decir(item .. ": lo suelta " .. b.mob .. raro .. ", nivel " .. b.nv .. ", " .. b.pc .. "% de las veces, en " .. (b.z or "?") .. " (" .. b.x .. ", " .. b.y .. "). Te llevo allí." .. (#otros > 0 and (" También: " .. table.concat(otros, "; ") .. ".") or "") .. " También en la casa de subastas si no se liga al recogerlo.",
    item .. ": dropped by " .. b.mob .. raro .. ", level " .. b.nv .. ", " .. b.pc .. "% of the time, in " .. (b.z or "?") .. " (" .. b.x .. ", " .. b.y .. "). Taking you there." .. (#otros > 0 and (" Also: " .. table.concat(otros, "; ") .. ".") or "") .. " Also at the auction house if it does not bind on pickup.")
  local destino = { m = b.m, x = b.x, y = b.y, n = Y(b.mob .. " (" .. item .. ")") }
  destino.final = { texto = Y(L("Mata " .. b.mob .. " por aquí", "Kill " .. b.mob .. " around here")), titulo = b.mob, corto = b.mob,
    detalle = Y(L("Suelta " .. item .. " (" .. b.pc .. "%).", "Drops " .. item .. " (" .. b.pc .. "%).")), llegada = Y(L("Mata " .. b.mob .. " por aquí.", "Kill " .. b.mob .. " around here.")) }
  return ruta(destino), dentro
end

-- Vendedor de tu faccion (no hostil), el mas cercano
local function irVendedor(pz, item)
  local sirven = {}
  for _, v in ipairs(pz.vd or {}) do if reaccion(v) ~= -1 and v.m and zonaOk(v.m) then table.insert(sirven, v) end end
  if #sirven == 0 then return false end
  local v = masCerca(sirven)
  decir(item .. ": lo vende " .. v.npc .. " en " .. (v.z or "?") .. " (" .. v.x .. ", " .. v.y .. "). Te llevo allí.", item .. ": sold by " .. v.npc .. " in " .. (v.z or "?") .. " (" .. v.x .. ", " .. v.y .. "). Taking you there.")
  local destino = { m = v.m, x = v.x, y = v.y, n = Y(v.npc .. " (" .. item .. ")") }
  destino.final = { texto = Y(L("Compra " .. item .. " a " .. v.npc, "Buy " .. item .. " from " .. v.npc)), titulo = v.npc, corto = v.npc, detalle = "", llegada = Y(L("Compra " .. item .. " a " .. v.npc .. ".", "Buy " .. item .. " from " .. v.npc .. ".")), npc = v.npc }
  if WowF.marcarNPC then pcall(WowF.marcarNPC, { n = v.npc, sub = "|cffffd100" .. Y("BiS 30: " .. item) .. "|r" }) end
  return ruta(destino)
end

function WowF.irABiS(pz)
  if type(pz) ~= "table" then return false end
  local item = pz.n or "?"
  if not esMia(pz) then
    decir(item .. " no es de tu facción.", item .. " is not for your faction.")
    return false
  end
  -- 7-oct: ya la tienes (puesta, en las bolsas o en el banco): no hace falta ir a buscarla
  local tienes = WowF.yaLaTienes and WowF.yaLaTienes(pz.id)
  if tienes then
    local donde = (tienes.donde == "bolsas") and { "en las bolsas: póntela", "in your bags: equip it" }
      or (tienes.donde == "banco") and { "en el banco: sácala y póntela", "in your bank: take it out and equip it" } or { "puesta", "equipped" }
    decir("Ya tienes " .. item .. " (" .. donde[1] .. "): no hace falta ir a buscarla.", "You already have " .. item .. " (" .. donde[2] .. "): no need to go get it.")
    return false
  end
  if sinConfirmar(pz) then decir(item .. ": " .. textoSinConfirmar() .. ".", item .. ": " .. textoSinConfirmar() .. ".") end
  -- Mision (la de la guia o las de Wowhead de tu faccion): linea de misiones si hay pasos antes; si no, ruta a quien la da
  local mis = misionesDe(pz)
  local conSitio = {}
  for _, q in ipairs(mis) do if q.m and q.x and q.y then table.insert(conSitio, q) end end
  if #conSitio > 0 then
    if irMision(masCerca(conSitio), item) then return true end
  end
  -- Jefe, bichos de mazmorra o mision de dentro: ruta a la entrada
  local mzNombre = pz.mz
  if not mzNombre then for _, q in ipairs(mis) do if q.mz then mzNombre = q.mz; if not pz.mn then pz = setmetatable({ mn = q.mn, t = "mision" }, { __index = pz }) end break end end end
  local maz = buscarMazmorra(mzNombre)
  if maz then
    if not (maz.m and maz.x and maz.y) then -- 13-oct (Andy): el botín SÍ se sabe; solo falta la entrada. Un solo mensaje claro, sin ruta inventada
      local niv = (maz.d and maz.h) and (" (" .. maz.d .. "-" .. maz.h .. ")") or ""
      local donde = maz.z and (" (está en " .. maz.z .. ")") or ""
      local dondeEN = maz.z and (" (it is in " .. maz.z .. ")") or ""
      local quien = pz.j and ("lo suelta " .. pz.j .. " en ") or ((pz.t == "mision" and pz.mn) and ("la misión \"" .. pz.mn .. "\" se hace en ") or "sale en ")
      local quienEN = pz.j and ("dropped by " .. pz.j .. " in ") or ((pz.t == "mision" and pz.mn) and ("the quest \"" .. pz.mn .. "\" is done in ") or "it drops in ")
      decir(item .. ": " .. quien .. maz.n .. niv .. ", mazmorra de grupo. Sabemos que cae aquí (datos de WoW Forever), pero aún no tenemos la entrada de la mazmorra" .. donde .. "; se actualizará en próximas actualizaciones.",
        item .. ": " .. quienEN .. maz.n .. niv .. ", a group dungeon. We know it drops here (WoW Forever data), but we don't have the dungeon entrance yet" .. dondeEN .. "; it will be updated in future updates.")
      return true
    end
    if pz.j then decir(item .. ": lo suelta " .. pz.j .. " en " .. maz.n .. ". Te llevo a la entrada.", item .. ": dropped by " .. pz.j .. " in " .. maz.n .. ". Taking you to the entrance.")
    elseif pz.t == "mision" or not pz.mz then decir(item .. ": la misión \"" .. (pz.mn or "?") .. "\" se hace en " .. maz.n .. ". Te llevo a la entrada.", item .. ": the quest \"" .. (pz.mn or "?") .. "\" is done in " .. maz.n .. ". Taking you to the entrance.")
    else decir(item .. ": sale en " .. maz.n .. ". Te llevo a la entrada.", item .. ": it drops in " .. maz.n .. ". Taking you to the entrance.") end
    if WowF.irAMazmorra then WowF.irAMazmorra(maz); return true end
    if alfiler(maz.m, maz.x, maz.y) then return true end
  end
  -- Profesion: al entrenador que ensena ese rango
  if pz.t == "profesion" and pz.pr then
    decir(item .. ": " .. (pz.c or "") .. (pz.re and ("; receta: " .. pz.re) or "") .. (pz.no and (". " .. pz.no) or "") .. ".",
      item .. ": crafted with " .. (pz.ce or pz.pr) .. (pz.re and ("; recipe: " .. pz.re) or "") .. (pz.ne and (". " .. pz.ne) or "") .. ".")
    local e = entrenadorDe(pz.pr, pz.r)
    if e then
      decir("te llevo al entrenador de " .. pz.pr .. ": " .. e[1] .. (e[7] and (" (" .. e[7] .. ")") or "") .. ".",
        "taking you to the " .. pz.pr .. " trainer: " .. e[1] .. (e[7] and (" (" .. e[7] .. ")") or "") .. ".")
      local destino = { m = e[2], x = e[3], y = e[4], n = Y(e[1] .. " (" .. pz.pr .. ")") }
      if WowF.viajeA then
        local ok, hecho = pcall(WowF.viajeA, destino, { dibujar = true })
        if ok and hecho then return true end
      end
      if alfiler(e[2], e[3], e[4]) then return true end
    end
    return false
  end
  -- Raro, vendedor, libros... con sitio de la guia: ruta o alfiler al sitio
  if pz.m and pz.x and pz.y then
    decir(item .. ": " .. (pz.c or "") .. ".", item .. ": " .. (pz.ce or "") .. ".")
    local destino = { m = pz.m, x = pz.x, y = pz.y, n = Y((pz.npc or item) .. (pz.z and (" (" .. pz.z .. ")") or "")) }
    if WowF.viajeA then
      local ok, hecho = pcall(WowF.viajeA, destino, { dibujar = true })
      if ok and hecho then return true end
    end
    if alfiler(pz.m, pz.x, pz.y) then decir("alfiler puesto.", "pin placed."); return true end
  end
  -- Vendedor (Wowhead)
  if irVendedor(pz, item) then return true end
  -- Botin generico del mundo (muchos bichos con poca probabilidad): area de bichos de ese nivel; si no, los bichos concretos
  local mejorPc = 0
  for _, b in ipairs(pz.ms or {}) do if (b.pc or 0) > mejorPc then mejorPc = b.pc end end
  if pz.gen and mejorPc < 3 then
    if irMundoGenerico(pz, item) then return true end
  end
  local hecho, dentro = irBichos(pz, item)
  if hecho then return true end
  if pz.gen and mejorPc >= 3 and irMundoGenerico(pz, item) then return true end
  -- Sin sitio en el mapa: todo lo que se sabe y el aviso
  local extraEs, extraEn = {}, {}
  if otraFaccionSolo(pz) then
    table.insert(extraEs, "la misión que la da es solo de la " .. nombreFac(otraFac(miFac())))
    table.insert(extraEn, "the quest that gives it is " .. nombreFac(otraFac(miFac())) .. " only")
  end
  for _, q in ipairs(mis) do
    if not (q.m or q.mz) then
      table.insert(extraEs, "misión \"" .. (q.mn or "?") .. "\"" .. (q.npc and (" de " .. q.npc) or ""))
      table.insert(extraEn, "quest \"" .. (q.mn or "?") .. "\"" .. (q.npc and (" from " .. q.npc) or ""))
    end
  end
  if dentro and #dentro > 0 then
    local t = {}
    for i = 1, math.min(3, #dentro) do table.insert(t, dentro[i].mob .. " (" .. dentro[i].pc .. "%)") end
    table.insert(extraEs, "la sueltan bichos de dentro de una mazmorra: " .. table.concat(t, ", "))
    table.insert(extraEn, "dropped by mobs inside a dungeon: " .. table.concat(t, ", "))
  end
  if pz.ob and #pz.ob > 0 then
    table.insert(extraEs, "también puede salir en cofres (" .. table.concat(pz.ob, ", ") .. ")")
    table.insert(extraEn, "it can also come from chests (" .. table.concat(pz.ob, ", ") .. ")")
  end
  local mas = #extraEs > 0 and (" " .. table.concat(extraEs, "; ") .. ".") or ""
  local masEn = #extraEn > 0 and (" " .. table.concat(extraEn, "; ") .. ".") or ""
  decir(item .. ": " .. (pz.c or "") .. "." .. mas .. " Aún no tiene sitio confirmado en el mapa: " .. SE_ACTUALIZARA_ES .. ".",
    item .. ": " .. (pz.ce or "") .. "." .. masEn .. " It has no confirmed spot on the map yet: " .. SE_ACTUALIZARA_EN .. ".")
  return false
end

-- ----- 10-oct (4.22, Andy: "los Hunter o cualquier clase que necesite un pet, que en la BiS le diga donde conseguir los mejores pets") -----
-- Solo WoW Forever: guias de Wowhead /forever (hunter|warlock/<rama>/level-20|30-dps-overview, overview-pve-dps) y WoWForeverBuilds (PvP).
-- Posiciones: herramientas/descargar-mascotas.mjs (Wowhead /forever) -> fuente/wowhead/mascotas.json. Nada de la otra faccion; sin dato = aviso.
local SIN_DATOS_ES, SIN_DATOS_EN = "aún no hay datos de WoW Forever; se actualizará en próximas actualizaciones", "no WoW Forever data yet; it will be updated in future updates"
local FUENTE_HUNTER = "Wowhead /forever (guide/classes/hunter, level-20 & level-30 overview)"
local FUENTE_WARLOCK = "Wowhead /forever (guide/classes/warlock, level-30 overview) · WoWForeverBuilds (PvP)"
-- Hunter: el mejor al subir = un gato rapido; Wowhead /forever nombra a The Rake (Rare, nivel 10, norte de Mulgore)
local GATO = { id = 5807, n = "The Rake", fam = "Cat", nv = 10, m = 1412, x = 51.1, y = 20.3, zona = "Mulgore" }
-- Hunter: bichos que ensenan Claw (rango 3, 16829) con Beast Training (Wowhead /forever level-20 overview)
local CLAW = {
  { id = 1189, n = "Black Bear Patriarch", fam = "Bear", nv = 16, nv2 = 17, m = 1432, x = 56.0, y = 46.5, zona = "Loch Modan" },
  { id = 1216, n = "Shore Crawler", fam = "Crab", nv = 17, nv2 = 18, m = 1436, x = 29.9, y = 77.1, zona = "Westfall" },
  { id = 6788, n = "Den Mother", fam = "Bear", nv = 18, nv2 = 19, m = 1439, x = 51.5, y = 37.6, zona = "Darkshore" },
  { id = 3812, n = "Clattering Crawler", fam = "Crab", nv = 19, nv2 = 20, m = 1440, x = 12.5, y = 23.7, zona = "Ashenvale" },
}
-- Warlock: la primera mision de cada demonio y quien la da (por raza; si no se sabe la raza, el mas cercano de tu faccion)
local QV = {
  Human = { q = 1685, mision = "Gakin's Summons", npc = "Remen Marcot", m = 1429, x = 44.4, y = 66.2, zona = "Elwynn Forest" },
  Gnome = { q = 1715, mision = "The Slaughtered Lamb", npc = "Lago Blackwrench", m = 1455, x = 47.7, y = 9.9, zona = "Ironforge" },
  Orc = { q = 1506, mision = "Gan'rul's Summons", npc = "Ophek", m = 1411, x = 54.2, y = 41.2, zona = "Durotar" },
  Scourge = { q = 1478, mision = "Halgar's Summons", npc = "Ageron Kargal", m = 1420, x = 61.6, y = 52.5, zona = "Tirisfal Glades" },
}
QV.Troll = QV.Orc
local GAKIN = { npc = "Gakin the Darkbinder", m = 1453, x = 41.5, y = 86.1, zona = "Stormwind City", f = "A" }
local GANRUL = { npc = "Gan'rul Bloodeye", m = 1454, x = 48.2, y = 45.5, zona = "Orgrimmar", f = "H" }
local CARENDIN = { npc = "Carendin Halgar", m = 1458, x = 84.9, y = 25.7, zona = "Undercity", f = "H" }
local DEMONIOS = {
  Voidwalker = { nv = 10, hechizo = 697, icono = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker",
    es = "tanque: aguanta los golpes y te da seguridad", en = "tank: soaks the hits and keeps you safe" },
  Succubus = { nv = 20, hechizo = 712, icono = "Interface\\Icons\\Spell_Shadow_SummonSuccubus", mision = "Devourer of Souls",
    sitios = { A = { GAKIN }, H = { GANRUL, CARENDIN } }, q = { A = 1716, Orc = 1507, Troll = 1507, Scourge = 1472 },
    es = "la que más daño hace en la beta (Sayaad)", en = "the highest damage pet in the beta (Sayaad)" },
  Felhunter = { nv = 30, hechizo = 691, icono = "Interface\\Icons\\Spell_Shadow_SummonFelHunter", mision = "Seeking Strahad",
    sitios = { A = { GAKIN }, H = { GANRUL, CARENDIN } }, q = { A = 1798, Orc = 2996, Troll = 2996, Scourge = 3001 },
    es = "quita magia y corta hechizos: el de PvP", en = "dispels magic and interrupts spells: the PvP one" },
}
-- Por rama: PvE (Wowhead /forever level-30) y PvP (WoWForeverBuilds)
local WARLOCK_RAMA = {
  Affliction = { pve = "Succubus", alt = "Voidwalker", pvp = "Felhunter",
    es = "Succubus para ir rápido; Voidwalker si necesitas seguridad.", en = "Succubus for speed; Voidwalker if you need safety.",
    pvpEs = "Felhunter, o Voidwalker con Soul Link.", pvpEn = "Felhunter, or Voidwalker with Soul Link." },
  Demonology = { pve = "Succubus", alt = "Voidwalker", pvp = "Felhunter",
    es = "Succubus: con Demonic Brand (nivel 25) hace daño y aguanta como tanque.", en = "Succubus: with Demonic Brand (level 25) it deals damage and tanks.",
    pvpEs = "Felhunter.", pvpEn = "Felhunter." },
  Destruction = { pve = "Voidwalker", alt = "Succubus", pvp = "Felhunter",
    es = "Voidwalker: lo más seguro para Destruction.", en = "Voidwalker: the safest choice for Destruction.",
    pvpEs = "Felhunter o Succubus.", pvpEn = "Felhunter or Succubus." },
}
local function miRaza()
  local ok, _, token = pcall(UnitRace, "player")
  return ok and token or nil
end
local function sabe(id)
  if IsSpellKnown then local ok, s = pcall(IsSpellKnown, id); if ok and s == true then return true end end
  if IsPlayerSpell then local ok, s = pcall(IsPlayerSpell, id); if ok and s == true then return true end end
  return false
end
local function ramaDe(d, tabla)
  local r = tostring(d and d.rama or "")
  for k, v in pairs(tabla) do if r:find(k, 1, true) then return k, v end end
  return nil
end

-- Hunter: clic en un bicho = ruta a su zona + alfiler en el centro de donde sale + marca sobre el
local function irBicho(b, para)
  decir("ve a " .. b.zona .. " y doma a " .. b.n .. " (" .. b.fam .. ") con Tame Beast. " .. para,
    "go to " .. b.zona .. " and tame " .. b.n .. " (" .. b.fam .. ") with Tame Beast. " .. para)
  local destino = { m = b.m, x = b.x, y = b.y, n = Y(b.n .. " (" .. b.zona .. ")") }
  destino.final = { texto = Y(L("Doma a " .. b.n .. " con Tame Beast", "Tame " .. b.n .. " with Tame Beast")), titulo = b.n, corto = b.n, detalle = "",
    llegada = Y(L("Busca a " .. b.n .. " por esta zona y usa Tame Beast.", "Look for " .. b.n .. " around here and use Tame Beast.")), npc = b.n }
  if WowF.marcarNPC then pcall(WowF.marcarNPC, { n = b.n, npc = b.id, sub = "|cffffd100" .. Y(L("Mascota: domar", "Pet: tame")) .. "|r" }) end
  return ruta(destino)
end
WowF._mascotaIrBicho = irBicho -- para las pruebas

-- Warlock: el NPC que da la mision del demonio (por raza; si no, el mas cercano de tu faccion)
local function sitioDemonio(nombre)
  local dm = DEMONIOS[nombre]
  if not dm then return nil end
  local raza = miRaza()
  if nombre == "Voidwalker" then
    local s = QV[raza or ""]
    if s and ((miFac() == "H") == (s.m == 1411 or s.m == 1420)) then return { npc = s.npc, m = s.m, x = s.x, y = s.y, zona = s.zona, mision = s.mision, q = s.q } end
    -- raza sin mision propia en los datos: no se adivina
    return nil
  end
  local lista = dm.sitios[miFac()] or {}
  local s
  if miFac() == "H" then s = (raza == "Scourge") and CARENDIN or ((raza == "Orc" or raza == "Troll") and GANRUL) or masCerca(lista) else s = lista[1] end
  if not s then return nil end
  return { npc = s.npc, m = s.m, x = s.x, y = s.y, zona = s.zona, mision = dm.mision, q = dm.q[raza or ""] or (miFac() == "A" and dm.q.A) or nil }
end
WowF._mascotaSitioDemonio = sitioDemonio -- para las pruebas
local function irDemonio(nombre)
  local s = sitioDemonio(nombre)
  if not s then
    decir("aún no tengo quién da la misión de " .. nombre .. " para tu raza: " .. SIN_DATOS_ES .. ". Pregúntale a tu entrenador de Warlock.",
      "I do not have who gives the " .. nombre .. " quest for your race yet: " .. SIN_DATOS_EN .. ". Ask your Warlock trainer.")
    return false
  end
  local nv = DEMONIOS[nombre].nv
  decir(nombre .. ": la misión " .. s.mision .. " (desde nivel " .. nv .. ") te la da " .. s.npc .. " en " .. s.zona .. ". Te llevo.",
    nombre .. ": the quest " .. s.mision .. " (from level " .. nv .. ") is given by " .. s.npc .. " in " .. s.zona .. ". I take you there.")
  local destino = { m = s.m, x = s.x, y = s.y, n = Y(s.npc .. " (" .. nombre .. ")") }
  destino.final = { texto = Y(L("Habla con " .. s.npc .. " y acepta " .. s.mision, "Talk to " .. s.npc .. " and accept " .. s.mision)), titulo = s.npc, corto = s.npc, detalle = "",
    llegada = Y(L("Habla con " .. s.npc .. ": su misión te da el " .. nombre .. ".", "Talk to " .. s.npc .. ": the quest gives you the " .. nombre .. ".")), npc = s.npc }
  if WowF.marcarNPC then pcall(WowF.marcarNPC, { n = s.npc, qid = s.q, sub = "|cffffd100" .. Y(L("Mascota: ", "Pet: ") .. nombre) .. "|r" }) end
  return ruta(destino)
end
WowF._mascotaIrDemonio = irDemonio -- para las pruebas

local function seccionMascota(p, d, cab, nota, item)
  local clase = d and d.clave and d.clave:match("^(%u+)|")
  if not clase then local okC, _, tk = pcall(UnitClass, "player"); clase = okC and tk or nil end
  clase = clase and tostring(clase):upper() or ""
  if clase ~= "HUNTER" and clase ~= "WARLOCK" then return end
  local nivel = nivelPj()
  cab(Y(ORO .. L("Mascota: la mejor y dónde conseguirla", "Pet: the best one and where to get it") .. "|r"), nil, { clave = "bis-mascota" })
  if clase == "HUNTER" then
    local rama = ramaDe(d, { ["Beast Mastery"] = 1, Marksmanship = 1, Survival = 1 })
    if nivel < 10 then nota(Y(GRIS .. L("Tu primera mascota llega al nivel 10 (Tame Beast).", "Your first pet comes at level 10 (Tame Beast).") .. "|r")) end
    -- Al subir: un gato rapido
    if miFac() == "H" then
      item({ texto = Y(VERDE .. L("Al subir: ", "Leveling: ") .. "|r" .. ORO .. GATO.n .. "|r (" .. GATO.fam .. ", Rare)"),
        sub = Y(GRIS .. L("La mejor según Wowhead /forever: un gato muy rápido. Nivel " .. GATO.nv .. ", norte de " .. GATO.zona .. ". Con Claw rango 4 (nivel 24). Clic: te llevo.",
          "The best one according to Wowhead /forever: a very fast cat. Level " .. GATO.nv .. ", northern " .. GATO.zona .. ". With Claw rank 4 (level 24). Click: I take you there.") .. "|r"),
        icono = "Interface\\Icons\\Ability_Hunter_Pet_Cat",
        accion = function() return irBicho(GATO, L("Es la mejor mascota para subir.", "It is the best pet to level with.")) end })
    else
      item({ texto = Y(VERDE .. L("Al subir: ", "Leveling: ") .. "|r" .. ORO .. L("un gato rápido", "a fast cat") .. "|r"),
        sub = Y(GRIS .. L("Wowhead /forever recomienda un gato muy rápido.", "Wowhead /forever recommends a very fast cat.") .. "|r\n"
          .. NARANJA .. L("Gato rápido de la Alliance: " .. SIN_DATOS_ES .. ".", "Fast Alliance cat: " .. SIN_DATOS_EN .. ".") .. "|r"),
        icono = "Interface\\Icons\\Ability_Hunter_Pet_Cat" })
    end
    -- Claw: domar uno de estos y aprenderla con Beast Training (luego vuelves a tu gato)
    local claw = {}
    for _, b in ipairs(CLAW) do if zonaOk(b.m) then claw[#claw + 1] = b end end
    if #claw > 0 then
      nota(Y(CELESTE .. L("Para aprender Claw (rango 3): doma uno de estos, aprende Claw con Beast Training y vuelve a tu mascota.",
        "To learn Claw (rank 3): tame one of these, learn Claw with Beast Training and go back to your pet.") .. "|r"))
      for _, b in ipairs(claw) do
        local listo = nivel >= b.nv
        item({ texto = Y(ORO .. b.n .. "|r (" .. b.fam .. ", " .. L("nivel ", "level ") .. b.nv .. "-" .. b.nv2 .. ")"),
          sub = Y(GRIS .. b.zona .. ". " .. (listo and L("Ya lo puedes domar. Clic: te llevo.", "You can tame it now. Click: I take you there.")
            or L("Lo puedes domar desde el nivel " .. b.nv .. ". Clic: te llevo.", "You can tame it from level " .. b.nv .. ". Click: I take you there.")) .. "|r"),
          icono = "Interface\\Icons\\Ability_Druid_Rake", sangria = 20, chico = true,
          accion = function() return irBicho(b, L("Te enseña Claw.", "It teaches Claw.")) end })
      end
    end
    nota(Y(NARANJA .. L("Claw rango 4 (nivel 24): qué bicho la enseña: " .. SIN_DATOS_ES .. ".", "Claw rank 4 (level 24), which beast teaches it: " .. SIN_DATOS_EN .. ".") .. "|r"))
    if rama == "Marksmanship" then
      nota(Y(GRIS .. L("Marksmanship: en mazmorras y bandas, sin mascota (Lone Wolf); al subir, el gato.", "Marksmanship: no pet in dungeons and raids (Lone Wolf); while leveling, the cat.") .. "|r"))
    end
    nota(Y(NARANJA .. L("Ojo (beta): los talentos que suben el daño de la mascota no funcionan bien. Si tras un relog la mascota pierde habilidades o Beast Training dice \"You can't do that\", libérala y doma otra.",
      "Note (beta): talents that raise pet damage are bugged. If after a relog your pet loses abilities or Beast Training says \"You can't do that\", release it and tame another.") .. "|r"))
    nota(Y(GRIS .. L("PvP: la mejor mascota hasta el nivel 30: " .. SIN_DATOS_ES .. ".", "PvP: the best pet up to level 30: " .. SIN_DATOS_EN .. ".") .. "|r"))
    nota(Y(GRIS .. L("Fuente: ", "Source: ") .. FUENTE_HUNTER .. "|r"))
    return
  end
  -- WARLOCK
  local rama, rec = ramaDe(d, WARLOCK_RAMA)
  rec = rec or WARLOCK_RAMA.Affliction
  if rama then nota(Y(GRIS .. rama .. " (PvE): " .. L(rec.es, rec.en) .. "|r")) end
  local orden = { rec.pve, rec.alt }
  if rec.pve ~= "Felhunter" and rec.alt ~= "Felhunter" then orden[#orden + 1] = "Felhunter" end
  for i, nombre in ipairs(orden) do
    local dm = DEMONIOS[nombre]
    local s = sitioDemonio(nombre)
    local tiene = sabe(dm.hechizo)
    local etiqueta = (i == 1 and (VERDE .. L("RECOMENDADO: ", "RECOMMENDED: ")) or (nombre == rec.pvp and (CELESTE .. "PvP: ") or (CELESTE .. L("Alternativa: ", "Alternative: ")))) .. "|r"
    local estado
    if tiene then estado = VERDE .. L("Ya lo tienes.", "You already have it.") .. "|r"
    elseif nivel >= dm.nv then estado = L("Ya puedes hacer su misión.", "You can do its quest now.")
    else estado = L("Su misión es desde el nivel " .. dm.nv .. ".", "Its quest is from level " .. dm.nv .. ".") end
    local donde = s and L("Misión " .. s.mision .. ": la da " .. s.npc .. " (" .. s.zona .. "). Clic: te llevo.", "Quest " .. s.mision .. ": given by " .. s.npc .. " (" .. s.zona .. "). Click: I take you there.")
      or (NARANJA .. L("Quién da la misión para tu raza: " .. SIN_DATOS_ES .. ".", "Who gives the quest for your race: " .. SIN_DATOS_EN .. ".") .. "|r")
    item({ texto = Y(etiqueta .. ORO .. nombre .. "|r (" .. L("nivel ", "level ") .. dm.nv .. ")"),
      sub = Y(GRIS .. L(dm.es, dm.en) .. ". " .. estado .. "|r\n" .. GRIS .. donde .. "|r"), icono = dm.icono,
      accion = function() return irDemonio(nombre) end })
  end
  nota(Y(GRIS .. L("Evita el Imp en cuanto tengas el Voidwalker: hace poco daño y se queda sin maná.", "Avoid the Imp once you have the Voidwalker: it deals little damage and runs out of mana.") .. "|r"))
  nota(Y(CELESTE .. "PvP: " .. L(rec.pvpEs, rec.pvpEn) .. "|r"))
  nota(Y(GRIS .. L("Fuente: ", "Source: ") .. FUENTE_WARLOCK .. "|r"))
end
WowF._bisSeccionMascota = seccionMascota

-- ----- Contenido (pestana "BiS 30" del Libro) -----
function WowF.contenidoBiS(p, cab, nota, item, separador)
  local d = WowF.bisDe(p)
  local nivel = nivelPj()
  if not d then nota(Y(GRIS .. L("Sin datos de tu clase.", "No data for your class.") .. "|r")); return end
  cab(Y(ORO .. L("BiS de nivel " .. NIVEL_BIS .. ": " .. d.rama, "Level " .. NIVEL_BIS .. " BiS: " .. d.rama) .. "|r"))
  nota(Y(NARANJA .. L("Lista de " .. FUENTE .. " (temprana, puede cambiar)", "List from " .. FUENTE .. " (early, it may change)") .. "|r"))
  if d.porSubir then
    nota(Y(GRIS .. L("Subes con " .. d.rama .. " y pasas a " .. tostring(d.final) .. " al nivel " .. d.cambio .. ": a nivel " .. NIVEL_BIS .. " sigues en " .. d.rama .. ", así que esta es su lista.",
      "You level as " .. d.rama .. " and switch to " .. tostring(d.final) .. " at level " .. d.cambio .. ": at level " .. NIVEL_BIS .. " you are still " .. d.rama .. ", so this is its list.") .. "|r"))
  end
  if not d.meta then
    nota(Y(NARANJA .. L("Aún no hay lista para tu rama: se actualizará en próximas actualizaciones.", "There is no list for your spec yet: it will be updated in future updates.") .. "|r"))
    seccionMascota(p, d, cab, nota, item)
    if WowF.seccionConsumibles then WowF.seccionConsumibles(p, cab, nota, item) end -- 10-oct (4.23)
    return
  end
  local m = d.meta
  local aviso = L(m.nota, m.notaEn)
  if aviso and aviso ~= "" then nota(Y(NARANJA .. aviso .. "|r")) end
  nota(Y(GRIS .. L("Solo cosas de la " .. nombreFac(d.faccion) .. ". Clic en una pieza: te llevo a donde se consigue (ruta o alfiler).",
    "Only " .. nombreFac(d.faccion) .. " items. Click an item: I take you to where you get it (route or pin).") .. "|r"))
  local puestas = 0
  for _, f in ipairs(d.huecos) do if f.llevas then puestas = puestas + 1 end end
  nota(Y(VERDE .. L("Llevas " .. puestas .. " de " .. #d.huecos .. " piezas BiS.", "You wear " .. puestas .. " of " .. #d.huecos .. " BiS items.") .. "|r"))
  -- 8-oct (armas): nota de arma de la rama (Feral: el DPS del arma cuenta; Subtlety: la BiS es una Sword)
  local pRama = { clase = (d.clave and d.clave:match("^(%u+)|")) or (p and p.clase), ramaPesos = d.rama }
  local notaArma = WowF.notaArma and WowF.notaArma(pRama)
  if notaArma then nota(Y(NARANJA .. notaArma .. "|r")) end
  for _, f in ipairs(d.huecos) do
    local titulo = ORO .. f.hueco .. "|r"
    if f.prop then titulo = titulo .. "  " .. NARANJA .. L("(propuesta del addon: la guía no trae esta arma)", "(addon proposal: the guide has no weapon here)") .. "|r" end
    cab(Y(titulo))
    if f.bis then
      local pz = f.bis
      local etiqueta = (f.llevas and (VERDE .. L("BiS (la llevas): ", "BiS (you wear it): ")) or (ORO .. "BiS: ")) .. "|r"
      local subBis = lineasPieza(pz, f.llevas, nivel)
      -- 8-oct (armas): la BiS de la guia no cumple la regla de arma de tu rama (velocidad o tipo): se dice por que la pone igual
      local slot = (RANURAS[f.hueco] or {})[1]
      if WowF.ajusteArma and (slot == 16 or slot == 17 or slot == 18) then
        local okA, aj = pcall(WowF.ajusteArma, pz, pRama, slot)
        if okA and type(aj) == "table" and aj.motivo then
          subBis = subBis .. "\n" .. NARANJA .. (aj.prohibido and L("Ojo: " .. aj.motivo .. ".", "Note: " .. aj.motivo .. ".")
            or L("La guía la pone de BiS aunque " .. aj.motivo .. ": suma más daño en total.", "The guide lists it as BiS although " .. aj.motivo .. ": it adds more damage overall.")) .. "|r"
        end
      end
      item({ texto = Y(etiqueta .. nombreColor(pz) .. (sinConfirmar(pz) and (" " .. NARANJA .. "(?)|r") or "")), sub = Y(subBis),
        icono = icono(pz.id), objeto = pz.id, accion = function() WowF.irABiS(pz) end })
    elseif f.sinBis then
      nota(Y(GRIS .. L("La BiS de la guía no es de tu facción: usa lo de abajo.", "The guide's BiS is not for your faction: use the items below.") .. "|r"))
    end
    for i, pz in ipairs(f.prebis) do
      local llevas = f.llevasPre == pz
      local pre = (llevas and (VERDE .. L("Pre-BiS (la llevas): ", "Pre-BiS (you wear it): ")) or (CELESTE .. "Pre-BiS: ")) .. "|r"
      local sub = lineasPieza(pz, llevas, nivel)
      local pq = porque(pz)
      if pq and pq ~= "" then sub = GRIS .. pq .. "|r\n" .. sub end
      item({ texto = Y(pre .. nombreColor(pz) .. (sinConfirmar(pz) and (" " .. NARANJA .. "(?)|r") or "")), sub = Y(sub), icono = icono(pz.id), objeto = pz.id,
        sangria = 20, chico = true, accion = function() WowF.irABiS(pz) end })
    end
  end
  seccionMascota(p, d, cab, nota, item) -- 10-oct (4.22): Hunter y Warlock
  if WowF.seccionConsumibles then WowF.seccionConsumibles(p, cab, nota, item) end -- 10-oct (4.23): consumibles PvE y PvP
  separador()
  nota(Y(GRIS .. L("Fuente: ", "Source: ") .. (m.fuente or FUENTE) .. (m.fuente20 and (" · " .. L("pre-BiS: ", "pre-BiS: ") .. m.fuente20) or "") .. "|r"))
  local av = L(m.aviso, m.avisoEn)
  if av and av ~= "" then nota(Y(GRIS .. av .. "|r")) end
end

-- ===================== 11-oct (rediseño por tarjetas): pestana "BiS 30" (maqueta bis.html aprobada por Andy) =====================
-- WowF.vistaBiS(p, hoja, ancho, ctx) (contrato en CONTRATO.md). Arriba: [Equipo|Consumibles(|Mascota)] + fuente a la derecha.
-- Equipo: rejilla de huecos (3 columnas) a la izquierda y ficha del hueco elegido a la derecha (BiS, pre-BiS y consumibles PvE).
-- Consumibles y Mascota: las secciones de siempre (WowF.seccionConsumibles, seccionMascota) dibujadas con el kit.
local vistaB, selB
local BIS_PEQ = 12
local function colorK(n) local c = (WowF.estilo and WowF.estilo.color) or {}; return c[n] end
local function SIN_DATOS_K() return L("aún no hay datos de WoW Forever; pendiente de actualizar", "no WoW Forever data yet; pending update") end
local function iconoK(k, x, y, tam, tex, color, gris)
  local i = k:icono(x, y, tam, tex, color, gris)
  if i.negro and i.negro.ClearAllPoints then i.negro:ClearAllPoints(); i.negro:SetPoint("TOPLEFT", 1, -1); i.negro:SetPoint("BOTTOMRIGHT", -1, 1) end
  if i.SetAlpha then i:SetAlpha(1) end
  return i
end
-- Fuente corta del hueco (".s" de la maqueta): mazmorra, "mundo", "misión", "Engineering 225"...
local function fuenteCorta(pz)
  if not pz then return "" end
  if (pz.t == "jefe" or pz.t == "mazmorra") and pz.mz then return pz.mz end
  if pz.t == "profesion" and pz.pr then return pz.pr .. (pz.r and (" " .. pz.r) or "") end
  if pz.t == "mision" then return L("misión", "quest") end
  if pz.t == "mundo" or pz.t == "raro" then return L("mundo", "world") end
  if pz.t == "vendedor" or pz.t == "npc" then return L("vendedor", "vendor") end
  if pz.t == "propuesta" then return L("propuesta del addon", "addon proposal") end
  local c = como(pz) or ""
  if #c > 28 then c = c:sub(1, 26) .. "..." end
  return c
end
local function nivelDe(pz) return pz and (pz.ds or pz.nv) or nil end
-- 16-oct (Andy): el tooltip de cada pieza = el objeto real (estadisticas) + en que te mejora y cuanto + por que es tu BiS + de donde sale
local BISD = {} -- datos de la vista que se esta pintando (rama y fuente para el porque)
local function porQueBiS(pz, hueco, esBis)
  local url = BISD.d and BISD.d.meta and BISD.d.meta.fuente or FUENTE
  local fuente = (tostring(url):match("^https?://([^/]+)") or tostring(url)):gsub("^www%.", "")
  local rama, h = tostring(BISD.d and BISD.d.rama or "?"), tostring(hueco or "?")
  if pz and pz.t == "propuesta" then
    return L("Propuesta del addon: la guía " .. fuente .. " no trae pieza de " .. h .. " que puedas conseguir; esta es la mejor que encontramos para " .. rama .. " con datos de WoW Forever.",
      "Addon proposal: the " .. fuente .. " guide has no " .. h .. " piece you can get; this is the best we found for " .. rama .. " with WoW Forever data.")
  end
  if esBis then
    return L("Por qué es tu BiS: la guía " .. fuente .. " la pone como la mejor pieza de " .. h .. " al nivel " .. NIVEL_BIS .. " para " .. rama .. ".",
      "Why it is your BiS: the " .. fuente .. " guide lists it as the best " .. h .. " piece at level " .. NIVEL_BIS .. " for " .. rama .. ".")
  end
  return L("Pre-BiS: la guía " .. fuente .. " la pone como buena opción de " .. h .. " para " .. rama .. " mientras consigues la BiS.",
    "Pre-BiS: the " .. fuente .. " guide lists it as a good " .. h .. " option for " .. rama .. " while you get the BiS.")
end
local function ayudaPieza(pz, llevas, nivel, hueco, esBis, clic)
  return function(tt)
    local resto = lineasPieza(pz, llevas, nivel) .. "\n|cff66ccff" .. (clic or L("Clic: te llevo a donde se consigue", "Click: I take you to where you get it")) .. "|r"
    if WowF.tooltipPieza and pz and pz.id then
      WowF.tooltipPieza(tt, pz.id, { nombre = Y(nombreColor(pz)), porque = Y(porQueBiS(pz, hueco, esBis)), texto = Y(resto) })
    else
      tt:SetText(Y(nombreColor(pz) .. "\n" .. resto), 1, 1, 1, 1, true)
    end
  end
end
local function irPieza(pz) return function() if WowF.irABiS then WowF.irABiS(pz) end end end

-- Barra de arriba: conmutador + "Lista temprana de la beta: puede cambiar · Fuente: X" + copiar
local function barraBiS(k, d, ancho, ctx, sub)
  local ops = { { "equipo", L("Equipo", "Gear") }, { "consumibles", L("Consumibles", "Consumables") } }
  local clase = d and d.clave and d.clave:match("^(%u+)|")
  if clase == "HUNTER" or clase == "WARLOCK" then table.insert(ops, { "mascota", L("Mascota", "Pet") }) end
  k:seg(0, 0, ops, sub, function(c) if ctx.ponerSub then ctx.ponerSub(c) elseif ctx.redibujar then ctx.redibujar() end end)
  local m = d and d.meta
  if m then
    local url = m.fuente or FUENTE
    local nombre = (url:match("^https?://([^/]+)") or url):gsub("^www%.", "")
    local b = k:boton(ancho, 6, L("copiar", "copy"), "terciario", false, function()
      local txt = url .. (m.fuente20 and ("\n" .. m.fuente20) or "")
      if WowF.mostrarCopiaMacro then WowF.mostrarCopiaMacro(L("Fuente", "Source"), txt) else print(Y(txt)) end
    end, { derecha = true, ayuda = url .. (m.fuente20 and ("\n" .. m.fuente20) or "") })
    k:anotar(url)
    k:texto(0, 0, L("Lista temprana de la beta: puede cambiar · Fuente: ", "Early beta list: it may change · Source: ") .. nombre .. " · ",
      { tam = BIS_PEQ, color = colorK("tenue"), punto = { "RIGHT", b, "LEFT", 0, 0 } })
  else
    k:texto(0, 0, L("Fuente: ", "Source: ") .. SIN_DATOS_K(), { tam = BIS_PEQ, color = colorK("tenue"), punto = { "TOPRIGHT", k.marco, "TOPLEFT", ancho, -8 } })
  end
  return 28
end

-- Rejilla de huecos (".rejilla" 3 columnas, filas iguales)
local REJ_W, REJ_GAP, REJ_FILA = 526, 8, 72
local function K_AHORA() return WowF.vistaKit and WowF.vistaKit.AHORA_FONDO end
local function rejilla(k, x0, y0, d, nivel)
  local cw = math.floor((REJ_W - 2 * REJ_GAP) / 3)
  local y = y0
  for i, f in ipairs(d.huecos) do
    local col, fila = (i - 1) % 3, math.floor((i - 1) / 3)
    local x = x0 + col * (cw + REJ_GAP)
    y = y0 + fila * (REJ_FILA + REJ_GAP)
    local elegida = f.hueco == selB
    local card = k:tarjeta(x, y, cw, REJ_FILA, nil, elegida and K_AHORA() or nil, elegida and colorK("brasa") or nil, true)
    if elegida then k:franja(card, colorK("brasa")) end
    local pz = f.bis or f.prebis[1]
    local colorIco = (f.llevas and "verde") or ((pz and (pz.t == "jefe" or pz.t == "mazmorra")) and "oro") or nil
    iconoK(k, x + 10, y + 8, 32, pz and icono(pz.id) or nil, colorIco, pz == nil)
    local tx, tw = x + 10 + 32 + 8, cw - 10 - 32 - 8 - 8
    k:rotulo(tx, y + 8, f.hueco, colorK("tenue"))
    if pz then
      local nombre = pz.n or "?"
      k:texto(tx, y + 24, nombre, { tam = 13, peso = "negrita", ancho = tw, sinAnotar = false })
      k:texto(tx, y + REJ_FILA - 8 - 14, (f.bis and "" or "pre-BiS · ") .. fuenteCorta(pz), { tam = BIS_PEQ, color = colorK("oro") })
    else
      k:texto(tx, y + 24, L("sin BiS de tu facción", "no BiS for your faction"), { tam = BIS_PEQ, color = colorK("tenue"), ancho = tw })
    end
    local hueco = f.hueco
    k:zona(x, y, cw, REJ_FILA, function() selB = hueco; if vistaB and vistaB.ctx and vistaB.ctx.redibujar then vistaB.ctx.redibujar() end end,
      pz and ayudaPieza(pz, f.llevas, nivel, hueco, f.bis and true or false, L("Clic: ver la ficha de este hueco", "Click: see this slot's card")) or nil)
  end
  local filas = math.ceil(#d.huecos / 3)
  return y0 + filas * REJ_FILA + math.max(filas - 1, 0) * REJ_GAP
end

-- Ficha, tarjeta 1: la BiS del hueco
local function fichaBiS(k, x0, y0, w, f, nivel, p, d)
  local card = k:tarjeta(x0, y0, w, 10, "principal")
  local y = y0 + 14
  k:rotulo(x0 + 16, y, f.hueco .. " · BiS")
  local pz = f.bis
  if not pz then
    local txt = f.sinBis and L("La BiS de la guía no es de tu facción: usa la pre-BiS de abajo.", "The guide's BiS is not for your faction: use the pre-BiS below.") or SIN_DATOS_K()
    local _, h = k:texto(x0 + 16, y + 24, txt, { tam = 13, color = colorK("tenue"), ancho = w - 32 })
    y = y + 24 + h + 14
    card:SetHeight(y - y0); k:hasta(y)
    return y
  end
  local req = nivelDe(pz)
  local chip, color
  if f.llevas then chip, color = L("La llevas", "You wear it"), "verde"
  elseif f.tienes and f.tienes.donde == "bolsas" then chip, color = L("En tus bolsas", "In your bags"), "verde"
  elseif f.tienes and f.tienes.donde == "banco" then chip, color = L("En tu banco", "In your bank"), "verde"
  elseif req and req > nivel then chip, color = L("Aún no: desde nivel ", "Not yet: from level ") .. req, "gris"
  else chip, color = L("Ya puedes", "Available now"), "oro" end
  k:chip(x0 + w - 16, y - 3, chip, color, true)
  y = y + 14 + 12
  iconoK(k, x0 + 16, y, 52, icono(pz.id), "oro", false)
  local tx = x0 + 16 + 52 + 14
  local tw = x0 + w - 16 - tx
  local _, hn = k:texto(tx, y + 2, pz.n or "?", { tam = 20, letra = "marca", ancho = tw })
  local sub
  if pz.t == "jefe" and pz.j and pz.mz then sub = L("Lo suelta " .. pz.j .. " · " .. pz.mz, "Dropped by " .. pz.j .. " · " .. pz.mz)
  else sub = como(pz) end
  if sinConfirmar(pz) then sub = sub .. "\n" .. NARANJA .. textoSinConfirmar() .. "|r" end
  local mzSin = pz.mz and buscarMazmorra(pz.mz)
  if mzSin and not (mzSin.m and mzSin.x and mzSin.y) then -- 13-oct: el botín se sabe; la entrada aún no
    sub = sub .. "\n" .. NARANJA .. L("Mazmorra de grupo. Sabemos que cae aquí, pero aún no tenemos la entrada en WoW Forever; se actualizará.",
      "Group dungeon. We know it drops here, but we don't have the entrance in WoW Forever yet; it will be updated.") .. "|r"
  end
  if pz.sf then sub = sub .. "\n" .. NARANJA .. L("Solo la puede llevar quien la fabrica.", "Only its maker can wear it.") .. "|r" end
  if f.prop then sub = sub .. "\n" .. NARANJA .. L("Propuesta del addon: la guía no trae esta arma.", "Addon proposal: the guide has no weapon here.") .. "|r" end
  local slot = (RANURAS[f.hueco] or {})[1]
  local pRama = { clase = (d.clave and d.clave:match("^(%u+)|")) or (p and p.clase), ramaPesos = d.rama }
  if WowF.ajusteArma and (slot == 16 or slot == 17 or slot == 18) then
    local okA, aj = pcall(WowF.ajusteArma, pz, pRama, slot)
    if okA and type(aj) == "table" and aj.motivo then
      sub = sub .. "\n" .. NARANJA .. (aj.prohibido and L("Ojo: " .. aj.motivo .. ".", "Note: " .. aj.motivo .. ".")
        or L("La guía la pone de BiS aunque " .. aj.motivo .. ": suma más daño en total.", "The guide lists it as BiS although " .. aj.motivo .. ": it adds more damage overall.")) .. "|r"
    end
  end
  local _, hs = k:texto(tx, y + 2 + hn + 4, Y(sub), { tam = 13, color = colorK("tenue"), ancho = tw })
  y = math.max(y + 52, y + 2 + hn + 4 + hs) + 14
  k:zona(x0, y0, w, y - y0, irPieza(pz), ayudaPieza(pz, f.llevas, nivel, f.hueco, true))
  local txtB = (pz.t == "jefe" or pz.t == "mazmorra") and L("Llévame a la mazmorra ›", "Take me to the dungeon ›") or L("Llévame ›", "Take me there ›")
  local _, wB = k:boton(x0 + 16, y, txtB, "estandarte", false, irPieza(pz))
  -- 11-oct: Perseguir (wowF_Caza.lua): la pieza pasa a "Piezas que persigues"
  if WowF.botonPerseguir then WowF.botonPerseguir(k, x0 + 16 + (tonumber(wB) or 120) + 10, y, { id = pz.id, n = pz.n, tipo = "bis", clave = d.clave, hueco = f.hueco }) end
  y = y + 34 + 16
  card:SetHeight(y - y0); k:hasta(y)
  return y
end

-- Ficha, tarjeta 2: mientras tanto (pre-BiS) en 2 columnas
local function fichaPre(k, x0, y0, w, f, nivel)
  local card = k:tarjeta(x0, y0, w, 10)
  local y = y0 + 14
  k:rotulo(x0 + 16, y, L("Mientras tanto · pre-BiS", "Meanwhile · pre-BiS"), colorK("oro"))
  y = y + 14 + 12
  if #f.prebis == 0 then
    local _, h = k:texto(x0 + 16, y, SIN_DATOS_K(), { tam = 13, color = colorK("tenue"), ancho = w - 32 })
    y = y + h + 14
    card:SetHeight(y - y0); k:hasta(y)
    return y
  end
  local cw = math.floor((w - 32 - 12) / 2)
  local altoFila = 0
  for i, pz in ipairs(f.prebis) do
    if i > 4 then break end
    local col = (i - 1) % 2
    if col == 0 and i > 1 then y = y + altoFila + 10; altoFila = 0 end
    local x = x0 + 16 + col * (cw + 12)
    local llevas = f.llevasPre == pz
    local req = nivelDe(pz)
    local ya = llevas or not req or req <= nivel
    iconoK(k, x, y, 32, icono(pz.id), ya and "verde" or "gris", not ya)
    local _, hn = k:texto(x + 32 + 10, y, pz.n or "?", { tam = 13, peso = "negrita", ancho = cw - 42 })
    local peq = (llevas and L("la llevas", "you wear it")) or ((req and (L("nivel ", "level ") .. req .. " · ") or "") .. fuenteCorta(pz))
    local _, hp = k:texto(x + 32 + 10, y + hn + 2, peq, { tam = BIS_PEQ, color = colorK("tenue"), ancho = cw - 42 })
    altoFila = math.max(altoFila, 32, hn + 2 + hp)
    k:zona(x, y, cw, math.max(32, hn + 2 + hp), irPieza(pz), ayudaPieza(pz, llevas, nivel, f.hueco, false))
  end
  y = y + altoFila + 14
  card:SetHeight(y - y0); k:hasta(y)
  return y
end

-- Ficha, tarjeta 3: consumibles PvE (hasta el alto visible)
local function fichaConsumibles(k, x0, y0, w, altoMin, p, ctx)
  local card = k:tarjeta(x0, y0, w, 10)
  local y = y0 + 14
  k:rotulo(x0 + 16, y, L("Consumibles para ti · PvE", "Consumables for you · PvE"), colorK("oro"))
  k:boton(x0 + w - 16, y - 2, L("ver todos", "see all"), "terciario", false, function()
    if ctx.ponerSub then ctx.ponerSub("consumibles") end
  end, { derecha = true })
  y = y + 14 + 12
  local D = WowFConsumibles
  local r
  if D and WowF.consumiblesDe then local ok, v = pcall(WowF.consumiblesDe, p); if ok then r = v end end
  if not r or #(r.pve or {}) == 0 then
    local _, h = k:texto(x0 + 16, y, SIN_DATOS_K(), { tam = 13, color = colorK("tenue"), ancho = w - 32 })
    y = y + h + 14
  else
    for i, f in ipairs(r.pve) do
      if i > 4 then break end
      local id = f.id or f.prox
      local x = D.lista and D.lista[id]
      if x then
        iconoK(k, x0 + 16, y, 32, icono(id), f.id and "verde" or "gris", not f.id)
        local _, hn = k:texto(x0 + 16 + 42, y, x.n or "?", { tam = 13, peso = "negrita", ancho = w - 32 - 42 })
        local _, hp = k:texto(x0 + 16 + 42, y + hn + 2, L("nivel ", "level ") .. (x.rl or "?") .. " · " .. (L(x.es, x.en) or ""), { tam = BIS_PEQ, color = colorK("tenue"), ancho = w - 32 - 42 })
        local alto = math.max(32, hn + 2 + hp)
        k:zona(x0 + 16, y, w - 32, alto, function() if WowF.irAConsumible then WowF.irAConsumible(id) end end,
          L("Clic: te llevo al vendedor o te digo cómo conseguirlo", "Click: I take you to the vendor or tell you how to get it"))
        y = y + alto + 10
      end
    end
    y = y + 4
  end
  local fin = math.max(y, y0 + (altoMin or 0))
  card:SetHeight(fin - y0); k:hasta(fin)
  return fin
end

-- Secciones de siempre (consumibles, mascota) dibujadas con el kit: cab = rotulo con raya, nota = texto, item = fila-tarjeta
local function seccionKit(k, ancho, y0, dibujar)
  local y = y0
  local function cab(texto)
    y = y + 8
    local _, h = k:texto(0, y, texto, { tam = 15, letra = "marca", ancho = ancho })
    y = y + h + 4
    k:raya(0, y, ancho, colorK("borde"))
    y = y + 8
  end
  local function nota(texto)
    local _, h = k:texto(0, y, texto, { tam = BIS_PEQ, color = colorK("tenue"), ancho = ancho })
    y = y + h + 6
  end
  local function item(o)
    local sx = o.sangria or 0
    local w = ancho - sx
    local tex = o.icono
    local card = k:tarjeta(sx, y, w, 10, nil, nil, nil, true)
    local tx = sx + 10 + 32 + 10
    iconoK(k, sx + 10, y + 8, 32, tex, nil, false)
    local _, ht = k:texto(tx, y + 8, o.texto or "", { tam = 13, peso = "negrita", ancho = w - (tx - sx) - 10 })
    local hs = 0
    if o.sub and o.sub ~= "" then _, hs = k:texto(tx, y + 8 + ht + 2, o.sub, { tam = BIS_PEQ, color = colorK("tenue"), ancho = w - (tx - sx) - 10 }) end
    local alto = math.max(32 + 16, ht + 2 + hs + 16)
    card:SetHeight(alto)
    if o.accion then k:zona(sx, y, w, alto, o.accion, L("Clic: te llevo", "Click: I take you there")) end
    k:hasta(y + alto)
    y = y + alto + 6
  end
  local ok, err = pcall(dibujar, cab, nota, item)
  if not ok then nota(NARANJA .. SIN_DATOS_K() .. "|r") end
  return y
end

function WowF.vistaBiS(p, hoja, ancho, ctx)
  ancho = ancho or 890
  ctx = ctx or {}
  local KK = WowF.vistaKit
  if not vistaB then
    local m, kit = KK.marcoDe(nil, hoja, ancho)
    vistaB = { marco = m, kit = kit }
  end
  vistaB.ctx = ctx
  local m, k = vistaB.marco, vistaB.kit
  if m.GetParent and m:GetParent() ~= hoja and m.SetParent then m:SetParent(hoja) end
  m:SetWidth(ancho)
  k:empezar()
  local nivel = (WowF.verComoNivel and WowF.verComoNivel()) or nivelPj()
  local d
  do local ok, v = pcall(WowF.bisDe, p); if ok then d = v end end
  local sub = ctx.sub
  if sub ~= "consumibles" and sub ~= "mascota" then sub = "equipo" end
  local clase = d and d.clave and d.clave:match("^(%u+)|")
  if sub == "mascota" and clase ~= "HUNTER" and clase ~= "WARLOCK" then sub = "equipo" end
  local y = barraBiS(k, d, ancho, ctx, sub) + 12
  if sub == "equipo" and WowF.barraVerComo then y = WowF.barraVerComo(k, 0, y, ancho, ctx) end
  if sub == "consumibles" and WowF.vistaConsumibles then -- 11-oct: tarjetas (wowF_Consumibles.lua)
    local ok, ny = pcall(WowF.vistaConsumibles, k, 0, y, ancho, p, ctx)
    if ok and type(ny) == "number" then y = ny
    else
      WowF.libroErrorVista = "Consumibles: " .. tostring(ny)
      local _, h = k:texto(16, y + 10, SIN_DATOS_K(), { tam = 13, color = colorK("tenue"), ancho = ancho - 32 }); y = y + 10 + h + 10
    end
  elseif sub == "consumibles" then
    y = seccionKit(k, ancho, y, function(cab, nota, item)
      if WowF.seccionConsumibles then WowF.seccionConsumibles(p, cab, nota, item) else nota(SIN_DATOS_K()) end
    end)
  elseif sub == "mascota" then
    y = seccionKit(k, ancho, y, function(cab, nota, item) seccionMascota(p, d or {}, cab, nota, item) end)
  elseif not d or not d.meta then
    local card = k:tarjeta(0, y, ancho, 10, "principal")
    local yy = y + 14
    local txt = (not d) and L("Sin datos de tu clase.", "No data for your class.")
      or L("Aún no hay lista para tu rama: se actualizará en próximas actualizaciones.", "There is no list for your spec yet: it will be updated in future updates.")
    local _, h = k:texto(16, yy, txt .. "\n" .. SIN_DATOS_K(), { tam = 13, color = colorK("tenue"), ancho = ancho - 32 })
    yy = yy + h + 14
    card:SetHeight(yy - y); k:hasta(yy)
  else
    -- Hueco elegido: el que pulsaste; si no, el primero que aun no llevas
    local hay = false
    for _, f in ipairs(d.huecos) do if f.hueco == selB then hay = true end end
    if not hay then
      selB = nil
      for _, f in ipairs(d.huecos) do if not selB and f.bis and not f.llevas then selB = f.hueco end end
      selB = selB or (d.huecos[1] and d.huecos[1].hueco)
    end
    local fsel
    for _, f in ipairs(d.huecos) do if f.hueco == selB then fsel = f end end
    BISD.d = d
    local finR = rejilla(k, 0, y, d, nivel)
    local fx, fw = REJ_W + 12, ancho - REJ_W - 12
    local fy = y
    if fsel then
      fy = fichaBiS(k, fx, fy, fw, fsel, nivel, p, d) + 12
      fy = fichaPre(k, fx, fy, fw, fsel, nivel) + 12
    end
    local altoVis = ctx.altoVisible or 668
    fichaConsumibles(k, fx, fy, fw, math.max(altoVis - fy, finR - fy, 0), p, ctx)
    -- Notas de la rama debajo de la rejilla (subir con otra rama, nota de arma, nota de la lista)
    local ny = finR + 12
    local notasR = {}
    local puestas = 0
    for _, f in ipairs(d.huecos) do if f.llevas then puestas = puestas + 1 end end
    table.insert(notasR, L("Llevas " .. puestas .. " de " .. #d.huecos .. " piezas BiS. Solo cosas de la " .. nombreFac(d.faccion) .. ".", "You wear " .. puestas .. " of " .. #d.huecos .. " BiS items. Only " .. nombreFac(d.faccion) .. " items."))
    if d.porSubir then
      table.insert(notasR, L("Subes con " .. d.rama .. " y pasas a " .. tostring(d.final) .. " al nivel " .. d.cambio .. ": a nivel " .. NIVEL_BIS .. " sigues en " .. d.rama .. ", así que esta es su lista.",
        "You level as " .. d.rama .. " and switch to " .. tostring(d.final) .. " at level " .. d.cambio .. ": at level " .. NIVEL_BIS .. " you are still " .. d.rama .. ", so this is its list."))
    end
    local av = L(d.meta.nota, d.meta.notaEn)
    if av and av ~= "" then table.insert(notasR, av) end
    local na = WowF.notaArma and WowF.notaArma({ clase = p and p.clase, ramaPesos = d.rama })
    if na then table.insert(notasR, na) end
    for _, t in ipairs(notasR) do
      local _, h = k:texto(0, ny, Y(t), { tam = BIS_PEQ, color = colorK("tenue"), ancho = REJ_W })
      ny = ny + h + 6
    end
  end
  m:SetHeight(math.max(1, k.alto))
  return m, k.alto, k.textos
end

-- ----- /wowf bis -----
local ordenAnterior = SlashCmdList and SlashCmdList["WOWF"]
if SlashCmdList then
  SlashCmdList["WOWF"] = function(msg, ...)
    local c = ((msg or ""):lower()):match("^%s*(.-)%s*$")
    if c == "bis" or c == "bis 30" or c == "bis30" then
      if WowF.abrirLibro then WowF.abrirLibro("BiS 30") else
        local d = WowF.bisDe()
        if not d or not d.meta then decir("aún no hay lista BiS para tu rama.", "there is no BiS list for your spec yet.") return end
        for _, f in ipairs(d.huecos) do if f.bis then print(Y(f.hueco .. ": " .. nombreColor(f.bis))) end end
      end
      return
    end
    if ordenAnterior then return ordenAnterior(msg, ...) end
  end
end
