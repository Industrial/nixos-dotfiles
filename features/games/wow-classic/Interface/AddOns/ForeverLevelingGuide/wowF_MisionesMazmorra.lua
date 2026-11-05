-- wowF Misiones de mazmorra: marca al NPC que te da una mision de mazmorra (datos: q de wowF_Mazmorras.lua, de Wowhead /forever).
-- Casi todas se recogen FUERA (en ciudades o junto a la entrada) y se terminan dentro: hay que cogerlas antes de entrar.
-- 1) Raton sobre el NPC: "MISION DE MAZMORRA ... cogela ANTES de entrar" (o "se recoge dentro").
-- 2) Ventana de la mision (al hablarle): aviso encima con la mazmorra.
-- 3) Mapa del mundo (M), zona y continente: "!" con aro morado y etiqueta "Mision: <mazmorra>"; raton = que mision es, quien, donde y que hacer;
--    clic (tambien en el Libro y en la ficha del panel) = ruta paso a paso hasta el NPC (recuadro de wowF_Viaje.lua).
-- 4) Sobre la cabeza del NPC: el mismo icono, si tienes encendidas las placas de NPC amistosos (/wowf placas on).
-- /wowf misiones: las de tu nivel con quien las da y donde; /wowf misiones off|on apaga o enciende las marcas.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local AZUL = "|cff33ccffForever Guide|r: "
local ORO, VERDE, GRIS, BLANCO, NARANJA, MORADO = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933", "|cffc77dff"
local ICONO = "Interface\\GossipFrame\\AvailableQuestIcon"
local COLOR = { 0.78, 0.49, 1 } -- morado: mazmorra

local function apagado() return WowFExportarDB.misionesMazmorra == false end
local function seguro(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function nivelActual()
  local ok, n = pcall(UnitLevel, "player")
  n = ok and seguro(n)
  return tonumber(n) or 1
end
local function enElDiario(id)
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

-- Misiones de mazmorra que te tocan: de tu faccion, sin hacer, y de tu nivel (hasta 2 niveles antes de poder cogerlas)
-- Devuelve la lista y dos indices: por id de NPC y por nombre del NPC
local function pendientes()
  local lista, porNpc, porNombre, porId = {}, {}, {}, {}
  if not WowF.misionesDe or not WowFMazmorras then return lista, porNpc, porNombre, porId end
  local nivel = nivelActual()
  for _, m in ipairs(WowFMazmorras) do
    if (not WowF.esMia or WowF.esMia(m)) then
      for _, q in ipairs((WowF.misionesDe(m))) do
        porId[q.id] = q
        if not q.hecha and nivel >= q.nivel - 2 and nivel <= m.h + 2 then
          q.yaLaTienes = enElDiario(q.id)
          table.insert(lista, q)
          if q.npc and q.npc > 0 then porNpc[q.npc] = porNpc[q.npc] or {}; table.insert(porNpc[q.npc], q) end
          if q.quien and q.quien ~= "" then porNombre[q.quien] = porNombre[q.quien] or {}; table.insert(porNombre[q.quien], q) end
        end
      end
    end
  end
  return lista, porNpc, porNombre, porId
end
WowF.misionesMazmorraPendientes = pendientes

-- "antes de entrar" / "se recoge dentro", con el nivel si aun no llegas
local function cuando(q, nivel)
  local t = q.dentro and (GRIS .. "se recoge dentro de la mazmorra|r") or (NARANJA .. "cogela ANTES de entrar|r")
  if nivel < q.nivel then t = WowF.yaTraducido(NARANJA .. L("AUN NO te la da: desde nivel " .. q.nivel, "NOT YET: from level " .. q.nivel) .. "|r") end
  if q.yaLaTienes then t = VERDE .. "ya la tienes|r" end
  return t
end
WowF.cuandoMisionMazmorra = cuando
-- 7-oct (amigo de Andy, nivel 30, Scarlet Monastery pide 33-34): con nivel bajo, nunca "cogela ANTES de entrar":
-- el nivel exacto que pide, el tuyo y, si pasa del tope de la beta (30), que hoy no se puede
local TOPE_BETA = 30
local deFuera -- 7-oct: se rellena mas abajo (la usa resumenNivelesFuera)
function WowF.aunNoMision(q, nivel)
  nivel = nivel or nivelActual()
  if not q or nivel >= (q.nivel or 0) then return nil end
  local t = L("AÚN NO te la da: pide nivel " .. q.nivel .. " (eres " .. nivel .. ")", "NOT YET: it needs level " .. q.nivel .. " (you are " .. nivel .. ")")
  if q.nivel > TOPE_BETA then t = t .. L(". La beta llega al nivel " .. TOPE_BETA .. ": aún no se puede coger", ". The beta stops at level " .. TOPE_BETA .. ": it cannot be picked up yet") end
  return WowF.yaTraducido(NARANJA .. t .. "|r")
end
-- 7-oct (Andy: "si son 5 de fuera y por nivel solo puedo coger 2, como se cuales"): "YA puedes coger X de N" y la lista
-- de las que aun no, cada una con su nivel exacto y quien la da. nil si todas se pueden coger ya.
function WowF.resumenNivelesFuera(m, nivel)
  if not m then return nil end
  nivel = nivel or nivelActual()
  local total, ya, tarde = 0, 0, {}
  for _, g in ipairs(deFuera(m)) do for _, q in ipairs(g.q) do
    total = total + 1
    if nivel >= (q.nivel or 0) then ya = ya + 1 else table.insert(tarde, q) end
  end end
  if #tarde == 0 then return nil, ya, total end
  table.sort(tarde, function(a, b) return (a.nivel or 0) < (b.nivel or 0) end)
  local t = VERDE .. L("YA puedes coger " .. ya .. " de " .. total, "You can take " .. ya .. " of " .. total .. " NOW") .. "|r"
    .. NARANJA .. L(". AÚN NO (eres nivel " .. nivel .. "):", ". NOT YET (you are level " .. nivel .. "):") .. "|r"
  for _, q in ipairs(tarde) do
    t = t .. "\n   " .. BLANCO .. q.n .. "|r" .. NARANJA .. L(" - nivel ", " - level ") .. (q.nivel or "?") .. "|r" .. GRIS .. " (" .. (q.quien or "?") .. ")|r"
  end
  if (tarde[#tarde].nivel or 0) > TOPE_BETA then
    t = t .. "\n   " .. GRIS .. L("Las de nivel mayor que " .. TOPE_BETA .. " no se pueden coger en la beta.", "Those above level " .. TOPE_BETA .. " cannot be picked up in the beta.") .. "|r"
  end
  return WowF.yaTraducido(t), ya, total
end

-- Misiones que da esta unidad (NPC): por su id (del GUID) y, si no se puede leer, por su nombre
local function deLaUnidad(unidad)
  if apagado() or not UnitExists or not UnitExists(unidad) then return nil end
  local _, porNpc, porNombre = pendientes()
  local ok, guid = pcall(UnitGUID, unidad)
  guid = ok and seguro(guid)
  if type(guid) == "string" then
    local tipo, _, _, _, _, id = strsplit("-", guid)
    if tipo == "Creature" and tonumber(id) and porNpc[tonumber(id)] then return porNpc[tonumber(id)] end
  end
  local ok2, n = pcall(UnitName, unidad)
  n = ok2 and seguro(n)
  if type(n) == "string" then return porNombre[n] end
  return nil
end
WowF.misionesMazmorraDe = deLaUnidad

-- ----- 1) Tooltip del NPC -----
local function lineaTooltip(tt)
  if not tt or not tt.GetUnit then return end
  local ok, _, unidad = pcall(tt.GetUnit, tt)
  if not ok or not unidad then return end
  local lista = deLaUnidad(unidad)
  if not lista or #lista == 0 then return end
  local nivel = nivelActual()
  tt:AddLine(WowF.T("Forever Guide: MISION DE MAZMORRA"), COLOR[1], COLOR[2], COLOR[3])
  for _, q in ipairs(lista) do
    tt:AddLine(WowF.T(BLANCO .. q.n .. "|r" .. GRIS .. " (" .. q.mazmorra.n .. ")|r - " .. cuando(q, nivel)), 1, 1, 1, true)
    local corta = WowF.lineaMisionCorta and WowF.lineaMisionCorta(q) or ""
    if corta ~= "" then tt:AddLine("   " .. corta, 1, 1, 1, true) end
  end
  tt:Show()
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tt) pcall(lineaTooltip, tt) end)
elseif GameTooltip and GameTooltip.HookScript then
  pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tt) pcall(lineaTooltip, tt) end)
end

