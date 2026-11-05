-- wowF Panel 2.4
-- Panel en una esquina que se pone al dia solo: lo que toca a tu nivel (de "Mi plan" de la guia), la proxima mazmorra,
-- dentro de una mazmorra las piezas que te sirven, y la ruta de farmeo de Mining/Herbalism punto por punto en el mapa.
-- Alertas grandes al subir de nivel, al entrar a una mazmorra y cuando cae (o se sortea) una pieza que buscas.
-- Datos: el plan lo arma wowF_Armar.lua (WowFDatos); WowFPlan de la guia queda solo de respaldo. WowFMazmorras y WowFFarmeo (generados).

WowFExportarDB = WowFExportarDB or {}
WowF = WowF or {}
local AZUL = "|cff33ccffForever Guide|r: "
local E = WowF.estilo
-- 11-oct (hibrido): colores de la maqueta (oro viejo, hueso, gris tenue); verde y naranja quedan solo como detalle con
-- significado (verde = bien/hecho, naranja = falta algo) en tono apagado
local ORO, VERDE, GRIS, BLANCO, NARANJA, CELESTE = E.cod.oro, "|cff9ccc65", E.cod.tenue, E.cod.texto, "|cffff9933", E.cod.oro
local BRASA = E.cod.brasa
-- 4-oct (idioma): frases armadas con datos van en los dos idiomas aqui mismo (plantilla entera, no trozos); listo() marca el
-- texto ya hecho en ingles para que WowF.T no lo vuelva a tocar.
local function ingles() return WowF.enIngles and WowF.enIngles() end
local function L(es, en) if ingles() then return en end return es end
local function listo(s) if ingles() and WowF.yaTraducido then return WowF.yaTraducido(s) end return s end

local function despues(segundos, fn) if C_Timer and C_Timer.After then C_Timer.After(segundos, fn) else fn() end end
local function nivelActual() return UnitLevel("player") or 1 end
local function clavePersonaje()
  local nombre = UnitName("player") or "?"
  local reino = (GetRealmName and GetRealmName()) or ""
  if reino ~= "" then return nombre .. "-" .. reino end
  return nombre
end
local function miPlan()
  if WowF.armarPlan then
    local ok, p = pcall(WowF.armarPlan)
    if ok and p then return p end
  end
  if type(WowFPlan) ~= "table" then return nil end
  return WowFPlan[clavePersonaje()]
end
local function primerTrozo(t, largo)
  t = WowF.T(tostring(t or "")) -- traducir antes de cortar: lo cortado ya no esta en el diccionario
  local corto = t:match("^(.-) · ") or t
  if #corto > largo then corto = corto:sub(1, largo - 3) .. "..." end
  return corto
end
local function tengo(id)
  if not id then return false end
  if IsEquippedItem and IsEquippedItem(id) then return true end
  if GetItemCount and (GetItemCount(id, true) or 0) > 0 then return true end
  return false
end
local function idDeEnlace(enlace) return enlace and tonumber(enlace:match("item:(%d+)")) end

-- ===================== Alerta grande en el centro =====================
local alerta = CreateFrame("Frame", "wowFAlerta", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
alerta:SetSize(520, 110)
alerta:SetPoint("TOP", UIParent, "TOP", 0, -150)
alerta:SetFrameStrata("HIGH")
-- 11-oct (hibrido): cartel = etiqueta brasa arriba, titulo serif, texto Signika y boton de accion brasa (sin el borde de tooltip viejo)
E.marco(alerta, "aviso")
alerta:Hide()
local alertaEtiqueta = E.etiqueta(alerta, nil, nil, 9)
alertaEtiqueta:SetPoint("TOP", 0, -14)
alertaEtiqueta:SetText("FOREVER GUIDE")
local alertaTitulo = E.titulo(alerta, nil, 18)
alertaTitulo:SetPoint("TOP", alertaEtiqueta, "BOTTOM", 0, -6)
alertaTitulo:SetWidth(490)
alertaTitulo:SetJustifyH("CENTER")
local alertaRaya = E.textura(alerta, "ARTWORK", 1, E.color.brasa, 0.7)
alertaRaya:SetSize(60, 1)
alertaRaya:SetPoint("TOP", alertaTitulo, "BOTTOM", 0, -6)
local alertaTexto = E.cuerpo(alerta, nil, 13)
alertaTexto:SetPoint("TOP", alertaRaya, "BOTTOM", 0, -7)
alertaTexto:SetWidth(490)
alertaTexto:SetJustifyH("CENTER")
local entrada, salida
if alerta.CreateAnimationGroup then
  entrada = alerta:CreateAnimationGroup()
  local a = entrada:CreateAnimation("Alpha"); a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.35)
  local e = entrada:CreateAnimation("Scale"); if e.SetScaleFrom then e:SetScaleFrom(0.8, 0.8); e:SetScaleTo(1, 1) elseif e.SetFromScale then e:SetFromScale(0.8, 0.8); e:SetToScale(1, 1) end; e:SetDuration(0.35)
  salida = alerta:CreateAnimationGroup()
  local s = salida:CreateAnimation("Alpha"); s:SetFromAlpha(1); s:SetToAlpha(0); s:SetDuration(0.8)
  salida:SetScript("OnFinished", function() alerta:Hide() end)
end
-- Boton de la alerta (4-oct, Andy): abre el plan en la pestana de lo que se avisa (mazmorras, equipo...)
local alertaBoton = CreateFrame("Button", nil, alerta, "UIPanelButtonTemplate")
WowF.estilo.boton(alertaBoton, "cuero")
alertaBoton:SetSize(170, 20)
alertaBoton:SetPoint("BOTTOM", alerta, "BOTTOM", 0, 8)
alertaBoton:Hide()
alertaBoton:SetScript("OnClick", function(self)
  if self.pestana and WowF.abrirLibro then WowF.abrirLibro(self.pestana) end
  alerta:Hide()
end)
-- 4.25 (Andy: "mas friendly"): segundo boton con una accion directa (p. ej. "Llevame al entrenador" al subir de nivel)
local accionBoton = CreateFrame("Button", nil, alerta, "UIPanelButtonTemplate")
WowF.estilo.boton(accionBoton, "brasa")
accionBoton:SetSize(170, 20)
accionBoton:Hide()
accionBoton:SetScript("OnClick", function(self)
  local fn = self.fn
  alerta:Hide()
  if fn then pcall(fn) end
end)
local cola, mostrando = {}, false
local enPantalla, turno = nil, 0 -- turno: el temporizador de una alerta reemplazada no cierra la nueva
local function siguienteAlerta()
  local a = table.remove(cola, 1)
  if not a then mostrando = false; enPantalla = nil; return end
  mostrando = true
  enPantalla = a
  turno = turno + 1
  local miTurno = turno
  alertaTitulo:SetText(WowF.T(a.titulo))
  alertaTexto:SetText(WowF.T(a.texto or ""))
  alertaBoton.pestana = a.pestana
  local dos = a.pestana and a.accion
  alertaBoton:ClearAllPoints()
  alertaBoton:SetPoint("BOTTOM", alerta, "BOTTOM", dos and 90 or 0, 8)
  if a.pestana then
    alertaBoton:SetText(WowF.yaTraducido(L("Verlo en el plan", "See it in the plan")))
    alertaBoton:Show()
  else alertaBoton:Hide() end
  accionBoton.fn = a.accion and a.accion.fn
  accionBoton:ClearAllPoints()
  accionBoton:SetPoint("BOTTOM", alerta, "BOTTOM", dos and -90 or 0, 8)
  if a.accion then
    accionBoton:SetText(WowF.yaTraducido(a.accion.texto or "OK"))
    accionBoton:Show()
  else accionBoton:Hide() end
  -- 13-oct (Ajustes > Avisos emergentes): duracion elegida (nil = fijo: clic en el aviso para cerrarlo); tamano propio abajo
  if WowF.duracionPopup then a.dura = WowF.duracionPopup(a.segundos or 7) else a.dura = a.segundos or 7 end
  if not a.dura then alertaTexto:SetText((alertaTexto:GetText() or "") .. "\n|cff9d9d9d" .. L("(clic aquí para cerrar)", "(click here to close)") .. "|r") end
  -- etiqueta (14+10) + titulo + raya y huecos (19) + texto + botones
  local altoT = tonumber(alertaTitulo:GetStringHeight()) or 20
  local altoX = tonumber(alertaTexto:GetStringHeight()) or 20
  alerta:SetHeight(math.max(96, 30 + altoT + 19 + altoX + 14 + ((a.pestana or a.accion) and 28 or 0)))
  alerta:EnableMouse(not a.dura)
  if WowF.escalaPopup then WowF.escalaPopup(alerta, "wowFAlerta") end
  alerta:SetAlpha(1)
  alerta:Show()
  if entrada then entrada:Play() end
  if a.sonido then pcall(PlaySound, a.sonido) end
  if not a.dura then return end
  despues(a.dura, function()
    if miTurno ~= turno then return end -- la reemplazo otra alerta del mismo tipo
    if not alerta:IsShown() then despues(0, siguienteAlerta); return end -- ya la cerro el boton
    if salida then salida:Play() else alerta:Hide() end
    despues(1, function() if miTurno == turno then siguienteAlerta() end end)
  end)
end
-- extra (opcional): { clave = "farmeo" } = una alerta nueva con la misma clave sustituye a la que esta en pantalla o en cola
-- (6-oct, boton Cambiar: si no, se apilaban); sinChat = no repetir el texto en el chat (quien llama ya lo explico alli)
local function avisar(titulo, texto, sonido, segundos, pestana, extra)
  local clave = extra and extra.clave
  if clave then
    for i = #cola, 1, -1 do if cola[i].clave == clave then table.remove(cola, i) end end
  end
  local nueva = { titulo = titulo, texto = texto, sonido = sonido, segundos = segundos, pestana = pestana, clave = clave, accion = extra and extra.accion }
  if clave and mostrando and enPantalla and enPantalla.clave == clave then
    table.insert(cola, 1, nueva)
    if salida and salida.Stop then pcall(salida.Stop, salida) end
    siguienteAlerta()
    return
  end
  table.insert(cola, nueva)
  -- Traducir titulo y texto ANTES de quitar colores y saltos: el diccionario los tiene tal cual
  if texto and not (extra and extra.sinChat) then print(AZUL .. WowF.T(titulo):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. " - " .. WowF.T(texto):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " ")) end
  if not mostrando then siguienteAlerta() end
end
WowF.avisar = avisar -- wowF_AvisosNuevos.lua (fabricar algo nuevo) usa la misma alerta
-- 13-oct: aviso fijo (Ajustes > Avisos emergentes > Fijos): clic para cerrarlo; al cerrarse (clic o boton) pasa al siguiente de la cola
alerta:SetScript("OnMouseUp", function() alerta:Hide() end)
alerta:SetScript("OnHide", function()
  if not (enPantalla and not enPantalla.dura) then return end
  local t = turno
  despues(0, function() if t == turno then siguienteAlerta() end end)
end)
-- 13-oct (amigo: "una vez reparas no se quita"): quita la alerta con esa clave (en pantalla o en cola) cuando ya no hace falta
function WowF.quitarAviso(clave)
  if not clave then return false end
  for i = #cola, 1, -1 do if cola[i].clave == clave then table.remove(cola, i) end end
  if mostrando and enPantalla and enPantalla.clave == clave then
    alerta:Hide()
    siguienteAlerta()
    return true
  end
  return false
end
local SONIDO_AVISO = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959
local SONIDO_SUAVE = (SOUNDKIT and SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01) or (SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_OPEN) or 875

-- ===================== Panel =====================
-- 11-oct (rediseno por tarjetas, maqueta panel.html): 420 de ancho, cuero con filete oro2 y tachuelas; arriba el retrato del
-- personaje con el sello del nivel, "FOREVER GUIDE", "Plan completo" y el boton de plegar; dentro, losa de piedra (borde #3a2a1a)
-- con la rama, la puntuacion del equipo y las tarjetas (Ahora, Proximo, Profesiones, Mazmorra); abajo, los 3 botones.
local ANCHO = 420
local ARRIBA = 46 -- donde empieza la losa de piedra (padding 46/12/12 de .pan)
local X0, W = 22, ANCHO - 44 -- tarjetas: dentro de la losa (12) + su padding (10)
local XT, WT = X0 + 12, ANCHO - 44 - 24 -- contenido de cada tarjeta (padding 11/12)
local panel = CreateFrame("Frame", "wowFPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
panel:SetSize(ANCHO, 120)
panel:SetFrameStrata("MEDIUM")
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
-- Tipo "libro" = cuero + filete oro2 + tachuelas + losa de piedra con borde #3a2a1a a 12 px (arriba a 46)
local pielPanel = WowF.estilo.marco(panel, "libro", { alfa = 0.8, arriba = ARRIBA, lado = 12 })
if type(pielPanel) ~= "table" then pielPanel = rawget(panel, "_piel") end
-- Plegado: sin losa de piedra ni su borde (el borde es la parte justo antes de la piedra en piel.partes)
local function losaVisible(si)
  if type(pielPanel) ~= "table" or type(pielPanel.partes) ~= "table" then return end
  local piedra = rawget(pielPanel, "piedra")
  local borde
  for i, t in ipairs(pielPanel.partes) do if t == piedra then borde = pielPanel.partes[i - 1]; break end end
  for _, t in ipairs({ piedra, borde }) do if type(t) == "table" and t.Show then if si then t:Show() else t:Hide() end end end
end
local function guardarPosicion()
  local punto, _, relativo, x, y = panel:GetPoint()
  WowFExportarDB.panel = WowFExportarDB.panel or {}
  WowFExportarDB.panel.punto, WowFExportarDB.panel.relativo, WowFExportarDB.panel.x, WowFExportarDB.panel.y = punto, relativo, x, y
end
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); guardarPosicion() end)
local function nivelSobre(f, extra)
  local base = tonumber(panel.GetFrameLevel and panel:GetFrameLevel()) or 1
  pcall(f.SetFrameLevel, f, base + extra)
end

-- .top: retrato (26) con el sello del nivel, "FOREVER GUIDE", "Plan completo" y el boton de plegar (26)
local retratoPanel = E.retratoJugador(panel, 26)
retratoPanel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -12)
do
  local ok, _, token = pcall(UnitClass, "player")
  if ok and type(token) == "string" and retratoPanel.ponerRespaldo then retratoPanel:ponerRespaldo("Interface\\Icons\\ClassIcon_" .. token) end
end
-- Sello pequeno (cera de tu faccion, borde oro2) con el nivel, en la esquina de abajo a la derecha del retrato
local sello = CreateFrame("Frame", nil, panel)
sello:SetSize(16, 16)
sello:SetPoint("CENTER", retratoPanel, "BOTTOMRIGHT", -2, 3)
sello.aro = E.textura(sello, "ARTWORK", 1, E.color.oro2, 1); sello.aro:SetAllPoints()
sello.fondo = E.textura(sello, "ARTWORK", 2, E.color.cera, 1); sello.fondo:SetPoint("TOPLEFT", 1, -1); sello.fondo:SetPoint("BOTTOMRIGHT", -1, 1)
for _, t in ipairs({ sello.aro, sello.fondo }) do if t.SetMask then pcall(t.SetMask, t, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end end
sello.num = sello:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
E.letra(sello.num, "marca", 9)
sello.num:SetTextColor(1, 0.914, 0.788)
sello.num:SetPoint("CENTER", 0, 0)
nivelSobre(sello, 6)

local cabecera = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
E.letra(cabecera, "marca", 12)
cabecera:SetTextColor(E.color.oro[1], E.color.oro[2], E.color.oro[3])
cabecera:SetPoint("LEFT", retratoPanel, "RIGHT", 10, 0)
cabecera:SetJustifyH("LEFT")
if cabecera.SetWordWrap then cabecera:SetWordWrap(false) end
cabecera:SetText("FOREVER GUIDE")
-- Boton de plegar: cuadro de 26 (borde oro2, fondo piedra2, "–" oro 14)
local plegar = CreateFrame("Button", nil, panel)
plegar:SetSize(26, 26)
plegar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -12)
do
  local b = E.textura(plegar, "BACKGROUND", 1, E.color.oro2, 1); b:SetAllPoints()
  local f = E.textura(plegar, "BACKGROUND", 2, E.color.piedra2, 1); f:SetPoint("TOPLEFT", 1, -1); f:SetPoint("BOTTOMRIGHT", -1, 1)
  local fs = plegar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  E.letra(fs, "cuerpoNegrita", 14)
  fs:SetTextColor(E.color.oro[1], E.color.oro[2], E.color.oro[3])
  fs:SetPoint("CENTER", 0, 0)
  if plegar.SetFontString then plegar:SetFontString(fs) end
  if plegar.SetHighlightTexture then pcall(plegar.SetHighlightTexture, plegar, "Interface\\Buttons\\ButtonHilight-Square", "ADD") end
end
-- Abre la ventana con el plan completo (wowF_Libro.lua): secundario chico
local botonLibro = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
WowF.textoFijo(botonLibro, "Plan completo")
E.boton(botonLibro, "secundario", nil, true)
botonLibro:SetWidth(112)
botonLibro:SetPoint("RIGHT", plegar, "LEFT", -8, 0)
botonLibro:SetScript("OnClick", function() if WowF.abrirLibro then WowF.abrirLibro() end end)
-- 4-oct: Ajustes (tamano y opacidad): engranaje junto a "Plan completo"; al pasar el raton dice "Ajustes"
local botonAjustes = CreateFrame("Button", nil, panel)
botonAjustes:SetSize(24, 24) -- 13-oct (Andy: "un pelin mas grande"; antes 18)
botonAjustes:SetPoint("RIGHT", botonLibro, "LEFT", -6, 0)
botonAjustes:SetNormalTexture("Interface\\Icons\\INV_Misc_Gear_01")
botonAjustes:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
botonAjustes:SetScript("OnClick", function() if WowF.abrirOpciones then WowF.abrirOpciones() end end)
botonAjustes:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  GameTooltip:SetText(WowF.T("Ajustes"), 1, 0.82, 0)
  GameTooltip:AddLine(WowF.T("Tamaño de las ventanas y opacidad del fondo"), 1, 1, 1, true)
  GameTooltip:Show()
end)
botonAjustes:SetScript("OnLeave", function() GameTooltip:Hide() end)
WowF.botonAjustesPanel = botonAjustes
cabecera:SetPoint("RIGHT", botonAjustes, "LEFT", -34, 0) -- deja sitio al icono del entrenador de clase (wowF_EntrenadorClase.lua)

-- ===================== Piezas del panel (pool: se reutilizan en cada actualizar) =====================
-- Una fila = Button hijo directo del panel con todas las piezas posibles; cada tipo enciende solo las suyas.
local lineas = {}
local function tooltipBoton(self, texto)
  if not GameTooltip or type(texto) ~= "string" then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(texto, 1, 1, 1, 1, true)
  GameTooltip:Show()
end
local function linea(i)
  if lineas[i] then return lineas[i] end
  local b = CreateFrame("Button", nil, panel)
  b:SetSize(WT, 14)
  -- Rotulo de tarjeta (.eti) y lo de su derecha (.peq)
  b.rot = E.rotulo(b, nil, nil, 12); b.rot:Hide()
  b.der = E.texto(b, nil, 12, E.color.tenue, "regular"); b.der:Hide()
  if b.der.SetJustifyH then b.der:SetJustifyH("RIGHT") end
  -- Titulo (h3) y su subtitulo
  b.h3 = E.h3(b, nil, 15); b.h3:Hide()
  if b.h3.SetWordWrap then b.h3:SetWordWrap(false) end
  b.sub = E.texto(b, nil, 12, E.color.tenue, "regular"); b.sub:Hide()
  -- Fila con icono: nombre (13) y detalle (.peq 12)
  b.ic = E.icono(b, 28); b.ic:Hide()
  b.texto = E.texto(b, nil, 13, nil, "medio")
  if b.texto.SetWordWrap then b.texto:SetWordWrap(true) end
  b.peq = E.texto(b, nil, 12, E.color.tenue, "regular"); b.peq:Hide()
  if b.peq.SetWordWrap then b.peq:SetWordWrap(true) end
  b.barra = E.barra(b, 100); b.barra:Hide()
  -- Cifras de la mazmorra (PIEZAS / MISIONES / FUERA) en 20
  b.cifras = {}
  for k = 1, 3 do local c = E.cifra(b); E.letra(c.num, "cuerpoNegrita", 20); c:Hide(); b.cifras[k] = c end
  -- Raya del aviso (borde de arriba)
  b.raya = E.textura(b, "ARTWORK", 1, E.color.borde, 1); b.raya:SetHeight(1); b.raya:Hide()
  -- Boton terciario (a la derecha del rotulo o de la rama) y boton de accion (estandarte chico "Llevame")
  b.terc = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
  b.terc:SetText(" ")
  E.boton(b.terc, "terciario", 12)
  b.terc:Hide()
  b.terc:SetScript("OnClick", function(self) local fn = rawget(self, "fn"); if type(fn) == "function" then fn() end end)
  b.accion = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
  b.accion:SetText(" ")
  E.boton(b.accion, "estandarte", nil, true)
  b.accion:Hide()
  b.accion:SetScript("OnClick", function(self) local fn = rawget(self, "fn"); if type(fn) == "function" then fn() end end)
  b.accion:SetScript("OnEnter", function(self) local a = rawget(self, "ayuda"); if a then tooltipBoton(self, WowF.T(a)) end end)
  b.accion:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  -- 12-oct (Andy): brillo + mano + "clic" en la tarjeta de mazmorra (la gente no sabia que se puede abrir)
  b.brillo = E.textura(b, "HIGHLIGHT", 1, E.color.oro, 0.08); b.brillo:SetAllPoints(); b.brillo:Hide()
  b:SetScript("OnEnter", function(self)
    local ayuda = rawget(self, "ayuda")
    local pista = rawget(self, "pista")
    if pista then
      self.brillo:Show()
      if SetCursor then pcall(SetCursor, "INTERACT_CURSOR") end
      if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(WowF.T(pista), 1, 0.82, 0, 1, true)
        GameTooltip:Show()
      end
      return
    end
    if rawget(self, "ficha") or type(ayuda) ~= "string" or not GameTooltip then return end -- con ficha: solo el clic la muestra
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(WowF.T(ayuda), 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self)
    if GameTooltip then GameTooltip:Hide() end
    if rawget(self, "pista") then self.brillo:Hide(); if ResetCursor then pcall(ResetCursor) end end
  end)
  b:SetScript("OnClick", function(self)
    local ficha = rawget(self, "ficha")
    if ficha and WowF.abrirFicha then WowF.abrirFicha(ficha); return end
    local fn = rawget(self, "fn"); if type(fn) == "function" then fn() end
  end)
  lineas[i] = b
  return b
