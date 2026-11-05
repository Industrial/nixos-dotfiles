-- Forever Leveling Guide: "Piezas que persigues" (11-oct, ideas de GearQuest; solo la idea, datos y rutas de la guia).
--   * Boton "Perseguir" en Equipo (siguiente mejora, BiS del hueco, Comprar) y en la pestana BiS (WowF.botonPerseguir).
--   * Lista por personaje en WowFExportarDB.caza[Nombre-Reino] = { { id, n, tipo, clave, hueco, mi, mazmorra, mision, estado, fecha }, ... }
--     estado: "activa" | "conseguida" | "quitada". Pestanas Activas / Conseguidas / Quitadas en la ventana wowFCaza (/wowf caza|hunt).
--   * Clic en una activa = la ruta que ya existe: BiS -> WowF.irABiS, mazmorra -> WowF.irAMazmorra, mision -> WowF.irARecompensa.
--   * CHAT_MSG_LOOT y BAG_UPDATE(_DELAYED): si ya la tienes (WowF.yaLaTienes o GetItemCount con banco) pasa a Conseguidas
--     y sale la alerta "¡Conseguiste <pieza>!" (WowF.avisar, clave "caza<id>").
--   * "Ver como" (WowF.verComo*): otra clase y rama de la guia BiS y otro nivel, SOLO en esta sesion (no se guarda).
--     Limites: cambia la lista BiS / pre-BiS y el nivel con que se juzga; la "siguiente mejora" se oculta mientras dura
--     (usa tu equipo real); la faccion sigue siendo la tuya; no cambia talentos, rotacion ni profesiones.
--   * Boton del minimapa: casilla en Ajustes y /wowf minimapa|minimap on|off (WowF.aplicarMinimapa en wowF_Boton.lua).
-- Sin SetRaidTarget, sin SetCVar y sin UISpecialFrames.

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function Y(s) if WowF.yaTraducido then return WowF.yaTraducido(s) end return s end
local AZUL = "|cff33ccffForever Guide|r: "
local NARANJA = "|cffff9933"

local function personaje()
  local okN, n = pcall(UnitName, "player")
  local okR, r = pcall(GetRealmName)
  return ((okN and type(n) == "string") and n or "?") .. "-" .. ((okR and type(r) == "string") and r or "?")
end
local function lista()
  if type(WowFExportarDB) ~= "table" then WowFExportarDB = {} end
  WowFExportarDB.caza = type(WowFExportarDB.caza) == "table" and WowFExportarDB.caza or {}
  local pj = personaje()
  WowFExportarDB.caza[pj] = type(WowFExportarDB.caza[pj]) == "table" and WowFExportarDB.caza[pj] or {}
  return WowFExportarDB.caza[pj]
end
local function buscar(id)
  id = tonumber(id)
  for i, e in ipairs(lista()) do if e.id == id then return e, i end end
  return nil
end
local function nombreDe(id)
  local n
  if C_Item and C_Item.GetItemNameByID then local ok, v = pcall(C_Item.GetItemNameByID, id); if ok and type(v) == "string" then n = v end end
  if not n and GetItemInfo then local ok, v = pcall(GetItemInfo, id); if ok and type(v) == "string" then n = v end end
  return n or ("#" .. tostring(id))
end
-- La tienes = puesta, en las bolsas o en el banco
local function tiene(id)
  if WowF.yaLaTienes then
    local ok, v = pcall(WowF.yaLaTienes, id)
    if ok and v then return true end
  end
  local f = (C_Item and C_Item.GetItemCount) or GetItemCount
  if not f then return false end
  local ok, v = pcall(function() return tonumber(f(id, true)) end)
  return ok and v ~= nil and v > 0
end
local function redibujar()
  if WowF.libroRedibujar then pcall(WowF.libroRedibujar) end
  if WowF.cazaRefrescar then pcall(WowF.cazaRefrescar) end
end
local function ahora() local ok, t = pcall(time); return ok and t or 0 end

-- ===================== API =====================
function WowF.cazaEstado(id) local e = buscar(id); return e and e.estado or nil end
function WowF.cazaLista(estado)
  local res = {}
  for _, e in ipairs(lista()) do if not estado or e.estado == estado then table.insert(res, e) end end
  return res
