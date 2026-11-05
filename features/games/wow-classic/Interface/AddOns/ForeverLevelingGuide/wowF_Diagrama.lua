-- wowF Diagrama: el arbol de talentos dibujado como en la calculadora de Wowhead /forever, dentro de la pestana Talentos del Libro.
-- Cada casilla esta en su fila y columna reales, con su icono y los NIVELES en que la coges ("Nv 10-12"); debajo, la lista paso a paso.
-- Oro = ya puesto, verde = el siguiente, blanco = despues, naranja = sin guia verificada, gris = este plan no lo usa.
-- El orden sale de WowF.armarPlan() (orden / orden2), que sigue la guia de datos/guias-talentos.js (Icy Veins / Wowhead).
-- El punto n se pone al nivel 9 + n (12-oct: menos los puntos extra de Legacy "Talented", WowF.puntosTalento en wowF_Legacy.lua). Bilingue con L(es, en) (fuera de textos-addon.js, como Rotacion y Viaje).

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local ORO, VERDE, GRIS, BLANCO, NARANJA, CELESTE = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933", "|cff66ccff"
local ANCHO = 676             -- ANCHO_HOJA del Libro (11-oct: antes 512)
local X0, PASO_X, CAJA, PASO_Y = 30, 150, 34, 46
local E = WowF.estilo
local COLOR = { oro = ORO, verde = VERDE, blanco = BLANCO, naranja = NARANJA }

-- Valores del juego que pueden venir secretos en la beta: nunca se unen a texto sin pasar por aqui
local function numero(v)
  if v == nil then return nil end
  if issecretvalue then local ok, s = pcall(issecretvalue, v); if not ok or s then return nil end end
  return tonumber(v)
end
local function nivelActual() return numero(UnitLevel and UnitLevel("player")) or 1 end
local function sinGastar()
  if not UnitCharacterPoints then return 0 end
  local ok, a = pcall(UnitCharacterPoints, "player")
  return ok and numero(a) or 0
end
-- 12-oct (Legacy "Talented"): EXTRA = puntos de talento de mas que lee el cliente (0 si no se puede leer).
-- El punto idx de la guia llega cuando tienes idx puntos en total: al nivel 9 + idx - EXTRA.
local EXTRA = 0
local function nvP(idx) return math.max(1, 9 + idx - EXTRA) end
-- 16-oct (Andy: "si no hay información actualizada, que diga que los talentos están desactualizados"): la guía se escribió
-- antes de un parche que tocó los talentos de tu clase (g.desact, de arbol-wowhead.mjs + parches-talentos.json).
-- Devuelve titulo y cuerpo; los cambios que tocan un talento de tu guía van primero y marcados con ">>".
local function textoDesact(g)
  local d = g and g.desact
  if type(d) ~= "table" then return nil end
  local titulo = L("TALENTOS DESACTUALIZADOS", "OUTDATED TALENTS")
  local cuerpo = L("Tu guía es del " .. tostring(g.fecha or "?") .. ", antes del parche del " .. tostring(d.fecha) .. " (build " .. tostring(d.build) .. "), que cambió talentos de tu clase. "
      .. "Aún no hay guía de WoW Forever posterior al parche: el addon pondrá el orden nuevo solo cuando salga.",
    "Your guide is from " .. tostring(g.fecha or "?") .. ", before the " .. tostring(d.fecha) .. " patch (build " .. tostring(d.build) .. "), which changed your class talents. "
      .. "There is no WoW Forever guide after the patch yet: the addon will add the new order by itself when it comes out.")
  local lineas = {}
  for i, c in ipairs(d.cambios or {}) do
    if i > 5 then break end
    local t = L(c[1], c[2])
    table.insert(lineas, (c[3] and ">> " or "- ") .. t)
  end
  if (d.total or 0) > #lineas then table.insert(lineas, L("y " .. (d.total - #lineas) .. " cambios más", "and " .. (d.total - #lineas) .. " more changes")) end
  if (d.toca or 0) > 0 then
    table.insert(lineas, 1, L("Cambios que tocan tu guía (>>):", "Changes that touch your guide (>>):"))
  else
    table.insert(lineas, 1, L("Cambios del parche en tu clase:", "Patch changes for your class:"))
  end
  return titulo, cuerpo .. "\n" .. table.concat(lineas, "\n")
end
WowF.textoTalentosDesact = textoDesact
-- Puntos ya puestos (reales) y nota de Legacy para el jugador
local function leerPuntos(nivel)
  local r = WowF.puntosTalento and WowF.puntosTalento()
  EXTRA = (WowF.extraTalentos and r) and WowF.extraTalentos(r) or 0
  local nota = (WowF.notaLegacyTalentos and r) and WowF.notaLegacyTalentos(r) or nil
  if r and r.seguro and r.puestos then return r.puestos, nota end
  return math.max(0, math.min(nivel - 9, 51) - sinGastar()), nota
end

-- 12-oct (amigo Paladin: puso 3 puntos en Retribution y el diagrama marcaba Divine Strength 3/5 de Holy como puesto):
-- se lee el rango REAL de cada talento para saber DONDE pusiste los puntos, no solo cuantos.
-- Clave "Arbol|fila|col" (vale con el juego en cualquier idioma) y, de respaldo, el nombre. nil = el cliente no lo dice.
local function rangosReales(c)
  if not GetNumTalentTabs or not GetNumTalents or not GetTalentInfo or not c.pestanas then return nil end
  local okT, nt = pcall(GetNumTalentTabs); nt = okT and numero(nt) or nil
  if not nt or nt < 1 then return nil end
  local res, alguno = {}, false
  for t = 1, nt do
    local arbol = c.pestanas[t]
    local okN, n = pcall(GetNumTalents, t); n = okN and numero(n) or nil
    if not n then return nil end
    for i = 1, n do
      local ok, nombre, _, fila, col, rango = pcall(GetTalentInfo, t, i)
      if ok then
        local r = numero(rango)
        if r == nil then return nil end
        alguno = true
        fila, col = numero(fila), numero(col)
        if arbol and fila and col then res[arbol .. "|" .. fila .. "|" .. col] = r end
        local okS, sec = pcall(function() return issecretvalue and issecretvalue(nombre) end)
        if type(nombre) == "string" and okS and not sec then res["n:" .. nombre] = r end
      end
    end
  end
  return alguno and res or nil
end
local function rangoDe(real, c, nombre)
  local ta = c.talentos and c.talentos[nombre]
  local k = ta and ta[3] and ta[4] and ta[5] and (ta[3] .. "|" .. ta[4] .. "|" .. ta[5])
  return (k and real[k]) or real["n:" .. nombre] or 0
