-- Forever Leveling Guide: profesiones que se suben matando bichos (protocolo de Andy, 6-oct: "marcar un area en el mapa, la mas
-- cercana y densa, con un circulo... solo de WoW Forever"). Skinning, Leatherworking, Tailoring, Cooking y First Aid.
--   WowF.mejorAreaMobs(clave)  clave = "piel" | "tela" | id de un material. Elige EN VIVO el area mas cercana y densa de bichos que
--                              te sirven: atacables por tu faccion y de tu nivel (sin filtro por rango de Skinning: no hay dato de Forever).
--   WowF.irAreaMobs(clave)     pone el circulo en el mapa (con radio), el alfiler al centro y explica en el chat que bichos y de que nivel.
-- Datos: WowFMobs (wowF_Mobs.lua, generado por herramientas/procesar-mobs.mjs desde Wowhead /forever). Nunca se inventa un area.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local AZUL, VERDE, GRIS, NARANJA, ORO = "|cff66ccffForever Guide:|r ", "|cff33ff66", "|cff999999", "|cffff9933", "|cffffd100"

local function datos() return WowFMobs end
local function nivelPj() return (UnitLevel and UnitLevel("player")) or 1 end
local function lado() local f = UnitFactionGroup and UnitFactionGroup("player"); return f == "Horde" and 2 or (f == "Alliance" and 1 or 0) end
local function nombreObj(id) local o = WowFDatos and WowFDatos.obj and WowFDatos.obj[id]; return o and o[1] or (L("objeto ", "item ") .. tostring(id)) end

-- 9-oct (regla de Andy: cero datos de Classic): el nivel de Skinning que pide cada bicho aun no tiene fuente de Forever,
-- asi que NO se filtran areas ni bichos por el rango de Skinning (antes: regla de Classic r/10+10 y r/5).

-- Bichos que te sirven para la clave: { [npc] = { pct, { objetos } } }
local function bichosDe(clave)
  local d = datos()
  if not d or not d.obj then return {} end
  local r = {}
  local function sumar(obj, lista)
    for _, b in ipairs(lista) do
      local e = r[b[1]] or { pct = 0, objs = {} }
      if b[2] > e.pct then e.pct = b[2] end
      e.objs[obj] = true
      r[b[1]] = e
    end
  end
  if type(clave) == "number" then
    local o = d.obj[clave]
    if o then sumar(clave, o[2]) end
  else
    for id, o in pairs(d.obj) do if o[1] == clave then sumar(id, o[2]) end end
  end
  return r
end
WowF.hayAreaMobs = function(clave) return next(bichosDe(clave)) ~= nil end

-- Posicion en el mundo (yardas) de un punto de un mapa
local function enMundo(m, x, y)
  if not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return nil end
  local ok, cont, v = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x / 100, y / 100))
  if not ok or not v or not v.GetXY then return nil end
  local wx, wy = v:GetXY()
  if not wx then return nil end
  return wx, wy, cont
end
local function dondeEstoy()
  local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not m or not C_Map.GetPlayerMapPosition then return nil end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, m, "player")
  if not ok or not pos then return m end
  local x, y = pos.x, pos.y
  if (not x or not y) and pos.GetXY then x, y = pos:GetXY() end
  if not x or (x == 0 and y == 0) then return m end
  return m, x * 100, y * 100
end

