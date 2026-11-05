-- Forever Leveling Guide: como llegar a una mazmorra desde donde estas.
-- Arma el camino mas corto por zonas (a pie), zepelines, barcos y el Deeprun Tram, segun tu faccion, y lo explica paso a paso:
-- "Ve al zepelin de Durotar -> cogelo a Tirisfal Glades -> camina por Silverpine Forest hasta la entrada".
-- Un paso por tramo (pueblo, puerta, borde, transporte). El alfiler va SIEMPRE en el mapa de tu zona (si el punto queda fuera,
-- en el borde, en linea recta hacia el) y avanza solo al llegar; "Marcar la ruta en el mapa" dibuja el camino en el mapa (M).
-- Los textos traen los dos idiomas con L(es, en), como Rotacion y Bienvenida.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local AZUL = "|cff33ccffForever Guide|r: "
local ORO, VERDE, GRIS, BLANCO, NARANJA = "|cffffd100", "|cff33ff66", "|cff9d9d9d", "|cffffffff", "|cffff9933"

-- Zonas (uiMapID) con su nombre en ingles por si el cliente no lo da. 9-oct (CERO datos de Classic): ids y nombres = UiMap.csv del
-- cliente de WoW Forever (wago.tools, build de herramientas/fuente/BUILD.txt). Lo comprueba herramientas/pruebas/prueba-zonas-forever.mjs.
-- Zonas nuevas de Forever que aun no estan aqui (sin datos de por donde se entra a pie): Mount Hyjal 2482, Riverglades 2548, Shen'dralas 2652.
local ZONA = {
  [1411] = "Durotar", [1412] = "Mulgore", [1413] = "The Barrens", [1416] = "Alterac Mountains", [1417] = "Arathi Highlands",
  [1418] = "Badlands", [1419] = "Blasted Lands", [1420] = "Tirisfal Glades", [1421] = "Silverpine Forest",
  [1422] = "Western Plaguelands", [1423] = "Eastern Plaguelands", [1424] = "Hillsbrad Foothills", [1425] = "The Hinterlands",
  [1426] = "Dun Morogh", [1427] = "Searing Gorge", [1428] = "Burning Steppes", [1429] = "Elwynn Forest", [1430] = "Deadwind Pass",
  [1431] = "Duskwood", [1432] = "Loch Modan", [1433] = "Redridge Mountains", [1434] = "Stranglethorn Vale", [1435] = "Swamp of Sorrows",
  [1436] = "Westfall", [1437] = "Wetlands", [1438] = "Teldrassil", [1439] = "Darkshore", [1440] = "Ashenvale",
  [1441] = "Thousand Needles", [1442] = "Stonetalon Mountains", [1443] = "Desolace", [1444] = "Feralas", [1445] = "Dustwallow Marsh",
  [1446] = "Tanaris", [1447] = "Azshara", [1448] = "Felwood", [1449] = "Un'Goro Crater", [1450] = "Moonglade", [1451] = "Silithus",
  [1452] = "Winterspring", [1453] = "Stormwind City", [1454] = "Orgrimmar", [1455] = "Ironforge", [1456] = "Thunder Bluff",
  [1457] = "Darnassus", [1458] = "Undercity",
}
-- Zonas que se tocan a pie (el costo 1 = cruzar una zona; las peligrosas o enormes cuestan mas).
-- 9-oct: cada par esta comprobado con Forever: las dos zonas estan en el mismo continente y sus rectangulos de UiMapAssignment.csv
-- se tocan (prueba-zonas-forever.mjs). Por DONDE se cruza no lo trae ninguna tabla de Forever: el paso "borde" lo avisa al jugador.
local A_PIE = {
  -- Eastern Kingdoms
  { 1420, 1421 }, { 1420, 1422 }, { 1420, 1458, 0.3 }, { 1422, 1423 }, { 1421, 1424 }, { 1424, 1416 }, { 1424, 1417 }, { 1424, 1425 },
  { 1416, 1422 }, { 1417, 1437 }, { 1437, 1432 }, { 1426, 1455, 0.3 }, { 1426, 1432 }, { 1432, 1418 }, { 1418, 1427, 1.5 },
  { 1427, 1428, 1.5 }, { 1428, 1433, 1.5 }, { 1433, 1429 }, { 1429, 1453, 0.3 }, { 1429, 1436 }, { 1429, 1431 }, { 1436, 1431 },
  { 1433, 1431 }, { 1431, 1430 }, { 1430, 1435 }, { 1435, 1419 }, { 1431, 1434, 1.5 },
  -- Kalimdor
  { 1411, 1454, 0.3 }, { 1411, 1413, 1.5 }, { 1454, 1413, 1.5 }, { 1413, 1412, 1.5 }, { 1412, 1456, 0.3 }, { 1413, 1440, 1.5 }, { 1413, 1442, 1.5 },
  { 1413, 1445, 1.5 }, { 1413, 1441, 1.5 }, { 1442, 1440 }, { 1442, 1443 }, { 1443, 1444 }, { 1444, 1441 }, { 1441, 1446 }, { 1446, 1449 },
  { 1449, 1451 }, { 1440, 1439, 1.3 }, { 1440, 1448 }, { 1440, 1447 }, { 1448, 1452 }, { 1448, 1450 }, { 1452, 1450 }, { 1438, 1457, 0.3 },
}
-- Transportes: desde (mapa, x, y) -> hasta (mapa, x, y), faccion (0 las dos, 1 Horde, 2 Alliance), tipo, encargado, lugar.
-- Los barcos los puede usar cualquiera (los puertos de la Alliance solo cuestan mas a la Horde: ver HOSTIL)
-- 9-oct (CERO datos de Classic): fuente de cada punto, tablas del cliente de Forever (wago.tools, build 1.60.1.70291):
--   barcos y zepelines = paradas (Delay > 0) de TaxiPathNode de los caminos de transporte (TaxiPath 241 Booty Bay-Ratchet,
--   292 Menethil-Theramore, 293/295 Auberdine-Rut'theran/Menethil, 285/301/302 zepelines), pasadas al mapa con UiMapAssignment
--   (herramientas/mapas-forever.mjs). Los zepelines llevan la posicion del encargado (a menos de 15 yardas de la parada).
--   Deeprun Tram: Forever no trae la posicion de las entradas -> campo 11 = true = "aun sin confirmar en WoW Forever".
local TRANSPORTES = {
  { 1411, 50.8, 13.4, 1420, 60.8, 58.8, 1, "zep", "Frezza", { "la torre de zepelines al norte de Orgrimmar", "the zeppelin tower north of Orgrimmar" } },
  { 1420, 60.8, 58.8, 1411, 50.8, 13.4, 1, "zep", "Zapetta", { "la torre de zepelines junto a Undercity", "the zeppelin tower next to Undercity" } },
  { 1411, 50.6, 12.8, 1434, 31.4, 29.4, 1, "zep", "Snurk Bucksquick", { "la torre de zepelines al norte de Orgrimmar", "the zeppelin tower north of Orgrimmar" } },
  { 1434, 31.4, 29.4, 1411, 50.6, 12.8, 1, "zep", "Squibby Overspeck", { "Grom'gol Base Camp", "Grom'gol Base Camp" } },
  { 1420, 61.8, 59.0, 1434, 31.4, 29.8, 1, "zep", "Hin Denburg", { "la torre de zepelines junto a Undercity", "the zeppelin tower next to Undercity" } },
  { 1434, 31.4, 29.8, 1420, 61.8, 59.0, 1, "zep", "Nez'raz", { "Grom'gol Base Camp", "Grom'gol Base Camp" } },
  { 1437, 4.5, 56.7, 1439, 32.3, 44.1, 0, "barco", nil, { "el muelle de Menethil Harbor", "the Menethil Harbor dock" } },
  { 1439, 32.3, 44.1, 1437, 4.5, 56.7, 0, "barco", nil, { "el muelle de Auberdine", "the Auberdine dock" } },
  { 1437, 4.7, 63.8, 1445, 71.7, 56.7, 0, "barco", nil, { "el muelle de Menethil Harbor (el del sur)", "the Menethil Harbor dock (the southern one)" } },
  { 1445, 71.7, 56.7, 1437, 4.7, 63.8, 0, "barco", nil, { "el muelle de Theramore", "the Theramore dock" } },
  { 1439, 33.3, 39.8, 1438, 54.8, 97.2, 0, "barco", nil, { "el muelle de Auberdine (el del norte)", "the Auberdine dock (the northern one)" } },
  { 1438, 54.8, 97.2, 1439, 33.3, 39.8, 0, "barco", nil, { "el muelle de Rut'theran Village (desde Darnassus, el portal rosa te baja)", "the Rut'theran Village dock (from Darnassus, the pink portal takes you down)" } },
  { 1434, 25.7, 73.1, 1413, 63.8, 38.8, 0, "barco", nil, { "el muelle de Booty Bay", "the Booty Bay dock" } },
  { 1413, 63.8, 38.8, 1434, 25.7, 73.1, 0, "barco", nil, { "el muelle de Ratchet", "the Ratchet dock" } },
  { 1455, 76.3, 51.3, 1453, 69.0, 31.0, 2, "tranvia", nil, { "Tinker Town, en Ironforge", "Tinker Town, in Ironforge" }, true },
  { 1453, 69.0, 31.0, 1455, 76.3, 51.3, 2, "tranvia", nil, { "Dwarven District, en Stormwind", "Dwarven District, in Stormwind" }, true },
}
local COSTO = { zep = 2.5, barco = 2.5, tranvia = 1.5 }
-- Zonas de la otra faccion: entrar cuesta mas (guardias y jugadores enemigos). [1] = las que molestan a la Horde, [2] = a la Alliance
-- 9-oct, fuente de Forever: AreaTable.csv FactionGroupMask de la zona (2 = Alliance, 4 = Horde; ciudades incluidas) y, en las
-- disputadas (0), Wowhead /forever (fuente/wowhead/zonas.json): >= 20 misiones solo del otro bando y <= 1 del tuyo (Redridge 41/1,
-- Wetlands 60/0 = pueblos y guardias de la Alliance). Mismo criterio que AJENA de wowF_AreaMobs.lua; lo comprueba prueba-zonas-forever.mjs.
local HOSTIL = {
  [1] = { [1429] = true, [1436] = true, [1426] = true, [1432] = true, [1433] = true, [1438] = true, [1439] = true, [1437] = true, [1453] = true, [1455] = true, [1457] = true },
  [2] = { [1411] = true, [1412] = true, [1413] = true, [1420] = true, [1421] = true, [1454] = true, [1456] = true, [1458] = true },
}

local function nombreZona(m)
  if C_Map and C_Map.GetMapInfo then
    local ok, info = pcall(C_Map.GetMapInfo, m)
    if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" and ZONA[m] then return info.name end
  end
  return ZONA[m] or tostring(m)
end
WowF.nombreZona = nombreZona
local function miFaccion() return WowF.miFaccion and WowF.miFaccion() or 0 end

-- Zona del grafo donde estas: el mapa del jugador o el primero de sus padres que sea una zona conocida
local function zonaActual()
  if not C_Map or not C_Map.GetBestMapForUnit then return nil end
  local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
  local vueltas = 0
  while ok and m and vueltas < 6 do
    if ZONA[m] then return m end
    local ok2, info = pcall(C_Map.GetMapInfo, m)
    m = ok2 and type(info) == "table" and info.parentMapID or nil
    vueltas = vueltas + 1
  end
  return nil
end
local function posEn(m)
  if not C_Map or not C_Map.GetPlayerMapPosition then return nil end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, m, "player")
  if not ok or not pos then return nil end
  local x, y = pos.x, pos.y
  if (not x or not y) and pos.GetXY then x, y = pos:GetXY() end
  if not x or not y or (x == 0 and y == 0) then return nil end
  return x * 100, y * 100
