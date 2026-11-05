-- Forever Leveling Guide: profesiones segun el OBJETIVO que elegiste (pedido de Andy, 5-oct: "si pongo ganar oro, que me muestre lo
-- que puedo fabricar para vender en la casa de subastas... si marco PvP, que me muestre que me tengo que craftear para mi PvP").
--   fabricar: las piezas que te fabricas (las del plan), separadas en "Ya puedes" y "Proximas al subir".
--   oro:      que fabricar para VENDER (con fabricar) o que recoger para vender (con recoleccion), quien lo pide y donde recogerlo.
--   pvp:      que fabricarte para PvP (efecto real del objeto) y piezas con Stamina para tu clase.
-- Todo se recalcula EN VIVO con tu rango de cada profesion, tu nivel, tu clase y tu faccion (la clave de la cache los lleva).
-- Datos: WowFDatos.objetivoProf (herramientas/objetivo-prof.js). Precios: solo reales (WowF.precioSubasta de wowF_AvisoBotin.lua);
-- la ganancia solo se dice si hay precio del objeto y de TODOS sus materiales. Nada inventado.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function Y(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end
local ORO, VERDE, GRIS, BLANCO, NARANJA, CELESTE = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933", "|cff66ccff"

local CLASE_ID = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }
-- Prioridad en PvP (la misma que en los datos) y por que sirve, segun el efecto real del objeto
local PRIORIDAD = { libera = 1, aturde = 2, red = 3, velocidad = 4, cura = 5, mana = 6, invisible = 7, proteccion = 8, resistencia = 9, dano = 10, desarme = 11 }
local function motivoPvp(clave, valor)
  local v = (valor and valor > 0) and tostring(valor) or nil
  if clave == "libera" then return L("te libra de aturdimientos o raices", "frees you from stuns or roots")
  elseif clave == "aturde" then return L("aturde al rival", "stuns your enemy")
  elseif clave == "red" then return L("atrapa al rival en una red", "traps your enemy in a net")
  elseif clave == "velocidad" then return L("corres mas rapido: huir o perseguir", "you run faster: escape or chase")
  elseif clave == "cura" then return v and L("te cura " .. v .. " de salud en combate", "heals you " .. v .. " health in combat") or L("te cura en combate", "heals you in combat")
  elseif clave == "mana" then return v and L("te devuelve " .. v .. " de mana", "restores " .. v .. " mana") or L("te devuelve mana", "restores mana")
  elseif clave == "invisible" then return L("te hace invisible", "makes you invisible")
  elseif clave == "proteccion" then return v and L("absorbe " .. v .. " de dano", "absorbs " .. v .. " damage") or L("absorbe dano", "absorbs damage")
  elseif clave == "resistencia" then return L("mas resistencia a la magia", "more resistance to magic")
  elseif clave == "dano" then return v and L("dano de fuego en area (" .. v .. ")", "fire damage in an area (" .. v .. ")") or L("dano de fuego en area", "fire damage in an area")
  elseif clave == "desarme" then return L("no te pueden desarmar", "you cannot be disarmed") end
  return ""
end
-- Por que se vende, segun la clase del objeto (clase.subclase de los datos)
local function motivoVenta(grupo, demanda)
  local c = tonumber((grupo or ""):match("^(%d+)")) or -1
  if c == 0 then return L("consumible: se gasta y se vuelve a comprar", "consumable: used up and bought again")
  elseif c == 1 then return L("bolsa: todos necesitan espacio", "bag: everyone needs space")
  elseif c == 6 then return L("municion: los Hunter la gastan", "ammo: Hunters use it up")
  elseif c == 7 then return L("material que piden otras profesiones", "material other professions need")
  elseif c == 2 or c == 4 then return L("equipo que no se liga al recogerlo", "gear that does not bind on pickup") end
  return ""
end
local GRUPO_ORDEN = { [0] = 1, [1] = 2, [6] = 2, [7] = 3, [2] = 4, [4] = 4 }

local function D() return WowFDatos end
local function datos() return WowFDatos and WowFDatos.objetivoProf end
local function nombreObj(id) local o = WowFDatos and WowFDatos.obj and WowFDatos.obj[id]; return o and o[1] or (L("objeto ", "item ") .. tostring(id)), o and o[2] or 1, o and o[3] or "" end
local function tengo(id) return (GetItemCount and GetItemCount(id, true)) or 0 end
local function nivelPj() return (UnitLevel and UnitLevel("player")) or 1 end
local function miFaccion() local f = UnitFactionGroup and UnitFactionGroup("player"); return f == "Horde" and 2 or (f == "Alliance" and 1 or 0) end
local function claseId() if not UnitClass then return nil end; local _, t = UnitClass("player"); return CLASE_ID[t or ""] end
local function nombreProf(id) return (WowFDatos and WowFDatos.prof and WowFDatos.prof[id]) or tostring(id) end
-- Orden INTERNO de "Proximas al subir" (9-oct): el nivel de WowFDatos.caps es de Classic, NUNCA se muestra al jugador.
local function nivelParaRango(r)
  for _, c in ipairs((WowFDatos and WowFDatos.caps) or {}) do if r <= c[2] then return c[1] end end
  return 35
end
local function vale(fac, mia) return fac == 0 or (mia ~= 0 and fac == mia) end
local function dinero(c) if WowF.avisoBotinDinero then return WowF.avisoBotinDinero(c) end return tostring(c) .. "c" end
local function precio(id)
  if not WowF.precioSubasta then return nil end
  local link
  if GetItemInfo then local ok, _, l = pcall(GetItemInfo, id); if ok then link = l end end
  local ok, p, fuente, edad = pcall(WowF.precioSubasta, link or ("item:" .. id), id)
  if ok and p and p > 0 then return p, fuente, edad end
  return nil
end
-- Ganancia de una receta: solo con precio real del objeto y de TODOS los materiales
local function ganancia(e)
  local p, fuente, edad = precio(e.id)
  if not p then return nil end
  local costo = 0
  for _, m in ipairs(e.mats or {}) do
    local pm = precio(m[1])
    if not pm then return nil, p, fuente, edad end
    costo = costo + pm * m[2]
  end
  return p * (e.cant or 1) - costo, p, fuente, edad
end

-- ===================== Calculo en vivo =====================
local cache, claveCache = nil, nil
function WowF.profObjetivoInvalidar() cache, claveCache = nil, nil end

-- Tus profesiones con su rango (nil = no la tienes): las del plan (las tuyas y las que te faltan) y, para PvP, First Aid
local function profesionesPlan(objetivo)
  local p = WowF.armarPlan and WowF.armarPlan()
  local ids = {}
  for _, id in ipairs((p and p.ids) or {}) do table.insert(ids, id) end
  if objetivo == "pvp" then
    local ya = false
    for _, id in ipairs(ids) do if id == 129 then ya = true end end
    if not ya then table.insert(ids, 129) end
  end
  local rangos = {}
  for _, id in ipairs(ids) do rangos[id] = WowF.rangoProfesion and WowF.rangoProfesion(id) or nil end
  return p, ids, rangos
end

local function vendedorDe(spell, mia)
  local lista = datos() and datos().vend and datos().vend[spell]
  if not lista then return nil end
  local lado = mia == 2 and "H" or (mia == 1 and "A" or nil)
  local aqui = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local mejor
  for _, v in ipairs(lista) do
    if v[5] == "N" or v[5] == lado then
      if v[2] == aqui then return v end
      mejor = mejor or v
    end
  end
  return mejor
end

-- Lista de VENTA de una profesion de fabricar
local function listaVenta(prof, R, N, mia)
  local filas = (datos().venta or {})[prof] or {}
  local ya, prox = {}, {}
  for _, f in ipairs(filas) do
    if vale(f[5], mia) then
      local e = { id = f[1], nivel = f[2], cant = f[3], grupo = f[4], fac = f[5], demanda = f[6], fuente = f[7], rl = f[8], mats = f[9], spell = f[10], prof = prof }
      e.motivo = motivoVenta(e.grupo, e.demanda)
      if R and e.nivel <= R then table.insert(ya, e)
      else e.rango, e.nivelDesbloqueo = e.nivel, nivelParaRango(e.nivel); table.insert(prox, e) end
    end
  end
  for _, e in ipairs(ya) do e.gana, e.precio, e.precioFuente, e.precioEdad = ganancia(e) end
  table.sort(ya, function(a, b)
    local ga, gb = a.gana ~= nil, b.gana ~= nil
    if ga ~= gb then return ga end
    if ga and a.gana ~= b.gana then return a.gana > b.gana end
    if a.demanda ~= b.demanda then return a.demanda > b.demanda end
    local oa, ob = GRUPO_ORDEN[tonumber(a.grupo:match("^(%d+)")) or -1] or 9, GRUPO_ORDEN[tonumber(b.grupo:match("^(%d+)")) or -1] or 9
    if oa ~= ob then return oa < ob end
    if a.nivel ~= b.nivel then return a.nivel > b.nivel end
    return a.id < b.id
  end)
  table.sort(prox, function(a, b) if a.nivel ~= b.nivel then return a.nivel < b.nivel end; if a.demanda ~= b.demanda then return a.demanda > b.demanda end; return a.id < b.id end)
  return ya, prox
end

-- Lista de RECOLECCION para vender (lo que mas piden las rutas de las demas profesiones)
local function listaRecoge(prof, R)
  local filas = (datos().recoge or {})[prof] or {}
  local ya, prox, sinRango = {}, {}, false
  for _, f in ipairs(filas) do
    if f[3] > 0 then
      local e = { id = f[1], desde = f[2], demanda = f[3], tipo = f[4], prof = prof }
      e.usos = datos().usos and datos().usos[e.id]
      if e.desde < 0 then sinRango = true; table.insert(ya, e)
      elseif R and e.desde <= R then table.insert(ya, e)
      else e.rango, e.nivelDesbloqueo = e.desde, nivelParaRango(e.desde); table.insert(prox, e) end
    end
  end
  for _, e in ipairs(ya) do e.precio, e.precioFuente, e.precioEdad = precio(e.id) end
  table.sort(ya, function(a, b)
    if (a.precio ~= nil) ~= (b.precio ~= nil) then return a.precio ~= nil end
    if a.precio and a.precio ~= b.precio then return a.precio > b.precio end
    if a.demanda ~= b.demanda then return a.demanda > b.demanda end
    return a.id < b.id
  end)
  table.sort(prox, function(a, b) if a.desde ~= b.desde then return a.desde < b.desde end; if a.demanda ~= b.demanda then return a.demanda > b.demanda end; return a.id < b.id end)
  return ya, prox, sinRango
end

-- Lista de PvP: lo mejor que ya puedes de cada efecto, y lo proximo
local function listaPvp(prof, R, N, mia)
  local filas = (datos().pvp or {})[prof] or {}
  local todos, prox = {}, {}
  for _, f in ipairs(filas) do
    if vale(f[5], mia) then
      local e = { id = f[1], nivel = f[2], cant = f[3], clave = f[4], fac = f[5], fuente = f[6], rl = f[7], mats = f[8], spell = f[9], valor = f[10], equipo = f[11] == 1, prof = prof }
      e.motivo = motivoPvp(e.clave, e.valor)
      if R and e.nivel <= R and (e.rl or 0) <= N then table.insert(todos, e)
      else e.rango, e.nivelDesbloqueo = e.nivel, math.max(nivelParaRango(e.nivel), e.rl or 0); table.insert(prox, e) end
    end
  end
  -- Uno por efecto: el de mas habilidad (el mas fuerte que ya sabes hacer)
  local mejor = {}
  for _, e in ipairs(todos) do local m = mejor[e.clave]; if not m or e.nivel > m.nivel or (e.nivel == m.nivel and e.valor > m.valor) then mejor[e.clave] = e end end
  local ya = {}
  for _, e in pairs(mejor) do table.insert(ya, e) end
  table.sort(ya, function(a, b) local pa, pb = PRIORIDAD[a.clave] or 99, PRIORIDAD[b.clave] or 99; if pa ~= pb then return pa < pb end; return a.id < b.id end)
  -- Proximas: solo lo que mejora lo que ya tienes de ese efecto (o un efecto nuevo)
  local prox2 = {}
  for _, e in ipairs(prox) do local m = mejor[e.clave]; if not m or e.nivel > m.nivel then table.insert(prox2, e) end end
  table.sort(prox2, function(a, b)
    if a.nivelDesbloqueo ~= b.nivelDesbloqueo then return a.nivelDesbloqueo < b.nivelDesbloqueo end
    if a.nivel ~= b.nivel then return a.nivel < b.nivel end
    local pa, pb = PRIORIDAD[a.clave] or 99, PRIORIDAD[b.clave] or 99; if pa ~= pb then return pa < pb end
    return a.id < b.id
  end)
  return ya, prox2
end

-- Piezas con Stamina para tu clase (aguantar mas contra jugadores)
local function listaEquipoPvp(prof, R, N, mia, cid)
  local filas = (datos().equipoPvp or {})[prof] or {}
  local ya, prox = {}, {}
  if not cid then return ya, prox end
  local marca = "," .. cid .. ","
  local mejor = {}
  for _, f in ipairs(filas) do
    if vale(f[6], mia) and f[5]:find(marca, 1, true) then
      local e = { id = f[1], nivel = f[2], sta = f[3], rl = f[4], fac = f[6], fuente = f[7], mats = f[8], spell = f[9], inv = f[10], prof = prof, cant = 1 }
      e.motivo = L("+" .. e.sta .. " Stamina: aguantas mas", "+" .. e.sta .. " Stamina: you last longer")
      if R and e.nivel <= R and e.rl <= N and e.rl >= N - 10 then
        local m = mejor[e.inv]; if not m or e.sta > m.sta or (e.sta == m.sta and e.rl > m.rl) then mejor[e.inv] = e end
      elseif e.rl > N or not R or e.nivel > R then
        if e.rl <= N + 10 then e.rango, e.nivelDesbloqueo = e.nivel, math.max(nivelParaRango(e.nivel), e.rl); table.insert(prox, e) end
      end
    end
  end
  for _, e in pairs(mejor) do table.insert(ya, e) end
  table.sort(ya, function(a, b) if a.sta ~= b.sta then return a.sta > b.sta end; return a.id < b.id end)
  table.sort(prox, function(a, b) if a.nivelDesbloqueo ~= b.nivelDesbloqueo then return a.nivelDesbloqueo < b.nivelDesbloqueo end; if a.sta ~= b.sta then return a.sta > b.sta end; return a.id < b.id end)
  return ya, prox
end

-- Piezas que te fabricas (objetivo fabricar), del plan: "Nombre (Ranura, Tipo) · Prof N · fuente"
local function rangoDePieza(e)
  local prof, r = (tostring(e[3]):match(" \194\183 (.-) \194\183 ") or tostring(e[3]):match(" \194\183 (.-)$") or ""):match("^(.-) (%d+)")
  if not prof then return nil end
  for id, n in pairs((WowFDatos and WowFDatos.prof) or {}) do if n == prof then return id, tonumber(r) end end
  return nil
end
local function listaFabricar(p, prof, R, N, mia)
  local fac = (datos() and datos().facEquipo) or {}
  local ya, prox = {}, {}
  for _, e in ipairs((p and p.eventos) or {}) do
    if e[2] == "equipo" then
      local id, r = rangoDePieza(e)
      if id == prof and r and vale(fac[e.i or 0] or 0, mia) and (e.hasta or 60) > N then
        if R and R >= r and e[1] <= N + 2 then table.insert(ya, e)
        else table.insert(prox, { e = e, rango = r, nivelDesbloqueo = math.max(e[1], nivelParaRango(r)) }) end
      end
    end
  end
  table.sort(ya, function(a, b) if a[1] ~= b[1] then return a[1] > b[1] end; return (a.i or 0) < (b.i or 0) end)
  table.sort(prox, function(a, b) if a.nivelDesbloqueo ~= b.nivelDesbloqueo then return a.nivelDesbloqueo < b.nivelDesbloqueo end; return (a.e.i or 0) < (b.e.i or 0) end)
  local t = {}
  for _, x in ipairs(prox) do x.e.rangoDesbloqueo, x.e.nivelDesbloqueo = x.rango, x.nivelDesbloqueo; table.insert(t, x.e) end
  return ya, t
end

-- WowF.recetasObjetivo(objetivo): { objetivo, secciones = { { prof, nombre, rango (nil = no la tienes), tipo, ya, prox, sinRango } }, sugerida }
function WowF.recetasObjetivo(objetivo)
  objetivo = objetivo or (WowF.objetivo and WowF.objetivo()) or "fabricar"
  if not datos() then return { objetivo = objetivo, secciones = {}, sinDatos = true } end
  local p, ids, rangos = profesionesPlan(objetivo)
  local N, mia, cid = nivelPj(), miFaccion(), claseId()
  local partes = { objetivo, N, mia, cid or 0, p and p.sugerida and p.sugerida.id or 0 }
  for _, id in ipairs(ids) do table.insert(partes, id .. "=" .. tostring(rangos[id])) end
  local clave = table.concat(partes, "|")
  if cache and claveCache == clave then return cache end
  local res = { objetivo = objetivo, secciones = {}, nivel = N, faccion = mia, plan = p }
  local recoleccion = (WowFDatos and WowFDatos.recoleccion) or {}
  local function seccion(prof, tipo, ya, prox, sinRango)
    table.insert(res.secciones, { prof = prof, nombre = nombreProf(prof), rango = rangos[prof], tipo = tipo, ya = ya, prox = prox, sinRango = sinRango })
  end
  for _, id in ipairs(ids) do
    local R = rangos[id]
    if objetivo == "oro" then
      if recoleccion[id] then local y, x, s = listaRecoge(id, R); seccion(id, "recoge", y, x, s)
      elseif (datos().venta or {})[id] then local y, x = listaVenta(id, R, N, mia); seccion(id, "venta", y, x) end
    elseif objetivo == "pvp" then
      if (datos().pvp or {})[id] then local y, x = listaPvp(id, R, N, mia); seccion(id, "pvp", y, x) end
      if (datos().equipoPvp or {})[id] then local y, x = listaEquipoPvp(id, R, N, mia, cid); if #y + #x > 0 then seccion(id, "equipoPvp", y, x) end end
    elseif not recoleccion[id] then
      local y, x = listaFabricar(p, id, R, N, mia)
      if #y + #x > 0 then seccion(id, "fabricar", y, x) end
    end
  end
  -- Con PvP y sin profesion que fabrique algo para PvP (p. ej. Mining + Herbalism): lo que harias con la recomendada para tu clase
  if objetivo == "pvp" and p and p.sugerida and not rangos[p.sugerida.id] then
    local id = p.sugerida.id
    local hay = false
    for _, s in ipairs(res.secciones) do if s.prof == id then hay = true end end
    if not hay and (datos().pvp or {})[id] then
      local y, x = listaPvp(id, nil, N, mia)
      table.insert(res.secciones, { prof = id, nombre = nombreProf(id), rango = nil, tipo = "pvp", ya = y, prox = x, sugerida = true })
    end
  end
  cache, claveCache = res, clave
  return res
end

-- Lo primero que te conviene hacer YA para tu objetivo (para el panel): { texto, sub, id, icono, tipo }
function WowF.destacadoObjetivoProf()
  local objetivo = WowF.objetivo and WowF.objetivo() or "fabricar"
  if objetivo == "fabricar" then return nil end
  local ok, r = pcall(WowF.recetasObjetivo, objetivo)
  if not ok or not r then return nil end
  for _, s in ipairs(r.secciones) do
    local e = s.ya[1]
    if e and s.rango and s.tipo ~= "equipoPvp" then
      local n, q, ic = nombreObj(e.id)
      local det
      if s.tipo == "recoge" then det = L("recogelo con ", "gather it with ") .. s.nombre
      elseif s.tipo == "venta" then det = s.nombre .. " " .. e.nivel .. (e.gana and e.gana > 0 and (" \194\183 " .. L("ganas ", "profit ") .. dinero(e.gana)) or "")
      else det = s.nombre .. " " .. e.nivel .. " \194\183 " .. e.motivo end
      return { tipo = s.tipo, id = e.id, q = q, icono = (WowF.iconoObjeto and WowF.iconoObjeto(e.id, ic)) or (ic ~= "" and ("Interface\\Icons\\" .. ic)) or e.id, nombre = n, detalle = det }
    end
  end
  return nil
end

-- ===================== Seccion del Libro (pestana Profesiones) =====================
local function textoMats(lista)
  local partes, todo = {}, true
  for _, m in ipairs(lista or {}) do
    local n = nombreObj(m[1])
    local tn = tengo(m[1])
    if tn < m[2] then todo = false end
    table.insert(partes, (tn >= m[2] and VERDE or BLANCO) .. m[2] .. " " .. n .. "|r" .. GRIS .. (tn >= m[2] and " (ok)" or (tn > 0 and L(" (tienes " .. tn .. ")", " (you have " .. tn .. ")") or "")) .. "|r")
  end
  return table.concat(partes, GRIS .. ", |r"), todo
end
local function textoPrecio(e)
  if e.gana ~= nil then
    local base = L("Se vende a ", "Sells for ") .. dinero(e.precio) .. GRIS .. " (" .. (e.precioFuente == "visto" and L("lo viste", "you saw it") or e.precioFuente) .. (e.precioEdad and (", " .. e.precioEdad) or "") .. ")|r"
    if e.gana > 0 then return VERDE .. base .. VERDE .. "  " .. L("ganas ", "profit ") .. dinero(e.gana) .. "|r" end
    return NARANJA .. base .. NARANJA .. "  " .. L("pierdes ", "loss ") .. dinero(-e.gana) .. L(": hoy no compensa", ": not worth it today") .. "|r"
  end
  if e.precio then
    return BLANCO .. L("Se vende a ", "Sells for ") .. dinero(e.precio) .. GRIS .. " (" .. (e.precioFuente == "visto" and L("lo viste", "you saw it") or e.precioFuente) .. (e.precioEdad and (", " .. e.precioEdad) or "") .. ")" ..
      L(" · sin precio de algun material: mira la ganancia en la casa de subastas", " · no price for some material: check the profit at the auction house") .. "|r"
  end
  return GRIS .. L("Precio: miralo en la casa de subastas (con Auctionator o TSM sale aqui)", "Price: check the auction house (with Auctionator or TSM it shows here)") .. "|r"
end
local function textoUsos(usos)
  if not usos or #usos == 0 then return nil end
  local t = {}
  for i = 1, math.min(3, #usos) do table.insert(t, nombreProf(usos[i][1]) .. " (" .. usos[i][2] .. ")") end
  return L("Lo piden para subir: ", "Wanted to level: ") .. table.concat(t, ", ")
end
local function textoFuente(e, h)
  if e.fuente == "A" then return L("Receta: la sabes al aprender la profesion", "Recipe: known when you learn the profession"), nil end
  if e.fuente == "B" then return L("Receta: botin o casa de subastas", "Recipe: loot or auction house"), nil end
  if e.fuente == "V" then
    local v = vendedorDe(e.spell, miFaccion())
    if v then
      return L("Receta: la vende ", "Recipe: sold by ") .. v[1] .. " (" .. v[6] .. " " .. v[3] .. ", " .. v[4] .. ")  " .. VERDE .. L("clic: alfiler", "click: map pin") .. "|r",
        function() if WowF.marcar then WowF.marcar({ m = v[2], x = v[3], y = v[4], n = v[1] .. L(" (vende la receta)", " (sells the recipe)"), z = v[6], lugar = true }) end end
    end
    -- 9-oct: vendedores solo de Wowhead /forever; sin dato de Forever no hay alfiler
    return L("Receta: la vende un vendedor (vendedor aun no confirmado en Forever; se actualizara)", "Recipe: sold by a vendor (vendor not yet confirmed in Forever; will be updated)"), nil
  end
  if e.fuente == "F" then -- 7-oct: receta que se compra con Merchant's Favor (wowF_Favor.lua)
    local r = WowF.favorReceta and WowF.favorReceta(e.spell)
    local v = WowF.vendedorFavor and WowF.vendedorFavor(e.prof)
    local costo = r and (" " .. r[4]) or ""
    if v then
      return L("Receta: Merchant's Favor", "Recipe: Merchant's Favor") .. costo .. L(", la vende ", ", sold by ") .. v.n .. " (" .. v.zona .. " " .. v.x .. ", " .. v.y .. ")  " .. VERDE .. L("clic: ir", "click: go") .. "|r",
        function() WowF.irVendedorFavor(e.prof) end
    end
    return L("Receta: Merchant's Favor", "Recipe: Merchant's Favor") .. costo .. L(" (vendedor de tu faccion: sin confirmar)", " (vendor of your faction: unconfirmed)"), nil
  end
  local accion
  if h.entrenadorPara and h.marcarEntrenador then
    local t = h.entrenadorPara(e.prof, e.nivel <= 75 and 75 or (e.nivel <= 150 and 150 or (e.nivel <= 225 and 225 or 300)))
    if t then accion = function() h.marcarEntrenador(t, nombreProf(e.prof)) end end
  end
  return L("Receta: la ensena el entrenador", "Recipe: taught by the trainer") .. (accion and ("  " .. VERDE .. L("clic: alfiler", "click: map pin") .. "|r") or ""), accion
end

local MAX_YA, MAX_PROX = 8, 5
local function pintarReceta(h, e, s, proxima)
  local n, q, ic = nombreObj(e.id)
  local cant = (e.cant or 1) > 1 and (ORO .. e.cant .. " x|r ") or ""
  local cab = (proxima and (NARANJA .. L("rango ", "skill ") .. e.rango .. "|r  ") or (GRIS .. s.nombre .. " " .. e.nivel .. "  |r"))
  local lineas = {}
  if s.tipo == "venta" then
    table.insert(lineas, GRIS .. e.motivo .. "|r")
    local u = e.demanda > 0 and textoUsos(datos().usos and datos().usos[e.id]) or nil
    if u then table.insert(lineas, CELESTE .. u .. "|r") end
    if WowF.textoQuienLoPide then local q = WowF.textoQuienLoPide(e.id); if q then table.insert(lineas, q) end end -- 8-oct firstaid-alchemy
    if not proxima then table.insert(lineas, textoPrecio(e)) end
  elseif s.tipo == "pvp" or s.tipo == "equipoPvp" then
    table.insert(lineas, VERDE .. e.motivo .. "|r" .. ((e.rl or 0) > nivelPj() and (NARANJA .. L("  · se usa desde el nivel ", "  · usable from level ") .. e.rl .. "|r") or ""))
  end
  local mats, todo = textoMats(e.mats)
  if mats ~= "" then table.insert(lineas, GRIS .. L("Necesitas: ", "You need: ") .. "|r" .. mats .. (todo and (VERDE .. L("  ya lo tienes todo", "  you have it all") .. "|r") or "")) end
  local f, accion = textoFuente(e, h)
  table.insert(lineas, GRIS .. f .. "|r")
  h.item({ texto = Y(cab .. cant .. h.colorCalidad(q or 1) .. n .. "|r"), sub = Y(table.concat(lineas, "\n")), icono = h.icono(ic, e.id), objeto = e.id, sangria = 12, chico = true, accion = accion })
end
local function pintarRecoge(h, e, s, proxima)
  local n, q, ic = nombreObj(e.id)
  local cab
  if proxima then cab = NARANJA .. L("rango ", "skill ") .. e.rango .. "|r  "
  elseif e.desde >= 0 then cab = GRIS .. s.nombre .. " " .. math.max(1, e.desde) .. "  |r"
  else cab = "" end
  local lineas = {}
  local u = textoUsos(e.usos)
  if u then table.insert(lineas, CELESTE .. u .. "|r") end
  if e.tipo == "f" then table.insert(lineas, GRIS .. L("Barra: funde el mineral (vale mas que el mineral si la piden)", "Bar: smelt the ore (worth more than ore when wanted)") .. "|r") end
  if not proxima then
    if e.precio then table.insert(lineas, BLANCO .. L("Se vende a ", "Sells for ") .. dinero(e.precio) .. GRIS .. " (" .. (e.precioFuente == "visto" and L("lo viste", "you saw it") or e.precioFuente) .. (e.precioEdad and (", " .. e.precioEdad) or "") .. ")|r")
    else table.insert(lineas, GRIS .. L("Precio: miralo en la casa de subastas (con Auctionator o TSM sale aqui)", "Price: check the auction house (with Auctionator or TSM it shows here)") .. "|r") end
  end
  local accion
  if s.prof ~= 393 and s.rango then
    table.insert(lineas, VERDE .. L("clic: donde recogerlo (ruta en el mapa)", "click: where to gather it (route on the map)") .. "|r")
    accion = function() if SlashCmdList and SlashCmdList.WOWF then SlashCmdList.WOWF("farmeo " .. s.nombre) end end
  end
  h.item({ texto = Y(cab .. h.colorCalidad(q or 1) .. n .. "|r"), sub = Y(table.concat(lineas, "\n")), icono = h.icono(ic, e.id), objeto = e.id, sangria = 12, chico = true, accion = accion })
end
local function pintarPieza(h, e)
  h.fabricadas({ e })
  if e.rangoDesbloqueo then
    h.item({ texto = Y(NARANJA .. L("   se desbloquea: rango ", "   unlocks at: skill ") .. e.rangoDesbloqueo .. "|r"), sangria = 24, chico = true })
  end
end

local TITULO = {
  venta = function(s) return L("Para vender en la casa de subastas: ", "To sell at the auction house: ") .. s.nombre end,
  recoge = function(s) return L("Para vender en la casa de subastas: ", "To sell at the auction house: ") .. s.nombre end,
  pvp = function(s) return L("Para fabricarte para PvP: ", "To craft for PvP: ") .. s.nombre end,
  equipoPvp = function(s) return L("Piezas para PvP (Stamina) para tu clase: ", "PvP gear (Stamina) for your class: ") .. s.nombre end,
  fabricar = function(s) return L("Para fabricarte equipo: ", "To craft your gear: ") .. s.nombre end,
}

-- La llama CONTENIDO.Profesiones del Libro con sus piezas de dibujo (h = item, cab, nota, fabricadas, icono, colorCalidad...)
function WowF.seccionObjetivoProf(p, h)
  local objetivo = (p and p.objetivo) or (WowF.objetivo and WowF.objetivo()) or "fabricar"
  local r = WowF.recetasObjetivo(objetivo)
  if r.sinDatos then
    h.nota(Y(GRIS .. L("Faltan los datos de profesiones por objetivo: reinstala el addon.", "Professions-by-goal data is missing: reinstall the addon.") .. "|r"))
    return
  end
  local alguno = false
  for _, s in ipairs(r.secciones) do
    local ya, prox = s.ya, s.prox
    if #ya + #prox > 0 then
      alguno = true
      local estado = s.rango and (VERDE .. "  (" .. L("tienes ", "you have ") .. s.rango .. ")|r") or (NARANJA .. L("  (aun no la tienes)", "  (you do not have it yet)") .. "|r")
      h.cab(Y(CELESTE .. TITULO[s.tipo](s) .. "|r" .. estado))
      if s.tipo == "fabricar" and WowF.avisoMejorFabricar then h.nota(Y(WowF.avisoMejorFabricar())) end
      if s.sugerida then h.nota(Y(GRIS .. L("Ninguna de tus profesiones fabrica algo para PvP. Con " .. s.nombre .. " (la recomendada para tu clase) te harias esto:", "None of your professions crafts anything for PvP. With " .. s.nombre .. " (the one recommended for your class) you would make this:") .. "|r")) end
      if s.tipo == "venta" and #ya > 0 then h.nota(Y(GRIS .. L("Ordenado por ganancia real (si hay precios), despues por lo que mas piden las demas profesiones.", "Sorted by real profit (when there are prices), then by what other professions want most.") .. "|r")) end
      if s.tipo == "venta" and WowF.notaVentaProf then for _, n in ipairs(WowF.notaVentaProf(s) or {}) do h.nota(Y(n)) end end -- 8-oct firstaid-alchemy
      if s.tipo == "recoge" then h.nota(Y(GRIS .. L("Lo que mas piden las rutas de subida de las demas profesiones (unidades entre parentesis).", "What other professions need most to level up (units in brackets).") .. "|r")) end
      if s.sinRango then
        h.nota(Y(GRIS .. L("Skinning no tiene rango por piel en los datos: cada piel sale de bichos de su nivel.", "Skinning has no skill per hide in the data: each hide comes from beasts of its level.") .. "|r"))
      end
      -- Ya puedes
      if #ya > 0 then
        h.item({ texto = Y(VERDE .. L("Ya puedes", "You can now") .. "|r" .. GRIS .. (s.rango and ("  (" .. s.nombre .. " " .. s.rango .. L(", nivel ", ", level ") .. r.nivel .. ")") or "") .. "|r"), sangria = 4, chico = true })
        for i = 1, math.min(MAX_YA, #ya) do
          if s.tipo == "recoge" then pintarRecoge(h, ya[i], s, false)
          elseif s.tipo == "fabricar" then pintarPieza(h, ya[i])
          else pintarReceta(h, ya[i], s, false) end
        end
      elseif s.rango then
        h.item({ texto = Y(GRIS .. L("Ya puedes: nada aun con tu rango; mira las proximas.", "You can now: nothing yet at your skill; see the next ones.") .. "|r"), sangria = 4, chico = true })
      end
      -- Proximas al subir
      if #prox > 0 then
        h.item({ texto = Y(ORO .. L("Proximas al subir", "Next as you level up") .. "|r" .. GRIS .. L("  (rango en que se desbloquean)", "  (skill that unlocks them)") .. "|r"), sangria = 4, chico = true })
        for i = 1, math.min(MAX_PROX, #prox) do
          if s.tipo == "recoge" then pintarRecoge(h, prox[i], s, true)
          elseif s.tipo == "fabricar" then pintarPieza(h, prox[i])
          else pintarReceta(h, prox[i], s, true) end
        end
      end
    end
  end
  -- Fabricar sin profesion de fabricar: lo que te harias con la recomendada (como antes)
  if objetivo == "fabricar" and p and p.sugerida then
    alguno = true
    h.cab(Y(CELESTE .. L("Para fabricarte equipo: ", "To craft your gear: ") .. p.sugerida.nombre .. "|r"))
    h.nota(Y(GRIS .. L("Hoy tienes dos de recoleccion: ganas oro vendiendo lo que sacas. Si cambias una por " .. p.sugerida.nombre .. " (la recomendada para tu clase), te fabricas esto:",
      "You have two gathering professions: you make gold selling what you gather. If you swap one for " .. p.sugerida.nombre .. " (the one recommended for your class), you craft this:") .. "|r"))
    if WowF.avisoMejorFabricar then h.nota(Y(WowF.avisoMejorFabricar())) end
    local proximas = {}
    for _, e in ipairs(p.sugerida.piezas or {}) do if e[1] >= h.nivelActual() - 3 and #proximas < 8 then table.insert(proximas, e) end end
    h.fabricadas(proximas)
  end
  -- Dependencias entre profesiones (8-oct, wowF_Dependencias.lua): que venderle a otras profesiones y que necesitas de ellas
  if objetivo == "oro" and WowF.seccionDependencias and WowF.seccionDependencias(h) then alguno = true end
  if not alguno then
    h.nota(Y(GRIS .. L("Con tus profesiones no hay nada seguro que mostrar para este objetivo.", "With your professions there is nothing verified to show for this goal.") .. "|r"))
  end
end

-- ===================== Secundarias (6-oct): First Aid y Cooking =====================
-- Fila de WowFDatos.objetivoProf.secundaria[prof]: { objeto, habilidad, cantidad, faccion, fuente, nivel que pide, materiales, hechizo,
--   tipo (v venda, c comida, p pocion, a antidoto, o otro), cura, bufo, estadistica, % XP, habilidad en que se vuelve gris }
local function filaSec(prof, f)
  return { id = f[1], nivel = f[2], cant = f[3], fac = f[4], fuente = f[5], rl = f[6], mats = f[7], spell = f[8], tipo = f[9],
    cura = f[10] or 0, bufo = f[11] or 0, stat = f[12] or "", xp = f[13] or 0, gris = f[14] or 0, mana = f[15] or 0, prof = prof }
end
-- Lo que hace el objeto, con los numeros reales del objeto en Forever
local function efectoSec(e)
  local t = {}
  if e.tipo == "v" and e.cura > 0 then table.insert(t, L("venda: cura " .. e.cura .. " de salud", "bandage: heals " .. e.cura .. " health")) end
  if e.tipo == "a" then table.insert(t, L("quita veneno", "removes poison")) end
  if e.tipo ~= "v" and e.cura > 0 then table.insert(t, L("recupera " .. e.cura .. " de salud", "restores " .. e.cura .. " health")) end
  if e.bufo > 0 and e.stat ~= "" then table.insert(t, "+" .. e.bufo .. " " .. e.stat) end
  if e.xp > 0 then table.insert(t, L("+" .. e.xp .. "% de XP al matar", "+" .. e.xp .. "% XP from kills")) end
  if (e.mana or 0) > 0 then table.insert(t, L("recupera " .. e.mana .. " de mana", "restores " .. e.mana .. " mana")) end -- 8-oct firstaid-alchemy
  return table.concat(t, ", ")
end
-- Valor para ordenar "Ya puedes": lo que mas cura o mas bufo da primero
local function valorSec(e) return e.cura + e.bufo * 20 + e.xp * 10 end

function WowF.recetasSecundaria(prof)
  local d = datos()
  local filas = d and d.secundaria and d.secundaria[prof]
  if not filas then return nil end
  local R = WowF.rangoProfesion and WowF.rangoProfesion(prof) or nil
  local N, mia = nivelPj(), miFaccion()
  local ya, prox = {}, {}
  for _, f in ipairs(filas) do
    local e = filaSec(prof, f)
    if vale(e.fac, mia) then
      if R and e.nivel <= R and e.rl <= N then table.insert(ya, e)
      else
        e.rango = e.nivel
        e.nivelDesbloqueo = math.max(nivelParaRango(e.nivel), e.rl)
        if e.nivel > (R or 0) or e.rl > N then table.insert(prox, e) end
      end
    end
  end
  table.sort(ya, function(a, b) local va, vb = valorSec(a), valorSec(b); if va ~= vb then return va > vb end; return a.nivel > b.nivel end)
  table.sort(prox, function(a, b) if a.nivel ~= b.nivel then return a.nivel < b.nivel end; return a.id < b.id end)
  return { rango = R, nivel = N, ya = ya, prox = prox }
end

local function pintarSec(h, e, proxima, R)
  local n, q, ic = nombreObj(e.id)
  local cant = (e.cant or 1) > 1 and (ORO .. e.cant .. " x|r ") or ""
  local cab
  if proxima then cab = NARANJA .. L("rango ", "skill ") .. e.rango .. "|r  "
  else cab = GRIS .. nombreProf(e.prof) .. " " .. e.nivel .. "  |r" end
  local lineas = {}
  local ef = efectoSec(e)
  if ef ~= "" then table.insert(lineas, VERDE .. ef .. "|r" .. ((e.rl or 0) > nivelPj() and (NARANJA .. L("  · se usa desde el nivel ", "  · usable from level ") .. e.rl .. "|r") or "")) end
  -- Si aun te sube la habilidad (gris = ya no sube)
  if not proxima and R and e.gris > 0 then
    if R >= e.gris then table.insert(lineas, GRIS .. L("Ya no te sube la habilidad (gris desde " .. e.gris .. ")", "No longer raises your skill (grey from " .. e.gris .. ")") .. "|r")
    else table.insert(lineas, CELESTE .. L("Te sube la habilidad hasta " .. e.gris, "Raises your skill up to " .. e.gris) .. "|r") end
  end
  if WowF.lineasExtraSecundaria then for _, l in ipairs(WowF.lineasExtraSecundaria(e)) do table.insert(lineas, l) end end -- 8-oct firstaid-alchemy: hierba / mana
  local mats, todo = textoMats(e.mats)
  if mats ~= "" then table.insert(lineas, GRIS .. L("Necesitas: ", "You need: ") .. "|r" .. mats .. (todo and (VERDE .. L("  ya lo tienes todo", "  you have it all") .. "|r") or "")) end
  -- Material que se pesca: las zonas reales de Forever (WowFMobs.pesca)
  for _, m in ipairs(e.mats or {}) do
    local zs = WowFMobs and WowFMobs.pesca and WowFMobs.pesca[m[1]]
    if zs then
      local orden = {}
      for _, z in ipairs(zs) do table.insert(orden, z) end
      table.sort(orden, function(a, c) return a[2] > c[2] end)
      local partes = {}
      for i = 1, math.min(3, #orden) do table.insert(partes, orden[i][1] .. " " .. orden[i][2] .. "%") end
      table.insert(lineas, CELESTE .. L("Se pesca (Fishing): ", "Fished (Fishing): ") .. "|r" .. GRIS .. table.concat(partes, ", ") .. "|r")
    end
  end
  local f, accion = textoFuente(e, h)
  table.insert(lineas, GRIS .. f .. "|r")
  h.item({ texto = Y(cab .. cant .. h.colorCalidad(q or 1) .. n .. "|r"), sub = Y(table.concat(lineas, "\n")), icono = h.icono(ic, e.id), objeto = e.id, sangria = 12, chico = true, accion = accion })
end

-- La llama CONTENIDO.Profesiones del Libro debajo del paso a paso de cada secundaria
function WowF.seccionSecundaria(prof, h)
  local r = WowF.recetasSecundaria(prof)
  if not r then return end
  local nombre = nombreProf(prof)
  local ya, prox = r.ya, r.prox
  if #ya > 0 then
    h.item({ texto = Y(VERDE .. L("Ya puedes", "You can now") .. "|r" .. GRIS .. "  (" .. nombre .. " " .. r.rango .. L(", nivel ", ", level ") .. r.nivel .. ")|r"), sangria = 4, chico = true })
    for i = 1, math.min(MAX_YA, #ya) do pintarSec(h, ya[i], false, r.rango) end
  elseif r.rango then
    h.item({ texto = Y(GRIS .. L("Ya puedes: nada aun con tu rango; mira las proximas.", "You can now: nothing yet at your skill; see the next ones.") .. "|r"), sangria = 4, chico = true })
  else
    h.item({ texto = Y(NARANJA .. L("Aun no la tienes: aprendela con el entrenador (no ocupa hueco de profesion).", "You do not have it yet: learn it from the trainer (it does not use a profession slot).") .. "|r"), sangria = 4, chico = true })
  end
  -- Ruta de farmeo (protocolo de Andy, 6-oct): area de bichos en el mapa para el material que mas te sube
  if WowF.materialSecundaria then
    local mat = WowF.materialSecundaria(prof)
    if mat then
      h.item({ texto = Y(VERDE .. L("Ruta de farmeo: ", "Farming route: ") .. "|r" .. nombreObj(mat)), sub = Y(GRIS .. L("Clic: marca en el mapa el area mas cercana con bichos que lo sueltan (circulo, que bichos y su nivel).", "Click: marks on the map the nearest area with mobs that drop it (circle, which mobs and their level).") .. "|r"), sangria = 4, chico = true, accion = function() WowF.areaSecundaria(prof) end })
    end
  end
  if WowF.extraSecundaria then WowF.extraSecundaria(prof, h) end -- 8-oct firstaid-alchemy: ruta de hierbas de las pociones
  if #prox > 0 then
    h.item({ texto = Y(ORO .. L("Proximas al subir", "Next as you level up") .. "|r" .. GRIS .. L("  (rango en que se desbloquean)", "  (skill that unlocks them)") .. "|r"), sangria = 4, chico = true })
    for i = 1, math.min(MAX_PROX, #prox) do pintarSec(h, prox[i], true, r.rango) end
  end
end

-- Fishing: no se fabrica; entrenador cuando haya datos y zonas de pesca (aun sin datos de Forever)
function WowF.seccionPesca(h)
  local nombre = nombreProf(356)
  local R = WowF.rangoProfesion and WowF.rangoProfesion(356) or nil
  h.item({ texto = Y(ORO .. nombre .. "|r" .. (R and (VERDE .. "  (" .. L("tienes ", "you have ") .. R .. ")|r") or (NARANJA .. L("  (aun no la tienes)", "  (you do not have it yet)") .. "|r"))), sangria = 0 })
  h.nota(Y(GRIS .. L("Necesitas una Fishing Pole (se compra a un vendedor). Equipala, usa Fishing junto al agua y haz clic en el corcho cuando se hunda. Sube un punto casi con cada pesca mientras el agua sea de tu rango.",
    "You need a Fishing Pole (bought from a vendor). Equip it, cast Fishing near water and click the bobber when it dips. You gain skill on almost every catch while the water matches your skill.") .. "|r"))
  -- Donde pescar: zonas reales de Forever (Wowhead /forever). Primero lo que sale en la zona donde estas.
  local pesca = WowFMobs and WowFMobs.pesca
  local hayZonas = pesca and next(pesca) ~= nil
  if hayZonas then
    local aqui = (GetRealZoneText and GetRealZoneText()) or ""
    local peces = {}
    for id, zonas in pairs(pesca) do
      local orden = {}
      for _, z in ipairs(zonas) do table.insert(orden, z) end
      table.sort(orden, function(a, c) return a[2] > c[2] end)
      local enMiZona
      for _, z in ipairs(orden) do if z[1] == aqui then enMiZona = z[2] end end
      table.insert(peces, { id = id, zonas = orden, aqui = enMiZona })
    end
    table.sort(peces, function(a, c) if (a.aqui ~= nil) ~= (c.aqui ~= nil) then return a.aqui ~= nil end; return a.id < c.id end)
    h.item({ texto = Y(ORO .. L("Donde pescar", "Where to fish") .. "|r" .. GRIS .. L("  (datos de WoW Forever; % = de cada 100 pescas)", "  (WoW Forever data; % = out of 100 catches)") .. "|r"), sangria = 4, chico = true })
    for _, pz in ipairs(peces) do
      local n, q, ic = nombreObj(pz.id)
      local partes = {}
      for i = 1, math.min(4, #pz.zonas) do table.insert(partes, pz.zonas[i][1] .. " " .. pz.zonas[i][2] .. "%") end
      local sub = GRIS .. table.concat(partes, ", ") .. "|r"
      if pz.aqui then sub = VERDE .. L("Sale aqui (" .. aqui .. "): " .. pz.aqui .. "%", "Found here (" .. aqui .. "): " .. pz.aqui .. "%") .. "|r\n" .. sub end
      h.item({ texto = Y(h.colorCalidad(q or 1) .. n .. "|r"), sub = Y(sub), icono = h.icono(ic, pz.id), objeto = pz.id, sangria = 12, chico = true })
    end
  end
  local ents = WowFDatos and WowFDatos.entrenadores and WowFDatos.entrenadores[356]
  if not ents or #ents == 0 then
    h.nota(Y(NARANJA .. L("Sin confirmar en Forever: aun no tenemos los entrenadores de pesca de Forever" .. (hayZonas and "" or " ni las zonas") .. ". Se actualizara en proximas actualizaciones.",
      "Not confirmed in Forever: we do not have Forever's fishing trainers" .. (hayZonas and "" or " or fishing zones") .. " yet. This will be updated in future updates.") .. "|r"))
  end
end

-- ===================== Avisos: "Nuevo para vender: X" / "Nuevo para PvP: X" (una vez por receta) =====================
local function clavePj() return (UnitName and UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "") end
function WowF.revisarObjetivoNuevo()
  local objetivo = WowF.objetivo and WowF.objetivo()
  if objetivo ~= "oro" and objetivo ~= "pvp" then return end
  if WowF.objetivoElegido and not WowF.objetivoElegido() then return end
  local ok, r = pcall(WowF.recetasObjetivo, objetivo)
  if not ok or not r or r.sinDatos then return end
  WowFExportarDB.avisosObjetivo = WowFExportarDB.avisosObjetivo or {}
  local todos = WowFExportarDB.avisosObjetivo
  local k = clavePj() .. "|" .. objetivo
  local primera = todos[k] == nil
  local vistos = todos[k] or {}
  todos[k] = vistos
  local nuevas = {}
  for _, s in ipairs(r.secciones) do
    if s.rango and s.tipo ~= "recoge" then
      for _, e in ipairs(s.ya) do
        local id = e.spell or e.id
        if not vistos[id] then
          vistos[id] = true
          -- La primera vez solo se apunta lo que ya podias (no se avisa de lo viejo)
          if not primera then table.insert(nuevas, { e = e, s = s }) end
        end
      end
    end
  end
  if #nuevas == 0 or not WowF.avisar then return nuevas end
  local l = {}
  for i = 1, math.min(3, #nuevas) do
    local n = nombreObj(nuevas[i].e.id)
    table.insert(l, BLANCO .. n .. "|r" .. GRIS .. " (" .. nuevas[i].s.nombre .. " " .. (nuevas[i].e.nivel or "") .. ")" .. (nuevas[i].e.motivo and nuevas[i].e.motivo ~= "" and (" - " .. nuevas[i].e.motivo) or "") .. "|r")
  end
  local titulo = objetivo == "oro" and L("Nuevo para vender: ", "New to sell: ") or L("Nuevo para PvP: ", "New for PvP: ")
  WowF.avisar(Y(titulo .. nombreObj(nuevas[1].e.id)), Y(table.concat(l, "\n")), nil, 9, "Profesiones")
  return nuevas
end

-- 5-oct (revision): huella de tus profesiones = id=rango/maximo de cada una + la ventana de profesion abierta y su numero de
-- recetas. Con la ventana abierta, el juego lanza TRADE_SKILL_UPDATE / TRADE_SKILL_LIST_UPDATE muchas veces seguidas (al
-- fabricar, al filtrar): solo hay que recalcular si la huella cambio.
function WowF.firmaProfesiones()
  local partes = {}
  if WowF.profesiones then
    local ok, lista = pcall(WowF.profesiones)
    if ok and type(lista) == "table" then
      for _, p in ipairs(lista) do
        partes[#partes + 1] = tostring(p.id or p.en or p.nombre or "?") .. "=" .. tostring(p.rango or "") .. "/" .. tostring(p.maximo or "")
      end
    end
  end
  table.sort(partes)
  local leer = WowF.llamar or function() return nil end
  if type(GetTradeSkillLine) == "function" then
    local ok, nombre, rango, maximo = pcall(GetTradeSkillLine)
    if ok then
      local n, r, m = WowF.numero and WowF.numero(nombre), WowF.numero and WowF.numero(rango), WowF.numero and WowF.numero(maximo)
      partes[#partes + 1] = "ventana=" .. tostring(n or "") .. ":" .. tostring(r or "") .. "/" .. tostring(m or "")
    end
  end
  local recetas = tonumber(leer(GetNumTradeSkills) or "")
  if not recetas and C_TradeSkillUI and type(C_TradeSkillUI.GetAllRecipeIDs) == "function" then
    local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
    if ok and type(ids) == "table" then recetas = #ids end
  end
  partes[#partes + 1] = "recetas=" .. tostring(recetas or "?")
  return table.concat(partes, ";")
end

-- 5-oct (revision): agrupa llamadas seguidas: fn corre UNA vez, espera segundos despues de la primera (sin C_Timer, al momento)
function WowF.agrupar(fn, espera)
  local pendiente = false
  return function()
    if pendiente then return end
    if not (C_Timer and type(C_Timer.After) == "function") then pcall(fn); return end
    pendiente = true
    C_Timer.After(espera or 0.5, function() pendiente = false; pcall(fn) end)
  end
end

-- Cache al dia: cambia el rango, abres la ventana de la profesion, subes de nivel o vuelves de la casa de subastas (precios)
local firmaVista
local function redibujar(ev)
  -- El Libro ya se redibuja con SKILL_LINES_CHANGED y PLAYER_LEVEL_UP; con la ventana de la profesion o la subasta, aqui
  if ev ~= "SKILL_LINES_CHANGED" and ev ~= "PLAYER_LEVEL_UP" and WowF.libro and WowF.libro:IsShown() and WowF.abrirLibro then pcall(WowF.abrirLibro) end
end
-- TRADE_SKILL_UPDATE / TRADE_SKILL_LIST_UPDATE: agrupados (0,5 s) y solo si cambio el rango o el numero de recetas
local revisarVentana = WowF.agrupar(function()
  local ok, f = pcall(WowF.firmaProfesiones)
  if ok and f and f == firmaVista then return end
  firmaVista = ok and f or nil
  WowF.profObjetivoInvalidar()
  redibujar("TRADE_SKILL_UPDATE")
end, 0.5)
local vigia = CreateFrame("Frame")
for _, ev in ipairs({ "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE", "PLAYER_LEVEL_UP", "AUCTION_HOUSE_CLOSED" }) do pcall(vigia.RegisterEvent, vigia, ev) end
vigia:SetScript("OnEvent", function(_, ev)
  if ev == "TRADE_SKILL_UPDATE" or ev == "TRADE_SKILL_LIST_UPDATE" then revisarVentana(); return end
  WowF.profObjetivoInvalidar()
  local ok, f = pcall(WowF.firmaProfesiones)
  firmaVista = ok and f or nil
  redibujar(ev)
end)
