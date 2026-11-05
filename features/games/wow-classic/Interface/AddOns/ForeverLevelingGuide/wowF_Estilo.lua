-- Forever Leveling Guide: estilo comun de todas las ventanas (11-oct, rediseno elegido por Andy: "1 + 4").
-- Por fuera, del Grimorio: tapa de cuero con filete y tachuelas doradas, pestanas como cintas, sello de cera con el nivel.
-- Por dentro, del Estandarte: losa de piedra, estandarte de tu faccion con el escudo de tu clase, acento brasa.
-- Cada ventana llama a WowF.estilo.marco(f, tipo) en vez de su SetBackdrop; los botones, a WowF.estilo.boton(b, tipo).
-- Fuentes (licencia SIL OFL, en Fuentes/): Metamorphous (titulos viejos), Cinzel (marca, titulos y boton principal),
-- Signika (botones viejos), Alegreya Sans (cuerpo, desde el rediseno por tarjetas del 11-oct).
-- Texturas propias en Texturas/ (generadas, no editar a mano): estandarte, sello, escudo y tachuela.
--
-- ===== Ayudantes del rediseno por tarjetas (11-oct, maquetas progreso/talentos/botones aprobadas por Andy) =====
--   E.fuentes.cuerpo / cuerpoMedio / cuerpoNegrita : Alegreya Sans 400 / 500 / 700   (E.letra(fs, "cuerpoMedio", 14))
--   E.boton(b, tipo, tam, chico) : tipos nuevos
--       "estandarte" (principal: rojo #6b1414, borde oro, Cinzel 13; hover / pulsado / apagado; luz arriba y sombra abajo)
--       "secundario" (piedra #33302c con filete de oro, Alegreya 14)   "terciario" (enlace dorado con subrayado de 1 px)
--       "toggle"     (conmutador: E.toggle(b, activo); activo = cera #8f1d1a)
--       chico = true -> alto 28 (si no, 34). Los viejos (brasa, cuero, cinta, suave) siguen igual.
--   E.botonActivo(b, si) : habilita o apaga y repinta.   E.botonAncho(b, chico, minimo) : ancho justo para el texto.
--   E.tarjeta(padre, { variante = "principal"|"recomendada"|"hundida", fondo, alfa, acento }) : piedra2 #2a2724, borde #4a443c;
--       principal = linea de 3 px brasa arriba, recomendada = 3 px oro. E.tarjetaVariante(t, variante) la cambia despues.
--   E.chip(padre, texto, color) -> Frame (alto 20, 11 px, mayusculas) con :poner(texto, color); color "verde"|"oro"|"brasa"|"gris"
--   E.barra(padre, ancho, color) -> Frame (alto 8) con :poner(valor, max); color "brasa"|"verde"
--   E.icono(padre, tam, color) -> Frame con .tex (SetTexCoord 0.07-0.93) y borde de 1 px; :poner(textura, color, gris)
--       color del borde: nil (#6b5a3a) | "verde" | "oro" | "gris"; gris = true desatura.
--   E.retrato(padre, tam) -> Frame redondo (SetMask con pcall; si no hay, cuadrado) con borde de 2 px oro2; :poner(textura)
--   E.rotulo(padre, fs, color, tam) -> FontString de rotulo (".eti": 11 px negrita, MAYUSCULAS espaciadas, brasa por defecto);
--       pon el texto con E.ponerRotulo(fs, texto) (mayusculas + espaciado).
--   E.h2(padre, fs, tam) / E.h3(padre, fs, tam) : Cinzel 22 / 16 en blanco hueso.
--   E.texto(padre, fs, tam, color, peso) : Alegreya (peso "regular"|"medio"|"negrita"; tam 14 por defecto, color texto).
--   E.cifra(padre) -> Frame con :poner(numero, rotulo) (24 px negrita + rotulo de 10 px).

WowF = WowF or {}
local E = {}
WowF.estilo = E

local RAIZ = "Interface\\AddOns\\ForeverLevelingGuide\\"
local BLANCO8 = "Interface\\Buttons\\WHITE8X8"
E.fuentes = { titulo = RAIZ .. "Fuentes\\Metamorphous-Regular.ttf", marca = RAIZ .. "Fuentes\\Cinzel-Bold.ttf", boton = RAIZ .. "Fuentes\\Signika-SemiBold.ttf",
  cuerpo = RAIZ .. "Fuentes\\AlegreyaSans-Regular.ttf", cuerpoMedio = RAIZ .. "Fuentes\\AlegreyaSans-Medium.ttf", cuerpoNegrita = RAIZ .. "Fuentes\\AlegreyaSans-Bold.ttf" }
E.texturas = { estandarte = RAIZ .. "Texturas\\estandarte", sello = RAIZ .. "Texturas\\sello", escudo = RAIZ .. "Texturas\\escudo", tachuela = RAIZ .. "Texturas\\tachuela",
  cinta = RAIZ .. "Texturas\\cinta", banderin = RAIZ .. "Texturas\\banderin", escudo2 = RAIZ .. "Texturas\\escudo2", aro = RAIZ .. "Texturas\\aro" }

-- Colores (los mismos de la maqueta aprobada)
local C = {
  cuero = { 0.133, 0.082, 0.055 }, cuero2 = { 0.227, 0.153, 0.102 }, oro = { 0.847, 0.706, 0.408 }, oro2 = { 0.549, 0.42, 0.18 },
  cera = { 0.561, 0.114, 0.102 }, cera2 = { 0.722, 0.196, 0.165 }, piedra = { 0.122, 0.114, 0.106 }, piedra2 = { 0.165, 0.153, 0.141 },
  borde = { 0.29, 0.267, 0.235 }, sangre = { 0.541, 0.086, 0.086 }, brasa = { 1, 0.541, 0.165 }, texto = { 0.937, 0.906, 0.855 },
  -- 12-oct (legibilidad): grises mas claros; antes tenue 0.639/0.604/0.549 y apagado 0.49/0.459/0.416 (se leian poco a 100 %)
  tenue = { 0.769, 0.722, 0.659 }, oscuro = { 0.165, 0.071, 0 },
  horda = { 0.62, 0.09, 0.09 }, alianza = { 0.13, 0.25, 0.55 },
  -- 11-oct (rediseno por tarjetas)
  orocl = { 0.953, 0.863, 0.627 }, piedra3 = { 0.2, 0.188, 0.173 }, apagado = { 0.58, 0.545, 0.494 }, verde = { 0.486, 0.765, 0.353 },
  verdef = { 0.11, 0.149, 0.09 }, verdeBorde = { 0.247, 0.42, 0.165 }, bordeIcono = { 0.42, 0.353, 0.227 }, hundida = { 0.098, 0.09, 0.082 },
  negro = { 0.114, 0.106, 0.098 }, oroFondo = { 0.165, 0.129, 0.078 },
}
E.color = C
-- Los mismos colores como codigo de texto (para |c...|r)
E.cod = { oro = "|cffd8b468", brasa = "|cffff8a2a", tenue = "|cffc4b8a8", texto = "|cffefe7da", cera = "|cffb8322a",
  orocl = "|cfff3dca0", verde = "|cff7cc35a", apagado = "|cff948b7e" }

local function rgba(c, a) return c[1], c[2], c[3], a or 1 end

-- ===== Tema por faccion (11-oct, Andy) =====
-- E.tema() -> paleta de ACENTO segun UnitFactionGroup("player") (con pcall). Horde (y neutral/desconocido) = la aprobada
-- (rojo #6b1414 + brasa); Alliance = la misma estructura en azul real. Bordes y texto en oro, iguales en las dos.
--   .faccion "Horde"|"Alliance"; .estandarte / .estandarteHover / .estandartePulsado (fondo del boton principal);
--   .toggleOn (conmutador activo); .linea (3 px de la tarjeta principal); .ahora (chip AHORA y nodo de "ahora"),
--   .ahoraLetra (letra sobre .ahora), .ahoraBorde; .cod (codigo |c del acento para texto); .emblema (textura del cliente)
--   .filo (luz del borde de arriba de tarjetas y ventanas); .resplandor (brillo al pasar el raton)
local TEMAS = {
  Horde = { faccion = "Horde", estandarte = { 0.42, 0.078, 0.078 }, estandarteHover = { 0.522, 0.102, 0.102 }, estandartePulsado = { 0.31, 0.051, 0.051 },
    toggleOn = { 0.561, 0.114, 0.102 }, linea = { 1, 0.541, 0.165 }, ahora = { 0.561, 0.114, 0.102 }, ahoraLetra = { 1, 0.86, 0.6 },
    ahoraBorde = { 0.847, 0.706, 0.408 }, -- 12-oct (Andy: "nada de botones naranja y negro"): AHORA en rojo de la Horde con letra oro
    cod = "|cffff8a2a", emblema = "Interface\\FriendsFrame\\PlusManz-Horde",
    filo = { 0.96, 0.78, 0.47 }, resplandor = { 1, 0.55, 0.18 } },
  Alliance = { faccion = "Alliance", estandarte = { 0.078, 0.188, 0.42 }, estandarteHover = { 0.11, 0.247, 0.541 }, estandartePulsado = { 0.055, 0.137, 0.314 },
    toggleOn = { 0.11, 0.247, 0.541 }, linea = { 0.184, 0.373, 0.702 }, ahora = { 0.184, 0.373, 0.702 }, ahoraLetra = { 0.953, 0.863, 0.627 },
    ahoraBorde = { 0.522, 0.659, 0.902 }, cod = "|cff6f9be6", emblema = "Interface\\FriendsFrame\\PlusManz-Alliance",
    filo = { 0.78, 0.85, 1 }, resplandor = { 0.36, 0.6, 1 } },
}
E.temas = TEMAS
function E.tema()
  local f
  if UnitFactionGroup then local ok, x = pcall(UnitFactionGroup, "player"); if ok then f = x end end
  if type(f) ~= "string" then f = nil end
  return TEMAS[f or ""] or TEMAS.Horde
end

-- ===== Tamano de letra (12-oct, Andy: "en 100 % es demasiado chiquito y no se lee absolutamente nada") =====
-- Todo pasa por E.letra: nada por debajo de E.LETRA_MIN (11) y se multiplica por el ajuste "Tamano de letra"
-- (WowFExportarDB.opciones.letra, 0.9-1.4, por defecto 1.1). Los botones y los titulos grandes (>= 18) crecen a la mitad
-- (para no salirse de su caja); la letra con borde (OUTLINE: mapa y placas) solo respeta el minimo.
-- E.tamFinal(tam, tipo, borde) = el tamano que de verdad se pone (usarlo para calcular altos y anchos).
-- 12-oct (legibilidad a 100 %): minimo 12 (13 con el ajuste por defecto 1.1); el cuerpo Regular pasa a Medium (el Regular
-- es fino y se pierde sobre el arte) y toda letra sin borde lleva sombra negra de 1 px (mas nitida que OUTLINE a tamanos chicos).
E.LETRA_MIN, E.LETRA_ESC_MIN, E.LETRA_ESC_MAX, E.LETRA_ESC_DEF = 12, 0.9, 1.4, 1.1
function E.escalaLetra()
  local o = type(WowFExportarDB) == "table" and type(WowFExportarDB.opciones) == "table" and WowFExportarDB.opciones or nil
  local x = o and tonumber(o.letra)
  if not x then return E.LETRA_ESC_DEF end
  return math.max(E.LETRA_ESC_MIN, math.min(E.LETRA_ESC_MAX, x))
end
local function factorLetra(tam, tipo, borde, boton)
  if borde and borde ~= "" then return 0 end
  if boton or tam >= 18 then return 0.5 end
  return 1
end
-- 12-oct (Andy: "cuando pones mas grandes las letras... se van completamente de sus tarjetas"): la letra se pone SIEMPRE
-- con la escala de fabrica (110 %); lo que el jugador sube o baja en "Tamano de letra" agranda la VENTANA entera
-- (E.escalaVentana, en wowF_Opciones.aplicar): letra y tarjetas crecen juntas y nada se sale de su sitio.
function E.escalaVentana() return E.escalaLetra() / E.LETRA_ESC_DEF end
function E.tamFinal(tam, tipo, borde, boton)
  tam = math.max(E.LETRA_MIN, tonumber(tam) or 12)
  local f = factorLetra(tam, tipo, borde, boton)
  local esc = 1 + (E.LETRA_ESC_DEF - 1) * f
  return math.max(E.LETRA_MIN, math.floor(tam * esc + 0.5))
end
-- Letras ya puestas (para cambiar el tamano al momento desde Ajustes). Claves debiles: no retiene nada.
-- Tope de 4000: fengari (simulador) no tiene tablas debiles; al pasarlo se empieza de cero (lo que se repinta se vuelve a anotar).
local letrasVivas, nLetras = setmetatable({}, { __mode = "k" }), 0
local function ponerLetra(fs, tipo, tam, borde, boton)
  local archivo = (tipo == "cuerpo" and E.fuentes.cuerpoMedio) or E.fuentes[tipo] or E.fuentes.boton
  local ok, bien = pcall(fs.SetFont, fs, archivo, E.tamFinal(tam or 12, tipo, borde, boton), borde or "")
  if ok and bien == false and fs.SetFontObject then pcall(fs.SetFontObject, fs, "GameFontNormal") end
  if (not borde or borde == "") and fs.SetShadowOffset then
    pcall(fs.SetShadowOffset, fs, 1, -1)
    if fs.SetShadowColor then pcall(fs.SetShadowColor, fs, 0, 0, 0, 1) end
  end
end
-- Letra propia; si el archivo no carga (addon a medias), se queda la letra del juego. boton = true: crece a la mitad.
function E.letra(fs, tipo, tam, borde, boton)
  if not fs or not fs.SetFont then return end
  if not letrasVivas[fs] then
    nLetras = nLetras + 1
    if nLetras > 4000 then letrasVivas, nLetras = setmetatable({}, { __mode = "k" }), 1 end
  end
  letrasVivas[fs] = { tipo, tam or 12, borde, boton }
  ponerLetra(fs, tipo, tam or 12, borde, boton)
end
-- Vuelve a poner todas las letras con el ajuste actual (lo llama Ajustes al mover "Tamano de letra")
function E.reaplicarLetras()
  for fs, d in pairs(letrasVivas) do pcall(ponerLetra, fs, d[1], d[2], d[3], d[4]) end
end

local function textura(padre, capa, sub, color, a)
  local t = padre:CreateTexture(nil, capa, nil, sub)
  if color and t.SetColorTexture then t:SetColorTexture(rgba(color, a)) end
  return t
end
E.textura = textura

-- ===================== Esquinas redondeadas y luz (11-oct, Andy: "que no sea tan cuadrado... con algun efectico de luz") =====================
-- Texturas propias de Texturas/ (generadas por generar-texturas.js, TGA 32x32 blancos con alfa): cada cuarto del archivo es una
-- esquina; el kit las corta en 9 trozos a mano (SetTextureSliceMargins no: su tamano de esquina en el cliente no es fiable).
--   relleno (esquina llena, cualquier radio), aro4/5/6/8 (borde de 1 px), sombra5/6/8 (sombra suave fuera),
--   halo5/6/8 (resplandor ADD al pasar el raton), brillo (luz suave de arriba).
-- Si un archivo no carga, la capa vuelve al aspecto de antes (relleno y borde cuadrados; sin sombra ni halo).
-- Radios: ventanas 8, tarjetas 6, botones 5, chips 4. Nunca SetTexCoord sobre una textura con mascara (aqui no hay mascaras).
local function ruta(n) return RAIZ .. "Texturas\\" .. n end
for _, n in ipairs({ "relleno", "aro4", "aro5", "aro6", "aro8", "sombra5", "sombra6", "sombra8", "halo5", "halo6", "halo8", "brillo" }) do E.texturas[n] = ruta(n) end
local MEDIO1, MEDIO2 = 15.5 / 32, 16.5 / 32
local function ponerArchivo(t, archivo)
  if not t or not t.SetTexture or not archivo then return false end
  local ok, bien = pcall(t.SetTexture, t, archivo)
  return ok and bien ~= false
end
local function mezclar(a, b, f) return { a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f } end
-- Degradado con el API nuevo (SetGradient + CreateColor) o el viejo (SetGradientAlpha). VERTICAL: c1 abajo, c2 arriba.
local function degradar(t, orient, c1, a1, c2, a2)
  if t.SetGradient and CreateColor then
    if pcall(t.SetGradient, t, orient, CreateColor(c1[1], c1[2], c1[3], a1), CreateColor(c2[1], c2[2], c2[3], a2)) then return true end
  end
  if t.SetGradientAlpha then
    if pcall(t.SetGradientAlpha, t, orient, c1[1], c1[2], c1[3], a1, c2[1], c2[2], c2[3], a2) then return true end
  end
  return false
end

-- Capa redonda: se usa como una textura (SetColorTexture, SetVertexColor, SetAlpha, Show, Hide, IsShown y, con mover,
-- SetPoint/ClearAllPoints/SetAllPoints/SetSize), asi sustituye sin romper nada a los bordes y fondos de antes.
--   tipo "relleno": 4 esquinas del TGA + 3 bandas lisas   "aro": 4 esquinas + 4 rayas de 1 px   "suave": 8 trozos del TGA
--   o = { padre, nivel, sub, tipo, archivo, tam (px de cada esquina), fuera (px que sale del marco), mover, modo ("ADD") }
--   .filo (color) + .mezcla (0-1): en un aro, la luz de arriba (esquinas y raya de arriba; los lados en degradado).
local Capa = {}
Capa.__index = Capa
local ESQUINAS = { TL = { "TOPLEFT", -1, 1, 0, 0.5, 0, 0.5 }, TR = { "TOPRIGHT", 1, 1, 0.5, 1, 0, 0.5 },
  BL = { "BOTTOMLEFT", -1, -1, 0, 0.5, 0.5, 1 }, BR = { "BOTTOMRIGHT", 1, -1, 0.5, 1, 0.5, 1 } }
local function capa(o)
  local p = o.padre
  local cp = setmetatable({ piezas = {}, conArchivo = {}, ocultas = {}, tipo = o.tipo, color = { 1, 1, 1 }, a = 1, visible = true, padre = p }, Capa)
  local ancla = p
  if o.mover then
    cp.caja = p:CreateTexture(nil, o.nivel, nil, o.sub)
    if cp.caja.SetColorTexture then cp.caja:SetColorTexture(0, 0, 0, 0) end
    cp.caja:SetAllPoints(p)
    ancla = cp.caja
  end
  local K, O = o.tam, o.fuera or 0
  local function pieza(clave)
    local t = p:CreateTexture(nil, o.nivel, nil, o.sub)
    if o.modo and t.SetBlendMode then pcall(t.SetBlendMode, t, o.modo) end
    cp.piezas[clave] = t
    return t
  end
  -- Esquinas (la primera dice si el archivo carga)
  local hayArchivo = true
  for _, k in ipairs({ "TL", "TR", "BL", "BR" }) do
    local e, t = ESQUINAS[k], pieza(k)
    if hayArchivo then hayArchivo = ponerArchivo(t, o.archivo) end
    if hayArchivo then
      cp.conArchivo[k] = true
      if t.SetTexCoord then pcall(t.SetTexCoord, t, e[4], e[5], e[6], e[7]) end
    end
    t:SetSize(K, K)
    t:SetPoint(e[1], ancla, e[1], e[2] * O, e[3] * O)
  end
  local P = cp.piezas
  if not hayArchivo then
    -- Respaldo: el aspecto de antes. Relleno = esquinas lisas (cuadrado); aro = rayas a lo largo; suave = nada.
    cp.respaldo = true
    for k in pairs(ESQUINAS) do
      cp.conArchivo[k] = nil
      if o.tipo ~= "relleno" then cp.ocultas[k] = true; P[k]:Hide() end
    end
    if o.tipo == "suave" then cp.apagada = true end
  end
  if o.tipo == "relleno" then
    local c = pieza("C"); c:SetPoint("TOPLEFT", P.TL, "TOPRIGHT"); c:SetPoint("BOTTOMRIGHT", P.BR, "BOTTOMLEFT")
    local l = pieza("L"); l:SetPoint("TOPLEFT", P.TL, "BOTTOMLEFT"); l:SetPoint("BOTTOMRIGHT", P.BL, "TOPRIGHT")
    local r = pieza("R"); r:SetPoint("TOPLEFT", P.TR, "BOTTOMLEFT"); r:SetPoint("BOTTOMRIGHT", P.BR, "TOPRIGHT")
  elseif o.tipo == "aro" then
    local t, b, l, r = pieza("T"), pieza("B"), pieza("L"), pieza("R")
    if cp.respaldo then
      t:SetPoint("TOPLEFT", ancla, "TOPLEFT"); t:SetPoint("TOPRIGHT", ancla, "TOPRIGHT")
      b:SetPoint("BOTTOMLEFT", ancla, "BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT", ancla, "BOTTOMRIGHT")
      l:SetPoint("TOPLEFT", ancla, "TOPLEFT"); l:SetPoint("BOTTOMLEFT", ancla, "BOTTOMLEFT")
      r:SetPoint("TOPRIGHT", ancla, "TOPRIGHT"); r:SetPoint("BOTTOMRIGHT", ancla, "BOTTOMRIGHT")
    else
      t:SetPoint("TOPLEFT", P.TL, "TOPRIGHT"); t:SetPoint("TOPRIGHT", P.TR, "TOPLEFT")
      b:SetPoint("BOTTOMLEFT", P.BL, "BOTTOMRIGHT"); b:SetPoint("BOTTOMRIGHT", P.BR, "BOTTOMLEFT")
      l:SetPoint("TOPLEFT", P.TL, "BOTTOMLEFT"); l:SetPoint("BOTTOMLEFT", P.BL, "TOPLEFT")
      r:SetPoint("TOPRIGHT", P.TR, "BOTTOMRIGHT"); r:SetPoint("BOTTOMRIGHT", P.BR, "TOPRIGHT")
    end
    t:SetHeight(1); b:SetHeight(1); l:SetWidth(1); r:SetWidth(1)
  else
    local bordes = { T = { "TL", "TOPRIGHT", "TR", "BOTTOMLEFT", MEDIO1, MEDIO2, 0, 0.5 }, B = { "BL", "TOPRIGHT", "BR", "BOTTOMLEFT", MEDIO1, MEDIO2, 0.5, 1 },
      L = { "TL", "BOTTOMLEFT", "BL", "TOPRIGHT", 0, 0.5, MEDIO1, MEDIO2 }, R = { "TR", "BOTTOMLEFT", "BR", "TOPRIGHT", 0.5, 1, MEDIO1, MEDIO2 } }
    for k, d in pairs(bordes) do
      local t = pieza(k)
      t:SetPoint("TOPLEFT", P[d[1]], d[2]); t:SetPoint("BOTTOMRIGHT", P[d[3]], d[4])
      if not cp.respaldo and ponerArchivo(t, o.archivo) then
        cp.conArchivo[k] = true
        if t.SetTexCoord then pcall(t.SetTexCoord, t, d[5], d[6], d[7], d[8]) end
      else cp.ocultas[k] = true; t:Hide() end
    end
  end
  if cp.apagada then for _, t in pairs(P) do t:Hide() end end
  return cp
end
function Capa:pintar()
  local base, a = self.color, self.a
  local luz = self.filo and mezclar(base, self.filo, self.mezcla or 0.5) or nil
  for k, t in pairs(self.piezas) do
    local c = (luz and (k == "TL" or k == "TR" or k == "T")) and luz or base
    if self.conArchivo[k] then
      if t.SetVertexColor then pcall(t.SetVertexColor, t, c[1], c[2], c[3], a) end
    elseif luz and self.tipo == "aro" and (k == "L" or k == "R") then
      pcall(t.SetColorTexture, t, 1, 1, 1, 1)
      if not degradar(t, "VERTICAL", base, a, luz, a) then pcall(t.SetColorTexture, t, base[1], base[2], base[3], a) end
    elseif t.SetColorTexture then pcall(t.SetColorTexture, t, c[1], c[2], c[3], a) end
  end
end
function Capa:SetColorTexture(r, g, b, a)
  self.color = { tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1 }
  self.a = tonumber(a) or 1
  self:pintar()
end
Capa.SetVertexColor = Capa.SetColorTexture
function Capa:GetColor() return self.color[1], self.color[2], self.color[3], self.a end
function Capa:SetAlpha(x) self.alfa = x; for _, t in pairs(self.piezas) do if t.SetAlpha then pcall(t.SetAlpha, t, x) end end end
function Capa:GetAlpha() return self.alfa or 1 end
function Capa:Show()
  self.visible = true
  if self.apagada then return end
  for k, t in pairs(self.piezas) do if not self.ocultas[k] then t:Show() end end
end
function Capa:Hide() self.visible = false; for _, t in pairs(self.piezas) do t:Hide() end end
function Capa:IsShown() return self.visible end
function Capa:SetShown(si) if si then self:Show() else self:Hide() end end
function Capa:SetBlendMode(m) for _, t in pairs(self.piezas) do if t.SetBlendMode then pcall(t.SetBlendMode, t, m) end end end
-- Posicion (solo con o.mover: se mueve la caja invisible y los trozos la siguen)
function Capa:SetPoint(...) if self.caja then self.caja:SetPoint(...) end end
function Capa:ClearAllPoints() if self.caja then self.caja:ClearAllPoints() end end
function Capa:SetAllPoints(rel) if self.caja then self.caja:SetAllPoints(rel or self.padre) end end
function Capa:SetSize(w, h) if self.caja then self.caja:SetSize(w, h) end end
function Capa:SetWidth(w) if self.caja then self.caja:SetWidth(w) end end
function Capa:SetHeight(h) if self.caja then self.caja:SetHeight(h) end end
E.capa = capa

-- Barra de acento con luz: 2-3 px a lo ancho, metida del borde lo que mide la esquina, que se apaga hacia los lados.
-- Se usa como una textura (SetColorTexture, Show, Hide, IsShown, SetAlpha).
local Barra = {}
Barra.__index = Barra
local function barraLuz(padre, nivel, sub, color, alto, margen, y, ancla)
  ancla = ancla or padre
  local br = setmetatable({ visible = true }, Barra)
  br.i = padre:CreateTexture(nil, nivel, nil, sub)
  br.d = padre:CreateTexture(nil, nivel, nil, sub)
  br.i:SetPoint("TOPLEFT", ancla, "TOPLEFT", margen, y); br.i:SetPoint("TOPRIGHT", ancla, "TOP", 0, y); br.i:SetHeight(alto)
  br.d:SetPoint("TOPLEFT", ancla, "TOP", 0, y); br.d:SetPoint("TOPRIGHT", ancla, "TOPRIGHT", -margen, y); br.d:SetHeight(alto)
  br:SetColorTexture(color[1], color[2], color[3], 1)
  return br
end
function Barra:SetColorTexture(r, g, b, a)
  local c = { tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1 }
  a = tonumber(a) or 1
  pcall(self.i.SetColorTexture, self.i, 1, 1, 1, 1); pcall(self.d.SetColorTexture, self.d, 1, 1, 1, 1)
  if not degradar(self.i, "HORIZONTAL", c, a * 0.2, c, a) then pcall(self.i.SetColorTexture, self.i, c[1], c[2], c[3], a) end
  if not degradar(self.d, "HORIZONTAL", c, a, c, a * 0.2) then pcall(self.d.SetColorTexture, self.d, c[1], c[2], c[3], a) end
end
function Barra:Show() self.visible = true; self.i:Show(); self.d:Show() end
function Barra:Hide() self.visible = false; self.i:Hide(); self.d:Hide() end
function Barra:IsShown() return self.visible end
function Barra:SetAlpha(x) pcall(self.i.SetAlpha, self.i, x); pcall(self.d.SetAlpha, self.d, x) end
E.barraLuz = barraLuz

-- Forma completa de una ventana o tarjeta: sombra suave debajo, relleno redondo, brillo de arriba y borde con filo de luz.
-- Sustituye al backdrop: SetBackdropColor / SetBackdropBorderColor (y sus Get) del marco pasan a la forma redonda.
--   o = { radio, fondo, alfa, borde, bordeAlfa, filo, mezcla, sombra (false = sin), sombraAlfa, brillo (alfa; nil = sin) }
local SOMBRA = { [5] = { "sombra5", 5 }, [6] = { "sombra6", 8 }, [8] = { "sombra8", 10 } }
local function forma(f, o)
  local r = o.radio
  local fm = {}
  if o.sombra ~= false and SOMBRA[r] then
    local s = SOMBRA[r]
    fm.sombra = capa({ padre = f, nivel = "BACKGROUND", sub = -8, tipo = "suave", archivo = ruta(s[1]), tam = r + s[2], fuera = s[2] })
    fm.sombra:SetColorTexture(0, 0, 0, o.sombraAlfa or 0.55)
  end
  fm.fondo = capa({ padre = f, nivel = "BACKGROUND", sub = -7, tipo = "relleno", archivo = ruta("relleno"), tam = r })
  fm.fondo:SetColorTexture(rgba(o.fondo, o.alfa or 1))
  if o.brillo then
    local b = f:CreateTexture(nil, "BACKGROUND", nil, -5)
    if ponerArchivo(b, ruta("brillo")) then
      b:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1); b:SetPoint("BOTTOMRIGHT", f, "RIGHT", -1, 0)
      if b.SetVertexColor then pcall(b.SetVertexColor, b, 1, 0.94, 0.82, o.brillo) end
      fm.brillo = b
    else b:Hide() end
  end
  fm.borde = capa({ padre = f, nivel = "BORDER", sub = -6, tipo = "aro", archivo = ruta("aro" .. r), tam = r })
  fm.borde.filo, fm.borde.mezcla = o.filo, o.mezcla
  fm.borde:SetColorTexture(rgba(o.borde, o.bordeAlfa or 1))
  -- El backdrop cuadrado se quita y sus colores van a la forma
  f._forma = fm
  if f.SetBackdrop then pcall(f.SetBackdrop, f, nil) end
  f.SetBackdrop = function() end
  f.SetBackdropColor = function(_, rr, g, b, a) fm.fondo:SetColorTexture(rr, g, b, a) end
  f.GetBackdropColor = function() return fm.fondo:GetColor() end
  f.SetBackdropBorderColor = function(_, rr, g, b, a) fm.borde:SetColorTexture(rr, g, b, a) end
  f.GetBackdropBorderColor = function() return fm.borde:GetColor() end
  return fm
end
E.forma = forma
-- El backdrop cuadrado de antes (respaldo si la forma redonda falla)
local function backdropViejo(f, fondo, alfa, borde)
  if not f.SetBackdrop then return end
  pcall(f.SetBackdrop, f, { bgFile = BLANCO8, edgeFile = BLANCO8, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  pcall(f.SetBackdropColor, f, rgba(fondo, alfa))
  pcall(f.SetBackdropBorderColor, f, rgba(borde, 1))
end

-- Raya de 1 px (o del grosor pedido) a lo ancho, a la altura y del marco
function E.raya(padre, y, color, alfa, grosor, izq, der)
  local r = textura(padre, "ARTWORK", nil, color or C.oro2, alfa or 0.8)
  r:SetPoint("TOPLEFT", izq or 14, y)
  r:SetPoint("TOPRIGHT", -(der or 14), y)
  r:SetHeight(grosor or 1)
  return r
end

-- Tachuelas doradas en las 4 esquinas de un marco
local function tachuelas(f, d, lista)
  for _, punto in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
    local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetTexture(E.texturas.tachuela)
    t:SetSize(9, 9)
    local x = punto:find("LEFT") and d or -d
    local y = punto:find("TOP") and -d or d
    t:SetPoint("CENTER", f, punto, x, y)
    table.insert(lista, t)
  end
end

-- Filete fino (4 rayas) metido d px hacia dentro
local function filete(f, d, color, alfa, lista)
  -- 11-oct: aro redondo de 1 px (radio 4) con la luz de la faccion arriba; si el archivo no carga, las 4 rayas de antes
  local ok, aro = pcall(capa, { padre = f, nivel = "BORDER", sub = 2, tipo = "aro", archivo = ruta("aro4"), tam = 4, mover = true })
  if ok and aro and not aro.respaldo then
    aro:ClearAllPoints(); aro:SetPoint("TOPLEFT", f, "TOPLEFT", d, -d); aro:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -d, d)
    aro.filo, aro.mezcla = E.tema().filo, 0.6
    aro:SetColorTexture(rgba(color, alfa))
    table.insert(lista, aro)
    return
  end
  if ok and aro then aro:Hide() end
  local function r() local t = textura(f, "BORDER", 2, color, alfa); table.insert(lista, t); return t end
  local a, b, c, e = r(), r(), r(), r()
  a:SetPoint("TOPLEFT", d, -d); a:SetPoint("TOPRIGHT", -d, -d); a:SetHeight(1)
  b:SetPoint("BOTTOMLEFT", d, d); b:SetPoint("BOTTOMRIGHT", -d, d); b:SetHeight(1)
  c:SetPoint("TOPLEFT", d, -d); c:SetPoint("BOTTOMLEFT", d, d); c:SetWidth(1)
  e:SetPoint("TOPRIGHT", -d, -d); e:SetPoint("BOTTOMRIGHT", -d, d); e:SetWidth(1)
end

-- Fondo de una ventana. Tipos:
--   "tapa"  : ventana grande (Libro, Bienvenida, Novedades, Ajustes): cuero con filete y tachuelas, losa de piedra dentro.
--   "panel" : ventana de juego (panel, ruta, linea, ficha): forro de cuero fino, piedra dentro, franja roja arriba.
--   "aviso" : carteles y avisos: como "panel" pero la franja de arriba en brasa.
--   "losa"  : bloque de piedra dentro de otra ventana.
-- El fondo del backdrop es el cuero (Ajustes cambia su alfa); la piedra y lo demas siguen ese alfa con E.alfa.
function E.marco(f, tipo, opts)
  if not f then return end
  opts = opts or {}
  local piel = { tipo = tipo, partes = {} }
  f._piel = piel
  local grande = tipo == "tapa"
  local losa = tipo == "losa"
  local tema = E.tema()
  -- 11-oct: forma redonda (ventanas radio 8, losas radio 6) con sombra, brillo y filo de luz; si falla, el backdrop cuadrado de antes
  local fondo = losa and C.piedra2 or C.cuero
  local alfaFondo = opts.alfa or (losa and (E.alfaTarjeta or 0.8) or 0.97)
  local bordeColor = losa and C.borde or C.oro2
  local ok, fm = pcall(forma, f, { radio = losa and 6 or 8, fondo = fondo, alfa = alfaFondo, borde = bordeColor,
    filo = tema.filo, mezcla = losa and 0.45 or (tipo == "libro" and 0.5 or 0.85), sombraAlfa = losa and 0.45 or 0.7,
    brillo = losa and 0.05 or 0.07 })
  if ok and fm then
    piel.forma = fm
    if fm.sombra then table.insert(piel.partes, fm.sombra) end
    if fm.brillo then table.insert(piel.partes, fm.brillo) end
  else
    backdropViejo(f, fondo, alfaFondo, bordeColor)
  end
  if losa then
    if E.resplandorSiClic then E.resplandorSiClic(f, 6) end
    return piel
  end
  -- Pieza redonda que se usa como textura (con caja movible); si falla, la textura cuadrada de antes
  local function pieza(nivel, sub, radio, color, a)
    local okc, cp = pcall(capa, { padre = f, nivel = nivel, sub = sub, tipo = "relleno", archivo = ruta("relleno"), tam = radio, mover = true })
    if okc and cp then cp:SetColorTexture(rgba(color, a)); return cp end
    return textura(f, nivel, sub, color, a)
  end
  if tipo == "libro" then
    -- Libro (maqueta "hibrido"): cuero, filete dorado a 7 px, cuatro puntos de oro a 17 px y la losa de piedra a 16 px con su borde
    if f.SetBackdropBorderColor then pcall(f.SetBackdropBorderColor, f, 0.08, 0.05, 0.035, 1) end
    if f.SetToplevel then pcall(f.SetToplevel, f, true) end
    -- 11-oct (rediseno por tarjetas, comun.css): filete a 6 px, losa de piedra en x 14 / y 62 (arriba queda la marca y
    -- las cintas) con borde #3a2a1a, tachuelas de oro de 7 px a 12 px de cada esquina
    filete(f, 6, C.oro2, 0.9, piel.partes)
    local arriba = opts.arriba or 62
    local lado = opts.lado or 14
    -- El Panel (losaVisible) toma la parte de justo antes de la piedra como su borde: este orden no se cambia
    local borde = pieza("BACKGROUND", 1, 5, { 0.227, 0.165, 0.102 }, 1)
    borde:SetPoint("TOPLEFT", f, "TOPLEFT", lado, -arriba)
    borde:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -lado, lado)
    table.insert(piel.partes, borde)
    local piedra = pieza("BACKGROUND", 2, 4, C.piedra, 1)
    piedra:SetPoint("TOPLEFT", f, "TOPLEFT", lado + 1, -(arriba + 1))
    piedra:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(lado + 1), lado + 1)
    piel.piedra = piedra
    table.insert(piel.partes, piedra)
    for _, punto in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
      -- Puntos de oro redondos (el relleno entero es un circulo); si no carga, el cuadrito de antes
      local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
      if ponerArchivo(t, ruta("relleno")) then
        if t.SetVertexColor then pcall(t.SetVertexColor, t, rgba(C.oro, 1)) end
      elseif t.SetColorTexture then t:SetColorTexture(rgba(C.oro, 1)) end
      t:SetSize(7, 7)
      t:SetPoint("CENTER", f, punto, punto:find("LEFT") and 15 or -15, punto:find("TOP") and -15 or 15)
      table.insert(piel.partes, t)
    end
    return piel
  end
  -- Calidad de vida: la ventana en la que haces clic pasa al frente de las demas
  if f.SetToplevel then pcall(f.SetToplevel, f, true) end
  local dentro = opts.dentro or (grande and 9 or 4)
  if grande then filete(f, 5, C.oro2, 0.9, piel.partes) end
  local piedra = pieza("BACKGROUND", 2, 4, C.piedra, 1)
  piedra:SetPoint("TOPLEFT", f, "TOPLEFT", dentro, -dentro)
  piedra:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -dentro, dentro)
  piel.piedra = piedra
  table.insert(piel.partes, piedra)
  if not grande then
    -- Franja de arriba con luz (se apaga hacia los lados), dentro de las esquinas de la piedra
    local color = tipo == "aviso" and C.brasa or C.sangre
    local caja = rawget(piedra, "caja")
    local okb, franja = pcall(barraLuz, f, "BORDER", 3, color, 2, 4, 0, caja or piedra)
    if not okb or not franja then
      franja = textura(f, "BORDER", 3, color, 1)
      franja:SetPoint("TOPLEFT", piedra, "TOPLEFT", 0, 0)
      franja:SetPoint("TOPRIGHT", piedra, "TOPRIGHT", 0, 0)
      franja:SetHeight(2)
    end
    table.insert(piel.partes, franja)
  end
  if grande then tachuelas(f, 5, piel.partes) end
  return piel
end

-- Ajustes > opacidad: la piedra y el filete siguen al fondo (factor 0-1)
function E.alfa(f, factor)
  local piel = f and f._piel
  if type(piel) ~= "table" then return end
  if type(piel) ~= "table" or type(factor) ~= "number" then return end
  for _, t in ipairs(piel.partes) do if t.SetAlpha then pcall(t.SetAlpha, t, math.max(0.15, factor)) end end
  if piel.tapa and piel.tapa.SetAlpha then pcall(piel.tapa.SetAlpha, piel.tapa, math.max(0.15, factor)) end
end

-- Botones (sobre UIPanelButtonTemplate u otro Button). Tipos:
--   "brasa" : accion principal (relleno brasa, letra oscura)
--   "cuero" : secundario (cuero con borde dorado, letra dorada)
--   "cinta" : pestana del Libro (cuero; la abierta, en cera roja con letra dorada: E.cinta(b, true))
local function quitarPlantilla(b)
  for _, k in ipairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
    local t = rawget(b, k)
    if type(t) == "table" and t.SetAlpha then t:SetAlpha(0) end
  end
  for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
    local t = b[g] and b[g](b)
    if type(t) == "table" and t.SetAlpha then t:SetAlpha(0) end
  end
end
local COLORES_BOTON = {
  -- 11-oct (Andy: "ese fondo naranja es muy molesto"): los botones viejos toman los colores aprobados.
  -- brasa = principal (estandarte de tu faccion, borde oro); cuero = secundario (piedra con borde oro viejo)
  brasa = { fondo = { 0.42, 0.078, 0.078 }, borde = C.oro, letra = C.orocl },
  cuero = { fondo = C.piedra3, borde = C.oro2, letra = C.oro },
  cinta = { fondo = C.cuero2, borde = C.oro2, letra = C.oro },
  cintaOn = { fondo = C.cera, borde = C.oro, letra = C.oro },
  -- 11-oct (maqueta hibrido): botones secundarios sobre el estandarte, rojo oscuro con borde cobre
  suave = { fondo = { 0.29, 0.05, 0.05 }, borde = { 0.70, 0.45, 0.25 }, letra = { 1, 0.85, 0.76 } },
  -- 11-oct (maqueta botones.html): principal, secundario y conmutador, con sus estados
  estandarte = { fondo = { 0.42, 0.078, 0.078 }, borde = C.oro, letra = C.orocl },
  estandarteHover = { fondo = { 0.522, 0.102, 0.102 }, borde = { 0.941, 0.812, 0.518 }, letra = { 1, 0.945, 0.8 } },
  estandartePulsado = { fondo = { 0.31, 0.051, 0.051 }, borde = C.oro, letra = C.orocl },
  estandarteApagado = { fondo = { 0.18, 0.141, 0.125 }, borde = { 0.361, 0.29, 0.18 }, letra = { 0.49, 0.439, 0.369 } },
  secundario = { fondo = C.piedra3, borde = C.oro2, letra = C.oro },
  secundarioHover = { fondo = { 0.239, 0.224, 0.204 }, borde = C.oro, letra = C.orocl },
  secundarioPulsado = { fondo = { 0.141, 0.129, 0.118 }, borde = C.oro2, letra = C.oro },
  secundarioApagado = { fondo = C.piedra3, borde = C.borde, letra = { 0.435, 0.4, 0.345 } },
  toggle = { fondo = C.negro, borde = C.oro2, letra = C.tenue },
  toggleOn = { fondo = C.cera, borde = C.oro2, letra = C.orocl },
}
-- La piel guardada en el boton (solo si es una tabla: un campo que no existe no cuenta)
local function pielDe(b) local p = b and b._pielBoton; return type(p) == "table" and p or nil end
local function pintarBoton(b, clave)
  local pb = pielDe(b)
  local col = COLORES_BOTON[clave]
  if not pb or not col then return end
  -- 11-oct: el fondo de acento (principal y conmutador activo) sale del tema de tu faccion
  if clave == "brasa" then
    local t = E.tema()
    col = { fondo = t.estandarte or col.fondo, borde = col.borde, letra = col.letra }
  end
  if clave == "estandarte" or clave == "estandarteHover" or clave == "estandartePulsado" or clave == "toggleOn" then
    local t = E.tema()
    col = { fondo = t[clave] or col.fondo, borde = col.borde, letra = col.letra }
  end
  if pb.borde.SetColorTexture then pb.borde:SetColorTexture(rgba(col.borde, 1)) end
  if pb.fondo.SetColorTexture then pb.fondo:SetColorTexture(rgba(col.fondo, 1)) end
  local fs = b.GetFontString and b:GetFontString()
  if type(fs) == "table" and fs.SetTextColor then fs:SetTextColor(rgba(col.letra, 1)) end
end
-- Estados de los tipos nuevos: normal / Hover / Pulsado / Apagado (el texto baja 1 px al pulsar)
local CON_ESTADOS = { estandarte = true, secundario = true }
local function habilitado(b)
  if not b.IsEnabled then return true end
  local ok, si = pcall(b.IsEnabled, b)
  if not ok then return true end
  return si ~= false and si ~= nil and si ~= 0
end

-- Resplandor al pasar el raton (11-oct): halo ADD del color de tu faccion alrededor del borde + un velo muy suave dentro,
-- que aparece en 0,15 s (AnimationGroup Alpha). Se crea la primera vez que el raton entra (no gasta nada si nadie pasa).
-- No brilla con el boton apagado ni en el terciario (enlace de texto).
local function crearResplandor(f, r)
  local h = CreateFrame("Frame", nil, f)
  h:SetAllPoints(f)
  if h.EnableMouse then pcall(h.EnableMouse, h, false) end
  local tema = E.tema()
  local okh, halo = pcall(capa, { padre = h, nivel = "OVERLAY", sub = 6, tipo = "suave", archivo = ruta("halo" .. r), tam = r + 6, fuera = 6, modo = "ADD" })
  -- Sin la textura del halo no hay resplandor (queda el realce de antes)
  if not okh or not halo or halo.apagada then h:Hide(); return false end
  halo:SetColorTexture(rgba(tema.resplandor, 0.6))
  local okv, velo = pcall(capa, { padre = h, nivel = "OVERLAY", sub = 5, tipo = "relleno", archivo = ruta("relleno"), tam = r, modo = "ADD" })
  if okv and velo then velo:SetColorTexture(rgba(tema.resplandor, 0.06)) end
  h.halo, h.velo = halo, okv and velo or nil
  if h.CreateAnimationGroup then
    local oka, ag = pcall(h.CreateAnimationGroup, h)
    if oka and ag then
      local okn, an = pcall(ag.CreateAnimation, ag, "Alpha")
      if okn and an then
        pcall(an.SetFromAlpha, an, 0); pcall(an.SetToAlpha, an, 1); pcall(an.SetDuration, an, 0.15)
        if an.SetSmoothing then pcall(an.SetSmoothing, an, "OUT") end
        if ag.SetToFinalAlpha then pcall(ag.SetToFinalAlpha, ag, true) end
        h.anim = ag
      end
    end
  end
  h:Hide()
  return h
end
local function alEntrar(f)
  if rawget(f, "_luzActiva") ~= true or not habilitado(f) then return end
  local pb = pielDe(f)
  if pb and pb.tipo == "terciario" then return end
  local h = rawget(f, "_luz")
  if type(h) ~= "table" then
    local ok, nuevo = pcall(crearResplandor, f, rawget(f, "_radioLuz") or 6)
    if not ok or not nuevo then f._luzActiva = false; return end
    f._luz, h = nuevo, nuevo
  end
  -- El color sigue a la faccion (se lee al entrar: al cargar el personaje aun puede no saberse)
  local tema = E.tema()
  if h.halo then h.halo:SetColorTexture(rgba(tema.resplandor, 0.6)) end
  if h.velo then h.velo:SetColorTexture(rgba(tema.resplandor, 0.06)) end
  h:Show()
  local ag = rawget(h, "anim")
  if type(ag) == "table" and ag.Play then
    if ag.Stop then pcall(ag.Stop, ag) end
    if not pcall(ag.Play, ag) then pcall(h.SetAlpha, h, 1) end
  elseif h.SetAlpha then pcall(h.SetAlpha, h, 1) end
end
local function alSalir(f)
  local h = rawget(f, "_luz")
  if type(h) ~= "table" then return end
  local ag = rawget(h, "anim")
  if type(ag) == "table" and ag.Stop then pcall(ag.Stop, ag) end
  h:Hide()
end
local function engancharLuz(f)
  if rawget(f, "_luzEnganchada") == true or not f.HookScript then return end
  f._luzEnganchada = true
  pcall(f.HookScript, f, "OnEnter", alEntrar)
  pcall(f.HookScript, f, "OnLeave", alSalir)
  pcall(f.HookScript, f, "OnHide", alSalir)
  -- Un SetScript("OnEnter"/"OnLeave") posterior borra los ganchos: se vuelven a poner
  if hooksecurefunc then
    pcall(hooksecurefunc, f, "SetScript", function(s, evento)
      if evento == "OnEnter" then pcall(s.HookScript, s, "OnEnter", alEntrar)
      elseif evento == "OnLeave" then pcall(s.HookScript, s, "OnLeave", alSalir) end
    end)
  end
end
-- Resplandor en un boton o marco clicable (r = radio de sus esquinas)
function E.resplandor(f, r)
  if not f or type(f) ~= "table" then return end
  f._radioLuz = r or 6
  f._luzActiva = true
  engancharLuz(f)
end
-- Solo si el marco es clicable: ya tiene OnClick/OnMouseUp/OnMouseDown, o lo recibira despues (SetScript)
function E.resplandorSiClic(f, r)
  if not f or type(f) ~= "table" then return end
  local function clicable(s)
    for _, ev in ipairs({ "OnClick", "OnMouseUp", "OnMouseDown" }) do
      if s.GetScript then
        local ok, fn = pcall(s.GetScript, s, ev)
        if ok and type(fn) == "function" then return true end
      end
    end
    return false
  end
  if clicable(f) then E.resplandor(f, r); return end
  if rawget(f, "_luzEspera") == true or not hooksecurefunc then return end
  f._luzEspera = true
  pcall(hooksecurefunc, f, "SetScript", function(s, evento, fn)
    if rawget(s, "_luzActiva") ~= true and type(fn) == "function" and (evento == "OnClick" or evento == "OnMouseUp" or evento == "OnMouseDown") then
      E.resplandor(s, r)
    end
  end)
end

local function repintar(b)
  local pb = pielDe(b)
  if not pb then return end
  local tipo = pb.tipo
  if tipo == "toggle" then pintarBoton(b, pb.activo and "toggleOn" or "toggle"); return end
  if tipo == "terciario" then
    local fs = b.GetFontString and b:GetFontString()
    local col = (not habilitado(b)) and C.apagado or (pb.encima and C.orocl or C.oro)
    if type(fs) == "table" and fs.SetTextColor then fs:SetTextColor(rgba(col, 1)) end
    if pb.subrayado and pb.subrayado.SetColorTexture then pb.subrayado:SetColorTexture(rgba(pb.encima and C.oro or C.oro2, 1)) end
    return
  end
  if not CON_ESTADOS[tipo] then pintarBoton(b, tipo); return end
  local estado = (not habilitado(b)) and "Apagado" or (pb.pulsado and "Pulsado" or (pb.encima and "Hover" or ""))
  pintarBoton(b, tipo .. estado)
  if pb.luz then if estado == "Apagado" or estado == "Pulsado" then pb.luz:Hide() else pb.luz:Show() end end
  if pb.sombra then if estado == "Apagado" then pb.sombra:Hide() else pb.sombra:Show() end end
  if pb.sombraFuera then if estado == "Apagado" then pb.sombraFuera:Hide() else pb.sombraFuera:Show() end end
  -- Apagado mientras el raton esta encima: fuera el resplandor
  if estado == "Apagado" then alSalir(b) end
end
E.repintarBoton = repintar
local function engancharEstados(b)
  local pb = pielDe(b)
  if not pb or pb.enganchado or not b.HookScript then return end
  pb.enganchado = true
  pcall(b.HookScript, b, "OnEnter", function(s) local q = pielDe(s); if q then q.encima = true; repintar(s) end end)
  pcall(b.HookScript, b, "OnLeave", function(s) local q = pielDe(s); if q then q.encima = false; q.pulsado = false; repintar(s) end end)
  pcall(b.HookScript, b, "OnMouseDown", function(s) local q = pielDe(s); if q and habilitado(s) then q.pulsado = true; repintar(s) end end)
  pcall(b.HookScript, b, "OnMouseUp", function(s) local q = pielDe(s); if q then q.pulsado = false; repintar(s) end end)
  pcall(b.HookScript, b, "OnShow", function(s) repintar(s) end)
  if hooksecurefunc then
    pcall(hooksecurefunc, b, "Enable", function(s) repintar(s) end)
    pcall(hooksecurefunc, b, "Disable", function(s) repintar(s) end)
  end
  if b.SetPushedTextOffset then pcall(b.SetPushedTextOffset, b, 0, -1) end
end
-- Habilitar o apagar un boton y repintarlo (estado "apagado" de la maqueta)
function E.botonActivo(b, si)
  if not b then return end
  if si then if b.Enable then pcall(b.Enable, b) end elseif b.Disable then pcall(b.Disable, b) end
  repintar(b)
end
-- Conmutador ("seg" de la maqueta): activo = cera con letra oro claro; inactivo = casi negro con letra tenue
function E.toggle(b, activo)
  local pb = pielDe(b)
  if not pb then return end
  pb.activo = activo and true or false
  repintar(b)
end
-- Piel redonda de un boton (11-oct): relleno de radio 5 y aro de 1 px encima con un filo de luz arriba.
-- Devuelve nil si las texturas no cargan (entonces se usa la piel cuadrada de antes).
local function pielBotonRedonda(b)
  local okf, fondo = pcall(capa, { padre = b, nivel = "BACKGROUND", sub = -7, tipo = "relleno", archivo = ruta("relleno"), tam = 5 })
  local oka, aro = pcall(capa, { padre = b, nivel = "BACKGROUND", sub = -5, tipo = "aro", archivo = ruta("aro5"), tam = 5 })
  if okf and oka and fondo and aro and not fondo.respaldo and not aro.respaldo then
    aro.filo, aro.mezcla = { 1, 0.96, 0.85 }, 0.4
    return { borde = aro, fondo = fondo, redondo = true }
  end
  if okf and fondo then fondo:Hide() end
  if oka and aro then aro:Hide() end
  return nil
end
local function pielBotonCuadrada(b)
  local borde = b:CreateTexture(nil, "BACKGROUND", nil, -7)
  borde:SetAllPoints()
  local fondo = b:CreateTexture(nil, "BACKGROUND", nil, -6)
  fondo:SetPoint("TOPLEFT", 1, -1)
  fondo:SetPoint("BOTTOMRIGHT", -1, 1)
  return { borde = borde, fondo = fondo }
end
-- Tipos nuevos (11-oct). Alto 34 (28 si chico o toggle); terciario sin fondo, con subrayado de 1 px.
function E.botonNuevo(b, tipo, tam, chico)
  if not b or not b.CreateTexture then return end
  if not pielDe(b) then
    quitarPlantilla(b)
    b._pielBoton = pielBotonRedonda(b) or pielBotonCuadrada(b)
    local luz = b.GetHighlightTexture and b:GetHighlightTexture()
    if type(luz) == "table" and luz.SetAlpha then luz:SetAlpha(0) end
    E.resplandor(b, 5)
  end
  local pb = pielDe(b)
  pb.tipo = tipo
  local fs = b.GetFontString and b:GetFontString()
  if pb.borde.SetAlpha then pb.borde:SetAlpha(tipo == "terciario" and 0 or 1) end
  if pb.fondo.SetAlpha then pb.fondo:SetAlpha(tipo == "terciario" and 0 or 1) end
  if tipo == "estandarte" then
    if not pb.luz then
      -- Con esquinas redondas la luz y la sombra interior se meten dentro de la curva
      local m = pb.redondo and 4 or 1
      pb.luz = textura(b, "BORDER", 1, C.orocl, 0.22); pb.luz:SetPoint("TOPLEFT", m, -1); pb.luz:SetPoint("TOPRIGHT", -m, -1); pb.luz:SetHeight(1)
      pb.sombra = textura(b, "BORDER", 1, { 0, 0, 0 }, 0.35); pb.sombra:SetPoint("BOTTOMLEFT", m, 1); pb.sombra:SetPoint("BOTTOMRIGHT", -m, 1); pb.sombra:SetHeight(2)
      -- Sombra suave por fuera (solo el principal: lo levanta del fondo)
      if pb.redondo then
        local ok, s = pcall(capa, { padre = b, nivel = "BACKGROUND", sub = -8, tipo = "suave", archivo = ruta("sombra5"), tam = 10, fuera = 5 })
        if ok and s and not s.apagada then s:SetColorTexture(0, 0, 0, 0.45); pb.sombraFuera = s end
      end
    end
    if type(fs) == "table" then E.letra(fs, "marca", tam or (chico and 12 or 13), nil, true) end
  elseif tipo == "terciario" then
    if type(fs) == "table" then
      E.letra(fs, "cuerpoNegrita", tam or 13, nil, true)
      if not pb.subrayado then
        pb.subrayado = textura(b, "ARTWORK", 1, C.oro2, 1)
        pb.subrayado:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -1)
        pb.subrayado:SetPoint("TOPRIGHT", fs, "BOTTOMRIGHT", 0, -1)
        pb.subrayado:SetHeight(1)
      end
    end
  elseif type(fs) == "table" then
    E.letra(fs, "cuerpoNegrita", tam or ((tipo == "toggle" or chico) and 13 or 14), nil, true)
  end
  if b.SetHeight then pcall(b.SetHeight, b, tipo == "terciario" and 18 or ((tipo == "toggle" or chico) and 28 or 34)) end
  engancharEstados(b)
  repintar(b)
  return b
end
-- Ancho justo para el texto (padding 18 a cada lado, 12 si chico o toggle; terciario sin padding)
function E.botonAncho(b, chico, minimo)
  local fs = b and b.GetFontString and b:GetFontString()
  local w = type(fs) == "table" and fs.GetStringWidth and tonumber(fs:GetStringWidth()) or 0
  if type(w) ~= "number" or w <= 0 then w = 80 end
  local pb = pielDe(b)
  local pad = (pb and pb.tipo == "terciario") and 0 or ((chico or (pb and pb.tipo == "toggle")) and 24 or 36)
  local ancho = math.max(minimo or 0, math.floor(w + pad + 0.5))
  if b and b.SetWidth then pcall(b.SetWidth, b, ancho) end
  return ancho
end
function E.boton(b, tipo, tam, chico)
  if not b or not b.CreateTexture then return end
  tipo = tipo or "cuero"
  if tipo == "estandarte" or tipo == "secundario" or tipo == "terciario" or tipo == "toggle" then return E.botonNuevo(b, tipo, tam, chico) end
  if not pielDe(b) then
    quitarPlantilla(b)
    b._pielBoton = pielBotonRedonda(b) or pielBotonCuadrada(b)
    local luz = b.GetHighlightTexture and b:GetHighlightTexture()
    if type(luz) == "table" and luz.SetColorTexture then
      -- Con esquinas redondas el realce cuadrado se apaga: lo sustituye el resplandor redondo
      luz:SetColorTexture(1, 1, 1, pielDe(b).redondo and 0 or 0.12)
      luz:ClearAllPoints(); luz:SetPoint("TOPLEFT", 1, -1); luz:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    E.resplandor(b, 5)
  end
  pielDe(b).tipo = tipo
  local fs = b.GetFontString and b:GetFontString()
  if type(fs) == "table" then E.letra(fs, "boton", tam or 12, nil, true) end -- 12-oct: minimo 12 (antes 11 en cuero)
  -- Las fuentes de estado del boton tambien, para que no vuelva a la letra del juego al pasar el raton
  pintarBoton(b, tipo)
  return b
end
function E.cinta(b, abierta)
  if not b or not pielDe(b) then return end
  pintarBoton(b, abierta and "cintaOn" or "cinta")
end

-- Estandarte de faccion con el escudo de la clase y el sello de cera con el nivel (para el Libro).
-- Devuelve el marco; E.estandarteActualizar(e) pone nombre, raza, clase, faccion y nivel.
local ICONO_CLASE = {
  WARRIOR = "Interface\\Icons\\ClassIcon_Warrior", PALADIN = "Interface\\Icons\\ClassIcon_Paladin", HUNTER = "Interface\\Icons\\ClassIcon_Hunter",
  ROGUE = "Interface\\Icons\\ClassIcon_Rogue", PRIEST = "Interface\\Icons\\ClassIcon_Priest", SHAMAN = "Interface\\Icons\\ClassIcon_Shaman",
  MAGE = "Interface\\Icons\\ClassIcon_Mage", WARLOCK = "Interface\\Icons\\ClassIcon_Warlock", DRUID = "Interface\\Icons\\ClassIcon_Druid",
}
E.iconoClase = ICONO_CLASE
function E.estandarte(padre, ancho, alto)
  local e = CreateFrame("Frame", nil, padre)
  e:SetSize(ancho, alto)
  local tela = e:CreateTexture(nil, "BACKGROUND", nil, 1)
  tela:SetTexture(E.texturas.estandarte)
  tela:SetAllPoints()
  e.tela = tela
  local escudo = e:CreateTexture(nil, "ARTWORK", nil, 1)
  escudo:SetTexture(E.texturas.escudo)
  escudo:SetSize(84, 84)
  escudo:SetPoint("TOP", 0, -22)
  local icono = e:CreateTexture(nil, "ARTWORK", nil, 3)
  icono:SetSize(40, 40)
  icono:SetPoint("CENTER", escudo, "CENTER", 0, 6)
  if icono.SetTexCoord then icono:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  e.icono = icono
  local nombre = e:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  nombre:SetPoint("TOP", escudo, "BOTTOM", 0, -8)
  nombre:SetWidth(ancho - 12)
  if nombre.SetWordWrap then nombre:SetWordWrap(false) end
  E.letra(nombre, "titulo", 17)
  nombre:SetTextColor(1, 0.96, 0.9)
  e.nombre = nombre
  local datos = e:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  datos:SetPoint("TOP", nombre, "BOTTOM", 0, -6)
  datos:SetWidth(ancho - 14)
  datos:SetSpacing(3)
  E.letra(datos, "cuerpoMedio", 12) -- 12-oct: antes GameFontHighlightSmall (10 px, sin el ajuste de letra)
  datos:SetTextColor(1, 0.85, 0.76)
  e.datos = datos
  local sello = e:CreateTexture(nil, "ARTWORK", nil, 2)
  sello:SetTexture(E.texturas.sello)
  sello:SetSize(74, 74)
  sello:SetPoint("BOTTOM", 0, 58)
  e.sello = sello
  local palabra = e:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  palabra:SetPoint("CENTER", sello, "CENTER", 0, 15)
  E.letra(palabra, "marca", 11)
  palabra:SetTextColor(rgba(C.oro, 1))
  e.palabra = palabra
  local num = e:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  num:SetPoint("CENTER", sello, "CENTER", 0, -5)
  E.letra(num, "marca", 26)
  num:SetTextColor(1, 0.93, 0.8)
  e.num = num
  return e
end
function E.estandarteActualizar(e, enIngles)
  if not e then return end
  local function L(es, en) return enIngles and en or es end
  local _, faccion = nil, nil
  if UnitFactionGroup then _, faccion = pcall(UnitFactionGroup, "player") end
  local color = faccion == "Alliance" and C.alianza or C.horda
  if e.tela.SetVertexColor then e.tela:SetVertexColor(rgba(color, 1)) end
  local clase, archivo = "", nil
  if UnitClass then local ok, a, b = pcall(UnitClass, "player"); if ok then clase, archivo = a or "", b end end
  e.icono:SetTexture(ICONO_CLASE[archivo or ""] or "Interface\\Icons\\INV_Misc_Book_09")
  local nombre = UnitName and UnitName("player") or ""
  e.nombre:SetText(type(nombre) == "string" and nombre or "")
  local raza = UnitRace and UnitRace("player") or ""
  local fac = faccion == "Alliance" and "Alliance" or (faccion == "Horde" and "Horde" or "")
  e.datos:SetText((type(raza) == "string" and raza or "") .. "\n" .. (type(clase) == "string" and clase or "") .. (fac ~= "" and ("\n" .. fac) or ""))
  e.palabra:SetText(L("NIVEL", "LEVEL"))
  e.num:SetText(tostring((UnitLevel and UnitLevel("player")) or 1))
end

-- Leyenda de colores comun (Libro y panel): que significa cada color del texto
function E.leyenda(enIngles)
  local function L(es, en) return enIngles and en or es end
  return {
    { "|cff33ff66", L("Verde: lo que toca ahora o ya tienes", "Green: what to do now or what you already have") },
    { "|cffffd100", L("Dorado: lo siguiente y los titulos", "Gold: what comes next and headings") },
    { "|cffff9933", L("Naranja: te falta algo o es provisional", "Orange: something is missing or provisional") },
    { "|cff66ccff", L("Celeste: datos de tu personaje", "Light blue: your character's info") },
    { "|cffcc66ff", L("Morado: misiones de mazmorra", "Purple: dungeon quests") },
    { "|cff999999", L("Gris: ya pasado o detalle", "Gray: already done or detail") },
  }
end

-- ===================== Piezas comunes de la maqueta "hibrido" (11-oct, rediseno de TODAS las ventanas) =====================
-- Tarjeta: losa de piedra oscura con borde fino (opts.acento = raya brasa de 2 px arriba, como "TU MISION AHORA").
-- Devuelve un Frame; el contenido se ancla dentro con un margen de 12-16 px.
E.alfaTarjeta = 0.6 -- 12-oct (Andy): mas translucidas (antes 0.8)
function E.tarjeta(padre, opts)
  opts = opts or {}
  local t = CreateFrame("Frame", nil, padre, BackdropTemplateMixin and "BackdropTemplate" or nil)
  -- 11-oct: esquinas de 6 px, sombra suave, brillo arriba y filo de luz; la hundida va sin sombra ni brillo
  local hundida = opts.variante == "hundida"
  local fondo = hundida and C.hundida or (opts.fondo or C.piedra2)
  -- 11-oct (Andy): algo transparentes para que se vea el arte de fondo de cada pestana
  local alfaT = opts.alfa or (hundida and 0.42) or E.alfaTarjeta or 0.6
  local ok = pcall(forma, t, { radio = 6, fondo = fondo, alfa = alfaT, borde = C.borde, filo = E.tema().filo,
    mezcla = hundida and 0.15 or 0.4, sombra = not hundida, sombraAlfa = 0.5, brillo = (not hundida) and 0.05 or nil })
  if not ok then backdropViejo(t, fondo, alfaT, C.borde) end
  -- Acento: barra con luz metida dentro de las esquinas (si falla, la raya recta de antes)
  local function acento(color, alto, margen, y)
    local okb, a = pcall(barraLuz, t, "BORDER", 3, color, alto, margen, y)
    if okb and a then return a end
    a = textura(t, "BORDER", 3, color, 1)
    a:SetPoint("TOPLEFT", 1, y); a:SetPoint("TOPRIGHT", -1, y); a:SetHeight(alto)
    return a
  end
  if opts.variante == "principal" or opts.variante == "recomendada" then
    t.acento = acento(opts.variante == "recomendada" and C.oro or E.tema().linea, 3, 8, 0)
  elseif opts.acento then
    t.acento = acento(opts.acento == true and C.brasa or opts.acento, 2, 7, -1)
  end
  E.resplandorSiClic(t, 6)
  return t
end
-- Cambiar la variante de una tarjeta ya hecha ("principal" | "recomendada" | nil = sin linea)
function E.tarjetaVariante(t, variante)
  if not t then return end
  local a = rawget(t, "acento")
  if type(a) ~= "table" then
    local ok, b = pcall(barraLuz, t, "BORDER", 3, C.brasa, 3, 8, 0)
    if ok and b then a = b
    else
      a = textura(t, "BORDER", 3, C.brasa, 1)
      a:SetPoint("TOPLEFT", 0, 0); a:SetPoint("TOPRIGHT", 0, 0); a:SetHeight(3)
    end
    t.acento = a
  end
  if variante == "principal" or variante == "recomendada" then
    if a.SetColorTexture then a:SetColorTexture(rgba(variante == "recomendada" and C.oro or E.tema().linea, 1)) end
    a:Show()
  else a:Hide() end
end

-- ===================== Rediseno por tarjetas (11-oct): textos, chips, barra, icono, retrato, cifras =====================
local PESOS = { regular = "cuerpo", medio = "cuerpoMedio", negrita = "cuerpoNegrita" }
-- Texto de cuerpo en Alegreya Sans (14 por defecto, minimo 12)
function E.texto(padre, fs, tam, color, peso)
  fs = fs or padre:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  E.letra(fs, PESOS[peso or "medio"] or "cuerpoMedio", math.max(12, tam or 14))
  fs:SetTextColor(rgba(color or C.texto, 1))
  if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
  return fs
end
-- Titulos Cinzel: h2 (22) y h3 (16) en blanco hueso
function E.h2(padre, fs, tam)
  fs = fs or padre:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  E.letra(fs, "marca", tam or 22)
  fs:SetTextColor(rgba(C.texto, 1))
  if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
  return fs
end
function E.h3(padre, fs, tam) return E.h2(padre, fs, tam or 16) end
-- Texto de rotulo: MAYUSCULAS con tildes. WoW no tiene letter-spacing; el aire lo da la letra negrita de 12.
function E.espaciar(s) return E.mayus(s) end
-- Rotulo (".eti"): 11 px negrita, MAYUSCULAS, brasa por defecto (color = E.color.oro / tenue / verde)
function E.rotulo(padre, fs, color, tam)
  fs = fs or padre:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  E.letra(fs, "cuerpoNegrita", tam or 12)
  fs:SetTextColor(rgba(color or C.brasa, 1))
  if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  return fs
end
function E.ponerRotulo(fs, texto) if fs and fs.SetText then fs:SetText(E.espaciar(texto or "")) end end

-- Chip de estado: verde = ya puedes, oro = recomendado, brasa = ahora, gris = despues. c:poner(texto, color)
local CHIP = {
  verde = { letra = C.verde, borde = C.verdeBorde, fondo = C.verdef },
  oro = { letra = C.oro, borde = C.oro2, fondo = C.oroFondo },
  brasa = { letra = { 1, 0.86, 0.6 }, borde = { 0.847, 0.706, 0.408 }, fondo = { 0.561, 0.114, 0.102 } },
  gris = { letra = C.apagado, borde = C.borde, fondo = C.negro },
}
function E.chip(padre, texto, color)
  local c = CreateFrame("Frame", nil, padre)
  c:SetSize(60, 20)
  -- 11-oct: chip redondo (radio 4): relleno debajo y aro de 1 px encima con un toque de luz arriba; si no carga, cuadrado
  local okf, fondo = pcall(capa, { padre = c, nivel = "BACKGROUND", sub = 1, tipo = "relleno", archivo = ruta("relleno"), tam = 4 })
  local oka, aro = pcall(capa, { padre = c, nivel = "BACKGROUND", sub = 2, tipo = "aro", archivo = ruta("aro4"), tam = 4 })
  if okf and oka and fondo and aro and not fondo.respaldo and not aro.respaldo then
    aro.filo, aro.mezcla = { 1, 1, 1 }, 0.3
    c.fondo, c.borde = fondo, aro
  else
    if okf and fondo then fondo:Hide() end
    if oka and aro then aro:Hide() end
    c.borde = textura(c, "BACKGROUND", 1, C.borde, 1); c.borde:SetAllPoints()
    c.fondo = textura(c, "BACKGROUND", 2, C.negro, 1); c.fondo:SetPoint("TOPLEFT", 1, -1); c.fondo:SetPoint("BOTTOMRIGHT", -1, 1)
  end
  c.texto = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  E.letra(c.texto, "cuerpoNegrita", 12)
  c.texto:SetPoint("CENTER", 0, 0)
  if c.texto.SetWordWrap then c.texto:SetWordWrap(false) end
  function c:poner(t, col)
    local k = CHIP[col or "gris"] or CHIP.gris
    if col == "brasa" or col == "ahora" then -- 11-oct: el chip AHORA sigue el tema de tu faccion
      local tm = E.tema()
      k = { letra = tm.ahoraLetra, borde = tm.ahoraBorde or tm.ahora, fondo = tm.ahora }
    end
    if self.borde.SetColorTexture then self.borde:SetColorTexture(rgba(k.borde, 1)) end
    if self.fondo.SetColorTexture then self.fondo:SetColorTexture(rgba(k.fondo, 1)) end
    self.texto:SetTextColor(rgba(k.letra, 1))
    self.texto:SetText(E.mayus(t or ""))
    local w = tonumber(self.texto.GetStringWidth and self.texto:GetStringWidth()) or 0
    if type(w) ~= "number" or w <= 0 then w = 8 * #(tostring(t or "")) end
    self:SetWidth(math.floor(w + 16 + 0.5))
    self:SetHeight(math.max(20, E.tamFinal(12) + 7)) -- 12-oct: el alto sigue al tamano de letra elegido
  end
  c:poner(texto, color)
  return c
end

-- Barra de rango (profesiones): alto 8, fondo #141210, borde #3a352f, relleno brasa (o verde). b:poner(valor, max)
function E.barra(padre, ancho, color)
  local b = CreateFrame("Frame", nil, padre)
  b:SetSize(ancho or 200, 8)
  b.borde = textura(b, "BACKGROUND", 1, { 0.227, 0.208, 0.184 }, 1); b.borde:SetAllPoints()
  b.fondo = textura(b, "BACKGROUND", 2, { 0.078, 0.071, 0.063 }, 1); b.fondo:SetPoint("TOPLEFT", 1, -1); b.fondo:SetPoint("BOTTOMRIGHT", -1, 1)
  b.relleno = textura(b, "ARTWORK", 1, color == "verde" and C.verde or C.brasa, 1)
  b.relleno:SetPoint("TOPLEFT", 1, -1); b.relleno:SetHeight(6)
  function b:poner(valor, max, col)
    valor, max = tonumber(valor) or 0, tonumber(max) or 0
    local w = self.GetWidth and tonumber(self:GetWidth()) or 0
    if type(w) ~= "number" or w <= 2 then w = ancho or 200 end
    local f = (max > 0) and math.max(0, math.min(1, valor / max)) or 0
    if col and self.relleno.SetColorTexture then self.relleno:SetColorTexture(rgba(col == "verde" and C.verde or C.brasa, 1)) end
    if f <= 0 then self.relleno:Hide() else self.relleno:SetWidth(math.max(1, (w - 2) * f)); self.relleno:Show() end
  end
  return b
end

-- Icono cuadrado con borde de 1 px (#6b5a3a; "verde" | "oro" | "gris"). i:poner(textura, color, gris)
local BORDE_ICONO = { verde = C.verde, oro = C.oro, gris = C.borde }
function E.icono(padre, tam, color)
  tam = tam or 36
  local i = CreateFrame("Frame", nil, padre)
  i:SetSize(tam, tam)
  i.borde = textura(i, "BACKGROUND", 1, BORDE_ICONO[color or ""] or C.bordeIcono, 1); i.borde:SetAllPoints()
  i.negro = textura(i, "BACKGROUND", 2, { 0, 0, 0 }, 1); i.negro:SetPoint("TOPLEFT", 1, -1); i.negro:SetPoint("BOTTOMRIGHT", -1, 1)
  i.tex = i:CreateTexture(nil, "ARTWORK", nil, 1)
  i.tex:SetPoint("TOPLEFT", 2, -2); i.tex:SetPoint("BOTTOMRIGHT", -2, 2)
  if i.tex.SetTexCoord then i.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
  function i:poner(tx, col, gris)
    self.tex:SetTexture(tx or "Interface\\Icons\\INV_Misc_QuestionMark")
    if self.borde.SetColorTexture then self.borde:SetColorTexture(rgba(BORDE_ICONO[col or ""] or C.bordeIcono, 1)) end
    if self.tex.SetDesaturated then pcall(self.tex.SetDesaturated, self.tex, gris and true or false) end
    if self.tex.SetVertexColor then if gris then self.tex:SetVertexColor(0.6, 0.6, 0.6) else self.tex:SetVertexColor(1, 1, 1) end end
  end
  return i
end

-- Retrato redondo (NPC que da la mision): borde de 2 px oro2; sin SetMask en el cliente, cuadrado con el mismo borde.
function E.retrato(padre, tam)
  tam = tam or 40
  local r = CreateFrame("Frame", nil, padre)
  r:SetSize(tam, tam)
  local MASCARA = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
  r.aro = r:CreateTexture(nil, "BACKGROUND", nil, 1)
  r.aro:SetAllPoints()
  r.tex = r:CreateTexture(nil, "ARTWORK", nil, 1)
  r.tex:SetPoint("TOPLEFT", 2, -2); r.tex:SetPoint("BOTTOMRIGHT", -2, 2)
  local redondo = false
  if r.aro.SetMask and r.tex.SetMask then
    local ok1 = pcall(r.aro.SetColorTexture, r.aro, rgba(C.oro2, 1))
    local ok2 = pcall(r.aro.SetMask, r.aro, MASCARA)
    local ok3 = pcall(r.tex.SetMask, r.tex, MASCARA)
    redondo = ok1 and ok2 and ok3
  end
  if not redondo and r.aro.SetColorTexture then r.aro:SetColorTexture(rgba(C.oro2, 1)) end
  r.redondo = redondo
  function r:poner(tx)
    local t = self.tex
    if type(tx) == "function" then pcall(tx, t) elseif tx then t:SetTexture(tx) else t:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
    if not rawget(self, "redondo") and t.SetTexCoord then pcall(t.SetTexCoord, t, 0.1, 0.9, 0.1, 0.9) end
  end
  return r
end

-- ===== Retrato del jugador (11-oct, Andy: "la cara del personaje") =====
-- E.retratoJugador(padre, tam) -> E.retrato redondo con la CARA del personaje (SetPortraitTexture(tex, "player") con pcall).
-- r.respaldo = textura del icono de rama/clase (se usa si el cliente no da la cara). r:actualizar() la vuelve a pedir;
-- se refresca sola con UNIT_PORTRAIT_UPDATE (player) y PLAYER_ENTERING_WORLD.
local retratosJugador = setmetatable({}, { __mode = "k" })
local eventosRetrato
local function caraDelJugador(r)
  local t = r.tex
  local ok = false
  if SetPortraitTexture and t then
    ok = pcall(SetPortraitTexture, t, "player")
  end
  if ok and t.GetTexture then
    local ok2, tx = pcall(t.GetTexture, t)
    if ok2 and (tx == nil or tx == "" or tx == 0) then ok = false end
  end
  if ok then
    -- 11-oct: con mascara el cliente NO deja cambiar las coordenadas ("Cannot set tex coords when texture has mask")
    if not rawget(r, "redondo") and t.SetTexCoord then pcall(t.SetTexCoord, t, 0, 1, 0, 1) end
    r.esCara = true
  else
    r.esCara = false
    r:poner(rawget(r, "respaldo") or "Interface\\Icons\\INV_Misc_QuestionMark")
  end
  return ok
end
function E.retratoJugador(padre, tam)
  local r = E.retrato(padre, tam or 48)
  r.actualizar = caraDelJugador
  function r:ponerRespaldo(tx) self.respaldo = tx; if rawget(self, "esCara") ~= true then pcall(caraDelJugador, self) end end
  retratosJugador[r] = true
  if not eventosRetrato and CreateFrame then
    eventosRetrato = CreateFrame("Frame")
    pcall(eventosRetrato.RegisterEvent, eventosRetrato, "UNIT_PORTRAIT_UPDATE")
    pcall(eventosRetrato.RegisterEvent, eventosRetrato, "PLAYER_ENTERING_WORLD")
    eventosRetrato:SetScript("OnEvent", function(_, ev, unidad)
      if ev == "UNIT_PORTRAIT_UPDATE" and unidad ~= "player" then return end
      for x in pairs(retratosJugador) do pcall(caraDelJugador, x) end
    end)
  end
  pcall(caraDelJugador, r)
  return r
end

-- Emblema de tu faccion (textura del cliente, con pcall; nil si no carga). e:actualizar() lo repone segun E.tema()
function E.emblemaFaccion(padre, tam)
  local e = padre:CreateTexture(nil, "ARTWORK", nil, 2)
  e:SetSize(tam or 22, tam or 22)
  function e:actualizar()
    local ok = pcall(self.SetTexture, self, E.tema().emblema)
    if ok then self:Show() else self:Hide() end
  end
  e:actualizar()
  return e
end

-- ===== Fondo de ambiente (11-oct, Andy: "como GearQuest") =====
-- E.ambiente(padre) -> Frame detras de la hoja con: imagen del cliente (alfa 0.30, sin color), velo #141210 y vineta en los bordes
-- (no hay blur en WoW: el difuminado se imita con alfa baja + velo + degradados). a:poner(textura|fileDataID, coords) / a:quitar().
-- Si la textura no carga (pcall), queda el fondo plano de siempre.
local function degradado(t, orient, c1, a1, c2, a2)
  if t.SetColorTexture then t:SetColorTexture(1, 1, 1, 1) end
  local ok = false
  if t.SetGradient and CreateColor then
    ok = pcall(t.SetGradient, t, orient, CreateColor(c1[1], c1[2], c1[3], a1), CreateColor(c2[1], c2[2], c2[3], a2))
  end
  if not ok and t.SetGradientAlpha then
    ok = pcall(t.SetGradientAlpha, t, orient, c1[1], c1[2], c1[3], a1, c2[1], c2[2], c2[3], a2)
  end
  if not ok then t:Hide() end
  return ok
end
function E.ambiente(padre)
  local a = CreateFrame("Frame", nil, padre)
  a:SetAllPoints(padre)
  a.img = a:CreateTexture(nil, "BACKGROUND", nil, 2)
  a.img:SetAllPoints()
  a.velo = textura(a, "BACKGROUND", 3, { 0.078, 0.071, 0.063 }, 0.22) -- 12-oct: velo mas fino (antes 0.4)
  a.velo:SetAllPoints()
  local negro = { 0.078, 0.071, 0.063 }
  local G = 90
  a.arriba = a:CreateTexture(nil, "BACKGROUND", nil, 4); a.arriba:SetPoint("TOPLEFT"); a.arriba:SetPoint("TOPRIGHT"); a.arriba:SetHeight(G)
  a.abajo = a:CreateTexture(nil, "BACKGROUND", nil, 4); a.abajo:SetPoint("BOTTOMLEFT"); a.abajo:SetPoint("BOTTOMRIGHT"); a.abajo:SetHeight(G)
  a.izq = a:CreateTexture(nil, "BACKGROUND", nil, 4); a.izq:SetPoint("TOPLEFT"); a.izq:SetPoint("BOTTOMLEFT"); a.izq:SetWidth(G)
  a.der = a:CreateTexture(nil, "BACKGROUND", nil, 4); a.der:SetPoint("TOPRIGHT"); a.der:SetPoint("BOTTOMRIGHT"); a.der:SetWidth(G)
  -- VERTICAL va de abajo (1.er color) a arriba (2.o); HORIZONTAL de izquierda a derecha
  degradado(a.arriba, "VERTICAL", negro, 0, negro, 0.8)
  degradado(a.abajo, "VERTICAL", negro, 0.8, negro, 0)
  degradado(a.izq, "HORIZONTAL", negro, 0.8, negro, 0)
  degradado(a.der, "HORIZONTAL", negro, 0, negro, 0.8)
  function a:poner(tx, coords, alfa)
    if not tx then return self:quitar() end
    if rawget(self, "actual") == tx then self:Show(); return true end
    local ok = pcall(self.img.SetTexture, self.img, tx)
    if ok and self.img.GetTexture then
      local ok2, puesta = pcall(self.img.GetTexture, self.img)
      if ok2 and (puesta == nil or puesta == "") then ok = false end
    end
    if not ok then return self:quitar() end
    self.actual = tx
    local c = coords or { 0, 1, 0, 1 }
    if self.img.SetTexCoord then self.img:SetTexCoord(c[1], c[2], c[3], c[4]) end
    if self.img.SetDesaturation then pcall(self.img.SetDesaturation, self.img, 0.4) end
    if self.img.SetVertexColor then self.img:SetVertexColor(0.85, 0.78, 0.68) end
    self.img:SetAlpha(alfa or 0.30)
    self.img:Show(); self:Show()
    return true
  end
  function a:quitar() self.actual = nil; self.img:Hide(); self:Hide(); return false end
  a:quitar()
  return a
end

-- Cifra grande con rotulo ("3 PIEZAS PARA TI"): 24 px negrita + 10 px tenue. c:poner(numero, rotulo)
function E.cifra(padre)
  local c = CreateFrame("Frame", nil, padre)
  c:SetSize(70, 40)
  c.num = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  E.letra(c.num, "cuerpoNegrita", 24)
  c.num:SetTextColor(rgba(C.texto, 1))
  c.num:SetPoint("TOPLEFT", 0, 0)
  c.rotulo = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  E.letra(c.rotulo, "cuerpoNegrita", 12)
  c.rotulo:SetTextColor(rgba(C.tenue, 1))
  c.rotulo:SetPoint("TOPLEFT", c.num, "BOTTOMLEFT", 0, -4)
  if c.rotulo.SetJustifyH then c.rotulo:SetJustifyH("LEFT") end
  function c:poner(n, rot, color)
    self.num:SetText(tostring(n or ""))
    self.num:SetTextColor(rgba(color or C.texto, 1))
    self.rotulo:SetText(E.mayus(rot or ""))
    local w = math.max(tonumber(self.num.GetStringWidth and self.num:GetStringWidth()) or 0, tonumber(self.rotulo.GetStringWidth and self.rotulo:GetStringWidth()) or 0)
    if type(w) ~= "number" or w <= 0 then w = 60 end
    self:SetWidth(w + 4)
    self:SetHeight(math.max(40, E.tamFinal(24) + E.tamFinal(12) + 6)) -- 12-oct: alto segun la letra
  end
  return c
end

-- Etiqueta de seccion: mayusculas pequenas en brasa ("MAZMORRA AL NIVEL 13", "COGELAS ANTES DE ENTRAR").
-- Con fs ya creado lo restila; si no, crea uno en padre. color = E.color.* (por defecto brasa).
function E.etiqueta(padre, fs, color, tam)
  fs = fs or padre:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  E.letra(fs, "boton", tam or 11) -- 12-oct: antes 9
  fs:SetTextColor(rgba(color or C.brasa, 1))
  if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
  return fs
end
-- Texto de etiqueta en mayusculas (string.upper no toca las tildes de UTF-8: se suben a mano las comunes)
local TILDES = { ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ" }
function E.mayus(s)
  if type(s) ~= "string" then return s end
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return (s:upper():gsub("[\195][\161\169\173\179\186\177]", function(c) return TILDES[c] or c end))
end

-- Titulo serif (Metamorphous) en blanco hueso: "Sigue subiendo en Mulgore", "Ragefire Chasm"
function E.titulo(padre, fs, tam)
  fs = fs or padre:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  E.letra(fs, "titulo", tam or 16)
  fs:SetTextColor(rgba(C.texto, 1))
  if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
  return fs
end
-- Texto normal (Signika) y subtitulo gris ("Orgrimmar · ideal al 15", "nivel 10 · totem de Fire")
function E.cuerpo(padre, fs, tam, color)
  fs = fs or padre:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  E.letra(fs, "boton", tam or 12) -- 12-oct: antes 11
  fs:SetTextColor(rgba(color or C.texto, 1))
  if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
  return fs
end
function E.sub(padre, fs, tam) return E.cuerpo(padre, fs, tam or 11, C.tenue) end -- 12-oct: antes 10

-- Fila con icono: icono cuadrado con borde, nombre en blanco y debajo el detalle en gris.
-- f:poner(icono, nombre, detalle); devuelve el Button (clic y tooltip los pone quien la usa). Alto = tam + 8.
function E.fila(padre, ancho, tam)
  tam = tam or 26
  local f = CreateFrame("Button", nil, padre)
  f:SetSize(ancho or 200, tam + 8)
  local marcoIc = textura(f, "ARTWORK", 1, C.borde, 1)
  marcoIc:SetSize(tam + 2, tam + 2)
  marcoIc:SetPoint("LEFT", 0, 0)
  local ic = f:CreateTexture(nil, "ARTWORK", nil, 2)
  ic:SetSize(tam, tam)
  ic:SetPoint("CENTER", marcoIc, "CENTER")
  if ic.SetTexCoord then ic:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  f.icono, f.marcoIcono = ic, marcoIc
  local n = E.cuerpo(f, nil, 12)
  n:SetPoint("TOPLEFT", marcoIc, "TOPRIGHT", 8, -1)
  n:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  if n.SetWordWrap then n:SetWordWrap(false) end
  f.nombre = n
  local d = E.sub(f, nil, 11)
  d:SetPoint("TOPLEFT", n, "BOTTOMLEFT", 0, -2)
  d:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  if d.SetWordWrap then d:SetWordWrap(false) end
  f.detalle = d
  local luz = textura(f, "HIGHLIGHT", 1, { 1, 1, 1 }, 0.05)
  luz:SetAllPoints()
  function f:poner(icono, nombre, detalle)
    if icono then self.icono:SetTexture(icono); self.icono:Show(); self.marcoIcono:Show() else self.icono:Hide(); self.marcoIcono:Hide() end
    self.nombre:ClearAllPoints()
    if icono then self.nombre:SetPoint("TOPLEFT", self.marcoIcono, "TOPRIGHT", 8, -1) else self.nombre:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -1) end
    self.nombre:SetPoint("RIGHT", self, "RIGHT", 0, 0)
    self.nombre:SetText(nombre or "")
    self.detalle:SetText(detalle or "")
  end
  return f
end

-- Dato grande con rotulo en mayusculas debajo ("3 PIEZAS", "6 MISIONES"). d:poner(numero, rotulo)
function E.dato(padre)
  local d = CreateFrame("Frame", nil, padre)
  d:SetSize(56, 30)
  local n = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  E.letra(n, "marca", 16)
  n:SetTextColor(rgba(C.texto, 1))
  n:SetPoint("TOPLEFT", 0, 0)
  local r = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  E.letra(r, "boton", 11)
  r:SetTextColor(rgba(C.tenue, 1))
  r:SetPoint("TOPLEFT", n, "BOTTOMLEFT", 0, -3)
  d.num, d.rotulo = n, r
  function d:poner(num, rotulo)
    self.num:SetText(tostring(num or ""))
    self.rotulo:SetText(E.mayus(rotulo or ""))
    local w = math.max(tonumber(self.num.GetStringWidth and self.num:GetStringWidth()) or 0, tonumber(self.rotulo.GetStringWidth and self.rotulo:GetStringWidth()) or 0)
    self:SetWidth(math.max(24, (w > 0 and w or 40) + 4))
  end
  return d
end

-- Cabecera de ventana pequena (ruta, linea, ficha, avisos): franja oscura con titulo en mayusculas (Cinzel, oro),
-- un texto a la derecha ("1/5") y la raya roja debajo. Devuelve { titulo, derecha, alto }.
function E.cabecera(f, alto)
  alto = alto or 24
  local fondo = textura(f, "BORDER", 1, { 0.09, 0.07, 0.06 }, 1)
  fondo:SetPoint("TOPLEFT", 4, -4); fondo:SetPoint("TOPRIGHT", -4, -4); fondo:SetHeight(alto)
  local raya = textura(f, "BORDER", 4, C.sangre, 1)
  raya:SetPoint("TOPLEFT", fondo, "BOTTOMLEFT"); raya:SetPoint("TOPRIGHT", fondo, "BOTTOMRIGHT"); raya:SetHeight(2)
  local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  E.letra(t, "marca", 11)
  t:SetTextColor(rgba(C.oro, 1))
  t:SetPoint("LEFT", fondo, "LEFT", 10, 0)
  t:SetJustifyH("LEFT")
  local d = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  E.letra(d, "marca", 11)
  d:SetTextColor(rgba(C.oro, 1))
  d:SetPoint("RIGHT", fondo, "RIGHT", -10, 0)
  t:SetPoint("RIGHT", d, "LEFT", -6, 0)
  if t.SetWordWrap then t:SetWordWrap(false) end
  return { titulo = t, derecha = d, fondo = fondo, raya = raya, alto = alto + 6 }
end

-- Barra de progreso por tramos (la de la ruta: PASO 2 DE 5). b:poner(hecho, total)
function E.tramos(padre, ancho)
  local b = CreateFrame("Frame", nil, padre)
  b:SetSize(ancho or 200, 3)
  b.partes = {}
  function b:poner(hecho, total)
    total = math.max(1, math.min(12, tonumber(total) or 1))
    hecho = tonumber(hecho) or 0
    local w = self:GetWidth()
    if type(w) ~= "number" or w <= 0 then w = ancho or 200 end
    local hueco = 6
    local cada = (w - hueco * (total - 1)) / total
    for i = 1, math.max(total, #self.partes) do
      local p = self.partes[i]
      if i <= total then
        if not p then p = textura(self, "ARTWORK", 1, C.borde, 1); self.partes[i] = p end
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", (i - 1) * (cada + hueco), 0)
        p:SetSize(cada, 3)
        if p.SetColorTexture then p:SetColorTexture(rgba(i <= hecho and C.brasa or C.borde, 1)) end
        p:Show()
      elseif p then p:Hide() end
    end
  end
  return b
end

-- Divisor fino entre filas (gris piedra)
function E.divisor(padre, ancla, y, izq, der)
  local r = textura(padre, "ARTWORK", 1, C.borde, 1)
  r:SetHeight(1)
  r:SetPoint("TOPLEFT", ancla or padre, ancla and "BOTTOMLEFT" or "TOPLEFT", izq or 0, y or -6)
  r:SetPoint("RIGHT", padre, "RIGHT", -(der or 0), 0)
  return r
end

-- Ventana al frente al hacer clic (las del addon ya no quedan tapadas por otra del addon)
function E.alFrente(f)
  if f and f.SetToplevel then pcall(f.SetToplevel, f, true) end
end

-- Guardar y recuperar la posicion de una ventana (clave en WowFExportarDB)
function E.guardarPos(f, clave)
  if not f or not f.GetPoint then return end
  local ok, punto, _, relativo, x, y = pcall(f.GetPoint, f)
  if not ok or type(punto) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return end
  WowFExportarDB = WowFExportarDB or {}
  WowFExportarDB[clave] = { punto, type(relativo) == "string" and relativo or punto, x, y }
end
function E.ponerPos(f, clave)
  local p = type(WowFExportarDB) == "table" and WowFExportarDB[clave]
  if type(p) ~= "table" or type(p[1]) ~= "string" or type(p[3]) ~= "number" or type(p[4]) ~= "number" then return false end
  f:ClearAllPoints()
  f:SetPoint(p[1], UIParent, p[2] or p[1], p[3], p[4])
  return true
end

-- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget, 3 jugadores con mando, fuera de combate): la interfaz de mando de
-- WoW Forever culpa al addon que dibuja o crea marcos en el mapa del mundo, lo abre o le cambia la zona, mueve ventanas del
-- juego (el probador) o mete ventanas en UISpecialFrames; despues el juego le niega SetPreferredGamepadInteractTarget toda
-- la sesion. Con mando conectado (como Nemesis 1.1.1: GamePadEnable=1 Y un mando presente, o la interfaz en modo mando)
-- el addon no toca ninguna ventana del juego. La flecha de destino, la ruta en el chat y los avisos siguen igual.
function WowF.interfazMando()
  local estilo = C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle
  local tipo = Enum and Enum.InputDeviceInterfaceType and Enum.InputDeviceInterfaceType.Gamepad
  if type(estilo) == "function" and tipo ~= nil then
    local ok, s = pcall(estilo)
    if ok and s == tipo then return true end
  end
  local ok, v = pcall(GetCVar, "GamePadEnable")
  if not (ok and (v == "1" or v == 1)) then return false end
  if not (C_GamePad and C_GamePad.GetAllDeviceIDs) then return true end
  local okD, ids = pcall(C_GamePad.GetAllDeviceIDs)
  if not okD or type(ids) ~= "table" then return true end
  return next(ids) ~= nil
end
-- Esc cierra la ventana (UISpecialFrames) solo sin mando; se decide al entrar al juego, cuando ya se ve el mando
do
  local pendientes, entrado = {}, false
  local function meter(nombre)
    if UISpecialFrames and not WowF.interfazMando() then table.insert(UISpecialFrames, nombre) end
  end
  function WowF.cerrarConEsc(nombre)
    if entrado then meter(nombre) else pendientes[#pendientes + 1] = nombre end
  end
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    entrado = true
    for _, n in ipairs(pendientes) do meter(n) end
    pendientes = {}
  end)
end
