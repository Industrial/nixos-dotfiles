-- wowF Favor: Merchant's Favor (moneda 3402), la moneda de las profesiones de WoW Forever (7-oct).
--   * Que es, en 2-3 lineas; tu Favor actual (C_CurrencyInfo, leido con WowF.numero: puede ser secreto) y cuanto te falta.
--   * Paso a paso de las cajas (Waylaid Crate -> llenarla con UNO de los lotes -> entregarla) y la Shipping Label.
--   * Que comprar primero segun TUS profesiones y tu objetivo (fabricar / oro / pvp): "Ya puedes" / "Proximas al subir".
--   * El campamento de TU faccion (Alliance: Three Corners, Redridge; Horde: The Barrens) con icono en el mapa y ruta de un clic.
--   * /wowf favor y un aviso (una vez por personaje) al llegar al nivel 10.
-- Datos: WowFFavor (wowF_Favor_Datos.lua, generado por herramientas/generar-favor.mjs desde Wowhead /forever). Nada de la otra
-- faccion. Lo que la fuente no confirma se dice "sin confirmar, se actualizará en próximas actualizaciones"; nunca un numero inventado.

WowF = WowF or {}
WowFExportarDB = WowFExportarDB or {}
local AZUL = "|cff33ccffForever Guide|r: "
local ORO, VERDE, GRIS, BLANCO, NARANJA, CELESTE = "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933", "|cff66ccff"
local MORADO = "|cffcc88ff"
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function Y(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end
local function D() return WowFFavor end
local function lado()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  if f == "Horde" then return "H" elseif f == "Alliance" then return "A" end
  return nil
end
local function nivelPj() return (UnitLevel and UnitLevel("player")) or 1 end
local function clavePj() return (UnitName and UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "") end
local function nombreProf(id) return (WowFDatos and WowFDatos.prof and WowFDatos.prof[id]) or tostring(id) end
local function tengo(id) local ok, n = pcall(GetItemCount, id, true); return (ok and tonumber(n)) or 0 end
local function sinConfirmar() return L("sin confirmar, se actualizará en próximas actualizaciones", "unconfirmed, it will be updated in future updates") end
local REP = { [5] = "Honored", [6] = "Revered", [7] = "Exalted" }

-- Nivel en que se abre (la Shipping Label pide nivel 10 en Wowhead /forever)
function WowF.favorNivel()
  local d = D()
  local e = d and d.etiqueta and d.etiqueta[lado() or "A"]
  return (e and e.nivel) or 10
end

-- Tu Merchant's Favor ahora (nil = no se pudo leer)
function WowF.favorActual()
  local d = D()
  if not d or not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return nil end
  local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, d.moneda or 3402)
  if not ok or type(info) ~= "table" then return nil end
  local n = WowF.numero and WowF.numero(info.quantity)
  return tonumber(n)
end

-- Receta de Favor por su hechizo (el que fabrica): la fila de WowFFavor.recetas
local porHechizo
function WowF.favorReceta(spell)
  local d = D()
  if not d or not spell then return nil end
  if not porHechizo then
    porHechizo = {}
    for _, r in ipairs(d.recetas or {}) do porHechizo[r[6]] = r end
  end
  return porHechizo[spell]
end
local function deMiLado(lados) local l = lado(); return l ~= nil and type(lados) == "string" and lados:find(l, 1, true) ~= nil end

-- El vendedor de Favor de una profesion, solo de tu faccion
function WowF.vendedorFavor(prof)
  local d, l = D(), lado()
  if not d or not l then return nil end
  for _, v in ipairs((d.vend and d.vend[l]) or {}) do if v.prof == prof then return v end end
  return nil
end
function WowF.entregaFavor() local d, l = D(), lado(); return d and l and d.entrega and d.entrega[l] or nil end

