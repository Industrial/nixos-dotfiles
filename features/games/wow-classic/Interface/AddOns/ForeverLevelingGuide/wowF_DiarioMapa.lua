-- wowF DiarioMapa: pestana "Mapa" de la ficha de cada mazmorra del Diario, estilo "Mesa de guerra" (12-oct, Andy eligio la C).
-- Mapas PROPIOS (dibujados por herramientas/generar-texturas-mapa.mjs; datos en wowF_MapasMazmorras_Datos.lua): la ubicacion de los
-- jefes sale de las guias de WoW Forever de Icy Veins, el dibujo es nuestro. Cada jefe: su retrato en un medallon + gallardete rojo con
-- el nombre (sin numeros). Arrastrar = mover; rueda o +/- = acercar; "Centrar". Debajo: tarjeta "Siguiente jefe" (Ver su botin / Ir a el),
-- franja "La ruta", pistas de jefes escondidos (wowF_MapasPistas_Datos.lua, solo guias de WoW Forever; sin dato = aviso) y lo que falta
-- por ubicar. Jefes derrotados (ENCOUNTER_END con exito) quedan en gris ~2 h. /wowf mapa abre una ventana grande con lo mismo.
-- Todo en la tabla M (tope de 200 locales). Textos con L(es, en); nombres del juego en ingles.

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local M = { estado = {}, vistas = {} }
M.RAIZ = "Interface\\AddOns\\ForeverLevelingGuide\\Texturas\\"
M.UI = M.RAIZ .. "Mapa\\"
M.ICONO_JEFE = 521744
M.FONDO = { 11 / 255, 8 / 255, 6 / 255 }
M.TXT = { gris = "|cffa39a8c", oro = "|cffd8b468", naranja = "|cffff9933", verde = "|cff7cc35a", morado = "|cffc080ff", texto = "|cffefe7da", rojo = "|cffe06048" }
M.MARCA = { e = "E", r = "R", p = "?", o = "i", j = "J" }
M.TEX_MARCA = { e = "entrada", r = "raro", p = "posible", o = "objeto" }
M.ZOOM_MAX = 2.5
M.VIGENCIA = 2 * 3600 -- un jefe derrotado cuenta como muerto 2 h

function M.E() return WowF.estilo end
function M.esVentana(c) return c ~= nil and (c == M.grande or c == M.mini) end
function M.num(v) return tonumber(v) or 0 end
function M.es(par) if type(par) ~= "table" then return "" end return L(par[1] or par.es or "", par[2] or par.en or par[1] or par.es or "") end

-- ===================== Jefes derrotados =====================
function M.instanciaActual()
  if not IsInInstance or not GetInstanceInfo then return nil end
  local ok, dentro = pcall(IsInInstance)
  if not ok or dentro ~= true then return nil end
  local ok2, id = pcall(function() return (select(8, GetInstanceInfo())) end)
  return ok2 and tonumber(id) or nil
end
function M.muertos(id)
  local db = type(WowFExportarDB) == "table" and WowFExportarDB.mapaMuertos
  local r = type(db) == "table" and id and db[id]
  if type(r) ~= "table" or type(r.n) ~= "table" then return {} end
  local ahora = (time and time()) or 0
  if M.num(r.t) + M.VIGENCIA < ahora then return {} end
  return r.n
end
function M.anotarMuerto(encuentro, nombre)
  local id = M.instanciaActual()
  if not id then return end
  if type(WowFExportarDB) ~= "table" then WowFExportarDB = {} end
  WowFExportarDB.mapaMuertos = WowFExportarDB.mapaMuertos or {}
  local ahora = (time and time()) or 0
  local r = WowFExportarDB.mapaMuertos[id]
  if type(r) ~= "table" or M.num(r.t) + M.VIGENCIA < ahora then r = { n = {} } end
  r.t = ahora
  local e = WowFEncuentros and WowFEncuentros[tonumber(encuentro) or -1]
  if type(e) == "table" and e[1] then r.n[e[1]] = true end
  if type(nombre) == "string" and nombre ~= "" then r.n[nombre] = true end
  WowFExportarDB.mapaMuertos[id] = r
end

-- ===================== Una vista (Diario o ventana grande) =====================
-- V = { padre, capa, vista, lienzo, lineas, img, pines, marcas, textos, botones, retratos... }
function M.vistaDe(contenedor)
  local V = M.vistas[contenedor]
  if V then return V end
  V = { padre = contenedor, pines = {}, np = 0, marcas = {}, nm = 0, textos = {}, ntx = 0, botones = {}, nb = 0, rayas = {}, nr = 0,
        ox = 0, oy = 0, zoom = 1 }
  M.vistas[contenedor] = V
  V.capa = CreateFrame("Frame", nil, contenedor)
  V.capa:SetAllPoints(contenedor)
  pcall(function() V.capa:SetFrameLevel(M.num(contenedor:GetFrameLevel()) + 5) end)
  -- Ventana del mapa: recorta lo que se sale; fondo del color del dibujo y marco de oro viejo
  V.borde = V.capa:CreateTexture(nil, "BACKGROUND", nil, 1)
  if V.borde.SetColorTexture then V.borde:SetColorTexture(0.55, 0.42, 0.18, 1) end
  V.vista = CreateFrame("Frame", nil, V.capa)
  pcall(function() V.vista:SetClipsChildren(true) end)
  pcall(function() V.vista:SetFrameLevel(M.num(V.capa:GetFrameLevel()) + 1) end)
  V.fondo = V.vista:CreateTexture(nil, "BACKGROUND", nil, 1)
  V.fondo:SetAllPoints(V.vista)
  if V.fondo.SetColorTexture then V.fondo:SetColorTexture(M.FONDO[1], M.FONDO[2], M.FONDO[3], 1) end
  V.lienzo = CreateFrame("Frame", nil, V.vista)
  pcall(function() V.lienzo:SetFrameLevel(M.num(V.vista:GetFrameLevel()) + 1) end)
  V.img = V.lienzo:CreateTexture(nil, "ARTWORK", nil, 1)
  V.img:SetAllPoints(V.lienzo)
  V.lineas = CreateFrame("Frame", nil, V.lienzo)
  V.lineas:SetAllPoints(V.lienzo)
  pcall(function() V.lineas:SetFrameLevel(M.num(V.lienzo:GetFrameLevel()) + 2) end)
  -- Raton: arrastrar mueve, la rueda acerca alrededor del cursor
  V.vista:EnableMouse(true)
  pcall(function() V.vista:EnableMouseWheel(true) end)
  V.vista:SetScript("OnMouseDown", function(_, boton)
    if boton ~= "LeftButton" then return end
    local cx, cy = M.cursor(V)
    if cx then V.arrastre = { cx = cx, cy = cy, ox = V.ox, oy = V.oy } end
  end)
  V.vista:SetScript("OnMouseUp", function() V.arrastre = nil end)
  V.vista:SetScript("OnHide", function() V.arrastre = nil end)
  V.vista:SetScript("OnUpdate", function()
    local a = V.arrastre
    if not a then return end
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then V.arrastre = nil; return end
    local cx, cy = M.cursor(V)
    if not cx then return end
    V.ox, V.oy = a.ox + (cx - a.cx), a.oy + (cy - a.cy)
    M.aplicar(V, true)
  end)
  V.vista:SetScript("OnMouseWheel", function(_, delta)
    local cx, cy = M.cursor(V)
    M.zoomA(V, V.zoom * ((M.num(delta) > 0) and 1.25 or 0.8), cx, cy)
  end)
  -- Botones sobre el mapa: + / - / Centrar
  V.mas = M.botonMapa(V, "+", function() M.zoomA(V, V.zoom * 1.25) end)
  V.menos = M.botonMapa(V, "-", function() M.zoomA(V, V.zoom * 0.8) end)
  V.centrar = M.botonMapa(V, L("Centrar", "Center"), function() M.centrarTodo(V) end)
  -- 4.28: "Sacar el mapa" (ventana pequena movible) y "?" (como funciona el mapa)
  V.sacar = M.botonMapa(V, L("Sacar el mapa", "Pop out map"), function() WowF.sacarMapa(V.m) end)
  V.sacar:SetScript("OnEnter", M.ayuda); V.sacar:SetScript("OnLeave", M.sinAyuda)
  V.ayudaB = M.botonMapa(V, "?", function(self) M.ayuda(self) end)
  V.ayudaB:SetScript("OnEnter", M.ayuda); V.ayudaB:SetScript("OnLeave", M.sinAyuda)
  return V
end