end
-- datos: { id, n, tipo = "bis"|"mazmorra"|"mision", clave, hueco, mi, mazmorra, mision }
function WowF.cazaPerseguir(datos)
  if type(datos) ~= "table" or not tonumber(datos.id) then return false end
  local id = tonumber(datos.id)
  local e = buscar(id)
  if not e then
    e = { id = id }
    table.insert(lista(), e)
  end
  e.n = datos.n or e.n or nombreDe(id)
  e.tipo = datos.tipo or e.tipo or "bis"
  e.clave, e.hueco = datos.clave or e.clave, datos.hueco or e.hueco
  e.mi, e.mazmorra, e.mision = datos.mi or e.mi, datos.mazmorra or e.mazmorra, datos.mision or e.mision
  e.fecha = ahora()
  if tiene(id) then
    e.estado = "conseguida"
    print(AZUL .. Y(L("ya tienes " .. e.n .. ": la paso a Conseguidas.", "you already have " .. e.n .. ": moved to Obtained.")))
  else
    e.estado = "activa"
    print(AZUL .. Y(L("anotaste " .. e.n .. " en tu lista de Piezas que buscas. Vigilo tus bolsas y te aviso cuando la consigas (lista: /wowf caza).", "you added " .. e.n .. " to your Items you track list. I watch your bags and tell you when you get it (list: /wowf hunt).")))
    -- 12-oct (Andy: "que hace el addon, como se persigue"): explicacion completa solo la primera vez
    if not WowFExportarDB.cazaExplicada then
      WowFExportarDB.cazaExplicada = true
      print(AZUL .. Y(L("Cómo funciona: la lista es tuya y no caduca. En /wowf caza, clic en una pieza = ruta a donde sale (mazmorra, misión o vendedor). Al conseguirla, te aviso y pasa a Conseguidas.",
        "How it works: the list is yours and does not expire. In /wowf hunt, click an item = route to where it drops (dungeon, quest or vendor). When you get it, I tell you and it moves to Obtained.")))
    end
  end
  redibujar()
  return true
end
function WowF.cazaQuitar(id)
  local e = buscar(id)
  if not e then return false end
  e.estado = "quitada"; e.fecha = ahora()
  redibujar()
  return true
end
function WowF.cazaBorrar(id)
  local e, i = buscar(id)
  if not e then return false end
  table.remove(lista(), i)
  redibujar()
  return true
end
-- Revisa las activas; devuelve cuantas se consiguieron ahora
function WowF.cazaRevisar()
  local n = 0
  for _, e in ipairs(lista()) do
    if e.estado == "activa" and tiene(e.id) then
      e.estado = "conseguida"; e.fecha = ahora(); n = n + 1
      local nombre = e.n or nombreDe(e.id)
      if WowF.avisar then
        WowF.avisar(L("¡Conseguiste " .. nombre .. "!", "You got " .. nombre .. "!"),
          Y(L("Ya la tienes: pasa a Conseguidas en Piezas que buscas (/wowf caza).", "You have it now: moved to Obtained in Items you track (/wowf hunt).")),
          nil, 8, nil, { clave = "caza" .. e.id })
      else
        print(AZUL .. Y(L("¡Conseguiste " .. nombre .. "!", "You got " .. nombre .. "!")))
      end
    end
  end
  if n > 0 then redibujar() end
  return n
end

-- Ruta a la pieza con lo que ya existe
local function piezaBiS(id, clave)
  local function enRama(datos)
    if type(datos) ~= "table" then return nil end
    for h, e in pairs(datos) do
      if h ~= "_meta" and type(e) == "table" then
        for _, pz in ipairs({ e.bis, e.bisHorde }) do if type(pz) == "table" and pz.id == id then return pz end end
        for _, pz in ipairs(e.prebis or {}) do if pz.id == id then return pz end end
      end
    end
  end
  if type(WowFBiS) ~= "table" then return nil end
  local pz = clave and enRama(WowFBiS[clave])
  if pz then return pz end
  for _, datos in pairs(WowFBiS) do pz = enRama(datos); if pz then return pz end end
  return nil