-- Zonas donde NO se manda a farmear: ciudades (ciudadanos y guardias) y las de la otra faccion (CLAUDE.md: "nada de la otra faccion").
-- La reaccion de Wowhead llega 0,0 en muchos bichos (dato que falta), asi que la zona manda. [1] = prohibidas a la Alliance, [2] = a la Horde
-- 9-oct (CERO datos de Classic), fuente de Forever: CIUDAD = AreaTable.csv Flags_0 con el bit 0x100 (capital); AJENA = zonas (no ciudad)
-- con FactionGroupMask del otro bando en AreaTable.csv (2 = Alliance, 4 = Horde) y, en las disputadas (0), las que en Wowhead /forever
-- (fuente/wowhead/zonas.json) tienen >= 20 misiones solo del otro bando y <= 1 del tuyo (Redridge 41/1, Wetlands 60/0).
-- Lo comprueba herramientas/pruebas/prueba-zonas-forever.mjs.
local CIUDAD = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }
local AJENA = {
  [1] = { [1411] = true, [1412] = true, [1413] = true, [1420] = true, [1421] = true },
  [2] = { [1429] = true, [1436] = true, [1426] = true, [1432] = true, [1433] = true, [1438] = true, [1439] = true, [1437] = true },
}
local function zonaPermitida(m, fac) return not CIUDAD[m] and not (AJENA[fac] and AJENA[fac][m]) end
WowF._zonaPermitidaMobs = zonaPermitida

-- Elige el area: densidad (apariciones x probabilidad de que suelte) entre la distancia. Devuelve nil + motivo si no hay.
function WowF.mejorAreaMobs(clave, opciones)
  opciones = opciones or {}
  local d = datos()
  if not d or not d.areas then return nil, "sindatos" end
  local utiles = bichosDe(clave)
  if not next(utiles) then return nil, "sindatos" end
  local N = opciones.nivel or nivelPj()
  local mia = opciones.faccion or lado()
  local rangoPiel = nil
  if clave == "piel" then rangoPiel = opciones.rango or (WowF.rangoProfesion and WowF.rangoProfesion(393)) end
  local m0, x0, y0 = opciones.mapa, opciones.x, opciones.y
  if not m0 then m0, x0, y0 = dondeEstoy() end
  local wx0, wy0, c0
  if m0 and x0 then wx0, wy0, c0 = enMundo(m0, x0, y0) end
  local mejor, mejorPunt
  for _, a in ipairs(d.areas) do
    local peso, bichos = 0, {}
    for _, c in ipairs(zonaPermitida(a[1], mia) and a[6] or {}) do
      local u, n = utiles[c[1]], d.npc[c[1]]
      if u and n then
        local reac = (mia == 2) and n[5] or n[4]
        local nivelOk = n[2] <= N + 2
        if reac <= 0 and nivelOk then
          local f = (n[3] >= N - 6) and 1 or 0.6 -- los grises tambien sueltan, pero un poco menos de prisa
          peso = peso + c[2] * u.pct / 100 * f
          table.insert(bichos, { id = c[1], nombre = n[1], min = n[2], max = n[3], veces = c[2], pct = u.pct, objs = u.objs })
        end
      end
    end
    if peso >= 1 then
      local dist, otroContinente = nil, false
      if a[1] == m0 and x0 then dist = 0 end -- en tu mapa: la distancia real la pone el mundo si se puede
      local wx, wy, c = enMundo(a[1], a[2], a[3])
      if wx and wx0 then
        if c == c0 then dist = math.sqrt((wx - wx0) ^ 2 + (wy - wy0) ^ 2) else otroContinente = true end
      end
      local punt = peso / (1 + (dist or 3000) / 400)
      if otroContinente then punt = punt / 20 end
      if not mejorPunt or punt > mejorPunt then
        table.sort(bichos, function(p, q) return p.veces * p.pct > q.veces * q.pct end)
        mejor, mejorPunt = { m = a[1], x = a[2], y = a[3], radio = a[4], zona = a[5], bichos = bichos, peso = peso, dist = dist, clave = clave, rangoPiel = rangoPiel, lejos = otroContinente }, punt
      end
    end
  end
  if not mejor then return nil, "nada" end
  return mejor
end

local function nombreClave(clave)
  if clave == "piel" then return "Skinning" end
  if clave == "tela" then return L("tela", "cloth") end
  return nombreObj(clave)
