-- wowF Libro: el plan completo en una ventana con pestanas (lo que antes mostraba la guia wowF.exe).
-- Talentos, Profesiones, Equipo, Mazmorras y Subida, armado en el juego con WowF.armarPlan().
-- Ordenado por secciones: cada nivel con su encabezado, lo ya pasado plegado en una linea, iconos reales.
-- Se abre con /wowf (o /wowf plan), con el boton del minimapa y con "Plan completo" del panel.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local ORO, VERDE, GRIS, BLANCO, NARANJA, CELESTE = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933", "|cff66ccff"
local CALIDAD = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }
local ANCHO, ALTO = 1100, 780 -- 11-oct (rediseno por tarjetas): el tamano de la maqueta (comun.css)
local PESTANAS = { "Progreso", "Talentos", "Combate", "Rotacion", "Macros", "Profesiones", "Rares", "Equipo", "Mazmorras", "BiS 30" } -- 19-oct (Andy): Rares despues de Profesiones
local ICONO = {
  talento = "Interface\\Icons\\INV_Misc_Book_09", rama = "Interface\\Icons\\INV_Misc_Book_11", hito = "Interface\\Icons\\INV_Misc_Note_01",
  zona = "Interface\\Icons\\INV_Misc_Map_01", prof = "Interface\\Icons\\INV_Misc_Gear_01", mazmorra = "Interface\\Icons\\INV_Misc_Key_03",
  [186] = "Interface\\Icons\\Trade_Mining", [182] = "Interface\\Icons\\Trade_Herbalism", [393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
  [165] = "Interface\\Icons\\Trade_LeatherWorking", [197] = "Interface\\Icons\\Trade_Tailoring", [164] = "Interface\\Icons\\Trade_BlackSmithing",
  [171] = "Interface\\Icons\\Trade_Alchemy", [202] = "Interface\\Icons\\Trade_Engineering", [333] = "Interface\\Icons\\Trade_Engraving",
}

local function nivelActual() return UnitLevel("player") or 1 end
local function tengo(id) return (GetItemCount and GetItemCount(id, true)) or 0 end
local function colorCalidad(q)
  if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] and ITEM_QUALITY_COLORS[q].hex then return ITEM_QUALITY_COLORS[q].hex end
  return CALIDAD[q] or BLANCO
end
-- 12-oct: icono del propio objeto (cliente primero; ic = respaldo de los datos de ESE objeto)
local function icono(ic, id)
  return (WowF.iconoObjeto and WowF.iconoObjeto(id, ic)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function obj(id)
  local o = WowFDatos and WowFDatos.obj[id]
  if o then return o[1], o[2], o[3], o[4] end
  return "objeto " .. tostring(id), 1, "", nil
end
local function trozos(t)
  local res = {}
  for x in (tostring(t or "") .. " · "):gmatch("(.-) · ") do if x ~= "" then table.insert(res, x) end end
  return res
end

-- ===================== Ventana (11-oct: rediseno "hibrido", la maqueta que aprobo Andy) =====================
-- Tapa de cuero con filete dorado y losa de piedra; arriba a la izquierda la etiqueta "FOREVER GUIDE"; las pestanas son
-- CINTAS que cuelgan del borde de arriba (la abierta, roja y mas larga); a la izquierda el ESTANDARTE de tu faccion con el
-- icono de tu clase, tu nombre, raza/clase/rama/faccion y el sello de cera con tu nivel; a la derecha, el contenido.
local libro = CreateFrame("Frame", "wowFLibro", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
libro:SetSize(ANCHO, ALTO)
libro:SetPoint("CENTER")
libro:SetFrameStrata("HIGH")
libro:SetMovable(true)
libro:EnableMouse(true)
libro:RegisterForDrag("LeftButton")
libro:SetScript("OnDragStart", libro.StartMoving)
libro:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); WowF.estilo.guardarPos(self, "libroPos") end)
libro:SetClampedToScreen(true)
-- 11-oct (Andy: "solo me deja moverla de izquierda a derecha arriba"): la ventana puede salir de la pantalla por los lados y por abajo;
-- siempre queda a la vista la parte de arriba (la marca y las cintas) para volver a cogerla
if libro.SetClampRectInsets then libro:SetClampRectInsets(ANCHO - 160, -(ANCHO - 160), 18, ALTO - 90) end
-- 12-oct (Andy: "cuando el mapa se abre no me deja moverla"): el mapa del juego quedaba encima del Libro (o su capa oscura atrapaba
-- el raton). Con el mapa abierto, el Libro sube a la capa del mapa y al frente; clic en el Libro = vuelve al frente; al cerrar, HIGH.
if libro.SetToplevel then pcall(libro.SetToplevel, libro, true) end
do
  local ORDEN = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
  local function alFrente()
    if not (libro:IsShown() and WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown()) then return end
    local ok, s = pcall(WorldMapFrame.GetFrameStrata, WorldMapFrame)
    if ok and type(s) == "string" and (ORDEN[s] or 0) > ORDEN.HIGH then pcall(libro.SetFrameStrata, libro, s) end
    pcall(libro.Raise, libro)
  end
  WowF.libroAlFrente = alFrente
  if WorldMapFrame and WorldMapFrame.HookScript then
    WorldMapFrame:HookScript("OnShow", function() alFrente() end)
    WorldMapFrame:HookScript("OnHide", function() pcall(libro.SetFrameStrata, libro, "HIGH") end)
  end
  libro:HookScript("OnShow", function() alFrente() end)
  libro:HookScript("OnMouseDown", function() alFrente() end)
end
local E = WowF.estilo
local C = E.color
E.marco(libro, "libro")
E.alFrente(libro)
libro:Hide()
WowF.libro = libro
WowF.cerrarConEsc("wowFLibro") -- Esc la cierra

local function L(es, en) return (WowF.enIngles and WowF.enIngles()) and en or es end
local dibujar
local pestana = "Progreso"
-- Cualquier pieza de la ventana sirve para arrastrarla
local function moverConLibro(f)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() libro:StartMoving() end)
  f:SetScript("OnDragStop", function() libro:StopMovingOrSizing(); E.guardarPos(libro, "libroPos") end)
end
local function ayuda(b, titulo, texto)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(titulo(), 1, 0.82, 0)
    GameTooltip:AddLine(texto(), 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end
local function irArriba()
  local sc = _G.wowFLibroScroll -- el ScrollFrame se crea mas abajo
  if sc and sc.SetVerticalScroll then sc:SetVerticalScroll(0) end
end

-- ----- Marca "FOREVER GUIDE  Plan completo" (arriba a la izquierda, en x 30 / y 22 de la maqueta) -----
-- Cinzel 13 en oro con aire entre letras; al lado "Plan completo" en Alegreya 12 tenue. El emblema de tu faccion va delante.
local etiqueta = CreateFrame("Frame", nil, libro)
etiqueta:SetSize(320, 22)
etiqueta:SetPoint("TOPLEFT", libro, "TOPLEFT", 26, -18)
local emblema = E.emblemaFaccion and E.emblemaFaccion(etiqueta, 20)
local titulo = etiqueta:CreateFontString(nil, "OVERLAY", "GameFontNormal")
if emblema then
  emblema:SetPoint("LEFT", etiqueta, "LEFT", 0, 0)
  titulo:SetPoint("LEFT", emblema, "RIGHT", 6, 0)
else titulo:SetPoint("LEFT", etiqueta, "LEFT", 4, 0) end
E.letra(titulo, "marca", 13)
titulo:SetTextColor(C.oro[1], C.oro[2], C.oro[3])
titulo:SetText("F O R E V E R   G U I D E")
local subtitulo = etiqueta:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitulo:SetPoint("LEFT", titulo, "RIGHT", 10, 0)
subtitulo:Hide() -- 11-oct (Andy lo tacho: se montaba sobre "FOREVER GUIDE")
E.letra(subtitulo, "cuerpoMedio", 12)
subtitulo:SetTextColor(C.tenue[1], C.tenue[2], C.tenue[3])
moverConLibro(etiqueta)
WowF.libroMarca = etiqueta

-- ----- Cerrar (28 x 28, piedra con filete de oro, a 22 / 16 de la esquina) -----
local cerrar = CreateFrame("Button", nil, libro)
cerrar:SetSize(28, 28)
cerrar:SetPoint("TOPRIGHT", libro, "TOPRIGHT", -22, -16)
do
  local b = E.textura(cerrar, "BACKGROUND", 1, C.oro2, 1); b:SetAllPoints()
  local f = E.textura(cerrar, "BACKGROUND", 2, C.piedra2, 1); f:SetPoint("TOPLEFT", 1, -1); f:SetPoint("BOTTOMRIGHT", -1, 1)
  local luz = E.textura(cerrar, "ARTWORK", 1, { 1, 1, 1 }, 0.10); luz:SetPoint("TOPLEFT", 1, -1); luz:SetPoint("BOTTOMRIGHT", -1, 1); luz:Hide()
  local x = cerrar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  x:SetPoint("CENTER", 0, 0)
  E.letra(x, "cuerpoNegrita", 15)
  x:SetTextColor(C.oro[1], C.oro[2], C.oro[3])
  x:SetText("X")
  cerrar:SetScript("OnEnter", function() luz:Show() end)
  cerrar:SetScript("OnLeave", function() luz:Hide() end)
end
cerrar:SetScript("OnClick", function() libro:Hide() end)

-- ----- Cintas (pestanas que cuelgan del borde de arriba) -----
-- "Combate" junta Rotacion y Macros (se cambia entre las dos con la fila de arriba de su contenido)
local CINTAS = { "Progreso", "Talentos", "Combate", "Profesiones", "Rares", "Equipo", "Mazmorras", "BiS 30" }
local NOMBRE_CINTA = {
  Progreso = { "Progreso", "Progress" }, Talentos = { "Talentos", "Talents" }, Combate = { "Combate", "Combat" },
  Profesiones = { "Profesiones", "Professions" }, Equipo = { "Equipo", "Gear" }, Mazmorras = { "Mazmorras", "Dungeons" }, ["BiS 30"] = { "BiS 30", "BiS 30" },
  Rares = { "Rares", "Rares" }, -- 19-oct (Andy): pestana de rares (wowF_VistaRares.lua)
}
local COMBATE = { Rotacion = true, Macros = true }
local ultimaCombate = "Rotacion"
local function cintaDe(nombre) if COMBATE[nombre] then return "Combate" end return nombre end
local botones = {}
-- comun.css .cinta: normal cuero2 con letra #b3a184; abierta = cera (sigue el tema de tu faccion) con letra oro claro
local COLOR_CINTA = { normal = C.cuero2, encima = { 0.30, 0.20, 0.13 } }
local function pintarCinta(b)
  local abierta = cintaDe(pestana) == b.nombre
  local c = abierta and E.tema().toggleOn or (b.encima and COLOR_CINTA.encima or COLOR_CINTA.normal)
  if b.tela.SetVertexColor then b.tela:SetVertexColor(c[1], c[2], c[3], 1) end
  if abierta then b.t:SetTextColor(C.orocl[1], C.orocl[2], C.orocl[3]) else b.t:SetTextColor(0.702, 0.631, 0.518) end
end
for _, nombre in ipairs(CINTAS) do
  local b = CreateFrame("Button", nil, libro)
  b.nombre = nombre
  b:SetFrameLevel((type(libro:GetFrameLevel()) == "number" and libro:GetFrameLevel() or 1) + 5)
  local tela = b:CreateTexture(nil, "ARTWORK")
  tela:SetTexture(E.texturas.cinta)
  tela:SetAllPoints()
  b.tela = tela
  local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t:SetPoint("BOTTOM", 0, 13)
  E.letra(t, "marca", 11)
  b.t = t
  b:SetScript("OnEnter", function(self) self.encima = true; pintarCinta(self) end)
  b:SetScript("OnLeave", function(self) self.encima = false; pintarCinta(self) end)
  b:SetScript("OnClick", function()
    if nombre == "Combate" then pestana = ultimaCombate else pestana = nombre end
    dibujar(); irArriba()
  end)
  botones[nombre] = b
end
WowF.libroBotonBiS = botones["BiS 30"]
-- De derecha a izquierda (empiezan a 64 px del borde derecho, 5 px entre cintas, minimo 84 de ancho); alto 48, la abierta 60.
-- El ancho sigue al texto (el ingles es mas largo).
local function colocarCintas()
  local x = -64
  for k = #CINTAS, 1, -1 do
    local b = botones[CINTAS[k]]
    local n = NOMBRE_CINTA[CINTAS[k]]
    b.t:SetText(WowF.yaTraducido(L(n[1], n[2]):upper()))
    local w = b.t:GetStringWidth()
    w = math.max(84, math.floor((type(w) == "number" and w or 50) + 20 + 0.5))
    local abierta = cintaDe(pestana) == b.nombre
    b:SetSize(w, abierta and 60 or 48)
    b:ClearAllPoints()
    b:SetPoint("TOPRIGHT", libro, "TOPRIGHT", x, -6)
    pintarCinta(b)
    x = x - w - 5
  end
end

-- ----- Estandarte (banner de la maqueta): 124 x 430, colgando del borde de arriba de la losa -----
-- Escudo oscuro con la cara de tu personaje (si el cliente no la da, el icono de tu clase), tu nombre en Cinzel 18,
-- raza y clase, la rama en oro claro (clic = elegir rama) y la faccion; el sello de cera con tu nivel al pie.
local ANCHO_EST = 124
local est = CreateFrame("Frame", nil, libro)
est:SetSize(ANCHO_EST, 340) -- 12-oct (Andy): mas corto (antes 430); debajo va el adorno mistico
est:SetPoint("TOPLEFT", libro, "TOPLEFT", 29, -61)
est:SetFrameLevel((type(libro:GetFrameLevel()) == "number" and libro:GetFrameLevel() or 1) + 4)
moverConLibro(est)
est.tela = est:CreateTexture(nil, "BACKGROUND", nil, 3)
est.tela:SetTexture(E.texturas.banderin)
est.tela:SetAllPoints()
est.escudo = est:CreateTexture(nil, "ARTWORK", nil, 1)
est.escudo:SetTexture(E.texturas.escudo2)
est.escudo:SetSize(74, 88)
est.escudo:SetPoint("TOP", est, "TOP", 0, -20)
if est.escudo.SetVertexColor then est.escudo:SetVertexColor(0.114, 0.071, 0.063, 1) end
-- Retrato: la cara del personaje (E.retratoJugador); respaldo = icono de la clase
est.retrato = E.retratoJugador(est, 52)
est.retrato:SetPoint("TOP", est, "TOP", 0, -26)
est.retrato:SetFrameLevel((type(est:GetFrameLevel()) == "number" and est:GetFrameLevel() or 1) + 2)
est.icono = est.retrato.tex -- compatibilidad: antes era la textura del icono de la clase
est.nombre = est:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
est.nombre:SetPoint("TOP", est, "TOP", 0, -122)
if est.nombre.SetWordWrap then est.nombre:SetWordWrap(false) end
est.nombre:SetTextColor(C.texto[1], C.texto[2], C.texto[3])
est.datos = est:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
est.datos:SetPoint("TOP", est.nombre, "BOTTOM", 0, -8)
est.datos:SetWidth(ANCHO_EST - 20)
E.letra(est.datos, "cuerpoMedio", 13)
est.datos:SetTextColor(1, 0.851, 0.761)
-- La rama, en oro claro y negrita, es un boton: un clic abre el selector de rama en Talentos
local botonRama = CreateFrame("Button", nil, est)
botonRama:SetSize(ANCHO_EST - 16, 32) -- 11-oct: 2 renglones ("Enhancement -> Elemental al 40" se salia del estandarte)
botonRama:SetPoint("TOP", est.datos, "BOTTOM", 0, -2)
do
  local fs = botonRama:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("CENTER", 0, 0)
  fs:SetWidth(ANCHO_EST - 16)
  if fs.SetWordWrap then fs:SetWordWrap(true) end
  if fs.SetJustifyH then fs:SetJustifyH("CENTER") end
  E.letra(fs, "cuerpoNegrita", 12)
  fs:SetTextColor(C.orocl[1], C.orocl[2], C.orocl[3])
  if botonRama.SetFontString then botonRama:SetFontString(fs) end
  botonRama.fs = fs
  local raya = E.textura(botonRama, "ARTWORK", 1, C.orocl, 0.6)
  raya:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -1); raya:SetPoint("TOPRIGHT", fs, "BOTTOMRIGHT", 0, -1); raya:SetHeight(1)
  raya:Hide()
  botonRama:SetScript("OnLeave", function() raya:Hide(); if GameTooltip then GameTooltip:Hide() end end)
  botonRama.raya = raya
end
WowF.textoFijo(botonRama, "Elegir rama")
botonRama:SetScript("OnClick", function()
  pestana = "Talentos"; WowF.libroRamasAbiertas = true; dibujar(); irArriba()
end)
botonRama:SetScript("OnEnter", function(self)
  if self.raya then self.raya:Show() end
  if not GameTooltip then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(L("Tu rama", "Your spec"), 1, 0.82, 0)
  GameTooltip:AddLine(L("Clic para elegir otra rama (abre la lista en Talentos).", "Click to choose another spec (opens the list in Talents)."), 1, 1, 1, true)
  GameTooltip:Show()
end)
WowF.libroBotonRama = botonRama
est.faccion = est:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
est.faccion:SetPoint("TOP", botonRama, "BOTTOM", 0, -2)
E.letra(est.faccion, "cuerpoMedio", 13)
est.faccion:SetTextColor(1, 0.851, 0.761)

-- ----- Botones del lado (abajo a la izquierda): secundarios chicos de 124 de ancho, 6 px entre ellos -----
-- De abajo arriba: English/Espanol, Ajustes (los dos de la maqueta); encima, Limpiar el mapa, Novedades y "?".
local lado = CreateFrame("Frame", nil, libro)
lado:SetSize(ANCHO_EST, 10)
lado:SetPoint("BOTTOMLEFT", libro, "BOTTOMLEFT", 29, 29)
lado:SetFrameLevel((type(libro:GetFrameLevel()) == "number" and libro:GetFrameLevel() or 1) + 4)
local function suave(k, w)
  local b = CreateFrame("Button", nil, lado, "UIPanelButtonTemplate")
  b:SetSize(w or ANCHO_EST, 28)
  E.boton(b, "secundario", 13, true)
  b:SetWidth(w or ANCHO_EST)
  b:SetPoint("BOTTOMLEFT", lado, "BOTTOMLEFT", 0, (k - 1) * 34)
  return b
end
-- Idioma: dice el idioma AL QUE cambia (English / Español); cambia todo al momento, sin /reload
local botonIdioma = suave(1)
function WowF.botonIdiomaActualizar() botonIdioma:SetText(WowF.enIngles() and "Español" or "English") end
WowF.botonIdiomaActualizar()
botonIdioma:SetScript("OnClick", function()
  WowFExportarDB = WowFExportarDB or {}
  WowFExportarDB.idioma = WowF.enIngles() and "es" or "en"
  WowF.reidiomar()
  print(WowF.enIngles() and "|cff33ccffForever Guide|r: language = English." or "|cff33ccffForever Guide|r: idioma = espanol.")
end)
ayuda(botonIdioma, function() return L("Idioma", "Language") end,
  function() return L("Cambia todo el addon a ingles al momento.", "Switches the whole addon to Spanish right away.") end)
WowF.botonIdioma = botonIdioma
-- Ajustes (tamano de las ventanas y opacidad del fondo; wowF_Opciones.lua)
local botonAjustes = suave(2)
WowF.textoFijo(botonAjustes, "Ajustes")
botonAjustes:SetScript("OnClick", function() if WowF.abrirOpciones then WowF.abrirOpciones() end end)
botonAjustes:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(WowF.T("Ajustes"), 1, 0.82, 0)
  GameTooltip:AddLine(WowF.T("Tamaño de las ventanas y opacidad del fondo"), 1, 1, 1, true)
  GameTooltip:Show()
end)
botonAjustes:SetScript("OnLeave", function() GameTooltip:Hide() end)
WowF.botonAjustesLibro = botonAjustes
-- Limpiar el mapa de un clic (rutas de mazmorra, mision y farmeo, sus marcas y el alfiler)
local botonLimpiar = suave(4) -- 11-oct (maqueta): solo se ve con una ruta o marca activa (dibujar)
WowF.textoFijo(botonLimpiar, "Limpiar el mapa")
botonLimpiar:SetScript("OnClick", function() if WowF.limpiarRutas then WowF.limpiarRutas(false) end end)
WowF.botonLimpiarLibro = botonLimpiar
-- Novedades / What's new (wowF_Notas.lua); el texto se pone en dibujar() con L()
-- 11-oct (maqueta): Novedades, "?" y el entrenador de clase van en UNA fila de iconos chicos encima de Ajustes
local function iconoBoton(b, ruta)
  local tx = b:CreateTexture(nil, "OVERLAY")
  tx:SetPoint("TOPLEFT", 4, -4); tx:SetPoint("BOTTOMRIGHT", -4, 4)
  pcall(tx.SetTexture, tx, ruta)
  local fsb = b.GetFontString and b:GetFontString()
  if fsb and fsb.SetAlpha then fsb:SetAlpha(0) end -- el texto sigue (tooltip y pruebas), el icono es lo que se ve
  b.icono = tx
  return tx
end
local botonNotas = suave(3, 28)
botonNotas:SetText(WowF.enIngles() and "What's new" or "Novedades")
iconoBoton(botonNotas, "Interface\\Icons\\INV_Misc_Note_01")
botonNotas:SetScript("OnClick", function() if WowF.abrirNotas then WowF.abrirNotas() end end)
ayuda(botonNotas, function() return L("Novedades", "What's new") end,
  function() return L("Lo que cambio en cada version del addon.", "What changed in each version of the addon.") end)
WowF.libroBotonNotas = botonNotas
-- "?" = que significa cada color; a su lado, el icono del entrenador de clase (wowF_EntrenadorClase.lua lo crea; se coloca en dibujar)
local botonLeyenda = suave(3, 28)
botonLeyenda:ClearAllPoints(); botonLeyenda:SetPoint("LEFT", botonNotas, "RIGHT", 6, 0)
botonLeyenda:SetText("?")
botonLeyenda:SetScript("OnEnter", function(self)
  if not GameTooltip then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(L("Que significa cada color", "What each color means"), 1, 0.82, 0)
  for _, l in ipairs(E.leyenda(WowF.enIngles and WowF.enIngles())) do GameTooltip:AddLine(l[1] .. l[2] .. "|r", 1, 1, 1, true) end
  GameTooltip:AddLine(L("Arrastra el estandarte o el borde para mover la ventana.", "Drag the banner or the border to move the window."), 0.6, 0.6, 0.6, true)
  GameTooltip:AddLine(L("Clic: Guía del addon (qué es cada cosa y cómo se usa).", "Click: Addon guide (what everything is and how to use it)."), 0.2, 1, 0.4, true)
  GameTooltip:Show()
end)
-- 13-oct: el ? abre la Guia del addon (wowF_Guia.lua)
botonLeyenda:SetScript("OnClick", function() if WowF.abrirGuia then WowF.abrirGuia() end end)
botonLeyenda:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
WowF.libroBotonLeyenda = botonLeyenda