end
function WowF.cazaIr(id)
  local e = buscar(id)
  if not e then return false end
  if e.tipo == "mazmorra" then
    for _, m in ipairs(WowFMazmorras or {}) do
      if (e.mi and m.i == e.mi) or (not e.mi and m.n == e.mazmorra) then
        if WowF.irAMazmorra then WowF.irAMazmorra(m); return true end
      end
    end
  elseif e.tipo == "mision" and type(e.mision) == "table" then
    if WowF.irARecompensa then return WowF.irARecompensa({ tipo = "mision", id = e.id, mision = e.mision }) ~= false end
  else
    local pz = piezaBiS(e.id, e.clave)
    if pz and WowF.irABiS then return WowF.irABiS(pz) end
  end
  print(AZUL .. NARANJA .. Y(L((e.n or "?") .. ": aún no hay datos de WoW Forever para llevarte; pendiente de actualizar.",
    (e.n or "?") .. ": no WoW Forever data yet to take you there; pending update.")) .. "|r")
  return false
end
-- Desde una mejora de Equipo (WowF.equipoGuia): mazmorra o mision
function WowF.cazaDesdeMejora(x)
  if type(x) ~= "table" or not x.id then return nil end
  local d = { id = x.id, n = nombreDe(x.id), tipo = x.tipo }
  if x.tipo == "mazmorra" and type(x.m) == "table" then d.mi, d.mazmorra = x.m.i, x.m.n
  elseif x.tipo == "mision" and type(x.mision) == "table" then
    local q = x.mision
    d.mision = { id = q.id, nombre = q.nombre, nivelMision = q.nivelMision, quien = q.quien, m = q.m, x = q.x, y = q.y, zona = q.zona, elegir = q.elegir, objeto = q.objeto, cadena = q.cadena }
  else d.tipo = "bis" end
  return d
end
-- Boton del kit. derecha = x es el borde derecho. Devuelve el ancho.
function WowF.botonPerseguir(k, x, y, datos, chico, derecha)
  if not k or type(datos) ~= "table" or not tonumber(datos.id) then return 0 end
  local id = tonumber(datos.id)
  local ya = WowF.cazaEstado(id) == "activa"
  local txt = ya and L("Anotada", "Tracked") or L("Anotar", "Track")
  local ayuda = ya and L("Ya está en tu lista de Piezas que buscas. Clic: quitarla de la lista.", "It is already in your Items you track list. Click: remove it from the list.")
    or L("Anotar = guardarla en tu lista de Piezas que buscas (/wowf caza). El addon vigila tus bolsas y te avisa cuando la consigas; en la lista, clic en la pieza = te lleva a donde sale.", "Track = save it in your Items you track list (/wowf hunt). The addon watches your bags and tells you when you get it; in the list, click the item = takes you where it drops.")
  local _, w = k:boton(x, y, txt, "secundario", chico, function()
    if WowF.cazaEstado(id) == "activa" then WowF.cazaQuitar(id) else WowF.cazaPerseguir(datos) end
  end, { derecha = derecha, ayuda = ayuda })
  return tonumber(w) or 90
end

-- ===================== Ver como (solo esta sesion) =====================
local vc = nil
local function clavesBiS()
  local t = {}
  for c in pairs(WowFBiS or {}) do if type(c) == "string" and c:find("|", 1, true) then table.insert(t, c) end end
  table.sort(t)
  return t
end
function WowF.verComoActivo() return vc end
function WowF.verComoNivel() return vc and vc.nivel or nil end
local function tope() return (WowFDatos and WowFDatos.topeBeta) or 30 end
function WowF.verComoPoner(clase, rama, nivel)
  if type(clase) ~= "string" or type(rama) ~= "string" then return false end
  local clave
  for _, c in ipairs(clavesBiS()) do if c:lower() == (clase .. "|" .. rama):lower() then clave = c end end
  if not clave then return false end
  local cl, ra = clave:match("^(.-)|(.+)$")
  local okN, mio = pcall(UnitLevel, "player")
  nivel = math.max(1, math.min(tope(), math.floor(tonumber(nivel) or (okN and tonumber(mio)) or 1)))
  vc = { clase = cl, rama = ra, nivel = nivel }
  if WowF.equipoGuiaLimpiar then pcall(WowF.equipoGuiaLimpiar) end
  return true
