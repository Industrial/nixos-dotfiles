-- Forever Leveling Guide: opciones (4-oct, pedido de un usuario en CurseForge: "increase the font size and adjust the opacity").
-- Tamano de las ventanas (letra incluida) y opacidad del fondo. Se guardan en WowFExportarDB.opciones.
-- /wowf ajustes (u opciones, settings, options, config). Tambien en el menu del juego: Opciones > AddOns > Forever Leveling Guide.

WowF = WowF or {}
local function L(es, en) return (WowF.enIngles and WowF.enIngles()) and en or es end
local ORO, GRIS = "|cffffd100", "|cff9d9d9d"

-- Las ventanas del addon (por su nombre global). La flecha no tiene fondo: solo cambia de tamano.
local VENTANAS = { "wowFPanel", "wowFLibro", "wowFViaje", "wowFFicha", "wowFFlecha", "wowFAlerta", "wowFBienvenida",
  -- 11-oct: tambien las demas ventanas del addon (las que se crean al abrirlas toman el ajuste la proxima vez que se aplica)
  "wowFLinea", "wowFNotas", "wowFAvisoBotin", "wowFVendedor", "wowFEntrenamiento", "wowFMisionGrupo", "wowFCopiaMacro", "wowFAviso", "wowFErrores",
  -- 12-oct: las que faltaban (mapa suelto, mapa grande, piezas anotadas, exportar)
  "wowFMapaMini", "wowFMapaGrande", "wowFCaza", "wowFExportarMarco",
  -- 13-oct: la guia del addon y la de consumibles
  "wowFGuia", "wowFConsumible" }
local TAMANO_MIN, TAMANO_MAX = 0.7, 1.5
-- 12-oct (Andy: "en 100 % es demasiado chiquito y no se lee absolutamente nada"): tamano de letra aparte, 90-140 %, 110 % por defecto
local LETRA_MIN, LETRA_MAX, LETRA_DEF = 0.9, 1.4, 1.1
local ICONO_TAM_MIN, ICONO_TAM_MAX, ICONO_ALFA_MIN = 0.5, 2, 0.2
local POPUP_TAM_MIN, POPUP_TAM_MAX = 0.5, 1.5
-- Avisos emergentes: alerta del centro (Panel), "Tienes cosas nuevas" (Rotacion) y aviso de botin
local POPUPS = { wowFAlerta = true, wowFAviso = true, wowFAvisoBotin = true }
local DURACIONES = { false, 5, 10, 20, 0 } -- false = normal (como viene cada aviso), 0 = fijos hasta cerrarlos
-- 11-oct: el Libro (1100x780) y el panel (420) se midieron en pixeles de la maqueta; en el juego salian enormes.
-- Escala base para que queden como antes (900x530 y 300 de ancho); el 100 % de Ajustes multiplica sobre esto.
local ESCALA_BASE = { wowFLibro = 0.75, wowFPanel = 0.62 } -- 11-oct (Andy: "sigue viendose extremadamente grande"): panel compacto; cada quien lo agranda en Ajustes
-- 13-oct (Andy: "la ventana de ruta es enorme... no esta acorde con el resto"; la ficha de la mazmorra igual): las ventanas
-- sueltas usan letras como las del Libro (9-18) pero iban a escala 1 => un tercio mas grandes. Ahora van a la escala del Libro,
-- y la ficha de la mazmorra (letras del panel) a la del panel. Los avisos emergentes tienen su propio tamano (popupTam).
local BASE_VENTANA = 0.75
for _, n in ipairs({ "wowFViaje", "wowFLinea", "wowFBienvenida", "wowFGuia", "wowFNotas", "wowFVendedor", "wowFEntrenamiento",
  "wowFMisionGrupo", "wowFCopiaMacro", "wowFErrores", "wowFCaza", "wowFExportarMarco", "wowFConsumible" }) do ESCALA_BASE[n] = BASE_VENTANA end
ESCALA_BASE.wowFFicha = 0.62
WowF.escalaBase = ESCALA_BASE

local function num(x) return type(x) == "number" and x or nil end
local function opciones()
  if type(WowFExportarDB) ~= "table" then WowFExportarDB = {} end
  local o = WowFExportarDB.opciones
  if type(o) ~= "table" then o = {}; WowFExportarDB.opciones = o end
  o.tamano = math.max(TAMANO_MIN, math.min(TAMANO_MAX, num(o.tamano) or 1))
  o.fondo = math.max(0, math.min(1, num(o.fondo) or 1))
  o.letra = math.max(LETRA_MIN, math.min(LETRA_MAX, num(o.letra) or LETRA_DEF))
  -- 13-oct (comentario 8537474 de CurseForge): tamano (50-200 %) y opacidad (20-100 %) de los iconos de entrenadores en el mapa
  o.iconoTam = math.max(ICONO_TAM_MIN, math.min(ICONO_TAM_MAX, num(o.iconoTam) or 1))
  o.iconoAlfa = math.max(ICONO_ALFA_MIN, math.min(1, num(o.iconoAlfa) or 1))
  -- 19-oct (Andy): tamano de las calaveras de rares en el mapa (50-200 %, wowF_Rares.lua)
  o.raresTam = math.max(ICONO_TAM_MIN, math.min(ICONO_TAM_MAX, num(o.raresTam) or 1))
  -- 13-oct (Andy, comentario 8537474): tamano de los avisos emergentes (50-150 %) y cuanto duran (nil = como vienen, 0 = fijos)
  o.popupTam = math.max(POPUP_TAM_MIN, math.min(POPUP_TAM_MAX, num(o.popupTam) or 1))
  if o.popupSeg ~= nil and not num(o.popupSeg) then o.popupSeg = nil end
  return o
end
WowF.opciones = opciones
-- Segundos que dura un aviso emergente: normal = lo que trae ese aviso (nil = se queda hasta cerrarlo).
-- Devuelve nil si no debe cerrarse solo.
function WowF.duracionPopup(normal)
  local s = opciones().popupSeg
  if s == nil then return normal end
  if s <= 0 then return nil end
  return s
