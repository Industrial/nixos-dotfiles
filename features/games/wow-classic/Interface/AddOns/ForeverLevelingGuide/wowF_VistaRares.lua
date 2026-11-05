-- Forever Leveling Guide: pestana "Rares" del plan completo (19-oct, pedido de Andy: "una seccion para los rares, visible,
-- mas profesional, que marque el mapa"). WowF.vistaRares(p, hoja, ancho, ctx) (contrato en CONTRATO.md).
-- Datos: WowFRares (wowF_Rares_Datos.lua, Wowhead /forever, solo temporada "0"). Solo rares de tu faccion y de zonas
-- permitidas (WowF._rareTeSirve). Arriba: cabecera con cifras + conmutador Tu zona | Para tu nivel | Mejor botin | Peligrosos.
-- Cada tarjeta: calavera del color de la dificultad, nombre (ingles), nivel, zona y coordenadas, botin con icono y %,
-- y "Marcar en el mapa" (alfiler del juego + abre el mapa en esa zona).

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local CALIDAD = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }
local AZUL = "|cff66ccffForever Guide:|r "
local ORO, GRIS = "|cffffd100", "|cff9d9d9d"
local CALAVERA = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local TOPE = 20 -- tarjetas por filtro (2 columnas)
local POCAS = 20

local function C() return (WowF.estilo and WowF.estilo.color) or {} end
local function nivelPj() return tonumber(WowF.llamar and WowF.llamar(UnitLevel, "player") or (UnitLevel and UnitLevel("player"))) or 1 end
local function mapaPj()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
  return ok and m or nil
end
local function sirve(r, m) return not WowF._rareTeSirve or WowF._rareTeSirve(r, m) end
local function zona(m)
  if WowF.nombreZona then local ok, z = pcall(WowF.nombreZona, m); if ok and z then return z end end
  return tostring(m)
end
local function SIN_DATOS() return L("Aún no hay datos de WoW Forever; se actualizará en próximas actualizaciones.", "No WoW Forever data yet; this will be updated in future updates.") end

-- Dificultad para tu nivel: color de la calavera y del nivel (como el mapa)
-- 19-oct (foto de Andy: "Nivel 0"): Wowhead no da el nivel de algunos rares (a = 0) -> "nivel sin confirmar",
-- calavera blanca, y no entran en "Para tu nivel", "Mejor botin" ni "Peligrosos" (no se sabe si puedes matarlos)
local function sinNivel(r) return (r.a or 0) <= 0 end
local function colorNivel(r)
  if sinNivel(r) then return { 0.9, 0.9, 0.9 } end
  local nv = r.a or 1
  if GetQuestDifficultyColor then
    local ok, c = pcall(GetQuestDifficultyColor, nv)
    if ok and type(c) == "table" and c.r then return { c.r, c.g, c.b } end
  end
  local d = nv - nivelPj()
  if d >= 5 then return { 1, 0.1, 0.1 } elseif d >= 3 then return { 1, 0.5, 0.25 } elseif d >= -2 then return { 1, 1, 0 } elseif d >= -7 then return { 0.25, 0.75, 0.25 } end
  return { 0.5, 0.5, 0.5 }
end
local function textoNivel(r)
  if sinNivel(r) then return L("Nivel sin confirmar en WoW Forever", "Level not confirmed in WoW Forever") end
  local n = (r.a == r.b or not r.b or r.b == 0) and tostring(r.a) or (r.a .. "-" .. r.b)
  return L("Nivel ", "Level ") .. n
end
local function peligroso(r, nivel) return not sinNivel(r) and ((r.a or 0) >= nivel + 3 or (r.e and (r.a or 0) >= nivel - 2)) end
local function mejorDrop(r)
  local q, pct = -1, 0
  for _, o in ipairs(r.d or {}) do
    if (o[3] or 0) > q or ((o[3] or 0) == q and (o[4] or 0) > pct) then q, pct = o[3] or 0, o[4] or 0 end
  end
  return q, pct
end
local function pctTexto(o)
  local v = o[4] or 0
  local pct = v >= 10 and math.floor(v + 0.5) or (math.floor(v * 10 + 0.5) / 10)
  return pct .. " %" .. (((o[5] or 0) < POCAS) and "*" or "")
end
local function iconoObjeto(id)
  local tx
  if C_Item and C_Item.GetItemIconByID then local ok, v = pcall(C_Item.GetItemIconByID, id); if ok then tx = v end end
  if not tx and GetItemIcon then local ok, v = pcall(GetItemIcon, id); if ok then tx = v end end
  return tx or 134400