-- Texto del "?": como funciona el mapa
function M.textosAyuda()
  return { titulo = L("Cómo funciona el mapa", "How the map works"), lineas = {
    L("Cada medallón es un jefe, con su retrato y su nombre. El que brilla en naranja es el siguiente que te toca.",
      "Each medallion is a boss, with its portrait and its name. The one glowing orange is the next one to do."),
    L("La lista de la esquina es el orden recomendado (1, 2, 3...). Clic en un nombre = el mapa va hacia ese jefe. Clic en el título = plegar la lista.",
      "The list in the corner is the recommended order (1, 2, 3...). Click a name = the map moves to that boss. Click the title = fold the list."),
    L("La raya naranja es el camino de un jefe al siguiente; lo ya hecho queda en gris.",
      "The orange line is the path from one boss to the next; what is done turns grey."),
    L("Las marcas pequeñas son la entrada, los raros (no siempre aparecen), los sitios posibles de un jefe que cambia de lugar y los objetos o personajes que señala la guía.",
      "The small marks are the entrance, rares (they do not always spawn), the possible spots of a boss that moves around and the objects or characters the guide points out."),
    L("Pasa el ratón por un jefe: en qué sala está, cómo llegar y qué hacer. Clic en el jefe = su botín.",
      "Hover a boss: which room it is in, how to get there and what to do. Click the boss = its loot."),
    L("Arrastra para mover el mapa, rueda o +/- para acercar y Centrar para verlo entero.",
      "Drag to move the map, wheel or +/- to zoom and Center to see all of it."),
    L("Al matar a un jefe se marca solo como derrotado (durante 2 horas) y el siguiente pasa a brillar.",
      "When you kill a boss it is marked as defeated on its own (for 2 hours) and the next one starts glowing."),
    L("Sacar el mapa: lo abre en una ventana pequeña que puedes arrastrar a una esquina y agrandar desde su esquina de abajo; se queda donde la dejes, también al volver a entrar al juego.",
      "Pop out map: opens it in a small window you can drag to a corner and resize from its bottom corner; it stays where you leave it, also when you log back in."),
    M.TXT.gris .. L("Ubicación de los jefes: guías de WoW Forever de Icy Veins.", "Boss locations: Icy Veins WoW Forever guides.") .. "|r",
  } }
end

-- Centra el mapa en un jefe por su nombre
function M.centrarJefe(V, n)
  local d = V.datos
  if not d then return end
  for _, p in ipairs(d.p) do if p[1] == n then M.centrarEn(V, p[3], p[4], 1.8); break end end
end