end
-- Cuantos pasos de la guia (en orden) tienes de verdad, y aviso si hay puntos que no siguen la guia.
-- Sin poder leer los rangos: como antes (la cuenta de puntos gastados).
function WowF.seguirPlanTalentos(c, orden, limite, gastados)
  local real = rangosReales(c)
  if not real then return math.min(gastados, limite), nil end
  local cuenta, puestos = {}, 0
  for idx = 1, limite do
    local n = orden[idx]
    cuenta[n] = (cuenta[n] or 0) + 1
    if rangoDe(real, c, n) >= cuenta[n] then puestos = idx else break end
  end
  local enTramo = {}
  for idx = 1, puestos do enTramo[orden[idx]] = (enTramo[orden[idx]] or 0) + 1 end
  local fuera, nFuera = {}, 0
  for nombre, ta in pairs(c.talentos or {}) do
    local r = rangoDe(real, c, nombre)
    local sobra = r - (enTramo[nombre] or 0)
    if sobra > 0 then
      nFuera = nFuera + sobra
      fuera[#fuera + 1] = nombre .. " " .. r .. "/" .. tostring(ta[1] or r) .. " (" .. tostring(ta[3]) .. ")"
    end
  end
  if nFuera == 0 then return puestos, nil end
  table.sort(fuera)
  local sigN = orden[puestos + 1]
  local sigTa = sigN and c.talentos and c.talentos[sigN]
  local cnt = 0
  for idx = 1, puestos + 1 do if orden[idx] == sigN then cnt = cnt + 1 end end
  local sigTxt = sigN and (sigN .. " " .. cnt .. "/" .. tostring(sigTa and sigTa[1] or cnt) .. " (" .. tostring(sigTa and sigTa[3]) .. ")") or nil
  local lista = table.concat(fuera, ", ")
  local aviso = L("Tienes " .. nFuera .. " punto(s) que no siguen el orden de la guía: " .. lista .. ".",
    "You have " .. nFuera .. " point(s) that don't follow the guide order: " .. lista .. ".")
  if sigTxt then
    aviso = aviso .. " " .. L("La guía sigue desde " .. sigTxt .. ". Para dejarlo igual que la guía, reinicia los talentos con el entrenador de tu clase; si no, sigue desde aquí.",
      "The guide continues from " .. sigTxt .. ". To match the guide, reset your talents at your class trainer; otherwise, keep going from here.")
  end
  return puestos, aviso
end

local marco, botonesPestana, botonesModo, casillas, rayas, etiquetas = nil, {}, {}, {}, {}, {}
local siguiente, guiaTexto, notaTexto, leyenda, enlaces, pasos
local tarjetaSig, etqSig, etqGuia, divGuia -- 11-oct, rediseño "hibrido"
local elegida = {}       -- pestana elegida a mano, por rama y modo
local modoElegido = {}   -- rama mixta: 1 = con la que subes, 2 = la final (por rama)
local estado = {}        -- para las pruebas

local function crearMarco()
  if marco then return end
  marco = CreateFrame("Frame", nil, WowF.libroHoja)
  marco:SetSize(ANCHO, 10)
  marco:Hide()
  for i = 1, 3 do
    local b = CreateFrame("Button", nil, marco, "UIPanelButtonTemplate")
    b:SetSize(216, 22)
    if b.SetNormalFontObject then b:SetNormalFontObject("GameFontNormalSmall"); b:SetHighlightFontObject("GameFontHighlightSmall") end
    WowF.estilo.boton(b, "cuero")
    botonesPestana[i] = b
  end
  for i = 1, 2 do
    local b = CreateFrame("Button", nil, marco, "UIPanelButtonTemplate")
    b:SetSize(330, 22)
    if b.SetNormalFontObject then b:SetNormalFontObject("GameFontNormalSmall"); b:SetHighlightFontObject("GameFontHighlightSmall") end
    WowF.estilo.boton(b, "cuero")
    botonesModo[i] = b
  end
  local function texto(fuente)
    local t = marco:CreateFontString(nil, "OVERLAY", fuente)
    t:SetJustifyH("LEFT"); t:SetWidth(ANCHO)
    if t.SetWordWrap then t:SetWordWrap(true) end
    return t
  end
  -- 11-oct, rediseño "hibrido": lo que toca AHORA va en una tarjeta de piedra con raya brasa y su etiqueta;
  -- la fuente del orden, con etiqueta brasa y texto Signika; leyenda y notas en gris
  tarjetaSig = E.tarjeta(marco, { acento = true })
  etqSig = E.etiqueta(tarjetaSig, nil, nil, 9)
  etqSig:SetPoint("TOPLEFT", 12, -10)
  siguiente = tarjetaSig:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") -- dentro de la tarjeta (un marco hijo taparia un texto del padre)
  if siguiente.SetWordWrap then siguiente:SetWordWrap(true) end
  E.cuerpo(tarjetaSig, siguiente, 13)
  siguiente:SetWidth(ANCHO - 24)
  etqGuia = E.etiqueta(marco, nil, nil, 9)
  divGuia = E.divisor(marco, nil, 0, 0, 0)
  guiaTexto = texto("GameFontHighlightSmall")
  E.cuerpo(marco, guiaTexto, 11)
  notaTexto = texto("GameFontHighlightSmall")
  E.sub(marco, notaTexto, 10)
  leyenda = texto("GameFontHighlightSmall")
  E.sub(marco, leyenda, 10)
  pasos = texto("GameFontHighlight")
  E.cuerpo(marco, pasos, 12)
  if pasos.SetSpacing then pasos:SetSpacing(3) end
  enlaces = {}
  for i = 1, 2 do
    local e = CreateFrame("EditBox", nil, marco, "InputBoxTemplate")
    e:SetSize(ANCHO - 10, 20)
    e:SetAutoFocus(false)
    if e.SetFontObject then e:SetFontObject("GameFontHighlightSmall") end
    -- Solo para copiar: cualquier cambio vuelve al enlace; Esc o Enter sueltan el foco
    e:SetScript("OnTextChanged", function(self) if self._url and self:GetText() ~= self._url then self:SetText(self._url) end end)
    e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    enlaces[i] = e
  end
end

local function casilla(i)
  if casillas[i] then return casillas[i] end
  local b = CreateFrame("Button", nil, marco)
  b:SetSize(CAJA, CAJA)
  local borde = b:CreateTexture(nil, "BACKGROUND")
  borde:SetPoint("TOPLEFT", -3, 3); borde:SetPoint("BOTTOMRIGHT", 3, -3)
  b.borde = borde
  local ic = b:CreateTexture(nil, "ARTWORK")
  ic:SetAllPoints()
  b.icono = ic
  local rango = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  rango:SetPoint("BOTTOMRIGHT", 3, -3)
  b.rango = rango
  local num = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  if E and E.letra then E.letra(num, "boton", 11) end
  num:SetPoint("LEFT", b, "RIGHT", 6, 0)
  num:SetWidth(PASO_X - CAJA - 8)
  num:SetJustifyH("LEFT")
  if num.SetWordWrap then num:SetWordWrap(true) end
  b.num = num
  b:SetScript("OnEnter", function(self)
    if not GameTooltip or not self.nombre then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local base = self.ayuda and WowF.T(self.ayuda) or (ORO .. self.nombre .. "|r")
    GameTooltip:SetText(base .. "\n\n" .. (self.extra or ""), 1, 1, 1, 1, true)
    if GameTooltip.SetMinimumWidth then GameTooltip:SetMinimumWidth(260) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  casillas[i] = b
  return b
end

local function raya(i)
  if rayas[i] then return rayas[i] end
  local t = marco:CreateTexture(nil, "BORDER")
  rayas[i] = t
  return t
end

-- 4-oct (Andy no entendia "1-3"): junto al icono van los NIVELES en que pones el punto. Puntos 1, 2, 3, 7 -> "Nv 10-12, 16"
local function comprimir(lista, colorDe)
  local partes, i = {}, 1
  while i <= #lista do
    local j = i
    while j < #lista and lista[j + 1] == lista[j] + 1 and colorDe(lista[j + 1]) == colorDe(lista[i]) do j = j + 1 end
    table.insert(partes, COLOR[colorDe(lista[i])] .. (j > i and (nvP(lista[i]) .. "-" .. nvP(lista[j])) or tostring(nvP(lista[i]))) .. "|r")
    i = j + 1
  end
  return GRIS .. L("Nv ", "Lv ") .. "|r" .. table.concat(partes, GRIS .. ", |r")
end

local function textoGuia(g, desdeNivel)
  if not g then return nil end
  if g.reparto then
    return L("Reparto según ", "Build from ") .. g.fuente .. L(" (nivel ", " (level ") .. g.hasta .. ")"
  end
  if g.comp and g.comp ~= "" and (g.compDesde or 0) > 0 then
    return L("Orden según ", "Order from ") .. g.fuente .. L(" (niveles ", " (levels ") .. desdeNivel .. "-" .. (g.compDesde - 1) .. ")" ..
      L(" y ", " and ") .. g.comp .. " (" .. g.compDesde .. "-" .. g.verificada .. ")"
  end
  return L("Orden según ", "Order from ") .. g.fuente .. L(" (niveles ", " (levels ") .. desdeNivel .. "-" .. g.verificada .. ")"
end

-- Contenido: lo llama CONTENIDO.Talentos del Libro. bloque(marco, alto) reserva el sitio en la hoja.
function WowF.contenidoDiagrama(p, cab, nota, bloque)
  -- 30-oct: rama sin guía válida tras un parche: no hay orden; se dice a la vista (regla CERO CLASSIC)
  if p.guia and p.guia.sinDatos then
    estado = {}
    if marco then marco:Hide() end
    nota(L("Orden de talentos: aún no hay datos de WoW Forever; pendiente de actualizar.", "Talent order: no WoW Forever data yet; pending update."))
    local tt, cc = textoDesact(p.guia)
    if tt then nota(tt .. "\n" .. cc) end
    return
  end
  local c = WowFDatos and WowFDatos.clases and WowFDatos.clases[p.clase or ""]
  if not c or not c.pestanas or not p.orden or #p.orden == 0 or not WowF.libroHoja then return end
  crearMarco()
  local nivel = nivelActual()
  local tope = (WowFDatos and WowFDatos.topeBeta) or 30
  local cambio = p.ramaCambio or 0
  -- 4-nov: orden2 = {} (rama final sin guía) no es mixta: en Lua {} no es nil y el modo 2 salía en blanco
  local mixta = cambio > 0 and p.orden2 ~= nil and #p.orden2 > 0
  local clave = tostring(p.clase) .. "|" .. tostring(p.rama)
  local modoNivel = (mixta and nivel >= cambio) and 2 or 1
  local modo = mixta and (modoElegido[clave] or modoNivel) or 1
  local orden = (modo == 2) and p.orden2 or p.orden
  local g = (modo == 2) and p.guia2 or p.guia

  -- Puntos ya puestos (reales: suma de los arboles; si no se pueden leer, (nivel - 9) menos los sin gastar)
  local gastados, notaLegacy = leerPuntos(nivel)
  -- Hasta que punto se ensena: el tope de la beta o tu nivel (y en la rama con que subes, hasta el reajuste); + puntos de Legacy
  local limite = math.max(tope, nivel) - 9 + EXTRA
  if cambio > 0 and modo == 1 then limite = math.min(limite, cambio - 10 + EXTRA) end
  if cambio > 0 and not mixta then nota(L("Desde el nivel " .. cambio .. " (rama final): aún no hay datos de WoW Forever; pendiente de actualizar.", "From level " .. cambio .. " (final spec): no WoW Forever data yet; pending update.")) end
  if mixta and modo == 2 then limite = math.max(limite, cambio - 9 + EXTRA) end
  limite = math.max(0, math.min(limite, #orden))

  local puestos, sig, avisoOrden
  if mixta and modo == 1 and nivel >= cambio then puestos, sig = limite, nil
  elseif mixta and modo == 2 and nivel < cambio then puestos, sig = 0, nil
  else puestos, avisoOrden = WowF.seguirPlanTalentos(c, orden, limite, gastados); sig = (puestos + 1 <= limite) and (puestos + 1) or nil end

  local function verificado(idx)
    if not g then return false end
    local nv = 9 + idx
    if g.reparto then return nv <= (g.hasta or 0) end
    return nv <= (g.verificada or 0)
  end
  local function colorDe(idx)
    if idx <= puestos then return "oro" end
    if idx == sig then return "verde" end
    if not verificado(idx) then return "naranja" end
    return "blanco"
  end

  -- Puntos de cada talento y de cada rama del arbol
  local puntosDe, porPestana = {}, {}
  for idx = 1, limite do
    local n = orden[idx]
    puntosDe[n] = puntosDe[n] or {}
    table.insert(puntosDe[n], idx)
    local ta = c.talentos[n]
    if ta then porPestana[ta[3]] = (porPestana[ta[3]] or 0) + 1 end
  end
  local claveP = clave .. "|" .. modo
  local pest = elegida[claveP]
  if not pest then
    local n = sig and orden[sig] or orden[math.max(1, limite)]
    pest = n and c.talentos[n] and c.talentos[n][3]
    local mas = -1
    if not pest then for _, nombre in ipairs(c.pestanas) do if (porPestana[nombre] or 0) > mas then mas = porPestana[nombre] or 0; pest = nombre end end end
  end

  -- ===== Encabezado =====
  cab(ORO .. L("Tu árbol de talentos: ", "Your talent tree: ") .. p.rama .. "|r" .. GRIS .. L("  ·  como en la calculadora de Wowhead", "  ·  like the Wowhead talent calculator") .. "|r")
  nota(BLANCO .. L("Desde el nivel 10 ganas 1 punto de talento cada vez que subes. Sigue la lista PASO A PASO de arriba hacia abajo: cada vez que subes de nivel, pon el punto de la fila siguiente. Lo VERDE es lo que te toca ahora. El árbol de abajo te enseña dónde está cada talento.",
    "From level 10 you get 1 talent point each level. Follow the STEP BY STEP list from top to bottom: each time you level up, spend the point on the next row. GREEN is what to do now. The tree below shows where each talent is.") .. "|r")

  -- ===== Marco del diagrama =====
  local y = 0
  -- ===== Lo que te toca AHORA (arriba, en grande: lo primero que se lee) =====
  local textoSig
  local modoAhora = mixta and modoNivel or 1
  local ordenAhora = (modoAhora == 2) and p.orden2 or p.orden
  local idxAhora = (ordenAhora == orden and avisoOrden) and (puestos + 1) or (gastados + 1)
  if nivel < 10 - EXTRA then idxAhora = 1 end
  if mixta and modoAhora == 1 and idxAhora > cambio - 10 + EXTRA then
    textoSig = NARANJA .. L("AHORA: al nivel " .. cambio .. " ve al entrenador, reajusta talentos y reparte como en «2. Al nivel " .. cambio .. "».",
      "NOW: at level " .. cambio .. " visit your trainer, reset talents and spend them as in \"2. At level " .. cambio .. "\".") .. "|r"
  elseif ordenAhora[idxAhora] then
    local n = ordenAhora[idxAhora]
    local ta = c.talentos[n] or {}
    local rk = 0
    for i2 = 1, idxAhora do if ordenAhora[i2] == n then rk = rk + 1 end end
    local nv = nvP(idxAhora)
    textoSig = VERDE .. L("AHORA (nivel ", "NOW (level ") .. nv .. L("): pon 1 punto en ", "): put 1 point in ") .. n .. L(" (rango ", " (rank ") .. rk .. "/" .. (ta[1] or 1) .. ")|r" ..
      GRIS .. "  ·  " .. tostring(ta[3] or "") .. (nv <= nivel and (VERDE .. L("  ·  ya puedes ponerlo", "  ·  you can spend it now") .. "|r") or "") .. "|r"
    -- 5-oct (Andy): el porque de ese punto, como lo dice la guia
    local r = c.ramas and c.ramas[p.indiceRama or 0]
    local tabla = r and ((modoAhora == 2) and r.porque2 or r.porque)
    local por = tabla and tabla[n]
    if por then textoSig = textoSig .. "\n" .. GRIS .. L("Por qué (según " .. por[3] .. "): ", "Why (per " .. por[3] .. "): ") .. "|r" .. BLANCO .. L(por[1], por[2]) .. "|r" end
  else
    textoSig = VERDE .. L("Ya tienes todos los talentos del plan.", "You have every talent in the plan.") .. "|r"
  end
  if textoSig:sub(1, #VERDE) == VERDE then textoSig = E.cod.texto .. textoSig:sub(#VERDE + 1) end
  textoSig = textoSig:gsub(BLANCO, E.cod.texto):gsub(GRIS, E.cod.tenue)
  etqSig:SetText(E.mayus(L("Tu punto de talento ahora", "Your talent point now")))
  tarjetaSig:ClearAllPoints(); tarjetaSig:SetPoint("TOPLEFT", marco, "TOPLEFT", 0, -y); tarjetaSig:SetWidth(ANCHO)
  siguiente:ClearAllPoints(); siguiente:SetPoint("TOPLEFT", tarjetaSig, "TOPLEFT", 12, -26)
  siguiente:SetText(textoSig)
  local altoSig = (siguiente:GetStringHeight() or 13) + 38
  tarjetaSig:SetHeight(altoSig); tarjetaSig:Show()
  y = y + altoSig + 10
  estado.textoSiguiente = textoSig
  for i = 1, 2 do botonesModo[i]:Hide() end
  if mixta then
    local textos = {
      L("1. Subes con " .. tostring(p.ramaSubir) .. " (hasta el " .. (cambio - 1) .. ")", "1. Level as " .. tostring(p.ramaSubir) .. " (to " .. (cambio - 1) .. ")"),
      L("2. Al nivel " .. cambio .. ": " .. tostring(p.ramaNombre), "2. At level " .. cambio .. ": " .. tostring(p.ramaNombre)),
    }
    for i = 1, 2 do
      local b = botonesModo[i]
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", marco, "TOPLEFT", (i - 1) * 338, -y)
      b:SetText(textos[i])
      E.boton(b, i == modo and "brasa" or "cuero")
      if b.LockHighlight then if i == modo then b:LockHighlight() else b:UnlockHighlight() end end
      b:SetScript("OnClick", function() modoElegido[clave] = i; if WowF.libroRedibujar then WowF.libroRedibujar() end end)
      b:Show()
    end
    y = y + 28
  end
  -- ===== Paso a paso: nivel por nivel, en orden (de todas las ramas del arbol) =====
  local filas, idx = { E.cod.brasa .. E.mayus(L("Paso a paso (un punto por nivel):", "Step by step (one point per level):")) .. "|r" }, 1
  while idx <= limite do
    local n, j = orden[idx], idx
    while j < limite and orden[j + 1] == n and colorDe(j + 1) == colorDe(idx) do j = j + 1 end
    local ta = c.talentos[n] or {}
    local rkA, rkB = 0, 0
    for i2 = 1, j do if orden[i2] == n then rkB = rkB + 1; if i2 <= idx then rkA = rkB end end end
    local col = COLOR[colorDe(idx)]
    local niveles = (j > idx) and (L("Niveles ", "Levels ") .. nvP(idx) .. "-" .. nvP(j)) or (L("Nivel ", "Level ") .. nvP(idx))
    local rk = (j > idx) and (rkA .. "-" .. rkB) or tostring(rkA)
    local icono = (ta[6] and ta[6] ~= "") and ("|TInterface\\Icons\\" .. ta[6] .. ":16:16|t ") or ""
    local f = col .. niveles .. ":  |r" .. icono .. col .. n .. "  (" .. L("rango ", "rank ") .. rk .. "/" .. (ta[1] or 1) .. ")|r" .. GRIS .. "  " .. tostring(ta[3] or "") .. "|r"
    if colorDe(idx) == "verde" then f = f .. VERDE .. L("   << TE TOCA AHORA", "   << DO THIS NOW") .. "|r"
    elseif colorDe(idx) == "oro" then f = f .. GRIS .. L("   (ya puesto)", "   (done)") .. "|r" end
    -- 4-oct (Andy): si el punto VUELVE a un talento que ya empezaste antes (no el de la fila anterior), se avisa debajo con su icono
    if idx > 1 and orden[idx - 1] ~= n then
      local antes = {}
      for i2 = 1, idx - 1 do if orden[i2] == n then table.insert(antes, nvP(i2)) end end
      if #antes > 0 then
        local partes, a = {}, 1
        while a <= #antes do
          local b = a
          while b < #antes and antes[b + 1] == antes[b] + 1 do b = b + 1 end
          table.insert(partes, (b > a) and (antes[a] .. "-" .. antes[b]) or tostring(antes[a]))
          a = b + 1
        end
        f = f .. "\n      " .. CELESTE .. L("^ VUELVES ATRÁS a ", "^ GO BACK to ") .. "|r" .. icono .. CELESTE .. n ..
          L(": el mismo talento al que ya le pusiste puntos en el nivel ", ": the same talent you already put points in at level ") .. table.concat(partes, ", ") .. "|r"
      end
    end
    table.insert(filas, f)
    idx = j + 1
  end
  pasos:ClearAllPoints(); pasos:SetPoint("TOPLEFT", marco, "TOPLEFT", 0, -y)
  pasos:SetText(table.concat(filas, "\n") .. "\n\n" .. E.cod.brasa .. E.mayus(L("Dónde está cada talento (elige la rama con los botones):", "Where each talent is (pick the tree with the buttons):")) .. "|r")
  y = y + (pasos:GetStringHeight() or (#filas * 13)) + 10
  local filasPasos = filas

  for i = 1, 3 do
    local b, nombre = botonesPestana[i], c.pestanas[i]
    if nombre then
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", marco, "TOPLEFT", (i - 1) * 230, -y)
      local n = porPestana[nombre] or 0
      b:SetText(nombre .. "  (" .. n .. ")")
      E.boton(b, nombre == pest and "brasa" or "cuero")
      if b.LockHighlight then if nombre == pest then b:LockHighlight() else b:UnlockHighlight() end end
      b:SetScript("OnClick", function() elegida[claveP] = nombre; if WowF.libroRedibujar then WowF.libroRedibujar() end end)
      b:Show()
    else b:Hide() end
  end
  y = y + 30

  -- ===== Rejilla: fila y columna reales =====
  local arriba = y
  local filasMax, pos, k = 1, {}, 0
  estado = { pestana = pest, modo = modo, mixta = mixta, limite = limite, puestos = puestos, siguiente = sig, orden = orden, casillas = {} }
  estado.textoSiguiente = textoSig
  estado.pasos = filasPasos
  for nombre, ta in pairs(c.talentos) do
    if ta[3] == pest and (ta[4] or 0) > 0 and (ta[5] or 0) > 0 then
      k = k + 1
      local b = casilla(k)
      local fila, col = ta[4], ta[5]
      if fila > filasMax then filasMax = fila end
      local bx, by = X0 + (col - 1) * PASO_X, arriba + (fila - 1) * PASO_Y
      pos[nombre] = { bx, by }
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", marco, "TOPLEFT", bx, -by)
      b.icono:SetTexture((ta[6] and ta[6] ~= "") and ("Interface\\Icons\\" .. ta[6]) or (WowF.iconoHechizo and WowF.iconoHechizo(nombre)) or "Interface\\Icons\\INV_Misc_QuestionMark")
      local lista = puntosDe[nombre] or {}
      local n, rangos = #lista, ta[1] or 1
      local tieneSig = false
      for _, idx in ipairs(lista) do if idx == sig then tieneSig = true end end
      local todosPuestos = n > 0 and lista[n] <= puestos
      local r, gg, bb = 0.25, 0.25, 0.25
      if tieneSig then r, gg, bb = 0.2, 1, 0.4
      elseif todosPuestos then r, gg, bb = 1, 0.82, 0
      elseif n > 0 and lista[1] <= puestos then r, gg, bb = 1, 0.82, 0
      elseif n > 0 then r, gg, bb = 0.9, 0.9, 0.9 end
      if b.borde.SetColorTexture then b.borde:SetColorTexture(r, gg, bb, n > 0 and 0.95 or 0.6) end
      if b.icono.SetDesaturated then b.icono:SetDesaturated(n == 0) end
      if b.SetAlpha then b:SetAlpha(n > 0 and 1 or 0.55) end
      b.rango:SetText((n == 0 and GRIS or (n >= rangos and ORO or VERDE)) .. n .. "/" .. rangos .. "|r")
      -- 4-oct (Andy: "Nv 18-19, 24" confunde): junto al icono, solo el PROXIMO nivel en que toca, o "listo"
      local proximo
      for _, idx in ipairs(lista) do if idx > puestos then proximo = idx; break end end
      local etq = ""
      if n > 0 and not proximo then etq = ORO .. L("listo", "done") .. "|r"
      elseif proximo then etq = COLOR[colorDe(proximo)] .. L("Nv ", "Lv ") .. nvP(proximo) .. "|r" end
      b.num:SetText(etq)
      b.nombre = nombre
      b.ayuda = WowF.libroAyudaTalento and WowF.libroAyudaTalento(p, nombre, nil)
      local partes = {}
      for i2, idx in ipairs(lista) do
        local reaj = (mixta and modo == 2 and nvP(idx) <= cambio) and L(" (al reajustar)", " (at respec)") or ""
        table.insert(partes, COLOR[colorDe(idx)] .. L("Nivel ", "Level ") .. nvP(idx) .. reaj .. "  »  " .. L("rango ", "rank ") .. i2 .. "/" .. rangos .. "|r")
      end
      b.extra = n > 0 and (CELESTE .. L("En este plan:", "In this plan:") .. "|r\n" .. table.concat(partes, "\n"))
        or (GRIS .. L("Este plan no lo usa.", "This plan does not use it.") .. "|r")
      b:Show()
      estado.casillas[nombre] = { numeros = lista, texto = b.num:GetText(), siguiente = tieneSig, boton = b }
    end
  end
  for i = k + 1, #casillas do casillas[i]:Hide() end

  -- Lineas de requisito (de la casilla que pide hacia la que se abre)
  local nr = 0
  local function linea(x, yy, w, h, puesto)
    nr = nr + 1
    local t = raya(nr)
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", marco, "TOPLEFT", x, -yy); t:SetSize(math.max(w, 1), math.max(h, 1))
    if t.SetColorTexture then if puesto then t:SetColorTexture(1, 0.82, 0, 0.85) else t:SetColorTexture(0.45, 0.45, 0.45, 0.7) end end
    t:Show()
  end
  for nombre, ta in pairs(c.talentos) do
    local req = ta[7]
    if ta[3] == pest and req and req ~= "" and pos[nombre] and pos[req] then
      local a, b = pos[req], pos[nombre]
      local usado = puntosDe[nombre] ~= nil
      local m = CAJA / 2
      if a[1] == b[1] then linea(a[1] + m - 1, a[2] + CAJA + 3, 3, b[2] - a[2] - CAJA - 6, usado)
      elseif a[2] == b[2] then
        local x1, x2 = math.min(a[1], b[1]) + CAJA + 3, math.max(a[1], b[1]) - 3
        linea(x1, a[2] + m - 1, x2 - x1, 3, usado)
      else
        local x1, x2
        if b[1] > a[1] then x1, x2 = a[1] + CAJA + 3, b[1] + m + 1 else x1, x2 = b[1] + m - 1, a[1] - 3 end
        linea(x1, a[2] + m - 1, x2 - x1, 3, usado)
        linea(b[1] + m - 1, a[2] + m - 1, 3, b[2] - a[2] - m + 1 - 3, usado)
      end
    end
  end
  for i = nr + 1, #rayas do rayas[i]:Hide() end
  -- Fila: puntos que pide (fila 2 = 5 puntos en esa rama, fila 3 = 10...)
  for f = 1, 7 do
    local t = etiquetas[f]
    if not t then t = marco:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); etiquetas[f] = t end
    if f <= filasMax then
      t:ClearAllPoints(); t:SetPoint("TOPLEFT", marco, "TOPLEFT", 0, -(arriba + (f - 1) * PASO_Y + 11))
      t:SetText(GRIS .. ((f - 1) * 5) .. "|r"); t:Show()
    else t:Hide() end
  end
  y = arriba + filasMax * PASO_Y + 2


  -- ===== De donde sale el orden =====
  local lineaGuia = textoGuia(g, 10)
  local limNivel = 9 + limite
  local desdeSin
  if not g then desdeSin = 10
  elseif g.reparto then desdeSin = (g.hasta or 0) + 1
  elseif (g.verificada or 0) < limNivel then desdeSin = math.max(10, (g.verificada or 0) + 1) end
  divGuia:ClearAllPoints(); divGuia:SetPoint("TOPLEFT", marco, "TOPLEFT", 0, -(y + 4)); divGuia:SetPoint("RIGHT", marco, "RIGHT", 0, 0)
  etqGuia:ClearAllPoints(); etqGuia:SetPoint("TOPLEFT", marco, "TOPLEFT", 0, -(y + 14))
  etqGuia:SetText(E.mayus(L("De dónde sale el orden", "Where the order comes from")))
  y = y + 30
  guiaTexto:ClearAllPoints(); guiaTexto:SetPoint("TOPLEFT", marco, "TOPLEFT", 0, -y)
  guiaTexto:SetText(lineaGuia and (E.cod.texto .. lineaGuia .. "|r" .. E.cod.tenue .. L("  ·  enlace (clic y Ctrl+C para copiarlo):", "  ·  link (click and Ctrl+C to copy):") .. "|r")
    or (NARANJA .. L("Sin guía verificada para esta rama: se añadirá en próximas actualizaciones, cuando haya una guía de Forever.", "No verified guide for this spec yet: it will be added in future updates, when a Forever guide exists.") .. "|r"))
  y = y + (guiaTexto:GetStringHeight() or 12) + 4
  local urls = {}
  if g and g.url and g.url ~= "" then table.insert(urls, g.url) end
  if g and g.compUrl and g.compUrl ~= "" and g.compUrl ~= g.url then table.insert(urls, g.compUrl) end
  for i = 1, 2 do
    local e = enlaces[i]
    if urls[i] then
      e._url = urls[i]; e:SetText(urls[i]); e:SetCursorPosition(0)
      e:ClearAllPoints(); e:SetPoint("TOPLEFT", marco, "TOPLEFT", 6, -y)
      e:Show(); y = y + 24
    else e._url = nil; e:Hide() end
  end
  local notas = {}
  if g and g.reparto then
    table.insert(notas, NARANJA .. L("La guía solo da el reparto del nivel " .. g.hasta .. " (qué talentos llevar), no en qué orden; aquí van en el orden en que la guía los lista.",
      "The guide only gives the level " .. g.hasta .. " build (which talents), not the order; here they follow the order the guide lists them.") .. "|r")
  end
  if desdeSin and desdeSin <= limNivel then
    local dj = math.max(1, desdeSin - EXTRA)
    table.insert(notas, NARANJA .. L("Sin guía verificada desde el nivel " .. dj .. ": los números en naranja son una propuesta del addon, no de una guía. Se actualizará en próximas actualizaciones, cuando haya más datos.",
      "No verified guide from level " .. dj .. ": the orange numbers are the addon's suggestion, not from a guide. It will be updated in future updates, as more data becomes available.") .. "|r")
  end
  if mixta and modo == 2 and nivel < cambio then
    table.insert(notas, GRIS .. L("Al nivel " .. cambio .. " reajustas y pones de golpe los puntos 1 a " .. (cambio - 9 + EXTRA) .. " en este orden; después, uno por nivel.",
      "At level " .. cambio .. " you reset and spend points 1 to " .. (cambio - 9 + EXTRA) .. " at once in this order; then one per level.") .. "|r")
  end
  if limite < #orden and nvP(limite) >= tope and nivel <= tope then
    table.insert(notas, GRIS .. L("La beta llega al nivel " .. tope .. ": se enseña hasta ahí.", "The beta goes up to level " .. tope .. ": shown up to there.") .. "|r")
  end
  if notaLegacy then table.insert(notas, 1, notaLegacy) end
  if avisoOrden then table.insert(notas, 1, NARANJA .. avisoOrden .. "|r") end
  do local tt, cc = textoDesact(g); if tt then table.insert(notas, 1, NARANJA .. tt .. ": " .. cc .. "|r") end end
  notaTexto:ClearAllPoints(); notaTexto:SetPoint("TOPLEFT", marco, "TOPLEFT", 0, -y)
  notaTexto:SetText(table.concat(notas, "\n"))
  if #notas > 0 then y = y + (notaTexto:GetStringHeight() or 12) * #notas + 4 end
  leyenda:ClearAllPoints(); leyenda:SetPoint("TOPLEFT", marco, "TOPLEFT", 0, -y)
  leyenda:SetText(ORO .. L("Oro", "Gold") .. "|r" .. GRIS .. L(" = ya puesto  ·  ", " = spent  ·  ") .. "|r" .. VERDE .. L("Verde", "Green") .. "|r" .. GRIS .. L(" = el siguiente  ·  ", " = next  ·  ") .. "|r" ..
    BLANCO .. L("Blanco", "White") .. "|r" .. GRIS .. L(" = después  ·  ", " = later  ·  ") .. "|r" .. NARANJA .. L("Naranja", "Orange") .. "|r" .. GRIS .. L(" = sin guía  ·  Gris = no se usa  ·  junto al icono: el próximo nivel en que le toca (listo = completo)  ·  número a la izquierda = puntos que pide la fila", " = no guide  ·  Gray = not used  ·  next to the icon: the next level it gets a point (done = complete)  ·  left number = points the row needs") .. "|r")
  y = y + (leyenda:GetStringHeight() or 12) * 2 + 6
  estado.textoGuia = guiaTexto:GetText()
  estado.notas = notaTexto:GetText()
  estado.urls = urls

  marco:SetHeight(y)
  bloque(marco, y)
end

function WowF.diagramaOcultar() if marco then marco:Hide() end end
-- Para las pruebas
function WowF.diagramaEstado() return estado end
function WowF.diagramaElegirPestana(i) if botonesPestana[i] and botonesPestana[i]:GetScript("OnClick") then botonesPestana[i]:GetScript("OnClick")() end end
function WowF.diagramaElegirModo(i) if botonesModo[i] and botonesModo[i]:GetScript("OnClick") then botonesModo[i]:GetScript("OnClick")() end end
function WowF.diagramaTexto()
  local t = {}
  for i = 1, 3 do if botonesPestana[i] and botonesPestana[i]:IsShown() then table.insert(t, botonesPestana[i]:GetText()) end end
  for i = 1, 2 do if botonesModo[i] and botonesModo[i]:IsShown() then table.insert(t, botonesModo[i]:GetText()) end end
  for _, f in ipairs({ siguiente, pasos, guiaTexto, notaTexto, leyenda }) do if f then table.insert(t, f:GetText() or "") end end
  return table.concat(t, "\n")
end

-- ===================== Vista de Talentos (11-oct, maqueta talentos.png aprobada por Andy) =====================
-- Izquierda: tarjeta del arbol (conmutador de los 3 arboles, lienzo con las casillas en su fila/columna, requisitos y leyenda).
-- Derecha: Tu siguiente punto | Orden de tu guia (3 x 3) | Tu rama + Reiniciar talentos. Mismos datos que contenidoDiagrama
-- (orden / orden2, guia / guia2, punto idx = nivel 9 + idx). El contenido viejo sigue armado (oculto) para las pruebas.
do
  local C = E.color
  local vt
  local textos = {}
  local function anotar(s) if type(s) == "string" and s ~= "" then table.insert(textos, s) end return s end
  local function poner(fs, s) s = s or ""; fs:SetText(s); anotar(s); return s end
  local ANCHO_ARBOL, GAP, PAD = 378, 12, 16
  local TX, TY, PX, PY, T = 28, 26, 78, 74, 44
  local GRIS_LEY = { 0.353, 0.318, 0.282 }

  local function boton(padre, tipo, chico)
    local b = CreateFrame("Button", nil, padre, "UIPanelButtonTemplate")
    E.boton(b, tipo, nil, chico)
    return b
  end
  local function textoBoton(b, s, chico) b:SetText(s); anotar(s); return tonumber(E.botonAncho(b, chico)) or 120 end
  local function ajustar(fs, w) if fs.SetWidth then fs:SetWidth(w) end; if fs.SetWordWrap then fs:SetWordWrap(true) end end
  local function alto(fs, minimo)
    local h = fs and fs.GetStringHeight and tonumber(fs:GetStringHeight()) or 0
    if type(h) ~= "number" or h <= 0 then h = minimo or 14 end
    return math.max(h, minimo or 0)
  end
  local function tooltip(f)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
      local tt = rawget(self, "ayuda")
      if not GameTooltip or not tt then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(WowF.T(tt), 1, 1, 1, 1, true); GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  end

  -- El mismo calculo de contenidoDiagrama (modo, limite, puestos, siguiente, arbol elegido)
  local function calcular(p)
    local c = WowFDatos and WowFDatos.clases and WowFDatos.clases[p.clase or ""]
    if not c or not c.pestanas or not c.talentos or not p.orden or #p.orden == 0 then return nil end
    local s = { c = c }
    s.nivel = nivelActual()
    s.tope = (WowFDatos and WowFDatos.topeBeta) or 30
    s.cambio = p.ramaCambio or 0
    s.mixta = s.cambio > 0 and p.orden2 ~= nil and #p.orden2 > 0
    s.clave = tostring(p.clase) .. "|" .. tostring(p.rama)
    s.modoNivel = (s.mixta and s.nivel >= s.cambio) and 2 or 1
    s.modo = s.mixta and (modoElegido[s.clave] or s.modoNivel) or 1
    s.orden = (s.modo == 2) and p.orden2 or p.orden
    s.g = (s.modo == 2) and p.guia2 or p.guia
    s.gastados, s.notaLegacy = leerPuntos(s.nivel)
    s.extra = EXTRA
    local limite = math.max(s.tope, s.nivel) - 9 + EXTRA
    if s.cambio > 0 and s.modo == 1 then limite = math.min(limite, s.cambio - 10 + EXTRA) end
    if s.mixta and s.modo == 2 then limite = math.max(limite, s.cambio - 9 + EXTRA) end
    s.limite = math.max(0, math.min(limite, #s.orden))
    if s.mixta and s.modo == 1 and s.nivel >= s.cambio then s.puestos, s.sig = s.limite, nil
    elseif s.mixta and s.modo == 2 and s.nivel < s.cambio then s.puestos, s.sig = 0, nil
    else s.puestos, s.avisoOrden = WowF.seguirPlanTalentos(c, s.orden, s.limite, s.gastados); s.sig = (s.puestos + 1 <= s.limite) and (s.puestos + 1) or nil end
    s.puntosDe, s.porPestana, s.puestosPestana = {}, {}, {}
    for idx = 1, s.limite do
      local n = s.orden[idx]
      s.puntosDe[n] = s.puntosDe[n] or {}
      table.insert(s.puntosDe[n], idx)
      local ta = c.talentos[n]
      if ta then
        s.porPestana[ta[3]] = (s.porPestana[ta[3]] or 0) + 1
        if idx <= s.puestos then s.puestosPestana[ta[3]] = (s.puestosPestana[ta[3]] or 0) + 1 end
      end
    end
    s.claveP = s.clave .. "|" .. s.modo
    local pest = elegida[s.claveP]
    if not pest then
      local n = s.sig and s.orden[s.sig] or s.orden[math.max(1, s.limite)]
      pest = n and c.talentos[n] and c.talentos[n][3]
      local mas = -1
      if not pest then for _, nombre in ipairs(c.pestanas) do if (s.porPestana[nombre] or 0) > mas then mas = s.porPestana[nombre] or 0; pest = nombre end end end
    end
    s.pest = pest
    return s
  end

  -- Niveles de una lista de puntos: {1,2,3,7} -> "10-12, 16"
  local function niveles(lista)
    local partes, i = {}, 1
    while i <= #lista do
      local j = i
      while j < #lista and lista[j + 1] == lista[j] + 1 do j = j + 1 end
      table.insert(partes, j > i and (nvP(lista[i]) .. "-" .. nvP(lista[j])) or tostring(nvP(lista[i])))
      i = j + 1
    end
    return table.concat(partes, ", ")
  end

  local function crear(hoja, ancho)
    vt = CreateFrame("Frame", nil, hoja)
    vt:SetSize(ancho, 668)
    -- ----- Arbol -----
    local a = E.tarjeta(vt, { fondo = { 0.102, 0.086, 0.075 }, alfa = 0.4 }) -- 12-oct: mas transparente
    a:SetPoint("TOPLEFT", vt, "TOPLEFT", 0, 0); a:SetWidth(ANCHO_ARBOL)
    a.seg = {}
    for i = 1, 3 do
      local b = boton(a, "toggle", true)
      if i == 1 then b:SetPoint("TOPLEFT", a, "TOPLEFT", PAD, -14) else b:SetPoint("LEFT", a.seg[i - 1], "RIGHT", -1, 0) end
      a.seg[i] = b
    end
    a.puntos = E.texto(a, nil, 12, C.tenue, "medio"); a.puntos:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -PAD, 15) -- 12-oct: con la letra mas grande, arriba lo tapaban las pestanas
    if a.puntos.SetJustifyH then a.puntos:SetJustifyH("RIGHT") end
    local lz = CreateFrame("Frame", nil, a)
    lz:SetPoint("TOPLEFT", a, "TOPLEFT", PAD, -50); lz:SetWidth(ANCHO_ARBOL - 2 * PAD)
    -- 12-oct (Andy: "muy oscura"): el lienzo deja ver el arte de la clase (antes opaco)
    lz.borde = E.textura(lz, "BACKGROUND", 1, { 0.227, 0.2, 0.169 }, 0.45); lz.borde:SetAllPoints()
    lz.fondo = E.textura(lz, "BACKGROUND", 2, { 0.082, 0.071, 0.059 }, 0.3)
    lz.fondo:SetPoint("TOPLEFT", 1, -1); lz.fondo:SetPoint("BOTTOMRIGHT", -1, 1)
    lz.tal, lz.req = {}, {}
    a.lienzo = lz
    a.ley = {}
    local ley = { { L("el siguiente", "next"), C.verde }, { L("en tu plan", "in your plan"), C.oro }, { L("fuera del plan", "not in plan"), GRIS_LEY } }
    for i, x in ipairs(ley) do
      local cu = CreateFrame("Frame", nil, a); cu:SetSize(10, 10)
      cu.b = E.textura(cu, "ARTWORK", 1, x[2], 1); cu.b:SetAllPoints()
      cu.n = E.textura(cu, "ARTWORK", 2, { 0.102, 0.086, 0.075 }, 1); cu.n:SetPoint("TOPLEFT", 2, -2); cu.n:SetPoint("BOTTOMRIGHT", -2, 2)
      cu.t = E.texto(a, nil, 12, C.tenue, "medio"); cu.t:SetPoint("LEFT", cu, "RIGHT", 5, 0)
      cu.texto = x[1]
      a.ley[i] = cu
    end
    vt.arbol = a

    -- ----- Columna derecha -----
    local xd = ANCHO_ARBOL + GAP
    local wd = ancho - xd
    local s = E.tarjeta(vt, { variante = "principal" })
    s:SetPoint("TOPLEFT", vt, "TOPLEFT", xd, 0); s:SetSize(wd, 104)
    s.eti = E.rotulo(s); s.eti:SetPoint("TOPLEFT", PAD, -16)
    s.icono = E.icono(s, 52, "verde"); s.icono:SetPoint("TOPLEFT", PAD, -38)
    s.h2 = E.h2(s, nil, 22); s.h2:SetPoint("TOPLEFT", s.icono, "TOPRIGHT", 14, -4)
    if s.h2.SetWordWrap then s.h2:SetWordWrap(false) end
    s.rgo = E.texto(s, nil, 13, C.tenue, "negrita"); s.rgo:SetPoint("BOTTOMLEFT", s.h2, "BOTTOMRIGHT", 6, 2)
    s.sub = E.texto(s, nil, 13, C.tenue, "medio"); s.sub:SetPoint("TOPLEFT", s.h2, "BOTTOMLEFT", 0, -6); ajustar(s.sub, wd - 2 * PAD - 66 - 90)
    s.anchoTexto = wd - 2 * PAD - 66 - 90 -- 12-oct: el nombre del talento no pasa de aqui (antes podia llegar a la cifra de la derecha)
    s.raya = E.textura(s, "ARTWORK", 1, C.borde, 1); s.raya:SetWidth(1); s.raya:SetPoint("TOPRIGHT", s, "TOPRIGHT", -(PAD + 74), -40); s.raya:SetHeight(46)
    s.num = E.texto(s, nil, 26, C.brasa, "negrita"); s.num:SetPoint("TOP", s, "TOPRIGHT", -(PAD + 37), -44)
    if s.num.SetJustifyH then s.num:SetJustifyH("CENTER") end
    s.rot = E.rotulo(s, nil, C.tenue, 10); s.rot:SetPoint("TOP", s.num, "BOTTOM", 0, -4)
    tooltip(s)
    vt.sig = s

    local o = E.tarjeta(vt)
    o:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -GAP); o:SetWidth(wd)
    o.eti = E.rotulo(o, nil, C.oro); o.eti:SetPoint("TOPLEFT", PAD, -16)
    o.copiar = boton(o, "terciario", true); o.copiar:SetPoint("TOPRIGHT", o, "TOPRIGHT", -PAD, -8)
    o.enlace = CreateFrame("EditBox", nil, o, "InputBoxTemplate")
    o.enlace:SetSize(wd - 2 * PAD - 8, 20); o.enlace:SetAutoFocus(false)
    if o.enlace.SetFontObject then o.enlace:SetFontObject("GameFontHighlightSmall") end
    o.enlace:SetScript("OnTextChanged", function(self) local u = rawget(self, "url"); if u and self:GetText() ~= u then self:SetText(u) end end)
    o.enlace:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    o.enlace:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self:Hide() end)
    o.enlace:SetScript("OnEnterPressed", function(self) self:ClearFocus(); self:Hide() end)
    -- Fondo opaco: el cuadro sale encima de la cabecera de la tarjeta
    o.enlace.tapa = E.textura(o.enlace, "BACKGROUND", -8, { 0.102, 0.086, 0.075 }, 1)
    o.enlace.tapa:SetPoint("TOPLEFT", -10, 6); o.enlace.tapa:SetPoint("BOTTOMRIGHT", 6, -6)
    o.enlace:Hide()
    -- 16-oct (Andy: "ponlo como estaba antes, es mucho más bonito"): rejilla de tarjetas de 3 columnas, como antes,
    -- pero con TODOS los grupos hasta el último punto (antes era una ventana de 12). Se crean al pedirlas (filaOrden).
    o.pasos = {}
    local wp = math.floor((wd - 2 * PAD - 16) / 3)
    o.anchoPaso = wp
    o.filaOrden = function(k)
      local f = o.pasos[k]
      if f then return f end
      f = CreateFrame("Frame", nil, o)
      f:SetSize(wp, 52)
      f.borde = E.textura(f, "BACKGROUND", 1, { 0.231, 0.212, 0.192 }, 1); f.borde:SetAllPoints()
      f.fondo = E.textura(f, "BACKGROUND", 2, { 0.129, 0.122, 0.11 }, 1); f.fondo:SetPoint("TOPLEFT", 1, -1); f.fondo:SetPoint("BOTTOMRIGHT", -1, 1)
      f.icono = E.icono(f, 28); f.icono:SetPoint("LEFT", 8, 0)
      f.nv = E.rotulo(f, nil, C.oro, 11); f.nv:SetPoint("TOPLEFT", f, "TOPLEFT", 45, -7)
      f.nombre = E.texto(f, nil, 13, C.texto, "negrita"); f.nombre:SetPoint("TOPLEFT", f.nv, "BOTTOMLEFT", 0, -2); ajustar(f.nombre, wp - 53)
      tooltip(f)
      o.pasos[k] = f
      return f
    end
    o.aviso = E.texto(o, nil, 12, C.brasa, "medio"); ajustar(o.aviso, wd - 2 * PAD)
    o.nota = E.texto(o, nil, 12, C.tenue, "medio"); ajustar(o.nota, wd - 2 * PAD)
    vt.orden = o

    -- 11-oct (Andy: "se va de la pantalla"): Tu rama y Reiniciar talentos van una debajo de otra, a todo el ancho
    -- de la columna, para que los botones de modo quepan en una sola fila y la columna entre en el alto visible.
    local r = E.tarjeta(vt)
    r:SetPoint("TOPLEFT", o, "BOTTOMLEFT", 0, -GAP); r:SetWidth(wd)
    r.anchoUtil = wd - 2 * PAD
    r.eti = E.rotulo(r, nil, C.oro); r.eti:SetPoint("TOPLEFT", PAD, -14)
    r.cambiar = boton(r, "secundario", true); r.cambiar:SetPoint("TOPRIGHT", r, "TOPRIGHT", -PAD, -10)
    r.h3 = E.h3(r, nil, 16); r.h3:SetPoint("TOPLEFT", r.eti, "BOTTOMLEFT", 0, -6); ajustar(r.h3, wd - 2 * PAD - 150)
    r.sub = E.texto(r, nil, 13, C.tenue, "medio"); r.sub:SetPoint("TOPLEFT", r.h3, "BOTTOMLEFT", 0, -4); ajustar(r.sub, wd - 2 * PAD)
    r.real = boton(r, "terciario", true)
    r.modos = { boton(r, "toggle", true), boton(r, "toggle", true) }
    vt.rama = r

    local x = E.tarjeta(vt)
    x:SetPoint("TOPLEFT", r, "BOTTOMLEFT", 0, -GAP); x:SetWidth(wd)
    -- Icono de lo que hace (el mismo de "Reajusta tus talentos"); al pasar el raton, la explicacion larga
    x.icono = E.icono(x, 40, "oro"); x.icono:SetPoint("TOPLEFT", PAD, -14)
    tooltip(x.icono)
    x.eti = E.rotulo(x, nil, C.oro); x.eti:SetPoint("TOPLEFT", x.icono, "TOPRIGHT", 12, 0)
    x.h3 = E.h3(x, nil, 16); x.h3:SetPoint("TOPLEFT", x.eti, "BOTTOMLEFT", 0, -6); ajustar(x.h3, wd - 2 * PAD - 52 - 190)
    x.sub = E.texto(x, nil, 13, C.tenue, "medio"); x.sub:SetPoint("TOPLEFT", x.h3, "BOTTOMLEFT", 0, -6); ajustar(x.sub, wd - 2 * PAD - 52)
    x.ir = boton(x, "terciario", true); x.ir:SetPoint("TOPRIGHT", x, "TOPRIGHT", -PAD, -16)
    vt.reinicio = x
  end

  local function casillaV(lz, i)
    if lz.tal[i] then return lz.tal[i] end
    local b = CreateFrame("Button", nil, lz)
    b:SetSize(T, T)
    b.aro = E.textura(b, "BACKGROUND", 0, C.verde, 0.25); b.aro:SetPoint("TOPLEFT", -3, 3); b.aro:SetPoint("BOTTOMRIGHT", 3, -3)
    b.icono = E.icono(b, T); b.icono:SetAllPoints()
    b.rgF = CreateFrame("Frame", nil, b); b.rgF:SetSize(26, 16); b.rgF:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 9, -7)
    if b.rgF.SetFrameLevel and b.GetFrameLevel then pcall(b.rgF.SetFrameLevel, b.rgF, (tonumber(b:GetFrameLevel()) or 1) + 3) end
    b.rgB = E.textura(b.rgF, "BACKGROUND", 1, GRIS_LEY, 1); b.rgB:SetAllPoints()
    b.rgN = E.textura(b.rgF, "BACKGROUND", 2, { 0.059, 0.051, 0.043 }, 1); b.rgN:SetPoint("TOPLEFT", 1, -1); b.rgN:SetPoint("BOTTOMRIGHT", -1, 1)
    b.rg = E.texto(b.rgF, nil, 11, C.tenue, "negrita"); b.rg:SetPoint("CENTER", 0, 0)
    b.ordF = CreateFrame("Frame", nil, b); b.ordF:SetSize(10, 14); b.ordF:SetPoint("BOTTOMLEFT", b, "TOPLEFT", -6, -1)
    if b.ordF.SetFrameLevel and b.GetFrameLevel then pcall(b.ordF.SetFrameLevel, b.ordF, (tonumber(b:GetFrameLevel()) or 1) + 3) end
    b.ordN = E.textura(b.ordF, "BACKGROUND", 1, { 0.082, 0.071, 0.059 }, 1); b.ordN:SetAllPoints()
    b.ord = E.texto(b.ordF, nil, 11, C.oro, "negrita"); b.ord:SetPoint("LEFT", 3, 0)
    if b.ord.SetWordWrap then b.ord:SetWordWrap(false) end
    b:SetScript("OnEnter", function(self)
      local nombre = rawget(self, "nombre")
      if not GameTooltip or not nombre then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local ayuda = rawget(self, "ayuda")
      local base = ayuda and WowF.T(ayuda) or (ORO .. nombre .. "|r")
      GameTooltip:SetText(base .. "\n\n" .. (rawget(self, "extra") or ""), 1, 1, 1, 1, true)
      if GameTooltip.SetMinimumWidth then GameTooltip:SetMinimumWidth(260) end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    lz.tal[i] = b
    return b
  end

  local function llenarArbol(p, s)
    local a = vt.arbol
    local c = s.c
    for i, b in pairs(a.seg) do
      local nombre = c.pestanas[i]
      if nombre then
        textoBoton(b, nombre, true)
        E.toggle(b, nombre == s.pest)
        b:SetScript("OnClick", function() elegida[s.claveP] = nombre; if WowF.libroRedibujar then WowF.libroRedibujar() end end)
        b:Show()
      else b:Hide() end
    end
    local np = s.puestosPestana[s.pest] or 0
    poner(a.puntos, L(np .. (np == 1 and " punto" or " puntos"), np .. (np == 1 and " point" or " points")))
    local lz = a.lienzo
    local pos, k, filasMax = {}, 0, 1
    local casEstado = {}
    for nombre, ta in pairs(c.talentos) do
      if ta[3] == s.pest and (ta[4] or 0) > 0 and (ta[5] or 0) > 0 then
        k = k + 1
        local b = casillaV(lz, k)
        local fila, col = ta[4], ta[5]
        if fila > filasMax then filasMax = fila end
        local bx, by = TX + (col - 1) * PX, TY + (fila - 1) * PY
        pos[nombre] = { bx, by }
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", lz, "TOPLEFT", bx, -by)
        local lista = s.puntosDe[nombre] or {}
        local n, rangos = #lista, ta[1] or 1
        local tieneSig = false
        local yaPuestos = 0
        for _, idx in ipairs(lista) do if idx == s.sig then tieneSig = true end; if idx <= s.puestos then yaPuestos = yaPuestos + 1 end end
        local color = tieneSig and "verde" or (n > 0 and "oro" or nil)
        b.icono:poner((ta[6] and ta[6] ~= "") and ("Interface\\Icons\\" .. ta[6]) or nil, color, n == 0)
        if n == 0 and b.icono.tex.SetVertexColor then b.icono.tex:SetVertexColor(0.5, 0.5, 0.5) end
        if tieneSig then b.aro:Show() else b.aro:Hide() end
        local rcol = tieneSig and C.verde or C.tenue
        b.rg:SetTextColor(rcol[1], rcol[2], rcol[3], 1)
        if b.rgB.SetColorTexture then local bc = tieneSig and C.verde or GRIS_LEY; b.rgB:SetColorTexture(bc[1], bc[2], bc[3], 1) end
        b.rg:SetText(yaPuestos .. "/" .. rangos)
        if n > 0 then
          local txt = niveles(lista)
          b.ord:SetText(txt)
          local oc = tieneSig and C.verde or C.oro
          b.ord:SetTextColor(oc[1], oc[2], oc[3], 1)
          local w = b.ord.GetStringWidth and tonumber(b.ord:GetStringWidth()) or 30
          b.ordF:SetWidth((type(w) == "number" and w > 0 and w or 30) + 6)
          b.ordF:Show()
        else b.ordF:Hide() end
        b.nombre = nombre
        b.ayuda = WowF.libroAyudaTalento and WowF.libroAyudaTalento(p, nombre, nil)
        local partes = {}
        for i2, idx in ipairs(lista) do
          local reaj = (s.mixta and s.modo == 2 and nvP(idx) <= s.cambio) and L(" (al reajustar)", " (at respec)") or ""
          local lg = s.g and s.g.legacy and tonumber(s.g.legacy.desde)
          if lg and idx >= lg and idx < lg + (tonumber(s.g.legacy.n) or 0) then reaj = reaj .. L(" (Legacy, solo beta)", " (Legacy, beta only)") end
          table.insert(partes, L("Nivel ", "Level ") .. nvP(idx) .. reaj .. "  »  " .. L("rango ", "rank ") .. i2 .. "/" .. rangos)
        end
        b.extra = n > 0 and (CELESTE .. L("En este plan:", "In this plan:") .. "|r\n" .. table.concat(partes, "\n"))
          or (GRIS .. L("Este plan no lo usa.", "This plan does not use it.") .. "|r")
        b:Show()
        casEstado[nombre] = { numeros = lista, texto = n > 0 and niveles(lista) or "", siguiente = tieneSig, boton = b }
      end
    end
    for i, b in pairs(lz.tal) do if i > k then b:Hide() end end
    -- Requisitos: raya de 2 px #6b5a3a entre las casillas
    local nr = 0
    local function linea(x, y, w, h)
      nr = nr + 1
      local t = lz.req[nr]
      if not t then t = E.textura(lz, "BORDER", 1, { 0.42, 0.353, 0.227 }, 1); lz.req[nr] = t end
      t:ClearAllPoints(); t:SetPoint("TOPLEFT", lz, "TOPLEFT", x, -y); t:SetSize(math.max(w, 1), math.max(h, 1)); t:Show()
    end
    local m = T / 2
    for nombre, ta in pairs(c.talentos) do
      local req = ta[7]
      if ta[3] == s.pest and req and req ~= "" and pos[nombre] and pos[req] then
        local p1, p2 = pos[req], pos[nombre]
        if p1[1] == p2[1] then linea(p1[1] + m - 1, p1[2] + T, 2, p2[2] - p1[2] - T)
        elseif p1[2] == p2[2] then
          local x1, x2 = math.min(p1[1], p2[1]) + T, math.max(p1[1], p2[1])
          linea(x1, p1[2] + m - 1, x2 - x1, 2)
        else
          local x1, x2
          if p2[1] > p1[1] then x1, x2 = p1[1] + T, p2[1] + m + 1 else x1, x2 = p2[1] + m - 1, p1[1] end
          linea(x1, p1[2] + m - 1, x2 - x1, 2)
          linea(p2[1] + m - 1, p1[2] + m - 1, 2, p2[2] - p1[2] - m + 1)
        end
      end
    end
    for i, t in pairs(lz.req) do if i > nr then t:Hide() end end
    return filasMax, casEstado
  end

  -- 12-oct (legibilidad): el nombre se recorta antes de la cifra de la derecha y la tarjeta crece con el texto (antes 104 fijo:
  -- con la letra mas grande, el "Por que" se salia por abajo). Margen interior de 16 px a cada lado.
  local function altoSiguiente(sc)
    local max = tonumber(rawget(sc, "anchoTexto")) or 300
    if sc.h2.SetWidth then sc.h2:SetWidth(0) end
    local w = sc.h2.GetStringWidth and tonumber(sc.h2:GetStringWidth()) or 0
    local wr = sc.rgo.GetStringWidth and tonumber(sc.rgo:GetStringWidth()) or 0
    local tope = max - (type(wr) == "number" and wr > 0 and (wr + 6) or 0)
    if type(w) == "number" and w > tope and sc.h2.SetWidth then sc.h2:SetWidth(math.floor(tope)) end
    local h = 42 + alto(sc.h2, 22) + 6 + alto(sc.sub, 14) + 16
    h = math.max(104, math.floor(h + 0.5))
    sc:SetHeight(h)
    return h
  end

  local function llenarSiguiente(p, s)
    local sc = vt.sig
    local c = s.c
    E.ponerRotulo(sc.eti, anotar(L("Tu siguiente punto", "Your next point")))
    local modoAhora = s.mixta and s.modoNivel or 1
    local ordenAhora = (modoAhora == 2) and p.orden2 or p.orden
    local idx = (ordenAhora == s.orden and s.avisoOrden) and (s.puestos + 1) or (s.gastados + 1)
    if s.nivel < 10 - EXTRA then idx = 1 end
    sc.ayuda = nil
    if s.mixta and modoAhora == 1 and idx > s.cambio - 10 + EXTRA then
      sc.icono:poner("Interface\\Icons\\Spell_Holy_Restoration", "oro")
      poner(sc.h2, L("Reajusta tus talentos", "Reset your talents")); poner(sc.rgo, "")
      poner(sc.sub, WowF.yaTraducido(L("Al nivel " .. s.cambio .. " ve al entrenador, reinicia y reparte como en «2. Al nivel " .. s.cambio .. "».",
        "At level " .. s.cambio .. " visit your trainer, reset and spend as in \"2. At level " .. s.cambio .. "\".")))
      local faltan = math.max(0, s.cambio - s.nivel)
      poner(sc.num, tostring(faltan)); E.ponerRotulo(sc.rot, anotar(faltan == 1 and L("nivel", "level") or L("niveles", "levels")))
      return altoSiguiente(sc)
    end
    local n = ordenAhora[idx]
    -- 16-oct: sin puntos libres (p. ej. los siguientes son de Legacy y no los tienes) no se inventa un "nivel 31"
    if n and s.limite and idx > s.limite then
      sc.icono:poner("Interface\\Icons\\INV_Misc_Book_09", "oro")
      poner(sc.h2, L("Plan completo", "Plan complete")); poner(sc.rgo, "")
      local leg = s.g and s.g.legacy
      poner(sc.sub, WowF.yaTraducido(L("Ya tienes todos los puntos hasta el nivel " .. nvP(s.limite) .. ".", "You have every point up to level " .. nvP(s.limite) .. ".")
        .. (leg and L(" Con Legacy «Talented» (solo beta) seguirías con " .. n .. " (en morado abajo).", " With Legacy \"Talented\" (beta only) you would continue with " .. n .. " (purple below).") or "")))
      poner(sc.num, "OK"); E.ponerRotulo(sc.rot, anotar(L("listo", "done")))
      return altoSiguiente(sc)
    end
    if not n then
      sc.icono:poner("Interface\\Icons\\INV_Misc_Book_09", "oro")
      poner(sc.h2, L("Plan completo", "Plan complete")); poner(sc.rgo, "")
      poner(sc.sub, L("Ya tienes todos los talentos del plan.", "You have every talent in the plan."))
      poner(sc.num, "OK"); E.ponerRotulo(sc.rot, anotar(L("listo", "done")))
      return altoSiguiente(sc)
    end
    local ta = c.talentos[n] or {}
    local rk = 0
    for i2 = 1, idx do if ordenAhora[i2] == n then rk = rk + 1 end end
    local nv = nvP(idx)
    sc.icono:poner((ta[6] and ta[6] ~= "") and ("Interface\\Icons\\" .. ta[6]) or nil, "verde")
    poner(sc.h2, n)
    poner(sc.rgo, rk .. "/" .. (ta[1] or 1))
    local donde = L("árbol " .. tostring(ta[3] or "?") .. ", fila " .. tostring(ta[4] or "?"), tostring(ta[3] or "?") .. " tree, row " .. tostring(ta[4] or "?"))
    local cuando = nv <= s.nivel and L("Ya puedes ponerlo", "You can spend it now") or L("Al llegar al nivel " .. nv, "When you reach level " .. nv)
    local r = c.ramas and c.ramas[p.indiceRama or 0]
    local tabla = r and ((modoAhora == 2) and r.porque2 or r.porque)
    local por = tabla and tabla[n]
    local texto = cuando .. " · " .. donde
    if por then texto = texto .. "\n" .. L("Por qué (según " .. tostring(por[3]) .. "): ", "Why (per " .. tostring(por[3]) .. "): ") .. L(por[1], por[2]) end
    poner(sc.sub, WowF.yaTraducido(texto))
    local faltan = math.max(0, nv - s.nivel)
    if faltan == 0 then poner(sc.num, L("Ya", "Now")); E.ponerRotulo(sc.rot, anotar(L("puedes", "ready")))
    else poner(sc.num, tostring(faltan)); E.ponerRotulo(sc.rot, anotar(faltan == 1 and L("nivel", "level") or L("niveles", "levels"))) end
    sc.ayuda = WowF.libroAyudaTalento and WowF.libroAyudaTalento(p, n, nil)
    return altoSiguiente(sc)
  end

  -- Orden de la guia en tarjetas (puntos seguidos del mismo talento), del nivel 10 al último punto; devuelve el alto de la tarjeta
  local function llenarOrden(p, s)
    local o = vt.orden
    local c = s.c
    E.ponerRotulo(o.eti, anotar(L("Orden de tu guía · niveles " .. nvP(1) .. " a " .. nvP(s.limite), "Your guide order · levels " .. nvP(1) .. " to " .. nvP(s.limite))))
    local urls = {}
    if s.g and s.g.url and s.g.url ~= "" then table.insert(urls, s.g.url) end
    if s.g and s.g.compUrl and s.g.compUrl ~= "" and s.g.compUrl ~= s.g.url then table.insert(urls, s.g.compUrl) end
    o.enlace:Hide()
    if urls[1] then
      textoBoton(o.copiar, WowF.yaTraducido(tostring(s.g.fuente or "Guide") .. L(" · copiar enlace", " · copy link")), true)
      o.copiar:SetScript("OnClick", function()
        o.enlace.url = urls[1]; o.enlace:SetText(urls[1])
        if o.enlace.SetCursorPosition then o.enlace:SetCursorPosition(0) end
        o.enlace:Show(); o.enlace:SetFocus(); o.enlace:HighlightText()
      end)
      o.copiar:Show()
    else o.copiar:Hide() end
    local y = 40
    -- Aviso de guía desactualizada, arriba de la lista
    local tt, cc = textoDesact(s.g)
    if tt then
      poner(o.aviso, WowF.yaTraducido(tt .. "\n" .. cc))
      o.aviso:ClearAllPoints(); o.aviso:SetPoint("TOPLEFT", o, "TOPLEFT", PAD, -y); o.aviso:Show()
      y = y + alto(o.aviso, 14) + 10
    else o.aviso:Hide() end
    local usadas = 0
    -- 16-oct (Andy): puntos de Legacy "Talented" (solo beta). En morado; si no los tienes, se ven igual pero "solo con Legacy".
    local leg = s.g and s.g.legacy
    local legDesde = leg and tonumber(leg.desde) or nil
    local legHasta = legDesde and (legDesde + (tonumber(leg.n) or 0) - 1) or nil
    local LEG = { 0.78, 0.55, 1 }
    local hastaK = s.limite
    if legHasta and s.limite >= legDesde - 1 and s.limite < legHasta then hastaK = legHasta end
    local function esLegK(k) return legDesde and k >= legDesde and k <= legHasta or false end
    local grupos, idx = {}, 1
    while idx <= hastaK do
      local n, j = s.orden[idx], idx
      if not n then break end
      while j < hastaK and s.orden[j + 1] == n and esLegK(j + 1) == esLegK(idx) and ((j + 1 > s.limite) == (idx > s.limite)) do j = j + 1 end
      local rkA, rkB = 0, 0
      for i2 = 1, j do if s.orden[i2] == n then rkB = rkB + 1; if i2 <= idx then rkA = rkB end end end
      table.insert(grupos, { n = n, a = idx, b = j, rk = (j > idx) and (rkA .. "-" .. rkB) or tostring(rkA) })
      idx = j + 1
    end
    local wp = o.anchoPaso
    for k, gr in ipairs(grupos) do
      local f = o.filaOrden(k)
      local ta = c.talentos[gr.n] or {}
      local esLeg = esLegK(gr.a)
      local fuera = gr.a > s.limite
      local esSig = s.sig and s.sig >= gr.a and s.sig <= gr.b
      local hecho = gr.b <= s.puestos
      local verif = esLeg or (s.g and ((s.g.reparto and 9 + gr.a <= (s.g.hasta or 0)) or (not s.g.reparto and 9 + gr.a <= (s.g.verificada or 0))))
      f.icono:poner((ta[6] and ta[6] ~= "") and ("Interface\\Icons\\" .. ta[6]) or nil, esSig and "verde" or nil, hecho or fuera)
      local bc = esSig and C.verdeBorde or (esLeg and { 0.45, 0.3, 0.6 }) or { 0.231, 0.212, 0.192 }
      local fc = esSig and C.verdef or (esLeg and { 0.16, 0.12, 0.19 }) or { 0.129, 0.122, 0.11 }
      if f.borde.SetColorTexture then f.borde:SetColorTexture(bc[1], bc[2], bc[3], 1) end
      if f.fondo.SetColorTexture then f.fondo:SetColorTexture(fc[1], fc[2], fc[3], 1) end
      local nvTxt = (gr.b > gr.a) and L("Niveles " .. nvP(gr.a) .. "-" .. nvP(gr.b), "Levels " .. nvP(gr.a) .. "-" .. nvP(gr.b)) or L("Nivel " .. nvP(gr.a), "Level " .. nvP(gr.a))
      if fuera then nvTxt = "Legacy · beta" end
      E.ponerRotulo(f.nv, anotar(nvTxt))
      local nc = esSig and C.verde or (hecho and C.tenue) or (esLeg and LEG) or (verif and C.oro) or C.brasa
      f.nv:SetTextColor(nc[1], nc[2], nc[3], fuera and 0.7 or 1)
      local tc = (hecho or fuera) and C.tenue or C.texto
      f.nombre:SetTextColor(tc[1], tc[2], tc[3], 1)
      poner(f.nombre, gr.n .. "  " .. E.cod.tenue .. gr.rk .. "|r")
      f.ayuda = WowF.libroAyudaTalento and WowF.libroAyudaTalento(p, gr.n, nil)
      local fila, col = math.floor((k - 1) / 3), (k - 1) % 3
      -- La última fila incompleta va centrada (armonía visual, Andy 16-oct)
      local enUltima = #grupos - fila * 3
      local desp = (enUltima < 3) and ((3 - enUltima) * (wp + 8) / 2) or 0
      local h = math.max(46, 7 + alto(f.nv, 12) + 2 + alto(f.nombre, 15) + 4)
      f:SetHeight(math.min(h, 52))
      f:ClearAllPoints(); f:SetPoint("TOPLEFT", o, "TOPLEFT", PAD + desp + col * (wp + 8), -y - fila * 58)
      f:Show(); usadas = k
    end
    for k, f in pairs(o.pasos) do if k > usadas then f:Hide() end end
    y = y + math.ceil(usadas / 3) * 58
    -- El cuadro del enlace solo sale al pulsar "copiar enlace": se pone encima de la cabecera (no ocupa alto; Esc o Intro lo cierran)
    if urls[1] then o.enlace:ClearAllPoints(); o.enlace:SetPoint("TOPLEFT", o, "TOPLEFT", PAD + 6, -10) end
    -- Avisos: sin guia verificada, reparto sin orden, tope de la beta
    local notas = {}
    local limNivel = 9 + s.limite
    local desdeSin
    if not s.g then desdeSin = 10
    elseif s.g.reparto then desdeSin = (s.g.hasta or 0) + 1
    elseif (s.g.verificada or 0) + (leg and tonumber(leg.n) or 0) < limNivel then desdeSin = math.max(10, (s.g.verificada or 0) + (leg and tonumber(leg.n) or 0) + 1) end
    if not s.g then
      table.insert(notas, L("Sin guía verificada para esta rama: se añadirá en próximas actualizaciones, cuando haya una guía de Forever.",
        "No verified guide for this spec yet: it will be added in future updates, when a Forever guide exists."))
    elseif desdeSin and desdeSin <= limNivel then
      table.insert(notas, L("Sin guía verificada desde el nivel " .. math.max(1, desdeSin - EXTRA) .. ": los pasos en naranja son una propuesta del addon. Se actualizará en próximas actualizaciones.",
        "No verified guide from level " .. math.max(1, desdeSin - EXTRA) .. ": orange steps are the addon's suggestion. It will be updated in future updates."))
    end
    if s.cambio > 0 and not s.mixta then
      table.insert(notas, L("Desde el nivel " .. s.cambio .. " (rama final): aún no hay datos de WoW Forever; pendiente de actualizar.", "From level " .. s.cambio .. " (final spec): no WoW Forever data yet; pending update."))
    end
    if s.g and s.g.reparto then
      table.insert(notas, L("La guía solo da el reparto del nivel " .. tostring(s.g.hasta) .. ", no el orden; van en el orden en que la guía los lista.",
        "The guide only gives the level " .. tostring(s.g.hasta) .. " build, not the order; they follow the order the guide lists them."))
    end
    if s.limite < #s.orden and nvP(s.limite) >= s.tope and s.nivel <= s.tope then
      table.insert(notas, L("La beta llega al nivel " .. s.tope .. ": se enseña hasta ahí.", "The beta goes up to level " .. s.tope .. ": shown up to there."))
    end
    if s.notaLegacy then table.insert(notas, 1, s.notaLegacy) end
    if legHasta and s.limite >= legDesde - 1 then
      local rango = legDesde .. "-" .. legHasta
      local tiene = math.max(0, math.min(EXTRA, legHasta - legDesde + 1))
      local cita = (leg.cita and leg.cita ~= "") and (" «" .. leg.cita .. "»") or ""
      local fecha = (leg.fecha and leg.fecha ~= "") and (" (" .. leg.fecha .. ")") or ""
      local es = "LEGACY: los puntos " .. rango .. " (en morado) son los puntos extra de Legacy «Talented» (10 puntos de Legacy, hasta 5 más al nivel 30). "
      local en = "LEGACY: points " .. rango .. " (in purple) are the extra points from Legacy \"Talented\" (10 Legacy points, up to 5 more at level 30). "
      if tiene >= legHasta - legDesde + 1 then es = es .. "Tú los tienes."; en = en .. "You have them."
      elseif tiene > 0 then es = es .. "Tú tienes " .. tiene .. ": los que salen como «Legacy · beta» no te tocan."; en = en .. "You have " .. tiene .. ": the ones marked \"Legacy · beta\" are not for you."
      else es = es .. "Tú no los tienes: no te tocan; tu guía termina en el punto " .. (legDesde - 1) .. "."; en = en .. "You don't have them: skip them; your guide ends at point " .. (legDesde - 1) .. "." end
      es = es .. " Solo existen en la beta: en el juego final no estarán."; en = en .. " They only exist in the beta: they will not be in the final game."
      if (tonumber(leg.eleccion) or 0) > 0 then es = es .. " Los " .. leg.eleccion .. " últimos son a tu elección (la guía da opciones)."; en = en .. " The last " .. leg.eleccion .. " are your choice (the guide gives options)." end
      es = es .. " Según " .. tostring(leg.fuente or "") .. fecha .. ":" .. cita; en = en .. " Per " .. tostring(leg.fuente or "") .. fecha .. ":" .. cita
      table.insert(notas, 1, WowF.yaTraducido(L(es, en)))
    elseif EXTRA > 0 and s.limite > s.tope - 9 then
      table.insert(notas, 1, L("LEGACY: aún no hay datos de WoW Forever sobre dónde poner tus " .. EXTRA .. " puntos extra de Legacy en esta rama (los naranjas son propuesta del addon). Pendiente de actualizar.",
        "LEGACY: there is no WoW Forever data yet on where to spend your " .. EXTRA .. " extra Legacy points in this spec (orange ones are the addon's suggestion). Pending update."))
    end
    if s.avisoOrden then table.insert(notas, 1, s.avisoOrden) end
    if #notas > 0 then
      poner(o.nota, table.concat(notas, "\n"))
      o.nota:ClearAllPoints(); o.nota:SetPoint("TOPLEFT", o, "TOPLEFT", PAD, -y); o.nota:Show()
      y = y + alto(o.nota, 14) + 6
    else o.nota:Hide() end
    o:SetHeight(y + 12)
    return y + 12
  end

  local function llenarRama(p, s)
    local r = vt.rama
    E.ponerRotulo(r.eti, anotar(L("Tu rama", "Your spec")))
    local actual
    for _, x in ipairs(WowF.listaRamas and WowF.listaRamas() or {}) do if x.actual then actual = x end end
    local token = UnitClass and select(2, UnitClass("player")) or ""
    token = type(token) == "string" and token or ""
    local clase = token ~= "" and (token:sub(1, 1) .. token:sub(2):lower()) or ""
    poner(r.h3, WowF.yaTraducido(clase .. " " .. tostring(actual and actual.base or p.rama or "")))
    local sub
    if not actual then sub = L("Rama del plan.", "Plan spec.")
    elseif actual.origen == "elegida" then sub = L("La elegiste tú.", "You chose it.")
    elseif actual.origen == "talentos" then sub = L("Sale de tus talentos.", "Taken from your talents.")
    else sub = L("La recomendada: aún no tienes talentos.", "The recommended one: no talents yet.") end
    if actual and actual.nombre ~= actual.base then sub = sub .. "\n" .. L("Plan: ", "Plan: ") .. WowF.T(actual.nombre) end
    local real = WowF.ramaDeTalentos and WowF.ramaDeTalentos()
    if real and real.choca then sub = sub .. "\n" .. E.cod.brasa .. L("Tus talentos son de " .. real.base .. ".", "Your talents are " .. real.base .. ".") .. "|r" end
    poner(r.sub, WowF.yaTraducido(sub))
    -- "Cambiar de rama" va arriba a la derecha (anclado en crear); debajo del texto, los dos botones de modo en UNA fila
    -- (si no caben a lo ancho, uno debajo del otro)
    textoBoton(r.cambiar, L("Cambiar de rama", "Change spec"), true)
    r.cambiar:SetScript("OnClick", function() WowF.libroRamasAbiertas = true; if WowF.libroRedibujar then WowF.libroRedibujar() end end)
    r.cambiar:Show()
    local y = 14 + alto(r.eti, 12) + 6 + alto(r.h3, 18) + 4 + alto(r.sub, 14) + 10
    y = math.max(y, 10 + 28 + 8)
    local xm, filaUsada = PAD, false
    for i, b in pairs(r.modos) do
      if s.mixta then
        local t = (i == 1) and L("1. Subes con " .. tostring(p.ramaSubir) .. " (hasta el " .. (s.cambio - 1) .. ")", "1. Level as " .. tostring(p.ramaSubir) .. " (to " .. (s.cambio - 1) .. ")")
          or L("2. Al nivel " .. s.cambio .. ": " .. tostring(p.ramaNombre), "2. At level " .. s.cambio .. ": " .. tostring(p.ramaNombre))
        local w = textoBoton(b, WowF.yaTraducido(t), true)
        E.toggle(b, i == s.modo)
        b:SetScript("OnClick", function() modoElegido[s.clave] = i; if WowF.libroRedibujar then WowF.libroRedibujar() end end)
        if filaUsada and xm + w > PAD + r.anchoUtil then xm = PAD; y = y + 34 end
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", r, "TOPLEFT", xm, -y); b:Show()
        xm = xm + w + 8; filaUsada = true
      else b:Hide() end
    end
    if filaUsada then y = y + 28 + 8 end
    if real and real.choca then
      textoBoton(r.real, WowF.yaTraducido(L("Usar mi rama real: ", "Use my real spec: ") .. real.base), true)
      r.real:SetScript("OnClick", function()
        if WowF.elegirRama then WowF.elegirRama(nil) end
        WowF.libroRamasAbiertas = false
        if WowF.panelActualizar then pcall(WowF.panelActualizar) end
        if WowF.libroRedibujar then WowF.libroRedibujar() end
      end)
      r.real:ClearAllPoints(); r.real:SetPoint("TOPLEFT", r, "TOPLEFT", PAD, -y); r.real:Show()
      y = y + 26
    else r.real:Hide() end
    return y + 4
  end

  local function llenarReinicio()
    local x = vt.reinicio
    E.ponerRotulo(x.eti, anotar(L("Reiniciar talentos", "Reset talents")))
    -- Icono + que hace (Andy: "algo que explique bien que hace"); al pasar el raton por el icono, la explicacion larga
    x.icono:poner("Interface\\Icons\\Spell_Holy_Restoration", "oro")
    local que = L("Borra todos tus puntos de talento y te los devuelve para repartirlos otra vez. Se hace hablando con el entrenador de tu clase.",
      "Clears all your talent points and gives them back so you can spend them again. You do it by talking to your class trainer.")
    x.icono.ayuda = WowF.yaTraducido(ORO .. L("Reiniciar talentos", "Reset talents") .. "|r\n"
      .. L("Habla con el entrenador de tu clase y elige reiniciar tus talentos: se quitan todos los puntos que pusiste y los recuperas para repartirlos de nuevo (por ejemplo, al cambiar de rama).",
        "Talk to your class trainer and choose to reset your talents: every point you spent is removed and you get them back to spend again (for example, when you change spec).")
      .. "\n\n" .. L("Precio: desde 1 plata. Sube si reinicias seguido y baja un paso cada hora.", "Cost: from 1 silver. It goes up if you reset often and drops one step every hour."))
    local function altoTarjeta()
      local y = 14 + alto(x.eti, 12) + 6 + alto(x.h3, 18) + 6 + alto(x.sub, 14) + 14
      return math.max(y, 14 + 40 + 14)
    end
    if not WowF.costoReinicio then
      poner(x.h3, L("Reiniciar talentos", "Reset talents"))
      poner(x.sub, WowF.yaTraducido(que .. "\n" .. L("aún no hay datos de WoW Forever; pendiente de actualizar", "no WoW Forever data yet; pending update")))
      x.ir:Hide()
      return altoTarjeta()
    end
    local ok, c = pcall(WowF.costoReinicio)
    if not ok or type(c) ~= "table" then c = {} end
    if c.visto and c.proximo and WowF.dinero then poner(x.h3, WowF.yaTraducido(L("Próximo: ", "Next: ") .. WowF.dinero(c.proximo)))
    else poner(x.h3, L("Desde 1 plata", "From 1 silver")) end
    local sub = que .. " " .. L("Sube si reinicias seguido y baja un paso cada hora.", "It goes up if you reset often and drops one step every hour.")
    if c.visto then sub = sub .. " " .. L("(lo dijo el entrenador)", "(the trainer said so)") end
    if (c.veces or 0) > 0 then sub = sub .. "\n" .. L("Lo llevas " .. c.veces .. (c.veces == 1 and " vez." or " veces."), "Done " .. c.veces .. (c.veces == 1 and " time." or " times.")) end
    poner(x.sub, WowF.yaTraducido(sub))
    textoBoton(x.ir, L("Ver el entrenador en el mapa", "See the trainer on the map"), true)
    x.ir:SetScript("OnClick", function() if WowF.irAReiniciar then WowF.irAReiniciar() end end)
    x.ir:Show()
    return altoTarjeta()
  end

  function WowF.vistaTalentos(p, hoja, ancho, ctx)
    local s = calcular(p)
    if not s then return nil end
    if not vt then crear(hoja, ancho or 890) end
    textos = {}
    local visible = (ctx and ctx.altoVisible) or 668
    local filasMax, casEstado = llenarArbol(p, s)
    -- Estado para las pruebas (casillas de la vista nueva; el diagrama viejo guarda las suyas aparte)
    WowF.vistaTalentosEstado = { pestana = s.pest, modo = s.modo, mixta = s.mixta, limite = s.limite, puestos = s.puestos, siguiente = s.sig, casillas = casEstado }
    local altoS = llenarSiguiente(p, s) or 104
    local altoO = llenarOrden(p, s)
    local altoR = llenarRama(p, s)
    local altoX = llenarReinicio()
    -- Alturas: el arbol llena el alto visible (o lo que pidan sus filas); a la derecha, las dos de abajo llenan lo que sobra
    local a = vt.arbol
    local altoLienzo = TY + (filasMax - 1) * PY + T + 26
    local altoArbol = math.max(visible, 50 + altoLienzo + 40)
    a.lienzo:SetHeight(altoArbol - 50 - 40)
    a:SetHeight(altoArbol)
    local xley = PAD
    for _, cu in ipairs(a.ley) do
      cu:ClearAllPoints(); cu:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", xley, 17)
      poner(cu.t, cu.texto)
      local w = cu.t.GetStringWidth and tonumber(cu.t:GetStringWidth()) or 60
      xley = xley + 15 + ((type(w) == "number" and w > 0) and w or 60) + 14
    end
    -- Derecha (una debajo de otra): siguiente 104 + orden + Tu rama + Reiniciar; la ultima estira hasta el pie del arbol
    vt.rama:SetHeight(altoR)
    local arriba = altoS + GAP + altoO + GAP + altoR + GAP
    altoX = math.max(altoX, altoArbol - arriba)
    vt.reinicio:SetHeight(altoX)
    WowF.vistaTalentosAltoDerecha = arriba + altoX
    local total = math.max(altoArbol, arriba + altoX)
    vt:SetHeight(total)
    for _, b in pairs(a.seg) do if b:IsShown() then anotar(b:GetText()) end end
    local copia = {}
    for i, t in ipairs(textos) do copia[i] = t end
    return vt, total, copia
  end
end
