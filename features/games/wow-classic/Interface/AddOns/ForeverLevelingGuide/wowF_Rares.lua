-- Forever Leveling Guide (4.48, Andy 18-oct: "integrar donde salen los rares y su drop"): rares de WoW Forever.
--   Mapa: calavera en cada sitio donde sale un rare del mapa que miras (color = dificultad para tu nivel; elite = mas grande).
--         Al pasar el raton: nombre, nivel y lo que suelta con su % en Forever.
--   Tooltip del bicho: "Forever Guide: RARE" y lo que suelta.  Placa: aviso cuando aparece uno cerca (una vez cada 10 min).
--   /wowf rares (lista de tu zona) · /wowf rares on|off · casillas en Ajustes.
-- Datos: WowFRares (wowF_Rares_Datos.lua, generado por herramientas/generar-rares.mjs, solo Wowhead /forever, temporada de Forever).
-- Faccion: nada de la otra (bichos amistosos para ti fuera, zonas de la otra faccion y ciudades fuera, como en wowF_AreaMobs.lua).

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local AZUL, GRIS, NARANJA, ORO = "|cff66ccffForever Guide:|r ", "|cff999999", "|cffff9933", "|cffffd100"
local CALIDAD = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }
local POCAS = 20 -- con menos muertes registradas en Forever el % es aproximado