end
function WowF.verComoQuitar()
  vc = nil
  if WowF.equipoGuiaLimpiar then pcall(WowF.equipoGuiaLimpiar) end
  return true
end
local function nombreClase(c) return (c or "?"):sub(1, 1) .. (c or "?"):sub(2):lower() end
-- 12-oct (Andy: "que haya una parte que diga lista de anotados... de lo contrario no se puede ver"): boton a la vista que abre la lista
-- de Piezas que buscas (antes solo con /wowf caza). xDer = borde derecho. Devuelve el ancho.
function WowF.botonAnotadas(k, xDer, y)
  local n = #WowF.cazaLista("activa")
  local _, wb = k:boton(xDer, y, L("Piezas anotadas", "Tracked items") .. " (" .. n .. ")", "secundario", true, function() WowF.cazaAbrir("activa") end,
    { derecha = true, ayuda = L("Piezas anotadas\nAbre tu lista de Piezas que buscas: las que anotaste con el botón Anotar, las que ya conseguiste y las que quitaste. Clic en una pieza = te lleva a donde sale.",
      "Tracked items\nOpens your Items you track list: the ones you added with the Track button, the ones you already got and the ones you removed. Click an item = takes you where it drops.") })
  return tonumber(wb) or 130
end
-- Barra en Equipo y BiS. Devuelve la y siguiente.
function WowF.barraVerComo(k, x, y, w, ctx)
  local function otra() if ctx and ctx.redibujar then ctx.redibujar() elseif WowF.libroRedibujar then WowF.libroRedibujar() end end
  if not vc then
    local wA = WowF.botonAnotadas(k, x + w, y - 4) + 12
    k:boton(x, y, L("Ver como otro personaje", "View as another character"), "terciario", true, function()
      local c1 = clavesBiS()[1]
      local ok, clave = pcall(function() return WowF.bisRama and (WowF.bisRama()) end)
      if ok and type(clave) == "string" and WowFBiS and WowFBiS[clave] then c1 = clave end
      if c1 then local cl, ra = c1:match("^(.-)|(.+)$"); WowF.verComoPoner(cl, ra) end
      otra()
    end, { ayuda = L("Ver como otro personaje\nMira la lista BiS de nivel 30 que recomienda la guía para otra clase, rama o nivel, por ejemplo tu próximo personaje o el de un amigo.\n"
        .. "Solo cambia la lista BiS y el nivel con que se lee. Tu facción sigue siendo la tuya y tu personaje no cambia.\n"
        .. "Mientras miras, se oculta la tarjeta \"Siguiente mejora\" (es solo para tu personaje). Dura solo esta sesión; el botón \"Volver a mí\" lo quita.",
      "View as another character\nSee the level 30 BiS list the guide recommends for another class, spec or level, for example your next character or a friend's.\n"
        .. "Only the BiS list and the level used to read it change. Your faction stays yours and your character does not change.\n"
        .. "While you look, the \"Next upgrade\" card is hidden (it is only for your character). It lasts this session only; the \"Back to me\" button clears it.") })
    -- 12-oct (Andy no entendia el enlace): explicacion visible debajo
    local col0 = (WowF.estilo and WowF.estilo.color) or {}
    local _, h = k:texto(x, y + 18 + 4, L("Consulta la BiS de nivel 30 de otra clase, rama o nivel sin cambiar tu personaje (solo esta sesión).",
      "See the level 30 BiS of another class, spec or level without changing your character (this session only)."), { tam = 12, color = col0.tenue, ancho = w - wA })
    return math.max(y + 18 + 4 + (tonumber(h) or 14), y + 24) + 10
  end
  local K = WowF.vistaKit
  local col = (WowF.estilo and WowF.estilo.color) or {}
  local card = k:tarjeta(x, y, w, 10, "hundida")
  local yy = y + 12
  k:rotulo(x + 16, yy, L("Ver como", "View as"), col.oro)
  WowF.botonAnotadas(k, x + w - 16, y + 8)
  yy = yy + 14 + 6 + 8
  local _, h = k:texto(x + 16, yy, Y(NARANJA .. L("Estás viendo otro personaje: ", "You are viewing another character: ") .. "|r"
    .. nombreClase(vc.clase) .. " " .. vc.rama .. " · " .. L("nivel ", "level ") .. vc.nivel), { tam = 13, ancho = w - 32, sinAnotar = false })
  yy = yy + h + 8
  local claves = clavesBiS()
  local actual = vc.clase .. "|" .. vc.rama
  local function mover(paso)
    local i = 1
    for j, c in ipairs(claves) do if c == actual then i = j end end
    i = ((i - 1 + paso) % math.max(1, #claves)) + 1
    local cl, ra = (claves[i] or actual):match("^(.-)|(.+)$")
    WowF.verComoPoner(cl, ra, vc.nivel); otra()
  end
  local bx = x + 16
  local _, w1 = k:boton(bx, yy, "«", "secundario", true, function() mover(-1) end, { ayuda = L("Clase y rama anterior", "Previous class and spec") })
  bx = bx + (tonumber(w1) or 30) + 6
  local _, w2 = k:boton(bx, yy, "»", "secundario", true, function() mover(1) end, { ayuda = L("Clase y rama siguiente", "Next class and spec") })
  bx = bx + (tonumber(w2) or 30) + 14
  local _, w3 = k:boton(bx, yy, L("Nivel -", "Level -"), "secundario", true, function() WowF.verComoPoner(vc.clase, vc.rama, vc.nivel - 1); otra() end)
  bx = bx + (tonumber(w3) or 60) + 6
  local _, w4 = k:boton(bx, yy, L("Nivel +", "Level +"), "secundario", true, function() WowF.verComoPoner(vc.clase, vc.rama, vc.nivel + 1); otra() end)
  bx = bx + (tonumber(w4) or 60) + 14
  k:boton(bx, yy, L("Volver a mí", "Back to me"), "estandarte", true, function() WowF.verComoQuitar(); otra() end)
  yy = yy + 28 + 6
  local _, h2 = k:texto(x + 16, yy, L("Solo cambia la lista BiS y el nivel; la facción sigue siendo la tuya y la siguiente mejora se oculta mientras miras.",
    "Only the BiS list and the level change; the faction stays yours and the next upgrade is hidden while you look."), { tam = 12, color = col.tenue, ancho = w - 32 })
  yy = yy + h2 + 12
  card:SetHeight(yy - y); k:hasta(yy)
  return yy + 12
end

-- ===================== Ventana wowFCaza =====================
local ventana, kit, pestana = nil, nil, "activa"
local ANCHO, ALTO, MAX = 440, 500, 7
local ORIGEN = {
  bis = function() return L("Guía BiS", "BiS guide") end,
  mazmorra = function() return L("Mazmorra", "Dungeon") end,
  mision = function() return L("Misión", "Quest") end,
}
local function crear()
  if ventana then return ventana end
  local E = WowF.estilo
  local v = CreateFrame("Frame", "wowFCaza", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  v:SetSize(ANCHO, ALTO)
  v:SetPoint("CENTER", 0, 40)
  v:SetFrameStrata("DIALOG")
  if E and E.marco then E.marco(v, "aviso") end
  v:EnableMouse(true); v:SetMovable(true); v:RegisterForDrag("LeftButton")
  v:SetScript("OnDragStart", v.StartMoving)
  v:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); if E and E.guardarPos then E.guardarPos(s, "cazaPos") end end)
  if E and E.ponerPos then E.ponerPos(v, "cazaPos") end
  if E and E.cabecera then
    v.cab = E.cabecera(v, 20)
    v.cab.titulo:SetText("FOREVER GUIDE")
  end
  local x = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
  if E and E.boton then E.boton(x, "cuero", 11) end
  x:SetSize(18, 18); x:SetText("X"); x:SetPoint("TOPRIGHT", -8, -8)
  x:SetScript("OnClick", function() v:Hide() end)
  local cont = CreateFrame("Frame", nil, v)
  cont:SetPoint("TOPLEFT", 0, -30); cont:SetPoint("BOTTOMRIGHT", 0, 0)
  kit = WowF.vistaKit and WowF.vistaKit.nuevo(cont)
  ventana = v
  v:Hide()
  return v
end
local function dibujar()
  if not ventana or not kit then return end
  local k = kit
  local col = (WowF.estilo and WowF.estilo.color) or {}
  k:empezar()
  local x0, w = 16, ANCHO - 32
  local _, ht = k:texto(x0, 10, L("Piezas que buscas", "Items you track"), { tam = 18, letra = "marca" })
  local y = 10 + ht + 10
  local n = { activa = #WowF.cazaLista("activa"), conseguida = #WowF.cazaLista("conseguida"), quitada = #WowF.cazaLista("quitada") }
  k:seg(x0, y, {
    { "activa", L("Activas", "Active") .. " (" .. n.activa .. ")" },
    { "conseguida", L("Conseguidas", "Obtained") .. " (" .. n.conseguida .. ")" },
    { "quitada", L("Quitadas", "Removed") .. " (" .. n.quitada .. ")" },
  }, pestana, function(c) pestana = c; dibujar() end)
  y = y + 28 + 12
  local filas = WowF.cazaLista(pestana)
  table.sort(filas, function(a, b) return (a.fecha or 0) > (b.fecha or 0) end)
  if #filas == 0 then
    local vacio = (pestana == "activa") and L("Tu lista está vacía. Pulsa Anotar en una pieza de Equipo o de BiS 30: el addon te avisa cuando la consigas y te lleva a donde sale.", "Your list is empty. Press Track on an item in Gear or BiS 30: the addon tells you when you get it and takes you where it drops.")
      or (pestana == "conseguida") and L("Aún no has conseguido ninguna pieza de la lista.", "You have not obtained any item from the list yet.")
      or L("No has quitado ninguna pieza.", "You have not removed any item.")
    k:texto(x0, y, vacio, { tam = 13, color = col.tenue, ancho = w })
  end
  for i, e in ipairs(filas) do
    if i > MAX then
      k:texto(x0, y, L("y " .. (#filas - MAX) .. " más", "and " .. (#filas - MAX) .. " more"), { tam = 12, color = col.tenue })
      break
    end
    local card = k:tarjeta(x0, y, w, 50, e.estado == "activa" and "principal" or nil)
    local ic = WowF.iconoObjeto and WowF.iconoObjeto(e.id) -- 12-oct: cliente primero, datos de respaldo, sin signo de interrogacion
    k:icono(x0 + 10, y + 9, 32, ic, e.estado == "conseguida" and "verde" or nil, e.estado == "quitada")
    k:texto(x0 + 52, y + 8, e.n or nombreDe(e.id), { tam = 13, peso = "negrita", ancho = w - 52 - 120 })
    local origen = (ORIGEN[e.tipo or "bis"] or ORIGEN.bis)() .. ((e.tipo == "mazmorra" and e.mazmorra) and (": " .. e.mazmorra) or "")
      .. ((e.tipo == "mision" and type(e.mision) == "table" and e.mision.nombre) and (": " .. e.mision.nombre) or "")
      .. ((e.tipo == "bis" and e.hueco) and (" · " .. e.hueco) or "")
    k:texto(x0 + 52, y + 26, Y(origen), { tam = 12, color = col.tenue, ancho = w - 52 - 120 })
    local id = e.id
    if e.estado == "activa" then
      k:zona(x0, y, w - 110, 50, function() WowF.cazaIr(id) end, L("Clic: te llevo a conseguirla", "Click: I take you to get it"))
      k:boton(x0 + w - 10, y + 11, L("Quitar", "Remove"), "secundario", true, function() WowF.cazaQuitar(id) end, { derecha = true })
    elseif e.estado == "quitada" then
      k:boton(x0 + w - 10, y + 11, L("Anotar", "Track"), "secundario", true, function() WowF.cazaPerseguir({ id = id }) end, { derecha = true })
    else
      k:boton(x0 + w - 10, y + 11, L("Borrar", "Delete"), "secundario", true, function() WowF.cazaBorrar(id) end, { derecha = true })
    end
    y = y + 50 + 8
  end
  ventana.estado = { pestana = pestana, filas = filas }
end
function WowF.cazaRefrescar() if ventana and ventana:IsShown() then dibujar() end end
function WowF.cazaAbrir(p)
  crear()
  if p == "activa" or p == "conseguida" or p == "quitada" then pestana = p end
  ventana:Show()
  if WowF.estilo and WowF.estilo.alFrente then WowF.estilo.alFrente(ventana) end
  dibujar()
  return ventana
end
function WowF.cazaPestana(p) pestana = p; if ventana then dibujar() end end

-- ===================== Eventos =====================
local ev = CreateFrame("Frame")
local pendiente = false
local function programar()
  if pendiente then return end
  pendiente = true
  local function hacer() pendiente = false; pcall(WowF.cazaRevisar) end
  if C_Timer and C_Timer.After then C_Timer.After(1, hacer) else hacer() end
end
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("CHAT_MSG_LOOT")
pcall(ev.RegisterEvent, ev, "BAG_UPDATE_DELAYED")
ev:RegisterEvent("BAG_UPDATE")
ev:SetScript("OnEvent", function(_, evento)
  if evento == "PLAYER_LOGIN" then
    if WowF.aplicarMinimapa then pcall(WowF.aplicarMinimapa) end
  end
  if #WowF.cazaLista("activa") > 0 then programar() end
end)

-- ===================== Ajustes y comandos =====================
if WowF.registrarCasillaOpciones then
  WowF.registrarCasillaOpciones("ocultarMinimapa", function() return L("Ocultar el botón del minimapa (/wowf sigue abriendo la guía)", "Hide the minimap button (/wowf still opens the guide)") end, true,
    function() if WowF.aplicarMinimapa then WowF.aplicarMinimapa() end end)
end
function WowF.ponerMinimapa(visible)
  if type(WowFExportarDB) ~= "table" then WowFExportarDB = {} end
  WowFExportarDB.ocultarMinimapa = not visible
  if WowF.aplicarMinimapa then pcall(WowF.aplicarMinimapa) end
  print(AZUL .. (visible and L("botón del minimapa visible.", "minimap button shown.") or L("botón del minimapa oculto. Vuelve con /wowf minimapa on.", "minimap button hidden. Bring it back with /wowf minimap on.")))
end

local ordenAnterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje, ...)
  local m = strtrim and strtrim(mensaje or "") or (mensaje or "")
  local orden, resto = m:match("^(%S+)%s*(.-)$")
  orden = orden and orden:lower() or ""
  if orden == "caza" or orden == "hunt" then
    local p = ({ activas = "activa", active = "activa", conseguidas = "conseguida", obtained = "conseguida", quitadas = "quitada", removed = "quitada" })[(resto or ""):lower()]
    WowF.cazaAbrir(p)
    return
  end
  if orden == "minimapa" or orden == "minimap" then
    local a = (resto or ""):lower()
    if a == "on" then WowF.ponerMinimapa(true)
    elseif a == "off" then WowF.ponerMinimapa(false)
    else WowF.ponerMinimapa(type(WowFExportarDB) == "table" and WowFExportarDB.ocultarMinimapa == true) end
    return
  end
  if orden == "vercomo" or orden == "viewas" then
    local a = (resto or ""):lower()
    if a == "" or a == "off" then
      WowF.verComoQuitar()
      print(AZUL .. L("vuelves a ver tu personaje.", "back to your own character."))
    else
      local cl, ra, nv = resto:match("^(%S+)%s+(%S+)%s*(%d*)$")
      if cl and WowF.verComoPoner(cl:upper(), ra, tonumber(nv)) then
        print(AZUL .. Y(L("estás viendo otro personaje: ", "you are viewing another character: ") .. nombreClase(vc.clase) .. " " .. vc.rama .. " · " .. L("nivel ", "level ") .. vc.nivel
          .. L(" (Equipo y BiS 30; /wowf vercomo off = volver a ti)", " (Gear and BiS 30; /wowf viewas off = back to you)")))
      else
        print(AZUL .. L("uso: /wowf vercomo <clase> <rama> [nivel], p. ej. /wowf vercomo mage frost 20", "usage: /wowf viewas <class> <spec> [level], e.g. /wowf viewas mage frost 20"))
      end
    end
    redibujar()
    return
  end
  if ordenAnterior then return ordenAnterior(mensaje, ...) end
end
