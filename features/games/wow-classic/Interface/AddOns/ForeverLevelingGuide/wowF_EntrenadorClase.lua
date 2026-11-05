-- wowF EntrenadorClase: el entrenador de TU clase mas cercano, de un clic (Andy 5-oct: "si soy chaman, solo el de chaman,
-- donde quiera que llegue; un icono chiquito como los otros y que me marque la ruta").
--   * Boton con el icono de tu clase en el Libro (junto a Ajustes) y en el panel (junto al engranaje), y /wowf clase.
--   * El clic arma la ruta paso a paso (wowF_Viaje.lua) hasta el mas cercano (WowF.entrenadorClaseCercano, wowF_Reinicio.lua).
--   * En el mapa del mundo salen SOLO los entrenadores de tu clase y de tu faccion, con un icono pequeno (dorado = al que vas).
-- Datos: WowFDatos.entrenadoresClase (Wowhead /forever, verificados; generar-plan-addon.js). Sin datos de tu clase: aviso claro.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local AZUL = "|cff33ccffForever Guide|r: "
local ORO, VERDE, GRIS, BLANCO, NARANJA = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933"
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function miFac() return (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A" end
local function miClase()
  local ok, nombre, token = pcall(UnitClass, "player")
  if not ok then return "", "" end
  return nombre or "", token or ""
end

-- Icono de la clase: la hoja de iconos de clase del juego (CLASS_ICON_TCOORDS) o, si no esta, el icono suelto
local function ponerIcono(tex, token)
  local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[token]
  if c then
    tex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
  else
    tex:SetTexture("Interface\\Icons\\ClassIcon_" .. (token ~= "" and (token:sub(1, 1) .. token:sub(2):lower()) or "Warrior"))
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  end
end
local function colorClase(token)
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
  if c then return c.r, c.g, c.b end
  return 0.2, 0.8, 1
end

-- Los entrenadores de tu clase y de tu faccion (o neutrales)
function WowF.entrenadoresDeMiClase()
  local _, token = miClase()
  local lista = WowFDatos and WowFDatos.entrenadoresClase and WowFDatos.entrenadoresClase[token]
  local res, fac = {}, miFac()
  for _, e in ipairs(lista or {}) do if (e[5] == fac or e[5] == "N") and not (WowF.esAproximado and WowF.esAproximado(e)) then table.insert(res, e) end end -- 9-oct: sin posiciones de Classic
  return res
end

-- ----- Ir al entrenador -----
local elegido -- el entrenador al que vas (dorado en el mapa)
local dibujar
function WowF.irAlEntrenadorClase(motivo)
  local clase, token = miClase()
  local e = WowF.entrenadorClaseCercano and WowF.entrenadorClaseCercano()
  if not e then
    print(AZUL .. NARANJA .. L("aun no tengo la posicion de los entrenadores de " .. clase .. " de tu faccion en Wowhead /forever. Se anadira en proximas actualizaciones; mientras, ve al de tu capital.",
      "I do not have the position of the " .. clase .. " trainers of your faction on Wowhead /forever yet. It will be added in future updates; meanwhile, visit the one in your capital.") .. "|r")
    return nil
  end
  if WowF.limpiarRutas then pcall(WowF.limpiarRutas, true) end
  elegido = e
  local para = motivo and motivo ~= "" and motivo or L("entrenar tus hechizos nuevos", "train your new spells")
  local quien = ORO .. e[1] .. "|r" .. GRIS .. L(" (entrenador de " .. clase .. ")", " (" .. clase .. " trainer)") .. "|r"
  print(AZUL .. L("entrenador de " .. clase .. " mas cercano: ", "nearest " .. clase .. " trainer: ") .. quien .. GRIS .. ", " .. (e[7] or "") .. " " .. e[3] .. ", " .. e[4] .. "|r")
  local destino = { n = e[1], m = e[2], x = e[3], y = e[4], z = e[7], lugar = true, final = {
    titulo = e[1], ventana = ORO .. L("Entrenador de ", "") .. clase .. L("", " trainer") .. "|r",
    texto = L("Habla con ", "Talk to ") .. quien .. L(" para ", " to ") .. para,
    llegada = L("habla con ", "talk to ") .. quien .. L(" para ", " to ") .. para .. "." } }
  -- Retrato del entrenador en la ventana de la ruta (wowF_Retratos.lua); sin retrato aprendido, el icono de tu clase
  local tc = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[token]
  destino.retrato = { nombre = e[1], unidad = "target",
    icono = tc and "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes" or nil, coords = tc and { tc[1], tc[2], tc[3], tc[4] } or nil }
  local ok, hecho = false, false
  if WowF.viajeA then ok, hecho = pcall(WowF.viajeA, destino, { dibujar = true }) end
  if not (ok and hecho) and WowF.marcar then
    pcall(WowF.marcar, { m = e[2], x = e[3], y = e[4], n = e[1] .. L(" (entrenador de " .. clase .. ")", " (" .. clase .. " trainer)"), z = e[7], lugar = true })
  end
  if dibujar then pcall(dibujar) end
  return e
end
-- Lo que ya usaban Rotacion, Macros y Reiniciar talentos: ahora tambien con ruta
WowF.irAlEntrenador = function(motivo) return WowF.irAlEntrenadorClase(motivo) end
WowF.entrenadorClaseElegido = function() return elegido end

-- Limpiar el mapa tambien quita el entrenador elegido
local limpiarAntes = WowF.limpiarRutas
if limpiarAntes then
  WowF.limpiarRutas = function(...)
    elegido = nil
    local r = limpiarAntes(...)
    if dibujar then pcall(dibujar) end
    return r
  end
end

-- ----- Iconos en el mapa del mundo (solo tu clase) -----
local pines = {}
local function lienzo()
  if not WorldMapFrame or WowF.interfazMando() then return nil end -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
  if WorldMapFrame.GetCanvas then return WorldMapFrame:GetCanvas() end
  return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end
dibujar = function()
  for _, p in pairs(pines) do p:Hide() end -- pairs: nunca ipairs al ocultar
  if WowFExportarDB.entrenadorClaseMapa == false then return end
  local c = lienzo()
  if not c or not WorldMapFrame:IsShown() then return end
  local visto = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  local _, token = miClase()
  local lista = {}
  for _, e in ipairs(WowF.entrenadoresDeMiClase()) do if e[2] == visto then table.insert(lista, e) end end
  if #lista == 0 then return end
  local ancho, alto = c:GetWidth(), c:GetHeight()
  if not ancho or ancho == 0 then return end
  local escala = 1
  pcall(function() escala = c:GetEffectiveScale() / UIParent:GetEffectiveScale() end)
  if not escala or escala <= 0 then escala = 1 end
  local px = 1 / escala
  local tam = 14 * px
  local r, g, b = colorClase(token)
  for i, e in ipairs(lista) do
    local pin = pines[i]
    if not pin then
      pin = CreateFrame("Button", nil, c)
      pin:SetFrameStrata("HIGH")
      pin.punto = pin:CreateTexture(nil, "OVERLAY")
      pin.aro = pin:CreateTexture(nil, "BACKGROUND")
      pin.negro = pin:CreateTexture(nil, "BORDER")
      pin.icono = pin:CreateTexture(nil, "ARTWORK")
      pin.icono:SetAllPoints()
      pin:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local x = self.datos
        local clase = miClase()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(x[1], 1, 1, 1)
        GameTooltip:AddLine(L("Entrenador de " .. clase, clase .. " trainer"), 1, 0.82, 0)
        GameTooltip:AddLine((x[7] or "") .. " " .. x[3] .. ", " .. x[4], 0.6, 0.6, 0.6)
        if WowF.esAproximado and WowF.esAproximado(x) then GameTooltip:AddLine(WowF.textoAprox(), 0.6, 0.6, 0.6, true) end
        GameTooltip:AddLine(L("Clic: llevame hasta el (ruta paso a paso)", "Click: take me there (step-by-step route)"), 0.2, 1, 0.4)
        GameTooltip:Show()
      end)
      pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
      pin:SetScript("OnClick", function(self) WowF.irAlEntrenadorDe(self.datos) end)
      pines[i] = pin
    end
    pin.datos = e
    local este = elegido and elegido[1] == e[1] and elegido[2] == e[2]
    local s = este and tam * 1.25 or tam
    pin:SetSize(s, s)
    pin:ClearAllPoints()
    local borde = 2 * px
    pin.negro:ClearAllPoints(); pin.negro:SetPoint("TOPLEFT", -px, px); pin.negro:SetPoint("BOTTOMRIGHT", px, -px)
    pin.aro:ClearAllPoints(); pin.aro:SetPoint("TOPLEFT", -px - borde, px + borde); pin.aro:SetPoint("BOTTOMRIGHT", px + borde, -px - borde)
    pin.negro:SetColorTexture(0, 0, 0, 1)
    local d = 4 * px
    pin.punto:ClearAllPoints(); pin.punto:SetSize(d, d); pin.punto:SetPoint("BOTTOM", pin, "TOP", 0, px + borde)
    pin:SetPoint("TOP", c, "TOPLEFT", ancho * e[3] / 100, -alto * e[4] / 100 - d - px - borde)
    ponerIcono(pin.icono, token)
    if este then pin.aro:SetColorTexture(1, 0.82, 0, 1); pin.punto:SetColorTexture(1, 0.82, 0, 1)
    else pin.aro:SetColorTexture(r, g, b, 1); pin.punto:SetColorTexture(r, g, b, 1) end
    pin:Show()
  end
end
WowF.dibujarEntrenadorClase = dibujar
WowF.pinesEntrenadorClase = function() local n = 0; for _, p in pairs(pines) do if p:IsShown() then n = n + 1 end end; return n end -- pruebas

-- Ir a uno concreto (clic en su icono del mapa)
function WowF.irAlEntrenadorDe(e)
  if not e then return nil end
  local antes = WowF.entrenadorClaseCercano
  WowF.entrenadorClaseCercano = function() return e end
  local ok, r = pcall(WowF.irAlEntrenadorClase)
  WowF.entrenadorClaseCercano = antes
  return ok and r or nil
end

if WorldMapFrame then
  if WorldMapFrame.OnMapChanged then pcall(hooksecurefunc, WorldMapFrame, "OnMapChanged", function() pcall(dibujar) end) end
  WorldMapFrame:HookScript("OnShow", function() pcall(dibujar) end)
  local escalaVista
  local vigia = CreateFrame("Frame", nil, WorldMapFrame)
  vigia:SetScript("OnUpdate", function()
    local cv = lienzo()
    local ok, s = pcall(function() return cv:GetEffectiveScale() end)
    if ok and type(s) == "number" and s > 0 and (not escalaVista or math.abs(s - escalaVista) > escalaVista * 0.01) then
      escalaVista = s; pcall(dibujar)
    end
  end)
end

-- ----- Botones con el icono de tu clase -----
local function tooltipBoton(self)
  if not GameTooltip then return end
  local clase = miClase()
  local e = WowF.entrenadorClaseCercano and WowF.entrenadorClaseCercano()
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  GameTooltip:SetText(L("Entrenador de " .. clase, clase .. " trainer"), 1, 0.82, 0)
  if e then
    GameTooltip:AddLine(L("El mas cercano: ", "Nearest: ") .. e[1] .. " (" .. (e[7] or "") .. ")", 1, 1, 1, true)
    GameTooltip:AddLine(L("Clic: llevame hasta el (ruta paso a paso y marca en el mapa)", "Click: take me there (step-by-step route and map mark)"), 0.2, 1, 0.4, true)
  else
    GameTooltip:AddLine(L("Aun sin datos de los entrenadores de tu clase. Se anadiran en proximas actualizaciones.", "No data for your class trainers yet. They will be added in future updates."), 1, 0.6, 0.2, true)
  end
  GameTooltip:Show()
end
local function crearBoton(padre, tam)
  local b = CreateFrame("Button", nil, padre)
  b:SetSize(tam, tam)
  b.icono = b:CreateTexture(nil, "ARTWORK")
  b.icono:SetAllPoints()
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("OnClick", function() WowF.irAlEntrenadorClase() end)
  b:SetScript("OnEnter", tooltipBoton)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return b
end
local botonLibro, botonPanel
if WowF.botonAjustesLibro and WowF.libro then
  botonLibro = crearBoton(WowF.libro, 22)
  botonLibro:SetPoint("RIGHT", WowF.botonAjustesLibro, "LEFT", -6, 0)
end
local panelPadre = _G.wowFPanel or (WowF.botonAjustesPanel and WowF.botonAjustesPanel:GetParent())
if WowF.botonAjustesPanel and panelPadre then
  botonPanel = crearBoton(panelPadre, 24) -- 13-oct: antes 18 (Andy: muy pequeno)
  botonPanel:SetPoint("RIGHT", WowF.botonAjustesPanel, "LEFT", -5, 0)
end
WowF.botonEntrenadorClaseLibro, WowF.botonEntrenadorClasePanel = botonLibro, botonPanel
-- El icono se pone al entrar (antes UnitClass puede no estar listo)
local function iconos()
  local _, token = miClase()
  for _, b in ipairs({ botonLibro, botonPanel }) do if b then ponerIcono(b.icono, token) end end
end
pcall(iconos)
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() pcall(iconos) end)

-- ----- /wowf clase [on|off] -----
local anterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower(); resto = (resto or ""):lower()
  if orden == "clase" or orden == "class" or orden == "entrenadorclase" or orden == "trainer" then
    if resto == "off" or resto == "no" then
      WowFExportarDB.entrenadorClaseMapa = false
      print(AZUL .. L("iconos de tu entrenador de clase en el mapa: apagados (/wowf clase on para verlos).", "class trainer icons on the map: off (/wowf class on to show them)."))
    elseif resto == "on" or resto == "si" then
      WowFExportarDB.entrenadorClaseMapa = nil
      print(AZUL .. L("iconos de tu entrenador de clase en el mapa: encendidos.", "class trainer icons on the map: on."))
    else
      WowF.irAlEntrenadorClase()
    end
    pcall(dibujar)
    return
  end
  if anterior then anterior(mensaje) end
end