local function seguro(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end
local function lista() return WowFRares and WowFRares.r or {} end
local function nivelPj() return (UnitLevel and UnitLevel("player")) or 1 end
local function lado() local f = UnitFactionGroup and UnitFactionGroup("player"); return f == "Horde" and 2 or (f == "Alliance" and 1 or 0) end
local function encendido(clave) return WowFExportarDB[clave] ~= false end

-- Un rare te sirve si no es amistoso para tu faccion y su mapa no es ciudad ni de la otra faccion
local function teSirve(r, m, fac)
  fac = fac or lado()
  local reac = (fac == 2) and r.rh or r.ra
  if (reac or 0) > 0 then return false end
  if m and WowF._zonaPermitidaMobs and not WowF._zonaPermitidaMobs(m, fac) then return false end
  return true
end
WowF._rareTeSirve = teSirve

-- Rares por mapa (se arma una vez): [uiMap] = { { id, rare, { {x, y}, ... } }, ... }
local porMapa
local function indice()
  if porMapa then return porMapa end
  porMapa = {}
  for id, r in pairs(lista()) do
    local enMapa = {}
    for _, p in ipairs(r.p or {}) do
      local e = enMapa[p[1]]
      if not e then e = { id = id, r = r, puntos = {} }; enMapa[p[1]] = e; porMapa[p[1]] = porMapa[p[1]] or {}; table.insert(porMapa[p[1]], e) end
      table.insert(e.puntos, { p[2], p[3] })
    end
  end
  for _, l in pairs(porMapa) do table.sort(l, function(a, b) return (a.r.a or 0) < (b.r.a or 0) end) end
  return porMapa
end
function WowF.raresDelMapa(m, fac)
  local t = {}
  for _, e in ipairs(indice()[m] or {}) do if teSirve(e.r, m, fac) then table.insert(t, e) end end
  return t
end

local function textoNivel(r)
  if (r.a or 0) <= 0 then return L("nivel sin confirmar", "level not confirmed") .. (r.e and " elite" or "") end -- 19-oct: Wowhead sin nivel (a = 0)
  local n =(r.a == r.b or not r.b or r.b == 0) and tostring(r.a) or (r.a .. "-" .. r.b)
  return L("nv ", "lvl ") .. n .. (r.e and L(" elite", " elite") or "")
end
-- Color por dificultad para tu nivel (el del cliente si existe)
local function color(r)
  if (r.a or 0) <= 0 then return 0.9, 0.9, 0.9 end -- 19-oct: nivel sin confirmar
  local nv = r.a or 1
  if GetQuestDifficultyColor then
    local ok, c = pcall(GetQuestDifficultyColor, nv)
    if ok and type(c) == "table" and c.r then return c.r, c.g, c.b end
  end
  local d = nv - nivelPj()
  if d >= 5 then return 1, 0.1, 0.1 elseif d >= 3 then return 1, 0.5, 0.25 elseif d >= -2 then return 1, 1, 0 elseif d >= -7 then return 0.25, 0.75, 0.25 end
  return 0.5, 0.5, 0.5
end
local function lineaDrop(o)
  local nombre = (CALIDAD[o[3]] or "|cffffffff") .. o[2] .. "|r"
  local pct = o[4] >= 10 and math.floor(o[4] + 0.5) or (math.floor(o[4] * 10 + 0.5) / 10)
  return nombre .. GRIS .. " " .. pct .. L(" % de probabilidad al matarlo", " % chance per kill") .. ((o[5] or 0) < POCAS and L(" (aprox., pocas muestras)", " (approx., few samples)") or "") .. "|r"
end
local function lineasDrops(r)
  local t = {}
  for _, o in ipairs(r.d or {}) do table.insert(t, lineaDrop(o)) end
  if #t == 0 then table.insert(t, NARANJA .. L("Aún no hay datos de WoW Forever de lo que suelta; se actualizará en próximas actualizaciones.", "No WoW Forever data on its drops yet; this will be updated in future updates.") .. "|r") end
  return t
end
WowF._lineasDropsRare = lineasDrops

-- ===================== Mapa =====================
local marcas, capa = {}, nil
local function lienzo()
  if not WorldMapFrame or WowF.interfazMando() then return nil end -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
  if WorldMapFrame.GetCanvas then return WorldMapFrame:GetCanvas() end
  return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end
local function alEntrar(self)
  if not GameTooltip or not self.rare then return end
  local r = self.rare
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(WowF.yaTraducido and WowF.yaTraducido(r.n) or r.n, 1, 0.82, 0)
  GameTooltip:AddLine("RARE " .. textoNivel(r), color(r))
  for _, t in ipairs(lineasDrops(r)) do GameTooltip:AddLine(t, 1, 1, 1, true) end
  GameTooltip:AddLine(GRIS .. L("Sale en uno de estos puntos. Datos de Wowhead (WoW Forever).", "Spawns at one of these spots. Data from Wowhead (WoW Forever).") .. "|r", 1, 1, 1, true)
  if self.elegido then GameTooltip:AddLine(L("Lo marcaste tú (pestaña Rares). Limpiar mapa lo quita.", "You marked it (Rares tab). Clear map removes it."), 1, 0.82, 0, true) end
  GameTooltip:Show()
end
local function marca(i, c)
  local f = marcas[i]
  if f then return f end
  f = CreateFrame("Frame", nil, c)
  f:SetFrameStrata("HIGH")
  pcall(function() f:SetFrameLevel(c:GetFrameLevel() + 6) end)
  if f.EnableMouse then f:EnableMouse(true) end
  f.icono = f:CreateTexture(nil, "OVERLAY")
  f.icono:SetAllPoints()
  f.icono:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
  -- 19-oct: halo dorado detras del rare marcado desde la pestana Rares
  f.brillo = f:CreateTexture(nil, "BACKGROUND")
  f.brillo:SetPoint("CENTER")
  f.brillo:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  if f.brillo.SetBlendMode then f.brillo:SetBlendMode("ADD") end
  f.brillo:SetVertexColor(1, 0.82, 0)
  f.brillo:Hide()
  f:SetScript("OnEnter", alEntrar)
  f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  marcas[i] = f
  return f
end
local function ocultar() for _, f in pairs(marcas) do f:Hide() end end
local function mapaPj()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
  return ok and m or nil
end
-- 19-oct (Andy: "que se muestren en la zona que tu estas nada mas" + "marcalo en el mapa... y que no muestre nada mas"):
-- el rare marcado desde la pestana Rares se guarda en WowFExportarDB.rareElegido = { id, m } y se ve SIEMPRE (resaltado),
-- aunque las calaveras de zona esten apagadas. Lo quitan "Quitar del mapa", marcar otro y Limpiar mapa (WowF.limpiarRutas).
function WowF.rareElegido()
  local el = WowFExportarDB and WowFExportarDB.rareElegido
  if type(el) ~= "table" or not el.id or not el.m then return nil end
  for _, e in ipairs(indice()[el.m] or {}) do if e.id == el.id then return e, el.m end end
  return nil
end
local dibujar
function WowF.quitarRareElegido()
  if WowFExportarDB then WowFExportarDB.rareElegido = nil end
  if dibujar then pcall(dibujar) end
end
dibujar = function()
  ocultar()
  local c = lienzo()
  if not c or not WorldMapFrame:IsShown() then return end
  local m = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  if not m then return end
  local ancho, alto = c:GetWidth(), c:GetHeight()
  if not ancho or ancho == 0 then return end
  local escala = ancho / 1000 -- el lienzo crece con el zoom: la calavera se ve igual
  local tam = WowF.opciones and WowF.opciones().raresTam or 1 -- 19-oct: deslizador de Ajustes > Mapa
  local elegido, mElegido = WowF.rareElegido()
  local ver = {}
  -- Calaveras de zona: solo en el mapa de la zona donde estas (ni otras zonas ni el continente)
  if encendido("raresMapa") and m == mapaPj() then
    for _, e in ipairs(WowF.raresDelMapa(m)) do if not (elegido and e.id == elegido.id) then table.insert(ver, e) end end
  end
  if elegido and mElegido == m then table.insert(ver, elegido) end
  local i = 0
  for _, e in ipairs(ver) do
    local resaltado = elegido ~= nil and e.id == elegido.id
    local lado_ = (e.r.e and 20 or 16) * math.max(escala, 0.5) * tam * (resaltado and 1.4 or 1)
    for _, p in ipairs(e.puntos) do
      i = i + 1
      local f = marca(i, c)
      f.rare = e.r
      f.elegido = resaltado or nil
      f:SetSize(lado_, lado_)
      f.brillo:SetSize(lado_ * 2.2, lado_ * 2.2)
      if resaltado then f.brillo:Show() else f.brillo:Hide() end
      f.icono:SetVertexColor(color(e.r))
      f:ClearAllPoints()
      f:SetPoint("CENTER", c, "TOPLEFT", ancho * p[1] / 100, -alto * p[2] / 100)
      f:Show()
    end
  end
  return i
end
WowF.dibujarRares = dibujar
WowF._marcasRares = function() return marcas end -- para las pruebas
if WorldMapFrame then
  if WorldMapFrame.OnMapChanged then pcall(hooksecurefunc, WorldMapFrame, "OnMapChanged", function() pcall(dibujar) end) end
  WorldMapFrame:HookScript("OnShow", function() pcall(dibujar) end)
end

-- 19-oct: boton "Rares" abajo del mapa, al lado del de entrenadores. Brasa = se ven; cuero = ocultos.
-- Clic: mostrar u ocultar · clic derecho: Ajustes > Mapa (tamano de las calaveras, aviso y tooltip)
local botonMapa
local CALAVERA = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:14:14|t "
function WowF.refrescarBotonRares()
  if not botonMapa then return end
  local si = encendido("raresMapa")
  botonMapa:SetText(CALAVERA .. (si and L("Rares de tu zona: sí", "Rares in your zone: on") or L("Rares de tu zona: no", "Rares in your zone: off")))
  if WowF.estilo then WowF.estilo.boton(botonMapa, si and "brasa" or "cuero") end
end
local function ayudaBoton(self)
  if not GameTooltip then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:SetText("Forever Guide", 0.2, 1, 0.6)
  GameTooltip:AddLine(L("Calaveras de los rares de la zona donde estás: dónde salen y qué sueltan. Al mirar otras zonas no se muestra nada.",
    "Skulls for the rares in the zone you are in: where they spawn and what they drop. Nothing shows when you look at other zones."), 1, 1, 1, true)
  GameTooltip:AddLine(L("El rare que marques en la pestaña Rares (Plan completo) se ve siempre, con halo dorado y su ruta.",
    "The rare you mark in the Rares tab (Full plan) always shows, with a golden glow and its route."), 1, 0.82, 0, true)
  GameTooltip:AddLine(L("Clic: mostrar u ocultar", "Click: show or hide"), 0.2, 1, 0.4)
  GameTooltip:AddLine(L("Clic derecho: tamaño y más ajustes", "Right-click: size and more settings"), 0.2, 1, 0.4)
  GameTooltip:Show()
end
local function crearBotonMapa()
  if botonMapa or not WorldMapFrame or not WowF.estilo or WowF.interfazMando() then return botonMapa end -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
  botonMapa = CreateFrame("Button", nil, WorldMapFrame, "UIPanelButtonTemplate")
  WowF.estilo.boton(botonMapa, "cuero")
  botonMapa:SetSize(170, 20)
  botonMapa:SetPoint("BOTTOMLEFT", WorldMapFrame.ScrollContainer or WorldMapFrame, "BOTTOMLEFT", 202, 6) -- el de entrenadores: 6 + 190
  if botonMapa.SetFrameStrata then botonMapa:SetFrameStrata("HIGH") end
  if botonMapa.RegisterForClicks then botonMapa:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  botonMapa:SetScript("OnClick", function(self, tecla)
    if tecla == "RightButton" then
      if WowF.abrirOpcionesEn then pcall(WowF.abrirOpcionesEn, "mapa") end
      return
    end
    WowFExportarDB.raresMapa = not encendido("raresMapa")
    pcall(dibujar)
    WowF.refrescarBotonRares()
    if WowF.refrescarOpciones then pcall(WowF.refrescarOpciones) end
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then ayudaBoton(self) end
  end)
  botonMapa:SetScript("OnEnter", ayudaBoton)
  botonMapa:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  WorldMapFrame:HookScript("OnShow", WowF.refrescarBotonRares)
  WowF.refrescarBotonRares()
  return botonMapa
end
pcall(crearBotonMapa)
WowF._botonRaresMapa = function() pcall(crearBotonMapa); return botonMapa end -- para las pruebas

-- ===================== Tooltip del bicho =====================
local function idDe(unidad)
  if not UnitExists or not UnitExists(unidad) then return nil end
  local ok, guid = pcall(UnitGUID, unidad)
  guid = ok and seguro(guid)
  if type(guid) ~= "string" then return nil end
  local tipo, _, _, _, _, id = strsplit("-", guid)
  if tipo ~= "Creature" then return nil end
  return tonumber(id)
end
WowF._idRareDe = idDe
local function lineaTooltip(tt)
  if not encendido("raresTooltip") or not tt or not tt.GetUnit then return end
  local ok, _, unidad = pcall(tt.GetUnit, tt)
  if not ok or not unidad then return end
  local id = idDe(unidad)
  local r = id and lista()[id]
  if not r then return end
  tt:AddLine(WowF.T and WowF.T("Forever Guide: RARE") or "Forever Guide: RARE", 1, 0.82, 0)
  for _, t in ipairs(lineasDrops(r)) do tt:AddLine(t, 1, 1, 1, true) end
  tt:Show()
end
WowF._lineaTooltipRare = lineaTooltip
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tt) pcall(lineaTooltip, tt) end)
elseif GameTooltip and GameTooltip.HookScript then
  pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tt) pcall(lineaTooltip, tt) end)