end

-- ----- ¿Te sirve a TI? (19-oct, Andy: "mostrar siempre lo que te va a servir a ti... para equiparte, para vender, para otra cosa") -----
-- Por objeto: "mejora" (te mejora, como el aviso de botin), "guardar" (para tu rama final), "prof" (lo piden recetas de TUS
-- profesiones: Dependencias > Compra), "vende" (vale dinero: precio del cliente o de la subasta, como el aviso de botin) o nil.
-- Reutiliza WowF.avisoBotinDecidir (wowF_AvisoBotin.lua), asi el filtro dice lo mismo que el aviso al recogerlo.
local UTIL_ORDEN = { mejora = 4, guardar = 3, prof = 2, vende = 1 }
local cacheUtil, pendientes = {}, false
local function enlaceDe(id)
  local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if type(f) ~= "function" then return nil end
  local ok, nombre, link = pcall(f, id)
  if ok and nombre and type(link) == "string" then return link end
  if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  pendientes = true
  return nil
end
local function utilDe(id)
  local c = cacheUtil[id]
  if c ~= nil then return c or nil end
  -- Para tus profesiones (no hace falta la info del objeto en el cliente)
  if WowF.dependencias then
    local ok, d = pcall(WowF.dependencias)
    if ok and type(d) == "table" then
      for _, e in ipairs(d.compra or {}) do
        if e.id == id then
          local ej = e.ejemplo or {}
          local res = { tipo = "prof", prof = ej.prof }
          cacheUtil[id] = res
          return res
        end
      end
    end
  end
  local link = enlaceDe(id)
  if not link then return nil end -- el cliente aun no lo tiene: se vuelve a mirar al llegar (GET_ITEM_INFO_RECEIVED)
  local res = false
  if WowF.avisoBotinDecidir then
    local ok, tipo, _, extra = pcall(WowF.avisoBotinDecidir, link)
    if ok and extra == "pendiente" then pendientes = true; return nil end
    if ok and tipo == "sirve" then res = { tipo = "mejora" }
    elseif ok and tipo == "guardar" then res = { tipo = "guardar" }
    elseif ok and tipo == "vende" then res = { tipo = "vende" } end
  end
  cacheUtil[id] = res
  return res or nil
end
-- Lo mejor que te da un rare: { tipo, pct } (nil = nada para ti)
local function utilRare(r)
  local mejor
  for _, o in ipairs(r.d or {}) do
    local u = utilDe(o[1])
    if u and (not mejor or UTIL_ORDEN[u.tipo] > UTIL_ORDEN[mejor.tipo] or (u.tipo == mejor.tipo and (o[4] or 0) > mejor.pct)) then
      mejor = { tipo = u.tipo, pct = o[4] or 0 }
    end
  end
  return mejor
end
local function textoUtil(u)
  if not u then return nil end
  if u.tipo == "mejora" then return L("Mejora para ti", "Upgrade for you"), "verde" end
  if u.tipo == "guardar" then return L("Para tu rama final", "For your final spec"), "brasa" end
  if u.tipo == "prof" then
    local p = u.prof and ((WowF.nombreProfesionEN and WowF.nombreProfesionEN(u.prof)) or (WowFDatos and WowFDatos.prof and WowFDatos.prof[u.prof]))
    return (type(p) == "string" and p ~= "") and L("Para tu " .. p, "For your " .. p) or L("Para tu profesión", "For your profession"), "brasa"
  end
  return L("Se vende bien", "Sells well"), "oro"
