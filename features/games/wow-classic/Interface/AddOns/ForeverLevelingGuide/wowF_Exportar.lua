-- Forever Leveling Guide (antes wowF Exportar). Parte de guardar el personaje.
-- Guarda los datos de tu personaje en el disco para que la guía wowF los lea sola.
-- No hay que copiar ni pegar nada: juega, sal del juego (o escribe /reload) y abre la guía.
-- /wowf sigue funcionando por si prefieres copiar el texto a mano.

WowFExportarDB = WowFExportarDB or {}
WowF = WowF or {}

-- ===================== Profesiones del personaje (compartido) =====================
-- Las lee por su numero (skillLine) y por su nombre en TODOS los idiomas del cliente, asi cada jugador ve las suyas
-- aunque juegue en otro idioma o tenga plegado el apartado "Profesiones" de la ventana de habilidades.
local NOMBRES_PROF = {
  [171] = { "Alchemy", "Alquimia", "Alchimie", "Alchimia", "Алхимия", "연금술", "炼金术", "鍊金術" },
  [164] = { "Blacksmithing", "Herrería", "Herreria", "Schmiedekunst", "Forge", "Ferraria", "Forgiatura", "Кузнечное дело", "대장기술", "锻造", "鍛造" },
  [165] = { "Leatherworking", "Peletería", "Peleteria", "Lederverarbeitung", "Travail du cuir", "Couraria", "Conciatura", "Кожевничество", "가죽세공", "制皮", "製皮" },
  [197] = { "Tailoring", "Sastrería", "Sastreria", "Schneiderei", "Couture", "Alfaiataria", "Sartoria", "Портняжное дело", "재봉술", "裁缝", "裁縫" },
  [202] = { "Engineering", "Ingeniería", "Ingenieria", "Ingenieurskunst", "Ingénierie", "Engenharia", "Ingegneria", "Инженерное дело", "기계공학", "工程学", "工程學" },
  [333] = { "Enchanting", "Encantamiento", "Verzauberkunst", "Enchantement", "Encantamento", "Incantamento", "Наложение чар", "마법부여", "附魔" },
  [186] = { "Mining", "Minería", "Mineria", "Bergbau", "Minage", "Mineração", "Estrazione", "Горное дело", "채광", "采矿", "採礦" },
  [182] = { "Herbalism", "Herboristería", "Herboristeria", "Herbalismo", "Kräuterkunde", "Herboristerie", "Herborismo", "Erbalismo", "Травничество", "약초채집", "草药学", "草藥學" },
  [393] = { "Skinning", "Desuello", "Kürschnerei", "Dépeçage", "Esfolamento", "Scuoiatura", "Снятие шкур", "무두질", "剥皮", "剝皮" },
  [185] = { "Cooking", "Cocina", "Kochkunst", "Cuisine", "Culinária", "Cucina", "Кулинария", "요리", "烹饪", "烹飪" },
  [129] = { "First Aid", "Primeros auxilios", "Erste Hilfe", "Secourisme", "Primeiros Socorros", "Primo soccorso", "Первая помощь", "응급치료", "急救" },
  [356] = { "Fishing", "Pesca", "Angeln", "Pêche", "Рыбная ловля", "낚시", "钓鱼", "釣魚" },
}
local PRINCIPALES = { [171] = true, [164] = true, [165] = true, [197] = true, [202] = true, [333] = true, [186] = true, [182] = true, [393] = true }
local ID_POR_NOMBRE = {}
for id, lista in pairs(NOMBRES_PROF) do for _, n in ipairs(lista) do ID_POR_NOMBRE[n:lower()] = id end end

-- Numero de la profesion a partir de su nombre en cualquier idioma (nil si no es una profesion)
function WowF.idProfesion(nombre)
  if type(nombre) ~= "string" then return nil end
  return ID_POR_NOMBRE[nombre:lower()] or ID_POR_NOMBRE[(nombre:gsub("^%s+", ""):gsub("%s+$", "")):lower()]
end
function WowF.nombreProfesionEN(id) return NOMBRES_PROF[id] and NOMBRES_PROF[id][1] end