-- ----- 2) Ventana de la mision -----
local cartel
local function cartelMision()
  if cartel or not QuestFrame then return cartel end
  cartel = CreateFrame("Frame", nil, QuestFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  cartel:SetSize(300, 58)
  cartel:SetPoint("BOTTOM", QuestFrame, "TOP", 0, -2)
  cartel:SetFrameStrata("HIGH")
  -- 11-oct (rediseno "hibrido"): aviso de piedra con raya brasa, icono en su casilla y texto de la paleta
  local E = WowF.estilo
  if E and E.marco then
    E.marco(cartel, "aviso")
  else
    cartel.fondo = cartel:CreateTexture(nil, "BACKGROUND")
    cartel.fondo:SetAllPoints()
    if cartel.fondo.SetColorTexture then cartel.fondo:SetColorTexture(0.12, 0.04, 0.2, 0.92) end
  end
  cartel.casilla = cartel:CreateTexture(nil, "ARTWORK", nil, 1)
  cartel.casilla:SetSize(30, 30)
  cartel.casilla:SetPoint("TOPLEFT", 10, -12)
  if cartel.casilla.SetColorTexture then
    local c = E and E.color and E.color.piedra2 or { 0.16, 0.15, 0.14 }
    cartel.casilla:SetColorTexture(c[1], c[2], c[3], 1)
  end
  cartel.icono = cartel:CreateTexture(nil, "ARTWORK", nil, 3)
  cartel.icono:SetSize(24, 24)
  cartel.icono:SetPoint("CENTER", cartel.casilla, "CENTER", 0, 0)
  cartel.icono:SetTexture(ICONO)
  -- Retrato redondo de quien da la mision (wowF_Retratos.lua) en lugar de la casilla; sin retrato, la casilla de siempre
  if WowF.marcoRetrato then
    cartel.retrato = WowF.marcoRetrato(cartel, 30)
    cartel.retrato:SetPoint("CENTER", cartel.casilla, "CENTER", 0, 0)
  end
  cartel.texto =cartel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  if E and E.cuerpo then E.cuerpo(cartel, cartel.texto, 11) end
  cartel.texto:SetPoint("TOPLEFT", cartel.casilla, "TOPRIGHT", 8, 0)
  cartel.texto:SetWidth(250)
  cartel.texto:SetJustifyH("LEFT")
  if cartel.texto.SetSpacing then cartel.texto:SetSpacing(2) end
  cartel:Hide()
  return cartel
end
-- 5-oct: XP REAL de una mision de mazmorra. La de los datos es la base de Classic (Wowhead), el minimo; al abrir la mision
-- (QUEST_DETAIL) o al entregarla (QUEST_COMPLETE) el juego dice lo que da: se guarda por cuenta en WowFExportarDB.xpReal[id]
-- = { xp = N, nivel = nivel del personaje cuando se vio } y se usa tal cual (WowF.xpMision, wowF_Exportar.lua).
-- Solo las misiones de mazmorra de los datos. Valores secretos o API que no existe = no se guarda nada.
local function registrarXP()
  if type(GetQuestID) ~= "function" or type(GetRewardXP) ~= "function" then return end
  local leer = WowF.llamar or function(f) local ok, v = pcall(f); v = ok and seguro(v); return v ~= nil and tostring(v) or nil end
  local id, xp = tonumber(leer(GetQuestID)), tonumber(leer(GetRewardXP))
  if not id or id <= 0 or not xp or xp <= 0 then return end
  local _, _, _, porId = pendientes()
  if not porId[id] then return end
  WowFExportarDB.xpReal = type(WowFExportarDB.xpReal) == "table" and WowFExportarDB.xpReal or {}
  WowFExportarDB.xpReal[id] = { xp = math.floor(xp + 0.5), nivel = nivelActual() }
end
WowF.registrarXPMision = registrarXP -- para las pruebas
local function mostrarCartel()
  local c = cartelMision()
  if not c then return end
  c:Hide()
  if apagado() or type(GetQuestID) ~= "function" then return end
  local ok, id = pcall(GetQuestID)
  id = ok and seguro(id)
  local _, _, _, porId = pendientes()
  local q = id and porId[id]
  if not q then return end
  c.texto:SetText(WowF.T(MORADO .. "MISION DE MAZMORRA: " .. q.mazmorra.n .. "|r\n"
    .. (q.dentro and (BLANCO .. "Se recoge aqui dentro: aceptala y terminala antes de salir.|r")
      or (BLANCO .. "Aceptala ahora: se termina DENTRO de la mazmorra.|r"))
    .. (q.xp and q.xp > 0 and (VERDE .. "  " .. WowF.textoXP(WowF.xpMision(q)) .. "|r") or ""))
    .. "\n" .. (WowF.dondeSeEntrega and WowF.dondeSeEntrega(q) or ""))
  -- 11-oct (hibrido): mismos textos, colores de la paleta (cabecera brasa, cuerpo hueso, detalle tenue)
  local E = WowF.estilo
  if E and E.cod then
    local t = c.texto:GetText() or ""
    t = t:gsub("|cffc77dff", E.cod.brasa, 1):gsub("|cffffffff", E.cod.texto):gsub("|cff999999", E.cod.tenue):gsub("|cffcccccc", E.cod.tenue)
    c.texto:SetText(t)
  end
  local alto = (c.texto.GetStringHeight and tonumber(c.texto:GetStringHeight())) or 0
  c:SetHeight(math.max(58, alto + 26))
  if c.retrato then
    local okR = pcall(c.retrato.poner, c.retrato, { unidad = "npc", npc = (WowF.npcDeUnidad and WowF.npcDeUnidad("npc")) or q.npc, icono = ICONO })
    if okR then c.casilla:Hide(); c.icono:Hide() else c.retrato:Hide() end
  end
  c:Show()
end
WowF.cartelMisionMazmorra = function() mostrarCartel(); return cartel and cartel:IsShown() and cartel.texto:GetText() end -- para las pruebas

-- ----- 3) Iconos en el mapa del mundo -----
-- Icono propio: "!" amarillo dentro de un aro MORADO (verde = la mision a la que vas ahora), con una etiqueta debajo
-- "Mision: <mazmorra>". Salen en el mapa de la zona y tambien en el del continente. Raton encima = que mision es y que hacer.
local pines = {}
local function lienzo()
  if not WorldMapFrame or WowF.interfazMando() then return nil end -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
  if WorldMapFrame.GetCanvas then return WorldMapFrame:GetCanvas() end
  return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end
-- Un punto (mapa, x, y) visto en el mapa abierto (0-100), o nil si no cae en el
local function enVista(m, x, y, visto)
  if m == visto then return x, y end
  -- 4-oct: con las esquinas del mundo (wowF_Viaje); GetMapRectOnMap solo vale si el mapa visto CONTIENE al otro
  if WowF.proyectar then
    local vx, vy = WowF.proyectar(m, x, y, visto)
    if vx and vx >= -0.5 and vx <= 100.5 and vy >= -0.5 and vy <= 100.5 then return vx, vy end
    return nil
  end
  if not C_Map or not C_Map.GetMapRectOnMap then return nil end
  local ok, izq, der, arr, aba = pcall(C_Map.GetMapRectOnMap, m, visto)
  if not ok or not izq or not der or der == izq then return nil end
  return (izq + (der - izq) * x / 100) * 100, (arr + (aba - arr) * y / 100) * 100
end
-- Un icono por NPC (puede dar varias): solo los de fuera. Con mapa: los que se ven en ese mapa (con su x, y en el)
local function enMapa(mapa)
  local grupos, orden = {}, {}
  for _, q in ipairs((pendientes())) do
    if not q.dentro and not q.yaLaTienes and q.m and q.m > 0 and q.x and q.x > 0 then
      local vx, vy = q.x, q.y
      if mapa then vx, vy = enVista(q.m, q.x, q.y, mapa) end
      if vx then
        local k = (q.quien or "") .. "|" .. q.x .. "|" .. q.y
        if not grupos[k] then grupos[k] = { quien = q.quien, m = q.m, x = q.x, y = q.y, vx = vx, vy = vy, q = {} }; table.insert(orden, grupos[k]) end
        table.insert(grupos[k].q, q)
      end
    end
  end
  local mk = WowF.misionesMarcadasDe and WowF.misionesMarcadasDe()
  if mk then
    for _, g in ipairs(mk.grupos) do
      local falta = false
      -- 6-oct: en vivo (q.hecha es del momento en que se pulso "Marcar misiones": tras entregarla seguia saliendo)
      for _, q in ipairs(g.q) do if not (WowF.misionHecha and WowF.misionHecha(q.id) or q.hecha) and not enElDiario(q.id) then falta = true end end
      local vx, vy = g.x, g.y
      if mapa then vx, vy = enVista(g.m, g.x, g.y, mapa) end
      if falta and vx then
        local k = (g.quien or "") .. "|" .. g.x .. "|" .. g.y
        if not grupos[k] then grupos[k] = { quien = g.quien, m = g.m, x = g.x, y = g.y, vx = vx, vy = vy, q = g.q }; table.insert(orden, grupos[k]) end
        grupos[k].n, grupos[k].de = g.n, #mk.grupos
      end
    end
  end
  return orden