end
local function lineaBichos(a, max)
  local t = {}
  for i = 1, math.min(max or 4, #a.bichos) do
    local b = a.bichos[i]
    table.insert(t, b.nombre .. " (" .. L("nv ", "lvl ") .. (b.min == b.max and b.min or (b.min .. "-" .. b.max)) .. ")")
  end
  return table.concat(t, ", ")
end
local function queSueltan(a)
  local vistos, t = {}, {}
  for _, b in ipairs(a.bichos) do
    for id in pairs(b.objs) do if not vistos[id] then vistos[id] = true; table.insert(t, nombreObj(id)) end end
  end
  table.sort(t)
  return table.concat(t, ", ")
end
WowF._lineaBichos = lineaBichos

-- ===================== Circulo en el mapa =====================
local actual -- area marcada
local circulo
local function lienzo()
  if not WorldMapFrame or WowF.interfazMando() then return nil end -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
  if WorldMapFrame.GetCanvas then return WorldMapFrame:GetCanvas() end
  return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end
local function textoTooltip(a)
  local l = { ORO .. L("Area de bichos: ", "Mob area: ") .. nombreClave(a.clave) .. "|r" }
  table.insert(l, L("Bichos: ", "Mobs: ") .. lineaBichos(a, 6))
  table.insert(l, L("Sueltan: ", "Drop: ") .. queSueltan(a))
  table.insert(l, GRIS .. L("Mata dentro del circulo; el alfiler marca el centro. Datos de Wowhead (WoW Forever).", "Kill inside the circle; the pin marks the center. Data from Wowhead (WoW Forever).") .. "|r")
  return table.concat(l, "\n")
end
local function dibujar()
  if circulo then circulo:Hide() end
  local c = lienzo()
  if not c or not actual or not WorldMapFrame:IsShown() then return end
  local visto = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  if visto ~= actual.m then return end
  local ancho, alto = c:GetWidth(), c:GetHeight()
  if not ancho or ancho == 0 then return end
  if not circulo then
    circulo = CreateFrame("Frame", nil, c)
    circulo:SetFrameStrata("HIGH")
    pcall(function() circulo:SetFrameLevel(c:GetFrameLevel() + 5) end)
    if circulo.EnableMouse then circulo:EnableMouse(true) end
    circulo.relleno = circulo:CreateTexture(nil, "ARTWORK")
    circulo.relleno:SetAllPoints()
    circulo.relleno:SetColorTexture(0.2, 1, 0.4, 0.22)
    pcall(function()
      local mk = circulo:CreateMaskTexture()
      mk:SetAllPoints(circulo.relleno)
      mk:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      circulo.relleno:AddMaskTexture(mk)
    end)
    circulo.etiqueta = circulo:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if WowF.estilo then WowF.estilo.letra(circulo.etiqueta, "boton", 12, "OUTLINE") end -- 11-oct (hibrido): Signika con borde sobre el mapa
    circulo.etiqueta:SetPoint("CENTER", 0, 0)
    circulo:SetScript("OnEnter", function(self)
      if not GameTooltip or not actual then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(textoTooltip(actual), 1, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    circulo:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  end
  local diam = ancho * actual.radio * 2 / 100
  circulo:SetSize(diam, diam)
  circulo:ClearAllPoints()
  circulo:SetPoint("CENTER", c, "TOPLEFT", ancho * actual.x / 100, -alto * actual.y / 100)
  circulo.etiqueta:SetText(VERDE .. nombreClave(actual.clave) .. "|r")
  circulo:Show()
end
WowF.dibujarAreaMobs = dibujar
WowF.areaMobsActual = function() return actual end
WowF.circuloAreaMobs = function() return circulo end -- para las pruebas
function WowF.quitarAreaMobs()
  actual = nil
  WowFExportarDB.areaMobs = nil
  if circulo then circulo:Hide() end
end
if WorldMapFrame then
  if WorldMapFrame.OnMapChanged then pcall(hooksecurefunc, WorldMapFrame, "OnMapChanged", function() pcall(dibujar) end) end
  WorldMapFrame:HookScript("OnShow", function() pcall(dibujar) end)
end

-- Marca el area y lo explica en el chat. Devuelve el area (o nil si no hay ninguna que te sirva)
function WowF.irAreaMobs(clave, opciones)
  local a, motivo = WowF.mejorAreaMobs(clave, opciones)
  local nombre = nombreClave(clave)
  -- 6-oct (Andy: "esa notificacion es importante"): el aviso grande del centro, como en la ruta de Mining/Herbalism
  local titulo = WowF.yaTraducido(L("Ruta de farmeo: ", "Farming route: ") .. ((opciones and opciones.titulo) or nombre))
  if not a then
    local t
    if motivo == "sindatos" then
      t = L("aun no tenemos datos de bichos de Forever para " .. nombre .. ". Se actualizara en proximas actualizaciones.", "we do not have Forever mob data for " .. nombre .. " yet. This will be updated in future updates.")
    else
      t = L("no hay un area de bichos de tu nivel y tu faccion para " .. nombre .. " en los datos de Forever. Se actualizara en proximas actualizaciones.", "there is no mob area for your level and faction for " .. nombre .. " in the Forever data. This will be updated in future updates.")
    end
    print(AZUL .. NARANJA .. t .. "|r")
    if WowF.avisar then pcall(WowF.avisar, titulo, WowF.yaTraducido(NARANJA .. t .. "|r"), nil, 8, nil, { clave = "farmeo", sinChat = true }) end
    return nil
  end
  actual = a
  WowFExportarDB.areaMobs = { clave = clave }
  if WowF.marcar then pcall(WowF.marcar, { m = a.m, x = a.x, y = a.y, n = L("Area de bichos: ", "Mob area: ") .. nombre, z = a.zona, lugar = true }) end
  print(AZUL .. L("area de bichos para ", "mob area for ") .. ORO .. nombre .. "|r: " .. a.zona .. " (" .. a.x .. ", " .. a.y .. ")" .. GRIS .. L(" · circulo verde en el mapa y alfiler en el centro", " · green circle on the map and pin at the center") .. "|r")
  if a.lejos then
    print(AZUL .. NARANJA .. L("En tu continente aun no tenemos datos de bichos de tu nivel para " .. nombre .. ": esta es la mas cercana que conocemos y queda LEJOS. Se actualizara en proximas actualizaciones.", "On your continent we do not have data on mobs of your level for " .. nombre .. " yet: this is the closest one we know and it is FAR. This will be updated in future updates.") .. "|r")
  end
  print(AZUL .. L("mata: ", "kill: ") .. lineaBichos(a, 4))
  print(AZUL .. L("sueltan: ", "they drop: ") .. queSueltan(a))
  if clave == "tela" and not (opciones and opciones.humanoidesDicho) then
    print(AZUL .. GRIS .. L("La tela la sueltan los humanoides (no las bestias): mata los de la lista.", "Cloth is dropped by humanoids (not beasts): kill the ones on the list.") .. "|r")
  end
  if clave == "piel" then
    if WowF.notaSkinningUnaVez then print(AZUL .. GRIS .. WowF.notaSkinningUnaVez() .. "|r") end -- 8-oct (wowF_Legacy.lua)
    if a.rangoPiel then
      print(AZUL .. GRIS .. L("El nivel de Skinning que pide cada bicho aun no esta disponible en Forever: si uno no se deja despellejar, sigue con otro. Se actualizara en proximas actualizaciones.", "The Skinning skill each mob needs is not available in Forever yet: if one cannot be skinned, move on to another. This will be updated in future updates.") .. "|r")
    else
      print(AZUL .. GRIS .. L("Aun no tienes Skinning: aprendela con el entrenador y lleva un Skinning Knife.", "You do not have Skinning yet: learn it from the trainer and carry a Skinning Knife.") .. "|r")
    end
  end
  pcall(dibujar)
  if WowF.avisar then
    local texto = L("Mata dentro del CIRCULO VERDE del mapa (M); el alfiler marca el centro.", "Kill inside the GREEN CIRCLE on the map (M); the pin marks the center.")
      .. "\n" .. VERDE .. L("Mata: ", "Kill: ") .. lineaBichos(a, 3) .. "|r"
      .. (a.lejos and ("\n" .. NARANJA .. L("Queda LEJOS: en tu continente aun no hay datos de tu nivel.", "It is FAR: no data for your level on your continent yet.") .. "|r") or "")
      .. "\n" .. GRIS .. L("Sueltan: ", "They drop: ") .. queSueltan(a) .. "|r"
    pcall(WowF.avisar, WowF.yaTraducido(titulo .. " - " .. a.zona), WowF.yaTraducido(texto), nil, 9, nil, { clave = "farmeo", sinChat = true })
  end
  return a
end

-- Tras /reload: vuelve a marcar el area que tenias
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
  local g = WowFExportarDB.areaMobs
  if g and g.clave and not actual then
    local a = WowF.mejorAreaMobs(g.clave)
    if a then actual = a; pcall(dibujar) end
  end
end)

-- Secundarias (Cooking 185, First Aid 129): el material de bicho de la receta que mejor te sube ahora (aun no gris), con datos de Forever
function WowF.materialSecundaria(prof)
  local d = datos()
  local r = WowF.recetasSecundaria and WowF.recetasSecundaria(prof)
  if not d or not d.obj or not r then return nil end
  local R = r.rango or 0
  local function buscar(lista, soloQueSube)
    for _, e in ipairs(lista) do
      if not soloQueSube or (e.gris or 0) == 0 or R < e.gris then
        for _, m in ipairs(e.mats or {}) do if d.obj[m[1]] then return m[1], e end end
      end
    end
  end
  -- primero lo que aun te sube (de menor rango a mayor), luego lo proximo
  local ya = {}
  for _, e in ipairs(r.ya) do table.insert(ya, e) end
  table.sort(ya, function(a, b) return (a.gris or 0) < (b.gris or 0) end)
  local id, e = buscar(ya, true)
  if not id then id, e = buscar(r.prox, false) end
  if not id then id, e = buscar(ya, false) end
  return id, e
end
function WowF.areaSecundaria(prof, opciones)
  local copia = {}
  for k, v in pairs(opciones or {}) do copia[k] = v end
  opciones = copia
  local id, e = WowF.materialSecundaria(prof)
  if prof == 129 and WowF.avisoHierbaSecundaria then pcall(WowF.avisoHierbaSecundaria, 129) end -- 8-oct firstaid-alchemy: las pociones piden hierbas
  opciones.titulo = opciones.titulo or ((prof == 185 and "Cooking" or "First Aid") .. (id and (" (" .. nombreObj(id) .. ")") or ""))
  if not id then
    local nombre = prof == 185 and "Cooking" or "First Aid"
    if prof == 129 then
      print(AZUL .. L("First Aid usa tela: la sueltan los humanoides. ", "First Aid uses cloth: humanoids drop it. ") .. GRIS .. L("Buscando el area de tela...", "Looking for the cloth area...") .. "|r")
      opciones.humanoidesDicho = true
      return WowF.irAreaMobs("tela", opciones)
    end
    local t = L("aun no tenemos datos de bichos de Forever para los materiales de " .. nombre .. ". Se actualizara en proximas actualizaciones.", "we do not have Forever mob data for " .. nombre .. " materials yet. This will be updated in future updates.")
    print(AZUL .. NARANJA .. t .. "|r")
    if WowF.avisar then pcall(WowF.avisar, WowF.yaTraducido(L("Ruta de farmeo: ", "Farming route: ") .. nombre), WowF.yaTraducido(NARANJA .. t .. "|r"), nil, 8, nil, { clave = "farmeo", sinChat = true }) end
    return nil
  end
  print(AZUL .. L("para ", "for ") .. ORO .. nombreObj(e.id) .. "|r" .. L(" necesitas ", " you need ") .. nombreObj(id) .. ".")
  return WowF.irAreaMobs(id, opciones)
end