end

-- ===================== Aviso al ver su placa =====================
local avisado = {}
local function alAparecer(unidad)
  if not encendido("raresAviso") then return end
  local id = idDe(unidad)
  local r = id and lista()[id]
  if not r then return end
  local ok, muerto = pcall(UnitIsDead, unidad)
  if ok and seguro(muerto) == true then return end
  local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not teSirve(r, m) then return end
  local ahora = GetTime and GetTime() or 0
  if avisado[id] and ahora - avisado[id] < 600 then return end
  avisado[id] = ahora
  local nombre = WowF.yaTraducido and WowF.yaTraducido(r.n) or r.n
  local t = lineasDrops(r)
  print(AZUL .. ORO .. L("RARE cerca: ", "RARE nearby: ") .. nombre .. "|r (" .. textoNivel(r) .. ") " .. GRIS .. L("suelta: ", "drops: ") .. "|r" .. table.concat(t, ", "))
  if WowF.avisar then
    pcall(WowF.avisar, L("RARE cerca: ", "RARE nearby: ") .. nombre, textoNivel(r) .. "\n" .. table.concat(t, "\n"), nil, 7, nil, { clave = "rare", sinChat = true })
  end
  if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound, SOUNDKIT.RAID_WARNING) end
  return true
end
WowF._alAparecerRare = alAparecer
local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "NAME_PLATE_UNIT_ADDED")
ev:SetScript("OnEvent", function(_, _, unidad) pcall(alAparecer, unidad) end)