-- ----- Ir a un NPC del campamento (ruta paso a paso; si no hay ruta, alfiler) -----
local elegido -- npc al que vas (dorado en el mapa)
local dibujar
local function irA(v, para, sub)
  if not v then return false end
  if WowF.limpiarRutas then pcall(WowF.limpiarRutas, true) end
  elegido = v.npc
  local quien = ORO .. v.n .. "|r" .. GRIS .. " (" .. (v.tag or "") .. ")|r"
  print(AZUL .. Y(L("Merchant's Favor: ve a ", "Merchant's Favor: go to ") .. quien .. GRIS .. ", " .. (v.zona or "") .. " " .. v.x .. ", " .. v.y .. "|r"))
  local destino = { n = v.n, m = v.m, x = v.x, y = v.y, z = v.zona, lugar = true, final = {
    titulo = v.n, ventana = ORO .. "Merchant's Favor|r",
    texto = Y(L("Habla con ", "Talk to ") .. quien .. ": " .. para),
    llegada = Y(L("habla con ", "talk to ") .. quien .. ": " .. para) } }
  local ok, hecho = false, false
  if WowF.viajeA then ok, hecho = pcall(WowF.viajeA, destino, { dibujar = true }) end
  if not (ok and hecho) and WowF.marcar then
    pcall(WowF.marcar, { m = v.m, x = v.x, y = v.y, n = v.n .. " (" .. (v.tag or "") .. ")", z = v.zona, lugar = true })
  end
  if WowF.marcarNPC then pcall(WowF.marcarNPC, { n = v.n, npc = v.npc, sub = sub }) end
  if dibujar then pcall(dibujar) end
  return true
end
function WowF.irVendedorFavor(prof)
  local v = WowF.vendedorFavor(prof)
  if not v then
    print(AZUL .. NARANJA .. Y(L("no hay vendedor de Merchant's Favor de " .. nombreProf(prof) .. " para tu faccion en los datos.", "there is no Merchant's Favor vendor for " .. nombreProf(prof) .. " for your faction in the data.")) .. "|r")
    return false
  end
  return irA(v, Y(L("compra recetas de " .. nombreProf(prof) .. " con Merchant's Favor", "buy " .. nombreProf(prof) .. " recipes with Merchant's Favor")),
    L("Recetas por Merchant's Favor", "Recipes for Merchant's Favor"))
end
function WowF.irEntregaFavor()
  local v = WowF.entregaFavor()
  if not v then
    print(AZUL .. NARANJA .. L("aun no tengo el NPC de entrega de tu faccion; se anadira en proximas actualizaciones.", "I do not have the turn-in NPC of your faction yet; it will be added in future updates.") .. "|r")
    return false
  end
  return irA(v, L("entrega tus cajas selladas y la Shipping Label", "turn in your sealed crates and the Shipping Label"),
    L("Entrega las cajas aqui", "Turn in crates here"))
end

-- ----- Lo que conviene comprar (tus profesiones + tu objetivo) -----
local function competencias()
  if not UnitClass then return nil end
  local _, token = UnitClass("player") -- sin "UnitClass and ...": el and corta a un valor y token quedaria nil
  return WowFValiosos and WowFValiosos.clases and WowFValiosos.clases[token or ""]
end
-- La puedes llevar? nil = no es para ponerse (consumible, encantamiento...)
local function laLlevas(r, N, comp)
  local c, s = r[11], r[12]
  if c == 4 then
    if s == 0 then return true end
    local desde = comp and comp.armaduras and comp.armaduras[s]
    return desde ~= nil and desde <= math.max(N, r[10] or 0)
  elseif c == 2 then
    local desde = comp and comp.armas and comp.armas[s]
    return desde ~= nil and desde <= math.max(N, r[10] or 0)
  end
  return nil
end
-- Puntos segun el objetivo (0 = no se recomienda)
local function puntos(r, objetivo, N, comp)
  local lleva = laLlevas(r, N, comp)
  local rl = r[10] or 0
  local cerca = rl >= N - 3 and rl <= N + 12
  if objetivo == "oro" then
    if r[14] == 1 then return 0 end -- se liga al recogerlo: no se puede vender
    return (r[9] or 1) >= 3 and 3 or 2
  elseif objetivo == "pvp" then
    if lleva == nil then return 3 end
    if lleva and cerca then return 2 end
    return 0
  end
  if lleva == nil then return 1 end
  if lleva and cerca then return 3 end
  if lleva and rl > N + 12 then return 1 end
  return 0
end
local function sabida(spell)
  if not IsPlayerSpell then return false end
  local ok, si = pcall(IsPlayerSpell, spell)
  return ok and si == true