end
local ayudaUtil = {
  mejora = function() return L("Te mejora lo que llevas puesto (con los pesos de tu rama), igual que el aviso al recogerlo.", "It improves what you wear (with your spec weights), same as the loot alert.") end,
  guardar = function() return L("Le sirve a la rama final de tu plan: guárdalo hasta que cambies.", "It suits the final spec of your plan: keep it until you switch.") end,
  prof = function() return L("Lo piden recetas de tus profesiones y no lo sacas tú (Profesiones > Dependencias).", "Recipes of your professions need it and you do not gather it (Professions > Dependencies).") end,
  vende = function() return L("No te sirve para equiparte, pero vale dinero (precio del vendedor o de la subasta).", "Not an upgrade for you, but it is worth money (vendor or auction price).") end,
}
-- Al llegar la info de objetos que faltaban: se olvida lo calculado y se redibuja la pestana (una vez por medio segundo)
local eventosUtil = CreateFrame and CreateFrame("Frame")
if eventosUtil then
  pcall(eventosUtil.RegisterEvent, eventosUtil, "GET_ITEM_INFO_RECEIVED")
  pcall(eventosUtil.RegisterEvent, eventosUtil, "PLAYER_EQUIPMENT_CHANGED")
  pcall(eventosUtil.RegisterEvent, eventosUtil, "SKILL_LINES_CHANGED")
  eventosUtil:SetScript("OnEvent", function(_, ev)
    if ev ~= "GET_ITEM_INFO_RECEIVED" then cacheUtil = {} elseif not pendientes then return end
    if eventosUtil.esperando then return end
    eventosUtil.esperando = true
    local function rehacer()
      eventosUtil.esperando = false
      pendientes = false
      if WowF._redibujarRares then pcall(WowF._redibujarRares) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, rehacer) else rehacer() end
  end)
end
WowF._utilRareObjeto = utilDe -- para las pruebas
WowF._olvidarUtilRares = function() cacheUtil = {}; pendientes = false end -- para las pruebas
local function paraMi() return not (WowFExportarDB and WowFExportarDB.raresBotinPara == "todos") end

-- ----- Listas -----
-- Cada entrada: { id, r, m (mapa donde mostrarlo), puntos = { {x, y}, ... } } en un mapa que te sirve
local function entrada(id, r, preferido)
  local porMapa, orden = {}, {}
  for _, p in ipairs(r.p or {}) do
    if sirve(r, p[1]) then
      if not porMapa[p[1]] then porMapa[p[1]] = {}; table.insert(orden, p[1]) end
      table.insert(porMapa[p[1]], { p[2], p[3] })
    end
  end
  local m = (preferido and porMapa[preferido]) and preferido or orden[1]
  if not m then return nil end
  return { id = id, r = r, m = m, puntos = porMapa[m] }
end
local function todas(preferido)
  local t = {}
  for id, r in pairs(WowFRares and WowFRares.r or {}) do
    local e = entrada(id, r, preferido)
    if e then table.insert(t, e) end
  end
  return t
end
local function porNombre(a, b) return (a.r.n or "") < (b.r.n or "") end

local FILTROS = { "zona", "nivel", "botin", "peligro" }
local function listaDe(filtro, nivel, m)
  local t = {}
  for _, e in ipairs(todas(m)) do
    local r = e.r
    if filtro == "zona" then
      if m and e.m == m then table.insert(t, e) end
    elseif sinNivel(r) then
      -- nivel sin confirmar: solo en "Tu zona"
    elseif filtro == "nivel" then
      if (r.a or 0) >= nivel - 2 and (r.a or 0) <= nivel + 4 then table.insert(t, e) end
    elseif filtro == "botin" then
      local q = mejorDrop(r)
      if (r.a or 0) <= nivel + 5 and (r.b or r.a or 0) >= nivel - 10 then
        if paraMi() then
          e.util = utilRare(r)
          if e.util then table.insert(t, e) end
        elseif q >= 2 then
          table.insert(t, e)
        end
      end
    elseif filtro == "peligro" then
      if peligroso(r, nivel) and (r.a or 0) <= nivel + 12 then table.insert(t, e) end
    end
  end
  if filtro == "zona" then
    table.sort(t, function(a, b) if (a.r.a or 0) ~= (b.r.a or 0) then return (a.r.a or 0) < (b.r.a or 0) end return porNombre(a, b) end)
  elseif filtro == "nivel" then
    table.sort(t, function(a, b)
      local da, db = math.abs((a.r.a or 0) - nivel), math.abs((b.r.a or 0) - nivel)
      if da ~= db then return da < db end
      return porNombre(a, b)
    end)
  elseif filtro == "botin" then
    table.sort(t, function(a, b)
      if a.util and b.util then
        local ua, ub = UTIL_ORDEN[a.util.tipo], UTIL_ORDEN[b.util.tipo]
        if ua ~= ub then return ua > ub end
        if a.util.pct ~= b.util.pct then return a.util.pct > b.util.pct end
      end
      local qa, pa = mejorDrop(a.r)
      local qb, pb = mejorDrop(b.r)
      if qa ~= qb then return qa > qb end
      if pa ~= pb then return pa > pb end
      return porNombre(a, b)
    end)
  else
    table.sort(t, function(a, b)
      if (a.r.a or 0) ~= (b.r.a or 0) then return (a.r.a or 0) > (b.r.a or 0) end
      if (a.r.e and 1 or 0) ~= (b.r.e and 1 or 0) then return a.r.e and true or false end
      return porNombre(a, b)
    end)
  end
  return t
