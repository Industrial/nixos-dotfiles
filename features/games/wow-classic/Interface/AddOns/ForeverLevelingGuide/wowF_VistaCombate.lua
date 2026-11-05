-- Forever Leveling Guide: pestana Combate por tarjetas (11-oct, maqueta combate.html aprobada por Andy).
-- WowF.vistaRotacion / WowF.vistaMacros (contrato en CONTRATO.md): datos de WowF.datosVistaCombate (wowF_Rotacion.lua).
-- Tambien deja WowF.vistaKit: piezas reutilizables (tarjetas, textos, iconos, chips, botones) con posicion absoluta
-- dentro del marco de la vista; lo usa wowF_VistaProfesiones.lua.
-- Colores de acento (boton principal, conmutador activo, linea de la tarjeta principal, chip AHORA) salen de E.tema():
-- Horde = rojo/brasa aprobado, Alliance = azul real. Aqui no hay colores de acento fijos.

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local unpack = unpack or table.unpack

-- ===================== Kit comun de las vistas =====================
local K = {}
WowF.vistaKit = K

local function E() return WowF.estilo end
local function C() return (WowF.estilo and WowF.estilo.color) or {} end
local function col(c, a) c = c or { 1, 1, 1 }; return c[1], c[2], c[3], a or 1 end
-- Color de acento para TEXTO (rotulos brasa, numeros): Horde = brasa; Alliance = azul claro legible sobre la piedra
function K.acentoTexto()
  local es = E()
  local t = es and es.tema and es.tema()
  if type(t) ~= "table" then return C().brasa or { 1, 0.541, 0.165 } end
  if t.faccion == "Alliance" then return t.ahoraBorde or t.linea end
  return t.linea or C().brasa
end
function K.acentoCod()
  local es = E()
  local t = es and es.tema and es.tema()
  if type(t) == "table" and t.faccion == "Alliance" then return "|cff85a8e6" end
  return (type(t) == "table" and t.cod) or "|cffff8a2a"
end
-- Colores de la maqueta que no estan en E.color
K.CASILLA = { 0.129, 0.122, 0.11 }      -- #211f1c
K.CASILLA_BORDE = { 0.231, 0.212, 0.192 } -- #3b3631
K.AHORA_FONDO = { 0.184, 0.141, 0.106 }  -- #2f241b
K.PRE_FONDO = { 0.078, 0.071, 0.063 }    -- #141210
K.PRE_BORDE = { 0.227, 0.208, 0.184 }    -- #3a352f
K.PRE_LETRA = { 0.812, 0.776, 0.714 }    -- #cfc6b6
K.CLARO = { 0.851, 0.816, 0.761 }        -- #d9d0c2
K.LUEGO = { 0.741, 0.702, 0.643 }        -- #bdb3a4
K.NEUTRO_FONDO = { 0.114, 0.106, 0.098 } -- #1d1b19

-- Medir sin romperse con los marcos falsos del simulador
local function medir(o, metodo)
  if type(o) ~= "table" then return nil end
  local ok, v = pcall(function() return o[metodo](o) end)
  if not ok then return nil end
  v = tonumber(v)
  if v and v > 0 then return v end
  return nil
end
K.medir = medir
-- 12-oct: tamano que de verdad se pone (minimo 11 y ajuste "Tamano de letra"); sin Estilo, el minimo
local function tf(tam, boton)
  local e = WowF.estilo
  if e and e.tamFinal then return e.tamFinal(tam, nil, nil, boton) end
  return math.max(11, tonumber(tam) or 12)
