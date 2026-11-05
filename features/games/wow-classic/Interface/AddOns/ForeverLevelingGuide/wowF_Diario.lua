-- wowF Diario: la pestana Mazmorras del Libro al estilo de un diario de mazmorras (estilo "hibrido").
-- 11-oct (4.26). Izquierda: tarjetas con la miniatura de cada mazmorra (la recomendada resaltada, las proximas con su nivel,
-- las pasadas atenuadas). Derecha: ficha con el estandarte, el titulo y 3 sub-pestanas: Resumen, Jefes y botin, Misiones.
-- No es un catalogo: la recomendacion sale de WowF.mazmorrasParaTi (el mismo criterio que el panel y el tablero del Libro).
-- Datos: WowFDiario (wowF_Diario_Datos.lua, generado del cliente de WoW Forever) y retratos de WowF.retrato (wowF_Retratos.lua).
-- Si falta alguno de los dos, se usan iconos y nada se rompe. Bilingue con L(es, en) (fuera de textos-addon.js).

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local unpack = unpack or table.unpack
local VERDE, GRIS, NARANJA, MORADO = "|cff33ff66", "|cff999999", "|cffff9933", "|cffc77dff"
local ANCHO, IZQ, HUECO = 867, 216, 12 -- 12-oct: la hoja del Libro mide 867 (margenes iguales a cada lado; antes 880 llegaba a la barra)
local DER = ANCHO - IZQ - HUECO   -- 639
local XD = IZQ + HUECO            -- donde empieza la ficha
local ICONO_MAZMORRA = "Interface\\Icons\\INV_Misc_Key_03"
local ICONO_JEFE = 521744 -- icono de jefe del cliente (el mismo respaldo que usa wowF_Retratos)
local ICONO_MISION = "Interface\\Icons\\INV_Misc_Note_01"

local function numero(v)
  if v == nil then return nil end
  if issecretvalue then local ok, s = pcall(issecretvalue, v); if not ok or s then return nil end end
  return tonumber(v)
end
local function nivelActual()
  local ok, n = pcall(UnitLevel, "player")
  return (ok and numero(n)) or 1
end
local function tx(s) if type(s) ~= "string" then return "" end return (WowF.T and WowF.T(s)) or s end
local function cod(nombre) local E = WowF.estilo; return (E and E.cod and E.cod[nombre]) or "|cffffffff" end