-- Orden de los jefes en la esquina del mapa: "1. X", "2. Y"...; derrotados en gris con visto, el siguiente en naranja
function M.pintarOrden(V, d)
  local orden = d and d.orden or {}
  local F = V.ordenF
  if not F then
    F = CreateFrame("Frame", nil, V.vista)
    pcall(function() F:SetFrameLevel(M.num(V.vista:GetFrameLevel()) + 25) end)
    F.borde = F:CreateTexture(nil, "BACKGROUND", nil, 1); F.borde:SetAllPoints()
    if F.borde.SetColorTexture then F.borde:SetColorTexture(0.55, 0.42, 0.18, 0.85) end
    F.fondo = F:CreateTexture(nil, "BACKGROUND", nil, 2); F.fondo:SetPoint("TOPLEFT", 1, -1); F.fondo:SetPoint("BOTTOMRIGHT", -1, 1)
    if F.fondo.SetColorTexture then F.fondo:SetColorTexture(0.05, 0.035, 0.025, 0.8) end
    F:EnableMouse(true)
    F.cab = CreateFrame("Button", nil, F)
    F.cab:SetPoint("TOPLEFT", F, "TOPLEFT", 0, 0); F.cab:SetPoint("TOPRIGHT", F, "TOPRIGHT", 0, 0); F.cab:SetHeight(18)
    F.cab.txt = F.cab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    F.cab.txt:SetPoint("LEFT", F.cab, "LEFT", 8, 0)
    local E = M.E()
    if E and E.letra then pcall(E.letra, F.cab.txt, "marca", 10, "OUTLINE") end
    F.cab:SetScript("OnClick", function()
      if type(WowFExportarDB) ~= "table" then WowFExportarDB = {} end
      WowFExportarDB.mapaOrdenCerrado = not (WowFExportarDB.mapaOrdenCerrado == true)
      M.pintarOrden(V, V.datos)
    end)
    F.lin = {}
    V.ordenF = F
  end
  if #orden == 0 then F:Hide(); return end
  local cerrado = type(WowFExportarDB) == "table" and WowFExportarDB.mapaOrdenCerrado == true
  F.cab.txt:SetText(M.TXT.oro .. L("Orden de los jefes", "Boss order") .. "|r" .. (cerrado and (M.TXT.gris .. " (" .. #orden .. ")|r") or ""))
  local maxw = M.num(F.cab.txt.GetStringWidth and F.cab.txt:GetStringWidth()) + 20
  local vis = {}
  for k, n in ipairs(orden) do
    local b = F.lin[k]
    if not b then
      b = CreateFrame("Button", nil, F)
      b:SetHeight(15)
      b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      b.txt:SetPoint("LEFT", b, "LEFT", 8, 0)
      if b.txt.SetWordWrap then b.txt:SetWordWrap(false) end
      if b.txt.SetJustifyH then b.txt:SetJustifyH("LEFT") end
      local E = M.E()
      if E and E.letra then pcall(E.letra, b.txt, "cuerpo", 10, "OUTLINE") end
      b:SetScript("OnEnter", M.ayuda); b:SetScript("OnLeave", M.sinAyuda)
      F.lin[k] = b
    end
    if cerrado then b:Hide() else
      local muerto, sig = V.muertos and V.muertos[n], n == V.siguiente
      local s = k .. ". " .. n
      if muerto then b.txt:SetText(M.TXT.gris .. s .. "|r |TInterface\\RaidFrame\\ReadyCheck-Ready:12|t")
      elseif sig then b.txt:SetText("|cffffb84d" .. s .. " «|r")
      else b.txt:SetText(M.TXT.texto .. s .. "|r") end
      maxw = math.max(maxw, M.num(b.txt.GetStringWidth and b.txt:GetStringWidth()) + 20)
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", F, "TOPLEFT", 0, -(18 + (k - 1) * 15))
      local sala = d.salaDe and d.salaDe[n] and M.es(d.salaDe[n])
      local lineas = {}
      if sala and sala ~= "" then table.insert(lineas, M.TXT.gris .. sala .. "|r") end
      if muerto then table.insert(lineas, M.TXT.verde .. L("Ya lo derrotaste", "Already defeated") .. "|r")
      elseif sig then table.insert(lineas, "|cffffb84d" .. L("Es el siguiente", "It is the next one") .. "|r") end
      table.insert(lineas, M.TXT.verde .. L("Clic: el mapa va hacia él", "Click: the map moves to it") .. "|r")
      b.info = { titulo = s, lineas = lineas }
      b:SetScript("OnClick", function() M.centrarJefe(V, n) end)
      b:Show()
      table.insert(vis, s .. (muerto and " [x]" or "") .. (sig and " [>]" or ""))
    end
  end
  for k = #orden + 1, #F.lin do F.lin[k]:Hide() end
  local w = math.floor(math.min(maxw, math.max(140, V.vw * 0.55)))
  for k = 1, #orden do F.lin[k]:SetWidth(w); if F.lin[k].txt.SetWidth then F.lin[k].txt:SetWidth(w - 12) end end
  F.cab.info = { titulo = L("Orden de los jefes", "Boss order"), lineas = { L("Clic: plegar o desplegar la lista", "Click: fold or unfold the list") } }
  F.cab:SetScript("OnEnter", M.ayuda); F.cab:SetScript("OnLeave", M.sinAyuda)
  F:SetSize(w, 18 + (cerrado and 0 or #orden * 15) + 4)
  F:ClearAllPoints(); F:SetPoint("TOPLEFT", V.vista, "TOPLEFT", 6, -6); F:Show()
  V.estado.orden = vis
  V.estado.ordenCerrado = cerrado
end

function M.botonMapa(V, txt, fn)
  local b = CreateFrame("Button", nil, V.vista, "UIPanelButtonTemplate")
  pcall(function() b:SetFrameLevel(M.num(V.vista:GetFrameLevel()) + 30) end)
  b:SetText(txt)
  local E = M.E()
  if E and E.boton then pcall(E.boton, b, "cuero", 12, true) end
  b:SetHeight(24)
  local w = 26
  if #txt > 1 then
    local fs = b.GetFontString and b:GetFontString()
    w = math.max(64, math.floor(M.num(fs and fs.GetStringWidth and fs:GetStringWidth()) + 24))
  end
  b:SetWidth(w)
  b:SetScript("OnClick", fn)
  b.wowfTexto = txt
  return b
end

-- Cursor en coordenadas de la vista (x a la derecha, y hacia abajo)
function M.cursor(V)
  if not GetCursorPosition then return nil end
  local ok, x, y, esc, izq, arriba = pcall(function()
    local cx, cy = GetCursorPosition()
    return cx, cy, V.vista:GetEffectiveScale(), V.vista:GetLeft(), V.vista:GetTop()
  end)
  if not ok or not x or not esc or not izq or not arriba then return nil end
  esc = M.num(esc); if esc <= 0 then esc = 1 end
  return M.num(x) / esc - M.num(izq), M.num(arriba) - M.num(y) / esc
end

-- Escala: "ajuste" = el mapa entero cabe en la vista; zoom 1 .. ZOOM_MAX sobre eso
function M.medidas(V)
  local d = V.datos
  local ajuste = V.ajuste or math.min(V.vw / d.iw, V.vh / d.ih)
  local s = ajuste * V.zoom
  return d.iw * s, d.ih * s
end
-- 12-oct: caja de TODO lo dibujado (mapa + medallones + gallardetes + etiquetas) para un lienzo w x h; antes solo contaba el mapa
-- y los nombres de los jefes del borde se cortaban (Andy: "se cortan algunas cosas a la derecha")
function M.caja(V, w, h)
  local l, r, t, b = 0, w, 0, h
  local function pon(x, y, hw, up, dn)
    l = math.min(l, x * w - hw); r = math.max(r, x * w + hw)
    t = math.min(t, y * h - up); b = math.max(b, y * h + dn)
  end
  for i = 1, V.np do local p = V.pines[i]; if p.px then pon(p.px, p.py, p.hw or 31, p.up or 31, p.dn or 64) end end
  for i = 1, V.nm do local p = V.marcas[i]; if p.px then pon(p.px, p.py, p.hw or 13, p.up or 13, p.dn or 26) end end
  return l, r, t, b
end
-- Escala a la que cabe la caja entera con un respiro de 8 px por lado (busqueda binaria: la caja crece con la escala)
function M.calcAjuste(V)
  local d = V.datos
  local alto = math.min(V.vw / d.iw, V.vh / d.ih)
  local function cabe(s)
    local l, r, t, b = M.caja(V, d.iw * s, d.ih * s)
    return (r - l) <= V.vw - 16 and (b - t) <= V.vh - 16
  end
  if cabe(alto) then V.ajuste = alto; return end
  local lo, hi = alto * 0.35, alto
  for _ = 1, 18 do local mid = (lo + hi) / 2; if cabe(mid) then lo = mid else hi = mid end end
  V.ajuste = lo
end
function M.limitar(V)
  local w, h = M.medidas(V)
  local l, r, t, b = M.caja(V, w, h)
  local cw, ch = r - l, b - t
  if cw <= V.vw then V.ox = (V.vw - cw) / 2 - l else V.ox = math.max(V.vw - r, math.min(-l, V.ox)) end
  if ch <= V.vh then V.oy = (V.vh - ch) / 2 - t else V.oy = math.max(V.vh - b, math.min(-t, V.oy)) end
  return w, h
end
function M.zoomA(V, z, cx, cy)
  if not V.datos then return end
  z = math.max(1, math.min(M.ZOOM_MAX, z or 1))
  cx, cy = cx or V.vw / 2, cy or V.vh / 2
  local w, h = M.medidas(V)
  local u, v = (cx - V.ox) / w, (cy - V.oy) / h
  V.zoom = z
  local w2, h2 = M.medidas(V)
  V.ox, V.oy = cx - u * w2, cy - v * h2
  M.aplicar(V)
end
function M.centrarTodo(V) V.zoom = 1; M.aplicar(V) end
-- Acerca y pone un punto (0..1 del mapa) en el centro de la vista
function M.centrarEn(V, px, py, z)
  if not V.datos then return end
  V.zoom = math.max(1, math.min(M.ZOOM_MAX, z or math.max(V.zoom, 1.6)))
  local w, h = M.medidas(V)
  V.ox, V.oy = V.vw / 2 - px * w, V.vh / 2 - py * h
  M.aplicar(V)
end

-- Coloca lienzo, pines y rayas segun ox/oy/zoom. "rapido" = solo mover (arrastre): las rayas van pegadas al lienzo
function M.aplicar(V, rapido)
  if not V.datos then return end
  local w, h = M.limitar(V)
  V.lienzo:ClearAllPoints()
  V.lienzo:SetPoint("TOPLEFT", V.vista, "TOPLEFT", V.ox, -V.oy)
  V.lienzo:SetSize(math.max(1, w), math.max(1, h))
  V.w, V.h = w, h
  if rapido and V.medidoW == w then return end
  V.medidoW = w
  for i = 1, V.np do local b = V.pines[i]; b:ClearAllPoints(); b:SetPoint("CENTER", V.lienzo, "TOPLEFT", b.px * w, -b.py * h) end
  for i = 1, V.nm do local b = V.marcas[i]; b:ClearAllPoints(); b:SetPoint("CENTER", V.lienzo, "TOPLEFT", b.px * w, -b.py * h) end
  M.pintarRayas(V)
end

-- ===================== Rayas de la ruta =====================
function M.raya(V)
  if not V.lineas.CreateLine then return nil end
  V.nr = V.nr + 1
  local r = V.rayas[V.nr]
  if not r then
    r = { abajo = V.lineas:CreateLine(nil, "ARTWORK", nil, 1), arriba = V.lineas:CreateLine(nil, "ARTWORK", nil, 2) }
    for _, l in pairs(r) do if l.SetColorTexture then l:SetColorTexture(1, 1, 1, 1) end end
    V.rayas[V.nr] = r
  end
  return r
end
function M.soltarRayas(V)
  for i = 1, #V.rayas do local r = V.rayas[i]; r.abajo:Hide(); r.arriba:Hide() end
  V.nr = 0
end
function M.pintarRayas(V)
  M.soltarRayas(V)
  local d = V.datos
  if not d or type(d.tramos) ~= "table" or not V.w then return end
  local w, h = V.w, V.h
  local grosor = math.max(2, math.min(5, 2.5 * V.zoom))
  for k, t in ipairs(d.tramos) do
    local jefe = d.orden and d.orden[k]
    local hecho = jefe and V.muertos and V.muertos[jefe]
    local siguiente = jefe and jefe == V.siguiente
    local c = hecho and { 0.45, 0.42, 0.38, 0.55 } or (siguiente and { 1, 0.55, 0.16, 1 } or { 0.85, 0.5, 0.2, 0.6 })
    for i = 1, #t - 3, 2 do
      local r = M.raya(V)
      if not r then return end
      for capa, l in pairs(r) do
        l:SetStartPoint("TOPLEFT", V.lienzo, t[i] * w, -t[i + 1] * h)
        l:SetEndPoint("TOPLEFT", V.lienzo, t[i + 2] * w, -t[i + 3] * h)
        if capa == "abajo" then l:SetThickness(grosor + 3); l:SetVertexColor(0, 0, 0, 0.6)
        else l:SetThickness(grosor); l:SetVertexColor(c[1], c[2], c[3], c[4]) end
        l:Show()
      end
    end
  end
end

-- ===================== Pines =====================
function M.ayuda(self)
  if not GameTooltip or not self.info then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(self.info.titulo, 1, 0.82, 0.2, 1, true)
  for _, s in ipairs(self.info.lineas or {}) do GameTooltip:AddLine(s, 0.94, 0.9, 0.85, true) end
  GameTooltip:Show()
end
function M.sinAyuda() if GameTooltip then GameTooltip:Hide() end end

-- Jefe: brillo (late en el siguiente) + retrato bajo el medallon + gallardete rojo con el nombre y la sala
function M.pinJefe(V)
  V.np = V.np + 1
  local b = V.pines[V.np]
  if not b then
    b = CreateFrame("Button", nil, V.lienzo)
    pcall(function() b:SetFrameLevel(M.num(V.lienzo:GetFrameLevel()) + 10) end)
    b:SetSize(56, 56)
    b.brillo = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.brillo:SetPoint("CENTER"); b.brillo:SetSize(96, 96); b.brillo:SetTexture(M.UI .. "brillo")
    pcall(b.brillo.SetBlendMode, b.brillo, "ADD")
    if WowF.marcoRetrato then
      b.ret = WowF.marcoRetrato(b, 40)
    else
      b.ret = CreateFrame("Frame", nil, b); b.ret:SetSize(40, 40)
      b.ret.tex = b.ret:CreateTexture(nil, "ARTWORK"); b.ret.tex:SetAllPoints()
      function b.ret:poner(o) self.tex:SetTexture(o and o.icono or M.ICONO_JEFE) end
    end
    b.ret:SetPoint("CENTER")
    pcall(function() b.ret:SetFrameLevel(M.num(b:GetFrameLevel()) + 1) end)
    b.tapa = CreateFrame("Frame", nil, b)
    b.tapa:SetAllPoints(b)
    pcall(function() b.tapa:SetFrameLevel(M.num(b:GetFrameLevel()) + 3) end)
    b.medallon = b.tapa:CreateTexture(nil, "OVERLAY", nil, 1)
    b.medallon:SetPoint("CENTER"); b.medallon:SetSize(62, 62); b.medallon:SetTexture(M.UI .. "medallon")
    -- Gallardete en 3 piezas (bordes fijos, centro estirado); la tela va de y 6 a 45 de 64
    b.gal = CreateFrame("Frame", nil, b.tapa)
    b.gal:SetHeight(32); b.gal:SetPoint("TOP", b, "BOTTOM", 0, 6)
    b.galI = b.gal:CreateTexture(nil, "ARTWORK", nil, 1); b.galI:SetTexture(M.UI .. "gallardete")
    b.galI:SetPoint("TOPLEFT"); b.galI:SetSize(20, 32); b.galI:SetTexCoord(0, 40 / 256, 0, 1)
    b.galD = b.gal:CreateTexture(nil, "ARTWORK", nil, 1); b.galD:SetTexture(M.UI .. "gallardete")
    b.galD:SetPoint("TOPRIGHT"); b.galD:SetSize(20, 32); b.galD:SetTexCoord(216 / 256, 1, 0, 1)
    b.galC = b.gal:CreateTexture(nil, "ARTWORK", nil, 1); b.galC:SetTexture(M.UI .. "gallardete")
    b.galC:SetPoint("TOPLEFT", b.galI, "TOPRIGHT"); b.galC:SetPoint("BOTTOMRIGHT", b.galD, "BOTTOMLEFT"); b.galC:SetTexCoord(40 / 256, 216 / 256, 0, 1)
    b.nombre = b.gal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.nombre:SetPoint("CENTER", b.gal, "TOP", 0, -12.5)
    b.sub = b.tapa:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.sub:SetPoint("TOP", b.gal, "BOTTOM", 0, 6)
    local E = M.E()
    if E and E.letra then pcall(E.letra, b.nombre, "marca", 10, "OUTLINE"); pcall(E.letra, b.sub, "cuerpo", 9, "OUTLINE") end
    -- El brillo late solo en el siguiente jefe
    b:SetScript("OnUpdate", function(self)
      if not self.late or not GetTime then return end
      local a = 0.55 + 0.35 * math.sin(GetTime() * 3)
      self.brillo:SetAlpha(a)
    end)
    b:SetScript("OnEnter", function(self) M.ayuda(self); if self.medallon.SetVertexColor then self.medallon:SetVertexColor(1, 1, 0.8) end end)
    b:SetScript("OnLeave", function(self) M.sinAyuda(); if self.medallon.SetVertexColor then self.medallon:SetVertexColor(1, 1, 1) end end)
    V.pines[V.np] = b
  end
  b:Show()
  return b
end

-- Marca pequena: entrada, raro, sitio posible, objeto o NPC
function M.marca(V)
  V.nm = V.nm + 1
  local b = V.marcas[V.nm]
  if not b then
    b = CreateFrame("Button", nil, V.lienzo)
    pcall(function() b:SetFrameLevel(M.num(V.lienzo:GetFrameLevel()) + 8) end)
    b:SetSize(26, 26)
    b.tex = b:CreateTexture(nil, "ARTWORK", nil, 1); b.tex:SetAllPoints()
    b.etiqueta = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.etiqueta:SetPoint("TOP", b, "BOTTOM", 0, -1)
    local E = M.E()
    if E and E.letra then pcall(E.letra, b.etiqueta, "cuerpo", 9, "OUTLINE") end
    b:SetScript("OnEnter", M.ayuda)
    b:SetScript("OnLeave", M.sinAyuda)
    V.marcas[V.nm] = b
  end
  b:Show()
  return b
end

-- ===================== Textos y botones debajo del mapa =====================
function M.texto(V, x, y, ancho, s, tipo, tam, color, padre)
  V.ntx = V.ntx + 1
  local f = V.textos[V.ntx]
  if not f then
    f = V.capa:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if f.SetWordWrap then f:SetWordWrap(true) end
    V.textos[V.ntx] = f
  end
  local E = M.E()
  if E then
    if tipo == "titulo" then pcall(E.titulo, V.capa, f, tam or 14)
    elseif tipo == "etiqueta" then pcall(E.etiqueta, V.capa, f, color or E.color.brasa, tam or 9)
    elseif tipo == "sub" then pcall(E.sub, V.capa, f, tam or 10)
    else pcall(E.cuerpo, V.capa, f, tam or 11, color) end
  end
  f:ClearAllPoints(); f:SetPoint("TOPLEFT", padre or V.padre, "TOPLEFT", x, -y); f:SetWidth(ancho)
  if f.SetJustifyH then f:SetJustifyH("LEFT") end
  f:SetText((tipo == "etiqueta" and E and E.mayus) and E.mayus(s) or s)
  f:Show()
  local alto = M.num(f.GetStringHeight and f:GetStringHeight())
  if alto <= 0 then alto = (tam or 11) + 3 end
  return f, alto
end
function M.boton(V, x, y, txt, tipo, fn)
  V.nb = V.nb + 1
  local b = V.botones[V.nb]
  if not b then
    b = CreateFrame("Button", nil, V.capa, "UIPanelButtonTemplate")
    pcall(function() b:SetFrameLevel(M.num(V.capa:GetFrameLevel()) + 6) end)
    V.botones[V.nb] = b
  end
  b:SetText(txt)
  b.wowfTexto = txt
  local E = M.E()
  if E and E.boton then pcall(E.boton, b, tipo or "cuero", 12, true) end
  b:SetHeight(26)
  local fs = b.GetFontString and b:GetFontString()
  local w = math.max(70, math.floor(M.num(fs and fs.GetStringWidth and fs:GetStringWidth()) + 28))
  b:SetWidth(w)
  b:ClearAllPoints(); b:SetPoint("TOPLEFT", V.padre, "TOPLEFT", x, -y)
  b:SetScript("OnClick", fn)
  b:Show()
  return b, w
end
function M.panel(V)
  if not V.tarjeta then
    V.tarjeta = CreateFrame("Frame", nil, V.capa)
    pcall(function() V.tarjeta:SetFrameLevel(M.num(V.capa:GetFrameLevel()) + 1) end)
    V.tarjeta.borde = V.tarjeta:CreateTexture(nil, "BACKGROUND", nil, 1); V.tarjeta.borde:SetAllPoints()
    if V.tarjeta.borde.SetColorTexture then V.tarjeta.borde:SetColorTexture(0.55, 0.42, 0.18, 0.9) end
    V.tarjeta.fondo = V.tarjeta:CreateTexture(nil, "BACKGROUND", nil, 2)
    V.tarjeta.fondo:SetPoint("TOPLEFT", 1, -1); V.tarjeta.fondo:SetPoint("BOTTOMRIGHT", -1, 1)
    if V.tarjeta.fondo.SetColorTexture then V.tarjeta.fondo:SetColorTexture(0.133, 0.082, 0.055, 0.86) end
    V.tarjeta.acento = V.tarjeta:CreateTexture(nil, "BORDER", nil, 1)
    V.tarjeta.acento:SetPoint("TOPLEFT", 1, -1); V.tarjeta.acento:SetPoint("BOTTOMLEFT", 1, 1); V.tarjeta.acento:SetWidth(3)
    if V.tarjeta.acento.SetColorTexture then V.tarjeta.acento:SetColorTexture(1, 0.541, 0.165, 1) end
    V.retSig = WowF.marcoRetrato and WowF.marcoRetrato(V.capa, 56)
    if V.retSig then pcall(function() V.retSig:SetFrameLevel(M.num(V.capa:GetFrameLevel()) + 3) end) end
  end
  return V.tarjeta
end

function WowF.diarioMapaSoltar(contenedor)
  local lista = contenedor and { M.vistas[contenedor] } or M.vistas
  for _, V in pairs(lista) do
    if V then
      for i = 1, #V.pines do V.pines[i]:Hide() end
      for i = 1, #V.marcas do V.marcas[i]:Hide() end
      for i = 1, #V.textos do V.textos[i]:Hide() end
      for i = 1, #V.botones do V.botones[i]:Hide() end
      M.soltarRayas(V)
      V.np, V.nm, V.ntx, V.nb = 0, 0, 0, 0
      V.borde:Hide(); V.vista:Hide()
      if V.tarjeta then V.tarjeta:Hide() end
      if V.retSig then V.retSig:Hide() end
      V.datos = nil
    end
  end
end

-- Etiqueta del mapa -> jefe del diario (por nombre o alias)
function M.indiceEnDiario(jefes, n, alias)
  for i, j in ipairs(jefes) do if j.n == n or (alias and j.n == alias) then return i end end
  return nil
end
-- Pista de un jefe escondido (wowF_MapasPistas_Datos.lua): { es, en, url } o { es = , en = , url = }
function M.pista(id, n, alias)
  local t = WowFMapasPistas and WowFMapasPistas[id]
  if type(t) ~= "table" then return nil end
  local p = t[n] or (alias and t[alias])
  if type(p) ~= "table" then return nil end
  return { texto = L(p.es or p[1] or "", p.en or p[2] or p.es or p[1] or ""), url = p.url or p[3] }
end
function M.esDentro(m)
  local id = M.instanciaActual()
  return id ~= nil and m and id == m.i
end

-- WowF.diarioPintarMapa(contenedor, m, ancho [, x0, y0 [, altoMapa]]) -> y de abajo (en el contenedor, y crece hacia abajo)
function WowF.diarioPintarMapa(contenedor, m, ancho, x0, y0, altoMapa)
  if not contenedor or type(m) ~= "table" then return y0 or 0 end
  local V = M.vistaDe(contenedor)
  WowF.diarioMapaSoltar(contenedor)
  x0, y0, ancho = x0 or 0, y0 or 0, math.max(240, ancho or 400)
  V.args = { m, ancho, x0, y0, altoMapa }
  local d = WowFMapasMazmorras and m.i and WowFMapasMazmorras[m.i]
  local jefes = (WowF.diarioJefesDe and WowF.diarioJefesDe(m)) or {}
  local est = { mazmorra = m.n, disponible = d and true or false, pines = {}, porUbicar = {}, ruta = {}, pistas = {} }
  local mini = V.padre == M.mini
  if not M.esVentana(V.padre) then M.estado = est; M.ultima = m end
  V.estado = est
  local y = y0
  if not mini then
    M.texto(V, x0, y, ancho, L("Mapa de la mazmorra", "Dungeon map"), "titulo", 14)
    y = y + 22
  end
  if not d then
    local _, a = M.texto(V, x0, y, ancho, M.TXT.naranja .. L("El mapa de esta mazmorra aún no está disponible en WoW Forever; se actualizará.",
      "The map of this dungeon is not available in WoW Forever yet; it will be updated.") .. "|r", "cuerpo", 11)
    y = y + a + 6
    local _, a2 = M.texto(V, x0, y, ancho, M.TXT.gris .. L("El cliente de la beta no trae mapas de las mazmorras y ninguna guía de WoW Forever ubica todavía a sus jefes; no se inventa. Mientras tanto, el orden de los jefes está en la pestaña Jefes y botín.",
      "The beta client has no dungeon maps and no WoW Forever guide places its bosses yet; nothing is made up. Meanwhile, the boss order is in the Bosses and loot tab.") .. "|r", "sub", 10)
    return y + a2 + 8
  end
  V.datos, V.m = d, m
  est.tex = d.tex
  V.muertos = M.muertos(m.i)
  est.muertos = V.muertos
  -- Siguiente jefe = el primero del orden que no esta derrotado
  V.siguiente = nil
  for _, n in ipairs(d.orden or {}) do if not V.muertos[n] then V.siguiente = n; break end end
  est.siguiente = V.siguiente
  -- Vista: alto segun el mapa (maximo altoMapa o 440)
  local tope = altoMapa or 440
  V.vw = ancho
  V.vh = mini and math.max(150, math.floor(tope)) or math.floor(math.min(tope, math.max(260, ancho * d.ih / d.iw)))
  V.borde:ClearAllPoints(); V.borde:SetPoint("TOPLEFT", V.padre, "TOPLEFT", x0 - 2, -(y - 2)); V.borde:SetSize(V.vw + 4, V.vh + 4); V.borde:Show()
  V.vista:ClearAllPoints(); V.vista:SetPoint("TOPLEFT", V.padre, "TOPLEFT", x0, -y); V.vista:SetSize(V.vw, V.vh); V.vista:Show()
  V.img:SetTexture(M.RAIZ .. "Mapas\\" .. d.tex)
  pcall(V.img.SetTexCoord, V.img, 0, d.iw / (d.tw or 1024), 0, d.ih / (d.th or 1024))
  V.mas:ClearAllPoints(); V.mas:SetPoint("TOPRIGHT", V.vista, "TOPRIGHT", -8, -8)
  V.menos:ClearAllPoints(); V.menos:SetPoint("TOP", V.mas, "BOTTOM", 0, -4)
  V.centrar:ClearAllPoints(); V.centrar:SetPoint("TOPRIGHT", V.menos, "BOTTOMRIGHT", 0, -4)
  V.sacar:SetText(L("Sacar el mapa", "Pop out map")); V.sacar.wowfTexto = L("Sacar el mapa", "Pop out map")
  V.sacar.info = { titulo = L("Sacar el mapa", "Pop out map"), lineas = { L("Lo abre en una ventana pequeña que puedes mover a una esquina mientras juegas (por ejemplo, si vas de tanque). Se queda donde la dejes.",
    "Opens it in a small window you can move to a corner while you play (for example, as a tank). It stays where you leave it.") } }
  V.ayudaB.info = M.textosAyuda()
  V.sacar:ClearAllPoints(); V.sacar:SetPoint("TOPRIGHT", V.centrar, "BOTTOMRIGHT", 0, -4)
  V.ayudaB:ClearAllPoints(); V.ayudaB:SetPoint("TOPRIGHT", mini and V.centrar or V.sacar, "BOTTOMRIGHT", 0, -4)
  if mini then V.sacar:Hide() else V.sacar:Show() end
  est.sacar = not mini
  est.ayuda = V.ayudaB.info
  if V.mapaDe ~= m.n then V.zoom, V.ox, V.oy, V.mapaDe = 1, 0, 0, m.n end
  -- Pines
  local enMapa = {}
  for _, p in ipairs(d.p) do
    local n, t, px, py, alias = p[1], p[2], p[3], p[4], p[5]
    local idx = (t == "j" or t == "p" or t == "r") and M.indiceEnDiario(jefes, n, alias) or nil
    local pista = M.pista(m.i, n, alias)
    local lineas = {}
    local sala = d.salaDe and d.salaDe[n] and M.es(d.salaDe[n])
    if sala and sala ~= "" then table.insert(lineas, M.TXT.gris .. sala .. "|r") end
    local b
    if t == "j" then
      b = M.pinJefe(V)
      local j = idx and jefes[idx]
      b.ret:poner({ npc = j and j.npc, cara = j and j.cara, display = (j and j.d) or (d.ret and (d.ret[n] or (alias and d.ret[alias]))), nombre = n, icono = M.ICONO_JEFE })
      local muerto = V.muertos[n] or (alias and V.muertos[alias])
      local sig = n == V.siguiente
      b.nombre:SetText(n)
      local wn = M.num(b.nombre.GetStringWidth and b.nombre:GetStringWidth())
      b.gal:SetWidth(math.max(64, math.floor(wn + 44)))
      b.subTxt = muerto and L("derrotado", "defeated") or (sig and L("siguiente", "next")) or sala or ""
      if muerto then b.sub:SetText(M.TXT.gris .. L("derrotado", "defeated") .. "|r")
      elseif sig then b.sub:SetText("|cffffb84d" .. L("siguiente", "next") .. "|r")
      else b.sub:SetText(sala and (M.TXT.gris .. sala .. "|r") or "") end
      b.late = sig
      b.brillo:SetAlpha(sig and 0.8 or 0.25)
      if b.brillo.SetVertexColor then
        if muerto then b.brillo:SetVertexColor(0.4, 0.4, 0.4) elseif sig then b.brillo:SetVertexColor(1, 0.55, 0.15) else b.brillo:SetVertexColor(0.9, 0.7, 0.35) end
      end
      if b.ret.tex and b.ret.tex.SetDesaturated then pcall(b.ret.tex.SetDesaturated, b.ret.tex, muerto and true or false) end
      b:SetAlpha(muerto and 0.6 or 1)
      if muerto then table.insert(lineas, M.TXT.verde .. L("Ya lo derrotaste (en las últimas 2 horas)", "Already defeated (in the last 2 hours)") .. "|r") end
      if d.como and d.como[n] then table.insert(lineas, M.es(d.como[n])) end
      if pista then table.insert(lineas, M.TXT.morado .. L("Cómo encontrarlo: ", "How to find it: ") .. "|r" .. pista.texto) end
      if not idx then table.insert(lineas, L("No está en el diario del juego de WoW Forever", "Not in the WoW Forever in-game journal")) end
      if idx then table.insert(lineas, M.TXT.verde .. L("Clic: ver su botín", "Click: see its loot") .. "|r") end
    else
      b = M.marca(V)
      b.tex:SetTexture(M.UI .. (M.TEX_MARCA[t] or "objeto"))
      local etq = ""
      if t == "e" then table.insert(lineas, 1, L("Entrada de la mazmorra", "Dungeon entrance")); etq = L("Entrada", "Entrance")
      elseif t == "o" then table.insert(lineas, L("Objeto o personaje que señala la guía", "Object or character marked by the guide"))
      elseif t == "r" then table.insert(lineas, L("Raro: no siempre aparece", "Rare: does not always spawn")); etq = n
      elseif t == "p" then table.insert(lineas, L("Uno de sus sitios posibles (aparece en uno de ellos)", "One of its possible spots (it spawns at one of them)")) end
      if pista then table.insert(lineas, M.TXT.morado .. L("Cómo encontrarlo: ", "How to find it: ") .. "|r" .. pista.texto) end
      if idx then table.insert(lineas, M.TXT.verde .. L("Clic: ver su botín", "Click: see its loot") .. "|r") end
      b.etiqueta:SetText(etq)
      b.hw = math.max(13, math.floor(M.num(b.etiqueta.GetStringWidth and b.etiqueta:GetStringWidth()) / 2) + 2)
      b.up, b.dn = 13, (etq ~= "" and 28 or 14)
    end
    if t == "j" then
      local ws = M.num(b.sub.GetStringWidth and b.sub:GetStringWidth())
      b.hw = math.max(31, math.floor(math.max(M.num(b.gal:GetWidth()), ws) / 2) + 2)
      b.up, b.dn = 31, (b.subTxt ~= "" and 64 or 52)
    end
    if idx then enMapa[idx] = true end
    b.px, b.py = px, py
    b.info = { titulo = (t == "e") and L("Entrada", "Entrance") or n, lineas = lineas }
    local nombre = idx and jefes[idx].n
    b:SetScript("OnClick", function() if nombre then M.verBotin(V, nombre) end end)
    if pista then est.pistas[n] = pista.texto end
    table.insert(est.pines, { n = n, t = t, marca = M.MARCA[t] or "J", x = px, y = py, diario = idx })
  end
  M.calcAjuste(V)
  M.aplicar(V)
  M.pintarOrden(V, d)
  if mini then return y + V.vh end
  y = y + V.vh + 6
  local _, ah = M.texto(V, x0, y, ancho, M.TXT.gris .. L("Arrastra para mover · rueda o +/- para acercar · clic en un jefe = su botín",
    "Drag to move · wheel or +/- to zoom · click a boss = its loot") .. "|r", "sub", 9)
  y = y + ah + 10
  y = M.pintarSiguiente(V, m, d, jefes, x0, y, ancho)
  y = M.pintarRuta(V, d, x0, y, ancho)
  y = M.pintarPistas(V, m, d, jefes, x0, y, ancho)
  -- Jefes del diario que el mapa no trae
  local porUbicar = {}
  for i, j in ipairs(jefes) do if not enMapa[i] then table.insert(porUbicar, j.n) end end
  est.porUbicar = porUbicar
  if #porUbicar > 0 then
    local _, ap = M.texto(V, x0, y, ancho, M.TXT.naranja .. L("Quedan por ubicar: ", "Still to be placed: ") .. table.concat(porUbicar, ", ") .. "|r "
      .. M.TXT.gris .. L("— la guía de WoW Forever aún no " .. (#porUbicar == 1 and "lo marca" or "los marca") .. " en el mapa; se actualizará en próximas actualizaciones.",
        "— the WoW Forever guide does not mark " .. (#porUbicar == 1 and "it" or "them") .. " on the map yet; it will be updated in future updates.") .. "|r", "sub", 10)
    y = y + ap + 6
  end
  local _, ac = M.texto(V, x0, y, ancho, M.TXT.gris .. L("Ubicación de los jefes: guía de WoW Forever de Icy Veins; dibujo del mapa: Forever Leveling Guide.",
    "Boss locations: Icy Veins WoW Forever guide; map drawing: Forever Leveling Guide.") .. "|r", "sub", 9)
  return y + ac + 8
end

-- Tarjeta "Siguiente jefe": retrato, nombre, sala, como llegar, pista; Ver su botin / Ir a el
function M.pintarSiguiente(V, m, d, jefes, x0, y, ancho)
  local t = M.panel(V)
  local n = V.siguiente
  local y0 = y
  local xt = x0 + 14
  local anchoT = ancho - 28
  if not n then
    local _, a = M.texto(V, xt, y + 12, anchoT, M.TXT.verde .. L("¡Todos los jefes derrotados! Mazmorra completada.", "All bosses defeated! Dungeon complete.") .. "|r", "cuerpo", 12)
    y = y + a + 24
  else
    local _, a0 = M.texto(V, xt, y + 10, anchoT, L("Siguiente jefe", "Next boss"), "etiqueta", 9)
    local yy = y + 10 + a0 + 6
    local idx = M.indiceEnDiario(jefes, n)
    local j = idx and jefes[idx]
    local xr = xt
    if V.retSig then
      V.retSig:ClearAllPoints(); V.retSig:SetPoint("TOPLEFT", V.padre, "TOPLEFT", xt, -yy)
      V.retSig:poner({ npc = j and j.npc, cara = j and j.cara, display = (j and j.d) or (d.ret and d.ret[n]), nombre = n, icono = M.ICONO_JEFE }); V.retSig:Show()
      xr = xt + 68
    end
    local anchoR = anchoT - (xr - xt)
    local _, a1 = M.texto(V, xr, yy, anchoR, n, "titulo", 15)
    local yr = yy + a1 + 2
    local sala = d.salaDe and d.salaDe[n] and M.es(d.salaDe[n])
    if sala and sala ~= "" then local _, a2 = M.texto(V, xr, yr, anchoR, M.TXT.oro .. sala .. "|r", "cuerpo", 11); yr = yr + a2 + 4 end
    if d.como and d.como[n] then local _, a3 = M.texto(V, xr, yr, anchoR, M.es(d.como[n]), "cuerpo", 11); yr = yr + a3 + 4 end
    local p = M.pista(m.i, n)
    if p then local _, a4 = M.texto(V, xr, yr, anchoR, M.TXT.morado .. L("Cómo encontrarlo: ", "How to find it: ") .. "|r" .. p.texto, "cuerpo", 11); yr = yr + a4 + 4 end
    yr = math.max(yr, yy + 60) + 4
    local _, wb = M.boton(V, xr, yr, L("Ver su botín", "See its loot"), "estandarte", function() M.verBotin(V, n) end)
    M.boton(V, xr + wb + 8, yr, L("Ir a él", "Go to it"), "cuero", function() M.irA(V, n) end)
    y = yr + 26 + 12
  end
  t:ClearAllPoints(); t:SetPoint("TOPLEFT", V.padre, "TOPLEFT", x0, -y0); t:SetSize(ancho, y - y0); t:Show()
  return y + 10
end

-- "Ver su botin": en el Diario va directo; desde la ventana grande abre el Diario en esa mazmorra
function M.verBotin(V, n)
  if V.padre == M.grande and V.m then
    if WowF.abrirLibro then pcall(WowF.abrirLibro, "Mazmorras") end
    if WowF.libroSubpestana then pcall(WowF.libroSubpestana, "diario") end
    if WowF.diarioElegir then pcall(WowF.diarioElegir, V.m.n) end
  end
  if WowF.diarioVerJefe then return WowF.diarioVerJefe(n) end
end
-- "Ir a el": centra el mapa en el jefe; fuera de la mazmorra, ademas, la ruta a su entrada
function M.irA(V, n)
  local d = V.datos
  if not d then return end
  for _, p in ipairs(d.p) do if p[1] == n then M.centrarEn(V, p[3], p[4], 1.8); break end end
  if V.m and not M.esDentro(V.m) and WowF.irAMazmorra then pcall(WowF.irAMazmorra, V.m) end
  M.estado.irA = n
end

-- Franja "La ruta": los jefes en orden; derrotados en gris, el siguiente en naranja; clic = centrar en el
function M.pintarRuta(V, d, x0, y, ancho)
  local orden = d.orden or {}
  if #orden == 0 then return y end
  local _, a0 = M.texto(V, x0, y, ancho, L("La ruta", "The route"), "etiqueta", 9)
  y = y + a0 + 6
  local x = x0
  for k, n in ipairs(orden) do
    local muerto, sig = V.muertos[n], n == V.siguiente
    local txt = (muerto and M.TXT.gris or (sig and "|cffffb84d" or M.TXT.texto)) .. n .. "|r"
    local b, w = M.boton(V, x, y, txt, sig and "estandarte" or "cuero", function()
      for _, p in ipairs(d.p) do if p[1] == n then M.centrarEn(V, p[3], p[4], 1.8); break end end
    end)
    if x + w > x0 + ancho and x > x0 then
      x = x0; y = y + 32
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", V.padre, "TOPLEFT", x, -y)
    end
    table.insert(V.estado.ruta, { n = n, muerto = muerto and true or false, siguiente = sig })
    x = x + w + (k < #orden and 14 or 0)
  end
  return y + 26 + 12
end

-- Pistas de jefes escondidos o con truco: solo guias de WoW Forever; sin datos = aviso
function M.pintarPistas(V, m, d, jefes, x0, y, ancho)
  local t = WowFMapasPistas and WowFMapasPistas[m.i]
  local lista = {}
  if type(t) == "table" then
    for n in pairs(t) do local p = M.pista(m.i, n); if p and p.texto ~= "" then table.insert(lista, { n = n, texto = p.texto }) end end
    table.sort(lista, function(a, b) return a.n < b.n end)
  end
  local _, a0 = M.texto(V, x0, y, ancho, L("Jefes escondidos y trucos", "Hidden bosses and tricks"), "etiqueta", 9)
  y = y + a0 + 4
  if #lista == 0 then
    local _, a = M.texto(V, x0, y, ancho, M.TXT.gris .. L("Aún no hay datos de WoW Forever sobre jefes escondidos en esta mazmorra; pendiente de actualizar.",
      "No WoW Forever data on hidden bosses in this dungeon yet; pending update.") .. "|r", "sub", 10)
    V.estado.sinPistas = true
    return y + a + 10
  end
  for _, p in ipairs(lista) do
    local _, a = M.texto(V, x0, y, ancho, M.TXT.morado .. p.n .. ":|r " .. p.texto, "cuerpo", 11)
    y = y + a + 4
    V.estado.pistas[p.n] = p.texto
  end
  return y + 8
end

-- Para las pruebas: lo que se ve en la pestana Mapa del Diario
function WowF.diarioMapaEstado() return M.estado end
function WowF.diarioMapaTexto(contenedor)
  local V = contenedor and M.vistas[contenedor]
  if not V then for c, v in pairs(M.vistas) do if not M.esVentana(c) then V = v end end end
  if not V then return "" end
  local t = {}
  for i = 1, V.ntx do local f = V.textos[i]; if f and f.GetText then table.insert(t, f:GetText() or "") end end
  for i = 1, V.nb do local b = V.botones[i]; if b and b.wowfTexto then table.insert(t, b.wowfTexto) end end
  for _, p in ipairs((V.estado or {}).pines or {}) do table.insert(t, "[" .. p.marca .. "] " .. p.n) end
  return table.concat(t, "\n")
end
-- Para las pruebas: zoom y desplazamiento de una vista
function WowF.diarioMapaVista(contenedor)
  local V = contenedor and M.vistas[contenedor]
  if not V then for c, v in pairs(M.vistas) do if not M.esVentana(c) then V = v end end end
  if not V then return nil end
  local cl, cr = 0, V.w or 0 -- 12-oct: caja con etiquetas (lo que limitar() mantiene a la vista)
  if V.datos then local w, h = M.medidas(V); cl, cr = M.caja(V, w, h) end
  return { zoom = V.zoom, ox = V.ox, oy = V.oy, w = V.w, h = V.h, vw = V.vw, vh = V.vh, cl = cl, cr = cr,
    zoomA = function(z) M.zoomA(V, z) end, centrar = function() M.centrarTodo(V) end, irA = function(n) M.irA(V, n) end }
end

-- ===================== Ventana grande: /wowf mapa =====================
function M.mazmorraParaVentana()
  local id = M.instanciaActual()
  if id and WowFMazmorras then for _, m in ipairs(WowFMazmorras) do if m.i == id then return m end end end
  if M.ultima then return M.ultima end
  if WowF.mazmorrasParaTi then
    local ok, lista = pcall(WowF.mazmorrasParaTi)
    if ok and type(lista) == "table" then
      for _, x in ipairs(lista) do if x.reco and WowFMapasMazmorras and WowFMapasMazmorras[x.m.i] then return x.m end end
      for _, x in ipairs(lista) do if WowFMapasMazmorras and WowFMapasMazmorras[x.m.i] then return x.m end end
      if lista[1] then return lista[1].m end
    end
  end
  return WowFMazmorras and WowFMazmorras[1]
end
function WowF.abrirMapaGrande(m)
  m = m or M.mazmorraParaVentana()
  if not m then return end
  if not M.ventana then
    local f = CreateFrame("Frame", "wowFMapaGrande", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(900, 620); f:SetPoint("CENTER")
    pcall(function() f:SetFrameStrata("HIGH") end)
    f:SetMovable(true); f:EnableMouse(true)
    pcall(function() f:SetClampedToScreen(true) end)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.fondo = f:CreateTexture(nil, "BACKGROUND", nil, 1); f.fondo:SetAllPoints()
    if f.fondo.SetColorTexture then f.fondo:SetColorTexture(0.07, 0.05, 0.04, 0.96) end
    f.borde = f:CreateTexture(nil, "BACKGROUND", nil, 0); f.borde:SetPoint("TOPLEFT", -2, 2); f.borde:SetPoint("BOTTOMRIGHT", 2, -2)
    if f.borde.SetColorTexture then f.borde:SetColorTexture(0.55, 0.42, 0.18, 1) end
    f.cerrar = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.cerrar:SetPoint("TOPRIGHT", 0, 0)
    -- Contenido con desplazamiento (la tarjeta y la ruta quedan debajo del mapa)
    f.scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", 14, -14); f.scroll:SetPoint("BOTTOMRIGHT", -32, 14)
    f.hoja = CreateFrame("Frame", nil, f.scroll)
    f.hoja:SetSize(850, 600)
    f.scroll:SetScrollChild(f.hoja)
    M.ventana, M.grande = f, f.hoja
  end
  M.ventana:Show()
  M.ventanaM = m
  local ok, y = pcall(WowF.diarioPintarMapa, M.grande, m, 840, 4, 4, 470)
  if ok and type(y) == "number" then M.grande:SetHeight(math.max(600, y + 10)) end
end
function WowF.mapaGrandeEstado()
  local V = M.grande and M.vistas[M.grande]
  return V and V.estado, M.ventana and M.ventana:IsShown()
end

-- ===================== Ventana pequena: "Sacar el mapa" (4.28) =====================
-- Solo el mapa (con el orden en la esquina y el "?"), movible y con esquina para agrandar; posicion y tamano en WowFExportarDB.mapaMini
function M.cfgMini()
  if type(WowFExportarDB) ~= "table" then WowFExportarDB = {} end
  if type(WowFExportarDB.mapaMini) ~= "table" then WowFExportarDB.mapaMini = {} end
  return WowFExportarDB.mapaMini
end
function M.guardarMini()
  local f, cfg = M.miniF, M.cfgMini()
  local ok, p, _, rp, x, y = pcall(f.GetPoint, f, 1)
  if ok and p then cfg.punto, cfg.rel, cfg.x, cfg.y = p, rp or p, M.num(x), M.num(y) end
  cfg.ancho = math.floor(M.num(f:GetWidth()))
  if not cfg.minimizado then cfg.alto = math.floor(M.num(f:GetHeight())) end
  cfg.v = 2
end
function M.crearMini()
  local cfg = M.cfgMini()
  local f = CreateFrame("Frame", "wowFMapaMini", UIParent)
  -- 12-oct: mas grande por defecto (Andy: "queda muy chiquito"); los tamanos guardados antes de esta version se olvidan
  if cfg.v ~= 2 then cfg.ancho, cfg.alto = nil, nil end
  f:SetSize(math.max(300, math.min(1000, M.num(cfg.ancho) > 0 and M.num(cfg.ancho) or 500)),
    math.max(240, math.min(900, M.num(cfg.alto) > 0 and M.num(cfg.alto) or 460)))
  if cfg.punto then f:SetPoint(cfg.punto, UIParent, cfg.rel or cfg.punto, M.num(cfg.x), M.num(cfg.y))
  else f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -230, -180) end
  pcall(function() f:SetFrameStrata("MEDIUM") end)
  pcall(function() f:SetToplevel(true) end)
  f:SetMovable(true); f:EnableMouse(true)
  pcall(function() f:SetResizable(true) end)
  if f.SetResizeBounds then pcall(f.SetResizeBounds, f, 300, 240, 1000, 900) elseif f.SetMinResize then pcall(f.SetMinResize, f, 300, 240) end
  pcall(function() f:SetClampedToScreen(true) end)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); M.guardarMini() end)
  f.borde = f:CreateTexture(nil, "BACKGROUND", nil, 0); f.borde:SetPoint("TOPLEFT", -2, 2); f.borde:SetPoint("BOTTOMRIGHT", 2, -2)
  if f.borde.SetColorTexture then f.borde:SetColorTexture(0.55, 0.42, 0.18, 1) end
  f.fondo = f:CreateTexture(nil, "BACKGROUND", nil, 1); f.fondo:SetAllPoints()
  if f.fondo.SetColorTexture then f.fondo:SetColorTexture(0.07, 0.05, 0.04, 0.94) end
  f.titulo = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.titulo:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -7); f.titulo:SetPoint("RIGHT", f, "RIGHT", -50, 0)
  if f.titulo.SetJustifyH then f.titulo:SetJustifyH("LEFT") end
  if f.titulo.SetWordWrap then f.titulo:SetWordWrap(false) end
  local E = M.E()
  if E and E.letra then pcall(E.letra, f.titulo, "marca", 12, "OUTLINE") end
  f.cerrar = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  f.cerrar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
  pcall(function() f.cerrar:SetScale(0.8) end)
  f.cerrar:SetScript("OnClick", function() M.cfgMini().abierto = false; f:Hide() end)
  -- 12-oct (Andy: "un boton con un simbolo menos para minimizarlo"): "-" deja solo la barra del titulo; "+" la vuelve al tamano que tenia
  f.minBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  if E and E.boton then pcall(E.boton, f.minBtn, "cuero", 11) end
  f.minBtn:SetSize(18, 18)
  f.minBtn:SetText("-")
  f.minBtn:SetPoint("RIGHT", f.cerrar, "LEFT", -2, 0)
  f.minBtn:SetScript("OnClick", function() M.minimizarMini(not M.cfgMini().minimizado) end)
  f.minBtn:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(M.cfgMini().minimizado and L("Agrandar el mapa", "Restore the map") or L("Minimizar el mapa", "Minimize the map"), 1, 0.82, 0.3)
    GameTooltip:Show()
  end)
  f.minBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  -- 12-oct: esquina para agrandar GRANDE y a la vista (Andy: "que te marque mejor el botón"); al pasar el raton: marco dorado
  -- encendido, cursor de redimensionar, cartel "Arrastra..." y la esquina en blanco. Ancho y alto libres; el mapa se redibuja en vivo.
  f.esquina = CreateFrame("Button", nil, f)
  f.esquina:SetSize(30, 30); f.esquina:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
  pcall(function() f.esquina:SetFrameLevel(M.num(f:GetFrameLevel()) + 40) end)
  f.esquina.fondo = f.esquina:CreateTexture(nil, "BACKGROUND")
  f.esquina.fondo:SetPoint("BOTTOMRIGHT"); f.esquina.fondo:SetSize(30, 30)
  if f.esquina.fondo.SetColorTexture then f.esquina.fondo:SetColorTexture(0.05, 0.035, 0.025, 0.85) end
  pcall(function()
    f.esquina:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    f.esquina:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    f.esquina:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    f.esquina:GetNormalTexture():SetVertexColor(1, 0.8, 0.35)
  end)
  f.aviso = f.esquina:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.aviso:SetPoint("RIGHT", f.esquina, "LEFT", -4, 0)
  if E and E.letra then pcall(E.letra, f.aviso, "cuerpo", 12, "OUTLINE") end
  f.aviso:Hide()
  local function encender(si)
    if f.borde.SetColorTexture then
      if si then f.borde:SetColorTexture(1, 0.78, 0.3, 1) else f.borde:SetColorTexture(0.55, 0.42, 0.18, 1) end
    end
    pcall(function() f.esquina:GetNormalTexture():SetVertexColor(1, si and 1 or 0.8, si and 1 or 0.35) end)
    if si then
      f.aviso:SetText("|cffffd36b" .. L("Arrastra para agrandar o achicar", "Drag to resize") .. "|r"); f.aviso:Show()
      if SetCursor then pcall(SetCursor, "Interface\\Cursor\\UI-Cursor-SizeRight") end
    else
      f.aviso:Hide()
      if ResetCursor then pcall(ResetCursor) end
    end
  end
  f.esquina:SetScript("OnEnter", function() encender(true) end)
  f.esquina:SetScript("OnLeave", function() if not f.redim then encender(false) end end)
  f.esquina:SetScript("OnMouseDown", function() f.redim = true; f:StartSizing("BOTTOMRIGHT") end)
  f.esquina:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing(); f.redim = false
    encender(f.esquina.IsMouseOver and f.esquina:IsMouseOver() or false)
    M.guardarMini(); M.pintarMini()
  end)
  f:SetScript("OnSizeChanged", function()
    if not f.redim then return end
    local t = GetTime and GetTime() or 0
    if f.ultimo and t - f.ultimo < 0.05 then return end
    f.ultimo = t
    M.pintarMini()
  end)
  f.hoja = CreateFrame("Frame", nil, f)
  f.hoja:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -26); f.hoja:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
  M.miniF, M.mini = f, f.hoja
  if cfg.minimizado then M.minimizarMini(true, true) end
end
-- Minimizar: el borde de arriba se queda donde esta (se ancla por TOPLEFT antes de cambiar el alto)
function M.minimizarMini(si, sinPintar)
  local f, cfg = M.miniF, M.cfgMini()
  if not f then return end
  pcall(function()
    local x, y = f:GetLeft(), f:GetTop()
    if type(x) == "number" and type(y) == "number" then
      f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    end
  end)
  if si then
    if not cfg.minimizado then cfg.alto = math.floor(M.num(f:GetHeight())) end
    cfg.minimizado = true
    f.hoja:Hide(); f.esquina:Hide()
    f:SetHeight(26)
  else
    cfg.minimizado = false
    f:SetHeight(math.max(240, math.min(900, M.num(cfg.alto) > 0 and M.num(cfg.alto) or 460)))
    f.hoja:Show(); f.esquina:Show()
  end
  f.minBtn:SetText(si and "+" or "-")
  M.guardarMini()
  if not si and not sinPintar then M.pintarMini() end
end
WowF.mapaMiniMinimizar = function(si) M.minimizarMini(si) end
function M.pintarMini()
  local f, m = M.miniF, M.miniM
  if not f or not m then return end
  f.titulo:SetText(m.n or "")
  if M.cfgMini().minimizado then return end
  -- 12-oct: el mapa ocupa toda la ventana (ancho y alto libres) y se encaja centrado dentro
  local ancho = math.max(300, M.num(f:GetWidth())) - 12
  local alto = math.max(240, M.num(f:GetHeight())) - 32
  pcall(WowF.diarioPintarMapa, M.mini, m, ancho, 0, 0, alto)
end
-- WowF.sacarMapa(m): abre la ventana pequena con el mapa de m (o de la mazmorra donde estas / la ultima vista) y cierra las grandes
function WowF.sacarMapa(m)
  m = m or M.mazmorraParaVentana()
  if not m then return end
  if not M.miniF then M.crearMini() end
  local cfg = M.cfgMini()
  cfg.abierto, cfg.mazmorra = true, m.n
  M.miniM = m
  M.miniF:Show()
  M.pintarMini()
  if M.ventana and M.ventana:IsShown() then M.ventana:Hide() end
  if WowF.libro and WowF.libro.IsShown and WowF.libro:IsShown() then pcall(function() WowF.libro:Hide() end) end
end
function WowF.mapaMiniEstado()
  local V = M.mini and M.vistas[M.mini]
  return V and V.estado, M.miniF and M.miniF:IsShown(), M.cfgMini()
end
-- Al entrar al mundo: si la ventana pequena quedo abierta, se vuelve a abrir (con la mazmorra donde estas, si tiene mapa)
function M.reabrirMini()
  local cfg = M.cfgMini()
  if cfg.abierto ~= true then return end
  local id, m = M.instanciaActual(), nil
  if id and WowFMazmorras and WowFMapasMazmorras and WowFMapasMazmorras[id] then
    for _, x in ipairs(WowFMazmorras) do if x.i == id then m = x end end
  end
  if not m and cfg.mazmorra and WowFMazmorras then
    for _, x in ipairs(WowFMazmorras) do if x.n == cfg.mazmorra then m = x end end
  end
  if not m then return end
  if not M.miniF then M.crearMini() end
  M.miniM = m
  M.miniF:Show()
  M.pintarMini()
end
WowF._mapaReabrirMini = M.reabrirMini -- para las pruebas

-- Repinta lo que esta a la vista (al derrotar un jefe)
function M.repintar()
  for c, V in pairs(M.vistas) do
    if V.args and V.vista:IsShown() then
      if c == M.mini then pcall(M.pintarMini)
      elseif c == M.grande then pcall(WowF.abrirMapaGrande, M.ventanaM)
      elseif WowF.diarioElegir then pcall(WowF.diarioElegir) end
    end
  end
end

M.ev = CreateFrame("Frame")
pcall(M.ev.RegisterEvent, M.ev, "ENCOUNTER_END")
pcall(M.ev.RegisterEvent, M.ev, "PLAYER_ENTERING_WORLD")
M.ev:SetScript("OnEvent", function(_, evento, encuentro, nombre, _, _, exito)
  if evento == "PLAYER_ENTERING_WORLD" then
    if C_Timer and C_Timer.After then C_Timer.After(1, function() pcall(M.reabrirMini) end) else pcall(M.reabrirMini) end
    return
  end
  if evento ~= "ENCOUNTER_END" or tonumber(exito) ~= 1 then return end
  pcall(M.anotarMuerto, encuentro, nombre)
  pcall(M.repintar)
end)
WowF._mapaAnotarMuerto = M.anotarMuerto -- para las pruebas

if SlashCmdList then
  local ordenAnterior = SlashCmdList["WOWF"]
  SlashCmdList["WOWF"] = function(mensaje, ...)
    local s = strtrim and strtrim(mensaje or "") or (mensaje or "")
    local orden, resto = s:match("^(%S+)%s*(.-)$")
    orden = orden and orden:lower() or ""
    if orden == "mapa" or orden == "map" then
      local m
      resto = (resto or ""):lower()
      if resto ~= "" and WowFMazmorras then
        for _, x in ipairs(WowFMazmorras) do if x.n:lower():find(resto, 1, true) then m = x; break end end
      end
      WowF.abrirMapaGrande(m)
      return
    end
    if orden == "sacarmapa" or orden == "popout" then
      local m
      resto = (resto or ""):lower()
      if resto ~= "" and WowFMazmorras then
        for _, x in ipairs(WowFMazmorras) do if x.n:lower():find(resto, 1, true) then m = x; break end end
      end
      WowF.sacarMapa(m)
      return
    end
    if ordenAnterior then return ordenAnterior(mensaje, ...) end
  end
end

-- 12-oct: al cambiar de idioma, el mapa sacado y el grande (si estan abiertos) se vuelven a pintar
WowF.alReidiomar = WowF.alReidiomar or {}
table.insert(WowF.alReidiomar, function()
  if M.miniF and M.miniF:IsShown() then M.pintarMini() end
  if M.ventana and M.ventana:IsShown() and M.ventanaM then WowF.abrirMapaGrande(M.ventanaM) end
end)