end
-- Cajas de misiones de fuera (.mis: 2 columnas, #211f1c con borde #3b3631): titulo 12.5 #d9d0c2 + "NPC · ciudad" 12
local cajas = {}
local function caja(i)
  if cajas[i] then return cajas[i] end
  local c = CreateFrame("Button", nil, panel)
  c:SetSize(170, 40)
  local bo = E.textura(c, "BACKGROUND", 1, { 0.231, 0.212, 0.192 }, 1); bo:SetAllPoints()
  local fo = E.textura(c, "BACKGROUND", 2, { 0.129, 0.122, 0.11 }, 1); fo:SetPoint("TOPLEFT", 1, -1); fo:SetPoint("BOTTOMRIGHT", -1, 1)
  if c.SetHighlightTexture then pcall(c.SetHighlightTexture, c, "Interface\\Buttons\\ButtonHilight-Square", "ADD") end
  c.t = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  E.letra(c.t, "cuerpoNegrita", 12.5)
  c.t:SetTextColor(0.851, 0.816, 0.761)
  c.t:SetJustifyH("LEFT"); if c.t.SetWordWrap then c.t:SetWordWrap(false) end
  c.t:SetPoint("TOPLEFT", 8, -6)
  c.s = E.texto(c, nil, 12, E.color.tenue, "regular")
  if c.s.SetWordWrap then c.s:SetWordWrap(false) end
  c.s:SetPoint("TOPLEFT", c.t, "BOTTOMLEFT", 0, -1)
  c:SetScript("OnClick", function(self) local g = rawget(self, "grupo"); if g and WowF.irAMision then WowF.irAMision(g) end end)
  c:SetScript("OnEnter", function(self) local a = rawget(self, "ayuda"); if a then tooltipBoton(self, a) end end)
  c:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  cajas[i] = c
  return c
end
local function boton(texto, tipo)
  local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  if texto then WowF.textoFijo(b, texto) else b:SetText(" ") end
  E.boton(b, tipo or "secundario", nil, true)
  b:SetWidth(120)
  return b
end
local botonFarmeo = boton(nil) -- texto en cada actualizar: "Farmeo"
local botonCambiar = boton(nil)
local botonParar = boton("Parar ruta")
local botonLimpiar = boton("Limpiar el mapa", "terciario") -- quita TODAS las rutas (mazmorra, mision, farmeo) y el alfiler
-- 4-oct: un par de botones por cada mazmorra recomendada (hasta 3). Cada boton actua sobre SU mazmorra (self.mazmorra):
--   "Ir a la mazmorra" = ruta hasta la entrada · "Misiones a/b" = marca en el mapa las misiones de ESA mazmorra que se cogen fuera.
-- 11-oct (tarjetas): los de la primera van en la fila de abajo (.bts); los de la 2.a y 3.a, debajo de su ficha.
local paresMazmorra = {}
for i = 1, 3 do
  local ir = boton("Ir a la mazmorra", "estandarte")
  local mis = boton(nil)
  ir:SetScript("OnClick", function(self)
    local m = type(self.mazmorra) == "table" and self.mazmorra or nil
    if not m then return end
    if WowF.irAMazmorra then WowF.irAMazmorra(m) elseif WowF.marcar then WowF.marcar(m) end
  end)
  ir:SetScript("OnEnter", function(self)
    local m = type(self.mazmorra) == "table" and self.mazmorra or nil
    if not m then return end
    tooltipBoton(self, WowF.T("Ir a la mazmorra") .. ": " .. m.n .. "\n" .. WowF.T("Te guia paso a paso hasta la entrada, con alfiler en el mapa."))
  end)
  mis:SetScript("OnClick", function(self)
    local m = type(self.mazmorra) == "table" and self.mazmorra or nil
    if m and WowF.marcarTodasMisiones then WowF.marcarTodasMisiones(m) end
  end)
  mis:SetScript("OnEnter", function(self)
    local m = type(self.mazmorra) == "table" and self.mazmorra or nil
    if not m then return end
    local ya = WowF.misionesMarcadasDe and WowF.misionesMarcadasDe(m)
    tooltipBoton(self, WowF.T("Misiones para ") .. m.n .. WowF.T(" que se cogen FUERA, en ciudades y pueblos.") .. "\n" .. WowF.T("Cogelas antes de entrar.") .. "\n"
      .. (ya and ("|cffff9933" .. WowF.T("Ya estan marcadas. Clic: quitar sus marcas del mapa.") .. "|r")
        or ("|cffc77dff" .. WowF.T("Clic: marcalas en el mapa, de la mas cercana a la mas lejana.") .. "|r")))
  end)
  ir:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  mis:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  ir:Hide(); mis:Hide()
  paresMazmorra[i] = { ir = ir, mis = mis }
end

-- ===================== Mazmorras =====================
local enInstancia = nil -- id de la instancia (8.o valor de GetInstanceInfo) o nil
local nombreInstancia = ""
-- Nivel ideal = mitad del rango (11-19 → 15): antes cuesta mucho, despues da poca experiencia
local function nivelIdeal(m) return math.floor((m.d + m.h) / 2) end
-- 4-oct: hasta 3 mazmorras para tu nivel, la mejor PARA TI primero. Puntos: mas piezas que mejoran lo que llevas (2 cada una),
-- ya en su nivel ideal (+3), con la entrada conocida (+1) y al final de su rango (-5: ahi da poca experiencia).
-- Solo entran las abiertas que NO estan al final de su rango; si todas lo estan, la mejor. Sin ninguna abierta: la proxima (una).
-- 11-oct (diario): el criterio vive ahora en WowF.mazmorrasParaTi (wowF_Diario.lua), el mismo para el panel, el Libro y los avisos;
-- esta copia queda solo de respaldo por si wowF_Diario.lua no cargo
local function mazmorrasRecomendadasViejo()
  if not WowF.disponibles then return {}, false end
  local nivel = nivelActual()
  local lista, proximas = WowF.disponibles(nivel)
  if not lista or #lista == 0 then return {}, proximas end
  if proximas or #lista == 1 then return { lista[1] }, proximas end
  local p = miPlan()
  local cand = {}
  for i, m in ipairs(lista) do
    local piezas = WowF.piezasParaTi and WowF.piezasParaTi(p, m.i) or (p and p.botin and p.botin[m.i])
    local puntos = (piezas and #piezas or 0) * 2 + (nivel >= nivelIdeal(m) and 3 or 0) + (m.m and 1 or 0) - (nivel >= m.h - 2 and 5 or 0)
    -- 4-oct: la 2.a y la 3.a solo si te dan algo de verdad (piezas que mejoran lo tuyo o misiones con XP)
    local _, xp = 0, 0
    if WowF.misionesDe then _, xp = WowF.misionesDe(m) end
    table.insert(cand, { m = m, puntos = puntos, orden = i, util = (piezas and #piezas or 0) > 0 or (xp or 0) > 0 })
  end
  table.sort(cand, function(a, b) if a.puntos ~= b.puntos then return a.puntos > b.puntos end return a.orden < b.orden end)
  local res = {}
  for _, c in ipairs(cand) do
    if nivel < c.m.h - 2 and #res < 3 and (#res == 0 or c.util) then table.insert(res, c.m) end
  end
  if #res == 0 then res[1] = cand[1].m end
  return res, proximas
end
local function mazmorrasRecomendadas()
  if WowF.mazmorrasParaTi then
    -- sin pcall, como antes: un error de la comparacion de piezas tiene que verse (las pruebas lo cazan)
    local _, reco, proximas = WowF.mazmorrasParaTi(miPlan(), nivelActual())
    if type(reco) == "table" then return reco, proximas end
  end
  return mazmorrasRecomendadasViejo()
end
WowF.mazmorrasRecomendadas = mazmorrasRecomendadas -- para las pruebas
local function piezasAqui()
  local p = miPlan()
  if not p or not p.botin or not enInstancia then return nil end
  -- Solo las que mejoran lo que llevas puesto (cada una con o.porque)
  -- 7-oct: true = la que ya conseguiste aqui sigue en la lista, marcada "[ya la tienes]" (fuera de la mazmorra no sale)
  if WowF.piezasParaTi then return WowF.piezasParaTi(p, enInstancia, true) end
  return p.botin[enInstancia]
end
local function misionesAqui()
  if not enInstancia or not WowF.misionesDe then return {} end
  for _, m in ipairs(WowFMazmorras or {}) do if m.i == enInstancia then return (WowF.misionesDe(m)) end end
  return {}
end
local function buscada(id)
  local p = miPlan()
  if not p or not p.botin or not id then return nil end
  if enInstancia and p.botin[enInstancia] then
    for _, o in ipairs(p.botin[enInstancia]) do if o.id == id then return o end end
  end
  for _, lista in pairs(p.botin) do for _, o in ipairs(lista) do if o.id == id then return o end end end
  return nil
end

-- ===================== Ruta de farmeo =====================
local ruta = nil -- { prof, nombre, rango, tramo, zona, i }
local NOMBRES = {
  [186] = { "Mining", "Mineria", "Minería" },
  [182] = { "Herbalism", "Herboristeria", "Herboristería", "Herbalismo" },
}
-- Profesiones que se surten de una de recoleccion
local SURTE = { blacksmithing = 186, engineering = 186, mining = 186, alchemy = 182, herbalism = 182, inscription = 182 }
local function rangoDe(prof)
  -- Lectura comun (wowF_Exportar.lua): por numero de profesion y en todos los idiomas del cliente
  if WowF.rangoProfesion then
    local r = WowF.rangoProfesion(prof)
    if r then return r, true end
    return 0, false
  end
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local nombre, esCabecera, _, rango = GetSkillLineInfo(i)
      if nombre and not esCabecera then
        for _, n in ipairs(NOMBRES[prof]) do if nombre == n then return rango or 0, true end end
      end
    end
  end
  return 0, false
end
local function misRecolecciones()
  local tiene = {}
  for _, prof in ipairs({ 186, 182 }) do local _, la = rangoDe(prof); if la then table.insert(tiene, prof) end end
  return tiene
end
-- 6-oct (Andy: "Cambiar no lo muestra para la otra profesion"): todas las rutas de farmeo que te sirven, para el boton Cambiar.
-- 186/182 = vetas/hierbas · "piel" = Skinning/Leatherworking · "tela" = Tailoring · "cocina" = Cooking · "vendas" = First Aid
local farmeoElegido -- la ultima que pediste con el boton (la de bichos no deja "ruta")
local function opcionesFarmeo()
  local l, visto = {}, {}
  local function poner(p) if p and not visto[p] then visto[p] = true; table.insert(l, p) end end
  for _, p in ipairs(misRecolecciones()) do poner(p) end
  local mias = {}
  for _, p in ipairs(WowF.profesiones and WowF.profesiones() or {}) do mias[p.id] = true end
  if mias[393] or mias[165] then poner("piel") end
  if mias[197] then poner("tela") end
  if mias[185] then poner("cocina") end
  if mias[129] then poner("vendas") end
  return l, mias
end
local function nombreFarmeo(p, mias)
  if p == 186 then return "Mining" elseif p == 182 then return "Herbalism"
  elseif p == "piel" then return (mias and not mias[393] and mias[165]) and "Leatherworking" or "Skinning"
  elseif p == "tela" then return "Tailoring" elseif p == "cocina" then return "Cooking" elseif p == "vendas" then return "First Aid" end
  return tostring(p)
end
-- La siguiente de la lista tras la que llevas (en vuelta). Sin otra que tengas: Mining <-> Herbalism si la ruta es una sugerencia
local function siguienteFarmeo(actual)
  local l = opcionesFarmeo()
  for i, p in ipairs(l) do if p == actual then local s = l[i % #l + 1]; if s ~= actual then return s end end end
  for _, p in ipairs(l) do if p ~= actual then return p end end
  if ruta and ruta.sugerida then return ruta.prof == 186 and 182 or 186 end
  return nil
end
WowF._opcionesFarmeo = opcionesFarmeo -- para las pruebas
local function continenteDe(mapa)
  if not C_Map or not C_Map.GetMapInfo then return nil end
  local info = C_Map.GetMapInfo(mapa or 0)
  local vueltas = 0
  while info and vueltas < 8 do
    if info.mapType == 2 then return info.name end
    info = info.parentMapID and C_Map.GetMapInfo(info.parentMapID)
    vueltas = vueltas + 1
  end
  return nil
end
local function elegirZona(prof, rango)
  local datos = WowFFarmeo and WowFFarmeo[prof]
  if not datos then return nil end
  local tramo = datos.tramos[#datos.tramos]
  for _, t in ipairs(datos.tramos) do if rango < t.b then tramo = t; break end end
  local faccion = WowF.miFaccion and WowF.miFaccion() or 0
  local nivel = nivelActual()
  local aptas = {}
  for _, z in ipairs(tramo.zonas) do
    if (z.f == 0 or z.f == faccion) and nivel >= z.d - 3 then table.insert(aptas, z) end
  end
  if #aptas == 0 then
    -- Ninguna a tu nivel: la de nivel mas bajo de tu faccion (o neutral)
    for _, z in ipairs(tramo.zonas) do if z.f == 0 or z.f == faccion then table.insert(aptas, z) end end
    table.sort(aptas, function(a, b) return a.d < b.d end)
    return aptas[1], tramo
  end
  local mejor = aptas[1]
  local aqui = continenteDe(C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
  if aqui then
    for _, z in ipairs(aptas) do
      if z.c == aqui then
        if z.s >= mejor.s * 0.6 then mejor = z end
        break
      end
    end
  end
  return mejor, tramo
end
local function ponerAlfiler(m, x, y, titulo)
  local puesto = false
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    puesto = pcall(function()
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(m, x / 100, y / 100))
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end)
  end
  if TomTom and TomTom.AddWaypoint then
    if pcall(TomTom.AddWaypoint, TomTom, m, x / 100, y / 100, { title = titulo }) then puesto = true end
  end
  return puesto
end

-- Posicion del jugador en el mapa m (0-100) o nil si no esta en ese mapa
local function posEn(m)
  if not C_Map or not C_Map.GetPlayerMapPosition then return nil end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, m, "player")
  if not ok or not pos then return nil end
  local x, y = pos.x or (pos.GetXY and select(1, pos:GetXY())), pos.y or (pos.GetXY and select(2, pos:GetXY()))
  if not x or not y or (x == 0 and y == 0) then return nil end
  return x * 100, y * 100
end
local function dist(p, x, y) local dx, dy = p[1] - x, p[2] - y; return math.sqrt(dx * dx + dy * dy) end
-- El punto sin recorrer mas cercano a (x, y)
local function masCercano(x, y)
  local mejor, dm
  for k, p in ipairs(ruta.zona.ruta) do
    if not ruta.hechos[k] then local d = dist(p, x, y); if not dm or d < dm then mejor, dm = k, d end end
  end
  return mejor, dm
end
-- Orden de recorrido: el que toca y, desde cada uno, el mas cercano que falte
local function ordenRuta()
  local orden, usado = { ruta.i }, { [ruta.i] = true }
  local actual = ruta.zona.ruta[ruta.i]
  while true do
    local mejor, dm
    for k, p in ipairs(ruta.zona.ruta) do
      if not ruta.hechos[k] and not usado[k] then local d = dist(p, actual[1], actual[2]); if not dm or d < dm then mejor, dm = k, d end end
    end
    if not mejor then break end
    table.insert(orden, mejor); usado[mejor] = true; actual = ruta.zona.ruta[mejor]
  end
  return orden
end
local function quedan()
  local n = 0
  for k in ipairs(ruta.zona.ruta) do if not ruta.hechos[k] then n = n + 1 end end
  return n
end

-- Puntos dibujados en el mapa del mundo (estrella = el mas cercano, el que toca; circulos numerados = el orden; apagados = ya recorridos)
local puntosMapa, lineasMapa, sitiosMapa, bordesMapa = {}, {}, {}, {}
local capaLineas -- marco encima del mapa donde va la raya de la ruta
local function lienzo()
  if not WorldMapFrame or WowF.interfazMando() then return nil end -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
  if WorldMapFrame.GetCanvas then return WorldMapFrame:GetCanvas() end
  return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end
local function tooltipPunto(self)
  if not GameTooltip or not self.texto then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(self.texto, 1, 1, 1, 1, true)
  GameTooltip:Show()
end
local VER_PUNTOS = 6 -- 4-oct (2): solo los siguientes (6) en el mapa (antes todos, y la zona quedaba llena de iconos)
local function dibujarMapa()
  for _, p in pairs(puntosMapa) do p:Hide() end
  for _, l in pairs(lineasMapa) do l:Hide() end
  for _, s in pairs(sitiosMapa) do s:Hide() end
  for _, b in pairs(bordesMapa) do b:Hide() end
  local c = lienzo()
  if not c or not ruta or not WorldMapFrame:IsShown() then return end
  local visto = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  if visto ~= ruta.zona.m then return end
  local ancho, alto = c:GetWidth(), c:GetHeight()
  if not ancho or ancho == 0 then return end
  -- Tamano fijo EN PANTALLA: 13 px el que toca, 10 px los demas (antes ancho/60 del lienzo: crecia con el mapa)
  local escala = 1
  pcall(function() escala = c:GetEffectiveScale() / UIParent:GetEffectiveScale() end)
  if not escala or escala <= 0 then escala = 1 end
  local px = 1 / escala
  local puntos = ruta.zona.ruta
  local orden = ordenRuta()
  local paso = {}
  for j, k in ipairs(orden) do if j <= VER_PUNTOS then paso[k] = j end end
  local ingles = WowF.enIngles and WowF.enIngles()
  for i, p in ipairs(puntos) do
    local j = paso[i]
    if j then
      -- 4-oct (Andy: "que salga definida como antes, con la rayita 1, 2, 3, 4"): circulo con el NUMERO dentro, como la ruta de viaje.
      -- VERDE = el 1, el mas cercano (adonde apunta la flecha del minimapa); dorado = los siguientes
      local pin = puntosMapa[i]
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
        pin:SetScript("OnEnter", tooltipPunto)
        pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        puntosMapa[i] = pin
      end
      local t = (j == 1 and 18 or 15) * px
      pin:SetSize(t, t)
      if pin.borde then
        pin.borde:ClearAllPoints()
        pin.borde:SetPoint("TOPLEFT", -1.5 * px, 1.5 * px)
        pin.borde:SetPoint("BOTTOMRIGHT", 1.5 * px, -1.5 * px)
      end
      pin:ClearAllPoints()
      pin:SetPoint("CENTER", c, "TOPLEFT", ancho * p[1] / 100, -alto * p[2] / 100)
      if j == 1 then pin.icono:SetColorTexture(0.2, 1, 0.4, 1) else pin.icono:SetColorTexture(1, 0.82, 0, 1) end
      if pin.numero then
        pcall(pin.numero.SetFont, pin.numero, (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"), (j == 1 and 12 or 10) * px, "")
        pin.numero:SetText(tostring(j))
      end
      pin.texto = (j == 1) and (ingles and "1 - Nearest point: go here first (the minimap arrow points here)" or "1 - Punto mas cercano: ve aqui primero (la flecha del minimapa apunta aqui)")
        or ((ingles and "Point " or "Punto ") .. j .. (ingles and ": then follow the line" or ": despues sigue la raya"))
      pin:Show()
    end
  end
  -- 4-oct (Andy: "que dibuje la ruta con la rayita amarilla"): la raya dibujada en el propio lienzo quedaba DEBAJO de las piezas del mapa
  -- y no se veia. Ahora va en una capa propia encima del mapa (debajo de los circulos), amarilla con borde oscuro
  if not capaLineas then
    capaLineas = CreateFrame("Frame", nil, c)
    capaLineas:SetAllPoints(c)
    capaLineas:SetFrameStrata("HIGH")
  end
  pcall(function() capaLineas:SetFrameLevel(c:GetFrameLevel() + 1) end)
  capaLineas:Show()
  if capaLineas.CreateLine then
    for j = 1, math.min(#orden, VER_PUNTOS) - 1 do
      local a, b = puntos[orden[j]], puntos[orden[j + 1]]
      local l, sombra = lineasMapa[j], bordesMapa[j]
      if not l then
        local ok1, s1 = pcall(capaLineas.CreateLine, capaLineas, nil, "ARTWORK")
        local ok2, l2 = pcall(capaLineas.CreateLine, capaLineas, nil, "OVERLAY")
        if ok1 and s1 then sombra = s1; bordesMapa[j] = s1 end
        if ok2 and l2 then l = l2; lineasMapa[j] = l2 end
      end
      for _, par in ipairs({ { sombra, 6, 0, 0, 0, 0.75 }, { l, 3, 1, 0.85, 0.1, 1 } }) do
        local ln = par[1]
        if ln then
          ln:SetThickness(par[2] * px)
          ln:SetColorTexture(par[3], par[4], par[5], par[6])
          ln:SetStartPoint("TOPLEFT", c, ancho * a[1] / 100, -alto * a[2] / 100)
          ln:SetEndPoint("TOPLEFT", c, ancho * b[1] / 100, -alto * b[2] / 100)
          ln:Show()
        end
      end
    end
  end
  -- Sitios donde sale la veta o la hierba alrededor del punto que toca (cuadritos de 4 px)
  local sitios = (puntos[ruta.i] or {})[5] or {}
  for k = 1, #sitios - 1, 2 do
    local j = (k + 1) / 2
    local s = sitiosMapa[j]
    if not s then
      s = CreateFrame("Frame", nil, c)
      s:SetFrameStrata("HIGH")
      s.icono = s:CreateTexture(nil, "OVERLAY")
      s.icono:SetAllPoints()
      s.icono:SetColorTexture(0.2, 1, 0.2, 0.9)
      sitiosMapa[j] = s
    end
    s:SetSize(4 * px, 4 * px)
    s:ClearAllPoints()
    s:SetPoint("CENTER", c, "TOPLEFT", ancho * sitios[k] / 100, -alto * sitios[k + 1] / 100)
    s:Show()
  end
end
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

local actualizar -- se define abajo
local function marcarPunto(avisoGrande)
  if not ruta then return end
  local p = ruta.zona.ruta[ruta.i]
  ponerAlfiler(ruta.zona.m, p[1], p[2], ruta.nombre .. " " .. ruta.i)
  local hechos = {}
  for k in pairs(ruta.hechos) do table.insert(hechos, k) end
  WowFExportarDB.farmeo = { prof = ruta.prof, zona = ruta.zona.n, i = ruta.i, hechos = hechos, pj = clavePersonaje() }
  if avisoGrande then
    avisar(ruta.nombre .. ": " .. ruta.zona.n, "Sigue la flecha: siempre te lleva al punto mas cercano (el circulo VERDE con el 1 en el mapa, M).\nLos cuadritos verdes de alrededor son donde salen las vetas: recorrelos.\n" .. GRIS .. "Aqui salen: " .. ruta.tramo.nodos .. "|r", SONIDO_SUAVE, 9, nil, { clave = "farmeo" })
  end
  pcall(dibujarMapa)
  if WowF.mostrarFlecha then WowF.mostrarFlecha() end
  if actualizar then actualizar() end
end
local function empezarRuta(prof, avisoGrande, zonaGuardada, puntoGuardado)
  local rango, laTienes = rangoDe(prof)
  local zona, tramo = elegirZona(prof, rango)
  if zonaGuardada and WowFFarmeo and WowFFarmeo[prof] then
    -- Al volver a entrar se retoma la misma zona si sigue en el tramo
    for _, z in ipairs(tramo and tramo.zonas or {}) do if z.n == zonaGuardada then zona = z end end
  end
  if not zona then
    print(WowF.T(AZUL .. "no hay ruta de farmeo para esa profesion todavia."))
    return
  end
  -- 4-oct: solo UNA ruta a la vez. Al pedir esta (no al retomarla al entrar) se quitan la de mazmorra/mision y el entrenador marcado
  if not zonaGuardada then
    if WowF.pararViaje then pcall(WowF.pararViaje, true) end
    if WowF.entrenadorElegido then WowF.entrenadorElegido = nil; if WowF.dibujarEntrenadores then pcall(WowF.dibujarEntrenadores) end end
  end
  ruta = { prof = prof, nombre = WowFFarmeo[prof].nombre, rango = rango, tramo = tramo, zona = zona, i = 1, hechos = {}, sugerida = not laTienes }
  local g = WowFExportarDB.farmeo
  if g and g.prof == prof and g.zona == zona.n and type(g.hechos) == "table" then
    for _, k in ipairs(g.hechos) do if zona.ruta[k] then ruta.hechos[k] = true end end
  end
  if quedan() == 0 then ruta.hechos = {} end
  if puntoGuardado and zona.n == zonaGuardada and zona.ruta[puntoGuardado] then ruta.i = puntoGuardado end
  -- Siempre el punto sin recorrer mas cercano a donde estas; si no estas en la zona, el vigia lo corrige al llegar
  local x, y = posEn(zona.m)
  if x then ruta.i = masCercano(x, y) or ruta.i end
  marcarPunto(avisoGrande)
  if avisoGrande and ruta and ruta.sugerida then
    print(WowF.T(AZUL .. "aun NO tienes " .. ruta.nombre .. ": te marco la ruta como sugerencia. Aprendela con el entrenador para poder recoger."))
  end
end
-- WowFExportarDB es por CUENTA: solo se retoma la ruta de ESTE personaje (las guardadas sin personaje, de la 3.3 o antes,
-- solo si de verdad tiene esa profesion)
local function rutaGuardadaMia(f)
  if not (f and f.prof and WowFFarmeo and WowFFarmeo[f.prof]) then return false end
  if f.pj then return f.pj == clavePersonaje() end
  local _, la = rangoDe(f.prof)
  return la
end
-- Retoma la ruta guardada (al entrar al juego y en las pruebas)
function WowF._retomarRuta()
  local f = WowFExportarDB.farmeo
  if rutaGuardadaMia(f) then empezarRuta(f.prof, false, f.zona, f.i) end
end
-- callado == true: sin mensaje (lo usan Limpiar el mapa y las otras rutas). Ojo: el clic del boton pasa el boton como 1er valor
local function pararRuta(callado)
  callado = (callado == true)
  if callado and not ruta then return end -- nada que parar: no tocar el alfiler de otra ruta
  ruta = nil
  local g = WowFExportarDB.farmeo
  if not (g and g.pj and g.pj ~= clavePersonaje()) then WowFExportarDB.farmeo = nil end -- la de otro personaje no se toca
  if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
  pcall(dibujarMapa)
  if WowF.mostrarFlecha then WowF.mostrarFlecha() end
  if not callado then print(WowF.T(AZUL .. "ruta de farmeo parada.")) end
  if actualizar then actualizar() end
end
WowF.pararRutaFarmeo = pararRuta
WowF.rutaFarmeoActiva = function() return ruta ~= nil end
local function profDeTexto(t)
  t = (t or ""):lower()
  for clave, prof in pairs(SURTE) do if t ~= "" and clave:find(t, 1, true) == 1 then return prof end end
  if t:find("^min") then return 186 end
  if t:find("^herb") or t:find("^hierb") then return 182 end
  if t:find("^skin") or t:find("^leather") or t:find("^desoll") then return "piel" end
  if t:find("^tail") or t:find("^sast") then return "tela" end
  if t:find("^cook") or t:find("^coc") then return "cocina" end
  if t:find("^first") or t:find("^prim") or t:find("^aid") then return "vendas" end
  return nil
end

-- Se revisa cada segundo si llegaste al punto
local reloj = 0
local vigiaRuta = CreateFrame("Frame")
vigiaRuta:SetScript("OnUpdate", function(_, pasado)
  reloj = reloj + pasado
  if reloj < 1 or not ruta then return end
  reloj = 0
  local x, y = posEn(ruta.zona.m)
  if not x then return end
  local function pisar()
    local alguno = false
    for k, p in ipairs(ruta.zona.ruta) do
      if not ruta.hechos[k] and dist(p, x, y) < 3 then ruta.hechos[k] = true; alguno = true end
    end
    return alguno
  end
  local pisado = pisar()
  if quedan() == 0 then
    ruta.hechos = {}
    pisar()
    avisar("Vuelta completa", "Empieza otra vuelta: las vetas y hierbas ya volvieron a salir. La flecha te lleva al punto mas cercano.", SONIDO_SUAVE, 5)
  end
  local k, d = masCercano(x, y)
  if not k then return end
  local llegaste = ruta.hechos[ruta.i]
  -- Cambia de destino si el que tocaba ya se recorrio o si otro que falta esta claramente mas cerca
  if k ~= ruta.i and (llegaste or d + 1 < dist(ruta.zona.ruta[ruta.i], x, y)) then
    ruta.i = k
    if llegaste then print(WowF.T(AZUL .. "punto listo. Ahora el mas cercano (" .. ruta.zona.ruta[k][4] .. "); quedan " .. quedan() .. " de " .. #ruta.zona.ruta .. ".")) end
    marcarPunto(false)
  elseif pisado then
    marcarPunto(false)
  end
end)

-- Flecha debajo del minimapa que apunta al punto que toca, con la distancia (como TomTom)
local flecha = CreateFrame("Frame", "wowFFlecha", UIParent)
flecha:SetSize(48, 58)
flecha:SetMovable(true)
flecha:EnableMouse(true)
flecha:RegisterForDrag("LeftButton")
flecha:SetScript("OnDragStart", function(self) self:StartMoving() end)
flecha:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local a, _, b, x, y = self:GetPoint()
  WowFExportarDB.flecha = { a, b, x, y }
end)
local mostrarFlecha
do -- 11-oct: bloque propio (Lua admite 200 locales por archivo)
local flechaTex = flecha:CreateTexture(nil, "ARTWORK")
flechaTex:SetSize(38, 38) -- 4-oct (2): antes 44, luego 32 (se perdia)
flechaTex:SetPoint("TOP", 0, 0)
flechaTex:SetTexture("Interface\\Minimap\\MinimapArrow")
flechaTex:SetVertexColor(0.2, 1, 0.4) -- verde, como el punto 1 del mapa
local VERDE_CLARO_FLECHA = "|cff33ff66"
local flechaTexto = flecha:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
flechaTexto:SetPoint("TOP", flechaTex, "BOTTOM", 0, 0)
flechaTexto:SetWidth(140)
flecha:Hide()
local flechaColocada = false
local function colocarFlecha()
  if flechaColocada then return end
  flechaColocada = true
  flecha:ClearAllPoints()
  local g = WowFExportarDB.flecha
  if g and g[1] then flecha:SetPoint(g[1], UIParent, g[2], g[3], g[4])
  elseif Minimap then flecha:SetPoint("TOP", Minimap, "BOTTOM", 0, -24)
  else flecha:SetPoint("TOP", UIParent, "TOP", 0, -120) end
end
-- Posicion en yardas del mundo si el cliente la da; si no, en coordenadas del mapa
local function enMundo(m, x, y)
  if C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
    local ok, _, v = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x, y))
    if ok and v and v.GetXY then local wx, wy = v:GetXY(); if wx then return wx, wy, true end end
  end
  return -y, -x, false -- norte = -y del mapa, oeste = -x
end
local relojFlecha = 0
flecha:SetScript("OnUpdate", function(self, pasado)
  relojFlecha = relojFlecha + pasado
  if relojFlecha < 0.05 then return end
  relojFlecha = 0
  if not ruta or not C_Map or not C_Map.GetPlayerMapPosition then self:Hide(); return end
  local x, y = posEn(ruta.zona.m)
  if x then x, y = x / 100, y / 100 end
  local p = ruta.zona.ruta[ruta.i]
  if not x or not y then
    flechaTex:SetRotation(0)
    flechaTexto:SetText(WowF.T(NARANJA .. "Ve a " .. ruta.zona.n .. "|r"))
    return
  end
  local px, py, yardas = enMundo(ruta.zona.m, x, y)
  local tx, ty = enMundo(ruta.zona.m, p[1] / 100, p[2] / 100)
  local norte, oeste = tx - px, ty - py
  local cara = GetPlayerFacing and GetPlayerFacing()
  if cara then flechaTex:SetRotation((math.atan2 or math.atan)(oeste, norte) - cara) end
  local dist = math.sqrt(norte * norte + oeste * oeste)
  local en = WowF.enIngles and WowF.enIngles()
  flechaTexto:SetText(WowF.yaTraducido and WowF.yaTraducido(VERDE_CLARO_FLECHA .. (en and "Go to point 1" or "Ve al punto 1") .. "|r\n" .. GRIS .. (en and "(nearest)" or "(el mas cercano)") .. (yardas and ("  " .. math.floor(dist + 0.5) .. (en and " yards" or " yardas")) or "") .. "|r")
    or (VERDE_CLARO_FLECHA .. "1|r"))
end)
mostrarFlecha = function()
  if ruta then colocarFlecha(); flecha:Show() else flecha:Hide() end
end
end -- fin del bloque de la flecha
WowF.mostrarFlecha = mostrarFlecha

-- ===================== Ficha (clic en una linea) =====================
-- Icono grande del objeto, que hacer paso a paso y los materiales con cuantos tienes
local function iconoDe(id, ic) -- 12-oct: cliente primero, ic = respaldo del mismo objeto
  return (WowF.iconoObjeto and WowF.iconoObjeto(id, ic)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local ICONO_TIPO = { hito = "Interface\\Icons\\INV_Misc_Note_01", talento = "Interface\\Icons\\INV_Misc_Book_09", rama = "Interface\\Icons\\INV_Misc_Book_09",
  prof = "Interface\\Icons\\INV_Misc_Gear_01", zona = "Interface\\Icons\\INV_Misc_Map_01" }
local CALIDAD = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }
local function colorCalidad(q)
  if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] and ITEM_QUALITY_COLORS[q].hex then return ITEM_QUALITY_COLORS[q].hex end
  return CALIDAD[q] or BLANCO
end
local function tooltipObjeto(owner, id)
  if (type(id) ~= "number" and type(id) ~= "string") or not GameTooltip then return end
  GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
  GameTooltip:SetHyperlink("item:" .. id)
  GameTooltip:Show()
end

local ficha = CreateFrame("Frame", "wowFFicha", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
ficha:SetSize(300, 120)
ficha:SetFrameStrata("MEDIUM")
ficha:SetClampedToScreen(true)
ficha:EnableMouse(true)
-- 11-oct (hibrido): tarjeta de piedra (marco "panel" + raya brasa arriba), etiqueta brasa, titulo serif, datos grandes
WowF.estilo.marco(ficha, "panel")
ficha:Hide()
do local fichaRaya = E.textura(ficha, "ARTWORK", 2, E.color.brasa, 1)
fichaRaya:SetPoint("TOPLEFT", 1, -1); fichaRaya:SetPoint("TOPRIGHT", -1, -1); fichaRaya:SetHeight(2) end
-- 11-oct (diario): la X del estilo hibrido (cuero con borde dorado), no la cruz roja del juego
local cerrarFicha = CreateFrame("Button", nil, ficha, "UIPanelButtonTemplate")
E.boton(cerrarFicha, "cuero", 11)
cerrarFicha:SetSize(18, 18); cerrarFicha:SetText("X")
cerrarFicha:SetPoint("TOPRIGHT", -6, -6)
local fichaEtiq = E.etiqueta(ficha, nil, nil, 9)
fichaEtiq:SetPoint("TOPLEFT", 12, -12)
fichaEtiq:SetWidth(240)
local fichaIcono = CreateFrame("Button", nil, ficha)
fichaIcono:SetSize(36, 36)
fichaIcono:SetPoint("TOPLEFT", 13, -29)
do local fichaIconoMarco = E.textura(ficha, "ARTWORK", 1, E.color.borde, 1)
fichaIconoMarco:SetPoint("TOPLEFT", fichaIcono, "TOPLEFT", -1, 1)
fichaIconoMarco:SetPoint("BOTTOMRIGHT", fichaIcono, "BOTTOMRIGHT", 1, -1) end
local fichaIconoTex = fichaIcono:CreateTexture(nil, "ARTWORK", nil, 3)
fichaIconoTex:SetAllPoints()
if fichaIconoTex.SetTexCoord then fichaIconoTex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
fichaIcono:SetScript("OnEnter", function(self) tooltipObjeto(self, self.id) end)
fichaIcono:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
local fichaTitulo = E.titulo(ficha, nil, 16)
fichaTitulo:SetPoint("TOPLEFT", fichaIcono, "TOPRIGHT", 10, -1)
fichaTitulo:SetWidth(228)
local fichaSub = E.sub(ficha, nil, 10)
fichaSub:SetPoint("TOPLEFT", fichaTitulo, "BOTTOMLEFT", 0, -4)
fichaSub:SetWidth(228)
local fichaDatos = {}
for i = 1, 3 do fichaDatos[i] = E.dato(ficha); fichaDatos[i]:Hide() end
local fichaTexto = E.cuerpo(ficha, nil, 11)
fichaTexto:SetWidth(276)
local materiales = {}
local function filaMaterial(i)
  if materiales[i] then return materiales[i] end
  local b = CreateFrame("Button", nil, ficha)
  b:SetSize(276, 22)
  local t = b:CreateTexture(nil, "ARTWORK")
  t:SetSize(20, 20)
  t:SetPoint("LEFT", 0, 0)
  b.tex = t
  local mc = E.textura(b, "ARTWORK", 1, E.color.borde, 1) -- 11-oct (hibrido): icono enmarcado
  mc:SetPoint("TOPLEFT", t, "TOPLEFT", -1, 1); mc:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 1, -1)
  if t.SetDrawLayer then pcall(t.SetDrawLayer, t, "ARTWORK", 3) end
  local f = E.cuerpo(b, nil, 11)
  f:SetPoint("LEFT", t, "RIGHT", 6, 0)
  f:SetWidth(250)
  b.texto = f
  b:SetScript("OnEnter", function(self) tooltipObjeto(self, self.id) end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  materiales[i] = b
  return b
end

local fichaActual = nil
local pintarFicha
-- Filas de misiones de la ficha (solo texto) y su cabecera desplegable
local filasMision = {}
local function filaMision(i)
  if filasMision[i] then return filasMision[i] end
  local b = CreateFrame("Button", nil, ficha)
  b:SetScript("OnClick", function(self) if type(self.mision) == "table" and WowF.irAMision then WowF.irAMision(self.mision) end end)
  b:SetScript("OnEnter", function(self)
    -- 4-oct: solo si la fila trae una mision de verdad ({ quien, m, x, y, q = { mision } }); si no, nada
    local mi = self.mision
    local q = type(mi) == "table" and type(mi.q) == "table" and mi.q[1]
    if type(q) ~= "table" or not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(WowF.T("MISION DE MAZMORRA"), 0.78, 0.49, 1)
    GameTooltip:AddLine(q.n or "?", 1, 1, 1)
    if q.dentro then GameTooltip:AddLine(WowF.T(GRIS .. "se recoge dentro de la mazmorra|r"), 1, 1, 1, true)
    elseif WowF.dondeLaDaMision then GameTooltip:AddLine(WowF.dondeLaDaMision(q), 1, 1, 1, true) end
    if WowF.dondeSeEntrega then GameTooltip:AddLine(WowF.dondeSeEntrega(q), 1, 1, 1, true) end -- 9-oct (4.16)
    if WowF.lineaMisionTooltip then for _, l in ipairs(WowF.lineaMisionTooltip(q)) do GameTooltip:AddLine(l[1], l[2], l[3], l[4], true) end end
    local llevas = WowF.misionEnDiario and WowF.misionEnDiario(q.id)
    if llevas then GameTooltip:AddLine(L("Ya la llevas. Clic: ruta hasta quien la recibe", "You have it. Click: route to whoever takes it"), 0.2, 1, 0.4, true)
    elseif q.dentro then GameTooltip:AddLine(L("Clic: que hacer y a quien se entrega", "Click: what to do and who takes it"), 0.2, 1, 0.4, true)
    else
    GameTooltip:AddLine(WowF.T("Cogela ANTES de entrar y terminala dentro."), 1, 0.6, 0.2, true)
    GameTooltip:AddLine(WowF.T("Clic: ruta paso a paso hasta el"), 0.2, 1, 0.4)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:SetSize(276, 16)
  local f = E.cuerpo(b, nil, 10) -- 11-oct (hibrido): Signika; la fila va en dos columnas (pintarFicha)
  f:SetPoint("TOPLEFT", 4, -1)
  f:SetWidth(266)
  b.texto = f
  filasMision[i] = b
  return b
end
local misionCab = CreateFrame("Button", nil, ficha)
misionCab:SetSize(276, 18)
misionCab.texto = E.etiqueta(misionCab, nil, nil, 10) -- 11-oct (hibrido): cabecera como etiqueta brasa
misionCab.texto:SetPoint("LEFT", 0, 0)
misionCab.texto:SetWidth(276)
local misionCabRaya = E.textura(ficha, "ARTWORK", 1, E.color.borde, 1)
misionCabRaya:SetHeight(1)
misionCabRaya:Hide()
misionCab:Hide()
misionCab:SetScript("OnClick", function(self)
  if not self.activa then return end
  WowFExportarDB.fichaMisiones = (WowFExportarDB.fichaMisiones == false)
  pintarFicha()
end)
WowF.fichaMisionesClic = function() misionCab:GetScript("OnClick")(misionCab) end
pintarFicha = function()
  local d = fichaActual
  if not d then return end
  fichaIcono.id = d.id
  fichaIconoTex:SetTexture(d.id and iconoDe(d.id, d.ic) or ICONO_TIPO[d.tipo] or "Interface\\Icons\\INV_Misc_QuestionMark")
  fichaTitulo:SetText(WowF.T(d.id and (colorCalidad(d.q or 1) .. (d.nombre or "?") .. "|r") or (BLANCO .. (d.nombre or "") .. "|r")))
  fichaSub:SetText(WowF.T(d.sub or ""))
  -- 11-oct (hibrido): etiqueta brasa arriba y, en las mazmorras, datos grandes (piezas / misiones / fuera)
  local clave = tostring(d.clave or "")
  local ini = clave:sub(1, 1)
  local etq = (ini == "m" and L("Mazmorra", "Dungeon")) or (ini == "p" and L("Pieza de mazmorra", "Dungeon item"))
    or (ini == "e" and L("Receta", "Recipe")) or L("Paso del plan", "Plan step")
  fichaEtiq:SetText(E.mayus(etq))
  local y = -29 - 36 - 10
  local nd = 0
  if ini == "m" then
    local fuera = 0
    for _, q in ipairs(d.misiones or {}) do if not q.dentro then fuera = fuera + 1 end end
    local lista = { { #(d.mats or {}), L("Piezas", "Items") } }
    if #(d.misiones or {}) > 0 then table.insert(lista, { #d.misiones, L("Misiones", "Quests") }) end
    if fuera > 0 then table.insert(lista, { fuera, L("Fuera", "Outside") }) end
    for i, v in ipairs(lista) do
      nd = i
      local dt = fichaDatos[i]
      dt:poner(v[1], v[2])
      dt:ClearAllPoints()
      dt:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12 + (i - 1) * 84, y)
      dt:Show()
    end
    if nd > 0 then y = y - 36 end
  end
  for i = nd + 1, 3 do fichaDatos[i]:Hide() end
  fichaTexto:ClearAllPoints()
  fichaTexto:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, y)
  fichaTexto:SetText(WowF.T(d.pasos or ""))
  y = y - (tonumber(fichaTexto:GetStringHeight()) or 14) - 8
  local mats = d.mats or {}
  for i, g in ipairs(mats) do
    local b = filaMaterial(i)
    local tienes = (GetItemCount and GetItemCount(g[1], true)) or 0
    local hecho = tienes >= (g[2] or 1)
    b.id = g[1]
    b.tex:SetTexture(iconoDe(g[1], g[4]))
    local alto = 22
    if g.pieza then
      b.texto:SetText(WowF.T((tienes > 0 and (VERDE .. "[ya la tienes] |r") or "") .. colorCalidad(g.pieza.q or 2) .. (g[3] or "?") .. "|r " .. GRIS .. "(" .. (g.pieza.r or "") .. ", la suelta " .. (g.pieza.j or "?") .. ")|r")
        .. (g.pieza.porque and ("\n" .. VERDE .. g.pieza.porque .. "|r") or ""))
      -- Debajo, por que es mejor que lo que llevas: la fila crece con el texto
      alto = math.max(22, (tonumber(b.texto:GetStringHeight()) or 14) + 4)
    else
    b.texto:SetText(WowF.T(BLANCO .. (g[2] or 1) .. " x " .. (g[3] ~= "" and g[3] or ("objeto " .. g[1])) .. "|r  " .. (hecho and VERDE or "|cffff5555") .. "(tienes " .. tienes .. ")|r"))
    end
    b:SetHeight(alto)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, y)
    b:Show()
    y = y - alto - 2
  end
  for i = #mats + 1, #materiales do materiales[i]:Hide() end
  -- Misiones de dentro de la mazmorra: cabecera con el total (clic = desplegar/plegar) y una fila por mision
  local mis = d.misiones
  local nfil = 0
  if mis then
    y = y - 4
    -- 11-oct (hibrido): raya fina gris encima de la cabecera de misiones
    misionCabRaya:ClearAllPoints()
    misionCabRaya:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, y)
    misionCabRaya:SetPoint("TOPRIGHT", ficha, "TOPRIGHT", -12, y)
    misionCabRaya:Show()
    y = y - 6
    local abierta = not (WowFExportarDB.fichaMisiones == false)
    local cab
    if #mis == 0 then
      cab = BRASA .. "Misiones:|r " .. NARANJA .. "aun sin datos (se añadiran en proximas actualizaciones)|r"
    else
      cab = BRASA .. "Misiones de dentro: " .. #mis .. "|r" .. (d.xpMis > 0 and (VERDE .. "  " .. WowF.textoXP(d.xpMis, d.xpExacta) .. "|r") or (GRIS .. "  (hechas)|r"))
        .. GRIS .. (abierta and "   [-] ocultar" or "   [+] ver") .. "|r"
    end
    misionCab.texto:SetText(WowF.T(cab))
    misionCab.activa = #mis > 0
    misionCab:ClearAllPoints()
    misionCab:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, y)
    misionCab:Show()
    y = y - 20
    if #mis > 0 and abierta then
      local nivel = nivelActual()
      local k2, altoPar = 0, 0
      for _, q in ipairs(mis) do
        nfil = nfil + 1
        local r = filaMision(nfil)
        local c = q.hecha and GRIS or (nivel < q.nivel and NARANJA or BLANCO)
        r.texto:SetText(WowF.T(c .. q.n .. "|r" .. GRIS .. "  nv " .. q.nivel .. "|r  " .. (q.hecha and (GRIS .. "hecha|r") or (VERDE .. WowF.textoXP(WowF.xpMision(q)) .. "|r") .. (q.dentro and (GRIS .. " · dentro|r") or (q.quien and (nivel < q.nivel and (NARANJA .. L(" · AUN NO: nv " .. q.nivel, " · NOT YET: lvl " .. q.nivel) .. "|r") or (NARANJA .. " · fuera: clic|r")) or "")))))
        -- 9-oct (4.16): tambien las de dentro y las que ya llevas (raton = a quien se entrega; clic = ruta a la entrega)
        r.mision = (not q.hecha) and { quien = q.quien, m = (not q.dentro) and q.m or nil, x = q.x, y = q.y, q = { q } } or nil
        -- 11-oct (hibrido): dos columnas de 136 px; la fila de la derecha baja la altura del par
        local col = (k2 % 2)
        r.texto:SetWidth(128)
        local h = math.max(16, (tonumber(r.texto:GetStringHeight()) or 13) + 4)
        r:SetSize(134, h)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12 + col * 142, y)
        r:Show()
        altoPar = math.max(altoPar, h)
        if col == 1 then y = y - altoPar - 2; altoPar = 0 end
        k2 = k2 + 1
      end
      if altoPar > 0 then y = y - altoPar - 2 end
      local nota = filaMision(nfil + 1)
      nfil = nfil + 1
      nota.mision = nil
      nota.texto:SetWidth(266)
      nota.texto:SetText(WowF.T(GRIS .. "Las de fuera: cogelas antes de entrar. Clic en una = ruta hasta quien la da.|r"))
      local hn = math.max(16, (tonumber(nota.texto:GetStringHeight()) or 13) + 4)
      nota:SetSize(276, hn)
      nota:ClearAllPoints(); nota:SetPoint("TOPLEFT", ficha, "TOPLEFT", 12, y); nota:Show()
      y = y - hn - 2
    end
  else
    misionCab:Hide()
    misionCabRaya:Hide()
  end
  for i = nfil + 1, #filasMision do filasMision[i]:Hide() end
  ficha:SetHeight(-y + 10)
  ficha:ClearAllPoints()
  -- A la derecha del panel; a la izquierda solo si a la derecha no cabe en la pantalla
  local derecha = panel:GetRight()
  local ancho = (UIParent.GetWidth and UIParent:GetWidth()) or (GetScreenWidth and GetScreenWidth())
  if type(derecha) == "number" and type(ancho) == "number" and derecha + 6 + ficha:GetWidth() > ancho then ficha:SetPoint("TOPRIGHT", panel, "TOPLEFT", -6, 0) else ficha:SetPoint("TOPLEFT", panel, "TOPRIGHT", 6, 0) end
end

-- Arma la ficha de un paso del plan ({n, tipo, texto, i=, q=, m=}) o de una pieza de mazmorra ({pieza = o})
local function datosFicha(f)
  if f.mazmorra then
    local m = f.mazmorra
    local p = miPlan()
    local piezas = (WowF.piezasParaTi and WowF.piezasParaTi(p, m.i)) or (p and p.botin and p.botin[m.i]) or {}
    local nivel = nivelActual()
    local ideal = nivelIdeal(m)
    local estado = nivel < m.d and (GRIS .. "Se abre al nivel " .. m.d .. ".|r") or (nivel < ideal and (NARANJA .. "Ya puedes entrar; mejor al nivel " .. ideal .. ".|r") or (VERDE .. "Buen nivel: ve ya.|r"))
    local pasos = estado .. "\n" .. ORO .. "Nivel ideal:|r " .. ideal .. GRIS .. " (antes cuesta mucho; despues da poca experiencia)|r"
      .. "\n" .. ORO .. "Donde:|r " .. (m.z or "?") .. (m.m and (GRIS .. " (boton Marcar mazmorra del panel)|r") or "")
      .. "\n" .. ORO .. "Por que ir:|r " .. (#piezas > 0 and ("te pueden caer " .. #piezas .. " piezas que te sirven:") or "experiencia y botin; para tu plan no hay piezas aqui.")
    local mats = {}
    for _, o in ipairs(piezas) do table.insert(mats, { o.id, 0, o.n, o.ic, pieza = o }) end
    local misiones, xpMis, xpExacta = {}, 0, false
    if WowF.misionesDe then misiones, xpMis, xpExacta = WowF.misionesDe(m) end
    return { clave = "m" .. (m.i or m.n), tipo = "zona", nombre = m.n, sub = GRIS .. "Mazmorra · niveles " .. m.d .. "-" .. m.h .. "|r", pasos = pasos, mats = mats, misiones = misiones, xpMis = xpMis, xpExacta = xpExacta }
  end
  if f.pieza then
    local o = f.pieza
    return { clave = "p" .. o.id, id = o.id, ic = o.ic, q = o.q, nombre = o.n, sub = GRIS .. (o.r or "") .. "|r",
      -- 4-oct: "pide Need" solo si se comparo de verdad con lo que llevas (o.mejora, wowF_Comparar.lua)
      pasos = (tengo(o.id) and (VERDE .. "Ya la tienes.|r\n") or "") .. ORO .. "La suelta:|r " .. (o.j or "?")
        -- 7-oct: mejora pequena (o.dudosa, pierdes algo que cuenta) = dorado y sin pedir Need; el porque corto (lo que ganas y lo que pierdes)
        .. ((o.mejora ~= false) and "\nSi cae, pide Need: es una mejora para ti." or (o.dudosa and L("\nMejora pequeña: depende de ti, no hace falta pedir Need.", "\nSmall upgrade: your call, no need to roll Need.") or "\nSi cae, comparala con lo que llevas antes de pedir Need."))
        .. (o.porque and ("\n" .. (o.dudosa and "|cffffd100" or VERDE) .. (o.porqueCorto or o.porque) .. "|r") or "") }
  end
  local e = f.evento
  local trozos = {}
  for t in (tostring(e[3] or "") .. " · "):gmatch("(.-) · ") do if t ~= "" then table.insert(trozos, t) end end
  if e.i then
    -- "Handstitched Leather Belt (Waist, Leather) · Leatherworking 1 (estimado) · Entrenador"
    local nombre, ranura = (trozos[1] or ""):match("^(.-) %((.-)%)$")
    nombre = nombre or trozos[1] or "?"
    local prof, fuente = (trozos[2] or ""):gsub(" %d+ %(estimado%)", " " .. L("(nivel aun no disponible en WoW Forever; se actualizara)", "(level not yet available in WoW Forever; will be updated)")), trozos[3] or "" -- 9-oct: sin nivel estimado
    local pasos = ORO .. "1.|r Aprende la receta: " .. BLANCO .. prof .. "|r" .. (fuente ~= "" and (GRIS .. " (" .. fuente .. ")|r") or "")
      .. "\n" .. ORO .. "2.|r Junta los materiales de abajo."
      .. "\n" .. ORO .. "3.|r Fabricala y equipala" .. (ranura and (" (" .. ranura .. ")") or "") .. "."
    if tengo(e.i) then pasos = VERDE .. "Ya la tienes.|r\n" .. pasos end
    return { clave = "e" .. e.i .. "-" .. (e[1] or 0), id = e.i, ic = e.ic, q = e.q, nombre = nombre, sub = GRIS .. "Nivel " .. (e[1] or "?") .. (ranura and (" · " .. ranura) or "") .. "|r", pasos = pasos, mats = e.m }
  end
  local titulos = { hito = "Lo que toca", talento = "Talento", rama = "Rama", prof = "Profesion", zona = "Zona" }
  return { clave = "t" .. tostring(e[2]) .. (e[1] or 0) .. (e[3] or ""):sub(1, 20), tipo = e[2], nombre = titulos[e[2]] or "Paso", sub = GRIS .. "Nivel " .. (e[1] or "?") .. "|r",
    pasos = table.concat(trozos, "\n") }
end

WowF.abrirFicha = function(f)
  if f.accion then f.accion(); return end
  local d = datosFicha(f)
  if fichaActual and fichaActual.clave == d.clave and ficha:IsShown() then ficha:Hide(); fichaActual = nil; return end
  d.origen = f
  fichaActual = d
  pintarFicha()
  ficha:Show()
end
local function refrescarFicha()
  if fichaActual and ficha:IsShown() then
    local d = datosFicha(fichaActual.origen)
    d.origen = fichaActual.origen
    fichaActual = d
    pintarFicha()
  end
end
cerrarFicha:SetScript("OnClick", function() ficha:Hide(); fichaActual = nil end)

-- ===================== Contenido del panel =====================
local ETIQUETA = { hito = ORO, talento = CELESTE .. "Talento: ", prof = NARANJA .. "Profesion: ", zona = VERDE, equipo = BLANCO .. "Fabrica: ", rama = CELESTE .. "Rama: " }
local ORDEN = { hito = 1, talento = 2, rama = 3, prof = 4, zona = 5, equipo = 6 }
local function eventosDe(p, nivel)
  local lista = {}
  for _, e in ipairs(p.eventos or {}) do if e[1] == nivel then table.insert(lista, e) end end
  table.sort(lista, function(a, b) return (ORDEN[a[2]] or 9) < (ORDEN[b[2]] or 9) end)
  return lista
end
local function seguro(fn, ...) if type(fn) ~= "function" then return nil end local ok, r = pcall(fn, ...); if ok then return r end return nil end
local SIN_DATOS = { "aún no hay datos de WoW Forever; pendiente de actualizar", "no WoW Forever data yet; pending update" }

-- 11-oct (tarjetas): .tj (piedra2 con borde), .tj.prin (raya de 3 px del tema arriba), .tj.mz (#2b2421)
local tarjetas = {}
local function tarjeta(i)
  if not tarjetas[i] then
    local t = E.tarjeta(panel, {})
    t:EnableMouse(false)
    tarjetas[i] = t
  end
  nivelSobre(tarjetas[i], 1)
  return tarjetas[i]
end
-- Colores de la puntuacion: rojo < 40, ambar 40-75, verde > 75
local function colorPuntos(v)
  if v < 40 then return { 0.78, 0.25, 0.2 }, "|cffc7402f" end
  if v <= 75 then return { 0.902, 0.643, 0.2 }, "|cffe6a433" end
  return E.color.verde, E.cod.verde
end
-- El tramo de zonas que toca a tu nivel (mismo criterio que la pestana Progreso del Libro)
local function tramoActual(nivel)
  local g = WowF.planZonas and seguro(WowF.planZonas)
  if type(g) ~= "table" or type(g.tramos) ~= "table" then return nil end
  for i, t in ipairs(g.tramos) do
    if nivel <= (t.hasta or 0) then
      local d = WowF.detalleTramo and seguro(WowF.detalleTramo, t, i, g)
      if type(d) == "table" and d.z and d.z.n then return t, i, d end
      return nil
    end
  end
  return nil
end

actualizar = function()
  if not panel:IsShown() then return end
  local nivel = nivelActual()
  local plegado = WowFExportarDB.panel and WowFExportarDB.panel.plegado
  sello.num:SetText(tostring(nivel))
  if sello.fondo.SetColorTexture then local c = E.tema().toggleOn or E.color.cera; sello.fondo:SetColorTexture(c[1], c[2], c[3], 1) end
  if retratoPanel.actualizar then pcall(retratoPanel.actualizar, retratoPanel) end
  plegar:SetText(plegado and "+" or "–")
  losaVisible(not plegado)
  -- filas: { tipo = "sec"|"suelta"|"zona"|"item"|"texto"|"prof"|"mz"|"cajas"|"aviso"|"botones", ... } (se pintan abajo)
  local filas = {}
  local function sec(rot, opts) opts = opts or {}; opts.tipo = "sec"; opts.rot = rot; table.insert(filas, opts) end
  local function add(f) table.insert(filas, f); return f end
  -- Un paso del plan: nombre (13) y detalle (12 tenue), icono de 28 (oro = talento/rama; gris = lo de despues)
  local function filaEvento(e, apagado)
    local ic = (e.ic and e.ic ~= "" and ("Interface\\Icons\\" .. e.ic)) or nil
    if e[2] == "equipo" then
      local nombre, ranura = (primerTrozo(e[3], 200)):match("^(.-) %((.-)%)$")
      nombre = nombre or primerTrozo(e[3], 60)
      local prof = (tostring(e[3]):match(" · (.-) · ") or ""):gsub(" %d+ %(estimado%)", " " .. L("(nivel aun no disponible en WoW Forever; se actualizara)", "(level not yet available in WoW Forever; will be updated)")) -- 9-oct: nivel de receta estimado (Classic) = aviso
      local v, porque = nil, nil
      if WowF.valeLaPena then v, porque = WowF.valeLaPena(e) end
      local veredicto = v == "si" and (E.cod.verde .. L("VALE LA PENA: ", "WORTH IT: ") .. "|r") or ""
      add({ tipo = "item", nombre = listo(L("Fabrícate: ", "Craft: ")) .. colorCalidad(e.q or 1) .. nombre .. "|r",
        peq = veredicto .. (porque or ranura or "") .. (prof ~= "" and (" · " .. prof) or ""),
        ayuda = e[3], ficha = { evento = e }, icono = iconoDe(e.i, ic), col = apagado and "gris" or nil })
    else
      local esZona = e[2] == "zona" and e.tramo and WowF.irAZona
      local t = WowF.T(tostring(e[3] or ""))
      local nombre = t:match("^(.-) · ") or t
      local resto = t:match(" · (.*)$")
      if #nombre > 80 then nombre = nombre:sub(1, 77) .. "..." end
      local tipoTxt = ({ talento = L("Talento", "Talent"), rama = L("Rama", "Spec"), prof = L("Profesión", "Profession") })[e[2]]
      add({ tipo = "item", nombre = WowF.yaTraducido and WowF.yaTraducido(nombre) or nombre,
        peq = resto and primerTrozo(resto, 80) or tipoTxt,
        ayuda = esZona and WowF.ayudaTramo(e.tramo, e.indice) or e[3],
        ficha = esZona and { evento = e, accion = function() WowF.irAZona(e.tramo) end } or { evento = e },
        icono = ic or (e[2] == "talento" and WowF.iconoHechizo and WowF.iconoHechizo(tostring(e[3] or ""):match("^(.-) %(") or tostring(e[3] or ""):match("^(.-) · ") or tostring(e[3] or ""))) or ICONO_TIPO[e[2]] or ICONO_TIPO.hito,
        col = apagado and "gris" or ((e[2] == "talento" or e[2] == "rama") and "oro" or nil) })
    end
  end
  local p = miPlan()
  local abrirProf = { accion = function() if WowF.abrirLibro then WowF.abrirLibro("Profesiones") end end }
  if not plegado then
    local piezas = piezasAqui()
    if enInstancia and piezas then
      -- Dentro de la mazmorra: tus piezas y las misiones de aqui
      sec(L("Dentro de la mazmorra", "Inside the dungeon"), { variante = "principal" })
      add({ tipo = "zona", h3 = nombreInstancia, sub = listo(L(#piezas .. (#piezas == 1 and " pieza para ti aquí" or " piezas para ti aquí"),
        #piezas .. (#piezas == 1 and " item for you here" or " items for you here"))) })
      for _, o in ipairs(piezas) do
        local marca = tengo(o.id) and (E.cod.verde .. L("[ya la tienes] ", "[you have it] ") .. "|r") or ""
        add({ tipo = "item", nombre = marca .. colorCalidad(o.q or 2) .. o.n .. "|r",
          peq = (o.r or "") .. L(" · la suelta ", " · dropped by ") .. (o.j or "?") .. (o.porque and ("\n" .. (o.dudosa and "|cffffd100" or E.cod.verde) .. o.porque .. "|r") or ""),
          ayuda = o.n .. L("\nLa suelta: ", "\nDropped by: ") .. (o.j or "?") .. L("\nRanura: ", "\nSlot: ") .. (o.r or "?") .. (o.porque and ("\n" .. o.porque) or ""),
          ficha = { pieza = o }, icono = iconoDe(o.id, o.ic), col = tengo(o.id) and "verde" or "oro" })
      end
      local mis = misionesAqui()
      for _, q in ipairs(mis) do
        if not q.hecha then
          local txp = WowF.textoXP(WowF.xpMision(q))
          add({ tipo = "item", nombre = q.n, peq = L("Misión de esta mazmorra", "Quest for this dungeon") .. (txp ~= "" and (" · " .. E.cod.verde .. txp .. "|r") or ""),
            ayuda = q.n .. L("\nMision de esta mazmorra", "\nQuest for this dungeon") .. (txp ~= "" and (": " .. txp) or "") .. L("\nDesde nivel ", "\nFrom level ") .. q.nivel,
            icono = "Interface\\Icons\\INV_Misc_Note_01" })
        end
      end
    elseif not p then
      sec(L("Ahora · nivel ", "Now · level ") .. nivel, { variante = "principal" })
      add({ tipo = "texto", texto = GRIS .. L("Sin datos del plan para esta clase. Reinstala el addon Forever Leveling Guide.", "No plan data for this class. Reinstall the Forever Leveling Guide addon.") .. "|r" })
    else
      -- Tu rama (fuera de tarjeta) y la puntuacion del equipo (compacta)
      add({ tipo = "rama", rama = p.rama or "?" })
      local pu = WowF.puntuacionEquipo and seguro(WowF.puntuacionEquipo)
      if type(pu) == "table" and type(pu.total) == "number" then add({ tipo = "puntos", pu = pu }) end
      -- Las piezas que no vale la pena fabricar (duran 1-2 niveles o ya llevas algo igual) no ocupan sitio aqui
      local function utiles(lista)
        local res, fuera = {}, 0
        local fab = not WowF.mejorasDe or WowF.mejorasDe("fabricar") -- 8-oct: fabricadas apagadas en Ajustes = no salen
        for _, e in ipairs(lista) do
          local v = (e[2] == "equipo" and WowF.valeLaPena) and WowF.valeLaPena(e) or nil
          if e[2] == "equipo" and not fab then -- nada
          elseif v == "opcional" or v == "ya" then fuera = fuera + 1 else table.insert(res, e) end
        end
        return res, fuera
      end
      -- AHORA: la zona donde subir (h3 + "Llevame") y lo nuevo de tu nivel
      local tramo, indice, dt = tramoActual(nivel)
      local ahora, fuera = utiles(eventosDe(p, nivel))
      if tramo then
        local sinZona = {}
        for _, e in ipairs(ahora) do if e[2] ~= "zona" then table.insert(sinZona, e) end end
        ahora = sinZona
      end
      sec(L("Ahora · nivel ", "Now · level ") .. nivel, { variante = "principal", ayuda = L("Tu rama: ", "Your spec: ") .. (p.rama or "?"),
        ficha = { accion = function() if WowF.abrirLibro then WowF.abrirLibro("Progreso") end end } })
      if tramo then
        local pueblo = dt.pueblo and (dt.pueblo.n or dt.pueblo.npc) or nil
        add({ tipo = "zona", h3 = listo(L("Sube en " .. dt.z.n, "Level in " .. dt.z.n)),
          sub = listo(L("Niveles " .. tramo.desde .. "-" .. tramo.hasta .. " · " .. (dt.n or 0) .. " misiones", "Levels " .. tramo.desde .. "-" .. tramo.hasta .. " · " .. (dt.n or 0) .. " quests") .. (pueblo and (" · " .. pueblo) or "")),
          boton = L("Llévame ›", "Take me ›"), fn = function() if WowF.irAZona then WowF.irAZona(tramo) end end,
          ayuda = WowF.ayudaTramo and seguro(WowF.ayudaTramo, tramo, indice) })
      end
      if #ahora == 0 and not tramo then add({ tipo = "texto", texto = GRIS .. L("Nada nuevo: sigue subiendo.", "Nothing new: keep leveling.") .. "|r" }) end
      for i, e in ipairs(ahora) do
        if i > 4 then
          add({ tipo = "texto", texto = GRIS .. "+" .. (#ahora - 4) .. L(" más", " more") .. "|r  " .. E.cod.verde .. L("clic: ver todo", "click: see all") .. "|r",
            ficha = { accion = function() if WowF.abrirLibro then WowF.abrirLibro("Progreso") end end } })
          break
        end
        filaEvento(e, false)
      end
      if fuera > 0 then
        add({ tipo = "texto", texto = GRIS .. listo(L(fuera .. (fuera == 1 and " pieza opcional" or " piezas opcionales") .. " (te duran poco o ya llevas algo igual)",
          fuera .. (fuera == 1 and " optional item" or " optional items") .. " (they last little or you already wear something as good)")) .. "|r", ficha = abrirProf })
      end
      local mostrado = {}
      for _, e in ipairs(ahora) do mostrado[e] = true end
      -- PROXIMO: lo del siguiente nivel con algo nuevo (solo hasta el tope de la beta)
      for n = nivel + 1, (WowFDatos and WowFDatos.topeBeta) or 30 do
        local luego = utiles(eventosDe(p, n))
        if #luego > 0 then
          local faltan = n - nivel
          sec(L("Próximo · nivel ", "Next · level ") .. n, { color = E.color.oro, der = listo(L("en " .. faltan .. (faltan == 1 and " nivel" or " niveles"), "in " .. faltan .. (faltan == 1 and " level" or " levels"))) })
          for i, e in ipairs(luego) do
            if i > 2 then break end
            mostrado[e] = true
            filaEvento(e, true)
          end
          break
        end
      end
      -- PROFESIONES: tus principales con su rango y barra; "ruta de farmeo" a la derecha
      sec(L("Profesiones", "Professions"), { color = E.color.oro, terc = L("ruta de farmeo", "farming route"),
        tercFn = function() local fn = botonFarmeo:GetScript("OnClick"); if fn then fn(botonFarmeo) end end })
      local hayProf = false
      for _, pr in ipairs(WowF.profesiones and seguro(WowF.profesiones) or {}) do
        if pr.principal then
          hayProf = true
          add({ tipo = "prof", nombre = pr.en or pr.nombre or "?", r = tonumber(WowF.numero and WowF.numero(pr.rango) or pr.rango) or 0,
            max = tonumber(WowF.numero and WowF.numero(pr.maximo) or pr.maximo) or 0,
            icono = (WowF.ICONO_PROF and WowF.ICONO_PROF[pr.id]) or "Interface\\Icons\\INV_Misc_Gear_01", ficha = abrirProf })
        end
      end
      if not hayProf then
        add({ tipo = "texto", texto = GRIS .. L("Aún no tienes profesiones principales. ", "You have no main professions yet. ") .. "|r" .. E.cod.verde .. L("clic: elegir", "click: choose") .. "|r", ficha = abrirProf })
      end
      -- FABRICAR: la proxima pieza que vale la pena hacerse (o la que harias con la profesion recomendada)
      local propia, sugerida = nil, false
      local fabricarSi = not WowF.mejorasDe or WowF.mejorasDe("fabricar")
      for _, e in ipairs(p.eventos or {}) do
        if fabricarSi and e[2] == "equipo" and e[1] > nivel and not mostrado[e] and WowF.valeLaPena and WowF.valeLaPena(e) == "si" then propia = e; break end
      end
      if fabricarSi and not propia and p.sugerida then
        for _, e in ipairs(p.sugerida.piezas or {}) do
          if e[1] >= nivel and WowF.valeLaPena and WowF.valeLaPena(e) == "si" then propia = e; sugerida = true; break end
        end
      end
      -- 5-oct: con objetivo "oro" o "pvp", en vez de FABRICAR sale lo primero para vender / para PvP (wowF_ProfObjetivo.lua)
      local obj = WowF.objetivo and WowF.objetivo() or "fabricar"
      if obj ~= "fabricar" then
        propia = nil
        local d = WowF.destacadoObjetivoProf and WowF.destacadoObjetivoProf()
        if d then
          sec(obj == "oro" and L("Vender", "Sell") or L("Para PvP", "For PvP"), { color = E.color.oro, der = L("clic: ver la lista", "click: see the list"), ficha = abrirProf })
          add({ tipo = "item", nombre = listo((d.tipo == "recoge" and L("Recoge: ", "Gather: ") or L("Fabrica: ", "Craft: ")) .. colorCalidad(d.q or 1) .. d.nombre .. "|r"),
            peq = listo(d.detalle or ""), ficha = abrirProf, icono = d.id and iconoDe(d.id, type(d.icono) == "string" and d.icono or nil) or d.icono })
        end
      end
      if propia then
        sec(L("Fabricar", "Craft"), { color = E.color.oro, der = sugerida and listo(L("si aprendes " .. p.sugerida.nombre, "if you learn " .. p.sugerida.nombre)) or listo(L("al nivel " .. propia[1], "at level " .. propia[1])) })
        filaEvento(propia, false)
      end
    end
    -- MAZMORRA: hasta 3 para tu nivel; la primera con cifras, misiones de fuera (cajas) y el aviso
    local recomendadas = (not enInstancia) and mazmorrasRecomendadas() or {}
    local FONDO_MZ = { 0.169, 0.141, 0.129 }
    for k, m in ipairs(recomendadas) do
      local ideal = nivelIdeal(m)
      local estado, estadoLargo
      if nivel < m.d then
        estado = L("se abre al " .. m.d, "opens at " .. m.d)
        estadoLargo = GRIS .. L("Se abre al nivel " .. m.d .. ". Lo ideal: ir al " .. ideal .. ".", "Opens at level " .. m.d .. ". Best: go at " .. ideal .. ".") .. "|r"
      elseif nivel < ideal then
        estado = L("ya puedes entrar", "you can enter")
        estadoLargo = NARANJA .. L("Ya puedes entrar, pero mejor ve al nivel " .. ideal, "You can enter, but better go at level " .. ideal) .. "|r " .. GRIS .. L("(te faltan " .. (ideal - nivel) .. ")", "(" .. (ideal - nivel) .. " to go)") .. "|r"
      else
        estado = L("buen nivel: ve ya", "good level: go now")
        estadoLargo = E.cod.verde .. L("Buen nivel: ve ya.", "Good level: go now.") .. "|r"
      end
      local suyas = (WowF.piezasParaTi and WowF.piezasParaTi(p, m.i)) or (p and p.botin and p.botin[m.i]) or {}
      local ayudaMz = m.n .. L(" (niveles ", " (levels ") .. m.d .. L(" a ", " to ") .. m.h .. L(")\nNivel ideal para ir: ", ")\nIdeal level to go: ") .. ideal
        .. L(" (estimacion de la guia: la mitad del rango de niveles)\n", " (guide estimate: the middle of the level range)\n") .. m.z
        .. ((m.a or not m.m) and L("\nEntrada aun sin confirmar en WoW Forever: se actualizara en proximas actualizaciones.", "\nEntrance not confirmed in WoW Forever yet: it will be updated in future updates.") or "")
      if k == 1 then
        if #recomendadas > 1 then
          sec(listo(L("Mazmorras para tu nivel (" .. #recomendadas .. ")", "Dungeons for your level (" .. #recomendadas .. ")")), { fondo = FONDO_MZ })
        else
          sec(listo(L("Mazmorra · ", "Dungeon · ") .. estado), { fondo = FONDO_MZ, der = listo(L("ideal al " .. ideal, "ideal at " .. ideal)) })
        end
      end
      -- Misiones de la mazmorra: cuantas, cuantas se cogen FUERA y las que aun no te dan
      local misM, nFuera, grupos, aviso = {}, 0, {}, {}
      if WowF.misionesDe then misM = WowF.misionesDe(m) or {} end
      if WowF.misionesFueraDe then grupos = WowF.misionesFueraDe(m) or {} end
      for _, g in ipairs(grupos) do nFuera = nFuera + #g.q end
      if k == 1 then
        if #misM > 0 then
          local aunNo, minNv = 0, nil
          for _, g in ipairs(grupos) do for _, q in ipairs(g.q) do
            if (q.nivel or 0) > nivel then aunNo = aunNo + 1; if not minNv or q.nivel < minNv then minNv = q.nivel end end
          end end
          -- 11-oct (maqueta): en el panel, una linea corta; el detalle de cada mision va en el tooltip de la mazmorra
          if aunNo > 0 then
            local resumen = WowF.resumenNivelesFuera and WowF.resumenNivelesFuera(m)
            if resumen then ayudaMz = ayudaMz .. "\n\n" .. resumen end
            table.insert(aviso, (aunNo >= nFuera) and L("Aún no te dan ninguna: la primera, al nivel " .. minNv .. ".", "None available yet: the first one at level " .. minNv .. ".")
              or L("Ya puedes coger " .. (nFuera - aunNo) .. " de " .. nFuera .. "; el resto, desde el nivel " .. minNv .. ".", "You can take " .. (nFuera - aunNo) .. " of " .. nFuera .. "; the rest from level " .. minNv .. "."))
          end
        else
          table.insert(aviso, NARANJA .. L("Misiones: " .. SIN_DATOS[1], "Quests: " .. SIN_DATOS[2]) .. "|r")
        end
      end
      local pocas = WowF.porQuePocas and WowF.porQuePocas(p, m.i, suyas)
      if pocas then -- 11-oct (maqueta): solo la primera frase; el porque completo, en el tooltip
        ayudaMz = ayudaMz .. "\n\n" .. pocas
        pocas = pocas:match("^[^;]+") or pocas
        table.insert(aviso, pocas:find("%.$") and pocas or (pocas .. "."))
      end
      for _, bp in ipairs(WowF.campamentoFicha and WowF.campamentoFicha(m.n) or {}) do table.insert(aviso, bp) end -- 8-oct: Blueprints (wowF_Campamento.lua)
      add({ tipo = "mz", m = m, k = k, varias = #recomendadas > 1, estado = estado, estadoLargo = estadoLargo, ideal = ideal,
        cifras = { { #suyas, L("Piezas", "Items") }, { #misM, L("Misiones", "Quests") }, { nFuera, L("Fuera", "Outside") } },
        ayuda = ayudaMz, ficha = { mazmorra = m } })
      if k == 1 and #grupos > 0 then add({ tipo = "cajas", grupos = grupos }) end
      if #aviso > 0 then add({ tipo = "aviso", texto = table.concat(aviso, "\n") }) end
      if k > 1 then add({ tipo = "botones", m = m, par = k }) end
    end
    if ruta then
      local punto = ruta.zona.ruta[ruta.i]
      local n = math.floor(#(punto[5] or {}) / 2)
      sec(L("Farmeo", "Farming"), { color = E.color.oro, der = listo(ruta.nombre .. L(" en ", " in ") .. ruta.zona.n) })
      add({ tipo = "item", nombre = listo(L("Punto mas cercano", "Nearest point") .. GRIS .. "  (" .. punto[4] .. ")  ·  " .. L("quedan ", "left ") .. quedan() .. L(" de ", " of ") .. #ruta.zona.ruta .. "|r"),
        peq = listo(E.cod.verde .. L(n .. " sitios alrededor: cuadritos verdes del mapa (M)", n .. " spots around: green squares on the map (M)") .. "|r"
          .. (ruta.sugerida and ("\n" .. NARANJA .. L("(sugerencia: no la tienes)", "(suggestion: you do not have it)") .. "|r") or ("\n" .. L("Habilidad ", "Skill ") .. ruta.rango))),
        ayuda = "Sigue la flecha: siempre apunta al punto sin recorrer mas cercano a ti (el circulo VERDE con el 1 en el mapa, M).\nAl llegar, recorre los cuadritos verdes de alrededor: ahi aparecen las vetas o hierbas.\nLuego la flecha salta sola al siguiente mas cercano. Si otro jugador ya las recogio, salen de nuevo en unos minutos.",
        icono = "Interface\\Icons\\INV_Misc_Map_01" })
    end
  end

  -- ===== Pintar =====
  local y = -(ARRIBA + 10)
  local nl, nc, nt = 0, 0, 0
  local arribaT = nil
  local primeraEnTarjeta = true
  local function cerrarTarjeta()
    if not arribaT then return end
    tarjetas[nt]:SetHeight(math.max(20, arribaT - y + 12))
    y = y - 10 - 6
    arribaT = nil
  end
  local function abrirTarjeta(f)
    cerrarTarjeta()
    nt = nt + 1
    local t = tarjeta(nt)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", panel, "TOPLEFT", X0, y)
    t:SetWidth(W)
    local fondo = f and f.fondo or E.color.piedra2
    if t.SetBackdropColor then pcall(t.SetBackdropColor, t, fondo[1], fondo[2], fondo[3], 1) end
    E.tarjetaVariante(t, f and f.variante or nil)
    t:Show()
    arribaT = y
    y = y - 11
    primeraEnTarjeta = true
  end
  local function limpiar(l)
    for _, k in ipairs({ "rot", "der", "h3", "sub", "texto", "peq" }) do l[k]:SetText(""); l[k]:Hide(); l[k]:ClearAllPoints() end
    l.ic:Hide(); l.barra:Hide(); l.raya:Hide(); l.terc:Hide(); l.accion:Hide()
    for _, c in ipairs(l.cifras) do c:Hide() end
    l.ficha, l.ayuda, l.fn, l.pista = nil, nil, nil, nil
    l.brillo:Hide()
  end
  for _, par in ipairs(paresMazmorra) do par.ir:Hide(); par.mis:Hide(); par.ir.mazmorra = nil; par.mis.mazmorra = nil; nivelSobre(par.ir, 4); nivelSobre(par.mis, 4) end
  -- Texto del boton de misiones de fuera de una mazmorra ("Misiones 2/5" o "Quitar misiones")
  local function ponerPar(par, m)
    local hayIr, hayMis = false, false
    if par and m.m then par.ir.mazmorra = m; hayIr = true end
    if par and WowF.misionesFueraDe and WowF.marcarTodasMisiones then
      local yaMarcadas = WowF.misionesMarcadasDe and WowF.misionesMarcadasDe(m)
      local n, ya = 0, 0
      for _, g in ipairs(WowF.misionesFueraDe(m)) do n = n + #g.q; for _, q in ipairs(g.q) do if nivel >= (q.nivel or 0) then ya = ya + 1 end end end
      if yaMarcadas or n > 0 then
        par.mis.mazmorra = m
        par.mis:SetText(yaMarcadas and WowF.T("Quitar misiones") or listo(L("Misiones ", "Quests ") .. ya .. "/" .. n))
        hayMis = true
      end
    end
    return hayIr, hayMis
  end
  local function fila(x, w, alto, l)
    l:SetWidth(w); l:SetHeight(math.max(1, alto))
    l:ClearAllPoints(); l:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y); l:Show()
  end
  local function altoDe(fs, minimo) return math.max(minimo or 0, tonumber(fs:GetStringHeight()) or 13) end
  for _, f in ipairs(filas) do
    if f.tipo == "sec" then
      abrirTarjeta(f)
      nl = nl + 1
      local l = linea(nl); limpiar(l); nivelSobre(l, 3)
      l.rot:SetTextColor((f.color or E.color.brasa)[1], (f.color or E.color.brasa)[2], (f.color or E.color.brasa)[3])
      l.rot:SetPoint("TOPLEFT", 0, 0); E.ponerRotulo(l.rot, WowF.T(f.rot)); l.rot:Show()
      if f.terc then
        l.terc:SetText(f.terc); E.botonAncho(l.terc, false, 40); l.terc:ClearAllPoints(); l.terc:SetPoint("TOPRIGHT", 0, 2); l.terc.fn = f.tercFn; l.terc:Show()
      elseif f.der then
        l.der:SetPoint("TOPRIGHT", 0, 0); l.der:SetText(f.der); l.der:Show()
      end
      l.ficha, l.ayuda = f.ficha, f.ayuda
      fila(XT, WT, 16, l)
      y = y - 16
      primeraEnTarjeta = false
    elseif f.tipo == "rama" or f.tipo == "puntos" then
      cerrarTarjeta()
      nl = nl + 1
      local l = linea(nl); limpiar(l); nivelSobre(l, 3)
      if f.tipo == "rama" then
        l.texto:SetPoint("LEFT", 2, 0); l.texto:SetWidth(W - 80)
        l.texto:SetText(E.cod.tenue .. WowF.T(L("Tu rama: ", "Your spec: ")) .. "|r" .. E.cod.texto .. WowF.T(f.rama or "") .. "|r"); l.texto:Show()
        l.terc:SetText(L("cambiar", "change")); E.botonAncho(l.terc, false, 40); l.terc:ClearAllPoints(); l.terc:SetPoint("RIGHT", 0, 0)
        l.terc.fn = function() if WowF.abrirLibro then WowF.abrirLibro("Talentos") end end; l.terc:Show()
        l.ayuda = L("Tu rama: ", "Your spec: ") .. f.rama .. L("\nCambiala en /wowf plan > Talentos.", "\nChange it in /wowf plan > Talents.")
        fila(X0, W, 20, l)
        y = y - 20 - 8
      else
        local pu = f.pu
        local v = math.max(0, math.min(100, math.floor((pu.total or 0) + 0.5)))
        local rgb, cod = colorPuntos(v)
        l.texto:SetPoint("TOPLEFT", 2, 0); l.texto:SetWidth(W - 90)
        l.texto:SetText(E.cod.tenue .. L("Equipo", "Gear") .. "|r"); l.texto:Show()
        l.der:SetPoint("TOPRIGHT", -2, 0); l.der:SetText(cod .. v .. " / 100|r"); l.der:Show()
        l.barra:ClearAllPoints(); l.barra:SetPoint("TOPLEFT", 2, -18); l.barra:SetWidth(W - 4); l.barra:poner(v, 100)
        if l.barra.relleno.SetColorTexture then l.barra.relleno:SetColorTexture(rgb[1], rgb[2], rgb[3], 1) end
        l.barra:Show()
        l.ayuda = (WowF.puntuacionFrase and seguro(WowF.puntuacionFrase, pu)) or L("Tu equipo frente a lo mejor que puedes tener ya. Clic: ver Equipo.", "Your gear against the best you can get now. Click: see Gear.")
        l.fn = function() if WowF.abrirLibro then WowF.abrirLibro("Equipo") end end
        fila(X0, W, 28, l)
        y = y - 28 - 8
      end
    elseif f.tipo == "cajas" then
      if not arribaT then abrirTarjeta() end
      y = y - 10
      -- 11-oct (Andy: "esto no se entiende que es"): titulo encima de las cajas
      nl = nl + 1
      local lc = linea(nl); limpiar(lc); nivelSobre(lc, 3)
      lc.texto:SetPoint("TOPLEFT", 0, 0); lc.texto:SetWidth(WT)
      lc.texto:SetText(listo(ORO .. L("Misiones para esta mazmorra: pídelas ANTES de entrar", "Quests for this dungeon: pick them up BEFORE going in") .. "|r\n"
        .. GRIS .. L("Quién te la da y dónde. Clic en una: te llevo al NPC.", "Who gives it and where. Click one: I take you to the NPC.") .. "|r"))
      lc.texto:Show()
      lc.ayuda = L("Estas misiones se piden FUERA de la mazmorra, en ciudades y pueblos. Si las coges antes de entrar, las completas dentro y ganas mucha más experiencia y mejores recompensas.\nCada caja: nombre de la misión (+N = más misiones del mismo NPC), y debajo quién la da y en qué ciudad.\nClic en una caja: ruta hasta ese NPC.",
        "These quests are picked up OUTSIDE the dungeon, in cities and towns. If you take them before going in, you complete them inside and get much more experience and better rewards.\nEach box: quest name (+N = more quests from the same NPC), and below who gives it and in which city.\nClick a box: route to that NPC.")
      local altoC = altoDe(lc.texto, 26)
      fila(XT, WT, altoC, lc)
      y = y - altoC - 6
      local cw = math.floor((WT - 6) / 2)
      local n = math.min(4, #f.grupos)
      for i = 1, n do
        local g = f.grupos[i]
        nc = nc + 1
        local c = caja(nc); nivelSobre(c, 3)
        local col, filaC = (i - 1) % 2, math.floor((i - 1) / 2)
        c:SetSize(cw, 40)
        c:ClearAllPoints(); c:SetPoint("TOPLEFT", panel, "TOPLEFT", XT + col * (cw + 6), y - filaC * 46)
        local q1 = g.q[1] or {}
        c.t:SetWidth(cw - 16); c.s:SetWidth(cw - 16)
        c.t:SetText(WowF.yaTraducido and WowF.yaTraducido((q1.n or "?") .. (#g.q > 1 and (" +" .. (#g.q - 1)) or "")) or (q1.n or "?"))
        local ciudad = WowF.nombreZona and g.m and seguro(WowF.nombreZona, g.m)
        c.s:SetText((g.quien or "?") .. ((type(ciudad) == "string" and ciudad ~= "") and (" · " .. ciudad) or ""))
        local partes = { ORO .. (g.quien or "?") .. "|r" .. ((type(ciudad) == "string" and ciudad ~= "") and (GRIS .. " · " .. ciudad .. "|r") or "") }
        for _, q in ipairs(g.q) do
          table.insert(partes, "- " .. (q.n or "?") .. ((q.nivel or 0) > nivel and (NARANJA .. L(" (AUN NO: desde nivel ", " (NOT YET: from level ") .. q.nivel .. ")|r") or "")
            .. (q.hecha and (E.cod.verde .. L(" (hecha)", " (done)") .. "|r") or ""))
        end
        table.insert(partes, E.cod.verde .. L("Clic: ruta hasta este NPC.", "Click: route to this NPC.") .. "|r")
        c.grupo = g
        c.ayuda = listo(table.concat(partes, "\n"))
        c:Show()
      end
      local filasC = math.ceil(n / 2)
      y = y - (filasC * 40 + (filasC - 1) * 6)
      primeraEnTarjeta = false
    elseif f.tipo == "botones" then
      -- Los dos botones de la 2.a / 3.a mazmorra, debajo de su ficha
      local par = paresMazmorra[f.par]
      local hayIr, hayMis = ponerPar(par, f.m)
      if hayIr or hayMis then
        y = y - 10
        local bw = (hayIr and hayMis) and math.floor((WT - 6) / 2) or WT
        local x = XT
        if hayIr then par.ir:SetWidth(bw); par.ir:ClearAllPoints(); par.ir:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y); par.ir:Show(); x = x + bw + 6 end
        if hayMis then par.mis:SetWidth(bw); par.mis:ClearAllPoints(); par.mis:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y); par.mis:Show() end
        y = y - 28
      end
    else
      if not arribaT then abrirTarjeta() end
      nl = nl + 1
      local l = linea(nl); limpiar(l); nivelSobre(l, 3)
      l.ficha, l.ayuda, l.fn = f.ficha, f.ayuda, f.fn
      local alto
      if f.tipo == "zona" then
        y = y - (primeraEnTarjeta and 0 or 6)
        l.h3:SetPoint("TOPLEFT", 0, -4); l.h3:SetWidth(WT); l.h3:SetText(f.h3 or ""); l.h3:Show()
        l.sub:SetPoint("TOPLEFT", 0, -24); l.sub:SetWidth(WT); l.sub:SetText(f.sub or ""); l.sub:Show()
        alto = 24 + altoDe(l.sub, 14)
        if f.boton then
          l.accion:SetText(f.boton); E.botonAncho(l.accion, true, 100)
          l.accion:ClearAllPoints(); l.accion:SetPoint("TOPLEFT", 0, -(alto + 10)); l.accion.fn = f.fn; l.accion.ayuda = f.ayuda; l.accion:Show()
          alto = alto + 10 + 28
          l.fn = nil -- el clic va en el boton; la fila solo da el porque al pasar el raton
        end
      elseif f.tipo == "item" then
        y = y - (primeraEnTarjeta and 0 or 9)
        l.ic:ClearAllPoints(); l.ic:SetPoint("TOPLEFT", 0, 0)
        l.ic:poner(f.icono, f.col == "gris" and "gris" or f.col, false); l.ic:Show()
        l.texto:SetPoint("TOPLEFT", 38, -1); l.texto:SetWidth(WT - 38); l.texto:SetText(WowF.T(f.nombre or "")); l.texto:Show()
        local hT = altoDe(l.texto, 14)
        alto = hT + 1
        if f.peq and f.peq ~= "" then
          l.peq:SetPoint("TOPLEFT", 38, -(hT + 3)); l.peq:SetWidth(WT - 38); l.peq:SetText(WowF.T(f.peq)); l.peq:Show()
          alto = hT + 3 + altoDe(l.peq, 12)
        end
        alto = math.max(28, alto)
      elseif f.tipo == "prof" then
        y = y - (primeraEnTarjeta and 0 or 9)
        l.ic:ClearAllPoints(); l.ic:SetPoint("TOPLEFT", 0, 0); l.ic:poner(f.icono); l.ic:Show()
        l.texto:SetPoint("TOPLEFT", 38, 0); l.texto:SetWidth(WT - 38 - 70); l.texto:SetText(f.nombre); l.texto:Show()
        l.der:SetPoint("TOPRIGHT", 0, 0); l.der:SetText(f.max > 0 and (f.r .. "/" .. f.max) or tostring(f.r)); l.der:Show()
        l.barra:ClearAllPoints(); l.barra:SetPoint("TOPLEFT", 38, -19); l.barra:SetWidth(WT - 38); l.barra:poner(f.r, f.max, "brasa"); l.barra:Show()
        l.ayuda = f.nombre .. ": " .. f.r .. (f.max > 0 and ("/" .. f.max) or "") .. L("\nClic: ver Profesiones.", "\nClick: see Professions.")
        alto = 28
      elseif f.tipo == "mz" then
        y = y - (primeraEnTarjeta and 6 or 14)
        local yy = 0
        if f.varias then
          l.rot:SetTextColor(E.color.brasa[1], E.color.brasa[2], E.color.brasa[3])
          l.rot:SetPoint("TOPLEFT", 0, 0)
          E.ponerRotulo(l.rot, f.k == 1 and L("La mejor para ti", "Best for you") or WowF.T(f.estado)); l.rot:Show()
          l.der:SetPoint("TOPRIGHT", 0, 0); l.der:SetText(listo(L("ideal al " .. f.ideal, "ideal at " .. f.ideal))); l.der:Show()
          yy = 18
        end
        l.h3:SetPoint("TOPLEFT", 0, -yy); l.h3:SetWidth(WT); E.letra(l.h3, "marca", 16); l.h3:SetText(f.m.n); l.h3:Show()
        l.sub:SetPoint("TOPLEFT", 0, -(yy + 20)); l.sub:SetWidth(WT)
        l.sub:SetText(listo(f.m.z .. " · " .. L("niveles ", "levels ") .. f.m.d .. "-" .. f.m.h)); l.sub:Show()
        yy = yy + 20 + 16
        if f.k == 1 then
          yy = yy + 10
          local x = 0
          for k2, dd in ipairs(f.cifras) do
            local c = l.cifras[k2]
            c:poner(dd[1], dd[2], nil) -- 11-oct (maqueta): cifras en blanco
            c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, -yy); c:Show()
            x = x + 88
          end
          yy = yy + 40
          -- 12-oct (Andy): que se vea que la tarjeta se abre
          l.peq:SetPoint("TOPLEFT", 0, -(yy + 2)); l.peq:SetWidth(WT)
          l.peq:SetText(WowF.yaTraducido(E.cod.oro .. L("» Clic aquí: jefes, botín para ti y misiones", "» Click here: bosses, loot for you and quests") .. "|r")); l.peq:Show()
          yy = yy + 2 + altoDe(l.peq, 12)
        else
          l.peq:SetPoint("TOPLEFT", 0, -(yy + 4)); l.peq:SetWidth(WT)
          l.peq:SetText(WowF.T(f.estadoLargo or "") .. "\n" .. WowF.yaTraducido(E.cod.oro .. L("» Clic: ver jefes y botín", "» Click: see bosses and loot") .. "|r")); l.peq:Show()
          yy = yy + 4 + altoDe(l.peq, 12)
        end
        l.pista = L("Clic para abrir la ficha de " .. f.m.n .. ": qué te sueltan los jefes, sus misiones y cómo llegar.",
          "Click to open the " .. f.m.n .. " page: what the bosses drop for you, its quests and how to get there.")
        alto = yy
      elseif f.tipo == "aviso" then
        y = y - 10
        l.raya:ClearAllPoints(); l.raya:SetPoint("TOPLEFT", 0, 0); l.raya:SetPoint("TOPRIGHT", 0, 0); l.raya:Show()
        l.texto:SetPoint("TOPLEFT", 0, -9); l.texto:SetWidth(WT); l.texto:SetText(WowF.T(f.texto)); l.texto:Show()
        E.letra(l.texto, "cuerpo", 12); l.texto:SetTextColor(E.color.tenue[1], E.color.tenue[2], E.color.tenue[3])
        alto = 9 + altoDe(l.texto, 12)
      else -- texto suelto dentro de la tarjeta
        y = y - (primeraEnTarjeta and 0 or 8)
        l.texto:SetPoint("TOPLEFT", 0, 0); l.texto:SetWidth(WT); l.texto:SetText(WowF.T(f.texto or "")); l.texto:Show()
        alto = altoDe(l.texto, 13)
      end
      -- La letra del texto vuelve a la de siempre (el aviso la cambia)
      if f.tipo ~= "aviso" then E.letra(l.texto, "cuerpoMedio", 13); l.texto:SetTextColor(E.color.texto[1], E.color.texto[2], E.color.texto[3]) end
      fila(XT, WT, alto, l)
      y = y - alto
      primeraEnTarjeta = false
    end
  end
  cerrarTarjeta()
  for i = nl + 1, #lineas do local l = lineas[i]; limpiar(l); l:Hide() end
  for i = nc + 1, #cajas do cajas[i]:Hide(); cajas[i].grupo = nil end
  for i, t in pairs(tarjetas) do if i > nt then t:Hide() end end
  pcall(refrescarFicha)
  botonFarmeo:Hide(); botonCambiar:Hide(); botonParar:Hide(); botonLimpiar:Hide()
  if not plegado then
    -- .bts: Ir a la mazmorra (estandarte) · Misiones a/b · Farmeo (o Parar ruta), repartidos a lo ancho
    if nt == 0 then y = y - 2 end
    local bts = {}
    local m1 = nil
    for _, f in ipairs(filas) do if f.tipo == "mz" and f.k == 1 then m1 = f.m end end
    if m1 then
      local par = paresMazmorra[1]
      local hayIr, hayMis = ponerPar(par, m1)
      if hayIr then table.insert(bts, par.ir) end
      if hayMis then table.insert(bts, par.mis) end
    end
    if ruta then table.insert(bts, botonParar)
    else botonFarmeo:SetText(WowF.yaTraducido and WowF.yaTraducido(L("Farmeo", "Farming")) or L("Farmeo", "Farming")); table.insert(bts, botonFarmeo) end
    -- 12-oct (Andy: "se sale completamente"): ancho segun el texto de cada boton; lo que sobra se reparte igual
    do
      local libre = W - 6 * (#bts - 1)
      local pide, suma = {}, 0
      for i, b in ipairs(bts) do
        local fs = b.GetFontString and b:GetFontString()
        local ok, w = pcall(function() return fs and fs:GetStringWidth() end)
        w = (ok and tonumber(w)) or 0
        pide[i] = math.max(56, math.ceil(w) + 26)
        suma = suma + pide[i]
      end
      local extra = (libre - suma) / #bts
      local x = X0
      for i, b in ipairs(bts) do
        local bw = (suma <= libre) and math.floor(pide[i] + extra) or math.floor(pide[i] * libre / suma)
        if i == #bts then bw = X0 + W - x end
        b:SetWidth(bw); b:ClearAllPoints(); b:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y); b:Show()
        x = x + bw + 6
      end
    end
    y = y - 28 - 6
    -- Segunda fila: "Cambiar a ..." (secundario) y "Limpiar el mapa" (terciario) cuando hacen falta
    local otra = false
    local guardada = WowFExportarDB.areaMobs and WowFExportarDB.areaMobs.clave -- tras /reload: "piel"/"tela" (o un material)
    local actualF = ruta and ruta.prof or ((WowF.areaMobsActual and WowF.areaMobsActual())
      and (farmeoElegido or ((guardada == "piel" or guardada == "tela") and guardada)) or nil)
    local sig = actualF and siguienteFarmeo(actualF)
    if sig then
      local _, mias = opcionesFarmeo()
      botonCambiar.destino = sig
      botonCambiar:SetText(WowF.yaTraducido(L("Cambiar a ", "Switch to ") .. nombreFarmeo(sig, mias)))
      E.botonAncho(botonCambiar, true, 120)
      botonCambiar:ClearAllPoints(); botonCambiar:SetPoint("TOPLEFT", panel, "TOPLEFT", X0, y); botonCambiar:Show()
      otra = true
    end
    -- Limpiar el mapa: visible mientras haya cualquier ruta o marca (mazmorra, mision, farmeo, entrenador)
    if WowF.hayRutaActiva and WowF.hayRutaActiva() then
      botonLimpiar:SetText(WowF.T("Limpiar el mapa"))
      E.botonAncho(botonLimpiar, false, 80)
      botonLimpiar:ClearAllPoints(); botonLimpiar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -X0, y - (otra and 5 or 0)); botonLimpiar:Show()
      otra = true
    end
    if otra then y = y - 28 - 6 end
    panel:SetHeight(-y + 12)
  else
    panel:SetHeight(ARRIBA)
  end
end

WowF.panelActualizar = function() pcall(actualizar) end
local pendiente = false
local function actualizarPronto()
  if pendiente then return end
  pendiente = true
  despues(0.4, function() pendiente = false; pcall(actualizar) end)
end

plegar:SetScript("OnClick", function()
  WowFExportarDB.panel = WowFExportarDB.panel or {}
  WowFExportarDB.panel.plegado = not WowFExportarDB.panel.plegado
  actualizar()
end)
WowF._botonMisiones = paresMazmorra[1].mis -- para las pruebas: el de la primera mazmorra
WowF._paresMazmorra = paresMazmorra -- para las pruebas: los 3 pares (ir / misiones de fuera)
-- Que ruta te toca segun las profesiones que TIENES de verdad (lectura por id de wowF_Exportar.lua):
--   186/182 = la recoleccion que tienes · sin recoleccion: la que surte a tu profesion (Alchemy -> Herbalism,
--   Blacksmithing/Engineering -> Mining), marcada como sugerencia · "piel" = Skinning/Leatherworking · "tela" = Tailoring ·
--   "otra" = Enchanting u otras sin ruta · sin ninguna profesion: Mining como sugerencia para empezar
local function rutaPorDefecto()
  local tiene = misRecolecciones()
  if #tiene > 0 then return tiene[1] end
  local mias = {}
  for _, p in ipairs(WowF.profesiones and WowF.profesiones() or {}) do if p.principal then mias[p.id] = true end end
  if mias[171] then return 182 end
  if mias[164] or mias[202] then return 186 end
  if mias[393] or mias[165] then return "piel" end
  if mias[197] then return "tela" end
  if next(mias) then return "otra" end
  return 186
end
local function nombresMias()
  local n = {}
  for _, p in ipairs(WowF.profesiones and WowF.profesiones() or {}) do if p.principal then table.insert(n, p.en) end end
  return table.concat(n, " + ")
end
-- Boton "Ruta de farmeo" y /wowf farmeo: la ruta de lo que tienes, o un consejo si tus profesiones no usan ruta
local function ofrecerRuta(prof)
  -- Protocolo de Andy (6-oct): las profesiones de bichos llevan su area en el mapa (circulo con radio), nunca "no hace falta ruta"
  if (prof == "piel" or prof == "tela" or prof == "cocina" or prof == "vendas") and WowF.irAreaMobs then
    pararRuta(true) -- una sola ruta a la vez: fuera la de vetas/hierbas
    farmeoElegido = prof
    if prof == "cocina" or prof == "vendas" then WowF.areaSecundaria(prof == "cocina" and 185 or 129) else WowF.irAreaMobs(prof) end
    if actualizar then pcall(actualizar) end
    return
  end
  if prof == 186 or prof == 182 then
    farmeoElegido = prof
    if WowF.quitarAreaMobs then pcall(WowF.quitarAreaMobs) end
  end
  if prof == "otra" then
    print(WowF.T(AZUL .. "tus profesiones (" .. nombresMias() .. ") no se surten de vetas ni de hierbas: no hay ruta de farmeo para ti."))
    print(WowF.T(AZUL .. "si aun asi quieres una: /wowf farmeo mining o /wowf farmeo herbalism (sale como sugerencia: no la tienes)."))
    return
  end
  empezarRuta(prof, true)
end
botonFarmeo:SetScript("OnClick", function() ofrecerRuta(rutaPorDefecto()) end)
botonCambiar:SetScript("OnClick", function(self) if self.destino then ofrecerRuta(self.destino) end end)
botonParar:SetScript("OnClick", function() pararRuta(false) end)
botonLimpiar:SetScript("OnClick", function() if WowF.limpiarRutas then WowF.limpiarRutas(false) else pararRuta(false) end end)

-- ===================== Eventos =====================
local yaAvisadaInstancia = nil
local function revisarInstancia()
  local datos = { GetInstanceInfo() }
  local tipo, id = datos[2], tonumber(datos[8])
  if tipo == "party" or tipo == "raid" then
    enInstancia, nombreInstancia = id, datos[1] or ""
    local piezas = piezasAqui()
    if piezas and yaAvisadaInstancia ~= id then
      yaAvisadaInstancia = id
      local faltan = {}
      -- Cada pieza con su por que (mejor que lo que llevas en esa ranura)
      for _, o in ipairs(piezas) do if not tengo(o.id) and #faltan < 3 then table.insert(faltan, o.n .. GRIS .. " (" .. (o.j or "") .. ")|r" .. (o.porque and ("\n   " .. (o.dudosa and "|cffffd100" or VERDE) .. o.porque .. "|r") or "")) end end
      if #faltan > 0 then avisar(nombreInstancia, "Aqui te puede caer:\n" .. BLANCO .. table.concat(faltan, "\n") .. "|r", SONIDO_SUAVE, 9) end
    end
    if WowF.placasJefes then WowF.placasJefes(true) end
    -- 8-oct: las placas que ya se veian al entrar no lanzan NAME_PLATE_UNIT_ADDED: se revisan ahora y al segundo
    if WowF.revisarPlacasJefes then pcall(WowF.revisarPlacasJefes); despues(1, function() pcall(WowF.revisarPlacasJefes) end) end
  else
    enInstancia, nombreInstancia, yaAvisadaInstancia = nil, "", nil
    if WowF.olvidarJefes then WowF.olvidarJefes() end
  end
end

local function alSubir(nivel)
  local p = miPlan()
  local lineasAviso = {}
  local pestana = "Progreso"
  if p then
    for _, e in ipairs(eventosDe(p, nivel)) do
      if #lineasAviso < 4 and e[2] ~= "equipo" then table.insert(lineasAviso, WowF.T((ETIQUETA[e[2]] or "") .. primerTrozo(e[3], 80) .. "|r")) end
    end
  end
  for _, m in ipairs(WowFMazmorras or {}) do
    if WowF.esMia and WowF.esMia(m) and #lineasAviso < 5 then
      if nivelIdeal(m) == nivel then table.insert(lineasAviso, WowF.T(VERDE .. "Ya estas listo para " .. m.n .. ": ve ahora (es tu nivel ideal).|r")); pestana = "Mazmorras"
      elseif m.d == nivel then
        pestana = "Mazmorras"
        table.insert(lineasAviso, WowF.T(ORO .. m.n .. " ya se abre|r " .. GRIS .. "(" .. m.d .. "-" .. m.h .. "). Lo ideal: ir al nivel " .. nivelIdeal(m) .. ".|r"))
        local suyas = (WowF.piezasParaTi and WowF.piezasParaTi(p, m.i)) or (p and p.botin and p.botin[m.i])
        if suyas and #suyas > 0 then
          local nombres = {}
          for _, o in ipairs(suyas) do if #nombres < 3 then table.insert(nombres, o.n) end end
          table.insert(lineasAviso, WowF.T(GRIS .. "Te puede caer: |r") .. BLANCO .. table.concat(nombres, ", ") .. "|r")
        end
      end
    end
  end
  -- 4-oct (Andy): hechizos nuevos del entrenador y piezas que te fabricas que valen la pena (wowF_AvisosNuevos.lua)
  if WowF.lineasNuevasNivel then
    local ok, extra = pcall(WowF.lineasNuevasNivel, p, nivel)
    if ok then for _, l in ipairs(extra or {}) do if #lineasAviso < 7 then table.insert(lineasAviso, l) end end end
  end
  if #lineasAviso == 0 then table.insert(lineasAviso, WowF.T(GRIS .. "Nada nuevo a este nivel: sigue asi.|r")) end
  -- 4.25: con hechizos nuevos, boton directo que traza la ruta a tu entrenador de clase
  local accion
  if WowF.hechizosNuevos and WowF.irAlEntrenadorClase then
    local okH, h = pcall(WowF.hechizosNuevos, nivel)
    if okH and type(h) == "table" and #h > 0 then
      accion = { texto = L("Llevame al entrenador", "Take me to the trainer"), fn = function() WowF.irAlEntrenadorClase() end }
    end
  end
  -- 13-oct (comentario 8537474 de CurseForge: con otros addons de subida "parece un virus"): casilla en Ajustes
  -- (WowFExportarDB.avisoSubirNivel = false) = sin ventana, el mismo resumen solo en el chat
  if WowFExportarDB.avisoSubirNivel == false then
    print(AZUL .. WowF.T("¡Nivel " .. nivel .. "!") .. " - " .. table.concat(lineasAviso, " "):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " "))
  else
    avisar("¡Nivel " .. nivel .. "!", WowF.yaTraducido(table.concat(lineasAviso, "\n")), nil, accion and 15 or 11, pestana, accion and { accion = accion } or nil)
  end
  -- La ruta de farmeo se ajusta si cambiaste de tramo o ya hay una zona mejor a tu nivel
  if ruta then empezarRuta(ruta.prof, false) end
end

local tramoVisto = {}
local function revisarHabilidad()
  if not ruta then return end
  local rango, laTienes = rangoDe(ruta.prof)
  -- Cambiaste de profesion en la sesion: la ruta sigue a lo que tienes de verdad (lista vacia = el juego aun no cargo)
  if laTienes and ruta.sugerida then ruta.sugerida = false end
  if not laTienes and not ruta.sugerida and WowF.profesiones and #WowF.profesiones() > 0 then
    local nombre = ruta.nombre
    pararRuta()
    print(WowF.T(AZUL .. "ya no tienes " .. nombre .. ": pare su ruta. Pulsa Ruta de farmeo para la de tus profesiones."))
    return
  end
  local _, tramo = elegirZona(ruta.prof, rango)
  if tramo and tramoVisto[ruta.prof] and tramoVisto[ruta.prof] ~= tramo.a then
    empezarRuta(ruta.prof, false)
    avisar(ruta.nombre .. " " .. rango, "Subiste de tramo: nueva ruta en " .. ruta.zona.n .. ".\n" .. GRIS .. tramo.nodos .. "|r", SONIDO_SUAVE, 7)
  end
  if tramo then tramoVisto[ruta.prof] = tramo.a end
  ruta.rango = rango
end

local function revisarBotin(enlace, enSorteo)
  local id = idDeEnlace(enlace)
  local o = buscada(id)
  if not o or tengo(id) then return end
  -- 4-oct: solo si mejora lo que llevas puesto (antes avisaba de cualquier pieza del plan, aunque fuera peor)
  if WowF.compararPieza then
    local sirve, _, segura = WowF.compararPieza(o, miPlan())
    if not sirve then return end
    if not segura then
      avisar("Te puede servir", enlace .. "\nComparala con lo que llevas (" .. (o.r or "") .. ") antes de pedir Need.", SONIDO_SUAVE, 7)
      return
    end
  end
  if enSorteo then
    avisar("¡Pide Need!", enlace .. "\nEs una de las piezas que buscas (" .. (o.r or "") .. ").", SONIDO_AVISO, 9)
  else
    avisar("¡Lo solto: cogelo!", enlace .. "\nEs la que andas buscando (" .. (o.r or "") .. ").", SONIDO_AVISO, 9)
  end
end

-- ===================== Jefes que sueltan lo que buscas =====================
-- En la mazmorra, el jefe que suelta una pieza de tu plan lleva encima el icono de la pieza ("Suelta: X"),
-- una estrella de banda (si vas solo o eres el lider), un aviso la primera vez que lo ves y una linea en su tooltip.
-- Las placas de nombre de enemigos tienen que estar encendidas (tecla V).
local function nombreSeguro(v) -- la beta puede devolver valores secretos: no se comparan
  if v == nil or (issecretvalue and issecretvalue(v)) or type(v) ~= "string" then return nil end
  return v
end
local function jefesAqui()
  local res = {}
  if WowF.mejorasDe and not WowF.mejorasDe("mazmorra") then return res end -- 8-oct: apagadas en Ajustes
  for _, o in ipairs(piezasAqui() or {}) do
    if o.jefe and not tengo(o.id) then
      res[o.jefe] = res[o.jefe] or {}
      table.insert(res[o.jefe], o)
    end
  end
  return res
end
WowF.jefesAqui = jefesAqui
-- 5-oct: id del NPC -> nombre del jefe en los datos (WowFJefesNPC de wowF_Mazmorras.lua). Con el juego en otro idioma
-- UnitName da el nombre traducido y no coincide; el GUID ("Creature-0-...-<id>-...") es igual en todos los idiomas.
local jefePorId
local function idDeUnidad(unidad)
  if not UnitGUID then return nil end
  local ok, g = pcall(UnitGUID, unidad)
  g = ok and nombreSeguro(g)
  if not g then return nil end
  local tipo, id = g:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
  if tipo ~= "Creature" and tipo ~= "Vehicle" then return nil end
  return tonumber(id)
end
-- 8-oct (Andy: en ninguna mazmorra salio la marca): este cliente (motor 12.x) puede devolver SECRETOS el GUID y el nombre
-- de los enemigos (C_Secrets.ShouldUnitIdentityBeSecret), sobre todo dentro de instancias: asi no se sabe que jefe es.
-- Se usa lo que el juego deja ver: 1) el id o el nombre si llegan en claro; 2) si no, pistas de jefe (UnitIsBossMob,
-- "worldboss", nivel -1, el nombre del combate de ENCOUNTER_START) y la marca dice "puede ser" (dato sin confirmar = aviso).
local function secreto(v) return v ~= nil and issecretvalue ~= nil and issecretvalue(v) and true or false end
local function leer(fn, ...)
  if not fn then return nil end
  local ok, v = pcall(fn, ...)
  if not ok or secreto(v) then return nil end
  return v
end
local function pareceJefe(unidad)
  if leer(UnitIsBossMob, unidad) == true then return true end
  if leer(UnitClassification, unidad) == "worldboss" then return true end
  return leer(UnitLevel, unidad) == -1
end
local aquiFijo -- 8-oct: en un repaso de placas, jefesAqui se calcula una sola vez
local combateJefe -- nombre del combate de jefe en marcha (ENCOUNTER_START), si llega en claro
-- 8-oct (2), amigos de Andy sin marca en ninguna mazmorra: dentro de la mazmorra el juego oculta el nombre y el GUID de los
-- enemigos (secretos) y los jefes de Classic son "elite" normales (ni UnitIsBossMob, ni "worldboss", ni nivel -1), asi que
-- nunca se sabia quien era el jefe. ENCOUNTER_START trae el encounterID (igual en todos los idiomas): con WowFEncuentros
-- (wowF_Encuentros.lua, de DungeonEncounter de la beta) se sabe el jefe del combate, y boss1-boss5 son sus unidades.
local encuentroJefe -- nombre en ingles del jefe del combate en marcha (por el encounterID), si llego en claro
local function normal(s) return (s:lower():gsub("[^%w]", "")) end
local function parecido(a, b) -- mismo nombre con una o dos letras cambiadas (DungeonEncounter: "Geilhast" / Wowhead: "Gelihast")
  if #a < 6 or math.abs(#a - #b) > 1 or a:sub(1, 1) ~= b:sub(1, 1) then return false end
  local prev = {}
  for j = 0, #b do prev[j] = j end
  for i = 1, #a do
    local cur = { [0] = i }
    for j = 1, #b do cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + ((a:sub(i, i) == b:sub(j, j)) and 0 or 1)) end
    prev = cur
  end
  return prev[#b] <= 2
end
local function claveJefe(aqui, nombre) -- nombre del combate -> clave de jefesAqui (exacta, sin signos o casi igual)
  if not nombre then return nil end
  if aqui[nombre] then return nombre end
  local n = normal(nombre)
  for k in pairs(aqui) do if normal(k) == n then return k end end
  for k in pairs(aqui) do if parecido(normal(k), n) then return k end end
  return nil
end
local function jefeDelCombate(aqui) return claveJefe(aqui, encuentroJefe) or claveJefe(aqui, combateJefe) end
local function unidadesJefe() -- boss1..boss5 que existen ahora
  local r = {}
  for i = 1, 5 do local u = "boss" .. i; if UnitExists and UnitExists(u) then r[#r + 1] = u end end
  return r
end
local function esUnidadJefe(unidad)
  if type(unidad) ~= "string" then return false end
  if unidad:match("^boss%d$") then return UnitExists and UnitExists(unidad) and true or false end
  for _, u in ipairs(unidadesJefe()) do if leer(UnitIsUnit, unidad, u) == true then return true end end
  return false
end
local function esObjetivo(unidad) return unidad == "target" or leer(UnitIsUnit, unidad, "target") == true end
-- Devuelve: piezas, nombre del jefe (o "?"), dudoso (true = el juego oculto quien es: "puede ser"), desconocido (no se pudo leer nada)
local function piezasDelJefe(unidad)
  if not enInstancia or not UnitExists or not UnitExists(unidad) then return nil end
  local aqui = aquiFijo
  if not aqui then
    local okA, a = pcall(jefesAqui)
    if not okA or type(a) ~= "table" then return nil end
    aqui = a
  end
  if next(aqui) == nil then return nil end
  local id = idDeUnidad(unidad)
  if id then
    if not jefePorId then
      jefePorId = {}
      for nombre, ids in pairs(WowFJefesNPC or {}) do for _, i in ipairs(ids) do jefePorId[i] = nombre end end
    end
    local n = jefePorId[id]
    if n and aqui[n] then return aqui[n], n end
  end
  local n = nombreSeguro(leer(UnitName, unidad))
  if n then
    n = n:gsub("^%s+", ""):gsub("%s+$", "")
    return aqui[n], n
  end
  if id then return nil end -- se leyo el id y no es un jefe con tus piezas
  -- 8-oct (2): identidad oculta, pero hay un combate de jefe con tus piezas en marcha: si esta unidad es boss1-5, es SEGURO;
  -- si no hay unidades boss y es tu objetivo en ese combate, "puede ser" (5.o valor: marca puesta por ser tu objetivo)
  local enc = jefeDelCombate(aqui)
  if enc then
    if esUnidadJefe(unidad) then return aqui[enc], enc, false end
    if #unidadesJefe() == 0 and esObjetivo(unidad) then return aqui[enc], enc, true, nil, true end
  end
  -- Identidad oculta por el juego: solo pistas
  if not pareceJefe(unidad) then return nil, nil, false, true end
  if enc then return aqui[enc], enc, true end
  local nombres, todas = {}, {}
  for jefe, lista in pairs(aqui) do
    table.insert(nombres, jefe)
    for _, o in ipairs(lista) do table.insert(todas, o) end
  end
  if #nombres == 1 then return aqui[nombres[1]], nombres[1], true end
  return todas, "?", true
end
WowF.piezasDelJefe = piezasDelJefe
local function nombresPiezas(lista)
  local t = {}
  for _, o in ipairs(lista) do table.insert(t, o.n .. GRIS .. " (" .. (o.r or "") .. ")|r") end
  return table.concat(t, "\n")
end
local marcasJefe = {} -- placa de nombre -> marco con el icono
local avisadoJefe = {}
-- 5-oct (Andy: "que se note que este te puede soltar esto"): icono de 38 con aro dorado y brillo que late,
-- encima "PUEDE SOLTAR TU PIEZA" y debajo el nombre de la pieza
local function marcaEn(placa)
  if marcasJefe[placa] then return marcasJefe[placa] end
  if placa.IsForbidden and placa:IsForbidden() == true then return nil end -- placa protegida por el juego: no se puede tocar
  -- 11-oct (FLG-ERR SetPreferredGamepadInteractTarget, mando): marco propio anclado a la placa, no hijo de ella
  local m = CreateFrame("Frame", nil, UIParent)
  m:SetSize(38, 38)
  m:SetPoint("BOTTOM", placa, "TOP", 0, 22)
  m:SetFrameStrata("HIGH")
  m.brillo = m:CreateTexture(nil, "BACKGROUND")
  m.brillo:SetPoint("TOPLEFT", -14, 14); m.brillo:SetPoint("BOTTOMRIGHT", 14, -14)
  m.brillo:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
  m.brillo:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
  if m.brillo.SetBlendMode then m.brillo:SetBlendMode("ADD") end
  m.aro = m:CreateTexture(nil, "BORDER")
  m.aro:SetPoint("TOPLEFT", -3, 3); m.aro:SetPoint("BOTTOMRIGHT", 3, -3)
  -- 11-oct (hibrido): aro brasa, titulo con la letra de marca (con contorno: va sobre el mundo) y nombre en Signika
  if m.aro.SetColorTexture then m.aro:SetColorTexture(E.color.brasa[1], E.color.brasa[2], E.color.brasa[3], 1) end
  m.icono = m:CreateTexture(nil, "ARTWORK")
  m.icono:SetAllPoints()
  m.icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  m.titulo = m:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  E.letra(m.titulo, "marca", 14, "OUTLINE")
  m.titulo:SetPoint("BOTTOM", m, "TOP", 0, 6)
  m.texto = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  E.letra(m.texto, "boton", 12, "OUTLINE")
  m.texto:SetPoint("TOP", m, "BOTTOM", 0, -3)
  -- 8-oct (Andy): ademas, el icono pequeno en la esquina de arriba del nombre del jefe
  local function tabla(v) return type(v) == "table" and v or nil end
  local uf = tabla(rawget(placa, "UnitFrame") or placa.UnitFrame)
  local hb = uf and tabla(uf.HealthBarsContainer)
  local ancla = uf and (tabla(uf.name) or tabla(uf.healthBar) or (hb and tabla(hb.healthBar)))
  if ancla then
    m.esquina = m:CreateTexture(nil, "OVERLAY")
    m.esquina:SetSize(20, 20)
    m.esquina:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if not pcall(m.esquina.SetPoint, m.esquina, "BOTTOMLEFT", ancla, "TOPRIGHT", -4, -6) then m.esquina:Hide(); m.esquina = nil end
  end
  if m.CreateAnimationGroup then
    local ag = m:CreateAnimationGroup()
    local a = ag:CreateAnimation("Alpha")
    if a then
      a:SetTarget(m.brillo); a:SetFromAlpha(1); a:SetToAlpha(0.25); a:SetDuration(0.6)
      if ag.SetLooping then ag:SetLooping("BOUNCE") end
      ag:Play()
    end
    m.anim = ag
  end
  marcasJefe[placa] = m
  return m
end
-- 8-oct (2): si el juego oculta los nombres y no hay ninguna marca, se dice UNA vez por mazmorra cuando saldra (dato sin confirmar = aviso)
local avisadaOculta = false
local function avisoOculta()
  if avisadaOculta then return end
  for _, m in pairs(marcasJefe) do if m.IsShown and m:IsShown() then return end end
  avisadaOculta = true
  print(WowF.T("|cff33ff99Forever Guide|r: ") .. L("el juego oculta el nombre de los enemigos en esta mazmorra: la marca del jefe que suelta tu pieza saldra al empezar el combate contra el.",
    "the game hides enemy names in this dungeon: the mark on the boss that drops your item will appear when the fight against it starts."))
end
-- 11-oct (4.26): retrato del jefe junto a la marca (wowF_Retratos.lua); cara de WowFDiario por id del NPC o por nombre
local function jefeDiario(id, nombre)
  if type(WowFDiario) ~= "table" then return nil end
  for _, d in pairs(WowFDiario) do
    for _, j in ipairs(type(d) == "table" and d.jefes or {}) do
      if id and (j.npc == id or (type(j.npcs) == "table" and tContains and tContains(j.npcs, id))) then return j end
      if type(nombre) == "string" and nombre ~= "?" and j.n == nombre then return j end
    end
  end
end
local function retratoMarca(m, unidad, n)
  if not WowF.marcoRetrato then return end
  if not rawget(m, "retrato") then -- rawget: campo propio (en el simulador un campo desconocido devuelve una funcion)
    local ok, r = pcall(WowF.marcoRetrato, m, 40)
    if not ok or not r then return end
    m.retrato = r
    r:SetPoint("RIGHT", m, "LEFT", -8, 0)
  end
  local id = idDeUnidad(unidad)
  local j = jefeDiario(id, n)
  local okT, esObjetivo = pcall(function() return UnitIsUnit and UnitIsUnit(unidad, "target") == true end)
  pcall(m.retrato.poner, m.retrato, { cara = j and j.cara, display = j and j.d, npc = id or (j and j.npc), nombre = (type(n) == "string" and n ~= "?") and n or (j and j.n),
    unidad = (okT and esObjetivo) and "target" or nil, icono = 521744 })
  if m.retrato.resaltar then pcall(m.retrato.resaltar, m.retrato, true) end
  m.retrato:Show()
end
local function revisarJefe(unidad, placa)
  if placa and WowF.mandoActivo and WowF.mandoActivo() then placa = nil end -- 14-oct: con mando, nada sobre las placas
  local lista, n, dudoso, desconocido, porObjetivo = piezasDelJefe(unidad)
  if placa then
    if not lista or #lista == 0 then
      -- 8-oct: si el juego oculto quien es (p. ej. al entrar en combate), la marca que ya tenia se queda
      if marcasJefe[placa] and not desconocido then marcasJefe[placa]:Hide() end
      if desconocido then avisoOculta() end
    else
      local m = marcaEn(placa)
      if m then
        -- 8-oct (2): la marca "puede ser" puesta por ser tu objetivo pasa al objetivo nuevo (no se queda en el anterior)
        if porObjetivo then for p2, m2 in pairs(marcasJefe) do if p2 ~= placa and m2.porObjetivo then m2:Hide(); m2.porObjetivo = nil end end end
        m.porObjetivo = porObjetivo or nil
        local o = lista[1]
        local icono = iconoDe(o.id, o.ic)
        m.icono:SetTexture(icono)
        if type(m.esquina) == "table" then m.esquina:SetTexture(icono); m.esquina:Show() end
        retratoMarca(m, unidad, n)
        if dudoso then
          m.titulo:SetText(ORO .. L("PUEDE SER EL JEFE DE TU PIEZA", "MAY BE THE BOSS OF YOUR ITEM") .. "|r")
        else
          m.titulo:SetText(BRASA .. L("PUEDE SOLTAR TU PIEZA", "CAN DROP YOUR ITEM") .. "|r")
        end
        m.texto:SetText(BLANCO .. o.n .. "|r" .. (#lista > 1 and (GRIS .. L(" y " .. (#lista - 1) .. " mas", " and " .. (#lista - 1) .. " more") .. "|r") or ""))
        m:Show()
        if m.anim and m.anim.Play then m.anim:Play() end
      end
    end
  end
  if not lista or #lista == 0 then return false end
  -- 6-oct: SetRaidTarget esta reservado a Blizzard en este cliente (sale "blocked from an action only available to the Blizzard UI"): no se usa
  if not avisadoJefe[n] then
    avisadoJefe[n] = true
    if dudoso then
      local titulo = (n ~= "?") and L("¡Puede ser " .. n .. ": suelta lo que buscas!", "This may be " .. n .. ": it drops what you are looking for!")
        or L("¡Este puede ser el jefe que suelta lo que buscas!", "This may be the boss that drops what you are looking for!")
      avisar(WowF.yaTraducido(titulo), BLANCO .. nombresPiezas(lista) .. "|r\n" .. GRIS .. WowF.yaTraducido(L("El juego oculta el nombre de este enemigo, asi que no es seguro. Lleva el icono encima: matalo y revisa su botin. Se mejorara en proximas actualizaciones.",
        "The game hides this enemy's name, so it is not certain. It has the icon above it: kill it and check its loot. This will improve in future updates.")) .. "|r", SONIDO_AVISO, 8)
    else
      avisar(WowF.yaTraducido(L("¡" .. n .. " suelta lo que buscas!", n .. " drops what you are looking for!")), BLANCO .. nombresPiezas(lista) .. "|r\n" .. GRIS .. WowF.yaTraducido(L("Lleva el icono encima. Matalo y revisa su botin.", "It has the icon above it. Kill it and check its loot.")) .. "|r", SONIDO_AVISO, 8)
    end
  end
  return true
end
WowF.revisarJefe = revisarJefe
-- 5-oct: sin placas de enemigos no se ve el icono: dentro de la mazmorra, si hay jefes con tus piezas, se encienden
-- (una sola vez, con aviso) y al salir se dejan como estaban
local function conMando() return WowF.interfazMando() end -- 22-oct: mando conectado de verdad (wowF_Estilo.lua) -- 11-oct: con mando no se tocan los CVars de placas
local function placasEnemigos(encender)
  if not (GetCVar and SetCVar) then return end
  if InCombatLockdown and InCombatLockdown() then return end -- en combate el juego lo bloquea
  WowFExportarDB = WowFExportarDB or {}
  if encender then
    if conMando() or WowFExportarDB.placasJefes ~= nil or next(jefesAqui()) == nil then return end
    local ok, v = pcall(GetCVar, "nameplateShowEnemies")
    if ok and v == "0" then
      WowFExportarDB.placasJefes = "0"
      pcall(SetCVar, "nameplateShowEnemies", "1")
      print(WowF.T("|cff33ff99Forever Guide|r: ") .. L("encendi las placas de nombre de los enemigos para marcar al jefe que suelta tu pieza (al salir de la mazmorra vuelven a como estaban).",
        "I turned on enemy nameplates to mark the boss that drops your item (they go back to how they were when you leave the dungeon)."))
    end
  elseif WowFExportarDB.placasJefes ~= nil then
    pcall(SetCVar, "nameplateShowEnemies", WowFExportarDB.placasJefes)
    WowFExportarDB.placasJefes = nil
  end
end
WowF.placasJefes = placasEnemigos
WowF.olvidarJefes = function() avisadoJefe = {}; avisadaOculta = false; placasEnemigos(false) end -- al salir de la mazmorra: la proxima vez avisa otra vez
-- Linea en el tooltip del enemigo
local function lineaTooltip(tt)
  if not tt or not tt.GetUnit then return end
  local ok, _, unidad = pcall(tt.GetUnit, tt)
  if not ok or not unidad then return end
  local lista, _, dudoso = piezasDelJefe(unidad)
  if lista and #lista > 0 then
    if dudoso then tt:AddLine("Forever Guide: " .. L("puede ser el jefe de tu pieza (el juego oculta su nombre)", "may be the boss of your item (the game hides its name)"), 1, 0.82, 0) end
    for _, o in ipairs(lista) do tt:AddLine("Forever Guide: " .. L("puede soltar " .. o.n .. " (tu pieza)", "can drop " .. o.n .. " (your item)"), 0.2, 1, 0.4) end
    tt:Show()
  end
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tt) pcall(lineaTooltip, tt) end)
elseif GameTooltip and GameTooltip.HookScript then
  pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tt) pcall(lineaTooltip, tt) end)
end
-- 8-oct: diagnostico de lo que el juego deja leer de cada enemigo (/wowf jefes y WowFExportarDB.diagJefes)
local function diagnostico(unidad, placa)
  local ok, g = pcall(UnitGUID or function() end, unidad)
  local ok2, nom = pcall(UnitName or function() end, unidad)
  local d = {
    unidad = unidad, inst = enInstancia, instNombre = nombreInstancia,
    guid = not ok and "error" or (g == nil and "nil" or (secreto(g) and "SECRETO" or "claro")),
    nombre = not ok2 and "error" or (nom == nil and "nil" or (secreto(nom) and "SECRETO" or nom)),
    oculta = tostring(C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret and leer(C_Secrets.ShouldUnitIdentityBeSecret, unidad)),
    id = idDeUnidad(unidad), jefeBoss = tostring(leer(UnitIsBossMob, unidad)), clase = tostring(leer(UnitClassification, unidad)),
    nivel = tostring(leer(UnitLevel, unidad)), placa = placa and ((placa.IsForbidden and placa:IsForbidden() == true) and L("PROHIBIDA", "FORBIDDEN") or L("si", "yes")) or "no",
    encuentro = tostring(encuentroJefe or combateJefe), esJefeCombate = tostring(esUnidadJefe(unidad)), unidadesBoss = #unidadesJefe(),
  }
  local lista, n, dudoso = piezasDelJefe(unidad)
  d.resultado = lista and #lista > 0 and ((dudoso and L("PUEDE SER ", "MAYBE ") or L("SI ", "YES ")) .. tostring(n)) or "no"
  return d
end
local function anotarDiag(unidad, placa)
  WowFExportarDB = WowFExportarDB or {}
  local ok, d = pcall(diagnostico, unidad, placa)
  if not ok then return end
  local r = WowFExportarDB.diagJefes
  if type(r) ~= "table" then r = {}; WowFExportarDB.diagJefes = r end
  table.insert(r, d)
  while #r > 40 do table.remove(r, 1) end
end
-- 8-oct: revisar TODAS las placas visibles (las que ya estaban al entrar no lanzan NAME_PLATE_UNIT_ADDED)
local function revisarPlacas()
  if not enInstancia or not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
  local ok, placas = pcall(C_NamePlate.GetNamePlates)
  if not ok or type(placas) ~= "table" or #placas == 0 then return end
  local okA, aqui = pcall(jefesAqui)
  if not okA or next(aqui) == nil then return end
  aquiFijo = aqui
  for _, placa in pairs(placas) do
    local uf = type(placa.UnitFrame) == "table" and placa.UnitFrame or nil
    local unidad = placa.namePlateUnitToken or (uf and uf.unit)
    if type(unidad) == "string" then pcall(revisarJefe, unidad, placa) end
  end
  aquiFijo = nil
end
WowF.revisarPlacasJefes = revisarPlacas
-- 8-oct (2): combate de jefe (ENCOUNTER_START con el encounterID): marca la placa de boss1-5 (seguro) o, si no hay unidades
-- boss, la de tu objetivo ("puede ser"); y el aviso sale igual aunque no haya placa (el combate si es seguro)
local function revisarEncuentro()
  if not enInstancia then return end
  local okA, aqui = pcall(jefesAqui)
  if not okA or type(aqui) ~= "table" then return end
  local clave = jefeDelCombate(aqui)
  if not clave then return end
  local marcada = false
  local function placaDe(u) return C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(u) or nil end
  for _, u in ipairs(unidadesJefe()) do
    local placa = placaDe(u)
    local ok, r = pcall(revisarJefe, u, placa)
    if ok and r and placa then marcada = true end
  end
  if not marcada and UnitExists and UnitExists("target") then pcall(revisarJefe, "target", placaDe("target")) end
  if not avisadoJefe[clave] then
    avisadoJefe[clave] = true
    avisar(WowF.yaTraducido(L("¡" .. clave .. " suelta lo que buscas!", clave .. " drops what you are looking for!")), BLANCO .. nombresPiezas(aqui[clave]) .. "|r\n" .. GRIS
      .. WowF.yaTraducido(L("Es el jefe de este combate. Matalo y revisa su botin.", "It is the boss of this fight. Kill it and check its loot.")) .. "|r", SONIDO_AVISO, 8)
  end
end
WowF.revisarEncuentroJefe = revisarEncuentro
-- 8-oct (2): que llega en ENCOUNTER_START en el juego real (para comprobarlo sin Andy: WowFExportarDB.diagJefes)
local function anotarEncuentro(idE, nombreE)
  WowFExportarDB = WowFExportarDB or {}
  local r = WowFExportarDB.diagJefes
  if type(r) ~= "table" then r = {}; WowFExportarDB.diagJefes = r end
  local bosses = unidadesJefe()
  local okA, aqui = pcall(jefesAqui)
  local marcas = 0
  for _, m in pairs(marcasJefe) do if m.IsShown and m:IsShown() then marcas = marcas + 1 end end
  local placaBoss = #bosses > 0 and C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(bosses[1])
  table.insert(r, { evento = "ENCOUNTER_START", inst = enInstancia, instNombre = nombreInstancia,
    encId = idE == nil and "nil" or (secreto(idE) and "SECRETO" or tostring(idE)),
    encNombre = nombreE == nil and "nil" or (secreto(nombreE) and "SECRETO" or tostring(nombreE)),
    jefe = tostring(encuentroJefe), conPiezas = tostring(okA and type(aqui) == "table" and jefeDelCombate(aqui) or "no"),
    unidadesBoss = #bosses, placaBoss = placaBoss and "si" or "no", objetivo = tostring(UnitExists and UnitExists("target") or false),
    combate = tostring(InCombatLockdown and InCombatLockdown() or false), marcas = marcas })
  while #r > 40 do table.remove(r, 1) end
end
-- 10-oct: si el juego bloquea algo del addon ("has been blocked from an action..."), anotar QUE funcion fue
-- (WowFExportarDB.diagBloqueos, ultimos 20) para arreglarlo sin pedirle pruebas al jugador; aviso en el chat una vez por sesion
-- 10-oct (4.20): el registro de diagBloqueos no nos llega (los addons no salen a internet), asi que el jugador ve una
-- ventanita con un codigo FLG-ERR ya seleccionado para copiarlo y pegarlo en los comentarios de CurseForge; el agente de
-- comentarios lo detecta y avisa a Andy. Sin UISpecialFrames (sospechoso de taint): Esc en la caja la cierra.
do -- 11-oct: bloque propio (ventana de errores, vigias de bloqueos y jefes): Lua solo admite 200 locales por archivo
local function codigoError(b)
  if type(b) ~= "table" then return nil end
  local v = WowF.versionAddon and WowF.versionAddon() or "?"
  local funcion = tostring(b.funcion or "?"); if funcion == "" or funcion == "nil" then funcion = "?" end
  return "FLG-ERR " .. tostring(v) .. " " .. tostring(b.evento or "?") .. " " .. funcion .. " | " .. tostring(b.zona or "?") .. " | nv " .. tostring(b.nivel or 0)
    .. " | mando " .. tostring(b.mando or "?") .. " | combate " .. ((b.combate == "true") and "si" or "no") .. " | " .. tostring(b.fecha or "?")
end
WowF.codigoError = codigoError
local ventanaErrores
local function crearVentanaErrores()
  local v = CreateFrame("Frame", "wowFErrores", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  v:SetSize(460, 200)
  v:SetPoint("CENTER", 0, 120)
  v:SetFrameStrata("DIALOG")
  -- 11-oct (hibrido): cabecera pequena (FOREVER GUIDE), titulo serif, texto Signika y Cerrar como boton principal brasa
  WowF.estilo.marco(v, "aviso")
  v:EnableMouse(true)
  v:SetMovable(true)
  v:RegisterForDrag("LeftButton")
  v:SetScript("OnDragStart", v.StartMoving)
  v:SetScript("OnDragStop", v.StopMovingOrSizing)
  v.cab = E.cabecera(v, 20)
  v.cab.titulo:SetText("FOREVER GUIDE")
  v.cab.titulo:SetPoint("RIGHT", v.cab.fondo, "RIGHT", -28, 0)
  v.titulo = E.titulo(v, nil, 16)
  v.titulo:SetPoint("TOPLEFT", 16, -36)
  v.titulo:SetWidth(428)
  v.texto = E.cuerpo(v, nil, 12)
  v.texto:SetPoint("TOPLEFT", v.titulo, "BOTTOMLEFT", 0, -8)
  v.texto:SetWidth(428)
  local caja = CreateFrame("EditBox", nil, v, "InputBoxTemplate")
  caja:SetSize(420, 24)
  caja:SetPoint("BOTTOM", 0, 46)
  caja:SetAutoFocus(false)
  caja:SetScript("OnEscapePressed", function() v:Hide() end)
  caja:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  -- si el jugador borra o cambia el texto sin querer, vuelve el codigo
  caja:SetScript("OnTextChanged", function(self, usuario) if usuario and v.codigo then self:SetText(v.codigo); self:HighlightText() end end)
  v.caja = caja
  local cerrar = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
  WowF.estilo.boton(cerrar, "brasa")
  cerrar:SetSize(100, 22)
  cerrar:SetPoint("BOTTOMRIGHT", -16, 14)
  cerrar:SetScript("OnClick", function() v:Hide() end)
  v.cerrar = cerrar
  local x = CreateFrame("Button", nil, v, "UIPanelButtonTemplate") -- 11-oct (diario): X hibrida (cuero), no la cruz roja del juego
  E.boton(x, "cuero", 11)
  x:SetSize(18, 18); x:SetText("X")
  x:SetScript("OnClick", function() v:Hide() end)
  x:SetPoint("TOPRIGHT", -8, -8)
  v:Hide()
  return v
end
function WowF.mostrarErrores()
  local r = WowFExportarDB and WowFExportarDB.diagBloqueos
  local ultimo = type(r) == "table" and r[#r] or nil
  if not ultimo then
    print(AZUL .. L("el juego no ha bloqueado nada del addon. Si ves un error, avisanos en los comentarios de Forever Leveling Guide en CurseForge.",
      "the game hasn't blocked anything from the addon. If you see an error, tell us in the Forever Leveling Guide comments on CurseForge."))
    return false
  end
  if not ventanaErrores then ventanaErrores = crearVentanaErrores() end
  local v = ventanaErrores
  v.codigo = codigoError(ultimo)
  v.titulo:SetText(BLANCO .. L("Ayudanos a arreglarlo", "Help us fix it") .. "|r")
  v.texto:SetText(L("El juego bloqueo una accion de Forever Leveling Guide. Puedes pulsar Ignore: el addon sigue funcionando.\n\n"
      .. BRASA .. "1.|r Haz clic en el codigo y pulsa Ctrl+C.\n" .. BRASA .. "2.|r Pegalo (Ctrl+V) en los comentarios de Forever Leveling Guide en CurseForge.",
    "The game blocked an action from Forever Leveling Guide. You can press Ignore: the addon keeps working.\n\n"
      .. BRASA .. "1.|r Click the code and press Ctrl+C.\n" .. BRASA .. "2.|r Paste it (Ctrl+V) in the Forever Leveling Guide comments on CurseForge."))
  v.cerrar:SetText(L("Cerrar", "Close"))
  v.caja:SetText(v.codigo)
  v:Show()
  v.caja:SetFocus()
  v.caja:HighlightText()
  return true
end
-- 13-oct: misma ventana para cualquier codigo que el jugador tenga que copiar y pegar en CurseForge (diagnostico del modo aprendizaje)
function WowF.mostrarCodigo(titulo, texto, codigo)
  if not ventanaErrores then ventanaErrores = crearVentanaErrores() end
  local v = ventanaErrores
  v.codigo = codigo
  v.titulo:SetText(BLANCO .. titulo .. "|r")
  v.texto:SetText(texto)
  v.cerrar:SetText(L("Cerrar", "Close"))
  pcall(v.caja.SetMaxLetters, v.caja, 0)
  v.caja:SetText(codigo)
  v:Show()
  v.caja:SetFocus()
  v.caja:HighlightText()
  return true
end
WowF._ventanaErrores = function() return ventanaErrores end -- para las pruebas
local bloqueoAvisado = false
local vigiaBloqueos = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do pcall(vigiaBloqueos.RegisterEvent, vigiaBloqueos, e) end
vigiaBloqueos:SetScript("OnEvent", function(_, evento, addon, funcion)
  if addon ~= "ForeverLevelingGuide" then return end
  WowFExportarDB = WowFExportarDB or {}
  local r = WowFExportarDB.diagBloqueos
  if type(r) ~= "table" then r = {}; WowFExportarDB.diagBloqueos = r end
  local function cv(n) local ok, v = pcall(GetCVar, n); return ok and tostring(v) or "?" end
  local okZ, zona = pcall(GetRealZoneText)
  table.insert(r, { evento = evento, funcion = tostring(funcion), fecha = date and date("%Y-%m-%d %H:%M:%S") or "?",
    zona = okZ and tostring(zona) or "?", nivel = UnitLevel and UnitLevel("player") or 0,
    combate = tostring(InCombatLockdown and InCombatLockdown() or false), mando = cv("GamePadEnable"),
    placasAmigas = cv("nameplateShowFriendlyNPCs"), placasEnemigas = cv("nameplateShowEnemies") })
  while #r > 20 do table.remove(r, 1) end
  if not bloqueoAvisado then
    bloqueoAvisado = true
    print(AZUL .. L("el juego bloqueo una accion del addon (" .. tostring(funcion) .. "). Puedes pulsar Ignore. Para que lo arreglemos: copia el codigo de la ventana y pegalo en los comentarios de Forever Leveling Guide en CurseForge (/wowf errores lo vuelve a abrir).",
      "the game blocked an addon action (" .. tostring(funcion) .. "). You can press Ignore. To help us fix it: copy the code from the window and paste it in the Forever Leveling Guide comments on CurseForge (/wowf errors opens it again)."))
    WowF.mostrarErrores()
  end
end)
WowF._vigiaBloqueos = vigiaBloqueos -- para las pruebas
local vigiaJefes = CreateFrame("Frame")
for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
  "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "INSTANCE_ENCOUNTER_ENGAGE_UNIT" }) do pcall(vigiaJefes.RegisterEvent, vigiaJefes, e) end
vigiaJefes:SetScript("OnEvent", function(_, evento, unidad, nombreCombate)
  if evento == "NAME_PLATE_UNIT_REMOVED" then
    local placa = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unidad)
    if placa and marcasJefe[placa] then marcasJefe[placa]:Hide() end
    return
  end
  if evento == "ENCOUNTER_END" then combateJefe, encuentroJefe = nil, nil; return end
  if not enInstancia then return end
  if evento == "ENCOUNTER_START" then
    -- ENCOUNTER_START(encounterID, encounterName, ...): el nombre llega traducido; el id es igual en todos los idiomas
    local n = nombreSeguro(nombreCombate)
    combateJefe = n and n:gsub("^%s+", ""):gsub("%s+$", "") or nil
    local idE = (not secreto(unidad)) and tonumber(unidad) or nil
    local e = idE and WowFEncuentros and WowFEncuentros[idE]
    encuentroJefe = type(e) == "table" and e[1] or nil
    pcall(revisarPlacas)
    pcall(revisarEncuentro)
    pcall(anotarEncuentro, unidad, nombreCombate)
  elseif evento == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then pcall(revisarEncuentro)
  elseif evento == "PLAYER_REGEN_ENABLED" or evento == "PLAYER_REGEN_DISABLED" then
    -- 8-oct (2): si entraste en combate no se pudieron encender las placas: se encienden al salir del combate
    if evento == "PLAYER_REGEN_ENABLED" and WowF.placasJefes then pcall(WowF.placasJefes, true) end
    pcall(revisarPlacas)
  elseif evento == "NAME_PLATE_UNIT_ADDED" then
    local placa = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unidad)
    pcall(revisarJefe, unidad, placa)
    anotarDiag(unidad, placa)
  elseif evento == "PLAYER_TARGET_CHANGED" then
    pcall(revisarJefe, "target")
    local placa = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
    if placa then pcall(revisarJefe, "target", placa) end
    if UnitExists and UnitExists("target") then anotarDiag("target", placa) end
  else pcall(revisarJefe, "mouseover") end
end)
-- Repaso ligero cada 2 s dentro de la mazmorra (placas que ya estaban, identidad que se aclara al salir de combate)
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(2, function() if enInstancia then pcall(revisarPlacas) end end) end

-- /wowf jefes: que ve el addon del enemigo que tienes seleccionado (para medirlo en la mazmorra)
local ordenJefes = SlashCmdList and SlashCmdList["WOWF"]
if SlashCmdList then
  SlashCmdList["WOWF"] = function(mensaje, ...)
    local orden = ((mensaje or ""):match("^%s*(%S*)") or ""):lower()
    if orden == "errores" or orden == "errors" then WowF.mostrarErrores(); return end
    if orden == "jefes" or orden == "bosses" then
      local nombres = {}
      for jefe, lista in pairs(jefesAqui()) do table.insert(nombres, jefe .. " (" .. #lista .. ")") end
      print(AZUL .. L("jefes con tus piezas aqui: ", "bosses with your items here: ") .. (enInstancia and (#nombres > 0 and table.concat(nombres, ", ") or L("ninguno", "none")) or L("no estas en una mazmorra", "you are not in a dungeon")))
      if UnitExists and UnitExists("target") then
        local placa = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
        local d = diagnostico("target", placa)
        print(AZUL .. L("enemigo seleccionado: ", "target: ") .. "GUID=" .. d.guid .. " · " .. L("nombre", "name") .. "=" .. d.nombre .. " · id=" .. tostring(d.id)
          .. " · " .. L("oculto", "hidden") .. "=" .. d.oculta .. " · boss=" .. d.jefeBoss .. " · " .. d.clase .. " · " .. L("nivel", "level") .. "=" .. d.nivel
          .. " · " .. L("placa", "nameplate") .. "=" .. d.placa .. " · " .. L("combate", "fight") .. "=" .. d.encuentro .. " · " .. L("marca", "mark") .. "=" .. d.resultado)
      else
        print(AZUL .. L("selecciona a un jefe y repite /wowf jefes para ver que lee el addon.", "target a boss and type /wowf bosses again to see what the addon reads."))
      end
      return
    end
    if ordenJefes then return ordenJefes(mensaje, ...) end
  end
end
end -- fin del bloque de errores y jefes

local eventos = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "LOOT_OPENED", "START_LOOT_ROLL" }) do
  pcall(eventos.RegisterEvent, eventos, e)
end
local primeraVez = true
eventos:SetScript("OnEvent", function(_, evento, a1)
  if evento == "PLAYER_ENTERING_WORLD" then
    revisarInstancia()
    if primeraVez then
      primeraVez = false
      -- Retomar la ruta que estaba en marcha
      local f = WowFExportarDB.farmeo
      if f and f.prof and WowFFarmeo and WowFFarmeo[f.prof] then despues(3, function()
        if not rutaGuardadaMia(f) then return end -- otro personaje de la cuenta, o ya no tiene esa profesion
        empezarRuta(f.prof, false, f.zona, f.i); tramoVisto[f.prof] = ruta and ruta.tramo.a
      end) end
    end
  elseif evento == "ZONE_CHANGED_NEW_AREA" then
    revisarInstancia()
  elseif evento == "PLAYER_LEVEL_UP" then
    local nivel = tonumber(a1) or nivelActual()
    despues(1, function() pcall(alSubir, nivel); pcall(actualizar) end)
  elseif evento == "SKILL_LINES_CHANGED" then
    pcall(revisarHabilidad)
  elseif evento == "LOOT_OPENED" then
    if GetNumLootItems and GetLootSlotLink then
      for i = 1, GetNumLootItems() do pcall(revisarBotin, GetLootSlotLink(i), false) end
    end
  elseif evento == "START_LOOT_ROLL" then
    if GetLootRollItemLink then pcall(revisarBotin, GetLootRollItemLink(a1), true) end
  end
  actualizarPronto()
end)

-- ===================== Comandos (los de antes siguen en wowF_Exportar.lua, dentro de ForeverLevelingGuide) =====================
local ordenAnterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower()
  if orden == "panel" then
    if panel:IsShown() then panel:Hide(); WowFExportarDB.panel = WowFExportarDB.panel or {}; WowFExportarDB.panel.oculto = true
    else panel:Show(); if WowFExportarDB.panel then WowFExportarDB.panel.oculto = nil end; actualizar() end
    return
  end
  if orden == "farmeo" or orden == "f" then
    local prof = profDeTexto(resto)
    ofrecerRuta(prof or rutaPorDefecto())
    return
  end
  if orden == "parar" then pararRuta(); return end
  if orden == "objetivo" and WowF.elegirObjetivo then
    local o = resto:lower()
    if o == "vender" or o == "ganar" then o = "oro" elseif o == "fabricarme" or o == "craftear" or o == "equipo" then o = "fabricar" end
    local n = WowF.elegirObjetivo(o)
    if n then print(WowF.T(AZUL .. "Objetivo de las profesiones: " .. n .. ".")) else print(WowF.T(AZUL .. "Usa /wowf objetivo fabricar, /wowf objetivo oro o /wowf objetivo pvp.")) end
    actualizar()
    return
  end
  if orden == "rama" then
    if resto:lower() == "auto" then
      if WowFExportarDB.rama then WowFExportarDB.rama[clavePersonaje()] = nil end
      if WowF.cambiarRama then WowF.olvidarCache = true end
      print(WowF.T(AZUL .. "Rama del plan: la de tus talentos."))
    else
      local n = WowF.cambiarRama and WowF.cambiarRama()
      if n then print(WowF.T(AZUL .. "Rama del plan: " .. n .. ". Escribe /wowf rama otra vez para la siguiente, o /wowf rama auto.")) end
    end
    actualizar()
    return
  end
  if ordenAnterior then ordenAnterior(mensaje) end
end

-- Posicion guardada (por defecto: a la derecha, debajo del minimapa)
local pos = WowFExportarDB.panel
panel:ClearAllPoints()
if pos and pos.punto and pos.x then
  panel:SetPoint(pos.punto, UIParent, pos.relativo or pos.punto, pos.x, pos.y)
else
  panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -230)
end
if pos and pos.oculto then panel:Hide() else panel:Show() end
pcall(actualizar)