end

-- El alfa original del fondo de cada ventana: la opacidad es un porcentaje de ese (100 % = como siempre)
local base = {}
-- 12-oct (Andy: con la letra grande "se van completamente de sus tarjetas"): el "Tamano de letra" agranda la ventana
-- entera (la letra se pone siempre al 110 % de fabrica, ver E.tamFinal): 130 % de letra = ventana 130/110 mas grande.
-- Ajustes no entra en la cuenta de la letra (si creciera mientras arrastras su deslizador, se moveria bajo el raton).
local function escalaDe(nombre)
  local o = opciones()
  local letra = nombre == "wowFOpciones" and 1 or (o.letra / LETRA_DEF)
  -- "" = ventana suelta sin nombre (comparar del Diario, consumibles): misma escala que las demas
  return o.tamano * (ESCALA_BASE[nombre] or (nombre == "" and BASE_VENTANA) or 1) * letra * (POPUPS[nombre] and o.popupTam or 1)
end
WowF.escalaVentana = escalaDe
-- Los avisos que se crean tarde (al primer aviso) toman su tamano al mostrarse
function WowF.escalaPopup(f, nombre)
  if type(f) == "table" and f.SetScale then pcall(f.SetScale, f, escalaDe(nombre)) end
end
-- Ventanas sin nombre global (comparar del Diario...): se apuntan aqui y toman la misma escala
WowF.ventanasSueltas = WowF.ventanasSueltas or {}
function WowF.registrarVentana(f)
  if type(f) ~= "table" then return end
  WowF.ventanasSueltas[f] = true
  if f.SetScale then pcall(f.SetScale, f, escalaDe("")) end
end
local function aplicar()
  local o = opciones()
  for f in pairs(WowF.ventanasSueltas) do if f.SetScale then pcall(f.SetScale, f, escalaDe("")) end end
  for _, nombre in ipairs(VENTANAS) do
    local f = _G[nombre]
    if type(f) == "table" then
      if f.SetScale then pcall(f.SetScale, f, escalaDe(nombre)) end
      if f.SetBackdropColor and f.GetBackdropColor then
        if not base[nombre] then
          local ok, r, g, b, a = pcall(f.GetBackdropColor, f)
          if ok and num(r) and num(g) and num(b) and num(a) then base[nombre] = { r, g, b, a } end
        end
        local c = base[nombre]
        if c then pcall(f.SetBackdropColor, f, c[1], c[2], c[3], c[4] * o.fondo) end
      end
      -- 11-oct: la piedra y el filete del estilo nuevo siguen la misma opacidad
      if WowF.estilo then pcall(WowF.estilo.alfa, f, o.fondo) end
    end
  end
end
WowF.aplicarOpciones = aplicar
-- 13-oct: las ventanas que se crean al abrirlas (ruta, linea, vendedor, guia...) toman el ajuste en cuanto aparecen,
-- no la proxima vez que se aplica (antes la primera vez salian a escala 1, enormes)
do
  local vistas, espera = {}, 0
  local vigia = CreateFrame("Frame")
  vigia:SetScript("OnUpdate", function(_, dt)
    espera = espera + (tonumber(dt) or 0)
    if espera < 0.5 then return end
    espera = 0
    local nueva = false
    for _, nombre in ipairs(VENTANAS) do
      local f = _G[nombre]
      if type(f) == "table" and not vistas[f] then vistas[f] = true; nueva = true end
    end
    if nueva then pcall(aplicar) end
  end)
end
-- 12-oct: vuelve a poner todas las letras con el tamano elegido y repinta el plan y el panel
local function aplicarLetra()
  pcall(aplicar)
  if WowF.estilo and WowF.estilo.reaplicarLetras then pcall(WowF.estilo.reaplicarLetras) end
  if WowF.libroRedibujar then pcall(WowF.libroRedibujar) end
  if WowF.panelActualizar then pcall(WowF.panelActualizar) end
end
WowF.aplicarLetra = aplicarLetra