-- Un apartado plegado de la ventana de habilidades esconde sus lineas: se despliega (una vez; se queda desplegado
-- para no provocar un bucle con SKILL_LINES_CHANGED)
local function desplegarHabilidades()
  if not ExpandSkillHeader or not GetNumSkillLines or not GetSkillLineInfo then return end
  for i = GetNumSkillLines(), 1, -1 do
    local _, esCabecera, abierta = GetSkillLineInfo(i)
    if esCabecera and not abierta then ExpandSkillHeader(i) end
  end
end

-- Todas tus profesiones: { { id, nombre (como lo dice tu cliente), en (en ingles), rango, maximo, principal } }
function WowF.profesiones()
  local lista, visto = {}, {}
  -- La beta puede devolver valores "secretos" (no se pueden leer): se tratan como ausentes en vez de romper la lectura
  local function legible(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end
  local function idDe(nombre) local ok, id = pcall(WowF.idProfesion, legible(nombre)); return ok and id or nil end
  local function poner(id, nombre, rango, maximo)
    if not id or not NOMBRES_PROF[id] or visto[id] then return end
    visto[id] = true
    nombre, rango, maximo = legible(nombre), legible(rango), legible(maximo)
    table.insert(lista, { id = id, nombre = type(nombre) == "string" and nombre or NOMBRES_PROF[id][1], en = NOMBRES_PROF[id][1], rango = tonumber(rango) or 0,
      maximo = tonumber(maximo) or 0, principal = PRINCIPALES[id] or false })
  end
  -- Interfaz clasica de habilidades (Classic), en el orden del libro
  if GetNumSkillLines and GetSkillLineInfo then
    pcall(desplegarHabilidades)
    local okN, total = pcall(GetNumSkillLines)
    for i = 1, (okN and tonumber(legible(total)) or 0) do
      local ok, nombre, esCabecera, _, rango, _, _, maximo = pcall(GetSkillLineInfo, i)
      if ok and legible(nombre) and not esCabecera then poner(idDe(nombre), nombre, rango, maximo) end
    end
  end
  -- Interfaz moderna de profesiones: trae el numero de la profesion (sirve en cualquier idioma)
  if GetProfessions and GetProfessionInfo then
    local ok, p1, p2, p3, p4, p5 = pcall(GetProfessions)
    if ok then
      local indices = { p1, p2, p3, p4, p5 } -- puede tener huecos (nil): se recorre en orden 1..5
      for k = 1, 5 do
        local indice = indices[k]
        local ok2, nombre, _, rango, maximo, _, _, linea
        if indice then ok2, nombre, _, rango, maximo, _, _, linea = pcall(GetProfessionInfo, indice) end
        linea = ok2 and legible(linea) or nil
        if ok2 and (nombre or linea) then poner(NOMBRES_PROF[linea or 0] and linea or idDe(nombre), nombre, rango, maximo) end
      end
    end
  end
  return lista
end
-- Tus dos profesiones principales (ids), en el orden del libro de habilidades
function WowF.profesionesPrincipales()
  local res = {}
  for _, p in ipairs(WowF.profesiones()) do if p.principal and #res < 2 then table.insert(res, p.id) end end
  return res
end
-- Rango y maximo de una profesion (por id); nil si no la tienes
function WowF.rangoProfesion(id)
  for _, p in ipairs(WowF.profesiones()) do if p.id == id then return p.rango, p.maximo end end
  return nil
end

local function habilidades()
  local lista = {}
  -- Interfaz clásica de habilidades (Classic); las profesiones van con su nombre en inglés para que la guía las entienda
  if GetNumSkillLines and GetSkillLineInfo then
    pcall(desplegarHabilidades)
    for i = 1, GetNumSkillLines() do
      local nombre, esCabecera, _, rango, _, _, maximo = GetSkillLineInfo(i)
      if nombre and not esCabecera and maximo and maximo > 0 then
        nombre = WowF.nombreProfesionEN(WowF.idProfesion(nombre)) or nombre
        table.insert(lista, nombre .. ":" .. tostring(rango) .. "/" .. tostring(maximo))
      end
    end
  end
  -- Interfaz moderna de profesiones (por si el cliente la usa)
  if #lista == 0 and GetProfessions and GetProfessionInfo then
    local indices = { GetProfessions() }
    for _, indice in ipairs(indices) do
      if indice then
        local nombre, _, rango, maximo = GetProfessionInfo(indice)
        if nombre then table.insert(lista, nombre .. ":" .. tostring(rango) .. "/" .. tostring(maximo)) end
      end
    end
  end
  return table.concat(lista, ",")
end

local function equipo()
  local lista = {}
  for ranura = 1, 19 do
    local enlace = GetInventoryItemLink("player", ranura)
    if enlace then
      local id = enlace:match("item:(%d+)")
      if id then table.insert(lista, ranura .. "=" .. id) end
    end
  end
  return table.concat(lista, ",")
end

-- Puntos puestos en cada rama de talentos, con el nombre en inglés del cliente
local function talentos()
  if not GetNumTalentTabs or not GetTalentTabInfo then return "" end
  local ok, total = pcall(GetNumTalentTabs)
  if not ok or not total then return "" end
  local lista = {}
  for pestana = 1, total do
    local datos = { GetTalentTabInfo(pestana) }
    local nombre = datos[1]
    -- Según la versión del cliente, los puntos vienen en la posición 3 o en la 5
    local puntos = tonumber(datos[5]) or tonumber(datos[3]) or 0
    if nombre then table.insert(lista, nombre .. ":" .. tostring(puntos)) end
  end
  return table.concat(lista, ",")
end

-- Valor del juego como texto; nil si el cliente lo devuelve "secreto" (no se puede leer ni unir en texto)
local function numero(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  local ok, s = pcall(function() return tostring(v) .. "" end)
  if ok and type(s) == "string" then return s end
  return nil
end
local function llamar(f, ...)
  if type(f) ~= "function" then return nil end
  local ok, v = pcall(f, ...)
  if ok then return numero(v) end
  return nil
end

local function texto()
  local _, razaEn = UnitRace("player")
  local _, claseEn = UnitClass("player")
  local partes = {
    "WF1",
    "nombre=" .. (llamar(UnitName, "player") or ""),
    "raza=" .. (razaEn or ""),
    "clase=" .. (claseEn or ""),
    "nivel=" .. (llamar(UnitLevel, "player") or "0"),
    "habilidades=" .. habilidades(),
  }
  -- Atributos: fuerza, agilidad, aguante, intelecto, espíritu
  local atributos = {}
  for i = 1, 5 do
    table.insert(atributos, llamar(UnitStat, "player", i) or "0")
  end
  table.insert(partes, "atributos=" .. table.concat(atributos, ","))
  table.insert(partes, "salud=" .. (llamar(UnitHealthMax, "player") or "0"))
  table.insert(partes, "mana=" .. (llamar(UnitPowerMax, "player", 0) or "0"))
  table.insert(partes, "equipo=" .. equipo())
  -- Campos nuevos de la versión 2: la guía los usa si los entiende y los ignora si no.
  local faccion = UnitFactionGroup and UnitFactionGroup("player") or ""
  table.insert(partes, "faccion=" .. (faccion or ""))
  table.insert(partes, "oro=" .. (llamar(GetMoney) or "0"))
  table.insert(partes, "talentos=" .. talentos())
  return table.concat(partes, ";")
end

local function textoSeguro()
  local ok, t = pcall(texto)
  if ok then return t end
  return "WF1"
end

-- Al salir del juego el cliente ya no contesta a estas preguntas y devuelve todo en cero.
-- Por eso guardamos en memoria la última foto buena y es esa la que se escribe al disco.
local function sirve(t)
  if not t then return false end
  local a = t:match("atributos=([^;]*)")
  if not a then return false end
  for n in a:gmatch("%d+") do
    if tonumber(n) and tonumber(n) > 0 then return true end
  end
  return false
end

local ultimoBueno = nil

-- Guardado automático: cada personaje queda con su propia entrada
local function guardar(alSalir)
  if not UnitName("player") then return end
  local t
  if alSalir then
    -- Al salir no preguntamos nada: escribimos la última foto buena de esta sesión
    t = ultimoBueno or textoSeguro()
  else
    t = textoSeguro()
    if sirve(t) then
      ultimoBueno = t
    elseif ultimoBueno then
      t = ultimoBueno
    end
  end

  local nombre = UnitName("player") or "?"
  local reino = (GetRealmName and GetRealmName()) or ""
  local clave = nombre
  if reino ~= "" then clave = nombre .. "-" .. reino end

  WowFExportarDB.version = 2
  WowFExportarDB.personajes = WowFExportarDB.personajes or {}

  -- Nunca cambiar unos datos buenos por unos vacíos
  local anterior = WowFExportarDB.personajes[clave]
  if anterior and sirve(anterior.texto) and not sirve(t) then return end

  local _, claseEn = UnitClass("player")
  WowFExportarDB.personajes[clave] = {
    nombre = nombre,
    reino = reino,
    clase = claseEn or "",
    nivel = UnitLevel("player") or 0,
    momento = (time and time()) or 0,
    fecha = (date and date("%Y-%m-%d %H:%M")) or "",
    texto = t,
  }
  WowFExportarDB.ultimo = clave
end

-- Mazmorras (lista en wowF_Mazmorras.lua, la genera la guia): al llegar al nivel de una, avisa y pone un alfiler en su entrada
local AZUL = "|cff33ccffForever Guide|r: "
local function miFaccion()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  if f == "Horde" then return 1 elseif f == "Alliance" then return 2 end
  return 0
end
local function esMia(m) return not m.sn and (m.f == 0 or m.f == miFaccion()) end -- 9-oct: sn = nivel aun no disponible en WoW Forever (no se recomienda)
-- 5-oct: XP de una mision de mazmorra. q[3] de wowF_Mazmorras.lua es la XP BASE de Classic (Wowhead); Forever da mas
-- (base x multiplicador, y Blizzard rebajo ese extra el 1-oct sin publicar la formula). La XP REAL se guarda cuando abres
-- la mision en el juego (QUEST_DETAIL / QUEST_COMPLETE, wowF_MisionesMazmorra.lua) en WowFExportarDB.xpReal[id] = { xp, nivel }
-- (por cuenta). Devuelve xp, exacta: la real (exacta = true) o, si no se vio, 1 = "da XP" / 0 (exacta = false; nunca se muestra).
-- 9-oct (CERO datos de Classic): q[3] ya no es la cifra de Wowhead (Classic) sino 1/0 = da XP. Con datos viejos (cifra) se reduce a 1.
local function xpMision(q)
  if type(q) ~= "table" then return 0, false end
  local base = ((tonumber(q.xpBase or q.xp) or 0) > 0) and 1 or 0
  local tabla = type(WowFExportarDB) == "table" and type(WowFExportarDB.xpReal) == "table" and WowFExportarDB.xpReal
  local r = tabla and q.id and tabla[q.id]
  -- La XP baja cuando el personaje supera el nivel de la mision: la vista solo es EXACTA si se vio a tu nivel actual.
  -- Vista a un nivel mayor que el tuyo = te dara al menos eso. Vista a un nivel menor = no sirve (se usa la base).
  local xp, visto
  if type(r) == "table" then xp, visto = tonumber(r.xp), tonumber(r.nivel) else xp = tonumber(r) end
  if xp and xp > 0 then
    local ahora = tonumber(numero(llamar(UnitLevel, "player")))
    if visto and ahora and visto == ahora then return xp, true end
    if visto and ahora and visto > ahora and xp > base then return xp, false end
  end
  return base, false
end
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
-- Texto de la XP: exacta = "+N XP"; si no, NADA. 5-oct (Andy, captura de Blackfathom: el addon decia 2750 y la mision daba 8550):
-- la XP de Wowhead es la base de Classic y Forever da otra (formula sin publicar), asi que solo se ensena la que el juego ya te dio a tu nivel.
local function textoXP(xp, exacta)
  xp = tonumber(xp) or 0
  if exacta and xp > 0 then return "+" .. xp .. " XP" end
  return ""
end
WowF.xpMision, WowF.textoXP = xpMision, textoXP
-- 6-oct (amigo de Andy: "hice la mision de la mazmorra y sigue en el mapa"): el juego tarda un instante en marcar como hecha
-- una mision recien entregada (y ya salio del diario), asi que lo entregado en esta sesion cuenta como hecho al momento.
local entregadasSesion = {}
local function misionHecha(id)
  id = tonumber(id)
  if not id then return false end
  if entregadasSesion[id] then return true end
  local ok, r = false, nil
  if C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompleted) == "function" then ok, r = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
  elseif type(IsQuestFlaggedCompleted) == "function" then ok, r = pcall(IsQuestFlaggedCompleted, id) end
  if ok and issecretvalue and issecretvalue(r) then return false end
  return ok and (r == true or r == 1)
end
local function misionEnDiario(id)
  id = tonumber(id)
  if not id then return false end
  local ok, r = false, nil
  if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then ok, r = pcall(C_QuestLog.GetLogIndexForQuestID, id)
  elseif type(GetQuestLogIndexByID) == "function" then ok, r = pcall(GetQuestLogIndexByID, id) end
  if ok and issecretvalue and issecretvalue(r) then return false end
  return ok and type(r) == "number" and r > 0
end
WowF.misionHecha, WowF.misionEnDiario = misionHecha, misionEnDiario
WowF.misionEntregada = function(id) id = tonumber(id); if id then entregadasSesion[id] = true end end
WowF._olvidarEntregadas = function() entregadasSesion = {} end -- para las pruebas
local vigiaEntregas = CreateFrame("Frame")
pcall(vigiaEntregas.RegisterEvent, vigiaEntregas, "QUEST_TURNED_IN")
vigiaEntregas:SetScript("OnEvent", function(_, _, id) WowF.misionEntregada(id) end)
-- Misiones de dentro de una mazmorra para tu faccion: { { n, nivel, xp, xpExacta, id, hecha } }, la XP de las que te faltan
-- y si esa suma es exacta (todas con la XP real vista en el juego)
local function misionesDe(m)
  local lista, xp, exacta = {}, 0, true
  local fac = miFaccion()
  for _, q in ipairs((m and m.q) or {}) do
    if q[4] == 0 or q[4] == fac then
      local hecha = misionHecha(q[5])
      -- quien la da y donde (q[6..10]); dentro = se recoge dentro de la mazmorra (o la empieza un objeto que cae dentro)
      local e = { n = q[1], nivel = q[2], xpBase = q[3], id = q[5], hecha = hecha, quien = q[6], m = q[7], x = q[8], y = q[9], dentro = q[10], npc = q[11], cadena = q.c or false, mazmorra = m }
      e.xp, e.xpExacta = xpMision(e)
      table.insert(lista, e)
      if not hecha then xp = xp + e.xp; if not e.xpExacta then exacta = false end end
    end
  end
  return lista, xp, exacta
end
-- Las de tu nivel; si no hay ninguna, las del siguiente nivel que tenga (proximas = true). Primero las que tienen lugar.
local function disponibles(nivel)
  local lista, siguiente = {}, nil
  for _, m in ipairs(WowFMazmorras or {}) do
    if esMia(m) and nivel >= m.d and nivel <= m.h then table.insert(lista, m) end
    if esMia(m) and m.d > nivel and (not siguiente or m.d < siguiente) then siguiente = m.d end
  end
  local proximas = false
  if #lista == 0 and siguiente then
    proximas = true
    for _, m in ipairs(WowFMazmorras or {}) do
      if esMia(m) and m.d == siguiente then table.insert(lista, m) end
    end
  end
  local function peso(m) return (m.m and 0 or 2) + (m.a and 1 or 0) end
  table.sort(lista, function(a, b) if peso(a) ~= peso(b) then return peso(a) < peso(b) end return a.d < b.d end)
  return lista, proximas
end
local function coordenadas(m) return string.format("%.1f, %.1f", m.x, m.y) end

local function marcar(m)
  if not m.m then
    print(WowF.T(AZUL .. m.n .. L(" esta en " .. m.z .. ": entrada aun no confirmada en WoW Forever; se actualizara.", " is in " .. m.z .. ": entrance not confirmed in WoW Forever yet; it will be updated.")))
    return
  end
  local nota = m.a and L(" (entrada aun sin confirmar en WoW Forever; se actualizara)", " (entrance not confirmed in WoW Forever yet; it will be updated)") or ""
  local puesto = false
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    puesto = pcall(function()
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(m.m, m.x / 100, m.y / 100))
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end)
  end
  -- Si tienes TomTom, tambien te pone la flecha
  if TomTom and TomTom.AddWaypoint then
    if pcall(TomTom.AddWaypoint, TomTom, m.m, m.x / 100, m.y / 100, { title = m.n }) then puesto = true end
  end
  if puesto then
    print(WowF.T(AZUL .. (m.lugar and "alfiler en " or "alfiler en la entrada de ") .. m.n .. ": " .. m.z .. " " .. coordenadas(m) .. nota .. ". Abre el mapa (M) para ver la ruta."))
  else
    print(WowF.T(AZUL .. m.n .. ": " .. m.z .. ", coordenadas " .. coordenadas(m) .. nota .. "."))
  end
  -- 5-oct: NPC con posicion sin confirmar en Forever (entrenador solo de MTSL): linea gris aparte
  if m.aprox and WowF.textoAprox then print("|cff999999   " .. WowF.textoAprox() .. "|r") end