end
WowF.misionesMazmorraEnMapa = enMapa

-- Donde la da, comparado con donde esta la mazmorra: "en Orgrimmar, la misma zona que la mazmorra" / "en Undercity: LEJOS de la mazmorra"
local function dondeLaDa(q)
  local z = zonaDe(q.m)
  local mz = q.mazmorra
  -- 13-oct: con L y tildes (antes WowF.T con el texto en bruto); sin zona = aviso, nunca "?"
  local zona = (z ~= "" and z) or L("zona: aún no hay datos de WoW Forever", "zone: no WoW Forever data yet")
  local t = L("la da ", "given by ") .. ORO .. (q.quien or "?") .. "|r" .. L(" en ", " in ") .. BLANCO .. zona .. "|r" .. GRIS .. " (" .. string.format("%.0f, %.0f", q.x or 0, q.y or 0) .. ")|r"
  if mz and mz.m and mz.m == q.m then return WowF.yaTraducido(t .. GRIS .. L(" - la misma zona que la mazmorra", " - the same zone as the dungeon") .. "|r") end
  local zm = (mz and mz.m and zonaDe(mz.m)) or (mz and mz.z) or ""
  if zm ~= "" then return WowF.yaTraducido(t .. NARANJA .. L(" - OJO: lejos de la mazmorra (que está en " .. zm .. ")", " - CAREFUL: far from the dungeon (which is in " .. zm .. ")") .. "|r") end
  return WowF.yaTraducido(t)
end
WowF.dondeLaDaMision = dondeLaDa

-- 9-oct (4.16, Andy: "las de afuera y las de adentro, ¿dicen donde entregarlas?"): a quien se entrega y donde.
-- Dato ent de wowF_Mazmorras.lua (fin de Wowhead /forever): { n, m, x, y, d = dentro, id = NPC }. Sin dato = aviso, nunca inventado.
local function entregaDe(q)
  if type(q) ~= "table" or not q.mazmorra then return nil end
  for _, r in ipairs(q.mazmorra.q or {}) do if r[5] == q.id then return type(r.ent) == "table" and r.ent or nil end end
  return nil
end
WowF.entregaMision = entregaDe
function WowF.misionEnDiario(id) return enElDiario(id) end
local function dondeSeEntrega(q)
  local e = entregaDe(q)
  if not e or not e.n or e.n == "" then
    return WowF.yaTraducido(NARANJA .. L("Entrega: aún no disponible en WoW Forever; se actualizará", "Turn in: not available in WoW Forever yet; will be updated") .. "|r")
  end
  local mismo = q.quien and q.quien ~= "" and q.quien == e.n
  local t
  if e.d then
    t = L("se entrega a " .. ORO .. e.n .. "|r" .. BLANCO .. " DENTRO de la mazmorra|r", "turn it in to " .. ORO .. e.n .. "|r" .. BLANCO .. " INSIDE the dungeon|r")
  elseif e.m and e.m > 0 then
    local z = zonaDe(e.m)
    t = L("se entrega a ", "turn it in to ") .. ORO .. e.n .. "|r" .. L(" en ", " in ") .. BLANCO .. (z ~= "" and z or "?") .. "|r" .. GRIS .. " (" .. string.format("%.0f, %.0f", e.x or 0, e.y or 0) .. ")|r"
  else
    t = L("se entrega a " .. ORO .. e.n .. "|r" .. NARANJA .. " (el sitio aún no está disponible en WoW Forever; se actualizará)|r",
      "turn it in to " .. ORO .. e.n .. "|r" .. NARANJA .. " (the place is not available in WoW Forever yet; will be updated)|r")
  end
  if mismo then t = t .. GRIS .. L(" - el mismo NPC que te la da", " - the same NPC who gives it") .. "|r" end
  return WowF.yaTraducido(VERDE .. L("Entrega: ", "Turn in: ") .. "|r" .. t)
end
WowF.dondeSeEntrega = dondeSeEntrega
-- Clic en una mision que ya llevas: ruta hasta quien la recibe y marca sobre su cabeza (se quita sola al entregarla)
local function marcaEntrega(e, q)
  if WowF.marcarNPC then pcall(WowF.marcarNPC, { n = e.n, npc = e.id, qid = q.id, entrega = true, sub = MORADO .. L("Entrega: ", "Turn in: ") .. q.n .. "|r" }) end
end
local function irAEntrega(q)
  local e = entregaDe(q)
  print(AZUL .. MORADO .. L("ENTREGAR", "TURN IN") .. "|r: " .. BLANCO .. (q and q.n or "?") .. "|r" .. GRIS .. " (" .. (q and q.mazmorra and q.mazmorra.n or "?") .. ")|r")
  print("   " .. dondeSeEntrega(q))
  if not e or not e.n or e.n == "" then return false end
  -- la marca va DESPUES de armar la ruta: viajeA quita la marca del NPC de antes (prueba rutafuera, 9-oct)
  if e.d or not e.m or e.m <= 0 then marcaEntrega(e, q) end
  if e.d or not e.m or e.m <= 0 then
    if e.d then print("   " .. GRIS .. L("Esta dentro de la mazmorra: entrega la mision antes de salir.", "It is inside the dungeon: turn the quest in before you leave.") .. "|r") end
    return true
  end
  local destino = { n = e.n, m = e.m, x = e.x, y = e.y, z = zonaDe(e.m), lugar = true }
  local ok, hecho = false, false
  if WowF.viajeA then ok, hecho = pcall(WowF.viajeA, destino, { dibujar = true }) end
  if not (ok and hecho) and WowF.marcar then WowF.marcar(destino) end
  marcaEntrega(e, q)
  return true
end
WowF.irAEntrega = irAEntrega