-- ===================== Criterio unico de recomendacion (contrato 3) =====================
-- La logica de siempre del panel (4-oct): puntos = piezas que mejoran lo tuyo x2, +3 en su nivel ideal, +1 con la entrada conocida,
-- -5 al final de su rango. Hasta 3 abiertas que no estan al final de su rango (la 2.a y la 3.a solo si dan piezas o XP de misiones);
-- si todas lo estan, la mejor; sin ninguna abierta, la proxima (una). Sin pcall: un error de la comparacion tiene que verse.
-- Devuelve: lista ordenada de { m, estado = "ahora"|"proxima"|"pasada", piezas = N, lista = piezas, desde = nivel, porque, reco },
--           reco (las recomendadas, como el panel de siempre) y proximas (true = aun no hay ninguna abierta a tu nivel).
local function ideal(m) return math.floor((m.d + m.h) / 2) end
function WowF.mazmorrasParaTi(p, nivel)
  nivel = nivel or nivelActual()
  if p == nil and WowF.armarPlan then local ok, r = pcall(WowF.armarPlan); p = ok and r or nil end
  local lista, proximas = {}, false
  if WowF.disponibles then lista, proximas = WowF.disponibles(nivel) end
  lista = lista or {}
  local datos = {}
  local function piezasDe(m)
    if datos[m] then return datos[m] end
    local piezas = (WowF.piezasParaTi and WowF.piezasParaTi(p, m.i)) or (p and p.botin and p.botin[m.i]) or {}
    local _, xp = nil, 0
    if WowF.misionesDe then _, xp = WowF.misionesDe(m) end
    datos[m] = { piezas = piezas, xp = xp or 0 }
    return datos[m]
  end
  local reco = {}
  if #lista > 0 then
    if proximas or #lista == 1 then reco = { lista[1] }
    else
      local cand = {}
      for i, m in ipairs(lista) do
        local d = piezasDe(m)
        local puntos = #d.piezas * 2 + (nivel >= ideal(m) and 3 or 0) + (m.m and 1 or 0) - (nivel >= m.h - 2 and 5 or 0)
        table.insert(cand, { m = m, puntos = puntos, orden = i, util = #d.piezas > 0 or d.xp > 0 })
      end
      table.sort(cand, function(a, b) if a.puntos ~= b.puntos then return a.puntos > b.puntos end return a.orden < b.orden end)
      for _, c in ipairs(cand) do
        if nivel < c.m.h - 2 and #reco < 3 and (#reco == 0 or c.util) then table.insert(reco, c.m) end
      end
      if #reco == 0 then reco[1] = cand[1].m end
    end
  end
  local res, puesta = {}, {}
  local function entrada(m, estado, esReco)
    puesta[m] = true
    local e = { m = m, estado = estado, desde = m.d, reco = esReco or false, piezas = 0, lista = {} }
    if estado == "ahora" or (esReco and estado == "proxima") then
      local d = piezasDe(m)
      e.lista, e.piezas = d.piezas, #d.piezas
      e.porque = (#d.piezas > 0) and L(#d.piezas .. " piezas para ti", #d.piezas .. " pieces for you") or L("sin piezas para tu plan", "no pieces for your plan")
    elseif estado == "proxima" then e.porque = L("desde nivel " .. m.d, "from level " .. m.d)
    else e.porque = L("ya pasaste su nivel", "you are past its level") end
    table.insert(res, e)
  end
  for _, m in ipairs(reco) do entrada(m, proximas and "proxima" or "ahora", true) end
  local esMia = WowF.esMia or function() return true end
  local abiertas, futuras, pasadas = {}, {}, {}
  for _, m in ipairs(WowFMazmorras or {}) do
    if not puesta[m] and esMia(m) then
      if nivel > m.h then table.insert(pasadas, m) elseif nivel < m.d then table.insert(futuras, m) else table.insert(abiertas, m) end
    end
  end
  for _, m in ipairs(abiertas) do entrada(m, "ahora") end
  table.sort(futuras, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.n < b.n end)
  for _, m in ipairs(futuras) do entrada(m, "proxima") end
  table.sort(pasadas, function(a, b) if a.h ~= b.h then return a.h > b.h end return a.n < b.n end)
  for _, m in ipairs(pasadas) do entrada(m, "pasada") end
  return res, reco, proximas
end

-- ===================== Jefes de la ficha =====================
-- Scarlet Monastery: las 4 alas comparten la instancia 189 (7 jefes en WowFDiario). Solo los del ala (m.b, por nombre);
-- si m.b no trae ninguno, todos. Los de m.b sin datos del diario (Baron Aquanis, Gelihast...) van al final, sin cara.
local function jefesDe(m)
  local d = WowFDiario and WowFDiario[m.i]
  local delDiario = (d and d.jefes) or {}
  local enB = {}
  for _, n in ipairs(m.b or {}) do enB[n] = true end
  local res, vistos = {}, {}
  -- aka = el mismo jefe escrito distinto en Wowhead (13-oct: "Geilhast" del cliente / "Gelihast"): no se repite
  for _, j in ipairs(delDiario) do if enB[j.n] or (j.aka and enB[j.aka]) then table.insert(res, j); vistos[j.n] = true; if j.aka then vistos[j.aka] = true end end end
  if #res == 0 then for _, j in ipairs(delDiario) do table.insert(res, j); vistos[j.n] = true; if j.aka then vistos[j.aka] = true end end end
  for _, n in ipairs(m.b or {}) do if not vistos[n] then table.insert(res, { n = n, sinDiario = true }); vistos[n] = true end end
  return res
end
WowF.diarioJefesDe = jefesDe -- para las pruebas

-- Botin de tu rama en esta mazmorra, por jefe: lo tuyo primero (con el % de WowF.compararPieza), luego el resto
local function botinDe(p, m, tuyas)
  local esTuya = {}
  for _, o in ipairs(tuyas or {}) do esTuya[o.id] = true end
  local porJefe, sinJefe = {}, {}
  local deAka = {}   -- botin con el nombre de Wowhead ("Gelihast") va al jefe del diario ("Geilhast")
  local dd = WowFDiario and WowFDiario[m.i]
  for _, j in ipairs((dd and dd.jefes) or {}) do if j.aka then deAka[j.aka] = j.n end end
  for _, o in ipairs((p and p.botin and p.botin[m.i]) or {}) do
    local e = { o = o, tuya = esTuya[o.id] or false }
    if e.tuya and WowF.compararPieza then
      local ok, sirve, _, segura, cuanto = pcall(WowF.compararPieza, o, p)
      if ok and sirve then e.segura, e.cuanto = segura, numero(cuanto) end
    end
    local jf = o.jefe and (deAka[o.jefe] or o.jefe)
    if jf then porJefe[jf] = porJefe[jf] or {}; table.insert(porJefe[jf], e)
    else table.insert(sinJefe, e) end
  end
  local function ordenar(t)
    table.sort(t, function(a, b)
      if a.tuya ~= b.tuya then return a.tuya end
      if (a.cuanto or 0) ~= (b.cuanto or 0) then return (a.cuanto or 0) > (b.cuanto or 0) end
      return (a.o.n or "") < (b.o.n or "")
    end)
    return t
  end
  for k, t in pairs(porJefe) do ordenar(t) end
  ordenar(sinJefe)
  return porJefe, sinJefe
end

-- ===================== Marco y piezas reutilizables =====================
local marco, izq, ficha, banner, pestanas = nil, nil, nil, nil, {}
local elegida, sub, jefeSel, verPasadas = nil, "resumen", {}, false
local verFuturas = false -- 12-oct: "Mas adelante" muestra 4; [+] = todas
local sinAbrirPor = nil -- 12-oct (Andy: "Ver menos no hace nada"): la elegida oculta ya no reabre la lista tras pulsar Ver menos
local estado = {}  -- para las pruebas
-- 11-oct (ideas de GearQuest/DFL): buscador (solo esta sesion) y "Botin de todas" con favoritas
local buscar, soloFav, subAntes = "", false, "resumen"
local caja, cajaAyuda

local function pool(crear)
  local p = { lista = {}, n = 0 }
  function p:tomar() self.n = self.n + 1; local w = self.lista[self.n]; if not w then w = crear(); self.lista[self.n] = w end; w:Show(); return w end
  function p:soltar() for _, w in pairs(self.lista) do w:Hide() end; self.n = 0 end
  return p
end
local textos, tarjetas, retratos, filasObj, botones, iconos, capa
-- 11-oct (djextra): chips de confianza, fondos y franjas (tarjetas de mision, requisito) y recompensas con icono
local chips, fondos, franjas, premios
local chipTextos = {}   -- textos de los chips que se ven (los lee WowF.diarioTexto)
local soloMias = false  -- Misiones: "Solo las que tengo" (en tu registro)

local function crearMarco()
  if marco then return end
  local E = WowF.estilo
  marco = CreateFrame("Frame", nil, WowF.libroHoja)
  marco:SetSize(ANCHO, 10)
  marco:Hide()
  izq = CreateFrame("Frame", nil, marco)
  izq:SetPoint("TOPLEFT", 0, 0); izq:SetSize(IZQ, 10)
  ficha = E and E.tarjeta and E.tarjeta(marco, { fondo = E.color.piedra, acento = true }) or CreateFrame("Frame", nil, marco)
  ficha:SetPoint("TOPLEFT", XD, 0); ficha:SetSize(DER, 10)
  -- Estandarte de la mazmorra (fondo del cliente; si no hay, piedra con la llave)
  banner = CreateFrame("Frame", nil, ficha)
  banner:SetPoint("TOPLEFT", 1, -3); banner:SetSize(DER - 2, 110)
  banner.img = banner:CreateTexture(nil, "BACKGROUND", nil, 1)
  banner.img:SetAllPoints()
  banner.sombra = banner:CreateTexture(nil, "BORDER", nil, 1)
  banner.sombra:SetPoint("BOTTOMLEFT"); banner.sombra:SetPoint("BOTTOMRIGHT"); banner.sombra:SetHeight(54)
  if banner.sombra.SetColorTexture then banner.sombra:SetColorTexture(0, 0, 0, 0.62) end
  banner.icono = banner:CreateTexture(nil, "ARTWORK", nil, 1)
  banner.icono:SetSize(40, 40); banner.icono:SetPoint("TOPRIGHT", -12, -12)
  banner.titulo = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  banner.titulo:SetPoint("BOTTOMLEFT", 12, 26); banner.titulo:SetWidth(DER - 24)
  if E then E.titulo(banner, banner.titulo, 19) end
  banner.sub = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  banner.sub:SetPoint("BOTTOMLEFT", 12, 10); banner.sub:SetWidth(DER - 24)
  if E then E.sub(banner, banner.sub, 10) end
  banner.etq = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  banner.etq:SetPoint("TOPLEFT", 12, -10); banner.etq:SetWidth(DER - 80)
  if E then E.etiqueta(banner, banner.etq, E.color.brasa, 9) end
  local anchos, xp = { 84, 112, 84, 74, 74 }, 10 -- 12-oct: 4.a "Ruta" (wowF_DiarioRuta.lua) y 5.a "Mapa" (wowF_DiarioMapa.lua)
  for i = 1, 5 do
    local b = CreateFrame("Button", nil, ficha, "UIPanelButtonTemplate")
    b:SetSize(anchos[i], 22)
    b:SetPoint("TOPLEFT", xp, -120)
    xp = xp + anchos[i] + 4
    if E then E.boton(b, "cuero", 11) end
    pestanas[i] = b
  end

  -- 11-oct (ideas de GearQuest/DFL): buscador arriba de la lista (mazmorras, jefes y botin de tu rama).
  -- Sin UISpecialFrames: Esc y Enter solo quitan el foco.
  caja = CreateFrame("EditBox", nil, izq, "InputBoxTemplate")
  caja:SetSize(IZQ - 12, 20); caja:SetPoint("TOPLEFT", izq, "TOPLEFT", 8, -2)
  if caja.SetAutoFocus then caja:SetAutoFocus(false) end
  if caja.SetMaxLetters then caja:SetMaxLetters(40) end
  cajaAyuda = caja:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  cajaAyuda:SetPoint("LEFT", caja, "LEFT", 2, 0)
  caja:SetScript("OnTextChanged", function(self, deUsuario)
    local s = self:GetText() or ""
    if cajaAyuda then if s == "" then cajaAyuda:Show() else cajaAyuda:Hide() end end
    if deUsuario and s ~= buscar then
      buscar = s
      if WowF.libroRedibujar then WowF.libroRedibujar() end
      -- 13-oct (Andy: "escribes la primera letra y lo demas activa los atajos del juego"): redibujar el Libro oculta y
      -- vuelve a mostrar la caja y le quita el foco; se lo devolvemos con el cursor al final
      if self.IsVisible and self:IsVisible() and self.HasFocus and not self:HasFocus() and self.SetFocus then
        self:SetFocus()
        if self.SetCursorPosition then self:SetCursorPosition(#(self:GetText() or "")) end
      end
    end
  end)
  caja:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  caja:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

  -- 11-oct: textos e iconos en una capa ENCIMA de la ficha (con marco:CreateFontString quedaban debajo del fondo
  -- opaco de la tarjeta: nombres de jefes y misiones invisibles, solo se veian los retratos)
  capa = CreateFrame("Frame", nil, marco)
  capa:SetAllPoints(marco)
  if capa.SetFrameLevel and marco.GetFrameLevel then pcall(capa.SetFrameLevel, capa, (tonumber(marco:GetFrameLevel()) or 0) + 4) end
  textos = pool(function() local f = capa:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); if f.SetWordWrap then f:SetWordWrap(true) end; return f end)
  iconos = pool(function() local t = capa:CreateTexture(nil, "ARTWORK", nil, 3); if t.SetTexCoord then t:SetTexCoord(0.08, 0.92, 0.08, 0.92) end; return t end)
  botones = pool(function()
    local b = CreateFrame("Button", nil, marco, "UIPanelButtonTemplate")
    if b.SetFrameLevel and marco.GetFrameLevel then pcall(b.SetFrameLevel, b, (tonumber(marco:GetFrameLevel()) or 0) + 6) end
    return b
  end)
  retratos = pool(function()
    local f
    if WowF.marcoRetrato then f = WowF.marcoRetrato(marco, 32)
    else
      f = CreateFrame("Frame", nil, marco); f:SetSize(32, 32)
      f.tex = f:CreateTexture(nil, "ARTWORK"); f.tex:SetAllPoints()
      if f.tex.SetTexCoord then f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
      function f:poner(o) self.opts = o; self.tex:SetTexture(o and o.icono or ICONO_JEFE); return "icono" end
      function f:resaltar() end
    end
    if f.SetFrameLevel and marco.GetFrameLevel then pcall(f.SetFrameLevel, f, (tonumber(marco:GetFrameLevel()) or 0) + 5) end
    return f
  end)
  tarjetas = pool(function()
    local t = E and E.tarjeta and E.tarjeta(izq, { fondo = E.color.cuero2, acento = E.color.brasa }) or CreateFrame("Frame", nil, izq)
    t:SetSize(IZQ, 54)
    if t.acento then t.acento:Hide() end
    t.mini = t:CreateTexture(nil, "ARTWORK", nil, 1)
    t.mini:SetSize(64, 40); t.mini:SetPoint("TOPLEFT", 6, -7)
    t.sel = t:CreateTexture(nil, "OVERLAY", nil, 2)
    t.sel:SetPoint("TOPLEFT", 1, -1); t.sel:SetPoint("BOTTOMLEFT", 1, 1); t.sel:SetWidth(3)
    if t.sel.SetColorTexture and E then t.sel:SetColorTexture(E.color.oro[1], E.color.oro[2], E.color.oro[3], 1) end
    t.nombre = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.nombre:SetPoint("TOPLEFT", 76, -6); t.nombre:SetWidth(IZQ - 82)
    if t.nombre.SetWordWrap then t.nombre:SetWordWrap(false) end
    if E then E.cuerpo(t, t.nombre, 11) end
    t.etq = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.etq:SetPoint("TOPLEFT", 76, -21); t.etq:SetWidth(IZQ - 82)
    if t.etq.SetWordWrap then t.etq:SetWordWrap(false) end
    if E then E.etiqueta(t, t.etq, E.color.brasa, 8) end
    t.det = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.det:SetPoint("TOPLEFT", 76, -34); t.det:SetWidth(IZQ - 82)
    if t.det.SetWordWrap then t.det:SetWordWrap(false) end
    if E then E.sub(t, t.det, 9) end
    t.boton = CreateFrame("Button", nil, t)
    t.boton:SetAllPoints()
    return t
  end)
  filasObj = pool(function()
    local f
    if E and E.fila then f = E.fila(marco, DER - 24, 24)
    else
      f = CreateFrame("Button", nil, marco); f:SetSize(DER - 24, 32)
      f.icono = f:CreateTexture(nil, "ARTWORK"); f.icono:SetSize(24, 24); f.icono:SetPoint("LEFT", 0, 0)
      f.nombre = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.nombre:SetPoint("TOPLEFT", 30, -2)
      f.detalle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.detalle:SetPoint("TOPLEFT", 30, -16)
      function f:poner(ic, n, d) self.icono:SetTexture(ic); self.nombre:SetText(n); self.detalle:SetText(d or "") end
    end
    if f.RegisterForClicks then pcall(f.RegisterForClicks, f, "LeftButtonUp", "RightButtonUp") end
    if f.SetFrameLevel and marco.GetFrameLevel then pcall(f.SetFrameLevel, f, (tonumber(marco:GetFrameLevel()) or 0) + 5) end
    return f
  end)
  -- 11-oct (djextra): chips (E.chip) encima de todo; fondos y franjas en la capa (debajo de sus textos)
  chips = pool(function()
    local c
    if E and E.chip then
      c = E.chip(marco, "", "gris")
      if E.letra and c.texto then pcall(E.letra, c.texto, "cuerpoNegrita", 9) end -- pequenos: no compiten con el titulo
    else
      c = CreateFrame("Frame", nil, marco); c:SetSize(60, 16)
      c.texto = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); c.texto:SetPoint("CENTER")
      function c:poner(t) self.texto:SetText(t or "") end
    end
    if c.SetFrameLevel and marco.GetFrameLevel then pcall(c.SetFrameLevel, c, (tonumber(marco:GetFrameLevel()) or 0) + 6) end
    return c
  end)
  fondos = pool(function() return capa:CreateTexture(nil, "BACKGROUND", nil, 1) end)
  franjas = pool(function() return capa:CreateTexture(nil, "BORDER", nil, 1) end)
  premios = pool(function()
    local b = CreateFrame("Button", nil, marco)
    b:SetSize(26, 26)
    b.borde = b:CreateTexture(nil, "BACKGROUND", nil, 1); b.borde:SetAllPoints()
    b.icono = b:CreateTexture(nil, "ARTWORK", nil, 1); b.icono:SetPoint("TOPLEFT", 2, -2); b.icono:SetPoint("BOTTOMRIGHT", -2, 2)
    if b.icono.SetTexCoord then b.icono:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if b.SetFrameLevel and marco.GetFrameLevel then pcall(b.SetFrameLevel, b, (tonumber(marco:GetFrameLevel()) or 0) + 6) end
    return b
  end)
end

-- Un texto en (x, y) del marco con el estilo pedido: "titulo" | "cuerpo" | "sub" | "etiqueta"
local function texto(x, y, ancho, s, tipo, tam, color)
  local E = WowF.estilo
  local f = textos:tomar()
  f:ClearAllPoints(); f:SetPoint("TOPLEFT", marco, "TOPLEFT", x, -y); f:SetWidth(ancho)
  if E then
    if tipo == "titulo" then E.titulo(marco, f, tam or 15)
    elseif tipo == "sub" then E.sub(marco, f, tam or 10)
    elseif tipo == "etiqueta" then E.etiqueta(marco, f, color or E.color.brasa, tam or 9)
    else E.cuerpo(marco, f, tam or 11, color) end
  end
  if f.SetJustifyH then f:SetJustifyH("LEFT") end
  f:SetText((tipo == "etiqueta" and E and E.mayus) and E.mayus(s) or s)
  local alto = (f.GetStringHeight and numero(f:GetStringHeight())) or 0
  if alto <= 0 then alto = (tam or 11) + 3 end
  return f, alto
end
local function boton(x, y, ancho, alto, s, tipo, fn)
  local b = botones:tomar()
  b:ClearAllPoints(); b:SetPoint("TOPLEFT", marco, "TOPLEFT", x, -y); b:SetSize(ancho, alto)
  if WowF.estilo then WowF.estilo.boton(b, tipo or "cuero", 11) end
  b:SetText(s)
  if b.SetAlpha then b:SetAlpha(1) end -- el pool reutiliza los botones invisibles de los jefes del Resumen
  b:SetScript("OnClick", fn)
  return b
end
local function retrato(x, y, tam, opts)
  local r = retratos:tomar()
  r:ClearAllPoints(); r:SetPoint("TOPLEFT", marco, "TOPLEFT", x, -y); r:SetSize(tam, tam)
  if r.resaltar then pcall(r.resaltar, r, opts and opts.resaltar) end
  local ok = pcall(r.poner, r, opts)
  if not ok and r.tex then pcall(r.tex.SetTexture, r.tex, opts and opts.icono or ICONO_JEFE) end
  return r
end
local function icono(x, y, tam, tex)
  local t = iconos:tomar()
  t:ClearAllPoints(); t:SetPoint("TOPLEFT", marco, "TOPLEFT", x, -y); t:SetSize(tam, tam)
  t:SetTexture(tex or ICONO_MISION)
  return t
end
-- 11-oct (djextra): chip pequeno en (x, y); devuelve el chip y su ancho. color: "gris" (confianza) | "verde" | "oro" | "brasa"
local function chip(x, y, s, color)
  local c = chips:tomar()
  c:ClearAllPoints(); c:SetPoint("TOPLEFT", marco, "TOPLEFT", x, -y)
  pcall(c.poner, c, s, color or "gris")
  if c.SetHeight then c:SetHeight(16) end
  local t = (WowF.estilo and WowF.estilo.mayus) and WowF.estilo.mayus(s) or s
  table.insert(chipTextos, "[" .. t .. "]")
  return c, (tonumber(c.GetWidth and c:GetWidth()) or 60)
end
-- Rectangulo de color en (x, y): pool = fondos (debajo) o franjas (encima de los fondos)
local function rect(p, x, y, ancho, alto, col, a)
  local t = p:tomar()
  t:ClearAllPoints(); t:SetPoint("TOPLEFT", marco, "TOPLEFT", x, -y); t:SetSize(ancho, alto)
  if t.SetColorTexture then t:SetColorTexture(col[1], col[2], col[3], a or 1) end
  return t
end
-- 12-oct (Andy, "Mesa de guerra" punto 2): mecanicas minimas de cada jefe y datos de valor de la mazmorra.
-- WowFMecanicas (wowF_Mecanicas_Datos.lua, generado desde las guias de Icy Veins /wow-forever). Sin dato = aviso, nada inventado.
function WowF.mecanicasDe(i) return WowFMecanicas and i and WowFMecanicas[i] or nil end
function WowF.mecanicasJefe(i, j)
  local d = WowF.mecanicasDe(i)
  if not d or not j then return nil end
  local e = j.e or (d.nombres and d.nombres[j.n])
  local t = e and d.jefes and d.jefes[e]
  return (t and #t > 0) and t or nil
end
-- Bloque con titulo, vinetas (frases {es, en}) y la fuente; sin frases = aviso. Devuelve la y de abajo y cuantas vinetas pinto.
local function pintarMecanicas(y, titulo, frases)
  local E = WowF.estilo
  local x0, ancho = XD + 14, DER - 28
  rect(fondos, x0 - 6, y - 4, ancho + 12, 2, E and E.color.oro2 or { 0.55, 0.42, 0.18 }, 0.8)
  y = y + 6
  texto(x0, y, ancho, titulo, "etiqueta", 9)
  y = y + 17
  if not frases or #frases == 0 then
    local _, a = texto(x0, y, ancho, cod("brasa") .. L("Aún no hay datos de WoW Forever; pendiente de actualizar.",
      "No WoW Forever data yet; pending update.") .. "|r", "cuerpo", 11)
    return y + a + 10, 0
  end
  local oro = E and E.color.oro or { 0.85, 0.71, 0.41 }
  for _, f in ipairs(frases) do
    rect(franjas, x0 + 2, y + 5, 5, 5, oro, 1)
    local _, a = texto(x0 + 14, y, ancho - 14, cod("texto") .. L(f[1], f[2]) .. "|r", "cuerpo", 11)
    y = y + a + 4
  end
  local _, a2 = texto(x0, y + 1, ancho, GRIS .. L("Fuente: Icy Veins (WoW Forever)", "Source: Icy Veins (WoW Forever)") .. "|r", "sub", 9)
  return y + a2 + 10, #frases
end
local function redibujar() if WowF.libroRedibujar then WowF.libroRedibujar() end end

-- Imagen del cliente con el recorte que usa el diario del juego; si no hay, un fondo de piedra liso (nunca la llave;
-- la llave solo si el cliente no sabe pintar colores)
local function ponerImagen(tex, id, coords)
  if id then
    local ok = pcall(tex.SetTexture, tex, id)
    if ok then if tex.SetTexCoord then tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end; return true end
  end
  if tex.SetColorTexture then
    local c = WowF.estilo and WowF.estilo.color and WowF.estilo.color.piedra2 or { 0.16, 0.15, 0.14 }
    if tex.SetTexCoord then tex:SetTexCoord(0, 1, 0, 1) end
    tex:SetColorTexture(c[1], c[2], c[3], 1)
    return false
  end
  tex:SetTexture(ICONO_MAZMORRA)
  if tex.SetTexCoord then tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  return false
end

-- Objetos: clic = verlo y compararlo, Ctrl-clic = probartelo, Mayus-clic = enlazarlo en el chat
local function enlace(id)
  local ok, _, l = pcall(GetItemInfo, id)
  return (ok and type(l) == "string") and l or ("item:" .. id)
end
local function tooltipObjeto(f, comparar)
  if not GameTooltip or not f.objeto then return end
  GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
  if GameTooltip.SetItemByID then pcall(GameTooltip.SetItemByID, GameTooltip, f.objeto) else pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. f.objeto) end
  if f.porque then GameTooltip:AddLine(f.porque, 1, 1, 1, true) end
  GameTooltip:AddLine(L("Clic: comparar · Mayús-clic: enlazar en el chat", "Click: compare · Shift-click: link in chat"), 0.64, 0.6, 0.55, true)
  GameTooltip:Show()
  if comparar and GameTooltip_ShowCompareItem then pcall(GameTooltip_ShowCompareItem, GameTooltip) end
end
local function clicObjeto(f)
  if not f.objeto then return end
  local l = enlace(f.objeto)
  if IsControlKeyDown and IsControlKeyDown() and DressUpItemLink then pcall(DressUpItemLink, l); return end
  if IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink then pcall(ChatEdit_InsertLink, l); return end
  tooltipObjeto(f, true)
end
-- 12-oct (Andy): boton a la vista "Ver como queda" (probador, DressUpItemLink) en vez del texto "Ctrl-clic = probar".
-- Ctrl-clic sobre la fila sigue funcionando. Ancho fijo ANCHO_PROBAR; x = borde izquierdo del boton.
local ANCHO_PROBAR = 104
local function botonProbar(x, y, id)
  return boton(x, y, ANCHO_PROBAR, 22, L("Ver cómo queda", "Try it on"), "cuero", function()
    if DressUpItemLink then pcall(DressUpItemLink, enlace(id)) end
    estado.probado = id
  end)
end

-- 11-oct (djextra): "Comparar con lo puesto". Ventanita de 2 columnas (lo que llevas | esta pieza) con el resultado de
-- WowF.compararEnRanura (los mismos pesos de tu rama que el resto del addon). En anillos, abalorios y armas, un boton por hueco.
-- Sin nombre global ni UISpecialFrames (se cierra con la X o al salir del diario).
local planActual, vComp
local NOMBRE_HUECO = { [11] = "Finger 1", [12] = "Finger 2", [13] = "Trinket 1", [14] = "Trinket 2", [16] = "Main Hand", [17] = "Off Hand" }
local function ventanaComparar()
  if vComp then return vComp end
  local E = WowF.estilo
  local v = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  v:SetSize(440, 196); v:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  pcall(v.SetFrameStrata, v, "DIALOG")
  if WowF.registrarVentana then WowF.registrarVentana(v) end -- 12-oct: crece con el tamano de letra
  if v.EnableMouse then v:EnableMouse(true) end
  if v.SetMovable and v.RegisterForDrag then
    v:SetMovable(true); v:RegisterForDrag("LeftButton")
    v:SetScript("OnDragStart", function(self) self:StartMoving() end)
    v:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  end
  if E and E.marco then pcall(E.marco, v, "tapa") end
  v.titulo = v:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  v.titulo:SetPoint("TOP", v, "TOP", 0, -14); v.titulo:SetWidth(400)
  if E then E.titulo(v, v.titulo, 14) end
  v.col = {}
  for i = 1, 2 do
    local x = 20 + (i - 1) * 210
    local c = {}
    c.cab = v:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    c.cab:SetPoint("TOPLEFT", v, "TOPLEFT", x, -42); c.cab:SetWidth(190)
    if E then E.etiqueta(v, c.cab, E.color.brasa, 9) end
    c.icono = v:CreateTexture(nil, "ARTWORK")
    c.icono:SetSize(36, 36); c.icono:SetPoint("TOPLEFT", v, "TOPLEFT", x, -60)
    if c.icono.SetTexCoord then c.icono:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    c.nombre = v:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.nombre:SetPoint("TOPLEFT", v, "TOPLEFT", x + 42, -62); c.nombre:SetWidth(148)
    if E then E.cuerpo(v, c.nombre, 11) end
    c.zona = CreateFrame("Button", nil, v)
    c.zona:SetPoint("TOPLEFT", v, "TOPLEFT", x, -58); c.zona:SetSize(190, 40)
    c.zona:SetScript("OnEnter", function(self)
      if not GameTooltip or not c.link then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); pcall(GameTooltip.SetHyperlink, GameTooltip, c.link); GameTooltip:Show()
    end)
    c.zona:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    v.col[i] = c
  end
  v.resultado = v:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  v.resultado:SetPoint("TOP", v, "TOP", 0, -112); v.resultado:SetWidth(400)
  if E then E.cuerpo(v, v.resultado, 13) end
  v.huecos = {}
  for i = 1, 2 do
    local b = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
    b:SetSize(120, 22); b:SetPoint("BOTTOM", v, "BOTTOM", (i == 1) and -64 or 64, 16)
    v.huecos[i] = b
  end
  v.cerrar = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
  v.cerrar:SetSize(24, 22); v.cerrar:SetPoint("TOPRIGHT", v, "TOPRIGHT", -8, -8)
  if E then E.boton(v.cerrar, "cuero", 11) end
  v.cerrar:SetText("X")
  v.cerrar:SetScript("OnClick", function() v:Hide() end)
  v:Hide()
  vComp = v
  return v
end
local function iconoDe(o) -- 12-oct: cliente primero, o.ic = respaldo del mismo objeto
  return (WowF.iconoObjeto and WowF.iconoObjeto(o.id, o.ic)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
function WowF.diarioComparar(o, slot)
  if type(o) ~= "table" then return nil end
  local r = WowF.compararEnRanura and WowF.compararEnRanura(o, planActual, slot) or nil
  local v = ventanaComparar()
  local E = WowF.estilo
  v.titulo:SetText(L("Comparar con lo puesto", "Compare with what you wear"))
  local c1, c2 = v.col[1], v.col[2]
  c1.cab:SetText(L("Lo que llevas", "What you wear") .. ((r and r.ranura) and (" (" .. r.ranura .. ")") or ""))
  c2.cab:SetText(L("Esta pieza", "This item"))
  c1.link = (r and type(r.link) == "string") and r.link or nil
  if c1.link then
    c1.nombre:SetText(c1.link)
    local ok, t = false, nil
    if GetInventoryItemTexture then ok, t = pcall(GetInventoryItemTexture, "player", r.slot) end
    c1.icono:SetTexture((ok and t) or "Interface\\Icons\\INV_Misc_QuestionMark")
  else
    c1.nombre:SetText(GRIS .. ((r and r.link == false) and L("no se pudo leer", "could not be read") or L("nada", "nothing")) .. "|r")
    c1.icono:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
  end
  c2.link = enlace(o.id)
  c2.icono:SetTexture(iconoDe(o))
  local q = o.q or 2
  local cq = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] and ITEM_QUALITY_COLORS[q].hex) or (q >= 4 and "|cffa335ee" or q == 3 and "|cff0070dd" or q == 2 and "|cff1eff00" or "|cffffffff")
  c2.nombre:SetText(cq .. (o.n or "?") .. "|r")
  local s
  if not r then s = GRIS .. L("Esta pieza no va en una ranura que se pueda comparar.", "This item does not go in a slot that can be compared.") .. "|r"
  elseif r.sinPesos then s = GRIS .. L("Aún no hay pesos de tu rama para comparar.", "No weights for your spec to compare yet.") .. "|r"
  elseif r.vacia then s = VERDE .. L("No llevas nada en esa ranura: es una mejora segura.", "You wear nothing in that slot: a sure upgrade.") .. "|r"
  elseif r.vieja == false then s = GRIS .. L("No se pudo leer lo que llevas.", "Could not read what you wear.") .. "|r"
  elseif r.cuanto and r.cuanto > 0.005 then s = VERDE .. ((WowF.textoMejora and WowF.textoMejora(r.cuanto * 100)) or "+") .. L(" sobre lo tuyo", " over yours") .. "|r"
  elseif r.cuanto and r.cuanto < -0.005 then s = NARANJA .. math.floor(-r.cuanto * 100 + 0.5) .. L(" % peor que lo tuyo", " % worse than yours") .. "|r"
  elseif r.cuanto then s = GRIS .. L("Igual que lo tuyo.", "Same as yours.") .. "|r"
  else s = VERDE .. L("Lo tuyo no suma nada para tu rama: esta pieza es mejor.", "Yours adds nothing for your spec: this item is better.") .. "|r" end
  v.resultado:SetText(s)
  local slots = (r and r.slots) or {}
  for i, b in ipairs(v.huecos) do
    local sl = slots[i]
    if #slots > 1 and sl then
      if E then E.boton(b, (r.slot == sl) and "suave" or "cuero", 11) end
      b:SetText(NOMBRE_HUECO[sl] or tostring(sl))
      b:SetScript("OnClick", function() WowF.diarioComparar(o, sl) end)
      b:Show()
    else b:Hide() end
  end
  estado.comparar = { id = o.id, slot = r and r.slot, slots = slots, cuanto = r and r.cuanto, vacia = r and r.vacia or false,
    texto = s, huecos = (#slots > 1) and #slots or 0 }
  v:Show()
  return r
end

-- Estado de una mision leido de tu registro
local function enRegistro(id)
  if not id then return false end
  if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
    local ok, r = pcall(C_QuestLog.GetLogIndexForQuestID, id); r = ok and numero(r)
    return r ~= nil and r > 0
  end
  return WowF.misionEnDiario and WowF.misionEnDiario(id) and true or false
end
local function lista(id)
  local ok, r
  if C_QuestLog and type(C_QuestLog.IsComplete) == "function" then ok, r = pcall(C_QuestLog.IsComplete, id)
  elseif type(IsQuestComplete) == "function" then ok, r = pcall(IsQuestComplete, id) end
  return ok and r == true
end
local function estadoMision(q, nivel)
  if q.hecha then return "hecha", L("hecha", "done"), "tenue" end
  if enRegistro(q.id) then
    if lista(q.id) then return "entregar", L("lista para entregar", "ready to turn in"), "verde" end
    return "registro", L("en tu registro", "in your quest log"), "oro"
  end
  if nivel < (q.nivel or 0) then return "aunno", L("aún no te la da: pide nivel " .. q.nivel, "not yet: it needs level " .. q.nivel), "naranja" end
  if q.dentro then return "dentro", L("se recoge dentro", "picked up inside"), "brasa" end
  return "libre", L("cógela antes de entrar", "pick it up before you go in"), "brasa"
end
local function recompensas(id)
  local r = {}
  if not enRegistro(id) or type(GetNumQuestLogRewards) ~= "function" or type(GetQuestLogRewardInfo) ~= "function" then return r end
  local ok, n = pcall(GetNumQuestLogRewards, id)
  n = ok and numero(n) or 0
  for i = 1, math.min(n, 4) do
    local okI, nombre, tex, _, _, _, item = pcall(GetQuestLogRewardInfo, i, id)
    if okI and tex then table.insert(r, { tex = tex, n = nombre, id = numero(item) }) end
  end
  return r
end

-- ===================== Dibujo =====================
local COLOR_TXT = { oro = "|cffd8b468", verde = VERDE, tenue = "|cffa39a8c", naranja = NARANJA, brasa = "|cffff8a2a" }

-- 12-oct (Andy): la lista en DOS bloques con su cabecera. Arriba "PUEDES IR YA" = las abiertas a tu nivel (estado "ahora" de
-- WowF.mazmorrasParaTi, la recomendada primero). Debajo "MAS ADELANTE" = las que aun no se abren (nivel < m.d, el mismo criterio
-- que el aviso al subir de nivel: se abre al llegar a m.d), atenuadas y con "se abre al nivel N". Sin ninguna abierta, el primer
-- bloque dice cual es la primera y a que nivel (datos reales). Las que ya pasaste siguen al final con [+].
local function dibujarIzquierda(entradas, nivel, y0)
  local E = WowF.estilo
  tarjetas:soltar()
  local y = y0 or 0
  local ya, luego, pasadas = {}, {}, {}
  for _, e in ipairs(entradas) do
    if e.estado == "ahora" then table.insert(ya, e)
    elseif e.estado == "proxima" then table.insert(luego, e)
    else table.insert(pasadas, e) end
  end
  local function cabecera(s, color)
    local _, a = texto(4, y, IZQ - 8, s, "etiqueta", 10, color)
    y = y + a + 3
  end
  local function linea(s)
    local _, a = texto(4, y, IZQ - 8, s, "sub", 9)
    y = y + a + 6
  end
  local function tarjeta(e)
    local m = e.m
    local t = tarjetas:tomar()
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", izq, "TOPLEFT", 0, -y)
    local d = WowFDiario and WowFDiario[m.i]
    -- Miniatura: la del diario del cliente; las mazmorras nuevas de Forever (Hall of Thanes, Ruins of Lordaeron, Excavation Site,
    -- City of Dalaran) solo traen pantalla de carga (LoadScreen_Camelot_*): se recorta el centro; si tampoco, el fondo del banner
    if d and d.mini then ponerImagen(t.mini, d.mini, { 0, 0.68359375, 0, 0.7421875 })
    elseif d and d.carga then ponerImagen(t.mini, d.carga, { 0.1, 0.9, 0.2, 0.7 })
    else ponerImagen(t.mini, d and d.fondo, { 0.1, 0.6, 0.1, 0.5 }) end
    t.nombre:SetText(m.n)
    local etq, det
    local rango = L("niveles ", "levels ") .. m.d .. "-" .. m.h
    if e.reco and e.estado == "ahora" then
      etq = L("RECOMENDADA AHORA · " .. e.piezas .. " piezas para ti", "RECOMMENDED NOW · " .. e.piezas .. " pieces for you")
      det = rango .. " · " .. L("ideal ", "ideal ") .. ideal(m)
    elseif e.estado == "ahora" then
      etq = L("PARA TU NIVEL · " .. e.piezas .. " piezas", "FOR YOUR LEVEL · " .. e.piezas .. " pieces")
      det = rango
    elseif e.estado == "proxima" then
      etq = e.reco and L("LA PRÓXIMA · SE ABRE AL NIVEL " .. m.d, "NEXT UP · UNLOCKS AT LEVEL " .. m.d)
        or L("SE ABRE AL NIVEL " .. m.d, "UNLOCKS AT LEVEL " .. m.d)
      det = (m.z and m.z ~= "") and (m.z .. " · " .. rango) or rango
    else
      etq = L("YA PASASTE SU NIVEL", "YOU ARE PAST ITS LEVEL")
      det = rango
    end
    -- 12-oct: progreso de la Ruta de la mazmorra ("3/6", o la marca verde si esta todo hecho)
    if WowF.progresoMazmorra then
      local okP, pr = pcall(WowF.progresoMazmorra, m)
      if okP and type(pr) == "table" and (pr.total or 0) > 0 then
        local marca = (pr.hechos == pr.total) and (VERDE .. "|TInterface\\RaidFrame\\ReadyCheck-Ready:11|t " .. L("hecha", "done") .. "|r")
          or ("|cffd8b468" .. pr.hechos .. "/" .. pr.total .. "|r")
        det = marca .. " · " .. det
      end
    end
    t.etq:SetText(etq); t.det:SetText(det)
    if E then
      local c = (e.estado == "ahora" and e.reco) and { 0.2, 1, 0.4 } or ((e.estado == "ahora" or e.estado == "proxima") and E.color.brasa or E.color.tenue)
      t.etq:SetTextColor(c[1], c[2], c[3], 1)
    end
    if t.acento then if e.reco then t.acento:Show() else t.acento:Hide() end end
    if elegida == m.n then t.sel:Show() else t.sel:Hide() end
    -- atenuadas: las de mas adelante y las pasadas (la elegida un poco mas viva para poder leer su ficha)
    local alfa = 1
    if e.estado == "proxima" then alfa = (elegida == m.n) and 0.85 or 0.6
    elseif e.estado == "pasada" then alfa = 0.55 end
    t:SetAlpha(alfa)
    local nombre = m.n
    t.boton:SetScript("OnClick", function() elegida = nombre; redibujar() end)
    y = y + 58
  end

  -- 1) Puedes ir ya
  cabecera(L("PUEDES IR YA", "YOU CAN GO NOW"), { 0.2, 1, 0.4 })
  if #ya > 0 then
    for _, e in ipairs(ya) do tarjeta(e) end
  elseif luego[1] then
    local m = luego[1].m
    linea(L("Aún ninguna: la primera se abre al nivel " .. m.d .. " (" .. m.n .. ").", "None yet: the first one unlocks at level " .. m.d .. " (" .. m.n .. ")."))
  else
    linea(L("Ninguna para tu nivel ahora mismo.", "None for your level right now."))
  end

  -- 2) Mas adelante (4 a la vista; [+] = todas; si la elegida esta mas abajo, se abren todas)
  if #luego > 0 then
    y = y + 4
    cabecera(L("MÁS ADELANTE", "LATER ON"))
    linea(L("Aún no te toca; puedes revisarlas para ver qué te puede caer.", "Not your level yet; you can check them to see what they can drop."))
    for i, e in ipairs(luego) do if i > 4 and e.m.n == elegida and elegida ~= sinAbrirPor then verFuturas = true end end
    for i, e in ipairs(luego) do if i <= 4 or verFuturas then tarjeta(e) end end
    if #luego > 4 then
      local mas = #luego - 4
      boton(0, y + 2, IZQ, 20, verFuturas and ("[-] " .. L("Ver menos", "Show fewer"))
        or ("[+] " .. L("y " .. mas .. " más para niveles altos", "and " .. mas .. " more for higher levels")), "cuero",
        function() WowF.diarioAlternarFuturas() end)
      y = y + 26
    end
  end

  -- 3) Las que ya pasaste
  if #pasadas > 0 then
    y = y + 4
    boton(0, y + 2, IZQ, 20, (verPasadas and "[-] " or "[+] ") .. L("Ya pasaste su nivel: " .. #pasadas, "Past their level: " .. #pasadas), "cuero",
      function() verPasadas = not verPasadas; redibujar() end)
    y = y + 26
    if verPasadas then for _, e in ipairs(pasadas) do tarjeta(e) end end
  end
  estado.listaYa, estado.listaLuego, estado.listaPasadas = #ya, #luego, #pasadas
  return y
end

local function pintarBanner(e, nivel)
  local m = e.m
  local d = WowFDiario and WowFDiario[m.i]
  local hay = false
  if d and d.fondo then hay = ponerImagen(banner.img, d.fondo, { 0, 0.78125, 0.12, 0.38 })
  elseif d and d.carga then hay = ponerImagen(banner.img, d.carga, { 0, 1, 0.3, 0.55 }) end
  if not hay then
    if banner.img.SetColorTexture then
      local c = WowF.estilo and WowF.estilo.color.piedra2 or { 0.16, 0.15, 0.14 }
      banner.img:SetColorTexture(c[1], c[2], c[3], 1)
    end
    if d and d.mini then -- sin fondo ni pantalla de carga: la miniatura del cliente encima de la piedra; si tampoco, piedra lisa
      banner.icono:SetTexture(d.mini)
      if banner.icono.SetTexCoord then banner.icono:SetTexCoord(0, 0.68359375, 0, 0.7421875) end
      banner.icono:Show()
    else banner.icono:Hide() end
  else banner.icono:Hide() end
  banner.titulo:SetText(m.n)
  banner.sub:SetText((m.z or "") .. " · " .. L("niveles ", "levels ") .. m.d .. "-" .. m.h .. " · " .. L("ideal ", "ideal ") .. ideal(m)
    .. L(" (estimación de la guía)", " (guide estimate)"))
  -- 11-oct (djextra): chips de confianza (grises y pequenos) en vez de la etiqueta larga: lo que aun no esta confirmado en WoW Forever
  banner.etq:SetText("")
  local cx = XD + 12
  local function poner(s, color) local _, w = chip(cx, 12, s, color); cx = cx + w + 6 end
  if e.reco and e.estado == "ahora" then poner(L("recomendada ahora", "recommended now"), "brasa") end
  if m.bv == false then poner(L("botín sin confirmar", "loot not confirmed"), "gris") end
  if m.a or not m.m then poner(L("entrada sin confirmar", "entrance not confirmed"), "gris") end
end

-- 11-oct (djextra): franja de requisito bajo las pestanas. Roja "REQUISITO: nivel N" hasta que lo tienes; entonces verde "LISTO"
-- (el Libro se redibuja al subir de nivel). Solo el nivel: llave o mision previa no salen porque no hay ese dato de WoW Forever.
local function pintarRequisito(m, nivel, y)
  local E = WowF.estilo
  local listo = nivel >= (m.d or 0)
  local col = listo and { 0.12, 0.45, 0.2 } or { 0.55, 0.1, 0.08 }
  rect(franjas, XD + 14, y, DER - 28, 22, col, 0.55)
  rect(franjas, XD + 14, y, 3, 22, listo and { 0.2, 1, 0.4 } or { 1, 0.25, 0.2 }, 1)
  local s = listo and (VERDE .. L("LISTO: tienes el nivel " .. m.d .. " que pide", "READY: you have the required level " .. m.d) .. "|r")
    or ("|cffff5544" .. L("REQUISITO: nivel " .. m.d .. " (eres " .. nivel .. ")", "REQUIREMENT: level " .. m.d .. " (you are " .. nivel .. ")") .. "|r")
  texto(XD + 24, y + 5, DER - 48, s, "cuerpo", 11)
  estado.requisito = listo and "listo" or "rojo"
  return y + 30
end

-- 11-oct: "Ver en el mapa" del Resumen. Usa la ruta de siempre (WowF.irAMazmorra: alfiler en la entrada) y abre el mapa
-- en el mapa de la entrada (m.m). Sin entrada confirmada en WoW Forever = solo el aviso (nada inventado). En combate no abre el mapa.
function WowF.diarioVerEnMapa(m)
  if not m then return false end
  if not m.m then -- 11-oct: sin entrada de Forever no se traza ruta (antes daba error al no tener zona)
    print(NARANJA .. "Forever Guide: " .. L("la entrada de " .. (m.n or "?") .. " aún no tiene datos de WoW Forever; pendiente de actualizar.",
      "the entrance of " .. (m.n or "?") .. " has no WoW Forever data yet; pending update.") .. "|r")
    return false
  end
  if WowF.irAMazmorra then WowF.irAMazmorra(m) elseif WowF.marcar then WowF.marcar(m) end
  if m.a then
    print(NARANJA .. "Forever Guide: " .. L("entrada de " .. (m.n or "?") .. " aún sin confirmar en WoW Forever; búscala cerca del alfiler.",
      "entrance of " .. (m.n or "?") .. " not confirmed in WoW Forever yet; look near the map pin.") .. "|r")
  end
  if WorldMapFrame and not (InCombatLockdown and InCombatLockdown()) and not WowF.interfazMando() then -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
    if not (WorldMapFrame.IsShown and WorldMapFrame:IsShown()) then
      if ShowUIPanel then pcall(ShowUIPanel, WorldMapFrame) elseif ToggleWorldMap then pcall(ToggleWorldMap) end
    end
    if WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, m.m) end
  end
  return true
