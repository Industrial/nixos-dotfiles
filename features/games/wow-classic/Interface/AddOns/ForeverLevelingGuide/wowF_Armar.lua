-- wowF Armar: arma "Mi plan" dentro del juego, sin la guia (wowF.exe).
-- Junta los datos de WowFDatos (generados con la logica de la guia) segun tu clase, tu rama y tus profesiones reales:
--   rama: la que elegiste con /wowf rama, o la del arbol donde tienes mas puntos, o la recomendada para subir
--   profesiones: las dos principales que ya tienes; si te falta alguna, se completan con las recomendadas para tu clase
-- Devuelve la misma forma que el plan que escribia la guia, asi el panel no cambia.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}

local ID_PROF = {
  alchemy = 171, alquimia = 171, blacksmithing = 164, ["herrería"] = 164, herreria = 164,
  leatherworking = 165, ["peletería"] = 165, peleteria = 165, tailoring = 197, ["sastrería"] = 197, sastreria = 197,
  engineering = 202, ["ingeniería"] = 202, ingenieria = 202, enchanting = 333, encantamiento = 333,
  mining = 186, ["minería"] = 186, mineria = 186, herbalism = 182, ["herboristería"] = 182, herboristeria = 182,
  skinning = 393, desuello = 393,
}

local function clavePersonaje()
  local nombre = UnitName("player") or "?"
  local reino = (GetRealmName and GetRealmName()) or ""
  return reino ~= "" and (nombre .. "-" .. reino) or nombre
end

local function datosClase()
  if type(WowFDatos) ~= "table" or not UnitClass then return nil end
  local _, token = UnitClass("player")
  return token and WowFDatos.clases[token], token
end

-- Profesiones principales que ya tienes (ids), en el orden del libro de habilidades
local function misProfesiones()
  -- Lectura comun (wowF_Exportar.lua): por numero de profesion y en todos los idiomas del cliente
  if WowF.profesionesPrincipales then return WowF.profesionesPrincipales() end
  local res = {}
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local nombre, esCabecera = GetSkillLineInfo(i)
      local id = nombre and not esCabecera and ID_PROF[nombre:lower()]
      if id and #res < 2 then table.insert(res, id) end
    end
  end
  return res
end

-- Puntos por arbol de talentos: la pestana con mas puntos
-- 5-oct: los valores del juego pueden ser secretos en la beta (pcall + WowF.numero); nunca rompe el plan
local function num(v)
  if WowF.numero then return tonumber(WowF.numero(v)) end
  local ok, n = pcall(tonumber, v)
  return ok and n or nil
end
local function puntosArbol(t)
  -- Cliente nuevo: id, nombre, descripcion, icono, PUNTOS...; cliente viejo: nombre, icono, PUNTOS, archivo
  local ok, _, _, d3, _, d5 = pcall(GetTalentTabInfo, t)
  if not ok then return 0 end
  local p = num(d5) or num(d3) or 0
  if p > 0 or not GetNumTalents or not GetTalentInfo then return p end
  -- Si la pestana no dice los puntos, se suman los rangos de cada talento (5.o valor de GetTalentInfo)
  local okN, n = pcall(GetNumTalents, t)
  n = okN and num(n) or 0
  for i = 1, n do
    local okT, _, _, _, _, rango = pcall(GetTalentInfo, t, i)
    if okT then p = p + (num(rango) or 0) end
  end
  return p
end
-- Rangos puestos por nombre de talento en un arbol: { ["Thick Hide"] = 3, ... } (vacio si el cliente no lo dice)
local function rangosArbol(t)
  local res = {}
  if not GetNumTalents or not GetTalentInfo then return res end
  local okN, n = pcall(GetNumTalents, t)
  n = okN and num(n) or 0
  for i = 1, n do
    local okT, nombre, _, _, _, rango = pcall(GetTalentInfo, t, i)
    local r = okT and num(rango) or 0
    if okT and type(nombre) == "string" and r > 0 and not (issecretvalue and issecretvalue(nombre)) then res[nombre] = r end
  end
  return res
end
local function arbolPrincipal()
  if not GetNumTalentTabs or not GetTalentTabInfo then return nil end
  local ok, total = pcall(GetNumTalentTabs)
  total = ok and num(total)
  if not total then return nil end
  local mejor, max = nil, 0
  for t = 1, total do
    local puntos = puntosArbol(t)
    if puntos > max then mejor, max = t, puntos end
  end
  return mejor