end

local function listarMazmorras()
  local nivel = UnitLevel("player") or 1
  local lista, proximas = disponibles(nivel)
  if #lista == 0 then print(WowF.T(AZUL .. "no quedan mazmorras por delante.")); return end
  if proximas then
    print(WowF.T(AZUL .. "eres nivel " .. nivel .. "; las primeras mazmorras se abren al nivel " .. lista[1].d .. ". Ya puedes marcar el camino con /wowf ruta y el numero:"))
  else
    print(WowF.T(AZUL .. "mazmorras para tu nivel (" .. nivel .. "). Escribe /wowf ruta y el numero para marcarla en el mapa:"))
  end
  for i, m in ipairs(lista) do
    local lugar = m.z .. ((m.m and not m.a) and "" or L(" (entrada aun no confirmada en WoW Forever; se actualizara)", " (entrance not confirmed in WoW Forever yet; it will be updated)"))
    print(WowF.T("  " .. i .. ". " .. m.n .. " (niveles " .. m.d .. " a " .. m.h .. ") - " .. lugar))
  end
end

local function ruta(texto)
  local lista = disponibles(UnitLevel("player") or 1)
  local elegida = lista[tonumber(texto) or 0]
  if not elegida and texto ~= "" then
    local buscado = texto:lower()
    for _, m in ipairs(WowFMazmorras or {}) do
      if esMia(m) and m.n:lower():find(buscado, 1, true) then elegida = m; break end
    end
  end
  if elegida then (WowF.irAMazmorra or marcar)(elegida) else listarMazmorras() end