end
-- Profesiones a revisar: las que tienes + las del plan (solo las que tienen vendedor de Favor)
local function misProfesiones()
  local ids, visto = {}, {}
  local function poner(id) if id and not visto[id] and WowF.vendedorFavor(id) then visto[id] = true; table.insert(ids, id) end end
  local ok, lista = pcall(function() return WowF.profesiones and WowF.profesiones() end)
  for _, p in ipairs((ok and lista) or {}) do poner(p.id) end
  local ok2, plan = pcall(function() return WowF.armarPlan and WowF.armarPlan() end)
  for _, id in ipairs((ok2 and plan and plan.ids) or {}) do poner(id) end
  return ids
end
WowF.favorProfesiones = misProfesiones

function WowF.favorRecomendaciones(objetivo)
  objetivo = objetivo or (WowF.objetivo and WowF.objetivo()) or "fabricar"
  local d = D()
  local res = { objetivo = objetivo, favor = WowF.favorActual(), profs = {} }
  if not d or not lado() then return res end
  local N, comp = nivelPj(), competencias()
  for _, prof in ipairs(misProfesiones()) do
    local R = (WowF.rangoProfesion and tonumber((WowF.rangoProfesion(prof)))) or 0 -- doble parentesis: devuelve rango Y maximo (el 2.o seria la base de tonumber)
    local s = { prof = prof, nombre = nombreProf(prof), rango = R, vendedor = WowF.vendedorFavor(prof), ya = {}, prox = {} }
    for _, r in ipairs(d.recetas or {}) do
      if r[2] == prof and deMiLado(r[15]) and not sabida(r[6]) then
        local p = puntos(r, objetivo, N, comp)
        if p > 0 then
          local e = { r = r, puntos = p, rango = r[3], costo = r[4], rep = r[5] }
          if R > 0 and R >= r[3] then table.insert(s.ya, e) else table.insert(s.prox, e) end
        end
      end
    end
    table.sort(s.ya, function(a, b) if a.puntos ~= b.puntos then return a.puntos > b.puntos end if a.costo ~= b.costo then return a.costo < b.costo end return a.r[6] < b.r[6] end)
    table.sort(s.prox, function(a, b) if a.rango ~= b.rango then return a.rango < b.rango end if a.puntos ~= b.puntos then return a.puntos > b.puntos end return a.r[6] < b.r[6] end)
    table.insert(res.profs, s)
  end
  return res
end

-- Cajas que llevas en las bolsas (selladas o por llenar)
local function cajasEnBolsas()
  local d, lista = D(), {}
  for id, c in pairs((d and d.cajas) or {}) do if tengo(id) > 0 then table.insert(lista, { id = id, c = c }) end end
  table.sort(lista, function(a, b) return a.id < b.id end)
  return lista
end
WowF.favorCajasEnBolsas = cajasEnBolsas
local function favorDeCaja(c)
  local d = D()
  local f = d and d.favorCaja and d.favorCaja[c[1]]
  return f and f[c[3]] or nil
end
local function nombreCaja(c) return c[1] .. " " .. c[2] end
local function textoLotes(c)
  local t = {}
  for _, lote in ipairs(c[5] or {}) do
    local n = tengo(lote[1])
    local col = n >= lote[2] and VERDE or GRIS
    table.insert(t, col .. lote[2] .. " x " .. lote[3] .. " (" .. L("tienes ", "you have ") .. n .. ")|r")
  end
  return table.concat(t, "\n")
end

-- ----- Seccion del Libro (pestana Profesiones) -----
local MAX_YA, MAX_PROX = 5, 3
local function lineaReceta(h, e, favor, proxima)
  local r = e.r
  local cab
  if proxima then cab = NARANJA .. L("rango ", "skill ") .. r[3] .. "|r  " else cab = "" end
  local lineas = {}
  local costo = ORO .. r[4] .. " Merchant's Favor|r"
  if favor and not proxima then
    if favor >= r[4] then costo = costo .. "  " .. VERDE .. L("te alcanza", "you can afford it") .. "|r"
    else costo = costo .. "  " .. NARANJA .. L("te faltan ", "you need ") .. (r[4] - favor) .. L("", " more") .. "|r" end
  end
  table.insert(lineas, costo)
  if r[5] and r[5] > 0 then
    local f = D().faccion and D().faccion[lado()]
    table.insert(lineas, NARANJA .. L("pide reputacion ", "requires ") .. (REP[r[5]] or (L("rango ", "rank ") .. r[5])) .. L(" con ", " with ") .. (f and f[2] or "?") .. "|r")
  end
  local pieza = r[11] == 4 or r[11] == 2
  if (r[10] or 0) > 0 then table.insert(lineas, GRIS .. (pieza and L("para llevarlo: nivel ", "to wear it: level ") or L("para usarlo: nivel ", "to use it: level ")) .. r[10] .. (r[14] == 1 and L(" (se liga al recogerlo)", " (binds on pickup)") or L(" (se puede vender)", " (can be sold)")) .. "|r") end
  table.insert(lineas, VERDE .. L("clic: ruta al vendedor", "click: route to the vendor") .. "|r")
  local q = (r[9] and r[9] > 0) and r[9] or 1
  local id = (r[7] and r[7] > 0) and r[7] or r[1]
  h.item({ texto = Y(cab .. h.colorCalidad(q) .. r[8] .. "|r"), sub = Y(table.concat(lineas, "\n")), icono = h.icono(nil, id), objeto = id,
    sangria = 12, chico = true, accion = function() WowF.irVendedorFavor(r[2]) end })