end
WowF._listaRaresVista = listaDe -- para las pruebas

-- ----- Marcar en el mapa: alfiler del juego + abre el mapa en esa zona -----
-- 19-oct (Andy: "marcamelo en el mapa... y me cree la ruta para llegar a el... si hay que coger algun vuelo"):
-- ruta con WowF.viajeA (pasos, vuelos y alfiler que avanza solo), como el entrenador de clase. El rare queda "elegido"
-- (WowFExportarDB.rareElegido): sus calaveras se ven siempre con halo dorado aunque las de zona esten apagadas.
-- Ya NO enciende las calaveras de zona. Sin ruta posible: alfiler a mano en el punto.
-- El punto: el mas cercano a ti si estas en esa zona; si no, el primero.
local function puntoCercano(e)
  local mejor, dist = e.puntos[1], nil
  if mapaPj() ~= e.m or not (C_Map and C_Map.GetPlayerMapPosition) then return mejor end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, e.m, "player")
  if not ok or not pos then return mejor end
  local okX, px, py = pcall(function() return pos:GetXY() end)
  if not okX or not px then return mejor end
  px, py = px * 100, py * 100
  for _, p in ipairs(e.puntos) do
    local d = (p[1] - px) ^ 2 + (p[2] - py) ^ 2
    if not dist or d < dist then mejor, dist = p, d end
  end
  return mejor
end
local function esElegido(e)
  local el = WowFExportarDB and WowFExportarDB.rareElegido
  return type(el) == "table" and el.id == e.id
end
local function quitar()
  if WowF.limpiarRutas then pcall(WowF.limpiarRutas, true) end -- quita la ruta, el alfiler y el rare elegido
  if WowF.quitarRareElegido then pcall(WowF.quitarRareElegido) end
  print(AZUL .. L("rare quitado del mapa (y su ruta).", "rare removed from the map (and its route)."))
  if WowF._redibujarRares then pcall(WowF._redibujarRares) end
end
WowF._quitarRareMarcado = quitar
local function marcar(e)
  local p = puntoCercano(e)
  local nombre = WowF.yaTraducido and WowF.yaTraducido(e.r.n) or e.r.n
  local z = zona(e.m)
  if WowF.limpiarRutas then pcall(WowF.limpiarRutas, true) end -- una sola ruta a la vez (tambien quita el rare de antes)
  if WowFExportarDB then WowFExportarDB.rareElegido = { id = e.id, m = e.m } end
  local n = #e.puntos
  local otros = n > 1 and L(" Puede salir en cualquiera de sus " .. n .. " sitios: las calaveras con halo dorado del mapa.",
    " It can spawn at any of its " .. n .. " spots: the skulls with a golden glow on the map.") or ""
  local quien = ORO .. nombre .. "|r" .. GRIS .. " (RARE, " .. textoNivel(e.r) .. (e.r.e and " elite" or "") .. ")|r"
  local destino = { n = nombre, m = e.m, x = p[1], y = p[2], z = z, lugar = true, final = {
    titulo = nombre, ventana = ORO .. "Rare: " .. nombre .. "|r",
    texto = L("Busca a ", "Look for ") .. quien .. "." .. otros,
    llegada = L("busca a ", "look for ") .. quien .. L(". Si no está, prueba en otro de sus sitios (calaveras doradas) o vuelve más tarde: los rares tardan en volver a salir.",
      ". If it is not there, try another of its spots (golden skulls) or come back later: rares take a while to respawn."),
    npc = e.r.n } }
  local ok, hecho = false, false
  if WowF.viajeA then ok, hecho = pcall(WowF.viajeA, destino, { dibujar = true }) end
  local conRuta = ok and hecho and true or false
  local puesto = conRuta
  if not conRuta then
    if WowF.marcar then
      puesto = pcall(WowF.marcar, { m = e.m, x = p[1], y = p[2], n = nombre .. " (RARE)", z = z, lugar = true })
    elseif C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
      puesto = pcall(function()
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(e.m, p[1] / 100, p[2] / 100))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
      end)
    end
  end
  if WowF.interfazMando() then -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego (la flecha de destino sigue)
  elseif OpenWorldMap then pcall(OpenWorldMap, e.m)
  elseif WorldMapFrame then
    if ShowUIPanel then pcall(ShowUIPanel, WorldMapFrame) elseif WorldMapFrame.Show then WorldMapFrame:Show() end
    if WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, e.m) end
  end
  if WowF.dibujarRares then pcall(WowF.dibujarRares) end
  local donde = z .. string.format(" %.0f, %.0f", p[1], p[2])
  if conRuta then
    -- viajeA ya escribio los pasos en el chat
  elseif puesto then
    print(AZUL .. L("alfiler puesto en " .. donde .. ": " .. nombre .. ".", "pin placed at " .. donde .. ": " .. nombre .. "."))
  else
    print(AZUL .. L(nombre .. " está en " .. donde .. ".", nombre .. " is at " .. donde .. "."))
  end
  WowF._ultimoRareMarcado = { m = e.m, x = p[1], y = p[2], n = e.r.n, puesto = puesto, ruta = conRuta, id = e.id }
  if WowF._redibujarRares then pcall(WowF._redibujarRares) end
  return puesto
