-- Forever Leveling Guide: fondo de cada pestana del Libro con arte del propio cliente de WoW Forever (11-oct, "ambiente de World of Warcraft").
-- Datos: wowF_Fondos_Datos.lua (WowFFondosDatos, generado por generar-fondos.mjs; cada fileDataID esta en el manifest de la build).
--   Progreso            -> pantalla de carga del mapa donde estas (GetInstanceInfo, 8.o valor = Map.ID); si no hay, la del continente de tu faccion
--   Talentos / Combate  -> arte del arbol de talentos de tu clase y de la rama con la que subes (TalentFrame, 4 piezas)
--   Profesiones         -> arte de tu primera profesion (ProfessionBackgroundArt); sin profesion, tu ciudad de faccion
--   Equipo              -> fondo del probador de tu raza (DressUpBackground, 4 piezas); BiS 30 -> pantalla de mazmorra
--   Mazmorras           -> pantalla de carga (o arte del diario) de la primera mazmorra que te toca
-- Encima siguen el velo y la vineta de E.ambiente (wowF_Estilo.lua). Si una textura no carga: la siguiente opcion; si ninguna, piedra lisa.
-- Recorte "cover": la imagen llena el hueco SIN deformarse (se recorta lo que sobra con SetTexCoord). Nunca sobre texturas con mascara.
WowF = WowF or {}
local F = {}
WowF.fondos = F

-- Formas de cada tipo de arte. piezas = rectangulos {x, y, ancho, alto} de cada textura en una imagen virtual;
-- util = la parte con arte {x0, y0, x1, y1} (sin logo, pergamino ni bordes transparentes); fy = donde se centra el recorte vertical (0 arriba, 1 abajo).
-- Medidas tomadas de los BLP de la build 1.60.1.70338 (wago.tools).
local PIEZAS4 = { { 0, 0, 256, 256 }, { 256, 0, 64, 256 }, { 0, 256, 256, 128 }, { 256, 256, 64, 128 } }
local FORMAS = {
  -- LoadScreen_Camelot_* de Forever: 2992x1684, imagen entera
  n = { piezas = { { 0, 0, 2992, 1684 } }, util = { 0, 0, 2992, 1684 }, fy = 0.5 },
  -- LoadScreen*.blp viejas: 2048x2048 que el juego muestra en 4:3; logo arriba (hasta ~0.22) y pergamino abajo (desde ~0.80)
  v = { piezas = { { 0, 0, 1333, 1000 } }, util = { 0, 225, 1333, 795 }, fy = 0.5 },
  -- ProfessionBackgroundArt*: 1024x1024, el arte ocupa 678x546 arriba a la izquierda; es muy oscuro -> mas alfa y sin tinte
  prof = { piezas = { { 0, 0, 1024, 1024 } }, util = { 0, 0, 678, 546 }, fy = 0.45, alfa = 0.85, gris = 0, color = { 1, 1, 1 } },
  -- UI-EJ-LOREBG-* del diario: 512x512, cuadro con marco; dentro del marco 32..358 x 48..292
  lore = { piezas = { { 0, 0, 512, 512 } }, util = { 32, 48, 358, 292 }, fy = 0.5 },
  -- TalentFrame <Fondo>-TopLeft/TopRight/BottomLeft/BottomRight: arte util 300x331 (TR transparente desde x 44; BL desde y 75)
  talento = { piezas = PIEZAS4, util = { 0, 0, 300, 331 }, fy = 0.4, alfa = 0.64 },
  -- DressUpBackground-<Raza>1..4: arte util 316x326 (BL transparente desde y ~74); el suelo queda abajo
  probador = { piezas = PIEZAS4, util = { 0, 0, 316, 326 }, fy = 0.65 },
}
F.FORMAS = FORMAS

-- Rectangulo de la imagen virtual que se ve en un hueco de W x H (sin deformar): {x0, y0, ancho, alto}
function F.recorte(forma, W, H)
  local u = forma.util
  local rw, rh = u[3] - u[1], u[4] - u[2]
  local A = W / H
  if rw / rh > A then
    local cw = rh * A
    return u[1] + (rw - cw) / 2, u[2], cw, rh
  end
  local ch = rw / A
  return u[1], u[2] + (rh - ch) * (forma.fy or 0.5), rw, ch
end

-- Capas propias sobre el marco de ambiente (BACKGROUND, sublevel 2: debajo del velo 3 y la vineta 4)
local capasDe = setmetatable({}, { __mode = "k" })
local function capas(a)
  local c = capasDe[a]
  if not c then
    c = {}
    for i = 1, 4 do c[i] = a:CreateTexture(nil, "BACKGROUND", nil, 2); c[i]:Hide() end
    capasDe[a] = c
  end
  return c