-- ===================== Lista, ajustes y comando =====================
function WowF.listaRares()
  local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local t = m and WowF.raresDelMapa(m) or {}
  if #t == 0 then
    print(AZUL .. NARANJA .. L("aún no hay datos de rares de WoW Forever en esta zona; se actualizará en próximas actualizaciones.", "no WoW Forever rare data for this zone yet; this will be updated in future updates.") .. "|r")
    return 0
  end
  print(AZUL .. L("rares de esta zona (calaveras en el mapa, M):", "rares in this zone (skulls on the map, M):"))
  for _, e in ipairs(t) do
    local p = e.puntos[1]
    print("  " .. ORO .. (WowF.yaTraducido and WowF.yaTraducido(e.r.n) or e.r.n) .. "|r " .. GRIS .. "(" .. textoNivel(e.r) .. ", " .. p[1] .. ", " .. p[2] .. ")|r " .. table.concat(lineasDrops(e.r), ", "))
  end
  return #t
end
if WowF.registrarCasillaOpciones then
  -- 19-oct: "raresMapa" ya no es casilla: lo cambian los botones Mostrar/Ocultar de Ajustes > Mapa y el boton Rares del mapa
  WowF.registrarCasillaOpciones("raresAviso", function() return L("Rares: aviso cuando aparece uno cerca", "Rares: alert when one shows up nearby") end)
  WowF.registrarCasillaOpciones("raresTooltip", function() return L("Rares: lo que suelta en el tooltip del bicho", "Rares: their drops in the mob tooltip") end)
end
local ordenAnterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje, ...)
  local m = strtrim and strtrim(mensaje or "") or (mensaje or "")
  local orden, resto = m:match("^(%S+)%s*(.-)$")
  if orden and orden:lower() == "rares" then
    local a = (resto or ""):lower()
    if a == "on" or a == "off" then
      local v = a == "on"
      WowFExportarDB.raresMapa, WowFExportarDB.raresAviso, WowFExportarDB.raresTooltip = v, v, v
      pcall(dibujar)
      WowF.refrescarBotonRares()
      if WowF.refrescarOpciones then pcall(WowF.refrescarOpciones) end
      print(AZUL .. (v and L("rares encendidos (mapa, aviso y tooltip).", "rares on (map, alert and tooltip).") or L("rares apagados. Vuelve con /wowf rares on.", "rares off. Turn them back on with /wowf rares on.")))
    else
      WowF.listaRares()
    end
    return
  end
  if ordenAnterior then return ordenAnterior(mensaje, ...) end
end