end
WowF._marcarRare = marcar

-- ----- Dibujo -----
local vista
local function altoTarjeta(r)
  local n = #(r.d or {})
  local filas = n == 0 and 2 or math.min(n, 4)
  return 76 + 22 + filas * 26 + 62
end

local function tarjeta(k, x0, y0, w, h, e, nivel, mapaAqui)
  local r = e.r
  k:tarjeta(x0, y0, w, h, peligroso(r, nivel) and "principal" or nil)
  local col = colorNivel(r)
  -- Calavera del color de la dificultad
  local cal = k:tomar("calavera", k.capa, function(pd) return WowF.estilo.icono(pd, 44) end)
  cal:SetSize(44, 44)
  cal:poner(CALAVERA, r.e and "oro" or nil)
  if cal.tex.SetTexCoord then cal.tex:SetTexCoord(0, 1, 0, 1) end
  if cal.tex.SetVertexColor then cal.tex:SetVertexColor(col[1], col[2], col[3]) end
  cal:SetPoint("TOPLEFT", k.marco, "TOPLEFT", x0 + 14, -(y0 + 14))
  local tx = x0 + 70
  -- Chips a la derecha: elite / en tu zona
  local cx = x0 + w - 14
  if r.e then local _, cw = k:chip(cx, y0 + 14, L("ÉLITE", "ELITE"), "oro", true); cx = cx - cw - 6 end
  if mapaAqui and e.m == mapaAqui then local _, cw = k:chip(cx, y0 + 14, L("EN TU ZONA", "IN YOUR ZONE"), "verde", true); cx = cx - cw - 6 end
  k:texto(tx, y0 + 12, WowF.yaTraducido and WowF.yaTraducido(r.n) or r.n, { tam = 17, letra = "marca", color = C().orocl, ancho = cx - tx - 4 })
  k:texto(tx, y0 + 36, textoNivel(r), { tam = 13, peso = "negrita", color = col })
  local p = e.puntos[1]
  local otros = #e.puntos - 1
  local donde = zona(e.m) .. string.format("  %.0f, %.0f", p[1], p[2])
    .. (otros > 0 and L("  (+" .. otros .. " sitios donde sale)", "  (+" .. otros .. " spawn spots)") or "")
  k:texto(tx, y0 + 55, donde, { tam = 12, color = C().tenue, ancho = w - (tx - x0) - 14 })
  -- Botin
  local y = y0 + 80
  k:raya(x0 + 14, y - 4, w - 28)
  k:rotulo(x0 + 14, y + 2, L("BOTÍN (WOW FOREVER)", "LOOT (WOW FOREVER)"))
  -- 19-oct (Andy: "el porcentaje... explica que quiere decir, porque es muy confuso"): la columna dice que es y el raton lo explica
  k:texto(x0 + w - 14 - 160, y + 3, L("PROB. DE SOLTARLO", "DROP CHANCE"), { tam = 11, peso = "negrita", color = C().tenue, ancho = 160, just = "RIGHT" })
  k:zona(x0 + w - 14 - 160, y, 160, 18, nil, function(tt)
    tt:SetText(L("Probabilidad de que lo suelte", "Drop chance"), 1, 0.82, 0)
    tt:AddLine(L("Cada vez que matas a este rare. 36 % = de cada 100 veces que lo matas, unas 36 suelta ese objeto.",
      "Each time you kill this rare. 36 % = out of 100 kills, it drops that item about 36 times."), 1, 1, 1, true)
    tt:AddLine(L("* = pocas muestras en Wowhead (WoW Forever): el % es aproximado.", "* = few samples on Wowhead (WoW Forever): the % is approximate."), 0.7, 0.7, 0.7, true)
  end)
  y = y + 22
  local drops = r.d or {}
  if #drops == 0 then
    k:texto(x0 + 14, y + 2, SIN_DATOS(), { tam = 12, color = C().oro, ancho = w - 28 })
  else
    for i = 1, math.min(#drops, 4) do
      local o = drops[i]
      k:icono(x0 + 14, y + 2, 22, iconoObjeto(o[1]))
      k:texto(x0 + w - 14 - 80, y + 5, pctTexto(o), { tam = 13, peso = "negrita", color = C().orocl, ancho = 80, just = "RIGHT" })
      -- Para ti: mejora / rama final / tu profesion / se vende bien
      local u = utilDe(o[1])
      local tu, colU = textoUtil(u)
      local anchoNombre = w - 44 - 90
      if tu then
        local _, cw = k:chip(x0 + w - 14 - 84, y + 3, tu, colU, true)
        anchoNombre = anchoNombre - (cw or 0) - 6
      end
      k:texto(x0 + 44, y + 5, (CALIDAD[o[3]] or "|cffffffff") .. o[2] .. "|r", { tam = 13, ancho = anchoNombre })
      local id, pct = o[1], pctTexto(o)
      k:zona(x0 + 14, y, w - 28, 26, nil, function(tt)
        if tt.SetItemByID then tt:SetItemByID(id) else tt:SetText(o[2]) end
        tt:AddLine(" ")
        tt:AddLine(L("Lo suelta el " .. pct .. " de las veces que matas a este rare.", "Drops " .. pct .. " of the times you kill this rare."), 1, 0.82, 0, true)
        if u and ayudaUtil[u.tipo] then tt:AddLine(tu .. ": " .. ayudaUtil[u.tipo](), 0.2, 1, 0.4, true) end
      end)
      y = y + 26
    end
  end
  -- Boton: marcar con ruta, o quitarlo si ya es el marcado
  local by = y0 + h - 44
  local b
  if esElegido(e) then
    b = k:boton(x0 + 14, by, L("Quitar del mapa", "Remove from map"), "secundario", true, quitar,
      { ayuda = L("Quita este rare del mapa, su ruta y el alfiler.", "Removes this rare from the map, its route and the pin.") })
    k:chip(x0 + w - 14, by + 4, L("MARCADO EN EL MAPA", "MARKED ON THE MAP"), "oro", true)
  else
    b = k:boton(x0 + 14, by, L("Marcar en el mapa", "Mark on the map"), "estandarte", true, function() marcar(e) end,
      { ayuda = L("Lo marca en el mapa con su ruta desde donde estás (con vuelo si hace falta). Sus sitios se ven con calavera dorada, aunque tengas las calaveras apagadas.",
        "Marks it on the map with a route from where you are (with a flight if needed). Its spots show with a golden skull, even with skulls turned off.") })
  end
  e.boton = b
  return b
end

function WowF.vistaRares(p, hoja, ancho, ctx)
  if not (WowF.estilo and WowF.estilo.tarjeta and WowF.vistaKit) then return nil end
  ancho = ancho or 890
  ctx = ctx or {}
  local K = WowF.vistaKit
  if not vista then
    local m, kit = K.marcoDe(nil, hoja, ancho)
    vista = { marco = m, kit = kit }
  end
  local m, k = vista.marco, vista.kit
  if m.GetParent and m:GetParent() ~= hoja and m.SetParent then m:SetParent(hoja) end
  m:SetWidth(ancho)
  k:empezar()
  local nivel = nivelPj()
  local aqui = mapaPj()
  local listas = {}
  for _, f in ipairs(FILTROS) do listas[f] = listaDe(f, nivel, aqui) end
  local sub = ctx.sub
  if not listas[sub or ""] then sub = (#listas.zona > 0) and "zona" or "nivel" end
  vista.sub, vista.listas = sub, listas

  -- Cabecera
  local y = 0
  local cab = k:tarjeta(0, y, ancho, 84, "principal")
  k:texto(18, y + 14, L("Rares de WoW Forever", "WoW Forever rares"), { tam = 22, letra = "marca", color = C().orocl })
  local total = #todas(aqui)
  k:texto(18, y + 46, L("Bichos raros de tu facción: dónde salen, qué sueltan y qué tan duros son para tu nivel. Datos de Wowhead (WoW Forever) del " .. tostring(WowFRares and WowFRares.fecha or "?") .. ".",
    "Rare mobs for your faction: where they spawn, what they drop and how tough they are for your level. Data from Wowhead (WoW Forever), " .. tostring(WowFRares and WowFRares.fecha or "?") .. "."),
    { tam = 12, color = C().tenue, ancho = ancho - 300 })
  local cx = ancho - 18
  local _, w1 = k:cifra(cx, y + 16, #listas.zona, L("en tu zona", "in your zone"), true); cx = cx - w1 - 18
  local _, w2 = k:cifra(cx, y + 16, #listas.nivel, L("para tu nivel", "for your level"), true); cx = cx - w2 - 18
  k:cifra(cx, y + 16, total, L("en total", "in total"), true)
  if cab.SetHeight then cab:SetHeight(84) end
  y = y + 84 + 12

  -- 19-oct (Andy: "facil de activarlo y desactivarlo... visible, facil de entender"): calaveras del mapa a la vista
  local redibujar = function() if ctx.redibujar then ctx.redibujar() elseif WowF.libroRefrescar then pcall(WowF.libroRefrescar) end end
  WowF._redibujarRares = function() if vista and vista.marco and vista.marco.IsVisible and vista.marco:IsVisible() then redibujar() end end
  local enMapa = not (WowFExportarDB and WowFExportarDB.raresMapa == false)
  k:tarjeta(0, y, ancho, 44, "hundida")
  local _, _, wl = k:texto(16, y + 14, L("Calaveras en el mapa:", "Skulls on the map:"), { tam = 13, peso = "negrita", color = C().orocl })
  local xs = 16 + (wl or 150) + 10
  local ws = k:seg(xs, y + 9, {
    { "zona", L("Solo tu zona", "Your zone only") },
    { "no", L("Ninguna", "None") },
  }, enMapa and "zona" or "no", function(c)
    WowFExportarDB.raresMapa = (c == "zona")
    if WowF.dibujarRares then pcall(WowF.dibujarRares) end
    if WowF.refrescarBotonRares then pcall(WowF.refrescarBotonRares) end
    if WowF.refrescarOpciones then pcall(WowF.refrescarOpciones) end
    redibujar()
  end)
  k:texto(xs + (ws or 200) + 14, y + 8, L("El rare que marques se ve siempre, con su ruta. También con el botón del mapa (M).",
    "The rare you mark always shows, with its route. Also with the button on the map (M)."), { tam = 12, color = C().tenue, ancho = ancho - (xs + (ws or 200) + 14) - 16 })
  y = y + 44 + 12

  -- Conmutador de filtros
  local ops = {
    { "zona", L("Tu zona", "Your zone") .. " (" .. #listas.zona .. ")" },
    { "nivel", L("Para tu nivel", "For your level") .. " (" .. #listas.nivel .. ")" },
    { "botin", L("Mejor botín", "Best loot") .. " (" .. #listas.botin .. ")" },
    { "peligro", L("Peligrosos", "Dangerous") .. " (" .. #listas.peligro .. ")" },
  }
  k:seg(0, y, ops, sub, function(c) if ctx.ponerSub then ctx.ponerSub(c) else vista.subForzado = c; if ctx.redibujar then ctx.redibujar() end end end)
  y = y + 28 + 8
  -- 19-oct (Andy: "la opcion de marcar solamente para mi personaje o para todos"): Mejor botin para ti o de todos
  local mio = paraMi()
  if sub == "botin" then
    local _, _, wl = k:texto(2, y + 5, L("Mejor botín:", "Best loot:"), { tam = 13, peso = "negrita", color = C().orocl })
    k:seg(2 + (wl or 90) + 10, y, {
      { "mio", L("Para mi personaje", "For my character") },
      { "todos", L("Para todos", "For everyone") },
    }, mio and "mio" or "todos", function(c)
      WowFExportarDB.raresBotinPara = (c == "todos") and "todos" or nil
      redibujar()
    end)
    y = y + 28 + 8
  end
  local EXPLICA = {
    zona = L("Los rares de la zona donde estás, del más fácil al más difícil.", "The rares in the zone you are in, easiest first."),
    nivel = L("Rares de tu nivel (de 2 menos a 4 más), los más cercanos a tu nivel primero.", "Rares around your level (2 below to 4 above), closest to your level first."),
    botin = mio and L("Solo los que sueltan algo que te sirve a ti: mejora para tu equipo, para tu rama final, para tus profesiones o que se vende bien. Puedes matarlos a tu nivel.",
        "Only the ones that drop something useful for you: an upgrade, for your final spec, for your professions or that sells well. You can kill them at your level.")
      or L("Los que sueltan mejor botín (calidad y probabilidad) y puedes matar a tu nivel, sirva o no a tu personaje.",
        "The ones with the best loot (quality and chance) that you can kill at your level, useful for your character or not."),
    peligro = L("Élites y rares muy por encima de tu nivel: ve en grupo o espera a subir.", "Elites and rares well above your level: bring a group or wait until you level up."),
  }
  local _, he = k:texto(2, y, EXPLICA[sub] .. L("  Color de la calavera y del nivel = dificultad para ti. % = probabilidad de que suelte ese objeto cada vez que lo matas (* = pocas muestras, aproximado).",
    "  Skull and level color = difficulty for you. % = chance it drops that item each time you kill it (* = few samples, approximate)."), { tam = 12, color = C().tenue, ancho = ancho - 4 })
  y = y + he + 10

  local lista = listas[sub]
  if #lista == 0 then
    local t = k:tarjeta(0, y, ancho, 60, "hundida")
    local txt = (sub == "botin" and mio)
      and L("Ningún rare a tu alcance suelta ahora algo que te sirva a ti (equipo, rama final, profesiones o venta). Mira \"Para todos\".",
        "No rare within your reach drops anything useful for you right now (gear, final spec, professions or selling). Check \"For everyone\".")
      or (sub == "zona")
      and L("Aún no hay datos de rares de WoW Forever en esta zona; se actualizará en próximas actualizaciones. Mira \"Para tu nivel\".",
        "No WoW Forever rare data for this zone yet; this will be updated in future updates. Check \"For your level\".")
      or SIN_DATOS()
    local _, h = k:texto(16, y + 14, txt, { tam = 13, color = C().tenue, ancho = ancho - 32 })
    t:SetHeight(h + 28)
    y = y + h + 28
  else
    local cw = math.floor((ancho - 12) / 2)
    local n = math.min(#lista, TOPE)
    for i = 1, n, 2 do
      local a, b = lista[i], (i + 1 <= n) and lista[i + 1] or nil
      local h = math.max(altoTarjeta(a.r), b and altoTarjeta(b.r) or 0)
      tarjeta(k, 0, y, cw, h, a, nivel, aqui)
      if b then tarjeta(k, cw + 12, y, cw, h, b, nivel, aqui) end
      y = y + h + 12
    end
    if #lista > n then
      local _, h = k:texto(2, y, L("Se muestran los " .. n .. " primeros de " .. #lista .. ".", "Showing the first " .. n .. " of " .. #lista .. "."), { tam = 12, color = C().tenue })
      y = y + h + 8
    end
  end
  k:hasta(y)
  m:SetHeight(math.max(1, k.alto))
  return m, k.alto, k.textos
end
WowF._vistaRares = function() return vista end -- para las pruebas

-- Respaldo de texto (lo usa CONTENIDO.Rares del Libro si la vista de tarjetas falla, y libroTexto)
function WowF.listaRaresTexto(cab, nota)
  local nivel, aqui = nivelPj(), mapaPj()
  local lista = listaDe("nivel", nivel, aqui)
  cab(L("Rares para tu nivel", "Rares for your level"))
  if #lista == 0 then nota(SIN_DATOS()) return end
  for i = 1, math.min(#lista, TOPE) do
    local e = lista[i]
    local p = e.puntos[1]
    local drops = {}
    for _, o in ipairs(e.r.d or {}) do table.insert(drops, (CALIDAD[o[3]] or "") .. o[2] .. "|r " .. pctTexto(o)) end
    nota(e.r.n .. " (" .. textoNivel(e.r) .. (e.r.e and " elite" or "") .. ") - " .. zona(e.m) .. string.format(" %.0f, %.0f", p[1], p[2])
      .. (#drops > 0 and (": " .. table.concat(drops, ", ")) or ""))
  end
end