-- ----- Sello de cera con tu nivel (circulo de 76 en cera, borde de 3 px #6e1512 y aro fino de oro), al pie del estandarte -----
local sello = CreateFrame("Frame", nil, libro)
sello:SetSize(84, 84)
sello:SetPoint("CENTER", libro, "TOPLEFT", 95, -401)
sello:SetFrameLevel((type(est:GetFrameLevel()) == "number" and est:GetFrameLevel() or 1) + 3)
do
  local MASCARA = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
  local function circulo(tam, color, sub)
    local t = E.textura(sello, "ARTWORK", sub, color, 1)
    t:SetSize(tam, tam); t:SetPoint("CENTER", 0, 0)
    local ok = t.SetMask and pcall(t.SetMask, t, MASCARA)
    return t, ok
  end
  local aro, ok1 = circulo(84, C.oro2, 1)
  local borde, ok2 = circulo(82, { 0.431, 0.082, 0.071 }, 2)
  local cera, ok3 = circulo(76, E.tema().toggleOn, 3)
  sello.cera = cera
  if not (ok1 and ok2 and ok3) then
    -- Sin mascaras en el cliente: el sello dibujado de siempre
    aro:Hide(); borde:Hide(); cera:Hide()
    local s = sello:CreateTexture(nil, "ARTWORK", nil, 4)
    s:SetTexture(E.texturas.sello); s:SetAllPoints()
    sello.cera = nil
  end
end
est.sello = sello
est.palabra = sello:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
est.palabra:SetPoint("CENTER", sello, "CENTER", 0, 17)
E.letra(est.palabra, "cuerpoNegrita", 9)
est.palabra:SetTextColor(1, 0.914, 0.788)
est.num = sello:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
est.num:SetPoint("CENTER", sello, "CENTER", 0, -5)
E.letra(est.num, "marca", 30)
est.num:SetTextColor(1, 0.914, 0.788)
WowF.libroEstandarte = est

-- ----- Insignia bajo el estandarte (12-oct, Andy: "sale una sombra cuadrada... deja solo la insignia de la Horda") -----
-- Este cliente no recorta en redondo las texturas de color (SetMask): el halo y las chispas salian CUADRADOS.
-- 12-oct (Andy: "el efecto visual... le daba una vidita"): vuelven el halo que late y las chispas que suben, ahora con texturas
-- REDONDAS propias (Texturas\fulgor y Texturas\chispa, alfa radial que llega a 0 antes del borde: nunca se ve el cuadro).
do
  local adorno = CreateFrame("Frame", nil, libro)
  adorno:SetSize(ANCHO_EST + 30, 210)
  adorno:SetPoint("TOP", libro, "TOPLEFT", 95, -452)
  adorno:SetFrameLevel((type(libro:GetFrameLevel()) == "number" and libro:GetFrameLevel() or 1) + 3)
  if adorno.EnableMouse then adorno:EnableMouse(false) end
  local RAIZ_TEX = "Interface\\AddOns\\ForeverLevelingGuide\\Texturas\\"
  local function redondo(tam, sub, archivo)
    local t = adorno:CreateTexture(nil, "ARTWORK", nil, sub)
    t:SetSize(tam, tam)
    if not pcall(t.SetTexture, t, RAIZ_TEX .. archivo) then t:Hide() end
    if t.SetBlendMode then pcall(t.SetBlendMode, t, "ADD") end
    return t
  end
  local halo = redondo(170, 1, "fulgor")
  halo:SetPoint("CENTER", adorno, "CENTER", 0, 10)
  local emb = adorno:CreateTexture(nil, "ARTWORK", nil, 3)
  emb:SetSize(104, 104)
  emb:SetPoint("CENTER", adorno, "CENTER", 0, 10)
  local chispas = {}
  for i = 1, 9 do
    local c = redondo((i % 3 == 0) and 10 or 7, 4, "chispa")
    c.x = ((i * 37) % 120) - 60
    c.v = 9 + (i * 7) % 11
    c.t = (i * 0.37) % 1
    chispas[i] = c
  end
  function adorno:actualizar()
    local tm = E.tema()
    local r = tm.resplandor or { 1, 0.55, 0.18 }
    if halo.SetVertexColor then pcall(halo.SetVertexColor, halo, r[1], r[2], r[3]) end
    for _, c in ipairs(chispas) do
      if c.SetVertexColor then pcall(c.SetVertexColor, c, r[1], r[2] * 0.9 + 0.1, r[3] * 0.6 + 0.2) end
    end
    local ok = pcall(emb.SetTexture, emb, tm.emblema)
    if ok then
      if emb.SetDesaturation then pcall(emb.SetDesaturation, emb, 0.2) end
      emb:SetAlpha(0.4); emb:Show()
    else emb:Hide() end
  end
  adorno:actualizar()
  local reloj = 0
  adorno:SetScript("OnUpdate", function(self, dt)
    dt = tonumber(dt) or 0
    reloj = reloj + dt
    local pulso = 0.5 + 0.5 * math.sin(reloj * 1.3)
    halo:SetAlpha(0.25 + 0.3 * pulso)
    for _, c in ipairs(chispas) do
      c.t = (c.t + dt * c.v / 190) % 1
      c:ClearAllPoints()
      c:SetPoint("CENTER", self, "BOTTOM", c.x + 6 * math.sin(reloj * 0.8 + c.x), 10 + c.t * 190)
      c:SetAlpha(0.8 * math.sin(c.t * math.pi))
    end
  end)
  WowF.libroAdorno = adorno
end

local function actualizarEstandarte(p)
  local tm = E.tema()
  local faccion = tm.faccion
  -- Banner: sangre (#8a1616) en la Horda; el azul de la Alianza
  local col = faccion == "Alliance" and C.alianza or C.sangre
  if est.tela.SetVertexColor then est.tela:SetVertexColor(col[1], col[2], col[3], 0.78) end -- 12-oct: algo translucido
  if WowF.libroAdorno and WowF.libroAdorno.actualizar then pcall(WowF.libroAdorno.actualizar, WowF.libroAdorno) end
  if sello.cera and sello.cera.SetColorTexture then sello.cera:SetColorTexture(tm.toggleOn[1], tm.toggleOn[2], tm.toggleOn[3], 1) end
  if emblema and emblema.actualizar then pcall(emblema.actualizar, emblema) end
  subtitulo:SetText(L("Plan completo", "Full plan"))
  local clase, archivo = "", nil
  if UnitClass then local ok, a, b = pcall(UnitClass, "player"); if ok then clase, archivo = a or "", b end end
  est.retrato:ponerRespaldo(E.iconoClase[archivo or ""] or "Interface\\Icons\\INV_Misc_Book_09")
  local nombre = UnitName and UnitName("player") or ""
  if type(nombre) ~= "string" then nombre = "" end
  -- El nombre en Cinzel 18; si no cabe, se achica
  local tam = 18
  E.letra(est.nombre, "marca", tam)
  est.nombre:SetText(nombre)
  local w = est.nombre:GetStringWidth()
  while type(w) == "number" and w > ANCHO_EST - 12 and tam > 12 do
    tam = tam - 1; E.letra(est.nombre, "marca", tam); w = est.nombre:GetStringWidth()
  end
  local raza = UnitRace and UnitRace("player") or ""
  est.datos:SetText(WowF.yaTraducido((type(raza) == "string" and raza or "") .. " " .. (type(clase) == "string" and clase or "")))
  if p and p.rama and p.rama ~= "" then
    botonRama:SetText(WowF.yaTraducido(WowF.T(p.rama)))
    botonRama:Show()
  else
    WowF.textoFijo(botonRama, "Elegir rama")
    if p then botonRama:Show() else botonRama:Hide() end
  end
  local w2 = botonRama.fs and botonRama.fs.GetStringWidth and tonumber(botonRama.fs:GetStringWidth())
  if type(w2) == "number" and w2 > 0 then botonRama:SetWidth(math.min(ANCHO_EST - 8, w2 + 8)) end
  est.faccion:SetText(faccion == "Alliance" and "Alliance" or "Horde")
  if UnitFactionGroup then
    local ok, f = pcall(UnitFactionGroup, "player")
    if not ok or (f ~= "Alliance" and f ~= "Horde") then est.faccion:SetText("") end
  end
  est.palabra:SetText(L("NIVEL", "LEVEL"))
  est.num:SetText(tostring((UnitLevel and UnitLevel("player")) or 1))
end

-- ----- Fondo de ambiente (11-oct, Andy: "como GearQuest"): imagen del cliente por pestana, muy tenue, con velo y vineta -----
-- Ocupa la losa (dentro de su borde). Todo con pcall en E.ambiente: si la textura no carga, queda la piedra plana.
local ambiente
do
  local ok, a = pcall(E.ambiente, libro)
  if ok and a then
    ambiente = a
    a:ClearAllPoints()
    a:SetPoint("TOPLEFT", libro, "TOPLEFT", 15, -63)
    a:SetPoint("BOTTOMRIGHT", libro, "BOTTOMRIGHT", -15, 15)
    a:SetFrameLevel((type(libro:GetFrameLevel()) == "number" and libro:GetFrameLevel() or 1) + 1)
  end
end
WowF.libroAmbiente = ambiente

-- ----- Hoja con el contenido (a la derecha del estandarte): x 174 / y 80, 867 de ancho (padding 18 18 18 160 de la losa) -----
-- 12-oct (Andy: "la columna parece corrida, las tarjetas llegan a la barra"): el estandarte acaba en x 153 y la hoja empieza en 174
-- (21 px); la barra de desplazamiento va ahora de 1062 a 1078 y la hoja acaba en 1041: el mismo hueco de 21 px a cada lado.
local scroll = CreateFrame("ScrollFrame", "wowFLibroScroll", libro, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", libro, "TOPLEFT", 174, -80)
scroll:SetPoint("BOTTOMRIGHT", libro, "BOTTOMRIGHT", -44, 32)
scroll:SetFrameLevel((type(libro:GetFrameLevel()) == "number" and libro:GetFrameLevel() or 1) + 2)
local ANCHO_HOJA = 867
local hoja = CreateFrame("Frame", nil, scroll)
hoja:SetSize(ANCHO_HOJA, 10)
scroll:SetScrollChild(hoja)
WowF.libroHoja = hoja -- 4-oct: el diagrama de talentos (wowF_Diagrama.lua) se dibuja sobre la hoja


-- Renglones reutilizables: encabezado (oro, con raya) o elemento (icono + titulo + linea gris)
local renglones = {}
local filaTodo -- 11-oct: ya no hay "Abrir todo / Cerrar todo" (sin secciones plegables); queda en nil
local chipsDe = {} -- 9-oct: botones de las sub-pestanas de cada renglon (tabla aparte: el simulador inventa campos del marco)
local function renglon(i)
  if renglones[i] then return renglones[i] end
  local b = CreateFrame("Button", nil, hoja)
  b:SetSize(ANCHO_HOJA, 14)
  local ic = b:CreateTexture(nil, "OVERLAY")
  b.icono = ic
  local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  t:SetJustifyH("LEFT")
  if t.SetWordWrap then t:SetWordWrap(true) end
  b.texto = t
  local r = b:CreateTexture(nil, "ARTWORK")
  r:SetHeight(1)
  if r.SetColorTexture then r:SetColorTexture(1, 0.82, 0, 0.25) end
  b.raya = r
  -- Fondo de las opciones con aspecto de boton (objetivo de las profesiones)
  local fondo = b:CreateTexture(nil, "BACKGROUND")
  fondo:SetAllPoints()
  fondo:Hide()
  b.fondo = fondo
  local luz = b:CreateTexture(nil, "BACKGROUND")
  luz:SetAllPoints()
  if luz.SetColorTexture then luz:SetColorTexture(1, 1, 1, 0.06) end
  luz:Hide()
  b.luz = luz
  b:SetScript("OnEnter", function(self)
    if self.accion then self.luz:Show() end
    if not GameTooltip then return end
    if self.objeto then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.objeto) else GameTooltip:SetHyperlink("item:" .. self.objeto) end
      GameTooltip:Show()
    elseif self.ayuda then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(WowF.T(self.ayuda), 1, 1, 1, 1, true)
      if GameTooltip.SetMinimumWidth then GameTooltip:SetMinimumWidth(260) end
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(self) self.luz:Hide(); if GameTooltip then GameTooltip:Hide() end end)
  b:SetScript("OnClick", function(self) if self.accion then self.accion() end end)
  renglones[i] = b
  return b
end

-- ===================== Piezas para armar el contenido =====================
-- filas: { tipo = "cab"|"item"|"nota", texto, sub, icono, objeto, accion, ayuda, sangria, chico }
local filas
-- 9-oct (rediseno, Andy: "todo junto, mucho scroll"): cada cab abre una SECCION plegable (+/-) hasta el siguiente cab o raya.
-- opts = { cerrada = true (cerrada por defecto), clave = "..." (nombre fijo para guardar si esta abierta) }
local function cab(texto, accion, opts)
  table.insert(filas, { tipo = "cab", texto = texto, accion = accion, cerradaPorDefecto = opts and opts.cerrada, clave = opts and opts.clave })
end
-- Sub-pestanas dentro de una pestana: { { clave, etiqueta }, ... }; grupo(clave) marca a cual pertenece lo que sigue
local subActiva = {}
local function subpestanas(lista) table.insert(filas, { tipo = "chips", opciones = lista }) end
local function grupo(clave) table.insert(filas, { tipo = "grupo", clave = clave }) end
local function nota(texto, accion) table.insert(filas, { tipo = "nota", texto = texto, accion = accion }) end
local function item(t) t.tipo = "item"; table.insert(filas, t) end
-- Frase entera en los dos idiomas (la ayuda de talentos lleva su propio L)
local function L(es, en) return (WowF.enIngles and WowF.enIngles()) and en or es end
local function separador() table.insert(filas, { tipo = "raya" }) end
local verPasado = {}

-- Agrupa por nivel: lo ya pasado en una linea plegada; el nivel actual marcado "AHORA"
local function porNivel(lista, pintar, vacio)
  local nivel = nivelActual()
  local pasados, grupos, orden = 0, {}, {}
  -- Nada por delante (p. ej. nivel 60): se ensena todo, sin pedir clic
  local hayDelante = false
  for _, e in ipairs(lista) do if e[1] >= nivel then hayDelante = true end end
  if not hayDelante and #lista > 0 and verPasado[pestana] == nil then verPasado[pestana] = true end
  for _, e in ipairs(lista) do
    if e[1] < nivel then pasados = pasados + 1 end
    if e[1] >= nivel or verPasado[pestana] then
      if not grupos[e[1]] then grupos[e[1]] = {}; table.insert(orden, e[1]) end
      table.insert(grupos[e[1]], e)
    end
  end
  if pasados > 0 then
    nota(GRIS .. "Ya pasaste esos niveles: " .. pasados .. (pasados == 1 and " tarea" or " tareas") .. (verPasado[pestana] and " (clic para ocultarlas)" or " (clic para verlas)") .. "|r",
      function() verPasado[pestana] = not verPasado[pestana]; dibujar() end)
  end
  if #orden == 0 then nota(GRIS .. (vacio or "Nada mas por delante.") .. "|r") end
  local hayAhora, delante = false, 0
  local tope, avisoTope = WowFDatos and WowFDatos.topeBeta, false
  for _, n in ipairs(orden) do
    if tope and n > tope and not avisoTope then
      avisoTope = true
      local en = WowF.enIngles and WowF.enIngles()
      nota(en and (NARANJA .. "From here on, provisional:|r " .. GRIS .. "the beta goes up to level " .. tope .. ". Everything above comes from beta data but cannot be tested in game yet; it will be reviewed when the cap goes up.|r")
        or (NARANJA .. "Desde aqui, provisional:|r " .. GRIS .. "la beta llega hasta el nivel " .. tope .. ". Lo de mas arriba sale de los datos de la beta, pero aun no se puede probar en el juego; se revisara cuando suba el tope.|r"))
    end
    -- 11-oct: ya no hay secciones plegables; cada nivel es un titulo
    if n == nivel then hayAhora = true; cab(VERDE .. "Nivel " .. n .. "  ·  AHORA|r")
    elseif n < nivel then cab(GRIS .. "Nivel " .. n .. "|r")
    else
      delante = delante + 1
      cab(ORO .. "Nivel " .. n .. "|r" .. (not hayAhora and n == orden[1] and (GRIS .. "  ·  lo siguiente") or ""))
    end
    for _, e in ipairs(grupos[n]) do pintar(e, n < nivel) end
  end
end

local function eventosTipo(p, tipos)
  local lista = {}
  for _, e in ipairs(p.eventos or {}) do if tipos[e[2]] then table.insert(lista, e) end end
  return lista
end

local CONTENIDO = {}

-- Tooltip de un talento: que hace (con el rango maximo) y lo que da cada punto ("20/40/60" -> Punto 1: 20, Punto 2: 40...)
local function valorRango(desc, k)
  return (desc:gsub("[%d%.]+/[%d%./]*[%d]", function(g)
    local v = {}
    for x in g:gmatch("[^/]+") do table.insert(v, x) end
    return v[k] or v[#v]
  end))
end
-- 4-oct (idioma): en ingles TODO el tooltip en ingles, con la descripcion inglesa de Wowhead (ta[8], la genera
-- generar-plan-addon.js); en espanol, la traducida (ta[2]). Se arma ya en su idioma: WowF.T no lo vuelve a tocar.
local function ayudaTalento(p, nombre, puntos)
  local c = WowFDatos and WowFDatos.clases and WowFDatos.clases[p.clase or ""]
  local ta = c and c.talentos and c.talentos[nombre]
  if not ta then return nil end
  local ing = WowF.enIngles()
  local function L(es, en) return ing and en or es end
  local rangos, desc, rama = ta[1] or 1, ta[2] or "", ta[3] or ""
  if ing and ta[8] and ta[8] ~= "" then desc = ta[8] end
  local l = { ORO .. nombre .. "|r", GRIS .. rama .. "  ·  " .. rangos .. (rangos == 1 and L(" rango", " rank") or L(" rangos", " ranks")) .. (puntos and (L("  ·  este nivel: punto ", "  ·  this level: point ") .. puntos .. "/" .. rangos) or "") .. "|r", "" }
  table.insert(l, BLANCO .. valorRango(desc, rangos) .. "|r")
  -- 5-oct (Andy): por que lo coges, tal como lo dice la guia (sin guia que lo explique, se dice)
  local por = WowF.porqueTalento and WowF.porqueTalento(p, nombre)
  table.insert(l, "")
  if por then
    table.insert(l, CELESTE .. L("Por qué (según " .. por[3] .. "): ", "Why (per " .. por[3] .. "): ") .. "|r" .. VERDE .. (ing and por[2] or por[1]) .. "|r")
  else
    table.insert(l, GRIS .. L("La guía no explica este punto; arriba tienes lo que hace.", "The guide does not explain this point; what it does is above.") .. "|r")
  end
  local grupos = {}
  for g in desc:gmatch("[%d%.]+/[%d%./]*[%d]") do table.insert(grupos, g) end
  if rangos > 1 and #grupos > 0 then
    table.insert(l, "")
    table.insert(l, CELESTE .. L("Lo que da cada punto:", "What each point gives:") .. "|r")
    local plan = tonumber(puntos or "") or 0
    for k = 1, rangos do
      local v = {}
      for _, g in ipairs(grupos) do
        local partes = {}
        for x in g:gmatch("[^/]+") do table.insert(partes, x) end
        local donde = desc:find(g, 1, true) or 0
        local resto = desc:sub(donde + #g, donde + #g + 2)
        local sufijo = resto:find("^%%") and "%" or ((resto:find("^ s[%s%.,]") or resto == " s") and " s" or (resto:find("^ se") and " sec" or ""))
        table.insert(v, (partes[k] or partes[#partes]) .. sufijo)
      end
      table.insert(l, (k <= plan and VERDE or GRIS) .. L("Punto ", "Point ") .. k .. ": " .. table.concat(v, ", ") .. (k == plan and L("  < este nivel", "  < this level") or "") .. "|r")
    end
  end
  return WowF.yaTraducido(table.concat(l, "\n"))
end

WowF.libroAyudaTalento = ayudaTalento -- el diagrama usa el mismo tooltip

-- Motivo de la guia para un talento de tu plan: { es, en, fuente } o nil. En una rama mixta, primero la parte que juegas
-- ahora (antes del reajuste: la de subir; despues: la final) y si no esta, la otra
function WowF.porqueTalento(p, nombre)
  local c = WowFDatos and WowFDatos.clases and WowFDatos.clases[p and p.clase or ""]
  local r = c and c.ramas and c.ramas[p.indiceRama or 0]
  if not r then return nil end
  local nivel = UnitLevel and tonumber(UnitLevel("player")) or 1
  local primero, segundo = r.porque, r.porque2
  if (r.cambio or 0) > 0 and nivel >= r.cambio then primero, segundo = r.porque2, r.porque end
  return (primero and primero[nombre]) or (segundo and segundo[nombre]) or nil
end

-- ----- Talentos -----
CONTENIDO.Talentos = function(p)
  -- 5-oct: tu rama, ARRIBA. Cerrada: una linea con la rama y de donde sale + "Cambiar de rama". Abierta (clic o boton
  -- "Elegir rama"): cada opcion en su renglon; clic = el plan entero cambia a esa rama
  local ramas = WowF.listaRamas and WowF.listaRamas() or {}
  local actual
  for _, r in ipairs(ramas) do if r.actual then actual = r end end
  if actual then
    local deDonde = (actual.origen == "elegida") and L("la elegiste tu", "you chose it")
      or (actual.origen == "talentos") and L("sale de tus talentos", "taken from your talents")
      or L("aun no tienes talentos: es la recomendada", "no talents yet: this is the recommended one")
    local token = UnitClass and select(2, UnitClass("player")) or ""
    local clase = token ~= "" and (token:sub(1, 1) .. token:sub(2):lower()) or ""
    cab(WowF.yaTraducido(ORO .. L("Tu rama: ", "Your spec: ") .. "|r" .. VERDE .. clase .. " " .. actual.base .. "|r" .. GRIS .. "  ·  " .. deDonde .. "|r"))
    if actual.nombre ~= actual.base then nota(WowF.yaTraducido(GRIS .. L("Plan: ", "Plan: ") .. "|r" .. BLANCO .. WowF.T(actual.nombre) .. "|r")) end
    -- Elegiste una rama que no es la de tus puntos: se dice claro y un clic te devuelve a la tuya
    local real = WowF.ramaDeTalentos and WowF.ramaDeTalentos()
    if real and real.choca then
      nota(WowF.yaTraducido(NARANJA .. L("Tus talentos son de " .. real.base .. ", pero el plan sigue " .. WowF.T(actual.nombre) .. " porque la elegiste.",
        "Your talents are " .. real.base .. ", but the plan follows " .. WowF.T(actual.nombre) .. " because you chose it.") .. "|r"))
      item({ texto = WowF.yaTraducido(VERDE .. L("Usar mi rama real: ", "Use my real spec: ") .. real.base .. "|r"), icono = ICONO.rama, chico = true, boton = "si",
        accion = function()
          if WowF.elegirRama then WowF.elegirRama(nil) end
          WowF.libroRamasAbiertas = false
          if WowF.panelActualizar then pcall(WowF.panelActualizar) end
          dibujar()
        end })
    elseif real and actual.origen == "talentos" and #(real.tambien or {}) > 0 then
      -- Con pocos puntos varias guias empiezan igual (Priest Shadow y Discipline): se dice cual mas encaja y como elegirla
      local otras = table.concat(real.tambien, ", ")
      nota(WowF.yaTraducido(GRIS .. L("Tus talentos de ahora también encajan con: ", "Your talents so far also match: ") .. "|r" .. BLANCO .. otras .. "|r" ..
        GRIS .. L(". Las guías empiezan igual; si la tuya es otra, elígela en «Cambiar de rama».", ". The guides start the same; if yours is another one, pick it in \"Change spec\".") .. "|r"))
    end
  end
  if not WowF.libroRamasAbiertas then
    item({ texto = WowF.yaTraducido(VERDE .. L("Cambiar de rama", "Change spec") .. "|r" .. GRIS .. L("  ·  clic para ver todas las ramas de tu clase, también «subir con una y cambiar a otra»", "  ·  click to see every spec of your class, also \"level as one and switch to another\"") .. "|r"),
      icono = ICONO.rama, chico = true, boton = "si", accion = function() WowF.libroRamasAbiertas = true; dibujar() end })
  else
    local desdeLista = #filas + 1 -- 11-oct (tarjetas): la lista de ramas se ve tambien con la vista nueva (siempre = true)
    -- 5-oct (Andy): agrupado por la rama que quieres JUGAR; en cada una, "subir con otra y cambiar al nivel N" o "desde el principio"
    cab(WowF.yaTraducido(ORO .. L("Elige tu rama: ¿qué quieres jugar?", "Choose your spec: what do you want to play?") .. "|r" ..
      GRIS .. L("  ·  clic en una opción y todo el plan cambia", "  ·  click an option and the whole plan changes") .. "|r"))
    local hayElegida = actual and actual.origen == "elegida"
    local tope = (WowFDatos and WowFDatos.topeBeta) or 30
    local bases, porBase = {}, {}
    for _, r in ipairs(ramas) do
      if not porBase[r.base] then porBase[r.base] = {}; table.insert(bases, r.base) end
      table.insert(porBase[r.base], r)
    end
    for _, base in ipairs(bases) do
      local grupo = porBase[base]
      -- primero la mixta (subir con otra), luego la normal o "desde el principio"
      table.sort(grupo, function(a, b) return ((a.cambio or 0) > 0 and 0 or 1) < ((b.cambio or 0) > 0 and 0 or 1) end)
      nota(WowF.yaTraducido(CELESTE .. L("Si quieres jugar ", "If you want to play ") .. base .. ":|r"))
      for _, r in ipairs(grupo) do
        local titulo, explica
        if (r.cambio or 0) > 0 then
          titulo = L("Sube con " .. r.subir .. " y al nivel " .. r.cambio .. " cambia a " .. base, "Level as " .. r.subir .. " and switch to " .. base .. " at level " .. r.cambio)
          explica = L("Con " .. r.subir .. " matas más rápido solo. Al nivel " .. r.cambio .. " vas al entrenador de tu clase, haces respec (reiniciar talentos) y repartes como " .. base .. ".",
            "As " .. r.subir .. " you kill faster solo. At level " .. r.cambio .. " visit your class trainer, respec (reset talents) and spend them as " .. base .. ".")
          if r.cambio > tope then
            explica = explica .. L(" La beta llega al nivel " .. tope .. ": hasta entonces subes con " .. r.subir .. ".", " The beta goes up to level " .. tope .. ": until then you level as " .. r.subir .. ".")
          end
        elseif r.puro then
          titulo = L(base .. " desde el principio", base .. " from the start")
          explica = L("Juegas " .. base .. " de principio a fin, sin respec. Subes algo más lento, pero no cambias nunca.", "You play " .. base .. " from start to finish, no respec. Leveling is a bit slower, but you never switch.")
        else
          titulo = base
          explica = L("Subes y juegas con " .. base .. " todo el juego.", "You level and play as " .. base .. " the whole game.")
        end
        local marca = r.actual and (VERDE .. "> " .. "|r") or "   "
        local etiqueta = r.actual and (VERDE .. L("  [tu plan]", "  [your plan]") .. "|r") or ""
        if r.recomendada then etiqueta = etiqueta .. CELESTE .. L("  [recomendada para subir]", "  [recommended for leveling]") .. "|r" end
        item({ texto = WowF.yaTraducido(marca .. (r.actual and VERDE or BLANCO) .. titulo .. "|r" .. etiqueta),
          sub = WowF.yaTraducido(GRIS .. explica .. L("  Busca: ", "  Look for: ") .. r.stats .. "|r"), icono = ICONO.rama, sangria = 0,
          accion = function()
            if WowF.elegirRama then WowF.elegirRama(r.i) end
            WowF.libroRamasAbiertas = false
            print(WowF.yaTraducido("|cff33ccffForever Guide|r: " .. L("Rama del plan: ", "Plan spec: ") .. titulo))
            if WowF.panelActualizar then pcall(WowF.panelActualizar) end
            dibujar()
          end })
      end
    end
    if hayElegida then
      nota(WowF.yaTraducido(VERDE .. L("> Clic: volver a la rama de mis talentos", "> Click: back to the spec of my talents") .. "|r"), function()
        if WowF.elegirRama then WowF.elegirRama(nil) end
        WowF.libroRamasAbiertas = false
        if WowF.panelActualizar then pcall(WowF.panelActualizar) end
        dibujar()
      end)
    end
    nota(WowF.yaTraducido(GRIS .. L("> Clic: cerrar la lista", "> Click: close the list") .. "|r"), function() WowF.libroRamasAbiertas = false; dibujar() end)
    for i = desdeLista, #filas do filas[i].siempre = true end
  end
  -- 4-oct: primero el arbol dibujado como en Wowhead, con el numero de punto en cada casilla (wowF_Diagrama.lua)
  if WowF.contenidoDiagrama then
    WowF.contenidoDiagrama(p, cab, nota, function(marco, alto) table.insert(filas, { tipo = "bloque", marco = marco, alto = alto }) end)
  end
  -- Reiniciar talentos (empezar de cero): costo segun las veces y el entrenador mas cercano
  if WowF.costoReinicio then
    local c = WowF.costoReinicio()
    local e = WowF.entrenadorClaseCercano and WowF.entrenadorClaseCercano()
    item({ texto = ORO .. "Reiniciar talentos (empezar de cero)|r" .. GRIS .. "   proximo: |r" .. VERDE .. (c.visto and WowF.dinero(c.proximo) or WowF.yaTraducido(L("desde 1 plata", "from 1 silver"))) .. "|r" .. GRIS .. (c.visto and "  (lo dijo el entrenador)" or "") .. "|r",
      sub = GRIS .. "Lo llevas " .. c.veces .. (c.veces == 1 and " vez" or " veces") .. (e and ("  ·  entrenador mas cercano: " .. e[1] .. " (" .. e[7] .. ")") or "") .. "  ·  |r" .. VERDE .. "clic: verlo en el mapa|r",
      icono = "Interface\\Icons\\Spell_Holy_Restoration", chico = true, boton = "si",
      accion = function() WowF.irAReiniciar() end })
    nota(WowF.yaTraducido(GRIS .. L("Cuesta desde 1 plata: sube si reinicias seguido y baja un paso cada hora (nota de Blizzard del 8-oct). El precio exacto te lo dice el entrenador. Recuperas todos los puntos; los hechizos aprendidos no se pierden.",
      "It costs from 1 silver: it goes up if you reset often and drops one step every hour (Blizzard note, Oct 8). The trainer tells you the exact price. You get all your points back; learned spells are not lost.") .. "|r"))
  end
  cab(ORO .. "Talentos en orden: " .. p.rama .. "|r")
  -- 12-oct (Legacy "Talented"): puntos extra = los niveles de la lista ya vienen adelantados (wowF_Armar.lua)
  local notaLeg = WowF.notaLegacyTalentos and WowF.notaLegacyTalentos()
  if notaLeg then nota(notaLeg) end
  if (p.ramaCambio or 0) > 0 then
    nota(WowF.yaTraducido(NARANJA .. L("Al nivel " .. p.ramaCambio .. ": haces respec. Ve al entrenador de tu clase, reinicia talentos (desde 1 plata; el precio exacto te lo dice el entrenador) y reparte como dice la lista desde el " .. p.ramaCambio .. ".",
      "At level " .. p.ramaCambio .. ": respec. Visit your class trainer, reset talents (from 1 silver; the trainer tells you the exact price) and spend them as the list says from " .. p.ramaCambio .. ".") .. "|r"))
  end
  porNivel(eventosTipo(p, { talento = true, rama = true }), function(e, pasado)
    if e[2] == "rama" then
      item({ texto = (pasado and GRIS or CELESTE) .. tostring(e[3]) .. "|r", icono = ICONO.rama })
      return
    end
    local texto = tostring(e[3])
    local clave = texto:find(" · clave") ~= nil
    texto = texto:gsub(" · clave", "")
    local nombre, puntos, de = texto:match("^(.-) %((%d+)/(%d+)%)")
    local c = pasado and GRIS or BLANCO
    local por = (not pasado) and WowF.porqueTalento(p, nombre or texto)
    item({ texto = c .. (nombre or texto) .. "|r" .. (puntos and (GRIS .. "  " .. puntos .. "/" .. de .. "|r") or "") .. (clave and (NARANJA .. "  [clave]|r") or ""),
      sub = por and WowF.yaTraducido(GRIS .. L("Por qué: ", "Why: ") .. "|r" .. VERDE .. L(por[1], por[2]) .. "|r") or nil,
      icono = ((e.ic and e.ic ~= "") and ("Interface\\Icons\\" .. e.ic)) or (WowF.iconoHechizo and WowF.iconoHechizo(nombre or texto)) or ICONO.talento, ayuda = ayudaTalento(p, nombre or texto, puntos) })
  end, "Ya tienes todos los talentos del plan.")
end

-- ----- Profesiones -----
local function habilidad(nombre)
  local id = WowF.idProfesion and WowF.idProfesion(nombre)
  if id and WowF.rangoProfesion then return WowF.rangoProfesion(id) end
  if not GetNumSkillLines or not GetSkillLineInfo then return nil end
  local buscado = nombre:lower()
  for i = 1, GetNumSkillLines() do
    local n, esCab, _, rango, _, _, maximo = GetSkillLineInfo(i)
    if n and not esCab and n:lower() == buscado then return rango, maximo end
  end
  return nil
end
-- Vale la pena fabricarla? Mira cuantos niveles te dura (hasta que sale algo un 15 % mejor de cualquier fuente)
-- y lo que llevas puesto en esa ranura (por nivel de objeto). Devuelve: veredicto ("si"|"opcional"|"ya"), texto
local SLOT = { [1] = 1, [2] = 2, [3] = 3, [16] = 15, [5] = 5, [20] = 5, [9] = 9, [10] = 10, [6] = 6, [7] = 7, [8] = 8, [11] = 11, [12] = 13,
  [13] = 16, [17] = 16, [21] = 16, [14] = 17, [22] = 17, [23] = 17, [15] = 18, [25] = 18, [26] = 18, [28] = 18 }
local function nivelObjeto(x)
  if not GetItemInfo or not x then return nil end
  local _, _, _, il = GetItemInfo(x)
  return il
end
function WowF.valeLaPena(e)
  if e.hasta == 0 then return "opcional", "no es el tipo de pieza que usa tu rama" end
  -- 7-oct: la beta llega al topeBeta; lo que pide mas nivel no se puede llevar todavia, y hasta = 60 = nada mejor hasta el tope
  local tope = (WowFDatos and WowFDatos.topeBeta) or 30
  if e[1] > tope then return "opcional", L("pide nivel " .. e[1] .. ": la beta llega al " .. tope, "requires level " .. e[1] .. ": the beta goes up to " .. tope) end
  local dura = math.max(1, (e.hasta or 60) - e[1])
  local slot = e.ra and SLOT[e.ra]
  local enlace = slot and GetInventoryItemLink and GetInventoryItemLink("player", slot)
  if e.i and IsEquippedItem and IsEquippedItem(e.i) then return "ya", "ya la llevas puesta" end
  if enlace then
    local mio, suyo = nivelObjeto(enlace), nivelObjeto(e.i)
    if mio and suyo and mio >= suyo then return "ya", "lo que llevas (" .. (enlace:match("%[(.-)%]") or "?") .. ") es igual o mejor" end
  end
  if (e.hasta or 60) >= 60 and tope < 60 then
    return "si", L("nada mejor hasta el tope de la beta (" .. tope .. ")", "nothing better up to the beta level cap (" .. tope .. ")")
  end
  local hasta = (e.hasta or 60) >= 60 and "hasta el 60" or ("hasta el nivel " .. e.hasta)
  if dura >= 5 then return "si", "te dura " .. dura .. " niveles (" .. hasta .. ")" end
  if dura <= 2 then return "opcional", "solo te dura " .. dura .. (dura == 1 and " nivel" or " niveles") .. ": al " .. e.hasta .. " ya hay algo mejor" end
  return "normal", "te dura " .. dura .. " niveles (" .. hasta .. ")"
end
local VEREDICTO = { si = VERDE .. "VALE LA PENA|r", opcional = GRIS .. "opcional|r", ya = GRIS .. "no hace falta|r", normal = ORO .. "util|r" }

local function fabricadas(lista, titulo)
  for _, e in ipairs(lista) do
    local t = trozos(e[3])
    local nombre, ranura = (t[1] or ""):match("^(.-) %((.-)%)$")
    local prof = (t[2] or ""):gsub(" %d+ %(estimado%)", " " .. L("(nivel aun no disponible en WoW Forever; se actualizara)", "(level not yet available in WoW Forever; will be updated)")) -- 9-oct: nivel de receta estimado (Classic) = aviso
    local ya = e.i and tengo(e.i) > 0
    local mats = {}
    for _, m in ipairs(e.m or {}) do
      local tn = tengo(m[1])
      table.insert(mats, m[2] .. " " .. (m[3] or "?") .. (tn >= m[2] and (VERDE .. " (ok)|r" .. GRIS) or (tn > 0 and (" (tienes " .. tn .. ")") or "")))
    end
    local v, porque = WowF.valeLaPena(e)
    local apagada = (v == "opcional" or v == "ya")
    item({ texto = GRIS .. "Nv " .. e[1] .. "  |r" .. VEREDICTO[v] .. "  " .. (ya and (VERDE .. "[en tus bolsas] |r") or "") .. (apagada and GRIS or colorCalidad(e.q or 1)) .. (nombre or t[1] or "?") .. "|r" .. GRIS .. "  " .. (ranura or "") .. "|r",
      sub = (v == "si" and VERDE or GRIS) .. porque .. "|r\n" .. GRIS .. prof .. (#mats > 0 and ("  ·  " .. table.concat(mats, ", ")) or "") .. "|r", icono = icono(e.ic, e.i), objeto = e.i })
  end
end
-- Entrenador para un tramo: de tu faccion, que ensene recetas de ese tramo; primero el del mapa donde estas (el mas cercano),
-- luego el de la capital de tu raza, luego otra capital
local CAPITAL_RAZA = { Human = 1453, Dwarf = 1455, Gnome = 1455, NightElf = 1457, Orc = 1454, Troll = 1454, Tauren = 1456, Scourge = 1458, Undead = 1458 }
local CAPITALES = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }
local RANGO = { [75] = "Apprentice", [150] = "Journeyman", [225] = "Expert", [300] = "Artisan" }
-- 9-oct: la habilidad exigida para aprender un rango sale de los datos de Forever (WowFDatos.pideRango[profId][rango],
-- Wowhead /forever); sin dato no se muestra nada. El nivel del personaje que pide cada rango no tiene fuente de Forever: no se muestra.
local function pideRango(id, tope)
  local t = WowFDatos and WowFDatos.pideRango and WowFDatos.pideRango[id]
  return t and tonumber(t[tope])
end
local function entrenadorPara(id, cap)
  local lista = WowFDatos.entrenadores and WowFDatos.entrenadores[id]
  if not lista then return nil end
  local fac = (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A"
  local aqui = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local _, raza = UnitRace and UnitRace("player")
  local casa = CAPITAL_RAZA[raza or ""]
  local px, py
  if aqui and C_Map.GetPlayerMapPosition then
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, aqui, "player")
    if ok and pos then px, py = (pos.x or 0) * 100, (pos.y or 0) * 100 end
  end
  -- 9-oct: los de posicion aproximada (Classic) no se eligen; si no hay otro, se devuelve aparte (2.o valor) para decir
  -- "Posicion de X aun no disponible en WoW Forever; se actualizara"
  local mejor, mp, sinPos, sp
  for _, e in ipairs(lista) do
    if (e[5] == fac or e[5] == "N") and (cap <= 75 or e[6] > cap - 75) then
      local pr = 4
      if e[2] == aqui then pr = 0 + (px and (math.sqrt((e[3] - px) ^ 2 + (e[4] - py) ^ 2) / 1000) or 0)
      elseif e[2] == casa then pr = 1
      elseif CAPITALES[e[2]] then pr = 2 end
      if WowF.esAproximado and WowF.esAproximado(e) then
        if not sp or pr < sp then sinPos, sp = e, pr end
      elseif not mp or pr < mp then mejor, mp = e, pr end
    end
  end
  return mejor, (not mejor) and sinPos or nil
end
local function marcarEntrenador(e, prof)
  if WowF.esAproximado and WowF.esAproximado(e) and WowF.marcarEntrenador then WowF.marcarEntrenador(e, prof); return end -- 9-oct: sin alfiler de Classic
  if e and WowF.marcar then WowF.marcar({ m = e[2], x = e[3], y = e[4], n = e[1] .. " (entrenador de " .. prof .. ")", z = e[7], lugar = true, aprox = WowF.esAproximado and WowF.esAproximado(e) }) end
end
-- 5-oct: linea gris si la posicion del entrenador es aproximada (sin confirmar en Forever)
local function notaAprox(e) return (WowF.esAproximado and WowF.esAproximado(e)) and ("\n" .. GRIS .. WowF.textoAprox() .. "|r") or "" end
local profTope -- tramo que se abre al venir de "ya puedes subirlas hasta N"
local function materiales(lista)
  local partes, todo = {}, true
  for _, m in ipairs(lista or {}) do
    local n = obj(m[1])
    local tn = tengo(m[1])
    if tn < m[2] then todo = false end
    table.insert(partes, (tn >= m[2] and VERDE or BLANCO) .. m[2] .. " " .. n .. "|r" .. GRIS .. (tn >= m[2] and " (ok)" or (tn > 0 and (" (tienes " .. tn .. ")") or "")) .. "|r")
  end
  return table.concat(partes, GRIS .. ", |r"), todo
end
-- Lista de nombres de profesiones: "Leatherworking + Skinning"
local function nombresProf(ids)
  local n = {}
  for _, id in ipairs(ids or {}) do table.insert(n, WowFDatos.prof[id] or tostring(id)) end
  return table.concat(n, " + ")
end
local function objetivoProfesiones(p)
  if not WowF.ORDEN_OBJETIVOS then return true end
  local elegido = not WowF.objetivoElegido or WowF.objetivoElegido()
  local AYUDA = { fabricar = "las que te hacen tu propia armadura y armas mientras subes", oro = "las que mas se venden en la casa de subastas", pvp = "las que dan ventaja contra otros jugadores" }
  local ICONO_OBJ = { fabricar = "Interface\\Icons\\Trade_BlackSmithing", oro = "Interface\\Icons\\INV_Misc_Coin_02", pvp = "Interface\\Icons\\INV_Sword_27" }
  separador()
  -- 9-oct: ya elegido, el paso 1 queda plegado en una linea con lo que elegiste (clic = cambiarlo)
  if elegido and WowF.OBJETIVOS[p.objetivo] then
    cab(WowF.yaTraducido(ORO .. L("Paso 1 · tu objetivo: ", "Step 1 · your goal: ") .. "|r" .. VERDE .. WowF.T(WowF.OBJETIVOS[p.objetivo]) .. "|r"
      .. GRIS .. L("  ·  clic para cambiarlo", "  ·  click to change it") .. "|r"), nil, { cerrada = true, clave = "paso1" })
  else
    cab(ORO .. "Paso 1: elige que quieres con tus profesiones|r" .. (elegido and "" or (NARANJA .. "  (obligatorio)|r")), nil, { clave = "paso1sin" })
  end
  for _, k in ipairs(WowF.ORDEN_OBJETIVOS) do
    local activo = elegido and (p.objetivo == k)
    item({ texto = (activo and (VERDE .. "[X]  " .. WowF.OBJETIVOS[k] .. "|r" .. GRIS .. "   elegido|r") or (BLANCO .. "[  ]  " .. WowF.OBJETIVOS[k] .. "|r" .. GRIS .. "   clic para elegir|r")),
      sub = GRIS .. (AYUDA[k] or "") .. "|r", icono = ICONO_OBJ[k], chico = true, boton = activo and "elegido" or "si",
      accion = function() WowF.elegirObjetivo(k); dibujar() end })
  end
  separador()
  if not elegido then
    nota(NARANJA .. "Elige una de las tres opciones de arriba. Despues aqui abajo te sale todo: que profesiones aprender, donde estan los entrenadores y el paso a paso.|r")
    return false
  end
  return true
end
-- 9-oct: lo que te conviene segun el objetivo (ya dentro de la sub-pestana "Mis profesiones")
local function recomendacionProf(p)
  local info = p.objetivoInfo or {}
  local claseN = (UnitClass and UnitClass("player")) or "tu clase"
  local mejor = nombresProf(p.recomendadas)
  if mejor ~= "" then
    item({ texto = ORO .. "Para ti (" .. claseN .. ") lo mejor: |r" .. VERDE .. mejor .. "|r", icono = ICONO[(p.recomendadas or {})[1]] or ICONO.prof })
  end
  if (info.t or "") ~= "" then nota(BLANCO .. info.t .. "|r") end
  if (info.por or "") ~= "" then nota(GRIS .. "Por que: " .. info.por .. "|r") end
  -- Lo que tienes contra lo que te conviene
  local tengo = p.tengo or {}
  if #tengo > 0 then
    local iguales = true
    for _, id in ipairs(p.recomendadas or {}) do
      local esta = false
      for _, x in ipairs(tengo) do if x == id then esta = true end end
      if not esta then iguales = false end
    end
    if iguales then nota(VERDE .. "Ya tienes las dos correctas para esto.|r")
    else nota(NARANJA .. "Tu tienes " .. nombresProf(tengo) .. ". Para esto te conviene " .. mejor .. ".|r" .. GRIS .. " Abajo sigue el paso a paso de las que tienes.|r") end
  end
  if info.otras and #info.otras > 0 then
    cab(WowF.yaTraducido(CELESTE .. L("Otras opciones", "Other options") .. "|r"), nil, { cerrada = true, clave = "otras" })
    for _, o in ipairs(info.otras) do
      item({ texto = CELESTE .. o[1] .. "|r" .. ((o[2] or "") ~= "" and (GRIS .. "  (" .. o[2] .. ")|r") or ""), sub = GRIS .. o[3] .. "|r", sangria = 12, chico = true })
    end
  end
end
CONTENIDO.Profesiones = function(p)
  local D = WowFDatos
  if not objetivoProfesiones(p) then return end
  -- 9-oct (rediseno): 4 sub-pestanas en vez de una lista larguisima. Lo de cada una no cambia.
  local ETQ = { oro = L("Para vender", "To sell"), fabricar = L("Fabricarte equipo", "Craft your gear"), pvp = L("Para PvP", "For PvP") }
  subpestanas({ { "mias", L("Mis profesiones", "My professions") }, { "objetivo", ETQ[p.objetivo] or L("Qué hacer", "What to do") },
    { "secundarias", L("Secundarias", "Secondary") }, { "cajas", L("Cajas y favor", "Crates & Favor") }, { "campamento", L("Campamento", "Camping") }, { "reputacion", L("Reputación", "Reputation") }, { "legacy", L("Legacy", "Legacy") }, { "mas", L("Entrenadores", "Trainers") } })
  -- Entrenadores de la zona donde estas, con alfiler al hacer clic (sub-pestana "Mas")
  local function entrenadoresAqui()
  if WowF.entrenadoresEn then
    local m, zona = WowF.mapaActual()
    local aqui = WowF.entrenadoresEn(m)
    cab(ORO .. "Entrenadores donde estas|r" .. GRIS .. (zona ~= "" and ("  (" .. zona .. ")") or "") .. "|r")
    if #aqui == 0 then
      nota(GRIS .. "Aqui no hay entrenadores de profesiones. El paso 1 de cada profesion (abajo) te marca el mas cercano. En el mapa (M) de cada ciudad o pueblo salen todos con su icono.|r")
    else
      for _, t in ipairs(aqui) do
        item({ texto = ORO .. t.nombre .. "|r" .. BLANCO .. ": " .. t.e[1] .. "|r", sub = GRIS .. t.e[3] .. ", " .. t.e[4] .. "  ·  ensena hasta " .. WowF.rangoEntrenador(t.e[6]) .. "  ·  |r" .. VERDE .. "clic: verlo en el mapa|r" .. notaAprox(t.e),
          icono = ICONO[t.prof] or (WowF.ICONO_PROF and WowF.ICONO_PROF[t.prof]) or ICONO.prof, sangria = 8, chico = true,
          accion = function() (WowF.verEntrenador or WowF.marcarEntrenador)(t.e, t.nombre) end })
      end
      nota(GRIS .. "En el mapa (M) cada entrenador es un punto con el icono de su profesion debajo; los tuyos en verde y el que elegiste en dorado.|r")
    end
  end
  end
  -- Una profesion: cabecera y tramos con el paso a paso (6-oct: tambien las secundarias First Aid y Cooking)
  local function unaProfesion(id, secundaria)
    local nombre = D.prof[id] or tostring(id)
    local rango, maximo = habilidad(nombre)
    local falta = false
    if secundaria then falta = not rango end
    for _, f in ipairs(p.faltan or {}) do if f == id then falta = true end end
    cab(ORO .. nombre .. "|r  " .. (rango and (VERDE .. rango .. (maximo and ("/" .. maximo) or "") .. "|r") or (falta and (NARANJA .. "aun no la tienes: el paso 1 te marca el entrenador|r") or "")), nil, { clave = "prof" .. id })
    if D.recoleccion[id] and id ~= 393 then
      nota(falta and (NARANJA .. "> Sugerencia (aun NO la tienes): clic para ver la ruta de farmeo de " .. nombre .. "|r") or (VERDE .. "> Clic: ruta de farmeo de " .. nombre .. " en el mapa|r"), function() if SlashCmdList.WOWF then SlashCmdList.WOWF("farmeo " .. nombre) end end)
    end
    local ultimo = D.caps[#D.caps] and D.caps[#D.caps][2]
    if rango and ultimo and rango >= ultimo then
      nota(VERDE .. "Profesion al maximo: no quedan pasos. Clic en un tramo si quieres repasarlo.|r")
    end
    local antes = 0
    local r0 = rango or 0
    -- 9-oct (cero datos de Classic): el nivel de personaje de D.caps es de Classic y NO se muestra.
    -- El requisito real de Forever es la habilidad (pideRango: "Expert pide Leatherworking 125"); sin dato, no se inventa.
    for _, cap in ipairs(D.caps) do
      local tope = cap[2]
      local hecho = rango and rango >= tope
      local ahora = not hecho and r0 >= antes and r0 < tope
      local abierto = ahora or profTope == tope
      local exigeT = pideRango(id, tope)
      local estado = hecho and (GRIS .. "  hecho|r") or ""
      local titulo = (ahora and (VERDE .. "AHORA  |r") or "") .. (hecho and GRIS or ORO) .. "De " .. antes .. " a " .. tope .. "|r" .. GRIS .. "  (" .. (RANGO[tope] or "")
        .. (exigeT and L(", pide " .. nombre .. " " .. exigeT, ", requires " .. nombre .. " " .. exigeT) or "") .. ")|r" .. estado
      if not abierto then
        local antesDe = antes
        item({ texto = titulo, sub = GRIS .. "clic: ver el paso a paso de este tramo|r", sangria = 4, chico = true,
          accion = function() profTope = tope; dibujar() end })
      else
        item({ texto = titulo, sub = GRIS .. "Sigue los pasos en orden. Pasa el raton por un objeto para verlo.|r", sangria = 4 })
        local n = 0
        -- 1. Aprender el rango con el entrenador (con alfiler en el mapa)
        local e, eSinPos = entrenadorPara(id, tope)
        local yaRango = maximo and maximo >= tope
        local exige = pideRango(id, tope)
        local pide = exige and (GRIS .. L("  ·  pide " .. nombre .. " " .. exige, "  ·  requires " .. nombre .. " " .. exige) .. "|r") or ""
        n = n + 1
        if yaRango then
          item({ texto = BLANCO .. n .. ".|r " .. GRIS .. "Aprende " .. (RANGO[tope] or "el rango") .. ": ya lo tienes|r", icono = ICONO[id] or (WowF.ICONO_PROF and WowF.ICONO_PROF[id]) or ICONO.prof, sangria = 12, chico = true,
            accion = e and function() marcarEntrenador(e, nombre) end or nil })
        elseif e then
          item({ texto = BLANCO .. n .. ".|r " .. BLANCO .. "Aprende |r" .. ORO .. (RANGO[tope] or "el rango") .. "|r" .. BLANCO .. " con |r" .. CELESTE .. e[1] .. "|r" .. pide,
            sub = GRIS .. e[7] .. " " .. e[3] .. ", " .. e[4] .. "  ·  |r" .. VERDE .. "clic: alfiler en el mapa|r" .. notaAprox(e), icono = ICONO[id] or (WowF.ICONO_PROF and WowF.ICONO_PROF[id]) or ICONO.prof, sangria = 12, chico = true,
            accion = function() marcarEntrenador(e, nombre) end })
        elseif eSinPos then
          item({ texto = BLANCO .. n .. ".|r " .. BLANCO .. L("Aprende ", "Learn ") .. "|r" .. ORO .. (RANGO[tope] or L("el rango", "the rank")) .. "|r" .. BLANCO .. L(" con ", " with ") .. "|r" .. CELESTE .. eSinPos[1] .. "|r" .. pide,
            sub = NARANJA .. WowF.textoSinPosicion(eSinPos[1]) .. "|r", icono = ICONO[id] or (WowF.ICONO_PROF and WowF.ICONO_PROF[id]) or ICONO.prof, sangria = 12, chico = true })
        else
          item({ texto = WowF.yaTraducido(BLANCO .. n .. ".|r " .. NARANJA .. L("Aprende " .. (RANGO[tope] or "el rango") .. " de " .. nombre .. ": ningun entrenador de Forever enseña este rango segun los datos que tenemos; aun no sabemos como se aprende. Se actualizara en proximas actualizaciones.",
            "Learn " .. (RANGO[tope] or "the rank") .. " of " .. nombre .. ": no Forever trainer teaches this rank in the data we have; we don't know yet how it is learned. This will be updated in future updates.") .. "|r"), icono = ICONO[id] or (WowF.ICONO_PROF and WowF.ICONO_PROF[id]) or ICONO.prof, sangria = 12, chico = true })
        end
        if D.recoleccion[id] then
          -- Recoleccion: los tramos de farmeo de este tope, con la ruta en el mapa
          local fz = WowFFarmeo and WowFFarmeo[id]
          local alguno = false
          for _, tr in ipairs((fz and fz.tramos) or {}) do
            if tr.b > antes and tr.a < tope then
              alguno = true
              n = n + 1
              local dentro = r0 >= tr.a and r0 < tr.b
              local z = tr.zonas and tr.zonas[1]
              item({ texto = BLANCO .. n .. ".|r " .. (dentro and (VERDE .. "AHORA  |r") or "") .. "De " .. math.max(tr.a, antes) .. " a " .. math.min(tr.b, tope) .. ": recoge " .. CELESTE .. (tr.nodos or "") .. "|r",
                sub = GRIS .. (z and ("Mejor zona: " .. z.n .. "  ·  ") or "") .. "|r" .. VERDE .. "clic: ruta en el mapa (flecha al punto mas cercano)|r", icono = ICONO[id] or (WowF.ICONO_PROF and WowF.ICONO_PROF[id]) or ICONO.prof, sangria = 12, chico = true,
                accion = function() if SlashCmdList.WOWF then SlashCmdList.WOWF("farmeo " .. nombre) end end })
            end
          end
          if not alguno then n = n + 1; item({ texto = BLANCO .. n .. ".|r " .. trozos(D.tramos[id] and D.tramos[id][tope] or "")[1], sangria = 12, chico = true }) end
        else
          for _, ps in ipairs((D.pasos and D.pasos[id]) or {}) do
            if ps[1] < tope and ps[2] > antes then
              n = n + 1
              -- 13-oct: tramo cortado en el tope (sin "68 a 76" repetido), cuenta con tu rango y margen, clic = te lleva a lo que falta
              local a, z = math.max(ps[1], antes), math.min(ps[2], tope)
              local listo = r0 >= z
              local dentro = r0 >= a and r0 < z
              local nombreR = ps[7] or "?"
              local on, oq, oic = obj(ps[3])
              local veces, seguras, matsL, ahorro = WowF.cuentaPaso(ps, a, z, listo and a or r0)
              local mats, todo = materiales(matsL)
              local aprende = tostring(ps[5] or "")
              local c = listo and GRIS or BLANCO
              local linea, expl = WowF.textoPaso(ps, a, z, r0, veces, seguras)
              local paso = { tipo = "receta", desde = a, hasta = z, ps = ps, prof = id, veces = veces, seguras = seguras, ahorro = ahorro, mats = matsL, aprende = aprende, e = e,
                b = linea, nota = expl }
              -- 13-oct: la misma frase y explicacion que la tarjeta (WowF.textoPaso); el material es para la cantidad con mala suerte
              item({ texto = BLANCO .. n .. ".|r " .. (dentro and (VERDE .. "AHORA  |r") or "") .. (listo and GRIS or ORO) .. linea .. "|r" .. GRIS .. L("  (de " .. a .. " a " .. z .. ")", "  (" .. a .. " to " .. z .. ")") .. (ahorro > 0 and L("  Legacy: " .. ahorro .. " menos", "  Legacy: " .. ahorro .. " fewer") or "") .. "|r",
                sub = (expl and (GRIS .. expl .. "|r\n") or "") .. GRIS .. L("Material para " .. seguras .. ": |r", "Materials for " .. seguras .. ": |r") .. mats .. (todo and (VERDE .. L("  ya lo tienes todo|r", "  you have it all|r")) or "") .. "\n" .. GRIS .. L("Receta: ", "Recipe: ") .. (select(1, WowF.origenReceta(ps)) or "") .. "|r\n" .. VERDE .. L("clic: te llevo a lo primero que te falta", "click: I take you to the first thing you're missing") .. "|r",
                icono = (ps[3] ~= 0) and icono(oic, ps[3]) or ICONO.prof, objeto = (ps[3] ~= 0) and ps[3] or nil, sangria = 12, chico = true,
                accion = function() WowF.irPasoReceta(paso, nombre) end })
            end
          end
        end
      end
      antes = tope
    end
  end
  grupo("mias")
  recomendacionProf(p)
  for _, id in ipairs(p.ids or {}) do unaProfesion(id) end
  grupo("objetivo")
  -- Lo de abajo cambia segun el objetivo (vender / PvP / fabricarte), con "Ya puedes" y "Proximas al subir" (wowF_ProfObjetivo.lua)
  local h = { item = item, cab = cab, nota = nota, fabricadas = fabricadas, obj = obj, icono = icono, tengo = tengo,
    colorCalidad = colorCalidad, nivelActual = nivelActual, separador = separador, entrenadorPara = entrenadorPara, marcarEntrenador = marcarEntrenador }
  if WowF.seccionObjetivoProf then
    WowF.seccionObjetivoProf(p, h)
  elseif p.sugerida then
    cab(CELESTE .. "Para fabricarte equipo: " .. p.sugerida.nombre .. "|r", nil)
    nota(GRIS .. "Hoy tienes dos de recoleccion: ganas oro vendiendo lo que sacas. Si cambias una por " .. p.sugerida.nombre .. " (la recomendada para tu clase), te fabricas esto:|r")
    local proximas = {}
    for _, e in ipairs(p.sugerida.piezas) do if e[1] >= nivelActual() - 3 and #proximas < 8 then table.insert(proximas, e) end end
    fabricadas(proximas)
  end
  -- 6-oct (Andy: "solo salen las principales; First Aid no existe"): las secundarias con su paso a paso, "Ya puedes" / "Proximas al subir" y Fishing
  grupo("secundarias")
  cab(ORO .. L("Profesiones secundarias", "Secondary professions") .. "|r")
  nota(GRIS .. L("First Aid, Cooking y Fishing no ocupan hueco: puedes tener las tres ademas de tus dos principales. Topes: 75, 150, 225 y 300; el nivel de personaje que pide cada uno aun no esta disponible en Forever; se actualizara.", "First Aid, Cooking and Fishing do not use a slot: you can have all three plus your two main ones. Caps: 75, 150, 225 and 300; the character level each one requires is not available yet in Forever; will be updated.") .. "|r")
  for _, id in ipairs({ 129, 185 }) do
    unaProfesion(id, true)
    if WowF.seccionSecundaria then WowF.seccionSecundaria(id, h) end
  end
  if WowF.seccionPesca then WowF.seccionPesca(h) end
  grupo("cajas") -- 12-oct: sub-pestana propia
  if WowF.seccionFavor then WowF.seccionFavor(p, h) end -- 7-oct: Merchant's Favor (wowF_Favor.lua)
  grupo("campamento") -- 16-oct: guia de campamento (wowF_GuiaCampamento.lua) + la lista de objetos (wowF_Campamento.lua)
  if WowF.seccionGuiaCampamento then WowF.seccionGuiaCampamento(p, h) end
  if WowF.seccionCampamento then separador(); WowF.seccionCampamento(p, h) end -- 8-oct: objetos de campamento (wowF_Campamento.lua)
  grupo("reputacion") -- 16-oct: guia de reputacion (wowF_Reputacion.lua)
  if WowF.seccionReputacion then WowF.seccionReputacion(p, h) end
  grupo("legacy") -- 12-oct: sub-pestana propia (Andy: "un espacio solo para Legacy")
  if WowF.seccionLegacy then WowF.seccionLegacy(p, h) end -- perks Legacy y certificaciones (wowF_Legacy.lua)
  grupo("mas")
  entrenadoresAqui()
end

-- ----- Equipo: la figura de tu personaje con una casilla por ranura, como la ventana del juego -----
local function tramoDe(m, faccion, nivel)
  local lista = (faccion == "Horda" and m.Horda) or m.Alianza or {}
  local elegido
  for _, t in ipairs(lista) do if t[1] <= nivel then elegido = t end end
  return elegido
end
local CASILLAS = {
  { 1, "HeadSlot", "Head", "izq", 1 }, { 2, "NeckSlot", "Neck", "izq", 2 }, { 3, "ShoulderSlot", "Shoulder", "izq", 3 },
  { 15, "BackSlot", "Back", "izq", 4 }, { 5, "ChestSlot", "Chest", "izq", 5 }, { 9, "WristSlot", "Wrist", "izq", 6 },
  { 10, "HandsSlot", "Hands", "der", 1 }, { 6, "WaistSlot", "Waist", "der", 2 }, { 7, "LegsSlot", "Legs", "der", 3 },
  { 8, "FeetSlot", "Feet", "der", 4 }, { 11, "Finger0Slot", "Finger", "der", 5 }, { 12, "Finger1Slot", "Finger", "der", 6 },
  { 13, "Trinket0Slot", "Trinket", "der", 7 }, { 14, "Trinket1Slot", "Trinket", "der", 8 },
  { 16, "MainHandSlot", "Main Hand", "abajo", 1 }, { 17, "SecondaryHandSlot", "Off Hand", "abajo", 2 }, { 18, "RangedSlot", "Ranged", "abajo", 3 },
}
local CAS, PASO, LADO = 34, 40, 150
local ALTO_FIGURA = 8 * PASO + PASO + 10
local figura = CreateFrame("Frame", nil, hoja)
figura:SetPoint("TOPLEFT", 0, 0)
figura:SetSize(ANCHO_HOJA, ALTO_FIGURA)
figura:Hide()
local fondoFigura = figura:CreateTexture(nil, "BACKGROUND")
fondoFigura:SetPoint("TOPLEFT", LADO, 0)
fondoFigura:SetPoint("BOTTOMRIGHT", -LADO, PASO + 10)
if fondoFigura.SetColorTexture then fondoFigura:SetColorTexture(0.12, 0.09, 0.05, 0.7) end
local modelo
do
  local ok, m = pcall(CreateFrame, "PlayerModel", nil, figura)
  if ok and m then
    modelo = m
    modelo:SetPoint("TOPLEFT", LADO, 0)
    modelo:SetPoint("BOTTOMRIGHT", -LADO, PASO + 10)
    -- Arrastrar con el raton gira la figura
    if modelo.EnableMouse then modelo:EnableMouse(true) end
    local girando
    modelo:SetScript("OnMouseDown", function() girando = GetCursorPosition and GetCursorPosition() end)
    modelo:SetScript("OnMouseUp", function() girando = nil end)
    modelo:SetScript("OnUpdate", function(self)
      if type(girando) ~= "number" or not GetCursorPosition then return end
      local x = GetCursorPosition()
      if type(x) == "number" and self.SetFacing and self.GetFacing then self:SetFacing((tonumber(self:GetFacing()) or 0) + (x - girando) / 80) end
      girando = x
    end)
  end
end
local ayudaFigura = figura:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
ayudaFigura:SetPoint("BOTTOM", figura, "BOTTOM", 0, PASO + 14)
WowF.textoFijo(ayudaFigura, "arrastra para girar")
local casillas = {}
local guiaDe = {} -- 5-oct: la mejora de cada casilla (wowF_EquipoGuia.lua)
local function recortar(s, n) s = WowF.T(tostring(s or "")); if #s > n then return s:sub(1, n - 2) .. ".." end return s end
for i, d in ipairs(CASILLAS) do
  local b = CreateFrame("Button", nil, figura)
  b:SetSize(CAS, CAS)
  b.marco = b:CreateTexture(nil, "BACKGROUND")
  b.marco:SetPoint("TOPLEFT", -2, 2)
  b.marco:SetPoint("BOTTOMRIGHT", 2, -2)
  b.icono = b:CreateTexture(nil, "ARTWORK")
  b.icono:SetAllPoints()
  b.texto = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.texto:SetWidth(LADO - CAS - 10)
  if b.texto.SetWordWrap then b.texto:SetWordWrap(false) end
  if d[4] == "izq" then
    b:SetPoint("TOPLEFT", figura, "TOPLEFT", 0, -(d[5] - 1) * PASO)
    b.texto:SetPoint("LEFT", b, "RIGHT", 6, 0); b.texto:SetJustifyH("LEFT")
  elseif d[4] == "der" then
    b:SetPoint("TOPRIGHT", figura, "TOPRIGHT", 0, -(d[5] - 1) * PASO)
    b.texto:SetPoint("RIGHT", b, "LEFT", -6, 0); b.texto:SetJustifyH("RIGHT")
  else
    b:SetPoint("BOTTOMLEFT", figura, "BOTTOMLEFT", 10 + (d[5] - 1) * 170, 2)
    b.texto:SetPoint("LEFT", b, "RIGHT", 6, 0); b.texto:SetJustifyH("LEFT")
  end
  b.def = d
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local puesto = GetInventoryItemLink and GetInventoryItemLink("player", self.def[1])
    if puesto and GameTooltip.SetInventoryItem then GameTooltip:SetInventoryItem("player", self.def[1])
    else GameTooltip:SetText(WowF.T(self.def[3] .. ": vacio"), 0.7, 0.7, 0.7) end
    -- 5-oct: la siguiente mejora real (pesos de tu rama) y de donde sale (wowF_EquipoGuia.lua)
    GameTooltip:AddLine(" ")
    local guia = guiaDe[self]
    if guia then
      local primera = true
      for linea in (WowF.equipoAyuda(guia, nivelActual()) .. "\n"):gmatch("(.-)\n") do
        if linea ~= "" then GameTooltip:AddLine(WowF.yaTraducido(linea), 1, 1, 1, true) end
        -- 7-oct: el porque corto (lo que ganas y lo que pierdes) justo debajo de "Siguiente mejora": dorado si es mejora pequena, verde si no
        if primera and linea ~= "" then
          primera = false
          if type(guia.porqueCorto) == "string" and guia.porqueCorto ~= "" then
            if guia.dudosa then GameTooltip:AddLine(WowF.yaTraducido(guia.porqueCorto), 1, 0.82, 0, true)
            else GameTooltip:AddLine(WowF.yaTraducido(guia.porqueCorto), 0.2, 1, 0.4, true) end
          end
        end
      end
    else
      GameTooltip:AddLine(WowF.yaTraducido(L("No hay nada verificado mejor que lo que llevas, a tu nivel.", "Nothing verified is better than what you wear, at your level.")), 0.6, 0.6, 0.6, true)
    end
    -- 7-oct: la BiS de nivel 30 de este hueco (wowF_BiSGuia.lua), si la hay para tu rama y tu faccion
    for _, bx in ipairs(type(self._bis) == "table" and self._bis or {}) do
      GameTooltip:AddLine(bx.texto, 1, 1, 1, true)
      if bx.arma then GameTooltip:AddLine(bx.arma, 1, 1, 1, true) end -- 8-oct (armas): por que la BiS no cumple la regla de arma
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:SetScript("OnClick", function(self) if guiaDe[self] then WowF.irARecompensa(guiaDe[self]) end end)
  casillas[i] = b
end
local function vacia(d)
  local _, tex
  if GetInventorySlotInfo then _, tex = GetInventorySlotInfo(d[2]) end
  return tex or "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
end
-- Para las pruebas: cuantas casillas tienen texto y cuantas marcan mejora
WowF = WowF or {}
WowF.libroCasillas = function()
  local con, verdes = 0, 0
  for _, b in ipairs(casillas) do
    if b._txt and b._txt ~= "" then con = con + 1 end
    if b.mejora then verdes = verdes + 1 end
  end
  return con, verdes, #casillas
end
-- 5-oct, para las pruebas: la mejora de una casilla, su tooltip y su clic (Llevame)
WowF.libroCasilla = function(slot, que)
  for _, b in ipairs(casillas) do
    if b.def[1] == slot then
      if que == "clic" then b:GetScript("OnClick")(b)
      elseif que == "tooltip" then b:GetScript("OnEnter")(b) end
      return guiaDe[b], b -- 7-oct: b para las pruebas (b.dudosa, b._borde)
    end
  end
end
local arriba = 0 -- alto reservado arriba de la hoja (la figura en Equipo)

CONTENIDO.Equipo = function(p)
  local nivel = nivelActual()
  local Y = WowF.yaTraducido
  -- 5-oct: la siguiente mejora REAL por casilla segun los pesos de tu rama, con de donde sale (wowF_EquipoGuia.lua).
  -- Se recalcula con tu nivel, tu faccion y lo que llevas puesto.
  local g = WowF.equipoGuia and WowF.equipoGuia(p) or { ranuras = {}, total = 0 }
  for _, b in ipairs(casillas) do
    local d = b.def
    local enlace = GetInventoryItemLink and GetInventoryItemLink("player", d[1])
    local tex = enlace and GetInventoryItemTexture and GetInventoryItemTexture("player", d[1])
    local x = g.ranuras[d[1]]
    guiaDe[b] = x
    b.mejora = x ~= nil
    b.dudosa = (x and x.dudosa) and true or false -- 7-oct: mejora pequena = borde dorado (false, no nil: siempre booleano)
    b.mejor = x and x.id
    b._borde = b.dudosa and "oro" or (b.mejora and "verde" or (enlace and "gris" or "vacio"))
    b.icono:SetTexture(tex or vacia(d))
    if b.icono.SetDesaturated then b.icono:SetDesaturated(not enlace) end
    if b.marco.SetColorTexture then
      if b.dudosa then b.marco:SetColorTexture(1, 0.82, 0, 0.9)
      elseif b.mejora then b.marco:SetColorTexture(0.2, 1, 0.3, 0.9)
      elseif enlace then b.marco:SetColorTexture(0.45, 0.45, 0.45, 0.8)
      else b.marco:SetColorTexture(0.35, 0.3, 0.2, 0.8) end
    end
    local nombre = enlace and (enlace:match("%[(.-)%]") or "?")
    local q = enlace and GetItemInfo and select(3, GetItemInfo(enlace))
    local linea2 = nombre and (colorCalidad(q or 1) .. recortar(nombre, 22) .. "|r") or (GRIS .. WowF.T("vacio") .. "|r")
    local linea3 = ""
    if x then
      local n = obj(x.id)
      linea3 = "\n" .. (x.dudosa and ORO or VERDE) .. "+ " .. recortar(n, 14) .. " " .. WowF.equipoPorcentaje(x) .. "|r"
    elseif enlace then
      linea3 = "\n" .. GRIS .. L("ya lo tienes bien", "you're fine") .. "|r"
    end
    b._txt = GRIS .. d[3]
    b.texto:SetText(Y(GRIS .. WowF.T(d[3]) .. "|r\n" .. linea2 .. linea3))
  end
  figura:Show()
  if modelo then pcall(modelo.SetUnit, modelo, "player") end
  arriba = ALTO_FIGURA + 8
  cab(Y(ORO .. L("Mejoras para ti a nivel " .. nivel, "Upgrades for you at level " .. nivel) .. "|r" .. GRIS .. L("  ·  borde verde = mejora, dorado = mejora pequeña, gris = ya lo tienes bien", "  ·  green border = upgrade, gold = small upgrade, gray = you're fine") .. "|r"))
  if WowF.avisoMejorEquipo then nota(Y(WowF.avisoMejorEquipo())) end
  if WowF.avisoPesos then local ap = WowF.avisoPesos(p); if ap then nota(Y(ap)) end end -- 9-oct: orden de Icy Veins (Forever), valores sin confirmar
  local filtro = WowF.avisoFiltroMejoras and WowF.avisoFiltroMejoras() -- 8-oct: algun origen apagado en Ajustes
  if filtro then nota(Y(filtro)) end
  -- 8-oct (4.12): el filtro a la vista (antes solo en Ajustes y no se encontraba). Clic = marcar/desmarcar al momento.
  if WowF.mejorasDe then
    local casillas = {
      { "mision", "mejorasMision", L("De misiones", "From quests") },
      { "mazmorra", "mejorasMazmorra", L("De mazmorras (y marca del jefe)", "From dungeons (and boss mark)") },
      { "fabricar", "mejorasFabricar", L("Fabricadas (avisos y panel)", "Crafted (alerts and panel)") },
    }
    nota(Y(ORO .. L("Mostrar mejoras de equipo (clic para marcar o desmarcar):", "Show gear upgrades (click to check or uncheck):") .. "|r"))
    for _, c in ipairs(casillas) do
      local si = WowF.mejorasDe(c[1])
      nota(Y((si and (VERDE .. "[X] ") or (GRIS .. "[  ] ")) .. c[3] .. "|r" .. GRIS .. (si and L("  - clic para ocultarlas", "  - click to hide them") or L("  - clic para mostrarlas", "  - click to show them")) .. "|r"),
        function()
          if type(WowFExportarDB) ~= "table" then return end
          WowFExportarDB[c[2]] = (not si) and true or false
          if WowF.equipoGuiaLimpiar then WowF.equipoGuiaLimpiar() end
          dibujar()
        end)
    end
  end
  -- La mejor mazmorra para tu equipo ahora (abierta a tu nivel y de tu faccion)
  local mz = g.mazmorra
  if mz then
    local nombres = {}
    for k, x in ipairs(mz.piezas) do if k <= 4 then table.insert(nombres, (obj(x.id))) end end
    item({ texto = Y(ORO .. L("La mejor mazmorra para tu equipo ahora: ", "Best dungeon for your gear right now: ") .. "|r" .. VERDE .. mz.m.n .. "|r"
        .. GRIS .. " (" .. mz.n .. (mz.n == 1 and L(" mejora", " upgrade") or L(" mejoras", " upgrades")) .. ")|r"),
      sub = Y(GRIS .. table.concat(nombres, ", ") .. "  ·  " .. L("clic: llevame", "click: take me there") .. "|r"),
      icono = ICONO.mazmorra, accion = function() WowF.irAMazmorra(mz.m) end,
      ayuda = Y(L("Mazmorra abierta a tu nivel con mas casillas que mejoran. Clic: ruta hasta la entrada.", "Dungeon open at your level with the most slots that improve. Click: route to the entrance.")) })
  end
  nota(Y(GRIS .. L("Prioridad de estadisticas: ", "Stat priority: ") .. "|r" .. ORO .. WowF.T(p.prioridad or "") .. "|r"))
  -- Una fila por casilla con mejora, en el orden de la figura
  local hay = false
  for _, b in ipairs(casillas) do
    local x = guiaDe[b]
    if x then
      hay = true
      local n, q, ic = obj(x.id)
      local marca = tengo(x.id) > 0 and (VERDE .. L("  [en tus bolsas: equipala]", "  [in your bags: equip it]") .. "|r") or ""
      local desde = math.max(x.desde or 0, nivel)
      item({ texto = Y(GRIS .. WowF.T(b.def[3]) .. ":|r  " .. colorCalidad(q) .. n .. "|r  " .. (x.dudosa and ORO or VERDE) .. WowF.equipoPorcentaje(x) .. "|r" .. marca),
        sub = Y(GRIS .. WowF.equipoFuente(x) .. "  ·  " .. (x.desde > nivel and L("desde el nivel ", "from level ") .. x.desde .. "  ·  " or "")
          .. (x.hasta and L("te dura hasta el " .. x.hasta, "lasts until " .. x.hasta) or L("nada mejor verificado hasta el " .. (x.tope or 30), "nothing better verified up to " .. (x.tope or 30)))
          .. "  ·  " .. CELESTE .. ((WowF.equipoLinea and WowF.equipoLinea(x)) and L("clic: guiame paso a paso", "click: guide me step by step") or L("clic: llevame", "click: take me there")) .. "|r"),
        icono = icono(ic, x.id), objeto = x.id, chico = true, accion = function() WowF.irARecompensa(x) end })
    end
  end
  if not hay then nota(Y(VERDE .. L("No hay nada verificado mejor que lo que llevas a tu nivel. Vuelve al subir de nivel.", "Nothing verified is better than what you wear at your level. Check again when you level up.") .. "|r")) end
  -- 7-oct: "BiS 30: <pieza>" por hueco (wowF_EquipoGuia.lua WowF.equipoBiS); clic = el mismo destino que en la ventana BiS 30
  local dBis = WowF.bisDe and WowF.bisDe(p)
  local cabBis = false
  for _, b in ipairs(casillas) do
    b._bis = WowF.equipoBiS and WowF.equipoBiS(b.def[1], p, dBis) or {}
    for _, bx in ipairs(b._bis) do
      if not cabBis then
        cabBis = true
        cab(Y(ORO .. L("BiS de nivel 30 por hueco", "Level 30 BiS per slot") .. "|r" .. GRIS .. L("  ·  clic: te llevo a donde se consigue", "  ·  click: I take you to where you get it") .. "|r"), nil, { cerrada = true, clave = "bis" })
      end
      local subB = WowF.bisComo and Y(GRIS .. WowF.bisComo(bx.pz) .. "|r") or nil
      if bx.arma then subB = (subB and (subB .. "\n") or "") .. bx.arma end -- 8-oct (armas)
      local nmB = (not bx.llevas) and WowF.bisNivelMision and WowF.bisNivelMision(bx.pz) -- 8-oct: desde que nivel se hace la mision
      if nmB then subB = Y((subB and (subB .. "\n") or "") .. nmB) end
      item({ texto = Y(GRIS .. WowF.T(b.def[3]) .. ":|r  " .. bx.texto), sub = subB,
        icono = icono(nil, bx.pz.id), objeto = bx.pz.id, chico = true, accion = bx.accion })
    end
  end
  local propias = eventosTipo(p, { equipo = true })
  local proximas = {}
  local topeF = (WowFDatos and WowFDatos.topeBeta) or 30
  for _, e in ipairs(propias) do if e[1] >= nivel - 3 and e[1] <= topeF then table.insert(proximas, e) end end
  if #proximas > 0 then
    cab(ORO .. "Te lo fabricas tu (" .. (p.profesiones or "") .. ")|r")
    fabricadas(proximas)
  elseif p.sugerida then
    cab(CELESTE .. "Si aprendes " .. p.sugerida.nombre .. "|r")
    nota(GRIS .. "Con " .. (p.profesiones or "") .. " no fabricas equipo. En la pestana Profesiones ves todo lo que te harias con " .. p.sugerida.nombre .. ".|r",
      function() pestana = "Profesiones"; subActiva.Profesiones = "objetivo"; dibujar() end)
  end
end

-- ----- Mazmorras -----
CONTENIDO.Mazmorras = function(p)
  -- 11-oct (4.26): diario de mazmorras (wowF_Diario.lua) como sub-pestana principal; la lista de siempre queda en "Lista detallada"
  -- (las pruebas leen sus textos con libroTexto, que recorre tambien los grupos ocultos). Sin wowF_Diario, la lista de siempre.
  if WowF.contenidoDiario then
    subpestanas({ { "diario", L("Diario", "Journal") }, { "lista", L("Lista detallada", "Detailed list") } })
    grupo("diario")
    local ok, hecho = pcall(WowF.contenidoDiario, p, function(marco, alto) table.insert(filas, { tipo = "bloque", marco = marco, alto = alto }) end)
    if not ok then nota(NARANJA .. L("No se pudo dibujar el diario: ", "Could not draw the journal: ") .. tostring(hecho) .. "|r")
    elseif not hecho then nota(GRIS .. L("Aún no hay mazmorras con datos de WoW Forever.", "No dungeons with WoW Forever data yet.") .. "|r") end
    grupo("lista")
  end
  local nivel = nivelActual()
  local abiertas, proximas, pasadas = {}, {}, {}
  for _, m in ipairs(WowFMazmorras or {}) do
    if not WowF.esMia or WowF.esMia(m) then
      if nivel > m.h then table.insert(pasadas, m) elseif nivel < m.d then table.insert(proximas, m) else table.insert(abiertas, m) end
    end
  end
  local function pintar(m, apagada, sinPiezas)
    local ideal = math.floor((m.d + m.h) / 2)
    local estado
    if nivel > m.h then estado = GRIS .. L("ya pasaste su nivel", "you are past its level")
    elseif nivel < m.d then estado = GRIS .. L("se abre al nivel " .. m.d .. "  ·  ideal: " .. ideal, "opens at level " .. m.d .. "  ·  ideal: " .. ideal)
    elseif nivel < ideal then estado = NARANJA .. L("ya puedes entrar; mejor al nivel " .. ideal, "you can go in now; better at level " .. ideal)
    else estado = VERDE .. L("buen nivel: ve ya", "good level: go now") end
    -- Solo las piezas que mejoran lo que llevas puesto (wowF_Comparar.lua), cada una con o.porque
    local piezas = (WowF.piezasParaTi and WowF.piezasParaTi(p, m.i)) or (p.botin or {})[m.i] or {}
    local misiones, xpFalta, xpExacta = {}, 0, false
    if WowF.misionesDe then misiones, xpFalta, xpExacta = WowF.misionesDe(m) end
    local txtMis = (#misiones > 0) and ("  ·  " .. ORO .. #misiones .. L(" misiones de mazmorra", " dungeon quests") .. "|r" .. (xpFalta > 0 and (VERDE .. " " .. WowF.textoXP(xpFalta, xpExacta) .. "|r") or (GRIS .. L(" (hechas)", " (done)") .. "|r")))
      or (NARANJA .. L("  ·  misiones: aún no hay datos de WoW Forever; pendiente de actualizar", "  ·  quests: no WoW Forever data yet; pending update") .. "|r")
    local irA = function() if WowF.irAMazmorra then WowF.irAMazmorra(m) elseif WowF.marcar then WowF.marcar(m) end end
    item({ texto = WowF.yaTraducido((apagada and GRIS or ORO) .. m.n .. "|r" .. GRIS .. L("  niveles ", "  levels ") .. m.d .. "-" .. m.h .. "|r"),
      sub = WowF.yaTraducido(estado .. "|r" .. GRIS .. "  ·  " .. (m.z or "") .. ((m.a or not m.m) and L(" (entrada aún no confirmada en WoW Forever; pendiente de actualizar)", " (entrance not confirmed in WoW Forever yet; pending update)") or "") .. "|r\n"
        .. (#piezas > 0 and (VERDE .. #piezas .. L(" piezas para ti", " pieces for you") .. "|r") or (GRIS .. L("sin piezas para tu plan", "no pieces for your plan") .. "|r")) .. txtMis
        .. VERDE .. L("  ·  clic: cómo llegar (ruta paso a paso)", "  ·  click: how to get there (step-by-step route)") .. "|r"),
      icono = ICONO.mazmorra, accion = irA })
    -- 5-oct: por que hay pocas piezas (o ninguna) para ti aqui (WowF.porQuePocas, wowF_Comparar.lua)
    local pocas = (not apagada) and WowF.porQuePocas and WowF.porQuePocas(p, m.i, piezas)
    if pocas then item({ texto = WowF.yaTraducido(GRIS .. pocas .. '|r'), sangria = 30, chico = true }) end
    for _, bp in ipairs(WowF.campamentoFicha and WowF.campamentoFicha(m.n) or {}) do item({ texto = bp, sangria = 30, chico = true }) end -- 8-oct: Blueprints de tus profesiones (wowF_Campamento.lua)
    if not apagada and #misiones > 0 then
      -- 13-oct: antes decia "Misiones de dentro (casi todas se cogen FUERA...)": se contradecia. Se TERMINAN dentro; casi todas se cogen fuera.
      item({ texto = WowF.yaTraducido(ORO .. L("Misiones de la mazmorra", "Dungeon quests") .. "|r" .. GRIS .. L("  (se terminan dentro; casi todas se cogen FUERA, antes de entrar, y dan mucha XP)", "  (you finish them inside; most are picked up OUTSIDE, before you go in, and give a lot of XP)") .. "|r"), sangria = 30, chico = true })
      -- 4-oct: un clic marca en el mapa TODAS las de fuera, numeradas de la mas cercana a la mas lejana
      local fuera = 0
      if WowF.misionesFueraDe then for _, g in ipairs(WowF.misionesFueraDe(m)) do fuera = fuera + #g.q end end
      local yaMarcadas = WowF.misionesMarcadasDe and WowF.misionesMarcadasDe(m)
      if (fuera > 0 or yaMarcadas) and WowF.marcarTodasMisiones then
        item({ texto = WowF.yaTraducido(yaMarcadas and (NARANJA .. L("Quitar del mapa las marcas de misiones", "Clear the quest marks from the map") .. "|r")
            or ("|cffc77dff" .. L("Marcar en el mapa las " .. fuera .. " misiones de fuera", "Mark all " .. fuera .. " outside quests on the map") .. "|r")),
          sub = not yaMarcadas and WowF.yaTraducido(GRIS .. L("numeradas de la más cercana a la más lejana desde donde estás · clic", "numbered from nearest to farthest from where you are · click") .. "|r") or nil,
          icono = ICONO.mision or ICONO.mazmorra, sangria = 30, chico = true,
          accion = function() WowF.marcarTodasMisiones(m); if WowF.abrirLibro then pcall(WowF.abrirLibro) end end })
        local resumen = WowF.resumenNivelesFuera and WowF.resumenNivelesFuera(m, nivel)
        if resumen then item({ texto = resumen, sangria = 30, chico = true }) end
      end
      for _, q in ipairs(misiones) do
        local c = q.hecha and GRIS or (nivel < q.nivel and NARANJA or BLANCO)
        -- Quien la da y donde: clic = alfiler en el NPC (las de dentro no llevan alfiler)
        local donde, accion = nil, nil
        local sinDato = L("aún no hay datos de WoW Forever; pendiente de actualizar", "no WoW Forever data yet; pending update")
        if not q.hecha and q.dentro then
          -- 13-oct: antes sin clic; ahora lleva a la mazmorra (la mision se coge dentro)
          donde = GRIS .. L("se recoge dentro de la mazmorra", "picked up inside the dungeon") .. "|r" .. VERDE .. L("  ·  clic: cómo llegar a la mazmorra", "  ·  click: how to get to the dungeon") .. "|r"
          accion = irA
        elseif not q.hecha and q.quien and q.m and q.m > 0 then
          local info = C_Map and C_Map.GetMapInfo and select(2, pcall(C_Map.GetMapInfo, q.m))
          donde = (WowF.dondeLaDaMision and WowF.dondeLaDaMision(q) or (GRIS .. L("la da ", "given by ") .. q.quien .. ((type(info) == "table" and info.name) and (L(" en ", " in ") .. info.name) or "") .. "|r"))
            .. "\n" .. NARANJA .. L("cógela ANTES de entrar", "pick it up BEFORE going in") .. "|r" .. VERDE .. L("  ·  clic: ruta paso a paso hasta el NPC", "  ·  click: step-by-step route to the NPC") .. "|r"
          accion = function() if WowF.irAMision then WowF.irAMision({ quien = q.quien, m = q.m, x = q.x, y = q.y, q = { q } }) end end
          local aunNo = WowF.aunNoMision and WowF.aunNoMision(q, nivel)
          if aunNo then donde = (WowF.dondeLaDaMision and WowF.dondeLaDaMision(q) or (GRIS .. L("la da ", "given by ") .. q.quien .. "|r")) .. "\n" .. aunNo end
        elseif not q.hecha then
          -- 13-oct: sin NPC o sin sitio en los datos: antes no decia nada ni tenia clic. Ahora el aviso y el clic lo explica en el chat.
          local quien = q.quien and (L("la da ", "given by ") .. q.quien .. "; " .. L("dónde: ", "where: ")) or L("quién la da: ", "quest giver: ")
          donde = NARANJA .. quien .. sinDato .. "|r"
          accion = function() print(WowF.yaTraducido("|cff33ccffForever Guide|r: " .. q.n .. ": " .. quien .. sinDato)) end
        end
        -- 5-oct: linea de misiones con pasos pendientes: lo dice y el clic lleva al paso que toca (aunque la de mazmorra se coja dentro)
        local corta = (not q.hecha and WowF.lineaMisionCorta) and WowF.lineaMisionCorta(q) or ""
        if corta ~= "" then
          donde = corta .. VERDE .. L("  ·  clic: la línea paso a paso", "  ·  click: the questline step by step") .. "|r" .. (donde and ("\n" .. donde) or "")
          accion = function() if WowF.irALinea then WowF.irALinea(q, (not q.dentro and q.m and q.m > 0) and { quien = q.quien, m = q.m, x = q.x, y = q.y, q = { q } } or nil) end end
        end
        -- 9-oct (4.16): a quien se entrega y donde (fuera y dentro); si ya la llevas, el clic va a la entrega
        if not q.hecha and WowF.dondeSeEntrega then
          local ent = WowF.dondeSeEntrega(q)
          if WowF.misionEnDiario and WowF.misionEnDiario(q.id) and WowF.irAEntrega then
            ent = ent .. VERDE .. L("  ·  ya la llevas: clic = ruta a la entrega", "  ·  you have it: click = route to turn it in") .. "|r"
            accion = function() WowF.irAEntrega(q) end
          end
          donde = (donde and (donde .. "\n") or "") .. ent
        end
        item({ texto = WowF.yaTraducido(c .. q.n .. "|r" .. GRIS .. L("  ·  desde nivel ", "  ·  from level ") .. q.nivel .. "|r  " .. (q.hecha and (GRIS .. L("hecha", "done") .. "|r") or (VERDE .. WowF.textoXP(WowF.xpMision(q)) .. "|r"))),
          sub = donde and WowF.yaTraducido(donde) or nil, accion = accion, icono = ICONO.mision or ICONO.mazmorra, sangria = 30, chico = true })
      end
    end
    if not apagada and not sinPiezas then
      for _, o in ipairs(piezas) do
        local ya = tengo(o.id) > 0
        -- 13-oct: antes la pieza no tenia clic. Ahora dice quien la suelta y lleva a la mazmorra; sin jefe = aviso (nada de "?")
        local jefe = o.j and (L("la suelta ", "dropped by ") .. o.j) or L("jefe: aún no hay datos de WoW Forever; pendiente de actualizar", "boss: no WoW Forever data yet; pending update")
        item({ texto = WowF.yaTraducido((ya and (VERDE .. L("[ya la tienes] ", "[you have it] ") .. "|r") or "") .. colorCalidad(o.q or 2) .. o.n .. "|r" .. GRIS .. "  " .. (o.r or "") .. "  ·  " .. jefe .. "|r"),
          sub = WowF.yaTraducido((o.porque and (VERDE .. (WowF.T and WowF.T(o.porque) or o.porque) .. "|r\n") or "") .. VERDE .. L("clic: cómo llegar a la mazmorra", "click: how to get to the dungeon") .. "|r"),
          icono = icono(o.ic, o.id), objeto = o.id, sangria = 30, chico = true,
          accion = function()
            print(WowF.yaTraducido("|cff33ccffForever Guide|r: " .. o.n .. ": " .. jefe .. L(" en ", " in ") .. m.n))
            irA()
          end })
      end
    end
  end
  nota(WowF.yaTraducido(GRIS .. L("Ideal = estimación de la guía (la mitad del rango de niveles), no un dato de WoW Forever. Clic en una mazmorra: te explica cómo llegar desde donde estás (zepelines, barcos) y pone el alfiler. Pasa el ratón por una pieza para verla. La XP de una misión solo sale cuando el juego ya te la dijo a tu nivel (al abrir la misión): aún no tenemos la XP de WoW Forever de cada misión.",
    "Ideal = guide estimate (the middle of the level range), not WoW Forever data. Click a dungeon: it explains how to get there from where you are (zeppelins, boats) and sets the map pin. Hover over a piece to see it. Quest XP only shows once the game has told you the real amount at your level (when you open the quest): we do not have the WoW Forever XP of each quest yet.") .. "|r"))
  cab(WowF.yaTraducido(VERDE .. L("Para ir ya", "Go now") .. "|r"), nil, { clave = "maz-ya" })
  if #abiertas == 0 and #proximas == 0 and #pasadas > 0 then
    nota(WowF.yaTraducido(GRIS .. L("Ya pasaste el nivel de todas las mazmorras con datos (abajo, por si quieres repetirlas).", "You are past the level of every dungeon with data (below, in case you want to repeat them).") .. "|r"))
    if verPasado.Mazmorras == nil then verPasado.Mazmorras = true end
  elseif #abiertas == 0 then nota(WowF.yaTraducido(GRIS .. L("Ninguna abierta a tu nivel todavía.", "None open at your level yet.") .. "|r")) end
  for _, m in ipairs(abiertas) do pintar(m) end
  if #proximas > 0 then
    cab(WowF.yaTraducido(ORO .. L("Próximas", "Coming up") .. "|r"), nil, { cerrada = true, clave = "maz-proximas" })
    for i, m in ipairs(proximas) do if i <= 3 then pintar(m, false, true) end end
    if #proximas > 3 then nota(WowF.yaTraducido(GRIS .. L("y " .. (#proximas - 3) .. " más para niveles altos.", "and " .. (#proximas - 3) .. " more for higher levels.") .. "|r")) end
  end
  if #pasadas > 0 then
    nota(WowF.yaTraducido(GRIS .. L("Ya pasaste su nivel: ", "Past their level: ") .. #pasadas .. (verPasado.Mazmorras and L("  ·  clic: ocultarlas", "  ·  click: hide them") or L("  ·  clic: verlas", "  ·  click: show them")) .. "|r"), function() verPasado.Mazmorras = not verPasado.Mazmorras; dibujar() end)
    if verPasado.Mazmorras then for _, m in ipairs(pasadas) do pintar(m, true) end end
  end
end

-- ----- 11-oct (rediseno "hibrido"): tablero de Progreso, lo primero que ves al abrir -----
-- Tarjeta grande "TU MISION AHORA" (zona, Llevame, hechizos que vienen), a la derecha la mazmorra que toca y las misiones
-- que se cogen antes de entrar, y abajo tus profesiones. Debajo sigue la lista de siempre, nivel por nivel.
local ALTO_TABLERO = 438
local tablero = CreateFrame("Frame", nil, hoja)
tablero:SetSize(ANCHO_HOJA, ALTO_TABLERO)
tablero:Hide()
local function tarjeta(x, y, w, h, tinte)
  local f = CreateFrame("Button", nil, tablero, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(w, h)
  f:SetPoint("TOPLEFT", tablero, "TOPLEFT", x, -y)
  E.marco(f, "losa")
  if tinte and f.SetBackdropColor then pcall(f.SetBackdropColor, f, tinte[1], tinte[2], tinte[3], 0.92) end
  local luz = f:CreateTexture(nil, "ARTWORK")
  luz:SetAllPoints()
  if luz.SetColorTexture then luz:SetColorTexture(1, 1, 1, 0.05) end
  luz:Hide()
  f.luz = luz
  return f
end
local function letrero(padre, tipo, tam, r, g, b)
  local t = padre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  E.letra(t, tipo, tam)
  t:SetJustifyH("LEFT")
  if t.SetWordWrap then t:SetWordWrap(false) end
  t:SetTextColor(r or 1, g or 1, b or 1)
  return t
end
local function encima(f, titulo, texto)
  f:SetScript("OnEnter", function(self)
    if self.accion then self.luz:Show() end
    if not GameTooltip or not titulo then return end
    -- solo textos: un campo sin poner (titulo/explica) no debe llegar al tooltip
    local tt = titulo()
    if type(tt) ~= "string" or tt == "" then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(tt, 1, 0.82, 0)
    local s = texto and texto(self)
    if type(s) == "string" and s ~= "" then GameTooltip:AddLine(s, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function(self) self.luz:Hide(); if GameTooltip then GameTooltip:Hide() end end)
  f:SetScript("OnClick", function(self) if self.accion then self.accion() end end)
end
local function seguro(f, ...)
  if type(f) ~= "function" then return nil end
  local r = { pcall(f, ...) }
  if r[1] then return r[2], r[3] end
  return nil
end
local BRASA = { 0.85, 0.42, 0.18 }

-- Tarjeta de la mision
local mision = tarjeta(0, 0, 406, 356)
local barra = mision:CreateTexture(nil, "ARTWORK")
barra:SetPoint("TOPLEFT", 1, -1); barra:SetPoint("TOPRIGHT", -1, -1); barra:SetHeight(3)
if barra.SetColorTexture then barra:SetColorTexture(C.brasa[1], C.brasa[2], C.brasa[3], 1) end
mision.eti = letrero(mision, "marca", 10, BRASA[1], BRASA[2], BRASA[3])
mision.eti:SetPoint("TOPLEFT", 18, -18)
mision.titulo = letrero(mision, "titulo", 26, 1, 0.96, 0.9)
mision.titulo:SetPoint("TOPLEFT", 18, -36); mision.titulo:SetWidth(370)
mision.linea = letrero(mision, "boton", 12, 0.78, 0.72, 0.62)
mision.linea:SetPoint("TOPLEFT", 18, -76); mision.linea:SetWidth(260)
mision.ir = CreateFrame("Button", nil, mision, "UIPanelButtonTemplate")
mision.ir:SetSize(96, 34)
mision.ir:SetPoint("TOPRIGHT", mision, "TOPRIGHT", -16, -66)
E.boton(mision.ir, "brasa", 13)
mision.raya = mision:CreateTexture(nil, "ARTWORK")
mision.raya:SetPoint("TOPLEFT", 16, -114); mision.raya:SetPoint("TOPRIGHT", -16, -114); mision.raya:SetHeight(1)
if mision.raya.SetColorTexture then mision.raya:SetColorTexture(C.oro2[1], C.oro2[2], C.oro2[3], 0.35) end
mision.sub = letrero(mision, "marca", 9, 0.769, 0.722, 0.659)
mision.sub:SetPoint("TOPLEFT", 18, -126)
mision.filas = {}
for k = 1, 3 do
  local f = CreateFrame("Button", nil, mision)
  f:SetSize(373, 40)
  f:SetPoint("TOPLEFT", mision, "TOPLEFT", 16, -146 - (k - 1) * 46)
  local fondo = f:CreateTexture(nil, "BACKGROUND")
  fondo:SetAllPoints()
  if fondo.SetColorTexture then fondo:SetColorTexture(0, 0, 0, 0.22) end
  f.luz = f:CreateTexture(nil, "ARTWORK"); f.luz:SetAllPoints()
  if f.luz.SetColorTexture then f.luz:SetColorTexture(1, 1, 1, 0.06) end
  f.luz:Hide()
  f.icono = f:CreateTexture(nil, "OVERLAY")
  f.icono:SetSize(34, 34); f.icono:SetPoint("LEFT", 3, 0)
  if f.icono.SetTexCoord then f.icono:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  f.nombre = letrero(f, "boton", 13, 1, 0.93, 0.8)
  f.nombre:SetPoint("TOPLEFT", 46, -5); f.nombre:SetWidth(320)
  f.det = letrero(f, "boton", 11, 0.769, 0.722, 0.659)
  f.det:SetPoint("TOPLEFT", 46, -22); f.det:SetWidth(320)
  encima(f, function() return L("Hechizo nuevo", "New spell") end,
    function(self) return L("Clic: ruta a tu entrenador de clase.", "Click: route to your class trainer.") end)
  mision.filas[k] = f
end
mision.vacio = letrero(mision, "boton", 11, 0.769, 0.722, 0.659)
mision.vacio:SetPoint("TOPLEFT", 18, -150); mision.vacio:SetWidth(370)
if mision.vacio.SetWordWrap then mision.vacio:SetWordWrap(true) end

-- Tarjeta de la mazmorra
local maz = tarjeta(422, 0, 254, 148, { 0.20, 0.13, 0.10 })
maz.eti = letrero(maz, "marca", 10, BRASA[1], BRASA[2], BRASA[3])
maz.eti:SetPoint("TOPLEFT", 14, -14)
maz.nombre = letrero(maz, "titulo", 20, 1, 0.96, 0.9)
maz.nombre:SetPoint("TOPLEFT", 14, -32); maz.nombre:SetWidth(226)
maz.donde = letrero(maz, "boton", 11, 0.769, 0.722, 0.659)
maz.donde:SetPoint("TOPLEFT", 14, -60); maz.donde:SetWidth(226)
maz.cifras = {}
for k = 1, 3 do
  local n = letrero(maz, "marca", 18, C.oro[1], C.oro[2], C.oro[3])
  n:SetPoint("TOPLEFT", 14 + (k - 1) * 78, -88)
  local e = letrero(maz, "marca", 8, 0.769, 0.722, 0.659)
  e:SetPoint("TOPLEFT", n, "BOTTOMLEFT", 0, -3)
  maz.cifras[k] = { n = n, e = e }
end
encima(maz, function() return maz.titulo or "" end,
  function() return L("Clic: como llegar (ruta paso a paso).", "Click: how to get there (step-by-step route).") end)

-- Tarjeta de las misiones de fuera
local mis = tarjeta(422, 164, 254, 192)
mis.eti = letrero(mis, "marca", 10, BRASA[1], BRASA[2], BRASA[3])
mis.eti:SetPoint("TOPLEFT", 14, -14)
mis.filas = {}
for k = 1, 4 do
  local f = CreateFrame("Button", nil, mis)
  f:SetSize(226, 30) -- 12-oct: 30 (antes 26) para las dos lineas con la letra mas grande
  f:SetPoint("TOPLEFT", mis, "TOPLEFT", 14, -40 - (k - 1) * 34)
  f.luz = f:CreateTexture(nil, "ARTWORK"); f.luz:SetAllPoints()
  if f.luz.SetColorTexture then f.luz:SetColorTexture(1, 1, 1, 0.06) end
  f.luz:Hide()
  f.nombre = letrero(f, "boton", 12, 1, 0.93, 0.8)
  f.nombre:SetPoint("TOPLEFT", 2, -1); f.nombre:SetWidth(222)
  f.zona = letrero(f, "boton", 10, 0.769, 0.722, 0.659)
  f.zona:SetPoint("TOPLEFT", 2, -16); f.zona:SetWidth(222)
  f.raya = f:CreateTexture(nil, "ARTWORK")
  f.raya:SetPoint("BOTTOMLEFT", 0, -4); f.raya:SetPoint("BOTTOMRIGHT", 0, -4); f.raya:SetHeight(1)
  if f.raya.SetColorTexture then f.raya:SetColorTexture(C.oro2[1], C.oro2[2], C.oro2[3], 0.2) end
  encima(f, function() return f.titulo or "" end, function() return f.explica end)
  mis.filas[k] = f
end
mis.vacio = letrero(mis, "boton", 11, 0.769, 0.722, 0.659)
mis.vacio:SetPoint("TOPLEFT", 14, -42); mis.vacio:SetWidth(226)
if mis.vacio.SetWordWrap then mis.vacio:SetWordWrap(true) end

-- Franja de profesiones
local prof = tarjeta(0, 371, ANCHO_HOJA, 67)
prof.eti = letrero(prof, "marca", 10, BRASA[1], BRASA[2], BRASA[3])
prof.eti:SetPoint("TOPLEFT", 16, -8)
prof.casillas = {}
for k = 1, 4 do
  local f = CreateFrame("Button", nil, prof)
  f:SetSize(150, 38)
  f.luz = f:CreateTexture(nil, "ARTWORK"); f.luz:SetAllPoints()
  if f.luz.SetColorTexture then f.luz:SetColorTexture(1, 1, 1, 0.06) end
  f.luz:Hide()
  f.icono = f:CreateTexture(nil, "OVERLAY")
  f.icono:SetSize(30, 30); f.icono:SetPoint("LEFT", 0, 0)
  if f.icono.SetTexCoord then f.icono:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  f.nombre = letrero(f, "boton", 12, 1, 0.93, 0.8)
  f.nombre:SetPoint("TOPLEFT", 38, -4)
  f.rango = letrero(f, "marca", 11, C.oro[1], C.oro[2], C.oro[3])
  f.rango:SetPoint("TOPLEFT", 38, -20)
  encima(f, function() return f.titulo or "" end,
    function() return L("Clic: ver el paso a paso en Profesiones.", "Click: see the step by step in Professions.") end)
  prof.casillas[k] = f
end
prof.vacio = letrero(prof, "boton", 11, 0.769, 0.722, 0.659)
prof.vacio:SetPoint("TOPLEFT", 16, -30)

local SIN_DATOS = { "aún no hay datos de WoW Forever; pendiente de actualizar.", "no WoW Forever data yet; pending update." }
local ICONO_PESCA = "Interface\\Icons\\Trade_Fishing"

local function llenarMision(p, nivel)
  mision.eti:SetText(L("TU MISIÓN AHORA", "YOUR MISSION NOW"))
  local g = WowF.planZonas and seguro(WowF.planZonas)
  local tramo, indice
  if type(g) == "table" and type(g.tramos) == "table" then
    for i, t in ipairs(g.tramos) do
      if not tramo and nivel <= (t.hasta or 0) then tramo, indice = t, i end
    end
  end
  local d = tramo and WowF.detalleTramo and seguro(WowF.detalleTramo, tramo, indice, g)
  if type(d) == "table" and d.z and d.z.n then
    local ya = nivel >= (tramo.desde or 0)
    mision.titulo:SetText(WowF.yaTraducido(ya and L("Sigue subiendo en " .. d.z.n, "Keep leveling in " .. d.z.n) or L("Ve a " .. d.z.n, "Head to " .. d.z.n)))
    local quedan = math.max(0, (tramo.hasta or nivel) - nivel)
    mision.linea:SetText(WowF.yaTraducido(L("Niveles " .. tramo.desde .. "-" .. tramo.hasta .. " · te quedan " .. quedan .. (quedan == 1 and " nivel aquí" or " niveles aquí"),
      "Levels " .. tramo.desde .. "-" .. tramo.hasta .. " · " .. quedan .. (quedan == 1 and " level left here" or " levels left here"))))
    mision.ir:SetText(L("Llévame", "Take me"))
    mision.ir:SetScript("OnClick", function() if WowF.irAZona then WowF.irAZona(tramo) end end)
    mision.ir:Show()
  else
    mision.titulo:SetText(L("Sigue subiendo", "Keep leveling"))
    mision.linea:SetText(WowF.yaTraducido(L("Zona: " .. SIN_DATOS[1], "Zone: " .. SIN_DATOS[2])))
    mision.ir:Hide()
  end
  -- Hechizos que llegan en los proximos niveles (los del entrenador de tu clase; sin talentos)
  mision.sub:SetText(L("LO QUE APRENDES PRONTO", "WHAT YOU LEARN SOON"))
  local clase = UnitClass and select(2, UnitClass("player"))
  local hechizos = (WowFHechizos and clase and WowFHechizos[clase]) or {}
  local talentos = (WowFDatos and WowFDatos.clases and clase and WowFDatos.clases[clase] and WowFDatos.clases[clase].talentos) or {}
  local lista = {}
  for nombre, h in pairs(hechizos) do
    local n = type(h) == "table" and h[1] or nil
    if type(n) == "number" and n > 0 and n >= nivel and n <= nivel + 6 and not talentos[nombre] then
      local id = h[2]
      local sabe = false
      if id and IsSpellKnown then local ok, s = pcall(IsSpellKnown, id); sabe = ok and s and true or false end
      if not sabe then table.insert(lista, { nombre = nombre, nivel = n, id = id }) end
    end
  end
  table.sort(lista, function(a, b) if a.nivel ~= b.nivel then return a.nivel < b.nivel end return a.nombre < b.nombre end)
  for k, f in ipairs(mision.filas) do
    local h = lista[k]
    if h then
      -- 12-oct: icono real del hechizo (datos de WoW Forever, luego el cliente); el libro solo si no hay ninguno
      local tex = WowF.iconoHechizo and (WowF.iconoHechizo(h.id) or WowF.iconoHechizo(h.nombre))
      f.icono:SetTexture(tex or "Interface\\Icons\\INV_Misc_Book_09")
      f.nombre:SetText(WowF.yaTraducido(h.nombre))
      f.det:SetText(WowF.yaTraducido(h.nivel <= nivel and L("ya puedes aprenderlo · en tu entrenador de clase", "you can learn it now · at your class trainer")
        or L("nivel " .. h.nivel .. " · en tu entrenador de clase", "level " .. h.nivel .. " · at your class trainer")))
      f.accion = WowF.irAlEntrenadorClase and function() WowF.irAlEntrenadorClase() end or nil
      f:Show()
    else f:Hide() end
  end
  if #lista == 0 then
    mision.vacio:SetText(WowF.yaTraducido(L("Nada nuevo de tu entrenador en los próximos niveles.", "Nothing new from your trainer in the next levels.")))
    mision.vacio:Show()
  else mision.vacio:Hide() end
end

local function llenarMazmorra(p, nivel)
  local m
  -- 11-oct (diario): la misma que recomiendan el panel y la pestana Mazmorras (WowF.mazmorrasParaTi, wowF_Diario.lua)
  if WowF.mazmorrasParaTi then
    local ok, lista = pcall(WowF.mazmorrasParaTi, p, nivel)
    local e = ok and type(lista) == "table" and lista[1]
    if e and e.estado ~= "pasada" then m = e.m end
  end
  for _, x in ipairs(WowFMazmorras or {}) do
    if not m and (not WowF.esMia or WowF.esMia(x)) and (x.h or 0) >= nivel then m = x end
  end
  maz.titulo = m and m.n or nil
  if not m then
    maz.eti:SetText(L("MAZMORRA", "DUNGEON"))
    maz.nombre:SetText(L("Ninguna por ahora", "None for now"))
    maz.donde:SetText(WowF.yaTraducido(L(SIN_DATOS[1], SIN_DATOS[2])))
    for _, c in ipairs(maz.cifras) do c.n:SetText(""); c.e:SetText("") end
    maz.accion = nil
    return nil
  end
  maz.eti:SetText(L("MAZMORRA AL NIVEL " .. m.d, "DUNGEON AT LEVEL " .. m.d))
  maz.nombre:SetText(WowF.yaTraducido(m.n))
  local zona = WowF.nombreZona and m.m and seguro(WowF.nombreZona, m.m)
  local ideal = math.floor(((m.d or 0) + (m.h or 0)) / 2)
  maz.donde:SetText(WowF.yaTraducido((type(zona) == "string" and zona ~= "" and (zona .. " · ") or "") .. L("ideal al " .. ideal, "best at " .. ideal)))
  local piezas = WowF.piezasParaTi and seguro(WowF.piezasParaTi, p, m.i)
  local grupos = WowF.misionesFueraDe and seguro(WowF.misionesFueraDe, m)
  local fuera = 0
  if type(grupos) == "table" then for _, g in ipairs(grupos) do fuera = fuera + #(g.q or {}) end end
  local cifras = {
    { type(piezas) == "table" and #piezas or 0, L("PIEZAS", "ITEMS") },
    { #(m.q or {}), L("MISIONES", "QUESTS") },
    { fuera, L("FUERA", "OUTSIDE") },
  }
  for k, c in ipairs(maz.cifras) do c.n:SetText(tostring(cifras[k][1])); c.e:SetText(cifras[k][2]) end
  maz.accion = function() if WowF.irAMazmorra then WowF.irAMazmorra(m) end end
  return m, grupos
end

local function llenarMisiones(m, grupos)
  mis.eti:SetText(L("CÓGELAS ANTES DE ENTRAR", "GRAB THESE BEFORE GOING IN"))
  local lista = {}
  if type(grupos) == "table" then
    for _, g in ipairs(grupos) do
      for _, q in ipairs(g.q or {}) do table.insert(lista, { g = g, q = q }) end
    end
  end
  for k, f in ipairs(mis.filas) do
    local e = lista[k]
    if e then
      local nombre = e.q.n or e.q[1] or "?"
      local zona = WowF.nombreZona and e.g.m and seguro(WowF.nombreZona, e.g.m)
      f.nombre:SetText(WowF.yaTraducido(tostring(nombre)))
      f.zona:SetText(WowF.yaTraducido((e.g.quien and (e.g.quien .. " · ") or "") .. (type(zona) == "string" and zona or "")))
      f.titulo = tostring(nombre)
      f.explica = L("Clic: ruta hasta quien la da.", "Click: route to who gives it.")
      local g = e.g
      f.accion = WowF.irAMision and function() WowF.irAMision(g) end or nil
      if k < math.min(#lista, #mis.filas) then f.raya:Show() else f.raya:Hide() end
      f:Show()
    else f:Hide() end
  end
  if #lista == 0 then
    mis.vacio:SetText(WowF.yaTraducido(m and L("Esta mazmorra no tiene misiones que se cojan fuera.", "This dungeon has no quests picked up outside.")
      or L(SIN_DATOS[1], SIN_DATOS[2])))
    mis.vacio:Show()
  else mis.vacio:Hide() end
end

local function llenarProfesiones()
  prof.eti:SetText(L("PROFESIONES", "PROFESSIONS"))
  local lista = WowF.profesiones and seguro(WowF.profesiones)
  if type(lista) ~= "table" then lista = {} end
  local n = math.min(#lista, #prof.casillas)
  local ancho = math.floor((ANCHO_HOJA - 32) / math.max(n, 1))
  for k, f in ipairs(prof.casillas) do
    local pr = lista[k]
    if pr and k <= n then
      f:SetSize(ancho - 8, 38)
      f:ClearAllPoints(); f:SetPoint("TOPLEFT", prof, "TOPLEFT", 16 + (k - 1) * ancho, -24)
      local ic = ICONO[pr.id] or (WowF.ICONO_PROF and WowF.ICONO_PROF[pr.id]) or (pr.id == 356 and ICONO_PESCA) or ICONO.prof
      f.icono:SetTexture(ic)
      local nombre = pr.en or pr.nombre or "?"
      f.nombre:SetText(WowF.yaTraducido(nombre))
      f.rango:SetText(tostring(pr.rango or 0) .. "/" .. tostring(pr.maximo or 0))
      f.titulo = nombre
      f.accion = function() pestana = "Profesiones"; subActiva.Profesiones = "mias"; dibujar(); irArriba() end
      f:Show()
    else f:Hide() end
  end
  if n == 0 then
    prof.vacio:SetText(L("Aún no tienes profesiones. Revisa cuáles te convienen en la pestaña Profesiones.", "No professions yet. See which ones suit you in the Professions tab."))
    prof.vacio:Show()
    prof.accion = function() pestana = "Profesiones"; dibujar(); irArriba() end
  else prof.vacio:Hide(); prof.accion = nil end
end
encima(prof, nil, nil)

local function llenarTablero(p)
  local nivel = nivelActual()
  pcall(llenarMision, p, nivel)
  local ok, m, grupos = pcall(llenarMazmorra, p, nivel)
  pcall(llenarMisiones, ok and m or nil, ok and grupos or nil)
  pcall(llenarProfesiones)
  table.insert(filas, { tipo = "bloque", marco = tablero, alto = ALTO_TABLERO + 14 })
end
WowF.libroTablero = tablero

-- ===================== Vista de Progreso (11-oct, maqueta progreso.png aprobada por Andy) =====================
-- Fila 1: Tu mision ahora (1.45) | Lo que aprendes pronto (1) | Mazmorra (1). Fila 2: Tu camino (6 niveles con riel).
-- Fila 3: Cogelas antes de <mazmorra> (1.75) | Profesiones (1). Mismos datos y acciones que el tablero viejo.
-- Todo en un bloque do...end para no sumar locales al archivo (Lua tiene tope de 200 por funcion).
do
  local unpack = unpack or table.unpack
  local SIN = function() return L("aún no hay datos de WoW Forever; pendiente de actualizar", "no WoW Forever data yet; pending update") end
  local MASCARA = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
  local PAD, GAP = 16, 12
  local vp -- el marco de la vista (se crea una vez)
  local textos = {}
  local function anotar(s) if type(s) == "string" and s ~= "" then table.insert(textos, s) end return s end
  local function poner(fs, s) s = s or ""; fs:SetText(s); anotar(s); return s end
  local function altoDe(fs, minimo)
    local h = fs and fs.GetStringHeight and tonumber(fs:GetStringHeight()) or 0
    if type(h) ~= "number" or h <= 0 then h = minimo or 14 end
    return math.max(h, minimo or 0)
  end
  local function ajustar(fs, ancho) if fs.SetWidth then fs:SetWidth(ancho) end; if fs.SetWordWrap then fs:SetWordWrap(true) end end
  -- Zona clicable: luz al pasar el raton, tooltip y accion (el campo .accion se lee con rawget por el simulador)
  local function clicable(f, titulo, texto)
    f.luz = f:CreateTexture(nil, "ARTWORK", nil, 0)
    f.luz:SetAllPoints()
    if f.luz.SetColorTexture then f.luz:SetColorTexture(1, 1, 1, 0.05) end
    f.luz:Hide()
    if f.EnableMouse then f:EnableMouse(true) end
    f:SetScript("OnEnter", function(self)
      if rawget(self, "accion") then self.luz:Show() end
      if not GameTooltip then return end
      local tt = type(titulo) == "function" and titulo(self) or titulo
      if type(tt) ~= "string" or tt == "" then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tt, 1, 0.82, 0)
      local s = type(texto) == "function" and texto(self) or texto
      if type(s) == "string" and s ~= "" then GameTooltip:AddLine(s, 1, 1, 1, true) end
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function(self) self.luz:Hide(); if GameTooltip then GameTooltip:Hide() end end)
    local function hacer(self) local a = rawget(self, "accion"); if a then a() end end
    if f.RegisterForClicks then f:SetScript("OnClick", hacer) else f:SetScript("OnMouseUp", hacer) end
  end
  -- Disco redondo (nodo del camino): mascara con pcall; sin mascara queda cuadrado
  local function disco(padre, sub, col)
    local t = padre:CreateTexture(nil, "ARTWORK", nil, sub)
    if t.SetColorTexture then t:SetColorTexture(col[1], col[2], col[3], 1) end
    if t.SetMask then pcall(t.SetMask, t, MASCARA) end
    return t
  end
  local function boton(padre, tipo, chico)
    local b = CreateFrame("Button", nil, padre, "UIPanelButtonTemplate")
    E.boton(b, tipo, nil, chico)
    return b
  end
  local function textoBoton(b, s, chico) b:SetText(s); anotar(s); E.botonAncho(b, chico) end
  local function retratoNPC(padre, tam)
    if WowF.marcoRetrato then local ok, r = pcall(WowF.marcoRetrato, padre, tam); if ok and r then return r, true end end
    return E.retrato(padre, tam), false
  end

  local function crear(hoja, ancho)
    vp = CreateFrame("Frame", nil, hoja)
    vp:SetSize(ancho, 668)
    local inner = ancho - 2 * GAP
    local w1 = math.floor(inner * 1.45 / 3.45 + 0.5)
    local w2 = math.floor((inner - w1) / 2)
    local w3 = ancho - w1 - w2 - 2 * GAP

    -- ----- Tu mision ahora -----
    local m = E.tarjeta(vp, { variante = "principal" })
    m:SetPoint("TOPLEFT", vp, "TOPLEFT", 0, 0); m:SetSize(w1, 236)
    m.eti = E.rotulo(m); m.eti:SetPoint("TOPLEFT", PAD, -16)
    m.h2 = E.h2(m, nil, 24); m.h2:SetPoint("TOPLEFT", m.eti, "BOTTOMLEFT", 0, -10); ajustar(m.h2, w1 - 2 * PAD)
    m.sub = E.texto(m, nil, 13, C.tenue, "medio"); m.sub:SetPoint("TOPLEFT", m.h2, "BOTTOMLEFT", 0, -8); ajustar(m.sub, math.min(360, w1 - 2 * PAD))
    m.ir = boton(m, "estandarte"); m.ir:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", PAD, 22)
    m.rehacer = boton(m, "terciario"); m.rehacer:SetPoint("LEFT", m.ir, "RIGHT", 18, 0)
    vp.mision = m

    -- ----- Lo que aprendes pronto -----
    local a = E.tarjeta(vp)
    a:SetPoint("TOPLEFT", vp, "TOPLEFT", w1 + GAP, 0); a:SetSize(w2, 236)
    a.eti = E.rotulo(a, nil, C.oro); a.eti:SetPoint("TOPLEFT", PAD, -16)
    a.filas = {}
    for k = 1, 3 do
      local f = CreateFrame("Button", nil, a)
      f:SetSize(w2 - 2 * PAD, 36)
      f:SetPoint("TOPLEFT", a, "TOPLEFT", PAD, -38 - (k - 1) * 46)
      f.icono = E.icono(f, 32); f.icono:SetPoint("LEFT", 0, 0)
      f.nombre = E.texto(f, nil, 14, C.texto, "negrita"); f.nombre:SetPoint("TOPLEFT", 42, -1); ajustar(f.nombre, w2 - 2 * PAD - 42)
      if f.nombre.SetWordWrap then f.nombre:SetWordWrap(false) end
      f.det = E.texto(f, nil, 12, C.tenue, "medio"); f.det:SetPoint("TOPLEFT", f.nombre, "BOTTOMLEFT", 0, -3)
      clicable(f, function(self) return rawget(self, "titulo") end,
        function() return L("Clic: ruta a tu entrenador de clase.", "Click: route to your class trainer.") end)
      a.filas[k] = f
    end
    a.vacio = E.texto(a, nil, 13, C.tenue, "medio"); a.vacio:SetPoint("TOPLEFT", PAD, -40); ajustar(a.vacio, w2 - 2 * PAD)
    vp.aprende = a

    -- ----- Mazmorra -----
    local z = E.tarjeta(vp, { fondo = { 0.169, 0.141, 0.129 } })
    z:SetPoint("TOPLEFT", vp, "TOPLEFT", w1 + w2 + 2 * GAP, 0); z:SetSize(w3, 236)
    z.eti = E.rotulo(z); z.eti:SetPoint("TOPLEFT", PAD, -16)
    z.h3 = E.h3(z, nil, 18); z.h3:SetPoint("TOPLEFT", z.eti, "BOTTOMLEFT", 0, -10); ajustar(z.h3, w3 - 2 * PAD)
    z.sub = E.texto(z, nil, 13, C.tenue, "medio"); z.sub:SetPoint("TOPLEFT", z.h3, "BOTTOMLEFT", 0, -6); ajustar(z.sub, w3 - 2 * PAD)
    z.cifras = {}
    for k = 1, 3 do z.cifras[k] = E.cifra(z) end
    z.ver = boton(z, "secundario", true); z.ver:SetPoint("BOTTOMLEFT", z, "BOTTOMLEFT", PAD, 22)
    clicable(z, function() return rawget(z, "titulo") end,
      function() return L("Clic: cómo llegar (ruta paso a paso).", "Click: how to get there (step-by-step route).") end)
    vp.maz = z

    -- ----- Tu camino -----
    local c = E.tarjeta(vp)
    c:SetPoint("TOPLEFT", vp, "TOPLEFT", 0, -(236 + GAP)); c:SetSize(ancho, 240)
    c.eti = E.rotulo(c, nil, C.oro); c.eti:SetPoint("TOPLEFT", PAD, -16)
    c.chips = {}
    local ley = { { L("Ahora", "Now"), "brasa" }, { L("Ya puedes", "Available"), "verde" }, { L("Recomendado", "Recommended"), "oro" }, { L("Después", "Later"), "gris" } }
    for k = #ley, 1, -1 do
      local ch = E.chip(c, ley[k][1], ley[k][2])
      if k == #ley then ch:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PAD, -12) else ch:SetPoint("RIGHT", c.chips[k + 1], "LEFT", -6, 0) end
      c.chips[k] = ch
    end
    c.riel = E.textura(c, "BORDER", 1, { 0.239, 0.216, 0.188 }, 1)
    c.riel:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -63); c.riel:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PAD, -63); c.riel:SetHeight(2)
    c.hecho = E.textura(c, "BORDER", 2, C.brasa, 1)
    c.hecho:SetPoint("TOPLEFT", c.riel, "TOPLEFT", 0, 0); c.hecho:SetHeight(2); c.hecho:SetWidth(30)
    c.cols = {}
    local wc = math.floor((ancho - 2 * PAD - 5 * 10) / 6)
    c.anchoCol = wc
    for k = 1, 6 do
      local col = CreateFrame("Frame", nil, c)
      col:SetSize(wc, 200)
      col:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + (k - 1) * (wc + 10), -49)
      col.aro = disco(col, 3, { 0.353, 0.318, 0.282 }); col.aro:SetSize(30, 30); col.aro:SetPoint("TOPLEFT", 0, 0)
      col.dentro = disco(col, 4, C.piedra); col.dentro:SetPoint("TOPLEFT", col.aro, "TOPLEFT", 2, -2); col.dentro:SetPoint("BOTTOMRIGHT", col.aro, "BOTTOMRIGHT", -2, 2)
      col.num = E.texto(col, nil, 14, C.tenue, "negrita"); col.num:SetPoint("CENTER", col.aro, "CENTER", 0, 0)
      if col.num.SetJustifyH then col.num:SetJustifyH("CENTER") end
      col.tapa = E.textura(col, "ARTWORK", 1, C.piedra2, 1) -- tapa el riel detras del rotulo (padding 0 6px)
      col.rot = E.rotulo(col, nil, C.tenue, 12); col.rot:SetPoint("LEFT", col.aro, "RIGHT", 14, 0)
      col.tapa:SetPoint("TOPLEFT", col.rot, "TOPLEFT", -6, 2); col.tapa:SetPoint("BOTTOMRIGHT", col.rot, "BOTTOMRIGHT", 6, -2)
      col.tapaNodo = E.textura(col, "ARTWORK", 0, C.piedra2, 1) -- el riel no cruza el nodo
      col.tapaNodo:SetPoint("TOPLEFT", col.aro, "TOPLEFT", 0, 0); col.tapaNodo:SetPoint("BOTTOMRIGHT", col.aro, "BOTTOMRIGHT", 0, 0)
      if col.tapaNodo.SetMask then pcall(col.tapaNodo.SetMask, col.tapaNodo, MASCARA) end
      col.cosas = {}
      for j = 1, 3 do
        local f = CreateFrame("Button", nil, col)
        f:SetSize(wc, 30)
        f.icono = E.icono(f, 24); f.icono:SetPoint("TOPLEFT", 0, -2)
        f.a = E.texto(f, nil, 13, C.texto, "negrita"); f.a:SetPoint("TOPLEFT", 32, 0); ajustar(f.a, wc - 32)
        f.b = E.texto(f, nil, 12, C.tenue, "medio"); f.b:SetPoint("TOPLEFT", f.a, "BOTTOMLEFT", 0, -2); ajustar(f.b, wc - 32)
        clicable(f, function(self) return rawget(self, "titulo") end, function(self) return rawget(self, "explica") end)
        col.cosas[j] = f
      end
      col.mas = E.texto(col, nil, 12, C.tenue, "medio")
      c.cols[k] = col
    end
    c.vacio = E.texto(c, nil, 13, C.tenue, "medio"); c.vacio:SetPoint("TOPLEFT", PAD, -96); ajustar(c.vacio, ancho - 2 * PAD)
    vp.camino = c

    -- ----- Cogelas antes de <mazmorra> -----
    local wm = math.floor((ancho - GAP) * 1.75 / 2.75 + 0.5)
    local q = E.tarjeta(vp)
    q:SetWidth(wm)
    q.eti = E.rotulo(q); q.eti:SetPoint("TOPLEFT", PAD, -16)
    q.desde = E.texto(q, nil, 12, C.tenue, "medio"); q.desde:SetPoint("TOPRIGHT", q, "TOPRIGHT", -PAD, -16)
    if q.desde.SetJustifyH then q.desde:SetJustifyH("RIGHT") end
    q.filas = {}
    local wq = math.floor((wm - 2 * PAD - 14) / 2)
    for k = 1, 6 do
      local f = CreateFrame("Button", nil, q)
      f:SetSize(wq, 36)
      local fila, colm = math.floor((k - 1) / 2), (k - 1) % 2
      f:SetPoint("TOPLEFT", q, "TOPLEFT", PAD + colm * (wq + 14), -40 - fila * 44)
      f.ret = retratoNPC(f, 34); f.ret:SetPoint("LEFT", 0, 0)
      f.nombre = E.texto(f, nil, 14, C.texto, "negrita"); f.nombre:SetPoint("TOPLEFT", 44, -1); ajustar(f.nombre, wq - 44)
      if f.nombre.SetWordWrap then f.nombre:SetWordWrap(false) end
      f.det = E.texto(f, nil, 12, C.tenue, "medio"); f.det:SetPoint("TOPLEFT", f.nombre, "BOTTOMLEFT", 0, -3); ajustar(f.det, wq - 44)
      if f.det.SetWordWrap then f.det:SetWordWrap(false) end
      clicable(f, function(self) return rawget(self, "titulo") end,
        function() return L("Clic: ruta hasta quien la da.", "Click: route to who gives it.") end)
      q.filas[k] = f
    end
    q.mas = E.texto(q, nil, 12, C.tenue, "medio")
    q.vacio = E.texto(q, nil, 13, C.tenue, "medio"); q.vacio:SetPoint("TOPLEFT", PAD, -42); ajustar(q.vacio, wm - 2 * PAD)
    vp.misiones = q

    -- ----- Profesiones -----
    local wp = ancho - wm - GAP
    local pr = E.tarjeta(vp)
    pr:SetWidth(wp)
    pr.eti = E.rotulo(pr, nil, C.oro); pr.eti:SetPoint("TOPLEFT", PAD, -16)
    pr.filas = {}
    for k = 1, 4 do
      local f = CreateFrame("Button", nil, pr)
      f:SetSize(wp - 2 * PAD, 36)
      f:SetPoint("TOPLEFT", pr, "TOPLEFT", PAD, -40 - (k - 1) * 46)
      f.icono = E.icono(f, 32); f.icono:SetPoint("LEFT", 0, 0)
      f.nombre = E.texto(f, nil, 14, C.texto, "negrita"); f.nombre:SetPoint("TOPLEFT", 42, -2)
      f.rango = E.texto(f, nil, 13, C.texto, "negrita"); f.rango:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
      if f.rango.SetJustifyH then f.rango:SetJustifyH("RIGHT") end
      f.barra = E.barra(f, wp - 2 * PAD - 42); f.barra:SetPoint("TOPLEFT", f, "TOPLEFT", 42, -24)
      clicable(f, function(self) return rawget(self, "titulo") end,
        function() return L("Clic: ver el paso a paso en Profesiones.", "Click: see the step by step in Professions.") end)
      pr.filas[k] = f
    end
    pr.vacio = E.texto(pr, nil, 13, C.tenue, "medio"); pr.vacio:SetPoint("TOPLEFT", PAD, -42); ajustar(pr.vacio, wp - 2 * PAD)
    vp.prof = pr
  end

  -- Hechizos del entrenador de tu clase entre nivel y nivel+6 que aun no sabes (la misma regla del tablero viejo)
  local function hechizosPronto(nivel, hasta)
    local clase = UnitClass and select(2, UnitClass("player"))
    local hechizos = (WowFHechizos and clase and WowFHechizos[clase]) or {}
    local tal = (WowFDatos and WowFDatos.clases and clase and WowFDatos.clases[clase] and WowFDatos.clases[clase].talentos) or {}
    local lista = {}
    for nombre, h in pairs(hechizos) do
      local n = type(h) == "table" and h[1] or nil
      if type(n) == "number" and n > 0 and n >= nivel and n <= (hasta or nivel + 6) and not tal[nombre] then
        local id = h[2]
        local sabe = false
        if id and IsSpellKnown then local ok, s = pcall(IsSpellKnown, id); sabe = ok and s and true or false end
        if not sabe then
          -- 12-oct (Andy: "que siempre sean los iconos de verdad"): icono real del hechizo; el libro solo si no hay ninguno
          local tex = WowF.iconoHechizo and (WowF.iconoHechizo(id) or WowF.iconoHechizo(nombre, clase))
          table.insert(lista, { nombre = nombre, nivel = n, id = id, tex = tex or "Interface\\Icons\\INV_Misc_Book_09" })
        end
      end
    end
    table.sort(lista, function(x, y) if x.nivel ~= y.nivel then return x.nivel < y.nivel end return x.nombre < y.nombre end)
    return lista
  end

  local function mazmorraRecomendada(p, nivel)
    local m
    if WowF.mazmorrasParaTi then
      local ok, lista = pcall(WowF.mazmorrasParaTi, p, nivel)
      local e = ok and type(lista) == "table" and lista[1]
      if e and e.estado ~= "pasada" then m = e.m end
    end
    for _, x in ipairs(WowFMazmorras or {}) do
      if not m and (not WowF.esMia or WowF.esMia(x)) and (x.h or 0) >= nivel then m = x end
    end
    return m
  end

  local function llenarMisionV(p, nivel)
    local m = vp.mision
    E.ponerRotulo(m.eti, anotar(L("Tu misión ahora", "Your mission now")))
    local g = WowF.planZonas and seguro(WowF.planZonas)
    local tramo, indice
    if type(g) == "table" and type(g.tramos) == "table" then
      for i, t in ipairs(g.tramos) do if not tramo and nivel <= (t.hasta or 0) then tramo, indice = t, i end end
    end
    local d = tramo and WowF.detalleTramo and seguro(WowF.detalleTramo, tramo, indice, g)
    if type(d) == "table" and d.z and d.z.n then
      local ya = nivel >= (tramo.desde or 0)
      poner(m.h2, WowF.yaTraducido(ya and L("Sigue subiendo en " .. d.z.n, "Keep leveling in " .. d.z.n) or L("Ve a " .. d.z.n, "Head to " .. d.z.n)))
      local quedan = math.max(0, (tramo.hasta or nivel) - nivel)
      local pueblo = type(d.pueblo) == "table" and (d.pueblo.n or d.pueblo.npc) or nil
      local es = "Niveles " .. tramo.desde .. "-" .. tramo.hasta .. " · te quedan " .. quedan .. (quedan == 1 and " nivel aquí" or " niveles aquí")
      local en = "Levels " .. tramo.desde .. "-" .. tramo.hasta .. " · " .. quedan .. (quedan == 1 and " level left here" or " levels left here")
      if tonumber(d.n) then es = es .. " · " .. d.n .. " misiones"; en = en .. " · " .. d.n .. " quests" end
      if pueblo then es = es .. " · pueblo: " .. pueblo; en = en .. " · town: " .. pueblo end
      poner(m.sub, WowF.yaTraducido(L(es, en)))
      textoBoton(m.ir, L("Llévame  ›", "Take me  ›"))
      m.ir:SetScript("OnClick", function() if WowF.irAZona then WowF.irAZona(tramo) end end)
      m.ir:Show()
    else
      poner(m.h2, L("Sigue subiendo", "Keep leveling"))
      poner(m.sub, WowF.yaTraducido(L("Zona: ", "Zone: ") .. SIN()))
      m.ir:Hide()
    end
    if WowF.rehacerPlanZonas then
      textoBoton(m.rehacer, L("¿Cambiaste de zona? Rehacer aquí", "Changed zones? Rebuild here"))
      m.rehacer:SetScript("OnClick", function() WowF.rehacerPlanZonas() end)
      m.rehacer:ClearAllPoints()
      -- 12-oct (Andy: se salia de la tarjeta): al lado del boton solo si cabe; si no, debajo de el
      local libre = (tonumber(m:GetWidth()) or 0) - 2 * PAD - (tonumber(m.ir:GetWidth()) or 0) - 18
      -- 12-oct (Andy, 2.a vez: debajo del boton quedaba sobre el borde de la tarjeta): si va debajo, el boton sube para que los dos queden dentro
      m.ir:ClearAllPoints()
      if m.ir:IsShown() and (tonumber(m.rehacer:GetWidth()) or 0) <= libre then
        m.ir:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", PAD, 22)
        m.rehacer:SetPoint("LEFT", m.ir, "RIGHT", 18, 0)
      elseif m.ir:IsShown() then
        local hr = math.max(22, tonumber(m.rehacer:GetHeight()) or 22)
        m.ir:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", PAD, 18 + hr + 6)
        m.rehacer:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", PAD - 4, 16)
      else
        m.ir:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", PAD, 22)
        m.rehacer:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", PAD, 22)
      end
      m.rehacer:Show()
    else m.rehacer:Hide() end
  end

  local function llenarAprende(nivel)
    local a = vp.aprende
    E.ponerRotulo(a.eti, anotar(L("Lo que aprendes pronto", "What you learn soon")))
    local lista = hechizosPronto(nivel)
    for k, f in ipairs(a.filas) do
      local h = lista[k]
      if h then
        local ya = h.nivel <= nivel
        f.icono:poner(h.tex, ya and "verde" or "gris", not ya)
        poner(f.nombre, WowF.yaTraducido(h.nombre))
        poner(f.det, WowF.yaTraducido(ya and (E.cod.verde .. L("ya puedes", "available now") .. "|r" .. E.cod.tenue .. L(" · entrenador de clase", " · class trainer") .. "|r")
          or L("nivel " .. h.nivel .. " · entrenador de clase", "level " .. h.nivel .. " · class trainer")))
        f.titulo = h.nombre
        f.accion = WowF.irAlEntrenadorClase and function() WowF.irAlEntrenadorClase() end or nil
        f:Show()
      else f:Hide() end
    end
    if #lista == 0 then
      poner(a.vacio, L("Nada nuevo de tu entrenador en los próximos niveles.", "Nothing new from your trainer in the next levels."))
      a.vacio:Show()
    else a.vacio:Hide() end
  end

  local function llenarMazmorraV(p, nivel, m)
    local z = vp.maz
    z.titulo = m and m.n or nil
    if not m then
      E.ponerRotulo(z.eti, anotar(L("Mazmorra", "Dungeon")))
      poner(z.h3, L("Ninguna por ahora", "None for now"))
      poner(z.sub, SIN())
      for _, c in ipairs(z.cifras) do c:Hide() end
      z.accion = nil; z.ver:Hide()
      return nil
    end
    E.ponerRotulo(z.eti, anotar(L("Mazmorra al nivel " .. m.d, "Dungeon at level " .. m.d)))
    poner(z.h3, WowF.yaTraducido(m.n))
    local zona = WowF.nombreZona and m.m and seguro(WowF.nombreZona, m.m)
    local ideal = math.floor(((m.d or 0) + (m.h or 0)) / 2)
    poner(z.sub, WowF.yaTraducido((type(zona) == "string" and zona ~= "" and (zona .. " · ") or "") .. L("ideal al " .. ideal, "best at " .. ideal)))
    local piezas = WowF.piezasParaTi and seguro(WowF.piezasParaTi, p, m.i)
    local grupos = WowF.misionesFueraDe and seguro(WowF.misionesFueraDe, m)
    local fuera = 0
    if type(grupos) == "table" then for _, g in ipairs(grupos) do fuera = fuera + #(g.q or {}) end end
    local cifras = { { type(piezas) == "table" and #piezas or 0, L("Piezas", "Items") }, { #(m.q or {}), L("Misiones", "Quests") }, { fuera, L("Fuera", "Outside") } }
    local x = PAD
    for k, c in ipairs(z.cifras) do
      c:poner(cifras[k][1], cifras[k][2])
      anotar(tostring(cifras[k][1])); anotar(E.mayus(cifras[k][2]))
      c:ClearAllPoints(); c:SetPoint("TOPLEFT", z.sub, "BOTTOMLEFT", x - PAD, -12)
      local w = c.GetWidth and tonumber(c:GetWidth()) or 60
      x = x + (type(w) == "number" and w or 60) + 22
      c:Show()
    end
    z.accion = function() if WowF.irAMazmorra then WowF.irAMazmorra(m) end end
    textoBoton(z.ver, L("Ver la mazmorra", "See the dungeon"), true)
    z.ver:SetScript("OnClick", function()
      if WowF.diarioElegir then pcall(WowF.diarioElegir, m.n, "resumen") end
      pestana = "Mazmorras"; dibujar(); irArriba()
    end)
    z.ver:Show()
    return m, grupos
  end

  -- Lo que pasa en cada nivel (para "Tu camino"): zona, talento, rama, hechizos, mazmorra, profesion, pieza, hito
  local PRIO = { zona = 1, talento = 2, rama = 3, hechizo = 4, mazmorra = 5, prof = 6, equipo = 7, hito = 8 }
  local function cosasPorNivel(p, nivel, hasta, mRec)
    local por = {}
    local function add(n, c) if n >= nivel and n <= hasta then por[n] = por[n] or {}; table.insert(por[n], c) end end
    local primerTalento = true
    local ir = function(cual) return function() pestana = cual; dibujar(); irArriba() end end
    for _, e in ipairs(p.eventos or {}) do
      local n, tipo = tonumber(e[1]) or 0, e[2]
      if tipo == "talento" then
        local texto = tostring(e[3]):gsub(" · clave", "")
        local nombre, r, tot = texto:match("^(.-) %((%d+)/(%d+)%)")
        -- 12-oct: icono real del talento (WowF.iconoHechizo por nombre: campo 6 del arbol o el spellId en los datos de Forever)
        add(n, { tipo = "talento", tex = (nombre and WowF.iconoHechizo and WowF.iconoHechizo(nombre)) or ((e.ic and e.ic ~= "") and ("Interface\\Icons\\" .. e.ic)) or ICONO.talento,
          a = nombre and (nombre .. " " .. r .. "/" .. tot) or texto, b = primerTalento and L("primer talento", "first talent") or L("talento", "talent"),
          accion = ir("Talentos"), explica = L("Clic: verlo en Talentos.", "Click: see it in Talents.") })
        primerTalento = false
      elseif tipo == "rama" then
        add(n, { tipo = "rama", tex = ICONO.rama, a = tostring(e[3]), b = L("rama", "spec"), accion = ir("Talentos") })
      elseif tipo == "zona" then
        local d = e.tramo and WowF.detalleTramo and seguro(WowF.detalleTramo, e.tramo, e.indice, WowF.planZonas and seguro(WowF.planZonas))
        local t = e.tramo
        if type(d) == "table" and d.z and d.z.n and t then
          add(n, { tipo = "zona", tex = ICONO.zona, a = d.z.n, b = L("zona · niveles " .. t.desde .. "-" .. t.hasta, "zone · levels " .. t.desde .. "-" .. t.hasta),
            accion = WowF.irAZona and function() WowF.irAZona(t) end or nil, explica = L("Clic: ruta a la zona.", "Click: route to the zone.") })
        end
      elseif tipo == "prof" then
        local partes = trozos(e[3])
        local primero = partes[1] or ""
        local topeN = tonumber(primero:match("^Tope de profesion: (%d+)%.") or "")
        if topeN then
          add(n, { tipo = "prof", tex = ICONO.prof, a = L("Profesiones: tope " .. topeN, "Professions: cap " .. topeN), b = RANGO[topeN] or "",
            accion = function() profTope = topeN; pestana = "Profesiones"; subActiva.Profesiones = "mias"; dibujar(); irArriba() end,
            explica = L("Nivel de personaje que pide: aún no disponible en WoW Forever; se actualizará.", "Character level required: not available yet in WoW Forever; will be updated.") })
        end
      elseif tipo == "equipo" then
        local v = WowF.valeLaPena and seguro(WowF.valeLaPena, e)
        if v == "si" then
          local nombre = ((trozos(e[3])[1] or ""):match("^(.-) %(") or trozos(e[3])[1] or "?")
          -- 12-oct: icono del propio objeto (el cliente por id, luego los datos del plan); el engranaje solo si no hay ninguno
          add(n, { tipo = "equipo", tex = (WowF.iconoObjeto and WowF.iconoObjeto(e.i)) or ((e.ic and e.ic ~= "") and ("Interface\\Icons\\" .. e.ic)) or ICONO.prof, a = nombre, b = L("fabrícatela, vale la pena", "craft it, worth it"),
            accion = ir("Equipo") })
        end
      end
    end
    -- Hechizos del entrenador (agrupados por nivel)
    local porN = {}
    for _, h in ipairs(hechizosPronto(nivel, hasta)) do porN[h.nivel] = porN[h.nivel] or {}; table.insert(porN[h.nivel], h) end
    for n, l in pairs(porN) do
      local b
      if n <= nivel then b = L("ya puedes", "available now")
      elseif #l == 2 then b = L("y ", "and ") .. l[2].nombre
      elseif #l > 2 then b = L("y " .. (#l - 1) .. " más", "and " .. (#l - 1) .. " more")
      else b = L("hechizo nuevo", "new spell") end
      add(n, { tipo = "hechizo", tex = l[1].tex, a = l[1].nombre, b = b, verde = n <= nivel,
        accion = WowF.irAlEntrenadorClase and function() WowF.irAlEntrenadorClase() end or nil, explica = L("Clic: ruta a tu entrenador de clase.", "Click: route to your class trainer.") })
    end
    -- La mazmorra recomendada: cuando se abre y su nivel ideal
    if mRec then
      local ideal = math.floor(((mRec.d or 0) + (mRec.h or 0)) / 2)
      local accion = function() if WowF.irAMazmorra then WowF.irAMazmorra(mRec) end end
      local ic = ICONO.mazmorra
      if (mRec.d or 0) >= nivel then add(mRec.d, { tipo = "mazmorra", tex = ic, a = mRec.n, b = L("se abre la mazmorra", "dungeon opens"), accion = accion }) end
      if ideal ~= mRec.d then add(ideal, { tipo = "mazmorra", tex = ic, a = mRec.n, b = L("nivel ideal", "best level"), accion = accion }) end
    end
    for _, l in pairs(por) do table.sort(l, function(x, y) return (PRIO[x.tipo] or 9) < (PRIO[y.tipo] or 9) end) end
    return por
  end

  local function llenarCamino(p, nivel, mRec)
    local c = vp.camino
    local hasta = nivel + 7
    local por = cosasPorNivel(p, nivel, hasta, mRec)
    local niveles = { nivel }
    for n = nivel + 1, hasta do if por[n] and #niveles < 6 then table.insert(niveles, n) end end
    E.ponerRotulo(c.eti, anotar(L("Tu camino · niveles " .. niveles[1] .. " a " .. niveles[#niveles], "Your path · levels " .. niveles[1] .. " to " .. niveles[#niveles])))
    -- 12-oct: el texto de los chips se pone al PINTAR (se creaban con el idioma de antes de leer la DB: en ingles salian "AHORA", "YA PUEDES")
    local ley = { { L("Ahora", "Now"), "brasa" }, { L("Ya puedes", "Available"), "verde" }, { L("Recomendado", "Recommended"), "oro" }, { L("Después", "Later"), "gris" } }
    for k, ch in ipairs(c.chips) do if ley[k] and ch.poner then ch:poner(ley[k][1], ley[k][2]) end end
    for _, ch in ipairs(c.chips) do anotar(E.mayus(ch.texto:GetText() or "")) end
    local tm = E.tema()
    if c.hecho.SetColorTexture then c.hecho:SetColorTexture(tm.ahora[1], tm.ahora[2], tm.ahora[3], 1) end
    local altoMax = 0
    local hayAlgo = false
    for k, col in ipairs(c.cols) do
      local n = niveles[k]
      if n then
        local ahora = k == 1
        local oro = not ahora and mRec and n == mRec.d
        local borde = ahora and tm.ahoraBorde or (oro and C.oro) or { 0.353, 0.318, 0.282 }
        local fondo = ahora and tm.ahora or C.piedra
        local letra = ahora and tm.ahoraLetra or (oro and C.oro) or C.tenue
        if col.aro.SetColorTexture then col.aro:SetColorTexture(borde[1], borde[2], borde[3], 1) end
        if col.dentro.SetColorTexture then col.dentro:SetColorTexture(fondo[1], fondo[2], fondo[3], 1) end
        col.num:SetTextColor(letra[1], letra[2], letra[3], 1)
        poner(col.num, tostring(n))
        E.ponerRotulo(col.rot, anotar(ahora and L("Ahora", "Now") or L("Nivel " .. n, "Level " .. n)))
        local rc = ahora and tm.ahora or (oro and C.oro) or C.tenue
        col.rot:SetTextColor(rc[1], rc[2], rc[3], 1)
        local y = -40
        local lista = por[n] or {}
        for j, f in ipairs(col.cosas) do
          local x = lista[j]
          if x then
            hayAlgo = true
            f.icono:poner(x.tex, x.verde and "verde" or nil)
            poner(f.a, WowF.yaTraducido(x.a or ""))
            poner(f.b, WowF.yaTraducido(x.b or ""))
            if ahora then f.a:SetTextColor(C.texto[1], C.texto[2], C.texto[3], 1) else f.a:SetTextColor(0.851, 0.816, 0.761, 1) end
            f.titulo = x.a; f.explica = x.explica; f.accion = x.accion
            local h = math.max(28, altoDe(f.a, 15) + 2 + altoDe(f.b, 14))
            f:SetHeight(h)
            f:ClearAllPoints(); f:SetPoint("TOPLEFT", col, "TOPLEFT", 0, y)
            y = y - h - 10
            f:Show()
          else f:Hide() end
        end
        if #lista > #col.cosas then
          poner(col.mas, L("+" .. (#lista - #col.cosas) .. " más", "+" .. (#lista - #col.cosas) .. " more"))
          col.mas:ClearAllPoints(); col.mas:SetPoint("TOPLEFT", col, "TOPLEFT", 32, y + 4); col.mas:Show()
          y = y - 16
        else col.mas:Hide() end
        altoMax = math.max(altoMax, -y)
        col:Show()
      else col:Hide() end
    end
    if not hayAlgo then poner(c.vacio, SIN()); c.vacio:Show() else c.vacio:Hide() end
    local alto = 49 + math.max(altoMax, hayAlgo and 0 or 80) + 6
    c:SetHeight(math.max(160, alto))
    return math.max(160, alto)
  end

  local function llenarMisionesV(m, grupos)
    local q = vp.misiones
    -- 11-oct (Andy: "esto no sé qué es"): el título dice que son misiones DE la mazmorra que se piden fuera
    E.ponerRotulo(q.eti, anotar(m and L("Misiones de " .. m.n .. ": pídelas antes de entrar", "Quests for " .. m.n .. ": get them before going in") or L("Misiones de mazmorra: pídelas antes de entrar", "Dungeon quests: get them before going in")))
    local lista = {}
    if type(grupos) == "table" then for _, g in ipairs(grupos) do for _, x in ipairs(g.q or {}) do table.insert(lista, { g = g, q = x }) end end end
    local desde
    for _, e in ipairs(lista) do local nv = tonumber(e.q.nivel); if nv and (not desde or nv < desde) then desde = nv end end
    if desde then poner(q.desde, L("desde nivel " .. desde .. " · clic: te llevo", "from level " .. desde .. " · click: take me")); q.desde:Show() else q.desde:Hide() end
    local ultimo = 0
    for k, f in ipairs(q.filas) do
      local e = lista[k]
      if e then
        local nombre = tostring(e.q.n or e.q[1] or "?")
        local zona = WowF.nombreZona and e.g.m and seguro(WowF.nombreZona, e.g.m)
        poner(f.nombre, WowF.yaTraducido(nombre))
        poner(f.det, WowF.yaTraducido((e.g.quien and (e.g.quien .. (type(zona) == "string" and zona ~= "" and " · " or "")) or "") .. (type(zona) == "string" and zona or "")))
        local okR = rawget(f.ret, "opts") ~= nil or true
        if okR then pcall(f.ret.poner, f.ret, WowF.marcoRetrato and { npc = e.q.npc, nombre = e.g.quien, icono = "Interface\\Icons\\INV_Scroll_01" } or "Interface\\Icons\\INV_Scroll_01") end
        f.titulo = nombre
        local g = e.g
        f.accion = WowF.irAMision and function() WowF.irAMision(g) end or nil
        f:Show(); ultimo = k
      else f:Hide() end
    end
    if #lista > #q.filas then
      poner(q.mas, L("y " .. (#lista - #q.filas) .. " más en la pestaña Mazmorras", "and " .. (#lista - #q.filas) .. " more in the Dungeons tab"))
      q.mas:ClearAllPoints(); q.mas:SetPoint("TOPLEFT", q, "TOPLEFT", PAD, -40 - math.ceil(ultimo / 2) * 44); q.mas:Show()
    else q.mas:Hide() end
    if #lista == 0 then
      poner(q.vacio, m and L("Esta mazmorra no tiene misiones que se cojan fuera.", "This dungeon has no quests picked up outside.") or SIN())
      q.vacio:Show()
    else q.vacio:Hide() end
    local alto = #lista == 0 and 90 or (40 + math.ceil(ultimo / 2) * 44 + (#lista > #q.filas and 20 or 0) + 8)
    return alto
  end

  local function llenarProfV()
    local pr = vp.prof
    E.ponerRotulo(pr.eti, anotar(L("Profesiones", "Professions")))
    local lista = WowF.profesiones and seguro(WowF.profesiones)
    if type(lista) ~= "table" then lista = {} end
    local n = 0
    for k, f in ipairs(pr.filas) do
      local x = lista[k]
      if x then
        n = k
        f.icono:poner(ICONO[x.id] or (WowF.ICONO_PROF and WowF.ICONO_PROF[x.id]) or (x.id == 356 and "Interface\\Icons\\Trade_Fishing") or ICONO.prof)
        local nombre = x.en or x.nombre or "?"
        poner(f.nombre, WowF.yaTraducido(nombre))
        poner(f.rango, tostring(x.rango or 0) .. "/" .. tostring(x.maximo or 0))
        f.barra:poner(x.rango or 0, x.maximo or 0)
        f.titulo = nombre
        f.accion = function() pestana = "Profesiones"; subActiva.Profesiones = "mias"; dibujar(); irArriba() end
        f:Show()
      else f:Hide() end
    end
    if n == 0 then
      poner(pr.vacio, L("Aún no tienes profesiones. Revisa cuáles te convienen en la pestaña Profesiones.", "No professions yet. See which ones suit you in the Professions tab."))
      pr.vacio:Show()
    else pr.vacio:Hide() end
    return n == 0 and 90 or (40 + n * 46)
  end

  function WowF.vistaProgreso(p, hoja, ancho, ctx)
    if not vp then crear(hoja, ancho or ANCHO_HOJA) end
    textos = {}
    local nivel = nivelActual()
    pcall(llenarMisionV, p, nivel)
    pcall(llenarAprende, nivel)
    local mRec = mazmorraRecomendada(p, nivel)
    local ok, m, grupos = pcall(llenarMazmorraV, p, nivel, mRec)
    if not ok then m, grupos = nil, nil end
    local okC, altoC = pcall(llenarCamino, p, nivel, mRec)
    altoC = okC and tonumber(altoC) or 240
    local okQ, altoQ = pcall(llenarMisionesV, m, grupos)
    local okP, altoP = pcall(llenarProfV)
    local y3 = 236 + GAP + altoC + GAP
    local alto3 = math.max(okQ and altoQ or 90, okP and altoP or 90, ((ctx and ctx.altoVisible) or 668) - y3)
    for _, t in ipairs({ vp.misiones, vp.prof }) do t:SetHeight(alto3) end
    vp.misiones:ClearAllPoints(); vp.misiones:SetPoint("TOPLEFT", vp, "TOPLEFT", 0, -y3)
    vp.prof:ClearAllPoints(); vp.prof:SetPoint("TOPRIGHT", vp, "TOPRIGHT", 0, -y3)
    local alto = y3 + alto3
    vp:SetHeight(alto)
    local copia = {}
    for i, s in ipairs(textos) do copia[i] = s end
    return vp, alto, copia
  end
  WowF.libroVistaProgreso = function() return vp end
end

-- ----- Progreso: todo lo que te toca en cada nivel, junto (donde subir, talentos, mazmorras, profesiones, que fabricarte) -----
local ORDEN_TIPO = { zona = 1, mazmorra = 2, rama = 3, talento = 4, hito = 5, prof = 6, equipo = 7 }
CONTENIDO.Progreso = function(p)
  llenarTablero(p)
  if WowF.rehacerPlanZonas then
    item({ texto = WowF.yaTraducido(VERDE .. L("Zonas: rehacer desde donde estoy", "Zones: rebuild from where I am") .. "|r"),
      sub = WowF.yaTraducido(GRIS .. L("Las zonas son opcionales. Si te fuiste a otro sitio, el plan sigue desde aqui.", "Zones are optional. If you went elsewhere, the plan continues from here.") .. "|r"),
      icono = ICONO.zona, chico = true, accion = function() WowF.rehacerPlanZonas() end })
  end
  separador()
  local lista = {}
  for _, e in ipairs(p.eventos or {}) do
    if e[2] ~= "equipo" then table.insert(lista, e)
    else local v = WowF.valeLaPena(e); if v == "si" or v == "normal" then table.insert(lista, e) end end
  end
  for _, m in ipairs(WowFMazmorras or {}) do
    if not WowF.esMia or WowF.esMia(m) then table.insert(lista, { math.floor((m.d + m.h) / 2), "mazmorra", m.n, maz = m }) end
  end
  table.sort(lista, function(a, b)
    if a[1] ~= b[1] then return a[1] < b[1] end
    return (ORDEN_TIPO[a[2]] or 9) < (ORDEN_TIPO[b[2]] or 9)
  end)
  local ir = function(cual) return function() pestana = cual; dibujar() end end
  porNivel(lista, function(e, pasado)
    local c = pasado and GRIS or BLANCO
    local partes = trozos(e[3])
    if e[2] == "zona" then
      local d = e.tramo and WowF.detalleTramo and WowF.detalleTramo(e.tramo, e.indice, WowF.planZonas())
      if d then
        local t = e.tramo
        item({ texto = WowF.yaTraducido((pasado and GRIS or VERDE) .. L("Sube en: ", "Level in: ") .. "|r" .. c .. d.z.n .. "|r" .. GRIS .. "  (" .. L("niveles ", "levels ") .. t.desde .. "-" .. t.hasta .. ", " .. L("opcional", "optional") .. ")|r"),
          sub = WowF.yaTraducido(GRIS .. L(d.n .. " misiones · pueblo: " .. (d.pueblo.n or d.pueblo.npc) .. " · clic: ruta (raton: por que)",
            d.n .. " quests · town: " .. (d.pueblo.n or d.pueblo.npc) .. " · click: route (hover: why)") .. "|r"),
          icono = ICONO.zona, ayuda = WowF.ayudaTramo(t, e.indice), accion = function() WowF.irAZona(t) end })
      else
        item({ texto = (pasado and GRIS or VERDE) .. "Sube en: |r" .. c .. tostring(e[3]) .. "|r", icono = ICONO.zona })
      end
    elseif e[2] == "mazmorra" then
      local m = e.maz
      local piezas = (WowF.piezasParaTi and WowF.piezasParaTi(p, m.i)) or (p.botin or {})[m.i] or {}
      item({ texto = (pasado and GRIS or ORO) .. "Mazmorra: " .. m.n .. "|r" .. GRIS .. "  (niveles " .. m.d .. "-" .. m.h .. ")|r",
        sub = GRIS .. (#piezas > 0 and (#piezas .. " piezas para ti") or "sin piezas para tu plan") .. "  ·  clic: como llegar (ruta paso a paso)|r",
        icono = ICONO.mazmorra, accion = function() if WowF.irAMazmorra then WowF.irAMazmorra(m) elseif WowF.marcar then WowF.marcar(m) end end })
    elseif e[2] == "talento" then
      local texto = tostring(e[3]):gsub(" · clave", "")
      local nombre, puntos = texto:match("^(.-) %((%d+)/%d+%)")
      item({ texto = (pasado and GRIS or CELESTE) .. "Talento: |r" .. c .. texto .. "|r", icono = ((e.ic and e.ic ~= "") and ("Interface\\Icons\\" .. e.ic)) or (WowF.iconoHechizo and WowF.iconoHechizo(nombre or texto)) or ICONO.talento, chico = true, accion = ir("Talentos"),
        ayuda = ayudaTalento(p, nombre or texto, puntos) })
    elseif e[2] == "rama" then
      item({ texto = (pasado and GRIS or NARANJA) .. tostring(e[3]) .. "|r", icono = ICONO.rama, accion = ir("Talentos") })
    elseif e[2] == "prof" then
      local primero = table.remove(partes, 1) or ""
      -- 9-oct (cero datos de Classic): el nivel en que sale este tope es de Classic (solo ordena); no se dice "ya puedes"
      local topeN = tonumber(primero:match("^Tope de profesion: (%d+)%.") or "")
      local sub = GRIS .. "clic: ver el paso a paso|r"
      if topeN then
        primero = L("Profesiones: tope " .. topeN .. " (" .. (RANGO[topeN] or "") .. ")", "Professions: cap " .. topeN .. " (" .. (RANGO[topeN] or "") .. ")")
        sub = WowF.yaTraducido(GRIS .. L("Nivel de personaje que pide: aun no disponible en Forever; se actualizara. Clic: ver el paso a paso.",
          "Character level required: not available yet in Forever; will be updated. Click: see the step by step.") .. "|r")
      end
      local textoProf = (pasado and GRIS or NARANJA) .. primero .. "|r"
      if topeN then textoProf = WowF.yaTraducido(textoProf) end
      item({ texto = textoProf, sub = sub, icono = ICONO.prof, chico = true,
        accion = function() profTope = topeN; pestana = "Profesiones"; subActiva.Profesiones = "mias"; dibujar() end })
    elseif e[2] == "equipo" then
      local _, porque = WowF.valeLaPena(e)
      local nombre = (partes[1] or ""):match("^(.-) %(") or partes[1] or "?"
      item({ texto = (pasado and GRIS or VERDE) .. "Fabricate: |r" .. colorCalidad(e.q or 1) .. nombre .. "|r", sub = GRIS .. porque .. "|r", icono = icono(e.ic, e.i), objeto = e.i, chico = true })
    else
      local primero = table.remove(partes, 1) or ""
      item({ texto = c .. primero .. "|r", sub = #partes > 0 and (GRIS .. table.concat(partes, "\n") .. "|r") or nil, icono = ICONO.hito, chico = true })
    end
  end)
end

-- ----- Rotacion y Macros (wowF_Rotacion.lua) -----
local NAV_COMBATE = function() return { { "Rotacion", L("Rotación", "Rotation") }, { "Macros", "Macros" } } end
CONTENIDO.Rotacion = function(p)
  table.insert(filas, { tipo = "nav", opciones = NAV_COMBATE() })
  if WowF.contenidoRotacion then WowF.contenidoRotacion(p, cab, nota, item, separador) else nota(GRIS .. "Falta wowF_Rotacion.lua. Reinstala el addon.|r") end
end
CONTENIDO.Macros = function(p)
  table.insert(filas, { tipo = "nav", opciones = NAV_COMBATE() })
  if WowF.contenidoMacros then WowF.contenidoMacros(p, cab, nota, item, separador) else nota(GRIS .. "Falta wowF_Rotacion.lua. Reinstala el addon.|r") end
end
-- 7-oct: BiS y pre-BiS de nivel 30 (wowF_BiSGuia.lua; boton "BiS 30" de arriba y /wowf bis)
CONTENIDO["BiS 30"] = function(p)
  if WowF.contenidoBiS then WowF.contenidoBiS(p, cab, nota, item, separador) else nota(GRIS .. L("Falta wowF_BiSGuia.lua. Reinstala el addon.", "wowF_BiSGuia.lua is missing. Reinstall the addon.") .. "|r") end
end
-- 19-oct: Rares (la vista de tarjetas es wowF_VistaRares.lua; esto es el respaldo de texto)
CONTENIDO.Rares = function(p)
  if WowF.listaRaresTexto then WowF.listaRaresTexto(cab, nota) else nota(GRIS .. L("Falta wowF_VistaRares.lua. Reinstala el addon.", "wowF_VistaRares.lua is missing. Reinstall the addon.") .. "|r") end
end

-- ===================== Vistas nuevas (11-oct, rediseno por tarjetas; contrato en CONTRATO.md) =====================
-- Cada pestana puede tener su vista (WowF.vistaX, en su archivo). Si existe y no da error, el contenido viejo se sigue armando
-- (oculto: lo leen libroTexto/libroClic/libroAyudas) y se pinta la vista; si no, se pinta el contenido viejo como siempre.
local VISTA = { Progreso = "vistaProgreso", Talentos = "vistaTalentos", Rotacion = "vistaRotacion", Macros = "vistaMacros",
  Profesiones = "vistaProfesiones", Equipo = "vistaEquipo", ["BiS 30"] = "vistaBiS", Rares = "vistaRares" }
local marcosVista = {}
local function ocultarVistas() for m in pairs(marcosVista) do pcall(m.Hide, m) end end
local ctxVista = { altoVisible = 668, L = L }
ctxVista.redibujar = function() if WowF.libroRedibujar then WowF.libroRedibujar() end end
ctxVista.ponerSub = function(clave)
  if COMBATE[pestana] and COMBATE[clave] then pestana = clave else subActiva[pestana] = clave end
  dibujar(); irArriba()
end
ctxVista.irA = function(cual, sub)
  if cual == "Combate" then cual = ultimaCombate end
  -- 13-oct (Andy): "Ver en Profesiones" desde Equipo abre directo la sub-pestana de fabricarte equipo
  if CONTENIDO[cual] then pestana = cual; if sub then subActiva[cual] = sub end; dibujar(); irArriba() end
end
local function ponerVista(p)
  local nombre = VISTA[pestana]
  local fn = nombre and WowF[nombre]
  if type(fn) ~= "function" then return end
  ctxVista.pestana = pestana
  ctxVista.sub = COMBATE[pestana] and pestana or subActiva[pestana]
  local ok, marco, alto, textos = pcall(fn, p, hoja, ANCHO_HOJA, ctxVista)
  if not ok then WowF.libroErrorVista = pestana .. ": " .. tostring(marco); return end
  if type(marco) ~= "table" then return end
  marcosVista[marco] = true
  local ultimaSiempre = 0
  for i, f in ipairs(filas) do
    if f.siempre then ultimaSiempre = i else f.oculta = true end
  end
  table.insert(filas, ultimaSiempre + 1, { tipo = "bloque", marco = marco, alto = tonumber(alto) or 10, textos = textos, vista = nombre })
  if pestana == "Equipo" then figura:Hide(); arriba = 0 end -- la vista trae su propio muneco
end

-- Fondo de ambiente por pestana (fileDataID del cliente; si no carga, piedra lisa). La misma textura no se vuelve a poner.
local CARGA_CLASE = { SHAMAN = 1405662, HUNTER = 1379024, WARLOCK = 1394926, PRIEST = 1412500, DRUID = 1417745, MAGE = 1445353,
  WARRIOR = 1454826, PALADIN = 1454533, ROGUE = 236059 }
local function continente()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then return nil end
  local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
  id = ok and tonumber(id) or nil
  for _ = 1, 8 do
    if not id or id == 0 then return nil end
    local ok2, info = pcall(C_Map.GetMapInfo, id)
    if not ok2 or type(info) ~= "table" then return nil end
    if info.mapType == 2 then return id end
    id = info.parentMapID
  end
  return nil
end
local function ponerFondo(p)
  if not ambiente then return end
  -- 11-oct: arte por pestana, clase/rama, raza, profesion y mapa (wowF_Fondos.lua); lo de abajo queda solo de respaldo
  if WowF.fondoPestana then
    local ok, hecho = pcall(WowF.fondoPestana, pestana, p, ambiente)
    if ok and hecho then return end
  end
  local faccion = E.tema().faccion
  local tx, coords
  if pestana == "Progreso" then
    local c = continente()
    if c == 1414 then tx = 7963779 elseif c == 1415 then tx = 7963776
    else tx = faccion == "Alliance" and 7963776 or 7963779 end
  elseif pestana == "Talentos" or COMBATE[pestana] then
    local clase = UnitClass and select(2, UnitClass("player"))
    tx = CARGA_CLASE[clase or ""]
  elseif pestana == "Profesiones" then tx = faccion == "Alliance" and 7963781 or 1086951
  elseif pestana == "Equipo" then tx = 131824
  elseif pestana == "BiS 30" or pestana == "Rares" then tx = 131838
  elseif pestana == "Mazmorras" then
    local ok, lista = false, nil
    if WowF.mazmorrasParaTi then ok, lista = pcall(WowF.mazmorrasParaTi, p, nivelActual()) end
    if ok and type(lista) == "table" then
      for _, e in ipairs(lista) do
        if type(e) == "table" and e.estado ~= "pasada" and e.m then
          local d = WowFDiario and WowFDiario[e.m.i]
          if d and d.carga then tx, coords = d.carga, { 0, 1, 0.3, 0.55 }
          elseif d and d.fondo then tx, coords = d.fondo, { 0, 0.78125, 0.12, 0.38 } end
          break
        end
      end
    end
    tx = tx or 131838
  end
  if not tx or not ambiente:poner(tx, coords) then
    -- sin textura (o no cargo): en Mazmorras la de respaldo; si tampoco, piedra lisa (poner/quitar ya la ocultan)
    if pestana == "Mazmorras" and tx ~= 131838 then ambiente:poner(131838) else ambiente:quitar() end
  end
end

-- ===================== Dibujar =====================
dibujar = function()
  local p = WowF.armarPlan and WowF.armarPlan()
  local clase = UnitClass and select(2, UnitClass("player"))
  -- 11-oct (rediseno "hibrido"): cintas arriba (la abierta, roja y larga) y estandarte con tu personaje a la izquierda
  if COMBATE[pestana] then ultimaCombate = pestana end
  colocarCintas()
  actualizarEstandarte(p)
  WowFExportarDB = WowFExportarDB or {}
  WowFExportarDB.libroPestana = pestana
  WowFExportarDB.libroCombate = ultimaCombate
  botonNotas:SetText(L("Novedades", "What's new"))
  do local fsb = botonNotas.GetFontString and botonNotas:GetFontString(); if fsb and fsb.SetAlpha then fsb:SetAlpha(0) end end
  if WowF.abrirNotas then botonNotas:Show() else botonNotas:Hide() end
  if WowF.hayRutaActiva and WowF.hayRutaActiva() then botonLimpiar:Show() else botonLimpiar:Hide() end
  -- Icono del entrenador de clase (lo crea wowF_EntrenadorClase.lua): en el estandarte, al lado del "?"
  local bc = WowF.botonEntrenadorClaseLibro
  if bc and bc.ClearAllPoints then
    if bc.SetParent then pcall(bc.SetParent, bc, est) end
    bc:ClearAllPoints(); bc:SetSize(22, 22)
    bc:SetPoint("LEFT", botonLeyenda, "RIGHT", 6, 0)
  end
  tablero:Hide()
  ocultarVistas()
  filas = {}
  arriba = 0
  figura:Hide()
  if WowF.diagramaOcultar then WowF.diagramaOcultar() end
  if WowF.diarioOcultar then WowF.diarioOcultar() end
  if not p then nota(GRIS .. "Sin datos del plan para esta clase" .. (clase and (" (" .. clase .. ")") or "") .. ". Reinstala el addon Forever Leveling Guide.|r")
  else CONTENIDO[pestana](p) end
  -- 11-oct (rediseno por tarjetas): sin secciones plegables (ni +/-, ni "Abrir todo", ni contador). Todo queda en filas
  -- (las pruebas lo leen); aqui solo se decide que se ve: la sub-pestana abierta y, si la pestana tiene vista nueva, la vista.
  local chips, grupoActual
  for _, f in ipairs(filas) do
    if f.tipo == "chips" then
      chips = f
      local valida = false
      for _, o in ipairs(f.opciones) do if o[1] == subActiva[pestana] then valida = true end end
      if not valida then subActiva[pestana] = f.opciones[1] and f.opciones[1][1] end
    elseif f.tipo == "grupo" then grupoActual = f.clave
    else f.grupo = grupoActual end
  end
  for _, f in ipairs(filas) do
    f.oculta = (chips and f.grupo and f.grupo ~= subActiva[pestana]) or false
  end
  if p then
    local antes = WowF.libroErrorVista
    local okV, errV = pcall(ponerVista, p)
    if not okV then WowF.libroErrorVista = tostring(pestana) .. ": " .. tostring(errV) end
    -- 16-oct (Andy: "Talentos no carga, no se ve nada"): el error de una vista queda en las SavedVariables (no se puede copiar del juego)
    local e = WowF.libroErrorVista
    if e and e ~= antes and type(WowFExportarDB) == "table" then
      pcall(function()
        local r = WowFExportarDB.erroresLibro
        if type(r) ~= "table" then r = {}; WowFExportarDB.erroresLibro = r end
        local ult = r[#r]
        if not (ult and ult.error == e) then
          table.insert(r, { error = e, version = (C_AddOns and C_AddOns.GetAddOnMetadata and select(2, pcall(C_AddOns.GetAddOnMetadata, "ForeverLevelingGuide", "Version"))) or nil, fecha = date and date("%Y-%m-%d %H:%M") or "" })
          while #r > 20 do table.remove(r, 1) end
        end
      end)
    end
  end
  pcall(ponerFondo, p)
  local vis = {}
  for _, f in ipairs(filas) do
    f._r = nil
    if f.tipo == "grupo" then
      -- marca, no se dibuja
    elseif f.oculta then
      if f.tipo == "bloque" and f.marco then f.marco:Hide() end
    else table.insert(vis, f) end
  end
  local y = arriba
  for i, f in ipairs(vis) do
    local r = renglon(i)
    f._r = r
    r.objeto, r.accion, r.ayuda = f.objeto, f.accion, f.ayuda
    r.texto:ClearAllPoints()
    r.raya:Hide(); r.fondo:Hide()
    r.texto:SetJustifyH("LEFT")
    if chipsDe[r] then for _, c in ipairs(chipsDe[r]) do c:Hide() end end
    if r.raya.SetColorTexture then r.raya:SetColorTexture(1, 0.82, 0, 0.25) end
    r.raya:SetHeight(1)
    local x = f.sangria or 0
    local alto
    if f.tipo == "bloque" then
      -- Marco propio (el diagrama de talentos): ocupa su alto en la hoja; el renglon queda oculto para no tapar sus casillas
      r.icono:Hide(); r.texto:SetText(WowF.T(""))
      alto = f.alto or 10
      f.marco:ClearAllPoints(); f.marco:SetPoint("TOPLEFT", hoja, "TOPLEFT", 0, -y); f.marco:Show()
    elseif f.tipo == "raya" then
      -- Separador fuerte (dorado, 2 px) entre el selector de objetivo y lo demas
      r.icono:Hide(); r.texto:SetText(WowF.T(""))
      alto = 8
      if r.raya.SetColorTexture then r.raya:SetColorTexture(1, 0.82, 0, 0.8) end
      r.raya:SetHeight(2)
      r.raya:ClearAllPoints(); r.raya:SetPoint("LEFT", 0, 0); r.raya:SetPoint("RIGHT", 0, 0); r.raya:Show()
    elseif f.tipo == "chips" or f.tipo == "nav" then
      -- Sub-pestanas: botones en fila; la activa en oro ("nav" = Rotacion / Macros, cambia de pestana)
      local esNav = f.tipo == "nav"
      r.icono:Hide(); r.texto:SetText(WowF.T(""))
      r.accion = nil
      chipsDe[r] = chipsDe[r] or {}
      local n, hueco = #f.opciones, 4
      local ancho = math.floor((ANCHO_HOJA - hueco * (n - 1)) / math.max(n, 1))
      if esNav then ancho = math.min(ancho, 150) end
      for k, o in ipairs(f.opciones) do
        local c = chipsDe[r][k]
        if not c then
          c = CreateFrame("Button", nil, r)
          c.fondo = c:CreateTexture(nil, "BACKGROUND"); c.fondo:SetAllPoints()
          c.luz = c:CreateTexture(nil, "ARTWORK"); c.luz:SetAllPoints()
          if c.luz.SetColorTexture then c.luz:SetColorTexture(1, 1, 1, 0.08) end
          c.luz:Hide()
          c.linea = c:CreateTexture(nil, "ARTWORK"); c.linea:SetHeight(2)
          c.linea:SetPoint("BOTTOMLEFT", 0, 0); c.linea:SetPoint("BOTTOMRIGHT", 0, 0)
          if c.linea.SetColorTexture then c.linea:SetColorTexture(C.brasa[1], C.brasa[2], C.brasa[3], 0.95) end -- 11-oct (diario): raya brasa del hibrido
          c.t = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.t:SetPoint("CENTER", 0, 0)
          E.letra(c.t, "boton", 10)
          c:SetScript("OnEnter", function(self) self.luz:Show() end)
          c:SetScript("OnLeave", function(self) self.luz:Hide() end)
          chipsDe[r][k] = c
        end
        local activa = esNav and (o[1] == pestana) or (not esNav and o[1] == subActiva[pestana])
        c:SetSize(ancho, 22)
        c:ClearAllPoints(); c:SetPoint("TOPLEFT", r, "TOPLEFT", (k - 1) * (ancho + hueco), 0)
        if c.fondo.SetColorTexture then
          if activa then c.fondo:SetColorTexture(C.cera[1], C.cera[2], C.cera[3], 0.55) else c.fondo:SetColorTexture(C.cuero2[1], C.cuero2[2], C.cuero2[3], 0.8) end
        end
        if activa then c.linea:Show() else c.linea:Hide() end
        c.t:SetText(WowF.T((activa and E.cod.oro or E.cod.tenue) .. o[2] .. "|r"))
        local clave = o[1]
        c:SetScript("OnClick", function()
          if esNav then pestana = clave else subActiva[pestana] = clave end
          dibujar()
          local sc = _G.wowFLibroScroll
          if sc and sc.SetVerticalScroll then sc:SetVerticalScroll(0) end
        end)
        c:Show()
      end
      alto = 22
    elseif f.tipo == "cab" then
      if i > 1 then y = y + 8 end
      E.letra(r.texto, "cuerpoNegrita", 15); r.texto:SetTextColor(1, 0.82, 0) -- 12-oct: antes GameFontNormal (sin el ajuste de letra)
      r.icono:Hide()
      r.texto:SetPoint("TOPLEFT", 0, 0); r.texto:SetWidth(ANCHO_HOJA)
      r.texto:SetText(WowF.T(f.texto))
      alto = (r.texto:GetStringHeight() or 13) + 4
      r.raya:ClearAllPoints(); r.raya:SetPoint("BOTTOMLEFT", 0, 0); r.raya:SetPoint("BOTTOMRIGHT", 0, 0); r.raya:Show()
    elseif f.tipo == "nota" then
      r.icono:Hide()
      E.letra(r.texto, "cuerpoMedio", 13); r.texto:SetTextColor(1, 1, 1) -- 12-oct: antes GameFontHighlightSmall (10 px)
      r.texto:SetPoint("TOPLEFT", x, 0); r.texto:SetWidth(ANCHO_HOJA - x)
      r.texto:SetText(WowF.T(f.texto))
      alto = r.texto:GetStringHeight() or 12
    else
      local tam = f.chico and 16 or 26
      E.letra(r.texto, "cuerpoMedio", 13); r.texto:SetTextColor(1, 1, 1) -- 12-oct: antes GameFontHighlightSmall (10 px)
      local texto = f.texto .. (f.sub and ("\n" .. f.sub) or "")
      if f.icono then
        r.icono:ClearAllPoints(); r.icono:SetPoint("TOPLEFT", x, 0)
        r.icono:SetSize(tam, tam); r.icono:SetTexture(f.icono); r.icono:Show()
        r.texto:SetPoint("TOPLEFT", x + tam + 8, f.chico and -2 or -1); r.texto:SetWidth(ANCHO_HOJA - x - tam - 8)
      else
        r.icono:Hide()
        r.texto:SetPoint("TOPLEFT", x, 0); r.texto:SetWidth(ANCHO_HOJA - x)
      end
      r.texto:SetText(WowF.T(texto))
      alto = math.max(f.icono and tam or 12, (r.texto:GetStringHeight() or 12) + 2)
      if f.boton then
        -- Opcion con aspecto de boton: la elegida en verde, las demas en gris oscuro
        alto = alto + 6
        r.texto:ClearAllPoints()
        if f.icono then
          r.icono:ClearAllPoints(); r.icono:SetPoint("LEFT", x + 6, 0)
          r.texto:SetPoint("LEFT", x + tam + 14, 0); r.texto:SetWidth(ANCHO_HOJA - x - tam - 20)
        else r.texto:SetPoint("LEFT", x + 8, 0); r.texto:SetWidth(ANCHO_HOJA - x - 16) end
        if r.fondo.SetColorTexture then
          if f.boton == "elegido" then r.fondo:SetColorTexture(0.1, 0.55, 0.2, 0.45) else r.fondo:SetColorTexture(0.3, 0.3, 0.3, 0.35) end
        end
        r.fondo:Show()
      end
    end
    r:SetHeight(alto)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", hoja, "TOPLEFT", 0, -y)
    if f.tipo == "bloque" then r:Hide() else r:Show() end
    y = y + alto + ((f.tipo == "cab" or f.tipo == "chips" or f.tipo == "nav") and 4 or 5)
    if f.tipo == "chips" or f.tipo == "nav" then y = y + 4 end
  end
  for i = #vis + 1, #renglones do renglones[i]:Hide() end
  hoja:SetHeight(math.max(y, 10))
end

function WowF.libroRedibujar() if libro:IsShown() then dibujar() end end
function WowF.abrirLibro(cual)
  if cual == "Combate" then cual = ultimaCombate end
  if cual and CONTENIDO[cual] then pestana = cual end
  libro:Show()
  dibujar()
end
-- 9-oct: las pruebas leen TODO el contenido de la pestana, tambien lo plegado y lo de otras sub-pestanas
local function textoFila(f)
  if f._r and f._r:IsShown() then return f._r.texto:GetText() end
  if f.tipo == "chips" or f.tipo == "nav" then
    local t = {}
    for _, o in ipairs(f.opciones) do table.insert(t, o[2]) end
    return WowF.T(table.concat(t, "  ·  "))
  end
  return WowF.T((f.texto or "") .. (f.sub and ("\n" .. f.sub) or ""))
end
function WowF.libroTexto() -- para las pruebas
  local t = {}
  for _, f in ipairs(filas or {}) do
    if f.tipo ~= "grupo" and f.tipo ~= "bloque" then table.insert(t, textoFila(f) or "") end
  end
  return table.concat(t, "\n")
end

function WowF.libroClic(texto) -- para las pruebas: clic en la fila que contiene el texto (abierta o plegada)
  for _, f in ipairs(filas or {}) do
    local s = f.accion and textoFila(f)
    if s and s:find(texto, 1, true) then f.accion(); return true end
  end
  for _, f in ipairs(filas or {}) do
    if f.tipo == "chips" or f.tipo == "nav" then
      for _, o in ipairs(f.opciones) do
        if WowF.T(o[2]):find(texto, 1, true) then if f.tipo == "nav" then pestana = o[1] else subActiva[pestana] = o[1] end; dibujar(); return true end
      end
    end
  end
  return false
end
function WowF.libroFilasConAccion() -- 13-oct, para las pruebas: cada fila que se puede pulsar (texto + accion), tambien las plegadas
  local t = {}
  for _, f in ipairs(filas or {}) do
    if f.accion and f.tipo ~= "chips" and f.tipo ~= "nav" then table.insert(t, { texto = textoFila(f) or "", accion = f.accion, grupo = f.grupo, objeto = f.objeto }) end
  end
  return t
end

-- 11-oct (tarjetas): textos de un bloque (lista o funcion que la devuelve)
local function textosBloque(f)
  local x = f.textos
  if type(x) == "function" then local ok, r = pcall(x); x = ok and r or nil end
  local t = {}
  if type(x) == "table" then for _, s in ipairs(x) do if type(s) == "string" then table.insert(t, WowF.T(s)) end end
  elseif type(x) == "string" then table.insert(t, WowF.T(x)) end
  return t
end
function WowF.libroVisible() -- para las pruebas: solo lo que se ve (sin las otras sub-pestanas) + los textos de las vistas nuevas
  local t = {}
  for _, f in ipairs(filas or {}) do
    if f.tipo == "bloque" and not f.oculta then for _, s in ipairs(textosBloque(f)) do table.insert(t, s) end end
  end
  for _, r in ipairs(renglones) do
    if r:IsShown() then
      local s = r.texto:GetText() or ""
      if chipsDe[r] then for _, c in ipairs(chipsDe[r]) do if c:IsShown() then s = s .. "[" .. (c.t:GetText() or "") .. "]" end end end
      table.insert(t, s)
    end
  end
  return table.concat(t, "\n")
end
function WowF.libroVista() -- para las pruebas: nombre de la vista nueva que se ve (o nil = contenido viejo) y el error si fallo
  for _, f in ipairs(filas or {}) do if f.vista and not f.oculta then return f.vista, nil end end
  return nil, WowF.libroErrorVista
end

function WowF.libroSubpestana(clave) -- para las pruebas: cambia de sub-pestana (Profesiones: mias, objetivo, secundarias, mas)
  subActiva[pestana] = clave
  dibujar()
  return true
end

function WowF.libroAyudas() -- para las pruebas: los tooltips de todas las filas
  local t = {}
  for _, f in ipairs(filas or {}) do if type(f.ayuda) == "string" then table.insert(t, f.ayuda) end end
  return table.concat(t, "\n")
end

-- Se pone al dia si cambian el nivel, las bolsas, el equipo o las habilidades mientras esta abierta
local eventos = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_LEVEL_UP", "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED", "CHARACTER_POINTS_CHANGED", "PLAYER_EQUIPMENT_CHANGED" }) do pcall(eventos.RegisterEvent, eventos, ev) end
eventos:SetScript("OnEvent", function() if libro:IsShown() then pcall(dibujar) end end)
-- 11-oct: al entrar, el Libro vuelve a su sitio y a la ultima pestana que abriste
local alEntrar = CreateFrame("Frame")
pcall(alEntrar.RegisterEvent, alEntrar, "PLAYER_LOGIN")
alEntrar:SetScript("OnEvent", function()
  local db = type(WowFExportarDB) == "table" and WowFExportarDB or {}
  if type(db.libroCombate) == "string" and COMBATE[db.libroCombate] then ultimaCombate = db.libroCombate end
  if type(db.libroPestana) == "string" and CONTENIDO[db.libroPestana] then pestana = db.libroPestana end
  pcall(WowF.estilo.ponerPos, libro, "libroPos")
end)

-- /wowf solo (o /wowf plan [pestana]) abre esta ventana; el texto para la guia pasa a /wowf exportar
local ordenAnterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower()
  if orden == "" or orden == "plan" then
    local cual
    for _, n in ipairs(PESTANAS) do if resto ~= "" and n:lower():find(resto:lower(), 1, true) == 1 then cual = n end end
    if libro:IsShown() and not cual then libro:Hide() else WowF.abrirLibro(cual) end
    return
  end
  if orden == "exportar" then return ordenAnterior and ordenAnterior("") end
  return ordenAnterior and ordenAnterior(mensaje)
end