-- Clic en una mision (mapa, Libro, panel): explica en el chat que es y donde, y arma la ruta paso a paso hasta quien la da
local function irAMision(g, cadena)
  if not g then return end
  local q1 = g.q and g.q[1]
  if not q1 then return end
  -- 6-oct: el NPC puede dar varias; se busca la primera que aun te falta (para el nombre de la ruta y el aviso al aceptar)
  for _, q in ipairs(g.q) do if not q.hecha and not enElDiario(q.id) then q1 = q; break end end
  -- 9-oct (4.16): si ya llevas todas las de este NPC, el clic lleva a quien las recibe (entrega)
  local llevada, falta = nil, false
  for _, q in ipairs(g.q) do
    if not q.hecha then if enElDiario(q.id) then llevada = llevada or q else falta = true end end
  end
  if llevada and not falta then return irAEntrega(llevada) end
  -- 6-oct (Andy: "fui y no me la dio", nivel 8 y pide 9): nunca se manda a un NPC que aun no te da la mision
  local nivel = nivelActual()
  local yaTeDa, minNivel = nil, nil
  for _, q in ipairs(g.q) do
    if not q.hecha and not enElDiario(q.id) then
      if nivel >= (q.nivel or 0) then yaTeDa = yaTeDa or q elseif not minNivel or q.nivel < minNivel then minNivel = q.nivel end
    end
  end
  if yaTeDa then q1 = yaTeDa
  elseif minNivel then
    local nombres = {}
    for _, q in ipairs(g.q) do if not q.hecha and not enElDiario(q.id) then table.insert(nombres, q.n .. " (" .. L("nivel ", "level ") .. q.nivel .. ")") end end
    print(AZUL .. NARANJA .. L("AUN NO: ", "NOT YET: ") .. "|r" .. ORO .. (g.quien or "?") .. "|r" .. BLANCO .. L(" todavia no te da " .. table.concat(nombres, ", ") .. ". Eres nivel " .. nivel .. "; se desbloquea al nivel " .. minNivel .. ".",
      " will not give you " .. table.concat(nombres, ", ") .. " yet. You are level " .. nivel .. "; it unlocks at level " .. minNivel .. ".") .. "|r")
    print("   " .. GRIS .. L("No te llevo hasta alli: no te daria nada. Al llegar al nivel " .. minNivel .. " te aviso en el chat y ya te puedo llevar.",
      "I will not take you there: it would give you nothing. When you reach level " .. minNivel .. " I will tell you in the chat and then I can take you.") .. "|r")
    local t = L((g.quien or "?") .. ": AUN NO, desde nivel " .. minNivel .. " (eres " .. nivel .. ")", (g.quien or "?") .. ": NOT YET, from level " .. minNivel .. " (you are " .. nivel .. ")")
    local ok = RaidNotice_AddMessage and RaidWarningFrame and pcall(RaidNotice_AddMessage, RaidWarningFrame, t, { r = 1, g = 0.6, b = 0.2 })
    if not ok and UIErrorsFrame and UIErrorsFrame.AddMessage then pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, t, 1, 0.6, 0.2) end
    return false
  end
  if WowF.irALinea then
    for _, q in ipairs(g.q) do
      local st = WowF.estadoLinea and WowF.estadoLinea(q)
      if st and st.i and WowF.irALinea(q, g) then return end
    end
  end
  print(WowF.T(AZUL .. MORADO .. "MISION DE MAZMORRA|r: " .. BLANCO .. q1.n .. "|r" .. GRIS .. " (" .. q1.mazmorra.n .. ", desde nivel " .. q1.nivel .. ")|r" .. ((q1.xp or 0) > 0 and (VERDE .. "  " .. WowF.textoXP(WowF.xpMision(q1)) .. "|r") or "")))
  if WowF.marcarNPC then pcall(WowF.marcarNPC, { n = g.quien or q1.quien, npc = q1.npc, qid = q1.id, nivel = q1.nivel, sub = MORADO .. WowF.T("Mision: ") .. q1.mazmorra.n .. "|r" }) end
  if q1.dentro or not g.m or g.m <= 0 then
    print(WowF.T("   " .. GRIS .. "Se recoge DENTRO de la mazmorra: no hace falta ir a ningun sitio antes. Entra y busca el ! amarillo.|r"))
    print("   " .. dondeSeEntrega(q1))
    return
  end
  print("   " .. dondeLaDa(q1))
  print("   " .. dondeSeEntrega(q1))
  print(WowF.T("   " .. BLANCO .. "Que hacer: 1) ve hasta el (alfiler del mapa)  2) hablale y acepta la mision  3) entra en " .. q1.mazmorra.n .. " y terminala dentro.|r"))
  -- x2: el nombre de la ruta lleva todas las que da ese NPC, para que no se vaya con una sola
  local nombres, despues = {}, {}
  for _, q in ipairs(g.q) do
    if not q.hecha and not enElDiario(q.id) then
      if nivelActual() >= (q.nivel or 0) then table.insert(nombres, q.n) else table.insert(despues, q.n .. " (" .. L("nivel ", "level ") .. q.nivel .. ")") end
    end
  end
  if #nombres == 0 then nombres = { q1.n } end
  if #despues > 0 then print("   " .. NARANJA .. L("Este NPC tambien te dara " .. table.concat(despues, ", ") .. ": AUN NO, vuelve a por ella al subir.", "This NPC will also give you " .. table.concat(despues, ", ") .. ": NOT YET, come back for it when you level up.") .. "|r") end
  local destino = { n = g.quien or "?", m = g.m, x = g.x, y = g.y, z = zonaDe(g.m), lugar = true,
    mision = { quien = g.quien or "?", nombre = table.concat(nombres, " + "), mazmorra = q1.mazmorra.n, xp = q1.xpBase or q1.xp, id = q1.id, cadena = cadena, npc = q1.npc } }
  local ok, hecho = false, false
  if WowF.viajeA then ok, hecho = pcall(WowF.viajeA, destino, { dibujar = true }) end
  if not (ok and hecho) and WowF.marcar then WowF.marcar(destino) end
  pcall(WowF.dibujarMisionesMazmorra)
end
WowF.irAMision = irAMision
WowF.marcarMisionMazmorra = irAMision

-- ----- Marcar TODAS las misiones de fuera de una mazmorra (boton del panel y del Libro) -----
-- 4-oct (Andy): un solo boton que pone en el mapa todas las de fuera, numeradas de la mas cercana a la mas lejana
-- desde donde estas al pulsarlo. Sin ruta: solo el sitio. Raton sobre el numero = que mision es; clic = ruta hasta el NPC.
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local marcadas -- { m = mazmorra, grupos = { { quien, m, x, y, q = {...}, yardas, n } } }
local function mundo(m, x, y)
  if not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return nil end
  local ok, cont, v = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x / 100, y / 100))
  if not ok or not v or not v.GetXY then return nil end
  local wx, wy = v:GetXY()
  if not wx then return nil end
  return wx, wy, cont
end
local function miSitio()
  if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return nil end
  local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
  m = ok and seguro(m)
  if not m then return nil end
  local ok2, pos = pcall(C_Map.GetPlayerMapPosition, m, "player")
  if not ok2 or not pos then return nil end
  local x, y = pos.x, pos.y
  if (not x or not y) and pos.GetXY then x, y = pos:GetXY() end
  x, y = seguro(x), seguro(y)
  if not x or not y or (x == 0 and y == 0) then return nil end
  return mundo(m, x * 100, y * 100)
end
-- Las de fuera de la mazmorra m que te faltan (sin hacer y sin aceptar), una entrada por NPC
function deFuera(m) -- la local se declara arriba, junto a TOPE_BETA (7-oct)
  local grupos, por = {}, {}
  if not m or not WowF.misionesDe then return grupos end
  for _, q in ipairs((WowF.misionesDe(m))) do
    if not q.hecha and not q.dentro and q.m and q.m > 0 and q.x and q.x > 0 and not enElDiario(q.id) then
      local k = (q.quien or "") .. "|" .. q.x .. "|" .. q.y
      if not por[k] then por[k] = { quien = q.quien, m = q.m, x = q.x, y = q.y, q = {} }; table.insert(grupos, por[k]) end
      table.insert(por[k].q, q)
    end
  end
  return grupos
end
WowF.misionesFueraDe = deFuera
-- 6-oct (Andy: "que te cree la ruta, de la mas cerca a la mas lejos"): RECORRIDO encadenado. La 1 es la mas cercana a ti,
-- la 2 la mas cercana a la 1, y asi (vecino mas cercano); g.yardas = desde el punto anterior (desde ti para la 1).
-- Primero las que ya te dan por nivel; las de nivel mas alto van al final (g.listo = false). Otro continente: al final de su tanda.
local function ordenar(grupos)
  local nivel = nivelActual()
  local px, py, pc = miSitio()
  local listos, tarde = {}, {}
  for _, g in ipairs(grupos) do
    g.wx, g.wy, g.wc = mundo(g.m, g.x, g.y)
    g.listo = false
    for _, q in ipairs(g.q) do if nivel >= (q.nivel or 0) then g.listo = true end end
    table.insert(g.listo and listos or tarde, g)
  end
  local orden = {}
  local function encadenar(lista)
    table.sort(lista, function(a, b) return (a.quien or "") < (b.quien or "") end) -- empates siempre en el mismo orden
    while #lista > 0 do
      local mejor, dMejor = 1, nil
      for i, g in ipairs(lista) do
        if px and g.wx and pc == g.wc then
          local d = math.sqrt((px - g.wx) ^ 2 + (py - g.wy) ^ 2)
          if not dMejor or d < dMejor then mejor, dMejor = i, d end
        end
      end
      local g = table.remove(lista, mejor)
      g.yardas = dMejor
      table.insert(orden, g)
      if g.wx then px, py, pc = g.wx, g.wy, g.wc end
    end
  end
  encadenar(listos)
  encadenar(tarde)
  for i, g in ipairs(orden) do g.n = i end
  return orden
end
-- Lo que aun te falta de un NPC marcado (sin hacer y sin aceptar); con el nivel, solo lo que ya te da
local function faltaDe(g, conNivel)
  local nivel = nivelActual()
  for _, q in ipairs(g.q) do
    local hecha = (WowF.misionHecha and WowF.misionHecha(q.id)) or q.hecha
    if not hecha and not enElDiario(q.id) and not (marcadas and marcadas.aceptadas and marcadas.aceptadas[q.id])
      and (not conNivel or nivel >= (q.nivel or 0)) then return true end
  end
  return false
end
local function quitarMarcadas()
  marcadas = nil
  WowFExportarDB.misionesMarcadas = nil