end

-- Camino mas corto (Dijkstra) de la zona a hasta la zona b: lista de tramos { tipo = "pie" | transporte, de, a, t = transporte }
local function camino(a, b)
  local fac = miFaccion()
  local vecinos = {}
  local function unir(x, y, costo, t)
    vecinos[x] = vecinos[x] or {}
    table.insert(vecinos[x], { a = y, costo = costo, t = t })
  end
  local hostil = HOSTIL[fac] or {}
  local function pie(destino, costo) return costo + (hostil[destino] and destino ~= b and 0.7 or 0) end
  for _, e in ipairs(A_PIE) do unir(e[1], e[2], pie(e[2], e[3] or 1)); unir(e[2], e[1], pie(e[1], e[3] or 1)) end
  for _, t in ipairs(TRANSPORTES) do
    if t[7] == 0 or t[7] == fac or fac == 0 then unir(t[1], t[4], pie(t[4], COSTO[t[8]] or 2.5), t) end
  end
  local dist, previo, hecho = { [a] = 0 }, {}, {}
  while true do
    local u, du
    for n, d in pairs(dist) do if not hecho[n] and (not du or d < du) then u, du = n, d end end
    if not u or u == b then break end
    hecho[u] = true
    for _, v in ipairs(vecinos[u] or {}) do
      local nd = du + v.costo
      if not dist[v.a] or nd < dist[v.a] - 1e-9 then dist[v.a] = nd; previo[v.a] = { de = u, t = v.t } end
    end
  end
  if not dist[b] then return nil end
  local tramos, n = {}, b
  while n ~= a do
    local p = previo[n]
    table.insert(tramos, 1, { de = p.de, a = n, t = p.t })
    n = p.de
  end
  return tramos, dist[b]
end


-- ===================== Puntos de paso =====================
-- Puertas entre zonas que se conocen (verificadas en guias; las demas se cruzan "por el borde": el alfiler va al borde de tu zona,
-- en linea recta hacia el siguiente punto conocido). Clave = las dos zonas, la menor primero.
-- 9-oct: Forever no trae la posicion de estas puertas (ni wago.tools ni Wowhead /forever): campo 5 = true = el paso de la ruta
-- avisa "aun sin confirmar en WoW Forever". Quitar el true al confirmarla con una fuente de Forever.
local PUERTAS = {
  ["1412-1413"] = { 1412, 71, 61, { "el paso del este de Mulgore (sale junto a Camp Taurajo)", "the pass east of Mulgore (it comes out by Camp Taurajo)" }, true },
  ["1413-1454"] = { 1454, 16, 62, { "la puerta oeste de Orgrimmar", "the west gate of Orgrimmar" }, true },
  ["1411-1454"] = { 1411, 46, 12, { "la puerta principal de Orgrimmar", "the main gate of Orgrimmar" }, true },
  ["1411-1413"] = { 1413, 62, 20, { "el puente de Far Watch sobre el rio Southfury", "the Far Watch bridge over the Southfury River" }, true },
}
-- Pueblos con maestro de vuelo (posicion del maestro, de los datos del juego: TaxiNodes). 9-oct: comprobados los 45 con TaxiNodes de
-- Forever (wago.tools, build 1.60.1.70291) + UiMapAssignment: todos a menos de 5 yardas. Si uno queda de camino dentro de una zona,
-- se pone como paso intermedio ("Pasa por The Crossroads"). Faccion: 0 las dos, 1 Horde, 2 Alliance.
local PUEBLOS = {
  { 1413, 51.5, 30.4, "The Crossroads", 1 }, { 1413, 44.5, 59.1, "Camp Taurajo", 1 }, { 1413, 63.1, 37.1, "Ratchet", 0 },
  { 1421, 45.6, 42.4, "The Sepulcher", 1 }, { 1436, 56.6, 52.7, "Sentinel Hill", 2 }, { 1440, 34.5, 48.0, "Astranaar", 2 },
  { 1440, 73.3, 61.7, "Splintertree Post", 1 }, { 1440, 12.2, 33.8, "Zoram'gar Outpost", 1 }, { 1432, 33.9, 50.8, "Thelsamar", 2 },
  { 1433, 25.3, 59.0, "Lakeshire", 2 }, { 1431, 77.6, 44.4, "Darkshire", 2 }, { 1424, 60.2, 18.8, "Tarren Mill", 1 },
  { 1424, 49.4, 52.1, "Southshore", 2 }, { 1417, 45.8, 46.1, "Refuge Pointe", 2 }, { 1417, 73.1, 32.6, "Hammerfall", 1 },
  { 1441, 45.0, 49.1, "Freewind Post", 1 }, { 1434, 32.5, 29.3, "Grom'gol Base Camp", 1 }, { 1445, 67.5, 51.2, "Theramore", 2 },
  { 1445, 35.6, 31.8, "Brackenwall Village", 1 }, { 1446, 51.0, 29.3, "Gadgetzan", 0 }, { 1443, 64.7, 10.4, "Nijel's Point", 2 },
  { 1443, 21.6, 74.0, "Shadowprey Village", 1 }, { 1444, 75.4, 44.3, "Camp Mojache", 1 }, { 1444, 89.5, 45.9, "Thalanaar", 2 },
  { 1442, 45.2, 59.9, "Sun Rock Retreat", 1 }, { 1442, 36.5, 7.2, "Stonetalon Peak", 2 }, { 1435, 46.1, 54.7, "Stonard", 1 },
  { 1418, 4.1, 44.9, "Kargath", 1 }, { 1427, 37.9, 30.4, "Thorium Point", 0 }, { 1428, 84.4, 68.3, "Morgan's Vigil", 2 },
  { 1428, 65.6, 24.2, "Flame Crest", 1 }, { 1419, 65.5, 24.4, "Nethergarde Keep", 2 }, { 1422, 42.9, 85.0, "Chillwind Camp", 2 },
  { 1423, 71.7, 49.6, "Light's Hope Chapel", 0 }, { 1425, 11.1, 46.1, "Aerie Peak", 2 }, { 1425, 81.7, 81.9, "Revantusk Village", 1 },
  { 1448, 34.4, 53.9, "Bloodvenom Post", 1 }, { 1448, 62.5, 24.2, "Talonbranch Glade", 2 }, { 1452, 62.3, 36.6, "Everlook", 0 },
  { 1449, 45.3, 6.0, "Marshal's Refuge", 0 }, { 1451, 48.8, 36.7, "Cenarion Hold", 0 }, { 1447, 22.0, 49.7, "Valormok", 1 },
  { 1447, 11.9, 77.5, "Talrendis Point", 2 }, { 1439, 36.4, 45.6, "Auberdine", 2 }, { 1437, 9.5, 59.7, "Menethil Harbor", 2 },
}
-- Ciudades: AreaTable.csv de Forever, Flags_0 con el bit 0x100 (capital). 9-oct: fuera ELEVADOR (Thunder Bluff/Undercity "por el elevador"
-- era de memoria de Classic; Forever no trae los elevadores en sus tablas).
local CIUDAD = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }

-- ===================== Mapas: de un mapa a otro por coordenadas del mundo =====================
-- 4-oct: antes se usaba GetMapRectOnMap entre mapas hermanos (Orgrimmar no esta dentro de Mulgore) y el punto salia en el borde
-- oeste de Mulgore. Ahora: mapa -> mundo -> mapa visto, con las esquinas de cada mapa.
local function enMundo(m, x, y)
  if not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return nil end
  local ok, cont, v = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x / 100, y / 100))
  if not ok or not v or not v.GetXY then return nil end
  local wx, wy = v:GetXY()
  if not wx then return nil end
  return wx, wy, cont
end
local esquinas = {}
local function limites(m)
  if esquinas[m] ~= nil then return esquinas[m] end
  local x0, y0, c0 = enMundo(m, 0, 0)
  local x1, y1, c1 = enMundo(m, 100, 100)
  local r = false
  if x0 and x1 and c0 == c1 and x0 ~= x1 and y0 ~= y1 then r = { x0, y0, x1, y1, c0 } end
  if x0 then esquinas[m] = r end -- sin datos aun (cargando): no se guarda
  return r
end
local function esAntepasado(arriba, m)
  local vueltas = 0
  while m and vueltas < 6 do
    local ok, info = pcall(C_Map.GetMapInfo, m)
    m = ok and type(info) == "table" and info.parentMapID or nil
    if m == arriba then return true end
    vueltas = vueltas + 1
  end
  return false
end
-- (m, x, y) en coordenadas del mapa destino (0-100; puede salir fuera de 0-100), o nil si no se puede saber
local function proyectar(m, x, y, destino)
  if not m or not destino or not x then return nil end
  if m == destino then return x, y end
  local wx, wy, c = enMundo(m, x, y)
  local L4 = limites(destino)
  if wx and L4 and c == L4[5] then
    return (L4[2] - wy) / (L4[2] - L4[4]) * 100, (L4[1] - wx) / (L4[1] - L4[3]) * 100
  end
  -- Sin coordenadas del mundo: GetMapRectOnMap solo vale si el mapa visto CONTIENE al otro (zona dentro del continente)
  if C_Map and C_Map.GetMapRectOnMap and esAntepasado(destino, m) then
    local ok, izq, der, arr, aba = pcall(C_Map.GetMapRectOnMap, m, destino)
    if ok and izq and der and der ~= izq then return (izq + (der - izq) * x / 100) * 100, (arr + (aba - arr) * y / 100) * 100 end
  end
  return nil
end
WowF.proyectar = proyectar
local function dentro(x, y, margen) margen = margen or 0; return x and y and x >= -margen and x <= 100 + margen and y >= -margen and y <= 100 + margen end
-- Distancia en yardas entre dos puntos (mapa, x, y); nil si no se sabe
local function yardas(a, b)
  local ax, ay, ac = enMundo(a[1], a[2], a[3])
  local bx, by, bc = enMundo(b[1], b[2], b[3])
  if not ax or not bx or ac ~= bc then return nil end
  return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- Pasos para mostrar: uno por cada tramo (puerta entre zonas, pueblo de camino, muelle, transporte y llegada).
-- 4-oct (Andy: "PASO 1 DE 1" para cruzar 4 zonas): antes los tramos a pie se juntaban en un solo paso.
-- Cada paso: tipo ("pie" con punto, "borde" sin punto, "transporte"), texto, detalle, corto, m/x/y, zonas (donde se camina), sig (zona a la que pasas)
local function nombreTransporte(t)
  if t[8] == "zep" then return L("zepelin", "zeppelin") elseif t[8] == "tranvia" then return "Deeprun Tram" end
  return L("barco", "boat")