end
K.tamFinal = tf
local function aproxAlto(txt, ancho, tam)
  tam = tf(tam or 13)
  local n = #(tostring(txt or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
  local porLinea = math.max(1, math.floor((ancho or 200) / ((tam or 13) * 0.47)))
  local lineas = 0
  for trozo in (tostring(txt or "") .. "\n"):gmatch("([^\n]*)\n") do lineas = lineas + math.max(1, math.ceil(#trozo / porLinea)) end
  if n == 0 then lineas = 1 end
  return lineas * ((tam or 13) + 3)
end
local function aproxAncho(txt, tam)
  tam = tf(tam or 13)
  local s = tostring(txt or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return #s * (tam or 13) * 0.5
end

local function nivel(f, n) if f and f.SetFrameLevel then pcall(f.SetFrameLevel, f, n) end end
local function nivelDe(f) return medir(f, "GetFrameLevel") or 1 end

function K.nuevo(marco)
  local k = { marco = marco, pools = {}, usados = {}, textos = {}, alto = 0 }
  -- Capa de arriba: textos, iconos, chips y botones van por encima de tarjetas y casillas
  k.capa = CreateFrame("Frame", nil, marco)
  k.capa:SetPoint("TOPLEFT", marco, "TOPLEFT", 0, 0)
  k.capa:SetPoint("BOTTOMRIGHT", marco, "BOTTOMRIGHT", 0, 0)
  k.medio = CreateFrame("Frame", nil, marco)
  k.medio:SetPoint("TOPLEFT", marco, "TOPLEFT", 0, 0)
  k.medio:SetPoint("BOTTOMRIGHT", marco, "BOTTOMRIGHT", 0, 0)
  local base = nivelDe(marco)
  nivel(k.medio, base + 3)
  nivel(k.capa, base + 8)
  setmetatable(k, { __index = K })
  return k
end

function K:empezar()
  for _, lista in pairs(self.pools) do for _, f in pairs(lista) do if f.Hide then f:Hide() end end end
  self.usados, self.textos, self.alto = {}, {}, 0
  local base = nivelDe(self.marco)
  nivel(self.medio, base + 3)
  nivel(self.capa, base + 8)
end
function K:anotar(t)
  if t and t ~= "" then table.insert(self.textos, tostring(t)) end
end
function K:hasta(y) if y > self.alto then self.alto = y end end
-- Pieza del pool: crear(padre) la primera vez; despues se reutiliza (ClearAllPoints + Show)
function K:tomar(tipo, padre, crear)
  self.pools[tipo] = self.pools[tipo] or {}
  local n = (self.usados[tipo] or 0) + 1
  self.usados[tipo] = n
  local f = self.pools[tipo][n]
  if not f then f = crear(padre); self.pools[tipo][n] = f end
  if f.ClearAllPoints then f:ClearAllPoints() end
  if f.Show then f:Show() end
  return f
end
local function poner(f, marco, x, y) f:SetPoint("TOPLEFT", marco, "TOPLEFT", x, -y) end

-- Tarjeta (E.tarjeta). variante "principal" (linea de acento del tema) | "recomendada" | "hundida" | nil.
-- fondo/borde opcionales (colores de la maqueta para casillas y para la tarjeta elegida).
function K:tarjeta(x, y, w, h, variante, fondo, borde, enMedio)
  local padre = enMedio and self.medio or self.marco
  local f = self:tomar(enMedio and "casilla" or "tarjeta", padre, function(pd) return E().tarjeta(pd, {}) end)
  E().tarjetaVariante(f, (variante == "principal" or variante == "recomendada") and variante or nil)
  if f.SetBackdropColor then
    -- 11-oct (Andy): tarjetas algo transparentes para que se vea el arte de fondo; "lectura" = texto largo, casi opaca
    -- 12-oct (Andy: "sigue tapando demasiado el fondo"): mas translucidas; las de texto largo siguen casi opacas
    local alfa = (variante == "lectura" and 0.88) or (variante == "hundida" and 0.4) or K.alfaTarjeta or 0.56
    pcall(f.SetBackdropColor, f, col(fondo or (variante == "hundida" and C().hundida) or C().piedra2, alfa))
    pcall(f.SetBackdropBorderColor, f, col(borde or C().borde, 1))
  end
  -- Franja interior izquierda de 3 px (tarjeta elegida de la lista de profesiones)
  local fr = rawget(f, "franja")
  if type(fr) == "table" and fr.Hide then fr:Hide() end
  f:SetSize(w, h)
  poner(f, self.marco, x, y)
  self:hasta(y + h)
  return f
end
function K:franja(f, color)
  local fr = rawget(f, "franja")
  if type(fr) ~= "table" then
    fr = f:CreateTexture(nil, "BORDER", nil, 2)
    -- 11-oct: metida 6 px arriba y abajo para no salirse de las esquinas redondas de la tarjeta
    fr:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -6); fr:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 6); fr:SetWidth(3)
    f.franja = fr
  end
  if fr.SetColorTexture then fr:SetColorTexture(col(color, 1)) end
  fr:Show()
end

-- Texto. opts: tam, color, peso ("regular"|"medio"|"negrita"), letra ("marca" = Cinzel), ancho (con ancho = varias lineas),
-- just ("LEFT"|"CENTER"|"RIGHT"), sinAnotar. Devuelve fs, alto, ancho.
function K:texto(x, y, txt, opts)
  opts = opts or {}
  local fs = self:tomar("fs", self.capa, function(pd) return pd:CreateFontString(nil, "OVERLAY", "GameFontHighlight") end)
  local tam = opts.tam or 14
  if opts.letra == "marca" then
    E().h2(self.capa, fs, tam)
    if opts.color then fs:SetTextColor(col(opts.color, 1)) end
  else
    E().texto(self.capa, fs, tam, opts.color, opts.peso)
  end
  if fs.SetWordWrap then fs:SetWordWrap(opts.ancho and true or false) end
  if fs.SetWidth then fs:SetWidth(opts.ancho or 0) end
  if fs.SetJustifyH then fs:SetJustifyH(opts.just or "LEFT") end
  if fs.SetJustifyV then fs:SetJustifyV("TOP") end
  if txt and WowF.T and WowF.enIngles and WowF.enIngles() then txt = WowF.T(txt) end
  fs:SetText(txt or "")
  if opts.punto then fs:SetPoint(unpack(opts.punto)) else poner(fs, self.marco, x, y) end
  local h = (opts.ancho and medir(fs, "GetStringHeight")) or (not opts.ancho and medir(fs, "GetStringHeight")) or aproxAlto(txt, opts.ancho, tam)
  local tamF = tf((opts.letra == "marca") and tam or math.max(12, tam)) -- 12-oct: el alto con el tamano final
  if opts.ancho and h < tamF then h = aproxAlto(txt, opts.ancho, tam) end
  local w = medir(fs, "GetStringWidth") or aproxAncho(txt, tam)
  if opts.ancho and w > opts.ancho then w = opts.ancho end
  if not opts.sinAnotar then self:anotar(txt) end
  if not opts.punto then self:hasta(y + h) end
  return fs, h, w
end
-- Rotulo (".eti"): negrita 12 en MAYUSCULAS; color por defecto = acento del tema
function K:rotulo(x, y, txt, color)
  local fs = self:tomar("rot", self.capa, function(pd) return pd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") end)
  E().rotulo(self.capa, fs, color or K.acentoTexto(), 12)
  E().ponerRotulo(fs, txt)
  poner(fs, self.marco, x, y)
  self:anotar(txt)
  self:hasta(y + tf(12) + 2)
  return fs, medir(fs, "GetStringWidth") or aproxAncho(txt, 12) * 1.15
end
-- Icono cuadrado: color del borde nil | "verde" | "oro" | "gris"; gris = desaturado
function K:icono(x, y, tam, textura, color, gris)
  local i = self:tomar("ic", self.capa, function(pd) return E().icono(pd, 36) end)
  i:SetSize(tam, tam)
  i:poner(textura, color, gris)
  poner(i, self.marco, x, y)
  self:hasta(y + tam)
  return i
end
-- Chip: "verde" | "oro" | "brasa" (= AHORA, color del tema) | "gris" | "neutro" (texto tenue, borde #4a443c, fondo #1d1b19)
function K:chip(x, y, txt, color, derecha)
  local c = self:tomar("chip", self.capa, function(pd) return E().chip(pd, "", "gris") end)
  c:poner(txt, color == "neutro" and "gris" or color)
  if color == "neutro" then
    if c.texto and c.texto.SetTextColor then c.texto:SetTextColor(col(C().tenue, 1)) end
    if c.borde and c.borde.SetColorTexture then c.borde:SetColorTexture(col(C().borde, 1)) end
    if c.fondo and c.fondo.SetColorTexture then c.fondo:SetColorTexture(col(K.NEUTRO_FONDO, 1)) end
  end
  local w = medir(c, "GetWidth") or (aproxAncho(txt, 12) + 16)
  if derecha then c:SetPoint("TOPRIGHT", self.marco, "TOPLEFT", x, -y) else poner(c, self.marco, x, y) end
  self:anotar(txt)
  self:hasta(y + (medir(c, "GetHeight") or math.max(20, tf(12) + 7)))
  return c, w
end
-- Boton del estilo nuevo: tipo "estandarte" | "secundario" | "terciario" | "toggle". activo = false lo apaga.
-- derecha = true: x es el borde derecho. Devuelve b, ancho.
function K:boton(x, y, txt, tipo, chico, fn, opts)
  opts = opts or {}
  local clave = "bt:" .. tipo .. (chico and ":c" or "")
  local b = self:tomar(clave, self.capa, function(pd)
    local nb = CreateFrame("Button", nil, pd, "UIPanelButtonTemplate")
    E().boton(nb, tipo, nil, chico)
    -- 11-oct: la ayuda se engancha UNA vez (HookScript); un SetScript en cada dibujo borraba los ganchos del estilo (color y luz al pasar el raton)
    nb:HookScript("OnEnter", function(s)
      -- rawget: el texto de ayuda es un campo propio del boton (solo texto; una funcion se llama)
      local a = rawget(s, "_ayuda")
      if type(a) == "function" then local ok, r = pcall(a); a = ok and r or nil end
      if type(a) ~= "string" or a == "" or not GameTooltip then return end
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(a, 1, 1, 1, 1, true); GameTooltip:Show()
    end)
    nb:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return nb
  end)
  b:SetText(txt or "")
  local w = E().botonAncho(b, chico, opts.minimo) or 80
  if opts.ancho then b:SetWidth(opts.ancho); w = opts.ancho end
  if tipo == "toggle" then E().toggle(b, opts.on) end
  E().botonActivo(b, opts.activo ~= false)
  b:SetScript("OnClick", function() if fn then fn() end end)
  b._ayuda = opts.ayuda
  if opts.derecha then b:SetPoint("TOPRIGHT", self.marco, "TOPLEFT", x, -y) else poner(b, self.marco, x, y) end
  self:anotar(txt)
  self:hasta(y + ((tipo == "terciario") and 18 or ((chico or tipo == "toggle") and 28 or 34)))
  return b, w
end
-- 15-oct (Andy: "un efecto que destaque" en el boton del Modo aprendizaje): halo detras del boton que late en oro
-- mientras esta apagado (llama a usarlo) y queda verde y quieto cuando esta encendido.
function K:brillo(b, on)
  local g = self:tomar("brillo", self.capa, function(pd)
    local f = CreateFrame("Frame", nil, pd)
    f.fuera = f:CreateTexture(nil, "BACKGROUND"); f.fuera:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); f.fuera:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.dentro = f:CreateTexture(nil, "ARTWORK"); f.dentro:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4); f.dentro:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    f:SetScript("OnUpdate", function(s, el)
      s._t = (s._t or 0) + (tonumber(el) or 0)
      local a = rawget(s, "_on") and 0.6 or (0.25 + 0.75 * (0.5 + 0.5 * math.sin(s._t * 3.5)))
      if s.SetAlpha then s:SetAlpha(a) end
    end)
    return f
  end)
  g:SetPoint("TOPLEFT", b, "TOPLEFT", -7, 7)
  g:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 7, -7)
  local base = tonumber(self.capa and self.capa.GetFrameLevel and self.capa:GetFrameLevel()) or 0
  if g.SetFrameLevel then g:SetFrameLevel(base + 1) end
  if b.SetFrameLevel then b:SetFrameLevel(base + 3) end
  local c = on and C().verde or C().oro
  if g.fuera.SetColorTexture then g.fuera:SetColorTexture(col(c, 0.35)) end
  if g.dentro.SetColorTexture then g.dentro:SetColorTexture(col(on and C().verde or C().orocl, 0.95)) end
  g._on = on and true or false
  return g