end
WowF.arbolPrincipal = arbolPrincipal

-- La rama elegida se guarda por NOMBRE (antes por numero: si cambiaba el orden de las ramas con una build nueva,
-- el numero apuntaba a otra rama). Un numero viejo (hasta la 4.0) NO se usa: podia apuntar a una rama que no es la tuya.
local function ramaGuardada(c, e)
  if type(e) == "string" then
    for i, r in ipairs(c.ramas) do if WowF.nombreRama(r) == e then return i end end
  end
  return nil
end

-- Indice de la rama que usa el plan y de donde sale ("elegida", "talentos" o "recomendada")
local function ramaDeTalentos(c)
  -- 5-oct: las guias reales reparten puntos entre arboles (Paladin Retribution de Wowhead: 11 Holy + 10 Retribution hasta el 30;
  -- Priest Discipline: 8 Disc + 9 Holy + 4 Shadow). Tu rama es la que tiene un REPARTO por arbol mas parecido al tuyo con tus puntos
  -- (no "el arbol con mas puntos"). Empate: la que coincide con los NOMBRES de tus talentos, la que se juega desde ya (sin cambio) y la primera de la lista (la principal).
  if not GetNumTalentTabs or not GetTalentTabInfo then return nil end
  local okT, nT = pcall(GetNumTalentTabs)
  nT = okT and num(nT) or 0
  local pts, total = {}, 0
  for t = 1, nT do pts[t] = puntosArbol(t); total = total + pts[t] end
  if total <= 0 then return nil end
  local idxArbol = {}
  for i, nombre in ipairs(c.pestanas or {}) do idxArbol[nombre] = i end
  local nombres
  local mejor, mejorClave
  local claves = {}
  for i, r in ipairs(c.ramas) do
    local esperado = {}
    local orden = r.orden or {}
    for k = 1, total do
      local n = orden[k]
      local ta = n and c.talentos[n]
      local t = (ta and idxArbol[ta[3]]) or r.tab
      esperado[t] = (esperado[t] or 0) + 1
    end
    local dist = 0
    for t = 1, math.max(nT, 3) do dist = dist + math.abs((pts[t] or 0) - (esperado[t] or 0)) end
    -- Coincidencia por nombre (solo hace falta para desempatar: Druid Feral Cat / Bear)
    local s = 0
    if not nombres then nombres = {} for t = 1, nT do for n2, rg in pairs(rangosArbol(t)) do nombres[n2] = rg end end end
    local cuenta = {}
    for k = 1, math.min(total, #orden) do
      local n = orden[k]
      cuenta[n] = (cuenta[n] or 0) + 1
      if cuenta[n] <= (nombres[n] or 0) then s = s + 1 end
    end
    local clave = { dist, -s, ((r.cambio or 0) == 0) and 0 or 1, i }
    claves[i] = clave
    local gana = not mejorClave
    if not gana then
      for k = 1, #clave do
        if clave[k] ~= mejorClave[k] then gana = clave[k] < mejorClave[k]; break end
      end
    end
    if gana then mejor, mejorClave = i, clave end
  end
  -- Otras ramas (sin cambio) que encajan igual de bien: con pocos puntos varias guias empiezan igual (Priest Shadow y Discipline)
  local empates = {}
  for i, cl in pairs(claves) do
    if i ~= mejor and cl[1] == mejorClave[1] and cl[2] == mejorClave[2] and cl[3] == 0 then table.insert(empates, i) end
  end
  table.sort(empates)
  return mejor, empates
end
local function ramaIndice(c)
  local elegidas = WowFExportarDB.rama or {}
  local e = ramaGuardada(c, elegidas[clavePersonaje()])
  if e then return e, "elegida" end
  local t = ramaDeTalentos(c)
  if t then return t, "talentos" end
  return c.porDefecto or 1, "recomendada"
end
-- La rama de tus talentos reales (aunque hayas elegido otra) y si la elegida choca con ellos:
-- choca si tus puntos estan en otro arbol y la elegida no es "subir con ese arbol y cambiar despues"
function WowF.ramaDeTalentos()
  local c = datosClase()
  if not c then return nil end
  local t, empates = ramaDeTalentos(c)
  if not t then return nil end
  local ri = ramaIndice(c)
  local r, real = c.ramas[ri], c.ramas[t]
  local choca = r.tab ~= real.tab
  if choca and (r.cambio or 0) > 0 then
    for _, s in ipairs(c.ramas) do if s.nombre == r.subir and s.tab == real.tab then choca = false end end
  end
  local tambien = {}
  for _, e in ipairs(empates or {}) do if e ~= ri then table.insert(tambien, c.ramas[e].nombre) end end
  return { i = t, nombre = WowF.nombreRamaVer(real), base = real.nombre, choca = choca, tambien = tambien }
end

local function obj(id)
  local o = WowFDatos.obj[id]
  if o then return o[1], o[2], o[3] end
  return "", 1, ""
end

local OBJETIVOS = { fabricar = "Fabricarme mi equipo", oro = "Ganar oro", pvp = "PvP" }
WowF.OBJETIVOS = OBJETIVOS
WowF.ORDEN_OBJETIVOS = { "fabricar", "oro", "pvp" }
-- Objetivo de las profesiones (como en la guia): "fabricar" (por defecto), "oro" o "pvp"; se guarda por personaje
function WowF.objetivo()
  local o = WowFExportarDB.objetivo and WowFExportarDB.objetivo[clavePersonaje()]
  return OBJETIVOS[o or ""] and o or "fabricar"
end
-- true si este personaje ya eligio (el libro no despliega las profesiones hasta que elija)
function WowF.objetivoElegido()
  local o = WowFExportarDB.objetivo and WowFExportarDB.objetivo[clavePersonaje()]
  return OBJETIVOS[o or ""] ~= nil
end

local cache, claveCache = nil, nil
function WowF.elegirObjetivo(o)
  if not OBJETIVOS[o or ""] then return nil end
  WowFExportarDB.objetivo = WowFExportarDB.objetivo or {}
  WowFExportarDB.objetivo[clavePersonaje()] = o
  cache, claveCache = nil, nil
  return OBJETIVOS[o]
end
function WowF.armarPlan()
  local c, token = datosClase()
  if not c then return nil end
  local ri, origen = ramaIndice(c)
  local r = c.ramas[ri]
  local tengo = misProfesiones()
  local objetivo = WowF.objetivo()
  -- Completar con las recomendadas para tu objetivo (sin repetir) hasta tener dos
  local profs, faltan = {}, {}
  for _, id in ipairs(tengo) do table.insert(profs, id) end
  for _, id in ipairs(c.recomendadas[objetivo] or c.recomendadas.fabricar or {}) do
    if #profs >= 2 then break end
    local ya = false
    for _, x in ipairs(profs) do if x == id then ya = true end end
    if not ya then table.insert(profs, id); table.insert(faltan, id) end
  end
  -- 5-oct (revision): faccion y nivel por WowF.llamar/WowF.numero (wowF_Exportar.lua): en la beta pueden ser valores secretos
  local function juego(f, ...)
    if WowF.llamar then return WowF.llamar(f, ...) end
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, ...)
    if ok and not (issecretvalue and issecretvalue(v)) then return v end
    return nil
  end
  local faccion = juego(UnitFactionGroup, "player") == "Horde" and "Horda" or "Alianza"
  local nivelPj = tonumber(juego(UnitLevel, "player") or "") or 1
  -- El nivel entra en la clave: el botin de cada mazmorra depende de tu nivel (alas de Scarlet Monastery, tipo de armadura)
  -- 12-oct (Legacy "Talented"): puntos de talento extra que lee el cliente (0 si no se puede leer); entran en la clave
  local extraTal = 0
  pcall(function() extraTal = WowF.extraTalentos and WowF.puntosTalento and WowF.extraTalentos(WowF.puntosTalento()) or 0 end)
  extraTal = tonumber(extraTal) or 0
  local clave = "L" .. extraTal .. "|" .. token .. ri .. faccion .. objetivo .. table.concat(profs, ",") .. table.concat(faltan, ",") .. "|" .. nivelPj .. "|" .. (WowF.planZonasFirma and WowF.planZonasFirma() or "") .. ((WowF.enIngles and WowF.enIngles()) and "|en" or "|es")
  if cache and claveCache == clave then
    cache.prioridad = table.concat((r.cambio > 0 and nivelPj < r.cambio) and r.statsSubir or r.stats, " > ")
    cache.prioridadGuia = table.concat((r.cambio > 0 and nivelPj < r.cambio) and (r.statsGuiaSubir or {}) or (r.statsGuia or {}), " > ")
    cache.cambioNivel = r.cambio
    cache.prioridadSinGuia = (r.cambio > 0 and nivelPj < r.cambio) and (r.statsSinGuiaSubir and true or false) or (r.statsSinGuia and true or false)
    return cache
  end

  local D = WowFDatos
  local eventos = {}
  -- Talentos: el punto k llega con k puntos en total; con extraTal puntos de Legacy, extraTal niveles antes. En un plan mixto
  -- los de la rama final nunca antes del reajuste (nivel r.cambio: ahi se ponen de golpe)
  for _, e in ipairs(r.eventos) do
    local nv = e[1]
    if e[2] == "talento" and extraTal > 0 and type(nv) == "number" then
      if (r.cambio or 0) > 0 and nv >= r.cambio then nv = math.max(r.cambio, nv - extraTal)
      else nv = math.max(1, nv - extraTal) end
    end
    table.insert(eventos, { nv, e[2], e[3], ic = e[4] })
  end
  -- Donde subir: plan de zonas encadenado por bando, sitio y cercania (wowF_SubirZonas.lua; un tramo por zona, sin pisarse)
  for _, e in ipairs(WowF.eventosZonas and WowF.eventosZonas() or {}) do table.insert(eventos, e) end
  -- Profesiones: aprender las que faltan y la ruta de cada tope
  -- Las que aun no tienes van marcadas: el resumen ("Profesiones: ...") nunca debe hacer creer que son tuyas
  local nombres = {}
  for _, id in ipairs(profs) do
    local falta = false
    for _, f in ipairs(faltan) do if f == id then falta = true end end
    table.insert(nombres, (D.prof[id] or tostring(id)) .. (falta and " (por aprender)" or ""))
  end
  -- 9-oct (cero datos de Classic): el nivel de D.caps (5/10/20/35) es de Classic; aqui SOLO ordena los eventos.
  -- Ningun texto afirma ese nivel: el Libro y el Panel lo dicen como "nivel que pide: aun no disponible en Forever".
  if #faltan > 0 then
    local n = {}
    for _, id in ipairs(faltan) do table.insert(n, D.prof[id] or tostring(id)) end
    table.insert(eventos, { D.caps[1][1], "prof", "Aprende " .. table.concat(n, " y ") .. " en el entrenador de tu capital (recomendada para tu clase si quieres: " .. OBJETIVOS[objetivo] .. "), y ademas First Aid y Cooking." })
  end
  for _, cap in ipairs(D.caps) do
    local partes = {}
    for _, id in ipairs(profs) do local t = D.tramos[id] and D.tramos[id][cap[2]]; if t then table.insert(partes, t) end end
    if #partes > 0 then table.insert(eventos, { cap[1], "prof", "Tope de profesion: " .. cap[2] .. ". · " .. table.concat(partes, " · ") }) end
  end
  -- Equipo que te fabricas: tus dos profesiones juntas; solo lo que mejora la pieza anterior de esa ranura
  local function piezasDe(ids, tipo, destino)
    local piezas = {}
    for _, id in ipairs(ids) do for _, e in ipairs((r.equipo or {})[id] or {}) do table.insert(piezas, e) end end
    table.sort(piezas, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[3] > b[3] end)
    local mejor = {}
    for _, e in ipairs(piezas) do
      local previo = mejor[e[4]]
      if not (previo and (e[3] < previo[3] * 1.2 or previo[1] == e[1])) then
        mejor[e[4]] = e
        local n, q, ic = obj(e[2])
        local mats = {}
        for _, m in ipairs(e[6]) do local mn, _, mic = obj(m[1]); table.insert(mats, { m[1], m[2], mn, mic }) end
        table.insert(destino, { e[1], tipo, e[5], i = e[2], q = q, ic = ic, m = mats, ra = e[4], hasta = e[7] or 60 })
      end
    end
  end
  piezasDe(profs, "equipo", eventos)
  -- Sin profesion de fabricar (por ejemplo Herbalism + Mining): lo que te harias con la recomendada para tu clase
  local sugerida = nil
  local fabricas = false
  for _, id in ipairs(profs) do if not D.recoleccion[id] then fabricas = true end end
  -- 5-oct: con "oro" no se sugiere fabricarte equipo (lo de vender sale en wowF_ProfObjetivo.lua); con "pvp", la de PvP de tu clase
  local op = (objetivo == "pvp") and D.objetivoProf and D.objetivoProf.pvp or nil
  if not fabricas and objetivo ~= "oro" then
    for _, id in ipairs((op and c.recomendadas.pvp) or c.recomendadas.fabricar or {}) do
      if not D.recoleccion[id] and (op and op[id] or (not op and (r.equipo or {})[id])) then
        sugerida = { id = id, nombre = D.prof[id] or tostring(id), piezas = {} }
        piezasDe({ id }, "equipo", sugerida.piezas)
        table.sort(sugerida.piezas, function(a, b) return a[1] < b[1] end)
        break
      end
    end
  end
  -- Botin que te sirve en cada mazmorra, a TU nivel (o al de entrada si aun no se abre): o[4] = nivel que pide (no mas de 3
  -- por encima), o[5] = nivel en que ya llevas un tipo de armadura mas pesado (0 = siempre te sirve). Como mucho 12 por mazmorra:
  -- al mostrarlas, WowF.piezasParaTi (wowF_Comparar.lua) quita las que no mejoran lo que llevas y deja 8.
  local desde = {}
  -- 4-oct: solo mazmorras de tu faccion (Ragefire Chasm es Horde, The Stockade es Alliance) y con el botin verificado en
  -- Wowhead /forever (bv = false: la lista de Wowhead aun no esta completa; no se recomienda nada que no se pueda confirmar)
  local miFac = (faccion == "Horda") and 1 or 2
  local valida, jefesDe = {}, {}
  for _, m in ipairs(WowFMazmorras or {}) do
    if m.i and (not desde[m.i] or m.d < desde[m.i]) then desde[m.i] = m.d end
    if m.i and (m.f == 0 or m.f == miFac) and m.bv ~= false then valida[m.i] = true end
    -- b = jefes de la mazmorra segun la beta: "Jefe: X" solo si X es uno de ellos (si no, "Lo suelta: X")
    if m.i and m.b then jefesDe[m.i] = jefesDe[m.i] or {}; for _, n in ipairs(m.b) do jefesDe[m.i][n] = true end end
  end
  local botin = {}
  for inst, lista in pairs(r.botin or {}) do
    local ok = valida[inst] or not WowFMazmorras
    if ok then botin[inst] = {} else lista = {} end
    for _, o in ipairs(lista) do
      local pide, hasta = o[4] or 0, o[5] or 0
      local base = math.max(nivelPj, desde[inst] or 0)
      if #botin[inst] >= 12 or pide > base + 3 or (hasta > 0 and base >= hasta) then
        -- no te sirve a tu nivel (o ya hay 12)
      else
      local n, q, ic = obj(o[1])
      -- j = texto para mostrar; jefe = nombre real del jefe (nil si la suelta cualquiera o aun no se sabe)
      local quien, jefe = o[2], o[2]
      if quien == "Trash" then quien, jefe = "cualquier enemigo de la mazmorra", nil
      elseif not quien or quien == "" or quien == "?" then quien, jefe = "aun no hay informacion de quien la suelta", nil end
      -- inv, ar, dps, st: ranura, armadura, DPS y estadisticas reales para compararla con lo que llevas puesto
      table.insert(botin[inst], { id = o[1], n = n, q = q, j = quien, jefe = jefe, esJefe = (jefe and jefesDe[inst] and jefesDe[inst][jefe]) or false, r = o[3], ic = ic, nivel = pide, inv = o[6], ar = o[7] or 0, dps = o[8] or 0, st = o[9] or {} })
      end
    end
  end
  -- Pesos con que se compara el botin: los de la rama con que subes (si toca) o los de tu rama
  local subiendo = r.cambio > 0 and nivelPj < r.cambio
  -- 10-oct (4.21): rama final de un plan mixto (aviso "guardalo para <rama final>" de wowF_AvisoBotin): pesos de la final y
  -- manos/daga de esa rama sola (en la mixta, manos y daga son las de la rama con que subes)
  local fin
  if r.cambio > 0 then
    for _, o in ipairs(c.ramas) do if o.nombre == r.nombre and (o.cambio or 0) == 0 then fin = o break end end
  end
  table.sort(eventos, function(a, b) return a[1] < b[1] end)
  cache = {
    armado = true, origenRama = origen, indiceRama = ri, totalRamas = #c.ramas,
    rama = WowF.nombreRamaVer(r), ramaNombre = r.nombre, ramaSubir = r.subir, ramaCambio = r.cambio, manos = (subiendo or not fin) and r.manos or fin.manos, daga = r.daga,
    -- Diagrama de talentos: orden punto por punto (orden2 = rama final si es mixta), la guia de donde sale y la pestana del arbol
    orden = r.orden or {}, orden2 = r.orden2, guia = r.guia, guia2 = r.guia2, tab = r.tab,
    profesiones = table.concat(nombres, " + "), ids = profs, faltan = faltan, eventos = eventos, botin = botin,
    sugerida = sugerida, mejores = r.mejores, faccion = faccion, clase = token,
    pesos = (subiendo and r.pesosSubir) or r.pesos, ramaPesos = subiendo and r.subir or r.nombre,
    ramaFinal = (r.cambio > 0) and r.nombre or nil, pesosFinal = (r.cambio > 0) and r.pesos or nil,
    manosFinal = (r.cambio > 0) and ((fin and fin.manos) or r.manos) or nil, dagaFinal = (r.cambio > 0) and fin and fin.daga or nil,
    objetivo = objetivo, objetivoInfo = (c.objetivos or {})[objetivo], recomendadas = c.recomendadas[objetivo] or {}, tengo = tengo,
  }
  claveCache = clave
  cache.prioridad = table.concat((r.cambio > 0 and nivelPj < r.cambio) and r.statsSubir or r.stats, " > ")
    cache.prioridadGuia = table.concat((r.cambio > 0 and nivelPj < r.cambio) and (r.statsGuiaSubir or {}) or (r.statsGuia or {}), " > ")
    cache.cambioNivel = r.cambio
    cache.prioridadSinGuia = (r.cambio > 0 and nivelPj < r.cambio) and (r.statsSinGuiaSubir and true or false) or (r.statsSinGuia and true or false)
  return cache