end
-- "Ve a el muelle" -> "Ve al muelle" (los nombres de sitios empiezan con articulo)
local function al(s) return (s:gsub("^Ve a (|c%x%x%x%x%x%x%x%x)el ", "Ve al %1"):gsub("^Ve a el ", "Ve al ")) end
local function armarPasos(m, inicio)
  local tramos = camino(inicio, m.m)
  if not tramos then return nil end
  local fac = miFaccion()
  local pasos = {}
  local cur, entrada = inicio, nil -- zona donde caminas y punto conocido por donde entraste en ella
  local function donde(p) return L("Esta en ", "It is in ") .. nombreZona(p[1]) .. ", " .. string.format("%.0f, %.0f", p[2], p[3]) .. "." end
  -- Pueblo de camino entre la entrada y la salida de la zona (solo si casi no te desvia)
  local function pueblo(salida)
    if not entrada or not salida then return end
    local recto = yardas(entrada, salida)
    if not recto or recto < 600 then return end
    local mejor, extra
    for _, v in ipairs(PUEBLOS) do
      if v[1] == cur and (v[5] == 0 or v[5] == fac or fac == 0) then
        local a, b = yardas(entrada, v), yardas(v, salida)
        if a and b and a > 250 and b > 250 and (a + b) <= recto * 1.15 and (not extra or a + b < extra) then mejor, extra = v, a + b end
      end
    end
    if mejor then
      table.insert(pasos, { tipo = "pie", via = true, texto = L("Pasa por ", "Go through ") .. ORO .. mejor[4] .. "|r",
        detalle = donde(mejor) .. L(" Es un pueblo con maestro de vuelo: sigue el camino desde alli.", " It is a town with a flight master: follow the road from there."),
        corto = mejor[4], m = mejor[1], x = mejor[2], y = mejor[3], zonas = { cur }, titulo = mejor[4] })
      entrada = { mejor[1], mejor[2], mejor[3] }
    end
  end
  for _, tr in ipairs(tramos) do
    if tr.t then
      local t = tr.t
      local nombre, llega = nombreTransporte(t), nombreZona(t[4])
      pueblo({ t[1], t[2], t[3] })
      local que = L(t[10][1], t[10][2]) .. L(", donde sale el ", ", where the ") .. nombre .. L(" a ", " to ") .. ORO .. llega .. "|r" .. L("", " leaves")
      table.insert(pasos, { tipo = "pie", texto = al(L("Ve a ", "Go to ") .. que), detalle = donde({ t[1], t[2], t[3] }) .. (t[11] and (" " .. L("Posicion aun sin confirmar en WoW Forever: se actualizara.", "Position not confirmed in WoW Forever yet: it will be updated.")) or ""), corto = L("ir al ", "go to the ") .. nombre,
        m = t[1], x = t[2], y = t[3], zonas = { cur }, titulo = nombre .. " > " .. llega })
      local texto, detalle
      if t[8] == "tranvia" then
        texto = L("Sube al Deeprun Tram hacia ", "Ride the Deeprun Tram to ") .. ORO .. llega .. "|r"
        detalle = L("Espera en el anden a que llegue el vagon y subete. Bajate al final del tunel, en ", "Wait on the platform for the car and get on. Get off at the end of the tunnel, in ") .. llega .. "."
      else
        texto = L("Sube al ", "Take the ") .. nombre .. L(" hacia ", " to ") .. ORO .. llega .. "|r"
        detalle = L("Quedate en ese mismo sitio: el ", "Stay right there: the ") .. nombre .. L(" llega en 1 o 2 minutos. Subete y bajate cuando llegue a ", " arrives in 1 or 2 minutes. Get on and get off when it reaches ") .. llega .. "."
        if t[9] then detalle = detalle .. L(" (Encargado: ", " (Zeppelin master: ") .. t[9] .. L("; preguntale si dudas cual es.)", "; ask him if unsure which one.)") end
      end
      table.insert(pasos, { tipo = "transporte", texto = texto, detalle = detalle, corto = nombre .. " > " .. llega,
        m = t[1], x = t[2], y = t[3], hasta = t[4], llegada = { t[5], t[6] }, zonas = { t[1] }, titulo = nombre })
      cur, entrada = t[4], { t[4], t[5], t[6] }
    else
      local a, b = tr.de, tr.a
      local pu = PUERTAS[math.min(a, b) .. "-" .. math.max(a, b)]
      local zb = nombreZona(b)
      if pu then
        pueblo({ pu[1], pu[2], pu[3] })
        table.insert(pasos, { tipo = "pie", puerta = true, texto = al(L("Ve a ", "Go to ") .. ORO .. L(pu[4][1], pu[4][2]) .. "|r" .. L(" y pasa a ", " and cross into ") .. zb),
          detalle = donde(pu) .. (pu[5] and (" " .. L("Posicion aun sin confirmar en WoW Forever: se actualizara.", "Position not confirmed in WoW Forever yet: it will be updated.")) or ""), corto = L(pu[4][1], pu[4][2]), m = pu[1], x = pu[2], y = pu[3], zonas = { cur }, sig = b, titulo = zb })
        entrada = { pu[1], pu[2], pu[3] }
      else
        local texto
        if CIUDAD[a] then texto = L("Sal de ", "Leave ") .. nombreZona(a) .. L(" hacia ", " towards ") .. ORO .. zb .. "|r"
        elseif CIUDAD[b] then texto = L("Entra en ", "Enter ") .. ORO .. zb .. "|r"
        else texto = L("Cruza de ", "Cross from ") .. nombreZona(a) .. L(" a ", " into ") .. ORO .. zb .. "|r" end
        table.insert(pasos, { tipo = "borde", texto = texto,
          detalle = L("Sigue el camino hacia ", "Follow the road towards ") .. zb .. L(". El alfiler va en el borde de ", ". The pin is on the edge of ") .. nombreZona(a) .. L(", por donde tienes que salir.", ", where you have to leave.")
            .. L(" Por donde se cruza exactamente aun no esta confirmado en WoW Forever: se actualizara.", " The exact crossing point is not confirmed in WoW Forever yet: it will be updated."),
          corto = zb, zonas = { cur }, sig = b, titulo = zb })
        entrada = nil
      end
      cur = b
    end
  end
  pueblo({ m.m, m.x, m.y })
  if m.final then -- 5-oct: paso final a medida (lineas de misiones, wowF_LineaMisiones.lua): "Mata X...", "Entrega Y a Z"
    table.insert(pasos, { tipo = "pie", mision = true, texto = m.final.texto, detalle = donde({ m.m, m.x, m.y }) .. (m.final.detalle and (" " .. m.final.detalle) or ""),
      corto = m.final.corto or m.n, m = m.m, x = m.x, y = m.y, zonas = { cur }, titulo = m.final.titulo or m.n })
  elseif m.mision then
    local q = m.mision
    table.insert(pasos, { tipo = "pie", mision = true, texto = L("Habla con ", "Talk to ") .. ORO .. q.quien .. "|r" .. L(" y acepta ", " and accept ") .. BLANCO .. q.nombre .. "|r",
      detalle = donde({ m.m, m.x, m.y }) .. L(" Lo marco con un ! dorado que late y \"HABLA AQUI\" junto a su nombre. Es la mision de ", " I mark it with a pulsing gold ! and \"TALK HERE\" next to the name. It is the quest for ") .. q.mazmorra
        .. L(": aceptala ahora y se termina DENTRO de la mazmorra.", ": accept it now; it is finished INSIDE the dungeon.") .. ((q.xp or 0) > 0 and (" " .. WowF.textoXP(WowF.xpMision(q))) or ""),
      corto = L("mision: ", "quest: ") .. q.quien, m = m.m, x = m.x, y = m.y, zonas = { cur }, titulo = q.quien })
  else
    table.insert(pasos, { tipo = "pie", texto = L("Ve a la entrada de ", "Go to the entrance of ") .. ORO .. m.n .. "|r", detalle = donde({ m.m, m.x, m.y }),
      corto = m.n, m = m.m, x = m.x, y = m.y, zonas = { cur }, titulo = m.n })
  end
  pasos[#pasos].final = true
  return pasos
end

-- ===================== Viaje en curso =====================
local viaje -- { maz, pasos, i, dibujar }
local ventana, textoVentana, botonMapa
local dibujarMapa, actualizarVentana, actualizarRumbo

-- El punto conocido al que lleva el paso i (el suyo o, si es "por el borde", el del siguiente paso que tenga punto)
local function puntoDe(i)
  if not viaje then return nil end
  for j = i, #viaje.pasos do
    local p = viaje.pasos[j]
    if p.m and p.x then return p end
  end
  return nil
end
-- Donde va el alfiler AHORA: siempre en el mapa de la zona donde estas. Si el punto cae fuera de tu zona, en su borde,
-- en linea recta desde ti hacia el punto (4-oct: antes iba en el mapa del paso, p. ej. Orgrimmar, y no se veia desde Mulgore).
local function recortar(px, py, tx, ty, lo, hi)
  px = math.max(lo, math.min(hi, px)); py = math.max(lo, math.min(hi, py))
  local dx, dy, s = tx - px, ty - py, 1
  if tx < lo then s = math.min(s, (lo - px) / dx) elseif tx > hi then s = math.min(s, (hi - px) / dx) end
  if ty < lo then s = math.min(s, (lo - py) / dy) elseif ty > hi then s = math.min(s, (hi - py) / dy) end
  s = math.max(0, s)
  return px + dx * s, py + dy * s
end
local function objetivo()
  if not viaje then return nil end
  local p = viaje.pasos[viaje.i]
  if not p then return nil end
  local t = puntoDe(viaje.i)
  if not t then return nil end
  local aqui = zonaActual()
  if p.tipo == "transporte" and aqui ~= p.m then return nil end -- de viaje: el alfiler se queda donde estaba
  if not aqui then return { m = t.m, x = t.x, y = t.y } end
  local tx, ty = proyectar(t.m, t.x, t.y, aqui)
  if not tx then return { m = t.m, x = t.x, y = t.y } end
  if dentro(tx, ty) then return { m = aqui, x = tx, y = ty, exacto = (p.m ~= nil) } end
  local px, py = posEn(aqui)
  local cx, cy = recortar(px or 50, py or 50, tx, ty, 3, 97)
  return { m = aqui, x = cx, y = cy, borde = true }
end
WowF._objetivoViaje = objetivo -- para las pruebas

local alfiler, tomtomUid -- el ultimo puesto (para no ponerlo cada segundo)
-- Alfiler que tiene el juego ahora (0-100), o nil
WowF._leerAlfiler = function()
  if not (C_Map and C_Map.GetUserWaypoint) then return nil end
  local ok, wp = pcall(C_Map.GetUserWaypoint)
  if not ok or type(wp) ~= "table" then return nil end
  local pos = wp.position
  local m, x, y = tonumber(wp.uiMapID), pos and tonumber(pos.x), pos and tonumber(pos.y)
  if not (m and x and y) then return nil end
  return { m = m, x = x * 100, y = y * 100 }
end
local function ponerAlfiler(o, forzar)
  if not o then return false end
  if not forzar and alfiler and alfiler.m == o.m and math.abs(alfiler.x - o.x) < 2 and math.abs(alfiler.y - o.y) < 2 then return true end
  local puesto = false
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    puesto = pcall(function()
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(o.m, o.x / 100, o.y / 100))
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end)
  end
  if TomTom and TomTom.AddWaypoint then
    if tomtomUid and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, tomtomUid) end
    local ok, uid = pcall(TomTom.AddWaypoint, TomTom, o.m, o.x / 100, o.y / 100, { title = (viaje and viaje.pasos[viaje.i] and viaje.pasos[viaje.i].titulo) or "Forever Guide" })
    if ok then puesto = true; tomtomUid = uid end
  end
  alfiler = { m = o.m, x = o.x, y = o.y }
  alfiler.real = WowF._leerAlfiler() -- lo que el juego guardo de verdad (redondeo o mapa sin alfiler)
  return puesto
