-- Forever Leveling Guide: vistas nativas por tarjetas de 4 sub-pestanas de Profesiones (16-oct, Andy: "no me gusta, es una
-- lista de texto plano para abajo... que tenga sus cajitas, que luzca profesional, acorde a todo lo visual del addon;
-- hay muchos cuadros negros").
--   WowF.vistaCajas(k, p, y, ancho)       Cajas y favor (Merchant's Favor + Waylaid Crates)
--   WowF.vistaCampamento(k, p, y, ancho)  Campamento (guia de bufos + objetos de profesion)
--   WowF.vistaReputacion(k, p, y, ancho)  Reputacion (nativa, con barras del color del rango)
--   WowF.vistaLegacy(k, p, y, ancho)      Legacy (nativa, perks por arbol)
-- Todas devuelven la y final. Los MISMOS datos y acciones que las secciones viejas (WowF.seccionFavor, seccionGuiaCampamento,
-- seccionCampamento, seccionReputacion, seccionLegacy): Cajas y Campamento se "capturan" (la seccion vieja escribe en un h
-- falso y aqui se pinta en tarjetas); Reputacion y Legacy se dibujan directamente con sus APIs publicas.
-- Si algo falla, wowF_VistaProfesiones.lua vuelve a la vista vieja (flujo). Cero cuadros negros: todo icono tiene respaldo.

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function Y(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end
local function E() return WowF.estilo end
local function C() return (WowF.estilo and WowF.estilo.color) or {} end
local V = {}

V.SIN = function() return L("aún no hay datos de WoW Forever; pendiente de actualizar", "no WoW Forever data yet; pending update") end
V.PREG = "Interface\\Icons\\INV_Misc_QuestionMark"
V.IC = {
  bolsa = "Interface\\Icons\\INV_Misc_Bag_10", moneda = "Interface\\Icons\\INV_Misc_Coin_02", nota = "Interface\\Icons\\INV_Misc_Note_01",
  rep = "Interface\\Icons\\Achievement_Reputation_01", ficha = "Interface\\Icons\\INV_Misc_Token", caja = "Interface\\Icons\\INV_Crate_04",
  pergamino = "Interface\\Icons\\INV_Scroll_03", libro = "Interface\\Icons\\INV_Misc_Book_09", fuego = "Interface\\Icons\\Spell_Fire_Fire",
}
V.RANGO = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
V.GRUPOS = {
  { "ciudad", "Tu ciudad y aliadas", "Your capital and allies" },
  { "neutral", "Neutrales", "Neutral" },
  { "prof", "Profesiones", "Professions" },
  { "pvp", "PvP", "PvP" },
}
V.NOMBRE_OBJ = { fabricar = { "fabricarte el equipo", "crafting your gear" }, oro = { "ganar oro", "making gold" }, pvp = { "PvP", "PvP" } }
V.ARBOL = { { "Profesiones y comercio", "Professions and trade" }, { "Aventura", "Adventure" }, { "Combate, PvP y varios", "Combat, PvP and more" } }
V.FABRICAR = {
  { id = 171, titulo = "the Alchemist" }, { id = 164, titulo = "the Blacksmith" }, { id = 333, titulo = "the Enchanter" },
  { id = 202, titulo = "the Engineer" }, { id = 165, titulo = "the Leatherworker" }, { id = 197, titulo = "the Tailor" },
}
V.NOMBRE_PROF = { [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering", [165] = "Leatherworking", [197] = "Tailoring", [393] = "Skinning" }
V.ICONO_PROF = {
  [171] = "Interface\\Icons\\Trade_Alchemy", [164] = "Interface\\Icons\\Trade_BlackSmithing", [333] = "Interface\\Icons\\Trade_Engraving",
  [202] = "Interface\\Icons\\Trade_Engineering", [165] = "Interface\\Icons\\Trade_LeatherWorking", [197] = "Interface\\Icons\\Trade_Tailoring",
  [393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
}
-- color del juego -> clave del tema (igual que wowF_VistaProfesiones.lua)
V.RECOLOR = {}
for _, par in ipairs({ { "ffd100", "oro" }, { "33ff66", "verde" }, { "999999", "tenue" }, { "ffffff", "texto" }, { "ff9933", "brasa" }, { "66ccff", "orocl" } }) do V.RECOLOR[par[1]] = par[2] end
-- colores que abren un rotulo (titulo corto de un bloque)
V.ROTULO = { ffd100 = "oro", ["33ff66"] = "verde", ff9933 = "brasa", ["66ccff"] = "orocl" }

function V.recolor(s)
  if type(s) ~= "string" then return s end
  local cod = (E() and E().cod) or {}
  return (s:gsub("|c[fF][fF](%x%x%x%x%x%x)", function(hex)
    local n = V.RECOLOR[hex:lower()]
    return (n and cod[n]) or ("|cff" .. hex)
  end))
end
function V.limpio(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
function V.flecha() return WowF.vistaKit.acentoCod() .. "›|r" end
function V.nivel() return tonumber(UnitLevel and UnitLevel("player")) or 1 end
function V.lado()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  if f == "Horde" then return "H" elseif f == "Alliance" then return "A" end
  return nil
end
function V.miles(n)
  local s = tostring(math.floor(tonumber(n) or 0))
  local sep = L(".", ",")
  local r = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
  if r:sub(1, 1) == sep then r = r:sub(2) end
  return r
end
function V.profs()
  local t = {}
  if WowF.profesiones then
    local ok, lista = pcall(WowF.profesiones)
    if ok and type(lista) == "table" then for _, x in ipairs(lista) do if x.id then t[x.id] = tonumber(x.rango) or 0 end end end
  end
  return t
end
-- Icono: primero el del cliente para ESE objeto; luego la ruta o el nombre de los datos; si no, nil (el que pinta pone respaldo)
function V.icono(ic, id)
  if id and WowF.iconoObjeto then
    local ok, t = pcall(WowF.iconoObjeto, id, ic)
    if ok and t and t ~= "" and not (type(t) == "string" and t:lower():find("questionmark", 1, true)) then return t end
  end
  if type(ic) == "number" then return ic end
  if type(ic) == "string" and ic ~= "" then
    if ic:find("\\", 1, true) then
      if not ic:lower():find("questionmark", 1, true) then return ic end
    else
      return "Interface\\Icons\\" .. ic
    end
  end
  return nil
end
function V.iconoHechizo(id, resp)
  if WowF.iconoHechizo then
    local ok, t = pcall(WowF.iconoHechizo, id)
    if ok and t and t ~= "" and not (type(t) == "string" and t:lower():find("questionmark", 1, true)) then return t end
  end
  return resp or V.PREG
end

-- ===================== Captura: corre una seccion vieja con un h falso que guarda lo que escribe =====================
function V.capturar(fn, p, lista)
  lista = lista or {}
  if type(fn) ~= "function" then return lista end
  local h = {}
  function h.cab(texto, accion) table.insert(lista, { t = "cab", texto = texto, accion = accion }) end
  function h.nota(texto, accion) table.insert(lista, { t = "nota", texto = texto, accion = accion }) end
  function h.item(o) table.insert(lista, { t = "item", o = o or {} }) end
  function h.separador() table.insert(lista, { t = "sep" }) end
  function h.tarjetas(f) table.insert(lista, { t = "kit", fn = f }) end
  function h.fabricadas(l)
    for _, e in ipairs(l or {}) do
      local nombre = (WowFDatos and WowFDatos.obj and e.i and WowFDatos.obj[e.i] and WowFDatos.obj[e.i][1]) or tostring(e[3] or "?")
      h.item({ texto = Y(L("Nv ", "Lv ") .. tostring(e[1] or "?") .. "  " .. nombre), icono = V.icono(e.ic, e.i), objeto = e.i })
    end
  end
  h.icono = function(ic, id) return V.icono(ic, id) end
  h.obj = function(id)
    local o = WowFDatos and WowFDatos.obj and WowFDatos.obj[id]
    if o then return o[1], o[2], o[3], o[4] end
    return "objeto " .. tostring(id), 1, "", nil
  end
  h.colorCalidad = function(q)
    if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] and ITEM_QUALITY_COLORS[q].hex then return ITEM_QUALITY_COLORS[q].hex end
    return ({ [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" })[q] or "|cffffffff"
  end
  h.tengo = function(id) return (GetItemCount and GetItemCount(id, true)) or 0 end
  h.nivelActual = V.nivel
  local ok, err = pcall(fn, p, h)
  if not ok then
    table.insert(lista, { t = "nota", texto = "|cff999999" .. V.SIN() .. "|r" })
    WowF.libroErrorVista = "Profesiones: " .. tostring(err)
  end
  return lista
end

-- Clasifica una linea de nota: "paso" (1. ...), "rotulo" (titulo corto en color) o "parrafo"
function V.clase(linea)
  local l = V.limpio(linea)
  local n, resto = l:match("^%s*(%d+)%.%s+(.+)$")
  if n then return "paso", n end
  local hex, dentro, despues = linea:match("^|c[fF][fF](%x%x%x%x%x%x)(.-)|r(.*)$")
  if hex and V.ROTULO[hex:lower()] then
    local d = V.limpio(dentro):gsub("%s+$", "")
    if d ~= "" and #d <= 48 and not d:find("[%.!]$") and not d:find("\n") then return "rotulo", V.ROTULO[hex:lower()], d, despues end
  end
  return "parrafo"
end

-- ===================== Pintar lo capturado: tarjetas con titulo, rotulos, pasos y rejillas de casillas =====================
function V.pintar(k, y, ancho, lista, resp)
  local K = WowF.vistaKit
  local cod = (E() and E().cod) or {}
  local t, ty, cy, ult = nil, nil, nil, nil
  local x, w = 0, ancho
  local function cerrar()
    if not t then return end
    local fin = cy + 6
    t:SetHeight(fin - ty)
    k:hasta(fin)
    y = fin + 12
    t = nil
  end
  local function abrir()
    cerrar()
    ty = y
    t = k:tarjeta(x, ty, w, 40)
    cy = ty + 16
    ult = nil
  end
  local function titulo(texto, accion)
    abrir()
    local tw = w - 32 - (accion and 24 or 0)
    local _, h = k:texto(x + 16, cy, Y(V.limpio(texto)), { tam = 16, letra = "marca", color = C().texto, ancho = tw })
    if accion then
      k:texto(x + w - 28, cy, V.flecha(), { tam = 16, sinAnotar = true })
      k:zona(x, cy - 4, w, h + 8, accion)
    end
    cy = cy + h + 6
    k:raya(x + 16, cy, w - 32)
    cy = cy + 10
  end
  local function asegurar() if not t then abrir() end end
  local function linea(txt, accion)
    local clase, a, b, c = V.clase(txt)
    local tw = w - 32 - (accion and 24 or 0)
    if clase == "rotulo" and ult then cy = cy + 4 end
    local y0 = cy
    if clase == "rotulo" then
      k:rotulo(x + 16, cy, Y(b), C()[a] or C().oro)
      cy = cy + 18
      local resto = V.limpio(c or "")
      if resto:gsub("%s", "") ~= "" then
        local cuerpo = (c or ""):gsub("^%s+", "")
        local _, h2 = k:texto(x + 16, cy, Y(V.recolor(cuerpo)), { tam = 12, color = C().tenue, ancho = tw })
        cy = cy + h2 + 4
      end
      cy = cy + 2
    elseif clase == "paso" then
      k:bola(x + 16, cy - 2, a)
      local cuerpo = txt:gsub("^(|c%x%x%x%x%x%x%x%x)%s*%d+%.%s+", "%1")
      cuerpo = cuerpo:gsub("^%s*%d+%.%s+", "")
      local _, hp = k:texto(x + 46, cy + 2, Y(V.recolor(cuerpo)), { tam = 13, color = K.CLARO or C().texto, ancho = tw - 30 })
      cy = cy + math.max(22, hp + 2) + 8
    else
      local _, hp = k:texto(x + 16, cy, Y(V.recolor(txt)), { tam = 13, color = C().tenue, ancho = tw })
      cy = cy + hp + 8
    end
    if accion then
      local alto = cy - 8 - y0
      k:texto(x + w - 28, y0 + math.max(0, (alto - 16) / 2), V.flecha(), { tam = 16, sinAnotar = true })
      k:zona(x + 8, y0 - 3, w - 16, alto + 6, accion, L("Clic", "Click"))
    end
    ult = "nota"
  end
  local function nota(texto, accion)
    asegurar()
    texto = tostring(texto or "")
    -- las notas de varias lineas (ej. "Como se consigue:" + pasos) se parten y cada linea toma su forma
    local partes = {}
    for l in (texto .. "\n"):gmatch("(.-)\n") do if V.limpio(l):gsub("%s", "") ~= "" then table.insert(partes, l) end end
    for i, l in ipairs(partes) do linea(l, (i == #partes) and accion or nil) end
  end
  -- Rejilla de casillas: icono real, nombre, linea tenue, flecha si hay clic; filas con la misma altura
  local function rejilla(items)
    asegurar()
    if ult then cy = cy + 2 end
    local gx, gw = x + 16, w - 32
    local cols = (gw >= 460) and 2 or 1
    if gw >= 700 then
      local cortas = true
      for _, o in ipairs(items) do if #V.limpio(o.sub or "") > 90 or #V.limpio(o.texto or "") > 54 or (o.sub or ""):find("\n") then cortas = false end end
      if cortas and #items >= 3 then cols = 3 end
    end
    local gap = 10
    local bw = (gw - gap * (cols - 1)) / cols
    local i = 1
    while i <= #items do
      local fila, altoFila = {}, 60
      for c = 0, cols - 1 do
        local o = items[i + c]
        if not o then break end
        local bx = gx + c * (bw + gap)
        local cas = k:tarjeta(bx, cy, bw, 60, nil, K.CASILLA, K.CASILLA_BORDE, true)
        local tam = 36
        k:icono(bx + 12, cy + 12, tam, o.icono or (o.objeto and V.icono(nil, o.objeto)) or resp or V.PREG)
        local tx = bx + 12 + tam + 10
        local tw = bx + bw - 12 - tx - (o.accion and 18 or 0)
        local _, h1 = k:texto(tx, cy + 11, Y(V.recolor(o.texto or "")), { tam = 13, peso = "medio", color = C().texto, ancho = tw })
        local alto = 11 + h1
        if o.sub and o.sub ~= "" then
          local _, h2 = k:texto(tx, cy + alto + 3, Y(V.recolor(o.sub)), { tam = 12, color = C().tenue, ancho = tw })
          alto = alto + 3 + h2
        end
        alto = math.max(60, alto + 12)
        if o.accion then k:texto(bx + bw - 20, cy + 12, V.flecha(), { tam = 16, sinAnotar = true }) end
        table.insert(fila, { cas = cas, bx = bx, o = o })
        if alto > altoFila then altoFila = alto end
      end
      for _, e in ipairs(fila) do
        e.cas:SetHeight(altoFila)
        local o = e.o
        if o.accion or o.objeto or o.ayuda then
          local ayuda = o.ayuda
          if o.objeto then
            local id, nom = o.objeto, V.limpio(o.texto)
            ayuda = function(tt)
              local ok = tt.SetItemByID and pcall(tt.SetItemByID, tt, id)
              if not ok then tt:SetText(nom, 1, 1, 1) end
            end
          elseif not ayuda and o.accion then ayuda = L("Clic", "Click") end
          k:zona(e.bx, cy, bw, altoFila, o.accion, ayuda)
        end
      end
      k:hasta(cy + altoFila)
      cy = cy + altoFila + gap
      i = i + cols
    end
    cy = cy + 2
    ult = "item"
  end
  local i = 1
  while i <= #lista do
    local e = lista[i]
    if e.t == "cab" then
      titulo(e.texto, e.accion)
      i = i + 1
    elseif e.t == "nota" then
      nota(e.texto, e.accion)
      i = i + 1
    elseif e.t == "item" then
      local items = {}
      while lista[i] and lista[i].t == "item" do table.insert(items, lista[i].o); i = i + 1 end
      rejilla(items)
    elseif e.t == "sep" then
      cerrar()
      i = i + 1
    elseif e.t == "kit" then
      cerrar()
      local ok, ny = pcall(e.fn, k, 0, y, ancho)
      if ok and type(ny) == "number" then k:hasta(ny); y = ny + 12
      elseif not ok then WowF.libroErrorVista = "Profesiones: " .. tostring(ny) end
      i = i + 1
    else
      i = i + 1
    end
  end
  cerrar()
  return y
end

-- ===================== Tarjeta heroe: icono, titulo "marca", frase y cifras clave =====================
-- cifras = { { n, rotulo }, ... } ; boton = { texto, fn, ayuda } (opcional)
function V.heroe(k, y, ancho, icono, titulo, frase, cifras, boton)
  local t = k:tarjeta(0, y, ancho, 120, "principal")
  k:icono(20, y + 20, 48, icono or V.PREG, "oro")
  local bw = 0
  if boton then
    local _, w = k:boton(ancho - 20, y + 20, boton[1], "secundario", true, boton[2], { derecha = true, ayuda = boton[3] })
    bw = (tonumber(w) or 140) + 16
  end
  local tx = 84
  local _, ht = k:texto(tx, y + 18, Y(titulo), { tam = 20, letra = "marca", color = C().texto, ancho = ancho - tx - 20 - bw })
  local cy = y + 18 + ht + 6
  if frase and frase ~= "" then
    local _, hf = k:texto(tx, cy, Y(frase), { tam = 13, color = WowF.vistaKit.CLARO or C().tenue, ancho = ancho - tx - 20 - bw })
    cy = cy + hf + 10
  end
  if cifras and #cifras > 0 then
    -- 16-oct: cada cifra ocupa lo que mide su rotulo (+24); con paso fijo de 150 los rotulos largos se pisaban
    local dx, limite = 0, ancho - tx - 20
    for _, c in ipairs(cifras) do
      local ce, w = k:cifra(tx + dx, cy, c[1], c[2])
      w = math.max(150, (tonumber(w) or 60) + 24)
      if dx > 0 and dx + w > limite + 24 then
        dx = 0; cy = cy + 52
        if ce and ce.ClearAllPoints then ce:ClearAllPoints(); ce:SetPoint("TOPLEFT", k.marco, "TOPLEFT", tx, -cy) end
      end
      dx = dx + w
    end
    cy = cy + 48
  end
  local fin = math.max(cy, y + 20 + 48) + 14
  t:SetHeight(fin - y)
  k:hasta(fin)
  return fin + 14
end

-- Tarjeta de aviso (sin datos, sin faccion...)
function V.aviso(k, y, ancho, texto, icono)
  local t = k:tarjeta(0, y, ancho, 60, "hundida")
  k:icono(16, y + 14, 32, icono or V.IC.nota, "gris")
  local _, h = k:texto(60, y + 18, Y(texto), { tam = 13, color = C().tenue, ancho = ancho - 76 })
  local fin = math.max(y + 60, y + 18 + h + 16)
  t:SetHeight(fin - y)
  k:hasta(fin)
  return fin + 12
end

-- Titulo de bloque (fuera de tarjeta): letra marca + raya
function V.bloque(k, y, ancho, texto, extra)
  local _, h = k:texto(0, y, Y(texto), { tam = 16, letra = "marca", color = C().texto, ancho = ancho - 200 })
  if extra and extra ~= "" then k:chip(ancho, y, extra, "neutro", true) end
  local yr = y + h + 6
  k:raya(0, yr, ancho)
  return yr + 12
end

-- ===================== Cajas y favor =====================
function WowF.vistaCajas(k, p, y, ancho)
  local favor = WowF.favorActual and tonumber((select(2, pcall(WowF.favorActual)))) or nil
  local nivelF = WowF.favorNivel and select(2, pcall(WowF.favorNivel)) or nil
  local okE, entrega = false, nil
  if WowF.entregaFavor then okE, entrega = pcall(WowF.entregaFavor) end
  local nCajas = 0
  if WowF.favorCajasEnBolsas then
    local ok, l = pcall(WowF.favorCajasEnBolsas)
    if ok and type(l) == "table" then nCajas = #l end
  end
  local cifras = {
    { favor and V.miles(favor) or "?", L("tu Merchant's Favor", "your Merchant's Favor") },
    { tonumber(nivelF) and tostring(nivelF) or "?", L("nivel en que se abre", "unlock level") },
    { tostring(nCajas), L("cajas en tus bolsas", "crates in your bags") },
  }
  local boton = (okE and type(entrega) == "table" and WowF.irEntregaFavor) and { L("Ir a la entrega", "Go to the turn-in"), function() pcall(WowF.irEntregaFavor) end,
    L("Ruta paso a paso al campamento donde se entregan las cajas.", "Step-by-step route to the camp where crates are turned in.") } or nil
  y = V.heroe(k, y, ancho, V.IC.moneda, "Merchant's Favor",
    L("La moneda de las profesiones: llenas Waylaid Crates con materiales, las entregas en tu campamento y compras recetas.",
      "The profession currency: fill Waylaid Crates with materials, turn them in at your camp and buy recipes."), cifras, boton)
  if not WowF.seccionFavor then return V.aviso(k, y, ancho, V.SIN(), V.IC.moneda) end
  local lista = V.capturar(WowF.seccionFavor, p)
  -- el heroe ya lleva el titulo y tu Favor: fuera la primera cabecera y la linea "Tienes: N"
  local res, quitada = {}, false
  local tienes = L("Tienes: ", "You have: ")
  for _, e in ipairs(lista) do
    if e.t == "cab" and not quitada then quitada = true
    elseif e.t == "nota" and favor and V.limpio(e.texto):sub(1, #tienes) == tienes then -- ya esta en la cifra
    else table.insert(res, e) end
  end
  return V.pintar(k, y, ancho, res, V.IC.caja)
end

-- ===================== Campamento =====================
function WowF.vistaCampamento(k, p, y, ancho)
  local espera = 60
  if WowF.esperaCampamento then local ok, n = pcall(WowF.esperaCampamento, 60); if ok and tonumber(n) then espera = tonumber(n) end end
  local ya, total = 0, 0
  if WowF.campamentoProfesiones and WowF.campamentoDeProfesion then
    local ok, lp = pcall(WowF.campamentoProfesiones)
    for _, pr in ipairs((ok and type(lp) == "table" and lp) or {}) do
      local ok2, r = pcall(WowF.campamentoDeProfesion, pr.id, pr.rango)
      if ok2 and type(r) == "table" then ya = ya + #(r.ya or {}); total = total + #(r.ya or {}) + #(r.prox or {}) end
    end
  end
  local g = WowFGuiaCampamento
  local nBufos = (type(g) == "table" and type(g.buffs) == "table") and #g.buffs or 0
  local cifras = {
    { espera .. " min", L("espera entre objetos", "cooldown between items") },
    { nBufos > 0 and tostring(nBufos) or "?", L("bufos del campamento", "camp buffs") },
    { ya .. "/" .. total, L("objetos que ya puedes", "items you can make now") },
  }
  y = V.heroe(k, y, ancho, V.IC.fuego, L("Campamento", "Camp"),
    L("Qué bufos dar a tu grupo según tu rol y qué objetos de campamento puedes poner con tus profesiones.",
      "Which buffs to give your group for your role and which camp items you can place with your professions."), cifras)
  if not (WowF.seccionGuiaCampamento or WowF.seccionCampamento) then return V.aviso(k, y, ancho, V.SIN(), V.IC.bolsa) end
  local lista = {}
  V.capturar(WowF.seccionGuiaCampamento, p, lista)
  table.insert(lista, { t = "sep" })
  V.capturar(WowF.seccionCampamento, p, lista)
  return V.pintar(k, y, ancho, lista, V.IC.bolsa)
end

-- ===================== Reputacion (nativa) =====================
-- estado de una faccion: { rango, nombre, cur, max } o nil + texto del motivo
function V.repEstado(id)
  if not WowF.repEstado then return nil, L("no se pudo leer", "could not be read") end
  local ok, e, por = pcall(WowF.repEstado, id)
  if ok and type(e) == "table" and tonumber(e.rango) then return e end
  if ok and por == "nueva" then return nil, L("aún no la conoces", "not discovered yet") end
  return nil, L("no se pudo leer", "could not be read")
end
-- chip del rango + barra del color del rango; devuelve la y final
function V.repEstadoPintar(k, x, y, w, id)
  local e, motivo = V.repEstado(id)
  if not e then
    k:chip(x, y, motivo, "gris")
    return y + 24
  end
  local r = tonumber(e.rango) or 4
  local color = (r >= 5 and "verde") or (r == 4 and "neutro") or "brasa"
  local _, cw = k:chip(x, y, e.nombre or V.RANGO[r] or "?", color)
  if e.cur and e.max and tonumber(e.max) and tonumber(e.max) > 0 then
    k:texto(x + (tonumber(cw) or 70) + 8, y + 3, V.miles(e.cur) .. "/" .. V.miles(e.max), { tam = 12, color = C().tenue, sinAnotar = true })
  end
  local b
  if r == 8 then b = k:barra(x, y + 28, w, 1, 1, "verde")
  elseif e.cur and e.max and tonumber(e.max) and tonumber(e.max) > 0 then b = k:barra(x, y + 28, w, tonumber(e.cur) or 0, tonumber(e.max), r >= 5 and "verde" or nil)
  else return y + 26 end
  if r == 4 and b and b.relleno and b.relleno.SetColorTexture then
    local c = C().texto or { 0.9, 0.85, 0.75 }
    pcall(b.relleno.SetColorTexture, b.relleno, c[1], c[2], c[3], 1)
  end
  return y + 40
end
-- Fila pequena dentro de una tarjeta de faccion (icono opcional, texto, sub, flecha/clic)
function V.fila(k, x, y, w, o)
  local tx, tam = x, 0
  if o.icono ~= false then tam = 28; k:icono(x, y, tam, o.icono or V.IC.ficha); tx = x + tam + 8 end
  local tw = x + w - tx - (o.accion and 18 or 0)
  local _, h1 = k:texto(tx, y, Y(V.recolor(o.texto or "")), { tam = 13, peso = "medio", color = C().texto, ancho = tw })
  local alto = h1
  if o.sub and o.sub ~= "" then
    local _, h2 = k:texto(tx, y + h1 + 2, Y(V.recolor(o.sub)), { tam = 12, color = C().tenue, ancho = tw })
    alto = h1 + 2 + h2
  end
  if tam > alto then alto = tam end
  if o.accion then
    k:texto(x + w - 14, y + math.max(0, (alto - 16) / 2), V.flecha(), { tam = 16, sinAnotar = true })
    k:zona(x - 6, y - 3, w + 12, alto + 6, o.accion, o.ayuda or L("Clic", "Click"))
  end
  return y + alto + 8
end
function V.zonaTexto(g)
  local d = WowFReputacion
  if type(g.z) == "number" then return (g.z ~= 0 and d and d.zonas and d.zonas[g.z]) or (L("zona ", "zone ") .. g.z) end
  if g.z == "clase" then return L("misiones de tu clase", "your class quests") end
  if g.z == "jcj" then return L("campos de batalla", "battlegrounds") end
  if g.z == "feria" then return "Darkmoon Faire" end
  return L("otras misiones", "other quests")
end
-- Tarjeta de una faccion (contenido de pintarFaccion de wowF_Reputacion.lua); devuelve tarjeta y y final
function V.faccion(k, f, x, y, w, N, profs, comp)
  local cod = (E() and E().cod) or {}
  local t = k:tarjeta(x, y, w, 80)
  local en = WowF.enIngles and WowF.enIngles()
  k:icono(x + 14, y + 14, 36, V.IC.rep, "oro")
  local tx = x + 60
  local tw = x + w - 14 - tx - 18
  local _, hn = k:texto(tx, y + 14, Y(f.n or "?"), { tam = 15, letra = "marca", color = C().texto, ancho = tw })
  local cy = y + 14 + hn + 2
  local desc = en and f.en or f.es
  if desc and desc ~= "" then
    local _, hd = k:texto(tx, cy, Y(desc), { tam = 12, color = C().tenue, ancho = tw })
    cy = cy + hd
  end
  k:texto(x + w - 26, y + 18, V.flecha(), { tam = 16, sinAnotar = true })
  if WowF.irFaccionRep then
    k:zona(x, y, w, math.max(50, cy - y + 4), function() pcall(WowF.irFaccionRep, f) end,
      L("Clic: ruta a la capital o al vendedor de esta facción.", "Click: route to this faction's capital or vendor."))
  end
  cy = math.max(cy, y + 50) + 8
  cy = V.repEstadoPintar(k, x + 14, cy, w - 28, f.id) + 4
  local ix, iw = x + 14, w - 28
  local function parrafo(txt, color)
    local _, h = k:texto(ix, cy, Y(txt), { tam = 12, color = color or C().tenue, ancho = iw })
    cy = cy + h + 6
  end
  if not f.datos then
    parrafo(L("Esta facción: ", "This faction: ") .. V.SIN() .. ".", C().brasa)
    t:SetHeight(cy + 6 - y); k:hasta(cy + 6)
    return t, cy + 6
  end
  if (tonumber(f.nv) or 0) > N then parrafo(L("Se abre a nivel ", "Unlocks at level ") .. f.nv .. ".", C().brasa) end
  for _, c in ipairs(f.como or {}) do parrafo((cod.orocl or "") .. "» |r" .. (en and c[2] or c[1]), WowF.vistaKit.CLARO) end
  local ya, pronto = {}, {}
  if WowF.repMisiones then local ok, a, b = pcall(WowF.repMisiones, f, N); if ok then ya, pronto = a or {}, b or {} end end
  local zs = {}
  if WowF.repZonas then local ok, z = pcall(WowF.repZonas, ya); if ok and type(z) == "table" then zs = z end end
  cy = cy + 2
  if #zs > 0 then
    k:rotulo(ix, cy, Y(L("Súbela ya", "Raise it now")), C().verde); cy = cy + 18
    for i = 1, math.min(3, #zs) do
      local g = zs[i]
      local ej = g.q and g.q[1] and g.q[1][2] or ""
      cy = V.fila(k, ix, cy, iw, { icono = false,
        texto = V.zonaTexto(g) .. (cod.tenue or "") .. ": " .. g.n .. L(" misiones, +", " quests, +") .. V.miles(g.rep) .. L(" (nivel ", " (level ") .. g.d .. "-" .. g.h .. ")|r",
        sub = (ej ~= "" and (L("p. ej. ", "e.g. ") .. ej .. (g.maz and L(" (mazmorra)", " (dungeon)") or "")) or nil),
        accion = WowF.irZonaRep and function() pcall(WowF.irZonaRep, f, g) end or nil,
        ayuda = L("Clic: ruta a la zona y alfiler en quien da las misiones.", "Click: route to the zone and a pin on the quest giver.") })
    end
  elseif #pronto > 0 then
    local rep = 0
    for _, q in ipairs(pronto) do rep = rep + (q[5] or 0) end
    parrafo(L("Próximas al subir: ", "Coming up as you level: ") .. #pronto .. L(" misiones (+", " quests (+") .. V.miles(rep) .. L(") desde nivel ", ") from level ") .. (pronto[1][3] or N) .. ".", C().brasa)
  elseif #(f.q or {}) == 0 then
    parrafo(L("Misiones con reputación: ", "Quests with reputation: ") .. V.SIN() .. ".")
  else
    parrafo(L("No quedan misiones de tu nivel que den esta reputación.", "No quests at your level give this reputation."))
  end
  -- Recompensas por rango
  if #(f.it or {}) == 0 then
    parrafo(L("Recompensas: ", "Rewards: ") .. V.SIN() .. ".")
  else
    cy = cy + 2
    k:rotulo(ix, cy, Y(L("Recompensas", "Rewards")), C().oro); cy = cy + 18
    local porRango = {}
    for _, o in ipairs(f.it) do local r = o[4] or 4; porRango[r] = porRango[r] or {}; table.insert(porRango[r], o) end
    for r = 4, 8 do
      local lista = porRango[r]
      if lista then
        local partes, utiles = {}, 0
        for _, o in ipairs(lista) do
          local sirve = false
          if WowF.repTeSirve then local ok, s = pcall(WowF.repTeSirve, o, N, profs, comp); sirve = ok and s and true or false end
          if sirve then utiles = utiles + 1 end
          if #partes < 6 then partes[#partes + 1] = (sirve and (cod.verde or "") or (cod.tenue or "")) .. tostring(o[2] or "?") .. "|r" end
        end
        local resto = #lista > 6 and ((cod.tenue or "") .. L(" y ", " and ") .. (#lista - 6) .. L(" más", " more") .. "|r") or ""
        local vend = tonumber(lista[1][9])
        cy = V.fila(k, ix, cy, iw, {
          icono = V.icono(nil, lista[1][1]) or V.IC.ficha,
          texto = (cod.oro or "") .. (V.RANGO[r] or "?") .. "|r" .. (cod.tenue or "") .. ": " .. #lista .. L(" recompensas", " rewards") .. "|r"
            .. (utiles > 0 and ((cod.tenue or "") .. ", |r" .. (cod.verde or "") .. utiles .. L(" te sirven", " useful for you") .. "|r") or ""),
          sub = table.concat(partes, (cod.tenue or "") .. ", |r") .. resto,
          accion = (vend and vend > 0 and WowF.irVendedorRep) and function() pcall(WowF.irVendedorRep, f, vend) end or nil,
          ayuda = L("Clic: ruta al vendedor de la facción.", "Click: route to the faction vendor.") })
      end
    end
  end
  for _, a in ipairs(f.avisos or {}) do parrafo(en and a[2] or a[1], C().brasa) end
  local fin = cy + 6
  t:SetHeight(fin - y)
  k:hasta(fin)
  return t, fin
end
-- Rejilla de tarjetas de faccion con la misma altura por fila
function V.rejillaFacciones(k, y, ancho, lista, N, profs, comp)
  local cols = (ancho >= 640) and 2 or 1
  local gap = 12
  local cw = (ancho - gap * (cols - 1)) / cols
  local i = 1
  while i <= #lista do
    local fila, fin = {}, y
    for c = 0, cols - 1 do
      local f = lista[i + c]
      if not f then break end
      local ok, t, ff = pcall(V.faccion, k, f, c * (cw + gap), y, cw, N, profs, comp)
      if ok and t then table.insert(fila, t); if ff > fin then fin = ff end
      elseif not ok then WowF.libroErrorVista = "Reputacion: " .. tostring(t) end
    end
    for _, t in ipairs(fila) do t:SetHeight(fin - y) end
    k:hasta(fin)
    y = fin + gap
    i = i + cols
  end
  return y
end

function WowF.vistaReputacion(k, p, y, ancho)
  local d = WowFReputacion
  local cod = (E() and E().cod) or {}
  local l, N = V.lado(), V.nivel()
  local objetivo = (p and p.objetivo) or (WowF.objetivo and select(2, pcall(WowF.objetivo))) or nil
  if type(objetivo) ~= "string" then objetivo = nil end
  local mias, amigas = 0, 0
  for _, f in ipairs((d and d.f) or {}) do
    if l and (f.lado == "N" or f.lado == l) then
      mias = mias + 1
      local e = V.repEstado(f.id)
      if e and (tonumber(e.rango) or 0) >= 5 then amigas = amigas + 1 end
    end
  end
  local rec = {}
  if d and l and WowF.repRecomendadas then local ok, r = pcall(WowF.repRecomendadas, objetivo, N); if ok and type(r) == "table" then rec = r end end
  y = V.heroe(k, y, ancho, V.IC.rep, L("Reputación", "Reputation"),
    L("Subes con misiones (y algunas facciones con entregas o con su moneda). Cada rango abre recompensas en su vendedor. Tu barra la lee el addon de tu juego.",
      "You raise it with quests (and some factions with turn-ins or their currency). Each rank unlocks rewards at its vendor. Your bar is read from your game."),
    { { tostring(mias), L("facciones de tu bando", "factions on your side") }, { tostring(amigas), L("en Friendly o más", "at Friendly or higher") },
      { tostring(math.min(3, #rec)), L("recomendadas para ti", "recommended for you") } })
  if not d then
    return V.aviso(k, y, ancho, L("Faltan los datos de reputación: reinstala el addon.", "Reputation data is missing: reinstall the addon."), V.IC.rep)
  end
  -- Como funciona: los rangos en chips + bonos
  do
    local t = k:tarjeta(0, y, ancho, 60)
    local cy = y + 14
    k:rotulo(16, cy, Y(L("Los rangos", "The ranks")), C().oro); cy = cy + 20
    local cx = 16
    for r, n in ipairs(V.RANGO) do
      local color = (r >= 5 and "verde") or (r == 4 and "neutro") or "brasa"
      local _, cw = k:chip(cx, cy, n, color)
      cw = tonumber(cw) or 70
      if cx + cw > ancho - 16 then cy = cy + 26; cx = 16; k:chip(cx, cy, n, color) end
      cx = cx + cw + 6
      if r < #V.RANGO then k:texto(cx - 1, cy + 3, (cod.tenue or "") .. "»|r", { tam = 12, sinAnotar = true }); cx = cx + 12 end
    end
    cy = cy + 32
    local rangoDip, valorDip = 0, 0
    if d.diplomat and WowF.legacyRango then
      local ok, r = pcall(WowF.legacyRango, d.diplomat)
      if ok and type(r) == "table" then rangoDip = tonumber(r.rango) or 0 end
    end
    if d.diplomat and WowF.legacyValor then
      local ok, v = pcall(WowF.legacyValor, d.diplomat)
      if ok then valorDip = tonumber(v) or 0 end
    end
    if #(d.bonos or {}) > 0 then
      k:rotulo(16, cy, Y(L("Bonos", "Bonuses")), C().oro); cy = cy + 20
      for _, b in ipairs(d.bonos) do
        local txt = (WowF.enIngles and WowF.enIngles()) and b.en or b.es
        if b.id == "legacy-diplomat" then
          if rangoDip > 0 then txt = (txt or "") .. (cod.verde or "") .. L(" Tienes rango ", " You have rank ") .. rangoDip .. (valorDip > 0 and (": +" .. valorDip .. "%") or "") .. ".|r"
          else txt = (txt or "") .. L(" No lo tienes (o no se pudo leer).", " You do not have it (or it could not be read).") end
        end
        k:icono(16, cy, 20, b.existe and V.IC.rep or V.IC.nota, b.existe and "oro" or "gris", not b.existe)
        local _, h = k:texto(44, cy + 2, Y(V.recolor(txt or "")), { tam = 12, color = b.existe and WowF.vistaKit.CLARO or C().tenue, ancho = ancho - 60 })
        cy = cy + math.max(20, h) + 8
      end
    end
    t:SetHeight(cy + 6 - y); k:hasta(cy + 6)
    y = cy + 18
  end
  if not l then
    return V.aviso(k, y, ancho, L("Elige facción primero: las reputaciones dependen de ella.", "Choose a faction first: reputations depend on it."), V.IC.rep)
  end
  local profs = V.profs()
  local comp
  if UnitClass then local _, token = UnitClass("player"); comp = WowFValiosos and WowFValiosos.clases and WowFValiosos.clases[token or ""] end
  -- Recomendadas para ti
  local nom = objetivo and V.NOMBRE_OBJ[objetivo]
  y = V.bloque(k, y, ancho, L("Recomendadas para ti", "Recommended for you"), nom and (L("objetivo: ", "goal: ") .. L(nom[1], nom[2])) or nil)
  if #rec == 0 then
    y = V.aviso(k, y, ancho, L("Ninguna facción de tu bando tiene algo para ti a tu nivel: ", "No faction of your side has something for you at your level: ") .. V.SIN() .. ".", V.IC.rep)
  else
    local n = math.min(3, #rec)
    local cols = (ancho >= 720) and n or ((ancho >= 460) and math.min(2, n) or 1)
    local gap = 12
    local cw = (ancho - gap * (cols - 1)) / cols
    local i = 1
    while i <= n do
      local fila, fin = {}, y
      for c = 0, cols - 1 do
        local r = rec[i + c]
        if not r or i + c > n then break end
        local x = c * (cw + gap)
        local t = k:tarjeta(x, y, cw, 80, (i + c == 1) and "recomendada" or nil)
        k:bola(x + 14, y + 14, tostring(i + c), (i + c == 1) and "ahora" or nil)
        local _, hn = k:texto(x + 46, y + 15, Y(r.f.n or "?"), { tam = 15, letra = "marca", color = C().texto, ancho = cw - 46 - 32 })
        k:texto(x + cw - 26, y + 16, V.flecha(), { tam = 16, sinAnotar = true })
        local cy = math.max(y + 40, y + 15 + hn + 8)
        cy = V.repEstadoPintar(k, x + 14, cy, cw - 28, r.f.id) + 2
        k:rotulo(x + 14, cy, Y(L("Por qué", "Why")), C().oro); cy = cy + 18
        local _, hp = k:texto(x + 14, cy, Y(table.concat(r.porque or {}, "; ") .. "."), { tam = 12, color = WowF.vistaKit.CLARO or C().tenue, ancho = cw - 28 })
        cy = cy + hp + 14
        local f = r.f
        k:zona(x, y, cw, cy - y, function() if WowF.irFaccionRep then pcall(WowF.irFaccionRep, f) end end,
          L("Clic: ruta a la capital o al vendedor de esta facción.", "Click: route to this faction's capital or vendor."))
        table.insert(fila, t)
        if cy > fin then fin = cy end
      end
      for _, t in ipairs(fila) do t:SetHeight(fin - y) end
      k:hasta(fin)
      y = fin + gap
      i = i + cols
    end
    y = y + 6
  end
  -- Cada faccion de tu bando, por grupos
  for _, gr in ipairs(V.GRUPOS) do
    local lista = {}
    for _, f in ipairs(d.f or {}) do if f.g == gr[1] and (f.lado == "N" or f.lado == l) then table.insert(lista, f) end end
    if #lista > 0 then
      y = V.bloque(k, y, ancho, L(gr[2], gr[3]), #lista .. L(" facciones", " factions"))
      y = V.rejillaFacciones(k, y, ancho, lista, N, profs, comp) + 6
    end
  end
  -- Fuente
  y = V.aviso(k, y, ancho, L("Datos de WoW Forever (Wowhead /forever, build ", "WoW Forever data (Wowhead /forever, build ") .. tostring(d.build or "?")
    .. L("). La reputación de cada misión es la de la fuente; lo que aún no está confirmado se dice y se actualizará en próximas actualizaciones.",
      "). Each quest's reputation is the source's; anything unconfirmed is marked and will be updated in future updates."), V.IC.nota)
  return y
end

-- ===================== Legacy (nativa) =====================
function WowF.vistaLegacy(k, p, y, ancho)
  local perks = WowF.LEGACY_PERKS
  local mias = V.profs()
  if WowF.legacyDiagnostico then pcall(WowF.legacyDiagnostico) end
  local function sirve(x)
    if not x.para then return true end
    for _, id in ipairs(x.para) do if mias[id] then return true end end
    return false
  end
  local function rango(id)
    if not WowF.legacyRango then return { rango = 0, seguro = false } end
    local ok, r = pcall(WowF.legacyRango, id)
    if ok and type(r) == "table" then return r end
    return { rango = 0, seguro = false }
  end
  -- perks por arbol: primero los que tienes, luego el resto (solo los que te sirven, como la vista vieja)
  local arboles, activos, total = { {}, {}, {} }, 0, 0
  for _, x in ipairs(type(perks) == "table" and perks or {}) do
    if arboles[x.a] and sirve(x) then
      local r = rango(x.id)
      local tiene = (tonumber(r.rango) or 0) > 0
      if tiene then activos = activos + 1 end
      total = total + 1
      table.insert(arboles[x.a], { x = x, r = r, tiene = tiene })
    end
  end
  for a = 1, 3 do table.sort(arboles[a], function(u, v) if u.tiene ~= v.tiene then return u.tiene end return false end) end
  y = V.heroe(k, y, ancho, V.IC.libro, "Legacy",
    L("Ventajas de tu cuenta (no Hardcore). Cada personaje gasta hasta 16 Legacy Points. Se abre con la tecla Y o el escudo del menú.",
      "Your account perks (not Hardcore). Each character spends up to 16 Legacy Points. Open it with the Y key or the shield in the menu."),
    { { activos .. "/" .. total, L("perks activos", "active perks") }, { "16", L("puntos por personaje", "points per character") } })
  if type(perks) ~= "table" or total == 0 then return V.aviso(k, y, ancho, V.SIN(), V.IC.libro) end
  local cod = (E() and E().cod) or {}
  local K = WowF.vistaKit
  for a = 1, 3 do
    local lista = arboles[a]
    if #lista > 0 then
      local nAct = 0
      for _, e in ipairs(lista) do if e.tiene then nAct = nAct + 1 end end
      y = V.bloque(k, y, ancho, L(V.ARBOL[a][1], V.ARBOL[a][2]), nAct .. "/" .. #lista .. L(" activos", " active"))
      local cols = (ancho >= 460) and 2 or 1
      local gap = 10
      local cw = (ancho - gap * (cols - 1)) / cols
      local i = 1
      while i <= #lista do
        local fila, fin = {}, y
        for c = 0, cols - 1 do
          local e = lista[i + c]
          if not e then break end
          local x, r, tiene = e.x, e.r, e.tiene
          local bx = c * (cw + gap)
          local t = k:tarjeta(bx, y, cw, 70, tiene and "recomendada" or nil, K.CASILLA, tiene and C().verde or K.CASILLA_BORDE, true)
          k:icono(bx + 12, y + 12, 36, V.iconoHechizo(x.id, V.IC.libro), tiene and "verde" or nil, not tiene)
          local rg = tiene and (tostring(r.rango) .. "/" .. tostring(x.r) .. (r.seguro and "" or L(" o más", " or more"))) or ("0/" .. tostring(x.r))
          local _, chw = k:chip(bx + cw - 12, y + 12, rg, tiene and "verde" or "neutro", true)
          local tx = bx + 58
          local tw = bx + cw - 12 - tx - (tonumber(chw) or 50) - 8
          local _, hn = k:texto(tx, y + 13, Y(x.n or "?"), { tam = 14, peso = "medio", color = tiene and C().texto or WowF.vistaKit.CLARO, ancho = tw })
          local cy = y + 13 + hn + 4
          local es, en = x.es, x.en
          local desc = ""
          if es or en then
            local val = (x.v and (x.v[math.max(1, tonumber(r.rango) or 0)] or x.v[1])) or 0
            local ok, s = pcall(string.format, L(es or en or "", en or es or ""), val)
            desc = (ok and s or L(es or "", en or "")) .. (tiene and "" or L(" (con 1 rango)", " (with 1 rank)"))
          end
          local aw = bx + cw - 12 - tx
          if desc ~= "" then
            local _, hd = k:texto(tx, cy, Y(desc), { tam = 12, color = C().tenue, ancho = aw })
            cy = cy + hd + 4
          end
          local efecto
          if x.usa then efecto = (tiene and (cod.verde or "") or (cod.texto or "")) .. L("En el addon: ", "In the addon: ") .. L(x.usa[1], x.usa[2]) .. (tiene and L(" (ya aplicado)", " (already applied)") or "") .. "|r"
          else efecto = (cod.tenue or "") .. L("En el addon: solo informativo (el addon no calcula nada con esto).", "In the addon: info only (the addon doesn't calculate anything with this).") .. "|r" end
          local _, he = k:texto(tx, cy, Y(efecto), { tam = 12, color = C().tenue, ancho = aw })
          cy = cy + he + 12
          table.insert(fila, t)
          if cy > fin then fin = cy end
        end
        if fin < y + 60 then fin = y + 60 end
        for _, t in ipairs(fila) do t:SetHeight(fin - y) end
        k:hasta(fin)
        y = fin + gap
        i = i + cols
      end
      y = y + 8
    end
  end
  if activos == 0 then
    y = V.aviso(k, y, ancho, L("Aún no tienes perks Legacy en este personaje (o el juego no los muestra). Cuando pongas uno, esta lista y las vistas que afecta se recalculan solas.",
      "You don't have Legacy perks on this character yet (or the game doesn't show them). When you pick one, this list and the views it affects update on their own."), V.IC.libro)
  end
  -- Legacy Points y certificacion por tus profesiones de fabricar
  local filas = {}
  for _, f in ipairs(V.FABRICAR) do
    local r = mias[f.id]
    if r then
      local nom = V.NOMBRE_PROF[f.id]
      local prox
      for _, u in ipairs({ 150, 225, 300 }) do if r < u then prox = u; break end end
      local txt = prox and L(nom .. " a " .. prox .. ": +1 Legacy Point (llevas " .. r .. ").", nom .. " at " .. prox .. ": +1 Legacy Point (you have " .. r .. ").")
        or L(nom .. ": ya sacaste sus 3 Legacy Points (150, 225 y 300).", nom .. ": you already earned its 3 Legacy Points (150, 225 and 300).")
      table.insert(filas, { t = "item", o = { texto = (cod.verde or "") .. txt .. "|r", icono = (WowF.ICONO_PROF and WowF.ICONO_PROF[f.id]) or V.ICONO_PROF[f.id],
        sub = L("Con 300: " .. nom .. " Certification (1000 Merchant's Favor) = título \"" .. f.titulo .. "\" para toda la cuenta (dato de la beta).",
          "At 300: " .. nom .. " Certification (1000 Merchant's Favor) = \"" .. f.titulo .. "\" title for your whole account (beta data).") } })
    end
  end
  if mias[393] and WowF.notaSkinningUnaVez then
    local ok, s = pcall(WowF.notaSkinningUnaVez)
    if ok and s then table.insert(filas, { t = "item", o = { texto = "Skinning", sub = s, icono = (WowF.ICONO_PROF and WowF.ICONO_PROF[393]) or V.ICONO_PROF[393] } }) end
  end
  if #filas > 0 then
    table.insert(filas, 1, { t = "cab", texto = L("Legacy Points de tus profesiones", "Legacy Points from your professions") })
    y = V.pintar(k, y, ancho, filas, V.IC.nota)
  end
  -- Avisos y fuente
  local pie = {
    { t = "nota", texto = (cod.tenue or "") .. L("No hay perk de velocidad a pie en el árbol actual. Los nodos \"Unknown\" llegarán en una actualización futura del juego.",
      "There is no walking speed perk in the current tree. The \"Unknown\" nodes will come in a future game update.") .. "|r" },
    { t = "nota", texto = "|cffff9933" .. L("Rangos, números y certificaciones salen de la beta: pueden cambiar, se actualizará en próximas actualizaciones.",
      "Ranks, numbers and certifications come from the beta: they may change, it will be updated in future updates.") .. "|r" },
    { t = "nota", texto = "|cff999999" .. L("Fuente: ", "Source: ") .. tostring(WowF.LEGACY_URL or "?") .. "|r" },
  }
  return V.pintar(k, y, ancho, pie, V.IC.nota)
end