end

-- Nombre para mostrar: "Enhancement -> Elemental al 40" o "Elemental desde el principio"
function WowF.nombreRama(r)
  if r.cambio > 0 then return r.subir .. " -> " .. r.nombre .. " al " .. r.cambio end
  if r.puro then return r.nombre .. " desde el principio" end
  return r.nombre
end
-- 12-oct: lo que se MUESTRA (en ingles "Enhancement -> Elemental at level 40"); nombreRama sigue siendo la clave guardada
function WowF.nombreRamaVer(r)
  if not (WowF.enIngles and WowF.enIngles()) then return WowF.nombreRama(r) end
  if r.cambio > 0 then return r.subir .. " -> " .. r.nombre .. " at level " .. r.cambio end
  if r.puro then return r.nombre .. " from the start" end
  return r.nombre
end
-- Todas las ramas de tu clase para el selector: { {i, nombre, actual, subir, cambio, puro, stats} }
function WowF.listaRamas()
  local c = datosClase()
  if not c then return {} end
  local ri, origen = ramaIndice(c)
  local res = {}
  for i, r in ipairs(c.ramas) do
    table.insert(res, { i = i, nombre = WowF.nombreRamaVer(r), base = r.nombre, actual = (i == ri), origen = (i == ri) and origen or nil,
      subir = r.subir, cambio = r.cambio, puro = r.puro, stats = table.concat(r.stats or {}, " > "), recomendada = (i == (c.porDefecto or 1)) })
  end
  return res
end
-- Elegir una rama concreta (nil = volver a la de tus talentos)
function WowF.elegirRama(i)
  WowFExportarDB.rama = WowFExportarDB.rama or {}
  local c = datosClase()
  WowFExportarDB.rama[clavePersonaje()] = (i and c and c.ramas[i]) and WowF.nombreRama(c.ramas[i]) or nil
  cache, claveCache = nil, nil
end
-- Pasar a la siguiente rama (se guarda por personaje); devuelve el nombre
function WowF.cambiarRama()
  local c = datosClase()
  if not c then return nil end
  local ri = ramaIndice(c)
  local nueva = ri % #c.ramas + 1
  WowFExportarDB.rama = WowFExportarDB.rama or {}
  WowFExportarDB.rama[clavePersonaje()] = WowF.nombreRama(c.ramas[nueva])
  cache, claveCache = nil, nil
  return WowF.nombreRama(c.ramas[nueva])
end