end
local function quitarAlfiler()
  alfiler = nil
  if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
  if tomtomUid and TomTom and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, tomtomUid) end
  tomtomUid = nil
end

local function textoPaso(i)
  local p = viaje.pasos[i]
  return ORO .. L("PASO ", "STEP ") .. i .. "|r: " .. p.texto
end

-- Hacia donde y a cuanto esta el alfiler desde donde estas: "al noreste, a 320 yardas" (nil si no se sabe)
local RUMBOS = { { "norte", "north" }, { "noreste", "northeast" }, { "este", "east" }, { "sureste", "southeast" },
  { "sur", "south" }, { "suroeste", "southwest" }, { "oeste", "west" }, { "noroeste", "northwest" } }
local function rumbo(o)
  local aqui = zonaActual()
  if not aqui or not o then return nil end
  local x, y = posEn(aqui)
  if not x then return nil end
  local norte, este, yd
  local px, py, pc = enMundo(aqui, x, y)
  local tx, ty, tc = enMundo(o.m, o.x, o.y)
  if px and tx then
    if pc ~= tc then return nil, true end -- otro continente
    norte, este = tx - px, -(ty - py) -- en el mundo: x = norte, y = oeste
    yd = math.sqrt(norte ^ 2 + este ^ 2)
  elseif aqui == o.m then
    norte, este = y - o.y, o.x - x -- en el mapa: y crece hacia el sur
  else
    return nil
  end
  local atan2 = math.atan2 or math.atan
  local grados = math.deg(atan2(este, norte)) % 360
  local r = RUMBOS[math.floor((grados + 22.5) / 45) % 8 + 1]
  return { rumbo = L(r[1], r[2]), clave = r[2], grados = grados, yardas = yd, cerca = (yd and yd < 25) or (not yd and math.sqrt(norte ^ 2 + este ^ 2) < 1.5) }
end
WowF._rumboViaje = function() return rumbo(objetivo()) end -- para las pruebas
local function textoRumbo(p)
  if not p then return "" end
  local o = objetivo()
  local r, otro = rumbo(o)
  if otro then return NARANJA .. L("Esta en otro continente: sigue los pasos.", "It is on another continent: follow the steps.") .. "|r" end
  if not r then
    if p.tipo == "transporte" and zonaActual() ~= p.m then return VERDE .. L("Viajando... bajate al llegar.", "Travelling... get off when you arrive.") .. "|r" end
    return GRIS .. L("Sigue el alfiler del mapa.", "Follow the map pin.") .. "|r"
  end
  if r.cerca and not o.borde then
    if p.tipo == "transporte" then return VERDE .. L("Ya estas aqui: espera y subete.", "You are here: wait and get on.") .. "|r" end
    return VERDE .. L("Ya casi: esta aqui mismo.", "Almost there: it is right here.") .. "|r"
  end
  return VERDE .. L("Ve hacia el ", "Head ") .. string.upper(r.rumbo) .. "|r" ..
    (r.yardas and (BLANCO .. L(", a ", ", ") .. string.format("%d", math.floor(r.yardas / 10 + 0.5) * 10) .. L(" yardas", " yards") .. "|r") or "") ..
    GRIS .. (o.borde and L(" (alfiler en el borde de la zona)", " (pin on the zone edge)") or L(" (alfiler del mapa)", " (map pin)")) .. "|r"
end
local function irAlPaso(i, avisar)
  viaje.i = i
  local p = viaje.pasos[i]
  WowFExportarDB.viaje = { n = viaje.maz.n, i = i, dibujar = viaje.dibujar, destino = (viaje.maz.mision or viaje.maz.final) and viaje.maz or nil }
  if p then
    ponerAlfiler(objetivo(), true)
    if avisar then
      print(AZUL .. ORO .. L("PASO ", "STEP ") .. i .. L(" DE ", " OF ") .. #viaje.pasos .. "|r: " .. p.texto)
      if p.detalle then print("   " .. GRIS .. p.detalle .. "|r") end
    end
  end
  if dibujarMapa then pcall(dibujarMapa) end
  if actualizarVentana then actualizarVentana() end
  if avisar and ventana and viaje then
    if not WowF._viajeFusion() then ventana:Show()
    elseif WowF.lineaMostrar then pcall(WowF.lineaMostrar) end -- ruta de la linea: va dentro de su ventana
  end
  if WowF.lineaRefrescar then pcall(WowF.lineaRefrescar) end -- la ventana de la linea de misiones ensena el paso que toca
end

local function pararViaje(callado, dejarAlfiler)
  local habia = viaje ~= nil
  viaje = nil
  WowFExportarDB.viaje = nil
  if habia and dejarAlfiler then
    alfiler = nil
    if tomtomUid and TomTom and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, tomtomUid) end
    tomtomUid = nil
  elseif habia then quitarAlfiler() end
  if dibujarMapa then pcall(dibujarMapa) end
  if ventana then ventana:Hide() end
  if WowF.dibujarMisionesMazmorra then pcall(WowF.dibujarMisionesMazmorra) end
  if WowF.panelActualizar then pcall(WowF.panelActualizar) end
  if not callado then print(AZUL .. L("ruta quitada.", "route removed.")) end
end

-- Limpiar el mapa de un clic: quita TODAS las rutas (mazmorra, mision, farmeo), sus marcas, el alfiler y el recuadro
function WowF.limpiarRutas(callado)
  pararViaje(true)
  if WowF.pararRutaFarmeo then pcall(WowF.pararRutaFarmeo, true) end
  WowF.entrenadorElegido = nil
  quitarAlfiler()
  if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
  if WowF.dibujarEntrenadores then pcall(WowF.dibujarEntrenadores) end
  if WowF.quitarMisionesMarcadas then pcall(WowF.quitarMisionesMarcadas) end
  if WowF.quitarMarcaNPC then pcall(WowF.quitarMarcaNPC) end
  if WowF.quitarAreaMobs then pcall(WowF.quitarAreaMobs) end
  if WowF.quitarRareElegido then pcall(WowF.quitarRareElegido) end -- 19-oct: el rare marcado en la pestana Rares
  if WowF.dibujarMisionesMazmorra then pcall(WowF.dibujarMisionesMazmorra) end
  if WowF.panelActualizar then pcall(WowF.panelActualizar) end
  if not callado then print(AZUL .. L("mapa limpio: rutas, marcas y alfiler quitados.", "map cleared: routes, marks and pin removed.")) end
end
-- 17-oct (CurseForge, SilentCipherX: "click the trainer... it gets overridden instantly by next quest"): marcar otro sitio a mano
-- (entrenador desde el Libro o Profesiones, vendedor, hierbas...) dejaba la ruta de antes viva y cada segundo devolvia el alfiler
-- a su paso. Ahora el alfiler nuevo quita esa ruta (una sola a la vez); el fallback de la misma ruta (m == viaje.maz) no la toca.
-- Botones que ponen el alfiler sin WowF.marcar (BiS, consumibles, zonas, clic en el mapa): revisar() ve que el alfiler del juego
-- ya no es el de la ruta y la aparta SIN borrarlo. La linea de misiones tampoco lo pisa al entregar (WowF.alfilerManualVivo).
do
  local marcarAntes = WowF.marcar
  local function igual(a, b) return a and b and a.m == b.m and math.abs(a.x - b.x) < 1 and math.abs(a.y - b.y) < 1 end
  if marcarAntes then
    WowF.marcar = function(m, ...)
      if viaje and m ~= viaje.maz then pararViaje(true) end
      local r = marcarAntes(m, ...)
      if not WowF.marcandoLinea and type(m) == "table" and tonumber(m.m) and tonumber(m.x) then
        WowF.alfilerManual = WowF._leerAlfiler() or { m = tonumber(m.m), x = tonumber(m.x), y = tonumber(m.y) or 0 }
      end
      return r
    end
  end
  WowF._alfilerAjenoEnRuta = function()
    if not (viaje and alfiler) then return false end
    local wp = WowF._leerAlfiler()
    if not wp or igual(wp, alfiler.real or alfiler) then return false end
    WowF.alfilerManual = wp
    pararViaje(true, true)
    print(AZUL .. L("dejo tu alfiler donde lo pusiste; la ruta queda en pausa. Para seguirla, haz clic otra vez en el destino.",
      "your pin stays where you put it; the route is paused. To follow it again, click the destination again."))
    return true
  end
  -- true si el alfiler que pusiste a mano sigue en el juego (la linea de misiones no lo pisa al avanzar)
  WowF.alfilerManualVivo = function()
    local wp = WowF.alfilerManual and WowF._leerAlfiler()
    if wp and igual(wp, WowF.alfilerManual) then return true end
    WowF.alfilerManual = nil
    return false
  end
end
function WowF.hayRutaActiva()
  return viaje ~= nil or (WowF.rutaFarmeoActiva and WowF.rutaFarmeoActiva()) or WowF.entrenadorElegido ~= nil
    or (WowF.misionesMarcadasDe and WowF.misionesMarcadasDe() ~= nil) or false
end