end

-- Al subir de nivel: avisa de las mazmorras que se abren y marca la primera
local function mazmorrasNuevas(nivel)
  local nuevas = {}
  for _, m in ipairs(WowFMazmorras or {}) do
    if esMia(m) and m.d == nivel then table.insert(nuevas, m) end
  end
  if #nuevas == 0 then return end
  local nombres = {}
  for _, m in ipairs(nuevas) do table.insert(nombres, m.n) end
  print(WowF.T(AZUL .. "ya tienes nivel para " .. table.concat(nombres, ", ") .. ". Escribe /wowf mazmorras para ver todas."))
  local conLugar = nuevas[1]
  for _, m in ipairs(nuevas) do if m.m and not m.a then conLugar = m; break end end
  marcar(conLugar)
end

local vigia = CreateFrame("Frame")
vigia:RegisterEvent("PLAYER_ENTERING_WORLD")
vigia:RegisterEvent("PLAYER_LEVEL_UP")
vigia:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
vigia:RegisterEvent("SKILL_LINES_CHANGED")
vigia:RegisterEvent("CHARACTER_POINTS_CHANGED")
vigia:RegisterEvent("PLAYER_MONEY")
vigia:RegisterEvent("PLAYER_LOGOUT")
vigia:SetScript("OnEvent", function(_, evento, nuevoNivel)
  if evento == "PLAYER_LEVEL_UP" then
    guardar(false)
    print(WowF.T("|cff33ccffForever Guide|r: nivel " .. tostring(nuevoNivel or UnitLevel("player")) .. ". Tu plan se pone al dia solo."))
    pcall(mazmorrasNuevas, tonumber(nuevoNivel) or UnitLevel("player") or 1)
  elseif evento == "PLAYER_LOGOUT" then
    guardar(true)
  elseif evento == "PLAYER_ENTERING_WORLD" then
    -- Al entrar, el cliente tarda un momento en tener listos los datos: se reintenta
    if C_Timer and C_Timer.After then
      for _, segundos in ipairs({ 5, 15, 30 }) do
        C_Timer.After(segundos, function() guardar(false) end)
      end
    else
      guardar(false)
    end
  else
    guardar(false)
  end
end)