end
-- Zona de clic invisible (sobre una casilla o tarjeta) con ayuda al pasar el raton
function K:zona(x, y, w, h, fn, ayuda)
  local z = self:tomar("zona", self.capa, function(pd)
    local b = CreateFrame("Button", nil, pd)
    if b.RegisterForClicks then pcall(b.RegisterForClicks, b, "LeftButtonUp") end
    return b
  end)
  z:SetSize(w, h)
  poner(z, self.marco, x, y)
  z:SetScript("OnClick", function() if fn then fn() end end)
  z:SetScript("OnEnter", function(s)
    if not GameTooltip or not ayuda then return end
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    if type(ayuda) == "function" then pcall(ayuda, GameTooltip) else GameTooltip:SetText(ayuda, 1, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  z:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return z
end
function K:barra(x, y, w, valor, max, color)
  local b = self:tomar("barra", self.capa, function(pd) return E().barra(pd, w) end)
  b:SetWidth(w)
  poner(b, self.marco, x, y)
  b:poner(valor, max, color)
  self:hasta(y + 8)
  return b
end
function K:raya(x, y, w, color)
  local r = self:tomar("raya", self.capa, function(pd) return pd:CreateTexture(nil, "ARTWORK") end)
  if r.SetColorTexture then r:SetColorTexture(col(color or C().borde, 1)) end
  r:SetSize(w, 1)
  poner(r, self.marco, x, y)
  return r
end
-- Bola redonda con numero o check (pasos de profesiones)
function K:bola(x, y, txt, estilo)
  local b = self:tomar("bola", self.capa, function(pd)
    local f = CreateFrame("Frame", nil, pd)
    f:SetSize(22, 22)
    f.aro = f:CreateTexture(nil, "BACKGROUND", nil, 1); f.aro:SetAllPoints()
    f.dentro = f:CreateTexture(nil, "BACKGROUND", nil, 2); f.dentro:SetPoint("TOPLEFT", 1, -1); f.dentro:SetPoint("BOTTOMRIGHT", -1, 1)
    local MASCARA = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    if f.aro.SetMask then pcall(f.aro.SetMask, f.aro, MASCARA); pcall(f.dentro.SetMask, f.dentro, MASCARA) end
    f.txt = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.txt:SetPoint("CENTER", 0, 0)
    return f
  end)
  local tm = E().tema and E().tema() or {}
  local aro, fondo, letra = { 0.353, 0.318, 0.282 }, K.CASILLA, C().tenue
  if estilo == "ahora" then aro, fondo, letra = tm.ahoraBorde or tm.ahora or C().brasa, tm.ahora or C().brasa, tm.ahoraLetra or { 1, 0.86, 0.6 }
  elseif estilo == "ya" then aro, fondo, letra = C().verde, C().verdef, C().verde end
  if b.aro.SetColorTexture then b.aro:SetColorTexture(col(aro, 1)) end
  if b.dentro.SetColorTexture then b.dentro:SetColorTexture(col(fondo, 1)) end
  E().letra(b.txt, "cuerpoNegrita", 12)
  b.txt:SetTextColor(col(letra, 1))
  b.txt:SetText(txt or "")
  poner(b, self.marco, x, y)
  return b
end
function K:retrato(x, y, tam, opts)
  local r = self:tomar("ret" .. tam, self.capa, function(pd)
    if WowF.marcoRetrato then return WowF.marcoRetrato(pd, tam) end
    return E().retrato(pd, tam)
  end)
  poner(r, self.marco, x, y)
  if r.poner then pcall(r.poner, r, opts) end
  self:hasta(y + tam)
  return r
end
function K:cifra(x, y, n, rotulo, derecha)
  local c = self:tomar("cifra", self.capa, function(pd) return E().cifra(pd) end)
  c:poner(n, rotulo)
  if derecha then c:SetPoint("TOPRIGHT", self.marco, "TOPLEFT", x, -y) else poner(c, self.marco, x, y) end
  self:anotar(tostring(n or "") .. " " .. tostring(rotulo or ""))
  return c, medir(c, "GetWidth") or 60
end
-- Conmutador ("seg"): opciones { {clave, texto}, ... }; activa = clave; fn(clave). Devuelve el ancho total.
function K:seg(x, y, opciones, activa, fn)
  local dx = x
  for _, o in ipairs(opciones) do
    local clave = o[1]
    local _, w = self:boton(dx, y, o[2], "toggle", true, function() if clave ~= activa then fn(clave) end end, { on = clave == activa })
    dx = dx + w - 1
  end
  return dx - x + 1
end

-- Marco de una vista (una sola vez por vista) + su kit
function K.marcoDe(guardado, hoja, ancho)
  if guardado and guardado.marco then return guardado.marco, guardado.kit end
  local m = CreateFrame("Frame", nil, hoja)
  m:SetSize(ancho or 890, 600)
  local kit = K.nuevo(m)
  return m, kit
end

-- ===================== Vista de Combate =====================
local MAX_FILA = 7

local function datos(p)
  if not WowF.datosVistaCombate then return nil end
  local ok, d = pcall(WowF.datosVistaCombate, p)
  if ok and type(d) == "table" then return d end
  return nil
end

local function cambiarSub(ctx, clave)
  if ctx and ctx.irA then ctx.irA(clave)
  elseif ctx and ctx.ponerSub then ctx.ponerSub(clave) end
end

-- Barra de arriba: [Rotacion|Macros] [PvE|PvP] ... Fuente: X + Y · copiar enlaces
local function barraArriba(k, d, ancho, ctx, cual)
  local w1 = k:seg(0, 0, { { "Rotacion", L("Rotación", "Rotation") }, { "Macros", "Macros" } }, cual, function(c) cambiarSub(ctx, c) end)
  -- el segundo conmutador va 10 px despues del primero
  local w2 = k:seg(w1 + 10, 0, { { "pve", "PvE" }, { "pvp", "PvP" } }, d.modo == "pvp" and "pvp" or "pve", function(m) if WowF.modoRotacion then WowF.modoRotacion(m) end end)
  -- 13-oct: Modo aprendizaje (wowF_Aprendizaje.lua): ventanita que dice en combate que golpe toca
  if WowF.aprendizajeActivar and type(w2) == "number" then
    local on = WowF.aprendizajeActivo()
    local ba, wa = k:boton(w1 + 10 + w2 + 10, 0, L("Modo aprendizaje", "Learning mode"), on and "toggle" or "estandarte", true,
      function() WowF.aprendizajeActivar(not WowF.aprendizajeActivo()) end,
      { on = on, ayuda = L("Modo aprendizaje: una ventanita te dice en combate qué golpe toca AHORA y los 2 siguientes. Solo lo muestra; tú lo pulsas. Pensado para principiantes: el juego no deja leer todo en combate, así que a veces se equivoca.",
        "Learning mode: a small window tells you in combat which ability to press NOW and the next 2. It only shows it; you press it. Made for beginners: the game does not let addons read everything in combat, so it is sometimes wrong.") })
    -- 15-oct: que se vea (halo que late + cartel al lado)
    k:brillo(ba, on)
    k:chip(w1 + 10 + w2 + 10 + (tonumber(wa) or 120) + 14, 4, on and L("Activo", "On") or L("¡Pruébalo!", "Try it!"), on and "verde" or "brasa")
  end
  -- Fuente a la derecha, en su propia fila debajo de los botones (13-oct: con "Modo aprendizaje" el texto quedaba detras)
  local fuentes = d.fuentes or {}
  if #fuentes > 0 then
    local nombres, urls = {}, {}
    for _, f in ipairs(fuentes) do table.insert(nombres, f[1]); if f[2] then table.insert(urls, f[2]) end end
    local b = k:boton(ancho, 36, L("copiar enlaces", "copy links"), "terciario", false, function()
      if WowF.mostrarCopiaMacro then WowF.mostrarCopiaMacro(L("Fuentes", "Sources"), table.concat(urls, "\n")) end
    end, { derecha = true, ayuda = table.concat(urls, "\n") })
    for _, u in ipairs(urls) do k:anotar(u) end
    local txt = L("Fuente: ", "Source: ") .. table.concat(nombres, " + ") .. " · "
    k:texto(0, 0, txt, { tam = 12, color = C().tenue, punto = { "RIGHT", b, "LEFT", -10, 0 } })
  else
    k:texto(0, 0, L("Fuente: aún no hay datos de WoW Forever; pendiente de actualizar", "Source: no WoW Forever data yet; pending update"),
      { tam = 12, color = C().tenue, punto = { "TOPRIGHT", k.marco, "TOPLEFT", ancho, -38 } })
  end
  return 58
end

-- 15-oct: color de la linea "cuando" (misma clasificacion que el Modo aprendizaje)
local function colorCuando(c)
  local v = (c == "brasa" and K.acentoTexto()) or (c == "oro" and C().oro) or (c == "verde" and C().verde) or (c == "gris" and C().apagado) or K.CLARO
  v = v or K.CLARO
  return v[1], v[2], v[3]
end
K.colorCuando = colorCuando

-- Ayuda de un golpe (tooltip): el hechizo del juego + su estado
local function ayudaGolpe(g)
  return function(tt)
    local ok = false
    if g.id and tt.SetSpellByID then ok = pcall(tt.SetSpellByID, tt, g.id) end
    if not ok then tt:SetText(g.nombre, 1, 1, 1) end
    if g.desc and g.desc ~= "" then tt:AddLine(g.desc, 0.85, 0.82, 0.76, true) end
    if g.cuando then
      local r, gg, b = colorCuando(g.cuando.color)
      tt:AddLine(L("Cuándo: ", "When: ") .. g.cuando.corto, r, gg, b, true)
      tt:AddLine(g.cuando.largo, 0.77, 0.72, 0.66, true)
    end
    if g.ya then tt:AddLine(L("Clic: cógelo para ponerlo en tu barra.", "Click: pick it up to put it on your bar."), 0.49, 0.77, 0.35, true)
    elseif g.como then tt:AddLine(L("Te falta: ", "Missing: ") .. g.como, 1, 0.54, 0.17, true)
    elseif g.estado then tt:AddLine(g.estado, 0.64, 0.6, 0.55, true) end
  end
end
local function clicGolpe(g, ctx)
  if g.ya then if WowF.tomarHechizo then WowF.tomarHechizo(g.id) end; return end
  if not g.como then return end
  print("|cff33ccffForever Guide|r: " .. g.nombre .. " - " .. L("Te falta: ", "Missing: ") .. g.como)
  if g.accion == "talentos" then cambiarSub(ctx, "Talentos")
  elseif g.accion == "entrenador" and WowF.irAlEntrenador then WowF.irAlEntrenador(L("aprender ", "learn ") .. g.nombre) end
end

-- Tarjeta principal: la rotacion en el orden de la guia (7 por fila)
local function tarjetaRotacion(k, d, y, ancho, ctx)
  local x0, pad = 16, 12
  local interior = ancho - 32
  -- 16-oct (Andy: "mantener la armonía visual"): con más de 7 golpes, filas equilibradas (9 = 5 + 4), nunca 7 + 2 sueltos
  local nG = #d.golpes
  local porFila = MAX_FILA
  if nG > MAX_FILA then porFila = math.ceil(nG / math.ceil(nG / MAX_FILA)) end
  local cw = (interior - 8 * (porFila - 1)) / porFila
  local rama = (d.rama and d.rama ~= "") and (" " .. d.rama) or ""
  -- Medir las casillas antes de pintar la tarjeta (alto de cada fila = la casilla mas alta)
  local filas, fila = {}, {}
  for _, g in ipairs(d.golpes) do
    table.insert(fila, g)
    if #fila == porFila then table.insert(filas, fila); fila = {} end
  end
  if #fila > 0 then table.insert(filas, fila) end
  local t = k:tarjeta(0, y, ancho, 100, "principal")
  local yy = y + pad
  k:rotulo(x0, yy, L("Rotación", "Rotation") .. rama .. L(" · por prioridad", " · by priority"))
  -- Leyenda a la derecha: Ya lo tienes / Despues
  local c2, w2 = k:chip(ancho - 16, yy - 3, L("Después", "Later"), "gris", true)
  k:chip(ancho - 16 - w2 - 6, yy - 3, L("Ya lo tienes", "You have it"), "verde", true)
  yy = yy + 14 + 12
  if #d.golpes == 0 then
    local _, h = k:texto(x0, yy, d.sinDatos or L("Aún no hay datos de WoW Forever; pendiente de actualizar.", "No WoW Forever data yet; pending update."),
      { tam = 13, color = C().tenue, ancho = interior })
    yy = yy + h + 4
  end
  for fi, f in ipairs(filas) do
    -- alto de la fila
    local altoFila = 0
    local medidas = {}
    for ci, g in ipairs(f) do
      local wTxt = cw - 16
      local hN = math.max(30, aproxAlto(g.nombre, wTxt, 13))
      local hD = (g.desc and g.desc ~= "") and aproxAlto(g.desc, wTxt, 12) or 0
      local hC = g.cuando and aproxAlto(g.cuando.corto, wTxt, 12) or 0
      medidas[ci] = { hN = hN, hD = hD, hC = hC }
      local h = 12 + 44 + 8 + hN + (hC > 0 and (2 + hC) or 0) + (hD > 0 and (4 + hD) or 0) + ((not g.ya) and 28 or 0) + 10
      if h > altoFila then altoFila = h end
    end
    -- la fila incompleta va centrada
    local desp = (#filas > 1 and #f < porFila) and ((porFila - #f) * (cw + 8) / 2) or 0
    for ci, g in ipairs(f) do
      local cx = x0 + desp + (ci - 1) * (cw + 8)
      k:tarjeta(cx, yy, cw, altoFila, nil, K.CASILLA, K.CASILLA_BORDE, true)
      local luego = not g.ya
      -- numero del paso (Cinzel 13, acento; apagado si va despues)
      k:texto(cx + 6, yy + 5, tostring(g.i or ((fi - 1) * porFila + ci)), { tam = 13, letra = "marca", color = luego and C().apagado or K.acentoTexto(), sinAnotar = true })
      -- flecha entre casillas
      if ci > 1 then k:texto(cx - 9, yy + 24, "›", { tam = 16, peso = "negrita", color = C().oro2, sinAnotar = true }) end
      local cy = yy + 12
      k:icono(cx + (cw - 44) / 2, cy, 44, g.icono, luego and "gris" or "verde", luego)
      cy = cy + 44 + 8
      local _, hN = k:texto(cx + 8, cy, g.nombre, { tam = 13, peso = "negrita", color = luego and K.LUEGO or C().texto, ancho = cw - 16, just = "CENTER" })
      cy = cy + math.max(30, hN or 0)
      if g.cuando then
        local r, gg, b = colorCuando(g.cuando.color)
        local _, hC = k:texto(cx + 8, cy + 2, g.cuando.corto, { tam = 12, peso = "negrita", color = { r, gg, b }, ancho = cw - 16, just = "CENTER" })
        cy = cy + 2 + (hC or 14)
      end
      if g.desc and g.desc ~= "" then
        local _, hD = k:texto(cx + 8, cy + 4, g.desc, { tam = 12, peso = "regular", color = C().tenue, ancho = cw - 16, just = "CENTER" })
        cy = cy + 4 + (hD or 0)
      end
      if luego then
        local txt = g.nivel and (L("nivel ", "level ") .. g.nivel) or L("más adelante", "later on")
        local ch, wc = k:chip(0, 0, txt, "gris")
        ch:ClearAllPoints()
        ch:SetPoint("TOP", k.marco, "TOPLEFT", cx + cw / 2, -(cy + 8))
      end
      k:zona(cx, yy, cw, altoFila, function() clicGolpe(g, ctx) end, ayudaGolpe(g))
      if g.estado then k:anotar(g.estado) end
    end
    yy = yy + altoFila + 8
  end
  if #filas > 0 then yy = yy - 8 end
  -- Avisos y nota de la guia (debajo de los golpes)
  for _, a in ipairs({ { d.aviso, C().oro }, { d.nota, C().tenue } }) do
    if a[1] and a[1] ~= "" then
      local _, h = k:texto(x0, yy + 10, a[1], { tam = 12, peso = "regular", color = a[2], ancho = interior })
      yy = yy + 10 + h
    end
  end
  yy = yy + 14
  t:SetHeight(yy - y)
  k:hasta(yy)
  return yy
end

-- Fila del medio: tus totems (Shaman) + racial de tu raza
local function filaMedio(k, d, y, ancho)
  local hayTot = d.totems and #d.totems > 0
  local hayRac = #(d.raciales or {}) > 0
  if not hayTot and not hayRac then return y end
  local wTot = hayTot and (hayRac and math.floor((ancho - 12) * 1.6 / 2.6) or ancho) or 0
  local xRac = hayTot and (wTot + 12) or 0
  local wRac = ancho - xRac
  local altoTot, altoRac = 0, 0
  local tTot, tRac
  if hayTot then
    tTot = k:tarjeta(0, y, wTot, 100)
    k:rotulo(16, y + 14, L("Tus tótems", "Your totems"), C().oro)
    local cw = (wTot - 32 - 24) / 4
    for i, t in ipairs(d.totems) do
      local cx = 16 + (i - 1) * (cw + 8)
      local cy = y + 14 + 14 + 10
      k:icono(cx, cy, 32, t.icono, t.ya and "verde" or "gris", not t.ya)
      k:texto(cx + 42, cy, t.elemento, { tam = 14, peso = "negrita" })
      k:texto(cx + 42, cy + 17, L("nivel ", "level ") .. t.nivel, { tam = 12, peso = "regular", color = C().tenue })
      k:zona(cx, cy, cw, 32, nil, function(tt)
        local ok = false
        if t.id and tt.SetSpellByID then ok = pcall(tt.SetSpellByID, tt, t.id) end
        if not ok then tt:SetText(t.totem, 1, 1, 1) end
        tt:AddLine(t.ya and L("Ya lo tienes.", "You have it.") or (L("Llega con la misión de clase de nivel ", "Comes with the class quest at level ") .. t.nivel .. "."), 0.85, 0.82, 0.76, true)
      end)
      k:anotar(t.totem)
    end
    local _, h = k:texto(16, y + 14 + 14 + 10 + 32 + 8, L("Cada elemento llega con una misión de clase.", "Each element comes with a class quest."), { tam = 12, peso = "regular", color = C().tenue, ancho = wTot - 32 })
    altoTot = 14 + 14 + 10 + 32 + 8 + h + 14
  end
  if hayRac then
    tRac = k:tarjeta(xRac, y, wRac, 100)
    local raza = d.raza and (" " .. L("de ", "") .. d.raza) or ""
    local titulo = (#d.raciales > 1) and (L("Raciales", "Racials") .. raza) or (L("Racial", "Racial") .. raza)
    if WowF.enIngles and WowF.enIngles() and d.raza then titulo = d.raza .. " " .. ((#d.raciales > 1) and "racials" or "racial") end
    k:rotulo(xRac + 16, y + 14, titulo, C().oro)
    -- Sin totems: las raciales una al lado de otra; con totems, una debajo de otra
    local cols = hayTot and 1 or math.min(3, #d.raciales)
    local cw = (wRac - 32 - 12 * (cols - 1)) / cols
    local cy, maxFila, yFila = y + 14 + 14 + 10, 0, y + 14 + 14 + 10
    for i, r in ipairs(d.raciales) do
      local c = (i - 1) % cols
      if c == 0 and i > 1 then yFila = yFila + maxFila + 10; maxFila = 0 end
      local cx = xRac + 16 + c * (cw + 12)
      k:icono(cx, yFila, 44, r.icono)
      local _, hN = k:texto(cx + 54, yFila, r.nombre, { tam = 14, peso = "negrita", ancho = cw - 54 })
      local _, hD = k:texto(cx + 54, yFila + (hN or 16) + 2, r.desc or "", { tam = 12, peso = "regular", color = C().tenue, ancho = cw - 54 })
      local h = math.max(44, (hN or 16) + 2 + (hD or 0))
      if h > maxFila then maxFila = h end
      k:zona(cx, yFila, cw, h, nil, function(tt)
        local ok = false
        if r.id and tt.SetSpellByID then ok = pcall(tt.SetSpellByID, tt, r.id) end
        if not ok then tt:SetText(r.nombre, 1, 1, 1) end
        if r.desc then tt:AddLine(r.desc, 0.85, 0.82, 0.76, true) end
      end)
    end
    altoRac = (yFila + maxFila) - y + 14
  end
  local alto = math.max(altoTot, altoRac)
  if tTot then tTot:SetHeight(alto) end
  if tRac then tRac:SetHeight(alto) end
  k:hasta(y + alto)
  return y + alto
end

-- Tarjetas de macros (3 por fila)
local function tarjetasMacros(k, d, y, ancho, lista)
  local cols = 3
  local cw = (ancho - 12 * (cols - 1)) / cols
  local yy = y
  for inicio = 1, #lista, cols do
    local fila = {}
    for i = inicio, math.min(#lista, inicio + cols - 1) do table.insert(fila, lista[i]) end
    -- Pintar el contenido y medir; luego ajustar la tarjeta y poner los botones abajo (margin-top:auto)
    local tarjetas, finales = {}, {}
    local maxAlto = 0
    for ci, e in ipairs(fila) do
      local x = (ci - 1) * (cw + 12)
      local t = k:tarjeta(x, yy, cw, 100)
      tarjetas[ci] = t
      local cy = yy + 14
      local listo = e.listo and #e.faltan == 0
      k:icono(x + 16, cy, 44, e.icono, listo and "verde" or (e.listo and "oro" or "gris"), not e.listo)
      local _, hN = k:texto(x + 16 + 54, cy, e.nombre, { tam = 15, peso = "negrita", ancho = cw - 32 - 54 })
      local chY = cy + (hN or 18) + 4
      local chipTxt, chipCol
      if listo then chipTxt, chipCol = L("Ya puedes", "Ready"), "verde"
      elseif e.listo then chipTxt, chipCol = L("Te falta algo", "Something missing"), "oro"
      else chipTxt, chipCol = L("nivel ", "level ") .. e.nv, "gris" end
      local _, wc = k:chip(x + 16 + 54, chY, chipTxt, chipCol)
      -- 16-oct: tambien "Solo PvP"
      local uso = e.soloPve and L("Solo PvE", "PvE only") or (e.soloPvp and L("Solo PvP", "PvP only")) or L("PvE y PvP", "PvE and PvP")
      k:chip(x + 16 + 54 + wc + 4, chY, uso, "neutro")
      cy = math.max(cy + 44, chY + 20)
      -- Cuando (o En PvP si estas en modo PvP; si no hay "cuando", para que sirve)
      local rot, txt = L("Cuándo:", "When:"), e.cuando
      if e.soloPvp then rot = L("En PvP:", "In PvP:") end
      if d.modo == "pvp" and e.pvp then rot, txt = L("En PvP:", "In PvP:"), e.pvp end
      if d.modo == "pvp" and e.soloPve then rot, txt = L("En PvP:", "In PvP:"), L("no la uses contra jugadores; es para PvE.", "don't use it against players; it's for PvE.") end
      if not txt then rot, txt = L("Para qué:", "What for:"), e.paraQue end
      local linea = "|cffd8b468" .. rot .. "|r " .. (txt or "")
      local _, hC = k:texto(x + 16, cy + 10, linea, { tam = 13, peso = "medio", color = K.CLARO, ancho = cw - 32, sinAnotar = true })
      k:anotar(rot .. " " .. (txt or ""))
      cy = cy + 10 + (hC or 16)
      -- Lo que falta (macro lista por nivel pero sin un hechizo)
      for _, f in ipairs(e.faltan or {}) do
        local _, hF = k:texto(x + 16, cy + 4, L("Te falta: ", "Missing: ") .. f.nombre .. " - " .. (f.como or ""), { tam = 12, peso = "regular", color = C().oro, ancho = cw - 32 })
        cy = cy + 4 + (hF or 14)
      end
      -- 16-oct: lo que la macro usara mas adelante, y de que guia de WoW Forever sale (y para que rama)
      if e.extrasPend and #e.extrasPend > 0 and WowF.textoExtrasMacro then
        local _, hE = k:texto(x + 16, cy + 4, L("Más adelante también usará: ", "Later it will also use: ") .. WowF.textoExtrasMacro(e.extrasPend), { tam = 12, peso = "regular", color = K.CLARO, ancho = cw - 32 })
        cy = cy + 4 + (hE or 14)
      end
      if e.fuente then
        local _, hS = k:texto(x + 16, cy + 4, "|cff9a9a9a" .. L("Fuente: ", "Source: ") .. e.fuente .. (e.rama and (" · " .. L("para ", "for ") .. e.rama) or "") .. "|r", { tam = 11, peso = "regular", ancho = cw - 32 })
        cy = cy + 4 + (hS or 13)
      end
      -- Cuerpo de la macro (pre). WoW no trae Consolas: va en Alegreya 12.
      local pre = k:tarjeta(x + 16, cy + 8, cw - 32, 30, nil, K.PRE_FONDO, K.PRE_BORDE, true)
      local _, hP = k:texto(x + 16 + 10, cy + 8 + 8, e.cuerpo or "", { tam = 12, peso = "medio", color = K.PRE_LETRA, ancho = cw - 32 - 20 })
      pre:SetHeight((hP or 14) + 16)
      cy = cy + 8 + (hP or 14) + 16
      finales[ci] = cy
      local alto = (cy - yy) + 10 + 28 + 14
      if alto > maxAlto then maxAlto = alto end
    end
    for ci, e in ipairs(fila) do
      local x = (ci - 1) * (cw + 12)
      tarjetas[ci]:SetHeight(maxAlto)
      local by = yy + maxAlto - 14 - 28
      local _, wb = k:boton(x + 16, by, L("Crear macro", "Create macro"), "estandarte", true, function()
        if WowF.accionMacroVista then WowF.accionMacroVista(e) end
      end, { activo = e.listo, ayuda = e.paraQue .. (e.fuente and ("\n" .. L("Fuente: ", "Source: ") .. e.fuente .. (e.fuenteUrl and ("\n" .. e.fuenteUrl) or "")) or "") })
      k:boton(x + 16 + wb + 8, by, L("Copiar", "Copy"), "secundario", true, function()
        if WowF.mostrarCopiaMacro then WowF.mostrarCopiaMacro(e.nombre, e.cuerpo) end
      end)
      if e.paraQue then k:anotar(e.paraQue) end
    end
    yy = yy + maxAlto + 12
  end
  if #lista > 0 then yy = yy - 12 end
  k:hasta(yy)
  return yy
end

-- 15-oct: Modo aprendizaje · que es y como se usa
-- 16-oct (Andy: "es texto sin mas, fuera del estilo del addon"): rehecha con las piezas del addon:
-- cabecera con boton que brilla + vista previa de la ventanita con TUS golpes, pasos en casillas numeradas,
-- "como decide" como tira de casillas de color (igual que la rotacion) y el aviso "no es perfecto" en recuadro.
local function tarjetaAprendizaje(k, d, y, ancho)
  if not WowF.aprendizajeActivar then return y - 12 end
  local activo = WowF.aprendizajeActivo and WowF.aprendizajeActivo()
  local t = k:tarjeta(0, y, ancho, 100)
  local x0, interior = 16, ancho - 32
  local yy = y + 14
  k:rotulo(x0, yy, L("Modo aprendizaje · qué es y cómo se usa", "Learning mode · what it is and how to use it"))
  k:chip(ancho - 16, yy - 3, activo and L("Encendido", "On") or L("Apagado", "Off"), activo and "verde" or "gris", true)
  yy = yy + 14 + 12

  -- 1) Cabecera: que es (izquierda) + vista previa de la ventanita (derecha)
  local wPrev = math.min(380, math.floor(interior * 0.44))
  local wIzq = interior - wPrev - 20
  local xPrev = x0 + wIzq + 20
  local yTop = yy
  k:icono(x0, yTop, 44, "Interface\\Icons\\INV_Misc_Book_09", activo and "verde" or "oro")
  local _, hT = k:texto(x0 + 56, yTop, L("Te dice qué golpe toca, en combate", "It tells you what to press, in combat"),
    { tam = 18, letra = "marca", color = C().texto, ancho = wIzq - 56 })
  local _, hS = k:texto(x0 + 56, yTop + (hT or 22) + 4, L("Ventanita con el golpe de AHORA (icono grande y su tecla), los 2 siguientes y por qué. Usa esta misma rotación de WoW Forever. Solo te lo muestra: el golpe lo pulsas tú.",
    "A small window with the ability for NOW (big icon and its key), the next 2, and why. It uses this same WoW Forever rotation. It only shows it: you press the ability."),
    { tam = 13, color = K.CLARO, ancho = wIzq - 56 })
  local yb = math.max(yTop + 44, yTop + (hT or 22) + 4 + (hS or 32)) + 14
  local bAct, wb = k:boton(x0, yb, activo and L("Apagar el modo aprendizaje", "Turn learning mode off") or L("Activar el modo aprendizaje", "Turn learning mode on"),
    activo and "secundario" or "estandarte", true, function() WowF.aprendizajeActivar(not WowF.aprendizajeActivo()) end)
  k:brillo(bAct, activo)
  k:texto(x0 + (tonumber(wb) or 220) + 16, yb + 7, L("o escribe /wowf aprender on", "or type /wowf learn on"), { tam = 12, color = C().tenue })
  local yFinIzq = yb + 28

  -- Vista previa: AHORA › SIGUIENTE › LUEGO con tus golpes reales
  k:rotulo(xPrev, yTop - 2, L("Así se ve en combate", "How it looks in combat"), C().oro)
  local muestra = {}
  -- primero los que ya tienes y son de la rotacion (los "segun la situacion" no los pide la ventanita)
  local function sit(g) return g.cuando and g.cuando.color == "gris" end
  for _, g in ipairs(d.golpes or {}) do if g.ya and not sit(g) and #muestra < 3 then table.insert(muestra, g) end end
  for _, g in ipairs(d.golpes or {}) do if #muestra < 3 and not g.ya and not sit(g) then table.insert(muestra, g) end end
  for _, g in ipairs(d.golpes or {}) do if #muestra < 3 and sit(g) then table.insert(muestra, g) end end
  local yP = yTop + 18
  local altoPrev = 132
  k:tarjeta(xPrev, yP, wPrev, altoPrev, "hundida", nil, nil, true)
  local wA = math.floor((wPrev - 16 - 2 * 18) * 0.4)
  local wN = math.floor((wPrev - 16 - 2 * 18 - wA) / 2)
  local etiquetas = { { L("AHORA", "NOW"), "brasa" }, { L("SIGUIENTE", "NEXT"), "neutro" }, { L("LUEGO", "THEN"), "neutro" } }
  local cx = xPrev + 8
  for i = 1, 3 do
    local g = muestra[i]
    local w = (i == 1) and wA or wN
    local tamI = (i == 1) and 52 or 36
    local cy = yP + 8
    k:tarjeta(cx, cy, w, altoPrev - 16, nil, K.CASILLA, (i == 1) and C().verde or K.CASILLA_BORDE, true)
    k:icono(cx + (w - tamI) / 2, cy + 10, tamI, g and g.icono or nil, (i == 1) and "verde" or nil, i > 1)
    local ch = k:chip(0, 0, etiquetas[i][1], etiquetas[i][2])
    ch:ClearAllPoints(); ch:SetPoint("TOP", k.marco, "TOPLEFT", cx + w / 2, -(cy + 10 + tamI + 6))
    if g then
      k:texto(cx + 4, cy + 10 + tamI + 6 + 24, g.nombre, { tam = 12, peso = (i == 1) and "negrita" or "regular", color = (i == 1) and C().texto or K.LUEGO, ancho = w - 8, just = "CENTER", sinAnotar = true })
    end
    if i < 3 then k:texto(cx + w + 5, cy + 10 + tamI / 2 - 9, "›", { tam = 16, peso = "negrita", color = C().oro2, sinAnotar = true }) end
    cx = cx + w + 18
  end
  local yFinDer = yP + altoPrev
  local g1 = muestra[1]
  if g1 and g1.cuando and g1.cuando.corto then
    local r, gg, b = colorCuando(g1.cuando.color)
    local _, hq = k:texto(xPrev, yFinDer + 6, L("Por qué: ", "Why: ") .. g1.cuando.corto, { tam = 12, peso = "medio", color = { r, gg, b }, ancho = wPrev, sinAnotar = true })
    yFinDer = yFinDer + 6 + (hq or 14)
  end
  k:zona(xPrev, yP, wPrev, altoPrev, nil, L("Ejemplo con tus golpes: así te avisa la ventanita en combate. Verde = el de AHORA.", "Example with your abilities: this is how the window guides you in combat. Green = the one for NOW."))
  yy = math.max(yFinIzq, yFinDer) + 16

  -- 2) Aviso: no es perfecto (recuadro con franja brasa)
  local textoAviso = L("Pensado para quien empieza: te enseña una rotación base. El juego (Blizzard) no deja que los addons lean en combate cosas como recargas, energía, la vida exacta o algunos efectos, así que el modo las calcula por su cuenta y a veces se equivoca (te pide un golpe que aún no está listo o se salta uno). Úsalo como guía, no como regla.",
    "Made for beginners: it teaches you a basic rotation. The game (Blizzard) does not let addons read things like cooldowns, energy, exact health or some effects in combat, so the mode works them out on its own and is sometimes wrong (it asks for an ability that is not ready yet or skips one). Use it as a guide, not a rule.")
  local hAv = aproxAlto(textoAviso, interior - 36, 12)
  local av = k:tarjeta(x0, yy, interior, 14 + 16 + hAv + 12, "hundida", nil, nil, true)
  k:franja(av, C().brasa)
  k:rotulo(x0 + 16, yy + 10, L("Ten en cuenta: no es perfecto", "Keep in mind: it is not perfect"), C().brasa)
  local _, hl = k:texto(x0 + 16, yy + 10 + 16, textoAviso, { tam = 12, color = C().orocl, ancho = interior - 36 })
  local altoAv = 10 + 16 + math.max(hl or 0, hAv) + 12
  av:SetHeight(altoAv)
  yy = yy + altoAv + 18

  -- 3) Como se usa: 5 casillas numeradas con flecha entre ellas
  k:rotulo(x0, yy, L("Cómo se usa", "How to use it"), C().oro)
  yy = yy + 14 + 10
  local pasos = {
    { "Enciéndelo", "Turn it on", "Con el botón de arriba, el de esta tarjeta o /wowf aprender on.", "With the button at the top, the one on this card, or /wowf learn on." },
    { "Golpes en tu barra", "Abilities on your bar", "La ventanita te dice la tecla y hace brillar el botón.", "The window shows the key and makes the button glow." },
    { "Pulsa el icono grande", "Press the big icon", "Rojo = fuera de alcance: acércate.", "Red = out of range: get closer." },
    { "Auto / 1 / AoE", "Auto / 1 / AoE", "Auto cambia a golpes en área con 3 o más enemigos a la vista.", "Auto switches to area attacks with 3 or more enemies in view." },
    { "Muévela a tu gusto", "Move it anywhere", "Arrástrala. En Ajustes: brillo, sonido y ocultarla fuera de combate.", "Drag it. In Settings: glow, sound and hide it out of combat." },
  }
  local nP = #pasos
  local wP = (interior - 14 * (nP - 1)) / nP
  local altoP = 0
  for _, p in ipairs(pasos) do
    local h = 12 + 22 + 8 + aproxAlto(L(p[1], p[2]), wP - 20, 13) + 4 + aproxAlto(L(p[3], p[4]), wP - 20, 12) + 12
    if h > altoP then altoP = h end
  end
  -- el alto final sale del texto real (aproxAlto se pasa y dejaba hueco abajo)
  local casillas, altoReal = {}, 0
  for i, p in ipairs(pasos) do
    local px = x0 + (i - 1) * (wP + 14)
    casillas[i] = k:tarjeta(px, yy, wP, altoP, nil, K.CASILLA, K.CASILLA_BORDE, true)
    k:bola(px + 10, yy + 12, tostring(i), (i == 1 and activo) and "ya" or ((i == 1) and "ahora" or nil))
    local _, hN = k:texto(px + 10, yy + 12 + 22 + 8, L(p[1], p[2]), { tam = 13, peso = "negrita", color = C().texto, ancho = wP - 20 })
    local _, hD = k:texto(px + 10, yy + 12 + 22 + 8 + (hN or 16) + 4, L(p[3], p[4]), { tam = 12, color = C().tenue, ancho = wP - 20 })
    local h = 12 + 22 + 8 + (tonumber(hN) or 16) + 4 + (tonumber(hD) or 14) + 12
    if h > altoReal then altoReal = h end
  end
  if altoReal > 0 and altoReal < altoP then
    altoP = altoReal
    for _, c in ipairs(casillas) do if c and c.SetHeight then c:SetHeight(altoP) end end
  end
  for i = 2, nP do
    local px = x0 + (i - 1) * (wP + 14)
    k:texto(px - 11, yy + altoP / 2 - 10, "›", { tam = 16, peso = "negrita", color = C().oro2, sinAnotar = true })
  end
  yy = yy + altoP + 18

  -- 4) Como decide: tira de 7 casillas con el color de la linea "cuando" de la rotacion
  k:rotulo(x0, yy, L("Cómo decide qué golpe toca", "How it picks the next ability"), C().oro)
  k:texto(x0 + interior, yy - 1, L("de izquierda a derecha: lo primero que se cumpla", "left to right: the first one that applies"),
    { tam = 12, color = C().tenue, punto = { "TOPRIGHT", k.marco, "TOPLEFT", x0 + interior, -(yy - 1) } })
  yy = yy + 14 + 10
  local orden = {
    { "brasa", "Interrumpir si tu objetivo lanza", "Interrupt if your target casts" },
    { "brasa", "Lo que se encendió o ya se puede usar", "What lit up or just became usable" },
    { "oro", "Golpe en área con 3+ enemigos", "Area attack on 3+ enemies" },
    { "verde", "Efecto tuyo que falta", "Missing effect on you" },
    { "verde", "Efecto en tu enemigo que falta", "Missing effect on your enemy" },
    { "oro", "Recarga lista", "Cooldown ready" },
    { "neutro", "Relleno", "Filler" },
  }
  local nO = #orden
  local wO = (interior - 12 * (nO - 1)) / nO
  local altoO = 0
  for _, o in ipairs(orden) do
    local h = 10 + 18 + 6 + aproxAlto(L(o[2], o[3]), wO - 12, 12) + 10
    if h > altoO then altoO = h end
  end
  for i, o in ipairs(orden) do
    local ox = x0 + (i - 1) * (wO + 12)
    local r, g, b = colorCuando(o[1])
    k:tarjeta(ox, yy, wO, altoO, nil, K.CASILLA, { r * 0.55, g * 0.55, b * 0.55 }, true)
    k:texto(ox + 6, yy + 10, tostring(i), { tam = 16, letra = "marca", color = { r, g, b }, ancho = wO - 12, just = "CENTER", sinAnotar = true })
    k:texto(ox + 6, yy + 10 + 18 + 6, L(o[2], o[3]), { tam = 12, peso = "medio", color = { r, g, b }, ancho = wO - 12, just = "CENTER" })
    if i > 1 then k:texto(ox - 9, yy + altoO / 2 - 10, "›", { tam = 16, peso = "negrita", color = C().oro2, sinAnotar = true }) end
  end
  yy = yy + altoO + 12

  -- 5) Pie: casos especiales y que lista sigue (PvE / PvP)
  local extra = L("Con un aliado de objetivo: curas primero. Fuera de combate: lo de antes de pelear (sigilo, mascota, efectos). Lo gris de la rotación (según la situación) no te lo pide: lo decides tú.",
    "With an ally targeted: heals first. Out of combat: what goes before the fight (stealth, pet, effects). Grey items (situational) are never asked for: you decide.")
  local _, he = k:texto(x0, yy, extra, { tam = 12, color = C().tenue, ancho = interior })
  yy = yy + (he or 14) + 6
  local modo
  if d.modo == "pvp" and d.aviso then
    modo = L("PvP: tu rama aún no tiene guía PvP de WoW Forever; el modo sigue la lista PvE.", "PvP: your spec has no WoW Forever PvP guide yet; the mode follows the PvE list.")
  elseif d.modo == "pvp" then
    modo = L("PvP: sigue tu lista PvP (WoWForeverBuilds). Control y defensivas van como \"según la situación\": las decides tú.",
      "PvP: follows your PvP list (WoWForeverBuilds). Control and defensives are \"situational\": you decide.")
  else
    modo = L("PvE: sigue esta lista. Cambia a PvP con el botón de arriba y el modo seguirá la lista PvP.", "PvE: follows this list. Switch to PvP with the button at the top and the mode will follow the PvP list.")
  end
  local _, hm = k:texto(x0, yy, modo, { tam = 12, peso = "medio", color = C().oro, ancho = interior })
  yy = yy + (hm or 14)
  local fin = yy + 16
  t:SetHeight(fin - y)
  k:hasta(fin)
  return fin
end

local vistas = {}
local function preparar(cual, hoja, ancho)
  local v = vistas[cual]
  if not v then
    local m, kit = K.marcoDe(nil, hoja, ancho)
    v = { marco = m, kit = kit }
    vistas[cual] = v
  end
  if v.marco.GetParent and v.marco:GetParent() ~= hoja and v.marco.SetParent then v.marco:SetParent(hoja) end
  v.marco:SetWidth(ancho)
  v.kit:empezar()
  return v.marco, v.kit
end
local function terminar(m, k)
  m:SetHeight(math.max(1, k.alto))
  local lista = k.textos
  return m, k.alto, lista
end

function WowF.vistaRotacion(p, hoja, ancho, ctx)
  if not (WowF.estilo and WowF.estilo.tarjeta) then return nil end
  local d = datos(p)
  if not d then return nil end
  ancho = ancho or 890
  local m, k = preparar("Rotacion", hoja, ancho)
  local y = barraArriba(k, d, ancho, ctx, "Rotacion") + 12
  if WowF.aprendizajeCuando then pcall(WowF.aprendizajeCuando, d.golpes, d.clase) end
  y = tarjetaRotacion(k, d, y, ancho, ctx) + 12
  y = tarjetaAprendizaje(k, d, y, ancho) + 12
  local y2 = filaMedio(k, d, y, ancho)
  if y2 > y then y = y2 + 12 end
  -- Macros que ya puedes (como la maqueta: 3; las demas en la pestana Macros)
  local lista = {}
  for _, e in ipairs(d.macros) do if e.listo and #lista < 3 then table.insert(lista, e) end end
  if #lista > 0 then tarjetasMacros(k, d, y, ancho, lista) end
  return terminar(m, k)
end

function WowF.vistaMacros(p, hoja, ancho, ctx)
  if not (WowF.estilo and WowF.estilo.tarjeta) then return nil end
  local d = datos(p)
  if not d then return nil end
  ancho = ancho or 890
  local m, k = preparar("Macros", hoja, ancho)
  local y = barraArriba(k, d, ancho, ctx, "Macros") + 12
  if #d.macros == 0 then
    local t = k:tarjeta(0, y, ancho, 60, "hundida")
    local _, h = k:texto(16, y + 14, L("Aún no hay macros de WoW Forever para tu clase; pendiente de actualizar.", "No WoW Forever macros for your class yet; pending update."),
      { tam = 13, color = C().tenue, ancho = ancho - 32 })
    t:SetHeight(h + 28)
  else
    tarjetasMacros(k, d, y, ancho, d.macros)
  end
  return terminar(m, k)
end