-- 17-oct (CurseForge, mmjau: "Fly to the flight path XX, or if you do not have it follow the path"): la ruta va a pie; si el destino
-- esta en otra zona, se avisa del vuelo: maestro de vuelo cerca de ti -> el mas cercano al destino. Capitales: TaxiNodes de Forever
-- (Stormwind, Ironforge, Undercity, Thunder Bluff, Orgrimmar y Rut'theran Village para Darnassus); facciones: 1 Horde, 2 Alliance.
-- Capitales: { mapa, nombre, faccion, X, Y y continente del mundo (Pos_0, Pos_1, ContinentID de TaxiNodes) }
WowF.vueloCapital = { { 1453, "Stormwind", 2, -8832.8, 478.6, 0 }, { 1455, "Ironforge", 2, -4821.8, -1155.4, 0 },
  { 1457, "Rut'theran Village", 2, 8643.6, 841.0, 1 }, { 1454, "Orgrimmar", 1, 1677.6, -4315.7, 1 },
  { 1456, "Thunder Bluff", 1, -1197.2, 29.7, 1 }, { 1458, "Undercity", 1, 1568.6, 268.0, 0 } }
local function pistaVuelo(m, inicio)
  if not m.x or not m.y or inicio == m.m then return nil end
  local fac = miFaccion()
  -- todos los maestros de vuelo de tu faccion, en coordenadas del mundo
  local nodos = {}
  for _, c in ipairs(WowF.vueloCapital) do
    if fac == 0 or c[3] == fac then nodos[#nodos + 1] = { m = c[1], n = c[2], wx = c[4], wy = c[5], c = c[6], cap = true } end
  end
  for _, v in ipairs(PUEBLOS) do
    if v[5] == 0 or fac == 0 or v[5] == fac then
      local wx, wy, c = enMundo(v[1], v[2], v[3])
      if wx then nodos[#nodos + 1] = { m = v[1], n = v[4], x = v[2], y = v[3], wx = wx, wy = wy, c = c } end
    end
  end
  local function cerca(wx, wy, c)
    local mejor, dm
    for _, n in ipairs(nodos) do
      if n.c == c then
        local d = math.sqrt((n.wx - wx) ^ 2 + (n.wy - wy) ^ 2)
        if not dm or d < dm then mejor, dm = n, d end
      end
    end
    return mejor, dm
  end
  -- llegada: el maestro de vuelo mas cercano al destino (a menos de 1300 yardas; si no, no sirve)
  local dx, dy, dc = enMundo(m.m, m.x, m.y)
  if not dx then return nil end
  local llegar, dLlegar = cerca(dx, dy, dc)
  if not llegar or dLlegar > 1300 or llegar.m == inicio then return nil end
  -- salida: el mas cercano a ti (sin posicion: tu capital o un pueblo de tu zona)
  local salir
  local px, py = posEn(inicio)
  local yx, yy, yc
  if px then yx, yy, yc = enMundo(inicio, px, py) end
  if yx then
    if math.sqrt((yx - dx) ^ 2 + (yy - dy) ^ 2) < 1500 then return nil end -- cerca: a pie
    salir = cerca(yx, yy, yc)
  else
    for _, n in ipairs(nodos) do if n.m == inicio then salir = n; break end end
  end
  if not salir or salir == llegar then return nil end
  local function sitio(v) return ORO .. v.n .. "|r" .. (v.x and (GRIS .. " (" .. nombreZona(v.m) .. string.format(" %.0f, %.0f", v.x, v.y) .. ")|r") or "") end
  return L("Vuelo: si ya tienes la ruta de vuelo a ", "Flight: if you have the flight path to ") .. sitio(llegar)
    .. L(", ve al maestro de vuelo de ", ", go to the flight master in ") .. sitio(salir)
    .. L(" y vuela. Si no la tienes, sigue los pasos a pie.", " and fly there. If you do not have it, follow the steps on foot.")
end
WowF._pistaVuelo = function(m) local z = zonaActual(); return z and pistaVuelo(m, z) end -- pruebas
-- Empieza el viaje a la mazmorra m. Devuelve true si pudo armar la ruta (si no, el que llama pone solo el alfiler).
function WowF.viajeA(m, opciones)
  opciones = opciones or {}
  if not m or not m.m then return false end
  WowF.alfilerManual = nil -- elegiste una ruta: ya no hay alfiler a mano que respetar
  local inicio = zonaActual()
  if not inicio then return false end
  local pasos = armarPasos(m, inicio)
  if not pasos then return false end
  -- Solo UNA ruta a la vez: la de farmeo y el entrenador elegido se quitan (no al rehacer esta misma ruta)
  if not opciones.callado then
    if WowF.pararRutaFarmeo then pcall(WowF.pararRutaFarmeo, true) end
    if WowF.entrenadorElegido then WowF.entrenadorElegido = nil; if WowF.dibujarEntrenadores then pcall(WowF.dibujarEntrenadores) end end
  end
  -- 6-oct: una ruta a otro sitio (entrada de mazmorra, zona) quita la marca del NPC de antes
  if not opciones.callado and not m.mision and not m.final and WowF.quitarMarcaNPC then pcall(WowF.quitarMarcaNPC) end
  viaje = { maz = m, pasos = pasos, i = 1, dibujar = opciones.dibujar or false }
  local okV, pv = pcall(pistaVuelo, m, inicio)
  viaje.vuelo = okV and pv or nil
  if not opciones.callado then
    if m.final then
      print(AZUL .. L("como llegar: ", "how to get there: ") .. (m.final.titulo and (ORO .. m.final.titulo .. "|r") or m.n) .. GRIS .. " (" .. nombreZona(m.m) .. ")|r:")
    elseif m.mision then
      print(AZUL .. L("como llegar a quien da la mision ", "how to reach the quest giver for ") .. BLANCO .. m.mision.nombre .. "|r" .. GRIS .. " (" .. m.mision.mazmorra .. ")|r:")
    else
      print(AZUL .. L("como llegar a ", "how to get to ") .. ORO .. m.n .. "|r" .. GRIS .. " (" .. nombreZona(m.m) .. ")|r:")
    end
    if viaje.vuelo then print("  |cff66ccff" .. viaje.vuelo:gsub("|r", "|r|cff66ccff") .. "|r") end
    for i = 1, #pasos do print("  " .. textoPaso(i)); if pasos[i].detalle then print("     " .. GRIS .. pasos[i].detalle .. "|r") end end
    if m.a then print(GRIS .. L("  Posicion de la entrada aun sin confirmar en WoW Forever: se actualizara.", "  Entrance position not confirmed in WoW Forever yet: it will be updated.") .. "|r") end
    print(GRIS .. L("  El alfiler del mapa va SIEMPRE en tu zona, hacia el paso que toca, y pasa solo al siguiente cuando llegas. Si ya tienes la ruta de vuelo, vuela: es mas rapido.",
      "  The map pin is ALWAYS in your zone, towards the current step, and moves on by itself when you arrive. If you already have the flight path, fly: it is faster.") .. "|r")
  end
  irAlPaso(opciones.paso and pasos[opciones.paso] and opciones.paso or 1, false)
  if not opciones.callado and ventana then ventana:Show(); actualizarVentana() end
  if WowF.panelActualizar then pcall(WowF.panelActualizar) end
  return true
end
-- Los pasos para mostrar en otra parte (pruebas, Libro): { texto, ... } y el indice del paso que toca
function WowF.viajeMision() return viaje and viaje.maz.mision and viaje.maz or nil end
function WowF.viajePasos()
  if not viaje then return nil end
  local t = {}
  for i, p in ipairs(viaje.pasos) do t[i] = { texto = p.texto, tipo = p.tipo, m = p.m, x = p.x, y = p.y, hasta = p.hasta, llegada = p.llegada, sig = p.sig, zonas = p.zonas, via = p.via, puerta = p.puerta, final = p.final } end
  return t, viaje.i, viaje.maz.n
end
-- Para las pruebas: el camino de zona a zona como texto
function WowF._camino(a, b)
  local tr = camino(a, b)
  if not tr then return nil end
  local partes = { tostring(a) }
  for _, x in ipairs(tr) do table.insert(partes, (x.t and (x.t[8] .. ">") or "") .. x.a) end
  return table.concat(partes, " ")
end
-- Lo que cuesta ir de la zona a a la b (1 = cruzar una zona a pie; nil = no hay camino). Lo usa el plan de zonas (wowF_SubirZonas.lua)
function WowF.costoViaje(a, b)
  if not a or not b then return nil end
  if a == b then return 0 end
  local tr, c = camino(a, b)
  return tr and c or nil
end
WowF.zonaActual = zonaActual
WowF.pararViaje = pararViaje
-- 11-oct (diario): los pasos de la ruta a la mazmorra SIN ponerla en marcha (para mostrar 3-4 lineas en la ficha).
-- nil = no hay entrada conocida, no se sabe donde estas o no hay camino.
function WowF.pasosHacia(m)
  if type(m) ~= "table" or not m.m then return nil end
  local inicio = zonaActual()
  if not inicio then return nil end
  local ok, pasos = pcall(armarPasos, m, inicio)
  if not ok or type(pasos) ~= "table" then return nil end
  local t = {}
  for i, p in ipairs(pasos) do t[i] = { texto = p.texto, corto = p.corto, detalle = p.detalle, tipo = p.tipo } end
  return t, inicio
end

-- Se revisa cada segundo: al llegar al punto pasa al siguiente paso; al cambiar de zona por la puerta o el borde, tambien;
-- al bajar del transporte, tambien. Si apareces en una zona que no es del camino (otro barco, piedra de hogar), la ruta se rehace.
local reloj = 0
local function tiene(p, z) for _, x in ipairs(p.zonas or {}) do if x == z then return true end end return false end
local function revisar()
  if not viaje then return end
  local p = viaje.pasos[viaje.i]
  if not p then return end
  if WowF._alfilerAjenoEnRuta and WowF._alfilerAjenoEnRuta() then return end
  local aqui = zonaActual()
  if p.tipo == "transporte" then
    if aqui == p.hasta then
      print(AZUL .. VERDE .. L("llegaste a ", "you arrived at ") .. nombreZona(aqui) .. ".|r")
      irAlPaso(viaje.i + 1, true)
    end
    return
  end
  if p.m then
    local x, y = posEn(p.m)
    if x and math.sqrt((x - p.x) ^ 2 + (y - p.y) ^ 2) < (p.final and 2.5 or 3.5) then
      if p.final and viaje.maz.final then
        print(AZUL .. VERDE .. L("llegaste: ", "you are there: ") .. "|r" .. (viaje.maz.final.llegada or viaje.maz.final.texto))
        local npc = viaje.maz.final.npc or (WowF._lineaNPC and WowF._lineaNPC())
        if npc and WowF.avisoLlegadaNPC then pcall(WowF.avisoLlegadaNPC, npc) end
        pararViaje(true)
      elseif p.final and viaje.maz.mision then
        local q = viaje.maz.mision
        local cad = type(q.cadena) == "table" and q.cadena or nil
        local luego = (cad and cad.sig) and L(". Al aceptar, la ruta sigue sola a " .. cad.sig .. ".", ". Once accepted, the route moves on to " .. cad.sig .. " by itself.")
          or (cad and L(". Al aceptar, la ruta te lleva a " .. q.mazmorra .. ".", ". Once accepted, the route takes you to " .. q.mazmorra .. "."))
          or L(". Luego ve a " .. q.mazmorra .. ".", ". Then go to " .. q.mazmorra .. ".")
        print(AZUL .. VERDE .. L("llegaste: ", "you are there: ") .. "|r" .. L("habla con ", "talk to ") .. ORO .. q.quien .. "|r" .. L(" y acepta ", " and accept ") .. BLANCO .. q.nombre .. "|r" .. VERDE .. luego .. "|r")
        if WowF.avisoLlegadaNPC then pcall(WowF.avisoLlegadaNPC, q.quien) end
        pararViaje(true)
      elseif p.final then
        print(AZUL .. VERDE .. L("llegaste a la entrada de ", "you reached the entrance of ") .. viaje.maz.n .. ". " .. L("Buena suerte!", "Good luck!") .. "|r")
        pararViaje(true)
      else
        irAlPaso(viaje.i + 1, true)
      end
      return
    end
  end
  if not aqui then return end
  -- Pasaste a otra zona (puerta, borde) o saltaste pasos (ya estabas en el muelle de destino): al primer paso de esta zona
  if not tiene(p, aqui) then
    for j = viaje.i + 1, #viaje.pasos do
      local q = viaje.pasos[j]
      if q.tipo ~= "transporte" and tiene(q, aqui) then irAlPaso(j, true); return end
    end
  end
  local enCamino = false
  for j = 1, viaje.i do if tiene(viaje.pasos[j], aqui) then enCamino = true end end
  if not enCamino then
    local m, dib = viaje.maz, viaje.dibujar
    if WowF.viajeA(m, { callado = true, dibujar = dib }) then
      print(AZUL .. NARANJA .. L("estas fuera del camino: ruta rehecha desde ", "you are off the route: new route from ") .. nombreZona(aqui) .. ".|r " .. textoPaso(1))
    end
    return
  end
  -- Mismo paso: el alfiler sigue en tu zona (si el punto queda fuera, se mueve por el borde contigo)
  ponerAlfiler(objetivo())
end
WowF._revisarViaje = revisar
local vigia = CreateFrame("Frame")
vigia:SetScript("OnUpdate", function(_, pasado)
  reloj = reloj + (pasado or 0)
  if reloj < 1 then return end
  reloj = 0
  pcall(revisar)
  if actualizarRumbo and ventana and ventana:IsShown() then pcall(actualizarRumbo) end
  if viaje and WowF.lineaRumbo then pcall(WowF.lineaRumbo) end -- rumbo de la ruta dentro de la ventana de la linea
end)
-- 6-oct (amigo de Andy: "acepte la mision y sigue en el mapa"): la ruta solo se quitaba al llegar al punto exacto.
-- Ahora, aceptar o entregar la mision de la ruta la quita; y tras /reload no se retoma si ya la tienes o ya la hiciste.
local function idDeLaRuta(m) return type(m) == "table" and ((type(m.mision) == "table" and m.mision.id) or (type(m.final) == "table" and m.final.qid)) or nil end
local function yaNoHaceFalta(qid) return qid and ((WowF.misionHecha and WowF.misionHecha(qid)) or (WowF.misionEnDiario and WowF.misionEnDiario(qid))) end
local vigiaMision = CreateFrame("Frame")
for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN" }) do pcall(vigiaMision.RegisterEvent, vigiaMision, e) end
vigiaMision:SetScript("OnEvent", function(_, evento, a, b)
  if not viaje then return end
  -- QUEST_ACCEPTED: (indice, id) en el cliente clasico, (id) en el moderno; QUEST_TURNED_IN: (id, xp, dinero)
  local id = a
  if evento == "QUEST_ACCEPTED" and type(b) == "number" and b > 0 then id = b end
  local qid = idDeLaRuta(viaje.maz)
  if not qid or tonumber(id) ~= qid then return end
  print(AZUL .. VERDE .. (evento == "QUEST_TURNED_IN" and L("mision entregada", "quest turned in") or L("mision aceptada", "quest accepted")) .. "|r"
    .. L(": quito del mapa la ruta hasta quien la da.", ": the route to the quest giver is removed from the map."))
  pararViaje(true)
end)
WowF._idDeLaRuta = idDeLaRuta -- para las pruebas
-- Al entrar al juego se retoma el viaje guardado
vigia:RegisterEvent("PLAYER_ENTERING_WORLD")
vigia:SetScript("OnEvent", function()
  local g = WowFExportarDB.viaje
  if viaje or type(g) ~= "table" or not g.n then return end
  if yaNoHaceFalta(idDeLaRuta(g.destino)) then WowFExportarDB.viaje = nil; return end
  if type(g.destino) == "table" and g.destino.m then
    local function retomar() pcall(WowF.viajeA, g.destino, { callado = true, dibujar = g.dibujar }) end
    if C_Timer and C_Timer.After then C_Timer.After(5, retomar) else retomar() end
    return
  end
  for _, m in ipairs(WowFMazmorras or {}) do
    if m.n == g.n then
      local function retomar() pcall(WowF.viajeA, m, { callado = true, dibujar = g.dibujar }) end
      if C_Timer and C_Timer.After then C_Timer.After(5, retomar) else retomar() end
      return
    end
  end
end)

-- ===================== Dibujo en el mapa (M) =====================
local bordes, capaLineas = {}, nil -- 4-oct: la raya va en una capa propia encima del mapa; en el lienzo quedaba tapada y no se veia
local marcas, lineas = {}, {} -- con huecos (el punto "donde estas" no lleva circulo): ocultar SIEMPRE con pairs, ipairs se para en el hueco (4-oct: Limpiar no quitaba la ruta)
local function lienzo()
  if not WorldMapFrame or WowF.interfazMando() then return nil end -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
  if WorldMapFrame.GetCanvas then return WorldMapFrame:GetCanvas() end
  return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end
-- Un punto (mapa, x, y) visto en el mapa que esta abierto (0-100), o nil si no cae en el
local function enVista(m, x, y, visto)
  local vx, vy = proyectar(m, x, y, visto)
  if dentro(vx, vy, 0.5) then return vx, vy end
  return nil
end
WowF._enVista = enVista -- para las pruebas
local function tooltipMarca(self)
  if not GameTooltip or not self.texto then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(self.texto, 1, 1, 1, 1, true)
  GameTooltip:Show()
end
dibujarMapa = function()
  for _, p in pairs(marcas) do p:Hide() end
  for _, l in pairs(lineas) do l:Hide() end
  for _, l in pairs(bordes) do l:Hide() end
  local c = lienzo()
  if not c or not viaje or not viaje.dibujar or not WorldMapFrame:IsShown() then return end
  local visto = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  local ancho, alto = c:GetWidth(), c:GetHeight()
  if not visto or not ancho or ancho == 0 then return end
  -- Tamano fijo EN PANTALLA (el lienzo se escala con el zoom). 4-oct (2): 12 px (14 el que toca); la etiqueta solo con el raton
  local escala = 1
  pcall(function() escala = c:GetEffectiveScale() / UIParent:GetEffectiveScale() end)
  if not escala or escala <= 0 then escala = 1 end
  local px = 1 / escala
  local tam = 12 * px
  -- Puntos: donde estas, el alfiler del paso que toca (en tu zona) y el punto de cada paso que falta (llegada de los transportes incluida)
  local puntos = {}
  local aqui = zonaActual()
  if aqui then local x, y = posEn(aqui); if x then table.insert(puntos, { aqui, x, y, "" }) end end
  local o = objetivo()
  for i = viaje.i, #viaje.pasos do
    local p = viaje.pasos[i]
    local actual = (i == viaje.i)
    local etiqueta = (actual and (VERDE .. L("AHORA: ", "NOW: ") .. "|r") or "") .. L("Paso ", "Step ") .. i .. ": " .. (p.corto or "")
    if actual and o and o.borde then
      table.insert(puntos, { o.m, o.x, o.y, tostring(i), texto = etiqueta, actual = true })
    elseif p.m then
      table.insert(puntos, { p.m, p.x, p.y, p.mision and "!" or tostring(i), texto = etiqueta, actual = actual, mision = p.mision })
    end
    if p.tipo == "transporte" then table.insert(puntos, { p.hasta, p.llegada[1], p.llegada[2], "", salto = true }) end
  end
  local antes
  local fuenteN = (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
  for k, p in ipairs(puntos) do
    local x, y = enVista(p[1], p[2], p[3], visto)
    if x then
      if p[4] ~= "" then
        local pin = marcas[k]
        -- Circulo con el numero del paso dentro (verde = el paso que toca). Lo que hay alli sale al pasar el raton
        if not pin then
          pin = CreateFrame("Frame", nil, c)
          pin:SetFrameStrata("HIGH")
          pcall(function() pin:SetFrameLevel(c:GetFrameLevel() + 10) end) -- encima de la raya de la ruta
          if pin.EnableMouse then pin:EnableMouse(true) end
          pin.borde = pin:CreateTexture(nil, "ARTWORK")
          pin.borde:SetColorTexture(0, 0, 0, 1)
          pin.icono = pin:CreateTexture(nil, "OVERLAY")
          pin.icono:SetAllPoints()
          pcall(function()
            for _, tx in ipairs({ pin.borde, pin.icono }) do
              local m = pin:CreateMaskTexture()
              m:SetAllPoints(tx)
              m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
              tx:AddMaskTexture(m)
            end
          end)
          pin.numero = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          pin.numero:SetPoint("CENTER", 0, 0)
          pin.numero:SetTextColor(0, 0, 0)
          pin:SetScript("OnEnter", tooltipMarca)
          pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
          marcas[k] = pin
        end
        local t2 = p.actual and 14 * px or tam
        pin:SetSize(t2, t2)
        pin.borde:ClearAllPoints()
        pin.borde:SetPoint("TOPLEFT", -px, px)
        pin.borde:SetPoint("BOTTOMRIGHT", px, -px)
        pcall(pin.numero.SetFont, pin.numero, fuenteN, 9 * px, "")
        if p.mision then pin.icono:SetColorTexture(0.78, 0.49, 1, 1) elseif p.actual then pin.icono:SetColorTexture(0.2, 1, 0.4, 1) else pin.icono:SetColorTexture(1, 0.82, 0, 1) end
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", c, "TOPLEFT", ancho * x / 100, -alto * y / 100)
        pin.numero:SetText(p[4])
        pin.texto = p.texto
        pin:Show()
      end
      -- Linea desde el punto anterior (el viaje en barco o zepelin va en azul claro)
      if antes and not capaLineas then
        capaLineas = CreateFrame("Frame", nil, c)
        capaLineas:SetAllPoints(c)
        capaLineas:SetFrameStrata("HIGH")
      end
      if antes then pcall(function() capaLineas:SetFrameLevel(c:GetFrameLevel() + 1) end); capaLineas:Show() end
      if antes and capaLineas.CreateLine then
        local l, sombra = lineas[k], bordes[k]
        if not l then
          local ok1, s1 = pcall(capaLineas.CreateLine, capaLineas, nil, "ARTWORK")
          local ok2, l2 = pcall(capaLineas.CreateLine, capaLineas, nil, "OVERLAY")
          if ok1 and s1 then sombra = s1; bordes[k] = s1 end
          if ok2 and l2 then l = l2; lineas[k] = l2 end
        end
        local color = p.salto and { 0.3, 0.8, 1, 1 } or { 1, 0.85, 0.1, 1 }
        for _, par in ipairs({ { sombra, 5, 0, 0, 0, 0.75 }, { l, 2.5, color[1], color[2], color[3], color[4] } }) do
          local ln = par[1]
          if ln then
            ln:SetThickness(par[2] * px)
            ln:SetColorTexture(par[3], par[4], par[5], par[6])
            ln:SetStartPoint("TOPLEFT", c, ancho * antes[1] / 100, -alto * antes[2] / 100)
            ln:SetEndPoint("TOPLEFT", c, ancho * x / 100, -alto * y / 100)
            ln:Show()
          end
        end
      end
      antes = { x, y }
    else
      antes = nil
    end
  end
end
WowF._marcasViaje = function() local n = 0; for _, p in ipairs(marcas) do if p:IsShown() then n = n + 1 end end; return n end -- para las pruebas
-- 4-oct (Andy: "se ven grandes y se hacen pequenos solo al darles clic"): el tamano en pantalla sale de la escala del lienzo,
-- que cambia con el zoom y justo despues de abrir el mapa; antes solo se recalculaba al cambiar de mapa o al hacer clic.
-- Ahora se rehace en cuanto cambia la escala, asi salen pequenos desde el principio.
local escalaVista
local function revisarEscala()
  local c = lienzo()
  local ok, e = pcall(function() return c:GetEffectiveScale() end)
  if ok and type(e) == "number" and e > 0 and (not escalaVista or math.abs(e - escalaVista) > escalaVista * 0.01) then
    escalaVista = e
    pcall(dibujarMapa)
  end
end
WowF._revisarEscala = WowF._revisarEscala or {}
table.insert(WowF._revisarEscala, revisarEscala) -- para las pruebas
if WorldMapFrame then
  if WorldMapFrame.OnMapChanged then pcall(hooksecurefunc, WorldMapFrame, "OnMapChanged", function() pcall(dibujarMapa) end) end
  WorldMapFrame:HookScript("OnShow", function() pcall(dibujarMapa) end)
  local vigia = CreateFrame("Frame", nil, WorldMapFrame) -- hijo del mapa: OnUpdate solo corre con el mapa abierto
  vigia:SetScript("OnUpdate", revisarEscala)
end

-- ===================== Recuadro de la ruta =====================
-- Siempre a la vista mientras dura la ruta: "PASO 2 DE 4", la orden, donde esta, hacia donde ir y a cuantas yardas, y lo que viene despues.
local function fuente(padre, plantilla, otra)
  local ok, f = pcall(padre.CreateFontString, padre, nil, "OVERLAY", plantilla)
  if not ok or not f then f = padre:CreateFontString(nil, "OVERLAY", otra) end
  f:SetJustifyH("LEFT")
  return f
end
-- 11-oct (rediseno "hibrido"): cuero fino con "RUTA · X  1/5" arriba; dentro, la piedra con franja roja,
-- "PASO i DE N", la orden grande, el detalle, la caja de yardas con la flecha y una raya por paso.
local E = WowF.estilo
local C = E.color
ventana = CreateFrame("Frame", "wowFViaje", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
ventana:SetSize(290, 260)
ventana:SetFrameStrata("DIALOG")
ventana:SetClampedToScreen(true)
ventana:SetMovable(true)
ventana:EnableMouse(true)
ventana:RegisterForDrag("LeftButton")
ventana:SetScript("OnDragStart", function(self) self:StartMoving() end)
ventana:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local a, _, b, x, y = self:GetPoint()
  WowFExportarDB.viajePos = { a, b, x, y }
end)
local colocada = false
local function colocar()
  if colocada then return end
  colocada = true
  ventana:ClearAllPoints()
  local g = WowFExportarDB.viajePos
  if type(g) == "table" and g[1] then ventana:SetPoint(g[1], UIParent, g[2], g[3], g[4]) else ventana:SetPoint("RIGHT", UIParent, "RIGHT", -40, 120) end
end
local piel = E.marco(ventana, "panel", { dentro = 10 })
if piel and piel.piedra then
  piel.piedra:ClearAllPoints()
  piel.piedra:SetPoint("TOPLEFT", 10, -28)
  piel.piedra:SetPoint("BOTTOMRIGHT", -10, 10)
end
ventana:Hide()
local ANCHO = 242 -- 290 - 2 x (10 de cuero + 14 de piedra)
local IZQ = 24
-- Cabecera en el cuero
local cabIzq = fuente(ventana, "GameFontNormalSmall", "GameFontNormal")
E.letra(cabIzq, "marca", 10)
cabIzq:SetTextColor(C.oro[1], C.oro[2], C.oro[3])
cabIzq:SetPoint("TOPLEFT", 14, -10)
cabIzq:SetWidth(200)
if cabIzq.SetWordWrap then cabIzq:SetWordWrap(false) end
local cabDer = fuente(ventana, "GameFontNormalSmall", "GameFontNormal")
E.letra(cabDer, "marca", 10)
cabDer:SetTextColor(C.oro[1], C.oro[2], C.oro[3])
cabDer:SetJustifyH("RIGHT")
cabDer:SetPoint("TOPRIGHT", -36, -10)
-- Dentro de la piedra
local tituloVentana = fuente(ventana, "GameFontHighlightSmall", "GameFontHighlight") -- solo misiones: que mision y de que mazmorra
E.letra(tituloVentana, "boton", 11)
tituloVentana:SetPoint("TOPLEFT", IZQ, -42)
tituloVentana:SetWidth(ANCHO)
local pasoGrande = fuente(ventana, "GameFontNormalSmall", "GameFontNormal")
E.letra(pasoGrande, "marca", 10)
pasoGrande:SetTextColor(C.tenue[1], C.tenue[2], C.tenue[3])
local textoAhora = fuente(ventana, "GameFontHighlightLarge", "GameFontHighlight")
E.letra(textoAhora, "titulo", 14)
textoAhora:SetTextColor(C.texto[1], C.texto[2], C.texto[3])
textoAhora:SetPoint("TOPLEFT", pasoGrande, "BOTTOMLEFT", 0, -6)
textoAhora:SetWidth(ANCHO)
local textoDetalle = fuente(ventana, "GameFontHighlightSmall", "GameFontHighlight")
E.letra(textoDetalle, "boton", 11)
textoDetalle:SetTextColor(C.tenue[1], C.tenue[2], C.tenue[3])
textoDetalle:SetPoint("TOPLEFT", textoAhora, "BOTTOMLEFT", 0, -4)
textoDetalle:SetWidth(ANCHO)
-- Caja de yardas: circulo con la flecha hacia el alfiler, yardas grandes en brasa y el rumbo debajo
local caja = CreateFrame("Frame", nil, ventana, BackdropTemplateMixin and "BackdropTemplate" or nil)
caja:SetSize(ANCHO, 62)
caja:SetPoint("TOPLEFT", textoDetalle, "BOTTOMLEFT", 0, -10)
E.marco(caja, "losa")
local circulo = caja:CreateTexture(nil, "ARTWORK")
circulo:SetTexture(E.texturas.aro)
circulo:SetSize(44, 44)
circulo:SetPoint("LEFT", 9, 0)
local flecha = caja:CreateTexture(nil, "OVERLAY")
flecha:SetTexture("Interface\\Minimap\\MinimapArrow")
flecha:SetSize(30, 30)
flecha:SetPoint("CENTER", circulo, "CENTER", 0, 0)
local yardasGrandes = fuente(caja, "GameFontNormalHuge", "GameFontNormalLarge")
E.letra(yardasGrandes, "boton", 18)
yardasGrandes:SetTextColor(C.brasa[1], C.brasa[2], C.brasa[3])
yardasGrandes:SetPoint("TOPLEFT", circulo, "TOPRIGHT", 12, -2)
local textoRumboV = fuente(caja, "GameFontHighlightSmall", "GameFontHighlight")
E.letra(textoRumboV, "boton", 11)
textoRumboV:SetWidth(ANCHO - 74)
-- Retrato redondo del NPC al que vas (wowF_Retratos.lua), a la derecha de la caja de yardas; solo si el destino es un NPC
local retratoNPC
if WowF.marcoRetrato then
  retratoNPC = WowF.marcoRetrato(caja, 44)
  retratoNPC:SetPoint("RIGHT", -9, 0)
  retratoNPC:Hide()
end
-- Que retrato va (nil = el destino no es un NPC): campo retrato del destino, o el NPC de la mision de mazmorra
local function retratoDestino()
  local d = viaje and viaje.maz
  if type(d) ~= "table" then return nil end
  if type(d.retrato) == "table" then return d.retrato end
  if type(d.final) == "table" and type(d.final.retrato) == "table" then return d.final.retrato end
  if type(d.mision) == "table" and (d.mision.npc or d.mision.quien) then
    local quien = d.mision.quien ~= "?" and d.mision.quien or nil
    return { npc = d.mision.npc, nombre = quien, unidad = (d.mision.npc or quien) and "target" or nil, icono = "Interface\\GossipFrame\\AvailableQuestIcon" }
  end
  return nil
end
-- Una raya por paso (hasta 12; con mas, cada raya vale varios pasos)
local MAXR = 12
local rayas = {}
for i = 1, MAXR do
  local r = ventana:CreateTexture(nil, "ARTWORK")
  r:SetHeight(4)
  rayas[i] = r
end
textoVentana = fuente(ventana, "GameFontHighlightSmall", "GameFontHighlight")
E.letra(textoVentana, "boton", 11)
textoVentana:SetTextColor(C.texto[1], C.texto[2], C.texto[3])
textoVentana:SetWidth(ANCHO)
if textoVentana.SetSpacing then textoVentana:SetSpacing(3) end
local cerrar = CreateFrame("Button", nil, ventana, "UIPanelButtonTemplate")
E.boton(cerrar, "cuero", 11)
cerrar:SetSize(18, 18)
cerrar:SetText("X")
cerrar:SetPoint("TOPRIGHT", -8, -6)
cerrar:SetScript("OnClick", function()
  ventana:Hide()
  if viaje then print(AZUL .. L("recuadro cerrado; la ruta sigue (vuelve a salir en el paso siguiente). Para quitarla: boton Limpiar el mapa o /wowf limpiar.", "box closed; the route goes on (it shows again at the next step). To clear it: Clear the map button or /wowf limpiar.")) end
end)
local function boton(ancho, tipo)
  local b = CreateFrame("Button", nil, ventana, "UIPanelButtonTemplate")
  E.boton(b, tipo or "cuero", 10)
  b:SetSize(ancho, 22)
  return b
end
-- Ver el mapa es lo principal (brasa); los otros dos, secundarios
botonMapa = boton(80, "brasa")
botonMapa:SetPoint("BOTTOMLEFT", IZQ - 6, 18)
local botonTodos = boton(80)
botonTodos:SetPoint("LEFT", botonMapa, "RIGHT", 4, 0)
botonTodos:SetScript("OnClick", function()
  if not viaje then return end
  viaje.verTodos = not viaje.verTodos
  actualizarVentana()
end)
-- 5-oct (Andy: "Quitar del mapa y Limpiar el mapa hacen lo mismo; deja uno y pon Ver el mapa que saque el mapa"):
-- Ver el mapa = dibuja la ruta y ABRE el mapa del mundo en la zona del paso que toca. Quitar = solo Limpiar el mapa.
botonMapa:SetScript("OnClick", function()
  if not viaje then return end
  local yaEstaba = viaje.dibujar
  viaje.dibujar = true
  if not yaEstaba then irAlPaso(viaje.i, false) end
  if WorldMapFrame and not WowF.interfazMando() then -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
    if not WorldMapFrame:IsShown() then
      if ShowUIPanel then pcall(ShowUIPanel, WorldMapFrame) elseif ToggleWorldMap then pcall(ToggleWorldMap) else pcall(WorldMapFrame.Show, WorldMapFrame) end
    end
    local p = viaje.pasos[viaje.i]
    local m = p and p.m or zonaActual()
    if m and WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, m) end
  end
  if dibujarMapa then pcall(dibujarMapa) end
  if not yaEstaba then
    print(AZUL .. L("ruta en el mapa: cada circulo lleva el numero de su paso; el VERDE es el que toca ahora.", "route on the map: each circle has its step number; the GREEN one is the current step."))
  end
end)
WowF._botonVerMapa = botonMapa -- pruebas
local botonParar = boton(80)
botonParar:SetPoint("LEFT", botonTodos, "RIGHT", 4, 0)
botonParar:SetScript("OnClick", function() WowF.limpiarRutas(false) end)
-- 12-oct (Andy, captura "roto"): con ancho fijo de 80 los textos se montaban. Cada boton toma el ancho de SU texto;
-- si los tres no caben en una fila (letra grande, ingles...), Limpiar el mapa baja a una segunda fila. Devuelve el alto extra.
local function acomodarBotones()
  local libre = ANCHO + 12
  local w1 = E.botonAncho and E.botonAncho(botonMapa, true, 60) or 80
  local w2 = E.botonAncho and E.botonAncho(botonTodos, true, 60) or 80
  local w3 = E.botonAncho and E.botonAncho(botonParar, true, 60) or 80
  botonTodos:ClearAllPoints()
  botonParar:ClearAllPoints()
  botonMapa:ClearAllPoints()
  if w1 + w2 + w3 + 8 <= libre then
    botonMapa:SetPoint("BOTTOMLEFT", IZQ - 6, 18)
    botonTodos:SetPoint("LEFT", botonMapa, "RIGHT", 4, 0)
    botonParar:SetPoint("LEFT", botonTodos, "RIGHT", 4, 0)
    return 0
  end
  -- dos filas: arriba Ver el mapa + Todos los pasos (si no caben, cada uno ocupa media fila), abajo Limpiar el mapa
  if w1 + w2 + 4 > libre then
    local m = math.floor((libre - 4) / 2)
    pcall(botonMapa.SetWidth, botonMapa, m)
    pcall(botonTodos.SetWidth, botonTodos, m)
  end
  botonParar:SetPoint("BOTTOMLEFT", IZQ - 6, 18)
  botonMapa:SetPoint("BOTTOMLEFT", botonParar, "TOPLEFT", 0, 4)
  botonTodos:SetPoint("LEFT", botonMapa, "RIGHT", 4, 0)
  return 26
end

local function altoDe(f, lineas)
  local h = f.GetStringHeight and f:GetStringHeight()
  if type(h) ~= "number" or h <= 0 then h = (lineas or 1) * 14 end
  return h
end
-- Caja de yardas: con distancia, "110 yd" grande + "al SURESTE"; si no, la frase entera del rumbo
actualizarRumbo = function()
  if not viaje then return end
  local p = viaje.pasos[viaje.i]
  local o = p and objetivo()
  local ok, r = pcall(rumbo, o)
  if not ok then r = nil end
  textoRumboV:ClearAllPoints()
  if p and r and r.yardas and not r.cerca then
    yardasGrandes:SetText(string.format("%d", math.floor(r.yardas / 10 + 0.5) * 10) .. " yd")
    yardasGrandes:Show()
    textoRumboV:SetPoint("TOPLEFT", yardasGrandes, "BOTTOMLEFT", 0, -2)
    textoRumboV:SetText(GRIS .. L("hacia el ", "to the ") .. string.upper(r.rumbo) ..
      (o.borde and L(" · alfiler en el borde de la zona", " · pin on the zone edge") or "") .. "|r")
  else
    yardasGrandes:SetText("")
    yardasGrandes:Hide()
    textoRumboV:SetPoint("LEFT", circulo, "RIGHT", 12, 0)
    textoRumboV:SetText(textoRumbo(p))
  end
  if r and r.grados and flecha.SetRotation then
    pcall(flecha.SetRotation, flecha, -math.rad(r.grados))
    flecha:Show()
  else
    flecha:Hide()
  end
end
WowF._textoRumbo = function() return viaje and textoRumbo(viaje.pasos[viaje.i]) end
-- 13-oct (Andy: "te abre los dos pop-up... fusionalo"): la ruta de una linea de misiones NO abre su recuadro;
-- el rumbo, las yardas y el paso salen arriba de la ventana de la linea (wowF_LineaMisiones.lua, WowF.lineaRumbo).
WowF._viajeFusion = function()
  return (viaje and type(viaje.maz) == "table" and type(viaje.maz.final) == "table" and viaje.maz.final.linea
    and WowF.lineaActiva and WowF.lineaActiva()) and true or false
end
-- Lo que necesita la ventana de la linea: paso i de n, la orden, el detalle, yardas, rumbo y grados de la flecha
WowF.viajeEstado = function()
  if not viaje then return nil end
  local p = viaje.pasos[viaje.i]
  local o = p and objetivo()
  local ok, r = pcall(rumbo, o)
  if not ok or type(r) ~= "table" then r = nil end
  local ok2, frase = pcall(textoRumbo, p)
  return { i = viaje.i, n = #viaje.pasos, texto = p and p.texto or "", detalle = p and p.detalle or nil,
    yardas = (r and r.yardas and not r.cerca) and r.yardas or nil, rumbo = r and r.rumbo or nil, grados = r and r.grados or nil,
    borde = o and o.borde or nil, frase = ok2 and frase or "", fusion = WowF._viajeFusion() }
end

actualizarVentana = function()
  if not viaje then ventana:Hide(); return end
  if WowF._viajeFusion() then
    ventana:Hide()
    if WowF.lineaRumbo then pcall(WowF.lineaRumbo) end
    return
  end
  colocar()
  local p, n = viaje.pasos[viaje.i], #viaje.pasos
  local largo -- titulo largo (misiones), dentro de la piedra
  if viaje.maz.final and viaje.maz.final.ventana then
    cabIzq:SetText(L("RUTA", "ROUTE"))
    largo = viaje.maz.final.ventana
  elseif viaje.maz.mision then
    cabIzq:SetText(L("MISIÓN · ", "QUEST · ") .. string.upper(viaje.maz.mision.mazmorra or ""))
    local cad = viaje.maz.mision.cadena -- 6-oct: ruta de "Misiones de fuera" (NPC i de N)
    largo = (type(cad) == "table" and cad.i and (ORO .. L("Misiones de fuera: NPC ", "Outside quests: NPC ") .. cad.i .. L(" de ", " of ") .. (cad.de or "?") .. L(" que te dan ya", " that give you quests now") .. "|r"
      .. ((cad.tarde or 0) > 0 and ("|cff999999" .. L("  (+" .. cad.tarde .. " mas adelante, desde nivel " .. (cad.minTarde or "?") .. ")", "  (+" .. cad.tarde .. " later, from level " .. (cad.minTarde or "?") .. ")") .. "|r") or "") .. "\n") or "")
      .. "|cffc77dff" .. L("Mision de mazmorra: ", "Dungeon quest: ") .. "|r" .. BLANCO .. viaje.maz.mision.nombre .. "|r" .. GRIS .. " (" .. viaje.maz.mision.mazmorra .. ")|r"
  else
    cabIzq:SetText(L("RUTA · ", "ROUTE · ") .. string.upper(viaje.maz.n or ""))
  end
  cabDer:SetText(viaje.i .. "/" .. n)
  pasoGrande:ClearAllPoints()
  if largo then
    tituloVentana:SetText(largo)
    tituloVentana:Show()
    pasoGrande:SetPoint("TOPLEFT", tituloVentana, "BOTTOMLEFT", 0, -8)
  else
    tituloVentana:SetText("")
    tituloVentana:Hide()
    pasoGrande:SetPoint("TOPLEFT", IZQ, -42)
  end
  pasoGrande:SetText(L("PASO ", "STEP ") .. viaje.i .. L(" DE ", " OF ") .. n)
  textoAhora:SetText(p and p.texto or "")
  textoDetalle:SetText(p and p.detalle and (GRIS .. p.detalle .. "|r") or "")
  if retratoNPC then
    local ro = retratoDestino()
    if ro then
      pcall(retratoNPC.poner, retratoNPC, ro)
      retratoNPC:resaltar(p and p.final and true or false) -- borde brasa en el paso de hablar con el
      retratoNPC:Show()
      textoRumboV:SetWidth(ANCHO - 74 - 50)
    else
      retratoNPC:Hide()
      textoRumboV:SetWidth(ANCHO - 74)
    end
  end
  actualizarRumbo()
  -- rayas de avance
  local cuantas = math.min(n, MAXR)
  local hueco = 6
  local anchoR = (ANCHO - hueco * (cuantas - 1)) / math.max(cuantas, 1)
  local hechas = n <= MAXR and viaje.i or math.ceil(viaje.i * MAXR / n)
  for i = 1, MAXR do
    local r = rayas[i]
    if i <= cuantas then
      r:ClearAllPoints()
      r:SetWidth(anchoR)
      r:SetPoint("TOPLEFT", caja, "BOTTOMLEFT", (i - 1) * (anchoR + hueco), -10)
      if i <= hechas then r:SetColorTexture(C.brasa[1], C.brasa[2], C.brasa[3], 1) else r:SetColorTexture(0.227, 0.165, 0.102, 1) end
      r:Show()
    else
      r:Hide()
    end
  end
  local lineasTexto = {}
  if viaje.verTodos then
    for i, q in ipairs(viaje.pasos) do
      local c = i < viaje.i and GRIS or (i == viaje.i and BLANCO or "|cffcccccc")
      local marca = i < viaje.i and (VERDE .. L("[hecho] ", "[done] ") .. "|r") or (i == viaje.i and (VERDE .. L("AHORA > ", "NOW > ") .. "|r") or "")
      table.insert(lineasTexto, marca .. c .. i .. ". " .. q.texto:gsub("|r", "|r" .. c) .. "|r")
    end
  elseif viaje.pasos[viaje.i + 1] then
    local q = viaje.pasos[viaje.i + 1]
    table.insert(lineasTexto, GRIS .. L("Despues: ", "Next: ") .. "|r" .. (viaje.i + 1) .. ". " .. q.texto)
  else
    table.insert(lineasTexto, VERDE .. L("Es el ultimo paso.", "This is the last step.") .. "|r")
  end
  if viaje.vuelo and viaje.i == 1 then table.insert(lineasTexto, 1, "|cff66ccff" .. viaje.vuelo:gsub("|r", "|r|cff66ccff") .. "|r\n") end -- 17-oct: pista de vuelo (mmjau)
  local cad = viaje.maz.mision and viaje.maz.mision.cadena
  if type(cad) == "table" and cad.i then
    table.insert(lineasTexto, "|cffc77dff" .. (cad.sig and L("Al aceptar sus misiones, la ruta sigue sola al siguiente NPC: ", "When you accept its quests, the route moves on to the next NPC: ") .. cad.sig
      or L("Es el ultimo NPC: al aceptar, la ruta te lleva a la entrada de la mazmorra.", "It is the last NPC: after accepting, the route takes you to the dungeon entrance.")) .. "|r")
  end
  textoVentana:ClearAllPoints()
  textoVentana:SetPoint("TOPLEFT", caja, "BOTTOMLEFT", 0, -24)
  textoVentana:SetText(table.concat(lineasTexto, "\n"))
  local alto = 42 + (largo and (altoDe(tituloVentana, 2) + 8) or 0) + altoDe(pasoGrande) + 6 + altoDe(textoAhora, 2) + 4 + altoDe(textoDetalle, 2)
    + 10 + 62 + 24 + altoDe(textoVentana, #lineasTexto + 1) + 12 + 22 + 18
  botonTodos:SetText(viaje.verTodos and L("Menos pasos", "Fewer steps") or L("Todos los pasos", "All steps"))
  botonMapa:SetText(L("Ver el mapa", "Open the map"))
  botonParar:SetText(L("Limpiar el mapa", "Clear the map"))
  local extra = 0
  pcall(function() extra = acomodarBotones() or 0 end)
  ventana:SetHeight(math.max(230, alto + extra))
end
WowF.viajeVentana = ventana
WowF._retratoViaje = function() return retratoNPC end -- pruebas

-- Clic en una mazmorra (Libro, panel, /wowf ruta): explica como llegar; si no se sabe donde estas, solo el alfiler en la entrada
function WowF.irAMazmorra(m)
  if not m then return end
  local ok, hecho = pcall(WowF.viajeA, m)
  if not (ok and hecho) and WowF.marcar then WowF.marcar(m) end
end

-- /wowf limpiar (o clear): quita todas las rutas, marcas y el alfiler. Envuelve la orden que ya existe (Panel, Libro...)
local ordenAnterior = SlashCmdList and SlashCmdList["WOWF"]
if SlashCmdList then
  SlashCmdList["WOWF"] = function(msg, ...)
    local c = ((msg or ""):lower()):match("^%s*(.-)%s*$")
    if c == "limpiar" or c == "clear" or c == "limpiar mapa" then WowF.limpiarRutas(false); return end
    if ordenAnterior then return ordenAnterior(msg, ...) end
  end
end
