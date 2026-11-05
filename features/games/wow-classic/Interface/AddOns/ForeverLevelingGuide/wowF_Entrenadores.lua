-- wowF Entrenadores: los entrenadores de profesiones en el mapa del mundo (M), con el icono de cada profesion.
-- Se ven los de tu faccion en el mapa que estes mirando (ciudad, pueblo o zona). Pasa el raton: quien es y hasta que rango
-- ensena; clic: alfiler para ir. Los de tus profesiones (y las recomendadas para tu objetivo) se ven mas grandes.
-- /wowf entrenadores: lista los de la zona donde estas y elige que iconos salen en el mapa.
-- 6-oct (idea de molotov47k en CurseForge): tres modos, en WowFExportarDB.entrenadoresModo:
--   "mias" (por defecto) = solo tus profesiones (y la que te recomienda el plan si aun te falta una principal),
--   "todas" = todos los entrenadores, "ninguna" = sin iconos. Se cambia en Ajustes, con el boton del mapa o con
--   /wowf entrenadores mias|todas|ninguna. El entrenador que eliges en el libro (paso 1) sale siempre, aunque no sea de las tuyas.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local AZUL = "|cff33ccffForever Guide|r: "
local ORO, VERDE, GRIS = "|cffffd100", "|cff33ff66", "|cff999999"
local ICONO = {
  [171] = "Interface\\Icons\\Trade_Alchemy", [164] = "Interface\\Icons\\Trade_BlackSmithing", [165] = "Interface\\Icons\\Trade_LeatherWorking",
  [197] = "Interface\\Icons\\Trade_Tailoring", [202] = "Interface\\Icons\\Trade_Engineering", [333] = "Interface\\Icons\\Trade_Engraving",
  [186] = "Interface\\Icons\\Trade_Mining", [182] = "Interface\\Icons\\Trade_Herbalism", [393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
  [129] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", [185] = "Interface\\Icons\\INV_Misc_Food_15",
}
local ORDEN = { 171, 164, 165, 197, 202, 333, 186, 182, 393, 129, 185 }
WowF.ICONO_PROF = ICONO

-- Hasta que rango ensena (la habilidad mas alta de lo que ensena)
local function rangoMax(h)
  if h > 225 then return "Artisan" elseif h > 150 then return "Expert" elseif h > 75 then return "Journeyman" end
  return "Apprentice"
end
WowF.rangoEntrenador = rangoMax

local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
-- 5-oct: calidad del dato de cada entrenador (8.o campo de WowFDatos.entrenadores/entrenadoresClase, de generar-plan-addon.js):
-- 1 = exacta (posicion de Wowhead /forever), 0 = aproximada (posicion de Classic/MTSL, sin confirmar en Forever).
-- 9-oct (regla de Andy: CERO datos de Classic): la posicion aproximada NO se muestra: sin icono en el mapa ni alfiler. En su lugar
-- "Posicion de X aun no disponible en WoW Forever; se actualizara" y, si lo hay, otro entrenador verificado de tu faccion.
function WowF.esAproximado(e) return type(e) == "table" and e[8] == 0 end
function WowF.textoSinPosicion(nombre)
  nombre = tostring(nombre or "")
  local s = L("Posición de " .. nombre .. " aún no disponible en WoW Forever; se actualizará.",
    "Position of " .. nombre .. " not yet available in WoW Forever; it will be updated.")
  return WowF.yaTraducido and WowF.yaTraducido(s) or s
end
function WowF.textoAprox()
  local s = L("Posición aún no disponible en WoW Forever; se actualizará.", "Position not yet available in WoW Forever; it will be updated.")
  return WowF.yaTraducido and WowF.yaTraducido(s) or s
end

local function miFac() return (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A" end

-- Stormwind City (1453) y Eastern Plaguelands (1423): Forever usa el mapa redibujado de Wrath y los datos (MTSL y Wowhead, que
-- copian Classic) traen coordenadas de Classic, ~200 yardas desviadas (https://github.com/RestedXP/RXPGuides/issues/385).
-- Se pasan al cargar con los rectangulos del mundo de la tabla UiMapAssignment del cliente (wago.tools, builds 1.15.9.70003 y
-- 1.60.1.70205; igual que herramientas/coordenadas-forever.mjs). Comprobado: Ardwyn Cailen 42.8, 65.4 -> 52.8, 75.0 (juego: 52.8, 75.2).
-- Solo cambia x/y de cada NPC en su mapa: la faccion de cada entrenador no se toca.
local RECT = { -- minX, minY, maxX, maxY: classic, forever
  [1453] = { { -9175.20508, 36.70063, -8278.85059, 1380.97144 }, { -9154.16992, -14.584, -7995.83008, 1722.92004 } },
  [1423] = { { 1218.75, -6056.25, 3799.99976, -2185.4165 }, { 825, -6558.33398, 3691.66699, -2256.25 } },
}
function WowF.aForever(mapa, x, y)
  local r = RECT[mapa]
  if not r or not x or not y then return x, y end
  local a, c = r[1], r[2]
  local wY, wX = a[4] - (x / 100) * (a[4] - a[2]), a[3] - (y / 100) * (a[3] - a[1])
  local function r1(v) return math.floor(v * 10 + 0.5) / 10 end
  return r1((c[4] - wY) / (c[4] - c[2]) * 100), r1((c[3] - wX) / (c[3] - c[1]) * 100)
end
local function pasarAForever(tabla)
  local n = 0
  for _, lista in pairs(tabla or {}) do
    for _, e in pairs(lista) do
      if type(e) == "table" and RECT[e[2]] then e[3], e[4] = WowF.aForever(e[2], e[3], e[4]); n = n + 1 end
    end
  end
  return n
end
if WowFDatos and not WowFDatos.coordsForever then
  WowF.entrenadoresPasados = pasarAForever(WowFDatos.entrenadores) + pasarAForever(WowFDatos.entrenadoresClase)
  WowFDatos.coordsForever = true -- nunca dos veces
end

-- Entrenadores de tu faccion en un mapa: { { prof, nombreProf, e } } (e = { nombre, mapa, x, y, fac, habilidad, zona })
-- 9-oct: sin los de posicion aproximada (Classic), salvo conSinPosicion = true (solo para decir que aun no hay posicion)
function WowF.entrenadoresEn(mapa, conSinPosicion)
  local res = {}
  local D = WowFDatos
  if not mapa or not D or not D.entrenadores then return res end
  local fac = miFac()
  for _, id in ipairs(ORDEN) do
    for _, e in ipairs(D.entrenadores[id] or {}) do
      if e[2] == mapa and (e[5] == fac or e[5] == "N") and (conSinPosicion or not WowF.esAproximado(e)) then table.insert(res, { prof = id, nombre = (D.prof and D.prof[id]) or tostring(id), e = e }) end
    end
  end
  return res
end
function WowF.mapaActual()
  local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local info = m and C_Map.GetMapInfo and C_Map.GetMapInfo(m)
  return m, (info and info.name) or ""
end
-- 9-oct: otro entrenador de la misma profesion, de tu faccion y con posicion verificada en Forever (el de tu mapa primero),
-- que ensene al menos hasta donde ensenaba el que no tiene posicion
function WowF.otroEntrenadorVerificado(e, prof)
  local D = WowFDatos
  if not (D and D.entrenadores and type(e) == "table") then return nil end
  local id
  for k, lista in pairs(D.entrenadores) do
    for _, x in ipairs(lista) do if x == e then id = k end end
  end
  if not id and D.prof then for k, v in pairs(D.prof) do if v == prof then id = k end end end
  if not id then return nil end
  local fac, aqui = miFac(), WowF.mapaActual()
  local primero, local1
  for _, x in ipairs(D.entrenadores[id] or {}) do
    if x ~= e and not WowF.esAproximado(x) and (x[5] == fac or x[5] == "N") and (tonumber(x[6]) or 0) >= (tonumber(e[6]) or 0) then
      primero = primero or x
      if x[2] == aqui then local1 = local1 or x end
    end
  end
  return local1 or primero
end
function WowF.marcarEntrenador(e, prof)
  -- 9-oct: sin posicion de Forever = sin alfiler; se dice y, si lo hay, se marca otro verificado
  if WowF.esAproximado(e) then
    print(AZUL .. ORO .. WowF.textoSinPosicion(e[1]) .. "|r")
    local otro = WowF.otroEntrenadorVerificado(e, prof)
    if not otro then return nil end
    print(AZUL .. L("te marco otro entrenador de " .. tostring(prof) .. " de tu faccion: ", "marking another " .. tostring(prof) .. " trainer of your faction: ") .. ORO .. otro[1] .. "|r" .. GRIS .. " (" .. tostring(otro[7] or "") .. ")|r")
    e = otro
  end
  -- 4-oct: una sola ruta a la vez: ir al entrenador quita la ruta a la mazmorra y la de farmeo
  if e and WowF.limpiarRutas then pcall(WowF.limpiarRutas, true) end
  -- 13-oct (Andy): como el de clase, con ruta y flecha (wowF_Viaje); sin ruta, solo el alfiler
  local hecho = false
  if e and WowF.viajeA then
    local quien = ORO .. e[1] .. "|r" .. GRIS .. L(" (entrenador de " .. tostring(prof) .. ")", " (" .. tostring(prof) .. " trainer)") .. "|r"
    local destino = { n = e[1], m = e[2], x = e[3], y = e[4], z = e[7], lugar = true, final = {
      titulo = e[1], ventana = ORO .. L("Entrenador de ", "") .. tostring(prof) .. L("", " trainer") .. "|r",
      texto = L("Habla con ", "Talk to ") .. quien .. L(" para aprender " .. tostring(prof), " to learn " .. tostring(prof)),
      llegada = L("habla con ", "talk to ") .. quien .. L(" para aprender " .. tostring(prof) .. ".", " to learn " .. tostring(prof) .. ".") } }
    destino.retrato = { nombre = e[1], unidad = "target" }
    local ok, r = pcall(WowF.viajeA, destino, { dibujar = true })
    hecho = ok and r
  end
  if e and not hecho and WowF.marcar then WowF.marcar({ m = e[2], x = e[3], y = e[4], n = e[1] .. " (entrenador de " .. prof .. ")", z = e[7], lugar = true, aprox = WowF.esAproximado(e) }) end
  WowF.entrenadorElegido = e
  if WowF.dibujarEntrenadores then pcall(WowF.dibujarEntrenadores) end
  return e
end
-- Desde el libro: alfiler y abre el mapa en ese sitio, con el entrenador resaltado en dorado
function WowF.verEntrenador(e, prof)
  e = WowF.marcarEntrenador(e, prof)
  if e and WorldMapFrame and not WowF.interfazMando() then -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
    pcall(function()
      if not WorldMapFrame:IsShown() then
        if ShowUIPanel then ShowUIPanel(WorldMapFrame) else WorldMapFrame:Show() end
      end
      if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(e[2]) end
    end)
    pcall(WowF.dibujarEntrenadores)
  end
end

-- Las tuyas: profesiones que tienes y las recomendadas para tu objetivo (se dibujan mas grandes)
local function importantes()
  local imp = {}
  local p = WowF.armarPlan and select(2, pcall(WowF.armarPlan))
  if type(p) == "table" then
    for _, id in ipairs(p.ids or {}) do imp[id] = true end
    for _, id in ipairs(p.recomendadas or {}) do imp[id] = true end
  end
  return imp
end

-- ----- Iconos en el mapa del mundo -----
local pines = {}
-- ----- Modo: que entrenadores salen -----
function WowF.modoEntrenadores()
  local m = WowFExportarDB.entrenadoresModo
  if m == nil and WowFExportarDB.entrenadoresMapa == false then m = "ninguna" end -- lo de antes: /wowf entrenadores off
  if m ~= "todas" and m ~= "ninguna" then m = "mias" end
  return m
end
function WowF.textoModoEntrenadores(m)
  m = m or WowF.modoEntrenadores()
  if m == "todas" then return L("Entrenadores: todos", "Trainers: all")
  elseif m == "ninguna" then return L("Entrenadores: ninguno", "Trainers: none") end
  return L("Entrenadores: mis profesiones", "Trainers: my professions")
end
local botonMapa
local function refrescarBoton()
  if botonMapa then botonMapa:SetText(WowF.textoModoEntrenadores()) end
end
function WowF.ponerModoEntrenadores(m)
  if m ~= "todas" and m ~= "ninguna" then m = "mias" end
  WowFExportarDB.entrenadoresModo = m
  WowFExportarDB.entrenadoresMapa = nil
  refrescarBoton()
  if WowF.dibujarEntrenadores then pcall(WowF.dibujarEntrenadores) end
  return m
end
function WowF.siguienteModoEntrenadores()
  local sig = { mias = "todas", todas = "ninguna", ninguna = "mias" }
  return WowF.ponerModoEntrenadores(sig[WowF.modoEntrenadores()])
end
-- Tus profesiones (todas, tambien Cooking y First Aid) + las que el plan te pone para completar dos principales
local function misProfesionesMapa()
  local mias = {}
  local p = WowF.armarPlan and select(2, pcall(WowF.armarPlan))
  if type(p) == "table" then for _, id in ipairs(p.ids or {}) do mias[id] = true end end
  if WowF.profesiones then
    local ok, l = pcall(WowF.profesiones)
    if ok and type(l) == "table" then for _, x in ipairs(l) do if x.id then mias[x.id] = true end end end
  end
  return mias
end
local function lienzo()
  if not WorldMapFrame or WowF.interfazMando() then return nil end -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
  if WorldMapFrame.GetCanvas then return WorldMapFrame:GetCanvas() end
  return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end
local function dibujar()
  for _, p in pairs(pines) do p:Hide() end
  local modo = WowF.modoEntrenadores()
  if modo == "ninguna" then return end
  local c = lienzo()
  if not c or not WorldMapFrame:IsShown() then return end
  local visto = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  local lista = WowF.entrenadoresEn(visto)
  local elegido = WowF.entrenadorElegido
  if modo == "mias" then
    local mias, quedan = misProfesionesMapa(), {}
    for _, t in ipairs(lista) do
      if mias[t.prof] or (elegido and elegido[1] == t.e[1] and elegido[2] == t.e[2]) then quedan[#quedan + 1] = t end
    end
    lista = quedan
  end
  if #lista == 0 then return end
  local ancho, alto = c:GetWidth(), c:GetHeight()
  if not ancho or ancho == 0 then return end
  local imp = importantes()
  -- Tamano fijo EN PANTALLA (el lienzo del mapa se escala con el zoom): el icono se ve siempre igual de nitido, como en el libro.
  -- Sin mascara redonda: en este cliente deformaba el icono (se veia rayado, captura de Andy del 3-oct).
  local escala = 1
  pcall(function() escala = c:GetEffectiveScale() / UIParent:GetEffectiveScale() end)
  if not escala or escala <= 0 then escala = 1 end
  local px = 1 / escala -- un pixel de pantalla en unidades del lienzo
  local tam = 13 * px -- 4-oct: 13 px, 16 el elegido (Andy: "se ven muy grandes")
  -- 13-oct (comentario 8537474 de CurseForge: "a bit chunky"): tamano y opacidad elegibles en Ajustes (WowFExportarDB.opciones)
  local op = WowF.opciones and WowF.opciones() or {}
  tam = tam * (tonumber(op.iconoTam) or 1)
  local alfaPin = tonumber(op.iconoAlfa) or 1
  for i, t in ipairs(lista) do
    local pin = pines[i]
    if not pin then
      -- Punto exacto (donde va el alfiler) y, colgando debajo, el icono cuadrado de la profesion con borde
      pin = CreateFrame("Button", nil, c)
      pin:SetFrameStrata("HIGH")
      pin.punto = pin:CreateTexture(nil, "OVERLAY")
      pin.aro = pin:CreateTexture(nil, "BACKGROUND")
      pin.negro = pin:CreateTexture(nil, "BORDER")
      pin.icono = pin:CreateTexture(nil, "ARTWORK")
      pin.icono:SetAllPoints()
      pin.icono:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      pin:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local e = self.datos.e
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(WowF.T(e[1]), 1, 1, 1)
        GameTooltip:AddLine(WowF.T("Entrenador de " .. self.datos.nombre .. " (ensena hasta " .. rangoMax(e[6]) .. ")"), 1, 0.82, 0)
        GameTooltip:AddLine(WowF.T(e[7] .. " " .. e[3] .. ", " .. e[4]), 0.6, 0.6, 0.6)
        if WowF.esAproximado(e) then GameTooltip:AddLine(WowF.textoAprox(), 0.6, 0.6, 0.6, true) end
        GameTooltip:AddLine(WowF.T("Clic: alfiler para ir"), 0.2, 1, 0.4)
        GameTooltip:Show()
      end)
      pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
      pin:SetScript("OnClick", function(self) WowF.marcarEntrenador(self.datos.e, self.datos.nombre) end)
      pines[i] = pin
    end
    pin.datos = t
    local grande = imp[t.prof]
    local este = elegido and elegido[1] == t.e[1] and elegido[2] == t.e[2]
    local s = este and tam * 1.25 or tam
    pin:SetSize(s, s)
    pin:ClearAllPoints()
    -- Borde: 1 px negro pegado al icono y, por fuera, 2 px de color (dorado = el elegido, verde = tus profesiones, gris = el resto)
    local b = (este or grande) and 2 * px or px
    pin.negro:ClearAllPoints(); pin.negro:SetPoint("TOPLEFT", -px, px); pin.negro:SetPoint("BOTTOMRIGHT", px, -px)
    pin.aro:ClearAllPoints(); pin.aro:SetPoint("TOPLEFT", -px - b, px + b); pin.aro:SetPoint("BOTTOMRIGHT", px + b, -px - b)
    pin.negro:SetColorTexture(0, 0, 0, 1)
    -- El punto queda justo en la coordenada; el icono, debajo (asi el alfiler del juego no lo tapa)
    local d = 4 * px
    pin.punto:ClearAllPoints(); pin.punto:SetSize(d, d); pin.punto:SetPoint("BOTTOM", pin, "TOP", 0, px + b)
    pin:SetPoint("TOP", c, "TOPLEFT", ancho * t.e[3] / 100, -alto * t.e[4] / 100 - d - px - b)
    pin.icono:SetTexture(ICONO[t.prof] or "Interface\\Icons\\INV_Misc_Gear_01")
    if este then pin.aro:SetColorTexture(1, 0.82, 0, 1); pin.punto:SetColorTexture(1, 0.82, 0, 1)
    elseif grande then pin.aro:SetColorTexture(0.2, 1, 0.4, 1); pin.punto:SetColorTexture(0.2, 1, 0.4, 1)
    else pin.aro:SetColorTexture(0.55, 0.5, 0.4, 1); pin.punto:SetColorTexture(1, 1, 1, 1) end
    if pin.SetAlpha then pin:SetAlpha(alfaPin) end
    pin:Show()
  end
end
WowF.dibujarEntrenadores = dibujar
WowF.pinesEntrenadores = function() local n = 0; for _, p in ipairs(pines) do if p:IsShown() then n = n + 1 end end; return n end -- para las pruebas
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
-- 6-oct: boton abajo a la izquierda del mapa: cambia el modo (mis profesiones -> todos -> ninguno)
local function crearBotonMapa()
  if botonMapa or not WorldMapFrame or WowF.interfazMando() then return botonMapa end -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
  botonMapa = CreateFrame("Button", nil, WorldMapFrame, "UIPanelButtonTemplate")
  WowF.estilo.boton(botonMapa, "cuero")
  botonMapa:SetSize(190, 20)
  botonMapa:SetPoint("BOTTOMLEFT", WorldMapFrame.ScrollContainer or WorldMapFrame, "BOTTOMLEFT", 6, 6)
  if botonMapa.SetFrameStrata then botonMapa:SetFrameStrata("HIGH") end
  local function ayuda(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Forever Guide", 0.2, 1, 0.6)
    GameTooltip:AddLine(L("Que entrenadores de profesiones salen en el mapa:", "Which profession trainers show on the map:"), 1, 1, 1, true)
    GameTooltip:AddLine(L("Mis profesiones: las que tienes (y la que te recomienda el plan si te falta una).", "My professions: the ones you have (plus the one your plan recommends if you are missing one)."), 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(L("Todos: los de todas las profesiones (para cambiar de profesion).", "All: every profession trainer (to switch professions)."), 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(L("Ninguno: sin iconos.", "None: no icons."), 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(L("Clic: cambiar", "Click: change"), 0.2, 1, 0.4)
    GameTooltip:Show()
  end
  botonMapa:SetScript("OnClick", function(self)
    WowF.siguienteModoEntrenadores()
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then ayuda(self) end
  end)
  botonMapa:SetScript("OnEnter", ayuda)
  botonMapa:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  WorldMapFrame:HookScript("OnShow", refrescarBoton)
  refrescarBoton()
  return botonMapa
end
pcall(crearBotonMapa)
WowF._botonEntrenadoresMapa = function() pcall(crearBotonMapa); return botonMapa end -- para las pruebas

-- ----- /wowf entrenadores -----
local function listarAqui()
  local m, zona = WowF.mapaActual()
  local lista = WowF.entrenadoresEn(m, true)
  if #lista == 0 then
    print(WowF.T(AZUL .. "en " .. (zona ~= "" and zona or "esta zona") .. " no hay entrenadores de profesiones. Abre el libro (/wowf plan prof): el paso 1 de cada profesion te marca el mas cercano."))
    return
  end
  print(WowF.T(AZUL .. "entrenadores en " .. zona .. " (en el mapa, M, salen con su icono; clic en uno = alfiler):"))
  for _, t in ipairs(lista) do
    if WowF.esAproximado(t.e) then
      print(WowF.T("   " .. ORO .. t.nombre .. "|r: ") .. GRIS .. WowF.textoSinPosicion(t.e[1]) .. "|r")
    else
      print(WowF.T("   " .. ORO .. t.nombre .. "|r: " .. t.e[1] .. GRIS .. "  " .. t.e[3] .. ", " .. t.e[4] .. "  (hasta " .. rangoMax(t.e[6]) .. ")|r"))
    end
  end
end
local anterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower()
  if orden == "entrenadores" or orden == "entrenador" or orden == "maestros" or orden == "trainers" or orden == "trainer" then
    resto = (resto or ""):lower()
    local modo = ({ off = "ninguna", no = "ninguna", ninguna = "ninguna", ninguno = "ninguna", none = "ninguna",
      on = "mias", si = "mias", mias = "mias", mine = "mias", my = "mias", todas = "todas", todos = "todas", all = "todas" })[resto]
    if modo then
      WowF.ponerModoEntrenadores(modo)
      print(WowF.T(AZUL) .. L("iconos del mapa: ", "map icons: ") .. WowF.textoModoEntrenadores() .. GRIS .. L(" (/wowf entrenadores mias | todas | ninguna)", " (/wowf trainers mine | all | none)") .. "|r")
    else listarAqui() end
    pcall(dibujar)
    return
  end
  if anterior then anterior(mensaje) end
end
