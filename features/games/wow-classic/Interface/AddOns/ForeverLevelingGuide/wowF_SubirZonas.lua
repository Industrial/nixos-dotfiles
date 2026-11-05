-- Forever Leveling Guide: donde subir de nivel, como un plan encadenado que no se pisa (pedido de Andy, 4-oct).
-- Datos: wowF_Zonas.lua (WowFZonas, de Wowhead /forever: misiones de cada bando por nivel, XP y pueblos).
-- Reglas:
--   1. Solo zonas de TU bando (con pueblo amistoso y al menos 15 misiones de tu bando).
--   2. La primera zona sale de donde estas; cada una de las siguientes, de la anterior: la mas cercana (grafo de wowF_Viaje.lua,
--      sin cambiar de continente si no hace falta) que tenga misiones a tu nivel. Si empatan, la que dura mas niveles.
--   3. Cada zona tiene su tramo (del nivel D al H) y la siguiente empieza en H: nunca te manda a otra zona antes de tiempo.
--   4. El plan se guarda por personaje (WowFExportarDB.planZonas) y solo se rehace al terminarlo, al cambiar los datos
--      o con "Rehacer desde donde estoy". Es OPCIONAL: se dice siempre y se explica el porque.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local Y = function(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end
local TOPE = 60

-- 9-oct (regla de Andy: CERO datos de Classic): que misiones sirven a tu nivel P lo dice el CLIENTE en vivo:
--   por abajo, hasta donde dejan de ser grises (UnitQuestTrivialLevelRange / GetQuestGreenRange);
--   por arriba, hasta la ultima que no sale roja/imposible (GetQuestDifficultyColor contra QuestDifficultyColors).
-- Todo con pcall y comprobando que la funcion existe. Si el cliente no lo da, se usa P-2 a P+3 como ESTIMACION
-- (no es un dato de Forever; exacto = false). Se guarda por nivel del personaje (los desplazamientos se aplican a cada P).
local rangoCache = { nivel = nil }
local function nivelJugador() local ok, n = pcall(function() return UnitLevel and UnitLevel("player") end); return (ok and tonumber(n)) or 1 end
function WowF.rangoMisionUtil()
  local P = nivelJugador()
  if rangoCache.nivel == P then return rangoCache.abajo, rangoCache.arriba, rangoCache.exacto end
  local abajo, arriba
  if UnitQuestTrivialLevelRange then
    local ok, v = pcall(UnitQuestTrivialLevelRange, "player"); v = ok and tonumber(v)
    if v and v >= 0 and v < 30 then abajo = v end
  end
  if not abajo and GetQuestGreenRange then
    local ok, v = pcall(GetQuestGreenRange); v = ok and tonumber(v)
    if v and v >= 0 and v < 30 then abajo = v end
  end
  local roja = type(QuestDifficultyColors) == "table" and QuestDifficultyColors.impossible
  if GetQuestDifficultyColor and type(roja) == "table" then
    for d = 0, 10 do
      local ok, c = pcall(GetQuestDifficultyColor, P + d)
      if not ok or type(c) ~= "table" then break end
      if c == roja or (c.r == roja.r and c.g == roja.g and c.b == roja.b) then arriba = d - 1; break end
    end
  end
  local exacto = (abajo ~= nil and arriba ~= nil and arriba >= 0)
  if not exacto then abajo, arriba = 2, 3 end -- estimacion, no dato de Forever
  rangoCache.nivel, rangoCache.abajo, rangoCache.arriba, rangoCache.exacto = P, abajo, arriba, exacto
  return abajo, arriba, exacto
end
-- 9-oct (CERO datos de Classic): solo se CUENTAN misiones. La XP de Wowhead (t[2]) es la de Classic: no se usa.
local function utiles(s, P)
  local n = 0
  local abajo, arriba = WowF.rangoMisionUtil()
  for lv = P - abajo, P + arriba do local t = s.lv[lv]; if t then n = n + t[1] end end
  return n
end
local function bando()
  local f = WowF.miFaccion and WowF.miFaccion() or 0
  if f == 1 then return "H" elseif f == 2 then return "A" end
  return nil
end
local function porId(id) for _, z in ipairs(WowFZonas or {}) do if z.id == id then return z end end end
local function porMapa(m) for _, z in ipairs(WowFZonas or {}) do if z.m == m then return z end end end

-- Donde empiezas si no se sabe la zona (dentro de una mazmorra, zona nueva sin mapa): la zona inicial de tu raza o tu capital
-- 9-oct (CERO datos de Classic): zona inicial = la zona de Wowhead /forever con las misiones de nivel 1-2 solo para esa raza (reqrace),
-- paginas en fuente/wowhead/paginas-forever/zone-*.html; lo comprueba herramientas/pruebas/prueba-zonas-forever.mjs. Razas sin dato
-- (Goblin, Worgen, Skyborne...) van a la capital de su bando.
local INICIO = { Human = 1429, Dwarf = 1426, Gnome = 1426, NightElf = 1438, Orc = 1411, Troll = 1411, Tauren = 1412, Scourge = 1420 }
-- 19-oct (comentario 8570703 de CurseForge): los Skyborne (raza 95 High Order, Alliance; 96 Windshaper, Horde) empiezan en Zephras Isle
-- (uiMapID 2521, isla aparte que no esta en el grafo de viaje). Las zonas con "razas" (wowF_Zonas.lua) son solo para esas razas.
local function miRaza() local ok, _, _, id = pcall(UnitRace or error, "player"); return ok and tonumber(id) or nil end
local function zonaDeRaza(z) return z.razas == nil or z.razas[miRaza() or 0] == true end
-- La isla de inicio en la que estas (WowF.zonaActual no la ve: no esta en el grafo)
local function enIslaDeRaza()
  if not C_Map or not C_Map.GetBestMapForUnit then return nil end
  local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
  for _ = 1, 6 do
    if not ok or not m then return nil end
    for _, z in ipairs(WowFZonas or {}) do if z.razas and z.m == m and zonaDeRaza(z) then return m end end
    local ok2, info = pcall(C_Map.GetMapInfo, m)
    m = ok2 and type(info) == "table" and info.parentMapID or nil
  end
end
local function zonaDePartida(fac)
  local m = enIslaDeRaza() or (WowF.zonaActual and WowF.zonaActual())
  if m then return m end
  local r = miRaza()
  for _, z in ipairs(WowFZonas or {}) do if z.razas and r and z.razas[r] then return z.m end end
  local raza = UnitRace and select(2, UnitRace("player"))
  return INICIO[raza or ""] or (fac == "H" and 1454 or 1453)
end

-- El tramo que te da una zona desde el nivel L: hasta el ultimo nivel seguido con al menos 4 misiones utiles, sin pasar
-- del rango de la zona + 1 (las misiones sueltas de nivel alto no alargan la zona: luego toca la siguiente)
local function tramoDe(s, L)
  local hasta, tope = L, math.min(TOPE, s.h + 1)
  while hasta < tope and utiles(s, hasta + 1) >= 4 do hasta = hasta + 1 end
  return hasta
end
-- Misiones de la zona para un tramo (de D menos lo que el cliente da por util hacia abajo, a H+2; ver WowF.rangoMisionUtil).
-- 9-oct: sin XP (la cifra de Wowhead es de Classic).
local function contar(s, d, h)
  local n = 0
  local abajo = WowF.rangoMisionUtil()
  for lv = d - abajo, h + 2 do local t = s.lv[lv]; if t then n = n + t[1] end end
  return n
end

-- Arma el plan desde el nivel y la zona dados: { { id, desde, hasta, costo }, ... }
local function armar(fac, nivel, desde)
  local tramos, usadas, L, Z = {}, {}, math.max(1, nivel), desde
  local vueltas = 0
  while L < TOPE and vueltas < 40 do
    vueltas = vueltas + 1
    local mejor
    for paso = 1, 2 do -- 2.a vuelta: mas flexible (menos misiones), para no dejar huecos
      for _, z in ipairs(WowFZonas or {}) do
        local s = z[fac]
        -- Isla de inicio de raza: solo tu raza y solo como primera zona (desde fuera de la isla no hay camino conocido)
        if s and not usadas[z.id] and zonaDeRaza(z) and (not z.razas or #tramos == 0) then
          local n = utiles(s, L)
          local hasta = tramoDe(s, L)
          if n >= (paso == 1 and 6 or 3) and hasta >= L + (paso == 1 and 2 or 1) then
            local costo = (Z == z.m) and 0 or (WowF.costoViaje and Z and WowF.costoViaje(Z, z.m)) or 20
            -- Manda la cercania: lo largo del tramo solo desempata (tope 0.9, menos que ir a la zona de al lado)
            local nota = costo - 0.15 * math.min(hasta - L, 6) - 0.01 * math.min(n, 30)
            if not mejor or nota < mejor.nota then mejor = { z = z, hasta = hasta, costo = costo, nota = nota } end
          end
        end
      end
      if mejor then break end
    end
    if not mejor then L = L + 1 -- nivel sin zona con misiones (no deberia pasar): se salta
    else
      table.insert(tramos, { id = mejor.z.id, desde = L, hasta = math.min(TOPE, mejor.hasta), costo = mejor.costo })
      usadas[mejor.z.id] = true
      Z, L = mejor.z.m, mejor.hasta
      -- Al salir de la isla: la mision de salida te deja en su destino (Horde: Mulgore). City of Dalaran (Alliance) aun no tiene
      -- datos de viaje de WoW Forever: se cuenta desde la capital de tu bando (y se dice en el porque)
      if mejor.z.razas then Z = tonumber(mejor.z[fac].sale) or (fac == "H" and 1454 or 1453) end
    end
  end
  return tramos
end
WowF._armarPlanZonas = armar -- para las pruebas

local function firmaDatos() local n = 0; for _, z in ipairs(WowFZonas or {}) do n = n + z.id end; return #(WowFZonas or {}) .. ":" .. n end
local function clavePj() return (UnitName and UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "") end

-- El plan guardado del personaje (lo rehace si hace falta)
function WowF.planZonas(rehacer)
  local fac = bando()
  if not fac or not WowFZonas then return nil end
  local nivel = (UnitLevel and UnitLevel("player")) or 1
  WowFExportarDB.planZonas = WowFExportarDB.planZonas or {}
  local clave = clavePj()
  local g = WowFExportarDB.planZonas[clave]
  local ultimo = g and g.tramos and g.tramos[#g.tramos]
  if rehacer or not g or g.fac ~= fac or g.v ~= firmaDatos() or not ultimo or nivel >= ultimo.hasta and ultimo.hasta < TOPE
    or nivel < (g.tramos[1] and g.tramos[1].desde or 1) then
    g = { fac = fac, v = firmaDatos(), tramos = armar(fac, nivel, zonaDePartida(fac)), nivel = nivel }
    WowFExportarDB.planZonas[clave] = g
  end
  return g
end
function WowF.rehacerPlanZonas()
  WowF.planZonas(true)
  print("|cff33ccffForever Guide|r: " .. Y(L("plan de zonas rehecho desde donde estas.", "zone plan rebuilt from where you are.")))
  if WowF.planCambio then pcall(WowF.planCambio) end
end
-- Tras rehacer: redibujar el Libro y el panel (la cache de Armar cambia sola con planZonasFirma)
WowF.planCambio = WowF.planCambio or function()
  if WowF.libroRedibujar then WowF.libroRedibujar() end
  if WowF.panelActualizar then WowF.panelActualizar() end
end
-- Para la cache de wowF_Armar: cambia si cambia el plan o el idioma
function WowF.planZonasFirma()
  local g = WowF.planZonas()
  if not g then return "" end
  local t = { (WowF.enIngles and WowF.enIngles()) and "en" or "es" }
  for _, x in ipairs(g.tramos) do table.insert(t, x.id .. "/" .. x.desde .. "/" .. x.hasta) end
  return table.concat(t, ",")
end

local function miles(n)
  local s = tostring(math.floor(n + 0.5))
  local sep = L(".", ",")
  while true do local k; s, k = s:gsub("^(%d+)(%d%d%d)", "%1" .. sep .. "%2"); if k == 0 then break end end
  return s
end
local function nombrePueblo(p) return p.n or (p.npc .. (p.vuelo and L(" (maestro de vuelo)", " (flight master)") or L(" (posadero)", " (innkeeper)"))) end

-- Todo lo que hace falta para mostrar un tramo: zona, pueblo, cuantas misiones, porque
function WowF.detalleTramo(t, i, g)
  local z = porId(t.id)
  if not z then return nil end
  local fac = g.fac
  local s = z[fac]
  local n = contar(s, t.desde, t.hasta)
  local pueblo = s.pueblos[1]
  local anterior = i > 1 and porId(g.tramos[i - 1].id) or nil
  local nomBando = fac == "H" and "Horde" or "Alliance"
  local razones = {}
  table.insert(razones, L(n .. " misiones de " .. nomBando .. " para tus niveles " .. t.desde .. "-" .. t.hasta .. " (segun Wowhead WoW Forever).",
    n .. " " .. nomBando .. " quests for your levels " .. t.desde .. "-" .. t.hasta .. " (per Wowhead WoW Forever)."))
  -- 19-oct: isla de inicio de raza (Zephras Isle) y la zona que le sigue
  local sale = anterior and anterior.razas and anterior[fac] and anterior[fac].sale
  local nomSale = sale and (type(sale) == "number" and (porMapa(sale) or {}).n or tostring(sale))
  if z.razas then
    table.insert(razones, L("Es la zona inicial de tu raza (Skyborne): solo tu raza tiene estas misiones.",
      "It is your race's starting zone (Skyborne): only your race gets these quests."))
    local dest = s.sale and (type(s.sale) == "number" and (porMapa(s.sale) or {}).n or tostring(s.sale))
    if dest then table.insert(razones, L("Al terminarla, la mision What Comes Next te lleva en skycutter a " .. dest .. ".",
      "When you finish it, the quest What Comes Next takes you by skycutter to " .. dest .. ".")) end
  elseif sale and type(sale) == "number" then
    table.insert(razones, L("Al salir de " .. anterior.n .. " llegas a " .. nomSale .. " (What Comes Next): es la zona con misiones a tu nivel mas cerca de ahi.",
      "Leaving " .. anterior.n .. " you arrive in " .. nomSale .. " (What Comes Next): it is the zone with quests at your level closest to there."))
  elseif sale then
    table.insert(razones, L("Al salir de " .. anterior.n .. " llegas a " .. nomSale .. " (What Comes Next). Aun no hay datos de WoW Forever de como se viaja desde alli; pendiente de actualizar: la guia cuenta desde tu capital.",
      "Leaving " .. anterior.n .. " you arrive in " .. nomSale .. " (What Comes Next). There is no WoW Forever data yet on how to travel from there; pending update: the guide counts from your capital."))
  elseif i == 1 and t.costo == 0 then
    table.insert(razones, L("Ya estas aqui: no tienes que viajar.", "You are already here: no travelling needed."))
  elseif anterior and anterior.cont == z.cont then
    table.insert(razones, L("Es la zona con misiones a tu nivel mas cerca de " .. anterior.n .. ", en el mismo continente (" .. z.cont .. ").",
      "It is the zone with quests at your level closest to " .. anterior.n .. ", on the same continent (" .. z.cont .. ")."))
  elseif anterior then
    table.insert(razones, L("En " .. anterior.cont .. " no queda una zona de tu bando con misiones a tu nivel tan cerca: por eso cambias a " .. z.cont .. ".",
      "There is no zone for your faction with quests at your level as close on " .. anterior.cont .. ": that is why you move to " .. z.cont .. "."))
  else
    table.insert(razones, L("Es la zona de tu bando con misiones a tu nivel mas cerca de donde estas (" .. z.cont .. ").",
      "It is the zone for your faction with quests at your level closest to where you are (" .. z.cont .. ")."))
  end
  table.insert(razones, L("Pueblo de tu bando: " .. nombrePueblo(pueblo) .. " (posada, vendedores y misiones).",
    "Town for your faction: " .. nombrePueblo(pueblo) .. " (inn, vendors and quests)."))
  table.insert(razones, L("Te dura del nivel " .. t.desde .. " al " .. t.hasta .. ": la guia no te cambia de zona antes.",
    "It lasts from level " .. t.desde .. " to " .. t.hasta .. ": the guide will not move you to another zone before that."))
  return { z = z, s = s, n = n, pueblo = pueblo, razones = razones }
end

-- Eventos para el plan (wowF_Armar): uno por zona, en el nivel en que empieza
function WowF.eventosZonas()
  local g = WowF.planZonas()
  local lista = {}
  if not g then return lista end
  for i, t in ipairs(g.tramos) do
    local d = WowF.detalleTramo(t, i, g)
    if d then
      local texto = Y(L("Sube en " .. d.z.n .. " (niveles " .. t.desde .. "-" .. t.hasta .. ", opcional): " .. d.n .. " misiones",
        "Level in " .. d.z.n .. " (levels " .. t.desde .. "-" .. t.hasta .. ", optional): " .. d.n .. " quests"))
      table.insert(lista, { t.desde, "zona", texto, tramo = t, indice = i })
    end
  end
  return lista
end

-- El tooltip con el porque
function WowF.ayudaTramo(t, i)
  local g = WowF.planZonas()
  local d = g and WowF.detalleTramo(t, i, g)
  if not d then return nil end
  local partes = { "|cffffd100" .. d.z.n .. "|r  |cff9d9d9d(" .. L("niveles ", "levels ") .. t.desde .. "-" .. t.hasta .. ")|r",
    "|cff33ff66" .. L("OPCIONAL: es una recomendacion. Si prefieres otra zona, adelante.", "OPTIONAL: it is a recommendation. If you prefer another zone, go ahead.") .. "|r",
    " ", "|cffffffff" .. L("Por que aqui:", "Why here:") .. "|r" }
  for _, r in ipairs(d.razones) do table.insert(partes, "- " .. r) end
  table.insert(partes, " ")
  table.insert(partes, "|cff9d9d9d" .. L("Clic: ruta paso a paso hasta " .. nombrePueblo(d.pueblo) .. ".", "Click: step-by-step route to " .. nombrePueblo(d.pueblo) .. ".") .. "|r")
  return Y(table.concat(partes, "\n"))
end

-- Clic: la ruta hasta el pueblo de la zona (wowF_Viaje)
function WowF.irAZona(t)
  local z = t and porId(t.id)
  local g = WowF.planZonas()
  if not z or not g then return false end
  local p = z[g.fac] and z[g.fac].pueblos[1]
  if not p then return false end
  local destino = { m = z.m, x = p.x, y = p.y, n = Y(nombrePueblo(p) .. " (" .. z.n .. ")") }
  if WowF.viajeA and WowF.viajeA(destino, { dibujar = true }) then return true end
  -- Sin ruta (no se sabe donde estas): al menos el alfiler en el pueblo
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    pcall(function() C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(z.m, p.x / 100, p.y / 100)); if C_SuperTrack then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end end)
  end
  print("|cff33ccffForever Guide|r: " .. Y(L("alfiler en " .. nombrePueblo(p) .. " (" .. z.n .. ").", "pin on " .. nombrePueblo(p) .. " (" .. z.n .. ").")))
  return true
end
