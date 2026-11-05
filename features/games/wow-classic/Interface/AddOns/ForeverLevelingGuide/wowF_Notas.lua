-- Forever Leveling Guide: novedades del ultimo parche (7-oct, pedido de Andy: "cada vez que alguien actualice el addon y haga /reload,
-- que le salgan en pantalla las notas del parche").
-- Al entrar (PLAYER_LOGIN) compara la version del .toc con WowFExportarDB.notasVistas:
--   * version nueva y NO es la primera vez del jugador -> ventana "Novedades de la X.Y" + una linea en el chat
--   * primera vez (sale la bienvenida) -> solo guarda la version
-- Dentro del addon van SOLO las notas del ultimo parche (WowFNotas, wowF_Notas_Datos.lua, generado); el historial completo, en CurseForge.
-- /wowf novedades (o changes, patchnotes, notas, news) la abre cuando quieras. WowF.abrirNotas() para un boton del Libro.

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local ORO, GRIS, AZUL, VERDE, BLANCO = "|cffffd100", "|cff999999", "|cff33ccff", "|cff33ff66", "|cffffffff"

local function db()
  if type(WowFExportarDB) ~= "table" then WowFExportarDB = {} end
  return WowFExportarDB
end
local function datos() return type(WowFNotas) == "table" and WowFNotas or nil end

-- Version instalada: la del .toc (## Version); si el cliente no la da, la de las notas
local function versionAddon()
  local v
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    local ok, x = pcall(C_AddOns.GetAddOnMetadata, "ForeverLevelingGuide", "Version"); if ok then v = x end
  elseif GetAddOnMetadata then
    local ok, x = pcall(GetAddOnMetadata, "ForeverLevelingGuide", "Version"); if ok then v = x end
  end
  if type(v) ~= "string" or v == "" then v = datos() and datos().version or nil end
  return v
end
WowF.versionAddon = versionAddon

local function lineas()
  local d = datos()
  if not d then return {} end
  local t = L(d.es, d.en)
  return type(t) == "table" and t or {}
end

-- ===================== Ventana =====================
local v, titulo, fecha, cuerpo, hijo, desliz, pie, botonCerrar

-- Marca de "vista" = version + huella del texto de las notas (16-oct: con la misma version y notas nuevas no volvia a salir)
local function marcaNotas()
  local ver = versionAddon()
  if not ver then return nil end
  local d, h = datos(), 0
  if d and type(d.es) == "table" then
    for _, s in ipairs(d.es) do
      for i = 1, #s, 7 do h = (h * 31 + s:byte(i)) % 1000003 end
    end
  end
  return ver .. "#" .. h
end

WowF.marcaNotas = marcaNotas

local function marcarVista()
  local m = marcaNotas()
  if m then db().notasVistas = m end
end

local function texto()
  local t = {}
  local E = WowF.estilo
  for _, s in ipairs(lineas()) do t[#t + 1] = E.cod.brasa .. "-|r " .. E.cod.texto .. s .. "|r" end
  if #t == 0 then t[1] = E.cod.tenue .. L("No hay notas para esta versión.", "No notes for this version.") .. "|r" end
  return table.concat(t, "\n\n")
end

local function refrescar()
  if not v then return end
  local d = datos()
  local ver = (d and d.version) or versionAddon() or "?"
  titulo:SetText(L("Novedades de la ", "What's new in ") .. ver)
  fecha:SetText(WowF.estilo.mayus("Forever Guide" .. ((d and d.fecha) and (" · " .. d.fecha) or "")))
  cuerpo:SetText(texto())
  local ok, h = pcall(cuerpo.GetStringHeight, cuerpo)
  if hijo and hijo.SetHeight then pcall(hijo.SetHeight, hijo, ((ok and type(h) == "number") and h or 200) + 10) end
  if desliz and desliz.SetVerticalScroll then pcall(desliz.SetVerticalScroll, desliz, 0) end
  pie:SetText(L("Historial completo en la página del addon en CurseForge.", "Full history on the addon's CurseForge page."))
  botonCerrar:SetText(L("Cerrar", "Close"))
end

local function crear()
  if v then return v end
  v = CreateFrame("Frame", "wowFNotas", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  v:SetSize(440, 400)
  v:SetPoint("CENTER", 0, 60)
  v:SetFrameStrata("DIALOG")
  v:SetClampedToScreen(true)
  v:SetMovable(true)
  v:EnableMouse(true)
  v:RegisterForDrag("LeftButton")
  v:SetScript("OnDragStart", v.StartMoving)
  v:SetScript("OnDragStop", v.StopMovingOrSizing)
  if v.SetBackdrop then
    v:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    v:SetBackdropColor(0.03, 0.03, 0.05, 0.96)
    v:SetBackdropBorderColor(1, 0.82, 0, 0.9)
  end
  WowF.estilo.marco(v, "tapa")
  -- 11-oct, rediseño "hibrido": icono en casilla, etiqueta brasa (Forever Guide · fecha), titulo serif, divisor,
  -- texto Signika con raya brasa por nota, pie gris y un solo boton principal brasa
  local E = WowF.estilo
  local casilla = E.textura(v, "ARTWORK", 1, E.color.borde, 1)
  casilla:SetSize(40, 40)
  casilla:SetPoint("TOPLEFT", 22, -24)
  local icono = v:CreateTexture(nil, "ARTWORK", nil, 3)
  icono:SetSize(36, 36)
  icono:SetPoint("CENTER", casilla, "CENTER")
  if icono.SetTexCoord then icono:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  icono:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
  fecha = E.etiqueta(v, nil, nil, 9)
  fecha:SetPoint("TOPLEFT", casilla, "TOPRIGHT", 12, -2)
  fecha:SetPoint("RIGHT", v, "RIGHT", -44, 0)
  titulo = E.titulo(v, nil, 17)
  titulo:SetPoint("TOPLEFT", fecha, "BOTTOMLEFT", 0, -5)
  titulo:SetPoint("RIGHT", v, "RIGHT", -44, 0)
  local x = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
  E.boton(x, "cuero")
  x:SetSize(18, 18)
  x:SetText("X")
  x:SetPoint("TOPRIGHT", -16, -18)
  x:SetScript("OnClick", function() marcarVista(); v:Hide() end)
  E.divisor(v, nil, -76, 22, 22)
  -- Texto con desplazamiento (la rueda del raton lo mueve)
  desliz = CreateFrame("ScrollFrame", nil, v, "UIPanelScrollFrameTemplate")
  desliz:SetPoint("TOPLEFT", 24, -88)
  desliz:SetPoint("BOTTOMRIGHT", -40, 76)
  hijo = CreateFrame("Frame", nil, desliz)
  hijo:SetSize(370, 200)
  cuerpo = E.cuerpo(hijo, nil, 12)
  cuerpo:SetPoint("TOPLEFT", 0, 0)
  cuerpo:SetWidth(370)
  cuerpo:SetJustifyH("LEFT")
  if cuerpo.SetJustifyV then cuerpo:SetJustifyV("TOP") end
  if cuerpo.SetSpacing then cuerpo:SetSpacing(2) end
  desliz:SetScrollChild(hijo)
  E.divisor(v, nil, -334, 22, 22)
  pie = E.sub(v, nil, 10)
  pie:SetPoint("BOTTOM", 0, 48)
  pie:SetWidth(392)
  if pie.SetJustifyH then pie:SetJustifyH("CENTER") end
  botonCerrar = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
  E.boton(botonCerrar, "brasa")
  botonCerrar:SetSize(130, 24)
  botonCerrar:SetPoint("BOTTOM", 0, 16)
  botonCerrar:SetScript("OnClick", function() marcarVista(); v:Hide() end)
  -- Escape la cierra (como las ventanas del juego)
  WowF.cerrarConEsc("wowFNotas")
  v:Hide()
  return v
end

function WowF.abrirNotas()
  crear()
  refrescar()
  if WowF.opciones and v.SetScale then pcall(v.SetScale, v, WowF.escalaVentana and WowF.escalaVentana("wowFNotas") or WowF.opciones().tamano) end
  v:Show()
  return v
end
function WowF.cerrarNotas() if v then marcarVista(); v:Hide() end end
-- Si cambia el idioma con la ventana abierta (/wowf idioma), se redibuja
local reidiomarAntes = WowF.reidiomar
WowF.reidiomar = function(...)
  if reidiomarAntes then reidiomarAntes(...) end
  if v and v:IsShown() then pcall(refrescar) end
end

-- Para las pruebas: lo que se ve
function WowF.notasEstado()
  return { abierta = v ~= nil and v:IsShown() or false, titulo = v and titulo:GetText() or "", texto = v and cuerpo:GetText() or "",
    pie = v and pie:GetText() or "", boton = v and botonCerrar:GetText() or "", cerrar = function() if botonCerrar then botonCerrar:GetScript("OnClick")() end end }
end

-- ===================== Al entrar =====================
local function alEntrar()
  local ver, marca = versionAddon(), marcaNotas()
  if not ver or not marca then return end
  local d = db()
  if d.notasVistas == marca then return end
  -- Primera vez del jugador (o sin la bienvenida terminada): ya sale la bienvenida; solo se guarda la marca
  -- 4-nov: con la DB vacia, quien ya jugaba (nivel > 5 o profesiones: instalacion nueva, p. ej. la carpeta _forever_ del
  -- lanzamiento) no ve la bienvenida (se le rehacen los ajustes) y antes tampoco las novedades: ahora SI las ve
  local primera
  if WowF.dbEstabaVacia and WowF.dbEstabaVacia() then
    local okV, vet = pcall(function() return WowF.pjVeterano and WowF.pjVeterano() end)
    primera = not (okV and vet)
  else
    primera = not d.bienvenida or not d.idiomaVisto
  end
  if primera then d.notasVistas = marca; return end
  print(AZUL .. "Forever Guide|r " .. L("actualizado a ", "updated to ") .. ORO .. ver .. "|r" .. L(": escribe ", ": type ") .. ORO .. L("/wowf novedades", "/wowf changes") .. "|r" .. L(" para ver qué cambió.", " to see what changed."))
  -- En combate o con la interfaz oculta (cinematica de entrada) espera y reintenta cada 2 s (hasta ~3 min); si no, sale al proximo /reload
  local intentos = 0
  local function abrir()
    local ocupada = (WowF.interfazOcupada and WowF.interfazOcupada()) or (InCombatLockdown and InCombatLockdown())
    if ocupada then
      intentos = intentos + 1
      if intentos <= 90 and C_Timer and C_Timer.After then C_Timer.After(2, abrir) end
      return
    end
    WowF.abrirNotas()
  end
  if C_Timer and C_Timer.After then C_Timer.After(6, abrir) else abrir() end
end
local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, evento) if evento == "PLAYER_LOGIN" then pcall(alEntrar) end end)

-- ----- /wowf novedades | changes | patchnotes | notas | news -----
local ordenAnterior = SlashCmdList and SlashCmdList["WOWF"]
if SlashCmdList then
  SlashCmdList["WOWF"] = function(mensaje, ...)
    local orden = ((mensaje or ""):match("^%s*(%S*)") or ""):lower()
    if orden == "novedades" or orden == "changes" or orden == "patchnotes" or orden == "notas" or orden == "news" or orden == "changelog" then
      WowF.abrirNotas()
      return
    end
    if ordenAnterior then return ordenAnterior(mensaje, ...) end
  end
end