end
local function ocultarCapas(a)
  local c = capasDe[a]
  if c then for i = 1, 4 do c[i]:Hide() end end
  -- sin capas visibles la cache ya no vale (si no, el respaldo con la misma imagen de antes quedaria vacio)
  a.fondoClave = nil
end

-- Pone una textura y comprueba que cargo (si el cliente no la tiene, GetTexture vuelve vacio)
local function cargar(tx, fid)
  local ok = pcall(tx.SetTexture, tx, fid)
  if ok and tx.GetTexture then
    local ok2, puesta = pcall(tx.GetTexture, tx)
    if ok2 and (puesta == nil or puesta == "") then ok = false end
  end
  return ok
end

local function medida(a, metodo, defecto)
  local v = a[metodo] and select(2, pcall(a[metodo], a))
  v = tonumber(v)
  if not v or v <= 1 then return defecto end
  return v
end

-- Dibuja una opcion {fids, forma}; true si todo cargo
function F.dibujar(a, fids, nombreForma)
  local forma = FORMAS[nombreForma]
  if not (a and forma and type(fids) == "table") then return false end
  local W, H = medida(a, "GetWidth", 1070), medida(a, "GetHeight", 702)
  local clave = table.concat(fids, ",") .. "|" .. nombreForma .. "|" .. math.floor(W) .. "x" .. math.floor(H)
  if rawget(a, "fondoClave") == clave then a:Show(); return true end
  local c = capas(a)
  local cx, cy, cw, ch = F.recorte(forma, W, H)
  local s = W / cw
  -- 11-oct (Andy): el arte se ve mas (tarjetas translucidas encima)
  -- 12-oct (Andy: "que traspase mas, ese misticismo"): arte mas presente (antes 0.46 y gris 0.3)
  local alfa, gris, color = forma.alfa or 0.62, forma.gris or 0.2, forma.color or { 0.88, 0.8, 0.7 }
  for i = 1, 4 do
    local tx, pz, fid = c[i], forma.piezas[i], fids[i]
    tx:Hide()
    if pz then
      if not fid then ocultarCapas(a); return false end
      -- interseccion de la pieza con lo que se ve
      local x0, y0 = math.max(cx, pz[1]), math.max(cy, pz[2])
      local x1, y1 = math.min(cx + cw, pz[1] + pz[3]), math.min(cy + ch, pz[2] + pz[4])
      if x1 > x0 and y1 > y0 then
        if not cargar(tx, fid) then ocultarCapas(a); return false end
        tx:ClearAllPoints()
        -- medio pixel de mas para que no se vea la junta entre piezas
        tx:SetPoint("TOPLEFT", a, "TOPLEFT", (x0 - cx) * s, -(y0 - cy) * s)
        tx:SetSize((x1 - x0) * s + 0.5, (y1 - y0) * s + 0.5)
        tx:SetTexCoord((x0 - pz[1]) / pz[3], (x1 - pz[1]) / pz[3], (y0 - pz[2]) / pz[4], (y1 - pz[2]) / pz[4])
        if tx.SetDesaturation then pcall(tx.SetDesaturation, tx, gris) end
        if tx.SetVertexColor then tx:SetVertexColor(color[1], color[2], color[3]) end
        tx:SetAlpha(alfa)
        tx:Show()
      end
    end
  end
  -- la imagen unica de E.ambiente queda oculta: el arte va en estas capas (velo y vineta siguen encima)
  if a.img then a.img:Hide() end
  a.actual = nil
  a.fondoClave = clave
  a:Show()
  return true
end

local function quitar(a)
  ocultarCapas(a)
  a.fondoClave = nil
  if a.quitar then pcall(a.quitar, a) else a:Hide() end
end

-- ---------- Que imagen va en cada pestana (lista de opciones, de la mejor a la de respaldo) ----------
local function datos() return type(WowFFondosDatos) == "table" and WowFFondosDatos or {} end
local function faccion()
  local E = WowF.estilo
  if E and E.tema then
    local ok, t = pcall(E.tema)
    if ok and type(t) == "table" and (t.faccion == "Alliance" or t.faccion == "Horde") then return t.faccion end
  end
  if UnitFactionGroup then
    local ok, f = pcall(UnitFactionGroup, "player")
    if ok and (f == "Alliance" or f == "Horde") then return f end
  end
  return "Horde"
end
local function pantalla(fid, lista)
  if not fid then return end
  local t = datos().tipo and datos().tipo[fid]
  if t then table.insert(lista, { { fid }, t }) end
end
local function ciudad(lista) pantalla(datos().ciudad and datos().ciudad[faccion()], lista) end