end
WowF.quitarMisionesMarcadas = quitarMarcadas
WowF.misionesMarcadas = function() return marcadas end
-- Las marcadas de esta mazmorra (o de cualquiera si m es nil); tras /reload se rehacen desde la que quedo guardada
local function lasMarcadas(m)
  if not marcadas and WowFExportarDB.misionesMarcadas and WowFMazmorras then
    for _, x in ipairs(WowFMazmorras) do
      if (x.i or x.n) == WowFExportarDB.misionesMarcadas then marcadas = { m = x, grupos = ordenar(deFuera(x)) } end
    end
    if not marcadas then WowFExportarDB.misionesMarcadas = nil end
  end
  if marcadas and (not m or marcadas.m == m) then return marcadas end
  return nil
end
WowF.misionesMarcadasDe = lasMarcadas

-- La ruta va al primer NPC del recorrido que aun te da algo; al aceptar todas las suyas pasa sola al siguiente,
-- y cuando ya llevas todas te lleva a la entrada de la mazmorra.
local function rutaDeLaCadena() local v = WowF.viajeMision and WowF.viajeMision(); return v and v.mision and v.mision.cadena and v or nil end
local function siguienteDeLaRuta(avisar)
  local mk = lasMarcadas()
  if not mk then return false end
  local de, pos, tarde, minTarde = 0, {}, 0, nil
  for _, h in ipairs(mk.grupos) do
    if h.listo then de = de + 1; pos[h] = de
    else
      tarde = tarde + 1
      for _, q in ipairs(h.q) do if not minTarde or (q.nivel or 0) < minTarde then minTarde = q.nivel end end
    end
  end
  for k, g in ipairs(mk.grupos) do
    if g.listo and faltaDe(g, true) then
      if mk.va == g.n and rutaDeLaCadena() then return false end -- ya vas hacia el
      mk.va = g.n
      local sig
      for j = k + 1, #mk.grupos do local h = mk.grupos[j]; if h.listo and faltaDe(h, true) then sig = h; break end end
      local cadena = { i = pos[g] or g.n, de = de, tarde = tarde, minTarde = minTarde, sig = sig and ((sig.quien or "?") .. " (" .. zonaDe(sig.m) .. ")") or nil, maz = mk.m.n }
      if avisar then
        print(AZUL .. VERDE .. L("SIGUIENTE (" .. (pos[g] or g.n) .. " de " .. de .. "): ", "NEXT (" .. (pos[g] or g.n) .. " of " .. de .. "): ") .. "|r" .. ORO .. (g.quien or "?") .. "|r" .. GRIS .. L(" en ", " in ") .. zonaDe(g.m) .. "|r")
      end
      irAMision(g, cadena)
      return true
    end
  end
  -- Ya no queda ninguna que te den ahora: a la mazmorra
  local m = mk.m
  mk.va = nil
  local quedanTarde = 0
  for _, g in ipairs(mk.grupos) do if faltaDe(g, false) then quedanTarde = quedanTarde + 1 end end
  quitarMarcadas()
  print(AZUL .. VERDE .. L("ya tienes todas las misiones de fuera de " .. m.n .. " que te dan ahora.", "you have all the " .. m.n .. " quests from outside that you can get now.") .. "|r")
  if quedanTarde > 0 then
    print("   " .. GRIS .. L(quedanTarde .. " NPC mas te daran misiones cuando subas de nivel (vuelve a pulsar Misiones de fuera entonces).",
      quedanTarde .. " more NPCs will give you quests when you level up (press Outside quests again then).") .. "|r")
    local r = WowF.resumenNivelesFuera(m)
    if r then print("   " .. r) end
  end
  print("   " .. BLANCO .. L("Ahora ve a la entrada de " .. m.n .. ":", "Now go to the entrance of " .. m.n .. ":") .. "|r")
  local ok, hecho = false, false
  if WowF.viajeA then ok, hecho = pcall(WowF.viajeA, m, { dibujar = true }) end
  if not (ok and hecho) and WowF.marcar then pcall(WowF.marcar, m) end
  pcall(WowF.dibujarMisionesMazmorra)
  if WowF.panelActualizar then pcall(WowF.panelActualizar) end
  return false
end
WowF._siguienteMisionFuera = siguienteDeLaRuta -- para las pruebas
-- Aviso de que aceptaste una (QUEST_ACCEPTED): se anota y, si ese NPC ya no te da nada mas, la ruta pasa al siguiente
local function aceptada(id)
  local mk = lasMarcadas()
  if not mk then return end
  id = tonumber(id)
  local deLaRuta = false
  for _, g in ipairs(mk.grupos) do for _, q in ipairs(g.q) do if q.id == id then deLaRuta = true end end end
  if not deLaRuta then return end -- otra mision cualquiera: la ruta sigue igual
  mk.aceptadas = mk.aceptadas or {}; mk.aceptadas[id] = true
  local actual
  for _, g in ipairs(mk.grupos) do if g.n == mk.va then actual = g end end
  if actual and faltaDe(actual, true) then
    local suya = false
    for _, q in ipairs(actual.q) do if q.id == id then suya = true end end
    if not suya then pcall(WowF.dibujarMisionesMazmorra); return end -- cogiste una de otro NPC de la lista: se tacha y la ruta sigue
    print(AZUL .. L("bien. " .. (actual.quien or "?") .. " aun te da otra: aceptala tambien antes de seguir.", "good. " .. (actual.quien or "?") .. " still has another one: accept it too before moving on."))
    return
  end
  siguienteDeLaRuta(true)
end
WowF._misionFueraAceptada = aceptada -- para las pruebas

