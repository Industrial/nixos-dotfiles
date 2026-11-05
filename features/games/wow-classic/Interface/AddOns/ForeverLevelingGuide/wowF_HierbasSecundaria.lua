-- Forever Leveling Guide 5.0 (8-oct, firstaid-alchemy): First Aid con pociones y consejo de oro de Alchemy.
--   * En Forever las Healing Potions (Minor a Major) las fabrica First Aid y piden HIERBAS (datos del cliente de la beta).
--     La ruta de farmeo de First Aid dice que hierba te hace falta y donde sale mas (WowFFarmeo[182], Wowhead /forever),
--     filtrado por tu faccion, tu nivel y tu continente; clic = alfiler. Sin Herbalism: recogela o comprala en la casa de subastas.
--   * Pocion de mana en First Aid (hoy no hay ninguna): aviso "sin confirmar".
--   * Alchemy (objetivo oro): no recomienda Healing Potions (las hace First Aid; las Discolored hacen dano despues) y dice que
--     recetas de otras profesiones usan cada material que vendes (tintes de Tailoring, recetas de Merchant's Favor): objetivoProf.piden.
-- Todo se recalcula con tu rango, tu nivel, tu faccion y tu objetivo. Textos con L(es, en).

WowF = WowF or {}
local function L(es, en) if WowF.enIngles and WowF.enIngles() then return en end return es end
local function Y(s) return WowF.yaTraducido and WowF.yaTraducido(s) or s end
local AZUL, ORO, VERDE, GRIS, BLANCO, NARANJA, CELESTE = "|cff66ccffForever Guide:|r ", "|cffffd100", "|cff33ff66", "|cff999999", "|cffffffff", "|cffff9933", "|cff66ccff"
local HERBALISM, FIRST_AID, ALCHEMY = 182, 129, 171

local function datos() return WowFDatos and WowFDatos.objetivoProf end
local function nombreObj(id) local o = WowFDatos and WowFDatos.obj and WowFDatos.obj[id]; return o and o[1] or (L("objeto ", "item ") .. tostring(id)) end
local function nombreProf(id) return (WowFDatos and WowFDatos.prof and WowFDatos.prof[id]) or tostring(id) end
local function nivelPj() return (UnitLevel and UnitLevel("player")) or 1 end
-- Faccion como en WowFFarmeo (1 Horde, 2 Alliance) y como en objetivoProf (1 Alliance, 2 Horde)
local function facFarmeo() local f = UnitFactionGroup and UnitFactionGroup("player"); return f == "Horde" and 1 or (f == "Alliance" and 2 or 0) end
local function facDatos() local f = UnitFactionGroup and UnitFactionGroup("player"); return f == "Horde" and 2 or (f == "Alliance" and 1 or 0) end
local function vale(fac, mia) return (fac or 0) == 0 or (mia ~= 0 and fac == mia) end
local function rango(id) return WowF.rangoProfesion and WowF.rangoProfesion(id) or nil end
local function escapar(s) return (s:gsub("%p", "%%%0")) end
local function continenteDe(mapa)
  if not C_Map or not C_Map.GetMapInfo then return nil end
  local info = C_Map.GetMapInfo(mapa or 0)
  local vueltas = 0
  while info and vueltas < 8 do
    if info.mapType == 2 then return info.name end
    info = info.parentMapID and C_Map.GetMapInfo(info.parentMapID)
    vueltas = vueltas + 1
  end
  return nil
end

-- ===================== Hierbas =====================
-- Rango de Herbalism desde el que se recoge (nil = no es hierba). Primero objetivoProf.recoge[182]; si no, el tramo de WowFFarmeo.
function WowF.hierbaDesde(id)
  local d = datos()
  for _, f in ipairs((d and d.recoge and d.recoge[HERBALISM]) or {}) do if f[1] == id then return math.max(1, f[2]) end end
  local F = WowFFarmeo and WowFFarmeo[HERBALISM]
  if not F then return nil end
  local n = ", " .. nombreObj(id) .. ","
  for _, t in ipairs(F.tramos or {}) do if (", " .. (t.nodos or "") .. ","):find(n, 1, true) then return math.max(1, t.a or 1) end end
  return nil
end

-- Donde sale mas esa hierba: el punto de ruta de WowFFarmeo[182] con mas plantas, solo zonas de tu faccion o neutrales.
-- Peso: a tu nivel (zona de nivel <= el tuyo + 3) y en tu continente. Devuelve { z, p, n, lejos, alta }.
function WowF.sitioHierba(id)
  local F = WowFFarmeo and WowFFarmeo[HERBALISM]
  if not F then return nil end
  local fac, N = facFarmeo(), nivelPj()
  local aqui = continenteDe(C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
  local patron = ", " .. escapar(nombreObj(id)) .. " (%d+),"
  local mejor, mejorV
  for _, t in ipairs(F.tramos or {}) do
    for _, z in ipairs(t.zonas or {}) do
      if z.f == 0 or z.f == fac then
        for _, p in ipairs(z.ruta or {}) do
          local n = tonumber((", " .. (p[4] or "") .. ","):match(patron))
          if n then
            local v = n
            local alta = N < (z.d or 0) - 3
            local lejos = aqui and z.c and z.c ~= aqui or false
            if alta then v = v * 0.2 end
            if lejos then v = v * 0.3 end
            if not mejorV or v > mejorV then mejor, mejorV = { z = z, p = p, n = n, lejos = lejos, alta = alta }, v end
          end
        end
      end
    end
  end
  return mejor
end

-- Linea sobre como conseguir la hierba segun TU Herbalism
local function textoHerbalism(id)
  local desde = WowF.hierbaDesde(id) or 1
  local R = rango(HERBALISM)
  if not R then
    return NARANJA .. L("No tienes Herbalism: recogela con Herbalism (rango " .. desde .. ") o comprala en la casa de subastas.",
      "You do not have Herbalism: gather it with Herbalism (skill " .. desde .. ") or buy it at the auction house.") .. "|r"
  elseif R < desde then
    return NARANJA .. L("Tu Herbalism (" .. R .. ") aun no llega: la recoges desde " .. desde .. ". Mientras, comprala en la casa de subastas.",
      "Your Herbalism (" .. R .. ") is not there yet: you gather it from " .. desde .. ". Meanwhile, buy it at the auction house.") .. "|r"
  end
  return VERDE .. L("La recoges con tu Herbalism (" .. R .. ").", "You gather it with your Herbalism (" .. R .. ").") .. "|r"
end

local function textoSitio(s)
  if not s then return GRIS .. L("Aun no tenemos el sitio de esta hierba en WoW Forever: se actualizara en proximas actualizaciones.", "We do not have where this herb grows in WoW Forever yet: it will be updated in future updates.") .. "|r" end
  local t = L("Donde mas sale: ", "Where it grows most: ") .. s.z.n .. " " .. s.p[1] .. ", " .. s.p[2] .. L(" (" .. s.n .. " plantas en ese punto, zona de nivel " .. s.z.d .. ")", " (" .. s.n .. " plants at that spot, level " .. s.z.d .. " zone)")
  if s.lejos then t = t .. NARANJA .. L(" · queda en otro continente", " · it is on another continent") .. "|r" .. GRIS end
  if s.alta then t = t .. NARANJA .. L(" · zona de nivel alto para ti", " · high-level zone for you") .. "|r" .. GRIS end
  return GRIS .. t .. "|r"
end

-- Alfiler en el sitio de la hierba (y aviso en el chat)
function WowF.irHierba(id, para)
  local s = WowF.sitioHierba(id)
  local nombre = nombreObj(id)
  print(Y(AZUL .. (para and (L("para ", "for ") .. ORO .. nombreObj(para) .. "|r" .. L(" necesitas ", " you need ")) or "") .. nombre .. ". " .. textoHerbalism(id)))
  if not s then print(Y(AZUL .. textoSitio(nil))); return nil end
  if WowF.marcar then WowF.marcar({ m = s.z.m, x = s.p[1], y = s.p[2], n = nombre .. " (Herbalism)", z = s.z.n, lugar = true }) end
  print(Y(AZUL .. textoSitio(s)))
  return s
end

-- ===================== First Aid: la hierba de la pocion que te toca =====================
local function hierbaDe(e)
  for _, m in ipairs((e and e.mats) or {}) do
    local desde = WowF.hierbaDesde(m[1])
    if desde then return m[1], m[2], desde end
  end
  return nil
end
-- La pocion que aun te sube (de menor a mayor) o la proxima, y su hierba
function WowF.hierbaSecundaria(prof)
  local r = WowF.recetasSecundaria and WowF.recetasSecundaria(prof)
  if not r then return nil end
  local R = r.rango or 0
  local ya = {}
  for _, e in ipairs(r.ya) do table.insert(ya, e) end
  table.sort(ya, function(a, b) return (a.gris or 0) < (b.gris or 0) end)
  for _, e in ipairs(ya) do if (e.gris or 0) == 0 or R < e.gris then local h = hierbaDe(e); if h then return h, e, false end end end
  for _, e in ipairs(r.prox) do local h = hierbaDe(e); if h then return h, e, true end end
  for i = #ya, 1, -1 do local h = hierbaDe(ya[i]); if h then return h, ya[i], false end end
  return nil
end

-- Lineas extra de una receta de secundaria (pintarSec): hierba y como conseguirla; pocion de mana = sin confirmar
function WowF.lineasExtraSecundaria(e)
  local t = {}
  if (e.mana or 0) > 0 and e.prof == FIRST_AID then
    table.insert(t, NARANJA .. L("Pocion de mana en First Aid: sin confirmar en WoW Forever. Se actualizara en proximas actualizaciones.",
      "Mana potion in First Aid: unconfirmed in WoW Forever. It will be updated in future updates.") .. "|r")
  end
  local h = hierbaDe(e)
  if h then
    table.insert(t, CELESTE .. L("Hierba: ", "Herb: ") .. "|r" .. BLANCO .. nombreObj(h) .. "|r " .. textoHerbalism(h))
  end
  return t
end

-- Debajo de "Ruta de farmeo" en First Aid (y Cooking si alguna receta pide hierbas): la hierba de la pocion que te toca
function WowF.extraSecundaria(prof, h)
  local id, e, proxima = WowF.hierbaSecundaria(prof)
  if id then
    local s = WowF.sitioHierba(id)
    local sub = { textoHerbalism(id), textoSitio(s) }
    if s then table.insert(sub, VERDE .. L("Clic: alfiler en el mapa donde mas sale.", "Click: map pin where it grows most.") .. "|r") end
    h.item({ texto = Y(VERDE .. L("Ruta de hierbas: ", "Herb route: ") .. "|r" .. nombreObj(id) .. GRIS .. L(" (para ", " (for ") .. nombreObj(e.id) .. (proxima and L(", rango " .. e.nivel, ", skill " .. e.nivel) or "") .. ")|r"),
      sub = Y(table.concat(sub, "\n")), sangria = 4, chico = true, accion = s and function() WowF.irHierba(id, e.id) end or nil })
  end
  -- Objetivo oro: en Forever las Healing Potions solo las hace First Aid
  if prof == FIRST_AID and WowF.objetivo and WowF.objetivo() == "oro" then
    local d = datos()
    local hay = false
    for _, f in ipairs((d and d.secundaria and d.secundaria[FIRST_AID]) or {}) do if f[9] == "p" then hay = true end end
    if hay then
      h.nota(Y(ORO .. L("Para oro: en WoW Forever las Healing Potions las fabrica First Aid (Alchemy ya no las ensena). Precio: miralo en la casa de subastas.",
        "For gold: in WoW Forever Healing Potions are made with First Aid (Alchemy no longer teaches them). Price: check the auction house.") .. "|r"))
    end
  end
end

-- Para el panel / chat (WowF.areaSecundaria(129)): ademas de la tela, la hierba
function WowF.avisoHierbaSecundaria(prof)
  local id, e = WowF.hierbaSecundaria(prof or FIRST_AID)
  if not id then return end
  local s = WowF.sitioHierba(id)
  print(Y(AZUL .. L("las pociones de First Aid piden tambien ", "First Aid potions also need ") .. ORO .. nombreObj(id) .. "|r" .. L(" (para ", " (for ") .. nombreObj(e.id) .. "). " .. textoHerbalism(id)))
  if s then print(Y(AZUL .. textoSitio(s) .. GRIS .. L(" (Profesiones > First Aid: clic en Ruta de hierbas para el alfiler)", " (Professions > First Aid: click Herb route for the map pin)") .. "|r")) end
end

-- ===================== Quien pide lo que vendes (objetivoProf.piden) =====================
-- "Lo usan: Tailoring 14 recetas (12 de Merchant's Favor), Leatherworking 6 · p. ej. X (Tailoring 60, 2)"
function WowF.textoQuienLoPide(id)
  local d = datos()
  local l = d and d.piden and d.piden[id]
  if not l then return nil end
  local mia = facDatos()
  local porProf, orden, ejemplos, total = {}, {}, {}, 0
  for _, r in ipairs(l) do
    if vale(r[6], mia) then
      total = total + 1
      local p = porProf[r[1]]
      if not p then p = { n = 0, f = 0 }; porProf[r[1]] = p; table.insert(orden, r[1]) end
      p.n = p.n + 1
      if r[5] == 1 then p.f = p.f + 1; if #ejemplos < 2 then table.insert(ejemplos, r) end end
    end
  end
  if total == 0 then return nil end
  table.sort(orden, function(a, b) return porProf[a].n > porProf[b].n end)
  local partes = {}
  for i = 1, math.min(4, #orden) do
    local p = porProf[orden[i]]
    table.insert(partes, nombreProf(orden[i]) .. " " .. p.n .. (p.f > 0 and L(" (" .. p.f .. " de Merchant's Favor)", " (" .. p.f .. " Merchant's Favor)") or ""))
  end
  local ej = {}
  for _, r in ipairs(ejemplos) do table.insert(ej, nombreObj(r[3]) .. " (" .. nombreProf(r[1]) .. " " .. r[2] .. ", " .. r[4] .. ")") end
  return CELESTE .. L("Recetas que lo usan: ", "Recipes that use it: ") .. "|r" .. GRIS .. table.concat(partes, ", ") ..
    (#ej > 0 and (L(" · p. ej. ", " · e.g. ") .. table.concat(ej, ", ")) or "") .. "|r"
end

-- Notas de la seccion "Para vender" (objetivo oro). Alchemy: Healing Potions y materiales de las recetas nuevas.
function WowF.notaVentaProf(s)
  if not s or s.prof ~= ALCHEMY then return nil end
  local d = datos()
  local notas = {}
  table.insert(notas, ORO .. L("En WoW Forever las Healing Potions las fabrica First Aid: aqui no se recomiendan. Las Discolored Healing Potions tampoco: despues te quitan el 75 % de lo que curan.",
    "In WoW Forever Healing Potions are made with First Aid: they are not recommended here. Discolored Healing Potions are not either: afterwards they take back 75% of what they heal.") .. "|r")
  -- Materiales que piden las recetas de Merchant's Favor (tintes): los que ya puedes y los proximos
  local lista = {}
  local function mirar(e, ya)
    local l = d and d.piden and d.piden[e.id]
    if not l then return end
    for _, r in ipairs(l) do if r[5] == 1 and vale(r[6], facDatos()) then table.insert(lista, { e = e, ya = ya }); return end end
  end
  for _, e in ipairs(s.ya or {}) do mirar(e, true) end
  for _, e in ipairs(s.prox or {}) do mirar(e, false) end
  if #lista > 0 then
    local partes = {}
    for i = 1, math.min(4, #lista) do
      local x = lista[i]
      table.insert(partes, BLANCO .. nombreObj(x.e.id) .. "|r" .. (x.ya and (VERDE .. L(" (ya puedes)", " (you can now)") .. "|r") or (NARANJA .. L(" (rango " .. x.e.nivel .. ")", " (skill " .. x.e.nivel .. ")") .. "|r")))
    end
    table.insert(notas, GRIS .. L("Lo que piden las recetas nuevas (Merchant's Favor) de otras profesiones: ", "What the new recipes (Merchant's Favor) of other professions need: ") .. "|r" .. table.concat(partes, GRIS .. ", |r") ..
      GRIS .. L(". Abajo, en cada uno, que recetas lo usan.", ". Below, on each one, which recipes use it.") .. "|r")
  end
  return notas
end