end

-- 11-oct (Andy: "pon los mapas para que el tanque sepa como hacerlo bien"): tarjeta "Ruta del tanque" en el Resumen.
-- El cliente de la beta NO trae mapas de mazmorras y no se usa nada de Classic: es un ESQUEMA con la posicion REAL de cada jefe
-- en WoW Forever (WowFRutaTanque, wowF_RutaTanque_Datos.lua, de Wowhead /forever), en el orden del diario: circulos numerados
-- unidos por rayas (capa propia con CreateLine; sin CreateLine, sin rayas), un recuadro por piso y la pantalla de carga de la
-- mazmorra muy oscurecida de fondo. Sin posiciones = aviso "aun no hay datos de WoW Forever". Todo en la tabla RT (tope de locales).
local RT = { lineas = {}, nl = 0 }
function RT.crear()
  if RT.capa then return end
  RT.capa = CreateFrame("Frame", nil, marco)
  RT.capa:SetAllPoints(marco)
  pcall(function() RT.capa:SetFrameLevel((tonumber(marco:GetFrameLevel()) or 0) + 5) end)
  RT.texs = pool(function() return RT.capa:CreateTexture(nil, "BACKGROUND", nil, 1) end)
  RT.puntos = pool(function()
    local b = CreateFrame("Button", nil, marco)
    pcall(function() b:SetFrameLevel((tonumber(marco:GetFrameLevel()) or 0) + 8) end)
    b.borde = b:CreateTexture(nil, "ARTWORK", nil, 1)
    b.borde:SetPoint("TOPLEFT", -2, 2); b.borde:SetPoint("BOTTOMRIGHT", 2, -2)
    b.relleno = b:CreateTexture(nil, "ARTWORK", nil, 2)
    b.relleno:SetAllPoints()
    pcall(function()
      for _, t in ipairs({ b.borde, b.relleno }) do
        local mk = b:CreateMaskTexture()
        mk:SetAllPoints(t)
        mk:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        t:AddMaskTexture(mk)
      end
    end)
    b.numero = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.numero:SetPoint("CENTER", 0, 0)
    if b.numero.SetTextColor then b.numero:SetTextColor(0.1, 0.06, 0.02) end
    b:SetScript("OnEnter", function(self)
      if not GameTooltip or not self.info then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.info.n or "?", 1, 0.82, 0.41, 1, true)
      GameTooltip:AddLine(L("Jefe " .. self.info.k .. " de " .. self.info.t .. " (orden del diario del juego)",
        "Boss " .. self.info.k .. " of " .. self.info.t .. " (in-game journal order)"), 0.94, 0.91, 0.85, true)
      if self.info.pisos > 1 then GameTooltip:AddLine(L("Piso ", "Floor ") .. self.info.piso, 0.64, 0.6, 0.55, true) end
      GameTooltip:AddLine(L("Posición según Wowhead /forever", "Position according to Wowhead /forever"), 0.64, 0.6, 0.55, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return b
  end)
end
function RT.soltar()
  if not RT.capa then return end
  RT.texs:soltar(); RT.puntos:soltar()
  for _, l in pairs(RT.lineas) do if l.Hide then l:Hide() end end
  RT.nl = 0
end
-- Textura de la capa propia con su capa de dibujo (se reutiliza: se limpia el recorte)
function RT.tex(x, y, ancho, alto, capaDib, sub)
  local t = RT.texs:tomar()
  if t.SetDrawLayer then pcall(t.SetDrawLayer, t, capaDib, sub) end
  if t.SetTexCoord then t:SetTexCoord(0, 1, 0, 1) end
  t:ClearAllPoints(); t:SetPoint("TOPLEFT", marco, "TOPLEFT", x, -y); t:SetSize(ancho, alto)
  return t
end
function RT.raya(x1, y1, x2, y2, grueso, r, g, b, a)
  if not RT.capa.CreateLine then return end
  RT.nl = RT.nl + 1
  local l = RT.lineas[RT.nl]
  if not l then
    local ok, nueva = pcall(RT.capa.CreateLine, RT.capa, nil, "ARTWORK")
    if not ok or not nueva then RT.nl = RT.nl - 1; return end
    l = nueva; RT.lineas[RT.nl] = l
  end
  pcall(function()
    l:SetThickness(grueso)
    l:SetColorTexture(r, g, b, a)
    l:SetStartPoint("TOPLEFT", marco, x1, -y1)
    l:SetEndPoint("TOPLEFT", marco, x2, -y2)
    l:Show()
  end)
end
-- Dibuja la tarjeta en y; devuelve la y de debajo
function RT.pintar(m, y)
  RT.crear()
  local E = WowF.estilo
  local datos = WowFRutaTanque and m and m.i and WowFRutaTanque[m.i]
  local jefes = (datos and datos.jefes) or {}
  local pisos = (datos and datos.pisos) or {}
  local con, sin = {}, {}
  for k, j in ipairs(jefes) do
    if j.x and j.y then table.insert(con, { n = j.n, x = j.x, y = j.y, piso = j.piso or 1, k = k }) else table.insert(sin, j.n) end
  end
  local x0, ancho = XD + 14, DER - 28
  rect(fondos, x0 - 6, y - 4, ancho + 12, 2, E and E.color.oro2 or { 0.55, 0.42, 0.18 }, 0.8)
  y = y + 6
  texto(x0, y, 160, L("Ruta del tanque", "Tank route"), "etiqueta", 9)
  y = y + 17
  estado.rutaTanque = { jefes = #con, total = #jefes, pisos = #pisos, aviso = #con == 0 }
  if #con == 0 then
    local _, a = texto(x0, y, ancho, cod("brasa") .. L("Aún no hay datos de WoW Forever; pendiente de actualizar.",
      "No WoW Forever data yet; pending update.") .. "|r", "cuerpo", 11)
    y = y + a + 4
  else
    local carga = WowFDiario and WowFDiario[m.i] and WowFDiario[m.i].carga
    local alto = (#pisos > 1) and 150 or 190
    for np = 1, math.max(#pisos, 1) do
      local delPiso = {}
      for _, j in ipairs(con) do if (j.piso or 1) == np then table.insert(delPiso, j) end end
      if #pisos > 1 then
        texto(x0, y, ancho, cod("oro") .. L("Piso ", "Floor ") .. np .. "|r", "cuerpo", 10)
        y = y + 15
      end
      -- recuadro oscuro + pantalla de carga muy oscurecida
      local fondo = RT.tex(x0, y, ancho, alto, "BACKGROUND", 1)
      if fondo.SetColorTexture then fondo:SetColorTexture(0.05, 0.045, 0.04, 0.96) end
      if carga then
        local img = RT.tex(x0 + 1, y + 1, ancho - 2, alto - 2, "BACKGROUND", 2)
        local ok = pcall(img.SetTexture, img, carga)
        if ok then
          if img.SetTexCoord then img:SetTexCoord(0, 1, 0.22, 0.78) end
          local velo = RT.tex(x0 + 1, y + 1, ancho - 2, alto - 2, "BORDER", 1)
          if velo.SetColorTexture then velo:SetColorTexture(0, 0, 0, 0.82) end
        else img:Hide() end
      end
      -- escala: caja de los jefes de este piso con margen, misma escala en los dos ejes
      local minx, maxx, miny, maxy = 100, 0, 100, 0
      for _, j in ipairs(delPiso) do minx = math.min(minx, j.x); maxx = math.max(maxx, j.x); miny = math.min(miny, j.y); maxy = math.max(maxy, j.y) end
      local margen = 22
      local dx, dy = math.max(maxx - minx, 0.5), math.max(maxy - miny, 0.5)
      local esc = math.min((ancho - 2 * margen) / dx, (alto - 2 * margen) / dy)
      local cx, cy = (minx + maxx) / 2, (miny + maxy) / 2
      local antes
      for _, j in ipairs(delPiso) do
        local px = x0 + ancho / 2 + (j.x - cx) * esc
        local py = y + alto / 2 + (j.y - cy) * esc
        if antes and antes.k == j.k - 1 then
          RT.raya(antes.px, antes.py, px, py, 4, 0, 0, 0, 0.75)
          RT.raya(antes.px, antes.py, px, py, 2, 0.85, 0.71, 0.41, 0.95)
        end
        local b = RT.puntos:tomar()
        b:ClearAllPoints(); b:SetSize(20, 20)
        b:SetPoint("CENTER", marco, "TOPLEFT", px, -py)
        if b.borde.SetColorTexture then b.borde:SetColorTexture(0, 0, 0, 1) end
        local c = (j.k == 1) and { 0.2, 1, 0.4 } or ((E and E.color.oro) or { 0.85, 0.71, 0.41 })
        if b.relleno.SetColorTexture then b.relleno:SetColorTexture(c[1], c[2], c[3], 1) end
        b.numero:SetText(j.k)
        b.info = { n = j.n, k = j.k, t = #jefes, piso = np, pisos = #pisos }
        antes = { px = px, py = py, k = j.k }
      end
      y = y + alto + 6
    end
    if #sin > 0 then
      local _, a = texto(x0, y, ancho, GRIS .. L("Sin posición en WoW Forever todavía: ", "No WoW Forever position yet: ") .. table.concat(sin, ", ") .. "|r", "sub", 9)
      y = y + a + 3
    end
    local _, a1 = texto(x0, y, ancho, cod("texto") .. L("Ve de 1 a " .. #jefes .. " (verde = el primero). Limpia lo que esté en el camino entre cada jefe para no llevar enemigos de más al combate.",
      "Go from 1 to " .. #jefes .. " (green = the first one). Clear what is on the way between bosses so you do not pull extra enemies into the fight.") .. "|r", "sub", 10)
    y = y + a1 + 2
    local _, a2 = texto(x0, y, ancho, cod("texto") .. L("Antes de cada grupo, espera a que tu sanador tenga maná. Pasa el ratón por un círculo para ver qué jefe es.",
      "Before each pull, wait for your healer to have mana. Hover a circle to see which boss it is.") .. "|r", "sub", 10)
    y = y + a2 + 2
  end
  local _, a3 = texto(x0, y, ancho, GRIS .. L("Esquema con las posiciones reales de WoW Forever (Wowhead /forever); el cliente de la beta no trae el mapa dibujado.",
    "Sketch with the real WoW Forever positions (Wowhead /forever); the beta client does not include the drawn map.") .. "|r", "sub", 9)
  return y + a3 + 10
end

local function pintarResumen(e, p, nivel, y0)
  local m = e.m
  local y = y0
  local s
  if e.estado == "ahora" then
    s = (e.piezas > 0) and (VERDE .. L(e.piezas .. " piezas de esta mazmorra mejoran lo que llevas.", e.piezas .. " pieces from this dungeon upgrade what you wear.") .. "|r")
      or (GRIS .. L("Ninguna pieza de aquí mejora lo que llevas ahora.", "No piece from here upgrades what you wear now.") .. "|r")
  elseif e.estado == "proxima" then s = cod("brasa") .. L("Se abre al nivel " .. m.d .. " (eres " .. nivel .. ").", "Opens at level " .. m.d .. " (you are " .. nivel .. ").") .. "|r"
  else s = GRIS .. L("Ya pasaste su nivel: da poca experiencia, por si quieres repetirla.", "You are past its level: little experience, in case you want to repeat it.") .. "|r" end
  local _, a = texto(XD + 14, y, DER - 28, s, "cuerpo", 12); y = y + a + 4
  if e.estado == "ahora" and WowF.porQuePocas then
    local ok, pocas = pcall(WowF.porQuePocas, p, m.i, e.lista)
    if ok and type(pocas) == "string" and pocas ~= "" then local _, a2 = texto(XD + 14, y, DER - 28, pocas, "sub", 10); y = y + a2 + 4 end
  end
  -- 12-oct: "Lo que vale saber" (nivel, lugar, misiones... segun la guia de Icy Veins /wow-forever; sin guia = aviso)
  do
    local d = WowF.mecanicasDe(m.i)
    local nv
    y, nv = pintarMecanicas(y + 6, L("Lo que vale saber", "Good to know"), d and d.datos)
    estado.valeSaber = { n = nv, aviso = nv == 0 }
  end
  -- Jefes con retrato, en 2 columnas
  y = y + 6
  texto(XD + 14, y, DER - 28, L("Jefes", "Bosses"), "etiqueta", 9); y = y + 16
  local jefes = jefesDe(m)
  local porJefe = botinDe(p, m, e.lista)
  local col = (DER - 28) / 2
  for i, j in ipairs(jefes) do
    local cx = XD + 14 + ((i - 1) % 2) * col
    local cy = y + math.floor((i - 1) / 2) * 42
    local tuyas, todas = 0, #(porJefe[j.n] or {})
    for _, b in ipairs(porJefe[j.n] or {}) do if b.tuya then tuyas = tuyas + 1 end end
    retrato(cx, cy, 34, { npc = j.npc, cara = j.cara, display = j.d, nombre = j.n, icono = ICONO_JEFE, resaltar = tuyas > 0 })
    local _, an = texto(cx + 42, cy + 2, col - 48, "|cffefe7da" .. i .. ". " .. j.n .. "|r", "cuerpo", 11)
    -- Debajo del nombre, que puede soltar para ti (botin de tu rama del plan; nada inventado)
    local linea
    if tuyas > 0 then linea = VERDE .. L("puede soltar " .. tuyas .. (tuyas == 1 and " pieza" or " piezas") .. " para ti", "can drop " .. tuyas .. (tuyas == 1 and " piece" or " pieces") .. " for you") .. "|r"
    elseif todas > 0 then linea = GRIS .. L(todas .. " de tu rama, ninguna mejora lo tuyo", todas .. " for your spec, none upgrades yours") .. "|r"
    elseif m.bv == false then linea = GRIS .. L("botín sin confirmar en Forever", "loot not confirmed in Forever") .. "|r"
    else linea = GRIS .. L("nada de tu rama en Forever", "nothing for your spec in Forever") .. "|r" end
    texto(cx + 42, cy + 3 + math.min(an, 26), col - 48, linea, "sub", 9)
    local b = botones:tomar() -- clic en el jefe: ir a su botin
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", marco, "TOPLEFT", cx, -cy); b:SetSize(col - 6, 36)
    b:SetText(""); if b.SetAlpha then b:SetAlpha(0) end
    local nombre, idx = m.n, i
    b:SetScript("OnClick", function() jefeSel[nombre] = idx; sub = "jefes"; redibujar() end)
  end
  if #jefes == 0 then local _, a3 = texto(XD + 14, y, DER - 28, L("Aún no hay jefes con datos de WoW Forever; se actualizará.", "No bosses with WoW Forever data yet; it will be updated."), "sub", 10); y = y + a3 end
  y = y + math.ceil(#jefes / 2) * 42 + 8
  -- 11-oct (djextra): ruta de jefes en el orden del diario del juego (DungeonEncounter de WoW Forever). Sin mapa interior: el cliente
  -- de la beta no trae mapas de las mazmorras y no se inventan. Si algun jefe sale solo del botin (sin diario), el orden no esta confirmado.
  if #jefes > 1 then
    local nombresRuta, sinDiario = {}, false
    for i, j in ipairs(jefes) do table.insert(nombresRuta, i .. ". " .. j.n); if j.sinDiario then sinDiario = true end end
    texto(XD + 14, y, 120, L("Ruta de jefes", "Boss route"), "etiqueta", 9)
    chip(XD + 128, y - 2, sinDiario and L("orden sin confirmar", "order not confirmed") or L("orden del diario del juego", "in-game journal order"), "gris")
    y = y + 17
    local _, ar = texto(XD + 14, y, DER - 28, "|cffefe7da" .. table.concat(nombresRuta, GRIS .. "  >  |r|cffefe7da") .. "|r", "cuerpo", 10)
    y = y + ar + 10
    estado.rutaJefes = { orden = nombresRuta, confirmado = not sinDiario }
  end
  y = RT.pintar(m, y)
  -- Ubicacion: zona y coordenadas de la entrada; sin entrada confirmada en Forever, chip gris SIN CONFIRMAR (sin parrafos)
  local yUb = y
  texto(XD + 14, y, 120, L("Ubicación", "Location"), "etiqueta", 9)
  if m.a or not m.m then chip(XD + 128, y - 2, L("sin confirmar", "not confirmed"), "gris") end
  y = y + 17
  local lugar = m.z or "?"
  if m.m and m.x and m.y then lugar = lugar .. GRIS .. "  ·  " .. string.format("%.1f, %.1f", m.x, m.y) .. "|r" end
  local _, a4 = texto(XD + 14, y, DER - 190, lugar, "cuerpo", 11)
  y = y + a4 + 8
  -- Como llegar: las primeras lineas de la ruta de wowF_Viaje (calculada, sin ponerla en marcha) + "Llevame" a la derecha
  boton(XD + DER - 164, yUb, 140, 26, L("Llévame", "Take me"), "brasa", function()
    if WowF.irAMazmorra then WowF.irAMazmorra(m) elseif WowF.marcar then WowF.marcar(m) end
  end)
  -- 11-oct (ideas de DFL): Ver en el mapa = la misma ruta + abrir el mapa del mundo en la zona de la entrada
  boton(XD + DER - 164, yUb + 30, 140, 22, L("Ver en el mapa", "Show on the map"), "cuero", function() WowF.diarioVerEnMapa(m) end)
  texto(XD + 14, y, DER - 28, L("Cómo llegar", "How to get there"), "etiqueta", 9); y = y + 15
  local pasos = WowF.pasosHacia and WowF.pasosHacia(m)
  estado.pasos = pasos and #pasos or 0
  if pasos and #pasos > 0 then
    for i = 1, math.min(#pasos, 4) do
      local ps = pasos[i]
      local _, ap = texto(XD + 14, y, DER - 28, cod("oro") .. i .. ".|r " .. (ps.texto or ps.corto or ""), "sub", 10)
      y = y + ap + 2
    end
    if #pasos > 4 then
      local _, am = texto(XD + 14, y, DER - 28, GRIS .. L("y " .. (#pasos - 4) .. " pasos más: pulsa Llévame", "and " .. (#pasos - 4) .. " more steps: press Take me") .. "|r", "sub", 9)
      y = y + am + 2
    end
  else
    local _, a5 = texto(XD + 14, y, DER - 28, GRIS .. L("Pulsa Llévame: ruta paso a paso desde donde estás y alfiler en la entrada.", "Press Take me: step-by-step route from where you are and a map pin at the entrance.") .. "|r", "sub", 10)
    y = y + a5
  end
  y = math.max(y, yUb + 56) + 10
  local misiones = WowF.misionesDe and WowF.misionesDe(m) or {}
  if #misiones > 0 then
    local _, a6 = texto(XD + 14, y, DER - 28, cod("oro") .. L(#misiones .. " misiones de mazmorra: abre la pestaña Misiones (casi todas se cogen FUERA, antes de entrar).",
      #misiones .. " dungeon quests: see the Quests tab (almost all are picked up OUTSIDE, before you go in).") .. "|r", "cuerpo", 11)
    y = y + a6 + 6
  end
  return y
end

local function pintarJefes(e, p, nivel, y0)
  local m = e.m
  local y = y0
  local jefes = jefesDe(m)
  local porJefe, sinJefe = botinDe(p, m, e.lista)
  -- paginas: un jefe por pagina (+ "otros" si hay botin sin jefe conocido)
  local paginas = {}
  for i, j in ipairs(jefes) do table.insert(paginas, { j = j, n = i, botin = porJefe[j.n] or {} }) end
  -- botin de un jefe que no esta en la lista (nombre distinto) tambien va a "otros"
  local conocido = {}
  for _, j in ipairs(jefes) do conocido[j.n] = true end
  local otros = {}
  for _, b in ipairs(sinJefe) do table.insert(otros, b) end
  for nombre, t in pairs(porJefe) do if not conocido[nombre] then for _, b in ipairs(t) do table.insert(otros, b) end end end
  if #otros > 0 then table.insert(paginas, { otros = true, botin = otros }) end
  if #paginas == 0 then
    local _, a = texto(XD + 14, y, DER - 28, L("Aún no hay jefes ni botín con datos de WoW Forever; se actualizará.", "No bosses or loot with WoW Forever data yet; it will be updated."), "sub", 10)
    return y + a + 8
  end
  local k = jefeSel[m.n]
  if not k then -- de entrada, el primer jefe que suelta algo tuyo
    k = 1
    for i, pg in ipairs(paginas) do local hay = false; for _, b in ipairs(pg.botin) do if b.tuya then hay = true end end; if hay then k = i; break end end
  end
  k = math.max(1, math.min(k, #paginas))
  estado.jefe = k
  local pg = paginas[k]
  local nombre = m.n
  boton(XD + 14, y + 14, 26, 26, "<", "cuero", function() jefeSel[nombre] = (k <= 1) and #paginas or (k - 1); redibujar() end)
  retrato(XD + 48, y, 56, pg.otros and { icono = ICONO_MAZMORRA } or { npc = pg.j.npc, cara = pg.j.cara, display = pg.j.d, nombre = pg.j.n, icono = ICONO_JEFE })
  texto(XD + 112, y + 6, DER - 170, pg.otros and L("Otros enemigos", "Other enemies") or (pg.n .. ". " .. pg.j.n), "titulo", 15)
  local tuyas = 0
  for _, b in ipairs(pg.botin) do if b.tuya then tuyas = tuyas + 1 end end
  texto(XD + 112, y + 30, DER - 170, (pg.otros and L("botín sin jefe confirmado en Forever", "loot without a confirmed boss in Forever")
    or L("jefe " .. pg.n .. " de " .. #jefes, "boss " .. pg.n .. " of " .. #jefes)) .. (tuyas > 0 and (" · " .. VERDE .. L(tuyas .. " para ti", tuyas .. " for you") .. "|r") or ""), "sub", 10)
  boton(XD + DER - 40, y + 14, 26, 26, ">", "cuero", function() jefeSel[nombre] = (k >= #paginas) and 1 or (k + 1); redibujar() end)
  y = y + 64
  -- 12-oct: mecanicas minimas del jefe (guia de Icy Veins /wow-forever); sin dato = aviso
  if not pg.otros then
    local nm
    y, nm = pintarMecanicas(y, L("Mecánicas", "Mechanics"), WowF.mecanicasJefe(m.i, pg.j))
    estado.mecanicas = { jefe = pg.j.n, n = nm, aviso = nm == 0 }
    rect(fondos, XD + 8, y - 4, DER - 16, 2, WowF.estilo and WowF.estilo.color.oro2 or { 0.55, 0.42, 0.18 }, 0.8)
    texto(XD + 14, y + 2, DER - 28, L("Botín", "Loot"), "etiqueta", 9)
    y = y + 20
  end
  if m.bv == false then
    local _, a = texto(XD + 14, y, DER - 28, L("Botín sin confirmar en Forever", "Loot not confirmed in Forever"), "etiqueta", 9, WowF.estilo and WowF.estilo.color.brasa); y = y + a + 4
  end
  if #pg.botin == 0 then
    local _, a = texto(XD + 14, y, DER - 28, L("Este jefe no suelta nada de tu rama a tu nivel (o aún no está confirmado en WoW Forever).", "This boss drops nothing for your spec at your level (or it is not confirmed in WoW Forever yet)."), "sub", 10)
    y = y + a + 6
  end
  for _, b in ipairs(pg.botin) do
    local o = b.o
    local f = filasObj:tomar()
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", marco, "TOPLEFT", XD + 14, -y)
    if f.SetWidth then f:SetWidth(DER - 24 - 80 - ANCHO_PROBAR) end -- sitio para Comparar y "Ver como queda" a la derecha
    local det
    if b.tuya then
      -- 11-oct (djextra): "+X % sobre lo tuyo" (la flecha de mejora, con la cifra de WowF.compararPieza)
      det = VERDE .. ((b.cuanto and b.cuanto > 0) and ((WowF.textoMejora and WowF.textoMejora(b.cuanto * 100) or string.format("+%d %%", math.floor(b.cuanto * 100 + 0.5))) .. L(" sobre lo tuyo", " over yours")) or L("mejora lo tuyo", "upgrades yours")) .. "|r"
        .. ((o.porqueCorto and o.porqueCorto ~= "") and (GRIS .. " · " .. o.porqueCorto .. "|r") or "")
      table.insert(estado.flechas, { id = o.id, cuanto = b.cuanto })
    else
      det = GRIS .. (o.r or "") .. " · " .. L("no mejora lo que llevas", "not an upgrade over what you wear") .. "|r"
    end
    local ya = GetItemCount and select(2, pcall(GetItemCount, o.id, true))
    if numero(ya) and numero(ya) > 0 then det = det .. "  " .. VERDE .. L("[ya la tienes]", "[you have it]") .. "|r" end
    local ic = (WowF.iconoObjeto and WowF.iconoObjeto(o.id, o.ic)) or "Interface\\Icons\\INV_Misc_QuestionMark"
    local q = o.q or 2
    local cq = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] and ITEM_QUALITY_COLORS[q].hex) or (q >= 4 and "|cffa335ee" or q == 3 and "|cff0070dd" or q == 2 and "|cff1eff00" or "|cffffffff")
    f:poner(ic, cq .. (o.n or "?") .. "|r", det)
    f.objeto, f.porque = o.id, b.tuya and o.porque or nil
    f:SetScript("OnEnter", function(self) tooltipObjeto(self, false) end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    f:SetScript("OnClick", clicObjeto)
    -- 11-oct (djextra): botones a la vista (antes solo con Ctrl-clic)
    boton(XD + DER - 14 - ANCHO_PROBAR - 80, y + 4, 76, 22, L("Comparar", "Compare"), "cuero", function() WowF.diarioComparar(o) end)
    botonProbar(XD + DER - 14 - ANCHO_PROBAR, y + 4, o.id)
    y = y + 34
  end
  local _, a = texto(XD + 14, y + 2, DER - 28, L("Clic: ver y comparar · Mayús-clic: enlazar en el chat", "Click: view and compare · Shift-click: link in chat"), "sub", 9)
  return y + a + 8
end

-- 11-oct (Andy: la pestana salia vacia, solo 4 pergaminos muy separados). Cada mision, en una fila compacta:
-- nombre (ingles) · desde nivel N · FUERA/DENTRO · parte k de T (linea) · estado; quien la da y donde; a quien se entrega;
-- clic = ruta (entrega si ya la llevas, la linea si faltan las de antes, la mazmorra si se coge dentro, el NPC si es de fuera)
local function parteDeLinea(q)
  local c = type(q.cadena) == "table" and q.cadena or nil
  if not c or #c == 0 then return nil end
  local k = #c + 1
  return k, k + #(type(c.tras) == "table" and c.tras or {})
end
local function rutaMision(q, clave, m)
  if (clave == "registro" or clave == "entregar") and WowF.irAEntrega then WowF.irAEntrega(q); return end
  if WowF.irALinea and WowF.lineaMisionCorta and (WowF.lineaMisionCorta(q) or "") ~= "" then
    local ok, hecho = pcall(WowF.irALinea, q, (not q.dentro and q.m and q.m > 0) and { quien = q.quien, m = q.m, x = q.x, y = q.y, q = { q } } or nil)
    if ok and hecho ~= false then return end
  end
  if q.dentro or not (q.m and q.m > 0) then
    if WowF.irAMazmorra then WowF.irAMazmorra(m) elseif WowF.marcar then WowF.marcar(m) end
  elseif WowF.irAMision then WowF.irAMision({ quien = q.quien, m = q.m, x = q.x, y = q.y, q = { q } }) end
end
local function pintarMisiones(e, p, nivel, y0)
  local m = e.m
  local y = y0
  local misiones = {}
  if WowF.misionesDe then misiones = WowF.misionesDe(m) or {} end
  if #misiones == 0 then
    local _, a = texto(XD + 14, y, DER - 28, NARANJA .. L("Misiones: aún no hay datos de WoW Forever; pendiente de actualizar.", "Quests: no WoW Forever data yet; pending update.") .. "|r", "sub", 10)
    return y + a + 8
  end
  local nFuera, nDentro = 0, 0
  for _, q in ipairs(misiones) do if q.dentro then nDentro = nDentro + 1 else nFuera = nFuera + 1 end end
  local _, a0 = texto(XD + 14, y, DER - 28, L(#misiones .. " misiones · " .. nFuera .. " fuera · " .. nDentro .. " dentro", #misiones .. " quests · " .. nFuera .. " outside · " .. nDentro .. " inside"), "etiqueta", 10)
  y = y + a0 + 6
  local fuera = 0
  if WowF.misionesFueraDe then for _, g in ipairs(WowF.misionesFueraDe(m)) do fuera = fuera + #g.q end end
  local yaMarcadas = WowF.misionesMarcadasDe and WowF.misionesMarcadasDe(m)
  if (fuera > 0 or yaMarcadas) and WowF.marcarTodasMisiones then
    boton(XD + 14, y, 260, 22, yaMarcadas and L("Quitar las marcas del mapa", "Clear the map marks") or L("Marcar en el mapa las " .. fuera .. " de fuera", "Mark the " .. fuera .. " outside ones on the map"), "cuero",
      function() WowF.marcarTodasMisiones(m); redibujar() end)
    y = y + 30
  end
  local E = WowF.estilo
  -- 11-oct (djextra): "Solo las que tengo" = solo las que estan en tu registro (para entregar o a medias)
  boton(XD + DER - 194, y0, 180, 22, (soloMias and "[X] " or "[  ] ") .. L("Solo las que tengo", "Only the ones I have"), soloMias and "suave" or "cuero",
    function() soloMias = not soloMias; redibujar() end)
  estado.soloMias = soloMias
  -- faccion de cada mision: q[4] de los datos crudos (0 = las dos, 1 = Horde, 2 = Alliance)
  local facDe = {}
  for _, cr in ipairs(m.q or {}) do if cr[5] then facDe[cr[5]] = cr[4] end end
  local C = E and E.color or {}
  local FAC = {
    [1] = { C.horda or { 0.62, 0.09, 0.09 }, "Horde" },
    [2] = { C.alianza or { 0.13, 0.25, 0.55 }, "Alliance" },
    [0] = { { 0.36, 0.3, 0.17 }, L("Las dos facciones", "Both factions") },
  }
  local CHIP_COLOR = { hecha = "verde", entregar = "verde", registro = "oro", aunno = "gris", dentro = "brasa", libre = "brasa" }
  estado.misiones = {}
  local x0, ancho = XD + 20, DER - 40 - 40 - 118 -- texto entre el retrato (32) y el boton (110)
  local vistas = 0
  for _, q in ipairs(misiones) do
    local clave, etq = estadoMision(q, nivel)
    if q.hecha then etq = L("completada", "completed") end
    estado.misiones[q.id or q.n] = clave
    if not soloMias or clave == "registro" or clave == "entregar" then
    vistas = vistas + 1
    -- Tarjeta: fondo de piedra + cabecera con el color de la faccion (texto de la faccion y chip del estado)
    local fondo = rect(fondos, XD + 10, y, DER - 20, 60, C.piedra2 or { 0.16, 0.15, 0.14 }, 0.95)
    local fac = FAC[facDe[q.id] or 0] or FAC[0]
    rect(franjas, XD + 10, y, DER - 20, 20, fac[1], 0.9)
    texto(XD + 18, y + 4, 140, fac[2], "etiqueta", 8, { 1, 0.95, 0.85 })
    chip(XD + 150, y + 2, etq, CHIP_COLOR[clave] or "gris")
    local yTop = y
    y = y + 26
    retrato(x0, y + 1, 32, { npc = q.npcId or q.npc, nombre = q.quien, icono = ICONO_MISION })
    local _, a1 = texto(x0 + 40, y, ancho, ((clave == "hecha") and GRIS or "|cffefe7da") .. (q.n or "?") .. "|r", "cuerpo", 12)
    local yy = y + a1 + 1
    -- pide nivel M · FUERA/DENTRO · parte k de T (el nivel de la mision en si no viene en los datos de WoW Forever)
    local datos = { (nivel < (q.nivel or 0) and NARANJA or GRIS) .. L("pide nivel ", "requires level ") .. (q.nivel or "?") .. "|r",
      q.dentro and (MORADO .. L("DENTRO", "INSIDE") .. "|r") or (cod("oro") .. L("FUERA", "OUTSIDE") .. "|r") }
    local k, T = parteDeLinea(q)
    if k and T > 1 then table.insert(datos, GRIS .. L("parte " .. k .. " de " .. T, "part " .. k .. " of " .. T) .. "|r") end
    local _, a2 = texto(x0 + 40, yy, ancho, table.concat(datos, GRIS .. " · |r"), "sub", 9); yy = yy + a2 + 3
    if clave ~= "hecha" then
      -- quien la da y donde
      local quien
      if q.dentro then
        quien = L("se recoge DENTRO de la mazmorra", "picked up INSIDE the dungeon") .. ((q.quien and q.quien ~= "") and (L(": la da ", ": given by ") .. cod("oro") .. q.quien .. "|r") or "")
      elseif WowF.dondeLaDaMision then local ok, s = pcall(WowF.dondeLaDaMision, q); quien = ok and type(s) == "string" and tx(s) or nil end
      if not quien then quien = (q.quien and q.quien ~= "") and (L("la da ", "given by ") .. q.quien) or (NARANJA .. L("quién la da: aún no hay datos de WoW Forever; pendiente de actualizar", "quest giver: no WoW Forever data yet; pending update") .. "|r") end
      local _, a3 = texto(x0 + 40, yy, ancho, quien, "sub", 9); yy = yy + a3 + 1
      if WowF.dondeSeEntrega then
        local ok, s = pcall(WowF.dondeSeEntrega, q)
        if ok and type(s) == "string" and s ~= "" then local _, a4 = texto(x0 + 40, yy, ancho, tx(s), "sub", 9); yy = yy + a4 + 1 end
      end
      -- linea pendiente: cuantas faltan antes
      local okC, corta = false, nil
      if WowF.lineaMisionCorta then okC, corta = pcall(WowF.lineaMisionCorta, q) end
      if okC and type(corta) == "string" and corta ~= "" then local _, a5 = texto(x0 + 40, yy, ancho, corta, "sub", 9); yy = yy + a5 + 1 end
      local xp = (WowF.textoXP and WowF.xpMision) and WowF.textoXP(WowF.xpMision(q)) or ""
      if xp ~= "" then local _, a6 = texto(x0 + 40, yy, ancho, VERDE .. xp .. "|r", "sub", 9); yy = yy + a6 + 1 end
      local enLog = clave == "registro" or clave == "entregar"
      boton(XD + DER - 130, y, 110, 22, enLog and L("Ir a entregar", "Go turn in") or L("Llévame", "Take me"), enLog and "brasa" or "cuero", function() rutaMision(q, clave, m) end)
      -- recompensas (iconos con tooltip) si ya la llevas: el juego no las ensena antes. Borde verde = mejora lo que llevas
      local premiosQ = {}
      for i, r in ipairs(recompensas(q.id)) do
        local b = premios:tomar()
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", marco, "TOPLEFT", XD + DER - 130 + (i - 1) * 28, -(y + 27))
        b.icono:SetTexture(r.tex)
        local link
        if GetQuestLogItemLink then local okL, l = pcall(GetQuestLogItemLink, "reward", i, q.id); if okL and type(l) == "string" then link = l end end
        if not link and r.id then link = enlace(r.id) end
        local mejora = false
        if link and WowF.evaluarMejora then
          local okE, ev = pcall(WowF.evaluarMejora, link, planActual)
          mejora = okE and type(ev) == "table" and ev.estado == "mejora"
        end
        local cb = mejora and { 0.2, 1, 0.4 } or (C.borde or { 0.23, 0.21, 0.18 })
        if b.borde.SetColorTexture then b.borde:SetColorTexture(cb[1], cb[2], cb[3], 1) end
        b.link, b.mejora = link, mejora
        b:SetScript("OnEnter", function(self)
          if not GameTooltip or not self.link then return end
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
          if self.mejora then GameTooltip:AddLine(L("Mejora lo que llevas", "Upgrades what you wear"), 0.2, 1, 0.4) end
          GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        table.insert(premiosQ, { id = r.id, mejora = mejora })
      end
      if #premiosQ > 0 then estado.premios = estado.premios or {}; estado.premios[q.id] = premiosQ; yy = math.max(yy, y + 56) end
    end
    y = math.max(yy, y + 38) + 8
    fondo:SetHeight(y - yTop)
    y = y + 8
    end
  end
  if soloMias and vistas == 0 then
    local _, a = texto(XD + 14, y, DER - 28, GRIS .. L("No tienes en tu registro ninguna misión de esta mazmorra. Quita el filtro para ver todas.", "You have no quest from this dungeon in your log. Clear the filter to see them all.") .. "|r", "sub", 10)
    y = y + a + 8
  end
  return y
end

-- ===================== 11-oct: buscador y "Botin de todas" (ideas de GearQuest/DFL) =====================
local ESTRELLA = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:16|t"
local ESTRELLA_GRIS = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:16:16:0:0:64:64:0:64:0:64:90:90:90|t"
local function personaje()
  local okN, n = pcall(UnitName, "player")
  local okR, r = pcall(GetRealmName)
  return ((okN and type(n) == "string") and n or "?") .. "-" .. ((okR and type(r) == "string") and r or "?")
end
-- Favoritas por personaje: WowFExportarDB.diarioFavoritos[Nombre-Reino][id] = true
local function favoritas()
  if type(WowFExportarDB) ~= "table" then return {} end
  WowFExportarDB.diarioFavoritos = WowFExportarDB.diarioFavoritos or {}
  local k = personaje()
  WowFExportarDB.diarioFavoritos[k] = WowFExportarDB.diarioFavoritos[k] or {}
  return WowFExportarDB.diarioFavoritos[k]
end
function WowF.diarioFavorito(id) return favoritas()[numero(id) or 0] == true end
function WowF.diarioPonerFavorito(id, si)
  id = numero(id)
  if not id then return false end
  if si == nil then si = not WowF.diarioFavorito(id) end
  favoritas()[id] = si and true or nil
  return si and true or false
end
local function iconoObjeto(o) -- 12-oct: cliente primero, o.ic = respaldo del mismo objeto
  return (WowF.iconoObjeto and WowF.iconoObjeto(o.id, o.ic)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function colorCalidad(q)
  q = q or 2
  return (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] and ITEM_QUALITY_COLORS[q].hex) or (q >= 4 and "|cffa335ee" or q == 3 and "|cff0070dd" or q == 2 and "|cff1eff00" or "|cffffffff")
end
-- derecha = sitio que ya ocupan otros botones a la derecha de la fila (la estrella de favorita: 34); "Ver como queda" va a su izquierda
local function filaObjeto(o, y, det, derecha)
  derecha = derecha or 0
  local f = filasObj:tomar()
  f:ClearAllPoints(); f:SetPoint("TOPLEFT", marco, "TOPLEFT", XD + 14, -y)
  if f.SetWidth then f:SetWidth(DER - 24 - derecha - ANCHO_PROBAR - 4) end -- el pool reutiliza filas de otro ancho
  botonProbar(XD + DER - 14 - derecha - ANCHO_PROBAR, y + 4, o.id)
  f:poner(iconoObjeto(o), colorCalidad(o.q) .. (o.n or "?") .. "|r", det)
  f.objeto, f.porque = o.id, nil
  f:SetScript("OnEnter", function(self) tooltipObjeto(self, false) end)
  f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  f:SetScript("OnClick", clicObjeto)
  return f
end

-- Busca en TUS mazmorras (tu faccion: WowF.mazmorrasParaTi) por nombre o zona de la mazmorra, jefes y el botin de tu rama
-- (p.botin, el mismo del plan). Devuelve { { tipo = "mazmorra"|"jefe"|"objeto", m, n, jefe = indice, o } } (max. 40).
-- Menos de 2 letras = nada. Los nombres del juego van en ingles.
function WowF.diarioBuscar(txt, p, nivel)
  local q = (type(txt) == "string" and txt:lower():match("^%s*(.-)%s*$")) or ""
  local res = {}
  if #q < 2 then return res end
  if p == nil and WowF.armarPlan then local ok, r = pcall(WowF.armarPlan); p = ok and r or nil end
  local function hay(s) return type(s) == "string" and s:lower():find(q, 1, true) ~= nil end
  for _, e in ipairs(WowF.mazmorrasParaTi(p, nivel)) do
    local m = e.m
    if hay(m.n) or hay(m.z) then table.insert(res, { tipo = "mazmorra", m = m, n = m.n }) end
    local jefes = jefesDe(m)
    for i, j in ipairs(jefes) do if hay(j.n) then table.insert(res, { tipo = "jefe", m = m, n = j.n, jefe = i }) end end
    for _, o in ipairs((p and p.botin and p.botin[m.i]) or {}) do
      if hay(o.n) then
        local idx
        for i, j in ipairs(jefes) do if o.jefe and j.n == o.jefe then idx = i end end
        table.insert(res, { tipo = "objeto", m = m, n = o.n, o = o, jefe = idx or (#jefes + 1) })
      end
    end
    if #res >= 40 then break end
  end
  while #res > 40 do table.remove(res) end
  return res
end
-- Clic en un resultado: abre la ficha de esa mazmorra (Jefes y botin en el jefe o la pieza) y vacia el buscador
function WowF.diarioIrResultado(r)
  if type(r) ~= "table" or not r.m then return end
  elegida = r.m.n
  if r.tipo == "mazmorra" then sub = "resumen" else sub = "jefes"; jefeSel[r.m.n] = r.jefe end
  buscar = ""
  if caja then caja:SetText(""); if caja.ClearFocus then caja:ClearFocus() end end
  redibujar()
end
-- Para las pruebas (y /wowf): escribir en el buscador
function WowF.diarioPonerBusqueda(s)
  buscar = type(s) == "string" and s or ""
  if caja then caja:SetText(buscar) end
  redibujar()
end

local function pintarBusqueda(p, nivel, y0)
  local y = y0
  local res = WowF.diarioBuscar(buscar, p, nivel)
  estado.busqueda = #res
  local _, a = texto(XD + 14, y, DER - 28, L("Resultados para \"", "Results for \"") .. buscar .. "\" · " .. #res, "titulo", 15); y = y + a + 4
  local _, a1 = texto(XD + 14, y, DER - 28, L("Solo tus mazmorras (tu facción) y el botín de tu rama. Los nombres del juego van en inglés.",
    "Only your dungeons (your faction) and the loot for your spec."), "sub", 10); y = y + a1 + 8
  if #res == 0 then
    local _, a2 = texto(XD + 14, y, DER - 28, L("Nada con ese nombre. Prueba con otra parte del nombre.", "Nothing with that name. Try another part of the name."), "cuerpo", 11)
    return y + a2 + 8
  end
  for _, r in ipairs(res) do
    local f
    if r.tipo == "objeto" then
      f = filaObjeto(r.o, y, GRIS .. L("Objeto", "Item") .. " · " .. r.m.n .. " · " .. tx(r.o.j or "") .. "|r")
    else
      f = filasObj:tomar()
      f:ClearAllPoints(); f:SetPoint("TOPLEFT", marco, "TOPLEFT", XD + 14, -y)
      if f.SetWidth then f:SetWidth(DER - 24) end -- el pool puede traer una fila de pieza (mas estrecha)
      if r.tipo == "jefe" then f:poner(ICONO_JEFE, "|cffefe7da" .. r.n .. "|r", GRIS .. L("Jefe", "Boss") .. " · " .. r.m.n .. "|r")
      else f:poner(ICONO_MAZMORRA, "|cffefe7da" .. r.n .. "|r", GRIS .. L("Mazmorra", "Dungeon") .. " · " .. (r.m.z or "") .. " · " .. L("niveles ", "levels ") .. r.m.d .. "-" .. r.m.h .. "|r") end
      f.objeto, f.porque = nil, nil
      f:SetScript("OnEnter", nil)
      f:SetScript("OnLeave", nil)
    end
    local rr = r
    f:SetScript("OnClick", function(self)
      if self.objeto and IsShiftKeyDown and IsShiftKeyDown() then clicObjeto(self); return end
      WowF.diarioIrResultado(rr)
    end)
    y = y + 34
  end
  return y + 6
end

-- "Botin de todas": el botin de tu rama (p.botin: tu clase y tu faccion, a tu nivel) de cada mazmorra, con estrella de favorita.
-- Por defecto las abiertas y las proximas; las que ya pasaste, con [+] de la izquierda. Botin sin confirmar = aviso.
local function pintarTodas(p, nivel, entradas, y0)
  local y = y0
  local fav = favoritas()
  local nFav = 0
  for _ in pairs(fav) do nFav = nFav + 1 end
  texto(XD + 14, y, DER - 28 - 160, L("Botín de todas las mazmorras", "Loot from every dungeon"), "titulo", 15)
  boton(XD + DER - 164, y, 140, 22, soloFav and L("Ver todo", "Show all") or L("Solo favoritas", "Favorites only"), soloFav and "suave" or "cuero",
    function() soloFav = not soloFav; redibujar() end)
  y = y + 28
  local _, a = texto(XD + 14, y, DER - 28, L("Solo tu facción y tu clase (botín de tu rama a tu nivel). Estrella = favorita. Clic en la pieza: ver y comparar. Favoritas: " .. nFav,
    "Only your faction and class (loot for your spec at your level). Star = favorite. Click the item: view and compare. Favorites: " .. nFav), "sub", 10)
  y = y + a + 8
  local total = 0
  for _, e in ipairs(entradas) do
    local m = e.m
    if e.estado ~= "pasada" or verPasadas or soloFav then
      local botin = {}
      for _, o in ipairs((p and p.botin and p.botin[m.i]) or {}) do if not soloFav or fav[o.id] then table.insert(botin, o) end end
      if #botin > 0 or (not soloFav and m.bv == false) then
        local _, ah = texto(XD + 14, y, DER - 28, m.n .. " · " .. L("niveles ", "levels ") .. m.d .. "-" .. m.h, "etiqueta", 9)
        y = y + ah + 4
        if m.bv == false then
          local _, a2 = texto(XD + 14, y, DER - 28, NARANJA .. L("Botín sin confirmar en WoW Forever; se actualizará.", "Loot not confirmed in WoW Forever; it will be updated.") .. "|r", "sub", 9)
          y = y + a2 + 4
        end
        local tuyas = {}
        for _, o in ipairs(e.lista or {}) do tuyas[o.id] = true end
        for _, o in ipairs(botin) do
          local det = GRIS .. tx(o.j or "") .. ((o.r and o.r ~= "") and (" · " .. o.r) or "") .. "|r"
          if tuyas[o.id] then det = det .. "  " .. VERDE .. L("mejora lo tuyo", "upgrades yours") .. "|r" end
          filaObjeto(o, y, det, 34)
          local id = o.id
          boton(XD + DER - 44, y + 4, 28, 24, fav[id] and ESTRELLA or ESTRELLA_GRIS, "cuero", function() WowF.diarioPonerFavorito(id); redibujar() end)
          y = y + 34
          total = total + 1
        end
        y = y + 6
      end
    end
  end
  estado.todas = total
  if total == 0 then
    local s = soloFav and L("Aún no tienes favoritas: pulsa la estrella de una pieza.", "No favorites yet: click the star on an item.")
      or (NARANJA .. L("Botín: aún no hay datos de WoW Forever para tu rama; pendiente de actualizar.", "Loot: no WoW Forever data for your spec yet; pending update.") .. "|r")
    local _, a3 = texto(XD + 14, y, DER - 28, s, "sub", 10)
    y = y + a3 + 8
  end
  return y
end

-- Contenido: lo llama CONTENIDO.Mazmorras del Libro. bloque(marco, alto) reserva el sitio en la hoja.
function WowF.contenidoDiario(p, bloque)
  if not WowF.libroHoja or not WowFMazmorras then return false end
  crearMarco()
  textos:soltar(); iconos:soltar(); botones:soltar(); retratos:soltar(); filasObj:soltar()
  chips:soltar(); fondos:soltar(); franjas:soltar(); premios:soltar(); chipTextos = {}
  RT.soltar()
  if WowF.diarioRutaSoltar then pcall(WowF.diarioRutaSoltar) end
  if WowF.diarioMapaSoltar then pcall(WowF.diarioMapaSoltar) end
  estado.flechas, estado.premios, estado.misiones, estado.pasos, estado.rutaJefes, estado.rutaTanque = {}, {}, {}, nil, nil, nil
  estado.mecanicas, estado.valeSaber = nil, nil
  planActual = p
  local nivel = nivelActual()
  local entradas = WowF.mazmorrasParaTi(p, nivel)
  if #entradas == 0 then return false end
  local e
  for _, x in ipairs(entradas) do if x.m.n == elegida then e = x end end
  if not e then e = entradas[1]; elegida = e.m.n end
  if e.estado == "pasada" then verPasadas = true end
  -- 11-oct: buscador (arriba) + boton "Botin de todas"; la lista de mazmorras empieza debajo
  if cajaAyuda then cajaAyuda:SetText(L("Buscar mazmorra, jefe u objeto", "Search dungeon, boss or item")) end
  if caja and (caja:GetText() or "") ~= buscar then caja:SetText(buscar) end
  local enTodas = sub == "todas"
  boton(0, 26, IZQ, 22, enTodas and L("« Volver a la mazmorra", "« Back to the dungeon") or L("Botín de todas", "Loot from all"), enTodas and "suave" or "cuero", function()
    if sub == "todas" then sub = subAntes or "resumen" else subAntes = sub; sub = "todas" end
    buscar = ""; if caja then caja:SetText("") end
    redibujar()
  end)
  local altoIzq = dibujarIzquierda(entradas, nivel, 54)
  local modo = (#(buscar:match("^%s*(.-)%s*$") or "") >= 2) and "buscar" or (enTodas and "todas" or nil)
  estado.modo = modo or "ficha"
  if modo then
    banner:Hide()
    for _, b in ipairs(pestanas) do b:Hide() end
    local y = (modo == "buscar") and pintarBusqueda(p, nivel, 14) or pintarTodas(p, nivel, entradas, 14)
    local alto = math.max(altoIzq, y + 6)
    ficha:SetHeight(y + 6); izq:SetHeight(math.max(altoIzq, 10)); marco:SetHeight(alto)
    estado.mazmorra, estado.sub, estado.reco = e.m.n, sub, e.reco
    bloque(marco, alto + 12)
    return true
  end
  banner:Show()
  for _, b in ipairs(pestanas) do b:Show() end
  pintarBanner(e, nivel)
  local nombres = { { "resumen", L("Resumen", "Overview") }, { "jefes", L("Jefes y botín", "Bosses and loot") }, { "misiones", L("Misiones", "Quests") }, { "ruta", L("Ruta", "Path") }, { "mapa", L("Mapa", "Map") } }
  for i, b in ipairs(pestanas) do
    local clave, s = nombres[i][1], nombres[i][2]
    if WowF.estilo then WowF.estilo.boton(b, clave == sub and "suave" or "cuero", 10) end
    b:SetText(clave == sub and ("· " .. s .. " ·") or s)
    b:SetScript("OnClick", function() sub = clave; redibujar() end)
  end
  local y0 = pintarRequisito(e.m, nivel, 150)
  local y
  if sub == "jefes" then y = pintarJefes(e, p, nivel, y0)
  elseif sub == "misiones" then y = pintarMisiones(e, p, nivel, y0)
  elseif sub == "ruta" and WowF.diarioPintarRuta then
    local okR, yr = pcall(WowF.diarioPintarRuta, marco, e.m, DER - 28, XD + 14, y0)
    if okR and type(yr) == "number" then y = yr
    else
      y = y0 + select(2, texto(XD + 14, y0, DER - 28, NARANJA .. L("No se pudo dibujar la ruta de esta mazmorra.", "Could not draw the path for this dungeon.") .. "|r", "cuerpo", 11)) + 8
      if not okR then estado.errorRuta = tostring(yr) end
    end
  elseif sub == "mapa" and WowF.diarioPintarMapa then
    local okM, ym = pcall(WowF.diarioPintarMapa, marco, e.m, DER - 28, XD + 14, y0)
    if okM and type(ym) == "number" then y = ym
    else
      y = y0 + select(2, texto(XD + 14, y0, DER - 28, NARANJA .. L("No se pudo dibujar el mapa de esta mazmorra.", "Could not draw the map for this dungeon.") .. "|r", "cuerpo", 11)) + 8
      if not okM then estado.errorMapa = tostring(ym) end
    end
  else sub = "resumen"; y = pintarResumen(e, p, nivel, y0) end
  local alto = math.max(altoIzq, y + 6)
  ficha:SetHeight(y + 6)
  izq:SetHeight(math.max(altoIzq, 10))
  marco:SetHeight(alto)
  estado.mazmorra, estado.sub, estado.reco = e.m.n, sub, e.reco
  bloque(marco, alto + 12)
  return true
end

function WowF.diarioOcultar() if marco then marco:Hide() end; if vComp then vComp:Hide() end end
-- para las pruebas: elegir mazmorra y sub-pestana, y leer lo que se ve
function WowF.diarioElegir(nombre, cual) if nombre then elegida = nombre end; if cual then sub = cual end; redibujar() end
-- 12-oct: clic en un jefe del Mapa = su botin (pestana Jefes y botin) en la mazmorra elegida
function WowF.diarioVerJefe(nombreJefe)
  local m = nil
  for _, mm in ipairs(WowFMazmorras or {}) do if mm.n == elegida then m = mm; break end end
  if not m then return false end
  for i, j in ipairs(jefesDe(m)) do
    if j.n == nombreJefe then jefeSel[elegida] = i; sub = "jefes"; redibujar(); return true end
  end
  return false
end
-- 12-oct: [+]/[-] de "Mas adelante"; al cerrar, la elegida (aunque quede oculta) ya no vuelve a abrir la lista
function WowF.diarioAlternarFuturas()
  verFuturas = not verFuturas
  sinAbrirPor = (not verFuturas) and elegida or nil
  redibujar()
  return verFuturas
end
function WowF.diarioEstado() return estado end
function WowF.diarioTexto()
  local t = {}
  if not marco or not textos then return "" end
  for i = 1, textos.n do local f = textos.lista[i]; if f and f.GetText then table.insert(t, f:GetText() or "") end end
  -- filas de botin (nombre + detalle con la flecha de mejora) y botones en uso (Comparar, Probador, Llevame, Ir a entregar...)
  for i = 1, (filasObj and filasObj.n or 0) do
    local f = filasObj.lista[i]
    local n, d = f and rawget(f, "nombre"), f and rawget(f, "detalle")
    if type(n) == "table" and n.GetText then table.insert(t, n:GetText() or "") end
    if type(d) == "table" and d.GetText then table.insert(t, d:GetText() or "") end
  end
  for i = 1, (botones and botones.n or 0) do
    local b = botones.lista[i]
    if b and b.GetText then local s = b:GetText(); if type(s) == "string" and s ~= "" then table.insert(t, s) end end
  end
  if banner then table.insert(t, 1, (banner.titulo:GetText() or "") .. "\n" .. (banner.etq:GetText() or "")) end
  if #chipTextos > 0 then table.insert(t, 2, table.concat(chipTextos, " ")) end
  if sub == "ruta" and WowF.diarioRutaTexto then local ok, s = pcall(WowF.diarioRutaTexto); if ok and type(s) == "string" then table.insert(t, s) end end
  if sub == "mapa" and WowF.diarioMapaTexto then local ok, s = pcall(WowF.diarioMapaTexto); if ok and type(s) == "string" then table.insert(t, s) end end
  return table.concat(t, "\n")
end

-- 11-oct (djextra): el mapa sin cerrar el Libro. Con el mapa a pantalla completa el Libro baja de capa (MEDIUM) para no taparlo;
-- con el mapa pequeno o cerrado vuelve a HIGH (delante). Sin UISpecialFrames nuevos; todo con pcall.
local function mapaGrande()
  local w = _G.WorldMapFrame
  if not w or not w.IsShown or not w:IsShown() then return false end
  if type(w.IsMaximized) == "function" then local ok, r = pcall(w.IsMaximized, w); if ok then return r and true or false end end
  return rawget(w, "isMaximized") and true or false
end
function WowF.diarioAjustarCapa()
  local libro = WowF.libro
  if not libro or not libro.SetFrameStrata then return nil end
  local strata = mapaGrande() and "MEDIUM" or "HIGH"
  pcall(libro.SetFrameStrata, libro, strata)
  WowF._diarioStrata = strata
  estado.strata = strata
  return strata
end
do
  local w = _G.WorldMapFrame
  if w then
    if w.HookScript then
      pcall(w.HookScript, w, "OnShow", function() WowF.diarioAjustarCapa() end)
      pcall(w.HookScript, w, "OnHide", function() WowF.diarioAjustarCapa() end)
    end
    if hooksecurefunc then
      if type(w.Maximize) == "function" then pcall(hooksecurefunc, w, "Maximize", function() WowF.diarioAjustarCapa() end) end
      if type(w.Minimize) == "function" then pcall(hooksecurefunc, w, "Minimize", function() WowF.diarioAjustarCapa() end) end
    end
  end
end

-- 11-oct (djextra): la mazmorra recomendada (el mismo criterio de siempre, WowF.mazmorrasParaTi) abierta en el diario.
-- Lo usan el clic derecho del boton del minimapa y el atajo de teclado.
function WowF.abrirDiarioRecomendado()
  local ok, entradas = pcall(WowF.mazmorrasParaTi)
  local m
  if ok and type(entradas) == "table" then
    for _, x in ipairs(entradas) do if x.reco then m = x.m; break end end
    if not m and entradas[1] then m = entradas[1].m end
  end
  if m then elegida = m.n end
  sub = "resumen"
  if WowF.abrirLibro then
    WowF.abrirLibro("Mazmorras")
    if WowF.libroSubpestana then pcall(WowF.libroSubpestana, "diario") end
  end
  return m
end

-- 12-oct: la ficha (Ruta y progreso de la lista) se rehace al coger, entregar o abandonar una mision y al subir de nivel,
-- SOLO con el Diario abierto. El juego tarda un instante en marcar la mision como hecha: se repinta otra vez al segundo.
do
  local ev = CreateFrame("Frame")
  for _, nombre in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP" }) do pcall(ev.RegisterEvent, ev, nombre) end
  local function abierto()
    local libro = WowF.libro
    return marco and marco.IsShown and marco:IsShown() and libro and libro.IsShown and libro:IsShown()
  end
  local function repintar() if abierto() then redibujar() end end
  ev:SetScript("OnEvent", function()
    if not abierto() then return end
    repintar()
    if C_Timer and C_Timer.After then pcall(C_Timer.After, 1, repintar) end
  end)
end

-- 11-oct (djextra): "Abrir en" de Ajustes (WowFExportarDB.abrirEn = "ultima" | "Mazmorras" | "Progreso"). Solo cuando el Libro
-- se abre sin pestana pedida (boton, /wowf plan, atajo); si alguien pide una pestana concreta, manda esa.
do
  local original = WowF.abrirLibro
  if original then
    WowF.abrirLibro = function(cual, ...)
      local libro = WowF.libro
      local cerrado = not (libro and libro.IsShown and libro:IsShown())
      local donde = WowFExportarDB and WowFExportarDB.abrirEn
      if cual == nil and cerrado and (donde == "Mazmorras" or donde == "Progreso") then
        original(donde, ...)
        if donde == "Mazmorras" and WowF.libroSubpestana then pcall(WowF.libroSubpestana, "diario") end
      else
        original(cual, ...)
      end
      WowF.diarioAjustarCapa()
    end
  end
end