local function marcarTodas(m)
  if not m then return 0 end
  if lasMarcadas(m) then
    if rutaDeLaCadena() and WowF.pararViaje then pcall(WowF.pararViaje, true) end
    quitarMarcadas()
    print(AZUL .. L("marcas de las misiones de " .. m.n .. " quitadas.", m.n .. " quest marks removed."))
    pcall(WowF.dibujarMisionesMazmorra)
    if WowF.panelActualizar then pcall(WowF.panelActualizar) end
    return 0
  end
  local grupos = ordenar(deFuera(m))
  if #grupos == 0 then
    print(AZUL .. L("a " .. m.n .. " no le quedan misiones que se cojan fuera (las que faltan se recogen dentro, o ya las llevas).",
      m.n .. " has no quests left to pick up outside (the rest start inside, or you already have them)."))
    return 0
  end
  marcadas = { m = m, grupos = grupos }
  WowFExportarDB.misionesMarcadas = m.i or m.n
  local total = 0
  for _, g in ipairs(grupos) do total = total + #g.q end
  -- 5-oct: un numero por NPC; si alguno da varias, decir cuantos numeros hay para que no parezca que falta una
  local sitios = (#grupos < total) and L(", en " .. #grupos .. " sitios (un numero por NPC; alguno da varias)", ", at " .. #grupos .. " places (one number per NPC; some give several)") or ""
  print(AZUL .. L(MORADO .. total .. " misiones de " .. m.n .. "|r marcadas en el mapa (M)" .. sitios .. ". RUTA en este orden (de la mas cercana a la mas lejana, cada una desde la anterior):",
    MORADO .. total .. " " .. m.n .. " quests|r marked on the map (M)" .. sitios .. ". ROUTE in this order (nearest to farthest, each one from the previous):"))
  local resumen = WowF.resumenNivelesFuera(m)
  if resumen then print("   " .. resumen) end
  for _, g in ipairs(grupos) do
    local nombres = {}
    for _, q in ipairs(g.q) do table.insert(nombres, (nivelActual() < (q.nivel or 0)) and (q.n .. NARANJA .. L(" (nivel ", " (level ") .. q.nivel .. ")|r" .. BLANCO) or q.n) end
    local z = zonaDe(g.m)
    local desde = g.n == 1 and L(" de ti", " from you") or L(" de la " .. (g.n - 1), " from no. " .. (g.n - 1))
    local lejos = g.yardas and (GRIS .. L(" (a " .. math.floor(g.yardas + 0.5) .. " yardas" .. desde .. ")", " (" .. math.floor(g.yardas + 0.5) .. " yards" .. desde .. ")") .. "|r")
      or (GRIS .. L(" (en otro continente: barco o zepelin)", " (on another continent: boat or zeppelin)") .. "|r")
    local extra = ""
    if #g.q > 1 then extra = extra .. VERDE .. L("  x" .. #g.q .. ": te da " .. #g.q .. " misiones, cogelas todas", "  x" .. #g.q .. ": gives you " .. #g.q .. " quests, take them all") .. "|r" end
    if not g.listo then
      local min
      for _, q in ipairs(g.q) do if not min or q.nivel < min then min = q.nivel end end
      extra = extra .. NARANJA .. L("  (aun no: desde nivel " .. min .. ")", "  (not yet: from level " .. min .. ")") .. "|r"
    end
    print("   " .. ORO .. g.n .. ")|r " .. BLANCO .. table.concat(nombres, ", ") .. "|r" .. GRIS .. " - " .. (g.quien or "?") .. L(" en ", " in ") .. (z ~= "" and z or "?") .. "|r" .. lejos .. extra)
    -- Linea de misiones: hay que hacer otras antes para que este NPC te la de
    for _, q in ipairs(g.q) do
      local corta = WowF.lineaMisionCorta and WowF.lineaMisionCorta(q) or ""
      if corta ~= "" then print("      " .. corta) end
    end
  end
  print("   " .. GRIS .. L("En el mapa: los numeros van unidos por una raya morada en el orden de la ruta; raton encima = que mision es; clic = ir a ese NPC. Pulsa otra vez el boton (o Limpiar el mapa) para quitarlas.",
    "On the map: the numbers are joined by a purple line in route order; hover = which quest it is; click = go to that NPC. Press the button again (or Clear the map) to remove them.") .. "|r")
  local hay = false
  for _, g in ipairs(grupos) do if g.listo then hay = true; break end end
  if hay then
    local g1
    for _, g in ipairs(grupos) do if g.listo and faltaDe(g, true) then g1 = g; break end end
    if g1 then
      print(AZUL .. VERDE .. L("LO PRIMERO: ve a " .. g1.n .. ") ", "FIRST: go to " .. g1.n .. ") ") .. "|r" .. ORO .. (g1.quien or "?") .. "|r" .. GRIS .. L(" en ", " in ") .. zonaDe(g1.m) .. "|r"
        .. BLANCO .. L(". Te llevo paso a paso; al aceptar sus misiones la ruta pasa sola a la siguiente.", ". I will guide you step by step; when you accept its quests the route moves on to the next one by itself.") .. "|r")
    end
    siguienteDeLaRuta(false)
  else
    local min
    for _, g in ipairs(grupos) do for _, q in ipairs(g.q) do if not min or q.nivel < min then min = q.nivel end end end
    -- 6-oct: antes ponia el alfiler en el 1 aunque no te diera nada; ahora no se manda a nadie hasta tener el nivel
    print(AZUL .. NARANJA .. L("AUN NO te da ninguna: eres nivel " .. nivelActual() .. " y la primera se desbloquea al nivel " .. (min or "?") .. ". No vayas todavia: al subir te aviso y te llevo.",
      "NONE is available yet: you are level " .. nivelActual() .. " and the first one unlocks at level " .. (min or "?") .. ". Do not go yet: when you level up I will tell you and take you.") .. "|r")
  end
  pcall(WowF.dibujarMisionesMazmorra)
  if WowF.panelActualizar then pcall(WowF.panelActualizar) end
  return total
end
WowF.marcarTodasMisiones = marcarTodas

local function tooltipPin(self)
  if not GameTooltip then return end
  local d = self.datos
  local nivel = nivelActual()
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(WowF.T("MISION DE MAZMORRA"), COLOR[1], COLOR[2], COLOR[3])
  if d.n then GameTooltip:AddLine(L("N.o " .. d.n .. " de " .. d.de .. (d.n == 1 and " (la mas cercana)" or ""), "No. " .. d.n .. " of " .. d.de .. (d.n == 1 and " (the nearest)" or "")), 1, 0.82, 0) end
  if #d.q > 1 then
    GameTooltip:AddLine(L("Este NPC te da " .. #d.q .. " misiones (x" .. #d.q .. "): cogelas todas a la vez",
      "This NPC gives you " .. #d.q .. " quests (x" .. #d.q .. "): pick them all up at once"), 0.2, 1, 0.4, true)
  end
  for _, q in ipairs(d.q) do
    GameTooltip:AddLine(WowF.T(BLANCO .. q.n .. "|r" .. ((q.xp or 0) > 0 and (VERDE .. "  " .. WowF.textoXP(WowF.xpMision(q)) .. "|r") or "")), 1, 1, 1)
    GameTooltip:AddLine(WowF.T(GRIS .. "   para " .. "|r" .. ORO .. q.mazmorra.n .. "|r" .. GRIS .. " (niveles " .. q.mazmorra.d .. "-" .. q.mazmorra.h .. ")|r"
      .. (nivel < q.nivel and (NARANJA .. "  - desde nivel " .. q.nivel .. "|r") or "")), 1, 1, 1)
    if WowF.lineaMisionTooltip then for _, l in ipairs(WowF.lineaMisionTooltip(q)) do GameTooltip:AddLine("   " .. l[1], l[2], l[3], l[4], true) end end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(dondeLaDa(d.q[1]), 1, 1, 1, true)
  for _, q in ipairs(d.q) do GameTooltip:AddLine(dondeSeEntrega(q), 1, 1, 1, true) end
  GameTooltip:AddLine(WowF.T("Que hacer: hablale, acepta la mision ANTES de entrar y terminala dentro de la mazmorra."), 1, 1, 1, true)
  local min, alguna = nil, false
  for _, q in ipairs(d.q) do if nivel >= (q.nivel or 0) then alguna = true elseif not min or q.nivel < min then min = q.nivel end end
  if not alguna and min then
    GameTooltip:AddLine(L("AUN NO te da nada: eres nivel " .. nivel .. ", se desbloquea al nivel " .. min .. ". No vayas todavia.", "NOTHING for you yet: you are level " .. nivel .. ", it unlocks at level " .. min .. ". Do not go yet."), 1, 0.6, 0.2, true)
  elseif self.actual then GameTooltip:AddLine(WowF.T("Es la mision a la que vas ahora (sigue el alfiler del mapa)."), 0.2, 1, 0.4, true)
  else GameTooltip:AddLine(WowF.T("Clic: ruta paso a paso hasta el"), 0.2, 1, 0.4) end
  GameTooltip:Show()
end

local capaLineas, rayas, sombras = nil, {}, {}
local function dibujar()
  for _, p in pairs(pines) do p:Hide() end
  for _, l in pairs(rayas) do l:Hide() end
  for _, l in pairs(sombras) do l:Hide() end
  if apagado() then return end
  local puestos, centros = {}, {}
  local c = lienzo()
  if not c or not WorldMapFrame:IsShown() then return end
  local visto = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  local lista = enMapa(visto)
  if #lista == 0 then return end
  local ancho, alto = c:GetWidth(), c:GetHeight()
  if not ancho or ancho == 0 then return end
  -- Tamano fijo en pantalla (el lienzo se escala con el zoom), como los iconos de entrenadores
  local escala = 1
  pcall(function() escala = c:GetEffectiveScale() / UIParent:GetEffectiveScale() end)
  if not escala or escala <= 0 then escala = 1 end
  local px = 1 / escala
  local nivel = nivelActual()
  local va = WowF.viajeMision and WowF.viajeMision()
  -- En el mapa de la zona del NPC sale la etiqueta; en el del continente solo el icono (si no, se tapan)
  for i, g in ipairs(lista) do
    local pin = pines[i]
    if not pin then
      pin = CreateFrame("Button", nil, c)
      pin:SetFrameStrata("HIGH")
      pin.aro = pin:CreateTexture(nil, "BACKGROUND")
      pin.negro = pin:CreateTexture(nil, "BORDER")
      pin.icono = pin:CreateTexture(nil, "ARTWORK")
      pin.icono:SetAllPoints()
      pin.icono:SetTexture(ICONO)
      pcall(function()
        for _, tx in ipairs({ pin.aro, pin.negro }) do
          local m = pin:CreateMaskTexture()
          m:SetAllPoints(tx)
          m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
          tx:AddMaskTexture(m)
        end
      end)
      pin.numero = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      pin.numero:SetPoint("CENTER", 0, 0)
      pin.numero:SetTextColor(1, 1, 1)
      -- 5-oct (Andy: "son 5 misiones pero salen 4"): un NPC que da varias lleva "x2" junto al numero
      pin.cuantas = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      pin.cuantas:SetPoint("LEFT", pin, "RIGHT", 1, 0)
      pin.cuantas:SetTextColor(1, 1, 1)
      pin.etiqueta = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      pin.etiqueta:SetPoint("TOP", pin, "BOTTOM", 0, -2)
      pin:SetScript("OnEnter", tooltipPin)
      pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
      pin:SetScript("OnClick", function(self) irAMision(self.datos) end)
      pines[i] = pin
    end
    pin.datos = g
    pin.actual = va and va.m == g.m and va.x == g.x and va.y == g.y or false
    local tam = ((pin.actual or g.n) and 13 or 11) * px -- 4-oct: 14/16 px con el aro (Andy: "se ven muy grandes")
    pin:SetSize(tam, tam)
    pin.negro:ClearAllPoints(); pin.negro:SetPoint("TOPLEFT", -0.75 * px, 0.75 * px); pin.negro:SetPoint("BOTTOMRIGHT", 0.75 * px, -0.75 * px)
    pin.aro:ClearAllPoints(); pin.aro:SetPoint("TOPLEFT", -1.5 * px, 1.5 * px); pin.aro:SetPoint("BOTTOMRIGHT", 1.5 * px, -1.5 * px)
    pin.negro:SetColorTexture(0, 0, 0, 0.9)
    -- Morado = ya puedes cogerla; gris = aun no tienes el nivel; verde = vas hacia ella
    local listo = false
    for _, q in ipairs(g.q) do if nivel >= q.nivel then listo = true end end
    -- Marcadas con el boton: circulo dorado con su numero (1 = la mas cercana) en lugar del "!"
    if g.n then
      pin.icono:Hide()
      pcall(pin.numero.SetFont, pin.numero, (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"), 9 * px, "OUTLINE")
      pin.numero:SetText(g.n)
      pin.numero:Show()
    else
      pin.icono:Show()
      pin.numero:Hide()
    end
    if #g.q > 1 then
      pcall(pin.cuantas.SetFont, pin.cuantas, (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"), 10 * px, "OUTLINE")
      pin.cuantas:SetText("x" .. #g.q)
      pin.cuantas:Show()
    else
      pin.cuantas:Hide()
    end
    if pin.actual then pin.aro:SetColorTexture(0.2, 1, 0.4, 1)
    elseif g.n and listo then pin.aro:SetColorTexture(1, 0.82, 0, 1)
    elseif listo then pin.aro:SetColorTexture(COLOR[1], COLOR[2], COLOR[3], 1) else pin.aro:SetColorTexture(0.5, 0.5, 0.5, 1) end
    local nombres, vistos = {}, {}
    for _, q in ipairs(g.q) do if not vistos[q.mazmorra.n] then vistos[q.mazmorra.n] = true; table.insert(nombres, q.mazmorra.n) end end
    -- 4-oct: sin etiqueta fija (tapaba el mapa); el nombre sale al pasar el raton (tooltipPin)
    pin.etiqueta:SetText(WowF.T((pin.actual and (VERDE .. "VAS AQUI: ") or MORADO) .. "Mision: " .. table.concat(nombres, ", ") .. "|r"))
    pin.etiqueta:Hide()
    -- 6-oct (Andy: en el mapa del continente el 1, el 2 y el 3 salian uno encima de otro): si tapa a otro, se corre a un lado
    local cx, cy = ancho * g.vx / 100, alto * g.vy / 100
    -- (en una ciudad con 15-20 NPC no bastaba correrlo a la derecha: se busca hueco en anillos alrededor del sitio)
    local sepX, sepY = 13 * px * 1.7, 13 * px * 1.3
    local function libre(x, y)
      for _, o in ipairs(puestos) do if math.abs(o[1] - x) < sepX and math.abs(o[2] - y) < sepY then return false end end
      return true
    end
    if not libre(cx, cy) then
      local hueco
      for anillo = 1, 15 do
        for a = 0, 7 do
          local nx, ny = cx + math.cos(a * math.pi / 4) * sepX * anillo, cy + math.sin(a * math.pi / 4) * sepY * anillo
          if libre(nx, ny) then hueco = { nx, ny }; break end
        end
        if hueco then break end
      end
      if hueco then cx, cy = hueco[1], hueco[2] end
    end
    table.insert(puestos, { cx, cy })
    if g.n then centros[g.n] = { cx, cy } end
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", c, "TOPLEFT", cx, -cy)
    pin:Show()
  end
  -- 6-oct: la RUTA entre los numeros (1 -> 2 -> 3...), en una capa propia encima del mapa (en el lienzo quedaba tapada)
  if not capaLineas then
    capaLineas = CreateFrame("Frame", nil, c)
    capaLineas:SetAllPoints(c)
    capaLineas:SetFrameStrata("HIGH")
  end
  pcall(function() capaLineas:SetFrameLevel(c:GetFrameLevel() + 1) end)
  capaLineas:Show()
  if not capaLineas.CreateLine then return end
  -- Une los numeros que quedan, en su orden (los que ya cogiste desaparecen y la raya salta al siguiente)
  local ns = {}
  for n in pairs(centros) do table.insert(ns, n) end
  table.sort(ns)
  local k = 0
  for i = 1, #ns - 1 do
    local a, b = centros[ns[i]], centros[ns[i + 1]]
    if a and b then
      k = k + 1
      local l, sombra = rayas[k], sombras[k]
      if not l then
        local ok1, s1 = pcall(capaLineas.CreateLine, capaLineas, nil, "ARTWORK")
        local ok2, l2 = pcall(capaLineas.CreateLine, capaLineas, nil, "OVERLAY")
        if ok1 and s1 then sombra = s1; sombras[k] = s1 end
        if ok2 and l2 then l = l2; rayas[k] = l2 end
      end
      for _, par in ipairs({ { sombra, 4.5, 0, 0, 0, 0.75 }, { l, 2, COLOR[1], COLOR[2], COLOR[3], 1 } }) do
        local ln = par[1]
        if ln then
          ln:SetThickness(par[2] * px)
          ln:SetColorTexture(par[3], par[4], par[5], par[6])
          ln:SetStartPoint("TOPLEFT", c, a[1], -a[2])
          ln:SetEndPoint("TOPLEFT", c, b[1], -b[2])
          ln:Show()
        end
      end
    end
  end
end
WowF.dibujarMisionesMazmorra = dibujar
WowF.marcadoresMisiones = function() return pines end -- para las pruebas
WowF.pinesMisionesMazmorra = function() local n = 0; for _, p in ipairs(pines) do if p:IsShown() then n = n + 1 end end; return n end -- para las pruebas
WowF._tooltipMisionPin = function(i) local p = pines[i or 1]; if p and p:IsShown() then tooltipPin(p); return true end end -- para las pruebas
-- 4-oct (Andy: "se ven grandes y se hacen pequenos solo al darles clic"): el tamano en pantalla sale de la escala del lienzo,
-- que cambia con el zoom y justo despues de abrir el mapa; antes solo se recalculaba al cambiar de mapa o al hacer clic.
-- Ahora se rehace en cuanto cambia la escala, asi salen pequenos desde el principio.
local escalaVista
local function revisarEscala()
  local c = lienzo()
  local ok, e = pcall(function() return c:GetEffectiveScale() end)
  if ok and type(e) == "number" and e > 0 and (not escalaVista or math.abs(e - escalaVista) > escalaVista * 0.01) then
    escalaVista = e
    pcall(dibujar)
  end
end
WowF._revisarEscala = WowF._revisarEscala or {}
table.insert(WowF._revisarEscala, revisarEscala) -- para las pruebas
if WorldMapFrame then
  if WorldMapFrame.OnMapChanged then pcall(hooksecurefunc, WorldMapFrame, "OnMapChanged", function() pcall(dibujar) end) end
  WorldMapFrame:HookScript("OnShow", function() pcall(dibujar) end)
  local vigia = CreateFrame("Frame", nil, WorldMapFrame) -- hijo del mapa: OnUpdate solo corre con el mapa abierto
  vigia:SetScript("OnUpdate", revisarEscala)
end

-- ----- 4) Sobre la cabeza (placas de nombre de NPC amistosos) -----
-- 11-oct (FLG-ERR SetPreferredGamepadInteractTarget, jugador con mando): con el mando activo el juego elige el objetivo
-- con las placas de nombre; no se cambian sus CVars ni se cuelga nada de ellas (marcos propios, solo anclados)
local function conMando() return WowF.interfazMando() end -- 22-oct: mando conectado de verdad (wowF_Estilo.lua)
local marcas = {}
local function marcaEn(placa)
  if marcas[placa] then return marcas[placa] end
  if placa.IsForbidden and placa:IsForbidden() == true then return nil end
  local m = CreateFrame("Frame", nil, UIParent)
  m:SetSize(16, 16) -- 4-oct: era 22
  m:SetPoint("BOTTOM", placa, "TOP", 0, 4)
  m:SetFrameStrata("HIGH")
  m.icono = m:CreateTexture(nil, "ARTWORK")
  m.icono:SetAllPoints()
  m.icono:SetTexture(ICONO)
  m.texto = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if WowF.estilo and WowF.estilo.letra then WowF.estilo.letra(m.texto, "boton", 10, "OUTLINE") end -- 11-oct (hibrido): Signika con borde
  m.texto:SetPoint("BOTTOM", m, "TOP", 0, 1)
  marcas[placa] = m
  return m
end
local function revisarPlaca(unidad)
  if WowF.mandoActivo and WowF.mandoActivo() then for _, mm in pairs(marcas) do mm:Hide() end; return end -- 14-oct: con mando, nada sobre las placas
  local placa = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unidad)
  if not placa then return end
  if WowF.marcaNPCDe and WowF.marcaNPCDe(unidad) then if marcas[placa] then marcas[placa]:Hide() end; return end -- 6-oct: ya lleva la marca grande
  local lista = deLaUnidad(unidad)
  local q = nil
  local nivel = nivelActual()
  for _, x in ipairs(lista or {}) do if not x.yaLaTienes and nivel >= (x.nivel or 0) then q = x; break end end
  if not q then for _, x in ipairs(lista or {}) do if not x.yaLaTienes then q = x; break end end end
  if not q then if marcas[placa] then marcas[placa]:Hide() end; return end
  local m = marcaEn(placa)
  if not m then return end
  -- 6-oct (Andy: Rahauro a nivel 8): si aun no te la da, lo dice
  if nivel < (q.nivel or 0) then m.texto:SetText(WowF.yaTraducido(MORADO .. L("Mazmorra: ", "Dungeon: ") .. q.mazmorra.n .. "|r\n" .. NARANJA .. L("AUN NO: nivel " .. q.nivel, "NOT YET: level " .. q.nivel) .. "|r"))
  else m.texto:SetText(WowF.T(MORADO .. "Mazmorra: " .. q.mazmorra.n .. "|r\n" .. (q.dentro and (GRIS .. "se recoge dentro|r") or (NARANJA .. "antes de entrar|r")))) end
  m:Show()
end
local function revisarPlacas()
  if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
  for _, placa in ipairs(C_NamePlate.GetNamePlates() or {}) do
    if placa.namePlateUnitToken then pcall(revisarPlaca, placa.namePlateUnitToken) end
  end
end
-- 6-oct: al subir de nivel, las misiones de mazmorra de fuera que se te abren (de tu faccion, sin hacer, de mazmorras de tu nivel)
function WowF.misionesDesbloqueadas(nuevo)
  nuevo = nuevo or nivelActual()
  local lista = {}
  for _, q in ipairs((pendientes())) do
    if not q.dentro and not q.yaLaTienes and q.nivel == nuevo then table.insert(lista, q) end
  end
  if #lista > 0 then
    print(AZUL .. VERDE .. L("NIVEL " .. nuevo .. ": se te abren " .. #lista .. " misiones de mazmorra que se cogen fuera:", "LEVEL " .. nuevo .. ": " .. #lista .. " dungeon quests picked up outside are now open:") .. "|r")
    for _, q in ipairs(lista) do print("   " .. BLANCO .. q.n .. "|r" .. GRIS .. " - " .. (q.quien or "?") .. L(" en ", " in ") .. zonaDe(q.m) .. L(", para ", ", for ") .. q.mazmorra.n .. "|r") end
    print("   " .. GRIS .. L("Clic en el numero del mapa o boton Misiones de fuera: te llevo.", "Click the number on the map or the Outside quests button: I will take you.") .. "|r")
  end
  -- la ruta de Misiones de fuera que esperaba nivel ya puede arrancar
  local mk = lasMarcadas()
  if mk then
    for _, g in ipairs(mk.grupos) do
      g.listo = false
      for _, q in ipairs(g.q) do if nuevo >= (q.nivel or 0) then g.listo = true end end
    end
    if not rutaDeLaCadena() then siguienteDeLaRuta(true) end
  end
  return lista
end

-- 9-oct (4.16): al aceptar una mision de mazmorra, el chat dice a quien se entrega y donde
local function avisoEntrega(id)
  if apagado() then return end
  local _, _, _, porId = pendientes()
  local q = porId[tonumber(id) or 0]
  if not q then return end
  print(AZUL .. MORADO .. q.n .. "|r: " .. dondeSeEntrega(q))
end
WowF._avisoEntregaMision = avisoEntrega -- para las pruebas

local vigia = CreateFrame("Frame")
for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_DETAIL", "QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP" }) do pcall(vigia.RegisterEvent, vigia, e) end
vigia:SetScript("OnEvent", function(_, evento, unidad, otro)
  -- QUEST_ACCEPTED: (indice, id) en el cliente clasico, (id) en el moderno. La ruta de "Misiones de fuera" pasa al siguiente NPC
  if evento == "QUEST_ACCEPTED" then pcall(aceptada, (type(otro) == "number" and otro > 0) and otro or unidad); pcall(avisoEntrega, (type(otro) == "number" and otro > 0) and otro or unidad) end
  if evento == "NAME_PLATE_UNIT_ADDED" then pcall(revisarPlaca, unidad)
  elseif evento == "NAME_PLATE_UNIT_REMOVED" then
    local placa = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unidad)
    if placa and marcas[placa] then marcas[placa]:Hide() end
  elseif evento == "QUEST_DETAIL" then pcall(registrarXP); pcall(mostrarCartel)
  elseif evento == "QUEST_COMPLETE" then pcall(registrarXP)
  elseif evento == "QUEST_FINISHED" then if cartel then cartel:Hide() end
  else
    if evento == "QUEST_TURNED_IN" and WowF.misionEntregada then WowF.misionEntregada(unidad) end
    if evento == "PLAYER_LEVEL_UP" then pcall(WowF.misionesDesbloqueadas, tonumber(unidad)) end
    pcall(revisarPlacas); pcall(dibujar)
  end
end)

-- Placas de NPC amistosos: encender guarda como estaban, para dejarlas igual al apagar
local function cvar(n) local ok, v = pcall(GetCVar, n); return ok and v or nil end
local function placas(encender)
  if not SetCVar then return false end
  if InCombatLockdown and InCombatLockdown() then return false end -- en combate el juego lo bloquea
  if encender then
    WowFExportarDB.placasAntes = WowFExportarDB.placasAntes or { amigos = cvar("nameplateShowFriends"), npc = cvar("nameplateShowFriendlyNPCs") }
    pcall(SetCVar, "nameplateShowFriends", "1")
    pcall(SetCVar, "nameplateShowFriendlyNPCs", "1")
  else
    local a = WowFExportarDB.placasAntes or {}
    pcall(SetCVar, "nameplateShowFriendlyNPCs", a.npc or "0")
    pcall(SetCVar, "nameplateShowFriends", a.amigos or "0")
    WowFExportarDB.placasAntes = nil
  end
  return true
end

-- ----- /wowf misiones y /wowf placas -----
local function listar()
  local lista = pendientes()
  local nivel = nivelActual()
  if #lista == 0 then print(WowF.T(AZUL .. "no hay misiones de mazmorra pendientes para tu nivel.")); return end
  print(WowF.T(AZUL .. "misiones de mazmorra de tu nivel (casi todas se cogen FUERA, antes de entrar):"))
  for _, q in ipairs(lista) do
    print(WowF.T("   " .. ORO .. q.mazmorra.n .. "|r: " .. BLANCO .. q.n .. "|r - " .. cuando(q, nivel)))
    print("      " .. (q.dentro and WowF.T(GRIS .. "se recoge dentro de la mazmorra|r") or dondeLaDa(q)))
  end
  print(WowF.T(GRIS .. "En el mapa (M) salen con un ! en un aro morado: raton encima = que mision es; clic = ruta hasta quien la da. /wowf placas on = el icono tambien sobre la cabeza del NPC.|r"))
end
local anterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower(); resto = (resto or ""):lower()
  if orden == "misiones" or orden == "quests" then
    if resto == "off" or resto == "no" then WowFExportarDB.misionesMazmorra = false; print(WowF.T(AZUL .. "marcas de misiones de mazmorra: apagadas (/wowf misiones on para verlas)."))
    elseif resto == "on" or resto == "si" then WowFExportarDB.misionesMazmorra = nil; print(WowF.T(AZUL .. "marcas de misiones de mazmorra: encendidas."))
    else listar() end
    pcall(dibujar); pcall(revisarPlacas)
    return
  end
  if orden == "placas" or orden == "nameplates" then
    local on = not (resto == "off" or resto == "no")
    if placas(on) then
      print(WowF.T(AZUL .. (on and "placas de NPC amistosos encendidas: el ! morado sale sobre la cabeza de quien da una mision de mazmorra. /wowf placas off las apaga."
        or "placas de NPC amistosos como estaban antes.")))
    end
    pcall(revisarPlacas)
    return
  end
  if anterior then anterior(mensaje) end
end