local function mapaActual()
  if not GetInstanceInfo then return nil end
  local ok, a, b, c, d, e, f, g, id = pcall(GetInstanceInfo)
  if not ok then return nil end
  return tonumber(id)
end

local function sinParentesis(n) return type(n) == "string" and (n:gsub("%s*%b()", "")) or nil end
local function arbolDeTalentos(p)
  local D = datos()
  local clase = UnitClass and select(2, UnitClass("player"))
  if type(p) == "table" and type(p.clase) == "string" then clase = p.clase end
  local porClase = D.talento and clase and D.talento[clase]
  if not porClase then return nil end
  local ramas = D.ramas and D.ramas[clase] or {}
  local arbol
  if type(p) == "table" then
    arbol = ramas[sinParentesis(p.ramaPesos) or ""] or ramas[sinParentesis(p.ramaNombre) or ""] or ramas[sinParentesis(p.rama) or ""]
    if not arbol and tonumber(p.tab) then arbol = tonumber(p.tab) end
  end
  return porClase[arbol or 1] or porClase[1]
end

local function profesionConArte(p)
  local D = datos()
  if not D.prof then return nil end
  local ids = {}
  if WowF.profesionesPrincipales then
    local ok, r = pcall(WowF.profesionesPrincipales)
    if ok and type(r) == "table" then for _, x in ipairs(r) do table.insert(ids, x) end end
  end
  if WowF.profesiones then
    local ok, r = pcall(WowF.profesiones)
    if ok and type(r) == "table" then for _, x in ipairs(r) do if type(x) == "table" then table.insert(ids, x.id) end end end
  end
  -- sin profesiones aprendidas: las que pone tu plan
  if type(p) == "table" and type(p.ids) == "table" then for _, x in ipairs(p.ids) do table.insert(ids, x) end end
  for _, x in ipairs(ids) do if D.prof[tonumber(x) or 0] then return D.prof[tonumber(x)] end end
  return nil
end

local function mazmorraQueToca(p)
  if not WowF.mazmorrasParaTi then return nil end
  local nivel = (UnitLevel and UnitLevel("player")) or 1
  local ok, lista = pcall(WowF.mazmorrasParaTi, p, nivel)
  if not (ok and type(lista) == "table") then return nil end
  for _, e in ipairs(lista) do
    if type(e) == "table" and e.estado ~= "pasada" and type(e.m) == "table" then
      return WowFDiario and WowFDiario[e.m.i]
    end
  end
  return nil
end

function F.opciones(pestana, p)
  local D, lista = datos(), {}
  if pestana == "Progreso" or pestana == "Rares" then -- 19-oct: Rares con el arte de tu zona, como Progreso
    pantalla(D.mapa and D.mapa[mapaActual() or -1], lista)
    pantalla(D.continente and D.continente[faccion()], lista)
  elseif pestana == "Talentos" or pestana == "Combate" or pestana == "Rotacion" or pestana == "Macros" then
    local t = arbolDeTalentos(p)
    if t then table.insert(lista, { t, "talento" }) end
    ciudad(lista)
  elseif pestana == "Profesiones" then
    local fid = profesionConArte(p)
    if fid then table.insert(lista, { { fid }, "prof" }) end
    ciudad(lista)
  elseif pestana == "Equipo" then
    local raza = UnitRace and select(2, UnitRace("player"))
    local t = D.raza and raza and D.raza[raza]
    if t then table.insert(lista, { t, "probador" }) end
    pantalla(D.dungeon, lista)
  elseif pestana == "BiS 30" then
    pantalla(D.dungeon, lista)
    ciudad(lista)
  elseif pestana == "Mazmorras" then
    local d = mazmorraQueToca(p)
    if d and d.carga then pantalla(d.carga, lista) end
    if d and d.fondo then table.insert(lista, { { d.fondo }, "lore" }) end
    pantalla(D.dungeon, lista)
  end
  return lista
end

-- WowF.fondoPestana(pestana, p, ambiente): pone el fondo de esa pestana en el marco de ambiente del Libro.
-- Devuelve true si se encargo (con imagen o con piedra lisa); el Libro solo usa lo suyo si esto falla del todo.
function WowF.fondoPestana(pestana, p, a)
  a = a or WowF.libroAmbiente
  if not a then return false end
  local ok, lista = pcall(F.opciones, pestana, p)
  if ok and type(lista) == "table" then
    for _, o in ipairs(lista) do
      local ok2, puesto = pcall(F.dibujar, a, o[1], o[2])
      if ok2 and puesto then F.ultimo = { pestana = pestana, fids = o[1], forma = o[2] }; return true end
    end
  end
  F.ultimo = { pestana = pestana }
  pcall(quitar, a)
  return true
end