-- Ventana con el texto (sigue disponible para copiar a mano)
-- 11-oct (hibrido): fondo de piedra con cabecera pequena (antes BasicFrameTemplateWithInset de Blizzard),
-- el aviso en Signika y el texto dentro de una tarjeta de piedra
local E = WowF.estilo
local marco = CreateFrame("Frame", "wowFExportarMarco", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
marco:SetSize(560, 260)
marco:SetPoint("CENTER")
marco:SetFrameStrata("DIALOG")
marco:SetMovable(true)
marco:EnableMouse(true)
marco:RegisterForDrag("LeftButton")
marco:SetScript("OnDragStart", marco.StartMoving)
marco:SetScript("OnDragStop", marco.StopMovingOrSizing)
marco:Hide()
local cabExportar
if E then
  E.marco(marco, "panel")
  cabExportar = E.cabecera(marco, 20)
  cabExportar.titulo:SetText("Forever Guide")
end
local cerrarExportar = CreateFrame("Button", nil, marco, "UIPanelButtonTemplate")
cerrarExportar:SetSize(18, 18)
cerrarExportar:SetText("X")
if E then E.boton(cerrarExportar, "cuero", 11) end
if cabExportar then cerrarExportar:SetPoint("RIGHT", cabExportar.fondo, "RIGHT", -4, 0) else cerrarExportar:SetPoint("TOPRIGHT", -6, -6) end
cerrarExportar:SetScript("OnClick", function() marco:Hide() end)
marco.CloseButton = marco.CloseButton or cerrarExportar

local titulo = E and E.cuerpo(marco, nil, 11) or marco:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
titulo:SetPoint("TOPLEFT", 14, -34)
titulo:SetPoint("RIGHT", marco, "RIGHT", -14, 0)
WowF.textoFijo(titulo, "Forever Guide: personaje guardado. Copia el texto solo si lo quieres pegar a mano")

local hojaExportar = E and E.tarjeta(marco) or nil
if hojaExportar then hojaExportar:SetPoint("TOPLEFT", 10, -52); hojaExportar:SetPoint("BOTTOMRIGHT", -10, 10) end
local desplazar = CreateFrame("ScrollFrame", nil, marco, "UIPanelScrollFrameTemplate")
desplazar:SetPoint("TOPLEFT", 16, -58)
desplazar:SetPoint("BOTTOMRIGHT", -32, 16)
if hojaExportar and desplazar.SetFrameLevel and hojaExportar.GetFrameLevel then pcall(function() desplazar:SetFrameLevel(hojaExportar:GetFrameLevel() + 2) end) end

local caja = CreateFrame("EditBox", nil, desplazar)
caja:SetMultiLine(true)
caja:SetFontObject(ChatFontNormal)
caja:SetWidth(500)
caja:SetAutoFocus(false)
caja:SetScript("OnEscapePressed", function(self) self:ClearFocus(); marco:Hide() end)
desplazar:SetScrollChild(caja)

SLASH_WOWF1 = "/wowf"
SLASH_WOWF2 = "/flg"
SLASH_WOWF3 = "/forever"
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower()
  if orden == "mazmorras" or orden == "m" then listarMazmorras(); return end
  if orden == "ruta" then ruta(resto or ""); return end
  if orden == "borrar" then
    if WowF.pararViaje then WowF.pararViaje(true) end
    if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
    print(WowF.T(AZUL .. "alfiler quitado."))
    return
  end
  guardar(false)
  local t = ultimoBueno or textoSeguro()
  caja:SetText(WowF.T(t))
  marco:Show()
  caja:SetFocus()
  caja:HighlightText()
  if sirve(t) then
    print(WowF.T("|cff33ccffForever Guide|r: personaje guardado. Sal del juego o escribe /reload y la guia lo leera sola."))
  else
    print(WowF.T("|cff33ccffForever Guide|r: el cliente todavia no da tus datos. Espera unos segundos dentro del juego y vuelve a escribir /wowf."))
  end
end

-- El panel (wowF_Panel.lua) usa estas funciones
WowF = WowF or {}
WowF.marcar, WowF.disponibles, WowF.esMia, WowF.miFaccion, WowF.guardar = marcar, disponibles, esMia, miFaccion, guardar
WowF.misionesDe = misionesDe
WowF.llamar, WowF.numero = llamar, numero -- valores del juego que pueden ser secretos (los usa wowF_MisionesMazmorra.lua)

print(WowF.T("|cff33ccffForever Guide|r: addon activo. |cffffd100/wowf|r = tu plan completo (talentos, profesiones, equipo, mazmorras) · |cffffd100/wowf panel|r = mostrar u ocultar el panel."))