end

function WowF.seccionFavor(p, h)
  local d = D()
  h.cab(ORO .. "Merchant's Favor|r")
  if not d then
    h.nota(GRIS .. L("Faltan los datos de Merchant's Favor: reinstala el addon.", "Merchant's Favor data is missing: reinstall the addon.") .. "|r")
    return
  end
  local l = lado()
  if not l then
    h.nota(GRIS .. L("Elige faccion primero: el campamento depende de ella.", "Choose a faction first: the camp depends on it.") .. "|r")
    return
  end
  local N, nivel = nivelPj(), WowF.favorNivel()
  local fac = d.faccion and d.faccion[l]
  local entrega = WowF.entregaFavor()
  h.nota(Y(BLANCO .. L("La moneda de las profesiones: llenas cajas con materiales y las entregas en el campamento de ", "The profession currency: fill crates with materials and turn them in at the camp of ")
    .. (fac and fac[2] or "?") .. L(". Con el Favor compras recetas, la montura Pack Kodo y más.", ". With Favor you buy recipes, the Pack Kodo mount and more.") .. "|r"))
  local favor = WowF.favorActual()
  if favor then h.nota(Y(L("Tienes: ", "You have: ") .. ORO .. favor .. " Merchant's Favor|r"))
  else h.nota(GRIS .. L("Tu Favor: no se pudo leer (abre la ventana de monedas del juego).", "Your Favor: could not be read (open the game's currency window).") .. "|r") end
  if entrega then
    h.item({ texto = Y(VERDE .. L("Campamento: ", "Camp: ") .. "|r" .. BLANCO .. entrega.zona .. " " .. entrega.x .. ", " .. entrega.y .. "|r"),
      sub = Y(GRIS .. L("Entrega: ", "Turn-in: ") .. entrega.n .. "  ·  " .. VERDE .. L("clic: ruta paso a paso", "click: step-by-step route") .. "|r"),
      icono = "Interface\\Icons\\INV_Crate_04", chico = true, accion = function() WowF.irEntregaFavor() end })
  end
  if N < nivel then
    h.nota(Y(NARANJA .. L("Se abre a nivel ", "Unlocks at level ") .. nivel .. L(" (te faltan ", " (") .. (nivel - N) .. L(" niveles). Te avisaré al llegar.", " levels to go). I will tell you when you get there.") .. "|r"))
  end
  -- Pasos de las cajas
  h.nota(Y(ORO .. L("Cómo se consigue:", "How to earn it:") .. "|r\n"
    .. BLANCO .. "1. " .. L("Consigue una Waylaid Crate: cae en el mundo. Dónde exactamente: ", "Get a Waylaid Crate: it drops around the world. Exactly where: ") .. NARANJA .. sinConfirmar() .. "|r\n"
    .. BLANCO .. "2. " .. L("Te pide UNO de los lotes de materiales (lista abajo); llénala y queda sellada.", "It asks for ONE of the material bundles (list below); fill it and it becomes sealed.") .. "|r\n"
    .. BLANCO .. "3. " .. L("Entrégala a ", "Turn it in to ") .. (entrega and entrega.n or "?") .. L(" en el campamento.", " at the camp.") .. "|r"))
  local et = d.etiqueta and d.etiqueta[l]
  if et then
    local hecha = false
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then local ok, s = pcall(C_QuestLog.IsQuestFlaggedCompleted, et.q); hecha = ok and s == true end
    -- 9-oct (cero Classic): la XP de la etiqueta viene de Wowhead (base de Classic); solo se ensena la que el juego ya te dio a tu nivel
    local txp = ""
    if WowF.xpMision and WowF.textoXP then txp = WowF.textoXP(WowF.xpMision({ id = et.q, xp = et.xp })) end
    h.nota(Y((hecha and GRIS or CELESTE) .. "Shipping Label" .. L(" (nivel ", " (level ") .. et.nivel .. "): " .. et.favor .. " Merchant's Favor + " .. et.rep
      .. L(" de reputación", " reputation") .. (txp ~= "" and (" " .. txp) or "") .. (hecha and L("  (ya la entregaste)", "  (already turned in)") or L(". Entrégala también allí.", ". Turn it in there too.")) .. "|r"))
  end
  -- Favor por caja (solo lo que la guia confirma)
  local partes = {}
  for _, rango in ipairs({ "Apprentice", "Journeyman" }) do
    local f = d.favorCaja and d.favorCaja[rango]
    if f then table.insert(partes, rango .. " " .. f[1] .. L(" (blanca) / ", " (white) / ") .. f[2] .. L(" (verde)", " (green)")) end
  end
  h.nota(Y(GRIS .. L("Favor por caja: ", "Favor per crate: ") .. table.concat(partes, "; ") .. ". Expert / Artisan: " .. sinConfirmar() .. ".|r"))
  if WowF.notaLegacyFavor and WowF.notaLegacyFavor() then h.nota(WowF.notaLegacyFavor()) end
  -- Cajas que ya llevas
  local mias = cajasEnBolsas()
  for _, x in ipairs(mias) do
    local f = favorDeCaja(x.c)
    h.item({ texto = Y(VERDE .. L("En tus bolsas: ", "In your bags: ") .. "|r" .. BLANCO .. nombreCaja(x.c) .. "|r"
      .. (f and (GRIS .. " (" .. f .. " Favor)|r") or (GRIS .. " (Favor: " .. sinConfirmar() .. ")|r"))),
      sub = Y(GRIS .. L("Llenala con UNO de estos lotes:", "Fill it with ONE of these bundles:") .. "|r\n" .. textoLotes(x.c) .. "\n" .. VERDE .. L("clic: ruta a la entrega", "click: route to the turn-in") .. "|r"),
      icono = h.icono(nil, x.id), objeto = x.id, sangria = 12, chico = true, accion = function() WowF.irEntregaFavor() end })
  end
  if #mias == 0 and N >= nivel then
    -- Lotes que piden las cajas de tu nivel (para ir guardando materiales)
    local tipos = {}
    for _, c in pairs(d.cajas or {}) do
      if (c[4] or 99) <= N then
        local k = c[1] .. " " .. c[2]
        if not tipos[k] then tipos[k] = c end
      end
    end
    local claves = {}
    for k in pairs(tipos) do table.insert(claves, k) end
    -- primero las del rango mas alto que ya te toca (las de nivel mas alto), luego por nombre
    table.sort(claves, function(a, b) local na, nb = tipos[a][4] or 0, tipos[b][4] or 0; if na ~= nb then return na > nb end return a < b end)
    local t = {}
    for i = 1, math.min(8, #claves) do table.insert(t, claves[i]) end
    if #t > 0 then h.nota(Y(GRIS .. L("Cajas de tu nivel: ", "Crates at your level: ") .. table.concat(t, ", ") .. L(". Guarda materiales de tus profesiones para llenarlas.", ". Keep materials from your professions to fill them.") .. "|r")) end
  end
  -- Que comprar primero
  local rec = WowF.favorRecomendaciones(p and p.objetivo)
  local obj = rec.objetivo
  local porque = obj == "oro" and L("objetivo oro: recetas de cosas que se pueden vender", "gold goal: recipes for things you can sell")
    or (obj == "pvp" and L("objetivo PvP: consumibles, encantamientos y piezas para tu nivel", "PvP goal: consumables, enchants and gear for your level")
    or L("objetivo fabricar: piezas que tu clase lleva cerca de tu nivel", "craft goal: gear your class wears near your level"))
  local alguna = false
  for _, s in ipairs(rec.profs) do
    if #s.ya + #s.prox > 0 then
      if not alguna then h.nota(Y(ORO .. L("Que comprar primero", "What to buy first") .. "|r  " .. GRIS .. "(" .. porque .. ")|r")) end
      alguna = true
      local v = s.vendedor
      h.item({ texto = Y(CELESTE .. s.nombre .. "|r" .. GRIS .. (s.rango > 0 and (" " .. s.rango) or L(" (no la tienes aun)", " (not learned yet)")) .. "|r"),
        sub = Y(GRIS .. L("La vende ", "Sold by ") .. v.n .. " (" .. v.zona .. " " .. v.x .. ", " .. v.y .. ")  " .. VERDE .. L("clic: ruta", "click: route") .. "|r"),
        icono = "Interface\\Icons\\INV_Scroll_03", chico = true, accion = function() WowF.irVendedorFavor(s.prof) end })
      if #s.ya > 0 then
        h.nota(Y(VERDE .. L("Ya puedes", "You can now") .. "|r"))
        for i = 1, math.min(MAX_YA, #s.ya) do lineaReceta(h, s.ya[i], rec.favor, false) end
      end
      if #s.prox > 0 then
        h.nota(Y(NARANJA .. L("Proximas al subir", "Next as you level up") .. "|r"))
        for i = 1, math.min(MAX_PROX, #s.prox) do lineaReceta(h, s.prox[i], rec.favor, true) end
      end
    end
  end
  if not alguna then
    h.nota(GRIS .. L("Ninguna de tus profesiones tiene recetas de Merchant's Favor que te sirvan ahora (las venden Alchemy, Blacksmithing, Cooking, Enchanting, Engineering, Leatherworking y Tailoring).",
      "None of your professions has Merchant's Favor recipes useful to you now (they are sold for Alchemy, Blacksmithing, Cooking, Enchanting, Engineering, Leatherworking and Tailoring).") .. "|r")
  end
  -- Otras recompensas de tu faccion
  local otros = {}
  for _, o in ipairs(d.otros or {}) do
    if deMiLado(o[6]) and not o[2]:find("Certification", 1, true) then
      table.insert(otros, o[2] .. " " .. o[3] .. (o[4] > 0 and (" (" .. (REP[o[4]] or "?") .. ")") or ""))
    end
  end
  if #otros > 0 then h.nota(Y(GRIS .. L("También: ", "Also: ") .. table.concat(otros, ", ") .. L(". Certificaciones de profesión: 1000 cada una (rango 300, dan título).", ". Profession certifications: 1000 each (skill 300, grant a title).") .. "|r")) end
  h.nota(Y(GRIS .. L("Craftsman's Writs: nivel aún no disponible en Forever; se actualizará en próximas actualizaciones.", "Craftsman's Writs: level not available in Forever yet; it will be updated in future updates.") .. "|r"))
end

-- ----- Icono del campamento en el mapa (solo tu faccion) -----
local pines = {}
local function lienzo()
  if not WorldMapFrame or WowF.interfazMando() then return nil end -- 22-oct (FLG-ERR 4.52 SetPreferredGamepadInteractTarget): con mando no se toca el mapa del juego
  if WorldMapFrame.GetCanvas then return WorldMapFrame:GetCanvas() end
  return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end
local function puntosMapa()
  local lista, l, d = {}, lado(), D()
  if not d or not l then return lista end
  local e = WowF.entregaFavor()
  if e then table.insert(lista, { v = e, entrega = true }) end
  local mias = {}
  for _, id in ipairs(misProfesiones()) do mias[id] = true end
  for _, v in ipairs((d.vend and d.vend[l]) or {}) do
    if mias[v.prof] or elegido == v.npc then table.insert(lista, { v = v }) end
  end
  return lista
end
dibujar = function()
  for _, p in pairs(pines) do p:Hide() end -- pairs: nunca ipairs al ocultar
  if WowFExportarDB.favorMapa == false then return end
  local c = lienzo()
  if not c or not WorldMapFrame:IsShown() then return end
  local visto = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  local lista = {}
  for _, x in ipairs(puntosMapa()) do if x.v.m == visto then table.insert(lista, x) end end
  if #lista == 0 then return end
  local ancho, alto = c:GetWidth(), c:GetHeight()
  if not ancho or ancho == 0 then return end
  local escala = 1
  pcall(function() escala = c:GetEffectiveScale() / UIParent:GetEffectiveScale() end)
  if not escala or escala <= 0 then escala = 1 end
  local px = 1 / escala
  for i, x in ipairs(lista) do
    local pin = pines[i]
    if not pin then
      pin = CreateFrame("Button", nil, c)
      pin:SetFrameStrata("HIGH")
      pin.aro = pin:CreateTexture(nil, "BACKGROUND")
      pin.icono = pin:CreateTexture(nil, "ARTWORK")
      pin.icono:SetAllPoints()
      pin:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local v = self.datos.v
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(v.n, 1, 1, 1)
        GameTooltip:AddLine("Merchant's Favor · " .. (v.tag or ""), 1, 0.82, 0)
        if self.datos.entrega then GameTooltip:AddLine(L("Entrega aqui tus cajas selladas y la Shipping Label", "Turn in your sealed crates and the Shipping Label here"), 1, 1, 1, true)
        else GameTooltip:AddLine(L("Vende recetas de ", "Sells ") .. nombreProf(v.prof) .. L(" por Merchant's Favor", " recipes for Merchant's Favor"), 1, 1, 1, true) end
        GameTooltip:AddLine((v.zona or "") .. " " .. v.x .. ", " .. v.y, 0.6, 0.6, 0.6)
        GameTooltip:AddLine(L("Clic: llevame hasta alli (ruta paso a paso)", "Click: take me there (step-by-step route)"), 0.2, 1, 0.4)
        GameTooltip:Show()
      end)
      pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
      pin:SetScript("OnClick", function(self)
        if self.datos.entrega then WowF.irEntregaFavor() else WowF.irVendedorFavor(self.datos.v.prof) end
      end)
      pines[i] = pin
    end
    pin.datos = x
    local este = elegido == x.v.npc
    local s = (x.entrega and 16 or 12) * px * (este and 1.25 or 1)
    pin:SetSize(s, s)
    pin:ClearAllPoints()
    local borde = 2 * px
    pin.aro:ClearAllPoints(); pin.aro:SetPoint("TOPLEFT", -borde, borde); pin.aro:SetPoint("BOTTOMRIGHT", borde, -borde)
    if este then pin.aro:SetColorTexture(1, 0.82, 0, 1) elseif x.entrega then pin.aro:SetColorTexture(0.8, 0.53, 1, 1) else pin.aro:SetColorTexture(0, 0, 0, 1) end
    pin.icono:SetTexture(x.entrega and "Interface\\Icons\\INV_Crate_04" or "Interface\\Icons\\INV_Scroll_03")
    pin.icono:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    -- los del campamento estan pegados: un pequeno corrimiento para que no se monten
    local dx = x.entrega and 0 or ((i - 1) % 4 - 1.5) * 14 * px
    local dy = x.entrega and 0 or (math.floor((i - 1) / 4) + 1) * 16 * px
    pin:SetPoint("CENTER", c, "TOPLEFT", ancho * x.v.x / 100 + dx, -alto * x.v.y / 100 - dy)
    pin:Show()
  end
end
WowF.dibujarFavor = dibujar
WowF.pinesFavor = function() local n = 0; for _, p in pairs(pines) do if p:IsShown() then n = n + 1 end end; return n end -- pruebas
WowF.favorElegido = function() return elegido end

local limpiarAntes = WowF.limpiarRutas
if limpiarAntes then
  WowF.limpiarRutas = function(...)
    elegido = nil
    local r = limpiarAntes(...)
    if dibujar then pcall(dibujar) end
    return r
  end
end

if WorldMapFrame then
  if WorldMapFrame.OnMapChanged then pcall(hooksecurefunc, WorldMapFrame, "OnMapChanged", function() pcall(dibujar) end) end
  WorldMapFrame:HookScript("OnShow", function() pcall(dibujar) end)
  local escalaVista
  local vigia = CreateFrame("Frame", nil, WorldMapFrame)
  vigia:SetScript("OnUpdate", function()
    local cv = lienzo()
    local ok, s = pcall(function() return cv:GetEffectiveScale() end)
    if ok and type(s) == "number" and s > 0 and (not escalaVista or math.abs(s - escalaVista) > escalaVista * 0.01) then
      escalaVista = s; pcall(dibujar)
    end
  end)
end

-- ----- Resumen en el chat y aviso al nivel 10 -----
function WowF.favorResumen()
  local d, l = D(), lado()
  if not d or not l then
    print(AZUL .. NARANJA .. L("faltan los datos de Merchant's Favor o tu faccion.", "Merchant's Favor data or your faction is missing.") .. "|r")
    return
  end
  local e, favor, nivel = WowF.entregaFavor(), WowF.favorActual(), WowF.favorNivel()
  print(AZUL .. Y(ORO .. "Merchant's Favor|r: " .. (favor and (BLANCO .. favor .. "|r") or (GRIS .. L("no se pudo leer", "could not be read") .. "|r"))
    .. GRIS .. L(" · campamento: ", " · camp: ") .. (e and (e.zona .. " " .. e.x .. ", " .. e.y) or "?") .. "|r"))
  if nivelPj() < nivel then
    print(AZUL .. Y(L("se abre a nivel ", "unlocks at level ") .. nivel .. "."))
  else
    print(AZUL .. Y(L("llena Waylaid Crates con UNO de sus lotes y entregalas a ", "fill Waylaid Crates with ONE of their bundles and turn them in to ") .. (e and e.n or "?") .. L(". Detalle en el Libro (pestana Profesiones, al final).", ". Details in the Book (Professions tab, at the bottom).")))
  end
end

local function avisar()
  local nivel = WowF.favorNivel()
  if nivelPj() < nivel or not D() or not lado() then return end
  WowFExportarDB.favorAviso = WowFExportarDB.favorAviso or {}
  local k = clavePj()
  if WowFExportarDB.favorAviso[k] then return end
  WowFExportarDB.favorAviso[k] = true
  local e = WowF.entregaFavor()
  print(AZUL .. Y(ORO .. L("NUEVO: Merchant's Favor abierto (nivel ", "NEW: Merchant's Favor unlocked (level ") .. nivel .. ")|r. "
    .. L("Llena cajas con materiales y entregalas en ", "Fill crates with materials and turn them in at ") .. (e and (e.zona .. " " .. e.x .. ", " .. e.y) or "?")
    .. L(" para comprar recetas. Escribe ", " to buy recipes. Type ") .. ORO .. "/wowf favor|r" .. L(" para la guia.", " for the guide.")))
  if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo.RAID_WARNING then
    pcall(RaidNotice_AddMessage, RaidWarningFrame, L("Merchant's Favor abierto: /wowf favor", "Merchant's Favor unlocked: /wowf favor"), ChatTypeInfo.RAID_WARNING)
  end
end
WowF.favorAvisar = avisar
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LEVEL_UP", "PLAYER_LOGIN" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, evento)
  if C_Timer and C_Timer.After then C_Timer.After(evento == "PLAYER_LEVEL_UP" and 2 or 10, function() pcall(avisar) end) else pcall(avisar) end
end)

-- ----- /wowf favor [mapa on|off | entrega | <profesion>] -----
local anterior = SlashCmdList["WOWF"]
SlashCmdList["WOWF"] = function(mensaje)
  local orden, resto = (mensaje or ""):match("^%s*(%S*)%s*(.-)%s*$")
  orden = (orden or ""):lower(); resto = (resto or ""):lower()
  if orden == "favor" or orden == "merchant" then
    if resto == "mapa off" or resto == "map off" or resto == "off" then
      WowFExportarDB.favorMapa = false
      print(AZUL .. L("iconos de Merchant's Favor en el mapa: apagados (/wowf favor on).", "Merchant's Favor map icons: off (/wowf favor on)."))
    elseif resto == "mapa on" or resto == "map on" or resto == "on" then
      WowFExportarDB.favorMapa = nil
      print(AZUL .. L("iconos de Merchant's Favor en el mapa: encendidos.", "Merchant's Favor map icons: on."))
    elseif resto == "entrega" or resto == "turnin" or resto == "ruta" or resto == "route" then
      WowF.irEntregaFavor()
    elseif resto ~= "" then
      local hallada
      local d, l = D(), lado()
      for _, v in ipairs((d and l and d.vend[l]) or {}) do
        local n = nombreProf(v.prof):lower()
        if n:find(resto, 1, true) == 1 or (v.tag or ""):lower():find(resto, 1, true) then hallada = v.prof end
      end
      if hallada then WowF.irVendedorFavor(hallada)
      else print(AZUL .. L("no conozco esa profesion; prueba: /wowf favor tailoring", "unknown profession; try: /wowf favor tailoring")) end
    else
      WowF.favorResumen()
      if WowF.abrirLibro then pcall(WowF.abrirLibro, "Profesiones") end
    end
    pcall(dibujar)
    return
  end
  if anterior then anterior(mensaje) end
end