-- ===================== Ventana =====================
local v, deslizTamano, deslizFondo, deslizLetra, titulo, nota, botonRestablecer
local casillaBotin -- 4-oct: aviso de botin (wowF_AvisoBotin.lua) encendido/apagado, en WowFExportarDB.avisoBotin
-- 5-oct: casillas que registran otros archivos (clave de WowFExportarDB, encendida por defecto; texto = funcion que da el texto)
local extras, casillasExtra = {}, {}
-- apagada = true: la casilla empieza apagada (solo cuenta si el valor guardado es true)
-- 11-oct: alCambiar (opcional) = funcion que se llama tras cada clic (p. ej. ocultar el boton del minimapa al momento)
function WowF.registrarCasillaOpciones(clave, texto, apagada, alCambiar) extras[#extras + 1] = { clave = clave, texto = texto, apagada = apagada == true, alCambiar = alCambiar } end
local function casillaEncendida(dato)
  local v = WowFExportarDB[dato.clave]
  if dato.apagada then return v == true end
  return v ~= false
end
WowF._casillasOpciones = function() return casillasExtra end -- para las pruebas
-- 8-oct (4.11, pala1 en CurseForge): de donde se muestran las mejoras de equipo (WowF.mejorasDe en wowF_EquipoGuia.lua)
WowF.registrarCasillaOpciones("mejorasMision", function() return L("Mejoras de equipo: de misiones", "Gear upgrades: from quests") end)
WowF.registrarCasillaOpciones("mejorasMazmorra", function() return L("Mejoras de equipo: de mazmorras (y marca del jefe)", "Gear upgrades: from dungeons (and boss mark)") end)
WowF.registrarCasillaOpciones("mejorasFabricar", function() return L("Mejoras de equipo: fabricadas (avisos y panel)", "Gear upgrades: crafted (alerts and panel)") end)
-- 13-oct (comentario 8537474 de CurseForge: con otros addons de subida salian demasiadas ventanas): apagada = el resumen solo en el chat
WowF.registrarCasillaOpciones("avisoSubirNivel", function() return L("Ventanas al subir de nivel (apagada: el resumen sale solo en el chat)", "Level-up popups (off: the summary only goes to chat)") end)
local function porciento(x) return math.floor(x * 100 + 0.5) .. " %" end

-- 11-oct (rediseno "hibrido"): ventana tipo tapa, titulo serif, etiquetas brasa por seccion, deslizadores planos
-- (riel de piedra con borde fino y tirador brasa), casillas con texto Signika y un solo boton principal brasa (Restablecer).
local ANCHO, IZQ = 380, 24 -- 13-oct: mas ancha (las casillas caben en un renglon) y por pestanas
local function deslizador(padre, y, minimo, maximo, paso, guardar)
  local E = WowF.estilo
  local s = CreateFrame("Slider", nil, padre, BackdropTemplateMixin and "BackdropTemplate" or nil)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(ANCHO - 2 * IZQ, 10)
  s:SetPoint("TOPLEFT", IZQ, y)
  s:SetMinMaxValues(minimo, maximo)
  s:SetValueStep(paso)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  local tirador = s:CreateTexture(nil, "OVERLAY", nil, 2)
  local okT = pcall(function()
    tirador:SetColorTexture(E.color.brasa[1], E.color.brasa[2], E.color.brasa[3], 1)
    tirador:SetSize(8, 16)
    s:SetThumbTexture(tirador)
  end)
  if not okT then s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal") end
  if s.SetBackdrop then
    pcall(s.SetBackdrop, s, { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    pcall(s.SetBackdropColor, s, E.color.piedra2[1], E.color.piedra2[2], E.color.piedra2[3], 1)
    pcall(s.SetBackdropBorderColor, s, E.color.borde[1], E.color.borde[2], E.color.borde[3], 1)
  end
  s:EnableMouse(true)
  s.titulo = E.cuerpo(s, s:CreateFontString(nil, "ARTWORK", "GameFontNormal"), 12)
  s.titulo:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 6)
  s.valor = E.cuerpo(s, s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"), 12, E.color.oro)
  s.valor:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, 6)
  s.minimo = E.sub(s, s:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall"), 11)
  s.minimo:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -3)
  s.minimo:SetText(porciento(minimo))
  s.maximo = E.sub(s, s:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall"), 11)
  s.maximo:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -3)
  s.maximo:SetText(porciento(maximo))
  s:SetScript("OnValueChanged", function(self, x)
    x = num(x) or minimo
    x = math.floor(x / paso + 0.5) * paso
    self.valor:SetText(porciento(x))
    if self.cargando then return end
    guardar(x)
    aplicar()
  end)
  -- La rueda del raton tambien lo mueve
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseWheel", function(self, d)
    local x = num(self:GetValue()) or minimo
    self:SetValue(math.max(minimo, math.min(maximo, x + (d > 0 and paso or -paso))))
  end)
  return s
end

local function poner(s, x)
  s.cargando = true
  s:SetValue(x)
  s.valor:SetText(porciento(x))
  s.cargando = false
end

local deslizIconoTam, deslizIconoAlfa -- 13-oct: iconos de entrenadores en el mapa
local function redibujarIconos() if WowF.dibujarEntrenadores then pcall(WowF.dibujarEntrenadores) end end
local botonEntrenadores -- 6-oct: modo de los iconos de entrenadores en el mapa (wowF_Entrenadores.lua)
-- 19-oct (Andy: "activar o desactivar facilmente los rares en el mapa" + su tamano): seccion RARES en la pestana Mapa
-- (Mostrar / Ocultar, tamano de las calaveras y las casillas de aviso y tooltip). El boton del mapa esta en wowF_Rares.lua.
local etRares, filaRares, botonesRares, deslizRaresTam = nil, nil, {}, nil
local function redibujarRares()
  if WowF.dibujarRares then pcall(WowF.dibujarRares) end
  if WowF.refrescarBotonRares then pcall(WowF.refrescarBotonRares) end
end
-- 11-oct (djextra): "Abrir en" = donde se abre el plan completo (WowFExportarDB.abrirEn: "ultima" | "Mazmorras" | "Progreso";
-- lo aplica WowF.abrirLibro en wowF_Diario.lua). El boton va rotando entre los tres.
local botonAbrirEn
local ABRIR_EN = { "ultima", "Mazmorras", "Progreso" }
local function nombreAbrirEn(d)
  return (d == "Mazmorras") and L("Mazmorras (diario)", "Dungeons (journal)") or (d == "Progreso") and L("Progreso", "Progress")
    or L("donde lo dejé", "where I left it")
end
function WowF.textoAbrirEn()
  return L("Abrir el plan en: ", "Open the plan on: ") .. nombreAbrirEn(WowFExportarDB.abrirEn)
end
-- 13-oct (Andy: "le doy clic y no hace nada"): antes era un boton que rotaba y solo cambiaba su texto. Ahora son 3 opciones a la
-- vista (la elegida en brasa) y al elegir lo dice en el chat.
local etAbrirEn, botonesAbrirEn = nil, {}
local CORTO_ABRIR_EN = { ultima = { "Donde lo dejé", "Last tab" }, Mazmorras = { "Mazmorras", "Dungeons" }, Progreso = { "Progreso", "Progress" } }
function WowF.siguienteAbrirEn()
  local d, i = WowFExportarDB.abrirEn or "ultima", 1
  for k, x in ipairs(ABRIR_EN) do if x == d then i = k end end
  local s = ABRIR_EN[i % #ABRIR_EN + 1]
  WowFExportarDB.abrirEn = (s ~= "ultima") and s or nil
  return s
end
local etVentanas, etAvisos, etMapa, divisores = nil, nil, nil, {}
-- 13-oct: seccion AVISOS EMERGENTES (tamano + duracion)
local etPopups, deslizPopupTam, etDuracion, filaDuracion, botonesDuracion = nil, nil, nil, nil, {}
local function textoDuracion(d)
  if d == false then return L("Normal", "Default") end
  if d == 0 then return L("Fijos", "Stay") end
  return d .. " s"
end
-- 13-oct (Andy: "es muy grande, demasiado... que sea comodo"): la ventana ocupaba toda la pantalla. Ahora va en 4 pestanas
-- (Ventanas / Avisos / Equipo / Mapa); solo se ve la elegida y la ventana tiene el alto de la pestana mas larga (no salta).
local PESTANAS = { "ventanas", "avisos", "equipo", "mapa" }
local PEST_CASILLA = { ocultarMinimapa = "ventanas", mejorasMision = "equipo", mejorasMazmorra = "equipo", mejorasFabricar = "equipo",
  recompensa = "equipo", tooltipMejora = "equipo", vendedor = "equipo", autoReparar = "equipo",
  raresAviso = "mapa", raresTooltip = "mapa" }
local botonesPestana, etEquipo = {}, nil
local function pestanaActual()
  local p = WowFExportarDB and WowFExportarDB.opcionesPestana
  for _, x in ipairs(PESTANAS) do if x == p then return p end end
  return "ventanas"
end
local function pestanaDe(c) return (c.dato and PEST_CASILLA[c.dato.clave]) or "avisos" end
local function ver(f, si) if f then if si then f:Show() else f:Hide() end end end
local ARRIBA = 96 -- debajo del titulo y de las pestanas
local function colocar()
  if not v or not casillaBotin then return end
  local actual = pestanaActual()
  local altos = {}
  local function casillas(p, y)
    local filas = {}
    if p == "avisos" then filas[1] = casillaBotin end
    for _, c in ipairs(casillasExtra) do if pestanaDe(c) == p then filas[#filas + 1] = c end end
    for _, c in ipairs(filas) do
      c:ClearAllPoints(); c:SetPoint("TOPLEFT", IZQ - 4, -y)
      ver(c, p == actual); ver(c.texto, p == actual)
      local h = (c.texto.GetStringHeight and tonumber(c.texto:GetStringHeight())) or 12
      y = y + math.max(22, h + 8)
    end
    return y
  end
  -- VENTANAS: tamano, opacidad, letra, nota, "empieza en" y el boton del minimapa
  local si = actual == "ventanas"
  local y = ARRIBA
  etVentanas:ClearAllPoints(); etVentanas:SetPoint("TOPLEFT", IZQ, -y); ver(etVentanas, si)
  y = y + 38
  for _, s in ipairs({ deslizTamano, deslizFondo, deslizLetra }) do
    s:ClearAllPoints(); s:SetPoint("TOPLEFT", IZQ, -y); ver(s, si)
    y = y + 52
  end
  y = y - 22
  nota:ClearAllPoints(); nota:SetPoint("TOPLEFT", IZQ, -y); ver(nota, si)
  y = y + ((nota.GetStringHeight and tonumber(nota:GetStringHeight())) or 40) + 14
  if botonAbrirEn then
    etAbrirEn:ClearAllPoints(); etAbrirEn:SetPoint("TOPLEFT", IZQ, -y); ver(etAbrirEn, si)
    y = y + 16
    botonAbrirEn:ClearAllPoints(); botonAbrirEn:SetPoint("TOPLEFT", IZQ, -y); ver(botonAbrirEn, si)
    y = y + 32
  end
  altos.ventanas = casillas("ventanas", y)
  -- AVISOS: casillas de avisos + avisos emergentes (tamano y duracion)
  si = actual == "avisos"
  y = ARRIBA
  etAvisos:ClearAllPoints(); etAvisos:SetPoint("TOPLEFT", IZQ, -y); ver(etAvisos, si)
  y = casillas("avisos", y + 16)
  if deslizPopupTam then
    y = y + 12
    etPopups:ClearAllPoints(); etPopups:SetPoint("TOPLEFT", IZQ, -y); ver(etPopups, si)
    y = y + 40
    deslizPopupTam:ClearAllPoints(); deslizPopupTam:SetPoint("TOPLEFT", IZQ, -y); ver(deslizPopupTam, si)
    y = y + 26
    etDuracion:ClearAllPoints(); etDuracion:SetPoint("TOPLEFT", IZQ, -y); ver(etDuracion, si)
    y = y + 18
    filaDuracion:ClearAllPoints(); filaDuracion:SetPoint("TOPLEFT", IZQ, -y); ver(filaDuracion, si)
    y = y + 26
  end
  altos.avisos = y
  -- EQUIPO: de donde salen las mejoras, recompensa, tooltip y vendedor
  si = actual == "equipo"
  y = ARRIBA
  etEquipo:ClearAllPoints(); etEquipo:SetPoint("TOPLEFT", IZQ, -y); ver(etEquipo, si)
  altos.equipo = casillas("equipo", y + 16)
  -- MAPA: iconos de entrenadores
  si = actual == "mapa"
  y = ARRIBA
  etMapa:ClearAllPoints(); etMapa:SetPoint("TOPLEFT", IZQ, -y); ver(etMapa, si)
  y = y + 16
  if botonEntrenadores then
    botonEntrenadores:ClearAllPoints(); botonEntrenadores:SetPoint("TOPLEFT", IZQ, -y); ver(botonEntrenadores, si)
    y = y + 22
  end
  if deslizIconoTam then
    y = y + 30
    deslizIconoTam:ClearAllPoints(); deslizIconoTam:SetPoint("TOPLEFT", IZQ, -y); ver(deslizIconoTam, si)
    y = y + 52
    deslizIconoAlfa:ClearAllPoints(); deslizIconoAlfa:SetPoint("TOPLEFT", IZQ, -y); ver(deslizIconoAlfa, si)
    y = y + 26
  end
  -- 19-oct: RARES (Mostrar / Ocultar, tamano y casillas de aviso y tooltip)
  if filaRares then
    y = y + 22
    etRares:ClearAllPoints(); etRares:SetPoint("TOPLEFT", IZQ, -y); ver(etRares, si)
    y = y + 16
    filaRares:ClearAllPoints(); filaRares:SetPoint("TOPLEFT", IZQ, -y); ver(filaRares, si)
    y = y + 52
    deslizRaresTam:ClearAllPoints(); deslizRaresTam:SetPoint("TOPLEFT", IZQ, -y); ver(deslizRaresTam, si)
    y = y + 30
  end
  y = casillas("mapa", y)
  altos.mapa = y
  local alto = 0
  for _, p in ipairs(PESTANAS) do alto = math.max(alto, altos[p] or 0) end
  v:SetHeight(alto + 62)
end
WowF._pestanasOpciones = function() return botonesPestana, pestanaActual() end -- para las pruebas (13-oct)

local function refrescar()
  if not v then return end
  local E = WowF.estilo
  if botonEntrenadores and WowF.textoModoEntrenadores then botonEntrenadores:SetText(WowF.textoModoEntrenadores()) end
  local o = opciones()
  if botonAbrirEn then
    local actual = WowFExportarDB.abrirEn or "ultima"
    etAbrirEn:SetText(E.mayus(L("Al abrir el plan completo, empieza en", "When the full plan opens, start on")))
    for i, b in ipairs(botonesAbrirEn) do
      local c = CORTO_ABRIR_EN[ABRIR_EN[i]]
      b:SetText(L(c[1], c[2]))
      E.boton(b, ABRIR_EN[i] == actual and "brasa" or "cuero", 11)
    end
  end
  if deslizPopupTam then
    etPopups:SetText(E.mayus(L("Avisos emergentes", "Popups")))
    deslizPopupTam.titulo:SetText(L("Tamaño de los avisos", "Popup size"))
    poner(deslizPopupTam, o.popupTam)
    etDuracion:SetText(L("Cuánto duran en pantalla", "How long they stay on screen"))
    local actual = o.popupSeg == nil and false or o.popupSeg
    for i, b in ipairs(botonesDuracion) do
      b:SetText(textoDuracion(DURACIONES[i]))
      E.boton(b, DURACIONES[i] == actual and "brasa" or "cuero", 11)
    end
  end
  titulo:SetText((E and E.cod.oro or ORO) .. "Forever Guide|r - " .. L("Ajustes", "Settings"))
  if v and v.botonGuia then v.botonGuia:SetText("? " .. L("Guía del addon", "Addon guide")) end
  etVentanas:SetText(E.mayus(L("Ventanas", "Windows")))
  etAvisos:SetText(E.mayus(L("Avisos y mejoras", "Alerts and upgrades")))
  etMapa:SetText(E.mayus(L("Iconos de entrenadores en el mapa", "Trainer icons on the map")))
  if etEquipo then etEquipo:SetText(E.mayus(L("Mejoras de equipo y vendedor", "Gear upgrades and vendor"))) end
  local nombresP = { ventanas = { "Ventanas", "Windows" }, avisos = { "Avisos", "Alerts" }, equipo = { "Equipo", "Gear" }, mapa = { "Mapa", "Map" } }
  for i, b in ipairs(botonesPestana) do
    local p = PESTANAS[i]
    b:SetText(L(nombresP[p][1], nombresP[p][2]))
    E.boton(b, p == pestanaActual() and "brasa" or "cuero", 12)
  end
  deslizTamano.titulo:SetText(L("Tamaño (ventanas y letra)", "Size (windows and text)"))
  deslizFondo.titulo:SetText(L("Opacidad del fondo", "Background opacity"))
  deslizLetra.titulo:SetText(L("Tamaño de letra", "Text size"))
  nota:SetText((E and E.cod.tenue or GRIS) .. L("Cambia el panel, el plan completo, la ventana de la ruta, la flecha y los avisos. Tamaño de letra: 110 % = como viene; súbelo si no lees bien.",
    "Applies to the panel, the full plan, the route window, the arrow and the alerts. Text size: 110 % = default; raise it if the text is hard to read.") .. "|r")
  botonRestablecer:SetText(L("Restablecer", "Reset"))
  poner(deslizTamano, o.tamano)
  poner(deslizFondo, o.fondo)
  poner(deslizLetra, o.letra)
  if deslizIconoTam then
    deslizIconoTam.titulo:SetText(L("Tamaño de los iconos de entrenadores", "Trainer icon size"))
    deslizIconoAlfa.titulo:SetText(L("Opacidad de los iconos de entrenadores", "Trainer icon opacity"))
    poner(deslizIconoTam, o.iconoTam)
    poner(deslizIconoAlfa, o.iconoAlfa)
  end
  if filaRares then
    etRares:SetText(E.mayus(L("Rares de tu zona en el mapa", "Rares in your zone on the map")))
    local visibles = WowFExportarDB.raresMapa ~= false
    botonesRares[1]:SetText(L("Mostrar", "Show"))
    botonesRares[2]:SetText(L("Ocultar", "Hide"))
    E.boton(botonesRares[1], visibles and "brasa" or "cuero", 11)
    E.boton(botonesRares[2], visibles and "cuero" or "brasa", 11)
    deslizRaresTam.titulo:SetText(L("Tamaño de las calaveras de rares", "Rare skull size"))
    poner(deslizRaresTam, o.raresTam)
  end
  if casillaBotin then
    casillaBotin.texto:SetText(L("Avisarme cuando me cae algo bueno (botín)", "Alert me when I loot something good"))
    if casillaBotin.SetChecked then pcall(casillaBotin.SetChecked, casillaBotin, WowFExportarDB.avisoBotin ~= false) end
  end
  for _, c in ipairs(casillasExtra) do
    local ok, t = pcall(c.dato.texto)
    c.texto:SetText(ok and type(t) == "string" and t or c.dato.clave)
    if c.SetChecked then pcall(c.SetChecked, c, casillaEncendida(c.dato)) end
  end
  colocar()
end

local function crear()
  if v then return v end
  local E = WowF.estilo
  v = CreateFrame("Frame", "wowFOpciones", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  v:SetSize(ANCHO, 290)
  v:SetPoint("CENTER", 0, 80)
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
    v:SetBackdropBorderColor(0.2, 0.8, 1, 0.9)
  end
  E.marco(v, "tapa")
  -- Titulo serif y X de cuero (como la tarjeta de la ruta)
  titulo = E.titulo(v, v:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"), 16)
  titulo:SetPoint("TOPLEFT", IZQ, -22)
  local cerrar = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
  E.boton(cerrar, "cuero", 11)
  cerrar:SetSize(18, 18)
  cerrar:SetPoint("TOPRIGHT", -16, -18)
  cerrar:SetText("X")
  cerrar:SetScript("OnClick", function() v:Hide() end)
  divisores[1] = E.textura(v, "ARTWORK", 1, E.color.borde, 1)
  divisores[1]:SetHeight(1)
  divisores[1]:SetPoint("TOPLEFT", IZQ, -84); divisores[1]:SetPoint("TOPRIGHT", -IZQ, -84)
  -- 13-oct: pestanas (Ventanas / Avisos / Equipo / Mapa) bajo el titulo
  local anchoP = math.floor((ANCHO - 2 * IZQ - 18) / #PESTANAS)
  for i, p in ipairs(PESTANAS) do
    local b = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
    E.boton(b, "cuero", 12)
    b:SetSize(anchoP, 24)
    b:SetPoint("TOPLEFT", IZQ + (i - 1) * (anchoP + 6), -52)
    b:SetScript("OnClick", function()
      WowFExportarDB.opcionesPestana = p
      refrescar()
    end)
    botonesPestana[i] = b
  end
  -- Seccion VENTANAS: los dos deslizadores y la nota
  etVentanas = E.etiqueta(v)
  etVentanas:SetPoint("TOPLEFT", IZQ, -60)
  deslizTamano = deslizador(v, -98, TAMANO_MIN, TAMANO_MAX, 0.05, function(x) opciones().tamano = x end)
  deslizFondo = deslizador(v, -150, 0, 1, 0.05, function(x) opciones().fondo = x end)
  deslizLetra = deslizador(v, -202, LETRA_MIN, LETRA_MAX, 0.05, function(x) opciones().letra = x; aplicarLetra() end)
  nota = E.sub(v, v:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), 11)
  nota:SetPoint("TOPLEFT", IZQ, -232)
  nota:SetWidth(ANCHO - 2 * IZQ)
  nota:SetJustifyH("LEFT")
  divisores[2] = E.textura(v, "ARTWORK", 1, E.color.borde, 1)
  divisores[2]:SetHeight(1)
  divisores[2]:Hide()
  -- Seccion AVISOS Y MEJORAS: casillas (colocar() las pone segun el alto de su texto)
  etAvisos = E.etiqueta(v)
  etMapa = E.etiqueta(v)
  etEquipo = E.etiqueta(v)
  local function casilla()
    local c = CreateFrame("CheckButton", nil, v, "UICheckButtonTemplate")
    c:SetSize(22, 22)
    c.texto = E.cuerpo(v, v:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), 12)
    c.texto:SetPoint("TOPLEFT", c, "TOPRIGHT", 4, -4)
    c.texto:SetWidth(ANCHO - 2 * IZQ - 26)
    c.texto:SetJustifyH("LEFT")
    return c
  end
  casillaBotin = casilla()
  casillaBotin:SetPoint("TOPLEFT", IZQ - 4, -316)
  casillaBotin:SetScript("OnClick", function()
    WowFExportarDB.avisoBotin = (WowFExportarDB.avisoBotin == false) -- cambia: encendido <-> apagado
    refrescar()
  end)
  for i, dato in ipairs(extras) do
    local c = casilla()
    c:SetPoint("TOPLEFT", IZQ - 4, -316 - 24 * i)
    c.dato = dato
    c:SetScript("OnClick", function()
      if dato.apagada then WowFExportarDB[dato.clave] = not casillaEncendida(dato)
      else WowFExportarDB[dato.clave] = (WowFExportarDB[dato.clave] == false) end
      if type(dato.alCambiar) == "function" then pcall(dato.alCambiar) end
      refrescar()
    end)
    casillasExtra[#casillasExtra + 1] = c
  end
  local alto = 316 + 24 * (#extras + 1) + 56
  -- 13-oct: avisos emergentes (colocar() los pone debajo de las casillas)
  etPopups = E.etiqueta(v)
  deslizPopupTam = deslizador(v, -alto, POPUP_TAM_MIN, POPUP_TAM_MAX, 0.05, function(x)
    opciones().popupTam = x
    -- muestra al momento como queda (la misma clave la sustituye mientras arrastras)
    if WowF.avisar then pcall(WowF.avisar, L("Así se ven los avisos", "This is how popups look"), L("Tamaño: ", "Size: ") .. porciento(x), nil, 4, nil, { clave = "muestraTam", sinChat = true }) end
  end)
  etDuracion = E.cuerpo(v, v:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), 12)
  filaDuracion = CreateFrame("Frame", nil, v)
  filaDuracion:SetSize(ANCHO - 2 * IZQ, 22)
  local anchoD = math.floor((ANCHO - 2 * IZQ - 16) / #DURACIONES)
  for i, d in ipairs(DURACIONES) do
    local b = CreateFrame("Button", nil, filaDuracion, "UIPanelButtonTemplate")
    E.boton(b, "cuero", 11)
    b:SetSize(anchoD, 22)
    b:SetPoint("TOPLEFT", (i - 1) * (anchoD + 4), 0)
    b:SetScript("OnClick", function()
      opciones().popupSeg = (d ~= false) and d or nil
      refrescar()
      local msg = (d == false) and L("los avisos duran lo de siempre.", "popups last their default time.")
        or (d == 0) and L("los avisos se quedan hasta que los cierres.", "popups stay until you close them.")
        or L("los avisos se cierran solos a los " .. d .. " s.", "popups close by themselves after " .. d .. " s.")
      print("|cffffd200Forever Guide|r - " .. msg)
    end)
    b:SetScript("OnEnter", function(self)
      if not GameTooltip then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(textoDuracion(d), 1, 0.82, 0)
      GameTooltip:AddLine((d == false) and L("Cada aviso dura lo de siempre (la alerta del centro unos segundos; el de botín, hasta cerrarlo).",
        "Each popup lasts its default time (the center alert a few seconds; the loot one, until closed).")
        or (d == 0) and L("Ningún aviso se cierra solo: clic en el aviso o en Cerrar.", "No popup closes by itself: click it or press Close.")
        or L("Todos los avisos se cierran solos a los " .. d .. " segundos.", "All popups close by themselves after " .. d .. " seconds."), 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    botonesDuracion[i] = b
  end
  alto = alto + 110
  etAbrirEn = E.etiqueta(v)
  botonAbrirEn = CreateFrame("Frame", nil, v)
  botonAbrirEn:SetSize(ANCHO - 2 * IZQ, 22)
  botonAbrirEn:SetPoint("TOPLEFT", IZQ, -alto + 56)
  local anchoOp = math.floor((ANCHO - 2 * IZQ - 12) / 3)
  for i, s in ipairs(ABRIR_EN) do
    local b = CreateFrame("Button", nil, botonAbrirEn, "UIPanelButtonTemplate")
    E.boton(b, "cuero", 11)
    b:SetSize(anchoOp, 22)
    b:SetPoint("TOPLEFT", (i - 1) * (anchoOp + 6), 0)
    b:SetScript("OnClick", function()
      WowFExportarDB.abrirEn = (s ~= "ultima") and s or nil
      refrescar()
      print("|cffffd200Forever Guide|r - " .. L("El plan completo se abrirá en: ", "The full plan will open on: ") .. nombreAbrirEn(WowFExportarDB.abrirEn)
        .. L(" (botón Plan completo o /wowf plan).", " (Full plan button or /wowf plan)."))
    end)
    botonesAbrirEn[i] = b
  end
  alto = alto + 46
  if WowF.siguienteModoEntrenadores then
    botonEntrenadores = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
    E.boton(botonEntrenadores, "cuero")
    botonEntrenadores:SetSize(ANCHO - 2 * IZQ, 22)
    botonEntrenadores:SetPoint("TOPLEFT", IZQ, -316 - 24 * (#extras + 1) - 32)
    botonEntrenadores:SetScript("OnClick", function() WowF.siguienteModoEntrenadores(); refrescar() end)
    alto = alto + 54
    deslizIconoTam = deslizador(v, -alto, ICONO_TAM_MIN, ICONO_TAM_MAX, 0.1, function(x) opciones().iconoTam = x; redibujarIconos() end)
    deslizIconoAlfa = deslizador(v, -alto - 52, ICONO_ALFA_MIN, 1, 0.05, function(x) opciones().iconoAlfa = x; redibujarIconos() end)
    alto = alto + 108
  end
  -- 19-oct: RARES en el mapa (colocar() los pone en la pestana Mapa)
  etRares = E.etiqueta(v)
  filaRares = CreateFrame("Frame", nil, v)
  filaRares:SetSize(ANCHO - 2 * IZQ, 22)
  local anchoR = math.floor((ANCHO - 2 * IZQ - 6) / 2)
  for i = 1, 2 do
    local b = CreateFrame("Button", nil, filaRares, "UIPanelButtonTemplate")
    E.boton(b, "cuero", 11)
    b:SetSize(anchoR, 22)
    b:SetPoint("TOPLEFT", (i - 1) * (anchoR + 6), 0)
    b:SetScript("OnClick", function()
      WowFExportarDB.raresMapa = (i == 1)
      redibujarRares()
      refrescar()
    end)
    b:SetScript("OnEnter", function(self)
      if not GameTooltip then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(i == 1 and L("Mostrar rares de tu zona", "Show rares in your zone") or L("Ocultar rares de tu zona", "Hide rares in your zone"), 1, 0.82, 0)
      GameTooltip:AddLine(L("Las calaveras de los rares de la zona donde estás (al mirar otras zonas no sale nada). El rare que marques en la pestaña Rares se ve siempre. También con el botón del mapa.",
        "Skulls for the rares in the zone you are in (nothing shows on other zones). The rare you mark in the Rares tab always shows. Also with the button on the map."), 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    botonesRares[i] = b
  end
  deslizRaresTam = deslizador(v, -alto, ICONO_TAM_MIN, ICONO_TAM_MAX, 0.1, function(x) opciones().raresTam = x; redibujarRares() end)
  alto = alto + 90
  v:SetHeight(alto) -- colocar() lo ajusta al alto real de los textos al abrir
  -- 13-oct (Andy: la Guia arriba "apenas se ve y tapa el titulo"): abajo, boton principal (brasa) con "?"; Restablecer al lado en cuero
  v.botonGuia = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
  E.boton(v.botonGuia, "brasa", 13)
  v.botonGuia:SetSize(150, 26)
  v.botonGuia:SetPoint("BOTTOMLEFT", IZQ, 20)
  v.botonGuia:SetScript("OnClick", function() if WowF.abrirGuia then WowF.abrirGuia("ajustes") end end)
  v.botonGuia:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L("Guía del addon", "Addon guide"), 1, 0.82, 0)
    GameTooltip:AddLine(L("Qué hace cada ajuste y cada parte del addon, y dónde está.", "What each setting and each part of the addon does, and where it is."), 1, 1, 1, true)
    GameTooltip:Show()
  end)
  v.botonGuia:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  botonRestablecer = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
  E.boton(botonRestablecer, "cuero")
  botonRestablecer:SetSize(120, 26)
  botonRestablecer:SetPoint("BOTTOMRIGHT", -IZQ, 20)
  botonRestablecer:SetScript("OnClick", function()
    local o = opciones()
    o.tamano, o.fondo, o.letra = 1, 1, LETRA_DEF
    o.iconoTam, o.iconoAlfa = 1, 1
    o.popupTam, o.popupSeg = 1, nil
    o.raresTam = 1
    redibujarIconos()
    redibujarRares()
    aplicar()
    aplicarLetra()
    refrescar()
  end)
  v:SetScript("OnShow", refrescar)
  v:Hide()
  WowF.cerrarConEsc("wowFOpciones") -- Esc la cierra
  return v
end

function WowF.abrirOpciones()
  crear()
  if v:IsShown() then v:Hide() else v:Show(); refrescar() end
end
WowF._ventanaOpciones = function() return v, deslizTamano, deslizFondo, botonRestablecer, casillaBotin, botonEntrenadores, deslizLetra end -- para las pruebas
WowF._botonAbrirEn = function() return botonAbrirEn end
WowF._popupsOpciones = function() return deslizPopupTam, botonesDuracion end -- para las pruebas (13-oct)
-- 19-oct: abrir Ajustes directo en una pestana (clic derecho en el boton Rares del mapa -> "mapa")
function WowF.abrirOpcionesEn(p)
  WowFExportarDB.opcionesPestana = p
  crear(); v:Show(); refrescar()
end
function WowF.refrescarOpciones() if v and v:IsShown() then refrescar() end end -- el boton Rares del mapa y /wowf rares
WowF._raresOpciones = function() return etRares, botonesRares, deslizRaresTam end -- para las pruebas (19-oct)
WowF._deslizIconos = function() return deslizIconoTam, deslizIconoAlfa end -- para las pruebas (13-oct) -- para las pruebas (11-oct, djextra)

-- ===================== Menu del juego (Opciones > AddOns) =====================
-- Una hoja con un boton que abre la ventana de arriba (asi los cambios se ven al momento con el juego detras)
local function registrarEnMenu()
  local hoja = CreateFrame("Frame")
  hoja.name = "Forever Leveling Guide"
  local t = hoja:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", 16, -16)
  t:SetText("Forever Leveling Guide")
  if WowF.estilo and WowF.estilo.titulo then pcall(WowF.estilo.titulo, hoja, t, 18) end
  local d = hoja:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  if WowF.estilo and WowF.estilo.cuerpo then pcall(WowF.estilo.cuerpo, hoja, d, 12) end
  d:SetPoint("TOPLEFT", 16, -44)
  d:SetWidth(520)
  d:SetJustifyH("LEFT")
  local b = CreateFrame("Button", nil, hoja, "UIPanelButtonTemplate")
  WowF.estilo.boton(b, "brasa")
  b:SetSize(200, 24)
  b:SetPoint("TOPLEFT", 16, -80)
  b:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() and HideUIPanel and not WowF.interfazMando() then pcall(HideUIPanel, SettingsPanel) end
    if InterfaceOptionsFrame and InterfaceOptionsFrame.IsShown and InterfaceOptionsFrame:IsShown() and HideUIPanel and not WowF.interfazMando() then pcall(HideUIPanel, InterfaceOptionsFrame) end
    crear(); v:Show(); refrescar()
  end)
  -- 13-oct: al lado, la Guia del addon
  local bg = CreateFrame("Button", nil, hoja, "UIPanelButtonTemplate")
  WowF.estilo.boton(bg, "cuero")
  bg:SetSize(200, 24)
  bg:SetPoint("LEFT", b, "RIGHT", 10, 0)
  bg:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() and HideUIPanel and not WowF.interfazMando() then pcall(HideUIPanel, SettingsPanel) end
    if InterfaceOptionsFrame and InterfaceOptionsFrame.IsShown and InterfaceOptionsFrame:IsShown() and HideUIPanel and not WowF.interfazMando() then pcall(HideUIPanel, InterfaceOptionsFrame) end
    if WowF.abrirGuia then WowF.abrirGuia() end
  end)
  hoja:SetScript("OnShow", function()
    d:SetText(L("Tamaño de las ventanas, tamaño de letra y opacidad del fondo. También con /wowf ajustes.", "Window size, text size and background opacity. Also with /wowf settings."))
    b:SetText(L("Abrir ajustes", "Open settings"))
    bg:SetText(L("Guía del addon", "Addon guide"))
  end)
  local ok = Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory and pcall(function()
    local cat = Settings.RegisterCanvasLayoutCategory(hoja, hoja.name)
    Settings.RegisterAddOnCategory(cat)
  end)
  if not ok and InterfaceOptions_AddCategory then pcall(InterfaceOptions_AddCategory, hoja) end
end

-- ===================== Al entrar y /wowf opciones =====================
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  pcall(registrarEnMenu)
  aplicar()
  -- 12-oct: las letras creadas antes de leer los ajustes guardados toman el tamano elegido
  if WowF.estilo and WowF.estilo.reaplicarLetras then pcall(WowF.estilo.reaplicarLetras) end
  -- Por si alguna ventana coloca su fondo despues de entrar
  if C_Timer and C_Timer.After then C_Timer.After(2, aplicar) end
end)

local ordenAnterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden = ((mensaje or ""):match("^%s*(%S*)") or ""):lower()
  if orden == "ajustes" or orden == "opciones" or orden == "options" or orden == "config" or orden == "settings" or orden == "opcion" then
    WowF.abrirOpciones()
    return
  end
  return ordenAnterior and ordenAnterior(mensaje)
end

-- 12-oct: si Ajustes esta abierta al cambiar de idioma, se reescribe al momento
WowF.alReidiomar = WowF.alReidiomar or {}
table.insert(WowF.alReidiomar, function() if v and v:IsShown() then refrescar() end end)
